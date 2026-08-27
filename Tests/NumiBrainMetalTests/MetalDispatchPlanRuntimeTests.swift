import Metal
import NumiBrainABI
import XCTest

@testable import NumiBrainCore
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalDispatchPlanRuntimeTests: XCTestCase {
  private func makePlan() throws -> (
    BrainDispatchPlan,
    BrainModuleSchedule,
    RegionalTokenProgram,
    BrainParameterVersion
  ) {
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let program = try RegionalTokenProgram.runtimeFoundationV0(
      schedule: schedule,
      historyCapacity: 32
    )
    let version = try BrainParameterVersion.runtimeFoundationV0(
      schedule: schedule,
      regionalProgram: program,
      tissueParameters: .corticalSheetV0
    )
    let identifiers: [UInt32] = [22, 4, 17, 9]
    let environments = try identifiers.enumerated().map { index, identifier in
      var scheduler = CPUMultiRateScheduler(
        schedule: schedule,
        parameterVersionFingerprint: version.fingerprint
      )
      let warmup = try scheduler.beginAdvance(
        to: BrainTimestamp(microseconds: 20_000),
        events: []
      )
      try scheduler.commit(warmup)
      let events =
        index == 2
        ? [
          try BrainInterruptEvent(
            timestamp: BrainTimestamp(microseconds: 26_250),
            mask: [.pain, .lossOfSupport],
            identifier: 700
          )
        ]
        : []
      return BrainScheduledEnvironment(
        environmentIdentifier: identifier,
        transaction: try scheduler.beginAdvance(
          to: BrainTimestamp(microseconds: 40_000),
          events: events
        )
      )
    }
    return (try BrainDispatchPlan(environments: environments), schedule, program, version)
  }

  func testMetalMaterializesExactVersionedCohortPlanAndReplay() throws {
    try requireMetal4()
    let (plan, schedule, program, version) = try makePlan()
    let initialRegionalStates = plan.activeEnvironmentIdentifiers.map { identifier in
      BrainCohortRegionalState(
        environmentIdentifier: identifier,
        states: schedule.modules.enumerated().map { moduleIndex, _ in
          RegionalModuleState(
            activation: Float((Int(identifier) + moduleIndex) % 13) / 32,
            integration: Float((Int(identifier) * 3 + moduleIndex) % 11) / 32,
            interruptSalience: Float(moduleIndex % 3) / 32,
            phase: Float(moduleIndex) / Float(schedule.modules.count)
          )
        }
      )
    }
    let initialTokenStates = plan.activeEnvironmentIdentifiers.map { identifier in
      BrainCohortTokenState(
        environmentIdentifier: identifier,
        values: (0..<program.scalarCount).map { scalarIndex in
          Float((Int(identifier) * 7 + scalarIndex) % 29) / 64
        }
      )
    }
    let initialRoutingStates = plan.activeEnvironmentIdentifiers.map { identifier in
      var history = RegionalRouteHistory(program: program)
      for routeIndex in program.routes.indices {
        history.states[routeIndex] = RegionalRouteHistoryState(
          nextSlot: 1,
          count: 1,
          latestTimestamp: BrainTimestamp(microseconds: 0)
        )
        history.timestamps[routeIndex * history.capacity] = 0
        let valueOffset = Int(program.routeHistoryValueOffsets[routeIndex])
        let dimension = Int(program.routeMessageDimensions[routeIndex])
        for feature in 0..<dimension {
          history.values[valueOffset + feature] =
            Float((Int(identifier) + routeIndex + feature) % 31) / 64
        }
      }
      return BrainCohortRoutingState(
        environmentIdentifier: identifier,
        routeHistory: history,
        routingState: RegionalRoutingState(program: program)
      )
    }
    let first = try MetalDispatchPlanRuntime.materialize(
      plan: plan,
      schedule: schedule,
      regionalProgram: program,
      parameterVersion: version,
      initialRegionalStates: initialRegionalStates,
      initialTokenStates: initialTokenStates,
      initialRoutingStates: initialRoutingStates
    )
    let replay = try MetalDispatchPlanRuntime.materialize(
      plan: plan,
      schedule: schedule,
      regionalProgram: program,
      parameterVersion: version,
      initialRegionalStates: initialRegionalStates,
      initialTokenStates: initialTokenStates,
      initialRoutingStates: initialRoutingStates
    )

    XCTAssertEqual(first.status, 0)
    XCTAssertEqual(first.planFingerprint, plan.fingerprint)
    XCTAssertEqual(first.parameterVersionFingerprint, version.fingerprint)
    XCTAssertEqual(first.groups, plan.groups)
    XCTAssertEqual(first.workItems, plan.workItems)
    XCTAssertEqual(first.workFingerprint, plan.workFingerprint)
    XCTAssertEqual(first.indirectThreadgroupCount, UInt32((plan.entryCount + 63) / 64))
    XCTAssertEqual(first.groups, replay.groups)
    XCTAssertEqual(first.workItems, replay.workItems)
    XCTAssertEqual(first.workFingerprint, replay.workFingerprint)
    XCTAssertEqual(first.regionalStates, replay.regionalStates)
    XCTAssertEqual(first.regionalStateFingerprint, replay.regionalStateFingerprint)
    XCTAssertEqual(first.tokenStates, replay.tokenStates)
    XCTAssertEqual(first.tokenStateFingerprint, replay.tokenStateFingerprint)
    XCTAssertEqual(first.routingStates, replay.routingStates)
    XCTAssertEqual(first.routingStateFingerprint, replay.routingStateFingerprint)
    XCTAssertEqual(first.planFingerprint, replay.planFingerprint)
    XCTAssertEqual(first.parameterVersionFingerprint, replay.parameterVersionFingerprint)
    XCTAssertEqual(first.entryCount, plan.entryCount)
    XCTAssertEqual(first.regionalStates.map(\.environmentIdentifier), [4, 9, 17, 22])
    XCTAssertEqual(
      first.regionalIndirectThreadgroupCount,
      UInt32((first.regionalStates.count + 63) / 64)
    )
    XCTAssertEqual(
      first.regionalStateByteCount,
      first.regionalStates.count * schedule.modules.count
        * RegionalModuleState.abiByteCount
    )
    XCTAssertEqual(first.tokenStates.map(\.environmentIdentifier), [4, 9, 17, 22])
    XCTAssertEqual(first.tokenIndirectThreadgroupCount, UInt32(first.tokenStates.count))
    XCTAssertEqual(
      first.tokenStateByteCount,
      first.tokenStates.count * program.scalarCount * MemoryLayout<Float>.stride
    )
    XCTAssertFalse(first.deviceName.isEmpty)
    XCTAssertGreaterThanOrEqual(first.gpuDurationSeconds, 0)

    var maximumAbsoluteError: Float = 0
    for environment in first.regionalStates {
      let initial = try XCTUnwrap(
        initialRegionalStates.first {
          $0.environmentIdentifier == environment.environmentIdentifier
        }
      )
      let expected = try CPURegionalModuleOperator.advance(
        states: initial.states,
        schedule: schedule,
        invocations: plan.invocations(for: environment.environmentIdentifier)
      )
      XCTAssertEqual(environment.states.count, expected.count)
      for (actual, reference) in zip(environment.states, expected) {
        let errors = [
          abs(actual.activation - reference.activation),
          abs(actual.integration - reference.integration),
          abs(actual.interruptSalience - reference.interruptSalience),
          abs(actual.phase - reference.phase),
        ]
        maximumAbsoluteError = max(maximumAbsoluteError, errors.max() ?? 0)
        XCTAssertEqual(actual.updateCount, reference.updateCount)
        XCTAssertEqual(actual.interruptCount, reference.interruptCount)
        XCTAssertEqual(actual.lastUpdate, reference.lastUpdate)
      }
    }
    XCTAssertLessThanOrEqual(maximumAbsoluteError, 2e-6)
    let interrupted = try XCTUnwrap(
      first.regionalStates.first { $0.environmentIdentifier == 17 }
    )
    let unaffected = try XCTUnwrap(
      first.regionalStates.first { $0.environmentIdentifier == 22 }
    )
    XCTAssertNotEqual(interrupted.states, unaffected.states)
    XCTAssertGreaterThan(interrupted.states.map(\.interruptCount).reduce(0, +), 0)
    XCTAssertEqual(unaffected.states.map(\.interruptCount).reduce(0, +), 0)

    var tokenMaximumAbsoluteError: Float = 0
    var routeMaximumAbsoluteError: Float = 0
    for environment in first.tokenStates {
      let initialTokens = try XCTUnwrap(
        initialTokenStates.first {
          $0.environmentIdentifier == environment.environmentIdentifier
        }
      )
      let initialDiagnostics = try XCTUnwrap(
        initialRegionalStates.first {
          $0.environmentIdentifier == environment.environmentIdentifier
        }
      )
      let reference = try CPURegionalTokenOperator.advance(
        state: initialTokens.values,
        diagnostics: initialDiagnostics.states,
        schedule: schedule,
        program: program,
        invocations: plan.invocations(for: environment.environmentIdentifier),
        routeHistory: try XCTUnwrap(
          initialRoutingStates.first {
            $0.environmentIdentifier == environment.environmentIdentifier
          }
        ).routeHistory,
        routingState: try XCTUnwrap(
          initialRoutingStates.first {
            $0.environmentIdentifier == environment.environmentIdentifier
          }
        ).routingState
      )
      XCTAssertEqual(environment.values.count, reference.values.count)
      for (actual, expected) in zip(environment.values, reference.values) {
        tokenMaximumAbsoluteError = max(tokenMaximumAbsoluteError, abs(actual - expected))
      }
      let actualRouting = try XCTUnwrap(
        first.routingStates.first {
          $0.environmentIdentifier == environment.environmentIdentifier
        }
      )
      XCTAssertEqual(actualRouting.routeHistory.states, reference.routeHistory.states)
      XCTAssertEqual(actualRouting.routeHistory.timestamps, reference.routeHistory.timestamps)
      XCTAssertEqual(actualRouting.routingState.states.map(\.isActive),
        reference.routingState.states.map(\.isActive))
      XCTAssertEqual(actualRouting.routingState.states.map(\.selectionCount),
        reference.routingState.states.map(\.selectionCount))
      XCTAssertEqual(actualRouting.routingState.states.map(\.lastSelectedTimestamp),
        reference.routingState.states.map(\.lastSelectedTimestamp))
      XCTAssertEqual(actualRouting.routingState.states.map(\.switchCount),
        reference.routingState.states.map(\.switchCount))
      for (actual, expected) in zip(
        actualRouting.routeHistory.values,
        reference.routeHistory.values
      ) {
        routeMaximumAbsoluteError = max(routeMaximumAbsoluteError, abs(actual - expected))
      }
      for (actual, expected) in zip(
        actualRouting.routingState.states,
        reference.routingState.states
      ) {
        routeMaximumAbsoluteError = max(
          routeMaximumAbsoluteError,
          abs(actual.score - expected.score),
          abs(actual.strength - expected.strength)
        )
      }
    }
    XCTAssertLessThanOrEqual(tokenMaximumAbsoluteError, 3e-6)
    XCTAssertLessThanOrEqual(routeMaximumAbsoluteError, 3e-6)
    XCTAssertTrue(
      first.routingStates.contains { state in
        state.routingState.states.contains { $0.isActive }
      }
    )

    let regionalRecords = first.regionalStates.flatMap { state in
      state.states.map(\.abiRecord)
    }
    let identifiers = first.regionalStates.map(\.environmentIdentifier)
    let expectedRegionalFingerprint = identifiers.withUnsafeBufferPointer { identifiers in
      regionalRecords.withUnsafeBufferPointer { states in
        nb_brain_abi_cohort_regional_state_fingerprint(
          plan.fingerprint,
          version.fingerprint,
          schedule.fingerprint,
          identifiers.baseAddress,
          UInt32(identifiers.count),
          states.baseAddress,
          UInt32(schedule.modules.count)
        )
      }
    }
    XCTAssertEqual(first.regionalStateFingerprint, expectedRegionalFingerprint)
    let tokenValues = first.tokenStates.flatMap(\.values)
    let expectedTokenFingerprint = identifiers.withUnsafeBufferPointer { identifiers in
      tokenValues.withUnsafeBufferPointer { values in
        nb_brain_abi_cohort_token_state_fingerprint(
          plan.fingerprint,
          version.fingerprint,
          program.fingerprint,
          identifiers.baseAddress,
          UInt32(identifiers.count),
          values.baseAddress,
          UInt32(program.scalarCount)
        )
      }
    }
    XCTAssertEqual(first.tokenStateFingerprint, expectedTokenFingerprint)
    let historyStateRecords = first.routingStates.flatMap {
      $0.routeHistory.states.map(\.abiRecord)
    }
    let historyTimestamps = first.routingStates.flatMap(\.routeHistory.timestamps)
    let historyValues = first.routingStates.flatMap(\.routeHistory.values)
    let runtimeStateRecords = first.routingStates.flatMap {
      $0.routingState.states.map(\.abiRecord)
    }
    let expectedRoutingFingerprint = identifiers.withUnsafeBufferPointer { identifiers in
      historyStateRecords.withUnsafeBufferPointer { historyStates in
        historyTimestamps.withUnsafeBufferPointer { timestamps in
          historyValues.withUnsafeBufferPointer { values in
            runtimeStateRecords.withUnsafeBufferPointer { runtimeStates in
              nb_brain_abi_cohort_routing_state_fingerprint(
                plan.fingerprint,
                version.fingerprint,
                program.fingerprint,
                identifiers.baseAddress,
                UInt32(identifiers.count),
                historyStates.baseAddress,
                timestamps.baseAddress,
                values.baseAddress,
                runtimeStates.baseAddress,
                UInt32(program.routes.count),
                UInt32(program.compiledRouteHistoryCapacity),
                UInt32(program.routeHistoryScalarCount)
              )
            }
          }
        }
      }
    }
    XCTAssertEqual(first.routingStateFingerprint, expectedRoutingFingerprint)
    XCTAssertEqual(BrainDispatchPlan.cohortUniformByteCount, 32)
    XCTAssertEqual(BrainDispatchPlan.tokenUniformByteCount, 32)
    XCTAssertEqual(
      first.privateInputByteCount,
      BrainDispatchPlan.headerByteCount
        + plan.groups.count * BrainDispatchPlan.groupByteCount
        + plan.entryCount * BrainDispatchPlan.entryByteCount
        + BrainParameterVersion.bindingByteCount
        + BrainDispatchPlan.cohortUniformByteCount
        + first.regionalStates.count * MemoryLayout<UInt32>.stride
        + schedule.modules.count * BrainModuleSchedule.moduleDescriptorByteCount
        + first.regionalStateByteCount
        + BrainDispatchPlan.tokenUniformByteCount
        + Int(NB_REGIONAL_PROGRAM_HEADER_BYTE_COUNT)
        + program.layouts.count * Int(NB_REGIONAL_TOKEN_LAYOUT_BYTE_COUNT)
        + program.routes.count * Int(NB_REGIONAL_ROUTE_BYTE_COUNT)
        + program.parameters.count * Int(NB_REGIONAL_TOKEN_PARAMETERS_BYTE_COUNT)
        + first.tokenStateByteCount
        + first.routeHistoryByteCount
        + first.routeRuntimeStateByteCount
    )
    XCTAssertEqual(
      first.privateOutputByteCount,
      plan.groups.count * BrainDispatchPlan.groupByteCount
        + plan.entryCount * BrainDispatchPlan.entryByteCount
        + BrainDispatchPlan.resultByteCount
        + 48
        + plan.entryCount * BrainDispatchPlan.workItemByteCount
        + first.regionalStateByteCount
        + first.tokenStateByteCount * 2
        + first.regionalStates.count * schedule.modules.count
        * MemoryLayout<UInt64>.stride
        + first.routeHistoryByteCount
        + first.routeRuntimeStateByteCount
        + first.routingStates.count * program.routes.count
        * MemoryLayout<UInt32>.stride * 2
        + first.routingStates.count * schedule.modules.count
        * MemoryLayout<UInt32>.stride
    )
  }

  func testMetalRejectsStaleParameterGenerationBeforeUpload() throws {
    try requireMetal4()
    let (plan, schedule, program, version) = try makePlan()
    let successor = try version.successor(
      regionalProgramFingerprint: version.regionalProgramFingerprint,
      components: version.components
    )
    XCTAssertNotEqual(successor.fingerprint, version.fingerprint)
    XCTAssertThrowsError(
      try MetalDispatchPlanRuntime.materialize(
        plan: plan,
        schedule: schedule,
        regionalProgram: program,
        parameterVersion: successor
      )
    )

    let futureState = BrainCohortRegionalState(
      environmentIdentifier: plan.activeEnvironmentIdentifiers[0],
      states: schedule.modules.enumerated().map { index, _ in
        RegionalModuleState(
          lastUpdate: index == 0 ? BrainTimestamp(microseconds: 30_000) : nil
        )
      }
    )
    let remainingStates = plan.activeEnvironmentIdentifiers.dropFirst().map { identifier in
      BrainCohortRegionalState(
        environmentIdentifier: identifier,
        states: schedule.modules.map { _ in RegionalModuleState() }
      )
    }
    XCTAssertThrowsError(
      try MetalDispatchPlanRuntime.materialize(
        plan: plan,
        schedule: schedule,
        regionalProgram: program,
        parameterVersion: version,
        initialRegionalStates: [futureState] + remainingStates
      )
    )

    let unroutedProgram = try RegionalTokenProgram.runtimeFoundationUnroutedV0(
      schedule: schedule
    )
    XCTAssertThrowsError(
      try MetalDispatchPlanRuntime.materialize(
        plan: plan,
        schedule: schedule,
        regionalProgram: unroutedProgram,
        parameterVersion: version
      )
    )

    let malformedTokenStates = plan.activeEnvironmentIdentifiers.map { identifier in
      BrainCohortTokenState(
        environmentIdentifier: identifier,
        values: [Float](
          repeating: 0,
          count: identifier == plan.activeEnvironmentIdentifiers[0]
            ? program.scalarCount - 1
            : program.scalarCount
        )
      )
    }
    XCTAssertThrowsError(
      try MetalDispatchPlanRuntime.materialize(
        plan: plan,
        schedule: schedule,
        regionalProgram: program,
        parameterVersion: version,
        initialTokenStates: malformedTokenStates
      )
    )
  }

  func testMetalRejectsUnsafeCohortRouteHistoryBeforeUpload() throws {
    try requireMetal4()
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let route = try RegionalTokenRoute(
      senderModuleIdentifier: 95,
      receiverModuleIdentifier: 83,
      senderToken: 0,
      delayMicroseconds: 5_000,
      gain: 0.75,
      flags: [.persistent]
    )
    let program = try RegionalTokenProgram(
      schedule: schedule,
      routes: [route],
      historyCapacity: 1
    )
    let version = try BrainParameterVersion.runtimeFoundationV0(
      schedule: schedule,
      regionalProgram: program,
      tissueParameters: .corticalSheetV0
    )
    let scheduler = CPUMultiRateScheduler(
      schedule: schedule,
      parameterVersionFingerprint: version.fingerprint
    )
    let transaction = try scheduler.beginAdvance(
      to: BrainTimestamp(microseconds: 20_000),
      events: []
    )
    let plan = try BrainDispatchPlan(
      environments: [
        BrainScheduledEnvironment(
          environmentIdentifier: 7,
          transaction: transaction
        )
      ]
    )
    XCTAssertThrowsError(
      try MetalDispatchPlanRuntime.materialize(
        plan: plan,
        schedule: schedule,
        regionalProgram: program,
        parameterVersion: version
      )
    ) { error in
      XCTAssertTrue(String(describing: error).contains("cannot preserve route"))
    }
  }

  private func requireMetal4() throws {
    guard MTLCreateSystemDefaultDevice() != nil else {
      throw XCTSkip("Metal device unavailable")
    }
  }
}

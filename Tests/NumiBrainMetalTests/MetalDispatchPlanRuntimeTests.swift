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
    let program = try RegionalTokenProgram.runtimeFoundationUnroutedV0(
      schedule: schedule
    )
    let version = try BrainParameterVersion.runtimeFoundationV0(
      schedule: schedule,
      regionalProgram: program,
      tissueParameters: .corticalSheetV0
    )
    let identifiers: [UInt32] = [22, 4, 17, 9]
    let environments = try identifiers.enumerated().map { index, identifier in
      let scheduler = CPUMultiRateScheduler(
        schedule: schedule,
        parameterVersionFingerprint: version.fingerprint
      )
      let events =
        index == 2
        ? [
          try BrainInterruptEvent(
            timestamp: BrainTimestamp(microseconds: 6_250),
            mask: [.pain, .lossOfSupport],
            identifier: 700
          )
        ]
        : []
      return BrainScheduledEnvironment(
        environmentIdentifier: identifier,
        transaction: try scheduler.beginAdvance(
          to: BrainTimestamp(microseconds: 20_000),
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
    let first = try MetalDispatchPlanRuntime.materialize(
      plan: plan,
      schedule: schedule,
      regionalProgram: program,
      parameterVersion: version,
      initialRegionalStates: initialRegionalStates,
      initialTokenStates: initialTokenStates
    )
    let replay = try MetalDispatchPlanRuntime.materialize(
      plan: plan,
      schedule: schedule,
      regionalProgram: program,
      parameterVersion: version,
      initialRegionalStates: initialRegionalStates,
      initialTokenStates: initialTokenStates
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
        invocations: plan.invocations(for: environment.environmentIdentifier)
      )
      XCTAssertEqual(environment.values.count, reference.values.count)
      for (actual, expected) in zip(environment.values, reference.values) {
        tokenMaximumAbsoluteError = max(tokenMaximumAbsoluteError, abs(actual - expected))
      }
    }
    XCTAssertLessThanOrEqual(tokenMaximumAbsoluteError, 3e-6)

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
        + program.parameters.count * Int(NB_REGIONAL_TOKEN_PARAMETERS_BYTE_COUNT)
        + first.tokenStateByteCount
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

    let routedProgram = try RegionalTokenProgram.runtimeFoundationV0(
      schedule: schedule
    )
    XCTAssertThrowsError(
      try MetalDispatchPlanRuntime.materialize(
        plan: plan,
        schedule: schedule,
        regionalProgram: routedProgram,
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

  private func requireMetal4() throws {
    guard MTLCreateSystemDefaultDevice() != nil else {
      throw XCTSkip("Metal device unavailable")
    }
  }
}

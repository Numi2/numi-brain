import Foundation
import NumiBrainABI
import NumiBrainCore
import NumiBrainMetal

private struct Options {
  var environmentCount = 1_024
  var controlMilliseconds = 20
  var outputPath: String?

  static func parse(_ arguments: [String]) throws -> Self {
    var options = Self()
    var index = 0
    while index < arguments.count {
      let argument = arguments[index]
      func value() throws -> String {
        guard index + 1 < arguments.count else {
          throw DispatchCLIError("missing value after \(argument)")
        }
        index += 1
        return arguments[index]
      }
      switch argument {
      case "--environments":
        options.environmentCount = try positiveInteger(value(), name: argument)
      case "--control-ms":
        options.controlMilliseconds = try positiveInteger(value(), name: argument)
      case "--output":
        options.outputPath = try value()
      case "--help":
        printHelp()
        Foundation.exit(EXIT_SUCCESS)
      default:
        throw DispatchCLIError("unknown argument: \(argument)")
      }
      index += 1
    }
    guard options.environmentCount <= 12_288 else {
      throw DispatchCLIError("--environments exceeds the 12288-agent profile limit")
    }
    guard options.controlMilliseconds <= 1_000 else {
      throw DispatchCLIError("--control-ms exceeds 1000 ms")
    }
    return options
  }

  private static func positiveInteger(_ value: String, name: String) throws -> Int {
    guard let parsed = Int(value), parsed > 0 else {
      throw DispatchCLIError("\(name) must be a positive integer")
    }
    return parsed
  }

  private static func printHelp() {
    print(
      """
      Usage: numi-brain-dispatch [options]

        --environments N  Independent versioned scheduler states (default: 1024, max: 12288)
        --control-ms N     One root transaction interval (default: 20, max: 1000)
        --output PATH      Write deterministic JSON evidence
        --help             Show this help
      """
    )
  }
}

private struct DispatchCLIError: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}

private struct ABIEvidence: Codable {
  let planVersion: UInt32
  let cohortEnvironmentBytes: Int
  let groupBytes: Int
  let entryBytes: Int
  let headerBytes: Int
  let resultBytes: Int
  let workItemBytes: Int
  let cohortUniformBytes: Int
  let tokenUniformBytes: Int
  let regionalStateBytes: Int
  let regionalRouteBytes: Int
  let routeHistoryStateBytes: Int
  let routeRuntimeStateBytes: Int
  let parameterBindingBytes: Int
}

private struct IdentityEvidence: Codable {
  let scheduleFingerprint: String
  let regionalProgramFingerprint: String
  let parameterVersionFingerprint: String
  let cohortFingerprint: String
  let dispatchPlanFingerprint: String
  let dispatchWorkFingerprint: String
  let regionalStateFingerprint: String
  let tokenStateFingerprint: String
  let routingStateFingerprint: String
}

private struct CohortEvidence: Codable {
  let environmentCount: Int
  let moduleCount: Int
  let sourceInvocationCount: Int
  let interruptDeliveryCount: Int
  let dispatchGroupCount: Int
  let dispatchEntryCount: Int
  let maximumEnvironmentCountPerGroup: Int
  let tokenScalarsPerEnvironment: Int
  let routeCount: Int
  let routeHistoryCapacity: Int
  let routeHistoryScalarsPerEnvironment: Int
}

private struct MetalEvidence: Codable {
  let device: String
  let privateInputBytes: Int
  let privateOutputBytes: Int
  let workItemCount: Int
  let workItemBytes: Int
  let indirectThreadgroupCount: UInt32
  let regionalEnvironmentCount: Int
  let regionalStateBytes: Int
  let regionalIndirectThreadgroupCount: UInt32
  let tokenEnvironmentCount: Int
  let tokenStateBytes: Int
  let tokenIndirectThreadgroupCount: UInt32
  let routingEnvironmentCount: Int
  let routeHistoryBytes: Int
  let routeRuntimeStateBytes: Int
  let status: UInt32
  let gpuSeconds: Double
  let execution: String
}

private struct VerificationEvidence: Codable {
  let retryExact: Bool
  let discardedShadowStateUnchanged: Bool
  let canonicalInputOrderExact: Bool
  let gpuMaterializationExact: Bool
  let gpuIndirectConsumptionExact: Bool
  let gpuRegionalCPUReferenceWithinTolerance: Bool
  let gpuRegionalDiscreteStateExact: Bool
  let gpuRegionalOwnershipAndInterruptIsolationExact: Bool
  let regionalCPUReferenceMaximumAbsoluteError: Double
  let regionalCPUReferenceTolerance: Double
  let gpuTokenCPUReferenceWithinTolerance: Bool
  let gpuTokenOwnershipExact: Bool
  let tokenCPUReferenceMaximumAbsoluteError: Double
  let tokenCPUReferenceTolerance: Double
  let tokenCPUReferenceSampleCount: Int
  let gpuRoutingCPUReferenceWithinTolerance: Bool
  let gpuRoutingDiscreteStateExact: Bool
  let gpuRoutingOwnershipExact: Bool
  let routingCPUReferenceMaximumAbsoluteError: Double
  let routingCPUReferenceTolerance: Double
  let gpuReplayExact: Bool
  let staleParameterVersionRejected: Bool
}

private struct DispatchEvidence: Codable {
  let schema: String
  let revision: String
  let operatingSystem: String
  let abi: ABIEvidence
  let identity: IdentityEvidence
  let cohort: CohortEvidence
  let metal: MetalEvidence
  let verification: VerificationEvidence
  let executionPath: String
  let limitations: [String]
}

@main
private struct NumiBrainDispatchCommand {
  static func main() {
    do {
      guard #available(macOS 26.0, *) else {
        throw DispatchCLIError("Metal 4 cohort materialization requires macOS 26 or later")
      }
      let options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
      let evidence = try run(options: options)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      let data = try encoder.encode(evidence)
      if let outputPath = options.outputPath {
        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
          at: outputURL.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        try data.write(to: outputURL, options: .atomic)
      }
      FileHandle.standardOutput.write(data)
      FileHandle.standardOutput.write(Data([0x0a]))
    } catch {
      FileHandle.standardError.write(Data("numi-brain-dispatch: \(error)\n".utf8))
      Darwin.exit(EXIT_FAILURE)
    }
  }

  @available(macOS 26.0, *)
  private static func run(options: Options) throws -> DispatchEvidence {
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
    let targetMicroseconds = UInt64(options.controlMilliseconds) * 1_000
    var retryExact = true
    var shadowStateUnchanged = true
    var environments: [BrainScheduledEnvironment] = []
    environments.reserveCapacity(options.environmentCount)
    var sourceInvocationCount = 0
    var interruptDeliveryCount = 0
    for index in 0..<options.environmentCount {
      let scheduler = CPUMultiRateScheduler(
        schedule: schedule,
        parameterVersionFingerprint: version.fingerprint
      )
      let events = try configuredEvents(
        environmentIndex: index,
        environmentCount: options.environmentCount,
        targetMicroseconds: targetMicroseconds
      )
      let before = scheduler.snapshot
      let transaction = try scheduler.beginAdvance(
        to: BrainTimestamp(microseconds: targetMicroseconds),
        events: events
      )
      let retry = try scheduler.beginAdvance(
        to: BrainTimestamp(microseconds: targetMicroseconds),
        events: Array(events.reversed())
      )
      retryExact = retryExact && transaction == retry
      shadowStateUnchanged = shadowStateUnchanged && scheduler.snapshot == before
      sourceInvocationCount += transaction.invocations.count
      interruptDeliveryCount +=
        transaction.invocations.filter {
          $0.reasons.contains(.interrupt)
        }.count
      environments.append(
        BrainScheduledEnvironment(
          environmentIdentifier: UInt32(index),
          transaction: transaction
        )
      )
    }

    let plan = try BrainDispatchPlan(environments: environments)
    let reversed = try BrainDispatchPlan(environments: Array(environments.reversed()))
    let initialRegionalStates = plan.activeEnvironmentIdentifiers.map { identifier in
      BrainCohortRegionalState(
        environmentIdentifier: identifier,
        states: schedule.modules.enumerated().map { moduleIndex, _ in
          RegionalModuleState(
            activation: Float((Int(identifier) + moduleIndex) % 17) / 64,
            integration: Float((Int(identifier) * 3 + moduleIndex) % 13) / 64,
            interruptSalience: Float(moduleIndex % 3) / 64,
            phase: Float(moduleIndex) / Float(schedule.modules.count)
          )
        }
      )
    }
    let initialRegionalStatesByIdentifier = Dictionary(
      uniqueKeysWithValues: initialRegionalStates.map {
        ($0.environmentIdentifier, $0.states)
      }
    )
    let initialTokenStates = plan.activeEnvironmentIdentifiers.map { identifier in
      BrainCohortTokenState(
        environmentIdentifier: identifier,
        values: (0..<program.scalarCount).map { scalarIndex in
          Float((Int(identifier) * 7 + scalarIndex) % 29) / 64
        }
      )
    }
    let initialTokenStatesByIdentifier = Dictionary(
      uniqueKeysWithValues: initialTokenStates.map {
        ($0.environmentIdentifier, $0.values)
      }
    )
    let materialized = try MetalDispatchPlanRuntime.materialize(
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
    let successor = try version.successor(
      regionalProgramFingerprint: version.regionalProgramFingerprint,
      components: version.components
    )
    let staleParameterVersionRejected: Bool
    do {
      _ = try MetalDispatchPlanRuntime.materialize(
        plan: plan,
        schedule: schedule,
        regionalProgram: program,
        parameterVersion: successor
      )
      staleParameterVersionRejected = false
    } catch {
      staleParameterVersionRejected = true
    }
    let materializationExact =
      materialized.groups == plan.groups
      && materialized.planFingerprint == plan.fingerprint
      && materialized.parameterVersionFingerprint == version.fingerprint
      && materialized.status == 0
    let indirectConsumptionExact =
      materialized.workItems == plan.workItems
      && materialized.workFingerprint == plan.workFingerprint
      && materialized.indirectThreadgroupCount
        == UInt32((plan.entryCount + 63) / 64)
    let regionalTolerance: Float = 2e-6
    var regionalMaximumAbsoluteError: Float = 0
    var regionalDiscreteStateExact = true
    for environment in materialized.regionalStates {
      guard
        let initialStates = initialRegionalStatesByIdentifier[
          environment.environmentIdentifier
        ]
      else {
        throw DispatchCLIError("cohort regional input ownership is incomplete")
      }
      let reference = try CPURegionalModuleOperator.advance(
        states: initialStates,
        schedule: schedule,
        invocations: plan.invocations(for: environment.environmentIdentifier)
      )
      if environment.states.count != reference.count {
        regionalDiscreteStateExact = false
        continue
      }
      for (actual, expected) in zip(environment.states, reference) {
        let errors = [
          abs(actual.activation - expected.activation),
          abs(actual.integration - expected.integration),
          abs(actual.interruptSalience - expected.interruptSalience),
          abs(actual.phase - expected.phase),
        ]
        regionalMaximumAbsoluteError = max(
          regionalMaximumAbsoluteError,
          errors.max() ?? 0
        )
        regionalDiscreteStateExact =
          regionalDiscreteStateExact
          && actual.updateCount == expected.updateCount
          && actual.interruptCount == expected.interruptCount
          && actual.lastUpdate == expected.lastUpdate
      }
    }
    let regionalCPUReferenceWithinTolerance =
      regionalMaximumAbsoluteError <= regionalTolerance
    let totalRegionalInterruptCount = materialized.regionalStates.reduce(0) {
      result, environment in
      result + environment.states.reduce(0) { $0 + Int($1.interruptCount) }
    }
    let regionalOwnershipAndInterruptIsolationExact =
      materialized.regionalStates.map(\.environmentIdentifier)
      == plan.activeEnvironmentIdentifiers
      && materialized.regionalStates.allSatisfy {
        $0.states.count == schedule.modules.count
      }
      && totalRegionalInterruptCount == interruptDeliveryCount
      && materialized.regionalIndirectThreadgroupCount
        == UInt32((plan.activeEnvironmentIdentifiers.count + 63) / 64)
    let tokenReferenceIdentifiers = Set([
      plan.activeEnvironmentIdentifiers[0],
      plan.activeEnvironmentIdentifiers[
        plan.activeEnvironmentIdentifiers.count / 2
      ],
      plan.activeEnvironmentIdentifiers[plan.activeEnvironmentIdentifiers.count - 1],
    ])
    let tokenTolerance: Float = 3e-6
    var tokenMaximumAbsoluteError: Float = 0
    let routingTolerance: Float = 3e-6
    var routingMaximumAbsoluteError: Float = 0
    var routingDiscreteStateExact = true
    for environment in materialized.tokenStates
    where tokenReferenceIdentifiers.contains(environment.environmentIdentifier) {
      guard
        let initialTokens = initialTokenStatesByIdentifier[
          environment.environmentIdentifier
        ],
        let initialDiagnostics = initialRegionalStatesByIdentifier[
          environment.environmentIdentifier
        ]
      else {
        throw DispatchCLIError("cohort regional-token input ownership is incomplete")
      }
      let reference = try CPURegionalTokenOperator.advance(
        state: initialTokens,
        diagnostics: initialDiagnostics,
        schedule: schedule,
        program: program,
        invocations: plan.invocations(for: environment.environmentIdentifier)
      )
      guard environment.values.count == reference.values.count else {
        throw DispatchCLIError("cohort regional-token output shape drifted")
      }
      for (actual, expected) in zip(environment.values, reference.values) {
        tokenMaximumAbsoluteError = max(tokenMaximumAbsoluteError, abs(actual - expected))
      }
      guard
        let actualRouting = materialized.routingStates.first(where: {
          $0.environmentIdentifier == environment.environmentIdentifier
        })
      else {
        throw DispatchCLIError("cohort routing output ownership is incomplete")
      }
      routingDiscreteStateExact = routingDiscreteStateExact
        && actualRouting.routeHistory.states == reference.routeHistory.states
        && actualRouting.routeHistory.timestamps == reference.routeHistory.timestamps
        && actualRouting.routingState.states.map(\.isActive)
          == reference.routingState.states.map(\.isActive)
        && actualRouting.routingState.states.map(\.selectionCount)
          == reference.routingState.states.map(\.selectionCount)
        && actualRouting.routingState.states.map(\.lastSelectedTimestamp)
          == reference.routingState.states.map(\.lastSelectedTimestamp)
        && actualRouting.routingState.states.map(\.switchCount)
          == reference.routingState.states.map(\.switchCount)
      for (actual, expected) in zip(
        actualRouting.routeHistory.values,
        reference.routeHistory.values
      ) {
        routingMaximumAbsoluteError = max(
          routingMaximumAbsoluteError,
          abs(actual - expected)
        )
      }
      for (actual, expected) in zip(
        actualRouting.routingState.states,
        reference.routingState.states
      ) {
        routingMaximumAbsoluteError = max(
          routingMaximumAbsoluteError,
          abs(actual.score - expected.score),
          abs(actual.strength - expected.strength)
        )
      }
    }
    let tokenCPUReferenceWithinTolerance = tokenMaximumAbsoluteError <= tokenTolerance
    let tokenOwnershipExact =
      materialized.tokenStates.map(\.environmentIdentifier)
      == plan.activeEnvironmentIdentifiers
      && materialized.tokenStates.allSatisfy {
        $0.values.count == program.scalarCount
      }
      && materialized.tokenIndirectThreadgroupCount
        == UInt32(plan.activeEnvironmentIdentifiers.count)
    let routingCPUReferenceWithinTolerance =
      routingMaximumAbsoluteError <= routingTolerance
    let routingOwnershipExact =
      materialized.routingStates.map(\.environmentIdentifier)
        == plan.activeEnvironmentIdentifiers
      && materialized.routingStates.allSatisfy {
        $0.routeHistory.states.count == program.routes.count
          && $0.routeHistory.capacity == program.compiledRouteHistoryCapacity
          && $0.routeHistory.values.count == program.routeHistoryScalarCount
          && $0.routingState.states.count == program.routes.count
      }
    let replayExact =
      replay.groups == materialized.groups
      && replay.workItems == materialized.workItems
      && replay.workFingerprint == materialized.workFingerprint
      && replay.regionalStates == materialized.regionalStates
      && replay.regionalStateFingerprint == materialized.regionalStateFingerprint
      && replay.tokenStates == materialized.tokenStates
      && replay.tokenStateFingerprint == materialized.tokenStateFingerprint
      && replay.routingStates == materialized.routingStates
      && replay.routingStateFingerprint == materialized.routingStateFingerprint
      && replay.planFingerprint == materialized.planFingerprint
      && replay.parameterVersionFingerprint == materialized.parameterVersionFingerprint
      && replay.status == materialized.status
    guard retryExact, shadowStateUnchanged, reversed == plan, materializationExact,
      indirectConsumptionExact, regionalCPUReferenceWithinTolerance,
      regionalDiscreteStateExact, regionalOwnershipAndInterruptIsolationExact,
      tokenCPUReferenceWithinTolerance, tokenOwnershipExact, replayExact,
      routingCPUReferenceWithinTolerance, routingDiscreteStateExact,
      routingOwnershipExact,
      staleParameterVersionRejected
    else {
      throw DispatchCLIError("cohort materialization verification failed")
    }

    return DispatchEvidence(
      schema: "numibrain.cohort-dispatch-evidence.v5",
      revision: ProcessInfo.processInfo.environment["NUMIBRAIN_REVISION"] ?? "unknown",
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      abi: ABIEvidence(
        planVersion: BrainDispatchPlan.planVersion,
        cohortEnvironmentBytes: BrainDispatchPlan.environmentByteCount,
        groupBytes: BrainDispatchPlan.groupByteCount,
        entryBytes: BrainDispatchPlan.entryByteCount,
        headerBytes: BrainDispatchPlan.headerByteCount,
        resultBytes: BrainDispatchPlan.resultByteCount,
        workItemBytes: BrainDispatchPlan.workItemByteCount,
        cohortUniformBytes: BrainDispatchPlan.cohortUniformByteCount,
        tokenUniformBytes: BrainDispatchPlan.tokenUniformByteCount,
        regionalStateBytes: RegionalModuleState.abiByteCount,
        regionalRouteBytes: Int(NB_REGIONAL_ROUTE_BYTE_COUNT),
        routeHistoryStateBytes: Int(NB_REGIONAL_ROUTE_HISTORY_STATE_BYTE_COUNT),
        routeRuntimeStateBytes: Int(NB_REGIONAL_ROUTE_RUNTIME_STATE_BYTE_COUNT),
        parameterBindingBytes: BrainParameterVersion.bindingByteCount
      ),
      identity: IdentityEvidence(
        scheduleFingerprint: schedule.fingerprintHex,
        regionalProgramFingerprint: program.fingerprintHex,
        parameterVersionFingerprint: version.fingerprintHex,
        cohortFingerprint: plan.cohortFingerprintHex,
        dispatchPlanFingerprint: plan.fingerprintHex,
        dispatchWorkFingerprint: String(format: "%016llx", plan.workFingerprint),
        regionalStateFingerprint: String(
          format: "%016llx",
          materialized.regionalStateFingerprint
        ),
        tokenStateFingerprint: String(
          format: "%016llx",
          materialized.tokenStateFingerprint
        ),
        routingStateFingerprint: String(
          format: "%016llx",
          materialized.routingStateFingerprint
        )
      ),
      cohort: CohortEvidence(
        environmentCount: options.environmentCount,
        moduleCount: schedule.modules.count,
        sourceInvocationCount: sourceInvocationCount,
        interruptDeliveryCount: interruptDeliveryCount,
        dispatchGroupCount: plan.groups.count,
        dispatchEntryCount: plan.entryCount,
        maximumEnvironmentCountPerGroup: plan.groups.map { $0.entries.count }.max() ?? 0,
        tokenScalarsPerEnvironment: program.scalarCount,
        routeCount: program.routes.count,
        routeHistoryCapacity: program.compiledRouteHistoryCapacity,
        routeHistoryScalarsPerEnvironment: program.routeHistoryScalarCount
      ),
      metal: MetalEvidence(
        device: materialized.deviceName,
        privateInputBytes: materialized.privateInputByteCount,
        privateOutputBytes: materialized.privateOutputByteCount,
        workItemCount: materialized.workItems.count,
        workItemBytes: materialized.workItems.count * BrainDispatchPlan.workItemByteCount,
        indirectThreadgroupCount: materialized.indirectThreadgroupCount,
        regionalEnvironmentCount: materialized.regionalStates.count,
        regionalStateBytes: materialized.regionalStateByteCount,
        regionalIndirectThreadgroupCount: materialized.regionalIndirectThreadgroupCount,
        tokenEnvironmentCount: materialized.tokenStates.count,
        tokenStateBytes: materialized.tokenStateByteCount,
        tokenIndirectThreadgroupCount: materialized.tokenIndirectThreadgroupCount,
        routingEnvironmentCount: materialized.routingStates.count,
        routeHistoryBytes: materialized.routeHistoryByteCount,
        routeRuntimeStateBytes: materialized.routeRuntimeStateByteCount,
        status: materialized.status,
        gpuSeconds: materialized.gpuDurationSeconds,
        execution:
          "Metal 4 private immutable plan, parameter, schedule, diagnostic, token, route-history and routing-state inputs -> 2D timestamp/module by environment materialization -> device barrier -> GPU-generated indirect work expansion, compact diagnostic advance and one-threadgroup-per-agent routed token advance -> private transactional generations -> explicit post-completion inspection"
      ),
      verification: VerificationEvidence(
        retryExact: retryExact,
        discardedShadowStateUnchanged: shadowStateUnchanged,
        canonicalInputOrderExact: reversed == plan,
        gpuMaterializationExact: materializationExact,
        gpuIndirectConsumptionExact: indirectConsumptionExact,
        gpuRegionalCPUReferenceWithinTolerance: regionalCPUReferenceWithinTolerance,
        gpuRegionalDiscreteStateExact: regionalDiscreteStateExact,
        gpuRegionalOwnershipAndInterruptIsolationExact:
          regionalOwnershipAndInterruptIsolationExact,
        regionalCPUReferenceMaximumAbsoluteError: Double(regionalMaximumAbsoluteError),
        regionalCPUReferenceTolerance: Double(regionalTolerance),
        gpuTokenCPUReferenceWithinTolerance: tokenCPUReferenceWithinTolerance,
        gpuTokenOwnershipExact: tokenOwnershipExact,
        tokenCPUReferenceMaximumAbsoluteError: Double(tokenMaximumAbsoluteError),
        tokenCPUReferenceTolerance: Double(tokenTolerance),
        tokenCPUReferenceSampleCount: tokenReferenceIdentifiers.count,
        gpuRoutingCPUReferenceWithinTolerance: routingCPUReferenceWithinTolerance,
        gpuRoutingDiscreteStateExact: routingDiscreteStateExact,
        gpuRoutingOwnershipExact: routingOwnershipExact,
        routingCPUReferenceMaximumAbsoluteError: Double(routingMaximumAbsoluteError),
        routingCPUReferenceTolerance: Double(routingTolerance),
        gpuReplayExact: replayExact,
        staleParameterVersionRejected: staleParameterVersionRejected
      ),
      executionPath:
        "independent version-bound scheduler shadows -> compiled canonical cohort plan -> private Metal 4 region-major materialization -> GPU-generated indirect work expansion -> independent compact diagnostic plus routed 10752-scalar recurrent token, delayed-history and dynamic route-state generations",
      limitations: [
        "The CPU oracle currently compiles cohort membership before GPU materialization.",
        "The bounded cohort profile compiles 32 delayed publications per route and rejects a root plan if that capacity cannot preserve every observable delayed value.",
        "Token and routing CPU parity are sampled across deterministic boundary and interrupt-owning environments; ownership, shape and replay are checked across the full cohort.",
        "GPU seconds are command-feedback telemetry for materialization and three indirect consumers, not a production throughput or counter qualification.",
        "The eight-module runtime-foundation subset is not the complete 96-module graph.",
      ]
    )
  }

  private static func configuredEvents(
    environmentIndex: Int,
    environmentCount: Int,
    targetMicroseconds: UInt64
  ) throws -> [BrainInterruptEvent] {
    var events: [BrainInterruptEvent] = []
    if environmentIndex == 0 {
      events.append(
        try BrainInterruptEvent(
          timestamp: BrainTimestamp(microseconds: max(1, targetMicroseconds / 3)),
          mask: .pain,
          identifier: 1
        )
      )
    }
    if environmentIndex == environmentCount / 2 {
      events.append(
        try BrainInterruptEvent(
          timestamp: BrainTimestamp(microseconds: max(1, targetMicroseconds / 2)),
          mask: .impact,
          identifier: 2
        )
      )
    }
    if environmentIndex == environmentCount - 1 {
      events.append(
        try BrainInterruptEvent(
          timestamp: BrainTimestamp(microseconds: max(1, targetMicroseconds * 2 / 3)),
          mask: .lossOfSupport,
          identifier: 3
        )
      )
    }
    return events
  }
}

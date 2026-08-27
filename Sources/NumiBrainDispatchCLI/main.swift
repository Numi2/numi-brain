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
  let regionalStateBytes: Int
  let parameterBindingBytes: Int
}

private struct IdentityEvidence: Codable {
  let scheduleFingerprint: String
  let parameterVersionFingerprint: String
  let cohortFingerprint: String
  let dispatchPlanFingerprint: String
  let dispatchWorkFingerprint: String
  let regionalStateFingerprint: String
}

private struct CohortEvidence: Codable {
  let environmentCount: Int
  let moduleCount: Int
  let sourceInvocationCount: Int
  let interruptDeliveryCount: Int
  let dispatchGroupCount: Int
  let dispatchEntryCount: Int
  let maximumEnvironmentCountPerGroup: Int
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
    let program = try RegionalTokenProgram.runtimeFoundationV0(schedule: schedule)
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
    let materialized = try MetalDispatchPlanRuntime.materialize(
      plan: plan,
      schedule: schedule,
      parameterVersion: version,
      initialRegionalStates: initialRegionalStates
    )
    let replay = try MetalDispatchPlanRuntime.materialize(
      plan: plan,
      schedule: schedule,
      parameterVersion: version,
      initialRegionalStates: initialRegionalStates
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
    let replayExact =
      replay.groups == materialized.groups
      && replay.workItems == materialized.workItems
      && replay.workFingerprint == materialized.workFingerprint
      && replay.regionalStates == materialized.regionalStates
      && replay.regionalStateFingerprint == materialized.regionalStateFingerprint
      && replay.planFingerprint == materialized.planFingerprint
      && replay.parameterVersionFingerprint == materialized.parameterVersionFingerprint
      && replay.status == materialized.status
    guard retryExact, shadowStateUnchanged, reversed == plan, materializationExact,
      indirectConsumptionExact, regionalCPUReferenceWithinTolerance,
      regionalDiscreteStateExact, regionalOwnershipAndInterruptIsolationExact,
      replayExact, staleParameterVersionRejected
    else {
      throw DispatchCLIError("cohort materialization verification failed")
    }

    return DispatchEvidence(
      schema: "numibrain.cohort-dispatch-evidence.v3",
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
        regionalStateBytes: RegionalModuleState.abiByteCount,
        parameterBindingBytes: BrainParameterVersion.bindingByteCount
      ),
      identity: IdentityEvidence(
        scheduleFingerprint: schedule.fingerprintHex,
        parameterVersionFingerprint: version.fingerprintHex,
        cohortFingerprint: plan.cohortFingerprintHex,
        dispatchPlanFingerprint: plan.fingerprintHex,
        dispatchWorkFingerprint: String(format: "%016llx", plan.workFingerprint),
        regionalStateFingerprint: String(
          format: "%016llx",
          materialized.regionalStateFingerprint
        )
      ),
      cohort: CohortEvidence(
        environmentCount: options.environmentCount,
        moduleCount: schedule.modules.count,
        sourceInvocationCount: sourceInvocationCount,
        interruptDeliveryCount: interruptDeliveryCount,
        dispatchGroupCount: plan.groups.count,
        dispatchEntryCount: plan.entryCount,
        maximumEnvironmentCountPerGroup: plan.groups.map { $0.entries.count }.max() ?? 0
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
        status: materialized.status,
        gpuSeconds: materialized.gpuDurationSeconds,
        execution:
          "Metal 4 private immutable plan, parameter, schedule and state inputs -> 2D timestamp/module by environment materialization -> device barrier -> GPU-generated indirect work expansion and independent cohort regional-state advance -> private outputs -> explicit post-completion inspection"
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
        gpuReplayExact: replayExact,
        staleParameterVersionRejected: staleParameterVersionRejected
      ),
      executionPath:
        "independent version-bound scheduler shadows -> compiled canonical cohort plan -> private Metal 4 region-major materialization -> GPU-generated indirect work expansion and independent compact recurrent regional-state generations",
      limitations: [
        "The CPU oracle currently compiles cohort membership before GPU materialization.",
        "The regional kernel advances the compact 32-byte diagnostic state per module, not the authoritative 10752-scalar regional token state.",
        "GPU seconds are command-feedback telemetry for materialization and both indirect consumers, not a production throughput or counter qualification.",
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

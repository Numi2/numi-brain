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
  let parameterBindingBytes: Int
}

private struct IdentityEvidence: Codable {
  let scheduleFingerprint: String
  let parameterVersionFingerprint: String
  let cohortFingerprint: String
  let dispatchPlanFingerprint: String
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
  let status: UInt32
  let gpuSeconds: Double
  let execution: String
}

private struct VerificationEvidence: Codable {
  let retryExact: Bool
  let discardedShadowStateUnchanged: Bool
  let canonicalInputOrderExact: Bool
  let gpuMaterializationExact: Bool
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
      interruptDeliveryCount += transaction.invocations.filter {
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
    let materialized = try MetalDispatchPlanRuntime.materialize(
      plan: plan,
      parameterVersion: version
    )
    let replay = try MetalDispatchPlanRuntime.materialize(
      plan: plan,
      parameterVersion: version
    )
    let successor = try version.successor(
      regionalProgramFingerprint: version.regionalProgramFingerprint,
      components: version.components
    )
    let staleParameterVersionRejected: Bool
    do {
      _ = try MetalDispatchPlanRuntime.materialize(
        plan: plan,
        parameterVersion: successor
      )
      staleParameterVersionRejected = false
    } catch {
      staleParameterVersionRejected = true
    }
    let materializationExact = materialized.groups == plan.groups
      && materialized.planFingerprint == plan.fingerprint
      && materialized.parameterVersionFingerprint == version.fingerprint
      && materialized.status == 0
    let replayExact = replay.groups == materialized.groups
      && replay.planFingerprint == materialized.planFingerprint
      && replay.parameterVersionFingerprint == materialized.parameterVersionFingerprint
      && replay.status == materialized.status
    guard retryExact, shadowStateUnchanged, reversed == plan, materializationExact,
      replayExact, staleParameterVersionRejected
    else {
      throw DispatchCLIError("cohort materialization verification failed")
    }

    return DispatchEvidence(
      schema: "numibrain.cohort-dispatch-evidence.v1",
      revision: ProcessInfo.processInfo.environment["NUMIBRAIN_REVISION"] ?? "unknown",
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      abi: ABIEvidence(
        planVersion: BrainDispatchPlan.planVersion,
        cohortEnvironmentBytes: BrainDispatchPlan.environmentByteCount,
        groupBytes: BrainDispatchPlan.groupByteCount,
        entryBytes: BrainDispatchPlan.entryByteCount,
        headerBytes: BrainDispatchPlan.headerByteCount,
        resultBytes: BrainDispatchPlan.resultByteCount,
        parameterBindingBytes: BrainParameterVersion.bindingByteCount
      ),
      identity: IdentityEvidence(
        scheduleFingerprint: schedule.fingerprintHex,
        parameterVersionFingerprint: version.fingerprintHex,
        cohortFingerprint: plan.cohortFingerprintHex,
        dispatchPlanFingerprint: plan.fingerprintHex
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
        status: materialized.status,
        gpuSeconds: materialized.gpuDurationSeconds,
        execution:
          "Metal 4 private immutable plan and parameter inputs -> 2D timestamp/module by environment materialization -> private group and entry outputs -> explicit post-completion inspection"
      ),
      verification: VerificationEvidence(
        retryExact: retryExact,
        discardedShadowStateUnchanged: shadowStateUnchanged,
        canonicalInputOrderExact: reversed == plan,
        gpuMaterializationExact: materializationExact,
        gpuReplayExact: replayExact,
        staleParameterVersionRejected: staleParameterVersionRejected
      ),
      executionPath:
        "independent version-bound scheduler shadows -> compiled canonical cohort plan -> private Metal 4 region-major dispatch materialization",
      limitations: [
        "The CPU oracle currently compiles cohort membership before GPU materialization.",
        "The Metal kernel materializes compact dispatch records; indirect regional execution across the cohort is not yet connected.",
        "GPU seconds are command-feedback telemetry, not a production throughput or counter qualification.",
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

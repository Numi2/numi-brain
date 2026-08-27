import Foundation
import NumiBrainABI
import NumiBrainCore

private struct Options {
  var durationMilliseconds = 200
  var controlMilliseconds = 20
  var environmentCount = 4
  var outputPath: String?

  static func parse(_ arguments: [String]) throws -> Self {
    var options = Self()
    var index = 0
    while index < arguments.count {
      let argument = arguments[index]
      func value() throws -> String {
        guard index + 1 < arguments.count else {
          throw SchedulerCLIError("missing value after \(argument)")
        }
        index += 1
        return arguments[index]
      }
      switch argument {
      case "--duration-ms":
        options.durationMilliseconds = try positiveInteger(value(), name: argument)
      case "--control-ms":
        options.controlMilliseconds = try positiveInteger(value(), name: argument)
      case "--environments":
        options.environmentCount = try positiveInteger(value(), name: argument)
      case "--output":
        options.outputPath = try value()
      case "--help":
        printHelp()
        Foundation.exit(EXIT_SUCCESS)
      default:
        throw SchedulerCLIError("unknown argument: \(argument)")
      }
      index += 1
    }
    guard options.environmentCount <= 4_096 else {
      throw SchedulerCLIError("--environments exceeds the 4096-agent oracle limit")
    }
    guard options.durationMilliseconds <= 60_000 else {
      throw SchedulerCLIError("--duration-ms exceeds the 60000 ms oracle limit")
    }
    guard options.controlMilliseconds <= 1_000 else {
      throw SchedulerCLIError("--control-ms exceeds the 1000 ms oracle limit")
    }
    return options
  }

  private static func positiveInteger(_ value: String, name: String) throws -> Int {
    guard let parsed = Int(value), parsed > 0 else {
      throw SchedulerCLIError("\(name) must be a positive integer")
    }
    return parsed
  }

  private static func printHelp() {
    print(
      """
      Usage: numi-brain-scheduler [options]

        --duration-ms N  Accepted physical duration (default: 200, max: 60000)
        --control-ms N   Root transaction interval (default: 20, max: 1000)
        --environments N Independent CPU-oracle minds (default: 4, max: 4096)
        --output PATH    Write deterministic JSON evidence
        --help           Show this help
      """
    )
  }
}

private struct SchedulerCLIError: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}

private struct ABIEvidence: Codable {
  let version: UInt32
  let moduleDescriptorBytes: Int
  let moduleClockStateBytes: Int
  let interruptEventBytes: Int
  let dueInvocationBytes: Int
  let scheduleFingerprint: String
  let owner: String
}

private struct TimingEvidence: Codable {
  let durationMicroseconds: UInt64
  let controlIntervalMicroseconds: UInt64
  let rootTransactions: Int
  let wallSeconds: Double
}

private struct ScheduleEvidence: Codable {
  let moduleCount: Int
  let modules: [BrainModuleDescriptor]
  let totalInvocations: Int
  let periodicInvocations: Int
  let interruptInvocations: Int
  let dispatchGroupCount: Int
  let maximumEnvironmentCountPerGroup: Int
}

private struct EventEvidence: Codable {
  let sourceEventCount: Int
  let deliveredModuleInterruptCount: Int
  let zeroLatency: Bool
  let timestampsMicroseconds: [UInt64]
  let interpretation: String
}

private struct VerificationEvidence: Codable {
  let replayExact: Bool
  let retryExact: Bool
  let abortExact: Bool
  let independentMinds: Bool
  let canonicalCohortOrder: Bool
  let finalSnapshotHashes: [String]
}

private struct SchedulerEvidence: Codable {
  let schema: String
  let revision: String
  let operatingSystem: String
  let backend: String
  let numericalScope: String
  let abi: ABIEvidence
  let timing: TimingEvidence
  let schedule: ScheduleEvidence
  let events: EventEvidence
  let verification: VerificationEvidence
  let executionPath: String
  let limitations: [String]
}

private struct OracleRun: Equatable {
  let snapshots: [BrainSchedulerSnapshot]
  let totalInvocations: Int
  let periodicInvocations: Int
  let interruptInvocations: Int
  let dispatchGroupCount: Int
  let maximumEnvironmentCountPerGroup: Int
  let deliveredEventTimestamps: [UInt64]
  let retryExact: Bool
  let abortExact: Bool
  let canonicalCohortOrder: Bool
}

@main
private struct NumiBrainSchedulerCommand {
  static func main() {
    do {
      let options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
      let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
      let start = ContinuousClock.now
      let first = try runOracle(options: options, schedule: schedule)
      let second = try runOracle(options: options, schedule: schedule)
      let independentMinds = try verifyIndependentMinds(schedule: schedule)
      let elapsed = start.duration(to: .now).components
      let wallSeconds =
        Double(elapsed.seconds)
        + Double(elapsed.attoseconds) / 1_000_000_000_000_000_000
      let sourceEvents = try configuredEvents(
        environmentCount: options.environmentCount,
        durationMicroseconds: UInt64(options.durationMilliseconds) * 1_000
      )
      let evidence = SchedulerEvidence(
        schema: "numibrain.scheduler-evidence.v1",
        revision: ProcessInfo.processInfo.environment["NUMIBRAIN_REVISION"] ?? "unknown",
        operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
        backend: "Swift deterministic CPU oracle over compiled C++ ABI",
        numericalScope:
          "physical-time module scheduling and event interruption; no neural regional computation",
        abi: ABIEvidence(
          version: BrainModuleSchedule.abiVersion,
          moduleDescriptorBytes: Int(nb_brain_abi_module_descriptor_size()),
          moduleClockStateBytes: Int(nb_brain_abi_module_clock_state_size()),
          interruptEventBytes: Int(nb_brain_abi_interrupt_event_size()),
          dueInvocationBytes: Int(nb_brain_abi_due_invocation_size()),
          scheduleFingerprint: schedule.fingerprintHex,
          owner: "NumiBrainABI C++ static layout assertions and explicit field fingerprint"
        ),
        timing: TimingEvidence(
          durationMicroseconds: UInt64(options.durationMilliseconds) * 1_000,
          controlIntervalMicroseconds: UInt64(options.controlMilliseconds) * 1_000,
          rootTransactions: (options.durationMilliseconds + options.controlMilliseconds - 1)
            / options.controlMilliseconds,
          wallSeconds: wallSeconds
        ),
        schedule: ScheduleEvidence(
          moduleCount: schedule.modules.count,
          modules: schedule.modules,
          totalInvocations: first.totalInvocations,
          periodicInvocations: first.periodicInvocations,
          interruptInvocations: first.interruptInvocations,
          dispatchGroupCount: first.dispatchGroupCount,
          maximumEnvironmentCountPerGroup: first.maximumEnvironmentCountPerGroup
        ),
        events: EventEvidence(
          sourceEventCount: sourceEvents.values.reduce(0) { $0 + $1.count },
          deliveredModuleInterruptCount: first.interruptInvocations,
          zeroLatency: Set(first.deliveredEventTimestamps).isSubset(
            of: Set(sourceEvents.values.flatMap { $0.map(\.timestamp.rawValue) })
          ),
          timestampsMicroseconds: first.deliveredEventTimestamps,
          interpretation:
            "timestamped receptor-derived interrupt classes; no privileged physical state"
        ),
        verification: VerificationEvidence(
          replayExact: first == second,
          retryExact: first.retryExact,
          abortExact: first.abortExact,
          independentMinds: independentMinds,
          canonicalCohortOrder: first.canonicalCohortOrder,
          finalSnapshotHashes: first.snapshots.map { $0.stableHash() }
        ),
        executionPath:
          "physical microseconds -> shadow due/event merge -> module/time cohort compaction -> commit",
        limitations: [
          "CPU oracle only; the production scheduler kernel is not yet Metal-resident",
          "Eight logical modules qualify the ABI and scheduler, not the complete 96-module graph",
          "Cohort compaction is a deterministic host reference, not GPU prefix-sum dispatch",
        ]
      )
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      let data = try encoder.encode(evidence)
      if let outputPath = options.outputPath {
        try data.write(
          to: URL(fileURLWithPath: outputPath),
          options: Data.WritingOptions.atomic
        )
      }
      FileHandle.standardOutput.write(data)
      FileHandle.standardOutput.write(Data("\n".utf8))
      guard first == second, first.retryExact, first.abortExact else {
        throw SchedulerCLIError("scheduler replay or transaction verification failed")
      }
    } catch {
      FileHandle.standardError.write(Data("error: \(error)\n".utf8))
      Foundation.exit(EXIT_FAILURE)
    }
  }

  private static func runOracle(
    options: Options,
    schedule: BrainModuleSchedule
  ) throws -> OracleRun {
    var schedulers = (0..<options.environmentCount).map { _ in
      CPUMultiRateScheduler(schedule: schedule)
    }
    let duration = UInt64(options.durationMilliseconds) * 1_000
    let control = UInt64(options.controlMilliseconds) * 1_000
    let eventMap = try configuredEvents(
      environmentCount: options.environmentCount,
      durationMicroseconds: duration
    )
    var start: UInt64 = 0
    var rootIndex = 0
    var totalInvocations = 0
    var periodicInvocations = 0
    var interruptInvocations = 0
    var dispatchGroupCount = 0
    var maximumEnvironmentCountPerGroup = 0
    var deliveredEventTimestamps: Set<UInt64> = []
    var retryExact = true
    var abortExact = true
    var canonicalCohortOrder = true

    while start < duration {
      let target = min(start + control, duration)
      var environments: [BrainScheduledEnvironment] = []
      for index in schedulers.indices {
        let identifier = UInt32(index)
        let windowEvents = (eventMap[identifier] ?? []).filter { event in
          if rootIndex == 0 {
            return event.timestamp.rawValue >= start && event.timestamp.rawValue <= target
          }
          return event.timestamp.rawValue > start && event.timestamp.rawValue <= target
        }
        let before = schedulers[index].snapshot
        let transaction = try schedulers[index].beginAdvance(
          to: BrainTimestamp(microseconds: target),
          events: windowEvents
        )
        let retry = try schedulers[index].beginAdvance(
          to: BrainTimestamp(microseconds: target),
          events: Array(windowEvents.reversed())
        )
        retryExact = retryExact && transaction == retry
        abortExact = abortExact && schedulers[index].snapshot == before
        environments.append(
          BrainScheduledEnvironment(
            environmentIdentifier: identifier,
            transaction: transaction
          )
        )
      }
      let groups = try BrainSchedulerCohort.compact(environments)
      dispatchGroupCount += groups.count
      maximumEnvironmentCountPerGroup = max(
        maximumEnvironmentCountPerGroup,
        groups.map { $0.entries.count }.max() ?? 0
      )
      canonicalCohortOrder =
        canonicalCohortOrder
        && groups.allSatisfy { group in
          group.entries.map(\.environmentIdentifier)
            == group.entries.map(\.environmentIdentifier).sorted()
        }
      for environment in environments {
        let invocations = environment.transaction.invocations
        totalInvocations += invocations.count
        periodicInvocations += invocations.filter { $0.reasons.contains(.periodic) }.count
        let interrupted = invocations.filter { $0.reasons.contains(.interrupt) }
        interruptInvocations += interrupted.count
        deliveredEventTimestamps.formUnion(interrupted.map(\.timestamp.rawValue))
        let index = Int(environment.environmentIdentifier)
        try schedulers[index].commit(environment.transaction)
      }
      start = target
      rootIndex += 1
    }

    return OracleRun(
      snapshots: schedulers.map(\.snapshot),
      totalInvocations: totalInvocations,
      periodicInvocations: periodicInvocations,
      interruptInvocations: interruptInvocations,
      dispatchGroupCount: dispatchGroupCount,
      maximumEnvironmentCountPerGroup: maximumEnvironmentCountPerGroup,
      deliveredEventTimestamps: deliveredEventTimestamps.sorted(),
      retryExact: retryExact,
      abortExact: abortExact,
      canonicalCohortOrder: canonicalCohortOrder
    )
  }

  private static func configuredEvents(
    environmentCount: Int,
    durationMicroseconds: UInt64
  ) throws -> [UInt32: [BrainInterruptEvent]] {
    guard environmentCount > 0 else { return [:] }
    let candidates: [(UInt32, UInt64, BrainInterruptMask, UInt32)] = [
      (0, 7_500, .pain, 1),
      (0, 63_750, .lossOfSupport, 2),
      (UInt32(environmentCount - 1), 120_125, .physiologicalCritical, 3),
    ]
    var result: [UInt32: [BrainInterruptEvent]] = [:]
    for (environment, timestamp, mask, identifier) in candidates
    where timestamp <= durationMicroseconds {
      result[environment, default: []].append(
        try BrainInterruptEvent(
          timestamp: BrainTimestamp(microseconds: timestamp),
          mask: mask,
          identifier: identifier
        )
      )
    }
    return result
  }

  private static func verifyIndependentMinds(schedule: BrainModuleSchedule) throws -> Bool {
    var first = CPUMultiRateScheduler(schedule: schedule)
    let second = CPUMultiRateScheduler(schedule: schedule)
    let untouched = second.snapshot
    _ = try first.advance(to: BrainTimestamp(microseconds: 1_000))
    return second.snapshot == untouched && first.snapshot != second.snapshot
  }
}

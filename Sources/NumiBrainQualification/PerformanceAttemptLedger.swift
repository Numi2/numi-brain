import Foundation

public enum PerformanceAttemptOutcome: String, Codable, Sendable {
  case accepted, rejected, commandFailed
}

/// One completed observation of an attempted root, including failures. Wall
/// timestamps are one monotonic clock; physical timestamps are integer simulation
/// time. A command failure has UNKNOWN public state, not a fabricated rollback.
public struct PerformanceAttemptObservation: Codable, Equatable, Sendable {
  public let environment: UInt32
  public let attemptIdentifier: UInt64
  public let controlStepIdentifier: UInt64
  public let transactionFingerprint: UInt64
  public let outcome: PerformanceAttemptOutcome
  public let wallStartNanoseconds: UInt64
  public let wallEndNanoseconds: UInt64
  public let baseGeneration: UInt64
  public let publishedGeneration: UInt64?
  public let committedTimeMicroseconds: UInt64
  public let targetTimeMicroseconds: UInt64
  public let publishedTimeMicroseconds: UInt64?
  public let terminalEvidenceSHA256: String

  public init(environment: UInt32, attemptIdentifier: UInt64, controlStepIdentifier: UInt64,
    transactionFingerprint: UInt64, outcome: PerformanceAttemptOutcome,
    wallStartNanoseconds: UInt64, wallEndNanoseconds: UInt64, baseGeneration: UInt64,
    publishedGeneration: UInt64?, committedTimeMicroseconds: UInt64, targetTimeMicroseconds: UInt64,
    publishedTimeMicroseconds: UInt64?, terminalEvidenceSHA256: String) throws {
    self.environment = environment; self.attemptIdentifier = attemptIdentifier
    self.controlStepIdentifier = controlStepIdentifier; self.transactionFingerprint = transactionFingerprint
    self.outcome = outcome; self.wallStartNanoseconds = wallStartNanoseconds; self.wallEndNanoseconds = wallEndNanoseconds
    self.baseGeneration = baseGeneration; self.publishedGeneration = publishedGeneration
    self.committedTimeMicroseconds = committedTimeMicroseconds; self.targetTimeMicroseconds = targetTimeMicroseconds
    self.publishedTimeMicroseconds = publishedTimeMicroseconds; self.terminalEvidenceSHA256 = terminalEvidenceSHA256
    try validate()
  }

  public func validate() throws {
    guard attemptIdentifier > 0, controlStepIdentifier > 0, transactionFingerprint > 0,
      wallEndNanoseconds > wallStartNanoseconds, targetTimeMicroseconds > committedTimeMicroseconds,
      PerformanceRunArtifact.isSHA256(terminalEvidenceSHA256) else {
      throw QualificationError.invalid("invalid attempt identity, evidence or clocks")
    }
    switch outcome {
    case .accepted:
      let (next, overflow) = baseGeneration.addingReportingOverflow(1)
      guard !overflow, publishedGeneration == next, publishedTimeMicroseconds == targetTimeMicroseconds else {
        throw QualificationError.invalid("accepted attempt must advance exactly one generation and its declared physical interval")
      }
    case .rejected:
      guard publishedGeneration == baseGeneration, publishedTimeMicroseconds == committedTimeMicroseconds else {
        throw QualificationError.invalid("rejected attempt cannot advance committed state or physical time")
      }
    case .commandFailed:
      guard publishedGeneration == nil, publishedTimeMicroseconds == nil else {
        throw QualificationError.invalid("command failure cannot assert accepted or restored public state")
      }
    }
  }
}

public struct PerformanceAttemptLedger: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 2
  public let formatVersion: UInt32
  public let protocolSHA256: String
  public let sourceRevision: String
  public let binarySHA256: String
  public let metallibSHA256: String
  public let hardware: QualificationHardwareIdentity
  public let workload: PerformanceWorkloadIdentity
  public let warmupRootsPerEnvironment: UInt64
  public let measurementStartNanoseconds: UInt64
  public let measurementEndNanoseconds: UInt64
  public let attempts: [PerformanceAttemptObservation]
  public let peakResidentBytes: UInt64
  public let steadyResidentBytes: UInt64
  public let meanPowerWatts: Double?
  public let counters: PerformanceCounterSummary

  public init(protocolSHA256: String, sourceRevision: String, binarySHA256: String, metallibSHA256: String,
    hardware: QualificationHardwareIdentity, workload: PerformanceWorkloadIdentity,
    warmupRootsPerEnvironment: UInt64, measurementStartNanoseconds: UInt64, measurementEndNanoseconds: UInt64,
    attempts: [PerformanceAttemptObservation], peakResidentBytes: UInt64, steadyResidentBytes: UInt64,
    meanPowerWatts: Double? = nil, counters: PerformanceCounterSummary) throws {
    formatVersion = Self.formatVersion; self.protocolSHA256 = protocolSHA256; self.sourceRevision = sourceRevision
    self.binarySHA256 = binarySHA256; self.metallibSHA256 = metallibSHA256; self.hardware = hardware; self.workload = workload
    self.warmupRootsPerEnvironment = warmupRootsPerEnvironment
    self.measurementStartNanoseconds = measurementStartNanoseconds; self.measurementEndNanoseconds = measurementEndNanoseconds
    self.attempts = attempts; self.peakResidentBytes = peakResidentBytes; self.steadyResidentBytes = steadyResidentBytes
    self.meanPowerWatts = meanPowerWatts; self.counters = counters
    try validate()
  }

  public func validate() throws {
    try hardware.validate(); try workload.validate(); try counters.validate()
    guard formatVersion == Self.formatVersion, !sourceRevision.isEmpty, sourceRevision.utf8.count <= 256,
      [protocolSHA256, binarySHA256, metallibSHA256].allSatisfy(PerformanceRunArtifact.isSHA256),
      warmupRootsPerEnvironment > 0, measurementEndNanoseconds > measurementStartNanoseconds,
      !attempts.isEmpty, attempts.count <= 1_000_000, workload.environmentCount <= 65_536,
      peakResidentBytes >= steadyResidentBytes, steadyResidentBytes > 0,
      meanPowerWatts == nil || (meanPowerWatts!.isFinite && meanPowerWatts! > 0) else {
      throw QualificationError.invalid("invalid measured attempt ledger")
    }
    var prior: [UInt32: PerformanceAttemptObservation] = [:]
    var transactions: [UInt64: UInt32] = [:]
    var evidence = Set<String>()
    var accepted: [UInt32: UInt64] = [:]
    for row in attempts {
      try row.validate()
      guard row.environment < workload.environmentCount,
        row.wallStartNanoseconds >= measurementStartNanoseconds, row.wallEndNanoseconds <= measurementEndNanoseconds,
        row.targetTimeMicroseconds - row.committedTimeMicroseconds == UInt64(workload.timestepMicroseconds),
        evidence.insert(row.terminalEvidenceSHA256).inserted else {
        throw QualificationError.invalid("foreign environment, interval, timestep or reused terminal evidence")
      }
      if let old = prior[row.environment] {
        let (nextAttempt, overflow) = old.attemptIdentifier.addingReportingOverflow(1)
        guard !overflow, row.attemptIdentifier == nextAttempt, old.outcome != .commandFailed,
          row.baseGeneration == old.publishedGeneration, row.committedTimeMicroseconds == old.publishedTimeMicroseconds,
          row.wallStartNanoseconds >= old.wallEndNanoseconds else {
          throw QualificationError.invalid("attempt history has a gap, overlapping root, unresolved command fault or state discontinuity")
        }
        if row.transactionFingerprint == old.transactionFingerprint {
          guard old.outcome == .rejected, row.controlStepIdentifier == old.controlStepIdentifier,
            row.targetTimeMicroseconds == old.targetTimeMicroseconds else {
            throw QualificationError.invalid("only an exact rejected root may retry its transaction")
          }
        } else {
          let (nextControl, controlOverflow) = old.controlStepIdentifier.addingReportingOverflow(1)
          guard !controlOverflow, row.controlStepIdentifier == nextControl,
            transactions[row.transactionFingerprint] == nil else {
            throw QualificationError.invalid("foreign, replayed or skipped control identity")
          }
        }
      } else {
        guard row.attemptIdentifier == 1, transactions[row.transactionFingerprint] == nil else {
          throw QualificationError.invalid("each measured environment must start at attempt one with its own root identity")
        }
      }
      if let owner = transactions[row.transactionFingerprint], owner != row.environment {
        throw QualificationError.invalid("root identity shared between independent environments")
      }
      transactions[row.transactionFingerprint] = row.environment
      if row.outcome == .accepted { accepted[row.environment, default: 0] += 1 }
      guard accepted[row.environment, default: 0] <= workload.horizonRoots else {
        throw QualificationError.invalid("accepted horizon exceeds the declared workload")
      }
      prior[row.environment] = row
    }
    guard prior.count == Int(workload.environmentCount) else {
      throw QualificationError.invalid("one or more declared environments have no measured attempts")
    }
  }
}

/// All rates include wall time spent rejecting, retrying and failing. The
/// minimum per-environment rate prevents fast members from hiding a stalled one.
public struct PerformanceAttemptSummary: Codable, Equatable, Sendable {
  public let attemptedRoots: UInt64
  public let acceptedRoots: UInt64
  public let rejectedRoots: UInt64
  public let commandFailures: UInt64
  public let wallDurationSeconds: Double
  public let attemptLatency: LatencyDistribution
  public let maximumPerEnvironmentP99Microseconds: Double
  public let acceptedEnvironmentStepsPerSecond: Double
  public let aggregateAcceptedSimulatedSecondsPerWallSecond: Double
  public let minimumPerEnvironmentSimulatedSecondsPerWallSecond: Double
  public let amortizedResidentBytesPerEnvironment: Double
  public let energyJoulesPerAggregateAcceptedSimulatedSecond: Double?

  public init(ledger: PerformanceAttemptLedger) throws {
    try ledger.validate()
    attemptedRoots = UInt64(ledger.attempts.count)
    acceptedRoots = UInt64(ledger.attempts.filter { $0.outcome == .accepted }.count)
    rejectedRoots = UInt64(ledger.attempts.filter { $0.outcome == .rejected }.count)
    commandFailures = attemptedRoots - acceptedRoots - rejectedRoots
    wallDurationSeconds = Double(ledger.measurementEndNanoseconds - ledger.measurementStartNanoseconds) / 1_000_000_000
    let grouped = Dictionary(grouping: ledger.attempts, by: \.environment)
    func latency(_ row: PerformanceAttemptObservation) -> Double {
      Double(row.wallEndNanoseconds - row.wallStartNanoseconds) / 1_000
    }
    attemptLatency = try LatencyDistribution(samplesMicroseconds: ledger.attempts.map(latency))
    maximumPerEnvironmentP99Microseconds = try grouped.values.map {
      try LatencyDistribution(samplesMicroseconds: $0.map(latency)).p99Microseconds
    }.max()!
    acceptedEnvironmentStepsPerSecond = Double(acceptedRoots) / wallDurationSeconds
    aggregateAcceptedSimulatedSecondsPerWallSecond = Double(acceptedRoots)
      * Double(ledger.workload.timestepMicroseconds) / 1_000_000 / wallDurationSeconds
    let minimumAccepted = grouped.values.map { $0.filter { $0.outcome == .accepted }.count }.min()!
    minimumPerEnvironmentSimulatedSecondsPerWallSecond = Double(minimumAccepted)
      * Double(ledger.workload.timestepMicroseconds) / 1_000_000 / wallDurationSeconds
    amortizedResidentBytesPerEnvironment = Double(ledger.steadyResidentBytes) / Double(ledger.workload.environmentCount)
    if let power = ledger.meanPowerWatts, aggregateAcceptedSimulatedSecondsPerWallSecond > 0 {
      let energy = power / aggregateAcceptedSimulatedSecondsPerWallSecond
      guard energy.isFinite else { throw QualificationError.invalid("energy normalization overflow") }
      energyJoulesPerAggregateAcceptedSimulatedSecond = energy
    } else { energyJoulesPerAggregateAcceptedSimulatedSecond = nil }
  }
}

public struct PerformanceAttemptProtocol: Codable, Equatable, Sendable {
  public let limits: PerformanceQualificationProtocol
  public let minimumAttemptsPerEnvironment: UInt64
  public let requireCompleteAcceptedHorizon: Bool
  public let maximumRejectedFraction: Double
  public let maximumCommandFailures: UInt64

  public init(limits: PerformanceQualificationProtocol, minimumAttemptsPerEnvironment: UInt64 = 100,
    requireCompleteAcceptedHorizon: Bool = true, maximumRejectedFraction: Double = 0,
    maximumCommandFailures: UInt64 = 0) throws {
    self.limits = limits; self.minimumAttemptsPerEnvironment = minimumAttemptsPerEnvironment
    self.requireCompleteAcceptedHorizon = requireCompleteAcceptedHorizon
    self.maximumRejectedFraction = maximumRejectedFraction; self.maximumCommandFailures = maximumCommandFailures
    try validate()
  }
  public func validate() throws {
    try limits.validate()
    guard minimumAttemptsPerEnvironment >= 100, minimumAttemptsPerEnvironment <= 1_000_000,
      maximumRejectedFraction.isFinite, (0...1).contains(maximumRejectedFraction), maximumCommandFailures <= 1_000_000 else {
      throw QualificationError.invalid("invalid outcome-aware performance protocol")
    }
  }
}

public struct PerformanceAttemptEvaluation: Codable, Equatable, Sendable {
  public let scope: String
  public let promotable: Bool
  public let passed: Bool
  public let failures: [String]
  public let summary: PerformanceAttemptSummary

  /// Diagnostic verification of the SUPPLIED ledger. The Core artifact adapter
  /// must verify the actual protocol hash and native terminal evidence before
  /// these measurements can contribute to a gate-specific verified receipt.
  public init(ledger: PerformanceAttemptLedger, protocol p: PerformanceAttemptProtocol) throws {
    try p.validate()
    summary = try PerformanceAttemptSummary(ledger: ledger)
    var failures: [String] = []
    let grouped = Dictionary(grouping: ledger.attempts, by: \.environment)
    if grouped.values.contains(where: { UInt64($0.count) < p.minimumAttemptsPerEnvironment }) { failures.append("insufficient_attempts") }
    if p.requireCompleteAcceptedHorizon && grouped.values.contains(where: {
      UInt64($0.filter { $0.outcome == .accepted }.count) != ledger.workload.horizonRoots
    }) { failures.append("incomplete_accepted_horizon") }
    if Double(summary.rejectedRoots) / Double(summary.attemptedRoots) > p.maximumRejectedFraction { failures.append("rejected_fraction") }
    if summary.commandFailures > p.maximumCommandFailures { failures.append("command_failures") }
    if summary.maximumPerEnvironmentP99Microseconds > p.limits.maximumP99RootLatencyMicroseconds { failures.append("p99_root_latency") }
    if summary.minimumPerEnvironmentSimulatedSecondsPerWallSecond < p.limits.minimumSimulatedSecondsPerWallSecond { failures.append("accepted_simulation_rate") }
    if summary.acceptedEnvironmentStepsPerSecond < p.limits.minimumEnvironmentStepsPerSecond { failures.append("accepted_environment_steps") }
    if summary.amortizedResidentBytesPerEnvironment > p.limits.maximumBytesPerEnvironment { failures.append("bytes_per_environment") }
    if p.limits.requireZeroCPUWaits && ledger.counters.cpuWaitCount != 0 { failures.append("cpu_waits") }
    if p.limits.requireZeroQueueCreation && ledger.counters.queueCreationCountDuringMeasuredRegion != 0 { failures.append("queue_creation") }
    if p.limits.requireZeroHostPayloadReadback && ledger.counters.hostPayloadReadbackBytes != 0 { failures.append("host_payload_readback") }
    self.failures = failures; passed = failures.isEmpty; promotable = false
    scope = "supplied-attempt-ledger-diagnostic"
  }
}

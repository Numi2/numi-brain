import Foundation

public enum QualificationError: Error, Equatable, Sendable {
  case invalid(String)
}

@frozen
public struct QualificationHardwareIdentity: Codable, Equatable, Hashable, Sendable {
  public let machineIdentifier: String
  public let chipIdentifier: String
  public let gpuFamily: String
  public let memoryBytes: UInt64
  public let osBuild: String
  public let swiftVersion: String
  public let metalVersion: String

  public init(machineIdentifier: String, chipIdentifier: String, gpuFamily: String,
    memoryBytes: UInt64, osBuild: String, swiftVersion: String, metalVersion: String) throws {
    let strings = [machineIdentifier, chipIdentifier, gpuFamily, osBuild, swiftVersion, metalVersion]
    guard memoryBytes > 0, strings.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 256 }) else {
      throw QualificationError.invalid("hardware identity is incomplete")
    }
    self.machineIdentifier = machineIdentifier; self.chipIdentifier = chipIdentifier
    self.gpuFamily = gpuFamily; self.memoryBytes = memoryBytes; self.osBuild = osBuild
    self.swiftVersion = swiftVersion; self.metalVersion = metalVersion
  }
}

@frozen
public struct PerformanceWorkloadIdentity: Codable, Equatable, Hashable, Sendable {
  public let identifier: String
  public let environmentCount: UInt32
  public let logicalDoF: UInt32
  public let attachmentCount: UInt32
  public let femElementCount: UInt64
  public let sensorScalarCount: UInt64
  public let modelParameterCount: UInt64
  public let horizonRoots: UInt64
  public let timestepMicroseconds: UInt32
  public let deterministic: Bool
  public let fastMath: Bool

  public init(identifier: String, environmentCount: UInt32, logicalDoF: UInt32,
    attachmentCount: UInt32, femElementCount: UInt64, sensorScalarCount: UInt64,
    modelParameterCount: UInt64, horizonRoots: UInt64, timestepMicroseconds: UInt32,
    deterministic: Bool, fastMath: Bool) throws {
    guard !identifier.isEmpty, identifier.utf8.count <= 256,
      environmentCount > 0, logicalDoF > 0, horizonRoots > 0, timestepMicroseconds > 0,
      sensorScalarCount > 0, modelParameterCount > 0, !(deterministic && fastMath) else {
      throw QualificationError.invalid("performance workload identity is invalid")
    }
    self.identifier = identifier; self.environmentCount = environmentCount
    self.logicalDoF = logicalDoF; self.attachmentCount = attachmentCount
    self.femElementCount = femElementCount; self.sensorScalarCount = sensorScalarCount
    self.modelParameterCount = modelParameterCount; self.horizonRoots = horizonRoots
    self.timestepMicroseconds = timestepMicroseconds; self.deterministic = deterministic; self.fastMath = fastMath
  }
}

@frozen
public struct LatencyDistribution: Codable, Equatable, Sendable {
  public let sampleCount: UInt64
  public let minimumMicroseconds: Double
  public let p50Microseconds: Double
  public let p95Microseconds: Double
  public let p99Microseconds: Double
  public let maximumMicroseconds: Double
  public let meanMicroseconds: Double

  public init(samplesMicroseconds: [Double]) throws {
    guard !samplesMicroseconds.isEmpty, samplesMicroseconds.count <= 10_000_000,
      samplesMicroseconds.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
      throw QualificationError.invalid("latency samples are invalid")
    }
    let sorted = samplesMicroseconds.sorted()
    func quantile(_ p: Double) -> Double {
      let x = p * Double(sorted.count - 1)
      let lo = Int(x), hi = min(lo + 1, sorted.count - 1)
      let fraction = x - Double(lo)
      let legacy = sorted[lo] * (1 - fraction) + sorted[hi] * fraction
      return legacy.isFinite ? legacy : sorted[lo] + (sorted[hi] - sorted[lo]) * fraction
    }
    sampleCount = UInt64(sorted.count); minimumMicroseconds = sorted[0]
    p50Microseconds = quantile(0.50); p95Microseconds = quantile(0.95); p99Microseconds = quantile(0.99)
    maximumMicroseconds = sorted[sorted.count - 1]
    // Preserve version-1 finite arithmetic for retained historical summaries.
    // Only the overflowing path needs a scale-normalized fallback.
    let legacySum = samplesMicroseconds.reduce(0, +)
    if legacySum.isFinite { meanMicroseconds = legacySum / Double(samplesMicroseconds.count) }
    else {
      let scale = sorted[sorted.count - 1]
      let mean = scale * (sorted.reduce(0) { $0 + $1 / scale } / Double(sorted.count))
      meanMicroseconds = min(maximumMicroseconds, max(minimumMicroseconds, mean))
    }
    try validateSummary()
  }
}

@frozen
public struct PerformanceCounterSummary: Codable, Equatable, Sendable {
  public let gpuActiveFraction: Double?
  public let gpuBandwidthBytesPerSecond: Double?
  public let cacheHitFraction: Double?
  public let commandBufferCount: UInt64
  public let cpuWaitCount: UInt64
  public let queueCreationCountDuringMeasuredRegion: UInt64
  public let hostPayloadReadbackBytes: UInt64

  public init(gpuActiveFraction: Double? = nil, gpuBandwidthBytesPerSecond: Double? = nil,
    cacheHitFraction: Double? = nil, commandBufferCount: UInt64,
    cpuWaitCount: UInt64, queueCreationCountDuringMeasuredRegion: UInt64,
    hostPayloadReadbackBytes: UInt64) throws {
    for value in [gpuActiveFraction, cacheHitFraction].compactMap({ $0 }) {
      guard value.isFinite, (0...1).contains(value) else { throw QualificationError.invalid("fraction counter is invalid") }
    }
    if let bandwidth = gpuBandwidthBytesPerSecond {
      guard bandwidth.isFinite, bandwidth >= 0 else { throw QualificationError.invalid("bandwidth counter is invalid") }
    }
    self.gpuActiveFraction = gpuActiveFraction; self.gpuBandwidthBytesPerSecond = gpuBandwidthBytesPerSecond
    self.cacheHitFraction = cacheHitFraction; self.commandBufferCount = commandBufferCount
    self.cpuWaitCount = cpuWaitCount; self.queueCreationCountDuringMeasuredRegion = queueCreationCountDuringMeasuredRegion
    self.hostPayloadReadbackBytes = hostPayloadReadbackBytes
  }
}

/// Legacy version-1 summary retained for inspection and historical comparison.
/// Use PerformanceAttemptLedger for explicit accepted/rejected/fault accounting.
@frozen
public struct PerformanceRunArtifact: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let sourceRevision: String
  public let binarySHA256: String
  public let metallibSHA256: String
  public let hardware: QualificationHardwareIdentity
  public let workload: PerformanceWorkloadIdentity
  public let warmupRoots: UInt64
  public let measuredRoots: UInt64
  public let latency: LatencyDistribution
  public let simulatedSecondsPerWallSecond: Double
  public let environmentStepsPerSecond: Double
  public let peakResidentBytes: UInt64
  public let steadyResidentBytes: UInt64
  public let bytesPerEnvironment: Double
  public let meanPowerWatts: Double?
  public let energyJoulesPerSimulatedSecond: Double?
  public let counters: PerformanceCounterSummary

  public init(sourceRevision: String, binarySHA256: String, metallibSHA256: String,
    hardware: QualificationHardwareIdentity, workload: PerformanceWorkloadIdentity,
    warmupRoots: UInt64, measuredRoots: UInt64, latency: LatencyDistribution,
    simulatedSecondsPerWallSecond: Double, environmentStepsPerSecond: Double,
    peakResidentBytes: UInt64, steadyResidentBytes: UInt64, bytesPerEnvironment: Double,
    meanPowerWatts: Double? = nil, energyJoulesPerSimulatedSecond: Double? = nil,
    counters: PerformanceCounterSummary) throws {
    try hardware.validate(); try workload.validate(); try latency.validateSummary(); try counters.validate()
    guard !sourceRevision.isEmpty, sourceRevision.utf8.count <= 256,
      Self.isSHA256(binarySHA256), Self.isSHA256(metallibSHA256),
      warmupRoots > 0, measuredRoots == latency.sampleCount, measuredRoots >= 100,
      simulatedSecondsPerWallSecond.isFinite, simulatedSecondsPerWallSecond > 0,
      environmentStepsPerSecond.isFinite, environmentStepsPerSecond > 0,
      peakResidentBytes >= steadyResidentBytes, steadyResidentBytes > 0,
      bytesPerEnvironment.isFinite, bytesPerEnvironment > 0,
      meanPowerWatts == nil || (meanPowerWatts!.isFinite && meanPowerWatts! > 0),
      energyJoulesPerSimulatedSecond == nil || (energyJoulesPerSimulatedSecond!.isFinite && energyJoulesPerSimulatedSecond! > 0) else {
      throw QualificationError.invalid("performance run artifact is incomplete")
    }
    formatVersion = Self.formatVersion; self.sourceRevision = sourceRevision
    self.binarySHA256 = binarySHA256; self.metallibSHA256 = metallibSHA256
    self.hardware = hardware; self.workload = workload; self.warmupRoots = warmupRoots; self.measuredRoots = measuredRoots
    self.latency = latency; self.simulatedSecondsPerWallSecond = simulatedSecondsPerWallSecond
    self.environmentStepsPerSecond = environmentStepsPerSecond; self.peakResidentBytes = peakResidentBytes
    self.steadyResidentBytes = steadyResidentBytes; self.bytesPerEnvironment = bytesPerEnvironment
    self.meanPowerWatts = meanPowerWatts; self.energyJoulesPerSimulatedSecond = energyJoulesPerSimulatedSecond
    self.counters = counters
  }

  public static func isSHA256(_ value: String) -> Bool {
    value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
  }
}

@frozen
public struct PerformanceQualificationProtocol: Codable, Equatable, Sendable {
  public let maximumP99RootLatencyMicroseconds: Double
  public let minimumSimulatedSecondsPerWallSecond: Double
  public let minimumEnvironmentStepsPerSecond: Double
  public let maximumBytesPerEnvironment: Double
  public let requireZeroCPUWaits: Bool
  public let requireZeroQueueCreation: Bool
  public let requireZeroHostPayloadReadback: Bool

  public init(maximumP99RootLatencyMicroseconds: Double,
    minimumSimulatedSecondsPerWallSecond: Double, minimumEnvironmentStepsPerSecond: Double,
    maximumBytesPerEnvironment: Double, requireZeroCPUWaits: Bool = true,
    requireZeroQueueCreation: Bool = true, requireZeroHostPayloadReadback: Bool = true) throws {
    guard [maximumP99RootLatencyMicroseconds, minimumSimulatedSecondsPerWallSecond,
      minimumEnvironmentStepsPerSecond, maximumBytesPerEnvironment].allSatisfy({ $0.isFinite && $0 > 0 }) else {
      throw QualificationError.invalid("performance protocol is invalid")
    }
    self.maximumP99RootLatencyMicroseconds = maximumP99RootLatencyMicroseconds
    self.minimumSimulatedSecondsPerWallSecond = minimumSimulatedSecondsPerWallSecond
    self.minimumEnvironmentStepsPerSecond = minimumEnvironmentStepsPerSecond
    self.maximumBytesPerEnvironment = maximumBytesPerEnvironment
    self.requireZeroCPUWaits = requireZeroCPUWaits; self.requireZeroQueueCreation = requireZeroQueueCreation
    self.requireZeroHostPayloadReadback = requireZeroHostPayloadReadback
  }
}

/// Numeric summary check only. This is not native performance qualification.
@frozen
public struct PerformanceQualificationResult: Codable, Equatable, Sendable {
  public let passed: Bool
  public let failures: [String]

  public init(run: PerformanceRunArtifact, protocol p: PerformanceQualificationProtocol) {
    guard (try? run.validate()) != nil, (try? p.validate()) != nil else {
      passed = false; failures = ["invalid_summary_or_protocol"]; return
    }
    var failures: [String] = []
    if run.latency.p99Microseconds > p.maximumP99RootLatencyMicroseconds { failures.append("p99_root_latency") }
    if run.simulatedSecondsPerWallSecond < p.minimumSimulatedSecondsPerWallSecond { failures.append("simulated_seconds_per_wall_second") }
    if run.environmentStepsPerSecond < p.minimumEnvironmentStepsPerSecond { failures.append("environment_steps_per_second") }
    if run.bytesPerEnvironment > p.maximumBytesPerEnvironment { failures.append("bytes_per_environment") }
    if p.requireZeroCPUWaits && run.counters.cpuWaitCount != 0 { failures.append("cpu_waits") }
    if p.requireZeroQueueCreation && run.counters.queueCreationCountDuringMeasuredRegion != 0 { failures.append("queue_creation") }
    if p.requireZeroHostPayloadReadback && run.counters.hostPayloadReadbackBytes != 0 { failures.append("host_payload_readback") }
    self.failures = failures; passed = failures.isEmpty
  }
}

public enum PerformanceSweepVerifier {
  public static func verify(expected: [PerformanceWorkloadIdentity], observed: [PerformanceRunArtifact]) throws {
    guard !expected.isEmpty, expected.count <= 100_000, observed.count == expected.count else {
      throw QualificationError.invalid("performance sweep is incomplete or unbounded")
    }
    for workload in expected { try workload.validate() }
    for run in observed { try run.validate() }
    let actual = observed.map(\.workload)
    guard Set(expected).count == expected.count, Set(actual).count == actual.count, Set(actual) == Set(expected) else {
      throw QualificationError.invalid("performance sweep has missing, duplicate, or foreign workloads")
    }
    guard Set(observed.map(\.sourceRevision)).count == 1, Set(observed.map(\.binarySHA256)).count == 1,
      Set(observed.map(\.metallibSHA256)).count == 1, Set(observed.map(\.hardware)).count == 1 else {
      throw QualificationError.invalid("performance sweep mixes runtime or hardware identities")
    }
  }
}

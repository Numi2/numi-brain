import Foundation

/// Raw, retained measurements for one Gate E measured region. These values are
/// the evidence inputs; `PerformanceRunArtifact` is only their derived summary.
/// The measured region begins after warmup and contains no qualification-file
/// I/O. Resident-memory values are process-level same-device observations.
@frozen
public struct PerformanceMeasurementArtifact: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let rootLatencyMicroseconds: [Double]
  public let wallDurationSeconds: Double
  public let peakResidentBytes: UInt64
  public let steadyResidentBytes: UInt64
  public let meanPowerWatts: Double?
  public let counters: PerformanceCounterSummary

  public init(rootLatencyMicroseconds: [Double], wallDurationSeconds: Double,
    peakResidentBytes: UInt64, steadyResidentBytes: UInt64,
    meanPowerWatts: Double? = nil, counters: PerformanceCounterSummary) throws {
    guard rootLatencyMicroseconds.count >= 100,
      rootLatencyMicroseconds.count <= 10_000_000,
      rootLatencyMicroseconds.allSatisfy({ $0.isFinite && $0 >= 0 }),
      wallDurationSeconds.isFinite, wallDurationSeconds > 0,
      peakResidentBytes >= steadyResidentBytes, steadyResidentBytes > 0,
      meanPowerWatts == nil || (meanPowerWatts!.isFinite && meanPowerWatts! > 0) else {
      throw QualificationError.invalid("raw Gate E measurements are invalid")
    }
    formatVersion = Self.formatVersion
    self.rootLatencyMicroseconds = rootLatencyMicroseconds
    self.wallDurationSeconds = wallDurationSeconds
    self.peakResidentBytes = peakResidentBytes
    self.steadyResidentBytes = steadyResidentBytes
    self.meanPowerWatts = meanPowerWatts
    self.counters = counters
  }

  public func validate() throws {
    try counters.validate()
    guard formatVersion == Self.formatVersion,
      try Self(rootLatencyMicroseconds: rootLatencyMicroseconds,
        wallDurationSeconds: wallDurationSeconds,
        peakResidentBytes: peakResidentBytes,
        steadyResidentBytes: steadyResidentBytes,
        meanPowerWatts: meanPowerWatts, counters: counters) == self else {
      throw QualificationError.invalid("raw Gate E measurements are noncanonical")
    }
  }
}

public enum PerformanceEvidenceVerifier {
  /// Recomputes every derivable Gate E summary from the retained raw measured
  /// region. This prevents percentile, throughput and memory-per-environment
  /// scalars from being entered independently in a passing report.
  public static func verify(run: PerformanceRunArtifact,
    measurements: PerformanceMeasurementArtifact) throws {
    try run.validate()
    try measurements.validate()
    guard run.measuredRoots == UInt64(measurements.rootLatencyMicroseconds.count) else {
      throw QualificationError.invalid("Gate E run does not bind its raw root count")
    }
    let latency = try LatencyDistribution(samplesMicroseconds: measurements.rootLatencyMicroseconds)
    guard latency == run.latency,
      run.peakResidentBytes == measurements.peakResidentBytes,
      run.steadyResidentBytes == measurements.steadyResidentBytes,
      run.counters == measurements.counters,
      run.meanPowerWatts == measurements.meanPowerWatts else {
      throw QualificationError.invalid("Gate E derived summary differs from raw measurements")
    }

    let measuredRoots = Double(run.measuredRoots)
    let environmentCount = Double(run.workload.environmentCount)
    let expectedEnvironmentSteps = measuredRoots * environmentCount / measurements.wallDurationSeconds
    let expectedSimulatedSeconds = measuredRoots
      * Double(run.workload.timestepMicroseconds) / 1_000_000
      / measurements.wallDurationSeconds
    let expectedBytesPerEnvironment = Double(measurements.steadyResidentBytes) / environmentCount
    guard close(run.environmentStepsPerSecond, expectedEnvironmentSteps),
      close(run.simulatedSecondsPerWallSecond, expectedSimulatedSeconds),
      close(run.bytesPerEnvironment, expectedBytesPerEnvironment) else {
      throw QualificationError.invalid("Gate E throughput or memory summary is not derivable from its measured region")
    }

    if let power = measurements.meanPowerWatts {
      let expectedEnergy = power / expectedSimulatedSeconds
      guard let energy = run.energyJoulesPerSimulatedSecond,
        close(energy, expectedEnergy, relativeTolerance: 1.0e-8) else {
        throw QualificationError.invalid("Gate E energy summary does not match measured power and simulation rate")
      }
    } else if run.energyJoulesPerSimulatedSecond != nil {
      throw QualificationError.invalid("Gate E reports energy without retained power evidence")
    }
  }

  private static func close(_ a: Double, _ b: Double,
    relativeTolerance: Double = 1.0e-10) -> Bool {
    guard a.isFinite, b.isFinite else { return false }
    let scale = max(1, max(abs(a), abs(b)))
    return abs(a - b) <= relativeTolerance * scale
  }
}

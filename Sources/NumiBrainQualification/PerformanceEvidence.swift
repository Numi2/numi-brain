import Foundation

/// Legacy version-1 raw measurement summary. It does not record whether a root
/// was accepted. Retain it for historical numeric consistency checks; new
/// measurements must use the explicit PerformanceAttemptLedger outcome model.
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
    try counters.validate()
    guard rootLatencyMicroseconds.count >= 100, rootLatencyMicroseconds.count <= 10_000_000,
      rootLatencyMicroseconds.allSatisfy({ $0.isFinite && $0 >= 0 }),
      wallDurationSeconds.isFinite, wallDurationSeconds > 0,
      peakResidentBytes >= steadyResidentBytes, steadyResidentBytes > 0,
      meanPowerWatts == nil || (meanPowerWatts!.isFinite && meanPowerWatts! > 0) else {
      throw QualificationError.invalid("raw Gate E measurements are invalid")
    }
    formatVersion = Self.formatVersion; self.rootLatencyMicroseconds = rootLatencyMicroseconds
    self.wallDurationSeconds = wallDurationSeconds; self.peakResidentBytes = peakResidentBytes
    self.steadyResidentBytes = steadyResidentBytes; self.meanPowerWatts = meanPowerWatts; self.counters = counters
  }
  public func validate() throws {
    guard formatVersion == Self.formatVersion,
      try Self(rootLatencyMicroseconds: rootLatencyMicroseconds, wallDurationSeconds: wallDurationSeconds,
        peakResidentBytes: peakResidentBytes, steadyResidentBytes: steadyResidentBytes,
        meanPowerWatts: meanPowerWatts, counters: counters) == self else {
      throw QualificationError.invalid("raw Gate E measurements are noncanonical")
    }
  }
}

public enum PerformanceEvidenceVerifier {
  /// Legacy consistency check only: v1 cannot distinguish accepted progress
  /// from retries/failures and therefore cannot qualify production throughput.
  public static func verify(run: PerformanceRunArtifact, measurements: PerformanceMeasurementArtifact) throws {
    try run.validate(); try measurements.validate()
    guard run.measuredRoots == UInt64(measurements.rootLatencyMicroseconds.count) else {
      throw QualificationError.invalid("Gate E run does not bind its raw root count")
    }
    let latency = try LatencyDistribution(samplesMicroseconds: measurements.rootLatencyMicroseconds)
    guard latency == run.latency, run.peakResidentBytes == measurements.peakResidentBytes,
      run.steadyResidentBytes == measurements.steadyResidentBytes, run.counters == measurements.counters,
      run.meanPowerWatts == measurements.meanPowerWatts else {
      throw QualificationError.invalid("Gate E derived summary differs from raw measurements")
    }
    let roots = Double(run.measuredRoots), environments = Double(run.workload.environmentCount)
    let expectedEnvironmentSteps = roots * environments / measurements.wallDurationSeconds
    let expectedSimulatedSeconds = roots * Double(run.workload.timestepMicroseconds) / 1_000_000 / measurements.wallDurationSeconds
    let expectedBytesPerEnvironment = Double(measurements.steadyResidentBytes) / environments
    guard close(run.environmentStepsPerSecond, expectedEnvironmentSteps),
      close(run.simulatedSecondsPerWallSecond, expectedSimulatedSeconds), close(run.bytesPerEnvironment, expectedBytesPerEnvironment) else {
      throw QualificationError.invalid("Gate E throughput or memory summary differs from its legacy measured region")
    }
    if let power = measurements.meanPowerWatts {
      guard let energy = run.energyJoulesPerSimulatedSecond,
        close(energy, power / expectedSimulatedSeconds, relativeTolerance: 1.0e-8) else {
        throw QualificationError.invalid("Gate E energy summary does not match measured power and simulation rate")
      }
    } else if run.energyJoulesPerSimulatedSecond != nil { throw QualificationError.invalid("energy reported without power evidence") }
  }
  private static func close(_ a: Double, _ b: Double, relativeTolerance: Double = 1.0e-10) -> Bool {
    a.isFinite && b.isFinite && abs(a - b) <= relativeTolerance * max(1, max(abs(a), abs(b)))
  }
}

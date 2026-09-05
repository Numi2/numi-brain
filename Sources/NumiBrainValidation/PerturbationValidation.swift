import Foundation

public struct ValidationConfidenceInterval: Codable, Equatable, Sendable {
  public let estimate: Double
  public let lower: Double
  public let upper: Double
  public let independentUnitCount: Int
}

public struct PairedPerturbationOutcome: Codable, Equatable, Sendable {
  /// One independent episode/subject, not one physics root. Several samples
  /// from the same subject must be aggregated before calling this API.
  public let independentUnit: String
  public let baselineRecovered: Bool
  public let interventionRecovered: Bool
  /// Predeclared loss (e.g. integrated tracking error or effort). Failed or
  /// censored episodes must receive their declared loss, never be discarded.
  public let baselineLoss: Double
  public let interventionLoss: Double
  public init(independentUnit: String, baselineRecovered: Bool, interventionRecovered: Bool,
    baselineLoss: Double, interventionLoss: Double)
  {
    self.independentUnit = independentUnit; self.baselineRecovered = baselineRecovered
    self.interventionRecovered = interventionRecovered; self.baselineLoss = baselineLoss
    self.interventionLoss = interventionLoss
  }
}

public struct PairedPerturbationReport: Codable, Equatable, Sendable {
  public let baselineRecovery: ValidationConfidenceInterval
  public let interventionRecovery: ValidationConfidenceInterval
  public let recoveryDifference: ValidationConfidenceInterval
  public let lossDifference: ValidationConfidenceInterval
  public let bootstrapSeed: UInt64
  public let bootstrapReplicates: Int
}

public enum PerturbationValidation {
  /// Wilson 95% score interval; does not report [1,1] after a small perfect run.
  public static func recoveryInterval(successes: Int, trials: Int) throws -> ValidationConfidenceInterval {
    try ValidationNumerics.require(trials > 0 && successes >= 0 && successes <= trials,
      "invalid independent trial counts")
    let n = Double(trials), p = Double(successes) / n, z = 1.959963984540054
    let divisor = 1 + z * z / n
    let center = (p + z * z / (2 * n)) / divisor
    let half = z * sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / divisor
    return ValidationConfidenceInterval(estimate: p, lower: max(0, center - half),
      upper: min(1, center + half), independentUnitCount: trials)
  }

  /// Deterministic paired bootstrap of whole independent units. No per-root
  /// resampling and no unpaired mixing of baseline and lesion/ablation runs.
  /// Percentile intervals can be degenerate for homogeneous small samples;
  /// Wilson recovery intervals are retained alongside them rather than hidden.
  public static func paired(_ outcomes: [PairedPerturbationOutcome], seed: UInt64,
    bootstrapReplicates: Int = 2_000) throws -> PairedPerturbationReport
  {
    try ValidationNumerics.require(outcomes.count >= 2 && outcomes.count <= 10_000,
      "paired evaluation needs 2...10000 independent units")
    try ValidationNumerics.require(bootstrapReplicates >= 200 && bootstrapReplicates <= 20_000
      && outcomes.count <= 20_000_000 / bootstrapReplicates, "bootstrap exceeds bounded work budget")
    try ValidationNumerics.require(outcomes.allSatisfy { !$0.independentUnit.isEmpty }
      && Set(outcomes.map(\.independentUnit)).count == outcomes.count,
      "duplicate or absent independent unit identity")
    // Stable unit ordering makes the seed independent of file/array ordering.
    let ordered = outcomes.sorted { $0.independentUnit < $1.independentUnit }
    let losses = ordered.map { $0.interventionLoss - $0.baselineLoss }
    try ValidationNumerics.finite(ordered.flatMap { [$0.baselineLoss, $0.interventionLoss] })
    try ValidationNumerics.finite(losses)
    let recovery = ordered.map { ($0.interventionRecovered ? 1.0 : 0.0) - ($0.baselineRecovered ? 1.0 : 0.0) }
    var rng = SplitMix64(state: seed), recoverySamples: [Double] = [], lossSamples: [Double] = []
    recoverySamples.reserveCapacity(bootstrapReplicates); lossSamples.reserveCapacity(bootstrapReplicates)
    for _ in 0..<bootstrapReplicates {
      var sampledRecovery = 0.0, sampledLoss = 0.0
      for _ in ordered.indices {
        let index = rng.index(upperBound: ordered.count)
        sampledRecovery += recovery[index] / Double(ordered.count)
        sampledLoss += losses[index] / Double(ordered.count)
      }
      try ValidationNumerics.finite([sampledRecovery, sampledLoss])
      recoverySamples.append(sampledRecovery); lossSamples.append(sampledLoss)
    }
    func interval(_ values: [Double], _ samples: [Double]) throws -> ValidationConfidenceInterval {
      let sorted = samples.sorted()
      func quantile(_ q: Double) -> Double {
        let coordinate = q * Double(sorted.count - 1)
        let lo = Int(coordinate), hi = min(lo + 1, sorted.count - 1), fraction = coordinate - Double(lo)
        return (1 - fraction) * sorted[lo] + fraction * sorted[hi]
      }
      return ValidationConfidenceInterval(estimate: try ValidationNumerics.sum(values) / Double(values.count),
        lower: quantile(0.025), upper: quantile(0.975), independentUnitCount: values.count)
    }
    return try PairedPerturbationReport(
      baselineRecovery: recoveryInterval(successes: ordered.filter(\.baselineRecovered).count, trials: ordered.count),
      interventionRecovery: recoveryInterval(successes: ordered.filter(\.interventionRecovered).count, trials: ordered.count),
      recoveryDifference: interval(recovery, recoverySamples), lossDifference: interval(losses, lossSamples),
      bootstrapSeed: seed, bootstrapReplicates: bootstrapReplicates
    )
  }

  private struct SplitMix64 {
    var state: UInt64
    mutating func next() -> UInt64 {
      state &+= 0x9e3779b97f4a7c15
      var z = state
      z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
      z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
      return z ^ (z >> 31)
    }
    mutating func index(upperBound: Int) -> Int {
      let bound = UInt64(upperBound), threshold = (0 &- bound) % bound
      var value = next()
      while value < threshold { value = next() }
      return Int(value % bound)
    }
  }
}

import Foundation

/// One scalar physical observable. Units, frame, coordinate identity, and time
/// origins are explicit; comparison never fits a delay, gain, sign, or offset.
/// Raw receptor traces are not silently relabeled as authoritative body state.
public struct PhysicalTrace: Codable, Equatable, Sendable {
  public let quantity: String
  public let unit: String
  public let frame: String
  public let coordinate: String
  public let timestampsMicroseconds: [UInt64]
  public let values: [Double]
  public let validity: [Bool]

  public init(quantity: String, unit: String, frame: String, coordinate: String,
    timestampsMicroseconds: [UInt64], values: [Double], validity: [Bool]) throws
  {
    self.quantity = quantity; self.unit = unit; self.frame = frame; self.coordinate = coordinate
    self.timestampsMicroseconds = timestampsMicroseconds; self.values = values; self.validity = validity
    try validate()
  }

  public func validate() throws {
    try ValidationNumerics.require([quantity, unit, frame, coordinate].allSatisfy {
      !$0.isEmpty && $0.utf8.count <= 512
    }, "trace quantity/unit/frame/coordinate is incomplete")
    try ValidationNumerics.require(values.count >= 2 && timestampsMicroseconds.count == values.count
      && validity.count == values.count, "incompatible physical trace shape")
    try ValidationNumerics.finite(values)
    try ValidationNumerics.require(zip(timestampsMicroseconds.dropFirst(), timestampsMicroseconds)
      .allSatisfy { $0 > $1 }, "trace timestamps must strictly increase")
  }
}

public struct PhysicalTraceComparisonPlan: Codable, Equatable, Sendable {
  public enum Alignment: String, Codable, Sendable { case exact, linearReference }
  public let alignment: Alignment
  public let candidateTimeOriginMicroseconds: UInt64
  public let referenceTimeOriginMicroseconds: UInt64
  public let maximumInterpolationGapMicroseconds: UInt64
  public let minimumDurationMicroseconds: UInt64
  public let physicalScale: Double
  public let maximumNormalizedRMSE: Double
  public let maximumNormalizedPeakError: Double
  public let maximumNormalizedAbsoluteBias: Double

  public init(alignment: Alignment = .exact, candidateTimeOriginMicroseconds: UInt64 = 0,
    referenceTimeOriginMicroseconds: UInt64 = 0, maximumInterpolationGapMicroseconds: UInt64 = 0,
    minimumDurationMicroseconds: UInt64, physicalScale: Double, maximumNormalizedRMSE: Double,
    maximumNormalizedPeakError: Double, maximumNormalizedAbsoluteBias: Double) throws
  {
    self.alignment = alignment; self.candidateTimeOriginMicroseconds = candidateTimeOriginMicroseconds
    self.referenceTimeOriginMicroseconds = referenceTimeOriginMicroseconds
    self.maximumInterpolationGapMicroseconds = maximumInterpolationGapMicroseconds
    self.minimumDurationMicroseconds = minimumDurationMicroseconds; self.physicalScale = physicalScale
    self.maximumNormalizedRMSE = maximumNormalizedRMSE
    self.maximumNormalizedPeakError = maximumNormalizedPeakError
    self.maximumNormalizedAbsoluteBias = maximumNormalizedAbsoluteBias
    try validate()
  }

  public func validate() throws {
    try ValidationNumerics.require(minimumDurationMicroseconds > 0, "minimum duration must be predeclared")
    try ValidationNumerics.require(alignment == .exact ? maximumInterpolationGapMicroseconds == 0
      : maximumInterpolationGapMicroseconds > 0, "invalid interpolation contract")
    try ValidationNumerics.positive(physicalScale, "physical normalization scale")
    for threshold in [maximumNormalizedRMSE, maximumNormalizedPeakError, maximumNormalizedAbsoluteBias] {
      try ValidationNumerics.nonnegative(threshold, "trace error threshold")
    }
  }
}

public struct PhysicalTraceComparison: Codable, Equatable, Sendable {
  public let result: PhysicalValidationResult
  public let sampleCount: Int
  public let durationMicroseconds: UInt64
  public let normalizedSignedBias: Double
}

public enum PhysicalTraceValidation {
  public static func compare(candidate: PhysicalTrace, reference: PhysicalTrace,
    plan: PhysicalTraceComparisonPlan) throws -> PhysicalTraceComparison
  {
    try candidate.validate(); try reference.validate(); try plan.validate()
    try ValidationNumerics.require(candidate.quantity == reference.quantity && candidate.unit == reference.unit
      && candidate.frame == reference.frame && candidate.coordinate == reference.coordinate,
      "trace physical semantics do not match")
    try ValidationNumerics.require(candidate.validity.allSatisfy { $0 },
      "invalid candidate observations cannot be dropped from physical validation")
    let ct = try relative(candidate.timestampsMicroseconds, origin: plan.candidateTimeOriginMicroseconds)
    let rt = try relative(reference.timestampsMicroseconds, origin: plan.referenceTimeOriginMicroseconds)
    let duration = ct.last! - ct[0]
    try ValidationNumerics.require(duration >= plan.minimumDurationMicroseconds, "physical horizon is too short")
    let targets: [Double]
    switch plan.alignment {
    case .exact:
      try ValidationNumerics.require(ct == rt && reference.validity.allSatisfy { $0 },
        "exact comparison requires identical timestamps and valid reference observations")
      targets = reference.values
    case .linearReference:
      try ValidationNumerics.require(ct[0] >= rt[0] && ct.last! <= rt.last!, "reference extrapolation is forbidden")
      var cursor = 0, interpolated: [Double] = []
      interpolated.reserveCapacity(ct.count)
      for time in ct {
        while cursor + 1 < rt.count && rt[cursor + 1] <= time { cursor += 1 }
        if rt[cursor] == time {
          try ValidationNumerics.require(reference.validity[cursor], "reference sample is invalid")
          interpolated.append(reference.values[cursor])
        } else {
          try ValidationNumerics.require(cursor + 1 < rt.count && reference.validity[cursor]
            && reference.validity[cursor + 1], "reference interval is missing or invalid")
          let gap = rt[cursor + 1] - rt[cursor]
          try ValidationNumerics.require(gap <= plan.maximumInterpolationGapMicroseconds,
            "reference interpolation crosses an excessive gap")
          // Subtract integer clocks before converting to Double: absolute
          // clocks beyond 2^53 still preserve one-microsecond distinctions.
          let fraction = Double(time - rt[cursor]) / Double(gap)
          interpolated.append((1 - fraction) * reference.values[cursor] + fraction * reference.values[cursor + 1])
        }
      }
      targets = interpolated
    }
    let errors = zip(candidate.values, targets).map { ($0 - $1) / plan.physicalScale }
    try ValidationNumerics.finite(errors)
    var squaredTerms: [Double] = [], biasTerms: [Double] = []
    for index in 1..<errors.count {
      let weight = Double(ct[index] - ct[index - 1]) / Double(duration)
      let a = errors[index - 1], b = errors[index]
      // Exact integrals for the declared piecewise-linear error trace. This
      // weights physical time, not the density of capture samples.
      squaredTerms.append(weight * (a * a + a * b + b * b) / 3)
      biasTerms.append(weight * (a + b) / 2)
    }
    let rmse = sqrt(max(0, try ValidationNumerics.sum(squaredTerms)))
    let bias = try ValidationNumerics.sum(biasTerms)
    let peak = errors.map(abs).max()!
    let result = try PhysicalValidationResult(metrics: [
      ValidationNumerics.metric("time_weighted_normalized_rmse", rmse, plan.maximumNormalizedRMSE),
      ValidationNumerics.metric("normalized_peak_error", peak, plan.maximumNormalizedPeakError),
      ValidationNumerics.metric("normalized_absolute_bias", abs(bias), plan.maximumNormalizedAbsoluteBias),
    ], notes: ["piecewise-linear sampled trace; unresolved between-sample transients require a capture-rate study"])
    return PhysicalTraceComparison(result: result, sampleCount: errors.count,
      durationMicroseconds: duration, normalizedSignedBias: bias)
  }

  private static func relative(_ times: [UInt64], origin: UInt64) throws -> [UInt64] {
    try ValidationNumerics.require(times.allSatisfy { $0 >= origin }, "time origin is after a trace sample")
    return times.map { $0 - origin }
  }
}

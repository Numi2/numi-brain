import Foundation

public struct RichardsonEstimate: Codable, Equatable, Sendable {
  public let status: PhysicalValidationStatus
  public let observedOrder: Double?
  public let extrapolatedValue: Double?
  /// Absolute GCI in the observable's own units, not a percent of a near-zero result.
  public let absoluteFineGridIndex: Double?
  public let normalizedFineGridIndex: Double?
  public let reason: String
}

public enum ConvergenceValidation {
  /// Three equal-ratio spatial OR temporal refinements. This estimates
  /// discretization uncertainty, not model accuracy. Oscillation, divergence,
  /// unresolved differences and unequal ratios never receive a fabricated p.
  public static func richardson(
    coarse: Double, medium: Double, fine: Double,
    coarseStep: Double, mediumStep: Double, fineStep: Double,
    observableScale: Double, resolutionFloor: Double,
    minimumOrder: Double, maximumNormalizedIndex: Double
  ) throws -> RichardsonEstimate {
    try ValidationNumerics.finite([coarse, medium, fine])
    for step in [coarseStep, mediumStep, fineStep] {
      try ValidationNumerics.positive(step, "refinement step")
    }
    try ValidationNumerics.require(coarseStep > mediumStep && mediumStep > fineStep,
      "refinement must use decreasing positive steps")
    try ValidationNumerics.positive(observableScale, "observable scale")
    try ValidationNumerics.nonnegative(resolutionFloor, "resolution floor")
    try ValidationNumerics.positive(minimumOrder, "minimum order")
    try ValidationNumerics.nonnegative(maximumNormalizedIndex, "maximum index")
    let r = coarseStep / mediumStep, r2 = mediumStep / fineStep
    try ValidationNumerics.require(r.isFinite && r2.isFinite && abs(r - r2) <= 1e-10 * max(r, r2),
      "Richardson v1 requires equal refinement ratios")
    let d1 = coarse - medium, d2 = medium - fine
    try ValidationNumerics.finite([d1, d2])
    func unresolved(_ reason: String) -> RichardsonEstimate {
      RichardsonEstimate(status: .inconclusive, observedOrder: nil, extrapolatedValue: nil,
        absoluteFineGridIndex: nil, normalizedFineGridIndex: nil, reason: reason)
    }
    guard abs(d1) > resolutionFloor, abs(d2) > resolutionFloor else {
      return unresolved("refinement differences are below declared resolution; convergence order is not identifiable")
    }
    guard (d1 > 0) == (d2 > 0) else {
      return unresolved("oscillatory refinement; a monotone Richardson estimate is not justified")
    }
    guard abs(d2) < abs(d1) else {
      return RichardsonEstimate(status: .failed, observedOrder: nil, extrapolatedValue: nil,
        absoluteFineGridIndex: nil, normalizedFineGridIndex: nil,
        reason: "refinement differences do not contract")
    }
    let p = log(abs(d1) / abs(d2)) / log(r)
    let denominator = expm1(p * log(r))
    guard p.isFinite, p > 0, denominator.isFinite, denominator > 0 else {
      return unresolved("ill-conditioned refinement estimate")
    }
    let correction = (fine - medium) / denominator
    let extrapolated = fine + correction
    // Three-grid safety factor, following the NASA verification tutorial.
    let absoluteIndex = 1.25 * abs(correction)
    let normalized = absoluteIndex / observableScale
    try ValidationNumerics.finite([extrapolated, absoluteIndex, normalized])
    return RichardsonEstimate(
      status: p >= minimumOrder && normalized <= maximumNormalizedIndex ? .passed : .failed,
      observedOrder: p, extrapolatedValue: extrapolated,
      absoluteFineGridIndex: absoluteIndex, normalizedFineGridIndex: normalized,
      reason: "three-grid discretization estimate; asymptotic regime and physical accuracy require independent checks"
    )
  }

  public struct SweepCell: Codable, Equatable, Sendable {
    public let coordinates: [String: String]
    public let status: PhysicalValidationStatus
    public init(coordinates: [String: String], status: PhysicalValidationStatus) {
      self.coordinates = coordinates; self.status = status
    }
  }

  /// Checks the complete Cartesian product of predeclared timestep, stiffness,
  /// mass-ratio, friction, stack-depth and execution-mode levels. Missing and
  /// inconclusive cells are not silently removed from the denominator.
  public static func coverage(
    axes: [String: [String]], cells: [SweepCell]
  ) throws -> PhysicalValidationResult {
    try ValidationNumerics.require(!axes.isEmpty && axes.count <= 8, "invalid sweep dimension")
    let keys = axes.keys.sorted()
    var expectedCount = 1
    for key in keys {
      let levels = axes[key]!
      try ValidationNumerics.require(!key.isEmpty && !levels.isEmpty && levels.allSatisfy { !$0.isEmpty }
        && Set(levels).count == levels.count, "invalid sweep levels")
      try ValidationNumerics.require(expectedCount <= 100_000 / levels.count, "sweep exceeds 100000 cells")
      expectedCount *= levels.count
    }
    try ValidationNumerics.require(cells.count <= 100_000, "too many observed sweep cells")
    // Codable dictionaries are not used as unordered or delimiter-based keys.
    // The mixed-radix index is collision-free even for arbitrary level strings.
    var seen = Set<Int>(), duplicates = 0, failed = 0, inconclusive = 0
    for cell in cells {
      try ValidationNumerics.require(Set(cell.coordinates.keys) == Set(keys), "foreign sweep dimensions")
      var index = 0
      for key in keys {
        guard let level = axes[key]!.firstIndex(of: cell.coordinates[key]!) else {
          throw PhysicalValidationError.invalid("undeclared sweep level")
        }
        index = index * axes[key]!.count + level
      }
      if !seen.insert(index).inserted { duplicates += 1 }
      if cell.status == .failed { failed += 1 }
      if cell.status == .inconclusive { inconclusive += 1 }
    }
    return try PhysicalValidationResult(metrics: [
      ValidationNumerics.metric("missing_sweep_cells", Double(expectedCount - seen.count), 0),
      ValidationNumerics.metric("duplicate_sweep_cells", Double(duplicates), 0),
      ValidationNumerics.metric("failed_sweep_cells", Double(failed), 0),
      ValidationNumerics.metric("inconclusive_sweep_cells", Double(inconclusive), 0),
    ], notes: ["coverage checks supplied results; it does not authenticate the execution that produced them"])
  }
}

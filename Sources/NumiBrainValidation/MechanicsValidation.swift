import Foundation

public enum MechanicsValidation {
  /// Checks A(solve(b))=b and solve(A(v))=v using independently captured
  /// applications of the native operator. Never inverts a copied dense matrix.
  public static func inverseConsistency(
    rhs: [Double], actionOfInverse: [Double], velocity: [Double], inverseOfAction: [Double],
    rhsScales: [Double], velocityScales: [Double], tolerance: Double
  ) throws -> PhysicalValidationResult {
    try PhysicalValidationResult(metrics: [
      ValidationNumerics.metric("action_after_inverse", ValidationNumerics.error(
        actionOfInverse, rhs, scales: rhsScales), tolerance),
      ValidationNumerics.metric("inverse_after_action", ValidationNumerics.error(
        inverseOfAction, velocity, scales: velocityScales), tolerance),
    ])
  }

  /// Central directional finite difference of the exact residual. The native
  /// owner must perturb manifold coordinates with its own retraction. Different
  /// active sets are reported as inconclusive, not a failed smooth derivative.
  public static func tangent(
    action: [Double], residualPlus: [Double], residualMinus: [Double], epsilon: Double,
    residualScales: [Double], baseActiveSet: UInt64, plusActiveSet: UInt64,
    minusActiveSet: UInt64, tolerance: Double
  ) throws -> PhysicalValidationResult {
    try ValidationNumerics.positive(epsilon, "finite-difference step")
    try ValidationNumerics.finite(action)
    try ValidationNumerics.finite(residualPlus, count: action.count)
    try ValidationNumerics.finite(residualMinus, count: action.count)
    try ValidationNumerics.scales(residualScales, count: action.count)
    try ValidationNumerics.nonnegative(tolerance, "tolerance")
    guard baseActiveSet == plusActiveSet, baseActiveSet == minusActiveSet else {
      return .inconclusive("active set changed; use a declared one-sided/generalized derivative experiment")
    }
    let reference = zip(residualPlus, residualMinus).map { ($0 - $1) / (2 * epsilon) }
    return try PhysicalValidationResult(metrics: [ValidationNumerics.metric(
      "directional_tangent", ValidationNumerics.error(action, reference, scales: residualScales), tolerance
    )])
  }

  /// Verifies dW = f dot (J dq) = appliedGeneralizedForce dot dq.
  /// `jacobian` is row-major; translation and rotation have declared physical
  /// scales outside this check. Native point displacements are independently
  /// compared with J dq, so using a wrong J on both sides cannot hide that error.
  public static func virtualWork(
    jacobian: [Double], displacement: [Double], pointDisplacement: [Double],
    pointForce: [Double], appliedGeneralizedForce: [Double],
    pointScales: [Double], workScaleJoules: Double, tolerance: Double
  ) throws -> PhysicalValidationResult {
    try ValidationNumerics.finite(displacement)
    try ValidationNumerics.finite(pointForce)
    let rows = pointForce.count, columns = displacement.count
    try ValidationNumerics.require(rows <= ValidationNumerics.maximumElements / columns,
      "Jacobian exceeds bounded reference capacity")
    try ValidationNumerics.finite(jacobian, count: rows * columns)
    try ValidationNumerics.finite(appliedGeneralizedForce, count: columns)
    try ValidationNumerics.positive(workScaleJoules, "work scale")
    let projected = try (0..<rows).map { row in
      try ValidationNumerics.dot(Array(jacobian[(row * columns)..<((row + 1) * columns)]), displacement)
    }
    let pointWork = try ValidationNumerics.dot(pointForce, projected)
    let generalizedWork = try ValidationNumerics.dot(appliedGeneralizedForce, displacement)
    return try PhysicalValidationResult(metrics: [
      ValidationNumerics.metric("point_jacobian_displacement", ValidationNumerics.error(
        pointDisplacement, projected, scales: pointScales), tolerance),
      ValidationNumerics.metric("attachment_virtual_work", abs(pointWork - generalizedWork) / workScaleJoules, tolerance),
    ])
  }

  /// All angular momenta and external angular impulses must use the SAME
  /// fixed world origin and frame, including reactions from static supports.
  public static func momentum(
    linearBefore: [Double], linearAfter: [Double], externalImpulse: [Double],
    angularBefore: [Double], angularAfter: [Double], externalAngularImpulse: [Double],
    linearScale: Double, angularScale: Double, tolerance: Double
  ) throws -> PhysicalValidationResult {
    for vector in [linearBefore, linearAfter, externalImpulse, angularBefore, angularAfter, externalAngularImpulse] {
      try ValidationNumerics.finite(vector, count: 3)
    }
    try ValidationNumerics.positive(linearScale, "linear momentum scale")
    try ValidationNumerics.positive(angularScale, "angular momentum scale")
    return try PhysicalValidationResult(metrics: [
      ValidationNumerics.metric("linear_impulse_balance", ValidationNumerics.error(
        zip(linearAfter, linearBefore).map(-), externalImpulse,
        scales: [Double](repeating: linearScale, count: 3)), tolerance),
      ValidationNumerics.metric("angular_impulse_balance", ValidationNumerics.error(
        zip(angularAfter, angularBefore).map(-), externalAngularImpulse,
        scales: [Double](repeating: angularScale, count: 3)), tolerance),
    ])
  }

  /// E includes kinetic AND stored potential/strain energy. Gravity included
  /// as potential must not also appear in external work. Dissipation is positive
  /// removed energy; actuator work and support work are signed inputs.
  public static func energy(
    beforeJoules: Double, afterJoules: Double, externalWorkJoules: Double,
    actuatorWorkJoules: Double, dissipatedJoules: Double, scaleJoules: Double,
    tolerance: Double
  ) throws -> PhysicalValidationResult {
    try ValidationNumerics.finite([beforeJoules, afterJoules, externalWorkJoules, actuatorWorkJoules])
    try ValidationNumerics.nonnegative(dissipatedJoules, "dissipated energy")
    try ValidationNumerics.positive(scaleJoules, "energy scale")
    let residual = try ValidationNumerics.sum([
      afterJoules, -beforeJoules, -externalWorkJoules, -actuatorWorkJoules, dissipatedJoules,
    ])
    return try PhysicalValidationResult(metrics: [
      ValidationNumerics.metric("energy_balance", abs(residual) / scaleJoules, tolerance),
      ValidationNumerics.metric("unaccounted_energy_creation", max(0, residual) / scaleJoules, tolerance),
    ])
  }

  /// Independent point-plane Coulomb check in a contact-local orthonormal
  /// frame. Positive gap means separated; tractions are forces in newtons.
  /// Compliant contact must provide the constitutive corrected gap, not relabel
  /// a penetrating geometric gap as an exact rigid-contact solution.
  public static func contact(
    gapMeters: Double, normalForceNewtons: Double, tangentialForceNewtons: [Double],
    slipVelocityMetersPerSecond: [Double], friction: Double,
    lengthScaleMeters: Double, forceScaleNewtons: Double,
    velocityScaleMetersPerSecond: Double, stickingSpeedMetersPerSecond: Double,
    tolerance: Double
  ) throws -> PhysicalValidationResult {
    try ValidationNumerics.finite([gapMeters, normalForceNewtons])
    try ValidationNumerics.finite(tangentialForceNewtons, count: 2)
    try ValidationNumerics.finite(slipVelocityMetersPerSecond, count: 2)
    try ValidationNumerics.nonnegative(friction, "friction")
    try ValidationNumerics.nonnegative(stickingSpeedMetersPerSecond, "sticking speed")
    try ValidationNumerics.positive(lengthScaleMeters, "length scale")
    try ValidationNumerics.positive(forceScaleNewtons, "force scale")
    try ValidationNumerics.positive(velocityScaleMetersPerSecond, "velocity scale")
    let force = try ValidationNumerics.norm(tangentialForceNewtons)
    let speed = try ValidationNumerics.norm(slipVelocityMetersPerSecond)
    let power = try ValidationNumerics.dot(tangentialForceNewtons, slipVelocityMetersPerSecond)
    let coneRadius = friction * max(0, normalForceNewtons)
    var metrics = try [
      ValidationNumerics.metric("normal_gap", max(0, -gapMeters) / lengthScaleMeters, tolerance),
      ValidationNumerics.metric("normal_force", max(0, -normalForceNewtons) / forceScaleNewtons, tolerance),
      ValidationNumerics.metric("normal_complementarity",
        abs((gapMeters / lengthScaleMeters) * (normalForceNewtons / forceScaleNewtons)), tolerance),
      ValidationNumerics.metric("circular_coulomb_cone", max(0, force - coneRadius) / forceScaleNewtons, tolerance),
      ValidationNumerics.metric("friction_energy_creation", max(0, power) / forceScaleNewtons / velocityScaleMetersPerSecond, tolerance),
    ]
    if speed > stickingSpeedMetersPerSecond {
      // Checks direction as well as cone saturation; an arbitrary cone-boundary
      // force cannot pass merely because its tangential power is negative.
      let expected = slipVelocityMetersPerSecond.map { -coneRadius * ($0 / speed) }
      metrics.append(try ValidationNumerics.metric("maximum_dissipation", ValidationNumerics.error(
        tangentialForceNewtons, expected, scales: [forceScaleNewtons, forceScaleNewtons]), tolerance))
    }
    return try PhysicalValidationResult(metrics: metrics)
  }

  public struct ForceContribution: Codable, Equatable, Sendable {
    public let physicalSource: String
    public let owner: String
    public let applied: Bool
    public let generalizedForce: [Double]
    public init(physicalSource: String, owner: String, applied: Bool, generalizedForce: [Double]) {
      self.physicalSource = physicalSource; self.owner = owner
      self.applied = applied; self.generalizedForce = generalizedForce
    }
  }

  /// A MyoSim source transmitted through NHTENDON is still ONE physical
  /// source. Diagnostic transfers are retained but are not applied again.
  /// Independent expected totals detect a missing force even if the sum of
  /// all recorded contributions agrees with the runtime's applied total.
  public static func forceAccounting(
    contributions: [ForceContribution], requiredPhysicalSources: [String],
    appliedTotal: [Double], independentTotal: [Double], scales: [Double], tolerance: Double
  ) throws -> PhysicalValidationResult {
    try ValidationNumerics.finite(appliedTotal)
    try ValidationNumerics.require(!contributions.isEmpty && contributions.count <= 16_384,
      "invalid force contribution count")
    try ValidationNumerics.require(!requiredPhysicalSources.isEmpty
      && requiredPhysicalSources.allSatisfy { !$0.isEmpty }
      && Set(requiredPhysicalSources).count == requiredPhysicalSources.count,
      "invalid required force source registry")
    for source in contributions {
      try ValidationNumerics.require(!source.physicalSource.isEmpty && !source.owner.isEmpty,
        "force source identity is missing")
      try ValidationNumerics.finite(source.generalizedForce, count: appliedTotal.count)
    }
    let applied = contributions.filter(\.applied)
    let ids = applied.map(\.physicalSource)
    let duplicateCount = ids.count - Set(ids).count
    let registryMismatch = Set(ids).symmetricDifference(Set(requiredPhysicalSources)).count
    let sum = try appliedTotal.indices.map { coordinate in
      try ValidationNumerics.sum(applied.map { $0.generalizedForce[coordinate] })
    }
    return try PhysicalValidationResult(metrics: [
      ValidationNumerics.metric("duplicate_physical_force_sources", Double(duplicateCount), 0),
      ValidationNumerics.metric("force_source_coverage", Double(registryMismatch), 0),
      ValidationNumerics.metric("force_assembly", ValidationNumerics.error(appliedTotal, sum, scales: scales), tolerance),
      ValidationNumerics.metric("independent_generalized_force", ValidationNumerics.error(appliedTotal, independentTotal, scales: scales), tolerance),
    ])
  }

  /// Zero-stiffness/zero-attachment and monolithic/fast-path comparisons use
  /// independently captured results, not two aliases of the same state buffer.
  public static func reduction(
    coupled: [Double], standalone: [Double], scales: [Double], tolerance: Double
  ) throws -> PhysicalValidationResult {
    try PhysicalValidationResult(metrics: [ValidationNumerics.metric(
      "standalone_reduction", ValidationNumerics.error(coupled, standalone, scales: scales), tolerance
    )])
  }
}

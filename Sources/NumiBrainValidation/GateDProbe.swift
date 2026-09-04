import Foundation

/// Typed, executable offline probes. These payloads contain measurements, not
/// live native capabilities: a passing result never grants runtime admission.
public enum GateDProbe: Codable, Equatable, Sendable {
  case inverse(rhs: [Double], actionOfInverse: [Double], velocity: [Double], inverseOfAction: [Double],
    rhsScales: [Double], velocityScales: [Double], tolerance: Double)
  case tangent(action: [Double], residualPlus: [Double], residualMinus: [Double], epsilon: Double,
    residualScales: [Double], baseActiveSet: UInt64, plusActiveSet: UInt64, minusActiveSet: UInt64, tolerance: Double)
  case virtualWork(jacobian: [Double], displacement: [Double], pointDisplacement: [Double],
    pointForce: [Double], appliedGeneralizedForce: [Double], pointScales: [Double], workScaleJoules: Double, tolerance: Double)
  case momentum(linearBefore: [Double], linearAfter: [Double], externalImpulse: [Double],
    angularBefore: [Double], angularAfter: [Double], externalAngularImpulse: [Double],
    linearScale: Double, angularScale: Double, tolerance: Double)
  case energy(beforeJoules: Double, afterJoules: Double, externalWorkJoules: Double,
    actuatorWorkJoules: Double, dissipatedJoules: Double, scaleJoules: Double, tolerance: Double)
  case contact(gapMeters: Double, normalForceNewtons: Double, tangentialForceNewtons: [Double],
    slipVelocityMetersPerSecond: [Double], friction: Double, lengthScaleMeters: Double,
    forceScaleNewtons: Double, velocityScaleMetersPerSecond: Double, stickingSpeedMetersPerSecond: Double, tolerance: Double)
  case forceAccounting(contributions: [MechanicsValidation.ForceContribution], requiredPhysicalSources: [String],
    appliedTotal: [Double], independentTotal: [Double], scales: [Double], tolerance: Double)
  case reduction(coupled: [Double], standalone: [Double], scales: [Double], tolerance: Double)
  case refinement(coarse: Double, medium: Double, fine: Double, coarseStep: Double, mediumStep: Double,
    fineStep: Double, observableScale: Double, resolutionFloor: Double, minimumOrder: Double, maximumNormalizedIndex: Double)
  case sweep(axes: [String: [String]], cells: [ConvergenceValidation.SweepCell])
  case trace(candidate: PhysicalTrace, reference: PhysicalTrace, plan: PhysicalTraceComparisonPlan)
  case perturbation(outcomes: [PairedPerturbationOutcome], seed: UInt64, bootstrapReplicates: Int)
  case material(stretches: [Double], firstPiolaPascals: [Double], tangentPascals: [Double],
    strainEnergyDensities: [Double], shearModulusPascals: Double, stressScalePascals: Double,
    energyDensityScale: Double, tolerance: Double)

  public func evaluate() throws -> GateDProbeOutput {
    switch self {
    case let .inverse(rhs, applied, velocity, solved, rs, vs, tolerance):
      return .residuals(try MechanicsValidation.inverseConsistency(rhs: rhs, actionOfInverse: applied,
        velocity: velocity, inverseOfAction: solved, rhsScales: rs, velocityScales: vs, tolerance: tolerance))
    case let .tangent(action, plus, minus, epsilon, scales, base, ps, ms, tolerance):
      return .residuals(try MechanicsValidation.tangent(action: action, residualPlus: plus, residualMinus: minus,
        epsilon: epsilon, residualScales: scales, baseActiveSet: base, plusActiveSet: ps, minusActiveSet: ms, tolerance: tolerance))
    case let .virtualWork(jacobian, displacement, pointDisplacement, force, applied, scales, work, tolerance):
      return .residuals(try MechanicsValidation.virtualWork(jacobian: jacobian, displacement: displacement,
        pointDisplacement: pointDisplacement, pointForce: force, appliedGeneralizedForce: applied,
        pointScales: scales, workScaleJoules: work, tolerance: tolerance))
    case let .momentum(lb, la, impulse, ab, aa, angularImpulse, ls, `as`, tolerance):
      return .residuals(try MechanicsValidation.momentum(linearBefore: lb, linearAfter: la, externalImpulse: impulse,
        angularBefore: ab, angularAfter: aa, externalAngularImpulse: angularImpulse,
        linearScale: ls, angularScale: `as`, tolerance: tolerance))
    case let .energy(before, after, external, actuator, dissipation, scale, tolerance):
      return .residuals(try MechanicsValidation.energy(beforeJoules: before, afterJoules: after,
        externalWorkJoules: external, actuatorWorkJoules: actuator, dissipatedJoules: dissipation,
        scaleJoules: scale, tolerance: tolerance))
    case let .contact(gap, normal, tangential, slip, friction, length, force, velocity, sticking, tolerance):
      return .residuals(try MechanicsValidation.contact(gapMeters: gap, normalForceNewtons: normal,
        tangentialForceNewtons: tangential, slipVelocityMetersPerSecond: slip, friction: friction,
        lengthScaleMeters: length, forceScaleNewtons: force, velocityScaleMetersPerSecond: velocity,
        stickingSpeedMetersPerSecond: sticking, tolerance: tolerance))
    case let .forceAccounting(contributions, required, applied, independent, scales, tolerance):
      return .residuals(try MechanicsValidation.forceAccounting(contributions: contributions,
        requiredPhysicalSources: required, appliedTotal: applied, independentTotal: independent,
        scales: scales, tolerance: tolerance))
    case let .reduction(coupled, standalone, scales, tolerance):
      return .residuals(try MechanicsValidation.reduction(coupled: coupled, standalone: standalone,
        scales: scales, tolerance: tolerance))
    case let .refinement(coarse, medium, fine, cs, ms, fs, scale, resolution, order, gci):
      return .refinement(try ConvergenceValidation.richardson(coarse: coarse, medium: medium, fine: fine,
        coarseStep: cs, mediumStep: ms, fineStep: fs, observableScale: scale,
        resolutionFloor: resolution, minimumOrder: order, maximumNormalizedIndex: gci))
    case let .sweep(axes, cells):
      return .residuals(try ConvergenceValidation.coverage(axes: axes, cells: cells))
    case let .trace(candidate, reference, plan):
      return .trace(try PhysicalTraceValidation.compare(candidate: candidate, reference: reference, plan: plan))
    case let .perturbation(outcomes, seed, replicates):
      return .perturbation(try PerturbationValidation.paired(outcomes, seed: seed, bootstrapReplicates: replicates))
    case let .material(stretches, stress, tangent, energy, mu, stressScale, energyScale, tolerance):
      try ValidationNumerics.finite(stretches)
      let reference = try stretches.map {
        try AnalyticPhysicalReferences.neoHookeanUniaxial(stretch: $0, shearModulusPascals: mu)
      }
      return .residuals(try PhysicalValidationResult(metrics: [
        ValidationNumerics.metric("first_piola_stress", ValidationNumerics.error(stress,
          reference.map(\.firstPiolaPascals), scales: [Double](repeating: stressScale, count: stretches.count)), tolerance),
        ValidationNumerics.metric("material_stretch_tangent", ValidationNumerics.error(tangent,
          reference.map(\.tangentPascals), scales: [Double](repeating: stressScale, count: stretches.count)), tolerance),
        ValidationNumerics.metric("strain_energy_density", ValidationNumerics.error(energy,
          reference.map(\.energyJoulesPerCubicMeter), scales: [Double](repeating: energyScale, count: stretches.count)), tolerance),
      ], notes: ["analytic constitutive verification only; held-out mechanical calibration remains separate"]))
    }
  }
}

public enum GateDProbeOutput: Codable, Equatable, Sendable {
  case residuals(PhysicalValidationResult)
  case refinement(RichardsonEstimate)
  case trace(PhysicalTraceComparison)
  case perturbation(PairedPerturbationReport)

  /// Statistical estimates alone have no pass/fail claim without a declared
  /// acceptance protocol. This is deliberately separate from Gate D promotion.
  public var diagnosticStatus: PhysicalValidationStatus? {
    switch self {
    case .residuals(let value): value.status
    case .refinement(let value): value.status
    case .trace(let value): value.result.status
    case .perturbation: nil
    }
  }
}

public enum GateDRequiredSuite: String, Codable, CaseIterable, Sendable {
  case effectiveTangent, attachmentAccounting, physicalSweeps, executionPathComparison
  case standaloneReductions, generalizedForceOwnership, heldOutBiology
  case perturbationAndAblation, heldOutMaterialCalibration
}

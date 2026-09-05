import Foundation

/// Closed-form verification references for explicitly named reduced models.
/// These are not a replacement for held-out experimental biological data and
/// do not assert that NumanX uses the same constitutive law.
public enum AnalyticPhysicalReferences {
  public struct State: Codable, Equatable, Sendable {
    public let position: Double
    public let velocity: Double
    public init(position: Double, velocity: Double) { self.position = position; self.velocity = velocity }
  }

  public static func ballistic(initial: State, acceleration: Double, seconds: Double) throws -> State {
    try ValidationNumerics.finite([initial.position, initial.velocity, acceleration])
    try ValidationNumerics.nonnegative(seconds, "time")
    let x = initial.position + initial.velocity * seconds + 0.5 * acceleration * seconds * seconds
    let v = initial.velocity + acceleration * seconds
    try ValidationNumerics.finite([x, v])
    return State(position: x, velocity: v)
  }

  /// m*x'' + c*x' + k*x = constantForce; exact under/critical/overdamped
  /// solutions. k=0 is deliberately excluded (use the ballistic reference).
  public static func oscillator(
    initial: State, mass: Double, stiffness: Double, damping: Double,
    constantForce: Double = 0, seconds: Double
  ) throws -> State {
    try ValidationNumerics.positive(mass, "mass")
    try ValidationNumerics.positive(stiffness, "stiffness")
    try ValidationNumerics.nonnegative(damping, "damping")
    try ValidationNumerics.nonnegative(seconds, "time")
    try ValidationNumerics.finite([initial.position, initial.velocity, constantForce])
    let a = damping / (2 * mass), omega2 = stiffness / mass
    let equilibrium = constantForce / stiffness, x0 = initial.position - equilibrium
    try ValidationNumerics.finite([a, omega2, equilibrium, x0])
    let d = a * a - omega2
    let x: Double, v: Double
    if abs(d) <= 1e-12 * omega2 {
      let b = initial.velocity + a * x0, e = exp(-a * seconds)
      x = (x0 + b * seconds) * e
      v = (b - a * (x0 + b * seconds)) * e
    } else if d < 0 {
      let w = sqrt(-d), b = (initial.velocity + a * x0) / w
      let c = cos(w * seconds), s = sin(w * seconds), e = exp(-a * seconds)
      x = (x0 * c + b * s) * e
      v = (-a * (x0 * c + b * s) + w * (-x0 * s + b * c)) * e
    } else {
      let q = sqrt(d)
      // Stable slow root avoids catastrophic cancellation for large damping.
      let slow = -omega2 / (a + q), fast = -(a + q)
      let c1 = (initial.velocity - fast * x0) / (slow - fast), c2 = x0 - c1
      let e1 = exp(slow * seconds), e2 = exp(fast * seconds)
      x = c1 * e1 + c2 * e2
      v = slow * c1 * e1 + fast * c2 * e2
    }
    try ValidationNumerics.finite([x + equilibrium, v])
    return State(position: x + equilibrium, velocity: v)
  }

  /// Constant-excitation first-order activation: a'=(u-a)/tau. The caller
  /// declares tau; this is not the full state-dependent MyoSim activation law.
  public static func activation(initial: Double, excitation: Double, tauSeconds: Double, seconds: Double) throws -> Double {
    try ValidationNumerics.require(initial.isFinite && excitation.isFinite
      && (0...1).contains(initial) && (0...1).contains(excitation), "activation must be in [0,1]")
    try ValidationNumerics.positive(tauSeconds, "activation time constant")
    try ValidationNumerics.nonnegative(seconds, "time")
    return excitation + (initial - excitation) * exp(-seconds / tauSeconds)
  }

  /// Incompressible neo-Hookean uniaxial extension with traction-free lateral
  /// faces. Returns FIRST PIOLA stress, its stretch tangent, and energy per
  /// reference volume; never compares Cauchy stress against Piola stress.
  public static func neoHookeanUniaxial(stretch: Double, shearModulusPascals: Double)
    throws -> (firstPiolaPascals: Double, tangentPascals: Double, energyJoulesPerCubicMeter: Double)
  {
    try ValidationNumerics.positive(stretch, "stretch")
    try ValidationNumerics.positive(shearModulusPascals, "shear modulus")
    let p = shearModulusPascals * (stretch - 1 / (stretch * stretch))
    let tangent = shearModulusPascals * (1 + 2 / (stretch * stretch * stretch))
    let energy = 0.5 * shearModulusPascals * (stretch * stretch + 2 / stretch - 3)
    try ValidationNumerics.finite([p, tangent, energy])
    return (p, tangent, energy)
  }
}

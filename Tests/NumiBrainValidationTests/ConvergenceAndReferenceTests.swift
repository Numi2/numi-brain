import XCTest
@testable import NumiBrainValidation

final class ConvergenceAndReferenceTests: XCTestCase {
  private func refinement(_ c: Double, _ m: Double, _ f: Double, scale: Double = 1) throws -> RichardsonEstimate {
    try ConvergenceValidation.richardson(coarse: c, medium: m, fine: f,
      coarseStep: 0.4, mediumStep: 0.2, fineStep: 0.1, observableScale: scale,
      resolutionFloor: 1e-12, minimumOrder: 1.8, maximumNormalizedIndex: 0.1)
  }

  func testQuadraticRefinementRecoversOrderAndExtrapolate() throws {
    let result = try refinement(1.16,1.04,1.01)
    XCTAssertEqual(result.status, .passed)
    XCTAssertEqual(try XCTUnwrap(result.observedOrder), 2, accuracy: 1e-12)
    XCTAssertEqual(try XCTUnwrap(result.extrapolatedValue), 1, accuracy: 1e-12)
    XCTAssertEqual(try XCTUnwrap(result.absoluteFineGridIndex), 0.0125, accuracy: 1e-12)
  }

  func testNearZeroObservableDoesNotDivideByFineValue() throws {
    let result = try refinement(0.15,0.03,0)
    XCTAssertEqual(result.status, .passed)
    XCTAssertEqual(try XCTUnwrap(result.extrapolatedValue), -0.01, accuracy: 1e-12)
  }

  func testFlatUnresolvedAndOscillatoryResultsAreInconclusive() throws {
    XCTAssertEqual(try refinement(1,1,1).status, .inconclusive)
    XCTAssertEqual(try refinement(1.1,0.9,1.01).status, .inconclusive)
    XCTAssertNil(try refinement(1,1,1).observedOrder)
  }

  func testDivergenceAndTooLowOrderFail() throws {
    XCTAssertEqual(try refinement(1,2,4).status, .failed)
    XCTAssertEqual(try refinement(1.4,1.2,1.1).status, .failed)
  }

  func testUnequalRatiosCannotUseEqualRatioFormula() {
    XCTAssertThrowsError(try ConvergenceValidation.richardson(coarse: 2, medium: 1.5, fine: 1.1,
      coarseStep: 0.4, mediumStep: 0.2, fineStep: 0.05, observableScale: 1,
      resolutionFloor: 0, minimumOrder: 1, maximumNormalizedIndex: 1))
  }

  func testCompleteSweepRequiresEveryDeclaredCell() throws {
    let axes = ["dt":["100","50"], "massRatio":["1","1000"]]
    let cells = axes["dt"]!.flatMap { dt in axes["massRatio"]!.map { ratio in
      ConvergenceValidation.SweepCell(coordinates: ["dt":dt,"massRatio":ratio], status: .passed)
    }}
    XCTAssertEqual(try ConvergenceValidation.coverage(axes: axes, cells: cells).status, .passed)
    XCTAssertEqual(try ConvergenceValidation.coverage(axes: axes, cells: Array(cells.dropLast())).status, .failed)
    XCTAssertEqual(try ConvergenceValidation.coverage(axes: axes, cells: cells + [cells[0]]).status, .failed)
  }

  func testUnknownAndInconclusiveSweepCellsDoNotCountAsPasses() throws {
    XCTAssertThrowsError(try ConvergenceValidation.coverage(axes: ["dt":["1"]],
      cells: [.init(coordinates: ["dt":"2"], status: .passed)]))
    XCTAssertEqual(try ConvergenceValidation.coverage(axes: ["dt":["1"]],
      cells: [.init(coordinates: ["dt":"1"], status: .inconclusive)]).status, .failed)
  }

  func testBallisticReferenceIncludesGravity() throws {
    let state = try AnalyticPhysicalReferences.ballistic(initial: .init(position: 10, velocity: 0), acceleration: -10, seconds: 1)
    XCTAssertEqual(state.position, 5)
    XCTAssertEqual(state.velocity, -10)
  }

  func testUndampedOscillatorConservesEnergy() throws {
    let initial = AnalyticPhysicalReferences.State(position: 0.7, velocity: -0.2)
    for step in 0..<20 {
      let result = try AnalyticPhysicalReferences.oscillator(initial: initial, mass: 2, stiffness: 8, damping: 0, seconds: Double(step) * 0.13)
      XCTAssertEqual(result.velocity * result.velocity + 4 * result.position * result.position,
        initial.velocity * initial.velocity + 4 * initial.position * initial.position, accuracy: 1e-12)
    }
  }

  func testCriticalAndOverdampedSolutionsSatisfyInitialConditionsAndEquilibrium() throws {
    for damping in [2.0,3.0,1000.0] {
      let initial = AnalyticPhysicalReferences.State(position: 2, velocity: 0.5)
      let zero = try AnalyticPhysicalReferences.oscillator(initial: initial, mass: 1, stiffness: 1,
        damping: damping, constantForce: 1, seconds: 0)
      XCTAssertEqual(zero.position, 2, accuracy: 1e-12)
      XCTAssertEqual(zero.velocity, 0.5, accuracy: 1e-12)
      let settled = try AnalyticPhysicalReferences.oscillator(initial: initial, mass: 1, stiffness: 1,
        damping: damping, constantForce: 1, seconds: 100_000)
      XCTAssertEqual(settled.position, 1, accuracy: 1e-10)
      XCTAssertEqual(settled.velocity, 0, accuracy: 1e-10)
    }
  }

  func testActivationHasDeclaredTimeConstantAndBounds() throws {
    XCTAssertEqual(try AnalyticPhysicalReferences.activation(initial: 0, excitation: 1, tauSeconds: 0.02, seconds: 0.02), 1 - exp(-1), accuracy: 1e-14)
    XCTAssertThrowsError(try AnalyticPhysicalReferences.activation(initial: -0.1, excitation: 1, tauSeconds: 1, seconds: 1))
    XCTAssertThrowsError(try AnalyticPhysicalReferences.activation(initial: 0, excitation: 1, tauSeconds: 0, seconds: 1))
  }

  func testPiolaStressIsDerivativeOfEnergyAndTangentIsDerivativeOfStress() throws {
    for stretch in [0.5,0.9,1,1.2,2] {
      let epsilon = 1e-5, mu = 1000.0
      let value = try AnalyticPhysicalReferences.neoHookeanUniaxial(stretch: stretch, shearModulusPascals: mu)
      let plus = try AnalyticPhysicalReferences.neoHookeanUniaxial(stretch: stretch + epsilon, shearModulusPascals: mu)
      let minus = try AnalyticPhysicalReferences.neoHookeanUniaxial(stretch: stretch - epsilon, shearModulusPascals: mu)
      XCTAssertEqual((plus.energyJoulesPerCubicMeter - minus.energyJoulesPerCubicMeter) / (2 * epsilon), value.firstPiolaPascals, accuracy: 1e-4)
      XCTAssertEqual((plus.firstPiolaPascals - minus.firstPiolaPascals) / (2 * epsilon), value.tangentPascals, accuracy: 1e-4)
    }
  }

  func testMaterialProbeFailsWrongStressMeasure() throws {
    let stretches = [1.0,1.2]
    let ref = try stretches.map { try AnalyticPhysicalReferences.neoHookeanUniaxial(stretch: $0, shearModulusPascals: 1000) }
    let probe = GateDProbe.material(stretches: stretches,
      firstPiolaPascals: zip(stretches, ref).map { $0 * $1.firstPiolaPascals }, // Cauchy, intentionally wrong
      tangentPascals: ref.map(\.tangentPascals), strainEnergyDensities: ref.map(\.energyJoulesPerCubicMeter),
      shearModulusPascals: 1000, stressScalePascals: 1000, energyDensityScale: 1000, tolerance: 1e-6)
    XCTAssertEqual(try probe.evaluate().diagnosticStatus, .failed)
  }
}

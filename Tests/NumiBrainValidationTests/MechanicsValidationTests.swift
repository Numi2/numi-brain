import XCTest
@testable import NumiBrainValidation

final class MechanicsValidationTests: XCTestCase {
  func testInverseConsistencyChecksBothDirections() throws {
    let good = try MechanicsValidation.inverseConsistency(rhs: [2, 3], actionOfInverse: [2, 3],
      velocity: [1, 2], inverseOfAction: [1, 2], rhsScales: [2, 3], velocityScales: [1, 2], tolerance: 1e-6)
    XCTAssertEqual(good.status, .passed)
    let bad = try MechanicsValidation.inverseConsistency(rhs: [2], actionOfInverse: [2],
      velocity: [1], inverseOfAction: [1.1], rhsScales: [2], velocityScales: [1], tolerance: 1e-3)
    XCTAssertEqual(bad.status, .failed)
  }

  func testTangentAgainstIndependentQuadraticResidual() throws {
    let x = 0.7, direction = 0.2, epsilon = 1e-4
    let result = try MechanicsValidation.tangent(action: [2 * x * direction],
      residualPlus: [pow(x + epsilon * direction, 2)], residualMinus: [pow(x - epsilon * direction, 2)],
      epsilon: epsilon, residualScales: [1], baseActiveSet: 7, plusActiveSet: 7, minusActiveSet: 7, tolerance: 1e-8)
    XCTAssertEqual(result.status, .passed)
  }

  func testActiveSetChangeIsNotASmoothDerivativePass() throws {
    let result = try MechanicsValidation.tangent(action: [1], residualPlus: [1], residualMinus: [0],
      epsilon: 0.5, residualScales: [1], baseActiveSet: 1, plusActiveSet: 2, minusActiveSet: 1, tolerance: 1)
    XCTAssertEqual(result.status, .inconclusive)
    XCTAssertTrue(result.metrics.isEmpty)
  }

  func testVirtualWorkChecksNativeDisplacementAndAppliedForce() throws {
    // J=[[1,2],[3,4]], dq=[.1,.2], f=[2,-1]; Jdq=[.5,1.1], J^Tf=[-1,0].
    let result = try MechanicsValidation.virtualWork(jacobian: [1,2,3,4], displacement: [0.1,0.2],
      pointDisplacement: [0.5,1.1], pointForce: [2,-1], appliedGeneralizedForce: [-1,0],
      pointScales: [1,1], workScaleJoules: 1, tolerance: 1e-12)
    XCTAssertEqual(result.status, .passed)
    let wrong = try MechanicsValidation.virtualWork(jacobian: [1,2,3,4], displacement: [0.1,0.2],
      pointDisplacement: [0.5,1.1], pointForce: [2,-1], appliedGeneralizedForce: [-2,0],
      pointScales: [1,1], workScaleJoules: 1, tolerance: 1e-6)
    XCTAssertEqual(wrong.status, .failed)
  }

  func testMomentumIncludesSupportImpulseAndAngularImpulse() throws {
    let result = try MechanicsValidation.momentum(linearBefore: [1,2,3], linearAfter: [2,4,6],
      externalImpulse: [1,2,3], angularBefore: [4,5,6], angularAfter: [3,3,3],
      externalAngularImpulse: [-1,-2,-3], linearScale: 1, angularScale: 1, tolerance: 0)
    XCTAssertEqual(result.status, .passed)
  }

  func testEnergyIncludesActuationAndDissipationExactlyOnce() throws {
    XCTAssertEqual(try MechanicsValidation.energy(beforeJoules: 10, afterJoules: 12,
      externalWorkJoules: 1, actuatorWorkJoules: 3, dissipatedJoules: 2, scaleJoules: 10, tolerance: 0).status, .passed)
    let result = try MechanicsValidation.energy(beforeJoules: 10, afterJoules: 13,
      externalWorkJoules: 1, actuatorWorkJoules: 3, dissipatedJoules: 2, scaleJoules: 10, tolerance: 0)
    XCTAssertEqual(result.status, .failed)
    XCTAssertEqual(result.metrics[1].residual, 0.1, accuracy: 1e-14)
    XCTAssertThrowsError(try MechanicsValidation.energy(beforeJoules: 1, afterJoules: 1,
      externalWorkJoules: 0, actuatorWorkJoules: 0, dissipatedJoules: -1, scaleJoules: 1, tolerance: 0))
  }

  private func contact(gap: Double = 0, normal: Double = 10, tangent: [Double] = [-3,-4],
    slip: [Double] = [0.6,0.8], mu: Double = 0.5) throws -> PhysicalValidationResult {
    try MechanicsValidation.contact(gapMeters: gap, normalForceNewtons: normal, tangentialForceNewtons: tangent,
      slipVelocityMetersPerSecond: slip, friction: mu, lengthScaleMeters: 1, forceScaleNewtons: 10,
      velocityScaleMetersPerSecond: 1, stickingSpeedMetersPerSecond: 1e-6, tolerance: 1e-12)
  }

  func testCircularCoulombConeAndMaximumDissipation() throws {
    XCTAssertEqual(try contact().status, .passed)
    XCTAssertEqual(try contact(tangent: [-5,-5]).status, .failed) // passes a box, not the circular cone
  }

  func testConeBoundaryWithWrongDirectionFails() throws {
    XCTAssertEqual(try contact(tangent: [-5,0]).status, .failed)
    XCTAssertEqual(try contact(tangent: [3,4]).status, .failed)
  }

  func testSeparationCannotCarryNormalLoad() throws {
    XCTAssertEqual(try contact(gap: 0.01).status, .failed)
    XCTAssertEqual(try contact(gap: -0.01).status, .failed)
    XCTAssertEqual(try contact(normal: -1).status, .failed)
    XCTAssertEqual(try contact(gap: 1, normal: 0, tangent: [0,0]).status, .passed)
  }

  func testStictionAndFrictionlessContact() throws {
    XCTAssertEqual(try contact(tangent: [1,2], slip: [0,0]).status, .passed)
    XCTAssertEqual(try contact(tangent: [0,0], mu: 0).status, .passed)
    XCTAssertEqual(try contact(tangent: [1,0], mu: 0).status, .failed)
  }

  func testTendonDiagnosticsAreNotAnAdditionalForce() throws {
    let entries = [
      MechanicsValidation.ForceContribution(physicalSource: "muscle-1", owner: "MyoSim", applied: true, generalizedForce: [2,3]),
      MechanicsValidation.ForceContribution(physicalSource: "muscle-1", owner: "NHTENDON", applied: false, generalizedForce: [2,3]),
    ]
    let result = try MechanicsValidation.forceAccounting(contributions: entries, requiredPhysicalSources: ["muscle-1"],
      appliedTotal: [2,3], independentTotal: [2,3], scales: [1,1], tolerance: 0)
    XCTAssertEqual(result.status, .passed)
  }

  func testDuplicateForceDetectedEvenWhenNumericalContributionsCancel() throws {
    let entries = [
      MechanicsValidation.ForceContribution(physicalSource: "muscle-1", owner: "MyoSim", applied: true, generalizedForce: [1]),
      MechanicsValidation.ForceContribution(physicalSource: "muscle-1", owner: "NHTENDON", applied: true, generalizedForce: [-1]),
    ]
    let result = try MechanicsValidation.forceAccounting(contributions: entries, requiredPhysicalSources: ["muscle-1"],
      appliedTotal: [0], independentTotal: [0], scales: [1], tolerance: 0)
    XCTAssertEqual(result.status, .failed)
    XCTAssertEqual(result.metrics[0].residual, 1)
  }

  func testMissingRegisteredForceCannotPassAssemblyCheck() throws {
    let result = try MechanicsValidation.forceAccounting(contributions: [.init(physicalSource: "a", owner: "Human",
      applied: true, generalizedForce: [1])], requiredPhysicalSources: ["a","b"], appliedTotal: [1], independentTotal: [1],
      scales: [1], tolerance: 0)
    XCTAssertEqual(result.status, .failed)
  }

  func testReductionIsCoordinateScaledAndChecksEveryCoordinate() throws {
    XCTAssertEqual(try MechanicsValidation.reduction(coupled: [1,2], standalone: [1,2], scales: [1,100], tolerance: 0).status, .passed)
    XCTAssertEqual(try MechanicsValidation.reduction(coupled: [1,3], standalone: [1,2], scales: [1,100], tolerance: 0.001).status, .failed)
  }

  func testNaNsEmptyShapesAndZeroScalesNeverPass() {
    for values in [[], [Double.nan], [Double.infinity]] {
      XCTAssertThrowsError(try MechanicsValidation.reduction(coupled: values, standalone: [0], scales: [1], tolerance: 0))
    }
    XCTAssertThrowsError(try MechanicsValidation.reduction(coupled: [1], standalone: [1], scales: [0], tolerance: 0))
    XCTAssertThrowsError(try MechanicsValidation.reduction(coupled: [1], standalone: [1], scales: [1], tolerance: -1))
  }

  func testTypedProbeRoundTripAndJSONNaNRejection() throws {
    let probe = GateDProbe.energy(beforeJoules: 1, afterJoules: 2, externalWorkJoules: 1,
      actuatorWorkJoules: 0, dissipatedJoules: 0, scaleJoules: 1, tolerance: 0)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(probe)
    let decoded = try JSONDecoder().decode(GateDProbe.self, from: data)
    XCTAssertEqual(decoded, probe)
    XCTAssertEqual(try decoded.evaluate().diagnosticStatus, .passed)
    XCTAssertEqual(data, try encoder.encode(decoded))
  }
}

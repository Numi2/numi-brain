import Foundation
import XCTest
import NumiBrainCore

final class NumiLabTaskActionContractTests: XCTestCase {
  private let revision = String(repeating: "a", count: 40)

  private func robot() throws -> NumiLabRobotInterface {
    let origin: [String: Float] = ["x": 0, "y": 0, "z": 0]
    let joint: [String: Any] = ["jointIdentifier": 0, "parentBodyIdentifier": 0,
      "childBodyIdentifier": 1, "parentLocalAnchor": origin, "childLocalAnchor": origin,
      "restRelativeOrientation": ["x": 0, "y": 0, "z": 0, "w": 1],
      "coordinates": [["identifier": 0, "kind": 1,
        "parentLocalAxis": ["x": 0, "y": 0, "z": 1],
        "minimumPosition": -1, "maximumPosition": 1.5, "restPosition": 0.5]]]
    let actuator: [String: Any] = ["id": "hip", "kind": 0, "target": "hinge",
      "scale": 0.5, "responseTimeSeconds": 0, "component": 0,
      "qIndex": 7, "vIndex": 6, "parameters": [0,0,0,0], "terms": []]
    let object: [String: Any] = ["version": 1, "nativeRepositoryRevision": revision,
      "robotID": "synthetic", "sourceRepository": "", "sourceRevision": "", "license": "",
      "bodyNames": ["base", "link"], "jointNames": ["hinge"], "joints": [joint],
      "actuators": [actuator], "nativeKinematicsSamples": 3,
      "scope": "topology-and-actuator-metadata-only"]
    let data = try JSONSerialization.data(withJSONObject: object)
    return try NumiLabRobotInterface(data: data,
      expectedSHA256: BrainPolicyEvidenceArtifact.sha256(data), expectedNativeRevision: revision)
  }

  private func contract(_ robot: NumiLabRobotInterface,
    ids: [String] = ["hip"], minimum: Float = -1, maximum: Float = 1) throws -> NumiLabTaskActionContract {
    try NumiLabTaskActionContract(nativeRepositoryRevision: revision,
      robotContentSHA256: robot.contentSHA256, worldFingerprint: 1,
      taskFingerprint: 2, actionFingerprint: 3, robotFingerprint: 4,
      actuatorIdentifiers: ids, normalizedMinimum: minimum, normalizedMaximum: maximum)
  }

  private func receipt(q: UInt32? = 7, v: UInt32? = 6, scale: Float = 0.5,
    lower: Float = 0, upper: Float = 1, actionFingerprint: UInt64 = 3) throws -> NumiLabCompiledTaskActionReceipt {
    try NumiLabCompiledTaskActionReceipt(runFingerprint: 9, worldFingerprint: 1,
      taskFingerprint: 2, actionFingerprint: actionFingerprint, robotFingerprint: 4,
      bindings: [NumiLabCompiledTaskActionBinding(actionIndex: 0, qIndex: q, vIndex: v,
        actuatorKind: .jointPosition, resolvedComponent: 0, componentLane: 0,
        normalizedScale: scale, lowerTarget: lower, upperTarget: upper,
        responseTimeSeconds: 0)])
  }

  func testAbsoluteAndNormalizedPositionCoordinatesRoundTrip() throws {
    let robot = try robot()
    let encoder = try NumiLabPositionActionEncoder(robot: robot, contract: contract(robot))
    XCTAssertFalse(encoder.isPhysicalOwnerBound)
    XCTAssertEqual(try encoder.encodeAbsolutePositions([0.5]), [0])
    XCTAssertEqual(try encoder.encodeAbsolutePositions([0.75]), [0.5])
    XCTAssertEqual(try encoder.encodeAbsolutePositions([0]), [-1])
    XCTAssertEqual(try encoder.decodeNormalizedPositions([0.5]), [0.75])
    XCTAssertEqual(try encoder.decodeNormalizedPositions([-1]), [0])
  }

  func testCompiledTaskReceiptProducesExecutionBoundEncoder() throws {
    let robot = try robot(), contract = try contract(robot)
    let encoder = try NumiLabPositionActionEncoder(robot: robot, contract: contract,
      compiledTask: receipt())
    XCTAssertTrue(encoder.isPhysicalOwnerBound)
    XCTAssertEqual(encoder.compiledRunFingerprint, 9)
    XCTAssertEqual(encoder.lanes[0].qIndex, 7)
    XCTAssertEqual(encoder.lanes[0].vIndex, 6)
    XCTAssertEqual(encoder.lanes[0].minimumPosition, 0)
    XCTAssertEqual(encoder.lanes[0].maximumPosition, 1)
    XCTAssertEqual(try encoder.encodeAbsolutePositions([0.75]), [0.5])
    XCTAssertThrowsError(try encoder.encodeAbsolutePositions([-0.25]))
  }

  func testCompiledTaskBuildsPositionMotorContractNotMuscleOutput() throws {
    let robot = try robot(), contract = try contract(robot)
    let encoder = try NumiLabPositionActionEncoder(robot: robot, contract: contract,
      compiledTask: receipt())
    let motor = try encoder.motorTopology(neutralCommands: ["hip": 0.5],
      emergencyCommands: ["hip": 0.25], synergyCount: 1, motorNucleusCount: 1,
      autonomicActionDimension: 1, activeSensingActionDimension: 0)
    XCTAssertEqual(motor.actuatorCommandKind, .position)
    XCTAssertEqual(motor.actuatorCount, 1)
    XCTAssertEqual(motor.actuatorChannels[0].outputMinimum, 0)
    XCTAssertEqual(motor.actuatorChannels[0].outputMaximum, 1)
    XCTAssertEqual(motor.actuatorChannels[0].neutralCommand, 0.5)
    XCTAssertEqual(motor.actuatorChannels[0].emergencyCommand, 0.25)
    let structural = try NumiLabPositionActionEncoder(robot: robot, contract: contract)
    XCTAssertThrowsError(try structural.motorTopology(neutralCommands: ["hip": 0.5],
      emergencyCommands: ["hip": 0.25], synergyCount: 1, motorNucleusCount: 1,
      autonomicActionDimension: 1, activeSensingActionDimension: 0))
    XCTAssertThrowsError(try encoder.motorTopology(neutralCommands: ["hip": 0.5],
      emergencyCommands: [:], synergyCount: 1, motorNucleusCount: 1,
      autonomicActionDimension: 1, activeSensingActionDimension: 0))
  }

  func testCompiledTaskReceiptRejectsForeignCoordinateAuthorityAndIdentity() throws {
    let robot = try robot(), contract = try contract(robot)
    XCTAssertThrowsError(try NumiLabPositionActionEncoder(robot: robot, contract: contract,
      compiledTask: receipt(q: 8)))
    XCTAssertThrowsError(try NumiLabPositionActionEncoder(robot: robot, contract: contract,
      compiledTask: receipt(scale: 0.25)))
    XCTAssertThrowsError(try NumiLabPositionActionEncoder(robot: robot, contract: contract,
      compiledTask: receipt(lower: -1.25)))
    XCTAssertThrowsError(try NumiLabPositionActionEncoder(robot: robot, contract: contract,
      compiledTask: receipt(actionFingerprint: 30)))
  }

  func testJointLimitsDoNotSilentlyExpandNormalizedTaskAuthority() throws {
    let robot = try robot()
    let encoder = try NumiLabPositionActionEncoder(robot: robot, contract: contract(robot))
    // 1.25 rad is inside the mechanism limit but beyond the task's +1 residual
    // because this actuator's native scale is 0.5 around a 0.5-rad rest pose.
    XCTAssertThrowsError(try encoder.encodeAbsolutePositions([1.25]))
    XCTAssertThrowsError(try encoder.decodeNormalizedPositions([1.1]))
  }

  func testTaskOrderIsExplicitAndCannotBeInferredFromRobotOrder() throws {
    let robot = try robot()
    XCTAssertThrowsError(try NumiLabPositionActionEncoder(robot: robot,
      contract: contract(robot, ids: ["missing"])))
    XCTAssertThrowsError(try NumiLabTaskActionContract(nativeRepositoryRevision: revision,
      robotContentSHA256: robot.contentSHA256, worldFingerprint: 1,
      taskFingerprint: 2, actionFingerprint: 3, robotFingerprint: 4,
      actuatorIdentifiers: ["hip", "hip"]))
  }

  func testForeignRobotIdentityAndTaskFingerprintsFailClosed() throws {
    let robot = try robot()
    let foreign = try NumiLabTaskActionContract(nativeRepositoryRevision: revision,
      robotContentSHA256: String(repeating: "0", count: 64), worldFingerprint: 1,
      taskFingerprint: 2, actionFingerprint: 3, robotFingerprint: 4,
      actuatorIdentifiers: ["hip"])
    XCTAssertThrowsError(try NumiLabPositionActionEncoder(robot: robot, contract: foreign))
    XCTAssertThrowsError(try NumiLabTaskActionContract(nativeRepositoryRevision: revision,
      robotContentSHA256: robot.contentSHA256, worldFingerprint: 0,
      taskFingerprint: 2, actionFingerprint: 3, robotFingerprint: 4,
      actuatorIdentifiers: ["hip"]))
  }
}

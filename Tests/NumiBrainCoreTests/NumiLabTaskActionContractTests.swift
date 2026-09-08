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

  func testAbsoluteAndNormalizedPositionCoordinatesRoundTrip() throws {
    let robot = try robot()
    let encoder = try NumiLabPositionActionEncoder(robot: robot, contract: contract(robot))
    XCTAssertEqual(try encoder.encodeAbsolutePositions([0.5]), [0])
    XCTAssertEqual(try encoder.encodeAbsolutePositions([0.75]), [0.5])
    XCTAssertEqual(try encoder.encodeAbsolutePositions([0]), [-1])
    XCTAssertEqual(try encoder.decodeNormalizedPositions([0.5]), [0.75])
    XCTAssertEqual(try encoder.decodeNormalizedPositions([-1]), [0])
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

import Foundation
import XCTest
import NumiBrainCore

final class NumiLabRobotInterfaceTests: XCTestCase {
  private let revision = String(repeating: "a", count: 40)
  private func wire(rotor: Bool = false) -> [String: Any] {
    let origin: [String: Float] = ["x": 0, "y": 0, "z": 0]
    let joint: [String: Any] = ["jointIdentifier": 0, "parentBodyIdentifier": 0,
      "childBodyIdentifier": 1, "parentLocalAnchor": origin, "childLocalAnchor": origin,
      "restRelativeOrientation": ["x": 0, "y": 0, "z": 0, "w": 1],
      "coordinates": [["identifier": 0, "kind": 1,
        "parentLocalAxis": ["x": 0, "y": 0, "z": 1],
        "minimumPosition": -1, "maximumPosition": 2, "restPosition": 0.5]]]
    let actuator: [String: Any] = ["id": "command", "kind": rotor ? 5 : 0,
      "target": rotor ? "base" : "hinge", "scale": 0.25,
      "responseTimeSeconds": 0.02, "component": 0, "parameters": [0,0,0,0], "terms": []]
    return ["version": 1, "nativeRepositoryRevision": revision,
      "robotID": "synthetic_contract", "sourceRepository": "", "sourceRevision": "", "license": "",
      "bodyNames": rotor ? ["base"] : ["base", "link"],
      "jointNames": rotor ? [] : ["hinge"], "joints": rotor ? [] : [joint],
      "actuators": [actuator], "nativeKinematicsSamples": 3, "scope": "topology-and-actuator-metadata-only"]
  }
  private func load(_ object: [String: Any]) throws -> NumiLabRobotInterface {
    let data = try JSONSerialization.data(withJSONObject: object)
    return try NumiLabRobotInterface(data: data,
      expectedSHA256: BrainPolicyEvidenceArtifact.sha256(data), expectedNativeRevision: revision)
  }
  func testPositionChannelsRetainLimitsAndRequireExplicitEmergencyBehavior() throws {
    let imported = try load(wire())
    let channels = try imported.positionChannels(neutralCommands: ["command": 0.5], emergencyCommands: ["command": 0.25])
    XCTAssertEqual(channels.count, 1)
    XCTAssertEqual(channels[0].outputMinimum, -1)
    XCTAssertEqual(channels[0].outputMaximum, 2)
    XCTAssertEqual(channels[0].neutralCommand, 0.5)
    XCTAssertEqual(channels[0].emergencyCommand, 0.25)
    XCTAssertEqual(imported.actuators[0].responseTimeSeconds, 0.02)
    XCTAssertThrowsError(try imported.positionChannels(neutralCommands: [:], emergencyCommands: ["command": 0]))
    XCTAssertThrowsError(try imported.positionChannels(neutralCommands: ["command": 0], emergencyCommands: ["command": 3]))
    XCTAssertTrue(imported.license.isEmpty)
  }
  func testOwnerModelIdentityIsMandatoryAndIsNotAnExportChecksum() throws {
    let imported = try load(wire())
    XCTAssertThrowsError(try imported.jointTopologyCatalog(numanXModelFingerprint: 0))
    let first = try imported.jointTopologyCatalog(numanXModelFingerprint: 11)
    let second = try imported.jointTopologyCatalog(numanXModelFingerprint: 12)
    XCTAssertEqual(first.joints, second.joints)
    XCTAssertNotEqual(first.fingerprint, second.fingerprint)
    XCTAssertEqual(first.numanXModelFingerprint, 11)
  }
  func testJointlessRotorCannotBeCastAsAFlightJointOrMotorCurrent() throws {
    let imported = try load(wire(rotor: true))
    XCTAssertEqual(imported.actuators[0].kind, .rotorMixer)
    XCTAssertTrue(try imported.jointTopologyCatalog(numanXModelFingerprint: 1).joints.isEmpty)
    XCTAssertThrowsError(try imported.positionChannels(neutralCommands: ["command": 0], emergencyCommands: ["command": 0]))
  }
  func testForeignChecksumsRevisionsAndBudgetsFail() throws {
    let data = try JSONSerialization.data(withJSONObject: wire())
    let sha = BrainPolicyEvidenceArtifact.sha256(data)
    XCTAssertThrowsError(try NumiLabRobotInterface(data: data, expectedSHA256: String(repeating: "0", count: 64), expectedNativeRevision: revision))
    XCTAssertThrowsError(try NumiLabRobotInterface(data: data, expectedSHA256: sha, expectedNativeRevision: String(repeating: "b", count: 40)))
    XCTAssertThrowsError(try NumiLabRobotInterface(data: data, expectedSHA256: sha, expectedNativeRevision: revision, maximumBytes: 1))
  }
  func testDisconnectedTreesUnknownKindsAndUnresolvedActuatorsFail() throws {
    var value = wire(); value["joints"] = []
    XCTAssertThrowsError(try load(value))
    value = wire(); value["bodyNames"] = ["base", "base"]
    XCTAssertThrowsError(try load(value))
    for (key, bad): (String, Any) in [("target", "missing"), ("kind", 99), ("component", 1), ("parameters", [0,0,0]), ("scale", 0)] {
      value = wire(); var a = (value["actuators"] as! [[String: Any]])[0]; a[key] = bad; value["actuators"] = [a]
      XCTAssertThrowsError(try load(value))
    }
  }
  func testActualNativeAssetsImportWithTheirDistinctTopologyAndActuation() throws {
    guard let directory = ProcessInfo.processInfo.environment["NUMIBRAIN_NUMILAB_INTERFACES"] else {
      throw XCTSkip("native C++ asset export directory is not configured")
    }
    let nativeRevision = "68f5aa441a8437426de193a5c9beeac5a78113b6"
    for (id, bodies, joints, actuators) in [("franka_panda",11,10,9), ("unitree_g1",30,29,29), ("px4_x500",1,0,4)] {
      let data = try Data(contentsOf: URL(fileURLWithPath: directory).appendingPathComponent(id+".json"))
      let imported = try NumiLabRobotInterface(data: data,
        expectedSHA256: BrainPolicyEvidenceArtifact.sha256(data), expectedNativeRevision: nativeRevision)
      XCTAssertEqual(imported.robotID, id)
      XCTAssertEqual(imported.bodyNames.count, bodies)
      XCTAssertEqual(imported.joints.count, joints)
      XCTAssertEqual(imported.actuators.count, actuators)
      let catalog = try imported.jointTopologyCatalog(numanXModelFingerprint: 1) // structural test identity only
      XCTAssertEqual(catalog.joints.count, joints)
      if id == "px4_x500" {
        XCTAssertTrue(imported.actuators.allSatisfy { $0.kind == .rotorMixer })
        XCTAssertEqual(imported.actuators.map(\.component), [0,1,2,3])
      } else {
        let rest = Dictionary(uniqueKeysWithValues: imported.actuators.map { a in
          (a.id, imported.joints[imported.jointNames.firstIndex(of: a.target)!].coordinates[Int(a.component)].restPosition)
        })
        // Test values only; this does not declare these rest commands safe for deployment.
        XCTAssertEqual(try imported.positionChannels(neutralCommands: rest, emergencyCommands: rest).count, actuators)
      }
    }
  }
}

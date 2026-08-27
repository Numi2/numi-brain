import XCTest

@testable import NumiBrainCore

final class NumanXMuscleAttachmentCatalogTests: XCTestCase {
  func testCatalogPreservesRouteOrderAndMatchesMotorProfile() throws {
    let first = try NumanXMuscleAttachment(
      muscleIdentifier: 0,
      firstBodyIdentifier: 2,
      terminalBodyIdentifier: 7,
      routeNodeCount: 3,
      firstLocalPoint: try NumanXBodyLocalPoint(x: 0.1, y: -0.2, z: 0.3),
      terminalLocalPoint: try NumanXBodyLocalPoint(x: -0.4, y: 0.5, z: -0.6)
    )
    let second = try NumanXMuscleAttachment(
      muscleIdentifier: 4,
      firstBodyIdentifier: 7,
      terminalBodyIdentifier: 9,
      routeNodeCount: 2,
      firstLocalPoint: try NumanXBodyLocalPoint(x: 1, y: 2, z: 3),
      terminalLocalPoint: try NumanXBodyLocalPoint(x: 4, y: 5, z: 6)
    )
    let catalog = try NumanXMuscleAttachmentCatalog(
      bodyCount: 10,
      attachments: [first, second]
    )

    XCTAssertEqual(catalog.attachment(forMuscleIdentifier: 0), first)
    XCTAssertEqual(catalog.attachment(forMuscleIdentifier: 4), second)
    XCTAssertNil(catalog.attachment(forMuscleIdentifier: 3))
    XCTAssertEqual(catalog.fingerprintHex, "b4cce71bbf24254b")

    let profile = try ProtectiveMotorProfile(
      channels: [
        ProtectiveMuscleChannel(muscleIdentifier: 0, flags: []),
        ProtectiveMuscleChannel(muscleIdentifier: 4, flags: []),
      ]
    )
    XCTAssertNoThrow(try catalog.validate(profile: profile))
  }

  func testCatalogRejectsInvalidBodiesRoutesAndDuplicateMuscles() throws {
    let point = try NumanXBodyLocalPoint(x: 0, y: 0, z: 0)
    XCTAssertThrowsError(
      try NumanXMuscleAttachment(
        muscleIdentifier: 1,
        firstBodyIdentifier: 0,
        terminalBodyIdentifier: 1,
        routeNodeCount: 1,
        firstLocalPoint: point,
        terminalLocalPoint: point
      )
    )
    let attachment = try NumanXMuscleAttachment(
      muscleIdentifier: 1,
      firstBodyIdentifier: 0,
      terminalBodyIdentifier: 2,
      routeNodeCount: 2,
      firstLocalPoint: point,
      terminalLocalPoint: point
    )
    XCTAssertThrowsError(
      try NumanXMuscleAttachmentCatalog(bodyCount: 2, attachments: [attachment])
    )
    XCTAssertThrowsError(
      try NumanXMuscleAttachmentCatalog(
        bodyCount: 3,
        attachments: [attachment, attachment]
      )
    )
    XCTAssertThrowsError(try NumanXBodyLocalPoint(x: .nan, y: 0, z: 0))
  }

  func testCatalogDecodeRejectsFingerprintDrift() throws {
    let attachment = try NumanXMuscleAttachment(
      muscleIdentifier: 9,
      firstBodyIdentifier: 1,
      terminalBodyIdentifier: 2,
      routeNodeCount: 2,
      firstLocalPoint: try NumanXBodyLocalPoint(x: 0, y: 0, z: 0),
      terminalLocalPoint: try NumanXBodyLocalPoint(x: 1, y: 1, z: 1)
    )
    let catalog = try NumanXMuscleAttachmentCatalog(
      bodyCount: 3,
      attachments: [attachment]
    )
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(catalog))
        as? [String: Any]
    )
    object["fingerprint"] = 1
    XCTAssertThrowsError(
      try JSONDecoder().decode(
        NumanXMuscleAttachmentCatalog.self,
        from: JSONSerialization.data(withJSONObject: object)
      )
    )
  }
}

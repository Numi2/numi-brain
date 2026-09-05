import XCTest
@testable import NumiBrainCore

final class BrainGateDValiditySchemaTests: XCTestCase {
  private func schema(version: UInt32, mask: UInt32?) -> BrainGateDSensorSchema {
    BrainGateDSensorSchema(formatVersion: version, nativeModelSourceFingerprint: 1,
      compiledSpeciesTemplateFingerprint: 2, modality: .vestibular, receptorCount: 1,
      featureDimension: 22, ownerSchemaRevision: "fixture-only", fields: [
        .init(index: 15, quantity: "headHeight", unit: "m", frame: "world", coordinatePrefix: "body:", requiredValidityMask: mask)
      ])
  }
  func testLegacyImplicitValidityCannotQualifyANewTrace() {
    XCTAssertThrowsError(try schema(version: 1, mask: 1 << 15).validate())
    XCTAssertThrowsError(try schema(version: 2, mask: nil).validate())
    XCTAssertThrowsError(try schema(version: 2, mask: 0).validate())
  }
  func testExplicitOwnerDeclaredFieldMaskIsAccepted() {
    XCTAssertNoThrow(try schema(version: 2, mask: 1 << 15).validate())
  }
}

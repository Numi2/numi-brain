import CryptoKit
import Foundation
import XCTest
import NumiBrainCore
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class StandingSourceSupportAdmissionTests: XCTestCase {
  // The fixture is the 243,320-byte source exported by the native Human
  // feedback-disabled 500 ms run on 2026-09-23 (SHA-256
  // d42c6fbc5470da388e4cf1d43e5b81848acee309cb2a5f0d62991dd8f9df7de1).
  // These ten body/geometry pairs are the ordered NHCNT1 rows
  // admitted by that run; touch receptor indices follow the same order.
  private let nativeContacts: [(UInt32, UInt32)] = [
    (153, 408), (139, 377), (153, 409), (139, 378), (152, 405),
    (138, 374), (152, 406), (138, 375), (152, 407), (138, 376),
  ]

  private func fixture(_ name: String) throws -> Data {
    let path = try XCTUnwrap(Bundle.module.url(
      forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: path)
  }

  private func sourceObject() throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with:
      fixture("native-standing-source-20260923")) as? [String: Any])
  }

  private func endpoints() -> [[String: Any]] {
    nativeContacts.enumerated().map { index, contact in
      [
        "sourceEndpointIdentifier":
          UInt64(contact.0) << 32 | UInt64(contact.1),
        "bodyIdentifier": contact.0,
        "sourceGeometryIndex": contact.1,
        "touchReceptorIndex": UInt32(index),
      ]
    }
  }

  private func decode(_ object: [String: Any]) throws -> StandingSource {
    try JSONDecoder().decode(StandingSource.self,
      from: JSONSerialization.data(withJSONObject: object))
  }

  func testNativeTenContactSourceCompilesPhysicalSupportBindings() throws {
    var object = try sourceObject()
    let legacy = try decode(object).compile(latencyMicroseconds: 1_000)
    XCTAssertTrue(legacy.sensoryProfile.bodyReceptorBindings
      .filter { $0.signal == .support }.isEmpty)

    object["version"] = 2
    object["supportEndpoints"] = endpoints()
    let source = try decode(object)
    let template = try source.compile(latencyMicroseconds: 1_000)
    let bindings = template.sensoryProfile.bodyReceptorBindings
      .filter { $0.signal == .support }
      .sorted { $0.receptorIndex < $1.receptorIndex }
    XCTAssertEqual(bindings.count, 10)
    for (index, binding) in bindings.enumerated() {
      XCTAssertEqual(binding.bodyIdentifier, nativeContacts[index].0)
      XCTAssertEqual(binding.sourceEndpointIdentifier,
        UInt64(nativeContacts[index].0) << 32 | UInt64(nativeContacts[index].1))
      XCTAssertEqual(binding.receptorIndex, UInt32(index))
      XCTAssertEqual(binding.featureIndex, 4)
      XCTAssertEqual(binding.signal, .support)
    }
    XCTAssertNotEqual(template.sensoryProfile.fingerprint,
      legacy.sensoryProfile.fingerprint)
  }

  func testOldV1ProgramCannotBindNewSupportSource() throws {
    var object = try sourceObject()
    let legacySource = try decode(object)
    let legacyTemplate = try legacySource.compile(latencyMicroseconds: 1_000)
    // This is the retained feedback-disabled v1 program from the same native
    // run as the source fixture (SHA-256 3380ea6783dc8087160be9a71c1b2898
    // 18fe818674e7af0bc73a5303ea541f6c).
    let retainedProgram = try JSONDecoder().decode(MuscleLocomotorProgram.self,
      from: fixture("native-standing-program-v1-20260923"))
    let oldSourceHash = SHA256.hash(data:
      try fixture("native-standing-source-20260923"))
      .map { String(format: "%02x", $0) }.joined()
    XCTAssertEqual(retainedProgram.version, 1)
    XCTAssertEqual(retainedProgram.modelSourceFingerprint,
      legacySource.modelSourceFingerprint)
    XCTAssertEqual(retainedProgram.calibrationArtifactSHA256, oldSourceHash)
    let currentLegacyProgram = legacySource.baseline(template: legacyTemplate,
      sourceHash: oldSourceHash, epochMicroseconds: 1_000)
    XCTAssertNoThrow(try currentLegacyProgram.validate(template: legacyTemplate))

    object["version"] = 2
    object["supportEndpoints"] = endpoints()
    let newSourceData = try JSONSerialization.data(withJSONObject: object)
    let newSource = try JSONDecoder().decode(StandingSource.self, from: newSourceData)
    let newTemplate = try newSource.compile(latencyMicroseconds: 1_000)
    let newSourceHash = SHA256.hash(data: newSourceData)
      .map { String(format: "%02x", $0) }.joined()
    XCTAssertNotEqual(retainedProgram.calibrationArtifactSHA256, newSourceHash)
    XCTAssertNotEqual(retainedProgram.sensoryProfileFingerprint,
      newTemplate.sensoryProfile.fingerprint)
    XCTAssertThrowsError(try retainedProgram.validate(template: newTemplate))
    XCTAssertThrowsError(try currentLegacyProgram.validate(template: newTemplate))
    XCTAssertNoThrow(try newSource.baseline(template: newTemplate,
      sourceHash: newSourceHash, epochMicroseconds: 1_000)
      .validate(template: newTemplate))
  }

  func testMalformedOrDuplicateNativeSupportMappingFailsClosed() throws {
    let original = try sourceObject()
    var object = original
    object["supportEndpoints"] = endpoints()
    XCTAssertThrowsError(try decode(object).compile(latencyMicroseconds: 1_000))

    object = original
    object["version"] = 2
    XCTAssertThrowsError(try decode(object).compile(latencyMicroseconds: 1_000))

    object["supportEndpoints"] = NSNull()
    XCTAssertThrowsError(try decode(object))

    object["supportEndpoints"] = []
    XCTAssertThrowsError(try decode(object).compile(latencyMicroseconds: 1_000))

    var duplicate = endpoints()
    duplicate[1]["touchReceptorIndex"] = UInt32(0)
    object["supportEndpoints"] = duplicate
    XCTAssertThrowsError(try decode(object).compile(latencyMicroseconds: 1_000))

    var sameGeometryOtherBody = endpoints()
    sameGeometryOtherBody[1]["sourceGeometryIndex"] = UInt32(408)
    sameGeometryOtherBody[1]["sourceEndpointIdentifier"] = UInt64(139) << 32 | 408
    object["supportEndpoints"] = sameGeometryOtherBody
    XCTAssertNoThrow(try decode(object).compile(latencyMicroseconds: 1_000))

    var repeatedPair = endpoints()
    repeatedPair[1]["bodyIdentifier"] = UInt32(153)
    repeatedPair[1]["sourceGeometryIndex"] = UInt32(408)
    repeatedPair[1]["sourceEndpointIdentifier"] = UInt64(153) << 32 | 408
    object["supportEndpoints"] = repeatedPair
    XCTAssertThrowsError(try decode(object).compile(latencyMicroseconds: 1_000))

    var foreign = endpoints()
    foreign[0]["sourceGeometryIndex"] = UInt32(999)
    object["supportEndpoints"] = foreign
    XCTAssertThrowsError(try decode(object).compile(latencyMicroseconds: 1_000))

    object["supportEndpoints"] = endpoints()
    var partial = try XCTUnwrap(object["supportEndpoints"] as? [[String: Any]])
    partial[0].removeValue(forKey: "bodyIdentifier")
    object["supportEndpoints"] = partial
    XCTAssertThrowsError(try decode(object))
  }
}

import Foundation
import XCTest
@testable import NumiBrainQualification

final class QualificationDeclarationTests: XCTestCase {
  func testQualifiedStatusesRequireEvidenceButOpenWorkDoesNot() throws {
    for status in [GateEvidenceStatus.buildQualified, .executableQualified, .physicallyValidated,
                   .performanceQualified, .promotionReady] {
      XCTAssertThrowsError(try GateEvidenceEntry(gate: .A, status: status,
        sourceRevision: "test", evidenceSHA256: [], limitations: []))
    }
    XCTAssertNoThrow(try GateEvidenceEntry(gate: .A, status: .open,
      sourceRevision: "test", evidenceSHA256: [], limitations: []))
  }

  func testDeclaredPassingGatesCannotIssuePromotionAuthority() throws {
    let entries = try PromotionGate.allCases.map { gate in
      try GateEvidenceEntry(gate: gate, status: .promotionReady, sourceRevision: "test",
        evidenceSHA256: [String(repeating: "a", count: 64)], limitations: [])
    }
    let manifest = try NumanXQualificationManifest(sourceRevision: "test", entries: entries)
    XCTAssertTrue(manifest.declaredPromotionReady)
    XCTAssertFalse(manifest.promotionReady)
  }

  func testDecodedEmptyManifestCannotExploitVacuousAllSatisfy() throws {
    let data = Data(#"{"formatVersion":1,"sourceRevision":"test","entries":[]}"#.utf8)
    let manifest = try JSONDecoder().decode(NumanXQualificationManifest.self, from: data)
    XCTAssertThrowsError(try manifest.validate())
    XCTAssertFalse(manifest.declaredPromotionReady)
    XCTAssertFalse(manifest.promotionReady)
  }

  func testNestedDecodedEntriesAreRevalidated() throws {
    let entries = try PromotionGate.allCases.map { gate in
      try GateEvidenceEntry(gate: gate, status: .open, sourceRevision: "test", evidenceSHA256: [], limitations: [])
    }
    let original = try NumanXQualificationManifest(sourceRevision: "test", entries: entries)
    let data = try JSONEncoder().encode(original)
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var rows = try XCTUnwrap(json["entries"] as? [[String: Any]])
    rows[0]["status"] = "promotionReady"; json["entries"] = rows
    let decoded = try JSONDecoder().decode(NumanXQualificationManifest.self,
      from: JSONSerialization.data(withJSONObject: json))
    XCTAssertThrowsError(try decoded.validate())
  }
}

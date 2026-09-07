import XCTest
@testable import NumiBrainCore
import NumiBrainQualification

final class BrainAllGatesVerifierTests: XCTestCase {
  func testAdapterInventoryNamesEveryGateAndDoesNotClaimMissingAuthority() throws {
    let verifier = try BrainAllGatesVerifier(sourceRevision: "revision")
    XCTAssertEqual(Set(verifier.adapterStatus.map(\.gate)), Set(PromotionGate.allCases))
    let implemented = Set(verifier.adapterStatus.filter(\.authoritativeAdapterImplemented).map(\.gate))
    XCTAssertEqual(implemented, Set([.C, .D]))
  }

  func testEmptyAndDeclarationOnlyStateCannotFinalize() throws {
    let verifier = try BrainAllGatesVerifier(sourceRevision: "revision")
    XCTAssertThrowsError(try verifier.finalize([]))
    // The qualification declaration remains intentionally outside the API: no
    // manifest value can be supplied to finalize or converted to a receipt.
    XCTAssertFalse(verifier.adapterStatus.first(where: { $0.gate == .A })!.authoritativeAdapterImplemented)
    XCTAssertFalse(verifier.adapterStatus.first(where: { $0.gate == .F })!.authoritativeAdapterImplemented)
  }

  func testInvalidSourceRevisionIsRejected() {
    XCTAssertThrowsError(try BrainAllGatesVerifier(sourceRevision: ""))
    XCTAssertThrowsError(try BrainAllGatesVerifier(sourceRevision: String(repeating: "x", count: 257)))
  }
}

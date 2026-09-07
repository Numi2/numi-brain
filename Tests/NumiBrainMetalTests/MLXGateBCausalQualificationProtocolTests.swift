import Foundation
import XCTest
@testable import NumiBrainMLX
import NumiBrainCore

@available(macOS 26.0, *)
final class MLXGateBCausalQualificationProtocolTests: XCTestCase {
  private func valid() throws -> NumanXGateBCausalProtocol {
    try NumanXGateBCausalProtocol(modalities: [.proprioception, .touch],
      minimumGeneration: 2, maximumGeneration: 10, minimumTransitionsPerModality: 32,
      maximumIntactActionMSE: 0.25, minimumAblationActionDelta: 0.01,
      minimumShuffleActionDelta: 0.01, minimumTimestampShiftActionDelta: 0.01,
      shuffleSeed: 7)
  }

  func testProtocolCanonicalizesModalitiesAndRejectsWeakOrDuplicateCoverage() throws {
    let value = try valid()
    XCTAssertEqual(value.modalities, value.modalities.sorted { $0.rawValue < $1.rawValue })
    XCTAssertThrowsError(try NumanXGateBCausalProtocol(modalities: [.touch, .touch],
      minimumGeneration: 2, maximumGeneration: 10, minimumTransitionsPerModality: 32,
      maximumIntactActionMSE: 0.25, minimumAblationActionDelta: 0.01,
      minimumShuffleActionDelta: 0.01, minimumTimestampShiftActionDelta: 0.01,
      shuffleSeed: 7))
    XCTAssertThrowsError(try NumanXGateBCausalProtocol(modalities: [.touch],
      minimumGeneration: 2, maximumGeneration: 10, minimumTransitionsPerModality: 32,
      maximumIntactActionMSE: 0.25, minimumAblationActionDelta: 0,
      minimumShuffleActionDelta: 0.01, minimumTimestampShiftActionDelta: 0.01,
      shuffleSeed: 7))
  }

  func testDecodedProtocolCannotBypassValidation() throws {
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(valid())) as? [String: Any])
    object["maximumGeneration"] = 1
    let bytes = try JSONSerialization.data(withJSONObject: object)
    XCTAssertThrowsError(try JSONDecoder().decode(NumanXGateBCausalProtocol.self, from: bytes))
  }
}

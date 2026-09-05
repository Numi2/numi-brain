import Foundation
import XCTest
import NumiBrainValidation
@testable import NumiBrainCore

final class BrainReachHoldProtocolTests: XCTestCase {
  private func contract() throws -> BrainReachHoldProtocol {
    var target = [Float](repeating: 0, count: 16); target[2] = 0.25
    return BrainReachHoldProtocol(formatVersion: 1, identifier: "test", sourceRevision: "fixture",
      expectedNativeModelFingerprint: 1, parameterVersionFingerprint: 2,
      taskFingerprint: 3, sceneFingerprint: 4, objectFingerprint: 5, embodimentFingerprint: 6,
      episodeIdentifier: 1, randomSeed: 1, timestepMicroseconds: 100, targetState: target,
      objective: try ReachHoldObjective(targetPositionMeters: [0.25], durationMicroseconds: 1_000_000,
        holdDurationMicroseconds: 250_000, maximumSampleGapMicroseconds: 1000,
        positionScaleMeters: 0.1, maximumHoldErrorMeters: 0.01, maximumHoldSecantSpeedMetersPerSecond: 0.05,
        maximumMeanSquaredExcitation: 0.5, effortWeight: 0.1), calibrationSettingsSHA256: nil)
  }
  func testCaptureIncludesBootstrapAndTerminalInputAcquisition() throws {
    XCTAssertEqual(try contract().captureRootCount, 10_002)
  }
  func testGoalPreservesPhysicalBodyTargetAndExactPosition() throws {
    let value = try contract()
    let goal = try value.goal(controlStep: 2, committed: BrainTimestamp(microseconds: 200), target: BrainTimestamp(microseconds: 300))
    XCTAssertEqual(goal.targetBodyIdentifier, 23)
    XCTAssertEqual(goal.targetState.values[2], 0.25)
    XCTAssertEqual(goal.targetState.values[6], 0)
  }
  func testDecodeCannotChangeScoredTargetWithoutChangingAppliedGoal() throws {
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(contract())) as? [String: Any])
    var objective = try XCTUnwrap(json["objective"] as? [String: Any])
    objective["targetPositionMeters"] = [0.5]; json["objective"] = objective
    let decoded = try JSONDecoder().decode(BrainReachHoldProtocol.self, from: JSONSerialization.data(withJSONObject: json))
    XCTAssertThrowsError(try decoded.validate())
  }
  func testUnsupportedVelocityGoalAndZeroClockFail() throws {
    let bytes = try JSONEncoder().encode(contract())
    for field in ["timestepMicroseconds", "randomSeed", "parameterVersionFingerprint"] {
      var json = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any]); json[field] = 0
      let decoded = try JSONDecoder().decode(BrainReachHoldProtocol.self, from: JSONSerialization.data(withJSONObject: json))
      XCTAssertThrowsError(try decoded.validate())
    }
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    var target = [Float](repeating: 0, count: 16); target[2] = 0.25; target[6] = 1; json["targetState"] = target
    let decoded = try JSONDecoder().decode(BrainReachHoldProtocol.self, from: JSONSerialization.data(withJSONObject: json))
    XCTAssertThrowsError(try decoded.validate())
  }
}

import XCTest
@testable import NumiBrainValidation

final class ReachHoldObjectiveTests: XCTestCase {
  private func objective(target: Double = 1) throws -> ReachHoldObjective {
    try .init(targetPositionMeters: [target], durationMicroseconds: 1_000_000,
      holdDurationMicroseconds: 250_000, maximumSampleGapMicroseconds: 62_500,
      positionScaleMeters: 1, maximumHoldErrorMeters: 0.01,
      maximumHoldSecantSpeedMetersPerSecond: 0.05, maximumMeanSquaredExcitation: 0.5, effortWeight: 0.1)
  }
  private func samples(_ value: (Double) -> Double) -> [ReachHoldPositionSample] {
    (0...16).map { .init(timestampMicroseconds: UInt64($0 * 62_500), positionMeters: [value(Double($0) / 16)]) }
  }
  private var commands: [ReachHoldCommandInterval] {
    [.init(startMicroseconds: 0, endMicroseconds: 1_000_000, meanSquaredExcitation: 0.25)]
  }
  func testReachAndSettleCanSucceedWithNonzeroTrackingLoss() throws {
    let result = try ReachHoldEvaluator.evaluate(objective: objective(), positions: samples { min(1, $0 * 2) }, commands: commands)
    XCTAssertTrue(result.succeeds)
    XCTAssertEqual(result.normalizedTrackingMSE, 1.0 / 6, accuracy: 1e-12)
    XCTAssertEqual(result.objectiveLoss, 1.0 / 6 + 0.025, accuracy: 1e-12)
  }
  func testAcceptingRootsWithoutReachingDoesNotSucceed() throws {
    let result = try ReachHoldEvaluator.evaluate(objective: objective(), positions: samples { _ in 0 }, commands: commands)
    XCTAssertFalse(result.succeeds); XCTAssertEqual(result.normalizedTrackingMSE, 1)
  }
  func testTerminalPositionAloneCannotHideFailureToHold() throws {
    let result = try ReachHoldEvaluator.evaluate(objective: objective(), positions: samples { $0 }, commands: commands)
    XCTAssertFalse(result.succeeds); XCTAssertTrue(result.failures.contains("hold_secant_speed"))
  }
  func testRejectedAttemptsRemainFailuresEvenWithPerfectTracking() throws {
    let result = try ReachHoldEvaluator.evaluate(objective: objective(), positions: samples { _ in 1 },
      commands: commands, rejectedAttempts: 1, commandFailures: 1)
    XCTAssertEqual(result.failures, ["rejected_attempts", "command_failures"])
  }
  func testCommandClockIsIntegratedSeparatelyAndCannotHaveGaps() throws {
    let intervals = [ReachHoldCommandInterval(startMicroseconds: 0, endMicroseconds: 400_000, meanSquaredExcitation: 0),
      .init(startMicroseconds: 400_000, endMicroseconds: 1_100_000, meanSquaredExcitation: 0.5)]
    let result = try ReachHoldEvaluator.evaluate(objective: objective(), positions: samples { _ in 1 }, commands: intervals)
    XCTAssertEqual(result.meanSquaredExcitation, 0.3, accuracy: 1e-12)
    XCTAssertThrowsError(try ReachHoldEvaluator.evaluate(objective: objective(), positions: samples { _ in 1 },
      commands: [.init(startMicroseconds: 1, endMicroseconds: 1_000_000, meanSquaredExcitation: 0)]))
  }
  func testMissingSampleAndShortHorizonAreNotDiscarded() throws {
    var positions = samples { $0 }; positions.remove(at: 4)
    XCTAssertThrowsError(try ReachHoldEvaluator.evaluate(objective: objective(), positions: positions, commands: commands))
    XCTAssertThrowsError(try ReachHoldEvaluator.evaluate(objective: objective(), positions: Array(samples { $0 }.dropLast()), commands: commands))
    var invalid = samples { $0 }; invalid[3] = .init(timestampMicroseconds: 187_500, positionMeters: [.nan])
    XCTAssertThrowsError(try ReachHoldEvaluator.evaluate(objective: objective(), positions: invalid, commands: commands))
  }
  func testCommonLargeClockOriginPreservesMicroseconds() throws {
    let origin: UInt64 = (1 << 54) + 3
    let positions = samples { _ in 1 }.map { ReachHoldPositionSample(timestampMicroseconds: $0.timestampMicroseconds + origin, positionMeters: $0.positionMeters) }
    let intervals = commands.map { ReachHoldCommandInterval(startMicroseconds: $0.startMicroseconds + origin,
      endMicroseconds: $0.endMicroseconds + origin, meanSquaredExcitation: $0.meanSquaredExcitation) }
    XCTAssertTrue(try ReachHoldEvaluator.evaluate(objective: objective(), positions: positions, commands: intervals).succeeds)
  }
}

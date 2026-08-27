import XCTest

@testable import NumiBrainCore

final class TimestampedRelayHistoryTests: XCTestCase {
  func testPhysicalDelaySamplingIsExactAndInterpolated() throws {
    var history = try TimestampedRelayHistory(
      originTimestamp: BrainTimestamp(microseconds: 0),
      values: [0, 10],
      capacity: 4
    )
    try history.append(
      timestamp: BrainTimestamp(microseconds: 1_000),
      values: [1, 11]
    )
    try history.append(
      timestamp: BrainTimestamp(microseconds: 2_000),
      values: [2, 12]
    )

    XCTAssertEqual(
      try history.sample(
        at: BrainTimestamp(microseconds: 2_000),
        delayMicroseconds: 0
      ),
      [2, 12]
    )
    XCTAssertEqual(
      try history.sample(
        at: BrainTimestamp(microseconds: 2_000),
        delayMicroseconds: 1_000
      ),
      [1, 11]
    )
    XCTAssertEqual(
      try history.sample(
        at: BrainTimestamp(microseconds: 2_000),
        delayMicroseconds: 500
      ),
      [1.5, 11.5]
    )
  }

  func testOriginBoundaryAndLostCoverageFailClosed() throws {
    var history = try TimestampedRelayHistory(
      originTimestamp: BrainTimestamp(microseconds: 0),
      values: [4],
      capacity: 3
    )
    try history.append(timestamp: BrainTimestamp(microseconds: 1_000), values: [5])
    try history.append(timestamp: BrainTimestamp(microseconds: 2_000), values: [6])
    try history.append(timestamp: BrainTimestamp(microseconds: 3_000), values: [7])

    XCTAssertEqual(history.sampleCount, 3)
    XCTAssertEqual(history.oldestTimestamp, BrainTimestamp(microseconds: 1_000))
    XCTAssertEqual(history.newestTimestamp, BrainTimestamp(microseconds: 3_000))
    XCTAssertEqual(
      try history.sample(
        at: BrainTimestamp(microseconds: 3_000),
        delayMicroseconds: 3_000
      ),
      [4]
    )
    XCTAssertThrowsError(
      try history.sample(
        at: BrainTimestamp(microseconds: 3_000),
        delayMicroseconds: 2_500
      )
    )
  }

  func testRejectedValueCopyDoesNotAlterCommittedHistory() throws {
    let committed = try TimestampedRelayHistory(
      originTimestamp: BrainTimestamp(microseconds: 0),
      values: [0.25, 0.75],
      capacity: 4
    )
    var candidate = committed
    try candidate.append(
      timestamp: BrainTimestamp(microseconds: 750),
      values: [0.5, 0.5]
    )

    XCTAssertNotEqual(candidate.stableHash(), committed.stableHash())
    XCTAssertEqual(committed.sampleCount, 1)
    XCTAssertEqual(
      try committed.sample(
        at: BrainTimestamp(microseconds: 750),
        delayMicroseconds: 0
      ),
      [0.25, 0.75]
    )
  }

  func testTimestampAndShapeValidationRejectsInvalidSamples() throws {
    XCTAssertThrowsError(
      try TimestampedRelayHistory(
        originTimestamp: BrainTimestamp(microseconds: 0),
        values: [],
        capacity: 4
      )
    )
    var history = try TimestampedRelayHistory(
      originTimestamp: BrainTimestamp(microseconds: 1_000),
      values: [1, 2],
      capacity: 2
    )
    XCTAssertThrowsError(
      try history.append(
        timestamp: BrainTimestamp(microseconds: 1_000),
        values: [3, 4]
      )
    )
    XCTAssertThrowsError(
      try history.append(
        timestamp: BrainTimestamp(microseconds: 2_000),
        values: [3]
      )
    )
    XCTAssertThrowsError(
      try history.sample(
        at: BrainTimestamp(microseconds: 999),
        delayMicroseconds: 0
      )
    )
  }
}

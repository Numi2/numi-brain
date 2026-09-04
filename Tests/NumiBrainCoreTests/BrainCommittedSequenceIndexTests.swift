import XCTest
@testable import NumiBrainCore

final class BrainCommittedSequenceIndexTests: XCTestCase {
  private func record(
    _ generation: UInt64, start: UInt64? = nil, end: UInt64? = nil,
    identifier: UInt64? = nil, parameter: UInt64 = 7
  ) -> BrainCommittedSequenceRecord {
    BrainCommittedSequenceRecord(
      identifier: identifier ?? generation,
      sourceGeneration: generation,
      startTimestampMicroseconds: start ?? (generation - 1) * 100,
      endTimestampMicroseconds: end ?? generation * 100,
      parameterVersionFingerprint: parameter
    )
  }

  private func index(_ records: [BrainCommittedSequenceRecord?]) throws
    -> BrainCommittedSequenceIndex
  {
    try BrainCommittedSequenceIndex(
      records: records, parameterVersionFingerprint: 7,
      maximumSourceGeneration: UInt64.max
    )
  }

  func testWrappedRingUsesIdentityRatherThanSlotOrder() throws {
    let result = try index([record(4), record(5), nil, record(2), record(3)])
    XCTAssertEqual(result.oneStepSuccessors, [1, -1, -1, 4, 0])
    XCTAssertEqual(result.twoStepSuccessors, [-1, -1, -1, 0, 1])
    XCTAssertEqual(result.validRecordCount, 4)
  }

  func testMissingGenerationAndTimestampGapNeverJoin() throws {
    let result = try index([
      record(1), record(3), record(4, start: 301), record(5), nil,
    ])
    XCTAssertEqual(result.oneStepSuccessors, [-1, -1, 3, -1, -1])
    XCTAssertEqual(result.twoStepSuccessors, [-1, -1, -1, -1, -1])
  }

  func testSubFloatResolutionTimestampsRemainDistinct() throws {
    let t: UInt64 = (1 << 54) + 3
    let result = try index([
      record(1, start: t, end: t + 1),
      record(2, start: t + 2, end: t + 3),
      record(3, start: t + 3, end: t + 4),
    ])
    XCTAssertEqual(result.oneStepSuccessors, [-1, 2, -1])
  }

  func testMaximumGenerationCannotWrapToZero() throws {
    let result = try index([
      record(UInt64.max, start: 1, end: 2),
      record(UInt64.max - 1, start: 0, end: 1),
    ])
    XCTAssertEqual(result.oneStepSuccessors, [-1, 0])
    XCTAssertEqual(result.twoStepSuccessors, [-1, -1])
  }

  func testDuplicateGenerationsAndIdentifiersFailClosed() {
    XCTAssertThrowsError(try index([record(1), record(1, identifier: 2)])) {
      XCTAssertEqual($0 as? BrainCommittedSequenceIndexError, .duplicateGeneration(1))
    }
    XCTAssertThrowsError(try index([record(1), record(2, identifier: 1)])) {
      XCTAssertEqual($0 as? BrainCommittedSequenceIndexError, .duplicateIdentifier(1))
    }
  }

  func testInvalidIdentityTimeAndUncommittedGenerationFailClosed() {
    XCTAssertThrowsError(try index([record(1, parameter: 8)]))
    XCTAssertThrowsError(try index([record(1, start: 2, end: 1)]))
    XCTAssertThrowsError(try index([record(1, identifier: 0)]))
    XCTAssertThrowsError(try BrainCommittedSequenceIndex(
      records: [record(2)], parameterVersionFingerprint: 7,
      maximumSourceGeneration: 1
    ))
    XCTAssertThrowsError(try index([]))
  }

  func testEmptyCommittedSnapshotHasNoTemporalEdges() throws {
    let result = try BrainCommittedSequenceIndex(
      records: [nil, nil], parameterVersionFingerprint: 7,
      maximumSourceGeneration: 0
    )
    XCTAssertEqual(result.validRecordCount, 0)
    XCTAssertEqual(result.oneStepSuccessors, [-1, -1])
  }

  func testGatherIndicesMatchSmallDenseOracleAcrossPermutations() throws {
    for count in 2...37 {
      // Reversal and rotation exercise wrap without nondeterministic RNG.
      let records = (1...count).reversed().map { record(UInt64($0)) }
      let rotation = count / 2
      let permuted: [BrainCommittedSequenceRecord?] =
        Array(records[rotation...] + records[..<rotation])
      let result = try index(permuted)
      for source in permuted.indices {
        let next = permuted.indices.filter {
          permuted[$0]!.sourceGeneration == permuted[source]!.sourceGeneration + 1
            && permuted[$0]!.startTimestampMicroseconds
              == permuted[source]!.endTimestampMicroseconds
        }
        XCTAssertEqual(result.oneStepSuccessors[source], next.first.map(Int32.init) ?? -1)
        let second = next.first.flatMap { first -> Int32? in
          let row = result.oneStepSuccessors[first]
          return row == -1 ? nil : row
        }
        XCTAssertEqual(result.twoStepSuccessors[source], second ?? -1)
      }
    }
  }

  func testLargeRingRetainsOnlyTwoLinearIndexArrays() throws {
    let count = 100_000
    let records: [BrainCommittedSequenceRecord?] = (1...count).map { record(UInt64($0)) }
    let result = try index(records)
    XCTAssertEqual(result.capacity, count)
    XCTAssertEqual(result.validRecordCount, count)
    XCTAssertEqual(result.oneStepSuccessors[0], 1)
    XCTAssertEqual(result.twoStepSuccessors[0], 2)
    XCTAssertEqual(result.oneStepSuccessors[count - 1], -1)
    XCTAssertEqual(result.twoStepSuccessors[count - 2], -1)
    XCTAssertEqual((result.oneStepSuccessors.count + result.twoStepSuccessors.count)
      * MemoryLayout<Int32>.stride, 800_000)
  }
}

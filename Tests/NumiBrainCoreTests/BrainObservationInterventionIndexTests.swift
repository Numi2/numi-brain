import XCTest
@testable import NumiBrainCore

final class BrainObservationInterventionIndexTests: XCTestCase {
  private func sequence(gapBefore: UInt64? = nil) throws -> BrainCommittedSequenceIndex {
    try BrainCommittedSequenceIndex(
      records: (1...6).map { generation in
        let g = UInt64(generation)
        return BrainCommittedSequenceRecord(
          identifier: g, sourceGeneration: g,
          startTimestampMicroseconds: (g - 1) * 100 + (g == gapBefore ? 1 : 0),
          endTimestampMicroseconds: g * 100,
          parameterVersionFingerprint: 7
        )
      }, parameterVersionFingerprint: 7, maximumSourceGeneration: 6
    )
  }

  func testShufflePreservesAvailabilityAndLeavesUnselectedRowsUntouched() throws {
    let bits: [UInt32] = [7, 1, 7, 1, 2, 7]
    let plan = try BrainObservationInterventionIndex(
      sequenceIndex: sequence(), selectedRows: [0, 1, 2, 3, 4],
      observationValidityBits: bits, componentStart: 0, shuffleSeed: 1
    )
    XCTAssertEqual(plan.shuffledRows, [2, 3, 0, 1, 4, 5])
    for row in 0..<5 {
      XCTAssertEqual(bits[row], bits[Int(plan.shuffledRows[row])])
    }
    XCTAssertEqual(plan.shiftedRows, [-1, 0, 1, 2, 3, -1])
  }

  func testTimestampShiftNeverUsesTrainingPrefixOrBridgesAMissingRow() throws {
    let plan = try BrainObservationInterventionIndex(
      sequenceIndex: sequence(), selectedRows: [2, 3, 5],
      observationValidityBits: [UInt32](repeating: 7, count: 6),
      componentStart: 0, shuffleSeed: 0
    )
    XCTAssertEqual(plan.shiftedRows, [-1, -1, -1, 2, -1, -1])
  }

  func testTimestampDiscontinuityIsNotAValidShift() throws {
    let plan = try BrainObservationInterventionIndex(
      sequenceIndex: sequence(gapBefore: 3), selectedRows: Array(0..<6),
      observationValidityBits: [UInt32](repeating: 7, count: 6),
      componentStart: 0, shuffleSeed: 0
    )
    XCTAssertEqual(plan.shiftedRows, [-1, 0, -1, 2, 3, 4])
  }

  func testFinalModalityUsesItsOwnThreeValidityBits() throws {
    let bits: [UInt32] = [7 << 21, 1 << 21, (7 << 21) | 1, (1 << 21) | 7, 0, 0]
    let plan = try BrainObservationInterventionIndex(
      sequenceIndex: sequence(), selectedRows: Array(0..<6),
      observationValidityBits: bits, componentStart: 21, shuffleSeed: 99
    )
    XCTAssertEqual(plan.shuffledRows, [2, 3, 0, 1, 5, 4])
  }

  func testSeededDerangementIsDeterministicAndDoesNotSelectSelf() throws {
    func plan(_ seed: UInt64) throws -> BrainObservationInterventionIndex {
      try BrainObservationInterventionIndex(
        sequenceIndex: sequence(), selectedRows: Array(0..<6),
        observationValidityBits: [UInt32](repeating: 7, count: 6),
        componentStart: 0, shuffleSeed: seed
      )
    }
    XCTAssertEqual(try plan(123), try plan(123))
    XCTAssertNotEqual(try plan(0).shuffledRows, try plan(1).shuffledRows)
    let rows = try plan(UInt64.max).shuffledRows
    XCTAssertEqual(Set(rows), Set((0..<6).map(Int32.init)))
    for row in 0..<6 { XCTAssertNotEqual(rows[row], Int32(row)) }
  }

  func testEmptySelectionMakesNoImplicitIntervention() throws {
    let plan = try BrainObservationInterventionIndex(
      sequenceIndex: sequence(), selectedRows: [],
      observationValidityBits: [UInt32](repeating: 0, count: 6),
      componentStart: 0, shuffleSeed: 1
    )
    XCTAssertEqual(plan.shuffledRows, [0, 1, 2, 3, 4, 5])
    XCTAssertEqual(plan.shiftedRows, [-1, -1, -1, -1, -1, -1])
  }

  func testInvalidShapesAndSelectionsAreRejected() throws {
    let index = try sequence()
    for rows in [[0, 0], [-1], [6]] {
      XCTAssertThrowsError(try BrainObservationInterventionIndex(
        sequenceIndex: index, selectedRows: rows,
        observationValidityBits: [UInt32](repeating: 7, count: 6),
        componentStart: 0, shuffleSeed: 1
      ))
    }
    for start in [-1, 1, 22, 24] {
      XCTAssertThrowsError(try BrainObservationInterventionIndex(
        sequenceIndex: index, selectedRows: [],
        observationValidityBits: [UInt32](repeating: 7, count: 6),
        componentStart: start, shuffleSeed: 1
      ))
    }
    XCTAssertThrowsError(try BrainObservationInterventionIndex(
      sequenceIndex: index, selectedRows: [], observationValidityBits: [],
      componentStart: 0, shuffleSeed: 1
    ))
  }
}

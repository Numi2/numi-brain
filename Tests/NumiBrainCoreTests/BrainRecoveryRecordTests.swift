import Foundation
import XCTest
@testable import NumiBrainCore

final class BrainRecoveryRecordTests: XCTestCase {
  private func chain(_ decisions: [BrainRecoveryDecision]) throws -> [BrainRecoveryRecord] {
    var records: [BrainRecoveryRecord] = []
    for decision in decisions {
      records.append(try BrainRecoveryRecord(sequence: UInt64(records.count), decision: decision,
        transactionFingerprint: 7, preparedPayloadFingerprint: 11,
        previousRecordFingerprint: records.last?.recordFingerprint ?? 0))
    }
    return records
  }
  private func validate(_ records: [BrainRecoveryRecord]) throws {
    try BrainRecoveryRecord.validateChain(records, transactionFingerprint: 7, preparedPayloadFingerprint: 11)
  }
  func testEveryLegalPrefixAndTerminalDecisionIsAccepted() throws {
    for decisions: [BrainRecoveryDecision] in [[.prepared], [.prepared, .commitDecided],
      [.prepared, .commitDecided, .committed], [.prepared, .aborted]] {
      XCTAssertNoThrow(try validate(chain(decisions)))
    }
  }
  func testIllegalChainsFailEvenWithCorrectlyRecomputedFingerprints() throws {
    for decisions: [BrainRecoveryDecision] in [[], [.commitDecided], [.prepared, .committed],
      [.prepared, .aborted, .commitDecided], [.prepared, .commitDecided, .aborted],
      [.prepared, .prepared], [.prepared, .aborted, .aborted]] {
      XCTAssertThrowsError(try validate(chain(decisions)))
    }
  }
  func testChangingFinalRecordDigestCannotHideBehindPreviousLink() throws {
    let original = try chain([.prepared, .commitDecided])
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [[String: Any]])
    json[1]["recordFingerprint"] = 1
    let modified = try JSONDecoder().decode([BrainRecoveryRecord].self,
      from: JSONSerialization.data(withJSONObject: json))
    XCTAssertThrowsError(try validate(modified))
  }
  func testForeignRootOrPayloadAndSkippedSequenceFail() throws {
    let source = try chain([.prepared])
    XCTAssertThrowsError(try BrainRecoveryRecord.validateChain(source, transactionFingerprint: 8, preparedPayloadFingerprint: 11))
    XCTAssertThrowsError(try BrainRecoveryRecord.validateChain(source, transactionFingerprint: 7, preparedPayloadFingerprint: 12))
    let skipped = try BrainRecoveryRecord(sequence: 2, decision: .commitDecided,
      transactionFingerprint: 7, preparedPayloadFingerprint: 11, previousRecordFingerprint: source[0].recordFingerprint)
    XCTAssertThrowsError(try validate(source + [skipped]))
  }
}

import Foundation
import XCTest
import NumiBrainABI
@testable import NumiBrainCore

final class BrainPreparedNativeReceiptsTests: XCTestCase {
  private struct Fixture {
    let root: BrainJointTransactionToken
    let substep: BrainJointSubstepToken
    let accepted: AcceptedPhysicsStateToken
    let commit: BrainJointCommitToken
    let saved: BrainPreparedNativeReceipts
  }

  private func fixture(environment: UInt32 = 3, physicalFingerprint: UInt64 = 0x1234) throws -> Fixture {
    let root = try BrainJointTransactionToken(environmentIdentifier: environment,
      episodeIdentifier: 8, controlStepIdentifier: 21, parameterVersionFingerprint: 0x12345678,
      baseBrainGeneration: 10, basePhysicsGeneration: 40,
      committedTimestamp: BrainTimestamp(microseconds: 100_000),
      targetTimestamp: BrainTimestamp(microseconds: 120_000), randomCounterGeneration: 7)
    var transaction = BrainJointTransaction(token: root)
    let substep = try transaction.beginPhysicsSubstep(durationMicroseconds: 20_000)
    let accepted = try AcceptedPhysicsStateToken(transaction: root, substep: substep,
      physicsStateFingerprint: physicalFingerprint, physicsGeneration: 41)
    try transaction.acceptPhysicsSubstep(accepted, for: substep)
    let commit = try transaction.commit()
    let saved = try BrainPreparedNativeReceipts(root: root, substep: substep,
      acceptedPhysics: accepted, jointCommit: commit, physicalCheckpointFingerprint: 0x9876)
    return Fixture(root: root, substep: substep, accepted: accepted, commit: commit, saved: saved)
  }

  func testReceiptRoundTripPreservesTheOriginalNativeRecords() throws {
    let value = try fixture()
    let data = try JSONEncoder().encode(value.saved)
    let decoded = try JSONDecoder().decode(BrainPreparedNativeReceipts.self, from: data)
    XCTAssertEqual(try decoded.validated(), value.saved)
    XCTAssertEqual(try decoded.acceptedPhysicsToken(), value.accepted)
    XCTAssertEqual(try decoded.substepToken(), value.substep)
    XCTAssertEqual(try decoded.jointCommitFingerprint(), value.commit.fingerprint)
  }

  func testReceiptByteCountsMatchCompiledABI() throws {
    let value = try fixture().saved
    XCTAssertEqual(value.substepBytes.count, MemoryLayout<NBJointSubstepToken>.stride)
    XCTAssertEqual(value.acceptedPhysicsBytes.count, MemoryLayout<NBAcceptedPhysicsStateToken>.stride)
    XCTAssertEqual(value.jointCommitBytes.count, MemoryLayout<NBJointCommitToken>.stride)
    XCTAssertEqual(value.substepBytes.count, BrainJointSubstepToken.byteCount)
    XCTAssertEqual(value.acceptedPhysicsBytes.count, AcceptedPhysicsStateToken.byteCount)
    XCTAssertEqual(value.jointCommitBytes.count, BrainJointCommitToken.byteCount)
  }

  func testAnotherEnvironmentCannotSupplyAcceptanceOrCommit() throws {
    let first = try fixture(), other = try fixture(environment: 4)
    XCTAssertThrowsError(try BrainPreparedNativeReceipts(root: first.root, substep: first.substep,
      acceptedPhysics: other.accepted, jointCommit: first.commit, physicalCheckpointFingerprint: 123))
    XCTAssertThrowsError(try BrainPreparedNativeReceipts(root: first.root, substep: first.substep,
      acceptedPhysics: first.accepted, jointCommit: other.commit, physicalCheckpointFingerprint: 123))
  }

  func testDifferentValidPhysicalContentCannotReuseAnOldCommit() throws {
    let first = try fixture(physicalFingerprint: 100), other = try fixture(physicalFingerprint: 200)
    XCTAssertEqual(first.root, other.root)
    XCTAssertNotEqual(first.accepted.fingerprint, other.accepted.fingerprint)
    XCTAssertThrowsError(try BrainPreparedNativeReceipts(root: first.root, substep: first.substep,
      acceptedPhysics: other.accepted, jointCommit: first.commit, physicalCheckpointFingerprint: 123))
  }

  func testMissingPhysicalCheckpointIdentityIsRejected() throws {
    let value = try fixture()
    XCTAssertThrowsError(try BrainPreparedNativeReceipts(root: value.root, substep: value.substep,
      acceptedPhysics: value.accepted, jointCommit: value.commit, physicalCheckpointFingerprint: 0))
  }

  func testAllThreeRecordSectionsAreBoundIntoTheDigest() throws {
    let value = try fixture().saved
    for field in ["substepBytes", "acceptedPhysicsBytes", "jointCommitBytes"] {
      var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
      let text = try XCTUnwrap(object[field] as? String)
      var bytes = try XCTUnwrap(Data(base64Encoded: text))
      bytes[0] ^= 1
      object[field] = bytes.base64EncodedString()
      let changed = try JSONDecoder().decode(BrainPreparedNativeReceipts.self,
        from: JSONSerialization.data(withJSONObject: object))
      XCTAssertThrowsError(try changed.validated(), field)
    }
  }

  func testTruncatedRecordIsRejectedBeforeUnalignedLoad() throws {
    let value = try fixture().saved
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    object["acceptedPhysicsBytes"] = Data([1, 2, 3]).base64EncodedString()
    let changed = try JSONDecoder().decode(BrainPreparedNativeReceipts.self,
      from: JSONSerialization.data(withJSONObject: object))
    XCTAssertThrowsError(try changed.validated())
  }

  func testRecordVersionAndCheckpointIdentityAreNotMutableMetadata() throws {
    let value = try fixture().saved
    for field in ["version", "physicalCheckpointFingerprint"] {
      var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
      object[field] = NSNumber(value: 99)
      let changed = try JSONDecoder().decode(BrainPreparedNativeReceipts.self,
        from: JSONSerialization.data(withJSONObject: object))
      XCTAssertThrowsError(try changed.validated(), field)
    }
  }
}

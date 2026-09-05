import Foundation
import XCTest
@testable import NumiBrainCore

final class BrainJointPreparedManifestTests: XCTestCase {
  private func root() throws -> BrainPreparedRoot {
    BrainPreparedRoot(try BrainJointTransactionToken(environmentIdentifier: 3,
      episodeIdentifier: 8, controlStepIdentifier: 21,
      parameterVersionFingerprint: 0x1234_5678,
      baseBrainGeneration: 10, basePhysicsGeneration: 40,
      committedTimestamp: BrainTimestamp(microseconds: 100_000),
      targetTimestamp: BrainTimestamp(microseconds: 120_000),
      randomCounterGeneration: 7))
  }

  private func artifacts(root: BrainPreparedRoot) throws -> [BrainPreparedParticipantArtifact] {
    let token = try root.validatedToken()
    let hash = String(repeating: "a", count: 64)
    return [
      try .init(kind: .cognitiveArena, transactionFingerprint: token.fingerprint,
        baseGeneration: token.baseBrainGeneration, shadowGeneration: token.shadowGeneration,
        immutableProgramFingerprint: 11, payloadSHA256: hash, payloadBytes: 128),
      try .init(kind: .fastTissue, transactionFingerprint: token.fingerprint,
        baseGeneration: token.baseBrainGeneration, shadowGeneration: token.shadowGeneration,
        immutableProgramFingerprint: 12, payloadSHA256: hash, payloadBytes: 256),
      try .init(kind: .physicalSolver, transactionFingerprint: token.fingerprint,
        baseGeneration: token.basePhysicsGeneration, shadowGeneration: token.basePhysicsGeneration + 1,
        immutableProgramFingerprint: 13, payloadSHA256: hash, payloadBytes: 512),
      try .init(kind: .externalArchive, transactionFingerprint: token.fingerprint,
        baseGeneration: token.baseBrainGeneration, shadowGeneration: token.shadowGeneration,
        immutableProgramFingerprint: 14, payloadSHA256: hash, payloadBytes: 64),
    ]
  }

  func testManifestRoundTripBindsAllParticipantsToOneRoot() throws {
    let root = try root()
    let source = try BrainJointPreparedManifest(root: root,
      parameterVersionFingerprint: try root.validatedToken().parameterVersionFingerprint,
      participants: artifacts(root: root))
    let data = try JSONEncoder().encode(source)
    let decoded = try JSONDecoder().decode(BrainJointPreparedManifest.self, from: data)
    XCTAssertEqual(try decoded.validated(), source)
    XCTAssertEqual(decoded.participant(.physicalSolver).baseGeneration, 40)
  }

  func testMixedTransactionArtifactIsRejected() throws {
    let root = try root()
    var items = try artifacts(root: root)
    let old = items.remove(at: 2)
    items.append(try .init(kind: .physicalSolver,
      transactionFingerprint: old.transactionFingerprint &+ 1,
      baseGeneration: old.baseGeneration, shadowGeneration: old.shadowGeneration,
      immutableProgramFingerprint: old.immutableProgramFingerprint,
      payloadSHA256: old.payloadSHA256, payloadBytes: old.payloadBytes))
    XCTAssertThrowsError(try BrainJointPreparedManifest(root: root,
      parameterVersionFingerprint: try root.validatedToken().parameterVersionFingerprint,
      participants: items))
  }

  func testDecisionIdentityChangesBetweenCommitAndAbort() throws {
    let root = try root()
    let manifest = try BrainJointPreparedManifest(root: root,
      parameterVersionFingerprint: try root.validatedToken().parameterVersionFingerprint,
      participants: artifacts(root: root))
    let commit = try BrainJointPreparedDecisionRecord(manifest: manifest, decision: .commit)
    let abort = try BrainJointPreparedDecisionRecord(manifest: manifest, decision: .abort)
    XCTAssertEqual(commit.manifestSHA256, abort.manifestSHA256)
    XCTAssertNotEqual(commit.decisionSHA256, abort.decisionSHA256)
  }
}

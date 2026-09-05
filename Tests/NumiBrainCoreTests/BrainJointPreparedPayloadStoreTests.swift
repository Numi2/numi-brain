import Foundation
import CryptoKit
import XCTest
#if canImport(Darwin)
import Darwin
#endif
@testable import NumiBrainCore

@MainActor
final class BrainJointPreparedPayloadStoreTests: XCTestCase {
  private struct Fixture {
    let manifest: BrainJointPreparedManifest
    let payloads: [BrainPreparedParticipantKind: Data]
  }

  private func fixture() throws -> Fixture {
    let token = try BrainJointTransactionToken(environmentIdentifier: 3,
      episodeIdentifier: 8, controlStepIdentifier: 21, parameterVersionFingerprint: 0x12345678,
      baseBrainGeneration: 10, basePhysicsGeneration: 40,
      committedTimestamp: BrainTimestamp(microseconds: 100_000),
      targetTimestamp: BrainTimestamp(microseconds: 120_000), randomCounterGeneration: 7)
    var payloads: [BrainPreparedParticipantKind: Data] = [:]
    let artifacts = try BrainPreparedParticipantKind.allCases.map { kind in
      // Storage fixtures, not evidence that a real solver captured its complete native state.
      let bytes = Data("storage-fixture:\(kind.rawValue):same-joint-root".utf8)
      payloads[kind] = bytes
      let base = kind == .physicalSolver ? token.basePhysicsGeneration : token.baseBrainGeneration
      return try BrainPreparedParticipantArtifact(kind: kind, transactionFingerprint: token.fingerprint,
        baseGeneration: base, shadowGeneration: base + 1,
        immutableProgramFingerprint: UInt64(kind.rawValue) + 100,
        payloadSHA256: SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(),
        payloadBytes: UInt64(bytes.count))
    }
    return Fixture(manifest: try BrainJointPreparedManifest(root: BrainPreparedRoot(token),
      parameterVersionFingerprint: token.parameterVersionFingerprint, participants: artifacts), payloads: payloads)
  }

  private func directory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("joint-native-payloads-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    return url
  }

  private func materialize(_ fixture: Fixture, in store: BrainJointPreparedManifestStore) async throws {
    for artifact in fixture.manifest.participants {
      let bytes = try XCTUnwrap(fixture.payloads[artifact.kind])
      _ = try await store.storeParticipant(artifact, bytes: bytes)
    }
  }

  func testDigestOnlyManifestCannotPrepare() async throws {
    let url = try directory(); defer { try? FileManager.default.removeItem(at: url) }
    let store = try BrainJointPreparedManifestStore(directoryURL: url), value = try fixture()
    do { _ = try await store.prepare(value.manifest); XCTFail("digest-only prepare must fail") }
    catch {}
    let name = String(value.manifest.root.fingerprint, radix: 16) + ".joint-prepared"
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.appendingPathComponent(name).path))
    try await store.close()
  }

  func testWrongParticipantBytesCannotEnterStore() async throws {
    let url = try directory(); defer { try? FileManager.default.removeItem(at: url) }
    let store = try BrainJointPreparedManifestStore(directoryURL: url), value = try fixture()
    let artifact = try XCTUnwrap(value.manifest.participants.first)
    do { _ = try await store.storeParticipant(artifact, bytes: Data([1, 2])); XCTFail("wrong payload") }
    catch {}
    XCTAssertFalse(FileManager.default.fileExists(atPath:
      url.appendingPathComponent(artifact.payloadSHA256 + ".joint-payload").path))
    try await store.close()
  }

  func testOneMissingParticipantPreventsWholeRootPreparation() async throws {
    let url = try directory(); defer { try? FileManager.default.removeItem(at: url) }
    let store = try BrainJointPreparedManifestStore(directoryURL: url), value = try fixture()
    for artifact in value.manifest.participants where artifact.kind != .physicalSolver {
      let bytes = try XCTUnwrap(value.payloads[artifact.kind])
      _ = try await store.storeParticipant(artifact, bytes: bytes)
    }
    do { _ = try await store.prepare(value.manifest); XCTFail("missing physical bytes") }
    catch {}
    try await store.close()
  }

  func testPrepareAndPayloadsSurviveExplicitCloseReopenWithoutInventingDecision() async throws {
    let url = try directory(); defer { try? FileManager.default.removeItem(at: url) }
    let value = try fixture()
    let first = try BrainJointPreparedManifestStore(directoryURL: url)
    try await materialize(value, in: first)
    _ = try await first.prepare(value.manifest)
    _ = try await first.prepare(value.manifest)
    try await first.close()
    let reopened = try BrainJointPreparedManifestStore(directoryURL: url)
    let recovered = try await reopened.recover(rootFingerprint: value.manifest.root.fingerprint)
    XCTAssertEqual(recovered.manifest, value.manifest)
    XCTAssertNil(recovered.decision)
    for artifact in value.manifest.participants {
      let bytes = try await reopened.participantBytes(rootFingerprint: value.manifest.root.fingerprint, kind: artifact.kind)
      XCTAssertEqual(bytes, value.payloads[artifact.kind])
    }
    try await reopened.close()
  }

  func testCommitRequiresAllStillMatchingPayloadsAndCannotBecomeAbort() async throws {
    let url = try directory(); defer { try? FileManager.default.removeItem(at: url) }
    let store = try BrainJointPreparedManifestStore(directoryURL: url), value = try fixture()
    try await materialize(value, in: store)
    _ = try await store.prepare(value.manifest)
    let first = try await store.decide(rootFingerprint: value.manifest.root.fingerprint, decision: .commit)
    let repeated = try await store.decide(rootFingerprint: value.manifest.root.fingerprint, decision: .commit)
    XCTAssertEqual(first, repeated)
    do {
      _ = try await store.decide(rootFingerprint: value.manifest.root.fingerprint, decision: .abort)
      XCTFail("commit is irreversible")
    } catch {}
    try await store.close()
    let reopened = try BrainJointPreparedManifestStore(directoryURL: url)
    let recovered = try await reopened.recover(rootFingerprint: value.manifest.root.fingerprint)
    XCTAssertEqual(recovered.decision, first)
    try await reopened.close()
  }

  func testCorruptionAfterPrepareBlocksCommitButExplicitAbortRemainsInspectable() async throws {
    let url = try directory(); defer { try? FileManager.default.removeItem(at: url) }
    let store = try BrainJointPreparedManifestStore(directoryURL: url), value = try fixture()
    try await materialize(value, in: store)
    _ = try await store.prepare(value.manifest)
    let artifact = try XCTUnwrap(value.manifest.participants.first)
    let path = url.appendingPathComponent(artifact.payloadSHA256 + ".joint-payload")
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
    var corrupted = try XCTUnwrap(value.payloads[artifact.kind]); corrupted[0] ^= 1
    try corrupted.write(to: path)
    do { _ = try await store.decide(rootFingerprint: value.manifest.root.fingerprint, decision: .commit); XCTFail("changed bytes") }
    catch {}
    do { _ = try await store.recover(rootFingerprint: value.manifest.root.fingerprint); XCTFail("undecided corrupt root") }
    catch {}
    _ = try await store.decide(rootFingerprint: value.manifest.root.fingerprint, decision: .abort)
    let aborted = try await store.recover(rootFingerprint: value.manifest.root.fingerprint)
    XCTAssertEqual(aborted.decision?.decision, .abort)
    try await store.close()
  }

  func testPayloadSymlinkCannotSubstituteEvenIdenticalBytes() async throws {
    let url = try directory(); defer { try? FileManager.default.removeItem(at: url) }
    let store = try BrainJointPreparedManifestStore(directoryURL: url), value = try fixture()
    try await materialize(value, in: store)
    let artifact = try XCTUnwrap(value.manifest.participants.first)
    let expected = url.appendingPathComponent(artifact.payloadSHA256 + ".joint-payload")
    let relocated = url.appendingPathComponent("relocated.bin")
    try FileManager.default.moveItem(at: expected, to: relocated)
    try FileManager.default.createSymbolicLink(at: expected, withDestinationURL: relocated)
    do { _ = try await store.prepare(value.manifest); XCTFail("symlink must fail even if target hashes correctly") }
    catch {}
    try await store.close()
  }

  func testSecondWriterAndClosedStoreCannotOperate() async throws {
    let url = try directory(); defer { try? FileManager.default.removeItem(at: url) }
    let store = try BrainJointPreparedManifestStore(directoryURL: url), value = try fixture()
    XCTAssertThrowsError(try BrainJointPreparedManifestStore(directoryURL: url))
    try await store.close()
    do { _ = try await store.prepare(value.manifest); XCTFail("closed store") }
    catch {}
    let reopened = try BrainJointPreparedManifestStore(directoryURL: url)
    try await reopened.close()
  }

  func testWholeRootByteBudgetAppliesBeforeManifestPublication() async throws {
    let url = try directory(); defer { try? FileManager.default.removeItem(at: url) }
    let value = try fixture()
    let store = try BrainJointPreparedManifestStore(directoryURL: url,
      maximumParticipantBytes: 64, maximumRootBytes: 64)
    try await materialize(value, in: store)
    do { _ = try await store.prepare(value.manifest); XCTFail("aggregate root exceeds budget") }
    catch {}
    try await store.close()
  }

  #if canImport(Darwin)
  func testFIFOReplacementIsRejectedWithoutBlockingReader() async throws {
    let url = try directory(); defer { try? FileManager.default.removeItem(at: url) }
    let store = try BrainJointPreparedManifestStore(directoryURL: url), value = try fixture()
    try await materialize(value, in: store)
    let artifact = try XCTUnwrap(value.manifest.participants.first)
    let path = url.appendingPathComponent(artifact.payloadSHA256 + ".joint-payload")
    try FileManager.default.removeItem(at: path)
    XCTAssertEqual(path.path.withCString { mkfifo($0, mode_t(0o600)) }, 0)
    do { _ = try await store.prepare(value.manifest); XCTFail("FIFO is not a durable participant") }
    catch {}
    try await store.close()
  }
  #endif
}

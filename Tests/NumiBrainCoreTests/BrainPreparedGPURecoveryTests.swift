import Foundation
import XCTest
@testable import NumiBrainCore

@MainActor
final class BrainPreparedGPURecoveryTests: XCTestCase {
  private func root() throws -> BrainPreparedRoot {
    BrainPreparedRoot(try BrainJointTransactionToken(environmentIdentifier: 7,
      episodeIdentifier: 23, controlStepIdentifier: 17, parameterVersionFingerprint: 0x123456789abcdef0,
      baseBrainGeneration: 9, basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 80_000),
      targetTimestamp: BrainTimestamp(microseconds: 100_000), randomCounterGeneration: 55))
  }
  private func journal(destinations: [UInt64] = [0]) -> Data {
    var bytes = Data(repeating: 0, count: 48 + max(destinations.count, 1) * 64)
    func put<T: FixedWidthInteger>(_ value: T, at offset: Int) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { bytes.replaceSubrange(offset..<(offset + $0.count), with: $0) }
    }
    put(UInt32(1), at: 0); put(UInt32(destinations.count), at: 4)
    put(UInt32(max(destinations.count, 1)), at: 8); put(UInt32(1), at: 12)
    put(UInt64(9), at: 16); put(UInt64(10), at: 24); put(UInt64(64), at: 32)
    for (index, destination) in destinations.enumerated() {
      let offset = 48 + index * 64
      put(destination, at: offset); put(UInt64(10), at: offset + 8)
      put(UInt32(4), at: offset + 32); put(UInt32(1), at: offset + 36)
      put(UInt32(0x3f800000), at: offset + 48)
    }
    return bytes
  }
  private func image(shadow: Data? = nil, journal bytes: Data? = nil) throws -> BrainPreparedGPUImage {
    try .init(root: root(), cachedDecisionFingerprint: 11, acceptedPhysicsTokenFingerprint: 12,
      hotLayoutFingerprint: 13, memoryLayoutFingerprint: 14,
      baseHotState: Data(repeating: 1, count: 64), shadowHotState: shadow ?? Data(repeating: 2, count: 64),
      basePersistentMemory: Data(repeating: 0, count: 64), shadowJournal: bytes ?? journal())
  }
  private func directory() throws -> URL {
    let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("numibrain-prepare-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    return root
  }
  func testByteExactCodableRoundTripAndNativeRootValidation() throws {
    let source = try image()
    let decoded = try JSONDecoder().decode(BrainPreparedGPUImage.self, from: JSONEncoder().encode(source))
    XCTAssertEqual(try decoded.validated(), source)
    XCTAssertEqual(try decoded.root.validatedToken().shadowGeneration, 10)
    XCTAssertNotEqual(source.baseHotState, source.shadowHotState)
    XCTAssertEqual(source.basePersistentMemory, Data(repeating: 0, count: 64))
  }
  func testEveryImageSectionChangesCryptographicIdentity() throws {
    let a = try image(), b = try image(shadow: Data(repeating: 3, count: 64))
    XCTAssertNotEqual(a.sha256, b.sha256)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(a)) as? [String: Any])
    object["baseHotState"] = Data(repeating: 5, count: 64).base64EncodedString()
    let changed = try JSONDecoder().decode(BrainPreparedGPUImage.self,
      from: JSONSerialization.data(withJSONObject: object))
    XCTAssertThrowsError(try changed.validated())
  }
  func testUnappliedJournalRemainsSeparateFromBaseMemory() throws {
    let source = try image()
    XCTAssertEqual(source.basePersistentMemory.prefix(4), Data(repeating: 0, count: 4))
    let payload = source.shadowJournal.withUnsafeBytes {
      UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: 96, as: UInt32.self))
    }
    XCTAssertEqual(payload, 0x3f800000)
  }
  func testOverlappingJournalWritesAreRejected() throws {
    XCTAssertThrowsError(try image(journal: journal(destinations: [0, 0])))
    XCTAssertNoThrow(try image(journal: journal(destinations: [0, 4])))
  }
  func testOutOfBoundsAndStaleJournalAreRejected() throws {
    XCTAssertThrowsError(try image(journal: journal(destinations: [64])))
    var bytes = journal(); bytes[24] = 9
    XCTAssertThrowsError(try image(journal: bytes))
  }
  func testCorruptJournalHeaderAndSizeBudgetAreRejected() throws {
    var bytes = journal(); bytes[12] = 5
    XCTAssertThrowsError(try image(journal: bytes))
    XCTAssertThrowsError(try image().validated(maximumBytes: 16))
  }
  func testPersistIsIdempotentAndUndecidedIsNotAnAbort() async throws {
    let path = try directory(); defer { try? FileManager.default.removeItem(at: path) }
    let store = try BrainPreparedGPUStore(directoryURL: path), source = try image()
    let first = try await store.persist(source), second = try await store.persist(source)
    XCTAssertEqual(first, second)
    let recovered = try await store.recover(rootFingerprint: source.root.fingerprint)
    XCTAssertEqual(recovered.image, source); XCTAssertNil(recovered.decision)
  }
  func testConflictingCandidateForSameRootCannotOverwritePrepare() async throws {
    let path = try directory(); defer { try? FileManager.default.removeItem(at: path) }
    let store = try BrainPreparedGPUStore(directoryURL: path)
    _ = try await store.persist(image())
    do {
      _ = try await store.persist(image(shadow: Data(repeating: 3, count: 64)))
      XCTFail("conflicting candidate must fail")
    } catch {}
  }
  func testCommitDecisionIsIdempotentAndIrreversible() async throws {
    let path = try directory(); defer { try? FileManager.default.removeItem(at: path) }
    let store = try BrainPreparedGPUStore(directoryURL: path), source = try image()
    _ = try await store.persist(source)
    let a = try await store.decide(rootFingerprint: source.root.fingerprint,
      imageSHA256: source.sha256, resolution: .commit)
    let b = try await store.decide(rootFingerprint: source.root.fingerprint,
      imageSHA256: source.sha256, resolution: .commit)
    XCTAssertEqual(a, b)
    do {
      _ = try await store.decide(rootFingerprint: source.root.fingerprint,
        imageSHA256: source.sha256, resolution: .abort)
      XCTFail("commit cannot become abort")
    } catch {}
    let found = try await store.recover(rootFingerprint: source.root.fingerprint)
    XCTAssertEqual(found.decision?.resolution, .commit)
  }
  func testSecondWriterAndSymlinkStoreAreRejected() throws {
    let path = try directory(); defer { try? FileManager.default.removeItem(at: path) }
    let store = try BrainPreparedGPUStore(directoryURL: path)
    withExtendedLifetime(store) {
      XCTAssertThrowsError(try BrainPreparedGPUStore(directoryURL: path))
    }
    let alias = path.appendingPathComponent("alias")
    try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: path)
    XCTAssertThrowsError(try BrainPreparedGPUStore(directoryURL: alias))
  }
  func testTruncatedImageCannotBeRecovered() async throws {
    let path = try directory(); defer { try? FileManager.default.removeItem(at: path) }
    let store = try BrainPreparedGPUStore(directoryURL: path), source = try image()
    _ = try await store.persist(source)
    let file = path.appendingPathComponent(source.sha256 + ".image")
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    let handle = try FileHandle(forWritingTo: file)
    try handle.truncate(atOffset: 32); try handle.close()
    do { _ = try await store.recover(rootFingerprint: source.root.fingerprint); XCTFail("truncated image") }
    catch {}
  }
}

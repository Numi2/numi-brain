import Foundation
import CryptoKit
import XCTest
import NumiBrainCore
@testable import NumiBrainMetal

/// Artifact/ABI tests only. These synthetic byte arrays are not an executed neural simulation.
@MainActor
final class MetalPreparedFastRootImageTests: XCTestCase {
  private struct Fixture {
    let root: BrainJointTransactionToken
    let substep: BrainJointSubstepToken
    let accepted: AcceptedPhysicsStateToken
    let receipt: BrainJointCommitToken
    let base: MetalTissueCheckpoint
    let sources: [MetalPreparedFastSourceImage]
  }

  private func fixture() throws -> Fixture {
    let random = TissueRandomContext.deterministicDefault
    let root = try BrainJointTransactionToken(environmentIdentifier: random.environmentIdentifier,
      episodeIdentifier: UInt64(random.episodeIdentifier), controlStepIdentifier: 1,
      parameterVersionFingerprint: 10, baseBrainGeneration: 0, basePhysicsGeneration: 5,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 20_000), randomCounterGeneration: 0)
    var transaction = BrainJointTransaction(token: root)
    let substep = try transaction.beginPhysicsSubstep(durationMicroseconds: 20_000)
    let accepted = try AcceptedPhysicsStateToken(transaction: root, substep: substep,
      physicsStateFingerprint: 777, physicsGeneration: 6)
    try transaction.acceptPhysicsSubstep(accepted, for: substep)
    let receipt = try transaction.commit()
    let capacity = TissueDelayField.historyCapacity
    let emptyKinds: Set<MetalTissueCheckpointBufferKind> = [
      .routeHistoryStates, .routeHistoryTimestamps, .routeHistoryValues, .routeRuntimeStates
    ]
    let buffers = MetalTissueCheckpointBufferKind.allCases.map { kind in
      let count = kind == .relayHistoryTimestamps ? 2 * capacity * 8 : (emptyKinds.contains(kind) ? 0 : 16)
      return MetalTissueCheckpointBuffer(kind: kind, data: Data(repeating: 0, count: count))
    }
    let base = try MetalTissueCheckpoint(width: 1, height: 1,
      environmentIdentifier: random.environmentIdentifier, randomContext: random,
      committedStep: 0, committedSchedulerTime: nil, committedSchedulerGeneration: 0,
      committedHistoryOwnerMask: 0, committedRelayHistoryTimestamps: Array(repeating: 0, count: capacity),
      parameterVersionFingerprint: 10, scheduleFingerprint: 11, regionalProgramFingerprint: 12,
      sharedArtifactFingerprint: 13, protectiveMotorProfileFingerprint: 14,
      attachmentCatalogFingerprint: 0, somaticSynergyCatalogFingerprint: 15,
      structureHash: "fixture-structure", delayFieldHash: "fixture-delay",
      connectomeHash: "fixture-connectome", eventScheduleHash: "fixture-events",
      bodyLoadFieldDynamics: BodyLoadFieldDynamics.runtimeFoundationV0,
      bodySchemaDynamics: BodySchemaPosteriorDynamics.runtimeFoundationV0, buffers: buffers)
    var sources = buffers.filter { !$0.data.isEmpty }.map { record -> MetalPreparedFastSourceImage in
      var bytes = record.data
      if record.kind == .tissueState { bytes[0] = 1 }
      if record.kind == .relayHistoryTimestamps {
        put(UInt64(20_000), into: &bytes, at: (capacity + 1) * 8)
      }
      return .init(semanticIdentifier: PreparedFastSemantic.checkpoint(record.kind), bytes: bytes)
    }
    var words = [UInt64](repeating: 0, count: 64)
    words[0] = 0x4e55_4d49_4641_5354; words[1] = 1; words[2] = 512
    words[3] = UInt64(root.environmentIdentifier); words[4] = root.controlStepIdentifier
    words[5] = root.fingerprint; words[6] = substep.fingerprint
    words[7] = root.targetTimestamp.rawValue; words[8] = 6; words[9] = 1
    words[10] = 1; words[11] = 2; words[12] = 1; words[13] = 1; words[14] = 1
    words[15] = 20_000; words[16] = 1; words[17] = UInt64(sources.count)
    words[18] = 1; words[19] = 1; words[20] = UInt64(capacity)
    words[21] = 10; words[22] = 11; words[23] = 12; words[24] = 13
    words[25] = 14; words[26] = 0; words[27] = 15
    words[28] = fnv(Data(base.structureHash.utf8)); words[29] = fnv(Data(base.delayFieldHash.utf8))
    words[30] = fnv(Data(base.connectomeHash.utf8)); words[31] = fnv(Data(base.eventScheduleHash.utf8))
    words[32] = pack(random.seed, random.environmentIdentifier)
    words[33] = pack(random.episodeIdentifier, random.moduleIdentifier)
    words[34] = 81; words[35] = 82
    let load = base.bodyLoadFieldDynamics, schema = base.bodySchemaDynamics
    words[36] = pack(load.persistenceMicroseconds, load.decayMicroseconds)
    words[37] = pack(schema.forceScaleNewtons.bitPattern, schema.loadTimeConstantMicroseconds)
    words[38] = pack(schema.initialVariance.bitPattern, schema.maximumVariance.bitPattern)
    words[39] = pack(schema.processVariancePerSecond.bitPattern, schema.observationVariance.bitPattern)
    words[40] = pack(schema.vulnerabilityGainPerSecond.bitPattern, schema.recoveryPerSecond.bitPattern)
    words[41] = UInt64(schema.uncertaintyRiskWeight.bitPattern)
    words[44] = root.randomCounterGeneration; words[45] = root.baseBrainGeneration
    words[46] = root.basePhysicsGeneration; words[47] = root.episodeIdentifier
    sources.append(.init(semanticIdentifier: PreparedFastSemantic.rootManifest, bytes: manifestBytes(words)))
    return Fixture(root: root, substep: substep, accepted: accepted, receipt: receipt, base: base, sources: sources)
  }

  private func image(_ fixture: Fixture, sources: [MetalPreparedFastSourceImage]? = nil) throws -> MetalPreparedFastRootImage {
    try .init(root: BrainPreparedRoot(fixture.root), fastProgramFingerprint: 71,
      base: fixture.base, sources: sources ?? fixture.sources)
  }
  private func modifyingManifest(_ sources: [MetalPreparedFastSourceImage],
    _ edit: (inout [UInt64]) -> Void) throws -> [MetalPreparedFastSourceImage] {
    var result = sources
    let index = try XCTUnwrap(result.firstIndex { $0.semanticIdentifier == PreparedFastSemantic.rootManifest })
    var words = try (0..<64).map { try MetalPreparedFastRootImage.word(result[index].bytes, index: $0) }
    edit(&words)
    result[index] = .init(semanticIdentifier: PreparedFastSemantic.rootManifest, bytes: manifestBytes(words))
    return result
  }

  func testNativeManifestRoundTripAndSelectedHistoryPlane() throws {
    let source = try image(fixture())
    XCTAssertEqual(try MetalPreparedFastRootImage.decode(source.encoded()), source)
    let candidate = try source.stagedCheckpoint()
    XCTAssertEqual(candidate.committedSchedulerGeneration, 1)
    XCTAssertEqual(candidate.committedStep, 1)
    XCTAssertEqual(candidate.committedHistoryOwnerMask, 2)
    XCTAssertEqual(candidate.committedRelayHistoryTimestamps[1], 20_000)
    XCTAssertEqual(candidate.committedSchedulerTime?.rawValue, 20_000)
    XCTAssertEqual(source.base.committedSchedulerGeneration, 0)
    XCTAssertEqual(source.base.committedRelayHistoryTimestamps[1], 0)
  }

  func testArtifactIdentityHashesTheActualEncodedPayload() throws {
    let source = try image(fixture()), bytes = try source.encoded()
    let artifact = try source.participantArtifact()
    XCTAssertEqual(artifact.kind, .fastTissue)
    XCTAssertEqual(artifact.payloadBytes, UInt64(bytes.count))
    XCTAssertEqual(artifact.payloadSHA256, SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined())
    XCTAssertNotEqual(artifact.payloadSHA256, source.contentSHA256)
  }

  func testSavedBufferIndicesDoNotChooseRestoredAllocations() throws {
    let value = try fixture()
    let changed = try modifyingManifest(value.sources) { words in
      words[10] = 2; words[13] = 0; words[14] = 0
    }
    XCTAssertEqual(try image(value).stagedCheckpoint(), try image(value, sources: changed).stagedCheckpoint())
  }

  func testMissingNonemptyRangeCannotBecomeACompleteCheckpoint() throws {
    let value = try fixture()
    let missing = value.sources.filter { $0.semanticIdentifier != PreparedFastSemantic.checkpoint(.tissueState) }
    let correctedCount = try modifyingManifest(missing) { $0[17] -= 1 }
    XCTAssertThrowsError(try image(value, sources: correctedCount))
  }

  func testDuplicateSemanticIdentifierIsRejectedBeforeDictionaryConstruction() throws {
    let value = try fixture()
    let first = try XCTUnwrap(value.sources.first)
    XCTAssertThrowsError(try image(value, sources: value.sources + [first]))
  }

  func testWrongRootOrImmutableMetadataIsRejectedEvenWithRecomputedNativeChecksum() throws {
    let value = try fixture()
    for index in [5, 8, 9, 15, 21, 22, 28, 36, 44, 46, 47] {
      let changed = try modifyingManifest(value.sources) { $0[index] ^= 1 }
      XCTAssertThrowsError(try image(value, sources: changed), "metadata word \(index)")
    }
  }

  func testWrongHistoryOwnerCannotSelectAnUnwrittenPlane() throws {
    let value = try fixture()
    let changed = try modifyingManifest(value.sources) { $0[11] = 0 }
    XCTAssertThrowsError(try image(value, sources: changed))
  }

  func testFutureSelectedHistoryIsRejected() throws {
    let value = try fixture()
    var sources = value.sources
    let index = try XCTUnwrap(sources.firstIndex {
      $0.semanticIdentifier == PreparedFastSemantic.checkpoint(.relayHistoryTimestamps)
    })
    var bytes = sources[index].bytes
    put(UInt64(20_001), into: &bytes, at: 2 * 8)
    sources[index] = .init(semanticIdentifier: sources[index].semanticIdentifier, bytes: bytes)
    XCTAssertThrowsError(try image(value, sources: sources))
  }

  func testNativeManifestChecksumAndRecoveryDigestAreBothChecked() throws {
    let value = try fixture()
    var sources = value.sources
    let index = try XCTUnwrap(sources.firstIndex { $0.semanticIdentifier == PreparedFastSemantic.rootManifest })
    var broken = sources[index].bytes; broken[0] ^= 1
    sources[index] = .init(semanticIdentifier: PreparedFastSemantic.rootManifest, bytes: broken)
    XCTAssertThrowsError(try image(value, sources: sources))
    let original = try image(value)
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: original.encoded()) as? [String: Any])
    json["fastProgramFingerprint"] = NSNumber(value: 72)
    XCTAssertThrowsError(try MetalPreparedFastRootImage.decode(JSONSerialization.data(withJSONObject: json)))
  }

  func testRecoveryByteBudgetRejectsAnOtherwiseValidImage() throws {
    let source = try image(fixture())
    XCTAssertThrowsError(try source.validated(maximumPayloadBytes: 16))
  }

  func testPairedRecoveryRequiresDurableCommitAndMaterializesOnlySavedWrites() async throws {
    let value = try fixture(), fast = try image(value)
    let baseHot = Data(repeating: 0, count: 64), shadowHot = Data(repeating: 1, count: 64)
    let memory = Data(repeating: 0, count: 64)
    var journal = Data(repeating: 0, count: 48 + 64)
    put(UInt32(1), into: &journal, at: 0); put(UInt32(1), into: &journal, at: 4)
    put(UInt32(1), into: &journal, at: 8); put(UInt32(1), into: &journal, at: 12)
    put(UInt64(1), into: &journal, at: 24); put(UInt64(64), into: &journal, at: 32)
    put(UInt64(1), into: &journal, at: 48 + 8)
    put(UInt32(0x3f800000), into: &journal, at: 48 + 16)
    put(UInt32(4), into: &journal, at: 48 + 32); put(UInt32(1), into: &journal, at: 48 + 36)
    let gpu = try BrainPreparedGPUImage(root: BrainPreparedRoot(value.root), cachedDecisionFingerprint: 90,
      acceptedPhysicsTokenFingerprint: value.accepted.fingerprint, hotLayoutFingerprint: 91,
      memoryLayoutFingerprint: 92, baseHotState: baseHot, shadowHotState: shadowHot,
      basePersistentMemory: memory, shadowJournal: journal)
    let base = try MetalBrainCheckpoint(committedGeneration: 0,
      committedTimestamp: BrainTimestamp(microseconds: 0), environmentIdentifier: value.root.environmentIdentifier,
      episodeIdentifier: value.root.episodeIdentifier, controlStepIdentifier: 0,
      speciesTemplateFingerprint: 81, compiledSpeciesTemplateFingerprint: 82,
      regionalProgramFingerprint: 12, scheduleFingerprint: 11, parameterVersionFingerprint: 10,
      hotLayoutFingerprint: 91, memoryLayoutFingerprint: 92, physicalCheckpointFingerprint: 600,
      hotState: baseHot, persistentMemory: memory)
    let receipts = try BrainPreparedNativeReceipts(root: value.root, substep: value.substep,
      acceptedPhysics: value.accepted, jointCommit: value.receipt, physicalCheckpointFingerprint: 601)
    let cognitive = try MetalPreparedCognitiveRootImage(brainProgramFingerprint: 93,
      base: base, gpu: gpu, nativeReceipts: receipts)
    let physicalBytes = Data("opaque-physical-unit-fixture-not-native-solver-state".utf8)
    let archiveBytes = Data("opaque-archive-unit-fixture".utf8)
    let physical = try BrainPreparedParticipantArtifact(kind: .physicalSolver,
      transactionFingerprint: value.root.fingerprint, baseGeneration: 5, shadowGeneration: 6,
      immutableProgramFingerprint: 94, payloadSHA256: MetalPreparedFastRootImage.sha256(physicalBytes),
      payloadBytes: UInt64(physicalBytes.count))
    let archive = try BrainPreparedParticipantArtifact(kind: .externalArchive,
      transactionFingerprint: value.root.fingerprint, baseGeneration: 0, shadowGeneration: 1,
      immutableProgramFingerprint: 95, payloadSHA256: MetalPreparedFastRootImage.sha256(archiveBytes),
      payloadBytes: UInt64(archiveBytes.count))
    let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("prepared-fast-pair-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try BrainJointPreparedManifestStore(directoryURL: directory)
    _ = try await MetalPreparedBrainRootPersistence.prepare(cognitive: cognitive, fast: fast,
      physicalArtifact: physical, physicalBytes: physicalBytes,
      archiveArtifact: archive, archiveBytes: archiveBytes, store: store)
    do {
      _ = try await MetalPreparedBrainRootPersistence.recoverCommitted(rootFingerprint: value.root.fingerprint, store: store)
      XCTFail("a prepared file is not a commit decision")
    } catch {}
    _ = try await store.decide(rootFingerprint: value.root.fingerprint, decision: .commit)
    try await store.close()
    let reopened = try BrainJointPreparedManifestStore(directoryURL: directory)
    let recovered = try await MetalPreparedBrainRootPersistence.recoverCommitted(
      rootFingerprint: value.root.fingerprint, store: reopened)
    XCTAssertEqual(recovered.checkpoint.committedGeneration, 1)
    XCTAssertEqual(recovered.checkpoint.physicalCheckpointFingerprint, 601)
    XCTAssertEqual(recovered.checkpoint.cognitiveState.hotState, shadowHot)
    XCTAssertEqual(recovered.checkpoint.cognitiveState.persistentMemory.prefix(4), Data([0, 0, 0x80, 0x3f]))
    XCTAssertEqual(gpu.basePersistentMemory, memory)
    XCTAssertEqual(recovered.checkpoint.fastTissueState, try fast.stagedCheckpoint())
    XCTAssertEqual(try recovered.nativeReceipts.acceptedPhysicsToken(), value.accepted)
    try await reopened.close()
  }

  private func put<T: FixedWidthInteger>(_ value: T, into bytes: inout Data, at offset: Int) {
    var little = value.littleEndian
    withUnsafeBytes(of: &little) { bytes.replaceSubrange(offset..<(offset + $0.count), with: $0) }
  }
  private func manifestBytes(_ source: [UInt64]) -> Data {
    var bytes = Data(repeating: 0, count: 512)
    for index in 0..<63 { put(source[index], into: &bytes, at: index * 8) }
    put(fnv(Data(bytes.prefix(504))), into: &bytes, at: 504)
    return bytes
  }
  private func fnv(_ bytes: Data) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in bytes { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
    return hash == 0 ? 14_695_981_039_346_656_037 : hash
  }
  private func pack(_ low: UInt32, _ high: UInt32) -> UInt64 { UInt64(low) | UInt64(high) << 32 }
}

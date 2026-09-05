import Foundation
import NumiBrainCore

/// The cognitive participant includes its exact base checkpoint identity and the original native
/// physical/commit records, not just a hot-buffer digest. The fast participant remains a separate
/// payload so the whole-root manifest can require both producers.
public struct MetalPreparedCognitiveRootImage: Codable, Equatable, Sendable {
  public let version: UInt32
  public let brainProgramFingerprint: UInt64
  public let base: MetalBrainCheckpoint
  public let gpu: BrainPreparedGPUImage
  public let nativeReceipts: BrainPreparedNativeReceipts

  public init(brainProgramFingerprint: UInt64, base: MetalBrainCheckpoint,
    gpu: BrainPreparedGPUImage, nativeReceipts: BrainPreparedNativeReceipts) throws {
    version = 1; self.brainProgramFingerprint = brainProgramFingerprint
    self.base = base; self.gpu = gpu; self.nativeReceipts = nativeReceipts
    _ = try validated()
  }

  @discardableResult
  public func validated() throws -> Self {
    _ = try gpu.validated(); try base.validate(); _ = try nativeReceipts.validated()
    let root = try gpu.root.validatedToken()
    let accepted = try nativeReceipts.acceptedPhysicsToken()
    guard version == 1, brainProgramFingerprint > 0,
      nativeReceipts.root == gpu.root,
      accepted.fingerprint == gpu.acceptedPhysicsTokenFingerprint,
      base.committedGeneration == root.baseBrainGeneration,
      base.committedTimestamp == root.committedTimestamp,
      base.environmentIdentifier == root.environmentIdentifier,
      base.episodeIdentifier == root.episodeIdentifier,
      base.parameterVersionFingerprint == root.parameterVersionFingerprint,
      base.hotLayoutFingerprint == gpu.hotLayoutFingerprint,
      base.memoryLayoutFingerprint == gpu.memoryLayoutFingerprint,
      base.hotState == gpu.baseHotState, base.persistentMemory == gpu.basePersistentMemory,
      base.speciesTemplateFingerprint > 0, base.compiledSpeciesTemplateFingerprint > 0,
      base.physicalCheckpointFingerprint > 0 else {
      throw TissueError.transaction("prepared cognitive payload is not the same native base/root/physical acceptance")
    }
    return self
  }

  public func encoded() throws -> Data {
    _ = try validated()
    let data = try MetalPreparedFastRootImage.encode(self)
    guard data.count <= 1_073_741_824 else { throw TissueError.transaction("encoded cognitive payload exceeds 1 GiB") }
    return data
  }
  public static func decode(_ data: Data) throws -> Self {
    guard !data.isEmpty, data.count <= 1_073_741_824 else { throw TissueError.transaction("cognitive payload size") }
    return try JSONDecoder().decode(Self.self, from: data).validated()
  }
  public func participantArtifact() throws -> BrainPreparedParticipantArtifact {
    let bytes = try encoded(), root = try gpu.root.validatedToken()
    return try BrainPreparedParticipantArtifact(kind: .cognitiveArena,
      transactionFingerprint: root.fingerprint, baseGeneration: root.baseBrainGeneration,
      shadowGeneration: root.shadowGeneration, immutableProgramFingerprint: brainProgramFingerprint,
      payloadSHA256: MetalPreparedFastRootImage.sha256(bytes), payloadBytes: UInt64(bytes.count))
  }

  func materializedCheckpoint(after decision: BrainJointPreparedDecisionRecord,
    manifest: BrainJointPreparedManifest) throws -> MetalBrainCheckpoint {
    _ = try validated(); _ = try manifest.validated()
    guard manifest.root == gpu.root, decision.decision == .commit,
      decision == (try BrainJointPreparedDecisionRecord(manifest: manifest, decision: .commit)),
      manifest.participants.first(where: { $0.kind == .cognitiveArena }) == (try participantArtifact()) else {
      throw TissueError.transaction("cognitive materialization requires the matching whole-root commit decision")
    }
    let root = try gpu.root.validatedToken()
    // Only now apply the saved native fixed-byte writes to an isolated host image. This performs
    // no neural/physics computation, does not consume RNG, and leaves the saved base unchanged.
    let memory = try gpu.materializedCommittedMemory()
    return try MetalBrainCheckpoint(committedGeneration: root.shadowGeneration,
      committedTimestamp: root.targetTimestamp, environmentIdentifier: root.environmentIdentifier,
      episodeIdentifier: root.episodeIdentifier, controlStepIdentifier: root.controlStepIdentifier,
      speciesTemplateFingerprint: base.speciesTemplateFingerprint,
      compiledSpeciesTemplateFingerprint: base.compiledSpeciesTemplateFingerprint,
      regionalProgramFingerprint: base.regionalProgramFingerprint,
      scheduleFingerprint: base.scheduleFingerprint, parameterVersionFingerprint: root.parameterVersionFingerprint,
      hotLayoutFingerprint: base.hotLayoutFingerprint, memoryLayoutFingerprint: base.memoryLayoutFingerprint,
      physicalCheckpointFingerprint: nativeReceipts.physicalCheckpointFingerprint,
      hotState: gpu.shadowHotState, persistentMemory: memory)
  }
}

public enum MetalPreparedBrainRootPersistence {
  /// Captured native producers remain unpublished until the joint manager has recorded a decision.
  /// The physical/archive payloads are supplied by their real owners; this method hashes their
  /// actual bytes but does not fabricate or semantically validate a foreign solver/archive format.
  @discardableResult
  public static func prepare(cognitive: MetalPreparedCognitiveRootImage,
    fast: MetalPreparedFastRootImage,
    physicalArtifact: BrainPreparedParticipantArtifact, physicalBytes: Data,
    archiveArtifact: BrainPreparedParticipantArtifact, archiveBytes: Data,
    store: BrainJointPreparedManifestStore) async throws -> BrainJointPreparedManifest {
    try validatePair(cognitive: cognitive, fast: fast)
    let cognitiveBytes = try cognitive.encoded(), fastBytes = try fast.encoded()
    let cognitiveArtifact = try cognitive.participantArtifact(), fastArtifact = try fast.participantArtifact()
    let root = try cognitive.gpu.root.validatedToken()
    guard physicalArtifact.kind == .physicalSolver, archiveArtifact.kind == .externalArchive,
      archiveArtifact.baseGeneration == root.baseBrainGeneration,
      archiveArtifact.shadowGeneration == root.shadowGeneration else {
      throw TissueError.transaction("native recovery requires physical and archive artifacts for this generation")
    }
    let manifest = try BrainJointPreparedManifest(root: cognitive.gpu.root,
      parameterVersionFingerprint: root.parameterVersionFingerprint,
      participants: [cognitiveArtifact, fastArtifact, physicalArtifact, archiveArtifact])
    // Validate every supplied byte identity before publishing even the first artifact.
    let payloads = [(cognitiveArtifact, cognitiveBytes), (fastArtifact, fastBytes),
      (physicalArtifact, physicalBytes), (archiveArtifact, archiveBytes)]
    for (artifact, bytes) in payloads {
      guard artifact.payloadBytes == UInt64(bytes.count),
        artifact.payloadSHA256 == MetalPreparedFastRootImage.sha256(bytes) else {
        throw TissueError.transaction("native prepared participant bytes do not match declared identity")
      }
    }
    for (artifact, bytes) in payloads { _ = try await store.storeParticipant(artifact, bytes: bytes) }
    return try await store.prepare(manifest)
  }

  /// Loads only a decided COMMIT, after the store has streamed every participant's bytes. It
  /// reconstructs a native complete-brain checkpoint without publishing any runtime or actuator.
  public static func recoverCommitted(rootFingerprint: UInt64,
    store: BrainJointPreparedManifestStore) async throws -> MetalPreparedBrainRecoveryMaterial {
    let record = try await store.recover(rootFingerprint: rootFingerprint)
    guard let decision = record.decision, decision.decision == .commit else {
      throw TissueError.transaction("joint root is undecided or aborted; no candidate may be published")
    }
    let cognitiveBytes = try await store.participantBytes(rootFingerprint: rootFingerprint, kind: .cognitiveArena)
    let fastBytes = try await store.participantBytes(rootFingerprint: rootFingerprint, kind: .fastTissue)
    let cognitive = try MetalPreparedCognitiveRootImage.decode(cognitiveBytes)
    let fast = try MetalPreparedFastRootImage.decode(fastBytes)
    try validatePair(cognitive: cognitive, fast: fast)
    guard record.manifest.root == cognitive.gpu.root,
      record.manifest.participants.first(where: { $0.kind == .cognitiveArena }) == (try cognitive.participantArtifact()),
      record.manifest.participants.first(where: { $0.kind == .fastTissue }) == (try fast.participantArtifact()),
      let physical = record.manifest.participants.first(where: { $0.kind == .physicalSolver }),
      let archive = record.manifest.participants.first(where: { $0.kind == .externalArchive }) else {
      throw TissueError.transaction("stored native payloads do not belong to the decided joint manifest")
    }
    let checkpoint = try MetalNumiBrainCheckpoint(
      cognitiveState: cognitive.materializedCheckpoint(after: decision, manifest: record.manifest),
      fastTissueState: fast.stagedCheckpoint())
    return MetalPreparedBrainRecoveryMaterial(manifest: record.manifest, decision: decision,
      checkpoint: checkpoint, nativeReceipts: cognitive.nativeReceipts,
      physicalArtifact: physical, archiveArtifact: archive)
  }

  private static func validatePair(cognitive: MetalPreparedCognitiveRootImage,
    fast: MetalPreparedFastRootImage) throws {
    _ = try cognitive.validated(); _ = try fast.validated()
    let accepted = try cognitive.nativeReceipts.acceptedPhysicsToken()
    guard cognitive.gpu.root == fast.root,
      try fast.nativeSpeciesFingerprint == cognitive.base.speciesTemplateFingerprint,
      try fast.nativeCompiledSpeciesFingerprint == cognitive.base.compiledSpeciesTemplateFingerprint,
      try fast.nativeSubstepFingerprint == accepted.substepFingerprint else {
      throw TissueError.transaction("cognitive and fast candidates have different native origins")
    }
    // Existing native checkpoint validation checks time, generation, schedule, episode and program.
    _ = try MetalNumiBrainCheckpoint(cognitiveState: cognitive.base, fastTissueState: fast.base)
  }
}

/// The checkpoint is recovery material, not an assertion that the physical/archive owners have
/// resumed. The caller must keep the global suite publication fence closed throughout peer restore.
public struct MetalPreparedBrainRecoveryMaterial: Sendable {
  public let manifest: BrainJointPreparedManifest
  public let decision: BrainJointPreparedDecisionRecord
  public let checkpoint: MetalNumiBrainCheckpoint
  public let nativeReceipts: BrainPreparedNativeReceipts
  public let physicalArtifact: BrainPreparedParticipantArtifact
  public let archiveArtifact: BrainPreparedParticipantArtifact

  /// Uses the actual native owner and its isolated replacement mechanism. The factory must return
  /// a NEW unpublished handle made by the already-admitted species/parameter/policy factory, not
  /// a handle currently serving an agent. No policy verification is bypassed or reproduced here.
  /// Physical acceptance must come from the restored physical owner's actual state, not a replayed
  /// transport acknowledgement. Archive installation remains the native archive owner's operation.
  @available(macOS 26.0, *)
  public func restoreIsolatedBrain(
    restoredPhysicalAcceptance: AcceptedPhysicsStateToken,
    restoredPhysicalCheckpointFingerprint: UInt64,
    makeUnpublishedHandle: () throws -> MetalNumiBrainHandle
  ) throws -> MetalNumiBrainHandle {
    _ = try manifest.validated(); _ = try nativeReceipts.validated(); try checkpoint.validate()
    guard decision == (try BrainJointPreparedDecisionRecord(manifest: manifest, decision: .commit)),
      restoredPhysicalAcceptance == (try nativeReceipts.acceptedPhysicsToken()),
      restoredPhysicalCheckpointFingerprint == nativeReceipts.physicalCheckpointFingerprint,
      checkpoint.physicalCheckpointFingerprint == restoredPhysicalCheckpointFingerprint else {
      throw TissueError.transaction("restored physics does not match the saved native accepted state")
    }
    let handle = try makeUnpublishedHandle()
    guard !handle.hasOpenControl, handle.parameterVersionFingerprint == checkpoint.cognitiveState.parameterVersionFingerprint,
      handle.compiledSpeciesTemplateFingerprint == checkpoint.cognitiveState.compiledSpeciesTemplateFingerprint,
      handle.scheduleFingerprint == checkpoint.cognitiveState.scheduleFingerprint,
      handle.regionalProgramFingerprint == checkpoint.cognitiveState.regionalProgramFingerprint else {
      throw TissueError.transaction("unpublished recovery owner has different native configuration")
    }
    try handle.loadCheckpoint(checkpoint, physicalCheckpointFingerprint: restoredPhysicalCheckpointFingerprint)
    let roundTrip = try handle.saveCheckpoint(controlStepIdentifier: checkpoint.controlStepIdentifier,
      physicalCheckpointFingerprint: restoredPhysicalCheckpointFingerprint)
    guard roundTrip == checkpoint else {
      throw TissueError.transaction("native fast/cognitive GPU restore was not byte-exact")
    }
    return handle
  }
}

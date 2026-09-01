import Foundation

/// Retained proof that two independently executed support-stability
/// evaluations replayed the same semantic physics and policy evidence. Exact
/// owner applied/joint fingerprints are intentionally transaction-unique; the
/// replay relation requires those authority identities to differ while every
/// content-bearing sensor, outcome, generation, and physical metric matches.
@frozen
public struct BrainPolicyNumanXSupportStabilityReplayArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let referenceEvaluationArtifactSHA256: String
  public let replayEvaluationArtifactSHA256: String
  public let candidateArtifactSHA256: String
  public let contactVariantArtifactSHA256: String
  public let baselineRootCount: UInt64
  public let learnedRootCount: UInt64
  public let transactionUniqueIdentityDifferenceCount: UInt64
  public let exactSemanticReplay: Bool
  public let promotable: Bool

  public init(
    referenceEvaluationArtifactSHA256: String,
    replayEvaluationArtifactSHA256: String,
    candidateArtifactSHA256: String,
    contactVariantArtifactSHA256: String,
    baselineRootCount: UInt64,
    learnedRootCount: UInt64,
    transactionUniqueIdentityDifferenceCount: UInt64
  ) throws {
    guard BrainPolicyEvidenceArtifact.isSHA256(
      referenceEvaluationArtifactSHA256
    ), BrainPolicyEvidenceArtifact.isSHA256(replayEvaluationArtifactSHA256),
      referenceEvaluationArtifactSHA256 != replayEvaluationArtifactSHA256,
      BrainPolicyEvidenceArtifact.isSHA256(candidateArtifactSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(contactVariantArtifactSHA256),
      baselineRootCount > 0, learnedRootCount > 0,
      transactionUniqueIdentityDifferenceCount > 0,
      transactionUniqueIdentityDifferenceCount
        <= baselineRootCount + learnedRootCount
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-stability replay artifact is invalid"
      )
    }
    self.formatVersion = Self.formatVersion
    self.referenceEvaluationArtifactSHA256 =
      referenceEvaluationArtifactSHA256
    self.replayEvaluationArtifactSHA256 = replayEvaluationArtifactSHA256
    self.candidateArtifactSHA256 = candidateArtifactSHA256
    self.contactVariantArtifactSHA256 = contactVariantArtifactSHA256
    self.baselineRootCount = baselineRootCount
    self.learnedRootCount = learnedRootCount
    self.transactionUniqueIdentityDifferenceCount =
      transactionUniqueIdentityDifferenceCount
    self.exactSemanticReplay = true
    self.promotable = false
  }

  public func encoded() throws -> Data {
    try validate()
    return try BrainPolicyEvidenceArtifact.encodeCanonical(self)
  }

  @discardableResult
  public func write(to artifactDirectory: URL) throws -> String {
    try BrainPolicyEvidenceArtifact.write(encoded(), to: artifactDirectory)
  }

  public static func decode(_ data: Data) throws -> Self {
    let artifact = try JSONDecoder().decode(Self.self, from: data)
    try artifact.validate()
    return artifact
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion, exactSemanticReplay,
      !promotable,
      try Self(
        referenceEvaluationArtifactSHA256:
          referenceEvaluationArtifactSHA256,
        replayEvaluationArtifactSHA256: replayEvaluationArtifactSHA256,
        candidateArtifactSHA256: candidateArtifactSHA256,
        contactVariantArtifactSHA256: contactVariantArtifactSHA256,
        baselineRootCount: baselineRootCount,
        learnedRootCount: learnedRootCount,
        transactionUniqueIdentityDifferenceCount:
          transactionUniqueIdentityDifferenceCount
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-stability replay artifact is not canonical"
      )
    }
  }
}

public struct BrainPolicyNumanXSupportStabilityReplayReceipt: Sendable {
  public let replayArtifactSHA256: String
  public let referenceEvaluationArtifactSHA256: String
  public let replayEvaluationArtifactSHA256: String
  public let baselineRootCount: UInt64
  public let learnedRootCount: UInt64
  public let transactionUniqueIdentityDifferenceCount: UInt64
  public let transitiveEvidenceSHA256: String
}

public enum BrainPolicyNumanXSupportStabilityReplayVerifier {
  public static func compareAndWrite(
    referenceEvaluationArtifactSHA256: String,
    replayEvaluationArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXSupportStabilityReplayReceipt {
    try compare(
      referenceEvaluationArtifactSHA256:
        referenceEvaluationArtifactSHA256,
      replayEvaluationArtifactSHA256: replayEvaluationArtifactSHA256,
      artifactDirectory: artifactDirectory,
      writeArtifact: true
    )
  }

  public static func verify(
    replayArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXSupportStabilityReplayReceipt {
    let stored = try BrainPolicyNumanXSupportStabilityReplayArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: replayArtifactSHA256,
        directory: artifactDirectory
      )
    )
    let receipt = try compare(
      referenceEvaluationArtifactSHA256:
        stored.referenceEvaluationArtifactSHA256,
      replayEvaluationArtifactSHA256:
        stored.replayEvaluationArtifactSHA256,
      artifactDirectory: artifactDirectory,
      writeArtifact: false
    )
    guard receipt.replayArtifactSHA256 == replayArtifactSHA256 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-stability replay does not recompute byte-identically"
      )
    }
    return receipt
  }

  private static func compare(
    referenceEvaluationArtifactSHA256: String,
    replayEvaluationArtifactSHA256: String,
    artifactDirectory: URL,
    writeArtifact: Bool
  ) throws -> BrainPolicyNumanXSupportStabilityReplayReceipt {
    let referenceReceipt = try BrainPolicyNumanXSupportStabilityEvaluator
      .verify(
        evaluationArtifactSHA256: referenceEvaluationArtifactSHA256,
        artifactDirectory: artifactDirectory
      )
    let replayReceipt = try BrainPolicyNumanXSupportStabilityEvaluator.verify(
      evaluationArtifactSHA256: replayEvaluationArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let reference = try evaluation(
      referenceEvaluationArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let replay = try evaluation(
      replayEvaluationArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    guard reference.candidateArtifactSHA256
        == replay.candidateArtifactSHA256,
      reference.contactVariantArtifactSHA256
        == replay.contactVariantArtifactSHA256,
      reference.axis == replay.axis,
      reference.thresholds == replay.thresholds,
      reference.baselineObservations == replay.baselineObservations,
      reference.learnedObservations == replay.learnedObservations,
      reference.baselineSuccessRate == replay.baselineSuccessRate,
      reference.learnedSuccessRate == replay.learnedSuccessRate,
      reference.learnedMinusBaselineSuccessRate
        == replay.learnedMinusBaselineSuccessRate
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-stability replay changed semantic evaluation evidence"
      )
    }
    let baseline = try compareRuns(
      reference.baselineRunArtifactSHA256,
      replay.baselineRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let learned = try compareRuns(
      reference.learnedRunArtifactSHA256,
      replay.learnedRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let artifact = try BrainPolicyNumanXSupportStabilityReplayArtifact(
      referenceEvaluationArtifactSHA256:
        referenceEvaluationArtifactSHA256,
      replayEvaluationArtifactSHA256: replayEvaluationArtifactSHA256,
      candidateArtifactSHA256: reference.candidateArtifactSHA256,
      contactVariantArtifactSHA256: reference.contactVariantArtifactSHA256,
      baselineRootCount: baseline.rootCount,
      learnedRootCount: learned.rootCount,
      transactionUniqueIdentityDifferenceCount:
        baseline.identityDifferenceCount + learned.identityDifferenceCount
    )
    let artifactHash = if writeArtifact {
      try artifact.write(to: artifactDirectory)
    } else {
      BrainPolicyEvidenceArtifact.sha256(try artifact.encoded())
    }
    var transitive = Data()
    for hash in [
      artifactHash,
      referenceEvaluationArtifactSHA256,
      replayEvaluationArtifactSHA256,
      referenceReceipt.transitiveEvidenceSHA256,
      replayReceipt.transitiveEvidenceSHA256,
    ].sorted() {
      transitive.append(Data(hash.utf8))
    }
    return BrainPolicyNumanXSupportStabilityReplayReceipt(
      replayArtifactSHA256: artifactHash,
      referenceEvaluationArtifactSHA256:
        referenceEvaluationArtifactSHA256,
      replayEvaluationArtifactSHA256: replayEvaluationArtifactSHA256,
      baselineRootCount: baseline.rootCount,
      learnedRootCount: learned.rootCount,
      transactionUniqueIdentityDifferenceCount:
        artifact.transactionUniqueIdentityDifferenceCount,
      transitiveEvidenceSHA256: BrainPolicyEvidenceArtifact.sha256(transitive)
    )
  }

  private static func evaluation(
    _ hash: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXSupportStabilityEvaluationArtifact {
    try BrainPolicyNumanXSupportStabilityEvaluationArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: hash,
        directory: artifactDirectory
      )
    )
  }

  private static func compareRuns(
    _ referenceHash: String,
    _ replayHash: String,
    artifactDirectory: URL
  ) throws -> (rootCount: UInt64, identityDifferenceCount: UInt64) {
    let reference = try run(referenceHash, artifactDirectory: artifactDirectory)
    let replay = try run(replayHash, artifactDirectory: artifactDirectory)
    guard reference.runIdentifier == replay.runIdentifier,
      reference.sourceRevision == replay.sourceRevision,
      reference.datasetSourceIdentifier == replay.datasetSourceIdentifier,
      reference.datasetSourceRevision == replay.datasetSourceRevision,
      reference.deviceRegistryID == replay.deviceRegistryID,
      reference.nativeModelSourceFingerprint
        == replay.nativeModelSourceFingerprint,
      reference.acceptedStateProofProgramFingerprint
        == replay.acceptedStateProofProgramFingerprint,
      reference.compiledSpeciesTemplateFingerprint
        == replay.compiledSpeciesTemplateFingerprint,
      reference.parameterVersionFingerprint
        == replay.parameterVersionFingerprint,
      reference.timestepMicroseconds == replay.timestepMicroseconds,
      reference.learningBatchArtifactSHA256
        == replay.learningBatchArtifactSHA256,
      reference.learningBatchFingerprint == replay.learningBatchFingerprint,
      reference.roots.count == replay.roots.count
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-stability replay changed run identity or learning state"
      )
    }
    var identityDifferences: UInt64 = 0
    for (referenceRoot, replayRoot) in zip(reference.roots, replay.roots) {
      guard referenceRoot.controlStep == replayRoot.controlStep else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX support-stability replay changed root ordering"
        )
      }
      let referenceSample = try sample(
        referenceRoot.sampleSHA256,
        artifactDirectory: artifactDirectory
      )
      let replaySample = try sample(
        replayRoot.sampleSHA256,
        artifactDirectory: artifactDirectory
      )
      guard semanticallyEqual(referenceSample, replaySample) else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX support-stability replay changed retained sensor evidence"
        )
      }
      let referenceExecution = try execution(
        referenceRoot.executionSHA256,
        artifactDirectory: artifactDirectory
      )
      let replayExecution = try execution(
        replayRoot.executionSHA256,
        artifactDirectory: artifactDirectory
      )
      guard semanticallyEqual(referenceExecution, replayExecution) else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX support-stability replay changed root outcome or generation"
        )
      }
      if referenceExecution.appliedRecordFingerprint
          != replayExecution.appliedRecordFingerprint
        || referenceExecution.jointCommitFingerprint
          != replayExecution.jointCommitFingerprint
      {
        identityDifferences += 1
      }
    }
    guard identityDifferences > 0 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-stability replay reused transaction authority identities"
      )
    }
    return (UInt64(reference.roots.count), identityDifferences)
  }

  private static func run(
    _ hash: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXCaptureRunArtifact {
    try BrainPolicyNumanXCaptureRunArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: hash,
        directory: artifactDirectory
      )
    )
  }

  private static func sample(
    _ hash: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXRootSampleArtifact {
    try BrainPolicyNumanXRootSampleArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: hash,
        directory: artifactDirectory
      )
    )
  }

  private static func execution(
    _ hash: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXRootExecution {
    try BrainPolicyNumanXRootExecution.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: hash,
        directory: artifactDirectory
      )
    )
  }

  private static func semanticallyEqual(
    _ lhs: BrainPolicyNumanXRootSampleArtifact,
    _ rhs: BrainPolicyNumanXRootSampleArtifact
  ) -> Bool {
    lhs.coordinates == rhs.coordinates
      && lhs.transactionFingerprint == rhs.transactionFingerprint
      && lhs.controlStep == rhs.controlStep
      && lhs.committedTimestampMicroseconds
        == rhs.committedTimestampMicroseconds
      && lhs.targetTimestampMicroseconds == rhs.targetTimestampMicroseconds
      && lhs.basePhysicsGeneration == rhs.basePhysicsGeneration
      && lhs.acceptedPhysicsTokenFingerprint
        == rhs.acceptedPhysicsTokenFingerprint
      && lhs.physicsGeneration == rhs.physicsGeneration
      && lhs.speciesTemplateFingerprint == rhs.speciesTemplateFingerprint
      && lhs.sensoryProfileFingerprint == rhs.sensoryProfileFingerprint
      && lhs.channels == rhs.channels
  }

  private static func semanticallyEqual(
    _ lhs: BrainPolicyNumanXRootExecution,
    _ rhs: BrainPolicyNumanXRootExecution
  ) -> Bool {
    lhs.ownerProgramFingerprint == rhs.ownerProgramFingerprint
      && lhs.transactionFingerprint == rhs.transactionFingerprint
      && lhs.linearizationEpoch == rhs.linearizationEpoch
      && lhs.slotGeneration == rhs.slotGeneration
      && lhs.transactionSlot == rhs.transactionSlot
      && lhs.environment == rhs.environment
      && lhs.stepIndex == rhs.stepIndex
      && lhs.controlStep == rhs.controlStep
      && lhs.substepIndex == rhs.substepIndex
      && lhs.physicsSubstepCount == rhs.physicsSubstepCount
      && lhs.outcome == rhs.outcome
  }
}

import Foundation

@frozen
public struct BrainPolicyNumanXLossWeight: Codable, Equatable, Sendable {
  public let kind: BrainSlowLossKind
  public let weight: Float

  public init(kind: BrainSlowLossKind, weight: Float) throws {
    guard weight.isFinite, weight >= 0 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX learner loss weight is invalid"
      )
    }
    self.kind = kind
    self.weight = weight
  }
}

@frozen
public struct BrainPolicyNumanXLearnerConfigurationArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let learnerIdentifier: String
  public let learningRate: Float
  public let gradientNormLimit: Float
  public let parameterMagnitudeLimit: Float
  public let lossWeights: [BrainPolicyNumanXLossWeight]
  public let delayedSupportObjectiveIdentifier: String?
  public let delayedSupportObjectiveWeight: Float?
  public let headPostureObjectiveIdentifier: String?
  public let headPostureObjectiveWeight: Float?

  public init(
    learnerIdentifier: String,
    learningRate: Float,
    gradientNormLimit: Float,
    parameterMagnitudeLimit: Float,
    lossWeights: [BrainPolicyNumanXLossWeight],
    delayedSupportObjectiveIdentifier: String? = nil,
    delayedSupportObjectiveWeight: Float? = nil,
    headPostureObjectiveIdentifier: String? = nil,
    headPostureObjectiveWeight: Float? = nil
  ) throws {
    let canonicalWeights = lossWeights.sorted { $0.kind.rawValue < $1.kind.rawValue }
    guard !learnerIdentifier.isEmpty, learningRate.isFinite, learningRate > 0,
      gradientNormLimit.isFinite, gradientNormLimit > 0,
      parameterMagnitudeLimit.isFinite, parameterMagnitudeLimit > 0,
      canonicalWeights.count == BrainSlowLossKind.allCases.count,
      Set(canonicalWeights.map(\.kind)) == Set(BrainSlowLossKind.allCases),
      (delayedSupportObjectiveIdentifier == nil)
        == (delayedSupportObjectiveWeight == nil),
      (headPostureObjectiveIdentifier == nil)
        == (headPostureObjectiveWeight == nil),
      delayedSupportObjectiveIdentifier == nil
        || headPostureObjectiveIdentifier == nil,
      delayedSupportObjectiveIdentifier == nil
        || delayedSupportObjectiveIdentifier
          == BrainPolicyNumanXDelayedSupportLearningArtifact.objectiveIdentifier,
      delayedSupportObjectiveWeight == nil
        || (delayedSupportObjectiveWeight!.isFinite
          && delayedSupportObjectiveWeight! > 0),
      headPostureObjectiveIdentifier == nil
        || headPostureObjectiveIdentifier
          == BrainPolicyNumanXHeadPostureLearningArtifact.objectiveIdentifier,
      headPostureObjectiveWeight == nil
        || (headPostureObjectiveWeight!.isFinite
          && headPostureObjectiveWeight! > 0)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX learner configuration artifact is invalid"
      )
    }
    self.formatVersion = Self.formatVersion
    self.learnerIdentifier = learnerIdentifier
    self.learningRate = learningRate
    self.gradientNormLimit = gradientNormLimit
    self.parameterMagnitudeLimit = parameterMagnitudeLimit
    self.lossWeights = canonicalWeights
    self.delayedSupportObjectiveIdentifier =
      delayedSupportObjectiveIdentifier
    self.delayedSupportObjectiveWeight = delayedSupportObjectiveWeight
    self.headPostureObjectiveIdentifier = headPostureObjectiveIdentifier
    self.headPostureObjectiveWeight = headPostureObjectiveWeight
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
    let configuration = try JSONDecoder().decode(Self.self, from: data)
    try configuration.validate()
    return configuration
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion,
      try Self(
        learnerIdentifier: learnerIdentifier,
        learningRate: learningRate,
        gradientNormLimit: gradientNormLimit,
        parameterMagnitudeLimit: parameterMagnitudeLimit,
        lossWeights: lossWeights,
        delayedSupportObjectiveIdentifier: delayedSupportObjectiveIdentifier,
        delayedSupportObjectiveWeight: delayedSupportObjectiveWeight,
        headPostureObjectiveIdentifier: headPostureObjectiveIdentifier,
        headPostureObjectiveWeight: headPostureObjectiveWeight
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX learner configuration artifact is not canonical"
      )
    }
  }
}

/// Immutable output of one off-rollout MLX update. It retains the exact update
/// bytes and parent version while binding them to one verified capture run and
/// one content-addressed learner configuration. It is a candidate, never a
/// deployable `.nbpolicy` or Gate C promotion by itself.
@frozen
public struct BrainPolicyNumanXLearnedCandidateArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let captureRunArtifactSHA256: String
  public let learnerConfigurationSHA256: String
  public let parentCandidateArtifactSHA256: String?
  public let parentVersion: BrainParameterVersion
  public let learnerUpdate: BrainLearnerUpdate
  public let delayedSupportLearningArtifactSHA256: String?
  public let headPostureLearningArtifactSHA256: String?
  public let modelWeightsSHA256: String
  public let promotable: Bool

  public init(
    captureRunArtifactSHA256: String,
    learnerConfigurationSHA256: String,
    parentCandidateArtifactSHA256: String? = nil,
    parentVersion: BrainParameterVersion,
    learnerUpdate: BrainLearnerUpdate,
    delayedSupportLearningArtifactSHA256: String? = nil,
    headPostureLearningArtifactSHA256: String? = nil
  ) throws {
    guard BrainPolicyEvidenceArtifact.isSHA256(captureRunArtifactSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(learnerConfigurationSHA256),
      parentCandidateArtifactSHA256 == nil
        || BrainPolicyEvidenceArtifact.isSHA256(
          parentCandidateArtifactSHA256!
        ),
      delayedSupportLearningArtifactSHA256 == nil
        || BrainPolicyEvidenceArtifact.isSHA256(
          delayedSupportLearningArtifactSHA256!
        ),
      headPostureLearningArtifactSHA256 == nil
        || BrainPolicyEvidenceArtifact.isSHA256(
          headPostureLearningArtifactSHA256!
        ),
      delayedSupportLearningArtifactSHA256 == nil
        || headPostureLearningArtifactSHA256 == nil
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX learned candidate provenance hash is invalid"
      )
    }
    try learnerUpdate.validate(parentVersion: parentVersion)
    let publication = try BrainParameterPublication(
      parentVersion: parentVersion,
      learnerUpdate: learnerUpdate
    )
    self.formatVersion = Self.formatVersion
    self.captureRunArtifactSHA256 = captureRunArtifactSHA256
    self.learnerConfigurationSHA256 = learnerConfigurationSHA256
    self.parentCandidateArtifactSHA256 = parentCandidateArtifactSHA256
    self.parentVersion = parentVersion
    self.learnerUpdate = learnerUpdate
    self.delayedSupportLearningArtifactSHA256 =
      delayedSupportLearningArtifactSHA256
    self.headPostureLearningArtifactSHA256 =
      headPostureLearningArtifactSHA256
    self.modelWeightsSHA256 = try BrainFoundationPolicyPackage
      .parameterWeightsSHA256(publication)
    self.promotable = false
  }

  public var publication: BrainParameterPublication {
    get throws {
      try BrainParameterPublication(
        parentVersion: parentVersion,
        learnerUpdate: learnerUpdate
      )
    }
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
    let candidate = try JSONDecoder().decode(Self.self, from: data)
    try candidate.validate()
    return candidate
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion, !promotable,
      try Self(
        captureRunArtifactSHA256: captureRunArtifactSHA256,
        learnerConfigurationSHA256: learnerConfigurationSHA256,
        parentCandidateArtifactSHA256: parentCandidateArtifactSHA256,
        parentVersion: parentVersion,
        learnerUpdate: learnerUpdate,
        delayedSupportLearningArtifactSHA256:
          delayedSupportLearningArtifactSHA256,
        headPostureLearningArtifactSHA256:
          headPostureLearningArtifactSHA256
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX learned candidate artifact is not canonical"
      )
    }
  }
}

public struct BrainPolicyNumanXLearnedCandidateVerificationReceipt: Sendable {
  public let candidateArtifactSHA256: String
  public let captureRunArtifactSHA256: String
  public let modelWeightsSHA256: String
  public let learnerUpdateFingerprint: UInt64
  public let transitiveEvidenceSHA256: String
}

public enum BrainPolicyNumanXLearnedCandidateVerifier {
  /// Returns the learned publication only after the complete candidate, run,
  /// configuration, and retained learning batch have passed transitive
  /// verification. Offline evaluation must never load an update by decoding a
  /// candidate manifest alone.
  public static func verifiedPublication(
    candidateArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainParameterPublication {
    try verifiedCandidate(
      candidateArtifactSHA256: candidateArtifactSHA256,
      artifactDirectory: artifactDirectory
    ).publication
  }

  public static func verifiedCandidate(
    candidateArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXLearnedCandidateArtifact {
    _ = try verify(
      candidateArtifactSHA256: candidateArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    return try BrainPolicyNumanXLearnedCandidateArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: candidateArtifactSHA256,
        directory: artifactDirectory
      )
    )
  }

  public static func verify(
    candidateArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXLearnedCandidateVerificationReceipt {
    var visiting: Set<String> = []
    return try verify(
      candidateArtifactSHA256: candidateArtifactSHA256,
      artifactDirectory: artifactDirectory,
      visiting: &visiting
    )
  }

  private static func verify(
    candidateArtifactSHA256: String,
    artifactDirectory: URL,
    visiting: inout Set<String>
  ) throws -> BrainPolicyNumanXLearnedCandidateVerificationReceipt {
    guard visiting.insert(candidateArtifactSHA256).inserted else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX learned candidate provenance contains a cycle"
      )
    }
    defer { visiting.remove(candidateArtifactSHA256) }
    let candidate = try BrainPolicyNumanXLearnedCandidateArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: candidateArtifactSHA256,
        directory: artifactDirectory
      )
    )
    let configuration = try BrainPolicyNumanXLearnerConfigurationArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: candidate.learnerConfigurationSHA256,
        directory: artifactDirectory
      )
    )
    let run = try BrainPolicyNumanXCaptureRunArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: candidate.captureRunArtifactSHA256,
        directory: artifactDirectory
      )
    )
    let batch = try BrainPolicyNumanXLearningBatchArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: run.learningBatchArtifactSHA256,
        directory: artifactDirectory
      )
    )
    let runReceipt = try BrainPolicyNumanXCaptureVerifier.verify(
      runArtifactSHA256: candidate.captureRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let delayedSupport: BrainPolicyNumanXDelayedSupportLearningArtifact?
    if let hash = candidate.delayedSupportLearningArtifactSHA256 {
      delayedSupport = try BrainPolicyNumanXDelayedSupportLearningArtifact.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(
          sha256: hash,
          directory: artifactDirectory
        )
      )
    } else {
      delayedSupport = nil
    }
    if let delayedSupport {
      let recomputed = try BrainPolicyNumanXDelayedSupportLearningBuilder.build(
        sourceRunArtifactSHA256: candidate.captureRunArtifactSHA256,
        artifactDirectory: artifactDirectory,
        horizonRootCount: delayedSupport.horizonRootCount,
        objectiveWeight: delayedSupport.objectiveWeight,
        thresholds: delayedSupport.thresholds
      )
      guard recomputed == delayedSupport else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX delayed-support supervision does not recompute from its run"
        )
      }
    }
    let headPosture: BrainPolicyNumanXHeadPostureLearningArtifact?
    if let hash = candidate.headPostureLearningArtifactSHA256 {
      headPosture = try BrainPolicyNumanXHeadPostureLearningArtifact.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(
          sha256: hash,
          directory: artifactDirectory
        )
      )
    } else {
      headPosture = nil
    }
    if let headPosture {
      let recomputed = try BrainPolicyNumanXHeadPostureLearningBuilder
        .buildFromVerifiedSourceRun(
        sourceRunArtifactSHA256: candidate.captureRunArtifactSHA256,
        artifactDirectory: artifactDirectory,
        objectiveWeight: headPosture.objectiveWeight,
        calibrationEvaluationArtifactSHA256:
          headPosture.calibrationEvaluationArtifactSHA256
      )
      guard recomputed == headPosture else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX head-posture supervision does not recompute from its run"
        )
      }
    }
    var parentReceipt:
      BrainPolicyNumanXLearnedCandidateVerificationReceipt?
    if let parentHash = candidate.parentCandidateArtifactSHA256 {
      guard parentHash != candidateArtifactSHA256 else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX learned candidate cannot name itself as parent"
        )
      }
      parentReceipt = try verify(
        candidateArtifactSHA256: parentHash,
        artifactDirectory: artifactDirectory,
        visiting: &visiting
      )
      let parent = try BrainPolicyNumanXLearnedCandidateArtifact.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(
          sha256: parentHash,
          directory: artifactDirectory
        )
      )
      guard try parent.publication.version == candidate.parentVersion else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX learned candidate parent artifact has the wrong version"
        )
      }
    }
    let expectedWeights = Dictionary(
      uniqueKeysWithValues: configuration.lossWeights.map {
        ($0.kind, $0.weight)
      }
    )
    let expectedDelayedSupportRun =
      candidate.delayedSupportLearningArtifactSHA256 == nil
        ? nil : candidate.captureRunArtifactSHA256
    let expectedHeadPostureRun =
      candidate.headPostureLearningArtifactSHA256 == nil
        ? nil : candidate.captureRunArtifactSHA256
    guard candidate.parentVersion.fingerprint
        == run.parameterVersionFingerprint,
      candidate.learnerUpdate.sourceBatchFingerprint
        == run.learningBatchFingerprint,
      candidate.learnerUpdate.sourceBatchFingerprint == batch.batchFingerprint,
      candidate.learnerUpdate.sourceGeneration == batch.sourceGeneration,
      candidate.learnerUpdate.losses.allSatisfy({
        expectedWeights[$0.kind] == $0.weight
      }),
      (delayedSupport == nil)
        == (configuration.delayedSupportObjectiveIdentifier == nil),
      delayedSupport?.sourceRunArtifactSHA256
        == expectedDelayedSupportRun,
      delayedSupport?.objectiveIdentifier
        == configuration.delayedSupportObjectiveIdentifier,
      delayedSupport?.objectiveWeight
        == configuration.delayedSupportObjectiveWeight,
      (headPosture == nil)
        == (configuration.headPostureObjectiveIdentifier == nil),
      headPosture?.sourceRunArtifactSHA256 == expectedHeadPostureRun,
      headPosture?.objectiveIdentifier
        == configuration.headPostureObjectiveIdentifier,
      headPosture?.objectiveWeight
        == configuration.headPostureObjectiveWeight
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX learned candidate does not bind its run, batch, and loss configuration"
      )
    }
    var evidence = Data(candidateArtifactSHA256.utf8)
    evidence.append(Data(candidate.captureRunArtifactSHA256.utf8))
    evidence.append(Data(candidate.learnerConfigurationSHA256.utf8))
    if let parent = candidate.parentCandidateArtifactSHA256 {
      evidence.append(Data(parent.utf8))
    }
    if let parentReceipt {
      evidence.append(Data(parentReceipt.transitiveEvidenceSHA256.utf8))
    }
    evidence.append(Data(runReceipt.transitiveEvidenceSHA256.utf8))
    if let hash = candidate.delayedSupportLearningArtifactSHA256 {
      evidence.append(Data(hash.utf8))
    }
    if let hash = candidate.headPostureLearningArtifactSHA256 {
      evidence.append(Data(hash.utf8))
    }
    return BrainPolicyNumanXLearnedCandidateVerificationReceipt(
      candidateArtifactSHA256: candidateArtifactSHA256,
      captureRunArtifactSHA256: candidate.captureRunArtifactSHA256,
      modelWeightsSHA256: candidate.modelWeightsSHA256,
      learnerUpdateFingerprint: candidate.learnerUpdate.updateFingerprint,
      transitiveEvidenceSHA256: BrainPolicyEvidenceArtifact.sha256(evidence)
    )
  }
}

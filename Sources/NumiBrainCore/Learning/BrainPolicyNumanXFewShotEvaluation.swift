import Foundation

/// Monotonic host measurement of one deterministic MLX adaptation update. One
/// example is one accepted authoritative NumanX root present in the exact
/// retained learning batch. This artifact does not claim task improvement.
@frozen
public struct BrainPolicyNumanXAdaptationTrainingArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let parentCandidateArtifactSHA256: String
  public let adaptedCandidateArtifactSHA256: String
  public let adaptationRunArtifactSHA256: String
  public let adaptationExampleCount: UInt32
  public let adaptationWallClockSeconds: Double
  public let promotable: Bool

  public init(
    parentCandidateArtifactSHA256: String,
    adaptedCandidateArtifactSHA256: String,
    adaptationRunArtifactSHA256: String,
    adaptationExampleCount: UInt32,
    adaptationWallClockSeconds: Double
  ) throws {
    guard BrainPolicyEvidenceArtifact.isSHA256(parentCandidateArtifactSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(adaptedCandidateArtifactSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(adaptationRunArtifactSHA256),
      parentCandidateArtifactSHA256 != adaptedCandidateArtifactSHA256,
      (1...32).contains(adaptationExampleCount),
      adaptationWallClockSeconds.isFinite, adaptationWallClockSeconds > 0
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX adaptation training evidence is invalid"
      )
    }
    self.formatVersion = Self.formatVersion
    self.parentCandidateArtifactSHA256 = parentCandidateArtifactSHA256
    self.adaptedCandidateArtifactSHA256 = adaptedCandidateArtifactSHA256
    self.adaptationRunArtifactSHA256 = adaptationRunArtifactSHA256
    self.adaptationExampleCount = adaptationExampleCount
    self.adaptationWallClockSeconds = adaptationWallClockSeconds
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
    guard formatVersion == Self.formatVersion, !promotable,
      try Self(
        parentCandidateArtifactSHA256: parentCandidateArtifactSHA256,
        adaptedCandidateArtifactSHA256: adaptedCandidateArtifactSHA256,
        adaptationRunArtifactSHA256: adaptationRunArtifactSHA256,
        adaptationExampleCount: adaptationExampleCount,
        adaptationWallClockSeconds: adaptationWallClockSeconds
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX adaptation training artifact is not canonical"
      )
    }
  }
}

/// Local, recomputable few-shot evaluation. It retains pre-adaptation context,
/// post-adaptation task success, and prior-task retention. Promotion still
/// requires a separately frozen adaptation partition and an independently
/// sourced task/embodiment matrix.
@frozen
public struct BrainPolicyNumanXFewShotEvaluationArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 3

  public let formatVersion: UInt32
  public let trainingArtifactSHA256: String
  public let parentCandidateArtifactSHA256: String
  public let adaptedCandidateArtifactSHA256: String
  public let preAdaptationRunArtifactSHA256: String
  public let postAdaptationRunArtifactSHA256: String
  public let retainedPriorRunArtifactSHA256: String
  public let axis: BrainPolicyQualificationAxis
  public let adaptationThresholds: BrainPolicyNumanXSupportStabilityThresholds
  public let retainedPriorThresholds: BrainPolicyNumanXSupportStabilityThresholds
  public let adaptationExampleCount: UInt32
  public let adaptationWallClockSeconds: Double
  public let preAdaptationObservations:
    [BrainPolicyNumanXSupportStabilityObservation]
  public let postAdaptationObservations:
    [BrainPolicyNumanXSupportStabilityObservation]
  public let retainedPriorObservations:
    [BrainPolicyNumanXSupportStabilityObservation]
  public let preAdaptationSuccessRate: Double
  public let postAdaptationSuccessRate: Double
  public let retainedPriorSuccessRate: Double
  public let postMinusPreAdaptationSuccessRate: Double
  public let metrics: [BrainPolicyQualificationMetricEvidence]
  public let passesPredeclaredThresholds: Bool
  public let demonstratesPositiveAdaptation: Bool
  public let promotable: Bool

  public init(
    trainingArtifactSHA256: String,
    parentCandidateArtifactSHA256: String,
    adaptedCandidateArtifactSHA256: String,
    preAdaptationRunArtifactSHA256: String,
    postAdaptationRunArtifactSHA256: String,
    retainedPriorRunArtifactSHA256: String,
    adaptationThresholds: BrainPolicyNumanXSupportStabilityThresholds,
    retainedPriorThresholds: BrainPolicyNumanXSupportStabilityThresholds,
    adaptationExampleCount: UInt32,
    adaptationWallClockSeconds: Double,
    adaptationSampleSHA256: String,
    preAdaptationObservations:
      [BrainPolicyNumanXSupportStabilityObservation],
    postAdaptationObservations:
      [BrainPolicyNumanXSupportStabilityObservation],
    retainedPriorObservations:
      [BrainPolicyNumanXSupportStabilityObservation]
  ) throws {
    let pre = preAdaptationObservations.sorted { $0.controlStep < $1.controlStep }
    let post = postAdaptationObservations.sorted { $0.controlStep < $1.controlStep }
    let prior = retainedPriorObservations.sorted { $0.controlStep < $1.controlStep }
    guard [trainingArtifactSHA256, parentCandidateArtifactSHA256,
      adaptedCandidateArtifactSHA256, preAdaptationRunArtifactSHA256,
      postAdaptationRunArtifactSHA256, retainedPriorRunArtifactSHA256,
      adaptationSampleSHA256].allSatisfy(BrainPolicyEvidenceArtifact.isSHA256),
      parentCandidateArtifactSHA256 != adaptedCandidateArtifactSHA256,
      Set([preAdaptationRunArtifactSHA256, postAdaptationRunArtifactSHA256,
        retainedPriorRunArtifactSHA256]).count == 3,
      (1...32).contains(adaptationExampleCount),
      adaptationWallClockSeconds.isFinite, adaptationWallClockSeconds > 0,
      !pre.isEmpty, pre.count == post.count, !prior.isEmpty,
      zip(pre, post).allSatisfy({ $0.controlStep == $1.controlStep })
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX few-shot evaluation evidence is invalid"
      )
    }
    func successRate(
      _ observations: [BrainPolicyNumanXSupportStabilityObservation]
    ) -> Double {
      Double(observations.count(where: \.success)) / Double(observations.count)
    }
    let preRate = successRate(pre)
    let postRate = successRate(post)
    let priorRate = successRate(prior)
    let metrics = try [
      BrainPolicyQualificationMetricEvidence(
        identifier: "adaptation_examples", unit: "count", reducer: .maximum,
        threshold: 32, direction: .atMost,
        observations: [try BrainPolicyMetricObservation(
          sampleSHA256: adaptationSampleSHA256,
          value: Double(adaptationExampleCount)
        )]
      ),
      BrainPolicyQualificationMetricEvidence(
        identifier: "adaptation_wall_clock", unit: "seconds",
        reducer: .maximum, threshold: 3_600, direction: .atMost,
        observations: [try BrainPolicyMetricObservation(
          sampleSHA256: adaptationSampleSHA256,
          value: adaptationWallClockSeconds
        )]
      ),
      BrainPolicyQualificationMetricEvidence(
        identifier: "adaptation_success_gain", unit: "ratio",
        reducer: .mean, threshold: 0.1, direction: .atLeast,
        observations: try zip(pre, post).map { before, after in
          try BrainPolicyMetricObservation(
            sampleSHA256: after.sampleSHA256,
            value: (after.success ? 1 : 0) - (before.success ? 1 : 0)
          )
        }
      ),
      BrainPolicyQualificationMetricEvidence(
        identifier: "post_adaptation_success_rate", unit: "ratio",
        reducer: .mean, threshold: 0.7, direction: .atLeast,
        observations: try post.map {
          try BrainPolicyMetricObservation(
            sampleSHA256: $0.sampleSHA256, value: $0.success ? 1 : 0
          )
        }
      ),
      BrainPolicyQualificationMetricEvidence(
        identifier: "retained_prior_success_rate", unit: "ratio",
        reducer: .mean, threshold: 0.65, direction: .atLeast,
        observations: try prior.map {
          try BrainPolicyMetricObservation(
            sampleSHA256: $0.sampleSHA256, value: $0.success ? 1 : 0
          )
        }
      ),
    ].sorted { $0.identifier < $1.identifier }
    self.formatVersion = Self.formatVersion
    self.trainingArtifactSHA256 = trainingArtifactSHA256
    self.parentCandidateArtifactSHA256 = parentCandidateArtifactSHA256
    self.adaptedCandidateArtifactSHA256 = adaptedCandidateArtifactSHA256
    self.preAdaptationRunArtifactSHA256 = preAdaptationRunArtifactSHA256
    self.postAdaptationRunArtifactSHA256 = postAdaptationRunArtifactSHA256
    self.retainedPriorRunArtifactSHA256 = retainedPriorRunArtifactSHA256
    self.axis = .fewShotAdaptation
    self.adaptationThresholds = adaptationThresholds
    self.retainedPriorThresholds = retainedPriorThresholds
    self.adaptationExampleCount = adaptationExampleCount
    self.adaptationWallClockSeconds = adaptationWallClockSeconds
    self.preAdaptationObservations = pre
    self.postAdaptationObservations = post
    self.retainedPriorObservations = prior
    self.preAdaptationSuccessRate = preRate
    self.postAdaptationSuccessRate = postRate
    self.retainedPriorSuccessRate = priorRate
    self.postMinusPreAdaptationSuccessRate = postRate - preRate
    self.metrics = metrics
    self.passesPredeclaredThresholds = metrics.allSatisfy { metric in
      switch metric.direction {
      case .atLeast: metric.reducedValue >= metric.threshold
      case .atMost: metric.reducedValue <= metric.threshold
      }
    }
    self.demonstratesPositiveAdaptation = postRate - preRate >= 0.1
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
    let adaptationSample = metrics.first(where: {
      $0.identifier == "adaptation_examples"
    })?.observations.first?.sampleSHA256
    guard formatVersion == Self.formatVersion, axis == .fewShotAdaptation,
      !promotable, let adaptationSample,
      try Self(
        trainingArtifactSHA256: trainingArtifactSHA256,
        parentCandidateArtifactSHA256: parentCandidateArtifactSHA256,
        adaptedCandidateArtifactSHA256: adaptedCandidateArtifactSHA256,
        preAdaptationRunArtifactSHA256: preAdaptationRunArtifactSHA256,
        postAdaptationRunArtifactSHA256: postAdaptationRunArtifactSHA256,
        retainedPriorRunArtifactSHA256: retainedPriorRunArtifactSHA256,
        adaptationThresholds: adaptationThresholds,
        retainedPriorThresholds: retainedPriorThresholds,
        adaptationExampleCount: adaptationExampleCount,
        adaptationWallClockSeconds: adaptationWallClockSeconds,
        adaptationSampleSHA256: adaptationSample,
        preAdaptationObservations: preAdaptationObservations,
        postAdaptationObservations: postAdaptationObservations,
        retainedPriorObservations: retainedPriorObservations
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX few-shot evaluation artifact is not canonical"
      )
    }
  }
}

public struct BrainPolicyNumanXFewShotEvaluationReceipt: Sendable {
  public let evaluationArtifactSHA256: String
  public let trainingArtifactSHA256: String
  public let parentCandidateArtifactSHA256: String
  public let adaptedCandidateArtifactSHA256: String
  public let adaptationExampleCount: UInt32
  public let adaptationWallClockSeconds: Double
  public let preAdaptationSuccessRate: Double
  public let postAdaptationSuccessRate: Double
  public let retainedPriorSuccessRate: Double
  public let postMinusPreAdaptationSuccessRate: Double
  public let passesPredeclaredThresholds: Bool
  public let demonstratesPositiveAdaptation: Bool
  public let transitiveEvidenceSHA256: String
}

public enum BrainPolicyNumanXFewShotEvaluator {
  public static func evaluateAndWrite(
    trainingArtifactSHA256: String,
    preAdaptationRunArtifactSHA256: String,
    postAdaptationRunArtifactSHA256: String,
    retainedPriorRunArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXFewShotEvaluationReceipt {
    try evaluate(
      trainingArtifactSHA256: trainingArtifactSHA256,
      preAdaptationRunArtifactSHA256: preAdaptationRunArtifactSHA256,
      postAdaptationRunArtifactSHA256: postAdaptationRunArtifactSHA256,
      retainedPriorRunArtifactSHA256: retainedPriorRunArtifactSHA256,
      artifactDirectory: artifactDirectory,
      writeArtifact: true
    )
  }

  public static func verify(
    evaluationArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXFewShotEvaluationReceipt {
    let stored = try BrainPolicyNumanXFewShotEvaluationArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: evaluationArtifactSHA256,
        directory: artifactDirectory
      )
    )
    let receipt = try evaluate(
      trainingArtifactSHA256: stored.trainingArtifactSHA256,
      preAdaptationRunArtifactSHA256: stored.preAdaptationRunArtifactSHA256,
      postAdaptationRunArtifactSHA256: stored.postAdaptationRunArtifactSHA256,
      retainedPriorRunArtifactSHA256: stored.retainedPriorRunArtifactSHA256,
      artifactDirectory: artifactDirectory,
      writeArtifact: false
    )
    guard receipt.evaluationArtifactSHA256 == evaluationArtifactSHA256 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX few-shot evaluation does not recompute byte-identically"
      )
    }
    return receipt
  }

  private static func evaluate(
    trainingArtifactSHA256: String,
    preAdaptationRunArtifactSHA256: String,
    postAdaptationRunArtifactSHA256: String,
    retainedPriorRunArtifactSHA256: String,
    artifactDirectory: URL,
    writeArtifact: Bool
  ) throws -> BrainPolicyNumanXFewShotEvaluationReceipt {
    let training = try BrainPolicyNumanXAdaptationTrainingArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: trainingArtifactSHA256,
        directory: artifactDirectory
      )
    )
    let parent = try BrainPolicyNumanXLearnedCandidateVerifier.verifiedCandidate(
      candidateArtifactSHA256: training.parentCandidateArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let adapted = try BrainPolicyNumanXLearnedCandidateVerifier.verifiedCandidate(
      candidateArtifactSHA256: training.adaptedCandidateArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let adaptationRun = try BrainPolicyNumanXSupportStabilityEvaluator.run(
      training.adaptationRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let parentTrainingRun = try BrainPolicyNumanXSupportStabilityEvaluator.run(
      parent.captureRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let preRun = try BrainPolicyNumanXSupportStabilityEvaluator.run(
      preAdaptationRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let postRun = try BrainPolicyNumanXSupportStabilityEvaluator.run(
      postAdaptationRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let priorRun = try BrainPolicyNumanXSupportStabilityEvaluator.run(
      retainedPriorRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    for hash in [training.adaptationRunArtifactSHA256,
      preAdaptationRunArtifactSHA256, postAdaptationRunArtifactSHA256,
      retainedPriorRunArtifactSHA256]
    {
      _ = try BrainPolicyNumanXCaptureVerifier.verify(
        runArtifactSHA256: hash, artifactDirectory: artifactDirectory
      )
    }
    let adaptedPublication = try adapted.publication
    let parentPublication = try parent.publication
    let adaptationExecutions = try adaptationRun.roots.map { root in
      try BrainPolicyNumanXRootExecution.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(
          sha256: root.executionSHA256, directory: artifactDirectory
        )
      )
    }
    let acceptedAdaptationExamples = adaptationExecutions.count {
      $0.outcome == .accepted
    }
    guard adapted.parentCandidateArtifactSHA256
        == training.parentCandidateArtifactSHA256,
      adapted.captureRunArtifactSHA256 == training.adaptationRunArtifactSHA256,
      adapted.parentVersion == parentPublication.version,
      UInt32(acceptedAdaptationExamples) == training.adaptationExampleCount,
      adaptationRun.parameterVersionFingerprint == parentPublication.version.fingerprint,
      preRun.parameterVersionFingerprint == parentPublication.version.fingerprint,
      postRun.parameterVersionFingerprint == adaptedPublication.version.fingerprint,
      priorRun.parameterVersionFingerprint == adaptedPublication.version.fingerprint
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX few-shot runs do not bind the exact parent and adapted candidates"
      )
    }
    let adaptationCoordinates = try BrainPolicyNumanXSupportStabilityEvaluator
      .canonicalCoordinates(adaptationRun, artifactDirectory: artifactDirectory)
    let preCoordinates = try BrainPolicyNumanXSupportStabilityEvaluator
      .canonicalCoordinates(preRun, artifactDirectory: artifactDirectory)
    let postCoordinates = try BrainPolicyNumanXSupportStabilityEvaluator
      .canonicalCoordinates(postRun, artifactDirectory: artifactDirectory)
    let parentCoordinates = try BrainPolicyNumanXSupportStabilityEvaluator
      .canonicalCoordinates(parentTrainingRun, artifactDirectory: artifactDirectory)
    let priorCoordinates = try BrainPolicyNumanXSupportStabilityEvaluator
      .canonicalCoordinates(priorRun, artifactDirectory: artifactDirectory)
    guard adaptationCoordinates.taskFingerprint == preCoordinates.taskFingerprint,
      adaptationCoordinates.sceneFingerprint == preCoordinates.sceneFingerprint,
      adaptationCoordinates.objectFingerprint == preCoordinates.objectFingerprint,
      adaptationCoordinates.embodimentFingerprint == preCoordinates.embodimentFingerprint,
      preCoordinates.taskFingerprint == postCoordinates.taskFingerprint,
      preCoordinates.sceneFingerprint == postCoordinates.sceneFingerprint,
      preCoordinates.objectFingerprint == postCoordinates.objectFingerprint,
      preCoordinates.embodimentFingerprint == postCoordinates.embodimentFingerprint,
      parentCoordinates.taskFingerprint == priorCoordinates.taskFingerprint,
      parentCoordinates.sceneFingerprint == priorCoordinates.sceneFingerprint,
      parentCoordinates.objectFingerprint == priorCoordinates.objectFingerprint,
      parentCoordinates.embodimentFingerprint == priorCoordinates.embodimentFingerprint,
      adaptationRun.timestepMicroseconds == preRun.timestepMicroseconds,
      preRun.timestepMicroseconds == postRun.timestepMicroseconds,
      postRun.timestepMicroseconds == priorRun.timestepMicroseconds
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX few-shot task and retained-prior coordinates are not exact"
      )
    }
    let sampleSets = [adaptationRun, preRun, postRun, priorRun].map {
      Set($0.roots.map(\.sampleSHA256))
    }
    for left in sampleSets.indices {
      for right in sampleSets.indices where right > left {
        guard sampleSets[left].isDisjoint(with: sampleSets[right]) else {
          throw BrainRuntimeError.invalidParameterVersion(
            "NumanX few-shot adaptation and evaluation samples overlap"
          )
        }
      }
    }
    let adaptationThresholds = BrainPolicyNumanXSupportStabilityThresholds
      .gateCFewShotSupportV1
    let retainedPriorThresholds = BrainPolicyNumanXSupportStabilityThresholds
      .gateCCrossSceneV1
    let pre = try BrainPolicyNumanXSupportStabilityEvaluator.observations(
      preRun, thresholds: adaptationThresholds,
      artifactDirectory: artifactDirectory
    )
    let post = try BrainPolicyNumanXSupportStabilityEvaluator.observations(
      postRun, thresholds: adaptationThresholds,
      artifactDirectory: artifactDirectory
    )
    let prior = try BrainPolicyNumanXSupportStabilityEvaluator.observations(
      priorRun, thresholds: retainedPriorThresholds,
      artifactDirectory: artifactDirectory
    )
    guard pre.count >= 10, post.count >= 10, prior.count >= 10,
      let adaptationSample = adaptationRun.roots.first?.sampleSHA256
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX few-shot evaluation requires ten physical observations per cohort"
      )
    }
    let artifact = try BrainPolicyNumanXFewShotEvaluationArtifact(
      trainingArtifactSHA256: trainingArtifactSHA256,
      parentCandidateArtifactSHA256: training.parentCandidateArtifactSHA256,
      adaptedCandidateArtifactSHA256: training.adaptedCandidateArtifactSHA256,
      preAdaptationRunArtifactSHA256: preAdaptationRunArtifactSHA256,
      postAdaptationRunArtifactSHA256: postAdaptationRunArtifactSHA256,
      retainedPriorRunArtifactSHA256: retainedPriorRunArtifactSHA256,
      adaptationThresholds: adaptationThresholds,
      retainedPriorThresholds: retainedPriorThresholds,
      adaptationExampleCount: training.adaptationExampleCount,
      adaptationWallClockSeconds: training.adaptationWallClockSeconds,
      adaptationSampleSHA256: adaptationSample,
      preAdaptationObservations: pre,
      postAdaptationObservations: post,
      retainedPriorObservations: prior
    )
    let artifactHash = if writeArtifact {
      try artifact.write(to: artifactDirectory)
    } else {
      BrainPolicyEvidenceArtifact.sha256(try artifact.encoded())
    }
    var transitive = Data()
    for hash in [artifactHash, trainingArtifactSHA256,
      training.parentCandidateArtifactSHA256,
      training.adaptedCandidateArtifactSHA256,
      training.adaptationRunArtifactSHA256, preAdaptationRunArtifactSHA256,
      postAdaptationRunArtifactSHA256, retainedPriorRunArtifactSHA256].sorted()
    {
      transitive.append(Data(hash.utf8))
    }
    return BrainPolicyNumanXFewShotEvaluationReceipt(
      evaluationArtifactSHA256: artifactHash,
      trainingArtifactSHA256: trainingArtifactSHA256,
      parentCandidateArtifactSHA256: training.parentCandidateArtifactSHA256,
      adaptedCandidateArtifactSHA256: training.adaptedCandidateArtifactSHA256,
      adaptationExampleCount: training.adaptationExampleCount,
      adaptationWallClockSeconds: training.adaptationWallClockSeconds,
      preAdaptationSuccessRate: artifact.preAdaptationSuccessRate,
      postAdaptationSuccessRate: artifact.postAdaptationSuccessRate,
      retainedPriorSuccessRate: artifact.retainedPriorSuccessRate,
      postMinusPreAdaptationSuccessRate:
        artifact.postMinusPreAdaptationSuccessRate,
      passesPredeclaredThresholds: artifact.passesPredeclaredThresholds,
      demonstratesPositiveAdaptation: artifact.demonstratesPositiveAdaptation,
      transitiveEvidenceSHA256: BrainPolicyEvidenceArtifact.sha256(transitive)
    )
  }
}

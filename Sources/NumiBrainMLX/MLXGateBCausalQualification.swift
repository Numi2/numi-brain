import Foundation
import NumiBrainCore
import NumiBrainMetal

@frozen
public struct NumanXGateBCausalProtocol: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let modalities: [SensoryModality]
  public let minimumGeneration: UInt64
  public let maximumGeneration: UInt64
  public let minimumTransitionsPerModality: UInt32
  public let maximumIntactActionMSE: Float
  public let minimumAblationActionDelta: Float
  public let minimumShuffleActionDelta: Float
  public let minimumTimestampShiftActionDelta: Float
  public let shuffleSeed: UInt64

  public init(modalities: [SensoryModality], minimumGeneration: UInt64,
    maximumGeneration: UInt64, minimumTransitionsPerModality: UInt32,
    maximumIntactActionMSE: Float, minimumAblationActionDelta: Float,
    minimumShuffleActionDelta: Float, minimumTimestampShiftActionDelta: Float,
    shuffleSeed: UInt64) throws {
    formatVersion = Self.formatVersion
    self.modalities = modalities.sorted { $0.rawValue < $1.rawValue }
    self.minimumGeneration = minimumGeneration; self.maximumGeneration = maximumGeneration
    self.minimumTransitionsPerModality = minimumTransitionsPerModality
    self.maximumIntactActionMSE = maximumIntactActionMSE
    self.minimumAblationActionDelta = minimumAblationActionDelta
    self.minimumShuffleActionDelta = minimumShuffleActionDelta
    self.minimumTimestampShiftActionDelta = minimumTimestampShiftActionDelta
    self.shuffleSeed = shuffleSeed
    try validate()
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion, !modalities.isEmpty, modalities.count <= 8,
      Set(modalities).count == modalities.count,
      modalities == modalities.sorted(by: { $0.rawValue < $1.rawValue }),
      minimumGeneration > 0, minimumGeneration <= maximumGeneration,
      minimumTransitionsPerModality > 0, shuffleSeed > 0,
      maximumIntactActionMSE.isFinite, maximumIntactActionMSE >= 0,
      minimumAblationActionDelta.isFinite, minimumAblationActionDelta > 0,
      minimumShuffleActionDelta.isFinite, minimumShuffleActionDelta > 0,
      minimumTimestampShiftActionDelta.isFinite, minimumTimestampShiftActionDelta > 0 else {
      throw BrainRuntimeError.invalidParameterVersion("Gate B causal protocol is invalid")
    }
  }

  private enum CodingKeys: String, CodingKey {
    case formatVersion, modalities, minimumGeneration, maximumGeneration
    case minimumTransitionsPerModality, maximumIntactActionMSE
    case minimumAblationActionDelta, minimumShuffleActionDelta
    case minimumTimestampShiftActionDelta, shuffleSeed
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    guard try c.decode(UInt32.self, forKey: .formatVersion) == Self.formatVersion else {
      throw BrainRuntimeError.invalidParameterVersion("unsupported Gate B causal protocol version")
    }
    try self.init(modalities: c.decode([SensoryModality].self, forKey: .modalities),
      minimumGeneration: c.decode(UInt64.self, forKey: .minimumGeneration),
      maximumGeneration: c.decode(UInt64.self, forKey: .maximumGeneration),
      minimumTransitionsPerModality: c.decode(UInt32.self, forKey: .minimumTransitionsPerModality),
      maximumIntactActionMSE: c.decode(Float.self, forKey: .maximumIntactActionMSE),
      minimumAblationActionDelta: c.decode(Float.self, forKey: .minimumAblationActionDelta),
      minimumShuffleActionDelta: c.decode(Float.self, forKey: .minimumShuffleActionDelta),
      minimumTimestampShiftActionDelta: c.decode(Float.self, forKey: .minimumTimestampShiftActionDelta),
      shuffleSeed: c.decode(UInt64.self, forKey: .shuffleSeed))
  }
}

/// Inspectable result artifact. Decoding this artifact never confers Gate B
/// authority; only the live recomputation receipt below can do that.
@frozen
public struct NumanXGateBCausalQualificationArtifact: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let sourceRevision: String
  public let captureRunArtifactSHA256: String
  public let captureTransitiveEvidenceSHA256: String
  public let learningBatchArtifactSHA256: String
  public let learningBatchFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  public let protocolSHA256: String
  public let evaluations: [NumanXGateBPolicyHeadEvaluation]

  public init(sourceRevision: String, captureRunArtifactSHA256: String,
    captureTransitiveEvidenceSHA256: String, learningBatchArtifactSHA256: String,
    learningBatchFingerprint: UInt64, parameterVersionFingerprint: UInt64,
    protocolSHA256: String, evaluations: [NumanXGateBPolicyHeadEvaluation]) throws {
    formatVersion = Self.formatVersion; self.sourceRevision = sourceRevision
    self.captureRunArtifactSHA256 = captureRunArtifactSHA256
    self.captureTransitiveEvidenceSHA256 = captureTransitiveEvidenceSHA256
    self.learningBatchArtifactSHA256 = learningBatchArtifactSHA256
    self.learningBatchFingerprint = learningBatchFingerprint
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.protocolSHA256 = protocolSHA256
    self.evaluations = evaluations.sorted {
      ($0.modality.rawValue, $0.intervention.rawValue) < ($1.modality.rawValue, $1.intervention.rawValue)
    }
    try validate()
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion, !sourceRevision.isEmpty,
      sourceRevision.utf8.count <= 256,
      [captureRunArtifactSHA256, captureTransitiveEvidenceSHA256,
       learningBatchArtifactSHA256, protocolSHA256].allSatisfy(BrainPolicyEvidenceArtifact.isSHA256),
      learningBatchFingerprint > 0, parameterVersionFingerprint > 0,
      !evaluations.isEmpty,
      Set(evaluations.map { "\($0.modality.rawValue):\($0.intervention.rawValue)" }).count == evaluations.count,
      evaluations.allSatisfy({ $0.sourceBatchFingerprint == learningBatchFingerprint
        && $0.parameterVersionFingerprint == parameterVersionFingerprint }) else {
      throw BrainRuntimeError.invalidParameterVersion("Gate B qualification artifact is invalid")
    }
  }

  public func encoded() throws -> Data {
    try validate(); return try BrainPolicyEvidenceArtifact.encodeCanonical(self)
  }
}

/// Verifier-issued in-process authority. It cannot be reconstructed from the
/// inspectable evaluation artifact without rerunning the causal evaluator over
/// the exact immutable captured Metal batch and publication.
public final class MLXGateBCausalQualificationReceipt: @unchecked Sendable {
  public let sourceRevision: String
  public let artifactSHA256: String
  public let protocolSHA256: String
  public let captureRunArtifactSHA256: String
  public let captureTransitiveEvidenceSHA256: String
  public let parameterVersionFingerprint: UInt64
  public let modalityCount: UInt32
  public let minimumTransitionCount: UInt32

  fileprivate init(sourceRevision: String, artifactSHA256: String,
    protocolSHA256: String, captureRunArtifactSHA256: String,
    captureTransitiveEvidenceSHA256: String, parameterVersionFingerprint: UInt64,
    modalityCount: UInt32, minimumTransitionCount: UInt32) {
    self.sourceRevision = sourceRevision; self.artifactSHA256 = artifactSHA256
    self.protocolSHA256 = protocolSHA256
    self.captureRunArtifactSHA256 = captureRunArtifactSHA256
    self.captureTransitiveEvidenceSHA256 = captureTransitiveEvidenceSHA256
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.modalityCount = modalityCount; self.minimumTransitionCount = minimumTransitionCount
  }
}

@available(macOS 26.0, *)
public enum MLXGateBCausalQualification {
  public static func verify(publication: BrainParameterPublication,
    capturedLearningBatch: MetalNumanXCapturedLearningBatch,
    species: SpeciesTemplate, protocol protocolValue: NumanXGateBCausalProtocol,
    sourceRevision: String, captureRunArtifactSHA256: String,
    artifactDirectory: URL) throws -> MLXGateBCausalQualificationReceipt {
    try protocolValue.validate()
    guard !sourceRevision.isEmpty, sourceRevision.utf8.count <= 256 else {
      throw BrainRuntimeError.invalidParameterVersion("Gate B qualification source revision is invalid")
    }
    let captureReceipt = try BrainPolicyNumanXCaptureVerifier.verify(
      runArtifactSHA256: captureRunArtifactSHA256, artifactDirectory: artifactDirectory)
    let run = try BrainPolicyNumanXCaptureRunArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: captureRunArtifactSHA256, directory: artifactDirectory))
    guard run.sourceRevision == sourceRevision,
      run.learningBatchArtifactSHA256 == capturedLearningBatch.artifactSHA256,
      run.learningBatchFingerprint == capturedLearningBatch.batch.batchFingerprint,
      capturedLearningBatch.artifact.batchFingerprint == capturedLearningBatch.batch.batchFingerprint,
      capturedLearningBatch.artifact.parameterVersionFingerprint
        == capturedLearningBatch.batch.parameterVersionFingerprint,
      capturedLearningBatch.batch.speciesTemplateFingerprint == species.fingerprint else {
      throw BrainRuntimeError.invalidParameterVersion("Gate B live batch is not the exact retained native capture")
    }
    let enabledModalities = Set(species.senses.filter(\.enabled).map(\.modality))
    guard Set(protocolValue.modalities).isSubset(of: enabledModalities) else {
      throw BrainRuntimeError.invalidParameterVersion("Gate B protocol names unavailable sensory modalities")
    }
    let evaluator = MLXGateBCausalEvaluator()
    var evaluations: [NumanXGateBPolicyHeadEvaluation] = []
    var minimumCount = UInt32.max
    for modality in protocolValue.modalities {
      let result = try evaluator.evaluate(publication: publication,
        batch: capturedLearningBatch.batch, species: species, modality: modality,
        minimumGeneration: protocolValue.minimumGeneration,
        maximumGeneration: protocolValue.maximumGeneration,
        shuffleSeed: protocolValue.shuffleSeed)
      guard result.count == NumanXGateBInterventionKind.allCases.count,
        Set(result.map(\.intervention)) == Set(NumanXGateBInterventionKind.allCases),
        result.allSatisfy({ $0.modality == modality
          && $0.transitionCount >= protocolValue.minimumTransitionsPerModality }) else {
        throw BrainRuntimeError.invalidParameterVersion("Gate B intervention coverage is incomplete")
      }
      let byKind = Dictionary(uniqueKeysWithValues: result.map { ($0.intervention, $0) })
      guard byKind[.intact]!.actionMeanSquaredError <= protocolValue.maximumIntactActionMSE,
        byKind[.intact]!.actionDeltaFromIntact == 0,
        byKind[.ablated]!.actionDeltaFromIntact >= protocolValue.minimumAblationActionDelta,
        byKind[.valueShuffled]!.actionDeltaFromIntact >= protocolValue.minimumShuffleActionDelta,
        byKind[.timestampShifted]!.actionDeltaFromIntact >= protocolValue.minimumTimestampShiftActionDelta else {
        throw BrainRuntimeError.invalidParameterVersion("Gate B causal intervention thresholds were not met")
      }
      minimumCount = min(minimumCount, result.map(\.transitionCount).min()!)
      evaluations.append(contentsOf: result)
    }
    let protocolBytes = try BrainPolicyEvidenceArtifact.encodeCanonical(protocolValue)
    let protocolSHA = BrainPolicyEvidenceArtifact.sha256(protocolBytes)
    let artifact = try NumanXGateBCausalQualificationArtifact(sourceRevision: sourceRevision,
      captureRunArtifactSHA256: captureRunArtifactSHA256,
      captureTransitiveEvidenceSHA256: captureReceipt.transitiveEvidenceSHA256,
      learningBatchArtifactSHA256: capturedLearningBatch.artifactSHA256,
      learningBatchFingerprint: capturedLearningBatch.batch.batchFingerprint,
      parameterVersionFingerprint: publication.version.fingerprint,
      protocolSHA256: protocolSHA, evaluations: evaluations)
    let artifactSHA = try BrainPolicyEvidenceArtifact.write(artifact.encoded(), to: artifactDirectory)
    return MLXGateBCausalQualificationReceipt(sourceRevision: sourceRevision,
      artifactSHA256: artifactSHA, protocolSHA256: protocolSHA,
      captureRunArtifactSHA256: captureRunArtifactSHA256,
      captureTransitiveEvidenceSHA256: captureReceipt.transitiveEvidenceSHA256,
      parameterVersionFingerprint: publication.version.fingerprint,
      modalityCount: UInt32(protocolValue.modalities.count),
      minimumTransitionCount: minimumCount)
  }
}

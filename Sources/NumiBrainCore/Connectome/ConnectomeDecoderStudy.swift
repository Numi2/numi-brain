import Foundation

/// Frozen, bounded paired-direction experiment. Coordinates index actuator-major
/// decoder weights followed by decoder biases. The neural graph stays frozen.
public struct ConnectomeDecoderStudySettings: Codable, Equatable, Sendable {
  public let coordinates: [Int]
  public let directionSeed: UInt64
  public let probeRadius: Float
  public let learningRate: Float
  public let gradientLimit: Float
  public let trustRadius: Float
  public let magnitudeLimit: Float
  public let minimumResolvableLossDifference: Double

  public init(coordinates: [Int], directionSeed: UInt64, probeRadius: Float,
    learningRate: Float, gradientLimit: Float, trustRadius: Float,
    magnitudeLimit: Float, minimumResolvableLossDifference: Double) throws {
    self.coordinates = coordinates; self.directionSeed = directionSeed; self.probeRadius = probeRadius
    self.learningRate = learningRate; self.gradientLimit = gradientLimit; self.trustRadius = trustRadius
    self.magnitudeLimit = magnitudeLimit; self.minimumResolvableLossDifference = minimumResolvableLossDifference
    try validate()
  }

  public func validate(parameterCount: Int = 1_052_672) throws {
    guard parameterCount > 0, parameterCount <= 1_052_672,
      !coordinates.isEmpty, coordinates.count <= 65_536,
      coordinates == coordinates.sorted(), Set(coordinates).count == coordinates.count,
      coordinates.allSatisfy({ $0 >= 0 && $0 < parameterCount }), directionSeed != 0,
      [probeRadius, learningRate, gradientLimit, trustRadius, magnitudeLimit].allSatisfy({ $0.isFinite && $0 > 0 }),
      probeRadius <= 0.25, learningRate <= 1, gradientLimit <= 1_000_000,
      trustRadius <= 0.25, magnitudeLimit <= 16,
      minimumResolvableLossDifference.isFinite, minimumResolvableLossDifference > 0 else {
      throw ConnectomeError.invalid("decoder study indices, seed or numerical bounds are invalid")
    }
  }

  /// Counter-derived signs are stable across processes and contain no runtime
  /// random stream. This is experiment design, not neural activity simulation.
  public func directions() throws -> [Float] {
    try validate()
    return coordinates.map { coordinate in
      var x = directionSeed &+ UInt64(coordinate) &* 0x9e3779b97f4a7c15
      x = (x ^ (x >> 30)) &* 0xbf58476d1ce4e5b9
      x = (x ^ (x >> 27)) &* 0x94d049bb133111eb
      return ((x ^ (x >> 31)) & 1) == 0 ? -1 : 1
    }
  }

  public var sha256: String {
    get throws { BrainPolicyEvidenceArtifact.sha256(try BrainPolicyEvidenceArtifact.encodeCanonical(self)) }
  }
}

/// Probes are distinct immutable specifications, not mutations of a live mind.
/// Both runs must use the predeclared physical protocol and shared publication.
public struct ConnectomeDecoderProbePlan: Codable, Equatable, Sendable {
  public let version: UInt32
  public let promotable: Bool
  public let parentRunSHA256: String
  public let protocolSHA256: String
  public let parentController: ConnectomeCaptureIdentity
  public let settings: ConnectomeDecoderStudySettings
  public let negativeSpecificationSHA256: String
  public let positiveSpecificationSHA256: String

  public init(parentRunSHA256: String, protocolSHA256: String,
    parentController: ConnectomeCaptureIdentity, settings: ConnectomeDecoderStudySettings,
    negativeSpecificationSHA256: String, positiveSpecificationSHA256: String) throws {
    version = 1; promotable = false; self.parentRunSHA256 = parentRunSHA256
    self.protocolSHA256 = protocolSHA256; self.parentController = parentController; self.settings = settings
    self.negativeSpecificationSHA256 = negativeSpecificationSHA256
    self.positiveSpecificationSHA256 = positiveSpecificationSHA256
    try validate()
  }

  public func validate() throws {
    try settings.validate(); try parentController.validate()
    guard version == 1, !promotable,
      [parentRunSHA256, protocolSHA256, negativeSpecificationSHA256, positiveSpecificationSHA256]
        .allSatisfy(BrainPolicyEvidenceArtifact.isSHA256),
      negativeSpecificationSHA256 != positiveSpecificationSHA256,
      negativeSpecificationSHA256 != parentController.specificationSHA256,
      positiveSpecificationSHA256 != parentController.specificationSHA256 else {
      throw ConnectomeError.invalid("decoder probe plan has invalid identity or indistinguishable probes")
    }
  }
}

/// A proposed decoder and the physical evidence used to calculate it. This is
/// not accepted improvement: the candidate still needs its own physical runs.
public struct ConnectomeDecoderProposal: Codable, Sendable {
  public let version: UInt32
  public let promotable: Bool
  public let probePlanSHA256: String
  public let negativeEvaluationSHA256: String
  public let positiveEvaluationSHA256: String
  public let candidateSpecificationSHA256: String
  public let candidateProgramFingerprint: UInt64
  public let negativeLoss: Double
  public let positiveLoss: Double

  public init(probePlanSHA256: String, negativeEvaluationSHA256: String,
    positiveEvaluationSHA256: String, candidateSpecificationSHA256: String,
    candidateProgramFingerprint: UInt64, negativeLoss: Double, positiveLoss: Double) throws {
    version = 1; promotable = false; self.probePlanSHA256 = probePlanSHA256
    self.negativeEvaluationSHA256 = negativeEvaluationSHA256; self.positiveEvaluationSHA256 = positiveEvaluationSHA256
    self.candidateSpecificationSHA256 = candidateSpecificationSHA256
    self.candidateProgramFingerprint = candidateProgramFingerprint
    self.negativeLoss = negativeLoss; self.positiveLoss = positiveLoss
    try validate()
  }

  public func validate() throws {
    guard version == 1, !promotable, candidateProgramFingerprint != 0,
      [probePlanSHA256, negativeEvaluationSHA256, positiveEvaluationSHA256, candidateSpecificationSHA256]
        .allSatisfy(BrainPolicyEvidenceArtifact.isSHA256),
      negativeEvaluationSHA256 != positiveEvaluationSHA256,
      negativeLoss.isFinite, positiveLoss.isFinite else {
      throw ConnectomeError.invalid("invalid decoder proposal; it cannot confer runtime admission")
    }
  }
}

extension ConnectomeControllerSpec {
  public var decoderParameters: [Float] { decoderWeights + decoderBiases }

  /// Encoding utility, not validation or publication. Recompile the result
  /// through ConnectomeControllerProgram before using it in a rollout.
  public func replacingDecoderParameters(_ parameters: [Float]) throws -> Self {
    guard parameters.count == decoderWeights.count + decoderBiases.count,
      parameters.allSatisfy(\.isFinite) else {
      throw ConnectomeError.invalid("replacement decoder changed dimensions or contains non-finite values")
    }
    return Self(graphFingerprint: graphFingerprint, speciesFingerprint: speciesFingerprint,
      sensoryProfileFingerprint: sensoryProfileFingerprint, nominalStepMicroseconds: nominalStepMicroseconds,
      integrationStepMicroseconds: integrationStepMicroseconds, channelCount: channelCount,
      receptors: receptors, descending: descending,
      decoderWeights: Array(parameters.prefix(decoderWeights.count)),
      decoderBiases: Array(parameters.dropFirst(decoderWeights.count)), maximumLogit: maximumLogit)
  }
}

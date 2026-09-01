import Foundation

@frozen
public struct BrainPolicyNumanXSupportStabilityThresholds:
  Codable, Equatable, Sendable
{
  public static let gateCCrossSceneV1 = try! Self(
    minimumHeadGroundClearance: 1.4,
    maximumHeadGroundClearance: 2.0,
    maximumAbsoluteGroundNormalVelocity: 0.5,
    maximumHeadQuaternionNormError: 0.01
  )

  /// Predeclared short-horizon adaptation target. The tighter ground-normal
  /// velocity budget makes the adapted task discriminative before a root can
  /// accumulate into the broader cross-scene failure envelope.
  public static let gateCFewShotSupportV1 = try! Self(
    minimumHeadGroundClearance: 1.4,
    maximumHeadGroundClearance: 2.0,
    maximumAbsoluteGroundNormalVelocity: 0.01,
    maximumHeadQuaternionNormError: 0.01
  )

  public let minimumHeadGroundClearance: Float
  public let maximumHeadGroundClearance: Float
  public let maximumAbsoluteGroundNormalVelocity: Float
  public let maximumHeadQuaternionNormError: Float

  public init(
    minimumHeadGroundClearance: Float,
    maximumHeadGroundClearance: Float,
    maximumAbsoluteGroundNormalVelocity: Float,
    maximumHeadQuaternionNormError: Float
  ) throws {
    guard minimumHeadGroundClearance.isFinite,
      maximumHeadGroundClearance.isFinite,
      minimumHeadGroundClearance > 0,
      maximumHeadGroundClearance > minimumHeadGroundClearance,
      maximumAbsoluteGroundNormalVelocity.isFinite,
      maximumAbsoluteGroundNormalVelocity > 0,
      maximumHeadQuaternionNormError.isFinite,
      maximumHeadQuaternionNormError > 0
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-stability thresholds are invalid"
      )
    }
    self.minimumHeadGroundClearance = minimumHeadGroundClearance
    self.maximumHeadGroundClearance = maximumHeadGroundClearance
    self.maximumAbsoluteGroundNormalVelocity =
      maximumAbsoluteGroundNormalVelocity
    self.maximumHeadQuaternionNormError = maximumHeadQuaternionNormError
  }
}

@frozen
public struct BrainPolicyNumanXSupportStabilityObservation:
  Codable, Equatable, Sendable
{
  public let sampleSHA256: String
  public let controlStep: UInt32
  public let rootOutcome: BrainPolicyNumanXRootOutcome
  public let vestibularValidityMask: UInt32
  public let headGroundClearance: Float
  public let groundNormalVelocity: Float
  public let headQuaternionNormError: Float
  public let success: Bool

  public init(
    sampleSHA256: String,
    controlStep: UInt32,
    rootOutcome: BrainPolicyNumanXRootOutcome,
    vestibularValidityMask: UInt32,
    headGroundClearance: Float,
    groundNormalVelocity: Float,
    headQuaternionNormError: Float,
    thresholds: BrainPolicyNumanXSupportStabilityThresholds
  ) throws {
    guard BrainPolicyEvidenceArtifact.isSHA256(sampleSHA256), controlStep > 1,
      headGroundClearance.isFinite, groundNormalVelocity.isFinite,
      headQuaternionNormError.isFinite, headQuaternionNormError >= 0
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-stability observation is invalid"
      )
    }
    self.sampleSHA256 = sampleSHA256
    self.controlStep = controlStep
    self.rootOutcome = rootOutcome
    self.vestibularValidityMask = vestibularValidityMask
    self.headGroundClearance = headGroundClearance
    self.groundNormalVelocity = groundNormalVelocity
    self.headQuaternionNormError = headQuaternionNormError
    self.success = rootOutcome == .accepted
      && vestibularValidityMask == (UInt32(1) << 22) - 1
      && headGroundClearance >= thresholds.minimumHeadGroundClearance
      && headGroundClearance <= thresholds.maximumHeadGroundClearance
      && abs(groundNormalVelocity)
        <= thresholds.maximumAbsoluteGroundNormalVelocity
      && headQuaternionNormError
        <= thresholds.maximumHeadQuaternionNormError
  }
}

/// One retained paired cross-scene evaluation. It deliberately remains
/// non-promotable: this is one Gate C axis, not a complete policy package.
@frozen
public struct BrainPolicyNumanXSupportStabilityEvaluationArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let candidateArtifactSHA256: String
  public let contactVariantArtifactSHA256: String
  public let baselineRunArtifactSHA256: String
  public let learnedRunArtifactSHA256: String
  public let axis: BrainPolicyQualificationAxis
  public let thresholds: BrainPolicyNumanXSupportStabilityThresholds
  public let baselineObservations: [BrainPolicyNumanXSupportStabilityObservation]
  public let learnedObservations: [BrainPolicyNumanXSupportStabilityObservation]
  public let baselineSuccessRate: Double
  public let learnedSuccessRate: Double
  public let learnedMinusBaselineSuccessRate: Double
  public let promotable: Bool

  public init(
    candidateArtifactSHA256: String,
    contactVariantArtifactSHA256: String,
    baselineRunArtifactSHA256: String,
    learnedRunArtifactSHA256: String,
    thresholds: BrainPolicyNumanXSupportStabilityThresholds,
    baselineObservations: [BrainPolicyNumanXSupportStabilityObservation],
    learnedObservations: [BrainPolicyNumanXSupportStabilityObservation]
  ) throws {
    let baseline = baselineObservations.sorted { $0.controlStep < $1.controlStep }
    let learned = learnedObservations.sorted { $0.controlStep < $1.controlStep }
    guard BrainPolicyEvidenceArtifact.isSHA256(candidateArtifactSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(contactVariantArtifactSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(baselineRunArtifactSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(learnedRunArtifactSHA256),
      baselineRunArtifactSHA256 != learnedRunArtifactSHA256,
      !baseline.isEmpty, !learned.isEmpty,
      baseline.map(\.controlStep)
        == Array(UInt32(2)...UInt32(baseline.count + 1)),
      learned.map(\.controlStep)
        == Array(UInt32(2)...UInt32(learned.count + 1)),
      Set(baseline.map(\.sampleSHA256)).count == baseline.count,
      Set(learned.map(\.sampleSHA256)).count == learned.count
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-stability evaluation artifact is invalid"
      )
    }
    let baselineRate = Double(baseline.filter(\.success).count)
      / Double(baseline.count)
    let learnedRate = Double(learned.filter(\.success).count)
      / Double(learned.count)
    self.formatVersion = Self.formatVersion
    self.candidateArtifactSHA256 = candidateArtifactSHA256
    self.contactVariantArtifactSHA256 = contactVariantArtifactSHA256
    self.baselineRunArtifactSHA256 = baselineRunArtifactSHA256
    self.learnedRunArtifactSHA256 = learnedRunArtifactSHA256
    self.axis = .crossScene
    self.thresholds = thresholds
    self.baselineObservations = baseline
    self.learnedObservations = learned
    self.baselineSuccessRate = baselineRate
    self.learnedSuccessRate = learnedRate
    self.learnedMinusBaselineSuccessRate = learnedRate - baselineRate
    self.promotable = false
  }

  public var learnedSuccessMetricEvidence: BrainPolicyQualificationMetricEvidence {
    get throws {
      try BrainPolicyQualificationMetricEvidence(
        identifier: "success_rate",
        unit: "ratio",
        reducer: .mean,
        threshold: 0.7,
        direction: .atLeast,
        observations: try learnedObservations.map {
          try BrainPolicyMetricObservation(
            sampleSHA256: $0.sampleSHA256,
            value: $0.success ? 1 : 0
          )
        }
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
    let artifact = try JSONDecoder().decode(Self.self, from: data)
    try artifact.validate()
    return artifact
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion, axis == .crossScene, !promotable,
      try Self(
        candidateArtifactSHA256: candidateArtifactSHA256,
        contactVariantArtifactSHA256: contactVariantArtifactSHA256,
        baselineRunArtifactSHA256: baselineRunArtifactSHA256,
        learnedRunArtifactSHA256: learnedRunArtifactSHA256,
        thresholds: thresholds,
        baselineObservations: baselineObservations,
        learnedObservations: learnedObservations
      ) == self,
      try learnedSuccessMetricEvidence.reducedValue == learnedSuccessRate
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-stability evaluation artifact is not canonical"
      )
    }
  }
}

public struct BrainPolicyNumanXSupportStabilityEvaluationReceipt: Sendable {
  public let evaluationArtifactSHA256: String
  public let candidateArtifactSHA256: String
  public let contactVariantArtifactSHA256: String
  public let contactVariantAssetSHA256: String
  public let baselineRunArtifactSHA256: String
  public let learnedRunArtifactSHA256: String
  public let baselineObservationCount: UInt64
  public let learnedObservationCount: UInt64
  public let observationCount: UInt64
  public let baselineSuccessRate: Double
  public let learnedSuccessRate: Double
  public let transitiveEvidenceSHA256: String
}

public enum BrainPolicyNumanXSupportStabilityEvaluator {
  public static func verify(
    evaluationArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXSupportStabilityEvaluationReceipt {
    let stored = try BrainPolicyNumanXSupportStabilityEvaluationArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: evaluationArtifactSHA256,
        directory: artifactDirectory
      )
    )
    let receipt = try evaluate(
      candidateArtifactSHA256: stored.candidateArtifactSHA256,
      contactVariantArtifactSHA256: stored.contactVariantArtifactSHA256,
      baselineRunArtifactSHA256: stored.baselineRunArtifactSHA256,
      learnedRunArtifactSHA256: stored.learnedRunArtifactSHA256,
      artifactDirectory: artifactDirectory,
      thresholds: stored.thresholds,
      writeArtifact: false
    )
    guard receipt.evaluationArtifactSHA256 == evaluationArtifactSHA256 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-stability evaluation does not recompute byte-identically"
      )
    }
    return receipt
  }

  public static func evaluateAndWrite(
    candidateArtifactSHA256: String,
    contactVariantArtifactSHA256: String,
    baselineRunArtifactSHA256: String,
    learnedRunArtifactSHA256: String,
    artifactDirectory: URL,
    thresholds: BrainPolicyNumanXSupportStabilityThresholds =
      .gateCCrossSceneV1
  ) throws -> BrainPolicyNumanXSupportStabilityEvaluationReceipt {
    try evaluate(
      candidateArtifactSHA256: candidateArtifactSHA256,
      contactVariantArtifactSHA256: contactVariantArtifactSHA256,
      baselineRunArtifactSHA256: baselineRunArtifactSHA256,
      learnedRunArtifactSHA256: learnedRunArtifactSHA256,
      artifactDirectory: artifactDirectory,
      thresholds: thresholds,
      writeArtifact: true
    )
  }

  private static func evaluate(
    candidateArtifactSHA256: String,
    contactVariantArtifactSHA256: String,
    baselineRunArtifactSHA256: String,
    learnedRunArtifactSHA256: String,
    artifactDirectory: URL,
    thresholds: BrainPolicyNumanXSupportStabilityThresholds,
    writeArtifact: Bool
  ) throws -> BrainPolicyNumanXSupportStabilityEvaluationReceipt {
    let candidate = try BrainPolicyNumanXLearnedCandidateArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: candidateArtifactSHA256,
        directory: artifactDirectory
      )
    )
    _ = try BrainPolicyNumanXLearnedCandidateVerifier.verify(
      candidateArtifactSHA256: candidateArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let contact = try BrainPolicyNumanXSupportContactVariant.verify(
      artifactSHA256: contactVariantArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let trainingRun = try run(
      candidate.captureRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let baselineRun = try run(
      baselineRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let learnedRun = try run(
      learnedRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    _ = try BrainPolicyNumanXCaptureVerifier.verify(
      runArtifactSHA256: baselineRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    _ = try BrainPolicyNumanXCaptureVerifier.verify(
      runArtifactSHA256: learnedRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let learnedPublication = try candidate.publication
    guard baselineRun.parameterVersionFingerprint == candidate.parentVersion.fingerprint,
      learnedRun.parameterVersionFingerprint == learnedPublication.version.fingerprint,
      baselineRun.datasetSourceRevision == contactVariantArtifactSHA256,
      learnedRun.datasetSourceRevision == contactVariantArtifactSHA256,
      baselineRun.nativeModelSourceFingerprint
        == learnedRun.nativeModelSourceFingerprint,
      baselineRun.acceptedStateProofProgramFingerprint
        == learnedRun.acceptedStateProofProgramFingerprint,
      baselineRun.compiledSpeciesTemplateFingerprint
        == learnedRun.compiledSpeciesTemplateFingerprint,
      trainingRun.timestepMicroseconds != nil,
      trainingRun.timestepMicroseconds == baselineRun.timestepMicroseconds,
      baselineRun.timestepMicroseconds == learnedRun.timestepMicroseconds
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-stability runs do not bind the candidate and contact variant"
      )
    }
    let trainingCoordinates = try canonicalCoordinates(
      trainingRun,
      artifactDirectory: artifactDirectory
    )
    let baselineCoordinates = try canonicalCoordinates(
      baselineRun,
      artifactDirectory: artifactDirectory
    )
    let learnedCoordinates = try canonicalCoordinates(
      learnedRun,
      artifactDirectory: artifactDirectory
    )
    guard baselineCoordinates.taskFingerprint == learnedCoordinates.taskFingerprint,
      baselineCoordinates.sceneFingerprint == learnedCoordinates.sceneFingerprint,
      baselineCoordinates.objectFingerprint == learnedCoordinates.objectFingerprint,
      baselineCoordinates.embodimentFingerprint
        == learnedCoordinates.embodimentFingerprint,
      baselineCoordinates.taskFingerprint == trainingCoordinates.taskFingerprint,
      baselineCoordinates.sceneFingerprint != trainingCoordinates.sceneFingerprint,
      baselineCoordinates.objectFingerprint == trainingCoordinates.objectFingerprint,
      baselineCoordinates.embodimentFingerprint
        == trainingCoordinates.embodimentFingerprint
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX support-stability evaluation is not an exact cross-scene split"
      )
    }
    let baseline = try observations(
      baselineRun,
      thresholds: thresholds,
      artifactDirectory: artifactDirectory
    )
    let learned = try observations(
      learnedRun,
      thresholds: thresholds,
      artifactDirectory: artifactDirectory
    )
    let artifact = try BrainPolicyNumanXSupportStabilityEvaluationArtifact(
      candidateArtifactSHA256: candidateArtifactSHA256,
      contactVariantArtifactSHA256: contactVariantArtifactSHA256,
      baselineRunArtifactSHA256: baselineRunArtifactSHA256,
      learnedRunArtifactSHA256: learnedRunArtifactSHA256,
      thresholds: thresholds,
      baselineObservations: baseline,
      learnedObservations: learned
    )
    let artifactHash = if writeArtifact {
      try artifact.write(to: artifactDirectory)
    } else {
      BrainPolicyEvidenceArtifact.sha256(try artifact.encoded())
    }
    var transitive = Data()
    for hash in [
      artifactHash, candidateArtifactSHA256, contactVariantArtifactSHA256,
      contact.sourceAssetSHA256, contact.variantAssetSHA256,
      baselineRunArtifactSHA256, learnedRunArtifactSHA256,
    ].sorted() {
      transitive.append(Data(hash.utf8))
    }
    return BrainPolicyNumanXSupportStabilityEvaluationReceipt(
      evaluationArtifactSHA256: artifactHash,
      candidateArtifactSHA256: candidateArtifactSHA256,
      contactVariantArtifactSHA256: contactVariantArtifactSHA256,
      contactVariantAssetSHA256: contact.variantAssetSHA256,
      baselineRunArtifactSHA256: baselineRunArtifactSHA256,
      learnedRunArtifactSHA256: learnedRunArtifactSHA256,
      baselineObservationCount: UInt64(baseline.count),
      learnedObservationCount: UInt64(learned.count),
      observationCount: UInt64(learned.count),
      baselineSuccessRate: artifact.baselineSuccessRate,
      learnedSuccessRate: artifact.learnedSuccessRate,
      transitiveEvidenceSHA256: BrainPolicyEvidenceArtifact.sha256(transitive)
    )
  }

  static func run(
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

  static func canonicalCoordinates(
    _ run: BrainPolicyNumanXCaptureRunArtifact,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXDatasetCoordinates {
    let coordinates = try run.roots.map { root in
      try BrainPolicyNumanXRootSampleArtifact.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(
          sha256: root.sampleSHA256,
          directory: artifactDirectory
        )
      ).coordinates
    }
    guard let first = coordinates.first,
      coordinates.allSatisfy({ coordinates in
        coordinates.taskFingerprint == first.taskFingerprint
          && coordinates.sceneFingerprint == first.sceneFingerprint
          && coordinates.objectFingerprint == first.objectFingerprint
          && coordinates.embodimentFingerprint == first.embodimentFingerprint
      })
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX capture run changes dataset coordinates within one cohort"
      )
    }
    return first
  }

  static func observations(
    _ run: BrainPolicyNumanXCaptureRunArtifact,
    thresholds: BrainPolicyNumanXSupportStabilityThresholds,
    artifactDirectory: URL
  ) throws -> [BrainPolicyNumanXSupportStabilityObservation] {
    try run.roots.filter { $0.controlStep > 1 }.map { root in
      let sample = try BrainPolicyNumanXRootSampleArtifact.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(
          sha256: root.sampleSHA256,
          directory: artifactDirectory
        )
      )
      let execution = try BrainPolicyNumanXRootExecution.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(
          sha256: root.executionSHA256,
          directory: artifactDirectory
        )
      )
      guard let vestibular = sample.channels.first(where: {
        $0.modality == .vestibular
      }), vestibular.receptorCount == 1, vestibular.featureDimension == 22,
        let validityHash = vestibular.validitySHA256
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX support-stability sample lacks exact vestibular evidence"
        )
      }
      let values = try BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: vestibular.valuesSHA256,
        directory: artifactDirectory
      )
      let validity = try BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: validityHash,
        directory: artifactDirectory
      )
      guard values.count == 22 * MemoryLayout<Float>.stride,
        validity.count == MemoryLayout<UInt32>.stride
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX support-stability vestibular evidence has the wrong shape"
        )
      }
      func float(_ index: Int) -> Float {
        values.withUnsafeBytes { raw in
          let bits = raw.loadUnaligned(
            fromByteOffset: index * MemoryLayout<UInt32>.stride,
            as: UInt32.self
          )
          return Float(bitPattern: UInt32(littleEndian: bits))
        }
      }
      let quaternion = (16...19).map(float)
      let norm = sqrt(quaternion.reduce(0) { $0 + $1 * $1 })
      let mask = validity.withUnsafeBytes {
        UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self))
      }
      return try BrainPolicyNumanXSupportStabilityObservation(
        sampleSHA256: root.sampleSHA256,
        controlStep: root.controlStep,
        rootOutcome: execution.outcome,
        vestibularValidityMask: mask,
        headGroundClearance: float(20),
        groundNormalVelocity: float(21),
        headQuaternionNormError: abs(norm - 1),
        thresholds: thresholds
      )
    }
  }
}

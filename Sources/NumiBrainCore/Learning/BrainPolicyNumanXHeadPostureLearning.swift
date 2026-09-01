import Foundation

/// Immutable, off-rollout physical supervision for the head-posture task.
/// The response is reconstructed from accepted receptor/action artifacts; it
/// never observes or mutates authoritative NumanX state.
@frozen
public struct BrainPolicyNumanXHeadPostureLearningArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1
  public static let objectiveIdentifier =
    "numibrain.numanx.head-posture-response.v1"
  public static let minimumRelativeHeadLiftMeters: Float = 1.0e-6
  public static let responseScaleMeters: Float = 1.0e-4

  public let formatVersion: UInt32
  public let objectiveIdentifier: String
  public let sourceRunArtifactSHA256: String
  public let taskFingerprint: UInt64
  public let sceneFingerprint: UInt64
  public let objectFingerprint: UInt64
  public let embodimentFingerprint: UInt64
  public let timestepMicroseconds: UInt32
  public let targetBodyIdentifier: UInt32
  public let objectiveWeight: Float
  public let minimumRelativeHeadLiftMeters: Float
  public let responseScaleMeters: Float
  public let observation: BrainPolicyNumanXHeadPostureObservation
  public let responseDeficit: Float
  /// Optional causal calibration from a completed exploratory candidate.
  /// Absence preserves the original positive-gain probe. A calibrated
  /// artifact records the measured response sign explicitly so MLX never
  /// guesses the plant-gradient direction from a task-space deficit alone.
  public let calibrationEvaluationArtifactSHA256: String?
  public let responseGainDirection: Float?
  public let objectiveFingerprint: UInt64

  public var effectiveResponseGainDirection: Float {
    responseGainDirection ?? 1
  }

  public init(
    sourceRunArtifactSHA256: String,
    coordinates: BrainPolicyNumanXDatasetCoordinates,
    timestepMicroseconds: UInt32,
    objectiveWeight: Float,
    observation: BrainPolicyNumanXHeadPostureObservation,
    calibrationEvaluationArtifactSHA256: String? = nil,
    responseGainDirection: Float? = nil
  ) throws {
    let deficit = min(max(
      (Self.minimumRelativeHeadLiftMeters
        - observation.relativeHeadLiftMeters) / Self.responseScaleMeters,
      0
    ), 1)
    guard BrainPolicyEvidenceArtifact.isSHA256(sourceRunArtifactSHA256),
      observation.runArtifactSHA256 == sourceRunArtifactSHA256,
      coordinates.taskFingerprint > 0, coordinates.sceneFingerprint > 0,
      coordinates.objectFingerprint > 0,
      coordinates.embodimentFingerprint > 0,
      timestepMicroseconds > 0,
      objectiveWeight.isFinite, objectiveWeight > 0,
      deficit.isFinite, deficit > 0,
      (calibrationEvaluationArtifactSHA256 == nil
        && responseGainDirection == nil)
        || (calibrationEvaluationArtifactSHA256.map(
          BrainPolicyEvidenceArtifact.isSHA256
        ) == true && (responseGainDirection == -1 || responseGainDirection == 1))
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture learning artifact is invalid"
      )
    }
    var fingerprint: UInt64 = 14_695_981_039_346_656_037
    Self.mix(UInt64(Self.formatVersion), into: &fingerprint)
    Self.mix(Self.objectiveIdentifier, into: &fingerprint)
    Self.mix(sourceRunArtifactSHA256, into: &fingerprint)
    for value in [
      coordinates.taskFingerprint, coordinates.sceneFingerprint,
      coordinates.objectFingerprint, coordinates.embodimentFingerprint,
      UInt64(timestepMicroseconds),
      UInt64(BrainPolicyNumanXHeadPostureEvaluationArtifact
        .targetBodyIdentifier),
      UInt64(objectiveWeight.bitPattern),
      UInt64(Self.minimumRelativeHeadLiftMeters.bitPattern),
      UInt64(Self.responseScaleMeters.bitPattern),
      UInt64(observation.rootCount),
      UInt64(observation.initialControlStep),
      UInt64(observation.terminalControlStep),
      UInt64(observation.initialRelativeHeadHeightMeters.bitPattern),
      UInt64(observation.terminalRelativeHeadHeightMeters.bitPattern),
      UInt64(observation.relativeHeadLiftMeters.bitPattern),
      UInt64(observation.meanActuatorCommand.bitPattern),
      UInt64(observation.peakActuatorCommand.bitPattern),
      UInt64(deficit.bitPattern),
    ] {
      Self.mix(value, into: &fingerprint)
    }
    Self.mix(observation.initialSampleSHA256, into: &fingerprint)
    Self.mix(observation.terminalSampleSHA256, into: &fingerprint)
    if let calibrationEvaluationArtifactSHA256, let responseGainDirection {
      Self.mix(calibrationEvaluationArtifactSHA256, into: &fingerprint)
      Self.mix(UInt64(responseGainDirection.bitPattern), into: &fingerprint)
    }
    guard fingerprint > 0 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture objective fingerprint is zero"
      )
    }
    formatVersion = Self.formatVersion
    objectiveIdentifier = Self.objectiveIdentifier
    self.sourceRunArtifactSHA256 = sourceRunArtifactSHA256
    taskFingerprint = coordinates.taskFingerprint
    sceneFingerprint = coordinates.sceneFingerprint
    objectFingerprint = coordinates.objectFingerprint
    embodimentFingerprint = coordinates.embodimentFingerprint
    self.timestepMicroseconds = timestepMicroseconds
    targetBodyIdentifier = BrainPolicyNumanXHeadPostureEvaluationArtifact
      .targetBodyIdentifier
    self.objectiveWeight = objectiveWeight
    minimumRelativeHeadLiftMeters = Self.minimumRelativeHeadLiftMeters
    responseScaleMeters = Self.responseScaleMeters
    self.observation = observation
    responseDeficit = deficit
    self.calibrationEvaluationArtifactSHA256 =
      calibrationEvaluationArtifactSHA256
    self.responseGainDirection = responseGainDirection
    objectiveFingerprint = fingerprint
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
    let coordinates = try BrainPolicyNumanXDatasetCoordinates(
      datasetSourceIdentifier: "head-posture-validation",
      datasetSourceRevision: sourceRunArtifactSHA256,
      episodeIdentifier: 1,
      taskFingerprint: taskFingerprint,
      sceneFingerprint: sceneFingerprint,
      objectFingerprint: objectFingerprint,
      embodimentFingerprint: embodimentFingerprint
    )
    guard formatVersion == Self.formatVersion,
      objectiveIdentifier == Self.objectiveIdentifier,
      targetBodyIdentifier
        == BrainPolicyNumanXHeadPostureEvaluationArtifact
          .targetBodyIdentifier,
      minimumRelativeHeadLiftMeters == Self.minimumRelativeHeadLiftMeters,
      responseScaleMeters == Self.responseScaleMeters,
      try Self(
        sourceRunArtifactSHA256: sourceRunArtifactSHA256,
        coordinates: coordinates,
        timestepMicroseconds: timestepMicroseconds,
        objectiveWeight: objectiveWeight,
        observation: observation,
        calibrationEvaluationArtifactSHA256:
          calibrationEvaluationArtifactSHA256,
        responseGainDirection: responseGainDirection
      ).objectiveFingerprint == objectiveFingerprint
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture learning artifact is not canonical"
      )
    }
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    var value = value.littleEndian
    withUnsafeBytes(of: &value) { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }

  private static func mix(_ value: String, into hash: inout UInt64) {
    for byte in value.utf8 {
      hash ^= UInt64(byte)
      hash &*= 1_099_511_628_211
    }
  }
}

public enum BrainPolicyNumanXHeadPostureLearningBuilder {
  public static func build(
    sourceRunArtifactSHA256: String,
    artifactDirectory: URL,
    objectiveWeight: Float,
    calibrationEvaluationArtifactSHA256: String? = nil
  ) throws -> BrainPolicyNumanXHeadPostureLearningArtifact {
    try build(
      sourceRunArtifactSHA256: sourceRunArtifactSHA256,
      artifactDirectory: artifactDirectory,
      objectiveWeight: objectiveWeight,
      calibrationEvaluationArtifactSHA256:
        calibrationEvaluationArtifactSHA256,
      sourceRunAlreadyVerified: false
    )
  }

  /// Recomputes supervision while reusing the exact source-run receipt that
  /// the learned-candidate verifier established immediately before this call.
  /// This is internal so ordinary callers cannot bypass run verification.
  static func buildFromVerifiedSourceRun(
    sourceRunArtifactSHA256: String,
    artifactDirectory: URL,
    objectiveWeight: Float,
    calibrationEvaluationArtifactSHA256: String? = nil
  ) throws -> BrainPolicyNumanXHeadPostureLearningArtifact {
    try build(
      sourceRunArtifactSHA256: sourceRunArtifactSHA256,
      artifactDirectory: artifactDirectory,
      objectiveWeight: objectiveWeight,
      calibrationEvaluationArtifactSHA256:
        calibrationEvaluationArtifactSHA256,
      sourceRunAlreadyVerified: true
    )
  }

  private static func build(
    sourceRunArtifactSHA256: String,
    artifactDirectory: URL,
    objectiveWeight: Float,
    calibrationEvaluationArtifactSHA256: String?,
    sourceRunAlreadyVerified: Bool
  ) throws -> BrainPolicyNumanXHeadPostureLearningArtifact {
    if !sourceRunAlreadyVerified {
      _ = try BrainPolicyNumanXCaptureVerifier.verify(
        runArtifactSHA256: sourceRunArtifactSHA256,
        artifactDirectory: artifactDirectory
      )
    }
    let run = try BrainPolicyNumanXCaptureRunArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: sourceRunArtifactSHA256,
        directory: artifactDirectory
      )
    )
    guard let timestepMicroseconds = run.timestepMicroseconds else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture learning run lacks an exact timestep"
      )
    }
    let coordinates = try BrainPolicyNumanXHeadPostureEvaluator.coordinates(
      run, directory: artifactDirectory
    )
    let observation = try BrainPolicyNumanXHeadPostureEvaluator.observation(
      sourceRunArtifactSHA256,
      run: run,
      directory: artifactDirectory
    )
    let responseGainDirection: Float?
    if let calibrationEvaluationArtifactSHA256 {
      let calibrationReceipt = try BrainPolicyNumanXHeadPostureEvaluator.verify(
        evaluationArtifactSHA256: calibrationEvaluationArtifactSHA256,
        artifactDirectory: artifactDirectory
      )
      let calibration = try BrainPolicyNumanXHeadPostureEvaluationArtifact
        .decode(BrainPolicyNumanXCaptureVerifier.verifiedData(
          sha256: calibrationEvaluationArtifactSHA256,
          directory: artifactDirectory
        ))
      // The evaluator receipt above already transitively verified this exact
      // candidate and all three physical runs. Decode the hash-exact manifest
      // here instead of repeating the complete verification graph.
      guard calibrationReceipt.candidateArtifactSHA256
          == calibration.candidateArtifactSHA256
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX head-posture calibration receipt names the wrong candidate"
        )
      }
      let calibrationCandidate = try BrainPolicyNumanXLearnedCandidateArtifact
        .decode(BrainPolicyNumanXCaptureVerifier.verifiedData(
          sha256: calibration.candidateArtifactSHA256,
          directory: artifactDirectory
        ))
      guard let exploratoryHash =
          calibrationCandidate.headPostureLearningArtifactSHA256
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX head-posture calibration candidate lacks physical supervision"
        )
      }
      let exploratory = try BrainPolicyNumanXHeadPostureLearningArtifact.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(
          sha256: exploratoryHash, directory: artifactDirectory
        )
      )
      guard calibration.taskFingerprint == coordinates.taskFingerprint,
        calibration.trainingSceneFingerprint == coordinates.sceneFingerprint,
        calibration.objectFingerprint == coordinates.objectFingerprint,
        calibration.embodimentFingerprint == coordinates.embodimentFingerprint,
        calibration.timestepMicroseconds == timestepMicroseconds,
        exploratory.calibrationEvaluationArtifactSHA256 == nil,
        exploratory.effectiveResponseGainDirection == 1
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX head-posture calibration does not bind one positive-gain probe"
        )
      }
      responseGainDirection = try resolvedCalibrationDirection(
        candidateMinusBaselineLiftMeters:
          calibration.candidateMinusBaselineLiftMeters,
        minimumAbsoluteResponseMeters:
          calibration.minimumLiftAdvantageMeters
      )
    } else {
      responseGainDirection = nil
    }
    return try BrainPolicyNumanXHeadPostureLearningArtifact(
      sourceRunArtifactSHA256: sourceRunArtifactSHA256,
      coordinates: coordinates,
      timestepMicroseconds: timestepMicroseconds,
      objectiveWeight: objectiveWeight,
      observation: observation,
      calibrationEvaluationArtifactSHA256:
        calibrationEvaluationArtifactSHA256,
      responseGainDirection: responseGainDirection
    )
  }

  /// Resolves a measured plant-gradient sign only when the paired physical
  /// response clears the evaluator's predeclared resolution floor. A merely
  /// nonzero Float response can be one representational ULP and is not causal
  /// calibration authority.
  static func resolvedCalibrationDirection(
    candidateMinusBaselineLiftMeters: Float,
    minimumAbsoluteResponseMeters: Float
  ) throws -> Float {
    guard candidateMinusBaselineLiftMeters.isFinite,
      minimumAbsoluteResponseMeters.isFinite,
      minimumAbsoluteResponseMeters > 0,
      abs(candidateMinusBaselineLiftMeters) >= minimumAbsoluteResponseMeters
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture calibration response is below its physical "
          + "resolution floor"
      )
    }
    return candidateMinusBaselineLiftMeters > 0 ? 1 : -1
  }
}

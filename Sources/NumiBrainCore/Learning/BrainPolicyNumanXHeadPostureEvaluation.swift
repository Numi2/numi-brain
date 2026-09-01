import Foundation

/// Identity-free physical response measured from one authoritative full-body
/// run. Root one is bootstrap; the response spans the first settled vestibular
/// sample through the terminal root and uses head height relative to the free
/// root, so unconstrained gravity cannot masquerade as task progress.
@frozen
public struct BrainPolicyNumanXHeadPostureObservation:
  Codable, Equatable, Sendable
{
  public let runArtifactSHA256: String
  public let rootCount: UInt32
  public let initialControlStep: UInt32
  public let terminalControlStep: UInt32
  public let initialSampleSHA256: String
  public let terminalSampleSHA256: String
  public let initialRelativeHeadHeightMeters: Float
  public let terminalRelativeHeadHeightMeters: Float
  public let relativeHeadLiftMeters: Float
  public let meanActuatorCommand: Float
  public let peakActuatorCommand: Float

  public init(
    runArtifactSHA256: String,
    rootCount: UInt32,
    initialControlStep: UInt32,
    terminalControlStep: UInt32,
    initialSampleSHA256: String,
    terminalSampleSHA256: String,
    initialRelativeHeadHeightMeters: Float,
    terminalRelativeHeadHeightMeters: Float,
    meanActuatorCommand: Float,
    peakActuatorCommand: Float
  ) throws {
    let lift = terminalRelativeHeadHeightMeters
      - initialRelativeHeadHeightMeters
    guard BrainPolicyEvidenceArtifact.isSHA256(runArtifactSHA256),
      rootCount >= 100, initialControlStep > 1,
      terminalControlStep > initialControlStep,
      BrainPolicyEvidenceArtifact.isSHA256(initialSampleSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(terminalSampleSHA256),
      initialSampleSHA256 != terminalSampleSHA256,
      initialRelativeHeadHeightMeters.isFinite,
      terminalRelativeHeadHeightMeters.isFinite, lift.isFinite,
      meanActuatorCommand.isFinite, (0...1).contains(meanActuatorCommand),
      peakActuatorCommand.isFinite, (0...1).contains(peakActuatorCommand),
      meanActuatorCommand <= peakActuatorCommand
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture observation is invalid"
      )
    }
    self.runArtifactSHA256 = runArtifactSHA256
    self.rootCount = rootCount
    self.initialControlStep = initialControlStep
    self.terminalControlStep = terminalControlStep
    self.initialSampleSHA256 = initialSampleSHA256
    self.terminalSampleSHA256 = terminalSampleSHA256
    self.initialRelativeHeadHeightMeters = initialRelativeHeadHeightMeters
    self.terminalRelativeHeadHeightMeters = terminalRelativeHeadHeightMeters
    self.relativeHeadLiftMeters = lift
    self.meanActuatorCommand = meanActuatorCommand
    self.peakActuatorCommand = peakActuatorCommand
  }
}

/// Canonical local Gate C response result. It binds one candidate's disjoint
/// training scene to a matched parent/candidate held-out scene and retains a
/// predeclared minimum lift advantage. A failure remains useful evidence but
/// can never be promoted.
@frozen
public struct BrainPolicyNumanXHeadPostureEvaluationArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1
  public static let objectiveIdentifier =
    "numibrain.numanx.head-posture-lift.v1"
  public static let targetBodyIdentifier: UInt32 = 23
  public static let minimumLiftAdvantageMeters: Float = 1.0e-6

  public let formatVersion: UInt32
  public let objectiveIdentifier: String
  public let candidateArtifactSHA256: String
  public let trainingRunArtifactSHA256: String
  public let baselineRunArtifactSHA256: String
  public let candidateRunArtifactSHA256: String
  public let taskFingerprint: UInt64
  public let trainingSceneFingerprint: UInt64
  public let evaluationSceneFingerprint: UInt64
  public let objectFingerprint: UInt64
  public let embodimentFingerprint: UInt64
  public let timestepMicroseconds: UInt32
  public let targetBodyIdentifier: UInt32
  public let minimumLiftAdvantageMeters: Float
  public let baseline: BrainPolicyNumanXHeadPostureObservation
  public let candidate: BrainPolicyNumanXHeadPostureObservation
  public let candidateMinusBaselineLiftMeters: Float
  public let succeeds: Bool
  public let promotable: Bool

  public init(
    candidateArtifactSHA256: String,
    trainingRunArtifactSHA256: String,
    baselineRunArtifactSHA256: String,
    candidateRunArtifactSHA256: String,
    taskFingerprint: UInt64,
    trainingSceneFingerprint: UInt64,
    evaluationSceneFingerprint: UInt64,
    objectFingerprint: UInt64,
    embodimentFingerprint: UInt64,
    timestepMicroseconds: UInt32,
    baseline: BrainPolicyNumanXHeadPostureObservation,
    candidate: BrainPolicyNumanXHeadPostureObservation
  ) throws {
    let advantage = candidate.relativeHeadLiftMeters
      - baseline.relativeHeadLiftMeters
    guard BrainPolicyEvidenceArtifact.isSHA256(candidateArtifactSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(trainingRunArtifactSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(baselineRunArtifactSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(candidateRunArtifactSHA256),
      Set([
        trainingRunArtifactSHA256, baselineRunArtifactSHA256,
        candidateRunArtifactSHA256,
      ]).count == 3,
      taskFingerprint > 0, trainingSceneFingerprint > 0,
      evaluationSceneFingerprint > 0,
      trainingSceneFingerprint != evaluationSceneFingerprint,
      objectFingerprint > 0, embodimentFingerprint > 0,
      timestepMicroseconds > 0,
      baseline.runArtifactSHA256 == baselineRunArtifactSHA256,
      candidate.runArtifactSHA256 == candidateRunArtifactSHA256,
      baseline.rootCount == candidate.rootCount,
      baseline.initialControlStep == candidate.initialControlStep,
      baseline.terminalControlStep == candidate.terminalControlStep,
      advantage.isFinite
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture evaluation is invalid"
      )
    }
    formatVersion = Self.formatVersion
    objectiveIdentifier = Self.objectiveIdentifier
    self.candidateArtifactSHA256 = candidateArtifactSHA256
    self.trainingRunArtifactSHA256 = trainingRunArtifactSHA256
    self.baselineRunArtifactSHA256 = baselineRunArtifactSHA256
    self.candidateRunArtifactSHA256 = candidateRunArtifactSHA256
    self.taskFingerprint = taskFingerprint
    self.trainingSceneFingerprint = trainingSceneFingerprint
    self.evaluationSceneFingerprint = evaluationSceneFingerprint
    self.objectFingerprint = objectFingerprint
    self.embodimentFingerprint = embodimentFingerprint
    self.timestepMicroseconds = timestepMicroseconds
    targetBodyIdentifier = Self.targetBodyIdentifier
    minimumLiftAdvantageMeters = Self.minimumLiftAdvantageMeters
    self.baseline = baseline
    self.candidate = candidate
    candidateMinusBaselineLiftMeters = advantage
    succeeds = advantage >= Self.minimumLiftAdvantageMeters
    promotable = false
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
    let reconstructed = try Self(
      candidateArtifactSHA256: candidateArtifactSHA256,
      trainingRunArtifactSHA256: trainingRunArtifactSHA256,
      baselineRunArtifactSHA256: baselineRunArtifactSHA256,
      candidateRunArtifactSHA256: candidateRunArtifactSHA256,
      taskFingerprint: taskFingerprint,
      trainingSceneFingerprint: trainingSceneFingerprint,
      evaluationSceneFingerprint: evaluationSceneFingerprint,
      objectFingerprint: objectFingerprint,
      embodimentFingerprint: embodimentFingerprint,
      timestepMicroseconds: timestepMicroseconds,
      baseline: baseline,
      candidate: candidate
    )
    guard reconstructed == self else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture evaluation is not canonical"
      )
    }
  }
}

public struct BrainPolicyNumanXHeadPostureEvaluationReceipt: Sendable {
  public let evaluationArtifactSHA256: String
  public let candidateArtifactSHA256: String
  public let baselineRunArtifactSHA256: String
  public let candidateRunArtifactSHA256: String
  public let baselineLiftMeters: Float
  public let candidateLiftMeters: Float
  public let candidateMinusBaselineLiftMeters: Float
  public let succeeds: Bool
  public let transitiveEvidenceSHA256: String
}

public enum BrainPolicyNumanXHeadPostureEvaluator {
  public static func evaluateAndWrite(
    candidateArtifactSHA256: String,
    baselineRunArtifactSHA256: String,
    candidateRunArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXHeadPostureEvaluationReceipt {
    try evaluate(
      candidateArtifactSHA256: candidateArtifactSHA256,
      baselineRunArtifactSHA256: baselineRunArtifactSHA256,
      candidateRunArtifactSHA256: candidateRunArtifactSHA256,
      artifactDirectory: artifactDirectory,
      writeArtifact: true
    )
  }

  public static func verify(
    evaluationArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXHeadPostureEvaluationReceipt {
    let artifact = try BrainPolicyNumanXHeadPostureEvaluationArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: evaluationArtifactSHA256,
        directory: artifactDirectory
      )
    )
    let receipt = try evaluate(
      candidateArtifactSHA256: artifact.candidateArtifactSHA256,
      baselineRunArtifactSHA256: artifact.baselineRunArtifactSHA256,
      candidateRunArtifactSHA256: artifact.candidateRunArtifactSHA256,
      artifactDirectory: artifactDirectory,
      writeArtifact: false
    )
    guard receipt.evaluationArtifactSHA256 == evaluationArtifactSHA256 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture evaluation does not recompute byte-identically"
      )
    }
    return receipt
  }

  private static func evaluate(
    candidateArtifactSHA256: String,
    baselineRunArtifactSHA256: String,
    candidateRunArtifactSHA256: String,
    artifactDirectory: URL,
    writeArtifact: Bool
  ) throws -> BrainPolicyNumanXHeadPostureEvaluationReceipt {
    let learned = try BrainPolicyNumanXLearnedCandidateVerifier
      .verifiedCandidate(
        candidateArtifactSHA256: candidateArtifactSHA256,
        artifactDirectory: artifactDirectory
      )
    let trainingRun = try run(
      learned.captureRunArtifactSHA256, directory: artifactDirectory
    )
    let baselineRun = try run(
      baselineRunArtifactSHA256, directory: artifactDirectory
    )
    let candidateRun = try run(
      candidateRunArtifactSHA256, directory: artifactDirectory
    )
    for hash in [
      learned.captureRunArtifactSHA256, baselineRunArtifactSHA256,
      candidateRunArtifactSHA256,
    ] {
      _ = try BrainPolicyNumanXCaptureVerifier.verify(
        runArtifactSHA256: hash, artifactDirectory: artifactDirectory
      )
    }
    let publication = try learned.publication
    guard baselineRun.parameterVersionFingerprint
        == learned.parentVersion.fingerprint,
      candidateRun.parameterVersionFingerprint == publication.version.fingerprint,
      trainingRun.timestepMicroseconds != nil,
      trainingRun.timestepMicroseconds == baselineRun.timestepMicroseconds,
      baselineRun.timestepMicroseconds == candidateRun.timestepMicroseconds,
      baselineRun.nativeModelSourceFingerprint
        == candidateRun.nativeModelSourceFingerprint,
      baselineRun.acceptedStateProofProgramFingerprint
        == candidateRun.acceptedStateProofProgramFingerprint,
      baselineRun.compiledSpeciesTemplateFingerprint
        == candidateRun.compiledSpeciesTemplateFingerprint,
      baselineRun.deviceRegistryID == candidateRun.deviceRegistryID
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture runs do not bind the candidate and runtime"
      )
    }
    let trainingCoordinates = try coordinates(
      trainingRun, directory: artifactDirectory
    )
    let baselineCoordinates = try coordinates(
      baselineRun, directory: artifactDirectory
    )
    let candidateCoordinates = try coordinates(
      candidateRun, directory: artifactDirectory
    )
    guard baselineCoordinates == candidateCoordinates,
      trainingCoordinates.taskFingerprint
        == baselineCoordinates.taskFingerprint,
      trainingCoordinates.sceneFingerprint
        != baselineCoordinates.sceneFingerprint,
      trainingCoordinates.objectFingerprint
        == baselineCoordinates.objectFingerprint,
      trainingCoordinates.embodimentFingerprint
        == baselineCoordinates.embodimentFingerprint
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture evaluation is not a matched disjoint-scene split"
      )
    }
    let baseline = try observation(
      baselineRunArtifactSHA256, run: baselineRun,
      directory: artifactDirectory
    )
    let candidate = try observation(
      candidateRunArtifactSHA256, run: candidateRun,
      directory: artifactDirectory
    )
    let artifact = try BrainPolicyNumanXHeadPostureEvaluationArtifact(
      candidateArtifactSHA256: candidateArtifactSHA256,
      trainingRunArtifactSHA256: learned.captureRunArtifactSHA256,
      baselineRunArtifactSHA256: baselineRunArtifactSHA256,
      candidateRunArtifactSHA256: candidateRunArtifactSHA256,
      taskFingerprint: baselineCoordinates.taskFingerprint,
      trainingSceneFingerprint: trainingCoordinates.sceneFingerprint,
      evaluationSceneFingerprint: baselineCoordinates.sceneFingerprint,
      objectFingerprint: baselineCoordinates.objectFingerprint,
      embodimentFingerprint: baselineCoordinates.embodimentFingerprint,
      timestepMicroseconds: baselineRun.timestepMicroseconds!,
      baseline: baseline,
      candidate: candidate
    )
    let artifactHash = writeArtifact
      ? try artifact.write(to: artifactDirectory)
      : BrainPolicyEvidenceArtifact.sha256(try artifact.encoded())
    var transitive = Data()
    for hash in [
      artifactHash, candidateArtifactSHA256,
      learned.captureRunArtifactSHA256, baselineRunArtifactSHA256,
      candidateRunArtifactSHA256,
    ].sorted() {
      transitive.append(Data(hash.utf8))
    }
    return BrainPolicyNumanXHeadPostureEvaluationReceipt(
      evaluationArtifactSHA256: artifactHash,
      candidateArtifactSHA256: candidateArtifactSHA256,
      baselineRunArtifactSHA256: baselineRunArtifactSHA256,
      candidateRunArtifactSHA256: candidateRunArtifactSHA256,
      baselineLiftMeters: baseline.relativeHeadLiftMeters,
      candidateLiftMeters: candidate.relativeHeadLiftMeters,
      candidateMinusBaselineLiftMeters:
        artifact.candidateMinusBaselineLiftMeters,
      succeeds: artifact.succeeds,
      transitiveEvidenceSHA256: BrainPolicyEvidenceArtifact.sha256(transitive)
    )
  }

  private static func run(
    _ hash: String,
    directory: URL
  ) throws -> BrainPolicyNumanXCaptureRunArtifact {
    try BrainPolicyNumanXCaptureRunArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: hash, directory: directory
      )
    )
  }

  static func coordinates(
    _ run: BrainPolicyNumanXCaptureRunArtifact,
    directory: URL
  ) throws -> BrainPolicyNumanXDatasetCoordinates {
    try BrainPolicyNumanXSupportStabilityEvaluator.canonicalCoordinates(
      run, artifactDirectory: directory
    )
  }

  static func observation(
    _ runHash: String,
    run: BrainPolicyNumanXCaptureRunArtifact,
    directory: URL
  ) throws -> BrainPolicyNumanXHeadPostureObservation {
    let roots = run.roots.sorted { $0.controlStep < $1.controlStep }
    guard roots.count >= 100,
      roots.allSatisfy({ root in
        root.externalGoalArtifactSHA256 != nil
          && root.motorActionArtifactSHA256 != nil
      })
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture run lacks bounded goal/action evidence"
      )
    }
    var measurements: [(BrainPolicyNumanXCaptureRootReference, Float)] = []
    var actionSum: Double = 0
    var actionCount = 0
    var actionPeak: Float = 0
    for root in roots {
      let execution = try BrainPolicyNumanXRootExecution.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(
          sha256: root.executionSHA256, directory: directory
        )
      )
      guard execution.outcome == .accepted,
        let goalHash = root.externalGoalArtifactSHA256,
        let actionHash = root.motorActionArtifactSHA256
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX head-posture run contains a nonaccepted or unauthenticated root"
        )
      }
      let goal = try BrainPolicyNumanXActiveGoalArtifact.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(
          sha256: goalHash, directory: directory
        )
      )
      guard goal.targetBodyIdentifier
          == BrainPolicyNumanXHeadPostureEvaluationArtifact
            .targetBodyIdentifier,
        goal.targetState.count == 16,
        goal.targetState.enumerated().allSatisfy({ index, value in
          switch index {
          case 2: value == 0.25
          case 6: value == 0.10
          case 10: value == 0.05
          case 14: value == 0.20
          default: value == 0
          }
        })
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX head-posture root changes its body target"
        )
      }
      if root.controlStep > 1 {
        let sample = try BrainPolicyNumanXRootSampleArtifact.decode(
          BrainPolicyNumanXCaptureVerifier.verifiedData(
            sha256: root.sampleSHA256, directory: directory
          )
        )
        measurements.append((root, try relativeHeadHeight(
          sample, directory: directory
        )))
        let action = try BrainPolicyNumanXMotorActionArtifact.decode(
          BrainPolicyNumanXCaptureVerifier.verifiedData(
            sha256: actionHash, directory: directory
          )
        )
        guard action.controlStep == root.controlStep else {
          throw BrainRuntimeError.invalidParameterVersion(
            "NumanX head-posture action belongs to another root"
          )
        }
        for value in action.actuatorCommands {
          actionSum += Double(value)
          actionCount += 1
          actionPeak = max(actionPeak, value)
        }
      }
    }
    guard let first = measurements.first, let last = measurements.last,
      actionCount > 0
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture run has no settled response"
      )
    }
    return try BrainPolicyNumanXHeadPostureObservation(
      runArtifactSHA256: runHash,
      rootCount: UInt32(roots.count),
      initialControlStep: first.0.controlStep,
      terminalControlStep: last.0.controlStep,
      initialSampleSHA256: first.0.sampleSHA256,
      terminalSampleSHA256: last.0.sampleSHA256,
      initialRelativeHeadHeightMeters: first.1,
      terminalRelativeHeadHeightMeters: last.1,
      meanActuatorCommand: Float(actionSum / Double(actionCount)),
      peakActuatorCommand: actionPeak
    )
  }

  private static func relativeHeadHeight(
    _ sample: BrainPolicyNumanXRootSampleArtifact,
    directory: URL
  ) throws -> Float {
    guard let channel = sample.channels.first(where: {
      $0.modality == .vestibular
    }), channel.receptorCount == 1, channel.featureDimension == 22,
      let validityHash = channel.validitySHA256
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture sample lacks vestibular evidence"
      )
    }
    let values = try BrainPolicyNumanXCaptureVerifier.verifiedData(
      sha256: channel.valuesSHA256, directory: directory
    )
    let validity = try BrainPolicyNumanXCaptureVerifier.verifiedData(
      sha256: validityHash, directory: directory
    )
    guard values.count == 22 * MemoryLayout<Float>.stride,
      validity.count == MemoryLayout<UInt32>.stride
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture vestibular evidence has the wrong shape"
      )
    }
    let mask = validity.withUnsafeBytes {
      UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self))
    }
    guard (mask & (UInt32(1) << 2)) != 0,
      (mask & (UInt32(1) << 15)) != 0
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture root/head position is invalid"
      )
    }
    func float(_ index: Int) -> Float {
      values.withUnsafeBytes { bytes in
        let bits = bytes.loadUnaligned(
          fromByteOffset: index * MemoryLayout<UInt32>.stride,
          as: UInt32.self
        )
        return Float(bitPattern: UInt32(littleEndian: bits))
      }
    }
    let relative = float(15) - float(2)
    guard relative.isFinite else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX head-posture response is non-finite"
      )
    }
    return relative
  }
}

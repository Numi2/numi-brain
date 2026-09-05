import Foundation
import NumiBrainValidation

/// Narrow native adapter: body-23 height minus body-0 height along the native
/// world z axis. This is not a hand-reaching or whole-body qualification claim.
/// General 1...3-D objective arithmetic lives in NumiBrainValidation; additional
/// native coordinates require a reviewed owning sensor schema before use.
public struct BrainReachHoldProtocol: Codable, Equatable, Sendable {
  public let formatVersion: UInt32
  public let identifier: String
  public let sourceRevision: String
  public let expectedNativeModelFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  public let taskFingerprint: UInt64
  public let sceneFingerprint: UInt64
  public let objectFingerprint: UInt64
  public let embodimentFingerprint: UInt64
  public let episodeIdentifier: UInt64
  public let randomSeed: UInt64
  public let timestepMicroseconds: UInt32
  public let targetState: [Float]
  public let objective: ReachHoldObjective
  public let calibrationSettingsSHA256: String?

  public func validate() throws {
    try objective.validate()
    guard calibrationSettingsSHA256 == nil || BrainPolicyEvidenceArtifact.isSHA256(calibrationSettingsSHA256!),
      formatVersion == 1, !identifier.isEmpty, identifier.utf8.count <= 256,
      !sourceRevision.isEmpty, sourceRevision.utf8.count <= 256,
      [expectedNativeModelFingerprint, parameterVersionFingerprint, taskFingerprint, sceneFingerprint,
        objectFingerprint, embodimentFingerprint, episodeIdentifier, randomSeed].allSatisfy({ $0 > 0 }),
      UInt32(exactly: episodeIdentifier) != nil, UInt32(exactly: randomSeed) != nil,
      timestepMicroseconds > 0, objective.targetPositionMeters.count == 1,
      objective.durationMicroseconds % UInt64(timestepMicroseconds) == 0,
      objective.durationMicroseconds / UInt64(timestepMicroseconds) <= 100_000,
      targetState.count == 16, targetState.allSatisfy(\.isFinite),
      Double(targetState[2]) == objective.targetPositionMeters[0],
      targetState.enumerated().allSatisfy({ index, value in [2, 10, 14].contains(index) || value == 0 }) else {
      throw BrainRuntimeError.transaction("invalid or unsupported native reach/hold protocol")
    }
  }

  /// One bootstrap root plus the first and terminal settled-input acquisitions.
  /// Capture timestamps, not this count alone, determine usable physical time.
  public var captureRootCount: UInt32 {
    get throws { try validate(); return UInt32(objective.durationMicroseconds / UInt64(timestepMicroseconds) + 2) }
  }

  public func goal(controlStep: UInt32, committed: BrainTimestamp, target: BrainTimestamp) throws -> ActiveGoal {
    try validate()
    return try ActiveGoal(identifier: 0x5248_0000_0000_0000 | UInt64(controlStep), origin: .externalTask,
      targetState: BrainLatentVector(values: targetState, expectedCount: 16), priority: 10, deadline: target,
      successModel: BrainLatentVector(values: targetState, expectedCount: 16),
      failureModel: BrainLatentVector(values: targetState.map { -$0 }, expectedCount: 16),
      damageRiskBudget: 1, persistence: 1, createdTimestamp: committed, targetBodyIdentifier: 23)
  }
}

public struct BrainReachHoldEvaluation: Codable, Equatable, Sendable {
  public let formatVersion: UInt32
  public let promotable: Bool
  public let protocolSHA256: String
  public let runSHA256: String
  public let transitiveRunEvidenceSHA256: String
  public let acceptedRoots: UInt64
  public let rejectedRoots: UInt64
  public let initialRelativeHeadHeightMeters: Double?
  public let result: ReachHoldResult?
  public let failures: [String]
}

/// A verifier-issued diagnostic receipt, not a runtime publication capability.
public struct BrainVerifiedReachHoldEvaluation: Sendable {
  public let artifact: BrainReachHoldEvaluation
  public let artifactSHA256: String
  public let experiment: BrainReachHoldProtocol
  fileprivate init(artifact: BrainReachHoldEvaluation, hash: String, experiment: BrainReachHoldProtocol) {
    self.artifact = artifact; artifactSHA256 = hash; self.experiment = experiment
  }
}

public enum BrainReachHoldExperiment {
  public static func read<T: Decodable>(_ type: T.Type, hash: String, directory: URL) throws -> T {
    try JSONDecoder().decode(type, from: BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: hash, directory: directory))
  }
  @discardableResult
  public static func retain<T: Encodable>(_ value: T, directory: URL) throws -> String {
    try BrainPolicyEvidenceArtifact.write(BrainPolicyEvidenceArtifact.encodeCanonical(value), to: directory)
  }

  public static func evaluate(protocolSHA256: String, runSHA256: String, directory: URL) throws -> BrainVerifiedReachHoldEvaluation {
    let experiment = try read(BrainReachHoldProtocol.self, hash: protocolSHA256, directory: directory)
    try experiment.validate()
    let verified = try BrainPolicyNumanXCaptureVerifier.verify(runArtifactSHA256: runSHA256, artifactDirectory: directory)
    let run = try BrainPolicyNumanXCaptureRunArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: runSHA256, directory: directory))
    guard run.sourceRevision == experiment.sourceRevision, run.datasetSourceRevision == protocolSHA256,
      run.nativeModelSourceFingerprint == experiment.expectedNativeModelFingerprint,
      run.parameterVersionFingerprint == experiment.parameterVersionFingerprint,
      run.timestepMicroseconds == experiment.timestepMicroseconds,
      run.roots.count == Int(try experiment.captureRootCount) else {
      throw BrainRuntimeError.transaction("reach/hold capture is not bound to this frozen experiment")
    }
    var positions: [ReachHoldPositionSample] = [], commands: [ReachHoldCommandInterval] = []
    var firstCoordinates: BrainPolicyNumanXDatasetCoordinates?
    var expectedNextTime: UInt64?, expectedNextGeneration: UInt64?
    var sensorProfile: UInt64?, firstSensor: UInt64?, endSensor: UInt64?
    var lastAcquisitionIdentity: String?
    var previousAcquisitionTime: UInt64?
    for (index, root) in run.roots.enumerated() {
      guard root.controlStep == UInt32(index + 1), let goalHash = root.externalGoalArtifactSHA256,
        let actionHash = root.motorActionArtifactSHA256 else {
        throw BrainRuntimeError.transaction("reach/hold capture lacks exact control, goal or action evidence")
      }
      let sample = try BrainPolicyNumanXRootSampleArtifact.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: root.sampleSHA256, directory: directory))
      let coordinates = sample.coordinates
      guard coordinates.datasetSourceRevision == protocolSHA256,
        coordinates.taskFingerprint == experiment.taskFingerprint, coordinates.sceneFingerprint == experiment.sceneFingerprint,
        coordinates.objectFingerprint == experiment.objectFingerprint,
        coordinates.embodimentFingerprint == experiment.embodimentFingerprint,
        coordinates.episodeIdentifier == experiment.episodeIdentifier,
        firstCoordinates == nil || firstCoordinates == coordinates,
        sensorProfile == nil || sensorProfile == sample.sensoryProfileFingerprint,
        expectedNextTime == nil || expectedNextTime == sample.committedTimestampMicroseconds,
        expectedNextGeneration == nil || expectedNextGeneration == sample.basePhysicsGeneration else {
        throw BrainRuntimeError.transaction("reach/hold capture crosses physical history or experiment boundaries")
      }
      firstCoordinates = coordinates; sensorProfile = sample.sensoryProfileFingerprint
      let execution = try BrainPolicyNumanXRootExecution.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: root.executionSHA256, directory: directory))
      let goal = try BrainPolicyNumanXActiveGoalArtifact.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: goalHash, directory: directory))
      let expectedGoal = try BrainPolicyNumanXActiveGoalArtifact(goal: experiment.goal(controlStep: root.controlStep,
        committed: BrainTimestamp(microseconds: sample.committedTimestampMicroseconds),
        target: BrainTimestamp(microseconds: sample.targetTimestampMicroseconds)))
      guard goal == expectedGoal else { throw BrainRuntimeError.transaction("native goal changed from frozen reach/hold task") }
      let accepted = execution.outcome == .accepted
      expectedNextTime = accepted ? sample.targetTimestampMicroseconds : sample.committedTimestampMicroseconds
      let (generation, overflow) = sample.basePhysicsGeneration.addingReportingOverflow(accepted ? 1 : 0)
      guard !overflow else { throw BrainRuntimeError.transaction("physical generation overflow") }
      expectedNextGeneration = generation
      if accepted {
        let action = try BrainPolicyNumanXMotorActionArtifact.decode(
          BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: actionHash, directory: directory))
        guard action.controlStep == root.controlStep, action.actuatorCommands.count == 416,
          action.actuatorCommands.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
          throw BrainRuntimeError.transaction("invalid full-body applied excitation evidence")
        }
        let effort = action.actuatorCommands.reduce(0.0) { $0 + Double($1) * Double($1) } / 416
        commands.append(.init(startMicroseconds: sample.committedTimestampMicroseconds,
          endMicroseconds: sample.targetTimestampMicroseconds, meanSquaredExcitation: effort))
      }
      // Preserve rejected outcomes, but do not let one malformed acquisition
      // create an apparently successful shortened trace.
      if index > 0 && verified.rejectedRootCount == 0 {
        let position = try relativeHeadPosition(sample: sample, directory: directory)
        guard previousAcquisitionTime == nil || position.timestampMicroseconds >= previousAcquisitionTime! else {
          throw BrainRuntimeError.transaction("receptor acquisition clock moved backward")
        }
        previousAcquisitionTime = position.timestampMicroseconds
        if firstSensor == nil {
          let (end, overflow) = position.timestampMicroseconds.addingReportingOverflow(experiment.objective.durationMicroseconds)
          guard !overflow else { throw BrainRuntimeError.transaction("reach/hold sensor horizon overflow") }
          firstSensor = position.timestampMicroseconds; endSensor = end
        }
        let sourceChannel = sample.channels.first { $0.modality == .vestibular }!
        let acquisition = sourceChannel.valuesSHA256 + ":" + (sourceChannel.validitySHA256 ?? "")
        if let previous = positions.last, position.timestampMicroseconds == previous.timestampMicroseconds {
          guard previous == position, lastAcquisitionIdentity == acquisition else {
            throw BrainRuntimeError.transaction("sensor content changed without a new acquisition timestamp")
          }
        } else if position.timestampMicroseconds <= endSensor! {
          positions.append(position); lastAcquisitionIdentity = acquisition
        }
      }
    }
    let result: ReachHoldResult?
    let failures: [String]
    if verified.rejectedRootCount > 0 {
      result = nil; failures = ["authoritative_rejection_in_fixed_horizon"]
    } else {
      result = try ReachHoldEvaluator.evaluate(objective: experiment.objective, positions: positions, commands: commands)
      failures = result!.failures
    }
    let artifact = BrainReachHoldEvaluation(formatVersion: 1, promotable: false, protocolSHA256: protocolSHA256,
      runSHA256: runSHA256, transitiveRunEvidenceSHA256: verified.transitiveEvidenceSHA256,
      acceptedRoots: verified.acceptedRootCount, rejectedRoots: verified.rejectedRootCount,
      initialRelativeHeadHeightMeters: positions.first?.positionMeters[0], result: result, failures: failures)
    let hash = try retain(artifact, directory: directory)
    return BrainVerifiedReachHoldEvaluation(artifact: artifact, hash: hash, experiment: experiment)
  }

  public static func verify(evaluationSHA256: String, directory: URL) throws -> BrainVerifiedReachHoldEvaluation {
    let saved = try read(BrainReachHoldEvaluation.self, hash: evaluationSHA256, directory: directory)
    let rebuilt = try evaluate(protocolSHA256: saved.protocolSHA256, runSHA256: saved.runSHA256, directory: directory)
    guard saved == rebuilt.artifact, evaluationSHA256 == rebuilt.artifactSHA256 else {
      throw BrainRuntimeError.transaction("reach/hold metrics or retained source relation changed")
    }
    return rebuilt
  }

  private static func relativeHeadPosition(sample: BrainPolicyNumanXRootSampleArtifact, directory: URL) throws -> ReachHoldPositionSample {
    guard let channel = sample.channels.first(where: { $0.modality == .vestibular }),
      channel.receptorCount == 1, channel.featureDimension == 22, let maskHash = channel.validitySHA256,
      channel.receptorTimestampMicroseconds <= sample.committedTimestampMicroseconds else {
      throw BrainRuntimeError.transaction("unsupported or future-dated vestibular acquisition")
    }
    let values = try BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: channel.valuesSHA256, directory: directory)
    let mask = try BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: maskHash, directory: directory)
    let root = try PhysicalSensorField.decode(values: values, validity: mask, receptorCount: 1,
      featureDimension: 22, receptorIndex: 0, featureIndex: 2, requiredValidityMask: 1 << 2)
    let head = try PhysicalSensorField.decode(values: values, validity: mask, receptorCount: 1,
      featureDimension: 22, receptorIndex: 0, featureIndex: 15, requiredValidityMask: 1 << 15)
    guard root.valid, head.valid else { throw BrainRuntimeError.transaction("root/head height observation unavailable") }
    return .init(timestampMicroseconds: channel.receptorTimestampMicroseconds, positionMeters: [head.value - root.value])
  }
}

/// Explicit experiment-only parameter bytes. No standard learner provenance or
/// .nbpolicy qualification is fabricated for derivative-free physical probes.
public struct BrainMotorStudyPublication: Codable, Equatable, Sendable {
  public let formatVersion: UInt32
  public let version: BrainParameterVersion
  public let sharedArtifact: BrainSharedParameterArtifact
  public let evidenceSHA256: [String]
  public init(publication: BrainParameterPublication, evidenceSHA256: [String] = []) throws {
    formatVersion = 1; version = publication.version; sharedArtifact = publication.sharedArtifact
    self.evidenceSHA256 = evidenceSHA256; try validate()
  }
  public func validate() throws {
    try sharedArtifact.validate(parameterVersion: version)
    guard formatVersion == 1, evidenceSHA256.count <= 32, evidenceSHA256.allSatisfy(BrainPolicyEvidenceArtifact.isSHA256),
      Set(evidenceSHA256).count == evidenceSHA256.count else { throw BrainRuntimeError.transaction("invalid research publication") }
  }
  public var unverifiedPublication: BrainParameterPublication {
    get throws { try validate(); return try BrainParameterPublication(version: version, sharedArtifact: sharedArtifact) }
  }
}

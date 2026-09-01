import Foundation

@frozen
public struct BrainPolicyNumanXDelayedSupportExample:
  Codable, Equatable, Sendable
{
  public let startControlStep: UInt32
  public let consequenceControlStep: UInt32
  public let startSampleSHA256: String
  public let consequenceSampleSHA256: String
  public let horizonMicroseconds: UInt64
  public let startVestibularValidityMask: UInt32
  public let startGroundNormalVelocity: Float?
  public let consequenceGroundNormalVelocity: Float
  public let consequenceHeadGroundClearance: Float
  public let consequenceQuaternionNormError: Float
  public let meanActuatorCommand: Float
  public let peakActuatorCommand: Float
  public let stabilizationDemand: Float
  public let success: Bool

  public init(
    startControlStep: UInt32,
    consequenceControlStep: UInt32,
    startSampleSHA256: String,
    consequenceSampleSHA256: String,
    horizonMicroseconds: UInt64,
    startVestibularValidityMask: UInt32,
    startGroundNormalVelocity: Float?,
    consequenceGroundNormalVelocity: Float,
    consequenceHeadGroundClearance: Float,
    consequenceQuaternionNormError: Float,
    meanActuatorCommand: Float,
    peakActuatorCommand: Float,
    stabilizationDemand: Float,
    success: Bool
  ) throws {
    guard startControlStep > 0,
      consequenceControlStep > startControlStep,
      BrainPolicyEvidenceArtifact.isSHA256(startSampleSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(consequenceSampleSHA256),
      startSampleSHA256 != consequenceSampleSHA256,
      horizonMicroseconds > 0,
      [
        consequenceGroundNormalVelocity,
        consequenceHeadGroundClearance, consequenceQuaternionNormError,
        meanActuatorCommand, peakActuatorCommand, stabilizationDemand,
      ].allSatisfy(\.isFinite),
      startGroundNormalVelocity?.isFinite ?? true,
      ((startVestibularValidityMask & (UInt32(1) << 21)) != 0)
        == (startGroundNormalVelocity != nil),
      consequenceQuaternionNormError >= 0,
      (0...1).contains(meanActuatorCommand),
      (0...1).contains(peakActuatorCommand),
      meanActuatorCommand <= peakActuatorCommand,
      (0...1).contains(stabilizationDemand)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX delayed-support example is invalid"
      )
    }
    self.startControlStep = startControlStep
    self.consequenceControlStep = consequenceControlStep
    self.startSampleSHA256 = startSampleSHA256
    self.consequenceSampleSHA256 = consequenceSampleSHA256
    self.horizonMicroseconds = horizonMicroseconds
    self.startVestibularValidityMask = startVestibularValidityMask
    self.startGroundNormalVelocity = startGroundNormalVelocity
    self.consequenceGroundNormalVelocity = consequenceGroundNormalVelocity
    self.consequenceHeadGroundClearance = consequenceHeadGroundClearance
    self.consequenceQuaternionNormError = consequenceQuaternionNormError
    self.meanActuatorCommand = meanActuatorCommand
    self.peakActuatorCommand = peakActuatorCommand
    self.stabilizationDemand = stabilizationDemand
    self.success = success
  }
}

/// Immutable task-conditioned supervision for one off-rollout MLX update.
/// Each example spans several accepted physical roots: motor output is measured
/// over the complete horizon and its label is taken only from the terminal
/// vestibular consequence. The artifact is evidence, never rollout authority.
@frozen
public struct BrainPolicyNumanXDelayedSupportLearningArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1
  public static let objectiveIdentifier =
    "numibrain.numanx.delayed-support-stability.v1"

  public let formatVersion: UInt32
  public let objectiveIdentifier: String
  public let sourceRunArtifactSHA256: String
  public let taskFingerprint: UInt64
  public let sceneFingerprint: UInt64
  public let objectFingerprint: UInt64
  public let embodimentFingerprint: UInt64
  public let timestepMicroseconds: UInt32
  public let horizonRootCount: UInt32
  public let objectiveWeight: Float
  public let thresholds: BrainPolicyNumanXSupportStabilityThresholds
  public let examples: [BrainPolicyNumanXDelayedSupportExample]
  public let objectiveFingerprint: UInt64

  public init(
    sourceRunArtifactSHA256: String,
    coordinates: BrainPolicyNumanXDatasetCoordinates,
    timestepMicroseconds: UInt32,
    horizonRootCount: UInt32,
    objectiveWeight: Float,
    thresholds: BrainPolicyNumanXSupportStabilityThresholds,
    examples: [BrainPolicyNumanXDelayedSupportExample]
  ) throws {
    let examples = examples.sorted { $0.startControlStep < $1.startControlStep }
    let horizonsAreDisjoint = zip(examples, examples.dropFirst()).allSatisfy {
      pair in
      pair.0.consequenceControlStep < pair.1.startControlStep
    }
    guard BrainPolicyEvidenceArtifact.isSHA256(sourceRunArtifactSHA256),
      coordinates.taskFingerprint > 0,
      coordinates.sceneFingerprint > 0,
      coordinates.objectFingerprint > 0,
      coordinates.embodimentFingerprint > 0,
      timestepMicroseconds > 0,
      horizonRootCount >= 2,
      objectiveWeight.isFinite, objectiveWeight > 0,
      (1...32).contains(examples.count),
      Set(examples.map(\.startControlStep)).count == examples.count,
      horizonsAreDisjoint
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX delayed-support learning artifact is invalid"
      )
    }
    var fingerprint: UInt64 = 14_695_981_039_346_656_037
    Self.mix(UInt64(Self.formatVersion), into: &fingerprint)
    Self.mix(Self.objectiveIdentifier, into: &fingerprint)
    Self.mix(sourceRunArtifactSHA256, into: &fingerprint)
    for value in [
      coordinates.taskFingerprint, coordinates.sceneFingerprint,
      coordinates.objectFingerprint, coordinates.embodimentFingerprint,
      UInt64(timestepMicroseconds), UInt64(horizonRootCount),
      UInt64(objectiveWeight.bitPattern),
      UInt64(thresholds.minimumHeadGroundClearance.bitPattern),
      UInt64(thresholds.maximumHeadGroundClearance.bitPattern),
      UInt64(thresholds.maximumAbsoluteGroundNormalVelocity.bitPattern),
      UInt64(thresholds.maximumHeadQuaternionNormError.bitPattern),
    ] {
      Self.mix(value, into: &fingerprint)
    }
    for example in examples {
      Self.mix(UInt64(example.startControlStep), into: &fingerprint)
      Self.mix(UInt64(example.consequenceControlStep), into: &fingerprint)
      Self.mix(example.startSampleSHA256, into: &fingerprint)
      Self.mix(example.consequenceSampleSHA256, into: &fingerprint)
      Self.mix(example.horizonMicroseconds, into: &fingerprint)
      Self.mix(UInt64(example.startVestibularValidityMask), into: &fingerprint)
      Self.mix(example.startGroundNormalVelocity == nil ? 0 : 1, into: &fingerprint)
      if let startGroundNormalVelocity = example.startGroundNormalVelocity {
        Self.mix(UInt64(startGroundNormalVelocity.bitPattern), into: &fingerprint)
      }
      for value in [
        example.consequenceGroundNormalVelocity,
        example.consequenceHeadGroundClearance,
        example.consequenceQuaternionNormError,
        example.meanActuatorCommand,
        example.peakActuatorCommand,
        example.stabilizationDemand,
      ] {
        Self.mix(UInt64(value.bitPattern), into: &fingerprint)
      }
      Self.mix(example.success ? 1 : 0, into: &fingerprint)
    }
    guard fingerprint > 0 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX delayed-support fingerprint is zero"
      )
    }
    self.formatVersion = Self.formatVersion
    self.objectiveIdentifier = Self.objectiveIdentifier
    self.sourceRunArtifactSHA256 = sourceRunArtifactSHA256
    self.taskFingerprint = coordinates.taskFingerprint
    self.sceneFingerprint = coordinates.sceneFingerprint
    self.objectFingerprint = coordinates.objectFingerprint
    self.embodimentFingerprint = coordinates.embodimentFingerprint
    self.timestepMicroseconds = timestepMicroseconds
    self.horizonRootCount = horizonRootCount
    self.objectiveWeight = objectiveWeight
    self.thresholds = thresholds
    self.examples = examples
    self.objectiveFingerprint = fingerprint
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
      datasetSourceIdentifier: "delayed-support-validation",
      datasetSourceRevision: sourceRunArtifactSHA256,
      episodeIdentifier: 1,
      taskFingerprint: taskFingerprint,
      sceneFingerprint: sceneFingerprint,
      objectFingerprint: objectFingerprint,
      embodimentFingerprint: embodimentFingerprint
    )
    guard formatVersion == Self.formatVersion,
      objectiveIdentifier == Self.objectiveIdentifier,
      try Self(
        sourceRunArtifactSHA256: sourceRunArtifactSHA256,
        coordinates: coordinates,
        timestepMicroseconds: timestepMicroseconds,
        horizonRootCount: horizonRootCount,
        objectiveWeight: objectiveWeight,
        thresholds: thresholds,
        examples: examples
      ).objectiveFingerprint == objectiveFingerprint
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX delayed-support learning artifact is not canonical"
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

public enum BrainPolicyNumanXDelayedSupportLearningBuilder {
  public static func build(
    sourceRunArtifactSHA256: String,
    artifactDirectory: URL,
    horizonRootCount: UInt32,
    objectiveWeight: Float,
    thresholds: BrainPolicyNumanXSupportStabilityThresholds =
      .gateCFewShotSupportV1
  ) throws -> BrainPolicyNumanXDelayedSupportLearningArtifact {
    _ = try BrainPolicyNumanXCaptureVerifier.verify(
      runArtifactSHA256: sourceRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let run = try BrainPolicyNumanXCaptureRunArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: sourceRunArtifactSHA256,
        directory: artifactDirectory
      )
    )
    guard let timestepMicroseconds = run.timestepMicroseconds,
      horizonRootCount >= 2,
      let horizonCount = Int(exactly: horizonRootCount),
      run.roots.count >= horizonCount,
      run.roots.count.isMultiple(of: horizonCount),
      (1...32).contains(run.roots.count / horizonCount)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX delayed-support run does not form complete bounded horizons"
      )
    }
    let roots = run.roots.sorted { $0.controlStep < $1.controlStep }
    var coordinates: BrainPolicyNumanXDatasetCoordinates?
    var examples: [BrainPolicyNumanXDelayedSupportExample] = []
    examples.reserveCapacity(roots.count / horizonCount)
    for startIndex in stride(from: 0, to: roots.count, by: horizonCount) {
      let horizon = Array(roots[startIndex..<(startIndex + horizonCount)])
      guard let first = horizon.first, let last = horizon.last else { continue }
      let firstSample = try sample(first, directory: artifactDirectory)
      let lastSample = try sample(last, directory: artifactDirectory)
      if let coordinates {
        guard Self.sameTask(coordinates, firstSample.coordinates),
          Self.sameTask(coordinates, lastSample.coordinates)
        else {
          throw BrainRuntimeError.invalidParameterVersion(
            "NumanX delayed-support horizon changes task coordinates"
          )
        }
      } else {
        coordinates = firstSample.coordinates
      }
      let firstMeasurement = try vestibularMeasurement(
        first,
        sample: firstSample,
        directory: artifactDirectory
      )
      let consequence = try observation(
        last,
        sample: lastSample,
        thresholds: thresholds,
        directory: artifactDirectory
      )
      var actionSum: Double = 0
      var actionCount = 0
      var actionPeak: Float = 0
      for root in horizon {
        guard let motorActionArtifactSHA256 = root.motorActionArtifactSHA256 else {
          throw BrainRuntimeError.invalidParameterVersion(
            "NumanX delayed-support root lacks motor-action evidence"
          )
        }
        let action = try BrainPolicyNumanXMotorActionArtifact.decode(
          BrainPolicyNumanXCaptureVerifier.verifiedData(
            sha256: motorActionArtifactSHA256,
            directory: artifactDirectory
          )
        )
        guard action.controlStep == root.controlStep else {
          throw BrainRuntimeError.invalidParameterVersion(
            "NumanX delayed-support action belongs to another root"
          )
        }
        for command in action.actuatorCommands {
          actionSum += Double(command)
          actionCount += 1
          actionPeak = max(actionPeak, command)
        }
      }
      guard actionCount > 0,
        lastSample.targetTimestampMicroseconds
          > firstSample.committedTimestampMicroseconds
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX delayed-support horizon has no causal duration or action"
        )
      }
      let velocityDemand = min(
        abs(consequence.groundNormalVelocity)
          / thresholds.maximumAbsoluteGroundNormalVelocity,
        1
      )
      let clearanceSpan = thresholds.maximumHeadGroundClearance
        - thresholds.minimumHeadGroundClearance
      let clearanceDemand: Float
      if consequence.headGroundClearance
          < thresholds.minimumHeadGroundClearance
      {
        clearanceDemand = min(
          (thresholds.minimumHeadGroundClearance
            - consequence.headGroundClearance) / clearanceSpan,
          1
        )
      } else if consequence.headGroundClearance
          > thresholds.maximumHeadGroundClearance
      {
        clearanceDemand = min(
          (consequence.headGroundClearance
            - thresholds.maximumHeadGroundClearance) / clearanceSpan,
          1
        )
      } else {
        clearanceDemand = 0
      }
      let quaternionDemand = min(
        consequence.headQuaternionNormError
          / thresholds.maximumHeadQuaternionNormError,
        1
      )
      let demand = consequence.success
        ? max(velocityDemand, clearanceDemand, quaternionDemand) : 1
      examples.append(try BrainPolicyNumanXDelayedSupportExample(
        startControlStep: first.controlStep,
        consequenceControlStep: last.controlStep,
        startSampleSHA256: first.sampleSHA256,
        consequenceSampleSHA256: last.sampleSHA256,
        horizonMicroseconds: lastSample.targetTimestampMicroseconds
          - firstSample.committedTimestampMicroseconds,
        startVestibularValidityMask: firstMeasurement.validityMask,
        startGroundNormalVelocity: firstMeasurement.groundNormalVelocity,
        consequenceGroundNormalVelocity: consequence.groundNormalVelocity,
        consequenceHeadGroundClearance: consequence.headGroundClearance,
        consequenceQuaternionNormError: consequence.headQuaternionNormError,
        meanActuatorCommand: Float(actionSum / Double(actionCount)),
        peakActuatorCommand: actionPeak,
        stabilizationDemand: demand,
        success: consequence.success
      ))
    }
    guard let coordinates else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX delayed-support run has no task coordinates"
      )
    }
    return try BrainPolicyNumanXDelayedSupportLearningArtifact(
      sourceRunArtifactSHA256: sourceRunArtifactSHA256,
      coordinates: coordinates,
      timestepMicroseconds: timestepMicroseconds,
      horizonRootCount: horizonRootCount,
      objectiveWeight: objectiveWeight,
      thresholds: thresholds,
      examples: examples
    )
  }

  private static func sample(
    _ root: BrainPolicyNumanXCaptureRootReference,
    directory: URL
  ) throws -> BrainPolicyNumanXRootSampleArtifact {
    try BrainPolicyNumanXRootSampleArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: root.sampleSHA256,
        directory: directory
      )
    )
  }

  private static func observation(
    _ root: BrainPolicyNumanXCaptureRootReference,
    sample: BrainPolicyNumanXRootSampleArtifact,
    thresholds: BrainPolicyNumanXSupportStabilityThresholds,
    directory: URL
  ) throws -> BrainPolicyNumanXSupportStabilityObservation {
    let execution = try BrainPolicyNumanXRootExecution.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: root.executionSHA256,
        directory: directory
      )
    )
    let measurement = try vestibularMeasurement(
      root,
      sample: sample,
      directory: directory
    )
    return try BrainPolicyNumanXSupportStabilityObservation(
      sampleSHA256: root.sampleSHA256,
      controlStep: root.controlStep,
      rootOutcome: execution.outcome,
      vestibularValidityMask: measurement.validityMask,
      headGroundClearance: measurement.headGroundClearance,
      groundNormalVelocity: measurement.rawGroundNormalVelocity,
      headQuaternionNormError: measurement.headQuaternionNormError,
      thresholds: thresholds
    )
  }

  private struct VestibularMeasurement {
    let validityMask: UInt32
    let headGroundClearance: Float
    let rawGroundNormalVelocity: Float
    let groundNormalVelocity: Float?
    let headQuaternionNormError: Float
  }

  private static func vestibularMeasurement(
    _ root: BrainPolicyNumanXCaptureRootReference,
    sample: BrainPolicyNumanXRootSampleArtifact,
    directory: URL
  ) throws -> VestibularMeasurement {
    guard let vestibular = sample.channels.first(where: {
      $0.modality == .vestibular
    }), vestibular.receptorCount == 1, vestibular.featureDimension == 22,
      let validityHash = vestibular.validitySHA256
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX delayed-support example lacks vestibular evidence"
      )
    }
    let values = try BrainPolicyNumanXCaptureVerifier.verifiedData(
      sha256: vestibular.valuesSHA256,
      directory: directory
    )
    let validity = try BrainPolicyNumanXCaptureVerifier.verifiedData(
      sha256: validityHash,
      directory: directory
    )
    guard values.count == 22 * MemoryLayout<Float>.stride,
      validity.count == MemoryLayout<UInt32>.stride
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX delayed-support vestibular evidence has the wrong shape"
      )
    }
    func float(_ index: Int) -> Float {
      values.withUnsafeBytes { bytes in
        Float(bitPattern: UInt32(littleEndian: bytes.loadUnaligned(
          fromByteOffset: index * MemoryLayout<UInt32>.stride,
          as: UInt32.self
        )))
      }
    }
    let quaternion = (16...19).map(float)
    let norm = sqrt(quaternion.reduce(0) { $0 + $1 * $1 })
    let mask = validity.withUnsafeBytes {
      UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self))
    }
    let clearance = float(20)
    let velocity = float(21)
    let quaternionError = abs(norm - 1)
    guard clearance.isFinite, velocity.isFinite, quaternionError.isFinite else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX delayed-support vestibular evidence is non-finite"
      )
    }
    return VestibularMeasurement(
      validityMask: mask,
      headGroundClearance: clearance,
      rawGroundNormalVelocity: velocity,
      groundNormalVelocity: (mask & (UInt32(1) << 21)) != 0 ? velocity : nil,
      headQuaternionNormError: quaternionError
    )
  }

  private static func sameTask(
    _ lhs: BrainPolicyNumanXDatasetCoordinates,
    _ rhs: BrainPolicyNumanXDatasetCoordinates
  ) -> Bool {
    lhs.taskFingerprint == rhs.taskFingerprint
      && lhs.sceneFingerprint == rhs.sceneFingerprint
      && lhs.objectFingerprint == rhs.objectFingerprint
      && lhs.embodimentFingerprint == rhs.embodimentFingerprint
  }
}

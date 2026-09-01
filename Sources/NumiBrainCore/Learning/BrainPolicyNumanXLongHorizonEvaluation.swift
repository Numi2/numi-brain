import Foundation

@frozen
public enum BrainPolicyNumanXLongHorizonPhase:
  String, Codable, CaseIterable, Sendable
{
  case warmup
  case delayedCue
  case delayedWait
  case delayedConsequence
  case interruptionBaseline
  case interruption
  case interruptionRecovery
  case aliasReference
  case aliasProbe
}

/// Pre-run authority for one long-horizon Gate C cohort. The protocol hash is
/// used as the capture run's dataset-source revision, so the axis, schedule,
/// candidate, physical coordinates, and thresholds exist before any outcome.
@frozen
public struct BrainPolicyNumanXLongHorizonProtocolArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1
  public static let minimumCohortCount: UInt32 = 10

  public let formatVersion: UInt32
  public let protocolIdentifier: String
  public let candidateArtifactSHA256: String
  public let axis: BrainPolicyQualificationAxis
  public let datasetSourceIdentifier: String
  public let episodeIdentifier: UInt64
  public let taskFingerprint: UInt64
  public let sceneFingerprint: UInt64
  public let objectFingerprint: UInt64
  public let embodimentFingerprint: UInt64
  public let timestepMicroseconds: UInt32
  public let cohortCount: UInt32
  public let supportThresholds: BrainPolicyNumanXSupportStabilityThresholds

  public init(
    protocolIdentifier: String,
    candidateArtifactSHA256: String,
    axis: BrainPolicyQualificationAxis,
    datasetSourceIdentifier: String,
    episodeIdentifier: UInt64,
    taskFingerprint: UInt64,
    sceneFingerprint: UInt64,
    objectFingerprint: UInt64,
    embodimentFingerprint: UInt64,
    timestepMicroseconds: UInt32,
    cohortCount: UInt32,
    supportThresholds: BrainPolicyNumanXSupportStabilityThresholds =
      .gateCCrossSceneV1
  ) throws {
    guard !protocolIdentifier.isEmpty,
      BrainPolicyEvidenceArtifact.isSHA256(candidateArtifactSHA256),
      Self.rootsPerCohort(for: axis) != nil,
      !datasetSourceIdentifier.isEmpty, episodeIdentifier > 0,
      taskFingerprint > 0, sceneFingerprint > 0, objectFingerprint > 0,
      embodimentFingerprint > 0, timestepMicroseconds > 0,
      cohortCount >= Self.minimumCohortCount,
      cohortCount <= 10_000
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX long-horizon protocol is invalid"
      )
    }
    self.formatVersion = Self.formatVersion
    self.protocolIdentifier = protocolIdentifier
    self.candidateArtifactSHA256 = candidateArtifactSHA256
    self.axis = axis
    self.datasetSourceIdentifier = datasetSourceIdentifier
    self.episodeIdentifier = episodeIdentifier
    self.taskFingerprint = taskFingerprint
    self.sceneFingerprint = sceneFingerprint
    self.objectFingerprint = objectFingerprint
    self.embodimentFingerprint = embodimentFingerprint
    self.timestepMicroseconds = timestepMicroseconds
    self.cohortCount = cohortCount
    self.supportThresholds = supportThresholds
  }

  public var rootsPerCohort: UInt32 {
    Self.rootsPerCohort(for: axis)!
  }

  public var totalRootCount: UInt32 {
    let (cohortRoots, overflow) = cohortCount.multipliedReportingOverflow(
      by: rootsPerCohort
    )
    precondition(!overflow && cohortRoots < UInt32.max)
    return cohortRoots + 1
  }

  public func phase(controlStep: UInt32) throws
    -> (cohort: UInt32, phase: BrainPolicyNumanXLongHorizonPhase)
  {
    guard controlStep > 0, controlStep <= totalRootCount else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX long-horizon control step is outside the protocol"
      )
    }
    if controlStep == 1 { return (0, .warmup) }
    let offset = controlStep - 2
    let cohort = offset / rootsPerCohort + 1
    let phaseOffset = offset % rootsPerCohort
    let phase: BrainPolicyNumanXLongHorizonPhase =
      switch axis {
      case .delayedConsequences:
        switch phaseOffset {
        case 0: .delayedCue
        case rootsPerCohort - 1: .delayedConsequence
        default: .delayedWait
        }
      case .interruptedTasks:
        switch phaseOffset {
        case 0: .interruptionBaseline
        case 1: .interruption
        default: .interruptionRecovery
        }
      case .stateAliasing:
        phaseOffset == 0 ? .aliasReference : .aliasProbe
      default:
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX protocol axis is not long-horizon"
        )
      }
    return (cohort, phase)
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
    guard formatVersion == Self.formatVersion,
      try Self(
        protocolIdentifier: protocolIdentifier,
        candidateArtifactSHA256: candidateArtifactSHA256,
        axis: axis,
        datasetSourceIdentifier: datasetSourceIdentifier,
        episodeIdentifier: episodeIdentifier,
        taskFingerprint: taskFingerprint,
        sceneFingerprint: sceneFingerprint,
        objectFingerprint: objectFingerprint,
        embodimentFingerprint: embodimentFingerprint,
        timestepMicroseconds: timestepMicroseconds,
        cohortCount: cohortCount,
        supportThresholds: supportThresholds
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX long-horizon protocol is not canonical"
      )
    }
  }

  private static func rootsPerCohort(
    for axis: BrainPolicyQualificationAxis
  ) -> UInt32? {
    switch axis {
    case .delayedConsequences: 4
    case .interruptedTasks: 3
    case .stateAliasing: 2
    default: nil
    }
  }
}

/// Canonical copy of the actual external goal supplied to one captured root.
/// This is evidence only; it has no runtime or GPU authority.
@frozen
public struct BrainPolicyNumanXActiveGoalArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let identifier: UInt64
  public let origin: GoalOrigin
  public let targetState: [Float]
  public let priority: Float
  public let deadlineMicroseconds: UInt64?
  public let successModel: [Float]
  public let failureModel: [Float]
  public let damageRiskBudget: Float
  public let persistence: Float
  public let createdTimestampMicroseconds: UInt64
  public let targetBodyIdentifier: UInt32?

  public init(goal: ActiveGoal) throws {
    guard goal.identifier > 0, goal.targetState.values.count == 16,
      goal.successModel.values.count == 16,
      goal.failureModel.values.count == 16,
      goal.targetState.values.allSatisfy(\.isFinite),
      goal.successModel.values.allSatisfy(\.isFinite),
      goal.failureModel.values.allSatisfy(\.isFinite),
      goal.priority.isFinite, goal.priority >= 0,
      goal.damageRiskBudget.isFinite, goal.damageRiskBudget >= 0,
      goal.persistence.isFinite, (0...1).contains(goal.persistence),
      goal.deadline == nil || goal.deadline! >= goal.createdTimestamp
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX active-goal evidence is invalid"
      )
    }
    self.formatVersion = Self.formatVersion
    self.identifier = goal.identifier
    self.origin = goal.origin
    self.targetState = goal.targetState.values
    self.priority = goal.priority
    self.deadlineMicroseconds = goal.deadline?.rawValue
    self.successModel = goal.successModel.values
    self.failureModel = goal.failureModel.values
    self.damageRiskBudget = goal.damageRiskBudget
    self.persistence = goal.persistence
    self.createdTimestampMicroseconds = goal.createdTimestamp.rawValue
    self.targetBodyIdentifier = goal.targetBodyIdentifier
  }

  public var activeGoal: ActiveGoal {
    get throws {
      try ActiveGoal(
        identifier: identifier,
        origin: origin,
        targetState: BrainLatentVector(values: targetState, expectedCount: 16),
        priority: priority,
        deadline: deadlineMicroseconds.map(BrainTimestamp.init(microseconds:)),
        successModel: BrainLatentVector(values: successModel, expectedCount: 16),
        failureModel: BrainLatentVector(values: failureModel, expectedCount: 16),
        damageRiskBudget: damageRiskBudget,
        persistence: persistence,
        createdTimestamp: BrainTimestamp(
          microseconds: createdTimestampMicroseconds
        ),
        targetBodyIdentifier: targetBodyIdentifier
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
    let reconstructed = try Self(goal: activeGoal)
    guard formatVersion == Self.formatVersion, reconstructed == self else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX active-goal evidence is not canonical"
      )
    }
  }
}

public enum BrainPolicyNumanXLongHorizonProtocolVerifier {
  public static func verify(
    protocolArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXLongHorizonProtocolArtifact {
    let artifact = try BrainPolicyNumanXLongHorizonProtocolArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: protocolArtifactSHA256,
        directory: artifactDirectory
      )
    )
    _ = try BrainPolicyNumanXLearnedCandidateVerifier.verify(
      candidateArtifactSHA256: artifact.candidateArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    return artifact
  }
}

/// Recomputable evidence for one fixed long-horizon cohort. Semantic hashes
/// deliberately exclude root identity, timestamps, generations, and Metal
/// addresses. The retained memory hashes still name the complete verified
/// nine-section learning batch on both sides of every root.
@frozen
public struct BrainPolicyNumanXLongHorizonCohortObservation:
  Codable, Equatable, Sendable
{
  public let cohort: UInt32
  public let axis: BrainPolicyQualificationAxis
  public let phases: [BrainPolicyNumanXLongHorizonPhase]
  public let sampleSHA256: [String]
  public let rootOutcomes: [BrainPolicyNumanXRootOutcome]
  public let semanticSensorSHA256: [String]
  public let memoryBeforeSHA256: [String]
  public let memoryAfterSHA256: [String]
  public let semanticMotorActionSHA256: [String]
  public let externalGoalArtifactSHA256: [String?]
  public let supportStable: [Bool]
  public let semanticMotorActionDistance: Double
  public let success: Bool

  public init(
    cohort: UInt32,
    axis: BrainPolicyQualificationAxis,
    phases: [BrainPolicyNumanXLongHorizonPhase],
    sampleSHA256: [String],
    rootOutcomes: [BrainPolicyNumanXRootOutcome],
    semanticSensorSHA256: [String],
    memoryBeforeSHA256: [String],
    memoryAfterSHA256: [String],
    semanticMotorActionSHA256: [String],
    externalGoalArtifactSHA256: [String?],
    supportStable: [Bool],
    semanticMotorActionDistance: Double
  ) throws {
    let count = phases.count
    let expectedRoots = Self.rootsPerCohort(axis)
    let arraysHaveExactCount = [
      sampleSHA256.count, rootOutcomes.count, semanticSensorSHA256.count,
      memoryBeforeSHA256.count, memoryAfterSHA256.count,
      semanticMotorActionSHA256.count, externalGoalArtifactSHA256.count,
      supportStable.count,
    ].allSatisfy { $0 == count }
    let memoryIsContinuous = zip(
      memoryAfterSHA256.dropLast(), memoryBeforeSHA256.dropFirst()
    ).allSatisfy(==)
    guard cohort > 0, expectedRoots > 0, arraysHaveExactCount,
      count == Int(expectedRoots),
      sampleSHA256.allSatisfy(BrainPolicyEvidenceArtifact.isSHA256),
      semanticSensorSHA256.allSatisfy(
        BrainPolicyEvidenceArtifact.isSHA256
      ),
      memoryBeforeSHA256.allSatisfy(BrainPolicyEvidenceArtifact.isSHA256),
      memoryAfterSHA256.allSatisfy(BrainPolicyEvidenceArtifact.isSHA256),
      semanticMotorActionSHA256.allSatisfy(
        BrainPolicyEvidenceArtifact.isSHA256
      ),
      externalGoalArtifactSHA256.compactMap({ $0 }).allSatisfy(
        BrainPolicyEvidenceArtifact.isSHA256
      ),
      semanticMotorActionDistance.isFinite,
      semanticMotorActionDistance >= 0,
      memoryIsContinuous
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX long-horizon cohort evidence is invalid"
      )
    }
    self.cohort = cohort
    self.axis = axis
    self.phases = phases
    self.sampleSHA256 = sampleSHA256
    self.rootOutcomes = rootOutcomes
    self.semanticSensorSHA256 = semanticSensorSHA256
    self.memoryBeforeSHA256 = memoryBeforeSHA256
    self.memoryAfterSHA256 = memoryAfterSHA256
    self.semanticMotorActionSHA256 = semanticMotorActionSHA256
    self.externalGoalArtifactSHA256 = externalGoalArtifactSHA256
    self.supportStable = supportStable
    self.semanticMotorActionDistance = semanticMotorActionDistance
    self.success = Self.computedSuccess(
      axis: axis,
      phases: phases,
      rootOutcomes: rootOutcomes,
      semanticSensorSHA256: semanticSensorSHA256,
      memoryBeforeSHA256: memoryBeforeSHA256,
      memoryAfterSHA256: memoryAfterSHA256,
      semanticMotorActionSHA256: semanticMotorActionSHA256,
      externalGoalArtifactSHA256: externalGoalArtifactSHA256,
      supportStable: supportStable,
      semanticMotorActionDistance: semanticMotorActionDistance
    )
  }

  public func validate() throws {
    guard
      try Self(
        cohort: cohort,
        axis: axis,
        phases: phases,
        sampleSHA256: sampleSHA256,
        rootOutcomes: rootOutcomes,
        semanticSensorSHA256: semanticSensorSHA256,
        memoryBeforeSHA256: memoryBeforeSHA256,
        memoryAfterSHA256: memoryAfterSHA256,
        semanticMotorActionSHA256: semanticMotorActionSHA256,
        externalGoalArtifactSHA256: externalGoalArtifactSHA256,
        supportStable: supportStable,
        semanticMotorActionDistance: semanticMotorActionDistance
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX long-horizon cohort evidence is not canonical"
      )
    }
  }

  private static func rootsPerCohort(
    _ axis: BrainPolicyQualificationAxis
  ) -> UInt32 {
    switch axis {
    case .delayedConsequences: 4
    case .interruptedTasks: 3
    case .stateAliasing: 2
    default: 0
    }
  }

  private static func computedSuccess(
    axis: BrainPolicyQualificationAxis,
    phases: [BrainPolicyNumanXLongHorizonPhase],
    rootOutcomes: [BrainPolicyNumanXRootOutcome],
    semanticSensorSHA256: [String],
    memoryBeforeSHA256: [String],
    memoryAfterSHA256: [String],
    semanticMotorActionSHA256: [String],
    externalGoalArtifactSHA256: [String?],
    supportStable: [Bool],
    semanticMotorActionDistance: Double
  ) -> Bool {
    switch axis {
    case .stateAliasing:
      return phases == [.aliasReference, .aliasProbe]
        && rootOutcomes.allSatisfy { $0 == .accepted }
        && semanticSensorSHA256[0] == semanticSensorSHA256[1]
        && memoryBeforeSHA256[0] != memoryBeforeSHA256[1]
        && memoryAfterSHA256[0] == memoryBeforeSHA256[1]
        && semanticMotorActionSHA256[0] != semanticMotorActionSHA256[1]
        && semanticMotorActionDistance > 0
        && externalGoalArtifactSHA256.allSatisfy { $0 == nil }
        && supportStable.allSatisfy { $0 }
    case .interruptedTasks:
      return phases == [
        .interruptionBaseline, .interruption, .interruptionRecovery,
      ]
        && rootOutcomes == [.accepted, .rejected, .accepted]
        && memoryBeforeSHA256[1] == memoryAfterSHA256[1]
        && memoryAfterSHA256[1] == memoryBeforeSHA256[2]
        && externalGoalArtifactSHA256[0] != nil
        && externalGoalArtifactSHA256.dropFirst().allSatisfy { $0 == nil }
        && supportStable[0] && supportStable[2]
    case .delayedConsequences:
      return phases == [
        .delayedCue, .delayedWait, .delayedWait, .delayedConsequence,
      ]
        && rootOutcomes.allSatisfy { $0 == .accepted }
        && externalGoalArtifactSHA256[0] != nil
        && externalGoalArtifactSHA256.dropFirst().allSatisfy { $0 == nil }
        && semanticMotorActionSHA256[3] != semanticMotorActionSHA256[1]
        && semanticMotorActionSHA256[3] != semanticMotorActionSHA256[2]
        && semanticMotorActionDistance > 0
        && supportStable.allSatisfy { $0 }
    default:
      return false
    }
  }
}

/// One non-promotable, content-addressed long-horizon result. The sole metric
/// is the package-wide predeclared Gate C `success_rate >= 0.70` contract.
@frozen
public struct BrainPolicyNumanXLongHorizonEvaluationArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let candidateArtifactSHA256: String
  public let protocolArtifactSHA256: String
  public let captureRunArtifactSHA256: String
  public let axis: BrainPolicyQualificationAxis
  public let cohortObservations: [BrainPolicyNumanXLongHorizonCohortObservation]
  public let metrics: [BrainPolicyQualificationMetricEvidence]
  public let passesPredeclaredThresholds: Bool
  public let promotable: Bool

  public init(
    candidateArtifactSHA256: String,
    protocolArtifactSHA256: String,
    captureRunArtifactSHA256: String,
    axis: BrainPolicyQualificationAxis,
    cohortObservations: [BrainPolicyNumanXLongHorizonCohortObservation]
  ) throws {
    let canonical = cohortObservations.sorted { $0.cohort < $1.cohort }
    for observation in canonical { try observation.validate() }
    guard BrainPolicyEvidenceArtifact.isSHA256(candidateArtifactSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(protocolArtifactSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(captureRunArtifactSHA256),
      [.delayedConsequences, .interruptedTasks, .stateAliasing].contains(axis),
      canonical.count
        >= Int(BrainPolicyNumanXLongHorizonProtocolArtifact.minimumCohortCount),
      Set(canonical.map(\.cohort)).count == canonical.count,
      canonical.enumerated().allSatisfy({
        $0.element.cohort == UInt32($0.offset + 1)
          && $0.element.axis == axis
      })
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX long-horizon evaluation evidence is invalid"
      )
    }
    let successMetric = try BrainPolicyQualificationMetricEvidence(
      identifier: "success_rate",
      unit: "ratio",
      reducer: .mean,
      threshold: 0.7,
      direction: .atLeast,
      observations: canonical.map {
        try BrainPolicyMetricObservation(
          sampleSHA256: $0.sampleSHA256.last!,
          value: $0.success ? 1 : 0
        )
      }
    )
    self.formatVersion = Self.formatVersion
    self.candidateArtifactSHA256 = candidateArtifactSHA256
    self.protocolArtifactSHA256 = protocolArtifactSHA256
    self.captureRunArtifactSHA256 = captureRunArtifactSHA256
    self.axis = axis
    self.cohortObservations = canonical
    self.metrics = [successMetric]
    self.passesPredeclaredThresholds = successMetric.reducedValue >= 0.7
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
      cohortObservations.allSatisfy({ $0.axis == axis }),
      try Self(
        candidateArtifactSHA256: candidateArtifactSHA256,
        protocolArtifactSHA256: protocolArtifactSHA256,
        captureRunArtifactSHA256: captureRunArtifactSHA256,
        axis: axis,
        cohortObservations: cohortObservations
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX long-horizon evaluation artifact is not canonical"
      )
    }
  }
}

public struct BrainPolicyNumanXLongHorizonEvaluationReceipt: Sendable {
  public let evaluationArtifactSHA256: String
  public let candidateArtifactSHA256: String
  public let protocolArtifactSHA256: String
  public let captureRunArtifactSHA256: String
  public let axis: BrainPolicyQualificationAxis
  public let cohortCount: UInt64
  public let successfulCohortCount: UInt64
  public let successRate: Double
  public let passesPredeclaredThresholds: Bool
  public let transitiveEvidenceSHA256: String
}

public enum BrainPolicyNumanXLongHorizonEvaluator {
  public static func evaluateAndWrite(
    candidateArtifactSHA256: String,
    protocolArtifactSHA256: String,
    captureRunArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXLongHorizonEvaluationReceipt {
    try evaluate(
      candidateArtifactSHA256: candidateArtifactSHA256,
      protocolArtifactSHA256: protocolArtifactSHA256,
      captureRunArtifactSHA256: captureRunArtifactSHA256,
      artifactDirectory: artifactDirectory,
      writeArtifact: true
    )
  }

  public static func verify(
    evaluationArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXLongHorizonEvaluationReceipt {
    let stored = try BrainPolicyNumanXLongHorizonEvaluationArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: evaluationArtifactSHA256,
        directory: artifactDirectory
      )
    )
    let receipt = try evaluate(
      candidateArtifactSHA256: stored.candidateArtifactSHA256,
      protocolArtifactSHA256: stored.protocolArtifactSHA256,
      captureRunArtifactSHA256: stored.captureRunArtifactSHA256,
      artifactDirectory: artifactDirectory,
      writeArtifact: false
    )
    guard receipt.evaluationArtifactSHA256 == evaluationArtifactSHA256 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX long-horizon evaluation does not recompute byte-identically"
      )
    }
    return receipt
  }

  private struct SemanticSensorChannel: Codable {
    let modality: UInt16
    let receptorCount: UInt32
    let featureDimension: UInt32
    let valuesSHA256: String
    let validitySHA256: String?
  }

  private struct SemanticMotorAction: Codable {
    let protectiveFlags: UInt32
    let protectiveInterruptMask: UInt64
    let motorInhibition: Float
    let autonomicArousal: Float
    let actuatorCommandKind: UInt16
    let learnedDescendingCommands: [Float]
    let actuatorCommands: [Float]
    let autonomicCommands: [Float]
    let activeSensingCommands: [Float]
  }

  private static func evaluate(
    candidateArtifactSHA256: String,
    protocolArtifactSHA256: String,
    captureRunArtifactSHA256: String,
    artifactDirectory: URL,
    writeArtifact: Bool
  ) throws -> BrainPolicyNumanXLongHorizonEvaluationReceipt {
    let candidateReceipt = try BrainPolicyNumanXLearnedCandidateVerifier.verify(
      candidateArtifactSHA256: candidateArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let candidate =
      try BrainPolicyNumanXLearnedCandidateVerifier
      .verifiedCandidate(
        candidateArtifactSHA256: candidateArtifactSHA256,
        artifactDirectory: artifactDirectory
      )
    let protocolArtifact =
      try BrainPolicyNumanXLongHorizonProtocolVerifier
      .verify(
        protocolArtifactSHA256: protocolArtifactSHA256,
        artifactDirectory: artifactDirectory
      )
    let runReceipt = try BrainPolicyNumanXCaptureVerifier.verify(
      runArtifactSHA256: captureRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let run = try BrainPolicyNumanXCaptureRunArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: captureRunArtifactSHA256,
        directory: artifactDirectory
      )
    )
    guard protocolArtifact.candidateArtifactSHA256 == candidateArtifactSHA256,
      run.datasetSourceRevision == protocolArtifactSHA256,
      run.parameterVersionFingerprint
        == candidate.learnerUpdate.candidateVersion.fingerprint,
      run.roots.count == Int(protocolArtifact.totalRootCount)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX long-horizon run does not bind its candidate and protocol"
      )
    }
    let support = try BrainPolicyNumanXSupportStabilityEvaluator.observations(
      run,
      thresholds: protocolArtifact.supportThresholds,
      artifactDirectory: artifactDirectory
    )
    let supportByStep = Dictionary(
      uniqueKeysWithValues: support.map {
        ($0.controlStep, $0.success)
      })
    var observations: [BrainPolicyNumanXLongHorizonCohortObservation] = []
    observations.reserveCapacity(Int(protocolArtifact.cohortCount))
    for cohort in UInt32(1)...protocolArtifact.cohortCount {
      let roots = run.roots.filter { $0.longHorizonCohort == cohort }
        .sorted { $0.controlStep < $1.controlStep }
      guard roots.count == Int(protocolArtifact.rootsPerCohort) else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX long-horizon cohort is incomplete"
        )
      }
      var phases: [BrainPolicyNumanXLongHorizonPhase] = []
      var samples: [String] = []
      var outcomes: [BrainPolicyNumanXRootOutcome] = []
      var semanticSensors: [String] = []
      var memoryBefore: [String] = []
      var memoryAfter: [String] = []
      var semanticActions: [String] = []
      var actionVectors: [[Float]] = []
      var goals: [String?] = []
      var supportStable: [Bool] = []
      for root in roots {
        guard let phase = root.longHorizonPhase,
          let before = root.memoryBeforeLearningBatchArtifactSHA256,
          let after = root.memoryAfterLearningBatchArtifactSHA256,
          let actionHash = root.motorActionArtifactSHA256
        else {
          throw BrainRuntimeError.invalidParameterVersion(
            "NumanX long-horizon root lacks semantic evidence"
          )
        }
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
        let action = try BrainPolicyNumanXMotorActionArtifact.decode(
          BrainPolicyNumanXCaptureVerifier.verifiedData(
            sha256: actionHash,
            directory: artifactDirectory
          )
        )
        phases.append(phase)
        samples.append(root.sampleSHA256)
        outcomes.append(execution.outcome)
        semanticSensors.append(try semanticSensorSHA256(sample))
        memoryBefore.append(before)
        memoryAfter.append(after)
        semanticActions.append(try semanticMotorActionSHA256(action))
        actionVectors.append(actionVector(action))
        goals.append(root.externalGoalArtifactSHA256)
        supportStable.append(supportByStep[root.controlStep] == true)
      }
      let distance: Double =
        switch protocolArtifact.axis {
        case .stateAliasing:
          try motorDistance(actionVectors[0], actionVectors[1])
        case .delayedConsequences:
          max(
            try motorDistance(actionVectors[3], actionVectors[1]),
            try motorDistance(actionVectors[3], actionVectors[2])
          )
        case .interruptedTasks:
          try motorDistance(actionVectors[0], actionVectors[2])
        default: 0
        }
      observations.append(
        try BrainPolicyNumanXLongHorizonCohortObservation(
          cohort: cohort,
          axis: protocolArtifact.axis,
          phases: phases,
          sampleSHA256: samples,
          rootOutcomes: outcomes,
          semanticSensorSHA256: semanticSensors,
          memoryBeforeSHA256: memoryBefore,
          memoryAfterSHA256: memoryAfter,
          semanticMotorActionSHA256: semanticActions,
          externalGoalArtifactSHA256: goals,
          supportStable: supportStable,
          semanticMotorActionDistance: distance
        ))
    }
    let artifact = try BrainPolicyNumanXLongHorizonEvaluationArtifact(
      candidateArtifactSHA256: candidateArtifactSHA256,
      protocolArtifactSHA256: protocolArtifactSHA256,
      captureRunArtifactSHA256: captureRunArtifactSHA256,
      axis: protocolArtifact.axis,
      cohortObservations: observations
    )
    let hash =
      writeArtifact
      ? try artifact.write(to: artifactDirectory)
      : BrainPolicyEvidenceArtifact.sha256(try artifact.encoded())
    var transitive = Data()
    for value in [
      hash, candidateArtifactSHA256, protocolArtifactSHA256,
      captureRunArtifactSHA256, candidateReceipt.transitiveEvidenceSHA256,
      runReceipt.transitiveEvidenceSHA256,
    ].sorted() { transitive.append(Data(value.utf8)) }
    let successes = observations.filter(\.success).count
    return BrainPolicyNumanXLongHorizonEvaluationReceipt(
      evaluationArtifactSHA256: hash,
      candidateArtifactSHA256: candidateArtifactSHA256,
      protocolArtifactSHA256: protocolArtifactSHA256,
      captureRunArtifactSHA256: captureRunArtifactSHA256,
      axis: protocolArtifact.axis,
      cohortCount: UInt64(observations.count),
      successfulCohortCount: UInt64(successes),
      successRate: artifact.metrics[0].reducedValue,
      passesPredeclaredThresholds: artifact.passesPredeclaredThresholds,
      transitiveEvidenceSHA256: BrainPolicyEvidenceArtifact.sha256(transitive)
    )
  }

  private static func semanticSensorSHA256(
    _ sample: BrainPolicyNumanXRootSampleArtifact
  ) throws -> String {
    let semantic = sample.channels.sorted {
      $0.modality.rawValue < $1.modality.rawValue
    }.map {
      SemanticSensorChannel(
        modality: $0.modality.rawValue,
        receptorCount: $0.receptorCount,
        featureDimension: $0.featureDimension,
        valuesSHA256: $0.valuesSHA256,
        validitySHA256: $0.validitySHA256
      )
    }
    return BrainPolicyEvidenceArtifact.sha256(
      try BrainPolicyEvidenceArtifact.encodeCanonical(semantic)
    )
  }

  private static func semanticMotorActionSHA256(
    _ action: BrainPolicyNumanXMotorActionArtifact
  ) throws -> String {
    BrainPolicyEvidenceArtifact.sha256(
      try BrainPolicyEvidenceArtifact.encodeCanonical(
        SemanticMotorAction(
          protectiveFlags: action.protectiveFlags,
          protectiveInterruptMask: action.protectiveInterruptMask,
          motorInhibition: action.motorInhibition,
          autonomicArousal: action.autonomicArousal,
          actuatorCommandKind: action.actuatorCommandKind,
          learnedDescendingCommands: action.learnedDescendingCommands,
          actuatorCommands: action.actuatorCommands,
          autonomicCommands: action.autonomicCommands,
          activeSensingCommands: action.activeSensingCommands
        ))
    )
  }

  private static func actionVector(
    _ action: BrainPolicyNumanXMotorActionArtifact
  ) -> [Float] {
    action.learnedDescendingCommands + action.actuatorCommands
      + action.autonomicCommands + action.activeSensingCommands
      + [action.motorInhibition, action.autonomicArousal]
  }

  private static func motorDistance(_ lhs: [Float], _ rhs: [Float]) throws
    -> Double
  {
    guard lhs.count == rhs.count, !lhs.isEmpty else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX semantic motor actions have incompatible shapes"
      )
    }
    return sqrt(
      zip(lhs, rhs).reduce(0.0) {
        let difference = Double($1.0) - Double($1.1)
        return $0 + difference * difference
      })
  }
}

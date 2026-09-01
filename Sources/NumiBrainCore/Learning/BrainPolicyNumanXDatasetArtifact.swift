import CryptoKit
import Darwin
import Foundation

/// Dataset coordinates are explicit evidence, not inferred from file names or
/// run order. Every Gate C partition must retain independent task, scene,
/// object, and embodiment identities so disjointness can be reproduced.
@frozen
public struct BrainPolicyNumanXDatasetCoordinates:
  Codable, Equatable, Sendable
{
  public let datasetSourceIdentifier: String
  public let datasetSourceRevision: String
  public let episodeIdentifier: UInt64
  public let taskFingerprint: UInt64
  public let sceneFingerprint: UInt64
  public let objectFingerprint: UInt64
  public let embodimentFingerprint: UInt64

  public init(
    datasetSourceIdentifier: String,
    datasetSourceRevision: String,
    episodeIdentifier: UInt64,
    taskFingerprint: UInt64,
    sceneFingerprint: UInt64,
    objectFingerprint: UInt64,
    embodimentFingerprint: UInt64
  ) throws {
    guard !datasetSourceIdentifier.isEmpty, !datasetSourceRevision.isEmpty,
      episodeIdentifier > 0,
      taskFingerprint > 0, sceneFingerprint > 0, objectFingerprint > 0,
      embodimentFingerprint > 0
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX dataset coordinates are incomplete"
      )
    }
    self.datasetSourceIdentifier = datasetSourceIdentifier
    self.datasetSourceRevision = datasetSourceRevision
    self.episodeIdentifier = episodeIdentifier
    self.taskFingerprint = taskFingerprint
    self.sceneFingerprint = sceneFingerprint
    self.objectFingerprint = objectFingerprint
    self.embodimentFingerprint = embodimentFingerprint
  }
}

@frozen
public struct BrainPolicyNumanXCaptureRootReference:
  Codable, Equatable, Sendable
{
  public let controlStep: UInt32
  public let sampleSHA256: String
  public let executionSHA256: String
  /// Measured Metal execution duration for the cognitive decision command
  /// buffer. Optional only for byte-compatible verification of older captures.
  public let inferenceLatencyMicroseconds: Double?
  /// Present only for a predeclared uncertainty/OOD capture. Class 0 is the
  /// in-distribution control and class 1 is the held intervention.
  public let oodReferenceClass: UInt32?
  public let uncertaintyScore: Double?
  public let supervisionRequired: Bool?
  public let uncertaintyRootRejected: Bool?
  /// Present only for a retained hard-safety red-team root. The exact private
  /// command/output fingerprints bind the GPU overlay observed before the
  /// physical owner consumed the candidate.
  public let hardSafetyChallenge: Bool?
  public let protectiveCommandFingerprint: UInt64?
  public let protectiveOutputFingerprint: UInt64?
  public let protectiveInterruptMask: UInt64?
  public let learnedDescendingPeak: Double?
  public let protectiveBypass: Bool?
  public let safetyViolation: Bool?
  /// New long-horizon captures retain the complete committed memory batch on
  /// both sides of every authoritative root. Older format-v2 captures decode
  /// these as nil and cannot qualify a memory-dependent Gate C axis.
  public let memoryBeforeLearningBatchArtifactSHA256: String?
  public let memoryAfterLearningBatchArtifactSHA256: String?
  /// Content-addressed, identity-free motor values observed after the exact
  /// GPU motor gate completed. This deliberately excludes buffer addresses,
  /// transaction fingerprints, and generations so aliased observations can
  /// be compared semantically across distinct roots.
  public let motorActionArtifactSHA256: String?
  /// The optional goal hash names the exact external-goal bytes supplied to
  /// this root. Protocol fields remain present only for a pre-run long-horizon
  /// assignment; ordinary task-conditioned captures retain the goal without
  /// fabricating a protocol.
  public let longHorizonProtocolArtifactSHA256: String?
  public let longHorizonCohort: UInt32?
  public let longHorizonPhase: BrainPolicyNumanXLongHorizonPhase?
  public let externalGoalArtifactSHA256: String?

  public init(
    controlStep: UInt32,
    sampleSHA256: String,
    executionSHA256: String,
    inferenceLatencyMicroseconds: Double? = nil,
    oodReferenceClass: UInt32? = nil,
    uncertaintyScore: Double? = nil,
    supervisionRequired: Bool? = nil,
    uncertaintyRootRejected: Bool? = nil,
    hardSafetyChallenge: Bool? = nil,
    protectiveCommandFingerprint: UInt64? = nil,
    protectiveOutputFingerprint: UInt64? = nil,
    protectiveInterruptMask: UInt64? = nil,
    learnedDescendingPeak: Double? = nil,
    protectiveBypass: Bool? = nil,
    safetyViolation: Bool? = nil,
    memoryBeforeLearningBatchArtifactSHA256: String? = nil,
    memoryAfterLearningBatchArtifactSHA256: String? = nil,
    motorActionArtifactSHA256: String? = nil,
    longHorizonProtocolArtifactSHA256: String? = nil,
    longHorizonCohort: UInt32? = nil,
    longHorizonPhase: BrainPolicyNumanXLongHorizonPhase? = nil,
    externalGoalArtifactSHA256: String? = nil
  ) throws {
    let hardSafetyFieldsArePresent = hardSafetyChallenge != nil
    let longHorizonFields = [
      memoryBeforeLearningBatchArtifactSHA256,
      memoryAfterLearningBatchArtifactSHA256,
      motorActionArtifactSHA256,
    ]
    let longHorizonFieldsArePresent = longHorizonFields[0] != nil
    let protocolFieldsArePresent = longHorizonProtocolArtifactSHA256 != nil
    guard controlStep > 0,
      BrainPolicyEvidenceArtifact.isSHA256(sampleSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(executionSHA256),
      inferenceLatencyMicroseconds == nil
        || (inferenceLatencyMicroseconds!.isFinite
          && inferenceLatencyMicroseconds! > 0),
      oodReferenceClass == nil || oodReferenceClass == 0 || oodReferenceClass == 1,
      (oodReferenceClass == nil) == (uncertaintyScore == nil),
      (oodReferenceClass == nil) == (supervisionRequired == nil),
      (oodReferenceClass == nil) == (uncertaintyRootRejected == nil),
      uncertaintyScore == nil
        || (uncertaintyScore!.isFinite
          && uncertaintyScore! >= 0 && uncertaintyScore! <= 1),
      hardSafetyFieldsArePresent == (protectiveCommandFingerprint != nil),
      hardSafetyFieldsArePresent == (protectiveOutputFingerprint != nil),
      hardSafetyFieldsArePresent == (protectiveInterruptMask != nil),
      hardSafetyFieldsArePresent == (learnedDescendingPeak != nil),
      hardSafetyFieldsArePresent == (protectiveBypass != nil),
      hardSafetyFieldsArePresent == (safetyViolation != nil),
      hardSafetyChallenge == nil || hardSafetyChallenge == true,
      protectiveCommandFingerprint == nil || protectiveCommandFingerprint! > 0,
      protectiveOutputFingerprint == nil || protectiveOutputFingerprint! > 0,
      protectiveInterruptMask == nil || protectiveInterruptMask! > 0,
      learnedDescendingPeak == nil
        || (learnedDescendingPeak!.isFinite && learnedDescendingPeak! >= 0),
      longHorizonFields.allSatisfy({ ($0 != nil) == longHorizonFieldsArePresent }),
      longHorizonFields.compactMap({ $0 }).allSatisfy(
        BrainPolicyEvidenceArtifact.isSHA256
      ),
      protocolFieldsArePresent == (longHorizonCohort != nil),
      protocolFieldsArePresent == (longHorizonPhase != nil),
      longHorizonProtocolArtifactSHA256 == nil
        || BrainPolicyEvidenceArtifact.isSHA256(
          longHorizonProtocolArtifactSHA256!
        ),
      externalGoalArtifactSHA256 == nil
        || BrainPolicyEvidenceArtifact.isSHA256(
          externalGoalArtifactSHA256!
        ),
      longHorizonCohort == nil
        || (longHorizonPhase == .warmup
          ? longHorizonCohort == 0 : longHorizonCohort! > 0)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX capture root reference is invalid"
      )
    }
    self.controlStep = controlStep
    self.sampleSHA256 = sampleSHA256
    self.executionSHA256 = executionSHA256
    self.inferenceLatencyMicroseconds = inferenceLatencyMicroseconds
    self.oodReferenceClass = oodReferenceClass
    self.uncertaintyScore = uncertaintyScore
    self.supervisionRequired = supervisionRequired
    self.uncertaintyRootRejected = uncertaintyRootRejected
    self.hardSafetyChallenge = hardSafetyChallenge
    self.protectiveCommandFingerprint = protectiveCommandFingerprint
    self.protectiveOutputFingerprint = protectiveOutputFingerprint
    self.protectiveInterruptMask = protectiveInterruptMask
    self.learnedDescendingPeak = learnedDescendingPeak
    self.protectiveBypass = protectiveBypass
    self.safetyViolation = safetyViolation
    self.memoryBeforeLearningBatchArtifactSHA256 =
      memoryBeforeLearningBatchArtifactSHA256
    self.memoryAfterLearningBatchArtifactSHA256 =
      memoryAfterLearningBatchArtifactSHA256
    self.motorActionArtifactSHA256 = motorActionArtifactSHA256
    self.longHorizonProtocolArtifactSHA256 =
      longHorizonProtocolArtifactSHA256
    self.longHorizonCohort = longHorizonCohort
    self.longHorizonPhase = longHorizonPhase
    self.externalGoalArtifactSHA256 = externalGoalArtifactSHA256
  }
}

/// Exact semantic motor values produced for one NumanX root after the motor
/// command buffer completed. The artifact is diagnostic evidence only; it has
/// no GPU address or publication authority.
@frozen
public struct BrainPolicyNumanXMotorActionArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let controlStep: UInt32
  public let protectiveFlags: UInt32
  public let protectiveInterruptMask: UInt64
  public let motorInhibition: Float
  public let autonomicArousal: Float
  public let actuatorCommandKind: UInt16
  public let learnedDescendingCommands: [Float]
  public let actuatorCommands: [Float]
  public let autonomicCommands: [Float]
  public let activeSensingCommands: [Float]

  public init(
    controlStep: UInt32,
    protectiveFlags: UInt32,
    protectiveInterruptMask: UInt64,
    motorInhibition: Float,
    autonomicArousal: Float,
    actuatorCommandKind: UInt16,
    learnedDescendingCommands: [Float],
    actuatorCommands: [Float],
    autonomicCommands: [Float],
    activeSensingCommands: [Float]
  ) throws {
    let vectors = [
      learnedDescendingCommands, actuatorCommands, autonomicCommands,
      activeSensingCommands,
    ]
    guard controlStep > 0,
      learnedDescendingCommands.count == actuatorCommands.count,
      !actuatorCommands.isEmpty, !autonomicCommands.isEmpty,
      !activeSensingCommands.isEmpty,
      vectors.allSatisfy({ $0.count <= 16_384 }),
      vectors.joined().allSatisfy(\.isFinite),
      motorInhibition.isFinite, (0...1).contains(motorInhibition),
      autonomicArousal.isFinite, (0...1).contains(autonomicArousal)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX semantic motor-action evidence is invalid"
      )
    }
    self.formatVersion = Self.formatVersion
    self.controlStep = controlStep
    self.protectiveFlags = protectiveFlags
    self.protectiveInterruptMask = protectiveInterruptMask
    self.motorInhibition = motorInhibition
    self.autonomicArousal = autonomicArousal
    self.actuatorCommandKind = actuatorCommandKind
    self.learnedDescendingCommands = learnedDescendingCommands
    self.actuatorCommands = actuatorCommands
    self.autonomicCommands = autonomicCommands
    self.activeSensingCommands = activeSensingCommands
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
        controlStep: controlStep,
        protectiveFlags: protectiveFlags,
        protectiveInterruptMask: protectiveInterruptMask,
        motorInhibition: motorInhibition,
        autonomicArousal: autonomicArousal,
        actuatorCommandKind: actuatorCommandKind,
        learnedDescendingCommands: learnedDescendingCommands,
        actuatorCommands: actuatorCommands,
        autonomicCommands: autonomicCommands,
        activeSensingCommands: activeSensingCommands
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX semantic motor-action artifact is not canonical"
      )
    }
  }
}

/// Retained non-promotable output of one authoritative capture campaign. It
/// transitively names every root input and terminal execution artifact while
/// preserving exact native model, runtime, and device identities.
@frozen
public struct BrainPolicyNumanXCaptureRunArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 2

  public let formatVersion: UInt32
  public let runIdentifier: String
  public let sourceRevision: String
  public let datasetSourceIdentifier: String
  public let datasetSourceRevision: String
  public let deviceRegistryID: UInt64
  public let nativeModelSourceFingerprint: UInt64
  public let acceptedStateProofProgramFingerprint: UInt64
  public let compiledSpeciesTemplateFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  /// Exact native integration step for new Gate C captures. This is optional
  /// only to preserve byte-identical verification of retained format-v2
  /// artifacts created before timestep provenance was added.
  public let timestepMicroseconds: UInt32?
  /// Evaluation budget frozen before the capture begins. Optional only for
  /// older runs and for Gate C axes that are not latency qualifications.
  public let declaredMaximumInferenceLatencyMicroseconds: UInt64?
  public let learningBatchArtifactSHA256: String
  public let learningBatchFingerprint: UInt64
  public let promotable: Bool
  public let roots: [BrainPolicyNumanXCaptureRootReference]

  public init(
    runIdentifier: String,
    sourceRevision: String,
    datasetSourceIdentifier: String,
    datasetSourceRevision: String,
    deviceRegistryID: UInt64,
    nativeModelSourceFingerprint: UInt64,
    acceptedStateProofProgramFingerprint: UInt64,
    compiledSpeciesTemplateFingerprint: UInt64,
    parameterVersionFingerprint: UInt64,
    timestepMicroseconds: UInt32? = nil,
    declaredMaximumInferenceLatencyMicroseconds: UInt64? = nil,
    learningBatchArtifactSHA256: String,
    learningBatchFingerprint: UInt64,
    roots: [BrainPolicyNumanXCaptureRootReference]
  ) throws {
    let canonicalRoots = roots.sorted { $0.controlStep < $1.controlStep }
    guard !runIdentifier.isEmpty, !sourceRevision.isEmpty,
      !datasetSourceIdentifier.isEmpty, !datasetSourceRevision.isEmpty,
      deviceRegistryID > 0, nativeModelSourceFingerprint > 0,
      acceptedStateProofProgramFingerprint > 0,
      compiledSpeciesTemplateFingerprint > 0,
      parameterVersionFingerprint > 0,
      timestepMicroseconds == nil || timestepMicroseconds! > 0,
      declaredMaximumInferenceLatencyMicroseconds == nil
        || declaredMaximumInferenceLatencyMicroseconds! > 0,
      !canonicalRoots.isEmpty,
      BrainPolicyEvidenceArtifact.isSHA256(learningBatchArtifactSHA256),
      learningBatchFingerprint > 0,
      Set(canonicalRoots.map(\.controlStep)).count == canonicalRoots.count,
      Set(canonicalRoots.map(\.sampleSHA256)).count == canonicalRoots.count,
      Set(canonicalRoots.map(\.executionSHA256)).count == canonicalRoots.count
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX capture run artifact is invalid"
      )
    }
    self.formatVersion = Self.formatVersion
    self.runIdentifier = runIdentifier
    self.sourceRevision = sourceRevision
    self.datasetSourceIdentifier = datasetSourceIdentifier
    self.datasetSourceRevision = datasetSourceRevision
    self.deviceRegistryID = deviceRegistryID
    self.nativeModelSourceFingerprint = nativeModelSourceFingerprint
    self.acceptedStateProofProgramFingerprint =
      acceptedStateProofProgramFingerprint
    self.compiledSpeciesTemplateFingerprint =
      compiledSpeciesTemplateFingerprint
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.timestepMicroseconds = timestepMicroseconds
    self.declaredMaximumInferenceLatencyMicroseconds =
      declaredMaximumInferenceLatencyMicroseconds
    self.learningBatchArtifactSHA256 = learningBatchArtifactSHA256
    self.learningBatchFingerprint = learningBatchFingerprint
    self.promotable = false
    self.roots = canonicalRoots
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
    let run = try JSONDecoder().decode(Self.self, from: data)
    try run.validate()
    return run
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion, !promotable,
      try Self(
        runIdentifier: runIdentifier,
        sourceRevision: sourceRevision,
        datasetSourceIdentifier: datasetSourceIdentifier,
        datasetSourceRevision: datasetSourceRevision,
        deviceRegistryID: deviceRegistryID,
        nativeModelSourceFingerprint: nativeModelSourceFingerprint,
        acceptedStateProofProgramFingerprint:
          acceptedStateProofProgramFingerprint,
        compiledSpeciesTemplateFingerprint: compiledSpeciesTemplateFingerprint,
        parameterVersionFingerprint: parameterVersionFingerprint,
        timestepMicroseconds: timestepMicroseconds,
        declaredMaximumInferenceLatencyMicroseconds:
          declaredMaximumInferenceLatencyMicroseconds,
        learningBatchArtifactSHA256: learningBatchArtifactSHA256,
        learningBatchFingerprint: learningBatchFingerprint,
        roots: roots
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX capture run artifact is not canonical"
      )
    }
  }
}

@frozen
public struct BrainPolicyNumanXLearningBatchSectionArtifact:
  Codable, Equatable, Sendable
{
  public let sectionIdentifier: UInt16
  public let recordFormatVersion: UInt32
  public let elementCount: UInt64
  public let elementStride: UInt64
  public let byteCount: UInt64
  public let contentSHA256: String

  public init(
    sectionIdentifier: UInt16,
    recordFormatVersion: UInt32,
    elementCount: UInt64,
    elementStride: UInt64,
    byteCount: UInt64,
    contentSHA256: String
  ) throws {
    let (expectedBytes, overflow) = elementCount.multipliedReportingOverflow(
      by: elementStride
    )
    guard sectionIdentifier > 0, recordFormatVersion > 0,
      elementCount > 0, elementStride > 0, !overflow,
      byteCount == expectedBytes,
      BrainPolicyEvidenceArtifact.isSHA256(contentSHA256)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX learning-batch section artifact is invalid"
      )
    }
    self.sectionIdentifier = sectionIdentifier
    self.recordFormatVersion = recordFormatVersion
    self.elementCount = elementCount
    self.elementStride = elementStride
    self.byteCount = byteCount
    self.contentSHA256 = contentSHA256
  }
}

@frozen
public struct BrainPolicyNumanXLearningBatchArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let learningBatchFormatVersion: UInt32
  public let sourceGeneration: UInt64
  public let speciesTemplateFingerprint: UInt64
  public let regionalProgramFingerprint: UInt64
  public let scheduleFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  public let regionalModuleCount: UInt64
  public let metadataFingerprint: UInt64
  public let contentFingerprint: UInt64
  public let batchFingerprint: UInt64
  public let sections: [BrainPolicyNumanXLearningBatchSectionArtifact]

  public init(
    learningBatchFormatVersion: UInt32,
    sourceGeneration: UInt64,
    speciesTemplateFingerprint: UInt64,
    regionalProgramFingerprint: UInt64,
    scheduleFingerprint: UInt64,
    parameterVersionFingerprint: UInt64,
    regionalModuleCount: UInt64,
    metadataFingerprint: UInt64,
    contentFingerprint: UInt64,
    batchFingerprint: UInt64,
    sections: [BrainPolicyNumanXLearningBatchSectionArtifact]
  ) throws {
    let canonicalSections = sections.sorted {
      $0.sectionIdentifier < $1.sectionIdentifier
    }
    // Source generation zero names the content-addressed developmental seed
    // memory before the first accepted control root. Learner updates still
    // fail closed on generation zero at the cohort/update boundary.
    guard learningBatchFormatVersion > 0,
      speciesTemplateFingerprint > 0, regionalProgramFingerprint > 0,
      scheduleFingerprint > 0, parameterVersionFingerprint > 0,
      regionalModuleCount > 0, metadataFingerprint > 0,
      contentFingerprint > 0, batchFingerprint > 0,
      canonicalSections.count == 9,
      Set(canonicalSections.map(\.sectionIdentifier)).count
        == canonicalSections.count
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX learning-batch artifact is invalid"
      )
    }
    self.formatVersion = Self.formatVersion
    self.learningBatchFormatVersion = learningBatchFormatVersion
    self.sourceGeneration = sourceGeneration
    self.speciesTemplateFingerprint = speciesTemplateFingerprint
    self.regionalProgramFingerprint = regionalProgramFingerprint
    self.scheduleFingerprint = scheduleFingerprint
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.regionalModuleCount = regionalModuleCount
    self.metadataFingerprint = metadataFingerprint
    self.contentFingerprint = contentFingerprint
    self.batchFingerprint = batchFingerprint
    self.sections = canonicalSections
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
        learningBatchFormatVersion: learningBatchFormatVersion,
        sourceGeneration: sourceGeneration,
        speciesTemplateFingerprint: speciesTemplateFingerprint,
        regionalProgramFingerprint: regionalProgramFingerprint,
        scheduleFingerprint: scheduleFingerprint,
        parameterVersionFingerprint: parameterVersionFingerprint,
        regionalModuleCount: regionalModuleCount,
        metadataFingerprint: metadataFingerprint,
        contentFingerprint: contentFingerprint,
        batchFingerprint: batchFingerprint,
        sections: sections
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX learning-batch artifact is not canonical"
      )
    }
  }
}

/// Content-addressed raw bytes for one causal sensor channel. Values and
/// validity are retained as separate artifacts so the manifest stays compact
/// and large vision tensors remain stream-verifiable.
@frozen
public struct BrainPolicyNumanXSensorChannelArtifact:
  Codable, Equatable, Sendable
{
  public let modality: SensoryModality
  public let receptorTimestampMicroseconds: UInt64
  public let receptorCount: UInt32
  public let featureDimension: UInt32
  public let valuesByteCount: UInt64
  public let valuesSHA256: String
  public let validityByteCount: UInt64
  public let validitySHA256: String?

  public init(
    modality: SensoryModality,
    receptorTimestampMicroseconds: UInt64,
    receptorCount: UInt32,
    featureDimension: UInt32,
    valuesByteCount: UInt64,
    valuesSHA256: String,
    validityByteCount: UInt64 = 0,
    validitySHA256: String? = nil
  ) throws {
    let (scalarCount, scalarOverflow) = UInt64(receptorCount)
      .multipliedReportingOverflow(by: UInt64(featureDimension))
    let (requiredValues, valueOverflow) = scalarCount
      .multipliedReportingOverflow(by: UInt64(MemoryLayout<Float>.stride))
    let (requiredValidity, validityOverflow) = UInt64(receptorCount)
      .multipliedReportingOverflow(by: UInt64(MemoryLayout<UInt32>.stride))
    guard receptorCount > 0, featureDimension > 0,
      !scalarOverflow, !valueOverflow, !validityOverflow,
      valuesByteCount == requiredValues,
      BrainPolicyEvidenceArtifact.isSHA256(valuesSHA256),
      (validitySHA256 == nil && validityByteCount == 0)
        || (validitySHA256 != nil
          && validityByteCount == requiredValidity
          && BrainPolicyEvidenceArtifact.isSHA256(validitySHA256!))
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX sensor channel artifact is invalid"
      )
    }
    self.modality = modality
    self.receptorTimestampMicroseconds = receptorTimestampMicroseconds
    self.receptorCount = receptorCount
    self.featureDimension = featureDimension
    self.valuesByteCount = valuesByteCount
    self.valuesSHA256 = valuesSHA256
    self.validityByteCount = validityByteCount
    self.validitySHA256 = validitySHA256
  }
}

/// Canonical input manifest for one authoritative NumanX root. Its own
/// content SHA-256 is the `sampleSHA256` recorded by the terminal root
/// transcript; callers never supply an unrelated hash string.
@frozen
public struct BrainPolicyNumanXRootSampleArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let coordinates: BrainPolicyNumanXDatasetCoordinates
  public let transactionFingerprint: UInt64
  public let controlStep: UInt32
  public let committedTimestampMicroseconds: UInt64
  public let targetTimestampMicroseconds: UInt64
  public let basePhysicsGeneration: UInt64
  public let acceptedPhysicsTokenFingerprint: UInt64
  public let physicsGeneration: UInt64
  public let speciesTemplateFingerprint: UInt64
  public let sensoryProfileFingerprint: UInt64
  public let sensorPacketFingerprint: UInt64
  public let channels: [BrainPolicyNumanXSensorChannelArtifact]

  public init(
    coordinates: BrainPolicyNumanXDatasetCoordinates,
    transactionFingerprint: UInt64,
    controlStep: UInt32,
    committedTimestampMicroseconds: UInt64,
    targetTimestampMicroseconds: UInt64,
    basePhysicsGeneration: UInt64,
    acceptedPhysicsTokenFingerprint: UInt64,
    physicsGeneration: UInt64,
    speciesTemplateFingerprint: UInt64,
    sensoryProfileFingerprint: UInt64,
    sensorPacketFingerprint: UInt64,
    channels: [BrainPolicyNumanXSensorChannelArtifact]
  ) throws {
    let canonicalChannels = channels.sorted {
      $0.modality.rawValue < $1.modality.rawValue
    }
    let (nextPhysicsGeneration, physicsGenerationOverflow) =
      basePhysicsGeneration.addingReportingOverflow(1)
    let physicsGenerationIsCanonical = acceptedPhysicsTokenFingerprint == 0
      ? physicsGeneration == basePhysicsGeneration
      : !physicsGenerationOverflow && physicsGeneration == nextPhysicsGeneration
    guard transactionFingerprint > 0,
      targetTimestampMicroseconds > committedTimestampMicroseconds,
      speciesTemplateFingerprint > 0, sensoryProfileFingerprint > 0,
      sensorPacketFingerprint > 0, !canonicalChannels.isEmpty,
      canonicalChannels.count <= 8,
      Set(canonicalChannels.map(\.modality)).count == canonicalChannels.count,
      physicsGenerationIsCanonical
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX root sample artifact is invalid"
      )
    }
    self.formatVersion = Self.formatVersion
    self.coordinates = coordinates
    self.transactionFingerprint = transactionFingerprint
    self.controlStep = controlStep
    self.committedTimestampMicroseconds = committedTimestampMicroseconds
    self.targetTimestampMicroseconds = targetTimestampMicroseconds
    self.basePhysicsGeneration = basePhysicsGeneration
    self.acceptedPhysicsTokenFingerprint = acceptedPhysicsTokenFingerprint
    self.physicsGeneration = physicsGeneration
    self.speciesTemplateFingerprint = speciesTemplateFingerprint
    self.sensoryProfileFingerprint = sensoryProfileFingerprint
    self.sensorPacketFingerprint = sensorPacketFingerprint
    self.channels = canonicalChannels
  }

  public func encoded() throws -> Data {
    try validate()
    return try BrainPolicyEvidenceArtifact.encodeCanonical(self)
  }

  public var sampleSHA256: String {
    get throws { BrainPolicyEvidenceArtifact.sha256(try encoded()) }
  }

  @discardableResult
  public func write(to artifactDirectory: URL) throws -> String {
    try BrainPolicyEvidenceArtifact.write(
      encoded(),
      to: artifactDirectory
    )
  }

  public static func decode(_ data: Data) throws -> Self {
    let artifact = try JSONDecoder().decode(Self.self, from: data)
    try artifact.validate()
    return artifact
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion,
      try Self(
        coordinates: coordinates,
        transactionFingerprint: transactionFingerprint,
        controlStep: controlStep,
        committedTimestampMicroseconds: committedTimestampMicroseconds,
        targetTimestampMicroseconds: targetTimestampMicroseconds,
        basePhysicsGeneration: basePhysicsGeneration,
        acceptedPhysicsTokenFingerprint: acceptedPhysicsTokenFingerprint,
        physicsGeneration: physicsGeneration,
        speciesTemplateFingerprint: speciesTemplateFingerprint,
        sensoryProfileFingerprint: sensoryProfileFingerprint,
        sensorPacketFingerprint: sensorPacketFingerprint,
        channels: channels
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX root sample artifact is not canonical"
      )
    }
  }
}

public struct BrainPolicyNumanXCaptureVerificationReceipt: Sendable {
  public let runArtifactSHA256: String
  public let rootCount: UInt64
  public let acceptedRootCount: UInt64
  public let rejectedRootCount: UInt64
  public let transitiveEvidenceSHA256: String
}

public enum BrainPolicyNumanXCaptureVerifier {
  private static let maximumArtifactBytes = 256 * 1024 * 1024

  public static func verify(
    runArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXCaptureVerificationReceipt {
    let run = try BrainPolicyNumanXCaptureRunArtifact.decode(
      verifiedData(
        sha256: runArtifactSHA256,
        directory: artifactDirectory
      )
    )
    var hashes = [runArtifactSHA256]
    let retainedLearningBatch = try verifiedLearningBatch(
      sha256: run.learningBatchArtifactSHA256,
      expectedParameterVersionFingerprint: run.parameterVersionFingerprint,
      artifactDirectory: artifactDirectory
    )
    let learningBatch = retainedLearningBatch.artifact
    guard learningBatch.batchFingerprint == run.learningBatchFingerprint,
      learningBatch.parameterVersionFingerprint
        == run.parameterVersionFingerprint
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX capture run does not bind its exact learning batch"
      )
    }
    hashes.append(contentsOf: retainedLearningBatch.hashes)
    var accepted: UInt64 = 0
    var rejected: UInt64 = 0
    var previousMemoryAfter: String?
    var verifiedPreviousMemoryAfter: (
      sha256: String,
      batch: VerifiedLearningBatch
    )?
    var retainedLongHorizonProtocol:
      BrainPolicyNumanXLongHorizonProtocolArtifact?
    for root in run.roots {
      let sample = try BrainPolicyNumanXRootSampleArtifact.decode(
        verifiedData(
          sha256: root.sampleSHA256,
          directory: artifactDirectory
        )
      )
      let execution = try BrainPolicyNumanXRootExecution.decode(
        verifiedData(
          sha256: root.executionSHA256,
          directory: artifactDirectory
        )
      )
      guard sample.coordinates.datasetSourceIdentifier
          == run.datasetSourceIdentifier,
        sample.coordinates.datasetSourceRevision == run.datasetSourceRevision,
        sample.controlStep == root.controlStep,
        execution.controlStep == root.controlStep,
        execution.sampleSHA256 == root.sampleSHA256,
        execution.transactionFingerprint == sample.transactionFingerprint,
        run.timestepMicroseconds == nil
          || sample.targetTimestampMicroseconds
            - sample.committedTimestampMicroseconds
            == UInt64(run.timestepMicroseconds!)
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX capture root does not bind its exact sample and execution"
        )
      }
      switch execution.outcome {
      case .accepted: accepted += 1
      case .rejected: rejected += 1
      case .commandFailure:
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX capture run contains a command-failure execution"
        )
      }
      hashes.append(root.sampleSHA256)
      hashes.append(root.executionSHA256)
      if let beforeHash = root.memoryBeforeLearningBatchArtifactSHA256,
        let afterHash = root.memoryAfterLearningBatchArtifactSHA256,
        let actionHash = root.motorActionArtifactSHA256
      {
        let before: VerifiedLearningBatch
        if let retained = verifiedPreviousMemoryAfter,
          retained.sha256 == beforeHash
        {
          // Continuity makes this byte-identical to the prior root's already
          // hash-verified memoryAfter artifact. Reuse that exact value rather
          // than reading and hashing every retained section a second time.
          before = retained.batch
        } else {
          before = try verifiedLearningBatch(
            sha256: beforeHash,
            expectedParameterVersionFingerprint:
              run.parameterVersionFingerprint,
            artifactDirectory: artifactDirectory
          )
        }
        let after = if afterHash == beforeHash {
          before
        } else {
          try verifiedLearningBatch(
            sha256: afterHash,
            expectedParameterVersionFingerprint:
              run.parameterVersionFingerprint,
            artifactDirectory: artifactDirectory
          )
        }
        let action = try BrainPolicyNumanXMotorActionArtifact.decode(
          verifiedData(sha256: actionHash, directory: artifactDirectory)
        )
        guard action.controlStep == root.controlStep,
          previousMemoryAfter == nil || previousMemoryAfter == beforeHash,
          execution.outcome == .accepted
            ? beforeHash != afterHash : beforeHash == afterHash
        else {
          throw BrainRuntimeError.invalidParameterVersion(
            "NumanX long-horizon root evidence is discontinuous"
          )
        }
        previousMemoryAfter = afterHash
        verifiedPreviousMemoryAfter = (afterHash, after)
        hashes.append(contentsOf: before.hashes)
        hashes.append(contentsOf: after.hashes)
        hashes.append(actionHash)
      } else {
        previousMemoryAfter = nil
        verifiedPreviousMemoryAfter = nil
      }
      if let protocolHash = root.longHorizonProtocolArtifactSHA256,
        let cohort = root.longHorizonCohort,
        let phase = root.longHorizonPhase
      {
        let protocolArtifact = try BrainPolicyNumanXLongHorizonProtocolArtifact
          .decode(verifiedData(
            sha256: protocolHash,
            directory: artifactDirectory
          ))
        let expected = try protocolArtifact.phase(controlStep: root.controlStep)
        guard run.datasetSourceRevision == protocolHash,
          protocolArtifact.datasetSourceIdentifier
            == run.datasetSourceIdentifier,
          protocolArtifact.episodeIdentifier
            == sample.coordinates.episodeIdentifier,
          protocolArtifact.taskFingerprint
            == sample.coordinates.taskFingerprint,
          protocolArtifact.sceneFingerprint
            == sample.coordinates.sceneFingerprint,
          protocolArtifact.objectFingerprint
            == sample.coordinates.objectFingerprint,
          protocolArtifact.embodimentFingerprint
            == sample.coordinates.embodimentFingerprint,
          run.timestepMicroseconds == protocolArtifact.timestepMicroseconds,
          retainedLongHorizonProtocol == nil
            || retainedLongHorizonProtocol == protocolArtifact,
          cohort == expected.cohort, phase == expected.phase
        else {
          throw BrainRuntimeError.invalidParameterVersion(
            "NumanX root does not match its pre-run long-horizon protocol"
          )
        }
        retainedLongHorizonProtocol = protocolArtifact
        hashes.append(protocolHash)
        let requiresGoal: Bool = switch phase {
        case .warmup, .delayedCue, .interruptionBaseline: true
        default: false
        }
        guard (root.externalGoalArtifactSHA256 != nil) == requiresGoal else {
          throw BrainRuntimeError.invalidParameterVersion(
            "NumanX long-horizon phase has the wrong external-goal authority"
          )
        }
        if let goalHash = root.externalGoalArtifactSHA256 {
          let goal = try BrainPolicyNumanXActiveGoalArtifact.decode(
            verifiedData(sha256: goalHash, directory: artifactDirectory)
          )
          let expectedDeadline: UInt64
          if phase == .delayedCue {
            let (horizon, horizonOverflow) = UInt64(
              protocolArtifact.rootsPerCohort
            ).multipliedReportingOverflow(by: UInt64(
              protocolArtifact.timestepMicroseconds
            ))
            let (deadline, deadlineOverflow) = sample
              .committedTimestampMicroseconds.addingReportingOverflow(horizon)
            guard !horizonOverflow, !deadlineOverflow else {
              throw BrainRuntimeError.invalidParameterVersion(
                "NumanX delayed goal deadline overflows its protocol"
              )
            }
            expectedDeadline = deadline
          } else {
            expectedDeadline = sample.targetTimestampMicroseconds
          }
          guard goal.createdTimestampMicroseconds
              == sample.committedTimestampMicroseconds,
            goal.deadlineMicroseconds == expectedDeadline
          else {
            throw BrainRuntimeError.invalidParameterVersion(
              "NumanX long-horizon goal is not bound to its root timestamps"
            )
          }
          hashes.append(goalHash)
        }
      } else {
        if retainedLongHorizonProtocol != nil {
          throw BrainRuntimeError.invalidParameterVersion(
            "NumanX long-horizon run drops its protocol before completion"
          )
        }
        if let goalHash = root.externalGoalArtifactSHA256 {
          let goal = try BrainPolicyNumanXActiveGoalArtifact.decode(
            verifiedData(sha256: goalHash, directory: artifactDirectory)
          )
          guard goal.createdTimestampMicroseconds
              <= sample.targetTimestampMicroseconds,
            goal.deadlineMicroseconds == nil
              || goal.deadlineMicroseconds!
                >= sample.targetTimestampMicroseconds
          else {
            throw BrainRuntimeError.invalidParameterVersion(
              "NumanX external goal is not live at its captured root"
            )
          }
          hashes.append(goalHash)
        }
      }
      for channel in sample.channels {
        let values = try verifiedData(
          sha256: channel.valuesSHA256,
          directory: artifactDirectory
        )
        guard let valuesByteCount = Int(exactly: channel.valuesByteCount),
          values.count == valuesByteCount
        else {
          throw BrainRuntimeError.invalidParameterVersion(
            "NumanX capture sensor value artifact has the wrong length"
          )
        }
        hashes.append(channel.valuesSHA256)
        if let validitySHA256 = channel.validitySHA256 {
          let validity = try verifiedData(
            sha256: validitySHA256,
            directory: artifactDirectory
          )
          guard let validityByteCount = Int(exactly: channel.validityByteCount),
            validity.count == validityByteCount
          else {
            throw BrainRuntimeError.invalidParameterVersion(
              "NumanX capture sensor validity artifact has the wrong length"
            )
          }
          hashes.append(validitySHA256)
        }
      }
    }
    if let protocolArtifact = retainedLongHorizonProtocol {
      guard run.roots.count == Int(protocolArtifact.totalRootCount),
        run.roots.allSatisfy({
          $0.longHorizonProtocolArtifactSHA256 == run.datasetSourceRevision
        })
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX long-horizon run is incomplete"
        )
      }
    } else if run.roots.contains(where: {
      $0.longHorizonProtocolArtifactSHA256 != nil
    }) {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX long-horizon run has a partial protocol"
      )
    }
    var transitiveBytes = Data()
    for hash in Set(hashes).sorted() { transitiveBytes.append(Data(hash.utf8)) }
    return BrainPolicyNumanXCaptureVerificationReceipt(
      runArtifactSHA256: runArtifactSHA256,
      rootCount: UInt64(run.roots.count),
      acceptedRootCount: accepted,
      rejectedRootCount: rejected,
      transitiveEvidenceSHA256: BrainPolicyEvidenceArtifact.sha256(
        transitiveBytes
      )
    )
  }

  private struct VerifiedLearningBatch {
    let artifact: BrainPolicyNumanXLearningBatchArtifact
    let hashes: [String]
  }

  private static func verifiedLearningBatch(
    sha256: String,
    expectedParameterVersionFingerprint: UInt64,
    artifactDirectory: URL
  ) throws -> VerifiedLearningBatch {
    let artifact = try BrainPolicyNumanXLearningBatchArtifact.decode(
      verifiedData(sha256: sha256, directory: artifactDirectory)
    )
    guard artifact.parameterVersionFingerprint
        == expectedParameterVersionFingerprint
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX retained memory belongs to another parameter version"
      )
    }
    var hashes = [sha256]
    var sectionData: [UInt16: Data] = [:]
    for section in artifact.sections {
      let data = try verifiedData(
        sha256: section.contentSHA256,
        directory: artifactDirectory
      )
      guard let byteCount = Int(exactly: section.byteCount),
        data.count == byteCount
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX capture learning-batch section has the wrong length"
        )
      }
      sectionData[section.sectionIdentifier] = data
      hashes.append(section.contentSHA256)
    }
    try validateLearningBatchFingerprints(artifact, sectionData: sectionData)
    return VerifiedLearningBatch(artifact: artifact, hashes: hashes)
  }

  static func verifiedData(
    sha256: String,
    directory: URL
  ) throws -> Data {
    let url = try BrainPolicyEvidenceArtifact.url(
      forSHA256: sha256,
      in: directory
    )
    let descriptor = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
    guard descriptor >= 0 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX capture artifact is missing or unsafe"
      )
    }
    defer { Darwin.close(descriptor) }
    var metadata = stat()
    guard fstat(descriptor, &metadata) == 0,
      metadata.st_mode & S_IFMT == S_IFREG,
      metadata.st_size >= 0,
      metadata.st_size <= maximumArtifactBytes
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX capture artifact is not a bounded regular file"
      )
    }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
    var result = Data()
    result.reserveCapacity(Int(metadata.st_size))
    var hasher = SHA256()
    while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
      guard result.count <= maximumArtifactBytes - data.count else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX capture artifact exceeds the safety limit"
        )
      }
      hasher.update(data: data)
      result.append(data)
    }
    let actual = hasher.finalize().map {
      String(format: "%02x", $0)
    }.joined()
    guard actual == sha256 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX capture artifact is hash-mismatched"
      )
    }
    return result
  }

  /// Recomputes the exact little-endian FNV relation used by
  /// `MetalLearningBatch`. This keeps a retained batch independently
  /// verifiable after its originating Metal allocations and process are gone.
  /// Section identifiers are the stable on-disk ABI (1...9), so Core does not
  /// depend on the Metal module merely to verify evidence.
  static func validateLearningBatchFingerprints(
    _ artifact: BrainPolicyNumanXLearningBatchArtifact,
    sectionData: [UInt16: Data]
  ) throws {
    let sections = artifact.sections.sorted {
      $0.sectionIdentifier < $1.sectionIdentifier
    }
    guard sections.map(\.sectionIdentifier) == Array(UInt16(1)...UInt16(9)),
      Set(sectionData.keys) == Set(sections.map(\.sectionIdentifier)),
      sections.allSatisfy({ section in
        guard let bytes = sectionData[section.sectionIdentifier],
          let expected = Int(exactly: section.byteCount)
        else { return false }
        return bytes.count == expected
      }),
      sections[1].recordFormatVersion == sections[2].recordFormatVersion,
      sections[6].recordFormatVersion == sections[7].recordFormatVersion
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX learning-batch section ABI is not canonical"
      )
    }

    var metadata = fnvOffsetBasis
    for value in [
      UInt64(artifact.learningBatchFormatVersion),
      UInt64(sections[0].recordFormatVersion),
      UInt64(sections[1].recordFormatVersion),
      UInt64(sections[3].recordFormatVersion),
      UInt64(sections[4].recordFormatVersion),
      UInt64(sections[5].recordFormatVersion),
      UInt64(sections[6].recordFormatVersion),
      artifact.sourceGeneration,
      UInt64(sections[8].recordFormatVersion),
      artifact.regionalModuleCount,
      artifact.speciesTemplateFingerprint,
      artifact.regionalProgramFingerprint,
      artifact.scheduleFingerprint,
      artifact.parameterVersionFingerprint,
    ] {
      mixFNV(value, into: &metadata)
    }

    var content = fnvOffsetBasis
    for section in sections {
      mixFNV(UInt64(section.sectionIdentifier), into: &metadata)
      mixFNV(section.elementCount, into: &metadata)
      mixFNV(section.elementStride, into: &metadata)
      mixFNV(section.byteCount, into: &metadata)
      mixFNV(UInt64(section.sectionIdentifier), into: &content)
      for byte in sectionData[section.sectionIdentifier]! {
        content ^= UInt64(byte)
        content &*= fnvPrime
      }
    }
    var batch = metadata
    mixFNV(content, into: &batch)
    guard metadata == artifact.metadataFingerprint,
      content == artifact.contentFingerprint,
      batch == artifact.batchFingerprint
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX learning-batch retained bytes do not match their Metal fingerprints"
      )
    }
  }

  private static let fnvOffsetBasis: UInt64 = 14_695_981_039_346_656_037
  private static let fnvPrime: UInt64 = 1_099_511_628_211

  private static func mixFNV(_ value: UInt64, into hash: inout UInt64) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= fnvPrime
      }
    }
  }
}

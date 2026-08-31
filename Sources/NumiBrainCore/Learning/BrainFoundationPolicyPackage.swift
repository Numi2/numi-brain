import CryptoKit
import Foundation

@frozen
public enum BrainFoundationPolicyFamily: String, Codable, CaseIterable, Sendable {
  case visionLanguageAction
  case hierarchicalEmbodied
}

@frozen
public enum BrainPolicyGoalInterface: String, Codable, CaseIterable, Sendable {
  case structuredTask
  case language
  case demonstration
}

@frozen
public enum BrainPolicyActionGeneration: String, Codable, CaseIterable, Sendable {
  case chunked
  case diffusion
  case autoregressive
}

@frozen
public enum BrainPolicyInferencePrecision: String, Codable, CaseIterable, Sendable {
  case fp32
  case fp16
  case bf16
  case int8
}

@frozen
public enum BrainPolicyDatasetSourceKind: String, Codable, CaseIterable, Sendable {
  case simulated
  case real
  case independentlySourced
}

@frozen
public enum BrainPolicyDatasetPurpose: String, Codable, CaseIterable, Sendable {
  case multimodalPretraining
  case simulationDemonstration
  case embodiment
}

@frozen
public enum BrainPolicyDatasetSplit: String, Codable, CaseIterable, Sendable {
  case training
  case validation
  case heldOutTask
  case heldOutScene
  case heldOutObject
  case heldOutEmbodiment
  case adaptation
  case safety
}

@frozen
public enum BrainPolicyQualificationAxis: String, Codable, CaseIterable, Sendable {
  case actionGenerationLatency
  case crossTask
  case crossScene
  case crossObject
  case crossEmbodiment
  case fewShotAdaptation
  case delayedConsequences
  case interruptedTasks
  case stateAliasing
  case uncertaintyAndOOD
  case hardSafetyRetention
}

@frozen
public enum BrainPolicyMetricDirection: String, Codable, CaseIterable, Sendable {
  case atLeast
  case atMost
}

@frozen
public struct BrainFoundationPolicyArchitecture: Codable, Equatable, Sendable {
  public let family: BrainFoundationPolicyFamily
  public let modelIdentifier: String
  public let modelRevision: String
  public let modelWeightsSHA256: String
  public let speciesFingerprint: UInt64
  public let runtimeProgramFingerprint: UInt64
  public let lowLevelControllerFingerprint: UInt64
  public let hardSafetyProgramFingerprint: UInt64
  public let inputModalities: [SensoryModality]
  public let goalInterfaces: [BrainPolicyGoalInterface]
  public let actionGeneration: BrainPolicyActionGeneration
  public let actionHorizon: UInt32
  public let inferencePrecision: BrainPolicyInferencePrecision
  public let maximumInferenceLatencyMicroseconds: UInt64
  public let uncertaintyMethod: String
  public let supervisionRequestThreshold: Float
  public let rootRejectionThreshold: Float

  public init(
    family: BrainFoundationPolicyFamily,
    modelIdentifier: String,
    modelRevision: String,
    modelWeightsSHA256: String,
    speciesFingerprint: UInt64,
    runtimeProgramFingerprint: UInt64,
    lowLevelControllerFingerprint: UInt64,
    hardSafetyProgramFingerprint: UInt64,
    inputModalities: [SensoryModality],
    goalInterfaces: [BrainPolicyGoalInterface],
    actionGeneration: BrainPolicyActionGeneration,
    actionHorizon: UInt32,
    inferencePrecision: BrainPolicyInferencePrecision,
    maximumInferenceLatencyMicroseconds: UInt64,
    uncertaintyMethod: String,
    supervisionRequestThreshold: Float,
    rootRejectionThreshold: Float
  ) throws {
    let canonicalModalities = inputModalities.sorted { $0.rawValue < $1.rawValue }
    let canonicalGoalInterfaces = goalInterfaces.sorted { $0.rawValue < $1.rawValue }
    guard !modelIdentifier.isEmpty, !modelRevision.isEmpty,
      Self.isSHA256(modelWeightsSHA256), speciesFingerprint > 0,
      runtimeProgramFingerprint > 0, lowLevelControllerFingerprint > 0,
      hardSafetyProgramFingerprint > 0, !canonicalModalities.isEmpty,
      Set(canonicalModalities).count == canonicalModalities.count,
      !canonicalGoalInterfaces.isEmpty,
      Set(canonicalGoalInterfaces).count == canonicalGoalInterfaces.count,
      actionHorizon > 0, maximumInferenceLatencyMicroseconds > 0,
      !uncertaintyMethod.isEmpty, supervisionRequestThreshold.isFinite,
      rootRejectionThreshold.isFinite,
      supervisionRequestThreshold >= 0, supervisionRequestThreshold <= 1,
      rootRejectionThreshold >= supervisionRequestThreshold,
      rootRejectionThreshold <= 1
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "foundation-policy architecture is invalid"
      )
    }
    self.family = family
    self.modelIdentifier = modelIdentifier
    self.modelRevision = modelRevision
    self.modelWeightsSHA256 = modelWeightsSHA256
    self.speciesFingerprint = speciesFingerprint
    self.runtimeProgramFingerprint = runtimeProgramFingerprint
    self.lowLevelControllerFingerprint = lowLevelControllerFingerprint
    self.hardSafetyProgramFingerprint = hardSafetyProgramFingerprint
    self.inputModalities = canonicalModalities
    self.goalInterfaces = canonicalGoalInterfaces
    self.actionGeneration = actionGeneration
    self.actionHorizon = actionHorizon
    self.inferencePrecision = inferencePrecision
    self.maximumInferenceLatencyMicroseconds = maximumInferenceLatencyMicroseconds
    self.uncertaintyMethod = uncertaintyMethod
    self.supervisionRequestThreshold = supervisionRequestThreshold
    self.rootRejectionThreshold = rootRejectionThreshold
  }

  fileprivate func validate() throws {
    let rebuilt = try Self(
      family: family,
      modelIdentifier: modelIdentifier,
      modelRevision: modelRevision,
      modelWeightsSHA256: modelWeightsSHA256,
      speciesFingerprint: speciesFingerprint,
      runtimeProgramFingerprint: runtimeProgramFingerprint,
      lowLevelControllerFingerprint: lowLevelControllerFingerprint,
      hardSafetyProgramFingerprint: hardSafetyProgramFingerprint,
      inputModalities: inputModalities,
      goalInterfaces: goalInterfaces,
      actionGeneration: actionGeneration,
      actionHorizon: actionHorizon,
      inferencePrecision: inferencePrecision,
      maximumInferenceLatencyMicroseconds: maximumInferenceLatencyMicroseconds,
      uncertaintyMethod: uncertaintyMethod,
      supervisionRequestThreshold: supervisionRequestThreshold,
      rootRejectionThreshold: rootRejectionThreshold
    )
    guard rebuilt == self else {
      throw BrainRuntimeError.invalidParameterVersion(
        "foundation-policy architecture is not canonical"
      )
    }
  }

  fileprivate static func isSHA256(_ value: String) -> Bool {
    value.count == 64
      && value.allSatisfy {
        $0.isNumber || ("a"..."f").contains(String($0))
      }
  }
}

@frozen
public struct BrainPolicyDatasetSource: Codable, Equatable, Sendable {
  public let identifier: String
  public let revision: String
  public let sourceKind: BrainPolicyDatasetSourceKind
  public let purposes: [BrainPolicyDatasetPurpose]
  public let sourceURI: String
  public let licenseIdentifier: String
  public let contentSHA256: String

  public init(
    identifier: String,
    revision: String,
    sourceKind: BrainPolicyDatasetSourceKind,
    purposes: [BrainPolicyDatasetPurpose],
    sourceURI: String,
    licenseIdentifier: String,
    contentSHA256: String
  ) throws {
    let canonicalPurposes = purposes.sorted { $0.rawValue < $1.rawValue }
    guard !identifier.isEmpty, !revision.isEmpty, !canonicalPurposes.isEmpty,
      Set(canonicalPurposes).count == canonicalPurposes.count,
      let parsedURI = URL(string: sourceURI), parsedURI.scheme != nil,
      !licenseIdentifier.isEmpty,
      BrainFoundationPolicyArchitecture.isSHA256(contentSHA256)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "foundation-policy dataset source is invalid"
      )
    }
    self.identifier = identifier
    self.revision = revision
    self.sourceKind = sourceKind
    self.purposes = canonicalPurposes
    self.sourceURI = sourceURI
    self.licenseIdentifier = licenseIdentifier
    self.contentSHA256 = contentSHA256
  }

  fileprivate func validate() throws {
    guard
      try Self(
        identifier: identifier,
        revision: revision,
        sourceKind: sourceKind,
        purposes: purposes,
        sourceURI: sourceURI,
        licenseIdentifier: licenseIdentifier,
        contentSHA256: contentSHA256
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "foundation-policy dataset source is not canonical"
      )
    }
  }
}

@frozen
public struct BrainPolicyDatasetPartition: Codable, Equatable, Sendable {
  public let identifier: String
  public let split: BrainPolicyDatasetSplit
  public let datasetIdentifier: String
  public let membershipArtifactSHA256: String
  public let sampleCount: UInt64
  public let learnerBatchFingerprint: UInt64
  public let taskSetFingerprint: UInt64
  public let sceneSetFingerprint: UInt64
  public let objectSetFingerprint: UInt64
  public let embodimentSetFingerprint: UInt64

  public init(
    identifier: String,
    split: BrainPolicyDatasetSplit,
    datasetIdentifier: String,
    membershipArtifactSHA256: String,
    sampleCount: UInt64,
    learnerBatchFingerprint: UInt64,
    taskSetFingerprint: UInt64,
    sceneSetFingerprint: UInt64,
    objectSetFingerprint: UInt64,
    embodimentSetFingerprint: UInt64
  ) throws {
    guard !identifier.isEmpty, !datasetIdentifier.isEmpty,
      BrainFoundationPolicyArchitecture.isSHA256(membershipArtifactSHA256),
      sampleCount > 0,
      split == .training
        ? learnerBatchFingerprint > 0 : learnerBatchFingerprint == 0,
      taskSetFingerprint > 0, sceneSetFingerprint > 0,
      objectSetFingerprint > 0, embodimentSetFingerprint > 0
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "foundation-policy dataset partition is invalid"
      )
    }
    self.identifier = identifier
    self.split = split
    self.datasetIdentifier = datasetIdentifier
    self.membershipArtifactSHA256 = membershipArtifactSHA256
    self.sampleCount = sampleCount
    self.learnerBatchFingerprint = learnerBatchFingerprint
    self.taskSetFingerprint = taskSetFingerprint
    self.sceneSetFingerprint = sceneSetFingerprint
    self.objectSetFingerprint = objectSetFingerprint
    self.embodimentSetFingerprint = embodimentSetFingerprint
  }

  fileprivate func validate() throws {
    guard
      try Self(
        identifier: identifier,
        split: split,
        datasetIdentifier: datasetIdentifier,
        membershipArtifactSHA256: membershipArtifactSHA256,
        sampleCount: sampleCount,
        learnerBatchFingerprint: learnerBatchFingerprint,
        taskSetFingerprint: taskSetFingerprint,
        sceneSetFingerprint: sceneSetFingerprint,
        objectSetFingerprint: objectSetFingerprint,
        embodimentSetFingerprint: embodimentSetFingerprint
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "foundation-policy dataset partition is not canonical"
      )
    }
  }
}

@frozen
public struct BrainPolicyQualificationMetric: Codable, Equatable, Sendable {
  public let identifier: String
  public let unit: String
  public let value: Double
  public let threshold: Double
  public let direction: BrainPolicyMetricDirection

  public init(
    identifier: String,
    unit: String,
    value: Double,
    threshold: Double,
    direction: BrainPolicyMetricDirection
  ) throws {
    guard !identifier.isEmpty, !unit.isEmpty, value.isFinite, threshold.isFinite else {
      throw BrainRuntimeError.invalidParameterVersion(
        "foundation-policy qualification metric is invalid"
      )
    }
    self.identifier = identifier
    self.unit = unit
    self.value = value
    self.threshold = threshold
    self.direction = direction
  }

  public var passed: Bool {
    switch direction {
    case .atLeast: value >= threshold
    case .atMost: value <= threshold
    }
  }
}

@frozen
public struct BrainPolicyQualificationResult: Codable, Equatable, Sendable {
  public let axis: BrainPolicyQualificationAxis
  public let evaluationArtifactSHA256: String
  public let sampleCount: UInt64
  public let metrics: [BrainPolicyQualificationMetric]

  public init(
    axis: BrainPolicyQualificationAxis,
    evaluationArtifactSHA256: String,
    sampleCount: UInt64,
    metrics: [BrainPolicyQualificationMetric]
  ) throws {
    let canonicalMetrics = metrics.sorted { $0.identifier < $1.identifier }
    guard BrainFoundationPolicyArchitecture.isSHA256(evaluationArtifactSHA256),
      sampleCount > 0, !canonicalMetrics.isEmpty,
      Set(canonicalMetrics.map(\.identifier)).count == canonicalMetrics.count
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "foundation-policy qualification result is invalid"
      )
    }
    self.axis = axis
    self.evaluationArtifactSHA256 = evaluationArtifactSHA256
    self.sampleCount = sampleCount
    self.metrics = canonicalMetrics
  }

  public var passed: Bool { metrics.allSatisfy(\.passed) }

  fileprivate func validate() throws {
    guard
      try Self(
        axis: axis,
        evaluationArtifactSHA256: evaluationArtifactSHA256,
        sampleCount: sampleCount,
        metrics: metrics
      ) == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "foundation-policy qualification result is not canonical"
      )
    }
  }
}

@frozen
public struct BrainPackagedParameterPublication: Codable, Equatable, Sendable {
  public let version: BrainParameterVersion
  public let sharedArtifact: BrainSharedParameterArtifact
  public let learnerUpdateFingerprint: UInt64
  public let sourceBatchFingerprint: UInt64
  public let sourceMindCount: UInt32
  public let minimumSourceGeneration: UInt64
  public let sourceGeneration: UInt64

  public init(_ publication: BrainParameterPublication) throws {
    guard publication.learnerUpdateFingerprint > 0,
      publication.sourceBatchFingerprint > 0, publication.sourceMindCount > 0,
      publication.minimumSourceGeneration > 0,
      publication.minimumSourceGeneration <= publication.sourceGeneration
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "foundation-policy package requires a learned publication"
      )
    }
    self.version = publication.version
    self.sharedArtifact = publication.sharedArtifact
    self.learnerUpdateFingerprint = publication.learnerUpdateFingerprint
    self.sourceBatchFingerprint = publication.sourceBatchFingerprint
    self.sourceMindCount = publication.sourceMindCount
    self.minimumSourceGeneration = publication.minimumSourceGeneration
    self.sourceGeneration = publication.sourceGeneration
  }

  public func publication() throws -> BrainParameterPublication {
    try BrainParameterPublication(
      version: version,
      sharedArtifact: sharedArtifact,
      learnerUpdateFingerprint: learnerUpdateFingerprint,
      sourceBatchFingerprint: sourceBatchFingerprint,
      sourceMindCount: sourceMindCount,
      minimumSourceGeneration: minimumSourceGeneration,
      sourceGeneration: sourceGeneration
    )
  }

  fileprivate func validate() throws {
    guard try Self(publication()).version.fingerprint == version.fingerprint else {
      throw BrainRuntimeError.invalidParameterVersion(
        "packaged learned publication is invalid"
      )
    }
  }
}

/// Immutable, content-addressed deployment package for a learned embodied
/// policy. Structural validation permits offline inspection of candidates;
/// `validateGateCEvidenceManifest()` is the stricter manifest boundary and
/// rejects missing data classes, held-out splits, qualification axes, and
/// failed declared metrics. It does not replace independent verification of
/// the content-addressed evidence artifacts referenced by the manifest.
@frozen
public struct BrainFoundationPolicyPackage: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let packageIdentifier: String
  public let createdAtUnixMicroseconds: UInt64
  public let sourceRevision: String
  public let toolchainIdentifier: String
  public let architecture: BrainFoundationPolicyArchitecture
  public let parameterPublication: BrainPackagedParameterPublication
  public let datasetSources: [BrainPolicyDatasetSource]
  public let datasetPartitions: [BrainPolicyDatasetPartition]
  public let splitIntegrityReportSHA256: String
  public let qualificationResults: [BrainPolicyQualificationResult]
  public let packageContentSHA256: String

  private struct UnsignedPackage: Codable {
    let formatVersion: UInt32
    let packageIdentifier: String
    let createdAtUnixMicroseconds: UInt64
    let sourceRevision: String
    let toolchainIdentifier: String
    let architecture: BrainFoundationPolicyArchitecture
    let parameterPublication: BrainPackagedParameterPublication
    let datasetSources: [BrainPolicyDatasetSource]
    let datasetPartitions: [BrainPolicyDatasetPartition]
    let splitIntegrityReportSHA256: String
    let qualificationResults: [BrainPolicyQualificationResult]
  }

  public init(
    packageIdentifier: String,
    createdAtUnixMicroseconds: UInt64,
    sourceRevision: String,
    toolchainIdentifier: String,
    architecture: BrainFoundationPolicyArchitecture,
    parameterPublication: BrainParameterPublication,
    datasetSources: [BrainPolicyDatasetSource],
    datasetPartitions: [BrainPolicyDatasetPartition],
    splitIntegrityReportSHA256: String,
    qualificationResults: [BrainPolicyQualificationResult]
  ) throws {
    let packagedPublication = try BrainPackagedParameterPublication(parameterPublication)
    let weightsSHA256 = try Self.parameterWeightsSHA256(parameterPublication)
    let canonicalSources = datasetSources.sorted { $0.identifier < $1.identifier }
    let canonicalPartitions = datasetPartitions.sorted {
      $0.split.rawValue == $1.split.rawValue
        ? $0.identifier < $1.identifier
        : $0.split.rawValue < $1.split.rawValue
    }
    let canonicalResults = qualificationResults.sorted { $0.axis.rawValue < $1.axis.rawValue }
    guard !packageIdentifier.isEmpty, createdAtUnixMicroseconds > 0,
      !sourceRevision.isEmpty, !toolchainIdentifier.isEmpty,
      architecture.modelWeightsSHA256 == weightsSHA256,
      architecture.runtimeProgramFingerprint
        == parameterPublication.version.regionalProgramFingerprint,
      !canonicalSources.isEmpty,
      Set(canonicalSources.map(\.identifier)).count == canonicalSources.count,
      !canonicalPartitions.isEmpty,
      Set(canonicalPartitions.map(\.identifier)).count == canonicalPartitions.count,
      Set(canonicalPartitions.map(\.membershipArtifactSHA256)).count
        == canonicalPartitions.count,
      Set(canonicalResults.map(\.axis)).count == canonicalResults.count,
      BrainFoundationPolicyArchitecture.isSHA256(splitIntegrityReportSHA256)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "foundation-policy package identity is invalid"
      )
    }
    let sourceIdentifiers = Set(canonicalSources.map(\.identifier))
    guard
      canonicalPartitions.allSatisfy({
        sourceIdentifiers.contains($0.datasetIdentifier)
      })
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "foundation-policy partition references an unknown dataset"
      )
    }
    let unsigned = UnsignedPackage(
      formatVersion: Self.formatVersion,
      packageIdentifier: packageIdentifier,
      createdAtUnixMicroseconds: createdAtUnixMicroseconds,
      sourceRevision: sourceRevision,
      toolchainIdentifier: toolchainIdentifier,
      architecture: architecture,
      parameterPublication: packagedPublication,
      datasetSources: canonicalSources,
      datasetPartitions: canonicalPartitions,
      splitIntegrityReportSHA256: splitIntegrityReportSHA256,
      qualificationResults: canonicalResults
    )
    self.formatVersion = Self.formatVersion
    self.packageIdentifier = packageIdentifier
    self.createdAtUnixMicroseconds = createdAtUnixMicroseconds
    self.sourceRevision = sourceRevision
    self.toolchainIdentifier = toolchainIdentifier
    self.architecture = architecture
    self.parameterPublication = packagedPublication
    self.datasetSources = canonicalSources
    self.datasetPartitions = canonicalPartitions
    self.splitIntegrityReportSHA256 = splitIntegrityReportSHA256
    self.qualificationResults = canonicalResults
    self.packageContentSHA256 = try Self.sha256(Self.encodeCanonical(unsigned))
  }

  public var isGateCEvidenceManifestComplete: Bool {
    (try? validateGateCEvidenceManifest()) != nil
  }

  public func publication() throws -> BrainParameterPublication {
    try validate()
    return try parameterPublication.publication()
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion else {
      throw BrainRuntimeError.invalidParameterVersion(
        "foundation-policy package version is unsupported"
      )
    }
    try architecture.validate()
    try parameterPublication.validate()
    for source in datasetSources { try source.validate() }
    for partition in datasetPartitions { try partition.validate() }
    for result in qualificationResults { try result.validate() }
    let rebuilt = try Self(
      packageIdentifier: packageIdentifier,
      createdAtUnixMicroseconds: createdAtUnixMicroseconds,
      sourceRevision: sourceRevision,
      toolchainIdentifier: toolchainIdentifier,
      architecture: architecture,
      parameterPublication: parameterPublication.publication(),
      datasetSources: datasetSources,
      datasetPartitions: datasetPartitions,
      splitIntegrityReportSHA256: splitIntegrityReportSHA256,
      qualificationResults: qualificationResults
    )
    guard rebuilt.packageContentSHA256 == packageContentSHA256,
      rebuilt == self
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "foundation-policy package content fingerprint mismatch"
      )
    }
  }

  public func validateGateCEvidenceManifest() throws {
    try validate()
    let requiredModalities: Set<SensoryModality> = [
      .vision, .audition, .touch, .proprioception, .vestibular,
      .interoception, .kinesthesia,
    ]
    let purposes = Set(datasetSources.flatMap(\.purposes))
    let sourceKinds = Set(datasetSources.map(\.sourceKind))
    let splits = Set(datasetPartitions.map(\.split))
    let axes = Set(qualificationResults.map(\.axis))
    let hasExternalEmbodiment =
      sourceKinds.contains(.real)
      || sourceKinds.contains(.independentlySourced)
    let hasGoalInterface: Bool
    switch architecture.family {
    case .visionLanguageAction:
      hasGoalInterface = architecture.goalInterfaces.contains(.language)
    case .hierarchicalEmbodied:
      hasGoalInterface =
        architecture.goalInterfaces.contains(.structuredTask)
        && architecture.goalInterfaces.contains(.demonstration)
    }
    guard Set(architecture.inputModalities).isSuperset(of: requiredModalities),
      hasGoalInterface, architecture.actionHorizon > 1,
      purposes == Set(BrainPolicyDatasetPurpose.allCases),
      sourceKinds.contains(.simulated), hasExternalEmbodiment,
      splits == Set(BrainPolicyDatasetSplit.allCases),
      axes == Set(BrainPolicyQualificationAxis.allCases),
      qualificationResults.allSatisfy(\.passed),
      datasetPartitions.contains(where: {
        $0.split == .training
          && $0.learnerBatchFingerprint
            == parameterPublication.sourceBatchFingerprint
      }),
      parameterPublication.sourceBatchFingerprint > 0
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "foundation-policy package does not satisfy Gate C promotion evidence"
      )
    }
  }

  public func encoded() throws -> Data {
    try validate()
    return try Self.encodeCanonical(self)
  }

  public static func decode(_ data: Data) throws -> Self {
    let package = try JSONDecoder().decode(Self.self, from: data)
    try package.validate()
    return package
  }

  public func write(
    to url: URL,
    options: Data.WritingOptions = [.atomic]
  ) throws {
    try encoded().write(to: url, options: options)
  }

  public static func parameterWeightsSHA256(
    _ publication: BrainParameterPublication
  ) throws -> String {
    try publication.sharedArtifact.validate(parameterVersion: publication.version)
    var canonical = Data()
    appendLittleEndian(UInt64(publication.sharedArtifact.formatVersion), to: &canonical)
    appendLittleEndian(publication.version.fingerprint, to: &canonical)
    appendLittleEndian(
      publication.sharedArtifact.artifactFingerprint,
      to: &canonical
    )
    for payload in publication.sharedArtifact.payloads.sorted(by: {
      $0.kind.rawValue < $1.kind.rawValue
    }) {
      appendLittleEndian(UInt64(payload.kind.rawValue), to: &canonical)
      appendLittleEndian(UInt64(payload.elementType.rawValue), to: &canonical)
      appendLittleEndian(UInt64(payload.data.count), to: &canonical)
      canonical.append(payload.data)
    }
    return sha256(canonical)
  }

  private static func encodeCanonical<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
  }

  private static func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private static func appendLittleEndian(
    _ value: UInt64,
    to data: inout Data
  ) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
  }
}

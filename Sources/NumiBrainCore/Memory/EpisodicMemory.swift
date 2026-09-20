import Foundation

@frozen
public struct EpisodicSegmentationDynamics: Codable, Equatable, Hashable, Sendable {
  public let boundaryThreshold: Float
  public let sensorySurpriseWeight: Float
  public let contextChangeWeight: Float
  public let goalTransitionWeight: Float
  public let optionTerminationWeight: Float
  public let eventSalienceWeight: Float
  public let locationTransitionWeight: Float
  public let surpriseSampleCount: UInt16

  public init(
    boundaryThreshold: Float,
    sensorySurpriseWeight: Float,
    contextChangeWeight: Float,
    goalTransitionWeight: Float,
    optionTerminationWeight: Float,
    eventSalienceWeight: Float,
    locationTransitionWeight: Float,
    surpriseSampleCount: UInt16
  ) throws {
    let values = [
      boundaryThreshold, sensorySurpriseWeight, contextChangeWeight,
      goalTransitionWeight, optionTerminationWeight, eventSalienceWeight,
      locationTransitionWeight,
    ]
    guard values.allSatisfy({ $0.isFinite && $0 >= 0 }), surpriseSampleCount > 0 else {
      throw BrainRuntimeError.transaction("episodic segmentation dynamics are invalid")
    }
    self.boundaryThreshold = boundaryThreshold
    self.sensorySurpriseWeight = sensorySurpriseWeight
    self.contextChangeWeight = contextChangeWeight
    self.goalTransitionWeight = goalTransitionWeight
    self.optionTerminationWeight = optionTerminationWeight
    self.eventSalienceWeight = eventSalienceWeight
    self.locationTransitionWeight = locationTransitionWeight
    self.surpriseSampleCount = surpriseSampleCount
  }

  public static var foundationV1: Self {
    get throws {
      try Self(
        boundaryThreshold: 0.25,
        sensorySurpriseWeight: 1,
        contextChangeWeight: 0.5,
        goalTransitionWeight: 0.75,
        optionTerminationWeight: 0.75,
        eventSalienceWeight: 1,
        locationTransitionWeight: 0.5,
        surpriseSampleCount: 64
      )
    }
  }
}

@frozen
public enum EpisodicProvenanceKind: UInt16, Codable, CaseIterable, Sendable {
  case livedCommitted = 1
  case demonstration = 2
  case communicated = 3
  case reconstructed = 4
}

@frozen
public struct EpisodicProvenance: Codable, Equatable, Hashable, Sendable {
  public let kind: EpisodicProvenanceKind
  public let sourceEpisodeIdentifier: UInt64
  public let sourceRecordIdentifiers: [UInt64]
  public let parameterVersionFingerprint: UInt64
  public let physicalGeneration: UInt64?

  public init(
    kind: EpisodicProvenanceKind,
    sourceEpisodeIdentifier: UInt64,
    sourceRecordIdentifiers: [UInt64] = [],
    parameterVersionFingerprint: UInt64,
    physicalGeneration: UInt64?
  ) throws {
    guard parameterVersionFingerprint > 0,
      Set(sourceRecordIdentifiers).count == sourceRecordIdentifiers.count,
      kind != .livedCommitted || physicalGeneration != nil
    else {
      throw BrainRuntimeError.transaction("episodic provenance is invalid")
    }
    self.kind = kind
    self.sourceEpisodeIdentifier = sourceEpisodeIdentifier
    self.sourceRecordIdentifiers = sourceRecordIdentifiers
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.physicalGeneration = physicalGeneration
  }
}

@frozen
public struct EpisodicOutcome: Codable, Equatable, Hashable, Sendable {
  public let factoredReinforcement: FactoredReinforcement
  public let successProbability: Float
  public let damageSeverity: Float
  public let terminationCode: UInt32

  public init(
    factoredReinforcement: FactoredReinforcement,
    successProbability: Float,
    damageSeverity: Float,
    terminationCode: UInt32
  ) throws {
    guard successProbability.isFinite, (0...1).contains(successProbability),
      damageSeverity.isFinite, damageSeverity >= 0
    else {
      throw BrainRuntimeError.transaction("episodic outcome is invalid")
    }
    self.factoredReinforcement = factoredReinforcement
    self.successProbability = successProbability
    self.damageSeverity = damageSeverity
    self.terminationCode = terminationCode
  }
}

@frozen
public struct EpisodicAffectEvidence: Codable, Equatable, Hashable, Sendable {
  public let pain: Float
  public let pleasure: Float
  public let relief: Float
  public let sourceEvidence: [Float]
  public let sourceValidityMask: UInt32
  public let acceptedTimestamp: BrainTimestamp?

  public init(
    pain: Float,
    pleasure: Float,
    relief: Float,
    sourceEvidence: [Float],
    sourceValidityMask: UInt32,
    acceptedTimestamp: BrainTimestamp?
  ) throws {
    let affectValues = [pain, pleasure, relief] + sourceEvidence
    guard sourceEvidence.count == 5,
      affectValues.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
      sourceValidityMask & ~0x3f == 0,
      (sourceValidityMask == 0) == (acceptedTimestamp == nil),
      sourceValidityMask != 0 || affectValues.allSatisfy({ $0 == 0 })
    else {
      throw BrainRuntimeError.transaction("episodic affect evidence is invalid")
    }
    self.pain = pain
    self.pleasure = pleasure
    self.relief = relief
    self.sourceEvidence = sourceEvidence
    self.sourceValidityMask = sourceValidityMask
    self.acceptedTimestamp = acceptedTimestamp
  }

  private init(unavailable: Void) {
    pain = 0
    pleasure = 0
    relief = 0
    sourceEvidence = Array(repeating: 0, count: 5)
    sourceValidityMask = 0
    acceptedTimestamp = nil
  }

  public static let unavailable = Self(unavailable: ())

  private enum CodingKeys: String, CodingKey {
    case pain
    case pleasure
    case relief
    case sourceEvidence
    case sourceValidityMask
    case acceptedTimestamp
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      pain: container.decode(Float.self, forKey: .pain),
      pleasure: container.decode(Float.self, forKey: .pleasure),
      relief: container.decode(Float.self, forKey: .relief),
      sourceEvidence: container.decode([Float].self, forKey: .sourceEvidence),
      sourceValidityMask: container.decode(UInt32.self, forKey: .sourceValidityMask),
      acceptedTimestamp: container.decodeIfPresent(BrainTimestamp.self, forKey: .acceptedTimestamp)
    )
  }
}

@frozen
public struct EpisodicRecord: Codable, Equatable, Hashable, Sendable {
  public static let currentFormatVersion: UInt32 = 2

  public let formatVersion: UInt32
  public let identifier: UInt64
  public let retrievalKey: BrainLatentVector
  public let compressedTrajectory: [BrainLatentVector]
  public let startTimestamp: BrainTimestamp
  public let endTimestamp: BrainTimestamp
  public let context: BrainLatentVector
  public let activeGoalIdentifier: UInt64?
  public let optionIdentifiers: [UInt64]
  public let outcome: EpisodicOutcome
  public let epistemicUncertainty: Float
  public let salience: Float
  public let redundancy: Float
  public let provenance: EpisodicProvenance
  public let affectEvidence: EpisodicAffectEvidence

  public init(
    identifier: UInt64,
    retrievalKey: BrainLatentVector,
    compressedTrajectory: [BrainLatentVector],
    startTimestamp: BrainTimestamp,
    endTimestamp: BrainTimestamp,
    context: BrainLatentVector,
    activeGoalIdentifier: UInt64?,
    optionIdentifiers: [UInt64],
    outcome: EpisodicOutcome,
    epistemicUncertainty: Float,
    salience: Float,
    redundancy: Float,
    provenance: EpisodicProvenance,
    affectEvidence: EpisodicAffectEvidence = .unavailable
  ) throws {
    guard identifier > 0, startTimestamp <= endTimestamp,
      !compressedTrajectory.isEmpty,
      compressedTrajectory.allSatisfy({
        $0.values.count == compressedTrajectory[0].values.count
      }),
      epistemicUncertainty.isFinite, epistemicUncertainty >= 0,
      salience.isFinite, (0...1).contains(salience),
      redundancy.isFinite, (0...1).contains(redundancy),
      affectEvidence.acceptedTimestamp.map({
        $0 >= startTimestamp && $0 <= endTimestamp
      }) ?? true
    else {
      throw BrainRuntimeError.transaction("episodic record is invalid")
    }
    self.formatVersion = Self.currentFormatVersion
    self.identifier = identifier
    self.retrievalKey = retrievalKey
    self.compressedTrajectory = compressedTrajectory
    self.startTimestamp = startTimestamp
    self.endTimestamp = endTimestamp
    self.context = context
    self.activeGoalIdentifier = activeGoalIdentifier
    self.optionIdentifiers = optionIdentifiers
    self.outcome = outcome
    self.epistemicUncertainty = epistemicUncertainty
    self.salience = salience
    self.redundancy = redundancy
    self.provenance = provenance
    self.affectEvidence = affectEvidence
  }

  private enum CodingKeys: String, CodingKey {
    case formatVersion
    case identifier
    case retrievalKey
    case compressedTrajectory
    case startTimestamp
    case endTimestamp
    case context
    case activeGoalIdentifier
    case optionIdentifiers
    case outcome
    case epistemicUncertainty
    case salience
    case redundancy
    case provenance
    case affectEvidence
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let version = try container.decode(UInt32.self, forKey: .formatVersion)
    guard version == Self.currentFormatVersion else {
      throw DecodingError.dataCorruptedError(
        forKey: .formatVersion,
        in: container,
        debugDescription: "unsupported episodic record format version \(version)"
      )
    }
    try self.init(
      identifier: container.decode(UInt64.self, forKey: .identifier),
      retrievalKey: container.decode(BrainLatentVector.self, forKey: .retrievalKey),
      compressedTrajectory: container.decode([BrainLatentVector].self, forKey: .compressedTrajectory),
      startTimestamp: container.decode(BrainTimestamp.self, forKey: .startTimestamp),
      endTimestamp: container.decode(BrainTimestamp.self, forKey: .endTimestamp),
      context: container.decode(BrainLatentVector.self, forKey: .context),
      activeGoalIdentifier: container.decodeIfPresent(UInt64.self, forKey: .activeGoalIdentifier),
      optionIdentifiers: container.decode([UInt64].self, forKey: .optionIdentifiers),
      outcome: container.decode(EpisodicOutcome.self, forKey: .outcome),
      epistemicUncertainty: container.decode(Float.self, forKey: .epistemicUncertainty),
      salience: container.decode(Float.self, forKey: .salience),
      redundancy: container.decode(Float.self, forKey: .redundancy),
      provenance: container.decode(EpisodicProvenance.self, forKey: .provenance),
      affectEvidence: container.decode(EpisodicAffectEvidence.self, forKey: .affectEvidence)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(formatVersion, forKey: .formatVersion)
    try container.encode(identifier, forKey: .identifier)
    try container.encode(retrievalKey, forKey: .retrievalKey)
    try container.encode(compressedTrajectory, forKey: .compressedTrajectory)
    try container.encode(startTimestamp, forKey: .startTimestamp)
    try container.encode(endTimestamp, forKey: .endTimestamp)
    try container.encode(context, forKey: .context)
    try container.encodeIfPresent(activeGoalIdentifier, forKey: .activeGoalIdentifier)
    try container.encode(optionIdentifiers, forKey: .optionIdentifiers)
    try container.encode(outcome, forKey: .outcome)
    try container.encode(epistemicUncertainty, forKey: .epistemicUncertainty)
    try container.encode(salience, forKey: .salience)
    try container.encode(redundancy, forKey: .redundancy)
    try container.encode(provenance, forKey: .provenance)
    try container.encode(affectEvidence, forKey: .affectEvidence)
  }
}

@frozen
public enum EpisodicStorageTier: UInt16, Codable, CaseIterable, Sendable {
  case active = 1
  case compressed = 2
  case archive = 3
}

@frozen
public struct EpisodicArchiveIndexEntry: Codable, Equatable, Hashable, Sendable {
  public let recordIdentifier: UInt64
  public let coarseClusterIdentifier: UInt32
  public let quantizedKey: [Int8]
  public let byteOffset: UInt64
  public let byteCount: UInt32
  public let salience: Float
  public let lastRetrievalTimestamp: BrainTimestamp?

  public init(
    recordIdentifier: UInt64,
    coarseClusterIdentifier: UInt32,
    quantizedKey: [Int8],
    byteOffset: UInt64,
    byteCount: UInt32,
    salience: Float,
    lastRetrievalTimestamp: BrainTimestamp?
  ) throws {
    guard recordIdentifier > 0, !quantizedKey.isEmpty, byteCount > 0,
      salience.isFinite, (0...1).contains(salience)
    else {
      throw BrainRuntimeError.transaction("episodic archive index entry is invalid")
    }
    self.recordIdentifier = recordIdentifier
    self.coarseClusterIdentifier = coarseClusterIdentifier
    self.quantizedKey = quantizedKey
    self.byteOffset = byteOffset
    self.byteCount = byteCount
    self.salience = salience
    self.lastRetrievalTimestamp = lastRetrievalTimestamp
  }
}

@frozen
public enum EpisodicMutation: Codable, Equatable, Hashable, Sendable {
  case append(EpisodicRecord)
  case reconsolidate(EpisodicRecord)
  case remove(recordIdentifier: UInt64)
  case indexArchive(EpisodicArchiveIndexEntry)
}

@frozen
public struct EpisodicMemoryState: Codable, Equatable, Sendable {
  public let generation: UInt64
  public let nextRecordIdentifier: UInt64
  public let activeCapacity: UInt32
  public let compressedCapacity: UInt32
  public let archiveCapacity: UInt32
  public let activeRecords: [EpisodicRecord]
  public let compressedRecords: [EpisodicRecord]
  public let archiveIndex: [EpisodicArchiveIndexEntry]
  public let unfinishedEpisode: [BrainLatentVector]
  public let unfinishedEpisodeStart: BrainTimestamp?

  public init(
    generation: UInt64,
    nextRecordIdentifier: UInt64,
    activeCapacity: UInt32,
    compressedCapacity: UInt32,
    archiveCapacity: UInt32,
    activeRecords: [EpisodicRecord],
    compressedRecords: [EpisodicRecord],
    archiveIndex: [EpisodicArchiveIndexEntry],
    unfinishedEpisode: [BrainLatentVector],
    unfinishedEpisodeStart: BrainTimestamp?
  ) throws {
    let allRecordIdentifiers =
      activeRecords.map(\.identifier) + compressedRecords.map(\.identifier)
        + archiveIndex.map(\.recordIdentifier)
    guard activeRecords.count <= Int(activeCapacity),
      compressedRecords.count <= Int(compressedCapacity),
      archiveIndex.count <= Int(archiveCapacity),
      Set(allRecordIdentifiers).count == allRecordIdentifiers.count,
      allRecordIdentifiers.allSatisfy({ $0 < nextRecordIdentifier }),
      unfinishedEpisode.isEmpty == (unfinishedEpisodeStart == nil),
      unfinishedEpisode.isEmpty || unfinishedEpisode.allSatisfy({
        $0.values.count == unfinishedEpisode[0].values.count
      })
    else {
      throw BrainRuntimeError.capacity("episodic memory state is invalid")
    }
    self.generation = generation
    self.nextRecordIdentifier = nextRecordIdentifier
    self.activeCapacity = activeCapacity
    self.compressedCapacity = compressedCapacity
    self.archiveCapacity = archiveCapacity
    self.activeRecords = activeRecords
    self.compressedRecords = compressedRecords
    self.archiveIndex = archiveIndex
    self.unfinishedEpisode = unfinishedEpisode
    self.unfinishedEpisodeStart = unfinishedEpisodeStart
  }
}

@frozen
public struct EpisodicMutationJournal: Codable, Equatable, Sendable {
  public let baseGeneration: UInt64
  public let shadowGeneration: UInt64
  public let mutations: [EpisodicMutation]

  public init(
    baseGeneration: UInt64,
    shadowGeneration: UInt64,
    mutations: [EpisodicMutation] = []
  ) throws {
    let (expected, overflow) = baseGeneration.addingReportingOverflow(1)
    guard !overflow, shadowGeneration == expected else {
      throw BrainRuntimeError.transaction("episodic journal generation is invalid")
    }
    self.baseGeneration = baseGeneration
    self.shadowGeneration = shadowGeneration
    self.mutations = mutations
  }
}

@frozen
public struct EpisodicRetrievalQuery: Codable, Equatable, Hashable, Sendable {
  public let key: BrainLatentVector
  public let goalIdentifier: UInt64?
  public let context: BrainLatentVector
  public let minimumSalience: Float
  public let maximumResults: UInt16
  public let deadline: BrainTimestamp

  public init(
    key: BrainLatentVector,
    goalIdentifier: UInt64?,
    context: BrainLatentVector,
    minimumSalience: Float,
    maximumResults: UInt16,
    deadline: BrainTimestamp
  ) throws {
    guard minimumSalience.isFinite, (0...1).contains(minimumSalience),
      maximumResults > 0
    else {
      throw BrainRuntimeError.transaction("episodic retrieval query is invalid")
    }
    self.key = key
    self.goalIdentifier = goalIdentifier
    self.context = context
    self.minimumSalience = minimumSalience
    self.maximumResults = maximumResults
    self.deadline = deadline
  }
}

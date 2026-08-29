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
public struct EpisodicRecord: Codable, Equatable, Hashable, Sendable {
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
    provenance: EpisodicProvenance
  ) throws {
    guard identifier > 0, startTimestamp <= endTimestamp,
      !compressedTrajectory.isEmpty,
      compressedTrajectory.allSatisfy({
        $0.values.count == compressedTrajectory[0].values.count
      }),
      epistemicUncertainty.isFinite, epistemicUncertainty >= 0,
      salience.isFinite, (0...1).contains(salience),
      redundancy.isFinite, (0...1).contains(redundancy)
    else {
      throw BrainRuntimeError.transaction("episodic record is invalid")
    }
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

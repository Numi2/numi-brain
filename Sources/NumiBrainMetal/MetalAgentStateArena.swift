import Foundation
@preconcurrency import Metal
import NumiBrainCore

@frozen
public enum MetalAgentHotSection: UInt16, Codable, CaseIterable, Sendable {
  case regionalRecurrent = 1
  case bodyBelief = 2
  case muscleBelief = 3
  case objectSlots = 4
  case otherAgentSlots = 5
  case relationSlots = 6
  case spatialTransforms = 7
  case physiologyBelief = 8
  case contextBelief = 9
  case workspaceContent = 10
  case workspaceMetadata = 11
  case worldModel = 12
  case drives = 13
  case neuromodulation = 14
  case fastPlasticity = 15
  case activeControl = 16
  case schedulerRuntime = 17
  case eventQueue = 18
  case delayQueue = 19
  case randomCounters = 20
  case sensoryObservations = 21
  case sensoryAdaptation = 22
  case sensoryFrameMetadata = 23
  /// Contiguous authoritative somatic command vector consumed by NumanX.
  case somaticOutput = 24
  /// Transactional atomic winners for GPU persistent-memory retrieval.
  case memoryRetrievalScratch = 25
  case developmentalState = 26
  case developmentalEvidence = 27
  case regionalMaturation = 28
  /// Persistent per-agent cerebellar forward/inverse expert bank.
  case cerebellarExpertMemory = 29
  /// Reduced per-region effect of the agent's fast-plastic coefficients.
  case regionalPlasticModulation = 30
  /// Transactional unfinished lived-event segment.
  case activeEpisodeAccumulator = 31
  /// Accepted-tick history used to create and advance prospective intentions.
  case prospectiveLifecycle = 32
  /// One atomic residency state per fixed-size Tier-2 archive page.
  case archivePageResidency = 33
  /// Deadline-bounded GPU requests for archive pages absent this control.
  case archivePageRequests = 34
  /// Accepted option phases retained until procedural consolidation consumes them.
  case proceduralExecutionTrace = 35
}

@frozen
public enum MetalAgentPersistentSection: UInt16, Codable, CaseIterable, Sendable {
  case activeEpisodes = 1
  case compressedEpisodeMetadata = 2
  case archiveIndex = 3
  case semanticConcepts = 4
  case semanticRelations = 5
  case proceduralSkills = 6
  case prospectiveIntentions = 7
  case replayQueue = 8
  case committedTransitions = 9
}

@frozen
public enum MetalActiveControlSection: UInt16, Codable, CaseIterable, Sendable {
  case header = 1
  case optionCandidates = 2
  case planSteps = 3
  case motorCommands = 4
  case synergyCoefficients = 5
  case cerebellarExperts = 6
  case spinalState = 7
  case autonomicCommands = 8
  case activeSensingCommands = 9
  case internalActions = 10
}

@frozen
public struct MetalArenaSectionLayout<Section: RawRepresentable & Codable & Equatable & Sendable>:
  Codable, Equatable, Sendable where Section.RawValue == UInt16
{
  public let section: Section
  public let byteOffset: Int
  public let byteCount: Int
  public let elementCount: Int
  public let elementStride: Int

  public init(
    section: Section,
    byteOffset: Int,
    byteCount: Int,
    elementCount: Int,
    elementStride: Int
  ) throws {
    guard byteOffset >= 0, byteCount > 0, elementCount > 0, elementStride > 0,
      elementCount <= byteCount / elementStride
    else {
      throw BrainRuntimeError.capacity("Metal arena section layout is invalid")
    }
    self.section = section
    self.byteOffset = byteOffset
    self.byteCount = byteCount
    self.elementCount = elementCount
    self.elementStride = elementStride
  }
}

@frozen
public struct MetalAgentStateLayout: Codable, Equatable, Sendable {
  public static let alignment = 256
  public static let workspaceMetadataStride = 64
  public static let bodyBeliefStride = 256
  public static let muscleBeliefStride = 192
  public static let objectSlotStride = 512
  public static let otherAgentSlotStride = 512
  public static let relationStride = 64
  public static let spatialTransformStride = 96
  public static let physiologyScalarCapacity = 64
  public static let contextScalarCapacity = 512
  public static let fastPlasticityStride = 32
  public static let eventTokenStride = 32
  public static let delayMessageStride = 320
  public static let archiveRecordsPerPage = 256
  public static let archivePageRequestCapacity = 64
  public static let archivePageRequestStride = 32
  public static let archivePageRequestHeaderByteCount = 32

  public let speciesTemplateFingerprint: UInt64
  public let regionalProgramFingerprint: UInt64
  public let sections: [MetalArenaSectionLayout<MetalAgentHotSection>]
  public let totalByteCount: Int
  public let fingerprint: UInt64

  public init(
    species: SpeciesTemplate,
    regionalProgram: RegionalTokenProgram,
    maximumRelationSlots: Int = 1_024,
    maximumSpatialTransforms: Int = 32,
    maximumEventTokens: Int = 4_096,
    maximumDelayMessages: Int = 4_096
  ) throws {
    guard species.fingerprint > 0, regionalProgram.fingerprint > 0,
      regionalProgram.scheduleFingerprint == species.regionGraph.schedule.fingerprint,
      Set(regionalProgram.layouts.map(\.moduleIdentifier))
        == Set(species.enabledModuleIdentifiers),
      regionalProgram.scalarCount
        <= Int(species.capacities.activeRecurrentScalarCapacity),
      maximumRelationSlots > 0, maximumSpatialTransforms > 0,
      maximumEventTokens > 0, maximumDelayMessages > 0
    else {
      throw BrainRuntimeError.capacity("Metal agent-state layout input is invalid")
    }
    var builder = SectionBuilder<MetalAgentHotSection>()
    try builder.append(
      .regionalRecurrent,
      count: regionalProgram.scalarCount,
      stride: MemoryLayout<Float>.stride
    )
    try builder.append(
      .bodyBelief,
      count: Int(species.body.bodyCount),
      stride: Self.bodyBeliefStride
    )
    try builder.append(
      .muscleBelief,
      count: Int(species.body.muscleCount),
      stride: Self.muscleBeliefStride
    )
    try builder.append(
      .objectSlots,
      count: max(Int(species.capacities.objectSlotCapacity), 1),
      stride: Self.objectSlotStride
    )
    try builder.append(
      .otherAgentSlots,
      count: max(Int(species.capacities.otherAgentSlotCapacity), 1),
      stride: Self.otherAgentSlotStride
    )
    try builder.append(.relationSlots, count: maximumRelationSlots, stride: Self.relationStride)
    try builder.append(
      .spatialTransforms,
      count: maximumSpatialTransforms,
      stride: Self.spatialTransformStride
    )
    try builder.append(
      .physiologyBelief,
      count: Self.physiologyScalarCapacity,
      stride: MemoryLayout<Float>.stride
    )
    try builder.append(
      .contextBelief,
      count: Self.contextScalarCapacity,
      stride: MemoryLayout<Float>.stride
    )
    let workspaceScalarCount = Int(species.capacities.workspaceTokenCapacity)
      * Int(species.capacities.workspaceTokenDimension)
    try builder.append(
      .workspaceContent,
      count: workspaceScalarCount,
      stride: MemoryLayout<Float>.stride
    )
    try builder.append(
      .workspaceMetadata,
      count: Int(species.capacities.workspaceTokenCapacity),
      stride: Self.workspaceMetadataStride
    )
    let worldModelScalarCount = try WorldModelLevel.allCases.reduce(0) { total, level in
      let descriptor = try WorldModelLevelDescriptor.referenceV1(level: level)
      // latent, bottom-up error, top-down context, five state heads, and
      // one aleatoric field for the active horizon.
      let perLevel = Int(descriptor.latentDimension) * 9
      return try Self.checkedAdd(total, perLevel)
    }
    try builder.append(
      .worldModel,
      count: worldModelScalarCount,
      stride: MemoryLayout<Float>.stride
    )
    try builder.append(.drives, count: DriveKind.allCases.count, stride: 32)
    try builder.append(
      .neuromodulation,
      count: NeuromodulatorKind.allCases.count,
      stride: 16
    )
    try builder.append(
      .fastPlasticity,
      count: Int(species.capacities.fastPlasticityCapacity),
      stride: Self.fastPlasticityStride
    )
    let maximumPlanningHorizon = max(
      species.development.map({ Int($0.planningHorizonSteps) }).max() ?? 0,
      1
    )
    let candidateControlScalars = try Self.checkedMultiply(
      Int(species.capacities.activeOptionCandidateCapacity),
      32 * (1 + maximumPlanningHorizon)
    )
    let cerebellarControlScalars = try Self.checkedMultiply(
      Int(species.capacities.activeCerebellarExpertCapacity), 64
    )
    var controlScalarCount = 64
    controlScalarCount = try Self.checkedAdd(
      controlScalarCount,
      try Self.checkedMultiply(Int(species.motor.actuatorCount), 12)
    )
    controlScalarCount = try Self.checkedAdd(
      controlScalarCount, Int(species.motor.synergyCount)
    )
    controlScalarCount = try Self.checkedAdd(
      controlScalarCount,
      try Self.checkedMultiply(
        Int(species.physiology.autonomicActionDimension), 4
      )
    )
    controlScalarCount = try Self.checkedAdd(
      controlScalarCount,
      try Self.checkedMultiply(
        max(Int(species.motor.activeSensingActionDimension), 1), 4
      )
    )
    controlScalarCount = try Self.checkedAdd(
      controlScalarCount,
      InternalActionKind.allCases.count * 16
    )
    controlScalarCount = try Self.checkedAdd(
      controlScalarCount, candidateControlScalars
    )
    controlScalarCount = try Self.checkedAdd(
      controlScalarCount, cerebellarControlScalars
    )
    try builder.append(
      .activeControl,
      count: max(controlScalarCount, 1),
      stride: MemoryLayout<Float>.stride
    )
    try builder.append(.schedulerRuntime, count: 96, stride: 64)
    // Event queue element zero is a GPU-owned header; event records follow it.
    try builder.append(
      .eventQueue,
      count: try Self.checkedAdd(maximumEventTokens, 1),
      stride: Self.eventTokenStride
    )
    try builder.append(
      .delayQueue,
      count: maximumDelayMessages,
      stride: Self.delayMessageStride
    )
    try builder.append(
      .randomCounters,
      count: max(species.enabledModuleIdentifiers.count, 1),
      stride: MemoryLayout<UInt64>.stride
    )
    var sensoryObservationScalars = 0
    var sensoryReceptors = 0
    for sense in species.senses where sense.enabled {
      let (senseScalars, overflow) = Int(sense.receptorCount)
        .multipliedReportingOverflow(by: Int(sense.observationDimension))
      guard !overflow else {
        throw BrainRuntimeError.capacity("sensory observation arena overflows Int")
      }
      sensoryObservationScalars = try Self.checkedAdd(
        sensoryObservationScalars,
        senseScalars
      )
      sensoryReceptors = try Self.checkedAdd(sensoryReceptors, Int(sense.receptorCount))
    }
    try builder.append(
      .sensoryObservations,
      count: max(sensoryObservationScalars, 1),
      stride: MemoryLayout<Float>.stride
    )
    try builder.append(
      .sensoryAdaptation,
      count: max(sensoryReceptors, 1),
      stride: MemoryLayout<Float>.stride
    )
    try builder.append(
      .sensoryFrameMetadata,
      count: SensoryModality.allCases.count,
      stride: 32
    )
    try builder.append(
      .somaticOutput,
      count: Int(species.motor.actuatorCount),
      stride: MemoryLayout<Float>.stride
    )
    try builder.append(.memoryRetrievalScratch, count: 1, stride: 512)
    try builder.append(.developmentalState, count: 1, stride: 256)
    let capabilityCodeCount = species.development
      .flatMap(\.capabilityGateCodes).count
    try builder.append(
      .developmentalEvidence,
      count: max(capabilityCodeCount, 1),
      stride: 32
    )
    try builder.append(
      .regionalMaturation,
      count: species.enabledModuleIdentifiers.count,
      stride: 32
    )
    try builder.append(.cerebellarExpertMemory, count: 128, stride: 256)
    try builder.append(
      .regionalPlasticModulation,
      count: species.enabledModuleIdentifiers.count,
      stride: 32
    )
    try builder.append(.activeEpisodeAccumulator, count: 1, stride: 256)
    try builder.append(.prospectiveLifecycle, count: 1, stride: 256)
    let archivePageCount = max(
      (Int(species.capacities.archiveEpisodicCapacity)
        + Self.archiveRecordsPerPage - 1) / Self.archiveRecordsPerPage,
      1
    )
    try builder.append(
      .archivePageResidency,
      count: archivePageCount,
      stride: MemoryLayout<UInt32>.stride
    )
    let archiveRequestByteCount = try Self.checkedAdd(
      Self.archivePageRequestHeaderByteCount,
      try Self.checkedMultiply(
        Self.archivePageRequestCapacity,
        Self.archivePageRequestStride
      )
    )
    try builder.append(
      .archivePageRequests,
      count: 1,
      stride: archiveRequestByteCount
    )
    try builder.append(.proceduralExecutionTrace, count: 4, stride: 1_024)
    var hash: UInt64 = 14_695_981_039_346_656_037
    Self.mix(species.fingerprint, into: &hash)
    Self.mix(regionalProgram.fingerprint, into: &hash)
    for section in builder.sections {
      Self.mix(UInt64(section.section.rawValue), into: &hash)
      Self.mix(UInt64(section.byteOffset), into: &hash)
      Self.mix(UInt64(section.byteCount), into: &hash)
    }
    speciesTemplateFingerprint = species.fingerprint
    regionalProgramFingerprint = regionalProgram.fingerprint
    sections = builder.sections
    totalByteCount = builder.totalByteCount
    fingerprint = hash
  }

  public func section(
    _ section: MetalAgentHotSection
  ) -> MetalArenaSectionLayout<MetalAgentHotSection> {
    sections[Int(section.rawValue - 1)]
  }

  fileprivate static func checkedAdd(_ lhs: Int, _ rhs: Int) throws -> Int {
    let (result, overflow) = lhs.addingReportingOverflow(rhs)
    guard !overflow else { throw BrainRuntimeError.capacity("Metal arena size overflows Int") }
    return result
  }

  fileprivate static func checkedMultiply(_ lhs: Int, _ rhs: Int) throws -> Int {
    let (result, overflow) = lhs.multipliedReportingOverflow(by: rhs)
    guard !overflow else { throw BrainRuntimeError.capacity("Metal arena size overflows Int") }
    return result
  }

  fileprivate static func mix(_ value: UInt64, into hash: inout UInt64) {
    var value = value.littleEndian
    withUnsafeBytes(of: &value) { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }
}

@frozen
public struct MetalAgentMemoryLayout: Codable, Equatable, Sendable {
  public static let recordLayoutVersion: UInt32 = 3
  public static let alignment = 256
  public static let activeEpisodeStride = 1_536
  public static let compressedEpisodeMetadataStride = 128
  public static let archiveIndexStride = 320
  public static let semanticConceptStride = 384
  public static let semanticRelationStride = 96
  public static let proceduralSkillStride = 1_024
  public static let prospectiveIntentionStride = 640
  public static let replayQueueStride = 32
  public static let committedTransitionStride = 768

  public let sections: [MetalArenaSectionLayout<MetalAgentPersistentSection>]
  public let totalByteCount: Int
  public let journalByteCount: Int
  public let fingerprint: UInt64

  public init(species: SpeciesTemplate) throws {
    let capacities = species.capacities
    var builder = SectionBuilder<MetalAgentPersistentSection>()
    try builder.append(
      .activeEpisodes,
      count: Int(capacities.activeEpisodicCapacity),
      stride: Self.activeEpisodeStride
    )
    try builder.append(
      .compressedEpisodeMetadata,
      count: max(Int(capacities.compressedEpisodicCapacity), 1),
      stride: Self.compressedEpisodeMetadataStride
    )
    try builder.append(
      .archiveIndex,
      count: Int(capacities.archiveEpisodicCapacity),
      stride: Self.archiveIndexStride
    )
    try builder.append(
      .semanticConcepts,
      count: Int(capacities.semanticConceptCapacity),
      stride: Self.semanticConceptStride
    )
    try builder.append(
      .semanticRelations,
      count: Int(capacities.semanticRelationCapacity),
      stride: Self.semanticRelationStride
    )
    try builder.append(
      .proceduralSkills,
      count: Int(capacities.proceduralSkillCapacity),
      stride: Self.proceduralSkillStride
    )
    try builder.append(
      .prospectiveIntentions,
      count: Int(capacities.prospectiveIntentionCapacity),
      stride: Self.prospectiveIntentionStride
    )
    let replayCount = try MetalAgentStateLayout.checkedAdd(
      Int(capacities.activeEpisodicCapacity),
      Int(capacities.proceduralSkillCapacity)
    )
    try builder.append(.replayQueue, count: replayCount, stride: Self.replayQueueStride)
    let committedTransitionCount = max(
      Int(capacities.activeEpisodicCapacity) * 4,
      256
    )
    try builder.append(
      .committedTransitions,
      count: committedTransitionCount,
      stride: Self.committedTransitionStride
    )
    let mutationCapacity = max(
      Int(capacities.activeEpisodicCapacity)
        + Int(capacities.prospectiveIntentionCapacity)
        + Int(capacities.activeOptionCandidateCapacity),
      1_024
    )
    let (rawJournalBytes, overflow) = mutationCapacity.multipliedReportingOverflow(by: 256)
    guard !overflow else {
      throw BrainRuntimeError.capacity("Metal memory journal size overflows Int")
    }
    sections = builder.sections
    totalByteCount = builder.totalByteCount
    journalByteCount = Self.aligned(rawJournalBytes)
    var hash: UInt64 = 14_695_981_039_346_656_037
    for section in builder.sections {
      MetalAgentStateLayout.mix(UInt64(section.section.rawValue), into: &hash)
      MetalAgentStateLayout.mix(UInt64(section.byteOffset), into: &hash)
      MetalAgentStateLayout.mix(UInt64(section.byteCount), into: &hash)
      MetalAgentStateLayout.mix(UInt64(section.elementStride), into: &hash)
    }
    MetalAgentStateLayout.mix(UInt64(journalByteCount), into: &hash)
    MetalAgentStateLayout.mix(UInt64(Self.recordLayoutVersion), into: &hash)
    fingerprint = hash
  }

  public func section(
    _ section: MetalAgentPersistentSection
  ) -> MetalArenaSectionLayout<MetalAgentPersistentSection> {
    sections[Int(section.rawValue - 1)]
  }

  private static func aligned(_ value: Int) -> Int {
    (value + alignment - 1) & ~(alignment - 1)
  }
}

@frozen
public struct MetalActiveControlLayout: Codable, Equatable, Sendable {
  public let baseByteOffset: Int
  public let sections: [MetalArenaSectionLayout<MetalActiveControlSection>]
  public let totalByteCount: Int

  public init(
    arenaLayout: MetalAgentStateLayout,
    species: SpeciesTemplate
  ) throws {
    let parent = arenaLayout.section(.activeControl)
    var builder = SectionBuilder<MetalActiveControlSection>()
    try builder.append(.header, count: 1, stride: 256)
    try builder.append(
      .optionCandidates,
      count: Int(species.capacities.activeOptionCandidateCapacity),
      stride: 128
    )
    try builder.append(
      .planSteps,
      count: try MetalAgentStateLayout.checkedMultiply(
        Int(species.capacities.activeOptionCandidateCapacity),
        max(
          species.development.map({ Int($0.planningHorizonSteps) }).max() ?? 0,
          1
        )
      ),
      stride: 128
    )
    try builder.append(
      .motorCommands,
      count: Int(species.motor.actuatorCount),
      stride: 32
    )
    try builder.append(
      .synergyCoefficients,
      count: Int(species.motor.synergyCount),
      stride: MemoryLayout<Float>.stride
    )
    try builder.append(
      .cerebellarExperts,
      count: Int(species.capacities.activeCerebellarExpertCapacity),
      stride: 256
    )
    try builder.append(
      .spinalState,
      count: Int(species.motor.actuatorCount),
      stride: 16
    )
    try builder.append(
      .autonomicCommands,
      count: Int(species.physiology.autonomicActionDimension),
      stride: 16
    )
    try builder.append(
      .activeSensingCommands,
      count: max(Int(species.motor.activeSensingActionDimension), 1),
      stride: 16
    )
    try builder.append(
      .internalActions,
      count: InternalActionKind.allCases.count,
      stride: 64
    )
    guard builder.totalByteCount <= parent.byteCount else {
      throw BrainRuntimeError.capacity(
        "structured active-control state exceeds its hot arena section"
      )
    }
    baseByteOffset = parent.byteOffset
    sections = try builder.sections.map { local in
      let (absoluteOffset, overflow) = parent.byteOffset.addingReportingOverflow(
        local.byteOffset
      )
      guard !overflow else {
        throw BrainRuntimeError.capacity("active-control offset overflows Int")
      }
      return try MetalArenaSectionLayout(
        section: local.section,
        byteOffset: absoluteOffset,
        byteCount: local.byteCount,
        elementCount: local.elementCount,
        elementStride: local.elementStride
      )
    }
    totalByteCount = builder.totalByteCount
  }

  public func section(
    _ section: MetalActiveControlSection
  ) -> MetalArenaSectionLayout<MetalActiveControlSection> {
    sections[Int(section.rawValue - 1)]
  }
}

private struct SectionBuilder<Section: RawRepresentable & Codable & Equatable & Sendable>
where Section.RawValue == UInt16 {
  private(set) var sections: [MetalArenaSectionLayout<Section>] = []
  private(set) var totalByteCount = 0

  mutating func append(_ section: Section, count: Int, stride: Int) throws {
    guard count > 0, stride > 0 else {
      throw BrainRuntimeError.capacity("Metal arena section count must be positive")
    }
    let alignedOffset = (totalByteCount + 255) & ~255
    let (rawBytes, overflow) = count.multipliedReportingOverflow(by: stride)
    guard !overflow else {
      throw BrainRuntimeError.capacity("Metal arena section size overflows Int")
    }
    let alignedBytes = (rawBytes + 255) & ~255
    sections.append(
      try MetalArenaSectionLayout(
        section: section,
        byteOffset: alignedOffset,
        byteCount: alignedBytes,
        elementCount: count,
        elementStride: stride
      )
    )
    totalByteCount = try MetalAgentStateLayout.checkedAdd(alignedOffset, alignedBytes)
  }
}

@frozen
public struct MetalAgentStateTransactionToken: Equatable, Hashable, Sendable {
  public let baseGeneration: UInt64
  public let shadowGeneration: UInt64
  public let inputBufferIndex: UInt8
  public let outputBufferIndex: UInt8
  public let layoutFingerprint: UInt64
  public let fingerprint: UInt64

  fileprivate init(
    baseGeneration: UInt64,
    shadowGeneration: UInt64,
    inputBufferIndex: UInt8,
    outputBufferIndex: UInt8,
    layoutFingerprint: UInt64
  ) {
    self.baseGeneration = baseGeneration
    self.shadowGeneration = shadowGeneration
    self.inputBufferIndex = inputBufferIndex
    self.outputBufferIndex = outputBufferIndex
    self.layoutFingerprint = layoutFingerprint
    var hash: UInt64 = 14_695_981_039_346_656_037
    for value in [baseGeneration, shadowGeneration, UInt64(inputBufferIndex),
      UInt64(outputBufferIndex), layoutFingerprint]
    {
      MetalAgentStateLayout.mix(value, into: &hash)
    }
    fingerprint = hash
  }
}

@available(macOS 26.0, *)
public final class MetalAgentStateArena: @unchecked Sendable {
  struct PreparedCommit: Equatable, Sendable {
    let transaction: MetalAgentStateTransactionToken
  }

  public struct HotStateView: Equatable, Sendable {
    public let inputGPUAddress: UInt64
    public let outputGPUAddress: UInt64
    public let byteCount: Int
    public let generation: UInt64
  }

  public struct PersistentMemoryView: Equatable, Sendable {
    public let memoryGPUAddress: UInt64
    public let memoryByteCount: Int
    public let journalGPUAddress: UInt64
    public let journalByteCount: Int
    public let generation: UInt64
  }

  struct CheckpointSourceView: Equatable, Sendable {
    let hotGPUAddress: UInt64
    let hotByteCount: Int
    let memoryGPUAddress: UInt64
    let memoryByteCount: Int
    let generation: UInt64
  }

  struct CheckpointRestoreView: Equatable, Sendable {
    let firstHotGPUAddress: UInt64
    let secondHotGPUAddress: UInt64
    let hotByteCount: Int
    let memoryGPUAddress: UInt64
    let memoryByteCount: Int
    let firstJournalGPUAddress: UInt64
    let secondJournalGPUAddress: UInt64
    let journalByteCount: Int
  }

  public let layout: MetalAgentStateLayout
  public let memoryLayout: MetalAgentMemoryLayout
  public let deviceName: String
  public private(set) var committedGeneration: UInt64
  public private(set) var initialized: Bool = false

  private let hotBuffers: [any MTLBuffer]
  private let persistentMemoryBuffer: any MTLBuffer
  private let journalBuffers: [any MTLBuffer]
  private var committedIndex = 0
  private var committedJournalIndex = 0
  public private(set) var committedJournalNeedsConsolidation = false
  private var pendingToken: MetalAgentStateTransactionToken?
  private var pendingHotStateDefined = false
  private var pendingJournalFinalized = false

  public init(
    device: any MTLDevice,
    species: SpeciesTemplate,
    regionalProgram: RegionalTokenProgram,
    initialGeneration: UInt64 = 0
  ) throws {
    let layout = try MetalAgentStateLayout(species: species, regionalProgram: regionalProgram)
    let memoryLayout = try MetalAgentMemoryLayout(species: species)
    guard
      let firstHot = device.makeBuffer(
        length: layout.totalByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondHot = device.makeBuffer(
        length: layout.totalByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let memory = device.makeBuffer(
        length: memoryLayout.totalByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstJournal = device.makeBuffer(
        length: memoryLayout.journalByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondJournal = device.makeBuffer(
        length: memoryLayout.journalByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate the complete agent-state arena")
    }
    firstHot.label = "NumiBrain complete hot agent state generation 0"
    secondHot.label = "NumiBrain complete hot agent state generation 1"
    memory.label = "NumiBrain persistent individual memory arena"
    firstJournal.label = "NumiBrain memory mutation journal generation 0"
    secondJournal.label = "NumiBrain memory mutation journal generation 1"
    self.layout = layout
    self.memoryLayout = memoryLayout
    self.deviceName = device.name
    self.committedGeneration = initialGeneration
    self.hotBuffers = [firstHot, secondHot]
    self.persistentMemoryBuffer = memory
    self.journalBuffers = [firstJournal, secondJournal]
  }

  /// Addresses for the one-time GPU initialization pass. The caller writes
  /// complete state and persistent-memory headers, then calls markInitialized.
  public var initializationView: (
    hot: UInt64,
    memory: UInt64,
    journalZero: UInt64,
    journalOne: UInt64
  ) {
    (
      hotBuffers[committedIndex].gpuAddress,
      persistentMemoryBuffer.gpuAddress,
      journalBuffers[0].gpuAddress,
      journalBuffers[1].gpuAddress
    )
  }

  public func markInitialized(generation: UInt64) throws {
    guard !initialized, generation == committedGeneration else {
      throw TissueError.transaction("agent-state arena initialization generation mismatch")
    }
    initialized = true
  }

  public func beginShadow(
    expectedBaseGeneration: UInt64
  ) throws -> MetalAgentStateTransactionToken {
    guard initialized, pendingToken == nil, !committedJournalNeedsConsolidation,
      expectedBaseGeneration == committedGeneration
    else {
      throw TissueError.transaction("agent-state arena cannot begin a shadow generation")
    }
    let (shadowGeneration, overflow) = committedGeneration.addingReportingOverflow(1)
    guard !overflow else { throw TissueError.transaction("agent-state generation overflow") }
    let outputIndex = 1 - committedIndex
    let token = MetalAgentStateTransactionToken(
      baseGeneration: committedGeneration,
      shadowGeneration: shadowGeneration,
      inputBufferIndex: UInt8(committedIndex),
      outputBufferIndex: UInt8(outputIndex),
      layoutFingerprint: layout.fingerprint
    )
    pendingToken = token
    pendingHotStateDefined = false
    pendingJournalFinalized = false
    return token
  }

  public func hotStateView(
    transaction: MetalAgentStateTransactionToken
  ) throws -> HotStateView {
    try validate(transaction)
    return HotStateView(
      inputGPUAddress: hotBuffers[Int(transaction.inputBufferIndex)].gpuAddress,
      outputGPUAddress: hotBuffers[Int(transaction.outputBufferIndex)].gpuAddress,
      byteCount: layout.totalByteCount,
      generation: transaction.shadowGeneration
    )
  }

  public func persistentMemoryView(
    transaction: MetalAgentStateTransactionToken
  ) throws -> PersistentMemoryView {
    try validate(transaction)
    return PersistentMemoryView(
      memoryGPUAddress: persistentMemoryBuffer.gpuAddress,
      memoryByteCount: memoryLayout.totalByteCount,
      journalGPUAddress: journalBuffers[Int(transaction.outputBufferIndex)].gpuAddress,
      journalByteCount: memoryLayout.journalByteCount,
      generation: transaction.shadowGeneration
    )
  }

  /// Called only after the GPU command containing all state writes and journal
  /// application has completed successfully.
  public func markEncoded(
    transaction: MetalAgentStateTransactionToken,
    hotStateFullyDefined: Bool,
    memoryJournalFinalized: Bool
  ) throws {
    try validate(transaction)
    pendingHotStateDefined = hotStateFullyDefined
    pendingJournalFinalized = memoryJournalFinalized
  }

  public func commit(transaction: MetalAgentStateTransactionToken) throws {
    let prepared = try prepareCommit(transaction: transaction)
    publishPreparedCommit(prepared)
  }

  func prepareCommit(
    transaction: MetalAgentStateTransactionToken
  ) throws -> PreparedCommit {
    try validate(transaction)
    guard pendingHotStateDefined, pendingJournalFinalized else {
      throw TissueError.transaction(
        "complete hot state and memory journal must finish before commit"
      )
    }
    return PreparedCommit(transaction: transaction)
  }

  /// Preparation proves every fallible condition. Publication is only pointer
  /// and generation assignment, so the joint coordinator can publish this
  /// state after the fast-tissue side has also prepared successfully.
  func publishPreparedCommit(_ prepared: PreparedCommit) {
    let transaction = prepared.transaction
    committedIndex = Int(transaction.outputBufferIndex)
    committedJournalIndex = Int(transaction.outputBufferIndex)
    committedGeneration = transaction.shadowGeneration
    committedJournalNeedsConsolidation = true
    pendingToken = nil
    pendingHotStateDefined = false
    pendingJournalFinalized = false
  }

  public func abort(transaction: MetalAgentStateTransactionToken) throws {
    try validate(transaction)
    pendingToken = nil
    pendingHotStateDefined = false
    pendingJournalFinalized = false
  }

  public func committedMemoryJournalView() throws -> PersistentMemoryView {
    guard initialized, pendingToken == nil, committedJournalNeedsConsolidation else {
      throw TissueError.transaction("there is no committed memory journal to consolidate")
    }
    return PersistentMemoryView(
      memoryGPUAddress: persistentMemoryBuffer.gpuAddress,
      memoryByteCount: memoryLayout.totalByteCount,
      journalGPUAddress: journalBuffers[committedJournalIndex].gpuAddress,
      journalByteCount: memoryLayout.journalByteCount,
      generation: committedGeneration
    )
  }

  public func markCommittedMemoryJournalConsolidated(generation: UInt64) throws {
    guard pendingToken == nil, committedJournalNeedsConsolidation,
      generation == committedGeneration
    else {
      throw TissueError.transaction("memory journal consolidation generation mismatch")
    }
    committedJournalNeedsConsolidation = false
  }

  public func committedHotSectionAddress(_ section: MetalAgentHotSection) throws -> UInt64 {
    guard initialized, pendingToken == nil else {
      throw TissueError.transaction("finish agent-state transaction before inspection")
    }
    return hotBuffers[committedIndex].gpuAddress + UInt64(layout.section(section).byteOffset)
  }

  public func persistentSectionAddress(_ section: MetalAgentPersistentSection) -> UInt64 {
    persistentMemoryBuffer.gpuAddress + UInt64(memoryLayout.section(section).byteOffset)
  }

  func checkpointSourceView() throws -> CheckpointSourceView {
    guard initialized, pendingToken == nil, !committedJournalNeedsConsolidation else {
      throw TissueError.transaction(
        "checkpoint requires a fully consolidated committed agent state"
      )
    }
    return CheckpointSourceView(
      hotGPUAddress: hotBuffers[committedIndex].gpuAddress,
      hotByteCount: layout.totalByteCount,
      memoryGPUAddress: persistentMemoryBuffer.gpuAddress,
      memoryByteCount: memoryLayout.totalByteCount,
      generation: committedGeneration
    )
  }

  func checkpointRestoreView() throws -> CheckpointRestoreView {
    guard initialized, pendingToken == nil else {
      throw TissueError.transaction("checkpoint restore requires no open transaction")
    }
    return CheckpointRestoreView(
      firstHotGPUAddress: hotBuffers[0].gpuAddress,
      secondHotGPUAddress: hotBuffers[1].gpuAddress,
      hotByteCount: layout.totalByteCount,
      memoryGPUAddress: persistentMemoryBuffer.gpuAddress,
      memoryByteCount: memoryLayout.totalByteCount,
      firstJournalGPUAddress: journalBuffers[0].gpuAddress,
      secondJournalGPUAddress: journalBuffers[1].gpuAddress,
      journalByteCount: memoryLayout.journalByteCount
    )
  }

  func markCheckpointRestored(generation: UInt64) throws {
    guard initialized, pendingToken == nil else {
      throw TissueError.transaction("cannot publish checkpoint during a transaction")
    }
    committedIndex = 0
    committedJournalIndex = 0
    committedGeneration = generation
    committedJournalNeedsConsolidation = false
    pendingHotStateDefined = false
    pendingJournalFinalized = false
  }

  /// Retains the private shadow allocation while another GPU runtime consumes
  /// an address range from it. The transaction token remains the authority for
  /// which generation that range belongs to.
  func borrowShadowHotBuffer(
    transaction: MetalAgentStateTransactionToken
  ) throws -> any MTLBuffer {
    try validate(transaction)
    return hotBuffers[Int(transaction.outputBufferIndex)]
  }

  /// The owning runtime adds these allocations to its residency set. No CPU
  /// pointer to private state is exposed.
  public var residencyAllocations: [any MTLAllocation] {
    hotBuffers + [persistentMemoryBuffer] + journalBuffers
  }

  private func validate(_ transaction: MetalAgentStateTransactionToken) throws {
    guard pendingToken == transaction,
      transaction.layoutFingerprint == layout.fingerprint,
      transaction.baseGeneration == committedGeneration
    else {
      throw TissueError.transaction("agent-state transaction token is stale or foreign")
    }
  }
}

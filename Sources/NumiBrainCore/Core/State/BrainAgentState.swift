import Foundation

/// Complete rollout-owned state for one independent mind. Shared slow weights
/// are referenced by fingerprint and never embedded here.
@frozen
public struct BrainAgentState: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let environmentIdentifier: UInt32
  public let speciesTemplateFingerprint: UInt64
  public let regionalProgramFingerprint: UInt64
  public let regionalRecurrentState: [Float]
  public let belief: EmbodiedBeliefState
  public let worldModel: HierarchicalWorldModelState
  public let workspace: WorkspaceState
  public let memory: CompleteMemoryState
  public let drives: DriveState
  public let neuromodulation: NeuromodulatoryState
  public let fastPlasticity: FastPlasticityState
  public let control: ActiveControlState
  public let development: BrainDevelopmentalState
  public let runtime: BrainRuntimeState

  public init(
    environmentIdentifier: UInt32,
    speciesTemplateFingerprint: UInt64,
    regionalProgramFingerprint: UInt64,
    regionalRecurrentState: [Float],
    belief: EmbodiedBeliefState,
    worldModel: HierarchicalWorldModelState,
    workspace: WorkspaceState,
    memory: CompleteMemoryState,
    drives: DriveState,
    neuromodulation: NeuromodulatoryState,
    fastPlasticity: FastPlasticityState,
    control: ActiveControlState,
    development: BrainDevelopmentalState,
    runtime: BrainRuntimeState
  ) throws {
    let timestamp = runtime.committedTimestamp
    let generation = runtime.brainGeneration
    guard speciesTemplateFingerprint > 0, regionalProgramFingerprint > 0,
      !regionalRecurrentState.isEmpty,
      regionalRecurrentState.count
        <= Int(development.capacities.activeRecurrentScalarCapacity),
      regionalRecurrentState.allSatisfy(\.isFinite),
      belief.timestamp == timestamp, worldModel.timestamp == timestamp,
      worldModel.parameterVersionFingerprint == runtime.parameterVersionFingerprint,
      workspace.timestamp == timestamp,
      drives.timestamp == timestamp, neuromodulation.timestamp == timestamp,
      fastPlasticity.timestamp == timestamp, control.timestamp == timestamp,
      workspace.generation == generation, memory.generation == generation,
      fastPlasticity.generation == generation,
      workspace.tokenCapacity == development.capacities.workspaceTokenCapacity,
      workspace.tokenDimension == development.capacities.workspaceTokenDimension,
      belief.objects.count <= Int(development.capacities.objectSlotCapacity),
      belief.otherAgents.count <= Int(development.capacities.otherAgentSlotCapacity),
      memory.episodic.activeCapacity
        == development.capacities.activeEpisodicCapacity,
      memory.episodic.compressedCapacity
        == development.capacities.compressedEpisodicCapacity,
      memory.episodic.archiveCapacity
        == development.capacities.archiveEpisodicCapacity,
      memory.semantic.conceptCapacity
        == development.capacities.semanticConceptCapacity,
      memory.semantic.relationCapacity
        == development.capacities.semanticRelationCapacity,
      memory.procedural.skillCapacity
        == development.capacities.proceduralSkillCapacity,
      memory.prospective.capacity
        == development.capacities.prospectiveIntentionCapacity,
      fastPlasticity.capacity == development.capacities.fastPlasticityCapacity,
      control.candidates.count
        <= Int(development.capacities.activeOptionCandidateCapacity),
      control.cerebellarExperts.count
        <= Int(development.capacities.activeCerebellarExpertCapacity)
    else {
      throw BrainRuntimeError.transaction("complete per-agent brain state is inconsistent")
    }
    self.environmentIdentifier = environmentIdentifier
    self.speciesTemplateFingerprint = speciesTemplateFingerprint
    self.regionalProgramFingerprint = regionalProgramFingerprint
    self.regionalRecurrentState = regionalRecurrentState
    self.belief = belief
    self.worldModel = worldModel
    self.workspace = workspace
    self.memory = memory
    self.drives = drives
    self.neuromodulation = neuromodulation
    self.fastPlasticity = fastPlasticity
    self.control = control
    self.development = development
    self.runtime = runtime
  }

  public var committedTimestamp: BrainTimestamp { runtime.committedTimestamp }
  public var generation: UInt64 { runtime.brainGeneration }
  public var parameterVersionFingerprint: UInt64 {
    runtime.parameterVersionFingerprint
  }
}

@frozen
public struct BrainAgentShadowJournals: Codable, Equatable, Sendable {
  public let baseGeneration: UInt64
  public let shadowGeneration: UInt64
  public let workspace: WorkspaceMutationJournal
  public let episodic: EpisodicMutationJournal
  public let memory: MemoryMutationJournal

  public init(
    baseGeneration: UInt64,
    shadowGeneration: UInt64,
    workspace: WorkspaceMutationJournal,
    episodic: EpisodicMutationJournal,
    memory: MemoryMutationJournal
  ) throws {
    guard workspace.baseGeneration == baseGeneration,
      episodic.baseGeneration == baseGeneration,
      memory.baseGeneration == baseGeneration,
      workspace.shadowGeneration == shadowGeneration,
      episodic.shadowGeneration == shadowGeneration,
      memory.shadowGeneration == shadowGeneration
    else {
      throw BrainRuntimeError.transaction("brain shadow journals do not share generations")
    }
    self.baseGeneration = baseGeneration
    self.shadowGeneration = shadowGeneration
    self.workspace = workspace
    self.episodic = episodic
    self.memory = memory
  }
}

@frozen
public struct BrainCommittedCheckpoint: Codable, Equatable, Sendable {
  public let formatVersion: UInt32
  public let state: BrainAgentState
  public let scheduleFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  public let physicalCheckpointFingerprint: UInt64
  public let checkpointFingerprint: UInt64

  public init(
    state: BrainAgentState,
    scheduleFingerprint: UInt64,
    physicalCheckpointFingerprint: UInt64
  ) throws {
    guard scheduleFingerprint > 0, physicalCheckpointFingerprint > 0 else {
      throw BrainRuntimeError.transaction("checkpoint identity is incomplete")
    }
    var hash: UInt64 = 14_695_981_039_346_656_037
    Self.mix(BrainAgentState.formatVersion, into: &hash)
    Self.mix(UInt64(state.environmentIdentifier), into: &hash)
    Self.mix(state.generation, into: &hash)
    Self.mix(state.committedTimestamp.rawValue, into: &hash)
    Self.mix(state.speciesTemplateFingerprint, into: &hash)
    Self.mix(state.regionalProgramFingerprint, into: &hash)
    Self.mix(scheduleFingerprint, into: &hash)
    Self.mix(state.parameterVersionFingerprint, into: &hash)
    Self.mix(physicalCheckpointFingerprint, into: &hash)
    self.formatVersion = BrainAgentState.formatVersion
    self.state = state
    self.scheduleFingerprint = scheduleFingerprint
    self.parameterVersionFingerprint = state.parameterVersionFingerprint
    self.physicalCheckpointFingerprint = physicalCheckpointFingerprint
    self.checkpointFingerprint = hash
  }

  private static func mix(_ value: UInt32, into hash: inout UInt64) {
    mix(UInt64(value), into: &hash)
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }
}

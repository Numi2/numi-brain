import Foundation
@preconcurrency import Metal
import NumiBrainCore

/// Standalone GPU-resident cognitive runtime above the fast tissue/spinal
/// loop. It transduces delayed physical sensor buffers and advances one shadow
/// mind generation, but publication still requires the joint NumanX receipt.
@available(macOS 26.0, *)
public final class MetalEmbodiedBrainRuntime: @unchecked Sendable {
  @frozen
  public struct DecisionBufferView: Equatable, Sendable {
    public let transactionFingerprint: UInt64
    public let shadowGeneration: UInt64
    public let decisionTimestamp: BrainTimestamp
    public let activeControlGPUAddress: UInt64
    public let activeControlByteCount: Int
    public let motorGoalGPUAddress: UInt64
    public let motorGoalByteCount: Int
    public let motorCommandGPUAddress: UInt64
    public let motorCommandCount: Int
    public let spinalStateGPUAddress: UInt64
    public let somaticOutputGPUAddress: UInt64
    public let somaticOutputByteCount: Int
    public let somaticOutputCount: Int
    public let descendingSomaticBaselineGPUAddress: UInt64
    public let descendingSomaticBaselineByteCount: Int
    public let autonomicCommandGPUAddress: UInt64
    public let autonomicCommandCount: Int
    public let activeSensingCommandGPUAddress: UInt64
    public let activeSensingCommandCount: Int
    public let internalActionGPUAddress: UInt64
    public let internalActionCount: Int
    public let workspaceContentGPUAddress: UInt64
    public let workspaceContentByteCount: Int
    public let sensoryObservationGPUAddress: UInt64
    public let sensoryObservationScalarCount: Int
    public let receptorEventQueueGPUAddress: UInt64
    public let receptorEventCapacity: Int
    public let receptorEventMaximumCount: Int
    public let regionalMaturationGPUAddress: UInt64
    public let regionalMaturationByteCount: Int
    public let regionalMaturationCount: Int
    public let regionalPlasticModulationGPUAddress: UInt64
    public let regionalPlasticModulationByteCount: Int
    public let regionalPlasticModulationCount: Int
    public let fastPlasticityGPUAddress: UInt64
    public let fastPlasticityByteCount: Int
    public let fastPlasticityCount: Int
    public let cpgStateGPUAddress: UInt64
    public let cpgStateByteCount: Int
    public let cpgStateCount: Int
    public let cpgSynergyCount: Int
    public let reflexStateGPUAddress: UInt64
    public let reflexStateByteCount: Int
    public let reflexStateCount: Int
    public let fastCerebellarStateGPUAddress: UInt64
    public let fastCerebellarStateByteCount: Int
    public let fastCerebellarStateCount: Int
    public let fastAutonomicStateGPUAddress: UInt64
    public let fastAutonomicStateByteCount: Int
    public let fastAutonomicStateCount: Int
    public let gpuStartSeconds: Double
    public let gpuEndSeconds: Double

    public var gpuDurationSeconds: Double {
      max(gpuEndSeconds - gpuStartSeconds, 0)
    }
  }

  @frozen
  public struct AcceptedConsequenceView: Equatable, Sendable {
    /// These GPU addresses name candidate-only unpublished shadow storage. They
    /// are never physical, cognitive, or host publication authority.
    public let transactionFingerprint: UInt64
    public let shadowGeneration: UInt64
    public let acceptedPhysicsTokenFingerprint: UInt64
    public let acceptedTimestamp: BrainTimestamp
    public let sensoryObservationGPUAddress: UInt64
    public let sensoryObservationScalarCount: Int
    public let receptorEventQueueGPUAddress: UInt64
    public let receptorEventCapacity: Int
    public let gpuStartSeconds: Double
    public let gpuEndSeconds: Double

    public var gpuDurationSeconds: Double {
      max(gpuEndSeconds - gpuStartSeconds, 0)
    }
  }

  /// Host publication result for the authoritative device-token path. The
  /// accepted token is reconstructed only from the compact GPU gate result.
  @frozen
  public struct AcceptedConsequenceCompletion: Sendable {
    public let feedback: MetalGPUCompletionFeedback
    public let acceptedPhysicsState: AcceptedPhysicsStateToken
    public let consequence: AcceptedConsequenceView
  }

  /// Retains the private shadow generation while NumanX or the fast tissue
  /// runtime consumes its contiguous muscle/actuator command vector. No CPU
  /// pointer to command contents is exposed.
  public final class NumanXSomaticBufferLease: @unchecked Sendable {
    public let decision: DecisionBufferView
    public let speciesTemplateFingerprint: UInt64

    let buffer: any MTLBuffer
    let sourceOffset: Int
    let descendingBaselineSourceOffset: Int
    let autonomicSourceOffset: Int
    let activeSensingSourceOffset: Int
    let internalActionSourceOffset: Int
    let maturationSourceOffset: Int
    let plasticModulationSourceOffset: Int
    let fastPlasticitySourceOffset: Int
    let cpgStateSourceOffset: Int
    let reflexStateSourceOffset: Int
    let motorCommandSourceOffset: Int
    let fastCerebellarStateSourceOffset: Int
    let fastAutonomicStateSourceOffset: Int
    let receptorEventQueueSourceOffset: Int

    fileprivate init(
      decision: DecisionBufferView,
      speciesTemplateFingerprint: UInt64,
      buffer: any MTLBuffer,
      sourceOffset: Int,
      descendingBaselineSourceOffset: Int,
      autonomicSourceOffset: Int,
      activeSensingSourceOffset: Int,
      internalActionSourceOffset: Int,
      maturationSourceOffset: Int,
      plasticModulationSourceOffset: Int,
      fastPlasticitySourceOffset: Int,
      cpgStateSourceOffset: Int,
      reflexStateSourceOffset: Int,
      motorCommandSourceOffset: Int,
      fastCerebellarStateSourceOffset: Int,
      fastAutonomicStateSourceOffset: Int,
      receptorEventQueueSourceOffset: Int
    ) {
      self.decision = decision
      self.speciesTemplateFingerprint = speciesTemplateFingerprint
      self.buffer = buffer
      self.sourceOffset = sourceOffset
      self.descendingBaselineSourceOffset = descendingBaselineSourceOffset
      self.autonomicSourceOffset = autonomicSourceOffset
      self.activeSensingSourceOffset = activeSensingSourceOffset
      self.internalActionSourceOffset = internalActionSourceOffset
      self.maturationSourceOffset = maturationSourceOffset
      self.plasticModulationSourceOffset = plasticModulationSourceOffset
      self.fastPlasticitySourceOffset = fastPlasticitySourceOffset
      self.cpgStateSourceOffset = cpgStateSourceOffset
      self.reflexStateSourceOffset = reflexStateSourceOffset
      self.motorCommandSourceOffset = motorCommandSourceOffset
      self.fastCerebellarStateSourceOffset = fastCerebellarStateSourceOffset
      self.fastAutonomicStateSourceOffset = fastAutonomicStateSourceOffset
      self.receptorEventQueueSourceOffset = receptorEventQueueSourceOffset
    }

    public var metalBufferObject: UnsafeMutableRawPointer {
      Unmanaged.passUnretained(buffer as AnyObject).toOpaque()
    }

    public var somaticByteOffset: Int { sourceOffset }
    public var descendingSomaticBaselineByteOffset: Int {
      descendingBaselineSourceOffset
    }
    public var autonomicByteOffset: Int { autonomicSourceOffset }
    public var activeSensingByteOffset: Int { activeSensingSourceOffset }
    public var internalActionByteOffset: Int { internalActionSourceOffset }
    public var cpgStateByteOffset: Int { cpgStateSourceOffset }
    public var reflexStateByteOffset: Int { reflexStateSourceOffset }
    public var motorCommandByteOffset: Int { motorCommandSourceOffset }
    public var fastCerebellarStateByteOffset: Int {
      fastCerebellarStateSourceOffset
    }
    public var fastAutonomicStateByteOffset: Int {
      fastAutonomicStateSourceOffset
    }
    public var receptorEventQueueByteOffset: Int {
      receptorEventQueueSourceOffset
    }
    public static let structuredCommandStride = 16
  }

  public let deviceName: String
  public let deviceRegistryID: UInt64
  public let speciesTemplateFingerprint: UInt64
  public let compiledSpeciesTemplateFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  public let regionalProgramFingerprint: UInt64
  public let scheduleFingerprint: UInt64
  public let somaticSynergyCatalogFingerprint: UInt64
  public let numanXBrainProgramFingerprint: UInt64
  public let sharedParameterBank: MetalSharedParameterBank
  public let agentStateRuntime: MetalAgentStateRuntime
  public let sensoryRuntime: MetalSensoryTransductionRuntime
  public let cognitiveRuntime: MetalCognitiveStateRuntime
  public let decisionRuntime: MetalDecisionRuntime
  public let developmentalRuntime: MetalDevelopmentalRuntime
  public let acceptedConsequenceRuntime: MetalAcceptedConsequenceRuntime
  public let memoryRuntime: MetalMemoryRuntime

  private let device: any MTLDevice
  private let species: SpeciesTemplate
  private let acceptedPhysicsGateRuntime: MetalAcceptedPhysicsGateRuntime
  private let numanXHumanMatterRuntime: MetalNumanXHumanMatterBrainRuntime
  private let numanXMotorReadyRuntime: MetalNumanXMotorReadyRuntime
  let boundCompiledSpeciesTemplate: CompiledSpeciesTemplate
  private let commandQueue: any MTL4CommandQueue
  private let commandAllocator: any MTL4CommandAllocator
  private let commandBuffer: any MTL4CommandBuffer
  private let residencySet: any MTLResidencySet
  private let lock = NSLock()

  private enum AsyncSubmissionKind {
    case decision
    case acceptedConsequence
  }

  private final class ActiveAsyncSubmission: @unchecked Sendable {
    let identifier: UUID
    let kind: AsyncSubmissionKind
    let transactionFingerprint: UInt64
    let feedbackState: MetalAsyncFeedbackState
    let resources: MetalAsyncCommandResources
    let retainedInputs: [AnyObject]
    var abortRequested = false

    init(
      identifier: UUID,
      kind: AsyncSubmissionKind,
      transactionFingerprint: UInt64,
      feedbackState: MetalAsyncFeedbackState,
      resources: MetalAsyncCommandResources,
      retainedInputs: [AnyObject]
    ) {
      self.identifier = identifier
      self.kind = kind
      self.transactionFingerprint = transactionFingerprint
      self.feedbackState = feedbackState
      self.resources = resources
      self.retainedInputs = retainedInputs
    }
  }

  private var activeAsyncSubmission: ActiveAsyncSubmission?

  var boundSpeciesTemplate: SpeciesTemplate { species }

  public init(
    device: any MTLDevice,
    compiledSpeciesTemplate: CompiledSpeciesTemplate,
    regionalProgram: RegionalTokenProgram,
    parameterVersion: BrainParameterVersion,
    sharedParameterArtifact: BrainSharedParameterArtifact? = nil,
    decisionDynamics requestedDecisionDynamics: DecisionDynamics? = nil,
    acceptedConsequenceDynamics requestedAcceptedConsequenceDynamics:
      AcceptedConsequenceDynamics? = nil,
    memoryRetrievalDynamics requestedMemoryRetrievalDynamics:
      MemoryRetrievalDynamics? = nil,
    episodicSegmentation requestedEpisodicSegmentation:
      EpisodicSegmentationDynamics? = nil,
    initialGeneration: UInt64 = 0
  ) throws {
    let species = compiledSpeciesTemplate.species
    let sensoryProfile = compiledSpeciesTemplate.sensoryProfile
    let jointTopologyCatalog = compiledSpeciesTemplate.jointTopologyCatalog
    let muscleAttachmentCatalog = compiledSpeciesTemplate.muscleAttachmentCatalog
    let somaticSynergyCatalog = compiledSpeciesTemplate.somaticSynergyCatalog
    guard parameterVersion.regionalProgramFingerprint == regionalProgram.fingerprint,
      parameterVersion.scheduleFingerprint == regionalProgram.scheduleFingerprint,
      sensoryProfile.speciesTemplateFingerprint == species.fingerprint,
      !sensoryProfile.bodyReceptorBindings.isEmpty,
      sensoryProfile.bodyReceptorBindings.allSatisfy({
        $0.sourceModelFingerprint > 0 && $0.sourceEndpointIdentifier > 0
      }),
      let commandQueue = device.makeMTL4CommandQueue(),
      let commandAllocator = device.makeCommandAllocator(),
      let commandBuffer = device.makeCommandBuffer()
    else {
      throw TissueError.metal("embodied brain immutable bindings are inconsistent")
    }
    let agentStateRuntime = try MetalAgentStateRuntime(
      device: device,
      species: species,
      regionalProgram: regionalProgram,
      initialGeneration: initialGeneration
    )
    let sharedParameterBank = try MetalSharedParameterBank(
      device: device,
      parameterVersion: parameterVersion,
      artifact: sharedParameterArtifact
    )
    let sensoryRuntime = try MetalSensoryTransductionRuntime(
      device: device,
      arena: agentStateRuntime.arena,
      species: species,
      profile: sensoryProfile,
      sharedParameters: sharedParameterBank
    )
    let cognitiveRuntime = try MetalCognitiveStateRuntime(
      device: device,
      arena: agentStateRuntime.arena,
      species: species,
      regionalProgram: regionalProgram,
      sharedParameters: sharedParameterBank
    )
    let memoryRuntime = try MetalMemoryRuntime(
      device: device,
      arena: agentStateRuntime.arena,
      species: species,
      regionalProgram: regionalProgram,
      parameterVersion: parameterVersion,
      segmentation: requestedEpisodicSegmentation
        ?? EpisodicSegmentationDynamics.foundationV1,
      retrieval: requestedMemoryRetrievalDynamics
        ?? MemoryRetrievalDynamics.foundationV1,
      sharedParameters: sharedParameterBank
    )
    let decisionRuntime = try MetalDecisionRuntime(
      device: device,
      arena: agentStateRuntime.arena,
      species: species,
      somaticSynergyCatalog: somaticSynergyCatalog,
      regionalProgram: regionalProgram,
      parameterVersion: parameterVersion,
      dynamics: requestedDecisionDynamics ?? DecisionDynamics.foundationV1,
      sharedParameters: sharedParameterBank
    )
    let developmentalRuntime = try MetalDevelopmentalRuntime(
      device: device,
      arena: agentStateRuntime.arena,
      species: species
    )
    let acceptedConsequenceRuntime = try MetalAcceptedConsequenceRuntime(
      device: device,
      arena: agentStateRuntime.arena,
      species: species,
      dynamics: requestedAcceptedConsequenceDynamics
        ?? AcceptedConsequenceDynamics.foundationV1,
      sensoryProfile: sensoryProfile,
      jointTopologyCatalog: jointTopologyCatalog,
      muscleAttachmentCatalog: muscleAttachmentCatalog,
      sharedParameters: sharedParameterBank
    )
    let acceptedPhysicsGateRuntime = try MetalAcceptedPhysicsGateRuntime(
      device: device
    )
    let numanXMotorReadyRuntime = try MetalNumanXMotorReadyRuntime(device: device)
    let numanXHumanMatterRuntime = try MetalNumanXHumanMatterBrainRuntime(
      device: device,
      immutableFingerprints: [
        ("species", species.fingerprint),
        ("compiledSpecies", compiledSpeciesTemplate.fingerprint),
        ("parameterVersion", parameterVersion.fingerprint),
        ("regionalProgram", regionalProgram.fingerprint),
        ("schedule", regionalProgram.scheduleFingerprint),
        ("hotLayout", agentStateRuntime.arena.layout.fingerprint),
        ("memoryLayout", agentStateRuntime.arena.memoryLayout.fingerprint),
        ("sharedParameterArtifact", sharedParameterBank.artifactFingerprint),
        ("sensoryProfile", sensoryProfile.fingerprint),
        ("somaticSynergyCatalog", somaticSynergyCatalog.fingerprint),
      ]
    )
    let residencyDescriptor = MTLResidencySetDescriptor()
    residencyDescriptor.label = "NumiBrain embodied cognitive residency"
    residencyDescriptor.initialCapacity =
      agentStateRuntime.arena.residencyAllocations.count
      + sensoryRuntime.residencyAllocations.count
      + cognitiveRuntime.residencyAllocations.count
      + memoryRuntime.residencyAllocations.count
      + sharedParameterBank.residencyAllocations.count
      + developmentalRuntime.residencyAllocations.count
      + decisionRuntime.residencyAllocations.count
      + acceptedConsequenceRuntime.residencyAllocations.count
    let residencySet: any MTLResidencySet
    do {
      residencySet = try device.makeResidencySet(descriptor: residencyDescriptor)
    } catch {
      throw TissueError.metal("failed to create embodied brain residency: \(error)")
    }
    for allocation in agentStateRuntime.arena.residencyAllocations {
      residencySet.addAllocation(allocation)
    }
    for allocation in sharedParameterBank.residencyAllocations {
      residencySet.addAllocation(allocation)
    }
    for allocation in sensoryRuntime.residencyAllocations {
      residencySet.addAllocation(allocation)
    }
    for allocation in cognitiveRuntime.residencyAllocations {
      residencySet.addAllocation(allocation)
    }
    for allocation in decisionRuntime.residencyAllocations {
      residencySet.addAllocation(allocation)
    }
    for allocation in developmentalRuntime.residencyAllocations {
      residencySet.addAllocation(allocation)
    }
    for allocation in acceptedConsequenceRuntime.residencyAllocations {
      residencySet.addAllocation(allocation)
    }
    for allocation in memoryRuntime.residencyAllocations {
      residencySet.addAllocation(allocation)
    }
    residencySet.commit()
    residencySet.requestResidency()
    self.deviceName = device.name
    self.deviceRegistryID = device.registryID
    self.speciesTemplateFingerprint = species.fingerprint
    self.compiledSpeciesTemplateFingerprint = compiledSpeciesTemplate.fingerprint
    self.parameterVersionFingerprint = parameterVersion.fingerprint
    self.regionalProgramFingerprint = regionalProgram.fingerprint
    self.scheduleFingerprint = regionalProgram.scheduleFingerprint
    self.somaticSynergyCatalogFingerprint = somaticSynergyCatalog.fingerprint
    self.numanXBrainProgramFingerprint = numanXHumanMatterRuntime.programFingerprint
    self.sharedParameterBank = sharedParameterBank
    self.agentStateRuntime = agentStateRuntime
    self.sensoryRuntime = sensoryRuntime
    self.cognitiveRuntime = cognitiveRuntime
    self.decisionRuntime = decisionRuntime
    self.developmentalRuntime = developmentalRuntime
    self.acceptedConsequenceRuntime = acceptedConsequenceRuntime
    self.memoryRuntime = memoryRuntime
    self.device = device
    self.species = species
    self.acceptedPhysicsGateRuntime = acceptedPhysicsGateRuntime
    self.numanXHumanMatterRuntime = numanXHumanMatterRuntime
    self.numanXMotorReadyRuntime = numanXMotorReadyRuntime
    self.boundCompiledSpeciesTemplate = compiledSpeciesTemplate
    self.commandQueue = commandQueue
    self.commandAllocator = commandAllocator
    self.commandBuffer = commandBuffer
    self.residencySet = residencySet
  }

  deinit { residencySet.endResidency() }

  public func saveCheckpoint(
    environmentIdentifier: UInt32,
    episodeIdentifier: UInt64,
    controlStepIdentifier: UInt64,
    committedTimestamp: BrainTimestamp,
    physicalCheckpointFingerprint: UInt64
  ) throws -> MetalBrainCheckpoint {
    lock.lock()
    defer { lock.unlock() }
    let payload = try agentStateRuntime.snapshotCommittedState()
    return try MetalBrainCheckpoint(
      committedGeneration: payload.generation,
      committedTimestamp: committedTimestamp,
      environmentIdentifier: environmentIdentifier,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: controlStepIdentifier,
      speciesTemplateFingerprint: speciesTemplateFingerprint,
      compiledSpeciesTemplateFingerprint: compiledSpeciesTemplateFingerprint,
      regionalProgramFingerprint: regionalProgramFingerprint,
      scheduleFingerprint: scheduleFingerprint,
      parameterVersionFingerprint: parameterVersionFingerprint,
      hotLayoutFingerprint: agentStateRuntime.arena.layout.fingerprint,
      memoryLayoutFingerprint: agentStateRuntime.arena.memoryLayout.fingerprint,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint,
      hotState: payload.hotState,
      persistentMemory: payload.persistentMemory
    )
  }

  public func loadCheckpoint(
    _ checkpoint: MetalBrainCheckpoint,
    physicalCheckpointFingerprint: UInt64
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try validateCheckpointCompatibilityLocked(
      checkpoint,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    try agentStateRuntime.restoreCommittedState(
      from: .init(
        generation: checkpoint.committedGeneration,
        hotState: checkpoint.hotState,
        persistentMemory: checkpoint.persistentMemory
      )
    )
  }

  public func validateCheckpointCompatibility(
    _ checkpoint: MetalBrainCheckpoint,
    physicalCheckpointFingerprint: UInt64
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try validateCheckpointCompatibilityLocked(
      checkpoint,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
  }

  private func validateCheckpointCompatibilityLocked(
    _ checkpoint: MetalBrainCheckpoint,
    physicalCheckpointFingerprint: UInt64
  ) throws {
    try checkpoint.validate()
    guard checkpoint.speciesTemplateFingerprint == speciesTemplateFingerprint,
      checkpoint.compiledSpeciesTemplateFingerprint
        == compiledSpeciesTemplateFingerprint,
      checkpoint.regionalProgramFingerprint == regionalProgramFingerprint,
      checkpoint.scheduleFingerprint == scheduleFingerprint,
      checkpoint.parameterVersionFingerprint == parameterVersionFingerprint,
      checkpoint.hotLayoutFingerprint == agentStateRuntime.arena.layout.fingerprint,
      checkpoint.memoryLayoutFingerprint
        == agentStateRuntime.arena.memoryLayout.fingerprint,
      checkpoint.physicalCheckpointFingerprint == physicalCheckpointFingerprint,
      checkpoint.hotState.count == agentStateRuntime.arena.layout.totalByteCount,
      checkpoint.persistentMemory.count
        == agentStateRuntime.arena.memoryLayout.totalByteCount
    else {
      throw TissueError.transaction(
        "brain checkpoint is incompatible with runtime or physical checkpoint"
      )
    }
  }

  public func makeLearningBatch() throws -> MetalLearningBatch {
    lock.lock()
    defer { lock.unlock() }
    let transitions = try agentStateRuntime.snapshotPersistentSection(
      .committedTransitions
    )
    let livedEpisodes = try agentStateRuntime.snapshotPersistentSection(
      .activeEpisodes
    )
    let warmEpisodes = try agentStateRuntime.snapshotPersistentSection(
      .compressedEpisodeMetadata
    )
    let proceduralSkills = try agentStateRuntime.snapshotPersistentSection(
      .proceduralSkills
    )
    let replayQueue = try agentStateRuntime.snapshotPersistentSection(
      .replayQueue
    )
    let counterfactualRollouts = try agentStateRuntime.snapshotPersistentSection(
      .counterfactualRollouts
    )
    let semanticConcepts = try agentStateRuntime.snapshotPersistentSection(
      .semanticConcepts
    )
    let semanticRelations = try agentStateRuntime.snapshotPersistentSection(
      .semanticRelations
    )
    let regionalTransitions = try agentStateRuntime.snapshotPersistentSection(
      .regionalTransitions
    )
    return try MetalLearningBatch(
      transitions: transitions,
      livedEpisodes: livedEpisodes,
      warmEpisodes: warmEpisodes,
      proceduralSkills: proceduralSkills,
      replayQueue: replayQueue,
      counterfactualRollouts: counterfactualRollouts,
      semanticConcepts: semanticConcepts,
      semanticRelations: semanticRelations,
      regionalTransitions: regionalTransitions,
      regionalModuleCount: agentStateRuntime.arena.layout.section(
        .regionalMaturation
      ).elementCount,
      speciesTemplateFingerprint: speciesTemplateFingerprint,
      regionalProgramFingerprint: regionalProgramFingerprint,
      scheduleFingerprint: scheduleFingerprint,
      parameterVersionFingerprint: parameterVersionFingerprint
    )
  }

  public func beginControl(
    jointToken: BrainJointTransactionToken,
    cachedDecisionFingerprint: UInt64
  ) throws -> MetalJointAgentStateTransaction {
    guard jointToken.parameterVersionFingerprint == parameterVersionFingerprint else {
      throw TissueError.transaction("control root parameter version is not bound")
    }
    return try MetalJointAgentStateTransaction(
      jointToken: jointToken,
      runtime: agentStateRuntime,
      cachedDecisionFingerprint: cachedDecisionFingerprint
    )
  }

  public func inferAndDecide(
    transaction: MetalJointAgentStateTransaction,
    numanXSensors: NumanXSensorPacketLease,
    regionalRecurrentInput: MetalRegionalRecurrentBufferView? = nil,
    externalGoal: ActiveGoal? = nil
  ) throws -> DecisionBufferView {
    let packet = numanXSensors.packet
    guard packet.transactionFingerprint == transaction.jointToken.fingerprint,
      !packet.isAcceptedState,
      packet.deliveryTimestamp == transaction.jointToken.committedTimestamp,
      packet.physicsGeneration == transaction.jointToken.basePhysicsGeneration,
      packet.environmentIdentifier
        == transaction.jointToken.environmentIdentifier,
      packet.speciesTemplateFingerprint == speciesTemplateFingerprint,
      packet.sensoryProfileFingerprint == sensoryRuntime.profileFingerprint
    else {
      throw TissueError.transaction(
        "NumanX committed sensor packet does not belong to this control root"
      )
    }
    return try inferAndDecide(
      transaction: transaction,
      rawSensors: numanXSensors.rawSensors,
      regionalRecurrentInput: regionalRecurrentInput,
      externalGoal: externalGoal
    )
  }

  public func inferAndDecide(
    transaction: MetalJointAgentStateTransaction,
    rawSensors: [MetalRawSensorBufferLease],
    regionalRecurrentInput: MetalRegionalRecurrentBufferView? = nil,
    externalGoal: ActiveGoal? = nil
  ) throws -> DecisionBufferView {
    lock.lock()
    defer { lock.unlock() }
    guard activeAsyncSubmission == nil,
      transaction.status == .open,
      transaction.jointToken.parameterVersionFingerprint == parameterVersionFingerprint
    else {
      throw TissueError.transaction(
        "embodied control transaction is not open or owns an async submission"
      )
    }
    let duration =
      transaction.jointToken.targetTimestamp.rawValue
      - transaction.jointToken.committedTimestamp.rawValue
    guard duration > 0, duration <= UInt64(UInt32.max) else {
      throw TissueError.transaction("embodied control interval exceeds sensory ABI")
    }
    let dynamicResidency = try makeDynamicSensorResidency(rawSensors)
    defer { dynamicResidency?.endResidency() }
    do {
      commandAllocator.reset()
      commandBuffer.beginCommandBuffer(allocator: commandAllocator)
      commandBuffer.useResidencySet(residencySet)
      if let dynamicResidency { commandBuffer.useResidencySet(dynamicResidency) }
      guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
        commandBuffer.endCommandBuffer()
        throw TissueError.metal("failed to encode embodied cognitive control")
      }
      encoder.label = "NumiBrain receptor to cognitive decision"
      try developmentalRuntime.encodeCurrentStage(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        timestamp: transaction.jointToken.committedTimestamp
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      let sensory = try sensoryRuntime.encode(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        rawSensorViews: rawSensors.map(\.view),
        environmentIdentifier: transaction.jointToken.environmentIdentifier,
        episodeIdentifier: transaction.jointToken.episodeIdentifier,
        controlStepIdentifier: transaction.jointToken.controlStepIdentifier,
        randomCounterGeneration: transaction.cachedRandomCounterGeneration,
        targetTimestamp: transaction.jointToken.committedTimestamp,
        deltaMicroseconds: UInt32(duration)
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try cognitiveRuntime.encodeAcceptedCognitiveStep(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        targetTimestamp: transaction.jointToken.committedTimestamp,
        deltaMicroseconds: duration,
        receptorEventCapacity: sensory.eventCapacity,
        regionalRecurrentInput: regionalRecurrentInput
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try memoryRuntime.encodeRetrieval(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        timestamp: transaction.jointToken.committedTimestamp
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      let decision = try decisionRuntime.encode(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        timestamp: transaction.jointToken.committedTimestamp,
        externalGoal: externalGoal
      )
      encoder.endEncoding()
      commandBuffer.endCommandBuffer()
      let feedback = try commitCommandBuffer(label: "NumiBrain embodied cognitive control")
      let hot = try agentStateRuntime.hotStateView(
        transaction: transaction.agentStateToken
      )
      let control = agentStateRuntime.arena.layout.section(.activeControl)
      let workspace = agentStateRuntime.arena.layout.section(.workspaceContent)
      let maturation = agentStateRuntime.arena.layout.section(.regionalMaturation)
      let plasticModulation = agentStateRuntime.arena.layout.section(
        .regionalPlasticModulation
      )
      let fastPlasticity = agentStateRuntime.arena.layout.section(.fastPlasticity)
      let cpgState = agentStateRuntime.arena.layout.section(.cpgState)
      let descendingBaseline = agentStateRuntime.arena.layout.section(
        .descendingSomaticBaseline
      )
      let reflexState = agentStateRuntime.arena.layout.section(.reflexState)
      let fastCerebellarState = agentStateRuntime.arena.layout.section(
        .fastCerebellarState
      )
      let fastAutonomicState = agentStateRuntime.arena.layout.section(
        .fastAutonomicState
      )
      let reflexStateCount = species.reflexes.reduce(0) {
        $0 + $1.receptorChannelCodes.count * $1.actuatorIdentifiers.count
      }
      return DecisionBufferView(
        transactionFingerprint: transaction.jointToken.fingerprint,
        shadowGeneration: transaction.agentStateToken.shadowGeneration,
        decisionTimestamp: transaction.jointToken.committedTimestamp,
        activeControlGPUAddress: hot.outputGPUAddress + UInt64(control.byteOffset),
        activeControlByteCount: control.byteCount,
        motorGoalGPUAddress: decision.motorGoalGPUAddress,
        motorGoalByteCount: decision.motorGoalByteCount,
        motorCommandGPUAddress: decision.motorCommandGPUAddress,
        motorCommandCount: decision.motorCommandCount,
        spinalStateGPUAddress: decision.spinalStateGPUAddress,
        somaticOutputGPUAddress: decision.somaticOutputGPUAddress,
        somaticOutputByteCount:
          decision.somaticOutputCount * MemoryLayout<Float>.stride,
        somaticOutputCount: decision.somaticOutputCount,
        descendingSomaticBaselineGPUAddress:
          hot.outputGPUAddress + UInt64(descendingBaseline.byteOffset),
        descendingSomaticBaselineByteCount:
          descendingBaseline.elementCount * descendingBaseline.elementStride,
        autonomicCommandGPUAddress: decision.autonomicCommandGPUAddress,
        autonomicCommandCount: decision.autonomicCommandCount,
        activeSensingCommandGPUAddress:
          decision.activeSensingCommandGPUAddress,
        activeSensingCommandCount: decision.activeSensingCommandCount,
        internalActionGPUAddress: decision.internalActionGPUAddress,
        internalActionCount: decision.internalActionCount,
        workspaceContentGPUAddress: hot.outputGPUAddress + UInt64(workspace.byteOffset),
        workspaceContentByteCount: workspace.byteCount,
        sensoryObservationGPUAddress: sensory.observationGPUAddress,
        sensoryObservationScalarCount: sensory.observationScalarCount,
        receptorEventQueueGPUAddress: sensory.eventQueueGPUAddress,
        receptorEventCapacity: sensory.eventCapacity,
        receptorEventMaximumCount: sensory.maximumEventCount,
        regionalMaturationGPUAddress:
          hot.outputGPUAddress + UInt64(maturation.byteOffset),
        regionalMaturationByteCount:
          maturation.elementCount * maturation.elementStride,
        regionalMaturationCount: maturation.elementCount,
        regionalPlasticModulationGPUAddress:
          hot.outputGPUAddress + UInt64(plasticModulation.byteOffset),
        regionalPlasticModulationByteCount:
          plasticModulation.elementCount * plasticModulation.elementStride,
        regionalPlasticModulationCount: plasticModulation.elementCount,
        fastPlasticityGPUAddress:
          hot.outputGPUAddress + UInt64(fastPlasticity.byteOffset),
        fastPlasticityByteCount:
          fastPlasticity.elementCount * fastPlasticity.elementStride,
        fastPlasticityCount: fastPlasticity.elementCount,
        cpgStateGPUAddress: hot.outputGPUAddress + UInt64(cpgState.byteOffset),
        cpgStateByteCount: species.cpg.oscillators.count
          * cpgState.elementStride,
        cpgStateCount: species.cpg.oscillators.count,
        cpgSynergyCount: Int(species.motor.synergyCount),
        reflexStateGPUAddress:
          hot.outputGPUAddress + UInt64(reflexState.byteOffset),
        reflexStateByteCount: reflexStateCount * reflexState.elementStride,
        reflexStateCount: reflexStateCount,
        fastCerebellarStateGPUAddress:
          hot.outputGPUAddress + UInt64(fastCerebellarState.byteOffset),
        fastCerebellarStateByteCount:
          fastCerebellarState.elementCount * fastCerebellarState.elementStride,
        fastCerebellarStateCount: fastCerebellarState.elementCount,
        fastAutonomicStateGPUAddress:
          hot.outputGPUAddress + UInt64(fastAutonomicState.byteOffset),
        fastAutonomicStateByteCount:
          fastAutonomicState.elementCount * fastAutonomicState.elementStride,
        fastAutonomicStateCount: fastAutonomicState.elementCount,
        gpuStartSeconds: feedback.gpuStartTime,
        gpuEndSeconds: feedback.gpuEndTime
      )
    } catch {
      try? transaction.abort()
      throw error
    }
  }

  /// Encodes one cognitive decision and places it on a caller-owned shared GPU
  /// timeline without waiting for Metal feedback on the host. The returned
  /// ticket retains the complete shadow state and every zero-copy sensor lease.
  /// Call `finishDecisionSubmission` after the completion point (or its explicit
  /// host wait) has been observed; call `abortDecisionSubmission` on rejection.
  public func submitInferAndDecide(
    transaction: MetalJointAgentStateTransaction,
    numanXSensors: NumanXSensorPacketLease,
    regionalRecurrentInput: MetalRegionalRecurrentBufferView? = nil,
    externalGoal: ActiveGoal? = nil,
    waitFor waitPoint: MetalSharedEventPoint? = nil,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> DecisionSubmissionTicket {
    let packet = numanXSensors.packet
    guard packet.transactionFingerprint == transaction.jointToken.fingerprint,
      !packet.isAcceptedState,
      packet.deliveryTimestamp == transaction.jointToken.committedTimestamp,
      packet.physicsGeneration == transaction.jointToken.basePhysicsGeneration,
      packet.environmentIdentifier == transaction.jointToken.environmentIdentifier,
      packet.speciesTemplateFingerprint == speciesTemplateFingerprint,
      packet.sensoryProfileFingerprint == sensoryRuntime.profileFingerprint
    else {
      throw TissueError.transaction(
        "NumanX committed sensor packet does not belong to this control root"
      )
    }
    return try submitInferAndDecide(
      transaction: transaction,
      rawSensors: numanXSensors.rawSensors,
      regionalRecurrentInput: regionalRecurrentInput,
      externalGoal: externalGoal,
      waitFor: waitPoint,
      signal: completionPoint,
      retainedInputs: [numanXSensors]
    )
  }

  public func submitInferAndDecide(
    transaction: MetalJointAgentStateTransaction,
    rawSensors: [MetalRawSensorBufferLease],
    regionalRecurrentInput: MetalRegionalRecurrentBufferView? = nil,
    externalGoal: ActiveGoal? = nil,
    waitFor waitPoint: MetalSharedEventPoint? = nil,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> DecisionSubmissionTicket {
    try submitInferAndDecide(
      transaction: transaction,
      rawSensors: rawSensors,
      regionalRecurrentInput: regionalRecurrentInput,
      externalGoal: externalGoal,
      waitFor: waitPoint,
      signal: completionPoint,
      retainedInputs: rawSensors
    )
  }

  private func submitInferAndDecide(
    transaction: MetalJointAgentStateTransaction,
    rawSensors: [MetalRawSensorBufferLease],
    regionalRecurrentInput: MetalRegionalRecurrentBufferView?,
    externalGoal: ActiveGoal?,
    waitFor waitPoint: MetalSharedEventPoint?,
    signal completionPoint: MetalSharedEventPoint,
    retainedInputs: [AnyObject]
  ) throws -> DecisionSubmissionTicket {
    lock.lock()
    defer { lock.unlock() }
    guard activeAsyncSubmission == nil,
      transaction.status == .open,
      transaction.jointToken.parameterVersionFingerprint == parameterVersionFingerprint
    else {
      throw TissueError.transaction(
        "embodied control transaction is not open or already owns an async submission"
      )
    }
    try MetalSharedEventPoint.validateProgression(
      wait: waitPoint,
      signal: completionPoint,
      device: device
    )
    let duration = transaction.jointToken.targetTimestamp.rawValue
      - transaction.jointToken.committedTimestamp.rawValue
    guard duration > 0, duration <= UInt64(UInt32.max) else {
      throw TissueError.transaction("embodied control interval exceeds sensory ABI")
    }
    let dynamicResidency = try makeDynamicSensorResidency(rawSensors)
    var decisionGateResidency: (any MTLResidencySet)?
    do {
      guard let allocator = device.makeCommandAllocator(),
        let submissionBuffer = device.makeCommandBuffer()
      else {
        throw TissueError.metal("failed to allocate async embodied command resources")
      }
      submissionBuffer.beginCommandBuffer(allocator: allocator)
      submissionBuffer.useResidencySet(residencySet)
      if let dynamicResidency {
        submissionBuffer.useResidencySet(dynamicResidency)
      }
      guard let encoder = submissionBuffer.makeComputeCommandEncoder() else {
        submissionBuffer.endCommandBuffer()
        throw TissueError.metal("failed to encode async embodied cognitive control")
      }
      encoder.label = "NumiBrain async receptor to cognitive decision"
      try developmentalRuntime.encodeCurrentStage(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        timestamp: transaction.jointToken.committedTimestamp
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      let sensory = try sensoryRuntime.encode(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        rawSensorViews: rawSensors.map(\.view),
        environmentIdentifier: transaction.jointToken.environmentIdentifier,
        episodeIdentifier: transaction.jointToken.episodeIdentifier,
        controlStepIdentifier: transaction.jointToken.controlStepIdentifier,
        randomCounterGeneration: transaction.cachedRandomCounterGeneration,
        targetTimestamp: transaction.jointToken.committedTimestamp,
        deltaMicroseconds: UInt32(duration)
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try cognitiveRuntime.encodeAcceptedCognitiveStep(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        targetTimestamp: transaction.jointToken.committedTimestamp,
        deltaMicroseconds: duration,
        receptorEventCapacity: sensory.eventCapacity,
        regionalRecurrentInput: regionalRecurrentInput
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try memoryRuntime.encodeRetrieval(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        timestamp: transaction.jointToken.committedTimestamp
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      let decisionOutput = try decisionRuntime.encode(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        timestamp: transaction.jointToken.committedTimestamp,
        externalGoal: externalGoal
      )
      let decision = try makeDecisionBufferView(
        transaction: transaction,
        sensory: sensory,
        decision: decisionOutput,
        feedback: nil
      )
      let commandLease = try borrowNumanXSomaticBuffer(
        for: decision,
        transaction: transaction
      )
      let decisionGateEvaluation = try numanXMotorReadyRuntime
        .makeDecisionEvaluation(
          device: device,
          commandLease: commandLease,
          transaction: transaction.jointToken,
          readyPoint: completionPoint,
          compiledSpeciesTemplateFingerprint: compiledSpeciesTemplateFingerprint,
          parameterVersionFingerprint: parameterVersionFingerprint,
          regionalProgramFingerprint: regionalProgramFingerprint,
          scheduleFingerprint: scheduleFingerprint,
          brainProgramFingerprint: numanXBrainProgramFingerprint
        )
      let gateResidency = try numanXMotorReadyRuntime.makeResidencySet(
        device: device,
        label: "NumiBrain NumanX decision-ready residency",
        allocations: decisionGateEvaluation.residencyAllocations
      )
      decisionGateResidency = gateResidency
      submissionBuffer.useResidencySet(gateResidency)
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      numanXMotorReadyRuntime.encodeDecision(
        encoder: encoder,
        evaluation: decisionGateEvaluation
      )
      encoder.endEncoding()
      submissionBuffer.endCommandBuffer()

      let feedbackState = MetalAsyncFeedbackState()
      var residencySets = dynamicResidency.map { [$0] } ?? []
      residencySets.append(gateResidency)
      let resources = MetalAsyncCommandResources(
        allocator: allocator,
        commandBuffer: submissionBuffer,
        residencySets: residencySets
      )
      var allRetainedInputs = retainedInputs
      allRetainedInputs.append(commandLease)
      allRetainedInputs.append(decisionGateEvaluation)
      let identifier = UUID()
      activeAsyncSubmission = ActiveAsyncSubmission(
        identifier: identifier,
        kind: .decision,
        transactionFingerprint: transaction.jointToken.fingerprint,
        feedbackState: feedbackState,
        resources: resources,
        retainedInputs: allRetainedInputs
      )
      if let waitPoint {
        commandQueue.waitForEvent(waitPoint.event, value: waitPoint.value)
      }
      let options = MTL4CommitOptions()
      options.addFeedbackHandler { feedback in
        if feedback.error != nil || !decisionGateEvaluation.hasValidSuccess() {
          decisionGateEvaluation.markFailure()
        }
        feedbackState.record(feedback, label: "NumiBrain embodied cognitive control")
        if completionPoint.event.signaledValue < completionPoint.value {
          completionPoint.event.signaledValue = completionPoint.value
        }
        _ = resources
        _ = self
      }
      commandQueue.commit([submissionBuffer], options: options)
      return DecisionSubmissionTicket(
        identifier: identifier,
        owner: self,
        decision: decision,
        waitPoint: waitPoint,
        completionPoint: completionPoint,
        feedbackState: feedbackState,
        decisionGateEvaluation: decisionGateEvaluation
      )
    } catch {
      decisionGateResidency?.endResidency()
      dynamicResidency?.endResidency()
      try? transaction.abort()
      throw error
    }
  }

  /// Completes the explicit host side of an async decision without changing
  /// joint publication. The returned feedback is measured Metal execution;
  /// the ticket's decision addresses remain owned by the open transaction.
  @discardableResult
  public func finishDecisionSubmission(
    _ ticket: DecisionSubmissionTicket,
    transaction: MetalJointAgentStateTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws -> MetalGPUCompletionFeedback {
    lock.lock()
    defer { lock.unlock() }
    guard let active = activeAsyncSubmission,
      active.identifier == ticket.identifier,
      active.kind == .decision,
      active.transactionFingerprint == transaction.jointToken.fingerprint,
      active.feedbackState === ticket.feedbackState,
      !active.abortRequested,
      transaction.status == .open
    else {
      throw TissueError.transaction("async decision ticket is stale or not owned here")
    }
    do {
      let feedback = try ticket.feedbackState.wait(
        timeoutMilliseconds: timeoutMilliseconds
      )
      guard ticket.decisionGateEvaluation.hasValidSuccess() else {
        throw TissueError.transaction(
          "NumanX decision-ready gate rejected the cognitive output"
        )
      }
      active.resources.release()
      activeAsyncSubmission = nil
      return feedback
    } catch {
      // A host timeout is not a GPU cancellation. Keep every allocation and
      // lease quarantined while the queue may still be waiting or executing.
      // Only published Metal feedback proves it is safe to reap the command.
      if ticket.feedbackState.hasCompleted {
        active.resources.release()
        activeAsyncSubmission = nil
        try? transaction.abort()
      }
      throw error
    }
  }

  /// Nonblocking coordinator boundary. A nil result retains the sole active
  /// submission; a terminal failure releases its resources and aborts the
  /// unpublished cognitive shadow.
  func reapDecisionSubmissionIfCompleted(
    _ ticket: DecisionSubmissionTicket,
    transaction: MetalJointAgentStateTransaction
  ) throws -> MetalGPUCompletionFeedback? {
    lock.lock()
    defer { lock.unlock() }
    guard let active = activeAsyncSubmission,
      active.identifier == ticket.identifier,
      active.kind == .decision,
      active.transactionFingerprint == transaction.jointToken.fingerprint,
      active.feedbackState === ticket.feedbackState,
      !active.abortRequested,
      transaction.status == .open
    else {
      throw TissueError.transaction("async decision ticket is stale or not owned here")
    }
    let feedback: MetalGPUCompletionFeedback
    do {
      guard let available = try ticket.feedbackState.poll() else { return nil }
      feedback = available
      guard ticket.decisionGateEvaluation.hasValidSuccess() else {
        throw TissueError.transaction(
          "NumanX decision-ready gate rejected the cognitive output"
        )
      }
    } catch {
      active.resources.release()
      activeAsyncSubmission = nil
      if transaction.status == .open { try? transaction.abort() }
      throw error
    }
    active.resources.release()
    activeAsyncSubmission = nil
    return feedback
  }

  public func abortDecisionSubmission(
    _ ticket: DecisionSubmissionTicket,
    transaction: MetalJointAgentStateTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    guard let active = activeAsyncSubmission,
      active.identifier == ticket.identifier,
      active.kind == .decision,
      active.transactionFingerprint == transaction.jointToken.fingerprint
    else {
      throw TissueError.transaction("async decision ticket is stale or not owned here")
    }
    active.abortRequested = true
    var completionError: Error?
    do {
      _ = try ticket.feedbackState.wait(timeoutMilliseconds: timeoutMilliseconds)
    } catch {
      guard ticket.feedbackState.hasCompleted else {
        // The logical abort is sticky, but its resources cannot be released
        // until Metal reports that the queued work is no longer in flight.
        throw error
      }
      completionError = error
    }
    active.resources.release()
    activeAsyncSubmission = nil
    if transaction.status == .open {
      try transaction.abort()
    }
    if let completionError { throw completionError }
  }

  /// Coordinator-only quarantine probe. A true result means Metal has not
  /// been safely reaped, so the complete-brain root must remain unavailable.
  func ownsOutstandingSubmission(_ identifier: UUID) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return activeAsyncSubmission?.identifier == identifier
  }

  public func commit(
    transaction: MetalJointAgentStateTransaction,
    receipt: BrainJointCommitToken
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    guard activeAsyncSubmission == nil else {
      throw TissueError.transaction(
        "finish or abort the async GPU submission before commit"
      )
    }
    try transaction.commit(with: receipt)
  }

  func prepareCommit(
    transaction: MetalJointAgentStateTransaction,
    receipt: BrainJointCommitToken
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    guard activeAsyncSubmission == nil else {
      throw TissueError.transaction(
        "finish or abort the async GPU submission before preparing commit"
      )
    }
    try transaction.prepareCommit(with: receipt)
  }

  func publishPreparedCommit(
    transaction: MetalJointAgentStateTransaction
  ) {
    transaction.publishPreparedCommit()
  }

  public func abort(transaction: MetalJointAgentStateTransaction) throws {
    lock.lock()
    defer { lock.unlock() }
    guard activeAsyncSubmission == nil else {
      throw TissueError.transaction(
        "use the async ticket abort contract while GPU work is outstanding"
      )
    }
    try transaction.abort()
  }

  /// Assimilates only receptor signals generated from the accepted physical
  /// root, then seals hot state and memory for an atomic joint commit.
  public func finalizeAcceptedControl(
    transaction: MetalJointAgentStateTransaction,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    numanXSensors: NumanXSensorPacketLease,
    acceptedRegionalRecurrentInput: MetalRegionalRecurrentBufferView,
    developmentalEvidence: MetalDevelopmentalEvidenceBufferLease? = nil,
    teacherState: MetalTeacherStateBufferLease? = nil
  ) throws -> AcceptedConsequenceView {
    let packet = numanXSensors.packet
    guard packet.transactionFingerprint == transaction.jointToken.fingerprint,
      packet.isAcceptedState,
      packet.acceptedPhysicsTokenFingerprint == acceptedPhysicsState.fingerprint,
      packet.deliveryTimestamp == acceptedPhysicsState.acceptedTimestamp,
      packet.physicsGeneration == acceptedPhysicsState.physicsGeneration,
      packet.environmentIdentifier == acceptedPhysicsState.environmentIdentifier,
      packet.speciesTemplateFingerprint == speciesTemplateFingerprint,
      packet.sensoryProfileFingerprint == sensoryRuntime.profileFingerprint
    else {
      throw TissueError.transaction(
        "NumanX accepted sensor packet does not belong to this physical state"
      )
    }
    return try finalizeAcceptedControl(
      transaction: transaction,
      acceptedPhysicsState: acceptedPhysicsState,
      rawSensors: numanXSensors.rawSensors,
      acceptedRegionalRecurrentInput: acceptedRegionalRecurrentInput,
      developmentalEvidence: developmentalEvidence,
      teacherState: teacherState
    )
  }

  public func finalizeAcceptedControl(
    transaction: MetalJointAgentStateTransaction,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    rawSensors: [MetalRawSensorBufferLease],
    acceptedRegionalRecurrentInput: MetalRegionalRecurrentBufferView,
    developmentalEvidence: MetalDevelopmentalEvidenceBufferLease? = nil,
    teacherState: MetalTeacherStateBufferLease? = nil
  ) throws -> AcceptedConsequenceView {
    lock.lock()
    defer { lock.unlock() }
    guard activeAsyncSubmission == nil,
      transaction.status == .open,
      acceptedPhysicsState.transactionFingerprint
        == transaction.jointToken.fingerprint,
      acceptedPhysicsState.acceptedTimestamp
        == transaction.jointToken.targetTimestamp,
      acceptedPhysicsState.environmentIdentifier
        == transaction.jointToken.environmentIdentifier
    else {
      throw TissueError.transaction(
        "accepted consequence does not finish the open embodied control root"
      )
    }
    let duration =
      transaction.jointToken.targetTimestamp.rawValue
      - transaction.jointToken.committedTimestamp.rawValue
    guard duration > 0, duration <= UInt64(UInt32.max) else {
      throw TissueError.transaction("accepted control interval exceeds sensory ABI")
    }
    let acceptedFastMotorState = try transaction.borrowAcceptedFastMotorState()
    let dynamicResidency = try makeDynamicAcceptedResidency(
      sensors: rawSensors,
      developmentalEvidence: developmentalEvidence,
      teacherState: teacherState,
      acceptedFastMotorState: acceptedFastMotorState
    )
    defer { dynamicResidency?.endResidency() }
    do {
      commandAllocator.reset()
      commandBuffer.beginCommandBuffer(allocator: commandAllocator)
      commandBuffer.useResidencySet(residencySet)
      if let dynamicResidency { commandBuffer.useResidencySet(dynamicResidency) }
      guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
        commandBuffer.endCommandBuffer()
        throw TissueError.metal("failed to encode accepted brain consequence")
      }
      encoder.label = "NumiBrain accepted physical consequence"
      let sensory = try sensoryRuntime.encode(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        rawSensorViews: rawSensors.map(\.view),
        environmentIdentifier: transaction.jointToken.environmentIdentifier,
        episodeIdentifier: transaction.jointToken.episodeIdentifier,
        controlStepIdentifier: transaction.jointToken.controlStepIdentifier,
        randomCounterGeneration: transaction.cachedRandomCounterGeneration,
        targetTimestamp: acceptedPhysicsState.acceptedTimestamp,
        deltaMicroseconds: UInt32(duration)
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try cognitiveRuntime.encodeAcceptedRegionalRecurrentIngest(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        targetTimestamp: acceptedPhysicsState.acceptedTimestamp,
        deltaMicroseconds: duration,
        regionalRecurrentInput: acceptedRegionalRecurrentInput
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try acceptedConsequenceRuntime.encode(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        acceptedPhysicsState: acceptedPhysicsState,
        deltaMicroseconds: duration,
        receptorEventCapacity: sensory.eventCapacity,
        acceptedFastMotorState: acceptedFastMotorState
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try cognitiveRuntime.encodeAcceptedBeliefAssimilation(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        targetTimestamp: acceptedPhysicsState.acceptedTimestamp,
        deltaMicroseconds: duration,
        receptorEventCapacity: sensory.eventCapacity
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try developmentalRuntime.encodeAcceptedProgress(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        acceptedPhysicsState: acceptedPhysicsState,
        deltaMicroseconds: duration,
        evidence: developmentalEvidence
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try memoryRuntime.encodeAcceptedReconsolidation(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        timestamp: acceptedPhysicsState.acceptedTimestamp
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try memoryRuntime.encodeProspectiveLifecycle(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        timestamp: acceptedPhysicsState.acceptedTimestamp
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try memoryRuntime.encodeRestConsolidation(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        timestamp: acceptedPhysicsState.acceptedTimestamp
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try memoryRuntime.encodeEpisodicSegmentation(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        episodeIdentifier: transaction.jointToken.episodeIdentifier,
        controlStepIdentifier: transaction.jointToken.controlStepIdentifier,
        timestamp: acceptedPhysicsState.acceptedTimestamp
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try memoryRuntime.encodeCommittedTransition(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        episodeIdentifier: transaction.jointToken.episodeIdentifier,
        controlStepIdentifier: transaction.jointToken.controlStepIdentifier,
        previousTimestamp: transaction.jointToken.committedTimestamp,
        acceptedPhysicsState: acceptedPhysicsState,
        teacherState: teacherState
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try memoryRuntime.encodeCommittedCounterfactuals(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        episodeIdentifier: transaction.jointToken.episodeIdentifier,
        controlStepIdentifier: transaction.jointToken.controlStepIdentifier,
        sourceBeliefTimestamp: transaction.jointToken.committedTimestamp,
        acceptedTimestamp: acceptedPhysicsState.acceptedTimestamp
      )
      encoder.endEncoding()
      commandBuffer.endCommandBuffer()
      let feedback = try commitCommandBuffer(
        label: "NumiBrain accepted physical consequence"
      )
      try transaction.finishGPUState(
        acceptedPhysicsState: acceptedPhysicsState
      )
      return AcceptedConsequenceView(
        transactionFingerprint: transaction.jointToken.fingerprint,
        shadowGeneration: transaction.agentStateToken.shadowGeneration,
        acceptedPhysicsTokenFingerprint: acceptedPhysicsState.fingerprint,
        acceptedTimestamp: acceptedPhysicsState.acceptedTimestamp,
        sensoryObservationGPUAddress: sensory.observationGPUAddress,
        sensoryObservationScalarCount: sensory.observationScalarCount,
        receptorEventQueueGPUAddress: sensory.eventQueueGPUAddress,
        receptorEventCapacity: sensory.eventCapacity,
        gpuStartSeconds: feedback.gpuStartTime,
        gpuEndSeconds: feedback.gpuEndTime
      )
    } catch {
      try? transaction.abort()
      throw error
    }
  }

  /// Encodes accepted sensory assimilation and memory journals onto an
  /// externally composable shared-event timeline. The transaction remains
  /// open until `finishAcceptedConsequenceSubmission` validates Metal feedback
  /// and seals its GPU state.
  public func submitAcceptedConsequence(
    transaction: MetalJointAgentStateTransaction,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    candidateSubstep: BrainJointSubstepToken,
    acceptedPhysicsGate: MetalAcceptedPhysicsGateLease,
    numanXSensors: NumanXSensorPacketLease,
    acceptedRegionalRecurrentInput: MetalRegionalRecurrentBufferView,
    developmentalEvidence: MetalDevelopmentalEvidenceBufferLease? = nil,
    teacherState: MetalTeacherStateBufferLease? = nil,
    waitFor waitPoint: MetalSharedEventPoint? = nil,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> AcceptedConsequenceSubmissionTicket {
    let packet = numanXSensors.packet
    guard packet.transactionFingerprint == transaction.jointToken.fingerprint,
      packet.isAcceptedState,
      packet.acceptedPhysicsTokenFingerprint == acceptedPhysicsState.fingerprint,
      packet.deliveryTimestamp == acceptedPhysicsState.acceptedTimestamp,
      packet.physicsGeneration == acceptedPhysicsState.physicsGeneration,
      packet.environmentIdentifier == acceptedPhysicsState.environmentIdentifier,
      packet.speciesTemplateFingerprint == speciesTemplateFingerprint,
      packet.sensoryProfileFingerprint == sensoryRuntime.profileFingerprint
    else {
      throw TissueError.transaction(
        "NumanX accepted sensor packet does not belong to this physical state"
      )
    }
    var retainedInputs: [AnyObject] = [numanXSensors, acceptedPhysicsGate]
    if let developmentalEvidence { retainedInputs.append(developmentalEvidence) }
    if let teacherState { retainedInputs.append(teacherState) }
    return try submitAcceptedConsequence(
      transaction: transaction,
      acceptedPhysicsState: acceptedPhysicsState,
      candidateSubstep: candidateSubstep,
      acceptedPhysicsGate: acceptedPhysicsGate,
      rawSensors: numanXSensors.rawSensors,
      acceptedRegionalRecurrentInput: acceptedRegionalRecurrentInput,
      developmentalEvidence: developmentalEvidence,
      teacherState: teacherState,
      numanXRootPrepare: nil,
      waitFor: waitPoint,
      signal: completionPoint,
      retainedInputs: retainedInputs
    )
  }

  public func submitAcceptedConsequence(
    transaction: MetalJointAgentStateTransaction,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    candidateSubstep: BrainJointSubstepToken,
    acceptedPhysicsGate: MetalAcceptedPhysicsGateLease,
    rawSensors: [MetalRawSensorBufferLease],
    acceptedRegionalRecurrentInput: MetalRegionalRecurrentBufferView,
    developmentalEvidence: MetalDevelopmentalEvidenceBufferLease? = nil,
    teacherState: MetalTeacherStateBufferLease? = nil,
    waitFor waitPoint: MetalSharedEventPoint? = nil,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> AcceptedConsequenceSubmissionTicket {
    var retainedInputs: [AnyObject] = [acceptedPhysicsGate]
    retainedInputs.append(contentsOf: rawSensors)
    if let developmentalEvidence { retainedInputs.append(developmentalEvidence) }
    if let teacherState { retainedInputs.append(teacherState) }
    return try submitAcceptedConsequence(
      transaction: transaction,
      acceptedPhysicsState: acceptedPhysicsState,
      candidateSubstep: candidateSubstep,
      acceptedPhysicsGate: acceptedPhysicsGate,
      rawSensors: rawSensors,
      acceptedRegionalRecurrentInput: acceptedRegionalRecurrentInput,
      developmentalEvidence: developmentalEvidence,
      teacherState: teacherState,
      numanXRootPrepare: nil,
      waitFor: waitPoint,
      signal: completionPoint,
      retainedInputs: retainedInputs
    )
  }

  /// Production event-driven handoff. The host supplies only the immutable
  /// root/substep relation and a retained GPU token lease; it does not know or
  /// read the physical-state digest before submission.
  public func submitAcceptedConsequence(
    transaction: MetalJointAgentStateTransaction,
    candidateSubstep: BrainJointSubstepToken,
    acceptedPhysicsGate: MetalAcceptedPhysicsGateLease,
    rawSensors: [MetalRawSensorBufferLease],
    acceptedRegionalRecurrentInput: MetalRegionalRecurrentBufferView,
    teacherState: MetalTeacherStateBufferLease? = nil,
    waitFor waitPoint: MetalSharedEventPoint? = nil,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> AcceptedConsequenceSubmissionTicket {
    var retainedInputs: [AnyObject] = [acceptedPhysicsGate]
    retainedInputs.append(contentsOf: rawSensors)
    if let teacherState { retainedInputs.append(teacherState) }
    return try submitAcceptedConsequence(
      transaction: transaction,
      acceptedPhysicsState: nil,
      candidateSubstep: candidateSubstep,
      acceptedPhysicsGate: acceptedPhysicsGate,
      rawSensors: rawSensors,
      acceptedRegionalRecurrentInput: acceptedRegionalRecurrentInput,
      developmentalEvidence: nil,
      teacherState: teacherState,
      numanXRootPrepare: nil,
      waitFor: waitPoint,
      signal: completionPoint,
      retainedInputs: retainedInputs
    )
  }

  /// Owner-v2 production preparation. The distinct Brain commit witness is
  /// encoded after every accepted-consequence writer. This overload does not
  /// make the legacy start gate sufficient for publication.
  public func submitAcceptedConsequence(
    transaction: MetalJointAgentStateTransaction,
    candidateSubstep: BrainJointSubstepToken,
    acceptedPhysicsGate: MetalAcceptedPhysicsGateLease,
    rawSensors: [MetalRawSensorBufferLease],
    acceptedRegionalRecurrentInput: MetalRegionalRecurrentBufferView,
    teacherState: MetalTeacherStateBufferLease? = nil,
    numanXRootPrepare: MetalNumanXBrainCommitPrepareRequest,
    waitFor waitPoint: MetalSharedEventPoint? = nil,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> AcceptedConsequenceSubmissionTicket {
    var retainedInputs: [AnyObject] = [acceptedPhysicsGate]
    retainedInputs.append(contentsOf: rawSensors)
    if let teacherState { retainedInputs.append(teacherState) }
    retainedInputs.append(contentsOf: numanXRootPrepare.fastStateSources)
    return try submitAcceptedConsequence(
      transaction: transaction,
      acceptedPhysicsState: nil,
      candidateSubstep: candidateSubstep,
      acceptedPhysicsGate: acceptedPhysicsGate,
      rawSensors: rawSensors,
      acceptedRegionalRecurrentInput: acceptedRegionalRecurrentInput,
      developmentalEvidence: nil,
      teacherState: teacherState,
      numanXRootPrepare: numanXRootPrepare,
      waitFor: waitPoint,
      signal: completionPoint,
      retainedInputs: retainedInputs
    )
  }

  private func submitAcceptedConsequence(
    transaction: MetalJointAgentStateTransaction,
    acceptedPhysicsState: AcceptedPhysicsStateToken?,
    candidateSubstep: BrainJointSubstepToken,
    acceptedPhysicsGate: MetalAcceptedPhysicsGateLease,
    rawSensors: [MetalRawSensorBufferLease],
    acceptedRegionalRecurrentInput: MetalRegionalRecurrentBufferView,
    developmentalEvidence: MetalDevelopmentalEvidenceBufferLease?,
    teacherState: MetalTeacherStateBufferLease?,
    numanXRootPrepare: MetalNumanXBrainCommitPrepareRequest?,
    waitFor waitPoint: MetalSharedEventPoint?,
    signal completionPoint: MetalSharedEventPoint,
    retainedInputs baseRetainedInputs: [AnyObject]
  ) throws -> AcceptedConsequenceSubmissionTicket {
    lock.lock()
    defer { lock.unlock() }
    guard activeAsyncSubmission == nil,
      transaction.status == .open,
      candidateSubstep.transactionFingerprint == transaction.jointToken.fingerprint,
      candidateSubstep.candidateTimestamp == transaction.jointToken.targetTimestamp,
      candidateSubstep.shadowGeneration == transaction.jointToken.shadowGeneration,
      candidateSubstep.randomCounterGeneration
        == transaction.jointToken.randomCounterGeneration,
      acceptedPhysicsState == nil
        || (acceptedPhysicsState!.transactionFingerprint
          == transaction.jointToken.fingerprint
          && acceptedPhysicsState!.substepFingerprint
            == candidateSubstep.fingerprint
          && acceptedPhysicsState!.acceptedTimestamp
            == transaction.jointToken.targetTimestamp
          && acceptedPhysicsState!.environmentIdentifier
            == transaction.jointToken.environmentIdentifier)
    else {
      throw TissueError.transaction(
        "accepted consequence does not finish the open embodied control root"
      )
    }
    try MetalSharedEventPoint.validateProgression(
      wait: waitPoint,
      signal: completionPoint,
      device: device
    )
    let duration = transaction.jointToken.targetTimestamp.rawValue
      - transaction.jointToken.committedTimestamp.rawValue
    guard duration > 0, duration <= UInt64(UInt32.max) else {
      throw TissueError.transaction("accepted control interval exceeds sensory ABI")
    }
    let acceptedTimestamp = candidateSubstep.candidateTimestamp
    let acceptedFastMotorState = try transaction.borrowAcceptedFastMotorState()
    let gateEvaluation = try acceptedPhysicsGateRuntime.makeEvaluation(
      device: device,
      lease: acceptedPhysicsGate,
      transaction: transaction.jointToken,
      substep: candidateSubstep
    )
    let numanXPrepareEvaluation: MetalNumanXBrainCommitPrepareEvaluation?
    if let numanXRootPrepare {
      let hotBuffer = try agentStateRuntime.arena.borrowShadowHotBuffer(
        transaction: transaction.agentStateToken
      )
      let journalBuffer = try agentStateRuntime.arena.borrowShadowJournalBuffer(
        transaction: transaction.agentStateToken
      )
      numanXPrepareEvaluation = try numanXHumanMatterRuntime.makePrepareEvaluation(
        request: numanXRootPrepare,
        transaction: transaction,
        substep: candidateSubstep,
        startGate: gateEvaluation,
        hotBuffer: hotBuffer,
        journalBuffer: journalBuffer,
        fastPreparedPoint: waitPoint
      )
    } else {
      numanXPrepareEvaluation = nil
    }
    let dynamicResidency = try makeDynamicAcceptedResidency(
      sensors: rawSensors,
      developmentalEvidence: developmentalEvidence,
      teacherState: teacherState,
      acceptedFastMotorState: acceptedFastMotorState,
      gateEvaluation: gateEvaluation,
      numanXPrepareEvaluation: numanXPrepareEvaluation
    )
    do {
      guard let allocator = device.makeCommandAllocator(),
        let submissionBuffer = device.makeCommandBuffer()
      else {
        throw TissueError.metal("failed to allocate async consequence resources")
      }
      submissionBuffer.beginCommandBuffer(allocator: allocator)
      submissionBuffer.useResidencySet(residencySet)
      if let dynamicResidency {
        submissionBuffer.useResidencySet(dynamicResidency)
      }
      guard let encoder = submissionBuffer.makeComputeCommandEncoder() else {
        submissionBuffer.endCommandBuffer()
        throw TissueError.metal("failed to encode async accepted consequence")
      }
      encoder.label = "NumiBrain async accepted physical consequence"
      acceptedPhysicsGateRuntime.encodeValidation(
        encoder: encoder,
        evaluation: gateEvaluation
      )
      if let acceptedFastMotorState {
        try encodeAcceptedFastMotorStateImport(
          encoder: encoder,
          lease: acceptedFastMotorState,
          transaction: transaction,
          gateEvaluation: gateEvaluation
        )
        encoder.barrier(
          afterEncoderStages: .dispatch,
          beforeEncoderStages: .dispatch,
          visibilityOptions: .device
        )
      }
      let sensory = try sensoryRuntime.encode(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        rawSensorViews: rawSensors.map(\.view),
        environmentIdentifier: transaction.jointToken.environmentIdentifier,
        episodeIdentifier: transaction.jointToken.episodeIdentifier,
        controlStepIdentifier: transaction.jointToken.controlStepIdentifier,
        randomCounterGeneration: transaction.cachedRandomCounterGeneration,
        targetTimestamp: acceptedTimestamp,
        deltaMicroseconds: UInt32(duration),
        acceptanceGateGPUAddress: gateEvaluation.resultBuffer.gpuAddress + 4
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try cognitiveRuntime.encodeAcceptedRegionalRecurrentIngest(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        targetTimestamp: acceptedTimestamp,
        deltaMicroseconds: duration,
        regionalRecurrentInput: acceptedRegionalRecurrentInput,
        acceptanceGateGPUAddress: gateEvaluation.resultBuffer.gpuAddress + 4
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try acceptedConsequenceRuntime.encodeAuthoritativeGate(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        acceptedTimestamp: acceptedTimestamp,
        acceptedTransactionFingerprint: transaction.jointToken.fingerprint,
        deltaMicroseconds: duration,
        receptorEventCapacity: sensory.eventCapacity,
        acceptedFastMotorState: acceptedFastMotorState,
        acceptanceGateGPUAddress: gateEvaluation.resultBuffer.gpuAddress + 4,
        acceptanceGateResultGPUAddress: gateEvaluation.resultBuffer.gpuAddress
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try cognitiveRuntime.encodeAcceptedBeliefAssimilation(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        targetTimestamp: acceptedTimestamp,
        deltaMicroseconds: duration,
        receptorEventCapacity: sensory.eventCapacity,
        acceptanceGateGPUAddress: gateEvaluation.resultBuffer.gpuAddress + 4
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      if let acceptedPhysicsState {
        try developmentalRuntime.encodeAcceptedProgress(
          encoder: encoder,
          transaction: transaction.agentStateToken,
          acceptedPhysicsState: acceptedPhysicsState,
          deltaMicroseconds: duration,
          evidence: developmentalEvidence,
          acceptanceGateGPUAddress: gateEvaluation.resultBuffer.gpuAddress + 4,
          acceptanceGateResultGPUAddress: gateEvaluation.resultBuffer.gpuAddress
        )
      } else {
        try developmentalRuntime.encodeAcceptedProgressAuthoritativeGate(
          encoder: encoder,
          transaction: transaction.agentStateToken,
          targetTimestamp: acceptedTimestamp,
          deltaMicroseconds: duration,
          acceptanceGateGPUAddress: gateEvaluation.resultBuffer.gpuAddress + 4,
          acceptanceGateResultGPUAddress: gateEvaluation.resultBuffer.gpuAddress
        )
      }
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try memoryRuntime.encodeAcceptedReconsolidation(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        timestamp: acceptedTimestamp,
        acceptanceGateGPUAddress: gateEvaluation.resultBuffer.gpuAddress + 4
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try memoryRuntime.encodeProspectiveLifecycle(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        timestamp: acceptedTimestamp,
        acceptanceGateGPUAddress: gateEvaluation.resultBuffer.gpuAddress + 4
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try memoryRuntime.encodeRestConsolidation(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        timestamp: acceptedTimestamp,
        acceptanceGateGPUAddress: gateEvaluation.resultBuffer.gpuAddress + 4
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try memoryRuntime.encodeEpisodicSegmentation(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        episodeIdentifier: transaction.jointToken.episodeIdentifier,
        controlStepIdentifier: transaction.jointToken.controlStepIdentifier,
        timestamp: acceptedTimestamp,
        acceptanceGateGPUAddress: gateEvaluation.resultBuffer.gpuAddress + 4
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try memoryRuntime.encodeCommittedTransitionAuthoritativeGate(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        episodeIdentifier: transaction.jointToken.episodeIdentifier,
        controlStepIdentifier: transaction.jointToken.controlStepIdentifier,
        previousTimestamp: transaction.jointToken.committedTimestamp,
        acceptedTimestamp: acceptedTimestamp,
        teacherState: teacherState,
        acceptanceGateGPUAddress: gateEvaluation.resultBuffer.gpuAddress + 4,
        acceptanceGateResultGPUAddress: gateEvaluation.resultBuffer.gpuAddress
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      try memoryRuntime.encodeCommittedCounterfactuals(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        episodeIdentifier: transaction.jointToken.episodeIdentifier,
        controlStepIdentifier: transaction.jointToken.controlStepIdentifier,
        sourceBeliefTimestamp: transaction.jointToken.committedTimestamp,
        acceptedTimestamp: acceptedTimestamp,
        acceptanceGateGPUAddress: gateEvaluation.resultBuffer.gpuAddress + 4
      )
      if let numanXPrepareEvaluation {
        encoder.barrier(
          afterEncoderStages: .dispatch,
          beforeEncoderStages: .dispatch,
          visibilityOptions: .device
        )
        try transaction.encodeProvisionalGPUStateFinish(
          encoder: encoder,
          provisional:
            numanXPrepareEvaluation.request.provisionalPhysicsAcceptance
        )
        encoder.barrier(
          afterEncoderStages: .dispatch,
          beforeEncoderStages: .dispatch,
          visibilityOptions: .device
        )
        numanXHumanMatterRuntime.encodePrepare(
          encoder: encoder,
          evaluation: numanXPrepareEvaluation
        )
      }
      encoder.endEncoding()
      submissionBuffer.endCommandBuffer()

      let consequence = AcceptedConsequenceView(
        transactionFingerprint: transaction.jointToken.fingerprint,
        shadowGeneration: transaction.agentStateToken.shadowGeneration,
        acceptedPhysicsTokenFingerprint: acceptedPhysicsState?.fingerprint ?? 0,
        acceptedTimestamp: acceptedTimestamp,
        sensoryObservationGPUAddress: sensory.observationGPUAddress,
        sensoryObservationScalarCount: sensory.observationScalarCount,
        receptorEventQueueGPUAddress: sensory.eventQueueGPUAddress,
        receptorEventCapacity: sensory.eventCapacity,
        gpuStartSeconds: 0,
        gpuEndSeconds: 0
      )
      let feedbackState = MetalAsyncFeedbackState()
      let resources = MetalAsyncCommandResources(
        allocator: allocator,
        commandBuffer: submissionBuffer,
        residencySets: dynamicResidency.map { [$0] } ?? []
      )
      var retainedInputs = baseRetainedInputs
      if let acceptedFastMotorState { retainedInputs.append(acceptedFastMotorState) }
      if let numanXPrepareEvaluation { retainedInputs.append(numanXPrepareEvaluation) }
      let identifier = UUID()
      activeAsyncSubmission = ActiveAsyncSubmission(
        identifier: identifier,
        kind: .acceptedConsequence,
        transactionFingerprint: transaction.jointToken.fingerprint,
        feedbackState: feedbackState,
        resources: resources,
        retainedInputs: retainedInputs
      )
      if let waitPoint {
        commandQueue.waitForEvent(waitPoint.event, value: waitPoint.value)
      }
      let options = MTL4CommitOptions()
      options.addFeedbackHandler { feedback in
        if let numanXPrepareEvaluation {
          if feedback.error != nil ||
              !numanXPrepareEvaluation.hasValidPreparedWitness() {
            // The kernel may have written a valid-looking witness before a
            // later command-buffer fault. Publish a complete FAILURE record
            // before the CPU liveness signal wakes an owner proposal wait.
            numanXPrepareEvaluation.markWitnessPrepareFailed()
          }
          if completionPoint.event.signaledValue < completionPoint.value {
            completionPoint.event.signaledValue = completionPoint.value
          }
        }
        feedbackState.record(feedback, label: "NumiBrain accepted physical consequence")
        _ = resources
        _ = self
      }
      commandQueue.commit([submissionBuffer], options: options)
      if numanXPrepareEvaluation == nil {
        commandQueue.signalEvent(completionPoint.event, value: completionPoint.value)
      }
      return AcceptedConsequenceSubmissionTicket(
        identifier: identifier,
        owner: self,
        consequence: consequence,
        waitPoint: waitPoint,
        completionPoint: completionPoint,
        feedbackState: feedbackState,
        gateEvaluation: gateEvaluation,
        numanXPrepareEvaluation: numanXPrepareEvaluation
      )
    } catch {
      dynamicResidency?.endResidency()
      try? transaction.abort()
      throw error
    }
  }

  @discardableResult
  public func finishAcceptedConsequenceSubmission(
    _ ticket: AcceptedConsequenceSubmissionTicket,
    transaction: MetalJointAgentStateTransaction,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws -> MetalGPUCompletionFeedback {
    try finishAcceptedConsequenceSubmission(
      ticket,
      transaction: transaction,
      expectedAcceptedPhysicsState: acceptedPhysicsState,
      timeoutMilliseconds: timeoutMilliseconds
    ).feedback
  }

  /// Finalizes the production GPU-token path. Only the 128-byte gate result is
  /// read on the host; raw sensor and physical-state payloads stay device-side.
  public func finishAcceptedConsequenceSubmission(
    _ ticket: AcceptedConsequenceSubmissionTicket,
    transaction: MetalJointAgentStateTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws -> AcceptedConsequenceCompletion {
    try finishAcceptedConsequenceSubmission(
      ticket,
      transaction: transaction,
      expectedAcceptedPhysicsState: nil,
      timeoutMilliseconds: timeoutMilliseconds
    )
  }

  private func finishAcceptedConsequenceSubmission(
    _ ticket: AcceptedConsequenceSubmissionTicket,
    transaction: MetalJointAgentStateTransaction,
    expectedAcceptedPhysicsState: AcceptedPhysicsStateToken?,
    timeoutMilliseconds: UInt64
  ) throws -> AcceptedConsequenceCompletion {
    lock.lock()
    defer { lock.unlock() }
    guard let active = activeAsyncSubmission,
      active.identifier == ticket.identifier,
      active.kind == .acceptedConsequence,
      active.transactionFingerprint == transaction.jointToken.fingerprint,
      active.feedbackState === ticket.feedbackState,
      !active.abortRequested,
      expectedAcceptedPhysicsState == nil
        || ticket.consequence.acceptedPhysicsTokenFingerprint
          == expectedAcceptedPhysicsState!.fingerprint,
      ticket.numanXPrepareEvaluation == nil,
      transaction.status == .open
    else {
      throw TissueError.transaction(
        "async accepted-consequence ticket is stale or not owned here"
      )
    }
    do {
      let feedback = try ticket.feedbackState.wait(
        timeoutMilliseconds: timeoutMilliseconds
      )
      let acceptedPhysicsState = try ticket.gateEvaluation.validateAcceptedResult()
      guard expectedAcceptedPhysicsState == nil
        || acceptedPhysicsState == expectedAcceptedPhysicsState
      else {
        throw TissueError.transaction(
          "GPU accepted-physics token differs from the host compatibility proof"
        )
      }
      try transaction.finishGPUState(acceptedPhysicsState: acceptedPhysicsState)
      let consequence = AcceptedConsequenceView(
        transactionFingerprint: ticket.consequence.transactionFingerprint,
        shadowGeneration: ticket.consequence.shadowGeneration,
        acceptedPhysicsTokenFingerprint: acceptedPhysicsState.fingerprint,
        acceptedTimestamp: acceptedPhysicsState.acceptedTimestamp,
        sensoryObservationGPUAddress:
          ticket.consequence.sensoryObservationGPUAddress,
        sensoryObservationScalarCount:
          ticket.consequence.sensoryObservationScalarCount,
        receptorEventQueueGPUAddress:
          ticket.consequence.receptorEventQueueGPUAddress,
        receptorEventCapacity: ticket.consequence.receptorEventCapacity,
        gpuStartSeconds: feedback.gpuStartSeconds,
        gpuEndSeconds: feedback.gpuEndSeconds
      )
      active.resources.release()
      ticket.gateEvaluation.releaseInputLease()
      activeAsyncSubmission = nil
      return AcceptedConsequenceCompletion(
        feedback: feedback,
        acceptedPhysicsState: acceptedPhysicsState,
        consequence: consequence
      )
    } catch {
      // Preserve the complete accepted-state dependency graph after a host
      // timeout. Feedback failure is terminal and therefore safe to reap;
      // absence of feedback means the GPU can still touch these allocations.
      if ticket.feedbackState.hasCompleted {
        active.resources.release()
        ticket.gateEvaluation.releaseInputLease()
        activeAsyncSubmission = nil
        if transaction.status == .open { try? transaction.abort() }
      }
      throw error
    }
  }

  /// Writes the ABI4 Brain ACK only after the mutation-free owner proposal and
  /// the distinct host preflight record are both terminal and GPU-visible.
  /// This internal SPI retains the unpublished cognitive prepare; it cannot
  /// publish or mutate physical state.
  func submitNumanXBrainAck(
    prepared ticket: AcceptedConsequenceSubmissionTicket,
    proposal: MetalNumanXHumanMatterProposalLease,
    preflight: MetalNumanXHumanMatterBrainPreflightLease,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> MetalNumanXHumanMatterBrainAckTicket {
    lock.lock()
    guard let active = activeAsyncSubmission,
      active.identifier == ticket.identifier,
      active.kind == .acceptedConsequence,
      active.feedbackState === ticket.feedbackState,
      !active.abortRequested,
      ticket.numanXPrepareEvaluation != nil
    else {
      lock.unlock()
      throw TissueError.transaction(
        "NumanX Brain ACK requires the exact quarantined prepare ticket"
      )
    }
    lock.unlock()
    return try numanXHumanMatterRuntime.submitBrainAck(
      preparedTicket: ticket,
      proposal: proposal,
      preflight: preflight,
      signal: completionPoint
    )
  }

  /// Validates the complete applied chain and canonical final token without
  /// flipping cognitive, fast, journal, or physical publication state.
  func validateNumanXAppliedRoot(
    ack ticket: MetalNumanXHumanMatterBrainAckTicket,
    applied lease: MetalNumanXHumanMatterAppliedLease,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> MetalNumanXHumanMatterAppliedValidationTicket {
    lock.lock()
    guard let active = activeAsyncSubmission,
      active.identifier == ticket.preparedTicket.identifier,
      active.kind == .acceptedConsequence,
      active.feedbackState === ticket.preparedTicket.feedbackState,
      !active.abortRequested,
      ticket.preparedTicket.numanXPrepareEvaluation != nil
    else {
      lock.unlock()
      throw TissueError.transaction(
        "NumanX applied validation requires the exact quarantined prepare ticket"
      )
    }
    lock.unlock()
    return try numanXHumanMatterRuntime.submitAppliedValidation(
      ackTicket: ticket,
      applied: lease,
      signal: completionPoint
    )
  }

  public func abortAcceptedConsequenceSubmission(
    _ ticket: AcceptedConsequenceSubmissionTicket,
    transaction: MetalJointAgentStateTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    guard let active = activeAsyncSubmission,
      active.identifier == ticket.identifier,
      active.kind == .acceptedConsequence,
      active.transactionFingerprint == transaction.jointToken.fingerprint
    else {
      throw TissueError.transaction(
        "async accepted-consequence ticket is stale or not owned here"
      )
    }
    active.abortRequested = true
    var completionError: Error?
    do {
      _ = try ticket.feedbackState.wait(timeoutMilliseconds: timeoutMilliseconds)
    } catch {
      guard ticket.feedbackState.hasCompleted else {
        throw error
      }
      completionError = error
    }
    active.resources.release()
    ticket.gateEvaluation.releaseInputLease()
    activeAsyncSubmission = nil
    if transaction.status == .open { try transaction.abort() }
    if let completionError { throw completionError }
  }

  /// Reaps a NumanX prepare after a later owner close has resolved the joint
  /// root. The aggregate high-level ticket has already observed terminal Metal
  /// feedback and retains every borrowed input until this exact call, so no
  /// host wait, token reconstruction, or state publication is performed here.
  func releaseResolvedNumanXPreparedSubmission(
    _ ticket: AcceptedConsequenceSubmissionTicket,
    transaction: MetalJointAgentStateTransaction
  ) {
    lock.lock()
    defer { lock.unlock() }
    guard let active = activeAsyncSubmission,
      active.identifier == ticket.identifier,
      active.kind == .acceptedConsequence,
      active.transactionFingerprint == transaction.jointToken.fingerprint,
      active.feedbackState === ticket.feedbackState,
      ticket.numanXPrepareEvaluation != nil,
      ticket.feedbackState.hasCompleted
    else {
      preconditionFailure("resolved NumanX cognitive ticket is stale")
    }
    active.resources.release()
    ticket.gateEvaluation.releaseInputLease()
    activeAsyncSubmission = nil
  }

  private func encodeAcceptedFastMotorStateImport(
    encoder: any MTL4ComputeCommandEncoder,
    lease: MetalTissueRuntime.AcceptedFastMotorStateLease,
    transaction: MetalJointAgentStateTransaction,
    gateEvaluation: MetalAcceptedPhysicsGateEvaluation
  ) throws {
    let section = agentStateRuntime.arena.layout.section(.cpgState)
    let reflexSection = agentStateRuntime.arena.layout.section(.reflexState)
    let fastCerebellarSection = agentStateRuntime.arena.layout.section(
      .fastCerebellarState
    )
    let fastAutonomicSection = agentStateRuntime.arena.layout.section(
      .fastAutonomicState
    )
    let acceptedSomaticSection = agentStateRuntime.arena.layout.section(
      .acceptedSomaticOutput
    )
    let acceptedAutonomicSection = agentStateRuntime.arena.layout.section(
      .acceptedAutonomicOutput
    )
    let acceptedActiveSensingSection = agentStateRuntime.arena.layout.section(
      .acceptedActiveSensingOutput
    )
    let expectedReflexRuleCount = species.reflexes.reduce(0) {
      $0 + $1.receptorChannelCodes.count * $1.actuatorIdentifiers.count
    }
    guard activeAsyncSubmission == nil,
      transaction.status == .open,
      lease.transactionFingerprint == transaction.jointToken.fingerprint,
      lease.acceptedTimestamp == transaction.jointToken.targetTimestamp,
      lease.oscillatorCount == species.cpg.oscillators.count,
      lease.byteCount == lease.oscillatorCount * section.elementStride,
      lease.byteCount <= section.byteCount,
      lease.reflexRuleCount == expectedReflexRuleCount,
      lease.reflexStateByteCount
        == lease.reflexRuleCount * reflexSection.elementStride,
      lease.reflexStateByteCount <= reflexSection.byteCount,
      lease.fastCerebellarStateCount == Int(species.motor.actuatorCount),
      lease.fastCerebellarStateByteCount
        == fastCerebellarSection.elementCount * fastCerebellarSection.elementStride,
      lease.fastAutonomicStateCount
        == Int(species.physiology.autonomicActionDimension),
      lease.fastAutonomicStateByteCount
        == fastAutonomicSection.elementCount * fastAutonomicSection.elementStride,
      lease.acceptedSomaticOutputCount == Int(species.motor.actuatorCount),
      lease.acceptedSomaticOutputByteCount
        == acceptedSomaticSection.elementCount * acceptedSomaticSection.elementStride,
      lease.acceptedSomaticOutputBuffer.length
        >= lease.acceptedSomaticOutputByteCount,
      lease.acceptedAutonomicOutputCount
        == Int(species.physiology.autonomicActionDimension),
      lease.acceptedAutonomicOutputByteCount
        == acceptedAutonomicSection.elementCount * acceptedAutonomicSection.elementStride,
      lease.acceptedAutonomicOutputBuffer.length
        >= lease.acceptedAutonomicOutputByteCount,
      lease.acceptedActiveSensingOutputCount
        == Int(species.motor.activeSensingActionDimension),
      lease.acceptedActiveSensingOutputByteCount
        == acceptedActiveSensingSection.elementCount
          * acceptedActiveSensingSection.elementStride,
      lease.acceptedActiveSensingOutputBuffer.length
        >= lease.acceptedActiveSensingOutputByteCount,
      lease.actuatorCommandKind == species.motor.actuatorCommandKind
    else {
      throw TissueError.transaction(
        "accepted fast motor state does not match the cognitive shadow"
      )
    }
    let destination = try agentStateRuntime.arena.borrowShadowHotBuffer(
      transaction: transaction.agentStateToken
    )
    if lease.byteCount > 0 {
      try acceptedPhysicsGateRuntime.encodeConditionalCopy(
        encoder: encoder,
        evaluation: gateEvaluation,
        source: lease.cpgBuffer,
        sourceOffset: 0,
        destination: destination,
        destinationOffset: section.byteOffset,
        byteCount: lease.byteCount
      )
    }
    if lease.reflexStateByteCount > 0 {
      try acceptedPhysicsGateRuntime.encodeConditionalCopy(
        encoder: encoder,
        evaluation: gateEvaluation,
        source: lease.reflexStateBuffer,
        sourceOffset: 0,
        destination: destination,
        destinationOffset: reflexSection.byteOffset,
        byteCount: lease.reflexStateByteCount
      )
    }
    if lease.fastCerebellarStateByteCount > 0 {
      try acceptedPhysicsGateRuntime.encodeConditionalCopy(
        encoder: encoder,
        evaluation: gateEvaluation,
        source: lease.fastCerebellarStateBuffer,
        sourceOffset: 0,
        destination: destination,
        destinationOffset: fastCerebellarSection.byteOffset,
        byteCount: lease.fastCerebellarStateByteCount
      )
    }
    if lease.fastAutonomicStateByteCount > 0 {
      try acceptedPhysicsGateRuntime.encodeConditionalCopy(
        encoder: encoder,
        evaluation: gateEvaluation,
        source: lease.fastAutonomicStateBuffer,
        sourceOffset: 0,
        destination: destination,
        destinationOffset: fastAutonomicSection.byteOffset,
        byteCount: lease.fastAutonomicStateByteCount
      )
    }
    if lease.acceptedSomaticOutputByteCount > 0 {
      try acceptedPhysicsGateRuntime.encodeConditionalCopy(
        encoder: encoder,
        evaluation: gateEvaluation,
        source: lease.acceptedSomaticOutputBuffer,
        sourceOffset: 0,
        destination: destination,
        destinationOffset: acceptedSomaticSection.byteOffset,
        byteCount: lease.acceptedSomaticOutputByteCount
      )
    }
    if lease.acceptedAutonomicOutputByteCount > 0 {
      try acceptedPhysicsGateRuntime.encodeConditionalCopy(
        encoder: encoder,
        evaluation: gateEvaluation,
        source: lease.acceptedAutonomicOutputBuffer,
        sourceOffset: 0,
        destination: destination,
        destinationOffset: acceptedAutonomicSection.byteOffset,
        byteCount: lease.acceptedAutonomicOutputByteCount
      )
    }
    if lease.acceptedActiveSensingOutputByteCount > 0 {
      try acceptedPhysicsGateRuntime.encodeConditionalCopy(
        encoder: encoder,
        evaluation: gateEvaluation,
        source: lease.acceptedActiveSensingOutputBuffer,
        sourceOffset: 0,
        destination: destination,
        destinationOffset: acceptedActiveSensingSection.byteOffset,
        byteCount: lease.acceptedActiveSensingOutputByteCount
      )
    }
  }

  /// Imports the exact accepted physical somatic output plus fast-substep
  /// oscillator, reflex, per-actuator cerebellar, and autonomic state into the
  /// same shadow generation. That generation receives accepted sensory
  /// consequences and memory journals; a later abort discards every copy with
  /// the rest of the mind.
  func importAcceptedFastMotorState(
    _ lease: MetalTissueRuntime.AcceptedFastMotorStateLease,
    transaction: MetalJointAgentStateTransaction
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    let section = agentStateRuntime.arena.layout.section(.cpgState)
    let reflexSection = agentStateRuntime.arena.layout.section(.reflexState)
    let fastCerebellarSection = agentStateRuntime.arena.layout.section(
      .fastCerebellarState
    )
    let fastAutonomicSection = agentStateRuntime.arena.layout.section(
      .fastAutonomicState
    )
    let acceptedSomaticSection = agentStateRuntime.arena.layout.section(
      .acceptedSomaticOutput
    )
    let acceptedAutonomicSection = agentStateRuntime.arena.layout.section(
      .acceptedAutonomicOutput
    )
    let acceptedActiveSensingSection = agentStateRuntime.arena.layout.section(
      .acceptedActiveSensingOutput
    )
    let expectedReflexRuleCount = species.reflexes.reduce(0) {
      $0 + $1.receptorChannelCodes.count * $1.actuatorIdentifiers.count
    }
    guard activeAsyncSubmission == nil,
      transaction.status == .open,
      lease.transactionFingerprint == transaction.jointToken.fingerprint,
      lease.acceptedTimestamp == transaction.jointToken.targetTimestamp,
      lease.oscillatorCount == species.cpg.oscillators.count,
      lease.byteCount == lease.oscillatorCount * section.elementStride,
      lease.byteCount <= section.byteCount,
      lease.reflexRuleCount == expectedReflexRuleCount,
      lease.reflexStateByteCount
        == lease.reflexRuleCount * reflexSection.elementStride,
      lease.reflexStateByteCount <= reflexSection.byteCount,
      lease.fastCerebellarStateCount == Int(species.motor.actuatorCount),
      lease.fastCerebellarStateByteCount
        == fastCerebellarSection.elementCount * fastCerebellarSection.elementStride,
      lease.fastAutonomicStateCount
        == Int(species.physiology.autonomicActionDimension),
      lease.fastAutonomicStateByteCount
        == fastAutonomicSection.elementCount * fastAutonomicSection.elementStride,
      lease.acceptedSomaticOutputCount == Int(species.motor.actuatorCount),
      lease.acceptedSomaticOutputByteCount
        == acceptedSomaticSection.elementCount * acceptedSomaticSection.elementStride,
      lease.acceptedSomaticOutputBuffer.length
        >= lease.acceptedSomaticOutputByteCount,
      lease.acceptedAutonomicOutputCount
        == Int(species.physiology.autonomicActionDimension),
      lease.acceptedAutonomicOutputByteCount
        == acceptedAutonomicSection.elementCount * acceptedAutonomicSection.elementStride,
      lease.acceptedAutonomicOutputBuffer.length
        >= lease.acceptedAutonomicOutputByteCount,
      lease.acceptedActiveSensingOutputCount
        == Int(species.motor.activeSensingActionDimension),
      lease.acceptedActiveSensingOutputByteCount
        == acceptedActiveSensingSection.elementCount
          * acceptedActiveSensingSection.elementStride,
      lease.acceptedActiveSensingOutputBuffer.length
        >= lease.acceptedActiveSensingOutputByteCount,
      (lease.bodySchemaCount == 0 && lease.bodySchemaByteCount == 0)
        || (lease.bodySchemaCount == Int(species.body.bodyCount)
          && lease.bodySchemaByteCount == lease.bodySchemaCount * 48
          && lease.bodySchemaBuffer.length >= lease.bodySchemaByteCount),
      lease.actuatorCommandKind == species.motor.actuatorCommandKind
    else {
      throw TissueError.transaction(
        "accepted fast motor state does not match the cognitive shadow"
      )
    }
    guard
      lease.byteCount > 0 || lease.reflexStateByteCount > 0
        || lease.fastCerebellarStateByteCount > 0
        || lease.fastAutonomicStateByteCount > 0
        || lease.acceptedSomaticOutputByteCount > 0
        || lease.acceptedAutonomicOutputByteCount > 0
        || lease.acceptedActiveSensingOutputByteCount > 0
        || lease.bodySchemaByteCount > 0
    else { return }
    let descriptor = MTLResidencySetDescriptor()
    descriptor.label = "NumiBrain accepted fast motor residency"
    descriptor.initialCapacity = 7
    let borrowedResidency: any MTLResidencySet
    do {
      borrowedResidency = try device.makeResidencySet(descriptor: descriptor)
    } catch {
      throw TissueError.metal("failed to retain accepted fast motor state: \(error)")
    }
    borrowedResidency.addAllocation(lease.cpgBuffer)
    borrowedResidency.addAllocation(lease.reflexStateBuffer)
    borrowedResidency.addAllocation(lease.fastCerebellarStateBuffer)
    borrowedResidency.addAllocation(lease.fastAutonomicStateBuffer)
    borrowedResidency.addAllocation(lease.acceptedSomaticOutputBuffer)
    borrowedResidency.addAllocation(lease.acceptedAutonomicOutputBuffer)
    borrowedResidency.addAllocation(lease.acceptedActiveSensingOutputBuffer)
    borrowedResidency.commit()
    borrowedResidency.requestResidency()
    defer { borrowedResidency.endResidency() }
    let destination = try agentStateRuntime.arena.borrowShadowHotBuffer(
      transaction: transaction.agentStateToken
    )
    commandAllocator.reset()
    commandBuffer.beginCommandBuffer(allocator: commandAllocator)
    commandBuffer.useResidencySet(residencySet)
    commandBuffer.useResidencySet(borrowedResidency)
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
      commandBuffer.endCommandBuffer()
      throw TissueError.metal("failed to encode accepted fast motor import")
    }
    encoder.label = "NumiBrain accepted fast motor import"
    if lease.byteCount > 0 {
      encoder.copy(
        sourceBuffer: lease.cpgBuffer,
        sourceOffset: 0,
        destinationBuffer: destination,
        destinationOffset: section.byteOffset,
        size: lease.byteCount
      )
    }
    if lease.reflexStateByteCount > 0 {
      encoder.copy(
        sourceBuffer: lease.reflexStateBuffer,
        sourceOffset: 0,
        destinationBuffer: destination,
        destinationOffset: reflexSection.byteOffset,
        size: lease.reflexStateByteCount
      )
    }
    if lease.fastCerebellarStateByteCount > 0 {
      encoder.copy(
        sourceBuffer: lease.fastCerebellarStateBuffer,
        sourceOffset: 0,
        destinationBuffer: destination,
        destinationOffset: fastCerebellarSection.byteOffset,
        size: lease.fastCerebellarStateByteCount
      )
    }
    if lease.fastAutonomicStateByteCount > 0 {
      encoder.copy(
        sourceBuffer: lease.fastAutonomicStateBuffer,
        sourceOffset: 0,
        destinationBuffer: destination,
        destinationOffset: fastAutonomicSection.byteOffset,
        size: lease.fastAutonomicStateByteCount
      )
    }
    if lease.acceptedSomaticOutputByteCount > 0 {
      encoder.copy(
        sourceBuffer: lease.acceptedSomaticOutputBuffer,
        sourceOffset: 0,
        destinationBuffer: destination,
        destinationOffset: acceptedSomaticSection.byteOffset,
        size: lease.acceptedSomaticOutputByteCount
      )
    }
    if lease.acceptedAutonomicOutputByteCount > 0 {
      encoder.copy(
        sourceBuffer: lease.acceptedAutonomicOutputBuffer,
        sourceOffset: 0,
        destinationBuffer: destination,
        destinationOffset: acceptedAutonomicSection.byteOffset,
        size: lease.acceptedAutonomicOutputByteCount
      )
    }
    if lease.acceptedActiveSensingOutputByteCount > 0 {
      encoder.copy(
        sourceBuffer: lease.acceptedActiveSensingOutputBuffer,
        sourceOffset: 0,
        destinationBuffer: destination,
        destinationOffset: acceptedActiveSensingSection.byteOffset,
        size: lease.acceptedActiveSensingOutputByteCount
      )
    }
    encoder.endEncoding()
    commandBuffer.endCommandBuffer()
    _ = try commitCommandBuffer(label: "NumiBrain accepted fast motor import")
    try transaction.bindAcceptedFastMotorState(lease)
  }

  public func borrowNumanXSomaticBuffer(
    for decision: DecisionBufferView,
    transaction: MetalJointAgentStateTransaction
  ) throws -> NumanXSomaticBufferLease {
    guard transaction.status == .open,
      decision.transactionFingerprint == transaction.jointToken.fingerprint,
      decision.shadowGeneration == transaction.agentStateToken.shadowGeneration,
      decision.somaticOutputCount > 0,
      decision.somaticOutputByteCount
        == decision.somaticOutputCount * MemoryLayout<Float>.stride
    else {
      throw TissueError.transaction(
        "cannot lend a stale or incomplete embodied somatic command"
      )
    }
    let section = agentStateRuntime.arena.layout.section(.somaticOutput)
    let controlLayout = try MetalActiveControlLayout(
      arenaLayout: agentStateRuntime.arena.layout,
      species: species
    )
    let autonomic = controlLayout.section(.autonomicCommands)
    let motorGoal = controlLayout.section(.motorGoal)
    let motorCommands = controlLayout.section(.motorCommands)
    let activeSensing = controlLayout.section(.activeSensingCommands)
    let internalActions = controlLayout.section(.internalActions)
    let maturation = agentStateRuntime.arena.layout.section(.regionalMaturation)
    let plasticModulation = agentStateRuntime.arena.layout.section(
      .regionalPlasticModulation
    )
    let fastPlasticity = agentStateRuntime.arena.layout.section(.fastPlasticity)
    let cpgState = agentStateRuntime.arena.layout.section(.cpgState)
    let descendingBaseline = agentStateRuntime.arena.layout.section(
      .descendingSomaticBaseline
    )
    let reflexState = agentStateRuntime.arena.layout.section(.reflexState)
    let fastCerebellarState = agentStateRuntime.arena.layout.section(
      .fastCerebellarState
    )
    let fastAutonomicState = agentStateRuntime.arena.layout.section(
      .fastAutonomicState
    )
    let eventQueue = agentStateRuntime.arena.layout.section(.eventQueue)
    let reflexStateCount = species.reflexes.reduce(0) {
      $0 + $1.receptorChannelCodes.count * $1.actuatorIdentifiers.count
    }
    let buffer = try agentStateRuntime.arena.borrowShadowHotBuffer(
      transaction: transaction.agentStateToken
    )
    guard section.elementCount == decision.somaticOutputCount,
      section.byteOffset <= buffer.length,
      decision.somaticOutputByteCount <= buffer.length - section.byteOffset,
      decision.somaticOutputGPUAddress
        == buffer.gpuAddress + UInt64(section.byteOffset),
      decision.descendingSomaticBaselineByteCount
        == decision.somaticOutputByteCount,
      descendingBaseline.byteOffset <= buffer.length,
      decision.descendingSomaticBaselineByteCount
        <= buffer.length - descendingBaseline.byteOffset,
      decision.descendingSomaticBaselineGPUAddress
        == buffer.gpuAddress + UInt64(descendingBaseline.byteOffset),
      decision.autonomicCommandCount == autonomic.elementCount,
      autonomic.byteOffset <= buffer.length,
      autonomic.byteCount <= buffer.length - autonomic.byteOffset,
      decision.autonomicCommandGPUAddress
        == buffer.gpuAddress + UInt64(autonomic.byteOffset),
      decision.activeSensingCommandCount
        == Int(species.motor.activeSensingActionDimension),
      activeSensing.byteOffset <= buffer.length,
      activeSensing.byteCount <= buffer.length - activeSensing.byteOffset,
      decision.activeSensingCommandGPUAddress
        == buffer.gpuAddress + UInt64(activeSensing.byteOffset),
      decision.internalActionCount == internalActions.elementCount,
      internalActions.byteOffset <= buffer.length,
      internalActions.byteCount <= buffer.length - internalActions.byteOffset,
      decision.internalActionGPUAddress
        == buffer.gpuAddress + UInt64(internalActions.byteOffset),
      decision.regionalMaturationCount == maturation.elementCount,
      decision.regionalMaturationByteCount
        == maturation.elementCount * maturation.elementStride,
      maturation.byteOffset <= buffer.length,
      decision.regionalMaturationByteCount
        <= buffer.length - maturation.byteOffset,
      decision.regionalMaturationGPUAddress
        == buffer.gpuAddress + UInt64(maturation.byteOffset),
      decision.regionalPlasticModulationCount == plasticModulation.elementCount,
      decision.regionalPlasticModulationByteCount
        == plasticModulation.elementCount * plasticModulation.elementStride,
      plasticModulation.byteOffset <= buffer.length,
      decision.regionalPlasticModulationByteCount
        <= buffer.length - plasticModulation.byteOffset,
      decision.regionalPlasticModulationGPUAddress
        == buffer.gpuAddress + UInt64(plasticModulation.byteOffset),
      decision.fastPlasticityCount == fastPlasticity.elementCount,
      decision.fastPlasticityByteCount
        == fastPlasticity.elementCount * fastPlasticity.elementStride,
      fastPlasticity.byteOffset <= buffer.length,
      decision.fastPlasticityByteCount
        <= buffer.length - fastPlasticity.byteOffset,
      decision.fastPlasticityGPUAddress
        == buffer.gpuAddress + UInt64(fastPlasticity.byteOffset),
      decision.cpgStateCount == species.cpg.oscillators.count,
      decision.cpgStateByteCount
        == decision.cpgStateCount * cpgState.elementStride,
      decision.cpgSynergyCount == Int(species.motor.synergyCount),
      cpgState.byteOffset <= buffer.length,
      decision.cpgStateByteCount <= buffer.length - cpgState.byteOffset,
      decision.cpgStateGPUAddress
        == buffer.gpuAddress + UInt64(cpgState.byteOffset),
      decision.reflexStateCount == reflexStateCount,
      decision.reflexStateByteCount
        == decision.reflexStateCount * reflexState.elementStride,
      reflexState.byteOffset <= buffer.length,
      decision.reflexStateByteCount <= buffer.length - reflexState.byteOffset,
      decision.reflexStateGPUAddress
        == buffer.gpuAddress + UInt64(reflexState.byteOffset),
      decision.motorCommandCount == motorCommands.elementCount,
      decision.motorGoalByteCount == motorGoal.byteCount,
      motorGoal.byteOffset <= buffer.length,
      motorGoal.byteCount <= buffer.length - motorGoal.byteOffset,
      decision.motorGoalGPUAddress
        == buffer.gpuAddress + UInt64(motorGoal.byteOffset),
      motorCommands.byteOffset <= buffer.length,
      motorCommands.byteCount <= buffer.length - motorCommands.byteOffset,
      decision.motorCommandGPUAddress
        == buffer.gpuAddress + UInt64(motorCommands.byteOffset),
      decision.fastCerebellarStateCount == fastCerebellarState.elementCount,
      decision.fastCerebellarStateByteCount
        == fastCerebellarState.elementCount * fastCerebellarState.elementStride,
      fastCerebellarState.byteOffset <= buffer.length,
      fastCerebellarState.byteCount
        <= buffer.length - fastCerebellarState.byteOffset,
      decision.fastCerebellarStateGPUAddress
        == buffer.gpuAddress + UInt64(fastCerebellarState.byteOffset),
      decision.fastAutonomicStateCount == fastAutonomicState.elementCount,
      decision.fastAutonomicStateByteCount
        == fastAutonomicState.elementCount * fastAutonomicState.elementStride,
      fastAutonomicState.byteOffset <= buffer.length,
      fastAutonomicState.byteCount
        <= buffer.length - fastAutonomicState.byteOffset,
      decision.fastAutonomicStateGPUAddress
        == buffer.gpuAddress + UInt64(fastAutonomicState.byteOffset),
      decision.receptorEventCapacity == eventQueue.elementCount - 1,
      decision.receptorEventMaximumCount <= decision.receptorEventCapacity,
      eventQueue.byteOffset <= buffer.length,
      eventQueue.byteCount <= buffer.length - eventQueue.byteOffset,
      decision.receptorEventQueueGPUAddress
        == buffer.gpuAddress + UInt64(eventQueue.byteOffset)
    else {
      throw TissueError.transaction(
        "embodied somatic command does not identify its resident shadow buffer"
      )
    }
    return NumanXSomaticBufferLease(
      decision: decision,
      speciesTemplateFingerprint: speciesTemplateFingerprint,
      buffer: buffer,
      sourceOffset: section.byteOffset,
      descendingBaselineSourceOffset: descendingBaseline.byteOffset,
      autonomicSourceOffset: autonomic.byteOffset,
      activeSensingSourceOffset: activeSensing.byteOffset,
      internalActionSourceOffset: internalActions.byteOffset,
      maturationSourceOffset: maturation.byteOffset,
      plasticModulationSourceOffset: plasticModulation.byteOffset,
      fastPlasticitySourceOffset: fastPlasticity.byteOffset,
      cpgStateSourceOffset: cpgState.byteOffset,
      reflexStateSourceOffset: reflexState.byteOffset,
      motorCommandSourceOffset: motorCommands.byteOffset,
      fastCerebellarStateSourceOffset: fastCerebellarState.byteOffset,
      fastAutonomicStateSourceOffset: fastAutonomicState.byteOffset,
      receptorEventQueueSourceOffset: eventQueue.byteOffset
    )
  }

  private func makeDecisionBufferView(
    transaction: MetalJointAgentStateTransaction,
    sensory: MetalSensoryTransductionRuntime.Result,
    decision: MetalDecisionRuntime.OutputView,
    feedback: MetalGPUCompletionFeedback?
  ) throws -> DecisionBufferView {
    let hot = try agentStateRuntime.hotStateView(
      transaction: transaction.agentStateToken
    )
    let control = agentStateRuntime.arena.layout.section(.activeControl)
    let workspace = agentStateRuntime.arena.layout.section(.workspaceContent)
    let maturation = agentStateRuntime.arena.layout.section(.regionalMaturation)
    let plasticModulation = agentStateRuntime.arena.layout.section(
      .regionalPlasticModulation
    )
    let fastPlasticity = agentStateRuntime.arena.layout.section(.fastPlasticity)
    let cpgState = agentStateRuntime.arena.layout.section(.cpgState)
    let descendingBaseline = agentStateRuntime.arena.layout.section(
      .descendingSomaticBaseline
    )
    let reflexState = agentStateRuntime.arena.layout.section(.reflexState)
    let fastCerebellarState = agentStateRuntime.arena.layout.section(
      .fastCerebellarState
    )
    let fastAutonomicState = agentStateRuntime.arena.layout.section(
      .fastAutonomicState
    )
    let reflexStateCount = species.reflexes.reduce(0) {
      $0 + $1.receptorChannelCodes.count * $1.actuatorIdentifiers.count
    }
    return DecisionBufferView(
      transactionFingerprint: transaction.jointToken.fingerprint,
      shadowGeneration: transaction.agentStateToken.shadowGeneration,
      decisionTimestamp: transaction.jointToken.committedTimestamp,
      activeControlGPUAddress: hot.outputGPUAddress + UInt64(control.byteOffset),
      activeControlByteCount: control.byteCount,
      motorGoalGPUAddress: decision.motorGoalGPUAddress,
      motorGoalByteCount: decision.motorGoalByteCount,
      motorCommandGPUAddress: decision.motorCommandGPUAddress,
      motorCommandCount: decision.motorCommandCount,
      spinalStateGPUAddress: decision.spinalStateGPUAddress,
      somaticOutputGPUAddress: decision.somaticOutputGPUAddress,
      somaticOutputByteCount:
        decision.somaticOutputCount * MemoryLayout<Float>.stride,
      somaticOutputCount: decision.somaticOutputCount,
      descendingSomaticBaselineGPUAddress:
        hot.outputGPUAddress + UInt64(descendingBaseline.byteOffset),
      descendingSomaticBaselineByteCount:
        descendingBaseline.elementCount * descendingBaseline.elementStride,
      autonomicCommandGPUAddress: decision.autonomicCommandGPUAddress,
      autonomicCommandCount: decision.autonomicCommandCount,
      activeSensingCommandGPUAddress: decision.activeSensingCommandGPUAddress,
      activeSensingCommandCount: decision.activeSensingCommandCount,
      internalActionGPUAddress: decision.internalActionGPUAddress,
      internalActionCount: decision.internalActionCount,
      workspaceContentGPUAddress: hot.outputGPUAddress + UInt64(workspace.byteOffset),
      workspaceContentByteCount: workspace.byteCount,
      sensoryObservationGPUAddress: sensory.observationGPUAddress,
      sensoryObservationScalarCount: sensory.observationScalarCount,
      receptorEventQueueGPUAddress: sensory.eventQueueGPUAddress,
      receptorEventCapacity: sensory.eventCapacity,
      receptorEventMaximumCount: sensory.maximumEventCount,
      regionalMaturationGPUAddress:
        hot.outputGPUAddress + UInt64(maturation.byteOffset),
      regionalMaturationByteCount:
        maturation.elementCount * maturation.elementStride,
      regionalMaturationCount: maturation.elementCount,
      regionalPlasticModulationGPUAddress:
        hot.outputGPUAddress + UInt64(plasticModulation.byteOffset),
      regionalPlasticModulationByteCount:
        plasticModulation.elementCount * plasticModulation.elementStride,
      regionalPlasticModulationCount: plasticModulation.elementCount,
      fastPlasticityGPUAddress:
        hot.outputGPUAddress + UInt64(fastPlasticity.byteOffset),
      fastPlasticityByteCount:
        fastPlasticity.elementCount * fastPlasticity.elementStride,
      fastPlasticityCount: fastPlasticity.elementCount,
      cpgStateGPUAddress: hot.outputGPUAddress + UInt64(cpgState.byteOffset),
      cpgStateByteCount: species.cpg.oscillators.count * cpgState.elementStride,
      cpgStateCount: species.cpg.oscillators.count,
      cpgSynergyCount: Int(species.motor.synergyCount),
      reflexStateGPUAddress:
        hot.outputGPUAddress + UInt64(reflexState.byteOffset),
      reflexStateByteCount: reflexStateCount * reflexState.elementStride,
      reflexStateCount: reflexStateCount,
      fastCerebellarStateGPUAddress:
        hot.outputGPUAddress + UInt64(fastCerebellarState.byteOffset),
      fastCerebellarStateByteCount:
        fastCerebellarState.elementCount * fastCerebellarState.elementStride,
      fastCerebellarStateCount: fastCerebellarState.elementCount,
      fastAutonomicStateGPUAddress:
        hot.outputGPUAddress + UInt64(fastAutonomicState.byteOffset),
      fastAutonomicStateByteCount:
        fastAutonomicState.elementCount * fastAutonomicState.elementStride,
      fastAutonomicStateCount: fastAutonomicState.elementCount,
      gpuStartSeconds: feedback?.gpuStartSeconds ?? 0,
      gpuEndSeconds: feedback?.gpuEndSeconds ?? 0
    )
  }

  private struct Feedback {
    let gpuStartTime: Double
    let gpuEndTime: Double
  }

  private func commitCommandBuffer(label: String) throws -> Feedback {
    let semaphore = DispatchSemaphore(value: 0)
    final class FeedbackBox: @unchecked Sendable {
      var feedback: (any MTL4CommitFeedback)?
    }
    let feedbackBox = FeedbackBox()
    let options = MTL4CommitOptions()
    options.addFeedbackHandler { feedback in
      feedbackBox.feedback = feedback
      semaphore.signal()
    }
    commandQueue.commit([commandBuffer], options: options)
    semaphore.wait()
    guard let feedback = feedbackBox.feedback else {
      throw TissueError.metal("\(label) completed without feedback")
    }
    if let error = feedback.error {
      throw TissueError.metal("\(label) failed: \(error)")
    }
    return Feedback(
      gpuStartTime: feedback.gpuStartTime,
      gpuEndTime: feedback.gpuEndTime
    )
  }

  private func makeDynamicSensorResidency(
    _ sensors: [MetalRawSensorBufferLease]
  ) throws -> (any MTLResidencySet)? {
    guard !sensors.isEmpty else { return nil }
    let descriptor = MTLResidencySetDescriptor()
    descriptor.label = "NumiBrain borrowed NumanX sensor residency"
    descriptor.initialCapacity = sensors.reduce(0) {
      $0 + 1 + ($1.validityBuffer == nil ? 0 : 1)
    }
    let set: any MTLResidencySet
    do {
      set = try device.makeResidencySet(descriptor: descriptor)
    } catch {
      throw TissueError.metal("failed to borrow sensor residency: \(error)")
    }
    for sensor in sensors {
      set.addAllocation(sensor.buffer)
      if let validityBuffer = sensor.validityBuffer {
        set.addAllocation(validityBuffer)
      }
    }
    set.commit()
    set.requestResidency()
    return set
  }

  private func makeDynamicAcceptedResidency(
    sensors: [MetalRawSensorBufferLease],
    developmentalEvidence: MetalDevelopmentalEvidenceBufferLease?,
    teacherState: MetalTeacherStateBufferLease?,
    acceptedFastMotorState: MetalTissueRuntime.AcceptedFastMotorStateLease?,
    gateEvaluation: MetalAcceptedPhysicsGateEvaluation? = nil,
    numanXPrepareEvaluation: MetalNumanXBrainCommitPrepareEvaluation? = nil
  ) throws -> (any MTLResidencySet)? {
    guard
      !sensors.isEmpty || developmentalEvidence != nil || teacherState != nil
        || acceptedFastMotorState != nil || gateEvaluation != nil
        || numanXPrepareEvaluation != nil
    else { return nil }
    let descriptor = MTLResidencySetDescriptor()
    descriptor.label = "NumiBrain accepted receptor and capability residency"
    descriptor.initialCapacity =
      sensors.reduce(0) {
        $0 + 1 + ($1.validityBuffer == nil ? 0 : 1)
      }
      + (developmentalEvidence == nil ? 0 : 1)
      + (teacherState == nil ? 0 : 1)
      + (acceptedFastMotorState == nil ? 0 : 8)
      + ((acceptedFastMotorState?.bodySchemaByteCount ?? 0) > 0 ? 1 : 0)
      + (gateEvaluation?.residencyAllocations.count ?? 0)
      + (numanXPrepareEvaluation?.residencyAllocations.count ?? 0)
    let set: any MTLResidencySet
    do {
      set = try device.makeResidencySet(descriptor: descriptor)
    } catch {
      throw TissueError.metal("failed to retain accepted input buffers: \(error)")
    }
    for sensor in sensors {
      set.addAllocation(sensor.buffer)
      if let validityBuffer = sensor.validityBuffer {
        set.addAllocation(validityBuffer)
      }
    }
    if let developmentalEvidence { set.addAllocation(developmentalEvidence.buffer) }
    if let teacherState { set.addAllocation(teacherState.buffer) }
    for allocation in gateEvaluation?.residencyAllocations ?? [] {
      set.addAllocation(allocation)
    }
    for allocation in numanXPrepareEvaluation?.residencyAllocations ?? [] {
      set.addAllocation(allocation)
    }
    if let acceptedFastMotorState {
      set.addAllocation(acceptedFastMotorState.cpgBuffer)
      set.addAllocation(acceptedFastMotorState.reflexStateBuffer)
      set.addAllocation(acceptedFastMotorState.protectiveCommandBuffer)
      set.addAllocation(acceptedFastMotorState.fastCerebellarStateBuffer)
      set.addAllocation(acceptedFastMotorState.fastAutonomicStateBuffer)
      set.addAllocation(acceptedFastMotorState.acceptedSomaticOutputBuffer)
      set.addAllocation(acceptedFastMotorState.acceptedAutonomicOutputBuffer)
      set.addAllocation(acceptedFastMotorState.acceptedActiveSensingOutputBuffer)
    }
    if let acceptedFastMotorState,
      acceptedFastMotorState.bodySchemaByteCount > 0
    {
      set.addAllocation(acceptedFastMotorState.bodySchemaBuffer)
    }
    set.commit()
    set.requestResidency()
    return set
  }
}

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
  public let parameterVersionFingerprint: UInt64
  public let regionalProgramFingerprint: UInt64
  public let scheduleFingerprint: UInt64
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
  private let commandQueue: any MTL4CommandQueue
  private let commandAllocator: any MTL4CommandAllocator
  private let commandBuffer: any MTL4CommandBuffer
  private let residencySet: any MTLResidencySet
  private let lock = NSLock()

  var boundSpeciesTemplate: SpeciesTemplate { species }

  public init(
    device: any MTLDevice,
    species: SpeciesTemplate,
    regionalProgram: RegionalTokenProgram,
    parameterVersion: BrainParameterVersion,
    sharedParameterArtifact: BrainSharedParameterArtifact? = nil,
    sensoryProfile: SensoryTransductionProfile,
    decisionDynamics requestedDecisionDynamics: DecisionDynamics? = nil,
    acceptedConsequenceDynamics requestedAcceptedConsequenceDynamics:
      AcceptedConsequenceDynamics? = nil,
    memoryRetrievalDynamics requestedMemoryRetrievalDynamics:
      MemoryRetrievalDynamics? = nil,
    episodicSegmentation requestedEpisodicSegmentation:
      EpisodicSegmentationDynamics? = nil,
    initialGeneration: UInt64 = 0
  ) throws {
    guard parameterVersion.regionalProgramFingerprint == regionalProgram.fingerprint,
      parameterVersion.scheduleFingerprint == regionalProgram.scheduleFingerprint,
      sensoryProfile.speciesTemplateFingerprint == species.fingerprint,
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
      sharedParameters: sharedParameterBank
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
      + decisionRuntime.residencyAllocations.count + 1
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
    residencySet.addAllocation(acceptedConsequenceRuntime.residencyAllocation)
    for allocation in memoryRuntime.residencyAllocations {
      residencySet.addAllocation(allocation)
    }
    residencySet.commit()
    residencySet.requestResidency()
    self.deviceName = device.name
    self.deviceRegistryID = device.registryID
    self.speciesTemplateFingerprint = species.fingerprint
    self.parameterVersionFingerprint = parameterVersion.fingerprint
    self.regionalProgramFingerprint = regionalProgram.fingerprint
    self.scheduleFingerprint = regionalProgram.scheduleFingerprint
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
    return try MetalLearningBatch(
      transitions: transitions,
      livedEpisodes: livedEpisodes,
      warmEpisodes: warmEpisodes,
      proceduralSkills: proceduralSkills,
      replayQueue: replayQueue,
      counterfactualRollouts: counterfactualRollouts,
      semanticConcepts: semanticConcepts,
      semanticRelations: semanticRelations,
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
    rawSensors: [MetalRawSensorBufferLease],
    regionalRecurrentInput: MetalRegionalRecurrentBufferView? = nil
  ) throws -> DecisionBufferView {
    lock.lock()
    defer { lock.unlock() }
    guard transaction.status == .open,
      transaction.jointToken.parameterVersionFingerprint == parameterVersionFingerprint
    else {
      throw TissueError.transaction("embodied control transaction is not open")
    }
    let duration = transaction.jointToken.targetTimestamp.rawValue
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
        timestamp: transaction.jointToken.committedTimestamp
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
        fastCerebellarStateByteCount: fastCerebellarState.byteCount,
        fastCerebellarStateCount: fastCerebellarState.elementCount,
        fastAutonomicStateGPUAddress:
          hot.outputGPUAddress + UInt64(fastAutonomicState.byteOffset),
        fastAutonomicStateByteCount: fastAutonomicState.byteCount,
        fastAutonomicStateCount: fastAutonomicState.elementCount,
        gpuStartSeconds: feedback.gpuStartTime,
        gpuEndSeconds: feedback.gpuEndTime
      )
    } catch {
      try? transaction.abort()
      throw error
    }
  }

  public func commit(
    transaction: MetalJointAgentStateTransaction,
    receipt: BrainJointCommitToken
  ) throws {
    try transaction.commit(with: receipt)
  }

  func prepareCommit(
    transaction: MetalJointAgentStateTransaction,
    receipt: BrainJointCommitToken
  ) throws {
    try transaction.prepareCommit(with: receipt)
  }

  func publishPreparedCommit(
    transaction: MetalJointAgentStateTransaction
  ) {
    transaction.publishPreparedCommit()
  }

  public func abort(transaction: MetalJointAgentStateTransaction) throws {
    try transaction.abort()
  }

  /// Assimilates only receptor signals generated from the accepted physical
  /// root, then seals hot state and memory for an atomic joint commit.
  public func finalizeAcceptedControl(
    transaction: MetalJointAgentStateTransaction,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    rawSensors: [MetalRawSensorBufferLease],
    developmentalEvidence: MetalDevelopmentalEvidenceBufferLease? = nil,
    teacherState: MetalTeacherStateBufferLease? = nil
  ) throws -> AcceptedConsequenceView {
    lock.lock()
    defer { lock.unlock() }
    guard transaction.status == .open,
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
    let duration = transaction.jointToken.targetTimestamp.rawValue
      - transaction.jointToken.committedTimestamp.rawValue
    guard duration > 0, duration <= UInt64(UInt32.max) else {
      throw TissueError.transaction("accepted control interval exceeds sensory ABI")
    }
    let dynamicResidency = try makeDynamicAcceptedResidency(
      sensors: rawSensors,
      developmentalEvidence: developmentalEvidence,
      teacherState: teacherState
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
      try acceptedConsequenceRuntime.encode(
        encoder: encoder,
        transaction: transaction.agentStateToken,
        acceptedPhysicsState: acceptedPhysicsState,
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

  /// Imports accepted fast-substep oscillator, reflex, per-actuator
  /// cerebellar, and autonomic state into the same shadow generation that
  /// will receive accepted sensory consequences and memory journals. A later
  /// abort discards this copy with the rest of the mind.
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
    let expectedReflexRuleCount = species.reflexes.reduce(0) {
      $0 + $1.receptorChannelCodes.count * $1.actuatorIdentifiers.count
    }
    guard transaction.status == .open,
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
      lease.fastCerebellarStateByteCount == fastCerebellarSection.byteCount,
      lease.fastAutonomicStateCount
        == Int(species.physiology.autonomicActionDimension),
      lease.fastAutonomicStateByteCount == fastAutonomicSection.byteCount
    else {
      throw TissueError.transaction(
        "accepted fast motor state does not match the cognitive shadow"
      )
    }
    guard lease.byteCount > 0 || lease.reflexStateByteCount > 0
      || lease.fastCerebellarStateByteCount > 0
      || lease.fastAutonomicStateByteCount > 0
    else { return }
    let descriptor = MTLResidencySetDescriptor()
    descriptor.label = "NumiBrain accepted fast motor residency"
    descriptor.initialCapacity = 4
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
    encoder.endEncoding()
    commandBuffer.endCommandBuffer()
    _ = try commitCommandBuffer(label: "NumiBrain accepted fast motor import")
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
    let motorCommands = controlLayout.section(.motorCommands)
    let activeSensing = controlLayout.section(.activeSensingCommands)
    let internalActions = controlLayout.section(.internalActions)
    let maturation = agentStateRuntime.arena.layout.section(.regionalMaturation)
    let plasticModulation = agentStateRuntime.arena.layout.section(
      .regionalPlasticModulation
    )
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
      motorCommands.byteOffset <= buffer.length,
      motorCommands.byteCount <= buffer.length - motorCommands.byteOffset,
      decision.motorCommandGPUAddress
        == buffer.gpuAddress + UInt64(motorCommands.byteOffset),
      decision.fastCerebellarStateCount == fastCerebellarState.elementCount,
      decision.fastCerebellarStateByteCount == fastCerebellarState.byteCount,
      fastCerebellarState.byteOffset <= buffer.length,
      fastCerebellarState.byteCount
        <= buffer.length - fastCerebellarState.byteOffset,
      decision.fastCerebellarStateGPUAddress
        == buffer.gpuAddress + UInt64(fastCerebellarState.byteOffset),
      decision.fastAutonomicStateCount == fastAutonomicState.elementCount,
      decision.fastAutonomicStateByteCount == fastAutonomicState.byteCount,
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
      cpgStateSourceOffset: cpgState.byteOffset,
      reflexStateSourceOffset: reflexState.byteOffset,
      motorCommandSourceOffset: motorCommands.byteOffset,
      fastCerebellarStateSourceOffset: fastCerebellarState.byteOffset,
      fastAutonomicStateSourceOffset: fastAutonomicState.byteOffset,
      receptorEventQueueSourceOffset: eventQueue.byteOffset
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
    descriptor.initialCapacity = sensors.count
    let set: any MTLResidencySet
    do {
      set = try device.makeResidencySet(descriptor: descriptor)
    } catch {
      throw TissueError.metal("failed to borrow sensor residency: \(error)")
    }
    for sensor in sensors { set.addAllocation(sensor.buffer) }
    set.commit()
    set.requestResidency()
    return set
  }

  private func makeDynamicAcceptedResidency(
    sensors: [MetalRawSensorBufferLease],
    developmentalEvidence: MetalDevelopmentalEvidenceBufferLease?,
    teacherState: MetalTeacherStateBufferLease?
  ) throws -> (any MTLResidencySet)? {
    guard !sensors.isEmpty || developmentalEvidence != nil || teacherState != nil
    else { return nil }
    let descriptor = MTLResidencySetDescriptor()
    descriptor.label = "NumiBrain accepted receptor and capability residency"
    descriptor.initialCapacity = sensors.count
      + (developmentalEvidence == nil ? 0 : 1)
      + (teacherState == nil ? 0 : 1)
    let set: any MTLResidencySet
    do {
      set = try device.makeResidencySet(descriptor: descriptor)
    } catch {
      throw TissueError.metal("failed to retain accepted input buffers: \(error)")
    }
    for sensor in sensors { set.addAllocation(sensor.buffer) }
    if let developmentalEvidence { set.addAllocation(developmentalEvidence.buffer) }
    if let teacherState { set.addAllocation(teacherState.buffer) }
    set.commit()
    set.requestResidency()
    return set
  }
}

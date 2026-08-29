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
    public let autonomicCommandGPUAddress: UInt64
    public let autonomicCommandCount: Int
    public let workspaceContentGPUAddress: UInt64
    public let workspaceContentByteCount: Int
    public let sensoryObservationGPUAddress: UInt64
    public let sensoryObservationScalarCount: Int
    public let receptorEventQueueGPUAddress: UInt64
    public let receptorEventCapacity: Int
    public let regionalMaturationGPUAddress: UInt64
    public let regionalMaturationByteCount: Int
    public let regionalMaturationCount: Int
    public let regionalPlasticModulationGPUAddress: UInt64
    public let regionalPlasticModulationByteCount: Int
    public let regionalPlasticModulationCount: Int
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
    let maturationSourceOffset: Int
    let plasticModulationSourceOffset: Int

    fileprivate init(
      decision: DecisionBufferView,
      speciesTemplateFingerprint: UInt64,
      buffer: any MTLBuffer,
      sourceOffset: Int,
      maturationSourceOffset: Int,
      plasticModulationSourceOffset: Int
    ) {
      self.decision = decision
      self.speciesTemplateFingerprint = speciesTemplateFingerprint
      self.buffer = buffer
      self.sourceOffset = sourceOffset
      self.maturationSourceOffset = maturationSourceOffset
      self.plasticModulationSourceOffset = plasticModulationSourceOffset
    }

    public var metalBufferObject: UnsafeMutableRawPointer {
      Unmanaged.passUnretained(buffer as AnyObject).toOpaque()
    }
  }

  public let deviceName: String
  public let speciesTemplateFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  public let regionalProgramFingerprint: UInt64
  public let scheduleFingerprint: UInt64
  public let agentStateRuntime: MetalAgentStateRuntime
  public let sensoryRuntime: MetalSensoryTransductionRuntime
  public let cognitiveRuntime: MetalCognitiveStateRuntime
  public let decisionRuntime: MetalDecisionRuntime
  public let developmentalRuntime: MetalDevelopmentalRuntime
  public let acceptedConsequenceRuntime: MetalAcceptedConsequenceRuntime
  public let memoryRuntime: MetalMemoryRuntime

  private let device: any MTLDevice
  private let commandQueue: any MTL4CommandQueue
  private let commandAllocator: any MTL4CommandAllocator
  private let commandBuffer: any MTL4CommandBuffer
  private let residencySet: any MTLResidencySet
  private let lock = NSLock()

  public init(
    device: any MTLDevice,
    species: SpeciesTemplate,
    regionalProgram: RegionalTokenProgram,
    parameterVersion: BrainParameterVersion,
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
    let sensoryRuntime = try MetalSensoryTransductionRuntime(
      device: device,
      arena: agentStateRuntime.arena,
      species: species,
      profile: sensoryProfile
    )
    let cognitiveRuntime = try MetalCognitiveStateRuntime(
      device: device,
      arena: agentStateRuntime.arena,
      species: species,
      regionalProgram: regionalProgram
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
        ?? MemoryRetrievalDynamics.foundationV1
    )
    let decisionRuntime = try MetalDecisionRuntime(
      device: device,
      arena: agentStateRuntime.arena,
      species: species,
      regionalProgram: regionalProgram,
      parameterVersion: parameterVersion,
      dynamics: requestedDecisionDynamics ?? DecisionDynamics.foundationV1
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
        ?? AcceptedConsequenceDynamics.foundationV1
    )
    let residencyDescriptor = MTLResidencySetDescriptor()
    residencyDescriptor.label = "NumiBrain embodied cognitive residency"
    residencyDescriptor.initialCapacity =
      agentStateRuntime.arena.residencyAllocations.count
      + sensoryRuntime.residencyAllocations.count
      + cognitiveRuntime.residencyAllocations.count
      + memoryRuntime.residencyAllocations.count
      + developmentalRuntime.residencyAllocations.count + 2
    let residencySet: any MTLResidencySet
    do {
      residencySet = try device.makeResidencySet(descriptor: residencyDescriptor)
    } catch {
      throw TissueError.metal("failed to create embodied brain residency: \(error)")
    }
    for allocation in agentStateRuntime.arena.residencyAllocations {
      residencySet.addAllocation(allocation)
    }
    for allocation in sensoryRuntime.residencyAllocations {
      residencySet.addAllocation(allocation)
    }
    for allocation in cognitiveRuntime.residencyAllocations {
      residencySet.addAllocation(allocation)
    }
    residencySet.addAllocation(decisionRuntime.residencyAllocation)
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
    self.speciesTemplateFingerprint = species.fingerprint
    self.parameterVersionFingerprint = parameterVersion.fingerprint
    self.regionalProgramFingerprint = regionalProgram.fingerprint
    self.scheduleFingerprint = regionalProgram.scheduleFingerprint
    self.agentStateRuntime = agentStateRuntime
    self.sensoryRuntime = sensoryRuntime
    self.cognitiveRuntime = cognitiveRuntime
    self.decisionRuntime = decisionRuntime
    self.developmentalRuntime = developmentalRuntime
    self.acceptedConsequenceRuntime = acceptedConsequenceRuntime
    self.memoryRuntime = memoryRuntime
    self.device = device
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
    try agentStateRuntime.restoreCommittedState(
      from: .init(
        generation: checkpoint.committedGeneration,
        hotState: checkpoint.hotState,
        persistentMemory: checkpoint.persistentMemory
      )
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
        autonomicCommandGPUAddress: decision.autonomicCommandGPUAddress,
        autonomicCommandCount: decision.autonomicCommandCount,
        workspaceContentGPUAddress: hot.outputGPUAddress + UInt64(workspace.byteOffset),
        workspaceContentByteCount: workspace.byteCount,
        sensoryObservationGPUAddress: sensory.observationGPUAddress,
        sensoryObservationScalarCount: sensory.observationScalarCount,
        receptorEventQueueGPUAddress: sensory.eventQueueGPUAddress,
        receptorEventCapacity: sensory.eventCapacity,
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

  public func abort(transaction: MetalJointAgentStateTransaction) throws {
    try transaction.abort()
  }

  /// Assimilates only receptor signals generated from the accepted physical
  /// root, then seals hot state and memory for an atomic joint commit.
  public func finalizeAcceptedControl(
    transaction: MetalJointAgentStateTransaction,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    rawSensors: [MetalRawSensorBufferLease],
    developmentalEvidence: MetalDevelopmentalEvidenceBufferLease? = nil
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
      developmentalEvidence: developmentalEvidence
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
    let maturation = agentStateRuntime.arena.layout.section(.regionalMaturation)
    let plasticModulation = agentStateRuntime.arena.layout.section(
      .regionalPlasticModulation
    )
    let buffer = try agentStateRuntime.arena.borrowShadowHotBuffer(
      transaction: transaction.agentStateToken
    )
    guard section.elementCount == decision.somaticOutputCount,
      section.byteOffset <= buffer.length,
      decision.somaticOutputByteCount <= buffer.length - section.byteOffset,
      decision.somaticOutputGPUAddress
        == buffer.gpuAddress + UInt64(section.byteOffset),
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
        == buffer.gpuAddress + UInt64(plasticModulation.byteOffset)
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
      maturationSourceOffset: maturation.byteOffset,
      plasticModulationSourceOffset: plasticModulation.byteOffset
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
    developmentalEvidence: MetalDevelopmentalEvidenceBufferLease?
  ) throws -> (any MTLResidencySet)? {
    guard !sensors.isEmpty || developmentalEvidence != nil else { return nil }
    let descriptor = MTLResidencySetDescriptor()
    descriptor.label = "NumiBrain accepted receptor and capability residency"
    descriptor.initialCapacity = sensors.count + (developmentalEvidence == nil ? 0 : 1)
    let set: any MTLResidencySet
    do {
      set = try device.makeResidencySet(descriptor: descriptor)
    } catch {
      throw TissueError.metal("failed to retain accepted input buffers: \(error)")
    }
    for sensor in sensors { set.addAllocation(sensor.buffer) }
    if let developmentalEvidence { set.addAllocation(developmentalEvidence.buffer) }
    set.commit()
    set.requestResidency()
    return set
  }
}

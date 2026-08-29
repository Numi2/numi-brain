import Foundation
@preconcurrency import Metal
import NumiBrainCore

private struct AcceptedConsequenceUniforms {
  var targetTimestampMicroseconds: UInt64 = 0
  var deltaMicroseconds: UInt64 = 0
  var observationOffset: UInt64 = 0
  var eventQueueOffset: UInt64 = 0
  var bodyBeliefOffset: UInt64 = 0
  var muscleBeliefOffset: UInt64 = 0
  var physiologyOffset: UInt64 = 0
  var objectSlotOffset: UInt64 = 0
  var worldModelOffset: UInt64 = 0
  var neuromodulationOffset: UInt64 = 0
  var driveOffset: UInt64 = 0
  var fastPlasticityOffset: UInt64 = 0
  var workspaceContentOffset: UInt64 = 0
  var workspaceMetadataOffset: UInt64 = 0
  var controlHeaderOffset: UInt64 = 0
  var optionCandidateOffset: UInt64 = 0
  var proceduralTraceOffset: UInt64 = 0
  var motorCommandOffset: UInt64 = 0
  var cerebellarOffset: UInt64 = 0
  var cerebellarExpertMemoryOffset: UInt64 = 0
  var somaticOutputOffset: UInt64 = 0
  var activeSensingCommandOffset: UInt64 = 0
  var activeSensingEfficacyOffset: UInt64 = 0
  var acceptedSomaticOutputOffset: UInt64 = 0
  var acceptedActiveSensingOutputOffset: UInt64 = 0
  var reflexStateOffset: UInt64 = 0
  var fastAutonomicStateOffset: UInt64 = 0
  var physicsStateFingerprint: UInt64 = 0
  var regionalMaturationOffset: UInt64 = 0
  var observationCount: UInt32 = 0
  var bodyCount: UInt32 = 0
  var muscleCount: UInt32 = 0
  var physiologyCount: UInt32 = 0
  var objectSlotCount: UInt32 = 0
  var worldModelCount: UInt32 = 0
  var neuromodulatorCount: UInt32 = 0
  var driveCount: UInt32 = 0
  var maximumPlanningHorizon: UInt32 = 0
  var fastPlasticityCount: UInt32 = 0
  var workspaceCapacity: UInt32 = 0
  var workspaceDimension: UInt32 = 0
  var activeCerebellarCount: UInt32 = 0
  var actuatorCount: UInt32 = 0
  var activeSensingCount: UInt32 = 0
  var reflexStateCount: UInt32 = 0
  var fastAutonomicStateCount: UInt32 = 0
  var eventCapacity: UInt32 = 0
  var optionCandidateCapacity: UInt32 = 0
  var proceduralTraceRecordCapacity: UInt32 = 0
  var proceduralTracePhaseCapacity: UInt32 = 0
  var cerebellarExpertCapacity: UInt32 = 0
  var visionOffset: UInt32 = 0
  var visionCount: UInt32 = 0
  var auditionOffset: UInt32 = 0
  var auditionCount: UInt32 = 0
  var proprioceptionOffset: UInt32 = 0
  var proprioceptionCount: UInt32 = 0
  var touchOffset: UInt32 = 0
  var touchCount: UInt32 = 0
  var vestibularOffset: UInt32 = 0
  var vestibularCount: UInt32 = 0
  var olfactionOffset: UInt32 = 0
  var olfactionCount: UInt32 = 0
  var gustationOffset: UInt32 = 0
  var gustationCount: UInt32 = 0
  var interoceptionOffset: UInt32 = 0
  var interoceptionCount: UInt32 = 0
  var moduleCount: UInt32 = 0
  var plasticityParameterCount: UInt32 = 0
  var beliefGain: Float = 0
  var worldCorrectionGain: Float = 0
  var cerebellarLearningRate: Float = 0
  var plasticityLearningRate: Float = 0
}

private struct AcceptedActuatorDescriptor {
  var actuatorIdentifier: UInt32 = 0
  var commandKind: UInt32 = 0
  var flags: UInt32 = 0
  var reserved: UInt32 = 0
  var outputMinimum: Float = 0
  var outputMaximum: Float = 1
  var neutralCommand: Float = 0
  var emergencyCommand: Float = 0
}

private struct AcceptedBodyReceptorBindingTableHeader {
  var bindingCount: UInt32 = 0
  var bodyCount: UInt32 = 0
  var profileFingerprint: UInt64 = 0
}

private struct AcceptedBodyReceptorBindingRange {
  var bindingOffset: UInt32 = 0
  var bindingCount: UInt32 = 0
}

private struct AcceptedBodyReceptorBindingRecord {
  var bodyIdentifier: UInt32 = 0
  var signal: UInt32 = 0
  var observationScalarIndex: UInt32 = 0
  var flags: UInt32 = 0
  var scale: Float = 0
  var bias: Float = 0
  var weight: Float = 0
  var reserved: Float = 0
}

private struct ObservationRange: Sendable {
  let offset: UInt32
  let count: UInt32
}

/// Applies receptor evidence from the accepted end of a root transaction to
/// the already-computed shadow mind. It owns correction only; the predictive
/// decision remains cached and is never resampled during physical retries.
@available(macOS 26.0, *)
public final class MetalAcceptedConsequenceRuntime: @unchecked Sendable {
  private let arena: MetalAgentStateArena
  private let species: SpeciesTemplate
  private let dynamics: AcceptedConsequenceDynamics
  private let controlLayout: MetalActiveControlLayout
  private let observationRanges: [SensoryModality: ObservationRange]
  private let pipelines: [any MTLComputePipelineState]
  private let argumentTable: any MTL4ArgumentTable
  private let uniformBuffer: any MTLBuffer
  private let actuatorDescriptorBuffer: any MTLBuffer
  private let bodyReceptorBindingBuffer: any MTLBuffer
  private let neutralProtectiveCommandBuffer: any MTLBuffer
  private let plasticityParameterCount: UInt32

  public init(
    device: any MTLDevice,
    arena: MetalAgentStateArena,
    species: SpeciesTemplate,
    dynamics: AcceptedConsequenceDynamics,
    sensoryProfile: SensoryTransductionProfile,
    sharedParameters: MetalSharedParameterBank
  ) throws {
    guard MemoryLayout<AcceptedConsequenceUniforms>.stride == 408,
      MemoryLayout<AcceptedActuatorDescriptor>.stride == 32,
      MemoryLayout<AcceptedBodyReceptorBindingTableHeader>.stride == 16,
      MemoryLayout<AcceptedBodyReceptorBindingRange>.stride == 8,
      MemoryLayout<AcceptedBodyReceptorBindingRecord>.stride == 32,
      arena.layout.speciesTemplateFingerprint == species.fingerprint,
      sensoryProfile.speciesTemplateFingerprint == species.fingerprint
    else {
      throw TissueError.metal("accepted-consequence ABI or species binding drift")
    }
    var offset: UInt32 = 0
    var ranges: [SensoryModality: ObservationRange] = [:]
    for topology in species.senses.sorted(by: { $0.modality.rawValue < $1.modality.rawValue })
    where topology.enabled {
      let count64 = UInt64(topology.receptorCount)
        * UInt64(topology.observationDimension)
      guard count64 <= UInt64(UInt32.max),
        UInt64(offset) + count64 <= UInt64(UInt32.max)
      else {
        throw TissueError.metal("accepted sensory range exceeds UInt32")
      }
      let count = UInt32(count64)
      ranges[topology.modality] = ObservationRange(offset: offset, count: count)
      offset += count
    }
    guard Int(offset) == arena.layout.section(.sensoryObservations).elementCount else {
      throw TissueError.metal("accepted sensory ranges do not cover the arena")
    }
    guard sensoryProfile.bodyReceptorBindings.count <= Int(UInt32.max) else {
      throw TissueError.metal("accepted body receptor bindings exceed UInt32")
    }
    let topologyByModality = Dictionary(
      uniqueKeysWithValues: species.senses.map { ($0.modality, $0) }
    )
    let canonicalBodyBindings = sensoryProfile.bodyReceptorBindings.sorted {
      if $0.bodyIdentifier != $1.bodyIdentifier {
        return $0.bodyIdentifier < $1.bodyIdentifier
      }
      if $0.signal.rawValue != $1.signal.rawValue {
        return $0.signal.rawValue < $1.signal.rawValue
      }
      return $0.identifier < $1.identifier
    }
    let bodyReceptorBindings = try canonicalBodyBindings.map {
      binding -> AcceptedBodyReceptorBindingRecord in
      guard let range = ranges[binding.modality],
        let topology = topologyByModality[binding.modality]
      else {
        throw TissueError.metal("accepted body receptor topology is unavailable")
      }
      let scalarIndex = UInt64(range.offset)
        + UInt64(binding.receptorIndex)
          * UInt64(topology.observationDimension)
        + UInt64(binding.featureIndex)
      guard scalarIndex < UInt64(offset), scalarIndex <= UInt64(UInt32.max)
      else {
        throw TissueError.metal("accepted body receptor scalar exceeds its arena")
      }
      return AcceptedBodyReceptorBindingRecord(
        bodyIdentifier: binding.bodyIdentifier,
        signal: UInt32(binding.signal.rawValue),
        observationScalarIndex: UInt32(scalarIndex),
        flags: 1 | (UInt32(binding.component) << 16),
        scale: binding.scale,
        bias: binding.bias,
        weight: binding.weight,
        reserved: 0
      )
    }
    var bodyReceptorRanges = [AcceptedBodyReceptorBindingRange](
      repeating: AcceptedBodyReceptorBindingRange(),
      count: Int(species.body.bodyCount)
    )
    var bindingCursor = 0
    for bodyIdentifier in 0..<Int(species.body.bodyCount) {
      let begin = bindingCursor
      while bindingCursor < canonicalBodyBindings.count,
        canonicalBodyBindings[bindingCursor].bodyIdentifier
          == UInt32(bodyIdentifier)
      {
        bindingCursor += 1
      }
      bodyReceptorRanges[bodyIdentifier] = AcceptedBodyReceptorBindingRange(
        bindingOffset: UInt32(begin),
        bindingCount: UInt32(bindingCursor - begin)
      )
    }
    let actuatorDescriptors = species.motor.actuatorChannels.map { channel in
      AcceptedActuatorDescriptor(
        actuatorIdentifier: channel.identifier,
        commandKind: UInt32(species.motor.actuatorCommandKind.rawValue),
        flags: 1,
        reserved: 0,
        outputMinimum: channel.outputMinimum,
        outputMaximum: channel.outputMaximum,
        neutralCommand: channel.neutralCommand,
        emergencyCommand: channel.emergencyCommand
      )
    }
    guard actuatorDescriptors.count == Int(species.motor.actuatorCount),
      let actuatorDescriptorBuffer = device.makeBuffer(
        length: actuatorDescriptors.count
          * MemoryLayout<AcceptedActuatorDescriptor>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let bodyReceptorBindingBuffer = device.makeBuffer(
        length: MemoryLayout<AcceptedBodyReceptorBindingTableHeader>.stride
          + bodyReceptorRanges.count
            * MemoryLayout<AcceptedBodyReceptorBindingRange>.stride
          + max(
            bodyReceptorBindings.count,
            1
          ) * MemoryLayout<AcceptedBodyReceptorBindingRecord>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let neutralProtectiveCommandBuffer = device.makeBuffer(
        length: ProtectiveMotorCommand.byteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate accepted actuator descriptors")
    }
    actuatorDescriptorBuffer.label =
      "NumiBrain immutable accepted actuator descriptors"
    bodyReceptorBindingBuffer.label =
      "NumiBrain immutable anatomical body receptor bindings"
    neutralProtectiveCommandBuffer.label =
      "NumiBrain neutral accepted protective command"
    neutralProtectiveCommandBuffer.contents().initializeMemory(
      as: UInt8.self,
      repeating: 0,
      count: ProtectiveMotorCommand.byteCount
    )
    actuatorDescriptors.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      actuatorDescriptorBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    var bodyReceptorHeader = AcceptedBodyReceptorBindingTableHeader(
      bindingCount: UInt32(bodyReceptorBindings.count),
      bodyCount: species.body.bodyCount,
      profileFingerprint: sensoryProfile.fingerprint
    )
    withUnsafeBytes(of: &bodyReceptorHeader) { bytes in
      guard let source = bytes.baseAddress else { return }
      bodyReceptorBindingBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    bodyReceptorRanges.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      bodyReceptorBindingBuffer.contents().advanced(
        by: MemoryLayout<AcceptedBodyReceptorBindingTableHeader>.stride
      ).copyMemory(from: source, byteCount: bytes.count)
    }
    bodyReceptorBindings.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      bodyReceptorBindingBuffer.contents().advanced(
        by: MemoryLayout<AcceptedBodyReceptorBindingTableHeader>.stride
          + bodyReceptorRanges.count
            * MemoryLayout<AcceptedBodyReceptorBindingRange>.stride
      ).copyMemory(from: source, byteCount: bytes.count)
    }
    let sourceURL =
      Bundle.module.url(
        forResource: "AcceptedConsequence",
        withExtension: "metal",
        subdirectory: "Shaders"
      ) ?? Bundle.module.url(forResource: "AcceptedConsequence", withExtension: "metal")
    guard let sourceURL else {
      throw TissueError.metal("AcceptedConsequence.metal is missing from resources")
    }
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    let options = MTLCompileOptions()
    options.languageVersion = .version4_0
    options.mathMode = .safe
    options.mathFloatingPointFunctions = .precise
    let library: any MTLLibrary
    do {
      library = try device.makeLibrary(source: source, options: options)
    } catch {
      throw TissueError.metal("accepted-consequence Metal compilation failed: \(error)")
    }
    let names = [
      "assimilate_accepted_body_and_physiology",
      "reconcile_accepted_world_model",
      "update_active_sensing_efficacy",
      "broadcast_accepted_prediction_error",
      "adapt_cerebellar_experts_from_accepted_error",
      "update_fast_plasticity_from_accepted_error",
      "update_accepted_procedural_trace",
      "assimilate_accepted_fast_body_schema",
      "update_accepted_embodied_self_model",
    ]
    let functions = try names.map { name -> any MTLFunction in
      guard let function = library.makeFunction(name: name) else {
        throw TissueError.metal("\(name) is missing from accepted-consequence Metal")
      }
      return function
    }
    let pipelines: [any MTLComputePipelineState]
    do {
      pipelines = try functions.map { try device.makeComputePipelineState(function: $0) }
    } catch {
      throw TissueError.metal("accepted-consequence pipeline creation failed: \(error)")
    }
    let descriptor = MTL4ArgumentTableDescriptor()
    descriptor.label = "NumiBrain accepted-consequence arguments"
    descriptor.maxBufferBindCount = 10
    descriptor.initializeBindings = true
    guard let argumentTable = try? device.makeArgumentTable(descriptor: descriptor),
      let uniformBuffer = device.makeBuffer(
        length: MemoryLayout<AcceptedConsequenceUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate accepted-consequence bindings")
    }
    uniformBuffer.label = "NumiBrain accepted-consequence uniforms"
    argumentTable.setAddress(
      try sharedParameters.gpuAddress(.belief, minimumScalarCount: 15),
      index: 2
    )
    argumentTable.setAddress(
      try sharedParameters.gpuAddress(.world, minimumScalarCount: 158),
      index: 3
    )
    argumentTable.setAddress(
      try sharedParameters.gpuAddress(.cerebellar, minimumScalarCount: 8),
      index: 4
    )
    let regionCount = species.enabledModuleIdentifiers.count
    let basisCapacity =
      (Int(species.capacities.fastPlasticityCapacity) + regionCount - 1)
      / regionCount
    let minimumPlasticityScalarCount = try BrainSharedParameterArtifact
      .plasticityElementCount(
        regionCount: regionCount,
        basisCapacityPerRegion: basisCapacity
      )
    let plasticityScalarCount = sharedParameters.scalarCount(.plasticity)
    guard plasticityScalarCount >= minimumPlasticityScalarCount,
      plasticityScalarCount <= Int(UInt32.max)
    else {
      throw TissueError.metal(
        "accepted plasticity receptor matrix does not cover the species graph"
      )
    }
    argumentTable.setAddress(
      try sharedParameters.gpuAddress(
        .plasticity,
        minimumScalarCount: minimumPlasticityScalarCount
      ),
      index: 5
    )
    argumentTable.setAddress(actuatorDescriptorBuffer.gpuAddress, index: 6)
    argumentTable.setAddress(neutralProtectiveCommandBuffer.gpuAddress, index: 8)
    argumentTable.setAddress(bodyReceptorBindingBuffer.gpuAddress, index: 9)
    self.arena = arena
    self.species = species
    self.dynamics = dynamics
    self.controlLayout = try MetalActiveControlLayout(
      arenaLayout: arena.layout,
      species: species
    )
    self.observationRanges = ranges
    self.pipelines = pipelines
    self.argumentTable = argumentTable
    self.uniformBuffer = uniformBuffer
    self.actuatorDescriptorBuffer = actuatorDescriptorBuffer
    self.bodyReceptorBindingBuffer = bodyReceptorBindingBuffer
    self.neutralProtectiveCommandBuffer = neutralProtectiveCommandBuffer
    self.plasticityParameterCount = UInt32(plasticityScalarCount)
  }

  public var residencyAllocations: [any MTLAllocation] {
    [
      uniformBuffer, actuatorDescriptorBuffer, bodyReceptorBindingBuffer,
      neutralProtectiveCommandBuffer,
    ]
  }

  public func encode(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    deltaMicroseconds: UInt64,
    receptorEventCapacity: Int
  ) throws {
    try encode(
      encoder: encoder,
      transaction: transaction,
      acceptedPhysicsState: acceptedPhysicsState,
      deltaMicroseconds: deltaMicroseconds,
      receptorEventCapacity: receptorEventCapacity,
      acceptedFastMotorState: nil
    )
  }

  func encode(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    deltaMicroseconds: UInt64,
    receptorEventCapacity: Int,
    acceptedFastMotorState: MetalTissueRuntime.AcceptedFastMotorStateLease? = nil
  ) throws {
    guard acceptedPhysicsState.acceptedTimestamp.rawValue >= deltaMicroseconds,
      receptorEventCapacity >= 0,
      receptorEventCapacity <= Int(UInt32.max),
      acceptedFastMotorState == nil
        || (
          acceptedFastMotorState?.transactionFingerprint
            == acceptedPhysicsState.transactionFingerprint
            && acceptedFastMotorState?.acceptedTimestamp
              == acceptedPhysicsState.acceptedTimestamp
            && acceptedFastMotorState?.protectiveCommandByteCount
              == ProtectiveMotorCommand.byteCount
            && (acceptedFastMotorState?.protectiveCommandBuffer.length ?? 0)
              >= ProtectiveMotorCommand.byteCount
            && (((acceptedFastMotorState?.bodySchemaCount ?? 0) == 0
                  && (acceptedFastMotorState?.bodySchemaByteCount ?? 0) == 0)
              || (acceptedFastMotorState?.bodySchemaCount
                    == Int(species.body.bodyCount)
                && acceptedFastMotorState?.bodySchemaByteCount
                    == Int(species.body.bodyCount) * 48))
        )
    else {
      throw TissueError.transaction("accepted consequence timing or capacity is invalid")
    }
    let hot = try arena.hotStateView(transaction: transaction)
    var uniforms = try makeUniforms(
      acceptedPhysicsState: acceptedPhysicsState,
      deltaMicroseconds: deltaMicroseconds,
      eventCapacity: UInt32(receptorEventCapacity)
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      uniformBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    argumentTable.setAddress(hot.outputGPUAddress, index: 0)
    argumentTable.setAddress(uniformBuffer.gpuAddress, index: 1)
    argumentTable.setAddress(
      acceptedFastMotorState?.protectiveCommandBuffer.gpuAddress
        ?? neutralProtectiveCommandBuffer.gpuAddress,
      index: 8
    )
    dispatch(
      encoder,
      pipeline: pipelines[0],
      count: max(
        Int(species.body.bodyCount),
        max(
          arena.layout.section(.muscleBelief).elementCount,
          Int(species.physiology.stateDimension)
        )
      )
    )
    barrier(encoder)
    if let acceptedFastMotorState,
      acceptedFastMotorState.bodySchemaByteCount > 0
    {
      argumentTable.setAddress(
        acceptedFastMotorState.bodySchemaBuffer.gpuAddress,
        index: 7
      )
      dispatch(
        encoder,
        pipeline: pipelines[7],
        count: acceptedFastMotorState.bodySchemaCount
      )
      barrier(encoder)
    }
    dispatch(
      encoder,
      pipeline: pipelines[8],
      count: Int(species.body.bodyCount)
    )
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: pipelines[1],
      count: min(arena.layout.section(.worldModel).elementCount, 128)
    )
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: pipelines[2],
      count: Int(species.motor.activeSensingActionDimension)
    )
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: pipelines[3],
      count: 1
    )
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: pipelines[4],
      count: Int(species.capacities.activeCerebellarExpertCapacity)
    )
    dispatch(
      encoder,
      pipeline: pipelines[5],
      count: Int(species.capacities.fastPlasticityCapacity)
    )
    dispatch(encoder, pipeline: pipelines[6], count: 1)
  }

  private func makeUniforms(
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    deltaMicroseconds: UInt64,
    eventCapacity: UInt32
  ) throws -> AcceptedConsequenceUniforms {
    func hot(_ section: MetalAgentHotSection) -> MetalArenaSectionLayout<MetalAgentHotSection> {
      arena.layout.section(section)
    }
    func range(_ modality: SensoryModality) -> ObservationRange {
      observationRanges[modality] ?? ObservationRange(offset: 0, count: 0)
    }
    let vision = range(.vision)
    let audition = range(.audition)
    let proprioception = range(.proprioception)
    let touch = range(.touch)
    let vestibular = range(.vestibular)
    let olfaction = range(.olfaction)
    let gustation = range(.gustation)
    let interoception = range(.interoception)
    let controlHeader = controlLayout.section(.header)
    let optionCandidates = controlLayout.section(.optionCandidates)
    let planSteps = controlLayout.section(.planSteps)
    let motor = controlLayout.section(.motorCommands)
    let cerebellar = controlLayout.section(.cerebellarExperts)
    let activeSensing = controlLayout.section(.activeSensingCommands)
    let integerCounts = [
      hot(.sensoryObservations).elementCount,
      hot(.worldModel).elementCount,
      hot(.drives).elementCount,
      optionCandidates.elementCount,
      planSteps.elementCount,
      hot(.fastPlasticity).elementCount,
    ]
    guard integerCounts.allSatisfy({ $0 > 0 && $0 <= Int(UInt32.max) }),
      planSteps.elementCount % optionCandidates.elementCount == 0
    else {
      throw TissueError.metal("accepted-consequence arena exceeds UInt32")
    }
    let maximumPlanningHorizon =
      planSteps.elementCount / optionCandidates.elementCount
    let reflexStateCount = species.reflexes.reduce(0) {
      $0 + $1.receptorChannelCodes.count * $1.actuatorIdentifiers.count
    }
    guard reflexStateCount <= Int(UInt32.max),
      reflexStateCount <= hot(.reflexState).elementCount
    else {
      throw TissueError.metal("accepted reflex state exceeds UInt32 or its arena section")
    }
    return AcceptedConsequenceUniforms(
      targetTimestampMicroseconds: acceptedPhysicsState.acceptedTimestamp.rawValue,
      deltaMicroseconds: deltaMicroseconds,
      observationOffset: UInt64(hot(.sensoryObservations).byteOffset),
      eventQueueOffset: UInt64(hot(.eventQueue).byteOffset),
      bodyBeliefOffset: UInt64(hot(.bodyBelief).byteOffset),
      muscleBeliefOffset: UInt64(hot(.muscleBelief).byteOffset),
      physiologyOffset: UInt64(hot(.physiologyBelief).byteOffset),
      objectSlotOffset: UInt64(hot(.objectSlots).byteOffset),
      worldModelOffset: UInt64(hot(.worldModel).byteOffset),
      neuromodulationOffset: UInt64(hot(.neuromodulation).byteOffset),
      driveOffset: UInt64(hot(.drives).byteOffset),
      fastPlasticityOffset: UInt64(hot(.fastPlasticity).byteOffset),
      workspaceContentOffset: UInt64(hot(.workspaceContent).byteOffset),
      workspaceMetadataOffset: UInt64(hot(.workspaceMetadata).byteOffset),
      controlHeaderOffset: UInt64(controlHeader.byteOffset),
      optionCandidateOffset: UInt64(optionCandidates.byteOffset),
      proceduralTraceOffset: UInt64(
        hot(.proceduralExecutionTrace).byteOffset
      ),
      motorCommandOffset: UInt64(motor.byteOffset),
      cerebellarOffset: UInt64(cerebellar.byteOffset),
      cerebellarExpertMemoryOffset: UInt64(
        hot(.cerebellarExpertMemory).byteOffset
      ),
      somaticOutputOffset: UInt64(hot(.somaticOutput).byteOffset),
      activeSensingCommandOffset: UInt64(activeSensing.byteOffset),
      activeSensingEfficacyOffset: UInt64(
        hot(.activeSensingEfficacy).byteOffset
      ),
      acceptedSomaticOutputOffset: UInt64(
        hot(.acceptedSomaticOutput).byteOffset
      ),
      acceptedActiveSensingOutputOffset: UInt64(
        hot(.acceptedActiveSensingOutput).byteOffset
      ),
      reflexStateOffset: UInt64(hot(.reflexState).byteOffset),
      fastAutonomicStateOffset: UInt64(hot(.fastAutonomicState).byteOffset),
      physicsStateFingerprint: acceptedPhysicsState.physicsStateFingerprint,
      regionalMaturationOffset: UInt64(hot(.regionalMaturation).byteOffset),
      observationCount: UInt32(hot(.sensoryObservations).elementCount),
      bodyCount: species.body.bodyCount,
      muscleCount: UInt32(hot(.muscleBelief).elementCount),
      physiologyCount: UInt32(species.physiology.stateDimension),
      objectSlotCount: UInt32(hot(.objectSlots).elementCount),
      worldModelCount: UInt32(hot(.worldModel).elementCount),
      neuromodulatorCount: UInt32(NeuromodulatorKind.allCases.count),
      driveCount: UInt32(hot(.drives).elementCount),
      maximumPlanningHorizon: UInt32(maximumPlanningHorizon),
      fastPlasticityCount: UInt32(hot(.fastPlasticity).elementCount),
      workspaceCapacity: UInt32(species.capacities.workspaceTokenCapacity),
      workspaceDimension: UInt32(species.capacities.workspaceTokenDimension),
      activeCerebellarCount: UInt32(
        species.capacities.activeCerebellarExpertCapacity
      ),
      actuatorCount: species.motor.actuatorCount,
      activeSensingCount: UInt32(species.motor.activeSensingActionDimension),
      reflexStateCount: UInt32(reflexStateCount),
      fastAutonomicStateCount: UInt32(
        hot(.fastAutonomicState).elementCount
      ),
      eventCapacity: eventCapacity,
      optionCandidateCapacity: UInt32(optionCandidates.elementCount),
      proceduralTraceRecordCapacity: UInt32(
        hot(.proceduralExecutionTrace).elementCount
      ),
      proceduralTracePhaseCapacity: 8,
      cerebellarExpertCapacity: UInt32(
        species.capacities.cerebellarExpertCapacity
      ),
      visionOffset: vision.offset,
      visionCount: vision.count,
      auditionOffset: audition.offset,
      auditionCount: audition.count,
      proprioceptionOffset: proprioception.offset,
      proprioceptionCount: proprioception.count,
      touchOffset: touch.offset,
      touchCount: touch.count,
      vestibularOffset: vestibular.offset,
      vestibularCount: vestibular.count,
      olfactionOffset: olfaction.offset,
      olfactionCount: olfaction.count,
      gustationOffset: gustation.offset,
      gustationCount: gustation.count,
      interoceptionOffset: interoception.offset,
      interoceptionCount: interoception.count,
      moduleCount: UInt32(species.enabledModuleIdentifiers.count),
      plasticityParameterCount: plasticityParameterCount,
      beliefGain: dynamics.beliefGain,
      worldCorrectionGain: dynamics.worldCorrectionGain,
      cerebellarLearningRate: dynamics.cerebellarLearningRate,
      plasticityLearningRate: dynamics.plasticityLearningRate
    )
  }

  private func dispatch(
    _ encoder: any MTL4ComputeCommandEncoder,
    pipeline: any MTLComputePipelineState,
    count: Int
  ) {
    encoder.setComputePipelineState(pipeline)
    encoder.setArgumentTable(argumentTable)
    let width = min(
      max(pipeline.threadExecutionWidth, 1),
      pipeline.maxTotalThreadsPerThreadgroup
    )
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: max(count, 1), height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
    )
  }

  private func barrier(_ encoder: any MTL4ComputeCommandEncoder) {
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
  }
}

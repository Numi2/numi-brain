import Foundation
@preconcurrency import Metal
import NumiBrainCore

private struct CognitiveUniforms {
  var targetTimestampMicroseconds: UInt64 = 0
  var deltaMicroseconds: UInt64 = 0
  var recurrentOffset: UInt64 = 0
  var workspaceContentOffset: UInt64 = 0
  var workspaceMetadataOffset: UInt64 = 0
  var worldModelOffset: UInt64 = 0
  var driveOffset: UInt64 = 0
  var neuromodulationOffset: UInt64 = 0
  var fastPlasticityOffset: UInt64 = 0
  var activeControlOffset: UInt64 = 0
  var internalActionOffset: UInt64 = 0
  var eventQueueOffset: UInt64 = 0
  var developmentalStateOffset: UInt64 = 0
  var regionalMaturationOffset: UInt64 = 0
  var regionalPlasticModulationOffset: UInt64 = 0
  var hotStateByteCount: UInt64 = 0
  var observationOffset: UInt64 = 0
  var objectSlotOffset: UInt64 = 0
  var otherAgentSlotOffset: UInt64 = 0
  var contextBeliefOffset: UInt64 = 0
  var relationSlotOffset: UInt64 = 0
  var spatialTransformOffset: UInt64 = 0
  var physiologyBeliefOffset: UInt64 = 0
  var bodyBeliefOffset: UInt64 = 0
  var activeSensingEfficacyOffset: UInt64 = 0
  var somaticOutputOffset: UInt64 = 0
  var acceptedAutonomicOutputOffset: UInt64 = 0
  var acceptedActiveSensingOutputOffset: UInt64 = 0
  var recurrentScalarCount: UInt32 = 0
  var workspaceCapacity: UInt32 = 0
  var workspaceDimension: UInt32 = 0
  var worldModelScalarCount: UInt32 = 0
  var driveCount: UInt32 = 0
  var neuromodulatorCount: UInt32 = 0
  var fastPlasticityCount: UInt32 = 0
  var activeControlScalarCount: UInt32 = 0
  var eventCount: UInt32 = 0
  var actuatorCount: UInt32 = 0
  var synergyCount: UInt32 = 0
  var moduleCount: UInt32 = 0
  var worldLevelCount: UInt32 = 0
  var worldHeadCount: UInt32 = 0
  var proprioceptionObservationOffset: UInt32 = 0
  var proprioceptionObservationCount: UInt32 = 0
  var observationCount: UInt32 = 0
  var visionObservationOffset: UInt32 = 0
  var visionObservationCount: UInt32 = 0
  var auditionObservationOffset: UInt32 = 0
  var auditionObservationCount: UInt32 = 0
  var objectSlotCount: UInt32 = 0
  var otherAgentSlotCount: UInt32 = 0
  var contextBeliefCount: UInt32 = 0
  var relationSlotCount: UInt32 = 0
  var vestibularObservationOffset: UInt32 = 0
  var vestibularObservationCount: UInt32 = 0
  var spatialTransformCount: UInt32 = 0
  var physiologyBeliefCount: UInt32 = 0
  var bodyBeliefCount: UInt32 = 0
  var olfactionObservationOffset: UInt32 = 0
  var olfactionObservationCount: UInt32 = 0
  var gustationObservationOffset: UInt32 = 0
  var gustationObservationCount: UInt32 = 0
  var interoceptionObservationOffset: UInt32 = 0
  var interoceptionObservationCount: UInt32 = 0
  var activeSensingCount: UInt32 = 0
  var bodySensingMask: UInt32 = 0
  var autonomicActionCount: UInt32 = 0
  var internalActionCount: UInt32 = 0
}

private struct WorldModelLevelRecord {
  var level: UInt32 = 0
  var baseScalarOffset: UInt32 = 0
  var latentDimension: UInt32 = 0
  var updatePeriodMicroseconds: UInt32 = 0
  var minimumHorizonMicroseconds: UInt64 = 0
  var maximumHorizonMicroseconds: UInt64 = 0
  var headCount: UInt32 = 0
  var flags: UInt32 = 0
  var reserved: UInt64 = 0
}

@frozen
public struct MetalRegionalRecurrentBufferView: Equatable, Sendable {
  public let gpuAddress: UInt64
  public let scalarCount: Int
  public let regionalProgramFingerprint: UInt64

  public init(
    gpuAddress: UInt64,
    scalarCount: Int,
    regionalProgramFingerprint: UInt64
  ) throws {
    guard gpuAddress > 0, scalarCount > 0, regionalProgramFingerprint > 0 else {
      throw TissueError.transaction("regional recurrent buffer view is invalid")
    }
    self.gpuAddress = gpuAddress
    self.scalarCount = scalarCount
    self.regionalProgramFingerprint = regionalProgramFingerprint
  }
}

/// Encodes the first complete GPU cognitive tick over one shadow hot-state
/// generation. Learned parameter projections will replace the foundation
/// operators without changing section ownership or transaction semantics.
@available(macOS 26.0, *)
public final class MetalCognitiveStateRuntime: @unchecked Sendable {
  public let layoutFingerprint: UInt64

  private let arena: MetalAgentStateArena
  private let species: SpeciesTemplate
  private let regionalProgram: RegionalTokenProgram
  private let ingestPipeline: any MTLComputePipelineState
  private let homeostasisPipeline: any MTLComputePipelineState
  private let worldModelPipeline: any MTLComputePipelineState
  private let entityStatePipeline: any MTLComputePipelineState
  private let relationStatePipeline: any MTLComputePipelineState
  private let spatialStatePipeline: any MTLComputePipelineState
  private let fastPlasticityPipeline: any MTLComputePipelineState
  private let regionalPlasticityPipeline: any MTLComputePipelineState
  private let routeActionPipeline: any MTLComputePipelineState
  private let clearWorkspacePipeline: any MTLComputePipelineState
  private let workspacePipeline: any MTLComputePipelineState
  private let socialContextPipeline: any MTLComputePipelineState
  private let curiosityPipeline: any MTLComputePipelineState
  private let argumentTable: any MTL4ArgumentTable
  private let worldModelArgumentTables: [any MTL4ArgumentTable]
  private let uniformBuffer: any MTLBuffer
  private let worldModelDescriptorBuffer: any MTLBuffer
  private let worldModelLevelRecords: [WorldModelLevelRecord]
  private let visionObservationOffset: UInt32
  private let visionObservationCount: UInt32
  private let auditionObservationOffset: UInt32
  private let auditionObservationCount: UInt32
  private let proprioceptionObservationOffset: UInt32
  private let proprioceptionObservationCount: UInt32
  private let vestibularObservationOffset: UInt32
  private let vestibularObservationCount: UInt32
  private let olfactionObservationOffset: UInt32
  private let olfactionObservationCount: UInt32
  private let gustationObservationOffset: UInt32
  private let gustationObservationCount: UInt32
  private let interoceptionObservationOffset: UInt32
  private let interoceptionObservationCount: UInt32
  private let beliefParameterGPUAddress: UInt64
  private let worldParameterGPUAddress: UInt64
  private let memoryParameterGPUAddress: UInt64
  private let plasticityParameterGPUAddress: UInt64
  private let internalActionOffset: UInt64
  private let internalActionCount: UInt32

  public init(
    device: any MTLDevice,
    arena: MetalAgentStateArena,
    species: SpeciesTemplate,
    regionalProgram: RegionalTokenProgram,
    sharedParameters: MetalSharedParameterBank
  ) throws {
    guard MemoryLayout<CognitiveUniforms>.stride == 384,
      MemoryLayout<WorldModelLevelRecord>.stride == 48,
      arena.layout.speciesTemplateFingerprint == species.fingerprint,
      arena.layout.regionalProgramFingerprint == regionalProgram.fingerprint,
      sharedParameters.parameterVersionFingerprint > 0
    else {
      throw TissueError.metal("cognitive-state layout or uniform ABI drift")
    }
    let sourceURL =
      Bundle.module.url(
        forResource: "CognitiveState",
        withExtension: "metal",
        subdirectory: "Shaders"
      ) ?? Bundle.module.url(forResource: "CognitiveState", withExtension: "metal")
    guard let sourceURL else {
      throw TissueError.metal("CognitiveState.metal is missing from package resources")
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
      throw TissueError.metal("cognitive-state Metal 4 compilation failed: \(error)")
    }
    let functionNames = [
      "ingest_regional_recurrent_state",
      "advance_homeostasis_and_neuromodulation",
      "advance_hierarchical_world_model",
      "advance_entity_and_social_slots",
      "advance_entity_relation_graph",
      "advance_spatial_coordinate_transforms",
      "advance_fast_plasticity_foundation",
      "reduce_fast_plasticity_by_region",
      "apply_internal_route_allocation",
      "clear_requested_workspace_token",
      "broadcast_foundation_workspace",
      "broadcast_social_context",
      "update_curiosity_drive_from_world_model",
    ]
    let functions = try functionNames.map { name -> any MTLFunction in
      guard let function = library.makeFunction(name: name) else {
        throw TissueError.metal("\(name) is missing from cognitive-state Metal")
      }
      return function
    }
    let pipelines: [any MTLComputePipelineState]
    do {
      pipelines = try functions.map { try device.makeComputePipelineState(function: $0) }
    } catch {
      throw TissueError.metal("cognitive-state pipeline creation failed: \(error)")
    }
    let descriptor = MTL4ArgumentTableDescriptor()
    descriptor.label = "NumiBrain cognitive-state arguments"
    descriptor.maxBufferBindCount = 3
    descriptor.initializeBindings = true
    let worldDescriptor = MTL4ArgumentTableDescriptor()
    worldDescriptor.label = "NumiBrain hierarchical world-model arguments"
    worldDescriptor.maxBufferBindCount = 4
    worldDescriptor.initializeBindings = true
    var worldModelLevelRecords: [WorldModelLevelRecord] = []
    var worldScalarOffset = 0
    for level in WorldModelLevel.allCases {
      let levelDescriptor = try WorldModelLevelDescriptor.referenceV1(level: level)
      guard worldScalarOffset <= Int(UInt32.max) else {
        throw TissueError.metal("world-model scalar offset exceeds UInt32")
      }
      worldModelLevelRecords.append(
        WorldModelLevelRecord(
          level: UInt32(level.rawValue),
          baseScalarOffset: UInt32(worldScalarOffset),
          latentDimension: UInt32(levelDescriptor.latentDimension),
          updatePeriodMicroseconds: levelDescriptor.updatePeriodMicroseconds,
          minimumHorizonMicroseconds: levelDescriptor.minimumHorizonMicroseconds,
          maximumHorizonMicroseconds: levelDescriptor.maximumHorizonMicroseconds,
          headCount: 5,
          flags: 1,
          reserved: 0
        )
      )
      worldScalarOffset += Int(levelDescriptor.latentDimension) * 9
    }
    guard worldScalarOffset == arena.layout.section(.worldModel).elementCount else {
      throw TissueError.metal("world-model descriptor layout drift")
    }
    let worldDescriptorByteCount = worldModelLevelRecords.count
      * MemoryLayout<WorldModelLevelRecord>.stride
    var observationScalarOffset: UInt64 = 0
    var visionObservationOffset: UInt32 = 0
    var visionObservationCount: UInt32 = 0
    var auditionObservationOffset: UInt32 = 0
    var auditionObservationCount: UInt32 = 0
    var proprioceptionObservationOffset: UInt32 = 0
    var proprioceptionObservationCount: UInt32 = 0
    var vestibularObservationOffset: UInt32 = 0
    var vestibularObservationCount: UInt32 = 0
    var olfactionObservationOffset: UInt32 = 0
    var olfactionObservationCount: UInt32 = 0
    var gustationObservationOffset: UInt32 = 0
    var gustationObservationCount: UInt32 = 0
    var interoceptionObservationOffset: UInt32 = 0
    var interoceptionObservationCount: UInt32 = 0
    for topology in species.senses where topology.enabled {
      let scalarCount = UInt64(topology.receptorCount)
        * UInt64(topology.observationDimension)
      guard observationScalarOffset + scalarCount <= UInt64(UInt32.max) else {
        throw TissueError.metal("cognitive sensory range exceeds UInt32")
      }
      if topology.modality == .vision {
        visionObservationOffset = UInt32(observationScalarOffset)
        visionObservationCount = UInt32(scalarCount)
      } else if topology.modality == .audition {
        auditionObservationOffset = UInt32(observationScalarOffset)
        auditionObservationCount = UInt32(scalarCount)
      } else if topology.modality == .proprioception {
        proprioceptionObservationOffset = UInt32(observationScalarOffset)
        proprioceptionObservationCount = UInt32(scalarCount)
      } else if topology.modality == .vestibular {
        vestibularObservationOffset = UInt32(observationScalarOffset)
        vestibularObservationCount = UInt32(scalarCount)
      } else if topology.modality == .olfaction {
        olfactionObservationOffset = UInt32(observationScalarOffset)
        olfactionObservationCount = UInt32(scalarCount)
      } else if topology.modality == .gustation {
        gustationObservationOffset = UInt32(observationScalarOffset)
        gustationObservationCount = UInt32(scalarCount)
      } else if topology.modality == .interoception {
        interoceptionObservationOffset = UInt32(observationScalarOffset)
        interoceptionObservationCount = UInt32(scalarCount)
      }
      observationScalarOffset += scalarCount
    }
    guard observationScalarOffset
      == UInt64(arena.layout.section(.sensoryObservations).elementCount)
    else {
      throw TissueError.metal("cognitive sensory ranges do not match the arena")
    }
    guard let argumentTable = try? device.makeArgumentTable(descriptor: descriptor),
      let firstWorldTable = try? device.makeArgumentTable(descriptor: worldDescriptor),
      let secondWorldTable = try? device.makeArgumentTable(descriptor: worldDescriptor),
      let thirdWorldTable = try? device.makeArgumentTable(descriptor: worldDescriptor),
      let fourthWorldTable = try? device.makeArgumentTable(descriptor: worldDescriptor),
      let fifthWorldTable = try? device.makeArgumentTable(descriptor: worldDescriptor),
      let uniformBuffer = device.makeBuffer(
        length: MemoryLayout<CognitiveUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let worldModelDescriptorBuffer = device.makeBuffer(
        length: worldDescriptorByteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate cognitive-state bindings")
    }
    uniformBuffer.label = "NumiBrain cognitive-state uniforms"
    worldModelDescriptorBuffer.label = "NumiBrain immutable hierarchical world-model layout"
    worldModelLevelRecords.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      worldModelDescriptorBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    self.layoutFingerprint = arena.layout.fingerprint
    self.arena = arena
    self.species = species
    self.regionalProgram = regionalProgram
    self.ingestPipeline = pipelines[0]
    self.homeostasisPipeline = pipelines[1]
    self.worldModelPipeline = pipelines[2]
    self.entityStatePipeline = pipelines[3]
    self.relationStatePipeline = pipelines[4]
    self.spatialStatePipeline = pipelines[5]
    self.fastPlasticityPipeline = pipelines[6]
    self.regionalPlasticityPipeline = pipelines[7]
    self.routeActionPipeline = pipelines[8]
    self.clearWorkspacePipeline = pipelines[9]
    self.workspacePipeline = pipelines[10]
    self.socialContextPipeline = pipelines[11]
    self.curiosityPipeline = pipelines[12]
    self.argumentTable = argumentTable
    self.worldModelArgumentTables = [
      firstWorldTable, secondWorldTable, thirdWorldTable,
      fourthWorldTable, fifthWorldTable,
    ]
    self.uniformBuffer = uniformBuffer
    self.worldModelDescriptorBuffer = worldModelDescriptorBuffer
    self.worldModelLevelRecords = worldModelLevelRecords
    self.visionObservationOffset = visionObservationOffset
    self.visionObservationCount = visionObservationCount
    self.auditionObservationOffset = auditionObservationOffset
    self.auditionObservationCount = auditionObservationCount
    self.proprioceptionObservationOffset = proprioceptionObservationOffset
    self.proprioceptionObservationCount = proprioceptionObservationCount
    self.vestibularObservationOffset = vestibularObservationOffset
    self.vestibularObservationCount = vestibularObservationCount
    self.olfactionObservationOffset = olfactionObservationOffset
    self.olfactionObservationCount = olfactionObservationCount
    self.gustationObservationOffset = gustationObservationOffset
    self.gustationObservationCount = gustationObservationCount
    self.interoceptionObservationOffset = interoceptionObservationOffset
    self.interoceptionObservationCount = interoceptionObservationCount
    let controlLayout = try MetalActiveControlLayout(
      arenaLayout: arena.layout,
      species: species
    )
    let internalActions = controlLayout.section(.internalActions)
    guard internalActions.elementCount <= Int(UInt32.max) else {
      throw TissueError.metal("cognitive internal-action capacity exceeds UInt32")
    }
    self.internalActionOffset = UInt64(internalActions.byteOffset)
    self.internalActionCount = UInt32(internalActions.elementCount)
    self.beliefParameterGPUAddress = try sharedParameters.gpuAddress(
      .belief, minimumScalarCount: 8
    )
    self.worldParameterGPUAddress = try sharedParameters.gpuAddress(
      .world, minimumScalarCount: 190
    )
    self.memoryParameterGPUAddress = try sharedParameters.gpuAddress(
      .memory, minimumScalarCount: 8
    )
    self.plasticityParameterGPUAddress = try sharedParameters.gpuAddress(
      .plasticity, minimumScalarCount: 8
    )
  }

  public var residencyAllocations: [any MTLAllocation] {
    [uniformBuffer, worldModelDescriptorBuffer]
  }

  /// Imports the accepted fast regional generation into the cognitive shadow
  /// without rerunning slow belief, workspace, or plasticity updates. This is
  /// the causal B_t -> B_t+1 boundary used by committed regional learning.
  public func encodeAcceptedRegionalRecurrentIngest(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    targetTimestamp: BrainTimestamp,
    deltaMicroseconds: UInt64,
    regionalRecurrentInput: MetalRegionalRecurrentBufferView
  ) throws {
    guard transaction.layoutFingerprint == layoutFingerprint,
      deltaMicroseconds > 0,
      regionalRecurrentInput.scalarCount == regionalProgram.scalarCount,
      regionalRecurrentInput.regionalProgramFingerprint == regionalProgram.fingerprint
    else {
      throw TissueError.transaction(
        "accepted regional recurrent input does not match the cognitive shadow"
      )
    }
    let hot = try arena.hotStateView(transaction: transaction)
    var uniforms = try makeUniforms(
      targetTimestamp: targetTimestamp,
      deltaMicroseconds: deltaMicroseconds,
      receptorEventCount: 0
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      uniformBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    argumentTable.setAddress(hot.outputGPUAddress, index: 0)
    argumentTable.setAddress(uniformBuffer.gpuAddress, index: 1)
    argumentTable.setAddress(regionalRecurrentInput.gpuAddress, index: 2)
    try dispatch(
      encoder: encoder,
      pipeline: ingestPipeline,
      threadCount: regionalProgram.scalarCount
    )
  }

  /// Assimilates the exact accepted O(t+1) receptor state into the structured
  /// belief factors before B(t+1) is journaled and committed. This deliberately
  /// excludes world prediction, plasticity, routing, goals, options, and motor
  /// generation so the cached decision cannot be resampled after physics.
  public func encodeAcceptedBeliefAssimilation(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    targetTimestamp: BrainTimestamp,
    deltaMicroseconds: UInt64,
    receptorEventCapacity: Int
  ) throws {
    guard transaction.layoutFingerprint == layoutFingerprint,
      deltaMicroseconds > 0,
      receptorEventCapacity >= 0,
      receptorEventCapacity < arena.layout.section(.eventQueue).elementCount,
      receptorEventCapacity <= Int(UInt32.max)
    else {
      throw TissueError.transaction(
        "accepted belief assimilation identity or event capacity is invalid"
      )
    }
    let hot = try arena.hotStateView(transaction: transaction)
    var uniforms = try makeUniforms(
      targetTimestamp: targetTimestamp,
      deltaMicroseconds: deltaMicroseconds,
      receptorEventCount: UInt32(receptorEventCapacity)
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      uniformBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    argumentTable.setAddress(hot.outputGPUAddress, index: 0)
    argumentTable.setAddress(uniformBuffer.gpuAddress, index: 1)
    argumentTable.setAddress(beliefParameterGPUAddress, index: 2)
    try dispatch(
      encoder: encoder,
      pipeline: entityStatePipeline,
      threadCount: max(
        arena.layout.section(.objectSlots).elementCount,
        arena.layout.section(.otherAgentSlots).elementCount
      )
    )
    barrier(encoder)
    try dispatch(
      encoder: encoder,
      pipeline: relationStatePipeline,
      threadCount: arena.layout.section(.relationSlots).elementCount
    )
    barrier(encoder)
    try dispatch(
      encoder: encoder,
      pipeline: spatialStatePipeline,
      threadCount: arena.layout.section(.spatialTransforms).elementCount
    )
    barrier(encoder)
    try dispatch(
      encoder: encoder,
      pipeline: socialContextPipeline,
      threadCount: 1
    )
  }

  public func encodeAcceptedCognitiveStep(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    targetTimestamp: BrainTimestamp,
    deltaMicroseconds: UInt64,
    receptorEventCapacity: Int,
    regionalRecurrentInput: MetalRegionalRecurrentBufferView? = nil
  ) throws {
    guard transaction.layoutFingerprint == layoutFingerprint,
      deltaMicroseconds > 0,
      receptorEventCapacity >= 0,
      receptorEventCapacity < arena.layout.section(.eventQueue).elementCount,
      receptorEventCapacity <= Int(UInt32.max),
      regionalRecurrentInput == nil
        || (regionalRecurrentInput?.scalarCount == regionalProgram.scalarCount
          && regionalRecurrentInput?.regionalProgramFingerprint
            == regionalProgram.fingerprint)
    else {
      throw TissueError.transaction("cognitive-state step identity or capacity is invalid")
    }
    let hot = try arena.hotStateView(transaction: transaction)
    var uniforms = try makeUniforms(
      targetTimestamp: targetTimestamp,
      deltaMicroseconds: deltaMicroseconds,
      receptorEventCount: UInt32(receptorEventCapacity)
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      uniformBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    argumentTable.setAddress(hot.outputGPUAddress, index: 0)
    argumentTable.setAddress(uniformBuffer.gpuAddress, index: 1)
    if let regionalRecurrentInput {
      argumentTable.setAddress(regionalRecurrentInput.gpuAddress, index: 2)
      try dispatch(
        encoder: encoder,
        pipeline: ingestPipeline,
        threadCount: regionalProgram.scalarCount
      )
      barrier(encoder)
    }
    try dispatch(
      encoder: encoder,
      pipeline: homeostasisPipeline,
      threadCount: max(DriveKind.allCases.count, NeuromodulatorKind.allCases.count)
    )
    barrier(encoder)
    for (index, record) in worldModelLevelRecords.enumerated() {
      let worldTable = worldModelArgumentTables[index]
      worldTable.setAddress(hot.outputGPUAddress, index: 0)
      worldTable.setAddress(uniformBuffer.gpuAddress, index: 1)
      worldTable.setAddress(worldParameterGPUAddress, index: 2)
      worldTable.setAddress(
        worldModelDescriptorBuffer.gpuAddress
          + UInt64(index * MemoryLayout<WorldModelLevelRecord>.stride),
        index: 3
      )
      try dispatch(
        encoder: encoder,
        pipeline: worldModelPipeline,
        threadCount: Int(record.latentDimension),
        argumentTable: worldTable
      )
      barrier(encoder)
    }
    try dispatch(
      encoder: encoder,
      pipeline: curiosityPipeline,
      threadCount: 1
    )
    barrier(encoder)
    argumentTable.setAddress(beliefParameterGPUAddress, index: 2)
    try dispatch(
      encoder: encoder,
      pipeline: entityStatePipeline,
      threadCount: max(
        arena.layout.section(.objectSlots).elementCount,
        arena.layout.section(.otherAgentSlots).elementCount
      )
    )
    barrier(encoder)
    try dispatch(
      encoder: encoder,
      pipeline: relationStatePipeline,
      threadCount: arena.layout.section(.relationSlots).elementCount
    )
    barrier(encoder)
    try dispatch(
      encoder: encoder,
      pipeline: spatialStatePipeline,
      threadCount: arena.layout.section(.spatialTransforms).elementCount
    )
    barrier(encoder)
    argumentTable.setAddress(plasticityParameterGPUAddress, index: 2)
    try dispatch(
      encoder: encoder,
      pipeline: fastPlasticityPipeline,
      threadCount: Int(species.capacities.fastPlasticityCapacity)
    )
    barrier(encoder)
    try dispatch(
      encoder: encoder,
      pipeline: regionalPlasticityPipeline,
      threadCount: species.enabledModuleIdentifiers.count
    )
    barrier(encoder)
    try dispatch(
      encoder: encoder,
      pipeline: routeActionPipeline,
      threadCount: 1
    )
    barrier(encoder)
    let workspaceContent = Int(species.capacities.workspaceTokenCapacity)
      * Int(species.capacities.workspaceTokenDimension)
    try dispatch(
      encoder: encoder,
      pipeline: clearWorkspacePipeline,
      threadCount: 1
    )
    barrier(encoder)
    argumentTable.setAddress(memoryParameterGPUAddress, index: 2)
    try dispatch(
      encoder: encoder,
      pipeline: workspacePipeline,
      threadCount: max(workspaceContent, Int(species.capacities.workspaceTokenCapacity))
    )
    barrier(encoder)
    argumentTable.setAddress(beliefParameterGPUAddress, index: 2)
    try dispatch(
      encoder: encoder,
      pipeline: socialContextPipeline,
      threadCount: 1
    )
    barrier(encoder)
  }

  private func makeUniforms(
    targetTimestamp: BrainTimestamp,
    deltaMicroseconds: UInt64,
    receptorEventCount: UInt32
  ) throws -> CognitiveUniforms {
    func offset(_ section: MetalAgentHotSection) -> UInt64 {
      UInt64(arena.layout.section(section).byteOffset)
    }
    func count(_ section: MetalAgentHotSection) throws -> UInt32 {
      let count = arena.layout.section(section).elementCount
      guard count <= Int(UInt32.max) else {
        throw TissueError.metal("cognitive section count exceeds UInt32")
      }
      return UInt32(count)
    }
    var bodySensingMask: UInt32 = 0
    for (index, channel) in species.activeSensingChannels.enumerated()
    where index < 32
      && (channel.modality == .touch || channel.modality == .proprioception) {
      bodySensingMask |= 1 << UInt32(index)
    }
    return try CognitiveUniforms(
      targetTimestampMicroseconds: targetTimestamp.rawValue,
      deltaMicroseconds: deltaMicroseconds,
      recurrentOffset: offset(.regionalRecurrent),
      workspaceContentOffset: offset(.workspaceContent),
      workspaceMetadataOffset: offset(.workspaceMetadata),
      worldModelOffset: offset(.worldModel),
      driveOffset: offset(.drives),
      neuromodulationOffset: offset(.neuromodulation),
      fastPlasticityOffset: offset(.fastPlasticity),
      activeControlOffset: offset(.activeControl),
      internalActionOffset: internalActionOffset,
      eventQueueOffset: offset(.eventQueue),
      developmentalStateOffset: offset(.developmentalState),
      regionalMaturationOffset: offset(.regionalMaturation),
      regionalPlasticModulationOffset: offset(.regionalPlasticModulation),
      hotStateByteCount: UInt64(arena.layout.totalByteCount),
      observationOffset: offset(.sensoryObservations),
      objectSlotOffset: offset(.objectSlots),
      otherAgentSlotOffset: offset(.otherAgentSlots),
      contextBeliefOffset: offset(.contextBelief),
      relationSlotOffset: offset(.relationSlots),
      spatialTransformOffset: offset(.spatialTransforms),
      physiologyBeliefOffset: offset(.physiologyBelief),
      bodyBeliefOffset: offset(.bodyBelief),
      activeSensingEfficacyOffset: offset(.activeSensingEfficacy),
      somaticOutputOffset: offset(.somaticOutput),
      acceptedAutonomicOutputOffset: offset(.acceptedAutonomicOutput),
      acceptedActiveSensingOutputOffset: offset(.acceptedActiveSensingOutput),
      recurrentScalarCount: UInt32(regionalProgram.scalarCount),
      workspaceCapacity: UInt32(species.capacities.workspaceTokenCapacity),
      workspaceDimension: UInt32(species.capacities.workspaceTokenDimension),
      worldModelScalarCount: count(.worldModel),
      driveCount: UInt32(DriveKind.allCases.count),
      neuromodulatorCount: UInt32(NeuromodulatorKind.allCases.count),
      fastPlasticityCount: UInt32(species.capacities.fastPlasticityCapacity),
      activeControlScalarCount: count(.activeControl),
      eventCount: receptorEventCount,
      actuatorCount: species.motor.actuatorCount,
      synergyCount: UInt32(species.motor.synergyCount),
      moduleCount: UInt32(species.enabledModuleIdentifiers.count),
      worldLevelCount: UInt32(worldModelLevelRecords.count),
      worldHeadCount: 5,
      proprioceptionObservationOffset: proprioceptionObservationOffset,
      proprioceptionObservationCount: proprioceptionObservationCount,
      observationCount: count(.sensoryObservations),
      visionObservationOffset: visionObservationOffset,
      visionObservationCount: visionObservationCount,
      auditionObservationOffset: auditionObservationOffset,
      auditionObservationCount: auditionObservationCount,
      objectSlotCount: UInt32(species.capacities.objectSlotCapacity),
      otherAgentSlotCount: UInt32(species.capacities.otherAgentSlotCapacity),
      contextBeliefCount: count(.contextBelief),
      relationSlotCount: count(.relationSlots),
      vestibularObservationOffset: vestibularObservationOffset,
      vestibularObservationCount: vestibularObservationCount,
      spatialTransformCount: count(.spatialTransforms),
      physiologyBeliefCount: count(.physiologyBelief),
      bodyBeliefCount: count(.bodyBelief),
      olfactionObservationOffset: olfactionObservationOffset,
      olfactionObservationCount: olfactionObservationCount,
      gustationObservationOffset: gustationObservationOffset,
      gustationObservationCount: gustationObservationCount,
      interoceptionObservationOffset: interoceptionObservationOffset,
      interoceptionObservationCount: interoceptionObservationCount,
      activeSensingCount: UInt32(species.motor.activeSensingActionDimension),
      bodySensingMask: bodySensingMask,
      autonomicActionCount: UInt32(
        species.physiology.autonomicActionDimension
      ),
      internalActionCount: internalActionCount
    )
  }

  private func dispatch(
    encoder: any MTL4ComputeCommandEncoder,
    pipeline: any MTLComputePipelineState,
    threadCount: Int,
    argumentTable selectedArgumentTable: (any MTL4ArgumentTable)? = nil
  ) throws {
    guard threadCount > 0 else {
      throw TissueError.metal("cognitive-state dispatch cannot be empty")
    }
    encoder.setComputePipelineState(pipeline)
    encoder.setArgumentTable(selectedArgumentTable ?? argumentTable)
    let width = min(
      max(pipeline.threadExecutionWidth, 1),
      pipeline.maxTotalThreadsPerThreadgroup
    )
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: threadCount, height: 1, depth: 1),
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

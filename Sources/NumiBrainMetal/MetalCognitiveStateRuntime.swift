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
  var eventQueueOffset: UInt64 = 0
  var hotStateByteCount: UInt64 = 0
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
  var reserved0: UInt32 = 0
  var reserved1: UInt32 = 0
  var reserved2: UInt32 = 0
  var reserved3: UInt32 = 0
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
  private let fastPlasticityPipeline: any MTLComputePipelineState
  private let workspacePipeline: any MTLComputePipelineState
  private let motorPipeline: any MTLComputePipelineState
  private let argumentTable: any MTL4ArgumentTable
  private let uniformBuffer: any MTLBuffer

  public init(
    device: any MTLDevice,
    arena: MetalAgentStateArena,
    species: SpeciesTemplate,
    regionalProgram: RegionalTokenProgram
  ) throws {
    guard MemoryLayout<CognitiveUniforms>.stride == 160,
      arena.layout.speciesTemplateFingerprint == species.fingerprint,
      arena.layout.regionalProgramFingerprint == regionalProgram.fingerprint
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
      "advance_fast_plasticity_foundation",
      "broadcast_foundation_workspace",
      "advance_foundation_motor_control",
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
    guard let argumentTable = try? device.makeArgumentTable(descriptor: descriptor),
      let uniformBuffer = device.makeBuffer(
        length: MemoryLayout<CognitiveUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate cognitive-state bindings")
    }
    uniformBuffer.label = "NumiBrain cognitive-state uniforms"
    self.layoutFingerprint = arena.layout.fingerprint
    self.arena = arena
    self.species = species
    self.regionalProgram = regionalProgram
    self.ingestPipeline = pipelines[0]
    self.homeostasisPipeline = pipelines[1]
    self.worldModelPipeline = pipelines[2]
    self.fastPlasticityPipeline = pipelines[3]
    self.workspacePipeline = pipelines[4]
    self.motorPipeline = pipelines[5]
    self.argumentTable = argumentTable
    self.uniformBuffer = uniformBuffer
  }

  public var residencyAllocation: any MTLAllocation { uniformBuffer }

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
    try dispatch(
      encoder: encoder,
      pipeline: worldModelPipeline,
      threadCount: arena.layout.section(.worldModel).elementCount
    )
    barrier(encoder)
    try dispatch(
      encoder: encoder,
      pipeline: fastPlasticityPipeline,
      threadCount: Int(species.capacities.fastPlasticityCapacity)
    )
    barrier(encoder)
    let workspaceContent = Int(species.capacities.workspaceTokenCapacity)
      * Int(species.capacities.workspaceTokenDimension)
    try dispatch(
      encoder: encoder,
      pipeline: workspacePipeline,
      threadCount: max(workspaceContent, Int(species.capacities.workspaceTokenCapacity))
    )
    barrier(encoder)
    try dispatch(
      encoder: encoder,
      pipeline: motorPipeline,
      threadCount: arena.layout.section(.activeControl).elementCount
    )
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
      eventQueueOffset: offset(.eventQueue),
      hotStateByteCount: UInt64(arena.layout.totalByteCount),
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
      reserved0: 0,
      reserved1: 0,
      reserved2: 0,
      reserved3: 0
    )
  }

  private func dispatch(
    encoder: any MTL4ComputeCommandEncoder,
    pipeline: any MTLComputePipelineState,
    threadCount: Int
  ) throws {
    guard threadCount > 0 else {
      throw TissueError.metal("cognitive-state dispatch cannot be empty")
    }
    encoder.setComputePipelineState(pipeline)
    encoder.setArgumentTable(argumentTable)
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

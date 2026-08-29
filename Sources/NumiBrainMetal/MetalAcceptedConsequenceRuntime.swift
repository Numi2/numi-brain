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
  var worldModelOffset: UInt64 = 0
  var neuromodulationOffset: UInt64 = 0
  var fastPlasticityOffset: UInt64 = 0
  var workspaceContentOffset: UInt64 = 0
  var workspaceMetadataOffset: UInt64 = 0
  var controlHeaderOffset: UInt64 = 0
  var motorCommandOffset: UInt64 = 0
  var cerebellarOffset: UInt64 = 0
  var cerebellarExpertMemoryOffset: UInt64 = 0
  var somaticOutputOffset: UInt64 = 0
  var physicsStateFingerprint: UInt64 = 0
  var observationCount: UInt32 = 0
  var bodyCount: UInt32 = 0
  var muscleCount: UInt32 = 0
  var physiologyCount: UInt32 = 0
  var worldModelCount: UInt32 = 0
  var neuromodulatorCount: UInt32 = 0
  var fastPlasticityCount: UInt32 = 0
  var workspaceCapacity: UInt32 = 0
  var workspaceDimension: UInt32 = 0
  var activeCerebellarCount: UInt32 = 0
  var actuatorCount: UInt32 = 0
  var eventCapacity: UInt32 = 0
  var proprioceptionOffset: UInt32 = 0
  var proprioceptionCount: UInt32 = 0
  var touchOffset: UInt32 = 0
  var touchCount: UInt32 = 0
  var vestibularOffset: UInt32 = 0
  var vestibularCount: UInt32 = 0
  var interoceptionOffset: UInt32 = 0
  var interoceptionCount: UInt32 = 0
  var beliefGain: Float = 0
  var worldCorrectionGain: Float = 0
  var cerebellarLearningRate: Float = 0
  var plasticityLearningRate: Float = 0
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

  public init(
    device: any MTLDevice,
    arena: MetalAgentStateArena,
    species: SpeciesTemplate,
    dynamics: AcceptedConsequenceDynamics
  ) throws {
    guard MemoryLayout<AcceptedConsequenceUniforms>.stride == 240,
      arena.layout.speciesTemplateFingerprint == species.fingerprint
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
      "broadcast_accepted_prediction_error",
      "adapt_cerebellar_experts_from_accepted_error",
      "update_fast_plasticity_from_accepted_error",
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
    descriptor.maxBufferBindCount = 2
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
  }

  public var residencyAllocation: any MTLAllocation { uniformBuffer }

  public func encode(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    deltaMicroseconds: UInt64,
    receptorEventCapacity: Int
  ) throws {
    guard acceptedPhysicsState.acceptedTimestamp.rawValue >= deltaMicroseconds,
      receptorEventCapacity >= 0,
      receptorEventCapacity <= Int(UInt32.max)
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
    dispatch(
      encoder,
      pipeline: pipelines[0],
      count: max(
        Int(species.body.bodyCount),
        max(Int(species.body.muscleCount), Int(species.physiology.stateDimension))
      )
    )
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: pipelines[1],
      count: min(arena.layout.section(.worldModel).elementCount, 128)
    )
    barrier(encoder)
    dispatch(encoder, pipeline: pipelines[2], count: 1)
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: pipelines[3],
      count: Int(species.capacities.activeCerebellarExpertCapacity)
    )
    dispatch(
      encoder,
      pipeline: pipelines[4],
      count: Int(species.capacities.fastPlasticityCapacity)
    )
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
    let proprioception = range(.proprioception)
    let touch = range(.touch)
    let vestibular = range(.vestibular)
    let interoception = range(.interoception)
    let controlHeader = controlLayout.section(.header)
    let motor = controlLayout.section(.motorCommands)
    let cerebellar = controlLayout.section(.cerebellarExperts)
    let integerCounts = [
      hot(.sensoryObservations).elementCount,
      hot(.worldModel).elementCount,
      hot(.fastPlasticity).elementCount,
    ]
    guard integerCounts.allSatisfy({ $0 <= Int(UInt32.max) }) else {
      throw TissueError.metal("accepted-consequence arena exceeds UInt32")
    }
    return AcceptedConsequenceUniforms(
      targetTimestampMicroseconds: acceptedPhysicsState.acceptedTimestamp.rawValue,
      deltaMicroseconds: deltaMicroseconds,
      observationOffset: UInt64(hot(.sensoryObservations).byteOffset),
      eventQueueOffset: UInt64(hot(.eventQueue).byteOffset),
      bodyBeliefOffset: UInt64(hot(.bodyBelief).byteOffset),
      muscleBeliefOffset: UInt64(hot(.muscleBelief).byteOffset),
      physiologyOffset: UInt64(hot(.physiologyBelief).byteOffset),
      worldModelOffset: UInt64(hot(.worldModel).byteOffset),
      neuromodulationOffset: UInt64(hot(.neuromodulation).byteOffset),
      fastPlasticityOffset: UInt64(hot(.fastPlasticity).byteOffset),
      workspaceContentOffset: UInt64(hot(.workspaceContent).byteOffset),
      workspaceMetadataOffset: UInt64(hot(.workspaceMetadata).byteOffset),
      controlHeaderOffset: UInt64(controlHeader.byteOffset),
      motorCommandOffset: UInt64(motor.byteOffset),
      cerebellarOffset: UInt64(cerebellar.byteOffset),
      cerebellarExpertMemoryOffset: UInt64(
        hot(.cerebellarExpertMemory).byteOffset
      ),
      somaticOutputOffset: UInt64(hot(.somaticOutput).byteOffset),
      physicsStateFingerprint: acceptedPhysicsState.physicsStateFingerprint,
      observationCount: UInt32(hot(.sensoryObservations).elementCount),
      bodyCount: species.body.bodyCount,
      muscleCount: species.body.muscleCount,
      physiologyCount: UInt32(species.physiology.stateDimension),
      worldModelCount: UInt32(hot(.worldModel).elementCount),
      neuromodulatorCount: UInt32(NeuromodulatorKind.allCases.count),
      fastPlasticityCount: UInt32(hot(.fastPlasticity).elementCount),
      workspaceCapacity: UInt32(species.capacities.workspaceTokenCapacity),
      workspaceDimension: UInt32(species.capacities.workspaceTokenDimension),
      activeCerebellarCount: UInt32(
        species.capacities.activeCerebellarExpertCapacity
      ),
      actuatorCount: species.motor.actuatorCount,
      eventCapacity: eventCapacity,
      proprioceptionOffset: proprioception.offset,
      proprioceptionCount: proprioception.count,
      touchOffset: touch.offset,
      touchCount: touch.count,
      vestibularOffset: vestibular.offset,
      vestibularCount: vestibular.count,
      interoceptionOffset: interoception.offset,
      interoceptionCount: interoception.count,
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

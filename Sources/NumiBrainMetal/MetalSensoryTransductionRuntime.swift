import Foundation
@preconcurrency import Metal
import NumiBrainCore

private struct SensoryUniforms {
  var targetTimestampMicroseconds: UInt64 = 0
  var episodeIdentifier: UInt64 = 0
  var controlStepIdentifier: UInt64 = 0
  var randomCounterGeneration: UInt64 = 0
  var observationOffset: UInt64 = 0
  var adaptationOffset: UInt64 = 0
  var validityOffset: UInt64 = 0
  var frameMetadataOffset: UInt64 = 0
  var eventQueueOffset: UInt64 = 0
  var developmentalStateOffset: UInt64 = 0
  var environmentIdentifier: UInt32 = 0
  var descriptorCount: UInt32 = 0
  var totalObservationScalars: UInt32 = 0
  var totalReceptors: UInt32 = 0
  var eventCapacity: UInt32 = 0
  var eventRuleCount: UInt32 = 0
  var deltaMicroseconds: UInt32 = 0
  var flags: UInt32 = 0
}

private struct SensoryDescriptorRecord {
  var modality: UInt32 = 0
  var receptorCount: UInt32 = 0
  var featureDimension: UInt32 = 0
  var inputBufferIndex: UInt32 = 0
  var outputScalarOffset: UInt32 = 0
  var adaptationOffset: UInt32 = 0
  var rawScalarCount: UInt32 = 0
  var flags: UInt32 = 0
  var latencyMicroseconds: UInt64 = 0
  var adaptationTimeConstantSeconds: Float = 0
  var noiseStandardDeviation: Float = 0
  var reserved0: UInt64 = 0
  var reserved1: UInt64 = 0
}

private struct ReceptorEventRuleRecord {
  var identifier: UInt32 = 0
  var modality: UInt32 = 0
  var receptorStart: UInt32 = 0
  var receptorCount: UInt32 = 0
  var featureIndex: UInt32 = 0
  var comparison: UInt32 = 0
  var eventKind: UInt32 = 0
  var eventFlags: UInt32 = 0
  var threshold: Float = 0
  var magnitudeScale: Float = 0
  var sourceIdentifier: UInt32 = 0
  var ruleFlags: UInt32 = 0
}

@frozen
public struct MetalRawSensorBufferView: Equatable, Sendable {
  public let modality: SensoryModality
  public let gpuAddress: UInt64
  public let byteCount: Int
  public let receptorTimestamp: BrainTimestamp
  public let receptorCount: UInt32
  public let featureDimension: UInt32
  public let validityGPUAddress: UInt64
  public let validityByteCount: Int

  public var hasValidity: Bool { validityGPUAddress != 0 }

  public init(
    modality: SensoryModality,
    gpuAddress: UInt64,
    byteCount: Int,
    receptorTimestamp: BrainTimestamp,
    receptorCount: UInt32,
    featureDimension: UInt32,
    validityGPUAddress: UInt64 = 0,
    validityByteCount: Int = 0
  ) throws {
    let (scalarCount, scalarOverflow) = Int(receptorCount)
      .multipliedReportingOverflow(by: Int(featureDimension))
    let (minimumBytes, byteOverflow) = scalarCount.multipliedReportingOverflow(
      by: MemoryLayout<Float>.stride
    )
    let (minimumValidityBytes, validityOverflow) = Int(receptorCount)
      .multipliedReportingOverflow(by: MemoryLayout<UInt32>.stride)
    let hasValidity = validityGPUAddress != 0
    guard gpuAddress > 0, gpuAddress % UInt64(MemoryLayout<Float>.alignment) == 0,
      !scalarOverflow, !byteOverflow, !validityOverflow,
      byteCount >= minimumBytes, receptorCount > 0, featureDimension > 0,
      hasValidity == (validityByteCount > 0),
      !hasValidity || (
        validityGPUAddress % UInt64(MemoryLayout<UInt32>.alignment) == 0
          && validityByteCount >= minimumValidityBytes
      )
    else {
      throw TissueError.transaction("raw sensor buffer view is invalid")
    }
    self.modality = modality
    self.gpuAddress = gpuAddress
    self.byteCount = byteCount
    self.receptorTimestamp = receptorTimestamp
    self.receptorCount = receptorCount
    self.featureDimension = featureDimension
    self.validityGPUAddress = validityGPUAddress
    self.validityByteCount = validityByteCount
  }
}

@available(macOS 26.0, *)
public final class MetalRawSensorBufferLease: @unchecked Sendable {
  public let view: MetalRawSensorBufferView
  let buffer: any MTLBuffer
  let validityBuffer: (any MTLBuffer)?

  public init(
    buffer: any MTLBuffer,
    modality: SensoryModality,
    receptorTimestamp: BrainTimestamp,
    receptorCount: UInt32,
    featureDimension: UInt32,
    validityBuffer: (any MTLBuffer)? = nil
  ) throws {
    view = try MetalRawSensorBufferView(
      modality: modality,
      gpuAddress: buffer.gpuAddress,
      byteCount: buffer.length,
      receptorTimestamp: receptorTimestamp,
      receptorCount: receptorCount,
      featureDimension: featureDimension,
      validityGPUAddress: validityBuffer?.gpuAddress ?? 0,
      validityByteCount: validityBuffer?.length ?? 0
    )
    self.buffer = buffer
    self.validityBuffer = validityBuffer
  }
}

@available(macOS 26.0, *)
public final class MetalSensoryTransductionRuntime: @unchecked Sendable {
  @frozen
  public struct Result: Equatable, Sendable {
    public let timestamp: BrainTimestamp
    public let randomCounterGeneration: UInt64
    public let observationGPUAddress: UInt64
    public let observationScalarCount: Int
    public let validityGPUAddress: UInt64
    public let validityScalarCount: Int
    public let eventQueueGPUAddress: UInt64
    public let eventCapacity: Int
    public let maximumEventCount: Int
  }

  public let profileFingerprint: UInt64
  public let maximumEventCount: Int

  private let arena: MetalAgentStateArena
  private let species: SpeciesTemplate
  private let profile: SensoryTransductionProfile
  private let descriptors: [SensoryDescriptorRecord]
  private let inputSlotByModality: [SensoryModality: Int]
  private let totalObservationScalars: Int
  private let totalReceptors: Int
  private let beginPipeline: any MTLComputePipelineState
  private let adaptationPipeline: any MTLComputePipelineState
  private let transductionPipeline: any MTLComputePipelineState
  private let eventPipeline: any MTLComputePipelineState
  private let argumentTable: any MTL4ArgumentTable
  private let descriptorBuffer: any MTLBuffer
  private let ruleBuffer: any MTLBuffer
  private let uniformBuffer: any MTLBuffer
  private let dummyInputBuffer: any MTLBuffer
  private let dummyValidityBuffer: any MTLBuffer
  private let unconditionalAcceptanceGateBuffer: any MTLBuffer

  static func compactInputSlots(
    for modalities: [SensoryModality]
  ) throws -> [SensoryModality: Int] {
    let canonical = modalities.sorted { $0.rawValue < $1.rawValue }
    guard canonical.count <= 8, Set(canonical).count == canonical.count else {
      throw TissueError.metal("sensory topology exceeds eight compact Metal slots")
    }
    return Dictionary(
      uniqueKeysWithValues: canonical.enumerated().map {
        ($0.element, $0.offset)
      }
    )
  }

  public init(
    device: any MTLDevice,
    arena: MetalAgentStateArena,
    species: SpeciesTemplate,
    profile: SensoryTransductionProfile,
    sharedParameters: MetalSharedParameterBank
  ) throws {
    guard MemoryLayout<SensoryUniforms>.stride == 112,
      MemoryLayout<SensoryDescriptorRecord>.stride == 64,
      MemoryLayout<ReceptorEventRuleRecord>.stride == 48,
      arena.layout.speciesTemplateFingerprint == species.fingerprint,
      profile.speciesTemplateFingerprint == species.fingerprint
    else {
      throw TissueError.metal("sensory transduction ABI or species identity drift")
    }
    var observationOffset: UInt32 = 0
    var adaptationOffset: UInt32 = 0
    var descriptors: [SensoryDescriptorRecord] = []
    let enabledTopologies = species.senses.filter(\.enabled).sorted {
      $0.modality.rawValue < $1.modality.rawValue
    }
    let inputSlotByModality = try Self.compactInputSlots(
      for: enabledTopologies.map(\.modality)
    )
    for (inputSlot, topology) in enabledTopologies.enumerated() {
      let scalarCount64 = UInt64(topology.receptorCount)
        * UInt64(topology.observationDimension)
      guard scalarCount64 <= UInt64(UInt32.max),
        UInt64(observationOffset) + scalarCount64 <= UInt64(UInt32.max),
        UInt64(adaptationOffset) + UInt64(topology.receptorCount) <= UInt64(UInt32.max)
      else {
        throw TissueError.metal("sensory topology exceeds Metal UInt32 limits")
      }
      let scalarCount = UInt32(scalarCount64)
      descriptors.append(
        SensoryDescriptorRecord(
          modality: UInt32(topology.modality.rawValue),
          receptorCount: topology.receptorCount,
          featureDimension: topology.observationDimension,
          inputBufferIndex: UInt32(inputSlot),
          outputScalarOffset: observationOffset,
          adaptationOffset: adaptationOffset,
          rawScalarCount: scalarCount,
          flags: 1,
          latencyMicroseconds: UInt64(topology.latencyMicroseconds),
          adaptationTimeConstantSeconds:
            Float(topology.adaptationTimeConstantMicroseconds) * 0.000_001,
          noiseStandardDeviation: topology.noiseStandardDeviation,
          reserved0: 0,
          reserved1: 0
        )
      )
      observationOffset += scalarCount
      adaptationOffset += topology.receptorCount
    }
    guard Int(observationOffset) == arena.layout.section(.sensoryObservations).elementCount,
      Int(adaptationOffset) == arena.layout.section(.sensoryAdaptation).elementCount,
      descriptors.count <= arena.layout.section(.sensoryFrameMetadata).elementCount
    else {
      throw TissueError.metal("sensory arena shape does not match species topology")
    }
    let ruleRecords = profile.eventRules.map {
      ReceptorEventRuleRecord(
        identifier: $0.identifier,
        modality: UInt32($0.modality.rawValue),
        receptorStart: $0.receptorStart,
        receptorCount: $0.receptorCount,
        featureIndex: $0.featureIndex,
        comparison: UInt32($0.comparison.rawValue),
        eventKind: UInt32($0.eventKind.rawValue),
        eventFlags: $0.eventFlags,
        threshold: $0.threshold,
        magnitudeScale: $0.magnitudeScale,
        sourceIdentifier: $0.sourceIdentifier,
        ruleFlags: $0.usesAbsoluteThreshold ? 1 : 0
      )
    }
    let sourceURL =
      Bundle.module.url(
        forResource: "SensoryTransduction",
        withExtension: "metal",
        subdirectory: "Shaders"
      ) ?? Bundle.module.url(forResource: "SensoryTransduction", withExtension: "metal")
    guard let sourceURL else {
      throw TissueError.metal("SensoryTransduction.metal is missing from resources")
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
      throw TissueError.metal("sensory Metal 4 compilation failed: \(error)")
    }
    let names = [
      "begin_sensory_frame", "update_receptor_adaptation",
      "transduce_receptor_observations", "extract_receptor_events",
    ]
    let functions = try names.map { name -> any MTLFunction in
      guard let function = library.makeFunction(name: name) else {
        throw TissueError.metal("\(name) is missing from sensory Metal")
      }
      return function
    }
    let pipelines: [any MTLComputePipelineState]
    do {
      pipelines = try functions.map { try device.makeComputePipelineState(function: $0) }
    } catch {
      throw TissueError.metal("sensory pipeline creation failed: \(error)")
    }
    let argumentDescriptor = MTL4ArgumentTableDescriptor()
    argumentDescriptor.label = "NumiBrain sensory transduction arguments"
    argumentDescriptor.maxBufferBindCount = 22
    argumentDescriptor.initializeBindings = true
    let descriptorByteCount = max(
      descriptors.count * MemoryLayout<SensoryDescriptorRecord>.stride,
      MemoryLayout<SensoryDescriptorRecord>.stride
    )
    let ruleByteCount = max(
      ruleRecords.count * MemoryLayout<ReceptorEventRuleRecord>.stride,
      MemoryLayout<ReceptorEventRuleRecord>.stride
    )
    guard let argumentTable = try? device.makeArgumentTable(descriptor: argumentDescriptor),
      let descriptorBuffer = device.makeBuffer(
        length: descriptorByteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let ruleBuffer = device.makeBuffer(
        length: ruleByteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let uniformBuffer = device.makeBuffer(
        length: MemoryLayout<SensoryUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let dummyInputBuffer = device.makeBuffer(
        length: MemoryLayout<Float>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let dummyValidityBuffer = device.makeBuffer(
        length: MemoryLayout<UInt32>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let unconditionalAcceptanceGateBuffer = device.makeBuffer(
        length: MemoryLayout<UInt32>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate sensory transduction bindings")
    }
    descriptorBuffer.label = "NumiBrain immutable sensory descriptors"
    ruleBuffer.label = "NumiBrain immutable receptor event rules"
    uniformBuffer.label = "NumiBrain sensory transduction uniforms"
    dummyInputBuffer.label = "NumiBrain disabled sensory input"
    dummyValidityBuffer.label = "NumiBrain implicit valid receptor mask"
    descriptors.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      descriptorBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    ruleRecords.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      ruleBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    dummyInputBuffer.contents().storeBytes(of: Float(0), as: Float.self)
    dummyValidityBuffer.contents().storeBytes(of: UInt32.max, as: UInt32.self)
    unconditionalAcceptanceGateBuffer.contents().storeBytes(
      of: UInt32(1), as: UInt32.self
    )
    argumentTable.setAddress(
      try sharedParameters.gpuAddress(.sensory, minimumScalarCount: 8),
      index: 11
    )
    self.profileFingerprint = profile.fingerprint
    self.maximumEventCount = profile.eventRules.count
    self.arena = arena
    self.species = species
    self.profile = profile
    self.descriptors = descriptors
    self.inputSlotByModality = inputSlotByModality
    self.totalObservationScalars = Int(observationOffset)
    self.totalReceptors = Int(adaptationOffset)
    self.beginPipeline = pipelines[0]
    self.adaptationPipeline = pipelines[1]
    self.transductionPipeline = pipelines[2]
    self.eventPipeline = pipelines[3]
    self.argumentTable = argumentTable
    self.descriptorBuffer = descriptorBuffer
    self.ruleBuffer = ruleBuffer
    self.uniformBuffer = uniformBuffer
    self.dummyInputBuffer = dummyInputBuffer
    self.dummyValidityBuffer = dummyValidityBuffer
    self.unconditionalAcceptanceGateBuffer = unconditionalAcceptanceGateBuffer
  }

  public var residencyAllocations: [any MTLAllocation] {
    [
      descriptorBuffer, ruleBuffer, uniformBuffer, dummyInputBuffer,
      dummyValidityBuffer, unconditionalAcceptanceGateBuffer,
    ]
  }

  public func encode(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    rawSensorViews: [MetalRawSensorBufferView],
    environmentIdentifier: UInt32,
    episodeIdentifier: UInt64,
    controlStepIdentifier: UInt64,
    randomCounterGeneration: UInt64,
    targetTimestamp: BrainTimestamp,
    deltaMicroseconds: UInt32,
    allowsMatchingAcceptedFrameReuse: Bool = false,
    acceptanceGateGPUAddress: UInt64? = nil
  ) throws -> Result {
    guard transaction.layoutFingerprint == arena.layout.fingerprint,
      deltaMicroseconds > 0,
      Set(rawSensorViews.map(\.modality)).count == rawSensorViews.count
    else {
      throw TissueError.transaction("sensory shadow transaction is invalid")
    }
    let enabled = species.senses.filter(\.enabled)
    guard Set(rawSensorViews.map(\.modality)) == Set(enabled.map(\.modality)) else {
      throw TissueError.transaction("raw sensory views do not match enabled modalities")
    }
    let topologyByModality = Dictionary(
      uniqueKeysWithValues: enabled.map { ($0.modality, $0) }
    )
    for view in rawSensorViews {
      guard let topology = topologyByModality[view.modality],
        view.receptorCount == topology.receptorCount,
        view.featureDimension == topology.observationDimension,
        targetTimestamp.rawValue >= UInt64(topology.latencyMicroseconds),
        view.receptorTimestamp.rawValue
          == targetTimestamp.rawValue - UInt64(topology.latencyMicroseconds)
      else {
        throw TissueError.transaction("raw sensory view violates causal topology")
      }
    }
    let hot = try arena.hotStateView(transaction: transaction)
    let observation = arena.layout.section(.sensoryObservations)
    let adaptation = arena.layout.section(.sensoryAdaptation)
    let validity = arena.layout.section(.sensoryValidity)
    let metadata = arena.layout.section(.sensoryFrameMetadata)
    let eventQueue = arena.layout.section(.eventQueue)
    let eventCapacity = eventQueue.elementCount - 1
    guard validity.elementCount == observation.elementCount,
      eventCapacity <= Int(UInt32.max), descriptors.count <= Int(UInt32.max),
      totalObservationScalars <= Int(UInt32.max), totalReceptors <= Int(UInt32.max),
      profile.eventRules.count <= eventCapacity,
      profile.eventRules.count <= Int(UInt32.max)
    else {
      throw TissueError.metal("sensory runtime exceeds compiled queue limits")
    }
    var validityFlags: UInt32 = allowsMatchingAcceptedFrameReuse ? 1 : 0
    for view in rawSensorViews where view.hasValidity {
      guard let inputSlot = inputSlotByModality[view.modality] else {
        throw TissueError.transaction("raw sensory modality has no compact Metal slot")
      }
      validityFlags |= UInt32(1) << UInt32(8 + inputSlot)
    }
    var uniforms = SensoryUniforms(
      targetTimestampMicroseconds: targetTimestamp.rawValue,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: controlStepIdentifier,
      randomCounterGeneration: randomCounterGeneration,
      observationOffset: UInt64(observation.byteOffset),
      adaptationOffset: UInt64(adaptation.byteOffset),
      validityOffset: UInt64(validity.byteOffset),
      frameMetadataOffset: UInt64(metadata.byteOffset),
      eventQueueOffset: UInt64(eventQueue.byteOffset),
      developmentalStateOffset: UInt64(
        arena.layout.section(.developmentalState).byteOffset
      ),
      environmentIdentifier: environmentIdentifier,
      descriptorCount: UInt32(descriptors.count),
      totalObservationScalars: UInt32(totalObservationScalars),
      totalReceptors: UInt32(totalReceptors),
      eventCapacity: UInt32(eventCapacity),
      eventRuleCount: UInt32(profile.eventRules.count),
      deltaMicroseconds: deltaMicroseconds,
      flags: validityFlags
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      uniformBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    let viewByModality = Dictionary(
      uniqueKeysWithValues: rawSensorViews.map { ($0.modality, $0) }
    )
    argumentTable.setAddress(hot.outputGPUAddress, index: 0)
    argumentTable.setAddress(descriptorBuffer.gpuAddress, index: 1)
    argumentTable.setAddress(uniformBuffer.gpuAddress, index: 2)
    for inputSlot in 0..<8 {
      argumentTable.setAddress(dummyInputBuffer.gpuAddress, index: inputSlot + 3)
      argumentTable.setAddress(dummyValidityBuffer.gpuAddress, index: inputSlot + 12)
    }
    for (modality, inputSlot) in inputSlotByModality {
      argumentTable.setAddress(
        viewByModality[modality]?.gpuAddress ?? dummyInputBuffer.gpuAddress,
        index: inputSlot + 3
      )
      argumentTable.setAddress(
        viewByModality[modality].flatMap {
          $0.hasValidity ? $0.validityGPUAddress : nil
        } ?? dummyValidityBuffer.gpuAddress,
        index: inputSlot + 12
      )
    }
    argumentTable.setAddress(
      acceptanceGateGPUAddress ?? unconditionalAcceptanceGateBuffer.gpuAddress,
      index: 20
    )
    dispatch(
      encoder: encoder,
      pipeline: beginPipeline,
      count: max(descriptors.count, 1)
    )
    barrier(encoder)
    dispatch(
      encoder: encoder,
      pipeline: adaptationPipeline,
      count: max(totalReceptors, 1)
    )
    barrier(encoder)
    dispatch(
      encoder: encoder,
      pipeline: transductionPipeline,
      count: max(totalObservationScalars, 1)
    )
    if !profile.eventRules.isEmpty {
      barrier(encoder)
      argumentTable.setAddress(ruleBuffer.gpuAddress, index: 2)
      argumentTable.setAddress(uniformBuffer.gpuAddress, index: 21)
      dispatch(
        encoder: encoder,
        pipeline: eventPipeline,
        count: profile.eventRules.count
      )
    }
    return Result(
      timestamp: targetTimestamp,
      randomCounterGeneration: randomCounterGeneration,
      observationGPUAddress: hot.outputGPUAddress + UInt64(observation.byteOffset),
      observationScalarCount: totalObservationScalars,
      validityGPUAddress: hot.outputGPUAddress + UInt64(validity.byteOffset),
      validityScalarCount: validity.elementCount,
      eventQueueGPUAddress: hot.outputGPUAddress + UInt64(eventQueue.byteOffset),
      eventCapacity: eventCapacity,
      maximumEventCount: profile.eventRules.count
    )
  }

  private func dispatch(
    encoder: any MTL4ComputeCommandEncoder,
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
      threadsPerGrid: MTLSize(width: count, height: 1, depth: 1),
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

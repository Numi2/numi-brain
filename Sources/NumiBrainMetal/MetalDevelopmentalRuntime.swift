import Foundation
@preconcurrency import Metal
import NumiBrainCore

@frozen
public struct MetalDevelopmentalCapabilityEvidenceRecord: Sendable {
  public static let byteCount = 32

  public var code: UInt64
  public var timestampMicroseconds: UInt64
  public var acceptedPhysicsStateFingerprint: UInt64
  public var confidence: Float
  public var flags: UInt32

  public init(_ evidence: DevelopmentalCapabilityEvidence) {
    code = evidence.code
    timestampMicroseconds = evidence.timestamp.rawValue
    acceptedPhysicsStateFingerprint = evidence.acceptedPhysicsStateFingerprint
    confidence = evidence.confidence
    flags = 1
  }
}

@frozen
public struct MetalDevelopmentalEvidenceBufferView: Equatable, Sendable {
  public let gpuAddress: UInt64
  public let evidenceCount: Int
  public let timestamp: BrainTimestamp
  public let acceptedPhysicsStateFingerprint: UInt64

  public init(
    gpuAddress: UInt64,
    evidenceCount: Int,
    timestamp: BrainTimestamp,
    acceptedPhysicsStateFingerprint: UInt64
  ) throws {
    guard gpuAddress > 0, evidenceCount > 0,
      acceptedPhysicsStateFingerprint > 0
    else {
      throw TissueError.transaction("developmental evidence GPU view is invalid")
    }
    self.gpuAddress = gpuAddress
    self.evidenceCount = evidenceCount
    self.timestamp = timestamp
    self.acceptedPhysicsStateFingerprint = acceptedPhysicsStateFingerprint
  }
}

@available(macOS 26.0, *)
public final class MetalDevelopmentalEvidenceBufferLease: @unchecked Sendable {
  public let view: MetalDevelopmentalEvidenceBufferView
  let buffer: any MTLBuffer

  public init(
    buffer: any MTLBuffer,
    byteOffset: Int = 0,
    evidenceCount: Int,
    timestamp: BrainTimestamp,
    acceptedPhysicsStateFingerprint: UInt64
  ) throws {
    let (byteCount, overflow) = evidenceCount.multipliedReportingOverflow(
      by: MetalDevelopmentalCapabilityEvidenceRecord.byteCount
    )
    guard !overflow, byteOffset >= 0, byteOffset <= buffer.length,
      byteCount <= buffer.length - byteOffset
    else {
      throw TissueError.transaction("developmental evidence buffer range is invalid")
    }
    self.view = try MetalDevelopmentalEvidenceBufferView(
      gpuAddress: buffer.gpuAddress + UInt64(byteOffset),
      evidenceCount: evidenceCount,
      timestamp: timestamp,
      acceptedPhysicsStateFingerprint: acceptedPhysicsStateFingerprint
    )
    self.buffer = buffer
  }

  public var metalBufferObject: UnsafeMutableRawPointer {
    Unmanaged.passUnretained(buffer as AnyObject).toOpaque()
  }
}

private struct DevelopmentalUniforms {
  var targetTimestampMicroseconds: UInt64 = 0
  var deltaMicroseconds: UInt64 = 0
  var developmentalStateOffset: UInt64 = 0
  var evidenceStateOffset: UInt64 = 0
  var maturationStateOffset: UInt64 = 0
  var acceptedPhysicsStateFingerprint: UInt64 = 0
  var speciesTemplateFingerprint: UInt64 = 0
  var stageCount: UInt32 = 0
  var capabilityCodeCount: UInt32 = 0
  var evidenceCapacity: UInt32 = 0
  var moduleCount: UInt32 = 0
  var importedEvidenceCount: UInt32 = 0
  var reserved0: UInt32 = 0
  var reserved1: UInt32 = 0
  var reserved2: UInt32 = 0
}

private struct DevelopmentalStageRecord {
  var stage: UInt32 = 0
  var workspaceCapacity: UInt32 = 0
  var planningHorizonSteps: UInt32 = 0
  var capabilityStart: UInt32 = 0
  var capabilityCount: UInt32 = 0
  var reserved0: UInt32 = 0
  var learningRateMultiplier: Float = 0
  var sensorPrecisionMultiplier: Float = 0
  var muscleStrengthMultiplier: Float = 0
  var replayAllocationMultiplier: Float = 0
  var unlockedModuleMaskLow: UInt64 = 0
  var unlockedModuleMaskHigh: UInt64 = 0
  var reserved1: UInt64 = 0
}

/// Capability-gated developmental controller. Immutable species stages and
/// exact evidence codes are GPU resident; only accepted physical consequences
/// may record evidence or advance a stage.
@available(macOS 26.0, *)
public final class MetalDevelopmentalRuntime: @unchecked Sendable {
  public let speciesTemplateFingerprint: UInt64

  private let arena: MetalAgentStateArena
  private let species: SpeciesTemplate
  private let initializePipeline: any MTLComputePipelineState
  private let evidencePipeline: any MTLComputePipelineState
  private let advancePipeline: any MTLComputePipelineState
  private let maturationPipeline: any MTLComputePipelineState
  private let argumentTable: any MTL4ArgumentTable
  private let stageBuffer: any MTLBuffer
  private let capabilityCodeBuffer: any MTLBuffer
  private let moduleIdentifierBuffer: any MTLBuffer
  private let uniformBuffer: any MTLBuffer
  private let dummyEvidenceBuffer: any MTLBuffer
  private let unconditionalAcceptanceGateBuffer: any MTLBuffer
  private let capabilityCodeCount: Int

  public init(
    device: any MTLDevice,
    arena: MetalAgentStateArena,
    species: SpeciesTemplate
  ) throws {
    guard MemoryLayout<MetalDevelopmentalCapabilityEvidenceRecord>.stride == 32,
      MemoryLayout<DevelopmentalUniforms>.stride == 88,
      MemoryLayout<DevelopmentalStageRecord>.stride == 64,
      arena.layout.speciesTemplateFingerprint == species.fingerprint,
      species.enabledModuleIdentifiers.allSatisfy({ $0 <= 128 })
    else {
      throw TissueError.metal("developmental ABI or species binding drift")
    }
    var capabilityCodes: [UInt64] = []
    var stageRecords: [DevelopmentalStageRecord] = []
    for template in species.development {
      guard capabilityCodes.count <= Int(UInt32.max),
        template.capabilityGateCodes.count <= Int(UInt32.max)
      else {
        throw TissueError.metal("developmental capability table exceeds UInt32")
      }
      var low: UInt64 = 0
      var high: UInt64 = 0
      for identifier in template.unlockedModuleIdentifiers {
        let bit = UInt64(identifier - 1)
        if bit < 64 { low |= UInt64(1) << bit }
        else { high |= UInt64(1) << (bit - 64) }
      }
      stageRecords.append(
        DevelopmentalStageRecord(
          stage: UInt32(template.stage.rawValue),
          workspaceCapacity: UInt32(template.workspaceCapacity),
          planningHorizonSteps: UInt32(template.planningHorizonSteps),
          capabilityStart: UInt32(capabilityCodes.count),
          capabilityCount: UInt32(template.capabilityGateCodes.count),
          reserved0: 0,
          learningRateMultiplier: template.learningRateMultiplier,
          sensorPrecisionMultiplier: template.sensorPrecisionMultiplier,
          muscleStrengthMultiplier: template.muscleStrengthMultiplier,
          replayAllocationMultiplier: template.stage == .openEndedLife ? 1 : 0.25,
          unlockedModuleMaskLow: low,
          unlockedModuleMaskHigh: high,
          reserved1: 0
        )
      )
      capabilityCodes.append(contentsOf: template.capabilityGateCodes)
    }
    guard stageRecords.count == DevelopmentalStage.allCases.count,
      capabilityCodes.count
        == arena.layout.section(.developmentalEvidence).elementCount
    else {
      throw TissueError.metal("developmental stage table does not match the hot arena")
    }
    let sourceURL =
      Bundle.module.url(
        forResource: "DevelopmentalState",
        withExtension: "metal",
        subdirectory: "Shaders"
      ) ?? Bundle.module.url(forResource: "DevelopmentalState", withExtension: "metal")
    guard let sourceURL else {
      throw TissueError.metal("DevelopmentalState.metal is missing from resources")
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
      throw TissueError.metal("developmental Metal compilation failed: \(error)")
    }
    let names = [
      "initialize_developmental_state",
      "record_developmental_capability_evidence",
      "advance_developmental_stage_from_capabilities",
      "update_regional_maturation_state",
    ]
    let functions = try names.map { name -> any MTLFunction in
      guard let function = library.makeFunction(name: name) else {
        throw TissueError.metal("\(name) is missing from developmental Metal")
      }
      return function
    }
    let pipelines: [any MTLComputePipelineState]
    do {
      pipelines = try functions.map { try device.makeComputePipelineState(function: $0) }
    } catch {
      throw TissueError.metal("developmental pipeline creation failed: \(error)")
    }
    let descriptor = MTL4ArgumentTableDescriptor()
    descriptor.label = "NumiBrain developmental-state arguments"
    descriptor.maxBufferBindCount = 8
    descriptor.initializeBindings = true
    let stageBytes = stageRecords.count * MemoryLayout<DevelopmentalStageRecord>.stride
    let capabilityBytes = max(
      capabilityCodes.count * MemoryLayout<UInt64>.stride,
      MemoryLayout<UInt64>.stride
    )
    let moduleBytes = species.enabledModuleIdentifiers.count * MemoryLayout<UInt32>.stride
    guard let argumentTable = try? device.makeArgumentTable(descriptor: descriptor),
      let stageBuffer = device.makeBuffer(
        length: stageBytes,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let capabilityCodeBuffer = device.makeBuffer(
        length: capabilityBytes,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let moduleIdentifierBuffer = device.makeBuffer(
        length: moduleBytes,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let uniformBuffer = device.makeBuffer(
        length: MemoryLayout<DevelopmentalUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let dummyEvidenceBuffer = device.makeBuffer(
        length: MetalDevelopmentalCapabilityEvidenceRecord.byteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let unconditionalAcceptanceGateBuffer = device.makeBuffer(
        length: 128,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate developmental-state bindings")
    }
    stageRecords.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      stageBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    capabilityCodes.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      capabilityCodeBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    let moduleIdentifiers = species.enabledModuleIdentifiers.map(UInt32.init)
    moduleIdentifiers.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      moduleIdentifierBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    dummyEvidenceBuffer.contents().initializeMemory(
      as: UInt8.self,
      repeating: 0,
      count: dummyEvidenceBuffer.length
    )
    unconditionalAcceptanceGateBuffer.contents().storeBytes(
      of: UInt32(1), as: UInt32.self
    )
    stageBuffer.label = "NumiBrain immutable developmental stages"
    capabilityCodeBuffer.label = "NumiBrain immutable capability gate codes"
    moduleIdentifierBuffer.label = "NumiBrain developmental module identifiers"
    uniformBuffer.label = "NumiBrain developmental-state uniforms"
    dummyEvidenceBuffer.label = "NumiBrain empty developmental evidence"
    self.speciesTemplateFingerprint = species.fingerprint
    self.arena = arena
    self.species = species
    self.initializePipeline = pipelines[0]
    self.evidencePipeline = pipelines[1]
    self.advancePipeline = pipelines[2]
    self.maturationPipeline = pipelines[3]
    self.argumentTable = argumentTable
    self.stageBuffer = stageBuffer
    self.capabilityCodeBuffer = capabilityCodeBuffer
    self.moduleIdentifierBuffer = moduleIdentifierBuffer
    self.uniformBuffer = uniformBuffer
    self.dummyEvidenceBuffer = dummyEvidenceBuffer
    self.unconditionalAcceptanceGateBuffer = unconditionalAcceptanceGateBuffer
    self.capabilityCodeCount = capabilityCodes.count
  }

  public var residencyAllocations: [any MTLAllocation] {
    [
      stageBuffer, capabilityCodeBuffer, moduleIdentifierBuffer,
      uniformBuffer, dummyEvidenceBuffer, unconditionalAcceptanceGateBuffer,
    ]
  }

  public func encodeCurrentStage(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    timestamp: BrainTimestamp
  ) throws {
    try bind(
      transaction: transaction,
      targetTimestamp: timestamp,
      deltaMicroseconds: 0,
      acceptedPhysicsStateFingerprint: 0,
      evidence: nil
    )
    dispatch(encoder, pipeline: initializePipeline, count: 1)
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: maturationPipeline,
      count: species.enabledModuleIdentifiers.count
    )
  }

  public func encodeAcceptedProgress(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    deltaMicroseconds: UInt64,
    evidence: MetalDevelopmentalEvidenceBufferLease?,
    acceptanceGateGPUAddress: UInt64? = nil,
    acceptanceGateResultGPUAddress: UInt64? = nil
  ) throws {
    if let evidence {
      guard evidence.view.timestamp == acceptedPhysicsState.acceptedTimestamp,
        evidence.view.acceptedPhysicsStateFingerprint
          == acceptedPhysicsState.fingerprint,
        evidence.view.evidenceCount <= capabilityCodeCount
      else {
        throw TissueError.transaction(
          "developmental evidence does not belong to the accepted physical state"
        )
      }
    }
    try bind(
      transaction: transaction,
      targetTimestamp: acceptedPhysicsState.acceptedTimestamp,
      deltaMicroseconds: deltaMicroseconds,
      acceptedPhysicsStateFingerprint: acceptedPhysicsState.fingerprint,
      evidence: evidence,
      acceptanceGateGPUAddress: acceptanceGateGPUAddress,
      acceptanceGateResultGPUAddress: acceptanceGateResultGPUAddress
    )
    dispatch(encoder, pipeline: initializePipeline, count: 1)
    barrier(encoder)
    if let evidence {
      dispatch(
        encoder,
        pipeline: evidencePipeline,
        count: evidence.view.evidenceCount
      )
      barrier(encoder)
    }
    dispatch(encoder, pipeline: advancePipeline, count: 1)
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: maturationPipeline,
      count: species.enabledModuleIdentifiers.count
    )
  }

  func encodeAcceptedProgressAuthoritativeGate(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    targetTimestamp: BrainTimestamp,
    deltaMicroseconds: UInt64,
    acceptanceGateGPUAddress: UInt64,
    acceptanceGateResultGPUAddress: UInt64
  ) throws {
    try bind(
      transaction: transaction,
      targetTimestamp: targetTimestamp,
      deltaMicroseconds: deltaMicroseconds,
      acceptedPhysicsStateFingerprint: 0,
      evidence: nil,
      acceptanceGateGPUAddress: acceptanceGateGPUAddress,
      acceptanceGateResultGPUAddress: acceptanceGateResultGPUAddress
    )
    dispatch(encoder, pipeline: initializePipeline, count: 1)
    barrier(encoder)
    dispatch(encoder, pipeline: advancePipeline, count: 1)
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: maturationPipeline,
      count: species.enabledModuleIdentifiers.count
    )
  }

  private func bind(
    transaction: MetalAgentStateTransactionToken,
    targetTimestamp: BrainTimestamp,
    deltaMicroseconds: UInt64,
    acceptedPhysicsStateFingerprint: UInt64,
    evidence: MetalDevelopmentalEvidenceBufferLease?,
    acceptanceGateGPUAddress: UInt64? = nil,
    acceptanceGateResultGPUAddress: UInt64? = nil
  ) throws {
    let hot = try arena.hotStateView(transaction: transaction)
    var uniforms = DevelopmentalUniforms(
      targetTimestampMicroseconds: targetTimestamp.rawValue,
      deltaMicroseconds: deltaMicroseconds,
      developmentalStateOffset: UInt64(
        arena.layout.section(.developmentalState).byteOffset
      ),
      evidenceStateOffset: UInt64(
        arena.layout.section(.developmentalEvidence).byteOffset
      ),
      maturationStateOffset: UInt64(
        arena.layout.section(.regionalMaturation).byteOffset
      ),
      acceptedPhysicsStateFingerprint: acceptedPhysicsStateFingerprint,
      speciesTemplateFingerprint: species.fingerprint,
      stageCount: UInt32(species.development.count),
      capabilityCodeCount: UInt32(capabilityCodeCount),
      evidenceCapacity: UInt32(
        arena.layout.section(.developmentalEvidence).elementCount
      ),
      moduleCount: UInt32(species.enabledModuleIdentifiers.count),
      importedEvidenceCount: UInt32(evidence?.view.evidenceCount ?? 0),
      reserved0: 0,
      reserved1: 0,
      reserved2: 0
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      uniformBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    argumentTable.setAddress(hot.outputGPUAddress, index: 0)
    argumentTable.setAddress(stageBuffer.gpuAddress, index: 1)
    argumentTable.setAddress(capabilityCodeBuffer.gpuAddress, index: 2)
    argumentTable.setAddress(moduleIdentifierBuffer.gpuAddress, index: 3)
    argumentTable.setAddress(uniformBuffer.gpuAddress, index: 4)
    argumentTable.setAddress(
      evidence?.view.gpuAddress ?? dummyEvidenceBuffer.gpuAddress,
      index: 5
    )
    argumentTable.setAddress(
      acceptanceGateGPUAddress ?? unconditionalAcceptanceGateBuffer.gpuAddress,
      index: 6
    )
    argumentTable.setAddress(
      acceptanceGateResultGPUAddress
        ?? unconditionalAcceptanceGateBuffer.gpuAddress,
      index: 7
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

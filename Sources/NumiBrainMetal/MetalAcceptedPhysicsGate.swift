import Foundation
@preconcurrency import Metal
import NumiBrainABI
import NumiBrainCore

/// Retained device-side proof written by the physical runtime. The 64-byte
/// `NBAcceptedPhysicsStateToken` must remain zero while pending/rejected and is
/// validated in-place on the GPU after the shared-event dependency is met.
///
/// This lease intentionally carries no host copy of the accepted token: the
/// physical-state fingerprint may be produced by an earlier GPU submission.
@available(macOS 26.0, *)
public final class MetalAcceptedPhysicsGateLease: @unchecked Sendable {
  public static let byteCount = Int(NB_ACCEPTED_PHYSICS_STATE_TOKEN_BYTE_COUNT)

  public let byteOffset: Int
  public let gpuAddress: UInt64

  let buffer: any MTLBuffer

  public init(
    buffer: any MTLBuffer,
    byteOffset: Int = 0
  ) throws {
    let (end, overflow) = byteOffset.addingReportingOverflow(Self.byteCount)
    guard byteOffset >= 0, byteOffset.isMultiple(of: 8), !overflow,
      end <= buffer.length, buffer.gpuAddress > 0
    else {
      throw TissueError.transaction(
        "accepted-physics gate does not expose one aligned 64-byte token"
      )
    }
    self.buffer = buffer
    self.byteOffset = byteOffset
    self.gpuAddress = buffer.gpuAddress + UInt64(byteOffset)
  }

  public var metalBufferObject: UnsafeMutableRawPointer {
    Unmanaged.passUnretained(buffer as AnyObject).toOpaque()
  }

  func validate(device: any MTLDevice) throws {
    guard buffer.device.registryID == device.registryID,
      gpuAddress == buffer.gpuAddress + UInt64(byteOffset),
      buffer.length - byteOffset >= Self.byteCount
    else {
      throw TissueError.transaction(
        "accepted-physics gate device, range, or token identity is stale"
      )
    }
  }
}

@available(macOS 26.0, *)
private struct MetalAcceptedPhysicsGateExpectationRecord {
  var transactionFingerprint: UInt64 = 0
  var substepFingerprint: UInt64 = 0
  var acceptedTimestampMicroseconds: UInt64 = 0
  var physicsGeneration: UInt64 = 0
  var environmentIdentifier: UInt32 = 0
  var flags: UInt32 = 0
  var reserved0: UInt64 = 0
  var reserved1: UInt64 = 0
  var reserved2: UInt64 = 0
}

@available(macOS 26.0, *)
private struct MetalAcceptedPhysicsGateResultRecord {
  var version: UInt32 = 0
  var status: UInt32 = 0
  var expectedTransactionFingerprint: UInt64 = 0
  var observedTransactionFingerprint: UInt64 = 0
  var expectedSubstepFingerprint: UInt64 = 0
  var observedSubstepFingerprint: UInt64 = 0
  var computedTokenFingerprint: UInt64 = 0
  var observedTokenFingerprint: UInt64 = 0
  var reserved: UInt64 = 0
  var acceptedToken = NBAcceptedPhysicsStateToken()
}

@available(macOS 26.0, *)
private struct MetalAcceptedPhysicsGateCopyUniforms {
  var wordCount: UInt32
  var reserved0: UInt32 = 0
  var reserved1: UInt32 = 0
  var reserved2: UInt32 = 0
}

@available(macOS 26.0, *)
final class MetalAcceptedPhysicsGateEvaluation: @unchecked Sendable {
  static let version: UInt32 = 1
  static let acceptedStatus: UInt32 = 1
  static let maximumConditionalCopies = 16

  private var retainedLease: MetalAcceptedPhysicsGateLease?
  let transaction: BrainJointTransactionToken
  let substep: BrainJointSubstepToken
  let expectedBuffer: any MTLBuffer
  let resultBuffer: any MTLBuffer
  let copyUniformBuffer: any MTLBuffer
  private var copyCount = 0

  init(
    device: any MTLDevice,
    lease: MetalAcceptedPhysicsGateLease,
    transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken
  ) throws {
    try lease.validate(device: device)
    let (expectedPhysicsGeneration, generationOverflow) =
      transaction.basePhysicsGeneration.addingReportingOverflow(
        UInt64(substep.substepIndex) + 1
      )
    guard !generationOverflow,
      substep.transactionFingerprint == transaction.fingerprint,
      substep.candidateTimestamp == transaction.targetTimestamp,
      substep.shadowGeneration == transaction.shadowGeneration,
      substep.randomCounterGeneration == transaction.randomCounterGeneration,
      MemoryLayout<MetalAcceptedPhysicsGateExpectationRecord>.stride == 64,
      MemoryLayout<MetalAcceptedPhysicsGateResultRecord>.stride == 128,
      MemoryLayout<MetalAcceptedPhysicsGateCopyUniforms>.stride == 16,
      let expectedBuffer = device.makeBuffer(
        length: MemoryLayout<MetalAcceptedPhysicsGateExpectationRecord>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let resultBuffer = device.makeBuffer(
        length: MemoryLayout<MetalAcceptedPhysicsGateResultRecord>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let copyUniformBuffer = device.makeBuffer(
        length: Self.maximumConditionalCopies
          * MemoryLayout<MetalAcceptedPhysicsGateCopyUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate accepted-physics gate state")
    }
    var record = MetalAcceptedPhysicsGateExpectationRecord(
      transactionFingerprint: transaction.fingerprint,
      substepFingerprint: substep.fingerprint,
      acceptedTimestampMicroseconds: substep.candidateTimestamp.rawValue,
      physicsGeneration: expectedPhysicsGeneration,
      environmentIdentifier: transaction.environmentIdentifier,
      flags: 0
    )
    withUnsafeBytes(of: &record) { bytes in
      expectedBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
    resultBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: resultBuffer.length
    )
    copyUniformBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: copyUniformBuffer.length
    )
    expectedBuffer.label = "NumiBrain expected accepted-physics token"
    resultBuffer.label = "NumiBrain accepted-physics GPU gate result"
    copyUniformBuffer.label = "NumiBrain accepted-physics gated-copy uniforms"
    self.retainedLease = lease
    self.transaction = transaction
    self.substep = substep
    self.expectedBuffer = expectedBuffer
    self.resultBuffer = resultBuffer
    self.copyUniformBuffer = copyUniformBuffer
  }

  var residencyAllocations: [any MTLAllocation] {
    guard let retainedLease else {
      return [expectedBuffer, resultBuffer, copyUniformBuffer]
    }
    return [retainedLease.buffer, expectedBuffer, resultBuffer, copyUniformBuffer]
  }

  var lease: MetalAcceptedPhysicsGateLease {
    precondition(retainedLease != nil, "accepted-physics input lease already released")
    return retainedLease!
  }

  func releaseInputLease() {
    retainedLease = nil
  }

  func appendCopy(wordCount: Int) throws -> UInt64 {
    guard wordCount > 0, wordCount <= Int(UInt32.max),
      copyCount < Self.maximumConditionalCopies
    else {
      throw TissueError.metal("accepted-physics gated-copy capacity exceeded")
    }
    let index = copyCount
    copyCount += 1
    var uniforms = MetalAcceptedPhysicsGateCopyUniforms(
      wordCount: UInt32(wordCount)
    )
    let offset = index * MemoryLayout<MetalAcceptedPhysicsGateCopyUniforms>.stride
    withUnsafeBytes(of: &uniforms) { bytes in
      copyUniformBuffer.contents().advanced(by: offset).copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
    return copyUniformBuffer.gpuAddress + UInt64(offset)
  }

  func validateAcceptedResult() throws -> AcceptedPhysicsStateToken {
    let result = resultBuffer.contents().load(
      as: MetalAcceptedPhysicsGateResultRecord.self
    )
    guard result.version == Self.version,
      result.status == Self.acceptedStatus,
      result.expectedTransactionFingerprint == transaction.fingerprint,
      result.observedTransactionFingerprint == transaction.fingerprint,
      result.expectedSubstepFingerprint == substep.fingerprint,
      result.observedSubstepFingerprint == substep.fingerprint,
      result.computedTokenFingerprint != 0,
      result.observedTokenFingerprint == result.computedTokenFingerprint
    else {
      throw TissueError.transaction(
        "GPU accepted-physics gate rejected token "
          + String(format: "%016llx", result.observedTokenFingerprint)
          + " for substep \(substep.fingerprintHex)"
      )
    }
    return try AcceptedPhysicsStateToken(
      validating: result.acceptedToken,
      transaction: transaction,
      substep: substep
    )
  }
}

@available(macOS 26.0, *)
final class MetalAcceptedPhysicsGateRuntime {
  private let validationPipeline: any MTLComputePipelineState
  private let copyPipeline: any MTLComputePipelineState
  private let argumentTable: any MTL4ArgumentTable

  init(device: any MTLDevice) throws {
    guard let sourceURL = Bundle.module.url(
      forResource: "AcceptedPhysicsGate",
      withExtension: "metal",
      subdirectory: "Shaders"
    ) ?? Bundle.module.url(
      forResource: "AcceptedPhysicsGate", withExtension: "metal"
    ) else {
      throw TissueError.metal("AcceptedPhysicsGate.metal is missing")
    }
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    let library: any MTLLibrary
    do {
      library = try device.makeLibrary(source: source, options: nil)
    } catch {
      throw TissueError.metal("accepted-physics gate Metal compilation failed: \(error)")
    }
    guard let validationFunction = library.makeFunction(
      name: "validate_accepted_physics_gate"
    ), let copyFunction = library.makeFunction(
      name: "copy_if_accepted_physics_gate"
    ) else {
      throw TissueError.metal("accepted-physics gate kernels are missing")
    }
    do {
      validationPipeline = try device.makeComputePipelineState(
        function: validationFunction
      )
      copyPipeline = try device.makeComputePipelineState(function: copyFunction)
    } catch {
      throw TissueError.metal("accepted-physics gate pipeline creation failed: \(error)")
    }
    let descriptor = MTL4ArgumentTableDescriptor()
    descriptor.label = "NumiBrain accepted-physics gate arguments"
    descriptor.maxBufferBindCount = 4
    descriptor.initializeBindings = true
    guard let argumentTable = try? device.makeArgumentTable(descriptor: descriptor)
    else {
      throw TissueError.metal("failed to allocate accepted-physics gate arguments")
    }
    self.argumentTable = argumentTable
  }

  func makeEvaluation(
    device: any MTLDevice,
    lease: MetalAcceptedPhysicsGateLease,
    transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken
  ) throws -> MetalAcceptedPhysicsGateEvaluation {
    try MetalAcceptedPhysicsGateEvaluation(
      device: device,
      lease: lease,
      transaction: transaction,
      substep: substep
    )
  }

  func encodeValidation(
    encoder: any MTL4ComputeCommandEncoder,
    evaluation: MetalAcceptedPhysicsGateEvaluation
  ) {
    argumentTable.setAddress(evaluation.lease.gpuAddress, index: 0)
    argumentTable.setAddress(evaluation.expectedBuffer.gpuAddress, index: 1)
    argumentTable.setAddress(evaluation.resultBuffer.gpuAddress, index: 2)
    encoder.setComputePipelineState(validationPipeline)
    encoder.setArgumentTable(argumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
  }

  func encodeConditionalCopy(
    encoder: any MTL4ComputeCommandEncoder,
    evaluation: MetalAcceptedPhysicsGateEvaluation,
    source: any MTLBuffer,
    sourceOffset: Int,
    destination: any MTLBuffer,
    destinationOffset: Int,
    byteCount: Int
  ) throws {
    guard byteCount > 0, byteCount.isMultiple(of: MemoryLayout<UInt32>.stride),
      sourceOffset >= 0, sourceOffset.isMultiple(of: MemoryLayout<UInt32>.stride),
      destinationOffset >= 0,
      destinationOffset.isMultiple(of: MemoryLayout<UInt32>.stride),
      sourceOffset + byteCount <= source.length,
      destinationOffset + byteCount <= destination.length
    else {
      throw TissueError.metal("accepted-physics gated copy range is invalid")
    }
    let wordCount = byteCount / MemoryLayout<UInt32>.stride
    let uniformsAddress = try evaluation.appendCopy(wordCount: wordCount)
    argumentTable.setAddress(source.gpuAddress + UInt64(sourceOffset), index: 0)
    argumentTable.setAddress(
      destination.gpuAddress + UInt64(destinationOffset), index: 1
    )
    argumentTable.setAddress(evaluation.resultBuffer.gpuAddress, index: 2)
    argumentTable.setAddress(uniformsAddress, index: 3)
    encoder.setComputePipelineState(copyPipeline)
    encoder.setArgumentTable(argumentTable)
    let width = min(
      max(copyPipeline.threadExecutionWidth, 1),
      copyPipeline.maxTotalThreadsPerThreadgroup
    )
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: wordCount, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
    )
  }
}

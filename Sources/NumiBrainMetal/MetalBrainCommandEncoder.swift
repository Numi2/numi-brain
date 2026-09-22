@preconcurrency import Metal
import NumiBrainCore

/// Appends the same neural kernels to either Brain's Metal 4 encoder or the
/// native physical owner's ordinary encoder. It never submits or waits.
@available(macOS 26.0, *)
enum MetalBrainCommandEncoder {
  case metal4(any MTL4ComputeCommandEncoder)
  case borrowed(any MTLComputeCommandEncoder, allocations: [any MTLAllocation],
    copyPipeline: (any MTLComputePipelineState)? = nil)

  func bind(argumentTable: any MTL4ArgumentTable, addresses: [UInt64]) throws {
    try bind(argumentTable: argumentTable,
      bindings: Dictionary(uniqueKeysWithValues: addresses.enumerated().map { ($0.offset, $0.element) }))
  }

  func bind(argumentTable: any MTL4ArgumentTable, bindings: [Int: UInt64]) throws {
    switch self {
    case let .metal4(encoder):
      for (index, address) in bindings { argumentTable.setAddress(address, index: index) }
      encoder.setArgumentTable(argumentTable)
    case let .borrowed(encoder, allocations, _):
      let buffers = allocations.compactMap { $0 as? any MTLBuffer }
      // Validate every address before changing the owner's encoder bindings.
      let resolved = try bindings.map { index, address -> (Int, (any MTLBuffer)?, Int) in
        guard index >= 0 else { throw TissueError.transaction("negative borrowed neural buffer slot") }
        if address == 0 { return (index, nil, 0) }
        guard let buffer = buffers.first(where: {
          address >= $0.gpuAddress && address - $0.gpuAddress < UInt64($0.length)
        }), buffer.device.registryID == encoder.device.registryID,
          let offset = Int(exactly: address - buffer.gpuAddress)
        else {
          throw TissueError.transaction("borrowed neural argument has no matching device buffer lease")
        }
        return (index, buffer, offset)
      }
      for (index, buffer, offset) in resolved { encoder.setBuffer(buffer, offset: offset, index: index) }
    }
  }

  func dispatch(pipeline: any MTLComputePipelineState,
    argumentTable: MetalBrainArgumentTable, count: Int) throws {
    try bind(argumentTable: argumentTable.metal4, bindings: argumentTable.bindings)
    dispatch(pipeline: pipeline, argumentTable: argumentTable.metal4, count: count)
  }

  func dispatch(pipeline: any MTLComputePipelineState,
    argumentTable: MetalBrainArgumentTable, threadsPerGrid: MTLSize,
    threadsPerThreadgroup: MTLSize) throws {
    try bind(argumentTable: argumentTable.metal4, bindings: argumentTable.bindings)
    switch self {
    case let .metal4(encoder):
      encoder.setComputePipelineState(pipeline)
      encoder.dispatchThreads(threadsPerGrid: threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    case let .borrowed(encoder, _, _):
      encoder.setComputePipelineState(pipeline)
      encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }
  }

  func dispatch(pipeline: any MTLComputePipelineState,
    argumentTable: any MTL4ArgumentTable, count: Int) {
    let grid = MTLSize(width: count, height: 1, depth: 1)
    let width = min(max(pipeline.threadExecutionWidth, 1), pipeline.maxTotalThreadsPerThreadgroup)
    let group = MTLSize(width: width, height: 1, depth: 1)
    switch self {
    case let .metal4(encoder):
      encoder.setComputePipelineState(pipeline)
      encoder.setArgumentTable(argumentTable)
      encoder.dispatchThreads(threadsPerGrid: grid, threadsPerThreadgroup: group)
    case let .borrowed(encoder, _, _):
      encoder.setComputePipelineState(pipeline)
      encoder.dispatchThreads(grid, threadsPerThreadgroup: group)
    }
  }

  func barrier() {
    switch self {
    case let .metal4(encoder):
      encoder.barrier(afterEncoderStages: [.dispatch, .blit], beforeEncoderStages: [.dispatch, .blit],
        visibilityOptions: .device)
    case let .borrowed(encoder, _, _): encoder.memoryBarrier(scope: .buffers)
    }
  }

  func copy(sourceBuffer: any MTLBuffer, sourceOffset: Int,
    destinationBuffer: any MTLBuffer, destinationOffset: Int, size: Int) throws {
    guard sourceOffset >= 0, destinationOffset >= 0, size >= 0,
      sourceOffset <= sourceBuffer.length, size <= sourceBuffer.length - sourceOffset,
      destinationOffset <= destinationBuffer.length, size <= destinationBuffer.length - destinationOffset
    else { throw TissueError.transaction("borrowed neural copy is outside its retained buffer range") }
    guard size > 0 else { return }
    switch self {
    case let .metal4(encoder):
      encoder.copy(sourceBuffer: sourceBuffer, sourceOffset: sourceOffset,
        destinationBuffer: destinationBuffer, destinationOffset: destinationOffset, size: size)
    case let .borrowed(encoder, allocations, pipeline):
      guard let pipeline,
        pipeline.device.registryID == encoder.device.registryID,
        sourceBuffer.device.registryID == encoder.device.registryID,
        destinationBuffer.device.registryID == encoder.device.registryID,
        allocations.contains(where: { ($0 as AnyObject) === (sourceBuffer as AnyObject) }),
        allocations.contains(where: { ($0 as AnyObject) === (destinationBuffer as AnyObject) }),
        let byteCount = UInt32(exactly: size)
      else { throw TissueError.transaction("borrowed neural copy lacks its pipeline or exact buffer leases") }
      if (sourceBuffer as AnyObject) === (destinationBuffer as AnyObject) {
        guard sourceOffset + size <= destinationOffset || destinationOffset + size <= sourceOffset else {
          throw TissueError.transaction("borrowed neural copy ranges overlap")
        }
      }
      var count = byteCount
      encoder.setComputePipelineState(pipeline)
      encoder.setBuffer(sourceBuffer, offset: sourceOffset, index: 0)
      encoder.setBuffer(destinationBuffer, offset: destinationOffset, index: 1)
      encoder.setBytes(&count, length: MemoryLayout<UInt32>.stride, index: 2)
      encoder.dispatchThreads(MTLSize(width: size, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: pipeline.threadExecutionWidth, height: 1, depth: 1))
    }
  }
}

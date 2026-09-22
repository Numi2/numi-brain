@preconcurrency import Metal
import NumiBrainCore

/// Two bindings for the same muscle kernels. The borrowed form only appends
/// dispatches to the owner's current encoder; it never owns a queue, command
/// buffer, submission, wait, or physical state.
@available(macOS 26.0, *)
enum MetalMuscleCommandEncoder {
  case metal4(any MTL4ComputeCommandEncoder)
  case borrowed(any MTLComputeCommandEncoder, sensors: [MetalRawSensorBufferLease])

  func begin() {
    switch self {
    case let .metal4(encoder):
      encoder.barrier(afterQueueStages: [.dispatch, .blit], beforeStages: .dispatch,
        visibilityOptions: .device)
      encoder.barrier(afterEncoderStages: [.dispatch, .blit], beforeEncoderStages: .dispatch,
        visibilityOptions: .device)
    case let .borrowed(encoder, _):
      encoder.memoryBarrier(scope: .buffers)
    }
  }

  func dispatch(pipeline: any MTLComputePipelineState,
    arguments: any MTL4ArgumentTable, addresses: [UInt64],
    ownedBuffers: [any MTLBuffer], count: Int) throws {
    let grid = MTLSize(width: count, height: 1, depth: 1)
    let group = MTLSize(width: pipeline.threadExecutionWidth, height: 1, depth: 1)
    switch self {
    case let .metal4(encoder):
      for (index, address) in addresses.enumerated() {
        arguments.setAddress(address, index: index)
      }
      encoder.setComputePipelineState(pipeline)
      encoder.setArgumentTable(arguments)
      encoder.dispatchThreads(threadsPerGrid: grid, threadsPerThreadgroup: group)
      encoder.barrier(afterEncoderStages: .dispatch, beforeEncoderStages: .dispatch,
        visibilityOptions: .device)
    case let .borrowed(encoder, sensors):
      guard pipeline.device.registryID == encoder.device.registryID else {
        throw TissueError.transaction("borrowed muscle encoder belongs to a different device")
      }
      let buffers = ownedBuffers + sensors.flatMap { sensor in
        [sensor.buffer] + (sensor.validityBuffer.map { [$0] } ?? [])
      }
      // Resolve every argument before encoding any dispatch. Only exact buffer
      // bases are admitted: current raw leases and all controller arenas expose
      // complete buffers, and arbitrary interior addresses have no size lease.
      let bindings = try addresses.map { address -> any MTLBuffer in
        guard let buffer = buffers.first(where: { $0.gpuAddress == address }),
          buffer.length > 0,
          buffer.device.registryID == encoder.device.registryID
        else {
          throw TissueError.transaction("borrowed muscle argument has no matching device buffer lease")
        }
        return buffer
      }
      encoder.setComputePipelineState(pipeline)
      for (index, buffer) in bindings.enumerated() {
        encoder.setBuffer(buffer, offset: 0, index: index)
      }
      encoder.dispatchThreads(grid, threadsPerThreadgroup: group)
      encoder.memoryBarrier(scope: .buffers)
    }
  }
}

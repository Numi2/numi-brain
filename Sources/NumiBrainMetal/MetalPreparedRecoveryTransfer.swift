import Foundation
@preconcurrency import Metal
import NumiBrainCore

/// Checkpoint-boundary copies only. No new command queue, hot-loop host stepping or early readback.
/// The caller owns exclusive access to the runtime, closes any prior encoder, and commits the supplied
/// command buffer with the SAME options. Cross-queue producers need an owner-supplied event dependency.
@available(macOS 26.0, *)
enum MetalPreparedRecoveryTransfer {
  static func capture(runtime: MetalAgentStateRuntime, transaction: MetalAgentStateTransactionToken,
    root: BrainJointTransactionToken, decision: UInt64, acceptedPhysics: UInt64,
    device: any MTLDevice, commandBuffer: any MTL4CommandBuffer, options: MTL4CommitOptions,
    maximumBytes: Int, completion: @escaping @Sendable (Result<BrainPreparedGPUImage, Error>) -> Void) throws {
    _ = try runtime.arena.prepareCommit(transaction: transaction)
    guard root.baseBrainGeneration == transaction.baseGeneration,
      root.shadowGeneration == transaction.shadowGeneration else {
      throw TissueError.transaction("prepared GPU capture root/generation mismatch")
    }
    let hot = try runtime.arena.hotStateView(transaction: transaction)
    let memory = try runtime.arena.persistentMemoryView(transaction: transaction)
    let sources = try [
      buffer(runtime.arena, address: hot.inputGPUAddress, bytes: hot.byteCount, device: device),
      buffer(runtime.arena, address: hot.outputGPUAddress, bytes: hot.byteCount, device: device),
      buffer(runtime.arena, address: memory.memoryGPUAddress, bytes: memory.memoryByteCount, device: device),
      buffer(runtime.arena, address: memory.journalGPUAddress, bytes: memory.journalByteCount, device: device)
    ]
    try checkBudget(sources.map(\.length), maximumBytes: maximumBytes)
    let staging = try sources.map { source -> any MTLBuffer in
      guard let copy = device.makeBuffer(length: source.length, options: .storageModeShared) else {
        throw TissueError.metal("prepared capture allocation failed")
      }
      return copy
    }
    let resources = try RetainedCopies(device: device, sources: sources, destinations: staging)
    let rootRecord = BrainPreparedRoot(root)
    let hotLayout = runtime.arena.layout.fingerprint
    let memoryLayout = runtime.arena.memoryLayout.fingerprint
    try encode(resources, commandBuffer: commandBuffer)
    options.addFeedbackHandler { feedback in
      // Capturing resources here retains all buffers and their residency until GPU completion.
      let result: Result<BrainPreparedGPUImage, Error>
      if let error = feedback.error { result = .failure(error) }
      else {
        result = Result {
          let data = resources.destinations.map { Data(bytes: $0.contents(), count: $0.length) }
          return try BrainPreparedGPUImage(root: rootRecord, cachedDecisionFingerprint: decision,
            acceptedPhysicsTokenFingerprint: acceptedPhysics, hotLayoutFingerprint: hotLayout,
            memoryLayoutFingerprint: memoryLayout, baseHotState: data[0], shadowHotState: data[1],
            basePersistentMemory: data[2], shadowJournal: data[3], maximumBytes: maximumBytes)
        }
      }
      completion(result)
    }
  }

  static func restoreShadow(image: BrainPreparedGPUImage, runtime: MetalAgentStateRuntime,
    transaction: MetalAgentStateTransactionToken, device: any MTLDevice,
    commandBuffer: any MTL4CommandBuffer, options: MTL4CommitOptions,
    completion: @escaping @Sendable (Result<Void, Error>) -> Void) throws {
    _ = try image.validated()
    guard image.hotLayoutFingerprint == runtime.arena.layout.fingerprint,
      image.memoryLayoutFingerprint == runtime.arena.memoryLayout.fingerprint,
      transaction.baseGeneration == image.root.baseBrainGeneration,
      transaction.shadowGeneration == (try image.root.validatedToken()).shadowGeneration else {
      throw TissueError.transaction("prepared restore layout/generation mismatch")
    }
    let hot = try runtime.arena.hotStateView(transaction: transaction)
    let memory = try runtime.arena.persistentMemoryView(transaction: transaction)
    guard hot.byteCount == image.shadowHotState.count, memory.journalByteCount == image.shadowJournal.count,
      memory.memoryByteCount == image.basePersistentMemory.count else {
      throw TissueError.transaction("prepared restore dimensions differ from compiled native arena")
    }
    let destinations = try [
      buffer(runtime.arena, address: hot.outputGPUAddress, bytes: hot.byteCount, device: device),
      buffer(runtime.arena, address: memory.journalGPUAddress, bytes: memory.journalByteCount, device: device)
    ]
    let staging = try [image.shadowHotState, image.shadowJournal].map { bytes -> any MTLBuffer in
      guard let upload = device.makeBuffer(length: bytes.count, options: .storageModeShared) else {
        throw TissueError.metal("prepared restore staging allocation failed")
      }
      bytes.withUnsafeBytes { raw in
        if let pointer = raw.baseAddress { upload.contents().copyMemory(from: pointer, byteCount: raw.count) }
      }
      return upload
    }
    let resources = try RetainedCopies(device: device, sources: staging, destinations: destinations)
    try encode(resources, commandBuffer: commandBuffer)
    options.addFeedbackHandler { feedback in
      withExtendedLifetime(resources) {
        if let error = feedback.error { completion(.failure(error)) }
        else { completion(.success(())) }
      }
    }
  }

  private static func encode(_ resources: RetainedCopies, commandBuffer: any MTL4CommandBuffer) throws {
    commandBuffer.useResidencySet(resources.residency)
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
      throw TissueError.metal("prepared recovery encoder allocation failed")
    }
    encoder.label = "NumiBrain prepared-generation byte-exact transfer"
    encoder.barrier(afterQueueStages: [.dispatch, .blit], beforeStages: .blit, visibilityOptions: .device)
    for (source, destination) in zip(resources.sources, resources.destinations) {
      encoder.copy(sourceBuffer: source, sourceOffset: 0, destinationBuffer: destination,
        destinationOffset: 0, size: source.length)
    }
    encoder.barrier(afterStages: .blit, beforeQueueStages: [.dispatch, .blit], visibilityOptions: .device)
    encoder.endEncoding()
  }
  private static func buffer(_ arena: MetalAgentStateArena, address: UInt64, bytes: Int,
    device: any MTLDevice) throws -> any MTLBuffer {
    let found = arena.residencyAllocations.compactMap { $0 as? any MTLBuffer }.filter {
      $0.gpuAddress == address && $0.length == bytes && $0.device.registryID == device.registryID
    }
    guard found.count == 1, let value = found.first else {
      throw TissueError.transaction("prepared transfer cannot identify the native allocation")
    }
    return value
  }
  private static func checkBudget(_ sizes: [Int], maximumBytes: Int) throws {
    guard maximumBytes > 0, maximumBytes <= 536_870_912 else { throw TissueError.transaction("prepared recovery budget") }
    var total = 0
    for size in sizes {
      guard size > 0, size <= maximumBytes - total else { throw TissueError.transaction("prepared recovery exceeds byte budget") }
      total += size
    }
  }
  private final class RetainedCopies: @unchecked Sendable {
    let sources: [any MTLBuffer]
    let destinations: [any MTLBuffer]
    let residency: any MTLResidencySet
    init(device: any MTLDevice, sources: [any MTLBuffer], destinations: [any MTLBuffer]) throws {
      guard sources.count == destinations.count,
        zip(sources, destinations).allSatisfy({ $0.length == $1.length }) else {
        throw TissueError.transaction("prepared copy dimension mismatch")
      }
      self.sources = sources; self.destinations = destinations
      let descriptor = MTLResidencySetDescriptor()
      descriptor.label = "NumiBrain prepared recovery retained allocations"
      descriptor.initialCapacity = sources.count + destinations.count
      residency = try device.makeResidencySet(descriptor: descriptor)
      for buffer in sources + destinations { residency.addAllocation(buffer) }
      residency.commit(); residency.requestResidency()
    }
    deinit { residency.endResidency() }
  }
}

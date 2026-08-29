import Foundation
@preconcurrency import Metal
import NumiBrainCore

private struct AgentArenaUniforms {
  var baseGeneration: UInt64 = 0
  var shadowGeneration: UInt64 = 0
  var hotByteCount: UInt64 = 0
  var memoryByteCount: UInt64 = 0
  var journalByteCount: UInt64 = 0
  var archivePageResidencyOffset: UInt64 = 0
  var archivePageRequestOffset: UInt64 = 0
  var journalEntryCapacity: UInt32 = 0
  var applyMutations: UInt32 = 0
  var archivePageCount: UInt32 = 0
  var archivePageRequestCapacity: UInt32 = 0
}

private struct CheckpointCopyUniforms {
  var hotByteCount: UInt64 = 0
  var memoryByteCount: UInt64 = 0
  var journalByteCount: UInt64 = 0
}

private struct MemoryRangeCopyUniforms {
  var byteCount: UInt64 = 0
}

private struct ArchivePageResidencyUniforms {
  var pageCount: UInt32 = 0
  var updateCount: UInt32 = 0
  var residentState: UInt32 = 0
  var clearRequests: UInt32 = 0
}

/// Executes generation seeding and persistent-memory journal application for
/// `MetalAgentStateArena`. All state movement stays device-side; CPU only
/// publishes or discards generation pointers after command completion.
@available(macOS 26.0, *)
public final class MetalAgentStateRuntime: @unchecked Sendable {
  struct PreparedCommit: Equatable, Sendable {
    let arenaCommit: MetalAgentStateArena.PreparedCommit
  }

  struct CheckpointPayload: Equatable, Sendable {
    let generation: UInt64
    let hotState: Data
    let persistentMemory: Data
  }

  struct PersistentSectionSnapshot: @unchecked Sendable {
    let buffer: any MTLBuffer
    let generation: UInt64
    let elementCount: Int
    let elementStride: Int
  }

  public let arena: MetalAgentStateArena

  private let device: any MTLDevice
  private let commandQueue: any MTL4CommandQueue
  private let commandAllocator: any MTL4CommandAllocator
  private let commandBuffer: any MTL4CommandBuffer
  private let initializePipeline: any MTLComputePipelineState
  private let beginPipeline: any MTLComputePipelineState
  private let applyJournalPipeline: any MTLComputePipelineState
  private let checkpointSnapshotPipeline: any MTLComputePipelineState
  private let checkpointRestorePipeline: any MTLComputePipelineState
  private let memoryRangeSnapshotPipeline: any MTLComputePipelineState
  private let archivePageResidencyPipeline: any MTLComputePipelineState
  private let initializeArguments: any MTL4ArgumentTable
  private let beginArguments: any MTL4ArgumentTable
  private let applyJournalArguments: any MTL4ArgumentTable
  private let checkpointSnapshotArguments: any MTL4ArgumentTable
  private let checkpointRestoreArguments: any MTL4ArgumentTable
  private let memoryRangeSnapshotArguments: any MTL4ArgumentTable
  private let archivePageResidencyArguments: any MTL4ArgumentTable
  private let uniformBuffer: any MTLBuffer
  private let checkpointCopyUniformBuffer: any MTLBuffer
  private let memoryRangeCopyUniformBuffer: any MTLBuffer
  private let archivePageResidencyUniformBuffer: any MTLBuffer
  private let residencySet: any MTLResidencySet
  private let lock = NSLock()

  public init(
    device: any MTLDevice,
    species: SpeciesTemplate,
    regionalProgram: RegionalTokenProgram,
    initialGeneration: UInt64 = 0
  ) throws {
    guard MemoryLayout<AgentArenaUniforms>.stride == 72,
      MemoryLayout<CheckpointCopyUniforms>.stride == 24
        && MemoryLayout<MemoryRangeCopyUniforms>.stride == 8
        && MemoryLayout<ArchivePageResidencyUniforms>.stride == 16
    else {
      throw TissueError.metal("agent-state arena uniform ABI drift")
    }
    let arena = try MetalAgentStateArena(
      device: device,
      species: species,
      regionalProgram: regionalProgram,
      initialGeneration: initialGeneration
    )
    guard let commandQueue = device.makeMTL4CommandQueue(),
      let commandAllocator = device.makeCommandAllocator(),
      let commandBuffer = device.makeCommandBuffer(),
      let uniformBuffer = device.makeBuffer(
        length: MemoryLayout<AgentArenaUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let checkpointCopyUniformBuffer = device.makeBuffer(
        length: MemoryLayout<CheckpointCopyUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let memoryRangeCopyUniformBuffer = device.makeBuffer(
        length: MemoryLayout<MemoryRangeCopyUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let archivePageResidencyUniformBuffer = device.makeBuffer(
        length: MemoryLayout<ArchivePageResidencyUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to create agent-state Metal 4 execution objects")
    }
    uniformBuffer.label = "NumiBrain complete agent-state arena uniforms"
    checkpointCopyUniformBuffer.label = "NumiBrain checkpoint copy uniforms"
    memoryRangeCopyUniformBuffer.label = "NumiBrain learner range-copy uniforms"
    archivePageResidencyUniformBuffer.label =
      "NumiBrain archive page-residency uniforms"

    let sourceURL =
      Bundle.module.url(
        forResource: "AgentStateArena",
        withExtension: "metal",
        subdirectory: "Shaders"
      ) ?? Bundle.module.url(forResource: "AgentStateArena", withExtension: "metal")
    guard let sourceURL else {
      throw TissueError.metal("AgentStateArena.metal is missing from package resources")
    }
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    let compileOptions = MTLCompileOptions()
    compileOptions.languageVersion = .version4_0
    compileOptions.mathMode = .safe
    compileOptions.mathFloatingPointFunctions = .precise
    let library: any MTLLibrary
    do {
      library = try device.makeLibrary(source: source, options: compileOptions)
    } catch {
      throw TissueError.metal("agent-state Metal 4 library compilation failed: \(error)")
    }
    guard
      let initializeFunction = library.makeFunction(
        name: "initialize_agent_state_arena"
      ),
      let beginFunction = library.makeFunction(name: "begin_agent_state_shadow"),
      let applyFunction = library.makeFunction(name: "apply_agent_memory_journal"),
      let checkpointSnapshotFunction = library.makeFunction(
        name: "snapshot_agent_checkpoint"
      ),
      let checkpointRestoreFunction = library.makeFunction(
        name: "restore_agent_checkpoint"
      ),
      let memoryRangeSnapshotFunction = library.makeFunction(
        name: "snapshot_agent_memory_range"
      ),
      let archivePageResidencyFunction = library.makeFunction(
        name: "update_archive_page_residency"
      )
    else {
      throw TissueError.metal("agent-state arena kernels are incomplete")
    }
    let initializePipeline: any MTLComputePipelineState
    let beginPipeline: any MTLComputePipelineState
    let applyJournalPipeline: any MTLComputePipelineState
    let checkpointSnapshotPipeline: any MTLComputePipelineState
    let checkpointRestorePipeline: any MTLComputePipelineState
    let memoryRangeSnapshotPipeline: any MTLComputePipelineState
    let archivePageResidencyPipeline: any MTLComputePipelineState
    do {
      initializePipeline = try device.makeComputePipelineState(function: initializeFunction)
      beginPipeline = try device.makeComputePipelineState(function: beginFunction)
      applyJournalPipeline = try device.makeComputePipelineState(function: applyFunction)
      checkpointSnapshotPipeline = try device.makeComputePipelineState(
        function: checkpointSnapshotFunction
      )
      checkpointRestorePipeline = try device.makeComputePipelineState(
        function: checkpointRestoreFunction
      )
      memoryRangeSnapshotPipeline = try device.makeComputePipelineState(
        function: memoryRangeSnapshotFunction
      )
      archivePageResidencyPipeline = try device.makeComputePipelineState(
        function: archivePageResidencyFunction
      )
    } catch {
      throw TissueError.metal("agent-state arena pipeline creation failed: \(error)")
    }

    let initializeArguments = try Self.makeArgumentTable(
      device: device,
      label: "NumiBrain agent-state initialization arguments",
      count: 5
    )
    let beginArguments = try Self.makeArgumentTable(
      device: device,
      label: "NumiBrain agent-state shadow arguments",
      count: 4
    )
    let applyJournalArguments = try Self.makeArgumentTable(
      device: device,
      label: "NumiBrain agent-memory journal arguments",
      count: 3
    )
    let checkpointSnapshotArguments = try Self.makeArgumentTable(
      device: device,
      label: "NumiBrain checkpoint snapshot arguments",
      count: 5
    )
    let checkpointRestoreArguments = try Self.makeArgumentTable(
      device: device,
      label: "NumiBrain checkpoint restore arguments",
      count: 8
    )
    let memoryRangeSnapshotArguments = try Self.makeArgumentTable(
      device: device,
      label: "NumiBrain learner range snapshot arguments",
      count: 3
    )
    let archivePageResidencyArguments = try Self.makeArgumentTable(
      device: device,
      label: "NumiBrain archive page-residency arguments",
      count: 4
    )
    let residencyDescriptor = MTLResidencySetDescriptor()
    residencyDescriptor.label = "NumiBrain complete agent-state residency"
    residencyDescriptor.initialCapacity = arena.residencyAllocations.count + 5
    let residencySet: any MTLResidencySet
    do {
      residencySet = try device.makeResidencySet(descriptor: residencyDescriptor)
    } catch {
      throw TissueError.metal("failed to create agent-state residency set: \(error)")
    }
    for allocation in arena.residencyAllocations {
      residencySet.addAllocation(allocation)
    }
    residencySet.addAllocation(uniformBuffer)
    residencySet.addAllocation(checkpointCopyUniformBuffer)
    residencySet.addAllocation(memoryRangeCopyUniformBuffer)
    residencySet.addAllocation(archivePageResidencyUniformBuffer)
    residencySet.commit()
    residencySet.requestResidency()

    self.arena = arena
    self.device = device
    self.commandQueue = commandQueue
    self.commandAllocator = commandAllocator
    self.commandBuffer = commandBuffer
    self.initializePipeline = initializePipeline
    self.beginPipeline = beginPipeline
    self.applyJournalPipeline = applyJournalPipeline
    self.checkpointSnapshotPipeline = checkpointSnapshotPipeline
    self.checkpointRestorePipeline = checkpointRestorePipeline
    self.memoryRangeSnapshotPipeline = memoryRangeSnapshotPipeline
    self.archivePageResidencyPipeline = archivePageResidencyPipeline
    self.initializeArguments = initializeArguments
    self.beginArguments = beginArguments
    self.applyJournalArguments = applyJournalArguments
    self.checkpointSnapshotArguments = checkpointSnapshotArguments
    self.checkpointRestoreArguments = checkpointRestoreArguments
    self.memoryRangeSnapshotArguments = memoryRangeSnapshotArguments
    self.archivePageResidencyArguments = archivePageResidencyArguments
    self.uniformBuffer = uniformBuffer
    self.checkpointCopyUniformBuffer = checkpointCopyUniformBuffer
    self.memoryRangeCopyUniformBuffer = memoryRangeCopyUniformBuffer
    self.archivePageResidencyUniformBuffer = archivePageResidencyUniformBuffer
    self.residencySet = residencySet

    try writeUniforms(
      baseGeneration: initialGeneration,
      shadowGeneration: initialGeneration,
      applyMutations: false
    )
    let initialization = arena.initializationView
    try submit(label: "NumiBrain initialize complete agent state") { encoder in
      initializeArguments.setAddress(initialization.hot, index: 0)
      initializeArguments.setAddress(initialization.memory, index: 1)
      initializeArguments.setAddress(initialization.journalZero, index: 2)
      initializeArguments.setAddress(initialization.journalOne, index: 3)
      initializeArguments.setAddress(uniformBuffer.gpuAddress, index: 4)
      encoder.setComputePipelineState(initializePipeline)
      encoder.setArgumentTable(initializeArguments)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(width: self.initializationThreadCount, height: 1, depth: 1),
        threadsPerThreadgroup: self.threadgroupSize(for: initializePipeline)
      )
    }
    try arena.markInitialized(generation: initialGeneration)
  }

  deinit { residencySet.endResidency() }

  public func beginShadow(
    expectedBaseGeneration: UInt64
  ) throws -> MetalAgentStateTransactionToken {
    lock.lock()
    defer { lock.unlock() }
    if arena.committedJournalNeedsConsolidation {
      try consolidateCommittedMemoryJournalLocked()
    }
    let transaction = try arena.beginShadow(
      expectedBaseGeneration: expectedBaseGeneration
    )
    do {
      try writeUniforms(
        baseGeneration: transaction.baseGeneration,
        shadowGeneration: transaction.shadowGeneration,
        applyMutations: false
      )
      let hot = try arena.hotStateView(transaction: transaction)
      let memory = try arena.persistentMemoryView(transaction: transaction)
      try submit(label: "NumiBrain seed complete agent shadow") { encoder in
        beginArguments.setAddress(hot.inputGPUAddress, index: 0)
        beginArguments.setAddress(hot.outputGPUAddress, index: 1)
        beginArguments.setAddress(memory.journalGPUAddress, index: 2)
        beginArguments.setAddress(uniformBuffer.gpuAddress, index: 3)
        encoder.setComputePipelineState(beginPipeline)
        encoder.setArgumentTable(beginArguments)
        encoder.dispatchThreads(
          threadsPerGrid: MTLSize(width: self.shadowThreadCount, height: 1, depth: 1),
          threadsPerThreadgroup: self.threadgroupSize(for: beginPipeline)
        )
      }
      return transaction
    } catch {
      try? arena.abort(transaction: transaction)
      throw error
    }
  }

  public func hotStateView(
    transaction: MetalAgentStateTransactionToken
  ) throws -> MetalAgentStateArena.HotStateView {
    try arena.hotStateView(transaction: transaction)
  }

  public func persistentMemoryView(
    transaction: MetalAgentStateTransactionToken
  ) throws -> MetalAgentStateArena.PersistentMemoryView {
    try arena.persistentMemoryView(transaction: transaction)
  }

  /// Applies zero or more mutation chunks previously emitted by GPU memory
  /// modules. The fixed journal header is generation checked in Metal.
  public func validateMemoryJournalAndFinish(
    transaction: MetalAgentStateTransactionToken
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    let memory = try arena.persistentMemoryView(transaction: transaction)
    try writeUniforms(
      baseGeneration: transaction.baseGeneration,
      shadowGeneration: transaction.shadowGeneration,
      applyMutations: false
    )
    try submit(label: "NumiBrain validate individual memory journal") { encoder in
      applyJournalArguments.setAddress(memory.memoryGPUAddress, index: 0)
      applyJournalArguments.setAddress(memory.journalGPUAddress, index: 1)
      applyJournalArguments.setAddress(uniformBuffer.gpuAddress, index: 2)
      encoder.setComputePipelineState(applyJournalPipeline)
      encoder.setArgumentTable(applyJournalArguments)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(width: self.journalEntryCapacity, height: 1, depth: 1),
        threadsPerThreadgroup: self.threadgroupSize(for: applyJournalPipeline)
      )
    }
    try arena.markEncoded(
      transaction: transaction,
      hotStateFullyDefined: true,
      memoryJournalFinalized: true
    )
  }

  public func commit(transaction: MetalAgentStateTransactionToken) throws {
    lock.lock()
    defer { lock.unlock() }
    try arena.commit(transaction: transaction)
  }

  func prepareCommit(
    transaction: MetalAgentStateTransactionToken
  ) throws -> PreparedCommit {
    lock.lock()
    defer { lock.unlock() }
    return PreparedCommit(
      arenaCommit: try arena.prepareCommit(transaction: transaction)
    )
  }

  func publishPreparedCommit(_ prepared: PreparedCommit) {
    lock.lock()
    defer { lock.unlock() }
    arena.publishPreparedCommit(prepared.arenaCommit)
  }

  public func abort(transaction: MetalAgentStateTransactionToken) throws {
    lock.lock()
    defer { lock.unlock() }
    try arena.abort(transaction: transaction)
  }

  func snapshotCommittedState() throws -> CheckpointPayload {
    lock.lock()
    defer { lock.unlock() }
    if arena.committedJournalNeedsConsolidation {
      try consolidateCommittedMemoryJournalLocked()
    }
    let source = try arena.checkpointSourceView()
    guard let hotSnapshot = device.makeBuffer(
      length: source.hotByteCount,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ), let memorySnapshot = device.makeBuffer(
      length: source.memoryByteCount,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ) else {
      throw TissueError.metal("failed to allocate checkpoint snapshot buffers")
    }
    hotSnapshot.label = "NumiBrain committed hot-state checkpoint snapshot"
    memorySnapshot.label = "NumiBrain persistent-memory checkpoint snapshot"
    addTemporaryResidency([hotSnapshot, memorySnapshot])
    defer { removeTemporaryResidency([hotSnapshot, memorySnapshot]) }
    try writeCheckpointCopyUniforms()
    try submit(label: "NumiBrain snapshot committed brain checkpoint") { encoder in
      checkpointSnapshotArguments.setAddress(source.hotGPUAddress, index: 0)
      checkpointSnapshotArguments.setAddress(source.memoryGPUAddress, index: 1)
      checkpointSnapshotArguments.setAddress(hotSnapshot.gpuAddress, index: 2)
      checkpointSnapshotArguments.setAddress(memorySnapshot.gpuAddress, index: 3)
      checkpointSnapshotArguments.setAddress(checkpointCopyUniformBuffer.gpuAddress, index: 4)
      encoder.setComputePipelineState(checkpointSnapshotPipeline)
      encoder.setArgumentTable(checkpointSnapshotArguments)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(width: self.checkpointThreadCount, height: 1, depth: 1),
        threadsPerThreadgroup: self.threadgroupSize(for: checkpointSnapshotPipeline)
      )
    }
    return CheckpointPayload(
      generation: source.generation,
      hotState: Data(bytes: hotSnapshot.contents(), count: source.hotByteCount),
      persistentMemory: Data(
        bytes: memorySnapshot.contents(), count: source.memoryByteCount
      )
    )
  }

  func restoreCommittedState(from payload: CheckpointPayload) throws {
    lock.lock()
    defer { lock.unlock() }
    let destination = try arena.checkpointRestoreView()
    guard payload.hotState.count == destination.hotByteCount,
      payload.persistentMemory.count == destination.memoryByteCount,
      let hotSnapshot = device.makeBuffer(
        length: destination.hotByteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ), let memorySnapshot = device.makeBuffer(
        length: destination.memoryByteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.transaction("checkpoint payload does not fit this brain arena")
    }
    payload.hotState.withUnsafeBytes { bytes in
      if let source = bytes.baseAddress {
        hotSnapshot.contents().copyMemory(
          from: source, byteCount: destination.hotByteCount
        )
      }
    }
    payload.persistentMemory.withUnsafeBytes { bytes in
      if let source = bytes.baseAddress {
        memorySnapshot.contents().copyMemory(
          from: source, byteCount: destination.memoryByteCount
        )
      }
    }
    hotSnapshot.label = "NumiBrain checkpoint hot-state restore source"
    memorySnapshot.label = "NumiBrain checkpoint memory restore source"
    addTemporaryResidency([hotSnapshot, memorySnapshot])
    defer { removeTemporaryResidency([hotSnapshot, memorySnapshot]) }
    try writeCheckpointCopyUniforms()
    try submit(label: "NumiBrain restore committed brain checkpoint") { encoder in
      checkpointRestoreArguments.setAddress(hotSnapshot.gpuAddress, index: 0)
      checkpointRestoreArguments.setAddress(memorySnapshot.gpuAddress, index: 1)
      checkpointRestoreArguments.setAddress(destination.firstHotGPUAddress, index: 2)
      checkpointRestoreArguments.setAddress(destination.secondHotGPUAddress, index: 3)
      checkpointRestoreArguments.setAddress(destination.memoryGPUAddress, index: 4)
      checkpointRestoreArguments.setAddress(destination.firstJournalGPUAddress, index: 5)
      checkpointRestoreArguments.setAddress(destination.secondJournalGPUAddress, index: 6)
      checkpointRestoreArguments.setAddress(
        checkpointCopyUniformBuffer.gpuAddress, index: 7
      )
      encoder.setComputePipelineState(checkpointRestorePipeline)
      encoder.setArgumentTable(checkpointRestoreArguments)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(width: self.checkpointThreadCount, height: 1, depth: 1),
        threadsPerThreadgroup: self.threadgroupSize(for: checkpointRestorePipeline)
      )
    }
    try arena.markCheckpointRestored(generation: payload.generation)
  }

  func snapshotPersistentSection(
    _ section: MetalAgentPersistentSection
  ) throws -> PersistentSectionSnapshot {
    lock.lock()
    defer { lock.unlock() }
    if arena.committedJournalNeedsConsolidation {
      try consolidateCommittedMemoryJournalLocked()
    }
    _ = try arena.checkpointSourceView()
    let layout = arena.memoryLayout.section(section)
    guard layout.byteCount > 0,
      layout.byteCount % MemoryLayout<UInt32>.stride == 0,
      let snapshot = device.makeBuffer(
        length: layout.byteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate persistent-section snapshot")
    }
    snapshot.label = "NumiBrain immutable \(section) learner snapshot"
    addTemporaryResidency([snapshot])
    defer { removeTemporaryResidency([snapshot]) }
    var uniforms = MemoryRangeCopyUniforms(byteCount: UInt64(layout.byteCount))
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      memoryRangeCopyUniformBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    try submit(label: "NumiBrain freeze committed transition cohort") { encoder in
      memoryRangeSnapshotArguments.setAddress(
        arena.persistentSectionAddress(section), index: 0
      )
      memoryRangeSnapshotArguments.setAddress(snapshot.gpuAddress, index: 1)
      memoryRangeSnapshotArguments.setAddress(
        memoryRangeCopyUniformBuffer.gpuAddress, index: 2
      )
      encoder.setComputePipelineState(memoryRangeSnapshotPipeline)
      encoder.setArgumentTable(memoryRangeSnapshotArguments)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(
          width: layout.byteCount / MemoryLayout<UInt32>.stride,
          height: 1,
          depth: 1
        ),
        threadsPerThreadgroup: self.threadgroupSize(
          for: memoryRangeSnapshotPipeline
        )
      )
    }
    return PersistentSectionSnapshot(
      buffer: snapshot,
      generation: arena.committedGeneration,
      elementCount: layout.elementCount,
      elementStride: layout.elementStride
    )
  }

  /// Freezes the compact committed page-request queue for asynchronous archive
  /// orchestration. This synchronization readback is never part of the motor
  /// control path and cannot observe an uncommitted request.
  public func snapshotArchivePageRequests() throws
    -> MetalArchivePageRequestSnapshot
  {
    lock.lock()
    defer { lock.unlock() }
    if arena.committedJournalNeedsConsolidation {
      try consolidateCommittedMemoryJournalLocked()
    }
    _ = try arena.checkpointSourceView()
    let layout = arena.layout.section(.archivePageRequests)
    guard layout.byteCount >= MetalAgentStateLayout.archivePageRequestHeaderByteCount,
      layout.byteCount % MemoryLayout<UInt32>.stride == 0,
      let snapshot = device.makeBuffer(
        length: layout.byteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate archive-request snapshot")
    }
    snapshot.label = "NumiBrain committed archive-page requests"
    addTemporaryResidency([snapshot])
    defer { removeTemporaryResidency([snapshot]) }
    var copyUniforms = MemoryRangeCopyUniforms(byteCount: UInt64(layout.byteCount))
    withUnsafeBytes(of: &copyUniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      memoryRangeCopyUniformBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    let requestGPUAddress = try arena.committedHotSectionAddress(
      .archivePageRequests
    )
    try submit(label: "NumiBrain snapshot archive-page requests") { encoder in
      memoryRangeSnapshotArguments.setAddress(
        requestGPUAddress, index: 0
      )
      memoryRangeSnapshotArguments.setAddress(snapshot.gpuAddress, index: 1)
      memoryRangeSnapshotArguments.setAddress(
        memoryRangeCopyUniformBuffer.gpuAddress, index: 2
      )
      encoder.setComputePipelineState(memoryRangeSnapshotPipeline)
      encoder.setArgumentTable(memoryRangeSnapshotArguments)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(
          width: layout.byteCount / MemoryLayout<UInt32>.stride,
          height: 1,
          depth: 1
        ),
        threadsPerThreadgroup: threadgroupSize(for: memoryRangeSnapshotPipeline)
      )
    }
    let data = Data(bytes: snapshot.contents(), count: layout.byteCount)
    let requestCount = data.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self)
    }
    let encodedCapacity = data.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self)
    }
    let overflowCount = data.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: 8, as: UInt32.self)
    }
    let capacity = min(
      Int(encodedCapacity), MetalAgentStateLayout.archivePageRequestCapacity
    )
    guard capacity > 0,
      layout.byteCount >= MetalAgentStateLayout.archivePageRequestHeaderByteCount
        + capacity * MetalAgentStateLayout.archivePageRequestStride
    else {
      throw TissueError.transaction("archive-page request header is invalid")
    }
    let count = min(Int(requestCount), capacity)
    var requests: [MetalArchivePageRequest] = []
    requests.reserveCapacity(count)
    for index in 0..<count {
      let base = MetalAgentStateLayout.archivePageRequestHeaderByteCount
        + index * MetalAgentStateLayout.archivePageRequestStride
      let pageIdentifier = data.withUnsafeBytes {
        $0.loadUnaligned(fromByteOffset: base, as: UInt32.self)
      }
      let flags = data.withUnsafeBytes {
        $0.loadUnaligned(fromByteOffset: base + 4, as: UInt32.self)
      }
      let timestamp = data.withUnsafeBytes {
        $0.loadUnaligned(fromByteOffset: base + 8, as: UInt64.self)
      }
      let target = data.withUnsafeBytes {
        $0.loadUnaligned(fromByteOffset: base + 16, as: UInt64.self)
      }
      let priority = data.withUnsafeBytes {
        $0.loadUnaligned(fromByteOffset: base + 24, as: Float.self)
      }
      requests.append(
        try MetalArchivePageRequest(
          pageIdentifier: pageIdentifier,
          requestedTimestamp: BrainTimestamp(microseconds: timestamp),
          targetRecordIdentifier: target,
          priority: priority,
          flags: flags
        )
      )
    }
    return try MetalArchivePageRequestSnapshot(
      committedGeneration: arena.committedGeneration,
      pageCount: UInt32(
        arena.layout.section(.archivePageResidency).elementCount
      ),
      overflowCount: overflowCount,
      requests: requests
    )
  }

  /// Exports exact committed Tier-2 page bytes for checkpoint/archive storage.
  /// The copy is an orchestration boundary and never enters the control path.
  public func snapshotArchivePages(
    _ pageIdentifiers: [UInt32]
  ) throws -> [MetalArchivePagePayload] {
    lock.lock()
    defer { lock.unlock() }
    if arena.committedJournalNeedsConsolidation {
      try consolidateCommittedMemoryJournalLocked()
    }
    _ = try arena.checkpointSourceView()
    let archive = arena.memoryLayout.section(.archiveIndex)
    let pageCount = arena.layout.section(.archivePageResidency).elementCount
    guard Set(pageIdentifiers).count == pageIdentifiers.count,
      pageIdentifiers.allSatisfy({ Int($0) < pageCount })
    else {
      throw TissueError.transaction("archive page snapshot selection is invalid")
    }
    var payloads: [MetalArchivePagePayload] = []
    payloads.reserveCapacity(pageIdentifiers.count)
    for pageIdentifier in pageIdentifiers.sorted() {
      let startRecord = Int(pageIdentifier)
        * MetalAgentStateLayout.archiveRecordsPerPage
      let recordCount = min(
        MetalAgentStateLayout.archiveRecordsPerPage,
        archive.elementCount - startRecord
      )
      let byteCount = recordCount * archive.elementStride
      guard recordCount > 0,
        let snapshot = device.makeBuffer(
          length: byteCount,
          options: [.storageModeShared, .hazardTrackingModeTracked]
        )
      else {
        throw TissueError.metal("failed to allocate archive page snapshot")
      }
      snapshot.label = "NumiBrain archive page \(pageIdentifier) snapshot"
      addTemporaryResidency([snapshot])
      defer { removeTemporaryResidency([snapshot]) }
      var uniforms = MemoryRangeCopyUniforms(byteCount: UInt64(byteCount))
      withUnsafeBytes(of: &uniforms) { bytes in
        guard let source = bytes.baseAddress else { return }
        memoryRangeCopyUniformBuffer.contents().copyMemory(
          from: source, byteCount: bytes.count
        )
      }
      let sourceAddress = arena.persistentSectionAddress(.archiveIndex)
        + UInt64(startRecord * archive.elementStride)
      try submit(label: "NumiBrain snapshot archive page \(pageIdentifier)") {
        encoder in
        memoryRangeSnapshotArguments.setAddress(sourceAddress, index: 0)
        memoryRangeSnapshotArguments.setAddress(snapshot.gpuAddress, index: 1)
        memoryRangeSnapshotArguments.setAddress(
          memoryRangeCopyUniformBuffer.gpuAddress, index: 2
        )
        encoder.setComputePipelineState(memoryRangeSnapshotPipeline)
        encoder.setArgumentTable(memoryRangeSnapshotArguments)
        encoder.dispatchThreads(
          threadsPerGrid: MTLSize(
            width: byteCount / MemoryLayout<UInt32>.stride,
            height: 1,
            depth: 1
          ),
          threadsPerThreadgroup: threadgroupSize(
            for: memoryRangeSnapshotPipeline
          )
        )
      }
      payloads.append(
        try MetalArchivePagePayload(
          pageIdentifier: pageIdentifier,
          sourceGeneration: arena.committedGeneration,
          memoryLayoutFingerprint: arena.memoryLayout.fingerprint,
          recordLayoutVersion: MetalAgentMemoryLayout.recordLayoutVersion,
          recordStride: UInt32(archive.elementStride),
          recordCount: UInt32(recordCount),
          bytes: Data(bytes: snapshot.contents(), count: byteCount)
        )
      )
    }
    return payloads
  }

  /// Loads validated archive bytes into the private persistent-memory range and
  /// publishes residency only after each GPU copy completes.
  public func loadArchivePages(
    _ payloads: [MetalArchivePagePayload]
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    if arena.committedJournalNeedsConsolidation {
      try consolidateCommittedMemoryJournalLocked()
    }
    _ = try arena.checkpointSourceView()
    let archive = arena.memoryLayout.section(.archiveIndex)
    let pageCount = arena.layout.section(.archivePageResidency).elementCount
    guard Set(payloads.map(\.pageIdentifier)).count == payloads.count else {
      throw TissueError.transaction("archive page load contains duplicates")
    }
    for payload in payloads {
      let startRecord = Int(payload.pageIdentifier)
        * MetalAgentStateLayout.archiveRecordsPerPage
      let expectedRecordCount = min(
        MetalAgentStateLayout.archiveRecordsPerPage,
        archive.elementCount - startRecord
      )
      guard Int(payload.pageIdentifier) < pageCount,
        expectedRecordCount > 0,
        payload.memoryLayoutFingerprint == arena.memoryLayout.fingerprint,
        payload.recordLayoutVersion == MetalAgentMemoryLayout.recordLayoutVersion,
        payload.recordStride == UInt32(archive.elementStride),
        payload.recordCount == UInt32(expectedRecordCount),
        payload.bytes.count == expectedRecordCount * archive.elementStride,
        payload.validateChecksum()
      else {
        throw TissueError.transaction("archive page payload is incompatible or corrupt")
      }
    }
    for payload in payloads.sorted(by: {
      $0.pageIdentifier < $1.pageIdentifier
    }) {
      guard let upload = device.makeBuffer(
        length: payload.bytes.count,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ) else {
        throw TissueError.metal("failed to allocate archive page upload")
      }
      payload.bytes.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        upload.contents().copyMemory(from: source, byteCount: bytes.count)
      }
      upload.label = "NumiBrain archive page \(payload.pageIdentifier) upload"
      addTemporaryResidency([upload])
      defer { removeTemporaryResidency([upload]) }
      var uniforms = MemoryRangeCopyUniforms(
        byteCount: UInt64(payload.bytes.count)
      )
      withUnsafeBytes(of: &uniforms) { bytes in
        guard let source = bytes.baseAddress else { return }
        memoryRangeCopyUniformBuffer.contents().copyMemory(
          from: source, byteCount: bytes.count
        )
      }
      let startRecord = Int(payload.pageIdentifier)
        * MetalAgentStateLayout.archiveRecordsPerPage
      let destinationAddress = arena.persistentSectionAddress(.archiveIndex)
        + UInt64(startRecord * archive.elementStride)
      try submit(label: "NumiBrain load archive page \(payload.pageIdentifier)") {
        encoder in
        memoryRangeSnapshotArguments.setAddress(upload.gpuAddress, index: 0)
        memoryRangeSnapshotArguments.setAddress(destinationAddress, index: 1)
        memoryRangeSnapshotArguments.setAddress(
          memoryRangeCopyUniformBuffer.gpuAddress, index: 2
        )
        encoder.setComputePipelineState(memoryRangeSnapshotPipeline)
        encoder.setArgumentTable(memoryRangeSnapshotArguments)
        encoder.dispatchThreads(
          threadsPerGrid: MTLSize(
            width: payload.bytes.count / MemoryLayout<UInt32>.stride,
            height: 1,
            depth: 1
          ),
          threadsPerThreadgroup: threadgroupSize(
            for: memoryRangeSnapshotPipeline
          )
        )
      }
    }
    if !payloads.isEmpty {
      try updateArchivePageResidencyLocked(
        payloads.map(\.pageIdentifier).sorted(),
        residentState: 1,
        clearRequests: false
      )
    }
  }

  /// Marks resident archive pages absent between control roots. Retrieval will
  /// request them on demand and defer the corresponding memory result.
  public func evictArchivePages(_ pageIdentifiers: [UInt32]) throws {
    lock.lock()
    defer { lock.unlock() }
    try updateArchivePageResidencyLocked(
      pageIdentifiers,
      residentState: 0,
      clearRequests: false
    )
  }

  /// Resolves one exact request snapshot. Loaded pages become searchable;
  /// deferred pages return to the absent state so a later control may request
  /// them again. Clearing is rejected if another root committed meanwhile.
  public func resolveArchivePageRequests(
    _ snapshot: MetalArchivePageRequestSnapshot,
    residentPageIdentifiers: [UInt32]
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    guard snapshot.committedGeneration == arena.committedGeneration else {
      throw TissueError.transaction("archive-page request snapshot is stale")
    }
    let requested = Set(snapshot.requests.map(\.pageIdentifier))
    let resident = Set(residentPageIdentifiers)
    guard resident.isSubset(of: requested) else {
      throw TissueError.transaction("archive worker resolved an unrequested page")
    }
    let deferred = requested.subtracting(resident)
    if !resident.isEmpty {
      try updateArchivePageResidencyLocked(
        resident.sorted(),
        residentState: 1,
        clearRequests: deferred.isEmpty
      )
    }
    if !deferred.isEmpty || resident.isEmpty {
      try updateArchivePageResidencyLocked(
        deferred.sorted(),
        residentState: 0,
        clearRequests: true
      )
    }
  }

  private func updateArchivePageResidencyLocked(
    _ pageIdentifiers: [UInt32],
    residentState: UInt32,
    clearRequests: Bool
  ) throws {
    if arena.committedJournalNeedsConsolidation {
      try consolidateCommittedMemoryJournalLocked()
    }
    _ = try arena.checkpointSourceView()
    let pageLayout = arena.layout.section(.archivePageResidency)
    guard residentState <= 1,
      Set(pageIdentifiers).count == pageIdentifiers.count,
      pageIdentifiers.allSatisfy({ Int($0) < pageLayout.elementCount }),
      pageIdentifiers.count <= Int(UInt32.max),
      let identifiers = device.makeBuffer(
        length: max(pageIdentifiers.count, 1) * MemoryLayout<UInt32>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.transaction("archive page-residency update is invalid")
    }
    if !pageIdentifiers.isEmpty {
      pageIdentifiers.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        identifiers.contents().copyMemory(from: source, byteCount: bytes.count)
      }
    }
    identifiers.label = "NumiBrain archive page-residency identifiers"
    addTemporaryResidency([identifiers])
    defer { removeTemporaryResidency([identifiers]) }
    var uniforms = ArchivePageResidencyUniforms(
      pageCount: UInt32(pageLayout.elementCount),
      updateCount: UInt32(pageIdentifiers.count),
      residentState: residentState,
      clearRequests: clearRequests ? 1 : 0
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      archivePageResidencyUniformBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    let pageStateGPUAddress = try arena.committedHotSectionAddress(
      .archivePageResidency
    )
    let requestGPUAddress = try arena.committedHotSectionAddress(
      .archivePageRequests
    )
    try submit(label: "NumiBrain update archive page residency") { encoder in
      archivePageResidencyArguments.setAddress(
        pageStateGPUAddress, index: 0
      )
      archivePageResidencyArguments.setAddress(identifiers.gpuAddress, index: 1)
      archivePageResidencyArguments.setAddress(
        requestGPUAddress, index: 2
      )
      archivePageResidencyArguments.setAddress(
        archivePageResidencyUniformBuffer.gpuAddress, index: 3
      )
      encoder.setComputePipelineState(archivePageResidencyPipeline)
      encoder.setArgumentTable(archivePageResidencyArguments)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(
          width: max(pageIdentifiers.count, 1), height: 1, depth: 1
        ),
        threadsPerThreadgroup: threadgroupSize(for: archivePageResidencyPipeline)
      )
    }
  }

  private var journalEntryCapacity: Int {
    max((arena.memoryLayout.journalByteCount - 48) / 64, 1)
  }

  private var initializationThreadCount: Int {
    max(
      max(arena.layout.totalByteCount, arena.memoryLayout.totalByteCount),
      arena.memoryLayout.journalByteCount
    ) / MemoryLayout<UInt32>.stride
  }

  private var shadowThreadCount: Int {
    max(arena.layout.totalByteCount, arena.memoryLayout.journalByteCount)
      / MemoryLayout<UInt32>.stride
  }

  private var checkpointThreadCount: Int {
    max(
      max(arena.layout.totalByteCount, arena.memoryLayout.totalByteCount),
      arena.memoryLayout.journalByteCount
    ) / MemoryLayout<UInt32>.stride
  }

  private func writeUniforms(
    baseGeneration: UInt64,
    shadowGeneration: UInt64,
    applyMutations: Bool
  ) throws {
    guard journalEntryCapacity <= Int(UInt32.max)
    else {
      throw TissueError.metal("agent-state arena exceeds Metal ABI limits")
    }
    var uniforms = AgentArenaUniforms(
      baseGeneration: baseGeneration,
      shadowGeneration: shadowGeneration,
      hotByteCount: UInt64(arena.layout.totalByteCount),
      memoryByteCount: UInt64(arena.memoryLayout.totalByteCount),
      journalByteCount: UInt64(arena.memoryLayout.journalByteCount),
      archivePageResidencyOffset: UInt64(
        arena.layout.section(.archivePageResidency).byteOffset
      ),
      archivePageRequestOffset: UInt64(
        arena.layout.section(.archivePageRequests).byteOffset
      ),
      journalEntryCapacity: UInt32(journalEntryCapacity),
      applyMutations: applyMutations ? 1 : 0,
      archivePageCount: UInt32(
        arena.layout.section(.archivePageResidency).elementCount
      ),
      archivePageRequestCapacity: UInt32(
        MetalAgentStateLayout.archivePageRequestCapacity
      )
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      uniformBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
  }

  private func writeCheckpointCopyUniforms() throws {
    guard arena.layout.totalByteCount % MemoryLayout<UInt32>.stride == 0,
      arena.memoryLayout.totalByteCount % MemoryLayout<UInt32>.stride == 0,
      arena.memoryLayout.journalByteCount % MemoryLayout<UInt32>.stride == 0
    else {
      throw TissueError.metal("checkpoint arena alignment is invalid")
    }
    var uniforms = CheckpointCopyUniforms(
      hotByteCount: UInt64(arena.layout.totalByteCount),
      memoryByteCount: UInt64(arena.memoryLayout.totalByteCount),
      journalByteCount: UInt64(arena.memoryLayout.journalByteCount)
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      checkpointCopyUniformBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
  }

  private func addTemporaryResidency(_ buffers: [any MTLBuffer]) {
    for buffer in buffers { residencySet.addAllocation(buffer) }
    residencySet.commit()
    residencySet.requestResidency()
  }

  private func removeTemporaryResidency(_ buffers: [any MTLBuffer]) {
    for buffer in buffers { residencySet.removeAllocation(buffer) }
    residencySet.commit()
  }

  private func consolidateCommittedMemoryJournalLocked() throws {
    let memory = try arena.committedMemoryJournalView()
    guard memory.generation > 0 else {
      throw TissueError.transaction("generation zero cannot own a committed memory journal")
    }
    try writeUniforms(
      baseGeneration: memory.generation - 1,
      shadowGeneration: memory.generation,
      applyMutations: true
    )
    try submit(label: "NumiBrain consolidate committed individual memory journal") {
      encoder in
      applyJournalArguments.setAddress(memory.memoryGPUAddress, index: 0)
      applyJournalArguments.setAddress(memory.journalGPUAddress, index: 1)
      applyJournalArguments.setAddress(uniformBuffer.gpuAddress, index: 2)
      encoder.setComputePipelineState(applyJournalPipeline)
      encoder.setArgumentTable(applyJournalArguments)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(width: self.journalEntryCapacity, height: 1, depth: 1),
        threadsPerThreadgroup: self.threadgroupSize(for: applyJournalPipeline)
      )
    }
    try arena.markCommittedMemoryJournalConsolidated(generation: memory.generation)
  }

  private func threadgroupSize(
    for pipeline: any MTLComputePipelineState
  ) -> MTLSize {
    MTLSize(
      width: min(max(pipeline.threadExecutionWidth, 1), pipeline.maxTotalThreadsPerThreadgroup),
      height: 1,
      depth: 1
    )
  }

  private func submit(
    label: String,
    encode: (any MTL4ComputeCommandEncoder) -> Void
  ) throws {
    commandAllocator.reset()
    commandBuffer.beginCommandBuffer(allocator: commandAllocator)
    commandBuffer.useResidencySet(residencySet)
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
      commandBuffer.endCommandBuffer()
      throw TissueError.metal("failed to encode \(label)")
    }
    encoder.label = label
    encode(encoder)
    encoder.endEncoding()
    commandBuffer.endCommandBuffer()
    let semaphore = DispatchSemaphore(value: 0)
    final class FeedbackBox: @unchecked Sendable {
      var feedback: (any MTL4CommitFeedback)?
    }
    let feedbackBox = FeedbackBox()
    let options = MTL4CommitOptions()
    options.addFeedbackHandler { feedback in
      feedbackBox.feedback = feedback
      semaphore.signal()
    }
    commandQueue.commit([commandBuffer], options: options)
    semaphore.wait()
    guard let feedback = feedbackBox.feedback else {
      throw TissueError.metal("\(label) completed without Metal feedback")
    }
    if let error = feedback.error {
      throw TissueError.metal("\(label) failed: \(error)")
    }
  }

  private static func makeArgumentTable(
    device: any MTLDevice,
    label: String,
    count: Int
  ) throws -> any MTL4ArgumentTable {
    let descriptor = MTL4ArgumentTableDescriptor()
    descriptor.label = label
    descriptor.maxBufferBindCount = count
    descriptor.initializeBindings = true
    guard let table = try? device.makeArgumentTable(descriptor: descriptor) else {
      throw TissueError.metal("failed to create \(label)")
    }
    return table
  }
}

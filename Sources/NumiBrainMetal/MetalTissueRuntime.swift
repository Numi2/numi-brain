import Foundation
@preconcurrency import Metal
import NumiBrainCore

@available(macOS 26.0, *)
public final class MetalTissueRuntime: @unchecked Sendable {
  public struct Submission: Equatable, Sendable, Codable {
    public let attemptedSubsteps: Int
    public let acceptedSubsteps: Int
    public let gpuStartSeconds: Double
    public let gpuEndSeconds: Double

    public var gpuDurationSeconds: Double {
      max(gpuEndSeconds - gpuStartSeconds, 0)
    }
  }

  public let deviceName: String
  public let width: Int
  public let height: Int
  public let parameters: TissueParameters
  public let stimulus: TissueStimulus
  public let structureHash: String
  public let delayFieldHash: String
  public let connectomeHash: String
  public let eventScheduleHash: String
  public let eventSchedule: TissueEventSchedule
  public let randomContext: TissueRandomContext
  public let historyCapacity = TissueDelayField.historyCapacity
  public let maxEncodedSubsteps: Int
  public private(set) var committedStep: UInt64 = 0

  private let device: any MTLDevice
  private let commandQueue: any MTL4CommandQueue
  private let commandAllocator: any MTL4CommandAllocator
  private let commandBuffer: any MTL4CommandBuffer
  private let pipeline: any MTLComputePipelineState
  private let argumentTable: any MTL4ArgumentTable
  private let residencySet: any MTLResidencySet
  private let stateBuffers: [any MTLBuffer]
  private let structureBuffer: any MTLBuffer
  private let delayBuffer: any MTLBuffer
  private let relayHistoryBuffer: any MTLBuffer
  private let relayScratchBuffer: any MTLBuffer
  private let projectionOffsetBuffer: any MTLBuffer
  private let projectionEdgeBuffer: any MTLBuffer
  private let eventBuffer: any MTLBuffer
  private let uniformBuffer: any MTLBuffer
  private let stagingBuffer: any MTLBuffer
  private let stateByteCount: Int
  private let relayByteCount: Int
  public let relayHistoryByteCount: Int
  public let projectionOffsetByteCount: Int
  public let projectionEdgeByteCount: Int
  public let eventByteCount: Int

  private var committedIndex = 0
  private var committedHistoryOwnerMask: UInt32 = 0
  private var pendingRootShadowIndex: Int?
  private var pendingRootShadowOwnerMask: UInt32?
  private var pendingRootShadowStep: UInt64?

  public init(
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus,
    structure requestedStructure: TissueStructure? = nil,
    delayField requestedDelayField: TissueDelayField? = nil,
    connectome requestedConnectome: TissueConnectome? = nil,
    eventSchedule requestedEventSchedule: TissueEventSchedule? = nil,
    randomContext: TissueRandomContext = .deterministicDefault,
    maxEncodedSubsteps: Int = 4_096,
    device requestedDevice: (any MTLDevice)? = nil
  ) throws {
    try parameters.validate()
    try stimulus.validate()
    let structure: TissueStructure
    if let requestedStructure {
      structure = requestedStructure
    } else {
      structure = try TissueStructure.homogeneous(
        width: initialState.width,
        height: initialState.height
      )
    }
    try structure.validate()
    guard structure.width == initialState.width, structure.height == initialState.height else {
      throw TissueError.invalidStructure("structure dimensions must match the initial state")
    }
    let delayField: TissueDelayField
    if let requestedDelayField {
      delayField = requestedDelayField
    } else {
      delayField = try TissueDelayField.instantaneous(
        width: initialState.width,
        height: initialState.height
      )
    }
    try delayField.validate()
    guard delayField.width == initialState.width, delayField.height == initialState.height else {
      throw TissueError.invalidConduction("delay dimensions must match the initial state")
    }
    let connectome: TissueConnectome
    if let requestedConnectome {
      connectome = requestedConnectome
    } else {
      connectome = try TissueConnectome.none(
        width: initialState.width,
        height: initialState.height
      )
    }
    guard connectome.width == initialState.width, connectome.height == initialState.height else {
      throw TissueError.invalidConnectome("connectome dimensions must match the initial state")
    }
    let eventSchedule =
      try requestedEventSchedule
      ?? TissueEventSchedule.singleStimulus(stimulus)
    guard maxEncodedSubsteps > 0 else {
      throw TissueError.metal("maxEncodedSubsteps must be positive")
    }
    guard let device = requestedDevice ?? MTLCreateSystemDefaultDevice() else {
      throw TissueError.metal("no Metal device is available")
    }
    guard let commandQueue = device.makeMTL4CommandQueue() else {
      throw TissueError.metal("device does not provide a Metal 4 command queue")
    }
    guard let commandAllocator = device.makeCommandAllocator() else {
      throw TissueError.metal("failed to create a Metal 4 command allocator")
    }
    guard let commandBuffer = device.makeCommandBuffer() else {
      throw TissueError.metal("failed to create a reusable Metal 4 command buffer")
    }

    let sourceURL =
      Bundle.module.url(
        forResource: "NeuralTissue",
        withExtension: "metal",
        subdirectory: "Shaders"
      ) ?? Bundle.module.url(forResource: "NeuralTissue", withExtension: "metal")
    guard let sourceURL else {
      throw TissueError.metal("NeuralTissue.metal is missing from package resources")
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
      throw TissueError.metal("Metal 4 library compilation failed: \(error)")
    }
    guard let function = library.makeFunction(name: "neural_tissue_step") else {
      throw TissueError.metal("neural_tissue_step is missing from the Metal library")
    }
    let pipeline: any MTLComputePipelineState
    do {
      pipeline = try device.makeComputePipelineState(function: function)
    } catch {
      throw TissueError.metal("compute pipeline creation failed: \(error)")
    }

    let argumentDescriptor = MTL4ArgumentTableDescriptor()
    argumentDescriptor.label = "NumiBrain tissue arguments"
    argumentDescriptor.maxBufferBindCount = 10
    argumentDescriptor.initializeBindings = true
    guard let argumentTable = try? device.makeArgumentTable(descriptor: argumentDescriptor) else {
      throw TissueError.metal("failed to create the Metal 4 argument table")
    }

    let stateByteCount = initialState.count * MemoryLayout<TissueCell>.stride
    let stateBuffers: [any MTLBuffer] = try (0..<3).map { index in
      guard
        let buffer = device.makeBuffer(
          length: stateByteCount,
          options: [.storageModePrivate, .hazardTrackingModeTracked]
        )
      else {
        throw TissueError.metal("failed to allocate state generation \(index)")
      }
      buffer.label = "NumiBrain tissue state generation \(index)"
      return buffer
    }
    guard
      let structureBuffer = device.makeBuffer(
        length: stateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate the tissue structure field")
    }
    structureBuffer.label = "NumiBrain immutable tissue structure"
    let relayByteCount = initialState.count * MemoryLayout<Float>.stride
    let (historyPlaneByteCount, historyPlaneOverflow) = relayByteCount.multipliedReportingOverflow(
      by: TissueDelayField.historyCapacity
    )
    let (relayHistoryByteCount, relayHistoryOverflow) =
      historyPlaneByteCount
      .multipliedReportingOverflow(by: 2)
    guard !historyPlaneOverflow, !relayHistoryOverflow else {
      throw TissueError.metal("relay history byte count overflows Int")
    }
    guard
      let delayBuffer = device.makeBuffer(
        length: delayField.count * MemoryLayout<UInt8>.stride,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let relayHistoryBuffer = device.makeBuffer(
        length: relayHistoryByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let relayScratchBuffer = device.makeBuffer(
        length: relayByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate private conduction history buffers")
    }
    delayBuffer.label = "NumiBrain immutable conduction delays"
    relayHistoryBuffer.label = "NumiBrain transactional relay history"
    relayScratchBuffer.label = "NumiBrain rejected relay scratch"
    let packedProjectionEdges = connectome.packedEdges()
    let projectionOffsetByteCount =
      connectome.destinationOffsets.count
      * MemoryLayout<UInt32>.stride
    let projectionEdgeByteCount =
      packedProjectionEdges.count
      * MemoryLayout<TissueConnectome.PackedEdge>.stride
    guard
      let projectionOffsetBuffer = device.makeBuffer(
        length: projectionOffsetByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let projectionEdgeBuffer = device.makeBuffer(
        length: max(projectionEdgeByteCount, MemoryLayout<TissueConnectome.PackedEdge>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate private sparse projection buffers")
    }
    projectionOffsetBuffer.label = "NumiBrain projection CSR offsets"
    projectionEdgeBuffer.label = "NumiBrain packed delayed projections"
    let packedEvents = eventSchedule.packedVectors()
    let eventByteCount = eventSchedule.packedByteCount
    guard
      let eventBuffer = device.makeBuffer(
        length: max(eventByteCount, MemoryLayout<TissueEventSchedule.PackedVector>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate the private receptor-event schedule")
    }
    eventBuffer.label = "NumiBrain immutable receptor-event schedule"
    let uniformByteCount = maxEncodedSubsteps * TissueUniforms.byteCount
    guard
      let uniformBuffer = device.makeBuffer(
        length: uniformByteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate the substep uniform arena")
    }
    uniformBuffer.label = "NumiBrain tissue substep uniforms"
    guard
      let stagingBuffer = device.makeBuffer(
        length: max(
          stateByteCount,
          max(
            eventByteCount,
            max(projectionOffsetByteCount, projectionEdgeByteCount)
          )
        ),
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate the explicit upload/inspection buffer")
    }
    stagingBuffer.label = "NumiBrain tissue upload and inspection staging"

    let residencyDescriptor = MTLResidencySetDescriptor()
    residencyDescriptor.label = "NumiBrain tissue residency"
    residencyDescriptor.initialCapacity = stateBuffers.count + 9
    let residencySet: any MTLResidencySet
    do {
      residencySet = try device.makeResidencySet(descriptor: residencyDescriptor)
    } catch {
      throw TissueError.metal("failed to create the residency set: \(error)")
    }
    for buffer in stateBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(structureBuffer)
    residencySet.addAllocation(delayBuffer)
    residencySet.addAllocation(relayHistoryBuffer)
    residencySet.addAllocation(relayScratchBuffer)
    residencySet.addAllocation(projectionOffsetBuffer)
    residencySet.addAllocation(projectionEdgeBuffer)
    residencySet.addAllocation(eventBuffer)
    residencySet.addAllocation(uniformBuffer)
    residencySet.addAllocation(stagingBuffer)
    residencySet.commit()
    residencySet.requestResidency()

    self.device = device
    self.deviceName = device.name
    self.width = initialState.width
    self.height = initialState.height
    self.parameters = parameters
    self.stimulus = stimulus
    self.structureHash = structure.stableHash()
    self.delayFieldHash = delayField.stableHash()
    self.connectomeHash = connectome.stableHash()
    self.eventScheduleHash = eventSchedule.stableHash()
    self.eventSchedule = eventSchedule
    self.randomContext = randomContext
    self.maxEncodedSubsteps = maxEncodedSubsteps
    self.commandQueue = commandQueue
    self.commandAllocator = commandAllocator
    self.commandBuffer = commandBuffer
    self.pipeline = pipeline
    self.argumentTable = argumentTable
    self.residencySet = residencySet
    self.stateBuffers = stateBuffers
    self.structureBuffer = structureBuffer
    self.delayBuffer = delayBuffer
    self.relayHistoryBuffer = relayHistoryBuffer
    self.relayScratchBuffer = relayScratchBuffer
    self.projectionOffsetBuffer = projectionOffsetBuffer
    self.projectionEdgeBuffer = projectionEdgeBuffer
    self.eventBuffer = eventBuffer
    self.uniformBuffer = uniformBuffer
    self.stagingBuffer = stagingBuffer
    self.stateByteCount = stateByteCount
    self.relayByteCount = relayByteCount
    self.relayHistoryByteCount = relayHistoryByteCount
    self.projectionOffsetByteCount = projectionOffsetByteCount
    self.projectionEdgeByteCount = projectionEdgeByteCount
    self.eventByteCount = eventByteCount

    initialState.cells.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: stateByteCount)
    }
    try copy(
      source: stagingBuffer,
      destination: stateBuffers[committedIndex],
      label: "NumiBrain tissue initial upload"
    )
    structure.sites.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: stateByteCount)
    }
    try copy(
      source: stagingBuffer,
      destination: structureBuffer,
      label: "NumiBrain tissue structure upload"
    )
    delayField.delaySteps.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: delayField.count)
    }
    try copy(
      source: stagingBuffer,
      destination: delayBuffer,
      size: delayField.count,
      label: "NumiBrain conduction delay upload"
    )
    let initialRelay = initialState.cells.map(\.w)
    initialRelay.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: relayByteCount)
    }
    try seedRelayHistory()
    connectome.destinationOffsets.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: projectionOffsetByteCount)
    }
    try copy(
      source: stagingBuffer,
      destination: projectionOffsetBuffer,
      size: projectionOffsetByteCount,
      label: "NumiBrain projection offset upload"
    )
    if projectionEdgeByteCount > 0 {
      packedProjectionEdges.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(from: source, byteCount: projectionEdgeByteCount)
      }
      try copy(
        source: stagingBuffer,
        destination: projectionEdgeBuffer,
        size: projectionEdgeByteCount,
        label: "NumiBrain projection edge upload"
      )
    }
    if eventByteCount > 0 {
      packedEvents.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(from: source, byteCount: eventByteCount)
      }
      try copy(
        source: stagingBuffer,
        destination: eventBuffer,
        size: eventByteCount,
        label: "NumiBrain receptor-event upload"
      )
    }
  }

  deinit {
    residencySet.endResidency()
  }

  public var hasPendingRootTransaction: Bool {
    pendingRootShadowIndex != nil
  }

  public var residencyAllocatedBytes: UInt64 {
    residencySet.allocatedSize
  }

  public func runRootTransaction(
    at timeMilliseconds: Float,
    acceptedSubsteps: [Bool]
  ) throws -> Submission {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort the pending Metal root transaction first")
    }
    guard timeMilliseconds.isFinite else {
      throw TissueError.transaction("root time must be finite")
    }
    guard !acceptedSubsteps.isEmpty else {
      throw TissueError.transaction("a root transaction needs at least one candidate substep")
    }
    guard acceptedSubsteps.count <= maxEncodedSubsteps else {
      throw TissueError.transaction(
        "\(acceptedSubsteps.count) attempts exceed the \(maxEncodedSubsteps)-substep uniform arena"
      )
    }
    let acceptedCount = acceptedSubsteps.lazy.filter({ $0 }).count
    guard acceptedCount <= TissueDelayField.historyCapacity else {
      throw TissueError.transaction(
        "a Metal root transaction cannot accept more than \(TissueDelayField.historyCapacity) delayed substeps"
      )
    }

    var rootShadowIndex = committedIndex
    var acceptedTime = timeMilliseconds
    var historyOwnerMask = committedHistoryOwnerMask
    var historyStep = committedStep

    for attempt in acceptedSubsteps.indices {
      let nextHistoryStep = historyStep + 1
      let historyWriteSlot = Int(
        nextHistoryStep % UInt64(TissueDelayField.historyCapacity)
      )
      let currentOwner = (historyOwnerMask >> UInt32(historyWriteSlot)) & 1
      let historyWritePlane: UInt32 =
        acceptedSubsteps[attempt]
        ? currentOwner ^ 1
        : 2
      let values = TissueUniforms.encode(
        width: width,
        height: height,
        timeMilliseconds: acceptedTime,
        parameters: parameters,
        stimulus: stimulus,
        historyStep: UInt32(historyStep % UInt64(TissueDelayField.historyCapacity)),
        historyOwnerMask: historyOwnerMask,
        historyWriteSlot: UInt32(historyWriteSlot),
        historyWritePlane: historyWritePlane,
        eventCount: eventSchedule.eventCount,
        randomContext: randomContext,
        acceptedStep: historyStep
      )
      let destination = destinationIndex(rootShadowIndex: rootShadowIndex)
      writeUniforms(values, attempt: attempt)
      if acceptedSubsteps[attempt] {
        rootShadowIndex = destination
        acceptedTime += parameters.timestepMilliseconds
        historyStep = nextHistoryStep
        historyOwnerMask = settingHistoryOwner(
          mask: historyOwnerMask,
          slot: historyWriteSlot,
          owner: historyWritePlane
        )
      }
    }

    let finalRootShadowIndex = rootShadowIndex
    let finalHistoryOwnerMask = historyOwnerMask
    let finalHistoryStep = historyStep

    rootShadowIndex = committedIndex
    let feedback = try submit(label: "NumiBrain tissue root transaction") { encoder in
      encoder.setComputePipelineState(pipeline)
      for attempt in acceptedSubsteps.indices {
        let destination = destinationIndex(rootShadowIndex: rootShadowIndex)
        argumentTable.setAddress(stateBuffers[rootShadowIndex].gpuAddress, index: 0)
        argumentTable.setAddress(stateBuffers[destination].gpuAddress, index: 1)
        argumentTable.setAddress(
          uniformBuffer.gpuAddress + UInt64(attempt * TissueUniforms.byteCount),
          index: 2
        )
        argumentTable.setAddress(structureBuffer.gpuAddress, index: 3)
        argumentTable.setAddress(delayBuffer.gpuAddress, index: 4)
        argumentTable.setAddress(relayHistoryBuffer.gpuAddress, index: 5)
        argumentTable.setAddress(relayScratchBuffer.gpuAddress, index: 6)
        argumentTable.setAddress(projectionOffsetBuffer.gpuAddress, index: 7)
        argumentTable.setAddress(projectionEdgeBuffer.gpuAddress, index: 8)
        argumentTable.setAddress(eventBuffer.gpuAddress, index: 9)
        encoder.setArgumentTable(argumentTable)
        encoder.dispatchThreads(
          threadsPerGrid: MTLSize(width: width, height: height, depth: 1),
          threadsPerThreadgroup: threadgroupSize()
        )
        if attempt != acceptedSubsteps.indices.last {
          encoder.barrier(
            afterEncoderStages: .dispatch,
            beforeEncoderStages: .dispatch,
            visibilityOptions: .device
          )
        }
        if acceptedSubsteps[attempt] {
          rootShadowIndex = destination
        }
      }
    }
    pendingRootShadowIndex = finalRootShadowIndex
    pendingRootShadowOwnerMask = finalHistoryOwnerMask
    pendingRootShadowStep = finalHistoryStep
    return Submission(
      attemptedSubsteps: acceptedSubsteps.count,
      acceptedSubsteps: acceptedCount,
      gpuStartSeconds: feedback.gpuStartTime,
      gpuEndSeconds: feedback.gpuEndTime
    )
  }

  public func commitRootTransaction() throws {
    guard let pendingRootShadowIndex, let pendingRootShadowOwnerMask,
      let pendingRootShadowStep
    else {
      throw TissueError.transaction("there is no Metal root transaction to commit")
    }
    committedIndex = pendingRootShadowIndex
    committedHistoryOwnerMask = pendingRootShadowOwnerMask
    committedStep = pendingRootShadowStep
    self.pendingRootShadowIndex = nil
    self.pendingRootShadowOwnerMask = nil
    self.pendingRootShadowStep = nil
  }

  public func abortRootTransaction() throws {
    guard pendingRootShadowIndex != nil else {
      throw TissueError.transaction("there is no Metal root transaction to abort")
    }
    pendingRootShadowIndex = nil
    pendingRootShadowOwnerMask = nil
    pendingRootShadowStep = nil
  }

  public func snapshotCommitted() throws -> TissueGrid {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading committed state")
    }
    try copy(
      source: stateBuffers[committedIndex],
      destination: stagingBuffer,
      label: "NumiBrain tissue committed inspection"
    )
    let pointer = stagingBuffer.contents()
      .bindMemory(to: TissueCell.self, capacity: width * height)
    let cells = Array(UnsafeBufferPointer(start: pointer, count: width * height))
    return try TissueGrid(width: width, height: height, cells: cells)
  }

  private func destinationIndex(rootShadowIndex: Int) -> Int {
    (0..<stateBuffers.count).first {
      $0 != committedIndex && $0 != rootShadowIndex
    }!
  }

  private func settingHistoryOwner(
    mask: UInt32,
    slot: Int,
    owner: UInt32
  ) -> UInt32 {
    let bit = UInt32(1) << UInt32(slot)
    return owner == 0 ? mask & ~bit : mask | bit
  }

  private func writeUniforms(_ values: [Float], attempt: Int) {
    let destination = uniformBuffer.contents()
      .advanced(by: attempt * TissueUniforms.byteCount)
    values.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      destination.copyMemory(from: source, byteCount: TissueUniforms.byteCount)
    }
  }

  private struct FeedbackSnapshot {
    let gpuStartTime: Double
    let gpuEndTime: Double
  }

  private func copy(
    source: any MTLBuffer,
    destination: any MTLBuffer,
    size: Int? = nil,
    label: String
  ) throws {
    let size = size ?? stateByteCount
    _ = try submit(label: label) { encoder in
      encoder.copy(
        sourceBuffer: source,
        sourceOffset: 0,
        destinationBuffer: destination,
        destinationOffset: 0,
        size: size
      )
    }
  }

  private func seedRelayHistory() throws {
    _ = try submit(label: "NumiBrain relay history seed") { encoder in
      for plane in 0..<2 {
        for slot in 0..<TissueDelayField.historyCapacity {
          encoder.copy(
            sourceBuffer: stagingBuffer,
            sourceOffset: 0,
            destinationBuffer: relayHistoryBuffer,
            destinationOffset: (plane * TissueDelayField.historyCapacity + slot)
              * relayByteCount,
            size: relayByteCount
          )
        }
      }
    }
  }

  private func submit(
    label: String,
    encode: (any MTL4ComputeCommandEncoder) -> Void
  ) throws -> FeedbackSnapshot {
    commandAllocator.reset()
    commandBuffer.beginCommandBuffer(allocator: commandAllocator)
    commandBuffer.useResidencySet(residencySet)
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
      commandBuffer.endCommandBuffer()
      throw TissueError.metal("failed to create a Metal 4 compute command encoder")
    }
    encoder.label = label
    encode(encoder)
    encoder.endEncoding()
    commandBuffer.endCommandBuffer()

    let semaphore = DispatchSemaphore(value: 0)
    let options = MTL4CommitOptions()
    final class FeedbackBox: @unchecked Sendable {
      var feedback: (any MTL4CommitFeedback)?
    }
    let box = FeedbackBox()
    options.addFeedbackHandler { feedback in
      box.feedback = feedback
      semaphore.signal()
    }
    commandQueue.commit([commandBuffer], options: options)
    semaphore.wait()
    guard let feedback = box.feedback else {
      throw TissueError.metal("Metal 4 submission completed without feedback")
    }
    if let error = feedback.error {
      throw TissueError.metal("GPU execution failed during \(label): \(error)")
    }
    return FeedbackSnapshot(
      gpuStartTime: feedback.gpuStartTime,
      gpuEndTime: feedback.gpuEndTime
    )
  }

  private func threadgroupSize() -> MTLSize {
    let width = min(16, pipeline.threadExecutionWidth)
    let height = max(1, min(16, pipeline.maxTotalThreadsPerThreadgroup / width))
    return MTLSize(width: width, height: height, depth: 1)
  }
}

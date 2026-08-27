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
  public let maxEncodedSubsteps: Int

  private let device: any MTLDevice
  private let commandQueue: any MTL4CommandQueue
  private let commandAllocator: any MTL4CommandAllocator
  private let commandBuffer: any MTL4CommandBuffer
  private let pipeline: any MTLComputePipelineState
  private let argumentTable: any MTL4ArgumentTable
  private let residencySet: any MTLResidencySet
  private let stateBuffers: [any MTLBuffer]
  private let structureBuffer: any MTLBuffer
  private let uniformBuffer: any MTLBuffer
  private let stagingBuffer: any MTLBuffer
  private let stateByteCount: Int

  private var committedIndex = 0
  private var pendingRootShadowIndex: Int?

  public init(
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus,
    structure requestedStructure: TissueStructure? = nil,
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
    argumentDescriptor.maxBufferBindCount = 4
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
        length: stateByteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate the explicit upload/inspection buffer")
    }
    stagingBuffer.label = "NumiBrain tissue upload and inspection staging"

    let residencyDescriptor = MTLResidencySetDescriptor()
    residencyDescriptor.label = "NumiBrain tissue residency"
    residencyDescriptor.initialCapacity = stateBuffers.count + 3
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
    self.maxEncodedSubsteps = maxEncodedSubsteps
    self.commandQueue = commandQueue
    self.commandAllocator = commandAllocator
    self.commandBuffer = commandBuffer
    self.pipeline = pipeline
    self.argumentTable = argumentTable
    self.residencySet = residencySet
    self.stateBuffers = stateBuffers
    self.structureBuffer = structureBuffer
    self.uniformBuffer = uniformBuffer
    self.stagingBuffer = stagingBuffer
    self.stateByteCount = stateByteCount

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

    var rootShadowIndex = committedIndex
    var acceptedCount = 0
    var acceptedTime = timeMilliseconds

    for attempt in acceptedSubsteps.indices {
      let values = TissueUniforms.encode(
        width: width,
        height: height,
        timeMilliseconds: acceptedTime,
        parameters: parameters,
        stimulus: stimulus
      )
      let destination = destinationIndex(rootShadowIndex: rootShadowIndex)
      writeUniforms(values, attempt: attempt)
      if acceptedSubsteps[attempt] {
        rootShadowIndex = destination
        acceptedCount += 1
        acceptedTime += parameters.timestepMilliseconds
      }
    }

    rootShadowIndex = committedIndex
    acceptedCount = 0
    acceptedTime = timeMilliseconds
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
          acceptedCount += 1
          acceptedTime += parameters.timestepMilliseconds
        }
      }
    }
    pendingRootShadowIndex = rootShadowIndex
    return Submission(
      attemptedSubsteps: acceptedSubsteps.count,
      acceptedSubsteps: acceptedCount,
      gpuStartSeconds: feedback.gpuStartTime,
      gpuEndSeconds: feedback.gpuEndTime
    )
  }

  public func commitRootTransaction() throws {
    guard let pendingRootShadowIndex else {
      throw TissueError.transaction("there is no Metal root transaction to commit")
    }
    committedIndex = pendingRootShadowIndex
    self.pendingRootShadowIndex = nil
  }

  public func abortRootTransaction() throws {
    guard pendingRootShadowIndex != nil else {
      throw TissueError.transaction("there is no Metal root transaction to abort")
    }
    pendingRootShadowIndex = nil
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
    label: String
  ) throws {
    _ = try submit(label: label) { encoder in
      encoder.copy(
        sourceBuffer: source,
        sourceOffset: 0,
        destinationBuffer: destination,
        destinationOffset: 0,
        size: stateByteCount
      )
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

import Foundation
@preconcurrency import Metal
import NumiBrainCore
import NumiBrainConnectomeABI

/// Immutable graph allocation and pipelines shared by independent robot minds.
/// No private command queue, submission loop, or neural-state readback.
@available(macOS 26.0, *)
public final class MetalConnectomeGraph: @unchecked Sendable {
  public let graph: ConnectomeGraph
  public let device: any MTLDevice
  let buffer: any MTLBuffer
  let stepPipeline: any MTLComputePipelineState
  let readoutPipeline: any MTLComputePipelineState
  public init(graph: ConnectomeGraph, device: any MTLDevice,
    maximumResidentBytes: Int = 1_073_741_824) throws {
    guard graph.bytes.count <= maximumResidentBytes,
      graph.bytes.count <= device.maxBufferLength,
      let buffer = graph.bytes.withUnsafeBytes({ bytes in
        device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
      }), let url = Bundle.module.url(forResource: "ConnectomeRate", withExtension: "metal", subdirectory: "Shaders")
        ?? Bundle.module.url(forResource: "ConnectomeRate", withExtension: "metal") else {
      throw ConnectomeError.invalid("graph allocation budget or Metal shader resource is unavailable")
    }
    let options = MTLCompileOptions()
    options.mathMode = .safe
    let library = try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: options)
    guard let step = library.makeFunction(name: "nb_connectome_rate_step"),
      let readout = library.makeFunction(name: "nb_connectome_descending_readout") else {
      throw ConnectomeError.invalid("connectome kernels are missing")
    }
    self.graph = graph; self.device = device; self.buffer = buffer
    stepPipeline = try device.makeComputePipelineState(function: step)
    readoutPipeline = try device.makeComputePipelineState(function: readout)
    buffer.label = "NumiBrain immutable NUMICNS1 graph"
  }
}

@available(macOS 26.0, *)
public final class MetalConnectomeRuntime: @unchecked Sendable {
  public struct DescendingView: Sendable {
    public let transactionFingerprint: UInt64
    public let bindingFingerprint: UInt64
    public let timestamp: BrainTimestamp
    public let gpuAddress: UInt64
    public let channelCount: Int
  }
  // Only MetalJointAgentStateTransaction may publish this participant.
  final class Candidate: @unchecked Sendable {
    let owner: MetalConnectomeRuntime
    let root: BrainJointTransactionToken
    let stateIndex: Int
    let view: DescendingView
    init(owner: MetalConnectomeRuntime, root: BrainJointTransactionToken, stateIndex: Int) {
      self.owner = owner; self.root = root; self.stateIndex = stateIndex
      view = DescendingView(transactionFingerprint: root.fingerprint,
        bindingFingerprint: owner.binding.fingerprint, timestamp: root.targetTimestamp,
        gpuAddress: owner.output.gpuAddress, channelCount: Int(owner.binding.channelCount))
    }
    func snapshotPrepared() throws -> ConnectomePreparedState {
      owner.lock.lock(); defer { owner.lock.unlock() }
      guard owner.pendingRoot == root.fingerprint else { throw ConnectomeError.invalid("stale prepared neural root") }
      return try ConnectomePreparedState(
        base: owner.snapshotLocked(index: owner.committedIndex, generation: root.baseBrainGeneration,
          timestamp: root.committedTimestamp.rawValue),
        candidate: owner.snapshotLocked(index: stateIndex, generation: root.shadowGeneration,
          timestamp: root.targetTimestamp.rawValue),
        descending: Data(bytes: owner.output.contents(), count: owner.output.length), root: root)
    }
    func validateCommit(_ receipt: BrainJointCommitToken) throws {
      guard receipt.transactionFingerprint == root.fingerprint,
        receipt.brainGeneration == root.shadowGeneration,
        receipt.committedTimestamp == root.targetTimestamp,
        receipt.parameterVersionFingerprint == owner.binding.parameterVersionFingerprint else {
        throw ConnectomeError.invalid("connectome candidate does not match joint commit")
      }
      owner.lock.lock(); defer { owner.lock.unlock() }
      guard owner.pendingRoot == root.fingerprint else {
        throw ConnectomeError.invalid("connectome candidate is stale")
      }
    }
    func publish() {
      owner.lock.lock(); defer { owner.lock.unlock() }
      precondition(owner.pendingRoot == root.fingerprint)
      owner.committedIndex = stateIndex; owner.generation = root.shadowGeneration
      owner.timestamp = root.targetTimestamp; owner.pendingRoot = nil
    }
    func abort() {
      owner.lock.lock(); defer { owner.lock.unlock() }
      if owner.pendingRoot == root.fingerprint { owner.pendingRoot = nil }
    }
  }

  public let sharedGraph: MetalConnectomeGraph
  public let binding: ConnectomeBinding
  public let topologyFingerprint: UInt64
  public let programFingerprint: UInt64
  public let environmentIdentifier: UInt32
  public let episodeIdentifier: UInt64
  public let maximumSubsteps: Int
  private let lock = NSLock()
  private var generation: UInt64
  private var timestamp: BrainTimestamp
  private var committedIndex = 0
  private var pendingRoot: UInt64?
  // A fresh zero-state model establishes its origin at its first owning root.
  // Checkpoint restoration establishes the saved origin instead.
  private var originEstablished = false
  private let states: [any MTLBuffer]
  private let output: any MTLBuffer
  private let inputOffsets: any MTLBuffer
  private let inputBindings: any MTLBuffer
  private let readoutOffsets: any MTLBuffer
  private let readouts: any MTLBuffer
  private let uniforms: any MTLBuffer
  private let arguments: any MTL4ArgumentTable
  public var committedGeneration: UInt64 { lock.withLock { generation } }
  public var committedTimestamp: BrainTimestamp { lock.withLock { timestamp } }

  public init(sharedGraph: MetalConnectomeGraph, binding: ConnectomeBinding,
    template: CompiledSpeciesTemplate, environmentIdentifier: UInt32,
    episodeIdentifier: UInt64, initialGeneration: UInt64 = 0,
    initialTimestamp: BrainTimestamp = BrainTimestamp(microseconds: 0),
    maximumSubsteps: Int = 256, maximumStateBytes: Int = 67_108_864,
    topologyFingerprint: UInt64? = nil, programFingerprint: UInt64? = nil) throws {
    guard initialGeneration == 0, initialTimestamp.rawValue == 0,
      (topologyFingerprint == nil) == (programFingerprint == nil),
      topologyFingerprint == nil || (topologyFingerprint! != 0 && programFingerprint! != 0),
      binding.graphFingerprint == sharedGraph.graph.fingerprint,
      binding.speciesFingerprint == template.species.fingerprint,
      binding.sensoryProfileFingerprint == template.sensoryProfile.fingerprint,
      (1...4096).contains(maximumSubsteps), MemoryLayout<NBConnectomeDispatch>.stride == 48 else {
      throw ConnectomeError.invalid("connectome runtime does not match its compiled body")
    }
    let senses = template.species.senses.filter(\.enabled)
    var scalarCount: UInt64 = 0, receptorCount: UInt64 = 0
    for sense in senses {
      let count = UInt64(sense.receptorCount)*UInt64(sense.observationDimension)
      guard count <= UInt64(UInt32.max), scalarCount <= UInt64(UInt32.max)-count,
        receptorCount <= UInt64(UInt32.max)-UInt64(sense.receptorCount) else {
        throw ConnectomeError.invalid("native receptor layout exceeds index capacity")
      }
      scalarCount += count; receptorCount += UInt64(sense.receptorCount)
    }
    guard scalarCount == UInt64(binding.scalarCount), receptorCount == UInt64(binding.receptorCount) else {
      throw ConnectomeError.invalid("binding does not match the native receptor layout")
    }
    let n = sharedGraph.graph.nodeCount
    let stateBytes = n*4*3 + Int(binding.channelCount)*4 + (n+1)*4
      + binding.inputs.count*32 + binding.readouts.count*16
      + (Int(binding.channelCount)+1)*4 + maximumSubsteps*64
    guard stateBytes <= maximumStateBytes else { throw ConnectomeError.invalid("independent mind exceeds its byte budget") }
    let device = sharedGraph.device
    func zero(_ size: Int) throws -> any MTLBuffer {
      guard size > 0, size <= device.maxBufferLength,
        let b = device.makeBuffer(length: size, options: .storageModeShared) else {
        throw ConnectomeError.invalid("neural state allocation failed")
      }
      b.contents().initializeMemory(as: UInt8.self, repeating: 0, count: size)
      return b
    }
    func upload<T>(_ values: [T]) throws -> any MTLBuffer {
      let b = try zero(values.count*MemoryLayout<T>.stride)
      values.withUnsafeBytes { b.contents().copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
      return b
    }
    states = try [zero(n*4), zero(n*4), zero(n*4)]
    output = try zero(Int(binding.channelCount)*4)
    inputOffsets = try upload(binding.inputOffsets); inputBindings = try upload(binding.inputs)
    readoutOffsets = try upload(binding.readoutOffsets); readouts = try upload(binding.readouts)
    uniforms = try zero(maximumSubsteps*64)
    let descriptor = MTL4ArgumentTableDescriptor()
    descriptor.maxBufferBindCount = 11; descriptor.initializeBindings = true
    arguments = try device.makeArgumentTable(descriptor: descriptor)
    self.sharedGraph = sharedGraph; self.binding = binding
    self.topologyFingerprint = topologyFingerprint ?? binding.fingerprint
    self.programFingerprint = programFingerprint ?? binding.fingerprint
    self.environmentIdentifier = environmentIdentifier; self.episodeIdentifier = episodeIdentifier
    self.maximumSubsteps = maximumSubsteps; generation = initialGeneration; timestamp = initialTimestamp
  }

  /// Add these to the OWNER's residency set before submitting its command
  /// buffer. Sensor-arena residency remains owned by the cognitive root.
  public var residencyAllocations: [any MTLAllocation] {
    [sharedGraph.buffer, output, inputOffsets, inputBindings, readoutOffsets, readouts, uniforms] + states
  }

  /// Cold checkpoint boundary only. The owning cognitive runtime has drained
  /// its queue before entry. No hot-loop state readback is introduced.
  func snapshotCommitted() throws -> ConnectomeCheckpoint {
    lock.lock(); defer { lock.unlock() }
    guard pendingRoot == nil else { throw ConnectomeError.invalid("neural checkpoint requires a closed root") }
    return try snapshotLocked(index: committedIndex, generation: generation, timestamp: timestamp.rawValue)
  }

  private func snapshotLocked(index: Int, generation: UInt64, timestamp: UInt64) throws -> ConnectomeCheckpoint {
    try ConnectomeCheckpoint(graphFingerprint: sharedGraph.graph.fingerprint,
      topologyFingerprint: topologyFingerprint, programFingerprint: programFingerprint,
      parameterVersionFingerprint: binding.parameterVersionFingerprint,
      environmentIdentifier: environmentIdentifier, episodeIdentifier: episodeIdentifier,
      generation: generation, timestampMicroseconds: timestamp,
      activity: Data(bytes: states[index].contents(), count: states[index].length))
  }

  func validateCheckpoint(_ checkpoint: ConnectomeCheckpoint) throws {
    try checkpoint.validate()
    guard checkpoint.graphFingerprint == sharedGraph.graph.fingerprint,
      checkpoint.topologyFingerprint == topologyFingerprint,
      checkpoint.programFingerprint == programFingerprint,
      checkpoint.parameterVersionFingerprint == binding.parameterVersionFingerprint,
      checkpoint.environmentIdentifier == environmentIdentifier,
      checkpoint.episodeIdentifier == episodeIdentifier,
      checkpoint.activity.count == states[0].length else {
      throw ConnectomeError.invalid("neural checkpoint does not match this graph, body, decoder and parameter version")
    }
  }

  /// Restores into an exclusively owned, unpublished controller. The handle
  /// swaps it into service only after all cognitive, fast and neural restores.
  func restoreCommitted(_ checkpoint: ConnectomeCheckpoint) throws {
    lock.lock(); defer { lock.unlock() }
    guard pendingRoot == nil else { throw ConnectomeError.invalid("cannot restore an active neural root") }
    try validateCheckpoint(checkpoint)
    for state in states { checkpoint.activity.withUnsafeBytes {
      state.contents().copyMemory(from: $0.baseAddress!, byteCount: $0.count)
    }}
    output.contents().initializeMemory(as: UInt8.self, repeating: 0, count: output.length)
    committedIndex = 0; generation = checkpoint.generation
    timestamp = BrainTimestamp(microseconds: checkpoint.timestampMicroseconds)
    originEstablished = true
  }

  func validatePrepared(_ image: ConnectomePreparedState, root: BrainJointTransactionToken) throws {
    try image.validate(root: root); try validateCheckpoint(image.base); try validateCheckpoint(image.candidate)
    guard image.descending.count == output.length else { throw ConnectomeError.invalid("prepared descending shape mismatch") }
    lock.lock(); defer { lock.unlock() }
    guard pendingRoot == nil else { throw ConnectomeError.invalid("prepared restore requires an idle neural participant") }
  }

  func restorePrepared(_ image: ConnectomePreparedState, root: BrainJointTransactionToken) throws -> Candidate {
    try validatePrepared(image, root: root)
    try restoreCommitted(image.base)
    lock.lock(); defer { lock.unlock() }
    image.candidate.activity.withUnsafeBytes {
      states[1].contents().copyMemory(from: $0.baseAddress!, byteCount: $0.count)
    }
    image.descending.withUnsafeBytes {
      output.contents().copyMemory(from: $0.baseAddress!, byteCount: $0.count)
    }
    pendingRoot = root.fingerprint
    return Candidate(owner: self, root: root, stateIndex: 1)
  }

  func encodeCandidate(encoder: any MTL4ComputeCommandEncoder,
    root: BrainJointTransactionToken, sensory: MetalSensoryTransductionRuntime.Result) throws -> Candidate {
    lock.lock(); defer { lock.unlock() }
    guard pendingRoot == nil, root.environmentIdentifier == environmentIdentifier,
      root.episodeIdentifier == episodeIdentifier, root.baseBrainGeneration == generation,
      (originEstablished ? root.committedTimestamp == timestamp : generation == 0),
      root.targetTimestamp > root.committedTimestamp,
      root.parameterVersionFingerprint == binding.parameterVersionFingerprint,
      sensory.timestamp == root.committedTimestamp, sensory.observationScalarCount == Int(binding.scalarCount),
      sensory.validityScalarCount == Int(binding.scalarCount),
      sensory.observationGPUAddress != 0, sensory.validityGPUAddress != 0,
      sensory.observationGPUAddress % 4 == 0, sensory.validityGPUAddress % 4 == 0 else {
      throw ConnectomeError.invalid("candidate requires this mind's exact root and accepted O(t) receptor frame")
    }
    let duration = root.targetTimestamp.rawValue - root.committedTimestamp.rawValue
    let step = UInt64(binding.integrationStepMicroseconds)
    let count = duration/step + (duration%step == 0 ? 0 : 1)
    guard count <= UInt64(maximumSubsteps) else { throw ConnectomeError.invalid("neural substep capacity exceeded") }
    // All fallible validation precedes initial-origin establishment and encoding.
    if !originEstablished { timestamp = root.committedTimestamp; originEstablished = true }
    let slots = states.indices.filter { $0 != committedIndex }
    let graph = sharedGraph.graph.view
    func address(_ offset: UInt64) -> UInt64 { sharedGraph.buffer.gpuAddress + offset }
    func barrier() {
      encoder.barrier(afterEncoderStages: [.dispatch, .blit], beforeEncoderStages: .dispatch, visibilityOptions: .device)
    }
    // The caller retains a single queue timeline. Resolve previous-pass and
    // same-pass writes of the accepted sensor arena before consuming O(t).
    encoder.barrier(afterQueueStages: [.dispatch, .blit], beforeStages: .dispatch, visibilityOptions: .device)
    barrier()
    var previous = committedIndex
    for k in 0..<Int(count) {
      let destination = slots[k%2]
      let dt = min(step, duration-UInt64(k)*step)
      var u = NBConnectomeDispatch(nodes: graph.node_count, inputs: UInt32(binding.inputs.count),
        readouts: UInt32(binding.readouts.count), channels: binding.channelCount,
        step_count: UInt32(count), reserved0: 0, reserved1: 0, reserved2: 0,
        time_ratio: Float(dt)/Float(binding.nominalStepMicroseconds), output_clip: 1,
        reserved3: 0, reserved4: 0)
      withUnsafeBytes(of: &u) { uniforms.contents().advanced(by: k*64).copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
      for (i,a) in [address(graph.nodes_offset), address(graph.offsets_offset), address(graph.sources_offset),
        address(graph.weights_offset), inputOffsets.gpuAddress, inputBindings.gpuAddress,
        sensory.observationGPUAddress, sensory.validityGPUAddress, states[previous].gpuAddress,
        states[destination].gpuAddress, uniforms.gpuAddress+UInt64(k*64)].enumerated() {
        arguments.setAddress(a, index: i)
      }
      encoder.setComputePipelineState(sharedGraph.stepPipeline); encoder.setArgumentTable(arguments)
      encoder.dispatchThreads(threadsPerGrid: MTLSize(width: Int(graph.node_count), height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: sharedGraph.stepPipeline.threadExecutionWidth, height: 1, depth: 1))
      barrier(); previous = destination
    }
    for (i,a) in [address(graph.nodes_offset), readoutOffsets.gpuAddress, readouts.gpuAddress,
      states[previous].gpuAddress, output.gpuAddress].enumerated() { arguments.setAddress(a, index: i) }
    arguments.setAddress(uniforms.gpuAddress, index: 10)
    encoder.setComputePipelineState(sharedGraph.readoutPipeline); encoder.setArgumentTable(arguments)
    encoder.dispatchThreads(threadsPerGrid: MTLSize(width: Int(binding.channelCount), height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: sharedGraph.readoutPipeline.threadExecutionWidth, height: 1, depth: 1))
    barrier()
    pendingRoot = root.fingerprint
    return Candidate(owner: self, root: root, stateIndex: previous)
  }
}

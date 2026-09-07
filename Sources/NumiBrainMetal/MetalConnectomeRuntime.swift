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
  let decoderPipeline: any MTLComputePipelineState
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
      let readout = library.makeFunction(name: "nb_connectome_descending_readout"),
      let decode = library.makeFunction(name: "nb_connectome_motor_decode") else {
      throw ConnectomeError.invalid("connectome kernels are missing")
    }
    self.graph = graph; self.device = device; self.buffer = buffer
    stepPipeline = try device.makeComputePipelineState(function: step)
    readoutPipeline = try device.makeComputePipelineState(function: readout)
    decoderPipeline = try device.makeComputePipelineState(function: decode)
    buffer.label = "NumiBrain immutable NUMICNS1 graph"
  }
}

/// Connectome execution owned by the SAME transaction arena as cognition.
/// This object owns immutable tables and disposable scratch only. Recurrent
/// state, readout and decoder slew state are checkpointed hot-arena sections.
@available(macOS 26.0, *)
public final class MetalConnectomeRuntime: @unchecked Sendable {
  public let sharedGraph: MetalConnectomeGraph
  public let program: ConnectomeProgram
  private let arena: MetalAgentStateArena
  private let scratch: [any MTLBuffer]
  private let inputOffsets: any MTLBuffer
  private let inputBindings: any MTLBuffer
  private let readoutOffsets: any MTLBuffer
  private let readouts: any MTLBuffer
  private let decoderWeights: any MTLBuffer
  private let decoderBias: any MTLBuffer
  private let uniforms: any MTLBuffer
  private let decoderUniforms: any MTLBuffer
  private let arguments: any MTL4ArgumentTable

  private struct DecoderUniforms {
    var channels: UInt32
    var actuators: UInt32
    var commandKind: UInt32
    var reserved: UInt32 = 0
    var deltaSeconds: Float
    var maximumDriveChangePerSecond: Float
    var reserved1: Float = 0
    var reserved2: Float = 0
  }

  public init(sharedGraph: MetalConnectomeGraph, program: ConnectomeProgram,
    template: CompiledSpeciesTemplate, arena: MetalAgentStateArena,
    maximumScratchBytes: Int = 67_108_864) throws {
    try program.validate(template: template,
      parameterVersionFingerprint: program.binding.parameterVersionFingerprint)
    guard sharedGraph.graph.fingerprint == program.graph.fingerprint,
      arena.layout.connectomeProgramFingerprint == program.fingerprint,
      arena.layout.speciesTemplateFingerprint == template.species.fingerprint,
      MemoryLayout<NBConnectomeDispatch>.stride == 48,
      MemoryLayout<DecoderUniforms>.stride == 32 else {
      throw ConnectomeError.invalid("native arena/program or Metal ABI mismatch")
    }
    let binding = program.binding
    let n = program.graph.nodeCount
    let bytes = n*8 + (n+1)*4 + binding.inputs.count*32
      + binding.readouts.count*16 + (Int(binding.channelCount)+1)*4
      + program.decoder.weights.count*4 + program.decoder.bias.count*4
      + program.maximumSubsteps*64 + 32
    guard maximumScratchBytes > 0, bytes <= maximumScratchBytes else {
      throw ConnectomeError.invalid("connectome scratch allocation budget exceeded")
    }
    let device = sharedGraph.device
    func allocate(_ count: Int) throws -> any MTLBuffer {
      guard count > 0, count <= device.maxBufferLength,
        let b = device.makeBuffer(length: count, options: [.storageModeShared, .hazardTrackingModeTracked]) else {
        throw ConnectomeError.invalid("connectome allocation failed")
      }
      return b
    }
    func upload<T>(_ values: [T]) throws -> any MTLBuffer {
      let b = try allocate(values.count*MemoryLayout<T>.stride)
      values.withUnsafeBytes { b.contents().copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
      return b
    }
    // Scratch starts undefined: every element is fully written before use.
    guard let a = device.makeBuffer(length: n*4, options: .storageModePrivate),
      let b = device.makeBuffer(length: n*4, options: .storageModePrivate) else {
      throw ConnectomeError.invalid("connectome scratch allocation failed")
    }
    scratch = [a,b]
    inputOffsets = try upload(binding.inputOffsets); inputBindings = try upload(binding.inputs)
    readoutOffsets = try upload(binding.readoutOffsets); readouts = try upload(binding.readouts)
    decoderWeights = try upload(program.decoder.weights); decoderBias = try upload(program.decoder.bias)
    uniforms = try allocate(program.maximumSubsteps*64); decoderUniforms = try allocate(32)
    let descriptor = MTL4ArgumentTableDescriptor()
    descriptor.maxBufferBindCount = 11; descriptor.initializeBindings = true
    arguments = try device.makeArgumentTable(descriptor: descriptor)
    self.sharedGraph = sharedGraph; self.program = program; self.arena = arena
  }

  public var residencyAllocations: [any MTLAllocation] {
    [sharedGraph.buffer, inputOffsets, inputBindings, readoutOffsets, readouts,
      decoderWeights, decoderBias, uniforms, decoderUniforms] + scratch
  }

  /// The existing cognitive owner serializes encoding, residency and GPU
  /// completion. This function submits nothing and publishes no state.
  func encode(encoder: any MTL4ComputeCommandEncoder,
    root: BrainJointTransactionToken, transaction: MetalAgentStateTransactionToken,
    sensory: MetalSensoryTransductionRuntime.Result) throws {
    let hot = try arena.hotStateView(transaction: transaction)
    let binding = program.binding
    let obs = arena.layout.section(.sensoryObservations)
    let valid = arena.layout.section(.sensoryValidity)
    guard root.parameterVersionFingerprint == binding.parameterVersionFingerprint,
      root.baseBrainGeneration == transaction.baseGeneration,
      root.shadowGeneration == transaction.shadowGeneration,
      root.targetTimestamp > root.committedTimestamp,
      sensory.timestamp == root.committedTimestamp,
      sensory.observationScalarCount == Int(binding.scalarCount),
      sensory.validityScalarCount == Int(binding.scalarCount),
      sensory.observationGPUAddress == hot.outputGPUAddress+UInt64(obs.byteOffset),
      sensory.validityGPUAddress == hot.outputGPUAddress+UInt64(valid.byteOffset) else {
      throw ConnectomeError.invalid("connectome must consume this root's accepted receptor frame")
    }
    let duration = root.targetTimestamp.rawValue-root.committedTimestamp.rawValue
    let step = UInt64(binding.integrationStepMicroseconds)
    let count = duration/step + (duration%step == 0 ? 0 : 1)
    guard count <= UInt64(program.maximumSubsteps) else {
      throw ConnectomeError.invalid("neural physical-time substep budget exceeded")
    }
    let graph = program.graph.view
    let state = arena.layout.section(.connectomeState)
    let readout = arena.layout.section(.connectomeReadout)
    let control = arena.layout.section(.connectomeControl)
    func address(_ offset: UInt64) -> UInt64 { sharedGraph.buffer.gpuAddress+offset }
    func barrier() {
      encoder.barrier(afterEncoderStages: .dispatch, beforeEncoderStages: .dispatch, visibilityOptions: .device)
    }
    func dispatch(_ pipeline: any MTLComputePipelineState, _ count: Int) {
      encoder.setComputePipelineState(pipeline); encoder.setArgumentTable(arguments)
      encoder.dispatchThreads(threadsPerGrid: MTLSize(width: count, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: min(pipeline.threadExecutionWidth, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1))
    }
    var previous = hot.inputGPUAddress+UInt64(state.byteOffset)
    barrier()
    for k in 0..<Int(count) {
      let destination = k == Int(count)-1 ? hot.outputGPUAddress+UInt64(state.byteOffset) : scratch[k%2].gpuAddress
      let dt = min(step, duration-UInt64(k)*step)
      var u = NBConnectomeDispatch(nodes: graph.node_count, inputs: UInt32(binding.inputs.count),
        readouts: UInt32(binding.readouts.count), channels: binding.channelCount,
        step_count: UInt32(count), reserved0: 0, reserved1: 0, reserved2: 0,
        time_ratio: Float(dt)/Float(binding.nominalStepMicroseconds), output_clip: 1, reserved3: 0, reserved4: 0)
      withUnsafeBytes(of: &u) { uniforms.contents().advanced(by: k*64).copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
      for (i,a) in [address(graph.nodes_offset), address(graph.offsets_offset), address(graph.sources_offset),
        address(graph.weights_offset), inputOffsets.gpuAddress, inputBindings.gpuAddress,
        sensory.observationGPUAddress, sensory.validityGPUAddress, previous,
        destination, uniforms.gpuAddress+UInt64(k*64)].enumerated() { arguments.setAddress(a, index: i) }
      dispatch(sharedGraph.stepPipeline, Int(graph.node_count)); barrier(); previous = destination
    }
    let readoutAddress = hot.outputGPUAddress+UInt64(readout.byteOffset)
    for (i,a) in [address(graph.nodes_offset), readoutOffsets.gpuAddress, readouts.gpuAddress,
      previous, readoutAddress].enumerated() { arguments.setAddress(a, index: i) }
    arguments.setAddress(uniforms.gpuAddress, index: 10)
    dispatch(sharedGraph.readoutPipeline, Int(binding.channelCount)); barrier()
    var d = DecoderUniforms(channels: binding.channelCount, actuators: program.decoder.actuatorCount,
      commandKind: program.decoder.commandKind, deltaSeconds: Float(duration)*1e-6,
      maximumDriveChangePerSecond: program.decoder.maximumDriveChangePerSecond)
    withUnsafeBytes(of: &d) { decoderUniforms.contents().copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
    for (i,a) in [readoutAddress, decoderWeights.gpuAddress, decoderBias.gpuAddress,
      hot.inputGPUAddress+UInt64(control.byteOffset), hot.outputGPUAddress+UInt64(control.byteOffset),
      decoderUniforms.gpuAddress].enumerated() { arguments.setAddress(a, index: i) }
    dispatch(sharedGraph.decoderPipeline, Int(program.decoder.actuatorCount)); barrier()
  }
}

/// Weak cache: independently owned minds share immutable device data without
/// retaining every graph ever imported. Full bytes are checked on cache hits;
/// an interchange checksum is not treated as collision-proof authentication.
@available(macOS 26.0, *)
final class MetalConnectomeGraphCache: @unchecked Sendable {
  static let shared = MetalConnectomeGraphCache()
  private final class Entry {
    weak var value: MetalConnectomeGraph?
    init(_ value: MetalConnectomeGraph) { self.value = value }
  }
  private struct Key: Hashable { let device: UInt64; let graph: UInt64 }
  private let lock = NSLock()
  private var entries: [Key: Entry] = [:]
  func graph(program: ConnectomeProgram, device: any MTLDevice) throws -> MetalConnectomeGraph {
    lock.lock(); defer { lock.unlock() }
    entries = entries.filter { $0.value.value != nil }
    let key = Key(device: device.registryID, graph: program.graph.fingerprint)
    if let existing = entries[key]?.value {
      guard existing.graph.bytes == program.graph.bytes else {
        throw ConnectomeError.invalid("graph checksum collision in device cache")
      }
      return existing
    }
    let value = try MetalConnectomeGraph(graph: program.graph, device: device)
    entries[key] = Entry(value)
    return value
  }
}

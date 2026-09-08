import Foundation
@preconcurrency import Metal
import NumiBrainCore

/// Optional source on the normal NumiBrain factory. Reuse sharedGraph across
/// independent minds on one device to avoid duplicating the immutable graph.
public struct MetalConnectomeConfiguration: Sendable {
  public let graph: ConnectomeGraph
  public let specification: ConnectomeControllerSpec
  public let sharedGraph: MetalConnectomeGraph?
  public let maximumSubsteps: Int
  public init(graph: ConnectomeGraph, specification: ConnectomeControllerSpec,
    sharedGraph: MetalConnectomeGraph? = nil, maximumSubsteps: Int = 256) throws {
    guard (1...4096).contains(maximumSubsteps), graph.fingerprint == specification.graphFingerprint,
      sharedGraph == nil || sharedGraph!.graph.bytes == graph.bytes else {
      throw ConnectomeError.invalid("inconsistent connectome factory configuration")
    }
    self.graph = graph; self.specification = specification
    self.sharedGraph = sharedGraph; self.maximumSubsteps = maximumSubsteps
  }
}

/// Compiled per-agent construction input. No neural state is shared by this seed.
public struct MetalConnectomeControllerSeed: Sendable {
  public let program: ConnectomeControllerProgram
  public let environmentIdentifier: UInt32
  public let episodeIdentifier: UInt64
  public let sharedGraph: MetalConnectomeGraph?
  public let maximumSubsteps: Int
  public init(configuration: MetalConnectomeConfiguration, template: CompiledSpeciesTemplate,
    parameterVersionFingerprint: UInt64, environmentIdentifier: UInt32,
    episodeIdentifier: UInt64) throws {
    program = try ConnectomeControllerProgram(graph: configuration.graph,
      spec: configuration.specification, template: template,
      parameterVersionFingerprint: parameterVersionFingerprint)
    self.environmentIdentifier = environmentIdentifier; self.episodeIdentifier = episodeIdentifier
    sharedGraph = configuration.sharedGraph; maximumSubsteps = configuration.maximumSubsteps
  }
}

/// Only the owning controller constructs a view. The decision runtime checks
/// its exact generation/body/version, then uses it BEFORE existing protection.
struct MetalDescendingMotorView {
  enum Kind: UInt32 { case connectome = 1, muscleLocomotor = 2 }
  var kind: Kind = .connectome
  let transactionFingerprint: UInt64
  let shadowGeneration: UInt64
  let speciesFingerprint: UInt64
  let parameterVersionFingerprint: UInt64
  let programFingerprint: UInt64
  let logits: any MTLBuffer
  let actuatorCount: Int
}

@available(macOS 26.0, *)
final class MetalConnectomeController: @unchecked Sendable {
  let program: ConnectomeControllerProgram
  let mind: MetalConnectomeRuntime
  private let weights: any MTLBuffer
  private let biases: any MTLBuffer
  private let logits: any MTLBuffer
  private let uniforms: any MTLBuffer
  private let pipeline: any MTLComputePipelineState
  private let arguments: any MTL4ArgumentTable

  init(seed: MetalConnectomeControllerSeed, template: CompiledSpeciesTemplate,
    device: any MTLDevice) throws {
    let program = seed.program
    let graph = try seed.sharedGraph ?? MetalConnectomeGraph(graph: program.graph, device: device)
    guard graph.device.registryID == device.registryID,
      graph.graph.bytes == program.graph.bytes,
      program.binding.speciesFingerprint == template.species.fingerprint,
      program.binding.sensoryProfileFingerprint == template.sensoryProfile.fingerprint else {
      throw ConnectomeError.invalid("shared controller graph is on a foreign device or body")
    }
    mind = try MetalConnectomeRuntime(sharedGraph: graph, binding: program.binding,
      template: template, environmentIdentifier: seed.environmentIdentifier,
      episodeIdentifier: seed.episodeIdentifier, maximumSubsteps: seed.maximumSubsteps,
      topologyFingerprint: program.topologyFingerprint, programFingerprint: program.programFingerprint)
    self.program = program
    func upload<T>(_ values: [T]) throws -> any MTLBuffer {
      guard let buffer = values.withUnsafeBytes({ bytes in
        device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
      }) else { throw ConnectomeError.invalid("decoder allocation failed") }
      return buffer
    }
    weights = try upload(program.spec.decoderWeights); biases = try upload(program.spec.decoderBiases)
    logits = try upload([Float](repeating: 0, count: Int(program.actuatorCount)))
    uniforms = try upload([program.binding.channelCount, program.actuatorCount,
      program.spec.maximumLogit.bitPattern, UInt32(0)])
    guard let url = Bundle.module.url(forResource: "ConnectomeDecoder", withExtension: "metal", subdirectory: "Shaders")
      ?? Bundle.module.url(forResource: "ConnectomeDecoder", withExtension: "metal") else {
      throw ConnectomeError.invalid("connectome decoder shader missing")
    }
    let options = MTLCompileOptions(); options.mathMode = .safe
    let library = try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: options)
    guard let function = library.makeFunction(name: "nb_connectome_decode_motor") else {
      throw ConnectomeError.invalid("connectome decoder entry point missing")
    }
    pipeline = try device.makeComputePipelineState(function: function)
    let descriptor = MTL4ArgumentTableDescriptor()
    descriptor.maxBufferBindCount = 5; descriptor.initializeBindings = true
    arguments = try device.makeArgumentTable(descriptor: descriptor)
  }

  var residencyAllocations: [any MTLAllocation] {
    mind.residencyAllocations + [weights, biases, logits, uniforms]
  }

  func encode(transaction: MetalJointAgentStateTransaction,
    encoder: any MTL4ComputeCommandEncoder,
    sensory: MetalSensoryTransductionRuntime.Result) throws -> MetalDescendingMotorView {
    let descending = try transaction.encodeConnectome(mind, encoder: encoder, sensory: sensory)
    guard descending.bindingFingerprint == program.binding.fingerprint,
      descending.transactionFingerprint == transaction.jointToken.fingerprint else {
      throw ConnectomeError.invalid("decoder received a foreign neural decision")
    }
    for (i, address) in [descending.gpuAddress, weights.gpuAddress, biases.gpuAddress,
      logits.gpuAddress, uniforms.gpuAddress].enumerated() { arguments.setAddress(address, index: i) }
    encoder.setComputePipelineState(pipeline); encoder.setArgumentTable(arguments)
    encoder.dispatchThreads(threadsPerGrid: MTLSize(width: Int(program.actuatorCount), height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: pipeline.threadExecutionWidth, height: 1, depth: 1))
    encoder.barrier(afterEncoderStages: .dispatch, beforeEncoderStages: .dispatch, visibilityOptions: .device)
    return MetalDescendingMotorView(transactionFingerprint: transaction.jointToken.fingerprint,
      shadowGeneration: transaction.jointToken.shadowGeneration,
      speciesFingerprint: program.binding.speciesFingerprint,
      parameterVersionFingerprint: program.binding.parameterVersionFingerprint,
      programFingerprint: program.programFingerprint, logits: logits, actuatorCount: Int(program.actuatorCount))
  }
}

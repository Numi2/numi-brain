import Foundation
@preconcurrency import Metal
import NumiBrainCore

@available(macOS 26.0, *)
final class MetalMuscleLocomotorController: @unchecked Sendable {
  let program: MuscleLocomotorProgram
  private let template: CompiledSpeciesTemplate
  private let version: UInt64
  private let channels: any MTLBuffer
  private let logits: any MTLBuffer
  private let uniforms: any MTLBuffer
  private let pipeline: any MTLComputePipelineState
  private let arguments: any MTL4ArgumentTable

  init(program: MuscleLocomotorProgram, template: CompiledSpeciesTemplate,
    parameterVersion: UInt64, device: any MTLDevice) throws {
    try program.validate(template: template)
    self.program = program; self.template = template; version = parameterVersion
    let sense = template.species.senses.first { $0.modality == .proprioception }!
    var words: [UInt32] = []
    for c in program.channels {
      func binding(_ signal: MuscleReceptorSignal) -> MuscleReceptorBinding {
        template.sensoryProfile.muscleReceptorBindings.first {
          $0.muscleIdentifier == c.muscleIdentifier && $0.signal == signal
        }!
      }
      let l = binding(.length), v = binding(.lengthVelocity)
      guard l.receptorIndex == v.receptorIndex else {
        throw BrainRuntimeError.invalidDescriptor("spindle length and velocity must share receptor validity")
      }
      words += [l.receptorIndex * sense.observationDimension + l.featureIndex,
        v.receptorIndex * sense.observationDimension + v.featureIndex, l.receptorIndex,
        (UInt32(1) << l.featureIndex) | (UInt32(1) << v.featureIndex)]
      words += [c.referenceLengthMeters, c.tonicExcitation, c.lengthGain, c.velocityGainSeconds,
        c.gaitSine, c.gaitCosine, c.maximumExcitation, 0].map(\.bitPattern)
    }
    func upload(_ words: [UInt32]) throws -> any MTLBuffer {
      guard let b = words.withUnsafeBytes({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) }) else {
        throw TissueError.metal("locomotor allocation failed")
      }; return b
    }
    channels = try upload(words); logits = try upload([UInt32](repeating: 0, count: program.channels.count))
    uniforms = try upload([0, 0, 0, 0])
    let library = try Self.makeLibrary(device: device)
    guard let function = library.makeFunction(name: "nb_muscle_locomotor") else { throw TissueError.metal("locomotor kernel missing") }
    pipeline = try device.makeComputePipelineState(function: function)
    let descriptor = MTL4ArgumentTableDescriptor(); descriptor.maxBufferBindCount = 5; descriptor.initializeBindings = true
    arguments = try device.makeArgumentTable(descriptor: descriptor)
  }
  static func makeLibrary(device: any MTLDevice) throws -> any MTLLibrary {
    guard let url = Bundle.module.url(forResource: "MuscleLocomotor", withExtension: "metal", subdirectory: "Shaders")
      ?? Bundle.module.url(forResource: "MuscleLocomotor", withExtension: "metal") else {
      throw TissueError.metal("locomotor shader resource missing")
    }
    let options = MTLCompileOptions(); options.mathMode = .safe
    return try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: options)
  }
  var residencyAllocations: [any MTLAllocation] { [channels, logits, uniforms] }

  func encode(root: BrainJointTransactionToken, encoder: any MTL4ComputeCommandEncoder,
    rawSensors: [MetalRawSensorBufferView]) throws -> MetalDescendingMotorView {
    let sense = template.species.senses.first { $0.enabled && $0.modality == .proprioception }!
    let views = rawSensors.filter { $0.modality == .proprioception }
    guard views.count == 1, let view = views.first, view.hasValidity,
      view.receptorCount == sense.receptorCount, view.featureDimension == sense.observationDimension,
      view.receptorTimestamp.rawValue <= root.committedTimestamp.rawValue,
      root.committedTimestamp.rawValue - view.receptorTimestamp.rawValue >= UInt64(sense.latencyMicroseconds),
      root.parameterVersionFingerprint == version,
      root.committedTimestamp.rawValue >= program.epochMicroseconds else {
      throw TissueError.transaction("locomotor controller requires this root's delivered physical spindle packet")
    }
    let elapsed = root.committedTimestamp.rawValue - program.epochMicroseconds
    let phase = program.periodMicroseconds == 0 ? Float(0)
      : Float(elapsed % program.periodMicroseconds) / Float(program.periodMicroseconds) * (2 * Float.pi)
    let words = [UInt32(program.channels.count), phase.bitPattern, UInt32(0), UInt32(0)]
    words.withUnsafeBytes { uniforms.contents().copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
    encoder.barrier(afterQueueStages: [.dispatch, .blit], beforeStages: .dispatch, visibilityOptions: .device)
    encoder.barrier(afterEncoderStages: [.dispatch, .blit], beforeEncoderStages: .dispatch, visibilityOptions: .device)
    for (i, address) in [view.gpuAddress, view.validityGPUAddress, channels.gpuAddress,
      logits.gpuAddress, uniforms.gpuAddress].enumerated() { arguments.setAddress(address, index: i) }
    encoder.setComputePipelineState(pipeline); encoder.setArgumentTable(arguments)
    encoder.dispatchThreads(threadsPerGrid: MTLSize(width: program.channels.count, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: pipeline.threadExecutionWidth, height: 1, depth: 1))
    encoder.barrier(afterEncoderStages: .dispatch, beforeEncoderStages: .dispatch, visibilityOptions: .device)
    return MetalDescendingMotorView(kind: .muscleLocomotor, transactionFingerprint: root.fingerprint, shadowGeneration: root.shadowGeneration,
      speciesFingerprint: template.species.fingerprint, parameterVersionFingerprint: version,
      programFingerprint: program.fingerprint, logits: logits, actuatorCount: program.channels.count)
  }
}

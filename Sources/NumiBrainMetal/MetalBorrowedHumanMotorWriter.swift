import Foundation
@preconcurrency import Metal
import NumiBrainCore

@available(macOS 26.0, *)
final class MetalBorrowedHumanMotorWriter {
  private let pipeline: any MTLComputePipelineState
  private let noPriorFailure: any MTLBuffer

  init(device: any MTLDevice) throws {
    func source(_ name: String) throws -> String {
      guard let url = MetalBrainResourceBundle.bundle.url(forResource: name, withExtension: "metal", subdirectory: "Shaders")
        ?? MetalBrainResourceBundle.bundle.url(forResource: name, withExtension: "metal") else {
        throw TissueError.metal("\(name).metal is missing from package resources")
      }
      return try String(contentsOf: url, encoding: .utf8)
    }
    let options = MTLCompileOptions()
    options.languageVersion = .version4_0
    options.mathMode = .safe
    options.mathFloatingPointFunctions = .precise
    let library = try device.makeLibrary(source: source("NumanXMotorReady") + "\n" + source("BorrowedHumanMotor"), options: options)
    guard let function = library.makeFunction(name: "borrowed_human_motor_excitation"),
      let noPriorFailure = device.makeBuffer(length: 4, options: .storageModeShared) else {
      throw TissueError.metal("borrowed Human motor writer could not be allocated")
    }
    noPriorFailure.contents().storeBytes(of: UInt32(0), as: UInt32.self)
    self.noPriorFailure = noPriorFailure
    pipeline = try device.makeComputePipelineState(function: function)
  }

  func encode(command: MetalNumiBrainRuntime.BorrowedMotorCommand,
    encoder: any MTLComputeCommandEncoder, destinationMuscleStates: any MTLBuffer,
    count: Int, standStatuses: (any MTLBuffer)?) throws {
    let buffers = command.buffers
    let evaluation = command.evaluation
    let sources = [buffers.excitationBuffer, buffers.headerBuffer, evaluation.gateBuffer,
      evaluation.expectedBuffer, evaluation.candidateBuffer, buffers.autonomicBuffer,
      buffers.activeSensingBuffer]
    guard count == 416, command.candidate.muscleCount == UInt32(count),
      command.candidate.actuatorCommandKind == .muscleExcitation,
      buffers.excitationBuffer.length == count * MemoryLayout<Float>.stride,
      buffers.headerBuffer.length == 80,
      evaluation.gateBuffer.length == 160, evaluation.expectedBuffer.length == 160,
      evaluation.candidateBuffer.length == 152,
      Int(command.candidate.autonomicCommandByteCount) <= buffers.autonomicBuffer.length,
      Int(command.candidate.activeSensingCommandByteCount) <= buffers.activeSensingBuffer.length,
      destinationMuscleStates.length >= count * MemoryLayout<SIMD4<Float>>.stride,
      pipeline.device.registryID == encoder.device.registryID,
      destinationMuscleStates.device.registryID == encoder.device.registryID,
      sources.allSatisfy({ $0.device.registryID == encoder.device.registryID
        && ($0 as AnyObject) !== (destinationMuscleStates as AnyObject) }),
      standStatuses == nil || (standStatuses!.length >= 4
        && standStatuses!.device.registryID == encoder.device.registryID
        && (standStatuses! as AnyObject) !== (destinationMuscleStates as AnyObject)) else {
      throw TissueError.transaction("borrowed Human writer requires exact protected muscle buffers and native float4 states")
    }
    var shape = SIMD4<UInt32>(UInt32(count), standStatuses == nil ? 0 : 1,
      command.candidate.autonomicCommandByteCount, command.candidate.activeSensingCommandByteCount)
    encoder.memoryBarrier(scope: .buffers)
    encoder.setComputePipelineState(pipeline)
    encoder.setBuffer(buffers.excitationBuffer, offset: 0, index: 0)
    encoder.setBuffer(buffers.headerBuffer, offset: 0, index: 1)
    encoder.setBuffer(evaluation.gateBuffer, offset: 0, index: 2)
    encoder.setBuffer(evaluation.expectedBuffer, offset: 0, index: 3)
    encoder.setBuffer(evaluation.candidateBuffer, offset: 0, index: 4)
    encoder.setBuffer(destinationMuscleStates, offset: 0, index: 5)
    encoder.setBytes(&shape, length: MemoryLayout<SIMD4<UInt32>>.stride, index: 6)
    encoder.setBuffer(standStatuses ?? noPriorFailure, offset: 0, index: 7)
    encoder.setBuffer(buffers.autonomicBuffer, offset: 0, index: 8)
    encoder.setBuffer(buffers.activeSensingBuffer, offset: 0, index: 9)
    encoder.dispatchThreads(MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
    encoder.memoryBarrier(scope: .buffers)
  }
}

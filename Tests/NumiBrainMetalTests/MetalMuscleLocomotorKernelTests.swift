import Foundation
import Metal
import XCTest
@_spi(NumanXInterop) @testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalMuscleLocomotorKernelTests: XCTestCase {
  func testCheckpointPreservesAndAuthenticatesControllerIdentity() throws {
    let checkpoint = try MetalBrainCheckpoint(committedGeneration: 1,
      committedTimestamp: .init(microseconds: 1000), environmentIdentifier: 0,
      episodeIdentifier: 1, controlStepIdentifier: 1, speciesTemplateFingerprint: 1,
      compiledSpeciesTemplateFingerprint: 2, regionalProgramFingerprint: 3,
      scheduleFingerprint: 4, parameterVersionFingerprint: 5, hotLayoutFingerprint: 6,
      memoryLayoutFingerprint: 7, physicalCheckpointFingerprint: 8,
      hotState: Data([1]), persistentMemory: Data([2]), muscleLocomotorFingerprint: 123)
    XCTAssertEqual(try MetalBrainCheckpoint.decode(checkpoint.encoded()), checkpoint)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(checkpoint)) as? [String: Any])
    object["muscleLocomotorFingerprint"] = 124
    let changed = try JSONDecoder().decode(MetalBrainCheckpoint.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertThrowsError(try changed.validate())
    object.removeValue(forKey: "muscleLocomotorFingerprint")
    let removed = try JSONDecoder().decode(MetalBrainCheckpoint.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertThrowsError(try removed.validate())
  }

  // Numerical conformance over the production shader. This test encoder is
  // not a runtime fallback or physical locomotion qualification.
  func testSpindleFeedbackAlternationBoundsAndMissingEvidence() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let library = try MetalMuscleLocomotorController.makeLibrary(device: device)
    let pipeline = try device.makeComputePipelineState(function: XCTUnwrap(library.makeFunction(name: "nb_muscle_locomotor")))
    func upload<T>(_ values: [T]) throws -> any MTLBuffer {
      try XCTUnwrap(values.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) })
    }
    var rows: [UInt32] = []
    for sign: Float in [1, -1, 0] {
      rows += [0, 1, 0, 3]
      rows += [Float(0.25), sign == 0 ? 1 : 0.2, sign == 0 ? 0 : 0.5, sign == 0 ? 0 : 0.02, sign * 0.1, 0, sign == 0 ? 1 : 0.4, 0].map(\.bitPattern)
    }
    let channels = try upload(rows)
    let queue = try XCTUnwrap(device.makeCommandQueue())
    func evaluate(length: Float = 0.25, velocity: Float = 0, phase: Float = 0, valid: UInt32 = 3) throws -> [Float] {
      let inputs = try upload([length, velocity]), validity = try upload([valid])
      let output = try upload([Float(-1), -1, -1])
      let uniforms = try upload([UInt32(3), phase.bitPattern, 0, 0])
      let command = try XCTUnwrap(queue.makeCommandBuffer())
      let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
      encoder.setComputePipelineState(pipeline)
      for (i, b) in [inputs, validity, channels, output, uniforms].enumerated() { encoder.setBuffer(b, offset: 0, index: i) }
      encoder.dispatchThreads(MTLSize(width: 3, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 3, height: 1, depth: 1))
      encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
      XCTAssertEqual(command.status, .completed, "\(String(describing: command.error))")
      let raw = Array(UnsafeBufferPointer(start: output.contents().assumingMemoryBound(to: Float.self), count: 3))
      XCTAssertTrue(raw.allSatisfy(\.isFinite))
      return raw.map { tanh($0) }
    }
    let rest = try evaluate(); XCTAssertEqual(rest[2], 1); for value in rest.prefix(2) { XCTAssertEqual(value, 0.2, accuracy: 1e-6) }
    let a = try evaluate(phase: Float.pi / 2), b = try evaluate(phase: 3 * Float.pi / 2)
    XCTAssertEqual(a[0], 0.3, accuracy: 1e-6); XCTAssertEqual(a[1], 0.1, accuracy: 1e-6)
    XCTAssertEqual(b[0], a[1], accuracy: 1e-6); XCTAssertEqual(b[1], a[0], accuracy: 1e-6)
    XCTAssertEqual(try evaluate(length: 0.3, velocity: 0.5)[0], 0.34, accuracy: 1e-6)
    XCTAssertEqual(try evaluate(length: 1)[0], 0.4, accuracy: 1e-6)
    XCTAssertEqual(try evaluate(length: 0.01), [0, 0, 1])
    XCTAssertEqual(try evaluate(valid: 0), [0, 0, 0])
    XCTAssertEqual(try evaluate(valid: 1), [0, 0, 0])
    XCTAssertEqual(try evaluate(valid: 2), [0, 0, 0])
    XCTAssertEqual(try evaluate(length: .nan), [0, 0, 0])
    XCTAssertEqual(try evaluate(velocity: .infinity), [0, 0, 0])
    XCTAssertEqual(try evaluate(length: .greatestFiniteMagnitude), [0, 0, 0])
    XCTAssertEqual(try evaluate(phase: Float.pi / 2), a)
  }

  func testDelayedSpindleUsesExactHeldOffLogitUntilOnsetAndStillRequiresEvidence() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let library = try MetalMuscleLocomotorController.makeLibrary(device: device)
    let queue = try XCTUnwrap(device.makeCommandQueue())
    func upload<T>(_ values: [T]) throws -> any MTLBuffer {
      try XCTUnwrap(values.withUnsafeBytes {
        device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
      })
    }
    func logit(function: String, lengthGain: Float, velocityGain: Float,
      enabled: UInt32, validity: UInt32 = 3) throws -> UInt32 {
      let pipeline = try device.makeComputePipelineState(function: XCTUnwrap(
        library.makeFunction(name: function)))
      let row: [UInt32] = [0, 1, 0, 3] +
        [Float(0.25), 0.2, lengthGain, velocityGain, 0, 0, 1, 0].map(\.bitPattern)
      let inputs = try upload([Float(0.3), 0.5])
      let valid = try upload([validity]), channels = try upload(row)
      let output = try upload([UInt32.max])
      let uniforms = try upload([UInt32(1), Float(0).bitPattern, enabled, 0])
      let command = try XCTUnwrap(queue.makeCommandBuffer())
      let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
      encoder.setComputePipelineState(pipeline)
      for (index, buffer) in [inputs, valid, channels, output, uniforms].enumerated() {
        encoder.setBuffer(buffer, offset: 0, index: index)
      }
      encoder.dispatchThreads(MTLSize(width: 1, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
      encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
      XCTAssertEqual(command.status, .completed, "\(String(describing: command.error))")
      return output.contents().assumingMemoryBound(to: UInt32.self).pointee
    }
    let heldOff = try logit(function: "nb_muscle_locomotor", lengthGain: 0,
      velocityGain: 0, enabled: 0)
    let immediate = try logit(function: "nb_muscle_locomotor", lengthGain: 1,
      velocityGain: 0.02, enabled: 0)
    let before = try logit(function: "nb_muscle_locomotor_delayed", lengthGain: 1,
      velocityGain: 0.02, enabled: 0)
    let after = try logit(function: "nb_muscle_locomotor_delayed", lengthGain: 1,
      velocityGain: 0.02, enabled: 1)
    XCTAssertEqual(before, heldOff, "pre-onset motor logit must match v1 held-off bits")
    XCTAssertEqual(after, immediate, "post-onset motor logit must match immediate spindle bits")
    XCTAssertNotEqual(after, before)
    XCTAssertEqual(try logit(function: "nb_muscle_locomotor_delayed", lengthGain: 1,
      velocityGain: 0.02, enabled: 0, validity: 0), 0,
      "tonic recruitment cannot substitute for missing physical spindle evidence")
  }
}

import Foundation
import Metal
import NumiBrainABI
import XCTest
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalProtectiveHashKernelTests: XCTestCase {
  func testOrderedUnrollMatchesCABIForRemaindersAndRawFloatBits() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let queue = try XCTUnwrap(device.makeCommandQueue())
    let sourceURL = try XCTUnwrap(
      MetalBrainResourceBundle.bundle.url(forResource: "NeuralTissue", withExtension: "metal", subdirectory: "Shaders")
        ?? MetalBrainResourceBundle.bundle.url(forResource: "NeuralTissue", withExtension: "metal"))
    let source = try String(contentsOf: sourceURL, encoding: .utf8) + """

      kernel void nb_test_protective_hash(
        device const NBMotorOutputHeaderABI *headers [[buffer(0)]],
        device const float *values [[buffer(1)]],
        device ulong *results [[buffer(2)]],
        constant uint &stride [[buffer(3)]],
        constant uint &count [[buffer(4)]],
        uint gid [[thread_position_in_grid]]) {
        if (gid >= count) return;
        const NBMotorOutputHeaderABI header = headers[gid];
        results[gid] = motor_output_fingerprint(header, values + gid * stride);
      }
      """
    XCTAssertEqual(MemoryLayout<NBMotorOutputHeader>.stride, 80)
    let counts = [1, 3, 4, 7, 8, 15, 16, 17, 31, 32, 127, 128, 129,
      415, 416, 417, 511, 512, 513, 1040]
    let stride = 1040
    var headers: [NBMotorOutputHeader] = []
    var values: [Float] = []
    var expected: [UInt64] = []
    var random: UInt64 = 0x4e55_4d49_4841_5348
    func nextBits() -> UInt32 {
      random = random &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return UInt32(truncatingIfNeeded: random >> 32)
    }
    for count in counts {
      for context in 0..<8 {
        var header = NBMotorOutputHeader()
        header.format_version = UInt32(NB_MOTOR_OUTPUT_VERSION)
        header.flags = nextBits()
        header.timestamp_microseconds = UInt64(nextBits()) << 32 | UInt64(nextBits())
        header.brain_generation = UInt64(nextBits())
        header.profile_fingerprint = UInt64(nextBits()) << 32 | UInt64(nextBits())
        header.protective_command_fingerprint = UInt64(nextBits()) << 32 | UInt64(nextBits())
        header.muscle_count = UInt32(count)
        header.environment_identifier = nextBits()
        header.motor_inhibition = Float(bitPattern: nextBits())
        header.autonomic_arousal = Float(bitPattern: nextBits())
        header.actuator_command_kind = nextBits()
        header.reserved = nextBits()
        header.output_minimum = Float(bitPattern: nextBits())
        header.output_maximum = Float(bitPattern: nextBits())
        header.output_fingerprint = UInt64.max // The digest must not hash itself.
        var row = [Float](repeating: 0, count: stride)
        let specialBits: [UInt32] = [0x7fc0_1234, 0xffa0_4321, 0x7f80_0000,
          0xff80_0000, 1, 0x8000_0001, 0x3f80_0000, 0x8000_0000]
        for index in 0..<count {
          switch context {
          case 0: row[index] = 0
          case 1: row[index] = 1
          case 2: row[index] = Float(bitPattern: index.isMultiple(of: 2) ? 0 : 0x8000_0000)
          case 3: row[index] = Float(bitPattern: nextBits())
          case 4: row[index] = Float(bitPattern: specialBits[index % specialBits.count])
          default: row[index] = Float((index * 37 + 11) % 251) / 251
          }
        }
        if context == 6 { row[count / 2] = Float(bitPattern: row[count / 2].bitPattern ^ 1) }
        if context == 7 { row[count - 1] = Float(bitPattern: row[count - 1].bitPattern ^ 0x0080_0000) }
        let digest = row.withUnsafeBufferPointer { floats in
          withUnsafePointer(to: &header) {
            nb_brain_abi_motor_output_fingerprint($0, floats.baseAddress)
          }
        }
        headers.append(header)
        values.append(contentsOf: row)
        expected.append(digest)
      }
    }
    let headerBuffer = try XCTUnwrap(headers.withUnsafeBytes {
      device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
    })
    let valueBuffer = try XCTUnwrap(values.withUnsafeBytes {
      device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
    })
    let resultBuffer = try XCTUnwrap(device.makeBuffer(
      length: expected.count * MemoryLayout<UInt64>.stride, options: .storageModeShared))
    for unroll in [0, 4, 8, 16] {
      let options = MTLCompileOptions()
      options.languageVersion = .version4_0
      options.mathMode = .fast
      options.mathFloatingPointFunctions = .fast
      options.preprocessorMacros = ["NB_PROTECTIVE_HASH_UNROLL": NSNumber(value: unroll)]
      let library = try device.makeLibrary(source: source, options: options)
      let function = try XCTUnwrap(library.makeFunction(name: "nb_test_protective_hash"))
      let pipeline = try device.makeComputePipelineState(function: function)
      let command = try XCTUnwrap(queue.makeCommandBuffer())
      let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
      var width = UInt32(stride), count = UInt32(expected.count)
      encoder.setComputePipelineState(pipeline)
      encoder.setBuffer(headerBuffer, offset: 0, index: 0)
      encoder.setBuffer(valueBuffer, offset: 0, index: 1)
      encoder.setBuffer(resultBuffer, offset: 0, index: 2)
      encoder.setBytes(&width, length: 4, index: 3)
      encoder.setBytes(&count, length: 4, index: 4)
      encoder.dispatchThreads(MTLSize(width: expected.count, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: pipeline.threadExecutionWidth, height: 1, depth: 1))
      encoder.endEncoding()
      command.commit()
      command.waitUntilCompleted()
      XCTAssertEqual(command.status, .completed, "\(String(describing: command.error))")
      let actual = Array(UnsafeBufferPointer(
        start: resultBuffer.contents().assumingMemoryBound(to: UInt64.self), count: expected.count))
      XCTAssertEqual(actual, expected, "unroll=\(unroll): exact independent C ABI digest contract")
    }
  }
}

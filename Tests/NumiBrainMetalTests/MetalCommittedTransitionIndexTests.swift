import Foundation
import Metal
import XCTest

@available(macOS 26.0, *)
final class MetalCommittedTransitionIndexTests: XCTestCase {
  func testProductionSampleIndexMatchesUInt64OracleAcrossBounds() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent()
    let source = try String(contentsOf: root.appendingPathComponent(
      "Sources/NumiBrainMetal/Shaders/MemoryState.metal"), encoding: .utf8)
    XCTAssertTrue(source.contains("const uint local_index = nb_committed_transition_sample_index("))
    let start = try XCTUnwrap(source.range(of: "inline uint nb_committed_transition_sample_index("))
    let end = try XCTUnwrap(source.range(of: "\n}", range: start.lowerBound..<source.endIndex))
    let helper = String(source[start.lowerBound..<end.upperBound])
    let shader = """
    #include <metal_stdlib>
    using namespace metal;
    \(helper)
    kernel void sample_index(device const uint2 *inputs [[buffer(0)]],
        device uint *outputs [[buffer(1)]], uint gid [[thread_position_in_grid]]) {
      uint2 input = inputs[gid];
      outputs[gid] = nb_committed_transition_sample_index(
        input.x, input.y, min(input.y, 1024u));
    }
    """
    let options = MTLCompileOptions()
    options.languageVersion = .version4_0
    options.mathMode = .safe
    options.mathFloatingPointFunctions = .precise
    let library = try device.makeLibrary(source: shader, options: options)
    let pipeline = try device.makeComputePipelineState(
      function: XCTUnwrap(library.makeFunction(name: "sample_index")))
    var counts = Array(UInt32(1)...UInt32(1025))
    for shift in 11...31 {
      let value = UInt32(1) << shift
      counts += [value - 1, value, value + 1]
    }
    counts += [UInt32.max - 1, UInt32.max]
    var seed: UInt32 = 0x4e554d49
    for _ in 0..<128 {
      seed = seed &* 1664525 &+ 1013904223
      counts.append(max(seed, 1))
    }
    var inputs = [SIMD2<UInt32>]()
    var expected = [UInt32]()
    for count in counts {
      let n = min(count, 1024)
      for sample in UInt32(0)..<n {
        inputs.append(SIMD2(sample, count))
        expected.append(UInt32(UInt64(sample) * UInt64(count) / UInt64(n)))
      }
    }
    let input = try XCTUnwrap(inputs.withUnsafeBytes {
      device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
    })
    let output = try XCTUnwrap(device.makeBuffer(
      length: expected.count * MemoryLayout<UInt32>.stride, options: .storageModeShared))
    memset(output.contents(), 0xff, output.length)
    let queue = try XCTUnwrap(device.makeCommandQueue())
    let command = try XCTUnwrap(queue.makeCommandBuffer())
    let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
    encoder.setComputePipelineState(pipeline)
    encoder.setBuffer(input, offset: 0, index: 0)
    encoder.setBuffer(output, offset: 0, index: 1)
    encoder.dispatchThreads(MTLSize(width: expected.count, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: min(256, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1))
    encoder.endEncoding()
    command.commit()
    command.waitUntilCompleted()
    XCTAssertEqual(command.status, .completed, String(describing: command.error))
    let actual = UnsafeBufferPointer(start: output.contents().assumingMemoryBound(to: UInt32.self), count: expected.count)
    XCTAssertEqual(Array(actual), expected)
  }
}

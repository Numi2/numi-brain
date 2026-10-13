import Foundation
import Metal
import XCTest

@available(macOS 26.0, *)
final class MetalRegionalScalarOwnerTests: XCTestCase {
  func testProductionOwnerMatchesLinearOracleIncludingEmptyRegions() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let source = try String(contentsOf: root.appendingPathComponent(
      "Sources/NumiBrainMetal/Shaders/NeuralTissue.metal"), encoding: .utf8)
    XCTAssertTrue(source.contains("const uint localInvocation = nb_regional_scalar_owner("))
    let start = try XCTUnwrap(source.range(of: "inline uint nb_regional_scalar_owner("))
    let end = try XCTUnwrap(source.range(of: "\n}", range: start.lowerBound..<source.endIndex))
    let helper = String(source[start.lowerBound..<end.upperBound])
    let shader = """
    #include <metal_stdlib>
    using namespace metal;
    \(helper)
    kernel void owner(device const uint *input [[buffer(0)]],
        device const uint4 *cases [[buffer(1)]], device uint *output [[buffer(2)]],
        uint group [[threadgroup_position_in_grid]], uint lane [[thread_index_in_threadgroup]]) {
      threadgroup uint offsets[33];
      const uint4 c = cases[group];
      for (uint i = lane; i <= c.z; i += 32u) offsets[i] = input[c.x + i];
      threadgroup_barrier(mem_flags::mem_threadgroup);
      for (uint work = lane; work < c.w; work += 32u)
        output[c.y + work] = nb_regional_scalar_owner(offsets, c.z, work);
    }
    """
    let options = MTLCompileOptions()
    options.languageVersion = .version4_0
    options.mathMode = .safe
    options.mathFloatingPointFunctions = .precise
    let library = try device.makeLibrary(source: shader, options: options)
    let pipeline = try device.makeComputePipelineState(
      function: XCTUnwrap(library.makeFunction(name: "owner")))
    var offsets = [UInt32]()
    var cases = [SIMD4<UInt32>]()
    var expected = [UInt32]()
    func append(_ lengths: [UInt32]) {
      let base = UInt32(offsets.count)
      let out = UInt32(expected.count)
      var total: UInt32 = 0
      offsets.append(0)
      for (owner, length) in lengths.enumerated() {
        total += length
        offsets.append(total)
        expected.append(contentsOf: repeatElement(UInt32(owner), count: Int(length)))
      }
      cases.append(SIMD4(base, out, UInt32(lengths.count), total))
    }
    for count in 1...6 {
      for pattern in 0..<(1 << (2 * count)) {
        append((0..<count).map { UInt32((pattern >> (2 * $0)) & 3) })
      }
    }
    var seed: UInt32 = 0x4e554d49
    for count in 1...32 {
      append(Array(repeating: 0, count: count))
      append(Array(repeating: 1, count: count))
      append((0..<count).map { $0 % 2 == 0 ? 0 : 17 })
      for active in 0..<count {
        var lengths = Array(repeating: UInt32(0), count: count)
        lengths[active] = 257
        append(lengths)
      }
      for _ in 0..<32 {
        append((0..<count).map { _ in
          seed = seed &* 1664525 &+ 1013904223
          return (seed >> 24) % 65
        })
      }
    }
    func buffer<T>(_ values: [T]) throws -> MTLBuffer {
      try XCTUnwrap(values.withUnsafeBytes {
        device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
      })
    }
    let input = try buffer(offsets)
    let descriptions = try buffer(cases)
    let output = try XCTUnwrap(device.makeBuffer(
      length: expected.count * MemoryLayout<UInt32>.stride, options: .storageModeShared))
    memset(output.contents(), 0xff, output.length)
    let queue = try XCTUnwrap(device.makeCommandQueue())
    let command = try XCTUnwrap(queue.makeCommandBuffer())
    let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
    encoder.setComputePipelineState(pipeline)
    encoder.setBuffer(input, offset: 0, index: 0)
    encoder.setBuffer(descriptions, offset: 0, index: 1)
    encoder.setBuffer(output, offset: 0, index: 2)
    encoder.dispatchThreadgroups(MTLSize(width: cases.count, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
    encoder.endEncoding()
    command.commit()
    command.waitUntilCompleted()
    XCTAssertEqual(command.status, .completed, String(describing: command.error))
    let actual = UnsafeBufferPointer(
      start: output.contents().assumingMemoryBound(to: UInt32.self), count: expected.count)
    XCTAssertEqual(Array(actual), expected)
    print("regional_owner_native_cases=\(cases.count) scalar_checks=\(expected.count)")
  }
}

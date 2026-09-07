#if canImport(Metal)
import Foundation
import XCTest
import Metal
import NumiBrainCore
import NumiBrainConnectomeABI
import NumiBrainConnectomeTestSupport
@testable import NumiBrainMetal

/// Shader conformance only. The legacy test encoder is not a production
/// fallback; MetalConnectomeRuntime exclusively uses its owner's Metal 4 pass.
@available(macOS 26.0, *)
final class MetalConnectomeKernelTests: XCTestCase {
  func testRecurrentDirectionAndPerScalarValidity() throws {
    guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("Metal device required") }
    let graph = try ConnectomeGraph(data: ConnectomeTestFixture.data())
    let shared = try MetalConnectomeGraph(graph: graph, device: device)
    func upload<T>(_ values: [T]) throws -> any MTLBuffer {
      try XCTUnwrap(values.withUnsafeBytes {
        device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
      })
    }
    func evaluate(validity: [UInt32], timeRatio: Float = 1) throws -> (state: [Float], readout: Float) {
      let queue = try XCTUnwrap(device.makeCommandQueue())
      let command = try XCTUnwrap(queue.makeCommandBuffer())
      let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
      let inputOffsets = try upload([UInt32(0), 1, 1, 1])
      let inputs = try upload([NBConnectomeInput(node: 0, scalar: 1, receptor: 0, reserved: 0,
        weight: 1, scale: 1, bias: 0, clip: 8)])
      let observations = try upload([Float(0), 1])
      let masks = try upload(validity)
      let states = try [upload([Float](repeating: 0, count: 3)), upload([Float](repeating: 0, count: 3))]
      var u = NBConnectomeDispatch(nodes: 3, inputs: 1, readouts: 1, channels: 1,
        step_count: 3, reserved0: 0, reserved1: 0, reserved2: 0,
        time_ratio: timeRatio, output_clip: 1, reserved3: 0, reserved4: 0)
      let v = graph.view
      for (i,o) in [v.nodes_offset, v.offsets_offset, v.sources_offset, v.weights_offset].enumerated() {
        encoder.setBuffer(shared.buffer, offset: Int(o), index: i)
      }
      encoder.setBuffer(inputOffsets, offset: 0, index: 4)
      encoder.setBuffer(inputs, offset: 0, index: 5)
      encoder.setBuffer(observations, offset: 0, index: 6)
      encoder.setBuffer(masks, offset: 0, index: 7)
      encoder.setBytes(&u, length: MemoryLayout<NBConnectomeDispatch>.stride, index: 10)
      encoder.setComputePipelineState(shared.stepPipeline)
      var previous = 0
      for _ in 0..<3 {
        let next = 1-previous
        encoder.setBuffer(states[previous], offset: 0, index: 8)
        encoder.setBuffer(states[next], offset: 0, index: 9)
        encoder.dispatchThreads(MTLSize(width: 3, height: 1, depth: 1),
          threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        encoder.memoryBarrier(scope: .buffers); previous = next
      }
      let outputOffsets = try upload([UInt32(0), 1])
      let readouts = try upload([NBConnectomeReadout(node: 2, channel: 0, weight: 2, reserved: 0)])
      let output = try upload([Float(0)])
      encoder.setBuffer(shared.buffer, offset: Int(v.nodes_offset), index: 0)
      encoder.setBuffer(outputOffsets, offset: 0, index: 1)
      encoder.setBuffer(readouts, offset: 0, index: 2)
      encoder.setBuffer(states[previous], offset: 0, index: 3)
      encoder.setBuffer(output, offset: 0, index: 4)
      encoder.setComputePipelineState(shared.readoutPipeline)
      encoder.dispatchThreads(MTLSize(width: 1, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
      encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
      XCTAssertEqual(command.status, .completed, "\(String(describing: command.error))")
      return (Array(UnsafeBufferPointer(start: states[previous].contents().assumingMemoryBound(to: Float.self), count: 3)),
        output.contents().load(as: Float.self))
    }
    let valid = try evaluate(validity: [0, 1])
    var expected: [Float] = [0, 0, 0]
    for _ in 0..<3 {
      let targets: [Float] = [tanh(Float(1)), tanh(expected[0]), tanh(-expected[1])]
      expected = zip(expected, targets).map { pair in pair.0 + 0.2*(pair.1-pair.0) }
    }
    for i in 0..<3 { XCTAssertEqual(valid.state[i], expected[i], accuracy: 0.00001) }
    XCTAssertGreaterThan(valid.state[0], 0); XCTAssertGreaterThan(valid.state[1], 0); XCTAssertLessThan(valid.state[2], 0)
    // One receptor has two features. Only the selected scalar's mask applies.
    XCTAssertEqual(valid.readout, 2*expected[2], accuracy: 0.00001)
    let masked = try evaluate(validity: [1, 0])
    XCTAssertEqual(masked.state, [0, 0, 0]); XCTAssertEqual(masked.readout, 0)
    let shorter = try evaluate(validity: [0, 1], timeRatio: 0.5)
    let alpha: Float = 1-sqrt(0.8)
    XCTAssertEqual(shorter.state[0], tanh(Float(1))*(1-pow(1-alpha,3)), accuracy: 0.00001)
  }
}
#endif

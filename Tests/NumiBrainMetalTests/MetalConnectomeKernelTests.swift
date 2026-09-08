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
  /// Integration-gain conformance over the actual production shader. These
  /// numerical fixtures are not neural recordings or physical task evidence.
  func testSmallPhysicalStepsDoNotRoundTheUpdateToZero() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let graph = try ConnectomeGraph(data: ConnectomeTestFixture.data())
    let shared = try MetalConnectomeGraph(graph: graph, device: device)
    func upload<T>(_ values: [T]) throws -> any MTLBuffer {
      try XCTUnwrap(values.withUnsafeBytes {
        device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
      })
    }
    let queue = try XCTUnwrap(device.makeCommandQueue())
    let zeroOffsets = try upload([UInt32(0), 0, 0, 0])
    let dummy = try upload([UInt32](repeating: 0, count: 8))
    let old = try upload([Float](repeating: 0, count: 3))
    let pairs: [(Float, Float)] = [(1e-8, 0.5), (0.2, 1e-8), (1e-4, 1e-4),
      (0.06249, 0.999), (0.0625, 0.999), (0.99999994, 0.001), (1, 0.001), (0.2, 1)]
    for (alpha, ratio) in pairs {
      var nodes = try (0..<3).map { try graph.node(at: $0) }
      // Allocate private fixture parameters rather than mutating shared graph bytes.
      nodes[0].alpha = alpha; nodes[0].bias = 1
      let parameters = try upload(nodes), output = try upload([Float](repeating: 0, count: 3))
      let command = try XCTUnwrap(queue.makeCommandBuffer())
      let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
      encoder.setBuffer(parameters, offset: 0, index: 0)
      encoder.setBuffer(zeroOffsets, offset: 0, index: 1)
      encoder.setBuffer(dummy, offset: 0, index: 2); encoder.setBuffer(dummy, offset: 0, index: 3)
      encoder.setBuffer(zeroOffsets, offset: 0, index: 4)
      for slot in 5...7 { encoder.setBuffer(dummy, offset: 0, index: slot) }
      encoder.setBuffer(old, offset: 0, index: 8); encoder.setBuffer(output, offset: 0, index: 9)
      var u = NBConnectomeDispatch(nodes: 3, inputs: 0, readouts: 0, channels: 0,
        step_count: 1, reserved0: 0, reserved1: 0, reserved2: 0,
        time_ratio: ratio, output_clip: 1, reserved3: 0, reserved4: 0)
      encoder.setBytes(&u, length: MemoryLayout<NBConnectomeDispatch>.stride, index: 10)
      encoder.setComputePipelineState(shared.stepPipeline)
      encoder.dispatchThreads(MTLSize(width: 3, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
      encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
      XCTAssertEqual(command.status, .completed)
      guard command.status == .completed else { return }
      let actual = output.contents().load(as: Float.self)
      let gain = alpha == 1 ? 1.0 : -expm1(Double(ratio)*log1p(-Double(alpha)))
      let expected = Float(gain*tanh(1.0))
      XCTAssertGreaterThan(actual, 0, "alpha=\(alpha), ratio=\(ratio)")
      XCTAssertEqual(actual, expected, accuracy: abs(expected)*0.000002,
        "alpha=\(alpha), ratio=\(ratio)")
    }
  }
  /// Exercises the released sparse operator with a declared synthetic state.
  /// This tests all edges on an available Metal device, NOT the Metal 4 owner,
  /// a physical robot, a learned skill, or biological activity reconstruction.
  func testFullReleasedGraphSparseOperatorAgainstSampledReference() throws {
    guard let path = ProcessInfo.processInfo.environment["NUMIBRAIN_CONNECTOME_GRAPH"] else {
      throw XCTSkip("full release pack is not configured")
    }
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let graph = try ConnectomeGraph(contentsOf: URL(fileURLWithPath: path))
    XCTAssertEqual(graph.nodeCount, 166_700); XCTAssertEqual(graph.edgeCount, 25_582_938)
    let sha = BrainPolicyEvidenceArtifact.sha256(graph.bytes)
    XCTAssertEqual(sha, "58314f44a02afe0726e5ba699a533d203b85b2fd6125bc0542b5db72cf993a1c")
    let shared = try MetalConnectomeGraph(graph: graph, device: device)
    let n = graph.nodeCount, v = graph.view
    let previous = (0..<n).map { Float($0 % 31 - 15) / 60 }
    func upload<T>(_ values: [T]) throws -> any MTLBuffer {
      try XCTUnwrap(values.withUnsafeBytes {
        device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
      })
    }
    let old = try upload(previous), next = try upload([Float](repeating: 0, count: n))
    let offsets = try upload([UInt32](repeating: 0, count: n+1))
    let dummy = try upload([UInt32](repeating: 0, count: 8))
    var u = NBConnectomeDispatch(nodes: UInt32(n), inputs: 0, readouts: 0, channels: 0,
      step_count: 1, reserved0: 0, reserved1: 0, reserved2: 0,
      time_ratio: 1, output_clip: 1, reserved3: 0, reserved4: 0)
    let queue = try XCTUnwrap(device.makeCommandQueue()), command = try XCTUnwrap(queue.makeCommandBuffer())
    let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
    for (i, offset) in [v.nodes_offset, v.offsets_offset, v.sources_offset, v.weights_offset].enumerated() {
      encoder.setBuffer(shared.buffer, offset: Int(offset), index: i)
    }
    encoder.setBuffer(offsets, offset: 0, index: 4)
    for i in 5...7 { encoder.setBuffer(dummy, offset: 0, index: i) }
    encoder.setBuffer(old, offset: 0, index: 8); encoder.setBuffer(next, offset: 0, index: 9)
    encoder.setBytes(&u, length: MemoryLayout<NBConnectomeDispatch>.stride, index: 10)
    encoder.setComputePipelineState(shared.stepPipeline)
    encoder.dispatchThreads(MTLSize(width: n, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: shared.stepPipeline.threadExecutionWidth, height: 1, depth: 1))
    encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
    XCTAssertEqual(command.status, .completed, "\(String(describing: command.error))")
    guard command.status == .completed else { return }
    let result = UnsafeBufferPointer(start: next.contents().assumingMemoryBound(to: Float.self), count: n)
    XCTAssertTrue(result.allSatisfy { $0.isFinite && abs($0) <= 1 })
    var maximumError: Float = 0
    let targets = Array(stride(from: 0, to: n, by: max(n/128, 1))) + [n-1]
    try graph.bytes.withUnsafeBytes { bytes in
      for i in targets {
        let node = try graph.node(at: i)
        let start = bytes.loadUnaligned(fromByteOffset: Int(v.offsets_offset)+i*4, as: UInt32.self)
        let end = bytes.loadUnaligned(fromByteOffset: Int(v.offsets_offset)+(i+1)*4, as: UInt32.self)
        var recurrent: Float = 0
        for e in start..<end {
          let source = bytes.loadUnaligned(fromByteOffset: Int(v.sources_offset)+Int(e)*4, as: UInt32.self)
          let weight = bytes.loadUnaligned(fromByteOffset: Int(v.weights_offset)+Int(e)*4, as: Float.self)
          recurrent += weight * previous[Int(source)]
        }
        let alpha: Float = node.alpha == 1 ? 1 : 1-pow(1-node.alpha, Float(1))
        let expected = max(-1, min(1, previous[i]+alpha*(tanh(node.bias+node.recurrent_gain*recurrent)-previous[i])))
        maximumError = max(maximumError, abs(expected-result[i]))
        XCTAssertEqual(result[i], expected, accuracy: 0.00005, "destination \(i)")
      }
    }
    print("NUMIBRAIN_FULL_CONNECTOME_KERNEL nodes=\(n) edges=\(graph.edgeCount) graphSHA256=\(sha) device=\(device.name) referenceDestinations=\(targets.count) maxError=\(maximumError) productionRootExecuted=false")
  }

}
#endif

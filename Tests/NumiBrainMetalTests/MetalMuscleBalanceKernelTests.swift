import Foundation
import Metal
import XCTest
@_spi(NumanXInterop) @testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalMuscleBalanceKernelTests: XCTestCase {
  private func upload<T>(
    _ values: [T],
    device: any MTLDevice
  ) throws -> any MTLBuffer {
    try XCTUnwrap(
      values.withUnsafeBytes {
        device.makeBuffer(
          bytes: $0.baseAddress!,
          length: $0.count,
          options: .storageModeShared
        )
      }
    )
  }

  func testPhysicalSourcesSparseRoutesAndBounds() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let library = try MetalMuscleLocomotorController.makeLibrary(device: device)
    let sourcePipeline = try device.makeComputePipelineState(
      function: XCTUnwrap(
        library.makeFunction(name: "nb_muscle_balance_sources")
      )
    )
    let routePipeline = try device.makeComputePipelineState(
      function: XCTUnwrap(
        library.makeFunction(name: "nb_muscle_balance_routes")
      )
    )
    let queue = try XCTUnwrap(device.makeCommandQueue())

    var sourceWords: [UInt32] = []
    // Vestibular raw 2 - reference 1 = error 1.
    sourceWords += [0, 0, 1, 0]
    sourceWords += [Float(1), 1, 0, 0].map(\.bitPattern)
    // Touch raw 100 - reference 50 = error 50.
    sourceWords += [0, 0, 1, 1]
    sourceWords += [Float(50), 1, 0, 0].map(\.bitPattern)
    let sources = try upload(sourceWords, device: device)

    var routeWords: [UInt32] = []
    // Muscle 0: +0.1 from vestibular, +0.2 from touch.
    routeWords += [0, 0, Float(0.2).bitPattern, Float(0.1).bitPattern]
    routeWords += [1, 0, Float(0.01).bitPattern, Float(0.2).bitPattern]
    // Muscle 1: -0.4 from vestibular.
    routeWords += [0, 0, Float(-1).bitPattern, Float(0.4).bitPattern]
    let routes = try upload(routeWords, device: device)
    let ranges = try upload(
      [
        UInt32(0), 2, 0, 0,
        2, 1, 0, 0,
        // Malformed range must fail closed rather than indexing route 4.
        4, 1, 0, 0,
      ],
      device: device
    )

    func evaluate(
      vestibularRaw: Float = 2,
      vestibularMask: UInt32 = 1,
      touchRaw: Float = 100,
      touchMask: UInt32 = 1,
      feedbackEnabled: UInt32 = 1
    ) throws -> [Float] {
      let vestibular = try upload([vestibularRaw], device: device)
      let vestibularValidity = try upload(
        [vestibularMask], device: device
      )
      let touch = try upload([touchRaw], device: device)
      let touchValidity = try upload([touchMask], device: device)
      let sourceErrors = try upload(
        [Float(-1), -1], device: device
      )
      let sourceValidity = try upload(
        [UInt32.max, UInt32.max], device: device
      )
      let corrections = try upload(
        [Float(-1), -1, -1], device: device
      )
      let uniforms = try upload(
        [UInt32(2), 3, feedbackEnabled, 3], device: device
      )
      let command = try XCTUnwrap(queue.makeCommandBuffer())
      let sourceEncoder = try XCTUnwrap(
        command.makeComputeCommandEncoder()
      )
      sourceEncoder.setComputePipelineState(sourcePipeline)
      for (index, buffer) in [
        vestibular, vestibularValidity, touch, touchValidity, sources,
        sourceErrors, sourceValidity, uniforms,
      ].enumerated() {
        sourceEncoder.setBuffer(buffer, offset: 0, index: index)
      }
      sourceEncoder.dispatchThreads(
        MTLSize(width: 2, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 2, height: 1, depth: 1)
      )
      sourceEncoder.endEncoding()

      let routeEncoder = try XCTUnwrap(
        command.makeComputeCommandEncoder()
      )
      routeEncoder.setComputePipelineState(routePipeline)
      for (index, buffer) in [
        sourceErrors, sourceValidity, routes, ranges, corrections, uniforms,
      ].enumerated() {
        routeEncoder.setBuffer(buffer, offset: 0, index: index)
      }
      routeEncoder.dispatchThreads(
        MTLSize(width: 3, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 3, height: 1, depth: 1)
      )
      routeEncoder.endEncoding()
      command.commit()
      command.waitUntilCompleted()
      XCTAssertEqual(
        command.status, .completed,
        "\(String(describing: command.error))"
      )
      return Array(
        UnsafeBufferPointer(
          start: corrections.contents().assumingMemoryBound(to: Float.self),
          count: 3
        )
      )
    }

    let nominal = try evaluate()
    XCTAssertEqual(nominal[0], 0.3, accuracy: 1e-6)
    XCTAssertEqual(nominal[1], -0.4, accuracy: 1e-6)
    XCTAssertEqual(nominal[2], 0, accuracy: 1e-6)

    let noVestibular = try evaluate(vestibularMask: 0)
    XCTAssertEqual(noVestibular[0], 0.2, accuracy: 1e-6)
    XCTAssertEqual(noVestibular[1], 0, accuracy: 1e-6)
    XCTAssertEqual(noVestibular[2], 0, accuracy: 1e-6)

    XCTAssertEqual(try evaluate(feedbackEnabled: 0), [0, 0, 0])
    XCTAssertEqual(try evaluate(vestibularRaw: .nan), [0.2, 0, 0])
    XCTAssertEqual(try evaluate(touchRaw: .infinity), [0.1, -0.4, 0])
  }

  func testBalancedLocomotorPreservesBaselineAndProtectiveBounds() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let library = try MetalMuscleLocomotorController.makeLibrary(device: device)
    let pipeline = try device.makeComputePipelineState(
      function: XCTUnwrap(
        library.makeFunction(name: "nb_muscle_locomotor_balanced")
      )
    )
    let queue = try XCTUnwrap(device.makeCommandQueue())
    var channelWords = [UInt32(0), 1, 0, 3]
    channelWords += [
      Float(0.25), 0.2, 0, 0, 0, 0, 0.4, 0,
    ].map(\.bitPattern)
    let channels = try upload(channelWords, device: device)

    func evaluate(
      correction: Float,
      valid: UInt32 = 3
    ) throws -> Float {
      let spindle = try upload(
        [Float(0.25), 0], device: device
      )
      let validity = try upload([valid], device: device)
      let logits = try upload([Float(-1)], device: device)
      let uniforms = try upload(
        [UInt32(1), Float(0).bitPattern, 0, 0], device: device
      )
      let corrections = try upload([correction], device: device)
      let command = try XCTUnwrap(queue.makeCommandBuffer())
      let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
      encoder.setComputePipelineState(pipeline)
      for (index, buffer) in [
        spindle, validity, channels, logits, uniforms, corrections,
      ].enumerated() {
        encoder.setBuffer(buffer, offset: 0, index: index)
      }
      encoder.dispatchThreads(
        MTLSize(width: 1, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
      )
      encoder.endEncoding()
      command.commit()
      command.waitUntilCompleted()
      XCTAssertEqual(
        command.status, .completed,
        "\(String(describing: command.error))"
      )
      return tanh(logits.contents().load(as: Float.self))
    }

    XCTAssertEqual(try evaluate(correction: 0), 0.2, accuracy: 1e-6)
    XCTAssertEqual(try evaluate(correction: 0.1), 0.3, accuracy: 1e-6)
    XCTAssertEqual(try evaluate(correction: 1), 0.4, accuracy: 1e-6)
    XCTAssertEqual(try evaluate(correction: -0.5), 0, accuracy: 1e-6)
    XCTAssertEqual(try evaluate(correction: .nan), 0, accuracy: 1e-6)
    XCTAssertEqual(try evaluate(correction: 0.1, valid: 0), 0, accuracy: 1e-6)
  }
}

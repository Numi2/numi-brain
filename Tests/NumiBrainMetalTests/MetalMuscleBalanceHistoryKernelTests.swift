import Foundation
import Metal
import XCTest
@_spi(NumanXInterop) @testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalMuscleBalanceHistoryKernelTests: XCTestCase {
  private struct HistorySource {
    var delayMicroseconds: UInt32
    var filterTimeConstantSeconds: Float
    var reserved0: UInt32 = 0
    var reserved1: UInt32 = 0
  }

  private struct HistoryUniforms {
    var sampleTimestampMicroseconds: UInt64
    var sourceCount: UInt32
    var historyCapacity: UInt32
    var writeIndex: UInt32
    var correctionEnabled: UInt32
    var reserved0: UInt32 = 0
    var reserved1: UInt32 = 0
  }

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

  private func run(
    pipeline: any MTLComputePipelineState,
    queue: any MTLCommandQueue,
    observed: Float,
    observedValidity: UInt32,
    config: HistorySource,
    committedValues: any MTLBuffer,
    committedTimestamps: any MTLBuffer,
    committedValidity: any MTLBuffer,
    committedFilteredValues: any MTLBuffer,
    committedFilteredTimestamps: any MTLBuffer,
    committedFilteredValidity: any MTLBuffer,
    timestamp: UInt64,
    capacity: UInt32,
    writeIndex: UInt32,
    correctionEnabled: UInt32,
    device: any MTLDevice
  ) throws -> (
    values: any MTLBuffer,
    timestamps: any MTLBuffer,
    validity: any MTLBuffer,
    filteredValues: any MTLBuffer,
    filteredTimestamps: any MTLBuffer,
    filteredValidity: any MTLBuffer,
    output: Float,
    outputValidity: UInt32
  ) {
    let observedErrors = try upload([observed], device: device)
    let observedMask = try upload([observedValidity], device: device)
    let configs = try upload([config], device: device)
    let shadowValues = try upload(
      [Float](repeating: -99, count: Int(capacity)), device: device
    )
    let shadowTimestamps = try upload(
      [UInt64](repeating: UInt64.max, count: Int(capacity)), device: device
    )
    let shadowValidity = try upload(
      [UInt32](repeating: UInt32.max, count: Int(capacity)), device: device
    )
    let shadowFilteredValues = try upload([Float(-99)], device: device)
    let shadowFilteredTimestamps = try upload([UInt64.max], device: device)
    let shadowFilteredValidity = try upload([UInt32.max], device: device)
    let outputErrors = try upload([Float(-99)], device: device)
    let outputValidity = try upload([UInt32.max], device: device)
    let uniforms = try upload(
      [
        HistoryUniforms(
          sampleTimestampMicroseconds: timestamp,
          sourceCount: 1,
          historyCapacity: capacity,
          writeIndex: writeIndex,
          correctionEnabled: correctionEnabled
        )
      ],
      device: device
    )

    let command = try XCTUnwrap(queue.makeCommandBuffer())
    let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
    encoder.setComputePipelineState(pipeline)
    for (index, buffer) in [
      observedErrors, observedMask, configs,
      committedValues, committedTimestamps, committedValidity,
      committedFilteredValues, committedFilteredTimestamps,
      committedFilteredValidity, shadowValues, shadowTimestamps,
      shadowValidity, shadowFilteredValues, shadowFilteredTimestamps,
      shadowFilteredValidity, outputErrors, outputValidity, uniforms,
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

    return (
      shadowValues,
      shadowTimestamps,
      shadowValidity,
      shadowFilteredValues,
      shadowFilteredTimestamps,
      shadowFilteredValidity,
      outputErrors.contents().load(as: Float.self),
      outputValidity.contents().load(as: UInt32.self)
    )
  }

  func testDelayedHistoryIsShadowedAndBecomesReadyExactly() throws {
    XCTAssertEqual(MemoryLayout<HistorySource>.stride, 16)
    XCTAssertEqual(MemoryLayout<HistoryUniforms>.stride, 32)
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let library = try MetalMuscleLocomotorController.makeLibrary(device: device)
    let pipeline = try device.makeComputePipelineState(
      function: XCTUnwrap(
        library.makeFunction(name: "nb_muscle_balance_history")
      )
    )
    let queue = try XCTUnwrap(device.makeCommandQueue())
    let capacity: UInt32 = 3
    let committedValues = try upload(
      [Float](repeating: 0, count: Int(capacity)), device: device
    )
    let committedTimestamps = try upload(
      [UInt64](repeating: 0, count: Int(capacity)), device: device
    )
    let committedValidity = try upload(
      [UInt32](repeating: 0, count: Int(capacity)), device: device
    )
    let committedFilteredValues = try upload([Float(0)], device: device)
    let committedFilteredTimestamps = try upload([UInt64(0)], device: device)
    let committedFilteredValidity = try upload([UInt32(0)], device: device)
    let config = HistorySource(
      delayMicroseconds: 1_000,
      filterTimeConstantSeconds: 0
    )

    let warmup = try run(
      pipeline: pipeline,
      queue: queue,
      observed: 0.5,
      observedValidity: 1,
      config: config,
      committedValues: committedValues,
      committedTimestamps: committedTimestamps,
      committedValidity: committedValidity,
      committedFilteredValues: committedFilteredValues,
      committedFilteredTimestamps: committedFilteredTimestamps,
      committedFilteredValidity: committedFilteredValidity,
      timestamp: 0,
      capacity: capacity,
      writeIndex: 0,
      correctionEnabled: 0,
      device: device
    )
    XCTAssertEqual(warmup.output, 0)
    XCTAssertEqual(warmup.outputValidity, 0)
    XCTAssertEqual(
      committedValidity.contents().load(as: UInt32.self), 0,
      "candidate execution must not mutate committed history"
    )
    XCTAssertEqual(warmup.validity.contents().load(as: UInt32.self), 1)
    XCTAssertEqual(warmup.values.contents().load(as: Float.self), 0.5)

    let ready = try run(
      pipeline: pipeline,
      queue: queue,
      observed: 1,
      observedValidity: 1,
      config: config,
      committedValues: warmup.values,
      committedTimestamps: warmup.timestamps,
      committedValidity: warmup.validity,
      committedFilteredValues: warmup.filteredValues,
      committedFilteredTimestamps: warmup.filteredTimestamps,
      committedFilteredValidity: warmup.filteredValidity,
      timestamp: 1_000,
      capacity: capacity,
      writeIndex: 1,
      correctionEnabled: 1,
      device: device
    )
    XCTAssertEqual(ready.outputValidity, 1)
    XCTAssertEqual(ready.output, 0.5, accuracy: 1e-6)
    XCTAssertEqual(ready.filteredValidity.contents().load(as: UInt32.self), 1)
  }

  func testFilterInitializationNeverEmitsOnItsFirstReadyRoot() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let library = try MetalMuscleLocomotorController.makeLibrary(device: device)
    let pipeline = try device.makeComputePipelineState(
      function: XCTUnwrap(
        library.makeFunction(name: "nb_muscle_balance_history")
      )
    )
    let queue = try XCTUnwrap(device.makeCommandQueue())
    let values = try upload([Float(0)], device: device)
    let timestamps = try upload([UInt64(0)], device: device)
    let validity = try upload([UInt32(0)], device: device)
    let prior = try upload([Float(0)], device: device)
    let priorTimestamp = try upload([UInt64(0)], device: device)
    let priorValidity = try upload([UInt32(0)], device: device)
    let config = HistorySource(
      delayMicroseconds: 0,
      filterTimeConstantSeconds: 0.001
    )

    let initialized = try run(
      pipeline: pipeline,
      queue: queue,
      observed: 1,
      observedValidity: 1,
      config: config,
      committedValues: values,
      committedTimestamps: timestamps,
      committedValidity: validity,
      committedFilteredValues: prior,
      committedFilteredTimestamps: priorTimestamp,
      committedFilteredValidity: priorValidity,
      timestamp: 1_000,
      capacity: 1,
      writeIndex: 0,
      correctionEnabled: 1,
      device: device
    )
    XCTAssertEqual(initialized.output, 0)
    XCTAssertEqual(initialized.outputValidity, 0)
    XCTAssertEqual(
      initialized.filteredValues.contents().load(as: Float.self),
      1,
      accuracy: 1e-6
    )
    XCTAssertEqual(
      initialized.filteredValidity.contents().load(as: UInt32.self),
      1
    )

    let ready = try run(
      pipeline: pipeline,
      queue: queue,
      observed: 0,
      observedValidity: 1,
      config: config,
      committedValues: initialized.values,
      committedTimestamps: initialized.timestamps,
      committedValidity: initialized.validity,
      committedFilteredValues: initialized.filteredValues,
      committedFilteredTimestamps: initialized.filteredTimestamps,
      committedFilteredValidity: initialized.filteredValidity,
      timestamp: 2_000,
      capacity: 1,
      writeIndex: 0,
      correctionEnabled: 1,
      device: device
    )
    XCTAssertEqual(ready.outputValidity, 1)
    XCTAssertEqual(ready.output, exp(-1), accuracy: 1e-6)
  }

  func testFilterUsesCommittedStateAndFailsClosedOnMissingSample() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let library = try MetalMuscleLocomotorController.makeLibrary(device: device)
    let pipeline = try device.makeComputePipelineState(
      function: XCTUnwrap(
        library.makeFunction(name: "nb_muscle_balance_history")
      )
    )
    let queue = try XCTUnwrap(device.makeCommandQueue())
    let capacity: UInt32 = 1
    let values = try upload([Float(0)], device: device)
    let timestamps = try upload([UInt64(0)], device: device)
    let validity = try upload([UInt32(0)], device: device)
    let prior = try upload([Float(0)], device: device)
    let priorTimestamp = try upload([UInt64(0)], device: device)
    let priorValidity = try upload([UInt32(1)], device: device)
    let config = HistorySource(
      delayMicroseconds: 0,
      filterTimeConstantSeconds: 0.001
    )

    let filtered = try run(
      pipeline: pipeline,
      queue: queue,
      observed: 1,
      observedValidity: 1,
      config: config,
      committedValues: values,
      committedTimestamps: timestamps,
      committedValidity: validity,
      committedFilteredValues: prior,
      committedFilteredTimestamps: priorTimestamp,
      committedFilteredValidity: priorValidity,
      timestamp: 1_000,
      capacity: capacity,
      writeIndex: 0,
      correctionEnabled: 1,
      device: device
    )
    XCTAssertEqual(filtered.outputValidity, 1)
    XCTAssertEqual(filtered.output, 1 - exp(-1), accuracy: 1e-6)

    let missing = try run(
      pipeline: pipeline,
      queue: queue,
      observed: 1,
      observedValidity: 0,
      config: config,
      committedValues: values,
      committedTimestamps: timestamps,
      committedValidity: validity,
      committedFilteredValues: prior,
      committedFilteredTimestamps: priorTimestamp,
      committedFilteredValidity: priorValidity,
      timestamp: 1_000,
      capacity: capacity,
      writeIndex: 0,
      correctionEnabled: 1,
      device: device
    )
    XCTAssertEqual(missing.output, 0)
    XCTAssertEqual(missing.outputValidity, 0)
  }
}

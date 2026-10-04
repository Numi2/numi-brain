import Foundation
import Metal
import NumiBrainABI
import XCTest

@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalRespiratoryChemoreflexTests: XCTestCase {
  private func upload<T>(_ value: T, device: any MTLDevice) throws -> any MTLBuffer {
    let buffer: (any MTLBuffer)? = withUnsafeBytes(of: value) { rawValue in
      guard let baseAddress = rawValue.baseAddress else { return nil }
      return device.makeBuffer(
        bytes: baseAddress, length: MemoryLayout<T>.stride, options: .storageModeShared
      )
    }
    return try XCTUnwrap(buffer)
  }

  private func pipeline(device: any MTLDevice) throws -> any MTLComputePipelineState {
    let sourceURL = try XCTUnwrap(
      MetalBrainResourceBundle.bundle.url(
        forResource: "RespiratoryChemoreflexV1", withExtension: "metal",
        subdirectory: "Shaders"
      )
        ?? MetalBrainResourceBundle.bundle.url(
          forResource: "RespiratoryChemoreflexV1", withExtension: "metal"
        )
    )
    let shader = try String(contentsOf: sourceURL, encoding: .utf8)
      .replacingOccurrences(
        of: "#include <NumiBrainRespiratoryChemoreflexV1.h>", with: ""
      )
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let headerURL = root.appendingPathComponent(
      "Sources/NumiBrainABI/include/NumiBrainRespiratoryChemoreflexV1.h"
    )
    let header = try String(contentsOf: headerURL, encoding: .utf8)
    let options = MTLCompileOptions()
    options.languageVersion = .version4_0
    options.mathMode = .fast
    options.mathFloatingPointFunctions = .fast
    let library = try device.makeLibrary(source: header + "\n" + shader, options: options)
    return try device.makeComputePipelineState(
      function: XCTUnwrap(
        library.makeFunction(name: "advance_numi_respiratory_chemoreflex_v1")
      ))
  }

  private func dispatch(
    input: NBNumiRespiratoryChemoreflexInputV1,
    baseline: NBNumiRespiratoryChemoreflexStateV1,
    parameters: NBNumiRespiratoryChemoreflexParametersV1,
    pipeline: any MTLComputePipelineState,
    device: any MTLDevice,
    queue: any MTLCommandQueue
  ) throws -> (
    NBNumiRespiratoryChemoreflexStateV1,
    NBNumiRespiratoryChemoreflexOutputV1,
    NBNumiRespiratoryChemoreflexStateV1
  ) {
    let parameterBuffer = try upload(parameters, device: device)
    let inputBuffer = try upload(input, device: device)
    let baselineBuffer = try upload(baseline, device: device)
    var emptyState = NBNumiRespiratoryChemoreflexStateV1()
    let candidateBuffer = try upload(emptyState, device: device)
    var emptyOutput = NBNumiRespiratoryChemoreflexOutputV1()
    let outputBuffer = try upload(emptyOutput, device: device)
    let command = try XCTUnwrap(queue.makeCommandBuffer())
    let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
    encoder.setComputePipelineState(pipeline)
    for (index, buffer) in [
      parameterBuffer, inputBuffer, baselineBuffer,
      candidateBuffer, outputBuffer,
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
    XCTAssertEqual(command.status, .completed, "\(String(describing: command.error))")
    emptyState =
      candidateBuffer.contents()
      .assumingMemoryBound(to: NBNumiRespiratoryChemoreflexStateV1.self).pointee
    emptyOutput =
      outputBuffer.contents()
      .assumingMemoryBound(to: NBNumiRespiratoryChemoreflexOutputV1.self).pointee
    let committedAfter = baselineBuffer.contents()
      .assumingMemoryBound(to: NBNumiRespiratoryChemoreflexStateV1.self).pointee
    return (emptyState, emptyOutput, committedAfter)
  }

  private func sample(
    sourceTime: UInt64 = 1_000_000,
    sourceRoot: UInt64 = 0xCAFE,
    targetTime: UInt64 = 1_250_000,
    targetTransaction: UInt64 = 0xBEEF,
    paO2: Float = 95,
    paCO2: Float = 40,
    flags: UInt32 = UInt32(NB_NUMI_RESPIRATORY_INPUT_ACCEPTED),
    validityMask: UInt32 = UInt32(
      NB_NUMI_RESPIRATORY_VALID_PA_O2 | NB_NUMI_RESPIRATORY_VALID_PA_CO2
    )
  ) -> NBNumiRespiratoryChemoreflexInputV1 {
    var input = NBNumiRespiratoryChemoreflexInputV1()
    input.sourceTimestampMicroseconds = sourceTime
    input.sourceAcceptedRootFingerprint = sourceRoot
    input.targetTimestampMicroseconds = targetTime
    input.targetTransactionFingerprint = targetTransaction
    input.paO2MillimetersMercury = paO2
    input.paCO2MillimetersMercury = paCO2
    input.validityMask = validityMask
    input.flags = flags
    return input
  }

  private func baseline(
    time: UInt64 = 1_000_000,
    root: UInt64 = 0xCAFE,
    centralDrive: Float = 0,
    peripheralDrive: Float = 0,
    phase: Float = 0
  ) -> NBNumiRespiratoryChemoreflexStateV1 {
    var state = NBNumiRespiratoryChemoreflexStateV1()
    state.timestampMicroseconds = time
    state.acceptedRootFingerprint = root
    state.centralCO2DriveLitresPerMinute = centralDrive
    state.peripheralDriveLitresPerMinute = peripheralDrive
    state.respiratoryPhaseCycles = phase
    state.flags = UInt32(NB_NUMI_RESPIRATORY_RECORD_VALID)
    return state
  }

  func testRestingCO2AndHypoxiaMoveTheAcceptedControllerTowardMoreVentilation() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let queue = try XCTUnwrap(device.makeCommandQueue())
    let pipeline = try pipeline(device: device)
    let parameters = NBNumiRespiratoryChemoreflexReferenceParametersV1()
    XCTAssertEqual(MemoryLayout<NBNumiRespiratoryChemoreflexInputV1>.stride, 48)
    XCTAssertEqual(MemoryLayout<NBNumiRespiratoryChemoreflexStateV1>.stride, 32)
    XCTAssertEqual(MemoryLayout<NBNumiRespiratoryChemoreflexOutputV1>.stride, 48)
    XCTAssertEqual(MemoryLayout<NBNumiRespiratoryChemoreflexParametersV1>.stride, 64)

    let rest = try dispatch(
      input: sample(), baseline: baseline(),
      parameters: parameters, pipeline: pipeline, device: device, queue: queue)
    XCTAssertEqual(rest.1.flags, UInt32(NB_NUMI_RESPIRATORY_RECORD_VALID))
    XCTAssertEqual(rest.1.targetMinuteVentilationLitresPerMinute, 6, accuracy: 1e-6)
    XCTAssertEqual(rest.1.targetFrequencyBreathsPerMinute, 12, accuracy: 1e-6)
    XCTAssertEqual(rest.1.targetTidalVolumeLitres, 0.5, accuracy: 1e-6)
    XCTAssertEqual(
      rest.1.diaphragmExcitation, 0.16 * sin(Float.pi * 0.125),
      accuracy: 1e-6)
    XCTAssertEqual(
      rest.1.intercostalExcitation, 0.10 * sin(Float.pi * 0.125),
      accuracy: 1e-6)
    XCTAssertEqual(rest.0.timestampMicroseconds, 1_250_000)
    XCTAssertEqual(rest.0.acceptedRootFingerprint, 0xBEEF)

    let hypercapnia = try dispatch(
      input: sample(paCO2: 45), baseline: baseline(),
      parameters: parameters, pipeline: pipeline, device: device, queue: queue)
    let hypoxia = try dispatch(
      input: sample(paO2: 60), baseline: baseline(),
      parameters: parameters, pipeline: pipeline, device: device, queue: queue)
    XCTAssertGreaterThan(
      hypercapnia.1.targetMinuteVentilationLitresPerMinute,
      rest.1.targetMinuteVentilationLitresPerMinute
    )
    XCTAssertGreaterThan(
      hypoxia.1.targetMinuteVentilationLitresPerMinute,
      rest.1.targetMinuteVentilationLitresPerMinute
    )
    XCTAssertGreaterThan(
      hypercapnia.1.targetFrequencyBreathsPerMinute,
      rest.1.targetFrequencyBreathsPerMinute)
    XCTAssertGreaterThan(
      hypoxia.1.targetTidalVolumeLitres,
      rest.1.targetTidalVolumeLitres)
    XCTAssertEqual(
      rest.2.timestampMicroseconds, 1_000_000,
      "dispatch stages a candidate and never publishes its controller history")
    XCTAssertEqual(rest.2.acceptedRootFingerprint, 0xCAFE)
  }

  func testStaleRootOrRejectedInputDoesNotAdvanceCommittedControllerHistory() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let queue = try XCTUnwrap(device.makeCommandQueue())
    let pipeline = try pipeline(device: device)
    let parameters = NBNumiRespiratoryChemoreflexReferenceParametersV1()
    let accepted = baseline()
    let rejectedSamples = [
      sample(sourceRoot: 0xBAD),
      sample(sourceTime: 999_000),
      sample(targetTime: 1_000_000),
      sample(targetTransaction: 0),
      sample(flags: 0),
      sample(validityMask: UInt32(NB_NUMI_RESPIRATORY_VALID_PA_O2)),
      sample(paCO2: .nan),
    ]
    for input in rejectedSamples {
      let result = try dispatch(
        input: input, baseline: accepted,
        parameters: parameters, pipeline: pipeline, device: device, queue: queue)
      XCTAssertEqual(result.1.flags, 0)
      XCTAssertTrue(result.1.targetMinuteVentilationLitresPerMinute.isNaN)
      XCTAssertEqual(result.0.flags, 0)
      XCTAssertEqual(result.2.timestampMicroseconds, accepted.timestampMicroseconds)
      XCTAssertEqual(
        result.2.acceptedRootFingerprint,
        accepted.acceptedRootFingerprint)
      XCTAssertEqual(
        result.2.respiratoryPhaseCycles,
        accepted.respiratoryPhaseCycles)
    }
  }
}

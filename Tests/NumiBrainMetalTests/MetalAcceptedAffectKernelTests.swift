import Foundation
import Metal
import XCTest
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalAcceptedAffectKernelTests: XCTestCase {
  private func buffer(_ length: Int, device: any MTLDevice) throws -> any MTLBuffer {
    try XCTUnwrap(device.makeBuffer(length: max(length, 64), options: .storageModeShared))
  }

  private func fixture(bodyCount: Int, context: Int, device: any MTLDevice)
    throws -> (any MTLBuffer, AcceptedConsequenceUniforms, any MTLBuffer, any MTLBuffer, UInt32) {
    var u = AcceptedConsequenceUniforms()
    u.targetTimestampMicroseconds = 20_000
    u.deltaMicroseconds = 1_000
    u.touchCount = UInt32(bodyCount * 3)
    u.interoceptionOffset = u.touchCount
    let fullbodyReceptors = max(bodyCount, 1)
    u.interoceptionCount = context == 2 ? 37 : UInt32(fullbodyReceptors * 6)
    u.observationCount = u.touchCount + u.interoceptionCount
    u.observationOffset = 64
    u.observationValidityOffset = u.observationOffset + UInt64(u.observationCount) * 4
    u.sensoryFrameMetadataOffset = (u.observationValidityOffset
      + UInt64(u.observationCount) * 4 + 63) & ~63
    u.affectiveStateOffset = u.sensoryFrameMetadataOffset + 9 * 32
    u.eventQueueOffset = u.affectiveStateOffset + 64
    u.interoceptionFeatureSchemaFingerprint = context == 2 ? 0 : 0x5fe7_3ec8_1265_5efb
    u.affectivePainDecayMicroseconds = 200_000
    u.affectivePleasureDecayMicroseconds = 250_000
    u.affectiveReliefDecayMicroseconds = 150_000
    u.affectiveMaximumEvidenceAgeMicroseconds = 10_000
    u.affectiveRecoveryGain = 0.7
    u.affectiveReliefGain = 0.625
    u.affectiveSourceWeight0 = 0.15
    u.affectiveSourceWeight1 = 0.25
    u.affectiveSourceWeight2 = 0.3
    u.affectiveSourceWeight3 = 0.125
    u.affectiveSourceWeight4 = 0.175
    u.affectiveEnabled = context == 10 ? 0 : 1
    let hot = try buffer(Int(u.eventQueueOffset) + 32 + 64 * 32 + 64, device: device)
    hot.contents().initializeMemory(as: UInt8.self, repeating: 0x5a, count: hot.length)
    func put<T>(_ value: T, _ offset: Int) {
      hot.contents().storeBytes(of: value, toByteOffset: offset, as: T.self)
    }
    for index in 0..<Int(u.observationCount) {
      let value = Float((index * 37 + 19) % 97) / 100
      put(value, Int(u.observationOffset) + index * 4)
      put(UInt32(context == 3 && index == 1 ? 0 : 1),
        Int(u.observationValidityOffset) + index * 4)
    }
    if context == 6 && bodyCount > 0 {
      put(Float.nan, Int(u.observationOffset) + 4)
    }
    // The full-body schema requires complete, calibrated source coverage.
    if context != 2 {
      for receptor in 0..<fullbodyReceptors {
        let base = Int(u.observationOffset) + (Int(u.interoceptionOffset) + receptor * 6) * 4
        for feature in 0..<6 {
          put(Float(feature == 3 ? -0.17 : Float((receptor * 37 + feature * 13 + 19) % 89 + 5) / 100), base + feature * 4)
        }
      }
    }
    let frames = Int(u.sensoryFrameMetadataOffset)
    hot.contents().advanced(by: frames).initializeMemory(as: UInt8.self, repeating: 0, count: 9 * 32)
    func frame(_ index: Int, modality: UInt32, count: UInt32, dimension: UInt32) {
      let offset = frames + index * 32
      put(UInt64(context == 1 ? 18_000 : 19_000), offset)
      put(UInt64(context == 5 ? 19_999 : 20_000), offset + 8)
      put(modality, offset + 16)
      put(count, offset + 20)
      put(dimension, offset + 24)
      put(UInt32(1), offset + 28)
    }
    frame(0, modality: 3, count: u.touchCount, dimension: 1)
    frame(1, modality: 8, count: context == 2 ? 37 : UInt32(fullbodyReceptors), dimension: context == 2 ? 1 : 6)
    let affect = Int(u.affectiveStateOffset)
    for index in 0..<9 { put(Float(0.2 + Float(index) * 0.0625), affect + index * 4) }
    put(UInt16(0x3f), affect + 36)
    put(UInt16(0x3f), affect + 38)
    put(UInt64(context == 9 ? 20_000 : context == 8 ? 0 : 18_000), affect + 40)
    put(UInt64(context == 8 ? 0 : 18_000), affect + 48)
    put(UInt64(context == 8 ? 0 : 18_000), affect + 56)
    let events = Int(u.eventQueueOffset)
    hot.contents().advanced(by: events).initializeMemory(as: UInt8.self, repeating: 0, count: 32 + 64 * 32)
    put(UInt32(context == 7 ? 101 : 57), events)
    put(UInt32(64), events + 4)
    for index in 0..<64 {
      let offset = events + 32 + index * 32
      put(UInt32(1), offset)
      put(UInt32(index % 3 == 0 ? 8 : index % 3 == 1 ? 9 : 2), offset + 4)
      let timestamp: UInt64 = index % 5 == 0 ? 21_000 : index % 5 == 1 ? 1_000 : 19_000
      put(timestamp, offset + 16)
      put(Float(index % 7) * 0.05, offset + 24)
    }

    let bindings = bodyCount * 3
    let table = try buffer(16 + bodyCount * 8 + bindings * 32, device: device)
    table.contents().initializeMemory(as: UInt8.self, repeating: 0, count: table.length)
    table.contents().storeBytes(of: UInt32(bindings), as: UInt32.self)
    table.contents().storeBytes(of: UInt32(bodyCount), toByteOffset: 4, as: UInt32.self)
    for body in 0..<bodyCount {
      table.contents().storeBytes(of: UInt32(body * 3), toByteOffset: 16 + body * 8, as: UInt32.self)
      table.contents().storeBytes(of: UInt32(3), toByteOffset: 20 + body * 8, as: UInt32.self)
      for lane in 0..<3 {
        let index = body * 3 + lane
        let offset = 16 + bodyCount * 8 + index * 32
        table.contents().storeBytes(of: UInt32(context == 4 && index == 1 ? body + 1 : body), toByteOffset: offset, as: UInt32.self)
        table.contents().storeBytes(of: UInt32(6), toByteOffset: offset + 4, as: UInt32.self)
        table.contents().storeBytes(of: UInt32(index), toByteOffset: offset + 8, as: UInt32.self)
        table.contents().storeBytes(of: UInt32(1), toByteOffset: offset + 12, as: UInt32.self)
        table.contents().storeBytes(of: Float(0.75), toByteOffset: offset + 16, as: Float.self)
        table.contents().storeBytes(of: Float(0.05), toByteOffset: offset + 20, as: Float.self)
        table.contents().storeBytes(of: Float((index * 11 + 3) % 17 + 1) / 13,
          toByteOffset: offset + 24, as: Float.self)
      }
    }
    // Opaque interoception exercises the unchanged weighted-fatigue fallback.
    let muscleBindings = 37
    let muscleTable = try buffer(24 + 16 + 8 + muscleBindings * 32, device: device)
    muscleTable.contents().initializeMemory(as: UInt8.self, repeating: 0, count: muscleTable.length)
    muscleTable.contents().storeBytes(of: UInt32(muscleBindings), as: UInt32.self)
    muscleTable.contents().storeBytes(of: UInt32(1), toByteOffset: 4, as: UInt32.self)
    for index in 0..<muscleBindings {
      let offset = 48 + index * 32
      muscleTable.contents().storeBytes(of: UInt32(4), toByteOffset: offset + 4, as: UInt32.self)
      muscleTable.contents().storeBytes(of: u.interoceptionOffset + UInt32(index), toByteOffset: offset + 8, as: UInt32.self)
      muscleTable.contents().storeBytes(of: UInt32(1), toByteOffset: offset + 12, as: UInt32.self)
      muscleTable.contents().storeBytes(of: Float(1), toByteOffset: offset + 16, as: Float.self)
      muscleTable.contents().storeBytes(of: Float(index % 5 + 1) / 7, toByteOffset: offset + 24, as: Float.self)
    }
    return (hot, u, table, muscleTable, context == 11 ? 0 : 1)
  }

  private func execute(hot: any MTLBuffer, uniforms: AcceptedConsequenceUniforms,
    body: any MTLBuffer, muscle: any MTLBuffer, gate: UInt32,
    pipeline: any MTLComputePipelineState, threads: Int,
    device: any MTLDevice, queue: any MTLCommandQueue) throws -> Data {
    let copy = try XCTUnwrap(device.makeBuffer(bytes: hot.contents(), length: hot.length, options: .storageModeShared))
    var uniforms = uniforms
    var gate = gate
    let command = try XCTUnwrap(queue.makeCommandBuffer())
    let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
    encoder.setComputePipelineState(pipeline)
    encoder.setBuffer(copy, offset: 0, index: 0)
    encoder.setBytes(&uniforms, length: MemoryLayout<AcceptedConsequenceUniforms>.stride, index: 1)
    encoder.setBuffer(body, offset: 0, index: 9)
    encoder.setBuffer(muscle, offset: 0, index: 11)
    encoder.setBytes(&gate, length: 4, index: 12)
    encoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: threads, height: 1, depth: 1))
    encoder.endEncoding()
    command.commit()
    command.waitUntilCompleted()
    XCTAssertEqual(command.status, .completed, "\(String(describing: command.error))")
    return Data(bytes: copy.contents(), count: copy.length)
  }

  func testParallelAffectMatchesWholeScalarArenaForFreshStaleMissingAndRejectedEvidence() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let sourceURL = try XCTUnwrap(MetalBrainResourceBundle.bundle.url(forResource: "AcceptedConsequence", withExtension: "metal", subdirectory: "Shaders")
      ?? MetalBrainResourceBundle.bundle.url(forResource: "AcceptedConsequence", withExtension: "metal"))
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    func compile(_ enabled: Int) throws -> any MTLComputePipelineState {
      let options = MTLCompileOptions()
      options.languageVersion = .version4_0
      options.mathMode = .fast
      options.mathFloatingPointFunctions = .fast
      options.preprocessorMacros = ["NB_ACCEPTED_AFFECT_PARALLEL": NSNumber(value: enabled)]
      let library = try device.makeLibrary(source: source, options: options)
      return try device.makeComputePipelineState(function: XCTUnwrap(library.makeFunction(name: "update_accepted_affective_state")))
    }
    XCTAssertEqual(MemoryLayout<AcceptedConsequenceUniforms>.stride, 520)
    let scalar = try compile(0), parallel = try compile(1)
    XCTAssertEqual(parallel.threadExecutionWidth, 32)
    let queue = try XCTUnwrap(device.makeCommandQueue())
    for count in [0, 1, 31, 32, 157, 513] {
      for context in 0..<12 {
        let (hot, u, body, muscle, gate) = try fixture(bodyCount: count, context: context, device: device)
        let expected = try execute(hot: hot, uniforms: u, body: body, muscle: muscle,
          gate: gate, pipeline: scalar, threads: 1, device: device, queue: queue)
        let actual = try execute(hot: hot, uniforms: u, body: body, muscle: muscle,
          gate: gate, pipeline: parallel, threads: 32, device: device, queue: queue)
        if expected != actual {
          let offset = zip(expected, actual).enumerated().first { $0.element.0 != $0.element.1 }!.offset
          XCTFail("bodies=\(count) context=\(context) first differing byte=\(offset) scalar=\(expected[offset]) parallel=\(actual[offset])")
          return
        }
        if context == 9 || context == 11 {
          XCTAssertEqual(actual, Data(bytes: hot.contents(), count: hot.length), "stale time or rejected root must leave the whole arena unchanged")
        }
      }
    }
  }
}

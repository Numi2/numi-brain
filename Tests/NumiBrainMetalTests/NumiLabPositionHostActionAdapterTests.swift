import Metal
import XCTest
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class NumiLabPositionHostActionAdapterTests: XCTestCase {
  private func device() throws -> any MTLDevice {
    try XCTUnwrap(MTLCreateSystemDefaultDevice())
  }

  func testReadsOnlyExactSharedFloatRange() throws {
    let device = try device()
    let values: [Float] = [99, -0.25, 0.5, 1.0, 88]
    let buffer = try XCTUnwrap(device.makeBuffer(
      bytes: values,
      length: values.count * MemoryLayout<Float>.stride,
      options: .storageModeShared
    ))
    let offset = MemoryLayout<Float>.stride
    let result = try NumiLabPositionHostActionAdapter.absolutePositionCommands(
      buffer: buffer,
      gpuAddress: buffer.gpuAddress + UInt64(offset),
      byteCount: 3 * MemoryLayout<Float>.stride,
      scalarCount: 3
    )
    XCTAssertEqual(result, [-0.25, 0.5, 1.0])
  }

  func testRejectsForeignRangeShapeAndNonFiniteValues() throws {
    let device = try device()
    var values: [Float] = [0, .nan, 1]
    let buffer = try XCTUnwrap(device.makeBuffer(
      bytes: &values,
      length: values.count * MemoryLayout<Float>.stride,
      options: .storageModeShared
    ))
    XCTAssertThrowsError(try NumiLabPositionHostActionAdapter.absolutePositionCommands(
      buffer: buffer,
      gpuAddress: buffer.gpuAddress - 1,
      byteCount: values.count * MemoryLayout<Float>.stride,
      scalarCount: values.count
    ))
    XCTAssertThrowsError(try NumiLabPositionHostActionAdapter.absolutePositionCommands(
      buffer: buffer,
      gpuAddress: buffer.gpuAddress,
      byteCount: 2 * MemoryLayout<Float>.stride,
      scalarCount: values.count
    ))
    XCTAssertThrowsError(try NumiLabPositionHostActionAdapter.absolutePositionCommands(
      buffer: buffer,
      gpuAddress: buffer.gpuAddress,
      byteCount: values.count * MemoryLayout<Float>.stride,
      scalarCount: values.count
    ))
  }

  func testRejectsPrivateStorageRatherThanInventingStagingSynchronization() throws {
    let device = try device()
    let byteCount = 4 * MemoryLayout<Float>.stride
    let buffer = try XCTUnwrap(device.makeBuffer(length: byteCount, options: .storageModePrivate))
    XCTAssertThrowsError(try NumiLabPositionHostActionAdapter.absolutePositionCommands(
      buffer: buffer,
      gpuAddress: buffer.gpuAddress,
      byteCount: byteCount,
      scalarCount: 4
    ))
  }
}

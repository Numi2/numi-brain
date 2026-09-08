import Metal
import XCTest
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class NumiLabPositionHostReadinessTests: XCTestCase {
  func testOverflowingShapeIsRejectedBeforeReadingSharedStorage() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let buffer = try XCTUnwrap(device.makeBuffer(length: 16, options: .storageModeShared))
    for count in [Int.max, Int.min, 0, -1, 4097] {
      XCTAssertThrowsError(try NumiLabPositionHostActionAdapter.absolutePositionCommands(
        buffer: buffer, gpuAddress: buffer.gpuAddress, byteCount: 16, scalarCount: count))
    }
  }
  func testManagedStorageIsNotAcceptedAsSynchronizedSharedStorage() throws {
    try NumiLabPositionHostActionAdapter.validateHostReadableStorage(.shared)
    for mode: MTLStorageMode in [.managed, .private, .memoryless] {
      XCTAssertThrowsError(try NumiLabPositionHostActionAdapter.validateHostReadableStorage(mode))
    }
  }
}

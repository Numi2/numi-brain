import Foundation
@preconcurrency import Metal
import NumiBrainCore

@frozen
public struct MetalTeacherStateBufferView: Equatable, Sendable {
  public let gpuAddress: UInt64
  public let scalarCount: UInt32
  public let timestamp: BrainTimestamp
  public let contentFingerprint: UInt64
  /// Application-defined availability bits for body, entity, contact, force,
  /// damage, task, or other privileged labels.
  public let flags: UInt32

  public init(
    gpuAddress: UInt64,
    byteCount: Int,
    scalarCount: UInt32,
    timestamp: BrainTimestamp,
    contentFingerprint: UInt64,
    flags: UInt32
  ) throws {
    let (minimumByteCount, overflow) = Int(scalarCount)
      .multipliedReportingOverflow(by: MemoryLayout<Float>.stride)
    guard gpuAddress > 0, scalarCount > 0, !overflow,
      byteCount >= minimumByteCount, contentFingerprint > 0, flags != 0
    else {
      throw TissueError.transaction("teacher state buffer view is invalid")
    }
    self.gpuAddress = gpuAddress
    self.scalarCount = scalarCount
    self.timestamp = timestamp
    self.contentFingerprint = contentFingerprint
    self.flags = flags
  }
}

/// Training-only privileged state. The buffer is bound exclusively to the
/// accepted learning-transition encoder and is never visible to perception,
/// belief inference, workspace, decision, planning, or motor kernels.
@available(macOS 26.0, *)
public final class MetalTeacherStateBufferLease: @unchecked Sendable {
  public let view: MetalTeacherStateBufferView
  let buffer: any MTLBuffer

  public init(
    buffer: any MTLBuffer,
    scalarCount: UInt32,
    timestamp: BrainTimestamp,
    contentFingerprint: UInt64,
    flags: UInt32
  ) throws {
    self.view = try MetalTeacherStateBufferView(
      gpuAddress: buffer.gpuAddress,
      byteCount: buffer.length,
      scalarCount: scalarCount,
      timestamp: timestamp,
      contentFingerprint: contentFingerprint,
      flags: flags
    )
    self.buffer = buffer
  }
}

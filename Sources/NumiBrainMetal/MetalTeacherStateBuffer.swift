import Foundation
@preconcurrency import Metal
import NumiBrainCore

@frozen
public struct MetalTeacherStateFlags: OptionSet, Codable, Hashable, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  /// The first sixteen FP32 scalars are an actor-space demonstration target.
  public static let demonstratedAction = Self(rawValue: 1 << 31)
}

@frozen
public struct MetalTeacherStateBufferView: Equatable, Sendable {
  public let gpuAddress: UInt64
  public let scalarCount: UInt32
  public let timestamp: BrainTimestamp
  public let contentFingerprint: UInt64
  /// Availability bits for privileged labels. Low bits remain available to
  /// application-defined body/entity/task layouts; standardized flags occupy
  /// the high range so learners never reinterpret an existing label stream.
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

  /// Creates the canonical policy-imitation teacher lane. This allocation is
  /// visible only to the committed-transition encoder and the off-rollout
  /// learner; actor and belief kernels cannot bind it.
  public convenience init(
    device: any MTLDevice,
    demonstratedAction: [Float],
    timestamp: BrainTimestamp
  ) throws {
    guard demonstratedAction.count == 16,
      demonstratedAction.allSatisfy(\.isFinite),
      let buffer = device.makeBuffer(
        length: demonstratedAction.count * MemoryLayout<Float>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.transaction(
        "demonstrated action must contain sixteen finite actor-space scalars"
      )
    }
    demonstratedAction.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      buffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    buffer.label = "NumiBrain training-only demonstrated action"
    var fingerprint: UInt64 = 14_695_981_039_346_656_037
    demonstratedAction.withUnsafeBytes { bytes in
      for byte in bytes {
        fingerprint ^= UInt64(byte)
        fingerprint &*= 1_099_511_628_211
      }
    }
    try self.init(
      buffer: buffer,
      scalarCount: UInt32(demonstratedAction.count),
      timestamp: timestamp,
      contentFingerprint: fingerprint,
      flags: MetalTeacherStateFlags.demonstratedAction.rawValue
    )
  }

  public convenience init(
    device: any MTLDevice,
    demonstratedAction packet: BrainTeacherPacket
  ) throws {
    try self.init(
      device: device,
      demonstratedAction: packet.demonstratedAction,
      timestamp: packet.timestamp
    )
  }
}

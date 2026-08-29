import Foundation
@preconcurrency import Metal
import NumiBrainCore

/// Immutable GPU snapshot of committed rollout transitions from one parameter
/// generation. A learner may retain this batch while rollout resumes because
/// subsequent ring-buffer writes target a different allocation.
@available(macOS 26.0, *)
public final class MetalLearningBatch: @unchecked Sendable {
  public static let formatVersion: UInt32 = 1
  public static let transitionRecordVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let transitionRecordVersion: UInt32
  public let sourceGeneration: UInt64
  public let speciesTemplateFingerprint: UInt64
  public let regionalProgramFingerprint: UInt64
  public let scheduleFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  public let transitionCapacity: Int
  public let transitionStride: Int
  public let byteCount: Int
  public let gpuAddress: UInt64
  public let metadataFingerprint: UInt64
  let buffer: any MTLBuffer

  init(
    snapshot: MetalAgentStateRuntime.PersistentSectionSnapshot,
    speciesTemplateFingerprint: UInt64,
    regionalProgramFingerprint: UInt64,
    scheduleFingerprint: UInt64,
    parameterVersionFingerprint: UInt64
  ) throws {
    let byteCount = snapshot.elementCount * snapshot.elementStride
    guard snapshot.generation > 0, snapshot.elementCount > 0,
      snapshot.elementStride >= 640, byteCount == snapshot.buffer.length,
      speciesTemplateFingerprint > 0, regionalProgramFingerprint > 0,
      scheduleFingerprint > 0, parameterVersionFingerprint > 0
    else {
      throw TissueError.transaction("learning batch identity or layout is invalid")
    }
    var hash: UInt64 = 14_695_981_039_346_656_037
    for value in [
      UInt64(Self.formatVersion), UInt64(Self.transitionRecordVersion),
      snapshot.generation, speciesTemplateFingerprint,
      regionalProgramFingerprint, scheduleFingerprint,
      parameterVersionFingerprint, UInt64(snapshot.elementCount),
      UInt64(snapshot.elementStride), UInt64(byteCount),
    ] {
      Self.mix(value, into: &hash)
    }
    self.formatVersion = Self.formatVersion
    self.transitionRecordVersion = Self.transitionRecordVersion
    self.sourceGeneration = snapshot.generation
    self.speciesTemplateFingerprint = speciesTemplateFingerprint
    self.regionalProgramFingerprint = regionalProgramFingerprint
    self.scheduleFingerprint = scheduleFingerprint
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.transitionCapacity = snapshot.elementCount
    self.transitionStride = snapshot.elementStride
    self.byteCount = byteCount
    self.gpuAddress = snapshot.buffer.gpuAddress
    self.metadataFingerprint = hash
    self.buffer = snapshot.buffer
  }

  public var residencyAllocation: any MTLAllocation { buffer }

  public var metalBufferObject: UnsafeMutableRawPointer {
    Unmanaged.passUnretained(buffer as AnyObject).toOpaque()
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    var value = value.littleEndian
    withUnsafeBytes(of: &value) { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }
}

import Foundation
@preconcurrency import Metal
import NumiBrainCore

/// Retains the immutable shared Metal allocation while an external batch
/// learner imports its unified-memory address. The lease never exposes the
/// mutable rollout ring from which the snapshot was frozen.
@available(macOS 26.0, *)
public final class MetalLearningBatchStorageLease: @unchecked Sendable {
  public let baseAddress: UnsafeMutableRawPointer
  public let byteCount: Int

  private let buffer: any MTLBuffer

  fileprivate init(buffer: any MTLBuffer) throws {
    guard buffer.storageMode == .shared, buffer.length > 0 else {
      throw TissueError.transaction("learning batch is not shared unified memory")
    }
    self.baseAddress = buffer.contents()
    self.byteCount = buffer.length
    self.buffer = buffer
  }
}

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
  public let contentFingerprint: UInt64
  public let batchFingerprint: UInt64
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
    guard snapshot.buffer.storageMode == .shared else {
      throw TissueError.transaction("learning batch snapshot is not unified memory")
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
    var contentHash: UInt64 = 14_695_981_039_346_656_037
    let bytes = UnsafeRawBufferPointer(
      start: snapshot.buffer.contents(), count: byteCount
    )
    for byte in bytes {
      contentHash ^= UInt64(byte)
      contentHash &*= 1_099_511_628_211
    }
    var batchHash = hash
    Self.mix(contentHash, into: &batchHash)
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
    self.contentFingerprint = contentHash
    self.batchFingerprint = batchHash
    self.buffer = snapshot.buffer
  }

  public var residencyAllocation: any MTLAllocation { buffer }

  public var metalBufferObject: UnsafeMutableRawPointer {
    Unmanaged.passUnretained(buffer as AnyObject).toOpaque()
  }

  /// Creates a lifetime-safe zero-copy import lease for MLX. This is a learner
  /// synchronization boundary, never a production stepping-path readback.
  public func makeSharedStorageLease() throws -> MetalLearningBatchStorageLease {
    try MetalLearningBatchStorageLease(buffer: buffer)
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

import Foundation
import NumiBrainCore

@frozen
public struct MetalArchivePagePayload: Codable, Equatable, Sendable {
  public static let currentFormatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let pageIdentifier: UInt32
  public let sourceGeneration: UInt64
  public let pageEpoch: UInt64
  public let memoryLayoutFingerprint: UInt64
  public let recordLayoutVersion: UInt32
  public let recordStride: UInt32
  public let recordCount: UInt32
  public let checksum: UInt64
  public let bytes: Data

  public init(
    pageIdentifier: UInt32,
    sourceGeneration: UInt64,
    pageEpoch: UInt64,
    memoryLayoutFingerprint: UInt64,
    recordLayoutVersion: UInt32,
    recordStride: UInt32,
    recordCount: UInt32,
    bytes: Data
  ) throws {
    guard memoryLayoutFingerprint > 0, recordStride > 0, recordCount > 0,
      Int(recordStride) * Int(recordCount) == bytes.count,
      bytes.count % MemoryLayout<UInt32>.stride == 0
    else {
      throw TissueError.transaction("archive page payload shape is invalid")
    }
    formatVersion = Self.currentFormatVersion
    self.pageIdentifier = pageIdentifier
    self.sourceGeneration = sourceGeneration
    self.pageEpoch = pageEpoch
    self.memoryLayoutFingerprint = memoryLayoutFingerprint
    self.recordLayoutVersion = recordLayoutVersion
    self.recordStride = recordStride
    self.recordCount = recordCount
    self.bytes = bytes
    checksum = Self.checksum(
      pageIdentifier: pageIdentifier,
      sourceGeneration: sourceGeneration,
      pageEpoch: pageEpoch,
      memoryLayoutFingerprint: memoryLayoutFingerprint,
      recordLayoutVersion: recordLayoutVersion,
      recordStride: recordStride,
      recordCount: recordCount,
      bytes: bytes
    )
  }

  public func validateChecksum() -> Bool {
    formatVersion == Self.currentFormatVersion && checksum == Self.checksum(
      pageIdentifier: pageIdentifier,
      sourceGeneration: sourceGeneration,
      pageEpoch: pageEpoch,
      memoryLayoutFingerprint: memoryLayoutFingerprint,
      recordLayoutVersion: recordLayoutVersion,
      recordStride: recordStride,
      recordCount: recordCount,
      bytes: bytes
    )
  }

  private static func checksum(
    pageIdentifier: UInt32,
    sourceGeneration: UInt64,
    pageEpoch: UInt64,
    memoryLayoutFingerprint: UInt64,
    recordLayoutVersion: UInt32,
    recordStride: UInt32,
    recordCount: UInt32,
    bytes: Data
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    func mix(_ value: UInt64) {
      var value = value
      for _ in 0..<8 {
        hash ^= value & 0xff
        hash &*= 1_099_511_628_211
        value >>= 8
      }
    }
    mix(UInt64(currentFormatVersion))
    mix(UInt64(pageIdentifier))
    mix(sourceGeneration)
    mix(pageEpoch)
    mix(memoryLayoutFingerprint)
    mix(UInt64(recordLayoutVersion))
    mix(UInt64(recordStride))
    mix(UInt64(recordCount))
    for byte in bytes {
      hash ^= UInt64(byte)
      hash &*= 1_099_511_628_211
    }
    return hash
  }
}

/// One compact Tier-2 page request emitted by committed GPU retrieval. The
/// archive worker may satisfy requests asynchronously; motor control never
/// waits for the corresponding page.
@frozen
public struct MetalArchivePageRequest: Codable, Equatable, Hashable, Sendable {
  public let pageIdentifier: UInt32
  public let requestedTimestamp: BrainTimestamp
  public let targetRecordIdentifier: UInt64
  public let priority: Float
  public let flags: UInt32

  public init(
    pageIdentifier: UInt32,
    requestedTimestamp: BrainTimestamp,
    targetRecordIdentifier: UInt64,
    priority: Float,
    flags: UInt32
  ) throws {
    guard priority.isFinite, (0...1).contains(priority) else {
      throw TissueError.transaction("archive page request priority is invalid")
    }
    self.pageIdentifier = pageIdentifier
    self.requestedTimestamp = requestedTimestamp
    self.targetRecordIdentifier = targetRecordIdentifier
    self.priority = priority
    self.flags = flags
  }
}

/// Immutable orchestration snapshot of requests committed by an agent. An
/// overflow count is explicit so the archive worker can respond by broadening
/// residency rather than silently losing demand.
@frozen
public struct MetalArchivePageRequestSnapshot: Codable, Equatable, Sendable {
  public let committedGeneration: UInt64
  public let pageCount: UInt32
  public let overflowCount: UInt32
  public let requests: [MetalArchivePageRequest]

  public init(
    committedGeneration: UInt64,
    pageCount: UInt32,
    overflowCount: UInt32,
    requests: [MetalArchivePageRequest]
  ) throws {
    guard requests.allSatisfy({ $0.pageIdentifier < pageCount }) else {
      throw TissueError.transaction("archive request references an unknown page")
    }
    self.committedGeneration = committedGeneration
    self.pageCount = pageCount
    self.overflowCount = overflowCount
    self.requests = requests
  }
}

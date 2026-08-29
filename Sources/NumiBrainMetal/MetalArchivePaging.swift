import Foundation
import NumiBrainCore

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

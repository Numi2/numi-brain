import Foundation

/// Version 2 can retain a missing/malformed observation without inventing a
/// process ID, root, generation or timestamp. expectedProcessInstance comes
/// from the independently configured supervisor, not from the heartbeat file.
@frozen
public struct WatchdogStopRequest: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 2
  public let formatVersion: UInt32
  public let watchdogInstance: UUID
  public let expectedProcessInstance: UUID
  public let observed: WatchdogHeartbeat?
  public let reason: String
  public let createdUnixNanoseconds: UInt64

  public var observedProcessInstance: UUID? { observed?.processInstance }
  public var observedSequence: UInt64? { observed?.sequence }
  public var observedPublicGeneration: UInt64? { observed?.publicGeneration }
  public var observedTransactionFingerprint: UInt64? { observed?.transactionFingerprint }

  public init(watchdogInstance: UUID, observed: WatchdogHeartbeat, reason: String,
    createdUnixNanoseconds: UInt64) throws {
    try self.init(watchdogInstance: watchdogInstance, expectedProcessInstance: observed.processInstance,
      observed: observed, reason: reason, createdUnixNanoseconds: createdUnixNanoseconds)
  }

  public init(watchdogInstance: UUID, expectedProcessInstance: UUID, observed: WatchdogHeartbeat?,
    reason: String, createdUnixNanoseconds: UInt64) throws {
    formatVersion = Self.formatVersion; self.watchdogInstance = watchdogInstance
    self.expectedProcessInstance = expectedProcessInstance; self.observed = observed
    self.reason = reason; self.createdUnixNanoseconds = createdUnixNanoseconds
    try validate()
  }

  public func validate() throws {
    if let observed { try observed.validate() }
    guard formatVersion == Self.formatVersion, !reason.isEmpty, reason.utf8.count <= 512,
      createdUnixNanoseconds > 0 else { throw QualificationError.invalid("invalid watchdog stop request") }
  }
}

/// Off-rollout liveness file transport. A marker requests a safe state; only
/// an independently wired consumer can actually enforce and acknowledge it.
public enum WatchdogFileProtocol {
  public static let maximumBytes = 64 * 1024

  public static func readHeartbeat(_ url: URL) throws -> WatchdogHeartbeat {
    let value = try JSONDecoder().decode(WatchdogHeartbeat.self,
      from: QualificationFileDirectory.readFile(url, maximumBytes: maximumBytes))
    try value.validate(); return value
  }

  public static func publishHeartbeat(_ heartbeat: WatchdogHeartbeat, to url: URL) throws {
    try heartbeat.validate()
    let bytes = try QualificationFileDirectory.canonicalJSON(heartbeat)
    guard bytes.count <= maximumBytes else { throw QualificationFileError.sizeLimit }
    try QualificationFileDirectory(url: url.deletingLastPathComponent())
      .publish(bytes, named: url.lastPathComponent, replaceExisting: true, durable: false)
  }

  public static func readStopRequestIfPresent(_ url: URL) throws -> WatchdogStopRequest? {
    let directory = try QualificationFileDirectory(url: url.deletingLastPathComponent())
    guard let bytes = try directory.readIfPresent(url.lastPathComponent, maximumBytes: maximumBytes) else { return nil }
    let request = try JSONDecoder().decode(WatchdogStopRequest.self, from: bytes)
    try request.validate(); return request
  }

  /// Sticky create-only publication. The first fault remains visible until the
  /// independent recovery owner deliberately clears it, outside this API.
  public static func publishStopRequest(_ request: WatchdogStopRequest, to url: URL) throws {
    try request.validate()
    let bytes = try QualificationFileDirectory.canonicalJSON(request)
    guard bytes.count <= maximumBytes else { throw QualificationFileError.sizeLimit }
    let directory = try QualificationFileDirectory(url: url.deletingLastPathComponent())
    if try !directory.publish(bytes, named: url.lastPathComponent) {
      let existing = try JSONDecoder().decode(WatchdogStopRequest.self,
        from: directory.read(url.lastPathComponent, maximumBytes: maximumBytes))
      try existing.validate()
    }
  }
}

public struct WatchdogDecision: Codable, Equatable, Sendable {
  public let status: WatchdogStatus
  public let mustRequestSafeState: Bool
  public let reason: String?

  fileprivate init(status: WatchdogStatus, reason: String?) {
    self.status = status; mustRequestSafeState = status != .healthy; self.reason = reason
  }

  public init(previous: WatchdogHeartbeat?, current: WatchdogHeartbeat,
    nowNanoseconds: UInt64, maximumAgeNanoseconds: UInt64) throws {
    let status = try WatchdogVerifier.status(previous: previous, current: current,
      nowNanoseconds: nowNanoseconds, maximumAgeNanoseconds: maximumAgeNanoseconds)
    self.init(status: status, reason: status == .healthy ? nil : "heartbeat_" + status.rawValue)
  }
}

/// Stateful deterministic monitor. Polling continues across checks; a restart,
/// stale or malformed observation latches safe-state request until the owner
/// performs recovery and creates a new monitor for an approved process UUID.
public struct WatchdogMonitor: Sendable {
  public let expectedProcessInstance: UUID
  public let maximumAgeNanoseconds: UInt64
  public let maximumProgressAgeNanoseconds: UInt64
  public private(set) var lastHeartbeat: WatchdogHeartbeat?
  private var lastObservationTime: UInt64?
  private var lastProgressTime: UInt64?
  private var latched: WatchdogDecision?

  public init(expectedProcessInstance: UUID, maximumAgeNanoseconds: UInt64,
    maximumProgressAgeNanoseconds: UInt64) throws {
    guard maximumAgeNanoseconds > 0, maximumProgressAgeNanoseconds >= maximumAgeNanoseconds else {
      throw QualificationError.invalid("invalid heartbeat/progress deadlines")
    }
    self.expectedProcessInstance = expectedProcessInstance; self.maximumAgeNanoseconds = maximumAgeNanoseconds
    self.maximumProgressAgeNanoseconds = maximumProgressAgeNanoseconds
  }

  public mutating func observe(_ heartbeat: WatchdogHeartbeat?, readFailed: Bool = false,
    nowNanoseconds: UInt64) -> WatchdogDecision {
    if let latched { return latched }
    func failure(_ status: WatchdogStatus, _ reason: String) -> WatchdogDecision {
      WatchdogDecision(status: status, reason: reason)
    }
    let result: WatchdogDecision
    if let priorTime = lastObservationTime, nowNanoseconds < priorTime {
      result = failure(.malformed, "watchdog_clock_regressed")
    } else if readFailed {
      result = failure(.malformed, "heartbeat_unreadable_or_malformed")
    } else if let heartbeat {
      if heartbeat.processInstance != expectedProcessInstance {
        result = failure(.restarted, "process_restart_requires_joint_recovery")
      } else {
        do {
          let check = try WatchdogDecision(previous: lastHeartbeat, current: heartbeat,
            nowNanoseconds: nowNanoseconds, maximumAgeNanoseconds: maximumAgeNanoseconds)
          if check.mustRequestSafeState { result = check }
          else {
            if lastProgressTime == nil || lastHeartbeat.map({ heartbeat.publicGeneration > $0.publicGeneration }) == true {
              lastProgressTime = nowNanoseconds
            }
            if let progress = lastProgressTime, nowNanoseconds - progress > maximumProgressAgeNanoseconds {
              result = failure(.stale, "committed_progress_stalled")
            } else { result = check; lastHeartbeat = heartbeat }
          }
        } catch { result = failure(.malformed, "heartbeat_identity_or_clock_invalid") }
      }
    } else { result = failure(.missing, "heartbeat_missing") }
    lastObservationTime = nowNanoseconds
    if result.mustRequestSafeState { latched = result }
    return result
  }
}

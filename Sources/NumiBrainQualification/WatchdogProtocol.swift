import Foundation

@frozen
public struct WatchdogStopRequest: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let watchdogInstance: UUID
  public let observedProcessInstance: UUID
  public let observedSequence: UInt64
  public let observedPublicGeneration: UInt64
  public let observedTransactionFingerprint: UInt64
  public let reason: String
  public let createdUnixNanoseconds: UInt64

  public init(watchdogInstance: UUID, observed: WatchdogHeartbeat, reason: String,
    createdUnixNanoseconds: UInt64) throws {
    guard !reason.isEmpty, reason.utf8.count <= 512, createdUnixNanoseconds > 0 else {
      throw QualificationError.invalid("watchdog stop request is invalid")
    }
    formatVersion = Self.formatVersion
    self.watchdogInstance = watchdogInstance
    observedProcessInstance = observed.processInstance
    observedSequence = observed.sequence
    observedPublicGeneration = observed.publicGeneration
    observedTransactionFingerprint = observed.transactionFingerprint
    self.reason = reason
    self.createdUnixNanoseconds = createdUnixNanoseconds
  }
}

/// Independent-process file protocol. Writers publish via atomic replacement;
/// readers require regular files and bounded payloads. This is a liveness/safe-
/// state protocol, not cryptographic authentication of an untrusted host.
public enum WatchdogFileProtocol {
  public static let maximumBytes = 64 * 1024

  public static func readHeartbeat(_ url: URL) throws -> WatchdogHeartbeat {
    let values = try FileManager.default.attributesOfItem(atPath: url.path)
    guard values[.type] as? FileAttributeType == .typeRegular,
      let size = values[.size] as? NSNumber, size.intValue > 0, size.intValue <= maximumBytes else {
      throw QualificationError.invalid("heartbeat is not a bounded regular file")
    }
    let data = try Data(contentsOf: url, options: [.mappedIfSafe])
    return try JSONDecoder().decode(WatchdogHeartbeat.self, from: data)
  }

  public static func publishHeartbeat(_ heartbeat: WatchdogHeartbeat, to url: URL) throws {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(heartbeat)
    guard !data.isEmpty, data.count <= maximumBytes else { throw QualificationError.invalid("heartbeat payload size") }
    try data.write(to: url, options: [.atomic])
  }

  public static func publishStopRequest(_ request: WatchdogStopRequest, to url: URL) throws {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(request)
    guard !data.isEmpty, data.count <= maximumBytes else { throw QualificationError.invalid("stop payload size") }
    // A stop request is sticky. Never replace an existing request with a later
    // reason that could hide the first observed deployment failure.
    guard !FileManager.default.fileExists(atPath: url.path) else { return }
    let temporary = url.deletingLastPathComponent().appendingPathComponent(".watchdog-\(UUID().uuidString).tmp")
    try data.write(to: temporary, options: [.atomic])
    do {
      try FileManager.default.moveItem(at: temporary, to: url)
    } catch {
      try? FileManager.default.removeItem(at: temporary)
      if FileManager.default.fileExists(atPath: url.path) { return }
      throw error
    }
  }
}

public struct WatchdogDecision: Codable, Equatable, Sendable {
  public let status: WatchdogStatus
  public let mustRequestSafeState: Bool
  public let reason: String?

  public init(previous: WatchdogHeartbeat?, current: WatchdogHeartbeat,
    nowNanoseconds: UInt64, maximumAgeNanoseconds: UInt64) throws {
    status = try WatchdogVerifier.status(previous: previous, current: current,
      nowNanoseconds: nowNanoseconds, maximumAgeNanoseconds: maximumAgeNanoseconds)
    switch status {
    case .healthy:
      mustRequestSafeState = false; reason = nil
    case .restarted:
      // A restart is observable but not itself proof that state is unsafe;
      // recovery authority decides whether the new process can resume.
      mustRequestSafeState = false; reason = "process_restart_requires_recovery_verification"
    case .stale:
      mustRequestSafeState = true; reason = "heartbeat_stale"
    case .regressed:
      mustRequestSafeState = true; reason = "heartbeat_regressed"
    }
  }
}

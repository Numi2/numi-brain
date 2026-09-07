import Dispatch
import Foundation

/// One fresh, private artifact directory per supervised owner process. These
/// files coordinate cooperating processes; they do not authenticate a writer.
public struct WatchdogOwnerFileConfiguration: Codable, Equatable, Sendable {
  public let processInstance: UUID
  public let enforcerInstance: UUID
  public let directoryPath: String
  public let heartbeatName: String
  public let stopRequestName: String
  public let acknowledgementName: String
  public static let writerLockName = ".watchdog-owner.lock"

  public init(processInstance: UUID, enforcerInstance: UUID, directoryPath: String,
    heartbeatName: String = "heartbeat.json", stopRequestName: String = "stop.json",
    acknowledgementName: String = "stop-ack.json") throws {
    self.processInstance = processInstance; self.enforcerInstance = enforcerInstance
    self.directoryPath = directoryPath; self.heartbeatName = heartbeatName
    self.stopRequestName = stopRequestName; self.acknowledgementName = acknowledgementName
    try validate()
  }

  public func validate() throws {
    let names = [heartbeatName, stopRequestName, acknowledgementName, Self.writerLockName, ".watchdog-supervisor.lock"]
    guard directoryPath.hasPrefix("/"), !directoryPath.utf8.contains(0),
      !directoryPath.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }),
      Set(names).count == names.count, names.allSatisfy({
        !$0.isEmpty && $0 != "." && $0 != ".." && $0.utf8.count <= 255
          && !$0.contains("/") && !$0.utf8.contains(0)
      }) else { throw QualificationError.invalid("invalid watchdog owner file configuration") }
  }

  private enum CodingKeys: String, CodingKey {
    case processInstance, enforcerInstance, directoryPath, heartbeatName, stopRequestName, acknowledgementName
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(processInstance: c.decode(UUID.self, forKey: .processInstance),
      enforcerInstance: c.decode(UUID.self, forKey: .enforcerInstance),
      directoryPath: c.decode(String.self, forKey: .directoryPath),
      heartbeatName: c.decodeIfPresent(String.self, forKey: .heartbeatName) ?? "heartbeat.json",
      stopRequestName: c.decodeIfPresent(String.self, forKey: .stopRequestName) ?? "stop.json",
      acknowledgementName: c.decodeIfPresent(String.self, forKey: .acknowledgementName) ?? "stop-ack.json")
  }
}

/// Off-rollout file transport around the native-owner admission interlock.
/// Poll at submission and terminal reporting boundaries. This does not cancel
/// a stuck GPU command; the independent supervisor must escalate missing ACKs.
public final class WatchdogOwnerFileSession: @unchecked Sendable {
  public let configuration: WatchdogOwnerFileConfiguration
  private let directory: QualificationFileDirectory
  private let writerLock: FileHandle
  private let interlock: WatchdogRootInterlock
  private let lock = NSLock()
  private var active = false
  private var failed = false
  private var acknowledgement: WatchdogStopAcknowledgement?

  public init(configuration: WatchdogOwnerFileConfiguration) throws {
    try configuration.validate()
    self.configuration = configuration
    directory = try QualificationFileDirectory(url: URL(fileURLWithPath: configuration.directoryPath, isDirectory: true))
    writerLock = try directory.acquireExclusiveWriterLock(named: WatchdogOwnerFileConfiguration.writerLockName)
    interlock = WatchdogRootInterlock(expectedProcessInstance: configuration.processInstance,
      enforcerInstance: configuration.enforcerInstance)
    // No restart may reuse a prior heartbeat/acknowledgement as live authority.
    for name in [configuration.heartbeatName, configuration.acknowledgementName] {
      guard try directory.readIfPresent(name, maximumBytes: WatchdogFileProtocol.maximumBytes) == nil else {
        throw QualificationError.invalid("watchdog owner requires a fresh heartbeat and acknowledgement namespace")
      }
    }
    if let request = try readStop() { try interlock.latchStop(request) }
  }

  public var lastSettledHeartbeat: WatchdogHeartbeat? { interlock.lastSettledHeartbeat }
  public var admissionClosed: Bool { interlock.admissionClosed }

  public func beginRoot(nowNanoseconds: UInt64) throws -> WatchdogRootInterlock.Permit {
    lock.lock(); defer { lock.unlock() }
    try pollLocked(nowNanoseconds: nowNanoseconds)
    let permit = try interlock.beginRoot()
    active = true
    return permit
  }

  @discardableResult
  public func recordSettledRoot(_ permit: WatchdogRootInterlock.Permit, publicGeneration: UInt64,
    transactionFingerprint: UInt64, settledMonotonicNanoseconds: UInt64,
    terminalEvidenceArtifactSHA256: String) throws -> WatchdogHeartbeat {
    lock.lock(); defer { lock.unlock() }
    do {
      let heartbeat = try interlock.recordSettledRoot(permit, publicGeneration: publicGeneration,
        transactionFingerprint: transactionFingerprint, settledMonotonicNanoseconds: settledMonotonicNanoseconds,
        terminalEvidenceArtifactSHA256: terminalEvidenceArtifactSHA256)
      active = false
      try directory.publish(QualificationFileDirectory.canonicalJSON(heartbeat), named: configuration.heartbeatName,
        replaceExisting: true, durable: false)
      try pollLocked(nowNanoseconds: settledMonotonicNanoseconds)
      return heartbeat
    } catch { failed = true; interlock.failClosed(); throw error }
  }

  public func recordIndeterminateRoot(_ permit: WatchdogRootInterlock.Permit) throws {
    lock.lock(); defer { lock.unlock() }
    try interlock.recordIndeterminateRoot(permit)
    active = false; failed = true
  }

  public func failClosed() {
    lock.lock(); defer { lock.unlock() }
    failed = true; interlock.failClosed()
  }

  /// May also be invoked by the orchestration owner while idle. Removing a stop
  /// file does not reopen admission. Repeated polling retains the exact first
  /// acknowledgement bytes instead of changing its timestamp on every call.
  public func poll(nowNanoseconds: UInt64) throws {
    lock.lock(); defer { lock.unlock() }
    try pollLocked(nowNanoseconds: nowNanoseconds)
  }

  private func pollLocked(nowNanoseconds: UInt64) throws {
    do {
      guard nowNanoseconds > 0 else { throw QualificationError.invalid("invalid watchdog owner clock") }
      if let request = try readStop() {
        try interlock.latchStop(request)
      } else if interlock.retainedStopRequest != nil {
        throw QualificationError.invalid("latched watchdog stop was removed without joint recovery")
      }
      if !active, !failed, interlock.retainedStopRequest != nil, interlock.lastSettledHeartbeat != nil {
        if acknowledgement == nil {
          acknowledgement = try interlock.makeSimulationAcknowledgement(nowNanoseconds: DispatchTime.now().uptimeNanoseconds)
        }
        let value = acknowledgement!
        let bytes = try QualificationFileDirectory.canonicalJSON(value)
        guard bytes.count <= WatchdogFileProtocol.maximumBytes else { throw QualificationFileError.sizeLimit }
        if try !directory.publish(bytes, named: configuration.acknowledgementName) {
          let existing = try JSONDecoder().decode(WatchdogStopAcknowledgement.self,
            from: directory.read(configuration.acknowledgementName, maximumBytes: WatchdogFileProtocol.maximumBytes))
          guard existing == value else { throw QualificationError.invalid("conflicting watchdog owner acknowledgement") }
        }
      }
    } catch { failed = true; interlock.failClosed(); throw error }
  }

  private func readStop() throws -> WatchdogStopRequest? {
    guard let bytes = try directory.readIfPresent(configuration.stopRequestName,
      maximumBytes: WatchdogFileProtocol.maximumBytes) else { return nil }
    let request = try JSONDecoder().decode(WatchdogStopRequest.self, from: bytes)
    try request.validate(); return request
  }
}

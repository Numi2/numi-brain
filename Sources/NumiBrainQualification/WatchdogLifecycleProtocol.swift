import Foundation

/// Supervisor-created, create-only bootstrap authority. The monotonic creation
/// time and ready age travel WITH the incident namespace so a restarted
/// supervisor cannot silently grant a fresh startup deadline.
public struct WatchdogSupervisorArm: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let supervisorInstance: UUID
  public let expectedProcessInstance: UUID
  public let expectedEnforcerInstance: UUID
  public let createdMonotonicNanoseconds: UInt64
  public let maximumReadyAgeNanoseconds: UInt64

  public init(supervisorInstance: UUID, expectedProcessInstance: UUID,
    expectedEnforcerInstance: UUID, createdMonotonicNanoseconds: UInt64,
    maximumReadyAgeNanoseconds: UInt64) throws {
    formatVersion = Self.formatVersion
    self.supervisorInstance = supervisorInstance
    self.expectedProcessInstance = expectedProcessInstance
    self.expectedEnforcerInstance = expectedEnforcerInstance
    self.createdMonotonicNanoseconds = createdMonotonicNanoseconds
    self.maximumReadyAgeNanoseconds = maximumReadyAgeNanoseconds
    try validate()
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion, createdMonotonicNanoseconds > 0,
      maximumReadyAgeNanoseconds > 0 else {
      throw QualificationError.invalid("invalid watchdog supervisor arm")
    }
  }

  private enum CodingKeys: String, CodingKey {
    case formatVersion, supervisorInstance, expectedProcessInstance
    case expectedEnforcerInstance, createdMonotonicNanoseconds, maximumReadyAgeNanoseconds
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    guard try c.decode(UInt32.self, forKey: .formatVersion) == Self.formatVersion else {
      throw QualificationError.invalid("unsupported watchdog supervisor arm version")
    }
    try self.init(supervisorInstance: c.decode(UUID.self, forKey: .supervisorInstance),
      expectedProcessInstance: c.decode(UUID.self, forKey: .expectedProcessInstance),
      expectedEnforcerInstance: c.decode(UUID.self, forKey: .expectedEnforcerInstance),
      createdMonotonicNanoseconds: c.decode(UInt64.self, forKey: .createdMonotonicNanoseconds),
      maximumReadyAgeNanoseconds: c.decode(UInt64.self, forKey: .maximumReadyAgeNanoseconds))
  }
}

/// Owner response before the supervisor permits normal liveness monitoring.
/// This does not say a root has completed or that hardware is safe.
public struct WatchdogOwnerReady: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let arm: WatchdogSupervisorArm
  public let processInstance: UUID
  public let enforcerInstance: UUID
  public let readyMonotonicNanoseconds: UInt64

  public init(arm: WatchdogSupervisorArm, processInstance: UUID,
    enforcerInstance: UUID, readyMonotonicNanoseconds: UInt64) throws {
    formatVersion = Self.formatVersion; self.arm = arm
    self.processInstance = processInstance; self.enforcerInstance = enforcerInstance
    self.readyMonotonicNanoseconds = readyMonotonicNanoseconds
    try validate()
  }
  public func validate() throws {
    try arm.validate()
    guard formatVersion == Self.formatVersion,
      processInstance == arm.expectedProcessInstance,
      enforcerInstance == arm.expectedEnforcerInstance,
      readyMonotonicNanoseconds >= arm.createdMonotonicNanoseconds,
      readyMonotonicNanoseconds - arm.createdMonotonicNanoseconds <= arm.maximumReadyAgeNanoseconds else {
      throw QualificationError.invalid("watchdog owner readiness is late, foreign or invalid")
    }
  }
  private enum CodingKeys: String, CodingKey {
    case formatVersion, arm, processInstance, enforcerInstance, readyMonotonicNanoseconds
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    guard try c.decode(UInt32.self, forKey: .formatVersion) == Self.formatVersion else {
      throw QualificationError.invalid("unsupported watchdog owner-ready version")
    }
    try self.init(arm: c.decode(WatchdogSupervisorArm.self, forKey: .arm),
      processInstance: c.decode(UUID.self, forKey: .processInstance),
      enforcerInstance: c.decode(UUID.self, forKey: .enforcerInstance),
      readyMonotonicNanoseconds: c.decode(UInt64.self, forKey: .readyMonotonicNanoseconds))
  }
}

/// Normal owner completion is separate from a stop acknowledgement. It can only
/// name an actually settled heartbeat and a retained terminal/run artifact. A
/// completion marker never clears an already-retained stop request.
public struct WatchdogOwnerCompletion: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let arm: WatchdogSupervisorArm
  public let lastSettledHeartbeat: WatchdogHeartbeat
  public let completedMonotonicNanoseconds: UInt64
  public let terminalEvidenceArtifactSHA256: String

  public init(arm: WatchdogSupervisorArm, lastSettledHeartbeat: WatchdogHeartbeat,
    completedMonotonicNanoseconds: UInt64, terminalEvidenceArtifactSHA256: String) throws {
    formatVersion = Self.formatVersion; self.arm = arm
    self.lastSettledHeartbeat = lastSettledHeartbeat
    self.completedMonotonicNanoseconds = completedMonotonicNanoseconds
    self.terminalEvidenceArtifactSHA256 = terminalEvidenceArtifactSHA256
    try validate()
  }
  public func validate() throws {
    try arm.validate(); try lastSettledHeartbeat.validate()
    guard formatVersion == Self.formatVersion,
      lastSettledHeartbeat.processInstance == arm.expectedProcessInstance,
      completedMonotonicNanoseconds >= lastSettledHeartbeat.monotonicNanoseconds,
      PerformanceRunArtifact.isSHA256(terminalEvidenceArtifactSHA256) else {
      throw QualificationError.invalid("watchdog normal completion is invalid")
    }
  }
  private enum CodingKeys: String, CodingKey {
    case formatVersion, arm, lastSettledHeartbeat, completedMonotonicNanoseconds
    case terminalEvidenceArtifactSHA256
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    guard try c.decode(UInt32.self, forKey: .formatVersion) == Self.formatVersion else {
      throw QualificationError.invalid("unsupported watchdog completion version")
    }
    try self.init(arm: c.decode(WatchdogSupervisorArm.self, forKey: .arm),
      lastSettledHeartbeat: c.decode(WatchdogHeartbeat.self, forKey: .lastSettledHeartbeat),
      completedMonotonicNanoseconds: c.decode(UInt64.self, forKey: .completedMonotonicNanoseconds),
      terminalEvidenceArtifactSHA256: c.decode(String.self, forKey: .terminalEvidenceArtifactSHA256))
  }
}

public enum WatchdogLifecycleStatus: String, Codable, Equatable, Sendable {
  case awaitingOwnerReady, monitoring, completedNormally
  case startupDeadlineExceeded, invalidLifecycleRecord, stoppedIncidentPresent

  public var requiresEscalation: Bool {
    switch self {
    case .awaitingOwnerReady, .monitoring, .completedNormally: false
    default: true
    }
  }
}

/// Pure state machine for bootstrap and normal completion. Liveness between
/// ready and completion remains the existing WatchdogMonitor/stop supervisor.
public struct WatchdogLifecycleSupervisor: Sendable {
  public let arm: WatchdogSupervisorArm
  public private(set) var ready: WatchdogOwnerReady?
  public private(set) var completion: WatchdogOwnerCompletion?
  private var terminal: WatchdogLifecycleStatus?
  private var lastObservationNanoseconds: UInt64

  public init(arm: WatchdogSupervisorArm) throws {
    try arm.validate(); self.arm = arm
    lastObservationNanoseconds = arm.createdMonotonicNanoseconds
  }

  public mutating func observeReady(_ value: WatchdogOwnerReady?, readFailed: Bool = false,
    stopPresent: Bool = false, nowNanoseconds: UInt64) -> WatchdogLifecycleStatus {
    if let terminal { return terminal }
    let status: WatchdogLifecycleStatus
    if nowNanoseconds < lastObservationNanoseconds {
      status = .invalidLifecycleRecord
    } else if stopPresent {
      status = .stoppedIncidentPresent
    } else if nowNanoseconds - arm.createdMonotonicNanoseconds > arm.maximumReadyAgeNanoseconds {
      status = .startupDeadlineExceeded
    } else if readFailed {
      status = .invalidLifecycleRecord
    } else if let value {
      if (try? value.validate()) != nil, value.arm == arm,
        value.readyMonotonicNanoseconds <= nowNanoseconds {
        ready = value; status = .monitoring
      } else { status = .invalidLifecycleRecord }
    } else { status = .awaitingOwnerReady }
    lastObservationNanoseconds = nowNanoseconds
    if status.requiresEscalation { terminal = status }
    return status
  }

  public mutating func observeCompletion(_ value: WatchdogOwnerCompletion?,
    currentHeartbeat: WatchdogHeartbeat?, readFailed: Bool = false,
    stopPresent: Bool = false, nowNanoseconds: UInt64) -> WatchdogLifecycleStatus {
    if let terminal { return terminal }
    guard ready != nil else { return .awaitingOwnerReady }
    let status: WatchdogLifecycleStatus
    if nowNanoseconds < lastObservationNanoseconds {
      status = .invalidLifecycleRecord
    } else if stopPresent {
      status = .stoppedIncidentPresent
    } else if readFailed {
      status = .invalidLifecycleRecord
    } else if let value {
      if (try? value.validate()) != nil, value.arm == arm,
        value.lastSettledHeartbeat == currentHeartbeat,
        value.completedMonotonicNanoseconds <= nowNanoseconds {
        completion = value; status = .completedNormally
      } else { status = .invalidLifecycleRecord }
    } else { status = .monitoring }
    lastObservationNanoseconds = nowNanoseconds
    if status == .completedNormally || status.requiresEscalation { terminal = status }
    return status
  }
}

extension WatchdogFileProtocol {
  public static func publishSupervisorArm(_ arm: WatchdogSupervisorArm, to url: URL) throws {
    try arm.validate(); try publishExactCreateOnly(arm, to: url, conflict: "conflicting watchdog supervisor arm")
  }
  public static func readSupervisorArmIfPresent(_ url: URL) throws -> WatchdogSupervisorArm? {
    try readLifecycle(WatchdogSupervisorArm.self, from: url)
  }
  public static func publishOwnerReady(_ ready: WatchdogOwnerReady, to url: URL) throws {
    try ready.validate(); try publishExactCreateOnly(ready, to: url, conflict: "conflicting watchdog owner readiness")
  }
  public static func readOwnerReadyIfPresent(_ url: URL) throws -> WatchdogOwnerReady? {
    try readLifecycle(WatchdogOwnerReady.self, from: url)
  }
  public static func publishOwnerCompletion(_ completion: WatchdogOwnerCompletion, to url: URL) throws {
    try completion.validate(); try publishExactCreateOnly(completion, to: url, conflict: "conflicting watchdog normal completion")
  }
  public static func readOwnerCompletionIfPresent(_ url: URL) throws -> WatchdogOwnerCompletion? {
    try readLifecycle(WatchdogOwnerCompletion.self, from: url)
  }

  private static func readLifecycle<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
    let directory = try QualificationFileDirectory(url: url.deletingLastPathComponent())
    guard let bytes = try directory.readIfPresent(url.lastPathComponent, maximumBytes: maximumBytes) else { return nil }
    return try JSONDecoder().decode(type, from: bytes)
  }

  private static func publishExactCreateOnly<T: Codable & Equatable>(_ value: T, to url: URL,
    conflict: String) throws {
    let bytes = try QualificationFileDirectory.canonicalJSON(value)
    guard bytes.count <= maximumBytes else { throw QualificationFileError.sizeLimit }
    let directory = try QualificationFileDirectory(url: url.deletingLastPathComponent())
    if try !directory.publish(bytes, named: url.lastPathComponent) {
      let existing = try JSONDecoder().decode(T.self,
        from: directory.read(url.lastPathComponent, maximumBytes: maximumBytes))
      guard existing == value else { throw QualificationError.invalid(conflict) }
    }
  }
}

/// Owner-side lifecycle helper. It never admits roots itself; callers retain the
/// existing WatchdogOwnerFileSession as the only root admission interlock.
public final class WatchdogOwnerLifecycle: @unchecked Sendable {
  public let owner: WatchdogOwnerFileSession
  public let arm: WatchdogSupervisorArm
  public let readyURL: URL
  public let completionURL: URL
  private let lock = NSLock()
  private var activated = false
  private var completed = false

  public init(owner: WatchdogOwnerFileSession, armURL: URL, readyURL: URL,
    completionURL: URL, nowNanoseconds: UInt64) throws {
    let paths = [armURL, readyURL, completionURL].map(\.standardizedFileURL)
    guard Set(paths).count == paths.count,
      let arm = try WatchdogFileProtocol.readSupervisorArmIfPresent(armURL),
      arm.expectedProcessInstance == owner.configuration.processInstance,
      arm.expectedEnforcerInstance == owner.configuration.enforcerInstance,
      nowNanoseconds >= arm.createdMonotonicNanoseconds,
      nowNanoseconds - arm.createdMonotonicNanoseconds <= arm.maximumReadyAgeNanoseconds,
      !owner.admissionClosed, !owner.hasActiveRoot else {
      throw QualificationError.invalid("watchdog owner cannot enter lifecycle bootstrap")
    }
    self.owner = owner; self.arm = arm; self.readyURL = readyURL; self.completionURL = completionURL
  }

  public func activate(nowNanoseconds: UInt64) throws {
    lock.lock(); defer { lock.unlock() }
    guard !activated, !completed, !owner.admissionClosed, !owner.hasActiveRoot else {
      throw QualificationError.invalid("watchdog owner lifecycle cannot activate")
    }
    let ready = try WatchdogOwnerReady(arm: arm,
      processInstance: owner.configuration.processInstance,
      enforcerInstance: owner.configuration.enforcerInstance,
      readyMonotonicNanoseconds: nowNanoseconds)
    try WatchdogFileProtocol.publishOwnerReady(ready, to: readyURL)
    activated = true
  }

  public func complete(terminalEvidenceArtifactSHA256: String,
    nowNanoseconds: UInt64) throws -> WatchdogOwnerCompletion {
    lock.lock(); defer { lock.unlock() }
    guard activated, !completed, !owner.admissionClosed, !owner.hasActiveRoot,
      let heartbeat = owner.lastSettledHeartbeat else {
      throw QualificationError.invalid("watchdog owner cannot complete with pending, failed or unsettled state")
    }
    let value = try WatchdogOwnerCompletion(arm: arm, lastSettledHeartbeat: heartbeat,
      completedMonotonicNanoseconds: nowNanoseconds,
      terminalEvidenceArtifactSHA256: terminalEvidenceArtifactSHA256)
    try WatchdogFileProtocol.publishOwnerCompletion(value, to: completionURL)
    completed = true
    return value
  }
}

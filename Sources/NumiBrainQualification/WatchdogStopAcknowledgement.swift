import Foundation

/// A transport report, not a safety certificate or permission to resume.
/// The configured enforcer must actually implement the declared effect.
public enum WatchdogStopEffect: String, Codable, Equatable, Sendable {
  case simulationRootsQuiesced
  case externalActuatorsInhibited
}

public struct WatchdogStopAcknowledgement: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  /// Retain the COMPLETE first fault, not just its process UUID or generation.
  public let request: WatchdogStopRequest
  public let enforcerInstance: UUID
  public let effect: WatchdogStopEffect
  public let settledHeartbeat: WatchdogHeartbeat
  public let acknowledgedMonotonicNanoseconds: UInt64
  public let terminalEvidenceArtifactSHA256: String

  public init(request: WatchdogStopRequest, enforcerInstance: UUID,
    effect: WatchdogStopEffect, settledHeartbeat: WatchdogHeartbeat,
    acknowledgedMonotonicNanoseconds: UInt64, terminalEvidenceArtifactSHA256: String) throws {
    formatVersion = Self.formatVersion; self.request = request
    self.enforcerInstance = enforcerInstance; self.effect = effect
    self.settledHeartbeat = settledHeartbeat
    self.acknowledgedMonotonicNanoseconds = acknowledgedMonotonicNanoseconds
    self.terminalEvidenceArtifactSHA256 = terminalEvidenceArtifactSHA256
    try validate()
  }

  public func validate() throws {
    try request.validate(); try settledHeartbeat.validate()
    guard formatVersion == Self.formatVersion,
      settledHeartbeat.processInstance == request.expectedProcessInstance,
      acknowledgedMonotonicNanoseconds >= settledHeartbeat.monotonicNanoseconds,
      terminalEvidenceArtifactSHA256.utf8.count == 64,
      terminalEvidenceArtifactSHA256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
      throw QualificationError.invalid("invalid watchdog stop acknowledgement")
    }
    // The fault may describe a FOREIGN restarted process. Never transplant its
    // generations into the expected process's settlement comparison.
    if let observed = request.observed, observed.processInstance == request.expectedProcessInstance {
      guard settledHeartbeat.sequence >= observed.sequence,
        settledHeartbeat.monotonicNanoseconds >= observed.monotonicNanoseconds,
        settledHeartbeat.publicGeneration >= observed.publicGeneration,
        settledHeartbeat.publicGeneration != observed.publicGeneration
          || settledHeartbeat.transactionFingerprint == observed.transactionFingerprint else {
        throw QualificationError.invalid("watchdog acknowledgement regresses or changes settled authority")
      }
    }
  }

  private enum CodingKeys: String, CodingKey {
    case formatVersion, request, enforcerInstance, effect, settledHeartbeat
    case acknowledgedMonotonicNanoseconds, terminalEvidenceArtifactSHA256
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let version = try c.decode(UInt32.self, forKey: .formatVersion)
    guard version == Self.formatVersion else {
      throw QualificationError.invalid("unsupported watchdog acknowledgement version")
    }
    try self.init(request: c.decode(WatchdogStopRequest.self, forKey: .request),
      enforcerInstance: c.decode(UUID.self, forKey: .enforcerInstance),
      effect: c.decode(WatchdogStopEffect.self, forKey: .effect),
      settledHeartbeat: c.decode(WatchdogHeartbeat.self, forKey: .settledHeartbeat),
      acknowledgedMonotonicNanoseconds: c.decode(UInt64.self, forKey: .acknowledgedMonotonicNanoseconds),
      terminalEvidenceArtifactSHA256: c.decode(String.self, forKey: .terminalEvidenceArtifactSHA256))
  }
}

public enum WatchdogStopSupervisionStatus: String, Codable, Equatable, Sendable {
  case awaitingAcknowledgement, acknowledgedReport, deadlineExceeded, invalidAcknowledgement, clockRegressed

  /// Even an acknowledged report never reopens root admission or clears a stop.
  public var mustKeepStopped: Bool { true }
  public var requiresEscalation: Bool {
    switch self {
    case .awaitingAcknowledgement, .acknowledgedReport: false
    default: true
    }
  }
}

/// Deterministic, bounded observation of ONE stop incident in ONE monotonic
/// clock domain. A receipt arriving after the deadline never repairs failure.
/// An acknowledged report still requires native/external evidence verification;
/// UUIDs and an artifact hash do not authenticate a writer or prove actuation.
public struct WatchdogStopSupervisor: Sendable {
  public let request: WatchdogStopRequest
  public let expectedEnforcerInstance: UUID
  public let requiredEffect: WatchdogStopEffect
  public let requestedMonotonicNanoseconds: UInt64
  public let maximumAcknowledgementAgeNanoseconds: UInt64
  public private(set) var acknowledgement: WatchdogStopAcknowledgement?
  private var lastObservationTime: UInt64
  private var terminalStatus: WatchdogStopSupervisionStatus?

  public init(request: WatchdogStopRequest, expectedEnforcerInstance: UUID,
    requiredEffect: WatchdogStopEffect, requestedMonotonicNanoseconds: UInt64,
    maximumAcknowledgementAgeNanoseconds: UInt64) throws {
    try request.validate()
    guard requestedMonotonicNanoseconds > 0, maximumAcknowledgementAgeNanoseconds > 0 else {
      throw QualificationError.invalid("invalid watchdog acknowledgement deadline")
    }
    self.request = request; self.expectedEnforcerInstance = expectedEnforcerInstance
    self.requiredEffect = requiredEffect; self.requestedMonotonicNanoseconds = requestedMonotonicNanoseconds
    self.maximumAcknowledgementAgeNanoseconds = maximumAcknowledgementAgeNanoseconds
    lastObservationTime = requestedMonotonicNanoseconds
  }

  public mutating func observe(_ value: WatchdogStopAcknowledgement?, readFailed: Bool = false,
    nowNanoseconds: UInt64) -> WatchdogStopSupervisionStatus {
    if let terminalStatus { return terminalStatus }
    let status: WatchdogStopSupervisionStatus
    if nowNanoseconds < lastObservationTime {
      status = .clockRegressed
    } else if nowNanoseconds - requestedMonotonicNanoseconds > maximumAcknowledgementAgeNanoseconds {
      status = .deadlineExceeded
    } else if readFailed {
      status = .invalidAcknowledgement
    } else if let value {
      if (try? value.validate()) != nil, value.request == request,
        value.enforcerInstance == expectedEnforcerInstance, value.effect == requiredEffect,
        value.acknowledgedMonotonicNanoseconds >= requestedMonotonicNanoseconds,
        value.acknowledgedMonotonicNanoseconds <= nowNanoseconds {
        acknowledgement = value; status = .acknowledgedReport
      } else { status = .invalidAcknowledgement }
    } else { status = .awaitingAcknowledgement }
    lastObservationTime = nowNanoseconds
    if status != .awaitingAcknowledgement { terminalStatus = status }
    return status
  }
}

extension WatchdogFileProtocol {
  /// Returns the first retained request, including when another writer wins.
  /// Callers MUST supervise this value rather than their unretained proposal.
  public static func publishAndReadStopRequest(_ request: WatchdogStopRequest, to url: URL) throws -> WatchdogStopRequest {
    try publishStopRequest(request, to: url)
    guard let retained = try readStopRequestIfPresent(url) else {
      throw QualificationError.invalid("watchdog stop disappeared after publication")
    }
    return retained
  }

  public static func readStopAcknowledgementIfPresent(_ url: URL) throws -> WatchdogStopAcknowledgement? {
    let directory = try QualificationFileDirectory(url: url.deletingLastPathComponent())
    guard let bytes = try directory.readIfPresent(url.lastPathComponent, maximumBytes: maximumBytes) else { return nil }
    return try JSONDecoder().decode(WatchdogStopAcknowledgement.self, from: bytes)
  }

  /// Create-only, durable, and idempotent ONLY for the same complete report.
  /// A conflicting report is retained but cannot count as acknowledgement.
  public static func publishStopAcknowledgement(_ acknowledgement: WatchdogStopAcknowledgement, to url: URL) throws {
    try acknowledgement.validate()
    let bytes = try QualificationFileDirectory.canonicalJSON(acknowledgement)
    guard bytes.count <= maximumBytes else { throw QualificationFileError.sizeLimit }
    let directory = try QualificationFileDirectory(url: url.deletingLastPathComponent())
    if try !directory.publish(bytes, named: url.lastPathComponent) {
      let existing = try JSONDecoder().decode(WatchdogStopAcknowledgement.self,
        from: directory.read(url.lastPathComponent, maximumBytes: maximumBytes))
      guard existing == acknowledgement else {
        throw QualificationError.invalid("conflicting watchdog acknowledgement is already retained")
      }
    }
  }
}

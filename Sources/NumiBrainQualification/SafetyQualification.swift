import Foundation

@frozen
public struct SafetyVector: Codable, Equatable, Sendable {
  public let semanticRisk: Double
  public let kinematicRisk: Double
  public let contactRisk: Double
  public let forceRisk: Double
  public let thermalRisk: Double
  public let actuatorRisk: Double
  public let uncertainty: Double
  public let staleGeneration: Bool
  public let malformedRecord: Bool
  public let resourceAlias: Bool
  public let deviceFault: Bool

  public init(semanticRisk: Double, kinematicRisk: Double, contactRisk: Double,
    forceRisk: Double, thermalRisk: Double, actuatorRisk: Double, uncertainty: Double,
    staleGeneration: Bool = false, malformedRecord: Bool = false,
    resourceAlias: Bool = false, deviceFault: Bool = false) throws {
    let values = [semanticRisk, kinematicRisk, contactRisk, forceRisk, thermalRisk, actuatorRisk, uncertainty]
    guard values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
      throw QualificationError.invalid("safety vector risks must be finite [0,1]")
    }
    self.semanticRisk = semanticRisk; self.kinematicRisk = kinematicRisk; self.contactRisk = contactRisk
    self.forceRisk = forceRisk; self.thermalRisk = thermalRisk; self.actuatorRisk = actuatorRisk
    self.uncertainty = uncertainty; self.staleGeneration = staleGeneration
    self.malformedRecord = malformedRecord; self.resourceAlias = resourceAlias; self.deviceFault = deviceFault
  }
}

@frozen
public struct SafetyEnvelope: Codable, Equatable, Sendable {
  public let semanticStop: Double
  public let kinematicStop: Double
  public let contactStop: Double
  public let forceStop: Double
  public let thermalStop: Double
  public let actuatorStop: Double
  public let uncertaintySupervision: Double
  public let uncertaintyStop: Double

  public init(semanticStop: Double, kinematicStop: Double, contactStop: Double,
    forceStop: Double, thermalStop: Double, actuatorStop: Double,
    uncertaintySupervision: Double, uncertaintyStop: Double) throws {
    let values = [semanticStop, kinematicStop, contactStop, forceStop, thermalStop, actuatorStop,
      uncertaintySupervision, uncertaintyStop]
    guard values.allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 1 }), uncertaintySupervision <= uncertaintyStop else {
      throw QualificationError.invalid("safety envelope is invalid")
    }
    self.semanticStop = semanticStop; self.kinematicStop = kinematicStop; self.contactStop = contactStop
    self.forceStop = forceStop; self.thermalStop = thermalStop; self.actuatorStop = actuatorStop
    self.uncertaintySupervision = uncertaintySupervision; self.uncertaintyStop = uncertaintyStop
  }
}

@frozen
public enum SafetyDisposition: String, Codable, Equatable, Hashable, Sendable {
  case allow
  case requestSupervision
  case protectiveStop
  case failClosed
}

@frozen
public struct SafetyDecision: Codable, Equatable, Sendable {
  public let disposition: SafetyDisposition
  public let reasons: [String]

  public init(vector: SafetyVector, envelope: SafetyEnvelope) {
    var reasons: [String] = []
    if vector.staleGeneration { reasons.append("stale_generation") }
    if vector.malformedRecord { reasons.append("malformed_record") }
    if vector.resourceAlias { reasons.append("resource_alias") }
    if vector.deviceFault { reasons.append("device_fault") }
    if !reasons.isEmpty { self.disposition = .failClosed; self.reasons = reasons; return }

    let limits: [(String, Double, Double)] = [
      ("semantic", vector.semanticRisk, envelope.semanticStop),
      ("kinematic", vector.kinematicRisk, envelope.kinematicStop),
      ("contact", vector.contactRisk, envelope.contactStop),
      ("force", vector.forceRisk, envelope.forceStop),
      ("thermal", vector.thermalRisk, envelope.thermalStop),
      ("actuator", vector.actuatorRisk, envelope.actuatorStop),
    ]
    reasons = limits.filter({ $0.1 >= $0.2 }).map(\.0)
    if vector.uncertainty >= envelope.uncertaintyStop { reasons.append("uncertainty_stop") }
    if !reasons.isEmpty { self.disposition = .protectiveStop; self.reasons = reasons; return }
    if vector.uncertainty >= envelope.uncertaintySupervision {
      self.disposition = .requestSupervision; self.reasons = ["uncertainty_supervision"]; return
    }
    self.disposition = .allow; self.reasons = []
  }
}

@frozen
public struct WatchdogHeartbeat: Codable, Equatable, Sendable {
  public let processInstance: UUID
  public let sequence: UInt64
  public let monotonicNanoseconds: UInt64
  public let publicGeneration: UInt64
  public let transactionFingerprint: UInt64

  public init(processInstance: UUID, sequence: UInt64, monotonicNanoseconds: UInt64,
    publicGeneration: UInt64, transactionFingerprint: UInt64) throws {
    guard monotonicNanoseconds > 0, transactionFingerprint > 0 else {
      throw QualificationError.invalid("watchdog heartbeat is incomplete")
    }
    self.processInstance = processInstance; self.sequence = sequence
    self.monotonicNanoseconds = monotonicNanoseconds; self.publicGeneration = publicGeneration
    self.transactionFingerprint = transactionFingerprint
  }
}

@frozen
public enum WatchdogStatus: String, Codable, Equatable, Hashable, Sendable {
  case healthy, stale, restarted, regressed
}

public enum WatchdogVerifier {
  public static func status(previous: WatchdogHeartbeat?, current: WatchdogHeartbeat,
    nowNanoseconds: UInt64, maximumAgeNanoseconds: UInt64) throws -> WatchdogStatus {
    guard maximumAgeNanoseconds > 0, nowNanoseconds >= current.monotonicNanoseconds else {
      throw QualificationError.invalid("watchdog timing is invalid")
    }
    if nowNanoseconds - current.monotonicNanoseconds > maximumAgeNanoseconds { return .stale }
    guard let previous else { return .healthy }
    if previous.processInstance != current.processInstance { return .restarted }
    if current.sequence <= previous.sequence || current.publicGeneration < previous.publicGeneration ||
      current.monotonicNanoseconds <= previous.monotonicNanoseconds { return .regressed }
    return .healthy
  }
}

@frozen
public struct SafetyIncidentArtifact: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let sourceRevision: String
  public let parameterVersionFingerprint: UInt64
  public let publicGeneration: UInt64
  public let transactionFingerprint: UInt64
  public let vector: SafetyVector
  public let decision: SafetyDecision
  public let rejectedShadowExposed: Bool
  public let recoveryArtifactSHA256: String?

  public init(sourceRevision: String, parameterVersionFingerprint: UInt64, publicGeneration: UInt64,
    transactionFingerprint: UInt64, vector: SafetyVector, decision: SafetyDecision,
    rejectedShadowExposed: Bool, recoveryArtifactSHA256: String? = nil) throws {
    guard !sourceRevision.isEmpty, parameterVersionFingerprint > 0, transactionFingerprint > 0,
      !rejectedShadowExposed,
      recoveryArtifactSHA256 == nil || PerformanceRunArtifact.isSHA256(recoveryArtifactSHA256!) else {
      throw QualificationError.invalid("safety incident artifact is invalid")
    }
    formatVersion = Self.formatVersion; self.sourceRevision = sourceRevision
    self.parameterVersionFingerprint = parameterVersionFingerprint; self.publicGeneration = publicGeneration
    self.transactionFingerprint = transactionFingerprint; self.vector = vector; self.decision = decision
    self.rejectedShadowExposed = rejectedShadowExposed; self.recoveryArtifactSHA256 = recoveryArtifactSHA256
  }
}

@frozen
public struct SafetyCampaignScenario: Codable, Equatable, Hashable, Sendable {
  public enum Kind: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case semanticLimit, kinematicLimit, contactLimit, forceLimit, thermalLimit, actuatorLimit
    case uncertainty, malformedRecord, staleGeneration, resourceAlias, eventReplay, gpuFault, processRestart
  }
  public let kind: Kind
  public let identifier: String
  public init(kind: Kind, identifier: String) throws {
    guard !identifier.isEmpty, identifier.utf8.count <= 256 else {
      throw QualificationError.invalid("scenario identifier is empty or too large")
    }
    self.kind = kind; self.identifier = identifier
  }
}

@frozen
public struct SafetyCampaignOutcome: Codable, Equatable, Sendable {
  public let scenario: SafetyCampaignScenario
  public let disposition: SafetyDisposition
  public let publicRootChangedOnRejectedAttempt: Bool
  public let rejectedShadowExposed: Bool
  public let boundedLatencyMicroseconds: Double

  public init(scenario: SafetyCampaignScenario, disposition: SafetyDisposition,
    publicRootChangedOnRejectedAttempt: Bool, rejectedShadowExposed: Bool,
    boundedLatencyMicroseconds: Double) throws {
    guard boundedLatencyMicroseconds.isFinite, boundedLatencyMicroseconds >= 0 else {
      throw QualificationError.invalid("safety campaign latency is invalid")
    }
    self.scenario = scenario; self.disposition = disposition
    self.publicRootChangedOnRejectedAttempt = publicRootChangedOnRejectedAttempt
    self.rejectedShadowExposed = rejectedShadowExposed; self.boundedLatencyMicroseconds = boundedLatencyMicroseconds
  }
}

public enum SafetyCampaignVerifier {
  public static func verify(required: [SafetyCampaignScenario], outcomes: [SafetyCampaignOutcome],
    maximumProtectiveLatencyMicroseconds: Double) throws {
    let requiredKinds = Set(required.map(\.kind))
    guard maximumProtectiveLatencyMicroseconds.isFinite, maximumProtectiveLatencyMicroseconds > 0,
      !required.isEmpty, Set(required).count == required.count, outcomes.count == required.count,
      requiredKinds == Set(SafetyCampaignScenario.Kind.allCases) else {
      throw QualificationError.invalid("safety campaign protocol is invalid, incomplete, or missing a required scenario class")
    }
    guard Set(outcomes.map(\.scenario)) == Set(required), Set(outcomes.map(\.scenario)).count == outcomes.count else {
      throw QualificationError.invalid("safety campaign has missing, duplicate, or foreign scenarios")
    }
    for outcome in outcomes {
      guard outcome.disposition != .allow,
        !outcome.publicRootChangedOnRejectedAttempt, !outcome.rejectedShadowExposed,
        outcome.boundedLatencyMicroseconds <= maximumProtectiveLatencyMicroseconds else {
        throw QualificationError.invalid("safety campaign scenario failed")
      }
    }
  }
}

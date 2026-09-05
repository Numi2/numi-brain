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
    self.semanticRisk = semanticRisk; self.kinematicRisk = kinematicRisk; self.contactRisk = contactRisk
    self.forceRisk = forceRisk; self.thermalRisk = thermalRisk; self.actuatorRisk = actuatorRisk
    self.uncertainty = uncertainty; self.staleGeneration = staleGeneration
    self.malformedRecord = malformedRecord; self.resourceAlias = resourceAlias; self.deviceFault = deviceFault
    try validate()
  }

  public func validate() throws {
    guard [semanticRisk, kinematicRisk, contactRisk, forceRisk, thermalRisk, actuatorRisk, uncertainty]
      .allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
      throw QualificationError.invalid("safety risks must be finite [0,1]")
    }
  }

  private enum CodingKeys: String, CodingKey {
    case semanticRisk, kinematicRisk, contactRisk, forceRisk, thermalRisk, actuatorRisk, uncertainty
    case staleGeneration, malformedRecord, resourceAlias, deviceFault
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(semanticRisk: c.decode(Double.self, forKey: .semanticRisk),
      kinematicRisk: c.decode(Double.self, forKey: .kinematicRisk),
      contactRisk: c.decode(Double.self, forKey: .contactRisk), forceRisk: c.decode(Double.self, forKey: .forceRisk),
      thermalRisk: c.decode(Double.self, forKey: .thermalRisk), actuatorRisk: c.decode(Double.self, forKey: .actuatorRisk),
      uncertainty: c.decode(Double.self, forKey: .uncertainty), staleGeneration: c.decode(Bool.self, forKey: .staleGeneration),
      malformedRecord: c.decode(Bool.self, forKey: .malformedRecord), resourceAlias: c.decode(Bool.self, forKey: .resourceAlias),
      deviceFault: c.decode(Bool.self, forKey: .deviceFault))
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
    self.semanticStop = semanticStop; self.kinematicStop = kinematicStop; self.contactStop = contactStop
    self.forceStop = forceStop; self.thermalStop = thermalStop; self.actuatorStop = actuatorStop
    self.uncertaintySupervision = uncertaintySupervision; self.uncertaintyStop = uncertaintyStop
    try validate()
  }
  public func validate() throws {
    guard [semanticStop, kinematicStop, contactStop, forceStop, thermalStop, actuatorStop,
      uncertaintySupervision, uncertaintyStop].allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 1 }),
      uncertaintySupervision <= uncertaintyStop else { throw QualificationError.invalid("invalid safety envelope") }
  }
  private enum CodingKeys: String, CodingKey {
    case semanticStop, kinematicStop, contactStop, forceStop, thermalStop, actuatorStop
    case uncertaintySupervision, uncertaintyStop
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(semanticStop: c.decode(Double.self, forKey: .semanticStop),
      kinematicStop: c.decode(Double.self, forKey: .kinematicStop), contactStop: c.decode(Double.self, forKey: .contactStop),
      forceStop: c.decode(Double.self, forKey: .forceStop), thermalStop: c.decode(Double.self, forKey: .thermalStop),
      actuatorStop: c.decode(Double.self, forKey: .actuatorStop),
      uncertaintySupervision: c.decode(Double.self, forKey: .uncertaintySupervision),
      uncertaintyStop: c.decode(Double.self, forKey: .uncertaintyStop))
  }
}

@frozen
public enum SafetyDisposition: String, Codable, Equatable, Hashable, Sendable {
  case allow, requestSupervision, protectiveStop, failClosed
}

/// Derived diagnostic. Decoding a decision does not confer handoff authority.
@frozen
public struct SafetyDecision: Codable, Equatable, Sendable {
  public let disposition: SafetyDisposition
  public let reasons: [String]

  public init(vector: SafetyVector, envelope: SafetyEnvelope) {
    guard (try? vector.validate()) != nil, (try? envelope.validate()) != nil else {
      disposition = .failClosed; reasons = ["invalid_safety_input"]; return
    }
    var faults: [String] = []
    if vector.staleGeneration { faults.append("stale_generation") }
    if vector.malformedRecord { faults.append("malformed_record") }
    if vector.resourceAlias { faults.append("resource_alias") }
    if vector.deviceFault { faults.append("device_fault") }
    if !faults.isEmpty { disposition = .failClosed; reasons = faults; return }
    let limits: [(String, Double, Double)] = [
      ("semantic", vector.semanticRisk, envelope.semanticStop), ("kinematic", vector.kinematicRisk, envelope.kinematicStop),
      ("contact", vector.contactRisk, envelope.contactStop), ("force", vector.forceRisk, envelope.forceStop),
      ("thermal", vector.thermalRisk, envelope.thermalStop), ("actuator", vector.actuatorRisk, envelope.actuatorStop),
    ]
    var exceeded = limits.filter { $0.1 >= $0.2 }.map(\.0)
    if vector.uncertainty >= envelope.uncertaintyStop { exceeded.append("uncertainty_stop") }
    if !exceeded.isEmpty { disposition = .protectiveStop; reasons = exceeded; return }
    if vector.uncertainty >= envelope.uncertaintySupervision {
      disposition = .requestSupervision; reasons = ["uncertainty_supervision"]; return
    }
    disposition = .allow; reasons = []
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
    self.processInstance = processInstance; self.sequence = sequence
    self.monotonicNanoseconds = monotonicNanoseconds; self.publicGeneration = publicGeneration
    self.transactionFingerprint = transactionFingerprint
    try validate()
  }
  public func validate() throws {
    guard monotonicNanoseconds > 0, transactionFingerprint > 0 else {
      throw QualificationError.invalid("watchdog heartbeat is incomplete")
    }
  }
  private enum CodingKeys: String, CodingKey {
    case processInstance, sequence, monotonicNanoseconds, publicGeneration, transactionFingerprint
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(processInstance: c.decode(UUID.self, forKey: .processInstance),
      sequence: c.decode(UInt64.self, forKey: .sequence), monotonicNanoseconds: c.decode(UInt64.self, forKey: .monotonicNanoseconds),
      publicGeneration: c.decode(UInt64.self, forKey: .publicGeneration),
      transactionFingerprint: c.decode(UInt64.self, forKey: .transactionFingerprint))
  }
}

@frozen
public enum WatchdogStatus: String, Codable, Equatable, Hashable, Sendable {
  case healthy, stale, restarted, regressed, missing, malformed
}

public enum WatchdogVerifier {
  public static func status(previous: WatchdogHeartbeat?, current: WatchdogHeartbeat,
    nowNanoseconds: UInt64, maximumAgeNanoseconds: UInt64) throws -> WatchdogStatus {
    try current.validate()
    if let previous { try previous.validate() }
    guard maximumAgeNanoseconds > 0, nowNanoseconds >= current.monotonicNanoseconds else {
      throw QualificationError.invalid("watchdog timing is invalid")
    }
    if nowNanoseconds - current.monotonicNanoseconds > maximumAgeNanoseconds { return .stale }
    guard let previous else { return .healthy }
    if previous.processInstance != current.processInstance { return .restarted }
    // Polling the same immutable heartbeat is not a replay until it ages out.
    if current == previous { return .healthy }
    if current.sequence <= previous.sequence || current.publicGeneration < previous.publicGeneration
      || current.monotonicNanoseconds <= previous.monotonicNanoseconds { return .regressed }
    return .healthy
  }
}

/// Retains failures too: an exposed shadow is an incident, never a reason to
/// suppress the incident artifact. These records are not admission receipts.
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
    try vector.validate()
    guard !sourceRevision.isEmpty, sourceRevision.utf8.count <= 256,
      parameterVersionFingerprint > 0, transactionFingerprint > 0,
      recoveryArtifactSHA256 == nil || PerformanceRunArtifact.isSHA256(recoveryArtifactSHA256!) else {
      throw QualificationError.invalid("invalid safety incident identity")
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

    public var defaultDisposition: SafetyDisposition {
      switch self {
      case .semanticLimit, .kinematicLimit, .contactLimit, .forceLimit, .thermalLimit, .actuatorLimit: .protectiveStop
      case .uncertainty: .requestSupervision
      default: .failClosed
      }
    }
    func permits(_ value: SafetyDisposition) -> Bool {
      switch self {
      case .uncertainty: value == .requestSupervision || value == .protectiveStop
      case .semanticLimit, .kinematicLimit, .contactLimit, .forceLimit, .thermalLimit, .actuatorLimit:
        value == .protectiveStop || value == .failClosed
      default: value == .failClosed
      }
    }
  }
  public let kind: Kind
  public let identifier: String
  public let expectedDisposition: SafetyDisposition

  public init(kind: Kind, identifier: String, expectedDisposition: SafetyDisposition? = nil) throws {
    self.kind = kind; self.identifier = identifier
    self.expectedDisposition = expectedDisposition ?? kind.defaultDisposition
    try validate()
  }
  public func validate() throws {
    guard !identifier.isEmpty, identifier.utf8.count <= 256, kind.permits(expectedDisposition) else {
      throw QualificationError.invalid("invalid safety scenario or weakened required response")
    }
  }
  private enum CodingKeys: String, CodingKey { case kind, identifier, expectedDisposition }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(kind: c.decode(Kind.self, forKey: .kind), identifier: c.decode(String.self, forKey: .identifier),
      expectedDisposition: c.decodeIfPresent(SafetyDisposition.self, forKey: .expectedDisposition))
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
    self.scenario = scenario; self.disposition = disposition
    self.publicRootChangedOnRejectedAttempt = publicRootChangedOnRejectedAttempt
    self.rejectedShadowExposed = rejectedShadowExposed; self.boundedLatencyMicroseconds = boundedLatencyMicroseconds
    try validate()
  }
  public func validate() throws {
    try scenario.validate()
    guard boundedLatencyMicroseconds.isFinite, boundedLatencyMicroseconds >= 0 else {
      throw QualificationError.invalid("invalid safety campaign latency")
    }
  }
}

public enum SafetyCampaignVerifier {
  /// Checks supplied campaign results, not native execution authenticity.
  public static func verify(required: [SafetyCampaignScenario], outcomes: [SafetyCampaignOutcome],
    maximumProtectiveLatencyMicroseconds: Double) throws {
    guard maximumProtectiveLatencyMicroseconds.isFinite, maximumProtectiveLatencyMicroseconds > 0,
      !required.isEmpty, required.count <= 100_000, outcomes.count == required.count else {
      throw QualificationError.invalid("invalid or incomplete safety campaign")
    }
    for scenario in required { try scenario.validate() }
    for outcome in outcomes { try outcome.validate() }
    guard Set(required).count == required.count, Set(required.map(\.identifier)).count == required.count,
      Set(required.map(\.kind)) == Set(SafetyCampaignScenario.Kind.allCases),
      Set(outcomes.map(\.scenario)) == Set(required), Set(outcomes.map(\.scenario)).count == outcomes.count else {
      throw QualificationError.invalid("missing, duplicate, foreign or incomplete safety scenario coverage")
    }
    for outcome in outcomes {
      guard outcome.disposition == outcome.scenario.expectedDisposition,
        !outcome.publicRootChangedOnRejectedAttempt, !outcome.rejectedShadowExposed,
        outcome.boundedLatencyMicroseconds <= maximumProtectiveLatencyMicroseconds else {
        throw QualificationError.invalid("safety scenario did not produce its predeclared response")
      }
    }
  }
}

import CryptoKit
import Foundation
import NumiBrainQualification

@frozen
public enum BrainExternalSafetyMeasurementKind: String, Codable, CaseIterable, Sendable {
  case force
  case thermal
  case actuator
}

/// A signed producer's settled physical-limit observation. Values remain in an
/// explicitly named unit; the verifier never compares unlike quantities or
/// normalizes a raw device limit after the incident.
@frozen
public struct BrainExternalSafetyMeasurement: Codable, Equatable, Sendable {
  public let kind: BrainExternalSafetyMeasurementKind
  public let unit: String
  public let sampleCount: UInt64
  public let settledSampleMonotonicNanoseconds: UInt64
  public let settledValue: Double
  public let safeLimit: Double
  public let rawEvidenceArtifactSHA256: String

  public init(kind: BrainExternalSafetyMeasurementKind, unit: String,
    sampleCount: UInt64, settledSampleMonotonicNanoseconds: UInt64,
    settledValue: Double, safeLimit: Double,
    rawEvidenceArtifactSHA256: String) throws {
    self.kind = kind; self.unit = unit; self.sampleCount = sampleCount
    self.settledSampleMonotonicNanoseconds = settledSampleMonotonicNanoseconds
    self.settledValue = settledValue; self.safeLimit = safeLimit
    self.rawEvidenceArtifactSHA256 = rawEvidenceArtifactSHA256
    try validate()
  }

  public func validate() throws {
    guard !unit.isEmpty, unit.utf8.count <= 64, sampleCount > 0,
      settledSampleMonotonicNanoseconds > 0,
      settledValue.isFinite, safeLimit.isFinite, safeLimit >= 0,
      abs(settledValue) <= safeLimit,
      PerformanceRunArtifact.isSHA256(rawEvidenceArtifactSHA256) else {
      throw QualificationError.invalid("invalid signed external safety measurement")
    }
  }

  private enum CodingKeys: String, CodingKey {
    case kind, unit, sampleCount, settledSampleMonotonicNanoseconds
    case settledValue, safeLimit, rawEvidenceArtifactSHA256
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(kind: c.decode(BrainExternalSafetyMeasurementKind.self, forKey: .kind),
      unit: c.decode(String.self, forKey: .unit),
      sampleCount: c.decode(UInt64.self, forKey: .sampleCount),
      settledSampleMonotonicNanoseconds: c.decode(UInt64.self, forKey: .settledSampleMonotonicNanoseconds),
      settledValue: c.decode(Double.self, forKey: .settledValue),
      safeLimit: c.decode(Double.self, forKey: .safeLimit),
      rawEvidenceArtifactSHA256: c.decode(String.self, forKey: .rawEvidenceArtifactSHA256))
  }
}

/// Canonical bytes signed by the independently configured safety enforcer.
/// `requestedMonotonicNanoseconds` is the supervisor's retained stop-start time;
/// it is separate from the request's wall-clock incident timestamp.
@frozen
public struct BrainExternalSafetyStopPayload: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let sourceRevision: String
  public let scenarioIdentifier: String
  public let request: WatchdogStopRequest
  public let requestedMonotonicNanoseconds: UInt64
  public let enforcerInstance: UUID
  public let effect: WatchdogStopEffect
  public let acknowledgedMonotonicNanoseconds: UInt64
  public let terminalEvidenceArtifactSHA256: String
  public let measurements: [BrainExternalSafetyMeasurement]

  public init(sourceRevision: String, scenarioIdentifier: String,
    request: WatchdogStopRequest, requestedMonotonicNanoseconds: UInt64,
    enforcerInstance: UUID, effect: WatchdogStopEffect,
    acknowledgedMonotonicNanoseconds: UInt64,
    terminalEvidenceArtifactSHA256: String,
    measurements: [BrainExternalSafetyMeasurement]) throws {
    formatVersion = Self.formatVersion; self.sourceRevision = sourceRevision
    self.scenarioIdentifier = scenarioIdentifier; self.request = request
    self.requestedMonotonicNanoseconds = requestedMonotonicNanoseconds
    self.enforcerInstance = enforcerInstance; self.effect = effect
    self.acknowledgedMonotonicNanoseconds = acknowledgedMonotonicNanoseconds
    self.terminalEvidenceArtifactSHA256 = terminalEvidenceArtifactSHA256
    self.measurements = measurements.sorted { $0.kind.rawValue < $1.kind.rawValue }
    try validate()
  }

  public func validate() throws {
    try request.validate(); for measurement in measurements { try measurement.validate() }
    guard formatVersion == Self.formatVersion,
      !sourceRevision.isEmpty, sourceRevision.utf8.count <= 256,
      !scenarioIdentifier.isEmpty, scenarioIdentifier.utf8.count <= 256,
      requestedMonotonicNanoseconds > 0,
      acknowledgedMonotonicNanoseconds >= requestedMonotonicNanoseconds,
      effect == .externalActuatorsInhibited,
      PerformanceRunArtifact.isSHA256(terminalEvidenceArtifactSHA256),
      measurements.count == BrainExternalSafetyMeasurementKind.allCases.count,
      Set(measurements.map(\.kind)) == Set(BrainExternalSafetyMeasurementKind.allCases),
      Set(measurements.map(\.rawEvidenceArtifactSHA256)).count == measurements.count,
      measurements.allSatisfy({ $0.settledSampleMonotonicNanoseconds >= acknowledgedMonotonicNanoseconds }) else {
      throw QualificationError.invalid("external safety stop payload is incomplete or noncanonical")
    }
  }

  public func canonicalBytes() throws -> Data {
    try validate()
    return try QualificationFileDirectory.canonicalJSON(self)
  }

  private enum CodingKeys: String, CodingKey {
    case formatVersion, sourceRevision, scenarioIdentifier, request
    case requestedMonotonicNanoseconds, enforcerInstance, effect
    case acknowledgedMonotonicNanoseconds, terminalEvidenceArtifactSHA256, measurements
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    guard try c.decode(UInt32.self, forKey: .formatVersion) == Self.formatVersion else {
      throw QualificationError.invalid("unsupported external safety stop version")
    }
    try self.init(sourceRevision: c.decode(String.self, forKey: .sourceRevision),
      scenarioIdentifier: c.decode(String.self, forKey: .scenarioIdentifier),
      request: c.decode(WatchdogStopRequest.self, forKey: .request),
      requestedMonotonicNanoseconds: c.decode(UInt64.self, forKey: .requestedMonotonicNanoseconds),
      enforcerInstance: c.decode(UUID.self, forKey: .enforcerInstance),
      effect: c.decode(WatchdogStopEffect.self, forKey: .effect),
      acknowledgedMonotonicNanoseconds: c.decode(UInt64.self, forKey: .acknowledgedMonotonicNanoseconds),
      terminalEvidenceArtifactSHA256: c.decode(String.self, forKey: .terminalEvidenceArtifactSHA256),
      measurements: c.decode([BrainExternalSafetyMeasurement].self, forKey: .measurements))
  }
}

/// Detached Ed25519 signature over the exact canonical payload bytes. The raw
/// public key is carried for inspection but authority comes from an independently
/// pinned SHA-256 supplied to the verifier, never from this record itself.
@frozen
public struct BrainSignedExternalSafetyStop: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let payload: BrainExternalSafetyStopPayload
  public let publicKeyRawRepresentation: Data
  public let signature: Data

  public init(payload: BrainExternalSafetyStopPayload,
    publicKeyRawRepresentation: Data, signature: Data) throws {
    formatVersion = Self.formatVersion; self.payload = payload
    self.publicKeyRawRepresentation = publicKeyRawRepresentation
    self.signature = signature
    try validateStructure()
  }

  public func validateStructure() throws {
    try payload.validate()
    guard formatVersion == Self.formatVersion,
      publicKeyRawRepresentation.count == 32, signature.count == 64 else {
      throw QualificationError.invalid("malformed external safety signature record")
    }
  }

  private enum CodingKeys: String, CodingKey {
    case formatVersion, payload, publicKeyRawRepresentation, signature
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    guard try c.decode(UInt32.self, forKey: .formatVersion) == Self.formatVersion else {
      throw QualificationError.invalid("unsupported signed external safety record")
    }
    try self.init(payload: c.decode(BrainExternalSafetyStopPayload.self, forKey: .payload),
      publicKeyRawRepresentation: c.decode(Data.self, forKey: .publicKeyRawRepresentation),
      signature: c.decode(Data.self, forKey: .signature))
  }
}

/// Non-serializable verification result. This proves payload integrity and that
/// it was signed by the configured key, plus declared numeric stop/settlement
/// limits. It does NOT prove the private key is physically isolated, that a
/// sensor was calibrated, or that the enforcer actually actuated hardware.
public final class BrainExternalSafetyStopReceipt: @unchecked Sendable {
  public let sourceRevision: String
  public let scenarioIdentifier: String
  public let evidenceRootSHA256: String
  public let publicKeySHA256: String
  public let stopLatencyNanoseconds: UInt64
  public let measurementEvidenceSHA256: [BrainExternalSafetyMeasurementKind: String]

  fileprivate init(sourceRevision: String, scenarioIdentifier: String,
    evidenceRootSHA256: String, publicKeySHA256: String,
    stopLatencyNanoseconds: UInt64,
    measurementEvidenceSHA256: [BrainExternalSafetyMeasurementKind: String]) {
    self.sourceRevision = sourceRevision; self.scenarioIdentifier = scenarioIdentifier
    self.evidenceRootSHA256 = evidenceRootSHA256; self.publicKeySHA256 = publicKeySHA256
    self.stopLatencyNanoseconds = stopLatencyNanoseconds
    self.measurementEvidenceSHA256 = measurementEvidenceSHA256
  }
}

public final class BrainExternalSafetyEnforcerVerifier: @unchecked Sendable {
  public let sourceRevision: String
  public let expectedEnforcerInstance: UUID
  public let expectedPublicKeySHA256: String
  public let maximumStopLatencyNanoseconds: UInt64
  public let maximumPostStopMeasurementAgeNanoseconds: UInt64

  public init(sourceRevision: String, expectedEnforcerInstance: UUID,
    expectedPublicKeySHA256: String, maximumStopLatencyNanoseconds: UInt64,
    maximumPostStopMeasurementAgeNanoseconds: UInt64) throws {
    guard !sourceRevision.isEmpty, sourceRevision.utf8.count <= 256,
      PerformanceRunArtifact.isSHA256(expectedPublicKeySHA256),
      maximumStopLatencyNanoseconds > 0,
      maximumPostStopMeasurementAgeNanoseconds > 0 else {
      throw QualificationError.invalid("invalid external safety enforcer verifier configuration")
    }
    self.sourceRevision = sourceRevision; self.expectedEnforcerInstance = expectedEnforcerInstance
    self.expectedPublicKeySHA256 = expectedPublicKeySHA256
    self.maximumStopLatencyNanoseconds = maximumStopLatencyNanoseconds
    self.maximumPostStopMeasurementAgeNanoseconds = maximumPostStopMeasurementAgeNanoseconds
  }

  public func verify(_ signed: BrainSignedExternalSafetyStop) throws
    -> BrainExternalSafetyStopReceipt {
    try signed.validateStructure()
    let payload = signed.payload
    guard payload.sourceRevision == sourceRevision,
      payload.enforcerInstance == expectedEnforcerInstance else {
      throw QualificationError.invalid("external safety attestation source or enforcer is foreign")
    }
    let publicKeySHA = BrainPolicyEvidenceArtifact.sha256(signed.publicKeyRawRepresentation)
    guard publicKeySHA == expectedPublicKeySHA256 else {
      throw QualificationError.invalid("external safety attestation key is not pinned")
    }
    let key: Curve25519.Signing.PublicKey
    do { key = try Curve25519.Signing.PublicKey(rawRepresentation: signed.publicKeyRawRepresentation) }
    catch { throw QualificationError.invalid("external safety public key is invalid") }
    let payloadBytes = try payload.canonicalBytes()
    guard key.isValidSignature(signed.signature, for: payloadBytes) else {
      throw QualificationError.invalid("external safety attestation signature is invalid")
    }
    let (latency, underflow) = payload.acknowledgedMonotonicNanoseconds
      .subtractingReportingOverflow(payload.requestedMonotonicNanoseconds)
    guard !underflow, latency <= maximumStopLatencyNanoseconds else {
      throw QualificationError.invalid("external safety stop exceeded its frozen latency bound")
    }
    for measurement in payload.measurements {
      let (age, ageUnderflow) = measurement.settledSampleMonotonicNanoseconds
        .subtractingReportingOverflow(payload.acknowledgedMonotonicNanoseconds)
      guard !ageUnderflow, age <= maximumPostStopMeasurementAgeNanoseconds else {
        throw QualificationError.invalid("external safety settled measurement is outside its frozen window")
      }
    }
    let recordBytes = try QualificationFileDirectory.canonicalJSON(signed)
    let evidenceRoot = BrainPolicyEvidenceArtifact.sha256(recordBytes)
    return BrainExternalSafetyStopReceipt(sourceRevision: sourceRevision,
      scenarioIdentifier: payload.scenarioIdentifier,
      evidenceRootSHA256: evidenceRoot, publicKeySHA256: publicKeySHA,
      stopLatencyNanoseconds: latency,
      measurementEvidenceSHA256: Dictionary(uniqueKeysWithValues:
        payload.measurements.map { ($0.kind, $0.rawEvidenceArtifactSHA256) }))
  }
}

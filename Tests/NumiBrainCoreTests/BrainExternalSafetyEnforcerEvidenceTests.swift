import CryptoKit
import Foundation
import XCTest
@testable import NumiBrainCore
import NumiBrainQualification

final class BrainExternalSafetyEnforcerEvidenceTests: XCTestCase {
  private let process = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
  private let enforcer = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
  private let rawHash = String(repeating: "a", count: 64)

  private func payload() throws -> BrainExternalSafetyStopPayload {
    let request = try WatchdogStopRequest(watchdogInstance: UUID(),
      expectedProcessInstance: process, observed: nil, reason: "force_limit",
      createdUnixNanoseconds: 1_000)
    let measurements = try BrainExternalSafetyMeasurementKind.allCases.enumerated().map { index, kind in
      try BrainExternalSafetyMeasurement(kind: kind,
        unit: kind == .thermal ? "degC" : (kind == .force ? "N" : "normalized"),
        sampleCount: 8, settledSampleMonotonicNanoseconds: 1_250 + UInt64(index),
        settledValue: 0.25, safeLimit: 1,
        rawEvidenceArtifactSHA256: String(repeating: String(format: "%x", index + 1), count: 64))
    }
    return try BrainExternalSafetyStopPayload(sourceRevision: "revision",
      scenarioIdentifier: "force-limit-001", request: request,
      requestedMonotonicNanoseconds: 1_000, enforcerInstance: enforcer,
      effect: .externalActuatorsInhibited, acknowledgedMonotonicNanoseconds: 1_200,
      terminalEvidenceArtifactSHA256: rawHash, measurements: measurements)
  }

  private func signed(privateKey: Curve25519.Signing.PrivateKey,
    payload: BrainExternalSafetyStopPayload? = nil) throws -> BrainSignedExternalSafetyStop {
    let value = try payload ?? self.payload()
    return try BrainSignedExternalSafetyStop(payload: value,
      publicKeyRawRepresentation: privateKey.publicKey.rawRepresentation,
      signature: try privateKey.signature(for: value.canonicalBytes()))
  }

  private func verifier(privateKey: Curve25519.Signing.PrivateKey,
    maximumStopLatency: UInt64 = 500) throws -> BrainExternalSafetyEnforcerVerifier {
    try BrainExternalSafetyEnforcerVerifier(sourceRevision: "revision",
      expectedEnforcerInstance: enforcer,
      expectedPublicKeySHA256: BrainPolicyEvidenceArtifact.sha256(privateKey.publicKey.rawRepresentation),
      maximumStopLatencyNanoseconds: maximumStopLatency,
      maximumPostStopMeasurementAgeNanoseconds: 100)
  }

  func testPinnedSignatureAndAllThreeSettledMeasurementsVerify() throws {
    let key = Curve25519.Signing.PrivateKey(), value = try signed(privateKey: key)
    let receipt = try verifier(privateKey: key).verify(value)
    XCTAssertEqual(receipt.sourceRevision, "revision")
    XCTAssertEqual(receipt.scenarioIdentifier, "force-limit-001")
    XCTAssertEqual(receipt.stopLatencyNanoseconds, 200)
    XCTAssertEqual(Set(receipt.measurementEvidenceSHA256.keys), Set(BrainExternalSafetyMeasurementKind.allCases))
  }

  func testForeignKeyCannotSelfAuthorizeFromCarriedPublicKey() throws {
    let trusted = Curve25519.Signing.PrivateKey(), attacker = Curve25519.Signing.PrivateKey()
    XCTAssertThrowsError(try verifier(privateKey: trusted).verify(signed(privateKey: attacker)))
  }

  func testMutationAfterSigningInvalidatesSignature() throws {
    let key = Curve25519.Signing.PrivateKey(), original = try signed(privateKey: key)
    let changed = try BrainExternalSafetyStopPayload(sourceRevision: original.payload.sourceRevision,
      scenarioIdentifier: "changed", request: original.payload.request,
      requestedMonotonicNanoseconds: original.payload.requestedMonotonicNanoseconds,
      enforcerInstance: original.payload.enforcerInstance, effect: original.payload.effect,
      acknowledgedMonotonicNanoseconds: original.payload.acknowledgedMonotonicNanoseconds,
      terminalEvidenceArtifactSHA256: original.payload.terminalEvidenceArtifactSHA256,
      measurements: original.payload.measurements)
    let forged = try BrainSignedExternalSafetyStop(payload: changed,
      publicKeyRawRepresentation: original.publicKeyRawRepresentation, signature: original.signature)
    XCTAssertThrowsError(try verifier(privateKey: key).verify(forged))
  }

  func testLateStopIsRejectedEvenWithValidSignature() throws {
    let key = Curve25519.Signing.PrivateKey()
    XCTAssertThrowsError(try verifier(privateKey: key, maximumStopLatency: 100)
      .verify(signed(privateKey: key)))
  }

  func testMissingMeasurementClassAndUnsafeSettledValueCannotBeSignedAsValidPayload() throws {
    let base = try payload()
    XCTAssertThrowsError(try BrainExternalSafetyStopPayload(sourceRevision: base.sourceRevision,
      scenarioIdentifier: base.scenarioIdentifier, request: base.request,
      requestedMonotonicNanoseconds: base.requestedMonotonicNanoseconds,
      enforcerInstance: base.enforcerInstance, effect: base.effect,
      acknowledgedMonotonicNanoseconds: base.acknowledgedMonotonicNanoseconds,
      terminalEvidenceArtifactSHA256: base.terminalEvidenceArtifactSHA256,
      measurements: Array(base.measurements.dropLast())))
    XCTAssertThrowsError(try BrainExternalSafetyMeasurement(kind: .force, unit: "N",
      sampleCount: 1, settledSampleMonotonicNanoseconds: 2_000,
      settledValue: 2, safeLimit: 1, rawEvidenceArtifactSHA256: rawHash))
  }

  func testSimulationOnlyEffectCannotEnterExternalSafetyPayload() throws {
    let base = try payload()
    XCTAssertThrowsError(try BrainExternalSafetyStopPayload(sourceRevision: base.sourceRevision,
      scenarioIdentifier: base.scenarioIdentifier, request: base.request,
      requestedMonotonicNanoseconds: base.requestedMonotonicNanoseconds,
      enforcerInstance: base.enforcerInstance, effect: .simulationRootsQuiesced,
      acknowledgedMonotonicNanoseconds: base.acknowledgedMonotonicNanoseconds,
      terminalEvidenceArtifactSHA256: base.terminalEvidenceArtifactSHA256,
      measurements: base.measurements))
  }
}

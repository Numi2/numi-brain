import Foundation
import NumiBrainQualification
import NumiBrainValidation

/// Non-serializable authority produced only by a concrete gate adapter in this
/// process. A SHA, manifest status, CLI exit code, or decoded JSON value cannot
/// be converted into this receipt by callers.
public final class BrainAuthoritativeGateReceipt: @unchecked Sendable {
  public let gate: PromotionGate
  public let sourceRevision: String
  public let evidenceRootSHA256: String
  fileprivate let verifierInstance: UUID
  fileprivate let receiptInstance = UUID()

  fileprivate init(gate: PromotionGate, sourceRevision: String,
    evidenceRootSHA256: String, verifierInstance: UUID) {
    self.gate = gate; self.sourceRevision = sourceRevision
    self.evidenceRootSHA256 = evidenceRootSHA256
    self.verifierInstance = verifierInstance
  }
}

/// Final in-process authority that every A...F adapter succeeded against one
/// source revision. It is intentionally non-Codable and has no public
/// initializer. Production code must still decide where this receipt is
/// consumed; this type does not silently replace existing gate-specific policy
/// admission or physical publication authority.
public final class BrainAllGatesVerificationReceipt: @unchecked Sendable {
  public let sourceRevision: String
  public let evidenceRootSHA256: String
  public let gateEvidenceRootSHA256: [PromotionGate: String]
  fileprivate let verifierInstance: UUID

  fileprivate init(sourceRevision: String, evidenceRootSHA256: String,
    gateEvidenceRootSHA256: [PromotionGate: String], verifierInstance: UUID) {
    self.sourceRevision = sourceRevision
    self.evidenceRootSHA256 = evidenceRootSHA256
    self.gateEvidenceRootSHA256 = gateEvidenceRootSHA256
    self.verifierInstance = verifierInstance
  }
}

public struct BrainAllGatesAdapterStatus: Codable, Equatable, Sendable {
  public let gate: PromotionGate
  public let authoritativeAdapterImplemented: Bool
  public let limitation: String?
}

/// Authoritative coordinator. It does not accept `NumanXQualificationManifest`
/// as evidence because that object is a declaration. Each gate needs an adapter
/// that invokes the gate's actual verifier and returns an unforgeable receipt.
///
/// Current concrete adapters:
/// - C: complete content-addressed policy evidence verifier.
/// - D: recomputed physical-trace evaluation verifier.
/// - E: capture-bound outcome ledger adapter exists, but it is intentionally
///      refused until collector/process/device provenance is authoritative.
///
/// A/B/F remain impossible to mint here until their current-source native
/// evidence surfaces expose verifier-issued receipts. Finalization therefore
/// fails closed today, which is the correct behavior.
public final class BrainAllGatesVerifier: @unchecked Sendable {
  public let sourceRevision: String
  private let verifierInstance = UUID()
  private let lock = NSLock()
  private var issued: [UUID: BrainAuthoritativeGateReceipt] = [:]

  public init(sourceRevision: String) throws {
    guard !sourceRevision.isEmpty, sourceRevision.utf8.count <= 256 else {
      throw QualificationError.invalid("all-gates verifier needs one exact source revision")
    }
    self.sourceRevision = sourceRevision
  }

  public var adapterStatus: [BrainAllGatesAdapterStatus] {
    [
      BrainAllGatesAdapterStatus(gate: .A, authoritativeAdapterImplemented: false,
        limitation: "historical bounded runtime evidence has no current-source verifier receipt adapter"),
      BrainAllGatesAdapterStatus(gate: .B, authoritativeAdapterImplemented: false,
        limitation: "bounded causal sensorium evidence has no current-source verifier receipt adapter"),
      BrainAllGatesAdapterStatus(gate: .C, authoritativeAdapterImplemented: true, limitation: nil),
      BrainAllGatesAdapterStatus(gate: .D, authoritativeAdapterImplemented: true, limitation: nil),
      BrainAllGatesAdapterStatus(gate: .E, authoritativeAdapterImplemented: false,
        limitation: "native terminal rows can be verified, but timing/counter/process/device collector authority is not yet authenticated"),
      BrainAllGatesAdapterStatus(gate: .F, authoritativeAdapterImplemented: false,
        limitation: "safety campaigns and watchdog reports are not independent physical-stop/deployment authority"),
    ]
  }

  /// Invokes the existing transitive Gate C verifier. Structural package
  /// validation alone is insufficient.
  public func verifyGateC(package: BrainFoundationPolicyPackage,
    artifactDirectory: URL) throws -> BrainAuthoritativeGateReceipt {
    guard package.sourceRevision == sourceRevision else {
      throw QualificationError.invalid("Gate C package source differs from all-gates source")
    }
    let evidence = try BrainFoundationPolicyEvidenceVerifier.verify(
      package: package, artifactDirectory: artifactDirectory)
    try evidence.validate(package: package)
    return try issue(gate: .C, evidenceRootSHA256: evidence.evidenceRootSHA256)
  }

  /// Recomputes the retained Gate D evaluation, then follows its candidate back
  /// to the exact native capture source revision. Failed/inconclusive physical
  /// validation cannot mint authority.
  public func verifyGateD(evaluationSHA256: String,
    artifactDirectory: URL) throws -> BrainAuthoritativeGateReceipt {
    let evaluation = try BrainGateDEvidence.verifyTraceEvaluation(
      sha256: evaluationSHA256, artifactDirectory: artifactDirectory)
    guard evaluation.result.status == .passed else {
      throw QualificationError.invalid("Gate D evaluation is not physically passed")
    }
    let candidate = try BrainGateDEvidence.verifySensorTrace(
      sha256: evaluation.candidateSHA256, artifactDirectory: artifactDirectory)
    guard candidate.sourceRevision == sourceRevision else {
      throw QualificationError.invalid("Gate D native capture source differs from all-gates source")
    }
    let rootPayload = [evaluationSHA256, evaluation.evidenceSHA256,
      candidate.runEvidenceSHA256].sorted()
    let root = BrainPolicyEvidenceArtifact.sha256(
      try QualificationFileDirectory.canonicalJSON(rootPayload))
    return try issue(gate: .D, evidenceRootSHA256: root)
  }

  /// Executes the strongest current Gate E adapter but refuses to mint a gate
  /// receipt while collector provenance remains diagnostic. This is a real
  /// verifier call, not a trusted `passed` Boolean.
  public func verifyGateE(ledger: PerformanceAttemptLedger,
    protocol performanceProtocol: PerformanceAttemptProtocol,
    captureRunArtifactSHA256: String, artifactDirectory: URL) throws
    -> BrainAuthoritativeGateReceipt {
    let evidence = try BrainPerformanceAttemptLedgerEvidence.verify(
      ledger: ledger, protocol: performanceProtocol,
      captureRunArtifactSHA256: captureRunArtifactSHA256,
      artifactDirectory: artifactDirectory)
    guard ledger.sourceRevision == sourceRevision,
      evidence.evaluation.passed, evidence.collectorAuthorityVerified else {
      throw QualificationError.invalid("Gate E evidence is measured/consistent but not collector-authoritative")
    }
    return try issue(gate: .E, evidenceRootSHA256: evidence.ledgerEvidenceSHA256)
  }

  /// Requires exactly one receipt for every gate, all issued by THIS verifier
  /// instance and this source revision. Receipts are single-finalization inputs:
  /// duplicate or foreign objects are rejected even if their public fields are
  /// textually identical.
  public func finalize(_ receipts: [BrainAuthoritativeGateReceipt]) throws
    -> BrainAllGatesVerificationReceipt {
    lock.lock(); defer { lock.unlock() }
    guard receipts.count == PromotionGate.allCases.count,
      Set(receipts.map(\.gate)) == Set(PromotionGate.allCases),
      Set(receipts.map(\.receiptInstance)).count == receipts.count,
      receipts.allSatisfy({ receipt in
        receipt.verifierInstance == verifierInstance
          && receipt.sourceRevision == sourceRevision
          && issued[receipt.receiptInstance] === receipt
          && PerformanceRunArtifact.isSHA256(receipt.evidenceRootSHA256)
      }) else {
      throw QualificationError.invalid("all-gates finalization lacks one exact authoritative A...F receipt set")
    }
    let roots = Dictionary(uniqueKeysWithValues: receipts.map { ($0.gate, $0.evidenceRootSHA256) })
    let canonical = PromotionGate.allCases.sorted { $0.rawValue < $1.rawValue }.map {
      $0.rawValue + ":" + roots[$0]!
    }
    let evidenceRoot = BrainPolicyEvidenceArtifact.sha256(
      try QualificationFileDirectory.canonicalJSON(canonical))
    return BrainAllGatesVerificationReceipt(sourceRevision: sourceRevision,
      evidenceRootSHA256: evidenceRoot, gateEvidenceRootSHA256: roots,
      verifierInstance: verifierInstance)
  }

  /// Deliberately no public adapters for A/B/F. Adding one requires invoking an
  /// actual native/current-source verifier, not wrapping a declaration hash.
  private func issue(gate: PromotionGate, evidenceRootSHA256: String) throws
    -> BrainAuthoritativeGateReceipt {
    guard PerformanceRunArtifact.isSHA256(evidenceRootSHA256) else {
      throw QualificationError.invalid("gate verifier produced a noncanonical evidence root")
    }
    lock.lock(); defer { lock.unlock() }
    if issued.values.contains(where: { $0.gate == gate }) {
      throw QualificationError.invalid("one all-gates verifier cannot mint the same gate twice")
    }
    let receipt = BrainAuthoritativeGateReceipt(gate: gate,
      sourceRevision: sourceRevision, evidenceRootSHA256: evidenceRootSHA256,
      verifierInstance: verifierInstance)
    issued[receipt.receiptInstance] = receipt
    return receipt
  }
}

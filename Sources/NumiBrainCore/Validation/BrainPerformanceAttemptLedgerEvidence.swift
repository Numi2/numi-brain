import Foundation
import NumiBrainQualification

/// Diagnostic receipt proving that every terminal row in a Gate E attempt
/// ledger names the exact retained authoritative NumanX capture transcript and
/// that the supplied protocol bytes hash to the ledger's frozen protocol hash.
/// It deliberately does NOT authenticate wall-clock collection, process RSS,
/// hardware identity, executable/metallib hashes, power, or counter provenance.
public struct BrainVerifiedPerformanceAttemptLedger: Sendable {
  public let captureRunArtifactSHA256: String
  public let captureTransitiveEvidenceSHA256: String
  public let protocolSHA256: String
  public let ledgerEvidenceSHA256: String
  public let evaluation: PerformanceAttemptEvaluation
  public let nativeTerminalEvidenceVerified: Bool
  public let protocolBytesVerified: Bool
  public let collectorAuthorityVerified: Bool

  fileprivate init(captureRunArtifactSHA256: String,
    captureTransitiveEvidenceSHA256: String, protocolSHA256: String,
    ledgerEvidenceSHA256: String, evaluation: PerformanceAttemptEvaluation) {
    self.captureRunArtifactSHA256 = captureRunArtifactSHA256
    self.captureTransitiveEvidenceSHA256 = captureTransitiveEvidenceSHA256
    self.protocolSHA256 = protocolSHA256
    self.ledgerEvidenceSHA256 = ledgerEvidenceSHA256
    self.evaluation = evaluation
    nativeTerminalEvidenceVerified = true
    protocolBytesVerified = true
    collectorAuthorityVerified = false
  }
}

public enum BrainPerformanceAttemptLedgerEvidence {
  private struct EvidenceRoot: Codable {
    let captureRunArtifactSHA256: String
    let captureTransitiveEvidenceSHA256: String
    let protocolSHA256: String
    let ledgerSHA256: String
  }

  /// Verifies terminal outcome identity against the existing content-addressed
  /// Gate C capture verifier. The capture path currently owns one sequential
  /// environment; a multi-environment performance collector needs its own
  /// authoritative batch transcript rather than duplicating environment zero.
  public static func verify(ledger: PerformanceAttemptLedger,
    protocol performanceProtocol: PerformanceAttemptProtocol,
    captureRunArtifactSHA256: String, artifactDirectory: URL) throws
    -> BrainVerifiedPerformanceAttemptLedger {
    try ledger.validate(); try performanceProtocol.validate()
    guard ledger.workload.environmentCount == 1 else {
      throw QualificationError.invalid("capture-bound Gate E verification currently requires exactly one native environment")
    }
    let protocolBytes = try QualificationFileDirectory.canonicalJSON(performanceProtocol)
    let protocolSHA256 = BrainPolicyEvidenceArtifact.sha256(protocolBytes)
    guard protocolSHA256 == ledger.protocolSHA256 else {
      throw QualificationError.invalid("Gate E ledger does not bind the exact performance protocol bytes")
    }
    let captureReceipt = try BrainPolicyNumanXCaptureVerifier.verify(
      runArtifactSHA256: captureRunArtifactSHA256,
      artifactDirectory: artifactDirectory)
    let run = try BrainPolicyNumanXCaptureRunArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: captureRunArtifactSHA256, directory: artifactDirectory))
    guard run.sourceRevision == ledger.sourceRevision,
      run.timestepMicroseconds == nil || run.timestepMicroseconds == ledger.workload.timestepMicroseconds,
      run.roots.count == ledger.attempts.count,
      captureReceipt.rootCount == UInt64(ledger.attempts.count) else {
      throw QualificationError.invalid("Gate E ledger differs from its retained capture source, timestep or root count")
    }
    var accepted: UInt64 = 0, rejected: UInt64 = 0
    for (root, row) in zip(run.roots, ledger.attempts) {
      let sample = try BrainPolicyNumanXRootSampleArtifact.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(
          sha256: root.sampleSHA256, directory: artifactDirectory))
      let execution = try BrainPolicyNumanXRootExecution.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(
          sha256: root.executionSHA256, directory: artifactDirectory))
      guard row.environment == 0,
        row.controlStepIdentifier == UInt64(root.controlStep),
        row.controlStepIdentifier == UInt64(execution.controlStep),
        row.transactionFingerprint == execution.transactionFingerprint,
        row.transactionFingerprint == sample.transactionFingerprint,
        row.baseGeneration == sample.basePhysicsGeneration,
        row.committedTimeMicroseconds == sample.committedTimestampMicroseconds,
        row.targetTimeMicroseconds == sample.targetTimestampMicroseconds,
        row.terminalEvidenceSHA256 == root.executionSHA256 else {
        throw QualificationError.invalid("Gate E attempt row is not the exact retained native root")
      }
      switch execution.outcome {
      case .accepted:
        let (next, overflow) = sample.basePhysicsGeneration.addingReportingOverflow(1)
        guard !overflow, row.outcome == .accepted,
          row.publishedGeneration == next,
          row.publishedTimeMicroseconds == sample.targetTimestampMicroseconds else {
          throw QualificationError.invalid("Gate E accepted row changes authoritative publication semantics")
        }
        accepted += 1
      case .rejected:
        guard row.outcome == .rejected,
          row.publishedGeneration == sample.basePhysicsGeneration,
          row.publishedTimeMicroseconds == sample.committedTimestampMicroseconds else {
          throw QualificationError.invalid("Gate E rejected row changes restored-root semantics")
        }
        rejected += 1
      case .commandFailure:
        // The Gate C retained capture verifier itself rejects command-failure
        // transcripts. They require a separate owner-issued terminal-failure
        // surface before Gate E can count them as authenticated attempts.
        throw QualificationError.invalid("capture-bound Gate E evidence cannot authenticate command-failure rows")
      }
    }
    guard accepted == captureReceipt.acceptedRootCount,
      rejected == captureReceipt.rejectedRootCount else {
      throw QualificationError.invalid("Gate E outcome counts differ from authoritative capture evidence")
    }
    let evaluation = try PerformanceAttemptEvaluation(
      ledger: ledger, protocol: performanceProtocol)
    let ledgerBytes = try QualificationFileDirectory.canonicalJSON(ledger)
    let ledgerSHA256 = BrainPolicyEvidenceArtifact.sha256(ledgerBytes)
    let root = EvidenceRoot(captureRunArtifactSHA256: captureRunArtifactSHA256,
      captureTransitiveEvidenceSHA256: captureReceipt.transitiveEvidenceSHA256,
      protocolSHA256: protocolSHA256, ledgerSHA256: ledgerSHA256)
    let evidenceSHA256 = BrainPolicyEvidenceArtifact.sha256(
      try QualificationFileDirectory.canonicalJSON(root))
    return BrainVerifiedPerformanceAttemptLedger(
      captureRunArtifactSHA256: captureRunArtifactSHA256,
      captureTransitiveEvidenceSHA256: captureReceipt.transitiveEvidenceSHA256,
      protocolSHA256: protocolSHA256, ledgerEvidenceSHA256: evidenceSHA256,
      evaluation: evaluation)
  }
}

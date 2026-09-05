import Foundation
import NumiBrainQualification

/// Bounded host-side admission bookkeeping. This is NOT a substitute for the
/// mandatory GPU protective motor gate or proof of physical publication.
/// Native owners report terminal outcomes only after their authoritative close.
public actor BrainSafetyAdmissionController {
  public struct Configuration: Sendable {
    public let envelope: SafetyEnvelope
    public let requireContiguousBrainGeneration: Bool
    public let requireContiguousControlStep: Bool
    public init(envelope: SafetyEnvelope, requireContiguousBrainGeneration: Bool = true,
      requireContiguousControlStep: Bool = true) {
      self.envelope = envelope; self.requireContiguousBrainGeneration = requireContiguousBrainGeneration
      self.requireContiguousControlStep = requireContiguousControlStep
    }
  }

  /// Non-serializable and specific to one controller and one evaluation.
  public struct Receipt: Equatable, Sendable {
    public let transactionFingerprint: UInt64
    public let parameterVersionFingerprint: UInt64
    public let baseBrainGeneration: UInt64
    public let controlStepIdentifier: UInt64
    public let disposition: SafetyDisposition
    public let reasons: [String]
    fileprivate let issuer: UUID
    fileprivate let evaluation: UUID
    fileprivate init(transaction: BrainJointTransactionToken, decision: SafetyDecision, issuer: UUID) {
      transactionFingerprint = transaction.fingerprint; parameterVersionFingerprint = transaction.parameterVersionFingerprint
      baseBrainGeneration = transaction.baseBrainGeneration; controlStepIdentifier = transaction.controlStepIdentifier
      disposition = decision.disposition; reasons = decision.reasons; self.issuer = issuer; evaluation = UUID()
    }
  }

  private let configuration: Configuration
  private let issuer = UUID()
  private var lastAccepted: BrainJointTransactionToken?
  private var lastResolved: BrainJointTransactionToken?
  private var lastWasRejected = false
  private var pending: (token: BrainJointTransactionToken, receipt: Receipt)?
  private var scope: BrainJointTransactionToken?

  public init(configuration: Configuration) { self.configuration = configuration }

  public func evaluate(transaction: BrainJointTransactionToken, vector supplied: SafetyVector) throws -> Receipt {
    // Any reevaluation invalidates an earlier receipt, including when the new
    // input is malformed or a later observation requests a stop.
    let conflictingPending = pending.map { $0.token != transaction } ?? false
    pending = nil
    try supplied.validate(); try configuration.envelope.validate()
    var stale = supplied.staleGeneration || conflictingPending
    if let scope {
      stale = stale || scope.environmentIdentifier != transaction.environmentIdentifier
        || scope.episodeIdentifier != transaction.episodeIdentifier
        || scope.parameterVersionFingerprint != transaction.parameterVersionFingerprint
    }
    if let accepted = lastAccepted {
      if configuration.requireContiguousBrainGeneration {
        stale = stale || transaction.baseBrainGeneration != accepted.shadowGeneration
      } else { stale = stale || transaction.baseBrainGeneration <= accepted.baseBrainGeneration }
      stale = stale || transaction.committedTimestamp != accepted.targetTimestamp
    }
    if let resolved = lastResolved {
      let exactRejectedRetry = lastWasRejected && transaction == resolved
      if !exactRejectedRetry {
        if configuration.requireContiguousControlStep {
          let (expected, overflow) = resolved.controlStepIdentifier.addingReportingOverflow(1)
          stale = stale || overflow || transaction.controlStepIdentifier != expected
        } else { stale = stale || transaction.controlStepIdentifier <= resolved.controlStepIdentifier }
      }
    }
    let replay = lastAccepted?.fingerprint == transaction.fingerprint
    let vector = try SafetyVector(semanticRisk: supplied.semanticRisk, kinematicRisk: supplied.kinematicRisk,
      contactRisk: supplied.contactRisk, forceRisk: supplied.forceRisk, thermalRisk: supplied.thermalRisk,
      actuatorRisk: supplied.actuatorRisk, uncertainty: supplied.uncertainty, staleGeneration: stale,
      malformedRecord: supplied.malformedRecord, resourceAlias: supplied.resourceAlias || replay,
      deviceFault: supplied.deviceFault)
    let receipt = Receipt(transaction: transaction, decision: SafetyDecision(vector: vector, envelope: configuration.envelope), issuer: issuer)
    if receipt.disposition == .allow {
      if scope == nil { scope = transaction }
      pending = (transaction, receipt)
    }
    return receipt
  }

  /// Notification from the existing native publication owner. This consumes
  /// only the most recent matching allow receipt, exactly once.
  public func recordPublished(transaction: BrainJointTransactionToken, receipt: Receipt) throws {
    try requirePending(transaction, receipt)
    pending = nil; lastAccepted = transaction; lastResolved = transaction; lastWasRejected = false
  }

  /// Discards an admission after an authoritative rejection; no accepted
  /// generation or physical time advances. Exact root retries remain allowed.
  public func recordRejected(transaction: BrainJointTransactionToken, receipt: Receipt) throws {
    try requirePending(transaction, receipt)
    pending = nil; lastResolved = transaction; lastWasRejected = true
  }

  private func requirePending(_ transaction: BrainJointTransactionToken, _ receipt: Receipt) throws {
    guard receipt.issuer == issuer, receipt.disposition == .allow,
      let pending, pending.token == transaction, pending.receipt == receipt else {
      throw BrainRuntimeError.transaction("safety receipt is foreign, superseded, consumed or not allowed")
    }
  }

  @available(*, deprecated, message: "Scalar identities are not verified recovery. Reconstruct admission with the joint recovery owner; this legacy reset fails closed.")
  public func resetAfterVerifiedRecovery(baseBrainGeneration: UInt64,
    controlStepIdentifier: UInt64, transactionFingerprint: UInt64) throws {
    pending = nil
    throw BrainRuntimeError.transaction("scalar recovery reset cannot establish joint brain/physics authority")
  }
}

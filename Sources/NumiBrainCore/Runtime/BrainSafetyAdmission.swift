import Foundation
import NumiBrainQualification

/// Authoritative pre-handoff safety admission for one immutable root token.
/// This object owns no physics and cannot publish a root. It only converts
/// measured/derived bounded risks plus exact token continuity into a fail-closed
/// disposition that the NumanX owner can require before physical handoff.
public actor BrainSafetyAdmissionController {
  public struct Configuration: Sendable {
    public let envelope: SafetyEnvelope
    public let requireContiguousBrainGeneration: Bool
    public let requireContiguousControlStep: Bool

    public init(envelope: SafetyEnvelope, requireContiguousBrainGeneration: Bool = true,
      requireContiguousControlStep: Bool = true) {
      self.envelope = envelope
      self.requireContiguousBrainGeneration = requireContiguousBrainGeneration
      self.requireContiguousControlStep = requireContiguousControlStep
    }
  }

  @frozen
  public struct Receipt: Equatable, Sendable {
    public let transactionFingerprint: UInt64
    public let parameterVersionFingerprint: UInt64
    public let baseBrainGeneration: UInt64
    public let controlStepIdentifier: UInt64
    public let disposition: SafetyDisposition
    public let reasons: [String]

    fileprivate init(transaction: BrainJointTransactionToken, decision: SafetyDecision) {
      transactionFingerprint = transaction.fingerprint
      parameterVersionFingerprint = transaction.parameterVersionFingerprint
      baseBrainGeneration = transaction.baseBrainGeneration
      controlStepIdentifier = transaction.controlStepIdentifier
      disposition = decision.disposition
      reasons = decision.reasons
    }
  }

  private let configuration: Configuration
  private var lastAcceptedBaseGeneration: UInt64?
  private var lastAcceptedControlStep: UInt64?
  private var lastAcceptedTransactionFingerprint: UInt64?

  public init(configuration: Configuration) {
    self.configuration = configuration
  }

  /// Evaluates a root before physical handoff. Token continuity is converted
  /// into the same hard-fault path as malformed/stale evidence. This method
  /// does not mutate continuity for rejected, supervision, or stopped roots.
  public func evaluate(transaction: BrainJointTransactionToken, vector supplied: SafetyVector)
    throws -> Receipt
  {
    var stale = supplied.staleGeneration
    if let prior = lastAcceptedBaseGeneration {
      if configuration.requireContiguousBrainGeneration {
        let (expected, overflow) = prior.addingReportingOverflow(1)
        stale = stale || overflow || transaction.baseBrainGeneration != expected
      } else {
        stale = stale || transaction.baseBrainGeneration <= prior
      }
    }
    if let priorStep = lastAcceptedControlStep {
      if configuration.requireContiguousControlStep {
        let (expected, overflow) = priorStep.addingReportingOverflow(1)
        stale = stale || overflow || transaction.controlStepIdentifier != expected
      } else {
        stale = stale || transaction.controlStepIdentifier <= priorStep
      }
    }
    let replay = lastAcceptedTransactionFingerprint == transaction.fingerprint
    let vector = try SafetyVector(
      semanticRisk: supplied.semanticRisk,
      kinematicRisk: supplied.kinematicRisk,
      contactRisk: supplied.contactRisk,
      forceRisk: supplied.forceRisk,
      thermalRisk: supplied.thermalRisk,
      actuatorRisk: supplied.actuatorRisk,
      uncertainty: supplied.uncertainty,
      staleGeneration: stale,
      malformedRecord: supplied.malformedRecord,
      resourceAlias: supplied.resourceAlias || replay,
      deviceFault: supplied.deviceFault
    )
    return Receipt(transaction: transaction, decision: SafetyDecision(vector: vector, envelope: configuration.envelope))
  }

  /// Advances continuity only after the owner has published the exact root.
  /// A receipt from allow/supervision/stop cannot be substituted for another
  /// transaction, and rejected roots never advance the safety history.
  public func recordPublished(transaction: BrainJointTransactionToken, receipt: Receipt) throws {
    guard receipt.transactionFingerprint == transaction.fingerprint,
      receipt.parameterVersionFingerprint == transaction.parameterVersionFingerprint,
      receipt.baseBrainGeneration == transaction.baseBrainGeneration,
      receipt.controlStepIdentifier == transaction.controlStepIdentifier,
      receipt.disposition == .allow else {
      throw BrainRuntimeError.transaction("safety receipt cannot authorize this published root")
    }
    lastAcceptedBaseGeneration = transaction.baseBrainGeneration
    lastAcceptedControlStep = transaction.controlStepIdentifier
    lastAcceptedTransactionFingerprint = transaction.fingerprint
  }

  public func resetAfterVerifiedRecovery(baseBrainGeneration: UInt64,
    controlStepIdentifier: UInt64, transactionFingerprint: UInt64) throws {
    guard transactionFingerprint > 0 else {
      throw BrainRuntimeError.transaction("verified recovery requires a transaction identity")
    }
    lastAcceptedBaseGeneration = baseBrainGeneration
    lastAcceptedControlStep = controlStepIdentifier
    lastAcceptedTransactionFingerprint = transactionFingerprint
  }
}

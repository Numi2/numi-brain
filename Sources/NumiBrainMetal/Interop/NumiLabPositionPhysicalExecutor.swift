import Foundation
import NumiBrainCore

@available(macOS 26.0, *)
@frozen
public struct NumiLabPhysicalOwnerStateProof: Equatable, Sendable {
  public let liveRollout: NumiLabLiveRolloutSnapshot
  public let physicalStateFingerprint: UInt64
  public let physicsGeneration: UInt64

  public init(liveRollout: NumiLabLiveRolloutSnapshot,
    physicalStateFingerprint: UInt64, physicsGeneration: UInt64) throws {
    guard physicalStateFingerprint != 0, physicsGeneration > 0 else {
      throw TissueError.transaction("NumiLab physical owner state proof is empty")
    }
    self.liveRollout = liveRollout
    self.physicalStateFingerprint = physicalStateFingerprint
    self.physicsGeneration = physicsGeneration
  }
}

@available(macOS 26.0, *)
@frozen
public struct NumiLabExecutedPositionCandidate: Sendable {
  public let actionFrame: NumiLabPositionHostActionFrame
  public let advanceReceipt: NumiLabRolloutAdvanceReceipt
  public let acceptedPhysicsReceipt: NumiLabAcceptedPhysicsReceipt
  public let acceptedPhysicsState: AcceptedPhysicsStateToken
}

/// Ordered compatibility execution of one position-command candidate.
/// The native owner supplies its logical-byte resident digest. This function
/// holds exclusive rollout access across advance and digest capture, but does
/// not commit the Brain root or roll the physical world back. A post-advance
/// failure quarantines the target until disposal and fresh physical restoration.
@available(macOS 26.0, *)
public enum NumiLabPositionPhysicalExecutor {
  public static func execute(submission: NumiLabPositionMotorSubmission,
    lease: MetalTissueRuntime.NumanXMotorBufferLease,
    encoder: NumiLabPositionActionEncoder, transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken, rollout: NumiLabBorrowedTaskRollout,
    policyRevision: UInt64 = 0) throws -> NumiLabExecutedPositionCandidate {
    return try rollout.withExclusiveAccess {
      // This fallible preflight must run BEFORE native physics can mutate.
      let (physicsGeneration, overflow) = transaction.basePhysicsGeneration.addingReportingOverflow(1)
      guard !overflow else { throw TissueError.transaction("NumiLab accepted physics generation overflow") }
      let before = try rollout.snapshot()
      try submission.validate(transaction: transaction, substep: substep, liveRollout: before.identity)
      let frame = try NumiLabPositionHostActionAdapter.makeFrame(submission: submission,
        lease: lease, encoder: encoder, transaction: transaction, substep: substep, liveRollout: before.identity)
      let advance = try rollout.advance(frame: frame, policyRevision: policyRevision)
      do {
        guard advance.before == before, advance.fullyAccepted else {
          throw TissueError.transaction("NumiLab execution receipt is not the admitted pre-advance rollout")
        }
        let physicalStateFingerprint = try rollout.residentStateFingerprint()
        let liveAfterProof = try rollout.snapshot()
        guard liveAfterProof == advance.after else {
          throw TissueError.transaction("NumiLab resident-state fingerprint was not captured at the accepted rollout boundary")
        }
        let proof = try NumiLabPhysicalOwnerStateProof(liveRollout: liveAfterProof,
          physicalStateFingerprint: physicalStateFingerprint, physicsGeneration: physicsGeneration)
        let receipt = try NumiLabAcceptedPhysicsReceipt(submission: submission, transaction: transaction,
          substep: substep, advance: advance, physicalStateFingerprint: proof.physicalStateFingerprint,
          physicsGeneration: proof.physicsGeneration)
        let accepted = try receipt.acceptedPhysicsStateToken(transaction: transaction,
          substep: substep, liveRollout: proof.liveRollout)
        return NumiLabExecutedPositionCandidate(actionFrame: frame, advanceReceipt: advance,
          acceptedPhysicsReceipt: receipt, acceptedPhysicsState: accepted)
      } catch {
        rollout.quarantine(after: error)
        throw error
      }
    }
  }
}

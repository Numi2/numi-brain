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

/// Ordered host-action compatibility execution, not a joint publication owner.
/// Producer completion, native generation, action conversion, advance and digest
/// capture are admitted in order. A post-advance failure quarantines the world;
/// neither this function nor Brain abort is claimed to restore physical state.
@available(macOS 26.0, *)
public enum NumiLabPositionPhysicalExecutor {
  public static func execute(submission: NumiLabPositionMotorSubmission,
    ticket: MetalTissueRuntime.NumanXMotorSubmissionTicket,
    encoder: NumiLabPositionActionEncoder, transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken, rollout: NumiLabBorrowedTaskRollout,
    policyRevision: UInt64 = 0) throws -> NumiLabExecutedPositionCandidate {
    return try rollout.withExclusiveAccess {
      let before = try rollout.snapshot()
      // Reject exhausted/stale/reused roots BEFORE native physics can mutate.
      let physicsGeneration = try before.nextPhysicsGeneration(expectedBase: transaction.basePhysicsGeneration)
      try submission.validate(transaction: transaction, substep: substep, liveRollout: before.identity)
      let frame = try NumiLabPositionHostActionAdapter.makeFrame(submission: submission,
        ticket: ticket, encoder: encoder, transaction: transaction, substep: substep, liveRollout: before.identity)
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

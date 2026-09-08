import Foundation
import NumiBrainCore

@available(macOS 26.0, *)
@frozen
public struct NumiLabPhysicalOwnerStateProof: Equatable, Sendable {
  public let liveRollout: NumiLabLiveRolloutSnapshot
  public let physicalStateFingerprint: UInt64
  public let physicsGeneration: UInt64

  public init(
    liveRollout: NumiLabLiveRolloutSnapshot,
    physicalStateFingerprint: UInt64,
    physicsGeneration: UInt64
  ) throws {
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
///
/// This function deliberately stops after producing the canonical accepted
/// physics token. It never calls Brain commit APIs. The caller must pass the
/// returned token to the already-existing joint transaction, which preserves
/// the sole authoritative accept/commit/abort ordering.
@available(macOS 26.0, *)
public enum NumiLabPositionPhysicalExecutor {
  public static func execute(
    submission: NumiLabPositionMotorSubmission,
    lease: MetalTissueRuntime.NumanXMotorBufferLease,
    encoder: NumiLabPositionActionEncoder,
    transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken,
    rollout: NumiLabBorrowedTaskRollout,
    policyRevision: UInt64 = 0,
    physicalStateProof: (NumiLabLiveRolloutSnapshot) throws -> NumiLabPhysicalOwnerStateProof
  ) throws -> NumiLabExecutedPositionCandidate {
    let before = try rollout.snapshot()
    try submission.validate(
      transaction: transaction,
      substep: substep,
      liveRollout: before.identity
    )
    let frame = try NumiLabPositionHostActionAdapter.makeFrame(
      submission: submission,
      lease: lease,
      encoder: encoder,
      transaction: transaction,
      substep: substep,
      liveRollout: before.identity
    )
    let advance = try rollout.advance(frame: frame, policyRevision: policyRevision)
    guard advance.before == before, advance.fullyAccepted else {
      throw TissueError.transaction(
        "NumiLab execution receipt is not the admitted pre-advance rollout"
      )
    }
    let proof = try physicalStateProof(advance.after)
    guard proof.liveRollout == advance.after else {
      throw TissueError.transaction(
        "NumiLab physical state proof belongs to a different post-advance rollout"
      )
    }
    let receipt = try NumiLabAcceptedPhysicsReceipt(
      submission: submission,
      transaction: transaction,
      substep: substep,
      advance: advance,
      physicalStateFingerprint: proof.physicalStateFingerprint,
      physicsGeneration: proof.physicsGeneration
    )
    let accepted = try receipt.acceptedPhysicsStateToken(
      transaction: transaction,
      substep: substep,
      liveRollout: proof.liveRollout
    )
    return NumiLabExecutedPositionCandidate(
      actionFrame: frame,
      advanceReceipt: advance,
      acceptedPhysicsReceipt: receipt,
      acceptedPhysicsState: accepted
    )
  }
}

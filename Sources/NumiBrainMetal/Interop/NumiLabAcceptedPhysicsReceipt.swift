import Foundation
import NumiBrainCore

/// Physical-owner evidence for one accepted NumiLab candidate. NumiBrain does
/// not manufacture `physicalStateFingerprint`: the owner must compute it from
/// its complete accepted state (including all state necessary for continuation)
/// after the native solver accepts this exact candidate.
@available(macOS 26.0, *)
@frozen
public struct NumiLabAcceptedPhysicsReceipt: Equatable, Sendable {
  public let transactionFingerprint: UInt64
  public let substepFingerprint: UInt64
  public let motorCandidateFingerprint: UInt64
  public let compiledRunFingerprint: UInt64
  public let worldFingerprint: UInt64
  public let taskFingerprint: UInt64
  public let actionFingerprint: UInt64
  public let robotFingerprint: UInt64
  public let physicalStateFingerprint: UInt64
  public let physicsGeneration: UInt64
  public let environmentIdentifier: UInt32
  public let preAdvanceSubmissionCount: UInt64
  public let acceptedSubmissionCount: UInt64

  public init(
    submission: NumiLabPositionMotorSubmission,
    transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken,
    advance: NumiLabRolloutAdvanceReceipt,
    physicalStateFingerprint: UInt64,
    physicsGeneration: UInt64
  ) throws {
    let liveRollout = advance.after.identity
    try submission.validate(
      transaction: transaction,
      substep: substep,
      liveRollout: liveRollout
    )
    let (expectedGeneration, overflow) =
      transaction.basePhysicsGeneration.addingReportingOverflow(1)
    guard !overflow,
      advance.fullyAccepted,
      advance.before.identity == liveRollout,
      advance.after.identity == liveRollout,
      advance.after.submissionCount == advance.before.submissionCount + 1,
      advance.after.submittedControlSteps == advance.before.submittedControlSteps + 1,
      advance.after.completedEnvironmentSteps
        == advance.before.completedEnvironmentSteps + 1,
      physicalStateFingerprint != 0,
      physicsGeneration == expectedGeneration,
      submission.environmentIdentifier == transaction.environmentIdentifier
    else {
      throw TissueError.transaction(
        "NumiLab accepted-physics owner proof lacks one exact accepted physical advance"
      )
    }
    transactionFingerprint = transaction.fingerprint
    substepFingerprint = substep.fingerprint
    motorCandidateFingerprint = submission.motorCandidateFingerprint
    compiledRunFingerprint = liveRollout.runFingerprint
    worldFingerprint = liveRollout.worldFingerprint
    taskFingerprint = liveRollout.taskFingerprint
    actionFingerprint = liveRollout.actionFingerprint
    robotFingerprint = liveRollout.robotFingerprint
    self.physicalStateFingerprint = physicalStateFingerprint
    self.physicsGeneration = physicsGeneration
    environmentIdentifier = transaction.environmentIdentifier
    preAdvanceSubmissionCount = advance.before.submissionCount
    acceptedSubmissionCount = advance.after.submissionCount
  }

  public func acceptedPhysicsStateToken(
    transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken,
    liveRollout: NumiLabLiveRolloutSnapshot
  ) throws -> AcceptedPhysicsStateToken {
    let (expectedGeneration, overflow) =
      transaction.basePhysicsGeneration.addingReportingOverflow(1)
    guard !overflow,
      transactionFingerprint == transaction.fingerprint,
      substepFingerprint == substep.fingerprint,
      environmentIdentifier == transaction.environmentIdentifier,
      physicsGeneration == expectedGeneration,
      physicalStateFingerprint != 0,
      acceptedSubmissionCount == preAdvanceSubmissionCount + 1,
      liveRollout.submissionCount == acceptedSubmissionCount,
      compiledRunFingerprint == liveRollout.identity.runFingerprint,
      worldFingerprint == liveRollout.identity.worldFingerprint,
      taskFingerprint == liveRollout.identity.taskFingerprint,
      actionFingerprint == liveRollout.identity.actionFingerprint,
      robotFingerprint == liveRollout.identity.robotFingerprint else {
      throw TissueError.transaction(
        "NumiLab accepted-physics receipt no longer belongs to this live accepted root"
      )
    }
    return try AcceptedPhysicsStateToken(
      transaction: transaction,
      substep: substep,
      physicsStateFingerprint: physicalStateFingerprint,
      physicsGeneration: physicsGeneration
    )
  }
}

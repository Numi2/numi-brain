import Foundation
import NumiBrainCore

/// Physical-owner evidence for one accepted NumiLab candidate. NumiBrain does
/// not manufacture `physicalStateFingerprint`: the owner must compute it from
/// its complete accepted state (including all state necessary for continuation)
/// after the native solver accepts the candidate.
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

  public init(
    submission: NumiLabPositionMotorSubmission,
    transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken,
    liveRollout: NumiLabLiveRolloutIdentity,
    physicalStateFingerprint: UInt64,
    physicsGeneration: UInt64
  ) throws {
    try submission.validate(
      transaction: transaction,
      substep: substep,
      liveRollout: liveRollout
    )
    let (expectedGeneration, overflow) =
      transaction.basePhysicsGeneration.addingReportingOverflow(1)
    guard !overflow,
      physicalStateFingerprint != 0,
      physicsGeneration == expectedGeneration,
      submission.environmentIdentifier == transaction.environmentIdentifier
    else {
      throw TissueError.transaction(
        "NumiLab accepted-physics owner proof has invalid state identity or generation"
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
  }

  public func acceptedPhysicsStateToken(
    transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken,
    liveRollout: NumiLabLiveRolloutIdentity
  ) throws -> AcceptedPhysicsStateToken {
    let (expectedGeneration, overflow) =
      transaction.basePhysicsGeneration.addingReportingOverflow(1)
    guard !overflow,
      transactionFingerprint == transaction.fingerprint,
      substepFingerprint == substep.fingerprint,
      environmentIdentifier == transaction.environmentIdentifier,
      physicsGeneration == expectedGeneration,
      physicalStateFingerprint != 0,
      compiledRunFingerprint == liveRollout.runFingerprint,
      worldFingerprint == liveRollout.worldFingerprint,
      taskFingerprint == liveRollout.taskFingerprint,
      actionFingerprint == liveRollout.actionFingerprint,
      robotFingerprint == liveRollout.robotFingerprint else {
      throw TissueError.transaction(
        "NumiLab accepted-physics receipt no longer belongs to this live root"
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

import Foundation
import NumiBrainCore

/// One deterministic physical step retained by an exact replay checkpoint.
/// Actions are already in normalized physical-owner coordinates and the
/// fingerprint is the native owner's complete accepted continuation-state
/// digest captured by the physical executor at this exact boundary.
@available(macOS 26.0, *)
@frozen
public struct NumiLabReplayCheckpointStep: Equatable, Sendable {
  public let normalizedActions: [Float]
  public let policyRevision: UInt64
  public let postSubmissionCount: UInt64
  public let postSubmittedControlSteps: UInt64
  public let postCompletedEnvironmentSteps: UInt64
  public let physicalStateFingerprint: UInt64

  public init(
    executed: NumiLabExecutedPositionCandidate,
    policyRevision: UInt64
  ) throws {
    let after = executed.advanceReceipt.after
    let fingerprint = executed.acceptedPhysicsReceipt.physicalStateFingerprint
    guard executed.advanceReceipt.fullyAccepted,
      executed.actionFrame.controlStepCount == 1,
      executed.actionFrame.environmentCount == 1,
      executed.actionFrame.normalizedActions.allSatisfy(\.isFinite),
      fingerprint != 0 else {
      throw TissueError.transaction("NumiLab replay step is not one exact accepted physical step")
    }
    normalizedActions = executed.actionFrame.normalizedActions
    self.policyRevision = policyRevision
    postSubmissionCount = after.submissionCount
    postSubmittedControlSteps = after.submittedControlSteps
    postCompletedEnvironmentSteps = after.completedEnvironmentSteps
    physicalStateFingerprint = fingerprint
  }
}

/// Deterministic owner-verified checkpoint for the current NumiLab rollout
/// ABI. Exact restore is replay from a fresh rollout with the same immutable
/// CompiledRun identity, followed by native resident-state digest equality at
/// every accepted boundary. Partial q/v reconstruction is never accepted.
@available(macOS 26.0, *)
@frozen
public struct NumiLabReplayCheckpoint: Equatable, Sendable {
  public let identity: NumiLabLiveRolloutIdentity
  public let origin: NumiLabLiveRolloutSnapshot
  public let steps: [NumiLabReplayCheckpointStep]

  public init(origin: NumiLabLiveRolloutSnapshot) throws {
    guard origin.identity.environmentCount == 1,
      origin.submissionCount == 0,
      origin.submittedControlSteps == 0,
      origin.completedEnvironmentSteps == 0 else {
      throw TissueError.transaction(
        "NumiLab replay checkpoint must start at a fresh single-environment rollout"
      )
    }
    identity = origin.identity
    self.origin = origin
    steps = []
  }

  private init(
    identity: NumiLabLiveRolloutIdentity,
    origin: NumiLabLiveRolloutSnapshot,
    steps: [NumiLabReplayCheckpointStep]
  ) {
    self.identity = identity
    self.origin = origin
    self.steps = steps
  }

  public func appending(
    _ executed: NumiLabExecutedPositionCandidate,
    policyRevision: UInt64
  ) throws -> NumiLabReplayCheckpoint {
    guard executed.advanceReceipt.before.identity == identity,
      executed.advanceReceipt.after.identity == identity,
      executed.advanceReceipt.fullyAccepted else {
      throw TissueError.transaction("NumiLab replay candidate belongs to another rollout")
    }
    let expectedBefore = steps.last.map { previous in
      (previous.postSubmissionCount, previous.postSubmittedControlSteps,
       previous.postCompletedEnvironmentSteps)
    } ?? (origin.submissionCount, origin.submittedControlSteps, origin.completedEnvironmentSteps)
    let before = executed.advanceReceipt.before
    guard before.submissionCount == expectedBefore.0,
      before.submittedControlSteps == expectedBefore.1,
      before.completedEnvironmentSteps == expectedBefore.2 else {
      throw TissueError.transaction("NumiLab replay journal is not contiguous")
    }
    let step = try NumiLabReplayCheckpointStep(
      executed: executed,
      policyRevision: policyRevision
    )
    return NumiLabReplayCheckpoint(identity: identity, origin: origin, steps: steps + [step])
  }

  public var finalPhysicalStateFingerprint: UInt64? {
    steps.last?.physicalStateFingerprint
  }

  /// Replays into a caller-created fresh rollout. The caller owns creation
  /// because the rollout handle intentionally does not expose or serialize its
  /// manifest. Owner digest equality proves exact continuation after each step.
  @discardableResult
  public func restore(
    into rollout: NumiLabBorrowedTaskRollout
  ) throws -> NumiLabLiveRolloutSnapshot {
    let fresh = try rollout.snapshot()
    guard fresh == origin else {
      throw TissueError.transaction(
        "NumiLab replay restore requires the exact fresh rollout origin"
      )
    }
    var current = fresh
    for step in steps {
      let frame = try NumiLabPositionHostActionFrame(
        replayNormalizedActions: step.normalizedActions,
        liveRollout: identity
      )
      let advance = try rollout.advance(frame: frame, policyRevision: step.policyRevision)
      guard advance.before == current,
        advance.fullyAccepted,
        advance.after.submissionCount == step.postSubmissionCount,
        advance.after.submittedControlSteps == step.postSubmittedControlSteps,
        advance.after.completedEnvironmentSteps == step.postCompletedEnvironmentSteps else {
        throw TissueError.transaction("NumiLab replay restore diverged in rollout counters")
      }
      let fingerprint = try rollout.residentStateFingerprint()
      let afterProof = try rollout.snapshot()
      guard afterProof == advance.after,
        fingerprint == step.physicalStateFingerprint else {
        throw TissueError.transaction(
          "NumiLab replay restore diverged from the recorded complete physical state"
        )
      }
      current = afterProof
    }
    return current
  }
}

@available(macOS 26.0, *)
extension NumiLabPositionHostActionFrame {
  fileprivate init(
    replayNormalizedActions actions: [Float],
    liveRollout: NumiLabLiveRolloutIdentity
  ) throws {
    guard liveRollout.environmentCount == 1,
      actions.count == Int(liveRollout.actionCount),
      !actions.isEmpty,
      actions.allSatisfy(\.isFinite) else {
      throw TissueError.transaction("NumiLab replay action frame is malformed")
    }
    controlStepCount = 1
    environmentCount = 1
    actionCount = UInt32(actions.count)
    normalizedActions = actions
    self.liveRollout = liveRollout
  }
}

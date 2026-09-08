import Foundation
import NumiBrainCore

/// One deterministic physical step retained by an exact replay checkpoint.
/// The action bytes are already normalized physical-owner coordinates; the
/// post-step fingerprint must be computed by the owner from its complete
/// accepted continuation state, not from inspection-only q/readback fields.
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
    policyRevision: UInt64,
    physicalStateFingerprint: UInt64
  ) throws {
    let after = executed.advanceReceipt.after
    guard executed.advanceReceipt.fullyAccepted,
      executed.actionFrame.controlStepCount == 1,
      executed.actionFrame.environmentCount == 1,
      executed.actionFrame.normalizedActions.allSatisfy(\.isFinite),
      physicalStateFingerprint != 0,
      physicalStateFingerprint == executed.acceptedPhysicsReceipt.physicalStateFingerprint
    else {
      throw TissueError.transaction("NumiLab replay step is not one exact accepted physical step")
    }
    normalizedActions = executed.actionFrame.normalizedActions
    self.policyRevision = policyRevision
    postSubmissionCount = after.submissionCount
    postSubmittedControlSteps = after.submittedControlSteps
    postCompletedEnvironmentSteps = after.completedEnvironmentSteps
    self.physicalStateFingerprint = physicalStateFingerprint
  }
}

/// A deterministic, owner-verifiable checkpoint for the current public
/// NumiLab rollout ABI. NumiLab does not yet expose its private resident arena
/// as a serializable snapshot; therefore exact restore is performed by replay
/// from a fresh rollout with the same immutable CompiledRun identity.
///
/// This is stronger than reconstructing q/v: replay re-executes reset/RNG,
/// task state, actuator history, contact/manifold evolution, warm starts and
/// every other private resident transition. The restore is accepted only when
/// the physical owner recomputes the recorded complete-state fingerprint.
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
      origin.completedEnvironmentSteps == 0
    else {
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
      policyRevision: policyRevision,
      physicalStateFingerprint: executed.acceptedPhysicsReceipt.physicalStateFingerprint
    )
    return NumiLabReplayCheckpoint(identity: identity, origin: origin, steps: steps + [step])
  }

  public var finalPhysicalStateFingerprint: UInt64? {
    steps.last?.physicalStateFingerprint
  }

  /// Replays this checkpoint into a caller-created fresh rollout. The caller
  /// owns creation because the public C ABI does not expose the original
  /// manifest through a rollout handle. `physicalStateFingerprint` must hash
  /// the complete accepted native continuation state after each step.
  @discardableResult
  public func restore(
    into rollout: NumiLabBorrowedTaskRollout,
    physicalStateFingerprint: (NumiLabLiveRolloutSnapshot) throws -> UInt64
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
      let fingerprint = try physicalStateFingerprint(advance.after)
      guard fingerprint != 0, fingerprint == step.physicalStateFingerprint else {
        throw TissueError.transaction(
          "NumiLab replay restore diverged from the recorded complete physical state"
        )
      }
      current = advance.after
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

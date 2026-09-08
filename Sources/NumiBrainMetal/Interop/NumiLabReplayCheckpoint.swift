import Foundation
import NumiBrainCore

/// One accepted native physical step, not a Brain root-commit or learning receipt.
/// Policy revision is taken from execution, never supplied as replacement data.
@available(macOS 26.0, *)
@frozen
public struct NumiLabReplayCheckpointStep: Equatable, Sendable {
  public let normalizedActions: [Float]
  public let policyRevision: UInt64
  public let postSubmissionCount: UInt64
  public let postSubmittedControlSteps: UInt64
  public let postCompletedEnvironmentSteps: UInt64
  public let physicalStateFingerprint: UInt64

  public init(executed: NumiLabExecutedPositionCandidate,
    policyRevision expectedPolicyRevision: UInt64? = nil) throws {
    let after = executed.advanceReceipt.after
    let fingerprint = executed.acceptedPhysicsReceipt.physicalStateFingerprint
    let revision = try executed.advanceReceipt.policyRevisionForReplay(expected: expectedPolicyRevision)
    guard executed.advanceReceipt.fullyAccepted,
      executed.actionFrame.liveRollout == after.identity,
      executed.actionFrame.actionCount == after.identity.actionCount,
      executed.actionFrame.normalizedActions.count == Int(after.identity.actionCount),
      executed.actionFrame.controlStepCount == 1, executed.actionFrame.environmentCount == 1,
      executed.actionFrame.normalizedActions.allSatisfy(\.isFinite), fingerprint != 0 else {
      throw TissueError.transaction("NumiLab replay step is not one exact accepted physical step")
    }
    normalizedActions = executed.actionFrame.normalizedActions
    policyRevision = revision
    postSubmissionCount = after.submissionCount
    postSubmittedControlSteps = after.submittedControlSteps
    postCompletedEnvironmentSteps = after.completedEnvironmentSteps
    physicalStateFingerprint = fingerprint
  }
}

/// Deterministic physical checkpoint by exact replay, not an O(1) resident snapshot.
/// Each restored boundary must match the native continuation-state digest.
/// This does not serialize the external RunManifest or prove Brain root acceptance.
@available(macOS 26.0, *)
@frozen
public struct NumiLabReplayCheckpoint: Equatable, Sendable {
  public let identity: NumiLabLiveRolloutIdentity
  public let origin: NumiLabLiveRolloutSnapshot
  public let steps: [NumiLabReplayCheckpointStep]

  public init(origin: NumiLabLiveRolloutSnapshot) throws {
    guard origin.identity.environmentCount == 1, origin.submissionCount == 0,
      origin.submittedControlSteps == 0, origin.completedEnvironmentSteps == 0 else {
      throw TissueError.transaction("NumiLab replay checkpoint must start at a fresh single-environment rollout")
    }
    identity = origin.identity
    self.origin = origin
    steps = []
  }

  private init(identity: NumiLabLiveRolloutIdentity, origin: NumiLabLiveRolloutSnapshot,
    steps: [NumiLabReplayCheckpointStep]) {
    self.identity = identity
    self.origin = origin
    self.steps = steps
  }

  /// A supplied revision is an assertion only. Omit it to retain the executed value.
  public func appending(_ executed: NumiLabExecutedPositionCandidate,
    policyRevision expectedPolicyRevision: UInt64? = nil) throws -> NumiLabReplayCheckpoint {
    guard executed.advanceReceipt.before.identity == identity,
      executed.advanceReceipt.after.identity == identity, executed.advanceReceipt.fullyAccepted else {
      throw TissueError.transaction("NumiLab replay candidate belongs to another rollout")
    }
    let expected = steps.last.map {
      ($0.postSubmissionCount, $0.postSubmittedControlSteps, $0.postCompletedEnvironmentSteps)
    } ?? (origin.submissionCount, origin.submittedControlSteps, origin.completedEnvironmentSteps)
    let before = executed.advanceReceipt.before
    guard before.submissionCount == expected.0, before.submittedControlSteps == expected.1,
      before.completedEnvironmentSteps == expected.2 else {
      throw TissueError.transaction("NumiLab replay journal is not contiguous")
    }
    let step = try NumiLabReplayCheckpointStep(executed: executed, policyRevision: expectedPolicyRevision)
    return NumiLabReplayCheckpoint(identity: identity, origin: origin, steps: steps + [step])
  }

  public var finalPhysicalStateFingerprint: UInt64? { steps.last?.physicalStateFingerprint }

  /// The caller supplies a fresh rollout with the same retained manifest/seed.
  /// A failed replay quarantines that partially advanced world; it must be
  /// disposed rather than published, reused, or represented as rolled back.
  @discardableResult
  public func restore(into rollout: NumiLabBorrowedTaskRollout) throws -> NumiLabLiveRolloutSnapshot {
    return try rollout.withExclusiveAccess {
      let fresh = try rollout.snapshot()
      guard fresh == origin else {
        throw TissueError.transaction("NumiLab replay restore requires the exact fresh rollout origin")
      }
      var current = fresh
      do {
        for step in steps {
          let frame = try NumiLabPositionHostActionFrame(replayNormalizedActions: step.normalizedActions,
            liveRollout: identity)
          let advance = try rollout.advance(frame: frame, policyRevision: step.policyRevision)
          guard advance.before == current, advance.fullyAccepted,
            advance.policyRevision == step.policyRevision,
            advance.after.submissionCount == step.postSubmissionCount,
            advance.after.submittedControlSteps == step.postSubmittedControlSteps,
            advance.after.completedEnvironmentSteps == step.postCompletedEnvironmentSteps else {
            throw TissueError.transaction("NumiLab replay restore diverged in rollout counters")
          }
          let fingerprint = try rollout.residentStateFingerprint()
          let afterProof = try rollout.snapshot()
          guard afterProof == advance.after, fingerprint == step.physicalStateFingerprint else {
            throw TissueError.transaction("NumiLab replay restore diverged from the recorded complete physical state")
          }
          current = afterProof
        }
        return current
      } catch {
        rollout.quarantine(after: error)
        throw error
      }
    }
  }
}

@available(macOS 26.0, *)
extension NumiLabPositionHostActionFrame {
  fileprivate init(replayNormalizedActions actions: [Float], liveRollout: NumiLabLiveRolloutIdentity) throws {
    guard liveRollout.environmentCount == 1, actions.count == Int(liveRollout.actionCount),
      !actions.isEmpty, actions.allSatisfy(\.isFinite) else {
      throw TissueError.transaction("NumiLab replay action frame is malformed")
    }
    controlStepCount = 1
    environmentCount = 1
    actionCount = UInt32(actions.count)
    normalizedActions = actions
    self.liveRollout = liveRollout
  }
}

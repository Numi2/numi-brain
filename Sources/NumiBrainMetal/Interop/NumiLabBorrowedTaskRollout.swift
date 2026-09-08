import Foundation
import NumiBrainCore
import NumiBrainNumiLabBridgeABI

@available(macOS 26.0, *)
@frozen
public struct NumiLabLiveRolloutSnapshot: Equatable, Sendable {
  public let identity: NumiLabLiveRolloutIdentity
  public let submittedControlSteps: UInt64
  public let completedEnvironmentSteps: UInt64
  public let submissionCount: UInt64
}

@available(macOS 26.0, *)
@frozen
public struct NumiLabRolloutAdvanceReceipt: Equatable, Sendable {
  public let before: NumiLabLiveRolloutSnapshot
  public let after: NumiLabLiveRolloutSnapshot
  public let controlStepCount: UInt32
  public let successfulEnvironmentSteps: UInt32
  public let failedEnvironmentSteps: UInt32
  public let firstFailingEnvironment: UInt32
  public let firstFailingControlStep: UInt32
  public let firstGPUStatusCode: UInt32
  public let hostRequestedResets: UInt32
  public let maximumActiveContacts: UInt32
  public let maximumManifolds: UInt32
  public let gpuMilliseconds: Double
  public let submissionMilliseconds: Double

  public var fullyAccepted: Bool {
    controlStepCount == 1 && successfulEnvironmentSteps == 1
      && failedEnvironmentSteps == 0
      && after.submissionCount == before.submissionCount + 1
      && after.submittedControlSteps == before.submittedControlSteps + 1
      && after.completedEnvironmentSteps == before.completedEnvironmentSteps + 1
  }
}

/// Borrowed execution owner for an already-created NumiLab MRTaskRolloutHandle.
/// The handle remains owned by NumiLab/the embedding application. This object
/// dlopens only the pinned public C ABI and never creates, resets, destroys, or
/// substitutes simulator state.
@available(macOS 26.0, *)
public final class NumiLabBorrowedTaskRollout: @unchecked Sendable {
  private let bridge: OpaquePointer

  public init(libraryPath: String, borrowedRolloutHandle: UnsafeMutableRawPointer) throws {
    var error = [CChar](repeating: 0, count: 1024)
    let opened = libraryPath.withCString { path in
      error.withUnsafeMutableBufferPointer { buffer in
        nb_numilab_borrowed_rollout_open(
          path,
          borrowedRolloutHandle,
          buffer.baseAddress,
          buffer.count
        )
      }
    }
    guard let opened else {
      let detail = error.withUnsafeBufferPointer {
        $0.baseAddress.map(String.init(cString:)) ?? "NumiLab bridge open failed"
      }
      throw TissueError.transaction(detail)
    }
    bridge = opened
  }

  deinit {
    nb_numilab_borrowed_rollout_destroy(bridge)
  }

  public func snapshot() throws -> NumiLabLiveRolloutSnapshot {
    var raw = NBNumiLabRolloutIdentityV1()
    guard nb_numilab_borrowed_rollout_identity(bridge, &raw) == 0 else {
      throw TissueError.transaction(lastError())
    }
    let identity = try NumiLabLiveRolloutIdentity(
      environmentCount: raw.environment_count,
      actionCount: raw.action_count,
      runFingerprint: raw.run_fingerprint,
      worldFingerprint: raw.world_fingerprint,
      taskFingerprint: raw.task_fingerprint,
      actionFingerprint: raw.action_fingerprint,
      robotFingerprint: raw.robot_fingerprint
    )
    return NumiLabLiveRolloutSnapshot(
      identity: identity,
      submittedControlSteps: raw.submitted_control_steps,
      completedEnvironmentSteps: raw.completed_environment_steps,
      submissionCount: raw.submission_count
    )
  }

  public func advance(
    frame: NumiLabPositionHostActionFrame,
    policyRevision: UInt64 = 0
  ) throws -> NumiLabRolloutAdvanceReceipt {
    let before = try snapshot()
    guard before.identity == frame.liveRollout,
      frame.controlStepCount == 1,
      frame.environmentCount == 1,
      frame.actionCount == before.identity.actionCount,
      frame.normalizedActions.count == Int(frame.actionCount),
      frame.normalizedActions.allSatisfy(\.isFinite) else {
      throw TissueError.transaction(
        "NumiLab action frame no longer matches the borrowed live rollout"
      )
    }
    var raw = NBNumiLabAdvanceResultV1()
    let status = frame.normalizedActions.withUnsafeBufferPointer { actions in
      nb_numilab_borrowed_rollout_advance(
        bridge,
        actions.baseAddress,
        actions.count,
        policyRevision,
        &raw
      )
    }
    guard status == 0 else {
      throw TissueError.transaction(lastError())
    }
    let after = try snapshot()
    guard after.identity == before.identity,
      after.submissionCount == before.submissionCount + 1,
      after.submittedControlSteps == before.submittedControlSteps + 1 else {
      throw TissueError.transaction(
        "NumiLab live rollout counters or immutable identity drifted across advance"
      )
    }
    let receipt = NumiLabRolloutAdvanceReceipt(
      before: before,
      after: after,
      controlStepCount: raw.control_step_count,
      successfulEnvironmentSteps: raw.successful_environment_steps,
      failedEnvironmentSteps: raw.failed_environment_steps,
      firstFailingEnvironment: raw.first_failing_environment,
      firstFailingControlStep: raw.first_failing_control_step,
      firstGPUStatusCode: raw.first_gpu_status_code,
      hostRequestedResets: raw.host_requested_resets,
      maximumActiveContacts: raw.maximum_active_contacts,
      maximumManifolds: raw.maximum_manifolds,
      gpuMilliseconds: raw.gpu_milliseconds,
      submissionMilliseconds: raw.submission_milliseconds
    )
    guard receipt.fullyAccepted else {
      throw TissueError.transaction(
        "NumiLab physical advance did not accept exactly one environment step"
      )
    }
    return receipt
  }

  private func lastError() -> String {
    guard let pointer = nb_numilab_borrowed_rollout_last_error(bridge) else {
      return "unknown NumiLab borrowed rollout failure"
    }
    let value = String(cString: pointer)
    return value.isEmpty ? "unknown NumiLab borrowed rollout failure" : value
  }
}

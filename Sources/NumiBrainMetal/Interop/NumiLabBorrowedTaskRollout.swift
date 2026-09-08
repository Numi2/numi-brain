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
/// dlopens only the checksum-bound pinned public C ABI and never creates,
/// resets, destroys, or substitutes simulator state.
@available(macOS 26.0, *)
public final class NumiLabBorrowedTaskRollout: @unchecked Sendable {
  public static let requiredNativeRevision = "5db0c5aa169bfe1270ef7448e01dd7fbcd99d123"

  private let bridge: OpaquePointer
  public let nativeRevision: String
  public let librarySHA256: String

  public init(
    libraryPath: String,
    expectedLibrarySHA256: String,
    expectedNativeRevision: String,
    borrowedRolloutHandle: UnsafeMutableRawPointer,
    maximumLibraryBytes: Int = 1_073_741_824
  ) throws {
    guard expectedNativeRevision == Self.requiredNativeRevision,
      BrainPolicyEvidenceArtifact.isSHA256(expectedLibrarySHA256),
      maximumLibraryBytes > 0 else {
      throw TissueError.transaction("NumiLab borrowed rollout ABI evidence is invalid")
    }
    let url = URL(fileURLWithPath: libraryPath)
    let attributes = try FileManager.default.attributesOfItem(atPath: libraryPath)
    guard let size = attributes[.size] as? NSNumber,
      size.int64Value > 0,
      size.int64Value <= Int64(maximumLibraryBytes) else {
      throw TissueError.transaction("NumiLab dylib exceeds the admitted binary budget")
    }
    let data = try Data(contentsOf: url, options: [.mappedIfSafe])
    guard data.count == size.intValue,
      BrainPolicyEvidenceArtifact.sha256(data) == expectedLibrarySHA256 else {
      throw TissueError.transaction("NumiLab dylib content identity does not match deployment evidence")
    }

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
    nativeRevision = expectedNativeRevision
    librarySHA256 = expectedLibrarySHA256
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

  /// Copies the exact action table retained by this live CompiledTaskProgram.
  /// No cold exporter or actuator-order inference participates in execution.
  public func compiledActionBindings() throws -> [NumiLabCompiledTaskActionBinding] {
    let count = nb_numilab_borrowed_rollout_action_binding_count(bridge)
    guard count > 0, count <= 4096 else {
      throw TissueError.transaction("NumiLab live compiled action binding count is invalid")
    }
    var raw = [NBNumiLabActionBindingV1](repeating: NBNumiLabActionBindingV1(), count: count)
    let status = raw.withUnsafeMutableBufferPointer { buffer in
      nb_numilab_borrowed_rollout_copy_action_bindings(
        bridge, buffer.baseAddress, buffer.count)
    }
    guard status == 0 else {
      throw TissueError.transaction(lastError())
    }
    return try raw.enumerated().map { index, binding in
      guard binding.action_index == UInt32(index),
        let kind = NumiLabRobotInterface.ActuatorKind(rawValue: binding.actuator_kind),
        binding.normalized_scale.isFinite, binding.normalized_scale > 0,
        binding.lower_target.isFinite, binding.upper_target.isFinite,
        binding.lower_target <= binding.upper_target,
        binding.response_time_seconds.isFinite, binding.response_time_seconds >= 0,
        binding.drive_stiffness.isFinite, binding.drive_stiffness >= 0,
        binding.drive_damping.isFinite, binding.drive_damping >= 0 else {
        throw TissueError.transaction("NumiLab live compiled action binding is malformed")
      }
      return NumiLabCompiledTaskActionBinding(
        actionIndex: binding.action_index,
        qIndex: binding.q_index == UInt32.max ? nil : binding.q_index,
        vIndex: binding.v_index == UInt32.max ? nil : binding.v_index,
        actuatorKind: kind,
        resolvedComponent: binding.resolved_component,
        componentLane: binding.component_lane,
        normalizedScale: binding.normalized_scale,
        lowerTarget: binding.lower_target,
        upperTarget: binding.upper_target,
        responseTimeSeconds: binding.response_time_seconds,
        driveStiffness: binding.drive_stiffness,
        driveDamping: binding.drive_damping,
        interactionMotion: binding.interaction_motion != 0
      )
    }
  }

  public func compiledActionReceipt(
    robot: NumiLabRobotInterface,
    contract: NumiLabTaskActionContract
  ) throws -> NumiLabCompiledTaskActionReceipt {
    let live = try snapshot()
    let bindings = try compiledActionBindings()
    guard UInt32(bindings.count) == live.identity.actionCount else {
      throw TissueError.transaction("NumiLab live action table width drifted from rollout identity")
    }
    let receipt = try NumiLabCompiledTaskActionReceipt(
      runFingerprint: live.identity.runFingerprint,
      worldFingerprint: live.identity.worldFingerprint,
      taskFingerprint: live.identity.taskFingerprint,
      actionFingerprint: live.identity.actionFingerprint,
      robotFingerprint: live.identity.robotFingerprint,
      bindings: bindings
    )
    try receipt.validate(against: contract)
    _ = try NumiLabPositionActionEncoder(robot: robot, contract: contract, compiledTask: receipt)
    return receipt
  }

  /// Canonical physical-owner digest of every persistent resident continuation
  /// buffer plus resident metadata. It is valid only after an accepted step.
  public func residentStateFingerprint() throws -> UInt64 {
    let fingerprint = nb_numilab_borrowed_rollout_resident_state_fingerprint(bridge)
    guard fingerprint != 0 else {
      throw TissueError.transaction(
        "NumiLab physical owner has no accepted idle resident-state fingerprint"
      )
    }
    return fingerprint
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

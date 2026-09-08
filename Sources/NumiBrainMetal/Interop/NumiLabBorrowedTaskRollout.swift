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
  /// Exact revision passed to native execution, including zero.
  public let policyRevision: UInt64

  public var fullyAccepted: Bool {
    let submissions = before.submissionCount.addingReportingOverflow(1)
    let controls = before.submittedControlSteps.addingReportingOverflow(1)
    let completed = before.completedEnvironmentSteps.addingReportingOverflow(1)
    return !submissions.overflow && !controls.overflow && !completed.overflow
      && before.identity == after.identity && before.identity.environmentCount == 1
      && controlStepCount == 1 && successfulEnvironmentSteps == 1
      && failedEnvironmentSteps == 0 && hostRequestedResets == 0 && firstGPUStatusCode == 0
      && gpuMilliseconds.isFinite && gpuMilliseconds >= 0
      && submissionMilliseconds.isFinite && submissionMilliseconds >= 0
      && after.submissionCount == submissions.partialValue
      && after.submittedControlSteps == controls.partialValue
      && after.completedEnvironmentSteps == completed.partialValue
  }

  func policyRevisionForReplay(expected: UInt64?) throws -> UInt64 {
    guard fullyAccepted, expected == nil || expected == policyRevision else {
      throw TissueError.transaction("replay policy revision differs from the accepted native execution")
    }
    return policyRevision
  }
}

/// Borrowed execution owner for an already-created NumiLab MRTaskRolloutHandle.
/// The embedding application owns its lifetime and must prohibit external access
/// to the same handle. This wrapper serializes complete owner operations, not GPU
/// work, and never creates, resets, destroys or substitutes the physical world.
@available(macOS 26.0, *)
public final class NumiLabBorrowedTaskRollout: @unchecked Sendable {
  // Native owner hashes validated logical continuation bytes, not allocation slack.
  public static let requiredNativeRevision = "4a369ca846fde93016f3708f3fd9386c992b52a4"
  private let bridge: OpaquePointer
  private let access = NumiLabRolloutAccessGate()
  public let nativeRevision: String
  public let librarySHA256: String

  public init(libraryPath: String, expectedLibrarySHA256: String,
    expectedNativeRevision: String, borrowedRolloutHandle: UnsafeMutableRawPointer,
    maximumLibraryBytes: Int = 1_073_741_824) throws {
    guard expectedNativeRevision == Self.requiredNativeRevision,
      BrainPolicyEvidenceArtifact.isSHA256(expectedLibrarySHA256), maximumLibraryBytes > 0,
      !libraryPath.isEmpty, !libraryPath.utf8.contains(0) else {
      throw TissueError.transaction("NumiLab borrowed rollout ABI evidence is invalid")
    }
    let url = URL(fileURLWithPath: libraryPath)
    let attributes = try FileManager.default.attributesOfItem(atPath: libraryPath)
    guard let size = attributes[.size] as? NSNumber, size.int64Value > 0,
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
        nb_numilab_borrowed_rollout_open(path, borrowedRolloutHandle, buffer.baseAddress, buffer.count)
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

  // Synchronous nesting is intentional. Never suspend/await under this lock.
  func withExclusiveAccess<T>(_ operation: () throws -> T) throws -> T {
    try access.perform(operation)
  }
  func quarantine(after error: Error) {
    access.quarantine(String(describing: error))
  }
  deinit { nb_numilab_borrowed_rollout_destroy(bridge) }

  public func snapshot() throws -> NumiLabLiveRolloutSnapshot {
    return try withExclusiveAccess {
      var raw = NBNumiLabRolloutIdentityV1()
      guard nb_numilab_borrowed_rollout_identity(bridge, &raw) == 0 else {
        throw TissueError.transaction(lastError())
      }
      let identity = try NumiLabLiveRolloutIdentity(environmentCount: raw.environment_count,
        actionCount: raw.action_count, runFingerprint: raw.run_fingerprint,
        worldFingerprint: raw.world_fingerprint, taskFingerprint: raw.task_fingerprint,
        actionFingerprint: raw.action_fingerprint, robotFingerprint: raw.robot_fingerprint)
      return NumiLabLiveRolloutSnapshot(identity: identity,
        submittedControlSteps: raw.submitted_control_steps,
        completedEnvironmentSteps: raw.completed_environment_steps, submissionCount: raw.submission_count)
    }
  }

  /// Copies the exact live CompiledTaskProgram table, not inferred actuator order.
  public func compiledActionBindings() throws -> [NumiLabCompiledTaskActionBinding] {
    return try withExclusiveAccess {
      let count = nb_numilab_borrowed_rollout_action_binding_count(bridge)
      guard count > 0, count <= 4096 else {
        throw TissueError.transaction("NumiLab live compiled action binding count is invalid")
      }
      var raw = [NBNumiLabActionBindingV1](repeating: NBNumiLabActionBindingV1(), count: count)
      let status = raw.withUnsafeMutableBufferPointer { buffer in
        nb_numilab_borrowed_rollout_copy_action_bindings(bridge, buffer.baseAddress, buffer.count)
      }
      guard status == 0 else { throw TissueError.transaction(lastError()) }
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
        return NumiLabCompiledTaskActionBinding(actionIndex: binding.action_index,
          qIndex: binding.q_index == UInt32.max ? nil : binding.q_index,
          vIndex: binding.v_index == UInt32.max ? nil : binding.v_index,
          actuatorKind: kind, resolvedComponent: binding.resolved_component,
          componentLane: binding.component_lane, normalizedScale: binding.normalized_scale,
          lowerTarget: binding.lower_target, upperTarget: binding.upper_target,
          responseTimeSeconds: binding.response_time_seconds, driveStiffness: binding.drive_stiffness,
          driveDamping: binding.drive_damping, interactionMotion: binding.interaction_motion != 0)
      }
    }
  }

  public func compiledActionReceipt(robot: NumiLabRobotInterface,
    contract: NumiLabTaskActionContract) throws -> NumiLabCompiledTaskActionReceipt {
    return try withExclusiveAccess {
      let live = try snapshot()
      let bindings = try compiledActionBindings()
      guard UInt32(bindings.count) == live.identity.actionCount else {
        throw TissueError.transaction("NumiLab live action table width drifted from rollout identity")
      }
      let receipt = try NumiLabCompiledTaskActionReceipt(runFingerprint: live.identity.runFingerprint,
        worldFingerprint: live.identity.worldFingerprint, taskFingerprint: live.identity.taskFingerprint,
        actionFingerprint: live.identity.actionFingerprint, robotFingerprint: live.identity.robotFingerprint,
        bindings: bindings)
      try receipt.validate(against: contract)
      _ = try NumiLabPositionActionEncoder(robot: robot, contract: contract, compiledTask: receipt)
      return receipt
    }
  }

  /// Valid only at an accepted idle boundary; excludes allocator capacity slack.
  public func residentStateFingerprint() throws -> UInt64 {
    return try withExclusiveAccess {
      let fingerprint = nb_numilab_borrowed_rollout_resident_state_fingerprint(bridge)
      guard fingerprint != 0 else {
        throw TissueError.transaction("NumiLab physical owner has no accepted idle resident-state fingerprint")
      }
      return fingerprint
    }
  }

  public func advance(frame: NumiLabPositionHostActionFrame,
    policyRevision: UInt64 = 0) throws -> NumiLabRolloutAdvanceReceipt {
    return try withExclusiveAccess {
      let before = try snapshot()
      guard before.identity == frame.liveRollout, frame.controlStepCount == 1,
        frame.environmentCount == 1, frame.actionCount == before.identity.actionCount,
        frame.normalizedActions.count == Int(frame.actionCount),
        frame.normalizedActions.allSatisfy(\.isFinite) else {
        throw TissueError.transaction("NumiLab action frame no longer matches the borrowed live rollout")
      }
      var raw = NBNumiLabAdvanceResultV1()
      let status = frame.normalizedActions.withUnsafeBufferPointer { actions in
        nb_numilab_borrowed_rollout_advance(bridge, actions.baseAddress, actions.count, policyRevision, &raw)
      }
      guard status == 0 else { throw TissueError.transaction(lastError()) }
      let after = try snapshot()
      let receipt = NumiLabRolloutAdvanceReceipt(before: before, after: after,
        controlStepCount: raw.control_step_count, successfulEnvironmentSteps: raw.successful_environment_steps,
        failedEnvironmentSteps: raw.failed_environment_steps, firstFailingEnvironment: raw.first_failing_environment,
        firstFailingControlStep: raw.first_failing_control_step, firstGPUStatusCode: raw.first_gpu_status_code,
        hostRequestedResets: raw.host_requested_resets, maximumActiveContacts: raw.maximum_active_contacts,
        maximumManifolds: raw.maximum_manifolds, gpuMilliseconds: raw.gpu_milliseconds,
        submissionMilliseconds: raw.submission_milliseconds, policyRevision: policyRevision)
      guard receipt.fullyAccepted else {
        let error = TissueError.transaction("NumiLab physical advance did not accept exactly one environment step")
        quarantine(after: error)
        throw error
      }
      return receipt
    }
  }

  private func lastError() -> String {
    guard let pointer = nb_numilab_borrowed_rollout_last_error(bridge) else {
      return "unknown NumiLab borrowed rollout failure"
    }
    let value = String(cString: pointer)
    return value.isEmpty ? "unknown NumiLab borrowed rollout failure" : value
  }
}

import Foundation
import NumiBrainCore

@available(macOS 26.0, *)
extension NumiLabCompiledTaskActionSnapshot {
  /// Execution-strength promotion using the actual borrowed NumiLab rollout.
  /// Core performs the primitive identity checks; this wrapper preserves the
  /// one-way Core -> Metal dependency while keeping callers strongly typed.
  public func executionReceipt(
    liveRollout: NumiLabLiveRolloutIdentity,
    robot: NumiLabRobotInterface,
    contract: NumiLabTaskActionContract
  ) throws -> NumiLabCompiledTaskActionReceipt {
    try executionReceipt(
      runFingerprint: liveRollout.runFingerprint,
      liveWorldFingerprint: liveRollout.worldFingerprint,
      liveTaskFingerprint: liveRollout.taskFingerprint,
      liveActionFingerprint: liveRollout.actionFingerprint,
      liveRobotFingerprint: liveRollout.robotFingerprint,
      liveActionCount: liveRollout.actionCount,
      robot: robot,
      contract: contract
    )
  }
}

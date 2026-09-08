import Foundation
@preconcurrency import Metal
import NumiBrainCore

/// Explicit compatibility transport for NumiLab's current host-action API.
/// NumiBrain remains GPU-authoritative: this adapter only reads the exact
/// lease-retained command allocation after transaction and live-rollout
/// admission, then converts absolute position commands to the normalized task
/// coordinates consumed by `mr_task_rollout_advance` / `advance(normalizedActions:)`.
///
/// This is intentionally not described as zero-copy. A future NumiLab device
/// action boundary can replace this adapter without changing task ownership or
/// joint-root semantics.
@available(macOS 26.0, *)
public enum NumiLabPositionHostActionAdapter {
  public static func normalizedActions(
    submission: NumiLabPositionMotorSubmission,
    lease: MetalTissueRuntime.NumanXMotorBufferLease,
    encoder: NumiLabPositionActionEncoder,
    transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken,
    liveRollout: NumiLabLiveRolloutIdentity
  ) throws -> [Float] {
    try submission.validate(
      transaction: transaction,
      substep: substep,
      liveRollout: liveRollout
    )
    guard encoder.isPhysicalOwnerBound,
      encoder.compiledRunFingerprint == submission.compiledRunFingerprint,
      encoder.contract.worldFingerprint == submission.worldFingerprint,
      encoder.contract.taskFingerprint == submission.taskFingerprint,
      encoder.contract.actionFingerprint == submission.actionFingerprint,
      encoder.contract.robotFingerprint == submission.robotFingerprint,
      UInt32(encoder.lanes.count) == submission.actionCount,
      lease.output.muscleExcitationGPUAddress == submission.sourceCommandGPUAddress,
      lease.output.muscleExcitationByteCount == Int(submission.sourceCommandByteCount),
      lease.output.muscleCount == Int(submission.actionCount)
    else {
      throw TissueError.transaction(
        "NumiLab host action transport does not own the admitted motor allocation"
      )
    }

    let object = Unmanaged<AnyObject>
      .fromOpaque(lease.excitationMetalBufferObject)
      .takeUnretainedValue()
    guard let buffer = object as? any MTLBuffer else {
      throw TissueError.metal("NumiLab motor lease does not contain an MTLBuffer")
    }
    let commands = try absolutePositionCommands(
      buffer: buffer,
      gpuAddress: submission.sourceCommandGPUAddress,
      byteCount: Int(submission.sourceCommandByteCount),
      scalarCount: Int(submission.actionCount)
    )
    return try encoder.encodeAbsolutePositions(commands)
  }

  /// Host readback is deliberately restricted to CPU-visible Metal storage.
  /// Private-memory output must use a future physical-owner device-action path;
  /// silently allocating an unsynchronized staging copy here would weaken the
  /// producer/consumer timeline contract.
  static func absolutePositionCommands(
    buffer: any MTLBuffer,
    gpuAddress: UInt64,
    byteCount: Int,
    scalarCount: Int
  ) throws -> [Float] {
    guard scalarCount > 0,
      byteCount == scalarCount * MemoryLayout<Float>.stride,
      buffer.gpuAddress > 0,
      gpuAddress >= buffer.gpuAddress else {
      throw TissueError.transaction("NumiLab motor command range is malformed")
    }
    let offset64 = gpuAddress - buffer.gpuAddress
    guard offset64 <= UInt64(Int.max) else {
      throw TissueError.transaction("NumiLab motor command offset exceeds host addressability")
    }
    let offset = Int(offset64)
    let (end, overflow) = offset.addingReportingOverflow(byteCount)
    guard !overflow, offset >= 0, end <= buffer.length,
      offset.isMultiple(of: MemoryLayout<Float>.alignment),
      buffer.storageMode == .shared || buffer.storageMode == .managed else {
      throw TissueError.transaction(
        "NumiLab host action transport requires an exact CPU-visible command buffer range"
      )
    }
    let values = buffer.contents().advanced(by: offset)
      .assumingMemoryBound(to: Float.self)
    var result = [Float]()
    result.reserveCapacity(scalarCount)
    for index in 0..<scalarCount {
      let value = values[index]
      guard value.isFinite else {
        throw TissueError.transaction("NumiLab motor command contains a non-finite scalar")
      }
      result.append(value)
    }
    return result
  }
}

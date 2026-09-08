import Foundation
@preconcurrency import Metal
import NumiBrainCore

/// One [control step][environment][action] frame, never a batched rollout.
@available(macOS 26.0, *)
@frozen
public struct NumiLabPositionHostActionFrame: Equatable, Sendable {
  public let controlStepCount: UInt32
  public let environmentCount: UInt32
  public let actionCount: UInt32
  public let normalizedActions: [Float]
  public let liveRollout: NumiLabLiveRolloutIdentity

  fileprivate init(normalizedActions: [Float], liveRollout: NumiLabLiveRolloutIdentity) {
    controlStepCount = 1
    environmentCount = 1
    actionCount = UInt32(normalizedActions.count)
    self.normalizedActions = normalizedActions
    self.liveRollout = liveRollout
  }
}

/// Explicit host-action compatibility transport, not a zero-copy production path.
/// Requires the actual completed motor submission ticket, not merely a retained
/// GPU address or event. The owner remains responsible for settling/reaping work.
@available(macOS 26.0, *)
public enum NumiLabPositionHostActionAdapter {
  public static func makeFrame(submission: NumiLabPositionMotorSubmission,
    ticket: MetalTissueRuntime.NumanXMotorSubmissionTicket,
    encoder: NumiLabPositionActionEncoder, transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken,
    liveRollout: NumiLabLiveRolloutIdentity) throws -> NumiLabPositionHostActionFrame {
    // Poll terminal owner feedback and the exact motor-ready gate. No private
    // queue, unsynchronized staging, or guessed producer completion is allowed.
    guard try ticket.completionFeedbackIfAvailable() != nil,
      ticket.motorEvaluation.hasValidSuccess(),
      ticket.candidate.fingerprint == submission.motorCandidateFingerprint,
      ticket.fastSystems.substep == substep else {
      throw TissueError.transaction("NumiLab host transport requires this candidate's completed successful motor ticket")
    }
    let lease = ticket.buffers
    try submission.validate(transaction: transaction, substep: substep, liveRollout: liveRollout)
    guard liveRollout.environmentCount == 1, submission.environmentIdentifier == 0,
      encoder.isPhysicalOwnerBound, encoder.compiledRunFingerprint == submission.compiledRunFingerprint,
      encoder.contract.worldFingerprint == submission.worldFingerprint,
      encoder.contract.taskFingerprint == submission.taskFingerprint,
      encoder.contract.actionFingerprint == submission.actionFingerprint,
      encoder.contract.robotFingerprint == submission.robotFingerprint,
      UInt32(encoder.lanes.count) == submission.actionCount,
      lease.output.muscleExcitationGPUAddress == submission.sourceCommandGPUAddress,
      lease.output.muscleExcitationByteCount == Int(submission.sourceCommandByteCount),
      lease.output.muscleCount == submission.actionCount else {
      throw TissueError.transaction("NumiLab host action transport does not own one exact single-environment motor allocation")
    }
    let object = Unmanaged<AnyObject>.fromOpaque(lease.excitationMetalBufferObject).takeUnretainedValue()
    guard let buffer = object as? any MTLBuffer else {
      throw TissueError.metal("NumiLab motor lease does not contain an MTLBuffer")
    }
    let commands = try absolutePositionCommands(buffer: buffer,
      gpuAddress: submission.sourceCommandGPUAddress, byteCount: Int(submission.sourceCommandByteCount),
      scalarCount: Int(submission.actionCount))
    let normalized = try encoder.encodeAbsolutePositions(commands)
    guard normalized.count == Int(liveRollout.actionCount) else {
      throw TissueError.transaction("NumiLab action frame width changed after admission")
    }
    return NumiLabPositionHostActionFrame(normalizedActions: normalized, liveRollout: liveRollout)
  }

  /// Testable range reader; production callers first validate terminal producer
  /// feedback above. Managed memory needs resource synchronization not supplied
  /// by this API; private memory is never staged behind the owning timeline.
  static func absolutePositionCommands(buffer: any MTLBuffer, gpuAddress: UInt64,
    byteCount: Int, scalarCount: Int) throws -> [Float] {
    let expectedBytes = scalarCount.multipliedReportingOverflow(by: MemoryLayout<Float>.stride)
    guard !expectedBytes.overflow, scalarCount > 0, scalarCount <= 4096,
      byteCount == expectedBytes.partialValue, buffer.gpuAddress > 0,
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
      offset.isMultiple(of: MemoryLayout<Float>.alignment) else {
      throw TissueError.transaction("NumiLab host action transport requires an exact command buffer range")
    }
    try validateHostReadableStorage(buffer.storageMode)
    let values = buffer.contents().advanced(by: offset).assumingMemoryBound(to: Float.self)
    var result = [Float]()
    result.reserveCapacity(scalarCount)
    for index in 0..<scalarCount {
      let value = values[index]
      guard value.isFinite else { throw TissueError.transaction("NumiLab motor command contains a non-finite scalar") }
      result.append(value)
    }
    return result
  }

  static func validateHostReadableStorage(_ mode: MTLStorageMode) throws {
    guard mode == .shared else {
      throw TissueError.transaction("NumiLab host transport requires shared storage and completed producer work")
    }
  }
}

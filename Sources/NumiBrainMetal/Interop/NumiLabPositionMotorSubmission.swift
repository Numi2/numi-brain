import Foundation
import NumiBrainCore

/// Transaction-local handoff from one NumiBrain position-command candidate to
/// one exact compiled NumiLab task action table. This descriptor does not copy
/// or reinterpret the GPU payload. The physical owner remains responsible for
/// encoding the declared affine conversion on its own Metal timeline and for
/// returning an accepted-physics token before Brain publication.
@available(macOS 26.0, *)
@frozen
public struct NumiLabPositionMotorSubmission: Sendable {
  @frozen
  public struct Lane: Equatable, Sendable {
    public let actionIndex: UInt32
    public let qIndex: UInt32
    public let vIndex: UInt32
    public let restPosition: Float
    public let normalizedScale: Float
    public let minimumTarget: Float
    public let maximumTarget: Float
  }

  public let transactionFingerprint: UInt64
  public let substepFingerprint: UInt64
  public let motorCandidateFingerprint: UInt64
  public let compiledRunFingerprint: UInt64
  public let worldFingerprint: UInt64
  public let taskFingerprint: UInt64
  public let actionFingerprint: UInt64
  public let robotFingerprint: UInt64
  public let sourceCommandGPUAddress: UInt64
  public let sourceCommandByteCount: UInt32
  public let actionCount: UInt32
  public let environmentIdentifier: UInt32
  public let lanes: [Lane]

  public init(candidate: NumanXMotorCandidate,
    encoder: NumiLabPositionActionEncoder) throws {
    guard encoder.isPhysicalOwnerBound, encoder.compiledRunFingerprint != 0,
      candidate.actuatorCommandKind == .position,
      candidate.actuatorCommandGPUAddress != 0,
      candidate.actuatorCount == UInt32(encoder.lanes.count),
      encoder.lanes.count <= Int(UInt32.max) else {
      throw TissueError.transaction(
        "NumiLab position submission is not bound to one exact position-command task"
      )
    }
    let expectedBytes = UInt64(encoder.lanes.count) * UInt64(MemoryLayout<Float>.stride)
    guard expectedBytes <= UInt64(UInt32.max),
      candidate.actuatorCommandByteCount == UInt32(expectedBytes) else {
      throw TissueError.transaction(
        "NumiBrain command bytes do not match the compiled NumiLab task action width"
      )
    }
    var mapped: [Lane] = []
    mapped.reserveCapacity(encoder.lanes.count)
    for (index, lane) in encoder.lanes.enumerated() {
      guard lane.nativeScale.isFinite, lane.nativeScale > 0,
        lane.minimumPosition.isFinite, lane.maximumPosition.isFinite,
        lane.minimumPosition <= lane.restPosition,
        lane.restPosition <= lane.maximumPosition else {
        throw TissueError.transaction("compiled NumiLab position lane is invalid")
      }
      mapped.append(Lane(actionIndex: UInt32(index), qIndex: lane.qIndex,
        vIndex: lane.vIndex, restPosition: lane.restPosition,
        normalizedScale: lane.nativeScale, minimumTarget: lane.minimumPosition,
        maximumTarget: lane.maximumPosition))
    }
    transactionFingerprint = candidate.transactionFingerprint
    substepFingerprint = candidate.substepFingerprint
    motorCandidateFingerprint = candidate.fingerprint
    compiledRunFingerprint = encoder.compiledRunFingerprint
    worldFingerprint = encoder.contract.worldFingerprint
    taskFingerprint = encoder.contract.taskFingerprint
    actionFingerprint = encoder.contract.actionFingerprint
    robotFingerprint = encoder.contract.robotFingerprint
    sourceCommandGPUAddress = candidate.actuatorCommandGPUAddress
    sourceCommandByteCount = candidate.actuatorCommandByteCount
    actionCount = candidate.actuatorCount
    environmentIdentifier = candidate.environmentIdentifier
    lanes = mapped
  }

  /// Rechecks root ownership immediately before the physical owner consumes
  /// the descriptor. The candidate already validated these records at creation;
  /// repeating the check prevents a cached descriptor from being transplanted
  /// into a later control transaction.
  public func validate(transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken) throws {
    guard transactionFingerprint == transaction.fingerprint,
      substepFingerprint == substep.fingerprint,
      environmentIdentifier == transaction.environmentIdentifier,
      actionCount == UInt32(lanes.count), sourceCommandGPUAddress != 0,
      sourceCommandByteCount == actionCount * UInt32(MemoryLayout<Float>.stride),
      compiledRunFingerprint != 0, worldFingerprint != 0, taskFingerprint != 0,
      actionFingerprint != 0, robotFingerprint != 0 else {
      throw TissueError.transaction(
        "NumiLab position submission no longer belongs to this root/substep"
      )
    }
  }
}

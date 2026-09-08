import Foundation

/// Cold, native-compiled action authority. Unlike an execution receipt this
/// type deliberately has no `runFingerprint`: execution-profile identity is
/// observed from the live physical owner immediately before use.
@frozen
public struct NumiLabCompiledTaskActionSnapshot: Codable, Equatable, Sendable {
  public static let currentVersion: UInt32 = 1

  public let version: UInt32
  public let nativeRepositoryRevision: String
  public let worldFingerprint: UInt64
  public let taskFingerprint: UInt64
  public let actionFingerprint: UInt64
  public let robotFingerprint: UInt64
  public let actuatorIdentifiers: [String]
  public let bindings: [NumiLabCompiledTaskActionBinding]

  public init(
    nativeRepositoryRevision: String,
    worldFingerprint: UInt64,
    taskFingerprint: UInt64,
    actionFingerprint: UInt64,
    robotFingerprint: UInt64,
    actuatorIdentifiers: [String],
    bindings: [NumiLabCompiledTaskActionBinding]
  ) throws {
    version = Self.currentVersion
    self.nativeRepositoryRevision = nativeRepositoryRevision
    self.worldFingerprint = worldFingerprint
    self.taskFingerprint = taskFingerprint
    self.actionFingerprint = actionFingerprint
    self.robotFingerprint = robotFingerprint
    self.actuatorIdentifiers = actuatorIdentifiers
    self.bindings = bindings
    try validate()
  }

  public func validate() throws {
    guard version == Self.currentVersion,
      nativeRepositoryRevision.count == 40,
      nativeRepositoryRevision.utf8.allSatisfy({
        (48...57).contains($0) || (97...102).contains($0)
      }),
      worldFingerprint != 0,
      taskFingerprint != 0,
      actionFingerprint != 0,
      robotFingerprint != 0,
      !bindings.isEmpty,
      bindings.count <= 4096,
      bindings.count == actuatorIdentifiers.count,
      Set(actuatorIdentifiers).count == actuatorIdentifiers.count,
      actuatorIdentifiers.allSatisfy({
        !$0.isEmpty && $0.utf8.count <= 1024 && !$0.utf8.contains(0)
      }),
      bindings.enumerated().allSatisfy({ index, binding in
        binding.actionIndex == UInt32(index) &&
          binding.normalizedScale.isFinite && binding.normalizedScale > 0 &&
          binding.lowerTarget.isFinite && binding.upperTarget.isFinite &&
          binding.lowerTarget <= binding.upperTarget &&
          binding.responseTimeSeconds.isFinite && binding.responseTimeSeconds >= 0 &&
          binding.driveStiffness.isFinite && binding.driveStiffness >= 0 &&
          binding.driveDamping.isFinite && binding.driveDamping >= 0
      })
    else {
      throw ConnectomeError.invalid("cold NumiLab compiled action snapshot is incomplete or invalid")
    }
  }

  public func validate(
    robot: NumiLabRobotInterface,
    contract: NumiLabTaskActionContract
  ) throws {
    try validate()
    try contract.validate()
    guard nativeRepositoryRevision == robot.nativeRepositoryRevision,
      nativeRepositoryRevision == contract.nativeRepositoryRevision,
      robot.contentSHA256 == contract.robotContentSHA256,
      worldFingerprint == contract.worldFingerprint,
      taskFingerprint == contract.taskFingerprint,
      actionFingerprint == contract.actionFingerprint,
      robotFingerprint == contract.robotFingerprint,
      actuatorIdentifiers == contract.actuatorIdentifiers else {
      throw ConnectomeError.invalid(
        "cold NumiLab action snapshot disagrees with the checksum-bound task/robot contract"
      )
    }
  }

  /// Promotes cold native compilation evidence to execution authority only
  /// after the actual live rollout proves the same immutable physical-owner
  /// identity. The live run fingerprint is never inferred by the exporter.
  public func executionReceipt(
    liveRollout: NumiLabLiveRolloutIdentity,
    robot: NumiLabRobotInterface,
    contract: NumiLabTaskActionContract
  ) throws -> NumiLabCompiledTaskActionReceipt {
    try validate(robot: robot, contract: contract)
    guard liveRollout.actionCount == UInt32(bindings.count),
      liveRollout.worldFingerprint == worldFingerprint,
      liveRollout.taskFingerprint == taskFingerprint,
      liveRollout.actionFingerprint == actionFingerprint,
      liveRollout.robotFingerprint == robotFingerprint else {
      throw ConnectomeError.invalid(
        "live NumiLab rollout does not match the native-compiled action snapshot"
      )
    }
    return try NumiLabCompiledTaskActionReceipt(
      runFingerprint: liveRollout.runFingerprint,
      worldFingerprint: worldFingerprint,
      taskFingerprint: taskFingerprint,
      actionFingerprint: actionFingerprint,
      robotFingerprint: robotFingerprint,
      bindings: bindings
    )
  }
}

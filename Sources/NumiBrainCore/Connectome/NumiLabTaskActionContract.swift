import Foundation

/// Physical-owner publication describing the exact NumiLab task action order.
/// The exporter cannot infer this from robot actuator order: TaskPacks select
/// actuator identities explicitly, and a task may expose only a subset.
@frozen
public struct NumiLabTaskActionContract: Codable, Equatable, Sendable {
  public static let currentVersion: UInt32 = 1
  public let version: UInt32
  public let nativeRepositoryRevision: String
  public let robotContentSHA256: String
  public let worldFingerprint: UInt64
  public let taskFingerprint: UInt64
  public let actionFingerprint: UInt64
  public let robotFingerprint: UInt64
  public let actuatorIdentifiers: [String]
  public let normalizedMinimum: Float
  public let normalizedMaximum: Float

  public init(
    nativeRepositoryRevision: String,
    robotContentSHA256: String,
    worldFingerprint: UInt64,
    taskFingerprint: UInt64,
    actionFingerprint: UInt64,
    robotFingerprint: UInt64,
    actuatorIdentifiers: [String],
    normalizedMinimum: Float = -1,
    normalizedMaximum: Float = 1
  ) throws {
    version = Self.currentVersion
    self.nativeRepositoryRevision = nativeRepositoryRevision
    self.robotContentSHA256 = robotContentSHA256
    self.worldFingerprint = worldFingerprint
    self.taskFingerprint = taskFingerprint
    self.actionFingerprint = actionFingerprint
    self.robotFingerprint = robotFingerprint
    self.actuatorIdentifiers = actuatorIdentifiers
    self.normalizedMinimum = normalizedMinimum
    self.normalizedMaximum = normalizedMaximum
    try validate()
  }

  public func validate() throws {
    guard version == Self.currentVersion,
      nativeRepositoryRevision.count == 40,
      nativeRepositoryRevision.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
      BrainPolicyEvidenceArtifact.isSHA256(robotContentSHA256),
      worldFingerprint != 0, taskFingerprint != 0, actionFingerprint != 0, robotFingerprint != 0,
      !actuatorIdentifiers.isEmpty, actuatorIdentifiers.count <= 4096,
      Set(actuatorIdentifiers).count == actuatorIdentifiers.count,
      actuatorIdentifiers.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 1024 && !$0.utf8.contains(0) }),
      normalizedMinimum.isFinite, normalizedMaximum.isFinite,
      normalizedMinimum < 0, normalizedMaximum > 0,
      normalizedMinimum < normalizedMaximum
    else {
      throw ConnectomeError.invalid("NumiLab task action contract is incomplete or invalid")
    }
  }
}

/// Exact conversion from NumiBrain absolute position commands to the normalized
/// task coordinates consumed by NumiLab's existing external-action rollout API.
/// This is a value conversion only; it does not step physics or publish a root.
@frozen
public struct NumiLabPositionActionEncoder: Sendable {
  @frozen
  public struct Lane: Equatable, Sendable {
    public let actuatorIdentifier: String
    public let jointIdentifier: String
    public let minimumPosition: Float
    public let maximumPosition: Float
    public let restPosition: Float
    public let nativeScale: Float
  }

  public let contract: NumiLabTaskActionContract
  public let lanes: [Lane]

  public init(robot: NumiLabRobotInterface, contract: NumiLabTaskActionContract) throws {
    try contract.validate()
    guard robot.nativeRepositoryRevision == contract.nativeRepositoryRevision,
      robot.contentSHA256 == contract.robotContentSHA256 else {
      throw ConnectomeError.invalid("task action contract belongs to a different native robot export")
    }
    let byID = Dictionary(uniqueKeysWithValues: robot.actuators.map { ($0.id, $0) })
    var compiled: [Lane] = []
    compiled.reserveCapacity(contract.actuatorIdentifiers.count)
    for identifier in contract.actuatorIdentifiers {
      guard let actuator = byID[identifier],
        actuator.kind == .jointPosition || actuator.kind == .gripperPosition,
        actuator.terms.isEmpty,
        actuator.scale.isFinite, actuator.scale > 0,
        let jointIndex = robot.jointNames.firstIndex(of: actuator.target),
        Int(actuator.component) < robot.joints[jointIndex].coordinates.count else {
        throw ConnectomeError.invalid("task action is not a directly normalized position actuator")
      }
      let coordinate = robot.joints[jointIndex].coordinates[Int(actuator.component)]
      guard coordinate.minimumPosition.isFinite, coordinate.maximumPosition.isFinite,
        coordinate.restPosition.isFinite,
        coordinate.minimumPosition <= coordinate.restPosition,
        coordinate.restPosition <= coordinate.maximumPosition else {
        throw ConnectomeError.invalid("task action references an invalid authored coordinate")
      }
      compiled.append(Lane(actuatorIdentifier: identifier, jointIdentifier: actuator.target,
        minimumPosition: coordinate.minimumPosition, maximumPosition: coordinate.maximumPosition,
        restPosition: coordinate.restPosition, nativeScale: actuator.scale))
    }
    self.contract = contract
    lanes = compiled
  }

  public func encodeAbsolutePositions(_ commands: [Float]) throws -> [Float] {
    guard commands.count == lanes.count else {
      throw ConnectomeError.invalid("absolute command count does not match NumiLab task action count")
    }
    return try zip(commands, lanes).map { command, lane in
      guard command.isFinite,
        command >= lane.minimumPosition, command <= lane.maximumPosition else {
        throw ConnectomeError.invalid("absolute position command is outside the authored joint range")
      }
      let normalized = (command - lane.restPosition) / lane.nativeScale
      guard normalized.isFinite,
        normalized >= contract.normalizedMinimum,
        normalized <= contract.normalizedMaximum else {
        throw ConnectomeError.invalid("absolute command exceeds the task's normalized actuator authority")
      }
      return normalized
    }
  }

  public func decodeNormalizedPositions(_ actions: [Float]) throws -> [Float] {
    guard actions.count == lanes.count else {
      throw ConnectomeError.invalid("normalized action count does not match NumiLab task action count")
    }
    return try zip(actions, lanes).map { action, lane in
      guard action.isFinite,
        action >= contract.normalizedMinimum,
        action <= contract.normalizedMaximum else {
        throw ConnectomeError.invalid("normalized action is outside the physical owner's declared task range")
      }
      let command = lane.restPosition + lane.nativeScale * action
      guard command.isFinite,
        command >= lane.minimumPosition - 1e-6,
        command <= lane.maximumPosition + 1e-6 else {
        throw ConnectomeError.invalid("normalized task range would command outside the authored joint limit")
      }
      return min(max(command, lane.minimumPosition), lane.maximumPosition)
    }
  }
}

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

/// One action binding copied from NumiLab's compiled `MRTaskActionBindingGPU`.
/// Values here are physical-owner evidence, not inferred mechanism metadata.
@frozen
public struct NumiLabCompiledTaskActionBinding: Codable, Equatable, Sendable {
  public let actionIndex: UInt32
  public let qIndex: UInt32?
  public let vIndex: UInt32?
  public let actuatorKind: NumiLabRobotInterface.ActuatorKind
  public let resolvedComponent: UInt32
  public let componentLane: UInt32
  public let normalizedScale: Float
  public let lowerTarget: Float
  public let upperTarget: Float
  public let responseTimeSeconds: Float
  public let driveStiffness: Float
  public let driveDamping: Float
  public let interactionMotion: Bool

  public init(actionIndex: UInt32, qIndex: UInt32?, vIndex: UInt32?,
    actuatorKind: NumiLabRobotInterface.ActuatorKind, resolvedComponent: UInt32,
    componentLane: UInt32, normalizedScale: Float, lowerTarget: Float,
    upperTarget: Float, responseTimeSeconds: Float, driveStiffness: Float = 0,
    driveDamping: Float = 0, interactionMotion: Bool = false) {
    self.actionIndex = actionIndex; self.qIndex = qIndex; self.vIndex = vIndex
    self.actuatorKind = actuatorKind; self.resolvedComponent = resolvedComponent
    self.componentLane = componentLane; self.normalizedScale = normalizedScale
    self.lowerTarget = lowerTarget; self.upperTarget = upperTarget
    self.responseTimeSeconds = responseTimeSeconds; self.driveStiffness = driveStiffness
    self.driveDamping = driveDamping; self.interactionMotion = interactionMotion
  }
}

/// Identity and action table observed from one compiled/running NumiLab task.
/// `runFingerprint` prevents a task/action table from being transplanted into
/// another compiled run that happens to share the same mechanism dimensions.
@frozen
public struct NumiLabCompiledTaskActionReceipt: Codable, Equatable, Sendable {
  public static let currentVersion: UInt32 = 1
  public let version: UInt32
  public let runFingerprint: UInt64
  public let worldFingerprint: UInt64
  public let taskFingerprint: UInt64
  public let actionFingerprint: UInt64
  public let robotFingerprint: UInt64
  public let bindings: [NumiLabCompiledTaskActionBinding]

  public init(runFingerprint: UInt64, worldFingerprint: UInt64,
    taskFingerprint: UInt64, actionFingerprint: UInt64, robotFingerprint: UInt64,
    bindings: [NumiLabCompiledTaskActionBinding]) throws {
    version = Self.currentVersion; self.runFingerprint = runFingerprint
    self.worldFingerprint = worldFingerprint; self.taskFingerprint = taskFingerprint
    self.actionFingerprint = actionFingerprint; self.robotFingerprint = robotFingerprint
    self.bindings = bindings
    try validate()
  }

  public func validate() throws {
    guard version == Self.currentVersion, runFingerprint != 0, worldFingerprint != 0,
      taskFingerprint != 0, actionFingerprint != 0, robotFingerprint != 0,
      !bindings.isEmpty, bindings.count <= 4096,
      bindings.enumerated().allSatisfy({ index, binding in
        binding.actionIndex == UInt32(index) && binding.normalizedScale.isFinite &&
          binding.normalizedScale > 0 && binding.lowerTarget.isFinite &&
          binding.upperTarget.isFinite && binding.lowerTarget <= binding.upperTarget &&
          binding.responseTimeSeconds.isFinite && binding.responseTimeSeconds >= 0 &&
          binding.driveStiffness.isFinite && binding.driveStiffness >= 0 &&
          binding.driveDamping.isFinite && binding.driveDamping >= 0
      }) else {
      throw ConnectomeError.invalid("compiled NumiLab task action receipt is incomplete or invalid")
    }
  }

  public func validate(against contract: NumiLabTaskActionContract) throws {
    try validate(); try contract.validate()
    guard worldFingerprint == contract.worldFingerprint,
      taskFingerprint == contract.taskFingerprint,
      actionFingerprint == contract.actionFingerprint,
      robotFingerprint == contract.robotFingerprint,
      bindings.count == contract.actuatorIdentifiers.count else {
      throw ConnectomeError.invalid("compiled NumiLab action receipt belongs to another task or run identity")
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
    public let qIndex: UInt32
    public let vIndex: UInt32
    public let minimumPosition: Float
    public let maximumPosition: Float
    public let restPosition: Float
    public let nativeScale: Float
  }

  public let contract: NumiLabTaskActionContract
  public let lanes: [Lane]
  /// Nonzero only when the encoder was reconciled against a physical owner's
  /// exact compiled task table. A structural encoder is useful for inspection,
  /// but must not be treated as an execution admission.
  public let compiledRunFingerprint: UInt64
  public var isPhysicalOwnerBound: Bool { compiledRunFingerprint != 0 }

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
        actuator.terms.isEmpty, actuator.scale.isFinite, actuator.scale > 0,
        let q = actuator.qIndex, let v = actuator.vIndex,
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
        qIndex: q, vIndex: v, minimumPosition: coordinate.minimumPosition,
        maximumPosition: coordinate.maximumPosition, restPosition: coordinate.restPosition,
        nativeScale: actuator.scale))
    }
    self.contract = contract; lanes = compiled; compiledRunFingerprint = 0
  }

  /// Execution-strength initializer. It reconciles the exact compiled task
  /// table with the checksum-bound RobotPack export before exposing commands.
  public init(robot: NumiLabRobotInterface, contract: NumiLabTaskActionContract,
    compiledTask receipt: NumiLabCompiledTaskActionReceipt) throws {
    let structural = try Self(robot: robot, contract: contract)
    try receipt.validate(against: contract)
    let byID = Dictionary(uniqueKeysWithValues: robot.actuators.map { ($0.id, $0) })
    var exact: [Lane] = []
    exact.reserveCapacity(structural.lanes.count)
    for index in structural.lanes.indices {
      let lane = structural.lanes[index]
      let binding = receipt.bindings[index]
      guard let actuator = byID[lane.actuatorIdentifier],
        binding.actuatorKind == actuator.kind,
        binding.componentLane == actuator.component,
        binding.qIndex == actuator.qIndex, binding.vIndex == actuator.vIndex,
        binding.normalizedScale == actuator.scale,
        binding.responseTimeSeconds == actuator.responseTimeSeconds,
        binding.lowerTarget >= lane.minimumPosition,
        binding.upperTarget <= lane.maximumPosition,
        binding.lowerTarget <= lane.restPosition,
        lane.restPosition <= binding.upperTarget else {
        throw ConnectomeError.invalid("compiled NumiLab action binding disagrees with native robot ownership or authority")
      }
      exact.append(Lane(actuatorIdentifier: lane.actuatorIdentifier,
        jointIdentifier: lane.jointIdentifier, qIndex: lane.qIndex, vIndex: lane.vIndex,
        minimumPosition: binding.lowerTarget, maximumPosition: binding.upperTarget,
        restPosition: lane.restPosition, nativeScale: binding.normalizedScale))
    }
    self.contract = contract; lanes = exact; compiledRunFingerprint = receipt.runFingerprint
  }

  public func encodeAbsolutePositions(_ commands: [Float]) throws -> [Float] {
    guard commands.count == lanes.count else {
      throw ConnectomeError.invalid("absolute command count does not match NumiLab task action count")
    }
    return try zip(commands, lanes).map { command, lane in
      guard command.isFinite,
        command >= lane.minimumPosition, command <= lane.maximumPosition else {
        throw ConnectomeError.invalid("absolute position command is outside the compiled task target range")
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
        throw ConnectomeError.invalid("normalized action would command outside the compiled task target range")
      }
      return min(max(command, lane.minimumPosition), lane.maximumPosition)
    }
  }
}

import Foundation

/// Cold import of NumiLab's actual native asset topology. No sensor inventory,
/// actuator physics, emergency command or biological anatomy is invented.
/// The physical owner must bind its own model fingerprint at instantiation.
public struct NumiLabRobotInterface: Sendable {
  public enum ActuatorKind: UInt32, Codable, Sendable {
    case jointPosition = 0, jointVelocity = 1, jointEffort = 2, tendonPosition = 3
    case gripperPosition = 4, rotorMixer = 5, bodyWrench = 6, measuredSurface = 7
  }
  public struct Term: Codable, Sendable {
    public let joint: String
    public let coefficient: Float
  }
  public struct Actuator: Codable, Sendable {
    public let id: String
    public let kind: ActuatorKind
    public let target: String
    public let scale: Float
    public let responseTimeSeconds: Float
    public let component: UInt32
    public let parameters: [Float]
    public let terms: [Term]
  }
  private struct Wire: Decodable {
    let version: UInt32
    let nativeRepositoryRevision: String
    let robotID: String
    let sourceRepository: String
    let sourceRevision: String
    let license: String
    let bodyNames: [String]
    let jointNames: [String]
    let joints: [NumanXJointTopology]
    let actuators: [Actuator]
    let nativeKinematicsSamples: UInt32
    let scope: String
  }
  public let contentSHA256: String
  public let nativeRepositoryRevision: String
  public let robotID: String
  public let sourceRepository: String
  public let sourceRevision: String
  /// Empty means absent in the native RobotPack; never invent a license.
  public let license: String
  public let bodyNames: [String]
  public let jointNames: [String]
  public let joints: [NumanXJointTopology]
  public let actuators: [Actuator]

  public init(data: Data, expectedSHA256: String, expectedNativeRevision: String,
    maximumBytes: Int = 16_777_216) throws {
    guard !data.isEmpty, data.count <= maximumBytes,
      BrainPolicyEvidenceArtifact.isSHA256(expectedSHA256),
      BrainPolicyEvidenceArtifact.sha256(data) == expectedSHA256,
      expectedNativeRevision.count == 40,
      expectedNativeRevision.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
      throw ConnectomeError.invalid("native robot metadata exceeds its budget or has a foreign content identity")
    }
    let w = try JSONDecoder().decode(Wire.self, from: data)
    func namesValid(_ values: [String], empty: Bool = false) -> Bool {
      (empty || !values.isEmpty) && values.count <= 4096 && Set(values).count == values.count &&
        values.allSatisfy { !$0.isEmpty && $0.utf8.count <= 1024 && !$0.utf8.contains(0) }
    }
    guard w.version == 1, w.nativeRepositoryRevision == expectedNativeRevision,
      w.scope == "topology-and-actuator-metadata-only", w.nativeKinematicsSamples == 3,
      namesValid([w.robotID]), namesValid(w.bodyNames), namesValid(w.jointNames, empty: true),
      w.joints.count == w.jointNames.count, w.joints.count == w.bodyNames.count - 1,
      namesValid(w.actuators.map(\.id)),
      w.joints.enumerated().allSatisfy({ $0.element.jointIdentifier == UInt32($0.offset) }),
      w.joints.allSatisfy({ $0.coordinates.count <= 1 && $0.coordinates.allSatisfy { $0.identifier == 0 && $0.kinesthesiaReceptorIndex == nil } }) else {
      throw ConnectomeError.invalid("native robot topology shape, names, revision or scope is invalid")
    }
    // Validate the actual tree now. This temporary ID is NOT published as an
    // authoritative NumanX model identity; the physical owner supplies that.
    _ = try NumanXJointTopologyCatalog(numanXModelFingerprint: 1,
      bodyCount: UInt32(w.bodyNames.count), joints: w.joints)
    for a in w.actuators {
      guard !a.target.isEmpty, a.target.utf8.count <= 1024,
        a.scale.isFinite, a.scale != 0, a.responseTimeSeconds.isFinite, a.responseTimeSeconds >= 0,
        a.parameters.count == 4, a.parameters.allSatisfy(\.isFinite), a.terms.count <= 4096,
        a.terms.allSatisfy({ w.jointNames.contains($0.joint) && $0.coefficient.isFinite }) else {
        throw ConnectomeError.invalid("native actuator parameters or terms are invalid")
      }
      switch a.kind {
      case .jointPosition, .jointVelocity, .jointEffort, .gripperPosition:
        guard let index = w.jointNames.firstIndex(of: a.target),
          Int(a.component) < w.joints[index].coordinates.count else {
          throw ConnectomeError.invalid("native actuator does not address an existing joint coordinate")
        }
      case .rotorMixer, .bodyWrench, .measuredSurface:
        guard w.bodyNames.contains(a.target),
          (a.kind != .rotorMixer || a.component < 4),
          (a.kind != .bodyWrench || a.component < 6) else {
          throw ConnectomeError.invalid("native body actuator target is absent")
        }
      case .tendonPosition:
        guard !a.terms.isEmpty else { throw ConnectomeError.invalid("native tendon has no authored terms") }
      }
    }
    contentSHA256 = expectedSHA256; nativeRepositoryRevision = w.nativeRepositoryRevision
    robotID = w.robotID; sourceRepository = w.sourceRepository; sourceRevision = w.sourceRevision
    license = w.license; bodyNames = w.bodyNames; jointNames = w.jointNames
    joints = w.joints; actuators = w.actuators
  }

  /// The physical model fingerprint comes from the live owning model, not a
  /// guessed hash of counts, robot names or the exported JSON. This constructor
  /// does not claim the physical owner has admitted or instantiated that model.
  public func jointTopologyCatalog(numanXModelFingerprint: UInt64) throws -> NumanXJointTopologyCatalog {
    try NumanXJointTopologyCatalog(numanXModelFingerprint: numanXModelFingerprint,
      bodyCount: UInt32(bodyNames.count), joints: joints)
  }

  /// Compile absolute-position channels only for an entirely supported native
  /// position interface. Neutral/emergency behavior must be explicitly authored.
  /// Native action scales/response filters remain owned by NumiLab; these bounds
  /// do NOT imply its normalized policy action buffer accepts absolute position.
  public func positionChannels(neutralCommands: [String: Float],
    emergencyCommands: [String: Float]) throws -> [ActuatorChannelTemplate] {
    let names = Set(actuators.map(\.id))
    guard Set(neutralCommands.keys) == names, Set(emergencyCommands.keys) == names else {
      throw ConnectomeError.invalid("every native actuator needs explicit neutral and emergency commands")
    }
    return try actuators.enumerated().map { index, a in
      guard a.kind == .jointPosition || a.kind == .gripperPosition,
        a.terms.isEmpty, let joint = jointNames.firstIndex(of: a.target),
        Int(a.component) < joints[joint].coordinates.count else {
        throw ConnectomeError.invalid("mixed, rotor, force or tendon channels require their own physical adapter, not a position cast")
      }
      let coordinate = joints[joint].coordinates[Int(a.component)]
      return try ActuatorChannelTemplate(identifier: UInt32(index),
        outputMinimum: coordinate.minimumPosition, outputMaximum: coordinate.maximumPosition,
        neutralCommand: neutralCommands[a.id]!, emergencyCommand: emergencyCommands[a.id]!)
    }
  }
}

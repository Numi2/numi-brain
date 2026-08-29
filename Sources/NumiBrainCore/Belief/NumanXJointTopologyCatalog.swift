import Foundation

@frozen
public enum NumanXJointCoordinateKind: UInt16, Codable, CaseIterable, Sendable {
  case angular = 1
  case linear = 2
}

/// One independently sensed coordinate of an articulated NumanX joint.
/// Axis coordinates are expressed in the parent body's local frame.
@frozen
public struct NumanXJointCoordinateTopology: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt16
  public let kind: NumanXJointCoordinateKind
  public let parentLocalAxis: NumanXBodyLocalPoint
  public let minimumPosition: Float
  public let maximumPosition: Float
  public let restPosition: Float

  public init(
    identifier: UInt16,
    kind: NumanXJointCoordinateKind,
    parentLocalAxis: NumanXBodyLocalPoint,
    minimumPosition: Float,
    maximumPosition: Float,
    restPosition: Float
  ) throws {
    let axisNormSquared =
      parentLocalAxis.x * parentLocalAxis.x
      + parentLocalAxis.y * parentLocalAxis.y
      + parentLocalAxis.z * parentLocalAxis.z
    guard axisNormSquared.isFinite, axisNormSquared > 1e-12,
      minimumPosition.isFinite, maximumPosition.isFinite, restPosition.isFinite,
      minimumPosition < maximumPosition,
      (minimumPosition...maximumPosition).contains(restPosition)
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX joint coordinate axis or limits are invalid"
      )
    }
    self.identifier = identifier
    self.kind = kind
    self.parentLocalAxis = parentLocalAxis
    self.minimumPosition = minimumPosition
    self.maximumPosition = maximumPosition
    self.restPosition = restPosition
  }
}

/// Immutable articulation edge between two authoritative NumanX bodies.
@frozen
public struct NumanXJointTopology: Codable, Equatable, Hashable, Sendable {
  public let jointIdentifier: UInt32
  public let parentBodyIdentifier: UInt32
  public let childBodyIdentifier: UInt32
  public let coordinates: [NumanXJointCoordinateTopology]

  public init(
    jointIdentifier: UInt32,
    parentBodyIdentifier: UInt32,
    childBodyIdentifier: UInt32,
    coordinates: [NumanXJointCoordinateTopology]
  ) throws {
    guard parentBodyIdentifier != childBodyIdentifier,
      (1...6).contains(coordinates.count),
      Set(coordinates.map(\.identifier)).count == coordinates.count
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX joint topology endpoints or coordinates are invalid"
      )
    }
    self.jointIdentifier = jointIdentifier
    self.parentBodyIdentifier = parentBodyIdentifier
    self.childBodyIdentifier = childBodyIdentifier
    self.coordinates = coordinates.sorted { $0.identifier < $1.identifier }
  }
}

/// Content-addressed articulated body graph exported by NumanX. The catalog
/// owns endpoint identity and coordinate semantics; a scalar joint count is
/// never sufficient to construct a production body schema.
@frozen
public struct NumanXJointTopologyCatalog: Codable, Equatable, Hashable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let numanXModelFingerprint: UInt64
  public let bodyCount: UInt32
  public let joints: [NumanXJointTopology]
  public let fingerprint: UInt64

  public init(
    numanXModelFingerprint: UInt64,
    bodyCount: UInt32,
    joints: [NumanXJointTopology]
  ) throws {
    guard numanXModelFingerprint > 0, bodyCount > 1, !joints.isEmpty else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX joint topology catalog identity is incomplete"
      )
    }
    let canonicalJoints = joints.sorted { $0.jointIdentifier < $1.jointIdentifier }
    try Self.validate(bodyCount: bodyCount, joints: canonicalJoints)
    self.numanXModelFingerprint = numanXModelFingerprint
    self.bodyCount = bodyCount
    self.joints = canonicalJoints
    self.fingerprint = Self.computeFingerprint(
      numanXModelFingerprint: numanXModelFingerprint,
      bodyCount: bodyCount,
      joints: canonicalJoints
    )
  }

  public func validate(species: SpeciesTemplate) throws {
    guard bodyCount == species.body.bodyCount,
      UInt32(joints.count) == species.body.jointCount,
      fingerprint == species.body.jointTopologyFingerprint
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX joint topology catalog does not match the species body graph"
      )
    }
    try Self.validate(bodyCount: bodyCount, joints: joints)
  }

  public func joint(for identifier: UInt32) -> NumanXJointTopology? {
    joints.first { $0.jointIdentifier == identifier }
  }

  public var fingerprintHex: String {
    String(format: "%016llx", fingerprint)
  }

  private static func validate(
    bodyCount: UInt32,
    joints: [NumanXJointTopology]
  ) throws {
    guard Set(joints.map(\.jointIdentifier)).count == joints.count else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX joint identifiers must be unique"
      )
    }
    var adjacency = Array(repeating: [UInt32](), count: Int(bodyCount))
    for joint in joints {
      guard joint.parentBodyIdentifier < bodyCount,
        joint.childBodyIdentifier < bodyCount
      else {
        throw BrainRuntimeError.invalidDescriptor(
          "NumanX joint body identifier is out of bounds"
        )
      }
      adjacency[Int(joint.parentBodyIdentifier)].append(joint.childBodyIdentifier)
      adjacency[Int(joint.childBodyIdentifier)].append(joint.parentBodyIdentifier)
    }
    var visited: Set<UInt32> = [0]
    var frontier: [UInt32] = [0]
    while let body = frontier.popLast() {
      for neighbor in adjacency[Int(body)] where visited.insert(neighbor).inserted {
        frontier.append(neighbor)
      }
    }
    guard visited.count == Int(bodyCount) else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX joint graph must connect every declared body"
      )
    }
  }

  private enum CodingKeys: String, CodingKey {
    case formatVersion
    case numanXModelFingerprint
    case bodyCount
    case joints
    case fingerprint
  }

  public func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(Self.formatVersion, forKey: .formatVersion)
    try values.encode(numanXModelFingerprint, forKey: .numanXModelFingerprint)
    try values.encode(bodyCount, forKey: .bodyCount)
    try values.encode(joints, forKey: .joints)
    try values.encode(fingerprint, forKey: .fingerprint)
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    guard
      try values.decode(UInt32.self, forKey: .formatVersion)
        == Self.formatVersion
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX joint topology catalog format is unsupported"
      )
    }
    let decoded = try Self(
      numanXModelFingerprint: values.decode(
        UInt64.self, forKey: .numanXModelFingerprint
      ),
      bodyCount: values.decode(UInt32.self, forKey: .bodyCount),
      joints: values.decode([NumanXJointTopology].self, forKey: .joints)
    )
    guard decoded.fingerprint == (try values.decode(UInt64.self, forKey: .fingerprint))
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX joint topology catalog fingerprint drift"
      )
    }
    self = decoded
  }

  private static func computeFingerprint(
    numanXModelFingerprint: UInt64,
    bodyCount: UInt32,
    joints: [NumanXJointTopology]
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    mix(formatVersion, into: &hash)
    mix(numanXModelFingerprint, into: &hash)
    mix(bodyCount, into: &hash)
    mix(UInt32(joints.count), into: &hash)
    for joint in joints {
      mix(joint.jointIdentifier, into: &hash)
      mix(joint.parentBodyIdentifier, into: &hash)
      mix(joint.childBodyIdentifier, into: &hash)
      mix(UInt32(joint.coordinates.count), into: &hash)
      for coordinate in joint.coordinates {
        mix(UInt32(coordinate.identifier), into: &hash)
        mix(UInt32(coordinate.kind.rawValue), into: &hash)
        mix(coordinate.parentLocalAxis.x.bitPattern, into: &hash)
        mix(coordinate.parentLocalAxis.y.bitPattern, into: &hash)
        mix(coordinate.parentLocalAxis.z.bitPattern, into: &hash)
        mix(coordinate.minimumPosition.bitPattern, into: &hash)
        mix(coordinate.maximumPosition.bitPattern, into: &hash)
        mix(coordinate.restPosition.bitPattern, into: &hash)
      }
    }
    return hash
  }

  private static func mix(_ value: UInt32, into hash: inout UInt64) {
    mix(UInt64(value), into: &hash)
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }
}

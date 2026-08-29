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

  private enum CodingKeys: String, CodingKey {
    case identifier
    case kind
    case parentLocalAxis
    case minimumPosition
    case maximumPosition
    case restPosition
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      identifier: values.decode(UInt16.self, forKey: .identifier),
      kind: values.decode(NumanXJointCoordinateKind.self, forKey: .kind),
      parentLocalAxis: values.decode(
        NumanXBodyLocalPoint.self, forKey: .parentLocalAxis
      ),
      minimumPosition: values.decode(Float.self, forKey: .minimumPosition),
      maximumPosition: values.decode(Float.self, forKey: .maximumPosition),
      restPosition: values.decode(Float.self, forKey: .restPosition)
    )
  }
}

/// Immutable articulation edge between two authoritative NumanX bodies.
@frozen
public struct NumanXJointTopology: Codable, Equatable, Hashable, Sendable {
  public let jointIdentifier: UInt32
  public let parentBodyIdentifier: UInt32
  public let childBodyIdentifier: UInt32
  public let parentLocalAnchor: NumanXBodyLocalPoint
  public let childLocalAnchor: NumanXBodyLocalPoint
  public let restRelativeOrientation: BrainQuaternion
  public let coordinates: [NumanXJointCoordinateTopology]

  public init(
    jointIdentifier: UInt32,
    parentBodyIdentifier: UInt32,
    childBodyIdentifier: UInt32,
    parentLocalAnchor: NumanXBodyLocalPoint,
    childLocalAnchor: NumanXBodyLocalPoint,
    restRelativeOrientation: BrainQuaternion,
    coordinates: [NumanXJointCoordinateTopology]
  ) throws {
    let validatedParentAnchor = try NumanXBodyLocalPoint(
      x: parentLocalAnchor.x,
      y: parentLocalAnchor.y,
      z: parentLocalAnchor.z
    )
    let validatedChildAnchor = try NumanXBodyLocalPoint(
      x: childLocalAnchor.x,
      y: childLocalAnchor.y,
      z: childLocalAnchor.z
    )
    let validatedRestOrientation = try BrainQuaternion(
      x: restRelativeOrientation.x,
      y: restRelativeOrientation.y,
      z: restRelativeOrientation.z,
      w: restRelativeOrientation.w
    )
    let validatedCoordinates = try coordinates.map {
      try NumanXJointCoordinateTopology(
        identifier: $0.identifier,
        kind: $0.kind,
        parentLocalAxis: $0.parentLocalAxis,
        minimumPosition: $0.minimumPosition,
        maximumPosition: $0.maximumPosition,
        restPosition: $0.restPosition
      )
    }
    guard parentBodyIdentifier != childBodyIdentifier,
      (1...6).contains(validatedCoordinates.count),
      Set(validatedCoordinates.map(\.identifier)).count
        == validatedCoordinates.count
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX joint topology endpoints or coordinates are invalid"
      )
    }
    self.jointIdentifier = jointIdentifier
    self.parentBodyIdentifier = parentBodyIdentifier
    self.childBodyIdentifier = childBodyIdentifier
    self.parentLocalAnchor = validatedParentAnchor
    self.childLocalAnchor = validatedChildAnchor
    self.restRelativeOrientation = validatedRestOrientation
    self.coordinates = validatedCoordinates.sorted { $0.identifier < $1.identifier }
  }

  private enum CodingKeys: String, CodingKey {
    case jointIdentifier
    case parentBodyIdentifier
    case childBodyIdentifier
    case parentLocalAnchor
    case childLocalAnchor
    case restRelativeOrientation
    case coordinates
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      jointIdentifier: values.decode(UInt32.self, forKey: .jointIdentifier),
      parentBodyIdentifier: values.decode(
        UInt32.self, forKey: .parentBodyIdentifier
      ),
      childBodyIdentifier: values.decode(UInt32.self, forKey: .childBodyIdentifier),
      parentLocalAnchor: values.decode(
        NumanXBodyLocalPoint.self, forKey: .parentLocalAnchor
      ),
      childLocalAnchor: values.decode(
        NumanXBodyLocalPoint.self, forKey: .childLocalAnchor
      ),
      restRelativeOrientation: values.decode(
        BrainQuaternion.self, forKey: .restRelativeOrientation
      ),
      coordinates: values.decode(
        [NumanXJointCoordinateTopology].self, forKey: .coordinates
      )
    )
  }
}

/// Content-addressed articulated body graph exported by NumanX. The catalog
/// owns endpoint identity and coordinate semantics; a scalar joint count is
/// never sufficient to construct a production body schema.
@frozen
public struct NumanXJointTopologyCatalog: Codable, Equatable, Hashable, Sendable {
  public static let formatVersion: UInt32 = 2

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
    try Self.validate(bodyCount: bodyCount, joints: joints)
    let canonicalJoints = try Self.topologicallyOrdered(
      bodyCount: bodyCount,
      joints: joints
    )
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
    guard joints.count == Int(bodyCount - 1),
      !joints.contains(where: { $0.childBodyIdentifier == 0 }),
      Set(joints.map(\.childBodyIdentifier)).count == joints.count
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX articulation must be a body-rooted directed tree"
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

  private static func topologicallyOrdered(
    bodyCount: UInt32,
    joints: [NumanXJointTopology]
  ) throws -> [NumanXJointTopology] {
    var remaining = joints.sorted { $0.jointIdentifier < $1.jointIdentifier }
    var reachedBodies: Set<UInt32> = [0]
    var ordered: [NumanXJointTopology] = []
    ordered.reserveCapacity(joints.count)
    while !remaining.isEmpty {
      guard let nextIndex = remaining.firstIndex(where: {
        reachedBodies.contains($0.parentBodyIdentifier)
          && !reachedBodies.contains($0.childBodyIdentifier)
      }) else {
        throw BrainRuntimeError.invalidDescriptor(
          "NumanX directed joint graph cannot be ordered from body zero"
        )
      }
      let joint = remaining.remove(at: nextIndex)
      reachedBodies.insert(joint.childBodyIdentifier)
      ordered.append(joint)
    }
    guard reachedBodies.count == Int(bodyCount) else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX directed joint graph does not cover every body"
      )
    }
    return ordered
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
      mix(joint.parentLocalAnchor.x.bitPattern, into: &hash)
      mix(joint.parentLocalAnchor.y.bitPattern, into: &hash)
      mix(joint.parentLocalAnchor.z.bitPattern, into: &hash)
      mix(joint.childLocalAnchor.x.bitPattern, into: &hash)
      mix(joint.childLocalAnchor.y.bitPattern, into: &hash)
      mix(joint.childLocalAnchor.z.bitPattern, into: &hash)
      mix(joint.restRelativeOrientation.x.bitPattern, into: &hash)
      mix(joint.restRelativeOrientation.y.bitPattern, into: &hash)
      mix(joint.restRelativeOrientation.z.bitPattern, into: &hash)
      mix(joint.restRelativeOrientation.w.bitPattern, into: &hash)
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

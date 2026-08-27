import Foundation

@frozen
public struct NumanXBodyLocalPoint: Codable, Equatable, Hashable, Sendable {
  public let x: Float
  public let y: Float
  public let z: Float

  public init(x: Float, y: Float, z: Float) throws {
    guard x.isFinite, y.isFinite, z.isFinite else {
      throw BrainRuntimeError.transaction(
        "NumanX muscle attachment coordinates must be finite"
      )
    }
    self.x = x
    self.y = y
    self.z = z
  }
}

@frozen
public struct NumanXMuscleAttachment: Codable, Equatable, Hashable, Sendable {
  public let muscleIdentifier: UInt32
  public let firstBodyIdentifier: UInt32
  public let terminalBodyIdentifier: UInt32
  public let routeNodeCount: UInt32
  public let firstLocalPoint: NumanXBodyLocalPoint
  public let terminalLocalPoint: NumanXBodyLocalPoint

  public init(
    muscleIdentifier: UInt32,
    firstBodyIdentifier: UInt32,
    terminalBodyIdentifier: UInt32,
    routeNodeCount: UInt32,
    firstLocalPoint: NumanXBodyLocalPoint,
    terminalLocalPoint: NumanXBodyLocalPoint
  ) throws {
    guard routeNodeCount >= 2 else {
      throw BrainRuntimeError.transaction(
        "NumanX muscle attachment route requires at least two nodes"
      )
    }
    self.muscleIdentifier = muscleIdentifier
    self.firstBodyIdentifier = firstBodyIdentifier
    self.terminalBodyIdentifier = terminalBodyIdentifier
    self.routeNodeCount = routeNodeCount
    self.firstLocalPoint = firstLocalPoint
    self.terminalLocalPoint = terminalLocalPoint
  }
}

/// Immutable identity and endpoint geometry for one ordered NumanX muscle
/// catalog. First and terminal describe source route order; they do not imply
/// anatomical proximal/distal semantics.
@frozen
public struct NumanXMuscleAttachmentCatalog: Codable, Equatable, Hashable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let bodyCount: UInt32
  public let attachments: [NumanXMuscleAttachment]
  public let fingerprint: UInt64

  public init(
    bodyCount: UInt32,
    attachments: [NumanXMuscleAttachment]
  ) throws {
    guard bodyCount > 0, !attachments.isEmpty else {
      throw BrainRuntimeError.transaction(
        "NumanX muscle attachment catalog must contain bodies and muscles"
      )
    }
    var muscleIdentifiers = Set<UInt32>()
    muscleIdentifiers.reserveCapacity(attachments.count)
    for attachment in attachments {
      guard attachment.firstBodyIdentifier < bodyCount,
        attachment.terminalBodyIdentifier < bodyCount
      else {
        throw BrainRuntimeError.transaction(
          "NumanX muscle attachment body identifier is out of bounds"
        )
      }
      guard muscleIdentifiers.insert(attachment.muscleIdentifier).inserted else {
        throw BrainRuntimeError.transaction(
          "NumanX muscle attachment identifiers must be unique"
        )
      }
    }
    self.bodyCount = bodyCount
    self.attachments = attachments
    self.fingerprint = Self.computeFingerprint(
      bodyCount: bodyCount,
      attachments: attachments
    )
  }

  public func attachment(
    forMuscleIdentifier muscleIdentifier: UInt32
  ) -> NumanXMuscleAttachment? {
    attachments.first { $0.muscleIdentifier == muscleIdentifier }
  }

  public func validate(profile: ProtectiveMotorProfile) throws {
    guard
      profile.channels.map(\.muscleIdentifier)
        == attachments.map(\.muscleIdentifier)
    else {
      throw BrainRuntimeError.transaction(
        "NumanX muscle attachment order does not match the motor profile"
      )
    }
  }

  public var fingerprintHex: String {
    String(format: "%016llx", fingerprint)
  }

  private enum CodingKeys: String, CodingKey {
    case bodyCount
    case attachments
    case fingerprint
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let decoded = try Self(
      bodyCount: values.decode(UInt32.self, forKey: .bodyCount),
      attachments: values.decode([NumanXMuscleAttachment].self, forKey: .attachments)
    )
    guard decoded.fingerprint == (try values.decode(UInt64.self, forKey: .fingerprint))
    else {
      throw BrainRuntimeError.transaction(
        "NumanX muscle attachment catalog fingerprint drift"
      )
    }
    self = decoded
  }

  private static func computeFingerprint(
    bodyCount: UInt32,
    attachments: [NumanXMuscleAttachment]
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    mix(formatVersion, into: &hash)
    mix(bodyCount, into: &hash)
    mix(UInt32(attachments.count), into: &hash)
    for attachment in attachments {
      mix(attachment.muscleIdentifier, into: &hash)
      mix(attachment.firstBodyIdentifier, into: &hash)
      mix(attachment.terminalBodyIdentifier, into: &hash)
      mix(attachment.routeNodeCount, into: &hash)
      mix(attachment.firstLocalPoint.x.bitPattern, into: &hash)
      mix(attachment.firstLocalPoint.y.bitPattern, into: &hash)
      mix(attachment.firstLocalPoint.z.bitPattern, into: &hash)
      mix(attachment.terminalLocalPoint.x.bitPattern, into: &hash)
      mix(attachment.terminalLocalPoint.y.bitPattern, into: &hash)
      mix(attachment.terminalLocalPoint.z.bitPattern, into: &hash)
    }
    return hash
  }

  private static func mix(_ value: UInt32, into hash: inout UInt64) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }
}

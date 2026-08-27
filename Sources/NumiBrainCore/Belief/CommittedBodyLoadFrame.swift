import Foundation

@frozen
public struct BodyLoadEndpointRole: OptionSet, Codable, Hashable, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let firstRouteEndpoint = Self(rawValue: 1 << 0)
  public static let terminalRouteEndpoint = Self(rawValue: 1 << 1)
}

@frozen
public struct CommittedBodyLoadSample: Codable, Equatable, Hashable, Sendable {
  public let bodyIdentifier: UInt32
  public let endpointRole: BodyLoadEndpointRole
  public let sourceMuscleIdentifier: UInt32
  public let maximumAbsoluteMuscleForce: Float
  public let acceptedTimestamp: BrainTimestamp
  public let acceptedPhysicsStateFingerprint: UInt64

  fileprivate init(
    bodyIdentifier: UInt32,
    endpointRole: BodyLoadEndpointRole,
    observation: LocalizedMuscleLoadReceptorObservation
  ) {
    self.bodyIdentifier = bodyIdentifier
    self.endpointRole = endpointRole
    sourceMuscleIdentifier = observation.attachment.muscleIdentifier
    maximumAbsoluteMuscleForce = observation.maximumAbsoluteMuscleForce
    acceptedTimestamp = observation.event.timestamp
    acceptedPhysicsStateFingerprint = observation.acceptedPhysicsStateFingerprint
  }
}

/// Sparse accepted-load view over one immutable NumanX body catalog. It is a
/// transaction-owned precursor to the learned body schema, not authoritative
/// physical state. Every sample retains the causal receptor and physical-token
/// provenance from which it was constructed.
@frozen
public struct CommittedBodyLoadFrame: Codable, Equatable, Hashable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let jointCommitFingerprint: UInt64
  public let committedTimestamp: BrainTimestamp
  public let brainGeneration: UInt64
  public let attachmentCatalogFingerprint: UInt64
  public let bodyCount: UInt32
  public let samples: [CommittedBodyLoadSample]
  public let fingerprint: UInt64

  public init(
    commit: BrainJointCommitToken,
    attachmentCatalog: NumanXMuscleAttachmentCatalog,
    observations: [LocalizedMuscleLoadReceptorObservation]
  ) throws {
    for observation in observations {
      guard observation.attachmentCatalogFingerprint == attachmentCatalog.fingerprint,
        observation.event.timestamp <= commit.committedTimestamp,
        attachmentCatalog.attachment(
          forMuscleIdentifier: observation.attachment.muscleIdentifier
        ) == observation.attachment
      else {
        throw BrainRuntimeError.transaction(
          "committed body-load observation does not match its commit or attachment catalog"
        )
      }
    }

    var samples: [CommittedBodyLoadSample] = []
    samples.reserveCapacity(observations.count * 2)
    for observation in observations {
      let attachment = observation.attachment
      if attachment.firstBodyIdentifier == attachment.terminalBodyIdentifier {
        samples.append(
          CommittedBodyLoadSample(
            bodyIdentifier: attachment.firstBodyIdentifier,
            endpointRole: [.firstRouteEndpoint, .terminalRouteEndpoint],
            observation: observation
          )
        )
      } else {
        samples.append(
          CommittedBodyLoadSample(
            bodyIdentifier: attachment.firstBodyIdentifier,
            endpointRole: .firstRouteEndpoint,
            observation: observation
          )
        )
        samples.append(
          CommittedBodyLoadSample(
            bodyIdentifier: attachment.terminalBodyIdentifier,
            endpointRole: .terminalRouteEndpoint,
            observation: observation
          )
        )
      }
    }
    samples.sort(by: Self.precedes)
    try self.init(
      jointCommitFingerprint: commit.fingerprint,
      committedTimestamp: commit.committedTimestamp,
      brainGeneration: commit.brainGeneration,
      attachmentCatalogFingerprint: attachmentCatalog.fingerprint,
      bodyCount: attachmentCatalog.bodyCount,
      samples: samples,
      expectedFingerprint: nil
    )
  }

  public var affectedBodyIdentifiers: [UInt32] {
    var result: [UInt32] = []
    result.reserveCapacity(samples.count)
    for sample in samples where result.last != sample.bodyIdentifier {
      result.append(sample.bodyIdentifier)
    }
    return result
  }

  public var maximumAbsoluteMuscleForce: Float {
    samples.lazy.map(\.maximumAbsoluteMuscleForce).max() ?? 0
  }

  public func samples(forBodyIdentifier bodyIdentifier: UInt32)
    -> ArraySlice<CommittedBodyLoadSample>
  {
    let start = samples.firstIndex { $0.bodyIdentifier >= bodyIdentifier } ?? samples.endIndex
    let end =
      samples[start...].firstIndex { $0.bodyIdentifier > bodyIdentifier }
      ?? samples.endIndex
    return samples[start..<end]
  }

  private enum CodingKeys: String, CodingKey {
    case jointCommitFingerprint
    case committedTimestamp
    case brainGeneration
    case attachmentCatalogFingerprint
    case bodyCount
    case samples
    case fingerprint
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      jointCommitFingerprint: values.decode(UInt64.self, forKey: .jointCommitFingerprint),
      committedTimestamp: values.decode(BrainTimestamp.self, forKey: .committedTimestamp),
      brainGeneration: values.decode(UInt64.self, forKey: .brainGeneration),
      attachmentCatalogFingerprint: values.decode(
        UInt64.self,
        forKey: .attachmentCatalogFingerprint
      ),
      bodyCount: values.decode(UInt32.self, forKey: .bodyCount),
      samples: values.decode([CommittedBodyLoadSample].self, forKey: .samples),
      expectedFingerprint: values.decode(UInt64.self, forKey: .fingerprint)
    )
  }

  private init(
    jointCommitFingerprint: UInt64,
    committedTimestamp: BrainTimestamp,
    brainGeneration: UInt64,
    attachmentCatalogFingerprint: UInt64,
    bodyCount: UInt32,
    samples: [CommittedBodyLoadSample],
    expectedFingerprint: UInt64?
  ) throws {
    guard jointCommitFingerprint != 0, attachmentCatalogFingerprint != 0, bodyCount > 0,
      samples.allSatisfy({ sample in
        sample.bodyIdentifier < bodyCount
          && !sample.endpointRole.isEmpty
          && sample.maximumAbsoluteMuscleForce.isFinite
          && sample.maximumAbsoluteMuscleForce >= 0
          && sample.acceptedTimestamp <= committedTimestamp
          && sample.acceptedPhysicsStateFingerprint != 0
      }),
      samples.elementsEqual(samples.sorted(by: Self.precedes))
    else {
      throw BrainRuntimeError.transaction("committed body-load frame is invalid")
    }
    let fingerprint = Self.computeFingerprint(
      jointCommitFingerprint: jointCommitFingerprint,
      committedTimestamp: committedTimestamp,
      brainGeneration: brainGeneration,
      attachmentCatalogFingerprint: attachmentCatalogFingerprint,
      bodyCount: bodyCount,
      samples: samples
    )
    guard fingerprint != 0, expectedFingerprint == nil || expectedFingerprint == fingerprint else {
      throw BrainRuntimeError.transaction("committed body-load frame fingerprint drift")
    }
    self.jointCommitFingerprint = jointCommitFingerprint
    self.committedTimestamp = committedTimestamp
    self.brainGeneration = brainGeneration
    self.attachmentCatalogFingerprint = attachmentCatalogFingerprint
    self.bodyCount = bodyCount
    self.samples = samples
    self.fingerprint = fingerprint
  }

  private static func precedes(
    _ lhs: CommittedBodyLoadSample,
    _ rhs: CommittedBodyLoadSample
  ) -> Bool {
    if lhs.bodyIdentifier != rhs.bodyIdentifier {
      return lhs.bodyIdentifier < rhs.bodyIdentifier
    }
    if lhs.acceptedTimestamp != rhs.acceptedTimestamp {
      return lhs.acceptedTimestamp < rhs.acceptedTimestamp
    }
    if lhs.sourceMuscleIdentifier != rhs.sourceMuscleIdentifier {
      return lhs.sourceMuscleIdentifier < rhs.sourceMuscleIdentifier
    }
    if lhs.endpointRole.rawValue != rhs.endpointRole.rawValue {
      return lhs.endpointRole.rawValue < rhs.endpointRole.rawValue
    }
    if lhs.acceptedPhysicsStateFingerprint != rhs.acceptedPhysicsStateFingerprint {
      return lhs.acceptedPhysicsStateFingerprint < rhs.acceptedPhysicsStateFingerprint
    }
    return lhs.maximumAbsoluteMuscleForce.bitPattern
      < rhs.maximumAbsoluteMuscleForce.bitPattern
  }

  private static func computeFingerprint(
    jointCommitFingerprint: UInt64,
    committedTimestamp: BrainTimestamp,
    brainGeneration: UInt64,
    attachmentCatalogFingerprint: UInt64,
    bodyCount: UInt32,
    samples: [CommittedBodyLoadSample]
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    mix(formatVersion, into: &hash)
    mix(jointCommitFingerprint, into: &hash)
    mix(committedTimestamp.rawValue, into: &hash)
    mix(brainGeneration, into: &hash)
    mix(attachmentCatalogFingerprint, into: &hash)
    mix(bodyCount, into: &hash)
    mix(UInt32(samples.count), into: &hash)
    for sample in samples {
      mix(sample.bodyIdentifier, into: &hash)
      mix(sample.endpointRole.rawValue, into: &hash)
      mix(sample.sourceMuscleIdentifier, into: &hash)
      mix(sample.maximumAbsoluteMuscleForce.bitPattern, into: &hash)
      mix(sample.acceptedTimestamp.rawValue, into: &hash)
      mix(sample.acceptedPhysicsStateFingerprint, into: &hash)
    }
    return hash
  }

  private static func mix(_ value: UInt32, into hash: inout UInt64) {
    mix(UInt64(value), byteCount: 4, into: &hash)
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    mix(value, byteCount: 8, into: &hash)
  }

  private static func mix(_ value: UInt64, byteCount: Int, into hash: inout UInt64) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
      for byte in bytes.prefix(byteCount) {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }
}

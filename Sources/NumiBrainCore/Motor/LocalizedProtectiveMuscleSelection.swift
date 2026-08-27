import Foundation

@frozen
public struct LocalizedProtectiveMuscleFlags: OptionSet, Codable, Hashable, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let sharesLoadedEndpoint = Self(rawValue: 1 << 0)
  public static let overloadedSource = Self(rawValue: 1 << 1)
}

@frozen
public struct LocalizedProtectiveMuscleCandidate:
  Codable, Equatable, Hashable, Sendable
{
  public let motorChannelIndex: UInt32
  public let muscleIdentifier: UInt32
  public let flags: LocalizedProtectiveMuscleFlags
  public let sharedBodyIdentifiers: [UInt32]
  public let maximumObservedForce: Float
}

/// Deterministic mechanical neighborhood for one committed body-load frame.
/// Selection means only that a muscle route shares an affected endpoint. It
/// does not infer anatomical side, agonist/antagonist relation, or a safe
/// excitation direction.
@frozen
public struct LocalizedProtectiveMuscleSelection:
  Codable, Equatable, Hashable, Sendable
{
  public static let formatVersion: UInt32 = 1

  public let bodyLoadFrameFingerprint: UInt64
  public let attachmentCatalogFingerprint: UInt64
  public let motorProfileFingerprint: UInt64
  public let candidates: [LocalizedProtectiveMuscleCandidate]
  public let fingerprint: UInt64

  public init(
    bodyLoadFrame: CommittedBodyLoadFrame,
    attachmentCatalog: NumanXMuscleAttachmentCatalog,
    motorProfile: ProtectiveMotorProfile
  ) throws {
    guard bodyLoadFrame.attachmentCatalogFingerprint == attachmentCatalog.fingerprint
    else {
      throw BrainRuntimeError.transaction(
        "body-load frame and protective attachment catalog disagree"
      )
    }
    try attachmentCatalog.validate(profile: motorProfile)

    let affectedBodies = Set(bodyLoadFrame.affectedBodyIdentifiers)
    let sourceMuscles = Set(bodyLoadFrame.samples.map(\.sourceMuscleIdentifier))
    var candidates: [LocalizedProtectiveMuscleCandidate] = []
    candidates.reserveCapacity(motorProfile.channels.count)
    for (index, attachment) in attachmentCatalog.attachments.enumerated() {
      var sharedBodies: [UInt32] = []
      if affectedBodies.contains(attachment.firstBodyIdentifier) {
        sharedBodies.append(attachment.firstBodyIdentifier)
      }
      if attachment.terminalBodyIdentifier != attachment.firstBodyIdentifier,
        affectedBodies.contains(attachment.terminalBodyIdentifier)
      {
        sharedBodies.append(attachment.terminalBodyIdentifier)
      }
      sharedBodies.sort()
      guard !sharedBodies.isEmpty else { continue }

      let maximumObservedForce =
        sharedBodies.lazy
        .flatMap { bodyLoadFrame.samples(forBodyIdentifier: $0) }
        .map(\.maximumAbsoluteMuscleForce)
        .max() ?? 0
      var flags: LocalizedProtectiveMuscleFlags = [.sharesLoadedEndpoint]
      if sourceMuscles.contains(attachment.muscleIdentifier) {
        flags.insert(.overloadedSource)
      }
      candidates.append(
        LocalizedProtectiveMuscleCandidate(
          motorChannelIndex: UInt32(index),
          muscleIdentifier: attachment.muscleIdentifier,
          flags: flags,
          sharedBodyIdentifiers: sharedBodies,
          maximumObservedForce: maximumObservedForce
        )
      )
    }
    try self.init(
      bodyLoadFrameFingerprint: bodyLoadFrame.fingerprint,
      attachmentCatalogFingerprint: attachmentCatalog.fingerprint,
      motorProfileFingerprint: motorProfile.fingerprint,
      candidates: candidates,
      expectedFingerprint: nil
    )
  }

  public var selectedMuscleIdentifiers: [UInt32] {
    candidates.map(\.muscleIdentifier)
  }

  public var overloadedSourceMuscleIdentifiers: [UInt32] {
    candidates.lazy
      .filter { $0.flags.contains(.overloadedSource) }
      .map(\.muscleIdentifier)
  }

  private enum CodingKeys: String, CodingKey {
    case bodyLoadFrameFingerprint
    case attachmentCatalogFingerprint
    case motorProfileFingerprint
    case candidates
    case fingerprint
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      bodyLoadFrameFingerprint: values.decode(
        UInt64.self,
        forKey: .bodyLoadFrameFingerprint
      ),
      attachmentCatalogFingerprint: values.decode(
        UInt64.self,
        forKey: .attachmentCatalogFingerprint
      ),
      motorProfileFingerprint: values.decode(UInt64.self, forKey: .motorProfileFingerprint),
      candidates: values.decode(
        [LocalizedProtectiveMuscleCandidate].self,
        forKey: .candidates
      ),
      expectedFingerprint: values.decode(UInt64.self, forKey: .fingerprint)
    )
  }

  private init(
    bodyLoadFrameFingerprint: UInt64,
    attachmentCatalogFingerprint: UInt64,
    motorProfileFingerprint: UInt64,
    candidates: [LocalizedProtectiveMuscleCandidate],
    expectedFingerprint: UInt64?
  ) throws {
    guard bodyLoadFrameFingerprint != 0, attachmentCatalogFingerprint != 0,
      motorProfileFingerprint != 0,
      candidates.allSatisfy({ candidate in
        candidate.flags.contains(.sharesLoadedEndpoint)
          && !candidate.sharedBodyIdentifiers.isEmpty
          && candidate.sharedBodyIdentifiers
            == Array(Set(candidate.sharedBodyIdentifiers)).sorted()
          && candidate.maximumObservedForce.isFinite
          && candidate.maximumObservedForce >= 0
      }),
      candidates.elementsEqual(
        candidates.sorted { $0.motorChannelIndex < $1.motorChannelIndex }
      ),
      Set(candidates.map(\.motorChannelIndex)).count == candidates.count,
      Set(candidates.map(\.muscleIdentifier)).count == candidates.count
    else {
      throw BrainRuntimeError.transaction(
        "localized protective muscle selection is invalid"
      )
    }
    let fingerprint = Self.computeFingerprint(
      bodyLoadFrameFingerprint: bodyLoadFrameFingerprint,
      attachmentCatalogFingerprint: attachmentCatalogFingerprint,
      motorProfileFingerprint: motorProfileFingerprint,
      candidates: candidates
    )
    guard fingerprint != 0, expectedFingerprint == nil || expectedFingerprint == fingerprint else {
      throw BrainRuntimeError.transaction(
        "localized protective muscle selection fingerprint drift"
      )
    }
    self.bodyLoadFrameFingerprint = bodyLoadFrameFingerprint
    self.attachmentCatalogFingerprint = attachmentCatalogFingerprint
    self.motorProfileFingerprint = motorProfileFingerprint
    self.candidates = candidates
    self.fingerprint = fingerprint
  }

  private static func computeFingerprint(
    bodyLoadFrameFingerprint: UInt64,
    attachmentCatalogFingerprint: UInt64,
    motorProfileFingerprint: UInt64,
    candidates: [LocalizedProtectiveMuscleCandidate]
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    mix(formatVersion, into: &hash)
    mix(bodyLoadFrameFingerprint, into: &hash)
    mix(attachmentCatalogFingerprint, into: &hash)
    mix(motorProfileFingerprint, into: &hash)
    mix(UInt32(candidates.count), into: &hash)
    for candidate in candidates {
      mix(candidate.motorChannelIndex, into: &hash)
      mix(candidate.muscleIdentifier, into: &hash)
      mix(candidate.flags.rawValue, into: &hash)
      mix(UInt32(candidate.sharedBodyIdentifiers.count), into: &hash)
      for bodyIdentifier in candidate.sharedBodyIdentifiers {
        mix(bodyIdentifier, into: &hash)
      }
      mix(candidate.maximumObservedForce.bitPattern, into: &hash)
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

import Foundation

@frozen
public enum BrainSlowLossKind: UInt16, Codable, CaseIterable, Sendable {
  case observation = 1
  case belief = 2
  case world = 3
  case body = 4
  case agency = 5
  case event = 6
  case drive = 7
  case value = 8
  case risk = 9
  case policy = 10
  case option = 11
  case cerebellar = 12
  case episodic = 13
  case semantic = 14
  case procedural = 15
  case imitation = 16
  case route = 17
  case sparsity = 18
  case stability = 19
  case plasticity = 20
}

@frozen
public struct BrainSlowLossTerm: Codable, Equatable, Hashable, Sendable {
  public let kind: BrainSlowLossKind
  public let weight: Float
  public let value: Float

  public init(kind: BrainSlowLossKind, weight: Float, value: Float) throws {
    guard weight.isFinite, weight >= 0, value.isFinite else {
      throw BrainRuntimeError.invalidParameterVersion("learner loss term is invalid")
    }
    self.kind = kind
    self.weight = weight
    self.value = value
  }
}

/// Canonical output of one MLX batch-learning update. It binds the immutable
/// source cohort, every objective term, the candidate manifest, and the exact
/// parameter bytes that a successor Metal runtime will consume.
@frozen
public struct BrainLearnerUpdate: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 2

  public let formatVersion: UInt32
  public let parentParameterFingerprint: UInt64
  public let sourceBatchFingerprint: UInt64
  public let sourceMindCount: UInt32
  public let minimumSourceGeneration: UInt64
  public let sourceGeneration: UInt64
  public let candidateVersion: BrainParameterVersion
  public let sharedArtifact: BrainSharedParameterArtifact
  public let losses: [BrainSlowLossTerm]
  public let updateFingerprint: UInt64

  public init(
    parentVersion: BrainParameterVersion,
    sourceBatchFingerprint: UInt64,
    sourceGeneration: UInt64,
    sourceMindCount: UInt32 = 1,
    minimumSourceGeneration: UInt64? = nil,
    candidateVersion: BrainParameterVersion,
    sharedArtifact: BrainSharedParameterArtifact,
    losses: [BrainSlowLossTerm]
  ) throws {
    let canonicalLosses = losses.sorted { $0.kind.rawValue < $1.kind.rawValue }
    let minimumSourceGeneration = minimumSourceGeneration ?? sourceGeneration
    let (expectedSequence, sequenceOverflow) =
      parentVersion.sequence.addingReportingOverflow(1)
    guard sourceBatchFingerprint > 0, sourceMindCount > 0,
      minimumSourceGeneration > 0,
      minimumSourceGeneration <= sourceGeneration,
      !sequenceOverflow,
      candidateVersion.parentFingerprint == parentVersion.fingerprint,
      candidateVersion.sequence == expectedSequence,
      Set(canonicalLosses.map(\.kind)) == Set(BrainSlowLossKind.allCases),
      canonicalLosses.count == BrainSlowLossKind.allCases.count
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "learner update identity or objective coverage is invalid"
      )
    }
    try sharedArtifact.validate(parameterVersion: candidateVersion)
    var hash: UInt64 = 14_695_981_039_346_656_037
    for value in [
      UInt64(Self.formatVersion), parentVersion.fingerprint,
      sourceBatchFingerprint, UInt64(sourceMindCount), minimumSourceGeneration,
      sourceGeneration, candidateVersion.fingerprint,
      sharedArtifact.artifactFingerprint,
    ] {
      Self.mix(value, into: &hash)
    }
    for loss in canonicalLosses {
      Self.mix(UInt64(loss.kind.rawValue), into: &hash)
      Self.mix(UInt64(loss.weight.bitPattern), into: &hash)
      Self.mix(UInt64(loss.value.bitPattern), into: &hash)
    }
    self.formatVersion = Self.formatVersion
    self.parentParameterFingerprint = parentVersion.fingerprint
    self.sourceBatchFingerprint = sourceBatchFingerprint
    self.sourceMindCount = sourceMindCount
    self.minimumSourceGeneration = minimumSourceGeneration
    self.sourceGeneration = sourceGeneration
    self.candidateVersion = candidateVersion
    self.sharedArtifact = sharedArtifact
    self.losses = canonicalLosses
    self.updateFingerprint = hash
  }

  public func validate(parentVersion: BrainParameterVersion) throws {
    guard formatVersion == Self.formatVersion,
      parentParameterFingerprint == parentVersion.fingerprint
    else {
      throw BrainRuntimeError.invalidParameterVersion("learner update parent mismatch")
    }
    let rebuilt = try Self(
      parentVersion: parentVersion,
      sourceBatchFingerprint: sourceBatchFingerprint,
      sourceGeneration: sourceGeneration,
      sourceMindCount: sourceMindCount,
      minimumSourceGeneration: minimumSourceGeneration,
      candidateVersion: candidateVersion,
      sharedArtifact: sharedArtifact,
      losses: losses
    )
    guard rebuilt.updateFingerprint == updateFingerprint else {
      throw BrainRuntimeError.invalidParameterVersion(
        "learner update fingerprint mismatch"
      )
    }
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    var value = value.littleEndian
    withUnsafeBytes(of: &value) { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }
}

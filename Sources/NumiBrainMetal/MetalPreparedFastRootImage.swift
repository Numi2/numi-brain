import Foundation
import CryptoKit
import NumiBrainCore

/// Stable logical names from MetalTissueRuntime's existing fast-prepare witness ABI.
/// Addresses and ping-pong indices are never used to choose restored allocations.
enum PreparedFastSemantic {
  static let checkpointDomain: UInt64 = 0x4e42_4653_0000_0000
  static let rootManifest: UInt64 = 0x4e42_4653_ffff_ffff
  static func checkpoint(_ kind: MetalTissueCheckpointBufferKind) -> UInt64 {
    checkpointDomain | UInt64(kind.rawValue)
  }
}

public struct MetalPreparedFastSourceImage: Codable, Equatable, Sendable {
  public let semanticIdentifier: UInt64
  public let bytes: Data
  public init(semanticIdentifier: UInt64, bytes: Data) {
    self.semanticIdentifier = semanticIdentifier; self.bytes = bytes
  }
}

/// Captures the actual unpublished fast-root witness ranges, together with the last committed
/// checkpoint needed for explicit abort recovery. CPG/reflex/cerebellar/autonomic continuation is
/// imported into the cognitive arena by the native accepted-consequence path; this image must be
/// paired with that SAME root's BrainPreparedGPUImage, never used as a standalone complete brain.
public struct MetalPreparedFastRootImage: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let version: UInt32
  public let root: BrainPreparedRoot
  public let fastProgramFingerprint: UInt64
  public let base: MetalTissueCheckpoint
  public let sources: [MetalPreparedFastSourceImage]
  public let contentSHA256: String

  public init(root: BrainPreparedRoot, fastProgramFingerprint: UInt64,
    base: MetalTissueCheckpoint, sources: [MetalPreparedFastSourceImage],
    maximumPayloadBytes: Int = 536_870_912) throws {
    version = Self.formatVersion; self.root = root
    self.fastProgramFingerprint = fastProgramFingerprint; self.base = base
    self.sources = sources.sorted { $0.semanticIdentifier < $1.semanticIdentifier }
    try Self.validatePayloadBudget(base: base, sources: self.sources, limit: maximumPayloadBytes)
    contentSHA256 = try Self.digest(root: root, fastProgram: fastProgramFingerprint,
      base: base, sources: self.sources)
    _ = try validated(maximumPayloadBytes: maximumPayloadBytes)
  }

  @discardableResult
  public func validated(maximumPayloadBytes: Int = 536_870_912) throws -> Self {
    try Self.validatePayloadBudget(base: base, sources: sources, limit: maximumPayloadBytes)
    try base.validate()
    let token = try root.validatedToken()
    guard version == Self.formatVersion, fastProgramFingerprint > 0,
      base.environmentIdentifier == token.environmentIdentifier,
      UInt64(base.randomContext.episodeIdentifier) == token.episodeIdentifier,
      base.committedSchedulerGeneration == token.baseBrainGeneration,
      (base.committedSchedulerTime?.rawValue ?? 0) == token.committedTimestamp.rawValue,
      base.parameterVersionFingerprint == token.parameterVersionFingerprint,
      base.committedStep == token.randomCounterGeneration,
      contentSHA256 == (try Self.digest(root: root, fastProgram: fastProgramFingerprint,
        base: base, sources: sources)) else {
      throw TissueError.transaction("prepared fast image root, base or SHA-256 mismatch")
    }
    _ = try makeCandidateCheckpoint()
    return self
  }

  /// Canonical payload identity for BrainJointPreparedManifest is SHA-256 of these actual bytes,
  /// which is deliberately distinct from contentSHA256's domain-separated logical identity.
  public func encoded() throws -> Data {
    _ = try validated()
    return try Self.encode(self)
  }
  public static func decode(_ data: Data, maximumPayloadBytes: Int = 536_870_912) throws -> Self {
    guard maximumPayloadBytes > 0, maximumPayloadBytes <= 536_870_912,
      data.count <= maximumPayloadBytes * 2 + 1_048_576 else {
      throw TissueError.transaction("encoded fast recovery image exceeds budget")
    }
    let image = try JSONDecoder().decode(Self.self, from: data)
    return try image.validated(maximumPayloadBytes: maximumPayloadBytes)
  }
  public func participantArtifact() throws -> BrainPreparedParticipantArtifact {
    let bytes = try encoded(), token = try root.validatedToken()
    return try BrainPreparedParticipantArtifact(kind: .fastTissue,
      transactionFingerprint: root.fingerprint, baseGeneration: token.baseBrainGeneration,
      shadowGeneration: token.shadowGeneration, immutableProgramFingerprint: fastProgramFingerprint,
      payloadSHA256: Self.sha256(bytes), payloadBytes: UInt64(bytes.count))
  }

  var nativeSpeciesFingerprint: UInt64 { get throws { try manifestWords()[34] } }
  var nativeCompiledSpeciesFingerprint: UInt64 { get throws { try manifestWords()[35] } }
  var nativeSubstepFingerprint: UInt64 { get throws { try manifestWords()[6] } }

  /// Internal: target data may only be loaded into an isolated, unpublished replacement runtime.
  /// The public whole-brain recovery coordinator verifies the joint decision before exposing it.
  func stagedCheckpoint() throws -> MetalTissueCheckpoint {
    _ = try validated()
    return try makeCandidateCheckpoint()
  }

  private func makeCandidateCheckpoint() throws -> MetalTissueCheckpoint {
    let words = try manifestWords(), token = try root.validatedToken()
    let capacity = TissueDelayField.historyCapacity
    let nextPhysics = token.basePhysicsGeneration.addingReportingOverflow(1)
    let stepLimit = base.committedStep.addingReportingOverflow(UInt64(capacity))
    guard capacity > 0, capacity <= 32, !nextPhysics.overflow, !stepLimit.overflow,
      words[0] == 0x4e55_4d49_4641_5354, words[1] == 1, words[2] == 512,
      words[3] == UInt64(token.environmentIdentifier), words[4] == token.controlStepIdentifier,
      words[5] == token.fingerprint, words[6] > 0,
      words[7] == token.targetTimestamp.rawValue, words[8] == nextPhysics.partialValue,
      words[9] == token.shadowGeneration, words[10] < 3,
      words[11] <= UInt64(UInt32.max), words[12] > base.committedStep,
      words[12] <= stepLimit.partialValue, words[13] < 2, words[14] == words[13],
      words[15] == token.targetTimestamp.rawValue, words[16] == token.shadowGeneration,
      words[17] == UInt64(sources.count - 1), words[18] == UInt64(base.width),
      words[19] == UInt64(base.height), words[20] == UInt64(capacity),
      words[21] == base.parameterVersionFingerprint, words[22] == base.scheduleFingerprint,
      words[23] == base.regionalProgramFingerprint, words[24] == base.sharedArtifactFingerprint,
      words[25] == base.protectiveMotorProfileFingerprint, words[26] == base.attachmentCatalogFingerprint,
      words[27] == base.somaticSynergyCatalogFingerprint,
      words[28] == Self.fnv(Data(base.structureHash.utf8)),
      words[29] == Self.fnv(Data(base.delayFieldHash.utf8)),
      words[30] == Self.fnv(Data(base.connectomeHash.utf8)),
      words[31] == Self.fnv(Data(base.eventScheduleHash.utf8)),
      words[32] == Self.pack(base.randomContext.seed, base.randomContext.environmentIdentifier),
      words[33] == Self.pack(base.randomContext.episodeIdentifier, base.randomContext.moduleIdentifier),
      words[34] > 0, words[35] > 0,
      words[36] == Self.pack(base.bodyLoadFieldDynamics.persistenceMicroseconds, base.bodyLoadFieldDynamics.decayMicroseconds),
      words[37] == Self.pack(base.bodySchemaDynamics.forceScaleNewtons.bitPattern, base.bodySchemaDynamics.loadTimeConstantMicroseconds),
      words[38] == Self.pack(base.bodySchemaDynamics.initialVariance.bitPattern, base.bodySchemaDynamics.maximumVariance.bitPattern),
      words[39] == Self.pack(base.bodySchemaDynamics.processVariancePerSecond.bitPattern, base.bodySchemaDynamics.observationVariance.bitPattern),
      words[40] == Self.pack(base.bodySchemaDynamics.vulnerabilityGainPerSecond.bitPattern, base.bodySchemaDynamics.recoveryPerSecond.bitPattern),
      words[41] == UInt64(base.bodySchemaDynamics.uncertaintyRiskWeight.bitPattern),
      words[44] == token.randomCounterGeneration, words[45] == token.baseBrainGeneration,
      words[46] == token.basePhysicsGeneration, words[47] == token.episodeIdentifier,
      words[48..<63].allSatisfy({ $0 == 0 }) else {
      throw TissueError.transaction("native prepared-fast manifest does not bind its root and immutable model")
    }
    let mask = UInt32(words[11])
    let validMask: UInt32 = capacity == 32 ? .max : (UInt32(1) << UInt32(capacity)) - 1
    guard mask & ~validMask == 0 else { throw TissueError.transaction("invalid relay-history owner mask") }
    let expected = Dictionary(uniqueKeysWithValues: base.buffers.map { ($0.kind, $0.data.count) })
    let bySemantic = Dictionary(uniqueKeysWithValues: sources.map { ($0.semanticIdentifier, $0.bytes) })
    let allowed = Set(MetalTissueCheckpointBufferKind.allCases.map(PreparedFastSemantic.checkpoint))
      .union([PreparedFastSemantic.rootManifest])
    guard Set(bySemantic.keys).isSubset(of: allowed) else {
      throw TissueError.transaction("unknown prepared-fast source semantic")
    }
    var records: [MetalTissueCheckpointBuffer] = []
    for kind in MetalTissueCheckpointBufferKind.allCases {
      guard let byteCount = expected[kind] else { throw TissueError.transaction("incomplete base checkpoint") }
      let bytes = bySemantic[PreparedFastSemantic.checkpoint(kind)]
      if byteCount == 0 {
        guard bytes == nil else { throw TissueError.transaction("unexpected zero-length source") }
        records.append(.init(kind: kind, data: Data()))
      } else {
        guard let bytes, bytes.count == byteCount else {
          throw TissueError.transaction("missing or resized native fast source: \(kind)")
        }
        records.append(.init(kind: kind, data: bytes))
      }
    }
    guard let timestampBytes = bySemantic[PreparedFastSemantic.checkpoint(.relayHistoryTimestamps)],
      timestampBytes.count == 2 * capacity * MemoryLayout<UInt64>.stride else {
      throw TissueError.transaction("relay timestamp planes do not match the native layout")
    }
    var selected: [UInt64] = []
    selected.reserveCapacity(capacity)
    for slot in 0..<capacity {
      let plane = Int((mask >> UInt32(slot)) & 1)
      let value = try Self.word(timestampBytes, index: plane * capacity + slot)
      guard value <= token.targetTimestamp.rawValue else { throw TissueError.transaction("future relay history") }
      selected.append(value)
    }
    guard selected[Int(words[12] % UInt64(capacity))] == token.targetTimestamp.rawValue else {
      throw TissueError.transaction("prepared relay history did not reach the root target")
    }
    return try MetalTissueCheckpoint(width: base.width, height: base.height,
      environmentIdentifier: base.environmentIdentifier, randomContext: base.randomContext,
      committedStep: words[12], committedSchedulerTime: token.targetTimestamp,
      committedSchedulerGeneration: token.shadowGeneration, committedHistoryOwnerMask: mask,
      committedRelayHistoryTimestamps: selected, parameterVersionFingerprint: base.parameterVersionFingerprint,
      scheduleFingerprint: base.scheduleFingerprint, regionalProgramFingerprint: base.regionalProgramFingerprint,
      sharedArtifactFingerprint: base.sharedArtifactFingerprint,
      protectiveMotorProfileFingerprint: base.protectiveMotorProfileFingerprint,
      attachmentCatalogFingerprint: base.attachmentCatalogFingerprint,
      somaticSynergyCatalogFingerprint: base.somaticSynergyCatalogFingerprint,
      structureHash: base.structureHash, delayFieldHash: base.delayFieldHash,
      connectomeHash: base.connectomeHash, eventScheduleHash: base.eventScheduleHash,
      bodyLoadFieldDynamics: base.bodyLoadFieldDynamics, bodySchemaDynamics: base.bodySchemaDynamics,
      buffers: records)
  }

  private func manifestWords() throws -> [UInt64] {
    guard sources.count > 1, sources.count <= MetalTissueCheckpointBufferKind.allCases.count + 1,
      zip(sources, sources.dropFirst()).allSatisfy({ $0.semanticIdentifier < $1.semanticIdentifier }),
      let data = sources.first(where: { $0.semanticIdentifier == PreparedFastSemantic.rootManifest })?.bytes,
      data.count == 512 else { throw TissueError.transaction("missing, duplicate or oversized fast manifest") }
    let words = try (0..<64).map { try Self.word(data, index: $0) }
    guard Self.fnv(Data(data.prefix(504))) == words[63] else {
      throw TissueError.transaction("native fast manifest checksum mismatch")
    }
    return words
  }

  private static func validatePayloadBudget(base: MetalTissueCheckpoint,
    sources: [MetalPreparedFastSourceImage], limit: Int) throws {
    guard limit > 0, limit <= 536_870_912,
      base.buffers.count == MetalTissueCheckpointBufferKind.allCases.count,
      sources.count > 1, sources.count <= MetalTissueCheckpointBufferKind.allCases.count + 1 else {
      throw TissueError.transaction("prepared fast payload budget or source count")
    }
    var count = 0
    for bytes in base.buffers.map(\.data) + sources.map(\.bytes) {
      guard bytes.count <= limit - count else { throw TissueError.transaction("prepared fast payload exceeds byte budget") }
      count += bytes.count
    }
  }
  private struct Payload: Encodable {
    let domain = "NumiBrain.prepared-fast-root.v1"
    let root: BrainPreparedRoot
    let fastProgram: UInt64
    let base: MetalTissueCheckpoint
    let sources: [MetalPreparedFastSourceImage]
  }
  private static func digest(root: BrainPreparedRoot, fastProgram: UInt64,
    base: MetalTissueCheckpoint, sources: [MetalPreparedFastSourceImage]) throws -> String {
    sha256(try encode(Payload(root: root, fastProgram: fastProgram, base: base, sources: sources)))
  }
  static func encode<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
  }
  static func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
  static func word(_ data: Data, index: Int) throws -> UInt64 {
    guard index >= 0, data.count >= 8, index <= (data.count - 8) / 8 else {
      throw TissueError.transaction("truncated little-endian recovery word")
    }
    return data.withUnsafeBytes { UInt64(littleEndian: $0.loadUnaligned(fromByteOffset: index * 8, as: UInt64.self)) }
  }
  private static func fnv(_ bytes: Data) -> UInt64 {
    var value: UInt64 = 14_695_981_039_346_656_037
    for byte in bytes { value = (value ^ UInt64(byte)) &* 1_099_511_628_211 }
    return value == 0 ? 14_695_981_039_346_656_037 : value
  }
  private static func pack(_ low: UInt32, _ high: UInt32) -> UInt64 { UInt64(low) | UInt64(high) << 32 }
}

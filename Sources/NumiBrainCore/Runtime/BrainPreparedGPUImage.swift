import Foundation
import CryptoKit

/// Serializable logical root. GPU addresses and arena buffer indices are never persistence IDs.
public struct BrainPreparedRoot: Codable, Equatable, Sendable {
  public let environment: UInt32
  public let episode: UInt64
  public let controlStep: UInt64
  public let parameters: UInt64
  public let baseBrainGeneration: UInt64
  public let basePhysicsGeneration: UInt64
  public let committedMicroseconds: UInt64
  public let targetMicroseconds: UInt64
  public let randomCounterGeneration: UInt64
  public let fingerprint: UInt64

  public init(_ root: BrainJointTransactionToken) {
    environment = root.environmentIdentifier; episode = root.episodeIdentifier
    controlStep = root.controlStepIdentifier; parameters = root.parameterVersionFingerprint
    baseBrainGeneration = root.baseBrainGeneration; basePhysicsGeneration = root.basePhysicsGeneration
    committedMicroseconds = root.committedTimestamp.rawValue; targetMicroseconds = root.targetTimestamp.rawValue
    randomCounterGeneration = root.randomCounterGeneration; fingerprint = root.fingerprint
  }
  public func validatedToken() throws -> BrainJointTransactionToken {
    let token = try BrainJointTransactionToken(environmentIdentifier: environment,
      episodeIdentifier: episode, controlStepIdentifier: controlStep,
      parameterVersionFingerprint: parameters, baseBrainGeneration: baseBrainGeneration,
      basePhysicsGeneration: basePhysicsGeneration,
      committedTimestamp: BrainTimestamp(microseconds: committedMicroseconds),
      targetTimestamp: BrainTimestamp(microseconds: targetMicroseconds),
      randomCounterGeneration: randomCounterGeneration)
    guard token.fingerprint == fingerprint else {
      throw BrainRuntimeError.transaction("prepared root fingerprint mismatch")
    }
    return token
  }
}

/// Full native arena before publication. Persistent memory is the BASE memory; shadowJournal
/// contains unapplied mutations. Recovery MUST NOT apply it before the joint commit decision.
/// This image is limited to the complete agent-state arena; fast tissue/physics own their images.
public struct BrainPreparedGPUImage: Codable, Equatable, Sendable {
  public static let currentVersion: UInt32 = 1
  public let version: UInt32
  public let root: BrainPreparedRoot
  public let cachedDecisionFingerprint: UInt64
  public let acceptedPhysicsTokenFingerprint: UInt64
  public let hotLayoutFingerprint: UInt64
  public let memoryLayoutFingerprint: UInt64
  public let baseHotState: Data
  public let shadowHotState: Data
  public let basePersistentMemory: Data
  public let shadowJournal: Data
  public let sha256: String

  public init(root: BrainPreparedRoot, cachedDecisionFingerprint: UInt64,
              acceptedPhysicsTokenFingerprint: UInt64, hotLayoutFingerprint: UInt64,
              memoryLayoutFingerprint: UInt64, baseHotState: Data, shadowHotState: Data,
              basePersistentMemory: Data, shadowJournal: Data,
              maximumBytes: Int = 536_870_912) throws {
    version = Self.currentVersion; self.root = root
    self.cachedDecisionFingerprint = cachedDecisionFingerprint
    self.acceptedPhysicsTokenFingerprint = acceptedPhysicsTokenFingerprint
    self.hotLayoutFingerprint = hotLayoutFingerprint; self.memoryLayoutFingerprint = memoryLayoutFingerprint
    self.baseHotState = baseHotState; self.shadowHotState = shadowHotState
    self.basePersistentMemory = basePersistentMemory; self.shadowJournal = shadowJournal
    sha256 = Self.digest(version: Self.currentVersion, root: root,
      decision: cachedDecisionFingerprint, physics: acceptedPhysicsTokenFingerprint,
      hotLayout: hotLayoutFingerprint, memoryLayout: memoryLayoutFingerprint,
      chunks: [baseHotState, shadowHotState, basePersistentMemory, shadowJournal])
    _ = try validated(maximumBytes: maximumBytes)
  }

  public func validated(maximumBytes: Int = 536_870_912) throws -> Self {
    let token = try root.validatedToken()
    guard version == Self.currentVersion, cachedDecisionFingerprint > 0,
      acceptedPhysicsTokenFingerprint > 0, hotLayoutFingerprint > 0, memoryLayoutFingerprint > 0,
      maximumBytes > 0, baseHotState.count == shadowHotState.count,
      !baseHotState.isEmpty, !basePersistentMemory.isEmpty, shadowJournal.count >= 48,
      [baseHotState, shadowHotState, basePersistentMemory, shadowJournal].allSatisfy({ $0.count % 4 == 0 })
    else { throw BrainRuntimeError.transaction("incomplete prepared GPU image") }
    var total = 0
    for chunk in [baseHotState, shadowHotState, basePersistentMemory, shadowJournal] {
      guard chunk.count <= maximumBytes - total else { throw BrainRuntimeError.capacity("prepared image byte budget") }
      total += chunk.count
    }
    guard sha256 == Self.digest(version: version, root: root, decision: cachedDecisionFingerprint,
      physics: acceptedPhysicsTokenFingerprint, hotLayout: hotLayoutFingerprint,
      memoryLayout: memoryLayoutFingerprint,
      chunks: [baseHotState, shadowHotState, basePersistentMemory, shadowJournal]) else {
      throw BrainRuntimeError.transaction("prepared GPU image SHA-256 mismatch")
    }
    try validateJournal(base: token.baseBrainGeneration, shadow: token.shadowGeneration)
    return self
  }

  private func validateJournal(base: UInt64, shadow: UInt64) throws {
    func u32(_ offset: Int) -> UInt32 {
      shadowJournal.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self)) }
    }
    func u64(_ offset: Int) -> UInt64 {
      shadowJournal.withUnsafeBytes { UInt64(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self)) }
    }
    let count = Int(u32(4)), capacity = Int(u32(8))
    guard u32(0) == 1, u32(12) == 1, capacity == (shadowJournal.count - 48) / 64,
      count <= capacity, u64(16) == base, u64(24) == shadow,
      u64(32) == UInt64(basePersistentMemory.count), u64(40) == 0 else {
      throw BrainRuntimeError.transaction("prepared mutation journal header/generation/status")
    }
    var ranges: [(UInt64, UInt64)] = []
    ranges.reserveCapacity(count)
    for index in 0..<count {
      let offset = 48 + index * 64
      let destination = u64(offset), length = UInt64(u32(offset + 32))
      guard u64(offset + 8) == shadow, length > 0, length <= 16,
        length.isMultiple(of: 4), destination.isMultiple(of: 4),
        destination <= UInt64(basePersistentMemory.count),
        length <= UInt64(basePersistentMemory.count) - destination,
        (1...11).contains(u32(offset + 36)) else {
        throw BrainRuntimeError.transaction("prepared journal entry is invalid")
      }
      ranges.append((destination, destination + length))
    }
    ranges.sort { $0.0 < $1.0 }
    for (a, b) in zip(ranges, ranges.dropFirst()) where a.1 > b.0 {
      throw BrainRuntimeError.transaction("overlapping prepared memory mutations are not replay-safe")
    }
  }

  private static func digest(version: UInt32, root: BrainPreparedRoot, decision: UInt64,
    physics: UInt64, hotLayout: UInt64, memoryLayout: UInt64, chunks: [Data]) -> String {
    var hash = SHA256()
    hash.update(data: Data("NumiBrain.prepared-gpu-image.v1\0".utf8))
    let scalars: [UInt64] = [UInt64(version), UInt64(root.environment), root.episode, root.controlStep,
      root.parameters, root.baseBrainGeneration, root.basePhysicsGeneration, root.committedMicroseconds,
      root.targetMicroseconds, root.randomCounterGeneration, root.fingerprint, decision, physics,
      hotLayout, memoryLayout]
    for value in scalars {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { hash.update(bufferPointer: $0) }
    }
    for chunk in chunks {
      var length = UInt64(chunk.count).littleEndian
      withUnsafeBytes(of: &length) { hash.update(bufferPointer: $0) }
      hash.update(data: chunk)
    }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
  }
}

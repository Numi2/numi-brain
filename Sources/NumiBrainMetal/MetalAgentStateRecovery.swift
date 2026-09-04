import Foundation
@preconcurrency import Metal
import NumiBrainCore

/// Public, byte-exact committed Metal arena image for process-restart recovery. This is an
/// orchestration artifact, not a hot-loop representation. FNV fingerprints catch accidental
/// corruption; the outer recovery store remains responsible for durable ordering and stronger hashes.
@available(macOS 26.0, *)
public struct MetalAgentStateRecoveryImage: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let generation: UInt64
  public let hotState: Data
  public let persistentMemory: Data
  public let hotFingerprint: UInt64
  public let memoryFingerprint: UInt64

  public init(generation: UInt64, hotState: Data, persistentMemory: Data) throws {
    guard !hotState.isEmpty, !persistentMemory.isEmpty else {
      throw TissueError.transaction("recovery image cannot contain empty arenas")
    }
    formatVersion = Self.formatVersion
    self.generation = generation; self.hotState = hotState; self.persistentMemory = persistentMemory
    hotFingerprint = Self.hash(hotState); memoryFingerprint = Self.hash(persistentMemory)
  }

  public func validated(maximumBytes: Int = 512 * 1024 * 1024) throws -> Self {
    guard formatVersion == Self.formatVersion, maximumBytes > 0,
      !hotState.isEmpty, !persistentMemory.isEmpty,
      hotState.count <= maximumBytes, persistentMemory.count <= maximumBytes,
      hotFingerprint == Self.hash(hotState), memoryFingerprint == Self.hash(persistentMemory)
    else { throw TissueError.transaction("Metal recovery image failed integrity/capacity validation") }
    return self
  }

  private static func hash(_ data: Data) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in data { hash ^= UInt64(byte); hash &*= 1_099_511_628_211 }
    return hash
  }
}

@available(macOS 26.0, *)
public extension MetalAgentStateRuntime {
  /// Synchronizes the committed generation to CPU storage only at a recovery/checkpoint boundary.
  func makeRecoveryImage() throws -> MetalAgentStateRecoveryImage {
    let payload = try snapshotCommittedState()
    return try MetalAgentStateRecoveryImage(generation: payload.generation,
      hotState: payload.hotState, persistentMemory: payload.persistentMemory)
  }

  /// Restores both hot generations and persistent memory, then marks the exact generation committed.
  /// The runtime's existing Metal restore kernel validates byte dimensions against the compiled arena.
  func restoreRecoveryImage(_ image: MetalAgentStateRecoveryImage) throws {
    let image = try image.validated()
    try restoreCommittedState(from: CheckpointPayload(generation: image.generation,
      hotState: image.hotState, persistentMemory: image.persistentMemory))
  }
}

/// Pairs semantic state identity with the device-resident arena image. Both generations and immutable
/// parameter fingerprints must agree before an embedding runtime can resume a joint transaction.
@available(macOS 26.0, *)
public struct BrainMetalRecoveryBundle: Codable, Equatable, Sendable {
  public let semantic: BrainDurablePreparedGeneration
  public let metal: MetalAgentStateRecoveryImage
  public init(semantic: BrainDurablePreparedGeneration, metal: MetalAgentStateRecoveryImage) throws {
    let semantic = try semantic.validated(); let metal = try metal.validated()
    guard semantic.shadowGeneration == metal.generation else {
      throw TissueError.transaction("semantic and Metal recovery generations diverge")
    }
    self.semantic = semantic; self.metal = metal
  }
}

import Foundation
import CryptoKit

/// Exact neural-state snapshot at a root boundary, never a claim about the
/// biological source's activity. Data is canonical little-endian FP32.
public struct ConnectomeCheckpoint: Codable, Equatable, Sendable {
  public let version: UInt32
  public let graphFingerprint: UInt64
  public let topologyFingerprint: UInt64
  public let programFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  public let environmentIdentifier: UInt32
  public let episodeIdentifier: UInt64
  public let generation: UInt64
  public let timestampMicroseconds: UInt64
  public let activity: Data
  public let sha256: String

  public init(graphFingerprint: UInt64, topologyFingerprint: UInt64,
    programFingerprint: UInt64, parameterVersionFingerprint: UInt64,
    environmentIdentifier: UInt32, episodeIdentifier: UInt64,
    generation: UInt64, timestampMicroseconds: UInt64, activity: Data) throws {
    version = 1; self.graphFingerprint = graphFingerprint
    self.topologyFingerprint = topologyFingerprint; self.programFingerprint = programFingerprint
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.environmentIdentifier = environmentIdentifier; self.episodeIdentifier = episodeIdentifier
    self.generation = generation; self.timestampMicroseconds = timestampMicroseconds
    self.activity = activity
    sha256 = Self.digest(graph: graphFingerprint, topology: topologyFingerprint,
      program: programFingerprint, parameters: parameterVersionFingerprint,
      environment: environmentIdentifier, episode: episodeIdentifier, generation: generation,
      timestamp: timestampMicroseconds, activity: activity)
    try validate()
  }

  public func validate(maximumBytes: Int = 67_108_864) throws {
    guard version == 1, graphFingerprint != 0, topologyFingerprint != 0,
      programFingerprint != 0, parameterVersionFingerprint != 0,
      !activity.isEmpty, activity.count <= maximumBytes, activity.count.isMultiple(of: 4),
      sha256 == Self.digest(graph: graphFingerprint, topology: topologyFingerprint,
        program: programFingerprint, parameters: parameterVersionFingerprint,
        environment: environmentIdentifier, episode: episodeIdentifier, generation: generation,
        timestamp: timestampMicroseconds, activity: activity) else {
      throw ConnectomeError.invalid("neural checkpoint identity, size or SHA-256 mismatch")
    }
    try activity.withUnsafeBytes { bytes in
      for offset in stride(from: 0, to: bytes.count, by: 4) {
        let bits = UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
        let value = Float(bitPattern: bits)
        guard value.isFinite, abs(value) <= 1 else {
          throw ConnectomeError.invalid("neural checkpoint activity is outside its finite model domain")
        }
      }
    }
  }

  /// Called only by the complete checkpoint's direct-successor migration.
  /// The operator and decoder identity is deliberately preserved.
  public func rebinding(parameterVersionFingerprint: UInt64) throws -> Self {
    try validate()
    return try Self(graphFingerprint: graphFingerprint, topologyFingerprint: topologyFingerprint,
      programFingerprint: programFingerprint, parameterVersionFingerprint: parameterVersionFingerprint,
      environmentIdentifier: environmentIdentifier, episodeIdentifier: episodeIdentifier,
      generation: generation, timestampMicroseconds: timestampMicroseconds, activity: activity)
  }

  private static func digest(graph: UInt64, topology: UInt64, program: UInt64,
    parameters: UInt64, environment: UInt32, episode: UInt64, generation: UInt64,
    timestamp: UInt64, activity: Data) -> String {
    var hash = SHA256()
    hash.update(data: Data("NumiBrain.connectome-checkpoint.v1\0".utf8))
    for value in [graph, topology, program, parameters, UInt64(environment), episode,
      generation, timestamp, UInt64(activity.count)] {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { hash.update(bufferPointer: $0) }
    }
    hash.update(data: activity)
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
  }
}

/// Two generations plus the exact cached decision output. A restored prepared
/// root can either commit the candidate or discard it without recomputation.
public struct ConnectomePreparedState: Codable, Equatable, Sendable {
  public let base: ConnectomeCheckpoint
  public let candidate: ConnectomeCheckpoint
  public let descending: Data
  public let descendingSHA256: String

  public init(base: ConnectomeCheckpoint, candidate: ConnectomeCheckpoint,
    descending: Data, root: BrainJointTransactionToken) throws {
    self.base = base; self.candidate = candidate; self.descending = descending
    descendingSHA256 = SHA256.hash(data: descending).map { String(format: "%02x", $0) }.joined()
    try validate(root: root)
  }

  public func validate(root: BrainJointTransactionToken) throws {
    try base.validate(); try candidate.validate()
    guard base.graphFingerprint == candidate.graphFingerprint,
      base.topologyFingerprint == candidate.topologyFingerprint,
      base.programFingerprint == candidate.programFingerprint,
      base.parameterVersionFingerprint == root.parameterVersionFingerprint,
      candidate.parameterVersionFingerprint == root.parameterVersionFingerprint,
      base.environmentIdentifier == root.environmentIdentifier,
      candidate.environmentIdentifier == root.environmentIdentifier,
      base.episodeIdentifier == root.episodeIdentifier, candidate.episodeIdentifier == root.episodeIdentifier,
      base.generation == root.baseBrainGeneration, candidate.generation == root.shadowGeneration,
      base.timestampMicroseconds == root.committedTimestamp.rawValue,
      candidate.timestampMicroseconds == root.targetTimestamp.rawValue,
      base.activity.count == candidate.activity.count,
      !descending.isEmpty, descending.count <= 256*4, descending.count.isMultiple(of: 4),
      descendingSHA256 == SHA256.hash(data: descending).map({ String(format: "%02x", $0) }).joined()
    else { throw ConnectomeError.invalid("prepared neural generations do not describe this root") }
    try descending.withUnsafeBytes { bytes in
      for offset in stride(from: 0, to: bytes.count, by: 4) {
        let value = Float(bitPattern: UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self)))
        guard value.isFinite, abs(value) <= 1 else { throw ConnectomeError.invalid("invalid cached descending output") }
      }
    }
  }

  /// Appended as explicitly framed chunks to the existing prepared-image hash.
  public var digestChunks: [Data] {
    [Data(base.sha256.utf8), base.activity, Data(candidate.sha256.utf8),
      candidate.activity, Data(descendingSHA256.utf8), descending]
  }
}

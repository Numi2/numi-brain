import Foundation
import NumiBrainCore

/// Complete committed NumiBrain state. The envelope makes the cognitive mind
/// and fast nervous-system state inseparable and binds both to the exact
/// external NumanX checkpoint that owns the corresponding physical body.
@frozen
public struct MetalNumiBrainCheckpoint: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let cognitiveState: MetalBrainCheckpoint
  public let fastTissueState: MetalTissueCheckpoint
  public let checkpointFingerprint: UInt64

  public init(
    cognitiveState: MetalBrainCheckpoint,
    fastTissueState: MetalTissueCheckpoint
  ) throws {
    self.formatVersion = Self.formatVersion
    self.cognitiveState = cognitiveState
    self.fastTissueState = fastTissueState
    self.checkpointFingerprint = Self.contentFingerprint(
      cognitiveState: cognitiveState,
      fastTissueState: fastTissueState
    )
    try validate()
  }

  public var committedGeneration: UInt64 {
    cognitiveState.committedGeneration
  }

  public var committedTimestamp: BrainTimestamp {
    cognitiveState.committedTimestamp
  }

  public var environmentIdentifier: UInt32 {
    cognitiveState.environmentIdentifier
  }

  public var episodeIdentifier: UInt64 {
    cognitiveState.episodeIdentifier
  }

  public var controlStepIdentifier: UInt64 {
    cognitiveState.controlStepIdentifier
  }

  public var physicalCheckpointFingerprint: UInt64 {
    cognitiveState.physicalCheckpointFingerprint
  }

  public func validate() throws {
    try cognitiveState.validate()
    try fastTissueState.validate()
    let fastTimestamp = fastTissueState.committedSchedulerTime
      ?? BrainTimestamp(microseconds: 0)
    guard formatVersion == Self.formatVersion,
      cognitiveState.environmentIdentifier == fastTissueState.environmentIdentifier,
      cognitiveState.episodeIdentifier
        == UInt64(fastTissueState.randomContext.episodeIdentifier),
      cognitiveState.committedGeneration
        == fastTissueState.committedSchedulerGeneration,
      cognitiveState.committedTimestamp == fastTimestamp,
      cognitiveState.parameterVersionFingerprint
        == fastTissueState.parameterVersionFingerprint,
      cognitiveState.regionalProgramFingerprint
        == fastTissueState.regionalProgramFingerprint,
      cognitiveState.scheduleFingerprint == fastTissueState.scheduleFingerprint,
      cognitiveState.physicalCheckpointFingerprint > 0,
      checkpointFingerprint == Self.contentFingerprint(
        cognitiveState: cognitiveState,
        fastTissueState: fastTissueState
      )
    else {
      throw TissueError.transaction(
        "complete brain checkpoint generations or immutable identities diverge"
      )
    }
  }

  public func encoded() throws -> Data {
    try validate()
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    return try encoder.encode(self)
  }

  public static func decode(_ data: Data) throws -> Self {
    let checkpoint = try PropertyListDecoder().decode(Self.self, from: data)
    try checkpoint.validate()
    return checkpoint
  }

  public func write(
    to url: URL,
    options: Data.WritingOptions = [.atomic]
  ) throws {
    try encoded().write(to: url, options: options)
  }

  public static func read(from url: URL) throws -> Self {
    try decode(Data(contentsOf: url, options: [.mappedIfSafe]))
  }

  private static func contentFingerprint(
    cognitiveState: MetalBrainCheckpoint,
    fastTissueState: MetalTissueCheckpoint
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for value in [
      UInt64(Self.formatVersion),
      cognitiveState.checkpointFingerprint,
      fastTissueState.checkpointFingerprint,
      cognitiveState.physicalCheckpointFingerprint,
      cognitiveState.committedGeneration,
      cognitiveState.committedTimestamp.rawValue,
      UInt64(cognitiveState.environmentIdentifier),
      cognitiveState.episodeIdentifier,
      cognitiveState.controlStepIdentifier,
    ] {
      var value = value.littleEndian
      withUnsafeBytes(of: &value) { bytes in
        for byte in bytes {
          hash ^= UInt64(byte)
          hash &*= 1_099_511_628_211
        }
      }
    }
    return hash
  }
}

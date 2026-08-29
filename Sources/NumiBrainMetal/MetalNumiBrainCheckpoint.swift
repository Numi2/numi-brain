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
    let fastTimestamp =
      fastTissueState.committedSchedulerTime
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
      checkpointFingerprint
        == Self.contentFingerprint(
          cognitiveState: cognitiveState,
          fastTissueState: fastTissueState
        )
    else {
      throw TissueError.transaction(
        "complete brain checkpoint generations or immutable identities diverge"
      )
    }
  }

  /// Creates a new complete-state envelope for a direct successor parameter
  /// publication. Mutable mind, memory, scheduler, plasticity, and tissue bytes
  /// are preserved exactly; only the immutable runtime binding changes. The
  /// parent checkpoint remains valid for deterministic replay under its own
  /// version, while the returned checkpoint starts the successor cohort from
  /// the same committed embodied history.
  public func migrated(
    from parentVersion: BrainParameterVersion,
    to successorPublication: BrainParameterPublication
  ) throws -> Self {
    try validate()
    let successor = successorPublication.version
    let (expectedSequence, overflow) = parentVersion.sequence.addingReportingOverflow(1)
    let parentTissue = parentVersion.components.first(where: {
      $0.kind == .tissueDynamics
    })
    let successorTissue = successor.components.first(where: {
      $0.kind == .tissueDynamics
    })
    let parentRegional = parentVersion.components.first(where: {
      $0.kind == .regionalOperator
    })
    let successorRegional = successor.components.first(where: {
      $0.kind == .regionalOperator
    })
    guard !overflow,
      cognitiveState.parameterVersionFingerprint == parentVersion.fingerprint,
      fastTissueState.parameterVersionFingerprint == parentVersion.fingerprint,
      successor.parentFingerprint == parentVersion.fingerprint,
      successor.sequence == expectedSequence,
      successor.scheduleFingerprint == parentVersion.scheduleFingerprint,
      successor.regionalShapeFingerprint == parentVersion.regionalShapeFingerprint,
      successor.regionalProgramFingerprint == parentVersion.regionalProgramFingerprint,
      successor.scheduleFingerprint == cognitiveState.scheduleFingerprint,
      successor.regionalProgramFingerprint == cognitiveState.regionalProgramFingerprint,
      parentTissue == successorTissue,
      parentRegional == successorRegional,
      successorPublication.learnerUpdateFingerprint > 0,
      successorPublication.sourceBatchFingerprint > 0,
      successorPublication.sourceMindCount > 0,
      successorPublication.minimumSourceGeneration > 0,
      successorPublication.minimumSourceGeneration
        <= successorPublication.sourceGeneration,
      successorPublication.sourceGeneration > 0
    else {
      throw TissueError.transaction(
        "state migration requires a shape-compatible direct learner successor"
      )
    }
    try successorPublication.sharedArtifact.validate(parameterVersion: successor)

    let migratedCognitive = try MetalBrainCheckpoint(
      committedGeneration: cognitiveState.committedGeneration,
      committedTimestamp: cognitiveState.committedTimestamp,
      environmentIdentifier: cognitiveState.environmentIdentifier,
      episodeIdentifier: cognitiveState.episodeIdentifier,
      controlStepIdentifier: cognitiveState.controlStepIdentifier,
      speciesTemplateFingerprint: cognitiveState.speciesTemplateFingerprint,
      regionalProgramFingerprint: cognitiveState.regionalProgramFingerprint,
      scheduleFingerprint: cognitiveState.scheduleFingerprint,
      parameterVersionFingerprint: successor.fingerprint,
      hotLayoutFingerprint: cognitiveState.hotLayoutFingerprint,
      memoryLayoutFingerprint: cognitiveState.memoryLayoutFingerprint,
      physicalCheckpointFingerprint: cognitiveState.physicalCheckpointFingerprint,
      hotState: cognitiveState.hotState,
      persistentMemory: cognitiveState.persistentMemory
    )
    let migratedFast = try MetalTissueCheckpoint(
      width: fastTissueState.width,
      height: fastTissueState.height,
      environmentIdentifier: fastTissueState.environmentIdentifier,
      randomContext: fastTissueState.randomContext,
      committedStep: fastTissueState.committedStep,
      committedSchedulerTime: fastTissueState.committedSchedulerTime,
      committedSchedulerGeneration: fastTissueState.committedSchedulerGeneration,
      committedHistoryOwnerMask: fastTissueState.committedHistoryOwnerMask,
      committedRelayHistoryTimestamps:
        fastTissueState.committedRelayHistoryTimestamps,
      parameterVersionFingerprint: successor.fingerprint,
      scheduleFingerprint: fastTissueState.scheduleFingerprint,
      regionalProgramFingerprint: fastTissueState.regionalProgramFingerprint,
      sharedArtifactFingerprint:
        successorPublication.sharedArtifact.artifactFingerprint,
      protectiveMotorProfileFingerprint:
        fastTissueState.protectiveMotorProfileFingerprint,
      attachmentCatalogFingerprint: fastTissueState.attachmentCatalogFingerprint,
      structureHash: fastTissueState.structureHash,
      delayFieldHash: fastTissueState.delayFieldHash,
      connectomeHash: fastTissueState.connectomeHash,
      eventScheduleHash: fastTissueState.eventScheduleHash,
      bodyLoadFieldDynamics: fastTissueState.bodyLoadFieldDynamics,
      bodySchemaDynamics: fastTissueState.bodySchemaDynamics,
      buffers: fastTissueState.buffers
    )
    return try Self(
      cognitiveState: migratedCognitive,
      fastTissueState: migratedFast
    )
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

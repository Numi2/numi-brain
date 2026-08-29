import Foundation
import NumiBrainCore

/// GPU-resident cognitive, memory, drive, and developmental state at one
/// committed root boundary. `MetalNumiBrainCheckpoint` binds this payload to
/// the corresponding fast-tissue state for complete nervous-system recovery.
@frozen
public struct MetalBrainCheckpoint: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let formatVersion: UInt32
  public let committedGeneration: UInt64
  public let committedTimestamp: BrainTimestamp
  public let environmentIdentifier: UInt32
  public let episodeIdentifier: UInt64
  public let controlStepIdentifier: UInt64
  public let speciesTemplateFingerprint: UInt64
  public let regionalProgramFingerprint: UInt64
  public let scheduleFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  public let hotLayoutFingerprint: UInt64
  public let memoryLayoutFingerprint: UInt64
  public let physicalCheckpointFingerprint: UInt64
  public let hotState: Data
  public let persistentMemory: Data
  public let checkpointFingerprint: UInt64

  init(
    committedGeneration: UInt64,
    committedTimestamp: BrainTimestamp,
    environmentIdentifier: UInt32,
    episodeIdentifier: UInt64,
    controlStepIdentifier: UInt64,
    speciesTemplateFingerprint: UInt64,
    regionalProgramFingerprint: UInt64,
    scheduleFingerprint: UInt64,
    parameterVersionFingerprint: UInt64,
    hotLayoutFingerprint: UInt64,
    memoryLayoutFingerprint: UInt64,
    physicalCheckpointFingerprint: UInt64,
    hotState: Data,
    persistentMemory: Data
  ) throws {
    guard speciesTemplateFingerprint > 0, regionalProgramFingerprint > 0,
      scheduleFingerprint > 0, parameterVersionFingerprint > 0,
      hotLayoutFingerprint > 0, memoryLayoutFingerprint > 0,
      physicalCheckpointFingerprint > 0, !hotState.isEmpty,
      !persistentMemory.isEmpty
    else {
      throw TissueError.transaction("brain checkpoint identity is incomplete")
    }
    self.formatVersion = Self.formatVersion
    self.committedGeneration = committedGeneration
    self.committedTimestamp = committedTimestamp
    self.environmentIdentifier = environmentIdentifier
    self.episodeIdentifier = episodeIdentifier
    self.controlStepIdentifier = controlStepIdentifier
    self.speciesTemplateFingerprint = speciesTemplateFingerprint
    self.regionalProgramFingerprint = regionalProgramFingerprint
    self.scheduleFingerprint = scheduleFingerprint
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.hotLayoutFingerprint = hotLayoutFingerprint
    self.memoryLayoutFingerprint = memoryLayoutFingerprint
    self.physicalCheckpointFingerprint = physicalCheckpointFingerprint
    self.hotState = hotState
    self.persistentMemory = persistentMemory
    self.checkpointFingerprint = Self.contentFingerprint(
      committedGeneration: committedGeneration,
      committedTimestamp: committedTimestamp,
      environmentIdentifier: environmentIdentifier,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: controlStepIdentifier,
      speciesTemplateFingerprint: speciesTemplateFingerprint,
      regionalProgramFingerprint: regionalProgramFingerprint,
      scheduleFingerprint: scheduleFingerprint,
      parameterVersionFingerprint: parameterVersionFingerprint,
      hotLayoutFingerprint: hotLayoutFingerprint,
      memoryLayoutFingerprint: memoryLayoutFingerprint,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint,
      hotState: hotState,
      persistentMemory: persistentMemory
    )
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion,
      checkpointFingerprint == Self.contentFingerprint(
        committedGeneration: committedGeneration,
        committedTimestamp: committedTimestamp,
        environmentIdentifier: environmentIdentifier,
        episodeIdentifier: episodeIdentifier,
        controlStepIdentifier: controlStepIdentifier,
        speciesTemplateFingerprint: speciesTemplateFingerprint,
        regionalProgramFingerprint: regionalProgramFingerprint,
        scheduleFingerprint: scheduleFingerprint,
        parameterVersionFingerprint: parameterVersionFingerprint,
        hotLayoutFingerprint: hotLayoutFingerprint,
        memoryLayoutFingerprint: memoryLayoutFingerprint,
        physicalCheckpointFingerprint: physicalCheckpointFingerprint,
        hotState: hotState,
        persistentMemory: persistentMemory
      )
    else {
      throw TissueError.transaction("brain checkpoint content fingerprint mismatch")
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

  public func write(to url: URL, options: Data.WritingOptions = [.atomic]) throws {
    try encoded().write(to: url, options: options)
  }

  public static func read(from url: URL) throws -> Self {
    try decode(Data(contentsOf: url, options: [.mappedIfSafe]))
  }

  private static func contentFingerprint(
    committedGeneration: UInt64,
    committedTimestamp: BrainTimestamp,
    environmentIdentifier: UInt32,
    episodeIdentifier: UInt64,
    controlStepIdentifier: UInt64,
    speciesTemplateFingerprint: UInt64,
    regionalProgramFingerprint: UInt64,
    scheduleFingerprint: UInt64,
    parameterVersionFingerprint: UInt64,
    hotLayoutFingerprint: UInt64,
    memoryLayoutFingerprint: UInt64,
    physicalCheckpointFingerprint: UInt64,
    hotState: Data,
    persistentMemory: Data
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for value in [
      UInt64(Self.formatVersion), committedGeneration,
      committedTimestamp.rawValue, UInt64(environmentIdentifier),
      episodeIdentifier, controlStepIdentifier, speciesTemplateFingerprint,
      regionalProgramFingerprint, scheduleFingerprint,
      parameterVersionFingerprint, hotLayoutFingerprint,
      memoryLayoutFingerprint, physicalCheckpointFingerprint,
      UInt64(hotState.count), UInt64(persistentMemory.count),
    ] {
      mix(value, into: &hash)
    }
    mix(hotState, into: &hash)
    mix(persistentMemory, into: &hash)
    return hash
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

  private static func mix(_ data: Data, into hash: inout UInt64) {
    data.withUnsafeBytes { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }
}

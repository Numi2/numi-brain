import Foundation
import NumiBrainCore

@frozen
public enum MetalTissueCheckpointBufferKind: UInt16, Codable, CaseIterable, Sendable {
  case tissueState = 1
  case relayHistory = 2
  case relayHistoryTimestamps = 3
  case schedulerClocks = 4
  case regionalStates = 5
  case regionalTokens = 6
  case routeHistoryStates = 7
  case routeHistoryTimestamps = 8
  case routeHistoryValues = 9
  case routeRuntimeStates = 10
  case protectiveCommand = 11
  case protectiveMotorHeader = 12
  case protectiveMuscleExcitations = 13
  case bodyLoadField = 14
  case bodySchema = 15
}

@frozen
public struct MetalTissueCheckpointBuffer: Codable, Equatable, Sendable {
  public let kind: MetalTissueCheckpointBufferKind
  public let data: Data

  public init(kind: MetalTissueCheckpointBufferKind, data: Data) {
    self.kind = kind
    self.data = data
  }
}

/// Exact fast nervous-system state at one committed root boundary. Immutable
/// tissue structure, routes, species anatomy, and parameters are identified by
/// fingerprints; mutable GPU generations are stored byte-for-byte.
@frozen
public struct MetalTissueCheckpoint: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 2

  public let formatVersion: UInt32
  public let width: Int
  public let height: Int
  public let environmentIdentifier: UInt32
  public let randomContext: TissueRandomContext
  public let committedStep: UInt64
  public let committedSchedulerTime: BrainTimestamp?
  public let committedSchedulerGeneration: UInt64
  public let committedHistoryOwnerMask: UInt32
  public let committedRelayHistoryTimestamps: [UInt64]
  public let parameterVersionFingerprint: UInt64
  public let scheduleFingerprint: UInt64
  public let regionalProgramFingerprint: UInt64
  public let sharedArtifactFingerprint: UInt64
  public let protectiveMotorProfileFingerprint: UInt64
  public let attachmentCatalogFingerprint: UInt64
  public let somaticSynergyCatalogFingerprint: UInt64
  public let structureHash: String
  public let delayFieldHash: String
  public let connectomeHash: String
  public let eventScheduleHash: String
  public let bodyLoadFieldDynamics: BodyLoadFieldDynamics
  public let bodySchemaDynamics: BodySchemaPosteriorDynamics
  public let buffers: [MetalTissueCheckpointBuffer]
  public let checkpointFingerprint: UInt64

  init(
    width: Int,
    height: Int,
    environmentIdentifier: UInt32,
    randomContext: TissueRandomContext,
    committedStep: UInt64,
    committedSchedulerTime: BrainTimestamp?,
    committedSchedulerGeneration: UInt64,
    committedHistoryOwnerMask: UInt32,
    committedRelayHistoryTimestamps: [UInt64],
    parameterVersionFingerprint: UInt64,
    scheduleFingerprint: UInt64,
    regionalProgramFingerprint: UInt64,
    sharedArtifactFingerprint: UInt64,
    protectiveMotorProfileFingerprint: UInt64,
    attachmentCatalogFingerprint: UInt64,
    somaticSynergyCatalogFingerprint: UInt64,
    structureHash: String,
    delayFieldHash: String,
    connectomeHash: String,
    eventScheduleHash: String,
    bodyLoadFieldDynamics: BodyLoadFieldDynamics,
    bodySchemaDynamics: BodySchemaPosteriorDynamics,
    buffers: [MetalTissueCheckpointBuffer]
  ) throws {
    let buffers = buffers.sorted { $0.kind.rawValue < $1.kind.rawValue }
    guard width > 0, height > 0, parameterVersionFingerprint > 0,
      scheduleFingerprint > 0, regionalProgramFingerprint > 0,
      sharedArtifactFingerprint > 0, protectiveMotorProfileFingerprint > 0,
      somaticSynergyCatalogFingerprint > 0,
      !structureHash.isEmpty, !delayFieldHash.isEmpty, !connectomeHash.isEmpty,
      !eventScheduleHash.isEmpty,
      committedRelayHistoryTimestamps.count == TissueDelayField.historyCapacity,
      Set(buffers.map(\.kind)) == Set(MetalTissueCheckpointBufferKind.allCases),
      buffers.count == MetalTissueCheckpointBufferKind.allCases.count
    else {
      throw TissueError.transaction("fast-tissue checkpoint identity is incomplete")
    }
    self.formatVersion = Self.formatVersion
    self.width = width
    self.height = height
    self.environmentIdentifier = environmentIdentifier
    self.randomContext = randomContext
    self.committedStep = committedStep
    self.committedSchedulerTime = committedSchedulerTime
    self.committedSchedulerGeneration = committedSchedulerGeneration
    self.committedHistoryOwnerMask = committedHistoryOwnerMask
    self.committedRelayHistoryTimestamps = committedRelayHistoryTimestamps
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.scheduleFingerprint = scheduleFingerprint
    self.regionalProgramFingerprint = regionalProgramFingerprint
    self.sharedArtifactFingerprint = sharedArtifactFingerprint
    self.protectiveMotorProfileFingerprint = protectiveMotorProfileFingerprint
    self.attachmentCatalogFingerprint = attachmentCatalogFingerprint
    self.somaticSynergyCatalogFingerprint = somaticSynergyCatalogFingerprint
    self.structureHash = structureHash
    self.delayFieldHash = delayFieldHash
    self.connectomeHash = connectomeHash
    self.eventScheduleHash = eventScheduleHash
    self.bodyLoadFieldDynamics = bodyLoadFieldDynamics
    self.bodySchemaDynamics = bodySchemaDynamics
    self.buffers = buffers
    self.checkpointFingerprint = Self.contentFingerprint(
      width: width,
      height: height,
      environmentIdentifier: environmentIdentifier,
      randomContext: randomContext,
      committedStep: committedStep,
      committedSchedulerTime: committedSchedulerTime,
      committedSchedulerGeneration: committedSchedulerGeneration,
      committedHistoryOwnerMask: committedHistoryOwnerMask,
      committedRelayHistoryTimestamps: committedRelayHistoryTimestamps,
      parameterVersionFingerprint: parameterVersionFingerprint,
      scheduleFingerprint: scheduleFingerprint,
      regionalProgramFingerprint: regionalProgramFingerprint,
      sharedArtifactFingerprint: sharedArtifactFingerprint,
      protectiveMotorProfileFingerprint: protectiveMotorProfileFingerprint,
      attachmentCatalogFingerprint: attachmentCatalogFingerprint,
      somaticSynergyCatalogFingerprint: somaticSynergyCatalogFingerprint,
      structureHash: structureHash,
      delayFieldHash: delayFieldHash,
      connectomeHash: connectomeHash,
      eventScheduleHash: eventScheduleHash,
      bodyLoadFieldDynamics: bodyLoadFieldDynamics,
      bodySchemaDynamics: bodySchemaDynamics,
      buffers: buffers
    )
  }

  public func buffer(_ kind: MetalTissueCheckpointBufferKind) -> Data {
    buffers.first(where: { $0.kind == kind })!.data
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion, width > 0, height > 0,
      randomContext.environmentIdentifier == environmentIdentifier,
      parameterVersionFingerprint > 0, scheduleFingerprint > 0,
      regionalProgramFingerprint > 0, sharedArtifactFingerprint > 0,
      protectiveMotorProfileFingerprint > 0,
      somaticSynergyCatalogFingerprint > 0,
      !structureHash.isEmpty, !delayFieldHash.isEmpty,
      !connectomeHash.isEmpty, !eventScheduleHash.isEmpty,
      Set(buffers.map(\.kind)) == Set(MetalTissueCheckpointBufferKind.allCases),
      buffers.count == MetalTissueCheckpointBufferKind.allCases.count,
      committedRelayHistoryTimestamps.count == TissueDelayField.historyCapacity,
      checkpointFingerprint == Self.contentFingerprint(
        width: width,
        height: height,
        environmentIdentifier: environmentIdentifier,
        randomContext: randomContext,
        committedStep: committedStep,
        committedSchedulerTime: committedSchedulerTime,
        committedSchedulerGeneration: committedSchedulerGeneration,
        committedHistoryOwnerMask: committedHistoryOwnerMask,
        committedRelayHistoryTimestamps: committedRelayHistoryTimestamps,
        parameterVersionFingerprint: parameterVersionFingerprint,
        scheduleFingerprint: scheduleFingerprint,
        regionalProgramFingerprint: regionalProgramFingerprint,
        sharedArtifactFingerprint: sharedArtifactFingerprint,
        protectiveMotorProfileFingerprint: protectiveMotorProfileFingerprint,
        attachmentCatalogFingerprint: attachmentCatalogFingerprint,
        somaticSynergyCatalogFingerprint: somaticSynergyCatalogFingerprint,
        structureHash: structureHash,
        delayFieldHash: delayFieldHash,
        connectomeHash: connectomeHash,
        eventScheduleHash: eventScheduleHash,
        bodyLoadFieldDynamics: bodyLoadFieldDynamics,
        bodySchemaDynamics: bodySchemaDynamics,
        buffers: buffers.sorted { $0.kind.rawValue < $1.kind.rawValue }
      )
    else {
      throw TissueError.transaction("fast-tissue checkpoint fingerprint mismatch")
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
    width: Int,
    height: Int,
    environmentIdentifier: UInt32,
    randomContext: TissueRandomContext,
    committedStep: UInt64,
    committedSchedulerTime: BrainTimestamp?,
    committedSchedulerGeneration: UInt64,
    committedHistoryOwnerMask: UInt32,
    committedRelayHistoryTimestamps: [UInt64],
    parameterVersionFingerprint: UInt64,
    scheduleFingerprint: UInt64,
    regionalProgramFingerprint: UInt64,
    sharedArtifactFingerprint: UInt64,
    protectiveMotorProfileFingerprint: UInt64,
    attachmentCatalogFingerprint: UInt64,
    somaticSynergyCatalogFingerprint: UInt64,
    structureHash: String,
    delayFieldHash: String,
    connectomeHash: String,
    eventScheduleHash: String,
    bodyLoadFieldDynamics: BodyLoadFieldDynamics,
    bodySchemaDynamics: BodySchemaPosteriorDynamics,
    buffers: [MetalTissueCheckpointBuffer]
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for value in [
      UInt64(Self.formatVersion), UInt64(width), UInt64(height),
      UInt64(environmentIdentifier), committedStep,
      UInt64(randomContext.seed), UInt64(randomContext.environmentIdentifier),
      UInt64(randomContext.episodeIdentifier), UInt64(randomContext.moduleIdentifier),
      committedSchedulerTime?.rawValue ?? UInt64.max,
      committedSchedulerGeneration, UInt64(committedHistoryOwnerMask),
      parameterVersionFingerprint, scheduleFingerprint,
      regionalProgramFingerprint, sharedArtifactFingerprint,
      protectiveMotorProfileFingerprint, attachmentCatalogFingerprint,
      somaticSynergyCatalogFingerprint,
      UInt64(bodyLoadFieldDynamics.persistenceMicroseconds),
      UInt64(bodyLoadFieldDynamics.decayMicroseconds),
      UInt64(bodySchemaDynamics.forceScaleNewtons.bitPattern),
      UInt64(bodySchemaDynamics.loadTimeConstantMicroseconds),
      UInt64(bodySchemaDynamics.initialVariance.bitPattern),
      UInt64(bodySchemaDynamics.maximumVariance.bitPattern),
      UInt64(bodySchemaDynamics.processVariancePerSecond.bitPattern),
      UInt64(bodySchemaDynamics.observationVariance.bitPattern),
      UInt64(bodySchemaDynamics.vulnerabilityGainPerSecond.bitPattern),
      UInt64(bodySchemaDynamics.recoveryPerSecond.bitPattern),
      UInt64(bodySchemaDynamics.uncertaintyRiskWeight.bitPattern),
    ] {
      mix(value, into: &hash)
    }
    for timestamp in committedRelayHistoryTimestamps {
      mix(timestamp, into: &hash)
    }
    for value in [structureHash, delayFieldHash, connectomeHash, eventScheduleHash] {
      mix(Data(value.utf8), into: &hash)
    }
    for buffer in buffers {
      mix(UInt64(buffer.kind.rawValue), into: &hash)
      mix(UInt64(buffer.data.count), into: &hash)
      mix(buffer.data, into: &hash)
    }
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

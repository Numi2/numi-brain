import Foundation

/// Crash-recovery record for a fully materialized brain generation. This record owns the complete
/// BrainAgentState rather than GPU pointers. A Metal runtime may reconstruct device buffers from it
/// after process death, then verify all immutable fingerprints before publication.
@frozen
public struct BrainDurablePreparedGeneration: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let transactionFingerprint: UInt64
  public let environmentIdentifier: UInt32
  public let baseGeneration: UInt64
  public let shadowGeneration: UInt64
  public let basePhysicsGeneration: UInt64
  public let expectedPhysicsGeneration: UInt64
  public let committedTimestampMicroseconds: UInt64
  public let targetTimestampMicroseconds: UInt64
  public let parameterVersionFingerprint: UInt64
  public let acceptedPhysicsTokenFingerprint: UInt64
  public let scheduleFingerprint: UInt64
  public let state: BrainAgentState
  public let payloadFingerprint: UInt64

  public init(
    transactionFingerprint: UInt64,
    basePhysicsGeneration: UInt64,
    expectedPhysicsGeneration: UInt64,
    acceptedPhysicsTokenFingerprint: UInt64,
    scheduleFingerprint: UInt64,
    state: BrainAgentState,
    targetTimestamp: BrainTimestamp
  ) throws {
    let (expectedBrain, brainOverflow) = state.generation.subtractingReportingOverflow(1)
    guard transactionFingerprint > 0, acceptedPhysicsTokenFingerprint > 0,
      scheduleFingerprint > 0, !brainOverflow,
      expectedPhysicsGeneration > basePhysicsGeneration,
      state.committedTimestamp == targetTimestamp,
      state.parameterVersionFingerprint > 0
    else {
      throw BrainRuntimeError.transaction("durable prepared brain generation identity is invalid")
    }
    formatVersion = Self.formatVersion
    self.transactionFingerprint = transactionFingerprint
    environmentIdentifier = state.environmentIdentifier
    baseGeneration = expectedBrain
    shadowGeneration = state.generation
    self.basePhysicsGeneration = basePhysicsGeneration
    self.expectedPhysicsGeneration = expectedPhysicsGeneration
    committedTimestampMicroseconds = targetTimestamp.rawValue
    targetTimestampMicroseconds = targetTimestamp.rawValue
    parameterVersionFingerprint = state.parameterVersionFingerprint
    self.acceptedPhysicsTokenFingerprint = acceptedPhysicsTokenFingerprint
    self.scheduleFingerprint = scheduleFingerprint
    self.state = state
    payloadFingerprint = Self.fingerprint(
      transactionFingerprint: transactionFingerprint,
      environmentIdentifier: state.environmentIdentifier,
      baseGeneration: expectedBrain,
      shadowGeneration: state.generation,
      basePhysicsGeneration: basePhysicsGeneration,
      expectedPhysicsGeneration: expectedPhysicsGeneration,
      targetTimestamp: targetTimestamp.rawValue,
      parameterVersionFingerprint: state.parameterVersionFingerprint,
      acceptedPhysicsTokenFingerprint: acceptedPhysicsTokenFingerprint,
      scheduleFingerprint: scheduleFingerprint
    )
  }

  public func validated() throws -> Self {
    let expected = Self.fingerprint(
      transactionFingerprint: transactionFingerprint,
      environmentIdentifier: environmentIdentifier,
      baseGeneration: baseGeneration,
      shadowGeneration: shadowGeneration,
      basePhysicsGeneration: basePhysicsGeneration,
      expectedPhysicsGeneration: expectedPhysicsGeneration,
      targetTimestamp: targetTimestampMicroseconds,
      parameterVersionFingerprint: parameterVersionFingerprint,
      acceptedPhysicsTokenFingerprint: acceptedPhysicsTokenFingerprint,
      scheduleFingerprint: scheduleFingerprint
    )
    guard formatVersion == Self.formatVersion, transactionFingerprint > 0,
      environmentIdentifier == state.environmentIdentifier,
      shadowGeneration == state.generation,
      shadowGeneration == baseGeneration &+ 1,
      expectedPhysicsGeneration > basePhysicsGeneration,
      targetTimestampMicroseconds == state.committedTimestamp.rawValue,
      committedTimestampMicroseconds == targetTimestampMicroseconds,
      parameterVersionFingerprint == state.parameterVersionFingerprint,
      acceptedPhysicsTokenFingerprint > 0, scheduleFingerprint > 0,
      payloadFingerprint == expected
    else {
      throw BrainRuntimeError.transaction("durable prepared brain generation failed validation")
    }
    return self
  }

  private static func fingerprint(
    transactionFingerprint: UInt64, environmentIdentifier: UInt32,
    baseGeneration: UInt64, shadowGeneration: UInt64,
    basePhysicsGeneration: UInt64, expectedPhysicsGeneration: UInt64,
    targetTimestamp: UInt64, parameterVersionFingerprint: UInt64,
    acceptedPhysicsTokenFingerprint: UInt64, scheduleFingerprint: UInt64
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for value in [transactionFingerprint, UInt64(environmentIdentifier), baseGeneration,
                  shadowGeneration, basePhysicsGeneration, expectedPhysicsGeneration,
                  targetTimestamp, parameterVersionFingerprint,
                  acceptedPhysicsTokenFingerprint, scheduleFingerprint] {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { bytes in
        for byte in bytes { hash ^= UInt64(byte); hash &*= 1_099_511_628_211 }
      }
    }
    return hash
  }
}

@frozen
public enum BrainRecoveryDecision: String, Codable, Sendable {
  case prepared
  case commitDecided
  case committed
  case aborted
}

@frozen
public struct BrainRecoveryRecord: Codable, Equatable, Sendable {
  public let sequence: UInt64
  public let decision: BrainRecoveryDecision
  public let transactionFingerprint: UInt64
  public let preparedPayloadFingerprint: UInt64
  public let previousRecordFingerprint: UInt64
  public let recordFingerprint: UInt64

  public init(sequence: UInt64, decision: BrainRecoveryDecision,
              transactionFingerprint: UInt64, preparedPayloadFingerprint: UInt64,
              previousRecordFingerprint: UInt64) throws {
    guard transactionFingerprint > 0, preparedPayloadFingerprint > 0 else {
      throw BrainRuntimeError.transaction("recovery record identity is incomplete")
    }
    self.sequence = sequence; self.decision = decision
    self.transactionFingerprint = transactionFingerprint
    self.preparedPayloadFingerprint = preparedPayloadFingerprint
    self.previousRecordFingerprint = previousRecordFingerprint
    var hash: UInt64 = 14_695_981_039_346_656_037
    for value in [sequence, transactionFingerprint, preparedPayloadFingerprint,
                  previousRecordFingerprint, UInt64(Self.code(decision))] {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { bytes in
        for byte in bytes { hash ^= UInt64(byte); hash &*= 1_099_511_628_211 }
      }
    }
    recordFingerprint = hash
  }

  private static func code(_ decision: BrainRecoveryDecision) -> UInt8 {
    switch decision { case .prepared: 1; case .commitDecided: 2; case .committed: 3; case .aborted: 4 }
  }
}

/// File format: one canonical JSON envelope containing the prepared state and an append-only logical
/// decision chain. Writes use atomic replacement + fsync; a commit decision is never rewritten to abort.
public actor BrainDurableRecoveryStore {
  private struct Envelope: Codable {
    var prepared: BrainDurablePreparedGeneration
    var records: [BrainRecoveryRecord]
  }
  private let directory: URL
  private let maximumBytes: Int

  public init(directory: URL, maximumBytes: Int = 512 * 1024 * 1024) throws {
    guard directory.isFileURL, maximumBytes > 0 else {
      throw BrainRuntimeError.capacity("invalid recovery-store configuration")
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    self.directory = directory.resolvingSymlinksInPath()
    self.maximumBytes = maximumBytes
  }

  public func persistPrepared(_ prepared: BrainDurablePreparedGeneration) throws {
    let prepared = try prepared.validated()
    let url = file(prepared.transactionFingerprint)
    guard !FileManager.default.fileExists(atPath: url.path) else {
      let existing = try load(prepared.transactionFingerprint)
      guard existing.prepared == prepared else {
        throw BrainRuntimeError.transaction("conflicting durable prepare already exists")
      }
      return
    }
    let first = try BrainRecoveryRecord(sequence: 0, decision: .prepared,
      transactionFingerprint: prepared.transactionFingerprint,
      preparedPayloadFingerprint: prepared.payloadFingerprint,
      previousRecordFingerprint: 0)
    try write(Envelope(prepared: prepared, records: [first]), to: url, createOnly: true)
  }

  public func decideCommit(transactionFingerprint: UInt64) throws {
    var envelope = try load(transactionFingerprint)
    if envelope.records.contains(where: { $0.decision == .commitDecided }) { return }
    guard envelope.records.last?.decision == .prepared else {
      throw BrainRuntimeError.transaction("commit decision requires prepared state")
    }
    try append(.commitDecided, to: &envelope)
    try write(envelope, to: file(transactionFingerprint), createOnly: false)
  }

  public func markCommitted(transactionFingerprint: UInt64) throws {
    var envelope = try load(transactionFingerprint)
    if envelope.records.last?.decision == .committed { return }
    guard envelope.records.contains(where: { $0.decision == .commitDecided }) else {
      throw BrainRuntimeError.transaction("cannot publish without durable commit decision")
    }
    try append(.committed, to: &envelope)
    try write(envelope, to: file(transactionFingerprint), createOnly: false)
  }

  public func abortPrepared(transactionFingerprint: UInt64) throws {
    var envelope = try load(transactionFingerprint)
    guard !envelope.records.contains(where: { $0.decision == .commitDecided }) else {
      throw BrainRuntimeError.transaction("commit decision is irrevocable")
    }
    if envelope.records.last?.decision == .aborted { return }
    try append(.aborted, to: &envelope)
    try write(envelope, to: file(transactionFingerprint), createOnly: false)
  }

  public func recoveryCandidate(transactionFingerprint: UInt64) throws -> BrainDurablePreparedGeneration? {
    let envelope = try load(transactionFingerprint)
    guard envelope.records.contains(where: { $0.decision == .commitDecided }),
          envelope.records.last?.decision != .committed else { return nil }
    return try envelope.prepared.validated()
  }

  private func append(_ decision: BrainRecoveryDecision, to envelope: inout Envelope) throws {
    guard envelope.records.count < 1024, let last = envelope.records.last else {
      throw BrainRuntimeError.capacity("recovery decision chain capacity")
    }
    envelope.records.append(try BrainRecoveryRecord(sequence: UInt64(envelope.records.count),
      decision: decision, transactionFingerprint: envelope.prepared.transactionFingerprint,
      preparedPayloadFingerprint: envelope.prepared.payloadFingerprint,
      previousRecordFingerprint: last.recordFingerprint))
  }

  private func load(_ fingerprint: UInt64) throws -> Envelope {
    let data = try Data(contentsOf: file(fingerprint), options: [.mappedIfSafe])
    guard !data.isEmpty, data.count <= maximumBytes else {
      throw BrainRuntimeError.capacity("recovery artifact size")
    }
    let envelope = try JSONDecoder().decode(Envelope.self, from: data)
    _ = try envelope.prepared.validated()
    guard !envelope.records.isEmpty else { throw BrainRuntimeError.transaction("empty recovery decision chain") }
    var previous: UInt64 = 0
    for (index, record) in envelope.records.enumerated() {
      guard record.sequence == UInt64(index), record.transactionFingerprint == fingerprint,
            record.preparedPayloadFingerprint == envelope.prepared.payloadFingerprint,
            record.previousRecordFingerprint == previous else {
        throw BrainRuntimeError.transaction("recovery decision chain mismatch")
      }
      previous = record.recordFingerprint
    }
    return envelope
  }

  private func file(_ fingerprint: UInt64) -> URL {
    directory.appendingPathComponent(String(format: "%016llx.brain-prepare.json", fingerprint), isDirectory: false)
  }

  private func write(_ envelope: Envelope, to url: URL, createOnly: Bool) throws {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(envelope)
    guard data.count <= maximumBytes else { throw BrainRuntimeError.capacity("recovery artifact exceeds maximum") }
    let temporary = directory.appendingPathComponent(".\(UUID().uuidString).tmp")
    guard !createOnly || !FileManager.default.fileExists(atPath: url.path) else {
      throw BrainRuntimeError.transaction("recovery artifact already exists")
    }
    try data.write(to: temporary, options: [.atomic])
    let handle = try FileHandle(forWritingTo: temporary)
    try handle.synchronize(); try handle.close()
    if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    try FileManager.default.moveItem(at: temporary, to: url)
    let directoryHandle = try FileHandle(forReadingFrom: directory)
    try directoryHandle.synchronize(); try directoryHandle.close()
  }
}

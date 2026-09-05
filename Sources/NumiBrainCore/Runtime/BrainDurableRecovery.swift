import Foundation
import NumiBrainQualification

/// Versioned semantic brain-state archive. Native candidate arena recovery is
/// owned by BrainPreparedGPUImage/Store; neither format includes every physical
/// participant. A local archive never grants joint brain/physics publication.
@frozen
public struct BrainDurablePreparedGeneration: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 2
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
  public let stateSHA256: String
  public let payloadSHA256: String
  /// Compatibility identifier only. SHA-256, not this truncated scalar,
  /// establishes complete archive integrity.
  public let payloadFingerprint: UInt64

  private struct Identity: Encodable {
    let version: UInt32
    let transaction: UInt64
    let environment: UInt32
    let baseBrain: UInt64
    let candidateBrain: UInt64
    let basePhysics: UInt64
    let candidatePhysics: UInt64
    let timestamp: UInt64
    let parameter: UInt64
    let acceptedPhysics: UInt64
    let schedule: UInt64
    let state: String
  }

  public init(transactionFingerprint: UInt64, basePhysicsGeneration: UInt64,
    expectedPhysicsGeneration: UInt64, acceptedPhysicsTokenFingerprint: UInt64,
    scheduleFingerprint: UInt64, state: BrainAgentState, targetTimestamp: BrainTimestamp) throws {
    let (base, overflow) = state.generation.subtractingReportingOverflow(1)
    guard !overflow, transactionFingerprint > 0, acceptedPhysicsTokenFingerprint > 0,
      scheduleFingerprint > 0, state.parameterVersionFingerprint > 0,
      expectedPhysicsGeneration > basePhysicsGeneration,
      state.committedTimestamp == targetTimestamp else {
      throw BrainRuntimeError.transaction("invalid semantic recovery identity")
    }
    formatVersion = Self.formatVersion; self.transactionFingerprint = transactionFingerprint
    environmentIdentifier = state.environmentIdentifier; baseGeneration = base; shadowGeneration = state.generation
    self.basePhysicsGeneration = basePhysicsGeneration; self.expectedPhysicsGeneration = expectedPhysicsGeneration
    committedTimestampMicroseconds = targetTimestamp.rawValue; targetTimestampMicroseconds = targetTimestamp.rawValue
    parameterVersionFingerprint = state.parameterVersionFingerprint
    self.acceptedPhysicsTokenFingerprint = acceptedPhysicsTokenFingerprint; self.scheduleFingerprint = scheduleFingerprint
    self.state = state
    // Canonical serialization includes ALL semantic state fields, including
    // memories and recurrent values. Non-finite Float/Double values fail JSON encoding.
    stateSHA256 = BrainPolicyEvidenceArtifact.sha256(try BrainPolicyEvidenceArtifact.encodeCanonical(state))
    let identity = Identity(version: Self.formatVersion, transaction: transactionFingerprint,
      environment: state.environmentIdentifier, baseBrain: base, candidateBrain: state.generation,
      basePhysics: basePhysicsGeneration, candidatePhysics: expectedPhysicsGeneration,
      timestamp: targetTimestamp.rawValue, parameter: state.parameterVersionFingerprint,
      acceptedPhysics: acceptedPhysicsTokenFingerprint, schedule: scheduleFingerprint, state: stateSHA256)
    payloadSHA256 = try Self.digest(identity, domain: "NumiBrain.SemanticRecovery.v2")
    payloadFingerprint = UInt64(payloadSHA256.prefix(16), radix: 16).map { max($0, 1) }!
  }

  public func validated() throws -> Self {
    guard formatVersion == Self.formatVersion,
      try Self(transactionFingerprint: transactionFingerprint,
        basePhysicsGeneration: basePhysicsGeneration, expectedPhysicsGeneration: expectedPhysicsGeneration,
        acceptedPhysicsTokenFingerprint: acceptedPhysicsTokenFingerprint, scheduleFingerprint: scheduleFingerprint,
        state: state, targetTimestamp: BrainTimestamp(microseconds: targetTimestampMicroseconds)) == self else {
      throw BrainRuntimeError.transaction("semantic recovery state/identity failed verification; legacy v1 is not trusted")
    }
    return self
  }

  fileprivate static func digest<T: Encodable>(_ value: T, domain: String) throws -> String {
    let payload = try BrainPolicyEvidenceArtifact.encodeCanonical(value)
    var data = Data(domain.utf8); data.append(0)
    var count = UInt64(payload.count).littleEndian
    withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
    data.append(payload)
    return BrainPolicyEvidenceArtifact.sha256(data)
  }
}

@frozen
public enum BrainRecoveryDecision: String, Codable, Sendable {
  case prepared, commitDecided, committed, aborted
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
    self.sequence = sequence; self.decision = decision; self.transactionFingerprint = transactionFingerprint
    self.preparedPayloadFingerprint = preparedPayloadFingerprint; self.previousRecordFingerprint = previousRecordFingerprint
    var hash: UInt64 = 14_695_981_039_346_656_037
    let code: UInt64
    switch decision { case .prepared: code = 1; case .commitDecided: code = 2; case .committed: code = 3; case .aborted: code = 4 }
    for value in [sequence, transactionFingerprint, preparedPayloadFingerprint, previousRecordFingerprint, code] {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { bytes in
        for byte in bytes { hash ^= UInt64(byte); hash &*= 1_099_511_628_211 }
      }
    }
    recordFingerprint = hash
  }

  /// Recompute every record AND enforce the legal decision sequence. The
  /// archive's outer SHA-256 binds these records to the complete prepared state.
  public static func validateChain(_ records: [Self], transactionFingerprint: UInt64,
    preparedPayloadFingerprint: UInt64) throws {
    guard !records.isEmpty, records.count <= 3 else { throw BrainRuntimeError.transaction("invalid recovery chain length") }
    var previous: Self?
    for (index, record) in records.enumerated() {
      guard record.sequence == UInt64(index), record.transactionFingerprint == transactionFingerprint,
        record.preparedPayloadFingerprint == preparedPayloadFingerprint,
        record.previousRecordFingerprint == (previous?.recordFingerprint ?? 0),
        try Self(sequence: record.sequence, decision: record.decision,
          transactionFingerprint: record.transactionFingerprint, preparedPayloadFingerprint: record.preparedPayloadFingerprint,
          previousRecordFingerprint: record.previousRecordFingerprint) == record else {
        throw BrainRuntimeError.transaction("recovery chain identity or fingerprint mismatch")
      }
      switch (previous?.decision, record.decision) {
      case (nil, .prepared), (.prepared?, .commitDecided), (.prepared?, .aborted), (.commitDecided?, .committed): break
      default: throw BrainRuntimeError.transaction("illegal or reversed recovery decision")
      }
      previous = record
    }
  }
}

/// Single-writer semantic archive with full-payload integrity and atomic durable
/// replacement. A durable COMMIT decision cannot subsequently become ABORT.
/// Version-1 metadata-only archives are retained on disk but refused here.
public actor BrainDurableRecoveryStore {
  private struct Body: Codable {
    let version: UInt32
    var prepared: BrainDurablePreparedGeneration
    var records: [BrainRecoveryRecord]
  }
  private struct Envelope: Codable {
    let body: Body
    let sha256: String
  }
  private let directory: QualificationFileDirectory
  private let writerLock: FileHandle
  private let maximumBytes: Int

  /// The existing directory must be absolute and nonsymlinked. Use the same
  /// explicit storage-directory setup as BrainPreparedGPUStore.
  public init(directory: URL, maximumBytes: Int = 512 * 1024 * 1024) throws {
    guard maximumBytes > 0, maximumBytes <= 536_870_912 else {
      throw BrainRuntimeError.capacity("invalid semantic recovery archive limit")
    }
    let storage = try QualificationFileDirectory(url: directory)
    let writer = try storage.acquireExclusiveWriterLock(named: ".semantic-recovery.writer.lock")
    self.directory = storage; self.writerLock = writer; self.maximumBytes = maximumBytes
  }

  public func persistPrepared(_ value: BrainDurablePreparedGeneration) throws {
    let prepared = try value.validated()
    if let data = try directory.readIfPresent(name(prepared.transactionFingerprint), maximumBytes: maximumBytes) {
      guard try decode(data, fingerprint: prepared.transactionFingerprint).prepared == prepared else {
        throw BrainRuntimeError.transaction("conflicting semantic prepare already exists")
      }
      return
    }
    let first = try BrainRecoveryRecord(sequence: 0, decision: .prepared,
      transactionFingerprint: prepared.transactionFingerprint, preparedPayloadFingerprint: prepared.payloadFingerprint,
      previousRecordFingerprint: 0)
    let body = Body(version: 2, prepared: prepared, records: [first])
    try write(body, createOnly: true)
  }

  public func decideCommit(transactionFingerprint: UInt64) throws {
    var body = try load(transactionFingerprint)
    if body.records.last?.decision == .commitDecided || body.records.last?.decision == .committed { return }
    try append(.commitDecided, to: &body); try write(body)
  }

  public func markCommitted(transactionFingerprint: UInt64) throws {
    var body = try load(transactionFingerprint)
    if body.records.last?.decision == .committed { return }
    try append(.committed, to: &body); try write(body)
  }

  public func abortPrepared(transactionFingerprint: UInt64) throws {
    var body = try load(transactionFingerprint)
    if body.records.last?.decision == .aborted { return }
    try append(.aborted, to: &body); try write(body)
  }

  /// Diagnostic candidate only. The joint owner must reconcile its own
  /// physical participant and release receipt before publishing anything.
  public func recoveryCandidate(transactionFingerprint: UInt64) throws -> BrainDurablePreparedGeneration? {
    let body = try load(transactionFingerprint)
    return body.records.last?.decision == .commitDecided ? body.prepared : nil
  }

  private func append(_ decision: BrainRecoveryDecision, to body: inout Body) throws {
    guard let last = body.records.last, body.records.count < 3 else {
      throw BrainRuntimeError.transaction("semantic recovery chain is terminal")
    }
    body.records.append(try BrainRecoveryRecord(sequence: UInt64(body.records.count), decision: decision,
      transactionFingerprint: body.prepared.transactionFingerprint,
      preparedPayloadFingerprint: body.prepared.payloadFingerprint, previousRecordFingerprint: last.recordFingerprint))
    try BrainRecoveryRecord.validateChain(body.records, transactionFingerprint: body.prepared.transactionFingerprint,
      preparedPayloadFingerprint: body.prepared.payloadFingerprint)
  }

  private func load(_ fingerprint: UInt64) throws -> Body {
    try decode(directory.read(name(fingerprint), maximumBytes: maximumBytes), fingerprint: fingerprint)
  }

  private func decode(_ data: Data, fingerprint: UInt64) throws -> Body {
    let envelope = try JSONDecoder().decode(Envelope.self, from: data)
    guard envelope.body.version == 2, envelope.body.prepared.transactionFingerprint == fingerprint,
      try BrainDurablePreparedGeneration.digest(envelope.body, domain: "NumiBrain.SemanticRecoveryEnvelope.v2") == envelope.sha256 else {
      throw BrainRuntimeError.transaction("semantic recovery envelope digest/root mismatch")
    }
    _ = try envelope.body.prepared.validated()
    try BrainRecoveryRecord.validateChain(envelope.body.records, transactionFingerprint: fingerprint,
      preparedPayloadFingerprint: envelope.body.prepared.payloadFingerprint)
    return envelope.body
  }

  private func write(_ body: Body, createOnly: Bool = false) throws {
    let hash = try BrainDurablePreparedGeneration.digest(body, domain: "NumiBrain.SemanticRecoveryEnvelope.v2")
    let data = try QualificationFileDirectory.canonicalJSON(Envelope(body: body, sha256: hash))
    guard data.count <= maximumBytes else { throw BrainRuntimeError.capacity("semantic recovery archive exceeds limit") }
    guard try directory.publish(data, named: name(body.prepared.transactionFingerprint), replaceExisting: !createOnly) else {
      throw BrainRuntimeError.transaction("semantic recovery archive already exists")
    }
  }

  private func name(_ fingerprint: UInt64) -> String {
    String(format: "%016llx.brain-prepare.json", fingerprint)
  }
}

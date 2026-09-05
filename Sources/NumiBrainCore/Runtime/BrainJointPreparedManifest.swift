import Foundation
import CryptoKit

public enum BrainPreparedParticipantKind: UInt8, Codable, CaseIterable, Sendable {
  case cognitiveArena = 1
  case fastTissue = 2
  case physicalSolver = 3
  case externalArchive = 4
}

public struct BrainPreparedParticipantArtifact: Codable, Equatable, Sendable {
  public let kind: BrainPreparedParticipantKind
  public let transactionFingerprint: UInt64
  public let baseGeneration: UInt64
  public let shadowGeneration: UInt64
  public let immutableProgramFingerprint: UInt64
  public let payloadSHA256: String
  public let payloadBytes: UInt64

  public init(kind: BrainPreparedParticipantKind, transactionFingerprint: UInt64,
              baseGeneration: UInt64, shadowGeneration: UInt64,
              immutableProgramFingerprint: UInt64, payloadSHA256: String,
              payloadBytes: UInt64) throws {
    self.kind = kind; self.transactionFingerprint = transactionFingerprint
    self.baseGeneration = baseGeneration; self.shadowGeneration = shadowGeneration
    self.immutableProgramFingerprint = immutableProgramFingerprint
    self.payloadSHA256 = payloadSHA256; self.payloadBytes = payloadBytes
    _ = try validated()
  }

  public func validated() throws -> Self {
    let next = baseGeneration.addingReportingOverflow(1)
    guard transactionFingerprint > 0, !next.overflow, shadowGeneration == next.partialValue,
      immutableProgramFingerprint > 0, payloadBytes > 0, Self.isSHA256(payloadSHA256) else {
      throw BrainRuntimeError.transaction("invalid prepared participant artifact")
    }
    return self
  }

  private static func isSHA256(_ value: String) -> Bool {
    value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
  }
}

/// Durable prepare record for the whole reversible root. Participant payloads remain in their native
/// stores; this manifest prevents recovery from mixing independently valid artifacts from different
/// roots/generations. Physical hardware and living-culture stimulation are not reversible participants.
public struct BrainJointPreparedManifest: Codable, Equatable, Sendable {
  public static let currentVersion: UInt32 = 1
  public let version: UInt32
  public let root: BrainPreparedRoot
  public let targetTimestampMicroseconds: UInt64
  public let parameterVersionFingerprint: UInt64
  public let participants: [BrainPreparedParticipantArtifact]
  public let manifestSHA256: String

  public init(root: BrainPreparedRoot, parameterVersionFingerprint: UInt64,
              participants input: [BrainPreparedParticipantArtifact]) throws {
    let token = try root.validatedToken()
    let participants = input.sorted { $0.kind.rawValue < $1.kind.rawValue }
    for participant in participants { _ = try participant.validated() }
    try Self.validateParticipantSet(participants, token: token,
      parameterVersionFingerprint: parameterVersionFingerprint)
    version = Self.currentVersion; self.root = root
    targetTimestampMicroseconds = token.targetTimestamp.rawValue
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.participants = participants
    manifestSHA256 = Self.digest(version: Self.currentVersion, root: root,
      targetTimestampMicroseconds: token.targetTimestamp.rawValue,
      parameterVersionFingerprint: parameterVersionFingerprint, participants: participants)
  }

  public func validated() throws -> Self {
    let token = try root.validatedToken()
    guard version == Self.currentVersion,
      targetTimestampMicroseconds == token.targetTimestamp.rawValue else {
      throw BrainRuntimeError.transaction("joint prepared manifest version/time mismatch")
    }
    for participant in participants { _ = try participant.validated() }
    try Self.validateParticipantSet(participants, token: token,
      parameterVersionFingerprint: parameterVersionFingerprint)
    guard manifestSHA256 == Self.digest(version: version, root: root,
      targetTimestampMicroseconds: targetTimestampMicroseconds,
      parameterVersionFingerprint: parameterVersionFingerprint, participants: participants) else {
      throw BrainRuntimeError.transaction("joint prepared manifest integrity mismatch")
    }
    return self
  }

  public func participant(_ kind: BrainPreparedParticipantKind) -> BrainPreparedParticipantArtifact {
    participants.first(where: { $0.kind == kind })!
  }

  private static func validateParticipantSet(_ participants: [BrainPreparedParticipantArtifact],
    token: BrainJointTransactionToken, parameterVersionFingerprint: UInt64) throws {
    let orderedKinds = BrainPreparedParticipantKind.allCases.sorted { $0.rawValue < $1.rawValue }
    guard parameterVersionFingerprint == token.parameterVersionFingerprint,
      participants.count == orderedKinds.count,
      participants.map(\.kind) == orderedKinds,
      participants.allSatisfy({ $0.transactionFingerprint == token.fingerprint }),
      participants.first(where: { $0.kind == .cognitiveArena })?.baseGeneration == token.baseBrainGeneration,
      participants.first(where: { $0.kind == .cognitiveArena })?.shadowGeneration == token.shadowGeneration,
      participants.first(where: { $0.kind == .fastTissue })?.baseGeneration == token.baseBrainGeneration,
      participants.first(where: { $0.kind == .fastTissue })?.shadowGeneration == token.shadowGeneration,
      participants.first(where: { $0.kind == .physicalSolver })?.baseGeneration == token.basePhysicsGeneration,
      participants.first(where: { $0.kind == .physicalSolver })?.shadowGeneration == token.basePhysicsGeneration &+ 1 else {
      throw BrainRuntimeError.transaction("prepared participant set does not bind the joint root")
    }
  }

  private static func digest(version: UInt32, root: BrainPreparedRoot,
    targetTimestampMicroseconds: UInt64, parameterVersionFingerprint: UInt64,
    participants: [BrainPreparedParticipantArtifact]) -> String {
    var hash = SHA256()
    hash.update(data: Data("NumiBrain.joint-prepared-manifest.v1\0".utf8))
    func scalar(_ value: UInt64) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { hash.update(bufferPointer: $0) }
    }
    scalar(UInt64(version)); scalar(root.fingerprint); scalar(targetTimestampMicroseconds)
    scalar(parameterVersionFingerprint); scalar(UInt64(participants.count))
    for participant in participants {
      scalar(UInt64(participant.kind.rawValue)); scalar(participant.transactionFingerprint)
      scalar(participant.baseGeneration); scalar(participant.shadowGeneration)
      scalar(participant.immutableProgramFingerprint); scalar(participant.payloadBytes)
      hash.update(data: Data(participant.payloadSHA256.utf8))
    }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
  }
}

public enum BrainJointPreparedDecision: String, Codable, Sendable { case commit, abort }

public struct BrainJointPreparedDecisionRecord: Codable, Equatable, Sendable {
  public let manifestSHA256: String
  public let rootFingerprint: UInt64
  public let decision: BrainJointPreparedDecision
  public let decisionSHA256: String

  public init(manifest: BrainJointPreparedManifest, decision: BrainJointPreparedDecision) throws {
    let validated = try manifest.validated()
    manifestSHA256 = validated.manifestSHA256
    rootFingerprint = validated.root.fingerprint
    self.decision = decision
    var hash = SHA256()
    hash.update(data: Data("NumiBrain.joint-prepared-decision.v1\0".utf8))
    hash.update(data: Data(validated.manifestSHA256.utf8))
    var root = validated.root.fingerprint.littleEndian
    withUnsafeBytes(of: &root) { hash.update(bufferPointer: $0) }
    hash.update(data: Data(decision.rawValue.utf8))
    decisionSHA256 = hash.finalize().map { String(format: "%02x", $0) }.joined()
  }
}

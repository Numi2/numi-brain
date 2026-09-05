import Foundation
import CryptoKit
import NumiBrainABI

/// Original native ABI records, not regenerated accepted-physics claims. Persist these alongside
/// the actual physical prepared image. SHA-256 provides integrity, not signer authentication or
/// proof that the owner really captured complete physical state.
public struct BrainPreparedNativeReceipts: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let version: UInt32
  public let root: BrainPreparedRoot
  public let substepBytes: Data
  public let acceptedPhysicsBytes: Data
  public let jointCommitBytes: Data
  public let physicalCheckpointFingerprint: UInt64
  public let contentSHA256: String

  public init(root: BrainJointTransactionToken, substep: BrainJointSubstepToken,
    acceptedPhysics: AcceptedPhysicsStateToken, jointCommit: BrainJointCommitToken,
    physicalCheckpointFingerprint: UInt64) throws {
    version = Self.formatVersion; self.root = BrainPreparedRoot(root)
    substepBytes = Self.bytes(substep.abiRecord)
    acceptedPhysicsBytes = Self.bytes(acceptedPhysics.abiRecord)
    jointCommitBytes = Self.bytes(jointCommit.abiRecord)
    self.physicalCheckpointFingerprint = physicalCheckpointFingerprint
    contentSHA256 = Self.digest(root: self.root, substep: substepBytes,
      accepted: acceptedPhysicsBytes, commit: jointCommitBytes,
      checkpoint: physicalCheckpointFingerprint)
    _ = try validated()
  }

  @discardableResult
  public func validated() throws -> Self {
    let token = try root.validatedToken()
    guard version == Self.formatVersion, physicalCheckpointFingerprint > 0,
      substepBytes.count == BrainJointSubstepToken.byteCount,
      acceptedPhysicsBytes.count == AcceptedPhysicsStateToken.byteCount,
      jointCommitBytes.count == BrainJointCommitToken.byteCount,
      MemoryLayout<NBJointSubstepToken>.stride == substepBytes.count,
      MemoryLayout<NBAcceptedPhysicsStateToken>.stride == acceptedPhysicsBytes.count,
      MemoryLayout<NBJointCommitToken>.stride == jointCommitBytes.count,
      contentSHA256 == Self.digest(root: root, substep: substepBytes,
        accepted: acceptedPhysicsBytes, commit: jointCommitBytes,
        checkpoint: physicalCheckpointFingerprint) else {
      throw BrainRuntimeError.transaction("prepared native receipt format, ABI or SHA-256 mismatch")
    }
    var rootRecord = token.abiRecord
    var substep = substepBytes.withUnsafeBytes { $0.loadUnaligned(as: NBJointSubstepToken.self) }
    var accepted = acceptedPhysicsBytes.withUnsafeBytes { $0.loadUnaligned(as: NBAcceptedPhysicsStateToken.self) }
    var commit = jointCommitBytes.withUnsafeBytes { $0.loadUnaligned(as: NBJointCommitToken.self) }
    let substepStatus = withUnsafePointer(to: &rootRecord) { r in
      withUnsafePointer(to: &substep) { s in nb_brain_abi_validate_joint_substep(r, s) }
    }
    let acceptedStatus = withUnsafePointer(to: &rootRecord) { r in
      withUnsafePointer(to: &substep) { s in
        withUnsafePointer(to: &accepted) { a in nb_brain_abi_validate_accepted_physics_state(r, s, a) }
      }
    }
    let commitStatus = withUnsafePointer(to: &rootRecord) { r in
      withUnsafePointer(to: &accepted) { a in
        withUnsafePointer(to: &commit) { c in nb_brain_abi_validate_joint_commit(r, a, c) }
      }
    }
    let nextPhysics = token.basePhysicsGeneration.addingReportingOverflow(1)
    guard substepStatus == UInt32(NB_JOINT_TRANSACTION_VALID.rawValue),
      acceptedStatus == UInt32(NB_JOINT_TRANSACTION_VALID.rawValue),
      commitStatus == UInt32(NB_JOINT_TRANSACTION_VALID.rawValue),
      !nextPhysics.overflow, substep.substep_index == 0,
      substep.start_timestamp_microseconds == token.committedTimestamp.rawValue,
      substep.candidate_timestamp_microseconds == token.targetTimestamp.rawValue,
      accepted.physics_generation == nextPhysics.partialValue,
      commit.physics_generation == accepted.physics_generation else {
      throw BrainRuntimeError.transaction("saved native accepted/commit records do not validate against this whole-root candidate")
    }
    return self
  }

  public func acceptedPhysicsToken() throws -> AcceptedPhysicsStateToken {
    _ = try validated()
    let token = try root.validatedToken()
    let substep = try nativeSubstep(validatedRoot: token)
    let record = acceptedPhysicsBytes.withUnsafeBytes { $0.loadUnaligned(as: NBAcceptedPhysicsStateToken.self) }
    return try AcceptedPhysicsStateToken(validating: record, transaction: token, substep: substep)
  }

  public func substepToken() throws -> BrainJointSubstepToken {
    _ = try validated()
    return try nativeSubstep(validatedRoot: root.validatedToken())
  }

  public func jointCommitFingerprint() throws -> UInt64 {
    _ = try validated()
    return jointCommitBytes.withUnsafeBytes { $0.loadUnaligned(as: NBJointCommitToken.self).commit_fingerprint }
  }

  private func nativeSubstep(validatedRoot token: BrainJointTransactionToken) throws -> BrainJointSubstepToken {
    let saved = substepBytes.withUnsafeBytes { $0.loadUnaligned(as: NBJointSubstepToken.self) }
    let value = try BrainJointSubstepToken(transaction: token, substepIndex: saved.substep_index,
      attemptIndex: saved.attempt_index,
      startTimestamp: BrainTimestamp(microseconds: saved.start_timestamp_microseconds),
      durationMicroseconds: saved.duration_microseconds)
    guard Self.bytes(value.abiRecord) == substepBytes else {
      throw BrainRuntimeError.transaction("saved substep is not the canonical native ABI record")
    }
    return value
  }

  private static func bytes<T>(_ value: T) -> Data {
    var copy = value
    return withUnsafeBytes(of: &copy) { Data($0) }
  }
  private static func digest(root: BrainPreparedRoot, substep: Data, accepted: Data,
    commit: Data, checkpoint: UInt64) -> String {
    var hash = SHA256()
    hash.update(data: Data("NumiBrain.prepared-native-receipts.v1\0".utf8))
    for scalar in [UInt64(Self.formatVersion), root.fingerprint, checkpoint] {
      var little = scalar.littleEndian
      withUnsafeBytes(of: &little) { hash.update(bufferPointer: $0) }
    }
    for data in [substep, accepted, commit] {
      var length = UInt64(data.count).littleEndian
      withUnsafeBytes(of: &length) { hash.update(bufferPointer: $0) }
      hash.update(data: data)
    }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
  }
}

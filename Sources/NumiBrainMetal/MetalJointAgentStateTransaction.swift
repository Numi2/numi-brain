import Foundation
import NumiBrainCore

@available(macOS 26.0, *)
public final class MetalJointAgentStateTransaction: @unchecked Sendable {
  @frozen
  public enum Status: Equatable, Sendable {
    case open
    case gpuStateFinished
    case commitPrepared
    case committed
    case aborted
  }

  public let jointToken: BrainJointTransactionToken
  public let agentStateToken: MetalAgentStateTransactionToken
  public let cachedDecisionFingerprint: UInt64
  public let cachedRandomCounterGeneration: UInt64
  public private(set) var status: Status = .open
  public private(set) var acceptedPhysicsTokenFingerprint: UInt64?

  private let runtime: MetalAgentStateRuntime
  private let lock = NSLock()
  private var preparedCommit: MetalAgentStateRuntime.PreparedCommit?

  public init(
    jointToken: BrainJointTransactionToken,
    runtime: MetalAgentStateRuntime,
    cachedDecisionFingerprint: UInt64
  ) throws {
    guard jointToken.parameterVersionFingerprint > 0,
      cachedDecisionFingerprint > 0,
      runtime.arena.committedGeneration == jointToken.baseBrainGeneration
    else {
      throw TissueError.transaction(
        "joint brain-state transaction does not match committed generation"
      )
    }
    let agentStateToken = try runtime.beginShadow(
      expectedBaseGeneration: jointToken.baseBrainGeneration
    )
    guard agentStateToken.shadowGeneration == jointToken.shadowGeneration else {
      try? runtime.abort(transaction: agentStateToken)
      throw TissueError.transaction("joint and complete-state shadow generations diverged")
    }
    self.jointToken = jointToken
    self.agentStateToken = agentStateToken
    self.cachedDecisionFingerprint = cachedDecisionFingerprint
    self.cachedRandomCounterGeneration = jointToken.randomCounterGeneration
    self.runtime = runtime
  }

  public func hotStateView() throws -> MetalAgentStateArena.HotStateView {
    lock.lock()
    defer { lock.unlock() }
    try require(.open)
    return try runtime.hotStateView(transaction: agentStateToken)
  }

  public func persistentMemoryView() throws -> MetalAgentStateArena.PersistentMemoryView {
    lock.lock()
    defer { lock.unlock() }
    try require(.open)
    return try runtime.persistentMemoryView(transaction: agentStateToken)
  }

  /// Finishes all hot-state kernels and applies only accepted root memory
  /// mutations. Rejected substep mutations must never be emitted to this root
  /// journal.
  public func finishGPUState(
    acceptedPhysicsState: AcceptedPhysicsStateToken
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try require(.open)
    guard acceptedPhysicsState.transactionFingerprint == jointToken.fingerprint,
      acceptedPhysicsState.environmentIdentifier == jointToken.environmentIdentifier,
      acceptedPhysicsState.acceptedTimestamp == jointToken.targetTimestamp,
      acceptedPhysicsState.physicsGeneration > jointToken.basePhysicsGeneration
    else {
      throw TissueError.transaction(
        "accepted physical consequence does not complete this joint root"
      )
    }
    try runtime.validateMemoryJournalAndFinish(transaction: agentStateToken)
    acceptedPhysicsTokenFingerprint = acceptedPhysicsState.fingerprint
    status = .gpuStateFinished
  }

  public func commit(with receipt: BrainJointCommitToken) throws {
    try prepareCommit(with: receipt)
    publishPreparedCommit()
  }

  func prepareCommit(with receipt: BrainJointCommitToken) throws {
    lock.lock()
    defer { lock.unlock() }
    try require(.gpuStateFinished)
    guard receipt.transactionFingerprint == jointToken.fingerprint,
      receipt.brainGeneration == agentStateToken.shadowGeneration,
      receipt.committedTimestamp == jointToken.targetTimestamp,
      receipt.parameterVersionFingerprint == jointToken.parameterVersionFingerprint,
      receipt.acceptedPhysicsTokenFingerprint == acceptedPhysicsTokenFingerprint
    else {
      throw TissueError.transaction(
        "joint receipt cannot publish the complete agent-state generation"
      )
    }
    preparedCommit = try runtime.prepareCommit(transaction: agentStateToken)
    status = .commitPrepared
  }

  /// All receipt and arena conditions were checked by `prepareCommit`. This
  /// method performs only non-failing committed-generation publication.
  func publishPreparedCommit() {
    lock.lock()
    defer { lock.unlock() }
    guard status == .commitPrepared, let preparedCommit else {
      preconditionFailure("joint cognitive commit was not prepared")
    }
    runtime.publishPreparedCommit(preparedCommit)
    self.preparedCommit = nil
    status = .committed
  }

  public func abort() throws {
    lock.lock()
    defer { lock.unlock() }
    guard status == .open || status == .gpuStateFinished
      || status == .commitPrepared
    else {
      throw TissueError.transaction("joint brain-state transaction is already \(status)")
    }
    try runtime.abort(transaction: agentStateToken)
    acceptedPhysicsTokenFingerprint = nil
    preparedCommit = nil
    status = .aborted
  }

  private func require(_ expected: Status) throws {
    guard status == expected else {
      throw TissueError.transaction(
        "joint brain-state transaction is \(status), expected \(expected)"
      )
    }
  }
}

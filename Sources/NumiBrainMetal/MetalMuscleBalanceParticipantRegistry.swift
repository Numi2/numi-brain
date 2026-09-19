import Foundation
import NumiBrainCore

/// Narrow coordination point between the locomotor controller, which receives
/// the stable root token, and the owning joint transaction. Entries are keyed
/// by the complete root identity. A duplicate live root is rejected rather than
/// allowing one controller candidate to be published by another environment.
@available(macOS 26.0, *)
enum MetalMuscleBalanceParticipantRegistry {
  private final class WeakTransaction: @unchecked Sendable {
    weak var value: MetalJointAgentStateTransaction?
    init(_ value: MetalJointAgentStateTransaction) { self.value = value }
  }

  private struct Entry: @unchecked Sendable {
    let transaction: WeakTransaction
    var candidate: MetalMuscleBalanceController.Candidate?
  }

  private static let lock = NSLock()
  private nonisolated(unsafe) static var entries:
    [BrainJointTransactionToken: Entry] = [:]

  static func register(_ transaction: MetalJointAgentStateTransaction) throws {
    var staleCandidate: MetalMuscleBalanceController.Candidate?
    lock.lock()
    let root = transaction.jointToken
    if let existing = entries[root], existing.transaction.value == nil {
      staleCandidate = existing.candidate
      entries.removeValue(forKey: root)
    }
    guard entries[root] == nil else {
      lock.unlock()
      staleCandidate?.abort()
      throw TissueError.transaction(
        "duplicate live joint root cannot own muscle balance state"
      )
    }
    entries[root] = Entry(
      transaction: WeakTransaction(transaction),
      candidate: nil
    )
    lock.unlock()
    staleCandidate?.abort()
  }

  static func bind(
    _ candidate: MetalMuscleBalanceController.Candidate,
    to root: BrainJointTransactionToken
  ) throws {
    var staleCandidate: MetalMuscleBalanceController.Candidate?
    lock.lock()
    if let existing = entries[root], existing.transaction.value == nil {
      staleCandidate = existing.candidate
      entries.removeValue(forKey: root)
    }
    guard candidate.root == root,
      var entry = entries[root],
      let transaction = entry.transaction.value,
      transaction.jointToken == root,
      entry.candidate == nil
    else {
      lock.unlock()
      staleCandidate?.abort()
      candidate.abort()
      throw TissueError.transaction(
        "muscle balance candidate has no unique live owning transaction"
      )
    }
    entry.candidate = candidate
    entries[root] = entry
    lock.unlock()
    staleCandidate?.abort()
  }

  static func candidate(
    for transaction: MetalJointAgentStateTransaction
  ) throws -> MetalMuscleBalanceController.Candidate? {
    var staleCandidate: MetalMuscleBalanceController.Candidate?
    let result: MetalMuscleBalanceController.Candidate?
    lock.lock()
    if let existing = entries[transaction.jointToken],
      existing.transaction.value == nil
    {
      staleCandidate = existing.candidate
      entries.removeValue(forKey: transaction.jointToken)
    }
    guard let entry = entries[transaction.jointToken],
      entry.transaction.value === transaction
    else {
      lock.unlock()
      staleCandidate?.abort()
      throw TissueError.transaction(
        "joint transaction is not registered for muscle balance participation"
      )
    }
    result = entry.candidate
    lock.unlock()
    staleCandidate?.abort()
    return result
  }

  static func validateCommit(
    transaction: MetalJointAgentStateTransaction,
    receipt: BrainJointCommitToken
  ) throws {
    try candidate(for: transaction)?.validateCommit(receipt)
  }

  static func hasTransactionalHistory(
    transaction: MetalJointAgentStateTransaction
  ) throws -> Bool {
    try candidate(for: transaction)?.historyCandidate != nil
  }

  static func publish(_ transaction: MetalJointAgentStateTransaction) {
    let candidate: MetalMuscleBalanceController.Candidate?
    lock.lock()
    guard let entry = entries[transaction.jointToken],
      entry.transaction.value === transaction
    else {
      lock.unlock()
      preconditionFailure(
        "joint transaction lost its muscle balance registry identity"
      )
    }
    candidate = entry.candidate
    entries.removeValue(forKey: transaction.jointToken)
    lock.unlock()
    candidate?.publish()
  }

  static func abort(_ transaction: MetalJointAgentStateTransaction) {
    let candidate: MetalMuscleBalanceController.Candidate?
    lock.lock()
    if let entry = entries[transaction.jointToken],
      entry.transaction.value === transaction
    {
      candidate = entry.candidate
      entries.removeValue(forKey: transaction.jointToken)
    } else {
      candidate = nil
    }
    lock.unlock()
    candidate?.abort()
  }
}

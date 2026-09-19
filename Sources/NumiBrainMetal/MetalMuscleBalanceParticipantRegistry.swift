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
    lock.lock()
    defer { lock.unlock() }
    removeDeadEntriesLocked()
    let root = transaction.jointToken
    guard entries[root] == nil else {
      throw TissueError.transaction(
        "duplicate live joint root cannot own muscle balance state"
      )
    }
    entries[root] = Entry(
      transaction: WeakTransaction(transaction),
      candidate: nil
    )
  }

  static func bind(
    _ candidate: MetalMuscleBalanceController.Candidate,
    to root: BrainJointTransactionToken
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    removeDeadEntriesLocked()
    guard candidate.root == root,
      var entry = entries[root],
      let transaction = entry.transaction.value,
      transaction.jointToken == root,
      transaction.status == .open,
      entry.candidate == nil
    else {
      candidate.abort()
      throw TissueError.transaction(
        "muscle balance candidate has no unique live owning transaction"
      )
    }
    entry.candidate = candidate
    entries[root] = entry
  }

  static func candidate(
    for transaction: MetalJointAgentStateTransaction
  ) throws -> MetalMuscleBalanceController.Candidate? {
    lock.lock()
    defer { lock.unlock() }
    removeDeadEntriesLocked()
    guard let entry = entries[transaction.jointToken],
      entry.transaction.value === transaction
    else {
      throw TissueError.transaction(
        "joint transaction is not registered for muscle balance participation"
      )
    }
    return entry.candidate
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

  private static func removeDeadEntriesLocked() {
    let dead = entries.compactMap { key, entry in
      entry.transaction.value == nil ? key : nil
    }
    for key in dead {
      entries[key]?.candidate?.abort()
      entries.removeValue(forKey: key)
    }
  }
}

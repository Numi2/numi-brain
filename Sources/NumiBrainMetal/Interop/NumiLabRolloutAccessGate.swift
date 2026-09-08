import Foundation

/// Serializes an entire owner operation, including nested snapshot/advance calls.
/// It does not synchronize GPU work, own a native handle, or roll physics back.
/// External access to the borrowed handle must still be prohibited by its owner.
final class NumiLabRolloutAccessGate: @unchecked Sendable {
  enum Failure: Error, Equatable { case quarantined(String) }
  private let lock = NSRecursiveLock()
  private var failure: Failure?

  func perform<T>(_ operation: () throws -> T) throws -> T {
    lock.lock()
    defer { lock.unlock() }
    if let failure { throw failure }
    let result = try operation()
    if let failure { throw failure }
    return result
  }

  /// Retain the first failure. Recovery requires a separate fresh physical world;
  /// neither subsequent inspection nor a successful nested call clears this state.
  func quarantine(_ reason: String) {
    lock.lock()
    defer { lock.unlock() }
    if failure == nil { failure = .quarantined(reason) }
  }
}

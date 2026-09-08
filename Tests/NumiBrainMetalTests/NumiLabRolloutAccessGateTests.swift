import Foundation
import XCTest
@testable import NumiBrainMetal

final class NumiLabRolloutAccessGateTests: XCTestCase {
  private enum TestFailure: Error { case expected }
  private final class Counter: @unchecked Sendable {
    var value = 0 // Accessed only through the tested owner gate.
    private let lock = NSLock()
    private var errors = 0
    func failed() { lock.lock(); defer { lock.unlock() }; errors += 1 }
    var failures: Int { lock.lock(); defer { lock.unlock() }; return errors }
  }

  func testNestedOperationsRemainExclusiveAcrossConcurrentCallers() {
    let gate = NumiLabRolloutAccessGate(), counter = Counter()
    DispatchQueue.concurrentPerform(iterations: 256) { _ in
      do {
        try gate.perform {
          let before = counter.value
          let next = try gate.perform { before + 1 }
          counter.value = next
        }
      } catch { counter.failed() }
    }
    XCTAssertEqual(counter.value, 256)
    XCTAssertEqual(counter.failures, 0)
  }

  func testNonMutatingPreflightFailureDoesNotQuarantine() throws {
    let gate = NumiLabRolloutAccessGate()
    XCTAssertThrowsError(try gate.perform { throw TestFailure.expected })
    XCTAssertEqual(try gate.perform { 7 }, 7)
  }

  func testQuarantineIsTerminalPreservesFirstErrorAndPreventsExecution() {
    let gate = NumiLabRolloutAccessGate()
    gate.quarantine("native failure")
    gate.quarantine("later failure")
    var called = false
    XCTAssertThrowsError(try gate.perform { called = true }) { error in
      XCTAssertEqual(error as? NumiLabRolloutAccessGate.Failure, .quarantined("native failure"))
    }
    XCTAssertFalse(called)
  }

  func testNestedQuarantineCannotBeClearedByReturningNormally() throws {
    let gate = NumiLabRolloutAccessGate()
    XCTAssertThrowsError(try gate.perform { gate.quarantine("replay diverged") })
    XCTAssertThrowsError(try gate.perform { 1 })
  }
}

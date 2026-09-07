import Foundation
import XCTest
@testable import NumiBrainQualification

final class WatchdogCommittedIdentityTests: XCTestCase {
  private let process = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
  private func heartbeat(sequence: UInt64 = 1, time: UInt64 = 100,
    generation: UInt64 = 7, fingerprint: UInt64 = 70) throws -> WatchdogHeartbeat {
    try WatchdogHeartbeat(processInstance: process, sequence: sequence, monotonicNanoseconds: time,
      publicGeneration: generation, transactionFingerprint: fingerprint)
  }
  private func monitor() throws -> WatchdogMonitor {
    try WatchdogMonitor(expectedProcessInstance: process, maximumAgeNanoseconds: 1_000,
      maximumProgressAgeNanoseconds: 2_000)
  }

  func testFreshHeartbeatCannotReplaceFingerprintWithoutPublication() throws {
    var monitor = try monitor()
    XCTAssertFalse(monitor.observe(try heartbeat(), nowNanoseconds: 110).mustRequestSafeState)
    let fault = monitor.observe(try heartbeat(sequence: 2, time: 200, fingerprint: 71), nowNanoseconds: 210)
    XCTAssertEqual(fault.status, .regressed)
    XCTAssertEqual(fault.reason, "committed_identity_changed_without_publication")
    XCTAssertTrue(fault.mustRequestSafeState)
    // A later publication cannot erase the earlier identity violation.
    XCTAssertEqual(monitor.observe(try heartbeat(sequence: 3, time: 300, generation: 8, fingerprint: 80),
      nowNanoseconds: 310), fault)
  }

  func testRestoredRejectionMayAdvanceHeartbeatButNotPublicIdentity() throws {
    var monitor = try monitor()
    XCTAssertFalse(monitor.observe(try heartbeat(), nowNanoseconds: 110).mustRequestSafeState)
    XCTAssertFalse(monitor.observe(try heartbeat(sequence: 2, time: 200), nowNanoseconds: 210).mustRequestSafeState)
  }

  func testAcceptedPublicationMayAdvanceGenerationAndFingerprint() throws {
    var monitor = try monitor()
    XCTAssertFalse(monitor.observe(try heartbeat(), nowNanoseconds: 110).mustRequestSafeState)
    XCTAssertFalse(monitor.observe(try heartbeat(sequence: 2, time: 200, generation: 8, fingerprint: 80),
      nowNanoseconds: 210).mustRequestSafeState)
  }
}

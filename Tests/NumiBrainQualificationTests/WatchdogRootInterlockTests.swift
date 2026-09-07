import Foundation
import XCTest
@testable import NumiBrainQualification

final class WatchdogRootInterlockTests: XCTestCase {
  private let process = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
  private let enforcer = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
  private let digest = String(repeating: "b", count: 64)
  private func interlock() -> WatchdogRootInterlock {
    WatchdogRootInterlock(expectedProcessInstance: process, enforcerInstance: enforcer)
  }
  private func stop(process: UUID? = nil, reason: String = "stale") throws -> WatchdogStopRequest {
    try WatchdogStopRequest(watchdogInstance: UUID(), expectedProcessInstance: process ?? self.process,
      observed: nil, reason: reason, createdUnixNanoseconds: 1_000)
  }
  @discardableResult
  private func settle(_ gate: WatchdogRootInterlock, _ permit: WatchdogRootInterlock.Permit,
    generation: UInt64 = 7, fingerprint: UInt64 = 70, time: UInt64 = 100) throws -> WatchdogHeartbeat {
    try gate.recordSettledRoot(permit, publicGeneration: generation, transactionFingerprint: fingerprint,
      settledMonotonicNanoseconds: time, terminalEvidenceArtifactSHA256: digest)
  }

  func testEmptyOwnerCannotFabricateAcknowledgement() throws {
    let gate = interlock(); try gate.latchStop(stop())
    XCTAssertThrowsError(try gate.makeSimulationAcknowledgement(nowNanoseconds: 200))
    XCTAssertThrowsError(try gate.beginRoot())
  }
  func testPermitsAreSingleUseAndOnlyOneRootCanExecute() throws {
    let gate = interlock(), permit = try gate.beginRoot()
    XCTAssertThrowsError(try gate.beginRoot())
    try settle(gate, permit)
    XCTAssertThrowsError(try settle(gate, permit))
    XCTAssertThrowsError(try gate.recordIndeterminateRoot(permit))
  }
  func testForeignPermitCannotSettleOrInvalidateRealRoot() throws {
    let gate = interlock(), foreign = interlock()
    let permit = try gate.beginRoot(), other = try foreign.beginRoot()
    XCTAssertThrowsError(try settle(gate, other))
    XCTAssertThrowsError(try gate.recordIndeterminateRoot(other))
    XCTAssertNoThrow(try settle(gate, permit))
  }
  func testStopClosesAdmissionBeforeInFlightRootDrains() throws {
    let gate = interlock(), permit = try gate.beginRoot(), request = try stop()
    try gate.latchStop(request)
    XCTAssertTrue(gate.admissionClosed)
    XCTAssertThrowsError(try gate.beginRoot())
    XCTAssertThrowsError(try gate.makeSimulationAcknowledgement(nowNanoseconds: 200))
    try settle(gate, permit)
    let acknowledgement = try gate.makeSimulationAcknowledgement(nowNanoseconds: 200)
    XCTAssertEqual(acknowledgement.request, request)
    XCTAssertEqual(acknowledgement.effect, .simulationRootsQuiesced)
    XCTAssertEqual(acknowledgement.terminalEvidenceArtifactSHA256, digest)
    XCTAssertThrowsError(try gate.beginRoot())
  }
  func testIdleSettledOwnerCanAcknowledgeButCannotResume() throws {
    let gate = interlock(); try settle(gate, gate.beginRoot())
    let request = try stop(); try gate.latchStop(request); try gate.latchStop(request)
    XCTAssertNoThrow(try gate.makeSimulationAcknowledgement(nowNanoseconds: 200))
    XCTAssertThrowsError(try gate.beginRoot())
  }
  func testRestoredRejectionKeepsCommittedAuthority() throws {
    let gate = interlock(); try settle(gate, gate.beginRoot())
    let second = try settle(gate, gate.beginRoot(), time: 200)
    XCTAssertEqual(second.publicGeneration, 7)
    XCTAssertEqual(second.transactionFingerprint, 70)
    XCTAssertEqual(second.sequence, 2)
    let third = try settle(gate, gate.beginRoot(), generation: 8, fingerprint: 80, time: 300)
    XCTAssertEqual(third.sequence, 3)
  }
  func testRejectedCandidateCannotReplacePublishedFingerprint() throws {
    let gate = interlock(); try settle(gate, gate.beginRoot())
    XCTAssertThrowsError(try settle(gate, gate.beginRoot(), fingerprint: 999, time: 200))
    XCTAssertTrue(gate.admissionClosed)
  }
  func testGenerationSkipAndTimeRegressionFailClosed() throws {
    for skip in [false, true] {
      let gate = interlock(); try settle(gate, gate.beginRoot())
      XCTAssertThrowsError(try settle(gate, gate.beginRoot(), generation: skip ? 9 : 7, time: skip ? 200 : 99))
      XCTAssertTrue(gate.admissionClosed)
    }
  }
  func testIndeterminateRootCanNeverAcknowledge() throws {
    let gate = interlock(); try settle(gate, gate.beginRoot())
    let permit = try gate.beginRoot(); try gate.latchStop(stop())
    try gate.recordIndeterminateRoot(permit)
    XCTAssertThrowsError(try gate.makeSimulationAcknowledgement(nowNanoseconds: 200))
    XCTAssertThrowsError(try gate.beginRoot())
  }
  func testTransportFaultCannotBeClearedByLaterSettlement() throws {
    let gate = interlock(), permit = try gate.beginRoot()
    gate.failClosed(); try gate.latchStop(stop()); try settle(gate, permit)
    XCTAssertNotNil(gate.lastSettledHeartbeat)
    XCTAssertThrowsError(try gate.makeSimulationAcknowledgement(nowNanoseconds: 200))
    XCTAssertThrowsError(try gate.beginRoot())
  }
  func testForeignStopFailsClosed() throws {
    let gate = interlock()
    XCTAssertThrowsError(try gate.latchStop(stop(process: UUID())))
    XCTAssertTrue(gate.admissionClosed)
    XCTAssertNil(gate.retainedStopRequest)
  }
  func testConflictingFaultRetainsFirstRequest() throws {
    let gate = interlock(), first = try stop()
    try gate.latchStop(first)
    XCTAssertThrowsError(try gate.latchStop(stop(reason: "different")))
    XCTAssertEqual(gate.retainedStopRequest, first)
  }
  func testMalformedEvidenceCannotAdvanceSettledHeartbeat() throws {
    let gate = interlock(), permit = try gate.beginRoot()
    XCTAssertThrowsError(try gate.recordSettledRoot(permit, publicGeneration: 7, transactionFingerprint: 70,
      settledMonotonicNanoseconds: 100, terminalEvidenceArtifactSHA256: "not-a-hash"))
    XCTAssertNil(gate.lastSettledHeartbeat)
    XCTAssertTrue(gate.admissionClosed)
  }
  func testConcurrentAdmissionAfterStopIsDenied() throws {
    let gate = interlock(); try settle(gate, gate.beginRoot()); try gate.latchStop(stop())
    DispatchQueue.concurrentPerform(iterations: 32) { _ in
      do { _ = try gate.beginRoot(); XCTFail("stopped owner admitted a root") }
      catch { /* Expected: every concurrent admission remains closed. */ }
    }
    XCTAssertNoThrow(try gate.makeSimulationAcknowledgement(nowNanoseconds: 200))
  }
}

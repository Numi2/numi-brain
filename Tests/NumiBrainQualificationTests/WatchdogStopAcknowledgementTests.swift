import Foundation
import XCTest
@testable import NumiBrainQualification

final class WatchdogStopAcknowledgementTests: XCTestCase {
  private let process = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
  private let enforcer = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
  private let watchdog = UUID(uuidString: "00000000-0000-4000-8000-000000000003")!
  private let digest = String(repeating: "a", count: 64)

  private func heartbeat(generation: UInt64 = 7, fingerprint: UInt64 = 70,
    sequence: UInt64 = 1, time: UInt64 = 100, process: UUID? = nil) throws -> WatchdogHeartbeat {
    try WatchdogHeartbeat(processInstance: process ?? self.process, sequence: sequence,
      monotonicNanoseconds: time, publicGeneration: generation, transactionFingerprint: fingerprint)
  }
  private func request(reason: String = "heartbeat_stale", observed: WatchdogHeartbeat? = nil) throws -> WatchdogStopRequest {
    try WatchdogStopRequest(watchdogInstance: watchdog, expectedProcessInstance: process,
      observed: observed ?? heartbeat(), reason: reason, createdUnixNanoseconds: 1_000)
  }
  private func acknowledgement(request: WatchdogStopRequest? = nil, enforcer: UUID? = nil,
    effect: WatchdogStopEffect = .simulationRootsQuiesced, time: UInt64 = 250,
    heartbeat: WatchdogHeartbeat? = nil) throws -> WatchdogStopAcknowledgement {
    try WatchdogStopAcknowledgement(request: request ?? self.request(), enforcerInstance: enforcer ?? self.enforcer,
      effect: effect, settledHeartbeat: heartbeat ?? self.heartbeat(),
      acknowledgedMonotonicNanoseconds: time, terminalEvidenceArtifactSHA256: digest)
  }
  private func supervisor(request: WatchdogStopRequest? = nil) throws -> WatchdogStopSupervisor {
    try WatchdogStopSupervisor(request: request ?? self.request(), expectedEnforcerInstance: enforcer,
      requiredEffect: .simulationRootsQuiesced, requestedMonotonicNanoseconds: 200,
      maximumAcknowledgementAgeNanoseconds: 100)
  }
  private func changedJSON(_ value: WatchdogStopAcknowledgement,
    _ change: (inout [String: Any]) -> Void) throws -> Data {
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    change(&object); return try JSONSerialization.data(withJSONObject: object)
  }
  private func withDirectory(_ body: (URL) throws -> Void) throws {
    let url = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: url) }
    try body(url)
  }

  func testRoundTripPreservesCompleteFault() throws {
    let value = try acknowledgement()
    XCTAssertEqual(try JSONDecoder().decode(WatchdogStopAcknowledgement.self, from: JSONEncoder().encode(value)), value)
  }
  func testDecodeRejectsUnknownVersionAndMalformedEvidence() throws {
    let value = try acknowledgement()
    for key in ["formatVersion", "terminalEvidenceArtifactSHA256", "effect"] {
      let data = try changedJSON(value) { $0[key] = key == "formatVersion" ? 2 : "invalid" }
      XCTAssertThrowsError(try JSONDecoder().decode(WatchdogStopAcknowledgement.self, from: data))
    }
  }
  func testDecodeValidatesNestedRequest() throws {
    let data = try changedJSON(acknowledgement()) {
      var request = $0["request"] as! [String: Any]; request["reason"] = ""; $0["request"] = request
    }
    XCTAssertThrowsError(try JSONDecoder().decode(WatchdogStopAcknowledgement.self, from: data))
  }
  func testAcknowledgementRejectsForeignProcess() throws {
    XCTAssertThrowsError(try acknowledgement(heartbeat: heartbeat(process: UUID())))
  }
  func testAcknowledgementRejectsRegressedOrChangedAuthority() throws {
    XCTAssertThrowsError(try acknowledgement(heartbeat: heartbeat(generation: 6)))
    XCTAssertThrowsError(try acknowledgement(heartbeat: heartbeat(fingerprint: 71)))
    XCTAssertThrowsError(try acknowledgement(heartbeat: heartbeat(sequence: 0)))
    XCTAssertThrowsError(try acknowledgement(heartbeat: heartbeat(time: 99)))
  }
  func testInFlightAcceptedRootMaySettleAfterFault() throws {
    let value = try acknowledgement(heartbeat: heartbeat(generation: 8, fingerprint: 80, sequence: 2, time: 220))
    var monitor = try supervisor()
    XCTAssertEqual(monitor.observe(value, nowNanoseconds: 250), .acknowledgedReport)
  }
  func testRestartObservationDoesNotTransplantForeignGenerations() throws {
    let fault = try request(observed: heartbeat(generation: 999, sequence: 999, process: UUID()))
    XCTAssertNoThrow(try acknowledgement(request: fault))
  }
  func testAcknowledgementCannotPrecedeSettlement() throws {
    XCTAssertThrowsError(try acknowledgement(time: 99))
  }
  func testMissingReportStaysStoppedAndDeadlineIsInclusive() throws {
    var monitor = try supervisor()
    XCTAssertEqual(monitor.observe(nil, nowNanoseconds: 299), .awaitingAcknowledgement)
    let status = monitor.observe(try acknowledgement(time: 300), nowNanoseconds: 300)
    XCTAssertEqual(status, .acknowledgedReport)
    XCTAssertTrue(status.mustKeepStopped)
    XCTAssertFalse(status.requiresEscalation)
  }
  func testLateReceiptCannotRepairExpiredDeadline() throws {
    var monitor = try supervisor()
    XCTAssertEqual(monitor.observe(nil, nowNanoseconds: 301), .deadlineExceeded)
    XCTAssertEqual(monitor.observe(try acknowledgement(), nowNanoseconds: 302), .deadlineExceeded)
    XCTAssertNil(monitor.acknowledgement)
  }
  func testSameProcessDifferentFaultCannotAcknowledge() throws {
    var monitor = try supervisor()
    let value = try acknowledgement(request: request(reason: "different_fault"))
    XCTAssertEqual(monitor.observe(value, nowNanoseconds: 250), .invalidAcknowledgement)
  }
  func testWrongEnforcerCannotAcknowledge() throws {
    var monitor = try supervisor()
    XCTAssertEqual(monitor.observe(try acknowledgement(enforcer: UUID()), nowNanoseconds: 250), .invalidAcknowledgement)
  }
  func testSimulationReportCannotSatisfyActuatorInhibitRequirement() throws {
    var monitor = try WatchdogStopSupervisor(request: request(), expectedEnforcerInstance: enforcer,
      requiredEffect: .externalActuatorsInhibited, requestedMonotonicNanoseconds: 200,
      maximumAcknowledgementAgeNanoseconds: 100)
    XCTAssertEqual(monitor.observe(try acknowledgement(), nowNanoseconds: 250), .invalidAcknowledgement)
  }
  func testPredatedAndFutureReportsFail() throws {
    for time: UInt64 in [199, 251] {
      var monitor = try supervisor()
      XCTAssertEqual(monitor.observe(try acknowledgement(time: time), nowNanoseconds: 250), .invalidAcknowledgement)
    }
  }
  func testUnreadableReportLatchesFailure() throws {
    var monitor = try supervisor()
    XCTAssertEqual(monitor.observe(nil, readFailed: true, nowNanoseconds: 220), .invalidAcknowledgement)
    XCTAssertEqual(monitor.observe(try acknowledgement(), nowNanoseconds: 250), .invalidAcknowledgement)
  }
  func testClockRegressionFailsWithoutUnsignedUnderflow() throws {
    var monitor = try supervisor()
    XCTAssertEqual(monitor.observe(nil, nowNanoseconds: 199), .clockRegressed)
    XCTAssertTrue(WatchdogStopSupervisionStatus.clockRegressed.requiresEscalation)
  }
  func testDeadlineArithmeticDoesNotOverflowNearUInt64Maximum() throws {
    var monitor = try WatchdogStopSupervisor(request: request(), expectedEnforcerInstance: enforcer,
      requiredEffect: .simulationRootsQuiesced, requestedMonotonicNanoseconds: UInt64.max - 10,
      maximumAcknowledgementAgeNanoseconds: 20)
    XCTAssertEqual(monitor.observe(nil, nowNanoseconds: UInt64.max), .awaitingAcknowledgement)
  }
  func testStickyPublicationReturnsActualFirstRequest() throws {
    try withDirectory { directory in
      let url = directory.appendingPathComponent("stop.json"), first = try request()
      XCTAssertEqual(try WatchdogFileProtocol.publishAndReadStopRequest(first, to: url), first)
      XCTAssertEqual(try WatchdogFileProtocol.publishAndReadStopRequest(request(reason: "later"), to: url), first)
    }
  }
  func testAcknowledgementIsCreateOnlyAndExactlyIdempotent() throws {
    try withDirectory { directory in
      let url = directory.appendingPathComponent("ack.json"), first = try acknowledgement()
      XCTAssertNil(try WatchdogFileProtocol.readStopAcknowledgementIfPresent(url))
      try WatchdogFileProtocol.publishStopAcknowledgement(first, to: url)
      try WatchdogFileProtocol.publishStopAcknowledgement(first, to: url)
      XCTAssertThrowsError(try WatchdogFileProtocol.publishStopAcknowledgement(acknowledgement(time: 260), to: url))
      XCTAssertEqual(try WatchdogFileProtocol.readStopAcknowledgementIfPresent(url), first)
    }
  }
  func testAcknowledgementTransportRejectsSymlinkAndMalformedJSON() throws {
    try withDirectory { directory in
      let leaf = directory.appendingPathComponent("ack.json"), alias = directory.appendingPathComponent("alias.json")
      try Data("{}".utf8).write(to: leaf)
      try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: leaf)
      XCTAssertThrowsError(try WatchdogFileProtocol.readStopAcknowledgementIfPresent(leaf))
      XCTAssertThrowsError(try WatchdogFileProtocol.readStopAcknowledgementIfPresent(alias))
      XCTAssertThrowsError(try WatchdogFileProtocol.publishStopAcknowledgement(acknowledgement(), to: alias))
    }
  }
}

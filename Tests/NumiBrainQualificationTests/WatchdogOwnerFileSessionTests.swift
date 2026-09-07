import Foundation
import XCTest
@testable import NumiBrainQualification

final class WatchdogOwnerFileSessionTests: XCTestCase {
  private let process = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
  private let enforcer = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
  private func withDirectory(_ body: (URL) throws -> Void) throws {
    let url = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: url) }
    try body(url)
  }
  private func configuration(_ directory: URL) throws -> WatchdogOwnerFileConfiguration {
    try WatchdogOwnerFileConfiguration(processInstance: process, enforcerInstance: enforcer, directoryPath: directory.path)
  }
  private func stop(_ directory: URL, process: UUID? = nil) throws -> WatchdogStopRequest {
    let value = try WatchdogStopRequest(watchdogInstance: UUID(), expectedProcessInstance: process ?? self.process,
      observed: nil, reason: "heartbeat_missing", createdUnixNanoseconds: 1_000)
    try WatchdogFileProtocol.publishStopRequest(value, to: directory.appendingPathComponent("stop.json"))
    return value
  }
  private func settle(_ session: WatchdogOwnerFileSession, _ permit: WatchdogRootInterlock.Permit) throws {
    try session.recordSettledRoot(permit, publicGeneration: 1, transactionFingerprint: 10,
      settledMonotonicNanoseconds: 100, terminalEvidenceArtifactSHA256: String(repeating: "c", count: 64))
  }

  func testConfigurationRejectsAliasesTraversalAndReservedLockNames() throws {
    for name in ["stop.json", "..", "nested/name", ".watchdog-owner.lock", ".watchdog-supervisor.lock"] {
      XCTAssertThrowsError(try WatchdogOwnerFileConfiguration(processInstance: process, enforcerInstance: enforcer,
        directoryPath: "/tmp", heartbeatName: name))
    }
    XCTAssertThrowsError(try WatchdogOwnerFileConfiguration(processInstance: process, enforcerInstance: enforcer, directoryPath: "relative"))
    XCTAssertThrowsError(try WatchdogOwnerFileConfiguration(processInstance: process, enforcerInstance: enforcer, directoryPath: "/tmp/../tmp"))
  }
  func testDecodeValidatesConfigurationAndAppliesDocumentedNames() throws {
    let data = try JSONSerialization.data(withJSONObject: ["processInstance": process.uuidString,
      "enforcerInstance": enforcer.uuidString, "directoryPath": "/tmp"])
    let config = try JSONDecoder().decode(WatchdogOwnerFileConfiguration.self, from: data)
    XCTAssertEqual(config.heartbeatName, "heartbeat.json")
    let invalid = try JSONSerialization.data(withJSONObject: ["processInstance": process.uuidString,
      "enforcerInstance": enforcer.uuidString, "directoryPath": "relative"])
    XCTAssertThrowsError(try JSONDecoder().decode(WatchdogOwnerFileConfiguration.self, from: invalid))
  }
  func testOnlyOneOwnerCanHoldDirectoryLock() throws {
    try withDirectory { directory in
      let first = try WatchdogOwnerFileSession(configuration: configuration(directory))
      XCTAssertThrowsError(try WatchdogOwnerFileSession(configuration: configuration(directory)))
      XCTAssertFalse(first.admissionClosed)
    }
  }
  func testPreexistingStopPreventsAnyNativeAdmission() throws {
    try withDirectory { directory in
      _ = try stop(directory)
      let session = try WatchdogOwnerFileSession(configuration: configuration(directory))
      XCTAssertThrowsError(try session.beginRoot(nowNanoseconds: 10))
      XCTAssertTrue(session.admissionClosed)
      XCTAssertNil(try WatchdogFileProtocol.readStopAcknowledgementIfPresent(directory.appendingPathComponent("stop-ack.json")))
    }
  }
  func testForeignStopFailsSessionConstruction() throws {
    try withDirectory { directory in
      _ = try stop(directory, process: UUID())
      XCTAssertThrowsError(try WatchdogOwnerFileSession(configuration: configuration(directory)))
    }
  }
  func testExistingHeartbeatOrAcknowledgementCannotBeReusedOnRestart() throws {
    for name in ["heartbeat.json", "stop-ack.json"] {
      try withDirectory { directory in
        try Data("{}".utf8).write(to: directory.appendingPathComponent(name))
        XCTAssertThrowsError(try WatchdogOwnerFileSession(configuration: configuration(directory)))
      }
    }
  }
  func testTerminalRootPublishesOnlyItsSettledHeartbeat() throws {
    try withDirectory { directory in
      let session = try WatchdogOwnerFileSession(configuration: configuration(directory))
      let permit = try session.beginRoot(nowNanoseconds: 10)
      XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("heartbeat.json").path))
      try settle(session, permit)
      let heartbeat = try WatchdogFileProtocol.readHeartbeat(directory.appendingPathComponent("heartbeat.json"))
      XCTAssertEqual(heartbeat, session.lastSettledHeartbeat)
      XCTAssertEqual(heartbeat.publicGeneration, 1)
      XCTAssertFalse(session.admissionClosed)
    }
  }
  func testInFlightStopAcknowledgesOnlyAfterDrain() throws {
    try withDirectory { directory in
      let session = try WatchdogOwnerFileSession(configuration: configuration(directory))
      let permit = try session.beginRoot(nowNanoseconds: 10), request = try stop(directory)
      try session.poll(nowNanoseconds: 20)
      XCTAssertTrue(session.admissionClosed)
      XCTAssertNil(try WatchdogFileProtocol.readStopAcknowledgementIfPresent(directory.appendingPathComponent("stop-ack.json")))
      try settle(session, permit)
      let ack = try XCTUnwrap(WatchdogFileProtocol.readStopAcknowledgementIfPresent(directory.appendingPathComponent("stop-ack.json")))
      XCTAssertEqual(ack.request, request)
      XCTAssertEqual(ack.effect, .simulationRootsQuiesced)
      XCTAssertThrowsError(try session.beginRoot(nowNanoseconds: 200))
    }
  }
  func testIdlePollingKeepsExactFirstAcknowledgementBytes() throws {
    try withDirectory { directory in
      let session = try WatchdogOwnerFileSession(configuration: configuration(directory))
      try settle(session, session.beginRoot(nowNanoseconds: 10)); _ = try stop(directory)
      try session.poll(nowNanoseconds: 200)
      let url = directory.appendingPathComponent("stop-ack.json"), first = try Data(contentsOf: url)
      try session.poll(nowNanoseconds: 300)
      XCTAssertEqual(try Data(contentsOf: url), first)
    }
  }
  func testRemovedStopDoesNotReopenAdmission() throws {
    try withDirectory { directory in
      let session = try WatchdogOwnerFileSession(configuration: configuration(directory))
      try settle(session, session.beginRoot(nowNanoseconds: 10)); _ = try stop(directory)
      try session.poll(nowNanoseconds: 200)
      try FileManager.default.removeItem(at: directory.appendingPathComponent("stop.json"))
      XCTAssertThrowsError(try session.poll(nowNanoseconds: 300))
      XCTAssertThrowsError(try session.beginRoot(nowNanoseconds: 400))
      XCTAssertTrue(session.admissionClosed)
    }
  }
  func testMalformedStopAfterStartupFailsClosed() throws {
    try withDirectory { directory in
      let session = try WatchdogOwnerFileSession(configuration: configuration(directory))
      try Data("{}".utf8).write(to: directory.appendingPathComponent("stop.json"))
      XCTAssertThrowsError(try session.beginRoot(nowNanoseconds: 10))
      XCTAssertTrue(session.admissionClosed)
    }
  }
  func testReportingFailureRetainsSettledIdentityButCannotAcknowledge() throws {
    try withDirectory { directory in
      let session = try WatchdogOwnerFileSession(configuration: configuration(directory))
      let permit = try session.beginRoot(nowNanoseconds: 10)
      let other = directory.appendingPathComponent("other.json")
      try Data("{}".utf8).write(to: other)
      try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("heartbeat.json"), withDestinationURL: other)
      XCTAssertThrowsError(try settle(session, permit))
      XCTAssertEqual(session.lastSettledHeartbeat?.publicGeneration, 1)
      XCTAssertTrue(session.admissionClosed)
      _ = try stop(directory)
      try session.poll(nowNanoseconds: 200)
      XCTAssertNil(try WatchdogFileProtocol.readStopAcknowledgementIfPresent(directory.appendingPathComponent("stop-ack.json")))
    }
  }
  func testIndeterminateRootNeverPublishesHeartbeatOrAcknowledgement() throws {
    try withDirectory { directory in
      let session = try WatchdogOwnerFileSession(configuration: configuration(directory))
      let permit = try session.beginRoot(nowNanoseconds: 10)
      try session.recordIndeterminateRoot(permit); _ = try stop(directory)
      try session.poll(nowNanoseconds: 200)
      XCTAssertNil(session.lastSettledHeartbeat)
      XCTAssertNil(try WatchdogFileProtocol.readStopAcknowledgementIfPresent(directory.appendingPathComponent("stop-ack.json")))
      XCTAssertThrowsError(try session.beginRoot(nowNanoseconds: 300))
    }
  }
}

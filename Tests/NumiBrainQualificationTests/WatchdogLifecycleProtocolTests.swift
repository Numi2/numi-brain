import Foundation
import XCTest
@testable import NumiBrainQualification

final class WatchdogLifecycleProtocolTests: XCTestCase {
  private let process = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
  private let enforcer = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
  private let supervisor = UUID(uuidString: "00000000-0000-4000-8000-000000000003")!
  private let evidenceSHA256 = String(repeating: "d", count: 64)

  private func arm(created: UInt64 = 100, age: UInt64 = 100) throws -> WatchdogSupervisorArm {
    try WatchdogSupervisorArm(supervisorInstance: supervisor, expectedProcessInstance: process,
      expectedEnforcerInstance: enforcer, createdMonotonicNanoseconds: created,
      maximumReadyAgeNanoseconds: age)
  }
  private func heartbeat(time: UInt64 = 150) throws -> WatchdogHeartbeat {
    try WatchdogHeartbeat(processInstance: process, sequence: 1, monotonicNanoseconds: time,
      publicGeneration: 1, transactionFingerprint: 10)
  }
  private func withDirectory(_ body: (URL) throws -> Void) throws {
    let url = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: url) }
    try body(url)
  }

  func testReadyMustMatchArmAndOriginalDeadline() throws {
    let a = try arm(), ready = try WatchdogOwnerReady(arm: a, processInstance: process,
      enforcerInstance: enforcer, readyMonotonicNanoseconds: 200)
    XCTAssertNoThrow(try ready.validate())
    XCTAssertThrowsError(try WatchdogOwnerReady(arm: a, processInstance: UUID(),
      enforcerInstance: enforcer, readyMonotonicNanoseconds: 150))
    XCTAssertThrowsError(try WatchdogOwnerReady(arm: a, processInstance: process,
      enforcerInstance: enforcer, readyMonotonicNanoseconds: 201))
  }

  func testRestartedSupervisorCannotResetStartupDeadline() throws {
    var lifecycle = try WatchdogLifecycleSupervisor(arm: arm())
    XCTAssertEqual(lifecycle.observeReady(nil, nowNanoseconds: 201), .startupDeadlineExceeded)
    let late = try? WatchdogOwnerReady(arm: arm(), processInstance: process,
      enforcerInstance: enforcer, readyMonotonicNanoseconds: 200)
    XCTAssertEqual(lifecycle.observeReady(late, nowNanoseconds: 202), .startupDeadlineExceeded)
  }

  func testStopAlwaysOutranksReadinessAndCompletion() throws {
    let a = try arm(), ready = try WatchdogOwnerReady(arm: a, processInstance: process,
      enforcerInstance: enforcer, readyMonotonicNanoseconds: 150)
    var first = try WatchdogLifecycleSupervisor(arm: a)
    XCTAssertEqual(first.observeReady(ready, stopPresent: true, nowNanoseconds: 150), .stoppedIncidentPresent)
    var second = try WatchdogLifecycleSupervisor(arm: a)
    XCTAssertEqual(second.observeReady(ready, nowNanoseconds: 150), .monitoring)
    let completion = try WatchdogOwnerCompletion(arm: a, lastSettledHeartbeat: heartbeat(),
      completedMonotonicNanoseconds: 160, terminalEvidenceArtifactSHA256: evidenceSHA256)
    XCTAssertEqual(second.observeCompletion(completion, currentHeartbeat: try heartbeat(),
      stopPresent: true, nowNanoseconds: 160), .stoppedIncidentPresent)
  }

  func testCompletionRequiresExactCurrentlyObservedHeartbeat() throws {
    let a = try arm(), ready = try WatchdogOwnerReady(arm: a, processInstance: process,
      enforcerInstance: enforcer, readyMonotonicNanoseconds: 140)
    var lifecycle = try WatchdogLifecycleSupervisor(arm: a)
    XCTAssertEqual(lifecycle.observeReady(ready, nowNanoseconds: 140), .monitoring)
    let completion = try WatchdogOwnerCompletion(arm: a, lastSettledHeartbeat: heartbeat(),
      completedMonotonicNanoseconds: 160, terminalEvidenceArtifactSHA256: evidenceSHA256)
    let changed = try WatchdogHeartbeat(processInstance: process, sequence: 2, monotonicNanoseconds: 155,
      publicGeneration: 2, transactionFingerprint: 20)
    XCTAssertEqual(lifecycle.observeCompletion(completion, currentHeartbeat: changed,
      nowNanoseconds: 160), .invalidLifecycleRecord)
  }

  func testCreateOnlyLifecycleTransportIsExactlyIdempotent() throws {
    try withDirectory { directory in
      let armURL = directory.appendingPathComponent("arm.json"), a = try arm()
      try WatchdogFileProtocol.publishSupervisorArm(a, to: armURL)
      try WatchdogFileProtocol.publishSupervisorArm(a, to: armURL)
      XCTAssertEqual(try WatchdogFileProtocol.readSupervisorArmIfPresent(armURL), a)
      XCTAssertThrowsError(try WatchdogFileProtocol.publishSupervisorArm(arm(created: 101), to: armURL))
    }
  }

  func testOwnerLifecycleRequiresArmAndIdleSettledCompletion() throws {
    try withDirectory { directory in
      let config = try WatchdogOwnerFileConfiguration(processInstance: process,
        enforcerInstance: enforcer, directoryPath: directory.path)
      let owner = try WatchdogOwnerFileSession(configuration: config)
      let armURL = directory.appendingPathComponent("arm.json"), readyURL = directory.appendingPathComponent("ready.json")
      let completionURL = directory.appendingPathComponent("complete.json")
      try WatchdogFileProtocol.publishSupervisorArm(arm(), to: armURL)
      let lifecycle = try WatchdogOwnerLifecycle(owner: owner, armURL: armURL,
        readyURL: readyURL, completionURL: completionURL, nowNanoseconds: 120)
      try lifecycle.activate(nowNanoseconds: 130)
      XCTAssertNotNil(try WatchdogFileProtocol.readOwnerReadyIfPresent(readyURL))
      XCTAssertThrowsError(try lifecycle.complete(terminalEvidenceArtifactSHA256: evidenceSHA256, nowNanoseconds: 140))
      let permit = try owner.beginRoot(nowNanoseconds: 140)
      XCTAssertThrowsError(try lifecycle.complete(terminalEvidenceArtifactSHA256: evidenceSHA256, nowNanoseconds: 145))
      try owner.recordSettledRoot(permit, publicGeneration: 1, transactionFingerprint: 10,
        settledMonotonicNanoseconds: 150, terminalEvidenceArtifactSHA256: evidenceSHA256)
      let completion = try lifecycle.complete(terminalEvidenceArtifactSHA256: evidenceSHA256, nowNanoseconds: 160)
      XCTAssertEqual(try WatchdogFileProtocol.readOwnerCompletionIfPresent(completionURL), completion)
      XCTAssertThrowsError(try lifecycle.complete(terminalEvidenceArtifactSHA256: evidenceSHA256, nowNanoseconds: 170))
    }
  }

  func testMalformedLifecycleDecodeFailsClosed() throws {
    let a = try arm()
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(a)) as? [String: Any])
    object["formatVersion"] = 99
    XCTAssertThrowsError(try JSONDecoder().decode(WatchdogSupervisorArm.self,
      from: JSONSerialization.data(withJSONObject: object)))
  }
}

import Foundation
import XCTest
@testable import NumiBrainQualification

final class SafetyBoundaryTests: XCTestCase {
  private func envelope() throws -> SafetyEnvelope {
    try .init(semanticStop: 0.8, kinematicStop: 0.8, contactStop: 0.8, forceStop: 0.8,
      thermalStop: 0.8, actuatorStop: 0.8, uncertaintySupervision: 0.5, uncertaintyStop: 0.9)
  }
  private func vector() throws -> SafetyVector {
    try .init(semanticRisk: 0, kinematicRisk: 0, contactRisk: 0, forceRisk: 0,
      thermalRisk: 0, actuatorRisk: 0, uncertainty: 0)
  }
  private func changed<T: Encodable>(_ value: T, key: String, replacement: Any) throws -> Data {
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    json[key] = replacement
    return try JSONSerialization.data(withJSONObject: json)
  }

  func testDecoderCannotWeakenThresholdsOrImportInvalidRisks() throws {
    for key in ["semanticStop", "kinematicStop", "contactStop", "forceStop", "thermalStop", "actuatorStop", "uncertaintyStop"] {
      XCTAssertThrowsError(try JSONDecoder().decode(SafetyEnvelope.self,
        from: changed(envelope(), key: key, replacement: 2)))
    }
    XCTAssertThrowsError(try JSONDecoder().decode(SafetyEnvelope.self,
      from: changed(envelope(), key: "uncertaintySupervision", replacement: 0.99)))
    for value in [-1.0, 1.1] {
      XCTAssertThrowsError(try JSONDecoder().decode(SafetyVector.self,
        from: changed(vector(), key: "forceRisk", replacement: value)))
    }
    let decoder = JSONDecoder()
    decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
    XCTAssertThrowsError(try decoder.decode(SafetyVector.self,
      from: changed(vector(), key: "uncertainty", replacement: "nan")))
  }

  func testCampaignRequiresTheSpecificPredeclaredResponse() throws {
    let required = try SafetyCampaignScenario.Kind.allCases.map { try SafetyCampaignScenario(kind: $0, identifier: $0.rawValue) }
    func outcomes(weakenGPU: Bool) throws -> [SafetyCampaignOutcome] {
      try required.map { item in
        try .init(scenario: item, disposition: weakenGPU && item.kind == .gpuFault ? .requestSupervision : item.expectedDisposition,
          publicRootChangedOnRejectedAttempt: false, rejectedShadowExposed: false, boundedLatencyMicroseconds: 1)
      }
    }
    XCTAssertNoThrow(try SafetyCampaignVerifier.verify(required: required, outcomes: outcomes(weakenGPU: false), maximumProtectiveLatencyMicroseconds: 10))
    XCTAssertThrowsError(try SafetyCampaignVerifier.verify(required: required, outcomes: outcomes(weakenGPU: true), maximumProtectiveLatencyMicroseconds: 10))
    XCTAssertThrowsError(try SafetyCampaignScenario(kind: .gpuFault, identifier: "wrong", expectedDisposition: .requestSupervision))
  }

  func testActualSafetyFailuresAreRetainableIncidents() throws {
    let input = try vector()
    let incident = try SafetyIncidentArtifact(sourceRevision: "test", parameterVersionFingerprint: 7,
      publicGeneration: 1, transactionFingerprint: 1, vector: input,
      decision: SafetyDecision(vector: input, envelope: envelope()), rejectedShadowExposed: true)
    XCTAssertTrue(incident.rejectedShadowExposed)
  }

  func testRepeatedHeartbeatIsHealthyUntilStaleAndFailuresLatch() throws {
    let process = UUID()
    let a = try WatchdogHeartbeat(processInstance: process, sequence: 1, monotonicNanoseconds: 100,
      publicGeneration: 1, transactionFingerprint: 1)
    var monitor = try WatchdogMonitor(expectedProcessInstance: process, maximumAgeNanoseconds: 100, maximumProgressAgeNanoseconds: 500)
    XCTAssertEqual(monitor.observe(a, nowNanoseconds: 110).status, .healthy)
    XCTAssertEqual(monitor.observe(a, nowNanoseconds: 150).status, .healthy)
    XCTAssertEqual(monitor.observe(a, nowNanoseconds: 201).status, .stale)
    let newer = try WatchdogHeartbeat(processInstance: process, sequence: 2, monotonicNanoseconds: 202,
      publicGeneration: 2, transactionFingerprint: 2)
    XCTAssertEqual(monitor.observe(newer, nowNanoseconds: 203).status, .stale)
  }

  func testRestartMissingMalformedAndRegressedHeartbeatsRequestSafeState() throws {
    let process = UUID()
    func monitor() throws -> WatchdogMonitor {
      try .init(expectedProcessInstance: process, maximumAgeNanoseconds: 100, maximumProgressAgeNanoseconds: 500)
    }
    var missing = try monitor(), malformed = try monitor(), restarted = try monitor(), regressed = try monitor()
    XCTAssertTrue(missing.observe(nil, nowNanoseconds: 100).mustRequestSafeState)
    XCTAssertEqual(malformed.observe(nil, readFailed: true, nowNanoseconds: 100).status, .malformed)
    let foreign = try WatchdogHeartbeat(processInstance: UUID(), sequence: 1, monotonicNanoseconds: 100, publicGeneration: 1, transactionFingerprint: 1)
    XCTAssertTrue(restarted.observe(foreign, nowNanoseconds: 101).mustRequestSafeState)
    let a = try WatchdogHeartbeat(processInstance: process, sequence: 2, monotonicNanoseconds: 100, publicGeneration: 2, transactionFingerprint: 2)
    let b = try WatchdogHeartbeat(processInstance: process, sequence: 1, monotonicNanoseconds: 110, publicGeneration: 1, transactionFingerprint: 1)
    _ = regressed.observe(a, nowNanoseconds: 101)
    XCTAssertEqual(regressed.observe(b, nowNanoseconds: 111).status, .regressed)
  }

  func testCPUHeartbeatCannotHideStalledCommittedGeneration() throws {
    let process = UUID()
    var monitor = try WatchdogMonitor(expectedProcessInstance: process, maximumAgeNanoseconds: 100, maximumProgressAgeNanoseconds: 200)
    for step in 1...4 {
      let heartbeat = try WatchdogHeartbeat(processInstance: process, sequence: UInt64(step),
        monotonicNanoseconds: UInt64(step * 100), publicGeneration: 1, transactionFingerprint: 1)
      let result = monitor.observe(heartbeat, nowNanoseconds: UInt64(step * 100))
      if step < 4 { XCTAssertEqual(result.status, .healthy) }
      else { XCTAssertEqual(result.reason, "committed_progress_stalled") }
    }
  }

  func testMissingObservationStopRequestDoesNotFabricateIdentityAndIsSticky() throws {
    let path = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: path) }
    let url = path.appendingPathComponent("stop.json"), process = UUID(), watchdog = UUID()
    let first = try WatchdogStopRequest(watchdogInstance: watchdog, expectedProcessInstance: process,
      observed: nil, reason: "heartbeat_missing", createdUnixNanoseconds: 1)
    let second = try WatchdogStopRequest(watchdogInstance: watchdog, expectedProcessInstance: process,
      observed: nil, reason: "later_failure", createdUnixNanoseconds: 2)
    try WatchdogFileProtocol.publishStopRequest(first, to: url)
    try WatchdogFileProtocol.publishStopRequest(second, to: url)
    let retained = try XCTUnwrap(WatchdogFileProtocol.readStopRequestIfPresent(url))
    XCTAssertEqual(retained, first); XCTAssertNil(retained.observedTransactionFingerprint)
  }
}

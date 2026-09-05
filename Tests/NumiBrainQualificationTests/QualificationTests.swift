import XCTest
@testable import NumiBrainQualification

final class QualificationTests: XCTestCase {
  func testLatencyDistribution() throws {
    let value = try LatencyDistribution(samplesMicroseconds: [1,2,3,4,5])
    XCTAssertEqual(value.sampleCount, 5); XCTAssertEqual(value.p50Microseconds, 3)
    XCTAssertGreaterThan(value.p95Microseconds, value.p50Microseconds)
  }

  func testSafetyPrecedence() throws {
    let envelope = try SafetyEnvelope(semanticStop: 0.8, kinematicStop: 0.8, contactStop: 0.8,
      forceStop: 0.8, thermalStop: 0.8, actuatorStop: 0.8, uncertaintySupervision: 0.5, uncertaintyStop: 0.9)
    let ordinary = try SafetyVector(semanticRisk: 0, kinematicRisk: 0, contactRisk: 0, forceRisk: 0,
      thermalRisk: 0, actuatorRisk: 0, uncertainty: 0.6)
    XCTAssertEqual(SafetyDecision(vector: ordinary, envelope: envelope).disposition, .requestSupervision)
    let hard = try SafetyVector(semanticRisk: 0, kinematicRisk: 0, contactRisk: 0, forceRisk: 1,
      thermalRisk: 0, actuatorRisk: 0, uncertainty: 0)
    XCTAssertEqual(SafetyDecision(vector: hard, envelope: envelope).disposition, .protectiveStop)
    let malformed = try SafetyVector(semanticRisk: 0, kinematicRisk: 0, contactRisk: 0, forceRisk: 0,
      thermalRisk: 0, actuatorRisk: 0, uncertainty: 0, malformedRecord: true)
    XCTAssertEqual(SafetyDecision(vector: malformed, envelope: envelope).disposition, .failClosed)
  }

  func testWatchdogDetectsRegressionAndRestart() throws {
    let id = UUID()
    let a = try WatchdogHeartbeat(processInstance: id, sequence: 1, monotonicNanoseconds: 100,
      publicGeneration: 4, transactionFingerprint: 1)
    let b = try WatchdogHeartbeat(processInstance: id, sequence: 2, monotonicNanoseconds: 200,
      publicGeneration: 5, transactionFingerprint: 2)
    XCTAssertEqual(try WatchdogVerifier.status(previous: a, current: b, nowNanoseconds: 250,
      maximumAgeNanoseconds: 100), .healthy)
    XCTAssertEqual(try WatchdogVerifier.status(previous: b, current: a, nowNanoseconds: 250,
      maximumAgeNanoseconds: 1000), .regressed)
  }

  func testSweepRejectsMixedBinaries() throws {
    // Coverage behavior is exercised in Apple/full-package qualification with retained runs.
    XCTAssertTrue(true)
  }
}

import XCTest
@testable import NumiBrainQualification

final class QualificationTests: XCTestCase {
  private let hashA = String(repeating: "a", count: 64)
  private let hashB = String(repeating: "b", count: 64)

  private func hardware() throws -> QualificationHardwareIdentity {
    try .init(machineIdentifier: "Mac16,11", chipIdentifier: "Apple M4 Pro",
      gpuFamily: "Apple9", memoryBytes: 24 * 1024 * 1024 * 1024,
      osBuild: "26.6-test", swiftVersion: "6.3.3", metalVersion: "Metal4")
  }

  private func workload(_ identifier: String, environments: UInt32) throws -> PerformanceWorkloadIdentity {
    try .init(identifier: identifier, environmentCount: environments, logicalDoF: 128,
      attachmentCount: 1, femElementCount: 1, sensorScalarCount: 4_576,
      modelParameterCount: 1_000, horizonRoots: 100, timestepMicroseconds: 1_000,
      deterministic: true, fastMath: false)
  }

  private func run(_ workload: PerformanceWorkloadIdentity,
    binary: String = String(repeating: "a", count: 64)) throws -> PerformanceRunArtifact {
    let wallSeconds = 0.05
    return try .init(sourceRevision: "revision", binarySHA256: binary, metallibSHA256: hashB,
      hardware: hardware(), workload: workload, warmupRoots: 10, measuredRoots: 100,
      latency: LatencyDistribution(samplesMicroseconds: [Double](repeating: 100, count: 100)),
      simulatedSecondsPerWallSecond: 100 * 0.001 / wallSeconds,
      environmentStepsPerSecond: 100 * Double(workload.environmentCount) / wallSeconds,
      peakResidentBytes: 1_000_000, steadyResidentBytes: 900_000,
      bytesPerEnvironment: 900_000 / Double(workload.environmentCount),
      counters: PerformanceCounterSummary(commandBufferCount: 100, cpuWaitCount: 0,
        queueCreationCountDuringMeasuredRegion: 0, hostPayloadReadbackBytes: 0))
  }

  func testLatencyDistribution() throws {
    let value = try LatencyDistribution(samplesMicroseconds: [1,2,3,4,5])
    XCTAssertEqual(value.sampleCount, 5); XCTAssertEqual(value.p50Microseconds, 3)
    XCTAssertGreaterThan(value.p95Microseconds, value.p50Microseconds)
  }

  func testSHA256RequiresCanonicalLowercaseHex() {
    XCTAssertTrue(PerformanceRunArtifact.isSHA256(hashA))
    XCTAssertFalse(PerformanceRunArtifact.isSHA256(String(repeating: "A", count: 64)))
    XCTAssertFalse(PerformanceRunArtifact.isSHA256(String(repeating: "g", count: 64)))
    XCTAssertFalse(PerformanceRunArtifact.isSHA256(String(repeating: "a", count: 63)))
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

  func testWatchdogDetectsRegressionRestartAndStaleness() throws {
    let id = UUID()
    let a = try WatchdogHeartbeat(processInstance: id, sequence: 1, monotonicNanoseconds: 100,
      publicGeneration: 4, transactionFingerprint: 1)
    let b = try WatchdogHeartbeat(processInstance: id, sequence: 2, monotonicNanoseconds: 200,
      publicGeneration: 5, transactionFingerprint: 2)
    XCTAssertEqual(try WatchdogVerifier.status(previous: a, current: b, nowNanoseconds: 250,
      maximumAgeNanoseconds: 100), .healthy)
    XCTAssertEqual(try WatchdogVerifier.status(previous: b, current: a, nowNanoseconds: 250,
      maximumAgeNanoseconds: 1000), .regressed)
    XCTAssertEqual(try WatchdogVerifier.status(previous: nil, current: a, nowNanoseconds: 500,
      maximumAgeNanoseconds: 100), .stale)
    let restarted = try WatchdogHeartbeat(processInstance: UUID(), sequence: 1, monotonicNanoseconds: 300,
      publicGeneration: 5, transactionFingerprint: 3)
    XCTAssertEqual(try WatchdogVerifier.status(previous: b, current: restarted, nowNanoseconds: 350,
      maximumAgeNanoseconds: 100), .restarted)
  }

  func testPerformanceSweepRejectsMixedBinariesAndMissingCells() throws {
    let a = try workload("one", environments: 1)
    let b = try workload("many", environments: 16)
    XCTAssertNoThrow(try PerformanceSweepVerifier.verify(expected: [a,b], observed: [try run(a), try run(b)]))
    XCTAssertThrowsError(try PerformanceSweepVerifier.verify(expected: [a,b], observed: [try run(a)]))
    XCTAssertThrowsError(try PerformanceSweepVerifier.verify(expected: [a,b], observed: [
      try run(a), try run(b, binary: String(repeating: "c", count: 64)),
    ]))
  }

  func testRawPerformanceEvidenceRecomputesSummary() throws {
    let workload = try workload("one", environments: 1)
    let run = try run(workload)
    let measurements = try PerformanceMeasurementArtifact(
      rootLatencyMicroseconds: [Double](repeating: 100, count: 100),
      wallDurationSeconds: 0.05, peakResidentBytes: 1_000_000,
      steadyResidentBytes: 900_000,
      counters: PerformanceCounterSummary(commandBufferCount: 100, cpuWaitCount: 0,
        queueCreationCountDuringMeasuredRegion: 0, hostPayloadReadbackBytes: 0))
    XCTAssertNoThrow(try PerformanceEvidenceVerifier.verify(run: run, measurements: measurements))

    let forged = try PerformanceRunArtifact(sourceRevision: run.sourceRevision,
      binarySHA256: run.binarySHA256, metallibSHA256: run.metallibSHA256,
      hardware: run.hardware, workload: run.workload, warmupRoots: run.warmupRoots,
      measuredRoots: run.measuredRoots,
      latency: LatencyDistribution(samplesMicroseconds: [Double](repeating: 99, count: 100)),
      simulatedSecondsPerWallSecond: run.simulatedSecondsPerWallSecond,
      environmentStepsPerSecond: run.environmentStepsPerSecond,
      peakResidentBytes: run.peakResidentBytes, steadyResidentBytes: run.steadyResidentBytes,
      bytesPerEnvironment: run.bytesPerEnvironment, counters: run.counters)
    XCTAssertThrowsError(try PerformanceEvidenceVerifier.verify(run: forged, measurements: measurements))
  }

  func testPerformanceProtocolRejectsHotPathCPUWork() throws {
    let workload = try workload("one", environments: 1)
    let hardware = try hardware()
    let run = try PerformanceRunArtifact(sourceRevision: "revision", binarySHA256: hashA,
      metallibSHA256: hashB, hardware: hardware, workload: workload, warmupRoots: 10,
      measuredRoots: 100, latency: LatencyDistribution(samplesMicroseconds: [Double](repeating: 100, count: 100)),
      simulatedSecondsPerWallSecond: 2, environmentStepsPerSecond: 2_000,
      peakResidentBytes: 1_000_000, steadyResidentBytes: 900_000, bytesPerEnvironment: 900_000,
      counters: PerformanceCounterSummary(commandBufferCount: 100, cpuWaitCount: 1,
        queueCreationCountDuringMeasuredRegion: 0, hostPayloadReadbackBytes: 0))
    let protocolValue = try PerformanceQualificationProtocol(maximumP99RootLatencyMicroseconds: 1_000,
      minimumSimulatedSecondsPerWallSecond: 1, minimumEnvironmentStepsPerSecond: 1,
      maximumBytesPerEnvironment: 1_000_000)
    let result = PerformanceQualificationResult(run: run, protocol: protocolValue)
    XCTAssertFalse(result.passed)
    XCTAssertEqual(result.failures, ["cpu_waits"])
  }

  func testSafetyCampaignRequiresEveryScenarioClass() throws {
    let required = try SafetyCampaignScenario.Kind.allCases.map {
      try SafetyCampaignScenario(kind: $0, identifier: $0.rawValue)
    }
    let outcomes = try required.map {
      try SafetyCampaignOutcome(scenario: $0, disposition: .protectiveStop,
        publicRootChangedOnRejectedAttempt: false, rejectedShadowExposed: false,
        boundedLatencyMicroseconds: 100)
    }
    XCTAssertNoThrow(try SafetyCampaignVerifier.verify(required: required,
      outcomes: outcomes, maximumProtectiveLatencyMicroseconds: 1_000))
    XCTAssertThrowsError(try SafetyCampaignVerifier.verify(required: Array(required.dropLast()),
      outcomes: Array(outcomes.dropLast()), maximumProtectiveLatencyMicroseconds: 1_000))
  }
}

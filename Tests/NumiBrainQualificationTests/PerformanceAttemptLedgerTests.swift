import Foundation
import XCTest
@testable import NumiBrainQualification

final class PerformanceAttemptLedgerTests: XCTestCase {
  private func hash(_ value: UInt64) -> String { String(repeating: "0", count: 48) + String(format: "%016llx", value) }
  private func row(_ attempt: UInt64, step: UInt64? = nil, transaction: UInt64? = nil,
    environment: UInt32 = 0, base: UInt64, outcome: PerformanceAttemptOutcome = .accepted,
    wallStart: UInt64? = nil) throws -> PerformanceAttemptObservation {
    let time = base * 1000
    return try .init(environment: environment, attemptIdentifier: attempt, controlStepIdentifier: step ?? attempt,
      transactionFingerprint: transaction ?? UInt64(environment) * 10_000 + attempt,
      outcome: outcome, wallStartNanoseconds: wallStart ?? attempt * 10_000,
      wallEndNanoseconds: (wallStart ?? attempt * 10_000) + 5000,
      baseGeneration: base, publishedGeneration: outcome == .commandFailed ? nil : (outcome == .accepted ? base + 1 : base),
      committedTimeMicroseconds: time, targetTimeMicroseconds: time + 1000,
      publishedTimeMicroseconds: outcome == .commandFailed ? nil : (outcome == .accepted ? time + 1000 : time),
      terminalEvidenceSHA256: hash(UInt64(environment) * 10_000 + attempt))
  }
  private func ledger(_ rows: [PerformanceAttemptObservation], environments: UInt32 = 1,
    horizon: UInt64 = 100) throws -> PerformanceAttemptLedger {
    try .init(protocolSHA256: hash(90), sourceRevision: "test-fixture", binarySHA256: hash(91), metallibSHA256: hash(92),
      hardware: QualificationHardwareIdentity(machineIdentifier: "fixture", chipIdentifier: "fixture", gpuFamily: "fixture",
        memoryBytes: 1000, osBuild: "fixture", swiftVersion: "fixture", metalVersion: "fixture"),
      workload: PerformanceWorkloadIdentity(identifier: "fixture", environmentCount: environments, logicalDoF: 1,
        attachmentCount: 0, femElementCount: 0, sensorScalarCount: 1, modelParameterCount: 1,
        horizonRoots: horizon, timestepMicroseconds: 1000, deterministic: true, fastMath: false),
      warmupRootsPerEnvironment: 1, measurementStartNanoseconds: 0, measurementEndNanoseconds: 1_000_000_000,
      attempts: rows, peakResidentBytes: 1000, steadyResidentBytes: 800, meanPowerWatts: 2,
      counters: PerformanceCounterSummary(commandBufferCount: UInt64(rows.count), cpuWaitCount: 0,
        queueCreationCountDuringMeasuredRegion: 0, hostPayloadReadbackBytes: 0))
  }
  func testRejectedRetryConsumesWallTimeButNotPhysicalProgress() throws {
    let rows = try [row(1, base: 0, outcome: .rejected), row(2, step: 1, transaction: 1, base: 0), row(3, step: 2, transaction: 2, base: 1)]
    let summary = try PerformanceAttemptSummary(ledger: ledger(rows))
    XCTAssertEqual(summary.attemptedRoots, 3); XCTAssertEqual(summary.acceptedRoots, 2); XCTAssertEqual(summary.rejectedRoots, 1)
    XCTAssertEqual(summary.acceptedEnvironmentStepsPerSecond, 2)
    XCTAssertEqual(summary.aggregateAcceptedSimulatedSecondsPerWallSecond, 0.002, accuracy: 1e-12)
    XCTAssertEqual(summary.energyJoulesPerAggregateAcceptedSimulatedSecond, 1000)
  }
  func testZeroAcceptedProgressIsRetainedWithoutInventedEnergyEfficiency() throws {
    let summary = try PerformanceAttemptSummary(ledger: ledger([row(1, base: 0, outcome: .rejected)]))
    XCTAssertEqual(summary.acceptedRoots, 0); XCTAssertEqual(summary.acceptedEnvironmentStepsPerSecond, 0)
    XCTAssertNil(summary.energyJoulesPerAggregateAcceptedSimulatedSecond)
  }
  func testFailedCommandHasUnknownPublicationAndQuarantinesThatEnvironment() throws {
    let failed = try row(1, base: 0, outcome: .commandFailed)
    let summary = try PerformanceAttemptSummary(ledger: ledger([failed]))
    XCTAssertEqual(summary.commandFailures, 1); XCTAssertEqual(summary.attemptLatency.sampleCount, 1)
    XCTAssertThrowsError(try ledger([failed, row(2, base: 0)]))
    XCTAssertThrowsError(try PerformanceAttemptObservation(environment: 0, attemptIdentifier: 1, controlStepIdentifier: 1,
      transactionFingerprint: 1, outcome: .commandFailed, wallStartNanoseconds: 1, wallEndNanoseconds: 2,
      baseGeneration: 0, publishedGeneration: 0, committedTimeMicroseconds: 0, targetTimeMicroseconds: 1000,
      publishedTimeMicroseconds: 0, terminalEvidenceSHA256: hash(1)))
  }
  func testPerEnvironmentAccountingDoesNotMultiplyAttemptCountByCohortSize() throws {
    let rows = try [row(1, environment: 0, base: 0), row(1, environment: 1, base: 0, outcome: .rejected), row(2, environment: 0, base: 1)]
    let summary = try PerformanceAttemptSummary(ledger: ledger(rows, environments: 2))
    XCTAssertEqual(summary.acceptedEnvironmentStepsPerSecond, 2)
    XCTAssertEqual(summary.minimumPerEnvironmentSimulatedSecondsPerWallSecond, 0)
    XCTAssertEqual(summary.amortizedResidentBytesPerEnvironment, 400)
  }
  func testMissingDuplicateReplayedAndOverlappingAttemptsFail() throws {
    let first = try row(1, base: 0)
    XCTAssertThrowsError(try ledger([first, first]))
    XCTAssertThrowsError(try ledger([first, row(3, base: 1)]))
    XCTAssertThrowsError(try ledger([first, row(2, transaction: 1, base: 1)]))
    XCTAssertThrowsError(try ledger([first, row(2, base: 1, wallStart: 12_000)]))
    XCTAssertThrowsError(try ledger([first], environments: 2))
  }
  func testDecodedOutcomeCannotAdvanceRejectedPhysicalTime() throws {
    let source = try ledger([row(1, base: 0)])
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any])
    var rows = try XCTUnwrap(json["attempts"] as? [[String: Any]])
    rows[0]["outcome"] = "rejected"; json["attempts"] = rows
    let decoded = try JSONDecoder().decode(PerformanceAttemptLedger.self, from: JSONSerialization.data(withJSONObject: json))
    XCTAssertThrowsError(try decoded.validate())
  }
  func testSimulationHorizonCannotBeClaimedFromRejectedRows() throws {
    let rows = try (1...100).map { try row(UInt64($0), base: 0, outcome: .rejected) }
    let limits = try PerformanceQualificationProtocol(maximumP99RootLatencyMicroseconds: 100,
      minimumSimulatedSecondsPerWallSecond: 0.01, minimumEnvironmentStepsPerSecond: 1, maximumBytesPerEnvironment: 1000)
    let result = try PerformanceAttemptEvaluation(ledger: ledger(rows),
      protocol: PerformanceAttemptProtocol(limits: limits, maximumRejectedFraction: 1))
    XCTAssertFalse(result.passed); XCTAssertFalse(result.promotable)
    XCTAssertTrue(result.failures.contains("incomplete_accepted_horizon"))
    XCTAssertTrue(result.failures.contains("accepted_simulation_rate"))
  }
  func testFiniteLargeLatenciesDoNotOverflowTheirMean() throws {
    let large = Double.greatestFiniteMagnitude
    let summary = try LatencyDistribution(samplesMicroseconds: [large, large])
    XCTAssertEqual(summary.meanMicroseconds, large); XCTAssertTrue(summary.p99Microseconds.isFinite)
    XCTAssertEqual(try LatencyDistribution(samplesMicroseconds: [0,0]).meanMicroseconds, 0)
  }
  func testReleaseGenerationOverflowFailsInsteadOfTrapping() throws {
    func release(_ generation: UInt64, previous: String?) throws -> NumanXReleaseManifest {
      try .init(releaseIdentifier: "test", sourceRevision: "test", binarySHA256: hash(1), metallibSHA256: hash(2),
        modelSHA256: hash(3), datasetManifestSHA256: hash(4), qualificationManifestSHA256: hash(5),
        previousReleaseManifestSHA256: previous, createdUnixSeconds: 1, deploymentGeneration: generation)
    }
    let first = try release(UInt64.max, previous: nil), second = try release(1, previous: hash(10))
    XCTAssertThrowsError(try ReleaseChainVerifier.verify(chain: [(hash(10), first), (hash(11), second)]))
  }
}

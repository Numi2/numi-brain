import XCTest
@testable import NumiBrainValidation

final class PerturbationValidationTests: XCTestCase {
  private var outcomes: [PairedPerturbationOutcome] {
    (0..<10).map { index in .init(independentUnit: "episode-\(index)", baselineRecovered: true,
      interventionRecovered: index < 7, baselineLoss: Double(index), interventionLoss: Double(index) + 2) }
  }

  func testSmallPerfectRunDoesNotClaimCertainty() throws {
    let interval = try PerturbationValidation.recoveryInterval(successes: 10, trials: 10)
    XCTAssertEqual(interval.estimate, 1)
    XCTAssertEqual(interval.lower, 0.7224672001371107, accuracy: 1e-12)
    XCTAssertEqual(interval.upper, 1, accuracy: 1e-12)
  }

  func testZeroSuccessStillHasNonzeroUpperBound() throws {
    let interval = try PerturbationValidation.recoveryInterval(successes: 0, trials: 10)
    XCTAssertEqual(interval.lower, 0, accuracy: 1e-12)
    XCTAssertGreaterThan(interval.upper, 0.27)
    XCTAssertThrowsError(try PerturbationValidation.recoveryInterval(successes: 1, trials: 0))
  }

  func testPairedStatisticsIncludeFailedInterventions() throws {
    let report = try PerturbationValidation.paired(outcomes, seed: 17, bootstrapReplicates: 200)
    XCTAssertEqual(report.baselineRecovery.estimate, 1)
    XCTAssertEqual(report.interventionRecovery.estimate, 0.7)
    XCTAssertEqual(report.recoveryDifference.estimate, -0.3, accuracy: 1e-14)
    XCTAssertEqual(report.lossDifference.estimate, 2, accuracy: 1e-14)
    XCTAssertEqual(report.lossDifference.lower, 2, accuracy: 1e-14)
    XCTAssertEqual(report.lossDifference.upper, 2, accuracy: 1e-14)
  }

  func testSeedAndOrderingAreDeterministic() throws {
    let a = try PerturbationValidation.paired(outcomes, seed: 1, bootstrapReplicates: 200)
    let b = try PerturbationValidation.paired(Array(outcomes.reversed()), seed: 1, bootstrapReplicates: 200)
    XCTAssertEqual(a, b)
  }

  func testDuplicateUnitsAndUnboundedWorkAreRejected() {
    XCTAssertThrowsError(try PerturbationValidation.paired([outcomes[0],outcomes[0]], seed: 1))
    XCTAssertThrowsError(try PerturbationValidation.paired([outcomes[0]], seed: 1))
    XCTAssertThrowsError(try PerturbationValidation.paired(outcomes, seed: 1, bootstrapReplicates: 100))
  }

  func testStatisticalProbeDoesNotInventAcceptanceThresholds() throws {
    let result = try GateDProbe.perturbation(outcomes: outcomes, seed: 1, bootstrapReplicates: 200).evaluate()
    XCTAssertNil(result.diagnosticStatus)
  }
}

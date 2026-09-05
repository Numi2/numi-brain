import XCTest
import NumiBrainQualification
@testable import NumiBrainCore

@MainActor
final class BrainSafetyAdmissionTests: XCTestCase {
  private func controller() throws -> BrainSafetyAdmissionController {
    let envelope = try SafetyEnvelope(semanticStop: 0.8, kinematicStop: 0.8, contactStop: 0.8,
      forceStop: 0.8, thermalStop: 0.8, actuatorStop: 0.8, uncertaintySupervision: 0.5, uncertaintyStop: 0.9)
    return BrainSafetyAdmissionController(configuration: .init(envelope: envelope))
  }
  private func vector(uncertainty: Double = 0) throws -> SafetyVector {
    try .init(semanticRisk: 0, kinematicRisk: 0, contactRisk: 0, forceRisk: 0,
      thermalRisk: 0, actuatorRisk: 0, uncertainty: uncertainty)
  }
  private func token(step: UInt64, generation: UInt64) throws -> BrainJointTransactionToken {
    try .init(environmentIdentifier: 1, episodeIdentifier: 1, controlStepIdentifier: step,
      parameterVersionFingerprint: 7, baseBrainGeneration: generation, basePhysicsGeneration: generation,
      committedTimestamp: BrainTimestamp(microseconds: generation * 1000),
      targetTimestamp: BrainTimestamp(microseconds: generation * 1000 + 1000), randomCounterGeneration: generation + 1)
  }
  func testPublishedContinuityAdvancesOnlyForAllow() async throws {
    let c = try controller(), first = try token(step: 1, generation: 0)
    let receipt = try await c.evaluate(transaction: first, vector: vector())
    XCTAssertEqual(receipt.disposition, .allow)
    try await c.recordPublished(transaction: first, receipt: receipt)
    let second = try await c.evaluate(transaction: token(step: 2, generation: 1), vector: vector())
    XCTAssertEqual(second.disposition, .allow)
    let skipped = try await c.evaluate(transaction: token(step: 3, generation: 2), vector: vector())
    XCTAssertEqual(skipped.disposition, .failClosed)
  }
  func testReceiptCannotAuthorizeAnotherRootOrAnotherController() async throws {
    let a = try controller(), b = try controller(), first = try token(step: 1, generation: 0)
    let receipt = try await a.evaluate(transaction: first, vector: vector())
    do { try await a.recordPublished(transaction: token(step: 2, generation: 1), receipt: receipt); XCTFail("foreign root") } catch {}
    do { try await b.recordPublished(transaction: first, receipt: receipt); XCTFail("foreign issuer") } catch {}
    try await a.recordPublished(transaction: first, receipt: receipt)
  }
  func testPublicationConsumesReceiptExactlyOnce() async throws {
    let c = try controller(), first = try token(step: 1, generation: 0)
    let receipt = try await c.evaluate(transaction: first, vector: vector())
    try await c.recordPublished(transaction: first, receipt: receipt)
    do { try await c.recordPublished(transaction: first, receipt: receipt); XCTFail("replayed receipt") } catch {}
  }
  func testLaterUnsafeEvaluationInvalidatesEarlierAllow() async throws {
    let c = try controller(), first = try token(step: 1, generation: 0)
    let receipt = try await c.evaluate(transaction: first, vector: vector())
    let stop = try await c.evaluate(transaction: first, vector: vector(uncertainty: 1))
    XCTAssertEqual(stop.disposition, .protectiveStop)
    do { try await c.recordPublished(transaction: first, receipt: receipt); XCTFail("superseded receipt") } catch {}
  }
  func testRejectedRetryDoesNotAdvanceAcceptedTimeAndCanBeReadmitted() async throws {
    let c = try controller(), first = try token(step: 1, generation: 0)
    let a = try await c.evaluate(transaction: first, vector: vector())
    try await c.recordRejected(transaction: first, receipt: a)
    let b = try await c.evaluate(transaction: first, vector: vector())
    XCTAssertEqual(b.disposition, .allow); XCTAssertNotEqual(a, b)
    do { try await c.recordPublished(transaction: first, receipt: a); XCTFail("old attempt receipt") } catch {}
    try await c.recordPublished(transaction: first, receipt: b)
  }
  func testScalarRecoveryCannotResetContinuity() async throws {
    let c = try controller()
    do { try await c.resetAfterVerifiedRecovery(baseBrainGeneration: 1, controlStepIdentifier: 1, transactionFingerprint: 1); XCTFail("unverified reset") } catch {}
  }
  func testRejectedInitialRootCannotAdvanceItsUnpublishedState() async throws {
    let c = try controller(), first = try token(step: 1, generation: 0)
    let receipt = try await c.evaluate(transaction: first, vector: vector())
    try await c.recordRejected(transaction: first, receipt: receipt)
    let later = try await c.evaluate(transaction: token(step: 2, generation: 1), vector: vector())
    XCTAssertEqual(later.disposition, .failClosed)
  }
  func testStoppedInitialRootCannotChangeBaseOnReevaluation() async throws {
    let c = try controller(), first = try token(step: 1, generation: 0)
    _ = try await c.evaluate(transaction: first, vector: vector())
    _ = try await c.evaluate(transaction: first, vector: vector(uncertainty: 1))
    let later = try await c.evaluate(transaction: token(step: 2, generation: 1), vector: vector())
    XCTAssertEqual(later.disposition, .failClosed)
  }
}

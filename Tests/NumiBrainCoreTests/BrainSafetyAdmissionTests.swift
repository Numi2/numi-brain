import XCTest
import NumiBrainQualification
@testable import NumiBrainCore

final class BrainSafetyAdmissionTests: XCTestCase {
  private func envelope() throws -> SafetyEnvelope {
    try SafetyEnvelope(semanticStop: 0.8, kinematicStop: 0.8, contactStop: 0.8,
      forceStop: 0.8, thermalStop: 0.8, actuatorStop: 0.8,
      uncertaintySupervision: 0.5, uncertaintyStop: 0.9)
  }

  private func vector() throws -> SafetyVector {
    try SafetyVector(semanticRisk: 0, kinematicRisk: 0, contactRisk: 0,
      forceRisk: 0, thermalRisk: 0, actuatorRisk: 0, uncertainty: 0)
  }

  private func token(step: UInt64, generation: UInt64) throws -> BrainJointTransactionToken {
    try BrainJointTransactionToken(environmentIdentifier: 1, episodeIdentifier: 1,
      controlStepIdentifier: step, parameterVersionFingerprint: 7,
      baseBrainGeneration: generation, basePhysicsGeneration: generation,
      committedTimestamp: BrainTimestamp(microseconds: generation * 1000),
      targetTimestamp: BrainTimestamp(microseconds: generation * 1000 + 1000),
      randomCounterGeneration: generation + 1)
  }

  func testPublishedContinuityAdvancesOnlyForAllow() async throws {
    let controller = BrainSafetyAdmissionController(configuration: .init(envelope: try envelope()))
    let first = try token(step: 1, generation: 0)
    let firstReceipt = try await controller.evaluate(transaction: first, vector: vector())
    XCTAssertEqual(firstReceipt.disposition, .allow)
    try await controller.recordPublished(transaction: first, receipt: firstReceipt)

    let second = try token(step: 2, generation: 1)
    XCTAssertEqual(try await controller.evaluate(transaction: second, vector: vector()).disposition, .allow)

    let skipped = try token(step: 3, generation: 2)
    // second was evaluated but never published; the history must still expect generation 1 / step 2.
    XCTAssertEqual(try await controller.evaluate(transaction: skipped, vector: vector()).disposition, .failClosed)
  }

  func testReceiptCannotAuthorizeAnotherRoot() async throws {
    let controller = BrainSafetyAdmissionController(configuration: .init(envelope: try envelope()))
    let a = try token(step: 1, generation: 0)
    let b = try token(step: 2, generation: 1)
    let receipt = try await controller.evaluate(transaction: a, vector: vector())
    do {
      try await controller.recordPublished(transaction: b, receipt: receipt)
      XCTFail("foreign receipt was accepted")
    } catch {}
  }
}

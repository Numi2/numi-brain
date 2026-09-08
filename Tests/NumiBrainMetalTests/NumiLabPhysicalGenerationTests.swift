import XCTest
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class NumiLabPhysicalGenerationTests: XCTestCase {
  private func snapshot(_ generation: UInt64, controls: UInt64? = nil,
    environments: UInt32 = 1) throws -> NumiLabLiveRolloutSnapshot {
    let identity = try NumiLabLiveRolloutIdentity(environmentCount: environments, actionCount: 2,
      runFingerprint: 1, worldFingerprint: 2, taskFingerprint: 3, actionFingerprint: 4, robotFingerprint: 5)
    return NumiLabLiveRolloutSnapshot(identity: identity, submittedControlSteps: controls ?? generation,
      completedEnvironmentSteps: generation, submissionCount: generation)
  }
  func testNativeGenerationCannotBeRebasedOrReused() throws {
    XCTAssertEqual(try snapshot(0).nextPhysicsGeneration(expectedBase: 0), 1)
    XCTAssertEqual(try snapshot(1).nextPhysicsGeneration(expectedBase: 1), 2)
    XCTAssertThrowsError(try snapshot(1).nextPhysicsGeneration(expectedBase: 0))
    XCTAssertThrowsError(try snapshot(0).nextPhysicsGeneration(expectedBase: 99))
  }
  func testExhaustedInconsistentAndBatchedOriginsAreRejected() throws {
    XCTAssertThrowsError(try snapshot(UInt64.max).nextPhysicsGeneration(expectedBase: UInt64.max))
    XCTAssertThrowsError(try snapshot(0, controls: 1).nextPhysicsGeneration(expectedBase: 0))
    XCTAssertThrowsError(try snapshot(0, environments: 2).nextPhysicsGeneration(expectedBase: 0))
  }
}

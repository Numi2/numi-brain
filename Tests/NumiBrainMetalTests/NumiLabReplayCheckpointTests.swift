import XCTest
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class NumiLabReplayCheckpointTests: XCTestCase {
  private func identity(environmentCount: UInt32 = 1) throws -> NumiLabLiveRolloutIdentity {
    try NumiLabLiveRolloutIdentity(
      environmentCount: environmentCount,
      actionCount: 3,
      runFingerprint: 11,
      worldFingerprint: 12,
      taskFingerprint: 13,
      actionFingerprint: 14,
      robotFingerprint: 15
    )
  }

  func testFreshSingleEnvironmentOriginIsTheOnlyReplayOrigin() throws {
    let id = try identity()
    let fresh = NumiLabLiveRolloutSnapshot(
      identity: id,
      submittedControlSteps: 0,
      completedEnvironmentSteps: 0,
      submissionCount: 0
    )
    let checkpoint = try NumiLabReplayCheckpoint(origin: fresh)
    XCTAssertEqual(checkpoint.identity, id)
    XCTAssertEqual(checkpoint.origin, fresh)
    XCTAssertTrue(checkpoint.steps.isEmpty)
    XCTAssertNil(checkpoint.finalPhysicalStateFingerprint)

    for bad in [
      NumiLabLiveRolloutSnapshot(identity: id, submittedControlSteps: 1,
        completedEnvironmentSteps: 0, submissionCount: 0),
      NumiLabLiveRolloutSnapshot(identity: id, submittedControlSteps: 0,
        completedEnvironmentSteps: 1, submissionCount: 0),
      NumiLabLiveRolloutSnapshot(identity: id, submittedControlSteps: 0,
        completedEnvironmentSteps: 0, submissionCount: 1),
    ] {
      XCTAssertThrowsError(try NumiLabReplayCheckpoint(origin: bad))
    }
    let batched = NumiLabLiveRolloutSnapshot(
      identity: try identity(environmentCount: 2),
      submittedControlSteps: 0,
      completedEnvironmentSteps: 0,
      submissionCount: 0
    )
    XCTAssertThrowsError(try NumiLabReplayCheckpoint(origin: batched))
  }

  func testRuntimeRequiresHardenedPhysicalOwnerRevision() {
    XCTAssertEqual(
      NumiLabBorrowedTaskRollout.requiredNativeRevision,
      "4a369ca846fde93016f3708f3fd9386c992b52a4"
    )
  }
}

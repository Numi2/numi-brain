import XCTest
@testable import NumiBrainMetal

/// Synthetic immutable receipts test admission arithmetic, not physical success.
@available(macOS 26.0, *)
final class NumiLabRolloutReceiptTests: XCTestCase {
  private func receipt(before: (UInt64, UInt64, UInt64) = (0,0,0),
    after: (UInt64, UInt64, UInt64) = (1,1,1), environments: UInt32 = 1,
    foreign: Bool = false, resets: UInt32 = 0, gpuStatus: UInt32 = 0,
    gpuTime: Double = 0.1, submissionTime: Double = 0.2,
    policy: UInt64 = 42) throws -> NumiLabRolloutAdvanceReceipt {
    let identity = try NumiLabLiveRolloutIdentity(environmentCount: environments, actionCount: 2,
      runFingerprint: 11, worldFingerprint: 12, taskFingerprint: 13, actionFingerprint: 14, robotFingerprint: 15)
    let other = try NumiLabLiveRolloutIdentity(environmentCount: environments, actionCount: 2,
      runFingerprint: foreign ? 16 : 11, worldFingerprint: 12, taskFingerprint: 13, actionFingerprint: 14, robotFingerprint: 15)
    return NumiLabRolloutAdvanceReceipt(
      before: NumiLabLiveRolloutSnapshot(identity: identity, submittedControlSteps: before.0,
        completedEnvironmentSteps: before.1, submissionCount: before.2),
      after: NumiLabLiveRolloutSnapshot(identity: other, submittedControlSteps: after.0,
        completedEnvironmentSteps: after.1, submissionCount: after.2),
      controlStepCount: 1, successfulEnvironmentSteps: 1, failedEnvironmentSteps: 0,
      firstFailingEnvironment: UInt32.max, firstFailingControlStep: UInt32.max,
      firstGPUStatusCode: gpuStatus, hostRequestedResets: resets, maximumActiveContacts: 0,
      maximumManifolds: 0, gpuMilliseconds: gpuTime, submissionMilliseconds: submissionTime,
      policyRevision: policy)
  }

  func testCleanReceiptCarriesExactExecutedPolicyIncludingZero() throws {
    for policy: UInt64 in [0, 42, UInt64.max] {
      let value = try receipt(policy: policy)
      XCTAssertTrue(value.fullyAccepted)
      XCTAssertEqual(try value.policyRevisionForReplay(expected: nil), policy)
      XCTAssertEqual(try value.policyRevisionForReplay(expected: policy), policy)
      XCTAssertThrowsError(try value.policyRevisionForReplay(expected: policy ^ 1))
    }
  }

  func testCounterOverflowAndNoncontiguousReceiptsAreRejectedWithoutTrapping() throws {
    for counters in [(UInt64.max,UInt64(0),UInt64(0)), (0,UInt64.max,0), (0,0,UInt64.max)] {
      XCTAssertFalse(try receipt(before: counters).fullyAccepted)
    }
    for counters: (UInt64,UInt64,UInt64) in [(0,1,1),(1,2,1),(1,1,2)] {
      XCTAssertFalse(try receipt(after: counters).fullyAccepted)
    }
    let edge = try receipt(before: (UInt64.max-1,UInt64.max-1,UInt64.max-1),
      after: (UInt64.max,UInt64.max,UInt64.max))
    XCTAssertTrue(edge.fullyAccepted)
  }

  func testResetIdentityDriftAndGPUFailureCannotBecomeAcceptedReceipts() throws {
    for value in [try receipt(environments: 2), try receipt(foreign: true),
                  try receipt(resets: 1), try receipt(gpuStatus: 1)] {
      XCTAssertFalse(value.fullyAccepted)
      XCTAssertThrowsError(try value.policyRevisionForReplay(expected: nil))
    }
  }

  func testTimingCorruptionCannotBeHiddenByValidCounters() throws {
    for value in [Double.nan, .infinity, -.infinity, -0.1] {
      XCTAssertFalse(try receipt(gpuTime: value).fullyAccepted)
      XCTAssertFalse(try receipt(submissionTime: value).fullyAccepted)
    }
  }
}

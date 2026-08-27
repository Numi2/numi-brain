import Metal
import XCTest

@testable import NumiBrainCore
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalDispatchPlanRuntimeTests: XCTestCase {
  private func makePlan() throws -> (BrainDispatchPlan, BrainParameterVersion) {
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let program = try RegionalTokenProgram.runtimeFoundationV0(schedule: schedule)
    let version = try BrainParameterVersion.runtimeFoundationV0(
      schedule: schedule,
      regionalProgram: program,
      tissueParameters: .corticalSheetV0
    )
    let identifiers: [UInt32] = [22, 4, 17, 9]
    let environments = try identifiers.enumerated().map { index, identifier in
      let scheduler = CPUMultiRateScheduler(
        schedule: schedule,
        parameterVersionFingerprint: version.fingerprint
      )
      let events = index == 2
        ? [
          try BrainInterruptEvent(
            timestamp: BrainTimestamp(microseconds: 6_250),
            mask: [.pain, .lossOfSupport],
            identifier: 700
          )
        ]
        : []
      return BrainScheduledEnvironment(
        environmentIdentifier: identifier,
        transaction: try scheduler.beginAdvance(
          to: BrainTimestamp(microseconds: 20_000),
          events: events
        )
      )
    }
    return (try BrainDispatchPlan(environments: environments), version)
  }

  func testMetalMaterializesExactVersionedCohortPlanAndReplay() throws {
    try requireMetal4()
    let (plan, version) = try makePlan()
    let first = try MetalDispatchPlanRuntime.materialize(
      plan: plan,
      parameterVersion: version
    )
    let replay = try MetalDispatchPlanRuntime.materialize(
      plan: plan,
      parameterVersion: version
    )

    XCTAssertEqual(first.status, 0)
    XCTAssertEqual(first.planFingerprint, plan.fingerprint)
    XCTAssertEqual(first.parameterVersionFingerprint, version.fingerprint)
    XCTAssertEqual(first.groups, plan.groups)
    XCTAssertEqual(first.groups, replay.groups)
    XCTAssertEqual(first.planFingerprint, replay.planFingerprint)
    XCTAssertEqual(first.parameterVersionFingerprint, replay.parameterVersionFingerprint)
    XCTAssertEqual(first.entryCount, plan.entryCount)
    XCTAssertFalse(first.deviceName.isEmpty)
    XCTAssertGreaterThanOrEqual(first.gpuDurationSeconds, 0)
    XCTAssertEqual(
      first.privateInputByteCount,
      BrainDispatchPlan.headerByteCount
        + plan.groups.count * BrainDispatchPlan.groupByteCount
        + plan.entryCount * BrainDispatchPlan.entryByteCount
        + BrainParameterVersion.bindingByteCount
    )
    XCTAssertEqual(
      first.privateOutputByteCount,
      plan.groups.count * BrainDispatchPlan.groupByteCount
        + plan.entryCount * BrainDispatchPlan.entryByteCount
        + BrainDispatchPlan.resultByteCount
    )
  }

  func testMetalRejectsStaleParameterGenerationBeforeUpload() throws {
    try requireMetal4()
    let (plan, version) = try makePlan()
    let successor = try version.successor(
      regionalProgramFingerprint: version.regionalProgramFingerprint,
      components: version.components
    )
    XCTAssertNotEqual(successor.fingerprint, version.fingerprint)
    XCTAssertThrowsError(
      try MetalDispatchPlanRuntime.materialize(
        plan: plan,
        parameterVersion: successor
      )
    )
  }

  private func requireMetal4() throws {
    guard MTLCreateSystemDefaultDevice() != nil else {
      throw XCTSkip("Metal device unavailable")
    }
  }
}

import Foundation
import NumiBrainABI
import XCTest

@testable import NumiBrainCore

final class BrainDispatchPlanTests: XCTestCase {
  private func makeInputs() throws -> (
    BrainModuleSchedule,
    BrainParameterVersion,
    [BrainScheduledEnvironment]
  ) {
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let program = try RegionalTokenProgram.runtimeFoundationV0(schedule: schedule)
    let version = try BrainParameterVersion.runtimeFoundationV0(
      schedule: schedule,
      regionalProgram: program,
      tissueParameters: .corticalSheetV0
    )
    let identifiers: [UInt32] = [19, 3, 11]
    let environments = try identifiers.enumerated().map { index, identifier in
      let scheduler = CPUMultiRateScheduler(
        schedule: schedule,
        parameterVersionFingerprint: version.fingerprint
      )
      let events =
        index == 1
        ? [
          try BrainInterruptEvent(
            timestamp: BrainTimestamp(microseconds: 7_500),
            mask: .pain,
            identifier: 100 + UInt32(index)
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
    return (schedule, version, environments)
  }

  func testCompiledDispatchPlanABIAndCanonicalFlattening() throws {
    XCTAssertEqual(nb_brain_abi_cohort_environment_size(), 40)
    XCTAssertEqual(nb_brain_abi_dispatch_group_size(), 24)
    XCTAssertEqual(nb_brain_abi_dispatch_entry_size(), 16)
    XCTAssertEqual(nb_brain_abi_dispatch_plan_header_size(), 48)
    XCTAssertEqual(nb_brain_abi_dispatch_plan_result_size(), 32)
    XCTAssertEqual(nb_brain_abi_dispatch_work_item_size(), 32)
    XCTAssertEqual(nb_brain_abi_dispatch_cohort_uniforms_size(), 32)
    XCTAssertEqual(nb_brain_abi_dispatch_token_uniforms_size(), 32)
    XCTAssertEqual(MemoryLayout<NBCohortEnvironment>.stride, 40)
    XCTAssertEqual(MemoryLayout<NBDispatchGroup>.stride, 24)
    XCTAssertEqual(MemoryLayout<NBDispatchEntry>.stride, 16)
    XCTAssertEqual(MemoryLayout<NBDispatchPlanHeader>.stride, 48)
    XCTAssertEqual(MemoryLayout<NBDispatchPlanResult>.stride, 32)
    XCTAssertEqual(MemoryLayout<NBDispatchWorkItem>.stride, 32)

    let (schedule, version, environments) = try makeInputs()
    let plan = try BrainDispatchPlan(environments: environments)
    let reversed = try BrainDispatchPlan(environments: Array(environments.reversed()))
    XCTAssertEqual(plan, reversed)
    XCTAssertEqual(plan.scheduleFingerprint, schedule.fingerprint)
    XCTAssertEqual(plan.parameterVersionFingerprint, version.fingerprint)
    XCTAssertGreaterThan(plan.cohortFingerprint, 0)
    XCTAssertGreaterThan(plan.fingerprint, 0)
    XCTAssertFalse(plan.groups.isEmpty)
    XCTAssertEqual(plan.entryCount, plan.groups.reduce(0) { $0 + $1.entries.count })
    XCTAssertEqual(plan.workItems.count, plan.entryCount)
    XCTAssertGreaterThan(plan.workFingerprint, 0)
    XCTAssertTrue(
      plan.groups.allSatisfy { group in
        group.entries.map(\.environmentIdentifier)
          == group.entries.map(\.environmentIdentifier).sorted()
      }
    )

    var header = plan.abiHeader
    let groups = plan.groupABIRecords
    let entries = plan.entryABIRecords
    let validation = groups.withUnsafeBufferPointer { groups in
      entries.withUnsafeBufferPointer { entries in
        withUnsafePointer(to: &header) { header in
          nb_brain_abi_validate_dispatch_plan(
            header,
            groups.baseAddress,
            entries.baseAddress
          )
        }
      }
    }
    XCTAssertEqual(validation, UInt32(NB_DISPATCH_PLAN_VALID.rawValue))
    let recomputed = groups.withUnsafeBufferPointer { groups in
      entries.withUnsafeBufferPointer { entries in
        withUnsafePointer(to: &header) { header in
          nb_brain_abi_dispatch_plan_fingerprint(
            header,
            groups.baseAddress,
            entries.baseAddress
          )
        }
      }
    }
    XCTAssertEqual(recomputed, plan.fingerprint)
    let workRecords = plan.workItems.map(\.abiRecord)
    let workFingerprint = workRecords.withUnsafeBufferPointer { records in
      nb_brain_abi_dispatch_work_fingerprint(
        plan.fingerprint,
        version.fingerprint,
        records.baseAddress,
        UInt32(records.count)
      )
    }
    XCTAssertEqual(workFingerprint, plan.workFingerprint)
  }

  func testDispatchPlanPreservesIndependentInterruptEntries() throws {
    let (_, _, environments) = try makeInputs()
    let plan = try BrainDispatchPlan(environments: environments)
    let interruptGroups = plan.groups.filter {
      $0.timestamp == BrainTimestamp(microseconds: 7_500)
    }
    XCTAssertEqual(interruptGroups.map(\.moduleIdentifier), [12, 26, 95])
    XCTAssertTrue(
      interruptGroups.allSatisfy { group in
        group.entries.count == 1
          && group.entries[0].environmentIdentifier == 3
          && group.entries[0].reasons == .interrupt
          && group.entries[0].interruptMask == .pain
      }
    )
    let interruptWorkItems = plan.workItems.filter {
      $0.timestamp == BrainTimestamp(microseconds: 7_500)
    }
    XCTAssertEqual(interruptWorkItems.map(\.moduleIdentifier), [12, 26, 95])
    XCTAssertTrue(
      interruptWorkItems.allSatisfy { item in
        item.environmentIdentifier == 3
          && item.reasons == .interrupt
          && item.interruptMask == .pain
          && plan.groups[Int(item.groupIndex)].moduleIdentifier == item.moduleIdentifier
      }
    )
    let periodic = try XCTUnwrap(
      plan.groups.first {
        $0.timestamp == BrainTimestamp(microseconds: 20_000)
          && $0.moduleIdentifier == 12
      }
    )
    XCTAssertEqual(periodic.entries.map(\.environmentIdentifier), [3, 11, 19])
    XCTAssertTrue(periodic.entries.allSatisfy { $0.reasons == .periodic })
  }

  func testDispatchPlanSerializationRejectsTampering() throws {
    let (_, _, environments) = try makeInputs()
    let plan = try BrainDispatchPlan(environments: environments)
    let data = try JSONEncoder().encode(plan)
    XCTAssertEqual(try JSONDecoder().decode(BrainDispatchPlan.self, from: data), plan)
    var text = try XCTUnwrap(String(data: data, encoding: .utf8))
    let original = "\"fingerprint\":\(plan.fingerprint)"
    XCTAssertTrue(text.contains(original))
    text = text.replacingOccurrences(
      of: original,
      with: "\"fingerprint\":\(plan.fingerprint &+ 1)"
    )
    XCTAssertThrowsError(
      try JSONDecoder().decode(
        BrainDispatchPlan.self,
        from: try XCTUnwrap(text.data(using: .utf8))
      )
    )
  }

  func testDispatchPlanRejectsMixedOrUnversionedCohorts() throws {
    let (schedule, _, environments) = try makeInputs()
    let unversioned = CPUMultiRateScheduler(schedule: schedule)
    let unversionedEnvironment = BrainScheduledEnvironment(
      environmentIdentifier: 101,
      transaction: try unversioned.beginAdvance(to: BrainTimestamp(microseconds: 20_000))
    )
    XCTAssertThrowsError(try BrainDispatchPlan(environments: [unversionedEnvironment]))
    XCTAssertThrowsError(
      try BrainDispatchPlan(environments: [environments[0], unversionedEnvironment])
    )
    XCTAssertThrowsError(try BrainDispatchPlan(environments: []))
  }

  func testCompiledValidatorRejectsEntryOrderAndReasonDrift() throws {
    let (_, _, environments) = try makeInputs()
    let plan = try BrainDispatchPlan(environments: environments)
    var header = plan.abiHeader
    let groups = plan.groupABIRecords
    var entries = plan.entryABIRecords
    let groupIndex = try XCTUnwrap(
      groups.firstIndex(where: { $0.entry_count > 1 })
    )
    let start = Int(groups[groupIndex].entry_offset)
    entries.swapAt(start, start + 1)
    let orderValidation = groups.withUnsafeBufferPointer { groups in
      entries.withUnsafeBufferPointer { entries in
        withUnsafePointer(to: &header) { header in
          nb_brain_abi_validate_dispatch_plan(header, groups.baseAddress, entries.baseAddress)
        }
      }
    }
    XCTAssertEqual(orderValidation, UInt32(NB_DISPATCH_PLAN_ENTRY_ORDER.rawValue))

    entries = plan.entryABIRecords
    entries[0].reason_flags = 0
    let valueValidation = groups.withUnsafeBufferPointer { groups in
      entries.withUnsafeBufferPointer { entries in
        withUnsafePointer(to: &header) { header in
          nb_brain_abi_validate_dispatch_plan(header, groups.baseAddress, entries.baseAddress)
        }
      }
    }
    XCTAssertEqual(valueValidation, UInt32(NB_DISPATCH_PLAN_ENTRY_VALUE.rawValue))
  }

  func testDispatchPlanRetryAndDiscardPreserveCommittedSchedulerState() throws {
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let program = try RegionalTokenProgram.runtimeFoundationV0(schedule: schedule)
    let version = try BrainParameterVersion.runtimeFoundationV0(
      schedule: schedule,
      regionalProgram: program,
      tissueParameters: .corticalSheetV0
    )
    var scheduler = CPUMultiRateScheduler(
      schedule: schedule,
      parameterVersionFingerprint: version.fingerprint
    )
    let events = [
      try BrainInterruptEvent(
        timestamp: BrainTimestamp(microseconds: 9_250),
        mask: .pain,
        identifier: 2
      ),
      try BrainInterruptEvent(
        timestamp: BrainTimestamp(microseconds: 7_750),
        mask: .lossOfSupport,
        identifier: 1
      ),
    ]
    let before = scheduler.snapshot
    let first = try scheduler.beginAdvance(
      to: BrainTimestamp(microseconds: 20_000),
      events: events
    )
    let retry = try scheduler.beginAdvance(
      to: BrainTimestamp(microseconds: 20_000),
      events: Array(events.reversed())
    )
    let firstPlan = try BrainDispatchPlan(
      environments: [BrainScheduledEnvironment(environmentIdentifier: 5, transaction: first)]
    )
    let retryPlan = try BrainDispatchPlan(
      environments: [BrainScheduledEnvironment(environmentIdentifier: 5, transaction: retry)]
    )
    XCTAssertEqual(firstPlan, retryPlan)
    XCTAssertEqual(scheduler.snapshot, before)

    try scheduler.commit(first)
    let committed = scheduler.snapshot
    XCTAssertNotEqual(committed, before)
    let next = try scheduler.beginAdvance(to: BrainTimestamp(microseconds: 40_000))
    let nextPlan = try BrainDispatchPlan(
      environments: [BrainScheduledEnvironment(environmentIdentifier: 5, transaction: next)]
    )
    XCTAssertNotEqual(nextPlan.cohortFingerprint, firstPlan.cohortFingerprint)
    XCTAssertEqual(scheduler.snapshot, committed)
  }

  func testCompiledValidatorRejectsEntrySpanCapacityDrift() throws {
    let (_, _, environments) = try makeInputs()
    let plan = try BrainDispatchPlan(environments: environments)
    var header = plan.abiHeader
    var groups = plan.groupABIRecords
    let entries = plan.entryABIRecords
    groups[0].entry_count = UInt32.max
    let validation = groups.withUnsafeBufferPointer { groups in
      entries.withUnsafeBufferPointer { entries in
        withUnsafePointer(to: &header) { header in
          nb_brain_abi_validate_dispatch_plan(header, groups.baseAddress, entries.baseAddress)
        }
      }
    }
    XCTAssertEqual(validation, UInt32(NB_DISPATCH_PLAN_ENTRY_LAYOUT.rawValue))
  }
}

import Foundation
import NumiBrainABI
import XCTest

@testable import NumiBrainCore

final class BrainSchedulerTests: XCTestCase {
  func testCompiledModuleABIAndFingerprintAreStable() throws {
    XCTAssertEqual(nb_brain_abi_module_descriptor_size(), 32)
    XCTAssertEqual(nb_brain_abi_module_clock_state_size(), 16)
    XCTAssertEqual(nb_brain_abi_interrupt_event_size(), 24)
    XCTAssertEqual(nb_brain_abi_due_invocation_size(), 32)
    XCTAssertEqual(nb_brain_abi_scheduler_uniforms_size(), 40)
    XCTAssertEqual(nb_brain_abi_scheduler_result_size(), 16)
    XCTAssertEqual(nb_brain_abi_module_descriptor_offset_module_id(), 0)
    XCTAssertEqual(nb_brain_abi_module_descriptor_offset_interrupt_mask(), 16)
    XCTAssertEqual(nb_brain_abi_module_descriptor_offset_flags(), 28)
    XCTAssertEqual(BrainModuleSchedule.abiVersion, 1)
    XCTAssertEqual(BrainModuleSchedule.moduleDescriptorByteCount, 32)

    let forward = try makeSchedule()
    let reversed = try BrainModuleSchedule(modules: forward.modules.reversed())
    XCTAssertEqual(forward.modules.map(\.moduleIdentifier), [12, 25, 77])
    XCTAssertEqual(forward.fingerprint, reversed.fingerprint)
    XCTAssertEqual(forward.fingerprintHex, "91641fbb345b98b1")

    var invalid = NBModuleDescriptor()
    invalid.module_id = 1
    invalid.period_microseconds = 1
    invalid.token_count = 1
    invalid.token_dimension = 1
    let invalidResult = withUnsafePointer(to: &invalid) {
      nb_brain_abi_validate_module_descriptors($0, 1)
    }
    XCTAssertEqual(
      invalidResult,
      UInt32(NB_MODULE_DESCRIPTOR_ZERO_TIMESCALE.rawValue)
    )
  }

  func testReferenceScheduleAndSerializedFingerprintAreCanonical() throws {
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    XCTAssertEqual(schedule.modules.count, 8)
    XCTAssertEqual(schedule.fingerprintHex, "c0162952817e2b01")
    XCTAssertEqual(
      schedule.modules.map(\.periodMicroseconds),
      [1_000, 50_000, 1_000, 20_000, 100_000, 5_000, 2_000, 1_000]
    )

    let encoded = try JSONEncoder().encode(schedule)
    XCTAssertEqual(try JSONDecoder().decode(BrainModuleSchedule.self, from: encoded), schedule)
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    object["fingerprint"] = NSNumber(value: UInt64.zero)
    let corrupted = try JSONSerialization.data(withJSONObject: object)
    XCTAssertThrowsError(
      try JSONDecoder().decode(BrainModuleSchedule.self, from: corrupted)
    )
  }

  func testPeriodicModulesUsePhysicalTimeWithoutBoundaryDuplication() throws {
    var scheduler = CPUMultiRateScheduler(schedule: try makeSchedule())
    let first = try scheduler.advance(to: time(10_000))

    XCTAssertEqual(first.filter { $0.moduleIdentifier == 12 }.count, 11)
    XCTAssertEqual(first.filter { $0.moduleIdentifier == 25 }.count, 3)
    XCTAssertEqual(first.filter { $0.moduleIdentifier == 77 }.count, 2)
    XCTAssertEqual(first.first?.timestamp, time(0))
    XCTAssertEqual(first.first?.moduleIdentifier, 12)
    XCTAssertEqual(first.last?.timestamp, time(10_000))

    let second = try scheduler.advance(to: time(20_000))
    XCTAssertEqual(second.filter { $0.moduleIdentifier == 12 }.count, 10)
    XCTAssertEqual(second.filter { $0.moduleIdentifier == 25 }.count, 2)
    XCTAssertEqual(second.filter { $0.moduleIdentifier == 77 }.count, 1)
    XCTAssertFalse(second.contains { $0.timestamp == time(10_000) })
    XCTAssertEqual(scheduler.snapshot.committedTime, time(20_000))
    XCTAssertEqual(scheduler.snapshot.generation, 2)
  }

  func testInterruptBypassesPeriodAndMergesAtExactTimestamp() throws {
    var scheduler = CPUMultiRateScheduler(schedule: try makeSchedule())
    _ = try scheduler.advance(to: time(0))
    let pain = try BrainInterruptEvent(
      timestamp: time(3_500),
      mask: .pain,
      identifier: 8
    )
    let support = try BrainInterruptEvent(
      timestamp: time(3_500),
      mask: .lossOfSupport,
      identifier: 9
    )
    let impact = try BrainInterruptEvent(
      timestamp: time(4_000),
      mask: .impact,
      identifier: 10
    )
    let invocations = try scheduler.advance(
      to: time(4_000),
      events: [impact, support, pain]
    )

    let interrupted = try XCTUnwrap(
      invocations.first {
        $0.moduleIdentifier == 12 && $0.timestamp == time(3_500)
      }
    )
    XCTAssertEqual(interrupted.reasons, .interrupt)
    XCTAssertEqual(interrupted.interruptMask, [.pain, .lossOfSupport])
    XCTAssertFalse(
      invocations.contains {
        $0.moduleIdentifier == 25 && $0.timestamp == time(3_500)
      }
    )
    let coincident = try XCTUnwrap(
      invocations.first {
        $0.moduleIdentifier == 12 && $0.timestamp == time(4_000)
      }
    )
    XCTAssertEqual(coincident.reasons, [.periodic, .interrupt])
    XCTAssertEqual(coincident.interruptMask, .impact)
  }

  func testAbortAndRetryPreserveSchedulerHistoryExactly() throws {
    let schedule = try makeSchedule()
    var retried = CPUMultiRateScheduler(schedule: schedule)
    var direct = CPUMultiRateScheduler(schedule: schedule)
    let event = try BrainInterruptEvent(
      timestamp: time(7_250),
      mask: [.impact, .pain],
      identifier: 44
    )

    let beforeAbort = retried.snapshot
    let rejected = try retried.beginAdvance(to: time(20_000), events: [event])
    XCTAssertEqual(retried.snapshot, beforeAbort)
    let retry = try retried.beginAdvance(to: time(20_000), events: [event])
    XCTAssertEqual(rejected, retry)
    try retried.commit(retry)

    let accepted = try direct.beginAdvance(to: time(20_000), events: [event])
    try direct.commit(accepted)
    XCTAssertEqual(retried.snapshot, direct.snapshot)
    XCTAssertEqual(retried.snapshot.stableHash(), direct.snapshot.stableHash())
  }

  func testCheckpointRestoreAndStaleTransactionValidation() throws {
    let schedule = try makeSchedule()
    var original = CPUMultiRateScheduler(schedule: schedule)
    let first = try original.beginAdvance(to: time(5_000))
    try original.commit(first)
    XCTAssertThrowsError(try original.commit(first))

    var restored = try CPUMultiRateScheduler(
      schedule: schedule,
      restoring: original.snapshot
    )
    let originalFuture = try original.advance(to: time(15_000))
    let restoredFuture = try restored.advance(to: time(15_000))
    XCTAssertEqual(originalFuture, restoredFuture)
    XCTAssertEqual(original.snapshot.stableHash(), restored.snapshot.stableHash())
  }

  func testCohortCompactionPreservesIndependentInterruptState() throws {
    let schedule = try makeSchedule()
    var first = CPUMultiRateScheduler(schedule: schedule)
    var second = CPUMultiRateScheduler(schedule: schedule)
    _ = try first.advance(to: time(0))
    _ = try second.advance(to: time(0))
    let event = try BrainInterruptEvent(
      timestamp: time(2_500),
      mask: .damagingContact,
      identifier: 91
    )
    let firstTransaction = try first.beginAdvance(to: time(5_000), events: [event])
    let secondTransaction = try second.beginAdvance(to: time(5_000))
    let groups = try BrainSchedulerCohort.compact([
      BrainScheduledEnvironment(
        environmentIdentifier: 8,
        transaction: secondTransaction
      ),
      BrainScheduledEnvironment(
        environmentIdentifier: 3,
        transaction: firstTransaction
      ),
    ])

    let eventGroup = try XCTUnwrap(
      groups.first {
        $0.moduleIdentifier == 12 && $0.timestamp == time(2_500)
      }
    )
    XCTAssertEqual(eventGroup.entries.map(\.environmentIdentifier), [3])
    XCTAssertEqual(eventGroup.entries.first?.interruptMask, .damagingContact)
    let sharedPeriodic = try XCTUnwrap(
      groups.first {
        $0.moduleIdentifier == 12 && $0.timestamp == time(1_000)
      }
    )
    XCTAssertEqual(sharedPeriodic.entries.map(\.environmentIdentifier), [3, 8])
  }

  func testSchedulerRejectsBackwardAndStaleEventTime() throws {
    var scheduler = CPUMultiRateScheduler(schedule: try makeSchedule())
    _ = try scheduler.advance(to: time(5_000))
    XCTAssertThrowsError(try scheduler.beginAdvance(to: time(4_999)))
    let stale = try BrainInterruptEvent(
      timestamp: time(4_999),
      mask: .pain,
      identifier: 1
    )
    XCTAssertThrowsError(
      try scheduler.beginAdvance(to: time(6_000), events: [stale])
    )
    let future = try BrainInterruptEvent(
      timestamp: time(6_001),
      mask: .pain,
      identifier: 3
    )
    XCTAssertThrowsError(
      try scheduler.beginAdvance(to: time(6_000), events: [future])
    )
    let event = try BrainInterruptEvent(
      timestamp: time(5_500),
      mask: .pain,
      identifier: 2
    )
    XCTAssertThrowsError(
      try scheduler.beginAdvance(
        to: time(6_000),
        events: Array(
          repeating: event,
          count: CPUMultiRateScheduler.maximumEventsPerTransaction + 1
        )
      )
    )

    let invalidCheckpoint = BrainSchedulerSnapshot(
      scheduleFingerprint: scheduler.schedule.fingerprint,
      committedTime: time(5_000),
      generation: 1,
      moduleClocks: scheduler.snapshot.moduleClocks.map { _ in
        BrainModuleClockState(nextDue: time(4_999))
      }
    )
    XCTAssertThrowsError(
      try CPUMultiRateScheduler(
        schedule: scheduler.schedule,
        restoring: invalidCheckpoint
      )
    )
  }

  private func makeSchedule() throws -> BrainModuleSchedule {
    try BrainModuleSchedule(modules: [
      BrainModuleDescriptor(
        moduleIdentifier: 77,
        clockClass: .planning,
        periodMicroseconds: 10_000,
        conductionDelayMicroseconds: 5_000,
        intrinsicTimescaleMicroseconds: 250_000,
        tokenCount: 8,
        tokenDimension: 256
      ),
      BrainModuleDescriptor(
        moduleIdentifier: 12,
        clockClass: .emergency,
        periodMicroseconds: 1_000,
        intrinsicTimescaleMicroseconds: 5_000,
        interruptMask: [.pain, .damagingContact, .lossOfSupport, .impact],
        tokenCount: 2,
        tokenDimension: 64
      ),
      BrainModuleDescriptor(
        moduleIdentifier: 25,
        clockClass: .workspace,
        periodMicroseconds: 5_000,
        conductionDelayMicroseconds: 2_000,
        intrinsicTimescaleMicroseconds: 100_000,
        tokenCount: 16,
        tokenDimension: 256
      ),
    ])
  }

  private func time(_ microseconds: UInt64) -> BrainTimestamp {
    BrainTimestamp(microseconds: microseconds)
  }
}

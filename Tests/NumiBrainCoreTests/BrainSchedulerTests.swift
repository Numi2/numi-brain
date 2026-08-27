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
    XCTAssertEqual(nb_brain_abi_regional_module_state_size(), 32)
    XCTAssertEqual(nb_brain_abi_regional_token_layout_size(), 32)
    XCTAssertEqual(nb_brain_abi_regional_route_size(), 24)
    XCTAssertEqual(nb_brain_abi_regional_token_parameters_size(), 32)
    XCTAssertEqual(nb_brain_abi_regional_program_header_size(), 32)
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

  func testRegionalModuleOperatorConsumesCanonicalDueInvocations() throws {
    let schedule = try makeSchedule()
    var scheduler = CPUMultiRateScheduler(schedule: schedule)
    let pain = try BrainInterruptEvent(
      timestamp: time(3_500),
      mask: .pain,
      identifier: 8
    )
    let impact = try BrainInterruptEvent(
      timestamp: time(4_000),
      mask: .impact,
      identifier: 9
    )
    let invocations = try scheduler.advance(to: time(4_000), events: [impact, pain])
    let initial = schedule.modules.map { _ in RegionalModuleState() }
    let first = try CPURegionalModuleOperator.advance(
      states: initial,
      schedule: schedule,
      invocations: invocations
    )
    let replay = try CPURegionalModuleOperator.advance(
      states: initial,
      schedule: schedule,
      invocations: invocations
    )

    XCTAssertEqual(first, replay)
    XCTAssertEqual(first.count, schedule.modules.count)
    let emergencyIndex = try XCTUnwrap(
      schedule.modules.firstIndex { $0.moduleIdentifier == 12 }
    )
    XCTAssertEqual(first[emergencyIndex].updateCount, 6)
    XCTAssertEqual(first[emergencyIndex].interruptCount, 2)
    XCTAssertEqual(first[emergencyIndex].lastUpdate, time(4_000))
    XCTAssertEqual(first[emergencyIndex].phase, 0)
    XCTAssertGreaterThan(first[emergencyIndex].activation, 0)
    XCTAssertGreaterThan(first[emergencyIndex].interruptSalience, 0)
    XCTAssertEqual(
      RegionalModuleState(abiRecord: first[emergencyIndex].abiRecord),
      first[emergencyIndex]
    )

    let snapshot = RegionalModuleSnapshot(
      scheduleFingerprint: schedule.fingerprint,
      committedTime: scheduler.snapshot.committedTime,
      generation: scheduler.snapshot.generation,
      states: first
    )
    let initialSnapshot = RegionalModuleSnapshot(
      scheduleFingerprint: schedule.fingerprint,
      committedTime: time(0),
      generation: 0,
      states: initial
    )
    XCTAssertNotEqual(snapshot.stableHash(), initialSnapshot.stableHash())
  }

  func testRegionalTokenProgramIsCompiledCanonicalAndRouted() throws {
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let program = try RegionalTokenProgram.runtimeFoundationV0(schedule: schedule)

    XCTAssertEqual(program.layouts.count, 8)
    XCTAssertEqual(program.scalarCount, 10_752)
    XCTAssertEqual(program.parameters.count, program.scalarCount)
    XCTAssertEqual(program.routes.count, 7)
    XCTAssertEqual(program.headerRecord.module_count, 8)
    XCTAssertEqual(program.headerRecord.token_scalar_count, 10_752)
    XCTAssertEqual(program.headerRecord.route_count, 7)
    XCTAssertEqual(program.headerRecord.parameter_count, 10_752)
    XCTAssertEqual(program.headerRecord.program_fingerprint, program.fingerprint)
    XCTAssertEqual(
      program.layouts.map(\.scalarOffset), [0, 256, 4_352, 4_864, 6_912, 8_960, 9_984, 10_240])
    XCTAssertEqual(
      program.routes.map { [$0.senderModuleIdentifier, $0.receiverModuleIdentifier] },
      [[37, 25], [12, 26], [25, 77], [95, 83], [26, 95], [83, 95], [90, 95]]
    )
    XCTAssertNotEqual(program.fingerprint, 0)
  }

  func testRegionalTokenOperatorRoutesCausallyAndPreservesChunking() throws {
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let routedProgram = try RegionalTokenProgram.runtimeFoundationV0(schedule: schedule)
    let isolatedProgram = try RegionalTokenProgram(
      schedule: schedule,
      routes: [],
      parameters: routedProgram.parameters
    )
    let initialTokens = [Float](repeating: 0, count: routedProgram.scalarCount)
    let initialDiagnostics = schedule.modules.map { _ in RegionalModuleState() }
    let pain = try BrainInterruptEvent(
      timestamp: time(7_500),
      mask: [.pain, .impact],
      identifier: 91
    )

    var fullScheduler = CPUMultiRateScheduler(schedule: schedule)
    let fullInvocations = try fullScheduler.advance(to: time(20_000), events: [pain])
    let routed = try CPURegionalTokenOperator.advance(
      state: initialTokens,
      diagnostics: initialDiagnostics,
      schedule: schedule,
      program: routedProgram,
      invocations: fullInvocations
    )
    let replay = try CPURegionalTokenOperator.advance(
      state: initialTokens,
      diagnostics: initialDiagnostics,
      schedule: schedule,
      program: routedProgram,
      invocations: fullInvocations
    )
    let isolated = try CPURegionalTokenOperator.advance(
      state: initialTokens,
      diagnostics: initialDiagnostics,
      schedule: schedule,
      program: isolatedProgram,
      invocations: fullInvocations
    )
    XCTAssertEqual(routed, replay)
    let emergencyBus = try XCTUnwrap(
      routedProgram.layouts.first { $0.moduleIdentifier == 26 }
    )
    XCTAssertGreaterThan(
      maximumDifference(
        Array(routed[emergencyBus.scalarRange]),
        Array(isolated[emergencyBus.scalarRange])
      ),
      1e-5
    )

    var chunkedScheduler = CPUMultiRateScheduler(schedule: schedule)
    let firstInvocations = try chunkedScheduler.advance(to: time(10_000), events: [pain])
    let firstTokens = try CPURegionalTokenOperator.advance(
      state: initialTokens,
      diagnostics: initialDiagnostics,
      schedule: schedule,
      program: routedProgram,
      invocations: firstInvocations
    )
    let firstDiagnostics = try CPURegionalModuleOperator.advance(
      states: initialDiagnostics,
      schedule: schedule,
      invocations: firstInvocations
    )
    let secondInvocations = try chunkedScheduler.advance(to: time(20_000))
    let chunked = try CPURegionalTokenOperator.advance(
      state: firstTokens,
      diagnostics: firstDiagnostics,
      schedule: schedule,
      program: routedProgram,
      invocations: secondInvocations
    )
    XCTAssertEqual(routed, chunked)

    let snapshot = RegionalTokenSnapshot(
      scheduleFingerprint: schedule.fingerprint,
      programFingerprint: routedProgram.fingerprint,
      committedTime: time(20_000),
      generation: 1,
      values: routed
    )
    XCTAssertNotEqual(snapshot.stableHash(), String(repeating: "0", count: 16))
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

  private func maximumDifference(_ lhs: [Float], _ rhs: [Float]) -> Float {
    zip(lhs, rhs).reduce(0) { maximum, pair in
      max(maximum, abs(pair.0 - pair.1))
    }
  }
}

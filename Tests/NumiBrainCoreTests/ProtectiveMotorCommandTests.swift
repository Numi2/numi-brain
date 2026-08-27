import NumiBrainABI
import XCTest

@testable import NumiBrainCore

final class ProtectiveMotorCommandTests: XCTestCase {
  func testCompiledProtectiveCommandABIAndReferenceMapping() throws {
    XCTAssertEqual(
      nb_brain_abi_protective_command_size(),
      ProtectiveMotorCommand.byteCount
    )
    XCTAssertEqual(MemoryLayout<NBProtectiveCommand>.stride, 64)
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    var states = schedule.modules.map { _ in RegionalModuleState() }
    for index in schedule.modules.indices
    where schedule.modules[index].clockClass == .emergency
      || schedule.modules[index].clockClass == .spinal
    {
      states[index].interruptSalience = 0.8
    }
    let invocations = [
      BrainModuleInvocation(
        timestamp: BrainTimestamp(microseconds: 750),
        moduleIdentifier: 26,
        clockClass: .emergency,
        reasons: .interrupt,
        interruptMask: .lossOfSupport
      ),
      BrainModuleInvocation(
        timestamp: BrainTimestamp(microseconds: 800),
        moduleIdentifier: 95,
        clockClass: .spinal,
        reasons: .interrupt,
        interruptMask: .pain
      ),
    ]
    let command = try ProtectiveMotorCommand.reference(
      timestamp: BrainTimestamp(microseconds: 1_000),
      brainGeneration: 7,
      environmentIdentifier: 42,
      schedule: schedule,
      invocations: invocations,
      regionalStates: states
    )

    XCTAssertEqual(
      command.flags,
      [
        .valid, .emergencyStop, .withdrawal, .posturalBrace, .autonomicArousal,
      ])
    XCTAssertEqual(command.interruptMask, [.pain, .lossOfSupport])
    XCTAssertEqual(command.withdrawalDrive, 0.8)
    XCTAssertEqual(command.posturalStiffness, 0.8)
    XCTAssertEqual(command.motorInhibition, 1)
    XCTAssertEqual(command.autonomicArousal, 0.8)
    XCTAssertEqual(command.environmentIdentifier, 42)
    XCTAssertEqual(command, try ProtectiveMotorCommand(validating: command.abiRecord))
    XCTAssertEqual(command.fingerprintHex, "f07cfab10c8f298a")
  }

  func testProtectiveCommandRejectsNoncanonicalAndIdleRecords() throws {
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let idle = try ProtectiveMotorCommand.reference(
      timestamp: BrainTimestamp(microseconds: 0),
      brainGeneration: 0,
      environmentIdentifier: 7,
      schedule: schedule,
      invocations: [],
      regionalStates: schedule.modules.map { _ in RegionalModuleState() }
    )
    XCTAssertEqual(idle.flags, .valid)
    XCTAssertEqual(idle.interruptMask, [])
    XCTAssertEqual(idle.withdrawalDrive, 0)
    XCTAssertEqual(idle.posturalStiffness, 0)
    XCTAssertEqual(idle.motorInhibition, 0)
    XCTAssertEqual(idle.autonomicArousal, 0)

    var invalid = idle.abiRecord
    invalid.withdrawal_drive = 1.5
    invalid.command_fingerprint = withUnsafePointer(to: &invalid) {
      nb_brain_abi_protective_command_fingerprint($0)
    }
    XCTAssertThrowsError(try ProtectiveMotorCommand(validating: invalid))

    invalid = idle.abiRecord
    invalid.flags |= UInt32(NB_PROTECTIVE_COMMAND_FLAG_WITHDRAWAL)
    invalid.command_fingerprint = withUnsafePointer(to: &invalid) {
      nb_brain_abi_protective_command_fingerprint($0)
    }
    XCTAssertThrowsError(try ProtectiveMotorCommand(validating: invalid))
  }
}

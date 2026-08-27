import NumiBrainABI
import XCTest

@testable import NumiBrainCore

final class ProtectiveMotorAdapterTests: XCTestCase {
  func testCompiledProfileAndReferenceMotorOutput() throws {
    XCTAssertEqual(nb_brain_abi_motor_channel_descriptor_size(), 32)
    XCTAssertEqual(nb_brain_abi_motor_output_header_size(), 64)
    XCTAssertEqual(MemoryLayout<NBMotorChannelDescriptor>.stride, 32)
    XCTAssertEqual(MemoryLayout<NBMotorOutputHeader>.stride, 64)

    let profile = try ProtectiveMotorProfile.runtimeFoundationFixture()
    XCTAssertEqual(profile.channels.count, 6)
    XCTAssertEqual(profile.fingerprintHex, "1457d16b0089b029")

    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    var states = schedule.modules.map { _ in RegionalModuleState() }
    for index in schedule.modules.indices
    where schedule.modules[index].clockClass == .emergency
      || schedule.modules[index].clockClass == .spinal
    {
      states[index].interruptSalience = 0.8
    }
    let command = try ProtectiveMotorCommand.reference(
      timestamp: BrainTimestamp(microseconds: 1_000),
      brainGeneration: 7,
      environmentIdentifier: 42,
      schedule: schedule,
      invocations: [
        BrainModuleInvocation(
          timestamp: BrainTimestamp(microseconds: 750),
          moduleIdentifier: 26,
          clockClass: .emergency,
          reasons: .interrupt,
          interruptMask: [.pain, .lossOfSupport]
        )
      ],
      regionalStates: states
    )
    let output = try ProtectiveMotorOutput.reference(command: command, profile: profile)

    XCTAssertEqual(output.flags, [.valid, .emergencyStop])
    XCTAssertEqual(output.timestamp, command.timestamp)
    XCTAssertEqual(output.brainGeneration, command.brainGeneration)
    XCTAssertEqual(output.profileFingerprint, profile.fingerprint)
    XCTAssertEqual(output.protectiveCommandFingerprint, command.fingerprint)
    XCTAssertEqual(output.environmentIdentifier, command.environmentIdentifier)
    XCTAssertEqual(output.motorInhibition, 1)
    XCTAssertEqual(output.autonomicArousal, 0.8)
    XCTAssertEqual(output.muscleExcitations, [0.82, 0.74, 0.73, 0.73, 0.90999997, 0.90999997])
    XCTAssertEqual(output.fingerprintHex, "f53f0a94ea61c403")
    XCTAssertEqual(
      output,
      try ProtectiveMotorOutput(
        validating: output.abiHeader,
        muscleExcitations: output.muscleExcitations,
        expectedProfile: profile,
        expectedCommand: command
      )
    )
  }

  func testMotorProfileAndOutputRejectInvalidRelations() throws {
    let duplicate = ProtectiveMuscleChannel(
      muscleIdentifier: 1,
      flags: .withdrawal,
      withdrawalGain: 1
    )
    XCTAssertThrowsError(try ProtectiveMotorProfile(channels: [duplicate, duplicate]))
    XCTAssertThrowsError(
      try ProtectiveMotorProfile(
        channels: [
          ProtectiveMuscleChannel(
            muscleIdentifier: 1,
            flags: .posturalBrace,
            withdrawalGain: 0.5,
            braceGain: 0.5
          )
        ]
      )
    )

    let profile = try ProtectiveMotorProfile.runtimeFoundationFixture()
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let command = try ProtectiveMotorCommand.reference(
      timestamp: BrainTimestamp(microseconds: 0),
      brainGeneration: 0,
      environmentIdentifier: 7,
      schedule: schedule,
      invocations: [],
      regionalStates: schedule.modules.map { _ in RegionalModuleState() }
    )
    let idle = try ProtectiveMotorOutput.reference(command: command, profile: profile)
    XCTAssertEqual(idle.flags, .valid)
    XCTAssertEqual(idle.muscleExcitations, [0.02, 0.02, 0.05, 0.05, 0.03, 0.03])

    var invalidHeader = idle.abiHeader
    invalidHeader.motor_inhibition = 1
    invalidHeader.output_fingerprint = idle.muscleExcitations.withUnsafeBufferPointer { buffer in
      withUnsafePointer(to: &invalidHeader) {
        nb_brain_abi_motor_output_fingerprint($0, buffer.baseAddress)
      }
    }
    XCTAssertThrowsError(
      try ProtectiveMotorOutput(
        validating: invalidHeader,
        muscleExcitations: idle.muscleExcitations
      )
    )

    var invalidExcitations = idle.muscleExcitations
    invalidExcitations[0] = 1.1
    invalidHeader = idle.abiHeader
    invalidHeader.output_fingerprint = invalidExcitations.withUnsafeBufferPointer { buffer in
      withUnsafePointer(to: &invalidHeader) {
        nb_brain_abi_motor_output_fingerprint($0, buffer.baseAddress)
      }
    }
    XCTAssertThrowsError(
      try ProtectiveMotorOutput(
        validating: invalidHeader,
        muscleExcitations: invalidExcitations
      )
    )
    XCTAssertThrowsError(
      try ProtectiveMotorOutput(
        validating: idle.abiHeader,
        muscleExcitations: Array(idle.muscleExcitations.dropLast())
      )
    )
  }
}

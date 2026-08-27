import Foundation
import NumiBrainABI

@frozen
public struct ProtectiveCommandFlags: OptionSet, Codable, Hashable, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let valid = Self(
    rawValue: UInt32(NB_PROTECTIVE_COMMAND_FLAG_VALID)
  )
  public static let emergencyStop = Self(
    rawValue: UInt32(NB_PROTECTIVE_COMMAND_FLAG_EMERGENCY_STOP)
  )
  public static let withdrawal = Self(
    rawValue: UInt32(NB_PROTECTIVE_COMMAND_FLAG_WITHDRAWAL)
  )
  public static let posturalBrace = Self(
    rawValue: UInt32(NB_PROTECTIVE_COMMAND_FLAG_POSTURAL_BRACE)
  )
  public static let autonomicArousal = Self(
    rawValue: UInt32(NB_PROTECTIVE_COMMAND_FLAG_AUTONOMIC_AROUSAL)
  )
}

/// Species-neutral protective output for the next physical candidate. A body
/// adapter owns the final mapping from these bounded drives to muscles or
/// actuators; this record never writes authoritative physical state directly.
@frozen
public struct ProtectiveMotorCommand: Codable, Equatable, Hashable, Sendable {
  public static let formatVersion = UInt32(NB_PROTECTIVE_COMMAND_VERSION)
  public static let byteCount = Int(NB_PROTECTIVE_COMMAND_BYTE_COUNT)

  public let flags: ProtectiveCommandFlags
  public let timestamp: BrainTimestamp
  public let brainGeneration: UInt64
  public let interruptMask: BrainInterruptMask
  public let withdrawalDrive: Float
  public let posturalStiffness: Float
  public let motorInhibition: Float
  public let autonomicArousal: Float
  public let environmentIdentifier: UInt32
  public let fingerprint: UInt64

  public init(validating record: NBProtectiveCommand) throws {
    var record = record
    let validation = withUnsafePointer(to: &record) {
      nb_brain_abi_validate_protective_command($0)
    }
    guard validation == UInt32(NB_PROTECTIVE_COMMAND_VALID.rawValue) else {
      throw BrainRuntimeError.transaction(
        "compiled protective command validation failed with code \(validation)"
      )
    }
    flags = ProtectiveCommandFlags(rawValue: record.flags)
    timestamp = BrainTimestamp(microseconds: record.timestamp_microseconds)
    brainGeneration = record.brain_generation
    interruptMask = BrainInterruptMask(rawValue: record.interrupt_mask)
    withdrawalDrive = record.withdrawal_drive
    posturalStiffness = record.postural_stiffness
    motorInhibition = record.motor_inhibition
    autonomicArousal = record.autonomic_arousal
    environmentIdentifier = record.environment_identifier
    fingerprint = record.command_fingerprint
  }

  public var abiRecord: NBProtectiveCommand {
    var record = NBProtectiveCommand()
    record.format_version = Self.formatVersion
    record.flags = flags.rawValue
    record.timestamp_microseconds = timestamp.rawValue
    record.brain_generation = brainGeneration
    record.interrupt_mask = interruptMask.rawValue
    record.withdrawal_drive = withdrawalDrive
    record.postural_stiffness = posturalStiffness
    record.motor_inhibition = motorInhibition
    record.autonomic_arousal = autonomicArousal
    record.environment_identifier = environmentIdentifier
    record.reserved = 0
    record.command_fingerprint = fingerprint
    return record
  }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }

  public static func reference(
    timestamp: BrainTimestamp,
    brainGeneration: UInt64,
    environmentIdentifier: UInt32,
    schedule: BrainModuleSchedule,
    invocations: [BrainModuleInvocation],
    regionalStates: [RegionalModuleState]
  ) throws -> Self {
    guard schedule.modules.count == regionalStates.count else {
      throw BrainRuntimeError.transaction(
        "protective command regional state does not match the schedule"
      )
    }
    var interruptMask: BrainInterruptMask = []
    for invocation in invocations where invocation.reasons.contains(.interrupt) {
      interruptMask.formUnion(invocation.interruptMask)
    }
    var regionalSalience: Float = 0
    for (module, state) in zip(schedule.modules, regionalStates)
    where module.clockClass == .emergency || module.clockClass == .spinal {
      regionalSalience = max(regionalSalience, state.interruptSalience)
    }
    regionalSalience = min(max(regionalSalience, 0), 1)

    let withdrawalCauses: BrainInterruptMask = [
      .pain, .damagingContact, .jointLimit, .muscleOverload,
    ]
    let braceCauses: BrainInterruptMask = [.lossOfSupport, .impact]
    let stopCauses: BrainInterruptMask = [
      .pain, .damagingContact, .lossOfSupport, .impact,
      .physiologicalCritical, .jointLimit, .muscleOverload, .rescue,
    ]
    let withdrawal = !interruptMask.intersection(withdrawalCauses).isEmpty
    let brace = !interruptMask.intersection(braceCauses).isEmpty
    let emergencyStop = !interruptMask.intersection(stopCauses).isEmpty
    let arousal = !interruptMask.isEmpty

    var flags: ProtectiveCommandFlags = [.valid]
    if emergencyStop { flags.insert(.emergencyStop) }
    if withdrawal { flags.insert(.withdrawal) }
    if brace { flags.insert(.posturalBrace) }
    if arousal { flags.insert(.autonomicArousal) }
    var record = NBProtectiveCommand()
    record.format_version = Self.formatVersion
    record.flags = flags.rawValue
    record.timestamp_microseconds = timestamp.rawValue
    record.brain_generation = brainGeneration
    record.interrupt_mask = interruptMask.rawValue
    record.withdrawal_drive = withdrawal ? max(0.5, regionalSalience) : 0
    record.postural_stiffness = brace ? max(0.75, regionalSalience) : 0
    record.motor_inhibition = emergencyStop ? 1 : 0
    record.autonomic_arousal = arousal ? max(0.5, regionalSalience) : 0
    record.environment_identifier = environmentIdentifier
    record.reserved = 0
    record.command_fingerprint = withUnsafePointer(to: &record) {
      nb_brain_abi_protective_command_fingerprint($0)
    }
    return try Self(validating: record)
  }
}

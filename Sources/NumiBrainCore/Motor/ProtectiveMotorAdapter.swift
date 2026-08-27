import Foundation
import NumiBrainABI

@frozen
public struct ProtectiveMuscleChannelFlags: OptionSet, Codable, Hashable, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let valid = Self(rawValue: UInt32(NB_MOTOR_CHANNEL_FLAG_VALID))
  public static let withdrawal = Self(rawValue: UInt32(NB_MOTOR_CHANNEL_FLAG_WITHDRAWAL))
  public static let posturalBrace = Self(
    rawValue: UInt32(NB_MOTOR_CHANNEL_FLAG_POSTURAL_BRACE)
  )
}

@frozen
public struct ProtectiveMuscleChannel: Codable, Equatable, Hashable, Sendable {
  public let muscleIdentifier: UInt32
  public let flags: ProtectiveMuscleChannelFlags
  public let restingExcitation: Float
  public let withdrawalGain: Float
  public let braceGain: Float
  public let maximumExcitation: Float

  public init(
    muscleIdentifier: UInt32,
    flags: ProtectiveMuscleChannelFlags,
    restingExcitation: Float = 0,
    withdrawalGain: Float = 0,
    braceGain: Float = 0,
    maximumExcitation: Float = 1
  ) {
    self.muscleIdentifier = muscleIdentifier
    self.flags = flags.union(.valid)
    self.restingExcitation = restingExcitation
    self.withdrawalGain = withdrawalGain
    self.braceGain = braceGain
    self.maximumExcitation = maximumExcitation
  }

  public var abiRecord: NBMotorChannelDescriptor {
    var record = NBMotorChannelDescriptor()
    record.muscle_id = muscleIdentifier
    record.flags = flags.rawValue
    record.resting_excitation = restingExcitation
    record.withdrawal_gain = withdrawalGain
    record.brace_gain = braceGain
    record.maximum_excitation = maximumExcitation
    record.reserved0 = 0
    record.reserved1 = 0
    return record
  }
}

/// Immutable species/body mapping used by both the CPU oracle and Metal. The
/// current command is global, so this first profile can choose per-muscle gains
/// but cannot yet localize withdrawal to one receptor or body side.
@frozen
public struct ProtectiveMotorProfile: Codable, Equatable, Hashable, Sendable {
  public static let formatVersion = UInt32(NB_MOTOR_PROFILE_VERSION)
  public static let channelByteCount = Int(NB_MOTOR_CHANNEL_DESCRIPTOR_BYTE_COUNT)

  public let channels: [ProtectiveMuscleChannel]
  public let fingerprint: UInt64

  public init(channels: [ProtectiveMuscleChannel]) throws {
    guard channels.count <= Int(UInt32.max) else {
      throw BrainRuntimeError.transaction("protective motor profile exceeds UInt32 capacity")
    }
    let records = channels.map(\.abiRecord)
    let validation = records.withUnsafeBufferPointer { buffer in
      nb_brain_abi_validate_motor_profile(buffer.baseAddress, UInt32(buffer.count))
    }
    guard validation == UInt32(NB_MOTOR_PROFILE_VALID.rawValue) else {
      throw BrainRuntimeError.transaction(
        "compiled protective motor profile validation failed with code \(validation)"
      )
    }
    let fingerprint = records.withUnsafeBufferPointer { buffer in
      nb_brain_abi_motor_profile_fingerprint(buffer.baseAddress, UInt32(buffer.count))
    }
    guard fingerprint != 0 else {
      throw BrainRuntimeError.transaction("protective motor profile has no identity")
    }
    self.channels = channels
    self.fingerprint = fingerprint
  }

  public var abiRecords: [NBMotorChannelDescriptor] { channels.map(\.abiRecord) }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }

  /// Synthetic bilateral channels used only by the executable foundation.
  /// The identifiers and gains are deterministic fixtures, not anatomy.
  public static func runtimeFoundationFixture(
    muscleIdentifiers: [UInt32] = [100, 101, 102, 103, 104, 105]
  ) throws -> Self {
    guard muscleIdentifiers.count >= 6 else {
      throw BrainRuntimeError.transaction(
        "runtime-foundation protective profile requires at least six muscle identifiers"
      )
    }
    var channels = [
      ProtectiveMuscleChannel(
        muscleIdentifier: muscleIdentifiers[0],
        flags: .withdrawal,
        restingExcitation: 0.02,
        withdrawalGain: 1
      ),
      ProtectiveMuscleChannel(
        muscleIdentifier: muscleIdentifiers[1],
        flags: .withdrawal,
        restingExcitation: 0.02,
        withdrawalGain: 0.9
      ),
      ProtectiveMuscleChannel(
        muscleIdentifier: muscleIdentifiers[2],
        flags: .posturalBrace,
        restingExcitation: 0.05,
        braceGain: 0.85
      ),
      ProtectiveMuscleChannel(
        muscleIdentifier: muscleIdentifiers[3],
        flags: .posturalBrace,
        restingExcitation: 0.05,
        braceGain: 0.85
      ),
      ProtectiveMuscleChannel(
        muscleIdentifier: muscleIdentifiers[4],
        flags: [.withdrawal, .posturalBrace],
        restingExcitation: 0.03,
        withdrawalGain: 0.4,
        braceGain: 0.7
      ),
      ProtectiveMuscleChannel(
        muscleIdentifier: muscleIdentifiers[5],
        flags: [.withdrawal, .posturalBrace],
        restingExcitation: 0.03,
        withdrawalGain: 0.4,
        braceGain: 0.7
      ),
    ]
    channels.append(
      contentsOf: muscleIdentifiers.dropFirst(6).map {
        ProtectiveMuscleChannel(muscleIdentifier: $0, flags: [])
      }
    )
    return try Self(channels: channels)
  }
}

@frozen
public struct ProtectiveMotorOutputFlags: OptionSet, Codable, Hashable, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let valid = Self(rawValue: UInt32(NB_MOTOR_OUTPUT_FLAG_VALID))
  public static let emergencyStop = Self(
    rawValue: UInt32(NB_MOTOR_OUTPUT_FLAG_EMERGENCY_STOP)
  )
  public static let localizedSourceInhibition = Self(
    rawValue: UInt32(NB_MOTOR_OUTPUT_FLAG_LOCALIZED_SOURCE_INHIBITION)
  )
}

/// Bounded muscle-excitation residual plus the inhibition and autonomic values
/// that a NumanX adapter must combine with the rest of the motor hierarchy.
@frozen
public struct ProtectiveMotorOutput: Codable, Equatable, Hashable, Sendable {
  public static let formatVersion = UInt32(NB_MOTOR_OUTPUT_VERSION)
  public static let headerByteCount = Int(NB_MOTOR_OUTPUT_HEADER_BYTE_COUNT)

  public let flags: ProtectiveMotorOutputFlags
  public let timestamp: BrainTimestamp
  public let brainGeneration: UInt64
  public let profileFingerprint: UInt64
  public let protectiveCommandFingerprint: UInt64
  public let environmentIdentifier: UInt32
  public let motorInhibition: Float
  public let autonomicArousal: Float
  public let muscleExcitations: [Float]
  public let fingerprint: UInt64

  public init(
    validating header: NBMotorOutputHeader,
    muscleExcitations: [Float],
    expectedProfile: ProtectiveMotorProfile? = nil,
    expectedCommand: ProtectiveMotorCommand? = nil
  ) throws {
    var header = header
    guard muscleExcitations.count <= Int(UInt32.max),
      header.muscle_count == UInt32(muscleExcitations.count)
    else {
      throw BrainRuntimeError.transaction("protective motor output count drift")
    }
    let validation = muscleExcitations.withUnsafeBufferPointer { excitations in
      withUnsafePointer(to: &header) {
        nb_brain_abi_validate_motor_output($0, excitations.baseAddress)
      }
    }
    guard validation == UInt32(NB_MOTOR_OUTPUT_VALID.rawValue) else {
      throw BrainRuntimeError.transaction(
        "compiled protective motor output validation failed with code \(validation)"
      )
    }
    if let expectedProfile {
      guard header.profile_fingerprint == expectedProfile.fingerprint,
        muscleExcitations.count == expectedProfile.channels.count
      else {
        throw BrainRuntimeError.transaction("protective motor output profile drift")
      }
    }
    if let expectedCommand {
      guard header.protective_command_fingerprint == expectedCommand.fingerprint,
        header.timestamp_microseconds == expectedCommand.timestamp.rawValue,
        header.brain_generation == expectedCommand.brainGeneration,
        header.environment_identifier == expectedCommand.environmentIdentifier,
        header.motor_inhibition == expectedCommand.motorInhibition,
        header.autonomic_arousal == expectedCommand.autonomicArousal
      else {
        throw BrainRuntimeError.transaction("protective motor output command drift")
      }
    }
    flags = ProtectiveMotorOutputFlags(rawValue: header.flags)
    timestamp = BrainTimestamp(microseconds: header.timestamp_microseconds)
    brainGeneration = header.brain_generation
    profileFingerprint = header.profile_fingerprint
    protectiveCommandFingerprint = header.protective_command_fingerprint
    environmentIdentifier = header.environment_identifier
    motorInhibition = header.motor_inhibition
    autonomicArousal = header.autonomic_arousal
    self.muscleExcitations = muscleExcitations
    fingerprint = header.output_fingerprint
  }

  public var abiHeader: NBMotorOutputHeader {
    var header = NBMotorOutputHeader()
    header.format_version = Self.formatVersion
    header.flags = flags.rawValue
    header.timestamp_microseconds = timestamp.rawValue
    header.brain_generation = brainGeneration
    header.profile_fingerprint = profileFingerprint
    header.protective_command_fingerprint = protectiveCommandFingerprint
    header.muscle_count = UInt32(muscleExcitations.count)
    header.environment_identifier = environmentIdentifier
    header.motor_inhibition = motorInhibition
    header.autonomic_arousal = autonomicArousal
    header.output_fingerprint = fingerprint
    return header
  }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }

  public static func reference(
    command: ProtectiveMotorCommand,
    profile: ProtectiveMotorProfile,
    sourceInhibitedMuscleIdentifiers: Set<UInt32> = []
  ) throws -> Self {
    guard
      sourceInhibitedMuscleIdentifiers.isSubset(
        of: Set(profile.channels.map(\.muscleIdentifier))
      )
    else {
      throw BrainRuntimeError.transaction(
        "protective source-inhibition identifiers are absent from the motor profile"
      )
    }
    let excitations = profile.channels.map { channel in
      guard !sourceInhibitedMuscleIdentifiers.contains(channel.muscleIdentifier) else {
        return Float.zero
      }
      let withdrawalExcitation = fmaf(
        command.withdrawalDrive,
        channel.withdrawalGain,
        channel.restingExcitation
      )
      let protectiveExcitation = fmaf(
        command.posturalStiffness,
        channel.braceGain,
        withdrawalExcitation
      )
      return min(
        channel.maximumExcitation,
        max(0, protectiveExcitation)
      )
    }
    var header = NBMotorOutputHeader()
    header.format_version = Self.formatVersion
    header.flags = UInt32(NB_MOTOR_OUTPUT_FLAG_VALID)
    if command.flags.contains(.emergencyStop) {
      header.flags |= UInt32(NB_MOTOR_OUTPUT_FLAG_EMERGENCY_STOP)
    }
    if !sourceInhibitedMuscleIdentifiers.isEmpty {
      header.flags |= UInt32(NB_MOTOR_OUTPUT_FLAG_LOCALIZED_SOURCE_INHIBITION)
    }
    header.timestamp_microseconds = command.timestamp.rawValue
    header.brain_generation = command.brainGeneration
    header.profile_fingerprint = profile.fingerprint
    header.protective_command_fingerprint = command.fingerprint
    header.muscle_count = UInt32(excitations.count)
    header.environment_identifier = command.environmentIdentifier
    header.motor_inhibition = command.motorInhibition
    header.autonomic_arousal = command.autonomicArousal
    header.output_fingerprint = excitations.withUnsafeBufferPointer { buffer in
      withUnsafePointer(to: &header) {
        nb_brain_abi_motor_output_fingerprint($0, buffer.baseAddress)
      }
    }
    return try Self(
      validating: header,
      muscleExcitations: excitations,
      expectedProfile: profile,
      expectedCommand: command
    )
  }
}

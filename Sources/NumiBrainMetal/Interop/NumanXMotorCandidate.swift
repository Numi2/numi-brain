import Foundation
import NumiBrainABI
import NumiBrainCore

/// Transaction-local NumanX handoff for the protective motor buffers used by
/// one physical candidate. GPU addresses are valid only while the owning
/// `MetalTissueRuntime` and its residency set remain alive; this value must not
/// be serialized as replay identity.
@frozen
public struct NumanXMotorCandidate: Equatable, Hashable, Sendable {
  public static let formatVersion = UInt32(NB_NUMANX_MOTOR_CANDIDATE_VERSION)
  public static let byteCount = Int(NB_NUMANX_MOTOR_CANDIDATE_BYTE_COUNT)

  public let transactionFingerprint: UInt64
  public let substepFingerprint: UInt64
  public let acceptedBrainTimestamp: BrainTimestamp
  public let brainGeneration: UInt64
  public let motorProfileFingerprint: UInt64
  public let motorOutputHeaderGPUAddress: UInt64
  public let muscleExcitationGPUAddress: UInt64
  public let randomCounterGeneration: UInt64
  public let motorOutputHeaderByteCount: UInt32
  public let muscleExcitationByteCount: UInt32
  public let muscleCount: UInt32
  public let environmentIdentifier: UInt32
  public let fingerprint: UInt64

  public init(
    transaction: BrainJointTransactionToken,
    fastSystems: MetalTissueRuntime.FastSystemResult
  ) throws {
    let output = fastSystems.protectiveMotorOutput
    guard output.headerByteCount <= Int(UInt32.max),
      output.muscleExcitationByteCount <= Int(UInt32.max),
      output.muscleCount <= Int(UInt32.max)
    else {
      throw TissueError.transaction("NumanX protective motor view exceeds compiled capacity")
    }
    var root = transaction.abiRecord
    var substep = fastSystems.substep.abiRecord
    var record = NBNumanXMotorCandidate()
    record.format_version = Self.formatVersion
    record.flags = UInt32(NB_NUMANX_MOTOR_CANDIDATE_FLAG_VALID)
    record.transaction_fingerprint = transaction.fingerprint
    record.substep_fingerprint = fastSystems.substep.fingerprint
    record.accepted_brain_timestamp_microseconds = output.timestamp.rawValue
    record.brain_generation = output.brainGeneration
    record.motor_profile_fingerprint = output.profileFingerprint
    record.motor_output_header_gpu_address = output.headerGPUAddress
    record.muscle_excitation_gpu_address = output.muscleExcitationGPUAddress
    record.random_counter_generation = fastSystems.substep.randomCounterGeneration
    record.motor_output_header_byte_count = UInt32(output.headerByteCount)
    record.muscle_excitation_byte_count = UInt32(output.muscleExcitationByteCount)
    record.muscle_count = UInt32(output.muscleCount)
    record.environment_identifier = transaction.environmentIdentifier
    record.candidate_fingerprint = withUnsafePointer(to: &record) {
      nb_brain_abi_numanx_motor_candidate_fingerprint($0)
    }
    let validation = withUnsafePointer(to: &root) { root in
      withUnsafePointer(to: &substep) { substep in
        withUnsafePointer(to: &record) {
          nb_brain_abi_validate_numanx_motor_candidate(root, substep, $0)
        }
      }
    }
    guard validation == UInt32(NB_NUMANX_MOTOR_CANDIDATE_VALID.rawValue) else {
      throw TissueError.transaction(
        "compiled NumanX motor candidate validation failed with code \(validation)"
      )
    }
    self.init(unchecked: record)
  }

  public init(
    validating record: NBNumanXMotorCandidate,
    transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken
  ) throws {
    var root = transaction.abiRecord
    var substepRecord = substep.abiRecord
    var record = record
    let validation = withUnsafePointer(to: &root) { root in
      withUnsafePointer(to: &substepRecord) { substep in
        withUnsafePointer(to: &record) {
          nb_brain_abi_validate_numanx_motor_candidate(root, substep, $0)
        }
      }
    }
    guard validation == UInt32(NB_NUMANX_MOTOR_CANDIDATE_VALID.rawValue) else {
      throw TissueError.transaction(
        "compiled NumanX motor candidate validation failed with code \(validation)"
      )
    }
    self.init(unchecked: record)
  }

  private init(unchecked record: NBNumanXMotorCandidate) {
    transactionFingerprint = record.transaction_fingerprint
    substepFingerprint = record.substep_fingerprint
    acceptedBrainTimestamp = BrainTimestamp(
      microseconds: record.accepted_brain_timestamp_microseconds
    )
    brainGeneration = record.brain_generation
    motorProfileFingerprint = record.motor_profile_fingerprint
    motorOutputHeaderGPUAddress = record.motor_output_header_gpu_address
    muscleExcitationGPUAddress = record.muscle_excitation_gpu_address
    randomCounterGeneration = record.random_counter_generation
    motorOutputHeaderByteCount = record.motor_output_header_byte_count
    muscleExcitationByteCount = record.muscle_excitation_byte_count
    muscleCount = record.muscle_count
    environmentIdentifier = record.environment_identifier
    fingerprint = record.candidate_fingerprint
  }

  public var abiRecord: NBNumanXMotorCandidate {
    var record = NBNumanXMotorCandidate()
    record.format_version = Self.formatVersion
    record.flags = UInt32(NB_NUMANX_MOTOR_CANDIDATE_FLAG_VALID)
    record.transaction_fingerprint = transactionFingerprint
    record.substep_fingerprint = substepFingerprint
    record.accepted_brain_timestamp_microseconds = acceptedBrainTimestamp.rawValue
    record.brain_generation = brainGeneration
    record.motor_profile_fingerprint = motorProfileFingerprint
    record.motor_output_header_gpu_address = motorOutputHeaderGPUAddress
    record.muscle_excitation_gpu_address = muscleExcitationGPUAddress
    record.random_counter_generation = randomCounterGeneration
    record.motor_output_header_byte_count = motorOutputHeaderByteCount
    record.muscle_excitation_byte_count = muscleExcitationByteCount
    record.muscle_count = muscleCount
    record.environment_identifier = environmentIdentifier
    record.candidate_fingerprint = fingerprint
    return record
  }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }
}

import Foundation
import NumiBrainABI

/// The interpretation of physical timestamp words at a NumiBrain/NumanX
/// transaction boundary. Legacy v1 records are always microsecond ticks;
/// explicit-clock v2 records carry this domain together with their quantum.
@frozen
public enum BrainPhysicalClockDomain: UInt32, Codable, CaseIterable, Sendable {
  case legacyMicroseconds = 1
  case exactNanoseconds = 2
}

/// An explicit physical tick clock. V1 is the sole legacy-microsecond lane;
/// v2 is the sole exact-nanosecond lane and therefore requires a 1 ns quantum.
@frozen
public struct BrainPhysicalClock: Equatable, Hashable, Sendable {
  public let domain: BrainPhysicalClockDomain
  public let quantumNanoseconds: UInt32

  public static let legacyMicroseconds = BrainPhysicalClock(
    uncheckedDomain: .legacyMicroseconds,
    quantumNanoseconds: UInt32(NB_LEGACY_MICROSECOND_CLOCK_QUANTUM_NANOSECONDS)
  )

  public static let exactNanoseconds = BrainPhysicalClock(
    uncheckedDomain: .exactNanoseconds,
    quantumNanoseconds: UInt32(NB_EXACT_NANOSECOND_CLOCK_QUANTUM_NANOSECONDS)
  )

  public init(
    domain: BrainPhysicalClockDomain,
    quantumNanoseconds: UInt32
  ) throws {
    let requiredQuantum: UInt32
    switch domain {
    case .legacyMicroseconds:
      requiredQuantum = UInt32(
        NB_LEGACY_MICROSECOND_CLOCK_QUANTUM_NANOSECONDS
      )
    case .exactNanoseconds:
      requiredQuantum = UInt32(
        NB_EXACT_NANOSECOND_CLOCK_QUANTUM_NANOSECONDS
      )
    }
    guard quantumNanoseconds == requiredQuantum else {
      throw BrainRuntimeError.transaction(
        "physical clock quantum does not match its clock domain"
      )
    }
    self.domain = domain
    self.quantumNanoseconds = quantumNanoseconds
  }

  private init(
    uncheckedDomain domain: BrainPhysicalClockDomain,
    quantumNanoseconds: UInt32
  ) {
    self.domain = domain
    self.quantumNanoseconds = quantumNanoseconds
  }
}

/// Exact physical time expressed as neutral 1 ns ticks. This is intentionally
/// distinct from the legacy microsecond `BrainTimestamp` type.
@frozen
public struct BrainNanosecondTimestamp: Codable, Equatable, Hashable, Sendable {
  public let ticks: UInt64

  public init(ticks: UInt64) {
    self.ticks = ticks
  }

  public init(exactNanoseconds: UInt64) {
    ticks = exactNanoseconds
  }

  public var nanoseconds: UInt64 { ticks }
}

/// Exact physical duration expressed as neutral 1 ns ticks.
@frozen
public struct BrainNanosecondDuration: Codable, Equatable, Hashable, Sendable {
  public let ticks: UInt64

  public init(ticks: UInt64) {
    self.ticks = ticks
  }

  public init(exactNanoseconds: UInt64) {
    ticks = exactNanoseconds
  }

  public var nanoseconds: UInt64 { ticks }
}

private func brainPhysicalClock(
  abiDomain: UInt32,
  quantumNanoseconds: UInt64
) throws -> BrainPhysicalClock {
  guard let domain = BrainPhysicalClockDomain(rawValue: abiDomain),
    let quantum = UInt32(exactly: quantumNanoseconds)
  else {
    throw BrainRuntimeError.transaction("compiled physical clock is invalid")
  }
  return try BrainPhysicalClock(
    domain: domain,
    quantumNanoseconds: quantum
  )
}

private func requireValidV2(_ validation: UInt32, context: String) throws {
  guard validation == UInt32(NB_JOINT_TRANSACTION_VALID.rawValue) else {
    throw BrainRuntimeError.transaction(
      "compiled \(context) validation failed with code \(validation)"
    )
  }
}

/// Explicit-clock root identity. This is additive to the immutable v1 root;
/// it does not reinterpret a v1 flag or reserved word.
@frozen
public struct BrainJointTransactionTokenV2: Equatable, Hashable, Sendable {
  public static let formatVersion = UInt32(NB_JOINT_TRANSACTION_V2_VERSION)
  public static let byteCount = Int(NB_JOINT_TRANSACTION_TOKEN_V2_BYTE_COUNT)

  public let environmentIdentifier: UInt32
  public let episodeIdentifier: UInt64
  public let controlStepIdentifier: UInt64
  public let parameterVersionFingerprint: UInt64
  public let baseBrainGeneration: UInt64
  public let basePhysicsGeneration: UInt64
  public let committedTimestamp: BrainNanosecondTimestamp
  public let targetTimestamp: BrainNanosecondTimestamp
  public let shadowGeneration: UInt64
  public let randomCounterGeneration: UInt64
  public let fingerprint: UInt64

  public var clock: BrainPhysicalClock { .exactNanoseconds }
  public var clockDomain: BrainPhysicalClockDomain { clock.domain }
  public var clockQuantumNanoseconds: UInt32 { clock.quantumNanoseconds }
  public var committedTimestampTicks: UInt64 { committedTimestamp.ticks }
  public var targetTimestampTicks: UInt64 { targetTimestamp.ticks }

  public init(
    environmentIdentifier: UInt32,
    episodeIdentifier: UInt64,
    controlStepIdentifier: UInt64,
    parameterVersionFingerprint: UInt64,
    baseBrainGeneration: UInt64,
    basePhysicsGeneration: UInt64,
    committedTimestamp: BrainNanosecondTimestamp,
    targetTimestamp: BrainNanosecondTimestamp,
    randomCounterGeneration: UInt64
  ) throws {
    let (shadowGeneration, overflow) = baseBrainGeneration.addingReportingOverflow(1)
    guard !overflow else {
      throw BrainRuntimeError.transaction("brain shadow generation overflows UInt64")
    }
    var record = NBJointTransactionTokenV2()
    record.format_version = Self.formatVersion
    record.environment_identifier = environmentIdentifier
    record.episode_identifier = episodeIdentifier
    record.control_step_identifier = controlStepIdentifier
    record.parameter_version_fingerprint = parameterVersionFingerprint
    record.base_brain_generation = baseBrainGeneration
    record.base_physics_generation = basePhysicsGeneration
    record.committed_timestamp_ticks = committedTimestamp.ticks
    record.target_timestamp_ticks = targetTimestamp.ticks
    record.shadow_generation = shadowGeneration
    record.random_counter_generation = randomCounterGeneration
    record.clock_domain = BrainPhysicalClock.exactNanoseconds.domain.rawValue
    record.clock_quantum_nanoseconds =
      BrainPhysicalClock.exactNanoseconds.quantumNanoseconds
    record.transaction_fingerprint = withUnsafePointer(to: &record) {
      nb_brain_abi_joint_transaction_v2_fingerprint($0)
    }
    let validation = withUnsafePointer(to: &record) {
      nb_brain_abi_validate_joint_transaction_v2($0)
    }
    try requireValidV2(validation, context: "v2 joint root")
    self.environmentIdentifier = environmentIdentifier
    self.episodeIdentifier = episodeIdentifier
    self.controlStepIdentifier = controlStepIdentifier
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.baseBrainGeneration = baseBrainGeneration
    self.basePhysicsGeneration = basePhysicsGeneration
    self.committedTimestamp = committedTimestamp
    self.targetTimestamp = targetTimestamp
    self.shadowGeneration = shadowGeneration
    self.randomCounterGeneration = randomCounterGeneration
    fingerprint = record.transaction_fingerprint
  }

  public init(
    environmentIdentifier: UInt32,
    episodeIdentifier: UInt64,
    controlStepIdentifier: UInt64,
    parameterVersionFingerprint: UInt64,
    baseBrainGeneration: UInt64,
    basePhysicsGeneration: UInt64,
    committedTimestampTicks: UInt64,
    targetTimestampTicks: UInt64,
    randomCounterGeneration: UInt64
  ) throws {
    try self.init(
      environmentIdentifier: environmentIdentifier,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: controlStepIdentifier,
      parameterVersionFingerprint: parameterVersionFingerprint,
      baseBrainGeneration: baseBrainGeneration,
      basePhysicsGeneration: basePhysicsGeneration,
      committedTimestamp: BrainNanosecondTimestamp(ticks: committedTimestampTicks),
      targetTimestamp: BrainNanosecondTimestamp(ticks: targetTimestampTicks),
      randomCounterGeneration: randomCounterGeneration
    )
  }

  public static func exactNanoseconds(
    environmentIdentifier: UInt32,
    episodeIdentifier: UInt64,
    controlStepIdentifier: UInt64,
    parameterVersionFingerprint: UInt64,
    baseBrainGeneration: UInt64,
    basePhysicsGeneration: UInt64,
    committedTimestampNanoseconds: UInt64,
    targetTimestampNanoseconds: UInt64,
    randomCounterGeneration: UInt64
  ) throws -> Self {
    try Self(
      environmentIdentifier: environmentIdentifier,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: controlStepIdentifier,
      parameterVersionFingerprint: parameterVersionFingerprint,
      baseBrainGeneration: baseBrainGeneration,
      basePhysicsGeneration: basePhysicsGeneration,
      committedTimestamp: BrainNanosecondTimestamp(
        exactNanoseconds: committedTimestampNanoseconds
      ),
      targetTimestamp: BrainNanosecondTimestamp(
        exactNanoseconds: targetTimestampNanoseconds
      ),
      randomCounterGeneration: randomCounterGeneration
    )
  }

  public init(validating record: NBJointTransactionTokenV2) throws {
    var record = record
    let validation = withUnsafePointer(to: &record) {
      nb_brain_abi_validate_joint_transaction_v2($0)
    }
    try requireValidV2(validation, context: "v2 joint root")
    let clock = try brainPhysicalClock(
      abiDomain: record.clock_domain,
      quantumNanoseconds: UInt64(record.clock_quantum_nanoseconds)
    )
    guard clock == .exactNanoseconds else {
      throw BrainRuntimeError.transaction(
        "v2 joint root requires the exact 1 ns clock"
      )
    }
    environmentIdentifier = record.environment_identifier
    episodeIdentifier = record.episode_identifier
    controlStepIdentifier = record.control_step_identifier
    parameterVersionFingerprint = record.parameter_version_fingerprint
    baseBrainGeneration = record.base_brain_generation
    basePhysicsGeneration = record.base_physics_generation
    committedTimestamp = BrainNanosecondTimestamp(
      ticks: record.committed_timestamp_ticks
    )
    targetTimestamp = BrainNanosecondTimestamp(
      ticks: record.target_timestamp_ticks
    )
    shadowGeneration = record.shadow_generation
    randomCounterGeneration = record.random_counter_generation
    fingerprint = record.transaction_fingerprint
  }

  public var abiRecord: NBJointTransactionTokenV2 {
    var record = NBJointTransactionTokenV2()
    record.format_version = Self.formatVersion
    record.environment_identifier = environmentIdentifier
    record.episode_identifier = episodeIdentifier
    record.control_step_identifier = controlStepIdentifier
    record.parameter_version_fingerprint = parameterVersionFingerprint
    record.base_brain_generation = baseBrainGeneration
    record.base_physics_generation = basePhysicsGeneration
    record.committed_timestamp_ticks = committedTimestamp.ticks
    record.target_timestamp_ticks = targetTimestamp.ticks
    record.shadow_generation = shadowGeneration
    record.random_counter_generation = randomCounterGeneration
    record.clock_domain = clock.domain.rawValue
    record.clock_quantum_nanoseconds = clock.quantumNanoseconds
    record.transaction_fingerprint = fingerprint
    return record
  }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }
}

/// Explicit-clock candidate nested physical-substep identity.
@frozen
public struct BrainJointSubstepTokenV2: Equatable, Hashable, Sendable {
  public static let byteCount = Int(NB_JOINT_SUBSTEP_TOKEN_V2_BYTE_COUNT)

  public let transactionFingerprint: UInt64
  public let substepIndex: UInt32
  public let attemptIndex: UInt32
  public let startTimestamp: BrainNanosecondTimestamp
  public let duration: BrainNanosecondDuration
  public let candidateTimestamp: BrainNanosecondTimestamp
  public let shadowGeneration: UInt64
  public let randomCounterGeneration: UInt64
  public let fingerprint: UInt64

  public var clock: BrainPhysicalClock { .exactNanoseconds }
  public var clockDomain: BrainPhysicalClockDomain { clock.domain }
  public var clockQuantumNanoseconds: UInt32 { clock.quantumNanoseconds }
  public var startTimestampTicks: UInt64 { startTimestamp.ticks }
  public var durationTicks: UInt64 { duration.ticks }
  public var candidateTimestampTicks: UInt64 { candidateTimestamp.ticks }

  public init(
    transaction: BrainJointTransactionTokenV2,
    substepIndex: UInt32,
    attemptIndex: UInt32,
    startTimestamp: BrainNanosecondTimestamp,
    duration: BrainNanosecondDuration
  ) throws {
    let (candidateTicks, overflow) =
      startTimestamp.ticks.addingReportingOverflow(duration.ticks)
    guard !overflow else {
      throw BrainRuntimeError.transaction("candidate substep time overflows UInt64")
    }
    let candidateTimestamp = BrainNanosecondTimestamp(ticks: candidateTicks)
    var root = transaction.abiRecord
    var record = NBJointSubstepTokenV2()
    record.transaction_fingerprint = transaction.fingerprint
    record.substep_index = substepIndex
    record.attempt_index = attemptIndex
    record.start_timestamp_ticks = startTimestamp.ticks
    record.duration_ticks = duration.ticks
    record.candidate_timestamp_ticks = candidateTicks
    record.shadow_generation = transaction.shadowGeneration
    record.random_counter_generation = transaction.randomCounterGeneration
    record.clock_domain = transaction.clock.domain.rawValue
    record.clock_quantum_nanoseconds = transaction.clock.quantumNanoseconds
    record.substep_fingerprint = withUnsafePointer(to: &record) {
      nb_brain_abi_joint_substep_v2_fingerprint($0)
    }
    let validation = withUnsafePointer(to: &root) { root in
      withUnsafePointer(to: &record) { substep in
        nb_brain_abi_validate_joint_substep_v2(root, substep)
      }
    }
    try requireValidV2(validation, context: "v2 joint substep")
    transactionFingerprint = transaction.fingerprint
    self.substepIndex = substepIndex
    self.attemptIndex = attemptIndex
    self.startTimestamp = startTimestamp
    self.duration = duration
    self.candidateTimestamp = candidateTimestamp
    shadowGeneration = transaction.shadowGeneration
    randomCounterGeneration = transaction.randomCounterGeneration
    fingerprint = record.substep_fingerprint
  }

  public init(
    transaction: BrainJointTransactionTokenV2,
    substepIndex: UInt32,
    attemptIndex: UInt32,
    startTimestampTicks: UInt64,
    durationTicks: UInt64
  ) throws {
    try self.init(
      transaction: transaction,
      substepIndex: substepIndex,
      attemptIndex: attemptIndex,
      startTimestamp: BrainNanosecondTimestamp(ticks: startTimestampTicks),
      duration: BrainNanosecondDuration(ticks: durationTicks)
    )
  }

  public static func exactNanoseconds(
    transaction: BrainJointTransactionTokenV2,
    substepIndex: UInt32,
    attemptIndex: UInt32,
    startTimestampNanoseconds: UInt64,
    durationNanoseconds: UInt64
  ) throws -> Self {
    guard transaction.clock == .exactNanoseconds else {
      throw BrainRuntimeError.transaction(
        "exact-nanosecond substep requires a one-nanosecond root clock"
      )
    }
    return try Self(
      transaction: transaction,
      substepIndex: substepIndex,
      attemptIndex: attemptIndex,
      startTimestamp: BrainNanosecondTimestamp(
        exactNanoseconds: startTimestampNanoseconds
      ),
      duration: BrainNanosecondDuration(exactNanoseconds: durationNanoseconds)
    )
  }

  public init(
    validating record: NBJointSubstepTokenV2,
    transaction: BrainJointTransactionTokenV2
  ) throws {
    var root = transaction.abiRecord
    var record = record
    let validation = withUnsafePointer(to: &root) { root in
      withUnsafePointer(to: &record) { substep in
        nb_brain_abi_validate_joint_substep_v2(root, substep)
      }
    }
    try requireValidV2(validation, context: "v2 joint substep")
    transactionFingerprint = record.transaction_fingerprint
    substepIndex = record.substep_index
    attemptIndex = record.attempt_index
    startTimestamp = BrainNanosecondTimestamp(ticks: record.start_timestamp_ticks)
    duration = BrainNanosecondDuration(ticks: record.duration_ticks)
    candidateTimestamp = BrainNanosecondTimestamp(
      ticks: record.candidate_timestamp_ticks
    )
    shadowGeneration = record.shadow_generation
    randomCounterGeneration = record.random_counter_generation
    fingerprint = record.substep_fingerprint
  }

  public var abiRecord: NBJointSubstepTokenV2 {
    var record = NBJointSubstepTokenV2()
    record.transaction_fingerprint = transactionFingerprint
    record.substep_index = substepIndex
    record.attempt_index = attemptIndex
    record.start_timestamp_ticks = startTimestamp.ticks
    record.duration_ticks = duration.ticks
    record.candidate_timestamp_ticks = candidateTimestamp.ticks
    record.shadow_generation = shadowGeneration
    record.random_counter_generation = randomCounterGeneration
    record.clock_domain = clock.domain.rawValue
    record.clock_quantum_nanoseconds = clock.quantumNanoseconds
    record.substep_fingerprint = fingerprint
    return record
  }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }
}

/// Explicit-clock content-addressed NumanX acceptance proof.
@frozen
public struct AcceptedPhysicsStateTokenV2: Equatable, Hashable, Sendable {
  public static let byteCount = Int(NB_ACCEPTED_PHYSICS_STATE_TOKEN_V2_BYTE_COUNT)

  public let transactionFingerprint: UInt64
  public let substepFingerprint: UInt64
  public let physicsStateFingerprint: UInt64
  public let acceptedTimestamp: BrainNanosecondTimestamp
  public let physicsGeneration: UInt64
  public let environmentIdentifier: UInt32
  public let fingerprint: UInt64

  public var clock: BrainPhysicalClock { .exactNanoseconds }
  public var clockDomain: BrainPhysicalClockDomain { clock.domain }
  public var clockQuantumNanoseconds: UInt32 { clock.quantumNanoseconds }
  public var acceptedTimestampTicks: UInt64 { acceptedTimestamp.ticks }

  public init(
    transaction: BrainJointTransactionTokenV2,
    substep: BrainJointSubstepTokenV2,
    physicsStateFingerprint: UInt64,
    physicsGeneration: UInt64
  ) throws {
    var root = transaction.abiRecord
    var candidate = substep.abiRecord
    var record = NBAcceptedPhysicsStateTokenV2()
    record.transaction_fingerprint = transaction.fingerprint
    record.substep_fingerprint = substep.fingerprint
    record.physics_state_fingerprint = physicsStateFingerprint
    record.accepted_timestamp_ticks = substep.candidateTimestamp.ticks
    record.physics_generation = physicsGeneration
    record.environment_identifier = transaction.environmentIdentifier
    record.clock_domain = transaction.clock.domain.rawValue
    record.clock_quantum_nanoseconds = UInt64(transaction.clock.quantumNanoseconds)
    record.token_fingerprint = withUnsafePointer(to: &record) {
      nb_brain_abi_accepted_physics_state_v2_fingerprint($0)
    }
    let validation = withUnsafePointer(to: &root) { root in
      withUnsafePointer(to: &candidate) { candidate in
        withUnsafePointer(to: &record) { accepted in
          nb_brain_abi_validate_accepted_physics_state_v2(
            root, candidate, accepted
          )
        }
      }
    }
    try requireValidV2(validation, context: "v2 accepted-physics")
    transactionFingerprint = transaction.fingerprint
    substepFingerprint = substep.fingerprint
    self.physicsStateFingerprint = physicsStateFingerprint
    acceptedTimestamp = substep.candidateTimestamp
    self.physicsGeneration = physicsGeneration
    environmentIdentifier = transaction.environmentIdentifier
    fingerprint = record.token_fingerprint
  }

  public init(
    validating record: NBAcceptedPhysicsStateTokenV2,
    transaction: BrainJointTransactionTokenV2,
    substep: BrainJointSubstepTokenV2
  ) throws {
    var root = transaction.abiRecord
    var candidate = substep.abiRecord
    var record = record
    let validation = withUnsafePointer(to: &root) { root in
      withUnsafePointer(to: &candidate) { candidate in
        withUnsafePointer(to: &record) { accepted in
          nb_brain_abi_validate_accepted_physics_state_v2(
            root, candidate, accepted
          )
        }
      }
    }
    try requireValidV2(validation, context: "v2 accepted-physics")
    transactionFingerprint = record.transaction_fingerprint
    substepFingerprint = record.substep_fingerprint
    physicsStateFingerprint = record.physics_state_fingerprint
    acceptedTimestamp = BrainNanosecondTimestamp(
      ticks: record.accepted_timestamp_ticks
    )
    physicsGeneration = record.physics_generation
    environmentIdentifier = record.environment_identifier
    fingerprint = record.token_fingerprint
  }

  public var abiRecord: NBAcceptedPhysicsStateTokenV2 {
    var record = NBAcceptedPhysicsStateTokenV2()
    record.transaction_fingerprint = transactionFingerprint
    record.substep_fingerprint = substepFingerprint
    record.physics_state_fingerprint = physicsStateFingerprint
    record.accepted_timestamp_ticks = acceptedTimestamp.ticks
    record.physics_generation = physicsGeneration
    record.environment_identifier = environmentIdentifier
    record.clock_domain = clock.domain.rawValue
    record.clock_quantum_nanoseconds = UInt64(clock.quantumNanoseconds)
    record.token_fingerprint = fingerprint
    return record
  }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }
}

/// Non-authoritative explicit-clock identity for a candidate awaiting the
/// owner's canonical accepted-physics digest.
@frozen
public struct BrainProvisionalPhysicsAcceptanceV2:
  Equatable, Hashable, Sendable
{
  public let environmentIdentifier: UInt32
  public let controlStep: UInt32
  public let transactionFingerprint: UInt64
  public let substepFingerprint: UInt64
  public let substepIndex: UInt32
  public let acceptedTimestamp: BrainNanosecondTimestamp
  public let expectedPhysicsGeneration: UInt64
  public let shadowGeneration: UInt64

  public var clock: BrainPhysicalClock { .exactNanoseconds }
  public var clockDomain: BrainPhysicalClockDomain { clock.domain }
  public var clockQuantumNanoseconds: UInt32 { clock.quantumNanoseconds }

  public init(
    transaction: BrainJointTransactionTokenV2,
    substep: BrainJointSubstepTokenV2
  ) throws {
    var root = transaction.abiRecord
    var candidate = substep.abiRecord
    let validation = withUnsafePointer(to: &root) { root in
      withUnsafePointer(to: &candidate) { substep in
        nb_brain_abi_validate_joint_substep_v2(root, substep)
      }
    }
    try requireValidV2(validation, context: "v2 provisional substep")
    guard substep.substepIndex == 0,
      substep.candidateTimestamp == transaction.targetTimestamp
    else {
      throw BrainRuntimeError.transaction(
        "provisional NumanX acceptance requires one whole-root physical substep"
      )
    }
    guard let controlStep = UInt32(exactly: transaction.controlStepIdentifier) else {
      throw BrainRuntimeError.transaction(
        "NumanX global control step does not fit UInt32"
      )
    }
    let (expectedPhysicsGeneration, overflow) =
      transaction.basePhysicsGeneration.addingReportingOverflow(1)
    guard !overflow else {
      throw BrainRuntimeError.transaction(
        "provisional physics generation overflows UInt64"
      )
    }
    environmentIdentifier = transaction.environmentIdentifier
    self.controlStep = controlStep
    transactionFingerprint = transaction.fingerprint
    substepFingerprint = substep.fingerprint
    substepIndex = substep.substepIndex
    acceptedTimestamp = substep.candidateTimestamp
    self.expectedPhysicsGeneration = expectedPhysicsGeneration
    shadowGeneration = transaction.shadowGeneration
  }
}

/// Explicit-clock commit fields that can be proven before the physical digest
/// exists. Construction validates all root/substep/generation relationships.
@frozen
public struct BrainProvisionalJointCommitPlanV2: Equatable, Hashable, Sendable {
  public let transactionFingerprint: UInt64
  public let substepFingerprint: UInt64
  public let brainGeneration: UInt64
  public let expectedPhysicsGeneration: UInt64
  public let committedTimestamp: BrainNanosecondTimestamp
  public let parameterVersionFingerprint: UInt64
  public let environmentIdentifier: UInt32
  public let controlStep: UInt32

  public var clock: BrainPhysicalClock { .exactNanoseconds }
  public var clockDomain: BrainPhysicalClockDomain { clock.domain }
  public var clockQuantumNanoseconds: UInt32 { clock.quantumNanoseconds }

  public init(
    transaction: BrainJointTransactionTokenV2,
    provisional: BrainProvisionalPhysicsAcceptanceV2
  ) throws {
    let (expectedPhysicsGeneration, overflow) =
      transaction.basePhysicsGeneration.addingReportingOverflow(1)
    guard !overflow,
      provisional.environmentIdentifier == transaction.environmentIdentifier,
      provisional.transactionFingerprint == transaction.fingerprint,
      provisional.substepIndex == 0,
      provisional.acceptedTimestamp == transaction.targetTimestamp,
      provisional.expectedPhysicsGeneration == expectedPhysicsGeneration,
      provisional.shadowGeneration == transaction.shadowGeneration,
      UInt32(exactly: transaction.controlStepIdentifier) == provisional.controlStep
    else {
      throw BrainRuntimeError.transaction(
        "v2 provisional joint receipt does not match the root"
      )
    }
    transactionFingerprint = transaction.fingerprint
    substepFingerprint = provisional.substepFingerprint
    brainGeneration = transaction.shadowGeneration
    self.expectedPhysicsGeneration = expectedPhysicsGeneration
    committedTimestamp = transaction.targetTimestamp
    parameterVersionFingerprint = transaction.parameterVersionFingerprint
    environmentIdentifier = transaction.environmentIdentifier
    controlStep = provisional.controlStep
  }
}

/// Explicit-clock receipt for one atomic brain/physics publication boundary.
@frozen
public struct BrainJointCommitTokenV2: Equatable, Hashable, Sendable {
  public static let byteCount = Int(NB_JOINT_COMMIT_TOKEN_V2_BYTE_COUNT)

  public let transactionFingerprint: UInt64
  public let acceptedPhysicsTokenFingerprint: UInt64
  public let brainGeneration: UInt64
  public let physicsGeneration: UInt64
  public let committedTimestamp: BrainNanosecondTimestamp
  public let parameterVersionFingerprint: UInt64
  public let environmentIdentifier: UInt32
  public let fingerprint: UInt64

  public var clock: BrainPhysicalClock { .exactNanoseconds }
  public var clockDomain: BrainPhysicalClockDomain { clock.domain }
  public var clockQuantumNanoseconds: UInt32 { clock.quantumNanoseconds }
  public var committedTimestampTicks: UInt64 { committedTimestamp.ticks }

  public init(
    transaction: BrainJointTransactionTokenV2,
    acceptedPhysicsState: AcceptedPhysicsStateTokenV2
  ) throws {
    var root = transaction.abiRecord
    var accepted = acceptedPhysicsState.abiRecord
    var record = NBJointCommitTokenV2()
    record.transaction_fingerprint = transaction.fingerprint
    record.accepted_physics_token_fingerprint = acceptedPhysicsState.fingerprint
    record.brain_generation = transaction.shadowGeneration
    record.physics_generation = acceptedPhysicsState.physicsGeneration
    record.committed_timestamp_ticks = transaction.targetTimestamp.ticks
    record.parameter_version_fingerprint = transaction.parameterVersionFingerprint
    record.environment_identifier = transaction.environmentIdentifier
    record.clock_domain = transaction.clock.domain.rawValue
    record.commit_fingerprint = withUnsafePointer(to: &record) {
      nb_brain_abi_joint_commit_v2_fingerprint($0)
    }
    let validation = withUnsafePointer(to: &root) { root in
      withUnsafePointer(to: &accepted) { accepted in
        withUnsafePointer(to: &record) { commit in
          nb_brain_abi_validate_joint_commit_v2(root, accepted, commit)
        }
      }
    }
    try requireValidV2(validation, context: "v2 joint commit")
    transactionFingerprint = transaction.fingerprint
    acceptedPhysicsTokenFingerprint = acceptedPhysicsState.fingerprint
    brainGeneration = transaction.shadowGeneration
    physicsGeneration = acceptedPhysicsState.physicsGeneration
    committedTimestamp = transaction.targetTimestamp
    parameterVersionFingerprint = transaction.parameterVersionFingerprint
    environmentIdentifier = transaction.environmentIdentifier
    fingerprint = record.commit_fingerprint
  }

  public init(
    validating record: NBJointCommitTokenV2,
    transaction: BrainJointTransactionTokenV2,
    acceptedPhysicsState: AcceptedPhysicsStateTokenV2
  ) throws {
    var root = transaction.abiRecord
    var accepted = acceptedPhysicsState.abiRecord
    var record = record
    let validation = withUnsafePointer(to: &root) { root in
      withUnsafePointer(to: &accepted) { accepted in
        withUnsafePointer(to: &record) { commit in
          nb_brain_abi_validate_joint_commit_v2(root, accepted, commit)
        }
      }
    }
    try requireValidV2(validation, context: "v2 joint commit")
    transactionFingerprint = record.transaction_fingerprint
    acceptedPhysicsTokenFingerprint = record.accepted_physics_token_fingerprint
    brainGeneration = record.brain_generation
    physicsGeneration = record.physics_generation
    committedTimestamp = BrainNanosecondTimestamp(
      ticks: record.committed_timestamp_ticks
    )
    parameterVersionFingerprint = record.parameter_version_fingerprint
    environmentIdentifier = record.environment_identifier
    fingerprint = record.commit_fingerprint
  }

  public var abiRecord: NBJointCommitTokenV2 {
    var record = NBJointCommitTokenV2()
    record.transaction_fingerprint = transactionFingerprint
    record.accepted_physics_token_fingerprint = acceptedPhysicsTokenFingerprint
    record.brain_generation = brainGeneration
    record.physics_generation = physicsGeneration
    record.committed_timestamp_ticks = committedTimestamp.ticks
    record.parameter_version_fingerprint = parameterVersionFingerprint
    record.environment_identifier = environmentIdentifier
    record.clock_domain = clock.domain.rawValue
    record.commit_fingerprint = fingerprint
    return record
  }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }
}

// V1 values are permanently and explicitly legacy-microsecond values. These
// computed properties add clock visibility without changing storage, C bytes,
// validation, or fingerprints.
extension BrainJointTransactionToken {
  public var clock: BrainPhysicalClock { .legacyMicroseconds }
  public var clockDomain: BrainPhysicalClockDomain { clock.domain }
  public var clockQuantumNanoseconds: UInt32 { clock.quantumNanoseconds }
}

extension BrainJointSubstepToken {
  public var clock: BrainPhysicalClock { .legacyMicroseconds }
  public var clockDomain: BrainPhysicalClockDomain { clock.domain }
  public var clockQuantumNanoseconds: UInt32 { clock.quantumNanoseconds }
}

extension AcceptedPhysicsStateToken {
  public var clock: BrainPhysicalClock { .legacyMicroseconds }
  public var clockDomain: BrainPhysicalClockDomain { clock.domain }
  public var clockQuantumNanoseconds: UInt32 { clock.quantumNanoseconds }
}

extension BrainProvisionalPhysicsAcceptance {
  public var clock: BrainPhysicalClock { .legacyMicroseconds }
  public var clockDomain: BrainPhysicalClockDomain { clock.domain }
  public var clockQuantumNanoseconds: UInt32 { clock.quantumNanoseconds }
}

extension BrainProvisionalJointCommitPlan {
  public var clock: BrainPhysicalClock { .legacyMicroseconds }
  public var clockDomain: BrainPhysicalClockDomain { clock.domain }
  public var clockQuantumNanoseconds: UInt32 { clock.quantumNanoseconds }
}

extension BrainJointCommitToken {
  public var clock: BrainPhysicalClock { .legacyMicroseconds }
  public var clockDomain: BrainPhysicalClockDomain { clock.domain }
  public var clockQuantumNanoseconds: UInt32 { clock.quantumNanoseconds }
}

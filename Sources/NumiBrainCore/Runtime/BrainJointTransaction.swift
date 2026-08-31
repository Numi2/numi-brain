import Foundation
import NumiBrainABI

/// Stable root identity exchanged with NumanX. It authenticates generations,
/// physical time, immutable parameters, and the random-counter generation but
/// contains no mutable brain or physics pointers.
@frozen
public struct BrainJointTransactionToken: Equatable, Hashable, Sendable {
  public static let formatVersion = UInt32(NB_JOINT_TRANSACTION_VERSION)
  public static let byteCount = Int(NB_JOINT_TRANSACTION_TOKEN_BYTE_COUNT)

  public let environmentIdentifier: UInt32
  public let episodeIdentifier: UInt64
  public let controlStepIdentifier: UInt64
  public let parameterVersionFingerprint: UInt64
  public let baseBrainGeneration: UInt64
  public let basePhysicsGeneration: UInt64
  public let committedTimestamp: BrainTimestamp
  public let targetTimestamp: BrainTimestamp
  public let shadowGeneration: UInt64
  public let randomCounterGeneration: UInt64
  public let fingerprint: UInt64

  public init(
    environmentIdentifier: UInt32,
    episodeIdentifier: UInt64,
    controlStepIdentifier: UInt64,
    parameterVersionFingerprint: UInt64,
    baseBrainGeneration: UInt64,
    basePhysicsGeneration: UInt64,
    committedTimestamp: BrainTimestamp,
    targetTimestamp: BrainTimestamp,
    randomCounterGeneration: UInt64
  ) throws {
    let (shadowGeneration, overflow) = baseBrainGeneration.addingReportingOverflow(1)
    guard !overflow else {
      throw BrainRuntimeError.transaction("brain shadow generation overflows UInt64")
    }
    var record = NBJointTransactionToken()
    record.format_version = Self.formatVersion
    record.environment_identifier = environmentIdentifier
    record.episode_identifier = episodeIdentifier
    record.control_step_identifier = controlStepIdentifier
    record.parameter_version_fingerprint = parameterVersionFingerprint
    record.base_brain_generation = baseBrainGeneration
    record.base_physics_generation = basePhysicsGeneration
    record.committed_timestamp_microseconds = committedTimestamp.rawValue
    record.target_timestamp_microseconds = targetTimestamp.rawValue
    record.shadow_generation = shadowGeneration
    record.random_counter_generation = randomCounterGeneration
    record.flags = 0
    record.reserved = 0
    record.transaction_fingerprint = withUnsafePointer(to: &record) {
      nb_brain_abi_joint_transaction_fingerprint($0)
    }
    let validation = withUnsafePointer(to: &record) {
      nb_brain_abi_validate_joint_transaction($0)
    }
    guard validation == UInt32(NB_JOINT_TRANSACTION_VALID.rawValue) else {
      throw BrainRuntimeError.transaction(
        "compiled joint root validation failed with code \(validation)"
      )
    }
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

  public init(validating record: NBJointTransactionToken) throws {
    var record = record
    let validation = withUnsafePointer(to: &record) {
      nb_brain_abi_validate_joint_transaction($0)
    }
    guard validation == UInt32(NB_JOINT_TRANSACTION_VALID.rawValue) else {
      throw BrainRuntimeError.transaction(
        "compiled joint root validation failed with code \(validation)"
      )
    }
    environmentIdentifier = record.environment_identifier
    episodeIdentifier = record.episode_identifier
    controlStepIdentifier = record.control_step_identifier
    parameterVersionFingerprint = record.parameter_version_fingerprint
    baseBrainGeneration = record.base_brain_generation
    basePhysicsGeneration = record.base_physics_generation
    committedTimestamp = BrainTimestamp(
      microseconds: record.committed_timestamp_microseconds
    )
    targetTimestamp = BrainTimestamp(microseconds: record.target_timestamp_microseconds)
    shadowGeneration = record.shadow_generation
    randomCounterGeneration = record.random_counter_generation
    fingerprint = record.transaction_fingerprint
  }

  public var abiRecord: NBJointTransactionToken {
    var record = NBJointTransactionToken()
    record.format_version = Self.formatVersion
    record.environment_identifier = environmentIdentifier
    record.episode_identifier = episodeIdentifier
    record.control_step_identifier = controlStepIdentifier
    record.parameter_version_fingerprint = parameterVersionFingerprint
    record.base_brain_generation = baseBrainGeneration
    record.base_physics_generation = basePhysicsGeneration
    record.committed_timestamp_microseconds = committedTimestamp.rawValue
    record.target_timestamp_microseconds = targetTimestamp.rawValue
    record.shadow_generation = shadowGeneration
    record.random_counter_generation = randomCounterGeneration
    record.flags = 0
    record.reserved = 0
    record.transaction_fingerprint = fingerprint
    return record
  }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }
}

/// Candidate nested physical-substep identity. Attempt indices can change on
/// retry; the accepted-substep index and random generation do not.
@frozen
public struct BrainJointSubstepToken: Equatable, Hashable, Sendable {
  public static let byteCount = Int(NB_JOINT_SUBSTEP_TOKEN_BYTE_COUNT)

  public let transactionFingerprint: UInt64
  public let substepIndex: UInt32
  public let attemptIndex: UInt32
  public let startTimestamp: BrainTimestamp
  public let durationMicroseconds: UInt64
  public let candidateTimestamp: BrainTimestamp
  public let shadowGeneration: UInt64
  public let randomCounterGeneration: UInt64
  public let fingerprint: UInt64

  public init(
    transaction: BrainJointTransactionToken,
    substepIndex: UInt32,
    attemptIndex: UInt32,
    startTimestamp: BrainTimestamp,
    durationMicroseconds: UInt64
  ) throws {
    let (candidateTimestampValue, overflow) =
      startTimestamp.rawValue.addingReportingOverflow(durationMicroseconds)
    guard !overflow else {
      throw BrainRuntimeError.transaction("candidate substep time overflows UInt64")
    }
    let candidateTimestamp = BrainTimestamp(microseconds: candidateTimestampValue)
    var root = transaction.abiRecord
    var record = NBJointSubstepToken()
    record.transaction_fingerprint = transaction.fingerprint
    record.substep_index = substepIndex
    record.attempt_index = attemptIndex
    record.start_timestamp_microseconds = startTimestamp.rawValue
    record.duration_microseconds = durationMicroseconds
    record.candidate_timestamp_microseconds = candidateTimestamp.rawValue
    record.shadow_generation = transaction.shadowGeneration
    record.random_counter_generation = transaction.randomCounterGeneration
    record.flags = 0
    record.reserved = 0
    record.substep_fingerprint = withUnsafePointer(to: &record) {
      nb_brain_abi_joint_substep_fingerprint($0)
    }
    let validation = withUnsafePointer(to: &root) { root in
      withUnsafePointer(to: &record) { substep in
        nb_brain_abi_validate_joint_substep(root, substep)
      }
    }
    guard validation == UInt32(NB_JOINT_TRANSACTION_VALID.rawValue) else {
      throw BrainRuntimeError.transaction(
        "compiled joint substep validation failed with code \(validation)"
      )
    }
    transactionFingerprint = transaction.fingerprint
    self.substepIndex = substepIndex
    self.attemptIndex = attemptIndex
    self.startTimestamp = startTimestamp
    self.durationMicroseconds = durationMicroseconds
    self.candidateTimestamp = candidateTimestamp
    shadowGeneration = transaction.shadowGeneration
    randomCounterGeneration = transaction.randomCounterGeneration
    fingerprint = record.substep_fingerprint
  }

  public var abiRecord: NBJointSubstepToken {
    var record = NBJointSubstepToken()
    record.transaction_fingerprint = transactionFingerprint
    record.substep_index = substepIndex
    record.attempt_index = attemptIndex
    record.start_timestamp_microseconds = startTimestamp.rawValue
    record.duration_microseconds = durationMicroseconds
    record.candidate_timestamp_microseconds = candidateTimestamp.rawValue
    record.shadow_generation = shadowGeneration
    record.random_counter_generation = randomCounterGeneration
    record.flags = 0
    record.reserved = 0
    record.substep_fingerprint = fingerprint
    return record
  }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }
}

/// Content-addressed proof returned by NumanX only after accepting one physical
/// candidate. It describes the physical generation without exposing state.
@frozen
public struct AcceptedPhysicsStateToken: Equatable, Hashable, Sendable {
  public static let byteCount = Int(NB_ACCEPTED_PHYSICS_STATE_TOKEN_BYTE_COUNT)

  public let transactionFingerprint: UInt64
  public let substepFingerprint: UInt64
  public let physicsStateFingerprint: UInt64
  public let acceptedTimestamp: BrainTimestamp
  public let physicsGeneration: UInt64
  public let environmentIdentifier: UInt32
  public let fingerprint: UInt64

  public init(
    transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken,
    physicsStateFingerprint: UInt64,
    physicsGeneration: UInt64
  ) throws {
    var root = transaction.abiRecord
    var candidate = substep.abiRecord
    var record = NBAcceptedPhysicsStateToken()
    record.transaction_fingerprint = transaction.fingerprint
    record.substep_fingerprint = substep.fingerprint
    record.physics_state_fingerprint = physicsStateFingerprint
    record.accepted_timestamp_microseconds = substep.candidateTimestamp.rawValue
    record.physics_generation = physicsGeneration
    record.environment_identifier = transaction.environmentIdentifier
    record.flags = 0
    record.reserved = 0
    record.token_fingerprint = withUnsafePointer(to: &record) {
      nb_brain_abi_accepted_physics_state_fingerprint($0)
    }
    let validation = withUnsafePointer(to: &root) { root in
      withUnsafePointer(to: &candidate) { candidate in
        withUnsafePointer(to: &record) { accepted in
          nb_brain_abi_validate_accepted_physics_state(root, candidate, accepted)
        }
      }
    }
    guard validation == UInt32(NB_JOINT_TRANSACTION_VALID.rawValue) else {
      throw BrainRuntimeError.transaction(
        "compiled accepted-physics validation failed with code \(validation)"
      )
    }
    transactionFingerprint = transaction.fingerprint
    substepFingerprint = substep.fingerprint
    self.physicsStateFingerprint = physicsStateFingerprint
    acceptedTimestamp = substep.candidateTimestamp
    self.physicsGeneration = physicsGeneration
    environmentIdentifier = transaction.environmentIdentifier
    fingerprint = record.token_fingerprint
  }

  public init(
    validating record: NBAcceptedPhysicsStateToken,
    transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken
  ) throws {
    var root = transaction.abiRecord
    var candidate = substep.abiRecord
    var record = record
    let validation = withUnsafePointer(to: &root) { root in
      withUnsafePointer(to: &candidate) { candidate in
        withUnsafePointer(to: &record) { accepted in
          nb_brain_abi_validate_accepted_physics_state(root, candidate, accepted)
        }
      }
    }
    guard validation == UInt32(NB_JOINT_TRANSACTION_VALID.rawValue) else {
      throw BrainRuntimeError.transaction(
        "compiled accepted-physics validation failed with code \(validation)"
      )
    }
    transactionFingerprint = record.transaction_fingerprint
    substepFingerprint = record.substep_fingerprint
    physicsStateFingerprint = record.physics_state_fingerprint
    acceptedTimestamp = BrainTimestamp(
      microseconds: record.accepted_timestamp_microseconds
    )
    physicsGeneration = record.physics_generation
    environmentIdentifier = record.environment_identifier
    fingerprint = record.token_fingerprint
  }

  public var abiRecord: NBAcceptedPhysicsStateToken {
    var record = NBAcceptedPhysicsStateToken()
    record.transaction_fingerprint = transactionFingerprint
    record.substep_fingerprint = substepFingerprint
    record.physics_state_fingerprint = physicsStateFingerprint
    record.accepted_timestamp_microseconds = acceptedTimestamp.rawValue
    record.physics_generation = physicsGeneration
    record.environment_identifier = environmentIdentifier
    record.flags = 0
    record.reserved = 0
    record.token_fingerprint = fingerprint
    return record
  }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }
}

/// Non-authoritative identity for one physical candidate whose accepted bytes
/// are being prepared entirely on the device timeline. It deliberately has no
/// physical-state or token fingerprint and cannot make a joint root committable.
/// Only binding the owner's later, GPU-validated canonical 64-byte token can
/// advance accepted physics state.
@frozen
public struct BrainProvisionalPhysicsAcceptance: Equatable, Hashable, Sendable {
  public let environmentIdentifier: UInt32
  public let controlStep: UInt32
  public let transactionFingerprint: UInt64
  public let substepFingerprint: UInt64
  public let substepIndex: UInt32
  public let acceptedTimestamp: BrainTimestamp
  public let expectedPhysicsGeneration: UInt64
  public let shadowGeneration: UInt64

  fileprivate init(
    transaction: BrainJointTransactionToken,
    substep: BrainJointSubstepToken,
    controlStep: UInt32,
    expectedPhysicsGeneration: UInt64
  ) {
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

/// Receipt fields that can be proven before the device-generated physical
/// digest exists. This is not a receipt and has no accepted-token fingerprint;
/// it only prevents layout/generation/anatomy work from being deferred until
/// the final owner decision callback.
@frozen
public struct BrainProvisionalJointCommitPlan: Equatable, Hashable, Sendable {
  public let transactionFingerprint: UInt64
  public let substepFingerprint: UInt64
  public let brainGeneration: UInt64
  public let expectedPhysicsGeneration: UInt64
  public let committedTimestamp: BrainTimestamp
  public let parameterVersionFingerprint: UInt64
  public let environmentIdentifier: UInt32
  public let controlStep: UInt32

  fileprivate init(
    transaction: BrainJointTransactionToken,
    provisional: BrainProvisionalPhysicsAcceptance
  ) {
    transactionFingerprint = transaction.fingerprint
    substepFingerprint = provisional.substepFingerprint
    brainGeneration = transaction.shadowGeneration
    expectedPhysicsGeneration = provisional.expectedPhysicsGeneration
    committedTimestamp = transaction.targetTimestamp
    parameterVersionFingerprint = transaction.parameterVersionFingerprint
    environmentIdentifier = transaction.environmentIdentifier
    controlStep = provisional.controlStep
  }
}

/// Receipt for one atomic brain/physics publication boundary.
@frozen
public struct BrainJointCommitToken: Equatable, Hashable, Sendable {
  public static let byteCount = Int(NB_JOINT_COMMIT_TOKEN_BYTE_COUNT)

  public let transactionFingerprint: UInt64
  public let acceptedPhysicsTokenFingerprint: UInt64
  public let brainGeneration: UInt64
  public let physicsGeneration: UInt64
  public let committedTimestamp: BrainTimestamp
  public let parameterVersionFingerprint: UInt64
  public let environmentIdentifier: UInt32
  public let fingerprint: UInt64

  fileprivate init(
    transaction: BrainJointTransactionToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken
  ) throws {
    var root = transaction.abiRecord
    var accepted = acceptedPhysicsState.abiRecord
    var record = NBJointCommitToken()
    record.transaction_fingerprint = transaction.fingerprint
    record.accepted_physics_token_fingerprint = acceptedPhysicsState.fingerprint
    record.brain_generation = transaction.shadowGeneration
    record.physics_generation = acceptedPhysicsState.physicsGeneration
    record.committed_timestamp_microseconds = transaction.targetTimestamp.rawValue
    record.parameter_version_fingerprint = transaction.parameterVersionFingerprint
    record.environment_identifier = transaction.environmentIdentifier
    record.flags = 0
    record.commit_fingerprint = withUnsafePointer(to: &record) {
      nb_brain_abi_joint_commit_fingerprint($0)
    }
    let validation = withUnsafePointer(to: &root) { root in
      withUnsafePointer(to: &accepted) { accepted in
        withUnsafePointer(to: &record) { commit in
          nb_brain_abi_validate_joint_commit(root, accepted, commit)
        }
      }
    }
    guard validation == UInt32(NB_JOINT_TRANSACTION_VALID.rawValue) else {
      throw BrainRuntimeError.transaction(
        "compiled joint commit validation failed with code \(validation)"
      )
    }
    transactionFingerprint = transaction.fingerprint
    acceptedPhysicsTokenFingerprint = acceptedPhysicsState.fingerprint
    brainGeneration = transaction.shadowGeneration
    physicsGeneration = acceptedPhysicsState.physicsGeneration
    committedTimestamp = transaction.targetTimestamp
    parameterVersionFingerprint = transaction.parameterVersionFingerprint
    environmentIdentifier = transaction.environmentIdentifier
    fingerprint = record.commit_fingerprint
  }

  public var abiRecord: NBJointCommitToken {
    var record = NBJointCommitToken()
    record.transaction_fingerprint = transactionFingerprint
    record.accepted_physics_token_fingerprint = acceptedPhysicsTokenFingerprint
    record.brain_generation = brainGeneration
    record.physics_generation = physicsGeneration
    record.committed_timestamp_microseconds = committedTimestamp.rawValue
    record.parameter_version_fingerprint = parameterVersionFingerprint
    record.environment_identifier = environmentIdentifier
    record.flags = 0
    record.commit_fingerprint = fingerprint
    return record
  }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }
}

@frozen
public enum BrainJointTransactionStatus: Equatable, Sendable {
  case open
  case committed
  case aborted
}

@frozen
public struct BrainJointSubstepResolution: Equatable, Hashable, Sendable {
  public let substep: BrainJointSubstepToken
  public let acceptedPhysicsState: AcceptedPhysicsStateToken?
  public let receptorEvents: [BrainInterruptEvent]
  public let localizedMuscleLoadObservations: [LocalizedMuscleLoadReceptorObservation]

  public init(
    substep: BrainJointSubstepToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken?,
    receptorEvents: [BrainInterruptEvent] = [],
    localizedMuscleLoadObservations: [LocalizedMuscleLoadReceptorObservation] = []
  ) {
    self.substep = substep
    self.acceptedPhysicsState = acceptedPhysicsState
    self.receptorEvents = receptorEvents
    self.localizedMuscleLoadObservations = localizedMuscleLoadObservations
  }

  public var isAccepted: Bool { acceptedPhysicsState != nil }
}

/// Swift-owned orchestration state for one joint root. It never owns NumanX
/// physical state; acceptance requires a compiled physical-state token.
public struct BrainJointTransaction: Sendable {
  public let token: BrainJointTransactionToken
  public private(set) var status: BrainJointTransactionStatus = .open
  public private(set) var acceptedTimestamp: BrainTimestamp
  public private(set) var acceptedSubstepCount: UInt32 = 0
  public private(set) var rejectedAttemptCount: UInt64 = 0
  public private(set) var physicsGeneration: UInt64
  public private(set) var activeSubstep: BrainJointSubstepToken?
  public private(set) var lastAcceptedPhysicsState: AcceptedPhysicsStateToken?
  public private(set) var provisionalPhysicsAcceptance:
    BrainProvisionalPhysicsAcceptance?
  public private(set) var resolutions: [BrainJointSubstepResolution] = []

  private var attemptIndex: UInt32 = 0

  public init(token: BrainJointTransactionToken) {
    self.token = token
    acceptedTimestamp = token.committedTimestamp
    physicsGeneration = token.basePhysicsGeneration
  }

  public mutating func beginPhysicsSubstep(
    durationMicroseconds: UInt64
  ) throws -> BrainJointSubstepToken {
    try requireOpen()
    guard activeSubstep == nil else {
      throw BrainRuntimeError.transaction(
        "accept or reject the active physical substep before beginning another"
      )
    }
    let substep = try BrainJointSubstepToken(
      transaction: token,
      substepIndex: acceptedSubstepCount,
      attemptIndex: attemptIndex,
      startTimestamp: acceptedTimestamp,
      durationMicroseconds: durationMicroseconds
    )
    activeSubstep = substep
    return substep
  }

  public mutating func rejectPhysicsSubstep(
    _ substep: BrainJointSubstepToken,
    receptorEvents: [BrainInterruptEvent] = []
  ) throws {
    try requireActive(substep)
    let canonicalEvents = try canonicalReceptorEvents(receptorEvents, for: substep)
    let (nextAttempt, overflow) = attemptIndex.addingReportingOverflow(1)
    guard !overflow else {
      throw BrainRuntimeError.transaction("physical retry attempt index overflows UInt32")
    }
    let (nextRejectedCount, rejectedOverflow) =
      rejectedAttemptCount.addingReportingOverflow(1)
    guard !rejectedOverflow else {
      throw BrainRuntimeError.transaction("physical retry count overflows UInt64")
    }
    attemptIndex = nextAttempt
    rejectedAttemptCount = nextRejectedCount
    resolutions.append(
      BrainJointSubstepResolution(
        substep: substep,
        acceptedPhysicsState: nil,
        receptorEvents: canonicalEvents
      )
    )
    provisionalPhysicsAcceptance = nil
    activeSubstep = nil
  }

  /// Records the identity and expected generation of the sole NumanX physical
  /// substep without claiming that physics accepted it. This is the only core
  /// path that may precede a device-generated physical content digest.
  public mutating func prepareProvisionalPhysicsAcceptance(
    for substep: BrainJointSubstepToken
  ) throws -> BrainProvisionalPhysicsAcceptance {
    try requireActive(substep)
    guard provisionalPhysicsAcceptance == nil else {
      throw BrainRuntimeError.transaction(
        "physical acceptance is already provisionally prepared"
      )
    }
    guard acceptedSubstepCount == 0, substep.substepIndex == 0,
      substep.candidateTimestamp == token.targetTimestamp
    else {
      throw BrainRuntimeError.transaction(
        "provisional NumanX acceptance requires one whole-root physical substep"
      )
    }
    guard let controlStep = UInt32(exactly: token.controlStepIdentifier) else {
      throw BrainRuntimeError.transaction(
        "NumanX v3 global control step does not fit UInt32"
      )
    }
    let (expectedPhysicsGeneration, overflow) =
      physicsGeneration.addingReportingOverflow(1)
    guard !overflow else {
      throw BrainRuntimeError.transaction(
        "provisional physics generation overflows UInt64"
      )
    }
    let provisional = BrainProvisionalPhysicsAcceptance(
      transaction: token,
      substep: substep,
      controlStep: controlStep,
      expectedPhysicsGeneration: expectedPhysicsGeneration
    )
    provisionalPhysicsAcceptance = provisional
    return provisional
  }

  /// Binds the canonical token recovered only after the owner's final GPU
  /// decision validator succeeds. A stale/malformed token leaves the
  /// provisional transaction quarantined and publishes nothing.
  public mutating func bindAcceptedPhysicsState(
    _ accepted: AcceptedPhysicsStateToken,
    to provisional: BrainProvisionalPhysicsAcceptance,
    receptorEvents: [BrainInterruptEvent] = [],
    localizedMuscleLoadObservations: [LocalizedMuscleLoadReceptorObservation] = []
  ) throws {
    guard provisionalPhysicsAcceptance == provisional,
      let substep = activeSubstep,
      provisional.environmentIdentifier == token.environmentIdentifier,
      provisional.transactionFingerprint == token.fingerprint,
      provisional.substepFingerprint == substep.fingerprint,
      provisional.substepIndex == substep.substepIndex,
      provisional.acceptedTimestamp == substep.candidateTimestamp,
      provisional.expectedPhysicsGeneration == accepted.physicsGeneration,
      provisional.shadowGeneration == token.shadowGeneration,
      accepted.transactionFingerprint == provisional.transactionFingerprint,
      accepted.substepFingerprint == provisional.substepFingerprint,
      accepted.acceptedTimestamp == provisional.acceptedTimestamp,
      accepted.environmentIdentifier == provisional.environmentIdentifier
    else {
      throw BrainRuntimeError.transaction(
        "canonical accepted-physics token does not match the provisional root"
      )
    }
    try finishAcceptedPhysicsSubstep(
      accepted,
      for: substep,
      receptorEvents: receptorEvents,
      localizedMuscleLoadObservations: localizedMuscleLoadObservations
    )
  }

  /// Preflights every commit-receipt field that does not depend on the final
  /// physical content digest. Calling this never advances the transaction.
  public func preflightProvisionalCommit(
    _ provisional: BrainProvisionalPhysicsAcceptance
  ) throws -> BrainProvisionalJointCommitPlan {
    try requireOpen()
    let (expectedPhysicsGeneration, generationOverflow) =
      token.basePhysicsGeneration.addingReportingOverflow(1)
    guard provisionalPhysicsAcceptance == provisional,
      let activeSubstep,
      activeSubstep.fingerprint == provisional.substepFingerprint,
      acceptedSubstepCount == 0,
      lastAcceptedPhysicsState == nil,
      acceptedTimestamp == token.committedTimestamp,
      physicsGeneration == token.basePhysicsGeneration,
      provisional.acceptedTimestamp == token.targetTimestamp,
      !generationOverflow,
      provisional.expectedPhysicsGeneration == expectedPhysicsGeneration,
      UInt32(exactly: token.controlStepIdentifier) == provisional.controlStep
    else {
      throw BrainRuntimeError.transaction(
        "provisional joint receipt preflight does not match the open root"
      )
    }
    return BrainProvisionalJointCommitPlan(
      transaction: token,
      provisional: provisional
    )
  }

  public mutating func acceptPhysicsSubstep(
    _ accepted: AcceptedPhysicsStateToken,
    for substep: BrainJointSubstepToken,
    receptorEvents: [BrainInterruptEvent] = [],
    localizedMuscleLoadObservations: [LocalizedMuscleLoadReceptorObservation] = []
  ) throws {
    guard provisionalPhysicsAcceptance == nil else {
      throw BrainRuntimeError.transaction(
        "bind the owner-validated token to the provisional acceptance"
      )
    }
    try finishAcceptedPhysicsSubstep(
      accepted,
      for: substep,
      receptorEvents: receptorEvents,
      localizedMuscleLoadObservations: localizedMuscleLoadObservations
    )
  }

  private mutating func finishAcceptedPhysicsSubstep(
    _ accepted: AcceptedPhysicsStateToken,
    for substep: BrainJointSubstepToken,
    receptorEvents: [BrainInterruptEvent],
    localizedMuscleLoadObservations: [LocalizedMuscleLoadReceptorObservation]
  ) throws {
    try requireActive(substep)
    let canonicalEvents = try canonicalReceptorEvents(receptorEvents, for: substep)
    let canonicalLocalizedObservations = try canonicalMuscleLoadObservations(
      localizedMuscleLoadObservations,
      acceptedPhysicsState: accepted,
      canonicalEvents: canonicalEvents
    )
    var rootRecord = token.abiRecord
    var substepRecord = substep.abiRecord
    var acceptedRecord = accepted.abiRecord
    let validation = withUnsafePointer(to: &rootRecord) { root in
      withUnsafePointer(to: &substepRecord) { substep in
        withUnsafePointer(to: &acceptedRecord) { accepted in
          nb_brain_abi_validate_accepted_physics_state(root, substep, accepted)
        }
      }
    }
    guard validation == UInt32(NB_JOINT_TRANSACTION_VALID.rawValue) else {
      throw BrainRuntimeError.transaction(
        "accepted physical token failed relation validation with code \(validation)"
      )
    }
    let (nextCount, overflow) = acceptedSubstepCount.addingReportingOverflow(1)
    guard !overflow else {
      throw BrainRuntimeError.transaction("accepted substep count overflows UInt32")
    }
    acceptedTimestamp = accepted.acceptedTimestamp
    acceptedSubstepCount = nextCount
    physicsGeneration = accepted.physicsGeneration
    lastAcceptedPhysicsState = accepted
    resolutions.append(
      BrainJointSubstepResolution(
        substep: substep,
        acceptedPhysicsState: accepted,
        receptorEvents: canonicalEvents,
        localizedMuscleLoadObservations: canonicalLocalizedObservations
      )
    )
    provisionalPhysicsAcceptance = nil
    activeSubstep = nil
    attemptIndex = 0
  }

  public mutating func commit() throws -> BrainJointCommitToken {
    try requireOpen()
    guard activeSubstep == nil else {
      throw BrainRuntimeError.transaction("reject or accept the candidate before root commit")
    }
    guard acceptedTimestamp == token.targetTimestamp,
      let lastAcceptedPhysicsState
    else {
      throw BrainRuntimeError.transaction(
        "joint commit requires accepted physical time at the root target"
      )
    }
    let commit = try BrainJointCommitToken(
      transaction: token,
      acceptedPhysicsState: lastAcceptedPhysicsState
    )
    status = .committed
    return commit
  }

  public mutating func abort() throws {
    try requireOpen()
    activeSubstep = nil
    lastAcceptedPhysicsState = nil
    provisionalPhysicsAcceptance = nil
    acceptedTimestamp = token.committedTimestamp
    acceptedSubstepCount = 0
    rejectedAttemptCount = 0
    physicsGeneration = token.basePhysicsGeneration
    resolutions.removeAll(keepingCapacity: true)
    attemptIndex = 0
    status = .aborted
  }

  private func requireOpen() throws {
    guard status == .open else {
      throw BrainRuntimeError.transaction("joint transaction is already \(status)")
    }
  }

  private func requireActive(_ substep: BrainJointSubstepToken) throws {
    try requireOpen()
    guard activeSubstep == substep else {
      throw BrainRuntimeError.transaction("stale or unrelated physical substep token")
    }
  }

  private func canonicalReceptorEvents(
    _ events: [BrainInterruptEvent],
    for substep: BrainJointSubstepToken
  ) throws -> [BrainInterruptEvent] {
    let receptorDerived = UInt32(NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED)
    guard
      events.allSatisfy({ event in
        event.timestamp > substep.startTimestamp
          && event.timestamp <= substep.candidateTimestamp
          && event.flags & receptorDerived != 0
      })
    else {
      throw BrainRuntimeError.transaction(
        "substep events must be receptor-derived and lie after start through candidate time"
      )
    }
    return events.sorted { lhs, rhs in
      if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
      if lhs.identifier != rhs.identifier { return lhs.identifier < rhs.identifier }
      if lhs.mask.rawValue != rhs.mask.rawValue {
        return lhs.mask.rawValue < rhs.mask.rawValue
      }
      if lhs.flags != rhs.flags { return lhs.flags < rhs.flags }
      if lhs.magnitude.bitPattern != rhs.magnitude.bitPattern {
        return lhs.magnitude.bitPattern < rhs.magnitude.bitPattern
      }
      return lhs.auxiliaryValue.bitPattern < rhs.auxiliaryValue.bitPattern
    }
  }

  private func canonicalMuscleLoadObservations(
    _ observations: [LocalizedMuscleLoadReceptorObservation],
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    canonicalEvents: [BrainInterruptEvent]
  ) throws -> [LocalizedMuscleLoadReceptorObservation] {
    guard
      observations.allSatisfy({ observation in
        observation.acceptedPhysicsStateFingerprint == acceptedPhysicsState.fingerprint
          && canonicalEvents.contains(observation.event)
      })
    else {
      throw BrainRuntimeError.transaction(
        "localized muscle-load observations must match accepted physics and events"
      )
    }
    return observations.sorted { lhs, rhs in
      if lhs.event.timestamp != rhs.event.timestamp {
        return lhs.event.timestamp < rhs.event.timestamp
      }
      if lhs.event.identifier != rhs.event.identifier {
        return lhs.event.identifier < rhs.event.identifier
      }
      if lhs.attachmentCatalogFingerprint != rhs.attachmentCatalogFingerprint {
        return lhs.attachmentCatalogFingerprint < rhs.attachmentCatalogFingerprint
      }
      return lhs.maximumAbsoluteMuscleForce.bitPattern
        < rhs.maximumAbsoluteMuscleForce.bitPattern
    }
  }
}

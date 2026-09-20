import NumiBrainABI
import XCTest

@testable import NumiBrainCore

final class BrainJointTransactionV2Tests: XCTestCase {
  private func makeExactRoot(
    committedNanoseconds: UInt64 = 12_500,
    targetNanoseconds: UInt64 = 25_000
  ) throws -> BrainJointTransactionTokenV2 {
    try .exactNanoseconds(
      environmentIdentifier: 7,
      episodeIdentifier: 23,
      controlStepIdentifier: 17,
      parameterVersionFingerprint: 0x1234_5678_9abc_def0,
      baseBrainGeneration: 9,
      basePhysicsGeneration: 100,
      committedTimestampNanoseconds: committedNanoseconds,
      targetTimestampNanoseconds: targetNanoseconds,
      randomCounterGeneration: 55
    )
  }

  private func makeLegacyRoot() throws -> BrainJointTransactionToken {
    try BrainJointTransactionToken(
      environmentIdentifier: 7,
      episodeIdentifier: 23,
      controlStepIdentifier: 17,
      parameterVersionFingerprint: 0x1234_5678_9abc_def0,
      baseBrainGeneration: 9,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 12_500),
      targetTimestamp: BrainTimestamp(microseconds: 25_000),
      randomCounterGeneration: 55
    )
  }

  func testExactV2LayoutsAndNanosecondTransactionAreStable() throws {
    XCTAssertEqual(
      nb_brain_abi_joint_transaction_token_v2_size(),
      Int(NB_JOINT_TRANSACTION_TOKEN_V2_BYTE_COUNT)
    )
    XCTAssertEqual(
      nb_brain_abi_joint_substep_token_v2_size(),
      Int(NB_JOINT_SUBSTEP_TOKEN_V2_BYTE_COUNT)
    )
    XCTAssertEqual(
      nb_brain_abi_accepted_physics_state_token_v2_size(),
      Int(NB_ACCEPTED_PHYSICS_STATE_TOKEN_V2_BYTE_COUNT)
    )
    XCTAssertEqual(
      nb_brain_abi_joint_commit_token_v2_size(),
      Int(NB_JOINT_COMMIT_TOKEN_V2_BYTE_COUNT)
    )
    XCTAssertEqual(MemoryLayout<NBJointTransactionTokenV2>.stride, 96)
    XCTAssertEqual(MemoryLayout<NBJointSubstepTokenV2>.stride, 72)
    XCTAssertEqual(MemoryLayout<NBAcceptedPhysicsStateTokenV2>.stride, 64)
    XCTAssertEqual(MemoryLayout<NBJointCommitTokenV2>.stride, 64)
    XCTAssertEqual(BrainJointTransactionTokenV2.byteCount, 96)
    XCTAssertEqual(BrainJointSubstepTokenV2.byteCount, 72)
    XCTAssertEqual(AcceptedPhysicsStateTokenV2.byteCount, 64)
    XCTAssertEqual(BrainJointCommitTokenV2.byteCount, 64)

    XCTAssertEqual(
      BrainPhysicalClockDomain.legacyMicroseconds.rawValue,
      UInt32(NB_PHYSICAL_CLOCK_DOMAIN_LEGACY_MICROSECONDS)
    )
    XCTAssertEqual(
      BrainPhysicalClockDomain.exactNanoseconds.rawValue,
      UInt32(NB_PHYSICAL_CLOCK_DOMAIN_EXACT_NANOSECONDS)
    )
    XCTAssertEqual(BrainPhysicalClock.legacyMicroseconds.quantumNanoseconds, 1_000)
    XCTAssertEqual(BrainPhysicalClock.exactNanoseconds.quantumNanoseconds, 1)

    let root = try makeExactRoot()
    XCTAssertEqual(root.clock, .exactNanoseconds)
    XCTAssertEqual(root.clockDomain, .exactNanoseconds)
    XCTAssertEqual(root.clockQuantumNanoseconds, 1)
    XCTAssertEqual(root.committedTimestamp.ticks, 12_500)
    XCTAssertEqual(root.committedTimestamp.nanoseconds, 12_500)
    XCTAssertEqual(root.targetTimestamp.ticks, 25_000)
    var rootRecord = root.abiRecord
    XCTAssertEqual(rootRecord.committed_timestamp_ticks, 12_500)
    XCTAssertEqual(rootRecord.target_timestamp_ticks, 25_000)
    XCTAssertEqual(
      rootRecord.clock_domain,
      UInt32(NB_PHYSICAL_CLOCK_DOMAIN_EXACT_NANOSECONDS)
    )
    XCTAssertEqual(rootRecord.clock_quantum_nanoseconds, 1)
    XCTAssertEqual(
      withUnsafePointer(to: &rootRecord) {
        nb_brain_abi_validate_joint_transaction_v2($0)
      },
      UInt32(NB_JOINT_TRANSACTION_VALID.rawValue)
    )
    XCTAssertEqual(try BrainJointTransactionTokenV2(validating: rootRecord), root)
    XCTAssertEqual(
      try BrainJointTransactionTokenV2(
        environmentIdentifier: 7,
        episodeIdentifier: 23,
        controlStepIdentifier: 17,
        parameterVersionFingerprint: 0x1234_5678_9abc_def0,
        baseBrainGeneration: 9,
        basePhysicsGeneration: 100,
        committedTimestampTicks: 12_500,
        targetTimestampTicks: 25_000,
        randomCounterGeneration: 55
      ),
      root
    )

    let substep = try BrainJointSubstepTokenV2.exactNanoseconds(
      transaction: root,
      substepIndex: 0,
      attemptIndex: 0,
      startTimestampNanoseconds: 12_500,
      durationNanoseconds: 12_500
    )
    XCTAssertEqual(substep.startTimestamp.ticks, 12_500)
    XCTAssertEqual(substep.duration.ticks, 12_500)
    XCTAssertEqual(substep.candidateTimestamp.ticks, 25_000)
    XCTAssertEqual(
      try BrainJointSubstepTokenV2(
        validating: substep.abiRecord,
        transaction: root
      ),
      substep
    )

    let provisional = try BrainProvisionalPhysicsAcceptanceV2(
      transaction: root,
      substep: substep
    )
    XCTAssertEqual(provisional.clock, .exactNanoseconds)
    XCTAssertEqual(provisional.acceptedTimestamp.ticks, 25_000)
    XCTAssertEqual(provisional.expectedPhysicsGeneration, 101)
    let plan = try BrainProvisionalJointCommitPlanV2(
      transaction: root,
      provisional: provisional
    )
    XCTAssertEqual(plan.clock, .exactNanoseconds)
    XCTAssertEqual(plan.committedTimestamp.ticks, 25_000)

    let accepted = try AcceptedPhysicsStateTokenV2(
      transaction: root,
      substep: substep,
      physicsStateFingerprint: 0xa001,
      physicsGeneration: 101
    )
    XCTAssertEqual(accepted.clock, .exactNanoseconds)
    XCTAssertEqual(accepted.acceptedTimestamp.ticks, 25_000)
    XCTAssertEqual(
      try AcceptedPhysicsStateTokenV2(
        validating: accepted.abiRecord,
        transaction: root,
        substep: substep
      ),
      accepted
    )

    let commit = try BrainJointCommitTokenV2(
      transaction: root,
      acceptedPhysicsState: accepted
    )
    XCTAssertEqual(commit.clock, .exactNanoseconds)
    XCTAssertEqual(commit.committedTimestamp.ticks, 25_000)
    XCTAssertEqual(
      try BrainJointCommitTokenV2(
        validating: commit.abiRecord,
        transaction: root,
        acceptedPhysicsState: accepted
      ),
      commit
    )
  }

  func testV1RemainsLegacyAndSameNumericPayloadIsDomainSeparated() throws {
    let legacy = try makeLegacyRoot()
    let exact = try makeExactRoot()

    XCTAssertEqual(legacy.clock, .legacyMicroseconds)
    XCTAssertEqual(legacy.abiRecord.flags, 0)
    XCTAssertEqual(legacy.abiRecord.reserved, 0)
    XCTAssertEqual(legacy.fingerprint, 0xdc03_945c_65c1_f7d7)
    XCTAssertNotEqual(legacy.fingerprint, exact.fingerprint)

    let legacySubstep = try BrainJointSubstepToken(
      transaction: legacy,
      substepIndex: 0,
      attemptIndex: 0,
      startTimestamp: legacy.committedTimestamp,
      durationMicroseconds: 12_500
    )
    let legacyAccepted = try AcceptedPhysicsStateToken(
      transaction: legacy,
      substep: legacySubstep,
      physicsStateFingerprint: 0xa001,
      physicsGeneration: 101
    )
    var legacyTransaction = BrainJointTransaction(token: legacy)
    XCTAssertEqual(
      try legacyTransaction.beginPhysicsSubstep(durationMicroseconds: 12_500),
      legacySubstep
    )
    try legacyTransaction.acceptPhysicsSubstep(legacyAccepted, for: legacySubstep)
    let legacyCommit = try legacyTransaction.commit()
    XCTAssertEqual(legacySubstep.clock, .legacyMicroseconds)
    XCTAssertEqual(legacyAccepted.clock, .legacyMicroseconds)
    XCTAssertEqual(legacyCommit.clock, .legacyMicroseconds)

    var legacyRecord = legacy.abiRecord
    let mixedAsV2 = withUnsafePointer(to: &legacyRecord) { legacyPointer in
      legacyPointer.withMemoryRebound(
        to: NBJointTransactionTokenV2.self,
        capacity: 1
      ) { v2Pointer in
        nb_brain_abi_validate_joint_transaction_v2(v2Pointer)
      }
    }
    XCTAssertEqual(mixedAsV2, UInt32(NB_JOINT_TRANSACTION_FORMAT.rawValue))

    var exactRecord = exact.abiRecord
    let mixedAsV1 = withUnsafePointer(to: &exactRecord) { exactPointer in
      exactPointer.withMemoryRebound(
        to: NBJointTransactionToken.self,
        capacity: 1
      ) { v1Pointer in
        nb_brain_abi_validate_joint_transaction(v1Pointer)
      }
    }
    XCTAssertEqual(mixedAsV1, UInt32(NB_JOINT_TRANSACTION_FORMAT.rawValue))
  }

  func testV2RejectsLegacyNonUnitAndMixedClockMetadata() throws {
    let root = try makeExactRoot()
    let substep = try BrainJointSubstepTokenV2.exactNanoseconds(
      transaction: root,
      substepIndex: 0,
      attemptIndex: 0,
      startTimestampNanoseconds: 12_500,
      durationNanoseconds: 12_500
    )
    let accepted = try AcceptedPhysicsStateTokenV2(
      transaction: root,
      substep: substep,
      physicsStateFingerprint: 0xa001,
      physicsGeneration: 101
    )
    let commit = try BrainJointCommitTokenV2(
      transaction: root,
      acceptedPhysicsState: accepted
    )

    var legacyDomainRoot = root.abiRecord
    legacyDomainRoot.clock_domain = UInt32(
      NB_PHYSICAL_CLOCK_DOMAIN_LEGACY_MICROSECONDS
    )
    legacyDomainRoot.clock_quantum_nanoseconds = 1_000
    legacyDomainRoot.transaction_fingerprint = withUnsafePointer(
      to: &legacyDomainRoot
    ) {
      nb_brain_abi_joint_transaction_v2_fingerprint($0)
    }
    XCTAssertEqual(
      withUnsafePointer(to: &legacyDomainRoot) {
        nb_brain_abi_validate_joint_transaction_v2($0)
      },
      UInt32(NB_JOINT_TRANSACTION_CLOCK.rawValue)
    )

    var nonUnitRoot = root.abiRecord
    nonUnitRoot.clock_quantum_nanoseconds = 2
    nonUnitRoot.transaction_fingerprint = withUnsafePointer(to: &nonUnitRoot) {
      nb_brain_abi_joint_transaction_v2_fingerprint($0)
    }
    XCTAssertEqual(
      withUnsafePointer(to: &nonUnitRoot) {
        nb_brain_abi_validate_joint_transaction_v2($0)
      },
      UInt32(NB_JOINT_TRANSACTION_CLOCK.rawValue)
    )

    var mixedRoot = root.abiRecord
    mixedRoot.clock_quantum_nanoseconds = 1_000
    mixedRoot.transaction_fingerprint = withUnsafePointer(to: &mixedRoot) {
      nb_brain_abi_joint_transaction_v2_fingerprint($0)
    }
    XCTAssertEqual(
      withUnsafePointer(to: &mixedRoot) {
        nb_brain_abi_validate_joint_transaction_v2($0)
      },
      UInt32(NB_JOINT_TRANSACTION_CLOCK.rawValue)
    )

    var rootRecord = root.abiRecord
    var legacySubstep = substep.abiRecord
    legacySubstep.clock_domain = UInt32(
      NB_PHYSICAL_CLOCK_DOMAIN_LEGACY_MICROSECONDS
    )
    legacySubstep.clock_quantum_nanoseconds = 1_000
    legacySubstep.substep_fingerprint = withUnsafePointer(to: &legacySubstep) {
      nb_brain_abi_joint_substep_v2_fingerprint($0)
    }
    XCTAssertEqual(
      withUnsafePointer(to: &rootRecord) { root in
        withUnsafePointer(to: &legacySubstep) { substep in
          nb_brain_abi_validate_joint_substep_v2(root, substep)
        }
      },
      UInt32(NB_JOINT_TRANSACTION_CLOCK.rawValue)
    )

    var substepRecord = substep.abiRecord
    var nonUnitAccepted = accepted.abiRecord
    nonUnitAccepted.clock_quantum_nanoseconds = 2
    nonUnitAccepted.token_fingerprint = withUnsafePointer(to: &nonUnitAccepted) {
      nb_brain_abi_accepted_physics_state_v2_fingerprint($0)
    }
    XCTAssertEqual(
      withUnsafePointer(to: &rootRecord) { root in
        withUnsafePointer(to: &substepRecord) { substep in
          withUnsafePointer(to: &nonUnitAccepted) { accepted in
            nb_brain_abi_validate_accepted_physics_state_v2(
              root, substep, accepted
            )
          }
        }
      },
      UInt32(NB_JOINT_TRANSACTION_CLOCK.rawValue)
    )

    var acceptedRecord = accepted.abiRecord
    var legacyCommit = commit.abiRecord
    legacyCommit.clock_domain = UInt32(
      NB_PHYSICAL_CLOCK_DOMAIN_LEGACY_MICROSECONDS
    )
    legacyCommit.commit_fingerprint = withUnsafePointer(to: &legacyCommit) {
      nb_brain_abi_joint_commit_v2_fingerprint($0)
    }
    XCTAssertEqual(
      withUnsafePointer(to: &rootRecord) { root in
        withUnsafePointer(to: &acceptedRecord) { accepted in
          withUnsafePointer(to: &legacyCommit) { commit in
            nb_brain_abi_validate_joint_commit_v2(root, accepted, commit)
          }
        }
      },
      UInt32(NB_JOINT_TRANSACTION_CLOCK.rawValue)
    )

    var zeroPhysicsAccepted = accepted.abiRecord
    zeroPhysicsAccepted.physics_state_fingerprint = 0
    zeroPhysicsAccepted.token_fingerprint = withUnsafePointer(
      to: &zeroPhysicsAccepted
    ) {
      nb_brain_abi_accepted_physics_state_v2_fingerprint($0)
    }
    var zeroPhysicsCommit = commit.abiRecord
    zeroPhysicsCommit.accepted_physics_token_fingerprint =
      zeroPhysicsAccepted.token_fingerprint
    zeroPhysicsCommit.commit_fingerprint = withUnsafePointer(
      to: &zeroPhysicsCommit
    ) {
      nb_brain_abi_joint_commit_v2_fingerprint($0)
    }
    XCTAssertEqual(
      withUnsafePointer(to: &rootRecord) { root in
        withUnsafePointer(to: &zeroPhysicsAccepted) { accepted in
          withUnsafePointer(to: &zeroPhysicsCommit) { commit in
            nb_brain_abi_validate_joint_commit_v2(root, accepted, commit)
          }
        }
      },
      UInt32(NB_JOINT_TRANSACTION_IDENTITY.rawValue)
    )

    XCTAssertThrowsError(
      try BrainPhysicalClock(
        domain: .legacyMicroseconds,
        quantumNanoseconds: 1
      )
    )
    XCTAssertThrowsError(
      try BrainPhysicalClock(
        domain: .exactNanoseconds,
        quantumNanoseconds: 2
      )
    )
  }

  func testExactConstructionFailsClosedOnTimeAndGenerationOverflow() throws {
    XCTAssertThrowsError(
      try makeExactRoot(committedNanoseconds: 25_000, targetNanoseconds: 25_000)
    )

    let root = try makeExactRoot(
      committedNanoseconds: UInt64.max - 1,
      targetNanoseconds: UInt64.max
    )
    XCTAssertThrowsError(
      try BrainJointSubstepTokenV2(
        transaction: root,
        substepIndex: 0,
        attemptIndex: 0,
        startTimestamp: BrainNanosecondTimestamp(ticks: UInt64.max - 1),
        duration: BrainNanosecondDuration(ticks: 2)
      )
    )

    XCTAssertThrowsError(
      try BrainJointTransactionTokenV2.exactNanoseconds(
        environmentIdentifier: 7,
        episodeIdentifier: 23,
        controlStepIdentifier: 17,
        parameterVersionFingerprint: 0x1234,
        baseBrainGeneration: .max,
        basePhysicsGeneration: 100,
        committedTimestampNanoseconds: 0,
        targetTimestampNanoseconds: 1,
        randomCounterGeneration: 55
      )
    )
  }
}

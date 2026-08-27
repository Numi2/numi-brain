import Foundation
import NumiBrainABI
import XCTest

@testable import NumiBrainCore

final class BrainJointTransactionTests: XCTestCase {
  private func makeToken(
    controlStep: UInt64 = 17,
    baseBrainGeneration: UInt64 = 9,
    basePhysicsGeneration: UInt64 = 100
  ) throws -> BrainJointTransactionToken {
    try BrainJointTransactionToken(
      environmentIdentifier: 7,
      episodeIdentifier: 23,
      controlStepIdentifier: controlStep,
      parameterVersionFingerprint: 0x1234_5678_9abc_def0,
      baseBrainGeneration: baseBrainGeneration,
      basePhysicsGeneration: basePhysicsGeneration,
      committedTimestamp: BrainTimestamp(microseconds: 80_000),
      targetTimestamp: BrainTimestamp(microseconds: 100_000),
      randomCounterGeneration: 55
    )
  }

  func testCompiledJointTransactionABIAndFingerprintsAreStable() throws {
    XCTAssertEqual(
      nb_brain_abi_joint_transaction_token_size(),
      Int(NB_JOINT_TRANSACTION_TOKEN_BYTE_COUNT)
    )
    XCTAssertEqual(
      nb_brain_abi_joint_substep_token_size(),
      Int(NB_JOINT_SUBSTEP_TOKEN_BYTE_COUNT)
    )
    XCTAssertEqual(
      nb_brain_abi_accepted_physics_state_token_size(),
      Int(NB_ACCEPTED_PHYSICS_STATE_TOKEN_BYTE_COUNT)
    )
    XCTAssertEqual(
      nb_brain_abi_joint_commit_token_size(),
      Int(NB_JOINT_COMMIT_TOKEN_BYTE_COUNT)
    )
    XCTAssertEqual(MemoryLayout<NBJointTransactionToken>.stride, 96)
    XCTAssertEqual(MemoryLayout<NBJointSubstepToken>.stride, 72)
    XCTAssertEqual(MemoryLayout<NBAcceptedPhysicsStateToken>.stride, 64)
    XCTAssertEqual(MemoryLayout<NBJointCommitToken>.stride, 64)

    let token = try makeToken()
    var root = token.abiRecord
    XCTAssertEqual(
      withUnsafePointer(to: &root) { nb_brain_abi_validate_joint_transaction($0) },
      UInt32(NB_JOINT_TRANSACTION_VALID.rawValue)
    )
    XCTAssertEqual(
      withUnsafePointer(to: &root) { nb_brain_abi_joint_transaction_fingerprint($0) },
      token.fingerprint
    )
    XCTAssertEqual(try BrainJointTransactionToken(validating: root), token)

    root.transaction_fingerprint &+= 1
    XCTAssertEqual(
      withUnsafePointer(to: &root) { nb_brain_abi_validate_joint_transaction($0) },
      UInt32(NB_JOINT_TRANSACTION_FINGERPRINT.rawValue)
    )
  }

  func testRejectedRetryPreservesDecisionIdentityAndJointCommitIsExact() throws {
    let token = try makeToken()
    var transaction = BrainJointTransaction(token: token)

    let rejected = try transaction.beginPhysicsSubstep(durationMicroseconds: 5_000)
    XCTAssertEqual(rejected.substepIndex, 0)
    XCTAssertEqual(rejected.attemptIndex, 0)
    let rejectedEvent = try BrainInterruptEvent(
      timestamp: BrainTimestamp(microseconds: 82_500),
      mask: .pain,
      identifier: 41,
      flags: UInt32(NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED)
    )
    try transaction.rejectPhysicsSubstep(rejected, receptorEvents: [rejectedEvent])

    let retry = try transaction.beginPhysicsSubstep(durationMicroseconds: 5_000)
    XCTAssertEqual(retry.substepIndex, rejected.substepIndex)
    XCTAssertEqual(retry.attemptIndex, 1)
    XCTAssertEqual(retry.startTimestamp, rejected.startTimestamp)
    XCTAssertEqual(retry.shadowGeneration, rejected.shadowGeneration)
    XCTAssertEqual(retry.randomCounterGeneration, rejected.randomCounterGeneration)
    XCTAssertNotEqual(retry.fingerprint, rejected.fingerprint)

    let firstAccepted = try AcceptedPhysicsStateToken(
      transaction: token,
      substep: retry,
      physicsStateFingerprint: 0xa001,
      physicsGeneration: 101
    )
    XCTAssertEqual(
      try AcceptedPhysicsStateToken(
        validating: firstAccepted.abiRecord,
        transaction: token,
        substep: retry
      ),
      firstAccepted
    )
    let acceptedEvent = try BrainInterruptEvent(
      timestamp: BrainTimestamp(microseconds: 83_000),
      mask: .lossOfSupport,
      identifier: 42,
      flags: UInt32(NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED)
    )
    try transaction.acceptPhysicsSubstep(
      firstAccepted,
      for: retry,
      receptorEvents: [acceptedEvent]
    )
    XCTAssertEqual(transaction.acceptedTimestamp, BrainTimestamp(microseconds: 85_000))
    XCTAssertEqual(transaction.acceptedSubstepCount, 1)
    XCTAssertEqual(transaction.rejectedAttemptCount, 1)
    XCTAssertEqual(transaction.resolutions.map(\.isAccepted), [false, true])
    XCTAssertEqual(transaction.resolutions[0].receptorEvents, [rejectedEvent])
    XCTAssertEqual(transaction.resolutions[1].receptorEvents, [acceptedEvent])

    let second = try transaction.beginPhysicsSubstep(durationMicroseconds: 15_000)
    XCTAssertEqual(second.substepIndex, 1)
    XCTAssertEqual(second.attemptIndex, 0)
    let secondAccepted = try AcceptedPhysicsStateToken(
      transaction: token,
      substep: second,
      physicsStateFingerprint: 0xa002,
      physicsGeneration: 102
    )
    try transaction.acceptPhysicsSubstep(secondAccepted, for: second)
    let commit = try transaction.commit()

    XCTAssertEqual(transaction.status, .committed)
    XCTAssertEqual(commit.brainGeneration, token.baseBrainGeneration + 1)
    XCTAssertEqual(commit.physicsGeneration, 102)
    XCTAssertEqual(commit.committedTimestamp, token.targetTimestamp)
    XCTAssertEqual(commit.acceptedPhysicsTokenFingerprint, secondAccepted.fingerprint)
    XCTAssertEqual(transaction.resolutions.map(\.isAccepted), [false, true, true])

    var root = token.abiRecord
    var accepted = secondAccepted.abiRecord
    var receipt = commit.abiRecord
    let validation = withUnsafePointer(to: &root) { root in
      withUnsafePointer(to: &accepted) { accepted in
        withUnsafePointer(to: &receipt) { receipt in
          nb_brain_abi_validate_joint_commit(root, accepted, receipt)
        }
      }
    }
    XCTAssertEqual(validation, UInt32(NB_JOINT_TRANSACTION_VALID.rawValue))
    XCTAssertThrowsError(try transaction.beginPhysicsSubstep(durationMicroseconds: 1))
  }

  func testStaleTokensEarlyCommitAndInvalidPhysicsGenerationAreRejected() throws {
    let token = try makeToken()
    var transaction = BrainJointTransaction(token: token)
    XCTAssertThrowsError(try transaction.commit())

    let candidate = try transaction.beginPhysicsSubstep(durationMicroseconds: 5_000)
    let untransduced = try BrainInterruptEvent(
      timestamp: BrainTimestamp(microseconds: 82_000),
      mask: .pain,
      identifier: 99
    )
    XCTAssertThrowsError(
      try transaction.rejectPhysicsSubstep(
        candidate,
        receptorEvents: [untransduced]
      )
    )
    XCTAssertThrowsError(
      try AcceptedPhysicsStateToken(
        transaction: token,
        substep: candidate,
        physicsStateFingerprint: 0xa001,
        physicsGeneration: 102
      )
    )

    let otherToken = try makeToken(controlStep: 18)
    let unrelated = try BrainJointSubstepToken(
      transaction: otherToken,
      substepIndex: 0,
      attemptIndex: 0,
      startTimestamp: otherToken.committedTimestamp,
      durationMicroseconds: 5_000
    )
    XCTAssertThrowsError(try transaction.rejectPhysicsSubstep(unrelated))
    try transaction.rejectPhysicsSubstep(candidate)
    XCTAssertThrowsError(try transaction.beginPhysicsSubstep(durationMicroseconds: 25_000))

    try transaction.abort()
    XCTAssertEqual(transaction.status, .aborted)
    XCTAssertEqual(transaction.acceptedTimestamp, token.committedTimestamp)
    XCTAssertEqual(transaction.acceptedSubstepCount, 0)
    XCTAssertEqual(transaction.rejectedAttemptCount, 0)
    XCTAssertEqual(transaction.resolutions, [])
    XCTAssertEqual(transaction.physicsGeneration, token.basePhysicsGeneration)
    XCTAssertThrowsError(try transaction.beginPhysicsSubstep(durationMicroseconds: 1))
  }

  func testAcceptedMuscleLoadTransducesWithoutExposingForceToScheduler() throws {
    let token = try makeToken()
    let substep = try BrainJointSubstepToken(
      transaction: token,
      substepIndex: 0,
      attemptIndex: 0,
      startTimestamp: token.committedTimestamp,
      durationMicroseconds: 5_000
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: token,
      substep: substep,
      physicsStateFingerprint: 0xa001,
      physicsGeneration: 101
    )
    let transducer = try MuscleLoadReceptorTransducer(overloadThreshold: 10)

    XCTAssertNil(
      try transducer.transduce(
        maximumAbsoluteMuscleForce: 10,
        acceptedPhysicsState: accepted,
        receptorIdentifier: 77
      )
    )
    let event = try XCTUnwrap(
      transducer.transduce(
        maximumAbsoluteMuscleForce: 10.25,
        acceptedPhysicsState: accepted,
        receptorIdentifier: 77
      )
    )
    XCTAssertEqual(event.timestamp, accepted.acceptedTimestamp)
    XCTAssertEqual(event.mask, .muscleOverload)
    XCTAssertEqual(event.identifier, 77)
    XCTAssertEqual(event.flags, UInt32(NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED))
    let attachment = try NumanXMuscleAttachment(
      muscleIdentifier: 77,
      firstBodyIdentifier: 2,
      terminalBodyIdentifier: 5,
      routeNodeCount: 3,
      firstLocalPoint: try NumanXBodyLocalPoint(x: 0.1, y: 0.2, z: 0.3),
      terminalLocalPoint: try NumanXBodyLocalPoint(x: 0.4, y: 0.5, z: 0.6)
    )
    let catalog = try NumanXMuscleAttachmentCatalog(
      bodyCount: 6,
      attachments: [attachment]
    )
    let localized = try XCTUnwrap(
      transducer.transduceLocalized(
        maximumAbsoluteMuscleForce: 10.25,
        acceptedPhysicsState: accepted,
        muscleIdentifier: 77,
        attachmentCatalog: catalog
      )
    )
    XCTAssertEqual(localized.event, event)
    XCTAssertEqual(localized.attachment, attachment)
    XCTAssertEqual(localized.attachmentCatalogFingerprint, catalog.fingerprint)

    var transaction = BrainJointTransaction(token: token)
    XCTAssertEqual(
      try transaction.beginPhysicsSubstep(durationMicroseconds: 5_000),
      substep
    )
    try transaction.acceptPhysicsSubstep(
      accepted,
      for: substep,
      receptorEvents: [event],
      localizedMuscleLoadObservations: [localized]
    )
    XCTAssertEqual(
      transaction.resolutions[0].localizedMuscleLoadObservations,
      [localized]
    )
    XCTAssertThrowsError(
      try transducer.transduce(
        maximumAbsoluteMuscleForce: -.infinity,
        acceptedPhysicsState: accepted,
        receptorIdentifier: 77
      )
    )
    let zeroIdentifierEvent = try XCTUnwrap(
      transducer.transduce(
        maximumAbsoluteMuscleForce: 11,
        acceptedPhysicsState: accepted,
        receptorIdentifier: 0
      )
    )
    XCTAssertEqual(zeroIdentifierEvent.identifier, 0)
    XCTAssertEqual(zeroIdentifierEvent.mask, .muscleOverload)
    XCTAssertThrowsError(
      try transducer.transduceLocalized(
        maximumAbsoluteMuscleForce: 11,
        acceptedPhysicsState: accepted,
        muscleIdentifier: 0,
        attachmentCatalog: catalog
      )
    )
    XCTAssertThrowsError(try MuscleLoadReceptorTransducer(overloadThreshold: .nan))
  }
}

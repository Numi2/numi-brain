import Metal
import NumiBrainABI
import XCTest

@testable import NumiBrainCore
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalJointTransactionTests: XCTestCase {
  private let parameters = TissueParameters.corticalSheetV0

  func testMetalRootPublishesOnlyThroughMatchingJointCommit() throws {
    try requireMetal4()
    let runtime = try makeRuntime(maxEncodedSubsteps: 3)
    var joint = try runtime.beginJointControl(
      controlStepIdentifier: 4,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 2_000)
    )

    let rejected = try joint.beginPhysicsSubstep(durationMicroseconds: 1_000)
    let rejectedPain = try BrainInterruptEvent(
      timestamp: BrainTimestamp(microseconds: 500),
      mask: .pain,
      identifier: 900,
      flags: UInt32(NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED)
    )
    try joint.rejectPhysicsSubstep(rejected, receptorEvents: [rejectedPain])
    let retry = try joint.beginPhysicsSubstep(durationMicroseconds: 1_000)
    let firstPhysics = try AcceptedPhysicsStateToken(
      transaction: joint.token,
      substep: retry,
      physicsStateFingerprint: 0xabc1,
      physicsGeneration: 101
    )
    let acceptedSupportLoss = try BrainInterruptEvent(
      timestamp: BrainTimestamp(microseconds: 750),
      mask: .lossOfSupport,
      identifier: 901,
      flags: UInt32(NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED)
    )
    try joint.acceptPhysicsSubstep(
      firstPhysics,
      for: retry,
      receptorEvents: [acceptedSupportLoss]
    )
    let second = try joint.beginPhysicsSubstep(durationMicroseconds: 1_000)
    let secondPhysics = try AcceptedPhysicsStateToken(
      transaction: joint.token,
      substep: second,
      physicsStateFingerprint: 0xabc2,
      physicsGeneration: 102
    )
    try joint.acceptPhysicsSubstep(secondPhysics, for: second)

    let submission = try runtime.runJointRootTransaction(joint)
    XCTAssertEqual(submission.attemptedSubsteps, 3)
    XCTAssertEqual(submission.acceptedSubsteps, 2)
    XCTAssertEqual(submission.schedulerHostInputEventCount, 1)
    XCTAssertTrue(runtime.hasPendingRootTransaction)
    XCTAssertTrue(runtime.hasPendingJointTransaction)
    XCTAssertThrowsError(try runtime.commitRootTransaction())

    let commit = try runtime.commitJointRootTransaction()
    XCTAssertFalse(runtime.hasPendingRootTransaction)
    XCTAssertFalse(runtime.hasPendingJointTransaction)
    XCTAssertEqual(commit.transactionFingerprint, joint.token.fingerprint)
    XCTAssertEqual(commit.acceptedPhysicsTokenFingerprint, secondPhysics.fingerprint)
    XCTAssertEqual(commit.brainGeneration, 1)
    XCTAssertEqual(commit.physicsGeneration, 102)
    XCTAssertEqual(commit.committedTimestamp, BrainTimestamp(microseconds: 2_000))
    XCTAssertEqual(runtime.schedulerCommittedGeneration, commit.brainGeneration)
    XCTAssertEqual(runtime.schedulerCommittedTimestamp, commit.committedTimestamp)
    XCTAssertEqual(runtime.committedStep, 2)
    let scheduler = try runtime.inspectCommittedScheduler()
    XCTAssertTrue(
      scheduler.invocations.contains(where: {
        $0.interruptMask.contains(.lossOfSupport)
      })
    )
    XCTAssertFalse(
      scheduler.invocations.contains(where: { $0.interruptMask.contains(.pain) })
    )

    var next = try runtime.beginJointControl(
      controlStepIdentifier: 5,
      basePhysicsGeneration: commit.physicsGeneration,
      committedTimestamp: commit.committedTimestamp,
      targetTimestamp: BrainTimestamp(microseconds: 3_000)
    )
    XCTAssertEqual(next.token.baseBrainGeneration, commit.brainGeneration)
    XCTAssertEqual(next.token.randomCounterGeneration, 2)
    let nextSubstep = try next.beginPhysicsSubstep(durationMicroseconds: 1_000)
    let nextPhysics = try AcceptedPhysicsStateToken(
      transaction: next.token,
      substep: nextSubstep,
      physicsStateFingerprint: 0xabc3,
      physicsGeneration: 103
    )
    try next.acceptPhysicsSubstep(nextPhysics, for: nextSubstep)
    _ = try runtime.runJointRootTransaction(next)
    let nextCommit = try runtime.commitJointRootTransaction()
    XCTAssertEqual(nextCommit.brainGeneration, 2)
    XCTAssertEqual(nextCommit.physicsGeneration, 103)
    XCTAssertEqual(runtime.schedulerCommittedGeneration, 2)
    XCTAssertEqual(runtime.committedStep, 3)
  }

  func testJointMetalAbortPublishesNoBrainHistory() throws {
    try requireMetal4()
    let runtime = try makeRuntime(maxEncodedSubsteps: 1)
    let before = try runtime.snapshotCommitted().stableHash()
    let beforeProtective = try runtime.snapshotCommittedProtectiveCommand()
    let beforeProtectiveMotor = try runtime.snapshotCommittedProtectiveMotorOutput()
    var joint = try runtime.beginJointControl(
      controlStepIdentifier: 4,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 1_000)
    )
    let substep = try joint.beginPhysicsSubstep(durationMicroseconds: 1_000)
    let physics = try AcceptedPhysicsStateToken(
      transaction: joint.token,
      substep: substep,
      physicsStateFingerprint: 0xabc1,
      physicsGeneration: 101
    )
    try joint.acceptPhysicsSubstep(physics, for: substep)
    _ = try runtime.runJointRootTransaction(joint)
    try runtime.abortRootTransaction()

    XCTAssertFalse(runtime.hasPendingRootTransaction)
    XCTAssertFalse(runtime.hasPendingJointTransaction)
    XCTAssertEqual(runtime.committedStep, 0)
    XCTAssertEqual(runtime.schedulerCommittedGeneration, 0)
    XCTAssertNil(runtime.schedulerCommittedTimestamp)
    XCTAssertEqual(try runtime.snapshotCommitted().stableHash(), before)

    let acceptedAbortToken = try runtime.beginInteractiveJointControl(
      controlStepIdentifier: 5,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 2_000)
    )
    let acceptedCandidate = try runtime.advanceFastSystems(
      candidateDurationMicroseconds: 1_000
    )
    let acceptedPhysics = try AcceptedPhysicsStateToken(
      transaction: acceptedAbortToken,
      substep: acceptedCandidate.substep,
      physicsStateFingerprint: 0xabc1,
      physicsGeneration: 101
    )
    let acceptedPain = try BrainInterruptEvent(
      timestamp: BrainTimestamp(microseconds: 750),
      mask: .pain,
      identifier: 929,
      flags: UInt32(NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED)
    )
    try runtime.acceptPhysicsSubstep(
      acceptedPhysics,
      for: acceptedCandidate.substep,
      receptorEvents: [acceptedPain]
    )
    let shadowProtective = try runtime.snapshotInteractiveProtectiveCommand()
    let shadowProtectiveMotor = try runtime.snapshotInteractiveProtectiveMotorOutput()
    XCTAssertTrue(shadowProtective.flags.contains(.emergencyStop))
    XCTAssertTrue(shadowProtective.flags.contains(.withdrawal))
    XCTAssertNotEqual(shadowProtective, beforeProtective)
    XCTAssertNotEqual(shadowProtectiveMotor, beforeProtectiveMotor)
    try runtime.abortInteractiveJointControl()

    XCTAssertFalse(runtime.hasOpenInteractiveJointControl)
    XCTAssertEqual(runtime.committedStep, 0)
    XCTAssertEqual(runtime.schedulerCommittedGeneration, 0)
    XCTAssertNil(runtime.schedulerCommittedTimestamp)
    XCTAssertEqual(try runtime.snapshotCommitted().stableHash(), before)
    XCTAssertEqual(try runtime.snapshotCommittedProtectiveCommand(), beforeProtective)
    XCTAssertEqual(
      try runtime.snapshotCommittedProtectiveMotorOutput(),
      beforeProtectiveMotor
    )

    _ = try runtime.beginInteractiveJointControl(
      controlStepIdentifier: 6,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 500)
    )
    XCTAssertThrowsError(
      try runtime.advanceFastSystems(candidateDurationMicroseconds: 1_000)
    )
    try runtime.abortInteractiveJointControl()
    XCTAssertEqual(try runtime.snapshotCommitted().stableHash(), before)
  }

  func testInteractiveJointCandidatesMatchBatchedLedgerExactly() throws {
    try requireMetal4()
    let batched = try makeRuntime(maxEncodedSubsteps: 3)
    let interactive = try makeRuntime(maxEncodedSubsteps: 3)
    let committed = BrainTimestamp(microseconds: 0)
    let target = BrainTimestamp(microseconds: 2_000)
    let rejectedPain = try BrainInterruptEvent(
      timestamp: BrainTimestamp(microseconds: 500),
      mask: .pain,
      identifier: 900,
      flags: UInt32(NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED)
    )
    let acceptedSupportLoss = try BrainInterruptEvent(
      timestamp: BrainTimestamp(microseconds: 750),
      mask: .lossOfSupport,
      identifier: 901,
      flags: UInt32(NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED)
    )

    var batchedJoint = try batched.beginJointControl(
      controlStepIdentifier: 4,
      basePhysicsGeneration: 100,
      committedTimestamp: committed,
      targetTimestamp: target
    )
    let batchedRejected = try batchedJoint.beginPhysicsSubstep(
      durationMicroseconds: 1_000
    )
    try batchedJoint.rejectPhysicsSubstep(
      batchedRejected,
      receptorEvents: [rejectedPain]
    )
    let batchedRetry = try batchedJoint.beginPhysicsSubstep(durationMicroseconds: 1_000)
    let batchedFirstPhysics = try AcceptedPhysicsStateToken(
      transaction: batchedJoint.token,
      substep: batchedRetry,
      physicsStateFingerprint: 0xabc1,
      physicsGeneration: 101
    )
    try batchedJoint.acceptPhysicsSubstep(
      batchedFirstPhysics,
      for: batchedRetry,
      receptorEvents: [acceptedSupportLoss]
    )
    let batchedSecond = try batchedJoint.beginPhysicsSubstep(durationMicroseconds: 1_000)
    let batchedSecondPhysics = try AcceptedPhysicsStateToken(
      transaction: batchedJoint.token,
      substep: batchedSecond,
      physicsStateFingerprint: 0xabc2,
      physicsGeneration: 102
    )
    try batchedJoint.acceptPhysicsSubstep(batchedSecondPhysics, for: batchedSecond)
    let batchedSubmission = try batched.runJointRootTransaction(batchedJoint)
    let batchedCommit = try batched.commitJointRootTransaction()

    let interactiveToken = try interactive.beginInteractiveJointControl(
      controlStepIdentifier: 4,
      basePhysicsGeneration: 100,
      committedTimestamp: committed,
      targetTimestamp: target
    )
    XCTAssertEqual(interactiveToken, batchedJoint.token)
    let rejectedCandidate = try interactive.advanceFastSystems(
      candidateDurationMicroseconds: 1_000
    )
    XCTAssertEqual(rejectedCandidate.substep, batchedRejected)
    try interactive.rejectPhysicsSubstep(
      rejectedCandidate.substep,
      receptorEvents: [rejectedPain]
    )
    let retryCandidate = try interactive.advanceFastSystems(
      candidateDurationMicroseconds: 1_000
    )
    XCTAssertEqual(retryCandidate.substep, batchedRetry)
    let interactiveFirstPhysics = try AcceptedPhysicsStateToken(
      transaction: interactiveToken,
      substep: retryCandidate.substep,
      physicsStateFingerprint: 0xabc1,
      physicsGeneration: 101
    )
    try interactive.acceptPhysicsSubstep(
      interactiveFirstPhysics,
      for: retryCandidate.substep,
      receptorEvents: [acceptedSupportLoss]
    )
    let secondCandidate = try interactive.advanceFastSystems(
      candidateDurationMicroseconds: 1_000
    )
    XCTAssertEqual(secondCandidate.substep, batchedSecond)
    let interactiveSecondPhysics = try AcceptedPhysicsStateToken(
      transaction: interactiveToken,
      substep: secondCandidate.substep,
      physicsStateFingerprint: 0xabc2,
      physicsGeneration: 102
    )
    try interactive.acceptPhysicsSubstep(
      interactiveSecondPhysics,
      for: secondCandidate.substep
    )
    let interactiveSubmission = try interactive.finishInteractiveJointControl()
    XCTAssertFalse(interactive.hasOpenInteractiveJointControl)
    XCTAssertTrue(interactive.hasPendingRootTransaction)
    XCTAssertTrue(interactive.hasPendingJointTransaction)
    let interactiveCommit = try interactive.commitJointRootTransaction()

    XCTAssertEqual(interactiveSubmission.attemptedSubsteps, 3)
    XCTAssertEqual(interactiveSubmission.acceptedSubsteps, 2)
    XCTAssertEqual(interactiveSubmission.eventCompactionDispatches, 3)
    XCTAssertEqual(interactiveSubmission.schedulerHostInputEventCount, 1)
    XCTAssertGreaterThanOrEqual(
      interactiveSubmission.gpuEndSeconds,
      interactiveSubmission.gpuStartSeconds
    )
    XCTAssertEqual(interactiveCommit, batchedCommit)
    XCTAssertEqual(interactiveSubmission.attemptedSubsteps, batchedSubmission.attemptedSubsteps)
    XCTAssertEqual(interactiveSubmission.acceptedSubsteps, batchedSubmission.acceptedSubsteps)
    XCTAssertEqual(
      try interactive.snapshotCommitted().stableHash(),
      try batched.snapshotCommitted().stableHash()
    )
    XCTAssertEqual(
      try interactive.inspectCommittedScheduler(),
      try batched.inspectCommittedScheduler()
    )
    XCTAssertEqual(
      try interactive.snapshotCommittedRegionalState().stableHash(),
      try batched.snapshotCommittedRegionalState().stableHash()
    )
    XCTAssertEqual(
      try interactive.snapshotCommittedRegionalTokens().stableHash(),
      try batched.snapshotCommittedRegionalTokens().stableHash()
    )
    XCTAssertEqual(
      try interactive.snapshotCommittedRegionalRouteHistory().stableHash(),
      try batched.snapshotCommittedRegionalRouteHistory().stableHash()
    )
    XCTAssertEqual(
      try interactive.snapshotCommittedRegionalRoutingState().stableHash(),
      try batched.snapshotCommittedRegionalRoutingState().stableHash()
    )
  }

  func testInteractiveAbortAndInvalidDurationPublishNothing() throws {
    try requireMetal4()
    let runtime = try makeRuntime(maxEncodedSubsteps: 2)
    let before = try runtime.snapshotCommitted().stableHash()
    _ = try runtime.beginInteractiveJointControl(
      controlStepIdentifier: 4,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 1_000)
    )
    XCTAssertThrowsError(
      try runtime.advanceFastSystems(candidateDurationMicroseconds: 0)
    )
    XCTAssertThrowsError(
      try runtime.advanceFastSystems(candidateDurationMicroseconds: 1_001)
    )
    let candidate = try runtime.advanceFastSystems(candidateDurationMicroseconds: 500)
    XCTAssertTrue(runtime.hasOpenInteractiveJointControl)
    XCTAssertThrowsError(try runtime.finishInteractiveJointControl())
    XCTAssertThrowsError(
      try runtime.runRootTransaction(at: 0, acceptedSubsteps: [true])
    )
    XCTAssertEqual(candidate.substep.startTimestamp, BrainTimestamp(microseconds: 0))
    try runtime.abortInteractiveJointControl()

    XCTAssertFalse(runtime.hasOpenInteractiveJointControl)
    XCTAssertFalse(runtime.hasPendingRootTransaction)
    XCTAssertFalse(runtime.hasPendingJointTransaction)
    XCTAssertEqual(runtime.committedStep, 0)
    XCTAssertEqual(runtime.schedulerCommittedGeneration, 0)
    XCTAssertNil(runtime.schedulerCommittedTimestamp)
    XCTAssertEqual(try runtime.snapshotCommitted().stableHash(), before)
  }

  func testAcceptedSubstepInterruptAdvancesFastRegionalShadowBeforeRootFinish() throws {
    try requireMetal4()
    let runtime = try makeRuntime(maxEncodedSubsteps: 3)
    let token = try runtime.beginInteractiveJointControl(
      controlStepIdentifier: 8,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 2_000)
    )
    let supportLoss = try BrainInterruptEvent(
      timestamp: BrainTimestamp(microseconds: 750),
      mask: .lossOfSupport,
      identifier: 930,
      flags: UInt32(NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED)
    )
    let firstCandidate = try runtime.advanceFastSystems(
      candidateDurationMicroseconds: 1_000
    )
    XCTAssertEqual(firstCandidate.protectiveCommand.timestamp, BrainTimestamp(microseconds: 0))
    XCTAssertEqual(firstCandidate.protectiveCommand.brainGeneration, 0)
    XCTAssertNotEqual(firstCandidate.protectiveCommand.gpuAddress, 0)
    XCTAssertEqual(firstCandidate.protectiveMotorOutput.timestamp, BrainTimestamp(microseconds: 0))
    XCTAssertEqual(firstCandidate.protectiveMotorOutput.brainGeneration, 0)
    XCTAssertEqual(firstCandidate.protectiveMotorOutput.muscleCount, 6)
    XCTAssertEqual(firstCandidate.protectiveMotorOutput.headerByteCount, 64)
    XCTAssertEqual(firstCandidate.protectiveMotorOutput.muscleExcitationByteCount, 24)
    XCTAssertEqual(
      firstCandidate.protectiveMotorOutput.profileFingerprint,
      runtime.protectiveMotorProfile.fingerprint
    )
    XCTAssertNotEqual(firstCandidate.protectiveMotorOutput.headerGPUAddress, 0)
    XCTAssertNotEqual(firstCandidate.protectiveMotorOutput.muscleExcitationGPUAddress, 0)
    XCTAssertEqual(nb_brain_abi_numanx_motor_candidate_size(), 96)
    XCTAssertEqual(MemoryLayout<NBNumanXMotorCandidate>.stride, 96)
    let firstNumanXMotorCandidate = try NumanXMotorCandidate(
      transaction: token,
      fastSystems: firstCandidate
    )
    XCTAssertEqual(firstNumanXMotorCandidate.acceptedBrainTimestamp, .init(microseconds: 0))
    XCTAssertEqual(firstNumanXMotorCandidate.brainGeneration, token.baseBrainGeneration)
    XCTAssertEqual(
      firstNumanXMotorCandidate.motorOutputHeaderGPUAddress,
      firstCandidate.protectiveMotorOutput.headerGPUAddress
    )
    XCTAssertEqual(
      firstNumanXMotorCandidate.muscleExcitationGPUAddress,
      firstCandidate.protectiveMotorOutput.muscleExcitationGPUAddress
    )
    let firstMotorLease = try runtime.borrowNumanXMotorBuffers(for: firstCandidate)
    XCTAssertEqual(firstMotorLease.output, firstCandidate.protectiveMotorOutput)
    let borrowedHeaderObject = Unmanaged<AnyObject>.fromOpaque(
      firstMotorLease.headerMetalBufferObject
    ).takeUnretainedValue()
    let borrowedExcitationObject = Unmanaged<AnyObject>.fromOpaque(
      firstMotorLease.excitationMetalBufferObject
    ).takeUnretainedValue()
    let borrowedHeader = try XCTUnwrap(borrowedHeaderObject as? any MTLBuffer)
    let borrowedExcitations = try XCTUnwrap(
      borrowedExcitationObject as? any MTLBuffer
    )
    XCTAssertEqual(
      borrowedHeader.gpuAddress,
      firstNumanXMotorCandidate.motorOutputHeaderGPUAddress
    )
    XCTAssertEqual(
      borrowedExcitations.gpuAddress,
      firstNumanXMotorCandidate.muscleExcitationGPUAddress
    )
    XCTAssertGreaterThanOrEqual(
      borrowedExcitations.length,
      Int(firstNumanXMotorCandidate.muscleExcitationByteCount)
    )
    XCTAssertEqual(
      firstNumanXMotorCandidate,
      try NumanXMotorCandidate(
        validating: firstNumanXMotorCandidate.abiRecord,
        transaction: token,
        substep: firstCandidate.substep
      )
    )
    var invalidNumanXMotorCandidate = firstNumanXMotorCandidate.abiRecord
    invalidNumanXMotorCandidate.muscle_excitation_gpu_address = 0
    invalidNumanXMotorCandidate.candidate_fingerprint = withUnsafePointer(
      to: &invalidNumanXMotorCandidate
    ) {
      nb_brain_abi_numanx_motor_candidate_fingerprint($0)
    }
    XCTAssertThrowsError(
      try NumanXMotorCandidate(
        validating: invalidNumanXMotorCandidate,
        transaction: token,
        substep: firstCandidate.substep
      )
    )
    let firstPhysics = try AcceptedPhysicsStateToken(
      transaction: token,
      substep: firstCandidate.substep,
      physicsStateFingerprint: 0xf001,
      physicsGeneration: 101
    )
    try runtime.acceptPhysicsSubstep(
      firstPhysics,
      for: firstCandidate.substep,
      receptorEvents: [supportLoss]
    )
    XCTAssertThrowsError(
      try runtime.borrowNumanXMotorBuffers(for: firstCandidate)
    )

    let firstFastScheduler = try runtime.inspectInteractiveFastScheduler()
    let firstFastRegional = try runtime.snapshotInteractiveFastRegionalState()
    let firstProtective = try runtime.snapshotInteractiveProtectiveCommand()
    let firstProtectiveMotor = try runtime.snapshotInteractiveProtectiveMotorOutput()
    XCTAssertEqual(
      firstFastScheduler.snapshot.committedTime,
      BrainTimestamp(microseconds: 1_000)
    )
    XCTAssertEqual(firstFastScheduler.snapshot.generation, token.shadowGeneration)
    XCTAssertTrue(
      firstFastScheduler.invocations.contains(where: {
        $0.timestamp == supportLoss.timestamp
          && $0.moduleIdentifier == 26
          && $0.reasons.contains(.interrupt)
          && $0.interruptMask == .lossOfSupport
      })
    )
    let emergencyBusIndex = try XCTUnwrap(
      runtime.brainSchedule.modules.firstIndex(where: { $0.moduleIdentifier == 26 })
    )
    XCTAssertEqual(firstFastRegional.states[emergencyBusIndex].interruptCount, 1)
    XCTAssertEqual(firstProtective.interruptMask, .lossOfSupport)
    XCTAssertEqual(
      firstProtective.flags,
      [
        .valid, .emergencyStop, .posturalBrace, .autonomicArousal,
      ])
    XCTAssertEqual(firstProtective.withdrawalDrive, 0)
    XCTAssertEqual(firstProtective.posturalStiffness, 0.75)
    XCTAssertEqual(firstProtective.motorInhibition, 1)
    XCTAssertEqual(firstProtective.autonomicArousal, 0.5)
    XCTAssertEqual(
      firstProtective,
      try ProtectiveMotorCommand.reference(
        timestamp: BrainTimestamp(microseconds: 1_000),
        brainGeneration: token.shadowGeneration,
        environmentIdentifier: runtime.schedulerEnvironmentIdentifier,
        schedule: runtime.brainSchedule,
        invocations: firstFastScheduler.invocations,
        regionalStates: firstFastRegional.states
      )
    )
    XCTAssertEqual(
      firstProtectiveMotor,
      try ProtectiveMotorOutput.reference(
        command: firstProtective,
        profile: runtime.protectiveMotorProfile
      )
    )

    let rejectedPain = try BrainInterruptEvent(
      timestamp: BrainTimestamp(microseconds: 1_500),
      mask: .pain,
      identifier: 931,
      flags: UInt32(NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED)
    )
    let rejectedCandidate = try runtime.advanceFastSystems(
      candidateDurationMicroseconds: 1_000
    )
    XCTAssertEqual(
      rejectedCandidate.protectiveCommand.timestamp,
      BrainTimestamp(microseconds: 1_000)
    )
    XCTAssertEqual(rejectedCandidate.protectiveCommand.brainGeneration, token.shadowGeneration)
    XCTAssertNotEqual(
      rejectedCandidate.protectiveCommand.gpuAddress,
      firstCandidate.protectiveCommand.gpuAddress
    )
    XCTAssertEqual(
      rejectedCandidate.protectiveMotorOutput.timestamp,
      BrainTimestamp(microseconds: 1_000)
    )
    XCTAssertEqual(
      rejectedCandidate.protectiveMotorOutput.brainGeneration,
      token.shadowGeneration
    )
    XCTAssertNotEqual(
      rejectedCandidate.protectiveMotorOutput.headerGPUAddress,
      firstCandidate.protectiveMotorOutput.headerGPUAddress
    )
    XCTAssertNotEqual(
      rejectedCandidate.protectiveMotorOutput.muscleExcitationGPUAddress,
      firstCandidate.protectiveMotorOutput.muscleExcitationGPUAddress
    )
    let nextNumanXMotorCandidate = try NumanXMotorCandidate(
      transaction: token,
      fastSystems: rejectedCandidate
    )
    XCTAssertEqual(
      nextNumanXMotorCandidate.acceptedBrainTimestamp,
      BrainTimestamp(microseconds: 1_000)
    )
    XCTAssertEqual(nextNumanXMotorCandidate.brainGeneration, token.shadowGeneration)
    try runtime.rejectPhysicsSubstep(
      rejectedCandidate.substep,
      receptorEvents: [rejectedPain]
    )
    XCTAssertEqual(try runtime.inspectInteractiveFastScheduler(), firstFastScheduler)
    XCTAssertEqual(
      try runtime.snapshotInteractiveFastRegionalState(),
      firstFastRegional
    )
    XCTAssertEqual(try runtime.snapshotInteractiveProtectiveCommand(), firstProtective)
    XCTAssertEqual(
      try runtime.snapshotInteractiveProtectiveMotorOutput(),
      firstProtectiveMotor
    )

    let retryCandidate = try runtime.advanceFastSystems(candidateDurationMicroseconds: 1_000)
    let secondPhysics = try AcceptedPhysicsStateToken(
      transaction: token,
      substep: retryCandidate.substep,
      physicsStateFingerprint: 0xf002,
      physicsGeneration: 102
    )
    try runtime.acceptPhysicsSubstep(secondPhysics, for: retryCandidate.substep)
    let finalFastScheduler = try runtime.inspectInteractiveFastScheduler()
    let finalFastRegional = try runtime.snapshotInteractiveFastRegionalState()
    let finalProtective = try runtime.snapshotInteractiveProtectiveCommand()
    let finalProtectiveMotor = try runtime.snapshotInteractiveProtectiveMotorOutput()
    XCTAssertEqual(
      finalFastScheduler.snapshot.committedTime,
      BrainTimestamp(microseconds: 2_000)
    )
    XCTAssertTrue(
      finalFastScheduler.invocations.contains(where: {
        $0.interruptMask.contains(.lossOfSupport)
      })
    )
    XCTAssertFalse(
      finalFastScheduler.invocations.contains(where: { $0.interruptMask.contains(.pain) })
    )
    XCTAssertEqual(finalFastRegional.states[emergencyBusIndex].interruptCount, 1)
    XCTAssertEqual(
      finalProtective,
      try ProtectiveMotorCommand.reference(
        timestamp: BrainTimestamp(microseconds: 2_000),
        brainGeneration: token.shadowGeneration,
        environmentIdentifier: runtime.schedulerEnvironmentIdentifier,
        schedule: runtime.brainSchedule,
        invocations: finalFastScheduler.invocations,
        regionalStates: finalFastRegional.states
      )
    )
    XCTAssertEqual(
      finalProtectiveMotor,
      try ProtectiveMotorOutput.reference(
        command: finalProtective,
        profile: runtime.protectiveMotorProfile
      )
    )

    let submission = try runtime.finishInteractiveJointControl()
    XCTAssertEqual(submission.schedulerDispatches, 2)
    XCTAssertEqual(submission.regionalDispatches, 2)
    XCTAssertEqual(submission.protectiveDispatches, 2)
    XCTAssertEqual(submission.protectiveMotorDispatches, 2)
    _ = try runtime.commitJointRootTransaction()
    XCTAssertEqual(try runtime.inspectCommittedScheduler(), finalFastScheduler)
    XCTAssertEqual(try runtime.snapshotCommittedRegionalState(), finalFastRegional)
    XCTAssertEqual(try runtime.snapshotCommittedProtectiveCommand(), finalProtective)
    XCTAssertEqual(
      try runtime.snapshotCommittedProtectiveMotorOutput(),
      finalProtectiveMotor
    )
  }

  func testJointMetalBindingAcceptsCorrectedDurationAndRejectsStaleGeneration() throws {
    try requireMetal4()
    let runtime = try makeRuntime(maxEncodedSubsteps: 2)
    var joint = try runtime.beginJointControl(
      controlStepIdentifier: 4,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 1_000)
    )
    for index in 0..<2 {
      let substep = try joint.beginPhysicsSubstep(durationMicroseconds: 500)
      let physics = try AcceptedPhysicsStateToken(
        transaction: joint.token,
        substep: substep,
        physicsStateFingerprint: 0xabc1 + UInt64(index),
        physicsGeneration: 101 + UInt64(index)
      )
      try joint.acceptPhysicsSubstep(physics, for: substep)
    }
    let variableSubmission = try runtime.runJointRootTransaction(joint)
    XCTAssertEqual(variableSubmission.attemptedSubsteps, 2)
    XCTAssertEqual(variableSubmission.acceptedSubsteps, 2)
    let variableCommit = try runtime.commitJointRootTransaction()
    XCTAssertEqual(variableCommit.committedTimestamp, BrainTimestamp(microseconds: 1_000))
    XCTAssertEqual(runtime.committedStep, 2)

    let stale = try BrainJointTransactionToken(
      environmentIdentifier: 7,
      episodeIdentifier: 23,
      controlStepIdentifier: 5,
      parameterVersionFingerprint: runtime.parameterVersion.fingerprint,
      baseBrainGeneration: 0,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 1_000),
      randomCounterGeneration: 0
    )
    var staleJoint = BrainJointTransaction(token: stale)
    let substep = try staleJoint.beginPhysicsSubstep(durationMicroseconds: 1_000)
    let physics = try AcceptedPhysicsStateToken(
      transaction: stale,
      substep: substep,
      physicsStateFingerprint: 0xabc1,
      physicsGeneration: 101
    )
    try staleJoint.acceptPhysicsSubstep(physics, for: substep)
    XCTAssertThrowsError(try runtime.runJointRootTransaction(staleJoint))
    XCTAssertFalse(runtime.hasPendingRootTransaction)
  }

  func testCorrectedDurationInteractiveRelayMatchesCPUAndRetryExactly() throws {
    try requireMetal4()
    let (direct, directCPU) = try makeVariableDurationRuntimes()
    let (retried, _) = try makeVariableDurationRuntimes()
    var cpu = directCPU
    let target = BrainTimestamp(microseconds: 2_250)

    func runMetal(
      _ runtime: MetalTissueRuntime,
      rejectFirst: Bool
    ) throws -> MetalTissueRuntime.Submission {
      let token = try runtime.beginInteractiveJointControl(
        controlStepIdentifier: 9,
        basePhysicsGeneration: 200,
        committedTimestamp: BrainTimestamp(microseconds: 0),
        targetTimestamp: target
      )
      var physicsGeneration: UInt64 = 200
      if rejectFirst {
        let rejected = try runtime.advanceFastSystems(candidateDurationMicroseconds: 750)
        try runtime.rejectPhysicsSubstep(rejected.substep)
      }
      for fingerprint in [0xdef1, 0xdef2, 0xdef3] as [UInt64] {
        let candidate = try runtime.advanceFastSystems(candidateDurationMicroseconds: 750)
        physicsGeneration += 1
        let accepted = try AcceptedPhysicsStateToken(
          transaction: token,
          substep: candidate.substep,
          physicsStateFingerprint: fingerprint,
          physicsGeneration: physicsGeneration
        )
        try runtime.acceptPhysicsSubstep(accepted, for: candidate.substep)
      }
      let submission = try runtime.finishInteractiveJointControl()
      let commit = try runtime.commitJointRootTransaction()
      XCTAssertEqual(commit.committedTimestamp, target)
      XCTAssertEqual(commit.physicsGeneration, 203)
      return submission
    }

    let directSubmission = try runMetal(direct, rejectFirst: false)
    let retriedSubmission = try runMetal(retried, rejectFirst: true)
    try cpu.beginRootTransaction(at: 0)
    for _ in 0..<3 {
      try cpu.advanceCandidateSubstep(durationMicroseconds: 750)
      try cpu.acceptCandidateSubstep()
    }
    try cpu.commitRootTransaction()

    XCTAssertEqual(directSubmission.attemptedSubsteps, 3)
    XCTAssertEqual(retriedSubmission.attemptedSubsteps, 4)
    XCTAssertEqual(direct.committedStep, 3)
    XCTAssertEqual(retried.committedStep, 3)
    XCTAssertEqual(
      try direct.snapshotCommitted().stableHash(),
      try retried.snapshotCommitted().stableHash()
    )
    let directTimestamps = try direct.snapshotCommittedRelayHistoryTimestamps()
    XCTAssertEqual(
      directTimestamps,
      try retried.snapshotCommittedRelayHistoryTimestamps()
    )
    XCTAssertTrue(directTimestamps.contains(BrainTimestamp(microseconds: 750)))
    XCTAssertTrue(directTimestamps.contains(BrainTimestamp(microseconds: 1_500)))
    XCTAssertTrue(directTimestamps.contains(BrainTimestamp(microseconds: 2_250)))
    let metalState = try direct.snapshotCommitted()
    XCTAssertEqual(metalState.count, cpu.committed.count)
    for index in metalState.cells.indices {
      let metal = metalState.cells[index]
      let reference = cpu.committed.cells[index]
      XCTAssertEqual(metal.x, reference.x, accuracy: 2e-6)
      XCTAssertEqual(metal.y, reference.y, accuracy: 2e-6)
      XCTAssertEqual(metal.z, reference.z, accuracy: 2e-6)
      XCTAssertEqual(metal.w, reference.w, accuracy: 2e-6)
    }
  }

  func testCorrectedDurationHistoryCoverageFailsBeforeOverwrite() throws {
    try requireMetal4()
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 4,
      height: 4,
      parameters: parameters
    )
    let delayField = try TissueDelayField(
      width: 4,
      height: 4,
      repeating: UInt8(TissueDelayField.maximumDelaySteps)
    )
    let runtime = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      delayField: delayField,
      schedulerEnvironmentIdentifier: 0
    )
    let token = try runtime.beginInteractiveJointControl(
      controlStepIdentifier: 10,
      basePhysicsGeneration: 300,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 20_000)
    )
    for acceptedIndex in 1...31 {
      let candidate = try runtime.advanceFastSystems(candidateDurationMicroseconds: 500)
      let accepted = try AcceptedPhysicsStateToken(
        transaction: token,
        substep: candidate.substep,
        physicsStateFingerprint: UInt64(acceptedIndex),
        physicsGeneration: 300 + UInt64(acceptedIndex)
      )
      try runtime.acceptPhysicsSubstep(accepted, for: candidate.substep)
    }

    XCTAssertThrowsError(
      try runtime.advanceFastSystems(candidateDurationMicroseconds: 500)
    )
    try runtime.abortInteractiveJointControl()
    XCTAssertEqual(runtime.committedStep, 0)
    XCTAssertEqual(
      try runtime.snapshotCommittedRelayHistoryTimestamps(),
      Array(
        repeating: BrainTimestamp(microseconds: 0),
        count: TissueDelayField.historyCapacity
      )
    )
  }

  private func makeRuntime(maxEncodedSubsteps: Int) throws -> MetalTissueRuntime {
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 8,
      height: 8,
      parameters: parameters
    )
    return try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      randomContext: TissueRandomContext(
        seed: 0x4e55_4d49,
        environmentIdentifier: 7,
        episodeIdentifier: 23
      ),
      schedulerEnvironmentIdentifier: 7,
      maxEncodedSubsteps: maxEncodedSubsteps
    )
  }

  private func makeVariableDurationRuntimes() throws -> (
    MetalTissueRuntime,
    CPUTissueRuntime
  ) {
    let structure = try TissueStructure.homogeneous(width: 8, height: 8)
    let delayField = try TissueDelayField(width: 8, height: 8, repeating: 1)
    let initial = try CPUTissueDynamics.makeRestingGrid(
      parameters: parameters,
      structure: structure
    )
    let stimulus = TissueStimulus(
      radius: 0.35,
      excitatoryDrive: 6,
      startMilliseconds: 0,
      endMilliseconds: 5
    )
    let metal = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: delayField,
      schedulerEnvironmentIdentifier: 0,
      maxEncodedSubsteps: 4
    )
    let cpu = try CPUTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: delayField
    )
    return (metal, cpu)
  }

  private func requireMetal4() throws {
    guard MTLCreateSystemDefaultDevice() != nil else {
      throw XCTSkip("Metal device unavailable")
    }
  }
}

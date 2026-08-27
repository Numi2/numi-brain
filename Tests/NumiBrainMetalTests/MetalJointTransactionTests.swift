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
  }

  func testJointMetalBindingRejectsVariableDurationAndStaleGeneration() throws {
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
    XCTAssertThrowsError(try runtime.runJointRootTransaction(joint))
    XCTAssertFalse(runtime.hasPendingRootTransaction)

    let stale = try BrainJointTransactionToken(
      environmentIdentifier: 7,
      episodeIdentifier: 23,
      controlStepIdentifier: 5,
      parameterVersionFingerprint: runtime.parameterVersion.fingerprint,
      baseBrainGeneration: 1,
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

  private func requireMetal4() throws {
    guard MTLCreateSystemDefaultDevice() != nil else {
      throw XCTSkip("Metal device unavailable")
    }
  }
}

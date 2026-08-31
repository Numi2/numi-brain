import Metal
import XCTest

@testable import NumiBrainCore
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalSharedEventTimelineTests: XCTestCase {
  func testDecisionWaitSignalNeedsNoHostTicketCompletionAndRetainsInputs() throws {
    let fixture = try makeFixture()
    let transaction = try fixture.runtime.beginControl(
      jointToken: fixture.token,
      cachedDecisionFingerprint: 0xdec1_5100
    )
    var sensorPacket: NumanXSensorPacketLease? = try makeSensorPacket(
      fixture: fixture,
      acceptedPhysicsState: nil
    )
    weak var retainedPacket: NumanXSensorPacketLease?
    retainedPacket = sensorPacket
    let event = try XCTUnwrap(fixture.device.makeSharedEvent())
    let waitPoint = try MetalSharedEventPoint(event: event, value: 1)
    let completionPoint = try MetalSharedEventPoint(event: event, value: 2)

    let ticket = try fixture.runtime.submitInferAndDecide(
      transaction: transaction,
      numanXSensors: try XCTUnwrap(sensorPacket),
      regionalRecurrentInput: fixture.recurrentView,
      waitFor: waitPoint,
      signal: completionPoint
    )
    sensorPacket = nil

    XCTAssertEqual(transaction.status, .open)
    XCTAssertNotNil(retainedPacket)
    XCTAssertFalse(event.wait(untilSignaledValue: 2, timeoutMS: 20))
    XCTAssertNil(try ticket.completionFeedbackIfAvailable())

    event.signaledValue = 1
    XCTAssertTrue(event.wait(untilSignaledValue: 2, timeoutMS: 10_000))
    // The queue reaches the externally visible point without a ticket wait or
    // finish call. The owning runtime still retains the zero-copy input lease.
    XCTAssertNotNil(retainedPacket)
    let feedback = try ticket.waitUntilCompleted(timeoutMilliseconds: 10_000)
    XCTAssertGreaterThanOrEqual(feedback.gpuDurationSeconds, 0)
    XCTAssertNotEqual(ticket.decision.somaticOutputGPUAddress, 0)

    _ = try fixture.runtime.finishDecisionSubmission(
      ticket,
      transaction: transaction,
      timeoutMilliseconds: 10_000
    )
    XCTAssertNil(retainedPacket)
    XCTAssertNoThrow(
      try fixture.runtime.borrowNumanXSomaticBuffer(
        for: ticket.decision,
        transaction: transaction
      )
    )
    try transaction.abort()
  }

  func testCompleteRuntimeChainsDecisionToMotorWithoutAHostWait() throws {
    let fixture = try makeCompleteFixture(
      controlStepIdentifier: 19,
      cachedDecisionFingerprint: 0xdec1_5101
    )
    let sensors = try makeSensorPacket(
      device: fixture.device,
      compiled: fixture.compiled,
      token: fixture.transaction.token,
      acceptedPhysicsState: nil
    )
    let inputEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let timelineEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let inputReady = try MetalSharedEventPoint(event: inputEvent, value: 1)
    let decisionReady = try MetalSharedEventPoint(event: timelineEvent, value: 1)
    let motorReady = try MetalSharedEventPoint(event: timelineEvent, value: 2)

    let decisionTicket = try fixture.runtime.submitInferAndDecide(
      fixture.transaction,
      numanXSensors: sensors,
      waitFor: inputReady,
      signal: decisionReady
    )
    let motorTicket = try fixture.runtime.submitNumanXMotorCandidate(
      decisionTicket,
      transaction: fixture.transaction,
      candidateDurationMicroseconds: 1_000,
      signal: motorReady
    )

    XCTAssertEqual(fixture.transaction.status, .numanXMotorSubmitted)
    XCTAssertEqual(motorTicket.decisionReadyPoint.value, 1)
    XCTAssertEqual(motorTicket.motorReadyPoint.value, 2)
    XCTAssertTrue(
      (motorTicket.decisionReadyPoint.event as AnyObject)
        === (timelineEvent as AnyObject)
    )
    XCTAssertTrue(
      (motorTicket.motorReadyGate.readyPoint.event as AnyObject)
        === (timelineEvent as AnyObject)
    )
    XCTAssertTrue(motorTicket.candidate.usesDecisionShadow)
    XCTAssertEqual(
      motorTicket.candidate.brainGeneration,
      fixture.transaction.token.shadowGeneration
    )
    XCTAssertEqual(
      motorTicket.candidate.acceptedBrainTimestamp,
      fixture.transaction.token.committedTimestamp
    )
    XCTAssertNil(
      try fixture.runtime.reapNumanXMotorSubmissionIfCompleted(
        motorTicket,
        transaction: fixture.transaction
      )
    )
    XCTAssertFalse(timelineEvent.wait(untilSignaledValue: 2, timeoutMS: 20))

    inputEvent.signaledValue = 1
    XCTAssertTrue(timelineEvent.wait(untilSignaledValue: 2, timeoutMS: 10_000))
    let fast = try fixture.runtime.finishNumanXMotorSubmission(
      motorTicket,
      transaction: fixture.transaction,
      timeoutMilliseconds: 10_000
    )
    XCTAssertEqual(fast.substep, motorTicket.fastSystems.substep)
    XCTAssertEqual(fixture.transaction.status, .substepActive)
    XCTAssertTrue(motorTicket.hasCompleted)

    try fixture.runtime.rejectPhysicsSubstep(fixture.transaction)
    try fixture.runtime.abortControl(fixture.transaction)
    XCTAssertEqual(fixture.transaction.status, .aborted)
  }

  func testMotorPreflightFailurePreservesTheDecisionTicketForAbort() throws {
    let fixture = try makeCompleteFixture(
      controlStepIdentifier: 20,
      cachedDecisionFingerprint: 0xdec1_5102
    )
    let sensors = try makeSensorPacket(
      device: fixture.device,
      compiled: fixture.compiled,
      token: fixture.transaction.token,
      acceptedPhysicsState: nil
    )
    let inputEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let timelineEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let inputReady = try MetalSharedEventPoint(event: inputEvent, value: 1)
    let decisionReady = try MetalSharedEventPoint(event: timelineEvent, value: 1)
    let decisionTicket = try fixture.runtime.submitInferAndDecide(
      fixture.transaction,
      numanXSensors: sensors,
      waitFor: inputReady,
      signal: decisionReady
    )

    XCTAssertThrowsError(
      try fixture.runtime.submitNumanXMotorCandidate(
        decisionTicket,
        transaction: fixture.transaction,
        candidateDurationMicroseconds: 1_000,
        signal: decisionReady
      )
    )
    XCTAssertEqual(fixture.transaction.status, .decisionSubmitted)

    inputEvent.signaledValue = 1
    try fixture.runtime.abortInferAndDecideSubmission(
      decisionTicket,
      transaction: fixture.transaction,
      timeoutMilliseconds: 10_000
    )
    XCTAssertEqual(fixture.transaction.status, .aborted)
  }

  func testTimelineValidationTimeoutAndAbortPropagateWithoutPublishing() throws {
    let fixture = try makeFixture()
    let transaction = try fixture.runtime.beginControl(
      jointToken: fixture.token,
      cachedDecisionFingerprint: 0xfa11_0001
    )
    var sensors: NumanXSensorPacketLease? = try makeSensorPacket(
      fixture: fixture,
      acceptedPhysicsState: nil
    )
    weak var retainedSensors: NumanXSensorPacketLease?
    retainedSensors = sensors
    let event = try XCTUnwrap(fixture.device.makeSharedEvent())
    event.signaledValue = 5

    XCTAssertThrowsError(
      try fixture.runtime.submitInferAndDecide(
        transaction: transaction,
        numanXSensors: try XCTUnwrap(sensors),
        regionalRecurrentInput: fixture.recurrentView,
        waitFor: try MetalSharedEventPoint(event: event, value: 6),
        signal: try MetalSharedEventPoint(event: event, value: 6)
      )
    )
    XCTAssertEqual(transaction.status, .open)

    let ticket = try fixture.runtime.submitInferAndDecide(
      transaction: transaction,
      numanXSensors: try XCTUnwrap(sensors),
      regionalRecurrentInput: fixture.recurrentView,
      waitFor: try MetalSharedEventPoint(event: event, value: 10),
      signal: try MetalSharedEventPoint(event: event, value: 11)
    )
    sensors = nil

    XCTAssertThrowsError(
      try fixture.runtime.finishDecisionSubmission(
        ticket,
        transaction: transaction,
        timeoutMilliseconds: 10
      )
    )
    XCTAssertEqual(transaction.status, .open)
    XCTAssertNotNil(retainedSensors)
    XCTAssertEqual(fixture.runtime.agentStateRuntime.arena.committedGeneration, 0)

    XCTAssertThrowsError(
      try fixture.runtime.submitInferAndDecide(
        transaction: transaction,
        numanXSensors: try XCTUnwrap(retainedSensors),
        regionalRecurrentInput: fixture.recurrentView,
        signal: try MetalSharedEventPoint(event: event, value: 12)
      )
    )
    XCTAssertThrowsError(
      try fixture.runtime.abortDecisionSubmission(
        ticket,
        transaction: transaction,
        timeoutMilliseconds: 10
      )
    )
    XCTAssertEqual(transaction.status, .open)
    XCTAssertNotNil(retainedSensors)
    XCTAssertEqual(fixture.runtime.agentStateRuntime.arena.committedGeneration, 0)

    // An abort request is sticky: even if completion races in, this ticket can
    // never be converted back into an accepted decision.
    XCTAssertThrowsError(
      try fixture.runtime.finishDecisionSubmission(
        ticket,
        transaction: transaction,
        timeoutMilliseconds: 10
      )
    )

    event.signaledValue = 10
    XCTAssertTrue(event.wait(untilSignaledValue: 11, timeoutMS: 10_000))
    try fixture.runtime.abortDecisionSubmission(
      ticket,
      transaction: transaction,
      timeoutMilliseconds: 10_000
    )
    XCTAssertEqual(transaction.status, .aborted)
    XCTAssertNil(retainedSensors)
    XCTAssertEqual(fixture.runtime.agentStateRuntime.arena.committedGeneration, 0)
  }

  func testSharedEventCompatibilityAndSignalReservationAreRaceSafe() throws {
    let device = try requireMetal4Device()
    let event = try XCTUnwrap(device.makeSharedEvent())

    // Metal documents nil here for MTLSharedEvent because it is shareable.
    // Validation therefore proves queue-device compatibility by importing the
    // event handle through the exact device instead of accepting nil blindly.
    XCTAssertNil(event.device)
    let point = try MetalSharedEventPoint(event: event, value: 100)
    XCTAssertNoThrow(try point.validate(for: device))

    let successes = LockedCounter()
    DispatchQueue.concurrentPerform(iterations: 16) { _ in
      do {
        try MetalSharedEventPoint.validateProgression(
          wait: nil,
          signal: point,
          device: device
        )
        successes.increment()
      } catch {}
    }
    XCTAssertEqual(successes.value, 1)
    XCTAssertThrowsError(
      try MetalSharedEventPoint.validateProgression(
        wait: nil,
        signal: try MetalSharedEventPoint(event: event, value: 99),
        device: device
      )
    )
  }

  func testAcceptedConsequenceTimelineIsByteDeterministicAcrossFreshRuntimes() throws {
    let first = try runAcceptedRoot()
    let second = try runAcceptedRoot()

    XCTAssertEqual(first.hotState, second.hotState)
    XCTAssertEqual(first.persistentMemory, second.persistentMemory)
    XCTAssertEqual(first.generation, 1)
    XCTAssertEqual(second.generation, 1)
  }

  func testAcceptedPhysicsGatePendingAndWrongTokenMutateNoShadowBytes() throws {
    let pending = try runRejectedAcceptedPhysicsGate(.zero)
    let wrong = try runRejectedAcceptedPhysicsGate(.wrongToken)

    XCTAssertEqual(pending.generation, 0)
    XCTAssertEqual(wrong.generation, 0)
  }

  func testAcceptedPhysicsGateLateMutationAfterSubmitCannotPublish() throws {
    let result = try runRejectedAcceptedPhysicsGate(.lateZeroMutation)
    XCTAssertEqual(result.generation, 0)
  }

  func testAcceptedPhysicsGateCanBecomeAcceptedOnlyBeforeDependencySignal() throws {
    let prepared = try makePreparedAcceptedRoot()
    let gate = try makeAcceptedPhysicsGate(
      device: prepared.fixture.device,
      expected: prepared.accepted,
      observed: nil
    )
    let event = try XCTUnwrap(prepared.fixture.device.makeSharedEvent())
    let ticket = try prepared.fixture.runtime.submitAcceptedConsequence(
      transaction: prepared.transaction,
      acceptedPhysicsState: prepared.accepted,
      candidateSubstep: prepared.substep,
      acceptedPhysicsGate: gate,
      numanXSensors: prepared.acceptedSensors,
      acceptedRegionalRecurrentInput: prepared.fixture.recurrentView,
      waitFor: try MetalSharedEventPoint(event: event, value: 40),
      signal: try MetalSharedEventPoint(event: event, value: 41)
    )
    writeAcceptedPhysicsToken(prepared.accepted, to: gate.buffer)
    event.signaledValue = 40
    XCTAssertTrue(event.wait(untilSignaledValue: 41, timeoutMS: 10_000))
    XCTAssertNoThrow(
      try prepared.fixture.runtime.finishAcceptedConsequenceSubmission(
        ticket,
        transaction: prepared.transaction,
        acceptedPhysicsState: prepared.accepted,
        timeoutMilliseconds: 10_000
      )
    )
    XCTAssertEqual(prepared.transaction.status, .gpuStateFinished)
    XCTAssertEqual(
      prepared.fixture.runtime.agentStateRuntime.arena.committedGeneration,
      0
    )
    try prepared.fixture.runtime.abort(transaction: prepared.transaction)
  }

  func testAuthoritativeGPUTokenNeedsNoHostPhysicalDigestAtSubmit() throws {
    let prepared = try makePreparedAcceptedRoot()
    let gate = try makeAcceptedPhysicsGate(
      device: prepared.fixture.device,
      expected: prepared.accepted,
      observed: prepared.accepted
    )
    let event = try XCTUnwrap(prepared.fixture.device.makeSharedEvent())
    let ticket = try prepared.fixture.runtime.submitAcceptedConsequence(
      transaction: prepared.transaction,
      candidateSubstep: prepared.substep,
      acceptedPhysicsGate: gate,
      rawSensors: prepared.acceptedSensors.rawSensors,
      acceptedRegionalRecurrentInput: prepared.fixture.recurrentView,
      signal: try MetalSharedEventPoint(event: event, value: 61)
    )
    XCTAssertEqual(ticket.consequence.acceptedPhysicsTokenFingerprint, 0)
    XCTAssertEqual(ticket.acceptedPhysicsWitnessByteCount, 128)
    XCTAssertGreaterThan(ticket.acceptedPhysicsWitnessGPUAddress, 0)
    XCTAssertTrue(event.wait(untilSignaledValue: 61, timeoutMS: 10_000))

    let completion = try prepared.fixture.runtime
      .finishAcceptedConsequenceSubmission(
        ticket,
        transaction: prepared.transaction,
        timeoutMilliseconds: 10_000
      )
    XCTAssertEqual(completion.acceptedPhysicsState, prepared.accepted)
    XCTAssertEqual(
      completion.consequence.acceptedPhysicsTokenFingerprint,
      prepared.accepted.fingerprint
    )
    XCTAssertEqual(prepared.transaction.status, .gpuStateFinished)
    try prepared.fixture.runtime.abort(transaction: prepared.transaction)
  }

  func testAcceptedTimeoutQuarantinesGateUntilGPUActuallyCompletes() throws {
    let prepared = try makePreparedAcceptedRoot()
    var gate: MetalAcceptedPhysicsGateLease? = try makeAcceptedPhysicsGate(
      device: prepared.fixture.device,
      expected: prepared.accepted,
      observed: prepared.accepted
    )
    weak var retainedGate: MetalAcceptedPhysicsGateLease?
    retainedGate = gate
    let event = try XCTUnwrap(prepared.fixture.device.makeSharedEvent())
    let ticket = try prepared.fixture.runtime.submitAcceptedConsequence(
      transaction: prepared.transaction,
      candidateSubstep: prepared.substep,
      acceptedPhysicsGate: try XCTUnwrap(gate),
      rawSensors: prepared.acceptedSensors.rawSensors,
      acceptedRegionalRecurrentInput: prepared.fixture.recurrentView,
      waitFor: try MetalSharedEventPoint(event: event, value: 70),
      signal: try MetalSharedEventPoint(event: event, value: 71)
    )
    gate = nil

    XCTAssertThrowsError(
      try prepared.fixture.runtime.finishAcceptedConsequenceSubmission(
        ticket,
        transaction: prepared.transaction,
        timeoutMilliseconds: 10
      )
    )
    XCTAssertNotNil(retainedGate)
    XCTAssertEqual(prepared.transaction.status, .open)
    XCTAssertEqual(
      prepared.fixture.runtime.agentStateRuntime.arena.committedGeneration,
      0
    )
    XCTAssertThrowsError(
      try prepared.fixture.runtime.submitAcceptedConsequence(
        transaction: prepared.transaction,
        candidateSubstep: prepared.substep,
        acceptedPhysicsGate: try XCTUnwrap(retainedGate),
        rawSensors: prepared.acceptedSensors.rawSensors,
        acceptedRegionalRecurrentInput: prepared.fixture.recurrentView,
        signal: try MetalSharedEventPoint(event: event, value: 72)
      )
    )
    XCTAssertThrowsError(
      try prepared.fixture.runtime.abortAcceptedConsequenceSubmission(
        ticket,
        transaction: prepared.transaction,
        timeoutMilliseconds: 10
      )
    )
    XCTAssertNotNil(retainedGate)
    XCTAssertEqual(prepared.transaction.status, .open)
    XCTAssertThrowsError(
      try prepared.fixture.runtime.finishAcceptedConsequenceSubmission(
        ticket,
        transaction: prepared.transaction,
        timeoutMilliseconds: 10
      )
    )

    event.signaledValue = 70
    XCTAssertTrue(event.wait(untilSignaledValue: 71, timeoutMS: 10_000))
    try prepared.fixture.runtime.abortAcceptedConsequenceSubmission(
      ticket,
      transaction: prepared.transaction,
      timeoutMilliseconds: 10_000
    )
    XCTAssertNil(retainedGate)
    XCTAssertEqual(prepared.transaction.status, .aborted)
    XCTAssertEqual(
      prepared.fixture.runtime.agentStateRuntime.arena.committedGeneration,
      0
    )
  }

  func testCompleteRuntimePublishesOnlyAfterAsyncAcceptedTicketIsFinished() throws {
    let fixture = try makeCompleteFixture(
      controlStepIdentifier: 21,
      cachedDecisionFingerprint: 0x5eed_0021
    )
    let device = fixture.device
    let compiled = fixture.compiled
    let runtime = fixture.runtime
    let transaction = fixture.transaction
    let committedSensors = try makeSensorPacket(
      device: device,
      compiled: compiled,
      token: transaction.token,
      acceptedPhysicsState: nil
    )
    let event = try XCTUnwrap(device.makeSharedEvent())
    let decisionTicket = try runtime.submitInferAndDecide(
      transaction,
      numanXSensors: committedSensors,
      signal: try MetalSharedEventPoint(event: event, value: 1)
    )
    XCTAssertEqual(transaction.status, .decisionSubmitted)
    XCTAssertTrue(event.wait(untilSignaledValue: 1, timeoutMS: 10_000))
    _ = try runtime.finishInferAndDecideSubmission(
      decisionTicket,
      transaction: transaction,
      timeoutMilliseconds: 10_000
    )
    XCTAssertEqual(transaction.status, .decisionReady)

    let fast = try runtime.advanceFastSystems(
      transaction,
      candidateDurationMicroseconds: 1_000
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: transaction.token,
      substep: fast.substep,
      physicsStateFingerprint: 0xfeed_0021,
      physicsGeneration: 101
    )
    try runtime.acceptPhysicsSubstep(transaction, accepted: accepted)
    let acceptedSensors = try makeSensorPacket(
      device: device,
      compiled: compiled,
      token: transaction.token,
      acceptedPhysicsState: accepted
    )
    let commitTicket = try runtime.submitAcceptedControl(
      transaction,
      acceptedPhysicsGate: try makeAcceptedPhysicsGate(
        device: device,
        expected: accepted,
        observed: accepted
      ),
      acceptedSensors: acceptedSensors,
      waitFor: try MetalSharedEventPoint(event: event, value: 1),
      signal: try MetalSharedEventPoint(event: event, value: 2)
    )
    XCTAssertEqual(transaction.status, .acceptedConsequenceSubmitted)
    XCTAssertEqual(runtime.committedGeneration, 0)
    XCTAssertTrue(event.wait(untilSignaledValue: 2, timeoutMS: 10_000))
    XCTAssertEqual(runtime.committedGeneration, 0)

    let result = try runtime.finishAcceptedControlSubmission(
      commitTicket,
      transaction: transaction,
      timeoutMilliseconds: 10_000
    )
    XCTAssertEqual(result.receipt.brainGeneration, 1)
    XCTAssertEqual(result.receipt.physicsGeneration, 101)
    XCTAssertEqual(runtime.committedGeneration, 1)
    XCTAssertEqual(transaction.status, .committed)
  }

  func testExistingSynchronousCompleteRuntimePathStillCommits() throws {
    let fixture = try makeCompleteFixture(
      controlStepIdentifier: 22,
      cachedDecisionFingerprint: 0x5eed_0022
    )
    let transaction = fixture.transaction
    let committedSensors = try makeSensorPacket(
      device: fixture.device,
      compiled: fixture.compiled,
      token: transaction.token,
      acceptedPhysicsState: nil
    )

    let decision = try fixture.runtime.inferAndDecide(
      transaction,
      numanXSensors: committedSensors
    )
    XCTAssertEqual(transaction.status, .decisionReady)
    XCTAssertEqual(decision.transactionFingerprint, transaction.token.fingerprint)

    let fast = try fixture.runtime.advanceFastSystems(
      transaction,
      candidateDurationMicroseconds: 1_000
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: transaction.token,
      substep: fast.substep,
      physicsStateFingerprint: 0xfeed_0022,
      physicsGeneration: 101
    )
    try fixture.runtime.acceptPhysicsSubstep(transaction, accepted: accepted)
    let acceptedSensors = try makeSensorPacket(
      device: fixture.device,
      compiled: fixture.compiled,
      token: transaction.token,
      acceptedPhysicsState: accepted
    )

    let result = try fixture.runtime.commitControl(
      transaction,
      acceptedSensors: acceptedSensors
    )
    XCTAssertEqual(result.receipt.brainGeneration, 1)
    XCTAssertEqual(result.receipt.physicsGeneration, 101)
    XCTAssertEqual(fixture.runtime.committedGeneration, 1)
    XCTAssertEqual(transaction.status, .committed)
  }

  private func runAcceptedRoot() throws
    -> MetalAgentStateRuntime.CheckpointPayload
  {
    let fixture = try makeFixture()
    let transaction = try fixture.runtime.beginControl(
      jointToken: fixture.token,
      cachedDecisionFingerprint: 0x5eed_0001
    )
    let committedSensors = try makeSensorPacket(
      fixture: fixture,
      acceptedPhysicsState: nil
    )
    let event = try XCTUnwrap(fixture.device.makeSharedEvent())
    let decisionTicket = try fixture.runtime.submitInferAndDecide(
      transaction: transaction,
      numanXSensors: committedSensors,
      regionalRecurrentInput: fixture.recurrentView,
      signal: try MetalSharedEventPoint(event: event, value: 1)
    )
    XCTAssertTrue(event.wait(untilSignaledValue: 1, timeoutMS: 10_000))
    _ = try fixture.runtime.finishDecisionSubmission(
      decisionTicket,
      transaction: transaction,
      timeoutMilliseconds: 10_000
    )

    var physicalLedger = BrainJointTransaction(token: fixture.token)
    let substep = try physicalLedger.beginPhysicsSubstep(
      durationMicroseconds: fixture.token.targetTimestamp.rawValue
        - fixture.token.committedTimestamp.rawValue
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: fixture.token,
      substep: substep,
      physicsStateFingerprint: 0xfeed_0001,
      physicsGeneration: fixture.token.basePhysicsGeneration + 1
    )
    try physicalLedger.acceptPhysicsSubstep(accepted, for: substep)
    let acceptedSensors = try makeSensorPacket(
      fixture: fixture,
      acceptedPhysicsState: accepted
    )
    let consequenceTicket = try fixture.runtime.submitAcceptedConsequence(
      transaction: transaction,
      acceptedPhysicsState: accepted,
      candidateSubstep: substep,
      acceptedPhysicsGate: try makeAcceptedPhysicsGate(
        device: fixture.device,
        expected: accepted,
        observed: accepted
      ),
      numanXSensors: acceptedSensors,
      acceptedRegionalRecurrentInput: fixture.recurrentView,
      waitFor: try MetalSharedEventPoint(event: event, value: 1),
      signal: try MetalSharedEventPoint(event: event, value: 2)
    )

    XCTAssertEqual(transaction.status, .open)
    XCTAssertTrue(event.wait(untilSignaledValue: 2, timeoutMS: 10_000))
    XCTAssertEqual(transaction.status, .open)
    _ = try fixture.runtime.finishAcceptedConsequenceSubmission(
      consequenceTicket,
      transaction: transaction,
      acceptedPhysicsState: accepted,
      timeoutMilliseconds: 10_000
    )
    XCTAssertEqual(transaction.status, .gpuStateFinished)

    let receipt = try physicalLedger.commit()
    try fixture.runtime.commit(transaction: transaction, receipt: receipt)
    XCTAssertEqual(transaction.status, .committed)
    return try fixture.runtime.agentStateRuntime.snapshotCommittedState()
  }

  private enum RejectedGateMode: Equatable {
    case zero
    case wrongToken
    case lateZeroMutation
  }

  private struct PreparedAcceptedRoot {
    let fixture: Fixture
    let transaction: MetalJointAgentStateTransaction
    let substep: BrainJointSubstepToken
    let accepted: AcceptedPhysicsStateToken
    let acceptedSensors: NumanXSensorPacketLease
  }

  private func makePreparedAcceptedRoot() throws -> PreparedAcceptedRoot {
    let fixture = try makeFixture()
    let transaction = try fixture.runtime.beginControl(
      jointToken: fixture.token,
      cachedDecisionFingerprint: 0x6a7e_0001
    )
    let committedSensors = try makeSensorPacket(
      fixture: fixture,
      acceptedPhysicsState: nil
    )
    _ = try fixture.runtime.inferAndDecide(
      transaction: transaction,
      numanXSensors: committedSensors,
      regionalRecurrentInput: fixture.recurrentView
    )
    var physicalLedger = BrainJointTransaction(token: fixture.token)
    let substep = try physicalLedger.beginPhysicsSubstep(
      durationMicroseconds: fixture.token.targetTimestamp.rawValue
        - fixture.token.committedTimestamp.rawValue
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: fixture.token,
      substep: substep,
      physicsStateFingerprint: 0x6a7e_f001,
      physicsGeneration: fixture.token.basePhysicsGeneration + 1
    )
    try physicalLedger.acceptPhysicsSubstep(accepted, for: substep)
    let acceptedSensors = try makeSensorPacket(
      fixture: fixture,
      acceptedPhysicsState: accepted
    )
    return PreparedAcceptedRoot(
      fixture: fixture,
      transaction: transaction,
      substep: substep,
      accepted: accepted,
      acceptedSensors: acceptedSensors
    )
  }

  private func runRejectedAcceptedPhysicsGate(
    _ mode: RejectedGateMode
  ) throws -> MetalAgentStateRuntime.CheckpointPayload {
    let prepared = try makePreparedAcceptedRoot()
    let wrongToken = try AcceptedPhysicsStateToken(
      transaction: prepared.fixture.token,
      substep: prepared.substep,
      physicsStateFingerprint: prepared.accepted.physicsStateFingerprint ^ 0x55aa,
      physicsGeneration: prepared.accepted.physicsGeneration
    )
    let initiallyObserved: AcceptedPhysicsStateToken?
    switch mode {
    case .zero:
      initiallyObserved = nil
    case .wrongToken:
      initiallyObserved = wrongToken
    case .lateZeroMutation:
      initiallyObserved = prepared.accepted
    }
    let gate = try makeAcceptedPhysicsGate(
      device: prepared.fixture.device,
      expected: prepared.accepted,
      observed: initiallyObserved
    )
    if mode == .wrongToken {
      var invalid = wrongToken.abiRecord
      invalid.token_fingerprint ^= 1
      withUnsafeBytes(of: &invalid) { bytes in
        gate.buffer.contents().copyMemory(
          from: bytes.baseAddress!, byteCount: bytes.count
        )
      }
    }
    let arena = prepared.fixture.runtime.agentStateRuntime.arena
    let hotBuffer = try arena.borrowShadowHotBuffer(
      transaction: prepared.transaction.agentStateToken
    )
    let journalBuffer = try arena.borrowShadowJournalBuffer(
      transaction: prepared.transaction.agentStateToken
    )
    let hotBefore = try snapshot(
      buffer: hotBuffer,
      device: prepared.fixture.device
    )
    let journalBefore = try snapshot(
      buffer: journalBuffer,
      device: prepared.fixture.device
    )
    let event = try XCTUnwrap(prepared.fixture.device.makeSharedEvent())
    let ticket = try prepared.fixture.runtime.submitAcceptedConsequence(
      transaction: prepared.transaction,
      acceptedPhysicsState: prepared.accepted,
      candidateSubstep: prepared.substep,
      acceptedPhysicsGate: gate,
      numanXSensors: prepared.acceptedSensors,
      acceptedRegionalRecurrentInput: prepared.fixture.recurrentView,
      waitFor: try MetalSharedEventPoint(event: event, value: 50),
      signal: try MetalSharedEventPoint(event: event, value: 51)
    )
    if mode == .lateZeroMutation {
      gate.buffer.contents().initializeMemory(
        as: UInt8.self,
        repeating: 0,
        count: MetalAcceptedPhysicsGateLease.byteCount
      )
    }
    event.signaledValue = 50
    XCTAssertTrue(event.wait(untilSignaledValue: 51, timeoutMS: 10_000))
    XCTAssertEqual(
      try snapshot(buffer: hotBuffer, device: prepared.fixture.device),
      hotBefore
    )
    XCTAssertEqual(
      try snapshot(buffer: journalBuffer, device: prepared.fixture.device),
      journalBefore
    )
    XCTAssertThrowsError(
      try prepared.fixture.runtime.finishAcceptedConsequenceSubmission(
        ticket,
        transaction: prepared.transaction,
        acceptedPhysicsState: prepared.accepted,
        timeoutMilliseconds: 10_000
      )
    )
    XCTAssertEqual(prepared.transaction.status, .aborted)
    let committedAfter = try prepared.fixture.runtime.agentStateRuntime
      .snapshotCommittedState()
    XCTAssertEqual(committedAfter.generation, 0)
    return committedAfter
  }

  private struct Fixture {
    let device: any MTLDevice
    let compiled: CompiledSpeciesTemplate
    let runtime: MetalEmbodiedBrainRuntime
    let token: BrainJointTransactionToken
    let recurrentBuffer: any MTLBuffer
    let recurrentView: MetalRegionalRecurrentBufferView
  }

  private struct CompleteFixture {
    let device: any MTLDevice
    let compiled: CompiledSpeciesTemplate
    let runtime: MetalNumiBrainRuntime
    let transaction: MetalNumiBrainRuntime.ControlTransaction
  }

  private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
      lock.lock()
      defer { lock.unlock() }
      return count
    }

    func increment() {
      lock.lock()
      count += 1
      lock.unlock()
    }
  }

  private func makeCompleteFixture(
    controlStepIdentifier: UInt64,
    cachedDecisionFingerprint: UInt64
  ) throws -> CompleteFixture {
    let device = try requireMetal4Device()
    let compiled = try makeNumanXInteropCompiledTemplate()
    let parameters = TissueParameters.corticalSheetV0
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: compiled.species,
      tissueParameters: parameters
    )
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 8,
      height: 8,
      parameters: parameters
    )
    let configuration = MetalNumiBrainConfiguration(
      initialTissueState: initial,
      tissueParameters: parameters,
      tissueStimulus: .none,
      compiledSpeciesTemplate: compiled,
      randomContext: TissueRandomContext(
        seed: 0x4e55_4d49,
        environmentIdentifier: 7,
        episodeIdentifier: 23
      ),
      schedulerEnvironmentIdentifier: 7,
      maximumEncodedSubsteps: 1
    )
    let runtime = try MetalNumiBrainRuntime.makeRuntime(
      configuration: configuration,
      publication: publication,
      device: device
    )
    let transaction = try runtime.beginControl(
      controlStepIdentifier: controlStepIdentifier,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 10_000),
      targetTimestamp: BrainTimestamp(microseconds: 11_000),
      cachedDecisionFingerprint: cachedDecisionFingerprint
    )
    return CompleteFixture(
      device: device,
      compiled: compiled,
      runtime: runtime,
      transaction: transaction
    )
  }

  private func makeFixture() throws -> Fixture {
    let device = try requireMetal4Device()
    let compiled = try makeNumanXInteropCompiledTemplate()
    let parameters = TissueParameters.corticalSheetV0
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: compiled.species,
      tissueParameters: parameters
    )
    let regionalProgram = try compiled.species.regionalProgram()
    let runtime = try MetalEmbodiedBrainRuntime(
      device: device,
      compiledSpeciesTemplate: compiled,
      regionalProgram: regionalProgram,
      parameterVersion: publication.version,
      sharedParameterArtifact: publication.sharedArtifact
    )
    let token = try BrainJointTransactionToken(
      environmentIdentifier: 7,
      episodeIdentifier: 23,
      controlStepIdentifier: 17,
      parameterVersionFingerprint: publication.version.fingerprint,
      baseBrainGeneration: 0,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 10_000),
      targetTimestamp: BrainTimestamp(microseconds: 11_000),
      randomCounterGeneration: 0
    )
    guard let recurrentBuffer = device.makeBuffer(
      length: regionalProgram.scalarCount * MemoryLayout<Float>.stride,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ) else {
      throw TissueError.metal("failed to allocate recurrent test buffer")
    }
    recurrentBuffer.contents().initializeMemory(
      as: UInt8.self,
      repeating: 0,
      count: recurrentBuffer.length
    )
    let recurrentView = try MetalRegionalRecurrentBufferView(
      gpuAddress: recurrentBuffer.gpuAddress,
      scalarCount: regionalProgram.scalarCount,
      regionalProgramFingerprint: regionalProgram.fingerprint
    )
    return Fixture(
      device: device,
      compiled: compiled,
      runtime: runtime,
      token: token,
      recurrentBuffer: recurrentBuffer,
      recurrentView: recurrentView
    )
  }

  private func makeSensorPacket(
    fixture: Fixture,
    acceptedPhysicsState: AcceptedPhysicsStateToken?
  ) throws -> NumanXSensorPacketLease {
    try makeSensorPacket(
      device: fixture.device,
      compiled: fixture.compiled,
      token: fixture.token,
      acceptedPhysicsState: acceptedPhysicsState
    )
  }

  private func makeAcceptedPhysicsGate(
    device: any MTLDevice,
    expected: AcceptedPhysicsStateToken,
    observed: AcceptedPhysicsStateToken?
  ) throws -> MetalAcceptedPhysicsGateLease {
    guard let buffer = device.makeBuffer(
      length: MetalAcceptedPhysicsGateLease.byteCount,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ) else {
      throw TissueError.metal("failed to allocate accepted-physics test gate")
    }
    buffer.contents().initializeMemory(
      as: UInt8.self,
      repeating: 0,
      count: buffer.length
    )
    if let observed {
      var record = observed.abiRecord
      withUnsafeBytes(of: &record) { bytes in
        buffer.contents().copyMemory(
          from: bytes.baseAddress!, byteCount: bytes.count
        )
      }
    }
    _ = expected
    return try MetalAcceptedPhysicsGateLease(buffer: buffer)
  }

  private func writeAcceptedPhysicsToken(
    _ accepted: AcceptedPhysicsStateToken,
    to buffer: any MTLBuffer
  ) {
    var record = accepted.abiRecord
    withUnsafeBytes(of: &record) { bytes in
      buffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
  }

  private func snapshot(
    buffer: any MTLBuffer,
    device: any MTLDevice
  ) throws -> Data {
    guard let queue = device.makeCommandQueue(),
      let staging = device.makeBuffer(
        length: buffer.length,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let commandBuffer = queue.makeCommandBuffer(),
      let blit = commandBuffer.makeBlitCommandEncoder()
    else {
      throw TissueError.metal("failed to allocate test snapshot copy")
    }
    blit.copy(
      from: buffer,
      sourceOffset: 0,
      to: staging,
      destinationOffset: 0,
      size: buffer.length
    )
    blit.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    if let error = commandBuffer.error { throw error }
    return Data(bytes: staging.contents(), count: staging.length)
  }

  private func makeSensorPacket(
    device: any MTLDevice,
    compiled: CompiledSpeciesTemplate,
    token: BrainJointTransactionToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken?
  ) throws -> NumanXSensorPacketLease {
    let deliveryTimestamp = acceptedPhysicsState?.acceptedTimestamp
      ?? token.committedTimestamp
    let rawSensors = try compiled.species.senses.filter(\.enabled)
      .enumerated().map { sensorIndex, topology in
        let scalarCount = Int(topology.receptorCount)
          * Int(topology.observationDimension)
        guard let buffer = device.makeBuffer(
          length: scalarCount * MemoryLayout<Float>.stride,
          options: [.storageModeShared, .hazardTrackingModeTracked]
        ) else {
          throw TissueError.metal("failed to allocate deterministic sensor buffer")
        }
        let scalars = buffer.contents().assumingMemoryBound(to: Float.self)
        for index in 0..<scalarCount {
          scalars[index] = Float(sensorIndex + 1) * 0.125 + Float(index) * 0.03125
        }
        let validity: (any MTLBuffer)?
        if topology.modality == .proprioception {
          guard let created = device.makeBuffer(
            length: Int(topology.receptorCount) * MemoryLayout<UInt32>.stride,
            options: [.storageModeShared, .hazardTrackingModeTracked]
          ) else {
            throw TissueError.metal("failed to allocate sensor validity buffer")
          }
          created.contents().assumingMemoryBound(to: UInt32.self)
            .initialize(repeating: 1, count: Int(topology.receptorCount))
          validity = created
        } else {
          validity = nil
        }
        return try MetalRawSensorBufferLease(
          buffer: buffer,
          modality: topology.modality,
          receptorTimestamp: BrainTimestamp(
            microseconds: deliveryTimestamp.rawValue
              - UInt64(topology.latencyMicroseconds)
          ),
          receptorCount: topology.receptorCount,
          featureDimension: topology.observationDimension,
          validityBuffer: validity
        )
      }
    return try NumanXSensorPacketLease(
      transaction: token,
      acceptedPhysicsState: acceptedPhysicsState,
      compiledSpeciesTemplate: compiled,
      rawSensors: rawSensors
    )
  }

  private func requireMetal4Device() throws -> any MTLDevice {
    guard let device = MTLCreateSystemDefaultDevice(),
      device.makeMTL4CommandQueue() != nil,
      device.makeCommandAllocator() != nil,
      device.makeCommandBuffer() != nil,
      device.makeSharedEvent() != nil
    else {
      throw XCTSkip("Metal 4 shared-event execution is unavailable")
    }
    return device
  }
}

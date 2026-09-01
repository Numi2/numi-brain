import Foundation
import Metal
import XCTest

import NumiBrainABI
@testable import NumiBrainCore
@_spi(NumanXInterop) @testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalProvisionalFastRootTests: XCTestCase {
  private final class CallbackProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var callbackCountStorage = 0
    private var fastFailureStorage: String?
    private var cognitiveFailureStorage: String?

    func record(
      fast: MetalNumanXPrepareTerminalFeedback,
      cognitive: MetalNumanXPrepareTerminalFeedback
    ) {
      lock.lock()
      callbackCountStorage += 1
      fastFailureStorage = fast.failureDescription
      cognitiveFailureStorage = cognitive.failureDescription
      lock.unlock()
    }

    func recordCallbackOnly() {
      lock.lock()
      callbackCountStorage += 1
      lock.unlock()
    }

    var snapshot: (count: Int, fastFailure: String?, cognitiveFailure: String?) {
      lock.lock()
      defer { lock.unlock() }
      return (
        callbackCountStorage,
        fastFailureStorage,
        cognitiveFailureStorage
      )
    }
  }

  private final class JointResolutionProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var acceptedCountStorage = 0
    private var rejectedCountStorage = 0
    private var latchedGenerationStorage: UInt64?
    private var externalPublicationStorage = false
    let acceptedDisposition: MetalNumanXJointResolutionDisposition
    let brainPublicationInvocationCount: Int

    init(
      acceptedDisposition: MetalNumanXJointResolutionDisposition = .released,
      brainPublicationInvocationCount: Int = 1
    ) {
      self.acceptedDisposition = acceptedDisposition
      self.brainPublicationInvocationCount = brainPublicationInvocationCount
    }

    func releaseAccepted(
      publishBrainGeneration: @Sendable () -> Bool,
      generation: UInt64
    ) -> MetalNumanXJointResolutionDisposition {
      lock.lock()
      acceptedCountStorage += 1
      lock.unlock()
      var acceptedLatchCount = 0
      for _ in 0..<brainPublicationInvocationCount {
        if publishBrainGeneration() { acceptedLatchCount += 1 }
      }
      if acceptedLatchCount == 1 {
        lock.lock()
        latchedGenerationStorage = generation
        externalPublicationStorage = acceptedDisposition == .released
        lock.unlock()
      }
      return acceptedDisposition
    }

    func releaseRejected() -> MetalNumanXJointResolutionDisposition {
      lock.lock()
      rejectedCountStorage += 1
      lock.unlock()
      return .released
    }

    var snapshot: (
      accepted: Int,
      rejected: Int,
      generation: UInt64?,
      externalPublished: Bool
    ) {
      lock.lock()
      defer { lock.unlock() }
      return (
        acceptedCountStorage,
        rejectedCountStorage,
        latchedGenerationStorage,
        externalPublicationStorage
      )
    }
  }

  private final class BlockingJointResolutionProbe: @unchecked Sendable {
    let entered = DispatchSemaphore(value: 0)
    let continuePublication = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var latchedGenerationStorage: UInt64?

    func releaseAccepted(
      publishBrainGeneration: @Sendable () -> Bool,
      generation: UInt64
    ) -> MetalNumanXJointResolutionDisposition {
      entered.signal()
      guard continuePublication.wait(timeout: .now() + 5) == .success else {
        return .terminalNoTouch
      }
      guard publishBrainGeneration() else { return .terminalNoTouch }
      lock.lock()
      latchedGenerationStorage = generation
      lock.unlock()
      return .released
    }

    var latchedGeneration: UInt64? {
      lock.lock()
      defer { lock.unlock() }
      return latchedGenerationStorage
    }
  }

  private final class GenerationProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var valueStorage: UInt64?

    func store(_ value: UInt64) {
      lock.lock()
      valueStorage = value
      lock.unlock()
    }

    var value: UInt64? {
      lock.lock()
      defer { lock.unlock() }
      return valueStorage
    }
  }

  private struct BrainCommitPreflightRecord {
    var abiVersion: UInt32
    var structBytes: UInt32
    var status: UInt32
    var environment: UInt32
    var controlStep: UInt32
    var substepIndex: UInt32
    var physicsSubstepCount: UInt32
    var transactionSlot: UInt32
    var ownerProgramFingerprint: UInt64
    var transactionFingerprint: UInt64
    var linearizationEpoch: UInt64
    var slotGeneration: UInt64
    var substepFingerprint: UInt64
    var physicsTokenFingerprint: UInt64
    var fastTargetGeneration: UInt64
    var cognitiveTargetGeneration: UInt64
    var jointReceiptFingerprint: UInt64
    var fastProgramFingerprint: UInt64
    var brainProgramFingerprint: UInt64
    var preflightFingerprint: UInt64
  }

  private struct JointPublicationFenceRecord {
    var abiVersion: UInt32
    var structBytes: UInt32
    var status: UInt32
    var environment: UInt32
    var controlStep: UInt32
    var substepIndex: UInt32
    var physicsSubstepCount: UInt32
    var reserved0: UInt32
    var ownerProgramFingerprint: UInt64
    var transactionFingerprint: UInt64
    var linearizationEpoch: UInt64
    var slotGeneration: UInt64
    var physicsTokenFingerprint: UInt64
    var brainProgramFingerprint: UInt64
    var brainShadowStateFingerprint: UInt64
    var brainWitnessFingerprint: UInt64
    var appliedDecisionFingerprint: UInt64
    var jointCommitFingerprint: UInt64
    var brainGeneration: UInt64
    var fenceFingerprint: UInt64
  }

  private let parameters = TissueParameters.corticalSheetV0

  func testHumanIOCandidateKeyMatchesCanonicalNativeFixedVector() throws {
    let key = try MetalNumanXHumanIOCandidateKey(
      transactionFingerprint: 1,
      programFingerprint: 2,
      sensorFingerprint: 3,
      transactionInstanceFingerprint: 4,
      sensorGeneration: 5,
      commandBufferIdentity: 6
    )
    XCTAssertEqual(key.fingerprint, 0x9245_fdca_af73_a477)
  }

  func testPublicationFenceStagesTerminalBytesBeforeNonallocatingCopy() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let identity = try MetalNumanXHumanMatterRootIdentity(
      programFingerprint: 0x4f57_4e45_5250_5247,
      transactionFingerprint: 0x5458_4649_4e47_4552,
      linearizationEpoch: 41,
      slotGeneration: 73,
      transactionSlot: 2,
      environment: 0,
      controlStep: 19
    )
    let offset = 16
    let buffer = try XCTUnwrap(
      device.makeBuffer(
        length: offset + 128,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    )
    let fence = try MetalNumiBrainRuntime.NumanXJointPublicationFenceResources(
      ownerBuffer: buffer,
      byteOffset: offset,
      deviceRegistryID: device.registryID,
      identity: identity,
      brainProgramFingerprint: 0x4252_4149_4e50_5247
    )
    let pending = buffer.contents().advanced(by: offset).load(
      as: JointPublicationFenceRecord.self
    )
    XCTAssertEqual(pending.status, 0)
    XCTAssertEqual(pending.fenceFingerprint, recordFingerprint(pending))

    XCTAssertTrue(
      fence.prepareCommittedRecord(
        physicsTokenFingerprint: 0x1001,
        brainShadowStateFingerprint: 0x1002,
        brainWitnessFingerprint: 0x1003,
        appliedDecisionFingerprint: 0x1004,
        jointCommitFingerprint: 0x1005,
        brainGeneration: 1
      )
    )
    let stillPending = buffer.contents().advanced(by: offset).load(
      as: JointPublicationFenceRecord.self
    )
    XCTAssertEqual(
      stillPending.status, 0,
      "terminal fence construction must not touch owner visibility before the private flip"
    )

    fence.copyPreparedCommittedRecord()
    let committed = buffer.contents().advanced(by: offset).load(
      as: JointPublicationFenceRecord.self
    )
    XCTAssertEqual(committed.status, 1)
    XCTAssertEqual(committed.physicsTokenFingerprint, 0x1001)
    XCTAssertEqual(committed.brainShadowStateFingerprint, 0x1002)
    XCTAssertEqual(committed.brainWitnessFingerprint, 0x1003)
    XCTAssertEqual(committed.appliedDecisionFingerprint, 0x1004)
    XCTAssertEqual(committed.jointCommitFingerprint, 0x1005)
    XCTAssertEqual(committed.brainGeneration, 1)
    XCTAssertEqual(committed.fenceFingerprint, recordFingerprint(committed))
    XCTAssertFalse(
      fence.prepareCommittedRecord(
        physicsTokenFingerprint: 0x2001,
        brainShadowStateFingerprint: 0x2002,
        brainWitnessFingerprint: 0x2003,
        appliedDecisionFingerprint: 0x2004,
        jointCommitFingerprint: 0x2005,
        brainGeneration: 2
      ),
      "one owner fence range must be terminally consumed exactly once"
    )
  }

  func testFastPrepareGateStaysPendingUntilExactFastCompletion() throws {
    let runtime = try makeRuntime()
    let token = try runtime.beginInteractiveJointControl(
      controlStepIdentifier: 36,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 1_000)
    )
    let candidate = try runtime.advanceFastSystems(
      candidateDurationMicroseconds: 1_000
    )
    let event = try XCTUnwrap(MTLCreateSystemDefaultDevice()?.makeSharedEvent())
    let ticket = try runtime.submitProvisionalAcceptedFastRoot(
      for: candidate.substep,
      waitFor: try MetalSharedEventPoint(event: event, value: 1),
      signal: try MetalSharedEventPoint(event: event, value: 2)
    )
    let lease = try runtime.numanXFastPrepareStatus(for: ticket)

    let pending = lease.buffer.contents().advanced(by: lease.byteOffset).load(
      as: NBNumanXFastPrepareStatusGPU.self
    )
    XCTAssertEqual(
      pending.abiVersion,
      UInt32(NB_NUMANX_FAST_PREPARE_STATUS_ABI_VERSION)
    )
    XCTAssertEqual(
      pending.structBytes,
      UInt32(NB_NUMANX_FAST_PREPARE_STATUS_BYTE_COUNT)
    )
    XCTAssertEqual(pending.status, UInt32(NB_NUMANX_FAST_PREPARE_PENDING.rawValue))
    XCTAssertEqual(pending.environment, token.environmentIdentifier)
    XCTAssertEqual(pending.controlStep, 36)
    XCTAssertEqual(pending.substepIndex, 0)
    XCTAssertEqual(pending.physicsSubstepCount, 1)
    XCTAssertEqual(pending.fastProgramFingerprint, runtime.numanXFastProgramFingerprint)
    XCTAssertEqual(pending.transactionFingerprint, token.fingerprint)
    XCTAssertEqual(pending.substepFingerprint, candidate.substep.fingerprint)
    XCTAssertEqual(pending.expectedPhysicsGeneration, 101)
    XCTAssertEqual(pending.shadowGeneration, 1)
    XCTAssertEqual(pending.acceptedTimestampMicroseconds, 1_000)
    XCTAssertEqual(pending.gateFingerprint, fastGateFingerprint(pending))
    XCTAssertFalse(ticket.hasCompleted)

    event.signaledValue = 1
    _ = try ticket.waitUntilCompleted(timeoutMilliseconds: 10_000)
    let callbackProbe = CallbackProbe()
    try ticket.registerTerminalFeedbackHandler {
      // Registration happens after terminal feedback, so this callback must
      // run synchronously and be free to reacquire the feedback-state lock.
      XCTAssertNotNil(try? ticket.completionFeedbackIfAvailable())
      callbackProbe.recordCallbackOnly()
    }
    XCTAssertEqual(callbackProbe.snapshot.count, 1)
    XCTAssertThrowsError(
      try ticket.registerTerminalFeedbackHandler {}
    )
    let success = lease.buffer.contents().advanced(by: lease.byteOffset).load(
      as: NBNumanXFastPrepareStatusGPU.self
    )
    XCTAssertEqual(success.status, UInt32(NB_NUMANX_FAST_PREPARE_SUCCESS.rawValue))
    XCTAssertEqual(success.gateFingerprint, fastGateFingerprint(success))
    XCTAssertEqual(success.transactionFingerprint, pending.transactionFingerprint)
    XCTAssertEqual(success.substepFingerprint, pending.substepFingerprint)

    try runtime.abortProvisionalAcceptedFastRootSubmission(
      ticket,
      timeoutMilliseconds: 10_000
    )
  }

  func testPrepareFeedbackLatchIsOrderIndependentAndExactOnce() throws {
    let latch = MetalNumanXPrepareFeedbackLatch()
    let callbackProbe = CallbackProbe()
    let fast = MetalGPUCompletionFeedback(
      gpuStartSeconds: 1,
      gpuEndSeconds: 2
    )
    let cognitive = MetalGPUCompletionFeedback(
      gpuStartSeconds: 2,
      gpuEndSeconds: 3
    )
    try latch.installHandler { fastResult, cognitiveResult in
      callbackProbe.record(fast: fastResult, cognitive: cognitiveResult)
      // If the consumer were invoked under the latch lock this duplicate
      // delivery would deadlock. It must instead be ignored after consume.
      latch.recordFast(.success(fast))
    }

    latch.recordCognitive(.success(cognitive))
    XCTAssertEqual(callbackProbe.snapshot.count, 0)
    latch.recordCognitive(.failure("duplicate cognitive failure"))
    XCTAssertEqual(callbackProbe.snapshot.count, 0)
    latch.recordFast(.success(fast))
    XCTAssertEqual(callbackProbe.snapshot.count, 1)
    XCTAssertNil(callbackProbe.snapshot.fastFailure)
    XCTAssertNil(callbackProbe.snapshot.cognitiveFailure)
    latch.recordFast(.failure("duplicate fast failure"))
    XCTAssertEqual(callbackProbe.snapshot.count, 1)
    XCTAssertThrowsError(
      try latch.installHandler { _, _ in }
    )

    let canceled = MetalNumanXPrepareFeedbackLatch()
    let canceledProbe = CallbackProbe()
    try canceled.installHandler { fastResult, cognitiveResult in
      canceledProbe.record(fast: fastResult, cognitive: cognitiveResult)
    }
    canceled.recordFast(.success(fast))
    canceled.cancel()
    canceled.recordCognitive(.success(cognitive))
    XCTAssertEqual(canceledProbe.snapshot.count, 0)
  }

  func testPrepareFeedbackLatchSynchronousInstallCarriesEitherFailure() throws {
    let latch = MetalNumanXPrepareFeedbackLatch()
    let callbackProbe = CallbackProbe()
    latch.recordFast(.failure("fast command failed"))
    latch.recordCognitive(
      .success(
        MetalGPUCompletionFeedback(gpuStartSeconds: 4, gpuEndSeconds: 5)
      )
    )

    try latch.installHandler { fast, cognitive in
      callbackProbe.record(fast: fast, cognitive: cognitive)
    }
    let snapshot = callbackProbe.snapshot
    XCTAssertEqual(snapshot.count, 1)
    XCTAssertEqual(snapshot.fastFailure, "fast command failed")
    XCTAssertNil(snapshot.cognitiveFailure)
  }

  func testProvisionalFastRootTimeoutRetainsThenCanonicalTokenPublishesOnce()
    throws
  {
    let runtime = try makeRuntime()
    let token = try runtime.beginInteractiveJointControl(
      controlStepIdentifier: 37,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 1_000)
    )
    let candidate = try runtime.advanceFastSystems(
      candidateDurationMicroseconds: 1_000
    )
    let event = try XCTUnwrap(MTLCreateSystemDefaultDevice()?.makeSharedEvent())
    let ticket = try runtime.submitProvisionalAcceptedFastRoot(
      for: candidate.substep,
      waitFor: try MetalSharedEventPoint(event: event, value: 1),
      signal: try MetalSharedEventPoint(event: event, value: 2)
    )

    XCTAssertEqual(ticket.provisional.controlStep, 37)
    XCTAssertEqual(ticket.provisional.expectedPhysicsGeneration, 101)
    XCTAssertEqual(runtime.schedulerCommittedGeneration, 0)
    XCTAssertEqual(runtime.committedStep, 0)
    XCTAssertTrue(runtime.hasPendingRootTransaction)
    XCTAssertTrue(runtime.hasPendingJointTransaction)
    XCTAssertThrowsError(
      try runtime.abortProvisionalAcceptedFastRootSubmission(
        ticket,
        timeoutMilliseconds: 5
      )
    )
    XCTAssertTrue(runtime.ownsOutstandingProvisionalFastRootSubmission(ticket.identifier))
    XCTAssertTrue(runtime.hasPendingRootTransaction)
    XCTAssertThrowsError(
      try runtime.beginInteractiveJointControl(
        controlStepIdentifier: 38,
        basePhysicsGeneration: 100,
        committedTimestamp: BrainTimestamp(microseconds: 0),
        targetTimestamp: BrainTimestamp(microseconds: 1_000)
      )
    )

    event.signaledValue = 1
    _ = try ticket.waitUntilCompleted(timeoutMilliseconds: 10_000)
    XCTAssertGreaterThanOrEqual(event.signaledValue, 2)
    XCTAssertEqual(runtime.schedulerCommittedGeneration, 0)
    XCTAssertEqual(runtime.committedStep, 0)
    let proofSources = try runtime.makeNumanXPreparedFastStateSources(for: ticket)
    XCTAssertEqual(proofSources.count, 16)
    XCTAssertEqual(
      Set(proofSources.map(\.semanticIdentifier)).count,
      proofSources.count
    )

    let accepted = try AcceptedPhysicsStateToken(
      transaction: token,
      substep: candidate.substep,
      physicsStateFingerprint: 0xfeed_0037,
      physicsGeneration: 101
    )
    let prepared = try runtime.prepareProvisionalJointRootTransactionCommit(
      acceptedPhysicsState: accepted,
      provisional: ticket.provisional
    )
    XCTAssertEqual(runtime.schedulerCommittedGeneration, 0)
    runtime.publishPreparedJointRootTransactionCommit(prepared)
    runtime.releaseResolvedProvisionalFastRootSubmission(ticket)

    XCTAssertEqual(runtime.schedulerCommittedGeneration, 1)
    XCTAssertEqual(runtime.committedStep, 1)
    XCTAssertEqual(runtime.schedulerCommittedTimestamp, token.targetTimestamp)
    XCTAssertFalse(runtime.hasPendingRootTransaction)
    XCTAssertFalse(runtime.hasPendingJointTransaction)
    XCTAssertEqual(prepared.receipt.acceptedPhysicsTokenFingerprint, accepted.fingerprint)
  }

  func testProvisionalFastRootRejectsPhysicsGenerationOverflowBeforeEncoding()
    throws
  {
    let runtime = try makeRuntime()
    _ = try runtime.beginInteractiveJointControl(
      controlStepIdentifier: 39,
      basePhysicsGeneration: .max,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 1_000)
    )
    let candidate = try runtime.advanceFastSystems(
      candidateDurationMicroseconds: 1_000
    )
    let event = try XCTUnwrap(MTLCreateSystemDefaultDevice()?.makeSharedEvent())
    XCTAssertThrowsError(
      try runtime.submitProvisionalAcceptedFastRoot(
        for: candidate.substep,
        waitFor: try MetalSharedEventPoint(event: event, value: 1),
        signal: try MetalSharedEventPoint(event: event, value: 2)
      )
    )
    XCTAssertFalse(runtime.hasPendingRootTransaction)
    XCTAssertFalse(runtime.hasPendingJointTransaction)
    try runtime.abortInteractiveJointControl()
  }

  func testStaleTokenAndPhysicalFailureAbortNeverPublish() throws {
    let runtime = try makeRuntime()
    let token = try runtime.beginInteractiveJointControl(
      controlStepIdentifier: 41,
      basePhysicsGeneration: 200,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 1_000)
    )
    let candidate = try runtime.advanceFastSystems(
      candidateDurationMicroseconds: 1_000
    )
    let event = try XCTUnwrap(MTLCreateSystemDefaultDevice()?.makeSharedEvent())
    let ticket = try runtime.submitProvisionalAcceptedFastRoot(
      for: candidate.substep,
      waitFor: try MetalSharedEventPoint(event: event, value: 1),
      signal: try MetalSharedEventPoint(event: event, value: 2)
    )
    event.signaledValue = 1
    _ = try ticket.waitUntilCompleted(timeoutMilliseconds: 10_000)

    let otherToken = try BrainJointTransactionToken(
      environmentIdentifier: token.environmentIdentifier,
      episodeIdentifier: token.episodeIdentifier,
      controlStepIdentifier: 42,
      parameterVersionFingerprint: token.parameterVersionFingerprint,
      baseBrainGeneration: token.baseBrainGeneration,
      basePhysicsGeneration: token.basePhysicsGeneration,
      committedTimestamp: token.committedTimestamp,
      targetTimestamp: token.targetTimestamp,
      randomCounterGeneration: token.randomCounterGeneration
    )
    let otherSubstep = try BrainJointSubstepToken(
      transaction: otherToken,
      substepIndex: 0,
      attemptIndex: 0,
      startTimestamp: otherToken.committedTimestamp,
      durationMicroseconds: 1_000
    )
    let stale = try AcceptedPhysicsStateToken(
      transaction: otherToken,
      substep: otherSubstep,
      physicsStateFingerprint: 0xdead,
      physicsGeneration: 201
    )
    XCTAssertThrowsError(
      try runtime.prepareProvisionalJointRootTransactionCommit(
        acceptedPhysicsState: stale,
        provisional: ticket.provisional
      )
    )
    XCTAssertEqual(runtime.schedulerCommittedGeneration, 0)
    XCTAssertEqual(runtime.committedStep, 0)

    // A first-physical-CB failure is represented by liveness signal without
    // a canonical owner token. Explicit teardown must only discard shadow.
    try runtime.abortProvisionalAcceptedFastRootSubmission(
      ticket,
      timeoutMilliseconds: 10_000
    )
    XCTAssertEqual(runtime.schedulerCommittedGeneration, 0)
    XCTAssertEqual(runtime.committedStep, 0)
    XCTAssertFalse(runtime.hasPendingRootTransaction)
    XCTAssertFalse(runtime.hasPendingJointTransaction)
  }

  func testProvisionalFastRootReplayIsByteDeterministic() throws {
    let first = try runAcceptedReplay(controlStep: 51)
    let second = try runAcceptedReplay(controlStep: 51)
    XCTAssertEqual(first.provisional, second.provisional)
    XCTAssertEqual(first.receipt, second.receipt)
    XCTAssertEqual(first.state.stableHash(), second.state.stableHash())
    XCTAssertEqual(first.relayTimestamps, second.relayTimestamps)
    XCTAssertEqual(first.fastManifest, second.fastManifest)
  }

  func testPreflightedAtomicPublicationNeverExposesOneBrainHalf() throws {
    let failed = try makeCompleteFixture(controlStep: 61)
    let committedSensors = try makeSensorPacket(
      device: failed.device,
      compiled: failed.compiled,
      token: failed.transaction.token,
      acceptedPhysicsState: nil
    )
    _ = try failed.runtime.inferAndDecide(
      failed.transaction,
      numanXSensors: committedSensors
    )
    let failedCandidate = try failed.runtime.advanceFastSystems(
      failed.transaction,
      candidateDurationMicroseconds: 1_000
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: failed.transaction.token,
      substep: failedCandidate.substep,
      physicsStateFingerprint: 0xa001,
      physicsGeneration: 101
    )
    try failed.runtime.acceptPhysicsSubstep(
      failed.transaction,
      accepted: accepted
    )
    let conflicting = try AcceptedPhysicsStateToken(
      transaction: failed.transaction.token,
      substep: failedCandidate.substep,
      physicsStateFingerprint: 0xa002,
      physicsGeneration: 101
    )
    let conflictingSensors = try makeSensorPacket(
      device: failed.device,
      compiled: failed.compiled,
      token: failed.transaction.token,
      acceptedPhysicsState: conflicting
    )
    XCTAssertThrowsError(
      try failed.runtime.commitControl(
        failed.transaction,
        acceptedSensors: conflictingSensors
      )
    )
    XCTAssertEqual(failed.runtime.committedGeneration, 0)
    XCTAssertEqual(failed.runtime.fastTissue.schedulerCommittedGeneration, 0)
    XCTAssertEqual(
      failed.runtime.cognitive.agentStateRuntime.arena.committedGeneration,
      0
    )

    let succeeded = try makeCompleteFixture(controlStep: 62)
    let initialSensors = try makeSensorPacket(
      device: succeeded.device,
      compiled: succeeded.compiled,
      token: succeeded.transaction.token,
      acceptedPhysicsState: nil
    )
    _ = try succeeded.runtime.inferAndDecide(
      succeeded.transaction,
      numanXSensors: initialSensors
    )
    let candidate = try succeeded.runtime.advanceFastSystems(
      succeeded.transaction,
      candidateDurationMicroseconds: 1_000
    )
    let finalAccepted = try AcceptedPhysicsStateToken(
      transaction: succeeded.transaction.token,
      substep: candidate.substep,
      physicsStateFingerprint: 0xb001,
      physicsGeneration: 101
    )
    try succeeded.runtime.acceptPhysicsSubstep(
      succeeded.transaction,
      accepted: finalAccepted
    )
    let finalSensors = try makeSensorPacket(
      device: succeeded.device,
      compiled: succeeded.compiled,
      token: succeeded.transaction.token,
      acceptedPhysicsState: finalAccepted
    )
    let result = try succeeded.runtime.commitControl(
      succeeded.transaction,
      acceptedSensors: finalSensors
    )
    XCTAssertEqual(result.receipt.brainGeneration, 1)
    XCTAssertEqual(succeeded.runtime.committedGeneration, 1)
    XCTAssertEqual(succeeded.runtime.fastTissue.schedulerCommittedGeneration, 1)
    XCTAssertEqual(
      succeeded.runtime.cognitive.agentStateRuntime.arena.committedGeneration,
      1
    )
  }

  func testHighLevelNumanXPrepareWaitsFastAndPublishesNothing() throws {
    let fixture = try makeCompleteFixture(
      controlStep: 71,
      environmentIdentifier: 0
    )
    let initialSensors = try makeSensorPacket(
      device: fixture.device,
      compiled: fixture.compiled,
      token: fixture.transaction.token,
      acceptedPhysicsState: nil
    )
    _ = try fixture.runtime.inferAndDecide(
      fixture.transaction,
      numanXSensors: initialSensors
    )
    let candidate = try fixture.runtime.advanceFastSystems(
      fixture.transaction,
      candidateDurationMicroseconds: 1_000
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: fixture.transaction.token,
      substep: candidate.substep,
      physicsStateFingerprint: 0xc001,
      physicsGeneration: 101
    )
    let gateBuffer = try XCTUnwrap(fixture.device.makeBuffer(
      length: MetalAcceptedPhysicsGateLease.byteCount,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ))
    var gateRecord = accepted.abiRecord
    withUnsafeBytes(of: &gateRecord) { bytes in
      gateBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
    let gate = try MetalAcceptedPhysicsGateLease(buffer: gateBuffer)
    let physicalEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let fastEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let brainEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let preflightEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let fastTicket = try fixture.runtime.submitProvisionalAcceptedFastRoot(
      fixture.transaction,
      waitFor: try MetalSharedEventPoint(event: physicalEvent, value: 1),
      signal: try MetalSharedEventPoint(event: fastEvent, value: 1)
    )
    let identity = try MetalNumanXHumanMatterRootIdentity(
      programFingerprint: 0x4855_4d41_4e4d_4154,
      transactionFingerprint: fixture.transaction.token.fingerprint,
      linearizationEpoch: 0x100,
      slotGeneration: 0x200,
      transactionSlot: 3,
      environment: 0,
      controlStep: 71
    )
    let acceptedSensors = try makeSensorPacket(
      device: fixture.device,
      compiled: fixture.compiled,
      token: fixture.transaction.token,
      acceptedPhysicsState: accepted
    )
    let sensorCandidate = try makePendingSensorCandidate(
      acceptedSensors,
      transaction: fixture.transaction.token,
      acceptedBrainGeneration: fastTicket.provisional.shadowGeneration
    )
    XCTAssertThrowsError(
      try fixture.runtime.submitNumanXPreparedControl(
        fixture.transaction,
        provisionalFast: fastTicket,
        identity: identity,
        acceptedPhysicsGate: gate,
        sensorCandidate: sensorCandidate,
        signal: try MetalSharedEventPoint(event: brainEvent, value: 1),
        thenSignal: try MetalSharedEventPoint(event: brainEvent, value: 2)
      )
    )
    XCTAssertEqual(fixture.transaction.status, .provisionalFastSubmitted)
    let prepared = try fixture.runtime.submitNumanXPreparedControl(
      fixture.transaction,
      provisionalFast: fastTicket,
      identity: identity,
      acceptedPhysicsGate: gate,
      sensorCandidate: sensorCandidate,
      signal: try MetalSharedEventPoint(event: brainEvent, value: 1),
      thenSignal: try MetalSharedEventPoint(event: preflightEvent, value: 1)
    )
    let publicationFenceOffset = 16
    let ownerPublicationFence = try XCTUnwrap(
      fixture.device.makeBuffer(
        length: publicationFenceOffset + 128,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    )
    try fixture.runtime.bindNumanXOwnerPublicationFence(
      prepared,
      ownerBuffer: ownerPublicationFence,
      byteOffset: publicationFenceOffset
    )

    XCTAssertEqual(prepared.identity, identity)
    XCTAssertEqual(
      prepared.provisionalPhysicsAcceptance,
      fastTicket.provisional
    )
    XCTAssertEqual(prepared.brainCommitWitnessByteCount, 128)
    XCTAssertGreaterThan(prepared.brainCommitWitnessGPUAddress, 0)
    XCTAssertGreaterThan(prepared.brainProgramFingerprint, 0)
    XCTAssertEqual(MemoryLayout<BrainCommitPreflightRecord>.stride, 128)
    XCTAssertEqual(MemoryLayout<JointPublicationFenceRecord>.stride, 128)
    XCTAssertEqual(prepared.brainCommitPreflightBuffer.length, 128)
    XCTAssertEqual(ownerPublicationFence.length, publicationFenceOffset + 128)
    XCTAssertEqual(
      prepared.brainCommitPreflightReadyPoint.value,
      1
    )
    let pendingPreflight = prepared.brainCommitPreflightBuffer.contents().load(
      as: BrainCommitPreflightRecord.self
    )
    XCTAssertEqual(pendingPreflight.abiVersion, 1)
    XCTAssertEqual(pendingPreflight.structBytes, 128)
    XCTAssertEqual(pendingPreflight.status, 0)
    XCTAssertEqual(pendingPreflight.environment, 0)
    XCTAssertEqual(pendingPreflight.controlStep, 71)
    XCTAssertEqual(pendingPreflight.substepIndex, 0)
    XCTAssertEqual(pendingPreflight.physicsSubstepCount, 1)
    XCTAssertEqual(pendingPreflight.transactionSlot, identity.transactionSlot)
    XCTAssertEqual(
      pendingPreflight.ownerProgramFingerprint,
      identity.programFingerprint
    )
    XCTAssertEqual(
      pendingPreflight.transactionFingerprint,
      identity.transactionFingerprint
    )
    XCTAssertEqual(
      pendingPreflight.substepFingerprint,
      fastTicket.provisional.substepFingerprint
    )
    XCTAssertEqual(pendingPreflight.physicsTokenFingerprint, 0)
    XCTAssertEqual(pendingPreflight.fastTargetGeneration, 1)
    XCTAssertEqual(pendingPreflight.cognitiveTargetGeneration, 1)
    XCTAssertEqual(pendingPreflight.jointReceiptFingerprint, 0)
    XCTAssertEqual(
      pendingPreflight.preflightFingerprint,
      recordFingerprint(pendingPreflight)
    )
    let pendingFence = ownerPublicationFence.contents()
      .advanced(by: publicationFenceOffset)
      .load(as: JointPublicationFenceRecord.self)
    XCTAssertEqual(pendingFence.abiVersion, 1)
    XCTAssertEqual(pendingFence.structBytes, 128)
    XCTAssertEqual(pendingFence.status, 0)
    XCTAssertEqual(pendingFence.controlStep, 71)
    XCTAssertEqual(pendingFence.ownerProgramFingerprint, identity.programFingerprint)
    XCTAssertEqual(pendingFence.transactionFingerprint, identity.transactionFingerprint)
    XCTAssertEqual(pendingFence.physicsTokenFingerprint, 0)
    XCTAssertEqual(pendingFence.brainProgramFingerprint, prepared.brainProgramFingerprint)
    XCTAssertEqual(pendingFence.fenceFingerprint, recordFingerprint(pendingFence))
    XCTAssertEqual(preflightEvent.signaledValue, 0)
    XCTAssertEqual(fixture.runtime.committedGeneration, 0)
    XCTAssertEqual(fixture.runtime.fastTissue.schedulerCommittedGeneration, 0)
    XCTAssertEqual(
      fixture.runtime.cognitive.agentStateRuntime.arena.committedGeneration,
      0
    )
    XCTAssertThrowsError(
      try fixture.runtime.abortNumanXPreparedControl(
        prepared,
        timeoutMilliseconds: 5
      )
    )
    XCTAssertTrue(fixture.runtime.hasOpenControl)
    XCTAssertEqual(fixture.transaction.status, .numanXPrepareSubmitted)
    XCTAssertTrue(
      fixture.runtime.fastTissue.ownsOutstandingProvisionalFastRootSubmission(
        fastTicket.identifier
      )
    )
    XCTAssertFalse(prepared.hasBrainPrepareCompleted)

    physicalEvent.signaledValue = 1
    _ = try prepared.waitUntilBrainPrepareCompleted(
      timeoutMilliseconds: 10_000
    )
    XCTAssertGreaterThanOrEqual(fastEvent.signaledValue, 1)
    XCTAssertGreaterThanOrEqual(brainEvent.signaledValue, 1)
    XCTAssertEqual(
      waitForPrepareTerminalStatus(prepared),
      .numanXPreflightReady
    )
    XCTAssertEqual(fixture.runtime.committedGeneration, 0)
    XCTAssertEqual(fixture.runtime.fastTissue.schedulerCommittedGeneration, 0)
    XCTAssertEqual(
      fixture.runtime.cognitive.agentStateRuntime.arena.committedGeneration,
      0
    )

    XCTAssertEqual(prepared.status, .numanXPreflightReady)
    XCTAssertGreaterThanOrEqual(preflightEvent.signaledValue, 1)
    let successfulPreflight = prepared.brainCommitPreflightBuffer.contents().load(
      as: BrainCommitPreflightRecord.self
    )
    XCTAssertEqual(successfulPreflight.status, 1)
    XCTAssertEqual(
      successfulPreflight.physicsTokenFingerprint,
      accepted.fingerprint
    )
    XCTAssertEqual(successfulPreflight.fastTargetGeneration, 1)
    XCTAssertEqual(successfulPreflight.cognitiveTargetGeneration, 1)
    XCTAssertGreaterThan(successfulPreflight.jointReceiptFingerprint, 0)
    XCTAssertEqual(
      successfulPreflight.preflightFingerprint,
      recordFingerprint(successfulPreflight)
    )
    XCTAssertEqual(fixture.runtime.committedGeneration, 0)
    XCTAssertEqual(fixture.runtime.fastTissue.schedulerCommittedGeneration, 0)
    XCTAssertEqual(
      fixture.runtime.cognitive.agentStateRuntime.arena.committedGeneration,
      0
    )
    try fixture.runtime.abortNumanXPreparedControl(
      prepared,
      timeoutMilliseconds: 10_000
    )
    XCTAssertGreaterThanOrEqual(preflightEvent.signaledValue, 1)
    let rejectedPreflight = prepared.brainCommitPreflightBuffer.contents().load(
      as: BrainCommitPreflightRecord.self
    )
    XCTAssertEqual(rejectedPreflight.status, 1)
    XCTAssertEqual(
      rejectedPreflight.preflightFingerprint,
      recordFingerprint(rejectedPreflight)
    )
    XCTAssertFalse(fixture.runtime.hasOpenControl)
    XCTAssertEqual(fixture.runtime.committedGeneration, 0)
    XCTAssertEqual(fixture.runtime.fastTissue.schedulerCommittedGeneration, 0)
    XCTAssertEqual(
      fixture.runtime.cognitive.agentStateRuntime.arena.committedGeneration,
      0
    )
    let reused = try fixture.runtime.beginControl(
      controlStepIdentifier: 72,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 10_000),
      targetTimestamp: BrainTimestamp(microseconds: 11_000),
      cachedDecisionFingerprint: 0x6048
    )
    try fixture.runtime.abortControl(reused)
  }

  func testNumanXPreparedJointCommitFingerprintRequiresSettledSuccess()
    throws
  {
    let fixture = try makePreparedCloseFixture(
      controlStep: 87,
      settle: false
    )
    defer {
      try? fixture.complete.runtime.abortNumanXPreparedControl(
        fixture.prepared,
        timeoutMilliseconds: 10_000
      )
    }

    XCTAssertEqual(fixture.prepared.status, .numanXPrepareSubmitted)
    XCTAssertThrowsError(
      try fixture.complete.runtime.numanXPreparedJointCommitFingerprint(
        for: fixture.prepared,
        identity: fixture.identity
      )
    )

    fixture.physicalEvent.signaledValue = 1
    _ = try fixture.prepared.waitUntilBrainPrepareCompleted(
      timeoutMilliseconds: 10_000
    )
    XCTAssertEqual(
      waitForPrepareTerminalStatus(fixture.prepared),
      .numanXPreflightReady
    )
    let fingerprint = try fixture.complete.runtime
      .numanXPreparedJointCommitFingerprint(
        for: fixture.prepared,
        identity: fixture.identity
      )
    XCTAssertGreaterThan(fingerprint, 0)
    XCTAssertEqual(
      fingerprint,
      expectedPreparedJointCommitFingerprint(fixture)
    )

    try fixture.complete.runtime.abortNumanXPreparedControl(
      fixture.prepared,
      timeoutMilliseconds: 10_000
    )
    XCTAssertThrowsError(
      try fixture.complete.runtime.numanXPreparedJointCommitFingerprint(
        for: fixture.prepared,
        identity: fixture.identity
      )
    )
  }

  func testNumanXPreparedJointCommitFingerprintRejectsForeignTicketAndRoot()
    throws
  {
    let owned = try makePreparedCloseFixture(controlStep: 88)
    let foreign = try makePreparedCloseFixture(controlStep: 88)
    defer {
      try? owned.complete.runtime.abortNumanXPreparedControl(
        owned.prepared,
        timeoutMilliseconds: 10_000
      )
      try? foreign.complete.runtime.abortNumanXPreparedControl(
        foreign.prepared,
        timeoutMilliseconds: 10_000
      )
    }

    XCTAssertEqual(owned.identity, foreign.identity)
    XCTAssertEqual(
      owned.prepared.provisionalPhysicsAcceptance,
      foreign.prepared.provisionalPhysicsAcceptance
    )
    XCTAssertFalse(owned.prepared === foreign.prepared)
    XCTAssertThrowsError(
      try owned.complete.runtime.numanXPreparedJointCommitFingerprint(
        for: foreign.prepared,
        identity: foreign.identity
      )
    )

    let wrongRoot = try MetalNumanXHumanMatterRootIdentity(
      programFingerprint: owned.identity.programFingerprint ^ 1,
      transactionFingerprint: owned.identity.transactionFingerprint,
      linearizationEpoch: owned.identity.linearizationEpoch,
      slotGeneration: owned.identity.slotGeneration &+ 1,
      transactionSlot: owned.identity.transactionSlot,
      environment: owned.identity.environment,
      stepIndex: owned.identity.stepIndex,
      controlStep: owned.identity.controlStep,
      substepIndex: owned.identity.substepIndex,
      physicsSubstepCount: owned.identity.physicsSubstepCount
    )
    XCTAssertThrowsError(
      try owned.complete.runtime.numanXPreparedJointCommitFingerprint(
        for: owned.prepared,
        identity: wrongRoot
      )
    )
    XCTAssertEqual(
      try owned.complete.runtime.numanXPreparedJointCommitFingerprint(
        for: owned.prepared,
        identity: owned.identity
      ),
      expectedPreparedJointCommitFingerprint(owned)
    )
  }

  func testNumanXPreparedJointCommitFingerprintReplayUsesRetainedScalar()
    throws
  {
    let fixture = try makePreparedCloseFixture(controlStep: 89)
    defer {
      try? fixture.complete.runtime.abortNumanXPreparedControl(
        fixture.prepared,
        timeoutMilliseconds: 10_000
      )
    }
    let first = try fixture.complete.runtime
      .numanXPreparedJointCommitFingerprint(
        for: fixture.prepared,
        identity: fixture.identity
      )
    XCTAssertEqual(first, expectedPreparedJointCommitFingerprint(fixture))
    for _ in 0..<8 {
      XCTAssertEqual(
        try fixture.complete.runtime.numanXPreparedJointCommitFingerprint(
          for: fixture.prepared,
          identity: fixture.identity
        ),
        first
      )
    }
  }

  func testHighLevelNumanXPrepareRejectsForeignFastOwnership() throws {
    let fixture = try makeCompleteFixture(
      controlStep: 72,
      environmentIdentifier: 0
    )
    let initialSensors = try makeSensorPacket(
      device: fixture.device,
      compiled: fixture.compiled,
      token: fixture.transaction.token,
      acceptedPhysicsState: nil
    )
    _ = try fixture.runtime.inferAndDecide(
      fixture.transaction,
      numanXSensors: initialSensors
    )
    _ = try fixture.runtime.advanceFastSystems(
      fixture.transaction,
      candidateDurationMicroseconds: 1_000
    )
    let ownedPhysicalEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let ownedFastEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let ownedTicket = try fixture.runtime.submitProvisionalAcceptedFastRoot(
      fixture.transaction,
      waitFor: try MetalSharedEventPoint(event: ownedPhysicalEvent, value: 1),
      signal: try MetalSharedEventPoint(event: ownedFastEvent, value: 1)
    )

    let foreignRuntime = try makeRuntime()
    _ = try foreignRuntime.beginInteractiveJointControl(
      controlStepIdentifier: 73,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 1_000)
    )
    let foreignCandidate = try foreignRuntime.advanceFastSystems(
      candidateDurationMicroseconds: 1_000
    )
    let foreignPhysicalEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let foreignFastEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let foreignTicket = try foreignRuntime.submitProvisionalAcceptedFastRoot(
      for: foreignCandidate.substep,
      waitFor: try MetalSharedEventPoint(event: foreignPhysicalEvent, value: 1),
      signal: try MetalSharedEventPoint(event: foreignFastEvent, value: 1)
    )
    let gateBuffer = try XCTUnwrap(fixture.device.makeBuffer(
      length: MetalAcceptedPhysicsGateLease.byteCount,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ))
    gateBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: gateBuffer.length
    )
    let identity = try MetalNumanXHumanMatterRootIdentity(
      programFingerprint: 0x4855_4d41_4e4d_4154,
      transactionFingerprint: fixture.transaction.token.fingerprint,
      linearizationEpoch: 0x100,
      slotGeneration: 0x200,
      transactionSlot: 3,
      environment: 0,
      controlStep: 72
    )
    let sensorCandidate = try makePendingSensorCandidate(
      initialSensors,
      transaction: fixture.transaction.token,
      acceptedBrainGeneration: ownedTicket.provisional.shadowGeneration
    )
    XCTAssertThrowsError(
      try fixture.runtime.submitNumanXPreparedControl(
        fixture.transaction,
        provisionalFast: foreignTicket,
        identity: identity,
        acceptedPhysicsGate: try MetalAcceptedPhysicsGateLease(
          buffer: gateBuffer
        ),
        sensorCandidate: sensorCandidate,
        signal: try MetalSharedEventPoint(
          event: try XCTUnwrap(fixture.device.makeSharedEvent()),
          value: 1
        ),
        thenSignal: try MetalSharedEventPoint(
          event: try XCTUnwrap(fixture.device.makeSharedEvent()),
          value: 1
        )
      )
    )
    XCTAssertEqual(fixture.transaction.status, .provisionalFastSubmitted)
    XCTAssertEqual(fixture.runtime.committedGeneration, 0)

    ownedPhysicalEvent.signaledValue = 1
    foreignPhysicalEvent.signaledValue = 1
    _ = try ownedTicket.waitUntilCompleted(timeoutMilliseconds: 10_000)
    _ = try foreignTicket.waitUntilCompleted(timeoutMilliseconds: 10_000)
    try fixture.runtime.abortProvisionalAcceptedFastRootSubmission(
      ownedTicket,
      transaction: fixture.transaction,
      timeoutMilliseconds: 10_000
    )
    try foreignRuntime.abortProvisionalAcceptedFastRootSubmission(
      foreignTicket,
      timeoutMilliseconds: 10_000
    )
  }

  func testPendingSensorCandidateBindsExactHumanIORanges() throws {
    let fixture = try makeCompleteFixture(
      controlStep: 86,
      environmentIdentifier: 0
    )
    let firstPacket = try makeSensorPacket(
      device: fixture.device,
      compiled: fixture.compiled,
      token: fixture.transaction.token,
      acceptedPhysicsState: nil
    )
    let substitutedPacket = try makeSensorPacket(
      device: fixture.device,
      compiled: fixture.compiled,
      token: fixture.transaction.token,
      acceptedPhysicsState: nil
    )
    let originalRange = try XCTUnwrap(firstPacket.rawSensors.first)
    let substitutedRange = try XCTUnwrap(substitutedPacket.rawSensors.first)
    XCTAssertEqual(originalRange.buffer.length, substitutedRange.buffer.length)
    XCTAssertThrowsError(
      try MetalNumanXHumanIOCandidateRangeLease(
        buffer: substitutedRange.buffer,
        metalBufferObject: Unmanaged.passUnretained(
          originalRange.buffer as AnyObject
        ).toOpaque(),
        gpuAddress: substitutedRange.buffer.gpuAddress,
        byteOffset: 0,
        byteCount: substitutedRange.buffer.length,
        elementType: MetalNumanXHumanIOCandidateRangeLease.float32ElementType,
        elementByteCount: UInt32(MemoryLayout<Float>.stride)
      ),
      "same-shape storage with a substituted retained handle must fail bridge construction"
    )
    let first = try makePendingSensorCandidate(
      firstPacket,
      transaction: fixture.transaction.token,
      acceptedBrainGeneration: 1,
      salt: 86
    )
    let substituted = try makePendingSensorCandidate(
      substitutedPacket,
      transaction: fixture.transaction.token,
      acceptedBrainGeneration: 1,
      salt: 86
    )

    XCTAssertEqual(first.candidateKey, substituted.candidateKey)
    XCTAssertEqual(
      first.candidatePublicationFingerprint,
      substituted.candidatePublicationFingerprint
    )
    XCTAssertNotEqual(
      first.publicationFingerprint,
      substituted.publicationFingerprint,
      "same-shape HumanIO storage substitution must change joint close authority"
    )
    try fixture.runtime.abortControl(fixture.transaction)
  }

  func testFailedCanonicalPreflightSignalsPendingAndNeverPublishes() throws {
    let fixture = try makeCompleteFixture(
      controlStep: 74,
      environmentIdentifier: 0
    )
    let initialSensors = try makeSensorPacket(
      device: fixture.device,
      compiled: fixture.compiled,
      token: fixture.transaction.token,
      acceptedPhysicsState: nil
    )
    _ = try fixture.runtime.inferAndDecide(
      fixture.transaction,
      numanXSensors: initialSensors
    )
    let candidate = try fixture.runtime.advanceFastSystems(
      fixture.transaction,
      candidateDurationMicroseconds: 1_000
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: fixture.transaction.token,
      substep: candidate.substep,
      physicsStateFingerprint: 0xc074,
      physicsGeneration: 101
    )
    let gateBuffer = try XCTUnwrap(fixture.device.makeBuffer(
      length: MetalAcceptedPhysicsGateLease.byteCount,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ))
    // A first-physical failure can advance only the liveness event while the
    // retained authoritative gate stays PENDING/zero. Automatic preflight
    // must fail closed without a host-supplied expected digest.
    gateBuffer.contents().initializeMemory(
      as: UInt8.self,
      repeating: 0,
      count: gateBuffer.length
    )
    let physicalEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let fastEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let brainEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let preflightEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let fastTicket = try fixture.runtime.submitProvisionalAcceptedFastRoot(
      fixture.transaction,
      waitFor: try MetalSharedEventPoint(event: physicalEvent, value: 1),
      signal: try MetalSharedEventPoint(event: fastEvent, value: 1)
    )
    let identity = try MetalNumanXHumanMatterRootIdentity(
      programFingerprint: 0x4855_4d41_4e4d_4154,
      transactionFingerprint: fixture.transaction.token.fingerprint,
      linearizationEpoch: 0x101,
      slotGeneration: 0x201,
      transactionSlot: 4,
      environment: 0,
      controlStep: 74
    )
    let acceptedSensors = try makeSensorPacket(
      device: fixture.device,
      compiled: fixture.compiled,
      token: fixture.transaction.token,
      acceptedPhysicsState: accepted
    )
    let sensorCandidate = try makePendingSensorCandidate(
      acceptedSensors,
      transaction: fixture.transaction.token,
      acceptedBrainGeneration: fastTicket.provisional.shadowGeneration,
      salt: 0x74
    )
    let prepared = try fixture.runtime.submitNumanXPreparedControl(
      fixture.transaction,
      provisionalFast: fastTicket,
      identity: identity,
      acceptedPhysicsGate: try MetalAcceptedPhysicsGateLease(
        buffer: gateBuffer
      ),
      sensorCandidate: sensorCandidate,
      signal: try MetalSharedEventPoint(event: brainEvent, value: 1),
      thenSignal: try MetalSharedEventPoint(event: preflightEvent, value: 1)
    )

    physicalEvent.signaledValue = 1
    _ = try prepared.waitUntilBrainPrepareCompleted(
      timeoutMilliseconds: 10_000
    )
    XCTAssertEqual(
      waitForPrepareTerminalStatus(prepared),
      .numanXPreflightFailed
    )
    XCTAssertEqual(prepared.status, .numanXPreflightFailed)
    XCTAssertGreaterThanOrEqual(preflightEvent.signaledValue, 1)
    let pending = prepared.brainCommitPreflightBuffer.contents().load(
      as: BrainCommitPreflightRecord.self
    )
    XCTAssertEqual(pending.status, 0)
    XCTAssertEqual(pending.physicsTokenFingerprint, 0)
    XCTAssertEqual(pending.jointReceiptFingerprint, 0)
    XCTAssertEqual(pending.preflightFingerprint, recordFingerprint(pending))
    XCTAssertEqual(fixture.runtime.committedGeneration, 0)
    XCTAssertEqual(fixture.runtime.fastTissue.schedulerCommittedGeneration, 0)
    XCTAssertEqual(
      fixture.runtime.cognitive.agentStateRuntime.arena.committedGeneration,
      0
    )
    XCTAssertThrowsError(
      try fixture.runtime.numanXPreparedJointCommitFingerprint(
        for: prepared,
        identity: identity
      )
    )

    try fixture.runtime.abortNumanXPreparedControl(
      prepared,
      timeoutMilliseconds: 10_000
    )
    XCTAssertFalse(fixture.runtime.hasOpenControl)
    XCTAssertEqual(fixture.runtime.committedGeneration, 0)
  }

  func testABI4JointClosePublishesOneGenerationThroughOwnerFence() throws {
    let fixture = try makePreparedCloseFixture(controlStep: 75)
    let captureDirectory = FileManager.default.temporaryDirectory.appending(
      path: UUID().uuidString,
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: captureDirectory) }
    let capturedSample = try MetalNumanXGateCCapture.writeSettledRootSample(
      transaction: fixture.complete.transaction.token,
      sensors: fixture.inputSensors,
      coordinates: try BrainPolicyNumanXDatasetCoordinates(
        datasetSourceIdentifier: "numanx-terminal-root-test",
        datasetSourceRevision: "test-revision",
        episodeIdentifier: 1,
        taskFingerprint: 2,
        sceneFingerprint: 3,
        objectFingerprint: 4,
        embodimentFingerprint: 5
      ),
      artifactDirectory: captureDirectory
    )
    let proposal = try makeProposalFixture(fixture, accept: true)
    let ackEvent = try XCTUnwrap(fixture.complete.device.makeSharedEvent())
    let ackTicket = try fixture.complete.runtime.submitNumanXBrainAck(
      fixture.prepared,
      proposal: proposal.lease,
      signal: try MetalSharedEventPoint(event: ackEvent, value: 1)
    )
    try waitForTerminalFeedback(ackTicket)
    let ack = ackTicket.ackLease.buffer.contents().load(
      as: NBNumanXHumanMatterBrainAckGPU.self
    )
    XCTAssertEqual(ack.status, NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_ACCEPT.rawValue)
    XCTAssertEqual(ack.decision, NB_NUMANX_HUMAN_MATTER_ROOT_ACCEPT.rawValue)

    let applied = try makeAppliedLease(
      fixture,
      ack: ack,
      proposal: proposal.proposal,
      accept: true
    )
    let preflight = fixture.prepared.brainCommitPreflightBuffer.contents().load(
      as: NBNumanXHumanMatterBrainCommitPreflightGPU.self
    )
    let probe = JointResolutionProbe()
    let resolution = try MetalNumanXJointResolutionReservation(
      identity: fixture.identity,
      proposal: proposal.lease,
      applied: applied,
      sensorCandidate: fixture.sensorCandidate,
      jointCommitFingerprint: preflight.jointReceiptFingerprint,
      brainGeneration: fixture.prepared.provisionalPhysicsAcceptance
        .shadowGeneration,
      releaseAccepted: { publish in
        probe.releaseAccepted(
          publishBrainGeneration: publish,
          generation: fixture.prepared.provisionalPhysicsAcceptance
            .shadowGeneration
        )
      },
      releaseRejected: { probe.releaseRejected() }
    )
    let validationEvent = try XCTUnwrap(fixture.complete.device.makeSharedEvent())
    let qualificationSample = BrainPolicyEvidenceArtifact.sha256(
      Data("accepted-root-sample".utf8)
    )
    XCTAssertThrowsError(
      try fixture.prepared.qualificationRootExecution(
        sampleSHA256: qualificationSample
      )
    )
    _ = try fixture.complete.runtime.validateNumanXAppliedRoot(
      fixture.prepared,
      ack: ackTicket,
      applied: applied,
      resolution: resolution,
      signal: try MetalSharedEventPoint(event: validationEvent, value: 1)
    )

    XCTAssertEqual(
      waitForCloseTerminalStatus(fixture.prepared),
      .committed
    )
    XCTAssertEqual(fixture.complete.runtime.committedGeneration, 1)
    XCTAssertEqual(
      fixture.complete.runtime.fastTissue.schedulerCommittedGeneration,
      1
    )
    XCTAssertEqual(
      fixture.complete.runtime.cognitive.agentStateRuntime.arena
        .committedGeneration,
      1
    )
    let probeSnapshot = probe.snapshot
    XCTAssertEqual(probeSnapshot.accepted, 1)
    XCTAssertEqual(probeSnapshot.rejected, 0)
    XCTAssertEqual(probeSnapshot.generation, 1)
    XCTAssertTrue(probeSnapshot.externalPublished)
    XCTAssertFalse(fixture.prepared.hasPublicationProtocolViolation)
    let qualification = try fixture.prepared.qualificationRootExecution(
      sampleSHA256: qualificationSample
    )
    XCTAssertEqual(qualification.outcome, .accepted)
    XCTAssertEqual(
      qualification.ownerProgramFingerprint,
      fixture.identity.programFingerprint
    )
    XCTAssertEqual(
      qualification.appliedRecordFingerprint,
      applied.appliedBuffer.contents()
        .advanced(by: applied.appliedByteOffset)
        .load(as: NBNumanXHumanMatterAppliedOutcomeGPU.self)
        .appliedFingerprint
    )
    XCTAssertEqual(
      qualification.jointCommitFingerprint,
      preflight.jointReceiptFingerprint
    )
    let capturedQualification = try fixture.prepared.qualificationRootExecution(
      capturedSample: capturedSample
    )
    XCTAssertEqual(
      capturedQualification.sampleSHA256,
      capturedSample.sampleSHA256
    )
    XCTAssertEqual(capturedQualification.outcome, .accepted)
    let fence = proposal.fenceBuffer.contents().load(
      as: NBNumanXHumanMatterJointPublicationFenceGPU.self
    )
    XCTAssertEqual(
      fence.status,
      NB_NUMANX_HUMAN_MATTER_PUBLICATION_COMMITTED.rawValue
    )
    XCTAssertEqual(fence.physicsTokenFingerprint, fixture.accepted.fingerprint)
    XCTAssertEqual(fence.jointCommitFingerprint, preflight.jointReceiptFingerprint)
    XCTAssertEqual(fence.brainGeneration, 1)
    XCTAssertEqual(fence.fenceFingerprint, recordFingerprint(fence))
    XCTAssertFalse(fixture.complete.runtime.hasOpenControl)
    XCTAssertThrowsError(
      try fixture.complete.runtime.numanXPreparedJointCommitFingerprint(
        for: fixture.prepared,
        identity: fixture.identity
      )
    )
  }

  func testABI4AggregateReaderCannotObserveInsideJointReleaseGate() throws {
    let fixture = try makePreparedCloseFixture(controlStep: 79)
    let proposal = try makeProposalFixture(fixture, accept: true)
    let ackEvent = try XCTUnwrap(fixture.complete.device.makeSharedEvent())
    let ackTicket = try fixture.complete.runtime.submitNumanXBrainAck(
      fixture.prepared,
      proposal: proposal.lease,
      signal: try MetalSharedEventPoint(event: ackEvent, value: 1)
    )
    try waitForTerminalFeedback(ackTicket)
    let ack = ackTicket.ackLease.buffer.contents().load(
      as: NBNumanXHumanMatterBrainAckGPU.self
    )
    let applied = try makeAppliedLease(
      fixture,
      ack: ack,
      proposal: proposal.proposal,
      accept: true
    )
    let preflight = fixture.prepared.brainCommitPreflightBuffer.contents().load(
      as: NBNumanXHumanMatterBrainCommitPreflightGPU.self
    )
    let gate = BlockingJointResolutionProbe()
    let resolution = try MetalNumanXJointResolutionReservation(
      identity: fixture.identity,
      proposal: proposal.lease,
      applied: applied,
      sensorCandidate: fixture.sensorCandidate,
      jointCommitFingerprint: preflight.jointReceiptFingerprint,
      brainGeneration: 1,
      releaseAccepted: { publish in
        gate.releaseAccepted(publishBrainGeneration: publish, generation: 1)
      },
      releaseRejected: { .released }
    )
    let validationEvent = try XCTUnwrap(fixture.complete.device.makeSharedEvent())
    _ = try fixture.complete.runtime.validateNumanXAppliedRoot(
      fixture.prepared,
      ack: ackTicket,
      applied: applied,
      resolution: resolution,
      signal: try MetalSharedEventPoint(event: validationEvent, value: 1)
    )
    XCTAssertEqual(gate.entered.wait(timeout: .now() + 10), .success)

    let readFinished = DispatchSemaphore(value: 0)
    let observed = GenerationProbe()
    DispatchQueue.global(qos: .userInitiated).async {
      observed.store(fixture.complete.runtime.committedGeneration)
      readFinished.signal()
    }
    XCTAssertEqual(
      readFinished.wait(timeout: .now() + .milliseconds(25)),
      .timedOut
    )
    gate.continuePublication.signal()
    XCTAssertEqual(readFinished.wait(timeout: .now() + 10), .success)
    XCTAssertEqual(waitForCloseTerminalStatus(fixture.prepared), .committed)
    XCTAssertEqual(observed.value, 1)
    XCTAssertEqual(gate.latchedGeneration, 1)
  }

  func testABI4UnexpectedReleaseQuarantinesAndHidesGeneration() throws {
    let fixture = try makePreparedCloseFixture(controlStep: 76)
    let proposal = try makeProposalFixture(fixture, accept: true)
    let ackEvent = try XCTUnwrap(fixture.complete.device.makeSharedEvent())
    let ackTicket = try fixture.complete.runtime.submitNumanXBrainAck(
      fixture.prepared,
      proposal: proposal.lease,
      signal: try MetalSharedEventPoint(event: ackEvent, value: 1)
    )
    try waitForTerminalFeedback(ackTicket)
    let ack = ackTicket.ackLease.buffer.contents().load(
      as: NBNumanXHumanMatterBrainAckGPU.self
    )
    let applied = try makeAppliedLease(
      fixture,
      ack: ack,
      proposal: proposal.proposal,
      accept: true
    )
    let preflight = fixture.prepared.brainCommitPreflightBuffer.contents().load(
      as: NBNumanXHumanMatterBrainCommitPreflightGPU.self
    )
    let probe = JointResolutionProbe(
      acceptedDisposition: .released,
      brainPublicationInvocationCount: 0
    )
    let resolution = try MetalNumanXJointResolutionReservation(
      identity: fixture.identity,
      proposal: proposal.lease,
      applied: applied,
      sensorCandidate: fixture.sensorCandidate,
      jointCommitFingerprint: preflight.jointReceiptFingerprint,
      brainGeneration: 1,
      releaseAccepted: { publish in
        probe.releaseAccepted(publishBrainGeneration: publish, generation: 1)
      },
      releaseRejected: { probe.releaseRejected() }
    )
    let validationEvent = try XCTUnwrap(fixture.complete.device.makeSharedEvent())
    _ = try fixture.complete.runtime.validateNumanXAppliedRoot(
      fixture.prepared,
      ack: ackTicket,
      applied: applied,
      resolution: resolution,
      signal: try MetalSharedEventPoint(event: validationEvent, value: 1)
    )

    XCTAssertEqual(
      waitForCloseTerminalStatus(fixture.prepared),
      .terminalQuarantined
    )
    XCTAssertEqual(fixture.complete.runtime.committedGeneration, 0)
    XCTAssertTrue(fixture.complete.runtime.hasOpenControl)
    XCTAssertEqual(probe.snapshot.accepted, 1)
    XCTAssertFalse(probe.snapshot.externalPublished)
  }

  func testABI4DuplicatePublicationCallbackIsIdempotentAfterExternalRelease()
    throws
  {
    let fixture = try makePreparedCloseFixture(controlStep: 81)
    let proposal = try makeProposalFixture(fixture, accept: true)
    let ackEvent = try XCTUnwrap(fixture.complete.device.makeSharedEvent())
    let ackTicket = try fixture.complete.runtime.submitNumanXBrainAck(
      fixture.prepared,
      proposal: proposal.lease,
      signal: try MetalSharedEventPoint(event: ackEvent, value: 1)
    )
    try waitForTerminalFeedback(ackTicket)
    let ack = ackTicket.ackLease.buffer.contents().load(
      as: NBNumanXHumanMatterBrainAckGPU.self
    )
    let applied = try makeAppliedLease(
      fixture,
      ack: ack,
      proposal: proposal.proposal,
      accept: true
    )
    let preflight = fixture.prepared.brainCommitPreflightBuffer.contents().load(
      as: NBNumanXHumanMatterBrainCommitPreflightGPU.self
    )
    let probe = JointResolutionProbe(brainPublicationInvocationCount: 2)
    let resolution = try MetalNumanXJointResolutionReservation(
      identity: fixture.identity,
      proposal: proposal.lease,
      applied: applied,
      sensorCandidate: fixture.sensorCandidate,
      jointCommitFingerprint: preflight.jointReceiptFingerprint,
      brainGeneration: 1,
      releaseAccepted: { publish in
        probe.releaseAccepted(publishBrainGeneration: publish, generation: 1)
      },
      releaseRejected: { probe.releaseRejected() }
    )
    let validationEvent = try XCTUnwrap(fixture.complete.device.makeSharedEvent())
    _ = try fixture.complete.runtime.validateNumanXAppliedRoot(
      fixture.prepared,
      ack: ackTicket,
      applied: applied,
      resolution: resolution,
      signal: try MetalSharedEventPoint(event: validationEvent, value: 1)
    )

    XCTAssertEqual(waitForCloseTerminalStatus(fixture.prepared), .committed)
    XCTAssertEqual(fixture.complete.runtime.committedGeneration, 1)
    XCTAssertFalse(fixture.complete.runtime.hasOpenControl)
    XCTAssertEqual(probe.snapshot.accepted, 1)
    XCTAssertTrue(probe.snapshot.externalPublished)
    XCTAssertTrue(fixture.prepared.hasPublicationProtocolViolation)
  }

  func testABI4MalformedFinalTokenNeverPublishesOrReleases() throws {
    let fixture = try makePreparedCloseFixture(controlStep: 80)
    let proposal = try makeProposalFixture(fixture, accept: true)
    let ackEvent = try XCTUnwrap(fixture.complete.device.makeSharedEvent())
    let ackTicket = try fixture.complete.runtime.submitNumanXBrainAck(
      fixture.prepared,
      proposal: proposal.lease,
      signal: try MetalSharedEventPoint(event: ackEvent, value: 1)
    )
    try waitForTerminalFeedback(ackTicket)
    let ack = ackTicket.ackLease.buffer.contents().load(
      as: NBNumanXHumanMatterBrainAckGPU.self
    )
    let applied = try makeAppliedLease(
      fixture,
      ack: ack,
      proposal: proposal.proposal,
      accept: true
    )
    var malformed = fixture.accepted.abiRecord
    malformed.physics_state_fingerprint ^= 1
    write(malformed, to: applied.finalTokenBuffer)
    let preflight = fixture.prepared.brainCommitPreflightBuffer.contents().load(
      as: NBNumanXHumanMatterBrainCommitPreflightGPU.self
    )
    let probe = JointResolutionProbe()
    let resolution = try MetalNumanXJointResolutionReservation(
      identity: fixture.identity,
      proposal: proposal.lease,
      applied: applied,
      sensorCandidate: fixture.sensorCandidate,
      jointCommitFingerprint: preflight.jointReceiptFingerprint,
      brainGeneration: 1,
      releaseAccepted: { publish in
        probe.releaseAccepted(publishBrainGeneration: publish, generation: 1)
      },
      releaseRejected: { probe.releaseRejected() }
    )
    let validationEvent = try XCTUnwrap(fixture.complete.device.makeSharedEvent())
    _ = try fixture.complete.runtime.validateNumanXAppliedRoot(
      fixture.prepared,
      ack: ackTicket,
      applied: applied,
      resolution: resolution,
      signal: try MetalSharedEventPoint(event: validationEvent, value: 1)
    )

    XCTAssertEqual(
      waitForCloseTerminalStatus(fixture.prepared),
      .terminalQuarantined
    )
    XCTAssertEqual(fixture.complete.runtime.committedGeneration, 0)
    XCTAssertEqual(probe.snapshot.accepted, 0)
    XCTAssertEqual(probe.snapshot.rejected, 0)
  }

  func testABI4PhysicalRejectRestoresBothBrainHalvesAndSensorCandidate() throws {
    let fixture = try makePreparedCloseFixture(controlStep: 77)
    let proposal = try makeProposalFixture(fixture, accept: false)
    let ackEvent = try XCTUnwrap(fixture.complete.device.makeSharedEvent())
    let ackTicket = try fixture.complete.runtime.submitNumanXBrainAck(
      fixture.prepared,
      proposal: proposal.lease,
      signal: try MetalSharedEventPoint(event: ackEvent, value: 1)
    )
    try waitForTerminalFeedback(ackTicket)
    let ack = ackTicket.ackLease.buffer.contents().load(
      as: NBNumanXHumanMatterBrainAckGPU.self
    )
    XCTAssertEqual(ack.status, NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_REJECT.rawValue)
    XCTAssertEqual(ack.decision, NB_NUMANX_HUMAN_MATTER_ROOT_REJECT.rawValue)
    let applied = try makeAppliedLease(
      fixture,
      ack: ack,
      proposal: proposal.proposal,
      accept: false
    )
    let preflight = fixture.prepared.brainCommitPreflightBuffer.contents().load(
      as: NBNumanXHumanMatterBrainCommitPreflightGPU.self
    )
    let probe = JointResolutionProbe()
    let resolution = try MetalNumanXJointResolutionReservation(
      identity: fixture.identity,
      proposal: proposal.lease,
      applied: applied,
      sensorCandidate: fixture.sensorCandidate,
      jointCommitFingerprint: preflight.jointReceiptFingerprint,
      brainGeneration: 1,
      releaseAccepted: { publish in
        probe.releaseAccepted(publishBrainGeneration: publish, generation: 1)
      },
      releaseRejected: { probe.releaseRejected() }
    )
    let validationEvent = try XCTUnwrap(fixture.complete.device.makeSharedEvent())
    _ = try fixture.complete.runtime.validateNumanXAppliedRoot(
      fixture.prepared,
      ack: ackTicket,
      applied: applied,
      resolution: resolution,
      signal: try MetalSharedEventPoint(event: validationEvent, value: 1)
    )

    XCTAssertEqual(waitForCloseTerminalStatus(fixture.prepared), .aborted)
    XCTAssertEqual(fixture.complete.runtime.committedGeneration, 0)
    XCTAssertEqual(
      fixture.complete.runtime.fastTissue.schedulerCommittedGeneration,
      0
    )
    XCTAssertEqual(
      fixture.complete.runtime.cognitive.agentStateRuntime.arena
        .committedGeneration,
      0
    )
    XCTAssertEqual(probe.snapshot.accepted, 0)
    XCTAssertEqual(probe.snapshot.rejected, 1)
    let qualification = try fixture.prepared.qualificationRootExecution(
      sampleSHA256: BrainPolicyEvidenceArtifact.sha256(
        Data("rejected-root-sample".utf8)
      )
    )
    XCTAssertEqual(qualification.outcome, .rejected)
    XCTAssertEqual(
      qualification.appliedRecordFingerprint,
      applied.appliedBuffer.contents()
        .advanced(by: applied.appliedByteOffset)
        .load(as: NBNumanXHumanMatterAppliedOutcomeGPU.self)
        .appliedFingerprint
    )
    XCTAssertEqual(qualification.jointCommitFingerprint, 0)
    XCTAssertFalse(fixture.complete.runtime.hasOpenControl)
    XCTAssertThrowsError(
      try fixture.complete.runtime.numanXPreparedJointCommitFingerprint(
        for: fixture.prepared,
        identity: fixture.identity
      )
    )
    let reused = try fixture.complete.runtime.beginControl(
      controlStepIdentifier: 78,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 11_000),
      targetTimestamp: BrainTimestamp(microseconds: 12_000),
      cachedDecisionFingerprint: 0x6078
    )
    try fixture.complete.runtime.abortControl(reused)
  }

  func testABI4HandleAcceptClearsOwnershipAndAdmitsNextRoot() throws {
    let fixture = try makeHandlePreparedCloseFixture(controlStep: 82)
    let proposal = try makeProposalFixture(fixture, accept: true)
    let ackEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let ackTicket = try fixture.handle.submitNumanXBrainAck(
      fixture.prepared,
      transaction: fixture.transaction,
      proposal: proposal.lease,
      signal: try MetalSharedEventPoint(event: ackEvent, value: 1)
    )
    try waitForTerminalFeedback(ackTicket)
    let ack = ackTicket.ackLease.buffer.contents().load(
      as: NBNumanXHumanMatterBrainAckGPU.self
    )
    let applied = try makeAppliedLease(
      fixture,
      ack: ack,
      proposal: proposal.proposal,
      accept: true
    )
    let preflight = fixture.prepared.brainCommitPreflightBuffer.contents().load(
      as: NBNumanXHumanMatterBrainCommitPreflightGPU.self
    )
    let probe = JointResolutionProbe()
    let resolution = try MetalNumanXJointResolutionReservation(
      identity: fixture.identity,
      proposal: proposal.lease,
      applied: applied,
      sensorCandidate: fixture.sensorCandidate,
      jointCommitFingerprint: preflight.jointReceiptFingerprint,
      brainGeneration: 1,
      releaseAccepted: { publish in
        probe.releaseAccepted(publishBrainGeneration: publish, generation: 1)
      },
      releaseRejected: { probe.releaseRejected() }
    )
    let validationEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    _ = try fixture.handle.validateNumanXAppliedRoot(
      fixture.prepared,
      transaction: fixture.transaction,
      ack: ackTicket,
      applied: applied,
      resolution: resolution,
      signal: try MetalSharedEventPoint(event: validationEvent, value: 1)
    )

    XCTAssertEqual(waitForCloseTerminalStatus(fixture.prepared), .committed)
    XCTAssertTrue(waitForHandleIdle(fixture.handle))
    XCTAssertEqual(fixture.handle.committedGeneration, 1)
    let next = try fixture.handle.beginControl(
      controlStepIdentifier: 83,
      basePhysicsGeneration: 101,
      committedTimestamp: BrainTimestamp(microseconds: 11_000),
      targetTimestamp: BrainTimestamp(microseconds: 12_000),
      cachedDecisionFingerprint: 0x7083
    )
    try fixture.handle.abortControl(next)
  }

  func testABI4HandleRejectClearsOwnershipAndAdmitsNextRoot() throws {
    let fixture = try makeHandlePreparedCloseFixture(
      controlStep: 84,
      validStartGate: false
    )
    let proposal = try makeProposalFixture(fixture, accept: false)
    let ackEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    let ackTicket = try fixture.handle.submitNumanXBrainAck(
      fixture.prepared,
      transaction: fixture.transaction,
      proposal: proposal.lease,
      signal: try MetalSharedEventPoint(event: ackEvent, value: 1)
    )
    try waitForTerminalFeedback(ackTicket)
    let ack = ackTicket.ackLease.buffer.contents().load(
      as: NBNumanXHumanMatterBrainAckGPU.self
    )
    let applied = try makeAppliedLease(
      fixture,
      ack: ack,
      proposal: proposal.proposal,
      accept: false
    )
    let preflight = fixture.prepared.brainCommitPreflightBuffer.contents().load(
      as: NBNumanXHumanMatterBrainCommitPreflightGPU.self
    )
    let probe = JointResolutionProbe()
    let resolution = try MetalNumanXJointResolutionReservation(
      identity: fixture.identity,
      proposal: proposal.lease,
      applied: applied,
      sensorCandidate: fixture.sensorCandidate,
      jointCommitFingerprint: preflight.jointReceiptFingerprint,
      brainGeneration: 1,
      releaseAccepted: { publish in
        probe.releaseAccepted(publishBrainGeneration: publish, generation: 1)
      },
      releaseRejected: { probe.releaseRejected() }
    )
    let validationEvent = try XCTUnwrap(fixture.device.makeSharedEvent())
    _ = try fixture.handle.validateNumanXAppliedRoot(
      fixture.prepared,
      transaction: fixture.transaction,
      ack: ackTicket,
      applied: applied,
      resolution: resolution,
      signal: try MetalSharedEventPoint(event: validationEvent, value: 1)
    )

    XCTAssertEqual(waitForCloseTerminalStatus(fixture.prepared), .aborted)
    XCTAssertTrue(waitForHandleIdle(fixture.handle))
    XCTAssertEqual(fixture.handle.committedGeneration, 0)
    let next = try fixture.handle.beginControl(
      controlStepIdentifier: 85,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 10_000),
      targetTimestamp: BrainTimestamp(microseconds: 11_000),
      cachedDecisionFingerprint: 0x7085
    )
    try fixture.handle.abortControl(next)
  }

  private func runAcceptedReplay(controlStep: UInt64) throws -> (
    provisional: BrainProvisionalPhysicsAcceptance,
    receipt: BrainJointCommitToken,
    state: TissueGrid,
    relayTimestamps: [BrainTimestamp],
    fastManifest: Data
  ) {
    let runtime = try makeRuntime()
    let token = try runtime.beginInteractiveJointControl(
      controlStepIdentifier: controlStep,
      basePhysicsGeneration: 300,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 1_000)
    )
    let candidate = try runtime.advanceFastSystems(
      candidateDurationMicroseconds: 1_000
    )
    let event = try XCTUnwrap(MTLCreateSystemDefaultDevice()?.makeSharedEvent())
    let ticket = try runtime.submitProvisionalAcceptedFastRoot(
      for: candidate.substep,
      waitFor: try MetalSharedEventPoint(event: event, value: 1),
      signal: try MetalSharedEventPoint(event: event, value: 2)
    )
    event.signaledValue = 1
    _ = try ticket.waitUntilCompleted(timeoutMilliseconds: 10_000)
    let sources = try runtime.makeNumanXPreparedFastStateSources(for: ticket)
    let manifest = try XCTUnwrap(
      sources.max { $0.semanticIdentifier < $1.semanticIdentifier }
    )
    let manifestData = Data(
      bytes: manifest.buffer.contents().advanced(by: manifest.byteOffset),
      count: manifest.byteCount
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: token,
      substep: candidate.substep,
      physicsStateFingerprint: 0xface,
      physicsGeneration: 301
    )
    let prepared = try runtime.prepareProvisionalJointRootTransactionCommit(
      acceptedPhysicsState: accepted,
      provisional: ticket.provisional
    )
    runtime.publishPreparedJointRootTransactionCommit(prepared)
    runtime.releaseResolvedProvisionalFastRootSubmission(ticket)
    return (
      provisional: ticket.provisional,
      receipt: prepared.receipt,
      state: try runtime.snapshotCommitted(),
      relayTimestamps: try runtime.snapshotCommittedRelayHistoryTimestamps(),
      fastManifest: manifestData
    )
  }

  private func fastGateFingerprint(
    _ record: NBNumanXFastPrepareStatusGPU
  ) -> UInt64 {
    recordFingerprint(record)
  }

  private func recordFingerprint<T>(_ record: T) -> UInt64 {
    var record = record
    return withUnsafeBytes(of: &record) { bytes in
      precondition(bytes.count == 128)
      var hash: UInt64 = 14_695_981_039_346_656_037
      for byte in bytes.prefix(120) {
        hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
      }
      return hash == 0 ? 14_695_981_039_346_656_037 : hash
    }
  }

  private func makeRuntime() throws -> MetalTissueRuntime {
    guard MTLCreateSystemDefaultDevice() != nil else {
      throw XCTSkip("Metal device unavailable")
    }
    let compiled = try makeNumanXInteropCompiledTemplate()
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 8,
      height: 8,
      parameters: parameters
    )
    let runtime = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      randomContext: TissueRandomContext(
        seed: 0x4e55_4d49,
        environmentIdentifier: 7,
        episodeIdentifier: 23
      ),
      protectiveMotorProfile: compiled.protectiveMotorProfile,
      numanXMuscleAttachmentCatalog: compiled.muscleAttachmentCatalog,
      somaticSynergyCatalog: compiled.somaticSynergyCatalog,
      schedulerEnvironmentIdentifier: 7,
      maxEncodedSubsteps: 1
    )
    try runtime.bindSpeciesReflexProgram(compiled)
    return runtime
  }

  private struct CompleteFixture {
    let device: any MTLDevice
    let compiled: CompiledSpeciesTemplate
    let runtime: MetalNumiBrainRuntime
    let transaction: MetalNumiBrainRuntime.ControlTransaction
  }

  private struct PreparedCloseFixture {
    let complete: CompleteFixture
    let inputSensors: NumanXSensorPacketLease
    let accepted: AcceptedPhysicsStateToken
    let sensorCandidate: MetalNumanXPendingSensorCandidateLease
    let prepared: MetalNumiBrainRuntime.NumanXPreparedControlTicket
    let identity: MetalNumanXHumanMatterRootIdentity
    let physicalEvent: any MTLSharedEvent
  }

  private struct HandlePreparedCloseFixture {
    let device: any MTLDevice
    let compiled: CompiledSpeciesTemplate
    let handle: MetalNumiBrainHandle
    let transaction: MetalNumiBrainHandle.ControlTransaction
    let accepted: AcceptedPhysicsStateToken
    let sensorCandidate: MetalNumanXPendingSensorCandidateLease
    let prepared: MetalNumiBrainRuntime.NumanXPreparedControlTicket
    let identity: MetalNumanXHumanMatterRootIdentity
  }

  private struct ProposalFixture {
    let lease: MetalNumanXHumanMatterProposalLease
    let fenceBuffer: any MTLBuffer
    let proposal: NBNumanXHumanMatterProposalGPU
  }

  private func waitForPrepareTerminalStatus(
    _ ticket: MetalNumiBrainRuntime.NumanXPreparedControlTicket,
    timeoutSeconds: TimeInterval = 10
  ) -> MetalNumiBrainRuntime.ControlTransaction.Status {
    let deadline = Date(timeIntervalSinceNow: timeoutSeconds)
    var status = ticket.status
    while status == .numanXPrepareSubmitted, Date() < deadline {
      Thread.sleep(forTimeInterval: 0.001)
      status = ticket.status
    }
    return status
  }

  private func waitForCloseTerminalStatus(
    _ ticket: MetalNumiBrainRuntime.NumanXPreparedControlTicket,
    timeoutSeconds: TimeInterval = 10
  ) -> MetalNumiBrainRuntime.ControlTransaction.Status {
    let deadline = Date(timeIntervalSinceNow: timeoutSeconds)
    var status = ticket.status
    while status != .committed, status != .aborted,
      status != .terminalQuarantined,
      status != .numanXAppliedValidationRetryRequired,
      Date() < deadline
    {
      Thread.sleep(forTimeInterval: 0.001)
      status = ticket.status
    }
    return status
  }

  private func waitForHandleIdle(
    _ handle: MetalNumiBrainHandle,
    timeoutSeconds: TimeInterval = 10
  ) -> Bool {
    let deadline = Date(timeIntervalSinceNow: timeoutSeconds)
    while handle.hasOpenControl, Date() < deadline {
      Thread.sleep(forTimeInterval: 0.001)
    }
    return !handle.hasOpenControl
  }

  private func waitForTerminalFeedback(
    _ ticket: MetalNumanXHumanMatterBrainAckTicket,
    timeoutSeconds: TimeInterval = 10
  ) throws {
    let deadline = Date(timeIntervalSinceNow: timeoutSeconds)
    while Date() < deadline {
      if try ticket.completionFeedbackIfAvailable() != nil { return }
      Thread.sleep(forTimeInterval: 0.001)
    }
    XCTFail("NumanX Brain ACK did not complete")
  }

  private func expectedPreparedJointCommitFingerprint(
    _ fixture: PreparedCloseFixture
  ) -> UInt64 {
    let token = fixture.complete.transaction.token
    var receipt = NBJointCommitToken()
    receipt.transaction_fingerprint = token.fingerprint
    receipt.accepted_physics_token_fingerprint = fixture.accepted.fingerprint
    receipt.brain_generation = token.shadowGeneration
    receipt.physics_generation = fixture.accepted.physicsGeneration
    receipt.committed_timestamp_microseconds = token.targetTimestamp.rawValue
    receipt.parameter_version_fingerprint = token.parameterVersionFingerprint
    receipt.environment_identifier = token.environmentIdentifier
    receipt.flags = 0
    receipt.commit_fingerprint = withUnsafePointer(to: &receipt) {
      nb_brain_abi_joint_commit_fingerprint($0)
    }
    return MetalNumanXPendingSensorCandidateLease.jointCloseFingerprint(
      receiptFingerprint: receipt.commit_fingerprint,
      sensorCandidateFingerprint:
        fixture.sensorCandidate.publicationFingerprint
    )
  }

  private func makePreparedCloseFixture(
    controlStep: UInt64,
    validStartGate: Bool = true,
    settle: Bool = true
  ) throws -> PreparedCloseFixture {
    let complete = try makeCompleteFixture(
      controlStep: controlStep,
      environmentIdentifier: 0
    )
    let initialSensors = try makeSensorPacket(
      device: complete.device,
      compiled: complete.compiled,
      token: complete.transaction.token,
      acceptedPhysicsState: nil
    )
    _ = try complete.runtime.inferAndDecide(
      complete.transaction,
      numanXSensors: initialSensors
    )
    let candidate = try complete.runtime.advanceFastSystems(
      complete.transaction,
      candidateDurationMicroseconds: 1_000
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: complete.transaction.token,
      substep: candidate.substep,
      physicsStateFingerprint: 0xc000 | controlStep,
      physicsGeneration: 101
    )
    let gateBuffer = try sharedBuffer(
      complete.device,
      byteCount: MetalAcceptedPhysicsGateLease.byteCount
    )
    gateBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: gateBuffer.length
    )
    if validStartGate { write(accepted.abiRecord, to: gateBuffer) }
    let physicalEvent = try XCTUnwrap(complete.device.makeSharedEvent())
    let fastEvent = try XCTUnwrap(complete.device.makeSharedEvent())
    let brainEvent = try XCTUnwrap(complete.device.makeSharedEvent())
    let preflightEvent = try XCTUnwrap(complete.device.makeSharedEvent())
    let fastTicket = try complete.runtime.submitProvisionalAcceptedFastRoot(
      complete.transaction,
      waitFor: try MetalSharedEventPoint(event: physicalEvent, value: 1),
      signal: try MetalSharedEventPoint(event: fastEvent, value: 1)
    )
    let identity = try MetalNumanXHumanMatterRootIdentity(
      programFingerprint: 0x4855_4d41_4e4d_4154,
      transactionFingerprint: complete.transaction.token.fingerprint,
      linearizationEpoch: 0x1000 | controlStep,
      slotGeneration: 0x2000 | controlStep,
      transactionSlot: UInt32(truncatingIfNeeded: controlStep),
      environment: 0,
      controlStep: try XCTUnwrap(UInt32(exactly: controlStep))
    )
    let acceptedSensors = try makeSensorPacket(
      device: complete.device,
      compiled: complete.compiled,
      token: complete.transaction.token,
      acceptedPhysicsState: accepted
    )
    let sensorCandidate = try makePendingSensorCandidate(
      acceptedSensors,
      transaction: complete.transaction.token,
      acceptedBrainGeneration: fastTicket.provisional.shadowGeneration,
      salt: controlStep
    )
    let prepared = try complete.runtime.submitNumanXPreparedControl(
      complete.transaction,
      provisionalFast: fastTicket,
      identity: identity,
      acceptedPhysicsGate: try MetalAcceptedPhysicsGateLease(
        buffer: gateBuffer
      ),
      sensorCandidate: sensorCandidate,
      signal: try MetalSharedEventPoint(event: brainEvent, value: 1),
      thenSignal: try MetalSharedEventPoint(event: preflightEvent, value: 1)
    )
    if settle {
      physicalEvent.signaledValue = 1
      _ = try prepared.waitUntilBrainPrepareCompleted(
        timeoutMilliseconds: 10_000
      )
      XCTAssertEqual(
        waitForPrepareTerminalStatus(prepared),
        validStartGate ? .numanXPreflightReady : .numanXPreflightFailed
      )
    }
    return PreparedCloseFixture(
      complete: complete,
      inputSensors: initialSensors,
      accepted: accepted,
      sensorCandidate: sensorCandidate,
      prepared: prepared,
      identity: identity,
      physicalEvent: physicalEvent
    )
  }

  private func makeHandlePreparedCloseFixture(
    controlStep: UInt64,
    validStartGate: Bool = true
  ) throws -> HandlePreparedCloseFixture {
    guard let device = MTLCreateSystemDefaultDevice(),
      device.makeMTL4CommandQueue() != nil,
      device.makeCommandAllocator() != nil,
      device.makeCommandBuffer() != nil
    else {
      throw XCTSkip("Metal 4 execution is unavailable")
    }
    let compiled = try makeNumanXInteropCompiledTemplate()
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
        environmentIdentifier: 0,
        episodeIdentifier: 23
      ),
      schedulerEnvironmentIdentifier: 0,
      maximumEncodedSubsteps: 1
    )
    let handle = try MetalNumiBrainHandle.create(
      configuration: configuration,
      publication: publication,
      device: device
    )
    let transaction = try handle.beginControl(
      controlStepIdentifier: controlStep,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 10_000),
      targetTimestamp: BrainTimestamp(microseconds: 11_000),
      cachedDecisionFingerprint: 0x7000 + controlStep
    )
    let initialSensors = try makeSensorPacket(
      device: device,
      compiled: compiled,
      token: transaction.token,
      acceptedPhysicsState: nil
    )
    _ = try handle.inferAndDecide(
      transaction,
      numanXSensors: initialSensors
    )
    let candidate = try handle.advanceFastSystems(
      transaction,
      candidateDurationMicroseconds: 1_000
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: transaction.token,
      substep: candidate.substep,
      physicsStateFingerprint: 0xd000 | controlStep,
      physicsGeneration: 101
    )
    let gateBuffer = try sharedBuffer(
      device,
      byteCount: MetalAcceptedPhysicsGateLease.byteCount
    )
    gateBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: gateBuffer.length
    )
    if validStartGate { write(accepted.abiRecord, to: gateBuffer) }
    let physicalEvent = try XCTUnwrap(device.makeSharedEvent())
    let fastEvent = try XCTUnwrap(device.makeSharedEvent())
    let brainEvent = try XCTUnwrap(device.makeSharedEvent())
    let preflightEvent = try XCTUnwrap(device.makeSharedEvent())
    let fastTicket = try handle.submitProvisionalAcceptedFastRoot(
      transaction,
      waitFor: try MetalSharedEventPoint(event: physicalEvent, value: 1),
      signal: try MetalSharedEventPoint(event: fastEvent, value: 1)
    )
    let identity = try MetalNumanXHumanMatterRootIdentity(
      programFingerprint: 0x4855_4d41_4e4d_4154,
      transactionFingerprint: transaction.token.fingerprint,
      linearizationEpoch: 0x3000 | controlStep,
      slotGeneration: 0x4000 | controlStep,
      transactionSlot: UInt32(truncatingIfNeeded: controlStep),
      environment: 0,
      controlStep: try XCTUnwrap(UInt32(exactly: controlStep))
    )
    let acceptedSensors = try makeSensorPacket(
      device: device,
      compiled: compiled,
      token: transaction.token,
      acceptedPhysicsState: accepted
    )
    let sensorCandidate = try makePendingSensorCandidate(
      acceptedSensors,
      transaction: transaction.token,
      acceptedBrainGeneration: fastTicket.provisional.shadowGeneration,
      salt: controlStep
    )
    let prepared = try handle.submitNumanXPreparedControl(
      transaction,
      provisionalFast: fastTicket,
      identity: identity,
      acceptedPhysicsGate: try MetalAcceptedPhysicsGateLease(
        buffer: gateBuffer
      ),
      sensorCandidate: sensorCandidate,
      signal: try MetalSharedEventPoint(event: brainEvent, value: 1),
      thenSignal: try MetalSharedEventPoint(event: preflightEvent, value: 1)
    )
    physicalEvent.signaledValue = 1
    _ = try prepared.waitUntilBrainPrepareCompleted(
      timeoutMilliseconds: 10_000
    )
    XCTAssertEqual(
      waitForPrepareTerminalStatus(prepared),
      validStartGate ? .numanXPreflightReady : .numanXPreflightFailed
    )
    return HandlePreparedCloseFixture(
      device: device,
      compiled: compiled,
      handle: handle,
      transaction: transaction,
      accepted: accepted,
      sensorCandidate: sensorCandidate,
      prepared: prepared,
      identity: identity
    )
  }

  private func makeProposalFixture(
    _ fixture: PreparedCloseFixture,
    accept: Bool
  ) throws -> ProposalFixture {
    try makeProposalFixture(
      identity: fixture.identity,
      accepted: fixture.accepted,
      prepared: fixture.prepared,
      device: fixture.complete.device,
      candidatePublicationFingerprint:
        fixture.sensorCandidate.candidatePublicationFingerprint,
      humanIOIdentityFingerprint:
        fixture.sensorCandidate.candidateIdentityFingerprint,
      accept: accept
    )
  }

  private func makeProposalFixture(
    _ fixture: HandlePreparedCloseFixture,
    accept: Bool
  ) throws -> ProposalFixture {
    try makeProposalFixture(
      identity: fixture.identity,
      accepted: fixture.accepted,
      prepared: fixture.prepared,
      device: fixture.device,
      candidatePublicationFingerprint:
        fixture.sensorCandidate.candidatePublicationFingerprint,
      humanIOIdentityFingerprint:
        fixture.sensorCandidate.candidateIdentityFingerprint,
      accept: accept
    )
  }

  private func makeProposalFixture(
    identity: MetalNumanXHumanMatterRootIdentity,
    accepted: AcceptedPhysicsStateToken,
    prepared: MetalNumiBrainRuntime.NumanXPreparedControlTicket,
    device: any MTLDevice,
    candidatePublicationFingerprint: UInt64,
    humanIOIdentityFingerprint: UInt64,
    accept: Bool
  ) throws -> ProposalFixture {
    let witness = try XCTUnwrap(
      prepared.cognitiveTicket.numanXPrepareEvaluation
    ).witnessBuffer.contents().load(
      as: NBNumanXHumanMatterBrainCommitWitness.self
    )
    var proposal = NBNumanXHumanMatterProposalGPU()
    proposal.abiVersion = UInt32(NB_NUMANX_HUMAN_MATTER_ABI_VERSION)
    proposal.status = NB_NUMANX_HUMAN_MATTER_PROPOSAL_READY.rawValue
    proposal.decision = accept
      ? NB_NUMANX_HUMAN_MATTER_ROOT_ACCEPT.rawValue
      : NB_NUMANX_HUMAN_MATTER_ROOT_REJECT.rawValue
    proposal.code = accept
      ? NB_NUMANX_HUMAN_MATTER_PROPOSAL_SUCCESS.rawValue
      : NB_NUMANX_HUMAN_MATTER_PROPOSAL_PHYSICAL_REJECT.rawValue
    proposal.programFingerprint = identity.programFingerprint
    proposal.transactionFingerprint = identity.transactionFingerprint
    proposal.linearizationEpoch = identity.linearizationEpoch
    proposal.slotGeneration = identity.slotGeneration
    proposal.physicsTokenFingerprint = accept ? accepted.fingerprint : 0
    if accept {
      proposal.brainProgramFingerprint = witness.brainProgramFingerprint
      proposal.brainShadowStateFingerprint = witness.brainShadowStateFingerprint
      proposal.brainWitnessFingerprint = witness.witnessFingerprint
    }
    proposal.candidatePublicationFingerprint = candidatePublicationFingerprint
    proposal.humanIOIdentityFingerprint = humanIOIdentityFingerprint
    proposal.environment = identity.environment
    proposal.stepIndex = identity.stepIndex
    proposal.substepIndex = identity.substepIndex
    proposal.transactionSlot = identity.transactionSlot
    proposal.physicsSubstepCount = identity.physicsSubstepCount
    proposal.controlStep = identity.controlStep
    proposal.proposalFingerprint = recordFingerprint(proposal)

    let proposalBuffer = try sharedBuffer(device, byteCount: 128)
    let tokenBuffer = try sharedBuffer(device, byteCount: 64)
    let fenceBuffer = try sharedBuffer(device, byteCount: 128)
    write(proposal, to: proposalBuffer)
    write(
      accept ? accepted.abiRecord : NBAcceptedPhysicsStateToken(),
      to: tokenBuffer
    )
    let event = try XCTUnwrap(device.makeSharedEvent())
    let point = try MetalSharedEventPoint(event: event, value: 1)
    let lease = try MetalNumanXHumanMatterProposalLease(
      identity: identity,
      proposalBuffer: proposalBuffer,
      proposalGPUAddress: proposalBuffer.gpuAddress,
      proposalStride: 1,
      proposedTokenBuffer: tokenBuffer,
      proposedTokenGPUAddress: tokenBuffer.gpuAddress,
      proposedTokenStride: 64,
      publicationFenceBuffer: fenceBuffer,
      publicationFenceGPUAddress: fenceBuffer.gpuAddress,
      publicationFenceStride: 1,
      readyPoint: point
    )
    event.signaledValue = 1
    return ProposalFixture(
      lease: lease,
      fenceBuffer: fenceBuffer,
      proposal: proposal
    )
  }

  private func makeAppliedLease(
    _ fixture: PreparedCloseFixture,
    ack: NBNumanXHumanMatterBrainAckGPU,
    proposal: NBNumanXHumanMatterProposalGPU,
    accept: Bool
  ) throws -> MetalNumanXHumanMatterAppliedLease {
    try makeAppliedLease(
      identity: fixture.identity,
      accepted: fixture.accepted,
      device: fixture.complete.device,
      ack: ack,
      proposal: proposal,
      accept: accept
    )
  }

  private func makeAppliedLease(
    _ fixture: HandlePreparedCloseFixture,
    ack: NBNumanXHumanMatterBrainAckGPU,
    proposal: NBNumanXHumanMatterProposalGPU,
    accept: Bool
  ) throws -> MetalNumanXHumanMatterAppliedLease {
    try makeAppliedLease(
      identity: fixture.identity,
      accepted: fixture.accepted,
      device: fixture.device,
      ack: ack,
      proposal: proposal,
      accept: accept
    )
  }

  private func makeAppliedLease(
    identity: MetalNumanXHumanMatterRootIdentity,
    accepted: AcceptedPhysicsStateToken,
    device: any MTLDevice,
    ack: NBNumanXHumanMatterBrainAckGPU,
    proposal: NBNumanXHumanMatterProposalGPU,
    accept: Bool
  ) throws -> MetalNumanXHumanMatterAppliedLease {
    var applied = NBNumanXHumanMatterAppliedOutcomeGPU()
    applied.abiVersion = UInt32(NB_NUMANX_HUMAN_MATTER_ABI_VERSION)
    applied.status = accept
      ? NB_NUMANX_HUMAN_MATTER_APPLIED_ACCEPT_QUARANTINED.rawValue
      : NB_NUMANX_HUMAN_MATTER_APPLIED_REJECT_RESTORED.rawValue
    applied.decision = accept
      ? NB_NUMANX_HUMAN_MATTER_ROOT_ACCEPT.rawValue
      : NB_NUMANX_HUMAN_MATTER_ROOT_REJECT.rawValue
    applied.code = accept
      ? NB_NUMANX_HUMAN_MATTER_APPLIED_SUCCESS.rawValue
      : NB_NUMANX_HUMAN_MATTER_APPLIED_PHYSICAL_REJECT.rawValue
    applied.programFingerprint = identity.programFingerprint
    applied.transactionFingerprint = identity.transactionFingerprint
    applied.linearizationEpoch = identity.linearizationEpoch
    applied.slotGeneration = identity.slotGeneration
    applied.physicsTokenFingerprint = accept ? accepted.fingerprint : 0
    applied.proposalFingerprint = proposal.proposalFingerprint
    applied.ackFingerprint = ack.ackFingerprint
    applied.preflightFingerprint = ack.preflightFingerprint
    applied.fastGateFingerprint = ack.fastGateFingerprint
    applied.matterApplyFingerprint = 0x4d41_5454_4150_504c
    applied.environment = identity.environment
    applied.stepIndex = identity.stepIndex
    applied.substepIndex = identity.substepIndex
    applied.transactionSlot = identity.transactionSlot
    applied.physicsSubstepCount = identity.physicsSubstepCount
    applied.controlStep = identity.controlStep
    applied.appliedFingerprint = recordFingerprint(applied)
    let appliedBuffer = try sharedBuffer(device, byteCount: 128)
    let tokenBuffer = try sharedBuffer(device, byteCount: 64)
    write(applied, to: appliedBuffer)
    write(
      accept ? accepted.abiRecord : NBAcceptedPhysicsStateToken(),
      to: tokenBuffer
    )
    let event = try XCTUnwrap(device.makeSharedEvent())
    let point = try MetalSharedEventPoint(event: event, value: 1)
    let lease = try MetalNumanXHumanMatterAppliedLease(
      identity: identity,
      appliedBuffer: appliedBuffer,
      appliedGPUAddress: appliedBuffer.gpuAddress,
      appliedStride: 1,
      finalTokenBuffer: tokenBuffer,
      finalTokenGPUAddress: tokenBuffer.gpuAddress,
      finalTokenStride: 64,
      readyPoint: point,
      commandDisposition: accept
        ? .acceptedPendingPublication : .rejectedReleased
    )
    event.signaledValue = 1
    return lease
  }

  private func sharedBuffer(
    _ device: any MTLDevice,
    byteCount: Int
  ) throws -> any MTLBuffer {
    try XCTUnwrap(
      device.makeBuffer(
        length: byteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    )
  }

  private func write<T>(_ value: T, to buffer: any MTLBuffer) {
    var value = value
    withUnsafeBytes(of: &value) { bytes in
      precondition(bytes.count <= buffer.length)
      buffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
  }

  private func makeCompleteFixture(
    controlStep: UInt64,
    environmentIdentifier: UInt32 = 7
  ) throws -> CompleteFixture {
    guard let device = MTLCreateSystemDefaultDevice(),
      device.makeMTL4CommandQueue() != nil,
      device.makeCommandAllocator() != nil,
      device.makeCommandBuffer() != nil
    else {
      throw XCTSkip("Metal 4 execution is unavailable")
    }
    let compiled = try makeNumanXInteropCompiledTemplate()
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: compiled.species,
      tissueParameters: parameters
    )
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 8,
      height: 8,
      parameters: parameters
    )
    let runtime = try MetalNumiBrainRuntime.makeRuntime(
      configuration: MetalNumiBrainConfiguration(
        initialTissueState: initial,
        tissueParameters: parameters,
        tissueStimulus: .none,
        compiledSpeciesTemplate: compiled,
        randomContext: TissueRandomContext(
          seed: 0x4e55_4d49,
          environmentIdentifier: environmentIdentifier,
          episodeIdentifier: 23
        ),
        schedulerEnvironmentIdentifier: environmentIdentifier,
        maximumEncodedSubsteps: 1
      ),
      publication: publication,
      device: device
    )
    let transaction = try runtime.beginControl(
      controlStepIdentifier: controlStep,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 10_000),
      targetTimestamp: BrainTimestamp(microseconds: 11_000),
      cachedDecisionFingerprint: 0x6000 + controlStep
    )
    return CompleteFixture(
      device: device,
      compiled: compiled,
      runtime: runtime,
      transaction: transaction
    )
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
          scalars[index] = Float(sensorIndex + 1) * 0.125
            + Float(index) * 0.03125
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

  private func makePendingSensorCandidate(
    _ packet: NumanXSensorPacketLease,
    transaction: BrainJointTransactionToken,
    acceptedBrainGeneration: UInt64,
    salt: UInt64 = 1
  ) throws -> MetalNumanXPendingSensorCandidateLease {
    let sensorGeneration = acceptedBrainGeneration &+ salt
    let humanIOProgramFingerprint = 0x4855_4d41_4e49_4f00 ^ salt
    let sensorFingerprint = 0x5345_4e53_4f52_0000 ^ salt
    let transactionInstanceFingerprint =
      transaction.fingerprint ^ 0x494e_5354_414e_4345 ^ salt
    let key = try MetalNumanXHumanIOCandidateKey(
      transactionFingerprint: transaction.fingerprint,
      programFingerprint: humanIOProgramFingerprint,
      sensorFingerprint: sensorFingerprint,
      transactionInstanceFingerprint: transactionInstanceFingerprint,
      sensorGeneration: sensorGeneration,
      commandBufferIdentity: 0x4342_4944_0000_0000 ^ salt
    )
    let channels = try packet.rawSensors.map { sensor in
      let deliveryTimestamp = packet.packet.deliveryTimestamp
      let latency = deliveryTimestamp.rawValue -
        sensor.view.receptorTimestamp.rawValue
      guard let latencyMicroseconds = UInt32(exactly: latency),
        latencyMicroseconds > 0
      else {
        throw TissueError.transaction("fixture sensor timing is invalid")
      }
      let valueRange = try MetalNumanXHumanIOCandidateRangeLease(
        buffer: sensor.buffer,
        metalBufferObject: Unmanaged.passUnretained(
          sensor.buffer as AnyObject
        ).toOpaque(),
        gpuAddress: sensor.view.gpuAddress,
        byteOffset: 0,
        byteCount: sensor.view.byteCount,
        elementType: MetalNumanXHumanIOCandidateRangeLease.float32ElementType,
        elementByteCount: UInt32(MemoryLayout<Float>.stride)
      )
      let validityRange = try sensor.validityBuffer.map { validity in
        try MetalNumanXHumanIOCandidateRangeLease(
          buffer: validity,
          metalBufferObject: Unmanaged.passUnretained(
            validity as AnyObject
          ).toOpaque(),
          gpuAddress: sensor.view.validityGPUAddress,
          byteOffset: 0,
          byteCount: sensor.view.validityByteCount,
          elementType: MetalNumanXHumanIOCandidateRangeLease.uint32ElementType,
          elementByteCount: UInt32(MemoryLayout<UInt32>.stride)
        )
      }
      return try MetalNumanXHumanIOSensorCandidateChannel(
        modality: sensor.view.modality,
        receptorTimestamp: sensor.view.receptorTimestamp,
        deliveryTimestamp: deliveryTimestamp,
        latencyMicroseconds: latencyMicroseconds,
        sampleIntervalMicroseconds: latencyMicroseconds,
        receptorCount: sensor.view.receptorCount,
        featureDimension: sensor.view.featureDimension,
        values: valueRange,
        validity: validityRange
      )
    }
    let bridgeCandidate = try MetalNumanXHumanIOPendingCandidateView(
      abiVersion: MetalNumanXHumanIOPendingCandidateView.abiVersion,
      transactionFingerprint: transaction.fingerprint,
      acceptedBrainGeneration: acceptedBrainGeneration,
      sensorGeneration: sensorGeneration,
      humanIOProgramFingerprint: humanIOProgramFingerprint,
      sensorFingerprint: sensorFingerprint,
      transactionInstanceFingerprint: transactionInstanceFingerprint,
      candidateKey: key,
      candidateKeyFingerprint: key.fingerprint,
      candidatePublicationFingerprint: 0x4350_5542_0000_0000 ^ salt,
      candidateIdentityFingerprint: 0x4349_4446_0000_0000 ^ salt,
      deviceRegistryID: try XCTUnwrap(packet.rawSensors.first).buffer.device
        .registryID,
      channels: channels,
      retainedOwner: NSObject()
    )
    return try MetalNumanXPendingSensorCandidateLease(
      bridgeCandidate: bridgeCandidate
    )
  }
}

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

  func testAcceptedNociceptionAndReliefMatchCPUOracle() throws {
    let compiled = try makeNumanXInteropCompiledTemplate(
      touchReceptorCount: 1,
      touchFeatureDimension: 1,
      includeTouchNociceptionBinding: true
    )
    let fixture = try makeFixture(compiledSpeciesTemplate: compiled)
    let first = try runAcceptedRoot(
      fixture: fixture,
      token: fixture.token,
      touchNociceptionValue: 0.8,
      cachedDecisionFingerprint: 0x5eed_1001
    )
    let affectSection = fixture.runtime.agentStateRuntime.arena.layout.section(
      .affectiveState
    )
    XCTAssertEqual(affectSection.elementStride, 64)

    func float(_ payload: MetalAgentStateRuntime.CheckpointPayload, _ offset: Int) -> Float {
      payload.hotState.withUnsafeBytes {
        $0.loadUnaligned(
          fromByteOffset: affectSection.byteOffset + offset,
          as: Float.self
        )
      }
    }
    func mask(_ payload: MetalAgentStateRuntime.CheckpointPayload) -> UInt16 {
      payload.hotState.withUnsafeBytes {
        $0.loadUnaligned(
          fromByteOffset: affectSection.byteOffset + 36,
          as: UInt16.self
        )
      }
    }
    func timestamp(_ payload: MetalAgentStateRuntime.CheckpointPayload) -> UInt64 {
      payload.hotState.withUnsafeBytes {
        $0.loadUnaligned(
          fromByteOffset: affectSection.byteOffset + 40,
          as: UInt64.self
        )
      }
    }
    func cpuSample(
      from payload: MetalAgentStateRuntime.CheckpointPayload,
      targetTimestamp: UInt64,
      nociceptionTimestamp: UInt64
    ) throws -> AffectivePhysiologySample {
      let directNociception = float(payload, 12)
      let painEvent = float(payload, 0) > directNociception
        ? float(payload, 0) : nil
      return try AffectivePhysiologySample(
        nociceptionTimestamp: BrainTimestamp(microseconds: nociceptionTimestamp),
        painEventTimestamp: painEvent.map {
          _ in BrainTimestamp(microseconds: targetTimestamp)
        },
        nociception: directNociception,
        painEvent: painEvent
      )
    }

    let cpuPain = try AffectiveState.neutral(
      at: BrainTimestamp(microseconds: 10_000)
    ).advanced(
      to: BrainTimestamp(microseconds: 11_000),
      sample: cpuSample(
        from: first, targetTimestamp: 11_000, nociceptionTimestamp: 10_750
      )
    )
    XCTAssertEqual(float(first, 0), cpuPain.pain, accuracy: 1.0e-5)
    XCTAssertEqual(float(first, 4), cpuPain.pleasure, accuracy: 1.0e-5)
    XCTAssertEqual(float(first, 8), cpuPain.relief, accuracy: 1.0e-5)
    XCTAssertEqual(mask(first) & (1 << 5), 1 << 5)
    XCTAssertEqual(timestamp(first), 11_000)

    let nextToken = try BrainJointTransactionToken(
      environmentIdentifier: fixture.token.environmentIdentifier,
      episodeIdentifier: fixture.token.episodeIdentifier,
      controlStepIdentifier: fixture.token.controlStepIdentifier + 1,
      parameterVersionFingerprint: fixture.token.parameterVersionFingerprint,
      baseBrainGeneration: 1,
      basePhysicsGeneration: 101,
      committedTimestamp: BrainTimestamp(microseconds: 11_000),
      targetTimestamp: BrainTimestamp(microseconds: 12_000),
      randomCounterGeneration: 1
    )
    let second = try runAcceptedRoot(
      fixture: fixture,
      token: nextToken,
      touchNociceptionValue: 0.2,
      cachedDecisionFingerprint: 0x5eed_1002
    )
    let cpuRelief = try cpuPain.advanced(
      to: BrainTimestamp(microseconds: 12_000),
      sample: cpuSample(
        from: second, targetTimestamp: 12_000, nociceptionTimestamp: 11_750
      )
    )
    XCTAssertEqual(float(second, 0), cpuRelief.pain, accuracy: 1.0e-5)
    XCTAssertEqual(float(second, 4), cpuRelief.pleasure, accuracy: 1.0e-5)
    XCTAssertEqual(float(second, 8), cpuRelief.relief, accuracy: 1.0e-5)
    XCTAssertEqual(mask(second) & (1 << 5), 1 << 5)
    XCTAssertEqual(timestamp(second), 12_000)
  }

  func testTypedNumanXInteroceptionRecoveryMatchesCPUAndOpaqueFeaturesStayInactive()
    throws
  {
    let schemaFingerprint =
      InteroceptiveFeatureSchema.NumanXFullBodyV1.fingerprint
    let typedTemplate = try makeNumanXInteropCompiledTemplate(
      interoceptorCount: 1,
      interoceptionFeatureDimension: InteroceptiveFeatureSchema
        .NumanXFullBodyV1.featureDimension,
      interoceptionFeatureSchemaFingerprint: schemaFingerprint
    )
    let fixture = try makeFixture(compiledSpeciesTemplate: typedTemplate)
    let firstValues: [Float] = [0, 0, 0, 0, 1, 1]
    let first = try runAcceptedRoot(
      fixture: fixture,
      token: fixture.token,
      touchNociceptionValue: nil,
      interoceptionValues: firstValues,
      cachedDecisionFingerprint: 0xaffe_0101
    )
    let secondToken = try BrainJointTransactionToken(
      environmentIdentifier: fixture.token.environmentIdentifier,
      episodeIdentifier: fixture.token.episodeIdentifier,
      controlStepIdentifier: fixture.token.controlStepIdentifier + 1,
      parameterVersionFingerprint: fixture.token.parameterVersionFingerprint,
      baseBrainGeneration: 1,
      basePhysicsGeneration: 101,
      committedTimestamp: BrainTimestamp(microseconds: 11_000),
      targetTimestamp: BrainTimestamp(microseconds: 12_000),
      randomCounterGeneration: 1
    )
    let secondValues: [Float] = [1, 1, 0, 0, 0, 0]
    let second = try runAcceptedRoot(
      fixture: fixture,
      token: secondToken,
      touchNociceptionValue: nil,
      interoceptionValues: secondValues,
      cachedDecisionFingerprint: 0xaffe_0102
    )
    let affectSection = fixture.runtime.agentStateRuntime.arena.layout.section(
      .affectiveState
    )
    func affectFloat(
      _ payload: MetalAgentStateRuntime.CheckpointPayload,
      _ offset: Int
    ) -> Float {
      payload.hotState.withUnsafeBytes {
        $0.loadUnaligned(
          fromByteOffset: affectSection.byteOffset + offset,
          as: Float.self
        )
      }
    }
    func affectMask(_ payload: MetalAgentStateRuntime.CheckpointPayload) -> UInt16 {
      payload.hotState.withUnsafeBytes {
        $0.loadUnaligned(
          fromByteOffset: affectSection.byteOffset + 36,
          as: UInt16.self
        )
      }
    }
    func cpuSample(_ values: [Float], at timestamp: UInt64) throws
      -> AffectivePhysiologySample
    {
      try AffectivePhysiologySample(
        interoceptionTimestamp: BrainTimestamp(microseconds: timestamp),
        energyDeficit: 1 - values[0],
        respiratoryDeficit: max(1 - values[1], values[2]),
        temperatureDeviation: abs(values[3]),
        fatigue: values[4],
        tissueDamage: values[5]
      )
    }
    let cpuFirst = try AffectiveState.neutral(
      at: BrainTimestamp(microseconds: 0)
    ).advanced(
      to: BrainTimestamp(microseconds: 11_000),
      sample: cpuSample(firstValues, at: 10_000)
    )
    let cpuSecond = try cpuFirst.advanced(
      to: BrainTimestamp(microseconds: 12_000),
      sample: cpuSample(secondValues, at: 11_000)
    )
    XCTAssertEqual(affectMask(first) & 0x1f, 0x1f)
    XCTAssertEqual(affectFloat(first, 0), cpuFirst.pain, accuracy: 1.0e-5)
    XCTAssertEqual(affectFloat(first, 4), cpuFirst.pleasure, accuracy: 1.0e-5)
    XCTAssertEqual(affectFloat(first, 16), cpuFirst.sourceEvidence[0], accuracy: 1.0e-5)
    XCTAssertEqual(affectFloat(first, 20), cpuFirst.sourceEvidence[1], accuracy: 1.0e-5)
    XCTAssertEqual(affectFloat(first, 24), cpuFirst.sourceEvidence[2], accuracy: 1.0e-5)
    XCTAssertEqual(affectFloat(first, 28), cpuFirst.sourceEvidence[3], accuracy: 1.0e-5)
    XCTAssertEqual(affectFloat(first, 32), cpuFirst.sourceEvidence[4], accuracy: 1.0e-5)
    XCTAssertEqual(affectMask(second) & 0x1f, 0x1f)
    XCTAssertEqual(affectFloat(second, 0), cpuSecond.pain, accuracy: 1.0e-5)
    XCTAssertEqual(affectFloat(second, 4), cpuSecond.pleasure, accuracy: 1.0e-5)
    XCTAssertEqual(affectFloat(second, 8), cpuSecond.relief, accuracy: 1.0e-5)
    XCTAssertEqual(cpuSecond.pleasure, 0.84, accuracy: 1.0e-5)

    let thirdToken = try BrainJointTransactionToken(
      environmentIdentifier: fixture.token.environmentIdentifier,
      episodeIdentifier: fixture.token.episodeIdentifier,
      controlStepIdentifier: fixture.token.controlStepIdentifier + 2,
      parameterVersionFingerprint: fixture.token.parameterVersionFingerprint,
      baseBrainGeneration: 2,
      basePhysicsGeneration: 102,
      committedTimestamp: BrainTimestamp(microseconds: 12_000),
      targetTimestamp: BrainTimestamp(microseconds: 13_000),
      randomCounterGeneration: 2
    )
    let invalidTemperatureValues: [Float] = [1, 1, 0, 2, 0, 0]
    let third = try runAcceptedRoot(
      fixture: fixture,
      token: thirdToken,
      touchNociceptionValue: nil,
      interoceptionValues: invalidTemperatureValues,
      cachedDecisionFingerprint: 0xaffe_0104
    )
    let cpuThird = try cpuSecond.advanced(
      to: BrainTimestamp(microseconds: 13_000),
      sample: AffectivePhysiologySample(
        interoceptionTimestamp: BrainTimestamp(microseconds: 12_000),
        energyDeficit: 1 - invalidTemperatureValues[0],
        respiratoryDeficit: max(
          1 - invalidTemperatureValues[1], invalidTemperatureValues[2]
        ),
        temperatureDeviation: nil,
        fatigue: invalidTemperatureValues[4],
        tissueDamage: invalidTemperatureValues[5]
      )
    )
    XCTAssertEqual(affectMask(third) & 0x1f, 0x1b)
    XCTAssertEqual((affectMask(second) ^ affectMask(third)) & 0x1f, 1 << 2)
    XCTAssertEqual(affectFloat(third, 0), cpuThird.pain, accuracy: 1.0e-5)
    XCTAssertEqual(affectFloat(third, 4), cpuThird.pleasure, accuracy: 1.0e-5)
    XCTAssertEqual(affectFloat(third, 8), cpuThird.relief, accuracy: 1.0e-5)
    XCTAssertEqual(affectFloat(third, 24), cpuThird.sourceEvidence[2], accuracy: 1.0e-5)
    XCTAssertEqual(
      cpuThird.pleasure,
      cpuSecond.pleasure * Float(Foundation.exp(-0.001)),
      accuracy: 1.0e-5,
      "the invalid temperature source must not earn recovery pleasure"
    )

    let opaqueTemplate = try makeNumanXInteropCompiledTemplate(
      interoceptorCount: 1,
      interoceptionFeatureDimension: InteroceptiveFeatureSchema
        .NumanXFullBodyV1.featureDimension
    )
    XCTAssertNotEqual(
      typedTemplate.species.fingerprint,
      opaqueTemplate.species.fingerprint
    )
    let opaqueFixture = try makeFixture(compiledSpeciesTemplate: opaqueTemplate)
    let opaque = try runAcceptedRoot(
      fixture: opaqueFixture,
      token: opaqueFixture.token,
      touchNociceptionValue: nil,
      interoceptionValues: firstValues,
      cachedDecisionFingerprint: 0xaffe_0103
    )
    let opaqueSection = opaqueFixture.runtime.agentStateRuntime.arena.layout.section(
      .affectiveState
    )
    let opaquePain = opaque.hotState.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: opaqueSection.byteOffset, as: Float.self)
    }
    let opaquePleasure = opaque.hotState.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: opaqueSection.byteOffset + 4, as: Float.self)
    }
    let opaqueSourceMask = opaque.hotState.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: opaqueSection.byteOffset + 36, as: UInt16.self)
    }
    XCTAssertEqual(opaquePain, 0)
    XCTAssertEqual(opaquePleasure, 0)
    XCTAssertEqual(opaqueSourceMask, 0)
  }

  func testTypedNumanXFullBodyAggregates416ReceptorsAndRejectsIncompleteCoverage()
    throws
  {
    let receptorCount = 416
    let schemaDimension =
      InteroceptiveFeatureSchema.NumanXFullBodyV1.featureDimension
    let schemaFingerprint =
      InteroceptiveFeatureSchema.NumanXFullBodyV1.fingerprint
    let template = try makeNumanXInteropCompiledTemplate(
      interoceptorCount: UInt32(receptorCount),
      interoceptionFeatureDimension: schemaDimension,
      interoceptionFeatureSchemaFingerprint: schemaFingerprint
    )
    let fixture = try makeFixture(compiledSpeciesTemplate: template)
    let mixedValues = (0..<receptorCount).map { receptor -> [Float] in
      let alternating = receptor.isMultiple(of: 2) ? Float(0) : Float(1)
      return [
        alternating,
        1 - alternating,
        0,
        receptor.isMultiple(of: 2) ? -0.25 : 0.25,
        alternating,
        alternating,
      ]
    }
    let first = try runAcceptedRoot(
      fixture: fixture,
      token: fixture.token,
      touchNociceptionValue: nil,
      interoceptionValuesByReceptor: mixedValues,
      cachedDecisionFingerprint: 0xaffe_0301
    )
    let firstAffect = affectBytes(first, fixture: fixture)
    let firstMask = affectUInt16(firstAffect, offset: 36)
    XCTAssertEqual(firstMask & 0x1f, 0x1f)
    XCTAssertEqual(affectFloat(firstAffect, offset: 16), 0.5, accuracy: 1e-5)
    XCTAssertEqual(affectFloat(firstAffect, offset: 20), 0.5, accuracy: 1e-5)
    XCTAssertEqual(affectFloat(firstAffect, offset: 24), 0.25, accuracy: 1e-5)
    XCTAssertEqual(affectFloat(firstAffect, offset: 28), 0.5, accuracy: 1e-5)
    XCTAssertEqual(affectFloat(firstAffect, offset: 32), 0.5, accuracy: 1e-5)
    XCTAssertEqual(affectFloat(firstAffect, offset: 0), 0.5, accuracy: 1e-5)

    let nextToken = try BrainJointTransactionToken(
      environmentIdentifier: fixture.token.environmentIdentifier,
      episodeIdentifier: fixture.token.episodeIdentifier,
      controlStepIdentifier: fixture.token.controlStepIdentifier + 1,
      parameterVersionFingerprint: fixture.token.parameterVersionFingerprint,
      baseBrainGeneration: 1,
      basePhysicsGeneration: 101,
      committedTimestamp: BrainTimestamp(microseconds: 11_000),
      targetTimestamp: BrainTimestamp(microseconds: 12_000),
      randomCounterGeneration: 1
    )
    let recoveredValues = Array(
      repeating: [Float(1), 1, 0, 0, 0, 0],
      count: receptorCount
    )
    let partial = try runAcceptedRoot(
      fixture: fixture,
      token: nextToken,
      touchNociceptionValue: nil,
      interoceptionValuesByReceptor: recoveredValues,
      invalidInteroceptionReceptor: receptorCount - 1,
      cachedDecisionFingerprint: 0xaffe_0302
    )
    let partialAffect = affectBytes(partial, fixture: fixture)
    let elapsed = Float(0.001)
    XCTAssertEqual(affectUInt16(partialAffect, offset: 36), 0)
    XCTAssertEqual(
      affectFloat(partialAffect, offset: 0),
      0.5 * Float(Foundation.exp(-elapsed / 2)),
      accuracy: 1e-5
    )
    XCTAssertEqual(
      affectFloat(partialAffect, offset: 4),
      affectFloat(firstAffect, offset: 4) * Float(Foundation.exp(-elapsed)),
      accuracy: 1e-5,
      "one invalid receptor must not earn recovery pleasure"
    )
  }

  func testAcceptedAffectShadowRollbackCanRetryTheSameTypedSample() throws {
    let schemaFingerprint = InteroceptiveFeatureSchema.NumanXFullBodyV1.fingerprint
    let typedTemplate = try makeNumanXInteropCompiledTemplate(
      interoceptorCount: 1,
      interoceptionFeatureDimension: InteroceptiveFeatureSchema
        .NumanXFullBodyV1.featureDimension,
      interoceptionFeatureSchemaFingerprint: schemaFingerprint
    )
    let sample: [Float] = [0, 0, 0, 0, 1, 1]
    let fixture = try makeFixture(compiledSpeciesTemplate: typedTemplate)
    let before = try fixture.runtime.agentStateRuntime.snapshotCommittedState()
    let beforeAffect = affectBytes(before, fixture: fixture)
    let prepared = try makePreparedAcceptedRoot(
      fixture: fixture,
      interoceptionValues: sample
    )

    let gate = try makeAcceptedPhysicsGate(
      device: fixture.device,
      expected: prepared.accepted,
      observed: prepared.accepted
    )
    let event = try XCTUnwrap(fixture.device.makeSharedEvent())
    let ticket = try fixture.runtime.submitAcceptedConsequence(
      transaction: prepared.transaction,
      acceptedPhysicsState: prepared.accepted,
      candidateSubstep: prepared.substep,
      acceptedPhysicsGate: gate,
      numanXSensors: prepared.acceptedSensors,
      acceptedRegionalRecurrentInput: fixture.recurrentView,
      signal: try MetalSharedEventPoint(event: event, value: 81)
    )
    XCTAssertTrue(event.wait(untilSignaledValue: 81, timeoutMS: 10_000))
    _ = try fixture.runtime.finishAcceptedConsequenceSubmission(
      ticket,
      transaction: prepared.transaction,
      acceptedPhysicsState: prepared.accepted,
      timeoutMilliseconds: 10_000
    )

    let affectSection = fixture.runtime.agentStateRuntime.arena.layout.section(
      .affectiveState
    )
    let shadowBuffer = try fixture.runtime.agentStateRuntime.arena
      .borrowShadowHotBuffer(transaction: prepared.transaction.agentStateToken)
    let completedShadow = try snapshot(buffer: shadowBuffer, device: fixture.device)
    let shadowAffect = affectBytes(
      completedShadow,
      sectionOffset: affectSection.byteOffset,
      byteCount: affectSection.byteCount
    )
    XCTAssertGreaterThan(affectFloat(shadowAffect, offset: 0), 0)
    XCTAssertEqual(affectUInt16(shadowAffect, offset: 36) & 0x1f, 0x1f)

    try fixture.runtime.abort(transaction: prepared.transaction)
    let afterAbort = try fixture.runtime.agentStateRuntime.snapshotCommittedState()
    XCTAssertEqual(afterAbort.generation, before.generation)
    XCTAssertEqual(afterAbort.hotState, before.hotState)
    XCTAssertEqual(affectBytes(afterAbort, fixture: fixture), beforeAffect)

    let retry = try runAcceptedRoot(
      fixture: fixture,
      token: fixture.token,
      touchNociceptionValue: nil,
      interoceptionValues: sample,
      cachedDecisionFingerprint: 0x6a7e_0001
    )
    let retryAffect = affectBytes(retry, fixture: fixture)
    let expected = try AffectiveState.neutral(at: BrainTimestamp(microseconds: 0))
      .advanced(
        to: fixture.token.targetTimestamp,
        sample: AffectivePhysiologySample(
          interoceptionTimestamp: BrainTimestamp(microseconds: 10_000),
          energyDeficit: 1,
          respiratoryDeficit: 1,
          temperatureDeviation: 0,
          fatigue: 1,
          tissueDamage: 1
        )
      )
    XCTAssertEqual(affectFloat(retryAffect, offset: 0), expected.pain, accuracy: 1e-5)
    XCTAssertEqual(affectFloat(retryAffect, offset: 4), expected.pleasure, accuracy: 1e-5)
    XCTAssertEqual(affectFloat(retryAffect, offset: 8), expected.relief, accuracy: 1e-5)
    XCTAssertEqual(affectUInt16(retryAffect, offset: 36) & 0x1f, 0x1f)
  }

  func testAcceptedAffectCheckpointRoundTripPreservesHotState() throws {
    let typedTemplate = try makeNumanXInteropCompiledTemplate(
      interoceptorCount: 1,
      interoceptionFeatureDimension: InteroceptiveFeatureSchema
        .NumanXFullBodyV1.featureDimension,
      interoceptionFeatureSchemaFingerprint:
        InteroceptiveFeatureSchema.NumanXFullBodyV1.fingerprint
    )
    let fixture = try makeFixture(compiledSpeciesTemplate: typedTemplate)
    let accepted = try runAcceptedRoot(
      fixture: fixture,
      token: fixture.token,
      touchNociceptionValue: nil,
      interoceptionValues: [0, 0, 0, 0, 1, 1],
      cachedDecisionFingerprint: 0xaffe_0201
    )
    let physicalFingerprint: UInt64 = 0xaffec7
    let checkpoint = try fixture.runtime.saveCheckpoint(
      environmentIdentifier: fixture.token.environmentIdentifier,
      episodeIdentifier: fixture.token.episodeIdentifier,
      controlStepIdentifier: fixture.token.controlStepIdentifier,
      committedTimestamp: fixture.token.targetTimestamp,
      physicalCheckpointFingerprint: physicalFingerprint
    )

    let restoredFixture = try makeFixture(compiledSpeciesTemplate: typedTemplate)
    try restoredFixture.runtime.loadCheckpoint(
      checkpoint,
      physicalCheckpointFingerprint: physicalFingerprint
    )
    let roundTrip = try restoredFixture.runtime.saveCheckpoint(
      environmentIdentifier: fixture.token.environmentIdentifier,
      episodeIdentifier: fixture.token.episodeIdentifier,
      controlStepIdentifier: fixture.token.controlStepIdentifier,
      committedTimestamp: fixture.token.targetTimestamp,
      physicalCheckpointFingerprint: physicalFingerprint
    )
    XCTAssertEqual(roundTrip, checkpoint)
    XCTAssertEqual(roundTrip.hotState, checkpoint.hotState)

    let originalAffect = affectBytes(accepted, fixture: fixture)
    let restored = try restoredFixture.runtime.agentStateRuntime
      .snapshotCommittedState()
    let restoredAffect = affectBytes(restored, fixture: restoredFixture)
    XCTAssertEqual(restoredAffect, originalAffect)
    XCTAssertGreaterThan(affectFloat(restoredAffect, offset: 0), 0)
    XCTAssertEqual(affectUInt16(restoredAffect, offset: 36) & 0x1f, 0x1f)
  }

  func testMaximumPleasureDoesNotSuppressCurrentRootSafetyStop() throws {
    let criticalRule = try ReceptorEventRule(
      identifier: 0x7000_0001,
      modality: .interoception,
      receptorStart: 0,
      receptorCount: 1,
      featureIndex: 0,
      comparison: .lessThan,
      threshold: 0.2,
      magnitudeScale: 10,
      eventKind: .physiologicalCritical,
      sourceIdentifier: 777,
      usesAbsoluteThreshold: true
    )
    let typedTemplate = try makeNumanXInteropCompiledTemplate(
      interoceptorCount: 1,
      interoceptionFeatureDimension: InteroceptiveFeatureSchema
        .NumanXFullBodyV1.featureDimension,
      interoceptionFeatureSchemaFingerprint:
        InteroceptiveFeatureSchema.NumanXFullBodyV1.fingerprint,
      extraEventRules: [criticalRule]
    )
    let source = try makeFixture(compiledSpeciesTemplate: typedTemplate)
    _ = try runAcceptedRoot(
      fixture: source,
      token: source.token,
      touchNociceptionValue: nil,
      interoceptionValues: [1, 1, 0, 0, 0, 0],
      cachedDecisionFingerprint: 0xaffe_0401
    )
    let physicalFingerprint: UInt64 = 0xaffec9
    let checkpoint = try source.runtime.saveCheckpoint(
      environmentIdentifier: source.token.environmentIdentifier,
      episodeIdentifier: source.token.episodeIdentifier,
      controlStepIdentifier: source.token.controlStepIdentifier,
      committedTimestamp: source.token.targetTimestamp,
      physicalCheckpointFingerprint: physicalFingerprint
    )

    let affectSection = source.runtime.agentStateRuntime.arena.layout.section(
      .affectiveState
    )
    var seededHotState = checkpoint.hotState
    seededHotState.withUnsafeMutableBytes { bytes in
      bytes.storeBytes(
        of: Float(1),
        toByteOffset: affectSection.byteOffset + 4,
        as: Float.self
      )
      bytes.storeBytes(
        of: UInt16(1),
        toByteOffset: affectSection.byteOffset + 36,
        as: UInt16.self
      )
      bytes.storeBytes(
        of: UInt16(1),
        toByteOffset: affectSection.byteOffset + 38,
        as: UInt16.self
      )
      bytes.storeBytes(
        of: checkpoint.committedTimestamp.rawValue,
        toByteOffset: affectSection.byteOffset + 40,
        as: UInt64.self
      )
      bytes.storeBytes(
        of: checkpoint.committedTimestamp.rawValue - 1_000,
        toByteOffset: affectSection.byteOffset + 48,
        as: UInt64.self
      )
    }
    let pleasureCheckpoint = try MetalBrainCheckpoint(
      committedGeneration: checkpoint.committedGeneration,
      committedTimestamp: checkpoint.committedTimestamp,
      environmentIdentifier: checkpoint.environmentIdentifier,
      episodeIdentifier: checkpoint.episodeIdentifier,
      controlStepIdentifier: checkpoint.controlStepIdentifier,
      speciesTemplateFingerprint: checkpoint.speciesTemplateFingerprint,
      compiledSpeciesTemplateFingerprint:
        checkpoint.compiledSpeciesTemplateFingerprint,
      regionalProgramFingerprint: checkpoint.regionalProgramFingerprint,
      scheduleFingerprint: checkpoint.scheduleFingerprint,
      parameterVersionFingerprint: checkpoint.parameterVersionFingerprint,
      hotLayoutFingerprint: checkpoint.hotLayoutFingerprint,
      memoryLayoutFingerprint: checkpoint.memoryLayoutFingerprint,
      physicalCheckpointFingerprint: checkpoint.physicalCheckpointFingerprint,
      hotState: seededHotState,
      persistentMemory: checkpoint.persistentMemory,
      connectomeState: checkpoint.connectomeState,
      muscleLocomotorFingerprint: checkpoint.muscleLocomotorFingerprint
    )

    let restored = try makeFixture(compiledSpeciesTemplate: typedTemplate)
    try restored.runtime.loadCheckpoint(
      pleasureCheckpoint,
      physicalCheckpointFingerprint: physicalFingerprint
    )
    let nextToken = try BrainJointTransactionToken(
      environmentIdentifier: checkpoint.environmentIdentifier,
      episodeIdentifier: checkpoint.episodeIdentifier,
      controlStepIdentifier: checkpoint.controlStepIdentifier + 1,
      parameterVersionFingerprint: checkpoint.parameterVersionFingerprint,
      baseBrainGeneration: checkpoint.committedGeneration,
      basePhysicsGeneration: source.token.basePhysicsGeneration + 1,
      committedTimestamp: checkpoint.committedTimestamp,
      targetTimestamp: BrainTimestamp(
        microseconds: checkpoint.committedTimestamp.rawValue + 1_000
      ),
      randomCounterGeneration: source.token.randomCounterGeneration + 1
    )
    let transaction = try restored.runtime.beginControl(
      jointToken: nextToken,
      cachedDecisionFingerprint: 0xaffe_0402
    )
    defer { try? restored.runtime.abort(transaction: transaction) }
    let decision = try restored.runtime.inferAndDecide(
      transaction: transaction,
      numanXSensors: try makeSensorPacket(
        fixture: restored,
        acceptedPhysicsState: nil,
        interoceptionValues: [0, 1, 0, 0, 0, 0],
        token: nextToken
      ),
      regionalRecurrentInput: restored.recurrentView
    )

    let hotBuffer = try restored.runtime.agentStateRuntime.arena
      .borrowShadowHotBuffer(transaction: transaction.agentStateToken)
    let hotState = try snapshot(buffer: hotBuffer, device: restored.device)
    let affect = affectBytes(
      hotState,
      sectionOffset: affectSection.byteOffset,
      byteCount: affectSection.byteCount
    )
    XCTAssertEqual(affectFloat(affect, offset: 4), 1)
    XCTAssertEqual(affectUInt16(affect, offset: 36), 1)
    XCTAssertEqual(
      affect.withUnsafeBytes {
        $0.loadUnaligned(fromByteOffset: 40, as: UInt64.self)
      },
      checkpoint.committedTimestamp.rawValue
    )

    let eventSection = restored.runtime.agentStateRuntime.arena.layout.section(
      .eventQueue
    )
    let eventCount = hotState.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: eventSection.byteOffset, as: UInt32.self)
    }
    XCTAssertGreaterThan(eventCount, 0)
    let eventKind = hotState.withUnsafeBytes {
      $0.loadUnaligned(
        fromByteOffset: eventSection.byteOffset + 32 + 4,
        as: UInt32.self
      )
    }
    let eventSource = hotState.withUnsafeBytes {
      $0.loadUnaligned(
        fromByteOffset: eventSection.byteOffset + 32 + 8,
        as: UInt32.self
      )
    }
    let eventMagnitude = hotState.withUnsafeBytes {
      $0.loadUnaligned(
        fromByteOffset: eventSection.byteOffset + 32 + 24,
        as: Float.self
      )
    }
    XCTAssertEqual(eventKind, UInt32(ReceptorEventKind.physiologicalCritical.rawValue))
    XCTAssertEqual(eventSource, 777)
    XCTAssertEqual(eventMagnitude, 1, accuracy: 1e-5)

    let driveSection = restored.runtime.agentStateRuntime.arena.layout.section(
      .drives
    )
    let safetyDrive = hotState.withUnsafeBytes {
      $0.loadUnaligned(
        fromByteOffset: driveSection.byteOffset + 11 * 32,
        as: Float.self
      )
    }
    XCTAssertGreaterThan(safetyDrive, 0.8)

    let controlLayout = try MetalActiveControlLayout(
      arenaLayout: restored.runtime.agentStateRuntime.arena.layout,
      species: restored.compiled.species
    )
    let headerOffset = controlLayout.section(.header).byteOffset
    let controlMode = hotState.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: headerOffset + 32, as: UInt32.self)
    }
    let controlFlags = hotState.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: headerOffset + 44, as: UInt32.self)
    }
    XCTAssertEqual(decision.decisionTimestamp, checkpoint.committedTimestamp)
    XCTAssertEqual(controlMode, 1, "safety must select reflex control mode")
    XCTAssertNotEqual(
      controlFlags & (1 << 1),
      0,
      "hyperdirect stop must remain asserted at maximum pleasure"
    )
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
    return try runAcceptedRoot(
      fixture: fixture,
      token: fixture.token,
      touchNociceptionValue: nil,
      cachedDecisionFingerprint: 0x5eed_0001
    )
  }

  private func runAcceptedRoot(
    fixture: Fixture,
    token: BrainJointTransactionToken,
    touchNociceptionValue: Float?,
    interoceptionValues: [Float]? = nil,
    interoceptionValuesByReceptor: [[Float]]? = nil,
    invalidInteroceptionReceptor: Int? = nil,
    cachedDecisionFingerprint: UInt64
  ) throws -> MetalAgentStateRuntime.CheckpointPayload {
    let transaction = try fixture.runtime.beginControl(
      jointToken: token,
      cachedDecisionFingerprint: cachedDecisionFingerprint
    )
    let committedSensors = try makeSensorPacket(
      fixture: fixture,
      acceptedPhysicsState: nil,
      touchNociceptionValue: touchNociceptionValue,
      interoceptionValues: interoceptionValues,
      interoceptionValuesByReceptor: interoceptionValuesByReceptor,
      invalidInteroceptionReceptor: invalidInteroceptionReceptor,
      token: token
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

    var physicalLedger = BrainJointTransaction(token: token)
    let substep = try physicalLedger.beginPhysicsSubstep(
      durationMicroseconds: token.targetTimestamp.rawValue
        - token.committedTimestamp.rawValue
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: token,
      substep: substep,
      physicsStateFingerprint: 0xfeed_0001 ^ token.baseBrainGeneration,
      physicsGeneration: token.basePhysicsGeneration + 1
    )
    try physicalLedger.acceptPhysicsSubstep(accepted, for: substep)
    let acceptedSensors = try makeSensorPacket(
      fixture: fixture,
      acceptedPhysicsState: accepted,
      touchNociceptionValue: touchNociceptionValue,
      interoceptionValues: interoceptionValues,
      interoceptionValuesByReceptor: interoceptionValuesByReceptor,
      invalidInteroceptionReceptor: invalidInteroceptionReceptor,
      token: token
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

  private func makePreparedAcceptedRoot(
    fixture suppliedFixture: Fixture? = nil,
    compiledSpeciesTemplate: CompiledSpeciesTemplate? = nil,
    interoceptionValues: [Float]? = nil
  ) throws -> PreparedAcceptedRoot {
    let fixture: Fixture
    if let suppliedFixture {
      fixture = suppliedFixture
    } else {
      fixture = try makeFixture(compiledSpeciesTemplate: compiledSpeciesTemplate)
    }
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
      acceptedPhysicsState: accepted,
      interoceptionValues: interoceptionValues
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
    try makeFixture(compiledSpeciesTemplate: nil)
  }

  private func makeFixture(
    compiledSpeciesTemplate: CompiledSpeciesTemplate?
  ) throws -> Fixture {
    let device = try requireMetal4Device()
    let compiled = try compiledSpeciesTemplate
      ?? makeNumanXInteropCompiledTemplate()
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
    acceptedPhysicsState: AcceptedPhysicsStateToken?,
    touchNociceptionValue: Float? = nil,
    interoceptionValues: [Float]? = nil,
    interoceptionValuesByReceptor: [[Float]]? = nil,
    invalidInteroceptionReceptor: Int? = nil,
    token: BrainJointTransactionToken? = nil
  ) throws -> NumanXSensorPacketLease {
    try makeSensorPacket(
      device: fixture.device,
      compiled: fixture.compiled,
      token: token ?? fixture.token,
      acceptedPhysicsState: acceptedPhysicsState,
      touchNociceptionValue: touchNociceptionValue,
      interoceptionValues: interoceptionValues,
      interoceptionValuesByReceptor: interoceptionValuesByReceptor,
      invalidInteroceptionReceptor: invalidInteroceptionReceptor
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

  private func affectBytes(
    _ payload: MetalAgentStateRuntime.CheckpointPayload,
    fixture: Fixture
  ) -> Data {
    let section = fixture.runtime.agentStateRuntime.arena.layout.section(
      .affectiveState
    )
    return affectBytes(
      payload.hotState,
      sectionOffset: section.byteOffset,
      byteCount: section.byteCount
    )
  }

  private func affectBytes(
    _ hotState: Data,
    sectionOffset: Int,
    byteCount: Int
  ) -> Data {
    hotState.subdata(in: sectionOffset..<(sectionOffset + byteCount))
  }

  private func affectFloat(_ affect: Data, offset: Int) -> Float {
    affect.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: offset, as: Float.self)
    }
  }

  private func affectUInt16(_ affect: Data, offset: Int) -> UInt16 {
    affect.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
    }
  }

  private func makeSensorPacket(
    device: any MTLDevice,
    compiled: CompiledSpeciesTemplate,
    token: BrainJointTransactionToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken?,
    touchNociceptionValue: Float? = nil,
    interoceptionValues: [Float]? = nil,
    interoceptionValuesByReceptor: [[Float]]? = nil,
    invalidInteroceptionReceptor: Int? = nil
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
        if let touchNociceptionValue, topology.modality == .touch, scalarCount > 0 {
          scalars[0] = touchNociceptionValue
        }
        if let interoceptionValues, topology.modality == .interoception {
          guard interoceptionValues.count == Int(topology.observationDimension) else {
            throw BrainRuntimeError.invalidEvent(
              "test interoceptive values do not match the feature schema"
            )
          }
          for receptor in 0..<Int(topology.receptorCount) {
            for feature in 0..<Int(topology.observationDimension) {
              scalars[receptor * Int(topology.observationDimension) + feature]
                = interoceptionValues[feature]
            }
          }
        }
        if let interoceptionValuesByReceptor,
          topology.modality == .interoception
        {
          guard interoceptionValuesByReceptor.count
              == Int(topology.receptorCount),
            interoceptionValuesByReceptor.allSatisfy({
              $0.count == Int(topology.observationDimension)
            })
          else {
            throw BrainRuntimeError.invalidEvent(
              "test interoceptive receptor rows do not match the feature schema"
            )
          }
          for receptor in 0..<Int(topology.receptorCount) {
            for feature in 0..<Int(topology.observationDimension) {
              scalars[receptor * Int(topology.observationDimension) + feature]
                = interoceptionValuesByReceptor[receptor][feature]
            }
          }
        }
        let validity: (any MTLBuffer)?
        if topology.modality == .proprioception
          || (topology.modality == .interoception
            && invalidInteroceptionReceptor != nil)
        {
          if topology.modality == .interoception,
            let invalidInteroceptionReceptor,
            !(0..<Int(topology.receptorCount)).contains(invalidInteroceptionReceptor)
          {
            throw BrainRuntimeError.invalidEvent(
              "test invalid interoception receptor is out of bounds"
            )
          }
          guard let created = device.makeBuffer(
            length: Int(topology.receptorCount) * MemoryLayout<UInt32>.stride,
            options: [.storageModeShared, .hazardTrackingModeTracked]
          ) else {
            throw TissueError.metal("failed to allocate sensor validity buffer")
          }
          let receptorValidity = created.contents().assumingMemoryBound(
            to: UInt32.self
          )
          receptorValidity.initialize(
            repeating: 1,
            count: Int(topology.receptorCount)
          )
          if topology.modality == .interoception,
            let invalidInteroceptionReceptor
          {
            receptorValidity[invalidInteroceptionReceptor] = 0
          }
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

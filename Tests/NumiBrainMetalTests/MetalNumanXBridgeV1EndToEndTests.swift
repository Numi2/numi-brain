import Foundation
import Metal
import XCTest

@testable import NumiBrainCore
@_spi(NumanXInterop) @testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalNumanXBridgeV1EndToEndTests: XCTestCase {
  func testRealFullBodyBrainProposalApplyAndJointPublication() throws {
    let paths = try bridgePaths()
    guard let device = MTLCreateSystemDefaultDevice(),
      device.makeMTL4CommandQueue() != nil,
      device.makeCommandAllocator() != nil,
      device.makeCommandBuffer() != nil
    else {
      throw XCTSkip("Metal 4 execution is unavailable")
    }
    let parameters = TissueParameters.corticalSheetV0
    let compiled = try makeNumanXFullBodyTransportCompiledTemplate()
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: compiled.species,
      tissueParameters: parameters
    )
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 8,
      height: 8,
      parameters: parameters
    )
    let brain = try MetalNumiBrainRuntime.makeRuntime(
      configuration: MetalNumiBrainConfiguration(
        initialTissueState: initial,
        tissueParameters: parameters,
        tissueStimulus: .none,
        compiledSpeciesTemplate: compiled,
        randomContext: TissueRandomContext(
          seed: 0x4e55_4d49,
          environmentIdentifier: 0,
          episodeIdentifier: 1
        ),
        schedulerEnvironmentIdentifier: 0,
        maximumEncodedSubsteps: 1
      ),
      publication: publication,
      device: device
    )
    let native = try MetalNumanXBridgeV1Runtime(
      libraryPath: paths.library,
      device: device,
      configuration: .init(
        rigidPayloadPath: paths.rigid,
        musclePayloadPath: paths.muscle,
        metalRoboMetallibPath: paths.metalRoboMetallib,
        matterMetallibPath: paths.matterMetallib,
        matterMaterialPath: paths.material,
        timestepMicroseconds: 1_000,
        transactionSlotCount: 2
      )
    )
    XCTAssertEqual(native.info.bodyCount, 157)
    XCTAssertEqual(native.info.qCoordinateCount, 129)
    XCTAssertEqual(native.info.dofCount, 128)
    XCTAssertEqual(native.info.muscleCount, 416)
    XCTAssertEqual(native.info.residentContinuationCount, 0)
    XCTAssertNil(try native.aggregateSnapshotIfAvailable())

    let transaction = try brain.beginControl(
      controlStepIdentifier: 1,
      basePhysicsGeneration: 0,
      committedTimestamp: BrainTimestamp(microseconds: 1_000),
      targetTimestamp: BrainTimestamp(microseconds: 2_000),
      cachedDecisionFingerprint: 0x4e58_4445_4349_5349
    )
    let initialSensors = try bootstrapSensorPacket(
      device: device,
      compiled: compiled,
      transaction: transaction.token
    )
    let first = try publishRoot(
      brain: brain,
      native: native,
      transaction: transaction,
      sensors: initialSensors,
      device: device
    )
    let physical = first.physical
    let aggregate = first.aggregate
    XCTAssertEqual(aggregate.publicationEpoch, 1)
    XCTAssertEqual(aggregate.brainGeneration, brain.committedGeneration)
    XCTAssertEqual(aggregate.physicsGeneration, 1)
    XCTAssertEqual(aggregate.sensorGeneration, 1)
    XCTAssertEqual(aggregate.identity, physical.identity)
    XCTAssertEqual(aggregate.proprioception.receptorCount, 416)
    XCTAssertEqual(aggregate.proprioception.featureDimension, 10)
    XCTAssertEqual(aggregate.interoception.receptorCount, 416)
    XCTAssertEqual(aggregate.interoception.featureDimension, 1)
    XCTAssertEqual(try native.currentInfo().residentContinuationCount, 0)

    let secondTransaction = try brain.beginControl(
      controlStepIdentifier: 2,
      basePhysicsGeneration: aggregate.physicsGeneration,
      committedTimestamp: BrainTimestamp(microseconds: 2_000),
      targetTimestamp: BrainTimestamp(microseconds: 3_000),
      cachedDecisionFingerprint: 0x4e58_4445_4349_534a
    )
    let publishedSensors = try aggregate.sensorPacket(
      for: secondTransaction.token,
      compiledSpeciesTemplate: compiled
    )
    let second = try publishRoot(
      brain: brain,
      native: native,
      transaction: secondTransaction,
      sensors: publishedSensors,
      device: device
    )
    XCTAssertEqual(second.physical.identity.controlStep, 2)
    XCTAssertEqual(second.aggregate.publicationEpoch, 2)
    XCTAssertEqual(second.aggregate.brainGeneration, 2)
    XCTAssertEqual(second.aggregate.physicsGeneration, 2)
    XCTAssertEqual(second.aggregate.sensorGeneration, 2)
    XCTAssertEqual(try native.currentInfo().residentContinuationCount, 1)
    XCTAssertEqual(
      second.aggregate.identity.transactionFingerprint,
      secondTransaction.token.fingerprint
    )
    XCTAssertEqual(second.aggregate.proprioception.receptorTimestamp,
                   BrainTimestamp(microseconds: 2_000))
    XCTAssertEqual(second.aggregate.interoception.receptorTimestamp,
                   BrainTimestamp(microseconds: 2_000))
    // The copied epoch-1 metadata remains an immutable value even though the
    // native runtime has advanced its sole public aggregate root.
    XCTAssertEqual(aggregate.publicationEpoch, 1)
    XCTAssertEqual(aggregate.physicsGeneration, 1)

    // A fully valid Brain/motor root with a stale physics predecessor is
    // rejected by the native causal-chain gate before it consumes a runtime
    // slot or touches the resident Human state.
    let staleTransaction = try brain.beginControl(
      controlStepIdentifier: 3,
      basePhysicsGeneration: 1,
      committedTimestamp: BrainTimestamp(microseconds: 3_000),
      targetTimestamp: BrainTimestamp(microseconds: 4_000),
      cachedDecisionFingerprint: 0x4e58_5354_414c_4501
    )
    let staleSensors = try bootstrapSensorPacket(
      device: device,
      compiled: compiled,
      transaction: staleTransaction.token
    )
    let staleDecision = try brain.submitInferAndDecide(
      staleTransaction,
      numanXSensors: staleSensors,
      signal: point(device, value: 1)
    )
    let staleMotor = try brain.submitNumanXMotorCandidate(
      staleDecision,
      transaction: staleTransaction,
      candidateDurationMicroseconds: 1_000,
      signal: point(device, value: 1)
    )
    XCTAssertThrowsError(
      try native.beginPhysicalRoot(
        transaction: staleTransaction.token,
        motor: staleMotor
      ) { _ in
        XCTFail("stale native root unexpectedly armed a completion")
      }
    )
    _ = try brain.finishNumanXMotorSubmission(
      staleMotor,
      transaction: staleTransaction,
      timeoutMilliseconds: 10_000
    )
    try brain.abortControl(staleTransaction)
    XCTAssertEqual(
      try XCTUnwrap(native.aggregateSnapshotIfAvailable()).publicationEpoch,
      2
    )
    XCTAssertEqual(try native.currentInfo().residentContinuationCount, 1)

    // The exact successor is still admissible and receives generation 3,
    // proving the failed stale request did not consume native generation or
    // sensor-publication authority.
    let thirdTransaction = try brain.beginControl(
      controlStepIdentifier: 3,
      basePhysicsGeneration: second.aggregate.physicsGeneration,
      committedTimestamp: BrainTimestamp(microseconds: 3_000),
      targetTimestamp: BrainTimestamp(microseconds: 4_000),
      cachedDecisionFingerprint: 0x4e58_4445_4349_534b
    )
    let thirdSensors = try second.aggregate.sensorPacket(
      for: thirdTransaction.token,
      compiledSpeciesTemplate: compiled
    )
    let third = try publishRoot(
      brain: brain,
      native: native,
      transaction: thirdTransaction,
      sensors: thirdSensors,
      device: device
    )
    XCTAssertEqual(third.aggregate.publicationEpoch, 3)
    XCTAssertEqual(third.aggregate.brainGeneration, 3)
    XCTAssertEqual(third.aggregate.physicsGeneration, 3)
    XCTAssertEqual(third.aggregate.sensorGeneration, 3)
    XCTAssertEqual(try native.currentInfo().residentContinuationCount, 2)

    let rejectedTransaction = try brain.beginControl(
      controlStepIdentifier: 4,
      basePhysicsGeneration: third.aggregate.physicsGeneration,
      committedTimestamp: BrainTimestamp(microseconds: 4_000),
      targetTimestamp: BrainTimestamp(microseconds: 5_000),
      cachedDecisionFingerprint: 0x4e58_5245_4a45_4354
    )
    let rejectedSensors = try third.aggregate.sensorPacket(
      for: rejectedTransaction.token,
      compiledSpeciesTemplate: compiled
    )
    let rejected = try prepareRoot(
      brain: brain,
      native: native,
      transaction: rejectedTransaction,
      sensors: rejectedSensors,
      device: device
    )
    let rejectedAcceptedToken = acceptedGateBytes(
      rejected.physical.acceptedPhysicsGate
    )
    let rejectedSensorPayload = sensorPayloadBytes(
      rejected.physical.sensorCandidate
    )
    XCTAssertTrue(rejected.physical.quarantineTimeout())
    let rejectProposalLatch =
      AsyncResultLatch<MetalNumanXHumanMatterProposalLease>()
    try rejected.physical.submitTimeoutRejectProposal {
      rejectProposalLatch.complete($0)
    }
    _ = try rejectProposalLatch.wait()
    try rejected.physical.reserveTimeoutRejectApplication(
      brain: rejected.prepared
    )
    let rejectApplyLatch =
      AsyncResultLatch<MetalNumanXHumanMatterAppliedLease>()
    try rejected.physical.submitTimeoutRejectApply {
      rejectApplyLatch.complete($0)
    }
    let rejectedApplied = try rejectApplyLatch.wait()
    XCTAssertEqual(rejectedApplied.commandDisposition, .rejectedReleased)
    XCTAssertTrue(rejected.physical.releaseRejected())
    try brain.abortNumanXPreparedControl(rejected.prepared)
    XCTAssertFalse(brain.hasOpenControl)
    XCTAssertEqual(brain.committedGeneration, 3)
    let afterReject = try XCTUnwrap(native.aggregateSnapshotIfAvailable())
    XCTAssertEqual(afterReject.publicationEpoch, 3)
    XCTAssertEqual(afterReject.physicsGeneration, 3)
    XCTAssertEqual(afterReject.sensorGeneration, 3)
    XCTAssertEqual(try native.currentInfo().residentContinuationCount, 3)

    // Retry the rejected causal step. Physics generation is reused from the
    // restored predecessor, while the private HumanIO sensor generation stays
    // monotonic and therefore skips the rejected candidate's generation 4.
    let retryTransaction = try brain.beginControl(
      controlStepIdentifier: 4,
      basePhysicsGeneration: afterReject.physicsGeneration,
      committedTimestamp: BrainTimestamp(microseconds: 4_000),
      targetTimestamp: BrainTimestamp(microseconds: 5_000),
      cachedDecisionFingerprint: 0x4e58_5245_4a45_4354
    )
    XCTAssertEqual(
      retryTransaction.token.fingerprint,
      rejectedTransaction.token.fingerprint
    )
    let retrySensors = try afterReject.sensorPacket(
      for: retryTransaction.token,
      compiledSpeciesTemplate: compiled
    )
    let retried = try publishRoot(
      brain: brain,
      native: native,
      transaction: retryTransaction,
      sensors: retrySensors,
      device: device
    )
    XCTAssertEqual(retried.aggregate.publicationEpoch, 4)
    XCTAssertEqual(retried.aggregate.brainGeneration, 4)
    XCTAssertEqual(retried.aggregate.physicsGeneration, 4)
    XCTAssertEqual(retried.aggregate.sensorGeneration, 5)
    XCTAssertEqual(try native.currentInfo().residentContinuationCount, 4)
    XCTAssertEqual(
      acceptedGateBytes(retried.physical.acceptedPhysicsGate),
      rejectedAcceptedToken
    )
    XCTAssertEqual(
      sensorPayloadBytes(retried.physical.sensorCandidate),
      rejectedSensorPayload
    )
  }

  private func publishRoot(
    brain: MetalNumiBrainRuntime,
    native: MetalNumanXBridgeV1Runtime,
    transaction: MetalNumiBrainRuntime.ControlTransaction,
    sensors: NumanXSensorPacketLease,
    device: any MTLDevice
  ) throws -> (
    physical: MetalNumanXBridgeV1PreparedRoot,
    aggregate: MetalNumanXBridgeV1Runtime.AggregateSnapshot
  ) {
    let staged = try prepareRoot(
      brain: brain,
      native: native,
      transaction: transaction,
      sensors: sensors,
      device: device
    )
    let physical = staged.physical
    let prepared = staged.prepared
    let proposalLatch = AsyncResultLatch<MetalNumanXHumanMatterProposalLease>()
    try physical.submitProposal(brain: prepared) { proposalLatch.complete($0) }

    _ = try prepared.waitUntilBrainPrepareCompleted(timeoutMilliseconds: 10_000)
    let proposal = try proposalLatch.wait()
    let preflightStatus = waitForPreflight(prepared)
    guard preflightStatus == .numanXPreflightReady else {
      throw TissueError.transaction(
        prepared.preflightFailureDescription
          ?? "NumanX preflight settled as \(preflightStatus)"
      )
    }
    let jointCommitFingerprint = try brain.numanXPreparedJointCommitFingerprint(
      for: prepared,
      identity: physical.identity
    )
    try physical.reserveApplication(brain: prepared)

    let ackPoint = try point(device, value: 1)
    let ack = try brain.submitNumanXBrainAck(
      prepared,
      proposal: proposal,
      signal: ackPoint
    )
    let appliedLatch = AsyncResultLatch<MetalNumanXHumanMatterAppliedLease>()
    try physical.submitApply(ack: ack) { appliedLatch.complete($0) }
    let applied = try appliedLatch.wait()
    XCTAssertEqual(applied.commandDisposition, .acceptedPendingPublication)

    let resolution = try physical.makeResolution(
      proposal: proposal,
      applied: applied,
      jointCommitFingerprint: jointCommitFingerprint,
      brainGeneration: transaction.token.shadowGeneration
    )
    let validationPoint = try point(device, value: 1)
    _ = try brain.validateNumanXAppliedRoot(
      prepared,
      ack: ack,
      applied: applied,
      resolution: resolution,
      signal: validationPoint
    )
    XCTAssertEqual(waitForClose(prepared), .committed)
    XCTAssertFalse(brain.hasOpenControl)
    XCTAssertEqual(brain.committedGeneration, transaction.token.shadowGeneration)
    return (physical, try XCTUnwrap(native.aggregateSnapshotIfAvailable()))
  }

  private func prepareRoot(
    brain: MetalNumiBrainRuntime,
    native: MetalNumanXBridgeV1Runtime,
    transaction: MetalNumiBrainRuntime.ControlTransaction,
    sensors: NumanXSensorPacketLease,
    device: any MTLDevice
  ) throws -> (
    physical: MetalNumanXBridgeV1PreparedRoot,
    prepared: MetalNumiBrainRuntime.NumanXPreparedControlTicket
  ) {
    let decisionPoint = try point(device, value: 1)
    let motorPoint = try point(device, value: 1)
    let decision = try brain.submitInferAndDecide(
      transaction,
      numanXSensors: sensors,
      signal: decisionPoint
    )
    let motor = try brain.submitNumanXMotorCandidate(
      decision,
      transaction: transaction,
      candidateDurationMicroseconds: 1_000,
      signal: motorPoint
    )
    let rootLatch = AsyncResultLatch<MetalNumanXBridgeV1PreparedRoot>()
    try native.beginPhysicalRoot(transaction: transaction.token, motor: motor) {
      rootLatch.complete($0)
    }
    let physical = try rootLatch.wait()

    // Diagnostic settlement only: the physical queue already consumed the
    // GPU motor gate without a host wait. This advances Brain's host phase
    // after both exact terminal feedbacks are available.
    _ = try brain.finishNumanXMotorSubmission(
      motor,
      transaction: transaction,
      timeoutMilliseconds: 10_000
    )
    XCTAssertEqual(
      physical.identity.transactionFingerprint,
      transaction.token.fingerprint
    )
    XCTAssertEqual(physical.sensorCandidate.rawSensors.count, 2)

    let fastPoint = try point(device, value: 1)
    let brainPoint = try point(device, value: 1)
    let preflightPoint = try point(device, value: 1)
    let fast = try brain.submitProvisionalAcceptedFastRoot(
      transaction,
      waitFor: physical.physicalPreparedPoint,
      signal: fastPoint
    )
    let prepared = try brain.submitNumanXPreparedControl(
      transaction,
      provisionalFast: fast,
      identity: physical.identity,
      acceptedPhysicsGate: physical.acceptedPhysicsGate,
      sensorCandidate: physical.sensorCandidate,
      signal: brainPoint,
      thenSignal: preflightPoint
    )
    _ = try prepared.waitUntilBrainPrepareCompleted(timeoutMilliseconds: 10_000)
    let preflightStatus = waitForPreflight(prepared)
    guard preflightStatus == .numanXPreflightReady else {
      throw TissueError.transaction(
        prepared.preflightFailureDescription
          ?? "NumanX preflight settled as \(preflightStatus)"
      )
    }
    return (physical, prepared)
  }

  private struct BridgePaths {
    let library: String
    let rigid: String
    let muscle: String
    let metalRoboMetallib: String
    let matterMetallib: String
    let material: String
  }

  private func bridgePaths() throws -> BridgePaths {
    let environment = ProcessInfo.processInfo.environment
    let keys = [
      "NUMANX_METALROBO_LIBRARY", "NUMANX_FULLBODY_RIGID",
      "NUMANX_FULLBODY_MUSCLE", "NUMANX_METALROBO_METALLIB",
      "NUMANX_MATTER_METALLIB", "NUMANX_MATTER_MATERIAL",
    ]
    guard keys.allSatisfy({ !(environment[$0] ?? "").isEmpty }) else {
      throw XCTSkip("real NumanX bridge paths are not configured")
    }
    return BridgePaths(
      library: environment[keys[0]]!, rigid: environment[keys[1]]!,
      muscle: environment[keys[2]]!, metalRoboMetallib: environment[keys[3]]!,
      matterMetallib: environment[keys[4]]!, material: environment[keys[5]]!
    )
  }

  private func point(
    _ device: any MTLDevice,
    value: UInt64
  ) throws -> MetalSharedEventPoint {
    guard let event = device.makeSharedEvent() else {
      throw TissueError.metal("failed to allocate NumanX test event")
    }
    return try MetalSharedEventPoint(event: event, value: value)
  }

  // Test-only replay evidence. Production authority never reads these shared
  // payloads on the host; it consumes the accepted token and sensors on GPU.
  private func acceptedGateBytes(
    _ gate: MetalAcceptedPhysicsGateLease
  ) -> [UInt8] {
    Array(UnsafeRawBufferPointer(
      start: gate.buffer.contents().advanced(by: gate.byteOffset),
      count: MetalAcceptedPhysicsGateLease.byteCount
    ))
  }

  private func sensorPayloadBytes(
    _ candidate: MetalNumanXPendingSensorCandidateLease
  ) -> [UInt8] {
    candidate.rawSensors.flatMap { sensor in
      var result = Array(UnsafeRawBufferPointer(
        start: sensor.buffer.contents(), count: sensor.buffer.length
      ))
      if let validity = sensor.validityBuffer {
        result.append(contentsOf: UnsafeRawBufferPointer(
          start: validity.contents(), count: validity.length
        ))
      }
      return result
    }
  }

  private func bootstrapSensorPacket(
    device: any MTLDevice,
    compiled: CompiledSpeciesTemplate,
    transaction: BrainJointTransactionToken
  ) throws -> NumanXSensorPacketLease {
    let sensors = try compiled.species.senses.filter(\.enabled).map { topology in
      let scalarCount = Int(topology.receptorCount)
        * Int(topology.observationDimension)
      guard let values = device.makeBuffer(
        length: scalarCount * MemoryLayout<Float>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ), let validity = device.makeBuffer(
        length: Int(topology.receptorCount) * MemoryLayout<UInt32>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ) else {
        throw TissueError.metal("failed to allocate bootstrap HumanIO sensors")
      }
      values.contents().assumingMemoryBound(to: Float.self).initialize(
        repeating: topology.modality == .proprioception ? 0.25 : 0.5,
        count: scalarCount
      )
      validity.contents().assumingMemoryBound(to: UInt32.self).initialize(
        repeating: 1,
        count: Int(topology.receptorCount)
      )
      return try MetalRawSensorBufferLease(
        buffer: values,
        modality: topology.modality,
        receptorTimestamp: BrainTimestamp(
          microseconds: transaction.committedTimestamp.rawValue
            - UInt64(topology.latencyMicroseconds)
        ),
        receptorCount: topology.receptorCount,
        featureDimension: topology.observationDimension,
        validityBuffer: validity
      )
    }
    return try NumanXSensorPacketLease(
      transaction: transaction,
      compiledSpeciesTemplate: compiled,
      rawSensors: sensors
    )
  }

  private func waitForPreflight(
    _ ticket: MetalNumiBrainRuntime.NumanXPreparedControlTicket
  ) -> MetalNumiBrainRuntime.ControlTransaction.Status {
    let deadline = Date(timeIntervalSinceNow: 10)
    var status = ticket.status
    while status == .numanXPrepareSubmitted, Date() < deadline {
      Thread.sleep(forTimeInterval: 0.001)
      status = ticket.status
    }
    return status
  }

  private func waitForClose(
    _ ticket: MetalNumiBrainRuntime.NumanXPreparedControlTicket
  ) -> MetalNumiBrainRuntime.ControlTransaction.Status {
    let deadline = Date(timeIntervalSinceNow: 10)
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
}

@available(macOS 26.0, *)
private final class AsyncResultLatch<Value: Sendable>: @unchecked Sendable {
  private let condition = NSCondition()
  private var result: Result<Value, Error>?

  func complete(_ value: Result<Value, Error>) {
    condition.lock()
    guard result == nil else {
      condition.unlock()
      return
    }
    result = value
    condition.broadcast()
    condition.unlock()
  }

  func wait(timeout: TimeInterval = 10) throws -> Value {
    condition.lock()
    defer { condition.unlock() }
    let deadline = Date(timeIntervalSinceNow: timeout)
    while result == nil, condition.wait(until: deadline) {}
    guard let result else {
      throw TissueError.transaction("NumanX callback did not settle before timeout")
    }
    return try result.get()
  }
}

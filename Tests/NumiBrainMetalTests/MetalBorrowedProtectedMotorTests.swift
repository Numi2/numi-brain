import Foundation
import Metal
import XCTest
@testable import NumiBrainCore
@_spi(NumanXInterop) @testable import NumiBrainMetal

/// Synthetic receptor and receipt conformance only. This does not constitute
/// native Human standing, physical recovery, or biological affect evidence.
@available(macOS 26.0, *)
final class MetalBorrowedProtectedMotorTests: XCTestCase {
  private struct Fixture {
    let device: any MTLDevice
    let template: CompiledSpeciesTemplate
    let brain: MetalNumiBrainRuntime
  }

  private func makeFixture() throws -> Fixture {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let zero = try NumanXBodyLocalPoint(x: 0, y: 0, z: 0)
    let joints = try (UInt32(0)..<122).map { index in
      try NumanXJointTopology(jointIdentifier: index + 1,
        parentBodyIdentifier: index, childBodyIdentifier: index + 1,
        parentLocalAnchor: zero, childLocalAnchor: zero, restRelativeOrientation: .identity,
        coordinates: [.init(identifier: 0, kind: .angular, kinesthesiaReceptorIndex: index + 6,
          parentLocalAxis: .init(x: 1, y: 0, z: 0), minimumPosition: -1,
          maximumPosition: 1, restPosition: 0)])
    }
    let topology = try NumanXJointTopologyCatalog(numanXModelFingerprint: 123,
      bodyCount: 123, joints: joints)
    let attachments = try (UInt32(0)..<416).map {
      try NumanXMuscleAttachment(muscleIdentifier: $0, firstBodyIdentifier: 0,
        terminalBodyIdentifier: 1, routeNodeCount: 2,
        firstLocalPoint: zero, terminalLocalPoint: zero)
    }
    let template = try NumanXFullBodyTransportTemplate.compile(anatomy: .init(
      jointTopologyCatalog: topology,
      muscleAttachmentCatalog: .init(bodyCount: 123, attachments: attachments),
      headBodyIdentifier: 1))
    let program = MuscleLocomotorProgram(modelSourceFingerprint: 123,
      sensoryProfileFingerprint: template.sensoryProfile.fingerprint,
      calibrationArtifactSHA256: String(repeating: "a", count: 64),
      channels: (UInt32(0)..<416).map {
        .init(muscleIdentifier: $0, referenceLengthMeters: 0.25,
          tonicExcitation: 0.05, lengthGain: 0.3, velocityGainSeconds: 0.02)
      })
    let parameters = TissueParameters.corticalSheetV0
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: template.species, tissueParameters: parameters)
    let configuration = MetalNumiBrainConfiguration(
      initialTissueState: try CPUTissueDynamics.makeRestingGrid(width: 8, height: 8, parameters: parameters),
      tissueParameters: parameters, tissueStimulus: .none, compiledSpeciesTemplate: template,
      randomContext: TissueRandomContext(seed: 0x4e55_4d49, environmentIdentifier: 7, episodeIdentifier: 23),
      schedulerEnvironmentIdentifier: 7, maximumEncodedSubsteps: 1, muscleLocomotor: program)
    return try Fixture(device: device, template: template,
      brain: MetalNumiBrainRuntime.makeRuntime(configuration: configuration,
        publication: publication, device: device))
  }

  private func sensors(_ fixture: Fixture, timestamp: BrainTimestamp,
    critical: Bool = false) throws -> [MetalRawSensorBufferLease] {
    try fixture.template.species.senses.filter(\.enabled).map { sense in
      let count = Int(sense.receptorCount * sense.observationDimension)
      let buffer = try XCTUnwrap(fixture.device.makeBuffer(length: count * 4, options: .storageModeShared))
      let values = buffer.contents().assumingMemoryBound(to: Float.self)
      values.initialize(repeating: 0, count: count)
      if sense.modality == .proprioception {
        for muscle in 0..<Int(sense.receptorCount) {
          values[muscle * 10 + 4] = 0.26
          values[muscle * 10 + 5] = 0.1
        }
      }
      if sense.modality == .interoception { values[0] = critical ? -0.5 : 0.5 }
      let validity = try XCTUnwrap(fixture.device.makeBuffer(
        length: Int(sense.receptorCount) * 4, options: .storageModeShared))
      validity.contents().assumingMemoryBound(to: UInt32.self).initialize(
        repeating: UInt32.max, count: Int(sense.receptorCount))
      return try MetalRawSensorBufferLease(buffer: buffer, modality: sense.modality,
        receptorTimestamp: .init(microseconds: timestamp.rawValue - UInt64(sense.latencyMicroseconds)),
        receptorCount: sense.receptorCount, featureDimension: sense.observationDimension,
        validityBuffer: validity)
    }
  }

  private func begin(_ fixture: Fixture, step: UInt64 = 1,
    basePhysicsGeneration: UInt64 = 100) throws
    -> MetalNumiBrainRuntime.ControlTransaction {
    let generation = fixture.brain.committedGeneration
    return try fixture.brain.beginControl(controlStepIdentifier: step,
      basePhysicsGeneration: basePhysicsGeneration + generation,
      committedTimestamp: .init(microseconds: 10_000 + generation * 1_000),
      targetTimestamp: .init(microseconds: 11_000 + generation * 1_000),
      cachedDecisionFingerprint: 0x5500 + step)
  }

  private func read(_ buffer: any MTLBuffer, device: any MTLDevice) throws -> [UInt32] {
    let queue = try XCTUnwrap(device.makeCommandQueue())
    let command = try XCTUnwrap(queue.makeCommandBuffer())
    let blit = try XCTUnwrap(command.makeBlitCommandEncoder())
    let staging = try XCTUnwrap(device.makeBuffer(length: buffer.length, options: .storageModeShared))
    blit.copy(from: buffer, sourceOffset: 0, to: staging, destinationOffset: 0, size: buffer.length)
    blit.endEncoding(); command.commit(); command.waitUntilCompleted()
    XCTAssertEqual(command.status, .completed, "\(String(describing: command.error))")
    return Array(UnsafeBufferPointer(start: staging.contents().assumingMemoryBound(to: UInt32.self),
      count: staging.length / 4))
  }

  private func borrowedMotor(_ fixture: Fixture, root: MetalNumiBrainRuntime.ControlTransaction,
    critical: Bool = false) throws -> MetalNumiBrainRuntime.BorrowedMotorCommand {
    let input = try sensors(fixture, timestamp: root.token.committedTimestamp, critical: critical)
    let queue = try XCTUnwrap(fixture.device.makeCommandQueue())
    let command = try XCTUnwrap(queue.makeCommandBuffer())
    let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
    let motor = try fixture.brain.encodeBorrowedMotorCommand(root, encoder: encoder, rawSensors: input)
    let retry = try fixture.brain.encodeBorrowedMotorCommand(root, encoder: encoder, rawSensors: [])
    XCTAssertEqual(retry.candidate, motor.candidate, "a retry must reuse its protected command")
    encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
    XCTAssertEqual(command.status, .completed, "\(String(describing: command.error))")
    XCTAssertTrue(motor.evaluation.hasValidSuccess(), "the normal ready proof must authorize the command")
    return motor
  }

  private func acceptBorrowed(_ fixture: Fixture,
    root: MetalNumiBrainRuntime.ControlTransaction,
    motor: MetalNumiBrainRuntime.BorrowedMotorCommand) throws -> BrainJointCommitToken {
    let accepted = try AcceptedPhysicsStateToken(transaction: root.token, substep: motor.substep,
      physicsStateFingerprint: 0x8811, physicsGeneration: 101)
    let input = try sensors(fixture, timestamp: root.token.targetTimestamp)
    let queue = try XCTUnwrap(fixture.device.makeCommandQueue())
    let command = try XCTUnwrap(queue.makeCommandBuffer())
    let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
    try fixture.brain.encodeBorrowedAcceptedConsequence(root, encoder: encoder,
      accepted: accepted, rawSensors: input)
    encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
    XCTAssertEqual(command.status, .completed, "\(String(describing: command.error))")
    return try fixture.brain.finishBorrowedControl(root,
      gpuStartSeconds: command.gpuStartTime, gpuEndSeconds: command.gpuEndTime)
  }

  private func checkNativeWriter(_ fixture: Fixture,
    command motor: MetalNumiBrainRuntime.BorrowedMotorCommand) throws {
    let states = try XCTUnwrap(fixture.device.makeBuffer(length: 416 * 16, options: .storageModeShared))
    let values = states.contents().assumingMemoryBound(to: SIMD4<Float>.self)
    values.initialize(repeating: SIMD4<Float>(0.75, 0.25, 0.3, 0.4), count: 416)
    let queue = try XCTUnwrap(fixture.device.makeCommandQueue())
    func write(status: (any MTLBuffer)? = nil) throws {
      let command = try XCTUnwrap(queue.makeCommandBuffer())
      let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
      try fixture.brain.encodeBorrowedHumanExcitation(command: motor, encoder: encoder,
        destinationMuscleStates: states, standStatuses: status)
      encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
      XCTAssertEqual(command.status, .completed, "\(String(describing: command.error))")
    }
    let protected = try read(motor.buffers.excitationBuffer, device: fixture.device)
    try write()
    for index in 0..<416 {
      XCTAssertEqual(values[index].x.bitPattern, protected[index])
      XCTAssertEqual(values[index].y, 0.25)
      XCTAssertEqual(values[index].z, 0.3)
      XCTAssertEqual(values[index].w, 0.4)
    }
    // Corrupt the terminal proof only after completed test execution. The
    // consumer must fail closed even while the old excitations are finite.
    let gateProofWord = motor.evaluation.gateBuffer.contents().advanced(by: 8)
    let originalGateProof = gateProofWord.load(as: UInt32.self)
    defer { gateProofWord.storeBytes(of: originalGateProof, as: UInt32.self) }
    gateProofWord.storeBytes(of: UInt32(0), as: UInt32.self)
    try write()
    XCTAssertTrue((0..<416).allSatisfy { values[$0].x.isNaN })
    XCTAssertTrue((0..<416).allSatisfy { values[$0].y == 0.25 && values[$0].z == 0.3 && values[$0].w == 0.4 })
    let priorFailure = try XCTUnwrap(fixture.device.makeBuffer(length: 4, options: .storageModeShared))
    priorFailure.contents().storeBytes(of: UInt32(7), as: UInt32.self)
    values.initialize(repeating: SIMD4<Float>(0.75, 0.25, 0.3, 0.4), count: 416)
    try write(status: priorFailure)
    XCTAssertTrue((0..<416).allSatisfy { values[$0].x == 0.75 }, "a preexisting native failure remains untouched")
  }

  func testBorrowedProtectedOutputMatchesMetal4AndAbortPreservesHistory() throws {
    for critical in [false, true] {
      let borrowed = try makeFixture(), reference = try makeFixture()
      let base = try borrowed.brain.saveCheckpoint(controlStepIdentifier: 0, physicalCheckpointFingerprint: 99)
      let a = try begin(borrowed), b = try begin(reference, basePhysicsGeneration: 200)
      let actual = try borrowedMotor(borrowed, root: a, critical: critical)
      let input = try sensors(reference, timestamp: b.token.committedTimestamp, critical: critical)
      let packet = try NumanXSensorPacketLease(transaction: b.token,
        compiledSpeciesTemplate: reference.template, rawSensors: input)
      let decisionEvent = try XCTUnwrap(reference.device.makeSharedEvent())
      let motorEvent = try XCTUnwrap(reference.device.makeSharedEvent())
      let decision = try reference.brain.submitInferAndDecide(b, numanXSensors: packet,
        signal: .init(event: decisionEvent, value: 1))
      let expected = try reference.brain.submitNumanXMotorCandidate(decision,
        transaction: b, candidateDurationMicroseconds: 1_000,
        signal: .init(event: motorEvent, value: 1))
      _ = try reference.brain.finishNumanXMotorSubmission(expected, transaction: b)
      XCTAssertEqual(try read(actual.buffers.excitationBuffer, device: borrowed.device),
        try read(expected.buffers.excitationBuffer, device: reference.device))
      XCTAssertEqual(try read(actual.buffers.headerBuffer, device: borrowed.device),
        try read(expected.buffers.headerBuffer, device: reference.device))
      if critical {
        let values = try read(actual.buffers.excitationBuffer, device: borrowed.device).map(Float.init(bitPattern:))
        XCTAssertTrue(values.allSatisfy { $0 == 0 }, "the same-root physiological interrupt must inhibit descending drive")
      }
      try checkNativeWriter(borrowed, command: actual)
      try borrowed.brain.abortBorrowedControl(a)
      try reference.brain.abortControl(b)
      let after = try borrowed.brain.saveCheckpoint(controlStepIdentifier: 0, physicalCheckpointFingerprint: 99)
      XCTAssertEqual(after.cognitiveState, base.cognitiveState,
        "an executed rejected command must not publish cognitive history")
      XCTAssertEqual(after.fastTissueState.committedStep, base.fastTissueState.committedStep)
      XCTAssertEqual(after.fastTissueState.committedSchedulerGeneration,
        base.fastTissueState.committedSchedulerGeneration)
      XCTAssertEqual(after.fastTissueState.committedHistoryOwnerMask,
        base.fastTissueState.committedHistoryOwnerMask)
      XCTAssertEqual(after.fastTissueState.committedRelayHistoryTimestamps,
        base.fastTissueState.committedRelayHistoryTimestamps)
      let baseBuffers = Dictionary(uniqueKeysWithValues:
        base.fastTissueState.buffers.map { ($0.kind, $0.data) })
      // The rejected candidate can write an inactive timestamp plane. The
      // owner mask selects the committed plane; every other checkpoint buffer
      // must remain byte-identical, and owned timestamp bytes stay unchanged.
      let changedBuffers = after.fastTissueState.buffers.compactMap { buffer in
        buffer.kind == .relayHistoryTimestamps || baseBuffers[buffer.kind] == buffer.data
          ? nil : buffer.kind
      }
      XCTAssertEqual(changedBuffers, [], "an executed rejected command changed committed fast checkpoint buffers")
      let beforeTimes = base.fastTissueState.buffer(.relayHistoryTimestamps)
      let afterTimes = after.fastTissueState.buffer(.relayHistoryTimestamps)
      let planeSize = after.fastTissueState.committedRelayHistoryTimestamps.count
      for slot in 0..<planeSize {
        let owner = Int((after.fastTissueState.committedHistoryOwnerMask >> UInt32(slot)) & 1)
        let word = owner * planeSize + slot
        let range = (word * MemoryLayout<UInt64>.stride)..<((word + 1) * MemoryLayout<UInt64>.stride)
        XCTAssertEqual(afterTimes.subdata(in: range), beforeTimes.subdata(in: range),
          "an aborted candidate must not alter the owned timestamp plane")
        var timestamp = after.fastTissueState.committedRelayHistoryTimestamps[slot].littleEndian
        let expected = withUnsafeBytes(of: &timestamp) { Data($0) }
        XCTAssertEqual(afterTimes.subdata(in: range), expected,
          "owned GPU timestamps must match the committed runtime timestamps")
      }
    }
  }

  func testBorrowedAcceptedConsequencePublishesOnlyAfterOwnerCompletion() throws {
    let fixture = try makeFixture()
    let root = try begin(fixture)
    let motor = try borrowedMotor(fixture, root: root)
    let accepted = try AcceptedPhysicsStateToken(transaction: root.token, substep: motor.substep,
      physicsStateFingerprint: 0x8811, physicsGeneration: 101)
    let input = try sensors(fixture, timestamp: root.token.targetTimestamp)
    let queue = try XCTUnwrap(fixture.device.makeCommandQueue())
    let command = try XCTUnwrap(queue.makeCommandBuffer())
    let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
    try fixture.brain.encodeBorrowedAcceptedConsequence(root, encoder: encoder,
      accepted: accepted, rawSensors: input)
    XCTAssertEqual(fixture.brain.committedGeneration, 0)
    encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
    XCTAssertEqual(command.status, .completed, "\(String(describing: command.error))")
    let receipt = try fixture.brain.finishBorrowedControl(root,
      gpuStartSeconds: command.gpuStartTime, gpuEndSeconds: command.gpuEndTime)
    XCTAssertEqual(receipt.brainGeneration, 1)
    XCTAssertEqual(fixture.brain.committedGeneration, 1)
    XCTAssertEqual(root.status, .committed)
    XCTAssertThrowsError(try fixture.brain.finishBorrowedControl(root,
      gpuStartSeconds: command.gpuStartTime, gpuEndSeconds: command.gpuEndTime))
    let saved = try fixture.brain.saveCheckpoint(controlStepIdentifier: 1, physicalCheckpointFingerprint: 99)
    XCTAssertEqual(saved.cognitiveState.committedGeneration, saved.fastTissueState.committedSchedulerGeneration)
  }

  func testExecutedBorrowedAbortThenRetryMatchesFreshAcceptedRoot() throws {
    for critical in [false, true] {
      let retried = try makeFixture(), fresh = try makeFixture()
      let rejectedRoot = try begin(retried)
      _ = try borrowedMotor(retried, root: rejectedRoot, critical: critical)
      try retried.brain.abortBorrowedControl(rejectedRoot)

      let retryRoot = try begin(retried)
      let retryMotor = try borrowedMotor(retried, root: retryRoot, critical: critical)
      let retrySubstep = retryMotor.substep
      let retryExcitations = try read(retryMotor.buffers.excitationBuffer, device: retried.device)
      let retryHeader = try read(retryMotor.buffers.headerBuffer, device: retried.device)
      let retryReceipt = try acceptBorrowed(retried, root: retryRoot, motor: retryMotor)
      let retryState = try retried.brain.saveCheckpoint(controlStepIdentifier: 1,
        physicalCheckpointFingerprint: 99)

      let freshRoot = try begin(fresh)
      let freshMotor = try borrowedMotor(fresh, root: freshRoot, critical: critical)
      XCTAssertEqual(retrySubstep, freshMotor.substep)
      XCTAssertEqual(retryExcitations,
        try read(freshMotor.buffers.excitationBuffer, device: fresh.device))
      XCTAssertEqual(retryHeader,
        try read(freshMotor.buffers.headerBuffer, device: fresh.device))
      let freshReceipt = try acceptBorrowed(fresh, root: freshRoot, motor: freshMotor)
      XCTAssertEqual(retryReceipt, freshReceipt, "the accepted physical and neural receipt changed on retry")
      let freshState = try fresh.brain.saveCheckpoint(controlStepIdentifier: 1,
        physicalCheckpointFingerprint: 99)
      XCTAssertEqual(retryState, freshState,
        "an executed rejected root changed the accepted cognitive or fast checkpoint")
    }
  }
}

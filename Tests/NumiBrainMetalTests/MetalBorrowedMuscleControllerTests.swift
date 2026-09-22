import Foundation
import Metal
import XCTest
@testable import NumiBrainCore
@_spi(NumanXInterop) @testable import NumiBrainMetal

/// Numerical/transaction conformance only. Receptor values and physical
/// receipts below are software fixtures, not Human standing evidence.
@available(macOS 26.0, *)
final class MetalBorrowedMuscleControllerTests: XCTestCase {
  private func template() throws -> CompiledSpeciesTemplate {
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
    return try NumanXFullBodyTransportTemplate.compile(anatomy: .init(
      jointTopologyCatalog: topology,
      muscleAttachmentCatalog: .init(bodyCount: 123, attachments: attachments),
      headBodyIdentifier: 1))
  }

  private func program(_ body: CompiledSpeciesTemplate) throws -> MuscleLocomotorProgram {
    let baseline = MuscleLocomotorProgram(modelSourceFingerprint: 123,
      sensoryProfileFingerprint: body.sensoryProfile.fingerprint,
      calibrationArtifactSHA256: String(repeating: "a", count: 64),
      channels: (UInt32(0)..<416).map {
        MuscleLocomotorChannel(muscleIdentifier: $0, referenceLengthMeters: 0.25,
          tonicExcitation: 0.03, lengthGain: 0.4, velocityGainSeconds: 0.02)
      })
    let orientation = try XCTUnwrap(body.sensoryProfile.bodyReceptorBindings.first {
      $0.signal == .orientation && $0.component == 0
    })
    let feedback = MuscleBalanceFeedbackProgram(locomotorProgramFingerprint: baseline.fingerprint,
      modelSourceFingerprint: 123, sensoryProfileFingerprint: body.sensoryProfile.fingerprint,
      calibrationArtifactSHA256: String(repeating: "b", count: 64), mode: .posture,
      updatePeriodMicroseconds: 1_000, initializationDurationMicroseconds: 2_000,
      sources: [.init(identifier: 1, bodyReceptorBindingIdentifier: orientation.identifier,
        referenceValue: 0, filterTimeConstantSeconds: 0.001, conductionDelayMicroseconds: 1_000)],
      routes: [.init(sourceIdentifier: 1, muscleIdentifier: 0, gain: -0.2, maximumCorrection: 0.1)])
    return MuscleLocomotorProgram(modelSourceFingerprint: baseline.modelSourceFingerprint,
      sensoryProfileFingerprint: baseline.sensoryProfileFingerprint,
      calibrationArtifactSHA256: baseline.calibrationArtifactSHA256,
      channels: baseline.channels, balanceFeedback: feedback)
  }

  private func sensors(_ device: any MTLDevice, timestamp: UInt64,
    orientation: Float) throws -> [MetalRawSensorBufferLease] {
    func upload<T>(_ values: [T]) throws -> any MTLBuffer {
      try XCTUnwrap(values.withUnsafeBytes {
        device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
      })
    }
    var spindles = [Float](repeating: 0, count: 416 * 10)
    for muscle in 0..<416 { spindles[muscle * 10 + 4] = 0.26; spindles[muscle * 10 + 5] = 0.1 }
    var vestibular = [Float](repeating: 0, count: 22)
    vestibular[3] = orientation
    return try [
      MetalRawSensorBufferLease(buffer: upload(spindles), modality: .proprioception,
        receptorTimestamp: .init(microseconds: timestamp - 1_000), receptorCount: 416,
        featureDimension: 10, validityBuffer: upload([UInt32](repeating: 0x3ff, count: 416))),
      MetalRawSensorBufferLease(buffer: upload(vestibular), modality: .vestibular,
        receptorTimestamp: .init(microseconds: timestamp - 1_000), receptorCount: 1,
        featureDimension: 22, validityBuffer: upload([UInt32(0x3fffff)])),
    ]
  }

  private func root(_ runtime: MetalAgentStateRuntime, environment: UInt32,
    step: UInt64) throws -> MetalJointAgentStateTransaction {
    let generation = runtime.arena.committedGeneration
    let start = 1_000 + 1_000 * generation
    let token = try BrainJointTransactionToken(environmentIdentifier: environment,
      episodeIdentifier: UInt64(environment) + 1, controlStepIdentifier: step,
      parameterVersionFingerprint: 7, baseBrainGeneration: generation,
      basePhysicsGeneration: generation, committedTimestamp: .init(microseconds: start),
      targetTimestamp: .init(microseconds: start + 1_000), randomCounterGeneration: generation + 1)
    return try MetalJointAgentStateTransaction(jointToken: token, runtime: runtime,
      cachedDecisionFingerprint: step + 100)
  }

  private func receipt(_ root: BrainJointTransactionToken) throws
    -> (AcceptedPhysicsStateToken, BrainJointCommitToken) {
    var manager = BrainJointTransaction(token: root)
    let substep = try manager.beginPhysicsSubstep(durationMicroseconds: 1_000)
    let accepted = try AcceptedPhysicsStateToken(transaction: root, substep: substep,
      physicsStateFingerprint: root.controlStepIdentifier + 100,
      physicsGeneration: root.basePhysicsGeneration + 1)
    try manager.acceptPhysicsSubstep(accepted, for: substep)
    return (accepted, try manager.commit())
  }

  private func accept(_ transaction: MetalJointAgentStateTransaction) throws {
    let (accepted, commit) = try receipt(transaction.jointToken)
    try transaction.finishGPUState(acceptedPhysicsState: accepted)
    try transaction.commit(with: commit)
  }

  private func evaluate(_ controller: MetalMuscleLocomotorController,
    transaction: MetalJointAgentStateTransaction, sensors: [MetalRawSensorBufferLease],
    device: any MTLDevice, borrowed: Bool) throws -> [UInt32] {
    let output: MetalDescendingMotorView
    if borrowed {
      let queue = try XCTUnwrap(device.makeCommandQueue())
      let command = try XCTUnwrap(queue.makeCommandBuffer())
      let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
      output = try transaction.encodeMuscleLocomotor(controller, encoder: encoder, rawSensors: sensors)
      let retry = try transaction.encodeMuscleLocomotor(controller, encoder: encoder, rawSensors: [])
      XCTAssertEqual(retry.logits.gpuAddress, output.logits.gpuAddress,
        "retry must reuse its decision instead of consuming a new receptor packet")
      encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
      XCTAssertEqual(command.status, .completed, "\(String(describing: command.error))")
    } else {
      let queue = try XCTUnwrap(device.makeMTL4CommandQueue())
      let allocator = try XCTUnwrap(device.makeCommandAllocator())
      let command = try XCTUnwrap(device.makeCommandBuffer())
      let residency = try device.makeResidencySet(descriptor: MTLResidencySetDescriptor())
      for allocation in controller.residencyAllocations { residency.addAllocation(allocation) }
      for sensor in sensors {
        residency.addAllocation(sensor.buffer)
        if let validity = sensor.validityBuffer { residency.addAllocation(validity) }
      }
      residency.commit(); residency.requestResidency()
      defer { residency.endResidency() }
      command.beginCommandBuffer(allocator: allocator); command.useResidencySet(residency)
      let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
      output = try controller.encode(root: transaction.jointToken, encoder: encoder,
        rawSensors: sensors.map(\.view))
      encoder.endEncoding(); command.endCommandBuffer()
      final class Feedback: @unchecked Sendable { var error: Error? }
      let feedback = Feedback(), semaphore = DispatchSemaphore(value: 0)
      let options = MTL4CommitOptions()
      options.addFeedbackHandler { feedback.error = $0.error; semaphore.signal() }
      queue.commit([command], options: options)
      guard semaphore.wait(timeout: .now() + 30) == .success else {
        throw TissueError.metal("Metal4 comparison command timed out")
      }
      if let error = feedback.error { throw error }
    }
    return Array(UnsafeBufferPointer(start: output.logits.contents().assumingMemoryBound(to: UInt32.self),
      count: output.actuatorCount))
  }

  func testBorrowedParityRollbackAndOwnerIsolation() throws {
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
    let body = try template(), program = try program(body)
    let regional = try body.species.regionGraph.regionalProgram()
    let borrowedRuntime = try MetalAgentStateRuntime(device: device, species: body.species,
      regionalProgram: regional)
    let referenceRuntime = try MetalAgentStateRuntime(device: device, species: body.species,
      regionalProgram: regional)
    let borrowed = try MetalMuscleLocomotorController(program: program, template: body,
      parameterVersion: 7, device: device)
    let reference = try MetalMuscleLocomotorController(program: program, template: body,
      parameterVersion: 7, device: device)

    for step in UInt64(1)...4 {
      if step == 3 {
        // Only the borrowed path sees this executed, rejected receptor spike.
        let rejected = try root(borrowedRuntime, environment: 1, step: 30)
        _ = try evaluate(borrowed, transaction: rejected,
          sensors: sensors(device, timestamp: rejected.jointToken.committedTimestamp.rawValue,
            orientation: 10), device: device, borrowed: true)
        try rejected.abort()
        XCTAssertEqual(borrowedRuntime.arena.committedGeneration, 2)

        // Identical model/version/generation/time cannot transfer A's neural history to B.
        let foreign = try root(referenceRuntime, environment: 2, step: 31)
        let queue = try XCTUnwrap(device.makeCommandQueue())
        let command = try XCTUnwrap(queue.makeCommandBuffer())
        let encoder = try XCTUnwrap(command.makeComputeCommandEncoder())
        XCTAssertThrowsError(try foreign.encodeMuscleLocomotor(borrowed, encoder: encoder,
          rawSensors: sensors(device, timestamp: foreign.jointToken.committedTimestamp.rawValue,
            orientation: 0.3)))
        encoder.endEncoding() // Abandon the unsubmitted command.
        try foreign.abort()

        let failed = try root(borrowedRuntime, environment: 1, step: 32)
        let failedCommand = try XCTUnwrap(queue.makeCommandBuffer())
        let failedEncoder = try XCTUnwrap(failedCommand.makeComputeCommandEncoder())
        XCTAssertThrowsError(try failed.encodeMuscleLocomotor(borrowed, encoder: failedEncoder, rawSensors: []))
        failedEncoder.endEncoding() // No submission follows an encoding failure.
        let (accepted, commit) = try receipt(failed.jointToken)
        XCTAssertThrowsError(try failed.finishGPUState(acceptedPhysicsState: accepted))
        XCTAssertThrowsError(try failed.commit(with: commit))
        try failed.abort()
        XCTAssertEqual(borrowedRuntime.arena.committedGeneration, 2)
      }
      let a = try root(borrowedRuntime, environment: 1, step: step)
      let b = try root(referenceRuntime, environment: 2, step: step)
      let input = try sensors(device, timestamp: a.jointToken.committedTimestamp.rawValue,
        orientation: Float(step) * 0.1)
      let actual = try evaluate(borrowed, transaction: a, sensors: input, device: device, borrowed: true)
      let expected = try evaluate(reference, transaction: b, sensors: input, device: device, borrowed: false)
      XCTAssertEqual(actual, expected, "same shaders must agree bitwise at accepted step \(step)")
      if step >= 3 {
        XCTAssertNotEqual(actual[0], actual[1], "delayed balance feedback must actually affect its routed muscle")
      }
      try accept(a); try accept(b)
    }
    XCTAssertEqual(borrowedRuntime.arena.committedGeneration, 4)
    XCTAssertEqual(referenceRuntime.arena.committedGeneration, 4)
  }
}

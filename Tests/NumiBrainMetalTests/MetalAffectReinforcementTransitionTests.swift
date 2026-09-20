import Metal
import XCTest

@testable import NumiBrainCore
@testable import NumiBrainMetal

/// Accepted-root regression for the signed homeostatic and independent pain
/// components of lived reinforcement. This is a synthetic Metal test, not a
/// NumanX physical qualification.
@available(macOS 26.0, *)
final class MetalAffectReinforcementTransitionTests: XCTestCase {
  private let environmentIdentifier: UInt32 = 7
  private let episodeIdentifier: UInt64 = 23

  func testCommittedInjuryRecoveryReinjuryKeepsSignedAndPainFactorsSeparate()
    throws
  {
    let fixture = try makeFixture()
    let start = UInt64(10_000)
    try seedDrivesForIsolatedTransition(fixture, timestamp: start)
    let stepDurations: [UInt64] = [
      1_000, 50_000_000, 50_000_000, 1_000, 50_000_000,
    ]
    let healthy: Physiology = .init(tissueDamage: 0, nociception: 0)
    let injured: Physiology = .init(tissueDamage: 0.8, nociception: 0.8)

    // The first accepted root creates injury. Later roots read the prior
    // committed physiology while accepting alternating recovery and reinjury
    // states, so each physical change enters reinforcement on the next root.
    let acceptedInjury = try runAcceptedRoot(
      fixture,
      step: 0,
      committedTimestamp: start,
      duration: stepDurations[0],
      committedPhysiology: healthy,
      acceptedPhysiology: injured
    )
    let injuryTransition = try runAcceptedRoot(
      fixture,
      step: 1,
      committedTimestamp: acceptedInjury.endTimestamp,
      duration: stepDurations[1],
      committedPhysiology: injured,
      acceptedPhysiology: healthy
    )
    let recoveryTransition = try runAcceptedRoot(
      fixture,
      step: 2,
      committedTimestamp: injuryTransition.endTimestamp,
      duration: stepDurations[2],
      committedPhysiology: healthy,
      acceptedPhysiology: injured
    )
    let reinjuryTransition = try runAcceptedRoot(
      fixture,
      step: 3,
      committedTimestamp: recoveryTransition.endTimestamp,
      duration: stepDurations[3],
      committedPhysiology: injured,
      acceptedPhysiology: healthy
    )
    let secondRecoveryTransition = try runAcceptedRoot(
      fixture,
      step: 4,
      committedTimestamp: reinjuryTransition.endTimestamp,
      duration: stepDurations[4],
      committedPhysiology: healthy,
      acceptedPhysiology: injured
    )
    XCTAssertLessThan(
      injuryTransition.factoredReinforcement[0], -0.05,
      "rising injury deficit must retain a negative signed homeostatic factor"
    )
    XCTAssertGreaterThan(
      recoveryTransition.factoredReinforcement[0], 0.05,
      "recovery after the long rest must retain a positive homeostatic factor"
    )
    XCTAssertLessThan(
      reinjuryTransition.factoredReinforcement[0], -0.05,
      "reinjury must reverse the homeostatic factor back below zero"
    )
    XCTAssertGreaterThan(
      secondRecoveryTransition.factoredReinforcement[0], 0.05,
      "the second recovery should retain its signed homeostatic contribution"
    )
    XCTAssertLessThanOrEqual(
      injuryTransition.factoredReinforcement[0]
        + recoveryTransition.factoredReinforcement[0]
        + reinjuryTransition.factoredReinforcement[0]
        + secondRecoveryTransition.factoredReinforcement[0],
      1.0e-5,
      "two injury/recovery cycles must not accumulate positive homeostatic balance"
    )

    for transition in [
      injuryTransition, recoveryTransition, reinjuryTransition,
      secondRecoveryTransition,
    ] {
      let homeostatic = transition.factoredReinforcement[0]
      let painCost = transition.factoredReinforcement[4]
      XCTAssertLessThan(
        painCost, -0.3,
        "accepted pain must remain present in its independent penalty component"
      )
      XCTAssertGreaterThan(
        abs(homeostatic - painCost), 0.1,
        "pain cost must not replace or sign-clamp the homeostatic delta"
      )
    }

    XCTAssertGreaterThan(
      acceptedInjury.affect[0], 0.75,
      "the accepted injury should be retained as pain in lived transition data"
    )
    XCTAssertGreaterThan(
      injuryTransition.affect[1], 0.75,
      "relief on the accepted recovery should retain positive pleasure"
    )
    XCTAssertGreaterThan(
      reinjuryTransition.affect[1], 0.75,
      "the second accepted recovery should also produce bounded relief pleasure"
    )
    XCTAssertGreaterThan(
      secondRecoveryTransition.affect[0], 0.75,
      "the second accepted reinjury should raise affective pain again"
    )
    XCTAssertEqual(
      secondRecoveryTransition.endTimestamp,
      start + stepDurations.reduce(0, +)
    )
  }

  private struct Physiology {
    let tissueDamage: Float
    let nociception: Float

    var interoception: [Float] {
      [1, 1, 0, 0, 0, tissueDamage]
    }
  }

  private struct TransitionObservation {
    let endTimestamp: UInt64
    let factoredReinforcement: [Float]
    let affect: [Float]
  }

  private struct Fixture {
    let device: any MTLDevice
    let compiled: CompiledSpeciesTemplate
    let runtime: MetalEmbodiedBrainRuntime
    let recurrentView: MetalRegionalRecurrentBufferView
  }

  private func seedDrivesForIsolatedTransition(
    _ fixture: Fixture,
    timestamp: UInt64
  ) throws {
    let physicalCheckpointFingerprint: UInt64 = 0xaffec7
    let original = try fixture.runtime.saveCheckpoint(
      environmentIdentifier: environmentIdentifier,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: 0,
      committedTimestamp: BrainTimestamp(microseconds: timestamp),
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    var hotState = original.hotState
    let section = fixture.runtime.agentStateRuntime.arena.layout.section(.drives)
    hotState.withUnsafeMutableBytes { bytes in
      for index in DriveKind.allCases.indices {
        let base = section.byteOffset + index * section.elementStride
        bytes.storeBytes(of: Float(0), toByteOffset: base, as: Float.self)
        bytes.storeBytes(of: Float(0), toByteOffset: base + 4, as: Float.self)
        bytes.storeBytes(
          of: index < 8 ? Float(0.1) : Float(1),
          toByteOffset: base + 8,
          as: Float.self
        )
        bytes.storeBytes(
          of: index == Int(DriveKind.injury.rawValue - 1) ? Float(1) : Float(0),
          toByteOffset: base + 12,
          as: Float.self
        )
        bytes.storeBytes(of: Float(0), toByteOffset: base + 16, as: Float.self)
        bytes.storeBytes(of: Float(0), toByteOffset: base + 20, as: Float.self)
        bytes.storeBytes(of: Float(0), toByteOffset: base + 24, as: Float.self)
        bytes.storeBytes(
          of: UInt32(index + 1), toByteOffset: base + 28, as: UInt32.self
        )
      }
    }
    let seeded = try MetalBrainCheckpoint(
      committedGeneration: original.committedGeneration,
      committedTimestamp: original.committedTimestamp,
      environmentIdentifier: original.environmentIdentifier,
      episodeIdentifier: original.episodeIdentifier,
      controlStepIdentifier: original.controlStepIdentifier,
      speciesTemplateFingerprint: original.speciesTemplateFingerprint,
      compiledSpeciesTemplateFingerprint:
        original.compiledSpeciesTemplateFingerprint,
      regionalProgramFingerprint: original.regionalProgramFingerprint,
      scheduleFingerprint: original.scheduleFingerprint,
      parameterVersionFingerprint: original.parameterVersionFingerprint,
      hotLayoutFingerprint: original.hotLayoutFingerprint,
      memoryLayoutFingerprint: original.memoryLayoutFingerprint,
      physicalCheckpointFingerprint: original.physicalCheckpointFingerprint,
      hotState: hotState,
      persistentMemory: original.persistentMemory,
      connectomeState: original.connectomeState,
      muscleLocomotorFingerprint: original.muscleLocomotorFingerprint
    )
    try fixture.runtime.loadCheckpoint(
      seeded,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
  }

  private func makeFixture() throws -> Fixture {
    let device = try requireMetal4Device()
    let painRule = try ReceptorEventRule(
      identifier: 0x5041_494e,
      modality: .touch,
      receptorStart: 0,
      receptorCount: 1,
      featureIndex: 0,
      comparison: .greaterThan,
      threshold: 0.1,
      magnitudeScale: 1,
      eventKind: .pain,
      usesAbsoluteThreshold: true
    )
    let compiled = try makeNumanXInteropCompiledTemplate(
      touchReceptorCount: 1,
      touchFeatureDimension: 1,
      includeTouchNociceptionBinding: true,
      interoceptionFeatureDimension:
        InteroceptiveFeatureSchema.NumanXFullBodyV1.featureDimension,
      interoceptionFeatureSchemaFingerprint:
        InteroceptiveFeatureSchema.NumanXFullBodyV1.fingerprint,
      extraEventRules: [painRule]
    )
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
    let recurrent = try XCTUnwrap(
      device.makeBuffer(
        length: regionalProgram.scalarCount * MemoryLayout<Float>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    )
    recurrent.contents().initializeMemory(
      as: UInt8.self,
      repeating: 0,
      count: recurrent.length
    )
    let recurrentView = try MetalRegionalRecurrentBufferView(
      gpuAddress: recurrent.gpuAddress,
      scalarCount: regionalProgram.scalarCount,
      regionalProgramFingerprint: regionalProgram.fingerprint
    )
    return Fixture(
      device: device,
      compiled: compiled,
      runtime: runtime,
      recurrentView: recurrentView
    )
  }

  private func runAcceptedRoot(
    _ fixture: Fixture,
    step: UInt64,
    committedTimestamp: UInt64,
    duration: UInt64,
    committedPhysiology: Physiology,
    acceptedPhysiology: Physiology
  ) throws -> TransitionObservation {
    let targetTimestamp = committedTimestamp + duration
    let token = try BrainJointTransactionToken(
      environmentIdentifier: environmentIdentifier,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: step + 1,
      parameterVersionFingerprint: fixture.runtime.parameterVersionFingerprint,
      baseBrainGeneration: step,
      basePhysicsGeneration: 100 + step,
      committedTimestamp: BrainTimestamp(microseconds: committedTimestamp),
      targetTimestamp: BrainTimestamp(microseconds: targetTimestamp),
      randomCounterGeneration: step
    )
    let transaction = try fixture.runtime.beginControl(
      jointToken: token,
      cachedDecisionFingerprint: 0xa77e_4000 + step
    )
    defer {
      if transaction.status != .committed {
        try? fixture.runtime.abort(transaction: transaction)
      }
    }
    _ = try fixture.runtime.inferAndDecide(
      transaction: transaction,
      numanXSensors: try makeSensors(
        fixture,
        token: token,
        acceptedPhysicsState: nil,
        physiology: committedPhysiology
      ),
      regionalRecurrentInput: fixture.recurrentView
    )

    var physicalLedger = BrainJointTransaction(token: token)
    let substep = try physicalLedger.beginPhysicsSubstep(
      durationMicroseconds: duration
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: token,
      substep: substep,
      physicsStateFingerprint: 0xa77e_5000 + step,
      physicsGeneration: token.basePhysicsGeneration + 1
    )
    try physicalLedger.acceptPhysicsSubstep(accepted, for: substep)
    let acceptedSensors = try makeSensors(
      fixture,
      token: token,
      acceptedPhysicsState: accepted,
      physiology: acceptedPhysiology
    )
    let gateBuffer = try XCTUnwrap(
      fixture.device.makeBuffer(
        length: MetalAcceptedPhysicsGateLease.byteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    )
    gateBuffer.contents().initializeMemory(
      as: UInt8.self,
      repeating: 0,
      count: gateBuffer.length
    )
    var acceptedABI = accepted.abiRecord
    withUnsafeBytes(of: &acceptedABI) { bytes in
      gateBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
    let event = try XCTUnwrap(fixture.device.makeSharedEvent())
    let ticket = try fixture.runtime.submitAcceptedConsequence(
      transaction: transaction,
      acceptedPhysicsState: accepted,
      candidateSubstep: substep,
      acceptedPhysicsGate: try MetalAcceptedPhysicsGateLease(buffer: gateBuffer),
      numanXSensors: acceptedSensors,
      acceptedRegionalRecurrentInput: fixture.recurrentView,
      signal: try MetalSharedEventPoint(event: event, value: 1)
    )
    XCTAssertTrue(event.wait(untilSignaledValue: 1, timeoutMS: 20_000))
    _ = try fixture.runtime.finishAcceptedConsequenceSubmission(
      ticket,
      transaction: transaction,
      acceptedPhysicsState: accepted,
      timeoutMilliseconds: 20_000
    )
    try fixture.runtime.commit(
      transaction: transaction,
      receipt: physicalLedger.commit()
    )

    let batch = try fixture.runtime.makeLearningBatch()
    let lease = try batch.makeSharedStorageLease(for: .committedTransitions)
    let bytes = UnsafeRawPointer(lease.baseAddress)
    let contract = BrainExecutableModelContract.CommittedTransition.self
    func readUInt32(_ offset: Int) -> UInt32 {
      UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }
    func readUInt64(_ offset: Int) -> UInt64 {
      UInt64(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt64.self))
    }
    let record = try XCTUnwrap((0..<batch.transitionCapacity).first { index in
      let base = index * batch.transitionStride
      return readUInt64(base + contract.Offset.identifier) > 0
        && readUInt32(base + contract.Offset.formatVersion) == contract.recordVersion
        && (readUInt32(base + contract.Offset.flags) & contract.validFlag) != 0
        && readUInt64(base + contract.Offset.endTimestamp) == targetTimestamp
    })
    let base = record * batch.transitionStride
    let reinforcement = (0..<contract.Count.factoredReinforcement).map { index in
      bytes.loadUnaligned(
        fromByteOffset: base + contract.Offset.factoredReinforcement
          + index * MemoryLayout<Float>.stride,
        as: Float.self
      )
    }
    let affect = (0..<contract.Count.affect).map { index in
      bytes.loadUnaligned(
        fromByteOffset: base + contract.Offset.affect
          + index * MemoryLayout<Float>.stride,
        as: Float.self
      )
    }
    return TransitionObservation(
      endTimestamp: targetTimestamp,
      factoredReinforcement: reinforcement,
      affect: affect
    )
  }

  private func makeSensors(
    _ fixture: Fixture,
    token: BrainJointTransactionToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken?,
    physiology: Physiology
  ) throws -> NumanXSensorPacketLease {
    let deliveryTimestamp = acceptedPhysicsState?.acceptedTimestamp
      ?? token.committedTimestamp
    let rawSensors = try fixture.compiled.species.senses.filter(\.enabled)
      .map { topology in
        let count = Int(topology.receptorCount) * Int(topology.observationDimension)
        let buffer = try XCTUnwrap(
          fixture.device.makeBuffer(
            length: count * MemoryLayout<Float>.stride,
            options: [.storageModeShared, .hazardTrackingModeTracked]
          )
        )
        let values = buffer.contents().assumingMemoryBound(to: Float.self)
        values.initialize(repeating: 0, count: count)
        if topology.modality == .interoception {
          for receptor in 0..<Int(topology.receptorCount) {
            for feature in 0..<Int(topology.observationDimension) {
              values[receptor * Int(topology.observationDimension) + feature]
                = physiology.interoception[feature]
            }
          }
        } else if topology.modality == .touch, count > 0 {
          values[0] = physiology.nociception
        }
        return try MetalRawSensorBufferLease(
          buffer: buffer,
          modality: topology.modality,
          receptorTimestamp: BrainTimestamp(
            microseconds: deliveryTimestamp.rawValue
              - UInt64(topology.latencyMicroseconds)
          ),
          receptorCount: topology.receptorCount,
          featureDimension: topology.observationDimension
        )
      }
    return try NumanXSensorPacketLease(
      transaction: token,
      acceptedPhysicsState: acceptedPhysicsState,
      compiledSpeciesTemplate: fixture.compiled,
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
      throw XCTSkip("Metal 4 accepted-root execution is unavailable")
    }
    return device
  }
}

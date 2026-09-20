import Metal
import XCTest

@testable import NumiBrainCore
@testable import NumiBrainMetal

/// Deterministic accepted-root replay across a checkpoint boundary. These
/// synthetic Metal runs exercise state continuity only; they are not NumanX
/// physical qualification.
@available(macOS 26.0, *)
final class MetalAffectReplayChunkingTests: XCTestCase {
  private let environmentIdentifier: UInt32 = 7
  private let episodeIdentifier: UInt64 = 23
  private let physicalCheckpointFingerprint: UInt64 = 0xaffec7

  func testTimestampedInteroceptionAndNociceptionReplayMatchesChunkedRestore()
    throws
  {
    let fixtureTemplate = try makeTemplate()
    let frames = makeFrames()

    let continuous = try makeFixture(template: fixtureTemplate)
    var continuousSnapshots: [MetalAgentStateRuntime.CheckpointPayload] = []
    for (index, frame) in frames.enumerated() {
      continuousSnapshots.append(try runAcceptedRoot(
        continuous,
        frame: frame,
        index: index
      ))
    }

    // Chunk the same timestamped input stream after a repeated frame and
    // receptor-validity dropout, then continue from the accepted checkpoint.
    let chunkedPrefix = try makeFixture(template: fixtureTemplate)
    var prefixSnapshots: [MetalAgentStateRuntime.CheckpointPayload] = []
    for (index, frame) in frames.prefix(3).enumerated() {
      prefixSnapshots.append(try runAcceptedRoot(
        chunkedPrefix,
        frame: frame,
        index: index
      ))
    }
    let splitIndex = 2
    let acceptedCheckpoint = try chunkedPrefix.runtime.saveCheckpoint(
      environmentIdentifier: environmentIdentifier,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: UInt64(splitIndex + 1),
      committedTimestamp: frames[splitIndex].targetTimestamp,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )

    let restored = try makeFixture(template: fixtureTemplate)
    try restored.runtime.loadCheckpoint(
      acceptedCheckpoint,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    XCTAssertEqual(
      try restored.runtime.saveCheckpoint(
        environmentIdentifier: environmentIdentifier,
        episodeIdentifier: episodeIdentifier,
        controlStepIdentifier: UInt64(splitIndex + 1),
        committedTimestamp: frames[splitIndex].targetTimestamp,
        physicalCheckpointFingerprint: physicalCheckpointFingerprint
      ),
      acceptedCheckpoint,
      "restore must preserve the accepted chunk boundary exactly"
    )

    var chunkedSnapshots = prefixSnapshots
    for index in frames.indices.dropFirst(splitIndex + 1) {
      chunkedSnapshots.append(try runAcceptedRoot(
        restored,
        frame: frames[index],
        index: index
      ))
    }

    let affectSection = continuous.runtime.agentStateRuntime.arena.layout
      .section(.affectiveState)
    let continuousFinal = try XCTUnwrap(continuousSnapshots.last)
    let chunkedFinal = try XCTUnwrap(chunkedSnapshots.last)
    let continuousAffect = affectBytes(
      continuousFinal.hotState,
      sectionOffset: affectSection.byteOffset,
      byteCount: affectSection.byteCount
    )
    let restoredSection = restored.runtime.agentStateRuntime.arena.layout
      .section(.affectiveState)
    let chunkedAffect = affectBytes(
      chunkedFinal.hotState,
      sectionOffset: restoredSection.byteOffset,
      byteCount: restoredSection.byteCount
    )

    XCTAssertEqual(continuousAffect, chunkedAffect)
    XCTAssertEqual(fingerprint(continuousAffect), fingerprint(chunkedAffect))
    XCTAssertEqual(continuousFinal.hotState, chunkedFinal.hotState)
    XCTAssertEqual(continuousFinal.generation, UInt64(frames.count))
    XCTAssertEqual(chunkedFinal.generation, UInt64(frames.count))

    let repeatedFrame = try XCTUnwrap(continuousSnapshots[safe: 1])
    let dropoutFrame = try XCTUnwrap(continuousSnapshots[safe: 2])
    let recoveredFrame = try XCTUnwrap(continuousSnapshots[safe: 3])
    let repeatedAffect = affectBytes(
      repeatedFrame.hotState,
      sectionOffset: affectSection.byteOffset,
      byteCount: affectSection.byteCount
    )
    let dropoutAffect = affectBytes(
      dropoutFrame.hotState,
      sectionOffset: affectSection.byteOffset,
      byteCount: affectSection.byteCount
    )
    let recoveredAffect = affectBytes(
      recoveredFrame.hotState,
      sectionOffset: affectSection.byteOffset,
      byteCount: affectSection.byteCount
    )
    XCTAssertEqual(readUInt16(repeatedAffect, offset: 36) & 0x1f, 0x1f)
    XCTAssertEqual(readUInt16(dropoutAffect, offset: 36) & 0x1f, 0)
    XCTAssertGreaterThan(readFloat(dropoutAffect, offset: 0), 0)
    XCTAssertGreaterThan(readFloat(recoveredAffect, offset: 4), 0)
    XCTAssertGreaterThan(readFloat(recoveredAffect, offset: 8), 0)
  }

  private struct Frame {
    let targetTimestamp: BrainTimestamp
    let interoception: [Float]
    let nociception: Float
    let interoceptionValid: Bool
  }

  private struct Fixture {
    let device: any MTLDevice
    let compiled: CompiledSpeciesTemplate
    let runtime: MetalEmbodiedBrainRuntime
    let recurrentView: MetalRegionalRecurrentBufferView
  }

  private func makeFrames() -> [Frame] {
    let repeatedInjury: [Float] = [0.2, 0.4, 0.6, 0.4, 0.8, 0.7]
    let recovered: [Float] = [1, 1, 0, 0, 0, 0.1]
    return [
      Frame(
        targetTimestamp: BrainTimestamp(microseconds: 11_000),
        interoception: repeatedInjury,
        nociception: 0.25,
        interoceptionValid: true
      ),
      // Same timestamped body evidence values: a repeated physiological frame.
      Frame(
        targetTimestamp: BrainTimestamp(microseconds: 12_000),
        interoception: repeatedInjury,
        nociception: 0.25,
        interoceptionValid: true
      ),
      Frame(
        targetTimestamp: BrainTimestamp(microseconds: 13_000),
        interoception: [1, 1, 0, 0, 0, 0],
        nociception: 0.9,
        interoceptionValid: false
      ),
      Frame(
        targetTimestamp: BrainTimestamp(microseconds: 14_000),
        interoception: recovered,
        nociception: 0.1,
        interoceptionValid: true
      ),
      Frame(
        targetTimestamp: BrainTimestamp(microseconds: 15_000),
        interoception: recovered,
        nociception: 0.1,
        interoceptionValid: true
      ),
    ]
  }

  private func makeTemplate() throws -> CompiledSpeciesTemplate {
    try makeNumanXInteropCompiledTemplate(
      touchReceptorCount: 1,
      touchFeatureDimension: 1,
      includeTouchNociceptionBinding: true,
      interoceptorCount: 1,
      interoceptionFeatureDimension:
        InteroceptiveFeatureSchema.NumanXFullBodyV1.featureDimension,
      interoceptionFeatureSchemaFingerprint:
        InteroceptiveFeatureSchema.NumanXFullBodyV1.fingerprint
    )
  }

  private func makeFixture(template: CompiledSpeciesTemplate) throws -> Fixture {
    let device = try requireMetal4Device()
    let parameters = TissueParameters.corticalSheetV0
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: template.species,
      tissueParameters: parameters
    )
    let regionalProgram = try template.species.regionalProgram()
    let runtime = try MetalEmbodiedBrainRuntime(
      device: device,
      compiledSpeciesTemplate: template,
      regionalProgram: regionalProgram,
      parameterVersion: publication.version,
      sharedParameterArtifact: publication.sharedArtifact,
      affectiveModelConfiguration: .reference
    )
    let recurrentBuffer = try XCTUnwrap(
      device.makeBuffer(
        length: regionalProgram.scalarCount * MemoryLayout<Float>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    )
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
      compiled: template,
      runtime: runtime,
      recurrentView: recurrentView
    )
  }

  private func runAcceptedRoot(
    _ fixture: Fixture,
    frame: Frame,
    index: Int
  ) throws -> MetalAgentStateRuntime.CheckpointPayload {
    let committedTimestamp = BrainTimestamp(
      microseconds: frame.targetTimestamp.rawValue - 1_000
    )
    let token = try BrainJointTransactionToken(
      environmentIdentifier: environmentIdentifier,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: UInt64(index + 1),
      parameterVersionFingerprint:
        fixture.runtime.parameterVersionFingerprint,
      baseBrainGeneration: UInt64(index),
      basePhysicsGeneration: UInt64(100 + index),
      committedTimestamp: committedTimestamp,
      targetTimestamp: frame.targetTimestamp,
      randomCounterGeneration: UInt64(index)
    )
    let transaction = try fixture.runtime.beginControl(
      jointToken: token,
      cachedDecisionFingerprint: 0xa77e_4000 + UInt64(index)
    )
    defer {
      if transaction.status != .committed {
        try? fixture.runtime.abort(transaction: transaction)
      }
    }

    _ = try fixture.runtime.inferAndDecide(
      transaction: transaction,
      numanXSensors: try makeSensorPacket(
        fixture,
        token: token,
        acceptedPhysicsState: nil,
        targetTimestamp: committedTimestamp,
        interoception: Array(repeating: 1, count: 6),
        nociception: 0,
        interoceptionValid: true
      ),
      regionalRecurrentInput: fixture.recurrentView
    )

    var physicalLedger = BrainJointTransaction(token: token)
    let substep = try physicalLedger.beginPhysicsSubstep(
      durationMicroseconds: frame.targetTimestamp.rawValue
        - committedTimestamp.rawValue
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: token,
      substep: substep,
      physicsStateFingerprint: 0xa77e_5000 + UInt64(index),
      physicsGeneration: token.basePhysicsGeneration + 1
    )
    try physicalLedger.acceptPhysicsSubstep(accepted, for: substep)
    let acceptedSensors = try makeSensorPacket(
      fixture,
      token: token,
      acceptedPhysicsState: accepted,
      targetTimestamp: frame.targetTimestamp,
      interoception: frame.interoception,
      nociception: frame.nociception,
      interoceptionValid: frame.interoceptionValid
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
        from: bytes.baseAddress!,
        byteCount: bytes.count
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
    return try fixture.runtime.agentStateRuntime.snapshotCommittedState()
  }

  private func makeSensorPacket(
    _ fixture: Fixture,
    token: BrainJointTransactionToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken?,
    targetTimestamp: BrainTimestamp,
    interoception: [Float],
    nociception: Float,
    interoceptionValid: Bool
  ) throws -> NumanXSensorPacketLease {
    let rawSensors = try fixture.compiled.species.senses.filter(\.enabled).map {
      topology -> MetalRawSensorBufferLease in
      let scalarCount = Int(topology.receptorCount)
        * Int(topology.observationDimension)
      let buffer = try XCTUnwrap(
        fixture.device.makeBuffer(
          length: scalarCount * MemoryLayout<Float>.stride,
          options: [.storageModeShared, .hazardTrackingModeTracked]
        )
      )
      let values = buffer.contents().assumingMemoryBound(to: Float.self)
      values.initialize(repeating: 0, count: scalarCount)
      if topology.modality == .interoception {
        guard interoception.count == Int(topology.observationDimension) else {
          throw BrainRuntimeError.invalidEvent(
            "test interoception sample does not match the template schema"
          )
        }
        for feature in interoception.indices {
          values[feature] = interoception[feature]
        }
      } else if topology.modality == .touch, scalarCount > 0 {
        values[0] = nociception
      }

      let validityBuffer: (any MTLBuffer)?
      if topology.modality == .interoception && !interoceptionValid {
        let created = try XCTUnwrap(
          fixture.device.makeBuffer(
            length: Int(topology.receptorCount) * MemoryLayout<UInt32>.stride,
            options: [.storageModeShared, .hazardTrackingModeTracked]
          )
        )
        created.contents().assumingMemoryBound(to: UInt32.self)
          .initialize(repeating: 0, count: Int(topology.receptorCount))
        validityBuffer = created
      } else {
        validityBuffer = nil
      }
      guard targetTimestamp.rawValue >= UInt64(topology.latencyMicroseconds) else {
        throw BrainRuntimeError.invalidEvent("test timestamp precedes sensor latency")
      }
      return try MetalRawSensorBufferLease(
        buffer: buffer,
        modality: topology.modality,
        receptorTimestamp: BrainTimestamp(
          microseconds: targetTimestamp.rawValue
            - UInt64(topology.latencyMicroseconds)
        ),
        receptorCount: topology.receptorCount,
        featureDimension: topology.observationDimension,
        validityBuffer: validityBuffer
      )
    }
    return try NumanXSensorPacketLease(
      transaction: token,
      acceptedPhysicsState: acceptedPhysicsState,
      compiledSpeciesTemplate: fixture.compiled,
      rawSensors: rawSensors
    )
  }

  private func affectBytes(
    _ hotState: Data,
    sectionOffset: Int,
    byteCount: Int
  ) -> Data {
    hotState.subdata(in: sectionOffset..<(sectionOffset + byteCount))
  }

  private func readFloat(_ bytes: Data, offset: Int) -> Float {
    bytes.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: offset, as: Float.self)
    }
  }

  private func readUInt16(_ bytes: Data, offset: Int) -> UInt16 {
    bytes.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
    }
  }

  private func fingerprint(_ bytes: Data) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in bytes {
      hash ^= UInt64(byte)
      hash &*= 1_099_511_628_211
    }
    return hash
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

private extension Collection {
  subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

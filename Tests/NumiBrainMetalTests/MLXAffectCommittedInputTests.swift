import Metal
import MLX
import XCTest

@testable import NumiBrainCore
@testable import NumiBrainMetal
@testable import NumiBrainMLX

/// Verifies that committed affect metadata survives the real learner-boundary
/// transition decoder and changes only the evidence-gated learning emphasis.
@available(macOS 26.0, *)
final class MLXAffectCommittedInputTests: XCTestCase {
  private typealias ABI = BrainExecutableModelContract.CommittedTransition

  func testCommittedAffectEvidenceReachesLearningInputsWithoutChangingRewardWidth() throws {
    guard let device = MTLCreateSystemDefaultDevice() else {
      throw XCTSkip("Metal shared memory is unavailable")
    }

    let transitionStorage = try makeSnapshotBuffer(
      device: device,
      section: .committedTransitions,
      elementCount: 2,
      elementStride: ABI.strideBytes,
      generation: 5
    )
    writeTransition(
      to: transitionStorage,
      slot: 0,
      identifier: 101,
      sourceGeneration: 5,
      parameterFingerprint: 77,
      startTimestamp: 1_000,
      endTimestamp: 2_000,
      affect: [0.2, 0.8, 0.5, 0.1, 0.2, 0.3, 0.4, 0.5],
      sourceMask: 1 << 4
    )
    writeTransition(
      to: transitionStorage,
      slot: 1,
      identifier: 102,
      sourceGeneration: 5,
      parameterFingerprint: 77,
      startTimestamp: 2_000,
      endTimestamp: 3_000,
      affect: [0.9, 0.7, 0.6, 0, 0, 0, 0, 0],
      sourceMask: 0
    )

    let source = try MetalLearningBatch(
      transitions: transitionStorage,
      livedEpisodes: makeSnapshotBuffer(
        device: device, section: .activeEpisodes,
        elementCount: 1, elementStride: MetalLearningBatch.episodicStride,
        generation: 5
      ),
      warmEpisodes: makeSnapshotBuffer(
        device: device, section: .warmEpisodes,
        elementCount: 1, elementStride: MetalLearningBatch.warmEpisodicStride,
        generation: 5
      ),
      proceduralSkills: makeSnapshotBuffer(
        device: device, section: .proceduralSkills,
        elementCount: 1, elementStride: MetalLearningBatch.proceduralStride,
        generation: 5
      ),
      replayQueue: makeSnapshotBuffer(
        device: device, section: .replayQueue,
        elementCount: 1, elementStride: MetalLearningBatch.replayStride,
        generation: 5
      ),
      counterfactualRollouts: makeSnapshotBuffer(
        device: device, section: .imaginedCounterfactuals,
        elementCount: 1, elementStride: MetalLearningBatch.counterfactualStride,
        generation: 5
      ),
      semanticConcepts: makeSnapshotBuffer(
        device: device, section: .semanticConcepts,
        elementCount: 1, elementStride: MetalLearningBatch.semanticConceptStride,
        generation: 5
      ),
      semanticRelations: makeSnapshotBuffer(
        device: device, section: .semanticRelations,
        elementCount: 1, elementStride: MetalLearningBatch.semanticRelationStride,
        generation: 5
      ),
      regionalTransitions: makeSnapshotBuffer(
        device: device, section: .regionalTransitions,
        elementCount: 1, elementStride: MetalLearningBatch.regionalTransitionStride,
        generation: 5
      ),
      regionalModuleCount: 1,
      speciesTemplateFingerprint: 11,
      regionalProgramFingerprint: 12,
      scheduleFingerprint: 13,
      parameterVersionFingerprint: 77
    )

    try Device.withDefaultDevice(.cpu) {
      let decoded = try MLXCommittedTransitionBatch(source)
      XCTAssertEqual(decoded.validMask.asArray(Float.self), [1, 1])
      XCTAssertEqual(
        decoded.affect.asArray(Float.self),
        [0.2, 0.8, 0.5, 0.1, 0.2, 0.3, 0.4, 0.5,
         0.9, 0.7, 0.6, 0, 0, 0, 0, 0]
      )
      XCTAssertEqual(decoded.affectSourceValidityMask.asArray(UInt32.self), [1 << 4, 0])
      XCTAssertEqual(decoded.affectTimestamp.asArray(UInt64.self), [2_000, 3_000])
      XCTAssertEqual(decoded.factoredReinforcement.shape[1], ABI.Count.factoredReinforcement)
      XCTAssertEqual(decoded.affect.shape[1], ABI.Count.affect)
      XCTAssertEqual(
        decoded.affectLearningEmphasis.asArray(Float.self),
        [0.8, 0],
        "a salient affect value must not emphasize a transition without source evidence"
      )
    }
  }

  private func makeSnapshotBuffer(
    device: any MTLDevice,
    section: MetalLearningBatchSection,
    elementCount: Int,
    elementStride: Int,
    generation: UInt64
  ) throws -> MetalAgentStateRuntime.PersistentSectionSnapshot {
    let byteCount = elementCount * elementStride
    let buffer = try XCTUnwrap(
      device.makeBuffer(length: byteCount, options: [.storageModeShared])
    )
    buffer.label = "Affect learning input fixture \(section.rawValue)"
    buffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: byteCount
    )
    return .init(
      buffer: buffer,
      generation: generation,
      elementCount: elementCount,
      elementStride: elementStride
    )
  }

  private func writeTransition(
    to snapshot: MetalAgentStateRuntime.PersistentSectionSnapshot,
    slot: Int,
    identifier: UInt64,
    sourceGeneration: UInt64,
    parameterFingerprint: UInt64,
    startTimestamp: UInt64,
    endTimestamp: UInt64,
    affect: [Float],
    sourceMask: UInt32
  ) {
    precondition(affect.count == ABI.Count.affect)
    let base = snapshot.buffer.contents().advanced(by: slot * ABI.strideBytes)
    func store<T>(_ value: T, at offset: Int) {
      var littleEndianValue = value
      withUnsafeBytes(of: &littleEndianValue) { bytes in
        base.advanced(by: offset).copyMemory(
          from: bytes.baseAddress!, byteCount: bytes.count
        )
      }
    }
    store(identifier, at: ABI.Offset.identifier)
    store(startTimestamp, at: ABI.Offset.startTimestamp)
    store(endTimestamp, at: ABI.Offset.endTimestamp)
    store(parameterFingerprint, at: ABI.Offset.parameterVersionFingerprint)
    store(sourceGeneration, at: ABI.Offset.sourceGeneration)
    store(ABI.recordVersion, at: ABI.Offset.formatVersion)
    store(ABI.validFlag, at: ABI.Offset.flags)
    store(UInt32(1), at: ABI.Offset.completeActionFlags)
    for (index, value) in affect.enumerated() {
      store(value, at: ABI.Offset.affect + index * MemoryLayout<Float>.stride)
    }
    store(sourceMask, at: ABI.Offset.affectSourceValidityMask)
    store(UInt32(0), at: ABI.Offset.affectReserved)
    store(endTimestamp, at: ABI.Offset.affectTimestamp)
  }
}

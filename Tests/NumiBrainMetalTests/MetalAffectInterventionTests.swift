import Foundation
import Metal
import XCTest

@testable import NumiBrainCore
@testable import NumiBrainMetal

/// Matched-state interventions for affect consumers. These are synthetic
/// Metal control-path checks; they do not qualify behavior on native NumanX.
@available(macOS 26.0, *)
final class MetalAffectInterventionTests: XCTestCase {
  private let environmentIdentifier: UInt32 = 7
  private let episodeIdentifier: UInt64 = 23
  private let physicalCheckpointFingerprint: UInt64 = 0xaffec7

  func testFreshPleasureWinsMatchedWorkspaceAttentionSelection() throws {
    let pair = try runMatchedPair(
      committed: BrainTimestamp(microseconds: 100_000),
      target: BrainTimestamp(microseconds: 101_000),
      damage: 0
    )
    XCTAssertNotEqual(pair.control.workspaceKind, 9)
    XCTAssertEqual(pair.pleasure.workspaceKind, 9)
    XCTAssertEqual(pair.pleasure.workspaceSourceModule, 70)
    XCTAssertEqual(pair.pleasure.workspacePleasure, 1, accuracy: 1.0e-5)
    XCTAssertEqual(pair.pleasure.workspaceSelectionScore, 1, accuracy: 1.0e-5)
  }

  func testSelectedEvidenceAgeControlsMatchedWorkspaceAttentionFreshness() throws {
    let committed = BrainTimestamp(microseconds: 150_000)
    let target = BrainTimestamp(microseconds: 151_000)
    let evidenceTimestamp = BrainTimestamp(microseconds: 20_000)
    let reference = try runMatchedPair(
      committed: committed,
      target: target,
      damage: 0,
      affectTimestamp: evidenceTimestamp
    )
    let extendedEvidenceAge = try runMatchedPair(
      committed: committed,
      target: target,
      damage: 0,
      affectiveModelConfiguration: try AffectiveModelConfiguration(
        maximumEvidenceAgeMicroseconds: 200_000
      ),
      affectTimestamp: evidenceTimestamp
    )

    XCTAssertNotEqual(reference.pleasure.workspaceKind, 9)
    XCTAssertEqual(extendedEvidenceAge.pleasure.workspaceKind, 9)
    XCTAssertEqual(
      extendedEvidenceAge.pleasure.workspaceSelectionScore,
      1,
      accuracy: 1.0e-5
    )
  }

  func testFreshPleasureRaisesMatchedRestorationOptionValue() throws {
    let pair = try runMatchedPair(
      committed: BrainTimestamp(microseconds: 10_000),
      target: BrainTimestamp(microseconds: 60_000),
      damage: 0.5
    )
    XCTAssertGreaterThan(pair.control.restorationPlanIdentifier, 0)
    XCTAssertEqual(
      pair.pleasure.restorationPlanIdentifier,
      pair.control.restorationPlanIdentifier,
      "the same restoration candidate must be compared in both conditions"
    )
    XCTAssertGreaterThan(
      pair.pleasure.restorationPlanObjective,
      pair.control.restorationPlanObjective,
      "pleasure should raise the objective for an option with restorative value"
    )
  }

  func testSelectedPleasureDecayChangesMatchedPlannerAffectModulation() throws {
    let committed = BrainTimestamp(microseconds: 10_000)
    let target = BrainTimestamp(microseconds: 60_000)
    let reference = try runMatchedPair(
      committed: committed,
      target: target,
      damage: 0.5,
      affectiveModelConfiguration: .reference,
      affectTimestamp: BrainTimestamp(microseconds: 2_000)
    )
    let shortDecay = try runMatchedPair(
      committed: committed,
      target: target,
      damage: 0.5,
      affectiveModelConfiguration: try AffectiveModelConfiguration(
        pleasureDecayMicroseconds: 1_000
      ),
      affectTimestamp: BrainTimestamp(microseconds: 2_000)
    )

    XCTAssertEqual(
      reference.control.restorationPlanIdentifier,
      shortDecay.control.restorationPlanIdentifier
    )
    XCTAssertEqual(
      reference.pleasure.restorationPlanIdentifier,
      shortDecay.pleasure.restorationPlanIdentifier
    )
    XCTAssertEqual(
      reference.control.restorationPlanObjective,
      shortDecay.control.restorationPlanObjective,
      accuracy: 1.0e-5,
      "decay configuration should not change the neutral matched control"
    )
    let referencePleasureModulation =
      reference.pleasure.restorationPlanObjective
      - reference.control.restorationPlanObjective
    let shortPleasureModulation =
      shortDecay.pleasure.restorationPlanObjective
      - shortDecay.control.restorationPlanObjective
    XCTAssertGreaterThan(referencePleasureModulation, 0)
    XCTAssertGreaterThan(
      referencePleasureModulation,
      shortPleasureModulation + 1.0e-5,
      "selected pleasure decay should reduce planner affect modulation"
    )
  }

  func testCommittedTransitionPreservesMatchedAffectForTheLearner() throws {
    let device = try requireMetal4Device()
    let typedTemplate = try makeNumanXInteropCompiledTemplate(
      interoceptorCount: 1,
      interoceptionFeatureDimension:
        InteroceptiveFeatureSchema.NumanXFullBodyV1.featureDimension,
      interoceptionFeatureSchemaFingerprint:
        InteroceptiveFeatureSchema.NumanXFullBodyV1.fingerprint,
      workspaceCapacity: 2
    )
    let auditSegmentation = try EpisodicSegmentationDynamics(
      boundaryThreshold: 100,
      sensorySurpriseWeight: 1,
      contextChangeWeight: 0.5,
      goalTransitionWeight: 0.75,
      optionTerminationWeight: 0.75,
      eventSalienceWeight: 1,
      locationTransitionWeight: 0.5,
      surpriseSampleCount: 64
    )
    let committed = BrainTimestamp(microseconds: 10_000)
    let target = BrainTimestamp(microseconds: 11_000)
    let checkpointSource = try makeFixture(
      device: device,
      template: typedTemplate,
      episodicSegmentation: auditSegmentation
    )
    let base = try checkpointSource.runtime.saveCheckpoint(
      environmentIdentifier: environmentIdentifier,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: 0,
      committedTimestamp: committed,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    let affectSection = checkpointSource.runtime.agentStateRuntime.arena.layout
      .section(.affectiveState)
    let affectOffset = affectSection.byteOffset
    let pleasureCheckpoint = try checkpoint(
      copying: base,
      affectOffset: affectOffset,
      withAffect: [0, 0.9, 0],
      sourceMask: 1,
      timestamp: committed
    )
    var normalizedPleasureState = pleasureCheckpoint.hotState
    normalizedPleasureState.replaceSubrange(
      affectSection.byteOffset..<(affectSection.byteOffset + affectSection.elementStride),
      with: base.hotState.subdata(
        in: affectSection.byteOffset..<(affectSection.byteOffset + affectSection.elementStride)
      )
    )
    XCTAssertEqual(
      normalizedPleasureState,
      base.hotState,
      "the learner and memory-journaling pair must differ only in the affect record"
    )

    let control = try makeFixture(
      device: device,
      template: typedTemplate,
      episodicSegmentation: auditSegmentation
    )
    let treated = try makeFixture(
      device: device,
      template: typedTemplate,
      episodicSegmentation: auditSegmentation
    )
    try control.runtime.loadCheckpoint(
      base, physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    try treated.runtime.loadCheckpoint(
      pleasureCheckpoint,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    let controlRecord = try commitAndReadTransition(
      control, committed: committed, target: target
    )
    let pleasureRecord = try commitAndReadTransition(
      treated, committed: committed, target: target
    )

    XCTAssertEqual(controlRecord.affectSourceMask, 0x1f)
    XCTAssertEqual(pleasureRecord.affectSourceMask, 0x1f)
    XCTAssertEqual(controlRecord.affectTimestamp, target.rawValue)
    XCTAssertEqual(pleasureRecord.affectTimestamp, target.rawValue)
    XCTAssertLessThan(controlRecord.affect[1], 0.05)
    XCTAssertGreaterThan(pleasureRecord.affect[1], 0.8)
    XCTAssertEqual(pleasureRecord.memoryAffectSourceMask, 0x1f)
    XCTAssertEqual(pleasureRecord.memoryAffectTimestamp, target.rawValue)
    XCTAssertGreaterThan(pleasureRecord.memoryAffect[1], 0.8)
    XCTAssertEqual(pleasureRecord.memoryEventKind, 12)
    XCTAssertEqual(pleasureRecord.memorySourceIdentifier, 0x1f)
    XCTAssertGreaterThan(
      pleasureRecord.memoryEventSalience,
      controlRecord.memoryEventSalience
    )
    XCTAssertEqual(
      pleasureRecord.factoredReinforcementCount,
      BrainExecutableModelContract.CommittedTransition.Count.factoredReinforcement
    )
  }

  func testAcceptedEpisodeJournalPreservesAffectAcrossWarmArchiveAndRetrieval() throws {
    let device = try requireMetal4Device()
    let typedTemplate = try makeNumanXInteropCompiledTemplate(
      interoceptorCount: 1,
      interoceptionFeatureDimension:
        InteroceptiveFeatureSchema.NumanXFullBodyV1.featureDimension,
      interoceptionFeatureSchemaFingerprint:
        InteroceptiveFeatureSchema.NumanXFullBodyV1.fingerprint,
      workspaceCapacity: 4
    )
    let segmentation = try EpisodicSegmentationDynamics(
      boundaryThreshold: 0.01,
      sensorySurpriseWeight: 1,
      contextChangeWeight: 0.5,
      goalTransitionWeight: 0.75,
      optionTerminationWeight: 0.75,
      eventSalienceWeight: 1,
      locationTransitionWeight: 0.5,
      surpriseSampleCount: 64
    )
    let fixture = try makeFixture(
      device: device,
      template: typedTemplate,
      episodicSegmentation: segmentation
    )
    let committed = BrainTimestamp(microseconds: 10_000)
    let firstTarget = BrainTimestamp(microseconds: 11_000)
    let base = try fixture.runtime.saveCheckpoint(
      environmentIdentifier: environmentIdentifier,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: 0,
      committedTimestamp: committed,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    let memoryLayout = fixture.runtime.agentStateRuntime.arena.memoryLayout
    let active = memoryLayout.section(.activeEpisodes)
    let warm = memoryLayout.section(.compressedEpisodeMetadata)
    let archive = memoryLayout.section(.archiveIndex)
    XCTAssertGreaterThan(active.elementCount, 0)
    XCTAssertGreaterThan(warm.elementCount, 0)
    XCTAssertGreaterThanOrEqual(archive.elementCount, 256)

    let nextGeneration = base.committedGeneration + 1
    let incomingIdentifier = ((episodeIdentifier << 32) ^ 1 ^ nextGeneration
      ^ firstTarget.rawValue) | 1
    let displacedActiveIdentifier = incomingIdentifier
      + UInt64(active.elementCount)
    let displacedWarmIdentifier = displacedActiveIdentifier
      + UInt64(warm.elementCount)
    let activeAffect: [Float] = [0.31, 0.41, 0.51, 0.11, 0.12, 0.13, 0.14, 0.15]
    let warmAffect: [Float] = [0.61, 0.21, 0.71, 0.51, 0.22, 0.53, 0.24, 0.55]
    var persistentMemory = base.persistentMemory
    writeEpisode(
      to: &persistentMemory,
      sectionOffset: active.byteOffset,
      stride: active.elementStride,
      slot: Int(displacedActiveIdentifier % UInt64(active.elementCount)),
      identifier: displacedActiveIdentifier,
      sourceGeneration: nextGeneration,
      startTimestamp: 9_000,
      endTimestamp: 10_000,
      affect: activeAffect,
      sourceMask: 0x15,
      affectTimestamp: 9_500
    )
    writeEpisode(
      to: &persistentMemory,
      sectionOffset: warm.byteOffset,
      stride: warm.elementStride,
      slot: Int(displacedActiveIdentifier % UInt64(warm.elementCount)),
      identifier: displacedWarmIdentifier,
      sourceGeneration: nextGeneration,
      startTimestamp: 7_000,
      endTimestamp: 8_000,
      affect: warmAffect,
      sourceMask: 0x2a,
      affectTimestamp: 7_500
    )
    let affectOffset = fixture.runtime.agentStateRuntime.arena.layout
      .section(.affectiveState).byteOffset
    let withCurrentAffect = try checkpoint(
      copying: base,
      affectOffset: affectOffset,
      withAffect: [0.05, 0.9, 0.4, 0.11, 0.22, 0.33, 0.44, 0.55],
      sourceMask: 0x2f,
      timestamp: committed
    )
    let seeded = try checkpoint(
      copying: withCurrentAffect,
      persistentMemory: persistentMemory
    )
    try fixture.runtime.loadCheckpoint(
      seeded, physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )

    let first = try commitAndReadTransition(
      fixture,
      committed: committed,
      target: firstTarget,
      controlStepIdentifier: 1
    )
    let currentEpisode = try XCTUnwrap(readEpisode(
      first.checkpoint.persistentMemory,
      sectionOffset: active.byteOffset,
      stride: active.elementStride,
      count: active.elementCount,
      identifier: incomingIdentifier,
      formatVersionOffset: 56
    ))
    XCTAssertEqual(currentEpisode.affectTimestamp, firstTarget.rawValue)
    XCTAssertNotEqual(currentEpisode.sourceMask, 0)
    XCTAssertEqual(currentEpisode.affect, affectFloats(
      first.checkpoint.hotState, at: affectOffset
    ), "the journal must capture the accepted root's complete eight-float snapshot")
    let warmedEpisode = try XCTUnwrap(readEpisode(
      first.checkpoint.persistentMemory,
      sectionOffset: warm.byteOffset,
      stride: warm.elementStride,
      count: warm.elementCount,
      identifier: displacedActiveIdentifier,
      formatVersionOffset: 56
    ))
    XCTAssertEqual(warmedEpisode.affect, activeAffect)
    XCTAssertEqual(warmedEpisode.sourceMask, 0x15)
    XCTAssertEqual(warmedEpisode.affectTimestamp, 9_500)
    let archived = try XCTUnwrap(readEpisode(
      first.checkpoint.persistentMemory,
      sectionOffset: archive.byteOffset,
      stride: archive.elementStride,
      count: archive.elementCount,
      identifier: displacedWarmIdentifier,
      formatVersionOffset: 64
    ))
    XCTAssertEqual(archived.affect, warmAffect)
    XCTAssertEqual(archived.sourceMask, 0x2a)
    XCTAssertEqual(archived.affectTimestamp, 7_500)

    // Leave only the archive source visible to the next real memory retrieval.
    // Duplicating the exact record in each cluster's first slot makes it
    // addressable by either deterministic query cluster in this fixture.
    var archiveOnlyMemory = first.checkpoint.persistentMemory
    archiveOnlyMemory.replaceSubrange(
      active.byteOffset..<(active.byteOffset + active.byteCount),
      with: Data(repeating: 0, count: active.byteCount)
    )
    archiveOnlyMemory.replaceSubrange(
      warm.byteOffset..<(warm.byteOffset + warm.byteCount),
      with: Data(repeating: 0, count: warm.byteCount)
    )
    let archiveSourceOffset = archive.byteOffset + archived.slot * archive.elementStride
    let archivedBytes = archiveOnlyMemory.subdata(
      in: archiveSourceOffset..<(archiveSourceOffset + archive.elementStride)
    )
    for cluster in 0..<256 {
      let destination = archive.byteOffset + cluster * archive.elementStride
      archiveOnlyMemory.replaceSubrange(
        destination..<(destination + archive.elementStride),
        with: archivedBytes
      )
      store(UInt32(cluster), in: &archiveOnlyMemory, at: destination + 80)
    }
    let archiveOnly = try checkpoint(
      copying: first.checkpoint,
      persistentMemory: archiveOnlyMemory
    )
    let activeControlLayout = try MetalActiveControlLayout(
      arenaLayout: fixture.runtime.agentStateRuntime.arena.layout,
      species: fixture.compiled.species
    )
    let retrievalAction = activeControlLayout.section(.internalActions)
    var retrievalHotState = archiveOnly.hotState
    let retrievalActionOffset = retrievalAction.byteOffset
    store(displacedWarmIdentifier, in: &retrievalHotState, at: retrievalActionOffset)
    store(firstTarget.rawValue, in: &retrievalHotState, at: retrievalActionOffset + 8)
    store(UInt32(InternalActionKind.retrieveMemory.rawValue),
      in: &retrievalHotState, at: retrievalActionOffset + 16)
    store(UInt32(1), in: &retrievalHotState, at: retrievalActionOffset + 20)
    store(UInt32(6), in: &retrievalHotState, at: retrievalActionOffset + 24)
    store(UInt32(0), in: &retrievalHotState, at: retrievalActionOffset + 28)
    store(Float(1), in: &retrievalHotState, at: retrievalActionOffset + 32)
    store(Float(1), in: &retrievalHotState, at: retrievalActionOffset + 36)
    // Persistent-memory retrieval is developmental-stage gated. This fixture
    // starts from an otherwise valid stage-0 accepted root, so seed the
    // episodic-memory-capable stage before the second retrieval root.
    let developmentalStateOffset = fixture.runtime.agentStateRuntime.arena.layout
      .section(.developmentalState).byteOffset
    store(UInt32(DevelopmentalStage.episodicAndProceduralMemory.rawValue),
      in: &retrievalHotState, at: developmentalStateOffset + 4)
    let retrievalCheckpoint = try checkpoint(
      copying: archiveOnly,
      hotState: retrievalHotState,
      persistentMemory: archiveOnlyMemory
    )
    try fixture.runtime.loadCheckpoint(
      retrievalCheckpoint, physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    let firstArchivePage = try fixture.runtime.agentStateRuntime.snapshotArchivePages([0])
    try fixture.runtime.agentStateRuntime.loadArchivePages(firstArchivePage)

    let second = try commitAndReadTransition(
      fixture,
      committed: firstTarget,
      target: BrainTimestamp(microseconds: 12_000),
      controlStepIdentifier: 2
    )
    let workspaceMetadata = fixture.runtime.agentStateRuntime.arena.layout
      .section(.workspaceMetadata)
    let workspaceContent = fixture.runtime.agentStateRuntime.arena.layout
      .section(.workspaceContent)
    let workspaceDimension = workspaceContent.elementCount
      / workspaceMetadata.elementCount
    XCTAssertGreaterThanOrEqual(workspaceDimension, 22)
    let publishedSlot = try XCTUnwrap((0..<workspaceMetadata.elementCount).first { slot in
      readUInt64(
        second.checkpoint.hotState,
        at: workspaceMetadata.byteOffset + slot * workspaceMetadata.elementStride + 48
      ) == displacedWarmIdentifier
    })
    let publishedMetadataOffset = workspaceMetadata.byteOffset
      + publishedSlot * workspaceMetadata.elementStride
    XCTAssertEqual(
      readUInt32(second.checkpoint.hotState, at: publishedMetadataOffset + 96),
      0x2a
    )
    XCTAssertEqual(
      readUInt64(second.checkpoint.hotState, at: publishedMetadataOffset + 104),
      7_500
    )
    let publishedAffect = (0..<8).map { index in
      readFloat(
        second.checkpoint.hotState,
        at: workspaceContent.byteOffset
          + (publishedSlot * workspaceDimension + 14 + index) * MemoryLayout<Float>.stride
      )
    }
    XCTAssertEqual(publishedAffect, warmAffect)
  }

  private func runMatchedPair(
    committed: BrainTimestamp,
    target: BrainTimestamp,
    damage: Float,
    affectiveModelConfiguration: AffectiveModelConfiguration = .reference,
    affectTimestamp: BrainTimestamp? = nil
  ) throws -> (control: DecisionObservation, pleasure: DecisionObservation) {
    let device = try requireMetal4Device()
    let typedTemplate = try makeNumanXInteropCompiledTemplate(
      interoceptorCount: 1,
      interoceptionFeatureDimension:
        InteroceptiveFeatureSchema.NumanXFullBodyV1.featureDimension,
      interoceptionFeatureSchemaFingerprint:
        InteroceptiveFeatureSchema.NumanXFullBodyV1.fingerprint,
      workspaceCapacity: 2
    )
    let checkpointSource = try makeFixture(
      device: device,
      template: typedTemplate,
      affectiveModelConfiguration: affectiveModelConfiguration
    )
    let base = try checkpointSource.runtime.saveCheckpoint(
      environmentIdentifier: environmentIdentifier,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: 0,
      committedTimestamp: committed,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    let affectOffset = checkpointSource.runtime.agentStateRuntime.arena.layout
      .section(.affectiveState).byteOffset
    let pleasureCheckpoint = try checkpoint(
      copying: base,
      affectOffset: affectOffset,
      withAffect: [0, 1, 0],
      sourceMask: 1,
      timestamp: affectTimestamp ?? committed
    )
    var normalizedPleasureState = pleasureCheckpoint.hotState
    let affectSection = checkpointSource.runtime.agentStateRuntime.arena.layout
      .section(.affectiveState)
    normalizedPleasureState.replaceSubrange(
      affectSection.byteOffset..<(affectSection.byteOffset + affectSection.elementStride),
      with: base.hotState.subdata(
        in: affectSection.byteOffset..<(affectSection.byteOffset + affectSection.elementStride)
      )
    )
    XCTAssertEqual(
      normalizedPleasureState,
      base.hotState,
      "the intervention pair must differ only in the affect record"
    )

    let control = try makeFixture(
      device: device,
      template: typedTemplate,
      affectiveModelConfiguration: affectiveModelConfiguration
    )
    let treated = try makeFixture(
      device: device,
      template: typedTemplate,
      affectiveModelConfiguration: affectiveModelConfiguration
    )
    try control.runtime.loadCheckpoint(
      base, physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    try treated.runtime.loadCheckpoint(
      pleasureCheckpoint,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )

    return (
      try runDecision(control, committed: committed, target: target, damage: damage),
      try runDecision(treated, committed: committed, target: target, damage: damage)
    )
  }

  private struct DecisionObservation {
    let workspaceKind: UInt32
    let workspaceSourceModule: UInt32
    let workspacePleasure: Float
    let workspaceSelectionScore: Float
    let restorationPlanIdentifier: UInt64
    let restorationPlanObjective: Float
  }

  private struct CommittedAffectObservation {
    let affect: [Float]
    let affectSourceMask: UInt32
    let affectTimestamp: UInt64
    let factoredReinforcementCount: Int
    let memoryAffect: [Float]
    let memoryAffectSourceMask: UInt16
    let memoryAffectTimestamp: UInt64
    let memoryEventKind: UInt32
    let memorySourceIdentifier: UInt32
    let memoryEventSalience: Float
    let checkpoint: MetalBrainCheckpoint
  }

  private struct EpisodeObservation {
    let slot: Int
    let affect: [Float]
    let sourceMask: UInt32
    let affectTimestamp: UInt64
  }

  private struct Fixture {
    let device: any MTLDevice
    let compiled: CompiledSpeciesTemplate
    let runtime: MetalEmbodiedBrainRuntime
    let recurrentBuffer: any MTLBuffer
    let recurrentView: MetalRegionalRecurrentBufferView
  }

  private func makeFixture(
    device: any MTLDevice,
    template: CompiledSpeciesTemplate,
    affectiveModelConfiguration: AffectiveModelConfiguration = .reference,
    episodicSegmentation: EpisodicSegmentationDynamics? = nil
  ) throws -> Fixture {
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
      episodicSegmentation: episodicSegmentation,
      affectiveModelConfiguration: affectiveModelConfiguration
    )
    let recurrentBuffer = try XCTUnwrap(
      device.makeBuffer(
        length: regionalProgram.scalarCount * MemoryLayout<Float>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    )
    recurrentBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: recurrentBuffer.length
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
      recurrentBuffer: recurrentBuffer,
      recurrentView: recurrentView
    )
  }

  private func runDecision(
    _ fixture: Fixture,
    committed: BrainTimestamp,
    target: BrainTimestamp,
    damage: Float
  ) throws -> DecisionObservation {
    let token = try BrainJointTransactionToken(
      environmentIdentifier: environmentIdentifier,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: 1,
      parameterVersionFingerprint:
        fixture.runtime.parameterVersionFingerprint,
      baseBrainGeneration:
        fixture.runtime.agentStateRuntime.arena.committedGeneration,
      basePhysicsGeneration: 100,
      committedTimestamp: committed,
      targetTimestamp: target,
      randomCounterGeneration: 0
    )
    let transaction = try fixture.runtime.beginControl(
      jointToken: token,
      cachedDecisionFingerprint: 0xa77e_0001
    )
    defer { try? fixture.runtime.abort(transaction: transaction) }
    _ = try fixture.runtime.inferAndDecide(
      transaction: transaction,
      numanXSensors: makeSensors(fixture, token: token, damage: damage),
      regionalRecurrentInput: fixture.recurrentView
    )

    let buffer = try fixture.runtime.agentStateRuntime.arena
      .borrowShadowHotBuffer(transaction: transaction.agentStateToken)
    let bytes = try snapshot(buffer: buffer, device: fixture.device)
    let hotLayout = fixture.runtime.agentStateRuntime.arena.layout
    let workspaceContent = hotLayout.section(.workspaceContent)
    let workspaceMetadata = hotLayout.section(.workspaceMetadata)
    let activeControl = try MetalActiveControlLayout(
      arenaLayout: hotLayout,
      species: fixture.compiled.species
    )
    let plans = activeControl.section(.planSteps)
    let restorationPlanOffset = plans.byteOffset + 3 * plans.elementStride

    return DecisionObservation(
      workspaceKind: readUInt32(bytes, at: workspaceMetadata.byteOffset + 56) & 0xffff,
      workspaceSourceModule: readUInt32(bytes, at: workspaceMetadata.byteOffset + 56) >> 16,
      workspacePleasure: readFloat(bytes, at: workspaceContent.byteOffset + MemoryLayout<Float>.stride),
      workspaceSelectionScore: readFloat(bytes, at: workspaceMetadata.byteOffset + 68),
      restorationPlanIdentifier: readUInt64(bytes, at: restorationPlanOffset),
      restorationPlanObjective: readFloat(bytes, at: restorationPlanOffset + 16)
    )
  }

  private func makeSensors(
    _ fixture: Fixture,
    token: BrainJointTransactionToken,
    damage: Float,
    acceptedPhysicsState: AcceptedPhysicsStateToken? = nil,
    interoceptionValues: [Float]? = nil
  ) throws -> NumanXSensorPacketLease {
    let deliveryTimestamp = acceptedPhysicsState?.acceptedTimestamp
      ?? token.committedTimestamp
    let rawSensors = try fixture.compiled.species.senses.filter(\.enabled)
      .map { topology in
        let scalarCount = Int(topology.receptorCount)
          * Int(topology.observationDimension)
        let buffer = try XCTUnwrap(
          fixture.device.makeBuffer(
            length: scalarCount * MemoryLayout<Float>.stride,
            options: [.storageModeShared, .hazardTrackingModeTracked]
          )
        )
        let scalars = buffer.contents().assumingMemoryBound(to: Float.self)
        scalars.initialize(repeating: 0, count: scalarCount)
        if topology.modality == .interoception {
          let physiology = interoceptionValues ?? [Float(1), 1, 0, 0, 0, damage]
          for receptor in 0..<Int(topology.receptorCount) {
            for feature in 0..<Int(topology.observationDimension) {
              scalars[receptor * Int(topology.observationDimension) + feature]
                = physiology[feature]
            }
          }
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

  private func commitAndReadTransition(
    _ fixture: Fixture,
    committed: BrainTimestamp,
    target: BrainTimestamp,
    controlStepIdentifier: UInt64 = 1
  ) throws -> CommittedAffectObservation {
    let token = try BrainJointTransactionToken(
      environmentIdentifier: environmentIdentifier,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: controlStepIdentifier,
      parameterVersionFingerprint: fixture.runtime.parameterVersionFingerprint,
      baseBrainGeneration: fixture.runtime.agentStateRuntime.arena.committedGeneration,
      basePhysicsGeneration: 100,
      committedTimestamp: committed,
      targetTimestamp: target,
      randomCounterGeneration: 0
    )
    let transaction = try fixture.runtime.beginControl(
      jointToken: token,
      cachedDecisionFingerprint: 0xa77e_0011
    )
    defer {
      if transaction.status != .committed {
        try? fixture.runtime.abort(transaction: transaction)
      }
    }
    _ = try fixture.runtime.inferAndDecide(
      transaction: transaction,
      numanXSensors: makeSensors(
        fixture, token: token, damage: 0,
        interoceptionValues: [1, 1, 0, 0, 0, 0]
      ),
      regionalRecurrentInput: fixture.recurrentView
    )

    var physicalLedger = BrainJointTransaction(token: token)
    let substep = try physicalLedger.beginPhysicsSubstep(
      durationMicroseconds: target.rawValue - committed.rawValue
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: token,
      substep: substep,
      physicsStateFingerprint: 0xa77e_1011,
      physicsGeneration: token.basePhysicsGeneration + 1
    )
    try physicalLedger.acceptPhysicsSubstep(accepted, for: substep)
    let acceptedSensors = try makeSensors(
      fixture,
      token: token,
      damage: 0,
      acceptedPhysicsState: accepted,
      interoceptionValues: [1, 1, 0, 0, 0, 0]
    )
    let gateBuffer = try XCTUnwrap(
      fixture.device.makeBuffer(
        length: MetalAcceptedPhysicsGateLease.byteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    )
    gateBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: gateBuffer.length
    )
    var acceptedABI = accepted.abiRecord
    withUnsafeBytes(of: &acceptedABI) { bytes in
      gateBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
    let gate = try MetalAcceptedPhysicsGateLease(buffer: gateBuffer)
    let event = try XCTUnwrap(fixture.device.makeSharedEvent())
    let ticket = try fixture.runtime.submitAcceptedConsequence(
      transaction: transaction,
      acceptedPhysicsState: accepted,
      candidateSubstep: substep,
      acceptedPhysicsGate: gate,
      numanXSensors: acceptedSensors,
      acceptedRegionalRecurrentInput: fixture.recurrentView,
      signal: try MetalSharedEventPoint(event: event, value: 1)
    )
    XCTAssertTrue(event.wait(untilSignaledValue: 1, timeoutMS: 10_000))
    _ = try fixture.runtime.finishAcceptedConsequenceSubmission(
      ticket,
      transaction: transaction,
      acceptedPhysicsState: accepted,
      timeoutMilliseconds: 10_000
    )
    try fixture.runtime.commit(transaction: transaction, receipt: physicalLedger.commit())

    let checkpoint = try fixture.runtime.saveCheckpoint(
      environmentIdentifier: environmentIdentifier,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: token.controlStepIdentifier,
      committedTimestamp: target,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    let accumulatorSection = fixture.runtime.agentStateRuntime.arena.layout
      .section(.activeEpisodeAccumulator)
    let accumulatorOffset = accumulatorSection.byteOffset
    let affectStateOffset = fixture.runtime.agentStateRuntime.arena.layout
      .section(.affectiveState).byteOffset

    let learningBatch = try fixture.runtime.makeLearningBatch()
    let transitionLease = try learningBatch.makeSharedStorageLease(
      for: .committedTransitions
    )
    let bytes = UnsafeRawPointer(transitionLease.baseAddress)
    let capacity = learningBatch.transitionCapacity
    let stride = learningBatch.transitionStride
    let abi = BrainExecutableModelContract.CommittedTransition.self
    func u64(_ slot: Int, _ field: Int) -> UInt64 {
      UInt64(littleEndian: bytes.loadUnaligned(
        fromByteOffset: slot * stride + field, as: UInt64.self
      ))
    }
    func u32(_ slot: Int, _ field: Int) -> UInt32 {
      UInt32(littleEndian: bytes.loadUnaligned(
        fromByteOffset: slot * stride + field, as: UInt32.self
      ))
    }
    func f32(_ slot: Int, _ field: Int) -> Float {
      bytes.loadUnaligned(fromByteOffset: slot * stride + field, as: Float.self)
    }
    let recordIndex = try XCTUnwrap((0..<capacity).first { slot in
      u64(slot, abi.Offset.identifier) > 0
        && u32(slot, abi.Offset.formatVersion) == abi.recordVersion
        && (u32(slot, abi.Offset.flags) & abi.validFlag) != 0
        && u64(slot, abi.Offset.endTimestamp) == target.rawValue
    })
    let memoryBytes = checkpoint.hotState
    return CommittedAffectObservation(
      affect: (0..<abi.Count.affect).map {
        f32(recordIndex, abi.Offset.affect + $0 * MemoryLayout<Float>.stride)
      },
      affectSourceMask: u32(recordIndex, abi.Offset.affectSourceValidityMask),
      affectTimestamp: u64(recordIndex, abi.Offset.affectTimestamp),
      factoredReinforcementCount: abi.Count.factoredReinforcement,
      memoryAffect: (0..<3).map { index in
        readFloat(
          checkpoint.hotState,
          at: affectStateOffset + index * MemoryLayout<Float>.stride
        )
      },
      memoryAffectSourceMask: checkpoint.hotState.withUnsafeBytes {
        $0.loadUnaligned(fromByteOffset: affectStateOffset + 36, as: UInt16.self)
      },
      memoryAffectTimestamp: readUInt64(
        checkpoint.hotState, at: affectStateOffset + 40
      ),
      memoryEventKind: readUInt32(
        memoryBytes, at: accumulatorOffset + 80
      ),
      memorySourceIdentifier: readUInt32(
        memoryBytes, at: accumulatorOffset + 84
      ),
      memoryEventSalience: readFloat(
        memoryBytes, at: accumulatorOffset + 128
      ),
      checkpoint: checkpoint
    )
  }

  private func checkpoint(
    copying source: MetalBrainCheckpoint,
    affectOffset: Int,
    withAffect values: [Float],
    sourceMask: UInt16,
    timestamp: BrainTimestamp
  ) throws -> MetalBrainCheckpoint {
    precondition(values.count == 3 || values.count == 8)
    var hotState = source.hotState
    hotState.withUnsafeMutableBytes { bytes in
      for (index, value) in values.enumerated() {
        guard index < 3 else { continue }
        bytes.storeBytes(
          of: value,
          toByteOffset: affectOffset + index * MemoryLayout<Float>.stride,
          as: Float.self
        )
      }
      if values.count == 8 {
        for index in 0..<5 {
          bytes.storeBytes(
            of: values[index + 3],
            toByteOffset: affectOffset + 16 + index * MemoryLayout<Float>.stride,
            as: Float.self
          )
        }
      }
      bytes.storeBytes(
        of: sourceMask,
        toByteOffset: affectOffset + 36,
        as: UInt16.self
      )
      bytes.storeBytes(
        of: timestamp.rawValue,
        toByteOffset: affectOffset + 40,
        as: UInt64.self
      )
    }
    return try MetalBrainCheckpoint(
      committedGeneration: source.committedGeneration,
      committedTimestamp: source.committedTimestamp,
      environmentIdentifier: source.environmentIdentifier,
      episodeIdentifier: source.episodeIdentifier,
      controlStepIdentifier: source.controlStepIdentifier,
      speciesTemplateFingerprint: source.speciesTemplateFingerprint,
      compiledSpeciesTemplateFingerprint: source.compiledSpeciesTemplateFingerprint,
      regionalProgramFingerprint: source.regionalProgramFingerprint,
      scheduleFingerprint: source.scheduleFingerprint,
      parameterVersionFingerprint: source.parameterVersionFingerprint,
      hotLayoutFingerprint: source.hotLayoutFingerprint,
      memoryLayoutFingerprint: source.memoryLayoutFingerprint,
      physicalCheckpointFingerprint: source.physicalCheckpointFingerprint,
      hotState: hotState,
      persistentMemory: source.persistentMemory,
      connectomeState: source.connectomeState,
      muscleLocomotorFingerprint: source.muscleLocomotorFingerprint
    )
  }

  private func checkpoint(
    copying source: MetalBrainCheckpoint,
    hotState: Data? = nil,
    persistentMemory: Data
  ) throws -> MetalBrainCheckpoint {
    try MetalBrainCheckpoint(
      committedGeneration: source.committedGeneration,
      committedTimestamp: source.committedTimestamp,
      environmentIdentifier: source.environmentIdentifier,
      episodeIdentifier: source.episodeIdentifier,
      controlStepIdentifier: source.controlStepIdentifier,
      speciesTemplateFingerprint: source.speciesTemplateFingerprint,
      compiledSpeciesTemplateFingerprint: source.compiledSpeciesTemplateFingerprint,
      regionalProgramFingerprint: source.regionalProgramFingerprint,
      scheduleFingerprint: source.scheduleFingerprint,
      parameterVersionFingerprint: source.parameterVersionFingerprint,
      hotLayoutFingerprint: source.hotLayoutFingerprint,
      memoryLayoutFingerprint: source.memoryLayoutFingerprint,
      physicalCheckpointFingerprint: source.physicalCheckpointFingerprint,
      hotState: hotState ?? source.hotState,
      persistentMemory: persistentMemory,
      connectomeState: source.connectomeState,
      muscleLocomotorFingerprint: source.muscleLocomotorFingerprint
    )
  }

  private func writeEpisode(
    to data: inout Data,
    sectionOffset: Int,
    stride: Int,
    slot: Int,
    identifier: UInt64,
    sourceGeneration: UInt64,
    startTimestamp: UInt64,
    endTimestamp: UInt64,
    affect: [Float],
    sourceMask: UInt32,
    affectTimestamp: UInt64
  ) {
    precondition(affect.count == 8 && slot >= 0)
    let base = sectionOffset + slot * stride
    store(identifier, in: &data, at: base)
    store(startTimestamp, in: &data, at: base + 8)
    store(endTimestamp, in: &data, at: base + 16)
    store(UInt64(1), in: &data, at: base + 24)
    store(sourceGeneration, in: &data, at: base + 32)
    store(UInt64(5), in: &data, at: base + 40)
    store(UInt64(7), in: &data, at: base + 48)
    store(MetalLearningBatch.episodicRecordVersion, in: &data, at: base + 56)
    store(UInt32(12), in: &data, at: base + 60)
    store(sourceMask, in: &data, at: base + 64)
    store(UInt32(1), in: &data, at: base + 68)
    store(Float(0.8), in: &data, at: base + 72)
    store(Float(0.1), in: &data, at: base + 76)
    store(Float(0.05), in: &data, at: base + 80)
    store(Float(0.25), in: &data, at: base + 84)
    for index in 0..<10 {
      store(Float(index.isMultiple(of: 2) ? 0.2 : -0.2), in: &data, at: base + 88 + index * 4)
    }
    for (index, value) in affect.enumerated() {
      store(value, in: &data, at: base + 128 + index * 4)
    }
    store(sourceMask, in: &data, at: base + 160)
    store(UInt32(0), in: &data, at: base + 164)
    store(affectTimestamp, in: &data, at: base + 168)
  }

  private func readEpisode(
    _ data: Data,
    sectionOffset: Int,
    stride: Int,
    count: Int,
    identifier: UInt64,
    formatVersionOffset: Int
  ) -> EpisodeObservation? {
    for slot in 0..<count {
      let base = sectionOffset + slot * stride
      guard readUInt64(data, at: base) == identifier,
        readUInt32(data, at: base + formatVersionOffset)
          == MetalLearningBatch.episodicRecordVersion
      else { continue }
      return EpisodeObservation(
        slot: slot,
        affect: (0..<8).map { readFloat(data, at: base + 128 + $0 * 4) },
        sourceMask: readUInt32(data, at: base + 160),
        affectTimestamp: readUInt64(data, at: base + 168)
      )
    }
    return nil
  }

  private func affectFloats(_ data: Data, at offset: Int) -> [Float] {
    (0..<8).map { readFloat(data, at: offset + $0 * 4) }
  }

  private func store<T>(_ value: T, in data: inout Data, at offset: Int) {
    var value = value
    withUnsafeBytes(of: &value) { source in
      data.withUnsafeMutableBytes { destination in
        destination.baseAddress!.advanced(by: offset).copyMemory(
          from: source.baseAddress!, byteCount: source.count
        )
      }
    }
  }

  private func readFloat(_ bytes: Data, at offset: Int) -> Float {
    bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Float.self) }
  }

  private func snapshot(buffer: any MTLBuffer, device: any MTLDevice) throws -> Data {
    guard let queue = device.makeCommandQueue(),
      let staging = device.makeBuffer(
        length: buffer.length,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let commandBuffer = queue.makeCommandBuffer(),
      let blit = commandBuffer.makeBlitCommandEncoder()
    else {
      throw TissueError.metal("failed to allocate affect test snapshot copy")
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

  private func readUInt32(_ bytes: Data, at offset: Int) -> UInt32 {
    bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
  }

  private func readUInt64(_ bytes: Data, at offset: Int) -> UInt64 {
    bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self) }
  }

  private func requireMetal4Device() throws -> any MTLDevice {
    guard let device = MTLCreateSystemDefaultDevice(),
      device.makeMTL4CommandQueue() != nil,
      device.makeCommandAllocator() != nil,
      device.makeCommandBuffer() != nil
    else { throw XCTSkip("Metal 4 execution is unavailable") }
    return device
  }
}

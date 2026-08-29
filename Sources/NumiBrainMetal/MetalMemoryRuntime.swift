import Foundation
@preconcurrency import Metal
import NumiBrainCore

private struct MemoryUniforms {
  var targetTimestampMicroseconds: UInt64 = 0
  var baseGeneration: UInt64 = 0
  var shadowGeneration: UInt64 = 0
  var parameterVersionFingerprint: UInt64 = 0
  var episodeIdentifier: UInt64 = 0
  var controlStepIdentifier: UInt64 = 0
  var recurrentOffset: UInt64 = 0
  var eventQueueOffset: UInt64 = 0
  var workspaceContentOffset: UInt64 = 0
  var controlHeaderOffset: UInt64 = 0
  var activeEpisodeAccumulatorOffset: UInt64 = 0
  var activeEpisodeMemoryOffset: UInt64 = 0
  var compressedEpisodeMemoryOffset: UInt64 = 0
  var archiveEpisodeMemoryOffset: UInt64 = 0
  var replayMemoryOffset: UInt64 = 0
  var archivePageEpochOffset: UInt64 = 0
  var journalByteCount: UInt64 = 0
  var persistentMemoryByteCount: UInt64 = 0
  var recurrentScalarCount: UInt32 = 0
  var workspaceScalarCount: UInt32 = 0
  var activeEpisodeCapacity: UInt32 = 0
  var activeEpisodeStride: UInt32 = 0
  var compressedEpisodeCapacity: UInt32 = 0
  var compressedEpisodeStride: UInt32 = 0
  var archiveEpisodeCapacity: UInt32 = 0
  var archiveEpisodeStride: UInt32 = 0
  var replayCapacity: UInt32 = 0
  var replayStride: UInt32 = 0
  var archiveRecordsPerPage: UInt32 = 0
  var archivePageCount: UInt32 = 0
  var journalEntryCapacity: UInt32 = 0
  var surpriseSampleCount: UInt32 = 0
  var boundaryThreshold: Float = 0
  var eventSalienceWeight: Float = 0
}

private struct MemoryRetrievalUniforms {
  var targetTimestampMicroseconds: UInt64 = 0
  var shadowGeneration: UInt64 = 0
  var recurrentOffset: UInt64 = 0
  var workspaceContentOffset: UInt64 = 0
  var workspaceMetadataOffset: UInt64 = 0
  var retrievalScratchOffset: UInt64 = 0
  var activeEpisodeMemoryOffset: UInt64 = 0
  var compressedEpisodeMemoryOffset: UInt64 = 0
  var archiveEpisodeMemoryOffset: UInt64 = 0
  var semanticMemoryOffset: UInt64 = 0
  var semanticRelationMemoryOffset: UInt64 = 0
  var proceduralMemoryOffset: UInt64 = 0
  var prospectiveMemoryOffset: UInt64 = 0
  var controlHeaderOffset: UInt64 = 0
  var internalActionOffset: UInt64 = 0
  var developmentalStateOffset: UInt64 = 0
  var archivePageResidencyOffset: UInt64 = 0
  var archivePageRequestOffset: UInt64 = 0
  var parameterVersionFingerprint: UInt64 = 0
  var recurrentScalarCount: UInt32 = 0
  var workspaceCapacity: UInt32 = 0
  var workspaceDimension: UInt32 = 0
  var activeEpisodeCapacity: UInt32 = 0
  var activeEpisodeStride: UInt32 = 0
  var compressedEpisodeCapacity: UInt32 = 0
  var compressedEpisodeStride: UInt32 = 0
  var archiveEpisodeCapacity: UInt32 = 0
  var archiveEpisodeStride: UInt32 = 0
  var archiveSearchCandidateCount: UInt32 = 0
  var archiveRecordsPerPage: UInt32 = 0
  var archivePageCount: UInt32 = 0
  var archivePageRequestCapacity: UInt32 = 0
  var semanticCapacity: UInt32 = 0
  var semanticStride: UInt32 = 0
  var semanticRelationCapacity: UInt32 = 0
  var semanticRelationStride: UInt32 = 0
  var proceduralCapacity: UInt32 = 0
  var proceduralStride: UInt32 = 0
  var prospectiveCapacity: UInt32 = 0
  var prospectiveStride: UInt32 = 0
  var candidateCount: UInt32 = 0
  var retrievalPass: UInt32 = 0
  var maximumResults: UInt32 = 0
  var minimumScore: Float = 0
  var episodicWeight: Float = 0
  var semanticWeight: Float = 0
  var proceduralWeight: Float = 0
  var prospectiveWeight: Float = 0
}

private struct MemoryConsolidationUniforms {
  var targetTimestampMicroseconds: UInt64 = 0
  var baseGeneration: UInt64 = 0
  var shadowGeneration: UInt64 = 0
  var controlHeaderOffset: UInt64 = 0
  var internalActionOffset: UInt64 = 0
  var developmentalStateOffset: UInt64 = 0
  var driveOffset: UInt64 = 0
  var activeEpisodeMemoryOffset: UInt64 = 0
  var compressedEpisodeMemoryOffset: UInt64 = 0
  var semanticMemoryOffset: UInt64 = 0
  var semanticRelationMemoryOffset: UInt64 = 0
  var proceduralMemoryOffset: UInt64 = 0
  var replayMemoryOffset: UInt64 = 0
  var proceduralTraceOffset: UInt64 = 0
  var persistentMemoryByteCount: UInt64 = 0
  var journalByteCount: UInt64 = 0
  var activeEpisodeCapacity: UInt32 = 0
  var activeEpisodeStride: UInt32 = 0
  var compressedEpisodeCapacity: UInt32 = 0
  var compressedEpisodeStride: UInt32 = 0
  var semanticCapacity: UInt32 = 0
  var semanticStride: UInt32 = 0
  var semanticRelationCapacity: UInt32 = 0
  var semanticRelationStride: UInt32 = 0
  var proceduralCapacity: UInt32 = 0
  var proceduralStride: UInt32 = 0
  var replayCapacity: UInt32 = 0
  var replayStride: UInt32 = 0
  var proceduralTraceCapacity: UInt32 = 0
  var proceduralTraceStride: UInt32 = 0
  var journalEntryCapacity: UInt32 = 0
  var minimumProceduralEpisodes: UInt32 = 0
  var flags: UInt32 = 0
  var reserved: UInt32 = 0
  var maximumDamage: Float = 0
  var minimumSalience: Float = 0
  var proceduralLearningRate: Float = 0
  var semanticLearningRate: Float = 0
  var freezeCompetence: Float = 0
  var freezeMaximumDamage: Float = 0
  var freezeMaximumUncertainty: Float = 0
  var retireCompetence: Float = 0
  var retireMinimumDamage: Float = 0
  var degradationMargin: Float = 0
  var mergeSimilarity: Float = 0
}

private struct MemoryReconsolidationUniforms {
  var targetTimestampMicroseconds: UInt64 = 0
  var baseGeneration: UInt64 = 0
  var shadowGeneration: UInt64 = 0
  var recurrentOffset: UInt64 = 0
  var observationOffset: UInt64 = 0
  var retrievalScratchOffset: UInt64 = 0
  var activeEpisodeMemoryOffset: UInt64 = 0
  var compressedEpisodeMemoryOffset: UInt64 = 0
  var archiveEpisodeMemoryOffset: UInt64 = 0
  var semanticMemoryOffset: UInt64 = 0
  var semanticRelationMemoryOffset: UInt64 = 0
  var proceduralMemoryOffset: UInt64 = 0
  var replayMemoryOffset: UInt64 = 0
  var archivePageEpochOffset: UInt64 = 0
  var controlHeaderOffset: UInt64 = 0
  var driveOffset: UInt64 = 0
  var persistentMemoryByteCount: UInt64 = 0
  var journalByteCount: UInt64 = 0
  var recurrentScalarCount: UInt32 = 0
  var observationCount: UInt32 = 0
  var activeEpisodeCapacity: UInt32 = 0
  var activeEpisodeStride: UInt32 = 0
  var compressedEpisodeCapacity: UInt32 = 0
  var compressedEpisodeStride: UInt32 = 0
  var archiveEpisodeCapacity: UInt32 = 0
  var archiveEpisodeStride: UInt32 = 0
  var archiveSearchCandidateCount: UInt32 = 0
  var semanticCapacity: UInt32 = 0
  var semanticStride: UInt32 = 0
  var semanticRelationCapacity: UInt32 = 0
  var semanticRelationStride: UInt32 = 0
  var proceduralCapacity: UInt32 = 0
  var proceduralStride: UInt32 = 0
  var replayCapacity: UInt32 = 0
  var replayStride: UInt32 = 0
  var archiveRecordsPerPage: UInt32 = 0
  var archivePageCount: UInt32 = 0
  var driveCount: UInt32 = 0
  var maximumResults: UInt32 = 0
  var journalEntryCapacity: UInt32 = 0
  var learningRate: Float = 0
  var confirmationSimilarity: Float = 0
  var conflictSimilarity: Float = 0
  var maximumDamage: Float = 0
  var freezeCompetence: Float = 0
  var freezeMaximumDamage: Float = 0
  var freezeMaximumUncertainty: Float = 0
  var retireCompetence: Float = 0
  var retireMinimumDamage: Float = 0
  var degradationMargin: Float = 0
}

private struct ProspectiveLifecycleUniforms {
  var targetTimestampMicroseconds: UInt64 = 0
  var baseGeneration: UInt64 = 0
  var shadowGeneration: UInt64 = 0
  var recurrentOffset: UInt64 = 0
  var controlHeaderOffset: UInt64 = 0
  var lifecycleStateOffset: UInt64 = 0
  var prospectiveMemoryOffset: UInt64 = 0
  var persistentMemoryByteCount: UInt64 = 0
  var journalByteCount: UInt64 = 0
  var defaultDeadlineMicroseconds: UInt64 = 0
  var recurrentScalarCount: UInt32 = 0
  var prospectiveCapacity: UInt32 = 0
  var prospectiveStride: UInt32 = 0
  var journalEntryCapacity: UInt32 = 0
  var triggerThreshold: Float = 0
  var completionThreshold: Float = 0
  var failureRiskThreshold: Float = 0
  var defaultPriority: Float = 0
}

private struct CommittedTransitionUniforms {
  var targetTimestampMicroseconds: UInt64 = 0
  var previousTimestampMicroseconds: UInt64 = 0
  var baseGeneration: UInt64 = 0
  var shadowGeneration: UInt64 = 0
  var parameterVersionFingerprint: UInt64 = 0
  var episodeIdentifier: UInt64 = 0
  var controlStepIdentifier: UInt64 = 0
  var physicsStateFingerprint: UInt64 = 0
  var teacherContentFingerprint: UInt64 = 0
  var recurrentOffset: UInt64 = 0
  var observationOffset: UInt64 = 0
  var eventQueueOffset: UInt64 = 0
  var controlHeaderOffset: UInt64 = 0
  var somaticOutputOffset: UInt64 = 0
  var activeSensingOffset: UInt64 = 0
  var driveOffset: UInt64 = 0
  var neuromodulationOffset: UInt64 = 0
  var fastPlasticityOffset: UInt64 = 0
  var regionalPlasticModulationOffset: UInt64 = 0
  var cerebellarOffset: UInt64 = 0
  var cerebellarExpertMemoryOffset: UInt64 = 0
  var transitionMemoryOffset: UInt64 = 0
  var persistentMemoryByteCount: UInt64 = 0
  var journalByteCount: UInt64 = 0
  var recurrentScalarCount: UInt32 = 0
  var observationCount: UInt32 = 0
  var actionCount: UInt32 = 0
  var activeSensingCount: UInt32 = 0
  var driveCount: UInt32 = 0
  var neuromodulatorCount: UInt32 = 0
  var fastPlasticityCount: UInt32 = 0
  var regionalPlasticModulationCount: UInt32 = 0
  var activeCerebellarCount: UInt32 = 0
  var cerebellarExpertCapacity: UInt32 = 0
  var transitionCapacity: UInt32 = 0
  var transitionStride: UInt32 = 0
  var journalEntryCapacity: UInt32 = 0
  var teacherScalarCount: UInt32 = 0
  var teacherFlags: UInt32 = 0
}

private struct CounterfactualLearningUniforms {
  var targetTimestampMicroseconds: UInt64 = 0
  var sourceBeliefTimestampMicroseconds: UInt64 = 0
  var baseGeneration: UInt64 = 0
  var shadowGeneration: UInt64 = 0
  var parameterVersionFingerprint: UInt64 = 0
  var episodeIdentifier: UInt64 = 0
  var controlStepIdentifier: UInt64 = 0
  var candidateOffset: UInt64 = 0
  var planOffset: UInt64 = 0
  var counterfactualMemoryOffset: UInt64 = 0
  var persistentMemoryByteCount: UInt64 = 0
  var journalByteCount: UInt64 = 0
  var candidateCapacity: UInt32 = 0
  var planCapacity: UInt32 = 0
  var maximumPlanningHorizon: UInt32 = 0
  var counterfactualCapacity: UInt32 = 0
  var counterfactualStride: UInt32 = 0
  var journalEntryCapacity: UInt32 = 0
  var maximumSamples: UInt32 = 0
  var reserved: UInt32 = 0
}

@available(macOS 26.0, *)
public final class MetalMemoryRuntime: @unchecked Sendable {
  public let parameterVersionFingerprint: UInt64

  private let arena: MetalAgentStateArena
  private let regionalProgram: RegionalTokenProgram
  private let segmentation: EpisodicSegmentationDynamics
  private let retrieval: MemoryRetrievalDynamics
  private let controlLayout: MetalActiveControlLayout
  private let activeSensingCount: Int
  private let segmentPipeline: any MTLComputePipelineState
  private let retrievalBeginPipeline: any MTLComputePipelineState
  private let archiveShortlistClearPipeline: any MTLComputePipelineState
  private let archiveShortlistScorePipeline: any MTLComputePipelineState
  private let retrievalScorePipeline: any MTLComputePipelineState
  private let archiveRerankPipeline: any MTLComputePipelineState
  private let retrievalPublishPipeline: any MTLComputePipelineState
  private let reconsolidationPipeline: any MTLComputePipelineState
  private let consolidationPipeline: any MTLComputePipelineState
  private let prospectiveLifecyclePipeline: any MTLComputePipelineState
  private let committedTransitionPipeline: any MTLComputePipelineState
  private let counterfactualLearningPipeline: any MTLComputePipelineState
  private let argumentTable: any MTL4ArgumentTable
  private let uniformBuffer: any MTLBuffer
  private let retrievalUniformBuffers: [any MTLBuffer]
  private let reconsolidationUniformBuffer: any MTLBuffer
  private let consolidationUniformBuffer: any MTLBuffer
  private let prospectiveLifecycleUniformBuffer: any MTLBuffer
  private let committedTransitionUniformBuffer: any MTLBuffer
  private let counterfactualLearningUniformBuffer: any MTLBuffer

  public init(
    device: any MTLDevice,
    arena: MetalAgentStateArena,
    species: SpeciesTemplate,
    regionalProgram: RegionalTokenProgram,
    parameterVersion: BrainParameterVersion,
    segmentation: EpisodicSegmentationDynamics,
    retrieval: MemoryRetrievalDynamics,
    sharedParameters: MetalSharedParameterBank
  ) throws {
    guard MemoryLayout<MemoryUniforms>.stride == 208,
      MemoryLayout<MemoryRetrievalUniforms>.stride == 272,
      MemoryLayout<MemoryReconsolidationUniforms>.stride == 272,
      MemoryLayout<MemoryConsolidationUniforms>.stride == 248,
      MemoryLayout<ProspectiveLifecycleUniforms>.stride == 112,
      MemoryLayout<CommittedTransitionUniforms>.stride == 256,
      MemoryLayout<CounterfactualLearningUniforms>.stride == 128,
      arena.layout.speciesTemplateFingerprint == species.fingerprint,
      arena.layout.regionalProgramFingerprint == regionalProgram.fingerprint,
      parameterVersion.regionalProgramFingerprint == regionalProgram.fingerprint
    else {
      throw TissueError.metal("memory runtime ABI or parameter binding drift")
    }
    let sourceURL =
      Bundle.module.url(
        forResource: "MemoryState",
        withExtension: "metal",
        subdirectory: "Shaders"
      ) ?? Bundle.module.url(forResource: "MemoryState", withExtension: "metal")
    guard let sourceURL else {
      throw TissueError.metal("MemoryState.metal is missing from package resources")
    }
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    let options = MTLCompileOptions()
    options.languageVersion = .version4_0
    options.mathMode = .safe
    options.mathFloatingPointFunctions = .precise
    let library: any MTLLibrary
    do {
      library = try device.makeLibrary(source: source, options: options)
    } catch {
      throw TissueError.metal("memory-state Metal 4 compilation failed: \(error)")
    }
    let names = [
      "segment_and_journal_episode", "begin_memory_retrieval",
      "clear_archive_retrieval_shortlist",
      "score_archive_retrieval_shortlist",
      "score_memory_retrieval_candidates",
      "rerank_archive_retrieval_shortlist",
      "publish_memory_retrieval_winner",
      "reconsolidate_retrieved_memory",
      "consolidate_lived_memory_during_rest", "advance_prospective_memory",
      "journal_committed_learning_transition",
      "journal_committed_counterfactual_rollouts",
    ]
    let functions = try names.map { name -> any MTLFunction in
      guard let function = library.makeFunction(name: name) else {
        throw TissueError.metal("\(name) is missing from memory Metal")
      }
      return function
    }
    let pipelines: [any MTLComputePipelineState]
    do {
      pipelines = try functions.map { try device.makeComputePipelineState(function: $0) }
    } catch {
      throw TissueError.metal("memory-state pipeline creation failed: \(error)")
    }
    let descriptor = MTL4ArgumentTableDescriptor()
    descriptor.label = "NumiBrain memory-state arguments"
    descriptor.maxBufferBindCount = 7
    descriptor.initializeBindings = true
    guard let argumentTable = try? device.makeArgumentTable(descriptor: descriptor),
      let uniformBuffer = device.makeBuffer(
        length: MemoryLayout<MemoryUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let firstRetrievalUniform = device.makeBuffer(
        length: MemoryLayout<MemoryRetrievalUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let secondRetrievalUniform = device.makeBuffer(
        length: MemoryLayout<MemoryRetrievalUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let thirdRetrievalUniform = device.makeBuffer(
        length: MemoryLayout<MemoryRetrievalUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let fourthRetrievalUniform = device.makeBuffer(
        length: MemoryLayout<MemoryRetrievalUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let reconsolidationUniformBuffer = device.makeBuffer(
        length: MemoryLayout<MemoryReconsolidationUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let consolidationUniformBuffer = device.makeBuffer(
        length: MemoryLayout<MemoryConsolidationUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let prospectiveLifecycleUniformBuffer = device.makeBuffer(
        length: MemoryLayout<ProspectiveLifecycleUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let committedTransitionUniformBuffer = device.makeBuffer(
        length: MemoryLayout<CommittedTransitionUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let counterfactualLearningUniformBuffer = device.makeBuffer(
        length: MemoryLayout<CounterfactualLearningUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate memory-state bindings")
    }
    reconsolidationUniformBuffer.label =
      "NumiBrain accepted memory reconsolidation uniforms"
    uniformBuffer.label = "NumiBrain episodic segmentation uniforms"
    let retrievalUniformBuffers: [any MTLBuffer] = [
      firstRetrievalUniform, secondRetrievalUniform,
      thirdRetrievalUniform, fourthRetrievalUniform,
    ]
    for (index, buffer) in retrievalUniformBuffers.enumerated() {
      buffer.label = "NumiBrain memory retrieval pass \(index) uniforms"
    }
    consolidationUniformBuffer.label = "NumiBrain lived-memory consolidation uniforms"
    prospectiveLifecycleUniformBuffer.label =
      "NumiBrain prospective-memory lifecycle uniforms"
    committedTransitionUniformBuffer.label =
      "NumiBrain committed learning-transition uniforms"
    counterfactualLearningUniformBuffer.label =
      "NumiBrain imagined counterfactual-learning uniforms"
    argumentTable.setAddress(
      try sharedParameters.gpuAddress(.memory, minimumScalarCount: 8),
      index: 6
    )
    self.parameterVersionFingerprint = parameterVersion.fingerprint
    self.arena = arena
    self.regionalProgram = regionalProgram
    self.segmentation = segmentation
    self.retrieval = retrieval
    self.controlLayout = try MetalActiveControlLayout(
      arenaLayout: arena.layout,
      species: species
    )
    self.activeSensingCount = Int(species.motor.activeSensingActionDimension)
    self.segmentPipeline = pipelines[0]
    self.retrievalBeginPipeline = pipelines[1]
    self.archiveShortlistClearPipeline = pipelines[2]
    self.archiveShortlistScorePipeline = pipelines[3]
    self.retrievalScorePipeline = pipelines[4]
    self.archiveRerankPipeline = pipelines[5]
    self.retrievalPublishPipeline = pipelines[6]
    self.reconsolidationPipeline = pipelines[7]
    self.consolidationPipeline = pipelines[8]
    self.prospectiveLifecyclePipeline = pipelines[9]
    self.committedTransitionPipeline = pipelines[10]
    self.counterfactualLearningPipeline = pipelines[11]
    self.argumentTable = argumentTable
    self.uniformBuffer = uniformBuffer
    self.retrievalUniformBuffers = retrievalUniformBuffers
    self.reconsolidationUniformBuffer = reconsolidationUniformBuffer
    self.consolidationUniformBuffer = consolidationUniformBuffer
    self.prospectiveLifecycleUniformBuffer = prospectiveLifecycleUniformBuffer
    self.committedTransitionUniformBuffer = committedTransitionUniformBuffer
    self.counterfactualLearningUniformBuffer = counterfactualLearningUniformBuffer
  }

  public var residencyAllocations: [any MTLAllocation] {
    [
      uniformBuffer, consolidationUniformBuffer,
      reconsolidationUniformBuffer,
      prospectiveLifecycleUniformBuffer, committedTransitionUniformBuffer,
      counterfactualLearningUniformBuffer,
    ]
      + retrievalUniformBuffers
  }

  /// Journals one B_t -> B_t+1 learning record from the accepted root shadow.
  /// The input generation supplies the prior; the output generation supplies
  /// accepted observations, action, belief, drives, uncertainty, and outcome.
  public func encodeCommittedTransition(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    episodeIdentifier: UInt64,
    controlStepIdentifier: UInt64,
    previousTimestamp: BrainTimestamp,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    teacherState: MetalTeacherStateBufferLease?
  ) throws {
    let hot = try arena.hotStateView(transaction: transaction)
    let memory = try arena.persistentMemoryView(transaction: transaction)
    let transitions = arena.memoryLayout.section(.committedTransitions)
    let layout = arena.layout
    let recurrent = layout.section(.regionalRecurrent)
    let observations = layout.section(.sensoryObservations)
    let events = layout.section(.eventQueue)
    let somatic = layout.section(.somaticOutput)
    let activeSensing = controlLayout.section(.activeSensingCommands)
    let drives = layout.section(.drives)
    let neuromodulation = layout.section(.neuromodulation)
    let fastPlasticity = layout.section(.fastPlasticity)
    let regionalPlasticModulation = layout.section(.regionalPlasticModulation)
    let cerebellar = controlLayout.section(.cerebellarExperts)
    let cerebellarExpertMemory = layout.section(.cerebellarExpertMemory)
    let journalEntryCapacity = (memory.journalByteCount - 48) / 64
    let counts = [
      regionalProgram.scalarCount, observations.elementCount,
      somatic.elementCount, drives.elementCount, neuromodulation.elementCount,
      fastPlasticity.elementCount, regionalPlasticModulation.elementCount,
      cerebellar.elementCount, cerebellarExpertMemory.elementCount,
      transitions.elementCount, transitions.elementStride, journalEntryCapacity,
    ]
    guard counts.allSatisfy({ $0 > 0 && $0 <= Int(UInt32.max) }),
      transitions.elementStride >= 640,
      teacherState == nil
        || teacherState!.view.timestamp == acceptedPhysicsState.acceptedTimestamp
    else {
      throw TissueError.transaction("committed transition exceeds GPU capacity")
    }
    var uniforms = CommittedTransitionUniforms(
      targetTimestampMicroseconds: acceptedPhysicsState.acceptedTimestamp.rawValue,
      previousTimestampMicroseconds: previousTimestamp.rawValue,
      baseGeneration: transaction.baseGeneration,
      shadowGeneration: transaction.shadowGeneration,
      parameterVersionFingerprint: parameterVersionFingerprint,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: controlStepIdentifier,
      physicsStateFingerprint: acceptedPhysicsState.physicsStateFingerprint,
      teacherContentFingerprint: teacherState?.view.contentFingerprint ?? 0,
      recurrentOffset: UInt64(recurrent.byteOffset),
      observationOffset: UInt64(observations.byteOffset),
      eventQueueOffset: UInt64(events.byteOffset),
      controlHeaderOffset: UInt64(controlLayout.section(.header).byteOffset),
      somaticOutputOffset: UInt64(somatic.byteOffset),
      activeSensingOffset: UInt64(activeSensing.byteOffset),
      driveOffset: UInt64(drives.byteOffset),
      neuromodulationOffset: UInt64(neuromodulation.byteOffset),
      fastPlasticityOffset: UInt64(fastPlasticity.byteOffset),
      regionalPlasticModulationOffset: UInt64(
        regionalPlasticModulation.byteOffset
      ),
      cerebellarOffset: UInt64(cerebellar.byteOffset),
      cerebellarExpertMemoryOffset: UInt64(cerebellarExpertMemory.byteOffset),
      transitionMemoryOffset: UInt64(transitions.byteOffset),
      persistentMemoryByteCount: UInt64(memory.memoryByteCount),
      journalByteCount: UInt64(memory.journalByteCount),
      recurrentScalarCount: UInt32(regionalProgram.scalarCount),
      observationCount: UInt32(observations.elementCount),
      actionCount: UInt32(somatic.elementCount),
      activeSensingCount: UInt32(activeSensingCount),
      driveCount: UInt32(drives.elementCount),
      neuromodulatorCount: UInt32(neuromodulation.elementCount),
      fastPlasticityCount: UInt32(fastPlasticity.elementCount),
      regionalPlasticModulationCount: UInt32(
        regionalPlasticModulation.elementCount
      ),
      activeCerebellarCount: UInt32(cerebellar.elementCount),
      cerebellarExpertCapacity: UInt32(cerebellarExpertMemory.elementCount),
      transitionCapacity: UInt32(transitions.elementCount),
      transitionStride: UInt32(transitions.elementStride),
      journalEntryCapacity: UInt32(journalEntryCapacity),
      teacherScalarCount: teacherState?.view.scalarCount ?? 0,
      teacherFlags: teacherState?.view.flags ?? 0
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      committedTransitionUniformBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    argumentTable.setAddress(hot.inputGPUAddress, index: 0)
    argumentTable.setAddress(hot.outputGPUAddress, index: 1)
    argumentTable.setAddress(memory.memoryGPUAddress, index: 2)
    argumentTable.setAddress(memory.journalGPUAddress, index: 3)
    argumentTable.setAddress(committedTransitionUniformBuffer.gpuAddress, index: 4)
    argumentTable.setAddress(
      teacherState?.view.gpuAddress ?? hot.outputGPUAddress, index: 5
    )
    encoder.setComputePipelineState(committedTransitionPipeline)
    encoder.setArgumentTable(argumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
  }

  /// Journals a bounded risk-balanced subset of the accepted decision's
  /// planning-only trajectories. The destination is a disjoint learner ring,
  /// so no imagined sample can be retrieved or consolidated as lived memory.
  public func encodeCommittedCounterfactuals(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    episodeIdentifier: UInt64,
    controlStepIdentifier: UInt64,
    sourceBeliefTimestamp: BrainTimestamp,
    acceptedTimestamp: BrainTimestamp
  ) throws {
    let hot = try arena.hotStateView(transaction: transaction)
    let memory = try arena.persistentMemoryView(transaction: transaction)
    let candidates = controlLayout.section(.optionCandidates)
    let plans = controlLayout.section(.planSteps)
    let counterfactuals = arena.memoryLayout.section(.counterfactualRollouts)
    let journalEntryCapacity = (memory.journalByteCount - 48) / 64
    guard acceptedTimestamp >= sourceBeliefTimestamp,
      candidates.elementCount > 0,
      plans.elementCount > 0,
      plans.elementCount % candidates.elementCount == 0,
      counterfactuals.elementStride >= 256
    else {
      throw TissueError.transaction("counterfactual learner geometry is invalid")
    }
    let maximumPlanningHorizon = plans.elementCount / candidates.elementCount
    let counts = [
      candidates.elementCount, plans.elementCount, maximumPlanningHorizon,
      counterfactuals.elementCount, counterfactuals.elementStride,
      journalEntryCapacity,
    ]
    guard counts.allSatisfy({ $0 > 0 && $0 <= Int(UInt32.max) }) else {
      throw TissueError.transaction("counterfactual learner capacity is invalid")
    }
    var uniforms = CounterfactualLearningUniforms(
      targetTimestampMicroseconds: acceptedTimestamp.rawValue,
      sourceBeliefTimestampMicroseconds: sourceBeliefTimestamp.rawValue,
      baseGeneration: transaction.baseGeneration,
      shadowGeneration: transaction.shadowGeneration,
      parameterVersionFingerprint: parameterVersionFingerprint,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: controlStepIdentifier,
      candidateOffset: UInt64(candidates.byteOffset),
      planOffset: UInt64(plans.byteOffset),
      counterfactualMemoryOffset: UInt64(counterfactuals.byteOffset),
      persistentMemoryByteCount: UInt64(memory.memoryByteCount),
      journalByteCount: UInt64(memory.journalByteCount),
      candidateCapacity: UInt32(candidates.elementCount),
      planCapacity: UInt32(plans.elementCount),
      maximumPlanningHorizon: UInt32(maximumPlanningHorizon),
      counterfactualCapacity: UInt32(counterfactuals.elementCount),
      counterfactualStride: UInt32(counterfactuals.elementStride),
      journalEntryCapacity: UInt32(journalEntryCapacity),
      maximumSamples: UInt32(min(candidates.elementCount, 8))
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      counterfactualLearningUniformBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    argumentTable.setAddress(hot.outputGPUAddress, index: 0)
    argumentTable.setAddress(memory.memoryGPUAddress, index: 2)
    argumentTable.setAddress(memory.journalGPUAddress, index: 3)
    argumentTable.setAddress(counterfactualLearningUniformBuffer.gpuAddress, index: 4)
    encoder.setComputePipelineState(counterfactualLearningPipeline)
    encoder.setArgumentTable(argumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
  }

  /// Advances prospective intentions only inside an accepted root shadow.
  /// Interrupted goals become pending intentions, while active intentions are
  /// satisfied, failed, re-pended, or expired through the memory journal.
  public func encodeProspectiveLifecycle(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    timestamp: BrainTimestamp
  ) throws {
    let hot = try arena.hotStateView(transaction: transaction)
    let memory = try arena.persistentMemoryView(transaction: transaction)
    let prospective = arena.memoryLayout.section(.prospectiveIntentions)
    let recurrent = arena.layout.section(.regionalRecurrent)
    let lifecycle = arena.layout.section(.prospectiveLifecycle)
    let journalEntryCapacity = (memory.journalByteCount - 48) / 64
    guard regionalProgram.scalarCount > 0,
      regionalProgram.scalarCount <= Int(UInt32.max),
      prospective.elementCount > 0,
      prospective.elementCount <= Int(UInt32.max),
      prospective.elementStride <= Int(UInt32.max),
      lifecycle.byteCount >= 256,
      journalEntryCapacity > 0,
      journalEntryCapacity <= Int(UInt32.max)
    else {
      throw TissueError.transaction("prospective lifecycle exceeds GPU capacity")
    }
    var uniforms = ProspectiveLifecycleUniforms(
      targetTimestampMicroseconds: timestamp.rawValue,
      baseGeneration: transaction.baseGeneration,
      shadowGeneration: transaction.shadowGeneration,
      recurrentOffset: UInt64(recurrent.byteOffset),
      controlHeaderOffset: UInt64(controlLayout.section(.header).byteOffset),
      lifecycleStateOffset: UInt64(lifecycle.byteOffset),
      prospectiveMemoryOffset: UInt64(prospective.byteOffset),
      persistentMemoryByteCount: UInt64(memory.memoryByteCount),
      journalByteCount: UInt64(memory.journalByteCount),
      defaultDeadlineMicroseconds: 60_000_000,
      recurrentScalarCount: UInt32(regionalProgram.scalarCount),
      prospectiveCapacity: UInt32(prospective.elementCount),
      prospectiveStride: UInt32(prospective.elementStride),
      journalEntryCapacity: UInt32(journalEntryCapacity),
      triggerThreshold: 0.2,
      completionThreshold: 0.95,
      failureRiskThreshold: 0.8,
      defaultPriority: 0.55
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      prospectiveLifecycleUniformBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    argumentTable.setAddress(hot.outputGPUAddress, index: 0)
    argumentTable.setAddress(memory.memoryGPUAddress, index: 1)
    argumentTable.setAddress(memory.journalGPUAddress, index: 2)
    argumentTable.setAddress(prospectiveLifecycleUniformBuffer.gpuAddress, index: 3)
    encoder.setComputePipelineState(prospectiveLifecyclePipeline)
    encoder.setArgumentTable(argumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
  }

  /// Reconsolidates only records that were actually retrieved into this root's
  /// shadow and only from accepted posterior evidence. All mutations remain in
  /// the root journal, so a rejected physical trajectory cannot confirm,
  /// contradict, or rewrite a memory.
  public func encodeAcceptedReconsolidation(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    timestamp: BrainTimestamp
  ) throws {
    let hot = try arena.hotStateView(transaction: transaction)
    let memory = try arena.persistentMemoryView(transaction: transaction)
    let layout = arena.layout
    let active = arena.memoryLayout.section(.activeEpisodes)
    let compressed = arena.memoryLayout.section(.compressedEpisodeMetadata)
    let archive = arena.memoryLayout.section(.archiveIndex)
    let semantic = arena.memoryLayout.section(.semanticConcepts)
    let semanticRelations = arena.memoryLayout.section(.semanticRelations)
    let procedural = arena.memoryLayout.section(.proceduralSkills)
    let replay = arena.memoryLayout.section(.replayQueue)
    let archiveClusterCount = 256
    let archiveSlotsPerCluster = archive.elementCount / archiveClusterCount
    let (archiveSearchCandidateCount, archiveSearchOverflow) =
      archiveSlotsPerCluster.multipliedReportingOverflow(by: 2)
    let journalEntryCapacity = (memory.journalByteCount - 48) / 64
    let maximumResults = Int(retrieval.maximumResults)
    let sections = [
      active, compressed, archive, semantic, semanticRelations, procedural,
      replay,
    ]
    guard !archiveSearchOverflow, archiveSearchCandidateCount <= archive.elementCount,
      journalEntryCapacity > 0, journalEntryCapacity <= Int(UInt32.max),
      maximumResults > 0, maximumResults <= 4,
      sections.allSatisfy({
        $0.elementCount > 0 && $0.elementCount <= Int(UInt32.max)
          && $0.elementStride <= Int(UInt32.max)
      })
    else {
      throw TissueError.transaction("memory reconsolidation exceeds GPU capacity")
    }
    let recurrent = layout.section(.regionalRecurrent)
    let observations = layout.section(.sensoryObservations)
    var uniforms = MemoryReconsolidationUniforms(
      targetTimestampMicroseconds: timestamp.rawValue,
      baseGeneration: transaction.baseGeneration,
      shadowGeneration: transaction.shadowGeneration,
      recurrentOffset: UInt64(recurrent.byteOffset),
      observationOffset: UInt64(observations.byteOffset),
      retrievalScratchOffset: UInt64(
        layout.section(.memoryRetrievalScratch).byteOffset
      ),
      activeEpisodeMemoryOffset: UInt64(active.byteOffset),
      compressedEpisodeMemoryOffset: UInt64(compressed.byteOffset),
      archiveEpisodeMemoryOffset: UInt64(archive.byteOffset),
      semanticMemoryOffset: UInt64(semantic.byteOffset),
      semanticRelationMemoryOffset: UInt64(semanticRelations.byteOffset),
      proceduralMemoryOffset: UInt64(procedural.byteOffset),
      replayMemoryOffset: UInt64(replay.byteOffset),
      archivePageEpochOffset: UInt64(
        layout.section(.archivePageEpochs).byteOffset
      ),
      controlHeaderOffset: UInt64(controlLayout.section(.header).byteOffset),
      driveOffset: UInt64(layout.section(.drives).byteOffset),
      persistentMemoryByteCount: UInt64(memory.memoryByteCount),
      journalByteCount: UInt64(memory.journalByteCount),
      recurrentScalarCount: UInt32(recurrent.elementCount),
      observationCount: UInt32(observations.elementCount),
      activeEpisodeCapacity: UInt32(active.elementCount),
      activeEpisodeStride: UInt32(active.elementStride),
      compressedEpisodeCapacity: UInt32(compressed.elementCount),
      compressedEpisodeStride: UInt32(compressed.elementStride),
      archiveEpisodeCapacity: UInt32(archive.elementCount),
      archiveEpisodeStride: UInt32(archive.elementStride),
      archiveSearchCandidateCount: UInt32(archiveSearchCandidateCount),
      semanticCapacity: UInt32(semantic.elementCount),
      semanticStride: UInt32(semantic.elementStride),
      semanticRelationCapacity: UInt32(semanticRelations.elementCount),
      semanticRelationStride: UInt32(semanticRelations.elementStride),
      proceduralCapacity: UInt32(procedural.elementCount),
      proceduralStride: UInt32(procedural.elementStride),
      replayCapacity: UInt32(replay.elementCount),
      replayStride: UInt32(replay.elementStride),
      archiveRecordsPerPage: UInt32(
        MetalAgentStateLayout.archiveRecordsPerPage
      ),
      archivePageCount: UInt32(
        layout.section(.archivePageEpochs).elementCount
      ),
      driveCount: UInt32(layout.section(.drives).elementCount),
      maximumResults: UInt32(maximumResults),
      journalEntryCapacity: UInt32(journalEntryCapacity),
      learningRate: 0.10,
      confirmationSimilarity: 0.50,
      conflictSimilarity: -0.10,
      maximumDamage: 1.0,
      freezeCompetence: 0.92,
      freezeMaximumDamage: 0.08,
      freezeMaximumUncertainty: 0.12,
      retireCompetence: 0.15,
      retireMinimumDamage: 0.6,
      degradationMargin: 0.15
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      reconsolidationUniformBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    argumentTable.setAddress(hot.outputGPUAddress, index: 0)
    argumentTable.setAddress(memory.memoryGPUAddress, index: 1)
    argumentTable.setAddress(memory.journalGPUAddress, index: 2)
    argumentTable.setAddress(reconsolidationUniformBuffer.gpuAddress, index: 3)
    encoder.setComputePipelineState(reconsolidationPipeline)
    encoder.setArgumentTable(argumentTable)
    dispatch(encoder, pipeline: reconsolidationPipeline, count: maximumResults)
  }

  /// Emits semantic, procedural, and replay mutations only from already
  /// committed episodes. Rest/development/safety gating remains on the GPU.
  public func encodeRestConsolidation(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    timestamp: BrainTimestamp
  ) throws {
    let hot = try arena.hotStateView(transaction: transaction)
    let memory = try arena.persistentMemoryView(transaction: transaction)
    let active = arena.memoryLayout.section(.activeEpisodes)
    let compressed = arena.memoryLayout.section(.compressedEpisodeMetadata)
    let semantic = arena.memoryLayout.section(.semanticConcepts)
    let semanticRelations = arena.memoryLayout.section(.semanticRelations)
    let procedural = arena.memoryLayout.section(.proceduralSkills)
    let replayQueue = arena.memoryLayout.section(.replayQueue)
    let journalEntryCapacity = (memory.journalByteCount - 48) / 64
    let sections = [
      active, compressed, semantic, semanticRelations, procedural, replayQueue,
    ]
    guard journalEntryCapacity > 0, journalEntryCapacity <= Int(UInt32.max),
      sections.allSatisfy({
        $0.elementCount > 0 && $0.elementCount <= Int(UInt32.max)
          && $0.elementStride <= Int(UInt32.max)
      })
    else {
      throw TissueError.transaction("memory consolidation exceeds GPU capacity")
    }
    let layout = arena.layout
    var uniforms = MemoryConsolidationUniforms(
      targetTimestampMicroseconds: timestamp.rawValue,
      baseGeneration: transaction.baseGeneration,
      shadowGeneration: transaction.shadowGeneration,
      controlHeaderOffset: UInt64(controlLayout.section(.header).byteOffset),
      internalActionOffset: UInt64(
        controlLayout.section(.internalActions).byteOffset
      ),
      developmentalStateOffset: UInt64(
        layout.section(.developmentalState).byteOffset
      ),
      driveOffset: UInt64(layout.section(.drives).byteOffset),
      activeEpisodeMemoryOffset: UInt64(active.byteOffset),
      compressedEpisodeMemoryOffset: UInt64(compressed.byteOffset),
      semanticMemoryOffset: UInt64(semantic.byteOffset),
      semanticRelationMemoryOffset: UInt64(semanticRelations.byteOffset),
      proceduralMemoryOffset: UInt64(procedural.byteOffset),
      replayMemoryOffset: UInt64(replayQueue.byteOffset),
      proceduralTraceOffset: UInt64(
        layout.section(.proceduralExecutionTrace).byteOffset
      ),
      persistentMemoryByteCount: UInt64(memory.memoryByteCount),
      journalByteCount: UInt64(memory.journalByteCount),
      activeEpisodeCapacity: UInt32(active.elementCount),
      activeEpisodeStride: UInt32(active.elementStride),
      compressedEpisodeCapacity: UInt32(compressed.elementCount),
      compressedEpisodeStride: UInt32(compressed.elementStride),
      semanticCapacity: UInt32(semantic.elementCount),
      semanticStride: UInt32(semantic.elementStride),
      semanticRelationCapacity: UInt32(semanticRelations.elementCount),
      semanticRelationStride: UInt32(semanticRelations.elementStride),
      proceduralCapacity: UInt32(procedural.elementCount),
      proceduralStride: UInt32(procedural.elementStride),
      replayCapacity: UInt32(replayQueue.elementCount),
      replayStride: UInt32(replayQueue.elementStride),
      proceduralTraceCapacity: UInt32(
        layout.section(.proceduralExecutionTrace).elementCount
      ),
      proceduralTraceStride: UInt32(
        layout.section(.proceduralExecutionTrace).elementStride
      ),
      journalEntryCapacity: UInt32(journalEntryCapacity),
      minimumProceduralEpisodes: 3,
      flags: 0,
      reserved: 0,
      maximumDamage: 0.25,
      minimumSalience: segmentation.boundaryThreshold,
      proceduralLearningRate: 0.25,
      semanticLearningRate: 0.2,
      freezeCompetence: 0.92,
      freezeMaximumDamage: 0.08,
      freezeMaximumUncertainty: 0.12,
      retireCompetence: 0.15,
      retireMinimumDamage: 0.6,
      degradationMargin: 0.15,
      mergeSimilarity: 0.92
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      consolidationUniformBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    argumentTable.setAddress(hot.outputGPUAddress, index: 0)
    argumentTable.setAddress(memory.memoryGPUAddress, index: 1)
    argumentTable.setAddress(memory.journalGPUAddress, index: 2)
    argumentTable.setAddress(consolidationUniformBuffer.gpuAddress, index: 3)
    encoder.setComputePipelineState(consolidationPipeline)
    encoder.setArgumentTable(argumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
  }

  public func encodeRetrieval(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    timestamp: BrainTimestamp
  ) throws {
    let hot = try arena.hotStateView(transaction: transaction)
    let memory = try arena.persistentMemoryView(transaction: transaction)
    let active = arena.memoryLayout.section(.activeEpisodes)
    let compressed = arena.memoryLayout.section(.compressedEpisodeMetadata)
    let archive = arena.memoryLayout.section(.archiveIndex)
    let semantic = arena.memoryLayout.section(.semanticConcepts)
    let semanticRelations = arena.memoryLayout.section(.semanticRelations)
    let procedural = arena.memoryLayout.section(.proceduralSkills)
    let prospective = arena.memoryLayout.section(.prospectiveIntentions)
    let archiveClusterCount = 256
    let archiveSlotsPerCluster = archive.elementCount / archiveClusterCount
    let (archiveSearchCandidateCount, archiveSearchOverflow) =
      archiveSlotsPerCluster.multipliedReportingOverflow(by: 2)
    let candidateCounts = [
      active.elementCount, compressed.elementCount, archiveSearchCandidateCount,
      semantic.elementCount,
      semanticRelations.elementCount, procedural.elementCount,
      prospective.elementCount,
    ]
    let candidateCount = try candidateCounts.reduce(0) { total, count in
      let (next, overflow) = total.addingReportingOverflow(count)
      guard !overflow else {
        throw TissueError.metal("memory retrieval candidate count overflows Int")
      }
      return next
    }
    let maximumResults = Int(retrieval.maximumResults)
    guard !archiveSearchOverflow,
      archiveSearchCandidateCount <= archive.elementCount,
      candidateCount > 0, candidateCount <= 0x0f_ffff,
      candidateCount <= Int(UInt32.max),
      maximumResults <= retrievalUniformBuffers.count,
      3 + maximumResults <= arena.layout.section(.workspaceMetadata).elementCount,
      [active, compressed, archive, semantic, semanticRelations, procedural,
       prospective].allSatisfy({
        $0.elementCount <= Int(UInt32.max) && $0.elementStride <= Int(UInt32.max)
      })
    else {
      throw TissueError.metal("memory retrieval exceeds deterministic GPU capacity")
    }
    let sections = arena.layout
    for pass in 0..<maximumResults {
      var uniforms = MemoryRetrievalUniforms(
        targetTimestampMicroseconds: timestamp.rawValue,
        shadowGeneration: transaction.shadowGeneration,
        recurrentOffset: UInt64(sections.section(.regionalRecurrent).byteOffset),
        workspaceContentOffset: UInt64(sections.section(.workspaceContent).byteOffset),
        workspaceMetadataOffset: UInt64(sections.section(.workspaceMetadata).byteOffset),
        retrievalScratchOffset: UInt64(
          sections.section(.memoryRetrievalScratch).byteOffset
        ),
        activeEpisodeMemoryOffset: UInt64(active.byteOffset),
        compressedEpisodeMemoryOffset: UInt64(compressed.byteOffset),
        archiveEpisodeMemoryOffset: UInt64(archive.byteOffset),
        semanticMemoryOffset: UInt64(semantic.byteOffset),
        semanticRelationMemoryOffset: UInt64(semanticRelations.byteOffset),
        proceduralMemoryOffset: UInt64(procedural.byteOffset),
        prospectiveMemoryOffset: UInt64(prospective.byteOffset),
        controlHeaderOffset: UInt64(controlLayout.section(.header).byteOffset),
        internalActionOffset: UInt64(
          controlLayout.section(.internalActions).byteOffset
        ),
        developmentalStateOffset: UInt64(
          sections.section(.developmentalState).byteOffset
        ),
        archivePageResidencyOffset: UInt64(
          sections.section(.archivePageResidency).byteOffset
        ),
        archivePageRequestOffset: UInt64(
          sections.section(.archivePageRequests).byteOffset
        ),
        parameterVersionFingerprint: parameterVersionFingerprint,
        recurrentScalarCount: UInt32(regionalProgram.scalarCount),
        workspaceCapacity: UInt32(
          sections.section(.workspaceMetadata).elementCount
        ),
        workspaceDimension: UInt32(
          sections.section(.workspaceContent).elementCount
            / sections.section(.workspaceMetadata).elementCount
        ),
        activeEpisodeCapacity: UInt32(active.elementCount),
        activeEpisodeStride: UInt32(active.elementStride),
        compressedEpisodeCapacity: UInt32(compressed.elementCount),
        compressedEpisodeStride: UInt32(compressed.elementStride),
        archiveEpisodeCapacity: UInt32(archive.elementCount),
        archiveEpisodeStride: UInt32(archive.elementStride),
        archiveSearchCandidateCount: UInt32(archiveSearchCandidateCount),
        archiveRecordsPerPage: UInt32(MetalAgentStateLayout.archiveRecordsPerPage),
        archivePageCount: UInt32(
          sections.section(.archivePageResidency).elementCount
        ),
        archivePageRequestCapacity: UInt32(
          MetalAgentStateLayout.archivePageRequestCapacity
        ),
        semanticCapacity: UInt32(semantic.elementCount),
        semanticStride: UInt32(semantic.elementStride),
        semanticRelationCapacity: UInt32(semanticRelations.elementCount),
        semanticRelationStride: UInt32(semanticRelations.elementStride),
        proceduralCapacity: UInt32(procedural.elementCount),
        proceduralStride: UInt32(procedural.elementStride),
        prospectiveCapacity: UInt32(prospective.elementCount),
        prospectiveStride: UInt32(prospective.elementStride),
        candidateCount: UInt32(candidateCount),
        retrievalPass: UInt32(pass),
        maximumResults: UInt32(maximumResults),
        minimumScore: retrieval.minimumScore,
        episodicWeight: retrieval.episodicWeight,
        semanticWeight: retrieval.semanticWeight,
        proceduralWeight: retrieval.proceduralWeight,
        prospectiveWeight: retrieval.prospectiveWeight
      )
      withUnsafeBytes(of: &uniforms) { bytes in
        guard let source = bytes.baseAddress else { return }
        retrievalUniformBuffers[pass].contents().copyMemory(
          from: source,
          byteCount: bytes.count
        )
      }
    }
    argumentTable.setAddress(hot.outputGPUAddress, index: 0)
    argumentTable.setAddress(memory.memoryGPUAddress, index: 1)
    argumentTable.setAddress(retrievalUniformBuffers[0].gpuAddress, index: 2)
    encoder.setComputePipelineState(retrievalBeginPipeline)
    encoder.setArgumentTable(argumentTable)
    dispatch(encoder, pipeline: retrievalBeginPipeline, count: maximumResults)
    barrier(encoder)
    for pass in 0..<maximumResults {
      argumentTable.setAddress(retrievalUniformBuffers[pass].gpuAddress, index: 2)
      dispatch(
        encoder,
        pipeline: archiveShortlistClearPipeline,
        count: 32
      )
      barrier(encoder)
      dispatch(
        encoder,
        pipeline: archiveShortlistScorePipeline,
        count: archiveSearchCandidateCount
      )
      barrier(encoder)
      dispatch(
        encoder,
        pipeline: retrievalScorePipeline,
        count: candidateCount
      )
      barrier(encoder)
      dispatch(
        encoder,
        pipeline: archiveRerankPipeline,
        count: 32
      )
      barrier(encoder)
      dispatch(encoder, pipeline: retrievalPublishPipeline, count: 1)
      barrier(encoder)
    }
  }

  public func encodeEpisodicSegmentation(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    episodeIdentifier: UInt64,
    controlStepIdentifier: UInt64,
    timestamp: BrainTimestamp
  ) throws {
    let hot = try arena.hotStateView(transaction: transaction)
    let memory = try arena.persistentMemoryView(transaction: transaction)
    let activeEpisodes = arena.memoryLayout.section(.activeEpisodes)
    let compressedEpisodes = arena.memoryLayout.section(.compressedEpisodeMetadata)
    let archiveEpisodes = arena.memoryLayout.section(.archiveIndex)
    let replayQueue = arena.memoryLayout.section(.replayQueue)
    let recurrent = arena.layout.section(.regionalRecurrent)
    let events = arena.layout.section(.eventQueue)
    let workspace = arena.layout.section(.workspaceContent)
    let journalEntryCapacity = (memory.journalByteCount - 48) / 64
    guard transaction.layoutFingerprint == arena.layout.fingerprint,
      regionalProgram.scalarCount <= Int(UInt32.max),
      workspace.elementCount <= Int(UInt32.max),
      activeEpisodes.elementCount <= Int(UInt32.max),
      activeEpisodes.elementStride <= Int(UInt32.max),
      compressedEpisodes.elementCount <= Int(UInt32.max),
      compressedEpisodes.elementStride <= Int(UInt32.max),
      archiveEpisodes.elementCount <= Int(UInt32.max),
      archiveEpisodes.elementStride <= Int(UInt32.max),
      replayQueue.elementCount <= Int(UInt32.max),
      replayQueue.elementStride <= Int(UInt32.max),
      journalEntryCapacity > 0, journalEntryCapacity <= Int(UInt32.max)
    else {
      throw TissueError.transaction("episodic segmentation exceeds memory capacity")
    }
    var uniforms = MemoryUniforms(
      targetTimestampMicroseconds: timestamp.rawValue,
      baseGeneration: transaction.baseGeneration,
      shadowGeneration: transaction.shadowGeneration,
      parameterVersionFingerprint: parameterVersionFingerprint,
      episodeIdentifier: episodeIdentifier,
      controlStepIdentifier: controlStepIdentifier,
      recurrentOffset: UInt64(recurrent.byteOffset),
      eventQueueOffset: UInt64(events.byteOffset),
      workspaceContentOffset: UInt64(workspace.byteOffset),
      controlHeaderOffset: UInt64(controlLayout.section(.header).byteOffset),
      activeEpisodeAccumulatorOffset: UInt64(
        arena.layout.section(.activeEpisodeAccumulator).byteOffset
      ),
      activeEpisodeMemoryOffset: UInt64(activeEpisodes.byteOffset),
      compressedEpisodeMemoryOffset: UInt64(compressedEpisodes.byteOffset),
      archiveEpisodeMemoryOffset: UInt64(archiveEpisodes.byteOffset),
      replayMemoryOffset: UInt64(replayQueue.byteOffset),
      archivePageEpochOffset: UInt64(
        arena.layout.section(.archivePageEpochs).byteOffset
      ),
      journalByteCount: UInt64(memory.journalByteCount),
      persistentMemoryByteCount: UInt64(memory.memoryByteCount),
      recurrentScalarCount: UInt32(regionalProgram.scalarCount),
      workspaceScalarCount: UInt32(workspace.elementCount),
      activeEpisodeCapacity: UInt32(activeEpisodes.elementCount),
      activeEpisodeStride: UInt32(activeEpisodes.elementStride),
      compressedEpisodeCapacity: UInt32(compressedEpisodes.elementCount),
      compressedEpisodeStride: UInt32(compressedEpisodes.elementStride),
      archiveEpisodeCapacity: UInt32(archiveEpisodes.elementCount),
      archiveEpisodeStride: UInt32(archiveEpisodes.elementStride),
      replayCapacity: UInt32(replayQueue.elementCount),
      replayStride: UInt32(replayQueue.elementStride),
      archiveRecordsPerPage: UInt32(
        MetalAgentStateLayout.archiveRecordsPerPage
      ),
      archivePageCount: UInt32(
        arena.layout.section(.archivePageEpochs).elementCount
      ),
      journalEntryCapacity: UInt32(journalEntryCapacity),
      surpriseSampleCount: UInt32(segmentation.surpriseSampleCount),
      boundaryThreshold: segmentation.boundaryThreshold,
      eventSalienceWeight: segmentation.eventSalienceWeight
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      uniformBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    argumentTable.setAddress(hot.outputGPUAddress, index: 0)
    argumentTable.setAddress(memory.memoryGPUAddress, index: 1)
    argumentTable.setAddress(memory.journalGPUAddress, index: 2)
    argumentTable.setAddress(uniformBuffer.gpuAddress, index: 3)
    encoder.setComputePipelineState(segmentPipeline)
    encoder.setArgumentTable(argumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
  }

  private func dispatch(
    _ encoder: any MTL4ComputeCommandEncoder,
    pipeline: any MTLComputePipelineState,
    count: Int
  ) {
    encoder.setComputePipelineState(pipeline)
    encoder.setArgumentTable(argumentTable)
    let width = min(
      max(pipeline.threadExecutionWidth, 1),
      pipeline.maxTotalThreadsPerThreadgroup
    )
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: max(count, 1), height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
    )
  }

  private func barrier(_ encoder: any MTL4ComputeCommandEncoder) {
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
  }

}

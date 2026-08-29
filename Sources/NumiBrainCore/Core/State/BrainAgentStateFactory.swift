import Foundation

public enum BrainAgentStateFactory {
  /// Creates a complete independent mind at generation zero from immutable
  /// species, anatomy, regional-program, and parameter identities.
  public static func makeInnateState(
    environmentIdentifier: UInt32,
    episodeIdentifier: UInt64,
    species: SpeciesTemplate,
    attachmentCatalog: NumanXMuscleAttachmentCatalog,
    graph: ReferenceBrainGraph,
    regionalProgram: RegionalTokenProgram,
    parameterVersion: BrainParameterVersion,
    initialTimestamp: BrainTimestamp = BrainTimestamp(microseconds: 0),
    physicalGeneration: UInt64 = 0,
    maximumResidentMemoryBytes: UInt64 = 512 * 1_024 * 1_024
  ) throws -> BrainAgentState {
    guard species.referenceGraphFingerprint == graph.fingerprint,
      species.body.bodyCount == attachmentCatalog.bodyCount,
      species.body.muscleCount == UInt32(attachmentCatalog.attachments.count),
      species.body.muscleAttachmentFingerprint == attachmentCatalog.fingerprint,
      regionalProgram.scheduleFingerprint == graph.schedule.fingerprint,
      parameterVersion.scheduleFingerprint == graph.schedule.fingerprint,
      parameterVersion.regionalProgramFingerprint == regionalProgram.fingerprint
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "innate-state immutable identities do not agree"
      )
    }

    let zero = try BrainVector3.zero
    let pose = try BrainPoseEstimate.origin
    let bodyNodes = try (0..<attachmentCatalog.bodyCount).map { identifier in
      try BodyNodeBelief(
        bodyIdentifier: identifier,
        pose: pose,
        contactProbability: 0,
        supportProbability: 0,
        estimatedLocalForce: zero,
        pain: 0,
        vulnerability: 0,
        reachability: 0,
        ownershipConfidence: 0,
        observationTimestamp: nil
      )
    }
    let unknownScalar = try BeliefScalar(mean: 0, logVariance: 0)
    let muscleEdges = try attachmentCatalog.attachments.map { attachment in
      try MuscleEdgeBelief(
        muscleIdentifier: attachment.muscleIdentifier,
        firstBodyIdentifier: attachment.firstBodyIdentifier,
        terminalBodyIdentifier: attachment.terminalBodyIdentifier,
        activation: unknownScalar,
        length: unknownScalar,
        lengthVelocity: unknownScalar,
        force: unknownScalar,
        fatigue: unknownScalar,
        learnedEffect: BrainLatentVector.zeros(count: 16)
      )
    }
    let bodyDynamics = try BodySchemaPosteriorDynamics.runtimeFoundationV0
    let bodyPosterior = try bodyDynamics.initialState(
      bodyCount: attachmentCatalog.bodyCount,
      timestamp: initialTimestamp
    )
    let physiologyBelief = PhysiologyBeliefState(
      energy: unknownScalar,
      hydration: unknownScalar,
      oxygen: unknownScalar,
      carbonDioxide: unknownScalar,
      temperature: unknownScalar,
      fatigue: unknownScalar,
      tissueDamage: unknownScalar,
      inflammation: unknownScalar,
      sleepPressure: unknownScalar,
      autonomicState: try .zeros(count: Int(species.physiology.stateDimension))
    )
    let context = try BeliefContextState(
      eventCode: 0,
      taskCode: 0,
      socialContextCode: 0,
      activeGoalIdentifier: nil,
      locationCode: 0,
      behavioralModeCode: UInt32(ControlMode.reflex.rawValue),
      latent: .zeros(count: 256),
      confidence: 0
    )
    let belief = try EmbodiedBeliefState(
      timestamp: initialTimestamp,
      bodyNodes: bodyNodes,
      muscleEdges: muscleEdges,
      bodyLoadPosterior: bodyPosterior,
      objects: [],
      otherAgents: [],
      relations: [],
      spatialTransforms: [],
      physiology: physiologyBelief,
      context: context,
      posteriorLatent: .zeros(count: 512),
      epistemicConfidence: 0,
      observationNoiseEstimate: 1,
      maximumObjectSlots: Int(species.capacities.objectSlotCapacity),
      maximumAgentSlots: Int(species.capacities.otherAgentSlotCapacity)
    )

    let worldLevels = try WorldModelLevel.allCases.map { level in
      let descriptor = try WorldModelLevelDescriptor.referenceV1(level: level)
      return try WorldModelLevelState(
        descriptor: descriptor,
        timestamp: initialTimestamp,
        latent: .zeros(count: Int(descriptor.latentDimension)),
        bottomUpPredictionError: .zeros(count: Int(descriptor.latentDimension)),
        topDownContext: .zeros(count: Int(descriptor.latentDimension)),
        latestPrediction: nil
      )
    }
    let worldModel = try HierarchicalWorldModelState(
      timestamp: initialTimestamp,
      parameterVersionFingerprint: parameterVersion.fingerprint,
      levels: worldLevels
    )
    let workspace = try WorkspaceState.empty(
      tokenCapacity: species.capacities.workspaceTokenCapacity,
      tokenDimension: species.capacities.workspaceTokenDimension,
      timestamp: initialTimestamp
    )
    let memory = try makeEmptyMemory(species: species)
    let drives = try DriveState(
      timestamp: initialTimestamp,
      channels: DriveKind.allCases.map { kind in
        try DriveChannelState(
          kind: kind,
          level: 0,
          viableMinimum: -0.1,
          viableMaximum: 0.1,
          priorityWeight: 1,
          estimatedRate: 0
        )
      }
    )
    let neuromodulation = try NeuromodulatoryState(
      timestamp: initialTimestamp,
      channels: NeuromodulatorKind.allCases.map { kind in
        try NeuromodulatorChannelState(
          kind: kind,
          value: 0,
          decayTimeConstantMicroseconds: 100_000
        )
      }
    )
    let fastPlasticity = try makeFastPlasticity(
      graph: graph,
      species: species,
      timestamp: initialTimestamp
    )
    let control = try makeInnateControl(species: species, timestamp: initialTimestamp)
    let development = try makeInnateDevelopment(species: species, graph: graph)
    let scheduler = try initialScheduler(
      schedule: graph.schedule,
      parameterVersionFingerprint: parameterVersion.fingerprint,
      timestamp: initialTimestamp
    )
    let runtime = try BrainRuntimeState(
      committedTimestamp: initialTimestamp,
      brainGeneration: 0,
      physicalGeneration: physicalGeneration,
      parameterVersionFingerprint: parameterVersion.fingerprint,
      scheduler: scheduler,
      eventQueue: [],
      delayMessages: [],
      oscillatorPhases: Dictionary(
        uniqueKeysWithValues: species.cpg.oscillators.map { ($0.identifier, 0) }
      ),
      memoryAllocator: MemoryAllocatorState(
        generation: 0,
        activeBytes: 0,
        warmBytes: 0,
        archiveBytes: 0,
        pendingJournalBytes: 0,
        maximumResidentBytes: maximumResidentMemoryBytes
      ),
      random: CounterRandomState(
        episodeIdentifier: episodeIdentifier,
        controlStepIdentifier: 0,
        generation: 0,
        moduleCounters: Dictionary(
          uniqueKeysWithValues: graph.modules.map { ($0.identifier, 0) }
        )
      ),
      transactionGeneration: 0
    )
    return try BrainAgentState(
      environmentIdentifier: environmentIdentifier,
      speciesTemplateFingerprint: species.fingerprint,
      regionalProgramFingerprint: regionalProgram.fingerprint,
      regionalRecurrentState: Array(
        repeating: 0,
        count: regionalProgram.parameters.count
      ),
      belief: belief,
      worldModel: worldModel,
      workspace: workspace,
      memory: memory,
      drives: drives,
      neuromodulation: neuromodulation,
      fastPlasticity: fastPlasticity,
      control: control,
      development: development,
      runtime: runtime
    )
  }

  private static func makeEmptyMemory(
    species: SpeciesTemplate
  ) throws -> CompleteMemoryState {
    let capacities = species.capacities
    let episodic = try EpisodicMemoryState(
      generation: 0,
      nextRecordIdentifier: 1,
      activeCapacity: capacities.activeEpisodicCapacity,
      compressedCapacity: capacities.compressedEpisodicCapacity,
      archiveCapacity: capacities.archiveEpisodicCapacity,
      activeRecords: [],
      compressedRecords: [],
      archiveIndex: [],
      unfinishedEpisode: [],
      unfinishedEpisodeStart: nil
    )
    let semantic = try SemanticMemoryState(
      generation: 0,
      conceptCapacity: capacities.semanticConceptCapacity,
      relationCapacity: capacities.semanticRelationCapacity,
      nextConceptIdentifier: 1,
      nextRelationIdentifier: 1,
      concepts: [],
      relations: []
    )
    let procedural = try ProceduralMemoryState(
      generation: 0,
      skillCapacity: capacities.proceduralSkillCapacity,
      nextSkillIdentifier: 1,
      skills: []
    )
    let prospective = try ProspectiveMemoryState(
      generation: 0,
      capacity: capacities.prospectiveIntentionCapacity,
      nextIdentifier: 1,
      intentions: []
    )
    let (replayCapacity, overflow) = capacities.archiveEpisodicCapacity
      .addingReportingOverflow(capacities.proceduralSkillCapacity)
    guard !overflow else {
      throw BrainRuntimeError.capacity("replay capacity overflows UInt32")
    }
    let replay = try ReplayState(generation: 0, capacity: replayCapacity, entries: [])
    return try CompleteMemoryState(
      episodic: episodic,
      semantic: semantic,
      procedural: procedural,
      prospective: prospective,
      replay: replay
    )
  }

  private static func makeFastPlasticity(
    graph: ReferenceBrainGraph,
    species: SpeciesTemplate,
    timestamp: BrainTimestamp
  ) throws -> FastPlasticityState {
    let regions = species.enabledModuleIdentifiers
    let capacity = Int(species.capacities.fastPlasticityCapacity)
    let sites = try (0..<capacity).map { index -> FastPlasticitySiteState in
      let region = regions[index % regions.count]
      let basis = UInt16(index / regions.count)
      return try FastPlasticitySiteState(
        identifier: FastPlasticitySiteIdentifier(
          regionIdentifier: region,
          basisIdentifier: basis
        ),
        coefficient: 0,
        eligibility: 0,
        coefficientRetention: 0.999,
        eligibilityRetention: 0.95,
        learningRate: 0.001,
        maximumMagnitude: 1
      )
    }
    return try FastPlasticityState(
      generation: 0,
      timestamp: timestamp,
      capacity: species.capacities.fastPlasticityCapacity,
      sites: sites
    )
  }

  private static func makeInnateControl(
    species: SpeciesTemplate,
    timestamp: BrainTimestamp
  ) throws -> ActiveControlState {
    let reflexDimension = max(species.reflexes.count, 1)
    let spinal = try SpinalControlState(
      cpgPhases: Array(repeating: 0, count: species.cpg.oscillators.count),
      reflexState: .zeros(count: reflexDimension),
      motorNeuronState: Array(repeating: 0, count: Int(species.motor.actuatorCount)),
      muscleExcitations: Array(repeating: 0, count: Int(species.motor.actuatorCount)),
      autonomicCommands: Array(
        repeating: 0,
        count: Int(species.physiology.autonomicActionDimension)
      )
    )
    return try ActiveControlState(
      timestamp: timestamp,
      mode: .reflex,
      activeGoal: nil,
      suppressedGoals: [],
      candidates: [],
      selectedOption: nil,
      plan: nil,
      motorGoal: nil,
      cerebellarExperts: [],
      spinal: spinal,
      controllerPhase: 0,
      emergencyStopActive: false,
      maximumCandidates: Int(species.capacities.activeOptionCandidateCapacity),
      maximumActiveCerebellarExperts: Int(
        species.capacities.activeCerebellarExpertCapacity
      )
    )
  }

  private static func makeInnateDevelopment(
    species: SpeciesTemplate,
    graph: ReferenceBrainGraph
  ) throws -> BrainDevelopmentalState {
    guard let stage = species.development.first,
      stage.stage == .innateScaffold
    else {
      throw BrainRuntimeError.invalidDescriptor("species has no innate developmental stage")
    }
    let unlocked = Set(stage.unlockedModuleIdentifiers)
    let regions = try graph.modules.map { module in
      try RegionalMaturationState(
        moduleIdentifier: module.identifier,
        learningRateMultiplier: stage.learningRateMultiplier,
        timescaleMultiplier: 1,
        routeGainMultiplier: unlocked.contains(module.identifier) ? 1 : 0,
        conductionDelayMultiplier: 1,
        capacityFraction: unlocked.contains(module.identifier) ? 1 : 0,
        unlocked: unlocked.contains(module.identifier)
      )
    }
    return try BrainDevelopmentalState(
      developmentalAgeMicroseconds: 0,
      stage: .innateScaffold,
      maturationProgress: 0,
      sensorPrecisionMultiplier: stage.sensorPrecisionMultiplier,
      muscleStrengthMultiplier: stage.muscleStrengthMultiplier,
      replayAllocationMultiplier: 0,
      criticalPeriods: [],
      regions: regions,
      capacities: species.capacities,
      capabilityEvidenceCodes: []
    )
  }

  private static func initialScheduler(
    schedule: BrainModuleSchedule,
    parameterVersionFingerprint: UInt64,
    timestamp: BrainTimestamp
  ) throws -> BrainSchedulerSnapshot {
    let clocks = try schedule.modules.map { module -> BrainModuleClockState in
      let (nextDue, overflow) = timestamp.rawValue.addingReportingOverflow(
        UInt64(module.periodMicroseconds)
      )
      guard !overflow else {
        throw BrainRuntimeError.invalidSchedule("initial module due time overflows")
      }
      return BrainModuleClockState(nextDue: BrainTimestamp(microseconds: nextDue))
    }
    return BrainSchedulerSnapshot(
      scheduleFingerprint: schedule.fingerprint,
      parameterVersionFingerprint: parameterVersionFingerprint,
      committedTime: timestamp,
      generation: 0,
      moduleClocks: clocks
    )
  }
}

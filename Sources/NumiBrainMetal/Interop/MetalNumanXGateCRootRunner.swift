import Foundation
@preconcurrency import Metal
import NumiBrainABI
import NumiBrainCore

/// Sequential, evidence-producing runner for authoritative NumanX roots. The
/// native bridge owns the 157-body physics asset; this runner owns Brain root
/// scheduling and writes exact input and terminal transcript artifacts. It is
/// intentionally not an evaluator: captured roots remain non-promotable until
/// disjoint Gate C partitions and metric evidence are separately verified.
@available(macOS 26.0, *)
@_spi(NumanXInterop)
public final class MetalNumanXGateCRootRunner: @unchecked Sendable {
  public enum SensorIntervention: Sendable {
    case none
    /// Preserves every exact settled value while marking every receptor
    /// observation unavailable in a fresh, disjoint packet.
    case invalidateAll
    /// Qualification-only observational alias: copies the immediately prior
    /// settled packet's exact value/validity bytes into fresh buffers with the
    /// current root's causal timestamps and transaction identity.
    case replayPreviousSettledObservation

    var isOOD: Bool {
      if case .invalidateAll = self { return true }
      return false
    }
  }

  public enum HardSafetyIntervention: Sendable {
    case none
    /// Injects a same-root damaging-contact challenge after learned inference
    /// and before the private protective motor map.
    case emergencyStop

    var isChallenge: Bool {
      if case .emergencyStop = self { return true }
      return false
    }
  }

  public struct HardSafetyObservation: Sendable {
    public let protectiveCommandFingerprint: UInt64
    public let protectiveOutputFingerprint: UInt64
    public let interruptMask: UInt64
    public let learnedDescendingPeak: Float
    public let protectiveBypass: Bool
    public let safetyViolation: Bool
  }

  public struct LongHorizonRootContext: Sendable {
    public let protocolArtifactSHA256: String
    public let cohort: UInt32
    public let phase: BrainPolicyNumanXLongHorizonPhase

    public init(
      protocolArtifactSHA256: String,
      cohort: UInt32,
      phase: BrainPolicyNumanXLongHorizonPhase
    ) throws {
      guard BrainPolicyEvidenceArtifact.isSHA256(protocolArtifactSHA256),
        phase == .warmup ? cohort == 0 : cohort > 0
      else {
        throw TissueError.transaction(
          "Gate C long-horizon root context is invalid"
        )
      }
      self.protocolArtifactSHA256 = protocolArtifactSHA256
      self.cohort = cohort
      self.phase = phase
    }
  }

  public struct RootResult: Sendable {
    public let sample: MetalNumanXCapturedRootSample
    public let execution: BrainPolicyNumanXRootExecution
    public let executionArtifactSHA256: String
    /// Scalar publication generations visible after this root. The runner
    /// retains only its latest full native aggregate; completed evidence must
    /// not keep every prior HumanIO buffer slot alive across a long cohort.
    public let aggregate: PublishedGenerations?
    public let inferenceLatencyMicroseconds: Double
    public let brainPreflightReady: Bool
    public let proposalCode: UInt32
    public let appliedCode: UInt32
    public let nativePhysicalDiagnosticStage: UInt32
    public let uncertainty: MetalNumanXDecisionUncertaintyObservation?
    public let oodReferenceClass: UInt32?
    public let hardSafety: HardSafetyObservation?
    public let memoryBeforeLearningBatchArtifactSHA256: String
    public let memoryAfterLearningBatchArtifactSHA256: String
    public let motorActionArtifactSHA256: String
    public let longHorizonContext: LongHorizonRootContext?
    public let externalGoalArtifactSHA256: String?
  }

  public struct PublishedGenerations: Sendable {
    public let publicationEpoch: UInt64
    public let brainGeneration: UInt64
    public let physicsGeneration: UInt64
    public let sensorGeneration: UInt64

    init(_ snapshot: MetalNumanXBridgeV1Runtime.AggregateSnapshot) {
      publicationEpoch = snapshot.publicationEpoch
      brainGeneration = snapshot.brainGeneration
      physicsGeneration = snapshot.physicsGeneration
      sensorGeneration = snapshot.sensorGeneration
    }
  }

  public let compiledSpeciesTemplate: CompiledSpeciesTemplate
  public let artifactDirectory: URL
  public let episodeIdentifier: UInt64
  public let nativeInfo: MetalNumanXBridgeV1Runtime.Info
  public let parameterVersionFingerprint: UInt64
  public let declaredMaximumInferenceLatencyMicroseconds: UInt64?

  private let device: any MTLDevice
  private let brain: MetalNumiBrainRuntime
  private let native: MetalNumanXBridgeV1Runtime
  private let timestepMicroseconds: UInt64
  private let productionUncertaintyGateEnabled: Bool
  private let lock = NSLock()
  private var aggregate: MetalNumanXBridgeV1Runtime.AggregateSnapshot?
  private var committedTimestampMicroseconds: UInt64
  private var previousSettledSensorSnapshot:
    [MetalNumanXGateCCapture.SettledSensorChannel]?

  public init(
    libraryPath: String,
    bridgeConfiguration: MetalNumanXBridgeV1Runtime.Configuration,
    publication: BrainParameterPublication,
    artifactDirectory: URL,
    episodeIdentifier: UInt64,
    randomSeed: UInt64,
    declaredMaximumInferenceLatencyMicroseconds: UInt64? = nil,
    enableProductionUncertaintyGate: Bool = false,
    device: any MTLDevice
  ) throws {
    guard episodeIdentifier > 0, randomSeed > 0,
      declaredMaximumInferenceLatencyMicroseconds == nil
        || declaredMaximumInferenceLatencyMicroseconds! > 0,
      let timestepMicroseconds = UInt32(exactly:
        bridgeConfiguration.timestepMicroseconds
      ),
      let randomSeed32 = UInt32(exactly: randomSeed),
      let episodeIdentifier32 = UInt32(exactly: episodeIdentifier),
      device.makeMTL4CommandQueue() != nil,
      device.makeCommandAllocator() != nil,
      device.makeCommandBuffer() != nil
    else {
      throw TissueError.metal(
        "Gate C runner requires Metal 4 and nonzero run identity"
      )
    }
    let native = try MetalNumanXBridgeV1Runtime(
      libraryPath: libraryPath,
      device: device,
      configuration: bridgeConfiguration
    )
    guard native.info.bodyCount == 157,
      native.info.qCoordinateCount == 129,
      native.info.dofCount == 128,
      native.info.muscleCount == NumanXFullBodyTransportTemplate.actuatorCount
    else {
      throw TissueError.metal("Gate C native full-body shape is invalid")
    }
    let anatomy = try native.fullBodyAnatomy()
    let compiled = try NumanXFullBodyTransportTemplate.compile(
      latencyMicroseconds: timestepMicroseconds,
      anatomy: anatomy
    )
    let parameters = TissueParameters.corticalSheetV0
    let brain = try MetalNumiBrainRuntime.makeRuntime(
      configuration: MetalNumiBrainConfiguration(
        initialTissueState: try CPUTissueDynamics.makeRestingGrid(
          width: 8,
          height: 8,
          parameters: parameters
        ),
        tissueParameters: parameters,
        tissueStimulus: .none,
        compiledSpeciesTemplate: compiled,
        randomContext: TissueRandomContext(
          seed: randomSeed32,
          environmentIdentifier: 0,
          episodeIdentifier: episodeIdentifier32
        ),
        schedulerEnvironmentIdentifier: 0,
        maximumEncodedSubsteps: 1
      ),
      publication: publication,
      numanXUncertaintyGate: enableProductionUncertaintyGate
        ? MetalNumanXUncertaintyGateConfiguration() : nil,
      device: device
    )
    self.device = device
    self.compiledSpeciesTemplate = compiled
    self.artifactDirectory = artifactDirectory
    self.episodeIdentifier = episodeIdentifier
    self.brain = brain
    self.native = native
    self.nativeInfo = native.info
    self.parameterVersionFingerprint = brain.parameterVersionFingerprint
    self.declaredMaximumInferenceLatencyMicroseconds =
      declaredMaximumInferenceLatencyMicroseconds
    self.timestepMicroseconds = UInt64(timestepMicroseconds)
    self.productionUncertaintyGateEnabled = enableProductionUncertaintyGate
    self.committedTimestampMicroseconds = UInt64(timestepMicroseconds)
  }

  public func writeCaptureRunArtifact(
    runIdentifier: String,
    sourceRevision: String,
    roots: [RootResult],
    learningBatch: MetalNumanXCapturedLearningBatch
  ) throws -> String {
    guard let first = roots.first else {
      throw TissueError.transaction("Gate C capture run has no roots")
    }
    let sourceIdentifier = first.sample.artifact.coordinates
      .datasetSourceIdentifier
    let sourceDatasetRevision = first.sample.artifact.coordinates
      .datasetSourceRevision
    guard roots.allSatisfy({
      $0.sample.artifact.coordinates.datasetSourceIdentifier == sourceIdentifier
        && $0.sample.artifact.coordinates.datasetSourceRevision
          == sourceDatasetRevision
        && $0.sample.artifact.coordinates.episodeIdentifier
          == episodeIdentifier
    }) else {
      throw TissueError.transaction(
        "Gate C capture roots do not share one dataset source and episode"
      )
    }
    let artifact = try BrainPolicyNumanXCaptureRunArtifact(
      runIdentifier: runIdentifier,
      sourceRevision: sourceRevision,
      datasetSourceIdentifier: sourceIdentifier,
      datasetSourceRevision: sourceDatasetRevision,
      deviceRegistryID: device.registryID,
      nativeModelSourceFingerprint: nativeInfo.modelSourceFingerprint,
      acceptedStateProofProgramFingerprint:
        nativeInfo.acceptedStateProofProgramFingerprint,
      compiledSpeciesTemplateFingerprint: compiledSpeciesTemplate.fingerprint,
      parameterVersionFingerprint: parameterVersionFingerprint,
      timestepMicroseconds: UInt32(timestepMicroseconds),
      declaredMaximumInferenceLatencyMicroseconds:
        declaredMaximumInferenceLatencyMicroseconds,
      learningBatchArtifactSHA256: learningBatch.artifactSHA256,
      learningBatchFingerprint: learningBatch.batch.batchFingerprint,
      roots: try roots.map {
        try BrainPolicyNumanXCaptureRootReference(
          controlStep: $0.execution.controlStep,
          sampleSHA256: $0.sample.sampleSHA256,
          executionSHA256: $0.executionArtifactSHA256,
          inferenceLatencyMicroseconds: $0.inferenceLatencyMicroseconds,
          oodReferenceClass: $0.oodReferenceClass,
          uncertaintyScore: $0.uncertainty.map { Double($0.score) },
          supervisionRequired: $0.uncertainty?.supervisionRequired,
          uncertaintyRootRejected: $0.uncertainty?.rootRejected,
          hardSafetyChallenge: $0.hardSafety.map { _ in true },
          protectiveCommandFingerprint:
            $0.hardSafety?.protectiveCommandFingerprint,
          protectiveOutputFingerprint:
            $0.hardSafety?.protectiveOutputFingerprint,
          protectiveInterruptMask: $0.hardSafety?.interruptMask,
          learnedDescendingPeak:
            $0.hardSafety.map { Double($0.learnedDescendingPeak) },
          protectiveBypass: $0.hardSafety?.protectiveBypass,
          safetyViolation: $0.hardSafety?.safetyViolation,
          memoryBeforeLearningBatchArtifactSHA256:
            $0.memoryBeforeLearningBatchArtifactSHA256,
          memoryAfterLearningBatchArtifactSHA256:
            $0.memoryAfterLearningBatchArtifactSHA256,
          motorActionArtifactSHA256: $0.motorActionArtifactSHA256,
          longHorizonProtocolArtifactSHA256:
            $0.longHorizonContext?.protocolArtifactSHA256,
          longHorizonCohort: $0.longHorizonContext?.cohort,
          longHorizonPhase: $0.longHorizonContext?.phase,
          externalGoalArtifactSHA256: $0.externalGoalArtifactSHA256
        )
      }
    )
    return try artifact.write(to: artifactDirectory)
  }

  /// Freezes the exact committed memory sections after the requested roots.
  /// MLX may retain this immutable batch while future rollouts use a different
  /// runtime; it never aliases mutable active state.
  public func makeLearningBatch() throws -> MetalLearningBatch {
    lock.lock()
    defer { lock.unlock() }
    return try brain.makeLearningBatch()
  }

  public func captureLearningBatch() throws -> MetalNumanXCapturedLearningBatch {
    try MetalNumanXGateCCapture.writeLearningBatch(
      makeLearningBatch(),
      artifactDirectory: artifactDirectory
    )
  }

  public func runAcceptedRoot(
    controlStep: UInt32,
    coordinates: BrainPolicyNumanXDatasetCoordinates,
    externalGoal: ActiveGoal? = nil,
    activeSensingCommandScale: Float = 1
  ) throws -> RootResult {
    let result = try runRoot(
      controlStep: controlStep,
      coordinates: coordinates,
      externalGoal: externalGoal,
      activeSensingCommandScale: activeSensingCommandScale
    )
    guard result.execution.outcome == .accepted else {
      throw TissueError.transaction(
        "Gate C accept-only capture observed an authoritative rejected root "
          + "at control step \(controlStep) "
          + "(proposal \(result.proposalCode), applied \(result.appliedCode), "
          + "native stage \(result.nativePhysicalDiagnosticStage))"
      )
    }
    return result
  }

  /// Runs one complete owner/Brain transaction and retains either exact
  /// accepted publication or exact restored rejection. Rejection never
  /// advances the aggregate generations and remains a metric failure, but it
  /// is valid authoritative evidence rather than an exception.
  public func runRoot(
    controlStep: UInt32,
    coordinates: BrainPolicyNumanXDatasetCoordinates,
    externalGoal: ActiveGoal? = nil,
    externalGoalProvider: ((BrainTimestamp, BrainTimestamp) throws
      -> ActiveGoal)? = nil,
    activeSensingCommandScale: Float = 1,
    sensorIntervention: SensorIntervention = .none,
    hardSafetyIntervention: HardSafetyIntervention = .none,
    longHorizonContext: LongHorizonRootContext? = nil
  ) throws -> RootResult {
    lock.lock()
    defer { lock.unlock() }
    guard coordinates.episodeIdentifier == episodeIdentifier,
      coordinates.datasetSourceIdentifier.isEmpty == false,
      controlStep > 0, activeSensingCommandScale.isFinite,
      activeSensingCommandScale >= 0,
      activeSensingCommandScale <= 1,
      externalGoal == nil || externalGoalProvider == nil
    else {
      throw TissueError.transaction("Gate C root coordinates are invalid")
    }
    let committedMicros = committedTimestampMicroseconds
    let memoryBefore = try MetalNumanXGateCCapture.writeLearningBatch(
      brain.makeLearningBatch(),
      artifactDirectory: artifactDirectory
    )
    let oodReferenceClass: UInt32? = productionUncertaintyGateEnabled
      ? (sensorIntervention.isOOD ? 1 : 0) : nil
    let (targetMicros, timestampOverflow) = committedMicros
      .addingReportingOverflow(timestepMicroseconds)
    guard !timestampOverflow else {
      throw TissueError.transaction("Gate C root timestamp overflowed")
    }
    let committedTimestamp = BrainTimestamp(microseconds: committedMicros)
    let targetTimestamp = BrainTimestamp(microseconds: targetMicros)
    let resolvedExternalGoal: ActiveGoal?
    let externalGoalArtifactSHA256: String?
    resolvedExternalGoal = try externalGoalProvider?(
      committedTimestamp,
      targetTimestamp
    ) ?? externalGoal
    externalGoalArtifactSHA256 = if let resolvedExternalGoal {
      try BrainPolicyNumanXActiveGoalArtifact(goal: resolvedExternalGoal)
        .write(to: artifactDirectory)
    } else {
      nil
    }
    let transaction = try brain.beginControl(
      controlStepIdentifier: UInt64(controlStep),
      basePhysicsGeneration: aggregate?.physicsGeneration ?? 0,
      committedTimestamp: committedTimestamp,
      targetTimestamp: targetTimestamp,
      cachedDecisionFingerprint: 0x4e58_4743_0000_0000 | UInt64(controlStep)
    )
    var physical: MetalNumanXBridgeV1PreparedRoot?
    var prepared: MetalNumiBrainRuntime.NumanXPreparedControlTicket?
    do {
      let settledSensors = if let aggregate {
        try aggregate.sensorPacket(
          for: transaction.token,
          compiledSpeciesTemplate: compiledSpeciesTemplate
        )
      } else {
        try Self.bootstrapSensorPacket(
          device: device,
          compiled: compiledSpeciesTemplate,
          transaction: transaction.token
        )
      }
      let sensors = try intervenedSensors(
        settledSensors,
        transaction: transaction.token,
        intervention: sensorIntervention
      )
      let capturedSample = try MetalNumanXGateCCapture.writeSettledRootSample(
        transaction: transaction.token,
        sensors: sensors,
        coordinates: coordinates,
        artifactDirectory: artifactDirectory
      )
      let decision = try brain.submitInferAndDecide(
        transaction,
        numanXSensors: sensors,
        externalGoal: resolvedExternalGoal,
        activeSensingCommandScale: activeSensingCommandScale,
        signal: try Self.point(device)
      )
      let hardSafetyEvents = try Self.hardSafetyEvents(
        hardSafetyIntervention,
        timestamp: committedTimestamp
      )
      let motor = try brain.submitNumanXMotorCandidate(
        decision,
        transaction: transaction,
        candidateDurationMicroseconds: timestepMicroseconds,
        qualificationInterruptEvents: hardSafetyEvents,
        signal: try Self.point(device)
      )
      let decisionFeedback = try decision.waitUntilCompleted(
        timeoutMilliseconds: 30_000
      )
      let uncertainty = productionUncertaintyGateEnabled
        ? try decision.uncertaintyObservationIfAvailable() : nil
      if uncertainty?.supervisionRequired == true {
        guard productionUncertaintyGateEnabled else {
          throw TissueError.transaction(
            "an unconfigured uncertainty policy rejected the decision"
          )
        }
        let settlement = try brain.finishNumanXPolicyRejectedMotorSubmission(
          motor,
          transaction: transaction,
          timeoutMilliseconds: 30_000
        )
        guard settlement.uncertainty == uncertainty else {
          throw TissueError.transaction(
            "uncertainty evidence changed across motor settlement"
          )
        }
      } else {
        _ = try brain.finishNumanXMotorSubmission(
          motor,
          transaction: transaction,
          timeoutMilliseconds: 30_000
        )
      }
      let motorObservation = try brain.qualificationProtectiveObservation(
        motor,
        transaction: transaction
      )
      let hardSafety = hardSafetyIntervention.isChallenge
        ? Self.hardSafetyObservation(motorObservation) : nil
      let motorActionArtifactSHA256 = try BrainPolicyNumanXMotorActionArtifact(
        controlStep: controlStep,
        protectiveFlags: motorObservation.output.flags.rawValue,
        protectiveInterruptMask: motorObservation.command.interruptMask.rawValue,
        motorInhibition: motorObservation.output.motorInhibition,
        autonomicArousal: motorObservation.output.autonomicArousal,
        actuatorCommandKind: motorObservation.output.actuatorCommandKind.rawValue,
        learnedDescendingCommands: motorObservation.learnedDescendingCommands,
        actuatorCommands: motorObservation.output.muscleExcitations,
        autonomicCommands: motorObservation.autonomicCommands,
        activeSensingCommands: motorObservation.activeSensingCommands
      ).write(to: artifactDirectory)
      // Qualification settles the exact Brain gates before lending their
      // retained ranges to the native owner. The production bridge still
      // consumes the same GPU records and event and may never infer authority
      // from host feedback; this ordering merely prevents an offline evidence
      // run from racing its own completion-handler-produced liveness signal.
      let physicalLatch = MetalNumanXGateCResultLatch<
        MetalNumanXBridgeV1PreparedRoot
      >()
      try native.beginPhysicalRoot(transaction: transaction.token, motor: motor) {
        physicalLatch.complete($0)
      }
      let root = try physicalLatch.wait()
      physical = root
      guard
        decisionFeedback.gpuDurationSeconds.isFinite,
        decisionFeedback.gpuDurationSeconds > 0
      else {
        throw TissueError.metal(
          "Gate C cognitive decision lacks measured Metal feedback"
        )
      }
      let inferenceLatencyMicroseconds =
        decisionFeedback.gpuDurationSeconds * 1_000_000
      let fast = try brain.submitProvisionalAcceptedFastRoot(
        transaction,
        waitFor: root.physicalPreparedPoint,
        signal: try Self.point(device)
      )
      let ticket = try brain.submitNumanXPreparedControl(
        transaction,
        provisionalFast: fast,
        identity: root.identity,
        acceptedPhysicsGate: root.acceptedPhysicsGate,
        sensorCandidate: root.sensorCandidate,
        signal: try Self.point(device),
        thenSignal: try Self.point(device)
      )
      prepared = ticket
      _ = try ticket.waitUntilBrainPrepareCompleted(timeoutMilliseconds: 30_000)
      let preflightStatus = Self.waitForPreflight(ticket)
      guard preflightStatus == .numanXPreflightReady
        || preflightStatus == .numanXPreflightFailed
      else {
        throw TissueError.transaction("Gate C Brain preflight did not settle")
      }
      let proposalLatch = MetalNumanXGateCResultLatch<
        MetalNumanXHumanMatterProposalLease
      >()
      try root.submitProposal(brain: ticket) { proposalLatch.complete($0) }
      let proposal = try proposalLatch.wait()
      let proposalRecord = proposal.proposalBuffer.contents().advanced(
        by: proposal.proposalByteOffset
      ).load(as: NBNumanXHumanMatterProposalGPU.self)
      if uncertainty?.rootRejected == true {
        guard proposalRecord.status
            == UInt32(NB_NUMANX_HUMAN_MATTER_PROPOSAL_READY.rawValue),
          proposalRecord.decision
            == UInt32(NB_NUMANX_HUMAN_MATTER_ROOT_REJECT.rawValue),
          proposalRecord.code
            == UInt32(NB_NUMANX_HUMAN_MATTER_PROPOSAL_PHYSICAL_REJECT.rawValue)
        else {
          throw TissueError.transaction(
            "uncertainty-rejected motor authority produced owner proposal "
              + "status=\(proposalRecord.status) decision=\(proposalRecord.decision) "
              + "code=\(proposalRecord.code)"
          )
        }
      }
      let jointCommitFingerprint = preflightStatus == .numanXPreflightReady
        ? try brain.numanXPreparedJointCommitFingerprint(
          for: ticket,
          identity: root.identity
        ) : 0
      try root.reserveApplication(brain: ticket)
      let ack = try brain.submitNumanXBrainAck(
        ticket,
        proposal: proposal,
        signal: try Self.point(device)
      )
      let appliedLatch = MetalNumanXGateCResultLatch<
        MetalNumanXHumanMatterAppliedLease
      >()
      try root.submitApply(ack: ack) { appliedLatch.complete($0) }
      let applied = try appliedLatch.wait()
      let appliedRecord = applied.appliedBuffer.contents().advanced(
        by: applied.appliedByteOffset
      ).load(as: NBNumanXHumanMatterAppliedOutcomeGPU.self)
      let nativePhysicalDiagnosticStage = try native.currentInfo()
        .requestFailureStage
      guard applied.commandDisposition == .acceptedPendingPublication
        || applied.commandDisposition == .rejectedReleased
      else {
        throw TissueError.transaction(
          "Gate C root reached terminal-no-touch instead of a resolved outcome"
        )
      }
      let resolution = try root.makeResolution(
        proposal: proposal,
        applied: applied,
        jointCommitFingerprint: jointCommitFingerprint,
        brainGeneration: transaction.token.shadowGeneration
      )
      _ = try brain.validateNumanXAppliedRoot(
        ticket,
        ack: ack,
        applied: applied,
        resolution: resolution,
        signal: try Self.point(device)
      )
      let closeStatus = Self.waitForClose(ticket)
      let nextAggregate = try native.aggregateSnapshotIfAvailable()
      if applied.commandDisposition == .rejectedReleased {
        let stableAggregate = aggregate
        let aggregateUnchanged = if let stableAggregate {
          nextAggregate != nil
            && nextAggregate!.brainGeneration == stableAggregate.brainGeneration
            && nextAggregate!.physicsGeneration == stableAggregate.physicsGeneration
            && nextAggregate!.sensorGeneration == stableAggregate.sensorGeneration
        } else {
          nextAggregate == nil
        }
        guard closeStatus == .aborted, aggregateUnchanged
        else {
          throw TissueError.transaction(
            "Gate C rejected root did not restore one exact prior generation"
          )
        }
        let execution = try ticket.qualificationRootExecution(
          capturedSample: capturedSample
        )
        guard execution.outcome == .rejected else {
          throw TissueError.transaction(
            "Gate C restored root did not produce a rejected transcript"
          )
        }
        let executionHash = try execution.write(to: artifactDirectory)
        let memoryAfter = try MetalNumanXGateCCapture.writeLearningBatch(
          brain.makeLearningBatch(),
          artifactDirectory: artifactDirectory
        )
        guard memoryAfter.artifactSHA256 == memoryBefore.artifactSHA256 else {
          throw TissueError.transaction(
            "Gate C rejected root mutated committed long-horizon memory"
          )
        }
        aggregate = stableAggregate
        return RootResult(
          sample: capturedSample,
          execution: execution,
          executionArtifactSHA256: executionHash,
          aggregate: stableAggregate.map(PublishedGenerations.init),
          inferenceLatencyMicroseconds: inferenceLatencyMicroseconds,
          brainPreflightReady: preflightStatus == .numanXPreflightReady,
          proposalCode: proposalRecord.code,
          appliedCode: appliedRecord.code,
          nativePhysicalDiagnosticStage: nativePhysicalDiagnosticStage,
          uncertainty: uncertainty,
          oodReferenceClass: oodReferenceClass,
          hardSafety: hardSafety,
          memoryBeforeLearningBatchArtifactSHA256: memoryBefore.artifactSHA256,
          memoryAfterLearningBatchArtifactSHA256: memoryAfter.artifactSHA256,
          motorActionArtifactSHA256: motorActionArtifactSHA256,
          longHorizonContext: longHorizonContext,
          externalGoalArtifactSHA256: externalGoalArtifactSHA256
        )
      }
      let (nextPhysicsGeneration, physicsGenerationOverflow) = transaction.token
        .basePhysicsGeneration.addingReportingOverflow(1)
      guard closeStatus == .committed,
        let nextAggregate,
        nextAggregate.brainGeneration == transaction.token.shadowGeneration,
        !physicsGenerationOverflow,
        nextAggregate.physicsGeneration == nextPhysicsGeneration
      else {
        throw TissueError.transaction(
          "Gate C root did not publish one exact joint generation"
        )
      }
      let execution = try ticket.qualificationRootExecution(
        capturedSample: capturedSample
      )
      let executionHash = try execution.write(to: artifactDirectory)
      let memoryAfter = try MetalNumanXGateCCapture.writeLearningBatch(
        brain.makeLearningBatch(),
        artifactDirectory: artifactDirectory
      )
      committedTimestampMicroseconds = targetMicros
      aggregate = nextAggregate
      return RootResult(
        sample: capturedSample,
        execution: execution,
        executionArtifactSHA256: executionHash,
        aggregate: PublishedGenerations(nextAggregate),
        inferenceLatencyMicroseconds: inferenceLatencyMicroseconds,
        brainPreflightReady: preflightStatus == .numanXPreflightReady,
        proposalCode: proposalRecord.code,
        appliedCode: appliedRecord.code,
        nativePhysicalDiagnosticStage: nativePhysicalDiagnosticStage,
        uncertainty: uncertainty,
        oodReferenceClass: oodReferenceClass,
        hardSafety: hardSafety,
        memoryBeforeLearningBatchArtifactSHA256: memoryBefore.artifactSHA256,
        memoryAfterLearningBatchArtifactSHA256: memoryAfter.artifactSHA256,
        motorActionArtifactSHA256: motorActionArtifactSHA256,
        longHorizonContext: longHorizonContext,
        externalGoalArtifactSHA256: externalGoalArtifactSHA256
      )
    } catch {
      if let physical, let prepared {
        _ = physical.quarantineTimeout()
        try? Self.forceReject(
          physical: physical,
          prepared: prepared,
          brain: brain
        )
      } else if physical == nil {
        try? brain.abortControl(transaction)
      }
      throw error
    }
  }

  private static func hardSafetyEvents(
    _ intervention: HardSafetyIntervention,
    timestamp: BrainTimestamp
  ) throws -> [BrainInterruptEvent] {
    guard case .emergencyStop = intervention else { return [] }
    return [try BrainInterruptEvent(
      timestamp: timestamp,
      mask: [.pain, .damagingContact, .impact],
      identifier: 0x4743_0001,
      magnitude: 1
    )]
  }

  private static func hardSafetyObservation(
    _ source: MetalTissueRuntime.NumanXProtectiveQualificationObservation
  ) -> HardSafetyObservation {
    let command = source.command
    let output = source.output
    let expectedMask: BrainInterruptMask = [.pain, .damagingContact, .impact]
    let emergencyOutputs = output.muscleExcitations.allSatisfy { $0 == 0 }
    let enforced = command.flags.contains(.emergencyStop)
      && command.interruptMask.isSuperset(of: expectedMask)
      && command.motorInhibition == 1
      && output.flags.contains(.emergencyStop)
      && output.motorInhibition == 1
      && output.protectiveCommandFingerprint == command.fingerprint
      && emergencyOutputs
    return HardSafetyObservation(
      protectiveCommandFingerprint: command.fingerprint,
      protectiveOutputFingerprint: output.fingerprint,
      interruptMask: command.interruptMask.rawValue,
      learnedDescendingPeak: source.learnedDescendingPeak,
      protectiveBypass: !enforced,
      safetyViolation: !enforced
    )
  }

  private static func forceReject(
    physical: MetalNumanXBridgeV1PreparedRoot,
    prepared: MetalNumiBrainRuntime.NumanXPreparedControlTicket,
    brain: MetalNumiBrainRuntime
  ) throws {
    let proposalLatch = MetalNumanXGateCResultLatch<
      MetalNumanXHumanMatterProposalLease
    >()
    try physical.submitTimeoutRejectProposal { proposalLatch.complete($0) }
    _ = try proposalLatch.wait()
    try physical.reserveTimeoutRejectApplication(brain: prepared)
    let appliedLatch = MetalNumanXGateCResultLatch<
      MetalNumanXHumanMatterAppliedLease
    >()
    try physical.submitTimeoutRejectApply { appliedLatch.complete($0) }
    guard try appliedLatch.wait().commandDisposition == .rejectedReleased,
      physical.releaseRejected()
    else {
      throw TissueError.transaction("Gate C forced reject did not restore root")
    }
    try brain.abortNumanXPreparedControl(prepared)
  }

  private static func point(_ device: any MTLDevice) throws
    -> MetalSharedEventPoint
  {
    guard let event = device.makeSharedEvent() else {
      throw TissueError.metal("failed to allocate Gate C shared event")
    }
    return try MetalSharedEventPoint(event: event, value: 1)
  }

  private static func bootstrapSensorPacket(
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
        throw TissueError.metal("failed to allocate Gate C bootstrap sensors")
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

  private func intervenedSensors(
    _ source: NumanXSensorPacketLease,
    transaction: BrainJointTransactionToken,
    intervention: SensorIntervention
  ) throws -> NumanXSensorPacketLease {
    if case .none = intervention {
      previousSettledSensorSnapshot = try MetalNumanXGateCCapture
        .settledSensorSnapshot(source)
      return source
    }
    if case .replayPreviousSettledObservation = intervention {
      guard let snapshot = previousSettledSensorSnapshot,
        snapshot.count == compiledSpeciesTemplate.species.senses
          .filter(\.enabled).count
      else {
        throw TissueError.transaction(
          "Gate C observational alias has no prior settled packet"
        )
      }
      let topology = Dictionary(uniqueKeysWithValues:
        compiledSpeciesTemplate.species.senses.filter(\.enabled).map {
          ($0.modality, $0)
        }
      )
      let rawSensors = try snapshot.map { channel in
        guard let sense = topology[channel.modality],
          channel.receptorCount == sense.receptorCount,
          channel.featureDimension == sense.observationDimension,
          transaction.committedTimestamp.rawValue
            >= UInt64(sense.latencyMicroseconds),
          let values = device.makeBuffer(
            length: channel.values.count,
            options: [.storageModeShared, .hazardTrackingModeTracked]
          )
        else {
          throw TissueError.transaction(
            "Gate C observational alias shape or timestamp is invalid"
          )
        }
        channel.values.copyBytes(
          to: values.contents().assumingMemoryBound(to: UInt8.self),
          count: channel.values.count
        )
        let validity: (any MTLBuffer)? = try channel.validity.map { bytes in
          guard let buffer = device.makeBuffer(
            length: bytes.count,
            options: [.storageModeShared, .hazardTrackingModeTracked]
          ) else {
            throw TissueError.metal(
              "failed to allocate Gate C aliased sensor validity"
            )
          }
          bytes.copyBytes(
            to: buffer.contents().assumingMemoryBound(to: UInt8.self),
            count: bytes.count
          )
          return buffer
        }
        return try MetalRawSensorBufferLease(
          buffer: values,
          modality: channel.modality,
          receptorTimestamp: BrainTimestamp(
            microseconds: transaction.committedTimestamp.rawValue
              - UInt64(sense.latencyMicroseconds)
          ),
          receptorCount: channel.receptorCount,
          featureDimension: channel.featureDimension,
          validityBuffer: validity
        )
      }
      return try NumanXSensorPacketLease(
        transaction: transaction,
        compiledSpeciesTemplate: compiledSpeciesTemplate,
        rawSensors: rawSensors
      )
    }
    let rawSensors = try source.rawSensors.map { sensor in
      let view = sensor.view
      let values = try copiedBuffer(sensor.buffer)
      guard let validity = device.makeBuffer(
        length: Int(view.receptorCount) * MemoryLayout<UInt32>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ) else {
        throw TissueError.metal(
          "failed to allocate Gate C OOD validity intervention"
        )
      }
      validity.contents().initializeMemory(
        as: UInt8.self, repeating: 0, count: validity.length
      )
      return try MetalRawSensorBufferLease(
        buffer: values,
        modality: view.modality,
        receptorTimestamp: view.receptorTimestamp,
        receptorCount: view.receptorCount,
        featureDimension: view.featureDimension,
        validityBuffer: validity
      )
    }
    return try NumanXSensorPacketLease(
      transaction: transaction,
      compiledSpeciesTemplate: compiledSpeciesTemplate,
      rawSensors: rawSensors
    )
  }

  private func copiedBuffer(_ source: any MTLBuffer) throws -> any MTLBuffer {
    guard let destination = device.makeBuffer(
      length: source.length,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ) else {
      throw TissueError.metal("failed to allocate Gate C sensor intervention")
    }
    if source.storageMode == .shared {
      destination.contents().copyMemory(
        from: source.contents(), byteCount: source.length
      )
      return destination
    }
    guard let queue = device.makeCommandQueue(),
      let commandBuffer = queue.makeCommandBuffer(),
      let blit = commandBuffer.makeBlitCommandEncoder()
    else {
      throw TissueError.metal("failed to allocate Gate C sensor-copy blit")
    }
    blit.copy(
      from: source,
      sourceOffset: 0,
      to: destination,
      destinationOffset: 0,
      size: source.length
    )
    blit.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    guard commandBuffer.status == .completed else {
      throw TissueError.metal("Gate C sensor-copy blit failed")
    }
    return destination
  }

  private static func waitForPreflight(
    _ ticket: MetalNumiBrainRuntime.NumanXPreparedControlTicket
  ) -> MetalNumiBrainRuntime.ControlTransaction.Status {
    let deadline = Date(timeIntervalSinceNow: 30)
    var status = ticket.status
    while status == .numanXPrepareSubmitted, Date() < deadline {
      Thread.sleep(forTimeInterval: 0.001)
      status = ticket.status
    }
    return status
  }

  private static func waitForClose(
    _ ticket: MetalNumiBrainRuntime.NumanXPreparedControlTicket
  ) -> MetalNumiBrainRuntime.ControlTransaction.Status {
    let deadline = Date(timeIntervalSinceNow: 30)
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
private final class MetalNumanXGateCResultLatch<Value: Sendable>:
  @unchecked Sendable
{
  private let condition = NSCondition()
  private var result: Result<Value, Error>?

  func complete(_ result: Result<Value, Error>) {
    condition.lock()
    guard self.result == nil else {
      condition.unlock()
      return
    }
    self.result = result
    condition.broadcast()
    condition.unlock()
  }

  func wait(timeout: TimeInterval = 30) throws -> Value {
    condition.lock()
    defer { condition.unlock() }
    let deadline = Date(timeIntervalSinceNow: timeout)
    while result == nil, condition.wait(until: deadline) {}
    guard let result else {
      throw TissueError.transaction(
        "Gate C native callback did not settle before timeout"
      )
    }
    return try result.get()
  }
}

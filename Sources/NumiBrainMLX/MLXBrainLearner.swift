import Foundation
import MLX
import NumiBrainCore
import NumiBrainMetal

@frozen
public struct MLXBrainLearnerConfiguration: Equatable, Sendable {
  public let learningRate: Float
  public let gradientNormLimit: Float
  public let parameterMagnitudeLimit: Float
  public let lossWeights: [BrainSlowLossKind: Float]
  public let delayedSupportObjectiveWeight: Float
  public let headPostureObjectiveWeight: Float

  public init(
    learningRate: Float,
    gradientNormLimit: Float,
    parameterMagnitudeLimit: Float,
    lossWeights: [BrainSlowLossKind: Float],
    delayedSupportObjectiveWeight: Float = 0,
    headPostureObjectiveWeight: Float = 0
  ) throws {
    guard learningRate.isFinite, learningRate > 0,
      gradientNormLimit.isFinite, gradientNormLimit > 0,
      parameterMagnitudeLimit.isFinite, parameterMagnitudeLimit > 0,
      delayedSupportObjectiveWeight.isFinite,
      delayedSupportObjectiveWeight >= 0,
      headPostureObjectiveWeight.isFinite,
      headPostureObjectiveWeight >= 0,
      delayedSupportObjectiveWeight == 0 || headPostureObjectiveWeight == 0,
      Set(lossWeights.keys) == Set(BrainSlowLossKind.allCases),
      lossWeights.values.allSatisfy({ $0.isFinite && $0 >= 0 })
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX learner configuration is invalid"
      )
    }
    self.learningRate = learningRate
    self.gradientNormLimit = gradientNormLimit
    self.parameterMagnitudeLimit = parameterMagnitudeLimit
    self.lossWeights = lossWeights
    self.delayedSupportObjectiveWeight = delayedSupportObjectiveWeight
    self.headPostureObjectiveWeight = headPostureObjectiveWeight
  }

  public static var foundationV1: Self {
    var weights = Dictionary(
      uniqueKeysWithValues: BrainSlowLossKind.allCases.map { ($0, Float(1)) }
    )
    weights[.imitation] = 0.25
    weights[.sparsity] = 0.001
    weights[.stability] = 0.01
    return try! Self(
      learningRate: 0.0001,
      gradientNormLimit: 1,
      parameterMagnitudeLimit: 4,
      lossWeights: weights,
      delayedSupportObjectiveWeight: 0,
      headPostureObjectiveWeight: 0
    )
  }
}

@available(macOS 26.0, *)
private struct MLXPreparedMindLearningBatch {
  let transitions: MLXCommittedTransitionBatch
  let sequences: MLXCommittedSequenceBatch
  let replay: MLXReplayLearningBatch
  let counterfactuals: MLXCounterfactualLearningBatch
  let semantics: MLXSemanticLearningBatch
  let regional: MLXRegionalLearningBatch

  init(_ source: MetalLearningBatch) throws {
    let transitions = try MLXCommittedTransitionBatch(source)
    self.transitions = transitions
    self.sequences = try MLXCommittedSequenceBatch(transitions)
    self.replay = try MLXReplayLearningBatch(source)
    self.counterfactuals = try MLXCounterfactualLearningBatch(source)
    self.semantics = try MLXSemanticLearningBatch(source)
    self.regional = try MLXRegionalLearningBatch(source)
  }
}

/// MLX owns this off-rollout update. It consumes an immutable committed batch,
/// differentiates all twenty specified objectives, and emits exact successor
/// bytes; it never advances physics or mutates an active Metal parameter bank.
@available(macOS 26.0, *)
public final class MLXBrainLearner: @unchecked Sendable {
  public let configuration: MLXBrainLearnerConfiguration

  public init(configuration: MLXBrainLearnerConfiguration = .foundationV1) {
    self.configuration = configuration
  }

  public func update(
    parentPublication: BrainParameterPublication,
    batch: MetalLearningBatch,
    delayedSupport: BrainPolicyNumanXDelayedSupportLearningArtifact? = nil,
    headPosture: BrainPolicyNumanXHeadPostureLearningArtifact? = nil
  ) throws -> BrainLearnerUpdate {
    try update(
      parentVersion: parentPublication.version,
      parentArtifact: parentPublication.sharedArtifact,
      batch: batch,
      delayedSupport: delayedSupport,
      headPosture: headPosture
    )
  }

  /// Applies one shared slow-weight update from several independent immutable
  /// minds. Every objective is reduced inside its owning mind first and then
  /// averaged equally across minds, so a larger episodic archive cannot give
  /// one agent disproportionate control of the shared parameter version.
  public func update(
    parentPublication: BrainParameterPublication,
    cohort: MetalLearningCohortBatch
  ) throws -> BrainLearnerUpdate {
    try update(
      parentVersion: parentPublication.version,
      parentArtifact: parentPublication.sharedArtifact,
      cohort: cohort
    )
  }

  public func update(
    parentVersion: BrainParameterVersion,
    parentArtifact: BrainSharedParameterArtifact,
    batch sourceBatch: MetalLearningBatch,
    delayedSupport: BrainPolicyNumanXDelayedSupportLearningArtifact? = nil,
    headPosture: BrainPolicyNumanXHeadPostureLearningArtifact? = nil
  ) throws -> BrainLearnerUpdate {
    guard sourceBatch.parameterVersionFingerprint == parentVersion.fingerprint,
      sourceBatch.regionalProgramFingerprint
        == parentVersion.regionalProgramFingerprint,
      sourceBatch.scheduleFingerprint == parentVersion.scheduleFingerprint,
      parentArtifact.parameterVersionFingerprint == parentVersion.fingerprint
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX learner inputs do not share one immutable parent version"
      )
    }
    guard delayedSupport == nil || headPosture == nil else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX update accepts only one physical objective"
      )
    }
    if let delayedSupport {
      try delayedSupport.validate()
      guard configuration.delayedSupportObjectiveWeight > 0,
        delayedSupport.objectiveWeight
          == configuration.delayedSupportObjectiveWeight
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "MLX delayed-support objective does not match its configuration"
        )
      }
    } else if configuration.delayedSupportObjectiveWeight > 0 {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX delayed-support configuration has no physical objective"
      )
    }
    if let headPosture {
      try headPosture.validate()
      guard configuration.headPostureObjectiveWeight > 0,
        headPosture.objectiveWeight
          == configuration.headPostureObjectiveWeight
      else {
        throw BrainRuntimeError.invalidParameterVersion(
          "MLX head-posture objective does not match its configuration"
        )
      }
    } else if configuration.headPostureObjectiveWeight > 0 {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX head-posture configuration has no physical objective"
      )
    }
    return try update(
      parentVersion: parentVersion,
      parentArtifact: parentArtifact,
      sourceBatchFingerprint: sourceBatch.batchFingerprint,
      sourceBatches: [sourceBatch],
      delayedSupport: delayedSupport,
      headPosture: headPosture
    )
  }

  public func update(
    parentVersion: BrainParameterVersion,
    parentArtifact: BrainSharedParameterArtifact,
    cohort: MetalLearningCohortBatch
  ) throws -> BrainLearnerUpdate {
    guard cohort.formatVersion == MetalLearningCohortBatch.formatVersion,
      cohort.parameterVersionFingerprint == parentVersion.fingerprint,
      cohort.regionalProgramFingerprint == parentVersion.regionalProgramFingerprint,
      cohort.scheduleFingerprint == parentVersion.scheduleFingerprint,
      parentArtifact.parameterVersionFingerprint == parentVersion.fingerprint
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX learner cohort does not share one immutable parent version"
      )
    }
    return try update(
      parentVersion: parentVersion,
      parentArtifact: parentArtifact,
      sourceBatchFingerprint: cohort.cohortFingerprint,
      sourceBatches: cohort.members.map(\.batch),
      delayedSupport: nil,
      headPosture: nil
    )
  }

  private func update(
    parentVersion: BrainParameterVersion,
    parentArtifact: BrainSharedParameterArtifact,
    sourceBatchFingerprint: UInt64,
    sourceBatches: [MetalLearningBatch],
    delayedSupport: BrainPolicyNumanXDelayedSupportLearningArtifact?,
    headPosture: BrainPolicyNumanXHeadPostureLearningArtifact?
  ) throws -> BrainLearnerUpdate {
    guard !sourceBatches.isEmpty,
      let sourceMindCount = UInt32(exactly: sourceBatches.count),
      let minimumSourceGeneration = sourceBatches.map(\.sourceGeneration).min(),
      let sourceGeneration = sourceBatches.map(\.sourceGeneration).max()
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX learner requires at least one committed mind"
      )
    }
    guard minimumSourceGeneration > 0,
      (delayedSupport != nil) == (configuration.delayedSupportObjectiveWeight > 0),
      (headPosture != nil) == (configuration.headPostureObjectiveWeight > 0)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX update requires committed experience and every configured physical objective"
      )
    }
    try parentArtifact.validate(parameterVersion: parentVersion)
    let preparedBatches = try sourceBatches.map(MLXPreparedMindLearningBatch.init)
    // One bounded synchronization at the immutable learning boundary. An empty
    // or wholly invalid mind must not publish a sparsity-only update or dilute
    // the equal-per-mind cohort objective.
    let validTransitionCounts = preparedBatches.map { $0.transitions.validMask.sum() }
    eval(validTransitionCounts)
    guard validTransitionCounts.allSatisfy({
      let count = $0.item(Float.self)
      return count.isFinite && count > 0
    }) else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX update contains a mind with no valid accepted transitions"
      )
    }
    let kinds = BrainSharedParameterArtifact.requiredKinds
    let parentParameters = kinds.map { kind -> MLXArray in
      let payload = parentArtifact.payload(kind)
      return MLXArray(
        payload.data,
        [payload.data.count / MemoryLayout<Float>.stride],
        type: Float.self
      )
    }
    let differentiated = valueAndGrad(
      { [configuration] parameters -> [MLXArray] in
        // Head-posture calibration is a causal intervention, not an ordinary
        // multi-objective successor update. Its physical response may
        // identify the sign of motor gains only when every other parameter is
        // held at the immutable parent. The owning loss touches exactly motor
        // parameters 3 and 4; MLX therefore emits zero gradients for every
        // other component and motor scalar. Full slow-loss terms are still
        // recomputed below for diagnostics, but cannot confound this probe.
        if let headPosture {
          return [
            configuration.headPostureObjectiveWeight
              * Self.headPostureLoss(
                parameters: parameters,
                artifact: headPosture
              ),
          ]
        }
        let terms = Self.cohortLossTerms(
          parameters: parameters,
          parentParameters: parentParameters,
          batches: preparedBatches,
          delayedSupport: delayedSupport,
          delayedSupportWeight: configuration.delayedSupportObjectiveWeight,
          headPosture: headPosture,
          headPostureWeight: configuration.headPostureObjectiveWeight
        )
        var total = MLXArray(Float(0))
        for (kind, term) in zip(BrainSlowLossKind.allCases, terms) {
          total = total + (configuration.lossWeights[kind] ?? 0) * term
        }
        return [total]
      },
      argumentNumbers: parentParameters.indices
    )
    let (_, gradients) = differentiated(parentParameters)
    guard gradients.count == parentParameters.count else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX learner did not differentiate every parameter component"
      )
    }
    let motorParameterIndex = kinds.firstIndex(of: .motor)!
    let effectiveGradients: [MLXArray]
    let motorMutationMask: MLXArray?
    if headPosture != nil {
      let motorElementCount = parentArtifact.payload(.motor).data.count
        / MemoryLayout<Float>.stride
      var motorMaskValues = [Float](repeating: 0, count: motorElementCount)
      for index in [3, 4] where index < motorMaskValues.count {
        motorMaskValues[index] = 1
      }
      let motorMask = MLXArray(motorMaskValues, [motorElementCount])
      motorMutationMask = motorMask
      effectiveGradients = gradients.enumerated().map { index, gradient in
        index == motorParameterIndex ? gradient * motorMask : gradient * Float(0)
      }
    } else {
      motorMutationMask = nil
      effectiveGradients = gradients
    }
    var squaredGradientNorm = MLXArray(Float(0))
    for gradient in effectiveGradients {
      squaredGradientNorm = squaredGradientNorm + square(gradient).sum()
    }
    let gradientNorm = sqrt(squaredGradientNorm + Float(1.0e-12))
    let gradientScale = minimum(
      MLXArray(Float(1)),
      configuration.gradientNormLimit / gradientNorm
    )
    // A one-step gradient evaluated exactly at the immutable parent has zero
    // derivative for ||theta-parent||^2. Apply the equivalent proximal pull to
    // the update delta so stability genuinely constrains every publication.
    let stabilityWeight = configuration.lossWeights[.stability] ?? 0
    let proximalRetention =
      Float(1) / (Float(1) + Float(2) * configuration.learningRate * stabilityWeight)
    let updatedParameters = zip(parentParameters, effectiveGradients)
      .enumerated().map { index, pair in
        let (parameter, gradient) = pair
        if headPosture != nil, index != motorParameterIndex {
          return parameter
        }
        return MLXImmutableParameterUpdate.project(
          parent: parameter,
          delta: proximalRetention * configuration.learningRate
            * gradientScale * gradient,
          magnitudeLimit: configuration.parameterMagnitudeLimit,
          mutableMask: index == motorParameterIndex ? motorMutationMask : nil
        )
    }
    let updatedTerms = Self.cohortLossTerms(
      parameters: updatedParameters,
      parentParameters: parentParameters,
      batches: preparedBatches,
      delayedSupport: delayedSupport,
      delayedSupportWeight: configuration.delayedSupportObjectiveWeight,
      headPosture: headPosture,
      headPostureWeight: configuration.headPostureObjectiveWeight
    )
    eval(updatedParameters + updatedTerms)
    let payloads = try zip(kinds, updatedParameters).map { kind, parameter in
      if headPosture != nil, kind != .motor {
        return parentArtifact.payload(kind)
      }
      return try BrainParameterPayload(
        kind: kind,
        elementType: .fp32,
        data: parameter.asData(access: .copy).data
      )
    }
    let successor = try BrainSharedParameterArtifact.successor(
      parentVersion: parentVersion,
      updatedPayloads: payloads
    )
    let losses = try zip(BrainSlowLossKind.allCases, updatedTerms).map { kind, term in
      try BrainSlowLossTerm(
        kind: kind,
        weight: configuration.lossWeights[kind] ?? 0,
        value: term.item(Float.self)
      )
    }
    return try BrainLearnerUpdate(
      parentVersion: parentVersion,
      sourceBatchFingerprint: sourceBatchFingerprint,
      sourceGeneration: sourceGeneration,
      sourceMindCount: sourceMindCount,
      minimumSourceGeneration: minimumSourceGeneration,
      candidateVersion: successor.version,
      sharedArtifact: successor.artifact,
      losses: losses
    )
  }

  private static func cohortLossTerms(
    parameters: [MLXArray],
    parentParameters: [MLXArray],
    batches: [MLXPreparedMindLearningBatch],
    delayedSupport: BrainPolicyNumanXDelayedSupportLearningArtifact?,
    delayedSupportWeight: Float,
    headPosture: BrainPolicyNumanXHeadPostureLearningArtifact?,
    headPostureWeight: Float
  ) -> [MLXArray] {
    precondition(!batches.isEmpty)
    var totals = lossTerms(
      parameters: parameters,
      parentParameters: parentParameters,
      batch: batches[0].transitions,
      sequences: batches[0].sequences,
      replay: batches[0].replay,
      counterfactuals: batches[0].counterfactuals,
      semantics: batches[0].semantics,
      regional: batches[0].regional
    )
    for batch in batches.dropFirst() {
      let terms = lossTerms(
        parameters: parameters,
        parentParameters: parentParameters,
        batch: batch.transitions,
        sequences: batch.sequences,
        replay: batch.replay,
        counterfactuals: batch.counterfactuals,
        semantics: batch.semantics,
        regional: batch.regional
      )
      for index in totals.indices {
        totals[index] = totals[index] + terms[index]
      }
    }
    let memberCount = Float(batches.count)
    totals = totals.map { $0 / memberCount }
    if let delayedSupport {
      totals[9] = totals[9] + delayedSupportWeight * delayedSupportLoss(
        parameters: parameters,
        artifact: delayedSupport
      )
    }
    if let headPosture {
      totals[9] = totals[9] + headPostureWeight * headPostureLoss(
        parameters: parameters,
        artifact: headPosture
      )
    }
    return totals
  }

  private static func headPostureLoss(
    parameters: [MLXArray],
    artifact: BrainPolicyNumanXHeadPostureLearningArtifact
  ) -> MLXArray {
    let motor = parameters[7]
    let demand = artifact.responseDeficit
    let direction = artifact.effectiveResponseGainDirection
    // DecisionState owns this task-space excitation path. The target-body
    // selector and learned anatomical effect choose muscles; these bounded
    // gains control position error and velocity error without
    // writing pose, force, or any authoritative physical state. The sign is
    // either the initial positive-gain probe or an exact, transitive physical
    // calibration; it is never inferred from task deficit alone.
    let positionTarget = Float(1) + direction * Float(2) * demand
    let velocityTarget = Float(1) + direction * Float(2) * demand
    return square(motor[3] - positionTarget)
      + square(motor[4] - velocityTarget)
  }

  private static func delayedSupportLoss(
    parameters: [MLXArray],
    artifact: BrainPolicyNumanXDelayedSupportLearningArtifact
  ) -> MLXArray {
    precondition(!artifact.examples.isEmpty)
    let demand = artifact.examples.map(\.stabilizationDemand)
      .reduce(Float(0), +) / Float(artifact.examples.count)
    let velocityDemand = artifact.examples.map {
      min(
        abs($0.consequenceGroundNormalVelocity)
          / artifact.thresholds.maximumAbsoluteGroundNormalVelocity,
        1
      )
    }.reduce(Float(0), +) / Float(artifact.examples.count)
    let clearanceSpan = artifact.thresholds.maximumHeadGroundClearance
      - artifact.thresholds.minimumHeadGroundClearance
    let clearanceDemand = artifact.examples.map { example -> Float in
      if example.consequenceHeadGroundClearance
          < artifact.thresholds.minimumHeadGroundClearance
      {
        return min(
          (artifact.thresholds.minimumHeadGroundClearance
            - example.consequenceHeadGroundClearance) / clearanceSpan,
          1
        )
      }
      if example.consequenceHeadGroundClearance
          > artifact.thresholds.maximumHeadGroundClearance
      {
        return min(
          (example.consequenceHeadGroundClearance
            - artifact.thresholds.maximumHeadGroundClearance) / clearanceSpan,
          1
        )
      }
      return 0
    }.reduce(Float(0), +) / Float(artifact.examples.count)
    let motor = parameters[7]
    // HumanIO v1 lends excitation, autonomic, and active-sensing commands to
    // physics. Stiffness/damping records remain Brain-private, so supervising
    // those values cannot change the physical consequence. These parameters
    // are the owning DecisionState.metal excitation path: [4] is anatomical
    // goal velocity feedback, [3] position feedback, and [0] overall motor
    // drive. Targets remain bounded by the learner's parameter limit.
    let velocityGainTarget = Float(1) + Float(2) * velocityDemand
    let positionGainTarget = Float(1) + clearanceDemand
    let motorGainTarget = Float(1) + Float(0.5) * demand
    return square(motor[4] - velocityGainTarget)
      + Float(0.5) * square(motor[3] - positionGainTarget)
      + Float(0.25) * square(motor[0] - motorGainTarget)
  }

  private static func lossTerms(
    parameters: [MLXArray],
    parentParameters: [MLXArray],
    batch: MLXCommittedTransitionBatch,
    sequences: MLXCommittedSequenceBatch,
    replay: MLXReplayLearningBatch,
    counterfactuals: MLXCounterfactualLearningBatch,
    semantics: MLXSemanticLearningBatch,
    regional: MLXRegionalLearningBatch
  ) -> [MLXArray] {
    let sensory = parameters[0]
    let belief = parameters[1]
    let world = parameters[2]
    let route = parameters[3]
    let memory = parameters[4]
    let value = parameters[5]
    let policy = parameters[6]
    let motor = parameters[7]
    let cerebellar = parameters[8]
    let plasticity = parameters[9]
    let regionalDense = parameters[10]
    let prior = batch.priorState
    let posterior = batch.posteriorState
    let observation = batch.observations
    let observationMask = batch.observationMask
    let action = batch.actions
    let completeAction = batch.completeActions
    let reward = batch.factoredReinforcement
    let metrics = batch.outcomeMetrics
    let priorBody = batch.priorEmbodiedState
    let posteriorBody = batch.posteriorEmbodiedState
    let acceptedBodyRisk = maximum(
      posteriorBody[0..., 5..<6], posteriorBody[0..., 7..<8]
    )
    let acceptedConsequenceRisk = maximum(
      acceptedBodyRisk, batch.acceptedStopMask
    )
    let replayTransitionWeights = clip(
      replay.transitionWeights(for: batch), min: 0, max: 4
    )
    let threatTransitionWeights = clip(
      replay.transitionWeights(
        for: batch, episodeWeights: replay.episodeThreatWeights
      ),
      min: 0,
      max: 4
    )
    let transitionMask =
      batch.validMask
      * (Float(1) + replayTransitionWeights)
    let riskTransitionMask =
      batch.validMask
      * (Float(1) + replayTransitionWeights + Float(2) * threatTransitionWeights
        + Float(2) * batch.acceptedStopMask)
    let bodyTransitionMask =
      batch.embodiedStateMask
      * (Float(1) + replayTransitionWeights + Float(2) * threatTransitionWeights)
    let acceptedRiskMask = maximum(
      batch.embodiedStateMask, batch.acceptedStopMask
    ) * (Float(1) + replayTransitionWeights
      + Float(2) * threatTransitionWeights
      + Float(2) * batch.acceptedStopMask)
    let stateDelta = posterior - prior
    let actionState = posterior[0..., 0..<16]
    let somaticWorldAction = completeAction[0..., 0..<16]
      .mean(axis: 1, keepDims: true)
    let autonomicWorldAction = completeAction[0..., 16..<32]
      .mean(axis: 1, keepDims: true)
    let sensingWorldAction = completeAction[0..., 32..<48]
      .mean(axis: 1, keepDims: true)
    let internalWorldAction = completeAction[0..., 48..<80]
      .mean(axis: 1, keepDims: true)
    let worldActionContexts = [
      (somaticWorldAction + sensingWorldAction + autonomicWorldAction) / Float(3),
      Float(0.5) * somaticWorldAction + Float(0.25) * autonomicWorldAction
        + Float(0.25) * sensingWorldAction,
      Float(0.35) * somaticWorldAction + Float(0.4) * sensingWorldAction
        + Float(0.25) * internalWorldAction,
      Float(0.4) * autonomicWorldAction + Float(0.6) * internalWorldAction,
      Float(0.25) * autonomicWorldAction + Float(0.75) * internalWorldAction,
    ]
    let worldActionGain = world[160..<185].mean()
    let structuredWorldContexts = (0..<5).map { level in
      prior[0..., (19 + level)..<(20 + level)]
    }
    let structuredWorldGain = world[185..<190].mean()
    // Match the deployed sensor-conditioned head. The accepted posterior is
    // an outcome target, not an input available when this action was chosen.
    let predictedPolicyAction = MLXEmbodiedPolicyHead.predict(
      prior: prior,
      observations: observation,
      observationMask: observationMask,
      belief: belief,
      policy: policy
    )
    let activeSensingTrace = batch.activeSensingTrace
    let predictedActiveSensingGain = clip(
      activeSensingTrace[0..., 2..<3]
        * metrics[0..., 7..<8] * policy[15],
      min: 0,
      max: 1
    )
    let burnInState = stopGradient(posterior)
    let oneStepObservation = sequences.oneStepSuccessors(observation)
    let oneStepObservationMask = sequences.oneStepSuccessors(observationMask)
    let oneStepAction = sequences.oneStepSuccessors(completeAction)
    let oneStepPrior = sequences.oneStepSuccessors(prior)
    let oneStepTarget = sequences.oneStepSuccessors(posterior)
    let twoStepObservation = sequences.twoStepSuccessors(observation)
    let twoStepObservationMask = sequences.twoStepSuccessors(observationMask)
    let twoStepAction = sequences.twoStepSuccessors(completeAction)
    let twoStepPrior = sequences.twoStepSuccessors(prior)
    let twoStepTarget = sequences.twoStepSuccessors(posterior)
    let oneStepMask =
      sequences.oneStepMask
      * (Float(1) + replayTransitionWeights)
    let twoStepMask =
      sequences.twoStepMask
      * (Float(1) + replayTransitionWeights)
    let observationLoss = batch.maskedElementMeanSquaredError(
      sensory[0] * posterior + sensory[1], observation,
      elementMask: transitionMask * observationMask
    )
    let oneStepBelief = tanh(
      belief[7] * burnInState + belief[0] * oneStepObservation
        + belief[15] * oneStepObservationMask
        + belief[6] * oneStepAction.mean(axis: 1, keepDims: true)
        + belief[4]
    )
    let beliefLoss =
      batch.maskedMeanSquaredError(
        belief[7] * prior + belief[0] * observation
          + belief[15] * observationMask,
        posterior,
        mask: transitionMask
      ) + Float(0.5)
      * batch.maskedMeanSquaredError(
        oneStepBelief, oneStepTarget, mask: oneStepMask
      )
    let oneStepWorld = tanh(
      world[0] * burnInState + world[1] * oneStepObservation
        + world[190] * oneStepObservationMask
        + world[2] * oneStepAction.mean(axis: 1, keepDims: true)
        + worldActionGain * oneStepAction.mean(axis: 1, keepDims: true)
        + structuredWorldGain
          * oneStepPrior[0..., 19..<24].mean(axis: 1, keepDims: true)
        + world[5]
    )
    let twoStepWorld = tanh(
      world[0] * oneStepWorld + world[1] * twoStepObservation
        + world[190] * twoStepObservationMask
        + world[2] * twoStepAction.mean(axis: 1, keepDims: true)
        + worldActionGain * twoStepAction.mean(axis: 1, keepDims: true)
        + structuredWorldGain
          * twoStepPrior[0..., 19..<24].mean(axis: 1, keepDims: true)
        + world[5]
    )
    var eventRiskHeads: [MLXArray] = []
    for head in 0..<5 {
      let base = 90 + head * 6
      eventRiskHeads.append(
        tanh(
          world[base] * priorBody[0..., 7..<8]
            + world[base + 1] * abs(prior[0..., 0..<1])
            + world[base + 2] * priorBody[0..., 5..<6]
            + world[base + 3] * metrics[0..., 4..<5]
            + world[base + 4] * metrics[0..., 6..<7]
            + world[base + 5]
        )
      )
    }
    let eventRiskPredictions = concatenated(eventRiskHeads, axis: 1)
    var actionConditionedWorldLoss = MLXArray(Float(0))
    for level in 0..<5 {
      for head in 0..<5 {
        let base = (level * 5 + head) * 6
        let prediction = tanh(
          world[base] * prior
            + world[base + 1] * observation
            + world[190] * observationMask
            + world[base + 3] * metrics[0..., 4..<5]
            + world[base + 4] * metrics[0..., 6..<7]
            + world[160 + level * 5 + head] * worldActionContexts[level]
            + world[185 + level] * structuredWorldContexts[level]
            + world[base + 5]
        )
        actionConditionedWorldLoss = actionConditionedWorldLoss
          + batch.maskedMeanSquaredError(
            prediction, posterior, mask: transitionMask
          ) / Float(25)
      }
    }
    let worldLoss =
      actionConditionedWorldLoss
      + batch.maskedMeanSquaredError(
        oneStepWorld, oneStepTarget, mask: oneStepMask
      ) + Float(0.5)
      * batch.maskedMeanSquaredError(
        twoStepWorld, twoStepTarget, mask: twoStepMask
      )
      + batch.maskedMeanSquaredError(
        eventRiskPredictions, acceptedConsequenceRisk,
        mask: acceptedRiskMask
      )
      + regional.predictionLoss(
        denseWeights: regionalDense,
        plasticityParameters: plasticity
      )
    let bodyLoss =
      batch.maskedMeanSquaredError(
        tanh(
          belief[7] * prior[0..., 0..<8]
            + belief[0] * observation[0..., 0..<8]
            + belief[6] * action[0..., 0..<8]
            + belief[4]
        ),
        posterior[0..., 0..<8],
        mask: transitionMask
      )
      + batch.maskedMeanSquaredError(
        sigmoid(
          belief[7] * priorBody
            + belief[0] * observation[0..., 0..<8]
            + belief[6] * abs(action[0..., 0..<8])
            + belief[4]
        ),
        posteriorBody,
        mask: bodyTransitionMask
      )
    let agencyLoss = batch.maskedMeanSquaredError(
      actionState * motor[0], action,
      mask: transitionMask
    )
    let eventLoss = batch.maskedMeanSquaredError(
      observation.mean(axis: 1, keepDims: true) * sensory[5],
      metrics[0..., 6..<7],
      mask: riskTransitionMask
    )
    let driveLoss = batch.maskedMeanSquaredError(
      -reward[0..., 0..<1] * value[0], metrics[0..., 4..<5],
      mask: transitionMask
    )
    let predictedValue = (reward * value[0..<8]).sum(axis: 1, keepDims: true)
    let replaySkillValue = (replay.skillExpectedFactoredValue * value[0..<8]).sum(
      axis: 1, keepDims: true)
    let imaginedValue =
      counterfactuals.predictedState.mean(
        axis: 1, keepDims: true
      ) * value[12]
      + counterfactuals.predictedDriveChange * value[13]
      - counterfactuals.predictedEffort * value[14]
      + counterfactuals.predictedInformationGain * value[15]
    let valueLoss =
      batch.maskedMeanSquaredError(
        predictedValue, metrics[0..., 0..<1], mask: transitionMask
      )
      + replay.skillMaskedMeanSquaredError(
        replaySkillValue, replay.skillExpectedValue
      )
      + counterfactuals.maskedMeanSquaredError(
        imaginedValue,
        counterfactuals.objectiveValue,
        mask: counterfactuals.validMask
      )
    let replayEpisodeRisk = sigmoid(
      abs(replay.episodeRetrievalKeys).mean(axis: 1, keepDims: true) * value[8]
        + replay.episodeUncertainty * value[9]
    )
    let replaySkillRisk = sigmoid(
      abs(replay.skillPolicyCode).mean(axis: 1, keepDims: true) * value[10]
        + replay.skillOutcomeUncertainty * value[11]
    )
    let imaginedRisk = sigmoid(
      abs(counterfactuals.actionParameters).mean(axis: 1, keepDims: true)
        * value[16]
        + counterfactuals.epistemicUncertainty * value[17]
        + counterfactuals.predictedEffort * value[18]
    )
    let predictedBodyRisk = sigmoid(
      priorBody[0..., 5..<6] * value[8]
        + priorBody[0..., 7..<8] * value[9]
        + abs(completeAction).mean(axis: 1, keepDims: true) * value[4]
    )
    let riskLoss =
      batch.maskedMeanSquaredError(
        abs(completeAction).mean(axis: 1, keepDims: true) * value[4],
        metrics[0..., 1..<2],
        mask: riskTransitionMask
      )
      + batch.maskedMeanSquaredError(
        predictedBodyRisk,
        acceptedConsequenceRisk,
        mask: acceptedRiskMask
      )
      + replay.episodeMaskedMeanSquaredError(
        replayEpisodeRisk,
        replay.episodeDamage,
        mask: replay.episodeReplayWeights + Float(2) * replay.episodeThreatWeights
      )
      + replay.skillMaskedMeanSquaredError(
        replaySkillRisk, replay.skillDamageCVaR
      )
      + counterfactuals.maskedMeanSquaredError(
        imaginedRisk,
        counterfactuals.damageCVaR,
        mask: counterfactuals.riskMask
      )
    let imaginedPolicyAction = tanh(
      counterfactuals.predictedState * policy[16..<32] + policy[9]
    )
    let policyLoss =
      batch.maskedMeanSquaredError(
        predictedPolicyAction, action,
        mask: transitionMask
      )
      + batch.maskedMeanSquaredError(
        predictedActiveSensingGain,
        activeSensingTrace[0..., 3..<4],
        mask: transitionMask
      )
      + counterfactuals.maskedMeanSquaredError(
        imaginedPolicyAction,
        counterfactuals.actionParameters,
        mask: counterfactuals.actorMask
      )
    let replaySkillCompetence = sigmoid(
      replay.skillInitiationModel.mean(axis: 1, keepDims: true) * policy[2]
        + replay.skillExpectedValue * policy[3]
        - replay.skillDamageCVaR * policy[4]
    )
    let imaginedAdmissibility = sigmoid(
      counterfactuals.objectiveValue * policy[5]
        - counterfactuals.damageCVaR * policy[6]
        - counterfactuals.epistemicUncertainty * policy[7]
    )
    let optionLoss =
      batch.maskedMeanSquaredError(
        sigmoid(predictedValue * policy[1]), metrics[0..., 2..<3],
        mask: transitionMask
      )
      + replay.skillMaskedMeanSquaredError(
        replaySkillCompetence, replay.skillCompetence
      )
      + counterfactuals.maskedMeanSquaredError(
        imaginedAdmissibility, counterfactuals.admissibility
      )
    let cerebellarTracePrediction = tanh(
      stateDelta[0..., 0..<16] * cerebellar[0]
        + action * cerebellar[1]
        + metrics[0..., 6..<7] * cerebellar[2]
        + cerebellar[4]
    )
    let cerebellarLoss =
      batch.maskedMeanSquaredError(
        stateDelta[0..., 0..<16] * cerebellar[3], action,
        mask: transitionMask
      )
      + batch.maskedMeanSquaredError(
        cerebellarTracePrediction, batch.cerebellarTrace,
        mask: transitionMask
      )
    let replayEpisodeOutcome = tanh(
      replay.episodeReinforcement - replay.episodeDamage
        + replay.episodeSalience
    )
    let replayEpisodePrediction = tanh(
      replay.episodeRetrievalKeys.mean(axis: 1, keepDims: true) * memory[8]
        + replay.episodeUncertainty * memory[9]
        + replay.episodeSalience * memory[10]
    )
    let episodicLoss =
      batch.maskedMean(
        abs(stateDelta) * memory[0] + metrics[0..., 3..<4] * memory[6],
        mask: transitionMask
      )
      + replay.episodeMaskedMeanSquaredError(
        replayEpisodePrediction, replayEpisodeOutcome
      )
    let semanticConceptConfidence = sigmoid(
      semantics.conceptEmbedding.mean(axis: 1, keepDims: true) * memory[12]
        + memory[13]
    )
    let semanticRelationEvidence = tanh(
      (semantics.relationSourceEmbedding[0..., 0..<10]
        + semantics.relationDestinationEmbedding[0..., 0..<10])
        * memory[32..<42] + memory[14]
    )
    let semanticRelationConfidence = sigmoid(
      -abs(
        semantics.relationSourceEmbedding
          - semantics.relationDestinationEmbedding
      ).mean(axis: 1, keepDims: true) * memory[15]
        - semantics.relationContradiction * memory[16]
    )
    let semanticLoss =
      batch.maskedMeanSquaredError(
        posterior.mean(axis: 1, keepDims: true) * memory[1],
        observation.mean(axis: 1, keepDims: true),
        mask: transitionMask
      )
      + replay.episodeMaskedMeanSquaredError(
        replay.episodeRetrievalKeys.mean(axis: 1, keepDims: true) * memory[11],
        replay.episodeReinforcement - replay.episodeUncertainty,
        mask: replay.episodeReplayWeights + replay.episodeRareEventWeights
      )
      + semantics.conceptMaskedMeanSquaredError(
        semanticConceptConfidence, semantics.conceptConfidence
      )
      + semantics.relationMaskedMeanSquaredError(
        semanticRelationEvidence, semantics.relationEvidenceEmbedding
      )
      + semantics.relationMaskedMeanSquaredError(
        semanticRelationConfidence, semantics.relationConfidence
      )
    let replaySkillPolicy = tanh(
      replay.skillInitiationModel * memory[16..<32] + memory[3]
    )
    let proceduralLoss =
      batch.maskedMeanSquaredError(
        actionState * memory[2], action,
        mask: transitionMask
      )
      + replay.skillMaskedMeanSquaredError(
        replaySkillPolicy, replay.skillPolicyCode
      )
    let imitationLoss = batch.maskedMeanSquaredError(
      predictedPolicyAction,
      batch.teacherState[0..., 0..<16],
      mask: batch.imitationMask * (Float(1) + replayTransitionWeights)
    )
    let routeLoss = batch.maskedMean(
      square(
        metrics[0..., 3..<4] * route[0]
          - metrics[0..., 7..<8] * route[1]) + square(route[4]),
      mask: transitionMask
    )
    let sparsityLoss =
      parameters.reduce(MLXArray(Float(0))) {
        $0 + abs($1).mean()
      } / Float(parameters.count)
    let stabilityLoss =
      zip(parameters, parentParameters).reduce(
        MLXArray(Float(0))
      ) {
        $0 + square($1.0 - $1.1).mean()
      } / Float(parameters.count)
    let fastPlasticityTracePrediction = tanh(
      observation[0..., 0..<16] * plasticity[3]
        + stateDelta[0..., 0..<16] * plasticity[4]
        + reward.mean(axis: 1, keepDims: true) * plasticity[5]
        + metrics[0..., 6..<7] * plasticity[6]
        + plasticity[0]
    )
    let plasticityLoss =
      batch.maskedMeanSquaredError(
        prior + plasticity[0] * plasticity[3] * observation, posterior,
        mask: transitionMask
      )
      + batch.maskedMeanSquaredError(
        fastPlasticityTracePrediction, batch.fastPlasticityTrace,
        mask: transitionMask
      )
    return [
      observationLoss, beliefLoss, worldLoss, bodyLoss, agencyLoss,
      eventLoss, driveLoss, valueLoss, riskLoss, policyLoss, optionLoss,
      cerebellarLoss, episodicLoss, semanticLoss, proceduralLoss,
      imitationLoss, routeLoss, sparsityLoss, stabilityLoss, plasticityLoss,
    ]
  }
}

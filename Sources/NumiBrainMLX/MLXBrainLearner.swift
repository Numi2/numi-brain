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

  public init(
    learningRate: Float,
    gradientNormLimit: Float,
    parameterMagnitudeLimit: Float,
    lossWeights: [BrainSlowLossKind: Float]
  ) throws {
    guard learningRate.isFinite, learningRate > 0,
      gradientNormLimit.isFinite, gradientNormLimit > 0,
      parameterMagnitudeLimit.isFinite, parameterMagnitudeLimit > 0,
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
      lossWeights: weights
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

  init(_ source: MetalLearningBatch) throws {
    let transitions = try MLXCommittedTransitionBatch(source)
    self.transitions = transitions
    self.sequences = MLXCommittedSequenceBatch(transitions)
    self.replay = try MLXReplayLearningBatch(source)
    self.counterfactuals = try MLXCounterfactualLearningBatch(source)
    self.semantics = try MLXSemanticLearningBatch(source)
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
    batch: MetalLearningBatch
  ) throws -> BrainLearnerUpdate {
    try update(
      parentVersion: parentPublication.version,
      parentArtifact: parentPublication.sharedArtifact,
      batch: batch
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
    batch sourceBatch: MetalLearningBatch
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
    return try update(
      parentVersion: parentVersion,
      parentArtifact: parentArtifact,
      sourceBatchFingerprint: sourceBatch.batchFingerprint,
      sourceBatches: [sourceBatch]
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
      sourceBatches: cohort.members.map(\.batch)
    )
  }

  private func update(
    parentVersion: BrainParameterVersion,
    parentArtifact: BrainSharedParameterArtifact,
    sourceBatchFingerprint: UInt64,
    sourceBatches: [MetalLearningBatch]
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
    try parentArtifact.validate(parameterVersion: parentVersion)
    let preparedBatches = try sourceBatches.map(MLXPreparedMindLearningBatch.init)
    let kinds = BrainSharedParameterArtifact.requiredKinds
    let parentParameters = kinds.map { kind -> MLXArray in
      let payload = parentArtifact.payload(kind)
      return MLXArray(
        payload.data,
        [payload.data.count / MemoryLayout<Float>.stride],
        type: Float.self
      )
    }
    let differentiated = valueAndGrad { [configuration] parameters -> [MLXArray] in
      let terms = Self.cohortLossTerms(
        parameters: parameters,
        parentParameters: parentParameters,
        batches: preparedBatches
      )
      var total = MLXArray(Float(0))
      for (kind, term) in zip(BrainSlowLossKind.allCases, terms) {
        total = total + (configuration.lossWeights[kind] ?? 0) * term
      }
      return [total]
    }
    let (_, gradients) = differentiated(parentParameters)
    var squaredGradientNorm = MLXArray(Float(0))
    for gradient in gradients {
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
    let updatedParameters = zip(parentParameters, gradients).map { parameter, gradient in
      clip(
        parameter - proximalRetention * configuration.learningRate
          * gradientScale * gradient,
        min: -configuration.parameterMagnitudeLimit,
        max: configuration.parameterMagnitudeLimit
      ).asType(.float32).contiguous()
    }
    let updatedTerms = Self.cohortLossTerms(
      parameters: updatedParameters,
      parentParameters: parentParameters,
      batches: preparedBatches
    )
    eval(updatedParameters + updatedTerms)
    let payloads = try zip(kinds, updatedParameters).map { kind, parameter in
      try BrainParameterPayload(
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
    batches: [MLXPreparedMindLearningBatch]
  ) -> [MLXArray] {
    precondition(!batches.isEmpty)
    var totals = lossTerms(
      parameters: parameters,
      parentParameters: parentParameters,
      batch: batches[0].transitions,
      sequences: batches[0].sequences,
      replay: batches[0].replay,
      counterfactuals: batches[0].counterfactuals,
      semantics: batches[0].semantics
    )
    for batch in batches.dropFirst() {
      let terms = lossTerms(
        parameters: parameters,
        parentParameters: parentParameters,
        batch: batch.transitions,
        sequences: batch.sequences,
        replay: batch.replay,
        counterfactuals: batch.counterfactuals,
        semantics: batch.semantics
      )
      for index in totals.indices {
        totals[index] = totals[index] + terms[index]
      }
    }
    let memberCount = Float(batches.count)
    return totals.map { $0 / memberCount }
  }

  private static func lossTerms(
    parameters: [MLXArray],
    parentParameters: [MLXArray],
    batch: MLXCommittedTransitionBatch,
    sequences: MLXCommittedSequenceBatch,
    replay: MLXReplayLearningBatch,
    counterfactuals: MLXCounterfactualLearningBatch,
    semantics: MLXSemanticLearningBatch
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
    let prior = batch.priorState
    let posterior = batch.posteriorState
    let observation = batch.observations
    let action = batch.actions
    let reward = batch.factoredReinforcement
    let metrics = batch.outcomeMetrics
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
      * (Float(1) + replayTransitionWeights + Float(2) * threatTransitionWeights)
    let stateDelta = posterior - prior
    let actionState = posterior[0..., 0..<16]
    let predictedPolicyAction = tanh(actionState * policy[0] + policy[8])
    let burnInState = stopGradient(posterior)
    let oneStepObservation = sequences.oneStepSuccessors(observation)
    let oneStepAction = sequences.oneStepSuccessors(action)
    let oneStepTarget = sequences.oneStepSuccessors(posterior)
    let twoStepObservation = sequences.twoStepSuccessors(observation)
    let twoStepAction = sequences.twoStepSuccessors(action)
    let twoStepTarget = sequences.twoStepSuccessors(posterior)
    let oneStepMask =
      sequences.oneStepMask
      * (Float(1) + replayTransitionWeights)
    let twoStepMask =
      sequences.twoStepMask
      * (Float(1) + replayTransitionWeights)
    let observationLoss = batch.maskedMeanSquaredError(
      sensory[0] * posterior + sensory[1], observation,
      mask: transitionMask
    )
    let oneStepBelief = tanh(
      belief[7] * burnInState + belief[0] * oneStepObservation
        + belief[6] * oneStepAction.mean(axis: 1, keepDims: true)
        + belief[4]
    )
    let beliefLoss =
      batch.maskedMeanSquaredError(
        belief[7] * prior + belief[0] * observation, posterior,
        mask: transitionMask
      ) + Float(0.5)
      * batch.maskedMeanSquaredError(
        oneStepBelief, oneStepTarget, mask: oneStepMask
      )
    let oneStepWorld = tanh(
      world[0] * burnInState + world[1] * oneStepObservation
        + world[2] * oneStepAction.mean(axis: 1, keepDims: true)
        + world[5]
    )
    let twoStepWorld = tanh(
      world[0] * oneStepWorld + world[1] * twoStepObservation
        + world[2] * twoStepAction.mean(axis: 1, keepDims: true)
        + world[5]
    )
    let worldLoss =
      batch.maskedMeanSquaredError(
        tanh(world[0] * prior + world[1] * observation + world[5]), posterior,
        mask: transitionMask
      )
      + batch.maskedMeanSquaredError(
        oneStepWorld, oneStepTarget, mask: oneStepMask
      ) + Float(0.5)
      * batch.maskedMeanSquaredError(
        twoStepWorld, twoStepTarget, mask: twoStepMask
      )
    let bodyLoss = batch.maskedMeanSquaredError(
      tanh(
        belief[7] * prior[0..., 0..<8]
          + belief[0] * observation[0..., 0..<8]
          + belief[6] * action[0..., 0..<8]
          + belief[4]
      ),
      posterior[0..., 0..<8],
      mask: transitionMask
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
    let riskLoss =
      batch.maskedMeanSquaredError(
        abs(action).mean(axis: 1, keepDims: true) * value[4],
        metrics[0..., 1..<2],
        mask: riskTransitionMask
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
    let cerebellarLoss = batch.maskedMeanSquaredError(
      stateDelta[0..., 0..<16] * cerebellar[3], action,
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
    let plasticityLoss = batch.maskedMeanSquaredError(
      prior + plasticity[0] * plasticity[3] * observation, posterior,
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

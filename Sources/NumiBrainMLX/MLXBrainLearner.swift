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

  public func update(
    parentVersion: BrainParameterVersion,
    parentArtifact: BrainSharedParameterArtifact,
    batch sourceBatch: MetalLearningBatch
  ) throws -> BrainLearnerUpdate {
    guard sourceBatch.parameterVersionFingerprint == parentVersion.fingerprint,
      parentArtifact.parameterVersionFingerprint == parentVersion.fingerprint
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX learner inputs do not share one immutable parent version"
      )
    }
    try parentArtifact.validate(parameterVersion: parentVersion)
    let batch = try MLXCommittedTransitionBatch(sourceBatch)
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
      let terms = Self.lossTerms(
        parameters: parameters,
        parentParameters: parentParameters,
        batch: batch
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
    let updatedParameters = zip(parentParameters, gradients).map { parameter, gradient in
      clip(
        parameter - configuration.learningRate * gradientScale * gradient,
        min: -configuration.parameterMagnitudeLimit,
        max: configuration.parameterMagnitudeLimit
      ).asType(.float32).contiguous()
    }
    let updatedTerms = Self.lossTerms(
      parameters: updatedParameters,
      parentParameters: parentParameters,
      batch: batch
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
      sourceBatchFingerprint: sourceBatch.batchFingerprint,
      sourceGeneration: sourceBatch.sourceGeneration,
      candidateVersion: successor.version,
      sharedArtifact: successor.artifact,
      losses: losses
    )
  }

  private static func lossTerms(
    parameters: [MLXArray],
    parentParameters: [MLXArray],
    batch: MLXCommittedTransitionBatch
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
    let stateDelta = posterior - prior
    let actionState = posterior[0..., 0..<16]
    let observationLoss = batch.maskedMeanSquaredError(
      sensory[0] * posterior + sensory[1], observation
    )
    let beliefLoss = batch.maskedMeanSquaredError(
      belief[7] * prior + belief[0] * observation, posterior
    )
    let worldLoss = batch.maskedMeanSquaredError(
      tanh(world[0] * prior + world[1] * observation + world[5]), posterior
    )
    let bodyLoss = batch.maskedMeanSquaredError(
      posterior[0..., 0..<8], observation[0..., 0..<8]
    )
    let agencyLoss = batch.maskedMeanSquaredError(
      actionState * motor[0], action
    )
    let eventLoss = batch.maskedMeanSquaredError(
      observation.mean(axis: 1, keepDims: true) * sensory[5],
      metrics[0..., 6..<7]
    )
    let driveLoss = batch.maskedMeanSquaredError(
      -reward[0..., 0..<1] * value[0], metrics[0..., 4..<5]
    )
    let predictedValue = (
      reward * value[0..<8]
    ).sum(axis: 1, keepDims: true)
    let valueLoss = batch.maskedMeanSquaredError(
      predictedValue, metrics[0..., 0..<1]
    )
    let riskLoss = batch.maskedMeanSquaredError(
      abs(action).mean(axis: 1, keepDims: true) * value[4],
      metrics[0..., 1..<2]
    )
    let policyLoss = batch.maskedMeanSquaredError(
      tanh(actionState * policy[0] + policy[8]), action
    )
    let optionLoss = batch.maskedMeanSquaredError(
      sigmoid(predictedValue * policy[1]), metrics[0..., 2..<3]
    )
    let cerebellarLoss = batch.maskedMeanSquaredError(
      stateDelta[0..., 0..<16] * cerebellar[3], action
    )
    let episodicLoss = batch.maskedMean(
      abs(stateDelta) * memory[0] + metrics[0..., 3..<4] * memory[6]
    )
    let semanticLoss = batch.maskedMeanSquaredError(
      posterior.mean(axis: 1, keepDims: true) * memory[1],
      observation.mean(axis: 1, keepDims: true)
    )
    let proceduralLoss = batch.maskedMeanSquaredError(
      actionState * memory[2], action
    )
    let imitationLoss = batch.maskedMeanSquaredError(
      action,
      batch.teacherState[0..., 0..<16],
      mask: batch.teacherMask
    )
    let routeLoss = batch.maskedMean(
      square(metrics[0..., 3..<4] * route[0]
        - metrics[0..., 7..<8] * route[1]) + square(route[4])
    )
    let sparsityLoss = parameters.reduce(MLXArray(Float(0))) {
      $0 + abs($1).mean()
    } / Float(parameters.count)
    let stabilityLoss = zip(parameters, parentParameters).reduce(
      MLXArray(Float(0))
    ) {
      $0 + square($1.0 - $1.1).mean()
    } / Float(parameters.count)
    let plasticityLoss = batch.maskedMeanSquaredError(
      prior + plasticity[0] * plasticity[3] * observation, posterior
    )
    return [
      observationLoss, beliefLoss, worldLoss, bodyLoss, agencyLoss,
      eventLoss, driveLoss, valueLoss, riskLoss, policyLoss, optionLoss,
      cerebellarLoss, episodicLoss, semanticLoss, proceduralLoss,
      imitationLoss, routeLoss, sparsityLoss, stabilityLoss, plasticityLoss,
    ]
  }
}

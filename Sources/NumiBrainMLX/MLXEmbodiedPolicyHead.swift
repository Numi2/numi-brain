import MLX
import NumiBrainCore

/// The sensor-conditioned somatic-synergy head used by DecisionState.metal.
/// Dimensions and parameter indices come from the generated executable-model
/// contract. Training and interventions evaluate this same causal relation from
/// the pre-transition recurrent state and observation sketch; accepted posterior
/// state, teacher state and future outcomes remain targets, never inputs.
@available(macOS 26.0, *)
public enum MLXEmbodiedPolicyHead {
  public static func predict(
    prior: MLXArray,
    observations: MLXArray,
    observationMask: MLXArray,
    belief: MLXArray,
    policy: MLXArray
  ) -> MLXArray {
    let c = BrainExecutableModelContract.PolicyHead.self
    precondition(prior.ndim == 2 && prior.shape[1] >= c.recurrentInputCount)
    precondition(observations.ndim == 2 && observations.shape[1] == c.observationCount)
    precondition(prior.shape[0] == observations.shape[0])
    precondition(observationMask.shape == observations.shape)
    precondition(belief.ndim == 1 && belief.size > c.beliefRecurrentIndex)
    precondition(policy.ndim == 1 && policy.size > c.policyBiasIndex)
    let rows = observations.shape[0]
    let zeroTail = MLXArray(
      [Float](repeating: 0, count: rows * c.tailObservationCount),
      [rows, c.tailObservationCount]
    )
    let validObservations = which(
      observationMask .> Float(0), observations, MLXArray(Float(0))
    )
    let primary = 0..<c.primaryObservationCount
    let tail = c.primaryObservationCount..<c.observationCount
    let foldedObservation = validObservations[0..., primary] + c.tailFoldGain
      * concatenated([validObservations[0..., tail], zeroTail], axis: 1)
    let foldedMask = observationMask[0..., primary] + c.tailFoldGain
      * concatenated([observationMask[0..., tail], zeroTail], axis: 1)
    let evidence = which(
      foldedMask .> Float(0), foldedObservation, MLXArray(Float(0))
    )
    let posterior = tanh(
      belief[c.beliefRecurrentIndex] * prior[0..., 0..<c.recurrentInputCount]
        + belief[c.beliefEvidenceIndex] * evidence + belief[c.beliefBiasIndex]
    )
    return tanh(posterior * policy[c.policyGainIndex] + policy[c.policyBiasIndex])
  }
}

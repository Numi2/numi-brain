import MLX

/// The sensor-conditioned sixteen-synergy head used by DecisionState.metal.
/// Training and offline interventions must evaluate this same relation from
/// the pre-transition recurrent state and causal observation sketch. Accepted
/// posterior state, teacher state and future outcomes are targets, not inputs.
@available(macOS 26.0, *)
public enum MLXEmbodiedPolicyHead {
  public static func predict(
    prior: MLXArray,
    observations: MLXArray,
    observationMask: MLXArray,
    belief: MLXArray,
    policy: MLXArray
  ) -> MLXArray {
    precondition(prior.ndim == 2 && prior.shape[1] >= 16)
    precondition(observations.ndim == 2 && observations.shape[1] == 24)
    precondition(prior.shape[0] == observations.shape[0])
    precondition(observationMask.shape == observations.shape)
    precondition(belief.ndim == 1 && belief.size > 7)
    precondition(policy.ndim == 1 && policy.size > 8)
    let rows = observations.shape[0]
    let zeroTail = MLXArray(
      [Float](repeating: 0, count: rows * 8), [rows, 8]
    )
    // Select before arithmetic: NaN * 0 is not a valid missing observation.
    let validObservations = which(
      observationMask .> Float(0), observations, MLXArray(Float(0))
    )
    let foldedObservation = validObservations[0..., 0..<16] + Float(0.25)
      * concatenated([validObservations[0..., 16..<24], zeroTail], axis: 1)
    let foldedMask = observationMask[0..., 0..<16] + Float(0.25)
      * concatenated([observationMask[0..., 16..<24], zeroTail], axis: 1)
    let evidence = which(
      foldedMask .> Float(0), foldedObservation, MLXArray(Float(0))
    )
    // A validity flag gates evidence. It must never become an action bias.
    let posterior = tanh(
      belief[7] * prior[0..., 0..<16] + belief[0] * evidence + belief[4]
    )
    return tanh(posterior * policy[0] + policy[8])
  }
}

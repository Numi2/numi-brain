import MLX

/// Off-rollout projection of a parameter delta. Frozen coordinates are
/// selected from the immutable parent *after* projection, so neither clipping
/// nor floating-point arithmetic can change an unrelated parameter.
@available(macOS 26.0, *)
enum MLXImmutableParameterUpdate {
  static func project(
    parent: MLXArray,
    delta: MLXArray,
    magnitudeLimit: Float,
    mutableMask: MLXArray? = nil
  ) -> MLXArray {
    precondition(parent.shape == delta.shape)
    precondition(magnitudeLimit.isFinite && magnitudeLimit > 0)
    let candidate = clip(parent - delta, min: -magnitudeLimit, max: magnitudeLimit)
      .asType(.float32)
    guard let mutableMask else { return candidate.contiguous() }
    precondition(mutableMask.shape == parent.shape)
    return which(mutableMask .> Float(0), candidate, parent).contiguous()
  }
}

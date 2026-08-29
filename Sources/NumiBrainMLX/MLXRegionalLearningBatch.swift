import Foundation
import MLX
import NumiBrainCore
import NumiBrainMetal

/// Zero-copy view of committed regional token transitions. Each record owns one
/// complete token from one exact module matrix; padded FP16 components are
/// masked before the values participate in the FP32 learner objective.
@available(macOS 26.0, *)
public struct MLXRegionalLearningBatch: @unchecked Sendable {
  public static let maximumFeatureCount = 256

  public let source: MetalLearningBatch
  public let rawBytes: MLXArray
  public let validMask: MLXArray
  public let featureMask: MLXArray
  public let featureCounts: MLXArray
  public let denseWeightOffsets: MLXArray
  public let denseWeightCounts: MLXArray
  public let priorState: MLXArray
  public let posteriorState: MLXArray

  public init(_ source: MetalLearningBatch) throws {
    guard source.formatVersion == MetalLearningBatch.formatVersion,
      source.regionalTransitionRecordVersion
        == MetalLearningBatch.regionalTransitionRecordVersion,
      source.regionalTransitionStride == MetalLearningBatch.regionalTransitionStride
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX regional-transition batch ABI is incompatible"
      )
    }
    let lease = try source.makeSharedStorageLease(for: .regionalTransitions)
    guard lease.byteCount
      == source.regionalTransitionCapacity * source.regionalTransitionStride
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX regional-transition section byte count is incompatible"
      )
    }
    let raw = MLXArray(
      rawPointer: lease.baseAddress,
      [source.regionalTransitionCapacity, source.regionalTransitionStride],
      dtype: .uint8
    ) {
      _ = lease
    }
    func field(_ byteOffset: Int, count: Int, dtype: DType) -> MLXArray {
      raw[0..., byteOffset..<(byteOffset + count * dtype.size)].view(dtype: dtype)
    }
    let identifiers = field(0, count: 1, dtype: .uint64)
    let startTimestamps = field(8, count: 1, dtype: .uint64)
    let endTimestamps = field(16, count: 1, dtype: .uint64)
    let parameterFingerprints = field(24, count: 1, dtype: .uint64)
    let sourceGenerations = field(32, count: 1, dtype: .uint64)
    let format = field(40, count: 1, dtype: .uint32)
    let flags = field(44, count: 1, dtype: .uint32)
    let featureCounts = field(60, count: 1, dtype: .uint32)
    let denseWeightOffsets = field(64, count: 1, dtype: .uint32)
    let denseWeightCounts = field(68, count: 1, dtype: .uint32)
    let prior = field(80, count: Self.maximumFeatureCount, dtype: .float16)
      .asType(.float32)
    let posterior = field(592, count: Self.maximumFeatureCount, dtype: .float16)
      .asType(.float32)
    let featureIndices = MLXArray(
      (0..<Self.maximumFeatureCount).map(UInt32.init),
      [1, Self.maximumFeatureCount]
    )
    let featureMask = (featureIndices .< featureCounts).asType(.float32)
    let statesFinite = (
      isFinite(prior).asType(.float32).sum(axis: 1, keepDims: true)
        .== Float(Self.maximumFeatureCount)
    ).asType(.float32) * (
      isFinite(posterior).asType(.float32).sum(axis: 1, keepDims: true)
        .== Float(Self.maximumFeatureCount)
    ).asType(.float32)
    let validMask = (
      (identifiers .> UInt64(0))
        * (format .== UInt32(MetalLearningBatch.regionalTransitionRecordVersion))
        * ((flags & UInt32(1)) .== UInt32(1))
        * (parameterFingerprints .== source.parameterVersionFingerprint)
        * (sourceGenerations .> UInt64(0))
        * (sourceGenerations .<= source.sourceGeneration)
        * (endTimestamps .>= startTimestamps)
        * (featureCounts .> UInt32(0))
        * (featureCounts .<= UInt32(Self.maximumFeatureCount))
        * (denseWeightCounts .== featureCounts * featureCounts)
    ).asType(.float32) * statesFinite

    self.source = source
    self.rawBytes = raw
    self.validMask = validMask
    self.featureMask = featureMask
    self.featureCounts = featureCounts
    self.denseWeightOffsets = denseWeightOffsets
    self.denseWeightCounts = denseWeightCounts
    self.priorState = which(isFinite(prior), prior, MLXArray(Float(0)))
    self.posteriorState = which(isFinite(posterior), posterior, MLXArray(Float(0)))
  }

  /// Differentiable gathered matrix execution matching the runtime's
  /// row-major W[module] x token / sqrt(d) convention. Invalid padded indices
  /// are clipped before gather and then removed by the feature mask.
  public func predictionLoss(denseWeights: MLXArray) -> MLXArray {
    let capacity = source.regionalTransitionCapacity
    let rows = MLXArray(
      (0..<Self.maximumFeatureCount).map(Int32.init),
      [1, Self.maximumFeatureCount, 1]
    )
    let columns = MLXArray(
      (0..<Self.maximumFeatureCount).map(Int32.init),
      [1, 1, Self.maximumFeatureCount]
    )
    let dimensions = featureCounts.asType(.int32).reshaped([capacity, 1, 1])
    let offsets = denseWeightOffsets.asType(.int32).reshaped([capacity, 1, 1])
    let unclippedIndices = offsets + rows * dimensions + columns
    let indices = clip(
      unclippedIndices,
      min: 0,
      max: max(denseWeights.size - 1, 0)
    )
    let matrices = denseWeights.take(indices)
    let rowMask = featureMask.reshaped([capacity, Self.maximumFeatureCount, 1])
    let columnMask = featureMask.reshaped([capacity, 1, Self.maximumFeatureCount])
    let activeMatrices = matrices * rowMask * columnMask
    let projected = (
      activeMatrices * priorState.reshaped([capacity, 1, Self.maximumFeatureCount])
    ).sum(axis: 2) / sqrt(maximum(featureCounts.asType(.float32), Float(1)))
    let prediction = tanh(priorState + projected)
    let inBounds = (
      denseWeightOffsets.asType(.uint64) + denseWeightCounts.asType(.uint64)
        .<= UInt64(denseWeights.size)
    ).asType(.float32)
    let mask = validMask * inBounds * featureMask
    let denominator = maximum(mask.sum(), MLXArray(Float(1)))
    return (square(prediction - posteriorState) * mask).sum() / denominator
  }
}

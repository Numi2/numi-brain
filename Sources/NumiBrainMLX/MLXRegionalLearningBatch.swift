import Foundation
import MLX
import NumiBrainCore
import NumiBrainMetal

/// Zero-copy view of committed regional token transitions. Each record owns one
/// complete token from one exact module matrix plus the committed top-four
/// fast-plastic basis context; padded FP16 components are masked before the
/// values participate in the FP32 learner objective.
@available(macOS 26.0, *)
public struct MLXRegionalLearningBatch: @unchecked Sendable {
  public static let maximumFeatureCount = 256

  public let source: MetalLearningBatch
  public let rawBytes: MLXArray
  public let validMask: MLXArray
  public let featureMask: MLXArray
  public let featureCounts: MLXArray
  public let moduleIndices: MLXArray
  public let denseWeightOffsets: MLXArray
  public let denseWeightCounts: MLXArray
  public let activePlasticBasisCounts: MLXArray
  public let activePlasticBasisIdentifiers: MLXArray
  public let activePlasticBasisCoefficients: MLXArray
  public let plasticDenseTargetScale: MLXArray
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
    let moduleIndices = field(48, count: 1, dtype: .uint32)
    let featureCounts = field(60, count: 1, dtype: .uint32)
    let denseWeightOffsets = field(64, count: 1, dtype: .uint32)
    let denseWeightCounts = field(68, count: 1, dtype: .uint32)
    let activePlasticBasisCounts = field(80, count: 1, dtype: .uint32)
    let activePlasticBasisIdentifiers = field(84, count: 4, dtype: .uint32)
    let activePlasticBasisCoefficients = field(100, count: 4, dtype: .float32)
    let plasticDenseTargetScale = field(116, count: 1, dtype: .float32)
    let prior = field(128, count: Self.maximumFeatureCount, dtype: .float16)
      .asType(.float32)
    let posterior = field(640, count: Self.maximumFeatureCount, dtype: .float16)
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
        * (moduleIndices .< UInt32(source.regionalModuleCount))
        * (featureCounts .> UInt32(0))
        * (featureCounts .<= UInt32(Self.maximumFeatureCount))
        * (denseWeightCounts .== featureCounts * featureCounts)
        * (activePlasticBasisCounts .<= UInt32(4))
    ).asType(.float32) * statesFinite
      * (
        isFinite(activePlasticBasisCoefficients).asType(.float32)
          .sum(axis: 1, keepDims: true) .== Float(4)
      ).asType(.float32)
      * isFinite(plasticDenseTargetScale).asType(.float32)
      * (plasticDenseTargetScale .>= Float(0)).asType(.float32)

    self.source = source
    self.rawBytes = raw
    self.validMask = validMask
    self.featureMask = featureMask
    self.featureCounts = featureCounts
    self.moduleIndices = moduleIndices
    self.denseWeightOffsets = denseWeightOffsets
    self.denseWeightCounts = denseWeightCounts
    self.activePlasticBasisCounts = activePlasticBasisCounts
    self.activePlasticBasisIdentifiers = activePlasticBasisIdentifiers
    self.activePlasticBasisCoefficients = which(
      isFinite(activePlasticBasisCoefficients),
      activePlasticBasisCoefficients,
      MLXArray(Float(0))
    )
    self.plasticDenseTargetScale = which(
      isFinite(plasticDenseTargetScale),
      plasticDenseTargetScale,
      MLXArray(Float(0))
    )
    self.priorState = which(isFinite(prior), prior, MLXArray(Float(0)))
    self.posteriorState = which(isFinite(posterior), posterior, MLXArray(Float(0)))
  }

  /// Differentiable gathered matrix execution matching the runtime's
  /// row-major (W[module] + sum f_l B_l) x token / sqrt(d) convention. Invalid
  /// padded indices are clipped before gather and removed by the feature mask.
  public func predictionLoss(
    denseWeights: MLXArray,
    plasticityParameters: MLXArray
  ) -> MLXArray {
    let capacity = source.regionalTransitionCapacity
    let moduleCount = source.regionalModuleCount
    let basisStride = BrainSharedParameterArtifact.plasticityBasisChannelCount
    let receptorScalarCount = moduleCount
      * NeuromodulatorKind.allCases.count
      * BrainSharedParameterArtifact.plasticityReceptorEffectCount
    let basisScalarCount = plasticityParameters.size
      - BrainSharedParameterArtifact.plasticityHyperparameterCount
      - receptorScalarCount
    let basisBankStride = moduleCount * basisStride
    precondition(
      moduleCount > 0 && basisScalarCount > 0 && basisBankStride > 0
        && basisScalarCount % basisBankStride == 0
    )
    let basisCapacity = basisScalarCount / basisBankStride
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
    let denseProjection = (
      activeMatrices * priorState.reshaped([capacity, 1, Self.maximumFeatureCount])
    ).sum(axis: 2) / sqrt(maximum(featureCounts.asType(.float32), Float(1)))
    let activeRanks = MLXArray((0..<4).map(UInt32.init), [1, 4])
    let activeBasisMask = (
      activeRanks .< activePlasticBasisCounts
    ).asType(.float32)
    let basisIdentifiers = clip(
      activePlasticBasisIdentifiers.asType(.int32),
      min: 0,
      max: max(basisCapacity - 1, 0)
    )
    let basisOffsets = Int32(
      BrainSharedParameterArtifact.plasticityHyperparameterCount
    ) + (
      moduleIndices.asType(.int32) * Int32(basisCapacity) + basisIdentifiers
    ) * Int32(basisStride)
    let basisFeatures = MLXArray(
      (0..<Self.maximumFeatureCount).map(Int32.init),
      [1, 1, Self.maximumFeatureCount]
    )
    let leftIndices = basisOffsets.reshaped([capacity, 4, 1])
      + Int32(BrainSharedParameterArtifact.plasticityBasisOperatorChannelCount)
      + basisFeatures
    let rightIndices = basisOffsets.reshaped([capacity, 4, 1])
      + Int32(BrainSharedParameterArtifact.plasticityBasisOperatorChannelCount)
      + Int32(BrainSharedParameterArtifact.plasticityBasisMaximumFeatureCount)
      + basisFeatures
    let leftFactors = plasticityParameters.take(leftIndices)
      * featureMask.reshaped([capacity, 1, Self.maximumFeatureCount])
    let rightFactors = plasticityParameters.take(rightIndices)
      * featureMask.reshaped([capacity, 1, Self.maximumFeatureCount])
    let rightProjection = (
      rightFactors * priorState.reshaped([capacity, 1, Self.maximumFeatureCount])
    ).sum(axis: 2, keepDims: true)
      / sqrt(maximum(
        featureCounts.asType(.float32).reshaped([capacity, 1, 1]),
        Float(1)
      ))
    let plasticResidual = (
      leftFactors
        * rightProjection
        * activePlasticBasisCoefficients.reshaped([capacity, 4, 1])
        * activeBasisMask.reshaped([capacity, 4, 1])
    ).sum(axis: 1)
    let prediction = tanh(priorState + denseProjection + plasticResidual)
    let denseInBounds = (
      denseWeightOffsets.asType(.uint64) + denseWeightCounts.asType(.uint64)
        .<= UInt64(denseWeights.size)
    ).asType(.float32)
    let activeBasisInBounds = (
      activePlasticBasisIdentifiers .< UInt32(basisCapacity)
    ).asType(.float32) * activeBasisMask
    let allActiveBasesInBounds = (
      activeBasisInBounds.sum(axis: 1, keepDims: true)
        .== activePlasticBasisCounts.asType(.float32)
    ).asType(.float32)
    let transitionWeight = Float(1) + minimum(plasticDenseTargetScale, Float(1))
    let mask = validMask * denseInBounds * allActiveBasesInBounds
      * featureMask * transitionWeight
    let denominator = maximum(mask.sum(), MLXArray(Float(1)))
    return (square(prediction - posteriorState) * mask).sum() / denominator
  }
}

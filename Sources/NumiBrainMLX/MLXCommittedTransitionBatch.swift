import Foundation
import MLX
import NumiBrainCore
import NumiBrainMetal

/// Zero-copy MLX view of committed-transition slots. Every valid record carries
/// 19 recurrent features, five exact structured world-context features,
/// accepted somatic, autonomic, active-sensing, and internal action features,
/// and bounded plasticity/cerebellar traces; empty ring slots are excluded by
/// `validMask`.
@available(macOS 26.0, *)
public struct MLXCommittedTransitionBatch: @unchecked Sendable {
  public static let transitionStride = MetalLearningBatch.transitionStride

  public let source: MetalLearningBatch
  public let rawBytes: MLXArray
  public let validMask: MLXArray
  public let startTimestamps: MLXArray
  public let endTimestamps: MLXArray
  public let sourceGenerations: MLXArray
  public let activeOptionIdentifiers: MLXArray
  public let parameterVersionFingerprints: MLXArray
  public let priorState: MLXArray
  public let posteriorState: MLXArray
  public let observations: MLXArray
  public let observationMask: MLXArray
  public let actions: MLXArray
  public let autonomicActions: MLXArray
  public let activeSensingActions: MLXArray
  public let internalActions: MLXArray
  public let completeActions: MLXArray
  public let factoredReinforcement: MLXArray
  public let outcomeMetrics: MLXArray
  public let teacherState: MLXArray
  public let fastPlasticityTrace: MLXArray
  public let cerebellarTrace: MLXArray
  public let activeSensingTrace: MLXArray
  public let priorBodyState: MLXArray
  public let posteriorBodyState: MLXArray
  public let bodyStateMask: MLXArray
  public let acceptedStopMask: MLXArray
  public let teacherMask: MLXArray
  public let imitationMask: MLXArray

  public init(_ source: MetalLearningBatch) throws {
    guard source.formatVersion == MetalLearningBatch.formatVersion,
      source.transitionRecordVersion == MetalLearningBatch.transitionRecordVersion,
      source.transitionStride == Self.transitionStride
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX committed-transition batch ABI is incompatible"
      )
    }
    let lease = try source.makeSharedStorageLease()
    guard lease.byteCount == source.transitionCapacity * source.transitionStride else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX committed-transition section byte count is incompatible"
      )
    }
    let raw = MLXArray(
      rawPointer: lease.baseAddress,
      [source.transitionCapacity, source.transitionStride],
      dtype: .uint8
    ) {
      _ = lease
    }
    func field(_ byteOffset: Int, count: Int, dtype: DType) -> MLXArray {
      raw[0..., byteOffset..<(byteOffset + count * dtype.size)].view(dtype: dtype)
    }
    func finite(_ values: MLXArray) -> MLXArray {
      which(isFinite(values), values, MLXArray(Float(0)))
    }
    func allFinite(_ values: MLXArray, count: Int) -> MLXArray {
      (
        isFinite(values).asType(.float32).sum(axis: 1, keepDims: true)
          .== Float(count)
      ).asType(.float32)
    }
    let identifiers = field(0, count: 1, dtype: .uint64)
    let startTimestamps = field(8, count: 1, dtype: .uint64)
    let endTimestamps = field(16, count: 1, dtype: .uint64)
    let sourceGenerations = field(32, count: 1, dtype: .uint64)
    let format = field(64, count: 1, dtype: .uint32)
    let flags = field(68, count: 1, dtype: .uint32)
    let parameterVersionFingerprints = field(24, count: 1, dtype: .uint64)
    let rawPrior = field(128, count: 24, dtype: .float32)
    let rawPosterior = field(224, count: 24, dtype: .float32)
    let rawObservations = field(320, count: 24, dtype: .float32)
    let observationValidityBits = field(92, count: 1, dtype: .uint32)
    let rawActions = field(416, count: 16, dtype: .float32)
    let rawReinforcement = field(480, count: 8, dtype: .float32)
    let rawMetrics = field(96, count: 8, dtype: .float32)
    let rawTeacher = field(528, count: 24, dtype: .float32)
    let rawFastPlasticityTrace = field(624, count: 16, dtype: .float32)
    let rawCerebellarTrace = field(688, count: 16, dtype: .float32)
    let rawActiveSensingTrace = field(752, count: 4, dtype: .float32)
    let completeActionCounts = field(768, count: 4, dtype: .uint32)
    let rawAutonomicActions = field(784, count: 16, dtype: .float32)
    let rawActiveSensingActions = field(848, count: 16, dtype: .float32)
    let rawInternalActions = field(912, count: 32, dtype: .float32)
    let rawBodySchemaTrace = field(1040, count: 16, dtype: .float32)
    let completeActionCountsValid = (
      (completeActionCounts[0..., 0..<1] .<= UInt32(8))
        * (completeActionCounts[0..., 1..<2] .<= UInt32(8))
        * (completeActionCounts[0..., 2..<3] .<= UInt32(8))
        * ((completeActionCounts[0..., 3..<4] & UInt32(1)) .== UInt32(1))
    ).asType(.float32)
    let validMask = (
      (identifiers .> UInt64(0))
        * (format .== UInt32(MetalLearningBatch.transitionRecordVersion))
        * ((flags & UInt32(1)) .== UInt32(1))
        * (parameterVersionFingerprints .== source.parameterVersionFingerprint)
        * (sourceGenerations .> UInt64(0))
        * (sourceGenerations .<= source.sourceGeneration)
        * (endTimestamps .>= startTimestamps)
    ).asType(.float32)
      * allFinite(rawPrior, count: 24)
      * allFinite(rawPosterior, count: 24)
      * allFinite(rawObservations, count: 24)
      * allFinite(rawActions, count: 16)
      * allFinite(rawReinforcement, count: 8)
      * allFinite(rawMetrics, count: 8)
      * allFinite(rawFastPlasticityTrace, count: 16)
      * allFinite(rawCerebellarTrace, count: 16)
      * allFinite(rawActiveSensingTrace, count: 4)
      * allFinite(rawAutonomicActions, count: 16)
      * allFinite(rawActiveSensingActions, count: 16)
      * allFinite(rawInternalActions, count: 32)
      * allFinite(rawBodySchemaTrace, count: 16)
      * completeActionCountsValid
    let observationMask = concatenated(
      (0..<24).map { component in
        (
          (observationValidityBits & UInt32(1 << component))
            .!= UInt32(0)
        ).asType(.float32)
      },
      axis: 1
    ) * validMask
    let teacherCount = field(520, count: 1, dtype: .uint32)
    let teacherFlags = field(524, count: 1, dtype: .uint32)
    let teacherFiniteMask = allFinite(rawTeacher, count: 24)
    let somaticActions = finite(rawActions)
    let autonomicActions = finite(rawAutonomicActions)
    let activeSensingActions = finite(rawActiveSensingActions)
    let internalActions = finite(rawInternalActions)
    self.source = source
    self.rawBytes = raw
    self.validMask = validMask
    self.startTimestamps = startTimestamps
    self.endTimestamps = endTimestamps
    self.sourceGenerations = sourceGenerations
    self.activeOptionIdentifiers = field(56, count: 1, dtype: .uint64)
    self.parameterVersionFingerprints = parameterVersionFingerprints
    self.priorState = finite(rawPrior)
    self.posteriorState = finite(rawPosterior)
    self.observations = finite(rawObservations) * observationMask
    self.observationMask = observationMask
    self.actions = somaticActions
    self.autonomicActions = autonomicActions
    self.activeSensingActions = activeSensingActions
    self.internalActions = internalActions
    self.completeActions = concatenated(
      [
        somaticActions, autonomicActions,
        activeSensingActions, internalActions,
      ],
      axis: 1
    )
    self.factoredReinforcement = finite(rawReinforcement)
    self.outcomeMetrics = finite(rawMetrics)
    self.teacherState = finite(rawTeacher)
    self.fastPlasticityTrace = finite(rawFastPlasticityTrace)
    self.cerebellarTrace = finite(rawCerebellarTrace)
    self.activeSensingTrace = finite(rawActiveSensingTrace)
    self.priorBodyState = finite(rawBodySchemaTrace[0..., 0..<8])
    self.posteriorBodyState = finite(rawBodySchemaTrace[0..., 8..<16])
    self.bodyStateMask = ((flags & UInt32(2)) .== UInt32(2)).asType(.float32)
      * validMask
    self.acceptedStopMask = ((flags & UInt32(4)) .== UInt32(4)).asType(.float32)
      * validMask
    self.teacherMask = (teacherCount .> UInt32(0)).asType(.float32)
      * validMask * teacherFiniteMask
    let hasDemonstratedAction = (
      teacherFlags & MetalTeacherStateFlags.demonstratedAction.rawValue
    ) .!= UInt32(0)
    self.imitationMask = hasDemonstratedAction.asType(.float32)
      * (teacherCount .> UInt32(15)).asType(.float32)
      * validMask * teacherFiniteMask
  }

  public func maskedMean(_ values: MLXArray, mask: MLXArray? = nil) -> MLXArray {
    let selectedMask = mask ?? validMask
    let valuesPerRecord = max(values.size / max(source.transitionCapacity, 1), 1)
    let denominator = maximum(
      selectedMask.sum() * Float(valuesPerRecord),
      MLXArray(Float(1))
    )
    return (values * selectedMask).sum() / denominator
  }

  public func maskedMeanSquaredError(
    _ prediction: MLXArray,
    _ target: MLXArray,
    mask: MLXArray? = nil
  ) -> MLXArray {
    maskedMean(square(prediction - target), mask: mask)
  }

  public func maskedElementMeanSquaredError(
    _ prediction: MLXArray,
    _ target: MLXArray,
    elementMask: MLXArray
  ) -> MLXArray {
    let denominator = maximum(elementMask.sum(), MLXArray(Float(1)))
    return (square(prediction - target) * elementMask).sum() / denominator
  }
}

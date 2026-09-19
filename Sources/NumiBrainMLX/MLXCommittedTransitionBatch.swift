import Foundation
import MLX
import NumiBrainCore
import NumiBrainMetal

private typealias TransitionABI = BrainExecutableModelContract.CommittedTransition

/// Zero-copy MLX view of committed-transition slots. Every valid record carries
/// 19 recurrent features, five exact structured world-context features,
/// accepted somatic-synergy, autonomic, active-sensing, and internal action
/// features,
/// bounded plasticity/cerebellar traces, and accepted body-joint state; empty
/// ring slots are excluded by `validMask`.
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
  /// `[pain, pleasure, relief, energy, respiration, temperature, fatigue, tissue damage]`.
  public let affect: MLXArray
  public let affectSourceValidityMask: MLXArray
  public let affectTimestamp: MLXArray
  public let teacherState: MLXArray
  public let fastPlasticityTrace: MLXArray
  public let cerebellarTrace: MLXArray
  public let activeSensingTrace: MLXArray
  public let priorEmbodiedState: MLXArray
  public let posteriorEmbodiedState: MLXArray
  public let embodiedStateMask: MLXArray
  /// Compatibility aliases for the v7 body-only trace name. In v8 these carry
  /// the complete body-and-joint summary.
  public let priorBodyState: MLXArray
  public let posteriorBodyState: MLXArray
  public let bodyStateMask: MLXArray
  public let acceptedStopMask: MLXArray
  public let teacherMask: MLXArray
  public let imitationMask: MLXArray

  public var affectLearningEmphasis: MLXArray {
    Self.learningEmphasis(affect: affect, sourceValidityMask: affectSourceValidityMask)
  }

  static func learningEmphasis(
    affect: MLXArray,
    sourceValidityMask: MLXArray
  ) -> MLXArray {
    precondition(affect.ndim == 2 && affect.shape[1] == TransitionABI.Count.affect)
    precondition(sourceValidityMask.shape == [affect.shape[0], 1])
    let hasCurrentEvidence = (sourceValidityMask .!= UInt32(0)).asType(.float32)
    let stateSalience = maximum(
      affect[0..., 0..<1], maximum(affect[0..., 1..<2], affect[0..., 2..<3])
    )
    return clip(stateSalience * hasCurrentEvidence, min: 0, max: 1)
  }

  public init(_ source: MetalLearningBatch) throws {
    guard source.formatVersion == MetalLearningBatch.formatVersion,
      source.transitionRecordVersion == TransitionABI.recordVersion,
      MetalLearningBatch.transitionRecordVersion == TransitionABI.recordVersion,
      source.transitionStride == TransitionABI.strideBytes,
      MetalLearningBatch.transitionStride == TransitionABI.strideBytes,
      Self.transitionStride == TransitionABI.strideBytes
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
    let abiOffset = TransitionABI.Offset.self
    let abiCount = TransitionABI.Count.self
    let identifiers = field(abiOffset.identifier, count: 1, dtype: .uint64)
    let startTimestamps = field(abiOffset.startTimestamp, count: 1, dtype: .uint64)
    let endTimestamps = field(abiOffset.endTimestamp, count: 1, dtype: .uint64)
    let sourceGenerations = field(abiOffset.sourceGeneration, count: 1, dtype: .uint64)
    let format = field(abiOffset.formatVersion, count: 1, dtype: .uint32)
    let flags = field(abiOffset.flags, count: 1, dtype: .uint32)
    let parameterVersionFingerprints = field(
      abiOffset.parameterVersionFingerprint, count: 1, dtype: .uint64)
    let rawPrior = field(abiOffset.priorState, count: abiCount.priorState, dtype: .float32)
    let rawPosterior = field(
      abiOffset.posteriorState, count: abiCount.posteriorState, dtype: .float32)
    let rawObservations = field(abiOffset.observation, count: abiCount.observation, dtype: .float32)
    let observationValidityBits = field(abiOffset.observationValidityMask, count: 1, dtype: .uint32)
    let rawActions = field(abiOffset.somaticAction, count: abiCount.somaticAction, dtype: .float32)
    let rawReinforcement = field(
      abiOffset.factoredReinforcement, count: abiCount.factoredReinforcement, dtype: .float32)
    let rawMetrics = field(
      abiOffset.outcomeMetrics, count: abiCount.outcomeMetrics, dtype: .float32)
    let rawTeacher = field(abiOffset.teacherState, count: abiCount.teacherState, dtype: .float32)
    let rawFastPlasticityTrace = field(
      abiOffset.fastPlasticityTrace, count: abiCount.fastPlasticityTrace, dtype: .float32)
    let rawCerebellarTrace = field(
      abiOffset.cerebellarTrace, count: abiCount.cerebellarTrace, dtype: .float32)
    let rawActiveSensingTrace = field(
      abiOffset.activeSensingTrace, count: abiCount.activeSensingTrace, dtype: .float32)
    let completeActionCounts = field(abiOffset.autonomicActionSampleCount, count: 4, dtype: .uint32)
    let rawAutonomicActions = field(
      abiOffset.autonomicAction, count: abiCount.autonomicAction, dtype: .float32)
    let rawActiveSensingActions = field(
      abiOffset.activeSensingAction, count: abiCount.activeSensingAction, dtype: .float32)
    let rawInternalActions = field(
      abiOffset.internalAction, count: abiCount.internalAction, dtype: .float32)
    let rawBodySchemaTrace = field(
      abiOffset.bodySchemaTrace, count: abiCount.bodySchemaTrace, dtype: .float32)
    let rawAffect = field(abiOffset.affect, count: abiCount.affect, dtype: .float32)
    let rawAffectSourceValidityMask = field(
      abiOffset.affectSourceValidityMask, count: 1, dtype: .uint32)
    let rawAffectReserved = field(abiOffset.affectReserved, count: 1, dtype: .uint32)
    let rawAffectTimestamp = field(abiOffset.affectTimestamp, count: 1, dtype: .uint64)
    let completeActionCountsValid = (
      (completeActionCounts[0..., 0..<1] .<= UInt32(8))
        * (completeActionCounts[0..., 1..<2] .<= UInt32(8))
        * (completeActionCounts[0..., 2..<3] .<= UInt32(8))
        * ((completeActionCounts[0..., 3..<4] & UInt32(1)) .== UInt32(1))
    ).asType(.float32)
    let affectRangeValid = (
      ((rawAffect .>= Float(0)).asType(.float32)
        * (rawAffect .<= Float(1)).asType(.float32))
        .sum(axis: 1, keepDims: true)
        .== Float(TransitionABI.Count.affect)
    ).asType(.float32)
    let affectMetadataValid = (
      (rawAffectTimestamp .== endTimestamps)
        * (rawAffectReserved .== UInt32(0))
        * ((rawAffectSourceValidityMask & UInt32(0xffff_ffc0)) .== UInt32(0))
    ).asType(.float32) * allFinite(rawAffect, count: TransitionABI.Count.affect)
      * affectRangeValid
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
      * affectMetadataValid
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
    let teacherCount = field(TransitionABI.Offset.teacherScalarCount, count: 1, dtype: .uint32)
    let teacherFlags = field(TransitionABI.Offset.teacherFlags, count: 1, dtype: .uint32)
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
    self.activeOptionIdentifiers = field(
      TransitionABI.Offset.activeOptionIdentifier, count: 1, dtype: .uint64
    )
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
    self.affect = finite(rawAffect) * validMask
    self.affectSourceValidityMask = which(
      validMask .> Float(0), rawAffectSourceValidityMask, MLXArray(UInt32(0))
    )
    self.affectTimestamp = which(
      validMask .> Float(0), rawAffectTimestamp, MLXArray(UInt64(0))
    )
    self.teacherState = finite(rawTeacher)
    self.fastPlasticityTrace = finite(rawFastPlasticityTrace)
    self.cerebellarTrace = finite(rawCerebellarTrace)
    self.activeSensingTrace = finite(rawActiveSensingTrace)
    let priorEmbodiedState = finite(rawBodySchemaTrace[0..., 0..<8])
    let posteriorEmbodiedState = finite(rawBodySchemaTrace[0..., 8..<16])
    let embodiedStateMask = ((flags & UInt32(2)) .== UInt32(2)).asType(.float32)
      * validMask
    self.priorEmbodiedState = priorEmbodiedState
    self.posteriorEmbodiedState = posteriorEmbodiedState
    self.embodiedStateMask = embodiedStateMask
    self.priorBodyState = priorEmbodiedState
    self.posteriorBodyState = posteriorEmbodiedState
    self.bodyStateMask = embodiedStateMask
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

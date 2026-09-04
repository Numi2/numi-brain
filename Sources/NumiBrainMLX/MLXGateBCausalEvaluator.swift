import Foundation
import MLX
import NumiBrainCore
import NumiBrainMetal

@frozen
public enum NumanXGateBInterventionKind: UInt16, Codable, CaseIterable, Sendable {
  case intact = 1
  case ablated = 2
  case valueShuffled = 3
  case timestampShifted = 4
}

/// One off-rollout evaluation of the learned one-step belief/policy head.
/// This is intervention evidence over immutable accepted transitions; it is
/// deliberately not described as a physical task-success result.
@frozen
public struct NumanXGateBPolicyHeadEvaluation: Codable, Equatable, Sendable {
  public let modality: SensoryModality
  public let intervention: NumanXGateBInterventionKind
  public let parameterVersionFingerprint: UInt64
  public let sourceBatchFingerprint: UInt64
  public let minimumGeneration: UInt64
  public let maximumGeneration: UInt64
  public let transitionCount: UInt32
  public let actionMeanSquaredError: Float
  public let actionDeltaFromIntact: Float

  public init(
    modality: SensoryModality,
    intervention: NumanXGateBInterventionKind,
    parameterVersionFingerprint: UInt64,
    sourceBatchFingerprint: UInt64,
    minimumGeneration: UInt64,
    maximumGeneration: UInt64,
    transitionCount: UInt32,
    actionMeanSquaredError: Float,
    actionDeltaFromIntact: Float
  ) throws {
    guard parameterVersionFingerprint > 0, sourceBatchFingerprint > 0,
      minimumGeneration > 0, minimumGeneration <= maximumGeneration,
      transitionCount > 0, actionMeanSquaredError.isFinite,
      actionMeanSquaredError >= 0, actionDeltaFromIntact.isFinite,
      actionDeltaFromIntact >= 0
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "Gate B policy-head evaluation is invalid"
      )
    }
    self.modality = modality
    self.intervention = intervention
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.sourceBatchFingerprint = sourceBatchFingerprint
    self.minimumGeneration = minimumGeneration
    self.maximumGeneration = maximumGeneration
    self.transitionCount = transitionCount
    self.actionMeanSquaredError = actionMeanSquaredError
    self.actionDeltaFromIntact = actionDeltaFromIntact
  }
}

/// Deterministic off-rollout evaluator used to prepare Gate B's physical task
/// qualification. It executes the same one-step belief and policy-head
/// relations optimized by `MLXBrainLearner`, but never mutates a rollout.
@available(macOS 26.0, *)
public final class MLXGateBCausalEvaluator: @unchecked Sendable {
  public init() {}

  public func evaluate(
    publication: BrainParameterPublication,
    batch source: MetalLearningBatch,
    species: SpeciesTemplate,
    modality: SensoryModality,
    minimumGeneration: UInt64,
    maximumGeneration: UInt64,
    shuffleSeed: UInt64 = 1
  ) throws -> [NumanXGateBPolicyHeadEvaluation] {
    guard minimumGeneration > 0, minimumGeneration <= maximumGeneration,
      source.speciesTemplateFingerprint == species.fingerprint,
      publication.version.parentFingerprint == source.parameterVersionFingerprint,
      publication.sourceBatchFingerprint > 0,
      publication.sourceGeneration < minimumGeneration,
      let modalitySlot = species.senses
        .filter(\.enabled)
        .sorted(by: { $0.modality.rawValue < $1.modality.rawValue })
        .map(\.modality)
        .firstIndex(of: modality),
      modalitySlot < 8
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "Gate B evaluation is not an exact held-out successor/modality split"
      )
    }
    try publication.sharedArtifact.validate(parameterVersion: publication.version)
    let batch = try MLXCommittedTransitionBatch(source)
    let sequences = try MLXCommittedSequenceBatch(batch)
    let metadata = try Self.transitionMetadata(source)
    // Resolve the full finite/format/version mask at this immutable offline
    // boundary. Reported counts and intervention donors must use that same
    // mask, not a weaker metadata-only approximation.
    let validRows = batch.validMask.asArray(Float.self)
    let selectedRows = metadata.indices.filter {
      metadata[$0].valid && validRows[$0] > 0
        && metadata[$0].generation >= minimumGeneration
        && metadata[$0].generation <= maximumGeneration
    }.sorted { metadata[$0].generation < metadata[$1].generation }
    guard !selectedRows.isEmpty, let transitionCount = UInt32(exactly: selectedRows.count)
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "Gate B evaluation has no held-out accepted transitions"
      )
    }

    let capacity = source.transitionCapacity
    var rowMaskValues = [Float](repeating: 0, count: capacity)
    for row in selectedRows { rowMaskValues[row] = 1 }
    let rowMask = MLXArray(rowMaskValues, [capacity, 1]) * batch.validMask
    let belief = Self.parameter(.belief, publication: publication)
    let policy = Self.parameter(.policy, publication: publication)
    guard belief.size > 15, policy.size > 8 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "Gate B evaluation parameter payload is undersized"
      )
    }
    let intactPrediction = Self.predictedAction(
      prior: batch.priorState,
      observations: batch.observations,
      observationMask: batch.observationMask,
      belief: belief,
      policy: policy
    )
    let intactMSE = Self.maskedMSE(
      intactPrediction, batch.actions, mask: rowMask
    )
    let componentStart = modalitySlot * 3
    let componentRange = componentStart..<(componentStart + 3)
    let zeroGroup = MLXArray(
      [Float](repeating: 0, count: capacity * 3), [capacity, 3]
    )
    let interventionIndex = try BrainObservationInterventionIndex(
      sequenceIndex: sequences.index,
      selectedRows: selectedRows,
      observationValidityBits: metadata.map(\.observationValidityBits),
      componentStart: componentStart,
      shuffleSeed: shuffleSeed
    )
    let shuffledIndices = MLXArray(interventionIndex.shuffledRows)
    let shiftedIndices = MLXArray(interventionIndex.shiftedRows.map { max($0, 0) })
    let shiftedExistsMask = MLXArray(
      interventionIndex.shiftedRows.map { $0 >= 0 ? Float(1) : Float(0) },
      [capacity, 1]
    )
    let variants: [(NumanXGateBInterventionKind, MLXArray, MLXArray)] = [
      (.intact, batch.observations, batch.observationMask),
      (
        .ablated,
        Self.replacingColumns(
          batch.observations, range: componentRange, with: zeroGroup
        ),
        Self.replacingColumns(
          batch.observationMask, range: componentRange, with: zeroGroup
        )
      ),
      (
        .valueShuffled,
        Self.replacingColumns(
          batch.observations,
          range: componentRange,
          with: batch.observations.take(
            shuffledIndices, axis: 0
          )[0..., componentRange]
        ),
        batch.observationMask
      ),
      (
        .timestampShifted,
        Self.replacingColumns(
          batch.observations,
          range: componentRange,
          with: Self.shiftedGroup(
            batch.observations, range: componentRange,
            indices: shiftedIndices, exists: shiftedExistsMask
          )
        ),
        Self.replacingColumns(
          batch.observationMask,
          range: componentRange,
          with: Self.shiftedGroup(
            batch.observationMask, range: componentRange,
            indices: shiftedIndices, exists: shiftedExistsMask
          )
        )
      ),
    ]
    let predictions = variants.map { _, observations, mask in
      Self.predictedAction(
        prior: batch.priorState,
        observations: observations,
        observationMask: mask,
        belief: belief,
        policy: policy
      )
    }
    let metrics = zip(variants, predictions).flatMap { variant, prediction in
      [
        Self.maskedMSE(prediction, batch.actions, mask: rowMask),
        Self.maskedMSE(prediction, intactPrediction, mask: rowMask),
      ]
    }
    eval(predictions + metrics + [intactMSE])
    return try zip(variants.indices, variants).map { index, variant in
      try NumanXGateBPolicyHeadEvaluation(
        modality: modality,
        intervention: variant.0,
        parameterVersionFingerprint: publication.version.fingerprint,
        sourceBatchFingerprint: source.batchFingerprint,
        minimumGeneration: minimumGeneration,
        maximumGeneration: maximumGeneration,
        transitionCount: transitionCount,
        actionMeanSquaredError: metrics[index * 2].item(Float.self),
        actionDeltaFromIntact: metrics[index * 2 + 1].item(Float.self)
      )
    }
  }

  private struct TransitionMetadata {
    let valid: Bool
    let generation: UInt64
    let observationValidityBits: UInt32
  }

  private static func transitionMetadata(
    _ source: MetalLearningBatch
  ) throws -> [TransitionMetadata] {
    let lease = try source.makeSharedStorageLease()
    return (0..<source.transitionCapacity).map { index in
      let record = lease.baseAddress.advanced(by: index * source.transitionStride)
      let identifier = record.load(as: UInt64.self)
      let generation = record.advanced(by: 32).load(as: UInt64.self)
      let format = record.advanced(by: 64).load(as: UInt32.self)
      let flags = record.advanced(by: 68).load(as: UInt32.self)
      return TransitionMetadata(
        valid: identifier > 0
          && format == MetalLearningBatch.transitionRecordVersion
          && (flags & 1) == 1,
        generation: generation,
        observationValidityBits: record.advanced(by: 92).load(as: UInt32.self)
      )
    }
  }

  private static func parameter(
    _ kind: BrainParameterComponentKind,
    publication: BrainParameterPublication
  ) -> MLXArray {
    let data = publication.sharedArtifact.payload(kind).data
    return MLXArray(
      data, [data.count / MemoryLayout<Float>.stride], type: Float.self
    )
  }

  private static func predictedAction(
    prior: MLXArray,
    observations: MLXArray,
    observationMask: MLXArray,
    belief: MLXArray,
    policy: MLXArray
  ) -> MLXArray {
    MLXEmbodiedPolicyHead.predict(
      prior: prior, observations: observations, observationMask: observationMask,
      belief: belief, policy: policy
    )
  }

  /// A missing or non-held-out predecessor means unavailable evidence, not a
  /// zero-valued valid receptor. Apply the same selection to values and masks.
  static func shiftedGroup(
    _ source: MLXArray,
    range: Range<Int>,
    indices: MLXArray,
    exists: MLXArray
  ) -> MLXArray {
    which(
      exists .> Float(0), source.take(indices, axis: 0)[0..., range],
      MLXArray(Float(0))
    )
  }

  static func maskedMSE(
    _ prediction: MLXArray,
    _ target: MLXArray,
    mask: MLXArray
  ) -> MLXArray {
    let denominator = maximum(mask.sum() * Float(16), MLXArray(Float(1)))
    let difference = which(mask .> Float(0), prediction - target, MLXArray(Float(0)))
    return (square(difference) * mask).sum() / denominator
  }

  private static func replacingColumns(
    _ source: MLXArray,
    range: Range<Int>,
    with replacement: MLXArray
  ) -> MLXArray {
    var pieces: [MLXArray] = []
    if range.lowerBound > 0 {
      pieces.append(source[0..., 0..<range.lowerBound])
    }
    pieces.append(replacement)
    if range.upperBound < source.shape[1] {
      pieces.append(source[0..., range.upperBound..<source.shape[1]])
    }
    return concatenated(pieces, axis: 1)
  }
}

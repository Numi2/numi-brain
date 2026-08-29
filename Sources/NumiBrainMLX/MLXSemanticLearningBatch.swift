import Foundation
import MLX
import NumiBrainCore
import NumiBrainMetal

/// Committed explicit semantic graph plus semantic-consolidation replay
/// priorities. Relation endpoints are resolved against the same immutable
/// concept generation before any loss is formed.
@available(macOS 26.0, *)
public struct MLXSemanticLearningBatch: @unchecked Sendable {
  public let source: MetalLearningBatch
  public let conceptRawBytes: MLXArray
  public let relationRawBytes: MLXArray
  public let conceptValidMask: MLXArray
  public let relationValidMask: MLXArray
  public let conceptLearningMask: MLXArray
  public let relationLearningMask: MLXArray
  public let conceptConfidence: MLXArray
  public let conceptEmbedding: MLXArray
  public let relationConfidence: MLXArray
  public let relationContradiction: MLXArray
  public let relationEvidenceEmbedding: MLXArray
  public let relationSourceEmbedding: MLXArray
  public let relationDestinationEmbedding: MLXArray

  public init(_ source: MetalLearningBatch) throws {
    guard source.formatVersion == MetalLearningBatch.formatVersion,
      source.semanticRecordVersion == MetalLearningBatch.semanticRecordVersion,
      source.semanticConceptStride == MetalLearningBatch.semanticConceptStride,
      source.semanticRelationStride == MetalLearningBatch.semanticRelationStride,
      source.replayStride == MetalLearningBatch.replayStride
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX semantic-learning batch ABI is incompatible"
      )
    }
    func rawView(
      _ section: MetalLearningBatchSection,
      capacity: Int,
      stride: Int
    ) throws -> MLXArray {
      let lease = try source.makeSharedStorageLease(for: section)
      guard lease.byteCount == capacity * stride else {
        throw BrainRuntimeError.invalidParameterVersion(
          "MLX semantic-learning section byte count is incompatible"
        )
      }
      return MLXArray(
        rawPointer: lease.baseAddress,
        [capacity, stride],
        dtype: .uint8
      ) {
        _ = lease
      }
    }
    let concepts = try rawView(
      .semanticConcepts,
      capacity: source.semanticConceptCapacity,
      stride: source.semanticConceptStride
    )
    let relations = try rawView(
      .semanticRelations,
      capacity: source.semanticRelationCapacity,
      stride: source.semanticRelationStride
    )
    let replay = try rawView(
      .replayQueue,
      capacity: source.replayCapacity,
      stride: source.replayStride
    )
    func field(
      _ raw: MLXArray,
      _ byteOffset: Int,
      count: Int,
      dtype: DType
    ) -> MLXArray {
      raw[0..., byteOffset..<(byteOffset + count * dtype.size)].view(dtype: dtype)
    }
    func finite(_ values: MLXArray) -> MLXArray {
      which(isFinite(values), values, MLXArray(Float(0)))
    }

    let conceptIdentifiers = field(concepts, 0, count: 1, dtype: .uint64)
    let conceptUsage = field(concepts, 16, count: 1, dtype: .uint64)
      .asType(.float32)
    let conceptFormats = field(concepts, 32, count: 1, dtype: .uint32)
    let conceptKinds = field(concepts, 36, count: 1, dtype: .uint32)
    let conceptFlags = field(concepts, 40, count: 1, dtype: .uint32)
    let rawConceptConfidence = field(concepts, 48, count: 1, dtype: .float32)
    let rawConceptEmbedding = field(concepts, 52, count: 19, dtype: .float32)
    let conceptConfidence = clip(finite(rawConceptConfidence), min: 0, max: 1)
    let conceptEmbedding = finite(rawConceptEmbedding)
    let conceptFiniteMask = (
      isFinite(rawConceptEmbedding).asType(.float32).sum(
        axis: 1, keepDims: true
      ) .== Float(19)
    ).asType(.float32) * isFinite(rawConceptConfidence).asType(.float32)
    let conceptValidMask = (
      (conceptIdentifiers .> UInt64(0))
        * (conceptFormats .== source.semanticRecordVersion)
        * (conceptKinds .>= UInt32(SemanticConceptKind.entity.rawValue))
        * (conceptKinds .<= UInt32(SemanticConceptKind.rule.rawValue))
        * ((conceptFlags & UInt32(1)) .== UInt32(1))
        * (rawConceptConfidence .>= Float(0))
        * (rawConceptConfidence .<= Float(1))
    ).asType(.float32) * conceptFiniteMask

    let relationIdentifiers = field(relations, 0, count: 1, dtype: .uint64)
    let relationSourceIdentifiers = field(relations, 8, count: 1, dtype: .uint64)
    let relationDestinationIdentifiers = field(
      relations, 16, count: 1, dtype: .uint64
    )
    let relationFormats = field(relations, 32, count: 1, dtype: .uint32)
    let relationKinds = field(relations, 36, count: 1, dtype: .uint32)
    let relationFlags = field(relations, 40, count: 1, dtype: .uint32)
    let relationSupport = field(relations, 44, count: 1, dtype: .uint32)
      .asType(.float32)
    let rawRelationConfidence = field(relations, 48, count: 1, dtype: .float32)
    let rawRelationContradiction = field(relations, 52, count: 1, dtype: .float32)
    let rawRelationEvidence = field(relations, 56, count: 10, dtype: .float32)
    let relationConfidence = clip(finite(rawRelationConfidence), min: 0, max: 1)
    let relationContradiction = clip(
      finite(rawRelationContradiction), min: 0, max: 1
    )
    let relationEvidence = finite(rawRelationEvidence)
    let sourceMatches = (
      relationSourceIdentifiers .== conceptIdentifiers.transposed()
    ).asType(.float32) * conceptValidMask.transposed()
    let destinationMatches = (
      relationDestinationIdentifiers .== conceptIdentifiers.transposed()
    ).asType(.float32) * conceptValidMask.transposed()
    let sourceExists = (
      sourceMatches.sum(axis: 1, keepDims: true) .== Float(1)
    ).asType(.float32)
    let destinationExists = (
      destinationMatches.sum(axis: 1, keepDims: true) .== Float(1)
    ).asType(.float32)
    let relationFiniteMask = (
      isFinite(rawRelationEvidence).asType(.float32).sum(
        axis: 1, keepDims: true
      ) .== Float(10)
    ).asType(.float32)
      * isFinite(rawRelationConfidence).asType(.float32)
      * isFinite(rawRelationContradiction).asType(.float32)
    let relationValidMask = (
      (relationIdentifiers .> UInt64(0))
        * (relationSourceIdentifiers .> UInt64(0))
        * (relationDestinationIdentifiers .> UInt64(0))
        * (relationSourceIdentifiers .!= relationDestinationIdentifiers)
        * (relationFormats .== source.semanticRecordVersion)
        * (relationKinds .>= UInt32(SemanticRelationKind.isA.rawValue))
        * (relationKinds .<= UInt32(SemanticRelationKind.associatedWith.rawValue))
        * ((relationFlags & UInt32(1)) .== UInt32(1))
        * (relationSupport .> Float(0))
        * (rawRelationConfidence .>= Float(0))
        * (rawRelationConfidence .<= Float(1))
        * (rawRelationContradiction .>= Float(0))
        * (rawRelationContradiction .<= Float(1))
    ).asType(.float32) * relationFiniteMask * sourceExists * destinationExists

    let replayQueueKinds = field(replay, 0, count: 1, dtype: .uint32)
    let replayRecordKinds = field(replay, 4, count: 1, dtype: .uint32)
    let replayIdentifiers = field(replay, 8, count: 1, dtype: .uint64)
    let rawReplayPriorities = field(replay, 16, count: 1, dtype: .float32)
    let replayCounts = field(replay, 20, count: 1, dtype: .uint32)
      .asType(.float32)
    let replayMask = (
      (replayIdentifiers .> UInt64(0))
        * (replayQueueKinds
          .== UInt32(ReplayQueueKind.semanticConsolidation.rawValue))
        * (rawReplayPriorities .> Float(0))
        * isFinite(rawReplayPriorities)
    ).asType(.float32)
    let replayPriority = replayMask * which(
      isFinite(rawReplayPriorities),
      clip(rawReplayPriorities, min: 0, max: 2),
      MLXArray(Float(0))
    ) / (Float(1) + Float(0.25) * replayCounts)
    func replayWeights(
      identifiers: MLXArray,
      recordKind: ReplayRecordKind
    ) -> MLXArray {
      let kindMask = (
        replayRecordKinds .== UInt32(recordKind.rawValue)
      ).asType(.float32)
      let matches = (
        replayIdentifiers .== identifiers.transposed()
      ).asType(.float32)
      return (
        matches * replayPriority * kindMask
      ).sum(axis: 0).expandedDimensions(axis: 1)
    }
    let conceptReplay = replayWeights(
      identifiers: conceptIdentifiers, recordKind: .semanticConcept
    )
    let relationReplay = replayWeights(
      identifiers: relationIdentifiers, recordKind: .semanticRelation
    )

    self.source = source
    self.conceptRawBytes = concepts
    self.relationRawBytes = relations
    self.conceptValidMask = conceptValidMask
    self.relationValidMask = relationValidMask
    self.conceptLearningMask = conceptValidMask
      * (Float(0.25) + conceptConfidence)
      * (Float(1) + conceptReplay)
      * (Float(1) + clip(conceptUsage, min: 0, max: 32) / Float(32))
    self.relationLearningMask = relationValidMask
      * (Float(0.25) + relationConfidence)
      * (Float(1) + relationReplay)
      * (Float(1) + clip(relationSupport, min: 0, max: 32) / Float(32))
    self.conceptConfidence = conceptConfidence
    self.conceptEmbedding = conceptEmbedding
    self.relationConfidence = relationConfidence
    self.relationContradiction = relationContradiction
    self.relationEvidenceEmbedding = relationEvidence
    self.relationSourceEmbedding = sourceMatches.matmul(conceptEmbedding)
    self.relationDestinationEmbedding = destinationMatches.matmul(conceptEmbedding)
  }

  public func conceptMaskedMeanSquaredError(
    _ prediction: MLXArray,
    _ target: MLXArray
  ) -> MLXArray {
    maskedMean(
      square(prediction - target),
      mask: conceptLearningMask,
      capacity: source.semanticConceptCapacity
    )
  }

  public func relationMaskedMeanSquaredError(
    _ prediction: MLXArray,
    _ target: MLXArray
  ) -> MLXArray {
    maskedMean(
      square(prediction - target),
      mask: relationLearningMask,
      capacity: source.semanticRelationCapacity
    )
  }

  private func maskedMean(
    _ values: MLXArray,
    mask: MLXArray,
    capacity: Int
  ) -> MLXArray {
    let valuesPerRecord = max(values.size / max(capacity, 1), 1)
    let denominator = maximum(
      mask.sum() * Float(valuesPerRecord), MLXArray(Float(1))
    )
    return (values * mask).sum() / denominator
  }
}

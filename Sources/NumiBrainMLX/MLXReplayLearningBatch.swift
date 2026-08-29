import Foundation
import MLX
import NumiBrainCore
import NumiBrainMetal

/// Typed zero-copy views over committed explicit memory and its replay queue.
/// These records are all accepted lived experience or skills distilled from
/// accepted experience. Imagined trajectories are deliberately not accepted
/// by this ABI and cannot be mislabeled as episodic memory.
@available(macOS 26.0, *)
public struct MLXReplayLearningBatch: @unchecked Sendable {
  public let source: MetalLearningBatch
  public let activeEpisodeRawBytes: MLXArray
  public let warmEpisodeRawBytes: MLXArray
  public let skillRawBytes: MLXArray
  public let replayRawBytes: MLXArray

  public let episodeValidMask: MLXArray
  public let episodeStartTimestamps: MLXArray
  public let episodeEndTimestamps: MLXArray
  public let episodeOptionIdentifiers: MLXArray
  public let episodeSalience: MLXArray
  public let episodeUncertainty: MLXArray
  public let episodeDamage: MLXArray
  public let episodeReinforcement: MLXArray
  public let episodeRetrievalKeys: MLXArray
  public let episodeReplayWeights: MLXArray
  public let episodeThreatWeights: MLXArray
  public let episodeRareEventWeights: MLXArray

  public let skillValidMask: MLXArray
  public let skillCompetence: MLXArray
  public let skillDamageCVaR: MLXArray
  public let skillExpectedEffort: MLXArray
  public let skillExpectedValue: MLXArray
  public let skillOutcomeUncertainty: MLXArray
  public let skillExpectedFactoredValue: MLXArray
  public let skillInitiationModel: MLXArray
  public let skillPolicyCode: MLXArray
  public let skillOutcomeModel: MLXArray
  public let skillReplayWeights: MLXArray

  public let replayValidMask: MLXArray
  public let replayEffectivePriority: MLXArray

  public init(_ source: MetalLearningBatch) throws {
    guard source.formatVersion == MetalLearningBatch.formatVersion,
      source.episodicRecordVersion == MetalLearningBatch.episodicRecordVersion,
      source.proceduralRecordVersion == MetalLearningBatch.proceduralRecordVersion,
      source.replayRecordVersion == MetalLearningBatch.replayRecordVersion,
      source.episodicStride == MetalLearningBatch.episodicStride,
      source.warmEpisodicStride == MetalLearningBatch.warmEpisodicStride,
      source.proceduralStride == MetalLearningBatch.proceduralStride,
      source.replayStride == MetalLearningBatch.replayStride
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX replay-learning batch ABI is incompatible"
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
          "MLX replay-learning section byte count is incompatible"
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
    let activeEpisodes = try rawView(
      .activeEpisodes,
      capacity: source.episodicCapacity,
      stride: source.episodicStride
    )
    let warmEpisodes = try rawView(
      .warmEpisodes,
      capacity: source.warmEpisodicCapacity,
      stride: source.warmEpisodicStride
    )
    let skills = try rawView(
      .proceduralSkills,
      capacity: source.proceduralCapacity,
      stride: source.proceduralStride
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
    func episodeField(
      _ byteOffset: Int,
      count: Int,
      dtype: DType
    ) -> MLXArray {
      concatenated([
        field(activeEpisodes, byteOffset, count: count, dtype: dtype),
        field(warmEpisodes, byteOffset, count: count, dtype: dtype),
      ])
    }

    let episodeIdentifiers = episodeField(0, count: 1, dtype: .uint64)
    let episodeStartTimestamps = episodeField(8, count: 1, dtype: .uint64)
    let episodeEndTimestamps = episodeField(16, count: 1, dtype: .uint64)
    let episodeSourceGenerations = episodeField(32, count: 1, dtype: .uint64)
    let episodeOptionIdentifiers = episodeField(48, count: 1, dtype: .uint64)
    let episodeFormats = episodeField(56, count: 1, dtype: .uint32)
    let episodeValidMask = (
      (episodeIdentifiers .> UInt64(0))
        * (episodeFormats .== source.episodicRecordVersion)
        * (episodeSourceGenerations .<= source.sourceGeneration)
        * (episodeEndTimestamps .>= episodeStartTimestamps)
    ).asType(.float32)

    let skillIdentifiers = field(skills, 0, count: 1, dtype: .uint64)
    let skillFormats = field(skills, 64, count: 1, dtype: .uint32)
    let skillFlags = field(skills, 68, count: 1, dtype: .uint32)
    let skillValidMask = (
      (skillIdentifiers .> UInt64(0))
        * (skillFormats .== source.proceduralRecordVersion)
        * ((skillFlags & UInt32(4)) .== UInt32(0))
    ).asType(.float32)

    let replayQueueKinds = field(replay, 0, count: 1, dtype: .uint32)
    let replayRecordKinds = field(replay, 4, count: 1, dtype: .uint32)
    let replayIdentifiers = field(replay, 8, count: 1, dtype: .uint64)
    let replayPriorities = field(replay, 16, count: 1, dtype: .float32)
    let replayCounts = field(replay, 20, count: 1, dtype: .uint32).asType(.float32)
    let replayValidMask = (
      (replayIdentifiers .> UInt64(0))
        * (replayQueueKinds .>= UInt32(ReplayQueueKind.episodic.rawValue))
        * (replayQueueKinds .<= UInt32(ReplayQueueKind.rareEvent.rawValue))
        * (replayRecordKinds .>= UInt32(ReplayRecordKind.episode.rawValue))
        * (replayRecordKinds .<= UInt32(ReplayRecordKind.skill.rawValue))
        * (replayPriorities .> Float(0))
        * isFinite(replayPriorities)
    ).asType(.float32)
    let finiteReplayPriority = which(
      isFinite(replayPriorities),
      clip(replayPriorities, min: 0, max: 2),
      MLXArray(Float(0))
    )
    let replayEffectivePriority = replayValidMask
      * finiteReplayPriority
      / (Float(1) + Float(0.25) * replayCounts)

    func weights(
      identifiers: MLXArray,
      recordKind: ReplayRecordKind,
      queueKind: ReplayQueueKind? = nil
    ) -> MLXArray {
      var queueMask = replayValidMask
      if let queueKind {
        queueMask = queueMask * (
          replayQueueKinds .== UInt32(queueKind.rawValue)
        ).asType(.float32)
      }
      let recordMask = (
        replayRecordKinds .== UInt32(recordKind.rawValue)
      ).asType(.float32)
      let matches = (
        replayIdentifiers .== identifiers.transposed()
      ).asType(.float32)
      return (
        matches
          * (queueMask * recordMask * replayEffectivePriority)
      ).sum(axis: 0).expandedDimensions(axis: 1)
    }

    self.source = source
    self.activeEpisodeRawBytes = activeEpisodes
    self.warmEpisodeRawBytes = warmEpisodes
    self.skillRawBytes = skills
    self.replayRawBytes = replay
    self.episodeValidMask = episodeValidMask
    self.episodeStartTimestamps = episodeStartTimestamps
    self.episodeEndTimestamps = episodeEndTimestamps
    self.episodeOptionIdentifiers = episodeOptionIdentifiers
    self.episodeSalience = episodeField(72, count: 1, dtype: .float32)
    self.episodeUncertainty = episodeField(76, count: 1, dtype: .float32)
    self.episodeDamage = episodeField(80, count: 1, dtype: .float32)
    self.episodeReinforcement = episodeField(84, count: 1, dtype: .float32)
    self.episodeRetrievalKeys = episodeField(88, count: 10, dtype: .float32)
    self.episodeReplayWeights = weights(
      identifiers: episodeIdentifiers, recordKind: .episode
    ) * episodeValidMask
    self.episodeThreatWeights = weights(
      identifiers: episodeIdentifiers,
      recordKind: .episode,
      queueKind: .threatFailure
    ) * episodeValidMask
    self.episodeRareEventWeights = weights(
      identifiers: episodeIdentifiers,
      recordKind: .episode,
      queueKind: .rareEvent
    ) * episodeValidMask
    self.skillValidMask = skillValidMask
    self.skillCompetence = field(skills, 80, count: 1, dtype: .float32)
    self.skillDamageCVaR = field(skills, 84, count: 1, dtype: .float32)
    self.skillExpectedEffort = field(skills, 88, count: 1, dtype: .float32)
    self.skillExpectedValue = field(skills, 92, count: 1, dtype: .float32)
    self.skillOutcomeUncertainty = field(skills, 104, count: 1, dtype: .float32)
    self.skillExpectedFactoredValue = field(skills, 112, count: 8, dtype: .float32)
    self.skillInitiationModel = field(skills, 144, count: 16, dtype: .float32)
    self.skillPolicyCode = field(skills, 208, count: 16, dtype: .float32)
    self.skillOutcomeModel = field(skills, 304, count: 16, dtype: .float32)
    self.skillReplayWeights = weights(
      identifiers: skillIdentifiers, recordKind: .skill
    ) * skillValidMask
    self.replayValidMask = replayValidMask
    self.replayEffectivePriority = replayEffectivePriority
  }

  public func transitionWeights(
    for transitions: MLXCommittedTransitionBatch,
    episodeWeights: MLXArray? = nil
  ) -> MLXArray {
    let weights = episodeWeights ?? episodeReplayWeights
    let transitionTimes = transitions.endTimestamps.transposed()
    let transitionOptions = transitions.activeOptionIdentifiers.transposed()
    let matches = (
      (transitionTimes .>= episodeStartTimestamps)
        * (transitionTimes .<= episodeEndTimestamps)
        * (transitionOptions .== episodeOptionIdentifiers)
    ).asType(.float32)
    return (
      matches * weights
    ).sum(axis: 0).expandedDimensions(axis: 1) * transitions.validMask
  }

  public func episodeMaskedMean(
    _ values: MLXArray,
    mask: MLXArray? = nil
  ) -> MLXArray {
    maskedMean(
      values,
      mask: mask ?? episodeReplayWeights,
      recordCapacity: source.episodicCapacity + source.warmEpisodicCapacity
    )
  }

  public func skillMaskedMean(
    _ values: MLXArray,
    mask: MLXArray? = nil
  ) -> MLXArray {
    maskedMean(
      values,
      mask: mask ?? skillReplayWeights,
      recordCapacity: source.proceduralCapacity
    )
  }

  public func episodeMaskedMeanSquaredError(
    _ prediction: MLXArray,
    _ target: MLXArray,
    mask: MLXArray? = nil
  ) -> MLXArray {
    episodeMaskedMean(square(prediction - target), mask: mask)
  }

  public func skillMaskedMeanSquaredError(
    _ prediction: MLXArray,
    _ target: MLXArray,
    mask: MLXArray? = nil
  ) -> MLXArray {
    skillMaskedMean(square(prediction - target), mask: mask)
  }

  private func maskedMean(
    _ values: MLXArray,
    mask: MLXArray,
    recordCapacity: Int
  ) -> MLXArray {
    let valuesPerRecord = max(values.size / max(recordCapacity, 1), 1)
    let denominator = maximum(
      mask.sum() * Float(valuesPerRecord), MLXArray(Float(1))
    )
    return (values * mask).sum() / denominator
  }
}

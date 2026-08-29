import Foundation
@preconcurrency import Metal
import NumiBrainCore

/// Identifies one immutable committed-memory view carried into an off-rollout
/// learner update. Imagined trajectories require a different provenance kind
/// and are intentionally absent from this lived-experience batch.
@frozen
public enum MetalLearningBatchSection: UInt16, CaseIterable, Sendable {
  case committedTransitions = 1
  case activeEpisodes = 2
  case warmEpisodes = 3
  case proceduralSkills = 4
  case replayQueue = 5
  case imaginedCounterfactuals = 6
  case semanticConcepts = 7
  case semanticRelations = 8
  case regionalTransitions = 9
}

@frozen
public struct MetalCounterfactualLearningFlags: OptionSet, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) { self.rawValue = rawValue }

  public static let valid = Self(rawValue: 1 << 0)
  public static let imagined = Self(rawValue: 1 << 1)
  public static let admissible = Self(rawValue: 1 << 2)
}

/// Retains one immutable shared Metal allocation while an external batch
/// learner imports its unified-memory address. A lease never exposes the
/// mutable persistent store from which the section was frozen.
@available(macOS 26.0, *)
public final class MetalLearningBatchStorageLease: @unchecked Sendable {
  public let section: MetalLearningBatchSection
  public let baseAddress: UnsafeMutableRawPointer
  public let byteCount: Int

  private let buffer: any MTLBuffer

  fileprivate init(
    section: MetalLearningBatchSection,
    buffer: any MTLBuffer
  ) throws {
    guard buffer.storageMode == .shared, buffer.length > 0 else {
      throw TissueError.transaction("learning batch section is not shared unified memory")
    }
    self.section = section
    self.baseAddress = buffer.contents()
    self.byteCount = buffer.length
    self.buffer = buffer
  }
}

/// Immutable, generation-consistent GPU snapshot of accepted transitions,
/// lived episodic summaries, procedural skills, replay priorities, and a
/// disjoint explicitly imagined planning ring. A learner may retain it while
/// rollout resumes because every section resides in a distinct allocation.
@available(macOS 26.0, *)
public final class MetalLearningBatch: @unchecked Sendable {
  public static let formatVersion: UInt32 = 12
  public static let transitionRecordVersion: UInt32 = 8
  public static let episodicRecordVersion: UInt32 = 2
  public static let proceduralRecordVersion =
    MetalAgentMemoryLayout.proceduralSkillRecordVersion
  public static let replayRecordVersion: UInt32 = 1
  public static let counterfactualRecordVersion: UInt32 = 1
  public static let semanticRecordVersion: UInt32 = 1
  public static let regionalTransitionRecordVersion: UInt32 = 2
  public static let transitionStride = MetalAgentMemoryLayout.committedTransitionStride
  public static let episodicStride = MetalAgentMemoryLayout.activeEpisodeStride
  public static let warmEpisodicStride =
    MetalAgentMemoryLayout.compressedEpisodeMetadataStride
  public static let proceduralStride = MetalAgentMemoryLayout.proceduralSkillStride
  public static let replayStride = MetalAgentMemoryLayout.replayQueueStride
  public static let counterfactualStride =
    MetalAgentMemoryLayout.counterfactualRolloutStride
  public static let semanticConceptStride =
    MetalAgentMemoryLayout.semanticConceptStride
  public static let semanticRelationStride =
    MetalAgentMemoryLayout.semanticRelationStride
  public static let regionalTransitionStride =
    MetalAgentMemoryLayout.regionalTransitionStride

  public let formatVersion: UInt32
  public let transitionRecordVersion: UInt32
  public let episodicRecordVersion: UInt32
  public let proceduralRecordVersion: UInt32
  public let replayRecordVersion: UInt32
  public let counterfactualRecordVersion: UInt32
  public let semanticRecordVersion: UInt32
  public let regionalTransitionRecordVersion: UInt32
  public let sourceGeneration: UInt64
  public let speciesTemplateFingerprint: UInt64
  public let regionalProgramFingerprint: UInt64
  public let scheduleFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  public let transitionCapacity: Int
  public let episodicCapacity: Int
  public let warmEpisodicCapacity: Int
  public let proceduralCapacity: Int
  public let replayCapacity: Int
  public let counterfactualCapacity: Int
  public let semanticConceptCapacity: Int
  public let semanticRelationCapacity: Int
  public let regionalTransitionCapacity: Int
  public let regionalModuleCount: Int
  public let transitionStride: Int
  public let episodicStride: Int
  public let warmEpisodicStride: Int
  public let proceduralStride: Int
  public let replayStride: Int
  public let counterfactualStride: Int
  public let semanticConceptStride: Int
  public let semanticRelationStride: Int
  public let regionalTransitionStride: Int
  public let byteCount: Int
  public let gpuAddress: UInt64
  public let metadataFingerprint: UInt64
  public let contentFingerprint: UInt64
  public let batchFingerprint: UInt64

  private let buffers: [MetalLearningBatchSection: any MTLBuffer]

  init(
    transitions: MetalAgentStateRuntime.PersistentSectionSnapshot,
    livedEpisodes: MetalAgentStateRuntime.PersistentSectionSnapshot,
    warmEpisodes: MetalAgentStateRuntime.PersistentSectionSnapshot,
    proceduralSkills: MetalAgentStateRuntime.PersistentSectionSnapshot,
    replayQueue: MetalAgentStateRuntime.PersistentSectionSnapshot,
    counterfactualRollouts: MetalAgentStateRuntime.PersistentSectionSnapshot,
    semanticConcepts: MetalAgentStateRuntime.PersistentSectionSnapshot,
    semanticRelations: MetalAgentStateRuntime.PersistentSectionSnapshot,
    regionalTransitions: MetalAgentStateRuntime.PersistentSectionSnapshot,
    regionalModuleCount: Int,
    speciesTemplateFingerprint: UInt64,
    regionalProgramFingerprint: UInt64,
    scheduleFingerprint: UInt64,
    parameterVersionFingerprint: UInt64
  ) throws {
    let sections: [(
      MetalLearningBatchSection,
      MetalAgentStateRuntime.PersistentSectionSnapshot,
      Int
    )] = [
      (.committedTransitions, transitions, Self.transitionStride),
      (.activeEpisodes, livedEpisodes, Self.episodicStride),
      (.warmEpisodes, warmEpisodes, Self.warmEpisodicStride),
      (.proceduralSkills, proceduralSkills, Self.proceduralStride),
      (.replayQueue, replayQueue, Self.replayStride),
      (.imaginedCounterfactuals, counterfactualRollouts, Self.counterfactualStride),
      (.semanticConcepts, semanticConcepts, Self.semanticConceptStride),
      (.semanticRelations, semanticRelations, Self.semanticRelationStride),
      (.regionalTransitions, regionalTransitions, Self.regionalTransitionStride),
    ]
    guard transitions.generation > 0,
      sections.allSatisfy({ _, snapshot, stride in
        snapshot.generation == transitions.generation
          && snapshot.elementCount > 0
          && snapshot.elementStride == stride
          && snapshot.elementCount <= Int.max / snapshot.elementStride
          && snapshot.elementCount * snapshot.elementStride == snapshot.buffer.length
          && snapshot.buffer.storageMode == .shared
      }),
      regionalModuleCount > 0, regionalModuleCount <= Int(UInt32.max),
      speciesTemplateFingerprint > 0, regionalProgramFingerprint > 0,
      scheduleFingerprint > 0, parameterVersionFingerprint > 0
    else {
      throw TissueError.transaction("learning batch identity, generation, or layout is invalid")
    }

    var metadataHash: UInt64 = 14_695_981_039_346_656_037
    for value in [
      UInt64(Self.formatVersion), UInt64(Self.transitionRecordVersion),
      UInt64(Self.episodicRecordVersion), UInt64(Self.proceduralRecordVersion),
      UInt64(Self.replayRecordVersion), UInt64(Self.counterfactualRecordVersion),
      UInt64(Self.semanticRecordVersion), transitions.generation,
      UInt64(Self.regionalTransitionRecordVersion),
      UInt64(regionalModuleCount),
      speciesTemplateFingerprint, regionalProgramFingerprint,
      scheduleFingerprint, parameterVersionFingerprint,
    ] {
      Self.mix(value, into: &metadataHash)
    }
    var contentHash: UInt64 = 14_695_981_039_346_656_037
    var totalByteCount = 0
    var sectionBuffers: [MetalLearningBatchSection: any MTLBuffer] = [:]
    for (kind, snapshot, _) in sections {
      Self.mix(UInt64(kind.rawValue), into: &metadataHash)
      Self.mix(UInt64(snapshot.elementCount), into: &metadataHash)
      Self.mix(UInt64(snapshot.elementStride), into: &metadataHash)
      Self.mix(UInt64(snapshot.buffer.length), into: &metadataHash)
      Self.mix(UInt64(kind.rawValue), into: &contentHash)
      let bytes = UnsafeRawBufferPointer(
        start: snapshot.buffer.contents(), count: snapshot.buffer.length
      )
      for byte in bytes {
        contentHash ^= UInt64(byte)
        contentHash &*= 1_099_511_628_211
      }
      let (nextByteCount, byteCountOverflow) = totalByteCount.addingReportingOverflow(
        snapshot.buffer.length
      )
      guard !byteCountOverflow else {
        throw TissueError.transaction("learning batch byte count overflows Int")
      }
      totalByteCount = nextByteCount
      sectionBuffers[kind] = snapshot.buffer
    }
    var batchHash = metadataHash
    Self.mix(contentHash, into: &batchHash)

    self.formatVersion = Self.formatVersion
    self.transitionRecordVersion = Self.transitionRecordVersion
    self.episodicRecordVersion = Self.episodicRecordVersion
    self.proceduralRecordVersion = Self.proceduralRecordVersion
    self.replayRecordVersion = Self.replayRecordVersion
    self.counterfactualRecordVersion = Self.counterfactualRecordVersion
    self.semanticRecordVersion = Self.semanticRecordVersion
    self.regionalTransitionRecordVersion = Self.regionalTransitionRecordVersion
    self.sourceGeneration = transitions.generation
    self.speciesTemplateFingerprint = speciesTemplateFingerprint
    self.regionalProgramFingerprint = regionalProgramFingerprint
    self.scheduleFingerprint = scheduleFingerprint
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.transitionCapacity = transitions.elementCount
    self.episodicCapacity = livedEpisodes.elementCount
    self.warmEpisodicCapacity = warmEpisodes.elementCount
    self.proceduralCapacity = proceduralSkills.elementCount
    self.replayCapacity = replayQueue.elementCount
    self.counterfactualCapacity = counterfactualRollouts.elementCount
    self.semanticConceptCapacity = semanticConcepts.elementCount
    self.semanticRelationCapacity = semanticRelations.elementCount
    self.regionalTransitionCapacity = regionalTransitions.elementCount
    self.regionalModuleCount = regionalModuleCount
    self.transitionStride = transitions.elementStride
    self.episodicStride = livedEpisodes.elementStride
    self.warmEpisodicStride = warmEpisodes.elementStride
    self.proceduralStride = proceduralSkills.elementStride
    self.replayStride = replayQueue.elementStride
    self.counterfactualStride = counterfactualRollouts.elementStride
    self.semanticConceptStride = semanticConcepts.elementStride
    self.semanticRelationStride = semanticRelations.elementStride
    self.regionalTransitionStride = regionalTransitions.elementStride
    self.byteCount = totalByteCount
    self.gpuAddress = transitions.buffer.gpuAddress
    self.metadataFingerprint = metadataHash
    self.contentFingerprint = contentHash
    self.batchFingerprint = batchHash
    self.buffers = sectionBuffers
  }

  /// Compatibility accessor for callers that only retain the transition
  /// allocation. New learners should retain `residencyAllocations`.
  public var residencyAllocation: any MTLAllocation {
    buffers[.committedTransitions]!
  }

  public var residencyAllocations: [any MTLAllocation] {
    MetalLearningBatchSection.allCases.compactMap { buffers[$0] }
  }

  public var metalBufferObject: UnsafeMutableRawPointer {
    Unmanaged.passUnretained(buffers[.committedTransitions]! as AnyObject).toOpaque()
  }

  public func metalBufferObject(
    for section: MetalLearningBatchSection
  ) -> UnsafeMutableRawPointer {
    Unmanaged.passUnretained(buffers[section]! as AnyObject).toOpaque()
  }

  /// Creates a lifetime-safe zero-copy import lease for MLX. This is a learner
  /// synchronization boundary, never a production stepping-path readback.
  public func makeSharedStorageLease(
    for section: MetalLearningBatchSection = .committedTransitions
  ) throws -> MetalLearningBatchStorageLease {
    guard let buffer = buffers[section] else {
      throw TissueError.transaction("learning batch section is absent")
    }
    return try MetalLearningBatchStorageLease(section: section, buffer: buffer)
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    var value = value.littleEndian
    withUnsafeBytes(of: &value) { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }
}

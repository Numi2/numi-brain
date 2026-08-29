import Foundation
import NumiBrainCore

/// One independently owned mind contributing an immutable committed snapshot
/// to a shared slow-parameter update. Identity is supplied by the rollout
/// orchestrator because environment and episode counters are not persistent
/// agent identities.
@available(macOS 26.0, *)
@frozen
public struct MetalLearningCohortMember: @unchecked Sendable {
  public let mindIdentifier: UInt64
  public let batch: MetalLearningBatch

  public init(
    mindIdentifier: UInt64,
    batch: MetalLearningBatch
  ) throws {
    guard mindIdentifier > 0 else {
      throw TissueError.transaction("learning cohort mind identity is invalid")
    }
    self.mindIdentifier = mindIdentifier
    self.batch = batch
  }
}

/// Canonical immutable learner input spanning several independent minds. The
/// cohort retains each snapshot as a separate allocation graph: recurrent
/// state, memories, drives, and histories are never concatenated or published
/// as shared agent state.
@available(macOS 26.0, *)
public final class MetalLearningCohortBatch: @unchecked Sendable {
  public static let formatVersion: UInt32 = 1
  public static let maximumMemberCount = 16_384

  public let formatVersion: UInt32
  public let members: [MetalLearningCohortMember]
  public let parameterVersionFingerprint: UInt64
  public let regionalProgramFingerprint: UInt64
  public let scheduleFingerprint: UInt64
  public let speciesTemplateFingerprints: [UInt64]
  public let minimumSourceGeneration: UInt64
  public let sourceGeneration: UInt64
  public let byteCount: Int
  public let cohortFingerprint: UInt64

  public var memberCount: Int { members.count }

  public init(members requestedMembers: [MetalLearningCohortMember]) throws {
    guard !requestedMembers.isEmpty,
      requestedMembers.count <= Self.maximumMemberCount
    else {
      throw TissueError.transaction("learning cohort member count is invalid")
    }
    let members = requestedMembers.sorted {
      $0.mindIdentifier < $1.mindIdentifier
    }
    guard Set(members.map(\.mindIdentifier)).count == members.count,
      Set(members.map { ObjectIdentifier($0.batch) }).count == members.count,
      let first = members.first
    else {
      throw TissueError.transaction(
        "learning cohort repeats a mind identity or immutable batch object"
      )
    }
    let parameterFingerprint = first.batch.parameterVersionFingerprint
    let regionalFingerprint = first.batch.regionalProgramFingerprint
    let scheduleFingerprint = first.batch.scheduleFingerprint
    guard parameterFingerprint > 0, regionalFingerprint > 0,
      scheduleFingerprint > 0,
      members.allSatisfy({ member in
        let batch = member.batch
        return batch.formatVersion == MetalLearningBatch.formatVersion
          && batch.parameterVersionFingerprint == parameterFingerprint
          && batch.regionalProgramFingerprint == regionalFingerprint
          && batch.scheduleFingerprint == scheduleFingerprint
          && batch.sourceGeneration > 0
          && batch.speciesTemplateFingerprint > 0
      })
    else {
      throw TissueError.transaction(
        "learning cohort members do not share one immutable parameter program"
      )
    }

    var totalByteCount = 0
    for member in members {
      let (next, overflow) = totalByteCount.addingReportingOverflow(
        member.batch.byteCount
      )
      guard !overflow else {
        throw TissueError.transaction("learning cohort byte count overflows Int")
      }
      totalByteCount = next
    }
    var hash: UInt64 = 14_695_981_039_346_656_037
    for value in [
      UInt64(Self.formatVersion), UInt64(members.count),
      parameterFingerprint, regionalFingerprint, scheduleFingerprint,
    ] {
      Self.mix(value, into: &hash)
    }
    for member in members {
      Self.mix(member.mindIdentifier, into: &hash)
      Self.mix(member.batch.speciesTemplateFingerprint, into: &hash)
      Self.mix(member.batch.sourceGeneration, into: &hash)
      Self.mix(member.batch.batchFingerprint, into: &hash)
    }

    self.formatVersion = Self.formatVersion
    self.members = members
    self.parameterVersionFingerprint = parameterFingerprint
    self.regionalProgramFingerprint = regionalFingerprint
    self.scheduleFingerprint = scheduleFingerprint
    self.speciesTemplateFingerprints = Array(
      Set(members.map { $0.batch.speciesTemplateFingerprint })
    ).sorted()
    self.minimumSourceGeneration = members.map { $0.batch.sourceGeneration }.min()!
    self.sourceGeneration = members.map { $0.batch.sourceGeneration }.max()!
    self.byteCount = totalByteCount
    self.cohortFingerprint = hash
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

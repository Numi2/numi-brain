/// Exact metadata for one accepted transition in one immutable mind's ring.
/// Empty or rejected slots must be represented by `nil`, not invented records.
/// Timestamps use the runtime's integer microsecond clock, never Float.
public struct BrainCommittedSequenceRecord: Equatable, Sendable {
  public let identifier: UInt64
  public let sourceGeneration: UInt64
  public let startTimestampMicroseconds: UInt64
  public let endTimestampMicroseconds: UInt64
  public let parameterVersionFingerprint: UInt64

  public init(
    identifier: UInt64,
    sourceGeneration: UInt64,
    startTimestampMicroseconds: UInt64,
    endTimestampMicroseconds: UInt64,
    parameterVersionFingerprint: UInt64
  ) {
    self.identifier = identifier
    self.sourceGeneration = sourceGeneration
    self.startTimestampMicroseconds = startTimestampMicroseconds
    self.endTimestampMicroseconds = endTimestampMicroseconds
    self.parameterVersionFingerprint = parameterVersionFingerprint
  }
}

public enum BrainCommittedSequenceIndexError: Error, Equatable, Sendable {
  case invalidCapacity
  case invalidIdentity
  case invalidRecord(slot: Int)
  case duplicateIdentifier(UInt64)
  case duplicateGeneration(UInt64)
}

/// Linear-storage temporal indexing for one private, immutable learning batch.
/// A successor must have exactly generation + 1, the same parameter version,
/// and a start timestamp equal to its predecessor's end timestamp. Ring order
/// is irrelevant. Missing links remain -1; they never wrap or bridge a gap.
///
/// Construction uses expected O(N) work and O(N) storage. This is an offline
/// learning operation; it does not schedule or step a production environment.
public struct BrainCommittedSequenceIndex: Equatable, Sendable {
  public static let missing: Int32 = -1

  public let oneStepSuccessors: [Int32]
  public let twoStepSuccessors: [Int32]
  public let validRecordCount: Int
  public var capacity: Int { oneStepSuccessors.count }

  public init(
    records: [BrainCommittedSequenceRecord?],
    parameterVersionFingerprint: UInt64,
    maximumSourceGeneration: UInt64
  ) throws {
    guard !records.isEmpty, records.count <= Int(Int32.max) else {
      throw BrainCommittedSequenceIndexError.invalidCapacity
    }
    guard parameterVersionFingerprint > 0 else {
      throw BrainCommittedSequenceIndexError.invalidIdentity
    }
    var generationToSlot: [UInt64: Int] = [:]
    var identifiers = Set<UInt64>()
    generationToSlot.reserveCapacity(records.count)
    identifiers.reserveCapacity(records.count)
    for (slot, record) in records.enumerated() {
      guard let record else { continue }
      guard record.identifier > 0, record.sourceGeneration > 0,
        record.sourceGeneration <= maximumSourceGeneration,
        record.startTimestampMicroseconds <= record.endTimestampMicroseconds,
        record.parameterVersionFingerprint == parameterVersionFingerprint
      else {
        throw BrainCommittedSequenceIndexError.invalidRecord(slot: slot)
      }
      guard identifiers.insert(record.identifier).inserted else {
        throw BrainCommittedSequenceIndexError.duplicateIdentifier(record.identifier)
      }
      guard generationToSlot.updateValue(slot, forKey: record.sourceGeneration) == nil
      else {
        throw BrainCommittedSequenceIndexError.duplicateGeneration(record.sourceGeneration)
      }
    }
    var one = [Int32](repeating: Self.missing, count: records.count)
    for (slot, record) in records.enumerated() {
      guard let record, record.sourceGeneration < UInt64.max,
        let nextSlot = generationToSlot[record.sourceGeneration + 1],
        let next = records[nextSlot],
        next.startTimestampMicroseconds == record.endTimestampMicroseconds
      else { continue }
      one[slot] = Int32(nextSlot)
    }
    var two = [Int32](repeating: Self.missing, count: records.count)
    for slot in one.indices where one[slot] != Self.missing {
      two[slot] = one[Int(one[slot])]
    }
    self.oneStepSuccessors = one
    self.twoStepSuccessors = two
    self.validRecordCount = generationToSlot.count
  }
}

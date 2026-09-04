public enum BrainObservationInterventionIndexError: Error, Equatable, Sendable {
  case invalidShape
  case invalidSelection
}

/// Deterministic, held-out-only indexing for a three-component receptor group.
/// Selected rows must be valid accepted rows, in stable generation order.
/// Value shuffling preserves each row's availability pattern; timestamp shifts
/// require exact committed adjacency and never borrow a training-prefix row.
public struct BrainObservationInterventionIndex: Equatable, Sendable {
  public let shuffledRows: [Int32]
  /// -1 means no selected, contiguous predecessor exists. Both values and
  /// validity must be cleared for that row by the tensor consumer.
  public let shiftedRows: [Int32]

  public init(
    sequenceIndex: BrainCommittedSequenceIndex,
    selectedRows: [Int],
    observationValidityBits: [UInt32],
    componentStart: Int,
    shuffleSeed: UInt64
  ) throws {
    let count = sequenceIndex.capacity
    guard observationValidityBits.count == count,
      componentStart >= 0, componentStart <= 21, componentStart % 3 == 0
    else { throw BrainObservationInterventionIndexError.invalidShape }
    let selected = Set(selectedRows)
    guard selected.count == selectedRows.count,
      selectedRows.allSatisfy({ $0 >= 0 && $0 < count })
    else { throw BrainObservationInterventionIndexError.invalidSelection }

    var shuffled = (0..<count).map(Int32.init)
    var shifted = [Int32](repeating: BrainCommittedSequenceIndex.missing, count: count)
    var groups = [[Int]](repeating: [], count: 8)
    for row in selectedRows {
      let signature = Int((observationValidityBits[row] >> componentStart) & 7)
      groups[signature].append(row)
      let next = sequenceIndex.oneStepSuccessors[row]
      if next >= 0, selected.contains(Int(next)) {
        shifted[Int(next)] = Int32(row)
      }
    }
    // A nonzero cyclic offset is a deterministic derangement within each
    // availability class. Singleton classes cannot be validly shuffled.
    for group in groups where group.count > 1 {
      let offset = Int(shuffleSeed % UInt64(group.count - 1)) + 1
      for (position, row) in group.enumerated() {
        shuffled[row] = Int32(group[(position + offset) % group.count])
      }
    }
    self.shuffledRows = shuffled
    self.shiftedRows = shifted
  }
}

import Foundation
import MLX
import NumiBrainCore
import NumiBrainMetal

/// Bounded temporal gathers over one private committed-transition ring.
/// Integer metadata are indexed once at the immutable learner boundary. The
/// MLX graph stores O(N) indices/masks, not N-by-N adjacency or its square.
/// Floating-point validity is still enforced on device at every edge.
@available(macOS 26.0, *)
public struct MLXCommittedSequenceBatch: @unchecked Sendable {
  public let transitions: MLXCommittedTransitionBatch
  private let gathers: MLXCommittedSequenceGathers
  public var index: BrainCommittedSequenceIndex { gathers.index }
  public var oneStepIndices: MLXArray { gathers.oneStepIndices }
  public var twoStepIndices: MLXArray { gathers.twoStepIndices }
  public var oneStepMask: MLXArray { gathers.oneStepMask }
  public var twoStepMask: MLXArray { gathers.twoStepMask }

  public init(_ transitions: MLXCommittedTransitionBatch) throws {
    let source = transitions.source
    let lease = try source.makeSharedStorageLease()
    guard source.transitionCapacity > 0,
      source.transitionCapacity <= Int(Int32.max),
      source.transitionStride >= 72,
      lease.byteCount / source.transitionStride == source.transitionCapacity,
      lease.byteCount % source.transitionStride == 0
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX temporal index has an incompatible committed-transition layout"
      )
    }
    // This reads only the already frozen shared allocation at the off-rollout
    // learning boundary. It never reads an active environment or waits inside
    // the production Metal command timeline.
    let records: [BrainCommittedSequenceRecord?] = (0..<source.transitionCapacity).map { slot in
      let bytes = UnsafeRawPointer(lease.baseAddress)
        .advanced(by: slot * source.transitionStride)
      func u64(_ offset: Int) -> UInt64 {
        UInt64(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt64.self))
      }
      func u32(_ offset: Int) -> UInt32 {
        UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
      }
      guard u64(0) > 0,
        u32(64) == MetalLearningBatch.transitionRecordVersion,
        (u32(68) & 1) == 1,
        u64(24) == source.parameterVersionFingerprint,
        u64(32) > 0, u64(32) <= source.sourceGeneration,
        u64(16) >= u64(8)
      else { return nil }
      return BrainCommittedSequenceRecord(
        identifier: u64(0), sourceGeneration: u64(32),
        startTimestampMicroseconds: u64(8), endTimestampMicroseconds: u64(16),
        parameterVersionFingerprint: u64(24)
      )
    }
    let index = try BrainCommittedSequenceIndex(
      records: records,
      parameterVersionFingerprint: source.parameterVersionFingerprint,
      maximumSourceGeneration: source.sourceGeneration
    )
    self.transitions = transitions
    self.gathers = MLXCommittedSequenceGathers(index: index, validMask: transitions.validMask)
  }

  public func oneStepSuccessors(_ values: MLXArray) -> MLXArray {
    gathers.oneStepSuccessors(values)
  }

  public func twoStepSuccessors(_ values: MLXArray) -> MLXArray {
    gathers.twoStepSuccessors(values)
  }

  /// Compatibility-only diagnostic. Explicit access allocates O(N^2) values;
  /// production learner code must use the gather methods above.
  @available(*, deprecated, message: "Use oneStepSuccessors(_:); dense adjacency is diagnostic only")
  public var oneStepAdjacency: MLXArray {
    denseAdjacency(indices: oneStepIndices, mask: oneStepMask)
  }

  /// Compatibility-only diagnostic; never materialized by this initializer.
  @available(*, deprecated, message: "Use twoStepSuccessors(_:); dense adjacency is diagnostic only")
  public var twoStepAdjacency: MLXArray {
    denseAdjacency(indices: twoStepIndices, mask: twoStepMask)
  }

  private func denseAdjacency(indices: MLXArray, mask: MLXArray) -> MLXArray {
    let columns = MLXArray((0..<index.capacity).map(Int32.init), [1, index.capacity])
    return (indices.reshaped([index.capacity, 1]) .== columns).asType(.float32) * mask
  }
}

/// Pure tensor portion, separated from snapshot decoding so the same gather
/// path can be checked with small synthetic masks without advancing physics.
@available(macOS 26.0, *)
struct MLXCommittedSequenceGathers {
  let index: BrainCommittedSequenceIndex
  let oneStepIndices: MLXArray
  let twoStepIndices: MLXArray
  let oneStepMask: MLXArray
  let twoStepMask: MLXArray

  init(index: BrainCommittedSequenceIndex, validMask: MLXArray) {
    precondition(validMask.shape == [index.capacity, 1])
    let one = MLXArray(index.oneStepSuccessors.map { max($0, 0) })
    let two = MLXArray(index.twoStepSuccessors.map { max($0, 0) })
    let exists = MLXArray(
      index.oneStepSuccessors.map { $0 >= 0 ? Float(1) : Float(0) },
      [index.capacity, 1]
    )
    let oneMask = exists * validMask
      * validMask.take(one, axis: 0)
    // Both edges must be valid. Endpoint-only masking would train across an
    // invalid intermediate record after a two-step gather.
    let twoMask = oneMask * oneMask.take(one, axis: 0)
    self.index = index
    self.oneStepIndices = one
    self.twoStepIndices = two
    self.oneStepMask = oneMask
    self.twoStepMask = twoMask
  }

  func oneStepSuccessors(_ values: MLXArray) -> MLXArray {
    gather(values, indices: oneStepIndices, mask: oneStepMask)
  }

  func twoStepSuccessors(_ values: MLXArray) -> MLXArray {
    gather(values, indices: twoStepIndices, mask: twoStepMask)
  }

  private func gather(_ values: MLXArray, indices: MLXArray, mask: MLXArray) -> MLXArray {
    precondition(values.ndim == 2 && values.shape[0] == index.capacity)
    // A missing edge gathers a safe in-bounds slot but must select zero, not
    // multiply by zero: that slot is allowed to contain a non-finite value.
    return which(mask .> Float(0), values.take(indices, axis: 0), MLXArray(Float(0)))
  }

}

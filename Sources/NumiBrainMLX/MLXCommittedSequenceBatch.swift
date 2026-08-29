import Foundation
import MLX
import NumiBrainCore
import NumiBrainMetal

/// Bounded temporal adjacency over the committed transition ring. It uses
/// generation and exact timestamp continuity rather than physical slot order,
/// so ring wrap cannot join unrelated lives. The learner unroll is fixed at
/// two steps and starts from a detached posterior burn-in state.
@available(macOS 26.0, *)
public struct MLXCommittedSequenceBatch: @unchecked Sendable {
  public let transitions: MLXCommittedTransitionBatch
  public let oneStepAdjacency: MLXArray
  public let twoStepAdjacency: MLXArray
  public let oneStepMask: MLXArray
  public let twoStepMask: MLXArray

  public init(_ transitions: MLXCommittedTransitionBatch) {
    let generations = transitions.sourceGenerations
    let successorGenerations = generations.transposed()
    let generationDelta = successorGenerations - generations
    let timestampContinuity = (
      transitions.startTimestamps.transposed() .== transitions.endTimestamps
    ).asType(.float32)
    let generationContinuity = (
      (successorGenerations .> generations)
        * (generationDelta .== UInt64(1))
    ).asType(.float32)
    let validity = transitions.validMask * transitions.validMask.transposed()
    let oneStepAdjacency = validity * timestampContinuity * generationContinuity
    let twoStepAdjacency = oneStepAdjacency.matmul(oneStepAdjacency)
    self.transitions = transitions
    self.oneStepAdjacency = oneStepAdjacency
    self.twoStepAdjacency = twoStepAdjacency
    self.oneStepMask = (
      oneStepAdjacency.sum(axis: 1, keepDims: true) .== Float(1)
    ).asType(.float32) * transitions.validMask
    self.twoStepMask = (
      twoStepAdjacency.sum(axis: 1, keepDims: true) .== Float(1)
    ).asType(.float32) * transitions.validMask
  }

  public func oneStepSuccessors(_ values: MLXArray) -> MLXArray {
    oneStepAdjacency.matmul(values)
  }

  public func twoStepSuccessors(_ values: MLXArray) -> MLXArray {
    twoStepAdjacency.matmul(values)
  }
}

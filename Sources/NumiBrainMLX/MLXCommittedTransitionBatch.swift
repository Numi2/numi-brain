import Foundation
import MLX
import NumiBrainCore
import NumiBrainMetal

/// Zero-copy MLX view of the fixed 768-byte committed-transition slots. The
/// live record occupies the first 640 bytes and the aligned tail is reserved.
/// Empty ring slots remain in the array but are excluded by `validMask`.
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
  public let actions: MLXArray
  public let factoredReinforcement: MLXArray
  public let outcomeMetrics: MLXArray
  public let teacherState: MLXArray
  public let teacherMask: MLXArray
  public let imitationMask: MLXArray

  public init(_ source: MetalLearningBatch) throws {
    guard source.formatVersion == MetalLearningBatch.formatVersion,
      source.transitionRecordVersion == MetalLearningBatch.transitionRecordVersion,
      source.transitionStride == Self.transitionStride
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
    let identifiers = field(0, count: 1, dtype: .uint64)
    let startTimestamps = field(8, count: 1, dtype: .uint64)
    let endTimestamps = field(16, count: 1, dtype: .uint64)
    let sourceGenerations = field(32, count: 1, dtype: .uint64)
    let format = field(64, count: 1, dtype: .uint32)
    let flags = field(68, count: 1, dtype: .uint32)
    let parameterVersionFingerprints = field(24, count: 1, dtype: .uint64)
    let rawPrior = field(128, count: 24, dtype: .float32)
    let rawPosterior = field(224, count: 24, dtype: .float32)
    let rawObservations = field(320, count: 24, dtype: .float32)
    let rawActions = field(416, count: 16, dtype: .float32)
    let rawReinforcement = field(480, count: 8, dtype: .float32)
    let rawMetrics = field(96, count: 8, dtype: .float32)
    let rawTeacher = field(528, count: 24, dtype: .float32)
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
    let teacherCount = field(520, count: 1, dtype: .uint32)
    let teacherFlags = field(524, count: 1, dtype: .uint32)
    let teacherFiniteMask = allFinite(rawTeacher, count: 24)
    self.source = source
    self.rawBytes = raw
    self.validMask = validMask
    self.startTimestamps = startTimestamps
    self.endTimestamps = endTimestamps
    self.sourceGenerations = sourceGenerations
    self.activeOptionIdentifiers = field(56, count: 1, dtype: .uint64)
    self.parameterVersionFingerprints = parameterVersionFingerprints
    self.priorState = finite(rawPrior)
    self.posteriorState = finite(rawPosterior)
    self.observations = finite(rawObservations)
    self.actions = finite(rawActions)
    self.factoredReinforcement = finite(rawReinforcement)
    self.outcomeMetrics = finite(rawMetrics)
    self.teacherState = finite(rawTeacher)
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
}

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
  public let endTimestamps: MLXArray
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
    let format = field(64, count: 1, dtype: .uint32)
    let parameterVersionFingerprints = field(24, count: 1, dtype: .uint64)
    let formatMask = (format .== UInt32(MetalLearningBatch.transitionRecordVersion))
      .asType(.float32)
    let versionMask = (
      parameterVersionFingerprints .== source.parameterVersionFingerprint
    ).asType(.float32)
    let validMask = formatMask * versionMask
    let teacherCount = field(520, count: 1, dtype: .uint32)
    let teacherFlags = field(524, count: 1, dtype: .uint32)
    self.source = source
    self.rawBytes = raw
    self.validMask = validMask
    self.endTimestamps = field(16, count: 1, dtype: .uint64)
    self.activeOptionIdentifiers = field(56, count: 1, dtype: .uint64)
    self.parameterVersionFingerprints = parameterVersionFingerprints
    self.priorState = field(128, count: 24, dtype: .float32)
    self.posteriorState = field(224, count: 24, dtype: .float32)
    self.observations = field(320, count: 24, dtype: .float32)
    self.actions = field(416, count: 16, dtype: .float32)
    self.factoredReinforcement = field(480, count: 8, dtype: .float32)
    self.outcomeMetrics = field(96, count: 8, dtype: .float32)
    self.teacherState = field(528, count: 24, dtype: .float32)
    self.teacherMask = (teacherCount .> UInt32(0)).asType(.float32) * validMask
    let hasDemonstratedAction = (
      teacherFlags & MetalTeacherStateFlags.demonstratedAction.rawValue
    ) .!= UInt32(0)
    self.imitationMask = hasDemonstratedAction.asType(.float32)
      * (teacherCount .> UInt32(15)).asType(.float32)
      * validMask
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

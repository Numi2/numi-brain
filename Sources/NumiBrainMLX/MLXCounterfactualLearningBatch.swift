import Foundation
import MLX
import NumiBrainCore
import NumiBrainMetal

/// Explicitly imagined planner trajectories for actor, option, value, and risk
/// learning. The source ABI requires the imagined provenance bit and has no
/// conversion path to an episodic record.
@available(macOS 26.0, *)
public struct MLXCounterfactualLearningBatch: @unchecked Sendable {
  public let source: MetalLearningBatch
  public let rawBytes: MLXArray
  public let validMask: MLXArray
  public let actorMask: MLXArray
  public let riskMask: MLXArray
  public let objectiveValue: MLXArray
  public let damageCVaR: MLXArray
  public let epistemicUncertainty: MLXArray
  public let predictedEffort: MLXArray
  public let predictedInformationGain: MLXArray
  public let predictedDriveChange: MLXArray
  public let admissibility: MLXArray
  public let predictedState: MLXArray
  public let actionParameters: MLXArray

  public init(_ source: MetalLearningBatch) throws {
    guard source.formatVersion == MetalLearningBatch.formatVersion,
      source.counterfactualRecordVersion
        == MetalLearningBatch.counterfactualRecordVersion,
      source.counterfactualStride == MetalLearningBatch.counterfactualStride
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX counterfactual-learning batch ABI is incompatible"
      )
    }
    let lease = try source.makeSharedStorageLease(for: .imaginedCounterfactuals)
    guard lease.byteCount
      == source.counterfactualCapacity * source.counterfactualStride
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "MLX counterfactual-learning byte count is incompatible"
      )
    }
    let raw = MLXArray(
      rawPointer: lease.baseAddress,
      [source.counterfactualCapacity, source.counterfactualStride],
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

    let identifiers = field(0, count: 1, dtype: .uint64)
    let parameterFingerprints = field(16, count: 1, dtype: .uint64)
    let sourceGenerations = field(24, count: 1, dtype: .uint64)
    let formats = field(64, count: 1, dtype: .uint32)
    let flags = field(68, count: 1, dtype: .uint32)
    let stateComponentCounts = field(76, count: 1, dtype: .uint32)
    let rawObjective = field(80, count: 1, dtype: .float32)
    let rawDamage = field(84, count: 1, dtype: .float32)
    let rawEpistemic = field(88, count: 1, dtype: .float32)
    let rawEffort = field(92, count: 1, dtype: .float32)
    let rawInformation = field(96, count: 1, dtype: .float32)
    let rawDuration = field(100, count: 1, dtype: .float32)
    let rawDriveChange = field(104, count: 1, dtype: .float32)
    let rawAdmissibility = field(108, count: 1, dtype: .float32)
    let rawPredictedState = field(112, count: 16, dtype: .float32)
    let rawActionParameters = field(176, count: 16, dtype: .float32)
    let objective = finite(rawObjective)
    let damage = finite(rawDamage)
    let epistemic = finite(rawEpistemic)
    let effort = finite(rawEffort)
    let information = finite(rawInformation)
    let driveChange = finite(rawDriveChange)
    let admissibility = clip(
      finite(rawAdmissibility), min: 0, max: 1
    )
    let scalarFiniteMask = (
      isFinite(rawObjective) * isFinite(rawDamage) * isFinite(rawEpistemic)
        * isFinite(rawEffort) * isFinite(rawInformation)
        * isFinite(rawDuration) * isFinite(rawDriveChange)
        * isFinite(rawAdmissibility)
    ).asType(.float32)
    let stateFiniteMask = (
      isFinite(rawPredictedState).asType(.float32).sum(
        axis: 1, keepDims: true
      ) .== Float(16)
    ).asType(.float32)
    let actionFiniteMask = (
      isFinite(rawActionParameters).asType(.float32).sum(
        axis: 1, keepDims: true
      ) .== Float(16)
    ).asType(.float32)
    let validMask = (
      (identifiers .> UInt64(0))
        * (parameterFingerprints .== source.parameterVersionFingerprint)
        * (sourceGenerations .<= source.sourceGeneration)
        * (formats .== source.counterfactualRecordVersion)
        * ((flags & (
          MetalCounterfactualLearningFlags.valid.rawValue
            | MetalCounterfactualLearningFlags.imagined.rawValue
        )) .== (
          MetalCounterfactualLearningFlags.valid.rawValue
            | MetalCounterfactualLearningFlags.imagined.rawValue
        ))
        * (stateComponentCounts .== UInt32(16))
    ).asType(.float32) * scalarFiniteMask * stateFiniteMask * actionFiniteMask
      * (damage .>= Float(0)).asType(.float32)
      * (damage .<= Float(1)).asType(.float32)
      * (epistemic .>= Float(0)).asType(.float32)
      * (effort .>= Float(0)).asType(.float32)
      * (finite(rawDuration) .> Float(0)).asType(.float32)

    self.source = source
    self.rawBytes = raw
    self.validMask = validMask
    self.actorMask = validMask * admissibility
      * (Float(0.5) + Float(0.5) * sigmoid(objective))
    self.riskMask = validMask * (
      Float(1) + clip(damage, min: 0, max: 1)
        + clip(epistemic, min: 0, max: 2)
    )
    self.objectiveValue = objective
    self.damageCVaR = damage
    self.epistemicUncertainty = epistemic
    self.predictedEffort = effort
    self.predictedInformationGain = information
    self.predictedDriveChange = driveChange
    self.admissibility = admissibility
    self.predictedState = finite(rawPredictedState)
    self.actionParameters = finite(rawActionParameters)
  }

  public func maskedMean(
    _ values: MLXArray,
    mask: MLXArray? = nil
  ) -> MLXArray {
    let selectedMask = mask ?? validMask
    let valuesPerRecord = max(
      values.size / max(source.counterfactualCapacity, 1), 1
    )
    let denominator = maximum(
      selectedMask.sum() * Float(valuesPerRecord), MLXArray(Float(1))
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

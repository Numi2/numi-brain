/// The exact prepared source-path linearization for one native 416-muscle,
/// 128-DoF Human standing model. Only articulated DoFs 6...127 participate.
/// Float bit patterns preserve the source evaluator's FP32 values through JSON.
public struct MuscleJointPathCalibration: Codable, Equatable, Sendable {
  public static let firstDof: UInt32 = 6
  public static let dofCount: Int = 122
  public static let muscleCount: Int = 416

  public let version: UInt32
  public let referencePositionBitsByDof: [UInt32]
  public let optimalFiberLengthBitsByMuscle: [UInt32]
  public let lengthJacobianBitsByMuscleDof: [UInt32]

  public init(version: UInt32 = 1, referencePositionBitsByDof: [UInt32],
    optimalFiberLengthBitsByMuscle: [UInt32],
    lengthJacobianBitsByMuscleDof: [UInt32]) {
    self.version = version
    self.referencePositionBitsByDof = referencePositionBitsByDof
    self.optimalFiberLengthBitsByMuscle = optimalFiberLengthBitsByMuscle
    self.lengthJacobianBitsByMuscleDof = lengthJacobianBitsByMuscleDof
  }

  public func validate() throws {
    guard version == 1,
      referencePositionBitsByDof.count == Self.dofCount,
      optimalFiberLengthBitsByMuscle.count == Self.muscleCount,
      lengthJacobianBitsByMuscleDof.count == Self.muscleCount * Self.dofCount,
      referencePositionBitsByDof.allSatisfy({ Float(bitPattern: $0).isFinite }),
      optimalFiberLengthBitsByMuscle.allSatisfy({
        let value = Float(bitPattern: $0)
        return value.isFinite && value > 0
      }),
      lengthJacobianBitsByMuscleDof.allSatisfy({ Float(bitPattern: $0).isFinite })
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "Human joint-path calibration has invalid source dimensions or FP32 values")
    }
  }
}

/// A distinct research controller. These exact values reproduce the historical
/// source-path law; changing them requires a new version and physical gate.
public struct MuscleJointPathFeedbackProgram: Codable, Equatable, Sendable {
  public let lengthGain: Float
  public let velocityGainSeconds: Float
  public let maximumCorrection: Float

  public init(lengthGain: Float, velocityGainSeconds: Float,
    maximumCorrection: Float) {
    self.lengthGain = lengthGain
    self.velocityGainSeconds = velocityGainSeconds
    self.maximumCorrection = maximumCorrection
  }

  public func validate() throws {
    guard lengthGain == 10, velocityGainSeconds == 1,
      maximumCorrection == 0.2 else {
      throw BrainRuntimeError.invalidDescriptor(
        "Human joint-path controller requires frozen 10/1 gains and 0.2 correction bound")
    }
  }
}

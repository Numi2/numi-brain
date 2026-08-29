import Foundation

@frozen
public enum WorldModelLevel: UInt16, Codable, CaseIterable, Comparable, Sendable {
  case receptor = 0
  case sensorimotor = 1
  case entityScene = 2
  case eventOption = 3
  case abstractSocial = 4

  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

@frozen
public struct WorldModelLevelDescriptor: Codable, Equatable, Hashable, Sendable {
  public let level: WorldModelLevel
  public let minimumHorizonMicroseconds: UInt64
  public let maximumHorizonMicroseconds: UInt64
  public let updatePeriodMicroseconds: UInt32
  public let latentDimension: UInt16

  public init(
    level: WorldModelLevel,
    minimumHorizonMicroseconds: UInt64,
    maximumHorizonMicroseconds: UInt64,
    updatePeriodMicroseconds: UInt32,
    latentDimension: UInt16
  ) throws {
    guard minimumHorizonMicroseconds > 0,
      minimumHorizonMicroseconds <= maximumHorizonMicroseconds,
      updatePeriodMicroseconds > 0, latentDimension > 0
    else {
      throw BrainRuntimeError.invalidDescriptor("world-model level descriptor is invalid")
    }
    self.level = level
    self.minimumHorizonMicroseconds = minimumHorizonMicroseconds
    self.maximumHorizonMicroseconds = maximumHorizonMicroseconds
    self.updatePeriodMicroseconds = updatePeriodMicroseconds
    self.latentDimension = latentDimension
  }

  public static func referenceV1(level: WorldModelLevel) throws -> Self {
    switch level {
    case .receptor:
      try Self(
        level: level, minimumHorizonMicroseconds: 5_000,
        maximumHorizonMicroseconds: 20_000, updatePeriodMicroseconds: 5_000,
        latentDimension: 128
      )
    case .sensorimotor:
      try Self(
        level: level, minimumHorizonMicroseconds: 20_000,
        maximumHorizonMicroseconds: 100_000, updatePeriodMicroseconds: 20_000,
        latentDimension: 256
      )
    case .entityScene:
      try Self(
        level: level, minimumHorizonMicroseconds: 100_000,
        maximumHorizonMicroseconds: 2_000_000, updatePeriodMicroseconds: 50_000,
        latentDimension: 256
      )
    case .eventOption:
      try Self(
        level: level, minimumHorizonMicroseconds: 1_000_000,
        maximumHorizonMicroseconds: 30_000_000, updatePeriodMicroseconds: 100_000,
        latentDimension: 256
      )
    case .abstractSocial:
      try Self(
        level: level, minimumHorizonMicroseconds: 1_000_000,
        maximumHorizonMicroseconds: 300_000_000, updatePeriodMicroseconds: 250_000,
        latentDimension: 256
      )
    }
  }
}

@frozen
public struct WorldModelHeadPrediction: Codable, Equatable, Hashable, Sendable {
  public let headIdentifier: UInt16
  public let targetTimestamp: BrainTimestamp
  public let predictedObservation: BrainLatentVector
  public let predictedState: BrainLatentVector
  public let predictedEventLogits: BrainLatentVector
  public let predictedDrives: [Float]
  public let predictedReinforcement: FactoredReinforcement
  public let risk: PredictedRiskEnvelope
  public let aleatoricVariance: BrainLatentVector

  public init(
    headIdentifier: UInt16,
    targetTimestamp: BrainTimestamp,
    predictedObservation: BrainLatentVector,
    predictedState: BrainLatentVector,
    predictedEventLogits: BrainLatentVector,
    predictedDrives: [Float],
    predictedReinforcement: FactoredReinforcement,
    risk: PredictedRiskEnvelope,
    aleatoricVariance: BrainLatentVector
  ) throws {
    guard predictedDrives.count == DriveKind.allCases.count,
      predictedDrives.allSatisfy(\.isFinite),
      aleatoricVariance.values.allSatisfy({ $0 >= 0 })
    else {
      throw BrainRuntimeError.transaction("world-model head prediction is invalid")
    }
    self.headIdentifier = headIdentifier
    self.targetTimestamp = targetTimestamp
    self.predictedObservation = predictedObservation
    self.predictedState = predictedState
    self.predictedEventLogits = predictedEventLogits
    self.predictedDrives = predictedDrives
    self.predictedReinforcement = predictedReinforcement
    self.risk = risk
    self.aleatoricVariance = aleatoricVariance
  }
}

@frozen
public struct WorldModelEnsemblePrediction: Codable, Equatable, Sendable {
  public let sourceTimestamp: BrainTimestamp
  public let level: WorldModelLevel
  public let heads: [WorldModelHeadPrediction]

  public init(
    sourceTimestamp: BrainTimestamp,
    level: WorldModelLevel,
    heads: [WorldModelHeadPrediction]
  ) throws {
    guard heads.count == 5, Set(heads.map(\.headIdentifier)).count == heads.count,
      heads.allSatisfy({ $0.targetTimestamp > sourceTimestamp }),
      heads.dropFirst().allSatisfy({ head in
        head.targetTimestamp == heads[0].targetTimestamp
          && head.predictedState.values.count == heads[0].predictedState.values.count
          && head.predictedObservation.values.count
            == heads[0].predictedObservation.values.count
          && head.aleatoricVariance.values.count
            == heads[0].aleatoricVariance.values.count
      })
    else {
      throw BrainRuntimeError.transaction("world-model ensemble is invalid")
    }
    self.sourceTimestamp = sourceTimestamp
    self.level = level
    self.heads = heads.sorted { $0.headIdentifier < $1.headIdentifier }
  }

  /// Mean per-latent head disagreement. This is epistemic uncertainty only.
  public var epistemicUncertainty: Float {
    let dimension = heads[0].predictedState.values.count
    var total: Float = 0
    for index in 0..<dimension {
      let mean = heads.reduce(0) { $0 + $1.predictedState.values[index] } / Float(heads.count)
      total += heads.reduce(0) { partial, head in
        let difference = head.predictedState.values[index] - mean
        return partial + difference * difference
      } / Float(heads.count)
    }
    return total / Float(dimension)
  }

  public var aleatoricUncertainty: Float {
    let count = heads.reduce(0) { $0 + $1.aleatoricVariance.values.count }
    let total = heads.reduce(Float(0)) { partial, head in
      partial + head.aleatoricVariance.values.reduce(0, +)
    }
    return total / Float(count)
  }
}

@frozen
public struct WorldModelLevelState: Codable, Equatable, Sendable {
  public let descriptor: WorldModelLevelDescriptor
  public let timestamp: BrainTimestamp
  public let latent: BrainLatentVector
  public let bottomUpPredictionError: BrainLatentVector
  public let topDownContext: BrainLatentVector
  public let latestPrediction: WorldModelEnsemblePrediction?

  public init(
    descriptor: WorldModelLevelDescriptor,
    timestamp: BrainTimestamp,
    latent: BrainLatentVector,
    bottomUpPredictionError: BrainLatentVector,
    topDownContext: BrainLatentVector,
    latestPrediction: WorldModelEnsemblePrediction?
  ) throws {
    guard latent.values.count == Int(descriptor.latentDimension),
      latestPrediction == nil
        || (latestPrediction?.sourceTimestamp == timestamp
          && latestPrediction?.level == descriptor.level)
    else {
      throw BrainRuntimeError.transaction("world-model level state is invalid")
    }
    self.descriptor = descriptor
    self.timestamp = timestamp
    self.latent = latent
    self.bottomUpPredictionError = bottomUpPredictionError
    self.topDownContext = topDownContext
    self.latestPrediction = latestPrediction
  }
}

@frozen
public struct HierarchicalWorldModelState: Codable, Equatable, Sendable {
  public let timestamp: BrainTimestamp
  public let parameterVersionFingerprint: UInt64
  public let levels: [WorldModelLevelState]

  public init(
    timestamp: BrainTimestamp,
    parameterVersionFingerprint: UInt64,
    levels: [WorldModelLevelState]
  ) throws {
    let canonical = levels.sorted { $0.descriptor.level < $1.descriptor.level }
    guard parameterVersionFingerprint > 0,
      canonical.map({ $0.descriptor.level }) == WorldModelLevel.allCases,
      canonical.allSatisfy({ $0.timestamp == timestamp })
    else {
      throw BrainRuntimeError.transaction("hierarchical world-model state is invalid")
    }
    self.timestamp = timestamp
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.levels = canonical
  }

  public func level(_ level: WorldModelLevel) -> WorldModelLevelState {
    levels[Int(level.rawValue)]
  }

  public func informationGain(comparedWith successor: Self) throws -> Float {
    guard successor.timestamp >= timestamp,
      successor.parameterVersionFingerprint == parameterVersionFingerprint
    else {
      throw BrainRuntimeError.transaction("world-model information-gain comparison is invalid")
    }
    var reduction: Float = 0
    for level in WorldModelLevel.allCases {
      guard let before = self.level(level).latestPrediction,
        let after = successor.level(level).latestPrediction
      else { continue }
      reduction += max(0, before.epistemicUncertainty - after.epistemicUncertainty)
    }
    return reduction
  }
}

@frozen
public enum CounterfactualProvenance: UInt16, Codable, CaseIterable, Sendable {
  case imaginedWorldModelRollout = 1
}

/// Planning-only trajectory. Its provenance type cannot be represented as a
/// lived episodic record and therefore cannot silently enter personal memory.
@frozen
public struct CounterfactualTrajectory: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt64
  public let provenance: CounterfactualProvenance
  public let sourceBeliefTimestamp: BrainTimestamp
  public let parameterVersionFingerprint: UInt64
  public let optionSteps: [PlannedOptionStep]
  public let terminalState: BrainLatentVector
  public let objectiveValue: Float

  public init(
    identifier: UInt64,
    sourceBeliefTimestamp: BrainTimestamp,
    parameterVersionFingerprint: UInt64,
    optionSteps: [PlannedOptionStep],
    terminalState: BrainLatentVector,
    objectiveValue: Float
  ) throws {
    guard identifier > 0, parameterVersionFingerprint > 0,
      !optionSteps.isEmpty, objectiveValue.isFinite
    else {
      throw BrainRuntimeError.transaction("counterfactual trajectory is invalid")
    }
    self.identifier = identifier
    self.provenance = .imaginedWorldModelRollout
    self.sourceBeliefTimestamp = sourceBeliefTimestamp
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.optionSteps = optionSteps
    self.terminalState = terminalState
    self.objectiveValue = objectiveValue
  }
}

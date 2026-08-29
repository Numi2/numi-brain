import Foundation

@frozen
public enum DriveKind: UInt16, Codable, CaseIterable, Sendable {
  case energy = 1
  case hydration = 2
  case oxygen = 3
  case temperature = 4
  case fatigue = 5
  case pain = 6
  case injury = 7
  case sleep = 8
  case curiosity = 9
  case social = 10
  case task = 11
  case safety = 12
}

@frozen
public struct DriveChannelState: Codable, Equatable, Hashable, Sendable {
  public let kind: DriveKind
  public let level: Float
  public let viableMinimum: Float
  public let viableMaximum: Float
  public let priorityWeight: Float
  public let estimatedRate: Float

  public init(
    kind: DriveKind,
    level: Float,
    viableMinimum: Float,
    viableMaximum: Float,
    priorityWeight: Float,
    estimatedRate: Float
  ) throws {
    guard level.isFinite, viableMinimum.isFinite, viableMaximum.isFinite,
      viableMinimum <= viableMaximum,
      priorityWeight.isFinite, priorityWeight >= 0,
      estimatedRate.isFinite
    else {
      throw BrainRuntimeError.transaction("drive channel is invalid")
    }
    self.kind = kind
    self.level = level
    self.viableMinimum = viableMinimum
    self.viableMaximum = viableMaximum
    self.priorityWeight = priorityWeight
    self.estimatedRate = estimatedRate
  }

  public var deficit: Float {
    if level < viableMinimum { return viableMinimum - level }
    if level > viableMaximum { return level - viableMaximum }
    return 0
  }

  public var potential: Float { priorityWeight * deficit * deficit }
}

@frozen
public struct DriveState: Codable, Equatable, Sendable {
  public let timestamp: BrainTimestamp
  public let channels: [DriveChannelState]

  public init(timestamp: BrainTimestamp, channels: [DriveChannelState]) throws {
    let canonical = channels.sorted { $0.kind.rawValue < $1.kind.rawValue }
    guard canonical.map(\.kind) == DriveKind.allCases else {
      throw BrainRuntimeError.transaction("drive state must contain every channel once")
    }
    self.timestamp = timestamp
    self.channels = canonical
  }

  public var homeostaticPotential: Float {
    channels.reduce(0) { $0 + $1.potential }
  }

  public func channel(_ kind: DriveKind) -> DriveChannelState {
    channels[Int(kind.rawValue - 1)]
  }

  public func homeostaticReinforcement(
    successor: DriveState,
    damageCost: Float,
    effortCost: Float
  ) throws -> Float {
    guard successor.timestamp >= timestamp, damageCost.isFinite, damageCost >= 0,
      effortCost.isFinite, effortCost >= 0
    else {
      throw BrainRuntimeError.transaction("homeostatic reinforcement input is invalid")
    }
    return homeostaticPotential - successor.homeostaticPotential - damageCost - effortCost
  }
}

@frozen
public struct FactoredReinforcement: Codable, Equatable, Hashable, Sendable {
  public let homeostatic: Float
  public let task: Float
  public let social: Float
  public let information: Float
  public let pain: Float
  public let effort: Float
  public let risk: Float

  public init(
    homeostatic: Float,
    task: Float,
    social: Float,
    information: Float,
    pain: Float,
    effort: Float,
    risk: Float
  ) throws {
    let components = [homeostatic, task, social, information, pain, effort, risk]
    guard components.allSatisfy(\.isFinite), information >= 0, pain >= 0,
      effort >= 0, risk >= 0
    else {
      throw BrainRuntimeError.transaction("factored reinforcement is invalid")
    }
    self.homeostatic = homeostatic
    self.task = task
    self.social = social
    self.information = information
    self.pain = pain
    self.effort = effort
    self.risk = risk
  }
}

@frozen
public enum NeuromodulatorKind: UInt16, Codable, CaseIterable, Sendable {
  case valueError = 1
  case modelError = 2
  case novelty = 3
  case epistemicUncertainty = 4
  case pain = 5
  case threat = 6
  case arousal = 7
  case satiety = 8
  case social = 9
  case fatigue = 10
  case sleep = 11
  case control = 12
}

@frozen
public struct NeuromodulatorChannelState: Codable, Equatable, Hashable, Sendable {
  public let kind: NeuromodulatorKind
  public let value: Float
  public let decayTimeConstantMicroseconds: UInt32

  public init(
    kind: NeuromodulatorKind,
    value: Float,
    decayTimeConstantMicroseconds: UInt32
  ) throws {
    guard value.isFinite, decayTimeConstantMicroseconds > 0 else {
      throw BrainRuntimeError.transaction("neuromodulator channel is invalid")
    }
    self.kind = kind
    self.value = value
    self.decayTimeConstantMicroseconds = decayTimeConstantMicroseconds
  }
}

@frozen
public struct NeuromodulatoryState: Codable, Equatable, Sendable {
  public let timestamp: BrainTimestamp
  public let channels: [NeuromodulatorChannelState]

  public init(
    timestamp: BrainTimestamp,
    channels: [NeuromodulatorChannelState]
  ) throws {
    let canonical = channels.sorted { $0.kind.rawValue < $1.kind.rawValue }
    guard canonical.map(\.kind) == NeuromodulatorKind.allCases else {
      throw BrainRuntimeError.transaction(
        "neuromodulatory state must contain every channel once"
      )
    }
    self.timestamp = timestamp
    self.channels = canonical
  }

  public func channel(_ kind: NeuromodulatorKind) -> Float {
    channels[Int(kind.rawValue - 1)].value
  }

  /// Applies a region-specific receptor row to the global modulatory state.
  public func localEffects(receptorWeights: [Float]) throws -> Float {
    guard receptorWeights.count == channels.count,
      receptorWeights.allSatisfy(\.isFinite)
    else {
      throw BrainRuntimeError.capacity("neuromodulator receptor row is invalid")
    }
    return zip(channels, receptorWeights).reduce(0) { result, pair in
      result + pair.0.value * pair.1
    }
  }
}

import Foundation

/// Identity of an optional detailed neuron-culture module. This module is not
/// part of NumiBrain's default mesoscale graph; it is an explicit experimental
/// controller whose state remains owned by Numi Lab/NumanX.
@frozen
public struct NeuronCultureModuleIdentity: Equatable, Hashable, Sendable {
  public static let abiVersion: UInt32 = 1

  public let cultureFingerprint: UInt64
  public let neuronCount: UInt32
  public let synapseCount: UInt32
  public let electrodeCount: UInt32
  public let fingerprint: UInt64

  public init(
    cultureFingerprint: UInt64,
    neuronCount: UInt32,
    synapseCount: UInt32,
    electrodeCount: UInt32
  ) throws {
    guard cultureFingerprint != 0, neuronCount > 0, synapseCount > 0,
      electrodeCount > 0, electrodeCount <= 256
    else {
      throw BrainRuntimeError.transaction("neuron-culture identity is invalid")
    }
    var hash = NeuronCultureFingerprint.offsetBasis
    NeuronCultureFingerprint.mix(Self.abiVersion, into: &hash)
    NeuronCultureFingerprint.mix(cultureFingerprint, into: &hash)
    NeuronCultureFingerprint.mix(neuronCount, into: &hash)
    NeuronCultureFingerprint.mix(synapseCount, into: &hash)
    NeuronCultureFingerprint.mix(electrodeCount, into: &hash)
    self.cultureFingerprint = cultureFingerprint
    self.neuronCount = neuronCount
    self.synapseCount = synapseCount
    self.electrodeCount = electrodeCount
    fingerprint = NeuronCultureFingerprint.nonzero(hash)
  }
}

/// Accepted virtual-MEA activity for one exact joint-root candidate. Counts are
/// values, not borrowed storage or publication authority.
@frozen
public struct NeuronCultureMEAFrame: Equatable, Hashable, Sendable {
  public let transactionFingerprint: UInt64
  public let cultureFingerprint: UInt64
  public let neuralTick: UInt64
  public let electrodeSpikeCounts: [UInt32]
  public let fingerprint: UInt64

  public init(
    transaction: BrainJointTransactionToken,
    culture: NeuronCultureModuleIdentity,
    neuralTick: UInt64,
    electrodeSpikeCounts: [UInt32]
  ) throws {
    guard neuralTick > 0,
      electrodeSpikeCounts.count == Int(culture.electrodeCount)
    else {
      throw BrainRuntimeError.transaction("neuron-culture MEA frame is invalid")
    }
    var hash = NeuronCultureFingerprint.offsetBasis
    NeuronCultureFingerprint.mix(transaction.fingerprint, into: &hash)
    NeuronCultureFingerprint.mix(culture.cultureFingerprint, into: &hash)
    NeuronCultureFingerprint.mix(neuralTick, into: &hash)
    NeuronCultureFingerprint.mix(culture.electrodeCount, into: &hash)
    for count in electrodeSpikeCounts {
      NeuronCultureFingerprint.mix(count, into: &hash)
    }
    transactionFingerprint = transaction.fingerprint
    cultureFingerprint = culture.cultureFingerprint
    self.neuralTick = neuralTick
    self.electrodeSpikeCounts = electrodeSpikeCounts
    fingerprint = NeuronCultureFingerprint.nonzero(hash)
  }
}

/// Deterministic population decoder. Weights are explicit experimental policy
/// parameters rather than an anatomical claim.
@frozen
public struct NeuronCultureControllerProfile: Equatable, Hashable, Sendable {
  public let cultureIdentityFingerprint: UInt64
  public let lateralWeights: [Float]
  public let forwardWeights: [Float]
  public let gain: Float
  public let fingerprint: UInt64

  public init(
    culture: NeuronCultureModuleIdentity,
    lateralWeights: [Float],
    forwardWeights: [Float],
    gain: Float = 1
  ) throws {
    let count = Int(culture.electrodeCount)
    guard lateralWeights.count == count, forwardWeights.count == count,
      gain.isFinite, gain > 0, gain <= 16,
      lateralWeights.allSatisfy({ $0.isFinite && abs($0) <= 1 }),
      forwardWeights.allSatisfy({ $0.isFinite && abs($0) <= 1 })
    else {
      throw BrainRuntimeError.transaction("neuron-culture controller profile is invalid")
    }
    var hash = NeuronCultureFingerprint.offsetBasis
    NeuronCultureFingerprint.mix(culture.fingerprint, into: &hash)
    NeuronCultureFingerprint.mix(gain.bitPattern, into: &hash)
    for weight in lateralWeights {
      NeuronCultureFingerprint.mix(weight.bitPattern, into: &hash)
    }
    for weight in forwardWeights {
      NeuronCultureFingerprint.mix(weight.bitPattern, into: &hash)
    }
    cultureIdentityFingerprint = culture.fingerprint
    self.lateralWeights = lateralWeights
    self.forwardWeights = forwardWeights
    self.gain = gain
    fingerprint = NeuronCultureFingerprint.nonzero(hash)
  }

  /// Reference decoder for the synthetic 6 x 10 Potter-style virtual MEA.
  public static func potterReference60(
    culture: NeuronCultureModuleIdentity,
    gain: Float = 1
  ) throws -> Self {
    guard culture.electrodeCount == 60 else {
      throw BrainRuntimeError.transaction("Potter reference decoder requires 60 electrodes")
    }
    var lateral: [Float] = []
    var forward: [Float] = []
    lateral.reserveCapacity(60)
    forward.reserveCapacity(60)
    for row in 0..<6 {
      for column in 0..<10 {
        lateral.append((Float(column) - 4.5) / 4.5)
        forward.append(1 - abs((Float(row) - 2.5) / 2.5))
      }
    }
    return try Self(
      culture: culture,
      lateralWeights: lateral,
      forwardWeights: forward,
      gain: gain
    )
  }
}

/// A prepared population action. Publication is a separate exact-root step.
@frozen
public struct NeuronCulturePopulationAction: Equatable, Hashable, Sendable {
  public let transactionFingerprint: UInt64
  public let cultureFingerprint: UInt64
  public let frameFingerprint: UInt64
  public let neuralTick: UInt64
  public let lateralCommand: Float
  public let forwardCommand: Float
  public let fingerprint: UInt64
}

/// Optional transactional adapter from virtual-MEA population activity to a
/// bounded two-axis controller. Rejected roots never publish an action.
public struct NeuronCultureControllerBridge: Sendable {
  public let culture: NeuronCultureModuleIdentity
  public let profile: NeuronCultureControllerProfile
  public private(set) var preparedAction: NeuronCulturePopulationAction?
  public private(set) var acceptedAction: NeuronCulturePopulationAction?

  public init(
    culture: NeuronCultureModuleIdentity,
    profile: NeuronCultureControllerProfile
  ) throws {
    guard profile.cultureIdentityFingerprint == culture.fingerprint else {
      throw BrainRuntimeError.transaction("neuron-culture controller identity mismatch")
    }
    self.culture = culture
    self.profile = profile
  }

  @discardableResult
  public mutating func prepare(
    frame: NeuronCultureMEAFrame,
    for transaction: BrainJointTransactionToken
  ) throws -> NeuronCulturePopulationAction {
    guard preparedAction == nil,
      frame.transactionFingerprint == transaction.fingerprint,
      frame.cultureFingerprint == culture.cultureFingerprint,
      frame.electrodeSpikeCounts.count == profile.lateralWeights.count
    else {
      throw BrainRuntimeError.transaction("neuron-culture frame does not match active root")
    }
    let total = frame.electrodeSpikeCounts.reduce(UInt64(0)) { $0 + UInt64($1) }
    var lateral: Double = 0
    var forward: Double = 0
    for index in frame.electrodeSpikeCounts.indices {
      let count = Double(frame.electrodeSpikeCounts[index])
      lateral += count * Double(profile.lateralWeights[index])
      forward += count * Double(profile.forwardWeights[index])
    }
    let scale = total == 0 ? 0 : Double(profile.gain) / Double(total)
    let lateralCommand = Float(max(-1, min(1, lateral * scale)))
    let forwardCommand = Float(max(-1, min(1, forward * scale)))
    var hash = NeuronCultureFingerprint.offsetBasis
    NeuronCultureFingerprint.mix(transaction.fingerprint, into: &hash)
    NeuronCultureFingerprint.mix(culture.cultureFingerprint, into: &hash)
    NeuronCultureFingerprint.mix(frame.fingerprint, into: &hash)
    NeuronCultureFingerprint.mix(frame.neuralTick, into: &hash)
    NeuronCultureFingerprint.mix(lateralCommand.bitPattern, into: &hash)
    NeuronCultureFingerprint.mix(forwardCommand.bitPattern, into: &hash)
    let action = NeuronCulturePopulationAction(
      transactionFingerprint: transaction.fingerprint,
      cultureFingerprint: culture.cultureFingerprint,
      frameFingerprint: frame.fingerprint,
      neuralTick: frame.neuralTick,
      lateralCommand: lateralCommand,
      forwardCommand: forwardCommand,
      fingerprint: NeuronCultureFingerprint.nonzero(hash)
    )
    preparedAction = action
    return action
  }

  public mutating func publishAccepted(
    _ action: NeuronCulturePopulationAction,
    for transaction: BrainJointTransactionToken
  ) throws {
    guard preparedAction == action,
      action.transactionFingerprint == transaction.fingerprint,
      action.cultureFingerprint == culture.cultureFingerprint
    else {
      throw BrainRuntimeError.transaction("neuron-culture accepted action is stale")
    }
    acceptedAction = action
    preparedAction = nil
  }

  public mutating func rejectPrepared(
    for transaction: BrainJointTransactionToken
  ) throws {
    guard let preparedAction,
      preparedAction.transactionFingerprint == transaction.fingerprint
    else {
      throw BrainRuntimeError.transaction("neuron-culture rejected action is stale")
    }
    self.preparedAction = nil
  }
}

private enum NeuronCultureFingerprint {
  static let offsetBasis: UInt64 = 14_695_981_039_346_656_037
  private static let prime: UInt64 = 1_099_511_628_211

  static func nonzero(_ value: UInt64) -> UInt64 {
    value == 0 ? offsetBasis : value
  }

  static func mix<T: FixedWidthInteger>(_ value: T, into hash: inout UInt64) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= prime
      }
    }
  }
}

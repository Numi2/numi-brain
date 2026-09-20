import Foundation

/// Semantic receptor feature contracts used by affect. A topology must name a
/// schema before the Metal path may interpret flattened interoception values.
public enum InteroceptiveFeatureSchema {
  /// NumanX's normalized 416x6 local-physiology channel. The fingerprint
  /// includes names, order, direction, and normalization bounds.
  public enum NumanXFullBodyV1 {
    public static let featureDimension: UInt32 = 6
    public static let fingerprint: UInt64 = {
      let descriptor = "numi-brain.interoception:numanx-fullbody-v1:"
        + "0=energy-availability:[0,1]:higher-is-better;"
        + "1=oxygen-availability:[0,1]:higher-is-better;"
        + "2=carbon-dioxide-burden:[0,1]:higher-is-worse;"
        + "3=temperature-deviation:[-1,1]:absolute-burden;"
        + "4=muscle-fatigue:[0,1]:higher-is-worse;"
        + "5=tissue-damage:[0,1]:higher-is-worse"
      var hash: UInt64 = 14_695_981_039_346_656_037
      for byte in descriptor.utf8 {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
      return hash
    }()

    public enum Feature: UInt32, CaseIterable, Sendable {
      case energyAvailability = 0
      case oxygenAvailability = 1
      case carbonDioxideBurden = 2
      case temperatureDeviation = 3
      case fatigue = 4
      case tissueDamage = 5
    }
  }
}

/// Physiological evidence used to derive per-agent affect from accepted
/// embodied consequences. Values are normalized deficits in 0...1.
@frozen
public struct AffectivePhysiologySample: Codable, Equatable, Hashable, Sendable {
  public let interoceptionTimestamp: BrainTimestamp?
  public let nociceptionTimestamp: BrainTimestamp?
  public let painEventTimestamp: BrainTimestamp?
  public let energyDeficit: Float?
  public let respiratoryDeficit: Float?
  public let temperatureDeviation: Float?
  public let fatigue: Float?
  public let tissueDamage: Float?
  public let nociception: Float?
  public let painEvent: Float?

  public init(
    interoceptionTimestamp: BrainTimestamp? = nil,
    nociceptionTimestamp: BrainTimestamp? = nil,
    painEventTimestamp: BrainTimestamp? = nil,
    energyDeficit: Float? = nil,
    respiratoryDeficit: Float? = nil,
    temperatureDeviation: Float? = nil,
    fatigue: Float? = nil,
    tissueDamage: Float? = nil,
    nociception: Float? = nil,
    painEvent: Float? = nil
  ) throws {
    let values = [energyDeficit, respiratoryDeficit, temperatureDeviation,
      fatigue, tissueDamage, nociception, painEvent]
    guard values.compactMap({ $0 }).allSatisfy({
      $0.isFinite && (0...1).contains($0)
    }), (!values.prefix(5).contains(where: { $0 != nil })
        || interoceptionTimestamp != nil),
      ((nociception != nil) == (nociceptionTimestamp != nil)),
      ((painEvent != nil) == (painEventTimestamp != nil))
    else {
      throw BrainRuntimeError.transaction("affective evidence is invalid")
    }
    self.interoceptionTimestamp = interoceptionTimestamp
    self.nociceptionTimestamp = nociceptionTimestamp
    self.painEventTimestamp = painEventTimestamp
    self.energyDeficit = energyDeficit
    self.respiratoryDeficit = respiratoryDeficit
    self.temperatureDeviation = temperatureDeviation
    self.fatigue = fatigue
    self.tissueDamage = tissueDamage
    self.nociception = nociception
    self.painEvent = painEvent
  }

  public var sourceValidityMask: UInt32 {
    var result: UInt32 = 0
    for (index, value) in [energyDeficit, respiratoryDeficit,
        temperatureDeviation, fatigue, tissueDamage, nociception].enumerated()
    where value != nil {
      result |= 1 << UInt32(index)
    }
    return result
  }

  fileprivate var homeostaticDeficits: [Float?] {
    [energyDeficit, respiratoryDeficit, temperatureDeviation, fatigue, tissueDamage]
  }
}

/// Bounded, fingerprinted gains and physical-time decay constants for affect.
@frozen
public struct AffectiveModelConfiguration: Codable, Equatable, Hashable, Sendable {
  /// Controls affect derivation and affect-based cognitive modulation only.
  /// Sensory pathways, reflexes, emergency stops, and independently factored
  /// pain costs remain active when affect is disabled.
  public let isEnabled: Bool
  public let painDecayMicroseconds: UInt64
  public let pleasureDecayMicroseconds: UInt64
  public let reliefDecayMicroseconds: UInt64
  public let maximumEvidenceAgeMicroseconds: UInt64
  public let recoveryGain: Float
  public let reliefGain: Float
  public let sourceWeights: [Float]

  public init(
    isEnabled: Bool = true,
    painDecayMicroseconds: UInt64 = 2_000_000,
    pleasureDecayMicroseconds: UInt64 = 1_000_000,
    reliefDecayMicroseconds: UInt64 = 500_000,
    maximumEvidenceAgeMicroseconds: UInt64 = 100_000,
    recoveryGain: Float = 1,
    reliefGain: Float = 1,
    sourceWeights: [Float] = [0.24, 0.24, 0.16, 0.18, 0.18]
  ) throws {
    guard painDecayMicroseconds > 0, pleasureDecayMicroseconds > 0,
      reliefDecayMicroseconds > 0, recoveryGain.isFinite,
      maximumEvidenceAgeMicroseconds > 0,
      (0...4).contains(recoveryGain), reliefGain.isFinite,
      (0...4).contains(reliefGain), sourceWeights.count == 5,
      sourceWeights.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
      abs(sourceWeights.reduce(0, +) - 1) <= 1.0e-5
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "affective model configuration must have bounded gains and five normalized source weights"
      )
    }
    self.isEnabled = isEnabled
    self.painDecayMicroseconds = painDecayMicroseconds
    self.pleasureDecayMicroseconds = pleasureDecayMicroseconds
    self.reliefDecayMicroseconds = reliefDecayMicroseconds
    self.maximumEvidenceAgeMicroseconds = maximumEvidenceAgeMicroseconds
    self.recoveryGain = recoveryGain
    self.reliefGain = reliefGain
    self.sourceWeights = sourceWeights
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    do {
      try self.init(
        isEnabled: container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true,
        painDecayMicroseconds: container.decode(UInt64.self, forKey: .painDecayMicroseconds),
        pleasureDecayMicroseconds: container.decode(UInt64.self, forKey: .pleasureDecayMicroseconds),
        reliefDecayMicroseconds: container.decode(UInt64.self, forKey: .reliefDecayMicroseconds),
        maximumEvidenceAgeMicroseconds: container.decode(
          UInt64.self, forKey: .maximumEvidenceAgeMicroseconds
        ),
        recoveryGain: container.decode(Float.self, forKey: .recoveryGain),
        reliefGain: container.decode(Float.self, forKey: .reliefGain),
        sourceWeights: container.decode([Float].self, forKey: .sourceWeights)
      )
    } catch {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "invalid affective model configuration",
          underlyingError: error
        )
      )
    }
  }

  private enum CodingKeys: String, CodingKey {
    case isEnabled
    case painDecayMicroseconds
    case pleasureDecayMicroseconds
    case reliefDecayMicroseconds
    case maximumEvidenceAgeMicroseconds
    case recoveryGain
    case reliefGain
    case sourceWeights
  }

  public static let reference = try! AffectiveModelConfiguration()
  public static let disabled = try! AffectiveModelConfiguration(isEnabled: false)

  public var fingerprint: UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    func mix(_ value: UInt64, into hash: inout UInt64) {
      var littleEndian = value.littleEndian
      withUnsafeBytes(of: &littleEndian) { bytes in
        for byte in bytes {
          hash ^= UInt64(byte)
          hash &*= 1_099_511_628_211
        }
      }
    }
    mix(painDecayMicroseconds, into: &hash)
    mix(pleasureDecayMicroseconds, into: &hash)
    mix(reliefDecayMicroseconds, into: &hash)
    mix(maximumEvidenceAgeMicroseconds, into: &hash)
    mix(UInt64(recoveryGain.bitPattern), into: &hash)
    mix(UInt64(reliefGain.bitPattern), into: &hash)
    mix(isEnabled ? 1 : 0, into: &hash)
    for weight in sourceWeights { mix(UInt64(weight.bitPattern), into: &hash) }
    return hash
  }
}

/// Functional affect derived only from fresh, comparable bodily evidence.
/// This state describes modulation and is not an independent reward function.
@frozen
public struct AffectiveState: Codable, Equatable, Hashable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let timestamp: BrainTimestamp
  public let pain: Float
  public let pleasure: Float
  public let relief: Float
  public let sourceValidityMask: UInt32
  public let sourceEvidence: [Float]
  public let previousSourceValidityMask: UInt32
  public let previousSampleTimestamp: BrainTimestamp?
  public let previousPainSampleTimestamp: BrainTimestamp?
  public let previousPainObservation: Float?
  public let configurationFingerprint: UInt64

  /// Stable replay identity for both visible affect and its causal baselines.
  var causalFingerprint: UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    Self.mix(timestamp.rawValue, into: &hash)
    Self.mix(UInt64(pain.bitPattern), into: &hash)
    Self.mix(UInt64(pleasure.bitPattern), into: &hash)
    Self.mix(UInt64(relief.bitPattern), into: &hash)
    Self.mix(UInt64(sourceValidityMask), into: &hash)
    Self.mix(UInt64(previousSourceValidityMask), into: &hash)
    for value in sourceEvidence { Self.mix(UInt64(value.bitPattern), into: &hash) }
    Self.mix(previousSampleTimestamp != nil ? 1 : 0, into: &hash)
    if let previousSampleTimestamp {
      Self.mix(previousSampleTimestamp.rawValue, into: &hash)
    }
    Self.mix(previousPainSampleTimestamp != nil ? 1 : 0, into: &hash)
    if let previousPainSampleTimestamp {
      Self.mix(previousPainSampleTimestamp.rawValue, into: &hash)
    }
    Self.mix(previousPainObservation != nil ? 1 : 0, into: &hash)
    if let previousPainObservation {
      Self.mix(UInt64(previousPainObservation.bitPattern), into: &hash)
    }
    Self.mix(configurationFingerprint, into: &hash)
    return hash
  }

  public init(
    timestamp: BrainTimestamp,
    pain: Float,
    pleasure: Float,
    relief: Float,
    sourceValidityMask: UInt32,
    sourceEvidence: [Float],
    previousSourceValidityMask: UInt32,
    previousSampleTimestamp: BrainTimestamp?,
    previousPainSampleTimestamp: BrainTimestamp?,
    previousPainObservation: Float?,
    configurationFingerprint: UInt64
  ) throws {
    guard [pain, pleasure, relief].allSatisfy({ $0.isFinite && (0...1).contains($0) }),
      sourceEvidence.count == 5, sourceEvidence.allSatisfy(\.isFinite),
      sourceEvidence.allSatisfy({ (0...1).contains($0) }),
      sourceValidityMask & ~0x3f == 0, previousSourceValidityMask & ~0x3f == 0,
      previousSampleTimestamp.map({ $0 <= timestamp }) ?? true,
      previousPainSampleTimestamp.map({ $0 <= timestamp }) ?? true,
      previousPainObservation.map({ $0.isFinite && (0...1).contains($0) }) ?? true,
      configurationFingerprint > 0
    else {
      throw BrainRuntimeError.transaction("affective state is invalid")
    }
    self.timestamp = timestamp
    self.pain = pain
    self.pleasure = pleasure
    self.relief = relief
    self.sourceValidityMask = sourceValidityMask
    self.sourceEvidence = sourceEvidence
    self.previousSourceValidityMask = previousSourceValidityMask
    self.previousSampleTimestamp = previousSampleTimestamp
    self.previousPainSampleTimestamp = previousPainSampleTimestamp
    self.previousPainObservation = previousPainObservation
    self.configurationFingerprint = configurationFingerprint
  }

  public static func neutral(
    at timestamp: BrainTimestamp,
    configuration: AffectiveModelConfiguration = .reference
  ) throws -> AffectiveState {
    try AffectiveState(
      timestamp: timestamp,
      pain: 0,
      pleasure: 0,
      relief: 0,
      sourceValidityMask: 0,
      sourceEvidence: Array(repeating: 0, count: 5),
      previousSourceValidityMask: 0,
      previousSampleTimestamp: nil,
      previousPainSampleTimestamp: nil,
      previousPainObservation: nil,
      configurationFingerprint: configuration.fingerprint
    )
  }

  /// CPU oracle for the Metal accepted-consequence affect update.
  public func advanced(
    to timestamp: BrainTimestamp,
    sample: AffectivePhysiologySample,
    configuration: AffectiveModelConfiguration = .reference
  ) throws -> AffectiveState {
    guard timestamp > self.timestamp,
      configuration.fingerprint == configurationFingerprint
    else {
      throw BrainRuntimeError.transaction(
        "affective update must advance physical time with the same configuration"
      )
    }
    guard configuration.isEnabled else {
      return try AffectiveState.neutral(at: timestamp, configuration: configuration)
    }
    let elapsedSeconds = Float(timestamp.rawValue - self.timestamp.rawValue) / 1_000_000
    let painRetention = Foundation.exp(
      -elapsedSeconds / (Float(configuration.painDecayMicroseconds) / 1_000_000)
    )
    let pleasureRetention = Foundation.exp(
      -elapsedSeconds / (Float(configuration.pleasureDecayMicroseconds) / 1_000_000)
    )
    let reliefRetention = Foundation.exp(
      -elapsedSeconds / (Float(configuration.reliefDecayMicroseconds) / 1_000_000)
    )
    let currentValues = sample.homeostaticDeficits
    let evidenceIsFresh = sample.interoceptionTimestamp.map { sampleTimestamp in
      sampleTimestamp <= timestamp
        && timestamp.rawValue - sampleTimestamp.rawValue
          <= configuration.maximumEvidenceAgeMicroseconds
        && (previousSampleTimestamp.map { sampleTimestamp > $0 } ?? true)
    } ?? false
    let painIsFresh = sample.nociceptionTimestamp.map { sampleTimestamp in
      sampleTimestamp <= timestamp
        && timestamp.rawValue - sampleTimestamp.rawValue
          <= configuration.maximumEvidenceAgeMicroseconds
        && (previousPainSampleTimestamp.map { sampleTimestamp > $0 } ?? true)
    } ?? false
    let painEventIsFresh = sample.painEventTimestamp.map { sampleTimestamp in
      sampleTimestamp <= timestamp
        && timestamp.rawValue - sampleTimestamp.rawValue
          <= configuration.maximumEvidenceAgeMicroseconds
    } ?? false

    var recovery: Float = 0
    var nextEvidence = sourceEvidence
    var nextValidityMask: UInt32 = 0
    if evidenceIsFresh {
      for index in currentValues.indices {
        guard let current = currentValues[index] else { continue }
        nextEvidence[index] = current
        nextValidityMask |= 1 << UInt32(index)
        guard previousSourceValidityMask & (1 << UInt32(index)) != 0 else { continue }
        recovery += configuration.sourceWeights[index]
          * max(sourceEvidence[index] - current, Float(0))
      }
    }

    let painSource = sample.nociception
    let reliefEvidence: Float
    if painIsFresh, let painSource, let priorPain = previousPainObservation {
      reliefEvidence = max(priorPain - painSource, Float(0))
    } else {
      reliefEvidence = 0
    }
    // Keep the last consumed timestamp across a dropout so a repeated frame
    // cannot become fresh again. Clear only its comparison value: a returning
    // source establishes a new baseline and cannot imply relief.
    let nextPainObservation = painIsFresh ? sample.nociception : nil
    let nextPainSampleTimestamp = painIsFresh
      ? sample.nociceptionTimestamp : previousPainSampleTimestamp
    let freshNociception = painIsFresh ? (sample.nociception ?? Float(0)) : Float(0)
    let freshTissueDamage = evidenceIsFresh ? (sample.tissueDamage ?? Float(0)) : Float(0)
    let freshPainEvent = painEventIsFresh ? (sample.painEvent ?? Float(0)) : Float(0)
    let nextPain = min(Float(1), max(
      pain * painRetention,
      max(freshPainEvent, max(freshNociception, freshTissueDamage))
    ))
    let reliefFromRecovery = configuration.reliefGain * reliefEvidence
    let nextRelief = min(Float(1), relief * reliefRetention + reliefFromRecovery)
    let retainedPleasure = pleasure * pleasureRetention
    let pleasureFromRecovery = configuration.recoveryGain * recovery
    let nextPleasure = min(
      Float(1), retainedPleasure + pleasureFromRecovery + reliefFromRecovery
    )
    return try AffectiveState(
      timestamp: timestamp,
      pain: nextPain,
      pleasure: nextPleasure,
      relief: nextRelief,
      sourceValidityMask: nextValidityMask
        | (painIsFresh || painEventIsFresh ? (1 << 5) : 0),
      sourceEvidence: nextEvidence,
      previousSourceValidityMask: nextValidityMask,
      previousSampleTimestamp: evidenceIsFresh
        ? sample.interoceptionTimestamp : previousSampleTimestamp,
      previousPainSampleTimestamp: nextPainSampleTimestamp,
      previousPainObservation: nextPainObservation,
      configurationFingerprint: configuration.fingerprint
    )
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }
}

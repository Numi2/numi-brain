import Foundation

@frozen
public enum ReceptorEventComparison: UInt16, Codable, CaseIterable, Sendable {
  case greaterThan = 1
  case lessThan = 2
  case absoluteGreaterThan = 3
}

@frozen
public struct ReceptorEventRule: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt32
  public let modality: SensoryModality
  public let receptorStart: UInt32
  public let receptorCount: UInt32
  public let featureIndex: UInt32
  public let comparison: ReceptorEventComparison
  public let threshold: Float
  public let magnitudeScale: Float
  public let eventKind: ReceptorEventKind
  public let eventFlags: UInt32
  /// Stable species receptor identity. Zero preserves the legacy behavior of
  /// using the strongest modality-local receptor index as event source.
  public let sourceIdentifier: UInt32
  /// Species-critical boundaries bypass the trainable generic event floor.
  /// Other learned or calibrated event rules retain the floor by default.
  public let usesAbsoluteThreshold: Bool

  public init(
    identifier: UInt32,
    modality: SensoryModality,
    receptorStart: UInt32,
    receptorCount: UInt32,
    featureIndex: UInt32,
    comparison: ReceptorEventComparison,
    threshold: Float,
    magnitudeScale: Float,
    eventKind: ReceptorEventKind,
    eventFlags: UInt32 = 0,
    sourceIdentifier: UInt32 = 0,
    usesAbsoluteThreshold: Bool = false
  ) throws {
    guard identifier > 0, receptorCount > 0, threshold.isFinite,
      magnitudeScale.isFinite, magnitudeScale > 0
    else {
      throw BrainRuntimeError.invalidEvent("receptor event rule is invalid")
    }
    self.identifier = identifier
    self.modality = modality
    self.receptorStart = receptorStart
    self.receptorCount = receptorCount
    self.featureIndex = featureIndex
    self.comparison = comparison
    self.threshold = threshold
    self.magnitudeScale = magnitudeScale
    self.eventKind = eventKind
    self.eventFlags = eventFlags
    self.sourceIdentifier = sourceIdentifier
    self.usesAbsoluteThreshold = usesAbsoluteThreshold
  }
}

/// Immutable receptor calibration and explicit event thresholds for one
/// species/morphology generation. Event meaning is supplied by the template;
/// the GPU runtime never invents anatomical thresholds.
@frozen
public struct SensoryTransductionProfile: Codable, Equatable, Sendable {
  public let speciesTemplateFingerprint: UInt64
  public let eventRules: [ReceptorEventRule]
  public let fingerprint: UInt64

  public init(
    species: SpeciesTemplate,
    eventRules: [ReceptorEventRule],
    includePhysiologicalCriticalRules: Bool = true
  ) throws {
    var compiledRules = eventRules
    if includePhysiologicalCriticalRules {
      compiledRules.append(contentsOf: try Self.physiologicalCriticalRules(species))
    }
    guard Set(compiledRules.map(\.identifier)).count == compiledRules.count else {
      throw BrainRuntimeError.invalidEvent("receptor event-rule identifiers are duplicated")
    }
    let topologyByModality = Dictionary(
      uniqueKeysWithValues: species.senses.map { ($0.modality, $0) }
    )
    for rule in compiledRules {
      guard let topology = topologyByModality[rule.modality], topology.enabled,
        rule.featureIndex < topology.observationDimension
      else {
        throw BrainRuntimeError.invalidEvent("receptor event rule names an unavailable feature")
      }
      let (end, overflow) = rule.receptorStart.addingReportingOverflow(rule.receptorCount)
      guard !overflow, end <= topology.receptorCount else {
        throw BrainRuntimeError.invalidEvent("receptor event rule exceeds receptor topology")
      }
    }
    var hash: UInt64 = 14_695_981_039_346_656_037
    Self.mix(species.fingerprint, into: &hash)
    for rule in compiledRules.sorted(by: { $0.identifier < $1.identifier }) {
      Self.mix(UInt64(rule.identifier), into: &hash)
      Self.mix(UInt64(rule.modality.rawValue), into: &hash)
      Self.mix(UInt64(rule.receptorStart), into: &hash)
      Self.mix(UInt64(rule.receptorCount), into: &hash)
      Self.mix(UInt64(rule.featureIndex), into: &hash)
      Self.mix(UInt64(rule.comparison.rawValue), into: &hash)
      Self.mix(UInt64(rule.threshold.bitPattern), into: &hash)
      Self.mix(UInt64(rule.magnitudeScale.bitPattern), into: &hash)
      Self.mix(UInt64(rule.eventKind.rawValue), into: &hash)
      Self.mix(UInt64(rule.eventFlags), into: &hash)
      Self.mix(UInt64(rule.sourceIdentifier), into: &hash)
      Self.mix(UInt64(rule.usesAbsoluteThreshold ? 1 : 0), into: &hash)
    }
    self.speciesTemplateFingerprint = species.fingerprint
    self.eventRules = compiledRules.sorted { $0.identifier < $1.identifier }
    self.fingerprint = hash
  }

  /// Critical physiology is emitted from causal interoceptive observations,
  /// never from authoritative NumanX state. Two immutable rules cover the low
  /// and high critical boundary for every species physiology component.
  private static func physiologicalCriticalRules(
    _ species: SpeciesTemplate
  ) throws -> [ReceptorEventRule] {
    var rules: [ReceptorEventRule] = []
    rules.reserveCapacity(species.physiology.receptorMappings.count * 2)
    for mapping in species.physiology.receptorMappings {
      let stateIndex = Int(mapping.stateIdentifier)
      let baseIdentifier = UInt32(0x8000_0000)
        | (UInt32(mapping.stateIdentifier) << 1)
      rules.append(
        try ReceptorEventRule(
          identifier: baseIdentifier,
          modality: .interoception,
          receptorStart: mapping.interoceptiveReceptorIndex,
          receptorCount: 1,
          featureIndex: mapping.featureIndex,
          comparison: .lessThan,
          threshold: species.physiology.criticalMinimums[stateIndex],
          magnitudeScale: mapping.magnitudeScale,
          eventKind: .physiologicalCritical,
          sourceIdentifier: mapping.receptorIdentifier,
          usesAbsoluteThreshold: true
        )
      )
      rules.append(
        try ReceptorEventRule(
          identifier: baseIdentifier | 1,
          modality: .interoception,
          receptorStart: mapping.interoceptiveReceptorIndex,
          receptorCount: 1,
          featureIndex: mapping.featureIndex,
          comparison: .greaterThan,
          threshold: species.physiology.criticalMaximums[stateIndex],
          magnitudeScale: mapping.magnitudeScale,
          eventKind: .physiologicalCritical,
          sourceIdentifier: mapping.receptorIdentifier,
          usesAbsoluteThreshold: true
        )
      )
    }
    return rules
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    var value = value.littleEndian
    withUnsafeBytes(of: &value) { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }
}

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
    eventFlags: UInt32 = 0
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
    eventRules: [ReceptorEventRule]
  ) throws {
    guard Set(eventRules.map(\.identifier)).count == eventRules.count else {
      throw BrainRuntimeError.invalidEvent("receptor event-rule identifiers are duplicated")
    }
    let topologyByModality = Dictionary(
      uniqueKeysWithValues: species.senses.map { ($0.modality, $0) }
    )
    for rule in eventRules {
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
    for rule in eventRules.sorted(by: { $0.identifier < $1.identifier }) {
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
    }
    self.speciesTemplateFingerprint = species.fingerprint
    self.eventRules = eventRules.sorted { $0.identifier < $1.identifier }
    self.fingerprint = hash
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

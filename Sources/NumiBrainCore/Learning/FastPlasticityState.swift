import Foundation

@frozen
public struct FastPlasticitySiteIdentifier: Codable, Equatable, Hashable, Sendable {
  public let regionIdentifier: UInt16
  public let basisIdentifier: UInt16

  public init(regionIdentifier: UInt16, basisIdentifier: UInt16) throws {
    guard regionIdentifier > 0 else {
      throw BrainRuntimeError.transaction("fast-plasticity region zero is reserved")
    }
    self.regionIdentifier = regionIdentifier
    self.basisIdentifier = basisIdentifier
  }
}

@frozen
public struct FastPlasticitySiteState: Codable, Equatable, Hashable, Sendable {
  public let identifier: FastPlasticitySiteIdentifier
  public let coefficient: Float
  public let eligibility: Float
  public let coefficientRetention: Float
  public let eligibilityRetention: Float
  public let learningRate: Float
  public let maximumMagnitude: Float

  public init(
    identifier: FastPlasticitySiteIdentifier,
    coefficient: Float,
    eligibility: Float,
    coefficientRetention: Float,
    eligibilityRetention: Float,
    learningRate: Float,
    maximumMagnitude: Float
  ) throws {
    guard coefficient.isFinite, eligibility.isFinite,
      coefficientRetention.isFinite, (0...1).contains(coefficientRetention),
      eligibilityRetention.isFinite, (0...1).contains(eligibilityRetention),
      learningRate.isFinite, learningRate >= 0,
      maximumMagnitude.isFinite, maximumMagnitude > 0,
      abs(coefficient) <= maximumMagnitude
    else {
      throw BrainRuntimeError.transaction("fast-plasticity site is invalid")
    }
    self.identifier = identifier
    self.coefficient = coefficient
    self.eligibility = eligibility
    self.coefficientRetention = coefficientRetention
    self.eligibilityRetention = eligibilityRetention
    self.learningRate = learningRate
    self.maximumMagnitude = maximumMagnitude
  }

  public func advanced(
    localActivityProduct: Float,
    localModulation: Float
  ) throws -> Self {
    guard localActivityProduct.isFinite, localModulation.isFinite else {
      throw BrainRuntimeError.transaction("fast-plasticity update is non-finite")
    }
    let nextEligibility = eligibilityRetention * eligibility + localActivityProduct
    let unconstrained =
      coefficientRetention * coefficient
      + learningRate * localModulation * nextEligibility
    let nextCoefficient = min(max(unconstrained, -maximumMagnitude), maximumMagnitude)
    return try Self(
      identifier: identifier,
      coefficient: nextCoefficient,
      eligibility: nextEligibility,
      coefficientRetention: coefficientRetention,
      eligibilityRetention: eligibilityRetention,
      learningRate: learningRate,
      maximumMagnitude: maximumMagnitude
    )
  }
}

@frozen
public struct FastPlasticityState: Codable, Equatable, Sendable {
  public let generation: UInt64
  public let timestamp: BrainTimestamp
  public let capacity: UInt16
  public let sites: [FastPlasticitySiteState]

  public init(
    generation: UInt64,
    timestamp: BrainTimestamp,
    capacity: UInt16,
    sites: [FastPlasticitySiteState]
  ) throws {
    guard sites.count <= Int(capacity),
      Set(sites.map(\.identifier)).count == sites.count
    else {
      throw BrainRuntimeError.capacity("fast-plasticity state exceeds capacity")
    }
    self.generation = generation
    self.timestamp = timestamp
    self.capacity = capacity
    self.sites = sites.sorted {
      if $0.identifier.regionIdentifier != $1.identifier.regionIdentifier {
        return $0.identifier.regionIdentifier < $1.identifier.regionIdentifier
      }
      return $0.identifier.basisIdentifier < $1.identifier.basisIdentifier
    }
  }

  public func advanced(
    shadowGeneration: UInt64,
    timestamp: BrainTimestamp,
    activityProducts: [FastPlasticitySiteIdentifier: Float],
    regionModulation: [UInt16: Float]
  ) throws -> Self {
    let (expectedGeneration, overflow) = generation.addingReportingOverflow(1)
    guard !overflow, shadowGeneration == expectedGeneration, timestamp >= self.timestamp,
      Set(activityProducts.keys).isSubset(of: Set(sites.map(\.identifier)))
    else {
      throw BrainRuntimeError.transaction("fast-plasticity shadow update is invalid")
    }
    let next = try sites.map { site in
      try site.advanced(
        localActivityProduct: activityProducts[site.identifier] ?? 0,
        localModulation: regionModulation[site.identifier.regionIdentifier] ?? 0
      )
    }
    return try Self(
      generation: shadowGeneration,
      timestamp: timestamp,
      capacity: capacity,
      sites: next
    )
  }
}

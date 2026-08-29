import Foundation

@frozen
public struct BodySchemaFlags: OptionSet, Codable, Hashable, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let everObserved = Self(rawValue: 1 << 0)
  public static let observedThisUpdate = Self(rawValue: 1 << 1)
  public static let firstRouteEndpoint = Self(rawValue: 1 << 2)
  public static let terminalRouteEndpoint = Self(rawValue: 1 << 3)
}

/// Dense per-body posterior owned by the brain. It estimates mechanical load
/// and vulnerability from causal receptor history; it is not authoritative
/// NumanX state.
@frozen
public struct BodySchemaPosteriorCell: Codable, Equatable, Hashable, Sendable {
  public static let unknownSourceMuscleIdentifier = UInt32.max

  public let bodyIdentifier: UInt32
  public let flags: BodySchemaFlags
  public let sourceMuscleIdentifier: UInt32
  public let endpointRole: BodyLoadEndpointRole
  public let estimatedAbsoluteLoad: Float
  public let epistemicVariance: Float
  public let vulnerability: Float
  public let damageRisk: Float
  public let lastObservationTimestamp: BrainTimestamp?
  public let stateTimestamp: BrainTimestamp

  public init(
    bodyIdentifier: UInt32,
    flags: BodySchemaFlags,
    sourceMuscleIdentifier: UInt32,
    endpointRole: BodyLoadEndpointRole,
    estimatedAbsoluteLoad: Float,
    epistemicVariance: Float,
    vulnerability: Float,
    damageRisk: Float,
    lastObservationTimestamp: BrainTimestamp?,
    stateTimestamp: BrainTimestamp
  ) throws {
    guard estimatedAbsoluteLoad.isFinite, estimatedAbsoluteLoad >= 0,
      epistemicVariance.isFinite, epistemicVariance >= 0,
      vulnerability.isFinite, (0...1).contains(vulnerability),
      damageRisk.isFinite, (0...1).contains(damageRisk),
      lastObservationTimestamp == nil || lastObservationTimestamp! <= stateTimestamp,
      flags.contains(.everObserved) == (lastObservationTimestamp != nil),
      flags.contains(.everObserved)
        == (sourceMuscleIdentifier != Self.unknownSourceMuscleIdentifier),
      flags.contains(.firstRouteEndpoint)
        == endpointRole.contains(.firstRouteEndpoint),
      flags.contains(.terminalRouteEndpoint)
        == endpointRole.contains(.terminalRouteEndpoint)
    else {
      throw BrainRuntimeError.transaction("body-schema posterior cell is invalid")
    }
    self.bodyIdentifier = bodyIdentifier
    self.flags = flags
    self.sourceMuscleIdentifier = sourceMuscleIdentifier
    self.endpointRole = endpointRole
    self.estimatedAbsoluteLoad = estimatedAbsoluteLoad
    self.epistemicVariance = epistemicVariance
    self.vulnerability = vulnerability
    self.damageRisk = damageRisk
    self.lastObservationTimestamp = lastObservationTimestamp
    self.stateTimestamp = stateTimestamp
  }

  public static func unobserved(
    bodyIdentifier: UInt32,
    initialVariance: Float,
    timestamp: BrainTimestamp = BrainTimestamp(microseconds: 0)
  ) throws -> Self {
    try Self(
      bodyIdentifier: bodyIdentifier,
      flags: [],
      sourceMuscleIdentifier: unknownSourceMuscleIdentifier,
      endpointRole: [],
      estimatedAbsoluteLoad: 0,
      epistemicVariance: initialVariance,
      vulnerability: 0,
      damageRisk: 0,
      lastObservationTimestamp: nil,
      stateTimestamp: timestamp
    )
  }

  public var confidence: Float {
    1 / (1 + Foundation.sqrt(epistemicVariance))
  }
}

/// Initial probabilistic body-schema filter. It combines a decaying load prior
/// with accepted receptor observations, tracks epistemic variance, accumulates
/// vulnerability under load, and recovers gradually while unloaded. Parameters
/// are explicit so later species calibration and learning can replace the
/// foundation values without changing state ownership.
@frozen
public struct BodySchemaPosteriorDynamics: Codable, Equatable, Hashable, Sendable {
  public let forceScaleNewtons: Float
  public let loadTimeConstantMicroseconds: UInt32
  public let initialVariance: Float
  public let maximumVariance: Float
  public let processVariancePerSecond: Float
  public let observationVariance: Float
  public let vulnerabilityGainPerSecond: Float
  public let recoveryPerSecond: Float
  public let uncertaintyRiskWeight: Float

  public init(
    forceScaleNewtons: Float,
    loadTimeConstantMicroseconds: UInt32,
    initialVariance: Float,
    maximumVariance: Float,
    processVariancePerSecond: Float,
    observationVariance: Float,
    vulnerabilityGainPerSecond: Float,
    recoveryPerSecond: Float,
    uncertaintyRiskWeight: Float
  ) throws {
    guard forceScaleNewtons.isFinite, forceScaleNewtons > 0,
      loadTimeConstantMicroseconds > 0,
      initialVariance.isFinite, initialVariance >= 0,
      maximumVariance.isFinite, maximumVariance >= initialVariance,
      processVariancePerSecond.isFinite, processVariancePerSecond >= 0,
      observationVariance.isFinite, observationVariance > 0,
      vulnerabilityGainPerSecond.isFinite, vulnerabilityGainPerSecond >= 0,
      recoveryPerSecond.isFinite, recoveryPerSecond >= 0,
      uncertaintyRiskWeight.isFinite, (0...1).contains(uncertaintyRiskWeight)
    else {
      throw BrainRuntimeError.transaction("body-schema posterior dynamics are invalid")
    }
    self.forceScaleNewtons = forceScaleNewtons
    self.loadTimeConstantMicroseconds = loadTimeConstantMicroseconds
    self.initialVariance = initialVariance
    self.maximumVariance = maximumVariance
    self.processVariancePerSecond = processVariancePerSecond
    self.observationVariance = observationVariance
    self.vulnerabilityGainPerSecond = vulnerabilityGainPerSecond
    self.recoveryPerSecond = recoveryPerSecond
    self.uncertaintyRiskWeight = uncertaintyRiskWeight
  }

  public static var runtimeFoundationV0: Self {
    get throws {
      try Self(
        forceScaleNewtons: 1_000,
        loadTimeConstantMicroseconds: 200_000,
        initialVariance: 40_000,
        maximumVariance: 1_000_000,
        processVariancePerSecond: 20_000,
        observationVariance: 10_000,
        vulnerabilityGainPerSecond: 0.5,
        recoveryPerSecond: 0.025,
        uncertaintyRiskWeight: 0.15
      )
    }
  }

  public func initialState(
    bodyCount: UInt32,
    timestamp: BrainTimestamp = BrainTimestamp(microseconds: 0)
  ) throws -> [BodySchemaPosteriorCell] {
    try (0..<bodyCount).map {
      try BodySchemaPosteriorCell.unobserved(
        bodyIdentifier: $0,
        initialVariance: initialVariance,
        timestamp: timestamp
      )
    }
  }

  public func advance(
    previous: [BodySchemaPosteriorCell],
    bodyLoads: [BodyLoadFieldCell],
    bodyCount: UInt32,
    targetTimestamp: BrainTimestamp
  ) throws -> [BodySchemaPosteriorCell] {
    guard previous.count == Int(bodyCount),
      previous.enumerated().allSatisfy({ index, cell in
        cell.bodyIdentifier == UInt32(index) && cell.stateTimestamp <= targetTimestamp
      }),
      bodyLoads.allSatisfy({ $0.bodyIdentifier < bodyCount }),
      Set(bodyLoads.map(\.bodyIdentifier)).count == bodyLoads.count
    else {
      throw BrainRuntimeError.transaction("body-schema input state is invalid")
    }
    let loadByBody = Dictionary(
      uniqueKeysWithValues: bodyLoads.map { ($0.bodyIdentifier, $0) }
    )
    return try previous.map { cell in
      try advance(
        previous: cell,
        bodyLoad: loadByBody[cell.bodyIdentifier],
        targetTimestamp: targetTimestamp
      )
    }
  }

  public func advance(
    previous: BodySchemaPosteriorCell,
    bodyLoad: BodyLoadFieldCell?,
    targetTimestamp: BrainTimestamp
  ) throws -> BodySchemaPosteriorCell {
    guard previous.stateTimestamp <= targetTimestamp else {
      throw BrainRuntimeError.transaction("body-schema state cannot move backward in time")
    }
    let elapsedMicroseconds = targetTimestamp.rawValue - previous.stateTimestamp.rawValue
    let elapsedSeconds = Float(elapsedMicroseconds) * 0.000_001
    let loadRetention = max(
      0,
      1 - Float(elapsedMicroseconds) / Float(loadTimeConstantMicroseconds)
    )
    let priorLoad = previous.estimatedAbsoluteLoad * loadRetention
    let priorVariance = min(
      maximumVariance,
      previous.epistemicVariance + processVariancePerSecond * elapsedSeconds
    )

    let isFreshObservation = bodyLoad?.fieldActivationTimestamp == targetTimestamp
    let estimatedLoad: Float
    let posteriorVariance: Float
    let sourceMuscleIdentifier: UInt32
    let endpointRole: BodyLoadEndpointRole
    let lastObservationTimestamp: BrainTimestamp?
    var flags = previous.flags.subtracting(.observedThisUpdate)
    if let bodyLoad, isFreshObservation {
      let gain = priorVariance / (priorVariance + observationVariance)
      estimatedLoad = max(
        0,
        priorLoad + gain * (bodyLoad.effectiveAbsoluteMuscleForce - priorLoad)
      )
      posteriorVariance = max(0, (1 - gain) * priorVariance)
      sourceMuscleIdentifier = bodyLoad.sourceMuscleIdentifier
      endpointRole = bodyLoad.endpointRole
      lastObservationTimestamp = targetTimestamp
      flags.insert([.everObserved, .observedThisUpdate])
      flags = flags.subtracting([.firstRouteEndpoint, .terminalRouteEndpoint])
      if endpointRole.contains(.firstRouteEndpoint) {
        flags.insert(.firstRouteEndpoint)
      }
      if endpointRole.contains(.terminalRouteEndpoint) {
        flags.insert(.terminalRouteEndpoint)
      }
    } else {
      estimatedLoad = priorLoad
      posteriorVariance = priorVariance
      sourceMuscleIdentifier = previous.sourceMuscleIdentifier
      endpointRole = previous.endpointRole
      lastObservationTimestamp = previous.lastObservationTimestamp
    }

    let normalizedLoad = min(max(estimatedLoad / forceScaleNewtons, 0), 1)
    let vulnerability = min(
      max(
        previous.vulnerability
          + elapsedSeconds
            * (vulnerabilityGainPerSecond * normalizedLoad
              - recoveryPerSecond * (1 - normalizedLoad)),
        0
      ),
      1
    )
    let normalizedUncertainty = min(
      Foundation.sqrt(posteriorVariance) / forceScaleNewtons,
      1
    )
    let damageRisk = lastObservationTimestamp == nil
      ? 0
      : min(
        normalizedLoad * (0.25 + 0.75 * vulnerability)
          + uncertaintyRiskWeight * normalizedUncertainty,
        1
      )
    return try BodySchemaPosteriorCell(
      bodyIdentifier: previous.bodyIdentifier,
      flags: flags,
      sourceMuscleIdentifier: sourceMuscleIdentifier,
      endpointRole: endpointRole,
      estimatedAbsoluteLoad: estimatedLoad,
      epistemicVariance: posteriorVariance,
      vulnerability: vulnerability,
      damageRisk: damageRisk,
      lastObservationTimestamp: lastObservationTimestamp,
      stateTimestamp: targetTimestamp
    )
  }
}

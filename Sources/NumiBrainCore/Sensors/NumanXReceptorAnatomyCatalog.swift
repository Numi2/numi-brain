import Foundation

/// One immutable scalar endpoint exported by NumanX and attributed to a
/// species body signal. `sourceEndpointIdentifier` is the physical producer's
/// stable identity; `identifier` is the NumiBrain binding identity.
@frozen
public struct NumanXReceptorEndpoint: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt32
  public let sourceEndpointIdentifier: UInt64
  public let bodyIdentifier: UInt32
  public let modality: SensoryModality
  public let receptorIndex: UInt32
  public let featureIndex: UInt32
  public let signal: BodyReceptorSignal
  public let component: UInt16
  public let scale: Float
  public let bias: Float
  public let weight: Float

  public init(
    identifier: UInt32,
    sourceEndpointIdentifier: UInt64,
    bodyIdentifier: UInt32,
    modality: SensoryModality,
    receptorIndex: UInt32,
    featureIndex: UInt32,
    signal: BodyReceptorSignal,
    component: UInt16 = 0,
    scale: Float = 1,
    bias: Float = 0,
    weight: Float = 1
  ) throws {
    guard identifier > 0, sourceEndpointIdentifier > 0,
      component < Self.componentCount(for: signal),
      scale.isFinite, bias.isFinite, weight.isFinite, weight > 0
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX receptor endpoint calibration is invalid"
      )
    }
    self.identifier = identifier
    self.sourceEndpointIdentifier = sourceEndpointIdentifier
    self.bodyIdentifier = bodyIdentifier
    self.modality = modality
    self.receptorIndex = receptorIndex
    self.featureIndex = featureIndex
    self.signal = signal
    self.component = component
    self.scale = scale
    self.bias = bias
    self.weight = weight
  }

  public func compiledBinding(
    sourceModelFingerprint: UInt64 = 0
  ) throws -> BodyReceptorBinding {
    try BodyReceptorBinding(
      identifier: identifier,
      sourceModelFingerprint: sourceModelFingerprint,
      sourceEndpointIdentifier: sourceEndpointIdentifier,
      bodyIdentifier: bodyIdentifier,
      modality: modality,
      receptorIndex: receptorIndex,
      featureIndex: featureIndex,
      signal: signal,
      component: component,
      scale: scale,
      bias: bias,
      weight: weight
    )
  }

  private static func componentCount(for signal: BodyReceptorSignal) -> UInt16 {
    switch signal {
    case .orientation: 4
    case .position, .velocity, .localForce, .angularVelocity,
      .positionVariance, .orientationVariance: 3
    case .contact, .support, .nociception, .vestibularStability: 1
    }
  }

  private enum CodingKeys: String, CodingKey {
    case identifier
    case sourceEndpointIdentifier
    case bodyIdentifier
    case modality
    case receptorIndex
    case featureIndex
    case signal
    case component
    case scale
    case bias
    case weight
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      identifier: values.decode(UInt32.self, forKey: .identifier),
      sourceEndpointIdentifier: values.decode(
        UInt64.self, forKey: .sourceEndpointIdentifier
      ),
      bodyIdentifier: values.decode(UInt32.self, forKey: .bodyIdentifier),
      modality: values.decode(SensoryModality.self, forKey: .modality),
      receptorIndex: values.decode(UInt32.self, forKey: .receptorIndex),
      featureIndex: values.decode(UInt32.self, forKey: .featureIndex),
      signal: values.decode(BodyReceptorSignal.self, forKey: .signal),
      component: values.decodeIfPresent(UInt16.self, forKey: .component) ?? 0,
      scale: values.decode(Float.self, forKey: .scale),
      bias: values.decode(Float.self, forKey: .bias),
      weight: values.decode(Float.self, forKey: .weight)
    )
  }
}

/// Content-addressed bridge between one NumanX physical model and the
/// receptor topology declared by one species template. The catalog is kept on
/// the orchestration side; only its compiled scalar binding table enters the
/// GPU hot path.
@frozen
public struct NumanXReceptorAnatomyCatalog: Codable, Equatable, Hashable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let numanXModelFingerprint: UInt64
  public let speciesTemplateFingerprint: UInt64
  public let endpoints: [NumanXReceptorEndpoint]
  public let fingerprint: UInt64

  public init(
    species: SpeciesTemplate,
    numanXModelFingerprint: UInt64,
    endpoints: [NumanXReceptorEndpoint]
  ) throws {
    guard numanXModelFingerprint > 0, species.fingerprint > 0,
      !endpoints.isEmpty
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX receptor anatomy catalog identity is incomplete"
      )
    }
    try Self.validate(endpoints: endpoints, species: species)
    let canonicalEndpoints = endpoints.sorted { $0.identifier < $1.identifier }
    self.numanXModelFingerprint = numanXModelFingerprint
    self.speciesTemplateFingerprint = species.fingerprint
    self.endpoints = canonicalEndpoints
    self.fingerprint = Self.computeFingerprint(
      numanXModelFingerprint: numanXModelFingerprint,
      speciesTemplateFingerprint: species.fingerprint,
      endpoints: canonicalEndpoints
    )
  }

  /// Revalidates the physical catalog against the exact species generation
  /// before producing the immutable body-receptor bindings used by Metal.
  public func compiledBindings(
    for species: SpeciesTemplate
  ) throws -> [BodyReceptorBinding] {
    guard speciesTemplateFingerprint == species.fingerprint else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX receptor anatomy catalog species fingerprint drift"
      )
    }
    try Self.validate(endpoints: endpoints, species: species)
    return try endpoints.map {
      try $0.compiledBinding(sourceModelFingerprint: numanXModelFingerprint)
    }
  }

  public var fingerprintHex: String {
    String(format: "%016llx", fingerprint)
  }

  private static func validate(
    endpoints: [NumanXReceptorEndpoint],
    species: SpeciesTemplate
  ) throws {
    guard Set(endpoints.map(\.identifier)).count == endpoints.count else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX receptor endpoint identifiers are duplicated"
      )
    }
    let topologyByModality = Dictionary(
      uniqueKeysWithValues: species.senses.map { ($0.modality, $0) }
    )
    for endpoint in endpoints {
      guard endpoint.bodyIdentifier < species.body.bodyCount,
        let topology = topologyByModality[endpoint.modality], topology.enabled,
        endpoint.receptorIndex < topology.receptorCount,
        endpoint.featureIndex < topology.observationDimension
      else {
        throw BrainRuntimeError.invalidDescriptor(
          "NumanX receptor endpoint exceeds species anatomy"
        )
      }
    }
  }

  private enum CodingKeys: String, CodingKey {
    case formatVersion
    case numanXModelFingerprint
    case speciesTemplateFingerprint
    case endpoints
    case fingerprint
  }

  public func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(Self.formatVersion, forKey: .formatVersion)
    try values.encode(numanXModelFingerprint, forKey: .numanXModelFingerprint)
    try values.encode(speciesTemplateFingerprint, forKey: .speciesTemplateFingerprint)
    try values.encode(endpoints, forKey: .endpoints)
    try values.encode(fingerprint, forKey: .fingerprint)
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    guard try values.decode(UInt32.self, forKey: .formatVersion)
      == Self.formatVersion
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX receptor anatomy catalog format is unsupported"
      )
    }
    let numanXModelFingerprint = try values.decode(
      UInt64.self, forKey: .numanXModelFingerprint
    )
    let speciesTemplateFingerprint = try values.decode(
      UInt64.self, forKey: .speciesTemplateFingerprint
    )
    let endpoints = try values.decode(
      [NumanXReceptorEndpoint].self, forKey: .endpoints
    ).sorted { $0.identifier < $1.identifier }
    guard numanXModelFingerprint > 0, speciesTemplateFingerprint > 0,
      !endpoints.isEmpty,
      Set(endpoints.map(\.identifier)).count == endpoints.count
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "decoded NumanX receptor anatomy catalog is incomplete"
      )
    }
    let fingerprint = Self.computeFingerprint(
      numanXModelFingerprint: numanXModelFingerprint,
      speciesTemplateFingerprint: speciesTemplateFingerprint,
      endpoints: endpoints
    )
    guard fingerprint == (try values.decode(UInt64.self, forKey: .fingerprint))
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX receptor anatomy catalog fingerprint drift"
      )
    }
    self.numanXModelFingerprint = numanXModelFingerprint
    self.speciesTemplateFingerprint = speciesTemplateFingerprint
    self.endpoints = endpoints
    self.fingerprint = fingerprint
  }

  private static func computeFingerprint(
    numanXModelFingerprint: UInt64,
    speciesTemplateFingerprint: UInt64,
    endpoints: [NumanXReceptorEndpoint]
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    mix(UInt64(formatVersion), into: &hash)
    mix(numanXModelFingerprint, into: &hash)
    mix(speciesTemplateFingerprint, into: &hash)
    mix(UInt64(endpoints.count), into: &hash)
    for endpoint in endpoints {
      mix(UInt64(endpoint.identifier), into: &hash)
      mix(endpoint.sourceEndpointIdentifier, into: &hash)
      mix(UInt64(endpoint.bodyIdentifier), into: &hash)
      mix(UInt64(endpoint.modality.rawValue), into: &hash)
      mix(UInt64(endpoint.receptorIndex), into: &hash)
      mix(UInt64(endpoint.featureIndex), into: &hash)
      mix(UInt64(endpoint.signal.rawValue), into: &hash)
      mix(UInt64(endpoint.component), into: &hash)
      mix(UInt64(endpoint.scale.bitPattern), into: &hash)
      mix(UInt64(endpoint.bias.bitPattern), into: &hash)
      mix(UInt64(endpoint.weight.bitPattern), into: &hash)
    }
    return hash
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

extension SensoryTransductionProfile {
  /// Compiles the physical NumanX receptor catalog into the causal sensory
  /// profile. Endpoint provenance becomes part of the profile fingerprint and
  /// therefore part of every accepted NumanX sensor packet identity.
  public init(
    species: SpeciesTemplate,
    eventRules: [ReceptorEventRule],
    numanXReceptorAnatomy: NumanXReceptorAnatomyCatalog,
    includePhysiologicalCriticalRules: Bool = true
  ) throws {
    try self.init(
      species: species,
      eventRules: eventRules,
      bodyReceptorBindings: numanXReceptorAnatomy.compiledBindings(for: species),
      includePhysiologicalCriticalRules: includePhysiologicalCriticalRules
    )
  }
}

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
      .positionVariance, .orientationVariance:
      3
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

/// One immutable NumanX kinesthetic receptor attributed to an exact joint
/// coordinate and physical producer endpoint.
@frozen
public struct NumanXJointReceptorEndpoint: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt32
  public let sourceEndpointIdentifier: UInt64
  public let jointIdentifier: UInt32
  public let coordinateIdentifier: UInt16
  public let modality: SensoryModality
  public let receptorIndex: UInt32
  public let featureIndex: UInt32
  public let signal: JointReceptorSignal
  public let scale: Float
  public let bias: Float
  public let weight: Float

  public init(
    identifier: UInt32,
    sourceEndpointIdentifier: UInt64,
    jointIdentifier: UInt32,
    coordinateIdentifier: UInt16,
    modality: SensoryModality = .kinesthesia,
    receptorIndex: UInt32,
    featureIndex: UInt32,
    signal: JointReceptorSignal,
    scale: Float = 1,
    bias: Float = 0,
    weight: Float = 1
  ) throws {
    guard identifier > 0, sourceEndpointIdentifier > 0,
      scale.isFinite, bias.isFinite, weight.isFinite, weight > 0
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX joint receptor endpoint calibration is invalid"
      )
    }
    self.identifier = identifier
    self.sourceEndpointIdentifier = sourceEndpointIdentifier
    self.jointIdentifier = jointIdentifier
    self.coordinateIdentifier = coordinateIdentifier
    self.modality = modality
    self.receptorIndex = receptorIndex
    self.featureIndex = featureIndex
    self.signal = signal
    self.scale = scale
    self.bias = bias
    self.weight = weight
  }

  public func compiledBinding(
    sourceModelFingerprint: UInt64
  ) throws -> JointReceptorBinding {
    try JointReceptorBinding(
      identifier: identifier,
      sourceModelFingerprint: sourceModelFingerprint,
      sourceEndpointIdentifier: sourceEndpointIdentifier,
      jointIdentifier: jointIdentifier,
      coordinateIdentifier: coordinateIdentifier,
      modality: modality,
      receptorIndex: receptorIndex,
      featureIndex: featureIndex,
      signal: signal,
      scale: scale,
      bias: bias,
      weight: weight
    )
  }
}

/// One immutable NumanX proprioceptor attributed to an exact muscle in the
/// content-addressed attachment graph.
@frozen
public struct NumanXMuscleReceptorEndpoint: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt32
  public let sourceEndpointIdentifier: UInt64
  public let muscleIdentifier: UInt32
  public let modality: SensoryModality
  public let receptorIndex: UInt32
  public let featureIndex: UInt32
  public let signal: MuscleReceptorSignal
  public let scale: Float
  public let bias: Float
  public let weight: Float

  public init(
    identifier: UInt32,
    sourceEndpointIdentifier: UInt64,
    muscleIdentifier: UInt32,
    modality: SensoryModality = .proprioception,
    receptorIndex: UInt32,
    featureIndex: UInt32,
    signal: MuscleReceptorSignal,
    scale: Float = 1,
    bias: Float = 0,
    weight: Float = 1
  ) throws {
    guard identifier > 0, sourceEndpointIdentifier > 0,
      scale.isFinite, bias.isFinite, weight.isFinite, weight > 0
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX muscle receptor endpoint calibration is invalid"
      )
    }
    self.identifier = identifier
    self.sourceEndpointIdentifier = sourceEndpointIdentifier
    self.muscleIdentifier = muscleIdentifier
    self.modality = modality
    self.receptorIndex = receptorIndex
    self.featureIndex = featureIndex
    self.signal = signal
    self.scale = scale
    self.bias = bias
    self.weight = weight
  }

  public func compiledBinding(
    sourceModelFingerprint: UInt64
  ) throws -> MuscleReceptorBinding {
    try MuscleReceptorBinding(
      identifier: identifier,
      sourceModelFingerprint: sourceModelFingerprint,
      sourceEndpointIdentifier: sourceEndpointIdentifier,
      muscleIdentifier: muscleIdentifier,
      modality: modality,
      receptorIndex: receptorIndex,
      featureIndex: featureIndex,
      signal: signal,
      scale: scale,
      bias: bias,
      weight: weight
    )
  }
}

/// Content-addressed bridge between one NumanX physical model and the
/// receptor topology declared by one species template. The catalog is kept on
/// the orchestration side; only its compiled scalar binding table enters the
/// GPU hot path.
@frozen
public struct NumanXReceptorAnatomyCatalog: Codable, Equatable, Hashable, Sendable {
  public static let formatVersion: UInt32 = 3

  public let numanXModelFingerprint: UInt64
  public let speciesTemplateFingerprint: UInt64
  public let jointTopologyFingerprint: UInt64
  public let muscleAttachmentFingerprint: UInt64
  public let endpoints: [NumanXReceptorEndpoint]
  public let jointEndpoints: [NumanXJointReceptorEndpoint]
  public let muscleEndpoints: [NumanXMuscleReceptorEndpoint]
  public let fingerprint: UInt64

  public init(
    species: SpeciesTemplate,
    jointTopologyCatalog: NumanXJointTopologyCatalog,
    muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog?,
    numanXModelFingerprint: UInt64,
    endpoints: [NumanXReceptorEndpoint],
    jointEndpoints: [NumanXJointReceptorEndpoint],
    muscleEndpoints: [NumanXMuscleReceptorEndpoint]
  ) throws {
    guard numanXModelFingerprint > 0, species.fingerprint > 0,
      !endpoints.isEmpty,
      jointTopologyCatalog.numanXModelFingerprint == numanXModelFingerprint,
      (species.body.muscleCount == 0 && muscleAttachmentCatalog == nil
        && muscleEndpoints.isEmpty)
        || (species.body.muscleCount > 0
          && muscleAttachmentCatalog?.fingerprint
            == species.body.muscleAttachmentFingerprint
          && !muscleEndpoints.isEmpty),
      Set(
        endpoints.map(\.identifier) + jointEndpoints.map(\.identifier)
          + muscleEndpoints.map(\.identifier)
      ).count == endpoints.count + jointEndpoints.count + muscleEndpoints.count
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX receptor anatomy catalog identity is incomplete"
      )
    }
    try jointTopologyCatalog.validate(species: species)
    try Self.validate(endpoints: endpoints, species: species)
    try Self.validate(
      jointEndpoints: jointEndpoints,
      species: species,
      jointTopologyCatalog: jointTopologyCatalog
    )
    try Self.validate(
      muscleEndpoints: muscleEndpoints,
      species: species,
      muscleAttachmentCatalog: muscleAttachmentCatalog
    )
    let canonicalEndpoints = endpoints.sorted { $0.identifier < $1.identifier }
    let canonicalJointEndpoints = jointEndpoints.sorted {
      $0.identifier < $1.identifier
    }
    let canonicalMuscleEndpoints = muscleEndpoints.sorted {
      $0.identifier < $1.identifier
    }
    self.numanXModelFingerprint = numanXModelFingerprint
    self.speciesTemplateFingerprint = species.fingerprint
    self.jointTopologyFingerprint = jointTopologyCatalog.fingerprint
    self.muscleAttachmentFingerprint = muscleAttachmentCatalog?.fingerprint ?? 0
    self.endpoints = canonicalEndpoints
    self.jointEndpoints = canonicalJointEndpoints
    self.muscleEndpoints = canonicalMuscleEndpoints
    self.fingerprint = Self.computeFingerprint(
      numanXModelFingerprint: numanXModelFingerprint,
      speciesTemplateFingerprint: species.fingerprint,
      jointTopologyFingerprint: jointTopologyCatalog.fingerprint,
      muscleAttachmentFingerprint: muscleAttachmentCatalog?.fingerprint ?? 0,
      endpoints: canonicalEndpoints,
      jointEndpoints: canonicalJointEndpoints,
      muscleEndpoints: canonicalMuscleEndpoints
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

  public func compiledJointBindings(
    for species: SpeciesTemplate,
    jointTopologyCatalog: NumanXJointTopologyCatalog
  ) throws -> [JointReceptorBinding] {
    guard speciesTemplateFingerprint == species.fingerprint,
      jointTopologyFingerprint == jointTopologyCatalog.fingerprint,
      numanXModelFingerprint == jointTopologyCatalog.numanXModelFingerprint
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX joint receptor anatomy identity drift"
      )
    }
    try jointTopologyCatalog.validate(species: species)
    try Self.validate(
      jointEndpoints: jointEndpoints,
      species: species,
      jointTopologyCatalog: jointTopologyCatalog
    )
    return try jointEndpoints.map {
      try $0.compiledBinding(sourceModelFingerprint: numanXModelFingerprint)
    }
  }

  public func compiledMuscleBindings(
    for species: SpeciesTemplate,
    muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog?
  ) throws -> [MuscleReceptorBinding] {
    guard speciesTemplateFingerprint == species.fingerprint,
      muscleAttachmentFingerprint == (muscleAttachmentCatalog?.fingerprint ?? 0)
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX muscle receptor anatomy identity drift"
      )
    }
    try Self.validate(
      muscleEndpoints: muscleEndpoints,
      species: species,
      muscleAttachmentCatalog: muscleAttachmentCatalog
    )
    return try muscleEndpoints.map {
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
    guard Set(endpoints.map(\.identifier)).count == endpoints.count,
      endpoints.contains(where: { $0.bodyIdentifier == 0 })
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX body receptor anatomy requires unique endpoints and root evidence"
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

  private static func validate(
    jointEndpoints: [NumanXJointReceptorEndpoint],
    species: SpeciesTemplate,
    jointTopologyCatalog: NumanXJointTopologyCatalog
  ) throws {
    if jointEndpoints.isEmpty { return }
    guard Set(jointEndpoints.map(\.identifier)).count == jointEndpoints.count else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX joint receptor endpoint identifiers are duplicated"
      )
    }
    let topologyByModality = Dictionary(
      uniqueKeysWithValues: species.senses.map { ($0.modality, $0) }
    )
    var suppliedSignals: [UInt64: Set<JointReceptorSignal>] = [:]
    for endpoint in jointEndpoints {
      guard let joint = jointTopologyCatalog.joint(for: endpoint.jointIdentifier),
        joint.coordinates.contains(where: {
          $0.identifier == endpoint.coordinateIdentifier
        }),
        let topology = topologyByModality[endpoint.modality], topology.enabled,
        endpoint.receptorIndex < topology.receptorCount,
        endpoint.featureIndex < topology.observationDimension
      else {
        throw BrainRuntimeError.invalidDescriptor(
          "NumanX joint receptor endpoint exceeds species articulation anatomy"
        )
      }
      let key =
        UInt64(endpoint.jointIdentifier) << 16
        | UInt64(endpoint.coordinateIdentifier)
      suppliedSignals[key, default: []].insert(endpoint.signal)
    }
    let requiredCausalSignals: Set<JointReceptorSignal> = [.position, .velocity]
    for joint in jointTopologyCatalog.joints {
      for coordinate in joint.coordinates {
        let key =
          UInt64(joint.jointIdentifier) << 16
          | UInt64(coordinate.identifier)
        guard let signals = suppliedSignals[key],
          requiredCausalSignals.isSubset(of: signals)
        else {
          throw BrainRuntimeError.invalidDescriptor(
            "every sensed joint coordinate requires position and velocity authority"
          )
        }
      }
    }
  }

  private static func validate(
    muscleEndpoints: [NumanXMuscleReceptorEndpoint],
    species: SpeciesTemplate,
    muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog?
  ) throws {
    guard
      (species.body.muscleCount == 0 && muscleAttachmentCatalog == nil
        && muscleEndpoints.isEmpty)
        || (species.body.muscleCount > 0
          && species.body.bodyCount == muscleAttachmentCatalog?.bodyCount
          && species.body.muscleCount
            == UInt32(muscleAttachmentCatalog?.attachments.count ?? 0)
          && species.body.muscleAttachmentFingerprint
            == muscleAttachmentCatalog?.fingerprint
          && !muscleEndpoints.isEmpty),
      Set(muscleEndpoints.map(\.identifier)).count == muscleEndpoints.count
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX muscle receptor anatomy is incomplete"
      )
    }
    let topologyByModality = Dictionary(
      uniqueKeysWithValues: species.senses.map { ($0.modality, $0) }
    )
    let muscleIdentifiers = Set(
      muscleAttachmentCatalog?.attachments.map(\.muscleIdentifier) ?? []
    )
    var suppliedSignals: [UInt32: Set<MuscleReceptorSignal>] = [:]
    for endpoint in muscleEndpoints {
      guard muscleIdentifiers.contains(endpoint.muscleIdentifier),
        let topology = topologyByModality[endpoint.modality], topology.enabled,
        endpoint.receptorIndex < topology.receptorCount,
        endpoint.featureIndex < topology.observationDimension
      else {
        throw BrainRuntimeError.invalidDescriptor(
          "NumanX muscle receptor endpoint exceeds species anatomy"
        )
      }
      suppliedSignals[endpoint.muscleIdentifier, default: []].insert(endpoint.signal)
    }
    for muscleIdentifier in muscleIdentifiers {
      guard suppliedSignals[muscleIdentifier] == Set(MuscleReceptorSignal.allCases)
      else {
        throw BrainRuntimeError.invalidDescriptor(
          "every NumanX muscle requires length, velocity, force, and fatigue receptors"
        )
      }
    }
  }

  private enum CodingKeys: String, CodingKey {
    case formatVersion
    case numanXModelFingerprint
    case speciesTemplateFingerprint
    case jointTopologyFingerprint
    case muscleAttachmentFingerprint
    case endpoints
    case jointEndpoints
    case muscleEndpoints
    case fingerprint
  }

  public func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(Self.formatVersion, forKey: .formatVersion)
    try values.encode(numanXModelFingerprint, forKey: .numanXModelFingerprint)
    try values.encode(speciesTemplateFingerprint, forKey: .speciesTemplateFingerprint)
    try values.encode(jointTopologyFingerprint, forKey: .jointTopologyFingerprint)
    try values.encode(muscleAttachmentFingerprint, forKey: .muscleAttachmentFingerprint)
    try values.encode(endpoints, forKey: .endpoints)
    try values.encode(jointEndpoints, forKey: .jointEndpoints)
    try values.encode(muscleEndpoints, forKey: .muscleEndpoints)
    try values.encode(fingerprint, forKey: .fingerprint)
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    guard
      try values.decode(UInt32.self, forKey: .formatVersion)
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
    let jointTopologyFingerprint = try values.decode(
      UInt64.self, forKey: .jointTopologyFingerprint
    )
    let muscleAttachmentFingerprint = try values.decode(
      UInt64.self, forKey: .muscleAttachmentFingerprint
    )
    let endpoints = try values.decode(
      [NumanXReceptorEndpoint].self, forKey: .endpoints
    ).sorted { $0.identifier < $1.identifier }
    let jointEndpoints = try values.decode(
      [NumanXJointReceptorEndpoint].self, forKey: .jointEndpoints
    ).sorted { $0.identifier < $1.identifier }
    let muscleEndpoints = try values.decode(
      [NumanXMuscleReceptorEndpoint].self, forKey: .muscleEndpoints
    ).sorted { $0.identifier < $1.identifier }
    guard numanXModelFingerprint > 0, speciesTemplateFingerprint > 0,
      jointTopologyFingerprint > 0, !endpoints.isEmpty,
      (muscleAttachmentFingerprint == 0) == muscleEndpoints.isEmpty,
      Set(endpoints.map(\.identifier)).count == endpoints.count,
      Set(jointEndpoints.map(\.identifier)).count == jointEndpoints.count,
      Set(muscleEndpoints.map(\.identifier)).count == muscleEndpoints.count,
      Set(
        endpoints.map(\.identifier) + jointEndpoints.map(\.identifier)
          + muscleEndpoints.map(\.identifier)
      ).count == endpoints.count + jointEndpoints.count + muscleEndpoints.count
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "decoded NumanX receptor anatomy catalog is incomplete"
      )
    }
    let fingerprint = Self.computeFingerprint(
      numanXModelFingerprint: numanXModelFingerprint,
      speciesTemplateFingerprint: speciesTemplateFingerprint,
      jointTopologyFingerprint: jointTopologyFingerprint,
      muscleAttachmentFingerprint: muscleAttachmentFingerprint,
      endpoints: endpoints,
      jointEndpoints: jointEndpoints,
      muscleEndpoints: muscleEndpoints
    )
    guard fingerprint == (try values.decode(UInt64.self, forKey: .fingerprint))
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "NumanX receptor anatomy catalog fingerprint drift"
      )
    }
    self.numanXModelFingerprint = numanXModelFingerprint
    self.speciesTemplateFingerprint = speciesTemplateFingerprint
    self.jointTopologyFingerprint = jointTopologyFingerprint
    self.muscleAttachmentFingerprint = muscleAttachmentFingerprint
    self.endpoints = endpoints
    self.jointEndpoints = jointEndpoints
    self.muscleEndpoints = muscleEndpoints
    self.fingerprint = fingerprint
  }

  private static func computeFingerprint(
    numanXModelFingerprint: UInt64,
    speciesTemplateFingerprint: UInt64,
    jointTopologyFingerprint: UInt64,
    muscleAttachmentFingerprint: UInt64,
    endpoints: [NumanXReceptorEndpoint],
    jointEndpoints: [NumanXJointReceptorEndpoint],
    muscleEndpoints: [NumanXMuscleReceptorEndpoint]
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    mix(UInt64(formatVersion), into: &hash)
    mix(numanXModelFingerprint, into: &hash)
    mix(speciesTemplateFingerprint, into: &hash)
    mix(jointTopologyFingerprint, into: &hash)
    mix(muscleAttachmentFingerprint, into: &hash)
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
    mix(UInt64(jointEndpoints.count), into: &hash)
    for endpoint in jointEndpoints {
      mix(UInt64(endpoint.identifier), into: &hash)
      mix(endpoint.sourceEndpointIdentifier, into: &hash)
      mix(UInt64(endpoint.jointIdentifier), into: &hash)
      mix(UInt64(endpoint.coordinateIdentifier), into: &hash)
      mix(UInt64(endpoint.modality.rawValue), into: &hash)
      mix(UInt64(endpoint.receptorIndex), into: &hash)
      mix(UInt64(endpoint.featureIndex), into: &hash)
      mix(UInt64(endpoint.signal.rawValue), into: &hash)
      mix(UInt64(endpoint.scale.bitPattern), into: &hash)
      mix(UInt64(endpoint.bias.bitPattern), into: &hash)
      mix(UInt64(endpoint.weight.bitPattern), into: &hash)
    }
    mix(UInt64(muscleEndpoints.count), into: &hash)
    for endpoint in muscleEndpoints {
      mix(UInt64(endpoint.identifier), into: &hash)
      mix(endpoint.sourceEndpointIdentifier, into: &hash)
      mix(UInt64(endpoint.muscleIdentifier), into: &hash)
      mix(UInt64(endpoint.modality.rawValue), into: &hash)
      mix(UInt64(endpoint.receptorIndex), into: &hash)
      mix(UInt64(endpoint.featureIndex), into: &hash)
      mix(UInt64(endpoint.signal.rawValue), into: &hash)
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
    jointTopologyCatalog: NumanXJointTopologyCatalog,
    muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog?,
    includePhysiologicalCriticalRules: Bool = true
  ) throws {
    try self.init(
      species: species,
      eventRules: eventRules,
      bodyReceptorBindings: numanXReceptorAnatomy.compiledBindings(for: species),
      jointTopologyCatalog: jointTopologyCatalog,
      jointReceptorBindings: numanXReceptorAnatomy.compiledJointBindings(
        for: species,
        jointTopologyCatalog: jointTopologyCatalog
      ),
      muscleAttachmentCatalog: muscleAttachmentCatalog,
      muscleReceptorBindings: numanXReceptorAnatomy.compiledMuscleBindings(
        for: species,
        muscleAttachmentCatalog: muscleAttachmentCatalog
      ),
      includePhysiologicalCriticalRules: includePhysiologicalCriticalRules
    )
  }
}

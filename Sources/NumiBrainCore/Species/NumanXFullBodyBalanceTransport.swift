import Foundation

/// Native ownership record for one scalar support-load receptor in the Human
/// touch packet. The touch feature is fixed to the physical normal-force row;
/// no contact force or centre of pressure is inferred by NumiBrain.
@frozen
public struct NumanXFullBodySupportEndpoint: Codable, Equatable, Hashable, Sendable {
  public let sourceEndpointIdentifier: UInt64
  public let bodyIdentifier: UInt32
  public let touchReceptorIndex: UInt32
  public let scale: Float
  public let bias: Float
  public let weight: Float

  public init(
    sourceEndpointIdentifier: UInt64,
    bodyIdentifier: UInt32,
    touchReceptorIndex: UInt32,
    scale: Float = 1,
    bias: Float = 0,
    weight: Float = 1
  ) {
    self.sourceEndpointIdentifier = sourceEndpointIdentifier
    self.bodyIdentifier = bodyIdentifier
    self.touchReceptorIndex = touchReceptorIndex
    self.scale = scale
    self.bias = bias
    self.weight = weight
  }
}

extension NumanXFullBodyTransportTemplate {
  /// Compiles the existing 416-muscle transport and adds source-owned support
  /// bindings for the normal-force feature already delivered by HumanIO.
  /// This does not create a second sensor packet or expose privileged state.
  public static func compileWithSupportReceptors(
    latencyMicroseconds: UInt32 = 1_000,
    anatomy: NumanXFullBodyAnatomy,
    supportEndpoints: [NumanXFullBodySupportEndpoint]
  ) throws -> CompiledSpeciesTemplate {
    guard !supportEndpoints.isEmpty else {
      throw BrainRuntimeError.invalidDescriptor(
        "full-body balance transport requires physical support endpoints"
      )
    }
    let base = try compile(
      latencyMicroseconds: latencyMicroseconds,
      anatomy: anatomy
    )
    guard let touch = base.species.senses.first(where: {
      $0.enabled && $0.modality == .touch
    }), touch.observationDimension > 4 else {
      throw BrainRuntimeError.invalidDescriptor(
        "full-body balance transport requires the native touch-force feature"
      )
    }

    let sorted = supportEndpoints.sorted {
      $0.touchReceptorIndex < $1.touchReceptorIndex
    }
    let sourceIdentifiers = sorted.map(\.sourceEndpointIdentifier)
    let receptorIndices = sorted.map(\.touchReceptorIndex)
    let existingSourceIdentifiers = Set(
      base.numanXReceptorAnatomyCatalog.endpoints.map(
        \.sourceEndpointIdentifier
      )
        + base.numanXReceptorAnatomyCatalog.jointEndpoints.map(
          \.sourceEndpointIdentifier
        )
        + base.numanXReceptorAnatomyCatalog.muscleEndpoints.map(
          \.sourceEndpointIdentifier
        )
    )
    guard Set(sourceIdentifiers).count == sorted.count,
      Set(receptorIndices).count == sorted.count,
      existingSourceIdentifiers.isDisjoint(with: sourceIdentifiers)
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "support endpoints require unique physical producer and receptor identities"
      )
    }

    var usedBindingIdentifiers = Set(
      base.numanXReceptorAnatomyCatalog.endpoints.map(\.identifier)
        + base.numanXReceptorAnatomyCatalog.jointEndpoints.map(\.identifier)
        + base.numanXReceptorAnatomyCatalog.muscleEndpoints.map(\.identifier)
    )
    var supportBindings: [NumanXReceptorEndpoint] = []
    supportBindings.reserveCapacity(sorted.count)
    for endpoint in sorted {
      let (identifier, overflow) = UInt32(0x5350_0000)
        .addingReportingOverflow(endpoint.touchReceptorIndex)
      guard !overflow, identifier > 0,
        usedBindingIdentifiers.insert(identifier).inserted,
        endpoint.sourceEndpointIdentifier > 0,
        endpoint.bodyIdentifier < base.species.body.bodyCount,
        endpoint.touchReceptorIndex < touch.receptorCount,
        endpoint.scale.isFinite, endpoint.bias.isFinite,
        endpoint.weight.isFinite, endpoint.weight > 0
      else {
        throw BrainRuntimeError.invalidDescriptor(
          "support endpoint exceeds native Human touch or body anatomy"
        )
      }
      supportBindings.append(
        try NumanXReceptorEndpoint(
          identifier: identifier,
          sourceEndpointIdentifier: endpoint.sourceEndpointIdentifier,
          bodyIdentifier: endpoint.bodyIdentifier,
          modality: .touch,
          receptorIndex: endpoint.touchReceptorIndex,
          featureIndex: 4,
          signal: .support,
          component: 0,
          scale: endpoint.scale,
          bias: endpoint.bias,
          weight: endpoint.weight
        )
      )
    }

    let receptorAnatomy = try NumanXReceptorAnatomyCatalog(
      species: base.species,
      jointTopologyCatalog: anatomy.jointTopologyCatalog,
      muscleAttachmentCatalog: anatomy.muscleAttachmentCatalog,
      numanXModelFingerprint: anatomy.jointTopologyCatalog.numanXModelFingerprint,
      endpoints: base.numanXReceptorAnatomyCatalog.endpoints + supportBindings,
      jointEndpoints: base.numanXReceptorAnatomyCatalog.jointEndpoints,
      muscleEndpoints: base.numanXReceptorAnatomyCatalog.muscleEndpoints
    )
    let bodyBindings = try receptorAnatomy.compiledBindings(for: base.species)
    let jointBindings = try receptorAnatomy.compiledJointBindings(
      for: base.species,
      jointTopologyCatalog: anatomy.jointTopologyCatalog
    )
    let muscleBindings = try receptorAnatomy.compiledMuscleBindings(
      for: base.species,
      muscleAttachmentCatalog: anatomy.muscleAttachmentCatalog
    )
    let sensoryProfile = try SensoryTransductionProfile(
      species: base.species,
      eventRules: base.sensoryProfile.eventRules,
      bodyReceptorBindings: bodyBindings,
      jointTopologyCatalog: anatomy.jointTopologyCatalog,
      jointReceptorBindings: jointBindings,
      muscleAttachmentCatalog: anatomy.muscleAttachmentCatalog,
      muscleReceptorBindings: muscleBindings,
      includePhysiologicalCriticalRules: false
    )
    return try CompiledSpeciesTemplate(
      referenceBrainGraph: base.referenceBrainGraph,
      species: base.species,
      sensoryProfile: sensoryProfile,
      numanXReceptorAnatomyCatalog: receptorAnatomy,
      jointTopologyCatalog: anatomy.jointTopologyCatalog,
      protectiveMotorProfile: base.protectiveMotorProfile,
      muscleAttachmentCatalog: anatomy.muscleAttachmentCatalog,
      somaticSynergyCatalog: base.somaticSynergyCatalog
    )
  }
}

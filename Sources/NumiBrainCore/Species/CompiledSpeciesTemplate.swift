import Foundation

/// Content-addressed production product of species compilation. It binds the
/// logical nervous-system graph to one exact NumanX morphology and to every
/// receptor and actuator table consumed by the GPU runtimes.
@frozen
public struct CompiledSpeciesTemplate: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 2

  public let referenceBrainGraph: ReferenceBrainGraph
  public let species: SpeciesTemplate
  public let sensoryProfile: SensoryTransductionProfile
  public let numanXReceptorAnatomyCatalog: NumanXReceptorAnatomyCatalog
  public let jointTopologyCatalog: NumanXJointTopologyCatalog
  public let protectiveMotorProfile: ProtectiveMotorProfile
  public let muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog?
  public let somaticSynergyCatalog: SomaticSynergyCatalog
  public let fingerprint: UInt64

  public init(
    referenceBrainGraph: ReferenceBrainGraph,
    species: SpeciesTemplate,
    sensoryProfile: SensoryTransductionProfile,
    numanXReceptorAnatomyCatalog: NumanXReceptorAnatomyCatalog,
    jointTopologyCatalog: NumanXJointTopologyCatalog,
    protectiveMotorProfile: ProtectiveMotorProfile,
    muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog?,
    somaticSynergyCatalog: SomaticSynergyCatalog
  ) throws {
    guard species.referenceGraphFingerprint == referenceBrainGraph.fingerprint else {
      throw BrainRuntimeError.invalidDescriptor(
        "compiled species does not name its supplied reference brain graph"
      )
    }
    let canonicalSpecies = try SpeciesTemplate(
      family: species.family,
      name: species.name,
      referenceGraph: referenceBrainGraph,
      enabledModuleIdentifiers: species.enabledModuleIdentifiers,
      regionGraph: species.regionGraph,
      body: species.body,
      senses: species.senses,
      motor: species.motor,
      reflexes: species.reflexes,
      cpg: species.cpg,
      physiology: species.physiology,
      innateBehaviors: species.innateBehaviors,
      development: species.development,
      capacities: species.capacities
    )
    guard canonicalSpecies == species else {
      throw BrainRuntimeError.invalidDescriptor(
        "compiled species template has content or fingerprint drift"
      )
    }
    try jointTopologyCatalog.validate(species: species)
    try somaticSynergyCatalog.validate(motor: species.motor)

    guard sensoryProfile.speciesTemplateFingerprint == species.fingerprint,
      numanXReceptorAnatomyCatalog.speciesTemplateFingerprint
        == species.fingerprint,
      numanXReceptorAnatomyCatalog.numanXModelFingerprint
        == jointTopologyCatalog.numanXModelFingerprint,
      numanXReceptorAnatomyCatalog.jointTopologyFingerprint
        == jointTopologyCatalog.fingerprint,
      protectiveMotorProfile.channels.count == Int(species.motor.actuatorCount),
      protectiveMotorProfile.channels.map(\.muscleIdentifier)
        == species.motor.actuatorChannels.map(\.identifier)
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "compiled species components do not share one morphology identity"
      )
    }

    if species.body.muscleCount == 0 {
      guard muscleAttachmentCatalog == nil,
        numanXReceptorAnatomyCatalog.muscleAttachmentFingerprint == 0,
        sensoryProfile.muscleReceptorBindings.isEmpty
      else {
        throw BrainRuntimeError.invalidDescriptor(
          "non-muscular species cannot carry muscle attachment state"
        )
      }
    } else {
      guard let muscleAttachmentCatalog,
        muscleAttachmentCatalog.bodyCount == species.body.bodyCount,
        UInt32(muscleAttachmentCatalog.attachments.count)
          == species.body.muscleCount,
        muscleAttachmentCatalog.fingerprint
          == species.body.muscleAttachmentFingerprint,
        numanXReceptorAnatomyCatalog.muscleAttachmentFingerprint
          == muscleAttachmentCatalog.fingerprint
      else {
        throw BrainRuntimeError.invalidDescriptor(
          "compiled species muscle anatomy is incomplete"
        )
      }
      try muscleAttachmentCatalog.validate(profile: protectiveMotorProfile)
    }

    let bodyBindings = try numanXReceptorAnatomyCatalog.compiledBindings(
      for: species
    )
    let jointBindings = try numanXReceptorAnatomyCatalog.compiledJointBindings(
      for: species,
      jointTopologyCatalog: jointTopologyCatalog
    )
    let muscleBindings = try numanXReceptorAnatomyCatalog.compiledMuscleBindings(
      for: species,
      muscleAttachmentCatalog: muscleAttachmentCatalog
    )
    guard bodyBindings == sensoryProfile.bodyReceptorBindings,
      jointBindings == sensoryProfile.jointReceptorBindings,
      muscleBindings == sensoryProfile.muscleReceptorBindings
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "compiled species receptor bindings do not match NumanX anatomy"
      )
    }

    // Recompile the supplied receptor data without adding a second set of
    // physiological rules. This revalidates decoded profiles and their
    // content fingerprint against the exact species generation.
    let canonicalSensoryProfile = try SensoryTransductionProfile(
      species: species,
      eventRules: sensoryProfile.eventRules,
      bodyReceptorBindings: bodyBindings,
      jointTopologyCatalog: jointTopologyCatalog,
      jointReceptorBindings: jointBindings,
      muscleAttachmentCatalog: muscleAttachmentCatalog,
      muscleReceptorBindings: muscleBindings,
      includePhysiologicalCriticalRules: false
    )
    guard canonicalSensoryProfile == sensoryProfile else {
      throw BrainRuntimeError.invalidDescriptor(
        "compiled species sensory profile has content drift"
      )
    }

    self.referenceBrainGraph = referenceBrainGraph
    self.species = canonicalSpecies
    self.sensoryProfile = sensoryProfile
    self.numanXReceptorAnatomyCatalog = numanXReceptorAnatomyCatalog
    self.jointTopologyCatalog = jointTopologyCatalog
    self.protectiveMotorProfile = protectiveMotorProfile
    self.muscleAttachmentCatalog = muscleAttachmentCatalog
    self.somaticSynergyCatalog = somaticSynergyCatalog
    self.fingerprint = Self.computeFingerprint(
      referenceBrainGraph: referenceBrainGraph,
      species: canonicalSpecies,
      sensoryProfile: sensoryProfile,
      numanXReceptorAnatomyCatalog: numanXReceptorAnatomyCatalog,
      jointTopologyCatalog: jointTopologyCatalog,
      protectiveMotorProfile: protectiveMotorProfile,
      muscleAttachmentCatalog: muscleAttachmentCatalog,
      somaticSynergyCatalog: somaticSynergyCatalog
    )
  }

  public var fingerprintHex: String {
    String(format: "%016llx", fingerprint)
  }

  private enum CodingKeys: String, CodingKey {
    case formatVersion
    case referenceBrainGraph
    case species
    case sensoryProfile
    case numanXReceptorAnatomyCatalog
    case jointTopologyCatalog
    case protectiveMotorProfile
    case muscleAttachmentCatalog
    case somaticSynergyCatalog
    case fingerprint
  }

  public func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(Self.formatVersion, forKey: .formatVersion)
    try values.encode(referenceBrainGraph, forKey: .referenceBrainGraph)
    try values.encode(species, forKey: .species)
    try values.encode(sensoryProfile, forKey: .sensoryProfile)
    try values.encode(
      numanXReceptorAnatomyCatalog,
      forKey: .numanXReceptorAnatomyCatalog
    )
    try values.encode(jointTopologyCatalog, forKey: .jointTopologyCatalog)
    try values.encode(protectiveMotorProfile, forKey: .protectiveMotorProfile)
    try values.encodeIfPresent(
      muscleAttachmentCatalog,
      forKey: .muscleAttachmentCatalog
    )
    try values.encode(somaticSynergyCatalog, forKey: .somaticSynergyCatalog)
    try values.encode(fingerprint, forKey: .fingerprint)
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    guard try values.decode(UInt32.self, forKey: .formatVersion)
      == Self.formatVersion
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "compiled species template format is unsupported"
      )
    }
    let decoded = try Self(
      referenceBrainGraph: values.decode(
        ReferenceBrainGraph.self,
        forKey: .referenceBrainGraph
      ),
      species: values.decode(SpeciesTemplate.self, forKey: .species),
      sensoryProfile: values.decode(
        SensoryTransductionProfile.self,
        forKey: .sensoryProfile
      ),
      numanXReceptorAnatomyCatalog: values.decode(
        NumanXReceptorAnatomyCatalog.self,
        forKey: .numanXReceptorAnatomyCatalog
      ),
      jointTopologyCatalog: values.decode(
        NumanXJointTopologyCatalog.self,
        forKey: .jointTopologyCatalog
      ),
      protectiveMotorProfile: values.decode(
        ProtectiveMotorProfile.self,
        forKey: .protectiveMotorProfile
      ),
      muscleAttachmentCatalog: values.decodeIfPresent(
        NumanXMuscleAttachmentCatalog.self,
        forKey: .muscleAttachmentCatalog
      ),
      somaticSynergyCatalog: values.decode(
        SomaticSynergyCatalog.self,
        forKey: .somaticSynergyCatalog
      )
    )
    guard decoded.fingerprint
      == (try values.decode(UInt64.self, forKey: .fingerprint))
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "compiled species template fingerprint drift"
      )
    }
    self = decoded
  }

  private static func computeFingerprint(
    referenceBrainGraph: ReferenceBrainGraph,
    species: SpeciesTemplate,
    sensoryProfile: SensoryTransductionProfile,
    numanXReceptorAnatomyCatalog: NumanXReceptorAnatomyCatalog,
    jointTopologyCatalog: NumanXJointTopologyCatalog,
    protectiveMotorProfile: ProtectiveMotorProfile,
    muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog?,
    somaticSynergyCatalog: SomaticSynergyCatalog
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for value in [
      UInt64(formatVersion), species.fingerprint, sensoryProfile.fingerprint,
      referenceBrainGraph.fingerprint,
      numanXReceptorAnatomyCatalog.fingerprint,
      jointTopologyCatalog.fingerprint, protectiveMotorProfile.fingerprint,
      muscleAttachmentCatalog?.fingerprint ?? 0,
      somaticSynergyCatalog.fingerprint,
    ] {
      mix(value, into: &hash)
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

extension SpeciesTemplateCompiler {
  /// Produces the immutable runtime anatomy contract after all constituent
  /// catalogs have been compiled from authoritative species and NumanX data.
  public static func compileRuntimeTemplate(
    referenceBrainGraph: ReferenceBrainGraph,
    species: SpeciesTemplate,
    sensoryProfile: SensoryTransductionProfile,
    numanXReceptorAnatomyCatalog: NumanXReceptorAnatomyCatalog,
    jointTopologyCatalog: NumanXJointTopologyCatalog,
    muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog?,
    somaticSynergyCatalog: SomaticSynergyCatalog,
    protectiveMotorProfile: ProtectiveMotorProfile? = nil
  ) throws -> CompiledSpeciesTemplate {
    try CompiledSpeciesTemplate(
      referenceBrainGraph: referenceBrainGraph,
      species: species,
      sensoryProfile: sensoryProfile,
      numanXReceptorAnatomyCatalog: numanXReceptorAnatomyCatalog,
      jointTopologyCatalog: jointTopologyCatalog,
      protectiveMotorProfile: protectiveMotorProfile
        ?? ProtectiveMotorProfile.compiled(species: species),
      muscleAttachmentCatalog: muscleAttachmentCatalog,
      somaticSynergyCatalog: somaticSynergyCatalog
    )
  }
}

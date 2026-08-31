import Foundation
@preconcurrency import Metal
import NumiBrainCore

/// Complete construction contract for one standalone embodied brain. The
/// configuration contains physical tissue and receptor inputs; the species
/// owns the regional graph, actuator topology, reflexes, development, and
/// per-agent capacities.
@frozen
public struct MetalNumiBrainConfiguration: Sendable {
  public let initialTissueState: TissueGrid
  public let tissueParameters: TissueParameters
  public let tissueStimulus: TissueStimulus
  public let tissueStructure: TissueStructure?
  public let tissueDelayField: TissueDelayField?
  public let tissueConnectome: TissueConnectome?
  public let tissueEventSchedule: TissueEventSchedule?
  public let randomContext: TissueRandomContext
  public let compiledSpeciesTemplate: CompiledSpeciesTemplate
  public let schedulerEnvironmentIdentifier: UInt32
  public let maximumSchedulerEvents: Int
  public let maximumSchedulerInvocations: Int
  public let maximumEncodedSubsteps: Int

  public init(
    initialTissueState: TissueGrid,
    tissueParameters: TissueParameters,
    tissueStimulus: TissueStimulus,
    compiledSpeciesTemplate: CompiledSpeciesTemplate,
    tissueStructure: TissueStructure? = nil,
    tissueDelayField: TissueDelayField? = nil,
    tissueConnectome: TissueConnectome? = nil,
    tissueEventSchedule: TissueEventSchedule? = nil,
    randomContext: TissueRandomContext = .deterministicDefault,
    schedulerEnvironmentIdentifier: UInt32 = 0,
    maximumSchedulerEvents: Int = 64,
    maximumSchedulerInvocations: Int = 4_096,
    maximumEncodedSubsteps: Int = 4_096
  ) {
    self.initialTissueState = initialTissueState
    self.tissueParameters = tissueParameters
    self.tissueStimulus = tissueStimulus
    self.tissueStructure = tissueStructure
    self.tissueDelayField = tissueDelayField
    self.tissueConnectome = tissueConnectome
    self.tissueEventSchedule = tissueEventSchedule
    self.randomContext = randomContext
    self.compiledSpeciesTemplate = compiledSpeciesTemplate
    self.schedulerEnvironmentIdentifier = schedulerEnvironmentIdentifier
    self.maximumSchedulerEvents = maximumSchedulerEvents
    self.maximumSchedulerInvocations = maximumSchedulerInvocations
    self.maximumEncodedSubsteps = maximumEncodedSubsteps
  }
}

@available(macOS 26.0, *)
extension MetalNumiBrainRuntime {
  /// Constructs one unpublished runtime generation. The public owning handle
  /// uses this for initial creation and isolated checkpoint replacement.
  static func makeRuntime(
    configuration: MetalNumiBrainConfiguration,
    publication: BrainParameterPublication,
    device: any MTLDevice
  ) throws -> MetalNumiBrainRuntime {
    let compiledSpeciesTemplate = configuration.compiledSpeciesTemplate
    let species = compiledSpeciesTemplate.species
    let regionalProgram = try species.regionalProgram()
    let version = publication.version
    guard
      compiledSpeciesTemplate.sensoryProfile.speciesTemplateFingerprint
        == species.fingerprint,
      regionalProgram.scheduleFingerprint == species.regionGraph.schedule.fingerprint,
      version.scheduleFingerprint == regionalProgram.scheduleFingerprint,
      version.regionalShapeFingerprint == regionalProgram.shapeFingerprint,
      version.regionalProgramFingerprint == regionalProgram.fingerprint,
      version.components.first(where: { $0.kind == .tissueDynamics })?
        .contentFingerprint == configuration.tissueParameters.parameterFingerprint,
      publication.sharedArtifact.payload(.regionalDense).data.count
        == regionalProgram.denseParameterCount * MemoryLayout<Float>.stride
    else {
      throw TissueError.metal(
        "complete brain configuration does not share one species and parameter identity"
      )
    }
    let compiledBindings = try compiledSpeciesTemplate.numanXReceptorAnatomyCatalog
      .compiledBindings(for: species)
    try compiledSpeciesTemplate.jointTopologyCatalog.validate(species: species)
    let compiledJointBindings = try compiledSpeciesTemplate.numanXReceptorAnatomyCatalog
      .compiledJointBindings(
        for: species,
        jointTopologyCatalog: compiledSpeciesTemplate.jointTopologyCatalog
      )
    let compiledMuscleBindings = try compiledSpeciesTemplate.numanXReceptorAnatomyCatalog
      .compiledMuscleBindings(
        for: species,
        muscleAttachmentCatalog: compiledSpeciesTemplate.muscleAttachmentCatalog
      )
    guard compiledBindings == compiledSpeciesTemplate.sensoryProfile.bodyReceptorBindings,
      compiledJointBindings
        == compiledSpeciesTemplate.sensoryProfile.jointReceptorBindings,
      compiledMuscleBindings
        == compiledSpeciesTemplate.sensoryProfile.muscleReceptorBindings
    else {
      throw TissueError.metal(
        "NumanX receptor anatomy catalog does not own all sensory profile bindings"
      )
    }
    let protectiveProfile = compiledSpeciesTemplate.protectiveMotorProfile
    guard protectiveProfile.channels.count == Int(species.motor.actuatorCount),
      protectiveProfile.channels.map(\.muscleIdentifier)
        == species.motor.actuatorChannels.map(\.identifier)
    else {
      throw TissueError.metal(
        "protective actuator profile does not match the species motor topology"
      )
    }
    let somaticSynergyCatalog = compiledSpeciesTemplate.somaticSynergyCatalog
    try somaticSynergyCatalog.validate(motor: species.motor)
    let cognitive = try MetalEmbodiedBrainRuntime(
      device: device,
      compiledSpeciesTemplate: compiledSpeciesTemplate,
      regionalProgram: regionalProgram,
      parameterVersion: version,
      sharedParameterArtifact: publication.sharedArtifact
    )
    let fastTissue = try MetalTissueRuntime(
      initialState: configuration.initialTissueState,
      parameters: configuration.tissueParameters,
      stimulus: configuration.tissueStimulus,
      structure: configuration.tissueStructure,
      delayField: configuration.tissueDelayField,
      connectome: configuration.tissueConnectome,
      eventSchedule: configuration.tissueEventSchedule,
      randomContext: configuration.randomContext,
      brainSchedule: species.regionGraph.schedule,
      regionalTokenProgram: regionalProgram,
      parameterVersion: version,
      sharedParameterArtifact: publication.sharedArtifact,
      protectiveMotorProfile: protectiveProfile,
      numanXMuscleAttachmentCatalog: compiledSpeciesTemplate.muscleAttachmentCatalog,
      somaticSynergyCatalog: somaticSynergyCatalog,
      schedulerEnvironmentIdentifier: configuration.schedulerEnvironmentIdentifier,
      maxSchedulerEvents: configuration.maximumSchedulerEvents,
      maxSchedulerInvocations: configuration.maximumSchedulerInvocations,
      maxEncodedSubsteps: configuration.maximumEncodedSubsteps,
      device: device
    )
    return try MetalNumiBrainRuntime(
      cognitive: cognitive,
      fastTissue: fastTissue
    )
  }
}

@available(macOS 26.0, *)
extension MetalNumiBrainHandle {
  /// Creates the authoritative complete brain behind one replaceable owning
  /// handle. New developmental agents may explicitly use
  /// `BrainParameterPublication.developmentalSeedV1`; trained cohorts supply
  /// their exact learner publication instead.
  public static func create(
    configuration: MetalNumiBrainConfiguration,
    publication: BrainParameterPublication,
    device requestedDevice: (any MTLDevice)? = nil
  ) throws -> MetalNumiBrainHandle {
    guard let device = requestedDevice ?? MTLCreateSystemDefaultDevice() else {
      throw TissueError.metal("no Metal device is available")
    }
    let runtime = try MetalNumiBrainRuntime.makeRuntime(
      configuration: configuration,
      publication: publication,
      device: device
    )
    return MetalNumiBrainHandle(
      runtime: runtime,
      configuration: configuration,
      publication: publication,
      device: device
    )
  }

  /// Creates a runtime from one learned-policy package only after the evidence
  /// verifier has streamed and semantically checked every retained artifact.
  /// The receipt is in-process authority and cannot be decoded or constructed
  /// from package declarations alone.
  public static func create(
    configuration: MetalNumiBrainConfiguration,
    policyPackage: BrainFoundationPolicyPackage,
    evidenceReceipt: BrainFoundationPolicyEvidenceReceipt,
    device requestedDevice: (any MTLDevice)? = nil
  ) throws -> MetalNumiBrainHandle {
    try policyPackage.validateGateCEvidenceManifest()
    try evidenceReceipt.validate(package: policyPackage)
    return try createValidatedPolicyPackage(
      configuration: configuration,
      policyPackage: policyPackage,
      requestedDevice: requestedDevice
    )
  }

  /// Explicit offline/evaluation path for a structurally valid candidate whose
  /// retained Gate C evidence has not yet been verified. This name prevents an
  /// unverified package from silently entering the production admission path.
  public static func createUnverifiedPolicyCandidate(
    configuration: MetalNumiBrainConfiguration,
    policyPackage: BrainFoundationPolicyPackage,
    device requestedDevice: (any MTLDevice)? = nil
  ) throws -> MetalNumiBrainHandle {
    try policyPackage.validate()
    return try createValidatedPolicyPackage(
      configuration: configuration,
      policyPackage: policyPackage,
      requestedDevice: requestedDevice
    )
  }

  private static func createValidatedPolicyPackage(
    configuration: MetalNumiBrainConfiguration,
    policyPackage: BrainFoundationPolicyPackage,
    requestedDevice: (any MTLDevice)?
  ) throws -> MetalNumiBrainHandle {
    let species = configuration.compiledSpeciesTemplate.species
    let regionalProgram = try species.regionalProgram()
    let enabledModalities = species.senses.filter(\.enabled).map(\.modality)
    let planningHorizon = species.development.map(\.planningHorizonSteps).max() ?? 0
    guard policyPackage.architecture.speciesFingerprint == species.fingerprint,
      policyPackage.architecture.runtimeProgramFingerprint
        == regionalProgram.fingerprint,
      policyPackage.architecture.lowLevelControllerFingerprint
        == configuration.compiledSpeciesTemplate.somaticSynergyCatalog.fingerprint,
      policyPackage.architecture.hardSafetyProgramFingerprint
        == configuration.compiledSpeciesTemplate.protectiveMotorProfile.fingerprint,
      policyPackage.architecture.inputModalities
        == enabledModalities.sorted(by: { $0.rawValue < $1.rawValue }),
      policyPackage.architecture.actionGeneration == .autoregressive,
      policyPackage.architecture.actionHorizon == UInt32(planningHorizon)
    else {
      throw TissueError.metal(
        "foundation-policy package does not match the requested Metal runtime"
      )
    }
    return try create(
      configuration: configuration,
      publication: policyPackage.publication(),
      device: requestedDevice
    )
  }
}

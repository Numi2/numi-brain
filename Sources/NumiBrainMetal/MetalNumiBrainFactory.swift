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
  public let sensoryProfile: SensoryTransductionProfile
  public let protectiveMotorProfile: ProtectiveMotorProfile?
  public let muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog?
  public let schedulerEnvironmentIdentifier: UInt32
  public let maximumSchedulerEvents: Int
  public let maximumSchedulerInvocations: Int
  public let maximumEncodedSubsteps: Int

  public init(
    initialTissueState: TissueGrid,
    tissueParameters: TissueParameters,
    tissueStimulus: TissueStimulus,
    sensoryProfile: SensoryTransductionProfile,
    tissueStructure: TissueStructure? = nil,
    tissueDelayField: TissueDelayField? = nil,
    tissueConnectome: TissueConnectome? = nil,
    tissueEventSchedule: TissueEventSchedule? = nil,
    randomContext: TissueRandomContext = .deterministicDefault,
    protectiveMotorProfile: ProtectiveMotorProfile? = nil,
    muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog? = nil,
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
    self.sensoryProfile = sensoryProfile
    self.protectiveMotorProfile = protectiveMotorProfile
    self.muscleAttachmentCatalog = muscleAttachmentCatalog
    self.schedulerEnvironmentIdentifier = schedulerEnvironmentIdentifier
    self.maximumSchedulerEvents = maximumSchedulerEvents
    self.maximumSchedulerInvocations = maximumSchedulerInvocations
    self.maximumEncodedSubsteps = maximumEncodedSubsteps
  }
}

@available(macOS 26.0, *)
extension MetalNumiBrainRuntime {
  /// Creates the authoritative complete runtime from one species graph and one
  /// immutable publication. Omitting the publication creates a content-
  /// addressed foundation generation for the full species graph, never the
  /// reduced scheduler qualification fixture.
  public static func create(
    configuration: MetalNumiBrainConfiguration,
    species: SpeciesTemplate,
    publication requestedPublication: BrainParameterPublication? = nil,
    device requestedDevice: (any MTLDevice)? = nil
  ) throws -> MetalNumiBrainRuntime {
    guard let device = requestedDevice ?? MTLCreateSystemDefaultDevice() else {
      throw TissueError.metal("no Metal device is available")
    }
    let regionalProgram = try species.regionalProgram()
    let publication: BrainParameterPublication
    if let requestedPublication {
      publication = requestedPublication
    } else {
      let version = try BrainParameterVersion.runtimeFoundationV0(
        schedule: species.regionGraph.schedule,
        regionalProgram: regionalProgram,
        tissueParameters: configuration.tissueParameters
      )
      publication = try BrainParameterPublication(
        version: version,
        sharedArtifact: BrainSharedParameterArtifact.foundation(
          parameterVersion: version
        )
      )
    }
    let version = publication.version
    guard configuration.sensoryProfile.speciesTemplateFingerprint
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
    let protectiveProfile = try configuration.protectiveMotorProfile
      ?? ProtectiveMotorProfile.compiled(species: species)
    guard protectiveProfile.channels.count == Int(species.motor.actuatorCount),
      protectiveProfile.channels.map(\.muscleIdentifier)
        == species.motor.actuatorChannels.map(\.identifier)
    else {
      throw TissueError.metal(
        "protective actuator profile does not match the species motor topology"
      )
    }
    let cognitive = try MetalEmbodiedBrainRuntime(
      device: device,
      species: species,
      regionalProgram: regionalProgram,
      parameterVersion: version,
      sharedParameterArtifact: publication.sharedArtifact,
      sensoryProfile: configuration.sensoryProfile
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
      numanXMuscleAttachmentCatalog: configuration.muscleAttachmentCatalog,
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

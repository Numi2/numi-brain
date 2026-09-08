import Foundation
@preconcurrency import Metal
import NumiBrainCore

@available(macOS 26.0, *)
extension MetalNumiBrainHandle {
  /// Restore a decoder-only fork as a new isolated research mind. This never
  /// mutates an existing handle and cannot inherit a trained-policy admission.
  /// The caller restores fork.physicalData through a separate physical owner
  /// before stepping the returned brain. Pass the SAME retained sourceBrainData
  /// to both probes; no assumptions about serialized key ordering are needed.
  public static func createConnectomeDecoderFork(
    from sourceBrainData: Data,
    configuration: MetalNumiBrainConfiguration,
    publication: BrainParameterPublication,
    identifier: String,
    specification: ConnectomeControllerSpec,
    physicalCheckpointFingerprint: UInt64,
    physicalData: Data,
    maximumSnapshotBytes: Int = 536_870_912,
    device requestedDevice: (any MTLDevice)? = nil
  ) throws -> (brain: MetalNumiBrainHandle, fork: MetalConnectomeDecoderFork) {
    guard let previous = configuration.connectome else {
      throw ConnectomeError.invalid("decoder forks require an explicitly configured research connectome controller")
    }
    let body = configuration.compiledSpeciesTemplate
    let parent = try ConnectomeControllerProgram(graph: previous.graph, spec: previous.specification,
      template: body, parameterVersionFingerprint: publication.version.fingerprint)
    let target = try ConnectomeControllerProgram(graph: previous.graph, spec: specification,
      template: body, parameterVersionFingerprint: publication.version.fingerprint)
    let fork = try MetalConnectomeDecoderFork.prepare(identifier: identifier,
      sourceBrainData: sourceBrainData, physicalData: physicalData,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint,
      parent: parent, target: target, template: body, maximumSnapshotBytes: maximumSnapshotBytes)
    guard let device = requestedDevice ?? MTLCreateSystemDefaultDevice() else {
      throw TissueError.metal("no Metal device is available")
    }
    let newConnectome = try MetalConnectomeConfiguration(graph: previous.graph,
      specification: specification, sharedGraph: previous.sharedGraph,
      maximumSubsteps: previous.maximumSubsteps)
    let c = configuration
    let changed = MetalNumiBrainConfiguration(initialTissueState: c.initialTissueState,
      tissueParameters: c.tissueParameters, tissueStimulus: c.tissueStimulus,
      compiledSpeciesTemplate: c.compiledSpeciesTemplate, tissueStructure: c.tissueStructure,
      tissueDelayField: c.tissueDelayField, tissueConnectome: c.tissueConnectome,
      tissueEventSchedule: c.tissueEventSchedule, randomContext: c.randomContext,
      schedulerEnvironmentIdentifier: c.schedulerEnvironmentIdentifier,
      maximumSchedulerEvents: c.maximumSchedulerEvents,
      maximumSchedulerInvocations: c.maximumSchedulerInvocations,
      maximumEncodedSubsteps: c.maximumEncodedSubsteps, connectome: newConnectome)
    let childRuntime = try MetalNumiBrainRuntime.makeRuntime(configuration: changed,
      publication: publication, device: device)
    try childRuntime.loadCheckpoint(fork.checkpoint,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint)
    let child = MetalNumiBrainHandle(runtime: childRuntime, configuration: changed,
      publication: publication, foundationPolicyArchitecture: nil, device: device)
    return (child, fork)
  }
}

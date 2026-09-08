import Foundation
import NumiBrainCore

/// A prepared research fork, not a runtime admission receipt. The source bytes
/// are retained exactly so separately prepared +/- probes can prove identical
/// initialization. No physical state is decoded or rewritten by NumiBrain.
public struct MetalConnectomeDecoderFork: Sendable {
  public let identity: ConnectomeDecoderForkIdentity
  public let sourceBrainData: Data
  public let targetBrainData: Data
  public let physicalData: Data
  public let checkpoint: MetalNumiBrainCheckpoint

  public static func prepare(identifier: String, sourceBrainData: Data,
    physicalData: Data, physicalCheckpointFingerprint: UInt64,
    parent: ConnectomeControllerProgram, target: ConnectomeControllerProgram,
    template: CompiledSpeciesTemplate, maximumSnapshotBytes: Int = 536_870_912) throws -> Self {
    guard maximumSnapshotBytes > 0, !sourceBrainData.isEmpty, !physicalData.isEmpty,
      sourceBrainData.count <= maximumSnapshotBytes,
      physicalData.count <= maximumSnapshotBytes - sourceBrainData.count else {
      throw ConnectomeError.invalid("paired brain/body snapshots exceed the explicit import budget")
    }
    let source = try MetalNumiBrainCheckpoint.decode(sourceBrainData)
    let rebuiltParent = try ConnectomeControllerProgram(graph: parent.graph, spec: parent.spec,
      template: template, parameterVersionFingerprint: source.cognitiveState.parameterVersionFingerprint)
    let rebuiltTarget = try ConnectomeControllerProgram(graph: target.graph, spec: target.spec,
      template: template, parameterVersionFingerprint: source.cognitiveState.parameterVersionFingerprint)
    guard rebuiltParent.binding.fingerprint == parent.binding.fingerprint,
      rebuiltParent.programFingerprint == parent.programFingerprint,
      rebuiltTarget.binding.fingerprint == target.binding.fingerprint,
      rebuiltTarget.programFingerprint == target.programFingerprint else {
      throw ConnectomeError.invalid("fork programs do not belong to the snapshot's exact parameter publication")
    }
    try rebuiltTarget.validateDecoderOnlyChange(from: rebuiltParent)
    let c = source.cognitiveState
    guard let neural = c.connectomeState,
      source.physicalCheckpointFingerprint == physicalCheckpointFingerprint,
      c.speciesTemplateFingerprint == template.species.fingerprint,
      c.compiledSpeciesTemplateFingerprint == template.fingerprint,
      neural.graphFingerprint == parent.graph.fingerprint,
      neural.topologyFingerprint == parent.topologyFingerprint,
      neural.programFingerprint == parent.programFingerprint,
      neural.activity.count == parent.graph.nodeCount * MemoryLayout<Float>.stride else {
      throw ConnectomeError.invalid("source checkpoint is not a complete snapshot of this parent controller and body")
    }
    let changedNeural = try ConnectomeCheckpoint(graphFingerprint: neural.graphFingerprint,
      topologyFingerprint: neural.topologyFingerprint, programFingerprint: target.programFingerprint,
      parameterVersionFingerprint: neural.parameterVersionFingerprint,
      environmentIdentifier: neural.environmentIdentifier, episodeIdentifier: neural.episodeIdentifier,
      generation: neural.generation, timestampMicroseconds: neural.timestampMicroseconds,
      activity: neural.activity)
    let changedCognitive = try MetalBrainCheckpoint(committedGeneration: c.committedGeneration,
      committedTimestamp: c.committedTimestamp, environmentIdentifier: c.environmentIdentifier,
      episodeIdentifier: c.episodeIdentifier, controlStepIdentifier: c.controlStepIdentifier,
      speciesTemplateFingerprint: c.speciesTemplateFingerprint,
      compiledSpeciesTemplateFingerprint: c.compiledSpeciesTemplateFingerprint,
      regionalProgramFingerprint: c.regionalProgramFingerprint, scheduleFingerprint: c.scheduleFingerprint,
      parameterVersionFingerprint: c.parameterVersionFingerprint, hotLayoutFingerprint: c.hotLayoutFingerprint,
      memoryLayoutFingerprint: c.memoryLayoutFingerprint, physicalCheckpointFingerprint: c.physicalCheckpointFingerprint,
      hotState: c.hotState, persistentMemory: c.persistentMemory, connectomeState: changedNeural)
    let checkpoint = try MetalNumiBrainCheckpoint(cognitiveState: changedCognitive,
      fastTissueState: source.fastTissueState)
    let encoded = try checkpoint.encoded()
    guard encoded.count <= maximumSnapshotBytes else {
      throw ConnectomeError.invalid("forked checkpoint exceeds the explicit output budget")
    }
    let identity = try ConnectomeDecoderForkIdentity(identifier: identifier,
      sourceBrainSHA256: BrainPolicyEvidenceArtifact.sha256(sourceBrainData),
      physicalSHA256: BrainPolicyEvidenceArtifact.sha256(physicalData),
      graphSHA256: BrainPolicyEvidenceArtifact.sha256(parent.graph.bytes),
      parentSpecificationSHA256: BrainPolicyEvidenceArtifact.sha256(
        try BrainPolicyEvidenceArtifact.encodeCanonical(parent.spec)),
      targetSpecificationSHA256: BrainPolicyEvidenceArtifact.sha256(
        try BrainPolicyEvidenceArtifact.encodeCanonical(target.spec)),
      targetBrainSHA256: BrainPolicyEvidenceArtifact.sha256(encoded),
      compiledTemplateFingerprint: template.fingerprint,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint,
      parameterVersionFingerprint: c.parameterVersionFingerprint, topologyFingerprint: neural.topologyFingerprint,
      environmentIdentifier: c.environmentIdentifier, episodeIdentifier: c.episodeIdentifier,
      generation: c.committedGeneration, timestampMicroseconds: c.committedTimestamp.rawValue,
      controlStepIdentifier: c.controlStepIdentifier)
    return Self(identity: identity, sourceBrainData: sourceBrainData, targetBrainData: encoded,
      physicalData: physicalData, checkpoint: checkpoint)
  }
}

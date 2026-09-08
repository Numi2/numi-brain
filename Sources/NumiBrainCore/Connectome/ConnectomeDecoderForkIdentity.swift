import Foundation

/// Content provenance for an explicit decoder-only experiment fork. Matching
/// this record is not proof that a physical owner restored or executed a state.
/// Keep the two retained checkpoint byte streams with the experiment artifacts.
public struct ConnectomeDecoderForkIdentity: Codable, Equatable, Sendable {
  public let version: UInt32
  public let promotable: Bool
  public let identifier: String
  public let sourceBrainSHA256: String
  public let physicalSHA256: String
  public let graphSHA256: String
  public let parentSpecificationSHA256: String
  public let targetSpecificationSHA256: String
  public let targetBrainSHA256: String
  public let compiledTemplateFingerprint: UInt64
  public let physicalCheckpointFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  public let topologyFingerprint: UInt64
  public let environmentIdentifier: UInt32
  public let episodeIdentifier: UInt64
  public let generation: UInt64
  public let timestampMicroseconds: UInt64
  public let controlStepIdentifier: UInt64

  public init(identifier: String, sourceBrainSHA256: String, physicalSHA256: String,
    graphSHA256: String, parentSpecificationSHA256: String, targetSpecificationSHA256: String,
    targetBrainSHA256: String, compiledTemplateFingerprint: UInt64,
    physicalCheckpointFingerprint: UInt64, parameterVersionFingerprint: UInt64,
    topologyFingerprint: UInt64, environmentIdentifier: UInt32, episodeIdentifier: UInt64,
    generation: UInt64, timestampMicroseconds: UInt64, controlStepIdentifier: UInt64) throws {
    version = 1; promotable = false; self.identifier = identifier
    self.sourceBrainSHA256 = sourceBrainSHA256; self.physicalSHA256 = physicalSHA256
    self.graphSHA256 = graphSHA256; self.parentSpecificationSHA256 = parentSpecificationSHA256
    self.targetSpecificationSHA256 = targetSpecificationSHA256; self.targetBrainSHA256 = targetBrainSHA256
    self.compiledTemplateFingerprint = compiledTemplateFingerprint
    self.physicalCheckpointFingerprint = physicalCheckpointFingerprint
    self.parameterVersionFingerprint = parameterVersionFingerprint; self.topologyFingerprint = topologyFingerprint
    self.environmentIdentifier = environmentIdentifier; self.episodeIdentifier = episodeIdentifier
    self.generation = generation; self.timestampMicroseconds = timestampMicroseconds
    self.controlStepIdentifier = controlStepIdentifier
    try validate()
  }

  public func validate() throws {
    guard version == 1, !promotable, (1...128).contains(identifier.utf8.count),
      identifier.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0)
        || (97...122).contains($0) || $0 == 45 || $0 == 95 }),
      [sourceBrainSHA256, physicalSHA256, graphSHA256, parentSpecificationSHA256,
        targetSpecificationSHA256, targetBrainSHA256].allSatisfy(BrainPolicyEvidenceArtifact.isSHA256),
      parentSpecificationSHA256 != targetSpecificationSHA256,
      sourceBrainSHA256 != targetBrainSHA256,
      [compiledTemplateFingerprint, physicalCheckpointFingerprint,
        parameterVersionFingerprint, topologyFingerprint].allSatisfy({ $0 != 0 }) else {
      throw ConnectomeError.invalid("decoder fork identity is incomplete or describes an unchanged controller")
    }
  }

  /// Preflight for matched-common-random-number probes. It compares complete
  /// source snapshot bytes, not one initial observation or equal body shapes.
  /// Execution still requires the physical owner's restore and capture checks.
  public func validatePairedInitialization(with other: Self) throws {
    try validate(); try other.validate()
    guard identifier != other.identifier,
      sourceBrainSHA256 == other.sourceBrainSHA256, physicalSHA256 == other.physicalSHA256,
      graphSHA256 == other.graphSHA256, parentSpecificationSHA256 == other.parentSpecificationSHA256,
      targetSpecificationSHA256 != other.targetSpecificationSHA256,
      targetBrainSHA256 != other.targetBrainSHA256,
      compiledTemplateFingerprint == other.compiledTemplateFingerprint,
      physicalCheckpointFingerprint == other.physicalCheckpointFingerprint,
      parameterVersionFingerprint == other.parameterVersionFingerprint,
      topologyFingerprint == other.topologyFingerprint,
      environmentIdentifier == other.environmentIdentifier, episodeIdentifier == other.episodeIdentifier,
      generation == other.generation, timestampMicroseconds == other.timestampMicroseconds,
      controlStepIdentifier == other.controlStepIdentifier else {
      throw ConnectomeError.invalid("decoder probes do not share one complete initial brain/body snapshot")
    }
  }
}

extension ConnectomeControllerProgram {
  /// Shape equality and a 64-bit fingerprint alone are insufficient for an
  /// experimental state fork. Compare the actual graph bytes and every frozen
  /// operator setting, after replacing only the decoder coefficient arrays.
  public func validateDecoderOnlyChange(from parent: Self) throws {
    guard graph.bytes == parent.graph.bytes,
      binding.parameterVersionFingerprint == parent.binding.parameterVersionFingerprint,
      binding.fingerprint == parent.binding.fingerprint,
      topologyFingerprint == parent.topologyFingerprint,
      actuatorCount == parent.actuatorCount, commandKind == parent.commandKind,
      spec == (try parent.spec.replacingDecoderParameters(spec.decoderParameters)),
      spec.decoderParameters != parent.spec.decoderParameters,
      programFingerprint != parent.programFingerprint else {
      throw ConnectomeError.invalid("experiment fork must change only decoder weights/biases under the same neural operator and publication")
    }
  }
}

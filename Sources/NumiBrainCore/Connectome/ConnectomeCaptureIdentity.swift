import Foundation

/// Exact research-controller provenance, not biological or runtime qualification.
/// The graph, specification and compiled body are transitive capture artifacts;
/// a retained decoder file that is not named here is not training evidence.
public struct ConnectomeCaptureIdentity: Codable, Equatable, Sendable {
  public static let datasetIdentifier = "numibrain.connectome.reach-hold.v1"
  public let version: UInt32
  public let graphSHA256: String
  public let specificationSHA256: String
  public let compiledTemplateSHA256: String
  public let graphFingerprint: UInt64
  public let speciesFingerprint: UInt64
  public let sensoryProfileFingerprint: UInt64
  public let compiledTemplateFingerprint: UInt64
  public let topologyFingerprint: UInt64
  public let programFingerprint: UInt64
  public let bindingFingerprint: UInt64
  public let brainProgramFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64

  public var artifactSHA256: [String] { [graphSHA256, specificationSHA256, compiledTemplateSHA256] }

  private init(program: ConnectomeControllerProgram, template: CompiledSpeciesTemplate,
    graphSHA256: String, specificationSHA256: String, compiledTemplateSHA256: String, brainProgramFingerprint: UInt64) {
    version = 1; self.graphSHA256 = graphSHA256; self.specificationSHA256 = specificationSHA256
    self.compiledTemplateSHA256 = compiledTemplateSHA256
    graphFingerprint = program.graph.fingerprint; speciesFingerprint = template.species.fingerprint
    sensoryProfileFingerprint = template.sensoryProfile.fingerprint
    compiledTemplateFingerprint = template.fingerprint; topologyFingerprint = program.topologyFingerprint
    programFingerprint = program.programFingerprint; bindingFingerprint = program.binding.fingerprint
    self.brainProgramFingerprint = brainProgramFingerprint
    parameterVersionFingerprint = program.binding.parameterVersionFingerprint
  }

  public func validate() throws {
    guard version == 1, artifactSHA256.allSatisfy(BrainPolicyEvidenceArtifact.isSHA256),
      [graphFingerprint, speciesFingerprint, sensoryProfileFingerprint, compiledTemplateFingerprint,
       topologyFingerprint, programFingerprint, bindingFingerprint, brainProgramFingerprint, parameterVersionFingerprint]
        .allSatisfy({ $0 != 0 }) else {
      throw ConnectomeError.invalid("incomplete captured graph, decoder or body identity")
    }
  }

  public static func retain(program: ConnectomeControllerProgram, template: CompiledSpeciesTemplate,
    brainProgramFingerprint: UInt64, directory: URL) throws -> Self {
    guard brainProgramFingerprint > 0 else { throw ConnectomeError.invalid("missing owning brain program") }
    let rebuilt = try ConnectomeControllerProgram(graph: program.graph, spec: program.spec,
      template: template, parameterVersionFingerprint: program.binding.parameterVersionFingerprint)
    guard rebuilt.programFingerprint == program.programFingerprint,
      rebuilt.binding.fingerprint == program.binding.fingerprint else {
      throw ConnectomeError.invalid("captured controller does not match its supplied body")
    }
    return Self(program: rebuilt, template: template,
      graphSHA256: try BrainPolicyEvidenceArtifact.write(program.graph.bytes, to: directory),
      specificationSHA256: try BrainReachHoldExperiment.retain(program.spec, directory: directory),
      compiledTemplateSHA256: try BrainReachHoldExperiment.retain(template, directory: directory),
      brainProgramFingerprint: brainProgramFingerprint)
  }

  /// Read all content-addressed bytes and recompile with the owning validators.
  /// Hashes detect changes; they are not signatures of a trusted execution host.
  public func verify(directory: URL, expectedTemplateFingerprint: UInt64,
    parameterVersionFingerprint: UInt64) throws -> ConnectomeControllerProgram {
    try validate()
    guard self.parameterVersionFingerprint == parameterVersionFingerprint,
      compiledTemplateFingerprint == expectedTemplateFingerprint else {
      throw ConnectomeError.invalid("capture controller belongs to another publication or physical body")
    }
    let graph = try ConnectomeGraph(data: BrainPolicyNumanXCaptureVerifier.verifiedData(
      sha256: graphSHA256, directory: directory))
    let spec = try BrainReachHoldExperiment.read(ConnectomeControllerSpec.self,
      hash: specificationSHA256, directory: directory)
    let body = try BrainReachHoldExperiment.read(CompiledSpeciesTemplate.self,
      hash: compiledTemplateSHA256, directory: directory)
    let program = try ConnectomeControllerProgram(graph: graph, spec: spec, template: body,
      parameterVersionFingerprint: parameterVersionFingerprint)
    guard Self(program: program, template: body, graphSHA256: graphSHA256,
      specificationSHA256: specificationSHA256, compiledTemplateSHA256: compiledTemplateSHA256,
      brainProgramFingerprint: brainProgramFingerprint) == self else {
      throw ConnectomeError.invalid("captured graph, projections or decoder failed exact recompilation")
    }
    return program
  }

  public func validate(execution: BrainPolicyNumanXRootExecution) throws {
    try validate(); try execution.validate()
    guard execution.connectomeProgramFingerprint == programFingerprint,
      execution.brainProgramFingerprint == brainProgramFingerprint else {
      throw ConnectomeError.invalid("native execution did not run the captured decoder and brain program")
    }
  }

  /// Legacy Gate C verifiers cannot silently admit a research controller.
  /// Version 3 requires this record even when the JSON is decoded directly.
  public static func requireScope(run: BrainPolicyNumanXCaptureRunArtifact,
    allowingResearch: Bool) throws {
    guard run.datasetSourceIdentifier != datasetIdentifier || run.connectome != nil else {
      throw ConnectomeError.invalid("research capture omitted its controller provenance")
    }
    guard run.connectome == nil || allowingResearch else {
      throw ConnectomeError.invalid("connectome capture requires explicit research evaluation, not legacy policy qualification")
    }
  }
}

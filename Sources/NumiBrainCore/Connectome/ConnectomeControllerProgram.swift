import Foundation
import NumiBrainConnectomeABI

/// Portable, body-specific controller input. Decoding this value confers no
/// runtime authority: compile it against the exact graph and compiled species.
/// The recurrent connectome is frozen; weights are actuator-major readout logits.
public struct ConnectomeControllerSpec: Codable, Sendable {
  public static let currentVersion: UInt32 = 1
  public let version: UInt32
  public let graphFingerprint: UInt64
  public let speciesFingerprint: UInt64
  public let sensoryProfileFingerprint: UInt64
  public let nominalStepMicroseconds: UInt32
  public let integrationStepMicroseconds: UInt32
  public let channelCount: UInt32
  public let receptors: [ConnectomeReceptorProjection]
  public let descending: [ConnectomeDescendingProjection]
  public let decoderWeights: [Float]
  public let decoderBiases: [Float]
  public let maximumLogit: Float

  public init(graphFingerprint: UInt64, speciesFingerprint: UInt64,
    sensoryProfileFingerprint: UInt64, nominalStepMicroseconds: UInt32,
    integrationStepMicroseconds: UInt32, channelCount: UInt32,
    receptors: [ConnectomeReceptorProjection], descending: [ConnectomeDescendingProjection],
    decoderWeights: [Float], decoderBiases: [Float], maximumLogit: Float = 8) {
    version = Self.currentVersion; self.graphFingerprint = graphFingerprint
    self.speciesFingerprint = speciesFingerprint
    self.sensoryProfileFingerprint = sensoryProfileFingerprint
    self.nominalStepMicroseconds = nominalStepMicroseconds
    self.integrationStepMicroseconds = integrationStepMicroseconds
    self.channelCount = channelCount; self.receptors = receptors; self.descending = descending
    self.decoderWeights = decoderWeights; self.decoderBiases = decoderBiases
    self.maximumLogit = maximumLogit
  }

  public static func read(from url: URL, maximumBytes: Int = 33_554_432) throws -> Self {
    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
    guard let size, size > 0, size <= maximumBytes else {
      throw ConnectomeError.invalid("controller specification exceeds its byte budget")
    }
    let data = try Data(contentsOf: url)
    guard data.count <= maximumBytes else { throw ConnectomeError.invalid("controller file grew during read") }
    return try JSONDecoder().decode(Self.self, from: data)
  }
}

/// Validated neural dynamics, sensor projection, and robot decoder identity.
/// Binding fingerprints include the live rollout version. programFingerprint
/// excludes that version but includes every operator, timestep, receptor and
/// actuator mapping, so checkpoint migration cannot silently replace a decoder.
public struct ConnectomeControllerProgram: Sendable {
  public let graph: ConnectomeGraph
  public let spec: ConnectomeControllerSpec
  public let binding: ConnectomeBinding
  public let topologyFingerprint: UInt64
  public let programFingerprint: UInt64
  public let actuatorCount: UInt32
  public let commandKind: ActuatorCommandKind

  public init(graph: ConnectomeGraph, spec: ConnectomeControllerSpec,
    template: CompiledSpeciesTemplate, parameterVersionFingerprint: UInt64) throws {
    guard spec.version == ConnectomeControllerSpec.currentVersion,
      spec.graphFingerprint == graph.fingerprint,
      spec.speciesFingerprint == template.species.fingerprint,
      spec.sensoryProfileFingerprint == template.sensoryProfile.fingerprint,
      spec.decoderWeights.count <= 1_048_576, spec.decoderBiases.count <= 4096 else {
      throw ConnectomeError.invalid("controller specification is foreign, unsupported or oversized")
    }
    let binding = try ConnectomeBinding(graph: graph, template: template,
      parameterVersionFingerprint: parameterVersionFingerprint, channelCount: spec.channelCount,
      nominalStepMicroseconds: spec.nominalStepMicroseconds,
      integrationStepMicroseconds: spec.integrationStepMicroseconds,
      receptors: spec.receptors, descending: spec.descending)
    let topology = try ConnectomeBinding(graph: graph,
      speciesFingerprint: binding.speciesFingerprint,
      sensoryProfileFingerprint: binding.sensoryProfileFingerprint,
      parameterVersionFingerprint: 1, scalarCount: binding.scalarCount,
      receptorCount: binding.receptorCount, channelCount: binding.channelCount,
      nominalStepMicroseconds: binding.nominalStepMicroseconds,
      integrationStepMicroseconds: binding.integrationStepMicroseconds,
      inputs: binding.inputs, readouts: binding.readouts).fingerprint
    let motor = template.species.motor
    let fingerprint = spec.decoderWeights.withUnsafeBufferPointer { weights in
      spec.decoderBiases.withUnsafeBufferPointer { biases in
        nb_connectome_decoder_fingerprint(graph.fingerprint, topology,
          template.species.fingerprint, UInt32(motor.actuatorCommandKind.rawValue),
          binding.channelCount, motor.actuatorCount, weights.baseAddress, UInt32(weights.count),
          biases.baseAddress, UInt32(biases.count), spec.maximumLogit)
      }
    }
    guard fingerprint != 0 else { throw ConnectomeError.invalid("invalid decoder shape or numerical values") }
    self.graph = graph; self.spec = spec; self.binding = binding
    topologyFingerprint = topology; programFingerprint = fingerprint
    actuatorCount = motor.actuatorCount; commandKind = motor.actuatorCommandKind
  }
}

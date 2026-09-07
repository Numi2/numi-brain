import Foundation
import NumiBrainConnectomeABI

/// Versioned, reviewed robot-specific decoder. Inputs are descending neural
/// features, outputs are logits in the EXISTING normalized motor-drive domain.
/// The normal spinal, inhibition and physical actuator adapters remain active.
public struct ConnectomeMotorDecoder: Codable, Equatable, Sendable {
  public let version: UInt32
  public let bindingFingerprint: UInt64
  public let compiledSpeciesFingerprint: UInt64
  public let channelCount: UInt32
  public let actuatorCount: UInt32
  public let commandKind: UInt32
  public let maximumDriveChangePerSecond: Float
  public let weights: [Float]
  public let bias: [Float]
  public let fingerprint: UInt64

  public init(binding: ConnectomeBinding, template: CompiledSpeciesTemplate,
    weights: [Float], bias: [Float], maximumDriveChangePerSecond: Float) throws {
    guard template.species.fingerprint == binding.speciesFingerprint,
      template.sensoryProfile.fingerprint == binding.sensoryProfileFingerprint else {
      throw ConnectomeError.invalid("decoder binding belongs to a different body")
    }
    try self.init(bindingFingerprint: binding.fingerprint,
      compiledSpeciesFingerprint: template.fingerprint,
      channelCount: binding.channelCount, actuatorCount: template.species.motor.actuatorCount,
      commandKind: UInt32(template.species.motor.actuatorCommandKind.rawValue),
      maximumDriveChangePerSecond: maximumDriveChangePerSecond, weights: weights, bias: bias)
  }

  // Internal numeric constructor is also used by the off-rollout learner.
  init(bindingFingerprint: UInt64, compiledSpeciesFingerprint: UInt64,
    channelCount: UInt32, actuatorCount: UInt32, commandKind: UInt32,
    maximumDriveChangePerSecond: Float, weights: [Float], bias: [Float]) throws {
    guard channelCount > 0, channelCount <= 256, actuatorCount > 0, actuatorCount <= 4096,
      weights.count == Int(channelCount)*Int(actuatorCount), bias.count == Int(actuatorCount) else {
      throw ConnectomeError.invalid("decoder shape/capacity mismatch")
    }
    let hash = weights.withUnsafeBufferPointer { w in bias.withUnsafeBufferPointer { b in
      nb_connectome_decoder_fingerprint(bindingFingerprint, compiledSpeciesFingerprint,
        channelCount, actuatorCount, commandKind, maximumDriveChangePerSecond, w.baseAddress, b.baseAddress)
    }}
    guard hash > 0 else { throw ConnectomeError.invalid("decoder values or immutable identity are invalid") }
    version = 1; self.bindingFingerprint = bindingFingerprint
    self.compiledSpeciesFingerprint = compiledSpeciesFingerprint
    self.channelCount = channelCount; self.actuatorCount = actuatorCount
    self.commandKind = commandKind; self.maximumDriveChangePerSecond = maximumDriveChangePerSecond
    self.weights = weights; self.bias = bias; fingerprint = hash
  }

  public func validated() throws -> Self {
    let canonical = try Self(bindingFingerprint: bindingFingerprint,
      compiledSpeciesFingerprint: compiledSpeciesFingerprint,
      channelCount: channelCount, actuatorCount: actuatorCount, commandKind: commandKind,
      maximumDriveChangePerSecond: maximumDriveChangePerSecond, weights: weights, bias: bias)
    guard self == canonical else { throw ConnectomeError.invalid("decoder version/fingerprint drift") }
    return canonical
  }
}

/// Exact, immutable module. A changed graph, mapping, decoder or neural time
/// discretization changes the hot-layout identity, so checkpoint/recovery and
/// NumanX program admission cannot confuse equally shaped controllers.
public struct ConnectomeProgram: Sendable {
  public let graph: ConnectomeGraph
  public let binding: ConnectomeBinding
  public let decoder: ConnectomeMotorDecoder
  public let maximumSubsteps: Int
  public let fingerprint: UInt64

  public init(graph: ConnectomeGraph, binding: ConnectomeBinding,
    decoder: ConnectomeMotorDecoder, maximumSubsteps: Int = 256) throws {
    let decoder = try decoder.validated()
    guard graph.fingerprint == binding.graphFingerprint,
      decoder.bindingFingerprint == binding.fingerprint,
      decoder.channelCount == binding.channelCount,
      (1...4096).contains(maximumSubsteps) else {
      throw ConnectomeError.invalid("program components do not share one identity")
    }
    self.graph = graph; self.binding = binding; self.decoder = decoder
    self.maximumSubsteps = maximumSubsteps
    var words: [UInt64] = [0x4e42435052470001, graph.fingerprint,
      binding.fingerprint, decoder.fingerprint, UInt64(maximumSubsteps)]
    words = words.map(\.littleEndian)
    fingerprint = words.withUnsafeBytes {
      nb_connectome_fnv1a_update(14_695_981_039_346_656_037, $0.baseAddress, $0.count)
    }
  }

  public func validate(template: CompiledSpeciesTemplate,
    parameterVersionFingerprint: UInt64) throws {
    guard binding.speciesFingerprint == template.species.fingerprint,
      binding.sensoryProfileFingerprint == template.sensoryProfile.fingerprint,
      binding.parameterVersionFingerprint == parameterVersionFingerprint,
      decoder.compiledSpeciesFingerprint == template.fingerprint,
      decoder.actuatorCount == template.species.motor.actuatorCount,
      decoder.commandKind == UInt32(template.species.motor.actuatorCommandKind.rawValue) else {
      throw ConnectomeError.invalid("connectome program cannot be rebound to a different robot/publication")
    }
    var scalarBase: UInt64 = 0, receptorBase: UInt64 = 0
    let senses = template.species.senses.filter(\.enabled).sorted { $0.modality.rawValue < $1.modality.rawValue }
    for sense in senses {
      let end = scalarBase + UInt64(sense.receptorCount)*UInt64(sense.observationDimension)
      guard end <= UInt64(UInt32.max) else { throw ConnectomeError.invalid("sensor indexing capacity") }
      for input in binding.inputs where UInt64(input.scalar) >= scalarBase && UInt64(input.scalar) < end {
        guard UInt64(input.receptor) == receptorBase + (UInt64(input.scalar)-scalarBase)/UInt64(sense.observationDimension) else {
          throw ConnectomeError.invalid("flat projection has an inconsistent receptor/feature identity")
        }
      }
      scalarBase = end; receptorBase += UInt64(sense.receptorCount)
    }
    guard scalarBase == UInt64(binding.scalarCount), receptorBase == UInt64(binding.receptorCount) else {
      throw ConnectomeError.invalid("compiled sensor layout does not match the projection")
    }
  }
}

/// Portable launch artifact; the graph remains an external, content-verified
/// file, not an embedded multi-hundred-megabyte JSON value. Loading recompiles
/// all semantic bindings and rejects stale fingerprints and extra dimensions.
public struct ConnectomeLaunch: Codable, Sendable {
  public let version: UInt32
  public let graphFingerprint: UInt64
  public let compiledSpeciesFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  public let nominalStepMicroseconds: UInt32
  public let integrationStepMicroseconds: UInt32
  public let maximumSubsteps: Int
  public let receptors: [ConnectomeReceptorProjection]
  public let descending: [ConnectomeDescendingProjection]
  public let decoder: ConnectomeMotorDecoder

  public init(graph: ConnectomeGraph, template: CompiledSpeciesTemplate,
    parameterVersionFingerprint: UInt64, nominalStepMicroseconds: UInt32,
    integrationStepMicroseconds: UInt32, maximumSubsteps: Int = 256,
    receptors: [ConnectomeReceptorProjection], descending: [ConnectomeDescendingProjection],
    decoder: ConnectomeMotorDecoder) throws {
    version = 1; graphFingerprint = graph.fingerprint; compiledSpeciesFingerprint = template.fingerprint
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.nominalStepMicroseconds = nominalStepMicroseconds; self.integrationStepMicroseconds = integrationStepMicroseconds
    self.maximumSubsteps = maximumSubsteps; self.receptors = receptors; self.descending = descending; self.decoder = decoder
    _ = try compile(graph: graph, template: template, parameterVersionFingerprint: parameterVersionFingerprint)
  }

  public func compile(graph: ConnectomeGraph, template: CompiledSpeciesTemplate,
    parameterVersionFingerprint expected: UInt64) throws -> ConnectomeProgram {
    guard version == 1, graphFingerprint == graph.fingerprint,
      compiledSpeciesFingerprint == template.fingerprint, parameterVersionFingerprint == expected else {
      throw ConnectomeError.invalid("launch artifact names a different graph, body or publication")
    }
    let binding = try ConnectomeBinding(graph: graph, template: template,
      parameterVersionFingerprint: expected, channelCount: decoder.channelCount,
      nominalStepMicroseconds: nominalStepMicroseconds, integrationStepMicroseconds: integrationStepMicroseconds,
      receptors: receptors, descending: descending)
    let program = try ConnectomeProgram(graph: graph, binding: binding, decoder: decoder, maximumSubsteps: maximumSubsteps)
    try program.validate(template: template, parameterVersionFingerprint: expected)
    return program
  }
}

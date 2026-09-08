import Foundation
import NumiBrainConnectomeABI

public struct ConnectomeReceptorProjection: Codable, Equatable, Sendable {
  public let neuronIdentifier: UInt64
  public let modality: SensoryModality
  public let receptorIndex: UInt32
  public let featureIndex: UInt32
  public let weight: Float
  public let scale: Float
  public let bias: Float
  public let clip: Float
  public init(neuronIdentifier: UInt64, modality: SensoryModality,
    receptorIndex: UInt32, featureIndex: UInt32, weight: Float = 1,
    scale: Float = 1, bias: Float = 0, clip: Float = 8) {
    self.neuronIdentifier = neuronIdentifier; self.modality = modality
    self.receptorIndex = receptorIndex; self.featureIndex = featureIndex
    self.weight = weight; self.scale = scale; self.bias = bias; self.clip = clip
  }
}
public struct ConnectomeDescendingProjection: Codable, Equatable, Sendable {
  public let neuronIdentifier: UInt64
  public let channel: UInt32
  public let weight: Float
  public init(neuronIdentifier: UInt64, channel: UInt32, weight: Float = 1) {
    self.neuronIdentifier = neuronIdentifier; self.channel = channel; self.weight = weight
  }
}

extension ConnectomeBinding {
  /// Compiles against the same modality-major, receptor-major layout used by
  /// MetalSensoryTransductionRuntime. This maps receptor measurements, never
  /// teacher state or arbitrary TaskProgram observation offsets.
  public init(graph: ConnectomeGraph, template: CompiledSpeciesTemplate,
    parameterVersionFingerprint: UInt64, channelCount: UInt32,
    nominalStepMicroseconds: UInt32, integrationStepMicroseconds: UInt32,
    receptors: [ConnectomeReceptorProjection], descending: [ConnectomeDescendingProjection]) throws {
    var layout: [SensoryModality: (UInt64, UInt64, SensoryTopology)] = [:]
    var scalars: UInt64 = 0, validity: UInt64 = 0
    for sense in template.species.senses.sorted(by: { $0.modality.rawValue < $1.modality.rawValue }) where sense.enabled {
      let count = UInt64(sense.receptorCount) * UInt64(sense.observationDimension)
      guard count <= UInt64(UInt32.max), scalars <= UInt64(UInt32.max)-count,
        validity <= UInt64(UInt32.max)-UInt64(sense.receptorCount) else {
        throw ConnectomeError.invalid("receptor layout exceeds native index capacity")
      }
      layout[sense.modality] = (scalars, validity, sense)
      scalars += count; validity += UInt64(sense.receptorCount)
    }
    var indices: [UInt64: UInt32] = [:]
    indices.reserveCapacity(graph.nodeCount)
    for i in 0..<graph.nodeCount {
      let node = try graph.node(at: i)
      indices[UInt64(node.identity_low) | UInt64(node.identity_high)<<32] = UInt32(i)
    }
    let inputs = try receptors.map { p -> NBConnectomeInput in
      guard let index = indices[p.neuronIdentifier], let (base, validBase, sense) = layout[p.modality],
        p.receptorIndex < sense.receptorCount, p.featureIndex < sense.observationDimension else {
        throw ConnectomeError.invalid("receptor projection does not resolve in this graph and body")
      }
      return NBConnectomeInput(node: index,
        scalar: UInt32(base + UInt64(p.receptorIndex)*UInt64(sense.observationDimension) + UInt64(p.featureIndex)),
        receptor: UInt32(validBase + UInt64(p.receptorIndex)), reserved: 0,
        weight: p.weight, scale: p.scale, bias: p.bias, clip: p.clip)
    }
    let outputs = try descending.map { p -> NBConnectomeReadout in
      guard let index = indices[p.neuronIdentifier] else {
        throw ConnectomeError.invalid("descending neuron is absent from this graph")
      }
      return NBConnectomeReadout(node: index, channel: p.channel, weight: p.weight, reserved: 0)
    }
    try self.init(graph: graph, speciesFingerprint: template.species.fingerprint,
      sensoryProfileFingerprint: template.sensoryProfile.fingerprint,
      parameterVersionFingerprint: parameterVersionFingerprint,
      scalarCount: UInt32(scalars), receptorCount: UInt32(validity), channelCount: channelCount,
      nominalStepMicroseconds: nominalStepMicroseconds, integrationStepMicroseconds: integrationStepMicroseconds,
      inputs: inputs, readouts: outputs)
  }
}

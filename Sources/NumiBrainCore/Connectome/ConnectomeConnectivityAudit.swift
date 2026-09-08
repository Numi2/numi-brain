import Foundation
import NumiBrainConnectomeABI

/// Structural influence paths under this exact rate-model graph and binding.
/// A path is necessary, not sufficient, for useful sensor-dependent behavior.
/// Opposing readouts can cancel and neural activity can saturate; neither is
/// established by a graph traversal. Distances are recurrent hops, not seconds.
public struct ConnectomeConnectivityAudit: Codable, Equatable, Sendable {
  public let version: UInt32
  public let graphFingerprint: String
  public let bindingFingerprint: String
  public let effectiveEdges: UInt32
  public let activeInputs: UInt32
  public let activeReadouts: UInt32
  public let reachableNodes: UInt32
  public let usefulInputs: UInt32
  public let reachableReadouts: UInt32
  public let reachableChannels: UInt32
  public let scratchBytes: UInt64
  public let inputHopsToReadout: [UInt32?]
  public let readoutHopsFromInput: [UInt32?]
  public let channelHopsFromInput: [UInt32?]
  public var allChannelsReachable: Bool {
    !channelHopsFromInput.isEmpty && channelHopsFromInput.allSatisfy { $0 != nil }
  }
  public var disconnectedChannels: [Int] {
    channelHopsFromInput.indices.filter { channelHopsFromInput[$0] == nil }
  }
  public func requireAllChannelsReachable() throws {
    guard allChannelsReachable else {
      throw ConnectomeError.invalid("no active sensor path to descending channels \(disconnectedChannels)")
    }
  }

  public init(graph: ConnectomeGraph, binding: ConnectomeBinding,
    maximumScratchBytes: Int = 268_435_456) throws {
    guard graph.fingerprint == binding.graphFingerprint, maximumScratchBytes > 0 else {
      throw ConnectomeError.invalid("connectivity audit graph identity or memory budget is invalid")
    }
    var summary = NBConnectomeAuditSummary()
    var inputs = Array(repeating: UInt32.max, count: binding.inputs.count)
    var readouts = Array(repeating: UInt32.max, count: binding.readouts.count)
    var channels = Array(repeating: UInt32.max, count: Int(binding.channelCount))
    let status = graph.bytes.withUnsafeBytes { bytes in
      binding.inputs.withUnsafeBufferPointer { projected in
        binding.readouts.withUnsafeBufferPointer { selected in
          inputs.withUnsafeMutableBufferPointer { ins in
            readouts.withUnsafeMutableBufferPointer { outs in
              channels.withUnsafeMutableBufferPointer { ch in
                nb_connectome_audit(bytes.baseAddress, bytes.count, UInt64(bytes.count),
                  UInt64(maximumScratchBytes), projected.baseAddress, UInt32(projected.count),
                  selected.baseAddress, UInt32(selected.count), binding.channelCount,
                  ins.baseAddress, outs.baseAddress, ch.baseAddress, &summary)
              }
            }
          }
        }
      }
    }
    guard status == 0 else {
      throw ConnectomeError.invalid("native connectivity audit failed (status \(status)); graph, projections or scratch budget rejected")
    }
    version = 1
    graphFingerprint = String(format: "%016llx", graph.fingerprint)
    bindingFingerprint = String(format: "%016llx", binding.fingerprint)
    effectiveEdges = summary.effective_edges; activeInputs = summary.active_inputs
    activeReadouts = summary.active_readouts; reachableNodes = summary.reachable_nodes
    usefulInputs = summary.useful_inputs; reachableReadouts = summary.reachable_readouts
    reachableChannels = summary.reachable_channels; scratchBytes = summary.scratch_bytes
    inputHopsToReadout = inputs.map { $0 == UInt32.max ? nil : $0 }
    readoutHopsFromInput = readouts.map { $0 == UInt32.max ? nil : $0 }
    channelHopsFromInput = channels.map { $0 == UInt32.max ? nil : $0 }
  }
}

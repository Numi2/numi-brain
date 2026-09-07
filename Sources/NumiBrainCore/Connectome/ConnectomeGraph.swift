import Foundation
import NumiBrainConnectomeABI
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public enum ConnectomeError: Error, CustomStringConvertible {
  case invalid(String)
  public var description: String {
    switch self { case .invalid(let message): return "connectome: \(message)" }
  }
}

/// Immutable, validated NUMICNS1 interchange. A type-level graph is a reduced
/// model, not an individual-neuron reconstruction. No implicit tissue-grid
/// adjacency is added to either graph resolution.
public struct ConnectomeGraph: Sendable {
  public let bytes: Data
  public let view: NBConnectomeGraphView
  public var nodeCount: Int { Int(view.node_count) }
  public var edgeCount: Int { Int(view.edge_count) }
  public var fingerprint: UInt64 { view.fingerprint }
  public var isPopulationGraph: Bool { view.resolution == 1 }
  public let manifestJSON: String

  public init(data: Data, maximumBytes: Int = 1_073_741_824) throws {
    guard maximumBytes >= 256, data.count >= 256, data.count <= maximumBytes else {
      throw ConnectomeError.invalid("graph exceeds its byte budget")
    }
    let data = data.withUnsafeBytes { Data(bytes: $0.baseAddress!, count: $0.count) }
    var decoded = NBConnectomeGraphView()
    let status = data.withUnsafeBytes {
      nb_connectome_validate($0.baseAddress, $0.count, UInt64(maximumBytes), &decoded)
    }
    guard status == 0 else {
      throw ConnectomeError.invalid(String(cString: nb_connectome_status_message(status)))
    }
    let manifestData = data.subdata(in: Int(decoded.manifest_offset)..<Int(decoded.manifest_offset + decoded.manifest_bytes))
    guard let manifest = String(data: manifestData, encoding: .utf8),
      (try? JSONSerialization.jsonObject(with: manifestData)) is [String: Any] else {
      throw ConnectomeError.invalid("manifest must be a UTF-8 JSON object")
    }
    self.bytes = data; self.view = decoded; self.manifestJSON = manifest
    // Validate text once at import, never in the neural hot path.
    for i in 0..<nodeCount { _ = try label(at: i) }
  }

  public init(contentsOf url: URL, maximumBytes: Int = 1_073_741_824) throws {
    guard url.isFileURL, maximumBytes >= 256 else {
      throw ConnectomeError.invalid("graph input must be a bounded local file")
    }
    let fd = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
    guard fd >= 0 else { throw ConnectomeError.invalid("graph file is missing or unsafe") }
    let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? handle.close() }
    var info = stat()
    guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
      info.st_size >= 256, info.st_size <= maximumBytes else {
      throw ConnectomeError.invalid("graph input is not a bounded regular file")
    }
    var data = Data(); data.reserveCapacity(Int(info.st_size))
    while let part = try handle.read(upToCount: min(1_048_576, maximumBytes-data.count+1)), !part.isEmpty {
      guard part.count <= maximumBytes-data.count else {
        throw ConnectomeError.invalid("graph grew beyond its byte budget")
      }
      data.append(part)
    }
    try self.init(data: data, maximumBytes: maximumBytes)
  }

  public func node(at index: Int) throws -> NBConnectomeNode {
    guard (0..<nodeCount).contains(index) else { throw ConnectomeError.invalid("node index out of range") }
    return bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: Int(view.nodes_offset) + index * 48, as: NBConnectomeNode.self) }
  }
  public func label(at index: Int) throws -> String {
    guard (0..<nodeCount).contains(index) else { throw ConnectomeError.invalid("label index out of range") }
    let table = Int(view.labels_offset)
    let a: UInt32 = bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: table + index*4, as: UInt32.self) }
    let z: UInt32 = bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: table + (index+1)*4, as: UInt32.self) }
    let blob = table + (nodeCount+1)*4
    guard let text = String(data: bytes.subdata(in: blob+Int(a)..<blob+Int(z)), encoding: .utf8) else {
      throw ConnectomeError.invalid("node label is not UTF-8")
    }
    return text
  }
  public func index(of identifier: UInt64) throws -> Int {
    for i in 0..<nodeCount {
      let id: UInt64 = bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: Int(view.node_ids_offset)+i*8, as: UInt64.self) }
      if id == identifier { return i }
    }
    throw ConnectomeError.invalid("source neuron identifier is absent from this graph")
  }
}

/// Compiled receptor/readout projection. Identical graph bytes can be shared
/// across robots; each exact body/sensor/parameter publication needs its own
/// binding. Native bindings deliberately do not accept wildcard fingerprints.
public struct ConnectomeBinding: Sendable {
  public let graphFingerprint: UInt64
  public let speciesFingerprint: UInt64
  public let sensoryProfileFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  public let fingerprint: UInt64
  public let scalarCount: UInt32
  public let receptorCount: UInt32
  public let channelCount: UInt32
  public let nominalStepMicroseconds: UInt32
  public let integrationStepMicroseconds: UInt32
  public let inputs: [NBConnectomeInput]
  public let readouts: [NBConnectomeReadout]
  public let inputOffsets: [UInt32]
  public let readoutOffsets: [UInt32]

  public init(graph: ConnectomeGraph, speciesFingerprint: UInt64,
    sensoryProfileFingerprint: UInt64, parameterVersionFingerprint: UInt64,
    scalarCount: UInt32, receptorCount: UInt32, channelCount: UInt32,
    nominalStepMicroseconds: UInt32, integrationStepMicroseconds: UInt32,
    inputs requestedInputs: [NBConnectomeInput], readouts requestedReadouts: [NBConnectomeReadout]) throws {
    guard requestedInputs.count <= 65_536, requestedReadouts.count <= 65_536 else {
      throw ConnectomeError.invalid("projection capacity exceeded")
    }
    let inputs = requestedInputs.enumerated().sorted {
      $0.element.node != $1.element.node ? $0.element.node < $1.element.node : $0.offset < $1.offset
    }.map(\.element)
    let outputs = requestedReadouts.enumerated().sorted {
      $0.element.channel != $1.element.channel ? $0.element.channel < $1.element.channel : $0.offset < $1.offset
    }.map(\.element)
    let fp = inputs.withUnsafeBufferPointer { ins in outputs.withUnsafeBufferPointer { outs in
      nb_connectome_binding_fingerprint(graph.fingerprint, speciesFingerprint,
        sensoryProfileFingerprint, parameterVersionFingerprint, UInt32(graph.nodeCount),
        scalarCount, receptorCount, channelCount, nominalStepMicroseconds, integrationStepMicroseconds,
        ins.baseAddress, UInt32(ins.count), outs.baseAddress, UInt32(outs.count))
    }}
    guard fp != 0 else { throw ConnectomeError.invalid("invalid projection shape, value or identity") }
    var inputKeys = Set<UInt64>(), outputKeys = Set<UInt64>()
    for x in inputs {
      guard try graph.node(at: Int(x.node)).flags & 17 != 0,
        inputKeys.insert(UInt64(x.node)<<32 | UInt64(x.scalar)).inserted else {
        throw ConnectomeError.invalid("input must uniquely target an annotated sensory/ascending node")
      }
    }
    for x in outputs {
      guard try graph.node(at: Int(x.node)).flags & 10 != 0,
        outputKeys.insert(UInt64(x.channel)<<32 | UInt64(x.node)).inserted else {
        throw ConnectomeError.invalid("readout must uniquely select an annotated motor/descending node")
      }
    }
    var io = Array(repeating: UInt32(0), count: graph.nodeCount+1)
    var oo = Array(repeating: UInt32(0), count: Int(channelCount)+1)
    for x in inputs { io[Int(x.node)+1] += 1 }
    for x in outputs { oo[Int(x.channel)+1] += 1 }
    for i in 1..<io.count { io[i] += io[i-1] }
    for i in 1..<oo.count { oo[i] += oo[i-1] }
    graphFingerprint = graph.fingerprint; self.speciesFingerprint = speciesFingerprint
    self.sensoryProfileFingerprint = sensoryProfileFingerprint
    self.parameterVersionFingerprint = parameterVersionFingerprint; fingerprint = fp
    self.scalarCount = scalarCount; self.receptorCount = receptorCount; self.channelCount = channelCount
    self.nominalStepMicroseconds = nominalStepMicroseconds
    self.integrationStepMicroseconds = integrationStepMicroseconds
    self.inputs = inputs; readouts = outputs; inputOffsets = io; readoutOffsets = oo
  }
}

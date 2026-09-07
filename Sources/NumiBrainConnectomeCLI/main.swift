import Foundation
import NumiBrainCore

do {
  let args = Array(CommandLine.arguments.dropFirst())
  guard args.count == 2, args[0] == "inspect" else {
    throw ConnectomeError.invalid("usage: numi-brain-connectome inspect GRAPH.numicns")
  }
  let graph = try ConnectomeGraph(contentsOf: URL(fileURLWithPath: args[1]))
  let result: [String: Any] = [
    "format": "NUMICNS1", "nodes": graph.nodeCount, "edges": graph.edgeCount,
    "resolution": graph.isPopulationGraph ? "population" : "neuron",
    "graphFingerprint": String(format: "%016llx", graph.fingerprint),
    "sourceFingerprint": String(format: "%016llx", graph.view.source_fingerprint),
    "bytes": graph.bytes.count,
    "manifest": try JSONSerialization.jsonObject(with: Data(graph.manifestJSON.utf8)),
    "runtimeQualification": "not established by pack inspection"
  ]
  let json = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
  FileHandle.standardOutput.write(json); FileHandle.standardOutput.write(Data([10]))
} catch {
  FileHandle.standardError.write(Data("\(error)\n".utf8)); exit(1)
}

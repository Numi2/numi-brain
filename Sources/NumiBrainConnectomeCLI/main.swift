import Foundation
import NumiBrainCore

do {
  let args = Array(CommandLine.arguments.dropFirst())
  guard let command = args.first else { throw ConnectomeError.invalid("missing command") }
  let result: [String: Any]
  if command == "inspect", args.count == 2 {
    let graph = try ConnectomeGraph(contentsOf: URL(fileURLWithPath: args[1]))
    result = ["format": "NUMICNS1", "nodes": graph.nodeCount, "edges": graph.edgeCount,
      "resolution": graph.isPopulationGraph ? "population" : "neuron",
      "graphFingerprint": String(format: "%016llx", graph.fingerprint),
      "sourceFingerprint": String(format: "%016llx", graph.view.source_fingerprint),
      "bytes": graph.bytes.count,
      "manifest": try JSONSerialization.jsonObject(with: Data(graph.manifestJSON.utf8)),
      "runtimeQualification": "not established by inspection"]
  } else if (command == "validate-controller" || command == "audit-controller"), args.count == 5 {
    let graph = try ConnectomeGraph(contentsOf: URL(fileURLWithPath: args[1]))
    let spec = try ConnectomeControllerSpec.read(from: URL(fileURLWithPath: args[2]))
    let bodyURL = URL(fileURLWithPath: args[3])
    guard let bytes = try bodyURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
      bytes > 0, bytes <= 33_554_432,
      let version = UInt64(args[4], radix: 16), version != 0 else {
      throw ConnectomeError.invalid("invalid body size or hexadecimal parameter fingerprint")
    }
    let template = try JSONDecoder().decode(CompiledSpeciesTemplate.self, from: Data(contentsOf: bodyURL))
    let program = try ConnectomeControllerProgram(graph: graph, spec: spec,
      template: template, parameterVersionFingerprint: version)
    let audit = try ConnectomeConnectivityAudit(graph: program.graph, binding: program.binding)
    let undrivenActuators = (0..<Int(program.actuatorCount)).filter { actuator in
      !(0..<Int(program.binding.channelCount)).contains { channel in
        audit.channelHopsFromInput[channel] != nil &&
          spec.decoderWeights[actuator * Int(program.binding.channelCount) + channel] != 0
      }
    }
    if command == "audit-controller" {
      try audit.requireAllChannelsReachable()
      guard undrivenActuators.isEmpty else {
        throw ConnectomeError.invalid("decoder has no sensory path to actuator rows \(undrivenActuators)")
      }
    }
    let auditJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(audit))
    result = ["connectivity": auditJSON, "undrivenActuators": undrivenActuators, "allChannelsReachable": audit.allChannelsReachable, "programFingerprint": String(format: "%016llx", program.programFingerprint),
      "bindingFingerprint": String(format: "%016llx", program.binding.fingerprint),
      "actuators": program.actuatorCount, "channels": program.binding.channelCount,
      "qualification": "unqualified; structural validation only"]
  } else if command == "import-numilab-topology", args.count == 5 {
    let url = URL(fileURLWithPath: args[1])
    guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
      size > 0, size <= 16_777_216,
      let model = UInt64(args[4], radix: 16), model != 0 else {
      throw ConnectomeError.invalid("invalid robot import size or physical-owner model fingerprint")
    }
    let imported = try NumiLabRobotInterface(data: Data(contentsOf: url),
      expectedSHA256: args[2], expectedNativeRevision: args[3])
    let topology = try imported.jointTopologyCatalog(numanXModelFingerprint: model)
    result = ["robotID": imported.robotID, "sourceSHA256": imported.contentSHA256,
      "nativeRepositoryRevision": imported.nativeRepositoryRevision,
      "bodyNames": imported.bodyNames, "jointNames": imported.jointNames,
      "topology": try JSONSerialization.jsonObject(with: JSONEncoder().encode(topology)),
      "actuators": try JSONSerialization.jsonObject(with: JSONEncoder().encode(imported.actuators)),
      "scope": "structural import only; physical-owner fingerprint supplied by caller; no sensor or actuator runtime admission"]
  } else if command == "catalog", args.count == 3 {
    let graph = try ConnectomeGraph(contentsOf: URL(fileURLWithPath: args[1]))
    let target = URL(fileURLWithPath: args[2])
    guard !FileManager.default.fileExists(atPath: target.path) else { throw ConnectomeError.invalid("catalog output already exists") }
    // JSON Lines preserves every 64-bit ID as a STRING for JavaScript consumers.
    var data = Data()
    for i in 0..<graph.nodeCount {
      let node = try graph.node(at: i)
      let row: [String: Any] = ["id": String(UInt64(node.identity_low) | UInt64(node.identity_high)<<32),
        "label": try graph.label(at: i), "flags": node.flags]
      data.append(try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])); data.append(10)
    }
    try data.write(to: target, options: [.atomic])
    result = ["nodes": graph.nodeCount, "catalog": target.path]
  } else {
    throw ConnectomeError.invalid("usage: import-numilab-topology ROBOT.json SHA256 NATIVE_REVISION OWNER_MODEL_HEX | inspect GRAPH | catalog GRAPH OUTPUT.jsonl | validate-controller GRAPH SPEC.json BODY.json PARAMETER_HEX | audit-controller GRAPH SPEC.json BODY.json PARAMETER_HEX")
  }
  let json = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
  FileHandle.standardOutput.write(json); FileHandle.standardOutput.write(Data([10]))
} catch {
  FileHandle.standardError.write(Data("\(error)\n".utf8)); exit(1)
}

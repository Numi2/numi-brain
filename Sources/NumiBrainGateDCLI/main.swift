import Foundation
import NumiBrainValidation
#if canImport(NumiBrainCore)
import NumiBrainCore
#endif
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

private struct ProbeReport: Encodable {
  let formatVersion: UInt32 = 1
  let scope: String = "offline-measurement-diagnostic"
  let promotable: Bool = false
  let output: GateDProbeOutput
}

private enum CLIUsageError: Error { case invalid(String) }

private func usage() {
  print("""
  numi-brain-gate-d probe --input FILE [--output FILE]
  numi-brain-gate-d import-reference --input FILE --specification FILE [--output FILE]
  numi-brain-gate-d suites
  numi-brain-gate-d retain --input FILE --artifact-dir DIR
  numi-brain-gate-d export-sensor --artifact-dir DIR --run-sha SHA --schema-sha SHA --receptor N --feature N
  numi-brain-gate-d export-reference --artifact-dir DIR --source-sha SHA --specification-sha SHA
  numi-brain-gate-d verify-reference --artifact-dir DIR --trace-sha SHA
  numi-brain-gate-d verify-sensor --artifact-dir DIR --trace-sha SHA
  numi-brain-gate-d evaluate-trace --artifact-dir DIR --protocol-sha SHA --trace-sha SHA
  numi-brain-gate-d verify-evaluation --artifact-dir DIR --evaluation-sha SHA

  probe executes typed independent mechanics, convergence, trace, or statistical
  checks on supplied measurements. It does not execute NumanX or promote Gate D.
  export-sensor reconstructs settled input receptors from an existing verified
  Gate C capture. It is not the just-finished root's endpoint measurement.
  Retained-artifact commands require the full NumiBrainCore Apple build.
  Exit: 0 diagnostic pass or descriptive output; 1 failed; 2 inconclusive;
  64 usage error; 65 invalid evidence. Failed evaluations are still retained.
  """)
}

private func readInput(_ path: String) throws -> Data {
  let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
  defer { try? handle.close() }
  let limit = 64 * 1024 * 1024
  var bytes = Data()
  while let chunk = try handle.read(upToCount: min(1024 * 1024, limit + 1 - bytes.count)), !chunk.isEmpty {
    bytes.append(chunk)
    guard bytes.count <= limit else { throw PhysicalValidationError.invalid("input exceeds 64 MiB") }
  }
  guard !bytes.isEmpty else { throw PhysicalValidationError.invalid("empty input") }
  return bytes
}

private func emit<T: Encodable>(_ value: T, path: String? = nil) throws {
  let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  var data = try encoder.encode(value); data.append(10)
  if let path { try data.write(to: URL(fileURLWithPath: path), options: .atomic) }
  FileHandle.standardOutput.write(data)
}

private func exitCode(_ status: PhysicalValidationStatus?) -> Int32 {
  switch status { case .passed, nil: 0; case .failed: 1; case .inconclusive: 2 }
}

private func run() throws -> Int32 {
  let args = Array(CommandLine.arguments.dropFirst())
  guard let command = args.first else { usage(); return 64 }
  if command == "--help" || command == "help" { usage(); return 0 }
  var options: [String: String] = [:]
  var cursor = 1
  while cursor < args.count {
    guard args[cursor].hasPrefix("--"), cursor + 1 < args.count,
      options[args[cursor]] == nil else { usage(); return 64 }
    options[args[cursor]] = args[cursor + 1]; cursor += 2
  }
  func require(_ key: String) throws -> String {
    guard let value = options[key], !value.isEmpty else {
      throw CLIUsageError.invalid("missing option \(key)")
    }
    return value
  }
  func keys(_ required: Set<String>, optional: Set<String> = []) throws {
    guard required.isSubset(of: Set(options.keys)), Set(options.keys).isSubset(of: required.union(optional)) else {
      throw CLIUsageError.invalid("unknown or missing command options")
    }
  }
  switch command {
  case "suites":
    try keys([]); try emit(GateDRequiredSuite.allCases.map(\.rawValue)); return 0
  case "import-reference":
    try keys(["--input", "--specification"], optional: ["--output"])
    let input = try require("--input"), specificationPath = try require("--specification")
    if let output = options["--output"], [input, specificationPath].contains(where: {
      URL(fileURLWithPath: $0).standardizedFileURL.resolvingSymlinksInPath()
        == URL(fileURLWithPath: output).standardizedFileURL.resolvingSymlinksInPath()
    }) { throw PhysicalValidationError.invalid("output would overwrite reference input/specification") }
    let specification = try JSONDecoder().decode(PhysicalReferenceImport.self, from: readInput(specificationPath))
    try emit(specification.decode(readInput(input)), path: options["--output"])
    return 0
  case "probe":
    try keys(["--input"], optional: ["--output"])
    let input = try require("--input")
    if let output = options["--output"], URL(fileURLWithPath: input).standardizedFileURL.resolvingSymlinksInPath()
      == URL(fileURLWithPath: output).standardizedFileURL.resolvingSymlinksInPath() {
      throw PhysicalValidationError.invalid("output would overwrite probe input")
    }
    let probe = try JSONDecoder().decode(GateDProbe.self, from: readInput(input))
    let result = try probe.evaluate()
    try emit(ProbeReport(output: result), path: options["--output"])
    return exitCode(result.diagnosticStatus)
#if canImport(NumiBrainCore)
  case "retain":
    try keys(["--input", "--artifact-dir"])
    let hash = try BrainGateDEvidence.retain(readInput(require("--input")),
      artifactDirectory: URL(fileURLWithPath: require("--artifact-dir")))
    try emit(["artifactSHA256": hash]); return 0
  case "export-sensor":
    try keys(["--artifact-dir", "--run-sha", "--schema-sha", "--receptor", "--feature"])
    guard let receptor = UInt32(try require("--receptor")), let feature = UInt32(try require("--feature")) else {
      throw PhysicalValidationError.invalid("receptor/feature must be UInt32 indices")
    }
    let directory = URL(fileURLWithPath: try require("--artifact-dir"))
    let artifact = try BrainGateDEvidence.exportSensorTrace(runSHA256: require("--run-sha"),
      schemaSHA256: require("--schema-sha"), receptorIndex: receptor, featureIndex: feature, artifactDirectory: directory)
    let hash = try BrainGateDEvidence.retain(artifact, artifactDirectory: directory)
    try emit(["traceSHA256": hash, "runEvidenceSHA256": artifact.runEvidenceSHA256]); return 0
  case "export-reference":
    try keys(["--artifact-dir", "--source-sha", "--specification-sha"])
    let directory = URL(fileURLWithPath: try require("--artifact-dir"))
    let artifact = try BrainGateDEvidence.exportReferenceTrace(sourceSHA256: require("--source-sha"),
      importSpecificationSHA256: require("--specification-sha"), artifactDirectory: directory)
    let hash = try BrainGateDEvidence.retain(artifact, artifactDirectory: directory)
    try emit(["referenceTraceSHA256": hash]); return 0
  case "verify-reference":
    try keys(["--artifact-dir", "--trace-sha"])
    try emit(BrainGateDEvidence.verifyReferenceTrace(sha256: require("--trace-sha"),
      artifactDirectory: URL(fileURLWithPath: require("--artifact-dir"))))
    return 0
  case "verify-sensor":
    try keys(["--artifact-dir", "--trace-sha"])
    let artifact = try BrainGateDEvidence.verifySensorTrace(sha256: require("--trace-sha"),
      artifactDirectory: URL(fileURLWithPath: require("--artifact-dir")))
    try emit(artifact); return 0
  case "evaluate-trace":
    try keys(["--artifact-dir", "--protocol-sha", "--trace-sha"])
    let directory = URL(fileURLWithPath: try require("--artifact-dir"))
    let result = try BrainGateDEvidence.evaluateTrace(protocolSHA256: require("--protocol-sha"),
      candidateSHA256: require("--trace-sha"), artifactDirectory: directory)
    let hash = try BrainGateDEvidence.retain(result, artifactDirectory: directory)
    try emit(["evaluationSHA256": hash, "evidenceSHA256": result.evidenceSHA256, "diagnosticStatus": result.result.status.rawValue])
    return exitCode(result.result.status)
  case "verify-evaluation":
    try keys(["--artifact-dir", "--evaluation-sha"])
    let result = try BrainGateDEvidence.verifyTraceEvaluation(sha256: require("--evaluation-sha"),
      artifactDirectory: URL(fileURLWithPath: require("--artifact-dir")))
    try emit(result); return exitCode(result.result.status)
#endif
  default: usage(); return 64
  }
}

do { exit(try run()) }
catch {
  FileHandle.standardError.write(Data("numi-brain-gate-d: \(error)\n".utf8))
  exit(error is CLIUsageError ? 64 : 65)
}

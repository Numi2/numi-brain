import Foundation
import NumiBrainQualification
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

private func usage() {
  print("""
  numi-brain-gate-e summarize --samples FILE
  numi-brain-gate-e verify --run FILE --measurements FILE --protocol FILE
  """)
}

private func read<T: Decodable>(_ type: T.Type, _ path: String) throws -> T {
  let data = try Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe])
  guard !data.isEmpty, data.count <= 256 * 1024 * 1024 else {
    throw QualificationError.invalid("input is empty or exceeds 256 MiB")
  }
  return try JSONDecoder().decode(type, from: data)
}

private func emit<T: Encodable>(_ value: T) throws {
  let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  var data = try encoder.encode(value); data.append(10)
  FileHandle.standardOutput.write(data)
}

let args = Array(CommandLine.arguments.dropFirst())
do {
  guard let command = args.first else { usage(); exit(64) }
  switch command {
  case "summarize":
    guard args.count == 3, args[1] == "--samples" else { usage(); exit(64) }
    try emit(LatencyDistribution(samplesMicroseconds: read([Double].self, args[2])))
    exit(0)
  case "verify":
    guard args.count == 7,
      args[1] == "--run", args[3] == "--measurements", args[5] == "--protocol" else {
      usage(); exit(64)
    }
    let run = try read(PerformanceRunArtifact.self, args[2])
    let measurements = try read(PerformanceMeasurementArtifact.self, args[4])
    try PerformanceEvidenceVerifier.verify(run: run, measurements: measurements)
    let result = PerformanceQualificationResult(run: run,
      protocol: try read(PerformanceQualificationProtocol.self, args[6]))
    try emit(result)
    exit(result.passed ? 0 : 1)
  default:
    usage(); exit(64)
  }
} catch {
  FileHandle.standardError.write(Data("numi-brain-gate-e: \(error)\n".utf8))
  exit(65)
}

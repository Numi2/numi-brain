import Foundation
import NumiBrainQualification
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

private func usage() {
  print("numi-brain-gate-e summarize --samples FILE\nnumi-brain-gate-e verify --run FILE --protocol FILE")
}

private func read<T: Decodable>(_ type: T.Type, _ path: String) throws -> T {
  let data = try Data(contentsOf: URL(fileURLWithPath: path))
  guard !data.isEmpty, data.count <= 256 * 1024 * 1024 else { throw QualificationError.invalid("input size") }
  return try JSONDecoder().decode(type, from: data)
}
private func emit<T: Encodable>(_ value: T) throws {
  let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
  var d = try e.encode(value); d.append(10); FileHandle.standardOutput.write(d)
}
let a = Array(CommandLine.arguments.dropFirst())
do {
  guard let command = a.first else { usage(); exit(64) }
  if command == "summarize" {
    guard a.count == 3, a[1] == "--samples" else { usage(); exit(64) }
    try emit(LatencyDistribution(samplesMicroseconds: read([Double].self, a[2]))); exit(0)
  }
  if command == "verify" {
    guard a.count == 5, a[1] == "--run", a[3] == "--protocol" else { usage(); exit(64) }
    let result = PerformanceQualificationResult(run: try read(PerformanceRunArtifact.self, a[2]),
      protocol: try read(PerformanceQualificationProtocol.self, a[4]))
    try emit(result); exit(result.passed ? 0 : 1)
  }
  usage(); exit(64)
} catch { FileHandle.standardError.write(Data("numi-brain-gate-e: \(error)\n".utf8)); exit(65) }

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
  numi-brain-gate-e check-attempts --ledger FILE --protocol FILE
  numi-brain-gate-e inspect-legacy --run FILE --measurements FILE --protocol FILE
  The former verify command returns inconclusive (2): v1 records do not bind
  accepted progress. Supplied-ledger checks do not authenticate native execution
  or protocol/source hashes, and always report promotable=false.
  """)
}
private func read<T: Decodable>(_ type: T.Type, _ path: String) throws -> T {
  try JSONDecoder().decode(type,
    from: QualificationFileDirectory.readFile(URL(fileURLWithPath: path), maximumBytes: 256 * 1024 * 1024))
}
private func emit<T: Encodable>(_ value: T) throws {
  var data = try QualificationFileDirectory.canonicalJSON(value); data.append(10)
  FileHandle.standardOutput.write(data)
}
private struct LegacyDiagnostic: Encodable {
  let scope = "legacy-v1-numeric-consistency-only"
  let promotable = false
  let acceptedProgressVerified = false
  let result: PerformanceQualificationResult
}

let args = Array(CommandLine.arguments.dropFirst())
do {
  guard let command = args.first else { usage(); exit(64) }
  switch command {
  case "summarize":
    guard args.count == 3, args[1] == "--samples" else { usage(); exit(64) }
    try emit(LatencyDistribution(samplesMicroseconds: read([Double].self, args[2]))); exit(0)
  case "check-attempts":
    guard args.count == 5, args[1] == "--ledger", args[3] == "--protocol" else { usage(); exit(64) }
    let result = try PerformanceAttemptEvaluation(ledger: read(PerformanceAttemptLedger.self, args[2]),
      protocol: read(PerformanceAttemptProtocol.self, args[4]))
    try emit(result); exit(result.passed ? 0 : 1)
  case "inspect-legacy", "verify":
    guard args.count == 7, args[1] == "--run", args[3] == "--measurements", args[5] == "--protocol" else { usage(); exit(64) }
    let run = try read(PerformanceRunArtifact.self, args[2])
    try PerformanceEvidenceVerifier.verify(run: run, measurements: read(PerformanceMeasurementArtifact.self, args[4]))
    let result = PerformanceQualificationResult(run: run, protocol: try read(PerformanceQualificationProtocol.self, args[6]))
    try emit(LegacyDiagnostic(result: result)); exit(command == "verify" ? 2 : (result.passed ? 0 : 1))
  default: usage(); exit(64)
  }
} catch { FileHandle.standardError.write(Data("numi-brain-gate-e: \(error)\n".utf8)); exit(65) }

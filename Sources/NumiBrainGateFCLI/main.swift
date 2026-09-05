import Foundation
import NumiBrainQualification
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

private struct Input: Codable { let vector: SafetyVector; let envelope: SafetyEnvelope }
private func usage() { print("numi-brain-gate-f decide --input FILE") }
let a = Array(CommandLine.arguments.dropFirst())
do {
  guard a.count == 3, a[0] == "decide", a[1] == "--input" else { usage(); exit(64) }
  let data = try Data(contentsOf: URL(fileURLWithPath: a[2]))
  guard !data.isEmpty, data.count <= 4 * 1024 * 1024 else { throw QualificationError.invalid("input size") }
  let input = try JSONDecoder().decode(Input.self, from: data)
  let decision = SafetyDecision(vector: input.vector, envelope: input.envelope)
  let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
  var d = try e.encode(decision); d.append(10); FileHandle.standardOutput.write(d)
  exit(decision.disposition == .allow ? 0 : 1)
} catch { FileHandle.standardError.write(Data("numi-brain-gate-f: \(error)\n".utf8)); exit(65) }

import Foundation
import NumiBrainQualification
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

private struct QualificationSummary: Encodable {
  let scope = "unverified-gate-declaration"
  let promotable = false
  let sourceRevision: String
  let declaredPromotionReady: Bool
  let gates: [GateEvidenceEntry]
  let verificationRequired: [String]
}

private func usage() {
  print("numi-brain-qualify inspect --manifest FILE\nThe former verify command cannot verify gate evidence and now fails closed.")
}

let args = Array(CommandLine.arguments.dropFirst())
do {
  guard args.count == 3, ["inspect", "verify"].contains(args[0]), args[1] == "--manifest" else {
    usage(); exit(64)
  }
  let data = try QualificationFileDirectory.readFile(URL(fileURLWithPath: args[2]), maximumBytes: 64 * 1024 * 1024)
  let manifest = try JSONDecoder().decode(NumanXQualificationManifest.self, from: data)
  try manifest.validate()
  let summary = QualificationSummary(sourceRevision: manifest.sourceRevision,
    declaredPromotionReady: manifest.declaredPromotionReady, gates: manifest.entries,
    verificationRequired: PromotionGate.allCases.map { $0.rawValue })
  var output = try QualificationFileDirectory.canonicalJSON(summary); output.append(10)
  FileHandle.standardOutput.write(output)
  if args[0] == "verify" {
    FileHandle.standardError.write(Data("No all-gates evidence verifier is registered. A manifest is not authority; use the gate-specific evidence verifiers.\n".utf8))
    exit(2)
  }
  exit(0)
} catch {
  FileHandle.standardError.write(Data("numi-brain-qualify: \(error)\n".utf8)); exit(65)
}

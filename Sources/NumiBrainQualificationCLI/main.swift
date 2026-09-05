import Foundation
import NumiBrainQualification
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

private struct QualificationSummary: Encodable {
  let sourceRevision: String
  let promotionReady: Bool
  let gates: [GateEvidenceEntry]
}

private func usage() {
  print("numi-brain-qualify verify --manifest FILE")
}

let args = Array(CommandLine.arguments.dropFirst())
do {
  guard args.count == 3, args[0] == "verify", args[1] == "--manifest" else {
    usage(); exit(64)
  }
  let data = try Data(contentsOf: URL(fileURLWithPath: args[2]), options: [.mappedIfSafe])
  guard !data.isEmpty, data.count <= 64 * 1024 * 1024 else {
    throw QualificationError.invalid("qualification manifest is empty or unbounded")
  }
  let manifest = try JSONDecoder().decode(NumanXQualificationManifest.self, from: data)
  // Reconstruct through the validating initializer. Synthesized Codable alone
  // must never allow a malformed decoded manifest to bypass canonical A...F
  // membership and one-revision requirements.
  let canonical = try NumanXQualificationManifest(
    sourceRevision: manifest.sourceRevision,
    entries: manifest.entries
  )
  guard canonical == manifest, manifest.formatVersion == NumanXQualificationManifest.formatVersion else {
    throw QualificationError.invalid("qualification manifest is not canonical")
  }
  let summary = QualificationSummary(sourceRevision: canonical.sourceRevision,
    promotionReady: canonical.promotionReady, gates: canonical.entries)
  let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  var output = try encoder.encode(summary); output.append(10)
  FileHandle.standardOutput.write(output)
  exit(canonical.promotionReady ? 0 : 1)
} catch {
  FileHandle.standardError.write(Data("numi-brain-qualify: \(error)\n".utf8))
  exit(65)
}

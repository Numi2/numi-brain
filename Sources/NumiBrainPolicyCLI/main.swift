import Darwin
import Foundation
import NumiBrainCore

private struct PolicySummary: Codable {
  let packageIdentifier: String
  let packageContentSHA256: String
  let modelIdentifier: String
  let modelRevision: String
  let modelWeightsSHA256: String
  let parameterVersionFingerprint: String
  let sourceRevision: String
  let datasetSourceCount: Int
  let datasetPartitionCount: Int
  let qualificationAxisCount: Int
  let gateCEvidenceManifestComplete: Bool
}

private func usage() -> Never {
  FileHandle.standardError.write(
    Data(
      "usage: numi-brain-policy <inspect|validate> <package.nbpolicy>\n".utf8
    ))
  exit(64)
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else { usage() }
let mode = arguments[1]
guard mode == "inspect" || mode == "validate" else { usage() }

do {
  let url = URL(fileURLWithPath: arguments[2])
  let package = try BrainFoundationPolicyPackage.decode(Data(contentsOf: url))
  if mode == "validate" {
    try package.validateGateCEvidenceManifest()
  }
  let publication = try package.publication()
  let summary = PolicySummary(
    packageIdentifier: package.packageIdentifier,
    packageContentSHA256: package.packageContentSHA256,
    modelIdentifier: package.architecture.modelIdentifier,
    modelRevision: package.architecture.modelRevision,
    modelWeightsSHA256: package.architecture.modelWeightsSHA256,
    parameterVersionFingerprint: publication.version.fingerprintHex,
    sourceRevision: package.sourceRevision,
    datasetSourceCount: package.datasetSources.count,
    datasetPartitionCount: package.datasetPartitions.count,
    qualificationAxisCount: package.qualificationResults.count,
    gateCEvidenceManifestComplete: package.isGateCEvidenceManifestComplete
  )
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  FileHandle.standardOutput.write(try encoder.encode(summary))
  FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
  FileHandle.standardError.write(Data("numi-brain-policy: \(error)\n".utf8))
  exit(1)
}

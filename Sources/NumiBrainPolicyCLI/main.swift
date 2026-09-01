import Darwin
import Foundation
import NumiBrainCore

private struct PolicySummary: Codable {
  let packageFormatVersion: UInt32
  let qualificationEvidenceFormatVersion: UInt32
  let packageIdentifier: String
  let packageContentSHA256: String
  let modelIdentifier: String
  let modelRevision: String
  let modelWeightsSHA256: String
  let parameterVersionFingerprint: String
  let ownerProgramFingerprint: String
  let lowLevelControllerFingerprint: String
  let hardSafetyProgramFingerprint: String
  let supervisionRequestThreshold: Float
  let rootRejectionThreshold: Float
  let sourceRevision: String
  let datasetSourceCount: Int
  let datasetPartitionCount: Int
  let qualificationAxisCount: Int
  let gateCEvidenceManifestComplete: Bool
  let evidenceRootSHA256: String?
}

private func usage() -> Never {
  FileHandle.standardError.write(
    Data(
      "usage: numi-brain-policy <inspect|validate> <package.nbpolicy>\n"
        .appending(
          "       numi-brain-policy verify <package.nbpolicy> <artifact-directory>\n"
        ).utf8
    ))
  exit(64)
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else { usage() }
let mode = arguments[1]
guard mode == "inspect" || mode == "validate" || mode == "verify" else {
  usage()
}
guard
  (mode == "verify" && arguments.count == 4)
    || (mode != "verify" && arguments.count == 3)
else { usage() }

do {
  let url = URL(fileURLWithPath: arguments[2])
  let package = try BrainFoundationPolicyPackage.decode(Data(contentsOf: url))
  if mode == "validate" || mode == "verify" {
    try package.validateGateCEvidenceManifest()
  }
  let receipt =
    try mode == "verify"
    ? BrainFoundationPolicyEvidenceVerifier.verify(
      package: package,
      artifactDirectory: URL(fileURLWithPath: arguments[3], isDirectory: true)
    ) : nil
  let publication = try package.publication()
  let summary = PolicySummary(
    packageFormatVersion: package.formatVersion,
    qualificationEvidenceFormatVersion:
      BrainPolicyQualificationEvidence.formatVersion,
    packageIdentifier: package.packageIdentifier,
    packageContentSHA256: package.packageContentSHA256,
    modelIdentifier: package.architecture.modelIdentifier,
    modelRevision: package.architecture.modelRevision,
    modelWeightsSHA256: package.architecture.modelWeightsSHA256,
    parameterVersionFingerprint: publication.version.fingerprintHex,
    ownerProgramFingerprint: String(
      format: "%016llx", package.architecture.ownerProgramFingerprint
    ),
    lowLevelControllerFingerprint: String(
      format: "%016llx", package.architecture.lowLevelControllerFingerprint
    ),
    hardSafetyProgramFingerprint: String(
      format: "%016llx", package.architecture.hardSafetyProgramFingerprint
    ),
    supervisionRequestThreshold:
      package.architecture.supervisionRequestThreshold,
    rootRejectionThreshold: package.architecture.rootRejectionThreshold,
    sourceRevision: package.sourceRevision,
    datasetSourceCount: package.datasetSources.count,
    datasetPartitionCount: package.datasetPartitions.count,
    qualificationAxisCount: package.qualificationResults.count,
    gateCEvidenceManifestComplete: package.isGateCEvidenceManifestComplete,
    evidenceRootSHA256: receipt?.evidenceRootSHA256
  )
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  FileHandle.standardOutput.write(try encoder.encode(summary))
  FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
  FileHandle.standardError.write(Data("numi-brain-policy: \(error)\n".utf8))
  exit(1)
}

import Foundation

@frozen
public struct NumanXReleaseManifest: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1
  public let formatVersion: UInt32
  public let releaseIdentifier: String
  public let sourceRevision: String
  public let binarySHA256: String
  public let metallibSHA256: String
  public let modelSHA256: String
  public let datasetManifestSHA256: String
  public let qualificationManifestSHA256: String
  public let previousReleaseManifestSHA256: String?
  public let createdUnixSeconds: UInt64
  public let deploymentGeneration: UInt64

  public init(releaseIdentifier: String, sourceRevision: String,
    binarySHA256: String, metallibSHA256: String, modelSHA256: String,
    datasetManifestSHA256: String, qualificationManifestSHA256: String,
    previousReleaseManifestSHA256: String?, createdUnixSeconds: UInt64,
    deploymentGeneration: UInt64) throws {
    let hashes = [binarySHA256, metallibSHA256, modelSHA256,
      datasetManifestSHA256, qualificationManifestSHA256]
    guard !releaseIdentifier.isEmpty, releaseIdentifier.utf8.count <= 256,
      !sourceRevision.isEmpty, hashes.allSatisfy(PerformanceRunArtifact.isSHA256),
      previousReleaseManifestSHA256 == nil || PerformanceRunArtifact.isSHA256(previousReleaseManifestSHA256!),
      createdUnixSeconds > 0, deploymentGeneration > 0 else {
      throw QualificationError.invalid("release manifest is incomplete")
    }
    formatVersion = Self.formatVersion
    self.releaseIdentifier = releaseIdentifier; self.sourceRevision = sourceRevision
    self.binarySHA256 = binarySHA256; self.metallibSHA256 = metallibSHA256
    self.modelSHA256 = modelSHA256; self.datasetManifestSHA256 = datasetManifestSHA256
    self.qualificationManifestSHA256 = qualificationManifestSHA256
    self.previousReleaseManifestSHA256 = previousReleaseManifestSHA256
    self.createdUnixSeconds = createdUnixSeconds; self.deploymentGeneration = deploymentGeneration
  }
}

@frozen
public struct RollbackAuthorization: Codable, Equatable, Sendable {
  public let activeReleaseSHA256: String
  public let targetReleaseSHA256: String
  public let targetDeploymentGeneration: UInt64
  public let reason: String

  public init(activeReleaseSHA256: String, targetReleaseSHA256: String,
    targetDeploymentGeneration: UInt64, reason: String) throws {
    guard PerformanceRunArtifact.isSHA256(activeReleaseSHA256),
      PerformanceRunArtifact.isSHA256(targetReleaseSHA256), activeReleaseSHA256 != targetReleaseSHA256,
      targetDeploymentGeneration > 0, !reason.isEmpty, reason.utf8.count <= 512 else {
      throw QualificationError.invalid("rollback authorization is invalid")
    }
    self.activeReleaseSHA256 = activeReleaseSHA256; self.targetReleaseSHA256 = targetReleaseSHA256
    self.targetDeploymentGeneration = targetDeploymentGeneration; self.reason = reason
  }
}

public enum ReleaseChainVerifier {
  /// Verifies that each newer release explicitly names the content hash of the
  /// prior release. The caller supplies the hashes after independently hashing
  /// the canonical retained manifests; this function never trusts filenames.
  public static func verify(chain: [(sha256: String, manifest: NumanXReleaseManifest)]) throws {
    guard !chain.isEmpty, chain.count <= 100_000 else {
      throw QualificationError.invalid("release chain is empty or unbounded")
    }
    var seen = Set<String>()
    for (index, item) in chain.enumerated() {
      guard PerformanceRunArtifact.isSHA256(item.sha256), seen.insert(item.sha256).inserted else {
        throw QualificationError.invalid("release chain contains invalid or duplicate identities")
      }
      if index == 0 {
        guard item.manifest.previousReleaseManifestSHA256 == nil else {
          throw QualificationError.invalid("release chain root names a predecessor")
        }
      } else {
        let previous = chain[index - 1]
        guard item.manifest.previousReleaseManifestSHA256 == previous.sha256,
          item.manifest.deploymentGeneration == previous.manifest.deploymentGeneration + 1,
          item.manifest.createdUnixSeconds >= previous.manifest.createdUnixSeconds else {
          throw QualificationError.invalid("release chain is discontinuous")
        }
      }
    }
  }

  public static func verifyRollback(_ authorization: RollbackAuthorization,
    chain: [(sha256: String, manifest: NumanXReleaseManifest)]) throws {
    try verify(chain: chain)
    guard let active = chain.last, active.sha256 == authorization.activeReleaseSHA256,
      let target = chain.first(where: {$0.sha256 == authorization.targetReleaseSHA256}),
      target.manifest.deploymentGeneration == authorization.targetDeploymentGeneration,
      target.manifest.deploymentGeneration < active.manifest.deploymentGeneration else {
      throw QualificationError.invalid("rollback target is not a verified prior release")
    }
  }
}

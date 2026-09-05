import XCTest
@testable import NumiBrainQualification

final class ReleaseManifestTests: XCTestCase {
  private let a = String(repeating: "a", count: 64)
  private let b = String(repeating: "b", count: 64)
  private let c = String(repeating: "c", count: 64)
  private let d = String(repeating: "d", count: 64)
  private let e = String(repeating: "e", count: 64)

  private func manifest(generation: UInt64, previous: String?) throws -> NumanXReleaseManifest {
    try .init(releaseIdentifier: "release-\(generation)", sourceRevision: "revision",
      binarySHA256: a, metallibSHA256: b, modelSHA256: c, datasetManifestSHA256: d,
      qualificationManifestSHA256: e, previousReleaseManifestSHA256: previous,
      createdUnixSeconds: 100 + generation, deploymentGeneration: generation)
  }

  func testReleaseChainAndRollback() throws {
    let firstHash = String(repeating: "1", count: 64)
    let secondHash = String(repeating: "2", count: 64)
    let first = try manifest(generation: 1, previous: nil)
    let second = try manifest(generation: 2, previous: firstHash)
    let chain = [(sha256: firstHash, manifest: first), (sha256: secondHash, manifest: second)]
    XCTAssertNoThrow(try ReleaseChainVerifier.verify(chain: chain))
    let rollback = try RollbackAuthorization(activeReleaseSHA256: secondHash,
      targetReleaseSHA256: firstHash, targetDeploymentGeneration: 1, reason: "regression")
    XCTAssertNoThrow(try ReleaseChainVerifier.verifyRollback(rollback, chain: chain))
  }

  func testReleaseChainRejectsSkippedGeneration() throws {
    let firstHash = String(repeating: "1", count: 64)
    let first = try manifest(generation: 1, previous: nil)
    let third = try manifest(generation: 3, previous: firstHash)
    XCTAssertThrowsError(try ReleaseChainVerifier.verify(chain: [
      (sha256: firstHash, manifest: first),
      (sha256: String(repeating: "3", count: 64), manifest: third),
    ]))
  }
}

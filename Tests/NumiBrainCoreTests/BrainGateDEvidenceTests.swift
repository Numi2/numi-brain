import Foundation
import XCTest
import NumiBrainValidation
@testable import NumiBrainCore

/// Requires the Apple Core target. These are artifact tests, not GPU or
/// physical calibration evidence; no native body execution is fabricated.
final class BrainGateDEvidenceTests: XCTestCase {
  private func directory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    addTeardownBlock { try FileManager.default.removeItem(at: url) }
    return url
  }

  private func trace() throws -> PhysicalTrace {
    try PhysicalTrace(quantity: "force", unit: "N", frame: "local", coordinate: "muscle:23",
      timestampsMicroseconds: [0, 1000], values: [1, 2], validity: [true, true])
  }

  private func reference(in directory: URL) throws -> (String, BrainGateDReferenceTraceArtifact) {
    let sourceHash = try BrainGateDEvidence.retain(trace(), artifactDirectory: directory)
    let importHash = try BrainGateDEvidence.retain(PhysicalReferenceImport.traceJSON, artifactDirectory: directory)
    let artifact = try BrainGateDEvidence.exportReferenceTrace(sourceSHA256: sourceHash,
      importSpecificationSHA256: importHash, artifactDirectory: directory)
    return (try BrainGateDEvidence.retain(artifact, artifactDirectory: directory), artifact)
  }

  func testReferenceVerificationRebuildsFromRawSource() throws {
    let store = try directory()
    let (hash, artifact) = try reference(in: store)
    XCTAssertEqual(try BrainGateDEvidence.verifyReferenceTrace(sha256: hash, artifactDirectory: store), artifact)
  }

  func testReferenceMetricForgeryFailsDespiteValidNewHash() throws {
    let store = try directory()
    let (_, artifact) = try reference(in: store)
    let falseTrace = try PhysicalTrace(quantity: "force", unit: "N", frame: "local", coordinate: "muscle:23",
      timestampsMicroseconds: [0, 1000], values: [100, 200], validity: [true, true])
    let modified = BrainGateDReferenceTraceArtifact(formatVersion: 1, sourceSHA256: artifact.sourceSHA256,
      importSpecificationSHA256: artifact.importSpecificationSHA256, trace: falseTrace)
    let hash = try BrainGateDEvidence.retain(modified, artifactDirectory: store)
    XCTAssertThrowsError(try BrainGateDEvidence.verifyReferenceTrace(sha256: hash, artifactDirectory: store))
  }

  func testMissingSourceFailsEvenWhenReferenceTraceIsComplete() throws {
    let store = try directory()
    let (hash, artifact) = try reference(in: store)
    let rawURL = try BrainPolicyEvidenceArtifact.url(forSHA256: artifact.sourceSHA256, in: store)
    try FileManager.default.removeItem(at: rawURL)
    XCTAssertThrowsError(try BrainGateDEvidence.verifyReferenceTrace(sha256: hash, artifactDirectory: store))
  }

  func testProtocolRejectsExactCalibrationSourceOverlap() throws {
    let comparison = try PhysicalTraceComparisonPlan(minimumDurationMicroseconds: 1000, physicalScale: 1,
      maximumNormalizedRMSE: 0.1, maximumNormalizedPeakError: 0.2, maximumNormalizedAbsoluteBias: 0.1)
    let source = String(repeating: "a", count: 64)
    let protocolValue = BrainGateDTraceProtocol(formatVersion: 1, identifier: "fixture-only",
      expectedRuntimeSourceRevision: "test-revision", expectedNativeModelSourceFingerprint: 1,
      expectedParameterVersionFingerprint: 2, expectedAcceptedStateProofProgramFingerprint: 3,
      sensorSchemaSHA256: String(repeating: "b", count: 64), receptorIndex: 23, featureIndex: 0,
      referenceKind: .analytic, referenceTraceSHA256: String(repeating: "c", count: 64),
      referenceSourceSHA256: source, referenceSourceURI: "urn:numi:test-reference",
      referenceSourceRevision: "test", referenceLicense: "test-fixture", referenceProcessingRevision: "v1",
      referenceImportSpecificationSHA256: String(repeating: "d", count: 64),
      calibrationArtifactSHA256: [source], minimumAcceptedRootCount: 2,
      maximumRejectedRootFraction: 0, comparison: comparison)
    XCTAssertThrowsError(try protocolValue.validate())
  }

  func testSchemaRejectsDuplicateOrOutOfRangeCoordinates() {
    let field = BrainGateDSensorSchema.Field(index: 0, quantity: "force", unit: "N", frame: "local", coordinatePrefix: "muscle:")
    let duplicate = BrainGateDSensorSchema(formatVersion: 1, nativeModelSourceFingerprint: 1,
      compiledSpeciesTemplateFingerprint: 2, modality: .proprioception, receptorCount: 416,
      featureDimension: 10, ownerSchemaRevision: "test", fields: [field, field])
    XCTAssertThrowsError(try duplicate.validate())
    let invalid = BrainGateDSensorSchema(formatVersion: 1, nativeModelSourceFingerprint: 1,
      compiledSpeciesTemplateFingerprint: 2, modality: .proprioception, receptorCount: 416,
      featureDimension: 0, ownerSchemaRevision: "test", fields: [field])
    XCTAssertThrowsError(try invalid.validate())
  }

  func testDecodedSensorTraceCannotStandInForMissingCaptureAuthority() throws {
    let store = try directory()
    let value = BrainGateDSensorTraceArtifact(formatVersion: 1, observationPhase: "settled-input-before-accepted-root",
      runArtifactSHA256: String(repeating: "a", count: 64), runEvidenceSHA256: String(repeating: "b", count: 64),
      datasetSourceRevision: String(repeating: "c", count: 64), acceptedStateProofProgramFingerprint: 1,
      sensorSchemaSHA256: String(repeating: "d", count: 64), receptorIndex: 23, featureIndex: 0,
      sourceRevision: "fixture", nativeModelSourceFingerprint: 2, parameterVersionFingerprint: 3,
      acceptedRootCount: 2, rejectedRootCount: 0, acceptedSampleSHA256: [], trace: try trace())
    let hash = try BrainGateDEvidence.retain(value, artifactDirectory: store)
    XCTAssertThrowsError(try BrainGateDEvidence.verifySensorTrace(sha256: hash, artifactDirectory: store))
  }
}

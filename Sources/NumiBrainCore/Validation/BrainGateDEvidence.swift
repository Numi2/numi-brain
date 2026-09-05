import Foundation
import NumiBrainValidation

/// Version 2 requires an explicit validity mask for every selected field.
/// Version-1 schemas assumed bit zero and cannot qualify new derived traces.
public struct BrainGateDSensorSchema: Codable, Equatable, Sendable {
  public struct Field: Codable, Equatable, Sendable {
    public let index: UInt32
    public let quantity: String
    public let unit: String
    public let frame: String
    public let coordinatePrefix: String
    public let requiredValidityMask: UInt32?
    public init(index: UInt32, quantity: String, unit: String, frame: String,
      coordinatePrefix: String, requiredValidityMask: UInt32? = nil) {
      self.index = index; self.quantity = quantity; self.unit = unit; self.frame = frame
      self.coordinatePrefix = coordinatePrefix; self.requiredValidityMask = requiredValidityMask
    }
  }
  public let formatVersion: UInt32
  public let nativeModelSourceFingerprint: UInt64
  public let compiledSpeciesTemplateFingerprint: UInt64
  public let modality: SensoryModality
  public let receptorCount: UInt32
  public let featureDimension: UInt32
  public let ownerSchemaRevision: String
  public let fields: [Field]

  public func validate() throws {
    guard formatVersion == 2, nativeModelSourceFingerprint > 0,
      compiledSpeciesTemplateFingerprint > 0, receptorCount > 0,
      featureDimension > 0, featureDimension <= 65_536,
      !ownerSchemaRevision.isEmpty, !fields.isEmpty,
      fields.count <= Int(featureDimension), Set(fields.map(\.index)).count == fields.count,
      fields.allSatisfy({ field in field.index < featureDimension
        && field.requiredValidityMask != nil && field.requiredValidityMask! != 0
        && [field.quantity, field.unit, field.frame, field.coordinatePrefix].allSatisfy {
          !$0.isEmpty && $0.utf8.count <= 256
        }
      }) else { throw PhysicalValidationError.invalid("sensor schema needs explicit field validity and reviewed v2 semantics") }
  }
}

public struct BrainGateDSensorTraceArtifact: Codable, Equatable, Sendable {
  public let formatVersion: UInt32
  public let observationPhase: String
  public let runArtifactSHA256: String
  public let runEvidenceSHA256: String
  public let datasetSourceRevision: String
  public let acceptedStateProofProgramFingerprint: UInt64
  public let sensorSchemaSHA256: String
  public let receptorIndex: UInt32
  public let featureIndex: UInt32
  public let sourceRevision: String
  public let nativeModelSourceFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  public let acceptedRootCount: UInt64
  public let rejectedRootCount: UInt64
  public let acceptedSampleSHA256: [String]
  public let trace: PhysicalTrace
}

public struct BrainGateDReferenceTraceArtifact: Codable, Equatable, Sendable {
  public let formatVersion: UInt32
  public let sourceSHA256: String
  public let importSpecificationSHA256: String
  public let trace: PhysicalTrace
}

public struct BrainGateDTraceProtocol: Codable, Equatable, Sendable {
  public enum ReferenceKind: String, Codable, Sendable { case experimental, independentModel, analytic }
  public let formatVersion: UInt32
  public let identifier: String
  public let expectedRuntimeSourceRevision: String
  public let expectedNativeModelSourceFingerprint: UInt64
  public let expectedParameterVersionFingerprint: UInt64
  public let expectedAcceptedStateProofProgramFingerprint: UInt64
  public let sensorSchemaSHA256: String
  public let receptorIndex: UInt32
  public let featureIndex: UInt32
  public let referenceKind: ReferenceKind
  public let referenceTraceSHA256: String
  public let referenceSourceSHA256: String
  public let referenceSourceURI: String
  public let referenceSourceRevision: String
  public let referenceLicense: String
  public let referenceProcessingRevision: String
  public let referenceImportSpecificationSHA256: String
  public let calibrationArtifactSHA256: [String]
  public let minimumAcceptedRootCount: UInt64
  public let maximumRejectedRootFraction: Double
  public let comparison: PhysicalTraceComparisonPlan

  public func validate() throws {
    let hashes = [sensorSchemaSHA256, referenceTraceSHA256, referenceSourceSHA256,
      referenceImportSpecificationSHA256] + calibrationArtifactSHA256
    guard formatVersion == 1, !identifier.isEmpty, !expectedRuntimeSourceRevision.isEmpty,
      expectedNativeModelSourceFingerprint > 0, expectedParameterVersionFingerprint > 0,
      expectedAcceptedStateProofProgramFingerprint > 0,
      hashes.allSatisfy(BrainPolicyEvidenceArtifact.isSHA256),
      calibrationArtifactSHA256.count <= 100_000,
      Set(calibrationArtifactSHA256).count == calibrationArtifactSHA256.count,
      !calibrationArtifactSHA256.contains(referenceTraceSHA256),
      !calibrationArtifactSHA256.contains(referenceSourceSHA256),
      let uri = URL(string: referenceSourceURI),
      (uri.scheme == "https" && uri.host != nil) || uri.scheme == "urn",
      [referenceSourceRevision, referenceLicense, referenceProcessingRevision].allSatisfy({ !$0.isEmpty }),
      minimumAcceptedRootCount >= 2,
      maximumRejectedRootFraction.isFinite, (0...1).contains(maximumRejectedRootFraction)
    else { throw PhysicalValidationError.invalid("invalid Gate D trace protocol or calibration overlap") }
    try comparison.validate()
  }
}

public struct BrainGateDTraceEvaluationArtifact: Codable, Equatable, Sendable {
  public let formatVersion: UInt32
  public let promotable: Bool
  public let protocolSHA256: String
  public let candidateSHA256: String
  public let referenceSHA256: String
  public let evidenceSHA256: String
  public let comparison: PhysicalTraceComparison
  public let result: PhysicalValidationResult
}

/// Read-only adaptation of retained native captures. SHA-256 binds source
/// integrity, not independent biology, clinical validity or host authenticity.
public enum BrainGateDEvidence {
  public static func retain(_ bytes: Data, artifactDirectory: URL) throws -> String {
    guard !bytes.isEmpty, bytes.count <= 256 * 1024 * 1024 else {
      throw PhysicalValidationError.invalid("Gate D artifact exceeds bounded size")
    }
    return try BrainPolicyEvidenceArtifact.write(bytes, to: artifactDirectory)
  }
  public static func retain<T: Encodable>(_ value: T, artifactDirectory: URL) throws -> String {
    try retain(BrainPolicyEvidenceArtifact.encodeCanonical(value), artifactDirectory: artifactDirectory)
  }
  public static func read<T: Decodable>(_ type: T.Type, sha256: String, artifactDirectory: URL) throws -> T {
    try JSONDecoder().decode(type, from: BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: sha256, directory: artifactDirectory))
  }
  public static func exportReferenceTrace(sourceSHA256: String, importSpecificationSHA256: String,
    artifactDirectory: URL) throws -> BrainGateDReferenceTraceArtifact {
    let specification = try read(PhysicalReferenceImport.self, sha256: importSpecificationSHA256, artifactDirectory: artifactDirectory)
    let source = try BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: sourceSHA256, directory: artifactDirectory)
    return BrainGateDReferenceTraceArtifact(formatVersion: 1, sourceSHA256: sourceSHA256,
      importSpecificationSHA256: importSpecificationSHA256, trace: try specification.decode(source))
  }
  public static func verifyReferenceTrace(sha256: String, artifactDirectory: URL) throws -> BrainGateDReferenceTraceArtifact {
    let artifact = try read(BrainGateDReferenceTraceArtifact.self, sha256: sha256, artifactDirectory: artifactDirectory)
    let rebuilt = try exportReferenceTrace(sourceSHA256: artifact.sourceSHA256,
      importSpecificationSHA256: artifact.importSpecificationSHA256, artifactDirectory: artifactDirectory)
    guard artifact == rebuilt else { throw PhysicalValidationError.invalid("reference trace differs from retained source/import") }
    return rebuilt
  }

  public static func exportSensorTrace(runSHA256: String, schemaSHA256: String, receptorIndex: UInt32,
    featureIndex: UInt32, artifactDirectory: URL) throws -> BrainGateDSensorTraceArtifact {
    let receipt = try BrainPolicyNumanXCaptureVerifier.verify(runArtifactSHA256: runSHA256, artifactDirectory: artifactDirectory)
    let run = try BrainPolicyNumanXCaptureRunArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: runSHA256, directory: artifactDirectory))
    let schema = try read(BrainGateDSensorSchema.self, sha256: schemaSHA256, artifactDirectory: artifactDirectory)
    try schema.validate()
    guard schema.nativeModelSourceFingerprint == run.nativeModelSourceFingerprint,
      schema.compiledSpeciesTemplateFingerprint == run.compiledSpeciesTemplateFingerprint,
      receptorIndex < schema.receptorCount, let field = schema.fields.first(where: { $0.index == featureIndex }),
      let requiredMask = field.requiredValidityMask,
      receipt.acceptedRootCount >= 2, run.roots.count <= 1_048_576 else {
      throw PhysicalValidationError.invalid("sensor schema does not bind captured native model/layout")
    }
    var times: [UInt64] = [], values: [Double] = [], validity: [Bool] = [], samples: [String] = []
    var firstCoordinates: BrainPolicyNumanXDatasetCoordinates?, sensoryProfile: UInt64?
    var lastValuesHash: String?, lastValidityHash: String?
    var previousCommittedTime: UInt64?, previousGeneration: UInt64?, previousTarget: UInt64?
    var previousOutcome: BrainPolicyNumanXRootOutcome?
    for root in run.roots {
      let execution = try BrainPolicyNumanXRootExecution.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: root.executionSHA256, directory: artifactDirectory))
      let sample = try BrainPolicyNumanXRootSampleArtifact.decode(
        BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: root.sampleSHA256, directory: artifactDirectory))
      guard sample.speciesTemplateFingerprint == schema.compiledSpeciesTemplateFingerprint,
        firstCoordinates == nil || firstCoordinates == sample.coordinates,
        sensoryProfile == nil || sensoryProfile == sample.sensoryProfileFingerprint else {
        throw PhysicalValidationError.invalid("trace crosses an episode, scene, body, or sensory-program boundary")
      }
      firstCoordinates = sample.coordinates; sensoryProfile = sample.sensoryProfileFingerprint
      if let lastTime = previousCommittedTime, let lastGeneration = previousGeneration,
        let lastTarget = previousTarget, let lastOutcome = previousOutcome {
        let (expectedGeneration, overflow) = lastGeneration.addingReportingOverflow(lastOutcome == .accepted ? 1 : 0)
        guard !overflow, sample.basePhysicsGeneration == expectedGeneration,
          sample.committedTimestampMicroseconds == (lastOutcome == .accepted ? lastTarget : lastTime) else {
          throw PhysicalValidationError.invalid("capture root history is discontinuous")
        }
      }
      previousCommittedTime = sample.committedTimestampMicroseconds; previousGeneration = sample.basePhysicsGeneration
      previousTarget = sample.targetTimestampMicroseconds; previousOutcome = execution.outcome
      guard execution.outcome == .accepted else { continue }
      guard let channel = sample.channels.first(where: { $0.modality == schema.modality }),
        channel.receptorCount == schema.receptorCount, channel.featureDimension == schema.featureDimension,
        channel.receptorTimestampMicroseconds <= sample.committedTimestampMicroseconds,
        let validityHash = channel.validitySHA256 else {
        throw PhysicalValidationError.invalid("missing validity or incompatible/future-dated sensor channel")
      }
      let decoded = try PhysicalSensorField.decode(
        values: BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: channel.valuesSHA256, directory: artifactDirectory),
        validity: BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: validityHash, directory: artifactDirectory),
        receptorCount: channel.receptorCount, featureDimension: channel.featureDimension,
        receptorIndex: receptorIndex, featureIndex: featureIndex, requiredValidityMask: requiredMask)
      let value = decoded.value, valid = decoded.valid
      samples.append(root.sampleSHA256)
      let time = channel.receptorTimestampMicroseconds
      if let last = times.last {
        guard time >= last else { throw PhysicalValidationError.invalid("receptor clock moved backward") }
        if time == last {
          guard lastValuesHash == channel.valuesSHA256, lastValidityHash == channel.validitySHA256,
            values.last == value, validity.last == valid else {
            throw PhysicalValidationError.invalid("different contents share one receptor timestamp")
          }
          continue
        }
      }
      times.append(time); values.append(value); validity.append(valid)
      lastValuesHash = channel.valuesSHA256; lastValidityHash = channel.validitySHA256
    }
    let trace = try PhysicalTrace(quantity: field.quantity, unit: field.unit, frame: field.frame,
      coordinate: field.coordinatePrefix + String(receptorIndex), timestampsMicroseconds: times, values: values, validity: validity)
    return BrainGateDSensorTraceArtifact(formatVersion: 1, observationPhase: "settled-input-before-accepted-root",
      runArtifactSHA256: runSHA256, runEvidenceSHA256: receipt.transitiveEvidenceSHA256,
      datasetSourceRevision: run.datasetSourceRevision,
      acceptedStateProofProgramFingerprint: run.acceptedStateProofProgramFingerprint,
      sensorSchemaSHA256: schemaSHA256, receptorIndex: receptorIndex, featureIndex: featureIndex,
      sourceRevision: run.sourceRevision, nativeModelSourceFingerprint: run.nativeModelSourceFingerprint,
      parameterVersionFingerprint: run.parameterVersionFingerprint, acceptedRootCount: receipt.acceptedRootCount,
      rejectedRootCount: receipt.rejectedRootCount, acceptedSampleSHA256: samples, trace: trace)
  }

  public static func verifySensorTrace(sha256: String, artifactDirectory: URL) throws -> BrainGateDSensorTraceArtifact {
    let artifact = try read(BrainGateDSensorTraceArtifact.self, sha256: sha256, artifactDirectory: artifactDirectory)
    let rebuilt = try exportSensorTrace(runSHA256: artifact.runArtifactSHA256, schemaSHA256: artifact.sensorSchemaSHA256,
      receptorIndex: artifact.receptorIndex, featureIndex: artifact.featureIndex, artifactDirectory: artifactDirectory)
    guard artifact == rebuilt else { throw PhysicalValidationError.invalid("sensor trace differs from retained source graph") }
    return rebuilt
  }

  public static func evaluateTrace(protocolSHA256: String, candidateSHA256: String,
    artifactDirectory: URL) throws -> BrainGateDTraceEvaluationArtifact {
    let contract = try read(BrainGateDTraceProtocol.self, sha256: protocolSHA256, artifactDirectory: artifactDirectory)
    try contract.validate()
    let candidate = try verifySensorTrace(sha256: candidateSHA256, artifactDirectory: artifactDirectory)
    guard candidate.datasetSourceRevision == protocolSHA256,
      candidate.acceptedStateProofProgramFingerprint == contract.expectedAcceptedStateProofProgramFingerprint,
      candidate.sourceRevision == contract.expectedRuntimeSourceRevision,
      candidate.nativeModelSourceFingerprint == contract.expectedNativeModelSourceFingerprint,
      candidate.parameterVersionFingerprint == contract.expectedParameterVersionFingerprint,
      candidate.sensorSchemaSHA256 == contract.sensorSchemaSHA256,
      candidate.receptorIndex == contract.receptorIndex, candidate.featureIndex == contract.featureIndex else {
      throw PhysicalValidationError.invalid("candidate differs from frozen trace protocol")
    }
    let reference = try verifyReferenceTrace(sha256: contract.referenceTraceSHA256, artifactDirectory: artifactDirectory)
    guard reference.sourceSHA256 == contract.referenceSourceSHA256,
      reference.importSpecificationSHA256 == contract.referenceImportSpecificationSHA256 else {
      throw PhysicalValidationError.invalid("reference source/import differs from frozen protocol")
    }
    for hash in contract.calibrationArtifactSHA256 {
      _ = try BrainPolicyNumanXCaptureVerifier.verifiedData(sha256: hash, directory: artifactDirectory)
    }
    let comparison = try PhysicalTraceValidation.compare(candidate: candidate.trace, reference: reference.trace, plan: contract.comparison)
    let attempted = Double(candidate.acceptedRootCount) + Double(candidate.rejectedRootCount)
    let rejectedFraction = Double(candidate.rejectedRootCount) / attempted
    let shortfall = candidate.acceptedRootCount >= contract.minimumAcceptedRootCount ? 0 : contract.minimumAcceptedRootCount - candidate.acceptedRootCount
    let result = try PhysicalValidationResult(metrics: comparison.result.metrics + [
      PhysicalValidationMetric(name: "rejected_root_fraction", residual: rejectedFraction, tolerance: contract.maximumRejectedRootFraction),
      PhysicalValidationMetric(name: "accepted_root_shortfall", residual: Double(shortfall), tolerance: 0),
    ], notes: ["reference provenance and sensor semantics are owner-declared; hashes establish integrity, not independent biological validity"])
    let hashes = ([protocolSHA256, candidateSHA256, candidate.runEvidenceSHA256, contract.sensorSchemaSHA256,
      contract.referenceTraceSHA256, contract.referenceSourceSHA256, contract.referenceImportSpecificationSHA256] + contract.calibrationArtifactSHA256).sorted()
    let evidenceHash = BrainPolicyEvidenceArtifact.sha256(try BrainPolicyEvidenceArtifact.encodeCanonical(hashes))
    return BrainGateDTraceEvaluationArtifact(formatVersion: 1, promotable: false,
      protocolSHA256: protocolSHA256, candidateSHA256: candidateSHA256, referenceSHA256: contract.referenceTraceSHA256,
      evidenceSHA256: evidenceHash, comparison: comparison, result: result)
  }

  public static func verifyTraceEvaluation(sha256: String, artifactDirectory: URL) throws -> BrainGateDTraceEvaluationArtifact {
    let artifact = try read(BrainGateDTraceEvaluationArtifact.self, sha256: sha256, artifactDirectory: artifactDirectory)
    let rebuilt = try evaluateTrace(protocolSHA256: artifact.protocolSHA256, candidateSHA256: artifact.candidateSHA256, artifactDirectory: artifactDirectory)
    guard artifact == rebuilt else { throw PhysicalValidationError.invalid("trace evaluation metrics or evidence identity were modified") }
    return rebuilt
  }
}

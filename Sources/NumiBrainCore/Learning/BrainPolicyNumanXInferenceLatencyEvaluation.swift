import Foundation

@frozen
public struct BrainPolicyNumanXInferenceLatencyObservation:
  Codable, Equatable, Sendable
{
  public let sampleSHA256: String
  public let controlStep: UInt32
  public let gpuDurationMicroseconds: Double

  public init(
    sampleSHA256: String,
    controlStep: UInt32,
    gpuDurationMicroseconds: Double
  ) throws {
    guard BrainPolicyEvidenceArtifact.isSHA256(sampleSHA256), controlStep > 0,
      gpuDurationMicroseconds.isFinite, gpuDurationMicroseconds > 0
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX inference-latency observation is invalid"
      )
    }
    self.sampleSHA256 = sampleSHA256
    self.controlStep = controlStep
    self.gpuDurationMicroseconds = gpuDurationMicroseconds
  }
}

/// A retained latency-axis evaluation from Metal 4 command feedback. Host
/// submission time, physical execution, and later publication are excluded;
/// every observation measures the exact receptor-to-decision command buffer
/// that produced one terminal authoritative root.
@frozen
public struct BrainPolicyNumanXInferenceLatencyEvaluationArtifact:
  Codable, Equatable, Sendable
{
  public static let formatVersion: UInt32 = 1
  public static let minimumObservationCount = 100

  public let formatVersion: UInt32
  public let candidateArtifactSHA256: String
  public let captureRunArtifactSHA256: String
  public let axis: BrainPolicyQualificationAxis
  public let maximumInferenceLatencyMicroseconds: UInt64
  public let observations: [BrainPolicyNumanXInferenceLatencyObservation]
  public let percentile99Microseconds: Double
  public let passesDeclaredBudget: Bool
  public let promotable: Bool

  public init(
    candidateArtifactSHA256: String,
    captureRunArtifactSHA256: String,
    maximumInferenceLatencyMicroseconds: UInt64,
    observations: [BrainPolicyNumanXInferenceLatencyObservation]
  ) throws {
    let canonical = observations.sorted { $0.controlStep < $1.controlStep }
    guard BrainPolicyEvidenceArtifact.isSHA256(candidateArtifactSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(captureRunArtifactSHA256),
      maximumInferenceLatencyMicroseconds > 0,
      canonical.count >= Self.minimumObservationCount,
      canonical.map(\.controlStep)
        == Array(UInt32(1)...UInt32(canonical.count)),
      Set(canonical.map(\.sampleSHA256)).count == canonical.count
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX inference-latency evaluation artifact is invalid"
      )
    }
    let sortedDurations = canonical.map(\.gpuDurationMicroseconds).sorted()
    let rank = Int(ceil(Double(sortedDurations.count) * 0.99)) - 1
    let percentile99 = sortedDurations[
      max(0, min(rank, sortedDurations.count - 1))
    ]
    self.formatVersion = Self.formatVersion
    self.candidateArtifactSHA256 = candidateArtifactSHA256
    self.captureRunArtifactSHA256 = captureRunArtifactSHA256
    self.axis = .actionGenerationLatency
    self.maximumInferenceLatencyMicroseconds =
      maximumInferenceLatencyMicroseconds
    self.observations = canonical
    self.percentile99Microseconds = percentile99
    self.passesDeclaredBudget = percentile99
      <= Double(maximumInferenceLatencyMicroseconds)
    self.promotable = false
  }

  public var metricEvidence: BrainPolicyQualificationMetricEvidence {
    get throws {
      try BrainPolicyQualificationMetricEvidence(
        identifier: "inference_latency_p99",
        unit: "microseconds",
        reducer: .percentile99,
        threshold: Double(maximumInferenceLatencyMicroseconds),
        direction: .atMost,
        observations: try observations.map {
          try BrainPolicyMetricObservation(
            sampleSHA256: $0.sampleSHA256,
            value: $0.gpuDurationMicroseconds
          )
        }
      )
    }
  }

  public func encoded() throws -> Data {
    try validate()
    return try BrainPolicyEvidenceArtifact.encodeCanonical(self)
  }

  @discardableResult
  public func write(to artifactDirectory: URL) throws -> String {
    try BrainPolicyEvidenceArtifact.write(encoded(), to: artifactDirectory)
  }

  public static func decode(_ data: Data) throws -> Self {
    let artifact = try JSONDecoder().decode(Self.self, from: data)
    try artifact.validate()
    return artifact
  }

  public func validate() throws {
    guard formatVersion == Self.formatVersion,
      axis == .actionGenerationLatency, !promotable,
      try Self(
        candidateArtifactSHA256: candidateArtifactSHA256,
        captureRunArtifactSHA256: captureRunArtifactSHA256,
        maximumInferenceLatencyMicroseconds:
          maximumInferenceLatencyMicroseconds,
        observations: observations
      ) == self,
      try metricEvidence.reducedValue == percentile99Microseconds
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX inference-latency evaluation artifact is not canonical"
      )
    }
  }
}

public struct BrainPolicyNumanXInferenceLatencyEvaluationReceipt: Sendable {
  public let evaluationArtifactSHA256: String
  public let candidateArtifactSHA256: String
  public let captureRunArtifactSHA256: String
  public let observationCount: UInt64
  public let percentile99Microseconds: Double
  public let maximumInferenceLatencyMicroseconds: UInt64
  public let passesDeclaredBudget: Bool
  public let transitiveEvidenceSHA256: String
}

public enum BrainPolicyNumanXInferenceLatencyEvaluator {
  public static func evaluateAndWrite(
    candidateArtifactSHA256: String,
    captureRunArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXInferenceLatencyEvaluationReceipt {
    try evaluate(
      candidateArtifactSHA256: candidateArtifactSHA256,
      captureRunArtifactSHA256: captureRunArtifactSHA256,
      artifactDirectory: artifactDirectory,
      writeArtifact: true
    )
  }

  public static func verify(
    evaluationArtifactSHA256: String,
    artifactDirectory: URL
  ) throws -> BrainPolicyNumanXInferenceLatencyEvaluationReceipt {
    let stored = try BrainPolicyNumanXInferenceLatencyEvaluationArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: evaluationArtifactSHA256,
        directory: artifactDirectory
      )
    )
    let receipt = try evaluate(
      candidateArtifactSHA256: stored.candidateArtifactSHA256,
      captureRunArtifactSHA256: stored.captureRunArtifactSHA256,
      artifactDirectory: artifactDirectory,
      writeArtifact: false
    )
    guard receipt.evaluationArtifactSHA256 == evaluationArtifactSHA256 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX inference-latency evaluation does not recompute byte-identically"
      )
    }
    return receipt
  }

  private static func evaluate(
    candidateArtifactSHA256: String,
    captureRunArtifactSHA256: String,
    artifactDirectory: URL,
    writeArtifact: Bool
  ) throws -> BrainPolicyNumanXInferenceLatencyEvaluationReceipt {
    let candidateReceipt = try BrainPolicyNumanXLearnedCandidateVerifier.verify(
      candidateArtifactSHA256: candidateArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let candidate = try BrainPolicyNumanXLearnedCandidateVerifier
      .verifiedCandidate(
        candidateArtifactSHA256: candidateArtifactSHA256,
        artifactDirectory: artifactDirectory
      )
    let runReceipt = try BrainPolicyNumanXCaptureVerifier.verify(
      runArtifactSHA256: captureRunArtifactSHA256,
      artifactDirectory: artifactDirectory
    )
    let run = try BrainPolicyNumanXCaptureRunArtifact.decode(
      BrainPolicyNumanXCaptureVerifier.verifiedData(
        sha256: captureRunArtifactSHA256,
        directory: artifactDirectory
      )
    )
    guard run.parameterVersionFingerprint
        == candidate.learnerUpdate.candidateVersion.fingerprint,
      run.timestepMicroseconds != nil,
      run.declaredMaximumInferenceLatencyMicroseconds != nil,
      run.roots.count >=
        BrainPolicyNumanXInferenceLatencyEvaluationArtifact
          .minimumObservationCount
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "NumanX inference-latency run does not bind the learned candidate"
      )
    }
    let maximumInferenceLatencyMicroseconds =
      run.declaredMaximumInferenceLatencyMicroseconds!
    let observations = try run.roots.map { root in
      guard let latency = root.inferenceLatencyMicroseconds else {
        throw BrainRuntimeError.invalidParameterVersion(
          "NumanX inference-latency run lacks Metal command feedback"
        )
      }
      return try BrainPolicyNumanXInferenceLatencyObservation(
        sampleSHA256: root.sampleSHA256,
        controlStep: root.controlStep,
        gpuDurationMicroseconds: latency
      )
    }
    let artifact = try BrainPolicyNumanXInferenceLatencyEvaluationArtifact(
      candidateArtifactSHA256: candidateArtifactSHA256,
      captureRunArtifactSHA256: captureRunArtifactSHA256,
      maximumInferenceLatencyMicroseconds:
        maximumInferenceLatencyMicroseconds,
      observations: observations
    )
    let artifactHash = if writeArtifact {
      try artifact.write(to: artifactDirectory)
    } else {
      BrainPolicyEvidenceArtifact.sha256(try artifact.encoded())
    }
    var transitive = Data()
    for hash in [
      artifactHash,
      candidateArtifactSHA256,
      captureRunArtifactSHA256,
      candidateReceipt.transitiveEvidenceSHA256,
      runReceipt.transitiveEvidenceSHA256,
    ].sorted() {
      transitive.append(Data(hash.utf8))
    }
    return BrainPolicyNumanXInferenceLatencyEvaluationReceipt(
      evaluationArtifactSHA256: artifactHash,
      candidateArtifactSHA256: candidateArtifactSHA256,
      captureRunArtifactSHA256: captureRunArtifactSHA256,
      observationCount: UInt64(observations.count),
      percentile99Microseconds: artifact.percentile99Microseconds,
      maximumInferenceLatencyMicroseconds:
        maximumInferenceLatencyMicroseconds,
      passesDeclaredBudget: artifact.passesDeclaredBudget,
      transitiveEvidenceSHA256: BrainPolicyEvidenceArtifact.sha256(transitive)
    )
  }
}

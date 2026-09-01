import Darwin
import Foundation
import Metal
import NumiBrainCore
@_spi(NumanXInterop) import NumiBrainMetal
import NumiBrainMLX

private let qualifiedGateCTimestepMicroseconds: UInt32 = 100

private struct CaptureRootSummary: Codable {
  let controlStep: UInt32
  let outcome: BrainPolicyNumanXRootOutcome
  let sampleSHA256: String
  let executionSHA256: String
  let brainGeneration: UInt64
  let physicsGeneration: UInt64
  let sensorGeneration: UInt64
  let inferenceLatencyMicroseconds: Double
  let brainPreflightReady: Bool
  let proposalCode: UInt32
  let appliedCode: UInt32
  let nativePhysicalDiagnosticStage: UInt32
  let uncertaintyScore: Float?
  let supervisionRequired: Bool?
  let uncertaintyRootRejected: Bool?
  let protectiveBypass: Bool?
  let safetyViolation: Bool?
  let learnedDescendingPeak: Float?
}

private struct CaptureSummary: Codable {
  let formatVersion: UInt32
  let runIdentifier: String
  let runArtifactSHA256: String
  let artifactDirectory: String
  let datasetSourceIdentifier: String
  let datasetSourceRevision: String
  let sourceRevision: String
  let promotable: Bool
  let deviceName: String
  let deviceRegistryID: UInt64
  let bodyCount: UInt32
  let qCoordinateCount: UInt32
  let dofCount: UInt32
  let muscleCount: UInt32
  let roots: [CaptureRootSummary]
  let learnerConfigurationSHA256: String?
  let headPostureLearningArtifactSHA256: String?
  let learnedCandidateSHA256: String?
  let modelWeightsSHA256: String?
  let learnerUpdateFingerprint: UInt64?
  let adaptationTrainingArtifactSHA256: String?
  let adaptationExampleCount: UInt32?
  let adaptationWallClockSeconds: Double?
}

private struct VerificationSummary: Codable {
  let runArtifactSHA256: String
  let rootCount: UInt64
  let acceptedRootCount: UInt64
  let rejectedRootCount: UInt64
  let transitiveEvidenceSHA256: String
}

private struct LongHorizonProtocolSummary: Codable {
  let formatVersion: UInt32
  let protocolArtifactSHA256: String
  let protocolIdentifier: String
  let candidateArtifactSHA256: String
  let axis: BrainPolicyQualificationAxis
  let cohortCount: UInt32
  let rootsPerCohort: UInt32
  let totalRootCount: UInt32
  let promotable: Bool
}

private struct LongHorizonEvaluationSummary: Codable {
  let formatVersion: UInt32
  let evaluationArtifactSHA256: String
  let candidateArtifactSHA256: String
  let protocolArtifactSHA256: String
  let captureRunArtifactSHA256: String
  let axis: BrainPolicyQualificationAxis
  let cohortCount: UInt64
  let successfulCohortCount: UInt64
  let successRate: Double
  let passesPredeclaredThresholds: Bool
  let transitiveEvidenceSHA256: String
  let promotable: Bool
}

private struct CandidateVerificationSummary: Codable {
  let candidateArtifactSHA256: String
  let captureRunArtifactSHA256: String
  let modelWeightsSHA256: String
  let learnerUpdateFingerprint: UInt64
  let transitiveEvidenceSHA256: String
}

private struct SupportEvaluationSummary: Codable {
  let formatVersion: UInt32
  let evaluationArtifactSHA256: String
  let candidateArtifactSHA256: String
  let contactVariantArtifactSHA256: String
  let contactVariantAssetSHA256: String
  let baselineRunArtifactSHA256: String
  let learnedRunArtifactSHA256: String
  let baselineObservationCount: UInt64
  let learnedObservationCount: UInt64
  let observationCount: UInt64
  let baselineSuccessRate: Double
  let learnedSuccessRate: Double
  let learnedMinusBaselineSuccessRate: Double
  let transitiveEvidenceSHA256: String
  let promotable: Bool
}

private struct HeadPostureEvaluationSummary: Codable {
  let formatVersion: UInt32
  let evaluationArtifactSHA256: String
  let candidateArtifactSHA256: String
  let baselineRunArtifactSHA256: String
  let candidateRunArtifactSHA256: String
  let targetBodyIdentifier: UInt32
  let baselineLiftMeters: Float
  let candidateLiftMeters: Float
  let candidateMinusBaselineLiftMeters: Float
  let minimumLiftAdvantageMeters: Float
  let succeeds: Bool
  let transitiveEvidenceSHA256: String
  let promotable: Bool
}

private struct SupportReplaySummary: Codable {
  let formatVersion: UInt32
  let replayArtifactSHA256: String
  let referenceEvaluationArtifactSHA256: String
  let replayEvaluationArtifactSHA256: String
  let baselineRootCount: UInt64
  let learnedRootCount: UInt64
  let transactionUniqueIdentityDifferenceCount: UInt64
  let exactSemanticReplay: Bool
  let transitiveEvidenceSHA256: String
  let promotable: Bool
}

private struct InferenceLatencySummary: Codable {
  let formatVersion: UInt32
  let evaluationArtifactSHA256: String
  let candidateArtifactSHA256: String
  let captureRunArtifactSHA256: String
  let observationCount: UInt64
  let percentile99Microseconds: Double
  let maximumInferenceLatencyMicroseconds: UInt64
  let passesDeclaredBudget: Bool
  let transitiveEvidenceSHA256: String
  let promotable: Bool
}

private struct OODEvaluationSummary: Codable {
  let formatVersion: UInt32
  let evaluationArtifactSHA256: String
  let candidateArtifactSHA256: String
  let captureRunArtifactSHA256: String
  let observationCount: UInt64
  let auroc: Double
  let supervisionOrRejectRecall: Double
  let unsafeAcceptRate: Double
  let passesPredeclaredThresholds: Bool
  let transitiveEvidenceSHA256: String
  let promotable: Bool
}

private struct HardSafetyEvaluationSummary: Codable {
  let formatVersion: UInt32
  let evaluationArtifactSHA256: String
  let candidateArtifactSHA256: String
  let captureRunArtifactSHA256: String
  let observationCount: UInt64
  let rejectedRootCount: UInt64
  let protectiveBypassCount: Double
  let safetyViolationRate: Double
  let maximumLearnedDescendingPeak: Double
  let passesPredeclaredThresholds: Bool
  let transitiveEvidenceSHA256: String
  let promotable: Bool
}

private struct FewShotEvaluationSummary: Codable {
  let formatVersion: UInt32
  let evaluationArtifactSHA256: String
  let trainingArtifactSHA256: String
  let parentCandidateArtifactSHA256: String
  let adaptedCandidateArtifactSHA256: String
  let adaptationExampleCount: UInt32
  let adaptationWallClockSeconds: Double
  let preAdaptationSuccessRate: Double
  let postAdaptationSuccessRate: Double
  let retainedPriorSuccessRate: Double
  let postMinusPreAdaptationSuccessRate: Double
  let passesPredeclaredThresholds: Bool
  let demonstratesPositiveAdaptation: Bool
  let transitiveEvidenceSHA256: String
  let promotable: Bool
}

private func usage(_ message: String? = nil) -> Never {
  if let message {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(message)\n".utf8))
  }
  FileHandle.standardError.write(Data("""
    usage: numi-brain-gate-c <capture|capture-train> \\
      --library PATH --rigid PATH --muscle PATH --contacts PATH \\
      --visual-pack PATH --vision-profile PATH \\
      --metalrobo-metallib PATH --matter-metallib PATH --material PATH \\
      --artifact-dir DIR --run-id ID --source-revision REV \\
      --dataset-id ID --dataset-revision REV --episode N --seed N --roots N \\
      --task-fp HEX --scene-fp HEX --object-fp HEX --embodiment-fp HEX \
      [--timestep-microseconds N]

    capture-train additionally requires --learning-rate FLOAT and at least
    three roots. It emits one deterministic, immutable, non-promotable MLX
    successor candidate tied to the capture run. --head-posture-weight enables
    accepted 100-root body-23 response supervision with
    --goal head-posture-lift-v1. Delayed-support learning is fail-closed until
    constrained Human/Matter contact authority is available.
    The full-body Gate C default is 100 microseconds. Larger explicitly named
    timesteps remain diagnostic inputs rather than qualified defaults.
    --head-posture-calibration-sha may name one verified exploratory response
    evaluation to calibrate the plant-gradient sign; it is training-only,
    requires --head-posture-weight, and its absolute paired response must clear
    the evaluation's predeclared physical-resolution threshold.

    usage: numi-brain-gate-c verify --artifact-dir DIR --run-sha SHA256
    usage: numi-brain-gate-c verify-candidate \\
      --artifact-dir DIR --candidate-sha SHA256

    create-long-horizon-protocol and verify-long-horizon-protocol freeze and
    verify one candidate, axis, fixed cohort schedule, physical coordinates,
    and support thresholds before authoritative outcomes are captured.

    evaluate-long-horizon and verify-long-horizon recompute the exact
    identity-free sensor/action, complete committed-memory, terminal owner,
    and support relations for every predeclared cohort.

    compare-support-replay and verify-support-replay retain and recompute the
    semantic replay relation between two independently executed evaluations.

    evaluate-latency and verify-latency retain and recompute Metal-feedback
    p99 for at least 100 authoritative roots captured with --candidate-sha and
    a predeclared --maximum-inference-latency-microseconds budget.

    evaluate-ood and verify-ood retain and recompute the predeclared AUROC,
    supervision-or-reject recall, and unsafe-accept metrics from at least 20
    authoritative roots in each predeclared class.

    evaluate-hard-safety and verify-hard-safety retain and recompute exact
    same-root protective bypass and safety-violation metrics from at least 20
    authoritative emergency-stop challenges, including a rejected root.

    evaluate-few-shot and verify-few-shot bind one measured parent-to-successor
    update to disjoint pre/post adaptation and retained-prior physical cohorts.

    evaluate-support is retained for artifact compatibility but fails closed
    while Human/Matter ABI v1 uses unconstrained A0 dynamics. Diagnostic
    support captures remain non-promotable negative evidence.

    evaluate-head-posture and verify-head-posture retain and recompute a
    matched parent/candidate head-relative lift response on body 23. Training
    and evaluation scenes must be disjoint and each run requires 100 roots.

    The capture output is retained authoritative root data, but is always
    marked non-promotable. Gate C promotion requires separately frozen,
    disjoint partitions and complete metric evidence.
    """.utf8))
  exit(64)
}

private func parseOptions(_ arguments: ArraySlice<String>) -> [String: String] {
  var result: [String: String] = [:]
  var index = arguments.startIndex
  while index < arguments.endIndex {
    let key = arguments[index]
    guard key.hasPrefix("--") else { usage("unexpected argument \(key)") }
    let valueIndex = arguments.index(after: index)
    guard valueIndex < arguments.endIndex,
      !arguments[valueIndex].hasPrefix("--"),
      result[key] == nil
    else {
      usage("missing value or duplicate option \(key)")
    }
    result[key] = arguments[valueIndex]
    index = arguments.index(after: valueIndex)
  }
  return result
}

private func required(_ key: String, in options: [String: String]) -> String {
  guard let value = options[key], !value.isEmpty else {
    usage("missing \(key)")
  }
  return value
}

private func decimal<T: FixedWidthInteger>(
  _ key: String,
  in options: [String: String],
  as type: T.Type = T.self
) -> T {
  let value = required(key, in: options)
  guard let parsed = T(value), parsed > 0 else {
    usage("\(key) must be a positive integer")
  }
  return parsed
}

private func optionalDecimal<T: FixedWidthInteger>(
  _ key: String,
  in options: [String: String],
  default defaultValue: T,
  as type: T.Type = T.self
) -> T {
  guard options[key] != nil else { return defaultValue }
  return decimal(key, in: options, as: type)
}

private func fingerprint(_ key: String, in options: [String: String]) -> UInt64 {
  var value = required(key, in: options).lowercased()
  if value.hasPrefix("0x") { value.removeFirst(2) }
  guard let parsed = UInt64(value, radix: 16), parsed > 0 else {
    usage("\(key) must be a nonzero hexadecimal UInt64")
  }
  return parsed
}

private func longHorizonAxis(
  _ value: String
) -> BrainPolicyQualificationAxis {
  switch value {
  case "delayed-consequences": .delayedConsequences
  case "interrupted-tasks": .interruptedTasks
  case "state-aliasing": .stateAliasing
  default:
    usage(
      "--axis must be delayed-consequences, interrupted-tasks, or state-aliasing"
    )
  }
}

private func positiveFloat(_ key: String, in options: [String: String]) -> Float {
  let value = required(key, in: options)
  guard let parsed = Float(value), parsed.isFinite, parsed > 0 else {
    usage("\(key) must be a positive finite Float")
  }
  return parsed
}

private func finiteFloat(_ key: String, in options: [String: String]) -> Float {
  let value = required(key, in: options)
  guard let parsed = Float(value), parsed.isFinite else {
    usage("\(key) must be a finite Float")
  }
  return parsed
}

// Human/Matter ABI v1 currently admits only the unconstrained articulated A0
// path. The runtime intentionally does not bind support contacts until the
// owner can prove exact nullspace/KKT tangent authority. Keep support capture
// available as negative diagnostic evidence, but never train or compare a
// "support" policy as though the supplied contact asset were physically live.
private let constrainedHumanMatterSupportAvailable = false

private func supportStabilityGoal(
  controlStep: UInt32,
  committedTimestamp: BrainTimestamp,
  targetTimestamp: BrainTimestamp
) throws -> ActiveGoal {
  guard controlStep > 0 else {
    throw TissueError.transaction("Gate C support goal has no control step")
  }
  var target = [Float](repeating: 0, count: 16)
  target[12] = 0.05
  target[13] = 0.05
  target[14] = 0.05
  return try ActiveGoal(
    identifier: 0x0047_4353_5441_0000 | UInt64(controlStep),
    origin: .externalTask,
    targetState: BrainLatentVector(values: target, expectedCount: 16),
    priority: 10,
    deadline: targetTimestamp,
    successModel: BrainLatentVector(values: target, expectedCount: 16),
    failureModel: BrainLatentVector(
      values: target.map { -$0 },
      expectedCount: 16
    ),
    damageRiskBudget: 1,
    persistence: 1,
    createdTimestamp: committedTimestamp
  )
}

private func headPostureLiftGoal(
  controlStep: UInt32,
  committedTimestamp: BrainTimestamp,
  targetTimestamp: BrainTimestamp
) throws -> ActiveGoal {
  guard controlStep > 0 else {
    throw TissueError.transaction("Gate C head-posture goal has no control step")
  }
  var target = [Float](repeating: 0, count: 16)
  // Module 73 interprets these as relative position, velocity, force, and
  // stiffness coordinates. Body 23 is the authoritative head body in the
  // checked full-body vision profile. Unlike root support velocity, this
  // head-relative target is actuated by the retained muscle system even while
  // constrained Human/Matter contact remains deliberately fail-closed.
  target[2] = 0.25
  target[6] = 0.10
  target[10] = 0.05
  target[14] = 0.20
  return try ActiveGoal(
    identifier: 0x0047_4348_4541_0000 | UInt64(controlStep),
    origin: .externalTask,
    targetState: BrainLatentVector(values: target, expectedCount: 16),
    priority: 10,
    deadline: targetTimestamp,
    successModel: BrainLatentVector(values: target, expectedCount: 16),
    failureModel: BrainLatentVector(
      values: target.map { -$0 }, expectedCount: 16
    ),
    damageRiskBudget: 1,
    persistence: 1,
    createdTimestamp: committedTimestamp,
    targetBodyIdentifier: 23
  )
}

private func supportReplaySummary(
  _ receipt: BrainPolicyNumanXSupportStabilityReplayReceipt
) -> SupportReplaySummary {
  SupportReplaySummary(
    formatVersion:
      BrainPolicyNumanXSupportStabilityReplayArtifact.formatVersion,
    replayArtifactSHA256: receipt.replayArtifactSHA256,
    referenceEvaluationArtifactSHA256:
      receipt.referenceEvaluationArtifactSHA256,
    replayEvaluationArtifactSHA256: receipt.replayEvaluationArtifactSHA256,
    baselineRootCount: receipt.baselineRootCount,
    learnedRootCount: receipt.learnedRootCount,
    transactionUniqueIdentityDifferenceCount:
      receipt.transactionUniqueIdentityDifferenceCount,
    exactSemanticReplay: true,
    transitiveEvidenceSHA256: receipt.transitiveEvidenceSHA256,
    promotable: false
  )
}

private func headPostureSummary(
  _ receipt: BrainPolicyNumanXHeadPostureEvaluationReceipt
) -> HeadPostureEvaluationSummary {
  HeadPostureEvaluationSummary(
    formatVersion:
      BrainPolicyNumanXHeadPostureEvaluationArtifact.formatVersion,
    evaluationArtifactSHA256: receipt.evaluationArtifactSHA256,
    candidateArtifactSHA256: receipt.candidateArtifactSHA256,
    baselineRunArtifactSHA256: receipt.baselineRunArtifactSHA256,
    candidateRunArtifactSHA256: receipt.candidateRunArtifactSHA256,
    targetBodyIdentifier:
      BrainPolicyNumanXHeadPostureEvaluationArtifact.targetBodyIdentifier,
    baselineLiftMeters: receipt.baselineLiftMeters,
    candidateLiftMeters: receipt.candidateLiftMeters,
    candidateMinusBaselineLiftMeters:
      receipt.candidateMinusBaselineLiftMeters,
    minimumLiftAdvantageMeters:
      BrainPolicyNumanXHeadPostureEvaluationArtifact
        .minimumLiftAdvantageMeters,
    succeeds: receipt.succeeds,
    transitiveEvidenceSHA256: receipt.transitiveEvidenceSHA256,
    promotable: false
  )
}

private func inferenceLatencySummary(
  _ receipt: BrainPolicyNumanXInferenceLatencyEvaluationReceipt
) -> InferenceLatencySummary {
  InferenceLatencySummary(
    formatVersion:
      BrainPolicyNumanXInferenceLatencyEvaluationArtifact.formatVersion,
    evaluationArtifactSHA256: receipt.evaluationArtifactSHA256,
    candidateArtifactSHA256: receipt.candidateArtifactSHA256,
    captureRunArtifactSHA256: receipt.captureRunArtifactSHA256,
    observationCount: receipt.observationCount,
    percentile99Microseconds: receipt.percentile99Microseconds,
    maximumInferenceLatencyMicroseconds:
      receipt.maximumInferenceLatencyMicroseconds,
    passesDeclaredBudget: receipt.passesDeclaredBudget,
    transitiveEvidenceSHA256: receipt.transitiveEvidenceSHA256,
    promotable: false
  )
}

private func oodSummary(
  _ receipt: BrainPolicyNumanXOODEvaluationReceipt
) -> OODEvaluationSummary {
  OODEvaluationSummary(
    formatVersion: BrainPolicyNumanXOODEvaluationArtifact.formatVersion,
    evaluationArtifactSHA256: receipt.evaluationArtifactSHA256,
    candidateArtifactSHA256: receipt.candidateArtifactSHA256,
    captureRunArtifactSHA256: receipt.captureRunArtifactSHA256,
    observationCount: receipt.observationCount,
    auroc: receipt.auroc,
    supervisionOrRejectRecall: receipt.supervisionOrRejectRecall,
    unsafeAcceptRate: receipt.unsafeAcceptRate,
    passesPredeclaredThresholds: receipt.passesPredeclaredThresholds,
    transitiveEvidenceSHA256: receipt.transitiveEvidenceSHA256,
    promotable: false
  )
}

private func hardSafetySummary(
  _ receipt: BrainPolicyNumanXHardSafetyEvaluationReceipt
) -> HardSafetyEvaluationSummary {
  HardSafetyEvaluationSummary(
    formatVersion:
      BrainPolicyNumanXHardSafetyEvaluationArtifact.formatVersion,
    evaluationArtifactSHA256: receipt.evaluationArtifactSHA256,
    candidateArtifactSHA256: receipt.candidateArtifactSHA256,
    captureRunArtifactSHA256: receipt.captureRunArtifactSHA256,
    observationCount: receipt.observationCount,
    rejectedRootCount: receipt.rejectedRootCount,
    protectiveBypassCount: receipt.protectiveBypassCount,
    safetyViolationRate: receipt.safetyViolationRate,
    maximumLearnedDescendingPeak: receipt.maximumLearnedDescendingPeak,
    passesPredeclaredThresholds: receipt.passesPredeclaredThresholds,
    transitiveEvidenceSHA256: receipt.transitiveEvidenceSHA256,
    promotable: false
  )
}

private func fewShotSummary(
  _ receipt: BrainPolicyNumanXFewShotEvaluationReceipt
) -> FewShotEvaluationSummary {
  FewShotEvaluationSummary(
    formatVersion: BrainPolicyNumanXFewShotEvaluationArtifact.formatVersion,
    evaluationArtifactSHA256: receipt.evaluationArtifactSHA256,
    trainingArtifactSHA256: receipt.trainingArtifactSHA256,
    parentCandidateArtifactSHA256: receipt.parentCandidateArtifactSHA256,
    adaptedCandidateArtifactSHA256: receipt.adaptedCandidateArtifactSHA256,
    adaptationExampleCount: receipt.adaptationExampleCount,
    adaptationWallClockSeconds: receipt.adaptationWallClockSeconds,
    preAdaptationSuccessRate: receipt.preAdaptationSuccessRate,
    postAdaptationSuccessRate: receipt.postAdaptationSuccessRate,
    retainedPriorSuccessRate: receipt.retainedPriorSuccessRate,
    postMinusPreAdaptationSuccessRate:
      receipt.postMinusPreAdaptationSuccessRate,
    passesPredeclaredThresholds: receipt.passesPredeclaredThresholds,
    demonstratesPositiveAdaptation: receipt.demonstratesPositiveAdaptation,
    transitiveEvidenceSHA256: receipt.transitiveEvidenceSHA256,
    promotable: false
  )
}

private func longHorizonProtocolSummary(
  _ artifact: BrainPolicyNumanXLongHorizonProtocolArtifact,
  sha256: String
) -> LongHorizonProtocolSummary {
  LongHorizonProtocolSummary(
    formatVersion: BrainPolicyNumanXLongHorizonProtocolArtifact.formatVersion,
    protocolArtifactSHA256: sha256,
    protocolIdentifier: artifact.protocolIdentifier,
    candidateArtifactSHA256: artifact.candidateArtifactSHA256,
    axis: artifact.axis,
    cohortCount: artifact.cohortCount,
    rootsPerCohort: artifact.rootsPerCohort,
    totalRootCount: artifact.totalRootCount,
    promotable: false
  )
}

private func longHorizonEvaluationSummary(
  _ receipt: BrainPolicyNumanXLongHorizonEvaluationReceipt
) -> LongHorizonEvaluationSummary {
  LongHorizonEvaluationSummary(
    formatVersion: BrainPolicyNumanXLongHorizonEvaluationArtifact.formatVersion,
    evaluationArtifactSHA256: receipt.evaluationArtifactSHA256,
    candidateArtifactSHA256: receipt.candidateArtifactSHA256,
    protocolArtifactSHA256: receipt.protocolArtifactSHA256,
    captureRunArtifactSHA256: receipt.captureRunArtifactSHA256,
    axis: receipt.axis,
    cohortCount: receipt.cohortCount,
    successfulCohortCount: receipt.successfulCohortCount,
    successRate: receipt.successRate,
    passesPredeclaredThresholds: receipt.passesPredeclaredThresholds,
    transitiveEvidenceSHA256: receipt.transitiveEvidenceSHA256,
    promotable: false
  )
}

let arguments = CommandLine.arguments
guard arguments.count > 2 else { usage() }
if arguments[1] == "verify-long-horizon" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let receipt = try BrainPolicyNumanXLongHorizonEvaluator.verify(
      evaluationArtifactSHA256: required("--evaluation-sha", in: options),
      artifactDirectory: URL(
        fileURLWithPath: required("--artifact-dir", in: options),
        isDirectory: true
      )
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(
      try encoder.encode(longHorizonEvaluationSummary(receipt))
    )
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "evaluate-long-horizon" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let receipt = try BrainPolicyNumanXLongHorizonEvaluator.evaluateAndWrite(
      candidateArtifactSHA256: required("--candidate-sha", in: options),
      protocolArtifactSHA256: required("--protocol-sha", in: options),
      captureRunArtifactSHA256: required("--run-sha", in: options),
      artifactDirectory: URL(
        fileURLWithPath: required("--artifact-dir", in: options),
        isDirectory: true
      )
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(
      try encoder.encode(longHorizonEvaluationSummary(receipt))
    )
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "verify-long-horizon-protocol" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let directory = URL(
      fileURLWithPath: required("--artifact-dir", in: options),
      isDirectory: true
    )
    let hash = required("--protocol-sha", in: options)
    let artifact = try BrainPolicyNumanXLongHorizonProtocolVerifier.verify(
      protocolArtifactSHA256: hash,
      artifactDirectory: directory
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(
      longHorizonProtocolSummary(artifact, sha256: hash)
    ))
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "create-long-horizon-protocol" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let directory = URL(
      fileURLWithPath: required("--artifact-dir", in: options),
      isDirectory: true
    )
    let candidateHash = required("--candidate-sha", in: options)
    _ = try BrainPolicyNumanXLearnedCandidateVerifier.verify(
      candidateArtifactSHA256: candidateHash,
      artifactDirectory: directory
    )
    let artifact = try BrainPolicyNumanXLongHorizonProtocolArtifact(
      protocolIdentifier: required("--protocol-id", in: options),
      candidateArtifactSHA256: candidateHash,
      axis: longHorizonAxis(required("--axis", in: options)),
      datasetSourceIdentifier: required("--dataset-id", in: options),
      episodeIdentifier: decimal("--episode", in: options, as: UInt64.self),
      taskFingerprint: fingerprint("--task-fp", in: options),
      sceneFingerprint: fingerprint("--scene-fp", in: options),
      objectFingerprint: fingerprint("--object-fp", in: options),
      embodimentFingerprint: fingerprint("--embodiment-fp", in: options),
      timestepMicroseconds: decimal(
        "--timestep-microseconds", in: options, as: UInt32.self
      ),
      cohortCount: decimal("--cohorts", in: options, as: UInt32.self)
    )
    let hash = try artifact.write(to: directory)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(
      longHorizonProtocolSummary(artifact, sha256: hash)
    ))
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "verify-few-shot" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let receipt = try BrainPolicyNumanXFewShotEvaluator.verify(
      evaluationArtifactSHA256: required("--evaluation-sha", in: options),
      artifactDirectory: URL(
        fileURLWithPath: required("--artifact-dir", in: options),
        isDirectory: true
      )
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(fewShotSummary(receipt)))
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "evaluate-few-shot" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let receipt = try BrainPolicyNumanXFewShotEvaluator.evaluateAndWrite(
      trainingArtifactSHA256: required("--training-sha", in: options),
      preAdaptationRunArtifactSHA256: required("--pre-run-sha", in: options),
      postAdaptationRunArtifactSHA256: required("--post-run-sha", in: options),
      retainedPriorRunArtifactSHA256: required("--prior-run-sha", in: options),
      artifactDirectory: URL(
        fileURLWithPath: required("--artifact-dir", in: options),
        isDirectory: true
      )
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(fewShotSummary(receipt)))
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "verify-hard-safety" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let receipt = try BrainPolicyNumanXHardSafetyEvaluator.verify(
      evaluationArtifactSHA256: required("--evaluation-sha", in: options),
      artifactDirectory: URL(
        fileURLWithPath: required("--artifact-dir", in: options),
        isDirectory: true
      )
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(
      try encoder.encode(hardSafetySummary(receipt))
    )
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "evaluate-hard-safety" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let receipt = try BrainPolicyNumanXHardSafetyEvaluator.evaluateAndWrite(
      candidateArtifactSHA256: required("--candidate-sha", in: options),
      captureRunArtifactSHA256: required("--run-sha", in: options),
      artifactDirectory: URL(
        fileURLWithPath: required("--artifact-dir", in: options),
        isDirectory: true
      )
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(
      try encoder.encode(hardSafetySummary(receipt))
    )
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "verify-ood" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let receipt = try BrainPolicyNumanXOODEvaluator.verify(
      evaluationArtifactSHA256: required("--evaluation-sha", in: options),
      artifactDirectory: URL(
        fileURLWithPath: required("--artifact-dir", in: options),
        isDirectory: true
      )
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(oodSummary(receipt)))
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "evaluate-ood" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let receipt = try BrainPolicyNumanXOODEvaluator.evaluateAndWrite(
      candidateArtifactSHA256: required("--candidate-sha", in: options),
      captureRunArtifactSHA256: required("--run-sha", in: options),
      artifactDirectory: URL(
        fileURLWithPath: required("--artifact-dir", in: options),
        isDirectory: true
      )
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(oodSummary(receipt)))
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "verify-latency" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let receipt = try BrainPolicyNumanXInferenceLatencyEvaluator.verify(
      evaluationArtifactSHA256: required("--evaluation-sha", in: options),
      artifactDirectory: URL(
        fileURLWithPath: required("--artifact-dir", in: options),
        isDirectory: true
      )
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(
      try encoder.encode(inferenceLatencySummary(receipt))
    )
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "evaluate-latency" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let receipt = try BrainPolicyNumanXInferenceLatencyEvaluator
      .evaluateAndWrite(
        candidateArtifactSHA256: required("--candidate-sha", in: options),
        captureRunArtifactSHA256: required("--run-sha", in: options),
        artifactDirectory: URL(
          fileURLWithPath: required("--artifact-dir", in: options),
          isDirectory: true
        )
      )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(
      try encoder.encode(inferenceLatencySummary(receipt))
    )
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "verify-support-replay" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let receipt = try BrainPolicyNumanXSupportStabilityReplayVerifier.verify(
      replayArtifactSHA256: required("--replay-sha", in: options),
      artifactDirectory: URL(
        fileURLWithPath: required("--artifact-dir", in: options),
        isDirectory: true
      )
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(
      try encoder.encode(supportReplaySummary(receipt))
    )
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "compare-support-replay" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let receipt = try BrainPolicyNumanXSupportStabilityReplayVerifier
      .compareAndWrite(
        referenceEvaluationArtifactSHA256: required(
          "--reference-evaluation-sha",
          in: options
        ),
        replayEvaluationArtifactSHA256: required(
          "--replay-evaluation-sha",
          in: options
        ),
        artifactDirectory: URL(
          fileURLWithPath: required("--artifact-dir", in: options),
          isDirectory: true
        )
      )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(
      try encoder.encode(supportReplaySummary(receipt))
    )
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "verify-head-posture" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let directory = URL(
      fileURLWithPath: required("--artifact-dir", in: options),
      isDirectory: true
    )
    let receipt = try BrainPolicyNumanXHeadPostureEvaluator.verify(
      evaluationArtifactSHA256: required("--evaluation-sha", in: options),
      artifactDirectory: directory
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(
      try encoder.encode(headPostureSummary(receipt))
    )
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "evaluate-head-posture" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let directory = URL(
      fileURLWithPath: required("--artifact-dir", in: options),
      isDirectory: true
    )
    let receipt = try BrainPolicyNumanXHeadPostureEvaluator.evaluateAndWrite(
      candidateArtifactSHA256: required("--candidate-sha", in: options),
      baselineRunArtifactSHA256: required("--baseline-run-sha", in: options),
      candidateRunArtifactSHA256: required("--candidate-run-sha", in: options),
      artifactDirectory: directory
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(
      try encoder.encode(headPostureSummary(receipt))
    )
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "verify-support" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let evaluationHash = required("--evaluation-sha", in: options)
    let directory = URL(
      fileURLWithPath: required("--artifact-dir", in: options),
      isDirectory: true
    )
    let receipt = try BrainPolicyNumanXSupportStabilityEvaluator.verify(
      evaluationArtifactSHA256: evaluationHash,
      artifactDirectory: directory
    )
    let summary = SupportEvaluationSummary(
      formatVersion:
        BrainPolicyNumanXSupportStabilityEvaluationArtifact.formatVersion,
      evaluationArtifactSHA256: receipt.evaluationArtifactSHA256,
      candidateArtifactSHA256: receipt.candidateArtifactSHA256,
      contactVariantArtifactSHA256: receipt.contactVariantArtifactSHA256,
      contactVariantAssetSHA256: receipt.contactVariantAssetSHA256,
      baselineRunArtifactSHA256: receipt.baselineRunArtifactSHA256,
      learnedRunArtifactSHA256: receipt.learnedRunArtifactSHA256,
      baselineObservationCount: receipt.baselineObservationCount,
      learnedObservationCount: receipt.learnedObservationCount,
      observationCount: receipt.observationCount,
      baselineSuccessRate: receipt.baselineSuccessRate,
      learnedSuccessRate: receipt.learnedSuccessRate,
      learnedMinusBaselineSuccessRate:
        receipt.learnedSuccessRate - receipt.baselineSuccessRate,
      transitiveEvidenceSHA256: receipt.transitiveEvidenceSHA256,
      promotable: false
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(summary))
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "evaluate-support" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    guard constrainedHumanMatterSupportAvailable else {
      throw TissueError.transaction(
        "Gate C support evaluation is unavailable: Human/Matter ABI v1 "
          + "does not yet own constrained nullspace/KKT contact authority"
      )
    }
    guard let device = MTLCreateSystemDefaultDevice() else {
      throw TissueError.metal("no Metal device is available")
    }
    let artifactDirectory = URL(
      fileURLWithPath: required("--artifact-dir", in: options),
      isDirectory: true
    )
    let candidateHash = required("--candidate-sha", in: options)
    let candidate = try BrainPolicyNumanXLearnedCandidateVerifier
      .verifiedCandidate(
        candidateArtifactSHA256: candidateHash,
        artifactDirectory: artifactDirectory
      )
    let timestepMicroseconds = optionalDecimal(
      "--timestep-microseconds",
      in: options,
      default: qualifiedGateCTimestepMicroseconds
    )
    guard timestepMicroseconds > 0 else {
      usage("--timestep-microseconds must be positive")
    }
    let compiled = try NumanXFullBodyTransportTemplate.compile(
      latencyMicroseconds: timestepMicroseconds
    )
    let baselinePublication = if let parent = candidate
      .parentCandidateArtifactSHA256
    {
      try BrainPolicyNumanXLearnedCandidateVerifier.verifiedPublication(
        candidateArtifactSHA256: parent,
        artifactDirectory: artifactDirectory
      )
    } else {
      try BrainParameterPublication.developmentalSeedV1(
        species: compiled.species,
        tissueParameters: .corticalSheetV0
      )
    }
    let learnedPublication = try candidate.publication
    guard baselinePublication.version == candidate.parentVersion else {
      throw TissueError.transaction(
        "Gate C support baseline does not match the candidate parent"
      )
    }
    let contact = try BrainPolicyNumanXSupportContactVariant.create(
      sourceURL: URL(fileURLWithPath: required("--contacts", in: options)),
      tiltDegrees: finiteFloat("--tilt-degrees", in: options),
      artifactDirectory: artifactDirectory
    )
    let episode = decimal("--episode", in: options, as: UInt64.self)
    let seed = decimal("--seed", in: options, as: UInt64.self)
    let rootCount = decimal("--roots", in: options, as: UInt32.self)
    guard rootCount >= 11 else {
      throw TissueError.transaction(
        "Gate C support evaluation requires at least ten physical observations"
      )
    }
    let coordinates = try BrainPolicyNumanXDatasetCoordinates(
      datasetSourceIdentifier: required("--dataset-id", in: options),
      datasetSourceRevision: contact.artifactSHA256,
      episodeIdentifier: episode,
      taskFingerprint: fingerprint("--task-fp", in: options),
      sceneFingerprint: fingerprint("--scene-fp", in: options),
      objectFingerprint: fingerprint("--object-fp", in: options),
      embodimentFingerprint: fingerprint("--embodiment-fp", in: options)
    )
    let evaluationIdentifier = required("--evaluation-id", in: options)
    let sourceRevision = required("--source-revision", in: options)
    func captureCohort(
      publication: BrainParameterPublication,
      label: String
    ) throws -> String {
      let runner = try MetalNumanXGateCRootRunner(
        libraryPath: required("--library", in: options),
        bridgeConfiguration: MetalNumanXBridgeV1Runtime.Configuration(
          rigidPayloadPath: required("--rigid", in: options),
          musclePayloadPath: required("--muscle", in: options),
          supportContactPayloadPath: contact.variantAssetURL.path(),
          visualPackPath: required("--visual-pack", in: options),
          visionProfilePath: required("--vision-profile", in: options),
          metalRoboMetallibPath: required("--metalrobo-metallib", in: options),
          matterMetallibPath: required("--matter-metallib", in: options),
          matterMaterialPath: required("--material", in: options),
          timestepMicroseconds: UInt64(timestepMicroseconds),
          transactionSlotCount: 2
        ),
        publication: publication,
        artifactDirectory: artifactDirectory,
        episodeIdentifier: episode,
        randomSeed: seed,
        enableProductionUncertaintyGate: true,
        device: device
      )
      var roots: [MetalNumanXGateCRootRunner.RootResult] = []
      roots.reserveCapacity(Int(rootCount))
      for controlStep in UInt32(1)...rootCount {
        do {
          let result = try runner.runRoot(
            controlStep: controlStep,
            coordinates: coordinates,
            externalGoalProvider: { committed, target in
              try supportStabilityGoal(
                controlStep: controlStep,
                committedTimestamp: committed,
                targetTimestamp: target
              )
            }
          )
          roots.append(result)
          if result.execution.outcome == .rejected { break }
        } catch {
          throw TissueError.transaction(
            "Gate C support \(label) root \(controlStep) failed: \(error)"
          )
        }
      }
      let batch = try runner.captureLearningBatch()
      return try runner.writeCaptureRunArtifact(
        runIdentifier: "\(evaluationIdentifier)-\(label)",
        sourceRevision: sourceRevision,
        roots: roots,
        learningBatch: batch
      )
    }
    let baselineRun = try captureCohort(
      publication: baselinePublication,
      label: "baseline"
    )
    let learnedRun = try captureCohort(
      publication: learnedPublication,
      label: "learned"
    )
    let receipt = try BrainPolicyNumanXSupportStabilityEvaluator
      .evaluateAndWrite(
        candidateArtifactSHA256: candidateHash,
        contactVariantArtifactSHA256: contact.artifactSHA256,
        baselineRunArtifactSHA256: baselineRun,
        learnedRunArtifactSHA256: learnedRun,
        artifactDirectory: artifactDirectory
      )
    let summary = SupportEvaluationSummary(
      formatVersion:
        BrainPolicyNumanXSupportStabilityEvaluationArtifact.formatVersion,
      evaluationArtifactSHA256: receipt.evaluationArtifactSHA256,
      candidateArtifactSHA256: receipt.candidateArtifactSHA256,
      contactVariantArtifactSHA256: receipt.contactVariantArtifactSHA256,
      contactVariantAssetSHA256: receipt.contactVariantAssetSHA256,
      baselineRunArtifactSHA256: receipt.baselineRunArtifactSHA256,
      learnedRunArtifactSHA256: receipt.learnedRunArtifactSHA256,
      baselineObservationCount: receipt.baselineObservationCount,
      learnedObservationCount: receipt.learnedObservationCount,
      observationCount: receipt.observationCount,
      baselineSuccessRate: receipt.baselineSuccessRate,
      learnedSuccessRate: receipt.learnedSuccessRate,
      learnedMinusBaselineSuccessRate:
        receipt.learnedSuccessRate - receipt.baselineSuccessRate,
      transitiveEvidenceSHA256: receipt.transitiveEvidenceSHA256,
      promotable: false
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(summary))
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "verify" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let receipt = try BrainPolicyNumanXCaptureVerifier.verify(
      runArtifactSHA256: required("--run-sha", in: options),
      artifactDirectory: URL(
        fileURLWithPath: required("--artifact-dir", in: options),
        isDirectory: true
      )
    )
    let summary = VerificationSummary(
      runArtifactSHA256: receipt.runArtifactSHA256,
      rootCount: receipt.rootCount,
      acceptedRootCount: receipt.acceptedRootCount,
      rejectedRootCount: receipt.rejectedRootCount,
      transitiveEvidenceSHA256: receipt.transitiveEvidenceSHA256
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(summary))
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
if arguments[1] == "verify-candidate" {
  let options = parseOptions(arguments.dropFirst(2))
  do {
    let receipt = try BrainPolicyNumanXLearnedCandidateVerifier.verify(
      candidateArtifactSHA256: required("--candidate-sha", in: options),
      artifactDirectory: URL(
        fileURLWithPath: required("--artifact-dir", in: options),
        isDirectory: true
      )
    )
    let summary = CandidateVerificationSummary(
      candidateArtifactSHA256: receipt.candidateArtifactSHA256,
      captureRunArtifactSHA256: receipt.captureRunArtifactSHA256,
      modelWeightsSHA256: receipt.modelWeightsSHA256,
      learnerUpdateFingerprint: receipt.learnerUpdateFingerprint,
      transitiveEvidenceSHA256: receipt.transitiveEvidenceSHA256
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(summary))
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
    exit(1)
  }
}
guard arguments[1] == "capture" || arguments[1] == "capture-train" else {
  usage()
}
let shouldTrain = arguments[1] == "capture-train"
let options = parseOptions(arguments.dropFirst(2))
let requestedDelayedSupportHorizon: UInt32? =
  options["--delayed-support-horizon-roots"] == nil ? nil : decimal(
    "--delayed-support-horizon-roots",
    in: options,
    as: UInt32.self
  )
let requestedDelayedSupportWeight: Float? =
  options["--delayed-support-weight"] == nil ? nil : positiveFloat(
    "--delayed-support-weight",
    in: options
  )
let requestedHeadPostureWeight: Float? =
  options["--head-posture-weight"] == nil ? nil : positiveFloat(
    "--head-posture-weight",
    in: options
  )
let requestedHeadPostureCalibrationSHA256 =
  options["--head-posture-calibration-sha"]
guard (requestedDelayedSupportHorizon == nil)
    == (requestedDelayedSupportWeight == nil),
  shouldTrain || requestedDelayedSupportHorizon == nil,
  shouldTrain || requestedHeadPostureWeight == nil,
  shouldTrain || requestedHeadPostureCalibrationSHA256 == nil,
  requestedHeadPostureCalibrationSHA256 == nil
    || requestedHeadPostureWeight != nil,
  requestedDelayedSupportHorizon == nil
    || requestedHeadPostureWeight == nil
else {
  usage("physical-objective options are exclusive and training-only")
}

do {
  guard let device = MTLCreateSystemDefaultDevice() else {
    throw TissueError.metal("no Metal device is available")
  }
  let episode = decimal("--episode", in: options, as: UInt64.self)
  let seed = decimal("--seed", in: options, as: UInt64.self)
  let rootCount = decimal("--roots", in: options, as: UInt32.self)
  let artifactDirectory = URL(
    fileURLWithPath: required("--artifact-dir", in: options),
    isDirectory: true
  )
  let timestepMicroseconds = optionalDecimal(
    "--timestep-microseconds",
    in: options,
    default: qualifiedGateCTimestepMicroseconds
  )
  guard timestepMicroseconds > 0 else {
    usage("--timestep-microseconds must be positive")
  }
  let compiled = try NumanXFullBodyTransportTemplate.compile(
    latencyMicroseconds: timestepMicroseconds
  )
  let parentCandidateHash = options["--parent-candidate-sha"]
  let longHorizonProtocolHash = options["--long-horizon-protocol-sha"]
  let longHorizonProtocol = try longHorizonProtocolHash.map {
    try BrainPolicyNumanXLongHorizonProtocolVerifier.verify(
      protocolArtifactSHA256: $0,
      artifactDirectory: artifactDirectory
    )
  }
  let evaluationCandidateHash = options["--candidate-sha"]
    ?? longHorizonProtocol?.candidateArtifactSHA256
  guard parentCandidateHash == nil || shouldTrain,
    evaluationCandidateHash == nil || !shouldTrain,
    parentCandidateHash == nil || evaluationCandidateHash == nil,
    longHorizonProtocol == nil || !shouldTrain,
    longHorizonProtocol == nil || options["--candidate-sha"] == nil
      || options["--candidate-sha"]
        == longHorizonProtocol?.candidateArtifactSHA256
  else {
    usage(
      "--parent-candidate-sha is training-only and --candidate-sha is capture-only"
    )
  }
  let publication = if let evaluationCandidateHash {
    try BrainPolicyNumanXLearnedCandidateVerifier.verifiedPublication(
      candidateArtifactSHA256: evaluationCandidateHash,
      artifactDirectory: artifactDirectory
    )
  } else if let parentCandidateHash {
    try BrainPolicyNumanXLearnedCandidateVerifier.verifiedPublication(
      candidateArtifactSHA256: parentCandidateHash,
      artifactDirectory: artifactDirectory
    )
  } else {
    try BrainParameterPublication.developmentalSeedV1(
      species: compiled.species,
      tissueParameters: .corticalSheetV0
    )
  }
  let declaredMaximumInferenceLatencyMicroseconds: UInt64? =
    if options["--maximum-inference-latency-microseconds"] != nil {
      decimal(
        "--maximum-inference-latency-microseconds",
        in: options,
        as: UInt64.self
      )
    } else {
      nil
    }
  let uncertaintyMode = options["--uncertainty-gate"]
  guard uncertaintyMode == nil || uncertaintyMode == "production-v1" else {
    usage("--uncertainty-gate must be production-v1 when supplied")
  }
  guard longHorizonProtocol?.axis != .interruptedTasks
      || uncertaintyMode == "production-v1"
  else {
    usage(
      "interrupted-task protocol capture requires --uncertainty-gate production-v1"
    )
  }
  let sensorIntervention: MetalNumanXGateCRootRunner.SensorIntervention =
    switch options["--sensor-intervention"] {
    case nil, "none": .none
    case "invalidate-all": .invalidateAll
    case "replay-previous-settled": .replayPreviousSettledObservation
    default:
      usage(
        "--sensor-intervention must be none, invalidate-all, or replay-previous-settled"
      )
    }
  let sensorInterventionStartStep = optionalDecimal(
    "--sensor-intervention-start-step",
    in: options,
    default: UInt32(1)
  )
  guard uncertaintyMode != nil
      || options["--sensor-intervention"] != "invalidate-all"
  else {
    usage("sensor intervention requires --uncertainty-gate production-v1")
  }
  let hardSafetyIntervention:
    MetalNumanXGateCRootRunner.HardSafetyIntervention =
      switch options["--hard-safety-intervention"] {
      case nil, "none": .none
      case "emergency-stop": .emergencyStop
      default:
        usage("--hard-safety-intervention must be none or emergency-stop")
      }
  let runner = try MetalNumanXGateCRootRunner(
    libraryPath: required("--library", in: options),
    bridgeConfiguration: MetalNumanXBridgeV1Runtime.Configuration(
      rigidPayloadPath: required("--rigid", in: options),
      musclePayloadPath: required("--muscle", in: options),
      supportContactPayloadPath: required("--contacts", in: options),
      visualPackPath: required("--visual-pack", in: options),
      visionProfilePath: required("--vision-profile", in: options),
      metalRoboMetallibPath: required("--metalrobo-metallib", in: options),
      matterMetallibPath: required("--matter-metallib", in: options),
      matterMaterialPath: required("--material", in: options),
      timestepMicroseconds: UInt64(timestepMicroseconds),
      transactionSlotCount: 2
    ),
    publication: publication,
    artifactDirectory: artifactDirectory,
    episodeIdentifier: episode,
    randomSeed: seed,
    declaredMaximumInferenceLatencyMicroseconds:
      declaredMaximumInferenceLatencyMicroseconds,
    enableProductionUncertaintyGate: uncertaintyMode != nil,
    device: device
  )
  let datasetIdentifier = required("--dataset-id", in: options)
  let datasetRevision = required("--dataset-revision", in: options)
  let coordinates = try BrainPolicyNumanXDatasetCoordinates(
    datasetSourceIdentifier: datasetIdentifier,
    datasetSourceRevision: datasetRevision,
    episodeIdentifier: episode,
    taskFingerprint: fingerprint("--task-fp", in: options),
    sceneFingerprint: fingerprint("--scene-fp", in: options),
    objectFingerprint: fingerprint("--object-fp", in: options),
    embodimentFingerprint: fingerprint("--embodiment-fp", in: options)
  )
  guard longHorizonProtocol == nil || (
    longHorizonProtocolHash == datasetRevision
      && longHorizonProtocol!.datasetSourceIdentifier == datasetIdentifier
      && longHorizonProtocol!.episodeIdentifier == episode
      && longHorizonProtocol!.taskFingerprint == coordinates.taskFingerprint
      && longHorizonProtocol!.sceneFingerprint == coordinates.sceneFingerprint
      && longHorizonProtocol!.objectFingerprint == coordinates.objectFingerprint
      && longHorizonProtocol!.embodimentFingerprint
        == coordinates.embodimentFingerprint
      && longHorizonProtocol!.timestepMicroseconds == timestepMicroseconds
      && longHorizonProtocol!.totalRootCount == rootCount
  ) else {
    usage("capture options do not match the frozen long-horizon protocol")
  }
  let goalMode = options["--goal"]
  guard goalMode == nil || goalMode == "support-stability-v1"
    || goalMode == "head-posture-lift-v1"
  else {
    usage(
      "--goal must be support-stability-v1 or head-posture-lift-v1 when supplied"
    )
  }
  guard requestedHeadPostureWeight == nil
      || (goalMode == "head-posture-lift-v1" && rootCount >= 100)
  else {
    usage(
      "--head-posture-weight requires --goal head-posture-lift-v1 and at least 100 roots"
    )
  }
  var results: [MetalNumanXGateCRootRunner.RootResult] = []
  results.reserveCapacity(Int(rootCount))
  for controlStep in UInt32(1)...rootCount {
    let scheduled = try longHorizonProtocol?.phase(controlStep: controlStep)
      let scheduledGoal = scheduled.map {
        switch $0.phase {
        case .warmup, .delayedCue, .interruptionBaseline: true
        default: false
        }
      } ?? (goalMode != nil)
      let scheduledSensorIntervention:
        MetalNumanXGateCRootRunner.SensorIntervention = switch scheduled?.phase {
      case .aliasProbe: .replayPreviousSettledObservation
      case .interruption: .invalidateAll
      default:
        controlStep >= sensorInterventionStartStep ? sensorIntervention : .none
      }
      let scheduledHardSafety:
        MetalNumanXGateCRootRunner.HardSafetyIntervention =
          scheduled?.phase == .interruption
            ? .emergencyStop : hardSafetyIntervention
      let longHorizonContext = try scheduled.map {
        try MetalNumanXGateCRootRunner.LongHorizonRootContext(
          protocolArtifactSHA256: longHorizonProtocolHash!,
          cohort: $0.cohort,
          phase: $0.phase
        )
      }
      let result = try runner.runRoot(
        controlStep: controlStep,
        coordinates: coordinates,
        externalGoalProvider: !scheduledGoal ? nil : {
          committedTimestamp, targetTimestamp in
          let goalDeadline: BrainTimestamp
          if scheduled?.phase == .delayedCue {
            let (horizon, horizonOverflow) = UInt64(
              longHorizonProtocol!.rootsPerCohort
            ).multipliedReportingOverflow(by: UInt64(timestepMicroseconds))
            let (deadline, deadlineOverflow) = committedTimestamp.rawValue
              .addingReportingOverflow(horizon)
            guard !horizonOverflow, !deadlineOverflow else {
              throw TissueError.transaction(
                "Gate C delayed goal deadline overflows"
              )
            }
            goalDeadline = BrainTimestamp(microseconds: deadline)
          } else {
            goalDeadline = targetTimestamp
          }
          switch goalMode {
          case "head-posture-lift-v1":
            return try headPostureLiftGoal(
              controlStep: controlStep,
              committedTimestamp: committedTimestamp,
              targetTimestamp: goalDeadline
            )
          default:
            return try supportStabilityGoal(
              controlStep: controlStep,
              committedTimestamp: committedTimestamp,
              targetTimestamp: goalDeadline
            )
          }
        },
        sensorIntervention: scheduledSensorIntervention,
        hardSafetyIntervention: scheduledHardSafety,
        longHorizonContext: longHorizonContext
      )
      guard uncertaintyMode != nil
        || (shouldTrain && requestedDelayedSupportHorizon != nil)
        || result.execution.outcome == .accepted
      else {
        throw TissueError.transaction(
          "Gate C accept-only capture observed an authoritative rejected root "
            + "at control step \(controlStep) "
            + "(proposal \(result.proposalCode), applied \(result.appliedCode), "
            + "native stage \(result.nativePhysicalDiagnosticStage))"
        )
      }
    results.append(result)
  }
  let runIdentifier = required("--run-id", in: options)
  let sourceRevision = required("--source-revision", in: options)
  let capturedLearningBatch = try runner.captureLearningBatch()
  let runArtifactSHA256 = try runner.writeCaptureRunArtifact(
    runIdentifier: runIdentifier,
    sourceRevision: sourceRevision,
    roots: results,
    learningBatch: capturedLearningBatch
  )
  let learnerConfigurationSHA256: String?
  let headPostureLearningArtifactSHA256: String?
  let learnedCandidateSHA256: String?
  let modelWeightsSHA256: String?
  let learnerUpdateFingerprint: UInt64?
  let adaptationTrainingArtifactSHA256: String?
  let adaptationExampleCount: UInt32?
  let adaptationWallClockSeconds: Double?
  if shouldTrain {
    guard rootCount >= 3 else {
      throw TissueError.transaction(
        "Gate C capture-train requires at least three accepted roots"
      )
    }
    let delayedSupportHorizon = requestedDelayedSupportHorizon
    let delayedSupportWeight = requestedDelayedSupportWeight
    let headPostureWeight = requestedHeadPostureWeight
    guard delayedSupportHorizon == nil || constrainedHumanMatterSupportAvailable
    else {
      throw TissueError.transaction(
        "Gate C delayed-support learning is unavailable: the current "
          + "physical root has no constrained contact authority"
      )
    }
    guard parentCandidateHash == nil || delayedSupportHorizon != nil
    else {
      throw TissueError.transaction(
        "Gate C few-shot training requires a complete delayed-support objective"
      )
    }
    let delayedSupport = try delayedSupportHorizon.map { horizon in
      try BrainPolicyNumanXDelayedSupportLearningBuilder.build(
        sourceRunArtifactSHA256: runArtifactSHA256,
        artifactDirectory: artifactDirectory,
        horizonRootCount: horizon,
        objectiveWeight: delayedSupportWeight!,
        thresholds: .gateCFewShotSupportV1
      )
    }
    let delayedSupportHash = try delayedSupport.map {
      try $0.write(to: artifactDirectory)
    }
    let headPosture = try headPostureWeight.map { weight in
      try BrainPolicyNumanXHeadPostureLearningBuilder.build(
        sourceRunArtifactSHA256: runArtifactSHA256,
        artifactDirectory: artifactDirectory,
        objectiveWeight: weight,
        calibrationEvaluationArtifactSHA256:
          requestedHeadPostureCalibrationSHA256
      )
    }
    let headPostureHash = try headPosture.map {
      try $0.write(to: artifactDirectory)
    }
    let foundation = MLXBrainLearnerConfiguration.foundationV1
    let learningRate = positiveFloat("--learning-rate", in: options)
    let lossWeights = try BrainSlowLossKind.allCases.map { kind in
      try BrainPolicyNumanXLossWeight(
        kind: kind,
        weight: foundation.lossWeights[kind] ?? 0
      )
    }
    let learnerIdentifier: String
    if delayedSupport != nil {
      learnerIdentifier = "numibrain.mlx-slow-learner.delayed-support.v1"
    } else if headPosture != nil {
      learnerIdentifier = "numibrain.mlx-slow-learner.head-posture.v1"
    } else {
      learnerIdentifier = "numibrain.mlx-slow-learner.v1"
    }
    let configurationArtifact = try
      BrainPolicyNumanXLearnerConfigurationArtifact(
        learnerIdentifier: learnerIdentifier,
        learningRate: learningRate,
        gradientNormLimit: foundation.gradientNormLimit,
        parameterMagnitudeLimit: foundation.parameterMagnitudeLimit,
        lossWeights: lossWeights,
        delayedSupportObjectiveIdentifier: delayedSupport?.objectiveIdentifier,
        delayedSupportObjectiveWeight: delayedSupport?.objectiveWeight,
        headPostureObjectiveIdentifier: headPosture?.objectiveIdentifier,
        headPostureObjectiveWeight: headPosture?.objectiveWeight
      )
    let configurationHash = try configurationArtifact.write(
      to: artifactDirectory
    )
    let learner = MLXBrainLearner(configuration: try MLXBrainLearnerConfiguration(
      learningRate: learningRate,
      gradientNormLimit: foundation.gradientNormLimit,
      parameterMagnitudeLimit: foundation.parameterMagnitudeLimit,
      lossWeights: foundation.lossWeights,
      delayedSupportObjectiveWeight: delayedSupport?.objectiveWeight ?? 0,
      headPostureObjectiveWeight: headPosture?.objectiveWeight ?? 0
    ))
    let batch = capturedLearningBatch.batch
    let updateStart = ContinuousClock.now
    let update = try learner.update(
      parentPublication: publication,
      batch: batch,
      delayedSupport: delayedSupport,
      headPosture: headPosture
    )
    let updateDuration = updateStart.duration(to: ContinuousClock.now).components
    let measuredUpdateSeconds = max(
      Double.leastNonzeroMagnitude,
      Double(updateDuration.seconds)
        + Double(updateDuration.attoseconds) / 1.0e18
    )
    guard try learner.update(
      parentPublication: publication,
      batch: batch,
      delayedSupport: delayedSupport,
      headPosture: headPosture
    )
      == update
    else {
      throw TissueError.transaction(
        "Gate C MLX successor did not replay deterministically"
      )
    }
    let candidate = try BrainPolicyNumanXLearnedCandidateArtifact(
      captureRunArtifactSHA256: runArtifactSHA256,
      learnerConfigurationSHA256: configurationHash,
      parentCandidateArtifactSHA256: parentCandidateHash,
      parentVersion: publication.version,
      learnerUpdate: update,
      delayedSupportLearningArtifactSHA256: delayedSupportHash,
      headPostureLearningArtifactSHA256: headPostureHash
    )
    learnerConfigurationSHA256 = configurationHash
    headPostureLearningArtifactSHA256 = headPostureHash
    let candidateHash = try candidate.write(to: artifactDirectory)
    learnedCandidateSHA256 = candidateHash
    modelWeightsSHA256 = candidate.modelWeightsSHA256
    learnerUpdateFingerprint = update.updateFingerprint
    if let parentCandidateHash {
      let acceptedExamples = UInt32(delayedSupport!.examples.count)
      guard (1...32).contains(acceptedExamples) else {
        throw TissueError.transaction(
          "Gate C few-shot adaptation requires 1...32 accepted examples"
        )
      }
      let training = try BrainPolicyNumanXAdaptationTrainingArtifact(
        parentCandidateArtifactSHA256: parentCandidateHash,
        adaptedCandidateArtifactSHA256: candidateHash,
        adaptationRunArtifactSHA256: runArtifactSHA256,
        adaptationExampleCount: acceptedExamples,
        adaptationWallClockSeconds: measuredUpdateSeconds
      )
      adaptationTrainingArtifactSHA256 = try training.write(
        to: artifactDirectory
      )
      adaptationExampleCount = acceptedExamples
      adaptationWallClockSeconds = measuredUpdateSeconds
    } else {
      adaptationTrainingArtifactSHA256 = nil
      adaptationExampleCount = nil
      adaptationWallClockSeconds = nil
    }
  } else {
    learnerConfigurationSHA256 = nil
    headPostureLearningArtifactSHA256 = nil
    learnedCandidateSHA256 = nil
    modelWeightsSHA256 = nil
    learnerUpdateFingerprint = nil
    adaptationTrainingArtifactSHA256 = nil
    adaptationExampleCount = nil
    adaptationWallClockSeconds = nil
  }
  let summary = CaptureSummary(
    formatVersion: BrainPolicyNumanXCaptureRunArtifact.formatVersion,
    runIdentifier: runIdentifier,
    runArtifactSHA256: runArtifactSHA256,
    artifactDirectory: artifactDirectory.path(),
    datasetSourceIdentifier: datasetIdentifier,
    datasetSourceRevision: datasetRevision,
    sourceRevision: sourceRevision,
    promotable: false,
    deviceName: device.name,
    deviceRegistryID: device.registryID,
    bodyCount: runner.nativeInfo.bodyCount,
    qCoordinateCount: runner.nativeInfo.qCoordinateCount,
    dofCount: runner.nativeInfo.dofCount,
    muscleCount: runner.nativeInfo.muscleCount,
    roots: results.map {
      CaptureRootSummary(
        controlStep: $0.execution.controlStep,
        outcome: $0.execution.outcome,
        sampleSHA256: $0.sample.sampleSHA256,
        executionSHA256: $0.executionArtifactSHA256,
        brainGeneration: $0.aggregate?.brainGeneration ?? 0,
        physicsGeneration: $0.aggregate?.physicsGeneration ?? 0,
        sensorGeneration: $0.aggregate?.sensorGeneration ?? 0,
        inferenceLatencyMicroseconds: $0.inferenceLatencyMicroseconds,
        brainPreflightReady: $0.brainPreflightReady,
        proposalCode: $0.proposalCode,
        appliedCode: $0.appliedCode,
        nativePhysicalDiagnosticStage: $0.nativePhysicalDiagnosticStage,
        uncertaintyScore: $0.uncertainty?.score,
        supervisionRequired: $0.uncertainty?.supervisionRequired,
        uncertaintyRootRejected: $0.uncertainty?.rootRejected,
        protectiveBypass: $0.hardSafety?.protectiveBypass,
        safetyViolation: $0.hardSafety?.safetyViolation,
        learnedDescendingPeak: $0.hardSafety?.learnedDescendingPeak
      )
    },
    learnerConfigurationSHA256: learnerConfigurationSHA256,
    headPostureLearningArtifactSHA256:
      headPostureLearningArtifactSHA256,
    learnedCandidateSHA256: learnedCandidateSHA256,
    modelWeightsSHA256: modelWeightsSHA256,
    learnerUpdateFingerprint: learnerUpdateFingerprint,
    adaptationTrainingArtifactSHA256: adaptationTrainingArtifactSHA256,
    adaptationExampleCount: adaptationExampleCount,
    adaptationWallClockSeconds: adaptationWallClockSeconds
  )
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  FileHandle.standardOutput.write(try encoder.encode(summary))
  FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
  FileHandle.standardError.write(Data("numi-brain-gate-c: \(error)\n".utf8))
  exit(1)
}

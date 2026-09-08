import Foundation
import MLX
import NumiBrainCore

/// Off-rollout, physical-outcome-based learning of the actual connectome decoder.
/// A paired random direction estimates a noisy gradient with two physical runs;
/// it does not differentiate through an invented physics or neural simulator.
@available(macOS 26.0, *)
public enum MLXConnectomeDecoderCalibration {
  public static func probes(parent: ConnectomeControllerProgram,
    settings: ConnectomeDecoderStudySettings) throws -> (negative: ConnectomeControllerSpec, positive: ConnectomeControllerSpec) {
    let values = parent.spec.decoderParameters
    try settings.validate(parameterCount: values.count)
    let old = settings.coordinates.map { values[$0] }
    let offset = MLXArray(try settings.directions()) * MLXArray(settings.probeRadius)
    let minus = (MLXArray(old) - offset).asArray(Float.self)
    let plus = (MLXArray(old) + offset).asArray(Float.self)
    var negative = values, positive = values
    for (j, index) in settings.coordinates.enumerated() {
      guard minus[j].isFinite, plus[j].isFinite, minus[j] != old[j], plus[j] != old[j],
        min(minus[j], plus[j]) < old[j], max(minus[j], plus[j]) > old[j],
        max(abs(minus[j]), abs(plus[j])) <= settings.magnitudeLimit else {
        throw ConnectomeError.invalid("decoder probe is unresolved or would need asymmetric clipping")
      }
      negative[index] = minus[j]; positive[index] = plus[j]
    }
    return (try parent.spec.replacingDecoderParameters(negative), try parent.spec.replacingDecoderParameters(positive))
  }

  /// Retain a probe plan only after verifying its actual parent capture. Neither
  /// old .motor gains nor frozen connectome edges participate in this update.
  public static func prepare(parentRunSHA256: String, protocolSHA256: String,
    settings: ConnectomeDecoderStudySettings, directory: URL) throws -> ConnectomeDecoderProbePlan {
    try settings.validate()
    let (run, identity, program) = try parentSource(parentRunSHA256, directory)
    let experiment = try BrainReachHoldExperiment.read(BrainReachHoldProtocol.self, hash: protocolSHA256, directory: directory)
    try experiment.validate()
    guard experiment.calibrationSettingsSHA256 == (try settings.sha256),
      experiment.parameterVersionFingerprint == run.parameterVersionFingerprint,
      experiment.expectedNativeModelFingerprint == run.nativeModelSourceFingerprint,
      experiment.sourceRevision == run.sourceRevision else {
      throw ConnectomeError.invalid("decoder study is not bound to frozen settings, source, body and publication")
    }
    let pair = try probes(parent: program, settings: settings)
    return try ConnectomeDecoderProbePlan(parentRunSHA256: parentRunSHA256, protocolSHA256: protocolSHA256,
      parentController: identity, settings: settings,
      negativeSpecificationSHA256: BrainReachHoldExperiment.retain(pair.negative, directory: directory),
      positiveSpecificationSHA256: BrainReachHoldExperiment.retain(pair.positive, directory: directory))
  }

  public static func update(planSHA256: String, negativeEvaluationSHA256: String,
    positiveEvaluationSHA256: String, directory: URL) throws -> ConnectomeDecoderProposal {
    let plan = try BrainReachHoldExperiment.read(ConnectomeDecoderProbePlan.self, hash: planSHA256, directory: directory)
    try plan.validate()
    let (parentRun, identity, parent) = try parentSource(plan.parentRunSHA256, directory)
    guard identity == plan.parentController else { throw ConnectomeError.invalid("probe plan changed its parent controller") }
    let pair = try probes(parent: parent, settings: plan.settings)
    let nHash = try specificationHash(pair.negative), pHash = try specificationHash(pair.positive)
    guard nHash == plan.negativeSpecificationSHA256, pHash == plan.positiveSpecificationSHA256 else {
      throw ConnectomeError.invalid("probes are not the exact predeclared perturbations of the immutable parent")
    }
    let negative = try BrainReachHoldExperiment.verify(evaluationSHA256: negativeEvaluationSHA256,
      directory: directory, allowingResearchConnectome: true)
    let positive = try BrainReachHoldExperiment.verify(evaluationSHA256: positiveEvaluationSHA256,
      directory: directory, allowingResearchConnectome: true)
    guard let ni = negative.connectome, let pi = positive.connectome,
      ni.specificationSHA256 == nHash, pi.specificationSHA256 == pHash,
      ni.graphSHA256 == identity.graphSHA256, pi.graphSHA256 == identity.graphSHA256,
      ni.compiledTemplateSHA256 == identity.compiledTemplateSHA256, pi.compiledTemplateSHA256 == identity.compiledTemplateSHA256,
      ni.topologyFingerprint == identity.topologyFingerprint, pi.topologyFingerprint == identity.topologyFingerprint,
      ni.parameterVersionFingerprint == identity.parameterVersionFingerprint,
      pi.parameterVersionFingerprint == identity.parameterVersionFingerprint,
      negative.artifact.protocolSHA256 == plan.protocolSHA256, positive.artifact.protocolSHA256 == plan.protocolSHA256,
      negative.experiment == positive.experiment,
      negative.capture.deviceRegistryID == positive.capture.deviceRegistryID,
      negative.capture.deviceRegistryID == parentRun.deviceRegistryID,
      negative.capture.nativeModelSourceFingerprint == parentRun.nativeModelSourceFingerprint,
      positive.capture.nativeModelSourceFingerprint == parentRun.nativeModelSourceFingerprint,
      negative.capture.acceptedStateProofProgramFingerprint == positive.capture.acceptedStateProofProgramFingerprint,
      negative.capture.acceptedStateProofProgramFingerprint == parentRun.acceptedStateProofProgramFingerprint,
      negative.experiment.calibrationSettingsSHA256 == (try plan.settings.sha256),
      negative.artifact.runSHA256 != positive.artifact.runSHA256,
      negative.artifact.initialRelativeHeadHeightMeters != nil,
      negative.artifact.initialRelativeHeadHeightMeters == positive.artifact.initialRelativeHeadHeightMeters,
      negative.artifact.rejectedRoots == 0, positive.artifact.rejectedRoots == 0,
      let negativeLoss = negative.artifact.result?.objectiveLoss, let positiveLoss = positive.artifact.result?.objectiveLoss else {
      throw ConnectomeError.invalid("decoder update lacks matched, accepted, exact-controller physical evidence")
    }
    let parameters = try proposedParameters(parent: parent.spec.decoderParameters,
      negative: pair.negative.decoderParameters, positive: pair.positive.decoderParameters,
      negativeLoss: negativeLoss, positiveLoss: positiveLoss, settings: plan.settings)
    let spec = try parent.spec.replacingDecoderParameters(parameters)
    let body = try BrainReachHoldExperiment.read(CompiledSpeciesTemplate.self,
      hash: identity.compiledTemplateSHA256, directory: directory)
    let candidate = try ConnectomeControllerProgram(graph: parent.graph, spec: spec, template: body,
      parameterVersionFingerprint: identity.parameterVersionFingerprint)
    guard candidate.programFingerprint != parent.programFingerprint,
      candidate.topologyFingerprint == parent.topologyFingerprint else {
      throw ConnectomeError.invalid("proposal is unchanged or modifies frozen neural topology")
    }
    return try ConnectomeDecoderProposal(probePlanSHA256: planSHA256,
      negativeEvaluationSHA256: negativeEvaluationSHA256, positiveEvaluationSHA256: positiveEvaluationSHA256,
      candidateSpecificationSHA256: BrainReachHoldExperiment.retain(spec, directory: directory),
      candidateProgramFingerprint: candidate.programFingerprint, negativeLoss: negativeLoss, positiveLoss: positiveLoss)
  }

  /// Internal arithmetic test surface; it issues no capture or learning receipt.
  /// Trust radius is L-infinity per selected parameter, not a bound on outcomes.
  static func proposedParameters(parent: [Float], negative: [Float], positive: [Float],
    negativeLoss: Double, positiveLoss: Double, settings: ConnectomeDecoderStudySettings) throws -> [Float] {
    try settings.validate(parameterCount: parent.count)
    let difference = positiveLoss - negativeLoss
    guard negative.count == parent.count, positive.count == parent.count,
      parent.allSatisfy(\.isFinite), negative.allSatisfy(\.isFinite), positive.allSatisfy(\.isFinite),
      negativeLoss.isFinite, positiveLoss.isFinite, difference.isFinite,
      abs(difference) > settings.minimumResolvableLossDifference else {
      throw ConnectomeError.invalid("physical loss difference is unresolved, non-finite or dimensionally inconsistent")
    }
    let gradients = try settings.coordinates.map { index -> Float in
      let lo = negative[index], hi = positive[index], old = parent[index]
      guard min(lo, hi) < old, old < max(lo, hi),
        max(abs(lo), abs(hi)) <= settings.magnitudeLimit else {
        throw ConnectomeError.invalid("physical probes do not bracket the bounded parent")
      }
      let estimate = Float(difference / (Double(hi) - Double(lo)))
      guard estimate.isFinite else { throw ConnectomeError.invalid("directional derivative exceeds finite FP32") }
      return estimate
    }
    let old = settings.coordinates.map { parent[$0] }
    let gradient = clip(MLXArray(gradients), min: -settings.gradientLimit, max: settings.gradientLimit)
    let step = clip(MLXArray(settings.learningRate)*gradient, min: -settings.trustRadius, max: settings.trustRadius)
    var changed = clip(MLXArray(old)-step, min: -settings.magnitudeLimit, max: settings.magnitudeLimit).asArray(Float.self)
    guard changed.count == old.count, changed.allSatisfy(\.isFinite) else {
      throw ConnectomeError.invalid("MLX decoder output is nonfinite or dimensionally inconsistent")
    }
    // FP32 subtraction may round just outside the exact L-infinity radius.
    // Round inward at the off-rollout publication boundary, never in a live mind.
    for i in changed.indices {
      let lower = max(-Double(settings.magnitudeLimit), Double(old[i])-Double(settings.trustRadius))
      let upper = min(Double(settings.magnitudeLimit), Double(old[i])+Double(settings.trustRadius))
      if Double(changed[i]) > upper { changed[i] = changed[i].nextDown }
      if Double(changed[i]) < lower { changed[i] = changed[i].nextUp }
      guard Double(changed[i]) >= lower, Double(changed[i]) <= upper else {
        throw ConnectomeError.invalid("decoder update exceeds its representable trust interval")
      }
    }
    guard zip(old, changed).contains(where: { $0 != $1 }) else {
      throw ConnectomeError.invalid("decoder proposal is non-finite or makes no representable change")
    }
    var result = parent
    for (j, index) in settings.coordinates.enumerated() { result[index] = changed[j] }
    return result
  }

  private static func specificationHash(_ spec: ConnectomeControllerSpec) throws -> String {
    BrainPolicyEvidenceArtifact.sha256(try BrainPolicyEvidenceArtifact.encodeCanonical(spec))
  }
  private static func parentSource(_ hash: String, _ directory: URL) throws
    -> (BrainPolicyNumanXCaptureRunArtifact, ConnectomeCaptureIdentity, ConnectomeControllerProgram) {
    let receipt = try BrainPolicyNumanXCaptureVerifier.verify(runArtifactSHA256: hash,
      artifactDirectory: directory, allowingResearchConnectome: true)
    guard receipt.acceptedRootCount > 0, receipt.rejectedRootCount == 0 else {
      throw ConnectomeError.invalid("decoder study parent must have a fully accepted native capture")
    }
    let run = try BrainReachHoldExperiment.read(BrainPolicyNumanXCaptureRunArtifact.self, hash: hash, directory: directory)
    guard let identity = run.connectome else { throw ConnectomeError.invalid("decoder learning requires a retained connectome capture") }
    let program = try identity.verify(directory: directory, expectedTemplateFingerprint: run.compiledSpeciesTemplateFingerprint,
      parameterVersionFingerprint: run.parameterVersionFingerprint)
    return (run, identity, program)
  }
}

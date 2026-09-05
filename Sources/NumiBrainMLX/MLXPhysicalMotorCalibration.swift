import Foundation
import MLX
import NumiBrainCore

/// Local outcome-based calibration, not a generalist policy learner. A small
/// secant step uses independently verified physical objectives rather than a
/// target assigned to the gains themselves. Native physics remains opaque and
/// authoritative; no differentiation through fictitious body dynamics occurs.
@available(macOS 26.0, *)
public enum MLXPhysicalMotorCalibration {
  public struct Settings: Codable, Equatable, Sendable {
    public let coordinate: Int
    public let learningRate: Float
    public let gradientLimit: Float
    public let trustRadius: Float
    public let magnitudeLimit: Float
    public let minimumResolvableLossDifference: Double

    public init(coordinate: Int, learningRate: Float, gradientLimit: Float, trustRadius: Float,
      magnitudeLimit: Float, minimumResolvableLossDifference: Double) throws {
      self.coordinate = coordinate; self.learningRate = learningRate; self.gradientLimit = gradientLimit
      self.trustRadius = trustRadius; self.magnitudeLimit = magnitudeLimit
      self.minimumResolvableLossDifference = minimumResolvableLossDifference
      try validate()
    }
    public func validate() throws {
      guard [3, 4].contains(coordinate), [learningRate, gradientLimit, trustRadius, magnitudeLimit]
        .allSatisfy({ $0.isFinite && $0 > 0 }), trustRadius <= 0.25, magnitudeLimit <= 4,
        minimumResolvableLossDifference.isFinite, minimumResolvableLossDifference > 0 else {
        throw BrainRuntimeError.invalidParameterVersion("invalid bounded physical motor calibration settings")
      }
    }
  }

  public static func probe(parent: BrainMotorStudyPublication, coordinate: Int,
    offset: Float, magnitudeLimit: Float = 4) throws -> BrainMotorStudyPublication {
    try parent.validate()
    guard [3, 4].contains(coordinate), offset.isFinite, offset != 0, abs(offset) <= 0.25,
      magnitudeLimit.isFinite, magnitudeLimit > 0, magnitudeLimit <= 4 else {
      throw BrainRuntimeError.invalidParameterVersion("invalid physical gain probe")
    }
    let old = try scalar(parent, coordinate)
    let changed = (MLXArray(old) + MLXArray(offset)).item(Float.self)
    guard changed != old, changed.isFinite, abs(changed) <= magnitudeLimit else {
      throw BrainRuntimeError.invalidParameterVersion("probe is unresolved or outside declared parameter bound")
    }
    return try replace(parent, coordinate: coordinate, value: changed, evidence: [])
  }

  /// Matched task/model/seed/initial observed height are checked. These are
  /// matched-initialization studies, NOT proof of equal complete checkpoints.
  /// Every proposal still needs fresh parent/candidate and held-out evaluation.
  public static func update(parent: BrainMotorStudyPublication,
    negative: BrainMotorStudyPublication, positive: BrainMotorStudyPublication,
    negativeEvaluation: BrainVerifiedReachHoldEvaluation,
    positiveEvaluation: BrainVerifiedReachHoldEvaluation,
    settings: Settings) throws -> BrainMotorStudyPublication {
    try settings.validate(); try parent.validate(); try negative.validate(); try positive.validate()
    try requireCoordinateOnlyProbe(parent: parent, probe: negative, coordinate: settings.coordinate)
    try requireCoordinateOnlyProbe(parent: parent, probe: positive, coordinate: settings.coordinate)
    let n = negativeEvaluation.experiment, p = positiveEvaluation.experiment
    let settingsHash = BrainPolicyEvidenceArtifact.sha256(try BrainPolicyEvidenceArtifact.encodeCanonical(settings))
    guard n.calibrationSettingsSHA256 == settingsHash, p.calibrationSettingsSHA256 == settingsHash,
      n.parameterVersionFingerprint == negative.version.fingerprint,
      p.parameterVersionFingerprint == positive.version.fingerprint,
      n.sourceRevision == p.sourceRevision, n.expectedNativeModelFingerprint == p.expectedNativeModelFingerprint,
      n.taskFingerprint == p.taskFingerprint, n.sceneFingerprint == p.sceneFingerprint,
      n.objectFingerprint == p.objectFingerprint, n.embodimentFingerprint == p.embodimentFingerprint,
      n.episodeIdentifier == p.episodeIdentifier, n.randomSeed == p.randomSeed,
      n.timestepMicroseconds == p.timestepMicroseconds, n.targetState == p.targetState, n.objective == p.objective,
      negativeEvaluation.artifact.runSHA256 != positiveEvaluation.artifact.runSHA256,
      negativeEvaluation.artifact.initialRelativeHeadHeightMeters != nil,
      negativeEvaluation.artifact.initialRelativeHeadHeightMeters == positiveEvaluation.artifact.initialRelativeHeadHeightMeters,
      negativeEvaluation.artifact.rejectedRoots == 0, positiveEvaluation.artifact.rejectedRoots == 0,
      let negativeLoss = negativeEvaluation.artifact.result?.objectiveLoss,
      let positiveLoss = positiveEvaluation.artifact.result?.objectiveLoss,
      abs(positiveLoss - negativeLoss) > settings.minimumResolvableLossDifference else {
      throw BrainRuntimeError.invalidParameterVersion("physical calibration lacks matched, valid and resolved outcome evidence")
    }
    let old = try scalar(parent, settings.coordinate)
    let lo = try scalar(negative, settings.coordinate), hi = try scalar(positive, settings.coordinate)
    guard lo < old, old < hi, hi - lo <= 0.5 else {
      throw BrainRuntimeError.invalidParameterVersion("physical probes do not bracket the immutable parent")
    }
    let gradient = (positiveLoss - negativeLoss) / Double(hi - lo)
    let gradientFP32 = Float(gradient)
    guard gradient.isFinite, gradientFP32.isFinite else {
      throw BrainRuntimeError.invalidParameterVersion("physical secant estimate exceeds finite FP32 range")
    }
    // MLX owns the off-rollout update arithmetic. Host work below only encodes
    // the exact resulting scalar into an immutable successor artifact.
    let g = clip(MLXArray(gradientFP32), min: -settings.gradientLimit, max: settings.gradientLimit)
    let step = clip(MLXArray(settings.learningRate) * g, min: -settings.trustRadius, max: settings.trustRadius)
    let result = clip(MLXArray(old) - step, min: -settings.magnitudeLimit, max: settings.magnitudeLimit).item(Float.self)
    guard result.isFinite, result != old else {
      throw BrainRuntimeError.invalidParameterVersion("physical update is unresolved or clipped to no change")
    }
    return try replace(parent, coordinate: settings.coordinate, value: result,
      evidence: [negativeEvaluation.artifactSHA256, positiveEvaluation.artifactSHA256])
  }

  private static func scalar(_ publication: BrainMotorStudyPublication, _ coordinate: Int) throws -> Float {
    let bytes = publication.sharedArtifact.payload(.motor).data
    guard bytes.count % 4 == 0, coordinate >= 0, coordinate < bytes.count / 4 else {
      throw BrainRuntimeError.invalidParameterVersion("motor coordinate is outside exact FP32 payload")
    }
    let value = bytes.withUnsafeBytes { Float(bitPattern: UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: coordinate * 4, as: UInt32.self))) }
    guard value.isFinite else { throw BrainRuntimeError.invalidParameterVersion("non-finite parent motor scalar") }
    return value
  }

  private static func requireCoordinateOnlyProbe(parent: BrainMotorStudyPublication,
    probe: BrainMotorStudyPublication, coordinate: Int) throws {
    guard probe.version.parentFingerprint == parent.version.fingerprint else {
      throw BrainRuntimeError.invalidParameterVersion("physical probe is not a direct successor")
    }
    for kind in BrainSharedParameterArtifact.requiredKinds {
      let a = parent.sharedArtifact.payload(kind).data, b = probe.sharedArtifact.payload(kind).data
      guard a.count == b.count else { throw BrainRuntimeError.invalidParameterVersion("probe changed parameter shape") }
      if kind == .motor {
        guard a.prefix(coordinate * 4) == b.prefix(coordinate * 4),
          a.dropFirst((coordinate + 1) * 4) == b.dropFirst((coordinate + 1) * 4) else {
          throw BrainRuntimeError.invalidParameterVersion("physical probe modified unrelated motor coordinates")
        }
      } else if a != b { throw BrainRuntimeError.invalidParameterVersion("physical probe modified a nonmotor component") }
    }
  }

  private static func replace(_ parent: BrainMotorStudyPublication, coordinate: Int, value: Float,
    evidence: [String]) throws -> BrainMotorStudyPublication {
    let payloads = try BrainSharedParameterArtifact.requiredKinds.map { kind -> BrainParameterPayload in
      let payload = parent.sharedArtifact.payload(kind)
      guard kind == .motor else { return payload }
      var data = payload.data, bits = value.bitPattern.littleEndian
      withUnsafeBytes(of: &bits) { data.replaceSubrange((coordinate * 4)..<((coordinate + 1) * 4), with: $0) }
      return try BrainParameterPayload(kind: kind, elementType: .fp32, data: data)
    }
    let successor = try BrainSharedParameterArtifact.successor(parentVersion: parent.version, updatedPayloads: payloads)
    return try BrainMotorStudyPublication(publication: BrainParameterPublication(version: successor.version,
      sharedArtifact: successor.artifact), evidenceSHA256: evidence)
  }
}

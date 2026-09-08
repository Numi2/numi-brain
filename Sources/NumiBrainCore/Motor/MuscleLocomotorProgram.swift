import Foundation

/// Explicit research controller parameters in delivered physical spindle units.
/// A periodic excitation candidate is not evidence of standing or walking.
public struct MuscleLocomotorChannel: Codable, Equatable, Sendable {
  public let muscleIdentifier: UInt32
  public let referenceLengthMeters: Float
  public let tonicExcitation: Float
  public let lengthGain: Float
  public let velocityGainSeconds: Float
  public let gaitSine: Float
  public let gaitCosine: Float
  public let maximumExcitation: Float

  public init(muscleIdentifier: UInt32, referenceLengthMeters: Float,
    tonicExcitation: Float, lengthGain: Float, velocityGainSeconds: Float,
    gaitSine: Float = 0, gaitCosine: Float = 0, maximumExcitation: Float = 0.95) {
    self.muscleIdentifier = muscleIdentifier; self.referenceLengthMeters = referenceLengthMeters
    self.tonicExcitation = tonicExcitation; self.lengthGain = lengthGain
    self.velocityGainSeconds = velocityGainSeconds; self.gaitSine = gaitSine
    self.gaitCosine = gaitCosine; self.maximumExcitation = maximumExcitation
  }
}

/// Immutable, source-bound muscle feedback and periodic recruitment program.
/// Zero period selects standing recruitment; nonzero period selects a gait
/// candidate. Phase is derived from committed physical time, so rejection and
/// chunking cannot advance an independent oscillator. No learned-policy
/// qualification transfers to this explicitly selected research controller.
public struct MuscleLocomotorProgram: Codable, Equatable, Sendable {
  public let version: UInt32
  public let modelSourceFingerprint: UInt64
  public let sensoryProfileFingerprint: UInt64
  public let calibrationArtifactSHA256: String
  public let epochMicroseconds: UInt64
  public let periodMicroseconds: UInt64
  public let channels: [MuscleLocomotorChannel]

  public init(modelSourceFingerprint: UInt64, sensoryProfileFingerprint: UInt64,
    calibrationArtifactSHA256: String, epochMicroseconds: UInt64 = 0,
    periodMicroseconds: UInt64 = 0, channels: [MuscleLocomotorChannel]) {
    version = 1; self.modelSourceFingerprint = modelSourceFingerprint
    self.sensoryProfileFingerprint = sensoryProfileFingerprint
    self.calibrationArtifactSHA256 = calibrationArtifactSHA256
    self.epochMicroseconds = epochMicroseconds; self.periodMicroseconds = periodMicroseconds
    self.channels = channels
  }

  public func validate(template: CompiledSpeciesTemplate) throws {
    guard version == 1, modelSourceFingerprint != 0,
      sensoryProfileFingerprint == template.sensoryProfile.fingerprint,
      BrainPolicyEvidenceArtifact.isSHA256(calibrationArtifactSHA256),
      template.species.motor.actuatorCommandKind == .muscleExcitation,
      !channels.isEmpty, channels.count <= 4096,
      channels.count == Int(template.species.motor.actuatorCount),
      periodMicroseconds == 0 || (100_000...10_000_000).contains(periodMicroseconds),
      let anatomy = template.muscleAttachmentCatalog,
      anatomy.attachments.count == channels.count,
      let proprioception = template.species.senses.first(where: { $0.enabled && $0.modality == .proprioception })
    else { throw BrainRuntimeError.invalidDescriptor("locomotor program requires exact muscle anatomy, sensor identity and calibration provenance") }
    for (index, channel) in channels.enumerated() {
      let values = [channel.referenceLengthMeters, channel.tonicExcitation, channel.lengthGain,
        channel.velocityGainSeconds, channel.gaitSine, channel.gaitCosine, channel.maximumExcitation]
      guard channel.muscleIdentifier == UInt32(index), values.allSatisfy(\.isFinite),
        (0.0001...10).contains(channel.referenceLengthMeters),
        (0...0.999).contains(channel.maximumExcitation),
        (0...channel.maximumExcitation).contains(channel.tonicExcitation),
        (0...10).contains(channel.lengthGain), (0...1).contains(channel.velocityGainSeconds),
        abs(channel.gaitSine) + abs(channel.gaitCosine) <= 0.25,
        periodMicroseconds != 0 || (channel.gaitSine == 0 && channel.gaitCosine == 0),
        anatomy.attachments.contains(where: { $0.muscleIdentifier == channel.muscleIdentifier })
      else { throw BrainRuntimeError.invalidDescriptor("locomotor channel ordering, bounds or standing/gait mode is invalid") }
      for signal in [MuscleReceptorSignal.length, .lengthVelocity] {
        let bindings = template.sensoryProfile.muscleReceptorBindings.filter {
          $0.muscleIdentifier == channel.muscleIdentifier && $0.signal == signal
        }
        guard bindings.count == 1, let binding = bindings.first,
          binding.sourceModelFingerprint == modelSourceFingerprint,
          binding.modality == .proprioception,
          binding.receptorIndex < proprioception.receptorCount,
          binding.featureIndex < proprioception.observationDimension, binding.featureIndex < 32,
          binding.scale == 1, binding.bias == 0, binding.weight == 1
        else { throw BrainRuntimeError.invalidDescriptor("locomotor feedback lacks a unique physical spindle binding") }
      }
    }
  }

  /// Canonical ordered bytes include all parameters and calibration provenance.
  public var fingerprint: UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    func bytes(_ values: [UInt8]) { for byte in values { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 } }
    func integer(_ value: UInt64) { bytes((0..<8).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }) }
    bytes(Array("NBMUSCLELOCOMOTOR1".utf8)); integer(UInt64(version))
    integer(modelSourceFingerprint); integer(sensoryProfileFingerprint)
    bytes(Array(calibrationArtifactSHA256.utf8)); integer(epochMicroseconds); integer(periodMicroseconds)
    integer(UInt64(channels.count))
    for c in channels {
      integer(UInt64(c.muscleIdentifier))
      for x in [c.referenceLengthMeters, c.tonicExcitation, c.lengthGain,
        c.velocityGainSeconds, c.gaitSine, c.gaitCosine, c.maximumExcitation] { integer(UInt64(x.bitPattern)) }
    }
    return hash
  }
}

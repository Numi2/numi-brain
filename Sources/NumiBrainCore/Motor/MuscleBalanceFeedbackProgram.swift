import Foundation

/// Selects the qualification boundary for a sparse whole-body correction
/// layered over one immutable muscle-locomotor baseline.
@frozen
public enum MuscleBalanceFeedbackMode: UInt16, Codable, CaseIterable, Sendable {
  /// Uses physically delivered body-motion receptors without claiming support
  /// awareness. This mode is useful while authoring and validating posture
  /// pathways, but is not evidence of standing balance.
  case posture = 1

  /// Requires both body-motion and physical support/load receptor evidence.
  case supportAware = 2
}

/// One calibrated scalar receptor used by the balance controller. The binding
/// identifier resolves through the exact compiled sensory profile; the source
/// cannot name simulator state or a teacher-only signal.
@frozen
public struct MuscleBalanceFeedbackSource: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt32
  public let bodyReceptorBindingIdentifier: UInt32
  public let referenceValue: Float
  public let filterTimeConstantSeconds: Float
  public let conductionDelayMicroseconds: UInt32

  public init(
    identifier: UInt32,
    bodyReceptorBindingIdentifier: UInt32,
    referenceValue: Float,
    filterTimeConstantSeconds: Float = 0,
    conductionDelayMicroseconds: UInt32 = 0
  ) {
    self.identifier = identifier
    self.bodyReceptorBindingIdentifier = bodyReceptorBindingIdentifier
    self.referenceValue = referenceValue
    self.filterTimeConstantSeconds = filterTimeConstantSeconds
    self.conductionDelayMicroseconds = conductionDelayMicroseconds
  }
}

/// Sparse signed excitation correction from one causal balance source to one
/// anatomical muscle. `maximumCorrection` bounds this route independently of
/// the baseline command and of the final protective motor adapter.
@frozen
public struct MuscleBalanceFeedbackRoute: Codable, Equatable, Hashable, Sendable {
  public let sourceIdentifier: UInt32
  public let muscleIdentifier: UInt32
  public let gain: Float
  public let maximumCorrection: Float

  public init(
    sourceIdentifier: UInt32,
    muscleIdentifier: UInt32,
    gain: Float,
    maximumCorrection: Float = 0.25
  ) {
    self.sourceIdentifier = sourceIdentifier
    self.muscleIdentifier = muscleIdentifier
    self.gain = gain
    self.maximumCorrection = maximumCorrection
  }
}

/// Immutable, source-bound whole-body feedback layered over one exact
/// `MuscleLocomotorProgram`. It describes only causal neural correction. The
/// physical owner retains activation, tendon, force, contact, and motion.
///
/// Runtime integration must hold the prepared baseline while required delayed
/// history is unavailable. It must not reinterpret missing observations as a
/// valid zero balance error or publish controller history before root commit.
@frozen
public struct MuscleBalanceFeedbackProgram: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let version: UInt32
  public let locomotorProgramFingerprint: UInt64
  public let modelSourceFingerprint: UInt64
  public let sensoryProfileFingerprint: UInt64
  public let calibrationArtifactSHA256: String
  public let mode: MuscleBalanceFeedbackMode
  public let updatePeriodMicroseconds: UInt32
  public let initializationDurationMicroseconds: UInt32
  public let sources: [MuscleBalanceFeedbackSource]
  public let routes: [MuscleBalanceFeedbackRoute]

  public init(
    locomotorProgramFingerprint: UInt64,
    modelSourceFingerprint: UInt64,
    sensoryProfileFingerprint: UInt64,
    calibrationArtifactSHA256: String,
    mode: MuscleBalanceFeedbackMode,
    updatePeriodMicroseconds: UInt32,
    initializationDurationMicroseconds: UInt32 = 0,
    sources: [MuscleBalanceFeedbackSource],
    routes: [MuscleBalanceFeedbackRoute]
  ) {
    version = Self.formatVersion
    self.locomotorProgramFingerprint = locomotorProgramFingerprint
    self.modelSourceFingerprint = modelSourceFingerprint
    self.sensoryProfileFingerprint = sensoryProfileFingerprint
    self.calibrationArtifactSHA256 = calibrationArtifactSHA256
    self.mode = mode
    self.updatePeriodMicroseconds = updatePeriodMicroseconds
    self.initializationDurationMicroseconds = initializationDurationMicroseconds
    self.sources = sources
    self.routes = routes
  }

  /// Largest exact neural-delivery delay represented by the bounded history
  /// ring. Delays are integer multiples of `updatePeriodMicroseconds`.
  public var maximumConductionDelayMicroseconds: UInt32 {
    sources.map(\.conductionDelayMicroseconds).max() ?? 0
  }

  /// Stateful execution is required for either an explicit delay or a causal
  /// low-pass filter. Stateless programs retain the direct source path.
  public var requiresTransactionalHistory: Bool {
    sources.contains {
      $0.conductionDelayMicroseconds > 0
        || $0.filterTimeConstantSeconds > 0
    }
  }

  /// One slot for every delayed update plus the current sample. Invalid decoded
  /// clocks saturate rather than trapping before `validate` can reject them.
  public var historyCapacity: UInt32 {
    guard updatePeriodMicroseconds > 0 else { return 0 }
    let quotient = maximumConductionDelayMicroseconds
      / updatePeriodMicroseconds
    let (capacity, overflow) = quotient.addingReportingOverflow(1)
    return overflow ? .max : capacity
  }

  /// A stateful controller must remain on its prepared baseline until delayed
  /// evidence exists. Filtered sources receive at least one additional update
  /// to initialize their committed filter state before corrections are enabled.
  /// Invalid decoded clocks saturate so validation remains fail-closed.
  public var minimumInitializationDurationMicroseconds: UInt32 {
    let extra = sources.contains { $0.filterTimeConstantSeconds > 0 }
      ? updatePeriodMicroseconds : 0
    let (duration, overflow) = maximumConductionDelayMicroseconds
      .addingReportingOverflow(extra)
    return overflow ? .max : duration
  }

  public func validate(
    template: CompiledSpeciesTemplate,
    locomotorProgram: MuscleLocomotorProgram
  ) throws {
    try locomotorProgram.validateBaseline(template: template)
    guard version == Self.formatVersion,
      locomotorProgramFingerprint == locomotorProgram.baselineFingerprint,
      modelSourceFingerprint == locomotorProgram.modelSourceFingerprint,
      sensoryProfileFingerprint == template.sensoryProfile.fingerprint,
      sensoryProfileFingerprint == locomotorProgram.sensoryProfileFingerprint,
      BrainPolicyEvidenceArtifact.isSHA256(calibrationArtifactSHA256),
      template.species.motor.actuatorCommandKind == .muscleExcitation,
      (1_000...20_000).contains(updatePeriodMicroseconds),
      initializationDurationMicroseconds <= 1_000_000,
      initializationDurationMicroseconds % updatePeriodMicroseconds == 0,
      initializationDurationMicroseconds
        >= minimumInitializationDurationMicroseconds,
      historyCapacity > 0, historyCapacity <= 501,
      !sources.isEmpty, sources.count <= 64,
      !routes.isEmpty, routes.count <= 65_536
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "balance feedback requires one exact locomotor baseline, sensor generation, and bounded clock"
      )
    }

    let sourceIdentifiers = sources.map(\.identifier)
    let bindingIdentifiers = sources.map(\.bodyReceptorBindingIdentifier)
    guard !sourceIdentifiers.contains(0),
      Set(sourceIdentifiers).count == sources.count,
      Set(bindingIdentifiers).count == sources.count
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "balance feedback sources require unique nonzero identities and receptor bindings"
      )
    }

    let bodyBindings = Dictionary(
      uniqueKeysWithValues: template.sensoryProfile.bodyReceptorBindings.map {
        ($0.identifier, $0)
      }
    )
    var resolvedBindings: [UInt32: BodyReceptorBinding] = [:]
    for source in sources {
      guard source.referenceValue.isFinite,
        source.filterTimeConstantSeconds.isFinite,
        (0...1).contains(source.filterTimeConstantSeconds),
        source.conductionDelayMicroseconds <= 500_000,
        source.conductionDelayMicroseconds % updatePeriodMicroseconds == 0,
        let binding = bodyBindings[source.bodyReceptorBindingIdentifier],
        binding.sourceModelFingerprint == modelSourceFingerprint
      else {
        throw BrainRuntimeError.invalidDescriptor(
          "balance feedback source calibration or physical receptor provenance is invalid"
        )
      }
      resolvedBindings[source.identifier] = binding
    }

    let kinematicSignals: Set<BodyReceptorSignal> = [
      .position, .velocity, .orientation, .angularVelocity,
      .vestibularStability,
    ]
    let supportSignals: Set<BodyReceptorSignal> = [.support, .localForce]
    let muscleIdentifiers = Set(locomotorProgram.channels.map(\.muscleIdentifier))
    var routeKeys = Set<UInt64>()
    var routedSourceIdentifiers = Set<UInt32>()
    var maximumCorrectionByMuscle: [UInt32: Float] = [:]
    var routedSignals = Set<BodyReceptorSignal>()
    for route in routes {
      let key = UInt64(route.sourceIdentifier) << 32 | UInt64(route.muscleIdentifier)
      let cumulativeMaximum =
        maximumCorrectionByMuscle[route.muscleIdentifier, default: 0]
        + route.maximumCorrection
      guard let binding = resolvedBindings[route.sourceIdentifier],
        muscleIdentifiers.contains(route.muscleIdentifier),
        route.gain.isFinite, route.gain != 0, abs(route.gain) <= 10,
        route.maximumCorrection.isFinite, route.maximumCorrection > 0,
        route.maximumCorrection <= 0.5, cumulativeMaximum <= 0.5,
        routeKeys.insert(key).inserted
      else {
        throw BrainRuntimeError.invalidDescriptor(
          "balance feedback route is duplicated, unbound, or outside bounded excitation correction"
        )
      }
      maximumCorrectionByMuscle[route.muscleIdentifier] = cumulativeMaximum
      routedSourceIdentifiers.insert(route.sourceIdentifier)
      routedSignals.insert(binding.signal)
    }
    guard routedSourceIdentifiers == Set(sourceIdentifiers),
      !routedSignals.isDisjoint(with: kinematicSignals),
      mode != .supportAware || !routedSignals.isDisjoint(with: supportSignals)
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "balance feedback requires every declared source to be routed and causal kinematic evidence; support-aware feedback also requires routed support/load evidence"
      )
    }
  }

  /// Canonical ordered bytes bind the exact baseline, receptors, timing,
  /// filtering, delays, and sparse muscle corrections.
  public var fingerprint: UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    func bytes(_ values: [UInt8]) {
      for byte in values {
        hash = (hash ^ UInt64(byte)) &* 0x100000001b3
      }
    }
    func integer(_ value: UInt64) {
      bytes((0..<8).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) })
    }

    bytes(Array("NBMUSCLEBALANCE1".utf8))
    integer(UInt64(version))
    integer(locomotorProgramFingerprint)
    integer(modelSourceFingerprint)
    integer(sensoryProfileFingerprint)
    bytes(Array(calibrationArtifactSHA256.utf8))
    integer(UInt64(mode.rawValue))
    integer(UInt64(updatePeriodMicroseconds))
    integer(UInt64(initializationDurationMicroseconds))
    integer(UInt64(sources.count))
    for source in sources.sorted(by: { $0.identifier < $1.identifier }) {
      integer(UInt64(source.identifier))
      integer(UInt64(source.bodyReceptorBindingIdentifier))
      integer(UInt64(source.referenceValue.bitPattern))
      integer(UInt64(source.filterTimeConstantSeconds.bitPattern))
      integer(UInt64(source.conductionDelayMicroseconds))
    }
    integer(UInt64(routes.count))
    for route in routes.sorted(by: {
      ($0.sourceIdentifier, $0.muscleIdentifier)
        < ($1.sourceIdentifier, $1.muscleIdentifier)
    }) {
      integer(UInt64(route.sourceIdentifier))
      integer(UInt64(route.muscleIdentifier))
      integer(UInt64(route.gain.bitPattern))
      integer(UInt64(route.maximumCorrection.bitPattern))
    }
    return hash
  }
}

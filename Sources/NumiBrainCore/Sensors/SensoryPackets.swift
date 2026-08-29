import Foundation

@frozen
public struct SensoryObservationView: Codable, Equatable, Sendable {
  public let modality: SensoryModality
  public let receptorTimestamp: BrainTimestamp
  public let deliveryTimestamp: BrainTimestamp
  public let receptorCount: UInt32
  public let featureDimension: UInt32
  public let values: [Float]
  public let adaptationState: [Float]
  public let validityMask: [UInt32]

  public init(
    modality: SensoryModality,
    receptorTimestamp: BrainTimestamp,
    deliveryTimestamp: BrainTimestamp,
    receptorCount: UInt32,
    featureDimension: UInt32,
    values: [Float],
    adaptationState: [Float],
    validityMask: [UInt32]
  ) throws {
    let scalarCount = UInt64(receptorCount) * UInt64(featureDimension)
    guard receptorCount > 0, featureDimension > 0,
      scalarCount <= UInt64(Int.max), values.count == Int(scalarCount),
      values.allSatisfy(\.isFinite),
      adaptationState.count == Int(receptorCount),
      adaptationState.allSatisfy(\.isFinite),
      validityMask.count == Int(receptorCount),
      receptorTimestamp <= deliveryTimestamp
    else {
      throw BrainRuntimeError.invalidEvent("sensory observation view is invalid")
    }
    self.modality = modality
    self.receptorTimestamp = receptorTimestamp
    self.deliveryTimestamp = deliveryTimestamp
    self.receptorCount = receptorCount
    self.featureDimension = featureDimension
    self.values = values
    self.adaptationState = adaptationState
    self.validityMask = validityMask
  }

  public var ageMicroseconds: UInt64 {
    deliveryTimestamp.rawValue - receptorTimestamp.rawValue
  }
}

@frozen
public struct ObservationPacket: Codable, Equatable, Sendable {
  public let committedTimestamp: BrainTimestamp
  public let sensorViews: [SensoryObservationView]
  public let receptorEvents: [ReceptorEventToken]

  public init(
    committedTimestamp: BrainTimestamp,
    sensorViews: [SensoryObservationView],
    receptorEvents: [ReceptorEventToken],
    species: SpeciesTemplate
  ) throws {
    let enabledModalities = Set(species.senses.filter(\.enabled).map(\.modality))
    let topologyByModality = Dictionary(
      uniqueKeysWithValues: species.senses.map { ($0.modality, $0) }
    )
    guard Set(sensorViews.map(\.modality)).count == sensorViews.count,
      Set(sensorViews.map(\.modality)) == enabledModalities,
      sensorViews.allSatisfy({ view in
        guard let topology = topologyByModality[view.modality] else { return false }
        return view.deliveryTimestamp == committedTimestamp
          && view.receptorCount == topology.receptorCount
          && view.featureDimension == topology.observationDimension
          && view.ageMicroseconds == UInt64(topology.latencyMicroseconds)
      }),
      receptorEvents.allSatisfy({ $0.timestamp <= committedTimestamp })
    else {
      throw BrainRuntimeError.invalidEvent(
        "observation packet violates causal or species topology"
      )
    }
    self.committedTimestamp = committedTimestamp
    self.sensorViews = sensorViews.sorted { $0.modality.rawValue < $1.modality.rawValue }
    self.receptorEvents = receptorEvents.sorted { $0.timestamp < $1.timestamp }
  }

  public func view(_ modality: SensoryModality) -> SensoryObservationView? {
    sensorViews.first { $0.modality == modality }
  }
}

/// Privileged state is a separate training-only value. No actor/belief packet
/// contains this type, preventing accidental normal-observation wiring.
@frozen
public struct BrainTeacherPacket: Codable, Equatable, Sendable {
  public let timestamp: BrainTimestamp
  public let authoritativeBodyState: [Float]
  public let authoritativeEntityState: [Float]
  public let contactLabels: [UInt32]
  public let forceLabels: [Float]
  public let damageLabels: [Float]
  public let taskLabels: [UInt32]
  /// Optional actor-space target from an observed or teacher-controlled action.
  /// It remains training-only and never enters the normal observation graph.
  public let demonstratedAction: [Float]

  public init(
    timestamp: BrainTimestamp,
    authoritativeBodyState: [Float],
    authoritativeEntityState: [Float],
    contactLabels: [UInt32],
    forceLabels: [Float],
    damageLabels: [Float],
    taskLabels: [UInt32],
    demonstratedAction: [Float] = []
  ) throws {
    guard authoritativeBodyState.allSatisfy(\.isFinite),
      authoritativeEntityState.allSatisfy(\.isFinite),
      forceLabels.allSatisfy(\.isFinite), damageLabels.allSatisfy(\.isFinite),
      demonstratedAction.allSatisfy(\.isFinite),
      demonstratedAction.isEmpty || demonstratedAction.count == 16
    else {
      throw BrainRuntimeError.invalidEvent("teacher packet is invalid")
    }
    self.timestamp = timestamp
    self.authoritativeBodyState = authoritativeBodyState
    self.authoritativeEntityState = authoritativeEntityState
    self.contactLabels = contactLabels
    self.forceLabels = forceLabels
    self.damageLabels = damageLabels
    self.taskLabels = taskLabels
    self.demonstratedAction = demonstratedAction
  }

  private enum CodingKeys: String, CodingKey {
    case timestamp
    case authoritativeBodyState
    case authoritativeEntityState
    case contactLabels
    case forceLabels
    case damageLabels
    case taskLabels
    case demonstratedAction
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      timestamp: values.decode(BrainTimestamp.self, forKey: .timestamp),
      authoritativeBodyState: values.decode(
        [Float].self, forKey: .authoritativeBodyState
      ),
      authoritativeEntityState: values.decode(
        [Float].self, forKey: .authoritativeEntityState
      ),
      contactLabels: values.decode([UInt32].self, forKey: .contactLabels),
      forceLabels: values.decode([Float].self, forKey: .forceLabels),
      damageLabels: values.decode([Float].self, forKey: .damageLabels),
      taskLabels: values.decode([UInt32].self, forKey: .taskLabels),
      demonstratedAction: values.decodeIfPresent(
        [Float].self, forKey: .demonstratedAction
      ) ?? []
    )
  }
}

@frozen
public struct BrainInputPacket: Codable, Equatable, Sendable {
  public let environmentIdentifier: UInt32
  public let episodeIdentifier: UInt64
  public let controlStepIdentifier: UInt64
  public let physicalSubstepIdentifier: UInt32
  public let parameterVersionFingerprint: UInt64
  public let transactionGeneration: UInt64
  public let observation: ObservationPacket

  public init(
    environmentIdentifier: UInt32,
    episodeIdentifier: UInt64,
    controlStepIdentifier: UInt64,
    physicalSubstepIdentifier: UInt32,
    parameterVersionFingerprint: UInt64,
    transactionGeneration: UInt64,
    observation: ObservationPacket
  ) throws {
    guard parameterVersionFingerprint > 0, transactionGeneration > 0 else {
      throw BrainRuntimeError.transaction("brain input transaction identity is invalid")
    }
    self.environmentIdentifier = environmentIdentifier
    self.episodeIdentifier = episodeIdentifier
    self.controlStepIdentifier = controlStepIdentifier
    self.physicalSubstepIdentifier = physicalSubstepIdentifier
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.transactionGeneration = transactionGeneration
    self.observation = observation
  }
}

@frozen
public struct SomaticActionCommand: Codable, Equatable, Hashable, Sendable {
  public let muscleExcitations: [Float]
  public let synergyCoefficients: [Float]
  public let impedanceTargets: [Float]
  public let movementDurationMicroseconds: UInt64
  public let emergencyStopMask: [UInt32]

  public init(
    muscleExcitations: [Float],
    synergyCoefficients: [Float],
    impedanceTargets: [Float],
    movementDurationMicroseconds: UInt64,
    emergencyStopMask: [UInt32],
    motor: MotorTopology
  ) throws {
    guard muscleExcitations.count == Int(motor.actuatorCount),
      muscleExcitations.allSatisfy({
        $0.isFinite && (motor.outputMinimum...motor.outputMaximum).contains($0)
      }),
      synergyCoefficients.count == Int(motor.synergyCount),
      synergyCoefficients.allSatisfy(\.isFinite),
      impedanceTargets.count == Int(motor.actuatorCount),
      impedanceTargets.allSatisfy({ $0.isFinite && $0 >= 0 }),
      movementDurationMicroseconds > 0,
      emergencyStopMask.count == Int(motor.actuatorCount)
    else {
      throw BrainRuntimeError.transaction("somatic action command is invalid")
    }
    self.muscleExcitations = muscleExcitations
    self.synergyCoefficients = synergyCoefficients
    self.impedanceTargets = impedanceTargets
    self.movementDurationMicroseconds = movementDurationMicroseconds
    self.emergencyStopMask = emergencyStopMask
  }
}

@frozen
public struct AutonomicActionCommand: Codable, Equatable, Hashable, Sendable {
  public let values: [Float]

  public init(values: [Float], physiology: PhysiologyTemplate) throws {
    guard values.count == Int(physiology.autonomicActionDimension),
      values.allSatisfy({ $0.isFinite && (0...1).contains($0) })
    else {
      throw BrainRuntimeError.transaction("autonomic action command is invalid")
    }
    self.values = values
  }
}

@frozen
public struct ActiveSensingCommand: Codable, Equatable, Hashable, Sendable {
  public let values: [Float]
  public let attentionAllocationMask: [UInt32]

  public init(
    values: [Float],
    attentionAllocationMask: [UInt32],
    motor: MotorTopology
  ) throws {
    guard values.count == Int(motor.activeSensingActionDimension),
      values.allSatisfy(\.isFinite)
    else {
      throw BrainRuntimeError.transaction("active-sensing command is invalid")
    }
    self.values = values
    self.attentionAllocationMask = attentionAllocationMask
  }
}

@frozen
public enum InternalActionKind: UInt16, Codable, CaseIterable, Sendable {
  case retrieveMemory = 1
  case writeWorkspace = 2
  case clearWorkspace = 3
  case allocateRoute = 4
  case beginPlanning = 5
  case endPlanning = 6
  case deliberateInhibition = 7
  case allocateReplay = 8
}

@frozen
public struct InternalActionCommand: Codable, Equatable, Hashable, Sendable {
  public let kind: InternalActionKind
  public let targetIdentifier: UInt64?
  public let parameters: BrainLatentVector
  public let priority: Float

  public init(
    kind: InternalActionKind,
    targetIdentifier: UInt64?,
    parameters: BrainLatentVector,
    priority: Float
  ) throws {
    guard priority.isFinite, priority >= 0 else {
      throw BrainRuntimeError.transaction("internal action command is invalid")
    }
    self.kind = kind
    self.targetIdentifier = targetIdentifier
    self.parameters = parameters
    self.priority = priority
  }
}

@frozen
public struct PredictedRiskEnvelope: Codable, Equatable, Hashable, Sendable {
  public let damageMean: Float
  public let damageCVaR: Float
  public let failureProbability: Float
  public let unsupportedUncertainty: Float
  public let horizonMicroseconds: UInt64

  public init(
    damageMean: Float,
    damageCVaR: Float,
    failureProbability: Float,
    unsupportedUncertainty: Float,
    horizonMicroseconds: UInt64
  ) throws {
    guard damageMean.isFinite, damageMean >= 0,
      damageCVaR.isFinite, damageCVaR >= damageMean,
      failureProbability.isFinite, (0...1).contains(failureProbability),
      unsupportedUncertainty.isFinite, unsupportedUncertainty >= 0,
      horizonMicroseconds > 0
    else {
      throw BrainRuntimeError.transaction("predicted risk envelope is invalid")
    }
    self.damageMean = damageMean
    self.damageCVaR = damageCVaR
    self.failureProbability = failureProbability
    self.unsupportedUncertainty = unsupportedUncertainty
    self.horizonMicroseconds = horizonMicroseconds
  }
}

@frozen
public struct BrainOutputPacket: Codable, Equatable, Sendable {
  public let somatic: SomaticActionCommand
  public let autonomic: AutonomicActionCommand
  public let activeSensing: ActiveSensingCommand
  public let internalActions: [InternalActionCommand]
  public let activeOptionIdentifier: UInt64?
  public let optionParameters: BrainLatentVector?
  public let planningActive: Bool
  public let confidence: Float
  public let risk: PredictedRiskEnvelope
  public let transactionFingerprint: UInt64
  public let shadowGeneration: UInt64
  public let randomCounterGeneration: UInt64
  public let pendingMemoryJournalOffset: UInt64

  public init(
    somatic: SomaticActionCommand,
    autonomic: AutonomicActionCommand,
    activeSensing: ActiveSensingCommand,
    internalActions: [InternalActionCommand],
    activeOptionIdentifier: UInt64?,
    optionParameters: BrainLatentVector?,
    planningActive: Bool,
    confidence: Float,
    risk: PredictedRiskEnvelope,
    transactionFingerprint: UInt64,
    shadowGeneration: UInt64,
    randomCounterGeneration: UInt64,
    pendingMemoryJournalOffset: UInt64
  ) throws {
    guard (activeOptionIdentifier == nil) == (optionParameters == nil),
      confidence.isFinite, (0...1).contains(confidence),
      transactionFingerprint > 0, shadowGeneration > 0
    else {
      throw BrainRuntimeError.transaction("brain output packet is invalid")
    }
    self.somatic = somatic
    self.autonomic = autonomic
    self.activeSensing = activeSensing
    self.internalActions = internalActions
    self.activeOptionIdentifier = activeOptionIdentifier
    self.optionParameters = optionParameters
    self.planningActive = planningActive
    self.confidence = confidence
    self.risk = risk
    self.transactionFingerprint = transactionFingerprint
    self.shadowGeneration = shadowGeneration
    self.randomCounterGeneration = randomCounterGeneration
    self.pendingMemoryJournalOffset = pendingMemoryJournalOffset
  }
}

import Foundation

@frozen
public enum SpeciesFamily: UInt16, Codable, CaseIterable, Sendable {
  case human = 1
  case quadruped = 2
  case bird = 3
  case genericRobot = 4
  case custom = 65_535
}

@frozen
public struct SpeciesBodyTopology: Codable, Equatable, Hashable, Sendable {
  public let bodyCount: UInt32
  public let jointCount: UInt32
  public let muscleCount: UInt32
  public let muscleAttachmentFingerprint: UInt64
  public let skinSurfaceCount: UInt32
  public let actuatorCount: UInt32
  public let morphologyCode: UInt64

  public init(
    bodyCount: UInt32,
    jointCount: UInt32,
    muscleCount: UInt32,
    muscleAttachmentFingerprint: UInt64,
    skinSurfaceCount: UInt32,
    actuatorCount: UInt32,
    morphologyCode: UInt64
  ) throws {
    guard bodyCount > 0, jointCount > 0, muscleCount > 0,
      muscleAttachmentFingerprint > 0, skinSurfaceCount > 0,
      actuatorCount > 0, morphologyCode > 0
    else {
      throw BrainRuntimeError.invalidDescriptor("species body topology is incomplete")
    }
    self.bodyCount = bodyCount
    self.jointCount = jointCount
    self.muscleCount = muscleCount
    self.muscleAttachmentFingerprint = muscleAttachmentFingerprint
    self.skinSurfaceCount = skinSurfaceCount
    self.actuatorCount = actuatorCount
    self.morphologyCode = morphologyCode
  }
}

@frozen
public enum SensoryModality: UInt16, Codable, CaseIterable, Sendable {
  case vision = 1
  case audition = 2
  case touch = 3
  case proprioception = 4
  case vestibular = 5
  case olfaction = 6
  case gustation = 7
  case interoception = 8
}

@frozen
public struct SensoryTopology: Codable, Equatable, Hashable, Sendable {
  public let modality: SensoryModality
  public let receptorCount: UInt32
  public let observationDimension: UInt32
  public let latencyMicroseconds: UInt32
  public let adaptationTimeConstantMicroseconds: UInt32
  public let noiseStandardDeviation: Float
  public let activeSensingActionDimension: UInt16
  public let enabled: Bool

  public init(
    modality: SensoryModality,
    receptorCount: UInt32,
    observationDimension: UInt32,
    latencyMicroseconds: UInt32,
    adaptationTimeConstantMicroseconds: UInt32,
    noiseStandardDeviation: Float,
    activeSensingActionDimension: UInt16,
    enabled: Bool
  ) throws {
    guard !enabled || (receptorCount > 0 && observationDimension > 0),
      adaptationTimeConstantMicroseconds > 0,
      noiseStandardDeviation.isFinite, noiseStandardDeviation >= 0
    else {
      throw BrainRuntimeError.invalidDescriptor("sensory topology is invalid")
    }
    self.modality = modality
    self.receptorCount = receptorCount
    self.observationDimension = observationDimension
    self.latencyMicroseconds = latencyMicroseconds
    self.adaptationTimeConstantMicroseconds = adaptationTimeConstantMicroseconds
    self.noiseStandardDeviation = noiseStandardDeviation
    self.activeSensingActionDimension = activeSensingActionDimension
    self.enabled = enabled
  }
}

@frozen
public enum ActuatorCommandKind: UInt16, Codable, CaseIterable, Sendable {
  case muscleExcitation = 1
  case motorCurrent = 2
  case torque = 3
  case velocity = 4
  case position = 5
  case impedance = 6
  case pressure = 7
}

@frozen
public enum CommunicationEffectorKind: UInt16, Codable, CaseIterable, Sendable {
  case vocalization = 1
  case gesture = 2
  case facialExpression = 3
  case sign = 4
  case writtenSymbol = 5
  case robotChannel = 6
}

/// Species-owned embodiment map for communication. The compiler never
/// invents actuator anatomy: a template must name every vocal, gestural,
/// facial, signing, writing, or robot output channel it makes available.
@frozen
public struct CommunicationEffectorTemplate: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt16
  public let kind: CommunicationEffectorKind
  public let actuatorIdentifiers: [UInt32]
  public let synergyIdentifiers: [UInt16]
  public let activeSensingChannelIdentifiers: [UInt16]
  public let gain: Float

  public init(
    identifier: UInt16,
    kind: CommunicationEffectorKind,
    actuatorIdentifiers: [UInt32],
    synergyIdentifiers: [UInt16],
    activeSensingChannelIdentifiers: [UInt16],
    gain: Float
  ) throws {
    guard identifier > 0,
      !actuatorIdentifiers.isEmpty || !synergyIdentifiers.isEmpty
        || !activeSensingChannelIdentifiers.isEmpty,
      Set(actuatorIdentifiers).count == actuatorIdentifiers.count,
      Set(synergyIdentifiers).count == synergyIdentifiers.count,
      Set(activeSensingChannelIdentifiers).count
        == activeSensingChannelIdentifiers.count,
      gain.isFinite, gain >= 0
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "communication effector template is invalid"
      )
    }
    self.identifier = identifier
    self.kind = kind
    self.actuatorIdentifiers = actuatorIdentifiers.sorted()
    self.synergyIdentifiers = synergyIdentifiers.sorted()
    self.activeSensingChannelIdentifiers = activeSensingChannelIdentifiers.sorted()
    self.gain = gain
  }
}

@frozen
public struct MotorTopology: Codable, Equatable, Hashable, Sendable {
  public let actuatorCommandKind: ActuatorCommandKind
  public let actuatorCount: UInt32
  public let synergyCount: UInt16
  public let motorNucleusCount: UInt16
  public let autonomicActionDimension: UInt16
  public let activeSensingActionDimension: UInt16
  public let outputMinimum: Float
  public let outputMaximum: Float
  public let communicationEffectors: [CommunicationEffectorTemplate]

  public init(
    actuatorCommandKind: ActuatorCommandKind,
    actuatorCount: UInt32,
    synergyCount: UInt16,
    motorNucleusCount: UInt16,
    autonomicActionDimension: UInt16,
    activeSensingActionDimension: UInt16,
    outputMinimum: Float,
    outputMaximum: Float,
    communicationEffectors: [CommunicationEffectorTemplate] = []
  ) throws {
    let communicationEffectors = communicationEffectors.sorted {
      $0.identifier < $1.identifier
    }
    let communicationActuators = communicationEffectors.flatMap(\.actuatorIdentifiers)
    let communicationSynergies = communicationEffectors.flatMap(\.synergyIdentifiers)
    let communicationSensingChannels = communicationEffectors.flatMap(
      \.activeSensingChannelIdentifiers
    )
    guard actuatorCount > 0, synergyCount > 0, motorNucleusCount > 0,
      outputMinimum.isFinite, outputMaximum.isFinite,
      outputMinimum < outputMaximum,
      Set(communicationEffectors.map(\.identifier)).count
        == communicationEffectors.count,
      Set(communicationActuators).count == communicationActuators.count,
      Set(communicationSynergies).count == communicationSynergies.count,
      Set(communicationSensingChannels).count
        == communicationSensingChannels.count,
      communicationActuators.allSatisfy({ $0 < actuatorCount }),
      communicationSynergies.allSatisfy({ $0 < synergyCount }),
      communicationSensingChannels.allSatisfy({
        $0 < activeSensingActionDimension
      })
    else {
      throw BrainRuntimeError.invalidDescriptor("motor topology is invalid")
    }
    self.actuatorCommandKind = actuatorCommandKind
    self.actuatorCount = actuatorCount
    self.synergyCount = synergyCount
    self.motorNucleusCount = motorNucleusCount
    self.autonomicActionDimension = autonomicActionDimension
    self.activeSensingActionDimension = activeSensingActionDimension
    self.outputMinimum = outputMinimum
    self.outputMaximum = outputMaximum
    self.communicationEffectors = communicationEffectors
  }
}

@frozen
public enum ReflexKind: UInt16, Codable, CaseIterable, Sendable {
  case stretch = 1
  case tendonUnloading = 2
  case withdrawal = 3
  case crossedExtension = 4
  case loadCompensation = 5
  case contactStabilization = 6
  case jointLimitProtection = 7
  case vestibulospinal = 8
  case painInhibition = 9
  case muscleOverloadInhibition = 10
  case righting = 11
  case perching = 12
}

@frozen
public struct ReflexCircuitTemplate: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt16
  public let kind: ReflexKind
  public let receptorChannelCodes: [UInt32]
  public let actuatorIdentifiers: [UInt32]
  public let latencyMicroseconds: UInt32
  public let activationThreshold: Float
  public let gain: Float
  public let innateEnabled: Bool

  public init(
    identifier: UInt16,
    kind: ReflexKind,
    receptorChannelCodes: [UInt32],
    actuatorIdentifiers: [UInt32],
    latencyMicroseconds: UInt32,
    activationThreshold: Float,
    gain: Float,
    innateEnabled: Bool
  ) throws {
    guard identifier > 0, !receptorChannelCodes.isEmpty,
      !actuatorIdentifiers.isEmpty, latencyMicroseconds > 0,
      Set(receptorChannelCodes).count == receptorChannelCodes.count,
      Set(actuatorIdentifiers).count == actuatorIdentifiers.count,
      activationThreshold.isFinite, activationThreshold >= 0,
      gain.isFinite
    else {
      throw BrainRuntimeError.invalidDescriptor("reflex circuit template is invalid")
    }
    self.identifier = identifier
    self.kind = kind
    self.receptorChannelCodes = receptorChannelCodes.sorted()
    self.actuatorIdentifiers = actuatorIdentifiers.sorted()
    self.latencyMicroseconds = latencyMicroseconds
    self.activationThreshold = activationThreshold
    self.gain = gain
    self.innateEnabled = innateEnabled
  }
}

@frozen
public struct CPGOscillatorTemplate: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt16
  public let naturalFrequencyHertz: Float
  public let dutyFactor: Float
  public let outputSynergyIdentifier: UInt16
  public let sensoryResetMask: BrainInterruptMask

  public init(
    identifier: UInt16,
    naturalFrequencyHertz: Float,
    dutyFactor: Float,
    outputSynergyIdentifier: UInt16,
    sensoryResetMask: BrainInterruptMask
  ) throws {
    guard identifier > 0,
      naturalFrequencyHertz.isFinite, naturalFrequencyHertz > 0,
      dutyFactor.isFinite, dutyFactor > 0, dutyFactor <= 1
    else {
      throw BrainRuntimeError.invalidDescriptor("CPG oscillator is invalid")
    }
    self.identifier = identifier
    self.naturalFrequencyHertz = naturalFrequencyHertz
    self.dutyFactor = dutyFactor
    self.outputSynergyIdentifier = outputSynergyIdentifier
    self.sensoryResetMask = sensoryResetMask
  }
}

@frozen
public struct CPGCouplingTemplate: Codable, Equatable, Hashable, Sendable {
  public let sourceOscillatorIdentifier: UInt16
  public let destinationOscillatorIdentifier: UInt16
  /// Desired source-to-destination phase relation in radians.
  public let phaseOffset: Float
  /// Maximum signed coupling correction in cycles per second.
  public let gain: Float

  public init(
    sourceOscillatorIdentifier: UInt16,
    destinationOscillatorIdentifier: UInt16,
    phaseOffset: Float,
    gain: Float
  ) throws {
    guard sourceOscillatorIdentifier != destinationOscillatorIdentifier,
      phaseOffset.isFinite, gain.isFinite
    else {
      throw BrainRuntimeError.invalidDescriptor("CPG coupling is invalid")
    }
    self.sourceOscillatorIdentifier = sourceOscillatorIdentifier
    self.destinationOscillatorIdentifier = destinationOscillatorIdentifier
    self.phaseOffset = phaseOffset
    self.gain = gain
  }
}

@frozen
public struct CPGTopology: Codable, Equatable, Hashable, Sendable {
  public let oscillators: [CPGOscillatorTemplate]
  public let couplings: [CPGCouplingTemplate]

  public init(
    oscillators: [CPGOscillatorTemplate],
    couplings: [CPGCouplingTemplate]
  ) throws {
    let identifiers = Set(oscillators.map(\.identifier))
    let couplingEdges = couplings.map {
      (UInt32($0.sourceOscillatorIdentifier) << 16)
        | UInt32($0.destinationOscillatorIdentifier)
    }
    guard oscillators.count <= 64,
      identifiers.count == oscillators.count,
      Set(couplingEdges).count == couplingEdges.count,
      couplings.allSatisfy({
        identifiers.contains($0.sourceOscillatorIdentifier)
          && identifiers.contains($0.destinationOscillatorIdentifier)
      })
    else {
      throw BrainRuntimeError.invalidDescriptor("CPG graph is invalid")
    }
    self.oscillators = oscillators.sorted { $0.identifier < $1.identifier }
    self.couplings = couplings.sorted { lhs, rhs in
      if lhs.sourceOscillatorIdentifier != rhs.sourceOscillatorIdentifier {
        return lhs.sourceOscillatorIdentifier < rhs.sourceOscillatorIdentifier
      }
      return lhs.destinationOscillatorIdentifier < rhs.destinationOscillatorIdentifier
    }
  }
}

@frozen
public enum PhysiologyModelClass: UInt16, Codable, CaseIterable, Sendable {
  case reducedBiological = 1
  case detailedBiological = 2
  case artificialEnergyThermal = 3
}

@frozen
public struct PhysiologyTemplate: Codable, Equatable, Hashable, Sendable {
  public let modelClass: PhysiologyModelClass
  public let stateDimension: UInt16
  public let autonomicActionDimension: UInt16
  public let viableMinimums: [Float]
  public let viableMaximums: [Float]
  public let criticalMinimums: [Float]
  public let criticalMaximums: [Float]

  public init(
    modelClass: PhysiologyModelClass,
    stateDimension: UInt16,
    autonomicActionDimension: UInt16,
    viableMinimums: [Float],
    viableMaximums: [Float],
    criticalMinimums: [Float],
    criticalMaximums: [Float]
  ) throws {
    let count = Int(stateDimension)
    guard stateDimension > 0, autonomicActionDimension > 0,
      [viableMinimums, viableMaximums, criticalMinimums, criticalMaximums]
        .allSatisfy({ $0.count == count && $0.allSatisfy(\.isFinite) }),
      (0..<count).allSatisfy({ index in
        criticalMinimums[index] <= viableMinimums[index]
          && viableMinimums[index] <= viableMaximums[index]
          && viableMaximums[index] <= criticalMaximums[index]
      })
    else {
      throw BrainRuntimeError.invalidDescriptor("physiology template is invalid")
    }
    self.modelClass = modelClass
    self.stateDimension = stateDimension
    self.autonomicActionDimension = autonomicActionDimension
    self.viableMinimums = viableMinimums
    self.viableMaximums = viableMaximums
    self.criticalMinimums = criticalMinimums
    self.criticalMaximums = criticalMaximums
  }
}

@frozen
public enum InnateBehaviorKind: UInt16, Codable, CaseIterable, Sendable {
  case withdrawal = 1
  case jointProtection = 2
  case startle = 3
  case righting = 4
  case vestibularStabilization = 5
  case painRouting = 6
  case restSleep = 7
  case vitalAutonomic = 8
  case ingestive = 9
}

@frozen
public struct InnateBehaviorTemplate: Codable, Equatable, Hashable, Sendable {
  public let kind: InnateBehaviorKind
  public let controllerModuleIdentifier: UInt16
  public let enabledFromStage: DevelopmentalStage
  public let gain: Float

  public init(
    kind: InnateBehaviorKind,
    controllerModuleIdentifier: UInt16,
    enabledFromStage: DevelopmentalStage,
    gain: Float
  ) throws {
    guard controllerModuleIdentifier > 0, gain.isFinite, gain >= 0 else {
      throw BrainRuntimeError.invalidDescriptor("innate behavior template is invalid")
    }
    self.kind = kind
    self.controllerModuleIdentifier = controllerModuleIdentifier
    self.enabledFromStage = enabledFromStage
    self.gain = gain
  }
}

@frozen
public struct DevelopmentalStageTemplate: Codable, Equatable, Hashable, Sendable {
  public let stage: DevelopmentalStage
  public let unlockedModuleIdentifiers: [UInt16]
  public let learningRateMultiplier: Float
  public let sensorPrecisionMultiplier: Float
  public let muscleStrengthMultiplier: Float
  public let planningHorizonSteps: UInt16
  public let workspaceCapacity: UInt16
  public let capabilityGateCodes: [UInt64]

  public init(
    stage: DevelopmentalStage,
    unlockedModuleIdentifiers: [UInt16],
    learningRateMultiplier: Float,
    sensorPrecisionMultiplier: Float,
    muscleStrengthMultiplier: Float,
    planningHorizonSteps: UInt16,
    workspaceCapacity: UInt16,
    capabilityGateCodes: [UInt64]
  ) throws {
    guard Set(unlockedModuleIdentifiers).count == unlockedModuleIdentifiers.count,
      learningRateMultiplier.isFinite, learningRateMultiplier >= 0,
      sensorPrecisionMultiplier.isFinite, sensorPrecisionMultiplier >= 0,
      muscleStrengthMultiplier.isFinite, muscleStrengthMultiplier >= 0,
      planningHorizonSteps <= 64, workspaceCapacity > 0,
      Set(capabilityGateCodes).count == capabilityGateCodes.count
    else {
      throw BrainRuntimeError.invalidDescriptor("developmental stage template is invalid")
    }
    self.stage = stage
    self.unlockedModuleIdentifiers = unlockedModuleIdentifiers.sorted()
    self.learningRateMultiplier = learningRateMultiplier
    self.sensorPrecisionMultiplier = sensorPrecisionMultiplier
    self.muscleStrengthMultiplier = muscleStrengthMultiplier
    self.planningHorizonSteps = planningHorizonSteps
    self.workspaceCapacity = workspaceCapacity
    self.capabilityGateCodes = capabilityGateCodes.sorted()
  }
}

@frozen
public struct SpeciesTemplate: Codable, Equatable, Sendable {
  /// Version 2 makes the identity content-address every runtime-affecting
  /// species field, including protective circuits and developmental capacity.
  public static let formatVersion: UInt32 = 2

  public let family: SpeciesFamily
  public let name: String
  public let referenceGraphFingerprint: UInt64
  public let regionGraph: SpeciesRegionGraph
  public let enabledModuleIdentifiers: [UInt16]
  public let body: SpeciesBodyTopology
  public let senses: [SensoryTopology]
  public let motor: MotorTopology
  public let reflexes: [ReflexCircuitTemplate]
  public let cpg: CPGTopology
  public let physiology: PhysiologyTemplate
  public let innateBehaviors: [InnateBehaviorTemplate]
  public let development: [DevelopmentalStageTemplate]
  public let capacities: BrainCapacityProfile
  public let fingerprint: UInt64

  public init(
    family: SpeciesFamily,
    name: String,
    referenceGraph: ReferenceBrainGraph,
    enabledModuleIdentifiers: [UInt16],
    regionGraph requestedRegionGraph: SpeciesRegionGraph? = nil,
    body: SpeciesBodyTopology,
    senses: [SensoryTopology],
    motor: MotorTopology,
    reflexes: [ReflexCircuitTemplate],
    cpg: CPGTopology,
    physiology: PhysiologyTemplate,
    innateBehaviors: [InnateBehaviorTemplate],
    development: [DevelopmentalStageTemplate],
    capacities: BrainCapacityProfile
  ) throws {
    let enabled = enabledModuleIdentifiers.sorted()
    let regionGraph = try requestedRegionGraph ?? SpeciesRegionGraph.referenceSubset(
      referenceGraph: referenceGraph,
      enabledModuleIdentifiers: enabled
    )
    let regionalIdentifiers = regionGraph.modules.map(\.identifier)
    var reflexRuleCount = 0
    var reflexRuleCountOverflow = false
    for reflex in reflexes {
      let product = reflex.receptorChannelCodes.count.multipliedReportingOverflow(
        by: reflex.actuatorIdentifiers.count
      )
      let total = reflexRuleCount.addingReportingOverflow(product.partialValue)
      reflexRuleCount = total.partialValue
      reflexRuleCountOverflow = reflexRuleCountOverflow || product.overflow
        || total.overflow
    }
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !enabled.isEmpty, Set(enabled).count == enabled.count,
      regionGraph.referenceGraphFingerprint == referenceGraph.fingerprint,
      enabled == regionalIdentifiers,
      senses.count == SensoryModality.allCases.count,
      Set(senses.map(\.modality)).count == senses.count,
      senses.contains(where: \.enabled),
      motor.actuatorCount == body.actuatorCount,
      motor.autonomicActionDimension == physiology.autonomicActionDimension,
      Set(reflexes.map(\.identifier)).count == reflexes.count,
      !reflexRuleCountOverflow, reflexRuleCount <= 4_096,
      reflexes.allSatisfy({ reflex in
        reflex.actuatorIdentifiers.allSatisfy({ $0 < motor.actuatorCount })
      }),
      cpg.oscillators.allSatisfy({
        $0.outputSynergyIdentifier < motor.synergyCount
      }),
      innateBehaviors.allSatisfy({ enabled.contains($0.controllerModuleIdentifier) }),
      development.map(\.stage) == DevelopmentalStage.allCases,
      development.dropFirst().allSatisfy({ !$0.capabilityGateCodes.isEmpty }),
      development.allSatisfy({ stage in
        Set(stage.unlockedModuleIdentifiers).isSubset(of: Set(enabled))
          && stage.workspaceCapacity <= capacities.workspaceTokenCapacity
      })
    else {
      throw BrainRuntimeError.invalidDescriptor("species template is inconsistent")
    }
    var hash: UInt64 = 14_695_981_039_346_656_037
    Self.mix(Self.formatVersion, into: &hash)
    Self.mix(UInt32(family.rawValue), into: &hash)
    Self.mix(referenceGraph.fingerprint, into: &hash)
    Self.mix(regionGraph.fingerprint, into: &hash)
    Self.mix(body.bodyCount, into: &hash)
    Self.mix(body.jointCount, into: &hash)
    Self.mix(body.muscleCount, into: &hash)
    Self.mix(body.muscleAttachmentFingerprint, into: &hash)
    Self.mix(body.skinSurfaceCount, into: &hash)
    Self.mix(body.actuatorCount, into: &hash)
    Self.mix(body.morphologyCode, into: &hash)
    Self.mix(UInt32(name.utf8.count), into: &hash)
    for byte in name.utf8 { Self.mix(byte, into: &hash) }
    Self.mix(UInt32(enabled.count), into: &hash)
    for identifier in enabled { Self.mix(UInt32(identifier), into: &hash) }
    let canonicalSenses = senses.sorted {
      $0.modality.rawValue < $1.modality.rawValue
    }
    Self.mix(UInt32(canonicalSenses.count), into: &hash)
    for sense in canonicalSenses {
      Self.mix(UInt32(sense.modality.rawValue), into: &hash)
      Self.mix(sense.receptorCount, into: &hash)
      Self.mix(sense.observationDimension, into: &hash)
      Self.mix(sense.latencyMicroseconds, into: &hash)
      Self.mix(sense.adaptationTimeConstantMicroseconds, into: &hash)
      Self.mix(sense.noiseStandardDeviation.bitPattern, into: &hash)
      Self.mix(UInt32(sense.activeSensingActionDimension), into: &hash)
      Self.mix(UInt8(sense.enabled ? 1 : 0), into: &hash)
    }
    Self.mix(UInt32(motor.actuatorCommandKind.rawValue), into: &hash)
    Self.mix(motor.actuatorCount, into: &hash)
    Self.mix(UInt32(motor.synergyCount), into: &hash)
    Self.mix(UInt32(motor.motorNucleusCount), into: &hash)
    Self.mix(UInt32(motor.autonomicActionDimension), into: &hash)
    Self.mix(UInt32(motor.activeSensingActionDimension), into: &hash)
    Self.mix(motor.outputMinimum.bitPattern, into: &hash)
    Self.mix(motor.outputMaximum.bitPattern, into: &hash)
    Self.mix(UInt32(motor.communicationEffectors.count), into: &hash)
    for effector in motor.communicationEffectors {
      Self.mix(UInt32(effector.identifier), into: &hash)
      Self.mix(UInt32(effector.kind.rawValue), into: &hash)
      Self.mix(effector.gain.bitPattern, into: &hash)
      Self.mix(UInt32(effector.actuatorIdentifiers.count), into: &hash)
      for identifier in effector.actuatorIdentifiers {
        Self.mix(identifier, into: &hash)
      }
      Self.mix(UInt32(effector.synergyIdentifiers.count), into: &hash)
      for identifier in effector.synergyIdentifiers {
        Self.mix(UInt32(identifier), into: &hash)
      }
      Self.mix(
        UInt32(effector.activeSensingChannelIdentifiers.count), into: &hash
      )
      for identifier in effector.activeSensingChannelIdentifiers {
        Self.mix(UInt32(identifier), into: &hash)
      }
    }
    let canonicalReflexes = reflexes.sorted { $0.identifier < $1.identifier }
    Self.mix(UInt32(canonicalReflexes.count), into: &hash)
    for reflex in canonicalReflexes {
      Self.mix(UInt32(reflex.identifier), into: &hash)
      Self.mix(UInt32(reflex.kind.rawValue), into: &hash)
      Self.mix(UInt32(reflex.receptorChannelCodes.count), into: &hash)
      for channel in reflex.receptorChannelCodes { Self.mix(channel, into: &hash) }
      Self.mix(UInt32(reflex.actuatorIdentifiers.count), into: &hash)
      for actuator in reflex.actuatorIdentifiers { Self.mix(actuator, into: &hash) }
      Self.mix(reflex.latencyMicroseconds, into: &hash)
      Self.mix(reflex.activationThreshold.bitPattern, into: &hash)
      Self.mix(reflex.gain.bitPattern, into: &hash)
      Self.mix(UInt8(reflex.innateEnabled ? 1 : 0), into: &hash)
    }
    Self.mix(UInt32(cpg.oscillators.count), into: &hash)
    for oscillator in cpg.oscillators {
      Self.mix(UInt32(oscillator.identifier), into: &hash)
      Self.mix(oscillator.naturalFrequencyHertz.bitPattern, into: &hash)
      Self.mix(oscillator.dutyFactor.bitPattern, into: &hash)
      Self.mix(UInt32(oscillator.outputSynergyIdentifier), into: &hash)
      Self.mix(oscillator.sensoryResetMask.rawValue, into: &hash)
    }
    Self.mix(UInt32(cpg.couplings.count), into: &hash)
    for coupling in cpg.couplings {
      Self.mix(UInt32(coupling.sourceOscillatorIdentifier), into: &hash)
      Self.mix(UInt32(coupling.destinationOscillatorIdentifier), into: &hash)
      Self.mix(coupling.phaseOffset.bitPattern, into: &hash)
      Self.mix(coupling.gain.bitPattern, into: &hash)
    }
    Self.mix(UInt32(physiology.modelClass.rawValue), into: &hash)
    Self.mix(UInt32(physiology.stateDimension), into: &hash)
    Self.mix(UInt32(physiology.autonomicActionDimension), into: &hash)
    for values in [
      physiology.viableMinimums, physiology.viableMaximums,
      physiology.criticalMinimums, physiology.criticalMaximums,
    ] {
      Self.mix(UInt32(values.count), into: &hash)
      for value in values { Self.mix(value.bitPattern, into: &hash) }
    }
    let canonicalInnateBehaviors = innateBehaviors.sorted { lhs, rhs in
      if lhs.kind != rhs.kind { return lhs.kind.rawValue < rhs.kind.rawValue }
      return lhs.controllerModuleIdentifier < rhs.controllerModuleIdentifier
    }
    Self.mix(UInt32(canonicalInnateBehaviors.count), into: &hash)
    for behavior in canonicalInnateBehaviors {
      Self.mix(UInt32(behavior.kind.rawValue), into: &hash)
      Self.mix(UInt32(behavior.controllerModuleIdentifier), into: &hash)
      Self.mix(UInt32(behavior.enabledFromStage.rawValue), into: &hash)
      Self.mix(behavior.gain.bitPattern, into: &hash)
    }
    Self.mix(UInt32(development.count), into: &hash)
    for stage in development {
      Self.mix(UInt32(stage.stage.rawValue), into: &hash)
      Self.mix(UInt32(stage.unlockedModuleIdentifiers.count), into: &hash)
      for identifier in stage.unlockedModuleIdentifiers {
        Self.mix(UInt32(identifier), into: &hash)
      }
      Self.mix(stage.learningRateMultiplier.bitPattern, into: &hash)
      Self.mix(stage.sensorPrecisionMultiplier.bitPattern, into: &hash)
      Self.mix(stage.muscleStrengthMultiplier.bitPattern, into: &hash)
      Self.mix(UInt32(stage.planningHorizonSteps), into: &hash)
      Self.mix(UInt32(stage.workspaceCapacity), into: &hash)
      Self.mix(UInt32(stage.capabilityGateCodes.count), into: &hash)
      for code in stage.capabilityGateCodes { Self.mix(code, into: &hash) }
    }
    Self.mix(capacities.activeRecurrentScalarCapacity, into: &hash)
    Self.mix(UInt32(capacities.workspaceTokenCapacity), into: &hash)
    Self.mix(UInt32(capacities.workspaceTokenDimension), into: &hash)
    Self.mix(UInt32(capacities.objectSlotCapacity), into: &hash)
    Self.mix(UInt32(capacities.otherAgentSlotCapacity), into: &hash)
    Self.mix(capacities.activeEpisodicCapacity, into: &hash)
    Self.mix(capacities.compressedEpisodicCapacity, into: &hash)
    Self.mix(capacities.archiveEpisodicCapacity, into: &hash)
    Self.mix(capacities.semanticConceptCapacity, into: &hash)
    Self.mix(capacities.semanticRelationCapacity, into: &hash)
    Self.mix(capacities.proceduralSkillCapacity, into: &hash)
    Self.mix(UInt32(capacities.prospectiveIntentionCapacity), into: &hash)
    Self.mix(UInt32(capacities.fastPlasticityCapacity), into: &hash)
    Self.mix(UInt32(capacities.activeOptionCandidateCapacity), into: &hash)
    Self.mix(UInt32(capacities.cerebellarExpertCapacity), into: &hash)
    Self.mix(UInt32(capacities.activeCerebellarExpertCapacity), into: &hash)
    self.family = family
    self.name = name
    self.referenceGraphFingerprint = referenceGraph.fingerprint
    self.regionGraph = regionGraph
    self.enabledModuleIdentifiers = enabled
    self.body = body
    self.senses = canonicalSenses
    self.motor = motor
    self.reflexes = canonicalReflexes
    self.cpg = cpg
    self.physiology = physiology
    self.innateBehaviors = canonicalInnateBehaviors
    self.development = development
    self.capacities = capacities
    self.fingerprint = hash
  }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }

  public func regionalProgram(
    historyCapacity: Int = RegionalTokenProgram.routeHistoryCapacity
  ) throws -> RegionalTokenProgram {
    try regionGraph.regionalProgram(historyCapacity: historyCapacity)
  }

  private static func mix(_ value: UInt8, into hash: inout UInt64) {
    hash ^= UInt64(value)
    hash &*= 1_099_511_628_211
  }

  private static func mix(_ value: UInt32, into hash: inout UInt64) {
    mix(UInt64(value), into: &hash)
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
      for byte in bytes { mix(byte, into: &hash) }
    }
  }
}

public enum SpeciesTemplateCompiler {
  /// Compiles the reference graph against authoritative morphology and
  /// receptor descriptors. The caller supplies measured counts and endpoint
  /// identity; the compiler does not invent anatomy.
  public static func compileMammalianReference(
    family: SpeciesFamily,
    name: String,
    body: SpeciesBodyTopology,
    senses: [SensoryTopology],
    motor: MotorTopology,
    reflexes: [ReflexCircuitTemplate],
    cpg: CPGTopology,
    physiology: PhysiologyTemplate,
    innateBehaviors: [InnateBehaviorTemplate],
    development: [DevelopmentalStageTemplate],
    capacities: BrainCapacityProfile
  ) throws -> SpeciesTemplate {
    let graph = try ReferenceBrainGraph.mammalianV1()
    return try SpeciesTemplate(
      family: family,
      name: name,
      referenceGraph: graph,
      enabledModuleIdentifiers: graph.modules.map(\.identifier),
      body: body,
      senses: senses,
      motor: motor,
      reflexes: reflexes,
      cpg: cpg,
      physiology: physiology,
      innateBehaviors: innateBehaviors,
      development: development,
      capacities: capacities
    )
  }

  /// Compiles a split, merged, reduced, or species-extended graph against
  /// authoritative morphology. Custom regions retain explicit provenance to
  /// the 96 reference roles or carry a nonzero species-specific role code.
  public static func compileSpecializedReference(
    family: SpeciesFamily,
    name: String,
    regionGraph: SpeciesRegionGraph,
    body: SpeciesBodyTopology,
    senses: [SensoryTopology],
    motor: MotorTopology,
    reflexes: [ReflexCircuitTemplate],
    cpg: CPGTopology,
    physiology: PhysiologyTemplate,
    innateBehaviors: [InnateBehaviorTemplate],
    development: [DevelopmentalStageTemplate],
    capacities: BrainCapacityProfile
  ) throws -> SpeciesTemplate {
    let reference = try ReferenceBrainGraph.mammalianV1()
    guard regionGraph.referenceGraphFingerprint == reference.fingerprint else {
      throw BrainRuntimeError.invalidDescriptor(
        "specialized graph does not derive from the authoritative reference"
      )
    }
    return try SpeciesTemplate(
      family: family,
      name: name,
      referenceGraph: reference,
      enabledModuleIdentifiers: regionGraph.modules.map(\.identifier),
      regionGraph: regionGraph,
      body: body,
      senses: senses,
      motor: motor,
      reflexes: reflexes,
      cpg: cpg,
      physiology: physiology,
      innateBehaviors: innateBehaviors,
      development: development,
      capacities: capacities
    )
  }
}

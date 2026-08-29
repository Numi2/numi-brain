import Foundation

@frozen
public enum DevelopmentalStage: UInt16, Codable, CaseIterable, Comparable, Sendable {
  case innateScaffold = 0
  case spontaneousMovement = 1
  case bodySchemaFormation = 2
  case cerebellarCalibration = 3
  case postureAndLocomotion = 4
  case manipulationAndActiveSensing = 5
  case objectAndSceneUnderstanding = 6
  case episodicAndProceduralMemory = 7
  case planningAndAutonomy = 8
  case socialDevelopment = 9
  case communicationAndLanguage = 10
  case openEndedLife = 11

  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

@frozen
public enum CriticalPeriodKind: UInt16, Codable, CaseIterable, Sendable {
  case sensorCalibration = 1
  case bodyOwnership = 2
  case balance = 3
  case motorCoordination = 4
  case objectPermanence = 5
  case socialAttachment = 6
  case imitation = 7
  case communication = 8
}

@frozen
public struct CriticalPeriodState: Codable, Equatable, Hashable, Sendable {
  public let kind: CriticalPeriodKind
  public let openedAtAgeMicroseconds: UInt64
  public let closesAtAgeMicroseconds: UInt64?
  public let plasticityMultiplier: Float
  public let active: Bool

  public init(
    kind: CriticalPeriodKind,
    openedAtAgeMicroseconds: UInt64,
    closesAtAgeMicroseconds: UInt64?,
    plasticityMultiplier: Float,
    active: Bool
  ) throws {
    guard closesAtAgeMicroseconds == nil
      || closesAtAgeMicroseconds! >= openedAtAgeMicroseconds,
      plasticityMultiplier.isFinite, plasticityMultiplier >= 0
    else {
      throw BrainRuntimeError.transaction("critical-period state is invalid")
    }
    self.kind = kind
    self.openedAtAgeMicroseconds = openedAtAgeMicroseconds
    self.closesAtAgeMicroseconds = closesAtAgeMicroseconds
    self.plasticityMultiplier = plasticityMultiplier
    self.active = active
  }
}

@frozen
public struct RegionalMaturationState: Codable, Equatable, Hashable, Sendable {
  public let moduleIdentifier: UInt16
  public let learningRateMultiplier: Float
  public let timescaleMultiplier: Float
  public let routeGainMultiplier: Float
  public let conductionDelayMultiplier: Float
  public let capacityFraction: Float
  public let unlocked: Bool

  public init(
    moduleIdentifier: UInt16,
    learningRateMultiplier: Float,
    timescaleMultiplier: Float,
    routeGainMultiplier: Float,
    conductionDelayMultiplier: Float,
    capacityFraction: Float,
    unlocked: Bool
  ) throws {
    let values = [
      learningRateMultiplier, timescaleMultiplier, routeGainMultiplier,
      conductionDelayMultiplier, capacityFraction,
    ]
    guard moduleIdentifier > 0, values.allSatisfy({ $0.isFinite && $0 >= 0 }),
      capacityFraction <= 1
    else {
      throw BrainRuntimeError.transaction("regional maturation state is invalid")
    }
    self.moduleIdentifier = moduleIdentifier
    self.learningRateMultiplier = learningRateMultiplier
    self.timescaleMultiplier = timescaleMultiplier
    self.routeGainMultiplier = routeGainMultiplier
    self.conductionDelayMultiplier = conductionDelayMultiplier
    self.capacityFraction = capacityFraction
    self.unlocked = unlocked
  }
}

@frozen
public struct BrainCapacityProfile: Codable, Equatable, Hashable, Sendable {
  public let activeRecurrentScalarCapacity: UInt32
  public let workspaceTokenCapacity: UInt16
  public let workspaceTokenDimension: UInt16
  public let objectSlotCapacity: UInt16
  public let otherAgentSlotCapacity: UInt16
  public let activeEpisodicCapacity: UInt32
  public let compressedEpisodicCapacity: UInt32
  public let archiveEpisodicCapacity: UInt32
  public let semanticConceptCapacity: UInt32
  public let semanticRelationCapacity: UInt32
  public let proceduralSkillCapacity: UInt32
  public let prospectiveIntentionCapacity: UInt16
  public let fastPlasticityCapacity: UInt16
  public let activeOptionCandidateCapacity: UInt16
  public let cerebellarExpertCapacity: UInt16
  public let activeCerebellarExpertCapacity: UInt16

  public init(
    activeRecurrentScalarCapacity: UInt32,
    workspaceTokenCapacity: UInt16,
    workspaceTokenDimension: UInt16,
    objectSlotCapacity: UInt16,
    otherAgentSlotCapacity: UInt16,
    activeEpisodicCapacity: UInt32,
    compressedEpisodicCapacity: UInt32,
    archiveEpisodicCapacity: UInt32,
    semanticConceptCapacity: UInt32,
    semanticRelationCapacity: UInt32,
    proceduralSkillCapacity: UInt32,
    prospectiveIntentionCapacity: UInt16,
    fastPlasticityCapacity: UInt16,
    activeOptionCandidateCapacity: UInt16,
    cerebellarExpertCapacity: UInt16,
    activeCerebellarExpertCapacity: UInt16
  ) throws {
    guard activeRecurrentScalarCapacity > 0, workspaceTokenCapacity > 0,
      workspaceTokenDimension > 0, activeEpisodicCapacity > 0,
      archiveEpisodicCapacity >= activeEpisodicCapacity,
      semanticConceptCapacity > 0, semanticRelationCapacity > 0,
      proceduralSkillCapacity > 0, prospectiveIntentionCapacity > 0,
      fastPlasticityCapacity > 0, activeOptionCandidateCapacity > 0,
      cerebellarExpertCapacity > 0,
      activeCerebellarExpertCapacity > 0,
      activeCerebellarExpertCapacity <= cerebellarExpertCapacity
    else {
      throw BrainRuntimeError.capacity("brain capacity profile is invalid")
    }
    self.activeRecurrentScalarCapacity = activeRecurrentScalarCapacity
    self.workspaceTokenCapacity = workspaceTokenCapacity
    self.workspaceTokenDimension = workspaceTokenDimension
    self.objectSlotCapacity = objectSlotCapacity
    self.otherAgentSlotCapacity = otherAgentSlotCapacity
    self.activeEpisodicCapacity = activeEpisodicCapacity
    self.compressedEpisodicCapacity = compressedEpisodicCapacity
    self.archiveEpisodicCapacity = archiveEpisodicCapacity
    self.semanticConceptCapacity = semanticConceptCapacity
    self.semanticRelationCapacity = semanticRelationCapacity
    self.proceduralSkillCapacity = proceduralSkillCapacity
    self.prospectiveIntentionCapacity = prospectiveIntentionCapacity
    self.fastPlasticityCapacity = fastPlasticityCapacity
    self.activeOptionCandidateCapacity = activeOptionCandidateCapacity
    self.cerebellarExpertCapacity = cerebellarExpertCapacity
    self.activeCerebellarExpertCapacity = activeCerebellarExpertCapacity
  }

  public static var fullCognitiveV1: Self {
    get throws {
      try Self(
        activeRecurrentScalarCapacity: 32_768,
        workspaceTokenCapacity: 16,
        workspaceTokenDimension: 256,
        objectSlotCapacity: 32,
        otherAgentSlotCapacity: 8,
        activeEpisodicCapacity: 128,
        compressedEpisodicCapacity: 4_096,
        archiveEpisodicCapacity: 1_048_576,
        semanticConceptCapacity: 65_536,
        semanticRelationCapacity: 262_144,
        proceduralSkillCapacity: 4_096,
        prospectiveIntentionCapacity: 256,
        fastPlasticityCapacity: 4_096,
        activeOptionCandidateCapacity: 32,
        cerebellarExpertCapacity: 128,
        activeCerebellarExpertCapacity: 4
      )
    }
  }
}

@frozen
public struct BrainDevelopmentalState: Codable, Equatable, Sendable {
  public let developmentalAgeMicroseconds: UInt64
  public let stage: DevelopmentalStage
  public let maturationProgress: Float
  public let sensorPrecisionMultiplier: Float
  public let muscleStrengthMultiplier: Float
  public let replayAllocationMultiplier: Float
  public let criticalPeriods: [CriticalPeriodState]
  public let regions: [RegionalMaturationState]
  public let capacities: BrainCapacityProfile
  public let capabilityEvidenceCodes: [UInt64]

  public init(
    developmentalAgeMicroseconds: UInt64,
    stage: DevelopmentalStage,
    maturationProgress: Float,
    sensorPrecisionMultiplier: Float,
    muscleStrengthMultiplier: Float,
    replayAllocationMultiplier: Float,
    criticalPeriods: [CriticalPeriodState],
    regions: [RegionalMaturationState],
    capacities: BrainCapacityProfile,
    capabilityEvidenceCodes: [UInt64]
  ) throws {
    let scalars = [
      maturationProgress, sensorPrecisionMultiplier, muscleStrengthMultiplier,
      replayAllocationMultiplier,
    ]
    guard maturationProgress.isFinite, (0...1).contains(maturationProgress),
      scalars.dropFirst().allSatisfy({ $0.isFinite && $0 >= 0 }),
      Set(criticalPeriods.map(\.kind)).count == criticalPeriods.count,
      Set(regions.map(\.moduleIdentifier)).count == regions.count,
      Set(capabilityEvidenceCodes).count == capabilityEvidenceCodes.count
    else {
      throw BrainRuntimeError.transaction("developmental state is invalid")
    }
    self.developmentalAgeMicroseconds = developmentalAgeMicroseconds
    self.stage = stage
    self.maturationProgress = maturationProgress
    self.sensorPrecisionMultiplier = sensorPrecisionMultiplier
    self.muscleStrengthMultiplier = muscleStrengthMultiplier
    self.replayAllocationMultiplier = replayAllocationMultiplier
    self.criticalPeriods = criticalPeriods
    self.regions = regions.sorted { $0.moduleIdentifier < $1.moduleIdentifier }
    self.capacities = capacities
    self.capabilityEvidenceCodes = capabilityEvidenceCodes
  }
}

/// Content-addressed evidence emitted by a GPU capability evaluator from a
/// committed physical consequence. It can unlock a named developmental gate;
/// elapsed age alone never can.
@frozen
public struct DevelopmentalCapabilityEvidence: Codable, Equatable, Hashable, Sendable {
  public let code: UInt64
  public let timestamp: BrainTimestamp
  public let acceptedPhysicsStateFingerprint: UInt64
  public let confidence: Float

  public init(
    code: UInt64,
    timestamp: BrainTimestamp,
    acceptedPhysicsStateFingerprint: UInt64,
    confidence: Float
  ) throws {
    guard code > 0, acceptedPhysicsStateFingerprint > 0,
      confidence.isFinite, (0...1).contains(confidence)
    else {
      throw BrainRuntimeError.transaction("developmental capability evidence is invalid")
    }
    self.code = code
    self.timestamp = timestamp
    self.acceptedPhysicsStateFingerprint = acceptedPhysicsStateFingerprint
    self.confidence = confidence
  }
}

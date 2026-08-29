import Foundation

@frozen
public struct DecisionDynamics: Codable, Equatable, Hashable, Sendable {
  public let riskWeight: Float
  public let damageRiskBudget: Float
  public let switchingMargin: Float
  public let curiosityWeight: Float
  public let planningCostWeight: Float
  public let motorGain: Float
  public let stiffnessGain: Float
  public let dampingGain: Float

  public init(
    riskWeight: Float,
    damageRiskBudget: Float,
    switchingMargin: Float,
    curiosityWeight: Float,
    planningCostWeight: Float,
    motorGain: Float,
    stiffnessGain: Float,
    dampingGain: Float
  ) throws {
    let values = [
      riskWeight, damageRiskBudget, switchingMargin, curiosityWeight,
      planningCostWeight, motorGain, stiffnessGain, dampingGain,
    ]
    guard values.allSatisfy({ $0.isFinite && $0 >= 0 }), damageRiskBudget <= 1 else {
      throw BrainRuntimeError.transaction("decision dynamics are invalid")
    }
    self.riskWeight = riskWeight
    self.damageRiskBudget = damageRiskBudget
    self.switchingMargin = switchingMargin
    self.curiosityWeight = curiosityWeight
    self.planningCostWeight = planningCostWeight
    self.motorGain = motorGain
    self.stiffnessGain = stiffnessGain
    self.dampingGain = dampingGain
  }

  public static var foundationV1: Self {
    get throws {
      try Self(
        riskWeight: 2,
        damageRiskBudget: 0.35,
        switchingMargin: 0.1,
        curiosityWeight: 0.25,
        planningCostWeight: 0.05,
        motorGain: 1,
        stiffnessGain: 0.75,
        dampingGain: 0.5
      )
    }
  }
}

@frozen
public enum GoalOrigin: UInt16, Codable, CaseIterable, Sendable {
  case physiological = 1
  case externalTask = 2
  case prospectiveMemory = 3
  case socialRequest = 4
  case curiosity = 5
  case threatAvoidance = 6
  case activePlan = 7
  case communication = 8
  case learnedPreference = 9
}

@frozen
public struct ActiveGoal: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt64
  public let origin: GoalOrigin
  public let targetState: BrainLatentVector
  public let priority: Float
  public let deadline: BrainTimestamp?
  public let successModel: BrainLatentVector
  public let failureModel: BrainLatentVector
  public let damageRiskBudget: Float
  public let persistence: Float
  public let createdTimestamp: BrainTimestamp

  public init(
    identifier: UInt64,
    origin: GoalOrigin,
    targetState: BrainLatentVector,
    priority: Float,
    deadline: BrainTimestamp?,
    successModel: BrainLatentVector,
    failureModel: BrainLatentVector,
    damageRiskBudget: Float,
    persistence: Float,
    createdTimestamp: BrainTimestamp
  ) throws {
    guard identifier > 0, priority.isFinite, priority >= 0,
      deadline == nil || deadline! >= createdTimestamp,
      damageRiskBudget.isFinite, damageRiskBudget >= 0,
      persistence.isFinite, (0...1).contains(persistence)
    else {
      throw BrainRuntimeError.transaction("active goal is invalid")
    }
    self.identifier = identifier
    self.origin = origin
    self.targetState = targetState
    self.priority = priority
    self.deadline = deadline
    self.successModel = successModel
    self.failureModel = failureModel
    self.damageRiskBudget = damageRiskBudget
    self.persistence = persistence
    self.createdTimestamp = createdTimestamp
  }
}

@frozen
public enum ControlMode: UInt16, Codable, CaseIterable, Sendable {
  case reflex = 1
  case procedural = 2
  case planning = 3
}

@frozen
public struct OptionValueEstimate: Codable, Equatable, Hashable, Sendable {
  public let task: Float
  public let homeostatic: Float
  public let social: Float
  public let expectedInformationGain: Float
  public let damageCVaR: Float
  public let effortCost: Float
  public let switchingCost: Float
  public let persistenceBonus: Float
  public let competenceBonus: Float

  public init(
    task: Float,
    homeostatic: Float,
    social: Float,
    expectedInformationGain: Float,
    damageCVaR: Float,
    effortCost: Float,
    switchingCost: Float,
    persistenceBonus: Float,
    competenceBonus: Float
  ) throws {
    let values = [
      task, homeostatic, social, expectedInformationGain, damageCVaR,
      effortCost, switchingCost, persistenceBonus, competenceBonus,
    ]
    guard values.allSatisfy(\.isFinite), expectedInformationGain >= 0,
      damageCVaR >= 0, effortCost >= 0, switchingCost >= 0
    else {
      throw BrainRuntimeError.transaction("option value estimate is invalid")
    }
    self.task = task
    self.homeostatic = homeostatic
    self.social = social
    self.expectedInformationGain = expectedInformationGain
    self.damageCVaR = damageCVaR
    self.effortCost = effortCost
    self.switchingCost = switchingCost
    self.persistenceBonus = persistenceBonus
    self.competenceBonus = competenceBonus
  }

  public func score(riskWeight: Float) throws -> Float {
    guard riskWeight.isFinite, riskWeight >= 0 else {
      throw BrainRuntimeError.transaction("option risk weight is invalid")
    }
    return task + homeostatic + social + expectedInformationGain
      - riskWeight * damageCVaR - effortCost - switchingCost
      + persistenceBonus + competenceBonus
  }
}

@frozen
public struct OptionCandidate: Codable, Equatable, Hashable, Sendable {
  public let skillIdentifier: UInt64
  public let parameters: BrainLatentVector
  public let value: OptionValueEstimate
  public let initiationProbability: Float
  public let terminationProbability: Float
  public let competence: Float
  public let proposalSourceModule: UInt16

  public init(
    skillIdentifier: UInt64,
    parameters: BrainLatentVector,
    value: OptionValueEstimate,
    initiationProbability: Float,
    terminationProbability: Float,
    competence: Float,
    proposalSourceModule: UInt16
  ) throws {
    guard skillIdentifier > 0, proposalSourceModule > 0,
      [initiationProbability, terminationProbability, competence].allSatisfy({
        $0.isFinite && (0...1).contains($0)
      })
    else {
      throw BrainRuntimeError.transaction("option candidate is invalid")
    }
    self.skillIdentifier = skillIdentifier
    self.parameters = parameters
    self.value = value
    self.initiationProbability = initiationProbability
    self.terminationProbability = terminationProbability
    self.competence = competence
    self.proposalSourceModule = proposalSourceModule
  }
}

@frozen
public struct PlannedOptionStep: Codable, Equatable, Hashable, Sendable {
  public let skillIdentifier: UInt64
  public let parameters: BrainLatentVector
  public let predictedState: BrainLatentVector
  public let predictedDrives: [Float]
  public let predictedDamageCVaR: Float
  public let epistemicUncertainty: Float
  public let durationMicroseconds: UInt64

  public init(
    skillIdentifier: UInt64,
    parameters: BrainLatentVector,
    predictedState: BrainLatentVector,
    predictedDrives: [Float],
    predictedDamageCVaR: Float,
    epistemicUncertainty: Float,
    durationMicroseconds: UInt64
  ) throws {
    guard skillIdentifier > 0, predictedDrives.count == DriveKind.allCases.count,
      predictedDrives.allSatisfy(\.isFinite),
      predictedDamageCVaR.isFinite, predictedDamageCVaR >= 0,
      epistemicUncertainty.isFinite, epistemicUncertainty >= 0,
      durationMicroseconds > 0
    else {
      throw BrainRuntimeError.transaction("planned option step is invalid")
    }
    self.skillIdentifier = skillIdentifier
    self.parameters = parameters
    self.predictedState = predictedState
    self.predictedDrives = predictedDrives
    self.predictedDamageCVaR = predictedDamageCVaR
    self.epistemicUncertainty = epistemicUncertainty
    self.durationMicroseconds = durationMicroseconds
  }
}

@frozen
public struct ActiveOptionPlan: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt64
  public let goalIdentifier: UInt64
  public let steps: [PlannedOptionStep]
  public let objectiveValue: Float
  public let admissible: Bool
  public let modelParameterFingerprint: UInt64
  public let createdTimestamp: BrainTimestamp

  public init(
    identifier: UInt64,
    goalIdentifier: UInt64,
    steps: [PlannedOptionStep],
    objectiveValue: Float,
    admissible: Bool,
    modelParameterFingerprint: UInt64,
    createdTimestamp: BrainTimestamp
  ) throws {
    guard identifier > 0, goalIdentifier > 0, !steps.isEmpty,
      objectiveValue.isFinite, modelParameterFingerprint > 0
    else {
      throw BrainRuntimeError.transaction("active option plan is invalid")
    }
    self.identifier = identifier
    self.goalIdentifier = goalIdentifier
    self.steps = steps
    self.objectiveValue = objectiveValue
    self.admissible = admissible
    self.modelParameterFingerprint = modelParameterFingerprint
    self.createdTimestamp = createdTimestamp
  }
}

@frozen
public struct MotorGoalState: Codable, Equatable, Hashable, Sendable {
  public let taskSpaceTarget: BrainLatentVector
  public let velocityTarget: BrainLatentVector
  public let forceTarget: BrainLatentVector
  public let stiffnessTarget: BrainLatentVector
  public let dampingTarget: BrainLatentVector
  public let movementDurationMicroseconds: UInt64
  public let synergyCoefficients: [Float]

  public init(
    taskSpaceTarget: BrainLatentVector,
    velocityTarget: BrainLatentVector,
    forceTarget: BrainLatentVector,
    stiffnessTarget: BrainLatentVector,
    dampingTarget: BrainLatentVector,
    movementDurationMicroseconds: UInt64,
    synergyCoefficients: [Float]
  ) throws {
    guard movementDurationMicroseconds > 0, !synergyCoefficients.isEmpty,
      synergyCoefficients.allSatisfy(\.isFinite)
    else {
      throw BrainRuntimeError.transaction("motor goal state is invalid")
    }
    self.taskSpaceTarget = taskSpaceTarget
    self.velocityTarget = velocityTarget
    self.forceTarget = forceTarget
    self.stiffnessTarget = stiffnessTarget
    self.dampingTarget = dampingTarget
    self.movementDurationMicroseconds = movementDurationMicroseconds
    self.synergyCoefficients = synergyCoefficients
  }
}

@frozen
public struct CerebellarExpertActivation: Codable, Equatable, Hashable, Sendable {
  public let expertIdentifier: UInt16
  public let weight: Float
  public let forwardPrediction: BrainLatentVector
  public let inverseCorrection: BrainLatentVector
  public let delayedError: BrainLatentVector

  public init(
    expertIdentifier: UInt16,
    weight: Float,
    forwardPrediction: BrainLatentVector,
    inverseCorrection: BrainLatentVector,
    delayedError: BrainLatentVector
  ) throws {
    guard weight.isFinite, (0...1).contains(weight) else {
      throw BrainRuntimeError.transaction("cerebellar expert activation is invalid")
    }
    self.expertIdentifier = expertIdentifier
    self.weight = weight
    self.forwardPrediction = forwardPrediction
    self.inverseCorrection = inverseCorrection
    self.delayedError = delayedError
  }
}

@frozen
public struct SpinalControlState: Codable, Equatable, Hashable, Sendable {
  public let cpgPhases: [Float]
  public let reflexState: BrainLatentVector
  public let motorNeuronState: [Float]
  public let muscleExcitations: [Float]
  public let autonomicCommands: [Float]

  public init(
    cpgPhases: [Float],
    reflexState: BrainLatentVector,
    motorNeuronState: [Float],
    muscleExcitations: [Float],
    autonomicCommands: [Float]
  ) throws {
    guard cpgPhases.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
      !motorNeuronState.isEmpty, motorNeuronState.allSatisfy(\.isFinite),
      muscleExcitations.count == motorNeuronState.count,
      muscleExcitations.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
      !autonomicCommands.isEmpty,
      autonomicCommands.allSatisfy({ $0.isFinite && (0...1).contains($0) })
    else {
      throw BrainRuntimeError.transaction("spinal control state is invalid")
    }
    self.cpgPhases = cpgPhases
    self.reflexState = reflexState
    self.motorNeuronState = motorNeuronState
    self.muscleExcitations = muscleExcitations
    self.autonomicCommands = autonomicCommands
  }
}

@frozen
public struct ActiveControlState: Codable, Equatable, Sendable {
  public let timestamp: BrainTimestamp
  public let mode: ControlMode
  public let activeGoal: ActiveGoal?
  public let suppressedGoals: [ActiveGoal]
  public let candidates: [OptionCandidate]
  public let selectedOption: OptionCandidate?
  public let plan: ActiveOptionPlan?
  public let motorGoal: MotorGoalState?
  public let cerebellarExperts: [CerebellarExpertActivation]
  public let spinal: SpinalControlState
  public let controllerPhase: Float
  public let emergencyStopActive: Bool

  public init(
    timestamp: BrainTimestamp,
    mode: ControlMode,
    activeGoal: ActiveGoal?,
    suppressedGoals: [ActiveGoal],
    candidates: [OptionCandidate],
    selectedOption: OptionCandidate?,
    plan: ActiveOptionPlan?,
    motorGoal: MotorGoalState?,
    cerebellarExperts: [CerebellarExpertActivation],
    spinal: SpinalControlState,
    controllerPhase: Float,
    emergencyStopActive: Bool,
    maximumCandidates: Int = 32,
    maximumActiveCerebellarExperts: Int = 4
  ) throws {
    let goalIdentifiers = ([activeGoal].compactMap { $0 } + suppressedGoals).map(\.identifier)
    guard candidates.count <= maximumCandidates,
      cerebellarExperts.count <= maximumActiveCerebellarExperts,
      Set(goalIdentifiers).count == goalIdentifiers.count,
      Set(candidates.map(\.skillIdentifier)).count == candidates.count,
      selectedOption == nil || candidates.contains(selectedOption!),
      plan == nil || activeGoal?.identifier == plan?.goalIdentifier,
      cerebellarExperts.isEmpty
        || abs(cerebellarExperts.reduce(0) { $0 + $1.weight } - 1) <= 0.001,
      controllerPhase.isFinite, (0...1).contains(controllerPhase)
    else {
      throw BrainRuntimeError.transaction("active control state is invalid")
    }
    self.timestamp = timestamp
    self.mode = mode
    self.activeGoal = activeGoal
    self.suppressedGoals = suppressedGoals
    self.candidates = candidates
    self.selectedOption = selectedOption
    self.plan = plan
    self.motorGoal = motorGoal
    self.cerebellarExperts = cerebellarExperts
    self.spinal = spinal
    self.controllerPhase = controllerPhase
    self.emergencyStopActive = emergencyStopActive
  }
}

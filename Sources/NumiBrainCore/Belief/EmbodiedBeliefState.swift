import Foundation

@frozen
public struct BeliefScalar: Codable, Equatable, Hashable, Sendable {
  public let mean: Float
  public let logVariance: Float

  public init(mean: Float, logVariance: Float) throws {
    guard mean.isFinite, logVariance.isFinite else {
      throw BrainRuntimeError.transaction("belief scalar must be finite")
    }
    self.mean = mean
    self.logVariance = logVariance
  }

  public var variance: Float { Foundation.exp(logVariance) }
  public var confidence: Float { 1 / (1 + Foundation.sqrt(variance)) }
}

@frozen
public struct BodyNodeBelief: Codable, Equatable, Hashable, Sendable {
  public let bodyIdentifier: UInt32
  public let pose: BrainPoseEstimate
  public let contactProbability: Float
  public let supportProbability: Float
  public let estimatedLocalForce: BrainVector3
  public let pain: Float
  public let vulnerability: Float
  public let reachability: Float
  public let ownershipConfidence: Float
  public let observationTimestamp: BrainTimestamp?

  public init(
    bodyIdentifier: UInt32,
    pose: BrainPoseEstimate,
    contactProbability: Float,
    supportProbability: Float,
    estimatedLocalForce: BrainVector3,
    pain: Float,
    vulnerability: Float,
    reachability: Float,
    ownershipConfidence: Float,
    observationTimestamp: BrainTimestamp?
  ) throws {
    let probabilities = [
      contactProbability, supportProbability, pain, vulnerability,
      reachability, ownershipConfidence,
    ]
    guard probabilities.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
      throw BrainRuntimeError.transaction("body-node belief probability is invalid")
    }
    self.bodyIdentifier = bodyIdentifier
    self.pose = pose
    self.contactProbability = contactProbability
    self.supportProbability = supportProbability
    self.estimatedLocalForce = estimatedLocalForce
    self.pain = pain
    self.vulnerability = vulnerability
    self.reachability = reachability
    self.ownershipConfidence = ownershipConfidence
    self.observationTimestamp = observationTimestamp
  }
}

@frozen
public struct MuscleEdgeBelief: Codable, Equatable, Hashable, Sendable {
  public let muscleIdentifier: UInt32
  public let firstBodyIdentifier: UInt32
  public let terminalBodyIdentifier: UInt32
  public let activation: BeliefScalar
  public let length: BeliefScalar
  public let lengthVelocity: BeliefScalar
  public let force: BeliefScalar
  public let fatigue: BeliefScalar
  public let learnedEffect: BrainLatentVector

  public init(
    muscleIdentifier: UInt32,
    firstBodyIdentifier: UInt32,
    terminalBodyIdentifier: UInt32,
    activation: BeliefScalar,
    length: BeliefScalar,
    lengthVelocity: BeliefScalar,
    force: BeliefScalar,
    fatigue: BeliefScalar,
    learnedEffect: BrainLatentVector
  ) throws {
    guard firstBodyIdentifier != terminalBodyIdentifier else {
      throw BrainRuntimeError.transaction("muscle belief endpoints must be distinct")
    }
    self.muscleIdentifier = muscleIdentifier
    self.firstBodyIdentifier = firstBodyIdentifier
    self.terminalBodyIdentifier = terminalBodyIdentifier
    self.activation = activation
    self.length = length
    self.lengthVelocity = lengthVelocity
    self.force = force
    self.fatigue = fatigue
    self.learnedEffect = learnedEffect
  }
}

/// Learned causal state for one physical somatic effector. Biological agents
/// retain their anatomical muscle graph separately; robot agents use this
/// actuator graph without inventing muscle attachments.
@frozen
public struct SomaticActuatorBelief: Codable, Equatable, Hashable, Sendable {
  public let actuatorIdentifier: UInt32
  public let commandKind: ActuatorCommandKind
  public let lastCommand: BeliefScalar
  public let predictedSensoryEffect: BrainLatentVector
  public let agencyConfidence: Float
  public let externalDisturbance: Float
  public let observationTimestamp: BrainTimestamp?

  public init(
    actuatorIdentifier: UInt32,
    commandKind: ActuatorCommandKind,
    lastCommand: BeliefScalar,
    predictedSensoryEffect: BrainLatentVector,
    agencyConfidence: Float,
    externalDisturbance: Float,
    observationTimestamp: BrainTimestamp?
  ) throws {
    guard agencyConfidence.isFinite, (0...1).contains(agencyConfidence),
      externalDisturbance.isFinite, externalDisturbance >= 0
    else {
      throw BrainRuntimeError.transaction("somatic actuator belief is invalid")
    }
    self.actuatorIdentifier = actuatorIdentifier
    self.commandKind = commandKind
    self.lastCommand = lastCommand
    self.predictedSensoryEffect = predictedSensoryEffect
    self.agencyConfidence = agencyConfidence
    self.externalDisturbance = externalDisturbance
    self.observationTimestamp = observationTimestamp
  }
}

@frozen
public struct ObjectBeliefSlot: Codable, Equatable, Hashable, Sendable {
  public let slotIdentifier: UInt16
  public let existenceProbability: Float
  public let identityCode: UInt64
  public let identityConfidence: Float
  public let pose: BrainPoseEstimate
  public let shape: BrainLatentVector
  public let material: BrainLatentVector
  public let affordances: BrainLatentVector
  public let visibilityProbability: Float
  public let occlusionProbability: Float
  public let epistemicUncertainty: Float
  public let lastEvidenceTimestamp: BrainTimestamp

  public init(
    slotIdentifier: UInt16,
    existenceProbability: Float,
    identityCode: UInt64,
    identityConfidence: Float,
    pose: BrainPoseEstimate,
    shape: BrainLatentVector,
    material: BrainLatentVector,
    affordances: BrainLatentVector,
    visibilityProbability: Float,
    occlusionProbability: Float,
    epistemicUncertainty: Float,
    lastEvidenceTimestamp: BrainTimestamp
  ) throws {
    let probabilities = [
      existenceProbability, identityConfidence, visibilityProbability,
      occlusionProbability,
    ]
    guard probabilities.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
      epistemicUncertainty.isFinite, epistemicUncertainty >= 0
    else {
      throw BrainRuntimeError.transaction("object-slot belief is invalid")
    }
    self.slotIdentifier = slotIdentifier
    self.existenceProbability = existenceProbability
    self.identityCode = identityCode
    self.identityConfidence = identityConfidence
    self.pose = pose
    self.shape = shape
    self.material = material
    self.affordances = affordances
    self.visibilityProbability = visibilityProbability
    self.occlusionProbability = occlusionProbability
    self.epistemicUncertainty = epistemicUncertainty
    self.lastEvidenceTimestamp = lastEvidenceTimestamp
  }
}

@frozen
public struct OtherAgentBeliefSlot: Codable, Equatable, Hashable, Sendable {
  public let slotIdentifier: UInt16
  public let existenceProbability: Float
  public let identityCode: UInt64
  public let bodyPose: BrainPoseEstimate
  public let gazeDirection: BrainVector3
  public let attentionTargetCode: UInt64
  public let predictedAction: BrainLatentVector
  public let estimatedGoal: BrainLatentVector
  public let socialRelation: BrainLatentVector
  public let confidence: Float
  public let lastEvidenceTimestamp: BrainTimestamp

  public init(
    slotIdentifier: UInt16,
    existenceProbability: Float,
    identityCode: UInt64,
    bodyPose: BrainPoseEstimate,
    gazeDirection: BrainVector3,
    attentionTargetCode: UInt64,
    predictedAction: BrainLatentVector,
    estimatedGoal: BrainLatentVector,
    socialRelation: BrainLatentVector,
    confidence: Float,
    lastEvidenceTimestamp: BrainTimestamp
  ) throws {
    guard existenceProbability.isFinite, (0...1).contains(existenceProbability),
      confidence.isFinite, (0...1).contains(confidence)
    else {
      throw BrainRuntimeError.transaction("other-agent belief is invalid")
    }
    self.slotIdentifier = slotIdentifier
    self.existenceProbability = existenceProbability
    self.identityCode = identityCode
    self.bodyPose = bodyPose
    self.gazeDirection = gazeDirection
    self.attentionTargetCode = attentionTargetCode
    self.predictedAction = predictedAction
    self.estimatedGoal = estimatedGoal
    self.socialRelation = socialRelation
    self.confidence = confidence
    self.lastEvidenceTimestamp = lastEvidenceTimestamp
  }
}

@frozen
public enum BeliefRelationKind: UInt16, Codable, CaseIterable, Sendable {
  case contacting = 1
  case supporting = 2
  case inside = 3
  case attached = 4
  case ownedBy = 5
  case reachable = 6
  case occluding = 7
  case following = 8
  case threatening = 9
  case communicatingWith = 10
  case attendingTo = 11
}

@frozen
public enum BeliefEntityKind: UInt16, Codable, CaseIterable, Sendable {
  case selfBody = 1
  case object = 2
  case otherAgent = 3
  case location = 4
  case concept = 5
}

@frozen
public struct BeliefEntityReference: Codable, Equatable, Hashable, Sendable {
  public let kind: BeliefEntityKind
  public let identifier: UInt64

  public init(kind: BeliefEntityKind, identifier: UInt64) {
    self.kind = kind
    self.identifier = identifier
  }
}

@frozen
public struct RelationBelief: Codable, Equatable, Hashable, Sendable {
  public let subject: BeliefEntityReference
  public let relation: BeliefRelationKind
  public let object: BeliefEntityReference
  public let probability: Float
  public let uncertainty: Float
  public let lastEvidenceTimestamp: BrainTimestamp

  public init(
    subject: BeliefEntityReference,
    relation: BeliefRelationKind,
    object: BeliefEntityReference,
    probability: Float,
    uncertainty: Float,
    lastEvidenceTimestamp: BrainTimestamp
  ) throws {
    guard subject != object, probability.isFinite, (0...1).contains(probability),
      uncertainty.isFinite, uncertainty >= 0
    else {
      throw BrainRuntimeError.transaction("relation belief is invalid")
    }
    self.subject = subject
    self.relation = relation
    self.object = object
    self.probability = probability
    self.uncertainty = uncertainty
    self.lastEvidenceTimestamp = lastEvidenceTimestamp
  }
}

@frozen
public enum SpatialCoordinateFrame: UInt16, Codable, CaseIterable, Sendable {
  case sensorCentered = 1
  case headCentered = 2
  case bodyCentered = 3
  case localWorld = 4
  case persistentMap = 5
}

@frozen
public struct SpatialTransformBelief: Codable, Equatable, Hashable, Sendable {
  public let source: SpatialCoordinateFrame
  public let destination: SpatialCoordinateFrame
  public let translation: BrainVector3
  public let rotation: BrainQuaternion
  public let uncertainty: Float

  public init(
    source: SpatialCoordinateFrame,
    destination: SpatialCoordinateFrame,
    translation: BrainVector3,
    rotation: BrainQuaternion,
    uncertainty: Float
  ) throws {
    guard source != destination, uncertainty.isFinite, uncertainty >= 0 else {
      throw BrainRuntimeError.transaction("spatial transform belief is invalid")
    }
    self.source = source
    self.destination = destination
    self.translation = translation
    self.rotation = rotation
    self.uncertainty = uncertainty
  }
}

@frozen
public struct PhysiologyBeliefState: Codable, Equatable, Hashable, Sendable {
  public let energy: BeliefScalar
  public let hydration: BeliefScalar
  public let oxygen: BeliefScalar
  public let carbonDioxide: BeliefScalar
  public let temperature: BeliefScalar
  public let fatigue: BeliefScalar
  public let tissueDamage: BeliefScalar
  public let inflammation: BeliefScalar
  public let sleepPressure: BeliefScalar
  public let autonomicState: BrainLatentVector

  public init(
    energy: BeliefScalar,
    hydration: BeliefScalar,
    oxygen: BeliefScalar,
    carbonDioxide: BeliefScalar,
    temperature: BeliefScalar,
    fatigue: BeliefScalar,
    tissueDamage: BeliefScalar,
    inflammation: BeliefScalar,
    sleepPressure: BeliefScalar,
    autonomicState: BrainLatentVector
  ) {
    self.energy = energy
    self.hydration = hydration
    self.oxygen = oxygen
    self.carbonDioxide = carbonDioxide
    self.temperature = temperature
    self.fatigue = fatigue
    self.tissueDamage = tissueDamage
    self.inflammation = inflammation
    self.sleepPressure = sleepPressure
    self.autonomicState = autonomicState
  }
}

@frozen
public struct BeliefContextState: Codable, Equatable, Hashable, Sendable {
  public let eventCode: UInt64
  public let taskCode: UInt64
  public let socialContextCode: UInt64
  public let activeGoalIdentifier: UInt64?
  public let locationCode: UInt64
  public let behavioralModeCode: UInt32
  public let latent: BrainLatentVector
  public let confidence: Float

  public init(
    eventCode: UInt64,
    taskCode: UInt64,
    socialContextCode: UInt64,
    activeGoalIdentifier: UInt64?,
    locationCode: UInt64,
    behavioralModeCode: UInt32,
    latent: BrainLatentVector,
    confidence: Float
  ) throws {
    guard confidence.isFinite, (0...1).contains(confidence) else {
      throw BrainRuntimeError.transaction("belief context confidence is invalid")
    }
    self.eventCode = eventCode
    self.taskCode = taskCode
    self.socialContextCode = socialContextCode
    self.activeGoalIdentifier = activeGoalIdentifier
    self.locationCode = locationCode
    self.behavioralModeCode = behavioralModeCode
    self.latent = latent
    self.confidence = confidence
  }
}

/// One compatible posterior over self, entities, other agents, relations,
/// spatial frames, physiology, and behavioral context. Capacity limits are
/// explicit so checkpoint identity cannot silently change between profiles.
@frozen
public struct EmbodiedBeliefState: Codable, Equatable, Sendable {
  public let timestamp: BrainTimestamp
  public let bodyNodes: [BodyNodeBelief]
  public let muscleEdges: [MuscleEdgeBelief]
  public let actuatorEffects: [SomaticActuatorBelief]
  public let bodyLoadPosterior: [BodySchemaPosteriorCell]
  public let objects: [ObjectBeliefSlot]
  public let otherAgents: [OtherAgentBeliefSlot]
  public let relations: [RelationBelief]
  public let spatialTransforms: [SpatialTransformBelief]
  public let physiology: PhysiologyBeliefState
  public let context: BeliefContextState
  public let posteriorLatent: BrainLatentVector
  public let epistemicConfidence: Float
  public let observationNoiseEstimate: Float

  public init(
    timestamp: BrainTimestamp,
    bodyNodes: [BodyNodeBelief],
    muscleEdges: [MuscleEdgeBelief],
    actuatorEffects: [SomaticActuatorBelief],
    bodyLoadPosterior: [BodySchemaPosteriorCell],
    objects: [ObjectBeliefSlot],
    otherAgents: [OtherAgentBeliefSlot],
    relations: [RelationBelief],
    spatialTransforms: [SpatialTransformBelief],
    physiology: PhysiologyBeliefState,
    context: BeliefContextState,
    posteriorLatent: BrainLatentVector,
    epistemicConfidence: Float,
    observationNoiseEstimate: Float,
    maximumObjectSlots: Int,
    maximumAgentSlots: Int
  ) throws {
    guard maximumObjectSlots >= 0, maximumAgentSlots >= 0,
      objects.count <= maximumObjectSlots, otherAgents.count <= maximumAgentSlots,
      Set(bodyNodes.map(\.bodyIdentifier)).count == bodyNodes.count,
      Set(muscleEdges.map(\.muscleIdentifier)).count == muscleEdges.count,
      Set(actuatorEffects.map(\.actuatorIdentifier)).count
        == actuatorEffects.count,
      Set(objects.map(\.slotIdentifier)).count == objects.count,
      Set(otherAgents.map(\.slotIdentifier)).count == otherAgents.count,
      bodyLoadPosterior.allSatisfy({ $0.stateTimestamp == timestamp }),
      epistemicConfidence.isFinite, (0...1).contains(epistemicConfidence),
      observationNoiseEstimate.isFinite, observationNoiseEstimate >= 0
    else {
      throw BrainRuntimeError.transaction("unified embodied belief state is invalid")
    }
    let bodyIdentifiers = Set(bodyNodes.map(\.bodyIdentifier))
    guard muscleEdges.allSatisfy({
      bodyIdentifiers.contains($0.firstBodyIdentifier)
        && bodyIdentifiers.contains($0.terminalBodyIdentifier)
    }), bodyLoadPosterior.allSatisfy({ bodyIdentifiers.contains($0.bodyIdentifier) })
    else {
      throw BrainRuntimeError.transaction("embodied belief graph has unknown body endpoints")
    }
    self.timestamp = timestamp
    self.bodyNodes = bodyNodes.sorted { $0.bodyIdentifier < $1.bodyIdentifier }
    self.muscleEdges = muscleEdges.sorted { $0.muscleIdentifier < $1.muscleIdentifier }
    self.actuatorEffects = actuatorEffects.sorted {
      $0.actuatorIdentifier < $1.actuatorIdentifier
    }
    self.bodyLoadPosterior = bodyLoadPosterior.sorted {
      $0.bodyIdentifier < $1.bodyIdentifier
    }
    self.objects = objects.sorted { $0.slotIdentifier < $1.slotIdentifier }
    self.otherAgents = otherAgents.sorted { $0.slotIdentifier < $1.slotIdentifier }
    self.relations = relations
    self.spatialTransforms = spatialTransforms
    self.physiology = physiology
    self.context = context
    self.posteriorLatent = posteriorLatent
    self.epistemicConfidence = epistemicConfidence
    self.observationNoiseEstimate = observationNoiseEstimate
  }
}

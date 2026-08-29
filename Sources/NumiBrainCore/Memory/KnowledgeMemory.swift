import Foundation

@frozen
public enum SemanticConceptKind: UInt16, Codable, CaseIterable, Sendable {
  case entity = 1
  case action = 2
  case property = 3
  case location = 4
  case event = 5
  case goal = 6
  case social = 7
  case symbol = 8
  case rule = 9
}

@frozen
public struct SemanticConceptNode: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt64
  public let kind: SemanticConceptKind
  public let embedding: BrainLatentVector
  public let confidence: Float
  public let usageCount: UInt64
  public let validFrom: BrainTimestamp
  public let validUntil: BrainTimestamp?
  public let sourceEpisodeIdentifiers: [UInt64]
  public let associatedSkillIdentifiers: [UInt64]

  public init(
    identifier: UInt64,
    kind: SemanticConceptKind,
    embedding: BrainLatentVector,
    confidence: Float,
    usageCount: UInt64,
    validFrom: BrainTimestamp,
    validUntil: BrainTimestamp?,
    sourceEpisodeIdentifiers: [UInt64],
    associatedSkillIdentifiers: [UInt64]
  ) throws {
    guard identifier > 0, confidence.isFinite, (0...1).contains(confidence),
      validUntil == nil || validUntil! >= validFrom,
      Set(sourceEpisodeIdentifiers).count == sourceEpisodeIdentifiers.count,
      Set(associatedSkillIdentifiers).count == associatedSkillIdentifiers.count
    else {
      throw BrainRuntimeError.transaction("semantic concept node is invalid")
    }
    self.identifier = identifier
    self.kind = kind
    self.embedding = embedding
    self.confidence = confidence
    self.usageCount = usageCount
    self.validFrom = validFrom
    self.validUntil = validUntil
    self.sourceEpisodeIdentifiers = sourceEpisodeIdentifiers
    self.associatedSkillIdentifiers = associatedSkillIdentifiers
  }
}

@frozen
public enum SemanticRelationKind: UInt16, Codable, CaseIterable, Sendable {
  case isA = 1
  case hasProperty = 2
  case partOf = 3
  case causes = 4
  case enables = 5
  case prevents = 6
  case locatedAt = 7
  case affords = 8
  case communicates = 9
  case contradicts = 10
  case precedes = 11
  case associatedWith = 12
}

@frozen
public struct SemanticRelationEdge: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt64
  public let sourceConceptIdentifier: UInt64
  public let kind: SemanticRelationKind
  public let destinationConceptIdentifier: UInt64
  public let confidence: Float
  public let supportingEpisodeIdentifiers: [UInt64]
  public let contradictingEpisodeIdentifiers: [UInt64]
  public let validFrom: BrainTimestamp
  public let validUntil: BrainTimestamp?

  public init(
    identifier: UInt64,
    sourceConceptIdentifier: UInt64,
    kind: SemanticRelationKind,
    destinationConceptIdentifier: UInt64,
    confidence: Float,
    supportingEpisodeIdentifiers: [UInt64],
    contradictingEpisodeIdentifiers: [UInt64],
    validFrom: BrainTimestamp,
    validUntil: BrainTimestamp?
  ) throws {
    guard identifier > 0, sourceConceptIdentifier != destinationConceptIdentifier,
      confidence.isFinite, (0...1).contains(confidence),
      validUntil == nil || validUntil! >= validFrom,
      Set(supportingEpisodeIdentifiers).count == supportingEpisodeIdentifiers.count,
      Set(contradictingEpisodeIdentifiers).count == contradictingEpisodeIdentifiers.count
    else {
      throw BrainRuntimeError.transaction("semantic relation edge is invalid")
    }
    self.identifier = identifier
    self.sourceConceptIdentifier = sourceConceptIdentifier
    self.kind = kind
    self.destinationConceptIdentifier = destinationConceptIdentifier
    self.confidence = confidence
    self.supportingEpisodeIdentifiers = supportingEpisodeIdentifiers
    self.contradictingEpisodeIdentifiers = contradictingEpisodeIdentifiers
    self.validFrom = validFrom
    self.validUntil = validUntil
  }
}

@frozen
public struct SemanticMemoryState: Codable, Equatable, Sendable {
  public let generation: UInt64
  public let conceptCapacity: UInt32
  public let relationCapacity: UInt32
  public let nextConceptIdentifier: UInt64
  public let nextRelationIdentifier: UInt64
  public let concepts: [SemanticConceptNode]
  public let relations: [SemanticRelationEdge]

  public init(
    generation: UInt64,
    conceptCapacity: UInt32,
    relationCapacity: UInt32,
    nextConceptIdentifier: UInt64,
    nextRelationIdentifier: UInt64,
    concepts: [SemanticConceptNode],
    relations: [SemanticRelationEdge]
  ) throws {
    let conceptIdentifiers = Set(concepts.map(\.identifier))
    guard concepts.count <= Int(conceptCapacity), relations.count <= Int(relationCapacity),
      conceptIdentifiers.count == concepts.count,
      Set(relations.map(\.identifier)).count == relations.count,
      concepts.allSatisfy({ $0.identifier < nextConceptIdentifier }),
      relations.allSatisfy({
        $0.identifier < nextRelationIdentifier
          && conceptIdentifiers.contains($0.sourceConceptIdentifier)
          && conceptIdentifiers.contains($0.destinationConceptIdentifier)
      })
    else {
      throw BrainRuntimeError.capacity("semantic memory graph is invalid")
    }
    self.generation = generation
    self.conceptCapacity = conceptCapacity
    self.relationCapacity = relationCapacity
    self.nextConceptIdentifier = nextConceptIdentifier
    self.nextRelationIdentifier = nextRelationIdentifier
    self.concepts = concepts.sorted { $0.identifier < $1.identifier }
    self.relations = relations.sorted { $0.identifier < $1.identifier }
  }
}

@frozen
public enum SemanticMutation: Codable, Equatable, Hashable, Sendable {
  case upsertConcept(SemanticConceptNode)
  case upsertRelation(SemanticRelationEdge)
  case removeConcept(UInt64)
  case removeRelation(UInt64)
}

@frozen
public enum ProceduralSkillFlags: UInt32, Codable, Sendable {
  case trainable = 1
  case frozen = 2
  case retired = 3
}

@frozen
public struct ProceduralSkill: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt64
  public let parentSkillIdentifiers: [UInt64]
  public let initiationModel: BrainLatentVector
  public let goalParameterDimension: UInt16
  public let policyCode: BrainLatentVector
  public let terminationModel: BrainLatentVector
  public let outcomeModel: BrainLatentVector
  public let expectedFactoredValue: FactoredReinforcement
  public let expectedDamageCVaR: Float
  public let expectedEffort: Float
  public let competence: Float
  public let adaptationState: BrainLatentVector
  public let executionCount: UInt64
  public let lastExecutionTimestamp: BrainTimestamp?
  public let flags: ProceduralSkillFlags

  public init(
    identifier: UInt64,
    parentSkillIdentifiers: [UInt64],
    initiationModel: BrainLatentVector,
    goalParameterDimension: UInt16,
    policyCode: BrainLatentVector,
    terminationModel: BrainLatentVector,
    outcomeModel: BrainLatentVector,
    expectedFactoredValue: FactoredReinforcement,
    expectedDamageCVaR: Float,
    expectedEffort: Float,
    competence: Float,
    adaptationState: BrainLatentVector,
    executionCount: UInt64,
    lastExecutionTimestamp: BrainTimestamp?,
    flags: ProceduralSkillFlags
  ) throws {
    guard identifier > 0, !parentSkillIdentifiers.contains(identifier),
      Set(parentSkillIdentifiers).count == parentSkillIdentifiers.count,
      goalParameterDimension > 0,
      expectedDamageCVaR.isFinite, expectedDamageCVaR >= 0,
      expectedEffort.isFinite, expectedEffort >= 0,
      competence.isFinite, (0...1).contains(competence)
    else {
      throw BrainRuntimeError.transaction("procedural skill is invalid")
    }
    self.identifier = identifier
    self.parentSkillIdentifiers = parentSkillIdentifiers
    self.initiationModel = initiationModel
    self.goalParameterDimension = goalParameterDimension
    self.policyCode = policyCode
    self.terminationModel = terminationModel
    self.outcomeModel = outcomeModel
    self.expectedFactoredValue = expectedFactoredValue
    self.expectedDamageCVaR = expectedDamageCVaR
    self.expectedEffort = expectedEffort
    self.competence = competence
    self.adaptationState = adaptationState
    self.executionCount = executionCount
    self.lastExecutionTimestamp = lastExecutionTimestamp
    self.flags = flags
  }
}

@frozen
public struct ProceduralMemoryState: Codable, Equatable, Sendable {
  public let generation: UInt64
  public let skillCapacity: UInt32
  public let nextSkillIdentifier: UInt64
  public let skills: [ProceduralSkill]

  public init(
    generation: UInt64,
    skillCapacity: UInt32,
    nextSkillIdentifier: UInt64,
    skills: [ProceduralSkill]
  ) throws {
    let identifiers = Set(skills.map(\.identifier))
    guard skills.count <= Int(skillCapacity), identifiers.count == skills.count,
      skills.allSatisfy({ skill in
        skill.identifier < nextSkillIdentifier
          && skill.parentSkillIdentifiers.allSatisfy(identifiers.contains)
      })
    else {
      throw BrainRuntimeError.capacity("procedural memory state is invalid")
    }
    self.generation = generation
    self.skillCapacity = skillCapacity
    self.nextSkillIdentifier = nextSkillIdentifier
    self.skills = skills.sorted { $0.identifier < $1.identifier }
  }
}

@frozen
public enum ProceduralMutation: Codable, Equatable, Hashable, Sendable {
  case upsert(ProceduralSkill)
  case remove(UInt64)
}

@frozen
public enum ProspectiveIntentionStatus: UInt16, Codable, CaseIterable, Sendable {
  case pending = 1
  case active = 2
  case satisfied = 3
  case failed = 4
  case expired = 5
}

@frozen
public struct ProspectiveIntention: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt64
  public let goalIdentifier: UInt64
  public let triggerModel: BrainLatentVector
  public let deadline: BrainTimestamp?
  public let priority: Float
  public let context: BrainLatentVector
  public let status: ProspectiveIntentionStatus
  public let createdTimestamp: BrainTimestamp

  public init(
    identifier: UInt64,
    goalIdentifier: UInt64,
    triggerModel: BrainLatentVector,
    deadline: BrainTimestamp?,
    priority: Float,
    context: BrainLatentVector,
    status: ProspectiveIntentionStatus,
    createdTimestamp: BrainTimestamp
  ) throws {
    guard identifier > 0, goalIdentifier > 0,
      deadline == nil || deadline! >= createdTimestamp,
      priority.isFinite, (0...1).contains(priority)
    else {
      throw BrainRuntimeError.transaction("prospective intention is invalid")
    }
    self.identifier = identifier
    self.goalIdentifier = goalIdentifier
    self.triggerModel = triggerModel
    self.deadline = deadline
    self.priority = priority
    self.context = context
    self.status = status
    self.createdTimestamp = createdTimestamp
  }
}

@frozen
public struct ProspectiveMemoryState: Codable, Equatable, Sendable {
  public let generation: UInt64
  public let capacity: UInt16
  public let nextIdentifier: UInt64
  public let intentions: [ProspectiveIntention]

  public init(
    generation: UInt64,
    capacity: UInt16,
    nextIdentifier: UInt64,
    intentions: [ProspectiveIntention]
  ) throws {
    guard intentions.count <= Int(capacity),
      Set(intentions.map(\.identifier)).count == intentions.count,
      intentions.allSatisfy({ $0.identifier < nextIdentifier })
    else {
      throw BrainRuntimeError.capacity("prospective memory state is invalid")
    }
    self.generation = generation
    self.capacity = capacity
    self.nextIdentifier = nextIdentifier
    self.intentions = intentions.sorted { $0.identifier < $1.identifier }
  }
}

@frozen
public enum ReplayQueueKind: UInt16, Codable, CaseIterable, Sendable {
  case episodic = 1
  case procedural = 2
  case threatFailure = 3
  case social = 4
  case semanticConsolidation = 5
  case rareEvent = 6
}

@frozen
public enum ReplayRecordKind: UInt16, Codable, CaseIterable, Sendable {
  case episode = 1
  case skill = 2
  case semanticConcept = 3
  case semanticRelation = 4
}

@frozen
public struct ReplayQueueEntry: Codable, Equatable, Hashable, Sendable {
  public let queue: ReplayQueueKind
  public let recordKind: ReplayRecordKind
  public let recordIdentifier: UInt64
  public let priority: Float
  public let enqueuedTimestamp: BrainTimestamp
  public let replayCount: UInt32

  public init(
    queue: ReplayQueueKind,
    recordKind: ReplayRecordKind,
    recordIdentifier: UInt64,
    priority: Float,
    enqueuedTimestamp: BrainTimestamp,
    replayCount: UInt32 = 0
  ) throws {
    guard recordIdentifier > 0, priority.isFinite, priority >= 0 else {
      throw BrainRuntimeError.transaction("replay queue entry is invalid")
    }
    self.queue = queue
    self.recordKind = recordKind
    self.recordIdentifier = recordIdentifier
    self.priority = priority
    self.enqueuedTimestamp = enqueuedTimestamp
    self.replayCount = replayCount
  }
}

@frozen
public struct ReplayState: Codable, Equatable, Sendable {
  public let generation: UInt64
  public let capacity: UInt32
  public let entries: [ReplayQueueEntry]

  public init(generation: UInt64, capacity: UInt32, entries: [ReplayQueueEntry]) throws {
    let identities = entries.map {
      "\($0.queue.rawValue):\($0.recordKind.rawValue):\($0.recordIdentifier)"
    }
    guard entries.count <= Int(capacity), Set(identities).count == identities.count else {
      throw BrainRuntimeError.capacity("replay state is invalid")
    }
    self.generation = generation
    self.capacity = capacity
    self.entries = entries.sorted {
      if $0.priority != $1.priority { return $0.priority > $1.priority }
      return $0.enqueuedTimestamp < $1.enqueuedTimestamp
    }
  }
}

@frozen
public struct MemoryMutationJournal: Codable, Equatable, Sendable {
  public let baseGeneration: UInt64
  public let shadowGeneration: UInt64
  public let semanticMutations: [SemanticMutation]
  public let proceduralMutations: [ProceduralMutation]
  public let prospectiveUpserts: [ProspectiveIntention]
  public let prospectiveRemovals: [UInt64]
  public let replayEnqueues: [ReplayQueueEntry]

  public init(
    baseGeneration: UInt64,
    shadowGeneration: UInt64,
    semanticMutations: [SemanticMutation] = [],
    proceduralMutations: [ProceduralMutation] = [],
    prospectiveUpserts: [ProspectiveIntention] = [],
    prospectiveRemovals: [UInt64] = [],
    replayEnqueues: [ReplayQueueEntry] = []
  ) throws {
    let (expected, overflow) = baseGeneration.addingReportingOverflow(1)
    guard !overflow, shadowGeneration == expected,
      Set(prospectiveUpserts.map(\.identifier)).count == prospectiveUpserts.count,
      Set(prospectiveRemovals).count == prospectiveRemovals.count
    else {
      throw BrainRuntimeError.transaction("memory journal is invalid")
    }
    self.baseGeneration = baseGeneration
    self.shadowGeneration = shadowGeneration
    self.semanticMutations = semanticMutations
    self.proceduralMutations = proceduralMutations
    self.prospectiveUpserts = prospectiveUpserts
    self.prospectiveRemovals = prospectiveRemovals
    self.replayEnqueues = replayEnqueues
  }
}

@frozen
public struct CompleteMemoryState: Codable, Equatable, Sendable {
  public let episodic: EpisodicMemoryState
  public let semantic: SemanticMemoryState
  public let procedural: ProceduralMemoryState
  public let prospective: ProspectiveMemoryState
  public let replay: ReplayState

  public init(
    episodic: EpisodicMemoryState,
    semantic: SemanticMemoryState,
    procedural: ProceduralMemoryState,
    prospective: ProspectiveMemoryState,
    replay: ReplayState
  ) throws {
    let generations = [
      episodic.generation, semantic.generation, procedural.generation,
      prospective.generation, replay.generation,
    ]
    guard Set(generations).count == 1 else {
      throw BrainRuntimeError.transaction("memory systems do not share a generation")
    }
    self.episodic = episodic
    self.semantic = semantic
    self.procedural = procedural
    self.prospective = prospective
    self.replay = replay
  }

  public var generation: UInt64 { episodic.generation }
}

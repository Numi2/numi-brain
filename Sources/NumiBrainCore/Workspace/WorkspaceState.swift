import Foundation

@frozen
public enum WorkspaceTokenKind: UInt16, Codable, CaseIterable, Sendable {
  case selfState = 1
  case goal = 2
  case object = 3
  case agent = 4
  case memory = 5
  case plan = 6
  case error = 7
  case drive = 8
  case action = 9
  case language = 10
}

@frozen
public enum WorkspaceMemoryProvenanceKind: UInt16, Codable, CaseIterable, Sendable {
  case none = 0
  case livedEpisode = 1
  case semanticFact = 2
  case proceduralSkill = 3
  case imaginedCounterfactual = 4
  case communication = 5
}

@frozen
public struct WorkspaceMemoryProvenance: Codable, Equatable, Hashable, Sendable {
  public let kind: WorkspaceMemoryProvenanceKind
  public let recordIdentifier: UInt64
  public let sourceGeneration: UInt64

  public init(
    kind: WorkspaceMemoryProvenanceKind,
    recordIdentifier: UInt64 = 0,
    sourceGeneration: UInt64 = 0
  ) throws {
    guard kind != .none || (recordIdentifier == 0 && sourceGeneration == 0) else {
      throw BrainRuntimeError.transaction("empty workspace provenance carries an identity")
    }
    self.kind = kind
    self.recordIdentifier = recordIdentifier
    self.sourceGeneration = sourceGeneration
  }

  public static var none: Self { get throws { try Self(kind: .none) } }
}

@frozen
public struct WorkspaceToken: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt64
  public let kind: WorkspaceTokenKind
  public let content: BrainLatentVector
  public let entityIdentifier: UInt64?
  public let sourceModuleIdentifier: UInt16
  public let confidence: Float
  public let sourceTimestamp: BrainTimestamp
  public let lastRefreshTimestamp: BrainTimestamp
  public let persistencePriority: Float
  public let goalBinding: UInt64?
  public let boundTokenIdentifier: UInt64?
  public let provenance: WorkspaceMemoryProvenance

  public init(
    identifier: UInt64,
    kind: WorkspaceTokenKind,
    content: BrainLatentVector,
    entityIdentifier: UInt64? = nil,
    sourceModuleIdentifier: UInt16,
    confidence: Float,
    sourceTimestamp: BrainTimestamp,
    lastRefreshTimestamp: BrainTimestamp,
    persistencePriority: Float,
    goalBinding: UInt64? = nil,
    boundTokenIdentifier: UInt64? = nil,
    provenance: WorkspaceMemoryProvenance
  ) throws {
    guard identifier > 0, sourceModuleIdentifier > 0,
      confidence.isFinite, (0...1).contains(confidence),
      persistencePriority.isFinite, (0...1).contains(persistencePriority),
      sourceTimestamp <= lastRefreshTimestamp,
      boundTokenIdentifier != identifier
    else {
      throw BrainRuntimeError.transaction("workspace token is invalid")
    }
    self.identifier = identifier
    self.kind = kind
    self.content = content
    self.entityIdentifier = entityIdentifier
    self.sourceModuleIdentifier = sourceModuleIdentifier
    self.confidence = confidence
    self.sourceTimestamp = sourceTimestamp
    self.lastRefreshTimestamp = lastRefreshTimestamp
    self.persistencePriority = persistencePriority
    self.goalBinding = goalBinding
    self.boundTokenIdentifier = boundTokenIdentifier
    self.provenance = provenance
  }

  public func refreshed(at timestamp: BrainTimestamp, confidence: Float) throws -> Self {
    try Self(
      identifier: identifier,
      kind: kind,
      content: content,
      entityIdentifier: entityIdentifier,
      sourceModuleIdentifier: sourceModuleIdentifier,
      confidence: confidence,
      sourceTimestamp: sourceTimestamp,
      lastRefreshTimestamp: timestamp,
      persistencePriority: persistencePriority,
      goalBinding: goalBinding,
      boundTokenIdentifier: boundTokenIdentifier,
      provenance: provenance
    )
  }

  public func bound(to tokenIdentifier: UInt64?) throws -> Self {
    try Self(
      identifier: identifier,
      kind: kind,
      content: content,
      entityIdentifier: entityIdentifier,
      sourceModuleIdentifier: sourceModuleIdentifier,
      confidence: confidence,
      sourceTimestamp: sourceTimestamp,
      lastRefreshTimestamp: lastRefreshTimestamp,
      persistencePriority: persistencePriority,
      goalBinding: goalBinding,
      boundTokenIdentifier: tokenIdentifier,
      provenance: provenance
    )
  }
}

@frozen
public enum WorkspaceMutation: Codable, Equatable, Hashable, Sendable {
  case write(slot: UInt16, token: WorkspaceToken)
  case refresh(slot: UInt16, timestamp: BrainTimestamp, confidence: Float)
  case bind(slot: UInt16, tokenIdentifier: UInt64?)
  case clear(slot: UInt16)
  case clearAll
}

/// Fixed-capacity broadcast state. Mutations are applied to a shadow value and
/// published only by the owning root transaction generation.
@frozen
public struct WorkspaceState: Codable, Equatable, Sendable {
  public let tokenCapacity: UInt16
  public let tokenDimension: UInt16
  public let generation: UInt64
  public let timestamp: BrainTimestamp
  public let slots: [WorkspaceToken?]

  public init(
    tokenCapacity: UInt16 = 16,
    tokenDimension: UInt16 = 256,
    generation: UInt64,
    timestamp: BrainTimestamp,
    slots: [WorkspaceToken?]
  ) throws {
    guard tokenCapacity > 0, tokenDimension > 0,
      slots.count == Int(tokenCapacity),
      slots.compactMap({ $0 }).allSatisfy({
        $0.content.values.count == Int(tokenDimension)
          && $0.lastRefreshTimestamp <= timestamp
      }),
      Set(slots.compactMap({ $0?.identifier })).count == slots.compactMap({ $0 }).count
    else {
      throw BrainRuntimeError.capacity("workspace shape or token identity is invalid")
    }
    let identities = Set(slots.compactMap({ $0?.identifier }))
    guard slots.compactMap({ $0?.boundTokenIdentifier }).allSatisfy(identities.contains) else {
      throw BrainRuntimeError.transaction("workspace binding names a missing token")
    }
    self.tokenCapacity = tokenCapacity
    self.tokenDimension = tokenDimension
    self.generation = generation
    self.timestamp = timestamp
    self.slots = slots
  }

  public static func empty(
    tokenCapacity: UInt16 = 16,
    tokenDimension: UInt16 = 256,
    generation: UInt64 = 0,
    timestamp: BrainTimestamp = BrainTimestamp(microseconds: 0)
  ) throws -> Self {
    try Self(
      tokenCapacity: tokenCapacity,
      tokenDimension: tokenDimension,
      generation: generation,
      timestamp: timestamp,
      slots: Array(repeating: nil, count: Int(tokenCapacity))
    )
  }

  public func applying(
    _ mutations: [WorkspaceMutation],
    shadowGeneration: UInt64,
    targetTimestamp: BrainTimestamp
  ) throws -> Self {
    let (expectedGeneration, overflow) = generation.addingReportingOverflow(1)
    guard !overflow, shadowGeneration == expectedGeneration, targetTimestamp >= timestamp else {
      throw BrainRuntimeError.transaction("workspace shadow generation is invalid")
    }
    var next = slots
    for mutation in mutations {
      switch mutation {
      case .write(let slot, let token):
        guard Int(slot) < next.count, token.content.values.count == Int(tokenDimension),
          token.lastRefreshTimestamp <= targetTimestamp
        else { throw BrainRuntimeError.capacity("workspace write exceeds capacity") }
        next[Int(slot)] = token
      case .refresh(let slot, let refreshTimestamp, let confidence):
        guard Int(slot) < next.count, let token = next[Int(slot)],
          refreshTimestamp <= targetTimestamp
        else { throw BrainRuntimeError.transaction("workspace refresh target is absent") }
        next[Int(slot)] = try token.refreshed(at: refreshTimestamp, confidence: confidence)
      case .bind(let slot, let tokenIdentifier):
        guard Int(slot) < next.count, let token = next[Int(slot)] else {
          throw BrainRuntimeError.transaction("workspace bind target is absent")
        }
        next[Int(slot)] = try token.bound(to: tokenIdentifier)
      case .clear(let slot):
        guard Int(slot) < next.count else {
          throw BrainRuntimeError.capacity("workspace clear exceeds capacity")
        }
        next[Int(slot)] = nil
      case .clearAll:
        next = Array(repeating: nil, count: next.count)
      }
    }
    return try Self(
      tokenCapacity: tokenCapacity,
      tokenDimension: tokenDimension,
      generation: shadowGeneration,
      timestamp: targetTimestamp,
      slots: next
    )
  }
}

@frozen
public struct WorkspaceMutationJournal: Codable, Equatable, Sendable {
  public let baseGeneration: UInt64
  public let shadowGeneration: UInt64
  public let mutations: [WorkspaceMutation]

  public init(
    baseGeneration: UInt64,
    shadowGeneration: UInt64,
    mutations: [WorkspaceMutation] = []
  ) throws {
    let (expectedGeneration, overflow) = baseGeneration.addingReportingOverflow(1)
    guard !overflow, shadowGeneration == expectedGeneration else {
      throw BrainRuntimeError.transaction("workspace journal generation is invalid")
    }
    self.baseGeneration = baseGeneration
    self.shadowGeneration = shadowGeneration
    self.mutations = mutations
  }
}

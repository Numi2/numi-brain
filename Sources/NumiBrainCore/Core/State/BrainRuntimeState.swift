import Foundation

@frozen
public enum ReceptorEventKind: UInt16, Codable, CaseIterable, Sendable {
  case touchOn = 1
  case touchOff = 2
  case impact = 3
  case slip = 4
  case lossOfSupport = 5
  case jointLimit = 6
  case muscleOverload = 7
  case pain = 8
  case injuryRisk = 9
  case soundOnset = 10
  case visualTransient = 11
  case physiologicalCritical = 12
  case rescue = 13
}

@frozen
public struct ReceptorEventToken: Codable, Equatable, Hashable, Sendable {
  public let environmentIdentifier: UInt32
  public let timestamp: BrainTimestamp
  public let kind: ReceptorEventKind
  public let sourceIdentifier: UInt32
  public let magnitude: Float
  public let auxiliaryValue: Float
  public let flags: UInt32

  public init(
    environmentIdentifier: UInt32,
    timestamp: BrainTimestamp,
    kind: ReceptorEventKind,
    sourceIdentifier: UInt32,
    magnitude: Float,
    auxiliaryValue: Float,
    flags: UInt32 = 0
  ) throws {
    guard magnitude.isFinite, magnitude >= 0, auxiliaryValue.isFinite else {
      throw BrainRuntimeError.invalidEvent("receptor event contains an invalid value")
    }
    self.environmentIdentifier = environmentIdentifier
    self.timestamp = timestamp
    self.kind = kind
    self.sourceIdentifier = sourceIdentifier
    self.magnitude = magnitude
    self.auxiliaryValue = auxiliaryValue
    self.flags = flags
  }

  public var interruptMask: BrainInterruptMask {
    switch kind {
    case .impact: .impact
    case .lossOfSupport: .lossOfSupport
    case .jointLimit: .jointLimit
    case .muscleOverload: .muscleOverload
    case .pain: .pain
    case .injuryRisk: .damagingContact
    case .soundOnset: .soundOnset
    case .visualTransient: .visualTransient
    case .physiologicalCritical: .physiologicalCritical
    case .rescue: .rescue
    default: []
    }
  }
}

@frozen
public struct RegionalDelayMessage: Codable, Equatable, Hashable, Sendable {
  public let senderModuleIdentifier: UInt16
  public let receiverModuleIdentifier: UInt16
  public let sourceTimestamp: BrainTimestamp
  public let deliveryTimestamp: BrainTimestamp
  public let token: BrainLatentVector

  public init(
    senderModuleIdentifier: UInt16,
    receiverModuleIdentifier: UInt16,
    sourceTimestamp: BrainTimestamp,
    deliveryTimestamp: BrainTimestamp,
    token: BrainLatentVector
  ) throws {
    guard senderModuleIdentifier > 0, receiverModuleIdentifier > 0,
      senderModuleIdentifier != receiverModuleIdentifier,
      sourceTimestamp <= deliveryTimestamp
    else {
      throw BrainRuntimeError.transaction("regional delay message is invalid")
    }
    self.senderModuleIdentifier = senderModuleIdentifier
    self.receiverModuleIdentifier = receiverModuleIdentifier
    self.sourceTimestamp = sourceTimestamp
    self.deliveryTimestamp = deliveryTimestamp
    self.token = token
  }
}

@frozen
public struct CounterRandomState: Codable, Equatable, Hashable, Sendable {
  public let episodeIdentifier: UInt64
  public let controlStepIdentifier: UInt64
  public let generation: UInt64
  public let moduleCounters: [UInt16: UInt64]

  public init(
    episodeIdentifier: UInt64,
    controlStepIdentifier: UInt64,
    generation: UInt64,
    moduleCounters: [UInt16: UInt64]
  ) throws {
    guard !moduleCounters.keys.contains(0) else {
      throw BrainRuntimeError.transaction("random counter module zero is reserved")
    }
    self.episodeIdentifier = episodeIdentifier
    self.controlStepIdentifier = controlStepIdentifier
    self.generation = generation
    self.moduleCounters = moduleCounters
  }
}

@frozen
public struct MemoryAllocatorState: Codable, Equatable, Hashable, Sendable {
  public let generation: UInt64
  public let activeBytes: UInt64
  public let warmBytes: UInt64
  public let archiveBytes: UInt64
  public let pendingJournalBytes: UInt64
  public let maximumResidentBytes: UInt64

  public init(
    generation: UInt64,
    activeBytes: UInt64,
    warmBytes: UInt64,
    archiveBytes: UInt64,
    pendingJournalBytes: UInt64,
    maximumResidentBytes: UInt64
  ) throws {
    let (activeAndWarm, overflow1) = activeBytes.addingReportingOverflow(warmBytes)
    let (resident, overflow2) = activeAndWarm.addingReportingOverflow(pendingJournalBytes)
    guard !overflow1, !overflow2, resident <= maximumResidentBytes else {
      throw BrainRuntimeError.capacity("memory allocator exceeds resident capacity")
    }
    self.generation = generation
    self.activeBytes = activeBytes
    self.warmBytes = warmBytes
    self.archiveBytes = archiveBytes
    self.pendingJournalBytes = pendingJournalBytes
    self.maximumResidentBytes = maximumResidentBytes
  }
}

@frozen
public struct BrainRuntimeState: Codable, Equatable, Sendable {
  public let committedTimestamp: BrainTimestamp
  public let brainGeneration: UInt64
  public let physicalGeneration: UInt64
  public let parameterVersionFingerprint: UInt64
  public let scheduler: BrainSchedulerSnapshot
  public let eventQueue: [ReceptorEventToken]
  public let delayMessages: [RegionalDelayMessage]
  public let oscillatorPhases: [UInt16: Float]
  public let memoryAllocator: MemoryAllocatorState
  public let random: CounterRandomState
  public let transactionGeneration: UInt64

  public init(
    committedTimestamp: BrainTimestamp,
    brainGeneration: UInt64,
    physicalGeneration: UInt64,
    parameterVersionFingerprint: UInt64,
    scheduler: BrainSchedulerSnapshot,
    eventQueue: [ReceptorEventToken],
    delayMessages: [RegionalDelayMessage],
    oscillatorPhases: [UInt16: Float],
    memoryAllocator: MemoryAllocatorState,
    random: CounterRandomState,
    transactionGeneration: UInt64
  ) throws {
    guard parameterVersionFingerprint > 0,
      scheduler.committedTime == committedTimestamp,
      eventQueue.allSatisfy({ $0.timestamp >= committedTimestamp }),
      delayMessages.allSatisfy({ $0.deliveryTimestamp >= committedTimestamp }),
      !oscillatorPhases.keys.contains(0),
      oscillatorPhases.values.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
      memoryAllocator.generation == brainGeneration,
      random.generation == brainGeneration,
      transactionGeneration >= brainGeneration
    else {
      throw BrainRuntimeError.transaction("brain runtime state is invalid")
    }
    self.committedTimestamp = committedTimestamp
    self.brainGeneration = brainGeneration
    self.physicalGeneration = physicalGeneration
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.scheduler = scheduler
    self.eventQueue = eventQueue.sorted { $0.timestamp < $1.timestamp }
    self.delayMessages = delayMessages.sorted { $0.deliveryTimestamp < $1.deliveryTimestamp }
    self.oscillatorPhases = oscillatorPhases
    self.memoryAllocator = memoryAllocator
    self.random = random
    self.transactionGeneration = transactionGeneration
  }
}

import Foundation
import NumiBrainABI

/// Integer physical simulation time used by the scheduler ABI.
/// Microseconds avoid wall-clock coupling and floating-point due-time drift.
@frozen
public struct BrainTimestamp: RawRepresentable, Codable, Hashable, Comparable, Sendable {
  public let rawValue: UInt64

  public init(rawValue: UInt64) {
    self.rawValue = rawValue
  }

  public init(microseconds: UInt64) {
    rawValue = microseconds
  }

  public static func < (lhs: BrainTimestamp, rhs: BrainTimestamp) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

/// Stable scheduler clock families. Periods remain explicit per module.
@frozen
public enum BrainClockClass: UInt16, Codable, CaseIterable, Comparable, Sendable {
  case physicalFast = 0
  case emergency = 1
  case spinal = 2
  case cpg = 3
  case cerebellar = 4
  case sensoryFusion = 5
  case cortical = 6
  case workspace = 7
  case scene = 8
  case planning = 9
  case abstract = 10
  case replay = 11

  public static func < (lhs: BrainClockClass, rhs: BrainClockClass) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

@frozen
public struct BrainInterruptMask: OptionSet, Codable, Hashable, Sendable {
  public let rawValue: UInt64

  public init(rawValue: UInt64) {
    self.rawValue = rawValue
  }

  public static let pain = Self(rawValue: 1 << 0)
  public static let damagingContact = Self(rawValue: 1 << 1)
  public static let lossOfSupport = Self(rawValue: 1 << 2)
  public static let impact = Self(rawValue: 1 << 3)
  public static let physiologicalCritical = Self(rawValue: 1 << 4)
  public static let jointLimit = Self(rawValue: 1 << 5)
  public static let muscleOverload = Self(rawValue: 1 << 6)
  public static let soundOnset = Self(rawValue: 1 << 7)
  public static let visualTransient = Self(rawValue: 1 << 8)
  public static let rescue = Self(rawValue: 1 << 9)
}

@frozen
public struct BrainInvocationReason: OptionSet, Codable, Hashable, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let periodic = Self(rawValue: 1 << 0)
  public static let interrupt = Self(rawValue: 1 << 1)
}

/// Swift value wrapper around the compiled 32-byte `NBModuleDescriptor` ABI.
@frozen
public struct BrainModuleDescriptor: Codable, Equatable, Hashable, Sendable {
  public let moduleIdentifier: UInt16
  public let clockClass: BrainClockClass
  public let periodMicroseconds: UInt32
  public let conductionDelayMicroseconds: UInt32
  public let intrinsicTimescaleMicroseconds: UInt32
  public let interruptMask: BrainInterruptMask
  public let tokenCount: UInt16
  public let tokenDimension: UInt16
  public let flags: UInt32

  public init(
    moduleIdentifier: UInt16,
    clockClass: BrainClockClass,
    periodMicroseconds: UInt32,
    conductionDelayMicroseconds: UInt32 = 0,
    intrinsicTimescaleMicroseconds: UInt32,
    interruptMask: BrainInterruptMask = [],
    tokenCount: UInt16,
    tokenDimension: UInt16,
    flags: UInt32 = 0
  ) throws {
    guard moduleIdentifier > 0 else {
      throw BrainRuntimeError.invalidDescriptor("module identifier zero is reserved")
    }
    guard periodMicroseconds > 0 else {
      throw BrainRuntimeError.invalidDescriptor("module period must be positive")
    }
    guard intrinsicTimescaleMicroseconds > 0 else {
      throw BrainRuntimeError.invalidDescriptor("intrinsic timescale must be positive")
    }
    guard tokenCount > 0, tokenDimension > 0 else {
      throw BrainRuntimeError.invalidDescriptor("module token shape must be positive")
    }
    self.moduleIdentifier = moduleIdentifier
    self.clockClass = clockClass
    self.periodMicroseconds = periodMicroseconds
    self.conductionDelayMicroseconds = conductionDelayMicroseconds
    self.intrinsicTimescaleMicroseconds = intrinsicTimescaleMicroseconds
    self.interruptMask = interruptMask
    self.tokenCount = tokenCount
    self.tokenDimension = tokenDimension
    self.flags = flags
  }

  private enum CodingKeys: String, CodingKey {
    case moduleIdentifier
    case clockClass
    case periodMicroseconds
    case conductionDelayMicroseconds
    case intrinsicTimescaleMicroseconds
    case interruptMask
    case tokenCount
    case tokenDimension
    case flags
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      moduleIdentifier: values.decode(UInt16.self, forKey: .moduleIdentifier),
      clockClass: values.decode(BrainClockClass.self, forKey: .clockClass),
      periodMicroseconds: values.decode(UInt32.self, forKey: .periodMicroseconds),
      conductionDelayMicroseconds: values.decode(
        UInt32.self,
        forKey: .conductionDelayMicroseconds
      ),
      intrinsicTimescaleMicroseconds: values.decode(
        UInt32.self,
        forKey: .intrinsicTimescaleMicroseconds
      ),
      interruptMask: values.decode(BrainInterruptMask.self, forKey: .interruptMask),
      tokenCount: values.decode(UInt16.self, forKey: .tokenCount),
      tokenDimension: values.decode(UInt16.self, forKey: .tokenDimension),
      flags: values.decode(UInt32.self, forKey: .flags)
    )
  }

  public func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(moduleIdentifier, forKey: .moduleIdentifier)
    try values.encode(clockClass, forKey: .clockClass)
    try values.encode(periodMicroseconds, forKey: .periodMicroseconds)
    try values.encode(conductionDelayMicroseconds, forKey: .conductionDelayMicroseconds)
    try values.encode(intrinsicTimescaleMicroseconds, forKey: .intrinsicTimescaleMicroseconds)
    try values.encode(interruptMask, forKey: .interruptMask)
    try values.encode(tokenCount, forKey: .tokenCount)
    try values.encode(tokenDimension, forKey: .tokenDimension)
    try values.encode(flags, forKey: .flags)
  }

  public var abiRecord: NBModuleDescriptor {
    var record = NBModuleDescriptor()
    record.module_id = moduleIdentifier
    record.clock_class = clockClass.rawValue
    record.period_microseconds = periodMicroseconds
    record.conduction_delay_microseconds = conductionDelayMicroseconds
    record.intrinsic_timescale_microseconds = intrinsicTimescaleMicroseconds
    record.interrupt_mask = interruptMask.rawValue
    record.token_count = tokenCount
    record.token_dimension = tokenDimension
    record.flags = flags
    return record
  }
}

@frozen
public struct BrainModuleSchedule: Codable, Equatable, Sendable {
  public static let abiVersion = UInt32(NB_BRAIN_ABI_VERSION)
  public static let moduleDescriptorByteCount = Int(NB_MODULE_DESCRIPTOR_BYTE_COUNT)

  public let modules: [BrainModuleDescriptor]
  public let fingerprint: UInt64

  public init(modules: [BrainModuleDescriptor]) throws {
    guard !modules.isEmpty else {
      throw BrainRuntimeError.invalidSchedule("at least one module is required")
    }
    guard modules.count <= Int(UInt16.max) else {
      throw BrainRuntimeError.invalidSchedule("module count exceeds the ABI limit")
    }
    let canonical = modules.sorted { $0.moduleIdentifier < $1.moduleIdentifier }
    let records = canonical.map(\.abiRecord)
    let validation = records.withUnsafeBufferPointer { buffer in
      nb_brain_abi_validate_module_descriptors(
        buffer.baseAddress,
        UInt32(buffer.count)
      )
    }
    guard validation == UInt32(NB_MODULE_DESCRIPTOR_VALID.rawValue) else {
      throw BrainRuntimeError.invalidSchedule(
        "compiled ABI validation failed with code \(validation)"
      )
    }
    self.modules = canonical
    self.fingerprint = records.withUnsafeBufferPointer { buffer in
      nb_brain_abi_module_descriptor_fingerprint(
        buffer.baseAddress,
        UInt32(buffer.count)
      )
    }
  }

  private enum CodingKeys: String, CodingKey {
    case modules
    case fingerprint
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let decodedModules = try values.decode([BrainModuleDescriptor].self, forKey: .modules)
    let encodedFingerprint = try values.decode(UInt64.self, forKey: .fingerprint)
    let validated = try BrainModuleSchedule(modules: decodedModules)
    guard validated.fingerprint == encodedFingerprint else {
      throw BrainRuntimeError.invalidSchedule("encoded schedule fingerprint mismatch")
    }
    self = validated
  }

  public func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(modules, forKey: .modules)
    try values.encode(fingerprint, forKey: .fingerprint)
  }

  public var fingerprintHex: String {
    String(format: "%016llx", fingerprint)
  }
}

@frozen
public struct BrainInterruptEvent: Codable, Equatable, Hashable, Sendable {
  public let timestamp: BrainTimestamp
  public let mask: BrainInterruptMask
  public let identifier: UInt32
  public let flags: UInt32

  public init(
    timestamp: BrainTimestamp,
    mask: BrainInterruptMask,
    identifier: UInt32,
    flags: UInt32 = 0
  ) throws {
    guard !mask.isEmpty else {
      throw BrainRuntimeError.invalidEvent("interrupt mask must not be empty")
    }
    self.timestamp = timestamp
    self.mask = mask
    self.identifier = identifier
    self.flags = flags
  }

  private enum CodingKeys: String, CodingKey {
    case timestamp
    case mask
    case identifier
    case flags
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      timestamp: values.decode(BrainTimestamp.self, forKey: .timestamp),
      mask: values.decode(BrainInterruptMask.self, forKey: .mask),
      identifier: values.decode(UInt32.self, forKey: .identifier),
      flags: values.decode(UInt32.self, forKey: .flags)
    )
  }

  public func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(timestamp, forKey: .timestamp)
    try values.encode(mask, forKey: .mask)
    try values.encode(identifier, forKey: .identifier)
    try values.encode(flags, forKey: .flags)
  }

  public var abiRecord: NBInterruptEvent {
    var record = NBInterruptEvent()
    record.timestamp_microseconds = timestamp.rawValue
    record.interrupt_mask = mask.rawValue
    record.identifier = identifier
    record.flags = flags
    return record
  }
}

@frozen
public struct BrainModuleInvocation: Codable, Equatable, Hashable, Sendable {
  public let timestamp: BrainTimestamp
  public let moduleIdentifier: UInt16
  public let clockClass: BrainClockClass
  public let reasons: BrainInvocationReason
  public let interruptMask: BrainInterruptMask

  public init(
    timestamp: BrainTimestamp,
    moduleIdentifier: UInt16,
    clockClass: BrainClockClass,
    reasons: BrainInvocationReason,
    interruptMask: BrainInterruptMask
  ) {
    self.timestamp = timestamp
    self.moduleIdentifier = moduleIdentifier
    self.clockClass = clockClass
    self.reasons = reasons
    self.interruptMask = interruptMask
  }

  public init(abiRecord: NBDueInvocation) throws {
    guard let clockClass = BrainClockClass(rawValue: abiRecord.clock_class) else {
      throw BrainRuntimeError.invalidSchedule("invocation contains an unknown clock class")
    }
    self.init(
      timestamp: BrainTimestamp(microseconds: abiRecord.timestamp_microseconds),
      moduleIdentifier: abiRecord.module_id,
      clockClass: clockClass,
      reasons: BrainInvocationReason(rawValue: abiRecord.reason_flags),
      interruptMask: BrainInterruptMask(rawValue: abiRecord.interrupt_mask)
    )
  }
}

@frozen
public struct BrainModuleClockState: Codable, Equatable, Hashable, Sendable {
  public static let neverUpdated = UInt64.max

  public var nextDue: BrainTimestamp
  public var lastUpdate: BrainTimestamp?

  public init(nextDue: BrainTimestamp, lastUpdate: BrainTimestamp? = nil) {
    self.nextDue = nextDue
    self.lastUpdate = lastUpdate
  }

  public var abiRecord: NBModuleClockState {
    var record = NBModuleClockState()
    record.next_due_microseconds = nextDue.rawValue
    record.last_update_microseconds = lastUpdate?.rawValue ?? Self.neverUpdated
    return record
  }

  public init(abiRecord: NBModuleClockState) {
    self.init(
      nextDue: BrainTimestamp(microseconds: abiRecord.next_due_microseconds),
      lastUpdate: abiRecord.last_update_microseconds == Self.neverUpdated
        ? nil
        : BrainTimestamp(microseconds: abiRecord.last_update_microseconds)
    )
  }
}

@frozen
public struct BrainSchedulerSnapshot: Codable, Equatable, Sendable {
  public let scheduleFingerprint: UInt64
  public let committedTime: BrainTimestamp
  public let generation: UInt64
  public let moduleClocks: [BrainModuleClockState]

  public init(
    scheduleFingerprint: UInt64,
    committedTime: BrainTimestamp,
    generation: UInt64,
    moduleClocks: [BrainModuleClockState]
  ) {
    self.scheduleFingerprint = scheduleFingerprint
    self.committedTime = committedTime
    self.generation = generation
    self.moduleClocks = moduleClocks
  }

  public func stableHash() -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    @inline(__always)
    func mix(_ value: UInt64, into hash: inout UInt64) {
      var littleEndian = value.littleEndian
      withUnsafeBytes(of: &littleEndian) { bytes in
        for byte in bytes {
          hash ^= UInt64(byte)
          hash &*= 0x100_0000_01b3
        }
      }
    }
    mix(scheduleFingerprint, into: &hash)
    mix(committedTime.rawValue, into: &hash)
    mix(generation, into: &hash)
    mix(UInt64(moduleClocks.count), into: &hash)
    for clock in moduleClocks {
      mix(clock.nextDue.rawValue, into: &hash)
      mix(clock.lastUpdate?.rawValue ?? BrainModuleClockState.neverUpdated, into: &hash)
    }
    return String(format: "%016llx", hash)
  }
}

@frozen
public struct BrainSchedulerTransaction: Equatable, Sendable {
  public let scheduleFingerprint: UInt64
  public let baseGeneration: UInt64
  public let baseCommittedTime: BrainTimestamp
  public let targetTime: BrainTimestamp
  public let invocations: [BrainModuleInvocation]
  fileprivate let proposedModuleClocks: [BrainModuleClockState]
}

/// Deterministic CPU oracle for physical-time module scheduling.
/// The production device-resident scheduler will consume the same compiled ABI.
public struct CPUMultiRateScheduler: Sendable {
  public static let maximumInvocationsPerTransaction = 262_144
  public static let maximumEventsPerTransaction = 65_536

  public let schedule: BrainModuleSchedule
  public private(set) var snapshot: BrainSchedulerSnapshot

  public init(
    schedule: BrainModuleSchedule,
    initialTime: BrainTimestamp = BrainTimestamp(microseconds: 0)
  ) {
    self.schedule = schedule
    snapshot = BrainSchedulerSnapshot(
      scheduleFingerprint: schedule.fingerprint,
      committedTime: initialTime,
      generation: 0,
      moduleClocks: schedule.modules.map { _ in
        BrainModuleClockState(nextDue: initialTime)
      }
    )
  }

  public init(schedule: BrainModuleSchedule, restoring snapshot: BrainSchedulerSnapshot) throws {
    guard snapshot.scheduleFingerprint == schedule.fingerprint else {
      throw BrainRuntimeError.transaction("checkpoint schedule fingerprint mismatch")
    }
    guard snapshot.moduleClocks.count == schedule.modules.count else {
      throw BrainRuntimeError.transaction("checkpoint module-clock count mismatch")
    }
    guard
      snapshot.moduleClocks.allSatisfy({ clock in
        clock.nextDue >= snapshot.committedTime
          && (clock.lastUpdate == nil || clock.lastUpdate! <= snapshot.committedTime)
      })
    else {
      throw BrainRuntimeError.transaction("checkpoint module clocks violate committed time")
    }
    self.schedule = schedule
    self.snapshot = snapshot
  }

  public func beginAdvance(
    to targetTime: BrainTimestamp,
    events: [BrainInterruptEvent] = []
  ) throws -> BrainSchedulerTransaction {
    guard targetTime >= snapshot.committedTime else {
      throw BrainRuntimeError.transaction("scheduler time cannot move backward")
    }
    guard events.count <= Self.maximumEventsPerTransaction else {
      throw BrainRuntimeError.capacity("scheduler event capacity exceeded")
    }
    let canonicalEvents = events.sorted(by: Self.eventOrder)
    guard canonicalEvents.allSatisfy({ $0.timestamp >= snapshot.committedTime }) else {
      throw BrainRuntimeError.invalidEvent("stale interrupt predates committed scheduler time")
    }
    guard canonicalEvents.allSatisfy({ $0.timestamp <= targetTime }) else {
      throw BrainRuntimeError.invalidEvent("interrupt lies beyond the transaction target")
    }

    var clocks = snapshot.moduleClocks
    var invocationMap: [InvocationKey: BrainModuleInvocation] = [:]

    for (index, module) in schedule.modules.enumerated() {
      var nextDue = clocks[index].nextDue.rawValue
      while nextDue <= targetTime.rawValue {
        try Self.mergeInvocation(
          timestamp: BrainTimestamp(microseconds: nextDue),
          module: module,
          reason: .periodic,
          interrupts: [],
          into: &invocationMap
        )
        clocks[index].lastUpdate = BrainTimestamp(microseconds: nextDue)
        let (advanced, overflow) = nextDue.addingReportingOverflow(
          UInt64(module.periodMicroseconds)
        )
        guard !overflow else {
          throw BrainRuntimeError.capacity("module next-due timestamp overflow")
        }
        nextDue = advanced
      }
      clocks[index].nextDue = BrainTimestamp(microseconds: nextDue)
    }

    for event in canonicalEvents where event.timestamp <= targetTime {
      for (index, module) in schedule.modules.enumerated()
      where !module.interruptMask.intersection(event.mask).isEmpty {
        let deliveredMask = module.interruptMask.intersection(event.mask)
        try Self.mergeInvocation(
          timestamp: event.timestamp,
          module: module,
          reason: .interrupt,
          interrupts: deliveredMask,
          into: &invocationMap
        )
        if clocks[index].lastUpdate == nil || clocks[index].lastUpdate! < event.timestamp {
          clocks[index].lastUpdate = event.timestamp
        }
      }
    }

    let invocations = invocationMap.values.sorted(by: Self.invocationOrder)
    return BrainSchedulerTransaction(
      scheduleFingerprint: schedule.fingerprint,
      baseGeneration: snapshot.generation,
      baseCommittedTime: snapshot.committedTime,
      targetTime: targetTime,
      invocations: invocations,
      proposedModuleClocks: clocks
    )
  }

  public mutating func commit(_ transaction: BrainSchedulerTransaction) throws {
    guard transaction.scheduleFingerprint == schedule.fingerprint else {
      throw BrainRuntimeError.transaction("transaction schedule fingerprint mismatch")
    }
    guard transaction.baseGeneration == snapshot.generation,
      transaction.baseCommittedTime == snapshot.committedTime
    else {
      throw BrainRuntimeError.transaction("transaction is stale")
    }
    guard transaction.proposedModuleClocks.count == schedule.modules.count else {
      throw BrainRuntimeError.transaction("transaction module-clock count mismatch")
    }
    let (nextGeneration, overflow) = snapshot.generation.addingReportingOverflow(1)
    guard !overflow else {
      throw BrainRuntimeError.capacity("scheduler generation overflow")
    }
    snapshot = BrainSchedulerSnapshot(
      scheduleFingerprint: schedule.fingerprint,
      committedTime: transaction.targetTime,
      generation: nextGeneration,
      moduleClocks: transaction.proposedModuleClocks
    )
  }

  @discardableResult
  public mutating func advance(
    to targetTime: BrainTimestamp,
    events: [BrainInterruptEvent] = []
  ) throws -> [BrainModuleInvocation] {
    let transaction = try beginAdvance(to: targetTime, events: events)
    try commit(transaction)
    return transaction.invocations
  }

  private struct InvocationKey: Hashable {
    let timestamp: BrainTimestamp
    let moduleIdentifier: UInt16
  }

  private static func mergeInvocation(
    timestamp: BrainTimestamp,
    module: BrainModuleDescriptor,
    reason: BrainInvocationReason,
    interrupts: BrainInterruptMask,
    into invocations: inout [InvocationKey: BrainModuleInvocation]
  ) throws {
    let key = InvocationKey(
      timestamp: timestamp,
      moduleIdentifier: module.moduleIdentifier
    )
    if let existing = invocations[key] {
      invocations[key] = BrainModuleInvocation(
        timestamp: timestamp,
        moduleIdentifier: module.moduleIdentifier,
        clockClass: module.clockClass,
        reasons: existing.reasons.union(reason),
        interruptMask: existing.interruptMask.union(interrupts)
      )
    } else {
      guard invocations.count < maximumInvocationsPerTransaction else {
        throw BrainRuntimeError.capacity("scheduler invocation capacity exceeded")
      }
      invocations[key] = BrainModuleInvocation(
        timestamp: timestamp,
        moduleIdentifier: module.moduleIdentifier,
        clockClass: module.clockClass,
        reasons: reason,
        interruptMask: interrupts
      )
    }
  }

  private static func eventOrder(_ lhs: BrainInterruptEvent, _ rhs: BrainInterruptEvent) -> Bool {
    if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
    if lhs.identifier != rhs.identifier { return lhs.identifier < rhs.identifier }
    if lhs.mask.rawValue != rhs.mask.rawValue { return lhs.mask.rawValue < rhs.mask.rawValue }
    return lhs.flags < rhs.flags
  }

  private static func invocationOrder(
    _ lhs: BrainModuleInvocation,
    _ rhs: BrainModuleInvocation
  ) -> Bool {
    if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
    if lhs.clockClass != rhs.clockClass { return lhs.clockClass < rhs.clockClass }
    return lhs.moduleIdentifier < rhs.moduleIdentifier
  }
}

@frozen
public struct BrainScheduledEnvironment: Equatable, Sendable {
  public let environmentIdentifier: UInt32
  public let transaction: BrainSchedulerTransaction

  public init(environmentIdentifier: UInt32, transaction: BrainSchedulerTransaction) {
    self.environmentIdentifier = environmentIdentifier
    self.transaction = transaction
  }
}

@frozen
public struct BrainDispatchEntry: Codable, Equatable, Sendable {
  public let environmentIdentifier: UInt32
  public let reasons: BrainInvocationReason
  public let interruptMask: BrainInterruptMask
}

@frozen
public struct BrainDispatchGroup: Codable, Equatable, Sendable {
  public let timestamp: BrainTimestamp
  public let moduleIdentifier: UInt16
  public let clockClass: BrainClockClass
  public let entries: [BrainDispatchEntry]
}

public enum BrainSchedulerCohort {
  public static func compact(
    _ environments: [BrainScheduledEnvironment]
  ) throws -> [BrainDispatchGroup] {
    guard let fingerprint = environments.first?.transaction.scheduleFingerprint else {
      return []
    }
    guard environments.allSatisfy({ $0.transaction.scheduleFingerprint == fingerprint }) else {
      throw BrainRuntimeError.invalidSchedule("cohort schedules do not share a fingerprint")
    }
    let identifiers = environments.map(\.environmentIdentifier)
    guard Set(identifiers).count == identifiers.count else {
      throw BrainRuntimeError.invalidSchedule("cohort environment identifiers must be unique")
    }

    struct GroupKey: Hashable {
      let timestamp: BrainTimestamp
      let moduleIdentifier: UInt16
      let clockClass: BrainClockClass
    }
    var grouped: [GroupKey: [BrainDispatchEntry]] = [:]
    for environment in environments {
      for invocation in environment.transaction.invocations {
        let key = GroupKey(
          timestamp: invocation.timestamp,
          moduleIdentifier: invocation.moduleIdentifier,
          clockClass: invocation.clockClass
        )
        grouped[key, default: []].append(
          BrainDispatchEntry(
            environmentIdentifier: environment.environmentIdentifier,
            reasons: invocation.reasons,
            interruptMask: invocation.interruptMask
          )
        )
      }
    }
    return grouped.map { key, entries in
      BrainDispatchGroup(
        timestamp: key.timestamp,
        moduleIdentifier: key.moduleIdentifier,
        clockClass: key.clockClass,
        entries: entries.sorted { $0.environmentIdentifier < $1.environmentIdentifier }
      )
    }.sorted { lhs, rhs in
      if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
      if lhs.clockClass != rhs.clockClass { return lhs.clockClass < rhs.clockClass }
      return lhs.moduleIdentifier < rhs.moduleIdentifier
    }
  }
}

public enum BrainRuntimeError: Error, Equatable, CustomStringConvertible {
  case invalidDescriptor(String)
  case invalidSchedule(String)
  case invalidEvent(String)
  case transaction(String)
  case capacity(String)

  public var description: String {
    switch self {
    case .invalidDescriptor(let message): "invalid module descriptor: \(message)"
    case .invalidSchedule(let message): "invalid module schedule: \(message)"
    case .invalidEvent(let message): "invalid scheduler event: \(message)"
    case .transaction(let message): "scheduler transaction error: \(message)"
    case .capacity(let message): "scheduler capacity error: \(message)"
    }
  }
}

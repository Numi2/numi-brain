import Foundation
import NumiBrainABI

/// One flattened active-environment invocation ready for a downstream
/// region-major consumer. Group identity preserves deterministic provenance.
@frozen
public struct BrainDispatchWorkItem: Codable, Equatable, Sendable {
  public let timestamp: BrainTimestamp
  public let interruptMask: BrainInterruptMask
  public let environmentIdentifier: UInt32
  public let reasons: BrainInvocationReason
  public let moduleIdentifier: UInt16
  public let clockClass: BrainClockClass
  public let groupIndex: UInt32

  public init(
    timestamp: BrainTimestamp,
    interruptMask: BrainInterruptMask,
    environmentIdentifier: UInt32,
    reasons: BrainInvocationReason,
    moduleIdentifier: UInt16,
    clockClass: BrainClockClass,
    groupIndex: UInt32
  ) {
    self.timestamp = timestamp
    self.interruptMask = interruptMask
    self.environmentIdentifier = environmentIdentifier
    self.reasons = reasons
    self.moduleIdentifier = moduleIdentifier
    self.clockClass = clockClass
    self.groupIndex = groupIndex
  }

  public var abiRecord: NBDispatchWorkItem {
    var record = NBDispatchWorkItem()
    record.timestamp_microseconds = timestamp.rawValue
    record.interrupt_mask = interruptMask.rawValue
    record.environment_identifier = environmentIdentifier
    record.reason_flags = reasons.rawValue
    record.module_id = moduleIdentifier
    record.clock_class = clockClass.rawValue
    record.group_index = groupIndex
    return record
  }
}

/// Independent environment-major compact recurrent state produced by cohort
/// execution. It is the existing regional trace primitive, not token state.
@frozen
public struct BrainCohortRegionalState: Equatable, Sendable {
  public let environmentIdentifier: UInt32
  public let states: [RegionalModuleState]

  public init(environmentIdentifier: UInt32, states: [RegionalModuleState]) {
    self.environmentIdentifier = environmentIdentifier
    self.states = states
  }
}

/// A compiled, flattened cohort dispatch plan. It preserves independent
/// environment state while grouping identical module work for later
/// region-major GPU execution.
@frozen
public struct BrainDispatchPlan: Codable, Equatable, Sendable {
  public static let planVersion = UInt32(NB_DISPATCH_PLAN_VERSION)
  public static let environmentByteCount = Int(NB_COHORT_ENVIRONMENT_BYTE_COUNT)
  public static let groupByteCount = Int(NB_DISPATCH_GROUP_BYTE_COUNT)
  public static let entryByteCount = Int(NB_DISPATCH_ENTRY_BYTE_COUNT)
  public static let headerByteCount = Int(NB_DISPATCH_PLAN_HEADER_BYTE_COUNT)
  public static let resultByteCount = Int(NB_DISPATCH_PLAN_RESULT_BYTE_COUNT)
  public static let workItemByteCount = Int(NB_DISPATCH_WORK_ITEM_BYTE_COUNT)
  public static let cohortUniformByteCount = Int(NB_DISPATCH_COHORT_UNIFORMS_BYTE_COUNT)

  public let scheduleFingerprint: UInt64
  public let parameterVersionFingerprint: UInt64
  public let cohortFingerprint: UInt64
  public let fingerprint: UInt64
  public let groups: [BrainDispatchGroup]

  public init(environments: [BrainScheduledEnvironment]) throws {
    guard !environments.isEmpty else {
      throw BrainRuntimeError.invalidSchedule("dispatch plan requires at least one environment")
    }
    let canonical = environments.sorted {
      $0.environmentIdentifier < $1.environmentIdentifier
    }
    guard Set(canonical.map(\.environmentIdentifier)).count == canonical.count else {
      throw BrainRuntimeError.invalidSchedule(
        "dispatch-plan environment identifiers must be unique"
      )
    }
    let scheduleFingerprint = canonical[0].transaction.scheduleFingerprint
    let parameterVersionFingerprint = canonical[0].transaction.parameterVersionFingerprint
    guard scheduleFingerprint > 0, parameterVersionFingerprint > 0 else {
      throw BrainRuntimeError.invalidParameterVersion(
        "compiled dispatch plans require schedule and parameter identities"
      )
    }
    guard
      canonical.allSatisfy({ environment in
        environment.transaction.scheduleFingerprint == scheduleFingerprint
          && environment.transaction.parameterVersionFingerprint
            == parameterVersionFingerprint
      })
    else {
      throw BrainRuntimeError.invalidParameterVersion(
        "dispatch-plan environments do not share schedule and parameter identity"
      )
    }

    var invocationOffset: UInt32 = 0
    var environmentRecords: [NBCohortEnvironment] = []
    environmentRecords.reserveCapacity(canonical.count)
    for environment in canonical {
      guard environment.transaction.invocations.count <= Int(UInt32.max) else {
        throw BrainRuntimeError.capacity("environment invocation count exceeds the ABI limit")
      }
      let count = UInt32(environment.transaction.invocations.count)
      let (nextOffset, overflow) = invocationOffset.addingReportingOverflow(count)
      guard !overflow else {
        throw BrainRuntimeError.capacity("cohort invocation count exceeds the ABI limit")
      }
      var record = NBCohortEnvironment()
      record.environment_identifier = environment.environmentIdentifier
      record.invocation_offset = invocationOffset
      record.invocation_count = count
      record.reserved = 0
      record.base_generation = environment.transaction.baseGeneration
      record.base_committed_time_microseconds =
        environment.transaction.baseCommittedTime.rawValue
      record.target_time_microseconds = environment.transaction.targetTime.rawValue
      environmentRecords.append(record)
      invocationOffset = nextOffset
    }
    let cohortFingerprint = environmentRecords.withUnsafeBufferPointer { records in
      nb_brain_abi_cohort_environment_fingerprint(
        records.baseAddress,
        UInt32(records.count)
      )
    }
    let groups = try BrainSchedulerCohort.compact(canonical)
    try self.init(
      scheduleFingerprint: scheduleFingerprint,
      parameterVersionFingerprint: parameterVersionFingerprint,
      cohortFingerprint: cohortFingerprint,
      groups: groups,
      expectedFingerprint: nil
    )
  }

  private init(
    scheduleFingerprint: UInt64,
    parameterVersionFingerprint: UInt64,
    cohortFingerprint: UInt64,
    groups: [BrainDispatchGroup],
    expectedFingerprint: UInt64?
  ) throws {
    guard groups.count <= Int(UInt32.max) else {
      throw BrainRuntimeError.capacity("dispatch group count exceeds the ABI limit")
    }
    var groupRecords: [NBDispatchGroup] = []
    var entryRecords: [NBDispatchEntry] = []
    groupRecords.reserveCapacity(groups.count)
    for group in groups {
      guard group.entries.count <= Int(UInt32.max) else {
        throw BrainRuntimeError.capacity("dispatch entry count exceeds the ABI limit")
      }
      let entryOffset = UInt32(entryRecords.count)
      let entryCount = UInt32(group.entries.count)
      let (nextEntryCount, overflow) = entryOffset.addingReportingOverflow(entryCount)
      guard !overflow else {
        throw BrainRuntimeError.capacity("dispatch entry span exceeds the ABI limit")
      }
      var groupRecord = NBDispatchGroup()
      groupRecord.timestamp_microseconds = group.timestamp.rawValue
      groupRecord.entry_offset = entryOffset
      groupRecord.entry_count = entryCount
      groupRecord.module_id = group.moduleIdentifier
      groupRecord.clock_class = group.clockClass.rawValue
      groupRecord.reserved = 0
      groupRecords.append(groupRecord)
      entryRecords.append(
        contentsOf: group.entries.map { entry in
          var record = NBDispatchEntry()
          record.interrupt_mask = entry.interruptMask.rawValue
          record.environment_identifier = entry.environmentIdentifier
          record.reason_flags = entry.reasons.rawValue
          return record
        })
      guard entryRecords.count == Int(nextEntryCount) else {
        throw BrainRuntimeError.capacity("dispatch entry span does not match flattened records")
      }
    }
    guard entryRecords.count <= Int(UInt32.max) else {
      throw BrainRuntimeError.capacity("dispatch entry count exceeds the ABI limit")
    }
    var header = NBDispatchPlanHeader()
    header.schedule_fingerprint = scheduleFingerprint
    header.parameter_version_fingerprint = parameterVersionFingerprint
    header.cohort_fingerprint = cohortFingerprint
    header.plan_fingerprint = 0
    header.group_count = UInt32(groupRecords.count)
    header.entry_count = UInt32(entryRecords.count)
    header.plan_version = Self.planVersion
    header.flags = 0
    header.plan_fingerprint = groupRecords.withUnsafeBufferPointer { groups in
      entryRecords.withUnsafeBufferPointer { entries in
        withUnsafePointer(to: &header) { header in
          nb_brain_abi_dispatch_plan_fingerprint(
            header,
            groups.baseAddress,
            entries.baseAddress
          )
        }
      }
    }
    let validation = groupRecords.withUnsafeBufferPointer { groups in
      entryRecords.withUnsafeBufferPointer { entries in
        withUnsafePointer(to: &header) { header in
          nb_brain_abi_validate_dispatch_plan(
            header,
            groups.baseAddress,
            entries.baseAddress
          )
        }
      }
    }
    guard validation == UInt32(NB_DISPATCH_PLAN_VALID.rawValue) else {
      throw BrainRuntimeError.invalidSchedule(
        "compiled dispatch-plan validation failed with code \(validation)"
      )
    }
    if let expectedFingerprint, expectedFingerprint != header.plan_fingerprint {
      throw BrainRuntimeError.invalidSchedule("encoded dispatch-plan fingerprint mismatch")
    }
    self.scheduleFingerprint = scheduleFingerprint
    self.parameterVersionFingerprint = parameterVersionFingerprint
    self.cohortFingerprint = cohortFingerprint
    self.fingerprint = header.plan_fingerprint
    self.groups = groups
  }

  private enum CodingKeys: String, CodingKey {
    case scheduleFingerprint
    case parameterVersionFingerprint
    case cohortFingerprint
    case fingerprint
    case groups
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      scheduleFingerprint: values.decode(UInt64.self, forKey: .scheduleFingerprint),
      parameterVersionFingerprint: values.decode(
        UInt64.self,
        forKey: .parameterVersionFingerprint
      ),
      cohortFingerprint: values.decode(UInt64.self, forKey: .cohortFingerprint),
      groups: values.decode([BrainDispatchGroup].self, forKey: .groups),
      expectedFingerprint: values.decode(UInt64.self, forKey: .fingerprint)
    )
  }

  public var fingerprintHex: String { String(format: "%016llx", fingerprint) }
  public var cohortFingerprintHex: String { String(format: "%016llx", cohortFingerprint) }

  public var entryCount: Int { groups.reduce(0) { $0 + $1.entries.count } }

  public var activeEnvironmentIdentifiers: [UInt32] {
    Array(Set(groups.flatMap { $0.entries.map(\.environmentIdentifier) })).sorted()
  }

  public var workItems: [BrainDispatchWorkItem] {
    groups.enumerated().flatMap { groupIndex, group in
      group.entries.map { entry in
        BrainDispatchWorkItem(
          timestamp: group.timestamp,
          interruptMask: entry.interruptMask,
          environmentIdentifier: entry.environmentIdentifier,
          reasons: entry.reasons,
          moduleIdentifier: group.moduleIdentifier,
          clockClass: group.clockClass,
          groupIndex: UInt32(groupIndex)
        )
      }
    }
  }

  public var workFingerprint: UInt64 {
    let records = workItems.map(\.abiRecord)
    return records.withUnsafeBufferPointer { records in
      nb_brain_abi_dispatch_work_fingerprint(
        fingerprint,
        parameterVersionFingerprint,
        records.baseAddress,
        UInt32(records.count)
      )
    }
  }

  public func invocations(
    for environmentIdentifier: UInt32
  ) -> [BrainModuleInvocation] {
    workItems.compactMap { item in
      guard item.environmentIdentifier == environmentIdentifier else { return nil }
      return BrainModuleInvocation(
        timestamp: item.timestamp,
        moduleIdentifier: item.moduleIdentifier,
        clockClass: item.clockClass,
        reasons: item.reasons,
        interruptMask: item.interruptMask
      )
    }
  }

  public var abiHeader: NBDispatchPlanHeader {
    var record = NBDispatchPlanHeader()
    record.schedule_fingerprint = scheduleFingerprint
    record.parameter_version_fingerprint = parameterVersionFingerprint
    record.cohort_fingerprint = cohortFingerprint
    record.plan_fingerprint = fingerprint
    record.group_count = UInt32(groups.count)
    record.entry_count = UInt32(entryCount)
    record.plan_version = Self.planVersion
    record.flags = 0
    return record
  }

  public var groupABIRecords: [NBDispatchGroup] {
    var entryOffset: UInt32 = 0
    return groups.map { group in
      var record = NBDispatchGroup()
      record.timestamp_microseconds = group.timestamp.rawValue
      record.entry_offset = entryOffset
      record.entry_count = UInt32(group.entries.count)
      record.module_id = group.moduleIdentifier
      record.clock_class = group.clockClass.rawValue
      record.reserved = 0
      entryOffset += UInt32(group.entries.count)
      return record
    }
  }

  public var entryABIRecords: [NBDispatchEntry] {
    groups.flatMap { group in
      group.entries.map { entry in
        var record = NBDispatchEntry()
        record.interrupt_mask = entry.interruptMask.rawValue
        record.environment_identifier = entry.environmentIdentifier
        record.reason_flags = entry.reasons.rawValue
        return record
      }
    }
  }
}

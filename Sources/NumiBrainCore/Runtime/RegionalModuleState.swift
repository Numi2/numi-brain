import Foundation
import NumiBrainABI

/// A compact executable regional trace. This is the first schedule-driven
/// population-state primitive, not the final trainable token operator.
@frozen
public struct RegionalModuleState: Equatable, Sendable {
  public static let neverUpdated = UInt64.max
  public static let abiByteCount = Int(NB_REGIONAL_MODULE_STATE_BYTE_COUNT)

  public var activation: Float
  public var integration: Float
  public var interruptSalience: Float
  public var phase: Float
  public var updateCount: UInt32
  public var interruptCount: UInt32
  public var lastUpdate: BrainTimestamp?

  public init(
    activation: Float = 0,
    integration: Float = 0,
    interruptSalience: Float = 0,
    phase: Float = 0,
    updateCount: UInt32 = 0,
    interruptCount: UInt32 = 0,
    lastUpdate: BrainTimestamp? = nil
  ) {
    self.activation = activation
    self.integration = integration
    self.interruptSalience = interruptSalience
    self.phase = phase
    self.updateCount = updateCount
    self.interruptCount = interruptCount
    self.lastUpdate = lastUpdate
  }

  public var abiRecord: NBRegionalModuleState {
    var record = NBRegionalModuleState()
    record.activation = activation
    record.integration = integration
    record.interrupt_salience = interruptSalience
    record.phase = phase
    record.update_count = updateCount
    record.interrupt_count = interruptCount
    record.last_update_microseconds = lastUpdate?.rawValue ?? Self.neverUpdated
    return record
  }

  public init(abiRecord: NBRegionalModuleState) {
    self.init(
      activation: abiRecord.activation,
      integration: abiRecord.integration,
      interruptSalience: abiRecord.interrupt_salience,
      phase: abiRecord.phase,
      updateCount: abiRecord.update_count,
      interruptCount: abiRecord.interrupt_count,
      lastUpdate: abiRecord.last_update_microseconds == Self.neverUpdated
        ? nil
        : BrainTimestamp(microseconds: abiRecord.last_update_microseconds)
    )
  }
}

@frozen
public struct RegionalModuleSnapshot: Equatable, Sendable {
  public let scheduleFingerprint: UInt64
  public let committedTime: BrainTimestamp
  public let generation: UInt64
  public let states: [RegionalModuleState]

  public init(
    scheduleFingerprint: UInt64,
    committedTime: BrainTimestamp,
    generation: UInt64,
    states: [RegionalModuleState]
  ) {
    self.scheduleFingerprint = scheduleFingerprint
    self.committedTime = committedTime
    self.generation = generation
    self.states = states
  }

  public func stableHash() -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    @inline(__always)
    func mix(_ value: UInt64, into hash: inout UInt64) {
      var littleEndian = value.littleEndian
      withUnsafeBytes(of: &littleEndian) { bytes in
        for byte in bytes {
          hash ^= UInt64(byte)
          hash &*= 0x0000_0100_0000_01b3
        }
      }
    }
    mix(scheduleFingerprint, into: &hash)
    mix(committedTime.rawValue, into: &hash)
    mix(generation, into: &hash)
    mix(UInt64(states.count), into: &hash)
    for state in states {
      mix(UInt64(state.activation.bitPattern), into: &hash)
      mix(UInt64(state.integration.bitPattern), into: &hash)
      mix(UInt64(state.interruptSalience.bitPattern), into: &hash)
      mix(UInt64(state.phase.bitPattern), into: &hash)
      mix(UInt64(state.updateCount), into: &hash)
      mix(UInt64(state.interruptCount), into: &hash)
      mix(state.lastUpdate?.rawValue ?? RegionalModuleState.neverUpdated, into: &hash)
    }
    return String(format: "%016llx", hash)
  }
}

public enum CPURegionalModuleOperator {
  public static func advance(
    states initialStates: [RegionalModuleState],
    schedule: BrainModuleSchedule,
    invocations: [BrainModuleInvocation]
  ) throws -> [RegionalModuleState] {
    guard initialStates.count == schedule.modules.count else {
      throw BrainRuntimeError.invalidSchedule("regional state count does not match module count")
    }
    let moduleIndices = Dictionary(
      uniqueKeysWithValues: schedule.modules.enumerated().map {
        ($0.element.moduleIdentifier, $0.offset)
      }
    )
    var states = initialStates
    for invocation in invocations {
      guard let moduleIndex = moduleIndices[invocation.moduleIdentifier] else {
        throw BrainRuntimeError.invalidSchedule("regional invocation names an unknown module")
      }
      let module = schedule.modules[moduleIndex]
      var state = states[moduleIndex]
      let elapsedMicroseconds: UInt64
      if let lastUpdate = state.lastUpdate {
        guard invocation.timestamp >= lastUpdate else {
          throw BrainRuntimeError.transaction("regional invocation time moved backward")
        }
        elapsedMicroseconds = invocation.timestamp.rawValue - lastUpdate.rawValue
      } else {
        elapsedMicroseconds = UInt64(module.periodMicroseconds)
      }
      let decay = Float(
        Foundation.exp(
          -Double(elapsedMicroseconds) / Double(module.intrinsicTimescaleMicroseconds)
        )
      )
      let blend = 1 - decay
      let periodicDrive: Float = invocation.reasons.contains(.periodic) ? 0.25 : 0
      let interruptDrive = min(Float(invocation.interruptMask.rawValue.nonzeroBitCount) * 0.125, 1)
      let target = min(periodicDrive + interruptDrive, 1)
      state.activation = min(max(decay * state.activation + blend * target, 0), 1)
      state.integration = min(
        max(decay * state.integration + blend * state.activation, 0),
        1
      )
      state.interruptSalience = min(
        max(decay * state.interruptSalience + blend * interruptDrive, 0),
        1
      )
      state.phase =
        Float(
          invocation.timestamp.rawValue % UInt64(module.periodMicroseconds)
        ) / Float(module.periodMicroseconds)
      state.updateCount = state.updateCount == UInt32.max ? UInt32.max : state.updateCount + 1
      if invocation.reasons.contains(.interrupt) {
        state.interruptCount =
          state.interruptCount == UInt32.max
          ? UInt32.max
          : state.interruptCount + 1
      }
      state.lastUpdate = invocation.timestamp
      states[moduleIndex] = state
    }
    return states
  }
}

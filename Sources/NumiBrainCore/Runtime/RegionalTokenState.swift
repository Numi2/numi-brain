import Foundation
import NumiBrainABI

@frozen
public struct RegionalRouteFlags: OptionSet, Codable, Hashable, Sendable {
  public let rawValue: UInt16

  public init(rawValue: UInt16) {
    self.rawValue = rawValue
  }

  public static let emergency = Self(rawValue: 1 << 0)
  public static let persistent = Self(rawValue: 1 << 1)
}

/// A compiled sparse message edge. Zero-delay routes read the common
/// pre-timestamp state; delayed routes read transaction-owned delivery history.
@frozen
public struct RegionalTokenRoute: Codable, Equatable, Hashable, Sendable {
  public let senderModuleIdentifier: UInt16
  public let receiverModuleIdentifier: UInt16
  public let senderToken: UInt16
  public let delayMicroseconds: UInt32
  public let gain: Float
  public let flags: RegionalRouteFlags

  public init(
    senderModuleIdentifier: UInt16,
    receiverModuleIdentifier: UInt16,
    senderToken: UInt16 = 0,
    delayMicroseconds: UInt32 = 0,
    gain: Float,
    flags: RegionalRouteFlags = []
  ) throws {
    guard senderModuleIdentifier > 0, receiverModuleIdentifier > 0 else {
      throw BrainRuntimeError.invalidDescriptor("regional route module identifiers must be nonzero")
    }
    guard senderModuleIdentifier != receiverModuleIdentifier else {
      throw BrainRuntimeError.invalidDescriptor("regional self-routes belong in local computation")
    }
    guard delayMicroseconds <= UInt32(NB_REGIONAL_MAX_ROUTE_DELAY_MICROSECONDS) else {
      throw BrainRuntimeError.invalidDescriptor(
        "regional route delay exceeds \(NB_REGIONAL_MAX_ROUTE_DELAY_MICROSECONDS) microseconds"
      )
    }
    guard gain.isFinite else {
      throw BrainRuntimeError.invalidDescriptor("regional route gain must be finite")
    }
    self.senderModuleIdentifier = senderModuleIdentifier
    self.receiverModuleIdentifier = receiverModuleIdentifier
    self.senderToken = senderToken
    self.delayMicroseconds = delayMicroseconds
    self.gain = gain
    self.flags = flags
  }

  fileprivate func abiRecord(
    historyValueOffset: UInt32,
    messageDimension: UInt32
  ) -> NBRegionalRoute {
    var record = NBRegionalRoute()
    record.sender_module_id = senderModuleIdentifier
    record.receiver_module_id = receiverModuleIdentifier
    record.sender_token = senderToken
    record.flags = flags.rawValue
    record.delay_microseconds = delayMicroseconds
    record.gain = gain
    record.history_value_offset = historyValueOffset
    record.message_dimension = messageDimension
    return record
  }
}

@frozen
public struct RegionalTokenLayout: Codable, Equatable, Hashable, Sendable {
  public let moduleIdentifier: UInt16
  public let tokenCount: UInt16
  public let tokenDimension: UInt16
  public let scalarOffset: UInt32
  public let scalarCount: UInt32
  public let parameterOffset: UInt32
  public let incomingRouteOffset: UInt32
  public let incomingRouteCount: UInt16
  public let flags: UInt32

  public var scalarRange: Range<Int> {
    Int(scalarOffset)..<Int(scalarOffset + scalarCount)
  }

  public var abiRecord: NBRegionalTokenLayout {
    var record = NBRegionalTokenLayout()
    record.scalar_offset = scalarOffset
    record.scalar_count = scalarCount
    record.parameter_offset = parameterOffset
    record.incoming_route_offset = incomingRouteOffset
    record.module_id = moduleIdentifier
    record.token_count = tokenCount
    record.token_dimension = tokenDimension
    record.incoming_route_count = incomingRouteCount
    record.flags = flags
    return record
  }
}

/// Immutable factorized slow parameters for one recurrent token scalar.
/// The structure is deliberately explicit so a learner can publish a new
/// fingerprinted version without mutating rollout-owned recurrent state.
@frozen
public struct RegionalTokenParameters: Codable, Equatable, Hashable, Sendable {
  public let recurrentGain: Float
  public let localGain: Float
  public let routeGain: Float
  public let driveGain: Float
  public let bias: Float
  public let gateBias: Float
  public let gateRecurrentGain: Float
  public let gateInputGain: Float

  public init(
    recurrentGain: Float,
    localGain: Float,
    routeGain: Float,
    driveGain: Float,
    bias: Float,
    gateBias: Float,
    gateRecurrentGain: Float,
    gateInputGain: Float
  ) {
    self.recurrentGain = recurrentGain
    self.localGain = localGain
    self.routeGain = routeGain
    self.driveGain = driveGain
    self.bias = bias
    self.gateBias = gateBias
    self.gateRecurrentGain = gateRecurrentGain
    self.gateInputGain = gateInputGain
  }

  public var abiRecord: NBRegionalTokenParameters {
    var record = NBRegionalTokenParameters()
    record.recurrent_gain = recurrentGain
    record.local_gain = localGain
    record.route_gain = routeGain
    record.drive_gain = driveGain
    record.bias = bias
    record.gate_bias = gateBias
    record.gate_recurrent_gain = gateRecurrentGain
    record.gate_input_gain = gateInputGain
    return record
  }
}

@frozen
public struct RegionalTokenProgram: Equatable, Sendable {
  public static let programVersion: UInt32 = 1
  public static let routeHistoryCapacity = Int(NB_REGIONAL_ROUTE_HISTORY_CAPACITY)

  public let scheduleFingerprint: UInt64
  public let layouts: [RegionalTokenLayout]
  public let routes: [RegionalTokenRoute]
  public let routeHistoryValueOffsets: [UInt32]
  public let routeMessageDimensions: [UInt32]
  public let routeHistoryScalarCount: Int
  public let parameters: [RegionalTokenParameters]
  public let fingerprint: UInt64

  public init(
    schedule: BrainModuleSchedule,
    routes requestedRoutes: [RegionalTokenRoute],
    parameters requestedParameters: [RegionalTokenParameters]? = nil
  ) throws {
    let moduleIdentifiers = Set(schedule.modules.map(\.moduleIdentifier))
    let canonicalRoutes = requestedRoutes.sorted {
      if $0.receiverModuleIdentifier != $1.receiverModuleIdentifier {
        return $0.receiverModuleIdentifier < $1.receiverModuleIdentifier
      }
      if $0.senderModuleIdentifier != $1.senderModuleIdentifier {
        return $0.senderModuleIdentifier < $1.senderModuleIdentifier
      }
      return $0.senderToken < $1.senderToken
    }
    guard Set(canonicalRoutes.map(\.senderModuleIdentifier)).isSubset(of: moduleIdentifiers),
      Set(canonicalRoutes.map(\.receiverModuleIdentifier)).isSubset(of: moduleIdentifiers)
    else {
      throw BrainRuntimeError.invalidSchedule("regional route names an unknown module")
    }
    for (previous, current) in zip(canonicalRoutes, canonicalRoutes.dropFirst()) {
      guard
        previous.receiverModuleIdentifier != current.receiverModuleIdentifier
          || previous.senderModuleIdentifier != current.senderModuleIdentifier
          || previous.senderToken != current.senderToken
      else {
        throw BrainRuntimeError.invalidSchedule(
          "duplicate regional route identity is not canonical")
      }
    }

    var scalarOffset: UInt32 = 0
    var incomingRouteOffset: UInt32 = 0
    var layouts: [RegionalTokenLayout] = []
    layouts.reserveCapacity(schedule.modules.count)
    for module in schedule.modules {
      let scalarProduct = UInt64(module.tokenCount) * UInt64(module.tokenDimension)
      guard scalarProduct <= UInt64(UInt32.max),
        UInt64(scalarOffset) + scalarProduct <= UInt64(UInt32.max)
      else {
        throw BrainRuntimeError.invalidSchedule("regional token scalar count exceeds ABI limits")
      }
      let incomingCount = canonicalRoutes.lazy.filter {
        $0.receiverModuleIdentifier == module.moduleIdentifier
      }.count
      guard incomingCount <= Int(UInt16.max),
        UInt64(incomingRouteOffset) + UInt64(incomingCount) <= UInt64(UInt32.max)
      else {
        throw BrainRuntimeError.invalidSchedule("regional incoming route count exceeds ABI limits")
      }
      layouts.append(
        RegionalTokenLayout(
          moduleIdentifier: module.moduleIdentifier,
          tokenCount: module.tokenCount,
          tokenDimension: module.tokenDimension,
          scalarOffset: scalarOffset,
          scalarCount: UInt32(scalarProduct),
          parameterOffset: scalarOffset,
          incomingRouteOffset: incomingRouteOffset,
          incomingRouteCount: UInt16(incomingCount),
          flags: module.flags
        )
      )
      scalarOffset += UInt32(scalarProduct)
      incomingRouteOffset += UInt32(incomingCount)
    }

    let parameters =
      requestedParameters
      ?? Self.makeFoundationParameters(schedule: schedule, layouts: layouts)
    guard parameters.count == Int(scalarOffset) else {
      throw BrainRuntimeError.invalidSchedule(
        "regional parameter count must equal the token scalar count"
      )
    }
    let moduleIndices = Dictionary(
      uniqueKeysWithValues: schedule.modules.enumerated().map {
        ($0.element.moduleIdentifier, $0.offset)
      }
    )
    var routeHistoryValueOffsets: [UInt32] = []
    var routeMessageDimensions: [UInt32] = []
    routeHistoryValueOffsets.reserveCapacity(canonicalRoutes.count)
    routeMessageDimensions.reserveCapacity(canonicalRoutes.count)
    var routeHistoryScalarCount: UInt32 = 0
    for route in canonicalRoutes {
      guard let senderIndex = moduleIndices[route.senderModuleIdentifier] else {
        throw BrainRuntimeError.invalidSchedule("regional route sender disappeared")
      }
      let messageDimension = UInt32(layouts[senderIndex].tokenDimension)
      let historyScalars =
        UInt64(messageDimension)
        * UInt64(Self.routeHistoryCapacity)
      guard UInt64(routeHistoryScalarCount) + historyScalars <= UInt64(UInt32.max) else {
        throw BrainRuntimeError.invalidSchedule("regional route history exceeds ABI limits")
      }
      routeHistoryValueOffsets.append(routeHistoryScalarCount)
      routeMessageDimensions.append(messageDimension)
      routeHistoryScalarCount += UInt32(historyScalars)
    }

    let descriptorRecords = schedule.modules.map(\.abiRecord)
    let layoutRecords = layouts.map(\.abiRecord)
    let routeRecords = zip(
      canonicalRoutes.indices,
      canonicalRoutes
    ).map { routeIndex, route in
      route.abiRecord(
        historyValueOffset: routeHistoryValueOffsets[routeIndex],
        messageDimension: routeMessageDimensions[routeIndex]
      )
    }
    let parameterRecords = parameters.map(\.abiRecord)
    let validation = descriptorRecords.withUnsafeBufferPointer { descriptors in
      layoutRecords.withUnsafeBufferPointer { layouts in
        routeRecords.withUnsafeBufferPointer { routes in
          parameterRecords.withUnsafeBufferPointer { parameters in
            nb_brain_abi_validate_regional_program(
              descriptors.baseAddress,
              layouts.baseAddress,
              UInt32(descriptors.count),
              routes.baseAddress,
              UInt32(routes.count),
              parameters.baseAddress,
              UInt32(parameters.count)
            )
          }
        }
      }
    }
    guard validation == UInt32(NB_REGIONAL_PROGRAM_VALID.rawValue) else {
      throw BrainRuntimeError.invalidSchedule(
        "compiled regional-program validation failed with code \(validation)"
      )
    }
    let fingerprint = layoutRecords.withUnsafeBufferPointer { layouts in
      routeRecords.withUnsafeBufferPointer { routes in
        parameterRecords.withUnsafeBufferPointer { parameters in
          nb_brain_abi_regional_program_fingerprint(
            layouts.baseAddress,
            UInt32(layouts.count),
            routes.baseAddress,
            UInt32(routes.count),
            parameters.baseAddress,
            UInt32(parameters.count)
          )
        }
      }
    }
    self.scheduleFingerprint = schedule.fingerprint
    self.layouts = layouts
    self.routes = canonicalRoutes
    self.routeHistoryValueOffsets = routeHistoryValueOffsets
    self.routeMessageDimensions = routeMessageDimensions
    self.routeHistoryScalarCount = Int(routeHistoryScalarCount)
    self.parameters = parameters
    self.fingerprint = fingerprint
  }

  public var scalarCount: Int {
    parameters.count
  }

  public var fingerprintHex: String {
    String(format: "%016llx", fingerprint)
  }

  public var headerRecord: NBRegionalProgramHeader {
    var record = NBRegionalProgramHeader()
    record.module_count = UInt32(layouts.count)
    record.token_scalar_count = UInt32(scalarCount)
    record.route_count = UInt32(routes.count)
    record.parameter_count = UInt32(parameters.count)
    record.program_fingerprint = fingerprint
    record.history_capacity = UInt32(Self.routeHistoryCapacity)
    record.history_scalar_count = UInt32(routeHistoryScalarCount)
    return record
  }

  public var routeABIRecords: [NBRegionalRoute] {
    zip(routes.indices, routes).map { routeIndex, route in
      route.abiRecord(
        historyValueOffset: routeHistoryValueOffsets[routeIndex],
        messageDimension: routeMessageDimensions[routeIndex]
      )
    }
  }

  public static func runtimeFoundationV0(
    schedule: BrainModuleSchedule
  ) throws -> RegionalTokenProgram {
    let moduleIDs = Set(schedule.modules.map(\.moduleIdentifier))
    let candidates: [(UInt16, UInt16, UInt16, UInt32, Float, RegionalRouteFlags)] = [
      (37, 25, 0, 2_000, 0.65, [.persistent]),
      (12, 26, 0, 0, 1.00, [.emergency, .persistent]),
      (25, 77, 0, 5_000, 0.55, [.persistent]),
      (95, 83, 0, 1_000, 0.65, [.persistent]),
      (26, 95, 0, 0, 1.00, [.emergency, .persistent]),
      (83, 95, 0, 250, 0.70, [.persistent]),
      (90, 95, 0, 250, 0.80, [.persistent]),
    ]
    let routes: [RegionalTokenRoute] = try candidates.compactMap { candidate in
      let (sender, receiver, token, delay, gain, flags) = candidate
      guard moduleIDs.contains(sender), moduleIDs.contains(receiver) else { return nil }
      return try RegionalTokenRoute(
        senderModuleIdentifier: sender,
        receiverModuleIdentifier: receiver,
        senderToken: token,
        delayMicroseconds: delay,
        gain: gain,
        flags: flags
      )
    }
    return try RegionalTokenProgram(schedule: schedule, routes: routes)
  }

  private static func makeFoundationParameters(
    schedule: BrainModuleSchedule,
    layouts: [RegionalTokenLayout]
  ) -> [RegionalTokenParameters] {
    var result: [RegionalTokenParameters] = []
    result.reserveCapacity(layouts.reduce(0) { $0 + Int($1.scalarCount) })
    for (moduleIndex, layout) in layouts.enumerated() {
      let dimension = Int(layout.tokenDimension)
      for localScalar in 0..<Int(layout.scalarCount) {
        let feature = localScalar % dimension
        let signedFeature = Float(Int(feature % 17) - 8)
        let signedModule = Float(Int(schedule.modules[moduleIndex].moduleIdentifier % 7) - 3)
        result.append(
          RegionalTokenParameters(
            recurrentGain: 0.62 + Float(feature % 5) * 0.015,
            localGain: 0.18 + Float(localScalar / dimension % 3) * 0.02,
            routeGain: 0.52 + Float(feature % 7) * 0.01,
            driveGain: 0.78 + Float(moduleIndex % 3) * 0.04,
            bias: signedFeature * 0.002 + signedModule * 0.003,
            gateBias: 0.18 + Float(feature % 3) * 0.025,
            gateRecurrentGain: 0.14,
            gateInputGain: 0.24 + Float(moduleIndex % 2) * 0.03
          )
        )
      }
    }
    return result
  }
}

@frozen
public struct RegionalRouteHistoryState: Equatable, Hashable, Sendable {
  public static let neverUpdated = UInt64.max

  public var nextSlot: UInt32
  public var count: UInt32
  public var latestTimestamp: BrainTimestamp?

  public init(
    nextSlot: UInt32 = 0,
    count: UInt32 = 0,
    latestTimestamp: BrainTimestamp? = nil
  ) {
    self.nextSlot = nextSlot
    self.count = count
    self.latestTimestamp = latestTimestamp
  }

  public var abiRecord: NBRegionalRouteHistoryState {
    var record = NBRegionalRouteHistoryState()
    record.next_slot = nextSlot
    record.count = count
    record.latest_timestamp_microseconds = latestTimestamp?.rawValue ?? Self.neverUpdated
    return record
  }

  public init(abiRecord: NBRegionalRouteHistoryState) {
    self.init(
      nextSlot: abiRecord.next_slot,
      count: abiRecord.count,
      latestTimestamp: abiRecord.latest_timestamp_microseconds == Self.neverUpdated
        ? nil
        : BrainTimestamp(microseconds: abiRecord.latest_timestamp_microseconds)
    )
  }
}

/// Per-agent, transaction-owned histories for sparse route message tokens.
/// Each route owns a ring of one selected sender token at publication times.
@frozen
public struct RegionalRouteHistory: Equatable, Sendable {
  public let programFingerprint: UInt64
  public let capacity: Int
  public var states: [RegionalRouteHistoryState]
  public var timestamps: [UInt64]
  public var values: [Float]

  public init(program: RegionalTokenProgram) {
    programFingerprint = program.fingerprint
    capacity = RegionalTokenProgram.routeHistoryCapacity
    states = program.routes.map { _ in RegionalRouteHistoryState() }
    timestamps = [UInt64](
      repeating: RegionalRouteHistoryState.neverUpdated,
      count: program.routes.count * RegionalTokenProgram.routeHistoryCapacity
    )
    values = [Float](repeating: 0, count: program.routeHistoryScalarCount)
  }

  public init(
    program: RegionalTokenProgram,
    states: [RegionalRouteHistoryState],
    timestamps: [UInt64],
    values: [Float]
  ) throws {
    programFingerprint = program.fingerprint
    capacity = RegionalTokenProgram.routeHistoryCapacity
    self.states = states
    self.timestamps = timestamps
    self.values = values
    try validate(program: program)
  }

  public func validate(program: RegionalTokenProgram) throws {
    guard programFingerprint == program.fingerprint else {
      throw BrainRuntimeError.invalidSchedule("regional route-history program mismatch")
    }
    guard capacity == RegionalTokenProgram.routeHistoryCapacity,
      states.count == program.routes.count,
      timestamps.count == program.routes.count * capacity,
      values.count == program.routeHistoryScalarCount
    else {
      throw BrainRuntimeError.invalidSchedule("regional route-history shape mismatch")
    }
    for (routeIndex, state) in states.enumerated() {
      guard state.nextSlot < UInt32(capacity), state.count <= UInt32(capacity) else {
        throw BrainRuntimeError.invalidSchedule("regional route-history ring state is invalid")
      }
      guard (state.count == 0) == (state.latestTimestamp == nil) else {
        throw BrainRuntimeError.invalidSchedule("regional route-history timestamp state is invalid")
      }
      guard state.count > 0 else { continue }
      var newerTimestamp: UInt64?
      for age in 0..<Int(state.count) {
        let slot = (Int(state.nextSlot) + capacity - 1 - age) % capacity
        let timestamp = timestamps[routeIndex * capacity + slot]
        guard timestamp != RegionalRouteHistoryState.neverUpdated else {
          throw BrainRuntimeError.invalidSchedule(
            "regional route-history contains an uninitialized active timestamp"
          )
        }
        if let newerTimestamp {
          guard timestamp < newerTimestamp else {
            throw BrainRuntimeError.invalidSchedule(
              "regional route-history timestamps are not strictly ordered"
            )
          }
        } else if timestamp != state.latestTimestamp?.rawValue {
          throw BrainRuntimeError.invalidSchedule(
            "regional route-history latest timestamp does not match its newest slot"
          )
        }
        newerTimestamp = timestamp
      }
    }
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
    mix(programFingerprint, into: &hash)
    mix(UInt64(capacity), into: &hash)
    for state in states {
      mix(UInt64(state.nextSlot), into: &hash)
      mix(UInt64(state.count), into: &hash)
      mix(state.latestTimestamp?.rawValue ?? RegionalRouteHistoryState.neverUpdated, into: &hash)
    }
    for timestamp in timestamps {
      mix(timestamp, into: &hash)
    }
    for value in values {
      mix(UInt64(value.bitPattern), into: &hash)
    }
    return String(format: "%016llx", hash)
  }

  fileprivate func sample(
    routeIndex: Int,
    targetTimestamp: BrainTimestamp,
    feature: Int,
    program: RegionalTokenProgram
  ) -> Float {
    let state = states[routeIndex]
    guard state.count > 0 else { return 0 }
    let messageDimension = Int(program.routeMessageDimensions[routeIndex])
    let valueBase = Int(program.routeHistoryValueOffsets[routeIndex])
    for age in 0..<Int(state.count) {
      let slot = (Int(state.nextSlot) + capacity - 1 - age) % capacity
      let timestamp = timestamps[routeIndex * capacity + slot]
      if timestamp <= targetTimestamp.rawValue {
        return values[valueBase + slot * messageDimension + feature % messageDimension]
      }
    }
    return 0
  }

  fileprivate mutating func append(
    routeIndex: Int,
    timestamp: BrainTimestamp,
    tokenValues: [Float],
    program: RegionalTokenProgram,
    moduleIndices: [UInt16: Int]
  ) throws {
    let route = program.routes[routeIndex]
    guard let senderIndex = moduleIndices[route.senderModuleIdentifier] else {
      throw BrainRuntimeError.invalidSchedule("regional route-history sender disappeared")
    }
    var state = states[routeIndex]
    if let latestTimestamp = state.latestTimestamp {
      guard timestamp > latestTimestamp else {
        throw BrainRuntimeError.transaction(
          "regional route-history publication time did not advance"
        )
      }
    }
    let slot = Int(state.nextSlot)
    let sender = program.layouts[senderIndex]
    let dimension = Int(program.routeMessageDimensions[routeIndex])
    let senderBase =
      Int(sender.scalarOffset)
      + Int(route.senderToken) * Int(sender.tokenDimension)
    let valueBase =
      Int(program.routeHistoryValueOffsets[routeIndex])
      + slot * dimension
    for feature in 0..<dimension {
      values[valueBase + feature] = tokenValues[senderBase + feature]
    }
    timestamps[routeIndex * capacity + slot] = timestamp.rawValue
    state.nextSlot = UInt32((slot + 1) % capacity)
    state.count = min(state.count + 1, UInt32(capacity))
    state.latestTimestamp = timestamp
    states[routeIndex] = state
  }
}

@frozen
public struct RegionalTokenTransition: Equatable, Sendable {
  public let values: [Float]
  public let routeHistory: RegionalRouteHistory

  public init(values: [Float], routeHistory: RegionalRouteHistory) {
    self.values = values
    self.routeHistory = routeHistory
  }
}

@frozen
public struct RegionalRouteHistorySnapshot: Equatable, Sendable {
  public let scheduleFingerprint: UInt64
  public let programFingerprint: UInt64
  public let committedTime: BrainTimestamp
  public let generation: UInt64
  public let history: RegionalRouteHistory

  public init(
    scheduleFingerprint: UInt64,
    programFingerprint: UInt64,
    committedTime: BrainTimestamp,
    generation: UInt64,
    history: RegionalRouteHistory
  ) {
    self.scheduleFingerprint = scheduleFingerprint
    self.programFingerprint = programFingerprint
    self.committedTime = committedTime
    self.generation = generation
    self.history = history
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
    mix(programFingerprint, into: &hash)
    mix(committedTime.rawValue, into: &hash)
    mix(generation, into: &hash)
    for byte in history.stableHash().utf8 {
      hash ^= UInt64(byte)
      hash &*= 0x0000_0100_0000_01b3
    }
    return String(format: "%016llx", hash)
  }
}

@frozen
public struct RegionalTokenSnapshot: Equatable, Sendable {
  public let scheduleFingerprint: UInt64
  public let programFingerprint: UInt64
  public let committedTime: BrainTimestamp
  public let generation: UInt64
  public let values: [Float]

  public init(
    scheduleFingerprint: UInt64,
    programFingerprint: UInt64,
    committedTime: BrainTimestamp,
    generation: UInt64,
    values: [Float]
  ) {
    self.scheduleFingerprint = scheduleFingerprint
    self.programFingerprint = programFingerprint
    self.committedTime = committedTime
    self.generation = generation
    self.values = values
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
    mix(programFingerprint, into: &hash)
    mix(committedTime.rawValue, into: &hash)
    mix(generation, into: &hash)
    mix(UInt64(values.count), into: &hash)
    for value in values {
      mix(UInt64(value.bitPattern), into: &hash)
    }
    return String(format: "%016llx", hash)
  }
}

public enum CPURegionalTokenOperator {
  public static func advance(
    state initialState: [Float],
    diagnostics initialDiagnostics: [RegionalModuleState],
    schedule: BrainModuleSchedule,
    program: RegionalTokenProgram,
    invocations: [BrainModuleInvocation],
    routeHistory initialRouteHistory: RegionalRouteHistory? = nil
  ) throws -> RegionalTokenTransition {
    guard program.scheduleFingerprint == schedule.fingerprint else {
      throw BrainRuntimeError.invalidSchedule("regional program and schedule fingerprints differ")
    }
    guard initialState.count == program.scalarCount else {
      throw BrainRuntimeError.invalidSchedule("regional token-state scalar count mismatch")
    }
    guard initialDiagnostics.count == schedule.modules.count else {
      throw BrainRuntimeError.invalidSchedule("regional diagnostic-state count mismatch")
    }
    var routeHistory = initialRouteHistory ?? RegionalRouteHistory(program: program)
    try routeHistory.validate(program: program)
    let moduleIndices = Dictionary(
      uniqueKeysWithValues: schedule.modules.enumerated().map {
        ($0.element.moduleIdentifier, $0.offset)
      }
    )
    var values = initialState
    var lastUpdates = initialDiagnostics.map(\.lastUpdate)
    var cursor = 0
    while cursor < invocations.count {
      let timestamp = invocations[cursor].timestamp
      if cursor > 0, timestamp < invocations[cursor - 1].timestamp {
        throw BrainRuntimeError.invalidSchedule("regional invocations are not chronological")
      }
      var end = cursor + 1
      while end < invocations.count, invocations[end].timestamp == timestamp {
        end += 1
      }
      let preTimestamp = values
      for invocation in invocations[cursor..<end] {
        guard let moduleIndex = moduleIndices[invocation.moduleIdentifier] else {
          throw BrainRuntimeError.invalidSchedule("regional invocation names an unknown module")
        }
        let module = schedule.modules[moduleIndex]
        let layout = program.layouts[moduleIndex]
        let elapsedMicroseconds: UInt64
        if let lastUpdate = lastUpdates[moduleIndex] {
          guard invocation.timestamp >= lastUpdate else {
            throw BrainRuntimeError.transaction("regional invocation time moved backward")
          }
          elapsedMicroseconds = invocation.timestamp.rawValue - lastUpdate.rawValue
        } else {
          elapsedMicroseconds = UInt64(module.periodMicroseconds)
        }
        let alpha = Float(
          1
            - Foundation.exp(
              -Double(elapsedMicroseconds) / Double(module.intrinsicTimescaleMicroseconds)
            )
        )
        let periodicDrive: Float = invocation.reasons.contains(.periodic) ? 0.25 : 0
        let interruptDrive = min(
          Float(invocation.interruptMask.rawValue.nonzeroBitCount) * 0.125,
          1
        )
        let drive = periodicDrive + interruptDrive
        let dimension = Int(layout.tokenDimension)
        let routeRange =
          Int(
            layout.incomingRouteOffset)..<Int(
            layout.incomingRouteOffset + UInt32(layout.incomingRouteCount)
          )
        for scalarIndex in layout.scalarRange {
          let localScalar = scalarIndex - Int(layout.scalarOffset)
          let tokenStart = Int(layout.scalarOffset) + (localScalar / dimension) * dimension
          let feature = localScalar % dimension
          var localSum: Float = 0
          for localFeature in 0..<dimension {
            localSum += preTimestamp[tokenStart + localFeature]
          }
          let localMean = localSum / Float(dimension)
          var routedInput: Float = 0
          for routeIndex in routeRange {
            let route = program.routes[routeIndex]
            if route.delayMicroseconds == 0 {
              guard let senderIndex = moduleIndices[route.senderModuleIdentifier] else {
                throw BrainRuntimeError.invalidSchedule("regional route sender disappeared")
              }
              let sender = program.layouts[senderIndex]
              let senderFeature = feature % Int(sender.tokenDimension)
              let senderScalar =
                Int(sender.scalarOffset)
                + Int(route.senderToken) * Int(sender.tokenDimension)
                + senderFeature
              routedInput += route.gain * preTimestamp[senderScalar]
            } else if invocation.timestamp.rawValue >= UInt64(route.delayMicroseconds) {
              routedInput +=
                route.gain
                * routeHistory.sample(
                  routeIndex: routeIndex,
                  targetTimestamp: BrainTimestamp(
                    microseconds: invocation.timestamp.rawValue - UInt64(route.delayMicroseconds)
                  ),
                  feature: feature,
                  program: program
                )
            }
          }
          let parameter = program.parameters[scalarIndex]
          let current = preTimestamp[scalarIndex]
          let candidate = Float(
            Foundation.tanh(
              Double(
                parameter.recurrentGain * current
                  + parameter.localGain * localMean
                  + parameter.routeGain * routedInput
                  + parameter.driveGain * drive
                  + parameter.bias
              )
            )
          )
          let gateInput =
            parameter.gateBias
            + parameter.gateRecurrentGain * current
            + parameter.gateInputGain * (routedInput + drive)
          let gate = Float(1 / (1 + Foundation.exp(-Double(gateInput))))
          values[scalarIndex] = current + alpha * gate * (candidate - current)
        }
        lastUpdates[moduleIndex] = invocation.timestamp
      }
      let dueModules = Set(invocations[cursor..<end].map(\.moduleIdentifier))
      for routeIndex in program.routes.indices
      where dueModules.contains(program.routes[routeIndex].senderModuleIdentifier) {
        try routeHistory.append(
          routeIndex: routeIndex,
          timestamp: timestamp,
          tokenValues: values,
          program: program,
          moduleIndices: moduleIndices
        )
      }
      cursor = end
    }
    return RegionalTokenTransition(values: values, routeHistory: routeHistory)
  }
}

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
  public let denseWeightOffset: UInt32
  public let denseWeightCount: UInt32
  public let incomingRouteCount: UInt16
  public let flags: UInt32
  public let normalRouteBudget: UInt16

  public var scalarRange: Range<Int> {
    Int(scalarOffset)..<Int(scalarOffset + scalarCount)
  }

  public var abiRecord: NBRegionalTokenLayout {
    var record = NBRegionalTokenLayout()
    record.scalar_offset = scalarOffset
    record.scalar_count = scalarCount
    record.parameter_offset = parameterOffset
    record.incoming_route_offset = incomingRouteOffset
    record.dense_weight_offset = denseWeightOffset
    record.dense_weight_count = denseWeightCount
    record.module_id = moduleIdentifier
    record.token_count = tokenCount
    record.token_dimension = tokenDimension
    record.incoming_route_count = incomingRouteCount
    record.flags = flags
    record.normal_route_budget = normalRouteBudget
    record.reserved = 0
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
  public static let programVersion = UInt32(NB_REGIONAL_PROGRAM_VERSION)
  public static let routeHistoryCapacity = Int(NB_REGIONAL_ROUTE_HISTORY_CAPACITY)
  public static let minimumRoutePersistenceMicroseconds = UInt32(
    NB_REGIONAL_MIN_ROUTE_PERSISTENCE_MICROSECONDS
  )
  public static let routeSalienceGain: Float = 0.125
  public static let routePersistenceBonus: Float = 0.05

  public let scheduleFingerprint: UInt64
  public let layouts: [RegionalTokenLayout]
  public let routes: [RegionalTokenRoute]
  /// CSR offsets into ``outgoingRouteIndices`` for each schedule module.
  public let outgoingRouteOffsets: [UInt32]
  /// Receiver-canonical route indices regrouped by sending module.
  public let outgoingRouteIndices: [UInt32]
  public let routeHistoryValueOffsets: [UInt32]
  public let routeMessageDimensions: [UInt32]
  public let compiledRouteHistoryCapacity: Int
  public let routeHistoryScalarCount: Int
  public let denseParameterCount: Int
  public let parameters: [RegionalTokenParameters]
  public let shapeFingerprint: UInt64
  public let fingerprint: UInt64

  public init(
    schedule: BrainModuleSchedule,
    routes requestedRoutes: [RegionalTokenRoute],
    parameters requestedParameters: [RegionalTokenParameters]? = nil,
    normalRouteBudgets requestedNormalRouteBudgets: [UInt16: UInt16] = [:],
    historyCapacity requestedHistoryCapacity: Int = Self.routeHistoryCapacity
  ) throws {
    guard requestedHistoryCapacity > 0,
      requestedHistoryCapacity <= Self.routeHistoryCapacity
    else {
      throw BrainRuntimeError.invalidSchedule(
        "regional route-history capacity must be in 1...\(Self.routeHistoryCapacity)"
      )
    }
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
      Set(canonicalRoutes.map(\.receiverModuleIdentifier)).isSubset(of: moduleIdentifiers),
      Set(requestedNormalRouteBudgets.keys).isSubset(of: moduleIdentifiers)
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
    var denseWeightOffset: UInt32 = 0
    var layouts: [RegionalTokenLayout] = []
    layouts.reserveCapacity(schedule.modules.count)
    for module in schedule.modules {
      let scalarProduct = UInt64(module.tokenCount) * UInt64(module.tokenDimension)
      let denseProduct = UInt64(module.tokenDimension) * UInt64(module.tokenDimension)
      guard scalarProduct <= UInt64(UInt32.max),
        denseProduct <= UInt64(UInt32.max),
        UInt64(scalarOffset) + scalarProduct <= UInt64(UInt32.max),
        UInt64(denseWeightOffset) + denseProduct <= UInt64(UInt32.max)
      else {
        throw BrainRuntimeError.invalidSchedule("regional token scalar count exceeds ABI limits")
      }
      let incomingRoutes = canonicalRoutes.filter {
        $0.receiverModuleIdentifier == module.moduleIdentifier
      }
      let incomingCount = incomingRoutes.count
      let normalRouteCount = incomingRoutes.lazy.filter {
        !$0.flags.contains(.emergency)
      }.count
      let normalRouteBudget = Int(
        requestedNormalRouteBudgets[module.moduleIdentifier]
          ?? UInt16(min(normalRouteCount, 1))
      )
      guard incomingCount <= Int(UInt16.max),
        UInt64(incomingRouteOffset) + UInt64(incomingCount) <= UInt64(UInt32.max),
        normalRouteBudget <= normalRouteCount
      else {
        throw BrainRuntimeError.invalidSchedule(
          "regional route count or normal-route budget exceeds compiled limits"
        )
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
          denseWeightOffset: denseWeightOffset,
          denseWeightCount: UInt32(denseProduct),
          incomingRouteCount: UInt16(incomingCount),
          flags: module.flags,
          normalRouteBudget: UInt16(normalRouteBudget)
        )
      )
      scalarOffset += UInt32(scalarProduct)
      incomingRouteOffset += UInt32(incomingCount)
      denseWeightOffset += UInt32(denseProduct)
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
    var outgoingRouteOffsets: [UInt32] = []
    var outgoingRouteIndices: [UInt32] = []
    outgoingRouteOffsets.reserveCapacity(schedule.modules.count + 1)
    outgoingRouteIndices.reserveCapacity(canonicalRoutes.count)
    for module in schedule.modules {
      outgoingRouteOffsets.append(UInt32(outgoingRouteIndices.count))
      for routeIndex in canonicalRoutes.indices
      where canonicalRoutes[routeIndex].senderModuleIdentifier == module.moduleIdentifier {
        guard routeIndex <= Int(UInt32.max) else {
          throw BrainRuntimeError.invalidSchedule(
            "regional outgoing-route index exceeds ABI limits"
          )
        }
        outgoingRouteIndices.append(UInt32(routeIndex))
      }
    }
    outgoingRouteOffsets.append(UInt32(outgoingRouteIndices.count))
    guard outgoingRouteIndices.count == canonicalRoutes.count else {
      throw BrainRuntimeError.invalidSchedule(
        "regional outgoing-route index does not cover the complete route graph"
      )
    }
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
        * UInt64(requestedHistoryCapacity)
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
              UInt32(parameters.count),
              UInt32(requestedHistoryCapacity)
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
            UInt32(parameters.count),
            UInt32(requestedHistoryCapacity)
          )
        }
      }
    }
    let shapeFingerprint = layoutRecords.withUnsafeBufferPointer { layouts in
      routeRecords.withUnsafeBufferPointer { routes in
        nb_brain_abi_regional_program_shape_fingerprint(
          layouts.baseAddress,
          UInt32(layouts.count),
          routes.baseAddress,
          UInt32(routes.count),
          UInt32(parameterRecords.count),
          UInt32(requestedHistoryCapacity)
        )
      }
    }
    self.scheduleFingerprint = schedule.fingerprint
    self.layouts = layouts
    self.routes = canonicalRoutes
    self.outgoingRouteOffsets = outgoingRouteOffsets
    self.outgoingRouteIndices = outgoingRouteIndices
    self.routeHistoryValueOffsets = routeHistoryValueOffsets
    self.routeMessageDimensions = routeMessageDimensions
    self.compiledRouteHistoryCapacity = requestedHistoryCapacity
    self.routeHistoryScalarCount = Int(routeHistoryScalarCount)
    self.denseParameterCount = Int(denseWeightOffset)
    self.parameters = parameters
    self.shapeFingerprint = shapeFingerprint
    self.fingerprint = fingerprint
  }

  public var scalarCount: Int {
    parameters.count
  }

  public var fingerprintHex: String {
    String(format: "%016llx", fingerprint)
  }

  public var shapeFingerprintHex: String {
    String(format: "%016llx", shapeFingerprint)
  }

  public var headerRecord: NBRegionalProgramHeader {
    var record = NBRegionalProgramHeader()
    record.module_count = UInt32(layouts.count)
    record.token_scalar_count = UInt32(scalarCount)
    record.route_count = UInt32(routes.count)
    record.parameter_count = UInt32(parameters.count)
    record.program_fingerprint = fingerprint
    record.history_capacity = UInt32(compiledRouteHistoryCapacity)
    record.history_scalar_count = UInt32(routeHistoryScalarCount)
    record.program_version = Self.programVersion
    record.minimum_route_persistence_microseconds = Self.minimumRoutePersistenceMicroseconds
    record.salience_gain = Self.routeSalienceGain
    record.persistence_bonus = Self.routePersistenceBonus
    record.dense_parameter_count = UInt32(denseParameterCount)
    record.reserved = 0
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
    schedule: BrainModuleSchedule,
    historyCapacity: Int = Self.routeHistoryCapacity
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
    return try RegionalTokenProgram(
      schedule: schedule,
      routes: routes,
      historyCapacity: historyCapacity
    )
  }

  /// Uses the authoritative token shapes and factorized recurrent parameters
  /// without long-range routes. This remains the explicit route-ablation and
  /// isolated-recurrence profile; production cohort execution uses routed state.
  public static func runtimeFoundationUnroutedV0(
    schedule: BrainModuleSchedule
  ) throws -> RegionalTokenProgram {
    try RegionalTokenProgram(schedule: schedule, routes: [])
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
    capacity = program.compiledRouteHistoryCapacity
    states = program.routes.map { _ in RegionalRouteHistoryState() }
    timestamps = [UInt64](
      repeating: RegionalRouteHistoryState.neverUpdated,
      count: program.routes.count * program.compiledRouteHistoryCapacity
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
    capacity = program.compiledRouteHistoryCapacity
    self.states = states
    self.timestamps = timestamps
    self.values = values
    try validate(program: program)
  }

  public func validate(program: RegionalTokenProgram) throws {
    guard programFingerprint == program.fingerprint else {
      throw BrainRuntimeError.invalidSchedule("regional route-history program mismatch")
    }
    guard capacity == program.compiledRouteHistoryCapacity,
      states.count == program.routes.count,
      timestamps.count == program.routes.count * capacity,
      values.count == program.routeHistoryScalarCount,
      values.allSatisfy(\.isFinite)
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
public struct RegionalRouteRuntimeState: Equatable, Hashable, Sendable {
  public static let neverSelected = UInt64.max

  public var score: Float
  public var strength: Float
  public var isActive: Bool
  public var selectionCount: UInt32
  public var lastSelectedTimestamp: BrainTimestamp?
  public var switchCount: UInt32

  public init(
    score: Float = 0,
    strength: Float = 0,
    isActive: Bool = false,
    selectionCount: UInt32 = 0,
    lastSelectedTimestamp: BrainTimestamp? = nil,
    switchCount: UInt32 = 0
  ) {
    self.score = score
    self.strength = strength
    self.isActive = isActive
    self.selectionCount = selectionCount
    self.lastSelectedTimestamp = lastSelectedTimestamp
    self.switchCount = switchCount
  }

  public var abiRecord: NBRegionalRouteRuntimeState {
    var record = NBRegionalRouteRuntimeState()
    record.score = score
    record.strength = strength
    record.active = isActive ? 1 : 0
    record.selection_count = selectionCount
    record.last_selected_timestamp_microseconds =
      lastSelectedTimestamp?.rawValue ?? Self.neverSelected
    record.switch_count = switchCount
    record.reserved = 0
    return record
  }

  public init(abiRecord: NBRegionalRouteRuntimeState) {
    self.init(
      score: abiRecord.score,
      strength: abiRecord.strength,
      isActive: abiRecord.active != 0,
      selectionCount: abiRecord.selection_count,
      lastSelectedTimestamp: abiRecord.last_selected_timestamp_microseconds == Self.neverSelected
        ? nil
        : BrainTimestamp(
          microseconds: abiRecord.last_selected_timestamp_microseconds
        ),
      switchCount: abiRecord.switch_count
    )
  }
}

/// Per-agent route scores, selections, normalized strengths, and persistence.
/// Shared route topology and scoring constants remain immutable in the program.
@frozen
public struct RegionalRoutingState: Equatable, Sendable {
  public let programFingerprint: UInt64
  public var states: [RegionalRouteRuntimeState]

  public init(program: RegionalTokenProgram) {
    programFingerprint = program.fingerprint
    states = program.routes.map { _ in RegionalRouteRuntimeState() }
  }

  public init(
    program: RegionalTokenProgram,
    states: [RegionalRouteRuntimeState]
  ) throws {
    programFingerprint = program.fingerprint
    self.states = states
    try validate(program: program)
  }

  public func validate(program: RegionalTokenProgram) throws {
    guard programFingerprint == program.fingerprint,
      states.count == program.routes.count
    else {
      throw BrainRuntimeError.invalidSchedule("regional routing-state program mismatch")
    }
    for state in states {
      guard state.score.isFinite, state.strength.isFinite,
        state.strength >= 0, state.strength <= 1,
        !state.isActive || state.lastSelectedTimestamp != nil,
        (state.selectionCount == 0) == (state.lastSelectedTimestamp == nil)
      else {
        throw BrainRuntimeError.invalidSchedule("regional routing state is invalid")
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
    mix(UInt64(states.count), into: &hash)
    for state in states {
      mix(UInt64(state.score.bitPattern), into: &hash)
      mix(UInt64(state.strength.bitPattern), into: &hash)
      mix(state.isActive ? 1 : 0, into: &hash)
      mix(UInt64(state.selectionCount), into: &hash)
      mix(
        state.lastSelectedTimestamp?.rawValue ?? RegionalRouteRuntimeState.neverSelected,
        into: &hash
      )
      mix(UInt64(state.switchCount), into: &hash)
    }
    return String(format: "%016llx", hash)
  }
}

@frozen
public struct RegionalTokenTransition: Equatable, Sendable {
  public let values: [Float]
  public let routeHistory: RegionalRouteHistory
  public let routingState: RegionalRoutingState

  public init(
    values: [Float],
    routeHistory: RegionalRouteHistory,
    routingState: RegionalRoutingState
  ) {
    self.values = values
    self.routeHistory = routeHistory
    self.routingState = routingState
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
public struct RegionalRoutingSnapshot: Equatable, Sendable {
  public let scheduleFingerprint: UInt64
  public let programFingerprint: UInt64
  public let committedTime: BrainTimestamp
  public let generation: UInt64
  public let routingState: RegionalRoutingState

  public init(
    scheduleFingerprint: UInt64,
    programFingerprint: UInt64,
    committedTime: BrainTimestamp,
    generation: UInt64,
    routingState: RegionalRoutingState
  ) {
    self.scheduleFingerprint = scheduleFingerprint
    self.programFingerprint = programFingerprint
    self.committedTime = committedTime
    self.generation = generation
    self.routingState = routingState
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
    for byte in routingState.stableHash().utf8 {
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
    routeHistory initialRouteHistory: RegionalRouteHistory? = nil,
    routingState initialRoutingState: RegionalRoutingState? = nil
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
    var routingState = initialRoutingState ?? RegionalRoutingState(program: program)
    try routingState.validate(program: program)
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
      let dueModules = Set(invocations[cursor..<end].map(\.moduleIdentifier))
      for moduleIndex in program.layouts.indices
      where dueModules.contains(program.layouts[moduleIndex].moduleIdentifier) {
        try selectRoutes(
          receiverModuleIndex: moduleIndex,
          timestamp: timestamp,
          preTimestamp: preTimestamp,
          routeHistory: routeHistory,
          routingState: &routingState,
          program: program,
          moduleIndices: moduleIndices
        )
      }
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
            let routeState = routingState.states[routeIndex]
            guard routeState.isActive else { continue }
            let route = program.routes[routeIndex]
            routedInput +=
              route.gain * routeState.strength
              * (try routeMessageValue(
                routeIndex: routeIndex,
                timestamp: invocation.timestamp,
                feature: feature,
                preTimestamp: preTimestamp,
                routeHistory: routeHistory,
                program: program,
                moduleIndices: moduleIndices
              ))
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
    return RegionalTokenTransition(
      values: values,
      routeHistory: routeHistory,
      routingState: routingState
    )
  }

  private static func routeMessageValue(
    routeIndex: Int,
    timestamp: BrainTimestamp,
    feature: Int,
    preTimestamp: [Float],
    routeHistory: RegionalRouteHistory,
    program: RegionalTokenProgram,
    moduleIndices: [UInt16: Int]
  ) throws -> Float {
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
      return preTimestamp[senderScalar]
    }
    guard timestamp.rawValue >= UInt64(route.delayMicroseconds) else { return 0 }
    return routeHistory.sample(
      routeIndex: routeIndex,
      targetTimestamp: BrainTimestamp(
        microseconds: timestamp.rawValue - UInt64(route.delayMicroseconds)
      ),
      feature: feature,
      program: program
    )
  }

  private static func selectRoutes(
    receiverModuleIndex: Int,
    timestamp: BrainTimestamp,
    preTimestamp: [Float],
    routeHistory: RegionalRouteHistory,
    routingState: inout RegionalRoutingState,
    program: RegionalTokenProgram,
    moduleIndices: [UInt16: Int]
  ) throws {
    let receiver = program.layouts[receiverModuleIndex]
    let routeRange =
      Int(
        receiver.incomingRouteOffset)..<Int(
        receiver.incomingRouteOffset + UInt32(receiver.incomingRouteCount)
      )
    guard !routeRange.isEmpty else { return }
    let queryDimension = Int(receiver.tokenDimension)
    let queryBase = Int(receiver.scalarOffset)
    for routeIndex in routeRange {
      var dot: Float = 0
      var salience: Float = 0
      for feature in 0..<queryDimension {
        let message = try routeMessageValue(
          routeIndex: routeIndex,
          timestamp: timestamp,
          feature: feature,
          preTimestamp: preTimestamp,
          routeHistory: routeHistory,
          program: program,
          moduleIndices: moduleIndices
        )
        dot += preTimestamp[queryBase + feature] * message
        salience += abs(message)
      }
      var score =
        dot / Float(Foundation.sqrt(Double(queryDimension)))
        + program.headerRecord.salience_gain * salience / Float(queryDimension)
      let previous = routingState.states[routeIndex]
      if previous.isActive {
        score += program.headerRecord.persistence_bonus
      }
      routingState.states[routeIndex].score = score
    }

    var selected: [Int] = []
    selected.reserveCapacity(routeRange.count)
    for routeIndex in routeRange where program.routes[routeIndex].flags.contains(.emergency) {
      selected.append(routeIndex)
    }
    let normalBudget = Int(receiver.normalRouteBudget)
    if normalBudget > 0 {
      for routeIndex in routeRange
      where !program.routes[routeIndex].flags.contains(.emergency)
        && routingState.states[routeIndex].isActive
        && selected.count < routeRange.count
      {
        guard let lastSelected = routingState.states[routeIndex].lastSelectedTimestamp,
          timestamp >= lastSelected
        else { continue }
        if timestamp.rawValue - lastSelected.rawValue
          < UInt64(program.headerRecord.minimum_route_persistence_microseconds)
        {
          selected.append(routeIndex)
          if selected.lazy.filter({
            !program.routes[$0].flags.contains(.emergency)
          }).count == normalBudget {
            break
          }
        }
      }
      while selected.lazy.filter({
        !program.routes[$0].flags.contains(.emergency)
      }).count < normalBudget {
        var bestRoute: Int?
        var bestScore = -Float.infinity
        for routeIndex in routeRange
        where !program.routes[routeIndex].flags.contains(.emergency)
          && !selected.contains(routeIndex)
        {
          let score = routingState.states[routeIndex].score
          if score > bestScore {
            bestScore = score
            bestRoute = routeIndex
          }
        }
        guard let bestRoute else { break }
        selected.append(bestRoute)
      }
    }

    let maximumScore = selected.map { routingState.states[$0].score }.max() ?? 0
    var strengthDenominator: Float = 0
    var unnormalized: [Int: Float] = [:]
    unnormalized.reserveCapacity(selected.count)
    for routeIndex in selected {
      let value = Float(
        Foundation.exp(Double(routingState.states[routeIndex].score - maximumScore))
      )
      unnormalized[routeIndex] = value
      strengthDenominator += value
    }
    let selectedSet = Set(selected)
    for routeIndex in routeRange {
      var state = routingState.states[routeIndex]
      let wasActive = state.isActive
      state.isActive = selectedSet.contains(routeIndex)
      state.strength =
        state.isActive && strengthDenominator > 0
        ? (unnormalized[routeIndex] ?? 0) / strengthDenominator
        : 0
      if state.isActive {
        state.selectionCount =
          state.selectionCount == UInt32.max
          ? UInt32.max
          : state.selectionCount + 1
        state.lastSelectedTimestamp = timestamp
      }
      if state.isActive != wasActive {
        state.switchCount =
          state.switchCount == UInt32.max
          ? UInt32.max
          : state.switchCount + 1
      }
      routingState.states[routeIndex] = state
    }
  }
}

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

/// A compiled sparse message edge. Version 0 executes synchronous, pre-timestamp
/// routes; delayed route history is intentionally rejected by the ABI validator.
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
    guard delayMicroseconds == 0 else {
      throw BrainRuntimeError.invalidDescriptor(
        "regional route-delay history is not executable in program version 0"
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

  public var abiRecord: NBRegionalRoute {
    var record = NBRegionalRoute()
    record.sender_module_id = senderModuleIdentifier
    record.receiver_module_id = receiverModuleIdentifier
    record.sender_token = senderToken
    record.flags = flags.rawValue
    record.delay_microseconds = delayMicroseconds
    record.gain = gain
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
  public static let programVersion: UInt32 = 0

  public let scheduleFingerprint: UInt64
  public let layouts: [RegionalTokenLayout]
  public let routes: [RegionalTokenRoute]
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
    guard Set(canonicalRoutes).count == canonicalRoutes.count else {
      throw BrainRuntimeError.invalidSchedule("duplicate regional routes are not canonical")
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
    let descriptorRecords = schedule.modules.map(\.abiRecord)
    let layoutRecords = layouts.map(\.abiRecord)
    let routeRecords = canonicalRoutes.map(\.abiRecord)
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
    record.flags = Self.programVersion
    return record
  }

  public static func runtimeFoundationV0(
    schedule: BrainModuleSchedule
  ) throws -> RegionalTokenProgram {
    let moduleIDs = Set(schedule.modules.map(\.moduleIdentifier))
    let candidates: [(UInt16, UInt16, UInt16, Float, RegionalRouteFlags)] = [
      (37, 25, 0, 0.65, [.persistent]),
      (12, 26, 0, 1.00, [.emergency, .persistent]),
      (25, 77, 0, 0.55, [.persistent]),
      (95, 83, 0, 0.65, [.persistent]),
      (26, 95, 0, 1.00, [.emergency, .persistent]),
      (83, 95, 0, 0.70, [.persistent]),
      (90, 95, 0, 0.80, [.persistent]),
    ]
    let routes: [RegionalTokenRoute] = try candidates.compactMap { candidate in
      let (sender, receiver, token, gain, flags) = candidate
      guard moduleIDs.contains(sender), moduleIDs.contains(receiver) else { return nil }
      return try RegionalTokenRoute(
        senderModuleIdentifier: sender,
        receiverModuleIdentifier: receiver,
        senderToken: token,
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
    invocations: [BrainModuleInvocation]
  ) throws -> [Float] {
    guard program.scheduleFingerprint == schedule.fingerprint else {
      throw BrainRuntimeError.invalidSchedule("regional program and schedule fingerprints differ")
    }
    guard initialState.count == program.scalarCount else {
      throw BrainRuntimeError.invalidSchedule("regional token-state scalar count mismatch")
    }
    guard initialDiagnostics.count == schedule.modules.count else {
      throw BrainRuntimeError.invalidSchedule("regional diagnostic-state count mismatch")
    }
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
      cursor = end
    }
    return values
  }
}

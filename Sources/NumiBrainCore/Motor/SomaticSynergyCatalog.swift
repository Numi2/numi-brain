import Foundation

/// One immutable sparse projection from a species somatic synergy into a
/// physical actuator. Positive and negative gains are permitted so a species
/// compiler can represent agonist, antagonist, and stabilizing recruitment.
@frozen
public struct SomaticSynergyRoute: Codable, Equatable, Hashable, Sendable {
  public let synergyIdentifier: UInt16
  public let actuatorIdentifier: UInt32
  public let gain: Float

  public init(
    synergyIdentifier: UInt16,
    actuatorIdentifier: UInt32,
    gain: Float
  ) throws {
    guard gain.isFinite, gain != 0, abs(gain) <= 1 else {
      throw BrainRuntimeError.invalidDescriptor(
        "somatic synergy gain must be finite, nonzero, and normalized"
      )
    }
    self.synergyIdentifier = synergyIdentifier
    self.actuatorIdentifier = actuatorIdentifier
    self.gain = gain
  }
}

/// Content-addressed species/body decoder shared by the cortical motor path
/// and the fast spinal/CPG path. The dense GPU representation is actuator-major
/// and never inferred from array indices inside a kernel.
@frozen
public struct SomaticSynergyCatalog: Codable, Equatable, Hashable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let actuatorCount: UInt32
  public let synergyCount: UInt16
  public let routes: [SomaticSynergyRoute]
  public let fingerprint: UInt64

  public init(
    actuatorCount: UInt32,
    synergyCount: UInt16,
    routes: [SomaticSynergyRoute]
  ) throws {
    guard actuatorCount > 0, synergyCount > 0, !routes.isEmpty else {
      throw BrainRuntimeError.invalidDescriptor(
        "somatic synergy catalog must contain actuators, synergies, and routes"
      )
    }
    let sortedRoutes = routes.sorted {
      if $0.actuatorIdentifier != $1.actuatorIdentifier {
        return $0.actuatorIdentifier < $1.actuatorIdentifier
      }
      return $0.synergyIdentifier < $1.synergyIdentifier
    }
    var pairs = Set<UInt64>()
    var coveredActuators = Set<UInt32>()
    var coveredSynergies = Set<UInt16>()
    for route in sortedRoutes {
      guard route.actuatorIdentifier < actuatorCount,
        route.synergyIdentifier < synergyCount
      else {
        throw BrainRuntimeError.invalidDescriptor(
          "somatic synergy route is outside the declared topology"
        )
      }
      let pair = UInt64(route.actuatorIdentifier) << 16
        | UInt64(route.synergyIdentifier)
      guard pairs.insert(pair).inserted else {
        throw BrainRuntimeError.invalidDescriptor(
          "somatic synergy routes must be unique per actuator and synergy"
        )
      }
      coveredActuators.insert(route.actuatorIdentifier)
      coveredSynergies.insert(route.synergyIdentifier)
    }
    guard coveredActuators.count == Int(actuatorCount),
      coveredSynergies.count == Int(synergyCount)
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "somatic synergy catalog must cover every actuator and synergy"
      )
    }
    self.actuatorCount = actuatorCount
    self.synergyCount = synergyCount
    self.routes = sortedRoutes
    self.fingerprint = Self.computeFingerprint(
      actuatorCount: actuatorCount,
      synergyCount: synergyCount,
      routes: sortedRoutes
    )
  }

  public func validate(motor: MotorTopology) throws {
    guard actuatorCount == motor.actuatorCount,
      synergyCount == motor.synergyCount,
      routes.allSatisfy({ route in
        motor.actuatorChannels[Int(route.actuatorIdentifier)].identifier
          == route.actuatorIdentifier
      })
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "somatic synergy catalog does not match the species motor topology"
      )
    }
  }

  public func denseDecoder() throws -> [Float] {
    let (count, overflow) = Int(actuatorCount).multipliedReportingOverflow(
      by: Int(synergyCount)
    )
    guard !overflow, count > 0 else {
      throw BrainRuntimeError.capacity("somatic synergy decoder is too large")
    }
    var result = [Float](repeating: 0, count: count)
    for route in routes {
      result[Int(route.actuatorIdentifier) * Int(synergyCount)
        + Int(route.synergyIdentifier)] = route.gain
    }
    return result
  }

  /// Explicit one-hot fixture for isolated runtime construction. Complete
  /// embodied production creation requires a supplied species-owned catalog.
  public static func runtimeFoundationFixture(
    actuatorCount: UInt32,
    synergyCount: UInt16
  ) throws -> Self {
    var routes: [SomaticSynergyRoute] = []
    var pairs = Set<UInt64>()
    for actuator in 0..<actuatorCount {
      let synergy = UInt16(actuator % UInt32(synergyCount))
      routes.append(try SomaticSynergyRoute(
        synergyIdentifier: synergy,
        actuatorIdentifier: actuator,
        gain: 1
      ))
      pairs.insert(UInt64(actuator) << 16 | UInt64(synergy))
    }
    for synergy in 0..<synergyCount {
      let actuator = UInt32(synergy) % actuatorCount
      let pair = UInt64(actuator) << 16 | UInt64(synergy)
      if pairs.contains(pair) { continue }
      routes.append(try SomaticSynergyRoute(
        synergyIdentifier: synergy,
        actuatorIdentifier: actuator,
        gain: 1
      ))
    }
    return try Self(
      actuatorCount: actuatorCount,
      synergyCount: synergyCount,
      routes: routes
    )
  }

  private enum CodingKeys: String, CodingKey {
    case actuatorCount
    case synergyCount
    case routes
    case fingerprint
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let decoded = try Self(
      actuatorCount: values.decode(UInt32.self, forKey: .actuatorCount),
      synergyCount: values.decode(UInt16.self, forKey: .synergyCount),
      routes: values.decode([SomaticSynergyRoute].self, forKey: .routes)
    )
    guard decoded.fingerprint
      == (try values.decode(UInt64.self, forKey: .fingerprint))
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "somatic synergy catalog fingerprint drift"
      )
    }
    self = decoded
  }

  private static func computeFingerprint(
    actuatorCount: UInt32,
    synergyCount: UInt16,
    routes: [SomaticSynergyRoute]
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    mix(formatVersion, into: &hash)
    mix(actuatorCount, into: &hash)
    mix(UInt32(synergyCount), into: &hash)
    mix(UInt32(routes.count), into: &hash)
    for route in routes {
      mix(UInt32(route.synergyIdentifier), into: &hash)
      mix(route.actuatorIdentifier, into: &hash)
      mix(route.gain.bitPattern, into: &hash)
    }
    return hash
  }

  private static func mix(_ value: UInt32, into hash: inout UInt64) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }
}

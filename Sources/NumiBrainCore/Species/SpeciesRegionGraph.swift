import Foundation

/// One runtime region in a species-specialized graph. Reference-role
/// provenance is explicit: repeated reference roles represent a split, several
/// reference roles on one module represent a merge, and an empty reference set
/// with a nonzero species role represents a species-specific addition.
@frozen
public struct SpeciesRegionModule: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt16
  public let name: String
  public let domain: BrainFunctionalDomain
  public let referenceRoleIdentifiers: [UInt16]
  public let speciesRoleCode: UInt64
  public let schedule: BrainModuleDescriptor

  public init(
    identifier: UInt16,
    name: String,
    domain: BrainFunctionalDomain,
    referenceRoleIdentifiers: [UInt16],
    speciesRoleCode: UInt64 = 0,
    schedule: BrainModuleDescriptor
  ) throws {
    let referenceRoles = referenceRoleIdentifiers.sorted()
    guard identifier > 0, identifier <= 128,
      identifier == schedule.moduleIdentifier,
      !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      Set(referenceRoles).count == referenceRoles.count,
      referenceRoles.allSatisfy({ (1...96).contains($0) }),
      !referenceRoles.isEmpty || speciesRoleCode > 0
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "species region module identity or role provenance is invalid"
      )
    }
    self.identifier = identifier
    self.name = name
    self.domain = domain
    self.referenceRoleIdentifiers = referenceRoles
    self.speciesRoleCode = speciesRoleCode
    self.schedule = schedule
  }
}

/// Immutable species-level regional graph compiled to the same scheduler and
/// sparse-routing ABI as the mammalian reference graph.
@frozen
public struct SpeciesRegionGraph: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let referenceGraphFingerprint: UInt64
  public let modules: [SpeciesRegionModule]
  public let schedule: BrainModuleSchedule
  public let routes: [RegionalTokenRoute]
  public let fingerprint: UInt64

  public init(
    referenceGraphFingerprint: UInt64,
    modules: [SpeciesRegionModule],
    routes: [RegionalTokenRoute]
  ) throws {
    let canonicalModules = modules.sorted { $0.identifier < $1.identifier }
    guard referenceGraphFingerprint > 0, !canonicalModules.isEmpty,
      canonicalModules.count <= 128,
      Set(canonicalModules.map(\.identifier)).count == canonicalModules.count,
      Set(canonicalModules.map(\.name)).count == canonicalModules.count
    else {
      throw BrainRuntimeError.invalidDescriptor(
        "species region graph modules are invalid"
      )
    }
    let identifiers = Set(canonicalModules.map(\.identifier))
    let canonicalRoutes = routes.sorted {
      if $0.receiverModuleIdentifier != $1.receiverModuleIdentifier {
        return $0.receiverModuleIdentifier < $1.receiverModuleIdentifier
      }
      if $0.senderModuleIdentifier != $1.senderModuleIdentifier {
        return $0.senderModuleIdentifier < $1.senderModuleIdentifier
      }
      return $0.senderToken < $1.senderToken
    }
    guard canonicalRoutes.allSatisfy({
      identifiers.contains($0.senderModuleIdentifier)
        && identifiers.contains($0.receiverModuleIdentifier)
    }) else {
      throw BrainRuntimeError.invalidDescriptor(
        "species regional route names an unknown module"
      )
    }
    for (previous, current) in zip(canonicalRoutes, canonicalRoutes.dropFirst()) {
      guard previous.senderModuleIdentifier != current.senderModuleIdentifier
        || previous.receiverModuleIdentifier != current.receiverModuleIdentifier
        || previous.senderToken != current.senderToken
      else {
        throw BrainRuntimeError.invalidDescriptor(
          "species regional route identity is duplicated"
        )
      }
    }
    let schedule = try BrainModuleSchedule(
      modules: canonicalModules.map(\.schedule)
    )
    var hash: UInt64 = 14_695_981_039_346_656_037
    Self.mix(UInt64(Self.formatVersion), into: &hash)
    Self.mix(referenceGraphFingerprint, into: &hash)
    Self.mix(schedule.fingerprint, into: &hash)
    for module in canonicalModules {
      Self.mix(UInt64(module.identifier), into: &hash)
      Self.mix(UInt64(module.domain.rawValue), into: &hash)
      Self.mix(module.speciesRoleCode, into: &hash)
      Self.mix(UInt64(module.referenceRoleIdentifiers.count), into: &hash)
      for role in module.referenceRoleIdentifiers {
        Self.mix(UInt64(role), into: &hash)
      }
      for byte in module.name.utf8 {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
      hash ^= 0
      hash &*= 1_099_511_628_211
    }
    for route in canonicalRoutes {
      Self.mix(UInt64(route.senderModuleIdentifier), into: &hash)
      Self.mix(UInt64(route.receiverModuleIdentifier), into: &hash)
      Self.mix(UInt64(route.senderToken), into: &hash)
      Self.mix(UInt64(route.delayMicroseconds), into: &hash)
      Self.mix(UInt64(route.gain.bitPattern), into: &hash)
      Self.mix(UInt64(route.flags.rawValue), into: &hash)
    }
    self.referenceGraphFingerprint = referenceGraphFingerprint
    self.modules = canonicalModules
    self.schedule = schedule
    self.routes = canonicalRoutes
    self.fingerprint = hash
  }

  public static func referenceSubset(
    referenceGraph: ReferenceBrainGraph,
    enabledModuleIdentifiers: [UInt16]
  ) throws -> Self {
    let enabled = Set(enabledModuleIdentifiers)
    let modules = try referenceGraph.modules.compactMap {
      module -> SpeciesRegionModule? in
      guard enabled.contains(module.identifier) else { return nil }
      return try SpeciesRegionModule(
        identifier: module.identifier,
        name: module.name,
        domain: module.domain,
        referenceRoleIdentifiers: [module.identifier],
        schedule: module.schedule
      )
    }
    let routes = referenceGraph.routes.filter {
      enabled.contains($0.senderModuleIdentifier)
        && enabled.contains($0.receiverModuleIdentifier)
    }
    return try Self(
      referenceGraphFingerprint: referenceGraph.fingerprint,
      modules: modules,
      routes: routes
    )
  }

  public func regionalProgram(
    historyCapacity: Int = RegionalTokenProgram.routeHistoryCapacity
  ) throws -> RegionalTokenProgram {
    var normalBudgets: [UInt16: UInt16] = [:]
    for module in modules {
      let normalCount = routes.lazy.filter {
        $0.receiverModuleIdentifier == module.identifier
          && !$0.flags.contains(.emergency)
      }.count
      if normalCount > 0 {
        normalBudgets[module.identifier] = UInt16(min(normalCount, 4))
      }
    }
    return try RegionalTokenProgram(
      schedule: schedule,
      routes: routes,
      normalRouteBudgets: normalBudgets,
      historyCapacity: historyCapacity
    )
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
      for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
  }
}

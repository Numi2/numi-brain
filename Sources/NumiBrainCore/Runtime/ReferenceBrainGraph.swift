import Foundation

@frozen
public enum BrainFunctionalDomain: UInt16, Codable, CaseIterable, Sendable {
  case sensoryPeripheral = 0
  case routingBroadcast = 1
  case bodySpatialSelf = 2
  case worldAssociation = 3
  case memory = 4
  case motivationNeuromodulation = 5
  case decision = 6
  case motorCerebellarBrainstemSpinal = 7
}

@frozen
public struct ReferenceBrainModule: Codable, Equatable, Hashable, Sendable {
  public let identifier: UInt16
  public let name: String
  public let domain: BrainFunctionalDomain
  public let schedule: BrainModuleDescriptor

  public init(
    identifier: UInt16,
    name: String,
    domain: BrainFunctionalDomain,
    schedule: BrainModuleDescriptor
  ) throws {
    guard identifier == schedule.moduleIdentifier,
      !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw BrainRuntimeError.invalidSchedule("reference brain-module identity is invalid")
    }
    self.identifier = identifier
    self.name = name
    self.domain = domain
    self.schedule = schedule
  }
}

/// Complete logical mammalian reference graph from the NumiBrain v1.0
/// architecture. It defines stable functional identities and multi-rate state
/// shapes; species templates may disable, split, merge, or resize modules while
/// retaining the runtime contract.
@frozen
public struct ReferenceBrainGraph: Codable, Equatable, Sendable {
  public static let formatVersion: UInt32 = 1

  public let modules: [ReferenceBrainModule]
  public let schedule: BrainModuleSchedule
  public let routes: [RegionalTokenRoute]
  public let fingerprint: UInt64

  public init(
    modules: [ReferenceBrainModule],
    routes: [RegionalTokenRoute]
  ) throws {
    let canonical = modules.sorted { $0.identifier < $1.identifier }
    guard canonical.count == 96,
      canonical.enumerated().allSatisfy({ index, module in
        module.identifier == UInt16(index + 1)
      }),
      Set(canonical.map(\.name)).count == canonical.count
    else {
      throw BrainRuntimeError.invalidSchedule(
        "reference brain graph must contain unique modules 1 through 96"
      )
    }
    let schedule = try BrainModuleSchedule(modules: canonical.map(\.schedule))
    let moduleIdentifiers = Set(canonical.map(\.identifier))
    guard routes.allSatisfy({
      moduleIdentifiers.contains($0.senderModuleIdentifier)
        && moduleIdentifiers.contains($0.receiverModuleIdentifier)
    }) else {
      throw BrainRuntimeError.invalidSchedule(
        "reference brain route names an unknown module"
      )
    }
    let canonicalRoutes = routes.sorted {
      if $0.receiverModuleIdentifier != $1.receiverModuleIdentifier {
        return $0.receiverModuleIdentifier < $1.receiverModuleIdentifier
      }
      if $0.senderModuleIdentifier != $1.senderModuleIdentifier {
        return $0.senderModuleIdentifier < $1.senderModuleIdentifier
      }
      return $0.senderToken < $1.senderToken
    }
    for (previous, current) in zip(canonicalRoutes, canonicalRoutes.dropFirst()) {
      guard previous.senderModuleIdentifier != current.senderModuleIdentifier
        || previous.receiverModuleIdentifier != current.receiverModuleIdentifier
        || previous.senderToken != current.senderToken
      else {
        throw BrainRuntimeError.invalidSchedule("reference brain route is duplicated")
      }
    }
    var hash: UInt64 = 14_695_981_039_346_656_037
    Self.mix(Self.formatVersion, into: &hash)
    Self.mix(schedule.fingerprint, into: &hash)
    for module in canonical {
      Self.mix(module.identifier, into: &hash)
      Self.mix(module.domain.rawValue, into: &hash)
      for byte in module.name.utf8 {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
      hash ^= 0
      hash &*= 1_099_511_628_211
    }
    for route in canonicalRoutes {
      Self.mix(route.senderModuleIdentifier, into: &hash)
      Self.mix(route.receiverModuleIdentifier, into: &hash)
      Self.mix(route.senderToken, into: &hash)
      Self.mix(route.delayMicroseconds, into: &hash)
      Self.mix(route.gain.bitPattern, into: &hash)
      Self.mix(route.flags.rawValue, into: &hash)
    }
    self.modules = canonical
    self.schedule = schedule
    self.routes = canonicalRoutes
    fingerprint = hash
  }

  public func module(identifier: UInt16) -> ReferenceBrainModule? {
    guard identifier > 0, Int(identifier) <= modules.count else { return nil }
    return modules[Int(identifier - 1)]
  }

  public func modules(in domain: BrainFunctionalDomain) -> [ReferenceBrainModule] {
    modules.filter { $0.domain == domain }
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

  public static func mammalianV1() throws -> Self {
    let names = [
      "Left foveal retina",
      "Right foveal retina",
      "Left peripheral retina",
      "Right peripheral retina",
      "Visual motion and depth",
      "Visual form and surface structure",
      "Left cochlear stream",
      "Right cochlear stream",
      "Auditory scene analysis",
      "Skin pressure and shear",
      "Skin vibration and texture",
      "Temperature and nociception",
      "Proprioceptive receptor fusion",
      "Vestibular receptor fusion",
      "Olfactory processing",
      "Gustatory processing",
      "Interoceptive processing",
      "Multisensory alignment",
      "Primary sensory relay",
      "Visual routing",
      "Auditory routing",
      "Somatic routing",
      "Higher-order association routing",
      "Salience gate",
      "Workspace broadcast",
      "Emergency interrupt bus",
      "Body-graph state",
      "Joint-state estimator",
      "Muscle-state estimator",
      "Self-generated versus external contact",
      "Balance and support model",
      "Peripersonal-space model",
      "Reachability and affordance model",
      "Pain and vulnerability map",
      "Agency and corollary-discharge model",
      "Spatial coordinate transforms",
      "Fast sensory dynamics",
      "Sensorimotor dynamics",
      "Object-slot state",
      "Other-agent slot state",
      "Local scene model",
      "Persistent spatial map",
      "Physical and causal interaction model",
      "Social prediction",
      "Temporal context",
      "Event segmentation",
      "Abstract state",
      "Goal context",
      "Counterfactual dynamics",
      "Uncertainty decomposition",
      "Communication and language association",
      "Self-history and identity state",
      "Working-memory maintenance",
      "Episodic encoder",
      "Episodic index",
      "Episodic retrieval",
      "Episodic reconsolidation",
      "Semantic concept store",
      "Semantic relation store",
      "Procedural skill library",
      "Prospective intention memory",
      "Replay and consolidation",
      "Homeostatic controller",
      "Pain and threat controller",
      "Curiosity and information drive",
      "Social drive",
      "Value-prediction system",
      "Arousal and gain controller",
      "Sleep and rest controller",
      "Neuromodulator dispatch",
      "Affordance proposer",
      "Skill candidate generator",
      "Direct selection channel",
      "Indirect suppression channel",
      "Hyperdirect stop channel",
      "Option sequencer",
      "Latent planner",
      "Arbitration, persistence and vigor",
      "Motor-goal transform",
      "Reference movement generator",
      "Muscle-synergy generator",
      "Force, stiffness and impedance control",
      "Cerebellar context selector",
      "Cerebellar forward prediction",
      "Cerebellar inverse correction",
      "Cerebellar error and adaptation",
      "Orienting brainstem controller",
      "Posture and balance brainstem controller",
      "Autonomic brainstem controller",
      "Locomotor CPG",
      "Vital and respiratory CPG",
      "Upper-limb spinal controller",
      "Lower-limb spinal controller",
      "Axial and neck spinal controller",
      "Reflex interneuron network",
      "Motor-neuron output",
    ]
    let modules = try names.enumerated().map { index, name -> ReferenceBrainModule in
      let identifier = UInt16(index + 1)
      let timing = timing(for: identifier)
      let shape = tokenShape(for: identifier)
      return try ReferenceBrainModule(
        identifier: identifier,
        name: name,
        domain: domain(for: identifier),
        schedule: BrainModuleDescriptor(
          moduleIdentifier: identifier,
          clockClass: timing.clockClass,
          periodMicroseconds: timing.period,
          conductionDelayMicroseconds: timing.delay,
          intrinsicTimescaleMicroseconds: timing.timescale,
          interruptMask: interruptMask(for: identifier),
          tokenCount: shape.count,
          tokenDimension: shape.dimension
        )
      )
    }
    return try Self(modules: modules, routes: mammalianRoutes())
  }

  private static func mammalianRoutes() throws -> [RegionalTokenRoute] {
    typealias Edge = (UInt16, UInt16, UInt32, Float, Bool)
    let edges: [Edge] = [
      (1, 5, 1_000, 0.75, false), (2, 5, 1_000, 0.75, false),
      (3, 5, 1_000, 0.60, false), (4, 5, 1_000, 0.60, false),
      (1, 6, 1_000, 0.75, false), (2, 6, 1_000, 0.75, false),
      (3, 6, 1_000, 0.60, false), (4, 6, 1_000, 0.60, false),
      (7, 9, 750, 0.80, false), (8, 9, 750, 0.80, false),
      (5, 20, 1_000, 0.80, false), (6, 20, 1_000, 0.80, false),
      (9, 21, 1_000, 0.85, false), (10, 22, 750, 0.80, false),
      (11, 22, 750, 0.70, false), (12, 22, 250, 1.00, true),
      (13, 22, 500, 0.85, false), (14, 22, 500, 0.90, false),
      (15, 19, 1_000, 0.55, false), (16, 19, 1_000, 0.55, false),
      (17, 19, 500, 0.85, false), (20, 18, 1_000, 0.75, false),
      (21, 18, 1_000, 0.75, false), (22, 18, 1_000, 0.85, false),
      (18, 23, 1_500, 0.80, false), (19, 24, 1_000, 0.65, false),
      (20, 24, 1_000, 0.70, false), (21, 24, 1_000, 0.70, false),
      (22, 24, 500, 0.85, false), (23, 25, 2_000, 0.70, false),
      (24, 25, 1_000, 0.90, false), (12, 26, 0, 1.00, true),
      (14, 26, 0, 1.00, true), (17, 26, 0, 1.00, true),
      (13, 28, 500, 0.90, false), (13, 29, 500, 0.90, false),
      (10, 30, 500, 0.80, false), (12, 34, 250, 1.00, true),
      (14, 31, 500, 0.95, false), (27, 28, 1_000, 0.70, false),
      (27, 29, 1_000, 0.70, false), (28, 27, 1_000, 0.75, false),
      (29, 27, 1_000, 0.75, false), (30, 34, 500, 0.90, false),
      (30, 35, 1_000, 0.75, false), (31, 27, 500, 0.90, false),
      (27, 32, 1_500, 0.70, false), (32, 33, 1_500, 0.75, false),
      (27, 36, 1_500, 0.75, false), (32, 36, 1_500, 0.70, false),
      (18, 37, 2_000, 0.80, false), (27, 38, 1_000, 0.90, false),
      (35, 38, 1_000, 0.75, false), (37, 38, 2_000, 0.80, false),
      (6, 39, 2_000, 0.75, false), (38, 39, 2_000, 0.80, false),
      (9, 40, 2_000, 0.65, false), (39, 41, 3_000, 0.85, false),
      (40, 41, 3_000, 0.75, false), (41, 42, 5_000, 0.70, false),
      (39, 43, 3_000, 0.80, false), (38, 43, 2_000, 0.85, false),
      (40, 44, 3_000, 0.80, false), (41, 44, 5_000, 0.65, false),
      (41, 45, 3_000, 0.70, false), (45, 46, 2_000, 0.80, false),
      (46, 47, 5_000, 0.70, false), (25, 48, 2_000, 0.85, false),
      (43, 49, 5_000, 0.80, false), (50, 49, 5_000, 0.70, false),
      (37, 50, 2_000, 0.75, false), (44, 51, 5_000, 0.65, false),
      (45, 52, 5_000, 0.70, false), (25, 53, 2_000, 0.90, false),
      (46, 54, 3_000, 0.90, false), (54, 55, 1_000, 0.90, false),
      (55, 56, 2_000, 0.85, false), (56, 25, 2_000, 0.80, false),
      (56, 57, 2_000, 0.75, false), (57, 54, 2_000, 0.70, false),
      (57, 58, 5_000, 0.75, false), (58, 59, 2_000, 0.80, false),
      (60, 72, 2_000, 0.90, false), (61, 25, 2_000, 0.80, false),
      (62, 43, 5_000, 0.65, false), (62, 58, 5_000, 0.75, false),
      (17, 63, 500, 0.90, false), (34, 64, 250, 1.00, true),
      (50, 65, 2_000, 0.80, false), (40, 66, 3_000, 0.75, false),
      (43, 67, 3_000, 0.80, false), (49, 67, 5_000, 0.75, false),
      (64, 68, 250, 0.95, true), (63, 70, 500, 0.90, false),
      (64, 70, 250, 1.00, true), (65, 70, 1_000, 0.75, false),
      (66, 70, 1_000, 0.70, false), (67, 70, 1_000, 0.80, false),
      (33, 71, 2_000, 0.85, false), (48, 71, 2_000, 0.85, false),
      (53, 72, 2_000, 0.70, false), (67, 73, 1_000, 0.90, false),
      (67, 74, 1_000, 0.75, false), (64, 75, 0, 1.00, true),
      (26, 75, 0, 1.00, true), (73, 76, 1_000, 0.85, false),
      (74, 76, 1_000, 0.80, false), (76, 77, 3_000, 0.80, false),
      (49, 77, 5_000, 0.85, false), (77, 78, 2_000, 0.90, false),
      (75, 78, 0, 1.00, true), (78, 79, 1_000, 0.95, false),
      (79, 80, 1_000, 0.90, false), (80, 81, 500, 0.90, false),
      (81, 82, 500, 0.90, false), (82, 83, 500, 0.80, false),
      (82, 85, 500, 0.85, false), (83, 84, 500, 0.90, false),
      (84, 86, 500, 0.90, false), (86, 85, 250, 0.85, false),
      (24, 87, 250, 0.80, false), (31, 88, 250, 0.95, true),
      (63, 89, 250, 0.90, false), (78, 90, 500, 0.80, false),
      (63, 91, 250, 0.90, false), (81, 92, 250, 0.90, false),
      (81, 93, 250, 0.90, false), (81, 94, 250, 0.85, false),
      (26, 95, 0, 1.00, true), (90, 95, 250, 0.85, false),
      (91, 95, 250, 0.85, false), (92, 95, 250, 0.90, false),
      (93, 95, 250, 0.90, false), (94, 95, 250, 0.85, false),
      (95, 96, 250, 1.00, false), (96, 35, 1_000, 0.80, false),
      (96, 38, 1_000, 0.75, false), (95, 86, 250, 0.85, false),
    ]
    return try edges.map { sender, receiver, delay, gain, emergency in
      try RegionalTokenRoute(
        senderModuleIdentifier: sender,
        receiverModuleIdentifier: receiver,
        delayMicroseconds: delay,
        gain: gain,
        flags: emergency ? [.emergency, .persistent] : [.persistent]
      )
    }
  }

  private static func domain(for identifier: UInt16) -> BrainFunctionalDomain {
    switch identifier {
    case 1...18: .sensoryPeripheral
    case 19...26: .routingBroadcast
    case 27...36: .bodySpatialSelf
    case 37...52: .worldAssociation
    case 53...62: .memory
    case 63...70: .motivationNeuromodulation
    case 71...78: .decision
    default: .motorCerebellarBrainstemSpinal
    }
  }

  private static func timing(for identifier: UInt16) -> (
    clockClass: BrainClockClass,
    period: UInt32,
    delay: UInt32,
    timescale: UInt32
  ) {
    switch identifier {
    case 1...6: return (.cortical, 20_000, 1_000, 40_000)
    case 7...14: return (.sensoryFusion, 10_000, 750, 20_000)
    case 15...18: return (.sensoryFusion, 20_000, 1_000, 50_000)
    case 19...24: return (.sensoryFusion, 10_000, 1_000, 20_000)
    case 25: return (.workspace, 50_000, 2_000, 100_000)
    case 26: return (.emergency, 1_000, 0, 2_000)
    case 27...36: return (.cortical, 20_000, 1_500, 50_000)
    case 37...38: return (.cortical, 20_000, 2_000, 40_000)
    case 39...46: return (.scene, 50_000, 3_000, 150_000)
    case 47...52: return (.abstract, 100_000, 5_000, 300_000)
    case 53: return (.workspace, 50_000, 2_000, 250_000)
    case 54...61: return (.scene, 100_000, 5_000, 500_000)
    case 62: return (.replay, 100_000, 5_000, 1_000_000)
    case 63: return (.planning, 100_000, 2_000, 500_000)
    case 64: return (.cortical, 20_000, 500, 50_000)
    case 65...67: return (.workspace, 50_000, 2_000, 250_000)
    case 68: return (.cortical, 20_000, 500, 100_000)
    case 69: return (.planning, 100_000, 2_000, 1_000_000)
    case 70: return (.cortical, 20_000, 500, 100_000)
    case 71...75: return (.cortical, 20_000, 1_000, 50_000)
    case 76: return (.cortical, 40_000, 2_000, 150_000)
    case 77: return (.planning, 100_000, 5_000, 250_000)
    case 78: return (.cortical, 20_000, 1_000, 100_000)
    case 79...82: return (.cortical, 20_000, 1_000, 50_000)
    case 83...86: return (.cerebellar, 5_000, 500, 10_000)
    case 87...89: return (.physicalFast, 5_000, 250, 10_000)
    case 90...91: return (.cpg, 2_000, 250, 5_000)
    default: return (.spinal, 1_000, 250, 5_000)
    }
  }

  private static func tokenShape(for identifier: UInt16) -> (
    count: UInt16,
    dimension: UInt16
  ) {
    switch identifier {
    case 1...4, 7...8, 10...17, 26, 90...96: return (2, 32)
    case 25: return (16, 256)
    case 37...62, 71...82: return (4, 128)
    case 27...36, 63...70, 83...89: return (4, 64)
    default: return (2, 64)
    }
  }

  private static func interruptMask(for identifier: UInt16) -> BrainInterruptMask {
    switch identifier {
    case 5, 6, 20, 37: return [.visualTransient, .impact]
    case 7...9, 21: return [.soundOnset]
    case 10...12, 22: return [.pain, .damagingContact, .impact]
    case 13, 28, 29: return [.jointLimit, .muscleOverload]
    case 14, 31: return [.lossOfSupport, .impact]
    case 17, 63, 69, 89, 91: return [.physiologicalCritical]
    case 18, 19, 23...24, 68, 70:
      return [
        .pain, .damagingContact, .lossOfSupport, .impact,
        .physiologicalCritical, .jointLimit, .muscleOverload,
        .soundOnset, .visualTransient,
      ]
    case 26, 75:
      return [
        .pain, .damagingContact, .lossOfSupport, .impact,
        .physiologicalCritical, .jointLimit, .muscleOverload, .rescue,
      ]
    case 27, 30, 32...36, 38, 50, 64:
      return [.pain, .damagingContact, .lossOfSupport, .impact, .muscleOverload]
    case 73...74, 76, 78:
      return [.pain, .lossOfSupport, .physiologicalCritical, .muscleOverload]
    case 79...88:
      return [.pain, .damagingContact, .lossOfSupport, .impact, .muscleOverload]
    case 90, 92...96:
      return [
        .pain, .damagingContact, .lossOfSupport, .impact,
        .jointLimit, .muscleOverload,
      ]
    default: return []
    }
  }

  private static func mix(_ value: UInt16, into hash: inout UInt64) {
    mix(UInt64(value), byteCount: 2, into: &hash)
  }

  private static func mix(_ value: UInt32, into hash: inout UInt64) {
    mix(UInt64(value), byteCount: 4, into: &hash)
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    mix(value, byteCount: 8, into: &hash)
  }

  private static func mix(_ value: UInt64, byteCount: Int, into hash: inout UInt64) {
    let littleEndian = value.littleEndian
    for byteIndex in 0..<byteCount {
      hash ^= UInt64(UInt8(truncatingIfNeeded: littleEndian >> UInt64(byteIndex * 8)))
      hash &*= 1_099_511_628_211
    }
  }
}

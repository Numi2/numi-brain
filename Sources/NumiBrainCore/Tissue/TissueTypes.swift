import Foundation

/// One mesoscale tissue site's normalized population state.
///
/// The four-lane representation is the canonical CPU/Metal ABI:
/// excitatory activity, inhibitory activity, adaptation, and axonal relay state.
public typealias TissueCell = SIMD4<Float>

public enum TissueCellLane {
  public static let excitatory = 0
  public static let inhibitory = 1
  public static let adaptation = 2
  public static let axonalRelay = 3
}

/// Immutable per-site tissue structure shared by the CPU oracle and Metal runtime.
///
/// The lanes scale excitatory response, inhibitory response, local outgoing
/// coupling, and viability. They are deliberately separate from neural history:
/// lesions and morphology therefore cannot be accidentally rolled forward or
/// backward with a candidate state generation.
public typealias TissueSite = SIMD4<Float>

public enum TissueSiteLane {
  public static let excitatoryScale = 0
  public static let inhibitoryScale = 1
  public static let couplingScale = 2
  public static let viability = 3
}

/// Immutable per-site outgoing conduction delay, expressed in accepted
/// integration steps. The v0.2 runtime uses a fixed 32-slot history ring so a
/// delay is always explicit and deterministic across CPU and Metal backends.
public struct TissueDelayField: Equatable, Sendable {
  public static let historyCapacity = 32
  public static let maximumDelaySteps = historyCapacity - 1

  public let width: Int
  public let height: Int
  public var delaySteps: [UInt8]

  public init(width: Int, height: Int, repeating delaySteps: UInt8 = 0) throws {
    guard width > 0, height > 0 else {
      throw TissueError.invalidConduction("width and height must be positive")
    }
    let (count, overflow) = width.multipliedReportingOverflow(by: height)
    guard !overflow else {
      throw TissueError.invalidConduction("width × height overflows Int")
    }
    guard Int(delaySteps) <= Self.maximumDelaySteps else {
      throw TissueError.invalidConduction(
        "delay exceeds the \(Self.maximumDelaySteps)-step history limit"
      )
    }
    self.width = width
    self.height = height
    self.delaySteps = Array(repeating: delaySteps, count: count)
  }

  public init(width: Int, height: Int, delaySteps: [UInt8]) throws {
    guard width > 0, height > 0 else {
      throw TissueError.invalidConduction("width and height must be positive")
    }
    let (count, overflow) = width.multipliedReportingOverflow(by: height)
    guard !overflow, delaySteps.count == count else {
      throw TissueError.invalidConduction("delay count does not match width × height")
    }
    self.width = width
    self.height = height
    self.delaySteps = delaySteps
    try validate()
  }

  public var count: Int { delaySteps.count }
  public var maximumConfiguredDelaySteps: Int { Int(delaySteps.max() ?? 0) }

  public subscript(x: Int, y: Int) -> UInt8 {
    get { delaySteps[y * width + x] }
    set { delaySteps[y * width + x] = newValue }
  }

  public static func instantaneous(width: Int, height: Int) throws -> TissueDelayField {
    try TissueDelayField(width: width, height: height)
  }

  /// Synthetic outgoing delay classes for the four v0 cortical strata.
  /// Values are integration-step classes, not calibrated conduction velocity.
  public static func layeredCorticalSheetV0(
    width: Int,
    height: Int
  ) throws -> TissueDelayField {
    var field = try TissueDelayField(width: width, height: height)
    let heightScale = Float(max(height - 1, 1))
    for y in 0..<height {
      let depth = Float(y) / heightScale
      let delay: UInt8
      switch depth {
      case ..<0.18: delay = 4
      case ..<0.48: delay = 2
      case ..<0.78: delay = 3
      default: delay = 1
      }
      for x in 0..<width {
        field[x, y] = delay
      }
    }
    return field
  }

  public func validate() throws {
    guard delaySteps.allSatisfy({ Int($0) <= Self.maximumDelaySteps }) else {
      throw TissueError.invalidConduction(
        "delay exceeds the \(Self.maximumDelaySteps)-step history limit"
      )
    }
  }

  public func stableHash() -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    @inline(__always)
    func mix(_ byte: UInt8, into hash: inout UInt64) {
      hash ^= UInt64(byte)
      hash &*= 0x100_0000_01b3
    }
    for byte in withUnsafeBytes(of: UInt32(width).littleEndian, Array.init) {
      mix(byte, into: &hash)
    }
    for byte in withUnsafeBytes(of: UInt32(height).littleEndian, Array.init) {
      mix(byte, into: &hash)
    }
    for delay in delaySteps {
      mix(delay, into: &hash)
    }
    return String(format: "%016llx", hash)
  }
}

public struct TissueProjection: Equatable, Sendable, Codable {
  public let sourceIndex: Int
  public let destinationIndex: Int
  public let weight: Float
  public let delaySteps: UInt8

  public init(
    sourceIndex: Int,
    destinationIndex: Int,
    weight: Float,
    delaySteps: UInt8
  ) {
    self.sourceIndex = sourceIndex
    self.destinationIndex = destinationIndex
    self.weight = weight
    self.delaySteps = delaySteps
  }
}

/// Destination-major sparse long-range axonal projections.
///
/// The CPU representation owns validated semantic edges. Metal receives a CSR
/// offset table and packed `uint4` edges containing source, delay, FP32 weight
/// bits, and flags. Projection delay samples the same committed relay history
/// as local conduction, so a long-range tract cannot read future source state.
public struct TissueConnectome: Equatable, Sendable {
  public typealias PackedEdge = SIMD4<UInt32>

  public let width: Int
  public let height: Int
  public let destinationOffsets: [UInt32]
  public let projections: [TissueProjection]

  public init(
    width: Int,
    height: Int,
    projections: [TissueProjection]
  ) throws {
    guard width > 0, height > 0 else {
      throw TissueError.invalidConnectome("width and height must be positive")
    }
    let (siteCount, siteOverflow) = width.multipliedReportingOverflow(by: height)
    guard !siteOverflow, siteCount <= Int(UInt32.max) else {
      throw TissueError.invalidConnectome("site count exceeds UInt32 CSR capacity")
    }
    guard projections.count <= Int(UInt32.max) else {
      throw TissueError.invalidConnectome("edge count exceeds UInt32 CSR capacity")
    }
    for edge in projections {
      guard (0..<siteCount).contains(edge.sourceIndex),
        (0..<siteCount).contains(edge.destinationIndex)
      else {
        throw TissueError.invalidConnectome("projection endpoint is outside the tissue grid")
      }
      guard edge.weight.isFinite else {
        throw TissueError.invalidConnectome("projection weights must be finite")
      }
      guard Int(edge.delaySteps) <= TissueDelayField.maximumDelaySteps else {
        throw TissueError.invalidConnectome(
          "projection delay exceeds the \(TissueDelayField.maximumDelaySteps)-step history limit"
        )
      }
    }

    let sorted = projections.enumerated().sorted { lhs, rhs in
      let left = lhs.element
      let right = rhs.element
      if left.destinationIndex != right.destinationIndex {
        return left.destinationIndex < right.destinationIndex
      }
      if left.sourceIndex != right.sourceIndex {
        return left.sourceIndex < right.sourceIndex
      }
      if left.delaySteps != right.delaySteps {
        return left.delaySteps < right.delaySteps
      }
      if left.weight.bitPattern != right.weight.bitPattern {
        return left.weight.bitPattern < right.weight.bitPattern
      }
      return lhs.offset < rhs.offset
    }.map(\.element)

    var offsets = Array(repeating: UInt32.zero, count: siteCount + 1)
    for edge in sorted {
      offsets[edge.destinationIndex + 1] += 1
    }
    for index in 1..<offsets.count {
      offsets[index] += offsets[index - 1]
    }

    self.width = width
    self.height = height
    self.destinationOffsets = offsets
    self.projections = sorted
  }

  public var siteCount: Int { width * height }
  public var edgeCount: Int { projections.count }
  public var maximumProjectionDelaySteps: Int {
    Int(projections.lazy.map(\.delaySteps).max() ?? 0)
  }
  public var maximumIncomingProjectionCount: Int {
    destinationOffsets.indices.dropLast().reduce(0) { maximum, index in
      max(maximum, Int(destinationOffsets[index + 1] - destinationOffsets[index]))
    }
  }

  public static func none(width: Int, height: Int) throws -> TissueConnectome {
    try TissueConnectome(width: width, height: height, projections: [])
  }

  /// Creates two synthetic mirrored projection bands across the sheet.
  /// This is a deterministic long-range communication test, not a calibrated
  /// corpus callosum or species connectome.
  public static func bilateralBridgeV0(
    width: Int,
    height: Int,
    weight: Float = 0.6,
    delaySteps: UInt8 = 12
  ) throws -> TissueConnectome {
    guard weight.isFinite else {
      throw TissueError.invalidConnectome("bridge weight must be finite")
    }
    var edges: [TissueProjection] = []
    let widthScale = Float(max(width - 1, 1))
    let heightScale = Float(max(height - 1, 1))
    for y in 0..<height {
      let normalizedY = Float(y) / heightScale
      guard (0.35...0.65).contains(normalizedY) else { continue }
      for x in 0..<width {
        let normalizedX = Float(x) / widthScale
        guard
          (0.18...0.32).contains(normalizedX)
            || (0.68...0.82).contains(normalizedX)
        else { continue }
        let sourceX = width - 1 - x
        edges.append(
          TissueProjection(
            sourceIndex: y * width + sourceX,
            destinationIndex: y * width + x,
            weight: weight,
            delaySteps: delaySteps
          )
        )
      }
    }
    return try TissueConnectome(width: width, height: height, projections: edges)
  }

  public func packedEdges() -> [PackedEdge] {
    projections.map { edge in
      PackedEdge(
        UInt32(edge.sourceIndex),
        UInt32(edge.delaySteps),
        edge.weight.bitPattern,
        0
      )
    }
  }

  public func stableHash() -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    @inline(__always)
    func mix(_ value: UInt32, into hash: inout UInt64) {
      var littleEndian = value.littleEndian
      withUnsafeBytes(of: &littleEndian) { bytes in
        for byte in bytes {
          hash ^= UInt64(byte)
          hash &*= 0x100_0000_01b3
        }
      }
    }
    mix(UInt32(width), into: &hash)
    mix(UInt32(height), into: &hash)
    for edge in projections {
      mix(UInt32(edge.sourceIndex), into: &hash)
      mix(UInt32(edge.destinationIndex), into: &hash)
      mix(edge.weight.bitPattern, into: &hash)
      mix(UInt32(edge.delaySteps), into: &hash)
    }
    return String(format: "%016llx", hash)
  }
}

public struct TissueStructure: Equatable, Sendable {
  public let width: Int
  public let height: Int
  public var sites: [TissueSite]

  public init(
    width: Int,
    height: Int,
    repeating site: TissueSite = TissueSite(repeating: 1)
  ) throws {
    guard width > 0, height > 0 else {
      throw TissueError.invalidStructure("width and height must be positive")
    }
    let (count, overflow) = width.multipliedReportingOverflow(by: height)
    guard !overflow else {
      throw TissueError.invalidStructure("width × height overflows Int")
    }
    self.width = width
    self.height = height
    self.sites = Array(repeating: site, count: count)
    try validate()
  }

  public init(width: Int, height: Int, sites: [TissueSite]) throws {
    guard width > 0, height > 0 else {
      throw TissueError.invalidStructure("width and height must be positive")
    }
    let (count, overflow) = width.multipliedReportingOverflow(by: height)
    guard !overflow, sites.count == count else {
      throw TissueError.invalidStructure("site count does not match width × height")
    }
    self.width = width
    self.height = height
    self.sites = sites
    try validate()
  }

  public var count: Int { sites.count }

  public subscript(x: Int, y: Int) -> TissueSite {
    get { sites[y * width + x] }
    set { sites[y * width + x] = newValue }
  }

  public static func homogeneous(width: Int, height: Int) throws -> TissueStructure {
    try TissueStructure(width: width, height: height)
  }

  /// Creates deterministic, synthetic depth strata for development testing.
  /// These coefficients are not calibrated to a named cortical area or species.
  public static func layeredCorticalSheetV0(
    width: Int,
    height: Int
  ) throws -> TissueStructure {
    var structure = try TissueStructure(width: width, height: height)
    let heightScale = Float(max(height - 1, 1))
    let widthScale = Float(max(width - 1, 1))
    for y in 0..<height {
      let depth = Float(y) / heightScale
      let stratum: TissueSite
      switch depth {
      case ..<0.18:
        stratum = TissueSite(0.90, 0.92, 0.72, 1)
      case ..<0.48:
        stratum = TissueSite(1.12, 0.94, 1.00, 1)
      case ..<0.78:
        stratum = TissueSite(1.00, 1.10, 0.90, 1)
      default:
        stratum = TissueSite(0.82, 0.88, 1.18, 1)
      }
      for x in 0..<width {
        // A small deterministic lateral modulation prevents every site in a
        // stratum from being numerically identical without introducing RNG.
        let lateral = Float(x) / widthScale
        let modulation = 1 + 0.04 * sin(2 * .pi * lateral)
        structure[x, y] = TissueSite(
          stratum.x * modulation,
          stratum.y / modulation,
          stratum.z,
          stratum.w
        )
      }
    }
    try structure.validate()
    return structure
  }

  public mutating func applyCircularLesion(
    centerX: Float,
    centerY: Float,
    radius: Float,
    viability: Float = 0
  ) throws {
    let values = [centerX, centerY, radius, viability]
    guard values.allSatisfy(\.isFinite) else {
      throw TissueError.invalidStructure("lesion values must be finite")
    }
    guard (0...1).contains(centerX), (0...1).contains(centerY) else {
      throw TissueError.invalidStructure("lesion center must use normalized [0, 1] coordinates")
    }
    guard radius >= 0, (0...1).contains(viability) else {
      throw TissueError.invalidStructure(
        "lesion radius must be nonnegative and viability in [0, 1]")
    }
    let widthScale = Float(max(width - 1, 1))
    let heightScale = Float(max(height - 1, 1))
    for y in 0..<height {
      for x in 0..<width {
        let dx = Float(x) / widthScale - centerX
        let dy = Float(y) / heightScale - centerY
        if dx * dx + dy * dy <= radius * radius {
          self[x, y].w = min(self[x, y].w, viability)
        }
      }
    }
  }

  public func validate() throws {
    for site in sites {
      guard site.x.isFinite, site.y.isFinite, site.z.isFinite, site.w.isFinite else {
        throw TissueError.invalidStructure("all site coefficients must be finite")
      }
      guard site.x >= 0, site.y >= 0, site.z >= 0, (0...1).contains(site.w) else {
        throw TissueError.invalidStructure(
          "response and coupling scales must be nonnegative and viability in [0, 1]"
        )
      }
    }
  }

  public func stableHash() -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    @inline(__always)
    func mix(_ value: UInt32, into hash: inout UInt64) {
      var littleEndian = value.littleEndian
      withUnsafeBytes(of: &littleEndian) { bytes in
        for byte in bytes {
          hash ^= UInt64(byte)
          hash &*= 0x100_0000_01b3
        }
      }
    }
    mix(UInt32(width), into: &hash)
    mix(UInt32(height), into: &hash)
    for site in sites {
      mix(site.x.bitPattern, into: &hash)
      mix(site.y.bitPattern, into: &hash)
      mix(site.z.bitPattern, into: &hash)
      mix(site.w.bitPattern, into: &hash)
    }
    return String(format: "%016llx", hash)
  }
}

public struct TissueGrid: Equatable, Sendable {
  public let width: Int
  public let height: Int
  public var cells: [TissueCell]

  public init(width: Int, height: Int, repeating cell: TissueCell = .zero) throws {
    guard width > 0, height > 0 else {
      throw TissueError.invalidGrid("width and height must be positive")
    }
    let (count, overflow) = width.multipliedReportingOverflow(by: height)
    guard !overflow else {
      throw TissueError.invalidGrid("width × height overflows Int")
    }
    self.width = width
    self.height = height
    self.cells = Array(repeating: cell, count: count)
  }

  public init(width: Int, height: Int, cells: [TissueCell]) throws {
    guard width > 0, height > 0 else {
      throw TissueError.invalidGrid("width and height must be positive")
    }
    let (count, overflow) = width.multipliedReportingOverflow(by: height)
    guard !overflow, cells.count == count else {
      throw TissueError.invalidGrid("cell count does not match width × height")
    }
    self.width = width
    self.height = height
    self.cells = cells
  }

  public var count: Int { cells.count }

  public subscript(x: Int, y: Int) -> TissueCell {
    get { cells[y * width + x] }
    set { cells[y * width + x] = newValue }
  }

  public func stableHash() -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325

    @inline(__always)
    func mix(_ value: UInt32, into hash: inout UInt64) {
      var littleEndian = value.littleEndian
      withUnsafeBytes(of: &littleEndian) { bytes in
        for byte in bytes {
          hash ^= UInt64(byte)
          hash &*= 0x100_0000_01b3
        }
      }
    }

    mix(UInt32(width), into: &hash)
    mix(UInt32(height), into: &hash)
    for cell in cells {
      mix(cell.x.bitPattern, into: &hash)
      mix(cell.y.bitPattern, into: &hash)
      mix(cell.z.bitPattern, into: &hash)
      mix(cell.w.bitPattern, into: &hash)
    }
    return String(format: "%016llx", hash)
  }
}

public struct TissueStimulus: Equatable, Sendable, Codable {
  public var centerX: Float
  public var centerY: Float
  public var radius: Float
  public var excitatoryDrive: Float
  public var inhibitoryDrive: Float
  public var startMilliseconds: Float
  public var endMilliseconds: Float

  public init(
    centerX: Float = 0.5,
    centerY: Float = 0.5,
    radius: Float = 0.08,
    excitatoryDrive: Float = 4.0,
    inhibitoryDrive: Float = 0.0,
    startMilliseconds: Float = 20.0,
    endMilliseconds: Float = 60.0
  ) {
    self.centerX = centerX
    self.centerY = centerY
    self.radius = radius
    self.excitatoryDrive = excitatoryDrive
    self.inhibitoryDrive = inhibitoryDrive
    self.startMilliseconds = startMilliseconds
    self.endMilliseconds = endMilliseconds
  }

  public static let none = TissueStimulus(
    radius: 0,
    excitatoryDrive: 0,
    inhibitoryDrive: 0,
    startMilliseconds: 0,
    endMilliseconds: 0
  )

  public func validate() throws {
    let values = [
      centerX, centerY, radius, excitatoryDrive, inhibitoryDrive,
      startMilliseconds, endMilliseconds,
    ]
    guard values.allSatisfy(\.isFinite) else {
      throw TissueError.invalidStimulus("all stimulus values must be finite")
    }
    guard (0...1).contains(centerX), (0...1).contains(centerY) else {
      throw TissueError.invalidStimulus("center must use normalized [0, 1] coordinates")
    }
    guard radius >= 0 else {
      throw TissueError.invalidStimulus("radius must be nonnegative")
    }
    guard endMilliseconds >= startMilliseconds else {
      throw TissueError.invalidStimulus("end time must not precede start time")
    }
  }
}

public struct TissueParameters: Equatable, Sendable, Codable {
  public var timestepMilliseconds: Float
  public var excitatoryTimeConstantMilliseconds: Float
  public var inhibitoryTimeConstantMilliseconds: Float
  public var adaptationTimeConstantMilliseconds: Float
  public var axonalRelayTimeConstantMilliseconds: Float
  public var excitatorySelfWeight: Float
  public var inhibitoryToExcitatoryWeight: Float
  public var excitatoryToInhibitoryWeight: Float
  public var inhibitorySelfWeight: Float
  public var excitatorySpatialMix: Float
  public var inhibitorySpatialMix: Float
  public var adaptationStrength: Float
  public var longRangeProjectionGain: Float
  public var excitatoryBias: Float
  public var inhibitoryBias: Float
  public var excitatoryGain: Float
  public var inhibitoryGain: Float

  public init(
    timestepMilliseconds: Float = 1.0,
    excitatoryTimeConstantMilliseconds: Float = 10.0,
    inhibitoryTimeConstantMilliseconds: Float = 20.0,
    adaptationTimeConstantMilliseconds: Float = 200.0,
    axonalRelayTimeConstantMilliseconds: Float = 8.0,
    excitatorySelfWeight: Float = 10.0,
    inhibitoryToExcitatoryWeight: Float = 12.0,
    excitatoryToInhibitoryWeight: Float = 10.0,
    inhibitorySelfWeight: Float = 2.0,
    excitatorySpatialMix: Float = 0.75,
    inhibitorySpatialMix: Float = 0.15,
    adaptationStrength: Float = 2.0,
    longRangeProjectionGain: Float = 1.0,
    excitatoryBias: Float = -2.5,
    inhibitoryBias: Float = -3.0,
    excitatoryGain: Float = 1.0,
    inhibitoryGain: Float = 1.0
  ) {
    self.timestepMilliseconds = timestepMilliseconds
    self.excitatoryTimeConstantMilliseconds = excitatoryTimeConstantMilliseconds
    self.inhibitoryTimeConstantMilliseconds = inhibitoryTimeConstantMilliseconds
    self.adaptationTimeConstantMilliseconds = adaptationTimeConstantMilliseconds
    self.axonalRelayTimeConstantMilliseconds = axonalRelayTimeConstantMilliseconds
    self.excitatorySelfWeight = excitatorySelfWeight
    self.inhibitoryToExcitatoryWeight = inhibitoryToExcitatoryWeight
    self.excitatoryToInhibitoryWeight = excitatoryToInhibitoryWeight
    self.inhibitorySelfWeight = inhibitorySelfWeight
    self.excitatorySpatialMix = excitatorySpatialMix
    self.inhibitorySpatialMix = inhibitorySpatialMix
    self.adaptationStrength = adaptationStrength
    self.longRangeProjectionGain = longRangeProjectionGain
    self.excitatoryBias = excitatoryBias
    self.inhibitoryBias = inhibitoryBias
    self.excitatoryGain = excitatoryGain
    self.inhibitoryGain = inhibitoryGain
  }

  public static let corticalSheetV0 = TissueParameters()

  public func validate() throws {
    let values = [
      timestepMilliseconds,
      excitatoryTimeConstantMilliseconds,
      inhibitoryTimeConstantMilliseconds,
      adaptationTimeConstantMilliseconds,
      axonalRelayTimeConstantMilliseconds,
      excitatorySelfWeight,
      inhibitoryToExcitatoryWeight,
      excitatoryToInhibitoryWeight,
      inhibitorySelfWeight,
      excitatorySpatialMix,
      inhibitorySpatialMix,
      adaptationStrength,
      longRangeProjectionGain,
      excitatoryBias,
      inhibitoryBias,
      excitatoryGain,
      inhibitoryGain,
    ]
    guard values.allSatisfy(\.isFinite) else {
      throw TissueError.invalidParameters("all parameters must be finite")
    }
    guard timestepMilliseconds > 0 else {
      throw TissueError.invalidParameters("timestep must be positive")
    }
    guard excitatoryTimeConstantMilliseconds >= timestepMilliseconds,
      inhibitoryTimeConstantMilliseconds >= timestepMilliseconds,
      adaptationTimeConstantMilliseconds >= timestepMilliseconds,
      axonalRelayTimeConstantMilliseconds >= timestepMilliseconds
    else {
      throw TissueError.invalidParameters("time constants must be at least one timestep")
    }
    guard (0...1).contains(excitatorySpatialMix),
      (0...1).contains(inhibitorySpatialMix)
    else {
      throw TissueError.invalidParameters("spatial mixing must lie in [0, 1]")
    }
    guard excitatoryGain > 0, inhibitoryGain > 0 else {
      throw TissueError.invalidParameters("sigmoid gains must be positive")
    }
  }
}

public struct TissueMetrics: Equatable, Sendable, Codable {
  public let meanExcitatory: Float
  public let meanInhibitory: Float
  public let meanAdaptation: Float
  public let meanAxonalRelay: Float
  public let maximumExcitatory: Float
  public let minimumExcitatory: Float
  public let maximumExcitatoryOutsideStimulus: Float
  public let meanExcitatoryOutsideStimulus: Float
  public let activeFraction: Float
  public let recruitedOutsideStimulusFraction: Float
  public let viableFraction: Float
  public let finite: Bool
  public let bounded: Bool
  public let stateHash: String
}

public enum TissueError: Error, Equatable, CustomStringConvertible {
  case invalidGrid(String)
  case invalidStructure(String)
  case invalidConduction(String)
  case invalidConnectome(String)
  case invalidParameters(String)
  case invalidStimulus(String)
  case transaction(String)
  case metal(String)

  public var description: String {
    switch self {
    case .invalidGrid(let message): "invalid grid: \(message)"
    case .invalidStructure(let message): "invalid tissue structure: \(message)"
    case .invalidConduction(let message): "invalid tissue conduction: \(message)"
    case .invalidConnectome(let message): "invalid tissue connectome: \(message)"
    case .invalidParameters(let message): "invalid parameters: \(message)"
    case .invalidStimulus(let message): "invalid stimulus: \(message)"
    case .transaction(let message): "transaction error: \(message)"
    case .metal(let message): "Metal error: \(message)"
    }
  }
}

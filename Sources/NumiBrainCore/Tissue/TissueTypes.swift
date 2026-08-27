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
  case invalidParameters(String)
  case invalidStimulus(String)
  case transaction(String)
  case metal(String)

  public var description: String {
    switch self {
    case .invalidGrid(let message): "invalid grid: \(message)"
    case .invalidStructure(let message): "invalid tissue structure: \(message)"
    case .invalidParameters(let message): "invalid parameters: \(message)"
    case .invalidStimulus(let message): "invalid stimulus: \(message)"
    case .transaction(let message): "transaction error: \(message)"
    case .metal(let message): "Metal error: \(message)"
    }
  }
}

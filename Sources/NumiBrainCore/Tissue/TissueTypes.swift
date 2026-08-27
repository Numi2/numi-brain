import Foundation

/// One mesoscale tissue site's normalized population state.
///
/// The four-lane representation is the canonical CPU/Metal ABI for v0:
/// excitatory activity, inhibitory activity, adaptation, and reserved state.
public typealias TissueCell = SIMD4<Float>

public enum TissueCellLane {
  public static let excitatory = 0
  public static let inhibitory = 1
  public static let adaptation = 2
  public static let reserved = 3
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
      adaptationTimeConstantMilliseconds >= timestepMilliseconds
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
  public let maximumExcitatory: Float
  public let minimumExcitatory: Float
  public let maximumExcitatoryOutsideStimulus: Float
  public let meanExcitatoryOutsideStimulus: Float
  public let activeFraction: Float
  public let recruitedOutsideStimulusFraction: Float
  public let finite: Bool
  public let bounded: Bool
  public let stateHash: String
}

public enum TissueError: Error, Equatable, CustomStringConvertible {
  case invalidGrid(String)
  case invalidParameters(String)
  case invalidStimulus(String)
  case transaction(String)
  case metal(String)

  public var description: String {
    switch self {
    case .invalidGrid(let message): "invalid grid: \(message)"
    case .invalidParameters(let message): "invalid parameters: \(message)"
    case .invalidStimulus(let message): "invalid stimulus: \(message)"
    case .transaction(let message): "transaction error: \(message)"
    case .metal(let message): "Metal error: \(message)"
    }
  }
}

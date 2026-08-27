import Foundation

private struct TissueSiteKey: Hashable {
  let excitatoryScale: UInt32
  let inhibitoryScale: UInt32
  let couplingScale: UInt32
  let viability: UInt32

  init(_ site: TissueSite) {
    excitatoryScale = site.x.bitPattern
    inhibitoryScale = site.y.bitPattern
    couplingScale = site.z.bitPattern
    viability = site.w.bitPattern
  }
}

public enum CPUTissueDynamics {
  @inline(__always)
  private static func sigmoid(_ value: Float) -> Float {
    1 / (1 + Foundation.exp(-value))
  }

  @inline(__always)
  private static func clampedIndex(_ value: Int, upperBound: Int) -> Int {
    min(max(value, 0), upperBound - 1)
  }

  public static func restingCell(
    parameters: TissueParameters,
    site: TissueSite = TissueSite(repeating: 1),
    iterations: Int = 4_096
  ) throws -> TissueCell {
    try parameters.validate()
    guard site.x.isFinite, site.y.isFinite, site.z.isFinite, site.w.isFinite,
      site.x >= 0, site.y >= 0, site.z >= 0, (0...1).contains(site.w)
    else {
      throw TissueError.invalidStructure("resting-site coefficients are invalid")
    }
    if site.w == 0 {
      return .zero
    }
    var cell = TissueCell(0.05, 0.05, 0.05, 0)
    let relaxation: Float = 0.02

    for _ in 0..<iterations {
      let e = cell.x
      let i = cell.y
      let a = cell.z
      let targetE = sigmoid(
        parameters.excitatoryGain * site.x
          * (parameters.excitatorySelfWeight * e
            - parameters.inhibitoryToExcitatoryWeight * i
            - parameters.adaptationStrength * a
            + parameters.excitatoryBias)
      )
      let targetI = sigmoid(
        parameters.inhibitoryGain * site.y
          * (parameters.excitatoryToInhibitoryWeight * e
            - parameters.inhibitorySelfWeight * i
            + parameters.inhibitoryBias)
      )
      cell.x += relaxation * (site.w * targetE - e)
      cell.y += relaxation * (site.w * targetI - i)
      cell.z += relaxation * (site.w * e - a)
    }
    cell.w = cell.x
    return cell
  }

  public static func makeRestingGrid(
    width: Int,
    height: Int,
    parameters: TissueParameters
  ) throws -> TissueGrid {
    let structure = try TissueStructure.homogeneous(width: width, height: height)
    return try makeRestingGrid(parameters: parameters, structure: structure)
  }

  public static func makeRestingGrid(
    parameters: TissueParameters,
    structure: TissueStructure
  ) throws -> TissueGrid {
    try structure.validate()
    var cells: [TissueCell] = []
    cells.reserveCapacity(structure.count)
    var equilibriumCache: [TissueSiteKey: TissueCell] = [:]
    for site in structure.sites {
      let key = TissueSiteKey(site)
      if let cached = equilibriumCache[key] {
        cells.append(cached)
      } else {
        let equilibrium = try restingCell(parameters: parameters, site: site)
        equilibriumCache[key] = equilibrium
        cells.append(equilibrium)
      }
    }
    return try TissueGrid(width: structure.width, height: structure.height, cells: cells)
  }

  public static func advance(
    _ input: TissueGrid,
    timeMilliseconds: Float,
    parameters: TissueParameters,
    stimulus: TissueStimulus
  ) throws -> TissueGrid {
    let structure = try TissueStructure.homogeneous(width: input.width, height: input.height)
    return try advance(
      input,
      timeMilliseconds: timeMilliseconds,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure
    )
  }

  public static func advance(
    _ input: TissueGrid,
    timeMilliseconds: Float,
    parameters: TissueParameters,
    stimulus: TissueStimulus,
    structure: TissueStructure
  ) throws -> TissueGrid {
    try parameters.validate()
    try stimulus.validate()
    try structure.validate()
    guard structure.width == input.width, structure.height == input.height else {
      throw TissueError.invalidStructure("structure dimensions must match the state grid")
    }
    guard timeMilliseconds.isFinite else {
      throw TissueError.invalidParameters("simulation time must be finite")
    }

    var output = try TissueGrid(width: input.width, height: input.height)
    let widthScale = Float(max(input.width - 1, 1))
    let heightScale = Float(max(input.height - 1, 1))
    let stimulusActive =
      timeMilliseconds >= stimulus.startMilliseconds
      && timeMilliseconds < stimulus.endMilliseconds
      && stimulus.radius > 0

    for y in 0..<input.height {
      let up = clampedIndex(y - 1, upperBound: input.height)
      let down = clampedIndex(y + 1, upperBound: input.height)
      for x in 0..<input.width {
        let left = clampedIndex(x - 1, upperBound: input.width)
        let right = clampedIndex(x + 1, upperBound: input.width)
        let center = input[x, y]
        let north = input[x, up]
        let south = input[x, down]
        let west = input[left, y]
        let east = input[right, y]

        let centerSite = structure[x, y]
        let northSite = structure[x, up]
        let southSite = structure[x, down]
        let westSite = structure[left, y]
        let eastSite = structure[right, y]

        let neighborRelay =
          0.25
          * (north.w * northSite.z * northSite.w
            + south.w * southSite.z * southSite.w
            + west.w * westSite.z * westSite.w
            + east.w * eastSite.z * eastSite.w)
        let neighborI =
          0.25
          * (north.y * northSite.z * northSite.w
            + south.y * southSite.z * southSite.w
            + west.y * westSite.z * westSite.w
            + east.y * eastSite.z * eastSite.w)
        let spatialE =
          center.x
          + parameters.excitatorySpatialMix * (neighborRelay - center.x)
        let spatialI =
          center.y
          + parameters.inhibitorySpatialMix * (neighborI - center.y)

        var stimulusE: Float = 0
        var stimulusI: Float = 0
        if stimulusActive {
          let normalizedX = Float(x) / widthScale
          let normalizedY = Float(y) / heightScale
          let dx = normalizedX - stimulus.centerX
          let dy = normalizedY - stimulus.centerY
          if dx * dx + dy * dy <= stimulus.radius * stimulus.radius {
            stimulusE = stimulus.excitatoryDrive
            stimulusI = stimulus.inhibitoryDrive
          }
        }

        let targetE = sigmoid(
          parameters.excitatoryGain * centerSite.x
            * (parameters.excitatorySelfWeight * spatialE
              - parameters.inhibitoryToExcitatoryWeight * center.y
              - parameters.adaptationStrength * center.z
              + parameters.excitatoryBias
              + stimulusE)
        )
        let targetI = sigmoid(
          parameters.inhibitoryGain * centerSite.y
            * (parameters.excitatoryToInhibitoryWeight * spatialE
              - parameters.inhibitorySelfWeight * spatialI
              + parameters.inhibitoryBias
              + stimulusI)
        )

        let nextE = min(
          max(
            center.x
              + parameters.timestepMilliseconds
              / parameters.excitatoryTimeConstantMilliseconds
              * (centerSite.w * targetE - center.x),
            0
          ), 1)
        let nextI = min(
          max(
            center.y
              + parameters.timestepMilliseconds
              / parameters.inhibitoryTimeConstantMilliseconds
              * (centerSite.w * targetI - center.y),
            0
          ), 1)
        let nextA = min(
          max(
            center.z
              + parameters.timestepMilliseconds
              / parameters.adaptationTimeConstantMilliseconds
              * (center.x - center.z),
            0
          ), 1)

        let nextRelay = min(
          max(
            center.w
              + parameters.timestepMilliseconds
              / parameters.axonalRelayTimeConstantMilliseconds
              * (center.x - center.w),
            0
          ), 1)

        output[x, y] = TissueCell(nextE, nextI, nextA, nextRelay)
      }
    }
    return output
  }

  public static func metrics(
    for grid: TissueGrid,
    stimulus: TissueStimulus,
    structure: TissueStructure? = nil,
    activeThreshold: Float = 0.2
  ) -> TissueMetrics {
    var sumE: Float = 0
    var sumI: Float = 0
    var sumA: Float = 0
    var sumRelay: Float = 0
    var viableCount: Float = 0
    var maximumE = -Float.infinity
    var minimumE = Float.infinity
    var activeCount = 0
    var outsideCount = 0
    var outsideActiveCount = 0
    var outsideExcitatorySum: Float = 0
    var outsideExcitatoryMaximum: Float = 0
    var finite = true
    var bounded = true
    let widthScale = Float(max(grid.width - 1, 1))
    let heightScale = Float(max(grid.height - 1, 1))

    for y in 0..<grid.height {
      for x in 0..<grid.width {
        let cell = grid[x, y]
        sumE += cell.x
        sumI += cell.y
        sumA += cell.z
        sumRelay += cell.w
        viableCount += structure?[x, y].w ?? 1
        maximumE = max(maximumE, cell.x)
        minimumE = min(minimumE, cell.x)
        finite =
          finite && cell.x.isFinite && cell.y.isFinite && cell.z.isFinite
          && cell.w.isFinite
        bounded =
          bounded
          && (0...1).contains(cell.x)
          && (0...1).contains(cell.y)
          && (0...1).contains(cell.z)
          && (0...1).contains(cell.w)
        if cell.x >= activeThreshold {
          activeCount += 1
        }

        let normalizedX = Float(x) / widthScale
        let normalizedY = Float(y) / heightScale
        let dx = normalizedX - stimulus.centerX
        let dy = normalizedY - stimulus.centerY
        if dx * dx + dy * dy > stimulus.radius * stimulus.radius {
          outsideCount += 1
          outsideExcitatorySum += cell.x
          outsideExcitatoryMaximum = max(outsideExcitatoryMaximum, cell.x)
          if cell.x >= activeThreshold {
            outsideActiveCount += 1
          }
        }
      }
    }

    let count = Float(grid.count)
    return TissueMetrics(
      meanExcitatory: sumE / count,
      meanInhibitory: sumI / count,
      meanAdaptation: sumA / count,
      meanAxonalRelay: sumRelay / count,
      maximumExcitatory: maximumE,
      minimumExcitatory: minimumE,
      maximumExcitatoryOutsideStimulus: outsideExcitatoryMaximum,
      meanExcitatoryOutsideStimulus: outsideCount == 0
        ? 0
        : outsideExcitatorySum / Float(outsideCount),
      activeFraction: Float(activeCount) / count,
      recruitedOutsideStimulusFraction: outsideCount == 0
        ? 0
        : Float(outsideActiveCount) / Float(outsideCount),
      viableFraction: viableCount / count,
      finite: finite,
      bounded: bounded,
      stateHash: grid.stableHash()
    )
  }
}

/// CPU oracle for the same committed/root-shadow/candidate state machine used by Metal.
public struct CPUTissueRuntime: Sendable {
  public private(set) var committed: TissueGrid
  public let parameters: TissueParameters
  public let stimulus: TissueStimulus
  public let structure: TissueStructure

  private var rootShadow: TissueGrid?
  private var candidate: TissueGrid?
  private var acceptedTimeMilliseconds: Float?

  public init(
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus
  ) throws {
    let structure = try TissueStructure.homogeneous(
      width: initialState.width,
      height: initialState.height
    )
    try self.init(
      initialState: initialState,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure
    )
  }

  public init(
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus,
    structure: TissueStructure
  ) throws {
    try parameters.validate()
    try stimulus.validate()
    try structure.validate()
    guard structure.width == initialState.width, structure.height == initialState.height else {
      throw TissueError.invalidStructure("structure dimensions must match the initial state")
    }
    self.committed = initialState
    self.parameters = parameters
    self.stimulus = stimulus
    self.structure = structure
  }

  public var hasOpenRootTransaction: Bool { rootShadow != nil }
  public var hasCandidateSubstep: Bool { candidate != nil }

  public mutating func beginRootTransaction(at timeMilliseconds: Float) throws {
    guard rootShadow == nil else {
      throw TissueError.transaction("a root transaction is already open")
    }
    guard timeMilliseconds.isFinite else {
      throw TissueError.transaction("root time must be finite")
    }
    rootShadow = committed
    candidate = nil
    acceptedTimeMilliseconds = timeMilliseconds
  }

  public mutating func advanceCandidateSubstep() throws {
    guard let rootShadow, let time = acceptedTimeMilliseconds else {
      throw TissueError.transaction("begin a root transaction before advancing")
    }
    guard candidate == nil else {
      throw TissueError.transaction("accept or reject the existing candidate first")
    }
    candidate = try CPUTissueDynamics.advance(
      rootShadow,
      timeMilliseconds: time,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure
    )
  }

  public mutating func acceptCandidateSubstep() throws {
    guard let candidate, let time = acceptedTimeMilliseconds else {
      throw TissueError.transaction("there is no candidate substep to accept")
    }
    rootShadow = candidate
    self.candidate = nil
    acceptedTimeMilliseconds = time + parameters.timestepMilliseconds
  }

  public mutating func rejectCandidateSubstep() throws {
    guard candidate != nil else {
      throw TissueError.transaction("there is no candidate substep to reject")
    }
    candidate = nil
  }

  public mutating func commitRootTransaction() throws {
    guard let rootShadow, candidate == nil else {
      throw TissueError.transaction("root commit requires a shadow and no pending candidate")
    }
    committed = rootShadow
    clearTransaction()
  }

  public mutating func abortRootTransaction() throws {
    guard rootShadow != nil else {
      throw TissueError.transaction("there is no root transaction to abort")
    }
    clearTransaction()
  }

  public mutating func runRootTransaction(
    at timeMilliseconds: Float,
    acceptedSubsteps: [Bool],
    commit: Bool = true
  ) throws {
    try beginRootTransaction(at: timeMilliseconds)
    for accepted in acceptedSubsteps {
      try advanceCandidateSubstep()
      if accepted {
        try acceptCandidateSubstep()
      } else {
        try rejectCandidateSubstep()
      }
    }
    if commit {
      try commitRootTransaction()
    } else {
      try abortRootTransaction()
    }
  }

  private mutating func clearTransaction() {
    rootShadow = nil
    candidate = nil
    acceptedTimeMilliseconds = nil
  }
}

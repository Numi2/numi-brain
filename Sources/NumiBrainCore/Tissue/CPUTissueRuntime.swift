import Foundation

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
    iterations: Int = 4_096
  ) throws -> TissueCell {
    try parameters.validate()
    var cell = TissueCell(0.05, 0.05, 0.05, 0)
    let relaxation: Float = 0.02

    for _ in 0..<iterations {
      let e = cell.x
      let i = cell.y
      let a = cell.z
      let targetE = sigmoid(
        parameters.excitatoryGain
          * (parameters.excitatorySelfWeight * e
            - parameters.inhibitoryToExcitatoryWeight * i
            - parameters.adaptationStrength * a
            + parameters.excitatoryBias)
      )
      let targetI = sigmoid(
        parameters.inhibitoryGain
          * (parameters.excitatoryToInhibitoryWeight * e
            - parameters.inhibitorySelfWeight * i
            + parameters.inhibitoryBias)
      )
      cell.x += relaxation * (targetE - e)
      cell.y += relaxation * (targetI - i)
      cell.z += relaxation * (e - a)
    }
    return cell
  }

  public static func makeRestingGrid(
    width: Int,
    height: Int,
    parameters: TissueParameters
  ) throws -> TissueGrid {
    try TissueGrid(
      width: width,
      height: height,
      repeating: restingCell(parameters: parameters)
    )
  }

  public static func advance(
    _ input: TissueGrid,
    timeMilliseconds: Float,
    parameters: TissueParameters,
    stimulus: TissueStimulus
  ) throws -> TissueGrid {
    try parameters.validate()
    try stimulus.validate()
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

        let neighborE = 0.25 * (north.x + south.x + west.x + east.x)
        let neighborI = 0.25 * (north.y + south.y + west.y + east.y)
        let spatialE =
          center.x
          + parameters.excitatorySpatialMix * (neighborE - center.x)
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
          parameters.excitatoryGain
            * (parameters.excitatorySelfWeight * spatialE
              - parameters.inhibitoryToExcitatoryWeight * center.y
              - parameters.adaptationStrength * center.z
              + parameters.excitatoryBias
              + stimulusE)
        )
        let targetI = sigmoid(
          parameters.inhibitoryGain
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
              * (targetE - center.x),
            0
          ), 1)
        let nextI = min(
          max(
            center.y
              + parameters.timestepMilliseconds
              / parameters.inhibitoryTimeConstantMilliseconds
              * (targetI - center.y),
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

        output[x, y] = TissueCell(nextE, nextI, nextA, 0)
      }
    }
    return output
  }

  public static func metrics(
    for grid: TissueGrid,
    stimulus: TissueStimulus,
    activeThreshold: Float = 0.2
  ) -> TissueMetrics {
    var sumE: Float = 0
    var sumI: Float = 0
    var sumA: Float = 0
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
        maximumE = max(maximumE, cell.x)
        minimumE = min(minimumE, cell.x)
        finite = finite && cell.x.isFinite && cell.y.isFinite && cell.z.isFinite
        bounded =
          bounded
          && (0...1).contains(cell.x)
          && (0...1).contains(cell.y)
          && (0...1).contains(cell.z)
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

  private var rootShadow: TissueGrid?
  private var candidate: TissueGrid?
  private var acceptedTimeMilliseconds: Float?

  public init(
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus
  ) throws {
    try parameters.validate()
    try stimulus.validate()
    self.committed = initialState
    self.parameters = parameters
    self.stimulus = stimulus
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
      stimulus: stimulus
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

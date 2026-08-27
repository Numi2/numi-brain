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
    structure: TissueStructure,
    delayedRelay: [Float]? = nil,
    longRangeExcitatoryDrive: [Float]? = nil,
    eventSchedule: TissueEventSchedule? = nil,
    randomContext: TissueRandomContext = .deterministicDefault,
    acceptedStep: UInt64 = 0
  ) throws -> TissueGrid {
    try parameters.validate()
    try stimulus.validate()
    try structure.validate()
    guard structure.width == input.width, structure.height == input.height else {
      throw TissueError.invalidStructure("structure dimensions must match the state grid")
    }
    guard delayedRelay == nil || delayedRelay?.count == input.count else {
      throw TissueError.invalidConduction("delayed relay count must match the state grid")
    }
    guard longRangeExcitatoryDrive == nil || longRangeExcitatoryDrive?.count == input.count else {
      throw TissueError.invalidConnectome("projection drive count must match the state grid")
    }
    guard timeMilliseconds.isFinite else {
      throw TissueError.invalidParameters("simulation time must be finite")
    }

    var output = try TissueGrid(width: input.width, height: input.height)
    let widthScale = Float(max(input.width - 1, 1))
    let heightScale = Float(max(input.height - 1, 1))
    let legacyStimulusActive =
      eventSchedule == nil
      && timeMilliseconds >= stimulus.startMilliseconds
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

        let northRelay = delayedRelay?[up * input.width + x] ?? north.w
        let southRelay = delayedRelay?[down * input.width + x] ?? south.w
        let westRelay = delayedRelay?[y * input.width + left] ?? west.w
        let eastRelay = delayedRelay?[y * input.width + right] ?? east.w
        let projectionDrive = longRangeExcitatoryDrive?[y * input.width + x] ?? 0

        let neighborRelay =
          0.25
          * (northRelay * northSite.z * northSite.w
            + southRelay * southSite.z * southSite.w
            + westRelay * westSite.z * westSite.w
            + eastRelay * eastSite.z * eastSite.w)
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
        if legacyStimulusActive {
          let normalizedX = Float(x) / widthScale
          let normalizedY = Float(y) / heightScale
          let dx = normalizedX - stimulus.centerX
          let dy = normalizedY - stimulus.centerY
          if dx * dx + dy * dy <= stimulus.radius * stimulus.radius {
            stimulusE = stimulus.excitatoryDrive
            stimulusI = stimulus.inhibitoryDrive
          }
        }
        if let eventSchedule {
          let siteIndex = UInt32(truncatingIfNeeded: y * input.width + x)
          let normalizedX = Float(x) / widthScale
          let normalizedY = Float(y) / heightScale
          for event in eventSchedule.events
          where timeMilliseconds >= event.startMilliseconds
            && timeMilliseconds < event.endMilliseconds
            && event.radius > 0
          {
            let dx = normalizedX - event.centerX
            let dy = normalizedY - event.centerY
            guard dx * dx + dy * dy <= event.radius * event.radius else { continue }
            let excitatoryNoise =
              event.noiseAmplitude
              * TissueCounterRandom.symmetricUnit(
                context: randomContext,
                acceptedStep: acceptedStep,
                eventIdentifier: event.identifier,
                siteIndex: siteIndex,
                sampleIndex: 0
              )
            let inhibitoryNoise =
              event.noiseAmplitude
              * TissueCounterRandom.symmetricUnit(
                context: randomContext,
                acceptedStep: acceptedStep,
                eventIdentifier: event.identifier,
                siteIndex: siteIndex,
                sampleIndex: 1
              )
            stimulusE += event.excitatoryDrive + excitatoryNoise
            stimulusI += event.inhibitoryDrive + inhibitoryNoise
          }
        }

        let targetE = sigmoid(
          parameters.excitatoryGain * centerSite.x
            * (parameters.excitatorySelfWeight * spatialE
              - parameters.inhibitoryToExcitatoryWeight * center.y
              - parameters.adaptationStrength * center.z
              + parameters.excitatoryBias
              + stimulusE)
            + parameters.longRangeProjectionGain * projectionDrive
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
  public private(set) var committedStep: UInt64 = 0
  public let parameters: TissueParameters
  public let stimulus: TissueStimulus
  public let structure: TissueStructure
  public let delayField: TissueDelayField
  public let connectome: TissueConnectome
  public let eventSchedule: TissueEventSchedule
  public let randomContext: TissueRandomContext

  private var rootShadow: TissueGrid?
  private var candidate: TissueGrid?
  private var candidateRelay: [Float]?
  private var acceptedTimeMilliseconds: Float?
  private var rootAcceptedStep: UInt64?
  private var rootHistoryWrites: [Int: [Float]] = [:]
  private var committedRelayHistory: [[Float]]

  public init(
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus
  ) throws {
    let structure = try TissueStructure.homogeneous(
      width: initialState.width,
      height: initialState.height
    )
    let delayField = try TissueDelayField.instantaneous(
      width: initialState.width,
      height: initialState.height
    )
    try self.init(
      initialState: initialState,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: delayField,
      connectome: nil,
      eventSchedule: nil,
      randomContext: .deterministicDefault
    )
  }

  public init(
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus,
    structure: TissueStructure
  ) throws {
    let delayField = try TissueDelayField.instantaneous(
      width: initialState.width,
      height: initialState.height
    )
    try self.init(
      initialState: initialState,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: delayField,
      connectome: nil,
      eventSchedule: nil,
      randomContext: .deterministicDefault
    )
  }

  public init(
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus,
    structure: TissueStructure,
    delayField: TissueDelayField,
    connectome requestedConnectome: TissueConnectome? = nil,
    eventSchedule requestedEventSchedule: TissueEventSchedule? = nil,
    randomContext: TissueRandomContext = .deterministicDefault
  ) throws {
    try parameters.validate()
    try stimulus.validate()
    try structure.validate()
    try delayField.validate()
    guard structure.width == initialState.width, structure.height == initialState.height else {
      throw TissueError.invalidStructure("structure dimensions must match the initial state")
    }
    guard delayField.width == initialState.width, delayField.height == initialState.height else {
      throw TissueError.invalidConduction("delay dimensions must match the initial state")
    }
    let connectome: TissueConnectome
    if let requestedConnectome {
      connectome = requestedConnectome
    } else {
      connectome = try TissueConnectome.none(
        width: initialState.width,
        height: initialState.height
      )
    }
    guard connectome.width == initialState.width, connectome.height == initialState.height else {
      throw TissueError.invalidConnectome("connectome dimensions must match the initial state")
    }
    let eventSchedule =
      try requestedEventSchedule
      ?? TissueEventSchedule.singleStimulus(stimulus)
    self.committed = initialState
    self.parameters = parameters
    self.stimulus = stimulus
    self.structure = structure
    self.delayField = delayField
    self.connectome = connectome
    self.eventSchedule = eventSchedule
    self.randomContext = randomContext
    let initialRelay = initialState.cells.map(\.w)
    self.committedRelayHistory = Array(
      repeating: initialRelay,
      count: TissueDelayField.historyCapacity
    )
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
    candidateRelay = nil
    acceptedTimeMilliseconds = timeMilliseconds
    rootAcceptedStep = committedStep
    rootHistoryWrites.removeAll(keepingCapacity: true)
  }

  public mutating func advanceCandidateSubstep() throws {
    guard let rootShadow, let time = acceptedTimeMilliseconds,
      let rootAcceptedStep
    else {
      throw TissueError.transaction("begin a root transaction before advancing")
    }
    guard candidate == nil else {
      throw TissueError.transaction("accept or reject the existing candidate first")
    }
    let delayedRelay = makeDelayedRelay(at: rootAcceptedStep)
    let projectionDrive = makeProjectionDrive(at: rootAcceptedStep)
    let candidate = try CPUTissueDynamics.advance(
      rootShadow,
      timeMilliseconds: time,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayedRelay: delayedRelay,
      longRangeExcitatoryDrive: projectionDrive,
      eventSchedule: eventSchedule,
      randomContext: randomContext,
      acceptedStep: rootAcceptedStep
    )
    self.candidate = candidate
    candidateRelay = candidate.cells.map(\.w)
  }

  public mutating func acceptCandidateSubstep() throws {
    guard let candidate, let candidateRelay, let time = acceptedTimeMilliseconds,
      let rootAcceptedStep
    else {
      throw TissueError.transaction("there is no candidate substep to accept")
    }
    let nextStep = rootAcceptedStep + 1
    let historySlot = Int(nextStep % UInt64(TissueDelayField.historyCapacity))
    rootHistoryWrites[historySlot] = candidateRelay
    rootShadow = candidate
    self.candidate = nil
    self.candidateRelay = nil
    acceptedTimeMilliseconds = time + parameters.timestepMilliseconds
    self.rootAcceptedStep = nextStep
  }

  public mutating func rejectCandidateSubstep() throws {
    guard candidate != nil else {
      throw TissueError.transaction("there is no candidate substep to reject")
    }
    candidate = nil
    candidateRelay = nil
  }

  public mutating func commitRootTransaction() throws {
    guard let rootShadow, let rootAcceptedStep, candidate == nil else {
      throw TissueError.transaction("root commit requires a shadow and no pending candidate")
    }
    committed = rootShadow
    for (slot, relay) in rootHistoryWrites {
      committedRelayHistory[slot] = relay
    }
    committedStep = rootAcceptedStep
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
    candidateRelay = nil
    acceptedTimeMilliseconds = nil
    rootAcceptedStep = nil
    rootHistoryWrites.removeAll(keepingCapacity: true)
  }

  public func committedHistoryHash() -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    @inline(__always)
    func mix(_ byte: UInt8, into hash: inout UInt64) {
      hash ^= UInt64(byte)
      hash &*= 0x100_0000_01b3
    }
    var step = committedStep.littleEndian
    withUnsafeBytes(of: &step) { bytes in
      for byte in bytes { mix(byte, into: &hash) }
    }
    for historySlot in committedRelayHistory {
      for relay in historySlot {
        var bits = relay.bitPattern.littleEndian
        withUnsafeBytes(of: &bits) { bytes in
          for byte in bytes { mix(byte, into: &hash) }
        }
      }
    }
    return String(format: "%016llx", hash)
  }

  private func makeDelayedRelay(at step: UInt64) -> [Float] {
    let capacity = TissueDelayField.historyCapacity
    let currentSlot = Int(step % UInt64(capacity))
    var delayed = Array(repeating: Float.zero, count: committed.count)
    for index in delayed.indices {
      let delay = Int(delayField.delaySteps[index])
      delayed[index] = relay(siteIndex: index, delay: delay, currentSlot: currentSlot)
    }
    return delayed
  }

  private func makeProjectionDrive(at step: UInt64) -> [Float]? {
    guard connectome.edgeCount > 0 else { return nil }
    let currentSlot = Int(step % UInt64(TissueDelayField.historyCapacity))
    var drive = Array(repeating: Float.zero, count: committed.count)
    for destination in 0..<connectome.siteCount {
      let start = Int(connectome.destinationOffsets[destination])
      let end = Int(connectome.destinationOffsets[destination + 1])
      guard start < end else { continue }
      var value: Float = 0
      for edgeIndex in start..<end {
        let edge = connectome.projections[edgeIndex]
        value +=
          edge.weight
          * relay(
            siteIndex: edge.sourceIndex,
            delay: Int(edge.delaySteps),
            currentSlot: currentSlot
          )
      }
      drive[destination] = value
    }
    return drive
  }

  private func relay(siteIndex: Int, delay: Int, currentSlot: Int) -> Float {
    let slot =
      (currentSlot - delay + TissueDelayField.historyCapacity)
      % TissueDelayField.historyCapacity
    return rootHistoryWrites[slot]?[siteIndex] ?? committedRelayHistory[slot][siteIndex]
  }
}

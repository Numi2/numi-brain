import XCTest

@testable import NumiBrainCore

final class CPUTissueRuntimeTests: XCTestCase {
  private let parameters = TissueParameters.corticalSheetV0

  func testCounterRandomAndEventScheduleAreCanonical() throws {
    let context = TissueRandomContext(
      seed: 42,
      environmentIdentifier: 7,
      episodeIdentifier: 9,
      moduleIdentifier: 12
    )
    XCTAssertEqual(
      TissueCounterRandom.sampleBits(
        context: context,
        acceptedStep: 0x1_0000_0002,
        eventIdentifier: 99,
        siteIndex: 123
      ),
      0xac0f_81a4
    )
    XCTAssertEqual(
      TissueCounterRandom.sampleBits(
        context: context,
        acceptedStep: 0x1_0000_0002,
        eventIdentifier: 99,
        siteIndex: 123,
        sampleIndex: 1
      ),
      0x5173_2ae8
    )

    let early = TissueReceptorEvent(
      identifier: 2,
      centerX: 0.25,
      centerY: 0.5,
      radius: 0.1,
      excitatoryDrive: 3,
      startMilliseconds: 5,
      endMilliseconds: 10
    )
    let late = TissueReceptorEvent(
      identifier: 1,
      centerX: 0.75,
      centerY: 0.5,
      radius: 0.1,
      excitatoryDrive: 2,
      startMilliseconds: 15,
      endMilliseconds: 20
    )
    let forward = try TissueEventSchedule(events: [early, late])
    let reversed = try TissueEventSchedule(events: [late, early])
    XCTAssertEqual(forward.events.map(\.identifier), [2, 1])
    XCTAssertEqual(forward.stableHash(), reversed.stableHash())
    XCTAssertEqual(forward.activeEventIndices(at: 4), [])
    XCTAssertEqual(forward.activeEventIndices(at: 5), [0])
    XCTAssertEqual(forward.activeEventIndices(at: 10), [])
    XCTAssertEqual(forward.activeEventIndices(at: 15), [1])
    XCTAssertEqual(forward.activeEventIndices(at: 20), [])
    XCTAssertEqual(forward.maximumSimultaneouslyActiveEventCount, 1)
    XCTAssertEqual(
      forward.activeIndexByteCapacity,
      (TissueEventSchedule.maximumEventCount + 1) * MemoryLayout<UInt32>.stride
    )
    XCTAssertEqual(
      forward.packedByteCount,
      2 * TissueEventSchedule.receptorEventByteCount
    )
    XCTAssertEqual(TissueEventSchedule.receptorEventByteCount, 64)
    XCTAssertThrowsError(try TissueEventSchedule(events: [early, early]))
  }

  func testReceptorInterruptTransductionIsCausalLatentAndBoundaryExact() throws {
    let pain = TissueReceptorEvent(
      identifier: 9,
      centerX: 0.5,
      centerY: 0.5,
      radius: 0.2,
      excitatoryDrive: 4,
      startMilliseconds: 2,
      endMilliseconds: 8,
      interruptMask: .pain,
      conductionLatencyMicroseconds: 500,
      receptorIdentifier: 77,
      magnitude: 4,
      auxiliaryValue: 0.25
    )
    let future = TissueReceptorEvent(
      identifier: 10,
      centerX: 0.5,
      centerY: 0.5,
      radius: 0.2,
      excitatoryDrive: 1,
      startMilliseconds: 20,
      endMilliseconds: 25,
      interruptMask: .impact
    )
    let disabled = TissueReceptorEvent(
      identifier: 11,
      centerX: 0.5,
      centerY: 0.5,
      radius: 0,
      excitatoryDrive: 1,
      startMilliseconds: 3,
      endMilliseconds: 4,
      interruptMask: .pain
    )
    let schedule = try TissueEventSchedule(events: [future, disabled, pain])

    let first = try schedule.schedulerInterruptEvents(
      committedTime: BrainTimestamp(microseconds: 0),
      targetTime: BrainTimestamp(microseconds: 2_499),
      includeCommittedBoundary: true
    )
    XCTAssertTrue(first.isEmpty)

    let delivered = try schedule.schedulerInterruptEvents(
      committedTime: BrainTimestamp(microseconds: 0),
      targetTime: BrainTimestamp(microseconds: 2_500),
      includeCommittedBoundary: true
    )
    XCTAssertEqual(delivered.count, 1)
    XCTAssertEqual(delivered[0].timestamp, BrainTimestamp(microseconds: 2_500))
    XCTAssertEqual(delivered[0].mask, .pain)
    XCTAssertEqual(delivered[0].identifier, 77)

    let repeatedBoundary = try schedule.schedulerInterruptEvents(
      committedTime: BrainTimestamp(microseconds: 2_500),
      targetTime: BrainTimestamp(microseconds: 5_000),
      includeCommittedBoundary: false
    )
    XCTAssertTrue(repeatedBoundary.isEmpty)
  }

  func testNoisyReceptorEventsAreCausalAndSeedDependent() throws {
    let width = 21
    let height = 21
    let structure = try TissueStructure.homogeneous(width: width, height: height)
    let delayField = try TissueDelayField.instantaneous(width: width, height: height)
    let initial = try CPUTissueDynamics.makeRestingGrid(
      parameters: parameters,
      structure: structure
    )
    let event = TissueReceptorEvent(
      identifier: 17,
      centerX: 0.5,
      centerY: 0.5,
      radius: 0.12,
      excitatoryDrive: 3,
      noiseAmplitude: 0.5,
      startMilliseconds: 10,
      endMilliseconds: 20
    )
    let schedule = try TissueEventSchedule(events: [event])
    var first = try CPUTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      structure: structure,
      delayField: delayField,
      eventSchedule: schedule,
      randomContext: TissueRandomContext(seed: 1)
    )
    var secondSeed = try CPUTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      structure: structure,
      delayField: delayField,
      eventSchedule: schedule,
      randomContext: TissueRandomContext(seed: 2)
    )
    var noEvent = try CPUTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      structure: structure,
      delayField: delayField
    )

    let preEventSteps = Array(repeating: true, count: 10)
    try first.runRootTransaction(at: 0, acceptedSubsteps: preEventSteps)
    try secondSeed.runRootTransaction(at: 0, acceptedSubsteps: preEventSteps)
    try noEvent.runRootTransaction(at: 0, acceptedSubsteps: preEventSteps)
    XCTAssertEqual(first.committed, noEvent.committed)
    XCTAssertEqual(secondSeed.committed, noEvent.committed)

    try first.runRootTransaction(at: 10, acceptedSubsteps: [true])
    try secondSeed.runRootTransaction(at: 10, acceptedSubsteps: [true])
    try noEvent.runRootTransaction(at: 10, acceptedSubsteps: [true])
    XCTAssertNotEqual(first.committed, noEvent.committed)
    XCTAssertNotEqual(first.committed, secondSeed.committed)
  }

  func testRestingStateRemainsStableAndBounded() throws {
    var runtime = try makeRuntime(width: 24, height: 24, stimulus: .none)
    let initial = runtime.committed
    try runtime.runRootTransaction(
      at: 0,
      acceptedSubsteps: Array(repeating: true, count: 200)
    )
    let metrics = CPUTissueDynamics.metrics(for: runtime.committed, stimulus: .none)
    XCTAssertTrue(metrics.finite)
    XCTAssertTrue(metrics.bounded)
    XCTAssertLessThan(maximumDifference(initial, runtime.committed), 1e-4)
  }

  func testLocalizedStimulusRecruitsTissueOutsideStimulusFootprint() throws {
    let stimulus = TissueStimulus(
      radius: 0.08,
      excitatoryDrive: 5.0,
      startMilliseconds: 10,
      endMilliseconds: 70
    )
    var runtime = try makeRuntime(width: 48, height: 48, stimulus: stimulus)
    try runtime.runRootTransaction(
      at: 0,
      acceptedSubsteps: Array(repeating: true, count: 40)
    )
    let metrics = CPUTissueDynamics.metrics(
      for: runtime.committed,
      stimulus: stimulus,
      activeThreshold: 0.08
    )
    XCTAssertTrue(metrics.finite)
    XCTAssertTrue(metrics.bounded)
    XCTAssertGreaterThan(metrics.maximumExcitatory, 0.25)
    XCTAssertGreaterThan(metrics.maximumExcitatoryOutsideStimulus, 0.055)
  }

  func testAxonalRelayLagsLocalExcitatoryRecruitment() throws {
    let stimulus = TissueStimulus(
      radius: 0.12,
      excitatoryDrive: 6,
      startMilliseconds: 0,
      endMilliseconds: 10
    )
    var runtime = try makeRuntime(width: 25, height: 25, stimulus: stimulus)
    try runtime.runRootTransaction(at: 0, acceptedSubsteps: [true])

    let center = runtime.committed[12, 12]
    XCTAssertGreaterThan(center.x, center.w)
    XCTAssertGreaterThan(center.w, 0)
  }

  func testExplicitConductionDelayPostponesLateralRecruitment() throws {
    let width = 31
    let height = 31
    let structure = try TissueStructure.homogeneous(width: width, height: height)
    let initial = try CPUTissueDynamics.makeRestingGrid(
      parameters: parameters,
      structure: structure
    )
    let stimulus = TissueStimulus(
      radius: 0.02,
      excitatoryDrive: 8,
      startMilliseconds: 0,
      endMilliseconds: 20
    )
    let immediateField = try TissueDelayField(
      width: width,
      height: height,
      repeating: 0
    )
    let delayedField = try TissueDelayField(
      width: width,
      height: height,
      repeating: 6
    )
    var immediate = try CPUTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: immediateField
    )
    var delayed = try CPUTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: delayedField
    )

    let acceptance = Array(repeating: true, count: 12)
    try immediate.runRootTransaction(at: 0, acceptedSubsteps: acceptance)
    try delayed.runRootTransaction(at: 0, acceptedSubsteps: acceptance)

    let lateralX = width / 2 + 1
    let lateralY = height / 2
    XCTAssertGreaterThan(
      immediate.committed[lateralX, lateralY].x,
      delayed.committed[lateralX, lateralY].x + 1e-6
    )
    XCTAssertNotEqual(immediate.committedHistoryHash(), delayed.committedHistoryHash())
  }

  func testDelayedHistoryRollsBackRetriesAndChunksExactly() throws {
    let width = 20
    let height = 20
    let structure = try TissueStructure.layeredCorticalSheetV0(
      width: width,
      height: height
    )
    let delayField = try TissueDelayField.layeredCorticalSheetV0(
      width: width,
      height: height
    )
    let connectome = try TissueConnectome(
      width: width,
      height: height,
      projections: [
        TissueProjection(
          sourceIndex: (height / 2) * width + width / 4,
          destinationIndex: (height / 2) * width + 3 * width / 4,
          weight: 2,
          delaySteps: 9
        )
      ]
    )
    let initial = try CPUTissueDynamics.makeRestingGrid(
      parameters: parameters,
      structure: structure
    )
    let stimulus = TissueStimulus(startMilliseconds: 5, endMilliseconds: 35)
    let baseline = try CPUTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: delayField,
      connectome: connectome
    )

    var aborted = baseline
    let initialHistoryHash = aborted.committedHistoryHash()
    try aborted.runRootTransaction(
      at: 0,
      acceptedSubsteps: Array(repeating: true, count: 40),
      commit: false
    )
    XCTAssertEqual(aborted.committed, initial)
    XCTAssertEqual(aborted.committedHistoryHash(), initialHistoryHash)

    var direct = baseline
    var retried = baseline
    try direct.runRootTransaction(at: 0, acceptedSubsteps: [true])
    try retried.runRootTransaction(at: 0, acceptedSubsteps: [false, true])
    XCTAssertEqual(direct.committed, retried.committed)
    XCTAssertEqual(direct.committedHistoryHash(), retried.committedHistoryHash())

    var single = baseline
    var chunked = baseline
    try single.runRootTransaction(
      at: 0,
      acceptedSubsteps: Array(repeating: true, count: 40)
    )
    try chunked.runRootTransaction(
      at: 0,
      acceptedSubsteps: Array(repeating: true, count: 20)
    )
    try chunked.runRootTransaction(
      at: 20,
      acceptedSubsteps: Array(repeating: true, count: 20)
    )
    XCTAssertEqual(single.committed, chunked.committed)
    XCTAssertEqual(single.committedHistoryHash(), chunked.committedHistoryHash())
  }

  func testSparseDelayedProjectionRecruitsDistantTarget() throws {
    let width = 41
    let height = 21
    let sourceX = 10
    let destinationX = 30
    let y = height / 2
    let structure = try TissueStructure.homogeneous(width: width, height: height)
    let delayField = try TissueDelayField.instantaneous(width: width, height: height)
    let projection = TissueProjection(
      sourceIndex: y * width + sourceX,
      destinationIndex: y * width + destinationX,
      weight: 4,
      delaySteps: 6
    )
    let connectome = try TissueConnectome(
      width: width,
      height: height,
      projections: [projection]
    )
    let connectomeReplay = try TissueConnectome(
      width: width,
      height: height,
      projections: [projection]
    )
    XCTAssertEqual(connectome.stableHash(), connectomeReplay.stableHash())
    XCTAssertEqual(connectome.edgeCount, 1)
    XCTAssertEqual(connectome.maximumIncomingProjectionCount, 1)

    let initial = try CPUTissueDynamics.makeRestingGrid(
      parameters: parameters,
      structure: structure
    )
    let stimulus = TissueStimulus(
      centerX: Float(sourceX) / Float(width - 1),
      centerY: 0.5,
      radius: 0.03,
      excitatoryDrive: 8,
      startMilliseconds: 0,
      endMilliseconds: 30
    )
    var projected = try CPUTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: delayField,
      connectome: connectome
    )
    var projectionBaseline = try CPUTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      structure: structure,
      delayField: delayField,
      connectome: connectome
    )
    var localOnly = try CPUTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: delayField
    )
    let acceptance = Array(repeating: true, count: 30)
    try projected.runRootTransaction(at: 0, acceptedSubsteps: acceptance)
    try projectionBaseline.runRootTransaction(at: 0, acceptedSubsteps: acceptance)
    try localOnly.runRootTransaction(at: 0, acceptedSubsteps: acceptance)

    let projectedDelta =
      projected.committed[destinationX, y].x
      - projectionBaseline.committed[destinationX, y].x
    let localDelta = localOnly.committed[destinationX, y].x - initial[destinationX, y].x
    XCTAssertGreaterThan(projectedDelta, localDelta + 1e-4)
  }

  func testLayeredStructureAndLesionAreDeterministicAndSilent() throws {
    var structure = try TissueStructure.layeredCorticalSheetV0(width: 48, height: 32)
    let pristineHash = structure.stableHash()
    let duplicate = try TissueStructure.layeredCorticalSheetV0(width: 48, height: 32)
    XCTAssertEqual(pristineHash, duplicate.stableHash())
    XCTAssertNotEqual(structure[12, 4], structure[12, 16])

    try structure.applyCircularLesion(
      centerX: 0.5,
      centerY: 0.5,
      radius: 0.12,
      viability: 0
    )
    XCTAssertNotEqual(pristineHash, structure.stableHash())

    let stimulus = TissueStimulus(
      radius: 0.16,
      excitatoryDrive: 8,
      startMilliseconds: 0,
      endMilliseconds: 30
    )
    let state = try CPUTissueDynamics.makeRestingGrid(
      parameters: parameters,
      structure: structure
    )
    var runtime = try CPUTissueRuntime(
      initialState: state,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure
    )
    try runtime.runRootTransaction(
      at: 0,
      acceptedSubsteps: Array(repeating: true, count: 20)
    )

    assertLesionIsSilent(runtime.committed, structure: structure)
    let metrics = CPUTissueDynamics.metrics(
      for: runtime.committed,
      stimulus: stimulus,
      structure: structure
    )
    XCTAssertTrue(metrics.finite)
    XCTAssertTrue(metrics.bounded)
    XCTAssertLessThan(metrics.viableFraction, 1)
    XCTAssertGreaterThan(metrics.viableFraction, 0.9)
  }

  func testRejectedSubstepDoesNotAdvanceCommittedTrajectory() throws {
    let stimulus = TissueStimulus(startMilliseconds: 0, endMilliseconds: 20)
    var direct = try makeRuntime(
      width: 16,
      height: 16,
      stimulus: stimulus,
      noiseAmplitude: 0.4,
      seed: 91
    )
    var retried = direct

    try direct.runRootTransaction(at: 0, acceptedSubsteps: [true])
    try retried.runRootTransaction(at: 0, acceptedSubsteps: [false, true])

    XCTAssertEqual(direct.committed.stableHash(), retried.committed.stableHash())
    XCTAssertEqual(direct.committed, retried.committed)
  }

  func testRootAbortRestoresEntireCommittedState() throws {
    let stimulus = TissueStimulus(startMilliseconds: 0, endMilliseconds: 20)
    var runtime = try makeRuntime(
      width: 16,
      height: 16,
      stimulus: stimulus,
      noiseAmplitude: 0.4,
      seed: 91
    )
    let before = runtime.committed

    try runtime.runRootTransaction(
      at: 0,
      acceptedSubsteps: Array(repeating: true, count: 12),
      commit: false
    )

    XCTAssertEqual(runtime.committed.stableHash(), before.stableHash())
    XCTAssertEqual(runtime.committed, before)
  }

  func testReplayIsBitExact() throws {
    let stimulus = TissueStimulus(startMilliseconds: 5, endMilliseconds: 35)
    var first = try makeRuntime(
      width: 20,
      height: 20,
      stimulus: stimulus,
      noiseAmplitude: 0.3,
      seed: 123
    )
    var second = first
    let acceptance = [true, true, false, true, true, false, true, true]

    try first.runRootTransaction(at: 0, acceptedSubsteps: acceptance)
    try second.runRootTransaction(at: 0, acceptedSubsteps: acceptance)

    XCTAssertEqual(first.committed.stableHash(), second.committed.stableHash())
    XCTAssertEqual(first.committed, second.committed)
  }

  func testControlIntervalChunkingDoesNotChangeTrajectory() throws {
    let stimulus = TissueStimulus(startMilliseconds: 5, endMilliseconds: 35)
    var single = try makeRuntime(
      width: 20,
      height: 20,
      stimulus: stimulus,
      noiseAmplitude: 0.3,
      seed: 123
    )
    var chunked = single

    try single.runRootTransaction(
      at: 0,
      acceptedSubsteps: Array(repeating: true, count: 40)
    )
    try chunked.runRootTransaction(
      at: 0,
      acceptedSubsteps: Array(repeating: true, count: 20)
    )
    try chunked.runRootTransaction(
      at: 20,
      acceptedSubsteps: Array(repeating: true, count: 20)
    )

    XCTAssertEqual(single.committed.stableHash(), chunked.committed.stableHash())
    XCTAssertEqual(single.committed, chunked.committed)
  }

  private func makeRuntime(
    width: Int,
    height: Int,
    stimulus: TissueStimulus,
    noiseAmplitude: Float = 0,
    seed: UInt32 = 0
  ) throws -> CPUTissueRuntime {
    let structure = try TissueStructure.homogeneous(width: width, height: height)
    let delayField = try TissueDelayField.instantaneous(width: width, height: height)
    let state = try CPUTissueDynamics.makeRestingGrid(
      parameters: parameters,
      structure: structure
    )
    return try CPUTissueRuntime(
      initialState: state,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: delayField,
      eventSchedule: TissueEventSchedule.singleStimulus(
        stimulus,
        noiseAmplitude: noiseAmplitude
      ),
      randomContext: TissueRandomContext(seed: seed)
    )
  }

  private func maximumDifference(_ lhs: TissueGrid, _ rhs: TissueGrid) -> Float {
    zip(lhs.cells, rhs.cells).reduce(0) { result, pair in
      let difference = pair.0 - pair.1
      return max(
        result,
        max(abs(difference.x), abs(difference.y), abs(difference.z), abs(difference.w))
      )
    }
  }

  private func assertLesionIsSilent(
    _ grid: TissueGrid,
    structure: TissueStructure,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    for index in structure.sites.indices where structure.sites[index].w == 0 {
      XCTAssertEqual(grid.cells[index], .zero, file: file, line: line)
    }
  }
}

import XCTest

@testable import NumiBrainCore

final class CPUTissueRuntimeTests: XCTestCase {
  private let parameters = TissueParameters.corticalSheetV0

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
      delayField: delayField
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
    var direct = try makeRuntime(width: 16, height: 16, stimulus: stimulus)
    var retried = direct

    try direct.runRootTransaction(at: 0, acceptedSubsteps: [true])
    try retried.runRootTransaction(at: 0, acceptedSubsteps: [false, true])

    XCTAssertEqual(direct.committed.stableHash(), retried.committed.stableHash())
    XCTAssertEqual(direct.committed, retried.committed)
  }

  func testRootAbortRestoresEntireCommittedState() throws {
    let stimulus = TissueStimulus(startMilliseconds: 0, endMilliseconds: 20)
    var runtime = try makeRuntime(width: 16, height: 16, stimulus: stimulus)
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
    var first = try makeRuntime(width: 20, height: 20, stimulus: stimulus)
    var second = first
    let acceptance = [true, true, false, true, true, false, true, true]

    try first.runRootTransaction(at: 0, acceptedSubsteps: acceptance)
    try second.runRootTransaction(at: 0, acceptedSubsteps: acceptance)

    XCTAssertEqual(first.committed.stableHash(), second.committed.stableHash())
    XCTAssertEqual(first.committed, second.committed)
  }

  func testControlIntervalChunkingDoesNotChangeTrajectory() throws {
    let stimulus = TissueStimulus(startMilliseconds: 5, endMilliseconds: 35)
    var single = try makeRuntime(width: 20, height: 20, stimulus: stimulus)
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
    stimulus: TissueStimulus
  ) throws -> CPUTissueRuntime {
    let state = try CPUTissueDynamics.makeRestingGrid(
      width: width,
      height: height,
      parameters: parameters
    )
    return try CPUTissueRuntime(
      initialState: state,
      parameters: parameters,
      stimulus: stimulus
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

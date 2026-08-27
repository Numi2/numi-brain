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
}

import Metal
import XCTest

@testable import NumiBrainCore
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalTissueRuntimeTests: XCTestCase {
  private let parameters = TissueParameters.corticalSheetV0

  func testMetalAgreesWithCPUOracle() throws {
    try requireMetal4()
    let stimulus = TissueStimulus(startMilliseconds: 2, endMilliseconds: 12)
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 24,
      height: 20,
      parameters: parameters
    )
    let acceptance = Array(repeating: true, count: 20)
    var cpu = try CPUTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus
    )
    try cpu.runRootTransaction(at: 0, acceptedSubsteps: acceptance)

    let metal = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      maxEncodedSubsteps: acceptance.count
    )
    _ = try metal.runRootTransaction(at: 0, acceptedSubsteps: acceptance)
    try metal.commitRootTransaction()
    let gpu = try metal.snapshotCommitted()

    XCTAssertLessThan(maximumDifference(cpu.committed, gpu), 3e-5)
  }

  func testMetalRejectedRetryMatchesDirectAcceptance() throws {
    try requireMetal4()
    let stimulus = TissueStimulus(startMilliseconds: 0, endMilliseconds: 20)
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 16,
      height: 16,
      parameters: parameters
    )
    let direct = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      maxEncodedSubsteps: 2
    )
    let retried = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      maxEncodedSubsteps: 2
    )

    _ = try direct.runRootTransaction(at: 0, acceptedSubsteps: [true])
    try direct.commitRootTransaction()
    _ = try retried.runRootTransaction(at: 0, acceptedSubsteps: [false, true])
    try retried.commitRootTransaction()

    XCTAssertEqual(
      try direct.snapshotCommitted().stableHash(),
      try retried.snapshotCommitted().stableHash()
    )
  }

  func testMetalRootAbortIsBitExact() throws {
    try requireMetal4()
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 16,
      height: 16,
      parameters: parameters
    )
    let runtime = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: TissueStimulus(startMilliseconds: 0, endMilliseconds: 20),
      maxEncodedSubsteps: 8
    )
    _ = try runtime.runRootTransaction(
      at: 0,
      acceptedSubsteps: Array(repeating: true, count: 8)
    )
    try runtime.abortRootTransaction()
    XCTAssertEqual(try runtime.snapshotCommitted().stableHash(), initial.stableHash())
  }

  func testMetalReplayAndControlIntervalChunkingAreBitExact() throws {
    try requireMetal4()
    let stimulus = TissueStimulus(startMilliseconds: 5, endMilliseconds: 35)
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 16,
      height: 16,
      parameters: parameters
    )
    let single = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      maxEncodedSubsteps: 40
    )
    let replay = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      maxEncodedSubsteps: 40
    )
    let chunked = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      maxEncodedSubsteps: 20
    )

    for runtime in [single, replay] {
      _ = try runtime.runRootTransaction(
        at: 0,
        acceptedSubsteps: Array(repeating: true, count: 40)
      )
      try runtime.commitRootTransaction()
    }
    _ = try chunked.runRootTransaction(
      at: 0,
      acceptedSubsteps: Array(repeating: true, count: 20)
    )
    try chunked.commitRootTransaction()
    _ = try chunked.runRootTransaction(
      at: 20,
      acceptedSubsteps: Array(repeating: true, count: 20)
    )
    try chunked.commitRootTransaction()

    let singleHash = try single.snapshotCommitted().stableHash()
    XCTAssertEqual(singleHash, try replay.snapshotCommitted().stableHash())
    XCTAssertEqual(singleHash, try chunked.snapshotCommitted().stableHash())
  }

  private func requireMetal4() throws {
    guard MTLCreateSystemDefaultDevice() != nil else {
      throw XCTSkip("Metal device unavailable")
    }
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

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

  func testMetalAgreesWithCPUForLayeredLesionedTissue() throws {
    try requireMetal4()
    var structure = try TissueStructure.layeredCorticalSheetV0(width: 32, height: 24)
    try structure.applyCircularLesion(
      centerX: 0.55,
      centerY: 0.5,
      radius: 0.14,
      viability: 0
    )
    let stimulus = TissueStimulus(
      centerX: 0.42,
      centerY: 0.5,
      radius: 0.1,
      excitatoryDrive: 6,
      startMilliseconds: 0,
      endMilliseconds: 20
    )
    let delayField = try TissueDelayField.layeredCorticalSheetV0(width: 32, height: 24)
    let initial = try CPUTissueDynamics.makeRestingGrid(
      parameters: parameters,
      structure: structure
    )
    let acceptance = Array(repeating: true, count: 24)
    var cpu = try CPUTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: delayField
    )
    try cpu.runRootTransaction(at: 0, acceptedSubsteps: acceptance)

    let metal = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: delayField,
      maxEncodedSubsteps: acceptance.count
    )
    _ = try metal.runRootTransaction(at: 0, acceptedSubsteps: acceptance)
    try metal.commitRootTransaction()
    let gpu = try metal.snapshotCommitted()

    XCTAssertEqual(metal.structureHash, structure.stableHash())
    XCTAssertEqual(metal.delayFieldHash, delayField.stableHash())
    XCTAssertLessThan(maximumDifference(cpu.committed, gpu), 3e-5)
    for index in structure.sites.indices where structure.sites[index].w == 0 {
      XCTAssertEqual(gpu.cells[index], .zero)
    }
  }

  func testMetalRejectedRetryMatchesDirectAcceptance() throws {
    try requireMetal4()
    let stimulus = TissueStimulus(startMilliseconds: 0, endMilliseconds: 20)
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 16,
      height: 16,
      parameters: parameters
    )
    let delayField = try TissueDelayField(
      width: 16,
      height: 16,
      repeating: 4
    )
    let direct = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      delayField: delayField,
      maxEncodedSubsteps: 12
    )
    let retried = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      delayField: delayField,
      maxEncodedSubsteps: 12
    )

    _ = try direct.runRootTransaction(at: 0, acceptedSubsteps: [true])
    try direct.commitRootTransaction()
    _ = try retried.runRootTransaction(at: 0, acceptedSubsteps: [false, true])
    try retried.commitRootTransaction()
    for runtime in [direct, retried] {
      _ = try runtime.runRootTransaction(
        at: 1,
        acceptedSubsteps: Array(repeating: true, count: 12)
      )
      try runtime.commitRootTransaction()
    }

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
    let delayField = try TissueDelayField(
      width: 16,
      height: 16,
      repeating: 5
    )
    let baseline = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: TissueStimulus(startMilliseconds: 0, endMilliseconds: 20),
      delayField: delayField,
      maxEncodedSubsteps: 16
    )
    let runtime = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: TissueStimulus(startMilliseconds: 0, endMilliseconds: 20),
      delayField: delayField,
      maxEncodedSubsteps: 16
    )
    _ = try runtime.runRootTransaction(
      at: 0,
      acceptedSubsteps: Array(repeating: true, count: 8)
    )
    try runtime.abortRootTransaction()
    XCTAssertEqual(try runtime.snapshotCommitted().stableHash(), initial.stableHash())
    for candidate in [baseline, runtime] {
      _ = try candidate.runRootTransaction(
        at: 0,
        acceptedSubsteps: Array(repeating: true, count: 16)
      )
      try candidate.commitRootTransaction()
    }
    XCTAssertEqual(
      try runtime.snapshotCommitted().stableHash(),
      try baseline.snapshotCommitted().stableHash()
    )
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
      maxEncodedSubsteps: 32
    )
    let replay = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      maxEncodedSubsteps: 32
    )
    let chunked = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      maxEncodedSubsteps: 16
    )

    for runtime in [single, replay] {
      _ = try runtime.runRootTransaction(
        at: 0,
        acceptedSubsteps: Array(repeating: true, count: 32)
      )
      try runtime.commitRootTransaction()
    }
    _ = try chunked.runRootTransaction(
      at: 0,
      acceptedSubsteps: Array(repeating: true, count: 16)
    )
    try chunked.commitRootTransaction()
    _ = try chunked.runRootTransaction(
      at: 16,
      acceptedSubsteps: Array(repeating: true, count: 16)
    )
    try chunked.commitRootTransaction()

    let singleHash = try single.snapshotCommitted().stableHash()
    XCTAssertEqual(singleHash, try replay.snapshotCommitted().stableHash())
    XCTAssertEqual(singleHash, try chunked.snapshotCommitted().stableHash())
  }

  func testMetalRejectsHistoryOverwriteBeforeDispatch() throws {
    try requireMetal4()
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 8,
      height: 8,
      parameters: parameters
    )
    let runtime = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      maxEncodedSubsteps: 33
    )

    XCTAssertThrowsError(
      try runtime.runRootTransaction(
        at: 0,
        acceptedSubsteps: Array(repeating: true, count: 33)
      )
    )
    XCTAssertFalse(runtime.hasPendingRootTransaction)
    XCTAssertEqual(runtime.committedStep, 0)
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

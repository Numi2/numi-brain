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

  func testMetalAgreesWithCPUForNoisyReceptorEvents() throws {
    try requireMetal4()
    let width = 24
    let height = 20
    let structure = try TissueStructure.homogeneous(width: width, height: height)
    let delayField = try TissueDelayField.instantaneous(width: width, height: height)
    let events = try TissueEventSchedule(
      events: [
        TissueReceptorEvent(
          identifier: 41,
          centerX: 0.35,
          centerY: 0.5,
          radius: 0.18,
          excitatoryDrive: 4,
          noiseAmplitude: 0.45,
          startMilliseconds: 2,
          endMilliseconds: 14
        ),
        TissueReceptorEvent(
          identifier: 7,
          centerX: 0.65,
          centerY: 0.5,
          radius: 0.16,
          excitatoryDrive: 1,
          inhibitoryDrive: 2,
          noiseAmplitude: 0.2,
          startMilliseconds: 8,
          endMilliseconds: 18,
          flags: .emergency
        ),
      ]
    )
    let randomContext = TissueRandomContext(
      seed: 0xf00d_beef,
      environmentIdentifier: 3,
      episodeIdentifier: 27,
      moduleIdentifier: 12
    )
    XCTAssertEqual(events.activeEventIndices(at: 1), [])
    XCTAssertEqual(events.activeEventIndices(at: 2), [0])
    XCTAssertEqual(events.activeEventIndices(at: 8), [0, 1])
    XCTAssertEqual(events.activeEventIndices(at: 14), [1])
    XCTAssertEqual(events.activeEventIndices(at: 18), [])
    XCTAssertEqual(events.maximumSimultaneouslyActiveEventCount, 2)
    let initial = try CPUTissueDynamics.makeRestingGrid(
      parameters: parameters,
      structure: structure
    )
    let acceptance = Array(repeating: true, count: 24)
    var cpu = try CPUTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      structure: structure,
      delayField: delayField,
      eventSchedule: events,
      randomContext: randomContext
    )
    try cpu.runRootTransaction(at: 0, acceptedSubsteps: acceptance)

    let metal = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      structure: structure,
      delayField: delayField,
      eventSchedule: events,
      randomContext: randomContext,
      maxEncodedSubsteps: acceptance.count
    )
    let submission = try metal.runRootTransaction(at: 0, acceptedSubsteps: acceptance)
    try metal.commitRootTransaction()
    let gpu = try metal.snapshotCommitted()

    XCTAssertEqual(metal.eventScheduleHash, events.stableHash())
    XCTAssertEqual(metal.eventByteCount, events.packedByteCount)
    XCTAssertEqual(metal.activeEventIndexByteCount, events.activeIndexByteCapacity)
    XCTAssertEqual(submission.eventCompactionDispatches, acceptance.count)
    XCTAssertLessThan(maximumDifference(cpu.committed, gpu), 3e-5)
  }

  func testMetalSchedulerMatchesCPUForPeriodicAndInterruptDueList() throws {
    try requireMetal4()
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let schedulerEvents = [
      try BrainInterruptEvent(
        timestamp: BrainTimestamp(microseconds: 7_500),
        mask: .pain,
        identifier: 1
      ),
      try BrainInterruptEvent(
        timestamp: BrainTimestamp(microseconds: 12_750),
        mask: .lossOfSupport,
        identifier: 2
      ),
      try BrainInterruptEvent(
        timestamp: BrainTimestamp(microseconds: 20_000),
        mask: .pain,
        identifier: 3
      ),
    ]
    var cpu = CPUMultiRateScheduler(schedule: schedule)
    let cpuTransaction = try cpu.beginAdvance(
      to: BrainTimestamp(microseconds: 20_000),
      events: Array(schedulerEvents.reversed())
    )
    try cpu.commit(cpuTransaction)
    var cpuRegionalStates = try CPURegionalModuleOperator.advance(
      states: schedule.modules.map { _ in RegionalModuleState() },
      schedule: schedule,
      invocations: cpuTransaction.invocations
    )

    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 12,
      height: 8,
      parameters: parameters
    )
    let metal = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      brainSchedule: schedule,
      maxEncodedSubsteps: 20
    )
    let submission = try metal.runRootTransaction(
      at: 0,
      acceptedSubsteps: Array(repeating: true, count: 20),
      schedulerEvents: schedulerEvents
    )
    try metal.commitRootTransaction()
    let inspection = try metal.inspectCommittedScheduler()

    XCTAssertEqual(submission.schedulerDispatches, 1)
    XCTAssertEqual(submission.regionalDispatches, 1)
    XCTAssertEqual(submission.schedulerInputEventCount, schedulerEvents.count)
    XCTAssertEqual(metal.schedulerDescriptorByteCount, 8 * 32)
    XCTAssertEqual(metal.schedulerClockByteCount, 8 * 16)
    XCTAssertEqual(metal.schedulerEventCapacityByteCount, 64 * 24)
    XCTAssertEqual(metal.schedulerInvocationCapacityByteCount, 4_096 * 32)
    XCTAssertEqual(metal.regionalStateByteCount, 8 * 32)
    XCTAssertEqual(inspection.status, 0)
    XCTAssertEqual(inspection.invocations, cpuTransaction.invocations)
    XCTAssertEqual(inspection.snapshot, cpu.snapshot)
    try assertRegionalStatesEqual(
      try metal.snapshotCommittedRegionalState(),
      cpuStates: cpuRegionalStates,
      schedulerSnapshot: cpu.snapshot
    )

    let secondEvents = [
      try BrainInterruptEvent(
        timestamp: BrainTimestamp(microseconds: 27_500),
        mask: .lossOfSupport,
        identifier: 4
      )
    ]
    let secondCPUTransaction = try cpu.beginAdvance(
      to: BrainTimestamp(microseconds: 40_000),
      events: secondEvents
    )
    try cpu.commit(secondCPUTransaction)
    cpuRegionalStates = try CPURegionalModuleOperator.advance(
      states: cpuRegionalStates,
      schedule: schedule,
      invocations: secondCPUTransaction.invocations
    )
    _ = try metal.runRootTransaction(
      at: 20,
      acceptedSubsteps: Array(repeating: true, count: 20),
      schedulerEvents: secondEvents
    )
    try metal.commitRootTransaction()
    let secondInspection = try metal.inspectCommittedScheduler()

    XCTAssertEqual(secondInspection.invocations, secondCPUTransaction.invocations)
    XCTAssertEqual(secondInspection.snapshot, cpu.snapshot)
    try assertRegionalStatesEqual(
      try metal.snapshotCommittedRegionalState(),
      cpuStates: cpuRegionalStates,
      schedulerSnapshot: cpu.snapshot
    )
  }

  func testMetalSchedulerRetryAndAbortAreTransactional() throws {
    try requireMetal4()
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 10,
      height: 8,
      parameters: parameters
    )
    let direct = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      brainSchedule: schedule,
      maxEncodedSubsteps: 2
    )
    let retried = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      brainSchedule: schedule,
      maxEncodedSubsteps: 2
    )
    let pain = try BrainInterruptEvent(
      timestamp: BrainTimestamp(microseconds: 500),
      mask: .pain,
      identifier: 7
    )
    _ = try direct.runRootTransaction(
      at: 0,
      acceptedSubsteps: [true],
      schedulerEvents: [pain]
    )
    try direct.commitRootTransaction()
    _ = try retried.runRootTransaction(
      at: 0,
      acceptedSubsteps: [false, true],
      schedulerEvents: [pain]
    )
    try retried.commitRootTransaction()
    XCTAssertEqual(
      try direct.inspectCommittedScheduler(),
      try retried.inspectCommittedScheduler()
    )
    XCTAssertEqual(
      try direct.snapshotCommittedRegionalState(),
      try retried.snapshotCommittedRegionalState()
    )

    let beforeScheduler = try retried.snapshotCommittedScheduler()
    let beforeRegional = try retried.snapshotCommittedRegionalState()
    let beforeTissue = try retried.snapshotCommitted()
    let support = try BrainInterruptEvent(
      timestamp: BrainTimestamp(microseconds: 1_500),
      mask: .lossOfSupport,
      identifier: 8
    )
    _ = try retried.runRootTransaction(
      at: 1,
      acceptedSubsteps: [true],
      schedulerEvents: [support]
    )
    try retried.abortRootTransaction()
    XCTAssertEqual(try retried.snapshotCommittedScheduler(), beforeScheduler)
    XCTAssertEqual(try retried.snapshotCommittedRegionalState(), beforeRegional)
    XCTAssertEqual(try retried.snapshotCommitted().stableHash(), beforeTissue.stableHash())

    for runtime in [direct, retried] {
      _ = try runtime.runRootTransaction(
        at: 1,
        acceptedSubsteps: [true],
        schedulerEvents: [support]
      )
      try runtime.commitRootTransaction()
    }
    XCTAssertEqual(
      try direct.inspectCommittedScheduler(),
      try retried.inspectCommittedScheduler()
    )
    XCTAssertEqual(
      try direct.snapshotCommitted().stableHash(),
      try retried.snapshotCommitted().stableHash()
    )
    XCTAssertEqual(
      try direct.snapshotCommittedRegionalState(),
      try retried.snapshotCommittedRegionalState()
    )
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

  func testMetalAgreesForSparseDelayedProjection() throws {
    try requireMetal4()
    let width = 41
    let height = 21
    let sourceX = 10
    let destinationX = 30
    let y = height / 2
    let structure = try TissueStructure.homogeneous(width: width, height: height)
    let delayField = try TissueDelayField.instantaneous(width: width, height: height)
    let connectome = try TissueConnectome(
      width: width,
      height: height,
      projections: [
        TissueProjection(
          sourceIndex: y * width + sourceX,
          destinationIndex: y * width + destinationX,
          weight: 4,
          delaySteps: 6
        )
      ]
    )
    let stimulus = TissueStimulus(
      centerX: Float(sourceX) / Float(width - 1),
      centerY: 0.5,
      radius: 0.03,
      excitatoryDrive: 8,
      startMilliseconds: 0,
      endMilliseconds: 30
    )
    let initial = try CPUTissueDynamics.makeRestingGrid(
      parameters: parameters,
      structure: structure
    )
    let acceptance = Array(repeating: true, count: 30)
    var cpu = try CPUTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: delayField,
      connectome: connectome
    )
    try cpu.runRootTransaction(at: 0, acceptedSubsteps: acceptance)

    let metal = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      structure: structure,
      delayField: delayField,
      connectome: connectome,
      maxEncodedSubsteps: acceptance.count
    )
    _ = try metal.runRootTransaction(at: 0, acceptedSubsteps: acceptance)
    try metal.commitRootTransaction()
    let gpu = try metal.snapshotCommitted()

    XCTAssertEqual(metal.connectomeHash, connectome.stableHash())
    XCTAssertEqual(metal.projectionEdgeByteCount, MemoryLayout<TissueConnectome.PackedEdge>.stride)
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
    let delayField = try TissueDelayField(
      width: 16,
      height: 16,
      repeating: 4
    )
    let connectome = try TissueConnectome(
      width: 16,
      height: 16,
      projections: [
        TissueProjection(
          sourceIndex: 8 * 16 + 4,
          destinationIndex: 8 * 16 + 12,
          weight: 2,
          delaySteps: 8
        )
      ]
    )
    let events = try TissueEventSchedule.singleStimulus(
      stimulus,
      noiseAmplitude: 0.4
    )
    let randomContext = TissueRandomContext(seed: 91, episodeIdentifier: 6)
    let direct = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      delayField: delayField,
      connectome: connectome,
      eventSchedule: events,
      randomContext: randomContext,
      maxEncodedSubsteps: 12
    )
    let retried = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      delayField: delayField,
      connectome: connectome,
      eventSchedule: events,
      randomContext: randomContext,
      maxEncodedSubsteps: 12
    )

    let directSubmission = try direct.runRootTransaction(at: 0, acceptedSubsteps: [true])
    try direct.commitRootTransaction()
    let retrySubmission = try retried.runRootTransaction(
      at: 0,
      acceptedSubsteps: [false, true]
    )
    try retried.commitRootTransaction()
    XCTAssertEqual(directSubmission.eventCompactionDispatches, 1)
    XCTAssertEqual(retrySubmission.eventCompactionDispatches, 2)
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
    let stimulus = TissueStimulus(startMilliseconds: 0, endMilliseconds: 20)
    let events = try TissueEventSchedule.singleStimulus(
      stimulus,
      noiseAmplitude: 0.35
    )
    let randomContext = TissueRandomContext(seed: 77, episodeIdentifier: 4)
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
      stimulus: stimulus,
      delayField: delayField,
      eventSchedule: events,
      randomContext: randomContext,
      maxEncodedSubsteps: 16
    )
    let runtime = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      delayField: delayField,
      eventSchedule: events,
      randomContext: randomContext,
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
    let events = try TissueEventSchedule.singleStimulus(
      stimulus,
      noiseAmplitude: 0.3
    )
    let randomContext = TissueRandomContext(seed: 123, episodeIdentifier: 8)
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 16,
      height: 16,
      parameters: parameters
    )
    let single = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      eventSchedule: events,
      randomContext: randomContext,
      maxEncodedSubsteps: 32
    )
    let replay = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      eventSchedule: events,
      randomContext: randomContext,
      maxEncodedSubsteps: 32
    )
    let chunked = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: stimulus,
      eventSchedule: events,
      randomContext: randomContext,
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
    XCTAssertEqual(
      try single.snapshotCommittedRegionalState().stableHash(),
      try replay.snapshotCommittedRegionalState().stableHash()
    )
    XCTAssertEqual(
      try single.snapshotCommittedRegionalState().states,
      try chunked.snapshotCommittedRegionalState().states
    )
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

  private func assertRegionalStatesEqual(
    _ metal: RegionalModuleSnapshot,
    cpuStates: [RegionalModuleState],
    schedulerSnapshot: BrainSchedulerSnapshot,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    XCTAssertEqual(
      metal.scheduleFingerprint,
      schedulerSnapshot.scheduleFingerprint,
      file: file,
      line: line
    )
    XCTAssertEqual(metal.committedTime, schedulerSnapshot.committedTime, file: file, line: line)
    XCTAssertEqual(metal.generation, schedulerSnapshot.generation, file: file, line: line)
    XCTAssertEqual(metal.states.count, cpuStates.count, file: file, line: line)
    for (gpu, cpu) in zip(metal.states, cpuStates) {
      XCTAssertEqual(gpu.updateCount, cpu.updateCount, file: file, line: line)
      XCTAssertEqual(gpu.interruptCount, cpu.interruptCount, file: file, line: line)
      XCTAssertEqual(gpu.lastUpdate, cpu.lastUpdate, file: file, line: line)
      XCTAssertEqual(gpu.phase, cpu.phase, accuracy: 1e-6, file: file, line: line)
      XCTAssertEqual(gpu.activation, cpu.activation, accuracy: 2e-6, file: file, line: line)
      XCTAssertEqual(gpu.integration, cpu.integration, accuracy: 2e-6, file: file, line: line)
      XCTAssertEqual(
        gpu.interruptSalience,
        cpu.interruptSalience,
        accuracy: 2e-6,
        file: file,
        line: line
      )
    }
  }
}

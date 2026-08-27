import Metal
import XCTest

@testable import NumiBrainCore
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalTissueRuntimeTests: XCTestCase {
  private let parameters = TissueParameters.corticalSheetV0

  func testMetalRejectsMismatchedImmutableParameterVersionBeforeDispatch() throws {
    try requireMetal4()
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let program = try RegionalTokenProgram.runtimeFoundationV0(schedule: schedule)
    let version = try BrainParameterVersion.runtimeFoundationV0(
      schedule: schedule,
      regionalProgram: program,
      tissueParameters: parameters
    )
    var changedParameters = parameters
    changedParameters.excitatorySelfWeight += 0.25
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 8,
      height: 8,
      parameters: changedParameters
    )
    XCTAssertThrowsError(
      try MetalTissueRuntime(
        initialState: initial,
        parameters: changedParameters,
        stimulus: .none,
        brainSchedule: schedule,
        regionalTokenProgram: program,
        parameterVersion: version,
        maxEncodedSubsteps: 1
      )
    )
  }

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
    let regionalProgram = try RegionalTokenProgram.runtimeFoundationV0(schedule: schedule)
    let parameterVersion = try BrainParameterVersion.runtimeFoundationV0(
      schedule: schedule,
      regionalProgram: regionalProgram,
      tissueParameters: parameters
    )
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
    var cpu = CPUMultiRateScheduler(
      schedule: schedule,
      parameterVersionFingerprint: parameterVersion.fingerprint
    )
    let cpuTransaction = try cpu.beginAdvance(
      to: BrainTimestamp(microseconds: 20_000),
      events: Array(schedulerEvents.reversed())
    )
    try cpu.commit(cpuTransaction)
    let initialRegionalStates = schedule.modules.map { _ in RegionalModuleState() }
    var cpuRegionalTransition = try CPURegionalTokenOperator.advance(
      state: [Float](repeating: 0, count: regionalProgram.scalarCount),
      diagnostics: initialRegionalStates,
      schedule: schedule,
      program: regionalProgram,
      invocations: cpuTransaction.invocations
    )
    var cpuRegionalStates = try CPURegionalModuleOperator.advance(
      states: initialRegionalStates,
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
      regionalTokenProgram: regionalProgram,
      parameterVersion: parameterVersion,
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
    XCTAssertEqual(submission.receptorInterruptTransductionDispatches, 1)
    XCTAssertEqual(submission.schedulerHostInputEventCount, schedulerEvents.count)
    XCTAssertEqual(submission.schedulerReceptorInputEventCount, 0)
    XCTAssertEqual(submission.schedulerInputEventCount, schedulerEvents.count)
    XCTAssertEqual(submission.parameterVersionFingerprint, parameterVersion.fingerprint)
    XCTAssertEqual(metal.parameterVersionBindingByteCount, 64)
    XCTAssertEqual(
      inspection.snapshot.parameterVersionFingerprint,
      parameterVersion.fingerprint
    )
    XCTAssertEqual(metal.schedulerDescriptorByteCount, 8 * 32)
    XCTAssertEqual(metal.schedulerClockByteCount, 8 * 16)
    XCTAssertEqual(metal.schedulerEventCapacityByteCount, 64 * 24)
    XCTAssertEqual(metal.schedulerInvocationCapacityByteCount, 4_096 * 32)
    XCTAssertEqual(metal.regionalStateByteCount, 8 * 32)
    XCTAssertEqual(metal.regionalTokenStateByteCount, 10_752 * 4)
    XCTAssertEqual(metal.regionalRouteByteCount, 7 * 24)
    XCTAssertEqual(metal.regionalParameterByteCount, 10_752 * 32)
    XCTAssertEqual(metal.regionalRouteHistoryStateByteCount, 7 * 16)
    XCTAssertEqual(metal.regionalRouteHistoryTimestampByteCount, 7 * 512 * 8)
    XCTAssertEqual(metal.regionalRouteHistoryValueByteCount, 393_216 * 4)
    XCTAssertEqual(metal.regionalRouteRuntimeStateByteCount, 7 * 32)
    XCTAssertEqual(metal.regionalSelectedRouteIndexByteCount, 7 * 4)
    XCTAssertEqual(metal.regionalSelectedRouteCountByteCount, 8 * 4)
    XCTAssertEqual(inspection.status, 0)
    XCTAssertEqual(inspection.transducedEventCount, schedulerEvents.count)
    XCTAssertEqual(inspection.receptorEventCount, 0)
    XCTAssertEqual(inspection.transductionStatus, 0)
    XCTAssertEqual(inspection.invocations, cpuTransaction.invocations)
    XCTAssertEqual(inspection.snapshot, cpu.snapshot)
    try assertRegionalStatesEqual(
      try metal.snapshotCommittedRegionalState(),
      cpuStates: cpuRegionalStates,
      schedulerSnapshot: cpu.snapshot
    )
    try assertRegionalTokensEqual(
      try metal.snapshotCommittedRegionalTokens(),
      cpuValues: cpuRegionalTransition.values,
      program: regionalProgram,
      schedulerSnapshot: cpu.snapshot
    )
    try assertRegionalRouteHistoryEqual(
      try metal.snapshotCommittedRegionalRouteHistory(),
      cpuHistory: cpuRegionalTransition.routeHistory,
      program: regionalProgram,
      schedulerSnapshot: cpu.snapshot
    )
    try assertRegionalRoutingStateEqual(
      try metal.snapshotCommittedRegionalRoutingState(),
      cpuRoutingState: cpuRegionalTransition.routingState,
      program: regionalProgram,
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
    cpuRegionalTransition = try CPURegionalTokenOperator.advance(
      state: cpuRegionalTransition.values,
      diagnostics: cpuRegionalStates,
      schedule: schedule,
      program: regionalProgram,
      invocations: secondCPUTransaction.invocations,
      routeHistory: cpuRegionalTransition.routeHistory,
      routingState: cpuRegionalTransition.routingState
    )
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
    try assertRegionalTokensEqual(
      try metal.snapshotCommittedRegionalTokens(),
      cpuValues: cpuRegionalTransition.values,
      program: regionalProgram,
      schedulerSnapshot: cpu.snapshot
    )
    try assertRegionalRouteHistoryEqual(
      try metal.snapshotCommittedRegionalRouteHistory(),
      cpuHistory: cpuRegionalTransition.routeHistory,
      program: regionalProgram,
      schedulerSnapshot: cpu.snapshot
    )
    try assertRegionalRoutingStateEqual(
      try metal.snapshotCommittedRegionalRoutingState(),
      cpuRoutingState: cpuRegionalTransition.routingState,
      program: regionalProgram,
      schedulerSnapshot: cpu.snapshot
    )
  }

  func testMetalReceptorOnsetBecomesTransactionalEmergencyInterrupt() throws {
    try requireMetal4()
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let regionalProgram = try RegionalTokenProgram.runtimeFoundationV0(schedule: schedule)
    let parameterVersion = try BrainParameterVersion.runtimeFoundationV0(
      schedule: schedule,
      regionalProgram: regionalProgram,
      tissueParameters: parameters
    )
    let receptorSchedule = try TissueEventSchedule(
      events: [
        TissueReceptorEvent(
          identifier: 41,
          centerX: 0.5,
          centerY: 0.5,
          radius: 0.2,
          excitatoryDrive: 4,
          startMilliseconds: 2,
          endMilliseconds: 8,
          flags: .emergency,
          interruptMask: .pain,
          conductionLatencyMicroseconds: 500,
          receptorIdentifier: 701,
          magnitude: 4
        )
      ]
    )
    let receptorInterrupts = try receptorSchedule.schedulerInterruptEvents(
      committedTime: BrainTimestamp(microseconds: 0),
      targetTime: BrainTimestamp(microseconds: 5_000),
      includeCommittedBoundary: true
    )
    var cpu = CPUMultiRateScheduler(
      schedule: schedule,
      parameterVersionFingerprint: parameterVersion.fingerprint
    )
    let cpuTransaction = try cpu.beginAdvance(
      to: BrainTimestamp(microseconds: 5_000),
      events: receptorInterrupts
    )
    try cpu.commit(cpuTransaction)
    let cpuRegionalStates = try CPURegionalModuleOperator.advance(
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
      eventSchedule: receptorSchedule,
      brainSchedule: schedule,
      regionalTokenProgram: regionalProgram,
      parameterVersion: parameterVersion,
      maxEncodedSubsteps: 8
    )
    let attempts = [true, false, true, true, true, true]
    _ = try metal.runRootTransaction(at: 0, acceptedSubsteps: attempts)
    try metal.abortRootTransaction()
    XCTAssertNil(metal.schedulerCommittedTimestamp)

    let submission = try metal.runRootTransaction(at: 0, acceptedSubsteps: attempts)
    try metal.commitRootTransaction()
    let inspection = try metal.inspectCommittedScheduler()
    XCTAssertEqual(submission.schedulerHostInputEventCount, 0)
    XCTAssertEqual(submission.schedulerReceptorInputEventCount, 1)
    XCTAssertEqual(submission.schedulerInputEventCount, 1)
    XCTAssertEqual(submission.receptorInterruptTransductionDispatches, 1)
    XCTAssertEqual(inspection.transducedEventCount, 1)
    XCTAssertEqual(inspection.receptorEventCount, 1)
    XCTAssertEqual(inspection.invocations, cpuTransaction.invocations)
    XCTAssertEqual(inspection.snapshot, cpu.snapshot)
    XCTAssertTrue(
      inspection.invocations.contains {
        $0.timestamp == BrainTimestamp(microseconds: 2_500)
          && $0.moduleIdentifier == 26
          && $0.reasons.contains(.interrupt)
          && $0.interruptMask == .pain
      }
    )
    try assertRegionalStatesEqual(
      try metal.snapshotCommittedRegionalState(),
      cpuStates: cpuRegionalStates,
      schedulerSnapshot: cpu.snapshot
    )
    let painModules = zip(schedule.modules, cpuRegionalStates)
      .filter { $0.0.interruptMask.contains(.pain) }
    XCTAssertEqual(painModules.map { $0.0.moduleIdentifier }, [12, 26, 95])
    XCTAssertTrue(painModules.allSatisfy { $0.1.interruptCount == 1 })

    let second = try metal.runRootTransaction(
      at: 5,
      acceptedSubsteps: Array(repeating: true, count: 5)
    )
    try metal.commitRootTransaction()
    let secondInspection = try metal.inspectCommittedScheduler()
    XCTAssertEqual(second.schedulerReceptorInputEventCount, 0)
    XCTAssertEqual(secondInspection.receptorEventCount, 0)
    XCTAssertEqual(secondInspection.transducedEventCount, 0)
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
    XCTAssertEqual(
      try direct.snapshotCommittedRegionalTokens(),
      try retried.snapshotCommittedRegionalTokens()
    )
    XCTAssertEqual(
      try direct.snapshotCommittedRegionalRouteHistory(),
      try retried.snapshotCommittedRegionalRouteHistory()
    )
    XCTAssertEqual(
      try direct.snapshotCommittedRegionalRoutingState(),
      try retried.snapshotCommittedRegionalRoutingState()
    )

    let beforeScheduler = try retried.snapshotCommittedScheduler()
    let beforeRegional = try retried.snapshotCommittedRegionalState()
    let beforeRegionalTokens = try retried.snapshotCommittedRegionalTokens()
    let beforeRegionalRouteHistory = try retried.snapshotCommittedRegionalRouteHistory()
    let beforeRegionalRoutingState = try retried.snapshotCommittedRegionalRoutingState()
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
    XCTAssertEqual(try retried.snapshotCommittedRegionalTokens(), beforeRegionalTokens)
    XCTAssertEqual(
      try retried.snapshotCommittedRegionalRouteHistory(),
      beforeRegionalRouteHistory
    )
    XCTAssertEqual(
      try retried.snapshotCommittedRegionalRoutingState(),
      beforeRegionalRoutingState
    )
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
    XCTAssertEqual(
      try direct.snapshotCommittedRegionalTokens(),
      try retried.snapshotCommittedRegionalTokens()
    )
    XCTAssertEqual(
      try direct.snapshotCommittedRegionalRouteHistory(),
      try retried.snapshotCommittedRegionalRouteHistory()
    )
    XCTAssertEqual(
      try direct.snapshotCommittedRegionalRoutingState(),
      try retried.snapshotCommittedRegionalRoutingState()
    )
  }

  func testMetalTopKRoutingIsContentDynamicAndEmergencySafe() throws {
    try requireMetal4()
    let schedule = try BrainModuleSchedule(
      modules: try (1...4).map { identifier in
        try BrainModuleDescriptor(
          moduleIdentifier: UInt16(identifier),
          clockClass: .cortical,
          periodMicroseconds: 1_000,
          intrinsicTimescaleMicroseconds: 4_000,
          tokenCount: 1,
          tokenDimension: 4
        )
      }
    )
    let program = try RegionalTokenProgram(
      schedule: schedule,
      routes: [
        RegionalTokenRoute(senderModuleIdentifier: 1, receiverModuleIdentifier: 4, gain: 1),
        RegionalTokenRoute(senderModuleIdentifier: 2, receiverModuleIdentifier: 4, gain: 1),
        RegionalTokenRoute(
          senderModuleIdentifier: 3,
          receiverModuleIdentifier: 4,
          gain: 1,
          flags: [.emergency, .persistent]
        ),
      ]
    )
    let initialTissue = try CPUTissueDynamics.makeRestingGrid(
      width: 8,
      height: 8,
      parameters: parameters
    )

    func tokenValues(normalWinner: Int) -> [Float] {
      var values = [Float](repeating: 0, count: program.scalarCount)
      for moduleIndex in program.layouts.indices {
        let value: Float
        switch moduleIndex {
        case normalWinner: value = 2
        case 2: value = 0.25
        case 3: value = 1
        default: value = 0.5
        }
        for scalar in program.layouts[moduleIndex].scalarRange {
          values[scalar] = value
        }
      }
      return values
    }

    func cpuOracle(
      initialValues: [Float]
    ) throws -> (BrainSchedulerSnapshot, RegionalTokenTransition) {
      var scheduler = CPUMultiRateScheduler(schedule: schedule)
      let invocations = try scheduler.advance(to: BrainTimestamp(microseconds: 1_000))
      let transition = try CPURegionalTokenOperator.advance(
        state: initialValues,
        diagnostics: schedule.modules.map { _ in RegionalModuleState() },
        schedule: schedule,
        program: program,
        invocations: invocations
      )
      return (scheduler.snapshot, transition)
    }

    for expectedNormalRoute in [0, 1] {
      let initialValues = tokenValues(normalWinner: expectedNormalRoute)
      let runtime = try MetalTissueRuntime(
        initialState: initialTissue,
        parameters: parameters,
        stimulus: .none,
        brainSchedule: schedule,
        regionalTokenProgram: program,
        initialRegionalTokenValues: initialValues,
        maxEncodedSubsteps: 1
      )
      _ = try runtime.runRootTransaction(at: 0, acceptedSubsteps: [true])
      try runtime.commitRootTransaction()

      let (schedulerSnapshot, cpuTransition) = try cpuOracle(initialValues: initialValues)
      let metalRouting = try runtime.snapshotCommittedRegionalRoutingState()
      XCTAssertEqual(
        metalRouting.routingState.states.map(\.isActive),
        expectedNormalRoute == 0 ? [true, false, true] : [false, true, true]
      )
      XCTAssertEqual(
        metalRouting.routingState.states.prefix(2).filter(\.isActive).count,
        1
      )
      XCTAssertTrue(metalRouting.routingState.states[2].isActive)
      XCTAssertEqual(
        metalRouting.routingState.states.map(\.strength).reduce(0, +),
        1,
        accuracy: 3e-6
      )
      try assertRegionalRoutingStateEqual(
        metalRouting,
        cpuRoutingState: cpuTransition.routingState,
        program: program,
        schedulerSnapshot: schedulerSnapshot
      )
      try assertRegionalTokensEqual(
        try runtime.snapshotCommittedRegionalTokens(),
        cpuValues: cpuTransition.values,
        program: program,
        schedulerSnapshot: schedulerSnapshot
      )
    }
  }

  func testMetalRegionalRouteDelayWithholdsMessageUntilConductionTime() throws {
    try requireMetal4()
    let schedule = try BrainModuleSchedule(modules: [
      BrainModuleDescriptor(
        moduleIdentifier: 1,
        clockClass: .cortical,
        periodMicroseconds: 1_000,
        intrinsicTimescaleMicroseconds: 4_000,
        tokenCount: 1,
        tokenDimension: 4
      ),
      BrainModuleDescriptor(
        moduleIdentifier: 2,
        clockClass: .cortical,
        periodMicroseconds: 1_000,
        conductionDelayMicroseconds: 2_000,
        intrinsicTimescaleMicroseconds: 4_000,
        tokenCount: 1,
        tokenDimension: 4
      ),
    ])
    let delayedProgram = try RegionalTokenProgram(
      schedule: schedule,
      routes: [
        RegionalTokenRoute(
          senderModuleIdentifier: 1,
          receiverModuleIdentifier: 2,
          delayMicroseconds: 2_000,
          gain: 1
        )
      ]
    )
    let isolatedProgram = try RegionalTokenProgram(
      schedule: schedule,
      routes: [],
      parameters: delayedProgram.parameters
    )
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 8,
      height: 8,
      parameters: parameters
    )
    let delayed = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      brainSchedule: schedule,
      regionalTokenProgram: delayedProgram,
      maxEncodedSubsteps: 1
    )
    let isolated = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      brainSchedule: schedule,
      regionalTokenProgram: isolatedProgram,
      maxEncodedSubsteps: 1
    )
    var scheduler = CPUMultiRateScheduler(schedule: schedule)
    var cpuDiagnostics = schedule.modules.map { _ in RegionalModuleState() }
    var cpuTransition = RegionalTokenTransition(
      values: [Float](repeating: 0, count: delayedProgram.scalarCount),
      routeHistory: RegionalRouteHistory(program: delayedProgram),
      routingState: RegionalRoutingState(program: delayedProgram)
    )
    let receiverRange = try XCTUnwrap(
      delayedProgram.layouts.first { $0.moduleIdentifier == 2 }
    ).scalarRange

    for targetMilliseconds in [Float(1), Float(2)] {
      let invocations = try scheduler.advance(
        to: BrainTimestamp(microseconds: UInt64(targetMilliseconds * 1_000))
      )
      cpuTransition = try CPURegionalTokenOperator.advance(
        state: cpuTransition.values,
        diagnostics: cpuDiagnostics,
        schedule: schedule,
        program: delayedProgram,
        invocations: invocations,
        routeHistory: cpuTransition.routeHistory,
        routingState: cpuTransition.routingState
      )
      cpuDiagnostics = try CPURegionalModuleOperator.advance(
        states: cpuDiagnostics,
        schedule: schedule,
        invocations: invocations
      )
      let startMilliseconds = targetMilliseconds - 1
      for runtime in [delayed, isolated] {
        _ = try runtime.runRootTransaction(
          at: startMilliseconds,
          acceptedSubsteps: [true]
        )
        try runtime.commitRootTransaction()
      }
      let delayedTokens = try delayed.snapshotCommittedRegionalTokens()
      let isolatedTokens = try isolated.snapshotCommittedRegionalTokens()
      let routeEffect = zip(
        delayedTokens.values[receiverRange],
        isolatedTokens.values[receiverRange]
      ).reduce(Float.zero) { result, pair in
        max(result, abs(pair.0 - pair.1))
      }
      if targetMilliseconds < 2 {
        XCTAssertEqual(routeEffect, 0)
      } else {
        XCTAssertGreaterThan(routeEffect, 1e-5)
      }
      try assertRegionalTokensEqual(
        delayedTokens,
        cpuValues: cpuTransition.values,
        program: delayedProgram,
        schedulerSnapshot: scheduler.snapshot
      )
      try assertRegionalRouteHistoryEqual(
        try delayed.snapshotCommittedRegionalRouteHistory(),
        cpuHistory: cpuTransition.routeHistory,
        program: delayedProgram,
        schedulerSnapshot: scheduler.snapshot
      )
    }
  }

  func testMetalRejectsUnsafeRegionalRouteHistoryBounds() throws {
    try requireMetal4()
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let program = try RegionalTokenProgram.runtimeFoundationV0(schedule: schedule)
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 8,
      height: 8,
      parameters: parameters
    )

    XCTAssertThrowsError(
      try MetalTissueRuntime(
        initialState: initial,
        parameters: parameters,
        stimulus: .none,
        brainSchedule: schedule,
        regionalTokenProgram: program,
        maxSchedulerEvents: 200
      )
    ) { error in
      XCTAssertTrue(String(describing: error).contains("route-history slots"))
    }
  }

  func testMetalSparseRouteChangesOnlyTheCompiledRegionalProgram() throws {
    try requireMetal4()
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let routedProgram = try RegionalTokenProgram.runtimeFoundationV0(schedule: schedule)
    let isolatedProgram = try RegionalTokenProgram(
      schedule: schedule,
      routes: [],
      parameters: routedProgram.parameters
    )
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 8,
      height: 8,
      parameters: parameters
    )
    let routed = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      brainSchedule: schedule,
      regionalTokenProgram: routedProgram,
      maxEncodedSubsteps: 20
    )
    let isolated = try MetalTissueRuntime(
      initialState: initial,
      parameters: parameters,
      stimulus: .none,
      brainSchedule: schedule,
      regionalTokenProgram: isolatedProgram,
      maxEncodedSubsteps: 20
    )
    let pain = try BrainInterruptEvent(
      timestamp: BrainTimestamp(microseconds: 7_500),
      mask: [.pain, .impact],
      identifier: 71
    )
    for runtime in [routed, isolated] {
      _ = try runtime.runRootTransaction(
        at: 0,
        acceptedSubsteps: Array(repeating: true, count: 20),
        schedulerEvents: [pain]
      )
      try runtime.commitRootTransaction()
    }
    let routedTokens = try routed.snapshotCommittedRegionalTokens()
    let isolatedTokens = try isolated.snapshotCommittedRegionalTokens()
    let emergencyBus = try XCTUnwrap(
      routedProgram.layouts.first { $0.moduleIdentifier == 26 }
    )
    let maximumRouteEffect = zip(
      routedTokens.values[emergencyBus.scalarRange],
      isolatedTokens.values[emergencyBus.scalarRange]
    ).reduce(Float.zero) { result, pair in
      max(result, abs(pair.0 - pair.1))
    }

    XCTAssertNotEqual(routedTokens.programFingerprint, isolatedTokens.programFingerprint)
    XCTAssertGreaterThan(maximumRouteEffect, 1e-5)
    XCTAssertEqual(
      try routed.snapshotCommitted().stableHash(),
      try isolated.snapshotCommitted().stableHash()
    )
    XCTAssertEqual(
      try routed.snapshotCommittedRegionalState(),
      try isolated.snapshotCommittedRegionalState()
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
    XCTAssertEqual(
      try single.snapshotCommittedRegionalTokens().stableHash(),
      try replay.snapshotCommittedRegionalTokens().stableHash()
    )
    XCTAssertEqual(
      try single.snapshotCommittedRegionalTokens().values,
      try chunked.snapshotCommittedRegionalTokens().values
    )
    XCTAssertEqual(
      try single.snapshotCommittedRegionalRouteHistory().stableHash(),
      try replay.snapshotCommittedRegionalRouteHistory().stableHash()
    )
    XCTAssertEqual(
      try single.snapshotCommittedRegionalRouteHistory().history,
      try chunked.snapshotCommittedRegionalRouteHistory().history
    )
    XCTAssertEqual(
      try single.snapshotCommittedRegionalRoutingState().stableHash(),
      try replay.snapshotCommittedRegionalRoutingState().stableHash()
    )
    XCTAssertEqual(
      try single.snapshotCommittedRegionalRoutingState().routingState,
      try chunked.snapshotCommittedRegionalRoutingState().routingState
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

  private func assertRegionalTokensEqual(
    _ metal: RegionalTokenSnapshot,
    cpuValues: [Float],
    program: RegionalTokenProgram,
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
    XCTAssertEqual(metal.programFingerprint, program.fingerprint, file: file, line: line)
    XCTAssertEqual(metal.committedTime, schedulerSnapshot.committedTime, file: file, line: line)
    XCTAssertEqual(metal.generation, schedulerSnapshot.generation, file: file, line: line)
    XCTAssertEqual(metal.values.count, cpuValues.count, file: file, line: line)
    let maximumError = zip(metal.values, cpuValues).reduce(Float.zero) { result, pair in
      max(result, abs(pair.0 - pair.1))
    }
    XCTAssertLessThanOrEqual(maximumError, 3e-6, file: file, line: line)
  }

  private func assertRegionalRouteHistoryEqual(
    _ metal: RegionalRouteHistorySnapshot,
    cpuHistory: RegionalRouteHistory,
    program: RegionalTokenProgram,
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
    XCTAssertEqual(metal.programFingerprint, program.fingerprint, file: file, line: line)
    XCTAssertEqual(metal.committedTime, schedulerSnapshot.committedTime, file: file, line: line)
    XCTAssertEqual(metal.generation, schedulerSnapshot.generation, file: file, line: line)
    XCTAssertEqual(metal.history.states, cpuHistory.states, file: file, line: line)
    XCTAssertEqual(metal.history.timestamps, cpuHistory.timestamps, file: file, line: line)
    XCTAssertEqual(metal.history.values.count, cpuHistory.values.count, file: file, line: line)
    let maximumError = zip(metal.history.values, cpuHistory.values).reduce(Float.zero) {
      result, pair in
      max(result, abs(pair.0 - pair.1))
    }
    XCTAssertLessThanOrEqual(maximumError, 3e-6, file: file, line: line)
  }

  private func assertRegionalRoutingStateEqual(
    _ metal: RegionalRoutingSnapshot,
    cpuRoutingState: RegionalRoutingState,
    program: RegionalTokenProgram,
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
    XCTAssertEqual(metal.programFingerprint, program.fingerprint, file: file, line: line)
    XCTAssertEqual(metal.committedTime, schedulerSnapshot.committedTime, file: file, line: line)
    XCTAssertEqual(metal.generation, schedulerSnapshot.generation, file: file, line: line)
    XCTAssertEqual(
      metal.routingState.programFingerprint,
      cpuRoutingState.programFingerprint,
      file: file,
      line: line
    )
    XCTAssertEqual(
      metal.routingState.states.count,
      cpuRoutingState.states.count,
      file: file,
      line: line
    )
    for (gpu, cpu) in zip(metal.routingState.states, cpuRoutingState.states) {
      XCTAssertEqual(gpu.score, cpu.score, accuracy: 3e-6, file: file, line: line)
      XCTAssertEqual(gpu.strength, cpu.strength, accuracy: 3e-6, file: file, line: line)
      XCTAssertEqual(gpu.isActive, cpu.isActive, file: file, line: line)
      XCTAssertEqual(gpu.selectionCount, cpu.selectionCount, file: file, line: line)
      XCTAssertEqual(
        gpu.lastSelectedTimestamp,
        cpu.lastSelectedTimestamp,
        file: file,
        line: line
      )
      XCTAssertEqual(gpu.switchCount, cpu.switchCount, file: file, line: line)
    }
  }
}

import Foundation
@preconcurrency import Metal
import NumiBrainABI
import NumiBrainCore

private struct ProtectiveCommandUniforms {
  var brainGeneration: UInt64 = 0
  var motorProfileFingerprint: UInt64 = 0
  var moduleCount: UInt32 = 0
  var muscleCount: UInt32 = 0
  var environmentIdentifier: UInt32 = 0
  var reserved: UInt32 = 0
}

@available(macOS 26.0, *)
public final class MetalTissueRuntime: @unchecked Sendable {
  public struct Submission: Equatable, Sendable, Codable {
    public let parameterVersionFingerprint: UInt64
    public let attemptedSubsteps: Int
    public let acceptedSubsteps: Int
    public let eventCompactionDispatches: Int
    public let receptorInterruptTransductionDispatches: Int
    public let schedulerDispatches: Int
    public let regionalDispatches: Int
    public let protectiveDispatches: Int
    public let protectiveMotorDispatches: Int
    public let schedulerHostInputEventCount: Int
    public let schedulerReceptorInputEventCount: Int
    public let schedulerInputEventCount: Int
    public let gpuStartSeconds: Double
    public let gpuEndSeconds: Double

    public var gpuDurationSeconds: Double {
      max(gpuEndSeconds - gpuStartSeconds, 0)
    }
  }

  public struct FastSystemResult: Equatable, Sendable {
    public let substep: BrainJointSubstepToken
    public let protectiveCommand: ProtectiveCommandBufferView
    public let protectiveMotorOutput: ProtectiveMotorOutputBufferView
    public let gpuStartSeconds: Double
    public let gpuEndSeconds: Double

    public var gpuDurationSeconds: Double {
      max(gpuEndSeconds - gpuStartSeconds, 0)
    }
  }

  public struct ProtectiveCommandBufferView: Equatable, Sendable {
    public let gpuAddress: UInt64
    public let byteCount: Int
    public let timestamp: BrainTimestamp
    public let brainGeneration: UInt64
  }

  public struct ProtectiveMotorOutputBufferView: Equatable, Sendable {
    public let headerGPUAddress: UInt64
    public let muscleExcitationGPUAddress: UInt64
    public let headerByteCount: Int
    public let muscleExcitationByteCount: Int
    public let muscleCount: Int
    public let timestamp: BrainTimestamp
    public let brainGeneration: UInt64
    public let profileFingerprint: UInt64
  }

  public struct SchedulerInspection: Equatable, Sendable {
    public let snapshot: BrainSchedulerSnapshot
    public let invocations: [BrainModuleInvocation]
    public let status: UInt32
    public let transducedEventCount: Int
    public let receptorEventCount: Int
    public let transductionStatus: UInt32
  }

  public let deviceName: String
  public let width: Int
  public let height: Int
  public let parameters: TissueParameters
  public let stimulus: TissueStimulus
  public let structureHash: String
  public let delayFieldHash: String
  public let connectomeHash: String
  public let eventScheduleHash: String
  public let eventSchedule: TissueEventSchedule
  public let randomContext: TissueRandomContext
  public let brainSchedule: BrainModuleSchedule
  public let regionalTokenProgram: RegionalTokenProgram
  public let parameterVersion: BrainParameterVersion
  public let schedulerEnvironmentIdentifier: UInt32
  public let historyCapacity = TissueDelayField.historyCapacity
  public let maximumTissueDelayMicroseconds: UInt64
  public let maxEncodedSubsteps: Int
  public let maxSchedulerEvents: Int
  public let maxSchedulerInvocations: Int
  public private(set) var committedStep: UInt64 = 0

  private let device: any MTLDevice
  private let commandQueue: any MTL4CommandQueue
  private let commandAllocator: any MTL4CommandAllocator
  private let commandBuffer: any MTL4CommandBuffer
  private let tissuePipeline: any MTLComputePipelineState
  private let eventCompactionPipeline: any MTLComputePipelineState
  private let receptorInterruptTransductionPipeline: any MTLComputePipelineState
  private let schedulerPipeline: any MTLComputePipelineState
  private let regionalPipeline: any MTLComputePipelineState
  private let protectivePipeline: any MTLComputePipelineState
  private let protectiveMotorPipeline: any MTLComputePipelineState
  private let argumentTable: any MTL4ArgumentTable
  private let eventArgumentTable: any MTL4ArgumentTable
  private let receptorInterruptArgumentTable: any MTL4ArgumentTable
  private let schedulerArgumentTable: any MTL4ArgumentTable
  private let regionalArgumentTable: any MTL4ArgumentTable
  private let protectiveArgumentTable: any MTL4ArgumentTable
  private let protectiveMotorArgumentTable: any MTL4ArgumentTable
  private let residencySet: any MTLResidencySet
  private let stateBuffers: [any MTLBuffer]
  private let structureBuffer: any MTLBuffer
  private let delayBuffer: any MTLBuffer
  private let relayHistoryBuffer: any MTLBuffer
  private let relayHistoryTimestampBuffer: any MTLBuffer
  private let relayScratchBuffer: any MTLBuffer
  private let projectionOffsetBuffer: any MTLBuffer
  private let projectionEdgeBuffer: any MTLBuffer
  private let eventBuffer: any MTLBuffer
  private let activeEventIndexBuffer: any MTLBuffer
  private let uniformBuffer: any MTLBuffer
  private let schedulerDescriptorBuffer: any MTLBuffer
  private let schedulerClockBuffers: [any MTLBuffer]
  private let schedulerEventUploadBuffer: any MTLBuffer
  private let transducedSchedulerEventBuffer: any MTLBuffer
  private let receptorEventTransductionUniformBuffer: any MTLBuffer
  private let receptorEventTransductionResultBuffer: any MTLBuffer
  private let schedulerUniformBuffer: any MTLBuffer
  private let schedulerInvocationBuffer: any MTLBuffer
  private let schedulerResultBuffer: any MTLBuffer
  private let parameterVersionBindingBuffer: any MTLBuffer
  private let regionalStateBuffers: [any MTLBuffer]
  private let regionalProgramHeaderBuffer: any MTLBuffer
  private let regionalLayoutBuffer: any MTLBuffer
  private let regionalRouteBuffer: any MTLBuffer
  private let regionalParameterBuffer: any MTLBuffer
  private let regionalTokenStateBuffers: [any MTLBuffer]
  private let regionalTokenCandidateBuffer: any MTLBuffer
  private let regionalRouteHistoryStateBuffers: [any MTLBuffer]
  private let regionalRouteHistoryTimestampBuffers: [any MTLBuffer]
  private let regionalRouteHistoryValueBuffers: [any MTLBuffer]
  private let regionalResolvedRouteHistorySlotBuffer: any MTLBuffer
  private let regionalRouteRuntimeStateBuffers: [any MTLBuffer]
  private let regionalSelectedRouteIndexBuffer: any MTLBuffer
  private let regionalSelectedRouteCountBuffer: any MTLBuffer
  private let protectiveCommandUniformBuffer: any MTLBuffer
  private let protectiveCommandBuffers: [any MTLBuffer]
  private let protectiveMotorProfileBuffer: any MTLBuffer
  private let protectiveMotorOutputHeaderBuffers: [any MTLBuffer]
  private let protectiveMuscleExcitationBuffers: [any MTLBuffer]
  private let stagingBuffer: any MTLBuffer
  private let stateByteCount: Int
  private let relayByteCount: Int
  public let relayHistoryByteCount: Int
  public let relayHistoryTimestampByteCount: Int
  public let projectionOffsetByteCount: Int
  public let projectionEdgeByteCount: Int
  public let eventByteCount: Int
  public let activeEventIndexByteCount: Int
  public let schedulerDescriptorByteCount: Int
  public let schedulerClockByteCount: Int
  public let schedulerEventCapacityByteCount: Int
  public let receptorEventTransductionUniformByteCount: Int
  public let receptorEventTransductionResultByteCount: Int
  public let schedulerInvocationCapacityByteCount: Int
  public let parameterVersionBindingByteCount: Int
  public let regionalStateByteCount: Int
  public let regionalTokenStateByteCount: Int
  public let regionalRouteByteCount: Int
  public let regionalParameterByteCount: Int
  public let regionalRouteHistoryStateByteCount: Int
  public let regionalRouteHistoryTimestampByteCount: Int
  public let regionalRouteHistoryValueByteCount: Int
  public let regionalRouteRuntimeStateByteCount: Int
  public let regionalSelectedRouteIndexByteCount: Int
  public let regionalSelectedRouteCountByteCount: Int
  public let protectiveCommandByteCount = ProtectiveMotorCommand.byteCount
  public let protectiveCommandUniformByteCount = MemoryLayout<ProtectiveCommandUniforms>.stride
  public let protectiveMotorProfile: ProtectiveMotorProfile
  public let protectiveMotorProfileByteCount: Int
  public let protectiveMotorOutputHeaderByteCount = ProtectiveMotorOutput.headerByteCount
  public let protectiveMuscleExcitationByteCount: Int

  private var committedIndex = 0
  private var committedHistoryOwnerMask: UInt32 = 0
  private var committedRelayHistoryTimestamps = [UInt64](
    repeating: 0,
    count: TissueDelayField.historyCapacity
  )
  private var pendingRootShadowIndex: Int?
  private var pendingRootShadowOwnerMask: UInt32?
  private var pendingRootShadowStep: UInt64?
  private var pendingRelayHistoryTimestamps: [UInt64]?
  private var committedSchedulerClockIndex = 0
  private var committedSchedulerTime: BrainTimestamp?
  private var committedSchedulerGeneration: UInt64 = 0
  private var committedRegionalStateIndex = 0
  private var pendingSchedulerClockIndex: Int?
  private var pendingSchedulerTargetTime: BrainTimestamp?
  private var pendingRegionalStateIndex: Int?
  private var pendingSchedulerInitialized = false
  private var hasCommittedSchedulerResult = false
  private var pendingJointTransaction: BrainJointTransaction?

  private struct InteractiveCandidate {
    let substep: BrainJointSubstepToken
    let destinationIndex: Int
    let historyWriteSlot: Int
    let historyWritePlane: UInt32
  }

  private struct InteractiveJointRoot {
    var transaction: BrainJointTransaction
    var rootShadowIndex: Int
    var historyOwnerMask: UInt32
    var historyStep: UInt64
    var relayHistoryTimestamps: [UInt64]
    var acceptedTimestamp: BrainTimestamp
    var candidate: InteractiveCandidate?
    var fastSchedulerWindow: PreparedSchedulerWindow?
    var firstGPUStartSeconds: Double?
    var lastGPUEndSeconds: Double?
  }

  private var interactiveJointRoot: InteractiveJointRoot?

  public init(
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus,
    structure requestedStructure: TissueStructure? = nil,
    delayField requestedDelayField: TissueDelayField? = nil,
    connectome requestedConnectome: TissueConnectome? = nil,
    eventSchedule requestedEventSchedule: TissueEventSchedule? = nil,
    randomContext: TissueRandomContext = .deterministicDefault,
    brainSchedule requestedBrainSchedule: BrainModuleSchedule? = nil,
    regionalTokenProgram requestedRegionalTokenProgram: RegionalTokenProgram? = nil,
    parameterVersion requestedParameterVersion: BrainParameterVersion? = nil,
    initialRegionalTokenValues requestedInitialRegionalTokenValues: [Float]? = nil,
    initialRegionalRoutingState requestedInitialRegionalRoutingState: RegionalRoutingState? = nil,
    protectiveMotorProfile requestedProtectiveMotorProfile: ProtectiveMotorProfile? = nil,
    schedulerEnvironmentIdentifier: UInt32 = 0,
    maxSchedulerEvents: Int = 64,
    maxSchedulerInvocations: Int = 4_096,
    maxEncodedSubsteps: Int = 4_096,
    device requestedDevice: (any MTLDevice)? = nil
  ) throws {
    try parameters.validate()
    try stimulus.validate()
    let structure: TissueStructure
    if let requestedStructure {
      structure = requestedStructure
    } else {
      structure = try TissueStructure.homogeneous(
        width: initialState.width,
        height: initialState.height
      )
    }
    try structure.validate()
    guard structure.width == initialState.width, structure.height == initialState.height else {
      throw TissueError.invalidStructure("structure dimensions must match the initial state")
    }
    let delayField: TissueDelayField
    if let requestedDelayField {
      delayField = requestedDelayField
    } else {
      delayField = try TissueDelayField.instantaneous(
        width: initialState.width,
        height: initialState.height
      )
    }
    try delayField.validate()
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
    let brainSchedule =
      try requestedBrainSchedule
      ?? ReferenceBrainSchedule.runtimeFoundationSubset()
    let regionalTokenProgram =
      try requestedRegionalTokenProgram
      ?? RegionalTokenProgram.runtimeFoundationV0(schedule: brainSchedule)
    guard regionalTokenProgram.scheduleFingerprint == brainSchedule.fingerprint else {
      throw TissueError.metal("regional token program does not match the brain schedule")
    }
    let parameterVersion =
      try requestedParameterVersion
      ?? BrainParameterVersion.runtimeFoundationV0(
        schedule: brainSchedule,
        regionalProgram: regionalTokenProgram,
        tissueParameters: parameters
      )
    guard parameterVersion.scheduleFingerprint == brainSchedule.fingerprint,
      parameterVersion.regionalShapeFingerprint == regionalTokenProgram.shapeFingerprint,
      parameterVersion.regionalProgramFingerprint == regionalTokenProgram.fingerprint,
      parameterVersion.components.first(where: { $0.kind == .tissueDynamics })?
        .contentFingerprint == parameters.parameterFingerprint,
      parameterVersion.components.first(where: { $0.kind == .regionalOperator })?
        .contentFingerprint == regionalTokenProgram.fingerprint
    else {
      throw TissueError.metal(
        "parameter version does not match tissue, schedule, or regional program"
      )
    }
    var parameterBindingValidationRecord = parameterVersion.abiBinding
    let parameterComponentValidationRecords = parameterVersion.components.map(\.abiRecord)
    let parameterValidation = parameterComponentValidationRecords.withUnsafeBufferPointer {
      components in
      withUnsafePointer(to: &parameterBindingValidationRecord) { binding in
        nb_brain_abi_validate_parameter_version(binding, components.baseAddress)
      }
    }
    guard parameterValidation == UInt32(NB_PARAMETER_VERSION_VALID.rawValue) else {
      throw TissueError.metal(
        "compiled parameter manifest validation failed with code \(parameterValidation)"
      )
    }
    let initialRegionalTokenValues =
      requestedInitialRegionalTokenValues
      ?? [Float](repeating: 0, count: regionalTokenProgram.scalarCount)
    guard initialRegionalTokenValues.count == regionalTokenProgram.scalarCount,
      initialRegionalTokenValues.allSatisfy(\.isFinite)
    else {
      throw TissueError.metal("initial regional token values do not match the program")
    }
    let initialRegionalRoutingState =
      requestedInitialRegionalRoutingState
      ?? RegionalRoutingState(program: regionalTokenProgram)
    do {
      try initialRegionalRoutingState.validate(program: regionalTokenProgram)
    } catch {
      throw TissueError.metal("initial regional routing state is invalid: \(error)")
    }
    let protectiveMotorProfile =
      try requestedProtectiveMotorProfile
      ?? ProtectiveMotorProfile.runtimeFoundationFixture()
    guard maxEncodedSubsteps > 0 else {
      throw TissueError.metal("maxEncodedSubsteps must be positive")
    }
    guard maxSchedulerEvents > 0, maxSchedulerEvents <= 65_536 else {
      throw TissueError.metal("maxSchedulerEvents must be in 1...65536")
    }
    guard maxSchedulerInvocations > 0, maxSchedulerInvocations <= Int(UInt32.max) else {
      throw TissueError.metal("maxSchedulerInvocations must be in 1...UInt32.max")
    }
    let timestepMicrosecondsDouble = Double(parameters.timestepMilliseconds) * 1_000
    let roundedTimestepMicroseconds = timestepMicrosecondsDouble.rounded()
    guard roundedTimestepMicroseconds >= 1,
      roundedTimestepMicroseconds < Double(UInt64.max),
      abs(timestepMicrosecondsDouble - roundedTimestepMicroseconds) <= 0.01
    else {
      throw TissueError.metal(
        "timestepMilliseconds must map to positive integer microseconds for route history"
      )
    }
    let timestepMicroseconds = UInt64(roundedTimestepMicroseconds)
    let maximumTissueDelaySteps = max(
      delayField.maximumConfiguredDelaySteps,
      connectome.maximumProjectionDelaySteps
    )
    let (maximumTissueDelayMicroseconds, tissueDelayOverflow) = UInt64(
      maximumTissueDelaySteps
    ).multipliedReportingOverflow(by: timestepMicroseconds)
    guard !tissueDelayOverflow else {
      throw TissueError.metal("physical tissue delay overflows UInt64")
    }
    let maximumRouteDelay = UInt64(
      regionalTokenProgram.routes.map(\.delayMicroseconds).max() ?? 0
    )
    let delayWindows =
      maximumRouteDelay == 0
      ? UInt64(1)
      : (maximumRouteDelay + timestepMicroseconds - 1) / timestepMicroseconds + 1
    let (historyPublicationsPerWindow, historyPublicationOverflow) =
      UInt64(maxSchedulerEvents + 2).multipliedReportingOverflow(by: delayWindows)
    let (requiredRouteHistoryCapacity, historyCapacityOverflow) =
      historyPublicationsPerWindow.addingReportingOverflow(1)
    guard !historyPublicationOverflow, !historyCapacityOverflow,
      requiredRouteHistoryCapacity <= UInt64(regionalTokenProgram.compiledRouteHistoryCapacity)
    else {
      throw TissueError.metal(
        "scheduler/event bounds require \(requiredRouteHistoryCapacity) regional route-history slots; capacity is \(regionalTokenProgram.compiledRouteHistoryCapacity)"
      )
    }
    guard let device = requestedDevice ?? MTLCreateSystemDefaultDevice() else {
      throw TissueError.metal("no Metal device is available")
    }
    guard let commandQueue = device.makeMTL4CommandQueue() else {
      throw TissueError.metal("device does not provide a Metal 4 command queue")
    }
    guard let commandAllocator = device.makeCommandAllocator() else {
      throw TissueError.metal("failed to create a Metal 4 command allocator")
    }
    guard let commandBuffer = device.makeCommandBuffer() else {
      throw TissueError.metal("failed to create a reusable Metal 4 command buffer")
    }

    let sourceURL =
      Bundle.module.url(
        forResource: "NeuralTissue",
        withExtension: "metal",
        subdirectory: "Shaders"
      ) ?? Bundle.module.url(forResource: "NeuralTissue", withExtension: "metal")
    guard let sourceURL else {
      throw TissueError.metal("NeuralTissue.metal is missing from package resources")
    }
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    let compileOptions = MTLCompileOptions()
    compileOptions.languageVersion = .version4_0
    compileOptions.mathMode = .safe
    compileOptions.mathFloatingPointFunctions = .precise
    let library: any MTLLibrary
    do {
      library = try device.makeLibrary(source: source, options: compileOptions)
    } catch {
      throw TissueError.metal("Metal 4 library compilation failed: \(error)")
    }
    guard let tissueFunction = library.makeFunction(name: "neural_tissue_step") else {
      throw TissueError.metal("neural_tissue_step is missing from the Metal library")
    }
    guard let eventCompactionFunction = library.makeFunction(name: "compact_receptor_events") else {
      throw TissueError.metal("compact_receptor_events is missing from the Metal library")
    }
    guard
      let receptorInterruptTransductionFunction = library.makeFunction(
        name: "transduce_receptor_interrupts"
      )
    else {
      throw TissueError.metal("transduce_receptor_interrupts is missing from the Metal library")
    }
    guard let schedulerFunction = library.makeFunction(name: "schedule_due_modules") else {
      throw TissueError.metal("schedule_due_modules is missing from the Metal library")
    }
    guard let regionalFunction = library.makeFunction(name: "advance_due_regional_tokens") else {
      throw TissueError.metal("advance_due_regional_tokens is missing from the Metal library")
    }
    guard let protectiveFunction = library.makeFunction(name: "derive_protective_command") else {
      throw TissueError.metal("derive_protective_command is missing from the Metal library")
    }
    guard
      let protectiveMotorFunction = library.makeFunction(name: "map_protective_motor_output")
    else {
      throw TissueError.metal("map_protective_motor_output is missing from the Metal library")
    }
    let tissuePipeline: any MTLComputePipelineState
    let eventCompactionPipeline: any MTLComputePipelineState
    let receptorInterruptTransductionPipeline: any MTLComputePipelineState
    let schedulerPipeline: any MTLComputePipelineState
    let regionalPipeline: any MTLComputePipelineState
    let protectivePipeline: any MTLComputePipelineState
    let protectiveMotorPipeline: any MTLComputePipelineState
    do {
      tissuePipeline = try device.makeComputePipelineState(function: tissueFunction)
      eventCompactionPipeline = try device.makeComputePipelineState(
        function: eventCompactionFunction
      )
      receptorInterruptTransductionPipeline = try device.makeComputePipelineState(
        function: receptorInterruptTransductionFunction
      )
      schedulerPipeline = try device.makeComputePipelineState(function: schedulerFunction)
      regionalPipeline = try device.makeComputePipelineState(function: regionalFunction)
      protectivePipeline = try device.makeComputePipelineState(function: protectiveFunction)
      protectiveMotorPipeline = try device.makeComputePipelineState(
        function: protectiveMotorFunction
      )
    } catch {
      throw TissueError.metal(
        "tissue, event/transduction, scheduler, or regional pipeline creation failed: \(error)"
      )
    }

    let argumentDescriptor = MTL4ArgumentTableDescriptor()
    argumentDescriptor.label = "NumiBrain tissue arguments"
    argumentDescriptor.maxBufferBindCount = 12
    argumentDescriptor.initializeBindings = true
    guard let argumentTable = try? device.makeArgumentTable(descriptor: argumentDescriptor) else {
      throw TissueError.metal("failed to create the Metal 4 argument table")
    }
    let eventArgumentDescriptor = MTL4ArgumentTableDescriptor()
    eventArgumentDescriptor.label = "NumiBrain event-compaction arguments"
    eventArgumentDescriptor.maxBufferBindCount = 3
    eventArgumentDescriptor.initializeBindings = true
    guard
      let eventArgumentTable = try? device.makeArgumentTable(
        descriptor: eventArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the event-compaction argument table")
    }
    let receptorInterruptArgumentDescriptor = MTL4ArgumentTableDescriptor()
    receptorInterruptArgumentDescriptor.label = "NumiBrain receptor-interrupt arguments"
    receptorInterruptArgumentDescriptor.maxBufferBindCount = 5
    receptorInterruptArgumentDescriptor.initializeBindings = true
    guard
      let receptorInterruptArgumentTable = try? device.makeArgumentTable(
        descriptor: receptorInterruptArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the receptor-interrupt argument table")
    }
    let schedulerArgumentDescriptor = MTL4ArgumentTableDescriptor()
    schedulerArgumentDescriptor.label = "NumiBrain scheduler arguments"
    schedulerArgumentDescriptor.maxBufferBindCount = 9
    schedulerArgumentDescriptor.initializeBindings = true
    guard
      let schedulerArgumentTable = try? device.makeArgumentTable(
        descriptor: schedulerArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the scheduler argument table")
    }
    let regionalArgumentDescriptor = MTL4ArgumentTableDescriptor()
    regionalArgumentDescriptor.label = "NumiBrain regional-token arguments"
    regionalArgumentDescriptor.maxBufferBindCount = 24
    regionalArgumentDescriptor.initializeBindings = true
    guard
      let regionalArgumentTable = try? device.makeArgumentTable(
        descriptor: regionalArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the regional-state argument table")
    }
    let protectiveArgumentDescriptor = MTL4ArgumentTableDescriptor()
    protectiveArgumentDescriptor.label = "NumiBrain protective-command arguments"
    protectiveArgumentDescriptor.maxBufferBindCount = 6
    protectiveArgumentDescriptor.initializeBindings = true
    guard
      let protectiveArgumentTable = try? device.makeArgumentTable(
        descriptor: protectiveArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the protective-command argument table")
    }
    let protectiveMotorArgumentDescriptor = MTL4ArgumentTableDescriptor()
    protectiveMotorArgumentDescriptor.label = "NumiBrain protective-motor arguments"
    protectiveMotorArgumentDescriptor.maxBufferBindCount = 5
    protectiveMotorArgumentDescriptor.initializeBindings = true
    guard
      let protectiveMotorArgumentTable = try? device.makeArgumentTable(
        descriptor: protectiveMotorArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the protective-motor argument table")
    }

    let stateByteCount = initialState.count * MemoryLayout<TissueCell>.stride
    let stateBuffers: [any MTLBuffer] = try (0..<3).map { index in
      guard
        let buffer = device.makeBuffer(
          length: stateByteCount,
          options: [.storageModePrivate, .hazardTrackingModeTracked]
        )
      else {
        throw TissueError.metal("failed to allocate state generation \(index)")
      }
      buffer.label = "NumiBrain tissue state generation \(index)"
      return buffer
    }
    guard
      let structureBuffer = device.makeBuffer(
        length: stateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate the tissue structure field")
    }
    structureBuffer.label = "NumiBrain immutable tissue structure"
    let relayByteCount = initialState.count * MemoryLayout<Float>.stride
    let (historyPlaneByteCount, historyPlaneOverflow) = relayByteCount.multipliedReportingOverflow(
      by: TissueDelayField.historyCapacity
    )
    let (relayHistoryByteCount, relayHistoryOverflow) =
      historyPlaneByteCount
      .multipliedReportingOverflow(by: 2)
    let relayHistoryTimestampByteCount =
      2 * TissueDelayField.historyCapacity
      * MemoryLayout<UInt64>.stride
    guard !historyPlaneOverflow, !relayHistoryOverflow else {
      throw TissueError.metal("relay history byte count overflows Int")
    }
    guard
      let delayBuffer = device.makeBuffer(
        length: delayField.count * MemoryLayout<UInt8>.stride,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let relayHistoryBuffer = device.makeBuffer(
        length: relayHistoryByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let relayHistoryTimestampBuffer = device.makeBuffer(
        length: relayHistoryTimestampByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let relayScratchBuffer = device.makeBuffer(
        length: relayByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate private conduction history buffers")
    }
    delayBuffer.label = "NumiBrain immutable conduction delays"
    relayHistoryBuffer.label = "NumiBrain transactional relay history"
    relayHistoryTimestampBuffer.label = "NumiBrain physical relay-history timestamps"
    relayScratchBuffer.label = "NumiBrain rejected relay scratch"
    let packedProjectionEdges = connectome.packedEdges()
    let projectionOffsetByteCount =
      connectome.destinationOffsets.count
      * MemoryLayout<UInt32>.stride
    let projectionEdgeByteCount =
      packedProjectionEdges.count
      * MemoryLayout<TissueConnectome.PackedEdge>.stride
    guard
      let projectionOffsetBuffer = device.makeBuffer(
        length: projectionOffsetByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let projectionEdgeBuffer = device.makeBuffer(
        length: max(projectionEdgeByteCount, MemoryLayout<TissueConnectome.PackedEdge>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate private sparse projection buffers")
    }
    projectionOffsetBuffer.label = "NumiBrain projection CSR offsets"
    projectionEdgeBuffer.label = "NumiBrain packed delayed projections"
    let packedEvents = eventSchedule.packedRecords()
    let eventByteCount = eventSchedule.packedByteCount
    let activeEventIndexByteCount = eventSchedule.activeIndexByteCapacity
    guard
      let eventBuffer = device.makeBuffer(
        length: max(eventByteCount, MemoryLayout<NBReceptorEvent>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let activeEventIndexBuffer = device.makeBuffer(
        length: activeEventIndexByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate private receptor-event buffers")
    }
    eventBuffer.label = "NumiBrain immutable receptor-event schedule"
    activeEventIndexBuffer.label = "NumiBrain compacted active-event indices"
    guard
      MemoryLayout<NBModuleDescriptor>.stride == Int(NB_MODULE_DESCRIPTOR_BYTE_COUNT),
      MemoryLayout<NBModuleClockState>.stride == Int(NB_MODULE_CLOCK_STATE_BYTE_COUNT),
      MemoryLayout<NBReceptorEvent>.stride == Int(NB_RECEPTOR_EVENT_BYTE_COUNT),
      MemoryLayout<NBInterruptEvent>.stride == Int(NB_INTERRUPT_EVENT_BYTE_COUNT),
      MemoryLayout<NBReceptorEventTransductionUniforms>.stride
        == Int(NB_RECEPTOR_EVENT_TRANSDUCTION_UNIFORMS_BYTE_COUNT),
      MemoryLayout<NBReceptorEventTransductionResult>.stride
        == Int(NB_RECEPTOR_EVENT_TRANSDUCTION_RESULT_BYTE_COUNT),
      MemoryLayout<NBDueInvocation>.stride == Int(NB_DUE_INVOCATION_BYTE_COUNT),
      MemoryLayout<NBSchedulerUniforms>.stride == Int(NB_SCHEDULER_UNIFORMS_BYTE_COUNT),
      MemoryLayout<NBSchedulerResult>.stride == Int(NB_SCHEDULER_RESULT_BYTE_COUNT),
      MemoryLayout<NBRegionalModuleState>.stride == Int(NB_REGIONAL_MODULE_STATE_BYTE_COUNT),
      MemoryLayout<NBRegionalTokenLayout>.stride == Int(NB_REGIONAL_TOKEN_LAYOUT_BYTE_COUNT),
      MemoryLayout<NBRegionalRoute>.stride == Int(NB_REGIONAL_ROUTE_BYTE_COUNT),
      MemoryLayout<NBRegionalTokenParameters>.stride
        == Int(NB_REGIONAL_TOKEN_PARAMETERS_BYTE_COUNT),
      MemoryLayout<NBRegionalProgramHeader>.stride
        == Int(NB_REGIONAL_PROGRAM_HEADER_BYTE_COUNT),
      MemoryLayout<NBRegionalRouteHistoryState>.stride
        == Int(NB_REGIONAL_ROUTE_HISTORY_STATE_BYTE_COUNT),
      MemoryLayout<NBRegionalRouteRuntimeState>.stride
        == Int(NB_REGIONAL_ROUTE_RUNTIME_STATE_BYTE_COUNT),
      MemoryLayout<NBParameterComponent>.stride == Int(NB_PARAMETER_COMPONENT_BYTE_COUNT),
      MemoryLayout<NBParameterVersionBinding>.stride
        == Int(NB_PARAMETER_VERSION_BINDING_BYTE_COUNT),
      MemoryLayout<NBMotorChannelDescriptor>.stride
        == Int(NB_MOTOR_CHANNEL_DESCRIPTOR_BYTE_COUNT),
      MemoryLayout<NBMotorOutputHeader>.stride == Int(NB_MOTOR_OUTPUT_HEADER_BYTE_COUNT)
    else {
      throw TissueError.metal("Swift imported scheduler ABI does not match NumiBrainABI")
    }
    let schedulerDescriptorByteCount =
      brainSchedule.modules.count
      * MemoryLayout<NBModuleDescriptor>.stride
    let schedulerClockByteCount =
      brainSchedule.modules.count
      * MemoryLayout<NBModuleClockState>.stride
    let schedulerEventCapacityByteCount =
      maxSchedulerEvents
      * MemoryLayout<NBInterruptEvent>.stride
    let schedulerInvocationCapacityByteCount =
      maxSchedulerInvocations
      * MemoryLayout<NBDueInvocation>.stride
    let regionalStateByteCount =
      brainSchedule.modules.count
      * MemoryLayout<NBRegionalModuleState>.stride
    let regionalLayoutByteCount =
      regionalTokenProgram.layouts.count
      * MemoryLayout<NBRegionalTokenLayout>.stride
    let regionalRouteByteCount =
      regionalTokenProgram.routes.count
      * MemoryLayout<NBRegionalRoute>.stride
    let regionalParameterByteCount =
      regionalTokenProgram.parameters.count
      * MemoryLayout<NBRegionalTokenParameters>.stride
    let regionalTokenStateByteCount =
      regionalTokenProgram.scalarCount * MemoryLayout<Float>.stride
    let regionalRouteHistoryStateByteCount =
      regionalTokenProgram.routes.count
      * MemoryLayout<NBRegionalRouteHistoryState>.stride
    let regionalRouteHistoryTimestampByteCount =
      regionalTokenProgram.routes.count
      * regionalTokenProgram.compiledRouteHistoryCapacity
      * MemoryLayout<UInt64>.stride
    let regionalRouteHistoryValueByteCount =
      regionalTokenProgram.routeHistoryScalarCount * MemoryLayout<Float>.stride
    let regionalResolvedRouteHistorySlotByteCount =
      regionalTokenProgram.routes.count * MemoryLayout<UInt32>.stride
    let regionalRouteRuntimeStateByteCount =
      regionalTokenProgram.routes.count
      * MemoryLayout<NBRegionalRouteRuntimeState>.stride
    let regionalSelectedRouteIndexByteCount =
      regionalTokenProgram.routes.count * MemoryLayout<UInt32>.stride
    let regionalSelectedRouteCountByteCount =
      regionalTokenProgram.layouts.count * MemoryLayout<UInt32>.stride
    let (protectiveMotorProfileByteCount, protectiveProfileByteOverflow) =
      protectiveMotorProfile.channels.count.multipliedReportingOverflow(
        by: MemoryLayout<NBMotorChannelDescriptor>.stride
      )
    let (protectiveMuscleExcitationByteCount, protectiveExcitationByteOverflow) =
      protectiveMotorProfile.channels.count.multipliedReportingOverflow(
        by: MemoryLayout<Float>.stride
      )
    guard !protectiveProfileByteOverflow, !protectiveExcitationByteOverflow else {
      throw TissueError.metal("protective motor profile byte count overflows Int")
    }
    guard
      let schedulerDescriptorBuffer = device.makeBuffer(
        length: schedulerDescriptorByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstSchedulerClockBuffer = device.makeBuffer(
        length: schedulerClockByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondSchedulerClockBuffer = device.makeBuffer(
        length: schedulerClockByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let schedulerEventUploadBuffer = device.makeBuffer(
        length: schedulerEventCapacityByteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let transducedSchedulerEventBuffer = device.makeBuffer(
        length: schedulerEventCapacityByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let receptorEventTransductionUniformBuffer = device.makeBuffer(
        length: MemoryLayout<NBReceptorEventTransductionUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let receptorEventTransductionResultBuffer = device.makeBuffer(
        length: MemoryLayout<NBReceptorEventTransductionResult>.stride,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let schedulerUniformBuffer = device.makeBuffer(
        length: MemoryLayout<NBSchedulerUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let schedulerInvocationBuffer = device.makeBuffer(
        length: schedulerInvocationCapacityByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let schedulerResultBuffer = device.makeBuffer(
        length: MemoryLayout<NBSchedulerResult>.stride,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let parameterVersionBindingBuffer = device.makeBuffer(
        length: MemoryLayout<NBParameterVersionBinding>.stride,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstRegionalStateBuffer = device.makeBuffer(
        length: regionalStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondRegionalStateBuffer = device.makeBuffer(
        length: regionalStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalProgramHeaderBuffer = device.makeBuffer(
        length: MemoryLayout<NBRegionalProgramHeader>.stride,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalLayoutBuffer = device.makeBuffer(
        length: regionalLayoutByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalRouteBuffer = device.makeBuffer(
        length: max(regionalRouteByteCount, MemoryLayout<NBRegionalRoute>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalParameterBuffer = device.makeBuffer(
        length: regionalParameterByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstRegionalTokenStateBuffer = device.makeBuffer(
        length: regionalTokenStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondRegionalTokenStateBuffer = device.makeBuffer(
        length: regionalTokenStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalTokenCandidateBuffer = device.makeBuffer(
        length: regionalTokenStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstRegionalRouteHistoryStateBuffer = device.makeBuffer(
        length: max(
          regionalRouteHistoryStateByteCount,
          MemoryLayout<NBRegionalRouteHistoryState>.stride
        ),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondRegionalRouteHistoryStateBuffer = device.makeBuffer(
        length: max(
          regionalRouteHistoryStateByteCount,
          MemoryLayout<NBRegionalRouteHistoryState>.stride
        ),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstRegionalRouteHistoryTimestampBuffer = device.makeBuffer(
        length: max(regionalRouteHistoryTimestampByteCount, MemoryLayout<UInt64>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondRegionalRouteHistoryTimestampBuffer = device.makeBuffer(
        length: max(regionalRouteHistoryTimestampByteCount, MemoryLayout<UInt64>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstRegionalRouteHistoryValueBuffer = device.makeBuffer(
        length: max(regionalRouteHistoryValueByteCount, MemoryLayout<Float>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondRegionalRouteHistoryValueBuffer = device.makeBuffer(
        length: max(regionalRouteHistoryValueByteCount, MemoryLayout<Float>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalResolvedRouteHistorySlotBuffer = device.makeBuffer(
        length: max(regionalResolvedRouteHistorySlotByteCount, MemoryLayout<UInt32>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstRegionalRouteRuntimeStateBuffer = device.makeBuffer(
        length: max(
          regionalRouteRuntimeStateByteCount,
          MemoryLayout<NBRegionalRouteRuntimeState>.stride
        ),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondRegionalRouteRuntimeStateBuffer = device.makeBuffer(
        length: max(
          regionalRouteRuntimeStateByteCount,
          MemoryLayout<NBRegionalRouteRuntimeState>.stride
        ),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalSelectedRouteIndexBuffer = device.makeBuffer(
        length: max(regionalSelectedRouteIndexByteCount, MemoryLayout<UInt32>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalSelectedRouteCountBuffer = device.makeBuffer(
        length: max(regionalSelectedRouteCountByteCount, MemoryLayout<UInt32>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let protectiveCommandUniformBuffer = device.makeBuffer(
        length: MemoryLayout<ProtectiveCommandUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let firstProtectiveCommandBuffer = device.makeBuffer(
        length: ProtectiveMotorCommand.byteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondProtectiveCommandBuffer = device.makeBuffer(
        length: ProtectiveMotorCommand.byteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let protectiveMotorProfileBuffer = device.makeBuffer(
        length: protectiveMotorProfileByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstProtectiveMotorOutputHeaderBuffer = device.makeBuffer(
        length: ProtectiveMotorOutput.headerByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondProtectiveMotorOutputHeaderBuffer = device.makeBuffer(
        length: ProtectiveMotorOutput.headerByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstProtectiveMuscleExcitationBuffer = device.makeBuffer(
        length: protectiveMuscleExcitationByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondProtectiveMuscleExcitationBuffer = device.makeBuffer(
        length: protectiveMuscleExcitationByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate scheduler ABI buffers")
    }
    let schedulerClockBuffers: [any MTLBuffer] = [
      firstSchedulerClockBuffer,
      secondSchedulerClockBuffer,
    ]
    let regionalStateBuffers: [any MTLBuffer] = [
      firstRegionalStateBuffer,
      secondRegionalStateBuffer,
    ]
    let regionalTokenStateBuffers: [any MTLBuffer] = [
      firstRegionalTokenStateBuffer,
      secondRegionalTokenStateBuffer,
    ]
    let regionalRouteHistoryStateBuffers: [any MTLBuffer] = [
      firstRegionalRouteHistoryStateBuffer,
      secondRegionalRouteHistoryStateBuffer,
    ]
    let regionalRouteHistoryTimestampBuffers: [any MTLBuffer] = [
      firstRegionalRouteHistoryTimestampBuffer,
      secondRegionalRouteHistoryTimestampBuffer,
    ]
    let regionalRouteHistoryValueBuffers: [any MTLBuffer] = [
      firstRegionalRouteHistoryValueBuffer,
      secondRegionalRouteHistoryValueBuffer,
    ]
    let regionalRouteRuntimeStateBuffers: [any MTLBuffer] = [
      firstRegionalRouteRuntimeStateBuffer,
      secondRegionalRouteRuntimeStateBuffer,
    ]
    let protectiveCommandBuffers: [any MTLBuffer] = [
      firstProtectiveCommandBuffer,
      secondProtectiveCommandBuffer,
    ]
    let protectiveMotorOutputHeaderBuffers: [any MTLBuffer] = [
      firstProtectiveMotorOutputHeaderBuffer,
      secondProtectiveMotorOutputHeaderBuffer,
    ]
    let protectiveMuscleExcitationBuffers: [any MTLBuffer] = [
      firstProtectiveMuscleExcitationBuffer,
      secondProtectiveMuscleExcitationBuffer,
    ]
    schedulerDescriptorBuffer.label = "NumiBrain immutable module descriptors"
    firstSchedulerClockBuffer.label = "NumiBrain scheduler clock generation 0"
    secondSchedulerClockBuffer.label = "NumiBrain scheduler clock generation 1"
    schedulerEventUploadBuffer.label = "NumiBrain committed scheduler event upload"
    schedulerUniformBuffer.label = "NumiBrain scheduler uniforms"
    schedulerInvocationBuffer.label = "NumiBrain compacted due-module invocations"
    schedulerResultBuffer.label = "NumiBrain scheduler result"
    parameterVersionBindingBuffer.label = "NumiBrain immutable parameter-version binding"
    firstRegionalStateBuffer.label = "NumiBrain regional state generation 0"
    secondRegionalStateBuffer.label = "NumiBrain regional state generation 1"
    regionalProgramHeaderBuffer.label = "NumiBrain immutable regional program header"
    regionalLayoutBuffer.label = "NumiBrain immutable region-major token layouts"
    regionalRouteBuffer.label = "NumiBrain immutable sparse regional routes"
    regionalParameterBuffer.label = "NumiBrain immutable regional slow parameters"
    firstRegionalTokenStateBuffer.label = "NumiBrain regional token state generation 0"
    secondRegionalTokenStateBuffer.label = "NumiBrain regional token state generation 1"
    regionalTokenCandidateBuffer.label = "NumiBrain regional token timestamp candidates"
    firstRegionalRouteHistoryStateBuffer.label =
      "NumiBrain regional route-history metadata generation 0"
    secondRegionalRouteHistoryStateBuffer.label =
      "NumiBrain regional route-history metadata generation 1"
    firstRegionalRouteHistoryTimestampBuffer.label =
      "NumiBrain regional route-history timestamps generation 0"
    secondRegionalRouteHistoryTimestampBuffer.label =
      "NumiBrain regional route-history timestamps generation 1"
    firstRegionalRouteHistoryValueBuffer.label =
      "NumiBrain regional route-history values generation 0"
    secondRegionalRouteHistoryValueBuffer.label =
      "NumiBrain regional route-history values generation 1"
    regionalResolvedRouteHistorySlotBuffer.label =
      "NumiBrain resolved delayed regional route slots"
    firstRegionalRouteRuntimeStateBuffer.label =
      "NumiBrain regional routing state generation 0"
    secondRegionalRouteRuntimeStateBuffer.label =
      "NumiBrain regional routing state generation 1"
    regionalSelectedRouteIndexBuffer.label =
      "NumiBrain compacted selected regional route indices"
    regionalSelectedRouteCountBuffer.label =
      "NumiBrain selected regional route counts"
    protectiveCommandUniformBuffer.label = "NumiBrain protective-command uniforms"
    firstProtectiveCommandBuffer.label = "NumiBrain protective command generation 0"
    secondProtectiveCommandBuffer.label = "NumiBrain protective command generation 1"
    protectiveMotorProfileBuffer.label = "NumiBrain immutable protective motor profile"
    firstProtectiveMotorOutputHeaderBuffer.label =
      "NumiBrain protective motor header generation 0"
    secondProtectiveMotorOutputHeaderBuffer.label =
      "NumiBrain protective motor header generation 1"
    firstProtectiveMuscleExcitationBuffer.label =
      "NumiBrain protective muscle excitation generation 0"
    secondProtectiveMuscleExcitationBuffer.label =
      "NumiBrain protective muscle excitation generation 1"
    let uniformByteCount = maxEncodedSubsteps * TissueUniforms.byteCount
    guard
      let uniformBuffer = device.makeBuffer(
        length: uniformByteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate the substep uniform arena")
    }
    uniformBuffer.label = "NumiBrain tissue substep uniforms"
    let schedulerInspectionByteCount =
      MemoryLayout<NBReceptorEventTransductionResult>.stride
      + MemoryLayout<NBSchedulerResult>.stride
      + schedulerClockByteCount + schedulerInvocationCapacityByteCount
    let regionalUploadByteCount = max(
      max(
        regionalParameterByteCount,
        regionalRouteHistoryValueByteCount
      ),
      max(
        max(regionalTokenStateByteCount, regionalRouteHistoryTimestampByteCount),
        max(
          max(regionalLayoutByteCount, regionalRouteByteCount),
          max(regionalRouteHistoryStateByteCount, regionalRouteRuntimeStateByteCount)
        )
      )
    )
    guard
      let stagingBuffer = device.makeBuffer(
        length: max(
          max(stateByteCount, schedulerInspectionByteCount),
          max(
            max(eventByteCount, schedulerDescriptorByteCount),
            max(
              schedulerClockByteCount,
              max(
                max(projectionOffsetByteCount, projectionEdgeByteCount),
                max(
                  regionalUploadByteCount,
                  max(protectiveMotorProfileByteCount, protectiveMuscleExcitationByteCount)
                )
              )
            )
          )
        ),
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate the explicit upload/inspection buffer")
    }
    stagingBuffer.label = "NumiBrain tissue upload and inspection staging"

    let residencyDescriptor = MTLResidencySetDescriptor()
    residencyDescriptor.label = "NumiBrain tissue residency"
    residencyDescriptor.initialCapacity = stateBuffers.count + 50
    let residencySet: any MTLResidencySet
    do {
      residencySet = try device.makeResidencySet(descriptor: residencyDescriptor)
    } catch {
      throw TissueError.metal("failed to create the residency set: \(error)")
    }
    for buffer in stateBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(structureBuffer)
    residencySet.addAllocation(delayBuffer)
    residencySet.addAllocation(relayHistoryBuffer)
    residencySet.addAllocation(relayHistoryTimestampBuffer)
    residencySet.addAllocation(relayScratchBuffer)
    residencySet.addAllocation(projectionOffsetBuffer)
    residencySet.addAllocation(projectionEdgeBuffer)
    residencySet.addAllocation(eventBuffer)
    residencySet.addAllocation(activeEventIndexBuffer)
    residencySet.addAllocation(uniformBuffer)
    residencySet.addAllocation(schedulerDescriptorBuffer)
    for buffer in schedulerClockBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(schedulerEventUploadBuffer)
    residencySet.addAllocation(transducedSchedulerEventBuffer)
    residencySet.addAllocation(receptorEventTransductionUniformBuffer)
    residencySet.addAllocation(receptorEventTransductionResultBuffer)
    residencySet.addAllocation(schedulerUniformBuffer)
    residencySet.addAllocation(schedulerInvocationBuffer)
    residencySet.addAllocation(schedulerResultBuffer)
    residencySet.addAllocation(parameterVersionBindingBuffer)
    for buffer in regionalStateBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(regionalProgramHeaderBuffer)
    residencySet.addAllocation(regionalLayoutBuffer)
    residencySet.addAllocation(regionalRouteBuffer)
    residencySet.addAllocation(regionalParameterBuffer)
    for buffer in regionalTokenStateBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(regionalTokenCandidateBuffer)
    for buffer in regionalRouteHistoryStateBuffers {
      residencySet.addAllocation(buffer)
    }
    for buffer in regionalRouteHistoryTimestampBuffers {
      residencySet.addAllocation(buffer)
    }
    for buffer in regionalRouteHistoryValueBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(regionalResolvedRouteHistorySlotBuffer)
    for buffer in regionalRouteRuntimeStateBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(regionalSelectedRouteIndexBuffer)
    residencySet.addAllocation(regionalSelectedRouteCountBuffer)
    residencySet.addAllocation(protectiveCommandUniformBuffer)
    for buffer in protectiveCommandBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(protectiveMotorProfileBuffer)
    for buffer in protectiveMotorOutputHeaderBuffers {
      residencySet.addAllocation(buffer)
    }
    for buffer in protectiveMuscleExcitationBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(stagingBuffer)
    residencySet.commit()
    residencySet.requestResidency()

    self.device = device
    self.deviceName = device.name
    self.width = initialState.width
    self.height = initialState.height
    self.parameters = parameters
    self.stimulus = stimulus
    self.structureHash = structure.stableHash()
    self.delayFieldHash = delayField.stableHash()
    self.connectomeHash = connectome.stableHash()
    self.eventScheduleHash = eventSchedule.stableHash()
    self.eventSchedule = eventSchedule
    self.randomContext = randomContext
    self.brainSchedule = brainSchedule
    self.regionalTokenProgram = regionalTokenProgram
    self.parameterVersion = parameterVersion
    self.protectiveMotorProfile = protectiveMotorProfile
    self.schedulerEnvironmentIdentifier = schedulerEnvironmentIdentifier
    self.maximumTissueDelayMicroseconds = maximumTissueDelayMicroseconds
    self.maxEncodedSubsteps = maxEncodedSubsteps
    self.maxSchedulerEvents = maxSchedulerEvents
    self.maxSchedulerInvocations = maxSchedulerInvocations
    self.commandQueue = commandQueue
    self.commandAllocator = commandAllocator
    self.commandBuffer = commandBuffer
    self.tissuePipeline = tissuePipeline
    self.eventCompactionPipeline = eventCompactionPipeline
    self.receptorInterruptTransductionPipeline = receptorInterruptTransductionPipeline
    self.schedulerPipeline = schedulerPipeline
    self.regionalPipeline = regionalPipeline
    self.protectivePipeline = protectivePipeline
    self.protectiveMotorPipeline = protectiveMotorPipeline
    self.argumentTable = argumentTable
    self.eventArgumentTable = eventArgumentTable
    self.receptorInterruptArgumentTable = receptorInterruptArgumentTable
    self.schedulerArgumentTable = schedulerArgumentTable
    self.regionalArgumentTable = regionalArgumentTable
    self.protectiveArgumentTable = protectiveArgumentTable
    self.protectiveMotorArgumentTable = protectiveMotorArgumentTable
    self.residencySet = residencySet
    self.stateBuffers = stateBuffers
    self.structureBuffer = structureBuffer
    self.delayBuffer = delayBuffer
    self.relayHistoryBuffer = relayHistoryBuffer
    self.relayHistoryTimestampBuffer = relayHistoryTimestampBuffer
    self.relayScratchBuffer = relayScratchBuffer
    self.projectionOffsetBuffer = projectionOffsetBuffer
    self.projectionEdgeBuffer = projectionEdgeBuffer
    self.eventBuffer = eventBuffer
    self.activeEventIndexBuffer = activeEventIndexBuffer
    self.uniformBuffer = uniformBuffer
    self.schedulerDescriptorBuffer = schedulerDescriptorBuffer
    self.schedulerClockBuffers = schedulerClockBuffers
    self.schedulerEventUploadBuffer = schedulerEventUploadBuffer
    self.transducedSchedulerEventBuffer = transducedSchedulerEventBuffer
    self.receptorEventTransductionUniformBuffer = receptorEventTransductionUniformBuffer
    self.receptorEventTransductionResultBuffer = receptorEventTransductionResultBuffer
    self.schedulerUniformBuffer = schedulerUniformBuffer
    self.schedulerInvocationBuffer = schedulerInvocationBuffer
    self.schedulerResultBuffer = schedulerResultBuffer
    self.parameterVersionBindingBuffer = parameterVersionBindingBuffer
    self.regionalStateBuffers = regionalStateBuffers
    self.regionalProgramHeaderBuffer = regionalProgramHeaderBuffer
    self.regionalLayoutBuffer = regionalLayoutBuffer
    self.regionalRouteBuffer = regionalRouteBuffer
    self.regionalParameterBuffer = regionalParameterBuffer
    self.regionalTokenStateBuffers = regionalTokenStateBuffers
    self.regionalTokenCandidateBuffer = regionalTokenCandidateBuffer
    self.regionalRouteHistoryStateBuffers = regionalRouteHistoryStateBuffers
    self.regionalRouteHistoryTimestampBuffers = regionalRouteHistoryTimestampBuffers
    self.regionalRouteHistoryValueBuffers = regionalRouteHistoryValueBuffers
    self.regionalResolvedRouteHistorySlotBuffer = regionalResolvedRouteHistorySlotBuffer
    self.regionalRouteRuntimeStateBuffers = regionalRouteRuntimeStateBuffers
    self.regionalSelectedRouteIndexBuffer = regionalSelectedRouteIndexBuffer
    self.regionalSelectedRouteCountBuffer = regionalSelectedRouteCountBuffer
    self.protectiveCommandUniformBuffer = protectiveCommandUniformBuffer
    self.protectiveCommandBuffers = protectiveCommandBuffers
    self.protectiveMotorProfileBuffer = protectiveMotorProfileBuffer
    self.protectiveMotorOutputHeaderBuffers = protectiveMotorOutputHeaderBuffers
    self.protectiveMuscleExcitationBuffers = protectiveMuscleExcitationBuffers
    self.stagingBuffer = stagingBuffer
    self.stateByteCount = stateByteCount
    self.relayByteCount = relayByteCount
    self.relayHistoryByteCount = relayHistoryByteCount
    self.relayHistoryTimestampByteCount = relayHistoryTimestampByteCount
    self.projectionOffsetByteCount = projectionOffsetByteCount
    self.projectionEdgeByteCount = projectionEdgeByteCount
    self.eventByteCount = eventByteCount
    self.activeEventIndexByteCount = activeEventIndexByteCount
    self.schedulerDescriptorByteCount = schedulerDescriptorByteCount
    self.schedulerClockByteCount = schedulerClockByteCount
    self.schedulerEventCapacityByteCount = schedulerEventCapacityByteCount
    self.receptorEventTransductionUniformByteCount =
      MemoryLayout<NBReceptorEventTransductionUniforms>.stride
    self.receptorEventTransductionResultByteCount =
      MemoryLayout<NBReceptorEventTransductionResult>.stride
    self.schedulerInvocationCapacityByteCount = schedulerInvocationCapacityByteCount
    self.parameterVersionBindingByteCount = MemoryLayout<NBParameterVersionBinding>.stride
    self.regionalStateByteCount = regionalStateByteCount
    self.regionalTokenStateByteCount = regionalTokenStateByteCount
    self.regionalRouteByteCount = regionalRouteByteCount
    self.regionalParameterByteCount = regionalParameterByteCount
    self.regionalRouteHistoryStateByteCount = regionalRouteHistoryStateByteCount
    self.regionalRouteHistoryTimestampByteCount = regionalRouteHistoryTimestampByteCount
    self.regionalRouteHistoryValueByteCount = regionalRouteHistoryValueByteCount
    self.regionalRouteRuntimeStateByteCount = regionalRouteRuntimeStateByteCount
    self.regionalSelectedRouteIndexByteCount = regionalSelectedRouteIndexByteCount
    self.regionalSelectedRouteCountByteCount = regionalSelectedRouteCountByteCount
    self.protectiveMotorProfileByteCount = protectiveMotorProfileByteCount
    self.protectiveMuscleExcitationByteCount = protectiveMuscleExcitationByteCount

    initialState.cells.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: stateByteCount)
    }
    try copy(
      source: stagingBuffer,
      destination: stateBuffers[committedIndex],
      label: "NumiBrain tissue initial upload"
    )
    structure.sites.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: stateByteCount)
    }
    try copy(
      source: stagingBuffer,
      destination: structureBuffer,
      label: "NumiBrain tissue structure upload"
    )
    delayField.delaySteps.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: delayField.count)
    }
    try copy(
      source: stagingBuffer,
      destination: delayBuffer,
      size: delayField.count,
      label: "NumiBrain conduction delay upload"
    )
    let initialRelay = initialState.cells.map(\.w)
    initialRelay.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: relayByteCount)
    }
    try seedRelayHistory()
    let initialRelayTimestamps = [UInt64](
      repeating: 0,
      count: 2 * TissueDelayField.historyCapacity
    )
    initialRelayTimestamps.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: relayHistoryTimestampByteCount
      )
    }
    try copy(
      source: stagingBuffer,
      destination: relayHistoryTimestampBuffer,
      size: relayHistoryTimestampByteCount,
      label: "NumiBrain relay-history timestamp seed"
    )
    connectome.destinationOffsets.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: projectionOffsetByteCount)
    }
    try copy(
      source: stagingBuffer,
      destination: projectionOffsetBuffer,
      size: projectionOffsetByteCount,
      label: "NumiBrain projection offset upload"
    )
    if projectionEdgeByteCount > 0 {
      packedProjectionEdges.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(from: source, byteCount: projectionEdgeByteCount)
      }
      try copy(
        source: stagingBuffer,
        destination: projectionEdgeBuffer,
        size: projectionEdgeByteCount,
        label: "NumiBrain projection edge upload"
      )
    }
    if eventByteCount > 0 {
      packedEvents.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(from: source, byteCount: eventByteCount)
      }
      try copy(
        source: stagingBuffer,
        destination: eventBuffer,
        size: eventByteCount,
        label: "NumiBrain receptor-event upload"
      )
    }
    let descriptorRecords = brainSchedule.modules.map(\.abiRecord)
    descriptorRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: schedulerDescriptorByteCount
      )
    }
    try copy(
      source: stagingBuffer,
      destination: schedulerDescriptorBuffer,
      size: schedulerDescriptorByteCount,
      label: "NumiBrain module descriptor upload"
    )
    var parameterVersionBinding = parameterVersion.abiBinding
    withUnsafeBytes(of: &parameterVersionBinding) { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: MemoryLayout<NBParameterVersionBinding>.stride
      )
    }
    try copy(
      source: stagingBuffer,
      destination: parameterVersionBindingBuffer,
      size: MemoryLayout<NBParameterVersionBinding>.stride,
      label: "NumiBrain parameter-version binding upload"
    )
    let initialClockRecords = brainSchedule.modules.map { _ in
      BrainModuleClockState(nextDue: BrainTimestamp(microseconds: 0)).abiRecord
    }
    initialClockRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: schedulerClockByteCount)
    }
    for (index, buffer) in schedulerClockBuffers.enumerated() {
      try copy(
        source: stagingBuffer,
        destination: buffer,
        size: schedulerClockByteCount,
        label: "NumiBrain scheduler clock generation \(index) upload"
      )
    }
    let initialRegionalRecords = brainSchedule.modules.map { _ in
      RegionalModuleState().abiRecord
    }
    initialRegionalRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: regionalStateByteCount)
    }
    for (index, buffer) in regionalStateBuffers.enumerated() {
      try copy(
        source: stagingBuffer,
        destination: buffer,
        size: regionalStateByteCount,
        label: "NumiBrain regional state generation \(index) upload"
      )
    }
    var regionalHeader = regionalTokenProgram.headerRecord
    withUnsafeBytes(of: &regionalHeader) { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: MemoryLayout<NBRegionalProgramHeader>.stride
      )
    }
    try copy(
      source: stagingBuffer,
      destination: regionalProgramHeaderBuffer,
      size: MemoryLayout<NBRegionalProgramHeader>.stride,
      label: "NumiBrain regional program-header upload"
    )
    let regionalLayoutRecords = regionalTokenProgram.layouts.map(\.abiRecord)
    regionalLayoutRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: regionalLayoutByteCount)
    }
    try copy(
      source: stagingBuffer,
      destination: regionalLayoutBuffer,
      size: regionalLayoutByteCount,
      label: "NumiBrain regional token-layout upload"
    )
    if regionalRouteByteCount > 0 {
      let regionalRouteRecords = regionalTokenProgram.routeABIRecords
      regionalRouteRecords.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(from: source, byteCount: regionalRouteByteCount)
      }
      try copy(
        source: stagingBuffer,
        destination: regionalRouteBuffer,
        size: regionalRouteByteCount,
        label: "NumiBrain sparse regional-route upload"
      )
    }
    let regionalParameterRecords = regionalTokenProgram.parameters.map(\.abiRecord)
    regionalParameterRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: regionalParameterByteCount)
    }
    try copy(
      source: stagingBuffer,
      destination: regionalParameterBuffer,
      size: regionalParameterByteCount,
      label: "NumiBrain regional slow-parameter upload"
    )
    initialRegionalTokenValues.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: regionalTokenStateByteCount)
    }
    for (index, buffer) in regionalTokenStateBuffers.enumerated() {
      try copy(
        source: stagingBuffer,
        destination: buffer,
        size: regionalTokenStateByteCount,
        label: "NumiBrain regional token generation \(index) upload"
      )
    }
    let initialRegionalRouteHistory = RegionalRouteHistory(program: regionalTokenProgram)
    if regionalRouteHistoryStateByteCount > 0 {
      let historyStateRecords = initialRegionalRouteHistory.states.map(\.abiRecord)
      historyStateRecords.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(
          from: source,
          byteCount: regionalRouteHistoryStateByteCount
        )
      }
      for (index, buffer) in regionalRouteHistoryStateBuffers.enumerated() {
        try copy(
          source: stagingBuffer,
          destination: buffer,
          size: regionalRouteHistoryStateByteCount,
          label: "NumiBrain regional route-history metadata generation \(index) upload"
        )
      }
    }
    if regionalRouteHistoryTimestampByteCount > 0 {
      initialRegionalRouteHistory.timestamps.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(
          from: source,
          byteCount: regionalRouteHistoryTimestampByteCount
        )
      }
      for (index, buffer) in regionalRouteHistoryTimestampBuffers.enumerated() {
        try copy(
          source: stagingBuffer,
          destination: buffer,
          size: regionalRouteHistoryTimestampByteCount,
          label: "NumiBrain regional route-history timestamps generation \(index) upload"
        )
      }
    }
    if regionalRouteHistoryValueByteCount > 0 {
      initialRegionalRouteHistory.values.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(
          from: source,
          byteCount: regionalRouteHistoryValueByteCount
        )
      }
      for (index, buffer) in regionalRouteHistoryValueBuffers.enumerated() {
        try copy(
          source: stagingBuffer,
          destination: buffer,
          size: regionalRouteHistoryValueByteCount,
          label: "NumiBrain regional route-history values generation \(index) upload"
        )
      }
    }
    if regionalRouteRuntimeStateByteCount > 0 {
      let routeRuntimeRecords = initialRegionalRoutingState.states.map(\.abiRecord)
      routeRuntimeRecords.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(
          from: source,
          byteCount: regionalRouteRuntimeStateByteCount
        )
      }
      for (index, buffer) in regionalRouteRuntimeStateBuffers.enumerated() {
        try copy(
          source: stagingBuffer,
          destination: buffer,
          size: regionalRouteRuntimeStateByteCount,
          label: "NumiBrain regional routing-state generation \(index) upload"
        )
      }
    }
    let initialProtectiveCommand = try ProtectiveMotorCommand.reference(
      timestamp: BrainTimestamp(microseconds: 0),
      brainGeneration: 0,
      environmentIdentifier: schedulerEnvironmentIdentifier,
      schedule: brainSchedule,
      invocations: [],
      regionalStates: brainSchedule.modules.map { _ in RegionalModuleState() }
    )
    var initialProtectiveRecord = initialProtectiveCommand.abiRecord
    withUnsafeBytes(of: &initialProtectiveRecord) { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: ProtectiveMotorCommand.byteCount
      )
    }
    for (index, buffer) in protectiveCommandBuffers.enumerated() {
      try copy(
        source: stagingBuffer,
        destination: buffer,
        size: ProtectiveMotorCommand.byteCount,
        label: "NumiBrain protective command generation \(index) upload"
      )
    }
    let protectiveMotorProfileRecords = protectiveMotorProfile.abiRecords
    protectiveMotorProfileRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: protectiveMotorProfileByteCount
      )
    }
    try copy(
      source: stagingBuffer,
      destination: protectiveMotorProfileBuffer,
      size: protectiveMotorProfileByteCount,
      label: "NumiBrain protective motor-profile upload"
    )
    let initialProtectiveMotorOutput = try ProtectiveMotorOutput.reference(
      command: initialProtectiveCommand,
      profile: protectiveMotorProfile
    )
    var initialProtectiveMotorHeader = initialProtectiveMotorOutput.abiHeader
    withUnsafeBytes(of: &initialProtectiveMotorHeader) { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: ProtectiveMotorOutput.headerByteCount
      )
    }
    for (index, buffer) in protectiveMotorOutputHeaderBuffers.enumerated() {
      try copy(
        source: stagingBuffer,
        destination: buffer,
        size: ProtectiveMotorOutput.headerByteCount,
        label: "NumiBrain protective motor header generation \(index) upload"
      )
    }
    initialProtectiveMotorOutput.muscleExcitations.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: protectiveMuscleExcitationByteCount
      )
    }
    for (index, buffer) in protectiveMuscleExcitationBuffers.enumerated() {
      try copy(
        source: stagingBuffer,
        destination: buffer,
        size: protectiveMuscleExcitationByteCount,
        label: "NumiBrain protective muscle excitation generation \(index) upload"
      )
    }
  }

  deinit {
    residencySet.endResidency()
  }

  public var hasPendingRootTransaction: Bool {
    pendingRootShadowIndex != nil
  }

  public var hasPendingJointTransaction: Bool {
    pendingJointTransaction != nil
  }

  public var hasOpenInteractiveJointControl: Bool {
    interactiveJointRoot != nil
  }

  public var residencyAllocatedBytes: UInt64 {
    residencySet.allocatedSize
  }

  public var schedulerCommittedTimestamp: BrainTimestamp? {
    committedSchedulerTime
  }

  public var schedulerCommittedGeneration: UInt64 {
    committedSchedulerGeneration
  }

  public var schedulerUniformByteCount: Int {
    MemoryLayout<NBSchedulerUniforms>.stride
  }

  public var schedulerResultByteCount: Int {
    MemoryLayout<NBSchedulerResult>.stride
  }

  /// Creates the stable root identity used by a NumanX shadow transaction.
  /// Physical state remains external and is represented only by acceptance
  /// tokens returned through `BrainJointTransaction`.
  public func beginJointControl(
    controlStepIdentifier: UInt64,
    basePhysicsGeneration: UInt64,
    committedTimestamp: BrainTimestamp,
    targetTimestamp: BrainTimestamp
  ) throws -> BrainJointTransaction {
    guard pendingRootShadowIndex == nil, pendingJointTransaction == nil,
      interactiveJointRoot == nil
    else {
      throw TissueError.transaction("commit or abort the pending Metal root first")
    }
    guard randomContext.environmentIdentifier == schedulerEnvironmentIdentifier else {
      throw TissueError.transaction(
        "joint transaction environment does not match the counter-random context"
      )
    }
    if let committedSchedulerTime, committedSchedulerTime != committedTimestamp {
      throw TissueError.transaction(
        "joint root time does not match committed Metal scheduler time"
      )
    }
    let token = try BrainJointTransactionToken(
      environmentIdentifier: schedulerEnvironmentIdentifier,
      episodeIdentifier: UInt64(randomContext.episodeIdentifier),
      controlStepIdentifier: controlStepIdentifier,
      parameterVersionFingerprint: parameterVersion.fingerprint,
      baseBrainGeneration: committedSchedulerGeneration,
      basePhysicsGeneration: basePhysicsGeneration,
      committedTimestamp: committedTimestamp,
      targetTimestamp: targetTimestamp,
      randomCounterGeneration: committedStep
    )
    return BrainJointTransaction(token: token)
  }

  /// Opens an interactive root whose tissue candidate is executed before the
  /// caller returns NumanX acceptance or rejection. No committed generation is
  /// published until `finishInteractiveJointControl` and joint commit.
  public func beginInteractiveJointControl(
    controlStepIdentifier: UInt64,
    basePhysicsGeneration: UInt64,
    committedTimestamp: BrainTimestamp,
    targetTimestamp: BrainTimestamp
  ) throws -> BrainJointTransactionToken {
    let transaction = try beginJointControl(
      controlStepIdentifier: controlStepIdentifier,
      basePhysicsGeneration: basePhysicsGeneration,
      committedTimestamp: committedTimestamp,
      targetTimestamp: targetTimestamp
    )
    interactiveJointRoot = InteractiveJointRoot(
      transaction: transaction,
      rootShadowIndex: committedIndex,
      historyOwnerMask: committedHistoryOwnerMask,
      historyStep: committedStep,
      relayHistoryTimestamps: committedRelayHistoryTimestamps,
      acceptedTimestamp: committedTimestamp,
      candidate: nil,
      fastSchedulerWindow: nil,
      firstGPUStartSeconds: nil,
      lastGPUEndSeconds: nil
    )
    return transaction.token
  }

  /// Advances one neural tissue candidate without publishing it. Corrected
  /// durations may shrink from the nominal tissue step; local and sparse
  /// conduction still resolve against accepted physical timestamps.
  public func advanceFastSystems(
    candidateDurationMicroseconds: UInt64
  ) throws -> FastSystemResult {
    guard var root = interactiveJointRoot else {
      throw TissueError.transaction("begin interactive joint control first")
    }
    guard root.candidate == nil else {
      throw TissueError.transaction("accept or reject the active neural candidate first")
    }
    guard root.transaction.acceptedSubstepCount < UInt32(TissueDelayField.historyCapacity) else {
      throw TissueError.transaction(
        "interactive root exhausted its \(TissueDelayField.historyCapacity)-slot delayed history"
      )
    }
    let nominalDuration = try schedulerTimestamp(
      milliseconds: parameters.timestepMilliseconds
    ).rawValue
    guard candidateDurationMicroseconds > 0,
      candidateDurationMicroseconds <= nominalDuration
    else {
      throw TissueError.transaction(
        "interactive candidate duration must be positive and no larger than the nominal tissue step"
      )
    }
    var transaction = root.transaction
    let substep = try transaction.beginPhysicsSubstep(
      durationMicroseconds: candidateDurationMicroseconds
    )
    guard substep.candidateTimestamp <= transaction.token.targetTimestamp else {
      throw TissueError.transaction("interactive candidate would overshoot the root target")
    }
    guard substep.startTimestamp == root.acceptedTimestamp else {
      throw TissueError.transaction("interactive neural and physical start times diverged")
    }
    let (nextHistoryStep, historyOverflow) = root.historyStep.addingReportingOverflow(1)
    guard !historyOverflow else {
      throw TissueError.transaction("interactive tissue history step overflows UInt64")
    }
    let historyWriteSlot = Int(
      nextHistoryStep % UInt64(TissueDelayField.historyCapacity)
    )
    let currentOwner =
      (root.historyOwnerMask >> UInt32(historyWriteSlot)) & 1
    let historyWritePlane = currentOwner ^ 1
    var prospectiveTimestamps = root.relayHistoryTimestamps
    prospectiveTimestamps[historyWriteSlot] = substep.candidateTimestamp.rawValue
    try validateRelayHistoryCoverage(
      at: substep.candidateTimestamp,
      timestamps: prospectiveTimestamps
    )
    let destination = destinationIndex(rootShadowIndex: root.rootShadowIndex)
    let timestepMilliseconds = Float(Double(candidateDurationMicroseconds) / 1_000)
    let values = TissueUniforms.encode(
      width: width,
      height: height,
      timeMilliseconds: Float(Double(root.acceptedTimestamp.rawValue) / 1_000),
      parameters: parameters,
      stimulus: stimulus,
      historyStep: UInt32(root.historyStep % UInt64(TissueDelayField.historyCapacity)),
      historyOwnerMask: root.historyOwnerMask,
      historyWriteSlot: UInt32(historyWriteSlot),
      historyWritePlane: historyWritePlane,
      eventCount: eventSchedule.eventCount,
      randomContext: randomContext,
      acceptedStep: root.historyStep,
      timestepMilliseconds: timestepMilliseconds,
      currentTimestamp: root.acceptedTimestamp,
      candidateTimestamp: substep.candidateTimestamp
    )
    writeUniforms(values, attempt: 0)
    let feedback = try submit(label: "NumiBrain interactive fast neural candidate") {
      encoder in
      eventArgumentTable.setAddress(uniformBuffer.gpuAddress, index: 0)
      eventArgumentTable.setAddress(eventBuffer.gpuAddress, index: 1)
      eventArgumentTable.setAddress(activeEventIndexBuffer.gpuAddress, index: 2)
      encoder.setComputePipelineState(eventCompactionPipeline)
      encoder.setArgumentTable(eventArgumentTable)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      argumentTable.setAddress(stateBuffers[root.rootShadowIndex].gpuAddress, index: 0)
      argumentTable.setAddress(stateBuffers[destination].gpuAddress, index: 1)
      argumentTable.setAddress(uniformBuffer.gpuAddress, index: 2)
      argumentTable.setAddress(structureBuffer.gpuAddress, index: 3)
      argumentTable.setAddress(delayBuffer.gpuAddress, index: 4)
      argumentTable.setAddress(relayHistoryBuffer.gpuAddress, index: 5)
      argumentTable.setAddress(relayScratchBuffer.gpuAddress, index: 6)
      argumentTable.setAddress(projectionOffsetBuffer.gpuAddress, index: 7)
      argumentTable.setAddress(projectionEdgeBuffer.gpuAddress, index: 8)
      argumentTable.setAddress(eventBuffer.gpuAddress, index: 9)
      argumentTable.setAddress(activeEventIndexBuffer.gpuAddress, index: 10)
      argumentTable.setAddress(relayHistoryTimestampBuffer.gpuAddress, index: 11)
      encoder.setComputePipelineState(tissuePipeline)
      encoder.setArgumentTable(argumentTable)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(width: width, height: height, depth: 1),
        threadsPerThreadgroup: threadgroupSize()
      )
    }
    root.transaction = transaction
    root.candidate = InteractiveCandidate(
      substep: substep,
      destinationIndex: destination,
      historyWriteSlot: historyWriteSlot,
      historyWritePlane: historyWritePlane
    )
    root.firstGPUStartSeconds = root.firstGPUStartSeconds ?? feedback.gpuStartTime
    interactiveJointRoot = root
    let protectiveStateIndex =
      root.fastSchedulerWindow?.outputClockIndex
      ?? committedRegionalStateIndex
    let protectiveTimestamp =
      root.fastSchedulerWindow == nil
      ? committedSchedulerTime ?? BrainTimestamp(microseconds: 0)
      : root.acceptedTimestamp
    let protectiveGeneration =
      root.fastSchedulerWindow == nil
      ? root.transaction.token.baseBrainGeneration
      : root.transaction.token.shadowGeneration
    return FastSystemResult(
      substep: substep,
      protectiveCommand: ProtectiveCommandBufferView(
        gpuAddress: protectiveCommandBuffers[protectiveStateIndex].gpuAddress,
        byteCount: ProtectiveMotorCommand.byteCount,
        timestamp: protectiveTimestamp,
        brainGeneration: protectiveGeneration
      ),
      protectiveMotorOutput: ProtectiveMotorOutputBufferView(
        headerGPUAddress: protectiveMotorOutputHeaderBuffers[protectiveStateIndex].gpuAddress,
        muscleExcitationGPUAddress:
          protectiveMuscleExcitationBuffers[protectiveStateIndex].gpuAddress,
        headerByteCount: ProtectiveMotorOutput.headerByteCount,
        muscleExcitationByteCount: protectiveMuscleExcitationByteCount,
        muscleCount: protectiveMotorProfile.channels.count,
        timestamp: protectiveTimestamp,
        brainGeneration: protectiveGeneration,
        profileFingerprint: protectiveMotorProfile.fingerprint
      ),
      gpuStartSeconds: feedback.gpuStartTime,
      gpuEndSeconds: feedback.gpuEndTime
    )
  }

  public func acceptPhysicsSubstep(
    _ accepted: AcceptedPhysicsStateToken,
    for substep: BrainJointSubstepToken,
    receptorEvents: [BrainInterruptEvent] = []
  ) throws {
    guard var root = interactiveJointRoot, let candidate = root.candidate,
      candidate.substep == substep
    else {
      throw TissueError.transaction("stale or missing interactive neural candidate")
    }
    var transaction = root.transaction
    try transaction.acceptPhysicsSubstep(
      accepted,
      for: substep,
      receptorEvents: receptorEvents
    )
    let acceptedEvents = transaction.resolutions.lazy
      .filter(\.isAccepted)
      .flatMap(\.receptorEvents)
    let schedulerWindow = try prepareSchedulerWindow(
      startTime: transaction.token.committedTimestamp,
      targetTime: accepted.acceptedTimestamp,
      events: Array(acceptedEvents)
    )
    guard committedRegionalStateIndex == schedulerWindow.inputClockIndex else {
      throw TissueError.transaction("interactive regional and scheduler generations diverged")
    }
    let feedback = try submit(label: "NumiBrain accepted fast regional prefix") { encoder in
      encodeRootFinalization(encoder, schedulerWindow: schedulerWindow)
    }
    root.transaction = transaction
    root.rootShadowIndex = candidate.destinationIndex
    root.historyOwnerMask = settingHistoryOwner(
      mask: root.historyOwnerMask,
      slot: candidate.historyWriteSlot,
      owner: candidate.historyWritePlane
    )
    root.historyStep += 1
    root.relayHistoryTimestamps[candidate.historyWriteSlot] =
      accepted.acceptedTimestamp.rawValue
    root.acceptedTimestamp = accepted.acceptedTimestamp
    root.candidate = nil
    root.fastSchedulerWindow = schedulerWindow
    root.firstGPUStartSeconds = root.firstGPUStartSeconds ?? feedback.gpuStartTime
    root.lastGPUEndSeconds = feedback.gpuEndTime
    hasCommittedSchedulerResult = false
    interactiveJointRoot = root
  }

  public func rejectPhysicsSubstep(
    _ substep: BrainJointSubstepToken,
    receptorEvents: [BrainInterruptEvent] = []
  ) throws {
    guard var root = interactiveJointRoot, root.candidate?.substep == substep else {
      throw TissueError.transaction("stale or missing interactive neural candidate")
    }
    var transaction = root.transaction
    try transaction.rejectPhysicsSubstep(
      substep,
      receptorEvents: receptorEvents
    )
    root.transaction = transaction
    root.candidate = nil
    interactiveJointRoot = root
  }

  /// Finalizes the slow scheduler and regional systems after NumanX has
  /// accepted enough interactive candidates to reach the root target. The
  /// accepted tissue generation remains unpublished until joint commit.
  public func finishInteractiveJointControl(
    schedulerEvents: [BrainInterruptEvent] = []
  ) throws -> Submission {
    guard let root = interactiveJointRoot else {
      throw TissueError.transaction("there is no interactive joint root to finish")
    }
    guard root.candidate == nil else {
      throw TissueError.transaction("accept or reject the active neural candidate first")
    }
    let transaction = root.transaction
    let token = transaction.token
    guard transaction.status == .open, transaction.activeSubstep == nil,
      !transaction.resolutions.isEmpty,
      transaction.acceptedSubstepCount > 0,
      transaction.acceptedTimestamp == token.targetTimestamp,
      transaction.lastAcceptedPhysicsState != nil
    else {
      throw TissueError.transaction("interactive joint root has not accepted its target")
    }
    guard token.baseBrainGeneration == committedSchedulerGeneration,
      token.randomCounterGeneration == committedStep,
      token.parameterVersionFingerprint == parameterVersion.fingerprint,
      token.environmentIdentifier == schedulerEnvironmentIdentifier
    else {
      throw TissueError.transaction("interactive joint identity is stale for this Metal runtime")
    }
    guard transaction.acceptedSubstepCount <= UInt32(TissueDelayField.historyCapacity) else {
      throw TissueError.transaction(
        "an interactive root cannot accept more than \(TissueDelayField.historyCapacity) delayed substeps"
      )
    }
    let (expectedHistoryStep, historyOverflow) = committedStep.addingReportingOverflow(
      UInt64(transaction.acceptedSubstepCount)
    )
    guard !historyOverflow, root.historyStep == expectedHistoryStep,
      root.acceptedTimestamp == token.targetTimestamp
    else {
      throw TissueError.transaction("interactive tissue shadow diverged from the joint ledger")
    }

    guard var schedulerWindow = root.fastSchedulerWindow,
      schedulerWindow.targetTime == token.targetTimestamp
    else {
      throw TissueError.transaction("interactive fast scheduler did not reach the root target")
    }
    guard schedulerWindow.targetTime == token.targetTimestamp,
      committedRegionalStateIndex == schedulerWindow.inputClockIndex
    else {
      throw TissueError.transaction("interactive scheduler shadow diverged from the joint token")
    }

    var finalGPUStart = root.firstGPUStartSeconds
    var finalGPUEnd = root.lastGPUEndSeconds
    var finalizationDispatches = 0
    if !schedulerEvents.isEmpty {
      let acceptedEvents = transaction.resolutions.lazy
        .filter(\.isAccepted)
        .flatMap(\.receptorEvents)
      schedulerWindow = try prepareSchedulerWindow(
        startTime: token.committedTimestamp,
        targetTime: token.targetTimestamp,
        events: schedulerEvents + acceptedEvents
      )
      let feedback = try submit(label: "NumiBrain interactive joint root finalization") {
        encoder in
        encodeRootFinalization(encoder, schedulerWindow: schedulerWindow)
      }
      finalGPUStart = finalGPUStart ?? feedback.gpuStartTime
      finalGPUEnd = feedback.gpuEndTime
      finalizationDispatches = 1
    }
    guard let finalGPUStart, let finalGPUEnd else {
      throw TissueError.transaction("interactive GPU timing did not cover the accepted root")
    }
    pendingRootShadowIndex = root.rootShadowIndex
    pendingRootShadowOwnerMask = root.historyOwnerMask
    pendingRootShadowStep = root.historyStep
    pendingRelayHistoryTimestamps = root.relayHistoryTimestamps
    pendingSchedulerClockIndex = schedulerWindow.outputClockIndex
    pendingSchedulerTargetTime = schedulerWindow.targetTime
    pendingRegionalStateIndex = schedulerWindow.outputClockIndex
    pendingSchedulerInitialized = schedulerWindow.initialize
    hasCommittedSchedulerResult = false
    pendingJointTransaction = transaction
    interactiveJointRoot = nil

    return Submission(
      parameterVersionFingerprint: parameterVersion.fingerprint,
      attemptedSubsteps: transaction.resolutions.count,
      acceptedSubsteps: Int(transaction.acceptedSubstepCount),
      eventCompactionDispatches: transaction.resolutions.count,
      receptorInterruptTransductionDispatches: Int(transaction.acceptedSubstepCount)
        + finalizationDispatches,
      schedulerDispatches: Int(transaction.acceptedSubstepCount) + finalizationDispatches,
      regionalDispatches: Int(transaction.acceptedSubstepCount) + finalizationDispatches,
      protectiveDispatches: Int(transaction.acceptedSubstepCount) + finalizationDispatches,
      protectiveMotorDispatches: Int(transaction.acceptedSubstepCount)
        + finalizationDispatches,
      schedulerHostInputEventCount: schedulerWindow.hostEventCount,
      schedulerReceptorInputEventCount: schedulerWindow.receptorEventCount,
      schedulerInputEventCount: schedulerWindow.eventCount,
      gpuStartSeconds: finalGPUStart,
      gpuEndSeconds: finalGPUEnd
    )
  }

  public func abortInteractiveJointControl() throws {
    guard var root = interactiveJointRoot else {
      throw TissueError.transaction("there is no interactive joint root to abort")
    }
    try root.transaction.abort()
    if root.fastSchedulerWindow != nil {
      hasCommittedSchedulerResult = false
    }
    interactiveJointRoot = nil
  }

  /// Encodes a Metal root from the exact accepted/rejected NumanX ledger.
  /// Candidate durations may shrink from the nominal tissue step, while
  /// physical-time relay lookup preserves the configured conduction interval.
  public func runJointRootTransaction(
    _ transaction: BrainJointTransaction,
    schedulerEvents: [BrainInterruptEvent] = []
  ) throws -> Submission {
    let token = transaction.token
    guard transaction.status == .open, transaction.activeSubstep == nil else {
      throw TissueError.transaction("joint transaction is not ready for Metal encoding")
    }
    guard !transaction.resolutions.isEmpty,
      transaction.acceptedSubstepCount > 0,
      transaction.acceptedTimestamp == token.targetTimestamp,
      transaction.lastAcceptedPhysicsState != nil
    else {
      throw TissueError.transaction("joint transaction has not accepted the root target")
    }
    guard token.environmentIdentifier == schedulerEnvironmentIdentifier,
      token.parameterVersionFingerprint == parameterVersion.fingerprint,
      token.baseBrainGeneration == committedSchedulerGeneration,
      token.randomCounterGeneration == committedStep
    else {
      throw TissueError.transaction("joint transaction identity is stale for this Metal runtime")
    }
    if let committedSchedulerTime {
      guard token.committedTimestamp == committedSchedulerTime else {
        throw TissueError.transaction("joint transaction starts from stale committed time")
      }
    }
    let timestep = try schedulerTimestamp(
      milliseconds: parameters.timestepMilliseconds
    ).rawValue
    guard
      transaction.resolutions.allSatisfy({
        $0.substep.durationMicroseconds > 0
          && $0.substep.durationMicroseconds <= timestep
      })
    else {
      throw TissueError.transaction(
        "joint substep duration must be positive and no larger than the nominal tissue step"
      )
    }
    let acceptance = transaction.resolutions.map(\.isAccepted)
    let acceptedCount = acceptance.lazy.filter({ $0 }).count
    let rejectedCount = acceptance.count - acceptedCount
    guard acceptedCount == Int(transaction.acceptedSubstepCount),
      UInt64(rejectedCount) == transaction.rejectedAttemptCount
    else {
      throw TissueError.transaction("joint substep ledger counters do not match")
    }
    var duration: UInt64 = 0
    var durationOverflow = false
    for resolution in transaction.resolutions where resolution.isAccepted {
      let result = duration.addingReportingOverflow(
        resolution.substep.durationMicroseconds
      )
      duration = result.partialValue
      durationOverflow = durationOverflow || result.overflow
    }
    let (expectedTarget, targetOverflow) = token.committedTimestamp.rawValue
      .addingReportingOverflow(duration)
    guard !durationOverflow, !targetOverflow,
      expectedTarget == token.targetTimestamp.rawValue
    else {
      throw TissueError.transaction("joint accepted duration does not reach the root target")
    }
    let submission = try runRootTransaction(
      startTime: token.committedTimestamp,
      candidateDurationsMicroseconds: transaction.resolutions.map(
        \.substep.durationMicroseconds
      ),
      acceptedSubsteps: acceptance,
      schedulerEvents: schedulerEvents
        + transaction.resolutions.lazy
        .filter(\.isAccepted)
        .flatMap(\.receptorEvents)
    )
    guard pendingSchedulerTargetTime == token.targetTimestamp else {
      try abortRootTransaction()
      throw TissueError.transaction("Metal shadow target diverged from the joint token")
    }
    pendingJointTransaction = transaction
    return submission
  }

  public func runRootTransaction(
    at timeMilliseconds: Float,
    acceptedSubsteps: [Bool],
    schedulerEvents: [BrainInterruptEvent] = []
  ) throws -> Submission {
    let startTime = try schedulerTimestamp(milliseconds: timeMilliseconds)
    let nominalDuration = try schedulerTimestamp(
      milliseconds: parameters.timestepMilliseconds
    ).rawValue
    return try runRootTransaction(
      startTime: startTime,
      candidateDurationsMicroseconds: Array(
        repeating: nominalDuration,
        count: acceptedSubsteps.count
      ),
      acceptedSubsteps: acceptedSubsteps,
      schedulerEvents: schedulerEvents
    )
  }

  private func runRootTransaction(
    startTime: BrainTimestamp,
    candidateDurationsMicroseconds: [UInt64],
    acceptedSubsteps: [Bool],
    schedulerEvents: [BrainInterruptEvent]
  ) throws -> Submission {
    guard pendingRootShadowIndex == nil, interactiveJointRoot == nil else {
      throw TissueError.transaction("commit or abort the pending Metal root transaction first")
    }
    guard !acceptedSubsteps.isEmpty else {
      throw TissueError.transaction("a root transaction needs at least one candidate substep")
    }
    guard candidateDurationsMicroseconds.count == acceptedSubsteps.count else {
      throw TissueError.transaction("candidate duration and acceptance ledgers differ in shape")
    }
    guard acceptedSubsteps.count <= maxEncodedSubsteps else {
      throw TissueError.transaction(
        "\(acceptedSubsteps.count) attempts exceed the \(maxEncodedSubsteps)-substep uniform arena"
      )
    }
    let acceptedCount = acceptedSubsteps.lazy.filter({ $0 }).count
    guard acceptedCount > 0 else {
      throw TissueError.transaction("a root transaction must accept simulated time")
    }
    guard acceptedCount <= TissueDelayField.historyCapacity else {
      throw TissueError.transaction(
        "a Metal root transaction cannot accept more than \(TissueDelayField.historyCapacity) delayed substeps"
      )
    }
    let nominalDuration = try schedulerTimestamp(
      milliseconds: parameters.timestepMilliseconds
    ).rawValue
    guard
      candidateDurationsMicroseconds.allSatisfy({
        $0 > 0 && $0 <= nominalDuration
      })
    else {
      throw TissueError.transaction(
        "candidate durations must be positive and no larger than the nominal tissue step"
      )
    }
    var acceptedDuration: UInt64 = 0
    for attempt in acceptedSubsteps.indices where acceptedSubsteps[attempt] {
      let (nextDuration, overflow) = acceptedDuration.addingReportingOverflow(
        candidateDurationsMicroseconds[attempt]
      )
      guard !overflow else {
        throw TissueError.transaction("accepted root duration overflows UInt64")
      }
      acceptedDuration = nextDuration
    }
    let (targetValue, targetOverflow) = startTime.rawValue.addingReportingOverflow(
      acceptedDuration
    )
    guard !targetOverflow else {
      throw TissueError.transaction("root target time overflows UInt64")
    }
    let targetTime = BrainTimestamp(microseconds: targetValue)
    let schedulerWindow = try prepareSchedulerWindow(
      startTime: startTime,
      targetTime: targetTime,
      events: schedulerEvents
    )
    guard committedRegionalStateIndex == schedulerWindow.inputClockIndex else {
      throw TissueError.transaction("regional and scheduler generations diverged")
    }

    var rootShadowIndex = committedIndex
    var acceptedTime = startTime
    var historyOwnerMask = committedHistoryOwnerMask
    var historyStep = committedStep
    var relayHistoryTimestamps = committedRelayHistoryTimestamps

    for attempt in acceptedSubsteps.indices {
      let (nextHistoryStep, historyOverflow) = historyStep.addingReportingOverflow(1)
      guard !historyOverflow else {
        throw TissueError.transaction("tissue history step overflows UInt64")
      }
      let historyWriteSlot = Int(
        nextHistoryStep % UInt64(TissueDelayField.historyCapacity)
      )
      let currentOwner = (historyOwnerMask >> UInt32(historyWriteSlot)) & 1
      let historyWritePlane: UInt32 =
        acceptedSubsteps[attempt]
        ? currentOwner ^ 1
        : 2
      let duration = candidateDurationsMicroseconds[attempt]
      let (candidateTimeValue, candidateTimeOverflow) = acceptedTime.rawValue
        .addingReportingOverflow(duration)
      guard !candidateTimeOverflow else {
        throw TissueError.transaction("candidate timestamp overflows UInt64")
      }
      let candidateTime = BrainTimestamp(microseconds: candidateTimeValue)
      var prospectiveTimestamps = relayHistoryTimestamps
      if acceptedSubsteps[attempt] {
        prospectiveTimestamps[historyWriteSlot] = candidateTime.rawValue
        try validateRelayHistoryCoverage(
          at: candidateTime,
          timestamps: prospectiveTimestamps
        )
      }
      let values = TissueUniforms.encode(
        width: width,
        height: height,
        timeMilliseconds: Float(Double(acceptedTime.rawValue) / 1_000),
        parameters: parameters,
        stimulus: stimulus,
        historyStep: UInt32(historyStep % UInt64(TissueDelayField.historyCapacity)),
        historyOwnerMask: historyOwnerMask,
        historyWriteSlot: UInt32(historyWriteSlot),
        historyWritePlane: historyWritePlane,
        eventCount: eventSchedule.eventCount,
        randomContext: randomContext,
        acceptedStep: historyStep,
        timestepMilliseconds: Float(Double(duration) / 1_000),
        currentTimestamp: acceptedTime,
        candidateTimestamp: candidateTime
      )
      let destination = destinationIndex(rootShadowIndex: rootShadowIndex)
      writeUniforms(values, attempt: attempt)
      if acceptedSubsteps[attempt] {
        rootShadowIndex = destination
        acceptedTime = candidateTime
        historyStep = nextHistoryStep
        relayHistoryTimestamps = prospectiveTimestamps
        historyOwnerMask = settingHistoryOwner(
          mask: historyOwnerMask,
          slot: historyWriteSlot,
          owner: historyWritePlane
        )
      }
    }

    let finalRootShadowIndex = rootShadowIndex
    let finalHistoryOwnerMask = historyOwnerMask
    let finalHistoryStep = historyStep
    let finalRelayHistoryTimestamps = relayHistoryTimestamps

    rootShadowIndex = committedIndex
    let feedback = try submit(label: "NumiBrain tissue root transaction") { encoder in
      for attempt in acceptedSubsteps.indices {
        let uniformAddress =
          uniformBuffer.gpuAddress + UInt64(attempt * TissueUniforms.byteCount)
        eventArgumentTable.setAddress(uniformAddress, index: 0)
        eventArgumentTable.setAddress(eventBuffer.gpuAddress, index: 1)
        eventArgumentTable.setAddress(activeEventIndexBuffer.gpuAddress, index: 2)
        encoder.setComputePipelineState(eventCompactionPipeline)
        encoder.setArgumentTable(eventArgumentTable)
        encoder.dispatchThreads(
          threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
          threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
        )
        encoder.barrier(
          afterEncoderStages: .dispatch,
          beforeEncoderStages: .dispatch,
          visibilityOptions: .device
        )

        let destination = destinationIndex(rootShadowIndex: rootShadowIndex)
        argumentTable.setAddress(stateBuffers[rootShadowIndex].gpuAddress, index: 0)
        argumentTable.setAddress(stateBuffers[destination].gpuAddress, index: 1)
        argumentTable.setAddress(uniformAddress, index: 2)
        argumentTable.setAddress(structureBuffer.gpuAddress, index: 3)
        argumentTable.setAddress(delayBuffer.gpuAddress, index: 4)
        argumentTable.setAddress(relayHistoryBuffer.gpuAddress, index: 5)
        argumentTable.setAddress(relayScratchBuffer.gpuAddress, index: 6)
        argumentTable.setAddress(projectionOffsetBuffer.gpuAddress, index: 7)
        argumentTable.setAddress(projectionEdgeBuffer.gpuAddress, index: 8)
        argumentTable.setAddress(eventBuffer.gpuAddress, index: 9)
        argumentTable.setAddress(activeEventIndexBuffer.gpuAddress, index: 10)
        argumentTable.setAddress(relayHistoryTimestampBuffer.gpuAddress, index: 11)
        encoder.setComputePipelineState(tissuePipeline)
        encoder.setArgumentTable(argumentTable)
        encoder.dispatchThreads(
          threadsPerGrid: MTLSize(width: width, height: height, depth: 1),
          threadsPerThreadgroup: threadgroupSize()
        )
        if attempt != acceptedSubsteps.indices.last {
          encoder.barrier(
            afterEncoderStages: .dispatch,
            beforeEncoderStages: .dispatch,
            visibilityOptions: .device
          )
        }
        if acceptedSubsteps[attempt] {
          rootShadowIndex = destination
        }
      }
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      encodeRootFinalization(encoder, schedulerWindow: schedulerWindow)
    }
    pendingRootShadowIndex = finalRootShadowIndex
    pendingRootShadowOwnerMask = finalHistoryOwnerMask
    pendingRootShadowStep = finalHistoryStep
    pendingRelayHistoryTimestamps = finalRelayHistoryTimestamps
    pendingSchedulerClockIndex = schedulerWindow.outputClockIndex
    pendingSchedulerTargetTime = schedulerWindow.targetTime
    pendingRegionalStateIndex = schedulerWindow.outputClockIndex
    pendingSchedulerInitialized = schedulerWindow.initialize
    hasCommittedSchedulerResult = false
    return Submission(
      parameterVersionFingerprint: parameterVersion.fingerprint,
      attemptedSubsteps: acceptedSubsteps.count,
      acceptedSubsteps: acceptedCount,
      eventCompactionDispatches: acceptedSubsteps.count,
      receptorInterruptTransductionDispatches: 1,
      schedulerDispatches: 1,
      regionalDispatches: 1,
      protectiveDispatches: 1,
      protectiveMotorDispatches: 1,
      schedulerHostInputEventCount: schedulerWindow.hostEventCount,
      schedulerReceptorInputEventCount: schedulerWindow.receptorEventCount,
      schedulerInputEventCount: schedulerWindow.eventCount,
      gpuStartSeconds: feedback.gpuStartTime,
      gpuEndSeconds: feedback.gpuEndTime
    )
  }

  public func commitRootTransaction() throws {
    guard pendingJointTransaction == nil else {
      throw TissueError.transaction(
        "joint roots require commitJointRootTransaction with the accepted physics token"
      )
    }
    try publishRootTransaction()
  }

  public func commitJointRootTransaction() throws -> BrainJointCommitToken {
    guard var transaction = pendingJointTransaction else {
      throw TissueError.transaction("there is no joint Metal root to commit")
    }
    let receipt = try transaction.commit()
    try publishRootTransaction()
    pendingJointTransaction = nil
    return receipt
  }

  private func publishRootTransaction() throws {
    guard let pendingRootShadowIndex, let pendingRootShadowOwnerMask,
      let pendingRootShadowStep, let pendingRelayHistoryTimestamps,
      let pendingSchedulerClockIndex,
      let pendingSchedulerTargetTime, let pendingRegionalStateIndex
    else {
      throw TissueError.transaction("there is no Metal root transaction to commit")
    }
    guard pendingSchedulerInitialized == (committedSchedulerTime == nil) else {
      throw TissueError.transaction("scheduler initialization generation mismatch")
    }
    guard pendingRegionalStateIndex == pendingSchedulerClockIndex else {
      throw TissueError.transaction("regional shadow does not match scheduler shadow")
    }
    let (nextSchedulerGeneration, schedulerGenerationOverflow) =
      committedSchedulerGeneration.addingReportingOverflow(1)
    guard !schedulerGenerationOverflow else {
      throw TissueError.transaction("scheduler generation overflow")
    }
    committedIndex = pendingRootShadowIndex
    committedHistoryOwnerMask = pendingRootShadowOwnerMask
    committedRelayHistoryTimestamps = pendingRelayHistoryTimestamps
    committedStep = pendingRootShadowStep
    committedSchedulerClockIndex = pendingSchedulerClockIndex
    committedRegionalStateIndex = pendingRegionalStateIndex
    committedSchedulerTime = pendingSchedulerTargetTime
    committedSchedulerGeneration = nextSchedulerGeneration
    hasCommittedSchedulerResult = true
    self.pendingRootShadowIndex = nil
    self.pendingRootShadowOwnerMask = nil
    self.pendingRootShadowStep = nil
    self.pendingRelayHistoryTimestamps = nil
    self.pendingSchedulerClockIndex = nil
    self.pendingSchedulerTargetTime = nil
    self.pendingRegionalStateIndex = nil
    self.pendingSchedulerInitialized = false
  }

  public func abortRootTransaction() throws {
    var jointTransaction = pendingJointTransaction
    try discardRootTransaction()
    if jointTransaction != nil {
      try jointTransaction?.abort()
      pendingJointTransaction = nil
    }
  }

  private func discardRootTransaction() throws {
    guard pendingRootShadowIndex != nil else {
      throw TissueError.transaction("there is no Metal root transaction to abort")
    }
    pendingRootShadowIndex = nil
    pendingRootShadowOwnerMask = nil
    pendingRootShadowStep = nil
    pendingRelayHistoryTimestamps = nil
    pendingSchedulerClockIndex = nil
    pendingSchedulerTargetTime = nil
    pendingRegionalStateIndex = nil
    pendingSchedulerInitialized = false
    hasCommittedSchedulerResult = false
  }

  public func snapshotCommitted() throws -> TissueGrid {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading committed state")
    }
    try copy(
      source: stateBuffers[committedIndex],
      destination: stagingBuffer,
      label: "NumiBrain tissue committed inspection"
    )
    let pointer = stagingBuffer.contents()
      .bindMemory(to: TissueCell.self, capacity: width * height)
    let cells = Array(UnsafeBufferPointer(start: pointer, count: width * height))
    return try TissueGrid(width: width, height: height, cells: cells)
  }

  public func snapshotCommittedRelayHistoryTimestamps() throws -> [BrainTimestamp] {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading relay-history timestamps")
    }
    try copy(
      source: relayHistoryTimestampBuffer,
      destination: stagingBuffer,
      size: relayHistoryTimestampByteCount,
      label: "NumiBrain committed relay-history timestamp inspection"
    )
    let timestampPointer = stagingBuffer.contents().bindMemory(
      to: UInt64.self,
      capacity: 2 * TissueDelayField.historyCapacity
    )
    let timestamps = (0..<TissueDelayField.historyCapacity).map { slot in
      let plane = Int((committedHistoryOwnerMask >> UInt32(slot)) & 1)
      return timestampPointer[plane * TissueDelayField.historyCapacity + slot]
    }
    guard timestamps == committedRelayHistoryTimestamps else {
      throw TissueError.metal("GPU relay-history timestamp ownership diverged from the runtime")
    }
    return timestamps.map(BrainTimestamp.init(microseconds:))
  }

  public func inspectCommittedScheduler() throws -> SchedulerInspection {
    guard pendingRootShadowIndex == nil, interactiveJointRoot == nil else {
      throw TissueError.transaction("commit or abort before inspecting scheduler state")
    }
    guard let committedSchedulerTime, hasCommittedSchedulerResult else {
      throw TissueError.transaction("there is no committed scheduler result to inspect")
    }
    return try inspectSchedulerState(
      clockIndex: committedSchedulerClockIndex,
      timestamp: committedSchedulerTime,
      generation: committedSchedulerGeneration,
      label: "NumiBrain committed scheduler inspection"
    )
  }

  /// Explicit inspection readback for the latest accepted physical prefix.
  /// It is unavailable while a tissue candidate is unresolved and is not part
  /// of the GPU-resident control hot path.
  public func inspectInteractiveFastScheduler() throws -> SchedulerInspection {
    guard let root = interactiveJointRoot, root.candidate == nil,
      let window = root.fastSchedulerWindow
    else {
      throw TissueError.transaction("there is no accepted fast scheduler prefix to inspect")
    }
    return try inspectSchedulerState(
      clockIndex: window.outputClockIndex,
      timestamp: root.acceptedTimestamp,
      generation: root.transaction.token.shadowGeneration,
      label: "NumiBrain interactive fast scheduler inspection"
    )
  }

  private func inspectSchedulerState(
    clockIndex: Int,
    timestamp: BrainTimestamp,
    generation: UInt64,
    label: String
  ) throws -> SchedulerInspection {
    let transductionResultOffset = 0
    let resultOffset = MemoryLayout<NBReceptorEventTransductionResult>.stride
    let clockOffset = resultOffset + MemoryLayout<NBSchedulerResult>.stride
    let invocationOffset = clockOffset + schedulerClockByteCount
    _ = try submit(label: label) { encoder in
      encoder.copy(
        sourceBuffer: receptorEventTransductionResultBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: transductionResultOffset,
        size: MemoryLayout<NBReceptorEventTransductionResult>.stride
      )
      encoder.copy(
        sourceBuffer: schedulerResultBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: resultOffset,
        size: MemoryLayout<NBSchedulerResult>.stride
      )
      encoder.copy(
        sourceBuffer: schedulerClockBuffers[clockIndex],
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: clockOffset,
        size: schedulerClockByteCount
      )
      encoder.copy(
        sourceBuffer: schedulerInvocationBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: invocationOffset,
        size: schedulerInvocationCapacityByteCount
      )
    }
    let transductionResult = stagingBuffer.contents()
      .advanced(by: transductionResultOffset)
      .load(as: NBReceptorEventTransductionResult.self)
    guard
      transductionResult.status
        == UInt32(NB_RECEPTOR_TRANSDUCTION_STATUS_VALID.rawValue)
    else {
      throw TissueError.metal(
        "receptor-event transduction reported status \(transductionResult.status)"
      )
    }
    guard transductionResult.event_count <= UInt32(maxSchedulerEvents),
      transductionResult.receptor_event_count <= transductionResult.event_count
    else {
      throw TissueError.metal("receptor-event transduction count exceeds capacity")
    }
    let result = stagingBuffer.contents()
      .advanced(by: resultOffset)
      .load(as: NBSchedulerResult.self)
    guard result.status == UInt32(NB_SCHEDULER_STATUS_VALID.rawValue) else {
      throw TissueError.metal("scheduler kernel reported status \(result.status)")
    }
    guard result.target_time_microseconds == timestamp.rawValue else {
      throw TissueError.metal("scheduler result target does not match inspected time")
    }
    guard result.invocation_count <= UInt32(maxSchedulerInvocations) else {
      throw TissueError.metal("scheduler result invocation count exceeds capacity")
    }
    let clockPointer = stagingBuffer.contents()
      .advanced(by: clockOffset)
      .bindMemory(
        to: NBModuleClockState.self,
        capacity: brainSchedule.modules.count
      )
    let clocks = UnsafeBufferPointer(
      start: clockPointer,
      count: brainSchedule.modules.count
    ).map(BrainModuleClockState.init(abiRecord:))
    let invocationPointer = stagingBuffer.contents()
      .advanced(by: invocationOffset)
      .bindMemory(
        to: NBDueInvocation.self,
        capacity: Int(result.invocation_count)
      )
    let invocations = try UnsafeBufferPointer(
      start: invocationPointer,
      count: Int(result.invocation_count)
    ).map { record in
      guard record.environment_identifier == schedulerEnvironmentIdentifier else {
        throw TissueError.metal("scheduler invocation environment identity drift")
      }
      return try BrainModuleInvocation(abiRecord: record)
    }
    return SchedulerInspection(
      snapshot: BrainSchedulerSnapshot(
        scheduleFingerprint: brainSchedule.fingerprint,
        parameterVersionFingerprint: parameterVersion.fingerprint,
        committedTime: timestamp,
        generation: generation,
        moduleClocks: clocks
      ),
      invocations: invocations,
      status: result.status,
      transducedEventCount: Int(transductionResult.event_count),
      receptorEventCount: Int(transductionResult.receptor_event_count),
      transductionStatus: transductionResult.status
    )
  }

  public func snapshotCommittedScheduler() throws -> BrainSchedulerSnapshot {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading scheduler clocks")
    }
    guard let committedSchedulerTime else {
      throw TissueError.transaction("there is no committed scheduler state to read")
    }
    try copy(
      source: schedulerClockBuffers[committedSchedulerClockIndex],
      destination: stagingBuffer,
      size: schedulerClockByteCount,
      label: "NumiBrain committed scheduler clock inspection"
    )
    let clockPointer = stagingBuffer.contents()
      .bindMemory(
        to: NBModuleClockState.self,
        capacity: brainSchedule.modules.count
      )
    let clocks = UnsafeBufferPointer(
      start: clockPointer,
      count: brainSchedule.modules.count
    ).map(BrainModuleClockState.init(abiRecord:))
    return BrainSchedulerSnapshot(
      scheduleFingerprint: brainSchedule.fingerprint,
      parameterVersionFingerprint: parameterVersion.fingerprint,
      committedTime: committedSchedulerTime,
      generation: committedSchedulerGeneration,
      moduleClocks: clocks
    )
  }

  public func snapshotCommittedRegionalState() throws -> RegionalModuleSnapshot {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading regional state")
    }
    guard let committedSchedulerTime else {
      throw TissueError.transaction("there is no committed regional state to read")
    }
    return try snapshotRegionalState(
      stateIndex: committedRegionalStateIndex,
      timestamp: committedSchedulerTime,
      generation: committedSchedulerGeneration,
      label: "NumiBrain committed regional-state inspection"
    )
  }

  /// Explicit inspection readback of the regional shadow produced after the
  /// latest accepted physical substep. It never publishes that shadow.
  public func snapshotInteractiveFastRegionalState() throws -> RegionalModuleSnapshot {
    guard let root = interactiveJointRoot, root.candidate == nil,
      let window = root.fastSchedulerWindow
    else {
      throw TissueError.transaction("there is no accepted fast regional prefix to inspect")
    }
    return try snapshotRegionalState(
      stateIndex: window.outputClockIndex,
      timestamp: root.acceptedTimestamp,
      generation: root.transaction.token.shadowGeneration,
      label: "NumiBrain interactive fast regional-state inspection"
    )
  }

  public func snapshotCommittedProtectiveCommand() throws -> ProtectiveMotorCommand {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading protective output")
    }
    return try snapshotProtectiveCommand(
      stateIndex: committedRegionalStateIndex,
      timestamp: committedSchedulerTime ?? BrainTimestamp(microseconds: 0),
      generation: committedSchedulerGeneration,
      label: "NumiBrain committed protective-command inspection"
    )
  }

  /// Explicit inspection readback for tests and diagnostics. The normal
  /// physics bridge consumes `FastSystemResult.protectiveCommand` on the GPU.
  public func snapshotInteractiveProtectiveCommand() throws -> ProtectiveMotorCommand {
    guard let root = interactiveJointRoot, root.candidate == nil,
      let window = root.fastSchedulerWindow
    else {
      throw TissueError.transaction("there is no accepted protective command to inspect")
    }
    return try snapshotProtectiveCommand(
      stateIndex: window.outputClockIndex,
      timestamp: root.acceptedTimestamp,
      generation: root.transaction.token.shadowGeneration,
      label: "NumiBrain interactive protective-command inspection"
    )
  }

  public func snapshotCommittedProtectiveMotorOutput() throws -> ProtectiveMotorOutput {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading protective motor output")
    }
    return try snapshotProtectiveMotorOutput(
      stateIndex: committedRegionalStateIndex,
      timestamp: committedSchedulerTime ?? BrainTimestamp(microseconds: 0),
      generation: committedSchedulerGeneration,
      label: "NumiBrain committed protective-motor inspection"
    )
  }

  /// Explicit inspection readback for tests and diagnostics. The normal
  /// physics bridge consumes the paired GPU addresses in `FastSystemResult`.
  public func snapshotInteractiveProtectiveMotorOutput() throws -> ProtectiveMotorOutput {
    guard let root = interactiveJointRoot, root.candidate == nil,
      let window = root.fastSchedulerWindow
    else {
      throw TissueError.transaction("there is no accepted protective motor output to inspect")
    }
    return try snapshotProtectiveMotorOutput(
      stateIndex: window.outputClockIndex,
      timestamp: root.acceptedTimestamp,
      generation: root.transaction.token.shadowGeneration,
      label: "NumiBrain interactive protective-motor inspection"
    )
  }

  private func snapshotProtectiveCommand(
    stateIndex: Int,
    timestamp: BrainTimestamp,
    generation: UInt64,
    label: String
  ) throws -> ProtectiveMotorCommand {
    try copy(
      source: protectiveCommandBuffers[stateIndex],
      destination: stagingBuffer,
      size: ProtectiveMotorCommand.byteCount,
      label: label
    )
    let record = stagingBuffer.contents().load(as: NBProtectiveCommand.self)
    let command = try ProtectiveMotorCommand(validating: record)
    guard command.timestamp == timestamp, command.brainGeneration == generation,
      command.environmentIdentifier == schedulerEnvironmentIdentifier
    else {
      throw TissueError.metal("protective command identity diverged from its state generation")
    }
    return command
  }

  private func snapshotProtectiveMotorOutput(
    stateIndex: Int,
    timestamp: BrainTimestamp,
    generation: UInt64,
    label: String
  ) throws -> ProtectiveMotorOutput {
    try copy(
      source: protectiveMotorOutputHeaderBuffers[stateIndex],
      destination: stagingBuffer,
      size: ProtectiveMotorOutput.headerByteCount,
      label: "\(label) header"
    )
    let header = stagingBuffer.contents().load(as: NBMotorOutputHeader.self)
    try copy(
      source: protectiveMuscleExcitationBuffers[stateIndex],
      destination: stagingBuffer,
      size: protectiveMuscleExcitationByteCount,
      label: "\(label) excitations"
    )
    let pointer = stagingBuffer.contents().bindMemory(
      to: Float.self,
      capacity: protectiveMotorProfile.channels.count
    )
    let excitations = Array(
      UnsafeBufferPointer(start: pointer, count: protectiveMotorProfile.channels.count)
    )
    let output = try ProtectiveMotorOutput(
      validating: header,
      muscleExcitations: excitations,
      expectedProfile: protectiveMotorProfile
    )
    guard output.timestamp == timestamp, output.brainGeneration == generation,
      output.environmentIdentifier == schedulerEnvironmentIdentifier
    else {
      throw TissueError.metal("protective motor output identity diverged from its state generation")
    }
    return output
  }

  private func snapshotRegionalState(
    stateIndex: Int,
    timestamp: BrainTimestamp,
    generation: UInt64,
    label: String
  ) throws -> RegionalModuleSnapshot {
    try copy(
      source: regionalStateBuffers[stateIndex],
      destination: stagingBuffer,
      size: regionalStateByteCount,
      label: label
    )
    let statePointer = stagingBuffer.contents()
      .bindMemory(
        to: NBRegionalModuleState.self,
        capacity: brainSchedule.modules.count
      )
    let states = UnsafeBufferPointer(
      start: statePointer,
      count: brainSchedule.modules.count
    ).map(RegionalModuleState.init(abiRecord:))
    return RegionalModuleSnapshot(
      scheduleFingerprint: brainSchedule.fingerprint,
      committedTime: timestamp,
      generation: generation,
      states: states
    )
  }

  public func snapshotCommittedRegionalTokens() throws -> RegionalTokenSnapshot {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading regional tokens")
    }
    guard let committedSchedulerTime else {
      throw TissueError.transaction("there is no committed regional token state to read")
    }
    try copy(
      source: regionalTokenStateBuffers[committedRegionalStateIndex],
      destination: stagingBuffer,
      size: regionalTokenStateByteCount,
      label: "NumiBrain committed regional-token inspection"
    )
    let values = Array(
      UnsafeBufferPointer(
        start: stagingBuffer.contents().bindMemory(
          to: Float.self,
          capacity: regionalTokenProgram.scalarCount
        ),
        count: regionalTokenProgram.scalarCount
      )
    )
    return RegionalTokenSnapshot(
      scheduleFingerprint: brainSchedule.fingerprint,
      programFingerprint: regionalTokenProgram.fingerprint,
      committedTime: committedSchedulerTime,
      generation: committedSchedulerGeneration,
      values: values
    )
  }

  public func snapshotCommittedRegionalRouteHistory() throws
    -> RegionalRouteHistorySnapshot
  {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading regional route history")
    }
    guard let committedSchedulerTime else {
      throw TissueError.transaction("there is no committed regional route history to read")
    }
    let states: [RegionalRouteHistoryState]
    if regionalTokenProgram.routes.isEmpty {
      states = []
    } else {
      try copy(
        source: regionalRouteHistoryStateBuffers[committedRegionalStateIndex],
        destination: stagingBuffer,
        size: regionalRouteHistoryStateByteCount,
        label: "NumiBrain committed regional route-history metadata inspection"
      )
      let statePointer = stagingBuffer.contents().bindMemory(
        to: NBRegionalRouteHistoryState.self,
        capacity: regionalTokenProgram.routes.count
      )
      states = UnsafeBufferPointer(
        start: statePointer,
        count: regionalTokenProgram.routes.count
      ).map(RegionalRouteHistoryState.init(abiRecord:))
    }
    let timestampCount =
      regionalTokenProgram.routes.count
      * regionalTokenProgram.compiledRouteHistoryCapacity
    let timestamps: [UInt64]
    if timestampCount == 0 {
      timestamps = []
    } else {
      try copy(
        source: regionalRouteHistoryTimestampBuffers[committedRegionalStateIndex],
        destination: stagingBuffer,
        size: regionalRouteHistoryTimestampByteCount,
        label: "NumiBrain committed regional route-history timestamp inspection"
      )
      timestamps = Array(
        UnsafeBufferPointer(
          start: stagingBuffer.contents().bindMemory(
            to: UInt64.self,
            capacity: timestampCount
          ),
          count: timestampCount
        )
      )
    }
    let values: [Float]
    if regionalTokenProgram.routeHistoryScalarCount == 0 {
      values = []
    } else {
      try copy(
        source: regionalRouteHistoryValueBuffers[committedRegionalStateIndex],
        destination: stagingBuffer,
        size: regionalRouteHistoryValueByteCount,
        label: "NumiBrain committed regional route-history value inspection"
      )
      values = Array(
        UnsafeBufferPointer(
          start: stagingBuffer.contents().bindMemory(
            to: Float.self,
            capacity: regionalTokenProgram.routeHistoryScalarCount
          ),
          count: regionalTokenProgram.routeHistoryScalarCount
        )
      )
    }
    let history = try RegionalRouteHistory(
      program: regionalTokenProgram,
      states: states,
      timestamps: timestamps,
      values: values
    )
    return RegionalRouteHistorySnapshot(
      scheduleFingerprint: brainSchedule.fingerprint,
      programFingerprint: regionalTokenProgram.fingerprint,
      committedTime: committedSchedulerTime,
      generation: committedSchedulerGeneration,
      history: history
    )
  }

  public func snapshotCommittedRegionalRoutingState() throws -> RegionalRoutingSnapshot {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading regional routing state")
    }
    guard let committedSchedulerTime else {
      throw TissueError.transaction("there is no committed regional routing state to read")
    }
    let states: [RegionalRouteRuntimeState]
    if regionalTokenProgram.routes.isEmpty {
      states = []
    } else {
      try copy(
        source: regionalRouteRuntimeStateBuffers[committedRegionalStateIndex],
        destination: stagingBuffer,
        size: regionalRouteRuntimeStateByteCount,
        label: "NumiBrain committed regional routing-state inspection"
      )
      let statePointer = stagingBuffer.contents().bindMemory(
        to: NBRegionalRouteRuntimeState.self,
        capacity: regionalTokenProgram.routes.count
      )
      states = UnsafeBufferPointer(
        start: statePointer,
        count: regionalTokenProgram.routes.count
      ).map(RegionalRouteRuntimeState.init(abiRecord:))
    }
    let routingState = try RegionalRoutingState(
      program: regionalTokenProgram,
      states: states
    )
    return RegionalRoutingSnapshot(
      scheduleFingerprint: brainSchedule.fingerprint,
      programFingerprint: regionalTokenProgram.fingerprint,
      committedTime: committedSchedulerTime,
      generation: committedSchedulerGeneration,
      routingState: routingState
    )
  }

  private func encodeRootFinalization(
    _ encoder: any MTL4ComputeCommandEncoder,
    schedulerWindow: PreparedSchedulerWindow
  ) {
    receptorInterruptArgumentTable.setAddress(
      receptorEventTransductionUniformBuffer.gpuAddress,
      index: 0
    )
    receptorInterruptArgumentTable.setAddress(eventBuffer.gpuAddress, index: 1)
    receptorInterruptArgumentTable.setAddress(
      schedulerEventUploadBuffer.gpuAddress,
      index: 2
    )
    receptorInterruptArgumentTable.setAddress(
      transducedSchedulerEventBuffer.gpuAddress,
      index: 3
    )
    receptorInterruptArgumentTable.setAddress(
      receptorEventTransductionResultBuffer.gpuAddress,
      index: 4
    )
    encoder.setComputePipelineState(receptorInterruptTransductionPipeline)
    encoder.setArgumentTable(receptorInterruptArgumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
    schedulerArgumentTable.setAddress(schedulerUniformBuffer.gpuAddress, index: 0)
    schedulerArgumentTable.setAddress(schedulerDescriptorBuffer.gpuAddress, index: 1)
    schedulerArgumentTable.setAddress(
      schedulerClockBuffers[schedulerWindow.inputClockIndex].gpuAddress,
      index: 2
    )
    schedulerArgumentTable.setAddress(
      schedulerClockBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 3
    )
    schedulerArgumentTable.setAddress(transducedSchedulerEventBuffer.gpuAddress, index: 4)
    schedulerArgumentTable.setAddress(schedulerInvocationBuffer.gpuAddress, index: 5)
    schedulerArgumentTable.setAddress(schedulerResultBuffer.gpuAddress, index: 6)
    schedulerArgumentTable.setAddress(
      receptorEventTransductionResultBuffer.gpuAddress,
      index: 7
    )
    schedulerArgumentTable.setAddress(parameterVersionBindingBuffer.gpuAddress, index: 8)
    encoder.setComputePipelineState(schedulerPipeline)
    encoder.setArgumentTable(schedulerArgumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
    regionalArgumentTable.setAddress(regionalProgramHeaderBuffer.gpuAddress, index: 0)
    regionalArgumentTable.setAddress(schedulerDescriptorBuffer.gpuAddress, index: 1)
    regionalArgumentTable.setAddress(regionalLayoutBuffer.gpuAddress, index: 2)
    regionalArgumentTable.setAddress(regionalRouteBuffer.gpuAddress, index: 3)
    regionalArgumentTable.setAddress(regionalParameterBuffer.gpuAddress, index: 4)
    regionalArgumentTable.setAddress(schedulerResultBuffer.gpuAddress, index: 5)
    regionalArgumentTable.setAddress(schedulerInvocationBuffer.gpuAddress, index: 6)
    regionalArgumentTable.setAddress(
      regionalStateBuffers[committedRegionalStateIndex].gpuAddress,
      index: 7
    )
    regionalArgumentTable.setAddress(
      regionalStateBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 8
    )
    regionalArgumentTable.setAddress(
      regionalTokenStateBuffers[committedRegionalStateIndex].gpuAddress,
      index: 9
    )
    regionalArgumentTable.setAddress(
      regionalTokenStateBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 10
    )
    regionalArgumentTable.setAddress(regionalTokenCandidateBuffer.gpuAddress, index: 11)
    regionalArgumentTable.setAddress(
      regionalRouteHistoryStateBuffers[committedRegionalStateIndex].gpuAddress,
      index: 12
    )
    regionalArgumentTable.setAddress(
      regionalRouteHistoryStateBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 13
    )
    regionalArgumentTable.setAddress(
      regionalRouteHistoryTimestampBuffers[committedRegionalStateIndex].gpuAddress,
      index: 14
    )
    regionalArgumentTable.setAddress(
      regionalRouteHistoryTimestampBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 15
    )
    regionalArgumentTable.setAddress(
      regionalRouteHistoryValueBuffers[committedRegionalStateIndex].gpuAddress,
      index: 16
    )
    regionalArgumentTable.setAddress(
      regionalRouteHistoryValueBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 17
    )
    regionalArgumentTable.setAddress(
      regionalResolvedRouteHistorySlotBuffer.gpuAddress,
      index: 18
    )
    regionalArgumentTable.setAddress(
      regionalRouteRuntimeStateBuffers[committedRegionalStateIndex].gpuAddress,
      index: 19
    )
    regionalArgumentTable.setAddress(
      regionalRouteRuntimeStateBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 20
    )
    regionalArgumentTable.setAddress(
      regionalSelectedRouteIndexBuffer.gpuAddress,
      index: 21
    )
    regionalArgumentTable.setAddress(
      regionalSelectedRouteCountBuffer.gpuAddress,
      index: 22
    )
    regionalArgumentTable.setAddress(parameterVersionBindingBuffer.gpuAddress, index: 23)
    encoder.setComputePipelineState(regionalPipeline)
    encoder.setArgumentTable(regionalArgumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: regionalThreadgroupSize(),
      threadsPerThreadgroup: regionalThreadgroupSize()
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
    protectiveArgumentTable.setAddress(schedulerResultBuffer.gpuAddress, index: 0)
    protectiveArgumentTable.setAddress(schedulerInvocationBuffer.gpuAddress, index: 1)
    protectiveArgumentTable.setAddress(schedulerDescriptorBuffer.gpuAddress, index: 2)
    protectiveArgumentTable.setAddress(
      regionalStateBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 3
    )
    protectiveArgumentTable.setAddress(protectiveCommandUniformBuffer.gpuAddress, index: 4)
    protectiveArgumentTable.setAddress(
      protectiveCommandBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 5
    )
    encoder.setComputePipelineState(protectivePipeline)
    encoder.setArgumentTable(protectiveArgumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
    protectiveMotorArgumentTable.setAddress(
      protectiveCommandBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 0
    )
    protectiveMotorArgumentTable.setAddress(protectiveMotorProfileBuffer.gpuAddress, index: 1)
    protectiveMotorArgumentTable.setAddress(protectiveCommandUniformBuffer.gpuAddress, index: 2)
    protectiveMotorArgumentTable.setAddress(
      protectiveMotorOutputHeaderBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 3
    )
    protectiveMotorArgumentTable.setAddress(
      protectiveMuscleExcitationBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 4
    )
    encoder.setComputePipelineState(protectiveMotorPipeline)
    encoder.setArgumentTable(protectiveMotorArgumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
  }

  private struct PreparedSchedulerWindow {
    let targetTime: BrainTimestamp
    let inputClockIndex: Int
    let outputClockIndex: Int
    let hostEventCount: Int
    let receptorEventCount: Int
    let eventCount: Int
    let initialize: Bool
  }

  private func prepareSchedulerWindow(
    startTime: BrainTimestamp,
    targetTime: BrainTimestamp,
    events: [BrainInterruptEvent]
  ) throws -> PreparedSchedulerWindow {
    if let committedSchedulerTime, startTime != committedSchedulerTime {
      throw TissueError.transaction(
        "root time does not match committed scheduler time \(committedSchedulerTime.rawValue) us"
      )
    }
    guard targetTime > startTime else {
      throw TissueError.transaction("scheduler target must advance physical time")
    }
    let duration = targetTime.rawValue - startTime.rawValue
    let targetMicroseconds = targetTime.rawValue
    let initialize = committedSchedulerTime == nil
    let canonicalEvents = events.sorted { lhs, rhs in
      if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
      if lhs.identifier != rhs.identifier { return lhs.identifier < rhs.identifier }
      if lhs.mask.rawValue != rhs.mask.rawValue {
        return lhs.mask.rawValue < rhs.mask.rawValue
      }
      return lhs.flags < rhs.flags
    }
    guard
      canonicalEvents.allSatisfy({
        $0.timestamp >= startTime && $0.timestamp <= targetTime
      })
    else {
      throw TissueError.transaction("scheduler event lies outside the root time window")
    }
    let receptorEvents = try eventSchedule.schedulerInterruptEvents(
      committedTime: startTime,
      targetTime: targetTime,
      includeCommittedBoundary: initialize
    )
    let totalEventCount = canonicalEvents.count + receptorEvents.count
    guard totalEventCount <= maxSchedulerEvents else {
      throw TissueError.transaction(
        "\(totalEventCount) host and receptor scheduler events exceed capacity \(maxSchedulerEvents)"
      )
    }

    var invocationUpperBound: UInt64 = 0
    for module in brainSchedule.modules {
      guard targetMicroseconds <= UInt64.max - UInt64(module.periodMicroseconds) else {
        throw TissueError.transaction("scheduler next-due time would overflow UInt64")
      }
      let periodic = duration / UInt64(module.periodMicroseconds) + 2
      let (next, overflow) = invocationUpperBound.addingReportingOverflow(periodic)
      guard !overflow else {
        throw TissueError.transaction("scheduler invocation bound overflows UInt64")
      }
      invocationUpperBound = next
    }
    let (interruptBound, interruptOverflow) = UInt64(totalEventCount)
      .multipliedReportingOverflow(by: UInt64(brainSchedule.modules.count))
    let (totalBound, totalOverflow) =
      invocationUpperBound
      .addingReportingOverflow(interruptBound)
    guard !interruptOverflow, !totalOverflow,
      totalBound <= UInt64(maxSchedulerInvocations)
    else {
      throw TissueError.transaction(
        "scheduler window may exceed invocation capacity \(maxSchedulerInvocations)"
      )
    }

    let eventRecords = canonicalEvents.map(\.abiRecord)
    eventRecords.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      schedulerEventUploadBuffer.contents().copyMemory(
        from: source,
        byteCount: bytes.count
      )
    }
    var transductionUniforms = NBReceptorEventTransductionUniforms()
    transductionUniforms.committed_time_microseconds = startTime.rawValue
    transductionUniforms.target_time_microseconds = targetTime.rawValue
    transductionUniforms.receptor_event_count = UInt32(eventSchedule.eventCount)
    transductionUniforms.host_event_count = UInt32(eventRecords.count)
    transductionUniforms.event_capacity = UInt32(maxSchedulerEvents)
    transductionUniforms.flags = initialize ? 1 : 0
    transductionUniforms.reserved_0 = 0
    transductionUniforms.reserved_1 = 0
    withUnsafeBytes(of: &transductionUniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      receptorEventTransductionUniformBuffer.contents().copyMemory(
        from: source,
        byteCount: MemoryLayout<NBReceptorEventTransductionUniforms>.stride
      )
    }
    var uniforms = NBSchedulerUniforms()
    uniforms.committed_time_microseconds = startTime.rawValue
    uniforms.target_time_microseconds = targetTime.rawValue
    uniforms.parameter_version_fingerprint = parameterVersion.fingerprint
    uniforms.schedule_fingerprint = brainSchedule.fingerprint
    uniforms.module_count = UInt32(brainSchedule.modules.count)
    uniforms.event_count = UInt32(totalEventCount)
    uniforms.invocation_capacity = UInt32(maxSchedulerInvocations)
    uniforms.environment_identifier = schedulerEnvironmentIdentifier
    uniforms.flags = initialize ? 1 : 0
    uniforms.reserved = 0
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      schedulerUniformBuffer.contents().copyMemory(
        from: source,
        byteCount: MemoryLayout<NBSchedulerUniforms>.stride
      )
    }
    let (protectiveGeneration, protectiveGenerationOverflow) =
      committedSchedulerGeneration.addingReportingOverflow(1)
    guard !protectiveGenerationOverflow else {
      throw TissueError.transaction("protective command generation overflows UInt64")
    }
    var protectiveUniforms = ProtectiveCommandUniforms(
      brainGeneration: protectiveGeneration,
      motorProfileFingerprint: protectiveMotorProfile.fingerprint,
      moduleCount: UInt32(brainSchedule.modules.count),
      muscleCount: UInt32(protectiveMotorProfile.channels.count),
      environmentIdentifier: schedulerEnvironmentIdentifier,
      reserved: 0
    )
    withUnsafeBytes(of: &protectiveUniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      protectiveCommandUniformBuffer.contents().copyMemory(
        from: source,
        byteCount: MemoryLayout<ProtectiveCommandUniforms>.stride
      )
    }
    let outputClockIndex = 1 - committedSchedulerClockIndex
    return PreparedSchedulerWindow(
      targetTime: targetTime,
      inputClockIndex: committedSchedulerClockIndex,
      outputClockIndex: outputClockIndex,
      hostEventCount: canonicalEvents.count,
      receptorEventCount: receptorEvents.count,
      eventCount: totalEventCount,
      initialize: initialize
    )
  }

  private func schedulerTimestamp(milliseconds: Float) throws -> BrainTimestamp {
    guard milliseconds.isFinite, milliseconds >= 0 else {
      throw TissueError.transaction("scheduler time must be finite and nonnegative")
    }
    let scaled = Double(milliseconds) * 1_000
    let rounded = scaled.rounded()
    guard rounded < Double(UInt64.max), abs(scaled - rounded) <= 0.01 else {
      throw TissueError.transaction("scheduler time is not representable in integer microseconds")
    }
    return BrainTimestamp(microseconds: UInt64(rounded))
  }

  private func validateRelayHistoryCoverage(
    at timestamp: BrainTimestamp,
    timestamps: [UInt64]
  ) throws {
    guard timestamps.count == TissueDelayField.historyCapacity else {
      throw TissueError.transaction("relay-history timestamp shape is invalid")
    }
    let target =
      maximumTissueDelayMicroseconds >= timestamp.rawValue
      ? UInt64(0)
      : timestamp.rawValue - maximumTissueDelayMicroseconds
    guard timestamps.contains(where: { $0 <= target }) else {
      throw TissueError.transaction(
        "physical relay history no longer covers target timestamp \(target) us"
      )
    }
  }

  private func destinationIndex(rootShadowIndex: Int) -> Int {
    (0..<stateBuffers.count).first {
      $0 != committedIndex && $0 != rootShadowIndex
    }!
  }

  private func settingHistoryOwner(
    mask: UInt32,
    slot: Int,
    owner: UInt32
  ) -> UInt32 {
    let bit = UInt32(1) << UInt32(slot)
    return owner == 0 ? mask & ~bit : mask | bit
  }

  private func writeUniforms(_ values: [Float], attempt: Int) {
    let destination = uniformBuffer.contents()
      .advanced(by: attempt * TissueUniforms.byteCount)
    values.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      destination.copyMemory(from: source, byteCount: TissueUniforms.byteCount)
    }
  }

  private struct FeedbackSnapshot {
    let gpuStartTime: Double
    let gpuEndTime: Double
  }

  private func copy(
    source: any MTLBuffer,
    destination: any MTLBuffer,
    size: Int? = nil,
    label: String
  ) throws {
    let size = size ?? stateByteCount
    _ = try submit(label: label) { encoder in
      encoder.copy(
        sourceBuffer: source,
        sourceOffset: 0,
        destinationBuffer: destination,
        destinationOffset: 0,
        size: size
      )
    }
  }

  private func seedRelayHistory() throws {
    _ = try submit(label: "NumiBrain relay history seed") { encoder in
      for plane in 0..<2 {
        for slot in 0..<TissueDelayField.historyCapacity {
          encoder.copy(
            sourceBuffer: stagingBuffer,
            sourceOffset: 0,
            destinationBuffer: relayHistoryBuffer,
            destinationOffset: (plane * TissueDelayField.historyCapacity + slot)
              * relayByteCount,
            size: relayByteCount
          )
        }
      }
    }
  }

  private func submit(
    label: String,
    encode: (any MTL4ComputeCommandEncoder) -> Void
  ) throws -> FeedbackSnapshot {
    commandAllocator.reset()
    commandBuffer.beginCommandBuffer(allocator: commandAllocator)
    commandBuffer.useResidencySet(residencySet)
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
      commandBuffer.endCommandBuffer()
      throw TissueError.metal("failed to create a Metal 4 compute command encoder")
    }
    encoder.label = label
    encode(encoder)
    encoder.endEncoding()
    commandBuffer.endCommandBuffer()

    let semaphore = DispatchSemaphore(value: 0)
    let options = MTL4CommitOptions()
    final class FeedbackBox: @unchecked Sendable {
      var feedback: (any MTL4CommitFeedback)?
    }
    let box = FeedbackBox()
    options.addFeedbackHandler { feedback in
      box.feedback = feedback
      semaphore.signal()
    }
    commandQueue.commit([commandBuffer], options: options)
    semaphore.wait()
    guard let feedback = box.feedback else {
      throw TissueError.metal("Metal 4 submission completed without feedback")
    }
    if let error = feedback.error {
      throw TissueError.metal("GPU execution failed during \(label): \(error)")
    }
    return FeedbackSnapshot(
      gpuStartTime: feedback.gpuStartTime,
      gpuEndTime: feedback.gpuEndTime
    )
  }

  private func threadgroupSize() -> MTLSize {
    let width = min(16, tissuePipeline.threadExecutionWidth)
    let height = max(1, min(16, tissuePipeline.maxTotalThreadsPerThreadgroup / width))
    return MTLSize(width: width, height: height, depth: 1)
  }

  private func regionalThreadgroupSize() -> MTLSize {
    MTLSize(
      width: min(256, regionalPipeline.maxTotalThreadsPerThreadgroup),
      height: 1,
      depth: 1
    )
  }
}

import Foundation
@preconcurrency import Metal
import NumiBrainABI
import NumiBrainCore

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
    public let schedulerHostInputEventCount: Int
    public let schedulerReceptorInputEventCount: Int
    public let schedulerInputEventCount: Int
    public let gpuStartSeconds: Double
    public let gpuEndSeconds: Double

    public var gpuDurationSeconds: Double {
      max(gpuEndSeconds - gpuStartSeconds, 0)
    }
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
  private let argumentTable: any MTL4ArgumentTable
  private let eventArgumentTable: any MTL4ArgumentTable
  private let receptorInterruptArgumentTable: any MTL4ArgumentTable
  private let schedulerArgumentTable: any MTL4ArgumentTable
  private let regionalArgumentTable: any MTL4ArgumentTable
  private let residencySet: any MTLResidencySet
  private let stateBuffers: [any MTLBuffer]
  private let structureBuffer: any MTLBuffer
  private let delayBuffer: any MTLBuffer
  private let relayHistoryBuffer: any MTLBuffer
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
  private let stagingBuffer: any MTLBuffer
  private let stateByteCount: Int
  private let relayByteCount: Int
  public let relayHistoryByteCount: Int
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

  private var committedIndex = 0
  private var committedHistoryOwnerMask: UInt32 = 0
  private var pendingRootShadowIndex: Int?
  private var pendingRootShadowOwnerMask: UInt32?
  private var pendingRootShadowStep: UInt64?
  private var committedSchedulerClockIndex = 0
  private var committedSchedulerTime: BrainTimestamp?
  private var committedSchedulerGeneration: UInt64 = 0
  private var committedRegionalStateIndex = 0
  private var pendingSchedulerClockIndex: Int?
  private var pendingSchedulerTargetTime: BrainTimestamp?
  private var pendingRegionalStateIndex: Int?
  private var pendingSchedulerInitialized = false
  private var hasCommittedSchedulerResult = false

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
    let tissuePipeline: any MTLComputePipelineState
    let eventCompactionPipeline: any MTLComputePipelineState
    let receptorInterruptTransductionPipeline: any MTLComputePipelineState
    let schedulerPipeline: any MTLComputePipelineState
    let regionalPipeline: any MTLComputePipelineState
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
    } catch {
      throw TissueError.metal(
        "tissue, event/transduction, scheduler, or regional pipeline creation failed: \(error)"
      )
    }

    let argumentDescriptor = MTL4ArgumentTableDescriptor()
    argumentDescriptor.label = "NumiBrain tissue arguments"
    argumentDescriptor.maxBufferBindCount = 11
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
      let relayScratchBuffer = device.makeBuffer(
        length: relayByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate private conduction history buffers")
    }
    delayBuffer.label = "NumiBrain immutable conduction delays"
    relayHistoryBuffer.label = "NumiBrain transactional relay history"
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
        == Int(NB_PARAMETER_VERSION_BINDING_BYTE_COUNT)
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
                regionalUploadByteCount
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
    residencyDescriptor.initialCapacity = stateBuffers.count + 41
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
    self.schedulerEnvironmentIdentifier = schedulerEnvironmentIdentifier
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
    self.argumentTable = argumentTable
    self.eventArgumentTable = eventArgumentTable
    self.receptorInterruptArgumentTable = receptorInterruptArgumentTable
    self.schedulerArgumentTable = schedulerArgumentTable
    self.regionalArgumentTable = regionalArgumentTable
    self.residencySet = residencySet
    self.stateBuffers = stateBuffers
    self.structureBuffer = structureBuffer
    self.delayBuffer = delayBuffer
    self.relayHistoryBuffer = relayHistoryBuffer
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
    self.stagingBuffer = stagingBuffer
    self.stateByteCount = stateByteCount
    self.relayByteCount = relayByteCount
    self.relayHistoryByteCount = relayHistoryByteCount
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
  }

  deinit {
    residencySet.endResidency()
  }

  public var hasPendingRootTransaction: Bool {
    pendingRootShadowIndex != nil
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

  public func runRootTransaction(
    at timeMilliseconds: Float,
    acceptedSubsteps: [Bool],
    schedulerEvents: [BrainInterruptEvent] = []
  ) throws -> Submission {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort the pending Metal root transaction first")
    }
    guard timeMilliseconds.isFinite else {
      throw TissueError.transaction("root time must be finite")
    }
    guard !acceptedSubsteps.isEmpty else {
      throw TissueError.transaction("a root transaction needs at least one candidate substep")
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
    let schedulerWindow = try prepareSchedulerWindow(
      timeMilliseconds: timeMilliseconds,
      acceptedSubstepCount: acceptedCount,
      events: schedulerEvents
    )
    guard committedRegionalStateIndex == schedulerWindow.inputClockIndex else {
      throw TissueError.transaction("regional and scheduler generations diverged")
    }

    var rootShadowIndex = committedIndex
    var acceptedTime = timeMilliseconds
    var historyOwnerMask = committedHistoryOwnerMask
    var historyStep = committedStep

    for attempt in acceptedSubsteps.indices {
      let nextHistoryStep = historyStep + 1
      let historyWriteSlot = Int(
        nextHistoryStep % UInt64(TissueDelayField.historyCapacity)
      )
      let currentOwner = (historyOwnerMask >> UInt32(historyWriteSlot)) & 1
      let historyWritePlane: UInt32 =
        acceptedSubsteps[attempt]
        ? currentOwner ^ 1
        : 2
      let values = TissueUniforms.encode(
        width: width,
        height: height,
        timeMilliseconds: acceptedTime,
        parameters: parameters,
        stimulus: stimulus,
        historyStep: UInt32(historyStep % UInt64(TissueDelayField.historyCapacity)),
        historyOwnerMask: historyOwnerMask,
        historyWriteSlot: UInt32(historyWriteSlot),
        historyWritePlane: historyWritePlane,
        eventCount: eventSchedule.eventCount,
        randomContext: randomContext,
        acceptedStep: historyStep
      )
      let destination = destinationIndex(rootShadowIndex: rootShadowIndex)
      writeUniforms(values, attempt: attempt)
      if acceptedSubsteps[attempt] {
        rootShadowIndex = destination
        acceptedTime += parameters.timestepMilliseconds
        historyStep = nextHistoryStep
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
    }
    pendingRootShadowIndex = finalRootShadowIndex
    pendingRootShadowOwnerMask = finalHistoryOwnerMask
    pendingRootShadowStep = finalHistoryStep
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
      schedulerHostInputEventCount: schedulerWindow.hostEventCount,
      schedulerReceptorInputEventCount: schedulerWindow.receptorEventCount,
      schedulerInputEventCount: schedulerWindow.eventCount,
      gpuStartSeconds: feedback.gpuStartTime,
      gpuEndSeconds: feedback.gpuEndTime
    )
  }

  public func commitRootTransaction() throws {
    guard let pendingRootShadowIndex, let pendingRootShadowOwnerMask,
      let pendingRootShadowStep, let pendingSchedulerClockIndex,
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
    committedStep = pendingRootShadowStep
    committedSchedulerClockIndex = pendingSchedulerClockIndex
    committedRegionalStateIndex = pendingRegionalStateIndex
    committedSchedulerTime = pendingSchedulerTargetTime
    committedSchedulerGeneration = nextSchedulerGeneration
    hasCommittedSchedulerResult = true
    self.pendingRootShadowIndex = nil
    self.pendingRootShadowOwnerMask = nil
    self.pendingRootShadowStep = nil
    self.pendingSchedulerClockIndex = nil
    self.pendingSchedulerTargetTime = nil
    self.pendingRegionalStateIndex = nil
    self.pendingSchedulerInitialized = false
  }

  public func abortRootTransaction() throws {
    guard pendingRootShadowIndex != nil else {
      throw TissueError.transaction("there is no Metal root transaction to abort")
    }
    pendingRootShadowIndex = nil
    pendingRootShadowOwnerMask = nil
    pendingRootShadowStep = nil
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

  public func inspectCommittedScheduler() throws -> SchedulerInspection {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before inspecting scheduler state")
    }
    guard let committedSchedulerTime, hasCommittedSchedulerResult else {
      throw TissueError.transaction("there is no committed scheduler result to inspect")
    }
    let transductionResultOffset = 0
    let resultOffset = MemoryLayout<NBReceptorEventTransductionResult>.stride
    let clockOffset = resultOffset + MemoryLayout<NBSchedulerResult>.stride
    let invocationOffset = clockOffset + schedulerClockByteCount
    _ = try submit(label: "NumiBrain committed scheduler inspection") { encoder in
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
        sourceBuffer: schedulerClockBuffers[committedSchedulerClockIndex],
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
    guard result.target_time_microseconds == committedSchedulerTime.rawValue else {
      throw TissueError.metal("scheduler result target does not match committed time")
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
        committedTime: committedSchedulerTime,
        generation: committedSchedulerGeneration,
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
    try copy(
      source: regionalStateBuffers[committedRegionalStateIndex],
      destination: stagingBuffer,
      size: regionalStateByteCount,
      label: "NumiBrain committed regional-state inspection"
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
      committedTime: committedSchedulerTime,
      generation: committedSchedulerGeneration,
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
    timeMilliseconds: Float,
    acceptedSubstepCount: Int,
    events: [BrainInterruptEvent]
  ) throws -> PreparedSchedulerWindow {
    let startTime = try schedulerTimestamp(milliseconds: timeMilliseconds)
    if let committedSchedulerTime, startTime != committedSchedulerTime {
      throw TissueError.transaction(
        "root time does not match committed scheduler time \(committedSchedulerTime.rawValue) us"
      )
    }
    let timestep = try schedulerTimestamp(
      milliseconds: parameters.timestepMilliseconds
    ).rawValue
    let (duration, durationOverflow) = UInt64(acceptedSubstepCount)
      .multipliedReportingOverflow(by: timestep)
    let (targetMicroseconds, targetOverflow) = startTime.rawValue
      .addingReportingOverflow(duration)
    guard !durationOverflow, !targetOverflow else {
      throw TissueError.transaction("scheduler target time overflows UInt64")
    }
    let targetTime = BrainTimestamp(microseconds: targetMicroseconds)
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

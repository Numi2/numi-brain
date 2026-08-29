import Foundation
@preconcurrency import Metal
import NumiBrainABI
import NumiBrainCore

/// Bounded Metal 4 materializer and indirect consumer for a compiled cohort
/// dispatch plan. The plan is authenticated by the compiled C ABI before
/// upload, copied into private region-major buffers under the immutable
/// parameter-version binding, and expanded without an intervening count readback.
@available(macOS 26.0, *)
public enum MetalDispatchPlanRuntime {
  public struct Materialization: Equatable, Sendable {
    public let deviceName: String
    public let planFingerprint: UInt64
    public let parameterVersionFingerprint: UInt64
    public let groups: [BrainDispatchGroup]
    public let workItems: [BrainDispatchWorkItem]
    public let workFingerprint: UInt64
    public let indirectThreadgroupCount: UInt32
    public let compactedInvocationCount: Int
    public let compactedInvocationFingerprint: UInt64
    public let compactedInvocationByteCount: Int
    public let regionalStates: [BrainCohortRegionalState]
    public let regionalStateFingerprint: UInt64
    public let regionalIndirectThreadgroupCount: UInt32
    public let regionalStateByteCount: Int
    public let tokenStates: [BrainCohortTokenState]
    public let tokenStateFingerprint: UInt64
    public let tokenIndirectThreadgroupCount: UInt32
    public let tokenStateByteCount: Int
    public let routingStates: [BrainCohortRoutingState]
    public let routingStateFingerprint: UInt64
    public let routeHistoryByteCount: Int
    public let routeRuntimeStateByteCount: Int
    public let status: UInt32
    public let privateInputByteCount: Int
    public let privateOutputByteCount: Int
    public let gpuStartSeconds: Double
    public let gpuEndSeconds: Double

    public var entryCount: Int {
      groups.reduce(0) { $0 + $1.entries.count }
    }

    public var gpuDurationSeconds: Double {
      max(gpuEndSeconds - gpuStartSeconds, 0)
    }
  }

  private struct FeedbackSnapshot {
    let gpuStartTime: Double
    let gpuEndTime: Double
  }

  private struct DispatchIndirectArguments {
    var threadgroupsX: UInt32 = 0
    var threadgroupsY: UInt32 = 0
    var threadgroupsZ: UInt32 = 0
  }

  private final class FeedbackBox: @unchecked Sendable {
    var feedback: (any MTL4CommitFeedback)?
  }

  /// Proves that the program's compiled ring capacity preserves every delayed
  /// route value that can be observed during this root dispatch. The initial
  /// checkpoint is already canonical; this simulation checks only publications
  /// and reads introduced by the candidate root transaction.
  private static func validateRouteHistoryCapacity(
    environmentIdentifier: UInt32,
    program: RegionalTokenProgram,
    initialHistory: RegionalRouteHistory,
    invocations: [BrainModuleInvocation]
  ) throws {
    guard !invocations.isEmpty else {
      throw TissueError.metal(
        "cohort routing state has no work for environment \(environmentIdentifier)"
      )
    }
    var bounded: [[UInt64]] = []
    bounded.reserveCapacity(program.routes.count)
    for routeIndex in program.routes.indices {
      let state = initialHistory.states[routeIndex]
      var timestamps: [UInt64] = []
      timestamps.reserveCapacity(Int(state.count))
      if state.count > 0 {
        for age in stride(from: Int(state.count) - 1, through: 0, by: -1) {
          let slot =
            (Int(state.nextSlot) + initialHistory.capacity - 1 - age)
            % initialHistory.capacity
          timestamps.append(
            initialHistory.timestamps[
              routeIndex * initialHistory.capacity + slot
            ]
          )
        }
      }
      bounded.append(timestamps)
    }
    var unbounded = bounded
    var cursor = 0
    while cursor < invocations.count {
      let timestamp = invocations[cursor].timestamp.rawValue
      var end = cursor + 1
      while end < invocations.count,
        invocations[end].timestamp.rawValue == timestamp
      {
        end += 1
      }
      let dueModules = Set(invocations[cursor..<end].map(\.moduleIdentifier))
      for routeIndex in program.routes.indices {
        let route = program.routes[routeIndex]
        if route.delayMicroseconds > 0,
          dueModules.contains(route.receiverModuleIdentifier)
        {
          let target = timestamp >= UInt64(route.delayMicroseconds)
            ? timestamp - UInt64(route.delayMicroseconds)
            : nil
          let boundedMatch = target.flatMap { target in
            bounded[routeIndex].last { $0 <= target }
          }
          let unboundedMatch = target.flatMap { target in
            unbounded[routeIndex].last { $0 <= target }
          }
          guard boundedMatch == unboundedMatch else {
            throw TissueError.metal(
              "route-history capacity \(program.compiledRouteHistoryCapacity) "
                + "cannot preserve route \(routeIndex) for environment "
                + "\(environmentIdentifier) at \(timestamp) us"
            )
          }
        }
      }
      for routeIndex in program.routes.indices
      where dueModules.contains(program.routes[routeIndex].senderModuleIdentifier) {
        guard unbounded[routeIndex].last.map({ $0 < timestamp }) ?? true else {
          throw TissueError.metal(
            "route-history publication time did not advance for environment "
              + "\(environmentIdentifier)"
          )
        }
        unbounded[routeIndex].append(timestamp)
        bounded[routeIndex].append(timestamp)
        if bounded[routeIndex].count > program.compiledRouteHistoryCapacity {
          bounded[routeIndex].removeFirst(
            bounded[routeIndex].count - program.compiledRouteHistoryCapacity
          )
        }
      }
      cursor = end
    }
  }

  public static func materialize(
    plan: BrainDispatchPlan,
    schedule: BrainModuleSchedule,
    regionalProgram: RegionalTokenProgram,
    parameterVersion: BrainParameterVersion,
    sharedParameterArtifact: BrainSharedParameterArtifact? = nil,
    initialRegionalStates: [BrainCohortRegionalState]? = nil,
    initialTokenStates: [BrainCohortTokenState]? = nil,
    initialRoutingStates: [BrainCohortRoutingState]? = nil,
    device requestedDevice: (any MTLDevice)? = nil
  ) throws -> Materialization {
    guard plan.scheduleFingerprint == schedule.fingerprint,
      plan.scheduleFingerprint == parameterVersion.scheduleFingerprint,
      plan.parameterVersionFingerprint == parameterVersion.fingerprint,
      regionalProgram.scheduleFingerprint == schedule.fingerprint,
      regionalProgram.fingerprint == parameterVersion.regionalProgramFingerprint,
      !regionalProgram.routes.isEmpty
    else {
      throw TissueError.metal(
        "dispatch plan does not match the immutable parameter-version binding"
      )
    }
    guard !plan.groups.isEmpty, plan.entryCount > 0 else {
      throw TissueError.metal("dispatch plan has no active module work to materialize")
    }
    guard
      MemoryLayout<NBDispatchPlanHeader>.stride == BrainDispatchPlan.headerByteCount,
      MemoryLayout<NBDispatchGroup>.stride == BrainDispatchPlan.groupByteCount,
      MemoryLayout<NBDispatchEntry>.stride == BrainDispatchPlan.entryByteCount,
      MemoryLayout<NBDispatchPlanResult>.stride == BrainDispatchPlan.resultByteCount,
      MemoryLayout<NBDispatchWorkItem>.stride == BrainDispatchPlan.workItemByteCount,
      MemoryLayout<NBDispatchCohortUniforms>.stride
        == BrainDispatchPlan.cohortUniformByteCount,
      MemoryLayout<NBDispatchTokenUniforms>.stride
        == BrainDispatchPlan.tokenUniformByteCount,
      MemoryLayout<NBRegionalProgramHeader>.stride
        == Int(NB_REGIONAL_PROGRAM_HEADER_BYTE_COUNT),
      MemoryLayout<NBRegionalTokenLayout>.stride
        == Int(NB_REGIONAL_TOKEN_LAYOUT_BYTE_COUNT),
      MemoryLayout<NBRegionalRoute>.stride == Int(NB_REGIONAL_ROUTE_BYTE_COUNT),
      MemoryLayout<NBRegionalTokenParameters>.stride
        == Int(NB_REGIONAL_TOKEN_PARAMETERS_BYTE_COUNT),
      MemoryLayout<NBRegionalRouteHistoryState>.stride
        == Int(NB_REGIONAL_ROUTE_HISTORY_STATE_BYTE_COUNT),
      MemoryLayout<NBRegionalRouteRuntimeState>.stride
        == Int(NB_REGIONAL_ROUTE_RUNTIME_STATE_BYTE_COUNT),
      MemoryLayout<NBRegionalModuleState>.stride
        == Int(NB_REGIONAL_MODULE_STATE_BYTE_COUNT),
      MemoryLayout<DispatchIndirectArguments>.stride == 12,
      MemoryLayout<NBParameterVersionBinding>.stride
        == BrainParameterVersion.bindingByteCount
    else {
      throw TissueError.metal("Swift dispatch-plan ABI does not match NumiBrainABI")
    }

    var header = plan.abiHeader
    let inputGroups = plan.groupABIRecords
    let inputEntries = plan.entryABIRecords
    let environmentIdentifiers = plan.activeEnvironmentIdentifiers
    guard !environmentIdentifiers.isEmpty,
      environmentIdentifiers.count <= Int(UInt32.max),
      schedule.modules.count <= Int(UInt32.max)
    else {
      throw TissueError.metal("cohort regional execution has invalid environment counts")
    }
    let planWorkItems = plan.workItems
    var invocationsByEnvironment: [UInt32: [BrainModuleInvocation]] = [:]
    invocationsByEnvironment.reserveCapacity(environmentIdentifiers.count)
    for item in planWorkItems {
      invocationsByEnvironment[item.environmentIdentifier, default: []].append(
        BrainModuleInvocation(
          timestamp: item.timestamp,
          moduleIdentifier: item.moduleIdentifier,
          clockClass: item.clockClass,
          reasons: item.reasons,
          interruptMask: item.interruptMask
        )
      )
    }
    let invocationCapacityPerEnvironment = plan.groups.count
    let (compactedInvocationCapacity, compactedInvocationCapacityOverflow) =
      environmentIdentifiers.count.multipliedReportingOverflow(
        by: invocationCapacityPerEnvironment
      )
    let (compactedInvocationByteCount, compactedInvocationByteCountOverflow) =
      compactedInvocationCapacity.multipliedReportingOverflow(
        by: MemoryLayout<NBDueInvocation>.stride
      )
    let compactedInvocationCountByteCount =
      environmentIdentifiers.count * MemoryLayout<UInt32>.stride
    guard !compactedInvocationCapacityOverflow,
      !compactedInvocationByteCountOverflow,
      invocationCapacityPerEnvironment > 0
    else {
      throw TissueError.metal("cohort invocation compaction exceeds the ABI limit")
    }
    let (regionalStateCount, regionalStateCountOverflow) =
      environmentIdentifiers.count.multipliedReportingOverflow(by: schedule.modules.count)
    guard !regionalStateCountOverflow, regionalStateCount <= Int(UInt32.max) else {
      throw TissueError.metal("cohort regional-state count exceeds the ABI limit")
    }
    let (tokenStateCount, tokenStateCountOverflow) =
      environmentIdentifiers.count.multipliedReportingOverflow(
        by: regionalProgram.scalarCount
      )
    let (tokenStateByteCount, tokenStateByteCountOverflow) =
      tokenStateCount.multipliedReportingOverflow(by: MemoryLayout<Float>.stride)
    guard !tokenStateCountOverflow, !tokenStateByteCountOverflow else {
      throw TissueError.metal("cohort regional-token state exceeds the ABI limit")
    }
    let routeCount = regionalProgram.routes.count
    let routeHistoryCapacity = regionalProgram.compiledRouteHistoryCapacity
    let routeHistoryScalarCount = regionalProgram.routeHistoryScalarCount
    let (cohortRouteCount, cohortRouteCountOverflow) =
      environmentIdentifiers.count.multipliedReportingOverflow(by: routeCount)
    let (historyTimestampCountPerEnvironment, historyTimestampCountOverflow) =
      routeCount.multipliedReportingOverflow(by: routeHistoryCapacity)
    let (cohortHistoryTimestampCount, cohortHistoryTimestampCountOverflow) =
      environmentIdentifiers.count.multipliedReportingOverflow(
        by: historyTimestampCountPerEnvironment
      )
    let (cohortHistoryScalarCount, cohortHistoryScalarCountOverflow) =
      environmentIdentifiers.count.multipliedReportingOverflow(
        by: routeHistoryScalarCount
      )
    guard !cohortRouteCountOverflow, !historyTimestampCountOverflow,
      !cohortHistoryTimestampCountOverflow, !cohortHistoryScalarCountOverflow,
      cohortRouteCount <= Int(UInt32.max)
    else {
      throw TissueError.metal("cohort routing state exceeds the ABI limit")
    }
    let canonicalInitialRegionalStates: [BrainCohortRegionalState]
    if let initialRegionalStates {
      canonicalInitialRegionalStates = initialRegionalStates.sorted {
        $0.environmentIdentifier < $1.environmentIdentifier
      }
      guard
        canonicalInitialRegionalStates.map(\.environmentIdentifier)
          == environmentIdentifiers,
        canonicalInitialRegionalStates.allSatisfy({ state in
          state.states.count == schedule.modules.count
            && state.states.allSatisfy { value in
              value.activation.isFinite
                && value.integration.isFinite
                && value.interruptSalience.isFinite
                && value.phase.isFinite
            }
        })
      else {
        throw TissueError.metal(
          "initial cohort regional state does not match active environments or modules"
        )
      }
    } else {
      canonicalInitialRegionalStates = environmentIdentifiers.map { identifier in
        BrainCohortRegionalState(
          environmentIdentifier: identifier,
          states: schedule.modules.map { _ in RegionalModuleState() }
        )
      }
    }
    var firstInvocationTimestamps: [UInt64: BrainTimestamp] = [:]
    for item in planWorkItems {
      let key =
        UInt64(item.environmentIdentifier) << 16
        | UInt64(item.moduleIdentifier)
      if let current = firstInvocationTimestamps[key] {
        firstInvocationTimestamps[key] = min(current, item.timestamp)
      } else {
        firstInvocationTimestamps[key] = item.timestamp
      }
    }
    guard
      canonicalInitialRegionalStates.allSatisfy({ environment in
        zip(schedule.modules, environment.states).allSatisfy { module, state in
          guard let lastUpdate = state.lastUpdate else { return true }
          let key =
            UInt64(environment.environmentIdentifier) << 16
            | UInt64(module.moduleIdentifier)
          guard let firstInvocation = firstInvocationTimestamps[key] else { return true }
          return lastUpdate <= firstInvocation
        }
      })
    else {
      throw TissueError.metal(
        "initial cohort regional state is newer than its first scheduled invocation"
      )
    }
    let initialRegionalStateRecords = canonicalInitialRegionalStates.flatMap { state in
      state.states.map(\.abiRecord)
    }
    let canonicalInitialTokenStates: [BrainCohortTokenState]
    if let initialTokenStates {
      canonicalInitialTokenStates = initialTokenStates.sorted {
        $0.environmentIdentifier < $1.environmentIdentifier
      }
      guard
        canonicalInitialTokenStates.map(\.environmentIdentifier)
          == environmentIdentifiers,
        canonicalInitialTokenStates.allSatisfy({ state in
          state.values.count == regionalProgram.scalarCount
            && state.values.allSatisfy(\.isFinite)
        })
      else {
        throw TissueError.metal(
          "initial cohort token state does not match active environments or program shape"
        )
      }
    } else {
      canonicalInitialTokenStates = environmentIdentifiers.map { identifier in
        BrainCohortTokenState(
          environmentIdentifier: identifier,
          values: [Float](repeating: 0, count: regionalProgram.scalarCount)
        )
      }
    }
    let initialTokenValues = canonicalInitialTokenStates.flatMap(\.values)
    let moduleRecords = schedule.modules.map(\.abiRecord)
    var programHeader = regionalProgram.headerRecord
    let layoutRecords = regionalProgram.layouts.map(\.abiRecord)
    let routeRecords = regionalProgram.routeABIRecords
    let outgoingRouteOffsets = regionalProgram.outgoingRouteOffsets
    let outgoingRouteIndices = regionalProgram.outgoingRouteIndices
    let outgoingRouteCSR = outgoingRouteOffsets + outgoingRouteIndices
    let parameterRecords = regionalProgram.parameters.map(\.abiRecord)
    let canonicalInitialRoutingStates: [BrainCohortRoutingState]
    if let initialRoutingStates {
      canonicalInitialRoutingStates = initialRoutingStates.sorted {
        $0.environmentIdentifier < $1.environmentIdentifier
      }
      guard
        canonicalInitialRoutingStates.map(\.environmentIdentifier)
          == environmentIdentifiers
      else {
        throw TissueError.metal(
          "initial cohort routing state does not match active environments"
        )
      }
      for state in canonicalInitialRoutingStates {
        try state.routeHistory.validate(program: regionalProgram)
        try state.routingState.validate(program: regionalProgram)
        guard let firstInvocation = invocationsByEnvironment[
          state.environmentIdentifier
        ]?.first else {
          throw TissueError.metal("cohort routing state has no scheduled environment")
        }
        let firstTimestamp = firstInvocation.timestamp
        guard
          state.routeHistory.states.allSatisfy({
            $0.latestTimestamp.map { $0 < firstTimestamp } ?? true
          }),
          state.routingState.states.allSatisfy({
            $0.lastSelectedTimestamp.map { $0 < firstTimestamp } ?? true
          })
        else {
          throw TissueError.metal(
            "initial cohort routing state is not older than its first invocation"
          )
        }
      }
    } else {
      canonicalInitialRoutingStates = environmentIdentifiers.map { identifier in
        BrainCohortRoutingState(
          environmentIdentifier: identifier,
          routeHistory: RegionalRouteHistory(program: regionalProgram),
          routingState: RegionalRoutingState(program: regionalProgram)
        )
      }
    }
    for state in canonicalInitialRoutingStates {
      try validateRouteHistoryCapacity(
        environmentIdentifier: state.environmentIdentifier,
        program: regionalProgram,
        initialHistory: state.routeHistory,
        invocations: invocationsByEnvironment[state.environmentIdentifier] ?? []
      )
    }
    let initialRouteHistoryStateRecords = canonicalInitialRoutingStates.flatMap {
      $0.routeHistory.states.map(\.abiRecord)
    }
    let initialRouteHistoryTimestamps = canonicalInitialRoutingStates.flatMap {
      $0.routeHistory.timestamps
    }
    let initialRouteHistoryValues = canonicalInitialRoutingStates.flatMap {
      $0.routeHistory.values
    }
    let initialRouteRuntimeStateRecords = canonicalInitialRoutingStates.flatMap {
      $0.routingState.states.map(\.abiRecord)
    }
    var cohortUniforms = NBDispatchCohortUniforms()
    cohortUniforms.plan_fingerprint = plan.fingerprint
    cohortUniforms.parameter_version_fingerprint = parameterVersion.fingerprint
    cohortUniforms.environment_count = UInt32(environmentIdentifiers.count)
    cohortUniforms.module_count = UInt32(schedule.modules.count)
    cohortUniforms.state_count = UInt32(regionalStateCount)
    cohortUniforms.flags = 0
    var tokenUniforms = NBDispatchTokenUniforms()
    tokenUniforms.regional_program_fingerprint = regionalProgram.fingerprint
    tokenUniforms.schedule_fingerprint = schedule.fingerprint
    tokenUniforms.environment_count = UInt32(environmentIdentifiers.count)
    tokenUniforms.scalar_count_per_environment = UInt32(regionalProgram.scalarCount)
    tokenUniforms.total_scalar_count = UInt64(tokenStateCount)
    let validation = inputGroups.withUnsafeBufferPointer { groups in
      inputEntries.withUnsafeBufferPointer { entries in
        withUnsafePointer(to: &header) { header in
          nb_brain_abi_validate_dispatch_plan(
            header,
            groups.baseAddress,
            entries.baseAddress
          )
        }
      }
    }
    guard validation == UInt32(NB_DISPATCH_PLAN_VALID.rawValue) else {
      throw TissueError.metal(
        "compiled dispatch-plan validation failed with code \(validation)"
      )
    }
    var binding = parameterVersion.abiBinding
    let components = parameterVersion.components.map(\.abiRecord)
    let versionValidation = components.withUnsafeBufferPointer { components in
      withUnsafePointer(to: &binding) { binding in
        nb_brain_abi_validate_parameter_version(binding, components.baseAddress)
      }
    }
    guard versionValidation == UInt32(NB_PARAMETER_VERSION_VALID.rawValue) else {
      throw TissueError.metal(
        "compiled parameter-version validation failed with code \(versionValidation)"
      )
    }

    guard let device = requestedDevice ?? MTLCreateSystemDefaultDevice() else {
      throw TissueError.metal("no Metal device is available")
    }
    let sharedParameterBank = try MetalSharedParameterBank(
      device: device,
      parameterVersion: parameterVersion,
      artifact: sharedParameterArtifact
    )
    guard sharedParameterBank.scalarCount(.regionalDense)
      == regionalProgram.denseParameterCount
    else {
      throw TissueError.metal(
        "regional dense parameter shape does not match the cohort program"
      )
    }
    guard let commandQueue = device.makeMTL4CommandQueue(),
      let commandAllocator = device.makeCommandAllocator(),
      let commandBuffer = device.makeCommandBuffer()
    else {
      throw TissueError.metal("device does not provide the required Metal 4 command objects")
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
    guard let function = library.makeFunction(name: "materialize_dispatch_plan"),
      let consumerFunction = library.makeFunction(name: "consume_dispatch_plan"),
      let regionalFunction = library.makeFunction(
        name: "advance_cohort_regional_diagnostics"
      ),
      let invocationCompactionFunction = library.makeFunction(
        name: "compact_cohort_invocations"
      ),
      let tokenFunction = library.makeFunction(
        name: "advance_cohort_regional_tokens_routed"
      )
    else {
      throw TissueError.metal("cohort dispatch functions are missing from the Metal library")
    }
    let pipeline: any MTLComputePipelineState
    let consumerPipeline: any MTLComputePipelineState
    let regionalPipeline: any MTLComputePipelineState
    let invocationCompactionPipeline: any MTLComputePipelineState
    let tokenPipeline: any MTLComputePipelineState
    do {
      pipeline = try device.makeComputePipelineState(function: function)
      consumerPipeline = try device.makeComputePipelineState(function: consumerFunction)
      regionalPipeline = try device.makeComputePipelineState(function: regionalFunction)
      invocationCompactionPipeline = try device.makeComputePipelineState(
        function: invocationCompactionFunction
      )
      tokenPipeline = try device.makeComputePipelineState(function: tokenFunction)
    } catch {
      throw TissueError.metal("dispatch-plan pipeline creation failed: \(error)")
    }
    let argumentDescriptor = MTL4ArgumentTableDescriptor()
    argumentDescriptor.label = "NumiBrain dispatch-plan arguments"
    argumentDescriptor.maxBufferBindCount = 10
    argumentDescriptor.initializeBindings = true
    guard let argumentTable = try? device.makeArgumentTable(descriptor: argumentDescriptor) else {
      throw TissueError.metal("failed to create the dispatch-plan argument table")
    }
    let consumerArgumentDescriptor = MTL4ArgumentTableDescriptor()
    consumerArgumentDescriptor.label = "NumiBrain dispatch consumer arguments"
    consumerArgumentDescriptor.maxBufferBindCount = 4
    consumerArgumentDescriptor.initializeBindings = true
    guard
      let consumerArgumentTable = try? device.makeArgumentTable(
        descriptor: consumerArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the dispatch consumer argument table")
    }
    let regionalArgumentDescriptor = MTL4ArgumentTableDescriptor()
    regionalArgumentDescriptor.label = "NumiBrain cohort regional-state arguments"
    regionalArgumentDescriptor.maxBufferBindCount = 8
    regionalArgumentDescriptor.initializeBindings = true
    guard
      let regionalArgumentTable = try? device.makeArgumentTable(
        descriptor: regionalArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the cohort regional-state argument table")
    }
    let tokenArgumentDescriptor = MTL4ArgumentTableDescriptor()
    tokenArgumentDescriptor.label = "NumiBrain cohort regional-token arguments"
    tokenArgumentDescriptor.maxBufferBindCount = 31
    tokenArgumentDescriptor.initializeBindings = true
    guard
      let tokenArgumentTable = try? device.makeArgumentTable(
        descriptor: tokenArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the cohort regional-token argument table")
    }
    let invocationCompactionArgumentDescriptor = MTL4ArgumentTableDescriptor()
    invocationCompactionArgumentDescriptor.label =
      "NumiBrain cohort invocation-compaction arguments"
    invocationCompactionArgumentDescriptor.maxBufferBindCount = 7
    invocationCompactionArgumentDescriptor.initializeBindings = true
    guard
      let invocationCompactionArgumentTable = try? device.makeArgumentTable(
        descriptor: invocationCompactionArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the invocation-compaction argument table")
    }

    let headerByteCount = MemoryLayout<NBDispatchPlanHeader>.stride
    let groupByteCount = inputGroups.count * MemoryLayout<NBDispatchGroup>.stride
    let entryByteCount = inputEntries.count * MemoryLayout<NBDispatchEntry>.stride
    let bindingByteCount = MemoryLayout<NBParameterVersionBinding>.stride
    let resultByteCount = MemoryLayout<NBDispatchPlanResult>.stride
    let indirectArgumentByteCount = MemoryLayout<DispatchIndirectArguments>.stride
    let indirectArgumentCount = 3
    let indirectStorageByteCount = 48
    let workItemByteCount = inputEntries.count * MemoryLayout<NBDispatchWorkItem>.stride
    let cohortUniformByteCount = MemoryLayout<NBDispatchCohortUniforms>.stride
    let tokenUniformByteCount = MemoryLayout<NBDispatchTokenUniforms>.stride
    let environmentIdentifierByteCount = environmentIdentifiers.count * MemoryLayout<UInt32>.stride
    let moduleByteCount = moduleRecords.count * MemoryLayout<NBModuleDescriptor>.stride
    let regionalStateByteCount =
      regionalStateCount
      * MemoryLayout<NBRegionalModuleState>.stride
    let programHeaderByteCount = MemoryLayout<NBRegionalProgramHeader>.stride
    let layoutByteCount = layoutRecords.count * MemoryLayout<NBRegionalTokenLayout>.stride
    let routeByteCount = routeRecords.count * MemoryLayout<NBRegionalRoute>.stride
    let outgoingRouteOffsetByteCount =
      outgoingRouteOffsets.count * MemoryLayout<UInt32>.stride
    let outgoingRouteIndexByteCount =
      outgoingRouteIndices.count * MemoryLayout<UInt32>.stride
    let outgoingRouteCSRByteCount =
      outgoingRouteOffsetByteCount + outgoingRouteIndexByteCount
    let parameterByteCount =
      parameterRecords.count * MemoryLayout<NBRegionalTokenParameters>.stride
    let tokenLastUpdateByteCount = regionalStateCount * MemoryLayout<UInt64>.stride
    let routeHistoryStateByteCount =
      cohortRouteCount * MemoryLayout<NBRegionalRouteHistoryState>.stride
    let routeHistoryTimestampByteCount =
      cohortHistoryTimestampCount * MemoryLayout<UInt64>.stride
    let routeHistoryValueByteCount =
      cohortHistoryScalarCount * MemoryLayout<Float>.stride
    let routeHistoryByteCount = routeHistoryStateByteCount
      + routeHistoryTimestampByteCount + routeHistoryValueByteCount
    let routeRuntimeStateByteCount =
      cohortRouteCount * MemoryLayout<NBRegionalRouteRuntimeState>.stride
    let resolvedRouteSlotByteCount = cohortRouteCount * MemoryLayout<UInt32>.stride
    let selectedRouteIndexByteCount = cohortRouteCount * MemoryLayout<UInt32>.stride
    let selectedRouteCountByteCount = regionalStateCount * MemoryLayout<UInt32>.stride
    let inspectionByteCount =
      resultByteCount + groupByteCount + entryByteCount
      + indirectStorageByteCount + workItemByteCount + regionalStateByteCount
      + tokenStateByteCount + tokenLastUpdateByteCount + routeHistoryByteCount
      + routeRuntimeStateByteCount + compactedInvocationByteCount
      + compactedInvocationCountByteCount
    let stagingByteCount = max(
      inspectionByteCount,
      max(
        max(headerByteCount, groupByteCount),
        max(
          max(entryByteCount, bindingByteCount),
          max(
            max(
              max(cohortUniformByteCount, tokenUniformByteCount),
              max(environmentIdentifierByteCount, programHeaderByteCount)
            ),
            max(
              max(moduleByteCount, regionalStateByteCount),
              max(
                max(
                  max(
                    max(layoutByteCount, routeByteCount),
                    outgoingRouteCSRByteCount
                  ),
                  parameterByteCount
                ),
                max(
                  max(tokenStateByteCount, tokenLastUpdateByteCount),
                  max(
                    max(routeHistoryStateByteCount, routeHistoryTimestampByteCount),
                    max(routeHistoryValueByteCount, routeRuntimeStateByteCount)
                  )
                )
              )
            )
          )
        )
      )
    )

    func privateBuffer(length: Int, label: String) throws -> any MTLBuffer {
      guard
        let buffer = device.makeBuffer(
          length: length,
          options: [.storageModePrivate, .hazardTrackingModeTracked]
        )
      else {
        throw TissueError.metal("failed to allocate \(label)")
      }
      buffer.label = label
      return buffer
    }
    let headerBuffer = try privateBuffer(
      length: headerByteCount,
      label: "NumiBrain immutable dispatch-plan header"
    )
    let inputGroupBuffer = try privateBuffer(
      length: groupByteCount,
      label: "NumiBrain immutable dispatch-plan groups"
    )
    let inputEntryBuffer = try privateBuffer(
      length: entryByteCount,
      label: "NumiBrain immutable dispatch-plan entries"
    )
    let bindingBuffer = try privateBuffer(
      length: bindingByteCount,
      label: "NumiBrain immutable dispatch parameter binding"
    )
    let outputGroupBuffer = try privateBuffer(
      length: groupByteCount,
      label: "NumiBrain private materialized dispatch groups"
    )
    let outputEntryBuffer = try privateBuffer(
      length: entryByteCount,
      label: "NumiBrain private materialized dispatch entries"
    )
    let resultBuffer = try privateBuffer(
      length: resultByteCount,
      label: "NumiBrain private dispatch-plan result"
    )
    let indirectArgumentBuffer = try privateBuffer(
      length: indirectStorageByteCount,
      label: "NumiBrain private GPU-generated indirect dispatch arguments"
    )
    let workItemBuffer = try privateBuffer(
      length: workItemByteCount,
      label: "NumiBrain private indirect dispatch work items"
    )
    let compactedInvocationBuffer = try privateBuffer(
      length: compactedInvocationByteCount,
      label: "NumiBrain private environment-major due invocations"
    )
    let compactedInvocationCountBuffer = try privateBuffer(
      length: compactedInvocationCountByteCount,
      label: "NumiBrain private environment-major invocation counts"
    )
    let cohortUniformBuffer = try privateBuffer(
      length: cohortUniformByteCount,
      label: "NumiBrain immutable cohort regional uniforms"
    )
    let tokenUniformBuffer = try privateBuffer(
      length: tokenUniformByteCount,
      label: "NumiBrain immutable cohort regional-token uniforms"
    )
    let environmentIdentifierBuffer = try privateBuffer(
      length: environmentIdentifierByteCount,
      label: "NumiBrain immutable active environment identifiers"
    )
    let moduleBuffer = try privateBuffer(
      length: moduleByteCount,
      label: "NumiBrain immutable cohort module descriptors"
    )
    let programHeaderBuffer = try privateBuffer(
      length: programHeaderByteCount,
      label: "NumiBrain immutable cohort regional-token header"
    )
    let layoutBuffer = try privateBuffer(
      length: layoutByteCount,
      label: "NumiBrain immutable cohort regional-token layouts"
    )
    let routeBuffer = try privateBuffer(
      length: routeByteCount,
      label: "NumiBrain immutable cohort regional-token routes"
    )
    let outgoingRouteCSRBuffer = try privateBuffer(
      length: outgoingRouteCSRByteCount,
      label: "NumiBrain immutable cohort outgoing-route CSR index"
    )
    let parameterBuffer = try privateBuffer(
      length: parameterByteCount,
      label: "NumiBrain immutable cohort regional-token parameters"
    )
    let inputRegionalStateBuffer = try privateBuffer(
      length: regionalStateByteCount,
      label: "NumiBrain private cohort regional input generation"
    )
    let outputRegionalStateBuffer = try privateBuffer(
      length: regionalStateByteCount,
      label: "NumiBrain private cohort regional output generation"
    )
    let inputTokenBuffer = try privateBuffer(
      length: tokenStateByteCount,
      label: "NumiBrain private cohort regional-token input generation"
    )
    let outputTokenBuffer = try privateBuffer(
      length: tokenStateByteCount,
      label: "NumiBrain private cohort regional-token output generation"
    )
    let candidateTokenBuffer = try privateBuffer(
      length: tokenStateByteCount,
      label: "NumiBrain private cohort regional-token candidate generation"
    )
    let tokenLastUpdateBuffer = try privateBuffer(
      length: tokenLastUpdateByteCount,
      label: "NumiBrain private cohort regional-token last-update state"
    )
    let inputRouteHistoryStateBuffer = try privateBuffer(
      length: routeHistoryStateByteCount,
      label: "NumiBrain private cohort route-history input states"
    )
    let outputRouteHistoryStateBuffer = try privateBuffer(
      length: routeHistoryStateByteCount,
      label: "NumiBrain private cohort route-history output states"
    )
    let inputRouteHistoryTimestampBuffer = try privateBuffer(
      length: routeHistoryTimestampByteCount,
      label: "NumiBrain private cohort route-history input timestamps"
    )
    let outputRouteHistoryTimestampBuffer = try privateBuffer(
      length: routeHistoryTimestampByteCount,
      label: "NumiBrain private cohort route-history output timestamps"
    )
    let inputRouteHistoryValueBuffer = try privateBuffer(
      length: routeHistoryValueByteCount,
      label: "NumiBrain private cohort route-history input values"
    )
    let outputRouteHistoryValueBuffer = try privateBuffer(
      length: routeHistoryValueByteCount,
      label: "NumiBrain private cohort route-history output values"
    )
    let resolvedRouteSlotBuffer = try privateBuffer(
      length: resolvedRouteSlotByteCount,
      label: "NumiBrain private cohort resolved route-history slots"
    )
    let inputRouteRuntimeStateBuffer = try privateBuffer(
      length: routeRuntimeStateByteCount,
      label: "NumiBrain private cohort route-runtime input states"
    )
    let outputRouteRuntimeStateBuffer = try privateBuffer(
      length: routeRuntimeStateByteCount,
      label: "NumiBrain private cohort route-runtime output states"
    )
    let selectedRouteIndexBuffer = try privateBuffer(
      length: selectedRouteIndexByteCount,
      label: "NumiBrain private cohort selected route indices"
    )
    let selectedRouteCountBuffer = try privateBuffer(
      length: selectedRouteCountByteCount,
      label: "NumiBrain private cohort selected route counts"
    )
    guard
      let stagingBuffer = device.makeBuffer(
        length: stagingByteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate dispatch-plan staging")
    }
    stagingBuffer.label = "NumiBrain explicit dispatch upload and inspection staging"

    let residencyDescriptor = MTLResidencySetDescriptor()
    residencyDescriptor.label = "NumiBrain dispatch-plan residency"
    residencyDescriptor.initialCapacity = 38
      + sharedParameterBank.residencyAllocations.count
    let residencySet: any MTLResidencySet
    do {
      residencySet = try device.makeResidencySet(descriptor: residencyDescriptor)
    } catch {
      throw TissueError.metal("failed to create dispatch-plan residency: \(error)")
    }
    let buffers: [any MTLBuffer] = [
      headerBuffer,
      inputGroupBuffer,
      inputEntryBuffer,
      bindingBuffer,
      outputGroupBuffer,
      outputEntryBuffer,
      resultBuffer,
      indirectArgumentBuffer,
      workItemBuffer,
      compactedInvocationBuffer,
      compactedInvocationCountBuffer,
      cohortUniformBuffer,
      tokenUniformBuffer,
      environmentIdentifierBuffer,
      moduleBuffer,
      programHeaderBuffer,
      layoutBuffer,
      routeBuffer,
      outgoingRouteCSRBuffer,
      parameterBuffer,
      inputRegionalStateBuffer,
      outputRegionalStateBuffer,
      inputTokenBuffer,
      outputTokenBuffer,
      candidateTokenBuffer,
      tokenLastUpdateBuffer,
      inputRouteHistoryStateBuffer,
      outputRouteHistoryStateBuffer,
      inputRouteHistoryTimestampBuffer,
      outputRouteHistoryTimestampBuffer,
      inputRouteHistoryValueBuffer,
      outputRouteHistoryValueBuffer,
      resolvedRouteSlotBuffer,
      inputRouteRuntimeStateBuffer,
      outputRouteRuntimeStateBuffer,
      selectedRouteIndexBuffer,
      selectedRouteCountBuffer,
      stagingBuffer,
    ]
    for buffer in buffers {
      residencySet.addAllocation(buffer)
    }
    for allocation in sharedParameterBank.residencyAllocations {
      residencySet.addAllocation(allocation)
    }
    residencySet.commit()
    residencySet.requestResidency()

    func submit(
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

    func upload(
      to destination: any MTLBuffer,
      byteCount: Int,
      label: String,
      write: (UnsafeMutableRawPointer) -> Void
    ) throws {
      write(stagingBuffer.contents())
      _ = try submit(label: label) { encoder in
        encoder.copy(
          sourceBuffer: stagingBuffer,
          sourceOffset: 0,
          destinationBuffer: destination,
          destinationOffset: 0,
          size: byteCount
        )
      }
    }

    try upload(to: headerBuffer, byteCount: headerByteCount, label: "dispatch header upload") {
      destination in
      withUnsafeBytes(of: &header) { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: headerByteCount)
      }
    }
    try upload(
      to: inputGroupBuffer,
      byteCount: groupByteCount,
      label: "dispatch groups upload"
    ) { destination in
      inputGroups.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: groupByteCount)
      }
    }
    try upload(
      to: inputEntryBuffer,
      byteCount: entryByteCount,
      label: "dispatch entries upload"
    ) { destination in
      inputEntries.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: entryByteCount)
      }
    }
    try upload(
      to: bindingBuffer,
      byteCount: bindingByteCount,
      label: "dispatch parameter binding upload"
    ) { destination in
      withUnsafeBytes(of: &binding) { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: bindingByteCount)
      }
    }
    try upload(
      to: cohortUniformBuffer,
      byteCount: cohortUniformByteCount,
      label: "cohort regional uniform upload"
    ) { destination in
      withUnsafeBytes(of: &cohortUniforms) { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: cohortUniformByteCount)
      }
    }
    try upload(
      to: tokenUniformBuffer,
      byteCount: tokenUniformByteCount,
      label: "cohort regional-token uniform upload"
    ) { destination in
      withUnsafeBytes(of: &tokenUniforms) { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: tokenUniformByteCount)
      }
    }
    try upload(
      to: environmentIdentifierBuffer,
      byteCount: environmentIdentifierByteCount,
      label: "active environment identifier upload"
    ) { destination in
      environmentIdentifiers.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: environmentIdentifierByteCount)
      }
    }
    try upload(
      to: moduleBuffer,
      byteCount: moduleByteCount,
      label: "cohort module descriptor upload"
    ) { destination in
      moduleRecords.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: moduleByteCount)
      }
    }
    try upload(
      to: programHeaderBuffer,
      byteCount: programHeaderByteCount,
      label: "cohort regional-token header upload"
    ) { destination in
      withUnsafeBytes(of: &programHeader) { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: programHeaderByteCount)
      }
    }
    try upload(
      to: layoutBuffer,
      byteCount: layoutByteCount,
      label: "cohort regional-token layout upload"
    ) { destination in
      layoutRecords.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: layoutByteCount)
      }
    }
    try upload(
      to: routeBuffer,
      byteCount: routeByteCount,
      label: "cohort regional-token route upload"
    ) { destination in
      routeRecords.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: routeByteCount)
      }
    }
    try upload(
      to: outgoingRouteCSRBuffer,
      byteCount: outgoingRouteCSRByteCount,
      label: "cohort outgoing regional-route CSR upload"
    ) { destination in
      outgoingRouteCSR.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: outgoingRouteCSRByteCount)
      }
    }
    try upload(
      to: parameterBuffer,
      byteCount: parameterByteCount,
      label: "cohort regional-token parameter upload"
    ) { destination in
      parameterRecords.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: parameterByteCount)
      }
    }
    try upload(
      to: inputRegionalStateBuffer,
      byteCount: regionalStateByteCount,
      label: "cohort regional input-state upload"
    ) { destination in
      initialRegionalStateRecords.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: regionalStateByteCount)
      }
    }
    try upload(
      to: inputTokenBuffer,
      byteCount: tokenStateByteCount,
      label: "cohort regional-token input-state upload"
    ) { destination in
      initialTokenValues.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: tokenStateByteCount)
      }
    }
    try upload(
      to: inputRouteHistoryStateBuffer,
      byteCount: routeHistoryStateByteCount,
      label: "cohort route-history state upload"
    ) { destination in
      initialRouteHistoryStateRecords.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: routeHistoryStateByteCount)
      }
    }
    try upload(
      to: inputRouteHistoryTimestampBuffer,
      byteCount: routeHistoryTimestampByteCount,
      label: "cohort route-history timestamp upload"
    ) { destination in
      initialRouteHistoryTimestamps.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: routeHistoryTimestampByteCount)
      }
    }
    try upload(
      to: inputRouteHistoryValueBuffer,
      byteCount: routeHistoryValueByteCount,
      label: "cohort route-history value upload"
    ) { destination in
      initialRouteHistoryValues.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: routeHistoryValueByteCount)
      }
    }
    try upload(
      to: inputRouteRuntimeStateBuffer,
      byteCount: routeRuntimeStateByteCount,
      label: "cohort route-runtime state upload"
    ) { destination in
      initialRouteRuntimeStateRecords.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: routeRuntimeStateByteCount)
      }
    }

    argumentTable.setAddress(headerBuffer.gpuAddress, index: 0)
    argumentTable.setAddress(inputGroupBuffer.gpuAddress, index: 1)
    argumentTable.setAddress(inputEntryBuffer.gpuAddress, index: 2)
    argumentTable.setAddress(bindingBuffer.gpuAddress, index: 3)
    argumentTable.setAddress(outputGroupBuffer.gpuAddress, index: 4)
    argumentTable.setAddress(outputEntryBuffer.gpuAddress, index: 5)
    argumentTable.setAddress(resultBuffer.gpuAddress, index: 6)
    argumentTable.setAddress(indirectArgumentBuffer.gpuAddress, index: 7)
    argumentTable.setAddress(cohortUniformBuffer.gpuAddress, index: 8)
    argumentTable.setAddress(tokenUniformBuffer.gpuAddress, index: 9)
    consumerArgumentTable.setAddress(headerBuffer.gpuAddress, index: 0)
    consumerArgumentTable.setAddress(outputGroupBuffer.gpuAddress, index: 1)
    consumerArgumentTable.setAddress(outputEntryBuffer.gpuAddress, index: 2)
    consumerArgumentTable.setAddress(workItemBuffer.gpuAddress, index: 3)
    regionalArgumentTable.setAddress(headerBuffer.gpuAddress, index: 0)
    regionalArgumentTable.setAddress(cohortUniformBuffer.gpuAddress, index: 1)
    regionalArgumentTable.setAddress(outputGroupBuffer.gpuAddress, index: 2)
    regionalArgumentTable.setAddress(outputEntryBuffer.gpuAddress, index: 3)
    regionalArgumentTable.setAddress(environmentIdentifierBuffer.gpuAddress, index: 4)
    regionalArgumentTable.setAddress(moduleBuffer.gpuAddress, index: 5)
    regionalArgumentTable.setAddress(inputRegionalStateBuffer.gpuAddress, index: 6)
    regionalArgumentTable.setAddress(outputRegionalStateBuffer.gpuAddress, index: 7)
    invocationCompactionArgumentTable.setAddress(headerBuffer.gpuAddress, index: 0)
    invocationCompactionArgumentTable.setAddress(cohortUniformBuffer.gpuAddress, index: 1)
    invocationCompactionArgumentTable.setAddress(outputGroupBuffer.gpuAddress, index: 2)
    invocationCompactionArgumentTable.setAddress(outputEntryBuffer.gpuAddress, index: 3)
    invocationCompactionArgumentTable.setAddress(
      environmentIdentifierBuffer.gpuAddress,
      index: 4
    )
    invocationCompactionArgumentTable.setAddress(
      compactedInvocationBuffer.gpuAddress,
      index: 5
    )
    invocationCompactionArgumentTable.setAddress(
      compactedInvocationCountBuffer.gpuAddress,
      index: 6
    )
    tokenArgumentTable.setAddress(headerBuffer.gpuAddress, index: 0)
    tokenArgumentTable.setAddress(cohortUniformBuffer.gpuAddress, index: 1)
    tokenArgumentTable.setAddress(tokenUniformBuffer.gpuAddress, index: 2)
    tokenArgumentTable.setAddress(bindingBuffer.gpuAddress, index: 3)
    tokenArgumentTable.setAddress(compactedInvocationBuffer.gpuAddress, index: 4)
    tokenArgumentTable.setAddress(compactedInvocationCountBuffer.gpuAddress, index: 5)
    tokenArgumentTable.setAddress(environmentIdentifierBuffer.gpuAddress, index: 6)
    tokenArgumentTable.setAddress(moduleBuffer.gpuAddress, index: 7)
    tokenArgumentTable.setAddress(programHeaderBuffer.gpuAddress, index: 8)
    tokenArgumentTable.setAddress(layoutBuffer.gpuAddress, index: 9)
    tokenArgumentTable.setAddress(parameterBuffer.gpuAddress, index: 10)
    tokenArgumentTable.setAddress(inputRegionalStateBuffer.gpuAddress, index: 11)
    tokenArgumentTable.setAddress(inputTokenBuffer.gpuAddress, index: 12)
    tokenArgumentTable.setAddress(outputTokenBuffer.gpuAddress, index: 13)
    tokenArgumentTable.setAddress(candidateTokenBuffer.gpuAddress, index: 14)
    tokenArgumentTable.setAddress(tokenLastUpdateBuffer.gpuAddress, index: 15)
    tokenArgumentTable.setAddress(routeBuffer.gpuAddress, index: 16)
    tokenArgumentTable.setAddress(inputRouteHistoryStateBuffer.gpuAddress, index: 17)
    tokenArgumentTable.setAddress(outputRouteHistoryStateBuffer.gpuAddress, index: 18)
    tokenArgumentTable.setAddress(inputRouteHistoryTimestampBuffer.gpuAddress, index: 19)
    tokenArgumentTable.setAddress(outputRouteHistoryTimestampBuffer.gpuAddress, index: 20)
    tokenArgumentTable.setAddress(inputRouteHistoryValueBuffer.gpuAddress, index: 21)
    tokenArgumentTable.setAddress(outputRouteHistoryValueBuffer.gpuAddress, index: 22)
    tokenArgumentTable.setAddress(resolvedRouteSlotBuffer.gpuAddress, index: 23)
    tokenArgumentTable.setAddress(inputRouteRuntimeStateBuffer.gpuAddress, index: 24)
    tokenArgumentTable.setAddress(outputRouteRuntimeStateBuffer.gpuAddress, index: 25)
    tokenArgumentTable.setAddress(selectedRouteIndexBuffer.gpuAddress, index: 26)
    tokenArgumentTable.setAddress(selectedRouteCountBuffer.gpuAddress, index: 27)
    tokenArgumentTable.setAddress(
      try sharedParameterBank.gpuAddress(.route, minimumScalarCount: 8),
      index: 28
    )
    tokenArgumentTable.setAddress(
      try sharedParameterBank.gpuAddress(
        .regionalDense,
        minimumScalarCount: regionalProgram.denseParameterCount
      ),
      index: 29
    )
    tokenArgumentTable.setAddress(outgoingRouteCSRBuffer.gpuAddress, index: 30)
    let maximumEntryCount = inputGroups.map { Int($0.entry_count) }.max() ?? 1
    let threadgroupWidth = min(64, pipeline.maxTotalThreadsPerThreadgroup)
    let consumerThreadgroupWidth = 64
    guard consumerPipeline.maxTotalThreadsPerThreadgroup >= consumerThreadgroupWidth else {
      throw TissueError.metal("dispatch consumer does not support 64-lane threadgroups")
    }
    guard regionalPipeline.maxTotalThreadsPerThreadgroup >= consumerThreadgroupWidth else {
      throw TissueError.metal("cohort regional kernel does not support 64-lane threadgroups")
    }
    guard
      invocationCompactionPipeline.maxTotalThreadsPerThreadgroup
        >= consumerThreadgroupWidth
    else {
      throw TissueError.metal("cohort invocation compaction does not support 64 lanes")
    }
    guard tokenPipeline.maxTotalThreadsPerThreadgroup >= consumerThreadgroupWidth else {
      throw TissueError.metal("cohort regional-token kernel does not support 64 lanes")
    }
    let feedback = try submit(label: "NumiBrain cohort materialization and indirect consume") {
      encoder in
      encoder.setComputePipelineState(pipeline)
      encoder.setArgumentTable(argumentTable)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(
          width: maximumEntryCount,
          height: inputGroups.count,
          depth: 1
        ),
        threadsPerThreadgroup: MTLSize(width: threadgroupWidth, height: 1, depth: 1)
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      encoder.setComputePipelineState(consumerPipeline)
      encoder.setArgumentTable(consumerArgumentTable)
      encoder.dispatchThreadgroups(
        indirectBuffer: indirectArgumentBuffer.gpuAddress,
        threadsPerThreadgroup: MTLSize(
          width: consumerThreadgroupWidth,
          height: 1,
          depth: 1
        )
      )
      encoder.setComputePipelineState(regionalPipeline)
      encoder.setArgumentTable(regionalArgumentTable)
      encoder.dispatchThreadgroups(
        indirectBuffer: indirectArgumentBuffer.gpuAddress
          + UInt64(indirectArgumentByteCount),
        threadsPerThreadgroup: MTLSize(
          width: consumerThreadgroupWidth,
          height: 1,
          depth: 1
        )
      )
      encoder.setComputePipelineState(invocationCompactionPipeline)
      encoder.setArgumentTable(invocationCompactionArgumentTable)
      encoder.dispatchThreadgroups(
        indirectBuffer: indirectArgumentBuffer.gpuAddress
          + UInt64(indirectArgumentByteCount * 2),
        threadsPerThreadgroup: MTLSize(
          width: consumerThreadgroupWidth,
          height: 1,
          depth: 1
        )
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      encoder.setComputePipelineState(tokenPipeline)
      encoder.setArgumentTable(tokenArgumentTable)
      encoder.dispatchThreadgroups(
        indirectBuffer: indirectArgumentBuffer.gpuAddress
          + UInt64(indirectArgumentByteCount * 2),
        threadsPerThreadgroup: MTLSize(
          width: consumerThreadgroupWidth,
          height: 1,
          depth: 1
        )
      )
    }
    _ = try submit(label: "NumiBrain dispatch-plan inspection") { encoder in
      encoder.copy(
        sourceBuffer: resultBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: 0,
        size: resultByteCount
      )
      encoder.copy(
        sourceBuffer: outputGroupBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: resultByteCount,
        size: groupByteCount
      )
      encoder.copy(
        sourceBuffer: outputEntryBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: resultByteCount + groupByteCount,
        size: entryByteCount
      )
      let indirectOffset = resultByteCount + groupByteCount + entryByteCount
      encoder.copy(
        sourceBuffer: indirectArgumentBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: indirectOffset,
        size: indirectArgumentByteCount * indirectArgumentCount
      )
      encoder.copy(
        sourceBuffer: workItemBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: indirectOffset + indirectStorageByteCount,
        size: workItemByteCount
      )
      encoder.copy(
        sourceBuffer: outputRegionalStateBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: indirectOffset + indirectStorageByteCount
          + workItemByteCount,
        size: regionalStateByteCount
      )
      let tokenOffset =
        indirectOffset + indirectStorageByteCount
        + workItemByteCount + regionalStateByteCount
      encoder.copy(
        sourceBuffer: outputTokenBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: tokenOffset,
        size: tokenStateByteCount
      )
      encoder.copy(
        sourceBuffer: tokenLastUpdateBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: tokenOffset + tokenStateByteCount,
        size: tokenLastUpdateByteCount
      )
      let routeHistoryStateOffset = tokenOffset + tokenStateByteCount
        + tokenLastUpdateByteCount
      let routeHistoryTimestampOffset = routeHistoryStateOffset
        + routeHistoryStateByteCount
      let routeHistoryValueOffset = routeHistoryTimestampOffset
        + routeHistoryTimestampByteCount
      let routeRuntimeStateOffset = routeHistoryValueOffset
        + routeHistoryValueByteCount
      let compactedInvocationOffset = routeRuntimeStateOffset
        + routeRuntimeStateByteCount
      let compactedInvocationCountOffset = compactedInvocationOffset
        + compactedInvocationByteCount
      encoder.copy(
        sourceBuffer: outputRouteHistoryStateBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: routeHistoryStateOffset,
        size: routeHistoryStateByteCount
      )
      encoder.copy(
        sourceBuffer: outputRouteHistoryTimestampBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: routeHistoryTimestampOffset,
        size: routeHistoryTimestampByteCount
      )
      encoder.copy(
        sourceBuffer: outputRouteHistoryValueBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: routeHistoryValueOffset,
        size: routeHistoryValueByteCount
      )
      encoder.copy(
        sourceBuffer: outputRouteRuntimeStateBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: routeRuntimeStateOffset,
        size: routeRuntimeStateByteCount
      )
      encoder.copy(
        sourceBuffer: compactedInvocationBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: compactedInvocationOffset,
        size: compactedInvocationByteCount
      )
      encoder.copy(
        sourceBuffer: compactedInvocationCountBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: compactedInvocationCountOffset,
        size: compactedInvocationCountByteCount
      )
    }

    let inspection = stagingBuffer.contents()
    let result = inspection.load(as: NBDispatchPlanResult.self)
    guard result.status == 0,
      result.group_count == UInt32(inputGroups.count),
      result.entry_count == UInt32(inputEntries.count),
      result.plan_fingerprint == plan.fingerprint,
      result.parameter_version_fingerprint == parameterVersion.fingerprint
    else {
      throw TissueError.metal(
        "GPU dispatch materialization failed with status \(result.status)"
      )
    }
    let outputGroups = Array(
      UnsafeBufferPointer(
        start: inspection.advanced(by: resultByteCount)
          .assumingMemoryBound(to: NBDispatchGroup.self),
        count: inputGroups.count
      )
    )
    let outputEntries = Array(
      UnsafeBufferPointer(
        start: inspection.advanced(by: resultByteCount + groupByteCount)
          .assumingMemoryBound(to: NBDispatchEntry.self),
        count: inputEntries.count
      )
    )
    let indirectOffset = resultByteCount + groupByteCount + entryByteCount
    let indirectArguments = Array(
      UnsafeBufferPointer(
        start: inspection.advanced(by: indirectOffset)
          .assumingMemoryBound(to: DispatchIndirectArguments.self),
        count: indirectArgumentCount
      )
    )
    let outputWorkRecords = Array(
      UnsafeBufferPointer(
        start: inspection.advanced(by: indirectOffset + indirectStorageByteCount)
          .assumingMemoryBound(to: NBDispatchWorkItem.self),
        count: inputEntries.count
      )
    )
    let outputRegionalStateRecords = Array(
      UnsafeBufferPointer(
        start: inspection.advanced(
          by: indirectOffset + indirectStorageByteCount + workItemByteCount
        ).assumingMemoryBound(to: NBRegionalModuleState.self),
        count: regionalStateCount
      )
    )
    let tokenOffset =
      indirectOffset + indirectStorageByteCount
      + workItemByteCount + regionalStateByteCount
    let outputTokenValues = Array(
      UnsafeBufferPointer(
        start: inspection.advanced(by: tokenOffset)
          .assumingMemoryBound(to: Float.self),
        count: tokenStateCount
      )
    )
    let outputTokenLastUpdates = Array(
      UnsafeBufferPointer(
        start: inspection.advanced(by: tokenOffset + tokenStateByteCount)
          .assumingMemoryBound(to: UInt64.self),
        count: regionalStateCount
      )
    )
    let routeHistoryStateOffset = tokenOffset + tokenStateByteCount
      + tokenLastUpdateByteCount
    let routeHistoryTimestampOffset = routeHistoryStateOffset
      + routeHistoryStateByteCount
    let routeHistoryValueOffset = routeHistoryTimestampOffset
      + routeHistoryTimestampByteCount
    let routeRuntimeStateOffset = routeHistoryValueOffset
      + routeHistoryValueByteCount
    let compactedInvocationOffset = routeRuntimeStateOffset
      + routeRuntimeStateByteCount
    let compactedInvocationCountOffset = compactedInvocationOffset
      + compactedInvocationByteCount
    let outputRouteHistoryStateRecords = Array(
      UnsafeBufferPointer(
        start: inspection.advanced(by: routeHistoryStateOffset)
          .assumingMemoryBound(to: NBRegionalRouteHistoryState.self),
        count: cohortRouteCount
      )
    )
    let outputRouteHistoryTimestamps = Array(
      UnsafeBufferPointer(
        start: inspection.advanced(by: routeHistoryTimestampOffset)
          .assumingMemoryBound(to: UInt64.self),
        count: cohortHistoryTimestampCount
      )
    )
    let outputRouteHistoryValues = Array(
      UnsafeBufferPointer(
        start: inspection.advanced(by: routeHistoryValueOffset)
          .assumingMemoryBound(to: Float.self),
        count: cohortHistoryScalarCount
      )
    )
    let outputRouteRuntimeStateRecords = Array(
      UnsafeBufferPointer(
        start: inspection.advanced(by: routeRuntimeStateOffset)
          .assumingMemoryBound(to: NBRegionalRouteRuntimeState.self),
        count: cohortRouteCount
      )
    )
    let outputCompactedInvocationRecords = Array(
      UnsafeBufferPointer(
        start: inspection.advanced(by: compactedInvocationOffset)
          .assumingMemoryBound(to: NBDueInvocation.self),
        count: compactedInvocationCapacity
      )
    )
    let outputCompactedInvocationCounts = Array(
      UnsafeBufferPointer(
        start: inspection.advanced(by: compactedInvocationCountOffset)
          .assumingMemoryBound(to: UInt32.self),
        count: environmentIdentifiers.count
      )
    )
    let groups = try outputGroups.map { record -> BrainDispatchGroup in
      guard record.entry_offset <= UInt32(outputEntries.count),
        record.entry_count <= UInt32(outputEntries.count) - record.entry_offset,
        let clockClass = BrainClockClass(rawValue: record.clock_class)
      else {
        throw TissueError.metal("GPU materialized an invalid dispatch-group span")
      }
      let lower = Int(record.entry_offset)
      let upper = lower + Int(record.entry_count)
      let entries = outputEntries[lower..<upper].map { entry in
        BrainDispatchEntry(
          environmentIdentifier: entry.environment_identifier,
          reasons: BrainInvocationReason(rawValue: entry.reason_flags),
          interruptMask: BrainInterruptMask(rawValue: entry.interrupt_mask)
        )
      }
      return BrainDispatchGroup(
        timestamp: BrainTimestamp(microseconds: record.timestamp_microseconds),
        moduleIdentifier: record.module_id,
        clockClass: clockClass,
        entries: entries
      )
    }
    guard groups == plan.groups else {
      throw TissueError.metal("GPU materialization does not match the compiled dispatch plan")
    }
    let workItems = try outputWorkRecords.map { record -> BrainDispatchWorkItem in
      guard let clockClass = BrainClockClass(rawValue: record.clock_class),
        record.group_index < UInt32(groups.count)
      else {
        throw TissueError.metal("GPU indirect consumer produced an invalid work item")
      }
      return BrainDispatchWorkItem(
        timestamp: BrainTimestamp(microseconds: record.timestamp_microseconds),
        interruptMask: BrainInterruptMask(rawValue: record.interrupt_mask),
        environmentIdentifier: record.environment_identifier,
        reasons: BrainInvocationReason(rawValue: record.reason_flags),
        moduleIdentifier: record.module_id,
        clockClass: clockClass,
        groupIndex: record.group_index
      )
    }
    let workFingerprint = outputWorkRecords.withUnsafeBufferPointer { records in
      nb_brain_abi_dispatch_work_fingerprint(
        plan.fingerprint,
        parameterVersion.fingerprint,
        records.baseAddress,
        UInt32(records.count)
      )
    }
    let expectedIndirectThreadgroups = UInt32(
      (inputEntries.count + consumerThreadgroupWidth - 1) / consumerThreadgroupWidth
    )
    let expectedRegionalIndirectThreadgroups = UInt32(
      (environmentIdentifiers.count + consumerThreadgroupWidth - 1)
        / consumerThreadgroupWidth
    )
    guard workItems == planWorkItems,
      workFingerprint == plan.workFingerprint,
      indirectArguments[0].threadgroupsX == expectedIndirectThreadgroups,
      indirectArguments[0].threadgroupsY == 1,
      indirectArguments[0].threadgroupsZ == 1,
      indirectArguments[1].threadgroupsX == expectedRegionalIndirectThreadgroups,
      indirectArguments[1].threadgroupsY == 1,
      indirectArguments[1].threadgroupsZ == 1,
      indirectArguments[2].threadgroupsX == UInt32(environmentIdentifiers.count),
      indirectArguments[2].threadgroupsY == 1,
      indirectArguments[2].threadgroupsZ == 1
    else {
      throw TissueError.metal("GPU indirect dispatch consumption does not match the plan")
    }
    var compactedInvocationCount = 0
    for (environmentIndex, environmentIdentifier) in
      environmentIdentifiers.enumerated()
    {
      let count = Int(outputCompactedInvocationCounts[environmentIndex])
      let expected = invocationsByEnvironment[environmentIdentifier] ?? []
      guard count == expected.count, count <= invocationCapacityPerEnvironment else {
        throw TissueError.metal("GPU invocation compaction produced an invalid count")
      }
      let base = environmentIndex * invocationCapacityPerEnvironment
      let actual = try (0..<count).map { invocationIndex in
        let record = outputCompactedInvocationRecords[base + invocationIndex]
        guard record.environment_identifier == environmentIdentifier,
          record.reserved == 0
        else {
          throw TissueError.metal("GPU invocation compaction crossed agent ownership")
        }
        return try BrainModuleInvocation(abiRecord: record)
      }
      guard actual == expected else {
        throw TissueError.metal("GPU invocation compaction does not match the CPU plan")
      }
      compactedInvocationCount += count
    }
    let compactedInvocationFingerprint =
      environmentIdentifiers.withUnsafeBufferPointer { identifiers in
        outputCompactedInvocationRecords.withUnsafeBufferPointer { invocations in
          outputCompactedInvocationCounts.withUnsafeBufferPointer { counts in
            nb_brain_abi_cohort_invocation_fingerprint(
              plan.fingerprint,
              parameterVersion.fingerprint,
              identifiers.baseAddress,
              UInt32(identifiers.count),
              invocations.baseAddress,
              counts.baseAddress,
              UInt32(invocationCapacityPerEnvironment)
            )
          }
        }
      }
    guard compactedInvocationCount == plan.entryCount,
      compactedInvocationFingerprint > 0
    else {
      throw TissueError.metal("GPU invocation compaction has no compiled identity")
    }
    let regionalStates = environmentIdentifiers.enumerated().map {
      environmentIndex, environmentIdentifier in
      let lower = environmentIndex * schedule.modules.count
      let upper = lower + schedule.modules.count
      return BrainCohortRegionalState(
        environmentIdentifier: environmentIdentifier,
        states: outputRegionalStateRecords[lower..<upper].map {
          RegionalModuleState(abiRecord: $0)
        }
      )
    }
    let regionalStateFingerprint = environmentIdentifiers.withUnsafeBufferPointer {
      identifiers in
      outputRegionalStateRecords.withUnsafeBufferPointer { states in
        nb_brain_abi_cohort_regional_state_fingerprint(
          plan.fingerprint,
          parameterVersion.fingerprint,
          schedule.fingerprint,
          identifiers.baseAddress,
          UInt32(identifiers.count),
          states.baseAddress,
          UInt32(schedule.modules.count)
        )
      }
    }
    guard regionalStateFingerprint > 0 else {
      throw TissueError.metal("GPU cohort regional state has no compiled identity")
    }
    guard outputTokenValues.allSatisfy(\.isFinite),
      zip(outputTokenLastUpdates, outputRegionalStateRecords).allSatisfy({
        lastUpdate, state in
        lastUpdate == state.last_update_microseconds
      })
    else {
      throw TissueError.metal("GPU cohort regional-token execution is invalid or incomplete")
    }
    let tokenStates = environmentIdentifiers.enumerated().map {
      environmentIndex, environmentIdentifier in
      let lower = environmentIndex * regionalProgram.scalarCount
      let upper = lower + regionalProgram.scalarCount
      return BrainCohortTokenState(
        environmentIdentifier: environmentIdentifier,
        values: Array(outputTokenValues[lower..<upper])
      )
    }
    let tokenStateFingerprint = environmentIdentifiers.withUnsafeBufferPointer {
      identifiers in
      outputTokenValues.withUnsafeBufferPointer { values in
        nb_brain_abi_cohort_token_state_fingerprint(
          plan.fingerprint,
          parameterVersion.fingerprint,
          regionalProgram.fingerprint,
          identifiers.baseAddress,
          UInt32(identifiers.count),
          values.baseAddress,
          UInt32(regionalProgram.scalarCount)
        )
      }
    }
    guard tokenStateFingerprint > 0 else {
      throw TissueError.metal("GPU cohort regional-token state has no compiled identity")
    }
    let routingStates = try environmentIdentifiers.enumerated().map {
      environmentIndex, environmentIdentifier in
      let routeLower = environmentIndex * routeCount
      let routeUpper = routeLower + routeCount
      let timestampLower = environmentIndex * historyTimestampCountPerEnvironment
      let timestampUpper = timestampLower + historyTimestampCountPerEnvironment
      let valueLower = environmentIndex * routeHistoryScalarCount
      let valueUpper = valueLower + routeHistoryScalarCount
      return BrainCohortRoutingState(
        environmentIdentifier: environmentIdentifier,
        routeHistory: try RegionalRouteHistory(
          program: regionalProgram,
          states: outputRouteHistoryStateRecords[routeLower..<routeUpper].map {
            RegionalRouteHistoryState(abiRecord: $0)
          },
          timestamps: Array(outputRouteHistoryTimestamps[timestampLower..<timestampUpper]),
          values: Array(outputRouteHistoryValues[valueLower..<valueUpper])
        ),
        routingState: try RegionalRoutingState(
          program: regionalProgram,
          states: outputRouteRuntimeStateRecords[routeLower..<routeUpper].map {
            RegionalRouteRuntimeState(abiRecord: $0)
          }
        )
      )
    }
    let routingStateFingerprint = environmentIdentifiers.withUnsafeBufferPointer {
      identifiers in
      outputRouteHistoryStateRecords.withUnsafeBufferPointer { historyStates in
        outputRouteHistoryTimestamps.withUnsafeBufferPointer { timestamps in
          outputRouteHistoryValues.withUnsafeBufferPointer { values in
            outputRouteRuntimeStateRecords.withUnsafeBufferPointer { runtimeStates in
              nb_brain_abi_cohort_routing_state_fingerprint(
                plan.fingerprint,
                parameterVersion.fingerprint,
                regionalProgram.fingerprint,
                identifiers.baseAddress,
                UInt32(identifiers.count),
                historyStates.baseAddress,
                timestamps.baseAddress,
                values.baseAddress,
                runtimeStates.baseAddress,
                UInt32(routeCount),
                UInt32(routeHistoryCapacity),
                UInt32(routeHistoryScalarCount)
              )
            }
          }
        }
      }
    }
    guard routingStateFingerprint > 0 else {
      throw TissueError.metal("GPU cohort routing state has no compiled identity")
    }
    return Materialization(
      deviceName: device.name,
      planFingerprint: result.plan_fingerprint,
      parameterVersionFingerprint: result.parameter_version_fingerprint,
      groups: groups,
      workItems: workItems,
      workFingerprint: workFingerprint,
      indirectThreadgroupCount: indirectArguments[0].threadgroupsX,
      compactedInvocationCount: compactedInvocationCount,
      compactedInvocationFingerprint: compactedInvocationFingerprint,
      compactedInvocationByteCount: compactedInvocationByteCount
        + compactedInvocationCountByteCount,
      regionalStates: regionalStates,
      regionalStateFingerprint: regionalStateFingerprint,
      regionalIndirectThreadgroupCount: indirectArguments[1].threadgroupsX,
      regionalStateByteCount: regionalStateByteCount,
      tokenStates: tokenStates,
      tokenStateFingerprint: tokenStateFingerprint,
      tokenIndirectThreadgroupCount: indirectArguments[2].threadgroupsX,
      tokenStateByteCount: tokenStateByteCount,
      routingStates: routingStates,
      routingStateFingerprint: routingStateFingerprint,
      routeHistoryByteCount: routeHistoryByteCount,
      routeRuntimeStateByteCount: routeRuntimeStateByteCount,
      status: result.status,
      privateInputByteCount: headerByteCount + groupByteCount + entryByteCount
        + bindingByteCount + cohortUniformByteCount + environmentIdentifierByteCount
        + moduleByteCount + regionalStateByteCount + tokenUniformByteCount
        + programHeaderByteCount + layoutByteCount + routeByteCount
        + outgoingRouteOffsetByteCount + outgoingRouteIndexByteCount
        + parameterByteCount + tokenStateByteCount + routeHistoryByteCount
        + routeRuntimeStateByteCount,
      privateOutputByteCount: groupByteCount + entryByteCount + resultByteCount
        + indirectStorageByteCount + workItemByteCount + regionalStateByteCount
        + tokenStateByteCount * 2 + tokenLastUpdateByteCount
        + routeHistoryByteCount + routeRuntimeStateByteCount
        + resolvedRouteSlotByteCount + selectedRouteIndexByteCount
        + selectedRouteCountByteCount + compactedInvocationByteCount
        + compactedInvocationCountByteCount,
      gpuStartSeconds: feedback.gpuStartTime,
      gpuEndSeconds: feedback.gpuEndTime
    )
  }
}

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
    public let regionalStates: [BrainCohortRegionalState]
    public let regionalStateFingerprint: UInt64
    public let regionalIndirectThreadgroupCount: UInt32
    public let regionalStateByteCount: Int
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

  public static func materialize(
    plan: BrainDispatchPlan,
    schedule: BrainModuleSchedule,
    parameterVersion: BrainParameterVersion,
    initialRegionalStates: [BrainCohortRegionalState]? = nil,
    device requestedDevice: (any MTLDevice)? = nil
  ) throws -> Materialization {
    guard plan.scheduleFingerprint == schedule.fingerprint,
      plan.scheduleFingerprint == parameterVersion.scheduleFingerprint,
      plan.parameterVersionFingerprint == parameterVersion.fingerprint
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
    let (regionalStateCount, regionalStateCountOverflow) =
      environmentIdentifiers.count.multipliedReportingOverflow(by: schedule.modules.count)
    guard !regionalStateCountOverflow, regionalStateCount <= Int(UInt32.max) else {
      throw TissueError.metal("cohort regional-state count exceeds the ABI limit")
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
    for item in plan.workItems {
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
    let moduleRecords = schedule.modules.map(\.abiRecord)
    var cohortUniforms = NBDispatchCohortUniforms()
    cohortUniforms.plan_fingerprint = plan.fingerprint
    cohortUniforms.parameter_version_fingerprint = parameterVersion.fingerprint
    cohortUniforms.environment_count = UInt32(environmentIdentifiers.count)
    cohortUniforms.module_count = UInt32(schedule.modules.count)
    cohortUniforms.state_count = UInt32(regionalStateCount)
    cohortUniforms.flags = 0
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
      )
    else {
      throw TissueError.metal("cohort dispatch functions are missing from the Metal library")
    }
    let pipeline: any MTLComputePipelineState
    let consumerPipeline: any MTLComputePipelineState
    let regionalPipeline: any MTLComputePipelineState
    do {
      pipeline = try device.makeComputePipelineState(function: function)
      consumerPipeline = try device.makeComputePipelineState(function: consumerFunction)
      regionalPipeline = try device.makeComputePipelineState(function: regionalFunction)
    } catch {
      throw TissueError.metal("dispatch-plan pipeline creation failed: \(error)")
    }
    let argumentDescriptor = MTL4ArgumentTableDescriptor()
    argumentDescriptor.label = "NumiBrain dispatch-plan arguments"
    argumentDescriptor.maxBufferBindCount = 9
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

    let headerByteCount = MemoryLayout<NBDispatchPlanHeader>.stride
    let groupByteCount = inputGroups.count * MemoryLayout<NBDispatchGroup>.stride
    let entryByteCount = inputEntries.count * MemoryLayout<NBDispatchEntry>.stride
    let bindingByteCount = MemoryLayout<NBParameterVersionBinding>.stride
    let resultByteCount = MemoryLayout<NBDispatchPlanResult>.stride
    let indirectArgumentByteCount = MemoryLayout<DispatchIndirectArguments>.stride
    let indirectArgumentCount = 2
    let indirectStorageByteCount = 32
    let workItemByteCount = inputEntries.count * MemoryLayout<NBDispatchWorkItem>.stride
    let cohortUniformByteCount = MemoryLayout<NBDispatchCohortUniforms>.stride
    let environmentIdentifierByteCount = environmentIdentifiers.count * MemoryLayout<UInt32>.stride
    let moduleByteCount = moduleRecords.count * MemoryLayout<NBModuleDescriptor>.stride
    let regionalStateByteCount =
      regionalStateCount
      * MemoryLayout<NBRegionalModuleState>.stride
    let inspectionByteCount =
      resultByteCount + groupByteCount + entryByteCount
      + indirectStorageByteCount + workItemByteCount + regionalStateByteCount
    let stagingByteCount = max(
      inspectionByteCount,
      max(
        max(headerByteCount, groupByteCount),
        max(
          max(entryByteCount, bindingByteCount),
          max(
            max(cohortUniformByteCount, environmentIdentifierByteCount),
            max(moduleByteCount, regionalStateByteCount)
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
    let cohortUniformBuffer = try privateBuffer(
      length: cohortUniformByteCount,
      label: "NumiBrain immutable cohort regional uniforms"
    )
    let environmentIdentifierBuffer = try privateBuffer(
      length: environmentIdentifierByteCount,
      label: "NumiBrain immutable active environment identifiers"
    )
    let moduleBuffer = try privateBuffer(
      length: moduleByteCount,
      label: "NumiBrain immutable cohort module descriptors"
    )
    let inputRegionalStateBuffer = try privateBuffer(
      length: regionalStateByteCount,
      label: "NumiBrain private cohort regional input generation"
    )
    let outputRegionalStateBuffer = try privateBuffer(
      length: regionalStateByteCount,
      label: "NumiBrain private cohort regional output generation"
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
    residencyDescriptor.initialCapacity = 15
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
      cohortUniformBuffer,
      environmentIdentifierBuffer,
      moduleBuffer,
      inputRegionalStateBuffer,
      outputRegionalStateBuffer,
      stagingBuffer,
    ]
    for buffer in buffers {
      residencySet.addAllocation(buffer)
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
      to: inputRegionalStateBuffer,
      byteCount: regionalStateByteCount,
      label: "cohort regional input-state upload"
    ) { destination in
      initialRegionalStateRecords.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        destination.copyMemory(from: source, byteCount: regionalStateByteCount)
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
    let maximumEntryCount = inputGroups.map { Int($0.entry_count) }.max() ?? 1
    let threadgroupWidth = min(64, pipeline.maxTotalThreadsPerThreadgroup)
    let consumerThreadgroupWidth = 64
    guard consumerPipeline.maxTotalThreadsPerThreadgroup >= consumerThreadgroupWidth else {
      throw TissueError.metal("dispatch consumer does not support 64-lane threadgroups")
    }
    guard regionalPipeline.maxTotalThreadsPerThreadgroup >= consumerThreadgroupWidth else {
      throw TissueError.metal("cohort regional kernel does not support 64-lane threadgroups")
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
    guard workItems == plan.workItems,
      workFingerprint == plan.workFingerprint,
      indirectArguments[0].threadgroupsX == expectedIndirectThreadgroups,
      indirectArguments[0].threadgroupsY == 1,
      indirectArguments[0].threadgroupsZ == 1,
      indirectArguments[1].threadgroupsX == expectedRegionalIndirectThreadgroups,
      indirectArguments[1].threadgroupsY == 1,
      indirectArguments[1].threadgroupsZ == 1
    else {
      throw TissueError.metal("GPU indirect dispatch consumption does not match the plan")
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
    return Materialization(
      deviceName: device.name,
      planFingerprint: result.plan_fingerprint,
      parameterVersionFingerprint: result.parameter_version_fingerprint,
      groups: groups,
      workItems: workItems,
      workFingerprint: workFingerprint,
      indirectThreadgroupCount: indirectArguments[0].threadgroupsX,
      regionalStates: regionalStates,
      regionalStateFingerprint: regionalStateFingerprint,
      regionalIndirectThreadgroupCount: indirectArguments[1].threadgroupsX,
      regionalStateByteCount: regionalStateByteCount,
      status: result.status,
      privateInputByteCount: headerByteCount + groupByteCount + entryByteCount
        + bindingByteCount + cohortUniformByteCount + environmentIdentifierByteCount
        + moduleByteCount + regionalStateByteCount,
      privateOutputByteCount: groupByteCount + entryByteCount + resultByteCount
        + indirectStorageByteCount + workItemByteCount + regionalStateByteCount,
      gpuStartSeconds: feedback.gpuStartTime,
      gpuEndSeconds: feedback.gpuEndTime
    )
  }
}

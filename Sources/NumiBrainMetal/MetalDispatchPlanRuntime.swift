import Foundation
@preconcurrency import Metal
import NumiBrainABI
import NumiBrainCore

/// Bounded Metal 4 materializer for a compiled cohort dispatch plan. The plan
/// is authenticated by the compiled C ABI before upload, then copied into
/// private region-major buffers under the immutable parameter-version binding.
@available(macOS 26.0, *)
public enum MetalDispatchPlanRuntime {
  public struct Materialization: Equatable, Sendable {
    public let deviceName: String
    public let planFingerprint: UInt64
    public let parameterVersionFingerprint: UInt64
    public let groups: [BrainDispatchGroup]
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

  private final class FeedbackBox: @unchecked Sendable {
    var feedback: (any MTL4CommitFeedback)?
  }

  public static func materialize(
    plan: BrainDispatchPlan,
    parameterVersion: BrainParameterVersion,
    device requestedDevice: (any MTLDevice)? = nil
  ) throws -> Materialization {
    guard plan.scheduleFingerprint == parameterVersion.scheduleFingerprint,
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
      MemoryLayout<NBParameterVersionBinding>.stride
        == BrainParameterVersion.bindingByteCount
    else {
      throw TissueError.metal("Swift dispatch-plan ABI does not match NumiBrainABI")
    }

    var header = plan.abiHeader
    let inputGroups = plan.groupABIRecords
    let inputEntries = plan.entryABIRecords
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
    guard let function = library.makeFunction(name: "materialize_dispatch_plan") else {
      throw TissueError.metal("materialize_dispatch_plan is missing from the Metal library")
    }
    let pipeline: any MTLComputePipelineState
    do {
      pipeline = try device.makeComputePipelineState(function: function)
    } catch {
      throw TissueError.metal("dispatch-plan pipeline creation failed: \(error)")
    }
    let argumentDescriptor = MTL4ArgumentTableDescriptor()
    argumentDescriptor.label = "NumiBrain dispatch-plan arguments"
    argumentDescriptor.maxBufferBindCount = 7
    argumentDescriptor.initializeBindings = true
    guard let argumentTable = try? device.makeArgumentTable(descriptor: argumentDescriptor) else {
      throw TissueError.metal("failed to create the dispatch-plan argument table")
    }

    let headerByteCount = MemoryLayout<NBDispatchPlanHeader>.stride
    let groupByteCount = inputGroups.count * MemoryLayout<NBDispatchGroup>.stride
    let entryByteCount = inputEntries.count * MemoryLayout<NBDispatchEntry>.stride
    let bindingByteCount = MemoryLayout<NBParameterVersionBinding>.stride
    let resultByteCount = MemoryLayout<NBDispatchPlanResult>.stride
    let inspectionByteCount = resultByteCount + groupByteCount + entryByteCount
    let stagingByteCount = max(
      inspectionByteCount,
      max(max(headerByteCount, groupByteCount), max(entryByteCount, bindingByteCount))
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
    residencyDescriptor.initialCapacity = 8
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

    argumentTable.setAddress(headerBuffer.gpuAddress, index: 0)
    argumentTable.setAddress(inputGroupBuffer.gpuAddress, index: 1)
    argumentTable.setAddress(inputEntryBuffer.gpuAddress, index: 2)
    argumentTable.setAddress(bindingBuffer.gpuAddress, index: 3)
    argumentTable.setAddress(outputGroupBuffer.gpuAddress, index: 4)
    argumentTable.setAddress(outputEntryBuffer.gpuAddress, index: 5)
    argumentTable.setAddress(resultBuffer.gpuAddress, index: 6)
    let maximumEntryCount = inputGroups.map { Int($0.entry_count) }.max() ?? 1
    let threadgroupWidth = min(64, pipeline.maxTotalThreadsPerThreadgroup)
    let feedback = try submit(label: "NumiBrain cohort dispatch materialization") { encoder in
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
    return Materialization(
      deviceName: device.name,
      planFingerprint: result.plan_fingerprint,
      parameterVersionFingerprint: result.parameter_version_fingerprint,
      groups: groups,
      status: result.status,
      privateInputByteCount: headerByteCount + groupByteCount + entryByteCount
        + bindingByteCount,
      privateOutputByteCount: groupByteCount + entryByteCount + resultByteCount,
      gpuStartSeconds: feedback.gpuStartTime,
      gpuEndSeconds: feedback.gpuEndTime
    )
  }
}

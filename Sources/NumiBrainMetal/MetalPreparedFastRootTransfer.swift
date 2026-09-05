import Foundation
@preconcurrency import Metal
import NumiBrainABI
import NumiBrainCore

@available(macOS 26.0, *)
public extension MetalTissueRuntime {
  /// Checkpoint boundary only. The owner must keep the root exclusively quarantined from this call
  /// through completion: no publish, abort, next root, or direct component inspection in between.
  /// Existing fast GPU work must have successful terminal feedback. The supplied command buffer is
  /// already begun, has no open encoder, and must be submitted with these exact commit options.
  /// This method neither creates a queue nor publishes a fast/cognitive/physical generation.
  func encodePreparedFastRootCapture(
    for ticket: ProvisionalFastRootSubmissionTicket,
    root: BrainJointTransactionToken,
    base: MetalTissueCheckpoint,
    device: any MTLDevice,
    commandBuffer: any MTL4CommandBuffer,
    options: MTL4CommitOptions,
    maximumPayloadBytes: Int = 536_870_912,
    completion: @escaping @Sendable (Result<MetalPreparedFastRootImage, Error>) -> Void
  ) throws {
    try base.validate()
    guard device.registryID == deviceRegistryID,
      try ticket.completionFeedbackIfAvailable() != nil,
      ticket.provisional.transactionFingerprint == root.fingerprint,
      ticket.provisional.acceptedTimestamp == root.targetTimestamp,
      ticket.provisional.shadowGeneration == root.shadowGeneration,
      base.committedSchedulerGeneration == root.baseBrainGeneration,
      (base.committedSchedulerTime?.rawValue ?? 0) == root.committedTimestamp.rawValue,
      base.parameterVersionFingerprint == root.parameterVersionFingerprint else {
      throw TissueError.transaction("fast recovery capture needs the completed matching native root")
    }
    // Checks immutable size/configuration against the actual live runtime, without changing it.
    try validateCheckpointCompatibility(base)
    let status = try numanXFastPrepareStatus(for: ticket)
    try status.validate(for: device)
    let statusBytes = Data(bytes: status.buffer.contents().advanced(by: status.byteOffset),
      count: MetalNumanXFastPrepareStatusLease.byteCount)
    try PreparedFastTransfer.validateGate(statusBytes, ticket: ticket,
      programFingerprint: numanXFastProgramFingerprint)
    let sources = try makeNumanXPreparedFastStateSources(for: ticket)
    let resources = try PreparedFastTransfer.Resources(device: device, sources: sources,
      base: base, maximumPayloadBytes: maximumPayloadBytes)
    commandBuffer.useResidencySet(resources.residency)
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
      throw TissueError.metal("prepared-fast capture encoder allocation failed")
    }
    encoder.label = "NumiBrain native prepared fast-root capture"
    encoder.barrier(afterQueueStages: [.dispatch, .blit], beforeStages: .blit, visibilityOptions: .device)
    for (source, offset) in zip(resources.sources, resources.offsets) {
      encoder.copy(sourceBuffer: source.buffer, sourceOffset: source.byteOffset,
        destinationBuffer: resources.staging, destinationOffset: offset, size: source.byteCount)
    }
    encoder.barrier(afterStages: .blit, beforeQueueStages: [.dispatch, .blit], visibilityOptions: .device)
    encoder.endEncoding()
    let programFingerprint = numanXFastProgramFingerprint
    let rootImage = BrainPreparedRoot(root)
    options.addFeedbackHandler { feedback in
      let result: Result<MetalPreparedFastRootImage, Error>
      if let error = feedback.error { result = .failure(error) }
      else {
        result = Result {
          let records = zip(resources.sources, resources.offsets).map { source, offset in
            MetalPreparedFastSourceImage(semanticIdentifier: source.semanticIdentifier,
              bytes: Data(bytes: resources.staging.contents().advanced(by: offset), count: source.byteCount))
          }
          return try MetalPreparedFastRootImage(root: rootImage,
            fastProgramFingerprint: programFingerprint, base: base, sources: records,
            maximumPayloadBytes: maximumPayloadBytes)
        }
      }
      // Retain the original fast ticket and source buffers even if a caller drops its capture handle.
      withExtendedLifetime(ticket) { completion(result) }
    }
  }
}

@available(macOS 26.0, *)
private enum PreparedFastTransfer {
  static func validateGate(_ bytes: Data,
    ticket: MetalTissueRuntime.ProvisionalFastRootSubmissionTicket,
    programFingerprint: UInt64) throws {
    guard bytes.count == 128, MemoryLayout<NBNumanXFastPrepareStatusGPU>.stride == 128 else {
      throw TissueError.transaction("fast-prepare gate ABI changed")
    }
    let record = bytes.withUnsafeBytes { $0.loadUnaligned(as: NBNumanXFastPrepareStatusGPU.self) }
    let provisional = ticket.provisional
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in bytes.prefix(120) { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
    if hash == 0 { hash = 14_695_981_039_346_656_037 }
    guard record.abiVersion == UInt32(NB_NUMANX_FAST_PREPARE_STATUS_ABI_VERSION),
      record.structBytes == 128, record.status == UInt32(NB_NUMANX_FAST_PREPARE_SUCCESS.rawValue),
      record.environment == provisional.environmentIdentifier,
      record.controlStep == provisional.controlStep, record.substepIndex == provisional.substepIndex,
      record.physicsSubstepCount == 1, record.fastProgramFingerprint == programFingerprint,
      record.transactionFingerprint == provisional.transactionFingerprint,
      record.substepFingerprint == provisional.substepFingerprint,
      record.expectedPhysicsGeneration == provisional.expectedPhysicsGeneration,
      record.shadowGeneration == provisional.shadowGeneration,
      record.acceptedTimestampMicroseconds == provisional.acceptedTimestamp.rawValue,
      record.gateFingerprint == hash else {
      throw TissueError.transaction("failed or mismatched native fast-prepare gate")
    }
  }

  final class Resources: @unchecked Sendable {
    let sources: [MetalNumanXBrainFastStateSource]
    let offsets: [Int]
    let staging: any MTLBuffer
    let residency: any MTLResidencySet

    init(device: any MTLDevice, sources: [MetalNumanXBrainFastStateSource],
      base: MetalTissueCheckpoint, maximumPayloadBytes: Int) throws {
      guard maximumPayloadBytes > 0, maximumPayloadBytes <= 536_870_912,
        sources.count > 1, sources.count <= MetalTissueCheckpointBufferKind.allCases.count + 1,
        Set(sources.map(\.semanticIdentifier)).count == sources.count else {
        throw TissueError.transaction("fast capture source/budget bounds")
      }
      var payloadBytes = 0
      for data in base.buffers.map(\.data) {
        guard data.count <= maximumPayloadBytes - payloadBytes else {
          throw TissueError.transaction("base checkpoint exceeds capture budget")
        }
        payloadBytes += data.count
      }
      var offsets: [Int] = [], stagingBytes = 0
      for source in sources {
        guard source.buffer.device.registryID == device.registryID, source.byteOffset >= 0,
          source.byteCount > 0, source.byteCount <= source.buffer.length,
          source.byteOffset <= source.buffer.length - source.byteCount,
          source.byteCount <= maximumPayloadBytes - payloadBytes else {
          throw TissueError.transaction("native capture source device, range or byte budget")
        }
        payloadBytes += source.byteCount
        let alignment = (16 - stagingBytes % 16) % 16
        let aligned = stagingBytes.addingReportingOverflow(alignment)
        let end = aligned.partialValue.addingReportingOverflow(source.byteCount)
        guard !aligned.overflow, !end.overflow, end.partialValue <= maximumPayloadBytes + 256 else {
          throw TissueError.transaction("prepared staging offset overflow")
        }
        offsets.append(aligned.partialValue); stagingBytes = end.partialValue
      }
      guard let staging = device.makeBuffer(length: stagingBytes,
        options: [.storageModeShared, .hazardTrackingModeTracked]) else {
        throw TissueError.metal("prepared fast-root staging allocation failed")
      }
      staging.label = "NumiBrain retained native fast-root recovery bytes"
      let descriptor = MTLResidencySetDescriptor()
      descriptor.initialCapacity = sources.count + 1
      descriptor.label = "NumiBrain prepared fast-root capture residency"
      let residency = try device.makeResidencySet(descriptor: descriptor)
      var allocations = Set<ObjectIdentifier>()
      for source in sources where allocations.insert(ObjectIdentifier(source.buffer as AnyObject)).inserted {
        residency.addAllocation(source.buffer)
      }
      residency.addAllocation(staging); residency.commit(); residency.requestResidency()
      self.sources = sources; self.offsets = offsets; self.staging = staging; self.residency = residency
    }
    deinit { residency.endResidency() }
  }
}

import Foundation
@preconcurrency import Metal
import NumiBrainCore

/// Unforgeable in-process receipt for a sample whose exact retained Metal
/// ranges were copied and content-addressed by `MetalNumanXGateCCapture`.
/// Decoded manifests remain inspectable, but cannot authorize a terminal root
/// transcript without this capture receipt.
@available(macOS 26.0, *)
public final class MetalNumanXCapturedRootSample: @unchecked Sendable {
  public let artifact: BrainPolicyNumanXRootSampleArtifact
  public let sampleSHA256: String

  fileprivate init(
    artifact: BrainPolicyNumanXRootSampleArtifact,
    sampleSHA256: String
  ) {
    self.artifact = artifact
    self.sampleSHA256 = sampleSHA256
  }
}

@available(macOS 26.0, *)
public final class MetalNumanXCapturedLearningBatch: @unchecked Sendable {
  public let batch: MetalLearningBatch
  public let artifact: BrainPolicyNumanXLearningBatchArtifact
  public let artifactSHA256: String

  fileprivate init(
    batch: MetalLearningBatch,
    artifact: BrainPolicyNumanXLearningBatchArtifact,
    artifactSHA256: String
  ) {
    self.batch = batch
    self.artifact = artifact
    self.artifactSHA256 = artifactSHA256
  }
}

/// Retains the exact settled sensor bytes consumed by one NumanX control root
/// and returns the content hash that must be passed to
/// `qualificationRootExecution`. This operation is evidence capture, not a
/// control-path synchronization primitive: the caller must provide a packet
/// whose producing command has already completed successfully. Shared ranges
/// are copied directly; private/managed ranges use one explicit qualification
/// blit and host completion wait. That readback never participates in control
/// authority or the root publication critical path.
@available(macOS 26.0, *)
public enum MetalNumanXGateCCapture {
  struct SettledSensorChannel {
    let modality: SensoryModality
    let receptorCount: UInt32
    let featureDimension: UInt32
    let values: Data
    let validity: Data?
  }

  static func settledSensorSnapshot(
    _ sensors: NumanXSensorPacketLease
  ) throws -> [SettledSensorChannel] {
    let captured = try settledBytes(sensors.rawSensors.flatMap { sensor in
      [sensor.buffer] + (sensor.validityBuffer.map { [$0] } ?? [])
    })
    return try sensors.rawSensors.map { sensor in
      SettledSensorChannel(
        modality: sensor.view.modality,
        receptorCount: sensor.view.receptorCount,
        featureDimension: sensor.view.featureDimension,
        values: try exactBytes(sensor.buffer, from: captured),
        validity: try sensor.validityBuffer.map {
          try exactBytes($0, from: captured)
        }
      )
    }
  }

  public static func writeLearningBatch(
    _ batch: MetalLearningBatch,
    artifactDirectory: URL
  ) throws -> MetalNumanXCapturedLearningBatch {
    let sections = try MetalLearningBatchSection.allCases.map { section in
      let lease = try batch.makeSharedStorageLease(for: section)
      let bytes = Data(bytes: lease.baseAddress, count: lease.byteCount)
      let hash = try BrainPolicyEvidenceArtifact.write(
        bytes,
        to: artifactDirectory
      )
      let shape = sectionShape(section, batch: batch)
      guard shape.count > 0, shape.stride > 0,
        shape.count <= Int.max / shape.stride,
        shape.count * shape.stride == lease.byteCount
      else {
        throw TissueError.transaction(
          "Gate C learning-batch section shape is inconsistent"
        )
      }
      return try BrainPolicyNumanXLearningBatchSectionArtifact(
        sectionIdentifier: section.rawValue,
        recordFormatVersion: shape.version,
        elementCount: UInt64(shape.count),
        elementStride: UInt64(shape.stride),
        byteCount: UInt64(lease.byteCount),
        contentSHA256: hash
      )
    }
    let artifact = try BrainPolicyNumanXLearningBatchArtifact(
      learningBatchFormatVersion: batch.formatVersion,
      sourceGeneration: batch.sourceGeneration,
      speciesTemplateFingerprint: batch.speciesTemplateFingerprint,
      regionalProgramFingerprint: batch.regionalProgramFingerprint,
      scheduleFingerprint: batch.scheduleFingerprint,
      parameterVersionFingerprint: batch.parameterVersionFingerprint,
      regionalModuleCount: UInt64(batch.regionalModuleCount),
      metadataFingerprint: batch.metadataFingerprint,
      contentFingerprint: batch.contentFingerprint,
      batchFingerprint: batch.batchFingerprint,
      sections: sections
    )
    return try MetalNumanXCapturedLearningBatch(
      batch: batch,
      artifact: artifact,
      artifactSHA256: artifact.write(to: artifactDirectory)
    )
  }

  public static func writeSettledRootSample(
    transaction: BrainJointTransactionToken,
    sensors: NumanXSensorPacketLease,
    coordinates: BrainPolicyNumanXDatasetCoordinates,
    artifactDirectory: URL
  ) throws -> MetalNumanXCapturedRootSample {
    let packet = sensors.packet
    guard packet.transactionFingerprint == transaction.fingerprint,
      packet.environmentIdentifier == transaction.environmentIdentifier,
      packet.deliveryTimestamp == transaction.committedTimestamp,
      packet.rawSensorViews.count == sensors.rawSensors.count
    else {
      throw TissueError.transaction(
        "Gate C capture packet does not belong to the exact control root"
      )
    }
    let settledBytes = try settledBytes(
      sensors.rawSensors.flatMap { sensor in
        [sensor.buffer] + (sensor.validityBuffer.map { [$0] } ?? [])
      }
    )
    let channels = try sensors.rawSensors.map { sensor in
      let view = sensor.view
      let (scalarCount, scalarOverflow) = Int(view.receptorCount)
        .multipliedReportingOverflow(by: Int(view.featureDimension))
      let (valuesByteCount, valueOverflow) = scalarCount
        .multipliedReportingOverflow(by: MemoryLayout<Float>.stride)
      let (validityByteCount, validityOverflow) = Int(view.receptorCount)
        .multipliedReportingOverflow(by: MemoryLayout<UInt32>.stride)
      guard !scalarOverflow, !valueOverflow, !validityOverflow,
        valuesByteCount > 0,
        sensor.buffer.gpuAddress == view.gpuAddress,
        sensor.buffer.length == valuesByteCount,
        (sensor.validityBuffer == nil && !view.hasValidity)
          || (sensor.validityBuffer != nil && view.hasValidity
            && sensor.validityBuffer!.gpuAddress == view.validityGPUAddress
            && sensor.validityBuffer!.length == validityByteCount)
      else {
        throw TissueError.transaction(
          "Gate C capture requires exact settled shared sensor ranges; "
            + "modality=\(view.modality) values=\(sensor.buffer.length)/"
            + "\(valuesByteCount) storage=\(sensor.buffer.storageMode.rawValue) "
            + "validity=\(sensor.validityBuffer?.length ?? 0)/"
            + "\(view.hasValidity ? validityByteCount : 0)"
        )
      }
      let values = try exactBytes(sensor.buffer, from: settledBytes)
      let valuesSHA256 = try BrainPolicyEvidenceArtifact.write(
        values,
        to: artifactDirectory
      )
      let validitySHA256: String?
      if let validity = sensor.validityBuffer {
        validitySHA256 = try BrainPolicyEvidenceArtifact.write(
          exactBytes(validity, from: settledBytes),
          to: artifactDirectory
        )
      } else {
        validitySHA256 = nil
      }
      return try BrainPolicyNumanXSensorChannelArtifact(
        modality: view.modality,
        receptorTimestampMicroseconds: view.receptorTimestamp.rawValue,
        receptorCount: view.receptorCount,
        featureDimension: view.featureDimension,
        valuesByteCount: UInt64(valuesByteCount),
        valuesSHA256: valuesSHA256,
        validityByteCount: validitySHA256 == nil ? 0 : UInt64(validityByteCount),
        validitySHA256: validitySHA256
      )
    }
    let controlStep = UInt32(exactly: transaction.controlStepIdentifier)
    guard let controlStep else {
      throw TissueError.transaction(
        "Gate C capture control step exceeds the authoritative UInt32 ABI"
      )
    }
    let artifact = try BrainPolicyNumanXRootSampleArtifact(
      coordinates: coordinates,
      transactionFingerprint: transaction.fingerprint,
      controlStep: controlStep,
      committedTimestampMicroseconds: transaction.committedTimestamp.rawValue,
      targetTimestampMicroseconds: transaction.targetTimestamp.rawValue,
      basePhysicsGeneration: transaction.basePhysicsGeneration,
      acceptedPhysicsTokenFingerprint: packet.acceptedPhysicsTokenFingerprint,
      physicsGeneration: packet.physicsGeneration,
      speciesTemplateFingerprint: packet.speciesTemplateFingerprint,
      sensoryProfileFingerprint: packet.sensoryProfileFingerprint,
      sensorPacketFingerprint: packet.fingerprint,
      channels: channels
    )
    return try MetalNumanXCapturedRootSample(
      artifact: artifact,
      sampleSHA256: artifact.write(to: artifactDirectory)
    )
  }

  private static func exactBytes(
    _ buffer: any MTLBuffer,
    from captured: [ObjectIdentifier: Data]
  ) throws -> Data {
    let identifier = ObjectIdentifier(buffer as AnyObject)
    guard let data = captured[identifier], data.count == buffer.length else {
      throw TissueError.transaction(
        "Gate C capture lost an exact settled Metal range"
      )
    }
    return data
  }

  private static func settledBytes(
    _ buffers: [any MTLBuffer]
  ) throws -> [ObjectIdentifier: Data] {
    guard let first = buffers.first else {
      throw TissueError.transaction("Gate C capture has no sensor ranges")
    }
    let device = first.device
    var unique: [ObjectIdentifier: any MTLBuffer] = [:]
    for buffer in buffers {
      let identifier = ObjectIdentifier(buffer as AnyObject)
      guard buffer.device.registryID == device.registryID, buffer.length > 0,
        unique[identifier] == nil
      else {
        throw TissueError.transaction(
          "Gate C capture ranges are duplicated or cross-device"
        )
      }
      unique[identifier] = buffer
    }
    var staging: [ObjectIdentifier: any MTLBuffer] = [:]
    let requiresBlit = unique.values.contains { $0.storageMode != .shared }
    if requiresBlit {
      guard let queue = device.makeCommandQueue(),
        let commandBuffer = queue.makeCommandBuffer(),
        let blit = commandBuffer.makeBlitCommandEncoder()
      else {
        throw TissueError.metal(
          "failed to allocate Gate C qualification readback"
        )
      }
      for (identifier, buffer) in unique where buffer.storageMode != .shared {
        guard let destination = device.makeBuffer(
          length: buffer.length,
          options: [.storageModeShared, .hazardTrackingModeTracked]
        ) else {
          throw TissueError.metal(
            "failed to allocate Gate C qualification staging"
          )
        }
        blit.copy(
          from: buffer,
          sourceOffset: 0,
          to: destination,
          destinationOffset: 0,
          size: buffer.length
        )
        staging[identifier] = destination
      }
      blit.endEncoding()
      commandBuffer.commit()
      commandBuffer.waitUntilCompleted()
      guard commandBuffer.status == .completed else {
        throw TissueError.metal(
          "Gate C qualification readback command failed"
        )
      }
    }
    var result: [ObjectIdentifier: Data] = [:]
    result.reserveCapacity(unique.count)
    for (identifier, buffer) in unique {
      let source = staging[identifier] ?? buffer
      result[identifier] = Data(
        bytes: source.contents(),
        count: source.length
      )
    }
    return result
  }

  private static func sectionShape(
    _ section: MetalLearningBatchSection,
    batch: MetalLearningBatch
  ) -> (version: UInt32, count: Int, stride: Int) {
    switch section {
    case .committedTransitions:
      (batch.transitionRecordVersion, batch.transitionCapacity,
        batch.transitionStride)
    case .activeEpisodes:
      (batch.episodicRecordVersion, batch.episodicCapacity,
        batch.episodicStride)
    case .warmEpisodes:
      (batch.episodicRecordVersion, batch.warmEpisodicCapacity,
        batch.warmEpisodicStride)
    case .proceduralSkills:
      (batch.proceduralRecordVersion, batch.proceduralCapacity,
        batch.proceduralStride)
    case .replayQueue:
      (batch.replayRecordVersion, batch.replayCapacity, batch.replayStride)
    case .imaginedCounterfactuals:
      (batch.counterfactualRecordVersion, batch.counterfactualCapacity,
        batch.counterfactualStride)
    case .semanticConcepts:
      (batch.semanticRecordVersion, batch.semanticConceptCapacity,
        batch.semanticConceptStride)
    case .semanticRelations:
      (batch.semanticRecordVersion, batch.semanticRelationCapacity,
        batch.semanticRelationStride)
    case .regionalTransitions:
      (batch.regionalTransitionRecordVersion,
        batch.regionalTransitionCapacity, batch.regionalTransitionStride)
    }
  }
}

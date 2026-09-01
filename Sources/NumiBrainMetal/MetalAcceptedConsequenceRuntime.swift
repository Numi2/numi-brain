import Foundation
@preconcurrency import Metal
import NumiBrainCore

@inline(never)
private func copyAcceptedConsequenceArray<Element>(
  _ values: [Element],
  to buffer: any MTLBuffer,
  byteOffset: Int
) -> Bool {
  let byteCount = values.count.multipliedReportingOverflow(
    by: MemoryLayout<Element>.stride
  )
  guard !byteCount.overflow,
    byteOffset >= 0,
    byteOffset <= buffer.length,
    byteCount.partialValue <= buffer.length - byteOffset
  else { return false }
  guard byteCount.partialValue > 0 else { return true }
  values.withUnsafeBytes { bytes in
    guard let source = bytes.baseAddress else { return }
    buffer.contents().advanced(by: byteOffset).copyMemory(
      from: source,
      byteCount: byteCount.partialValue
    )
  }
  return true
}

private struct AcceptedConsequenceUniforms {
  var targetTimestampMicroseconds: UInt64 = 0
  var deltaMicroseconds: UInt64 = 0
  var observationOffset: UInt64 = 0
  var observationValidityOffset: UInt64 = 0
  var eventQueueOffset: UInt64 = 0
  var bodyBeliefOffset: UInt64 = 0
  var jointBeliefOffset: UInt64 = 0
  var muscleBeliefOffset: UInt64 = 0
  var physiologyOffset: UInt64 = 0
  var objectSlotOffset: UInt64 = 0
  var worldModelOffset: UInt64 = 0
  var neuromodulationOffset: UInt64 = 0
  var driveOffset: UInt64 = 0
  var fastPlasticityOffset: UInt64 = 0
  var workspaceContentOffset: UInt64 = 0
  var workspaceMetadataOffset: UInt64 = 0
  var controlHeaderOffset: UInt64 = 0
  var optionCandidateOffset: UInt64 = 0
  var proceduralTraceOffset: UInt64 = 0
  var motorCommandOffset: UInt64 = 0
  var cerebellarOffset: UInt64 = 0
  var cerebellarExpertMemoryOffset: UInt64 = 0
  var somaticOutputOffset: UInt64 = 0
  var activeSensingCommandOffset: UInt64 = 0
  var activeSensingEfficacyOffset: UInt64 = 0
  var acceptedSomaticOutputOffset: UInt64 = 0
  var acceptedActiveSensingOutputOffset: UInt64 = 0
  var reflexStateOffset: UInt64 = 0
  var fastAutonomicStateOffset: UInt64 = 0
  var physicsStateFingerprint: UInt64 = 0
  var regionalMaturationOffset: UInt64 = 0
  var observationCount: UInt32 = 0
  var bodyCount: UInt32 = 0
  var jointCount: UInt32 = 0
  var anatomicalMuscleCount: UInt32 = 0
  var muscleCount: UInt32 = 0
  var physiologyCount: UInt32 = 0
  var objectSlotCount: UInt32 = 0
  var worldModelCount: UInt32 = 0
  var neuromodulatorCount: UInt32 = 0
  var driveCount: UInt32 = 0
  var maximumPlanningHorizon: UInt32 = 0
  var fastPlasticityCount: UInt32 = 0
  var workspaceCapacity: UInt32 = 0
  var workspaceDimension: UInt32 = 0
  var activeCerebellarCount: UInt32 = 0
  var actuatorCount: UInt32 = 0
  var activeSensingCount: UInt32 = 0
  var reflexStateCount: UInt32 = 0
  var fastAutonomicStateCount: UInt32 = 0
  var eventCapacity: UInt32 = 0
  var optionCandidateCapacity: UInt32 = 0
  var proceduralTraceRecordCapacity: UInt32 = 0
  var proceduralTracePhaseCapacity: UInt32 = 0
  var cerebellarExpertCapacity: UInt32 = 0
  var visionOffset: UInt32 = 0
  var visionCount: UInt32 = 0
  var auditionOffset: UInt32 = 0
  var auditionCount: UInt32 = 0
  var proprioceptionOffset: UInt32 = 0
  var proprioceptionCount: UInt32 = 0
  var touchOffset: UInt32 = 0
  var touchCount: UInt32 = 0
  var vestibularOffset: UInt32 = 0
  var vestibularCount: UInt32 = 0
  var olfactionOffset: UInt32 = 0
  var olfactionCount: UInt32 = 0
  var gustationOffset: UInt32 = 0
  var gustationCount: UInt32 = 0
  var interoceptionOffset: UInt32 = 0
  var interoceptionCount: UInt32 = 0
  var moduleCount: UInt32 = 0
  var plasticityParameterCount: UInt32 = 0
  var beliefGain: Float = 0
  var worldCorrectionGain: Float = 0
  var cerebellarLearningRate: Float = 0
  var plasticityLearningRate: Float = 0
}

private struct AcceptedActuatorDescriptor {
  var actuatorIdentifier: UInt32 = 0
  var commandKind: UInt32 = 0
  var flags: UInt32 = 0
  var reserved: UInt32 = 0
  var outputMinimum: Float = 0
  var outputMaximum: Float = 1
  var neutralCommand: Float = 0
  var emergencyCommand: Float = 0
}

private struct AcceptedBodyReceptorBindingTableHeader {
  var bindingCount: UInt32 = 0
  var bodyCount: UInt32 = 0
  var profileFingerprint: UInt64 = 0
}

private struct AcceptedBodyReceptorBindingRange {
  var bindingOffset: UInt32 = 0
  var bindingCount: UInt32 = 0
}

private struct AcceptedBodyReceptorBindingRecord {
  var bodyIdentifier: UInt32 = 0
  var signal: UInt32 = 0
  var observationScalarIndex: UInt32 = 0
  var flags: UInt32 = 0
  var scale: Float = 0
  var bias: Float = 0
  var weight: Float = 0
  var reserved: Float = 0
}

private struct AcceptedJointReceptorBindingTableHeader {
  var bindingCount: UInt32 = 0
  var jointCount: UInt32 = 0
  var profileFingerprint: UInt64 = 0
  var topologyFingerprint: UInt64 = 0
}

private struct AcceptedJointTopologyRecord {
  var identifiers = SIMD4<UInt32>(repeating: 0)
  var axis0 = SIMD4<Float>(repeating: 0)
  var axis1 = SIMD4<Float>(repeating: 0)
  var axis2 = SIMD4<Float>(repeating: 0)
  var axis3 = SIMD4<Float>(repeating: 0)
  var axis4 = SIMD4<Float>(repeating: 0)
  var axis5 = SIMD4<Float>(repeating: 0)
  var limits0 = SIMD4<Float>(repeating: 0)
  var limits1 = SIMD4<Float>(repeating: 0)
  var limits2 = SIMD4<Float>(repeating: 0)
  var limits3 = SIMD4<Float>(repeating: 0)
  var limits4 = SIMD4<Float>(repeating: 0)
  var limits5 = SIMD4<Float>(repeating: 0)
  var parentLocalAnchor = SIMD4<Float>(repeating: 0)
  var childLocalAnchor = SIMD4<Float>(repeating: 0)
  var restRelativeOrientation = SIMD4<Float>(0, 0, 0, 1)
}

private struct AcceptedJointReceptorBindingRecord {
  var jointIndex: UInt32 = 0
  var coordinateSlot: UInt32 = 0
  var signal: UInt32 = 0
  var observationScalarIndex: UInt32 = 0
  var scale: Float = 0
  var bias: Float = 0
  var weight: Float = 0
  var flags: UInt32 = 0
}

private struct AcceptedMuscleReceptorBindingTableHeader {
  var bindingCount: UInt32 = 0
  var muscleCount: UInt32 = 0
  var profileFingerprint: UInt64 = 0
  var attachmentFingerprint: UInt64 = 0
}

private struct AcceptedMuscleTopologyRecord {
  var identifiers = SIMD4<UInt32>(repeating: 0)
}

private struct AcceptedMuscleReceptorBindingRecord {
  var muscleIndex: UInt32 = 0
  var signal: UInt32 = 0
  var observationScalarIndex: UInt32 = 0
  var flags: UInt32 = 0
  var scale: Float = 0
  var bias: Float = 0
  var weight: Float = 0
  var reserved: Float = 0
}

private struct ObservationRange: Sendable {
  let offset: UInt32
  let count: UInt32
}

private struct AcceptedBodyReceptorTables {
  let bindings: [AcceptedBodyReceptorBindingRecord]
  let ranges: [AcceptedBodyReceptorBindingRange]
}

private struct AcceptedJointReceptorTables {
  let bindings: [AcceptedJointReceptorBindingRecord]
  let ranges: [AcceptedBodyReceptorBindingRange]
  let topologyRecords: [AcceptedJointTopologyRecord]
}

private struct AcceptedMuscleReceptorTables {
  let bindings: [AcceptedMuscleReceptorBindingRecord]
  let ranges: [AcceptedBodyReceptorBindingRange]
  let topologyRecords: [AcceptedMuscleTopologyRecord]
}

private struct AcceptedConsequenceImmutableBuffers {
  let actuatorDescriptors: any MTLBuffer
  let bodyReceptorBindings: any MTLBuffer
  let jointReceptorBindings: any MTLBuffer
  let muscleReceptorBindings: any MTLBuffer
  let neutralProtectiveCommand: any MTLBuffer
}

private struct AcceptedConsequenceProgramResources {
  let pipelines: [any MTLComputePipelineState]
  let argumentTable: any MTL4ArgumentTable
  let uniformBuffer: any MTLBuffer
  let unconditionalAcceptanceGate: any MTLBuffer
  let plasticityParameterCount: UInt32
}

@inline(never)
private func makeAcceptedConsequenceImmutableBuffer(
  device: any MTLDevice,
  length: Int,
  label: String
) throws -> any MTLBuffer {
  guard length > 0,
    let buffer = device.makeBuffer(
      length: length,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    )
  else {
    throw TissueError.metal("failed to allocate accepted-consequence immutable buffer")
  }
  buffer.label = label
  return buffer
}

@inline(never)
private func makeAcceptedBodyReceptorTables(
  species: SpeciesTemplate,
  sensoryProfile: SensoryTransductionProfile,
  observationRanges: [SensoryModality: ObservationRange],
  observationCount: UInt32
) throws -> AcceptedBodyReceptorTables {
  let topologyByModality = Dictionary(
    uniqueKeysWithValues: species.senses.map { ($0.modality, $0) }
  )
  let canonicalBindings = sensoryProfile.bodyReceptorBindings.sorted {
    if $0.bodyIdentifier != $1.bodyIdentifier {
      return $0.bodyIdentifier < $1.bodyIdentifier
    }
    if $0.signal.rawValue != $1.signal.rawValue {
      return $0.signal.rawValue < $1.signal.rawValue
    }
    return $0.identifier < $1.identifier
  }
  let bindings = try canonicalBindings.map {
    binding -> AcceptedBodyReceptorBindingRecord in
    guard let range = observationRanges[binding.modality],
      let topology = topologyByModality[binding.modality]
    else {
      throw TissueError.metal("accepted body receptor topology is unavailable")
    }
    let scalarIndex =
      UInt64(range.offset)
      + UInt64(binding.receptorIndex)
      * UInt64(topology.observationDimension)
      + UInt64(binding.featureIndex)
    guard scalarIndex < UInt64(observationCount),
      scalarIndex <= UInt64(UInt32.max)
    else {
      throw TissueError.metal("accepted body receptor scalar exceeds its arena")
    }
    return AcceptedBodyReceptorBindingRecord(
      bodyIdentifier: binding.bodyIdentifier,
      signal: UInt32(binding.signal.rawValue),
      observationScalarIndex: UInt32(scalarIndex),
      flags: 1 | (UInt32(binding.component) << 16),
      scale: binding.scale,
      bias: binding.bias,
      weight: binding.weight,
      reserved: 0
    )
  }
  var ranges = [AcceptedBodyReceptorBindingRange](
    repeating: AcceptedBodyReceptorBindingRange(),
    count: Int(species.body.bodyCount)
  )
  var bindingCursor = 0
  for bodyIdentifier in 0..<Int(species.body.bodyCount) {
    let begin = bindingCursor
    while bindingCursor < canonicalBindings.count,
      canonicalBindings[bindingCursor].bodyIdentifier == UInt32(bodyIdentifier)
    {
      bindingCursor += 1
    }
    ranges[bodyIdentifier] = AcceptedBodyReceptorBindingRange(
      bindingOffset: UInt32(begin),
      bindingCount: UInt32(bindingCursor - begin)
    )
  }
  return AcceptedBodyReceptorTables(bindings: bindings, ranges: ranges)
}

@inline(never)
private func makeAcceptedJointReceptorTables(
  species: SpeciesTemplate,
  sensoryProfile: SensoryTransductionProfile,
  observationRanges: [SensoryModality: ObservationRange],
  observationCount: UInt32,
  jointTopologyCatalog: NumanXJointTopologyCatalog
) throws -> AcceptedJointReceptorTables {
  let topologyByModality = Dictionary(
    uniqueKeysWithValues: species.senses.map { ($0.modality, $0) }
  )
  let jointIndexByIdentifier = Dictionary(
    uniqueKeysWithValues: jointTopologyCatalog.joints.enumerated().map {
      ($0.element.jointIdentifier, $0.offset)
    }
  )
  let indexedBindings = try sensoryProfile.jointReceptorBindings.map {
    binding -> (binding: JointReceptorBinding, jointIndex: Int, coordinateSlot: Int) in
    guard let jointIndex = jointIndexByIdentifier[binding.jointIdentifier],
      let coordinateSlot = jointTopologyCatalog.joints[jointIndex].coordinates
        .firstIndex(where: { $0.identifier == binding.coordinateIdentifier })
    else {
      throw TissueError.metal("accepted joint receptor endpoint is unavailable")
    }
    return (binding, jointIndex, coordinateSlot)
  }.sorted {
    if $0.jointIndex != $1.jointIndex { return $0.jointIndex < $1.jointIndex }
    if $0.coordinateSlot != $1.coordinateSlot {
      return $0.coordinateSlot < $1.coordinateSlot
    }
    if $0.binding.signal.rawValue != $1.binding.signal.rawValue {
      return $0.binding.signal.rawValue < $1.binding.signal.rawValue
    }
    return $0.binding.identifier < $1.binding.identifier
  }
  let bindings = try indexedBindings.map {
    entry -> AcceptedJointReceptorBindingRecord in
    let binding = entry.binding
    guard let range = observationRanges[binding.modality],
      let topology = topologyByModality[binding.modality]
    else {
      throw TissueError.metal("accepted joint receptor modality is unavailable")
    }
    let scalarIndex =
      UInt64(range.offset)
      + UInt64(binding.receptorIndex) * UInt64(topology.observationDimension)
      + UInt64(binding.featureIndex)
    guard scalarIndex < UInt64(observationCount),
      scalarIndex <= UInt64(UInt32.max)
    else {
      throw TissueError.metal("accepted joint receptor scalar exceeds its arena")
    }
    return AcceptedJointReceptorBindingRecord(
      jointIndex: UInt32(entry.jointIndex),
      coordinateSlot: UInt32(entry.coordinateSlot),
      signal: UInt32(binding.signal.rawValue),
      observationScalarIndex: UInt32(scalarIndex),
      scale: binding.scale,
      bias: binding.bias,
      weight: binding.weight,
      flags: 1
    )
  }
  var ranges = [AcceptedBodyReceptorBindingRange](
    repeating: AcceptedBodyReceptorBindingRange(),
    count: jointTopologyCatalog.joints.count
  )
  var bindingCursor = 0
  for jointIndex in jointTopologyCatalog.joints.indices {
    let begin = bindingCursor
    while bindingCursor < indexedBindings.count,
      indexedBindings[bindingCursor].jointIndex == jointIndex
    {
      bindingCursor += 1
    }
    ranges[jointIndex] = AcceptedBodyReceptorBindingRange(
      bindingOffset: UInt32(begin),
      bindingCount: UInt32(bindingCursor - begin)
    )
  }
  let topologyRecords = jointTopologyCatalog.joints.map { joint in
    let axes = joint.coordinates.map {
      SIMD4<Float>(
        $0.parentLocalAxis.x,
        $0.parentLocalAxis.y,
        $0.parentLocalAxis.z,
        Float($0.kind.rawValue)
      )
    } + Array(repeating: SIMD4<Float>(repeating: 0), count: 6 - joint.coordinates.count)
    let limits = joint.coordinates.map {
      SIMD4<Float>(
        $0.minimumPosition,
        $0.maximumPosition,
        $0.restPosition,
        0
      )
    } + Array(repeating: SIMD4<Float>(repeating: 0), count: 6 - joint.coordinates.count)
    return AcceptedJointTopologyRecord(
      identifiers: SIMD4<UInt32>(
        joint.jointIdentifier,
        joint.parentBodyIdentifier,
        joint.childBodyIdentifier,
        UInt32(joint.coordinates.count)
      ),
      axis0: axes[0], axis1: axes[1], axis2: axes[2],
      axis3: axes[3], axis4: axes[4], axis5: axes[5],
      limits0: limits[0], limits1: limits[1], limits2: limits[2],
      limits3: limits[3], limits4: limits[4], limits5: limits[5],
      parentLocalAnchor: SIMD4<Float>(
        joint.parentLocalAnchor.x,
        joint.parentLocalAnchor.y,
        joint.parentLocalAnchor.z,
        0
      ),
      childLocalAnchor: SIMD4<Float>(
        joint.childLocalAnchor.x,
        joint.childLocalAnchor.y,
        joint.childLocalAnchor.z,
        0
      ),
      restRelativeOrientation: SIMD4<Float>(
        joint.restRelativeOrientation.x,
        joint.restRelativeOrientation.y,
        joint.restRelativeOrientation.z,
        joint.restRelativeOrientation.w
      )
    )
  }
  return AcceptedJointReceptorTables(
    bindings: bindings,
    ranges: ranges,
    topologyRecords: topologyRecords
  )
}

@inline(never)
private func makeAcceptedMuscleReceptorTables(
  species: SpeciesTemplate,
  sensoryProfile: SensoryTransductionProfile,
  observationRanges: [SensoryModality: ObservationRange],
  observationCount: UInt32,
  muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog?
) throws -> AcceptedMuscleReceptorTables {
  let topologyByModality = Dictionary(
    uniqueKeysWithValues: species.senses.map { ($0.modality, $0) }
  )
  let attachments = muscleAttachmentCatalog?.attachments ?? []
  let topologyRecords = attachments.map { attachment in
    AcceptedMuscleTopologyRecord(
      identifiers: SIMD4<UInt32>(
        attachment.muscleIdentifier,
        attachment.firstBodyIdentifier,
        attachment.terminalBodyIdentifier,
        0
      )
    )
  }
  let muscleIndexByIdentifier = Dictionary(
    uniqueKeysWithValues: attachments.enumerated().map {
      ($0.element.muscleIdentifier, $0.offset)
    }
  )
  let indexedBindings = try sensoryProfile.muscleReceptorBindings.map {
    binding -> (binding: MuscleReceptorBinding, muscleIndex: Int) in
    guard let muscleIndex = muscleIndexByIdentifier[binding.muscleIdentifier]
    else {
      throw TissueError.metal("accepted muscle receptor endpoint is unavailable")
    }
    return (binding, muscleIndex)
  }.sorted {
    if $0.muscleIndex != $1.muscleIndex {
      return $0.muscleIndex < $1.muscleIndex
    }
    if $0.binding.signal.rawValue != $1.binding.signal.rawValue {
      return $0.binding.signal.rawValue < $1.binding.signal.rawValue
    }
    return $0.binding.identifier < $1.binding.identifier
  }
  let bindings = try indexedBindings.map {
    entry -> AcceptedMuscleReceptorBindingRecord in
    let binding = entry.binding
    guard let range = observationRanges[binding.modality],
      let topology = topologyByModality[binding.modality]
    else {
      throw TissueError.metal("accepted muscle receptor modality is unavailable")
    }
    let scalarIndex = UInt64(range.offset)
      + UInt64(binding.receptorIndex) * UInt64(topology.observationDimension)
      + UInt64(binding.featureIndex)
    guard scalarIndex < UInt64(observationCount),
      scalarIndex <= UInt64(UInt32.max)
    else {
      throw TissueError.metal("accepted muscle receptor scalar exceeds its arena")
    }
    return AcceptedMuscleReceptorBindingRecord(
      muscleIndex: UInt32(entry.muscleIndex),
      signal: UInt32(binding.signal.rawValue),
      observationScalarIndex: UInt32(scalarIndex),
      flags: 1,
      scale: binding.scale,
      bias: binding.bias,
      weight: binding.weight,
      reserved: 0
    )
  }
  var ranges = [AcceptedBodyReceptorBindingRange](
    repeating: AcceptedBodyReceptorBindingRange(),
    count: attachments.count
  )
  var bindingCursor = 0
  for muscleIndex in attachments.indices {
    let begin = bindingCursor
    while bindingCursor < indexedBindings.count,
      indexedBindings[bindingCursor].muscleIndex == muscleIndex
    {
      bindingCursor += 1
    }
    ranges[muscleIndex] = AcceptedBodyReceptorBindingRange(
      bindingOffset: UInt32(begin),
      bindingCount: UInt32(bindingCursor - begin)
    )
  }
  return AcceptedMuscleReceptorTables(
    bindings: bindings,
    ranges: ranges,
    topologyRecords: topologyRecords
  )
}

@inline(never)
private func makeAcceptedConsequenceImmutableBuffers(
  device: any MTLDevice,
  species: SpeciesTemplate,
  sensoryProfile: SensoryTransductionProfile,
  jointTopologyCatalog: NumanXJointTopologyCatalog,
  muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog?,
  bodyTables: AcceptedBodyReceptorTables,
  jointTables: AcceptedJointReceptorTables,
  muscleTables: AcceptedMuscleReceptorTables
) throws -> AcceptedConsequenceImmutableBuffers {
  let actuatorDescriptors = species.motor.actuatorChannels.map { channel in
    AcceptedActuatorDescriptor(
      actuatorIdentifier: channel.identifier,
      commandKind: UInt32(species.motor.actuatorCommandKind.rawValue),
      flags: 1,
      reserved: 0,
      outputMinimum: channel.outputMinimum,
      outputMaximum: channel.outputMaximum,
      neutralCommand: channel.neutralCommand,
      emergencyCommand: channel.emergencyCommand
    )
  }
  guard actuatorDescriptors.count == Int(species.motor.actuatorCount) else {
    throw TissueError.metal("accepted actuator descriptor count mismatch")
  }
  let actuatorDescriptorBuffer = try makeAcceptedConsequenceImmutableBuffer(
    device: device,
    length: actuatorDescriptors.count
      * MemoryLayout<AcceptedActuatorDescriptor>.stride,
    label: "NumiBrain immutable accepted actuator descriptors"
  )
  let bodyReceptorBindingBuffer = try makeAcceptedConsequenceImmutableBuffer(
    device: device,
    length: MemoryLayout<AcceptedBodyReceptorBindingTableHeader>.stride
      + bodyTables.ranges.count
      * MemoryLayout<AcceptedBodyReceptorBindingRange>.stride
      + max(bodyTables.bindings.count, 1)
      * MemoryLayout<AcceptedBodyReceptorBindingRecord>.stride,
    label: "NumiBrain immutable anatomical body receptor bindings"
  )
  let jointReceptorBindingBuffer = try makeAcceptedConsequenceImmutableBuffer(
    device: device,
    length: MemoryLayout<AcceptedJointReceptorBindingTableHeader>.stride
      + jointTables.topologyRecords.count
      * MemoryLayout<AcceptedJointTopologyRecord>.stride
      + jointTables.ranges.count
      * MemoryLayout<AcceptedBodyReceptorBindingRange>.stride
      + max(jointTables.bindings.count, 1)
      * MemoryLayout<AcceptedJointReceptorBindingRecord>.stride,
    label: "NumiBrain immutable anatomical joint receptor bindings"
  )
  let muscleReceptorBindingBuffer = try makeAcceptedConsequenceImmutableBuffer(
    device: device,
    length: MemoryLayout<AcceptedMuscleReceptorBindingTableHeader>.stride
      + muscleTables.topologyRecords.count
      * MemoryLayout<AcceptedMuscleTopologyRecord>.stride
      + muscleTables.ranges.count
      * MemoryLayout<AcceptedBodyReceptorBindingRange>.stride
      + max(muscleTables.bindings.count, 1)
      * MemoryLayout<AcceptedMuscleReceptorBindingRecord>.stride,
    label: "NumiBrain immutable anatomical muscle receptor bindings"
  )
  let neutralProtectiveCommandBuffer = try makeAcceptedConsequenceImmutableBuffer(
    device: device,
    length: ProtectiveMotorCommand.byteCount,
    label: "NumiBrain neutral accepted protective command"
  )
  neutralProtectiveCommandBuffer.contents().initializeMemory(
    as: UInt8.self,
    repeating: 0,
    count: ProtectiveMotorCommand.byteCount
  )
  guard copyAcceptedConsequenceArray(
      actuatorDescriptors,
      to: actuatorDescriptorBuffer,
      byteOffset: 0
    ) else {
    throw TissueError.metal("accepted actuator descriptor upload exceeds its buffer")
  }
  var bodyHeader = AcceptedBodyReceptorBindingTableHeader(
    bindingCount: UInt32(bodyTables.bindings.count),
    bodyCount: species.body.bodyCount,
    profileFingerprint: sensoryProfile.fingerprint
  )
  withUnsafeBytes(of: &bodyHeader) { bytes in
    guard let source = bytes.baseAddress else { return }
    bodyReceptorBindingBuffer.contents().copyMemory(
      from: source,
      byteCount: bytes.count
    )
  }
  let bodyRangeOffset = MemoryLayout<
    AcceptedBodyReceptorBindingTableHeader
  >.stride
  guard copyAcceptedConsequenceArray(
      bodyTables.ranges,
      to: bodyReceptorBindingBuffer,
      byteOffset: bodyRangeOffset
    ) else {
    throw TissueError.metal("accepted body receptor range upload exceeds its buffer")
  }
  guard copyAcceptedConsequenceArray(
      bodyTables.bindings,
      to: bodyReceptorBindingBuffer,
      byteOffset: bodyRangeOffset
        + bodyTables.ranges.count
        * MemoryLayout<AcceptedBodyReceptorBindingRange>.stride
    ) else {
    throw TissueError.metal("accepted body receptor upload exceeds its buffer")
  }
  var jointHeader = AcceptedJointReceptorBindingTableHeader(
    bindingCount: UInt32(jointTables.bindings.count),
    jointCount: UInt32(jointTables.topologyRecords.count),
    profileFingerprint: sensoryProfile.fingerprint,
    topologyFingerprint: jointTopologyCatalog.fingerprint
  )
  withUnsafeBytes(of: &jointHeader) { bytes in
    guard let source = bytes.baseAddress else { return }
    jointReceptorBindingBuffer.contents().copyMemory(
      from: source,
      byteCount: bytes.count
    )
  }
  let jointTopologyOffset = MemoryLayout<
    AcceptedJointReceptorBindingTableHeader
  >.stride
  guard copyAcceptedConsequenceArray(
      jointTables.topologyRecords,
      to: jointReceptorBindingBuffer,
      byteOffset: jointTopologyOffset
    ) else {
    throw TissueError.metal("accepted joint topology upload exceeds its buffer")
  }
  let jointRangeOffset = jointTopologyOffset
    + jointTables.topologyRecords.count
    * MemoryLayout<AcceptedJointTopologyRecord>.stride
  guard copyAcceptedConsequenceArray(
      jointTables.ranges,
      to: jointReceptorBindingBuffer,
      byteOffset: jointRangeOffset
    ) else {
    throw TissueError.metal("accepted joint receptor range upload exceeds its buffer")
  }
  guard copyAcceptedConsequenceArray(
      jointTables.bindings,
      to: jointReceptorBindingBuffer,
      byteOffset: jointRangeOffset
        + jointTables.ranges.count
        * MemoryLayout<AcceptedBodyReceptorBindingRange>.stride
    ) else {
    throw TissueError.metal("accepted joint receptor upload exceeds its buffer")
  }
  var muscleHeader = AcceptedMuscleReceptorBindingTableHeader(
    bindingCount: UInt32(muscleTables.bindings.count),
    muscleCount: UInt32(muscleTables.topologyRecords.count),
    profileFingerprint: sensoryProfile.fingerprint,
    attachmentFingerprint: muscleAttachmentCatalog?.fingerprint ?? 0
  )
  withUnsafeBytes(of: &muscleHeader) { bytes in
    guard let source = bytes.baseAddress else { return }
    muscleReceptorBindingBuffer.contents().copyMemory(
      from: source,
      byteCount: bytes.count
    )
  }
  let muscleTopologyOffset = MemoryLayout<
    AcceptedMuscleReceptorBindingTableHeader
  >.stride
  guard copyAcceptedConsequenceArray(
      muscleTables.topologyRecords,
      to: muscleReceptorBindingBuffer,
      byteOffset: muscleTopologyOffset
    ) else {
    throw TissueError.metal("accepted muscle topology upload exceeds its buffer")
  }
  let muscleRangeOffset = muscleTopologyOffset
    + muscleTables.topologyRecords.count
    * MemoryLayout<AcceptedMuscleTopologyRecord>.stride
  guard copyAcceptedConsequenceArray(
      muscleTables.ranges,
      to: muscleReceptorBindingBuffer,
      byteOffset: muscleRangeOffset
    ) else {
    throw TissueError.metal("accepted muscle receptor range upload exceeds its buffer")
  }
  guard copyAcceptedConsequenceArray(
      muscleTables.bindings,
      to: muscleReceptorBindingBuffer,
      byteOffset: muscleRangeOffset
        + muscleTables.ranges.count
        * MemoryLayout<AcceptedBodyReceptorBindingRange>.stride
    ) else {
    throw TissueError.metal("accepted muscle receptor upload exceeds its buffer")
  }
  return AcceptedConsequenceImmutableBuffers(
    actuatorDescriptors: actuatorDescriptorBuffer,
    bodyReceptorBindings: bodyReceptorBindingBuffer,
    jointReceptorBindings: jointReceptorBindingBuffer,
    muscleReceptorBindings: muscleReceptorBindingBuffer,
    neutralProtectiveCommand: neutralProtectiveCommandBuffer
  )
}

@inline(never)
private func makeAcceptedConsequenceProgramResources(
  device: any MTLDevice,
  species: SpeciesTemplate,
  sharedParameters: MetalSharedParameterBank,
  immutableBuffers: AcceptedConsequenceImmutableBuffers
) throws -> AcceptedConsequenceProgramResources {
  let sourceURL =
    Bundle.module.url(
      forResource: "AcceptedConsequence",
      withExtension: "metal",
      subdirectory: "Shaders"
    ) ?? Bundle.module.url(
      forResource: "AcceptedConsequence",
      withExtension: "metal"
    )
  guard let sourceURL else {
    throw TissueError.metal("AcceptedConsequence.metal is missing from resources")
  }
  let source = try String(contentsOf: sourceURL, encoding: .utf8)
  let options = MTLCompileOptions()
  options.languageVersion = .version4_0
  options.mathMode = .safe
  options.mathFloatingPointFunctions = .precise
  let library: any MTLLibrary
  do {
    library = try device.makeLibrary(source: source, options: options)
  } catch {
    throw TissueError.metal("accepted-consequence Metal compilation failed: \(error)")
  }
  let names = [
    "assimilate_accepted_body_and_physiology",
    "reconcile_accepted_world_model",
    "update_active_sensing_efficacy",
    "broadcast_accepted_prediction_error",
    "adapt_cerebellar_experts_from_accepted_error",
    "update_fast_plasticity_from_accepted_error",
    "update_accepted_procedural_trace",
    "assimilate_accepted_fast_body_schema",
    "update_accepted_embodied_self_model",
    "reconcile_accepted_sensorimotor_world_model",
    "assimilate_accepted_joint_schema",
    "assimilate_accepted_muscle_schema",
    "reconcile_accepted_articulated_body_graph",
    "learn_accepted_muscle_task_effect",
  ]
  let functions = try names.map { name -> any MTLFunction in
    guard let function = library.makeFunction(name: name) else {
      throw TissueError.metal("\(name) is missing from accepted-consequence Metal")
    }
    return function
  }
  let pipelines: [any MTLComputePipelineState]
  do {
    pipelines = try functions.map {
      try device.makeComputePipelineState(function: $0)
    }
  } catch {
    throw TissueError.metal("accepted-consequence pipeline creation failed: \(error)")
  }
  let descriptor = MTL4ArgumentTableDescriptor()
  descriptor.label = "NumiBrain accepted-consequence arguments"
  descriptor.maxBufferBindCount = 14
  descriptor.initializeBindings = true
  guard let argumentTable = try? device.makeArgumentTable(descriptor: descriptor),
    let uniformBuffer = device.makeBuffer(
      length: MemoryLayout<AcceptedConsequenceUniforms>.stride,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ),
    let unconditionalAcceptanceGateBuffer = device.makeBuffer(
      length: 128,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    )
  else {
    throw TissueError.metal("failed to allocate accepted-consequence bindings")
  }
  uniformBuffer.label = "NumiBrain accepted-consequence uniforms"
  unconditionalAcceptanceGateBuffer.contents().storeBytes(
    of: UInt32(1),
    as: UInt32.self
  )
  argumentTable.setAddress(
    try sharedParameters.gpuAddress(.belief, minimumScalarCount: 15),
    index: 2
  )
  argumentTable.setAddress(
    try sharedParameters.gpuAddress(.world, minimumScalarCount: 158),
    index: 3
  )
  argumentTable.setAddress(
    try sharedParameters.gpuAddress(.cerebellar, minimumScalarCount: 8),
    index: 4
  )
  let regionCount = species.enabledModuleIdentifiers.count
  let basisCapacity =
    (Int(species.capacities.fastPlasticityCapacity) + regionCount - 1)
    / regionCount
  let minimumPlasticityScalarCount = try BrainSharedParameterArtifact
    .plasticityElementCount(
      regionCount: regionCount,
      basisCapacityPerRegion: basisCapacity
    )
  let plasticityScalarCount = sharedParameters.scalarCount(.plasticity)
  guard plasticityScalarCount >= minimumPlasticityScalarCount,
    plasticityScalarCount <= Int(UInt32.max)
  else {
    throw TissueError.metal(
      "accepted plasticity receptor matrix does not cover the species graph"
    )
  }
  argumentTable.setAddress(
    try sharedParameters.gpuAddress(
      .plasticity,
      minimumScalarCount: minimumPlasticityScalarCount
    ),
    index: 5
  )
  argumentTable.setAddress(
    immutableBuffers.actuatorDescriptors.gpuAddress,
    index: 6
  )
  argumentTable.setAddress(
    immutableBuffers.neutralProtectiveCommand.gpuAddress,
    index: 8
  )
  argumentTable.setAddress(
    immutableBuffers.bodyReceptorBindings.gpuAddress,
    index: 9
  )
  argumentTable.setAddress(
    immutableBuffers.jointReceptorBindings.gpuAddress,
    index: 10
  )
  argumentTable.setAddress(
    immutableBuffers.muscleReceptorBindings.gpuAddress,
    index: 11
  )
  return AcceptedConsequenceProgramResources(
    pipelines: pipelines,
    argumentTable: argumentTable,
    uniformBuffer: uniformBuffer,
    unconditionalAcceptanceGate: unconditionalAcceptanceGateBuffer,
    plasticityParameterCount: UInt32(plasticityScalarCount)
  )
}

/// Applies receptor evidence from the accepted end of a root transaction to
/// the already-computed shadow mind. It owns correction only; the predictive
/// decision remains cached and is never resampled during physical retries.
@available(macOS 26.0, *)
public final class MetalAcceptedConsequenceRuntime: @unchecked Sendable {
  private let arena: MetalAgentStateArena
  private let species: SpeciesTemplate
  private let dynamics: AcceptedConsequenceDynamics
  private let controlLayout: MetalActiveControlLayout
  private let observationRanges: [SensoryModality: ObservationRange]
  private let pipelines: [any MTLComputePipelineState]
  private let argumentTable: any MTL4ArgumentTable
  private let uniformBuffer: any MTLBuffer
  private let actuatorDescriptorBuffer: any MTLBuffer
  private let bodyReceptorBindingBuffer: any MTLBuffer
  private let jointReceptorBindingBuffer: any MTLBuffer
  private let muscleReceptorBindingBuffer: any MTLBuffer
  private let neutralProtectiveCommandBuffer: any MTLBuffer
  private let unconditionalAcceptanceGateBuffer: any MTLBuffer
  private let plasticityParameterCount: UInt32
  private let sensorimotorWorldDimension: Int

  public init(
    device: any MTLDevice,
    arena: MetalAgentStateArena,
    species: SpeciesTemplate,
    dynamics: AcceptedConsequenceDynamics,
    sensoryProfile: SensoryTransductionProfile,
    jointTopologyCatalog: NumanXJointTopologyCatalog,
    muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog?,
    sharedParameters: MetalSharedParameterBank
  ) throws {
    let sensorimotorWorldDimension = Int(
      try WorldModelLevelDescriptor.referenceV1(level: .sensorimotor)
        .latentDimension
    )
    guard MemoryLayout<AcceptedConsequenceUniforms>.stride == 432,
      MemoryLayout<AcceptedActuatorDescriptor>.stride == 32,
      MemoryLayout<AcceptedBodyReceptorBindingTableHeader>.stride == 16,
      MemoryLayout<AcceptedBodyReceptorBindingRange>.stride == 8,
      MemoryLayout<AcceptedBodyReceptorBindingRecord>.stride == 32,
      MemoryLayout<AcceptedJointReceptorBindingTableHeader>.stride == 24,
      MemoryLayout<AcceptedJointTopologyRecord>.stride == 256,
      MemoryLayout<AcceptedJointReceptorBindingRecord>.stride == 32,
      MemoryLayout<AcceptedMuscleReceptorBindingTableHeader>.stride == 24,
      MemoryLayout<AcceptedMuscleTopologyRecord>.stride == 16,
      MemoryLayout<AcceptedMuscleReceptorBindingRecord>.stride == 32,
      sensorimotorWorldDimension == 256,
      arena.layout.speciesTemplateFingerprint == species.fingerprint,
      sensoryProfile.speciesTemplateFingerprint == species.fingerprint
    else {
      throw TissueError.metal("accepted-consequence ABI or species binding drift")
    }
    try jointTopologyCatalog.validate(species: species)
    guard
      (species.body.muscleCount == 0 && muscleAttachmentCatalog == nil
        && sensoryProfile.muscleReceptorBindings.isEmpty)
        || (species.body.muscleCount > 0
          && species.body.bodyCount == muscleAttachmentCatalog?.bodyCount
          && species.body.muscleCount
            == UInt32(muscleAttachmentCatalog?.attachments.count ?? 0)
          && species.body.muscleAttachmentFingerprint
            == muscleAttachmentCatalog?.fingerprint)
    else {
      throw TissueError.metal("accepted muscle receptor anatomy is inconsistent")
    }
    var offset: UInt32 = 0
    var ranges: [SensoryModality: ObservationRange] = [:]
    for topology in species.senses.sorted(by: { $0.modality.rawValue < $1.modality.rawValue })
    where topology.enabled {
      let count64 =
        UInt64(topology.receptorCount)
        * UInt64(topology.observationDimension)
      guard count64 <= UInt64(UInt32.max),
        UInt64(offset) + count64 <= UInt64(UInt32.max)
      else {
        throw TissueError.metal("accepted sensory range exceeds UInt32")
      }
      let count = UInt32(count64)
      ranges[topology.modality] = ObservationRange(offset: offset, count: count)
      offset += count
    }
    guard Int(offset) == arena.layout.section(.sensoryObservations).elementCount else {
      throw TissueError.metal("accepted sensory ranges do not cover the arena")
    }
    guard sensoryProfile.bodyReceptorBindings.count <= Int(UInt32.max) else {
      throw TissueError.metal("accepted body receptor bindings exceed UInt32")
    }
    let bodyTables = try makeAcceptedBodyReceptorTables(
      species: species,
      sensoryProfile: sensoryProfile,
      observationRanges: ranges,
      observationCount: offset
    )
    let jointTables = try makeAcceptedJointReceptorTables(
      species: species,
      sensoryProfile: sensoryProfile,
      observationRanges: ranges,
      observationCount: offset,
      jointTopologyCatalog: jointTopologyCatalog
    )
    let muscleTables = try makeAcceptedMuscleReceptorTables(
      species: species,
      sensoryProfile: sensoryProfile,
      observationRanges: ranges,
      observationCount: offset,
      muscleAttachmentCatalog: muscleAttachmentCatalog
    )
    let immutableBuffers = try makeAcceptedConsequenceImmutableBuffers(
      device: device,
      species: species,
      sensoryProfile: sensoryProfile,
      jointTopologyCatalog: jointTopologyCatalog,
      muscleAttachmentCatalog: muscleAttachmentCatalog,
      bodyTables: bodyTables,
      jointTables: jointTables,
      muscleTables: muscleTables
    )
    let actuatorDescriptorBuffer = immutableBuffers.actuatorDescriptors
    let bodyReceptorBindingBuffer = immutableBuffers.bodyReceptorBindings
    let jointReceptorBindingBuffer = immutableBuffers.jointReceptorBindings
    let muscleReceptorBindingBuffer = immutableBuffers.muscleReceptorBindings
    let neutralProtectiveCommandBuffer = immutableBuffers.neutralProtectiveCommand
    let programResources = try makeAcceptedConsequenceProgramResources(
      device: device,
      species: species,
      sharedParameters: sharedParameters,
      immutableBuffers: immutableBuffers
    )
    self.arena = arena
    self.species = species
    self.dynamics = dynamics
    self.controlLayout = try MetalActiveControlLayout(
      arenaLayout: arena.layout,
      species: species
    )
    self.observationRanges = ranges
    self.pipelines = programResources.pipelines
    self.argumentTable = programResources.argumentTable
    self.uniformBuffer = programResources.uniformBuffer
    self.actuatorDescriptorBuffer = actuatorDescriptorBuffer
    self.bodyReceptorBindingBuffer = bodyReceptorBindingBuffer
    self.jointReceptorBindingBuffer = jointReceptorBindingBuffer
    self.muscleReceptorBindingBuffer = muscleReceptorBindingBuffer
    self.neutralProtectiveCommandBuffer = neutralProtectiveCommandBuffer
    self.unconditionalAcceptanceGateBuffer =
      programResources.unconditionalAcceptanceGate
    self.plasticityParameterCount = programResources.plasticityParameterCount
    self.sensorimotorWorldDimension = sensorimotorWorldDimension
  }

  public var residencyAllocations: [any MTLAllocation] {
    [
      uniformBuffer, actuatorDescriptorBuffer, bodyReceptorBindingBuffer,
      jointReceptorBindingBuffer, muscleReceptorBindingBuffer,
      neutralProtectiveCommandBuffer, unconditionalAcceptanceGateBuffer,
    ]
  }

  public func encode(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    deltaMicroseconds: UInt64,
    receptorEventCapacity: Int,
    acceptanceGateGPUAddress: UInt64? = nil
  ) throws {
    try encode(
      encoder: encoder,
      transaction: transaction,
      acceptedTimestamp: acceptedPhysicsState.acceptedTimestamp,
      acceptedTransactionFingerprint: acceptedPhysicsState.transactionFingerprint,
      physicsStateFingerprint: acceptedPhysicsState.physicsStateFingerprint,
      deltaMicroseconds: deltaMicroseconds,
      receptorEventCapacity: receptorEventCapacity,
      acceptedFastMotorState: nil,
      acceptanceGateGPUAddress: acceptanceGateGPUAddress,
      acceptanceGateResultGPUAddress: nil
    )
  }

  func encode(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    deltaMicroseconds: UInt64,
    receptorEventCapacity: Int,
    acceptedFastMotorState: MetalTissueRuntime.AcceptedFastMotorStateLease? = nil,
    acceptanceGateGPUAddress: UInt64? = nil
  ) throws {
    try encode(
      encoder: encoder,
      transaction: transaction,
      acceptedTimestamp: acceptedPhysicsState.acceptedTimestamp,
      acceptedTransactionFingerprint: acceptedPhysicsState.transactionFingerprint,
      physicsStateFingerprint: acceptedPhysicsState.physicsStateFingerprint,
      deltaMicroseconds: deltaMicroseconds,
      receptorEventCapacity: receptorEventCapacity,
      acceptedFastMotorState: acceptedFastMotorState,
      acceptanceGateGPUAddress: acceptanceGateGPUAddress,
      acceptanceGateResultGPUAddress: nil
    )
  }

  func encodeAuthoritativeGate(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    acceptedTimestamp: BrainTimestamp,
    acceptedTransactionFingerprint: UInt64,
    deltaMicroseconds: UInt64,
    receptorEventCapacity: Int,
    acceptedFastMotorState: MetalTissueRuntime.AcceptedFastMotorStateLease? = nil,
    acceptanceGateGPUAddress: UInt64,
    acceptanceGateResultGPUAddress: UInt64
  ) throws {
    try encode(
      encoder: encoder,
      transaction: transaction,
      acceptedTimestamp: acceptedTimestamp,
      acceptedTransactionFingerprint: acceptedTransactionFingerprint,
      physicsStateFingerprint: 0,
      deltaMicroseconds: deltaMicroseconds,
      receptorEventCapacity: receptorEventCapacity,
      acceptedFastMotorState: acceptedFastMotorState,
      acceptanceGateGPUAddress: acceptanceGateGPUAddress,
      acceptanceGateResultGPUAddress: acceptanceGateResultGPUAddress
    )
  }

  private func encode(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    acceptedTimestamp: BrainTimestamp,
    acceptedTransactionFingerprint: UInt64,
    physicsStateFingerprint: UInt64,
    deltaMicroseconds: UInt64,
    receptorEventCapacity: Int,
    acceptedFastMotorState: MetalTissueRuntime.AcceptedFastMotorStateLease?,
    acceptanceGateGPUAddress: UInt64?,
    acceptanceGateResultGPUAddress: UInt64?
  ) throws {
    guard acceptedTimestamp.rawValue >= deltaMicroseconds,
      receptorEventCapacity >= 0,
      receptorEventCapacity <= Int(UInt32.max),
      acceptedFastMotorState == nil
        || (acceptedFastMotorState?.transactionFingerprint
          == acceptedTransactionFingerprint
          && acceptedFastMotorState?.acceptedTimestamp
            == acceptedTimestamp
          && acceptedFastMotorState?.protectiveCommandByteCount
            == ProtectiveMotorCommand.byteCount
          && (acceptedFastMotorState?.protectiveCommandBuffer.length ?? 0)
            >= ProtectiveMotorCommand.byteCount
          && (((acceptedFastMotorState?.bodySchemaCount ?? 0) == 0
            && (acceptedFastMotorState?.bodySchemaByteCount ?? 0) == 0)
            || (acceptedFastMotorState?.bodySchemaCount
              == Int(species.body.bodyCount)
              && acceptedFastMotorState?.bodySchemaByteCount
                == Int(species.body.bodyCount) * 48)))
    else {
      throw TissueError.transaction("accepted consequence timing or capacity is invalid")
    }
    let hot = try arena.hotStateView(transaction: transaction)
    var uniforms = try makeUniforms(
      acceptedTimestamp: acceptedTimestamp,
      physicsStateFingerprint: physicsStateFingerprint,
      deltaMicroseconds: deltaMicroseconds,
      eventCapacity: UInt32(receptorEventCapacity)
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      uniformBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    argumentTable.setAddress(hot.outputGPUAddress, index: 0)
    argumentTable.setAddress(uniformBuffer.gpuAddress, index: 1)
    argumentTable.setAddress(
      acceptanceGateGPUAddress ?? unconditionalAcceptanceGateBuffer.gpuAddress,
      index: 12
    )
    argumentTable.setAddress(
      acceptanceGateResultGPUAddress
        ?? unconditionalAcceptanceGateBuffer.gpuAddress,
      index: 13
    )
    argumentTable.setAddress(
      acceptedFastMotorState?.protectiveCommandBuffer.gpuAddress
        ?? neutralProtectiveCommandBuffer.gpuAddress,
      index: 8
    )
    if species.body.muscleCount > 0 {
      dispatch(
        encoder,
        pipeline: pipelines[11],
        count: Int(species.body.muscleCount)
      )
      barrier(encoder)
    }
    dispatch(
      encoder,
      pipeline: pipelines[0],
      count: max(
        Int(species.body.bodyCount),
        max(
          arena.layout.section(.muscleBelief).elementCount,
          Int(species.physiology.stateDimension)
        )
      )
    )
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: pipelines[10],
      count: Int(species.body.jointCount)
    )
    barrier(encoder)
    dispatch(encoder, pipeline: pipelines[12], count: 1)
    barrier(encoder)
    if species.body.muscleCount > 0 {
      dispatch(
        encoder,
        pipeline: pipelines[13],
        count: Int(species.body.muscleCount)
      )
      barrier(encoder)
    }
    if let acceptedFastMotorState,
      acceptedFastMotorState.bodySchemaByteCount > 0
    {
      argumentTable.setAddress(
        acceptedFastMotorState.bodySchemaBuffer.gpuAddress,
        index: 7
      )
      dispatch(
        encoder,
        pipeline: pipelines[7],
        count: acceptedFastMotorState.bodySchemaCount
      )
      barrier(encoder)
    }
    dispatch(
      encoder,
      pipeline: pipelines[8],
      count: Int(species.body.bodyCount)
    )
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: pipelines[9],
      count: sensorimotorWorldDimension
    )
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: pipelines[1],
      count: min(arena.layout.section(.worldModel).elementCount, 128)
    )
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: pipelines[2],
      count: Int(species.motor.activeSensingActionDimension)
    )
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: pipelines[3],
      count: 1
    )
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: pipelines[4],
      count: Int(species.capacities.activeCerebellarExpertCapacity)
    )
    dispatch(
      encoder,
      pipeline: pipelines[5],
      count: Int(species.capacities.fastPlasticityCapacity)
    )
    dispatch(encoder, pipeline: pipelines[6], count: 1)
  }

  private func makeUniforms(
    acceptedTimestamp: BrainTimestamp,
    physicsStateFingerprint: UInt64,
    deltaMicroseconds: UInt64,
    eventCapacity: UInt32
  ) throws -> AcceptedConsequenceUniforms {
    func hot(_ section: MetalAgentHotSection) -> MetalArenaSectionLayout<MetalAgentHotSection> {
      arena.layout.section(section)
    }
    func range(_ modality: SensoryModality) -> ObservationRange {
      observationRanges[modality] ?? ObservationRange(offset: 0, count: 0)
    }
    let vision = range(.vision)
    let audition = range(.audition)
    let proprioception = range(.proprioception)
    let touch = range(.touch)
    let vestibular = range(.vestibular)
    let olfaction = range(.olfaction)
    let gustation = range(.gustation)
    let interoception = range(.interoception)
    let controlHeader = controlLayout.section(.header)
    let optionCandidates = controlLayout.section(.optionCandidates)
    let planSteps = controlLayout.section(.planSteps)
    let motor = controlLayout.section(.motorCommands)
    let cerebellar = controlLayout.section(.cerebellarExperts)
    let activeSensing = controlLayout.section(.activeSensingCommands)
    let integerCounts = [
      hot(.sensoryObservations).elementCount,
      hot(.sensoryValidity).elementCount,
      hot(.worldModel).elementCount,
      hot(.drives).elementCount,
      optionCandidates.elementCount,
      planSteps.elementCount,
      hot(.fastPlasticity).elementCount,
    ]
    guard
      hot(.sensoryValidity).elementCount
        == hot(.sensoryObservations).elementCount,
      integerCounts.allSatisfy({ $0 > 0 && $0 <= Int(UInt32.max) }),
      planSteps.elementCount % optionCandidates.elementCount == 0
    else {
      throw TissueError.metal("accepted-consequence arena exceeds UInt32")
    }
    let maximumPlanningHorizon =
      planSteps.elementCount / optionCandidates.elementCount
    let reflexStateCount = species.reflexes.reduce(0) {
      $0 + $1.receptorChannelCodes.count * $1.actuatorIdentifiers.count
    }
    guard reflexStateCount <= Int(UInt32.max),
      reflexStateCount <= hot(.reflexState).elementCount
    else {
      throw TissueError.metal("accepted reflex state exceeds UInt32 or its arena section")
    }
    return AcceptedConsequenceUniforms(
      targetTimestampMicroseconds: acceptedTimestamp.rawValue,
      deltaMicroseconds: deltaMicroseconds,
      observationOffset: UInt64(hot(.sensoryObservations).byteOffset),
      observationValidityOffset: UInt64(hot(.sensoryValidity).byteOffset),
      eventQueueOffset: UInt64(hot(.eventQueue).byteOffset),
      bodyBeliefOffset: UInt64(hot(.bodyBelief).byteOffset),
      jointBeliefOffset: UInt64(hot(.jointBelief).byteOffset),
      muscleBeliefOffset: UInt64(hot(.muscleBelief).byteOffset),
      physiologyOffset: UInt64(hot(.physiologyBelief).byteOffset),
      objectSlotOffset: UInt64(hot(.objectSlots).byteOffset),
      worldModelOffset: UInt64(hot(.worldModel).byteOffset),
      neuromodulationOffset: UInt64(hot(.neuromodulation).byteOffset),
      driveOffset: UInt64(hot(.drives).byteOffset),
      fastPlasticityOffset: UInt64(hot(.fastPlasticity).byteOffset),
      workspaceContentOffset: UInt64(hot(.workspaceContent).byteOffset),
      workspaceMetadataOffset: UInt64(hot(.workspaceMetadata).byteOffset),
      controlHeaderOffset: UInt64(controlHeader.byteOffset),
      optionCandidateOffset: UInt64(optionCandidates.byteOffset),
      proceduralTraceOffset: UInt64(
        hot(.proceduralExecutionTrace).byteOffset
      ),
      motorCommandOffset: UInt64(motor.byteOffset),
      cerebellarOffset: UInt64(cerebellar.byteOffset),
      cerebellarExpertMemoryOffset: UInt64(
        hot(.cerebellarExpertMemory).byteOffset
      ),
      somaticOutputOffset: UInt64(hot(.somaticOutput).byteOffset),
      activeSensingCommandOffset: UInt64(activeSensing.byteOffset),
      activeSensingEfficacyOffset: UInt64(
        hot(.activeSensingEfficacy).byteOffset
      ),
      acceptedSomaticOutputOffset: UInt64(
        hot(.acceptedSomaticOutput).byteOffset
      ),
      acceptedActiveSensingOutputOffset: UInt64(
        hot(.acceptedActiveSensingOutput).byteOffset
      ),
      reflexStateOffset: UInt64(hot(.reflexState).byteOffset),
      fastAutonomicStateOffset: UInt64(hot(.fastAutonomicState).byteOffset),
      physicsStateFingerprint: physicsStateFingerprint,
      regionalMaturationOffset: UInt64(hot(.regionalMaturation).byteOffset),
      observationCount: UInt32(hot(.sensoryObservations).elementCount),
      bodyCount: species.body.bodyCount,
      jointCount: species.body.jointCount,
      anatomicalMuscleCount: species.body.muscleCount,
      muscleCount: UInt32(hot(.muscleBelief).elementCount),
      physiologyCount: UInt32(species.physiology.stateDimension),
      objectSlotCount: UInt32(hot(.objectSlots).elementCount),
      worldModelCount: UInt32(hot(.worldModel).elementCount),
      neuromodulatorCount: UInt32(NeuromodulatorKind.allCases.count),
      driveCount: UInt32(hot(.drives).elementCount),
      maximumPlanningHorizon: UInt32(maximumPlanningHorizon),
      fastPlasticityCount: UInt32(hot(.fastPlasticity).elementCount),
      workspaceCapacity: UInt32(species.capacities.workspaceTokenCapacity),
      workspaceDimension: UInt32(species.capacities.workspaceTokenDimension),
      activeCerebellarCount: UInt32(
        species.capacities.activeCerebellarExpertCapacity
      ),
      actuatorCount: species.motor.actuatorCount,
      activeSensingCount: UInt32(species.motor.activeSensingActionDimension),
      reflexStateCount: UInt32(reflexStateCount),
      fastAutonomicStateCount: UInt32(
        hot(.fastAutonomicState).elementCount
      ),
      eventCapacity: eventCapacity,
      optionCandidateCapacity: UInt32(optionCandidates.elementCount),
      proceduralTraceRecordCapacity: UInt32(
        hot(.proceduralExecutionTrace).elementCount
      ),
      proceduralTracePhaseCapacity: 8,
      cerebellarExpertCapacity: UInt32(
        species.capacities.cerebellarExpertCapacity
      ),
      visionOffset: vision.offset,
      visionCount: vision.count,
      auditionOffset: audition.offset,
      auditionCount: audition.count,
      proprioceptionOffset: proprioception.offset,
      proprioceptionCount: proprioception.count,
      touchOffset: touch.offset,
      touchCount: touch.count,
      vestibularOffset: vestibular.offset,
      vestibularCount: vestibular.count,
      olfactionOffset: olfaction.offset,
      olfactionCount: olfaction.count,
      gustationOffset: gustation.offset,
      gustationCount: gustation.count,
      interoceptionOffset: interoception.offset,
      interoceptionCount: interoception.count,
      moduleCount: UInt32(species.enabledModuleIdentifiers.count),
      plasticityParameterCount: plasticityParameterCount,
      beliefGain: dynamics.beliefGain,
      worldCorrectionGain: dynamics.worldCorrectionGain,
      cerebellarLearningRate: dynamics.cerebellarLearningRate,
      plasticityLearningRate: dynamics.plasticityLearningRate
    )
  }

  private func dispatch(
    _ encoder: any MTL4ComputeCommandEncoder,
    pipeline: any MTLComputePipelineState,
    count: Int
  ) {
    encoder.setComputePipelineState(pipeline)
    encoder.setArgumentTable(argumentTable)
    let width = min(
      max(pipeline.threadExecutionWidth, 1),
      pipeline.maxTotalThreadsPerThreadgroup
    )
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: max(count, 1), height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
    )
  }

  private func barrier(_ encoder: any MTL4ComputeCommandEncoder) {
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
  }
}

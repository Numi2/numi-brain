import Metal
import NumiBrainABI
import NumiBrainMetalBridgeABI
import XCTest

@testable import NumiBrainCore
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class NumanXInteropTests: XCTestCase {
  func testNumanXPacketABISizesAreExact() {
    XCTAssertEqual(NumanXMotorCandidate.byteCount, 152)
    XCTAssertEqual(nb_brain_abi_numanx_motor_candidate_size(), 152)
    XCTAssertEqual(MemoryLayout<NBNumanXMotorCandidate>.stride, 152)
    XCTAssertEqual(NumanXSensorPacket.channelByteCount, 56)
    XCTAssertEqual(nb_brain_abi_numanx_sensor_channel_size(), 56)
    XCTAssertEqual(MemoryLayout<NBNumanXSensorChannel>.stride, 56)
    XCTAssertEqual(NumanXSensorPacket.byteCount, 72)
    XCTAssertEqual(nb_brain_abi_numanx_sensor_packet_size(), 72)
    XCTAssertEqual(MemoryLayout<NBNumanXSensorPacket>.stride, 72)
    XCTAssertEqual(MemoryLayout<mrnx_candidate_timing_v1>.stride, 40)
    XCTAssertEqual(MemoryLayout<mrnx_aggregate_snapshot_v3>.stride, 1_320)
  }

  func testCommittedSensorPacketRoundTripsAndRejectsShapeAndLeaseDrift() throws {
    let device = try requireMetalDevice()
    let compiled = try makeNumanXInteropCompiledTemplate()
    let transaction = try makeTransaction()
    let rawSensors = try makeRawSensors(
      device: device,
      compiledSpeciesTemplate: compiled,
      deliveryTimestamp: transaction.committedTimestamp
    )
    let lease = try NumanXSensorPacketLease(
      transaction: transaction,
      compiledSpeciesTemplate: compiled,
      rawSensors: rawSensors
    )

    XCTAssertFalse(lease.packet.isAcceptedState)
    XCTAssertEqual(lease.packet.physicsGeneration, transaction.basePhysicsGeneration)
    XCTAssertEqual(lease.packet.deliveryTimestamp, transaction.committedTimestamp)
    XCTAssertEqual(
      lease.packet.rawSensorViews.map(\.modality),
      [.proprioception, .interoception, .kinesthesia]
    )
    XCTAssertEqual(
      try NumanXSensorPacketLease(
        validating: lease.packet.abiRecord,
        channels: lease.packet.abiChannels,
        transaction: transaction,
        compiledSpeciesTemplate: compiled,
        rawSensors: rawSensors
      ).packet,
      lease.packet
    )

    // Packet identity authenticates transaction-local buffer metadata and its
    // resident allocation, not mutable sensor payload bytes.
    let firstSensorScalar = rawSensors[0].buffer.contents()
      .assumingMemoryBound(to: Float.self)
    let originalScalar = firstSensorScalar.pointee
    firstSensorScalar.pointee = originalScalar + 1
    XCTAssertNotEqual(firstSensorScalar.pointee, originalScalar)
    var metadataRecord = lease.packet.abiRecord
    let metadataChannels = lease.packet.abiChannels
    XCTAssertEqual(
      metadataChannels.withUnsafeBufferPointer { channels in
        withUnsafePointer(to: &metadataRecord) {
          nb_brain_abi_numanx_sensor_packet_fingerprint($0, channels.baseAddress)
        }
      },
      lease.packet.fingerprint
    )

    var forgedPacket = lease.packet.abiRecord
    var forgedChannels = lease.packet.abiChannels
    forgedChannels[0].receptor_count = 1
    forgedChannels[0].byte_count = forgedChannels[0].feature_dimension
      * UInt32(MemoryLayout<Float>.stride)
    forgedChannels[0].validity_byte_count = UInt32(MemoryLayout<UInt32>.stride)
    forgedPacket.packet_fingerprint = forgedChannels.withUnsafeBufferPointer { channels in
      withUnsafePointer(to: &forgedPacket) {
        nb_brain_abi_numanx_sensor_packet_fingerprint($0, channels.baseAddress)
      }
    }
    XCTAssertThrowsError(
      try NumanXSensorPacket(
        validating: forgedPacket,
        channels: forgedChannels,
        transaction: transaction,
        compiledSpeciesTemplate: compiled
      )
    )

    var wrongModalityPacket = lease.packet.abiRecord
    var wrongModalityChannels = lease.packet.abiChannels
    wrongModalityChannels[0].modality = UInt32(SensoryModality.touch.rawValue)
    wrongModalityPacket.packet_fingerprint = wrongModalityChannels
      .withUnsafeBufferPointer { channels in
        withUnsafePointer(to: &wrongModalityPacket) {
          nb_brain_abi_numanx_sensor_packet_fingerprint($0, channels.baseAddress)
        }
      }
    XCTAssertThrowsError(
      try NumanXSensorPacket(
        validating: wrongModalityPacket,
        channels: wrongModalityChannels,
        transaction: transaction,
        compiledSpeciesTemplate: compiled
      )
    )

    var wrongLatencyPacket = lease.packet.abiRecord
    var wrongLatencyChannels = lease.packet.abiChannels
    wrongLatencyChannels[0].latency_microseconds += 1
    wrongLatencyChannels[0].receptor_timestamp_microseconds -= 1
    wrongLatencyPacket.packet_fingerprint = wrongLatencyChannels
      .withUnsafeBufferPointer { channels in
        withUnsafePointer(to: &wrongLatencyPacket) {
          nb_brain_abi_numanx_sensor_packet_fingerprint($0, channels.baseAddress)
        }
      }
    XCTAssertThrowsError(
      try NumanXSensorPacket(
        validating: wrongLatencyPacket,
        channels: wrongLatencyChannels,
        transaction: transaction,
        compiledSpeciesTemplate: compiled
      )
    )

    let replacementSensors = try makeRawSensors(
      device: device,
      compiledSpeciesTemplate: compiled,
      deliveryTimestamp: transaction.committedTimestamp
    )
    XCTAssertThrowsError(
      try NumanXSensorPacketLease(
        validating: lease.packet.abiRecord,
        channels: lease.packet.abiChannels,
        transaction: transaction,
        compiledSpeciesTemplate: compiled,
        rawSensors: replacementSensors
      )
    )
  }

  func testAcceptedSensorPacketIsBoundToExactAcceptedPhysicsToken() throws {
    let device = try requireMetalDevice()
    let compiled = try makeNumanXInteropCompiledTemplate()
    let transaction = try makeTransaction()
    let substep = try BrainJointSubstepToken(
      transaction: transaction,
      substepIndex: 0,
      attemptIndex: 0,
      startTimestamp: transaction.committedTimestamp,
      durationMicroseconds: transaction.targetTimestamp.rawValue
        - transaction.committedTimestamp.rawValue
    )
    let accepted = try AcceptedPhysicsStateToken(
      transaction: transaction,
      substep: substep,
      physicsStateFingerprint: 0xabc0_0001,
      physicsGeneration: transaction.basePhysicsGeneration + 1
    )
    let rawSensors = try makeRawSensors(
      device: device,
      compiledSpeciesTemplate: compiled,
      deliveryTimestamp: accepted.acceptedTimestamp
    )
    let lease = try NumanXSensorPacketLease(
      transaction: transaction,
      acceptedPhysicsState: accepted,
      compiledSpeciesTemplate: compiled,
      rawSensors: rawSensors
    )

    XCTAssertTrue(lease.packet.isAcceptedState)
    XCTAssertEqual(
      lease.packet.acceptedPhysicsTokenFingerprint,
      accepted.fingerprint
    )
    XCTAssertEqual(lease.packet.deliveryTimestamp, transaction.targetTimestamp)
    XCTAssertEqual(lease.packet.physicsGeneration, accepted.physicsGeneration)
    XCTAssertEqual(
      try NumanXSensorPacketLease(
        validating: lease.packet.abiRecord,
        channels: lease.packet.abiChannels,
        transaction: transaction,
        acceptedPhysicsState: accepted,
        compiledSpeciesTemplate: compiled,
        rawSensors: rawSensors
      ).packet,
      lease.packet
    )
    XCTAssertThrowsError(
      try NumanXSensorPacket(
        validating: lease.packet.abiRecord,
        channels: lease.packet.abiChannels,
        transaction: transaction,
        compiledSpeciesTemplate: compiled
      )
    )
  }

  private func makeTransaction() throws -> BrainJointTransactionToken {
    try BrainJointTransactionToken(
      environmentIdentifier: 7,
      episodeIdentifier: 23,
      controlStepIdentifier: 17,
      parameterVersionFingerprint: 0x1234_5678_9abc_def0,
      baseBrainGeneration: 9,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 80_000),
      targetTimestamp: BrainTimestamp(microseconds: 100_000),
      randomCounterGeneration: 55
    )
  }

  private func requireMetalDevice() throws -> any MTLDevice {
    guard let device = MTLCreateSystemDefaultDevice() else {
      throw XCTSkip("Metal is unavailable")
    }
    return device
  }
}

@available(macOS 26.0, *)
func makeNumanXInteropBoundRuntime(
  parameters: TissueParameters,
  maxEncodedSubsteps: Int
) throws -> (runtime: MetalTissueRuntime, compiledSpeciesTemplate: CompiledSpeciesTemplate) {
  let compiledSpeciesTemplate = try makeNumanXInteropCompiledTemplate()
  let initial = try CPUTissueDynamics.makeRestingGrid(
    width: 8,
    height: 8,
    parameters: parameters
  )
  let runtime = try MetalTissueRuntime(
    initialState: initial,
    parameters: parameters,
    stimulus: .none,
    randomContext: TissueRandomContext(
      seed: 0x4e55_4d49,
      environmentIdentifier: 7,
      episodeIdentifier: 23
    ),
    protectiveMotorProfile: compiledSpeciesTemplate.protectiveMotorProfile,
    somaticSynergyCatalog: compiledSpeciesTemplate.somaticSynergyCatalog,
    schedulerEnvironmentIdentifier: 7,
    maxEncodedSubsteps: maxEncodedSubsteps
  )
  try runtime.bindSpeciesReflexProgram(compiledSpeciesTemplate)
  return (runtime, compiledSpeciesTemplate)
}

func makeNumanXInteropCompiledTemplate(
  actuatorCount: UInt32 = 6,
  proprioceptorCount: UInt32 = 2,
  proprioceptionFeatureDimension: UInt32 = 3,
  proprioceptionLatencyMicroseconds: UInt32 = 250,
  proprioceptionActiveSensingActionDimension: UInt16 = 1,
  kinesthesiaReceptorCount: UInt32 = 1,
  kinesthesiaFeatureDimension: UInt32 = 7,
  kinesthesiaLatencyMicroseconds: UInt32 = 250,
  vestibularReceptorCount: UInt32 = 0,
  vestibularFeatureDimension: UInt32 = 0,
  vestibularLatencyMicroseconds: UInt32 = 250,
  auditionReceptorCount: UInt32 = 0,
  auditionFeatureDimension: UInt32 = 0,
  auditionLatencyMicroseconds: UInt32 = 250,
  visionReceptorCount: UInt32 = 0,
  visionFeatureDimension: UInt32 = 0,
  visionLatencyMicroseconds: UInt32 = 250,
  visionActiveSensingActionDimension: UInt16 = 0,
  touchReceptorCount: UInt32 = 0,
  touchFeatureDimension: UInt32 = 0,
  touchLatencyMicroseconds: UInt32 = 250,
  interoceptorCount: UInt32 = 1,
  interoceptionFeatureDimension: UInt32 = 1,
  interoceptionLatencyMicroseconds: UInt32 = 1_000,
  somaticSynergyCount: UInt16? = nil,
  planningHorizonSteps: UInt16 = 1,
  workspaceCapacity: UInt16 = 1,
  name: String = "NumanX interop test fixture"
) throws -> CompiledSpeciesTemplate {
  let capacities = try BrainCapacityProfile.fullCognitiveV1
  let resolvedSomaticSynergyCount = somaticSynergyCount
    ?? UInt16(truncatingIfNeeded: actuatorCount)
  guard actuatorCount > 0,
    actuatorCount <= UInt32(UInt16.max),
    resolvedSomaticSynergyCount > 0,
    proprioceptorCount > 1,
    proprioceptionFeatureDimension > 0,
    kinesthesiaReceptorCount > 0,
    kinesthesiaFeatureDimension >= UInt32(JointReceptorSignal.allCases.count),
    (auditionReceptorCount == 0) == (auditionFeatureDimension == 0),
    (visionReceptorCount == 0) == (visionFeatureDimension == 0),
    Int(proprioceptionActiveSensingActionDimension)
      + Int(visionActiveSensingActionDimension) <= Int(UInt16.max),
    interoceptorCount > 0,
    interoceptionFeatureDimension > 0,
    planningHorizonSteps > 0,
    workspaceCapacity > 0,
    workspaceCapacity <= capacities.workspaceTokenCapacity
  else {
    throw BrainRuntimeError.invalidDescriptor(
      "NumanX interop fixture shape is invalid"
    )
  }
  let referenceGraph = try ReferenceBrainGraph.mammalianV1()
  let jointTopology = try NumanXJointTopologyCatalog(
    numanXModelFingerprint: 0x4e55_4d41_4e58,
    bodyCount: 2,
    joints: [
      try NumanXJointTopology(
        jointIdentifier: 1,
        parentBodyIdentifier: 0,
        childBodyIdentifier: 1,
        parentLocalAnchor: try NumanXBodyLocalPoint(x: 0, y: 0, z: 0),
        childLocalAnchor: try NumanXBodyLocalPoint(x: 0, y: 0, z: 0),
        restRelativeOrientation: try BrainQuaternion.identity,
        coordinates: [
          try NumanXJointCoordinateTopology(
            identifier: 0,
            kind: .angular,
            parentLocalAxis: try NumanXBodyLocalPoint(x: 1, y: 0, z: 0),
            minimumPosition: -1,
            maximumPosition: 1,
            restPosition: 0
          )
        ]
      )
    ]
  )
  let senses = try SensoryModality.allCases.map { modality in
    switch modality {
    case .proprioception:
      return try SensoryTopology(
        modality: modality,
        receptorCount: proprioceptorCount,
        observationDimension: proprioceptionFeatureDimension,
        latencyMicroseconds: proprioceptionLatencyMicroseconds,
        adaptationTimeConstantMicroseconds: 10_000,
        noiseStandardDeviation: 0,
        activeSensingActionDimension:
          proprioceptionActiveSensingActionDimension,
        enabled: true
      )
    case .interoception:
      return try SensoryTopology(
        modality: modality,
        receptorCount: interoceptorCount,
        observationDimension: interoceptionFeatureDimension,
        latencyMicroseconds: interoceptionLatencyMicroseconds,
        adaptationTimeConstantMicroseconds: 10_000,
        noiseStandardDeviation: 0,
        activeSensingActionDimension: 0,
        enabled: true
      )
    case .kinesthesia:
      return try SensoryTopology(
        modality: modality,
        receptorCount: kinesthesiaReceptorCount,
        observationDimension: kinesthesiaFeatureDimension,
        latencyMicroseconds: kinesthesiaLatencyMicroseconds,
        adaptationTimeConstantMicroseconds: 10_000,
        noiseStandardDeviation: 0,
        activeSensingActionDimension: 0,
        enabled: true
      )
    case .vestibular where vestibularReceptorCount > 0:
      return try SensoryTopology(
        modality: modality,
        receptorCount: vestibularReceptorCount,
        observationDimension: vestibularFeatureDimension,
        latencyMicroseconds: vestibularLatencyMicroseconds,
        adaptationTimeConstantMicroseconds: 10_000,
        noiseStandardDeviation: 0,
        activeSensingActionDimension: 0,
        enabled: true
      )
    case .audition where auditionReceptorCount > 0:
      return try SensoryTopology(
        modality: modality,
        receptorCount: auditionReceptorCount,
        observationDimension: auditionFeatureDimension,
        latencyMicroseconds: auditionLatencyMicroseconds,
        adaptationTimeConstantMicroseconds: 20_000,
        noiseStandardDeviation: 0,
        activeSensingActionDimension: 0,
        enabled: true
      )
    case .vision where visionReceptorCount > 0:
      return try SensoryTopology(
        modality: modality,
        receptorCount: visionReceptorCount,
        observationDimension: visionFeatureDimension,
        latencyMicroseconds: visionLatencyMicroseconds,
        adaptationTimeConstantMicroseconds: 10_000,
        noiseStandardDeviation: 0,
        activeSensingActionDimension: visionActiveSensingActionDimension,
        enabled: true
      )
    case .touch where touchReceptorCount > 0:
      return try SensoryTopology(
        modality: modality,
        receptorCount: touchReceptorCount,
        observationDimension: touchFeatureDimension,
        latencyMicroseconds: touchLatencyMicroseconds,
        adaptationTimeConstantMicroseconds: 10_000,
        noiseStandardDeviation: 0,
        activeSensingActionDimension: 0,
        enabled: true
      )
    default:
      return try SensoryTopology(
        modality: modality,
        receptorCount: 0,
        observationDimension: 0,
        latencyMicroseconds: 0,
        adaptationTimeConstantMicroseconds: 10_000,
        noiseStandardDeviation: 0,
        activeSensingActionDimension: 0,
        enabled: false
      )
    }
  }
  let motor = try MotorTopology(
    actuatorCommandKind: .muscleExcitation,
    actuatorCount: actuatorCount,
    synergyCount: resolvedSomaticSynergyCount,
    motorNucleusCount: 1,
    autonomicActionDimension: 1,
    activeSensingActionDimension:
      proprioceptionActiveSensingActionDimension
        + visionActiveSensingActionDimension,
    outputMinimum: 0,
    outputMaximum: 1
  )
  let physiology = try PhysiologyTemplate(
    modelClass: .artificialEnergyThermal,
    stateDimension: 1,
    autonomicActionDimension: 1,
    viableMinimums: [0.2],
    viableMaximums: [0.8],
    criticalMinimums: [0],
    criticalMaximums: [1],
    receptorMappings: [
      try PhysiologicalReceptorTemplate(
        stateIdentifier: 0,
        receptorIdentifier: 900,
        interoceptiveReceptorIndex: 0,
        featureIndex: 0,
        magnitudeScale: 1
      )
    ],
    autonomicChannels: [
      try AutonomicChannelTemplate(
        identifier: 0,
        kind: .generic,
        criticalReceptorIdentifiers: [900],
        respondsToAnyPhysiologicalCritical: false,
        emergencyTarget: 1,
        emergencyGain: 1,
        cpgGain: 0
      )
    ]
  )
  let enabledModules = referenceGraph.modules.map(\.identifier)
  let development = try DevelopmentalStage.allCases.map { stage in
    try DevelopmentalStageTemplate(
      stage: stage,
      unlockedModuleIdentifiers: enabledModules,
      learningRateMultiplier: 1,
      sensorPrecisionMultiplier: 1,
      muscleStrengthMultiplier: 1,
      planningHorizonSteps: planningHorizonSteps,
      workspaceCapacity: workspaceCapacity,
      capabilityGateCodes: stage == .innateScaffold ? [] : [UInt64(stage.rawValue)]
    )
  }
  let species = try SpeciesTemplate(
    family: .genericRobot,
    name: name,
    referenceGraph: referenceGraph,
    enabledModuleIdentifiers: enabledModules,
    body: try SpeciesBodyTopology(
      bodyCount: 2,
      jointCount: 1,
      jointTopologyFingerprint: jointTopology.fingerprint,
      muscleCount: 0,
      muscleAttachmentFingerprint: 0,
      skinSurfaceCount: 1,
      actuatorCount: actuatorCount,
      morphologyCode: 0x4e55_4d41_4e58
    ),
    senses: senses,
    motor: motor,
    reflexes: [],
    cpg: try CPGTopology(oscillators: [], couplings: []),
    physiology: physiology,
    innateBehaviors: [],
    development: development,
    capacities: capacities
  )
  let receptorAnatomy = try NumanXReceptorAnatomyCatalog(
    species: species,
    jointTopologyCatalog: jointTopology,
    muscleAttachmentCatalog: nil,
    numanXModelFingerprint: jointTopology.numanXModelFingerprint,
    endpoints: [
      try NumanXReceptorEndpoint(
        identifier: 1,
        sourceEndpointIdentifier: 101,
        bodyIdentifier: 0,
        modality: .proprioception,
        receptorIndex: 0,
        featureIndex: 0,
        signal: .position,
        component: 0
      )
    ],
    jointEndpoints: try JointReceptorSignal.allCases.enumerated().map { index, signal in
      try NumanXJointReceptorEndpoint(
        identifier: UInt32(10 + index),
        sourceEndpointIdentifier: UInt64(110 + index),
        jointIdentifier: 1,
        coordinateIdentifier: 0,
        receptorIndex: 0,
        featureIndex: UInt32(index),
        signal: signal
      )
    },
    muscleEndpoints: []
  )
  let sensoryProfile = try SensoryTransductionProfile(
    species: species,
    eventRules: [],
    numanXReceptorAnatomy: receptorAnatomy,
    jointTopologyCatalog: jointTopology,
    muscleAttachmentCatalog: nil
  )
  let protectiveMotorProfile = try ProtectiveMotorProfile.runtimeFoundationFixture(
    muscleIdentifiers: Array(0..<actuatorCount)
  )
  let somaticSynergyCatalog = try SomaticSynergyCatalog.runtimeFoundationFixture(
    actuatorCount: actuatorCount,
    synergyCount: resolvedSomaticSynergyCount
  )
  return try SpeciesTemplateCompiler.compileRuntimeTemplate(
    referenceBrainGraph: referenceGraph,
    species: species,
    sensoryProfile: sensoryProfile,
    numanXReceptorAnatomyCatalog: receptorAnatomy,
    jointTopologyCatalog: jointTopology,
    muscleAttachmentCatalog: nil,
    somaticSynergyCatalog: somaticSynergyCatalog,
    protectiveMotorProfile: protectiveMotorProfile
  )
}

/// Exact NumanX HumanIO/motor transport shape used by the real 416-muscle
/// bridge. The two-body articulation remains an explicitly synthetic nervous-
/// system fixture; the native full-body runtime separately owns and proves the
/// 157-body 129-q/128-DoF physical asset.
func makeNumanXFullBodyTransportCompiledTemplate() throws
  -> CompiledSpeciesTemplate
{
  try makeNumanXInteropCompiledTemplate(
    actuatorCount: 416,
    proprioceptorCount: 416,
    proprioceptionFeatureDimension: 10,
    proprioceptionLatencyMicroseconds: 1_000,
    proprioceptionActiveSensingActionDimension: 0,
    kinesthesiaReceptorCount: 128,
    kinesthesiaFeatureDimension: 7,
    kinesthesiaLatencyMicroseconds: 1_000,
    vestibularReceptorCount: 1,
    vestibularFeatureDimension: 22,
    vestibularLatencyMicroseconds: 1_000,
    auditionReceptorCount: 24,
    auditionFeatureDimension: 8,
    auditionLatencyMicroseconds: 1_000,
    visionReceptorCount: 64 * 48,
    visionFeatureDimension: 8,
    visionLatencyMicroseconds: 1_000,
    visionActiveSensingActionDimension: 1,
    touchReceptorCount: 10,
    touchFeatureDimension: 7,
    touchLatencyMicroseconds: 1_000,
    interoceptorCount: 416,
    interoceptionFeatureDimension: 6,
    interoceptionLatencyMicroseconds: 1_000,
    somaticSynergyCount: 16,
    planningHorizonSteps: 4,
    workspaceCapacity: 16,
    name: "NumanX 416-muscle transport qualification fixture"
  )
}

@available(macOS 26.0, *)
private func makeRawSensors(
  device: any MTLDevice,
  compiledSpeciesTemplate: CompiledSpeciesTemplate,
  deliveryTimestamp: BrainTimestamp
) throws -> [MetalRawSensorBufferLease] {
  try compiledSpeciesTemplate.species.senses.filter(\.enabled).map { topology in
    let scalarCount = Int(topology.receptorCount) * Int(topology.observationDimension)
    guard let buffer = device.makeBuffer(
      length: scalarCount * MemoryLayout<Float>.stride,
      options: .storageModeShared
    ) else {
      throw TissueError.metal("failed to allocate test receptor buffer")
    }
    let validityBuffer: (any MTLBuffer)?
    if topology.modality == .proprioception {
      validityBuffer = device.makeBuffer(
        length: Int(topology.receptorCount) * MemoryLayout<UInt32>.stride,
        options: .storageModeShared
      )
    } else {
      validityBuffer = nil
    }
    return try MetalRawSensorBufferLease(
      buffer: buffer,
      modality: topology.modality,
      receptorTimestamp: BrainTimestamp(
        microseconds: deliveryTimestamp.rawValue - UInt64(topology.latencyMicroseconds)
      ),
      receptorCount: topology.receptorCount,
      featureDimension: topology.observationDimension,
      validityBuffer: validityBuffer
    )
  }
}

import CryptoKit
import Foundation
@preconcurrency import Metal
import NumiBrainABI
import NumiBrainCore

// The native Human owner supplies the exact prepared source, owns every command
// buffer, and publishes physical state. This bridge owns only neural state.
@available(macOS 26.0, *)
struct StandingSource: Decodable {
  struct SupportEndpoint: Decodable {
    let sourceEndpointIdentifier: UInt64
    let bodyIdentifier: UInt32
    let sourceGeometryIndex: UInt32
    let touchReceptorIndex: UInt32
  }
  struct Joint: Decodable {
    let jointIdentifier: UInt32
    let parentBodyIdentifier: UInt32
    let childBodyIdentifier: UInt32
    let coordinateOffset: UInt32
    let coordinateCount: UInt32
    let parentLocalAnchor: NumanXBodyLocalPoint
    let childLocalAnchor: NumanXBodyLocalPoint
    let restRelativeOrientation: BrainQuaternion
  }
  struct Coordinate: Decodable {
    let jointIdentifier: UInt32
    let identifier: UInt16
    let kind: NumanXJointCoordinateKind
    let qIndex: UInt32
    let vIndex: UInt32
    let parentLocalAxis: NumanXBodyLocalPoint
    let minimumPosition: Float
    let maximumPosition: Float
    let restPosition: Float
    let sourceCompliantLimit: Bool
  }
  struct Channel: Decodable {
    let muscleIdentifier: UInt32
    let referenceLengthMeters: Float
    let referenceFiberLengthMeters: Float
    let tonicExcitation: Float
    let preparedActivation: Float
  }
  let version: UInt32
  let modelSourceFingerprint: UInt64
  let bodyCount: UInt32
  let headBodyIdentifier: UInt32
  let joints: [Joint]
  let coordinates: [Coordinate]
  let attachments: [NumanXMuscleAttachment]
  let channels: [Channel]
  let supportEndpoints: [SupportEndpoint]?
  let jointPathCalibration: MuscleJointPathCalibration?

  private enum CodingKeys: String, CodingKey {
    case version, modelSourceFingerprint, bodyCount, headBodyIdentifier
    case joints, coordinates, attachments, channels, supportEndpoints
    case jointPathCalibration
  }

  init(from decoder: Decoder) throws {
    let source = try decoder.container(keyedBy: CodingKeys.self)
    version = try source.decode(UInt32.self, forKey: .version)
    modelSourceFingerprint = try source.decode(UInt64.self, forKey: .modelSourceFingerprint)
    bodyCount = try source.decode(UInt32.self, forKey: .bodyCount)
    headBodyIdentifier = try source.decode(UInt32.self, forKey: .headBodyIdentifier)
    joints = try source.decode([Joint].self, forKey: .joints)
    coordinates = try source.decode([Coordinate].self, forKey: .coordinates)
    attachments = try source.decode([NumanXMuscleAttachment].self, forKey: .attachments)
    channels = try source.decode([Channel].self, forKey: .channels)
    // An absent field is the legacy no-support source. A present field must
    // decode as a complete array; null and partial records are invalid.
    supportEndpoints = source.contains(.supportEndpoints)
      ? try source.decode([SupportEndpoint].self, forKey: .supportEndpoints) : nil
    // A present calibration must decode completely. It is owned by the exact
    // prepared native source and is never filled from a program-side fixture.
    jointPathCalibration = source.contains(.jointPathCalibration)
      ? try source.decode(MuscleJointPathCalibration.self,
        forKey: .jointPathCalibration) : nil
  }

  func compile(latencyMicroseconds: UInt32) throws -> CompiledSpeciesTemplate {
    // Version 3 adds an authenticated native reference-path calibration.
    // The unchanged version 1/2 source remains valid only without that field.
    guard (version == 1 && supportEndpoints == nil && jointPathCalibration == nil)
      || (version == 2 && supportEndpoints != nil && jointPathCalibration == nil)
      || (version == 3 && supportEndpoints != nil && jointPathCalibration != nil) else {
      throw BrainRuntimeError.invalidDescriptor("standing source version and support contract differ")
    }
    if let jointPathCalibration {
      try jointPathCalibration.validate()
    }
    guard modelSourceFingerprint != 0,
      bodyCount == 157, headBodyIdentifier < bodyCount,
      channels.count == 416, attachments.count == 416,
      coordinates.count == 122 else {
      throw BrainRuntimeError.invalidDescriptor("standing source dimensions or identity are invalid")
    }
    var byJoint = Dictionary(grouping: coordinates, by: \.jointIdentifier)
    let topology = try joints.map { joint in
      let entries = (byJoint.removeValue(forKey: joint.jointIdentifier) ?? [])
        .sorted { $0.identifier < $1.identifier }
      guard entries.count == Int(joint.coordinateCount),
        entries.enumerated().allSatisfy({ index, row in
          row.vIndex == joint.coordinateOffset + UInt32(index) && row.vIndex < 128 &&
          row.qIndex < 129
        }) else {
        throw BrainRuntimeError.invalidDescriptor("standing joint coordinate rows are inconsistent")
      }
      return try NumanXJointTopology(
        jointIdentifier: joint.jointIdentifier,
        parentBodyIdentifier: joint.parentBodyIdentifier,
        childBodyIdentifier: joint.childBodyIdentifier,
        parentLocalAnchor: joint.parentLocalAnchor,
        childLocalAnchor: joint.childLocalAnchor,
        restRelativeOrientation: joint.restRelativeOrientation,
        coordinates: entries.map { row in
          try NumanXJointCoordinateTopology(identifier: row.identifier, kind: row.kind,
            kinesthesiaReceptorIndex: row.vIndex, parentLocalAxis: row.parentLocalAxis,
            minimumPosition: row.minimumPosition, maximumPosition: row.maximumPosition,
            restPosition: row.restPosition, sourceCompliantLimit: row.sourceCompliantLimit)
        })
    }
    guard byJoint.isEmpty, Set(joints.map(\.jointIdentifier)).count == joints.count,
      channels.enumerated().allSatisfy({ $0.offset == Int($0.element.muscleIdentifier) }),
      attachments.enumerated().allSatisfy({ $0.offset == Int($0.element.muscleIdentifier) })
    else { throw BrainRuntimeError.invalidDescriptor("standing source index order is invalid") }
    if version == 3 {
      guard Set(coordinates.map(\.qIndex)).count == coordinates.count,
        coordinates.allSatisfy({ $0.qIndex >= 7 && $0.qIndex < 129 })
      else {
        throw BrainRuntimeError.invalidDescriptor(
          "standing joint-path source q indices are not unique native coordinates")
      }
    }
    let anatomy = try NumanXFullBodyAnatomy(
      jointTopologyCatalog: NumanXJointTopologyCatalog(
        numanXModelFingerprint: modelSourceFingerprint, bodyCount: bodyCount, joints: topology),
      muscleAttachmentCatalog: NumanXMuscleAttachmentCatalog(
        bodyCount: bodyCount, attachments: attachments),
      headBodyIdentifier: headBodyIdentifier)
    guard let supportEndpoints else {
      return try NumanXFullBodyTransportTemplate.compile(
        latencyMicroseconds: latencyMicroseconds, anatomy: anatomy)
    }
    let receptorIndices = Set(supportEndpoints.map(\.touchReceptorIndex))
    let sourceIdentifiers = Set(supportEndpoints.map(\.sourceEndpointIdentifier))
    guard supportEndpoints.count == 10,
      receptorIndices == Set(UInt32(0)..<10), sourceIdentifiers.count == 10,
      supportEndpoints.allSatisfy({ endpoint in
        endpoint.bodyIdentifier < bodyCount &&
        endpoint.sourceGeometryIndex != UInt32.max &&
        endpoint.sourceEndpointIdentifier != 0 &&
        endpoint.sourceEndpointIdentifier ==
          (UInt64(endpoint.bodyIdentifier) << 32 | UInt64(endpoint.sourceGeometryIndex))
      }) else {
      throw BrainRuntimeError.invalidDescriptor("standing support source mapping is invalid")
    }
    return try NumanXFullBodyTransportTemplate.compileWithSupportReceptors(
      latencyMicroseconds: latencyMicroseconds, anatomy: anatomy,
      supportEndpoints: supportEndpoints.map { endpoint in
        NumanXFullBodySupportEndpoint(
          sourceEndpointIdentifier: endpoint.sourceEndpointIdentifier,
          bodyIdentifier: endpoint.bodyIdentifier,
          touchReceptorIndex: endpoint.touchReceptorIndex)
      })
  }

  func baseline(template: CompiledSpeciesTemplate, sourceHash: String,
    epochMicroseconds: UInt64) -> MuscleLocomotorProgram {
    MuscleLocomotorProgram(modelSourceFingerprint: modelSourceFingerprint,
      sensoryProfileFingerprint: template.sensoryProfile.fingerprint,
      calibrationArtifactSHA256: sourceHash, epochMicroseconds: epochMicroseconds,
      channels: channels.map { channel in
        MuscleLocomotorChannel(muscleIdentifier: channel.muscleIdentifier,
          referenceLengthMeters: channel.referenceLengthMeters,
          tonicExcitation: channel.tonicExcitation, lengthGain: 0,
          velocityGainSeconds: 0, maximumExcitation: 1)
      })
  }
}

@available(macOS 26.0, *)
private final class StandingBridge {
  let source: StandingSource
  let template: CompiledSpeciesTemplate
  let program: MuscleLocomotorProgram
  let programFingerprint: UInt64
  let baselineProgramFingerprint: UInt64
  let publication: BrainParameterPublication
  let brain: MetalNumiBrainRuntime
  let timestepMicroseconds: UInt32
  let epochMicroseconds: UInt64
  var pending: MetalNumiBrainRuntime.ControlTransaction?
  var pendingMotor: MetalNumiBrainRuntime.BorrowedMotorCommand?
  var lastCommitFingerprint: UInt64 = 0

  init(device: any MTLDevice, sourceJSON: String, programJSON: String?,
    timestepMicroseconds: UInt32, epochMicroseconds: UInt64, seed: UInt32) throws {
    guard timestepMicroseconds > 0 && timestepMicroseconds <= 10_000 else {
      throw BrainRuntimeError.invalidDescriptor("standing timestep is invalid")
    }
    let sourceData = Data(sourceJSON.utf8)
    source = try JSONDecoder().decode(StandingSource.self, from: sourceData)
    template = try source.compile(latencyMicroseconds: timestepMicroseconds)
    let sourceHash = SHA256.hash(data: sourceData).map { String(format: "%02x", $0) }.joined()
    if let programJSON, !programJSON.isEmpty {
      program = try JSONDecoder().decode(MuscleLocomotorProgram.self, from: Data(programJSON.utf8))
      guard program.modelSourceFingerprint == source.modelSourceFingerprint,
        program.epochMicroseconds == epochMicroseconds,
        program.calibrationArtifactSHA256 == sourceHash else {
        throw BrainRuntimeError.invalidDescriptor("standing program source or physical epoch differs")
      }
    } else {
      program = source.baseline(template: template, sourceHash: sourceHash,
        epochMicroseconds: epochMicroseconds)
    }
    guard (program.version == 4 && source.version == 3 &&
        source.jointPathCalibration != nil)
      || (program.version != 4 && source.version != 3) else {
      throw BrainRuntimeError.invalidDescriptor(
        "standing joint-path program requires the version 3 prepared physical source")
    }
    try program.validate(template: template)
    // The program is immutable for this standing participant. Its canonical
    // fingerprint walks all 416 channels, so compute it at creation rather
    // than on every accepted-step ABI receipt.
    programFingerprint = program.fingerprint
    baselineProgramFingerprint = program.baselineFingerprint
    self.timestepMicroseconds = timestepMicroseconds
    self.epochMicroseconds = epochMicroseconds
    let parameters = TissueParameters.corticalSheetV0
    publication = try BrainParameterPublication.developmentalSeedV1(
      species: template.species, tissueParameters: parameters)
    let configuration = MetalNumiBrainConfiguration(
      initialTissueState: try CPUTissueDynamics.makeRestingGrid(
        width: 8, height: 8, parameters: parameters),
      tissueParameters: parameters, tissueStimulus: .none,
      compiledSpeciesTemplate: template,
      randomContext: TissueRandomContext(seed: seed,
        environmentIdentifier: 1, episodeIdentifier: 1),
      schedulerEnvironmentIdentifier: 1, maximumEncodedSubsteps: 1,
      muscleLocomotor: program,
      jointPathCalibration: program.version == 4
        ? source.jointPathCalibration : nil)
    brain = try MetalNumiBrainRuntime.makeRuntime(configuration: configuration,
      publication: publication, device: device)
  }

  func sensors(_ receptors: UnsafePointer<NBHumanStandingReceptor>?, count: UInt32,
    timestamp: UInt64) throws -> [MetalRawSensorBufferLease] {
    guard let receptors, count == 7 else {
      throw BrainRuntimeError.transaction("standing requires all seven native receptor streams")
    }
    var result: [MetalRawSensorBufferLease] = []
    var seen = Set<SensoryModality>()
    for i in 0..<Int(count) {
      let receptor = receptors[i]
      guard let modality = SensoryModality(rawValue: UInt16(exactly: receptor.modality) ?? 0),
        let expected = template.species.senses.first(where: { $0.enabled && $0.modality == modality }),
        seen.insert(modality).inserted,
        expected.receptorCount == receptor.receptor_count,
        expected.observationDimension == receptor.feature_dimension,
        receptor.receptor_timestamp_microseconds <= timestamp,
        let valuePointer = receptor.values,
        let validityPointer = receptor.validity,
        let values = Unmanaged<AnyObject>.fromOpaque(valuePointer).takeUnretainedValue() as? any MTLBuffer,
        let validity = Unmanaged<AnyObject>.fromOpaque(validityPointer).takeUnretainedValue() as? any MTLBuffer
      else { throw BrainRuntimeError.transaction("standing native receptor identity is invalid") }
      result.append(try MetalRawSensorBufferLease(buffer: values, modality: modality,
        receptorTimestamp: .init(microseconds: receptor.receptor_timestamp_microseconds),
        receptorCount: receptor.receptor_count,
        featureDimension: receptor.feature_dimension, validityBuffer: validity))
    }
    return result
  }

  func encodeMotor(encoder: any MTLComputeCommandEncoder, stepIndex: UInt32,
    receptors: UnsafePointer<NBHumanStandingReceptor>?, count: UInt32,
    muscleStates: any MTLBuffer, muscleCount: UInt32) throws {
    guard muscleCount == 416, pending == nil, stepIndex < UInt32.max,
      UInt64(stepIndex) == brain.committedGeneration,
      UInt64(stepIndex) + 1 <= (UInt64.max - epochMicroseconds) / UInt64(timestepMicroseconds) else {
      throw BrainRuntimeError.transaction("standing motor step or generation is invalid")
    }
    let committedTime = epochMicroseconds + UInt64(stepIndex) * UInt64(timestepMicroseconds)
    let targetTime = committedTime + UInt64(timestepMicroseconds)
    let input = try sensors(receptors, count: count, timestamp: committedTime)
    let transaction = try brain.beginControl(controlStepIdentifier: UInt64(stepIndex) + 1,
      basePhysicsGeneration: UInt64(stepIndex),
      committedTimestamp: .init(microseconds: committedTime),
      targetTimestamp: .init(microseconds: targetTime),
      cachedDecisionFingerprint: 0x4e554d4900000000 | UInt64(stepIndex + 1))
    pending = transaction
    do {
      let motor = try brain.encodeBorrowedMotorCommand(transaction,
        encoder: encoder, rawSensors: input)
      try brain.encodeBorrowedHumanExcitation(command: motor, encoder: encoder,
        destinationMuscleStates: muscleStates, count: 416)
      pendingMotor = motor
    } catch { throw error }
  }

  func encodeAccepted(encoder: any MTLComputeCommandEncoder,
    physicalFingerprint: UInt64, completedStepCount: UInt32,
    receptors: UnsafePointer<NBHumanStandingReceptor>?, count: UInt32) throws {
    guard let pending, let motor = pendingMotor,
      physicalFingerprint != 0,
      UInt64(completedStepCount) == brain.committedGeneration + 1 else {
      throw BrainRuntimeError.transaction("standing accepted endpoint is unpaired")
    }
    let timestamp = epochMicroseconds + UInt64(completedStepCount) * UInt64(timestepMicroseconds)
    let input = try sensors(receptors, count: count, timestamp: timestamp)
    let accepted = try AcceptedPhysicsStateToken(transaction: pending.token,
      substep: motor.substep, physicsStateFingerprint: physicalFingerprint,
      physicsGeneration: UInt64(completedStepCount))
    try brain.encodeBorrowedAcceptedConsequence(pending, encoder: encoder,
      accepted: accepted, rawSensors: input)
  }

  func publish(start: Double, end: Double) throws {
    guard let pending, start.isFinite, end.isFinite, end > start else {
      throw BrainRuntimeError.transaction("standing owner completion timing is invalid")
    }
    let commit = try brain.finishBorrowedControl(pending,
      gpuStartSeconds: start, gpuEndSeconds: end)
    lastCommitFingerprint = commit.fingerprint
    self.pending = nil
    pendingMotor = nil
  }

  func abort() throws {
    guard let pending else { return }
    try brain.abortBorrowedControl(pending)
    self.pending = nil
    pendingMotor = nil
  }
}

private func standingError(_ message: String, _ pointer: UnsafeMutablePointer<CChar>?,
  _ capacity: Int) {
  guard let pointer, capacity > 0 else { return }
  let bytes = Array(message.utf8.prefix(capacity - 1))
  for (i, byte) in bytes.enumerated() { pointer[i] = CChar(bitPattern: byte) }
  pointer[bytes.count] = 0
}

@_cdecl("nb_human_standing_create_v1")
public func nbHumanStandingCreate(_ device: UnsafeMutableRawPointer?,
  _ sourceJSON: UnsafePointer<CChar>?, _ programJSON: UnsafePointer<CChar>?,
  _ outputDirectory: UnsafePointer<CChar>?, _ timestep: UInt32, _ epoch: UInt64,
  _ seed: UInt32, _ errorBuffer: UnsafeMutablePointer<CChar>?, _ capacity: Int)
  -> UnsafeMutableRawPointer? {
  guard #available(macOS 26.0, *) else { standingError("macOS 26 required", errorBuffer, capacity); return nil }
  do {
    guard let device, let sourceJSON,
      let metalDevice = Unmanaged<AnyObject>.fromOpaque(device).takeUnretainedValue() as? any MTLDevice
    else { throw BrainRuntimeError.transaction("standing Metal device or source is missing") }
    let bridge = try StandingBridge(device: metalDevice,
      sourceJSON: String(cString: sourceJSON),
      programJSON: programJSON.map(String.init(cString:)),
      timestepMicroseconds: timestep, epochMicroseconds: epoch, seed: seed)
    return Unmanaged.passRetained(bridge).toOpaque()
  } catch { standingError(String(describing: error), errorBuffer, capacity); return nil }
}

@_cdecl("nb_human_standing_encode_motor_v1")
public func nbHumanStandingEncodeMotor(_ handle: UnsafeMutableRawPointer?,
  _ encoder: UnsafeMutableRawPointer?, _ step: UInt32,
  _ receptors: UnsafePointer<NBHumanStandingReceptor>?, _ receptorCount: UInt32,
  _ muscleStates: UnsafeMutableRawPointer?, _ muscleCount: UInt32,
  _ errorBuffer: UnsafeMutablePointer<CChar>?, _ capacity: Int) -> UInt32 {
  guard #available(macOS 26.0, *) else { standingError("macOS 26 required", errorBuffer, capacity); return 0 }
  do {
    guard let handle, let encoder, let muscleStates,
      let metalEncoder = Unmanaged<AnyObject>.fromOpaque(encoder).takeUnretainedValue() as? any MTLComputeCommandEncoder,
      let states = Unmanaged<AnyObject>.fromOpaque(muscleStates).takeUnretainedValue() as? any MTLBuffer
    else { throw BrainRuntimeError.transaction("standing motor objects are missing") }
    try Unmanaged<StandingBridge>.fromOpaque(handle).takeUnretainedValue()
      .encodeMotor(encoder: metalEncoder, stepIndex: step, receptors: receptors,
        count: receptorCount, muscleStates: states, muscleCount: muscleCount)
    return 1
  } catch { standingError(String(describing: error), errorBuffer, capacity); return 0 }
}

@_cdecl("nb_human_standing_encode_accepted_v1")
public func nbHumanStandingEncodeAccepted(_ handle: UnsafeMutableRawPointer?,
  _ encoder: UnsafeMutableRawPointer?, _ physicalFingerprint: UInt64,
  _ completedStepCount: UInt32, _ receptors: UnsafePointer<NBHumanStandingReceptor>?,
  _ receptorCount: UInt32, _ errorBuffer: UnsafeMutablePointer<CChar>?, _ capacity: Int) -> UInt32 {
  guard #available(macOS 26.0, *) else { standingError("macOS 26 required", errorBuffer, capacity); return 0 }
  do {
    guard let handle, let encoder,
      let metalEncoder = Unmanaged<AnyObject>.fromOpaque(encoder).takeUnretainedValue() as? any MTLComputeCommandEncoder
    else { throw BrainRuntimeError.transaction("standing accepted encoder is missing") }
    try Unmanaged<StandingBridge>.fromOpaque(handle).takeUnretainedValue()
      .encodeAccepted(encoder: metalEncoder, physicalFingerprint: physicalFingerprint,
        completedStepCount: completedStepCount, receptors: receptors, count: receptorCount)
    return 1
  } catch { standingError(String(describing: error), errorBuffer, capacity); return 0 }
}

@_cdecl("nb_human_standing_publish_v1")
public func nbHumanStandingPublish(_ handle: UnsafeMutableRawPointer?,
  _ start: Double, _ end: Double, _ errorBuffer: UnsafeMutablePointer<CChar>?,
  _ capacity: Int) -> UInt32 {
  guard #available(macOS 26.0, *) else { standingError("macOS 26 required", errorBuffer, capacity); return 0 }
  do {
    guard let handle else { throw BrainRuntimeError.transaction("standing handle is missing") }
    try Unmanaged<StandingBridge>.fromOpaque(handle).takeUnretainedValue().publish(start: start, end: end)
    return 1
  } catch { standingError(String(describing: error), errorBuffer, capacity); return 0 }
}

@_cdecl("nb_human_standing_abort_v1")
public func nbHumanStandingAbort(_ handle: UnsafeMutableRawPointer?,
  _ errorBuffer: UnsafeMutablePointer<CChar>?, _ capacity: Int) -> UInt32 {
  guard #available(macOS 26.0, *) else { standingError("macOS 26 required", errorBuffer, capacity); return 0 }
  do {
    guard let handle else { throw BrainRuntimeError.transaction("standing handle is missing") }
    try Unmanaged<StandingBridge>.fromOpaque(handle).takeUnretainedValue().abort()
    return 1
  } catch { standingError(String(describing: error), errorBuffer, capacity); return 0 }
}

@_cdecl("nb_human_standing_info_v1")
public func nbHumanStandingInfo(_ handle: UnsafeMutableRawPointer?,
  _ info: UnsafeMutablePointer<NBHumanStandingInfo>?) -> UInt32 {
  guard #available(macOS 26.0, *), let handle, let info else { return 0 }
  let bridge = Unmanaged<StandingBridge>.fromOpaque(handle).takeUnretainedValue()
  info.pointee.model_source_fingerprint = bridge.source.modelSourceFingerprint
  info.pointee.locomotor_program_fingerprint = bridge.programFingerprint
  info.pointee.baseline_program_fingerprint = bridge.baselineProgramFingerprint
  info.pointee.compiled_species_fingerprint = bridge.template.species.fingerprint
  info.pointee.sensory_profile_fingerprint = bridge.template.sensoryProfile.fingerprint
  info.pointee.parameter_version_fingerprint = bridge.publication.version.fingerprint
  info.pointee.committed_generation = bridge.brain.committedGeneration
  info.pointee.last_joint_commit_fingerprint = bridge.lastCommitFingerprint
  return 1
}

@_cdecl("nb_human_standing_destroy_v1")
public func nbHumanStandingDestroy(_ handle: UnsafeMutableRawPointer?) {
  guard #available(macOS 26.0, *), let handle else { return }
  Unmanaged<StandingBridge>.fromOpaque(handle).release()
}

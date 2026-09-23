import Foundation
@preconcurrency import Metal
import NumiBrainCore

@available(macOS 26.0, *)
@_spi(NumanXInterop)
public final class MetalMuscleLocomotorController: @unchecked Sendable {
  public let program: MuscleLocomotorProgram
  /// Runtime identity includes the exact prepared FP32 path calibration for
  /// v4. Earlier locomotor versions retain their historical program identity.
  public let bindingFingerprint: UInt64
  private let template: CompiledSpeciesTemplate
  private let version: UInt64
  private let channels: any MTLBuffer
  private let logits: any MTLBuffer
  private let uniforms: any MTLBuffer
  private let pipeline: any MTLComputePipelineState
  private let arguments: any MTL4ArgumentTable
  private let balanceController: MetalMuscleBalanceController?
  private let jointReferencePositions: (any MTLBuffer)?
  private let jointOptimalLengths: (any MTLBuffer)?
  private let jointPathJacobians: (any MTLBuffer)?
  private let borrowedLock = NSLock()
  private var borrowedRoot: UInt64?
  private var borrowedArenaIdentifier: ObjectIdentifier?
  private weak var borrowedArena: MetalAgentStateArena?
  var speciesFingerprint: UInt64 { template.species.fingerprint }

  public init(program: MuscleLocomotorProgram, template: CompiledSpeciesTemplate,
    parameterVersion: UInt64, device: any MTLDevice,
    jointPathCalibration: MuscleJointPathCalibration? = nil) throws {
    try program.validate(template: template)
    guard (program.version == 4) == (jointPathCalibration != nil) else {
      throw TissueError.metal("joint-path controller lacks its prepared physical calibration")
    }
    if let jointPathCalibration {
      try jointPathCalibration.validate()
      let bindings = template.sensoryProfile.jointReceptorBindings
      guard bindings.count == 2 * MuscleJointPathCalibration.dofCount,
        (Int(MuscleJointPathCalibration.firstDof)..<128).allSatisfy({ row in
          let paired = bindings.filter { $0.receptorIndex == UInt32(row) }
          return paired.count == 2 && paired.allSatisfy({
            $0.sourceModelFingerprint == program.modelSourceFingerprint &&
            $0.modality == .kinesthesia && $0.scale == 1 && $0.bias == 0 &&
            $0.weight == 1
          }) && paired.contains(where: {
            $0.signal == .position && $0.featureIndex == 0
          }) && paired.contains(where: {
            $0.signal == .velocity && $0.featureIndex == 1
          })
        }) else {
        throw TissueError.metal("joint-path calibration lacks exact native q/v receptor bindings")
      }
    }
    self.program = program
    bindingFingerprint = Self.makeBindingFingerprint(
      program: program, calibration: jointPathCalibration)
    self.template = template; version = parameterVersion
    let sense = template.species.senses.first { $0.modality == .proprioception }!
    var words: [UInt32] = []
    for c in program.channels {
      func binding(_ signal: MuscleReceptorSignal) -> MuscleReceptorBinding {
        template.sensoryProfile.muscleReceptorBindings.first {
          $0.muscleIdentifier == c.muscleIdentifier && $0.signal == signal
        }!
      }
      let l = binding(.length), v = binding(.lengthVelocity)
      guard l.receptorIndex == v.receptorIndex else {
        throw BrainRuntimeError.invalidDescriptor("spindle length and velocity must share receptor validity")
      }
      words += [l.receptorIndex * sense.observationDimension + l.featureIndex,
        v.receptorIndex * sense.observationDimension + v.featureIndex, l.receptorIndex,
        (UInt32(1) << l.featureIndex) | (UInt32(1) << v.featureIndex)]
      words += [c.referenceLengthMeters, c.tonicExcitation, c.lengthGain, c.velocityGainSeconds,
        c.gaitSine, c.gaitCosine, c.maximumExcitation, 0].map(\.bitPattern)
    }
    func upload(_ words: [UInt32]) throws -> any MTLBuffer {
      guard let b = words.withUnsafeBytes({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) }) else {
        throw TissueError.metal("locomotor allocation failed")
      }; return b
    }
    channels = try upload(words); logits = try upload([UInt32](repeating: 0, count: program.channels.count))
    uniforms = try upload([0, 0, 0, 0])
    if let jointPathCalibration {
      jointReferencePositions = try upload(jointPathCalibration.referencePositionBitsByDof)
      jointOptimalLengths = try upload(jointPathCalibration.optimalFiberLengthBitsByMuscle)
      jointPathJacobians = try upload(jointPathCalibration.lengthJacobianBitsByMuscleDof)
    } else {
      jointReferencePositions = nil
      jointOptimalLengths = nil
      jointPathJacobians = nil
    }
    let library = try Self.makeLibrary(device: device)
    let balanceController = try program.balanceFeedback.map {
      try MetalMuscleBalanceController(
        program: $0,
        locomotorProgram: program,
        template: template,
        parameterVersionFingerprint: parameterVersion,
        initialGeneration: 0,
        library: library,
        device: device
      )
    }
    let functionName = program.jointPathFeedback != nil
      ? "nb_muscle_locomotor_joint_path"
      : (program.spindleFeedbackOnsetMicroseconds != nil
        ? "nb_muscle_locomotor_delayed"
        : (balanceController == nil ? "nb_muscle_locomotor" : "nb_muscle_locomotor_balanced"))
    guard let function = library.makeFunction(name: functionName) else {
      throw TissueError.metal("locomotor kernel missing")
    }
    pipeline = try device.makeComputePipelineState(function: function)
    let descriptor = MTL4ArgumentTableDescriptor()
    descriptor.maxBufferBindCount = program.version == 4 ? 10 : 6
    descriptor.initializeBindings = true
    arguments = try device.makeArgumentTable(descriptor: descriptor)
    self.balanceController = balanceController
  }
  static func makeLibrary(device: any MTLDevice) throws -> any MTLLibrary {
    guard let url = Bundle.module.url(forResource: "MuscleLocomotor", withExtension: "metal", subdirectory: "Shaders")
      ?? Bundle.module.url(forResource: "MuscleLocomotor", withExtension: "metal") else {
      throw TissueError.metal("locomotor shader resource missing")
    }
    let options = MTLCompileOptions()
    options.languageVersion = .version4_0
    options.mathMode = .safe
    options.mathFloatingPointFunctions = .precise
    return try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: options)
  }
  public var residencyAllocations: [any MTLAllocation] {
    [channels, logits, uniforms]
      + [jointReferencePositions, jointOptimalLengths, jointPathJacobians].compactMap { $0 }
      + (balanceController?.residencyAllocations ?? [])
  }

  func encode(root: BrainJointTransactionToken, encoder: any MTL4ComputeCommandEncoder,
    rawSensors: [MetalRawSensorBufferView]) throws -> MetalDescendingMotorView {
    try encode(root: root, encoder: .metal4(encoder), rawSensors: rawSensors)
  }

  func encodeBorrowed(transaction: MetalJointAgentStateTransaction,
    arena: MetalAgentStateArena,
    encoder: any MTLComputeCommandEncoder,
    rawSensors: [MetalRawSensorBufferLease]) throws -> MetalDescendingMotorView {
    borrowedLock.lock()
    defer { borrowedLock.unlock() }
    if let identity = borrowedArenaIdentifier {
      guard identity == ObjectIdentifier(arena), borrowedArena === arena else {
        throw TissueError.transaction("borrowed muscle controller belongs to another agent-state arena")
      }
    } else {
      borrowedArenaIdentifier = ObjectIdentifier(arena)
      borrowedArena = arena
    }
    guard borrowedRoot == nil else {
      throw TissueError.transaction("borrowed muscle controller already owns an unfinished root")
    }
    borrowedRoot = transaction.jointToken.fingerprint
    return try encode(root: transaction.jointToken,
      encoder: .borrowed(encoder, sensors: rawSensors), rawSensors: rawSensors.map(\.view))
  }

  func releaseBorrowedRoot(_ root: BrainJointTransactionToken) {
    borrowedLock.lock()
    defer { borrowedLock.unlock() }
    if borrowedRoot == root.fingerprint { borrowedRoot = nil }
  }

  private func encode(root: BrainJointTransactionToken, encoder: MetalMuscleCommandEncoder,
    rawSensors: [MetalRawSensorBufferView]) throws -> MetalDescendingMotorView {
    let sense = template.species.senses.first { $0.enabled && $0.modality == .proprioception }!
    let views = rawSensors.filter { $0.modality == .proprioception }
    guard views.count == 1, let view = views.first, view.hasValidity,
      view.receptorCount == sense.receptorCount,
      view.featureDimension == sense.observationDimension,
      root.committedTimestamp.rawValue >= UInt64(sense.latencyMicroseconds),
      view.receptorTimestamp.rawValue
        == root.committedTimestamp.rawValue - UInt64(sense.latencyMicroseconds),
      root.parameterVersionFingerprint == version,
      root.committedTimestamp.rawValue >= program.epochMicroseconds else {
      throw TissueError.transaction("locomotor controller requires this root's delivered physical spindle packet")
    }
    let elapsed = root.committedTimestamp.rawValue - program.epochMicroseconds
    let phase = program.periodMicroseconds == 0 ? Float(0)
      : Float(elapsed % program.periodMicroseconds) / Float(program.periodMicroseconds) * (2 * Float.pi)
    let spindleEnabled: UInt32 = program.spindleFeedbackOnsetMicroseconds.map {
      elapsed >= $0 ? 1 : 0
    } ?? 0
    let words: [UInt32]
    if let jointPathFeedback = program.jointPathFeedback {
      words = [UInt32(program.channels.count), jointPathFeedback.lengthGain.bitPattern,
        jointPathFeedback.velocityGainSeconds.bitPattern,
        jointPathFeedback.maximumCorrection.bitPattern]
    } else {
      words = [UInt32(program.channels.count), phase.bitPattern, spindleEnabled, UInt32(0)]
    }
    words.withUnsafeBytes { uniforms.contents().copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
    let kinesthesia: MetalRawSensorBufferView?
    if program.version == 4 {
      let kinesthesiaTopology = template.species.senses.first {
        $0.enabled && $0.modality == .kinesthesia
      }
      let kinesthesiaViews = rawSensors.filter { $0.modality == .kinesthesia }
      guard kinesthesiaViews.count == 1, let view = kinesthesiaViews.first else {
        throw TissueError.transaction("joint-path controller lacks native kinesthesia")
      }
      try MetalMuscleBalanceSensorAdmission.validate(view: view,
        topology: kinesthesiaTopology, committedTimestamp: root.committedTimestamp)
      kinesthesia = view
    } else {
      kinesthesia = nil
    }
    encoder.begin()

    let balanceCandidate = try balanceController?.encodeCandidate(
      root: root,
      locomotorEpochMicroseconds: program.epochMicroseconds,
      encoder: encoder,
      rawSensors: rawSensors
    )
    if let balanceCandidate {
      try MetalMuscleBalanceParticipantRegistry.bind(
        balanceCandidate,
        to: root
      )
    }
    var addresses: [UInt64]
    if program.version == 4 {
      guard let kinesthesia,
        let jointReferencePositions, let jointOptimalLengths,
        let jointPathJacobians else {
        throw TissueError.transaction("joint-path controller lacks native kinesthesia or calibration")
      }
      addresses = [view.gpuAddress, view.validityGPUAddress,
        kinesthesia.gpuAddress, kinesthesia.validityGPUAddress,
        channels.gpuAddress, logits.gpuAddress, uniforms.gpuAddress,
        jointReferencePositions.gpuAddress, jointOptimalLengths.gpuAddress,
        jointPathJacobians.gpuAddress]
    } else {
      addresses = [view.gpuAddress, view.validityGPUAddress, channels.gpuAddress,
        logits.gpuAddress, uniforms.gpuAddress]
      if let balanceCandidate {
        addresses.append(balanceCandidate.corrections.gpuAddress)
      }
    }
    let jointBuffers = [jointReferencePositions, jointOptimalLengths,
      jointPathJacobians].compactMap { $0 }
    try encoder.dispatch(pipeline: pipeline, arguments: arguments, addresses: addresses,
      ownedBuffers: [channels, logits, uniforms] + jointBuffers
        + (balanceCandidate.map { [$0.corrections] } ?? []),
      count: program.channels.count)
    return MetalDescendingMotorView(kind: .muscleLocomotor, transactionFingerprint: root.fingerprint, shadowGeneration: root.shadowGeneration,
      speciesFingerprint: template.species.fingerprint, parameterVersionFingerprint: version,
      programFingerprint: bindingFingerprint, logits: logits, actuatorCount: program.channels.count)
  }

  private static func makeBindingFingerprint(program: MuscleLocomotorProgram,
    calibration: MuscleJointPathCalibration?) -> UInt64 {
    guard let calibration else { return program.fingerprint }
    var hash: UInt64 = 0xcbf29ce484222325
    func byte(_ value: UInt8) {
      hash = (hash ^ UInt64(value)) &* 0x100000001b3
    }
    func integer(_ value: UInt64) {
      for shift in stride(from: 0, through: 56, by: 8) {
        byte(UInt8(truncatingIfNeeded: value >> shift))
      }
    }
    for value in "NBMUSCLEJOINTPATHBINDING1".utf8 { byte(value) }
    integer(program.fingerprint)
    integer(UInt64(calibration.version))
    for values in [calibration.referencePositionBitsByDof,
      calibration.optimalFiberLengthBitsByMuscle,
      calibration.lengthJacobianBitsByMuscleDof] {
      integer(UInt64(values.count))
      for value in values { integer(UInt64(value)) }
    }
    return hash
  }
}

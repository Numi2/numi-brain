import Foundation
@preconcurrency import Metal
import NumiBrainABI
import NumiBrainCore

@available(macOS 26.0, *)
private enum MetalNumanXReadyFingerprint {
  static let offset: UInt64 = 14_695_981_039_346_656_037
  static let prime: UInt64 = 1_099_511_628_211
  static let fingerprintedByteCount = 152

  static func record<T>(_ value: T) -> UInt64 {
    withUnsafeBytes(of: value) { bytes in
      precondition(bytes.count >= fingerprintedByteCount)
      var hash = offset
      for byte in bytes.prefix(fingerprintedByteCount) {
        hash = (hash ^ UInt64(byte)) &* prime
      }
      return hash == 0 ? offset : hash
    }
  }

  static func data<T>(_ value: T) -> Data {
    withUnsafeBytes(of: value) { Data($0) }
  }
}

/// Retains the exact Brain-owned decision gate paired with a liveness event.
/// Consumers must validate the 160-byte record on the GPU; the event alone is
/// never decision authority.
@available(macOS 26.0, *)
public final class MetalNumanXDecisionReadyGateLease: @unchecked Sendable {
  public static let byteCount = Int(NB_NUMANX_DECISION_READY_GATE_BYTE_COUNT)

  public let readyPoint: MetalSharedEventPoint
  private let buffer: any MTLBuffer

  fileprivate init(
    buffer: any MTLBuffer,
    readyPoint: MetalSharedEventPoint
  ) {
    self.buffer = buffer
    self.readyPoint = readyPoint
  }

  public var gpuAddress: UInt64 { buffer.gpuAddress }

  public var metalBufferObject: UnsafeMutableRawPointer {
    Unmanaged.passUnretained(buffer as AnyObject).toOpaque()
  }
}

/// Retains the exact Brain-owned motor-ready gate paired with a liveness event.
/// A new lease is allocated for every physical attempt, including retries.
@available(macOS 26.0, *)
public final class MetalNumanXMotorReadyGateLease: @unchecked Sendable {
  public static let byteCount = Int(NB_NUMANX_MOTOR_READY_GATE_BYTE_COUNT)

  public let readyPoint: MetalSharedEventPoint
  private let buffer: any MTLBuffer

  fileprivate init(
    buffer: any MTLBuffer,
    readyPoint: MetalSharedEventPoint
  ) {
    self.buffer = buffer
    self.readyPoint = readyPoint
  }

  public var gpuAddress: UInt64 { buffer.gpuAddress }

  public var metalBufferObject: UnsafeMutableRawPointer {
    Unmanaged.passUnretained(buffer as AnyObject).toOpaque()
  }
}

@available(macOS 26.0, *)
private struct MetalNumanXDecisionRangeRecord {
  var byteOffset: UInt32
  var byteCount: UInt32
}

@available(macOS 26.0, *)
private struct MetalNumanXUncertaintyPolicyRecord {
  static let abiVersion: UInt32 = 1
  static let enabledFlag: UInt32 = 1 << 0

  var abiVersion: UInt32 = Self.abiVersion
  var flags: UInt32 = 0
  var supervisionRequestThreshold: Float = 0
  var rootRejectionThreshold: Float = 0
}

/// Host-readable qualification evidence copied from the exact fingerprinted
/// decision gate after Metal completion. It is diagnostic only and carries no
/// motor or publication authority.
@available(macOS 26.0, *)
@_spi(NumanXInterop)
public struct MetalNumanXDecisionUncertaintyObservation: Equatable, Sendable {
  public let score: Float
  public let supervisionRequestThreshold: Float
  public let rootRejectionThreshold: Float
  public let supervisionRequired: Bool
  public let rootRejected: Bool
  public let decisionGateFingerprint: UInt64
}

/// Immutable executable calibration for the pre-physical NumanX decision
/// gate. A nil foundation-policy architecture disables this Gate C boundary;
/// an admitted package must use the exact runtime-contract thresholds.
@available(macOS 26.0, *)
@_spi(NumanXInterop)
public struct MetalNumanXUncertaintyGateConfiguration: Equatable, Sendable {
  public let supervisionRequestThreshold: Float
  public let rootRejectionThreshold: Float

  init(architecture: BrainFoundationPolicyArchitecture) throws {
    guard BrainFoundationPolicyRuntimeContract.validates(architecture) else {
      throw TissueError.metal(
        "foundation-policy uncertainty calibration is not executable"
      )
    }
    self.supervisionRequestThreshold = architecture.supervisionRequestThreshold
    self.rootRejectionThreshold = architecture.rootRejectionThreshold
  }

  public init(productionRuntimeContract: Void = ()) {
    supervisionRequestThreshold =
      BrainFoundationPolicyRuntimeContract.supervisionRequestThreshold
    rootRejectionThreshold =
      BrainFoundationPolicyRuntimeContract.rootRejectionThreshold
  }

  var fingerprint: UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for value in [
      MetalNumanXUncertaintyPolicyRecord.abiVersion,
      MetalNumanXUncertaintyPolicyRecord.enabledFlag,
      supervisionRequestThreshold.bitPattern,
      rootRejectionThreshold.bitPattern,
    ] {
      for shift in stride(from: 0, to: 32, by: 8) {
        hash = (hash ^ UInt64((value >> UInt32(shift)) & 0xff))
          &* 1_099_511_628_211
      }
    }
    return hash == 0 ? 14_695_981_039_346_656_037 : hash
  }
}

@available(macOS 26.0, *)
final class MetalNumanXDecisionReadyEvaluation: @unchecked Sendable {
  static let dispatchByteCount = 272
  static let rangeTableByteOffset = 176

  let transaction: BrainJointTransactionToken
  let expected: NBNumanXDecisionReadyGateGPU
  let sourceBuffer: any MTLBuffer
  let dispatchBuffer: any MTLBuffer
  let uncertaintyPolicyBuffer: any MTLBuffer
  let gateBuffer: any MTLBuffer
  let lease: MetalNumanXDecisionReadyGateLease
  let descendingSomaticByteCount: Int
  let autonomicCommandByteCount: Int
  let activeSensingCommandByteCount: Int
  let controlHeaderSourceOffset: Int
  let uncertaintyGate: MetalNumanXUncertaintyGateConfiguration?
  private let failureRecord: Data

  init(
    device: any MTLDevice,
    commandLease: MetalEmbodiedBrainRuntime.NumanXSomaticBufferLease,
    transaction: BrainJointTransactionToken,
    readyPoint: MetalSharedEventPoint,
    compiledSpeciesTemplateFingerprint: UInt64,
    parameterVersionFingerprint: UInt64,
    regionalProgramFingerprint: UInt64,
    scheduleFingerprint: UInt64,
    brainProgramFingerprint: UInt64,
    uncertaintyGate: MetalNumanXUncertaintyGateConfiguration?
  ) throws {
    let decision = commandLease.decision
    let structuredStride = MetalEmbodiedBrainRuntime.NumanXSomaticBufferLease
      .structuredCommandStride
    let (motorCommandBytes, motorCommandOverflow) =
      decision.motorCommandCount.multipliedReportingOverflow(
        by: structuredStride
      )
    let (autonomicCommandBytes, autonomicCommandOverflow) =
      decision.autonomicCommandCount.multipliedReportingOverflow(
        by: structuredStride
      )
    let (activeSensingCommandBytes, activeSensingCommandOverflow) =
      decision.activeSensingCommandCount.multipliedReportingOverflow(
        by: structuredStride
      )
    let (receptorPayloadBytes, receptorPayloadOverflow) =
      decision.receptorEventMaximumCount.multipliedReportingOverflow(by: 32)
    let (receptorEventQueueBytes, receptorQueueOverflow) =
      receptorPayloadBytes.addingReportingOverflow(32)
    guard !motorCommandOverflow,
      !autonomicCommandOverflow,
      !activeSensingCommandOverflow,
      !receptorPayloadOverflow,
      !receptorQueueOverflow
    else {
      throw TissueError.transaction(
        "NumanX decision-ready range arithmetic overflowed"
      )
    }
    let ranges: [(Int, Int)] = [
      (commandLease.descendingBaselineSourceOffset,
       decision.descendingSomaticBaselineByteCount),
      (commandLease.maturationSourceOffset, decision.regionalMaturationByteCount),
      (commandLease.plasticModulationSourceOffset,
       decision.regionalPlasticModulationByteCount),
      (commandLease.fastPlasticitySourceOffset, decision.fastPlasticityByteCount),
      (commandLease.cpgStateSourceOffset, decision.cpgStateByteCount),
      (commandLease.reflexStateSourceOffset, decision.reflexStateByteCount),
      (commandLease.fastCerebellarStateSourceOffset,
       decision.fastCerebellarStateByteCount),
      (commandLease.motorCommandSourceOffset,
       motorCommandBytes),
      (commandLease.autonomicSourceOffset,
       autonomicCommandBytes),
      (commandLease.fastAutonomicStateSourceOffset,
       decision.fastAutonomicStateByteCount),
      (commandLease.activeSensingSourceOffset,
       activeSensingCommandBytes),
      (commandLease.receptorEventQueueSourceOffset,
       receptorEventQueueBytes),
    ]
    let exposedAddresses: [UInt64] = [
      decision.descendingSomaticBaselineGPUAddress,
      decision.regionalMaturationGPUAddress,
      decision.regionalPlasticModulationGPUAddress,
      decision.fastPlasticityGPUAddress,
      decision.cpgStateGPUAddress,
      decision.reflexStateGPUAddress,
      decision.fastCerebellarStateGPUAddress,
      decision.motorCommandGPUAddress,
      decision.autonomicCommandGPUAddress,
      decision.fastAutonomicStateGPUAddress,
      decision.activeSensingCommandGPUAddress,
      decision.receptorEventQueueGPUAddress,
    ]
    let nonemptyRanges = ranges.filter { $0.1 > 0 }.sorted { $0.0 < $1.0 }
    let rangesWithinBounds = ranges.allSatisfy { offset, count in
      offset >= 0 && count >= 0
        && offset <= commandLease.buffer.length
        && count <= commandLease.buffer.length - offset
        && offset <= Int(UInt32.max) && count <= Int(UInt32.max)
    }
    let rangesAreDisjoint = rangesWithinBounds
      && zip(nonemptyRanges, nonemptyRanges.dropFirst()).allSatisfy {
        left, right in left.0 + left.1 <= right.0
      }
    guard MemoryLayout<NBNumanXDecisionReadyGateGPU>.stride
        == MetalNumanXDecisionReadyGateLease.byteCount,
      MemoryLayout<MetalNumanXDecisionRangeRecord>.stride == 8,
      MemoryLayout<MetalNumanXUncertaintyPolicyRecord>.stride == 16,
      ranges.count == Int(NB_NUMANX_DECISION_READY_MAX_RANGES),
      transaction.fingerprint == decision.transactionFingerprint,
      transaction.shadowGeneration == decision.shadowGeneration,
      commandLease.speciesTemplateFingerprint != 0,
      compiledSpeciesTemplateFingerprint != 0,
      parameterVersionFingerprint != 0,
      regionalProgramFingerprint != 0,
      scheduleFingerprint != 0,
      brainProgramFingerprint != 0,
      commandLease.buffer.device.registryID == device.registryID,
      commandLease.controlHeaderByteOffset >= 0,
      commandLease.controlHeaderByteOffset <= commandLease.buffer.length,
      128 <= commandLease.buffer.length - commandLease.controlHeaderByteOffset,
      rangesAreDisjoint,
      ranges.enumerated().allSatisfy({ index, range in
        let (offset, count) = range
        guard offset >= 0,
          count >= 0,
          offset <= commandLease.buffer.length,
          count <= commandLease.buffer.length - offset,
          offset <= Int(UInt32.max),
          count <= Int(UInt32.max)
        else { return false }
        let (address, overflow) = commandLease.buffer.gpuAddress
          .addingReportingOverflow(UInt64(offset))
        return !overflow && address == exposedAddresses[index]
      }),
      let dispatchBuffer = device.makeBuffer(
        length: Self.dispatchByteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let uncertaintyPolicyBuffer = device.makeBuffer(
        length: MemoryLayout<MetalNumanXUncertaintyPolicyRecord>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let gateBuffer = device.makeBuffer(
        length: MetalNumanXDecisionReadyGateLease.byteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate an exact NumanX decision-ready gate")
    }
    var pending = NBNumanXDecisionReadyGateGPU()
    pending.abiVersion = UInt32(NB_NUMANX_MOTOR_READY_ABI_VERSION)
    pending.structBytes = UInt32(MetalNumanXDecisionReadyGateLease.byteCount)
    pending.status = UInt32(NB_NUMANX_READY_GATE_PENDING.rawValue)
    pending.environment = transaction.environmentIdentifier
    pending.rangeCount = UInt32(ranges.count)
    pending.flags = uncertaintyGate == nil
      ? 0 : MetalNumanXUncertaintyPolicyRecord.enabledFlag
    pending.unsupportedUncertaintyBits = 0
    pending.reserved32_1 = 0
    pending.controlStep = transaction.controlStepIdentifier
    pending.transactionFingerprint = transaction.fingerprint
    pending.shadowGeneration = transaction.shadowGeneration
    pending.decisionTimestampMicroseconds = decision.decisionTimestamp.rawValue
    pending.randomCounterGeneration = transaction.randomCounterGeneration
    pending.speciesTemplateFingerprint = commandLease.speciesTemplateFingerprint
    pending.compiledSpeciesTemplateFingerprint = compiledSpeciesTemplateFingerprint
    pending.parameterVersionFingerprint = parameterVersionFingerprint
    pending.regionalProgramFingerprint = regionalProgramFingerprint
    pending.scheduleFingerprint = scheduleFingerprint
    pending.brainProgramFingerprint = brainProgramFingerprint
    pending.decisionOutputFingerprint = 0
    pending.descendingSomaticFingerprint = 0
    pending.autonomicCommandFingerprint = 0
    pending.activeSensingCommandFingerprint = 0
    pending.gateFingerprint = MetalNumanXReadyFingerprint.record(pending)

    dispatchBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: dispatchBuffer.length
    )
    var uncertaintyPolicy = MetalNumanXUncertaintyPolicyRecord()
    if let uncertaintyGate {
      uncertaintyPolicy.flags = MetalNumanXUncertaintyPolicyRecord.enabledFlag
      uncertaintyPolicy.supervisionRequestThreshold =
        uncertaintyGate.supervisionRequestThreshold
      uncertaintyPolicy.rootRejectionThreshold =
        uncertaintyGate.rootRejectionThreshold
    }
    withUnsafeBytes(of: &uncertaintyPolicy) { bytes in
      uncertaintyPolicyBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
    withUnsafeBytes(of: &pending) { bytes in
      dispatchBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
      gateBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
    dispatchBuffer.contents().storeBytes(
      of: UInt64(commandLease.buffer.length), toByteOffset: 160, as: UInt64.self
    )
    for (index, range) in ranges.enumerated() {
      var record = MetalNumanXDecisionRangeRecord(
        byteOffset: UInt32(range.0), byteCount: UInt32(range.1)
      )
      withUnsafeBytes(of: &record) { bytes in
        dispatchBuffer.contents().advanced(
          by: Self.rangeTableByteOffset
            + index * MemoryLayout<MetalNumanXDecisionRangeRecord>.stride
        ).copyMemory(from: bytes.baseAddress!, byteCount: bytes.count)
      }
    }
    var failure = pending
    failure.status = UInt32(NB_NUMANX_READY_GATE_FAILURE.rawValue)
    failure.gateFingerprint = MetalNumanXReadyFingerprint.record(failure)
    dispatchBuffer.label = "NumiBrain NumanX decision-ready dispatch"
    uncertaintyPolicyBuffer.label = "NumiBrain NumanX uncertainty policy"
    gateBuffer.label = "NumiBrain NumanX decision-ready gate"
    self.transaction = transaction
    self.expected = pending
    self.sourceBuffer = commandLease.buffer
    self.dispatchBuffer = dispatchBuffer
    self.uncertaintyPolicyBuffer = uncertaintyPolicyBuffer
    self.gateBuffer = gateBuffer
    self.descendingSomaticByteCount =
      decision.descendingSomaticBaselineByteCount
    self.autonomicCommandByteCount = autonomicCommandBytes
    self.activeSensingCommandByteCount = activeSensingCommandBytes
    self.controlHeaderSourceOffset = commandLease.controlHeaderByteOffset
    self.uncertaintyGate = uncertaintyGate
    self.lease = MetalNumanXDecisionReadyGateLease(
      buffer: gateBuffer, readyPoint: readyPoint
    )
    self.failureRecord = MetalNumanXReadyFingerprint.data(failure)
  }

  var residencyAllocations: [any MTLAllocation] {
    [sourceBuffer, dispatchBuffer, uncertaintyPolicyBuffer, gateBuffer]
  }

  var controlHeaderGPUAddress: UInt64 {
    sourceBuffer.gpuAddress + UInt64(controlHeaderSourceOffset)
  }

  func markFailure() {
    failureRecord.withUnsafeBytes { bytes in
      gateBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
  }

  func hasValidSuccess() -> Bool {
    let record = gateBuffer.contents().load(
      as: NBNumanXDecisionReadyGateGPU.self
    )
    return record.abiVersion == expected.abiVersion
      && record.structBytes == expected.structBytes
      && record.status == UInt32(NB_NUMANX_READY_GATE_SUCCESS.rawValue)
      && record.environment == expected.environment
      && record.rangeCount == expected.rangeCount
      && record.flags == expected.flags
      && validUncertainty(record)
      && record.reserved32_1 == expected.reserved32_1
      && record.controlStep == expected.controlStep
      && record.transactionFingerprint == expected.transactionFingerprint
      && record.shadowGeneration == expected.shadowGeneration
      && record.decisionTimestampMicroseconds
        == expected.decisionTimestampMicroseconds
      && record.randomCounterGeneration == expected.randomCounterGeneration
      && record.speciesTemplateFingerprint == expected.speciesTemplateFingerprint
      && record.compiledSpeciesTemplateFingerprint
        == expected.compiledSpeciesTemplateFingerprint
      && record.parameterVersionFingerprint == expected.parameterVersionFingerprint
      && record.regionalProgramFingerprint == expected.regionalProgramFingerprint
      && record.scheduleFingerprint == expected.scheduleFingerprint
      && record.brainProgramFingerprint == expected.brainProgramFingerprint
      && record.decisionOutputFingerprint != 0
      && record.descendingSomaticFingerprint != 0
      && record.autonomicCommandFingerprint != 0
      && record.activeSensingCommandFingerprint != 0
      && record.gateFingerprint == MetalNumanXReadyFingerprint.record(record)
  }

  func hasValidTerminal() -> Bool {
    let record = gateBuffer.contents().load(
      as: NBNumanXDecisionReadyGateGPU.self
    )
    let knownFlags = MetalNumanXUncertaintyPolicyRecord.enabledFlag
      | (1 << 1) | (1 << 2)
    let baseValid = record.abiVersion == expected.abiVersion
      && record.structBytes == expected.structBytes
      && (record.status == UInt32(NB_NUMANX_READY_GATE_SUCCESS.rawValue)
        || record.status == UInt32(NB_NUMANX_READY_GATE_FAILURE.rawValue))
      && record.environment == expected.environment
      && record.rangeCount == expected.rangeCount
      && (record.flags & ~knownFlags) == 0
      && (record.flags & MetalNumanXUncertaintyPolicyRecord.enabledFlag)
        == expected.flags
      && validUncertainty(record)
      && record.reserved32_1 == 0
      && record.controlStep == expected.controlStep
      && record.transactionFingerprint == expected.transactionFingerprint
      && record.shadowGeneration == expected.shadowGeneration
      && record.decisionTimestampMicroseconds
        == expected.decisionTimestampMicroseconds
      && record.randomCounterGeneration == expected.randomCounterGeneration
      && record.speciesTemplateFingerprint == expected.speciesTemplateFingerprint
      && record.compiledSpeciesTemplateFingerprint
        == expected.compiledSpeciesTemplateFingerprint
      && record.parameterVersionFingerprint
        == expected.parameterVersionFingerprint
      && record.regionalProgramFingerprint
        == expected.regionalProgramFingerprint
      && record.scheduleFingerprint == expected.scheduleFingerprint
      && record.brainProgramFingerprint == expected.brainProgramFingerprint
      && record.gateFingerprint == MetalNumanXReadyFingerprint.record(record)
    if record.status == UInt32(NB_NUMANX_READY_GATE_SUCCESS.rawValue) {
      return baseValid && record.flags == expected.flags
        && record.decisionOutputFingerprint != 0
        && record.descendingSomaticFingerprint != 0
        && record.autonomicCommandFingerprint != 0
        && record.activeSensingCommandFingerprint != 0
    }
    return baseValid
      && record.decisionOutputFingerprint == 0
      && record.descendingSomaticFingerprint == 0
      && record.autonomicCommandFingerprint == 0
      && record.activeSensingCommandFingerprint == 0
  }

  func hasValidPolicyRejection() -> Bool {
    guard hasValidTerminal(), let uncertaintyGate else { return false }
    let record = gateBuffer.contents().load(
      as: NBNumanXDecisionReadyGateGPU.self
    )
    let supervisionFlag: UInt32 = 1 << 1
    let rejectionFlag: UInt32 = 1 << 2
    let score = Float(bitPattern: record.unsupportedUncertaintyBits)
    return record.status == UInt32(NB_NUMANX_READY_GATE_FAILURE.rawValue)
      && record.flags & supervisionFlag != 0
      && score >= uncertaintyGate.supervisionRequestThreshold
      && (record.flags & rejectionFlag != 0)
        == (score >= uncertaintyGate.rootRejectionThreshold)
  }

  func qualificationUncertaintyObservation()
    -> MetalNumanXDecisionUncertaintyObservation?
  {
    guard hasValidTerminal(), let uncertaintyGate else { return nil }
    let record = gateBuffer.contents().load(
      as: NBNumanXDecisionReadyGateGPU.self
    )
    let score = Float(bitPattern: record.unsupportedUncertaintyBits)
    return MetalNumanXDecisionUncertaintyObservation(
      score: score,
      supervisionRequestThreshold:
        uncertaintyGate.supervisionRequestThreshold,
      rootRejectionThreshold: uncertaintyGate.rootRejectionThreshold,
      supervisionRequired: record.flags & (1 << 1) != 0,
      rootRejected: record.flags & (1 << 2) != 0,
      decisionGateFingerprint: record.gateFingerprint
    )
  }

  private func validUncertainty(
    _ record: NBNumanXDecisionReadyGateGPU
  ) -> Bool {
    guard let uncertaintyGate else {
      return record.unsupportedUncertaintyBits == 0
    }
    let score = Float(bitPattern: record.unsupportedUncertaintyBits)
    guard score.isFinite, score >= 0, score <= 1 else { return false }
    let supervisionFlag: UInt32 = 1 << 1
    let rejectionFlag: UInt32 = 1 << 2
    let supervision = score >= uncertaintyGate.supervisionRequestThreshold
    let rejection = score >= uncertaintyGate.rootRejectionThreshold
    return (record.flags & supervisionFlag != 0) == supervision
      && (record.flags & rejectionFlag != 0) == rejection
  }
}

@available(macOS 26.0, *)
final class MetalNumanXMotorReadyEvaluation: @unchecked Sendable {
  let candidate: NumanXMotorCandidate
  let expected: NBNumanXMotorReadyGateGPU
  let expectedBuffer: any MTLBuffer
  let candidateBuffer: any MTLBuffer
  let gateBuffer: any MTLBuffer
  let lease: MetalNumanXMotorReadyGateLease
  let decisionEvaluation: MetalNumanXDecisionReadyEvaluation
  private let failureRecord: Data

  init(
    device: any MTLDevice,
    candidate: NumanXMotorCandidate,
    substep: BrainJointSubstepToken,
    transaction: BrainJointTransactionToken,
    decisionEvaluation: MetalNumanXDecisionReadyEvaluation,
    readyPoint: MetalSharedEventPoint,
    brainProgramFingerprint: UInt64,
    fastProgramFingerprint: UInt64
  ) throws {
    guard MemoryLayout<NBNumanXMotorReadyGateGPU>.stride
        == MetalNumanXMotorReadyGateLease.byteCount,
      MemoryLayout<NBNumanXMotorCandidate>.stride == NumanXMotorCandidate.byteCount,
      candidate.transactionFingerprint == transaction.fingerprint,
      candidate.substepFingerprint == substep.fingerprint,
      candidate.usesDecisionShadow,
      substep.substepIndex == 0,
      candidate.brainGeneration == transaction.shadowGeneration,
      candidate.environmentIdentifier == transaction.environmentIdentifier,
      candidate.speciesTemplateFingerprint
        == decisionEvaluation.expected.speciesTemplateFingerprint,
      candidate.compiledSpeciesTemplateFingerprint
        == decisionEvaluation.expected.compiledSpeciesTemplateFingerprint,
      brainProgramFingerprint == decisionEvaluation.expected.brainProgramFingerprint,
      fastProgramFingerprint != 0,
      let expectedBuffer = device.makeBuffer(
        length: MetalNumanXMotorReadyGateLease.byteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let candidateBuffer = device.makeBuffer(
        length: NumanXMotorCandidate.byteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let gateBuffer = device.makeBuffer(
        length: MetalNumanXMotorReadyGateLease.byteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate an exact NumanX motor-ready gate")
    }
    var pending = NBNumanXMotorReadyGateGPU()
    pending.abiVersion = UInt32(NB_NUMANX_MOTOR_READY_ABI_VERSION)
    pending.structBytes = UInt32(MetalNumanXMotorReadyGateLease.byteCount)
    pending.status = UInt32(NB_NUMANX_READY_GATE_PENDING.rawValue)
    pending.environment = transaction.environmentIdentifier
    pending.substepIndex = substep.substepIndex
    pending.attemptIndex = substep.attemptIndex
    pending.muscleCount = candidate.muscleCount
    pending.actuatorCommandKind = UInt32(candidate.actuatorCommandKind.rawValue)
    pending.controlStep = transaction.controlStepIdentifier
    pending.transactionFingerprint = transaction.fingerprint
    pending.substepFingerprint = substep.fingerprint
    pending.candidateFingerprint = candidate.fingerprint
    pending.motorOutputFingerprint = 0
    pending.motorProfileFingerprint = candidate.motorProfileFingerprint
    pending.brainGeneration = candidate.brainGeneration
    pending.acceptedBrainTimestampMicroseconds = candidate.acceptedBrainTimestamp.rawValue
    pending.randomCounterGeneration = candidate.randomCounterGeneration
    pending.speciesTemplateFingerprint = candidate.speciesTemplateFingerprint
    pending.compiledSpeciesTemplateFingerprint =
      candidate.compiledSpeciesTemplateFingerprint
    pending.brainProgramFingerprint = brainProgramFingerprint
    pending.fastProgramFingerprint = fastProgramFingerprint
    pending.decisionGateFingerprint = 0
    pending.reserved64_0 = 0
    pending.gateFingerprint = MetalNumanXReadyFingerprint.record(pending)
    var candidateRecord = candidate.abiRecord
    withUnsafeBytes(of: &pending) { bytes in
      expectedBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
      gateBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
    withUnsafeBytes(of: &candidateRecord) { bytes in
      candidateBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
    var failure = pending
    failure.status = UInt32(NB_NUMANX_READY_GATE_FAILURE.rawValue)
    failure.gateFingerprint = MetalNumanXReadyFingerprint.record(failure)
    expectedBuffer.label = "NumiBrain NumanX motor-ready expectation"
    candidateBuffer.label = "NumiBrain NumanX motor candidate identity"
    gateBuffer.label = "NumiBrain NumanX motor-ready gate"
    self.candidate = candidate
    self.expected = pending
    self.expectedBuffer = expectedBuffer
    self.candidateBuffer = candidateBuffer
    self.gateBuffer = gateBuffer
    self.lease = MetalNumanXMotorReadyGateLease(
      buffer: gateBuffer, readyPoint: readyPoint
    )
    self.decisionEvaluation = decisionEvaluation
    self.failureRecord = MetalNumanXReadyFingerprint.data(failure)
  }

  var residencyAllocations: [any MTLAllocation] {
    [expectedBuffer, candidateBuffer, gateBuffer]
      + decisionEvaluation.residencyAllocations
  }

  func markFailure() {
    failureRecord.withUnsafeBytes { bytes in
      gateBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
  }

  func hasValidSuccess() -> Bool {
    let record = gateBuffer.contents().load(as: NBNumanXMotorReadyGateGPU.self)
    let decision = decisionEvaluation.gateBuffer.contents().load(
      as: NBNumanXDecisionReadyGateGPU.self
    )
    return decisionEvaluation.hasValidSuccess()
      && record.abiVersion == expected.abiVersion
      && record.structBytes == expected.structBytes
      && record.status == UInt32(NB_NUMANX_READY_GATE_SUCCESS.rawValue)
      && record.environment == expected.environment
      && record.substepIndex == expected.substepIndex
      && record.attemptIndex == expected.attemptIndex
      && record.muscleCount == expected.muscleCount
      && record.actuatorCommandKind == expected.actuatorCommandKind
      && record.controlStep == expected.controlStep
      && record.transactionFingerprint == expected.transactionFingerprint
      && record.substepFingerprint == expected.substepFingerprint
      && record.candidateFingerprint == expected.candidateFingerprint
      && record.motorOutputFingerprint != 0
      && record.motorProfileFingerprint == expected.motorProfileFingerprint
      && record.brainGeneration == expected.brainGeneration
      && record.acceptedBrainTimestampMicroseconds
        == expected.acceptedBrainTimestampMicroseconds
      && record.randomCounterGeneration == expected.randomCounterGeneration
      && record.speciesTemplateFingerprint == expected.speciesTemplateFingerprint
      && record.compiledSpeciesTemplateFingerprint
        == expected.compiledSpeciesTemplateFingerprint
      && record.brainProgramFingerprint == expected.brainProgramFingerprint
      && record.fastProgramFingerprint == expected.fastProgramFingerprint
      && record.decisionGateFingerprint == decision.gateFingerprint
      && record.reserved64_0 == 0
      && record.gateFingerprint == MetalNumanXReadyFingerprint.record(record)
  }

  func hasValidPolicyRejection() -> Bool {
    let record = gateBuffer.contents().load(as: NBNumanXMotorReadyGateGPU.self)
    return decisionEvaluation.hasValidPolicyRejection()
      && record.abiVersion == expected.abiVersion
      && record.structBytes == expected.structBytes
      && record.status == UInt32(NB_NUMANX_READY_GATE_FAILURE.rawValue)
      && record.environment == expected.environment
      && record.substepIndex == expected.substepIndex
      && record.attemptIndex == expected.attemptIndex
      && record.muscleCount == expected.muscleCount
      && record.actuatorCommandKind == expected.actuatorCommandKind
      && record.controlStep == expected.controlStep
      && record.transactionFingerprint == expected.transactionFingerprint
      && record.substepFingerprint == expected.substepFingerprint
      && record.candidateFingerprint == expected.candidateFingerprint
      && record.motorOutputFingerprint == 0
      && record.motorProfileFingerprint == expected.motorProfileFingerprint
      && record.brainGeneration == expected.brainGeneration
      && record.acceptedBrainTimestampMicroseconds
        == expected.acceptedBrainTimestampMicroseconds
      && record.randomCounterGeneration == expected.randomCounterGeneration
      && record.speciesTemplateFingerprint == expected.speciesTemplateFingerprint
      && record.compiledSpeciesTemplateFingerprint
        == expected.compiledSpeciesTemplateFingerprint
      && record.brainProgramFingerprint == expected.brainProgramFingerprint
      && record.fastProgramFingerprint == expected.fastProgramFingerprint
      && record.decisionGateFingerprint == 0
      && record.reserved64_0 == 0
      && record.gateFingerprint == MetalNumanXReadyFingerprint.record(record)
  }
}

@available(macOS 26.0, *)
final class MetalNumanXMotorReadyRuntime {
  private struct BoundBufferRange {
    let name: String
    let lowerBound: UInt64
    let upperBound: UInt64
  }

  private let deviceRegistryID: UInt64
  private let decisionPipeline: any MTLComputePipelineState
  private let motorPipeline: any MTLComputePipelineState
  private let decisionArguments: any MTL4ArgumentTable
  private let motorArguments: any MTL4ArgumentTable

  init(device: any MTLDevice) throws {
    guard let sourceURL = Bundle.module.url(
      forResource: "NumanXMotorReady",
      withExtension: "metal",
      subdirectory: "Shaders"
    ) ?? Bundle.module.url(
      forResource: "NumanXMotorReady", withExtension: "metal"
    ) else {
      throw TissueError.metal("NumanXMotorReady.metal is missing")
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
      throw TissueError.metal("NumanX motor-ready Metal compilation failed: \(error)")
    }
    guard let decisionFunction = library.makeFunction(
      name: "numanx_publish_decision_ready"
    ), let motorFunction = library.makeFunction(
      name: "numanx_publish_motor_ready"
    ) else {
      throw TissueError.metal("NumanX motor-ready kernels are missing")
    }
    do {
      decisionPipeline = try device.makeComputePipelineState(
        function: decisionFunction
      )
      motorPipeline = try device.makeComputePipelineState(function: motorFunction)
    } catch {
      throw TissueError.metal("NumanX motor-ready pipeline creation failed: \(error)")
    }
    let decisionDescriptor = MTL4ArgumentTableDescriptor()
    decisionDescriptor.label = "NumiBrain NumanX decision-ready arguments"
    decisionDescriptor.maxBufferBindCount = 5
    decisionDescriptor.initializeBindings = true
    let motorDescriptor = MTL4ArgumentTableDescriptor()
    motorDescriptor.label = "NumiBrain NumanX motor-ready arguments"
    motorDescriptor.maxBufferBindCount = 14
    motorDescriptor.initializeBindings = true
    guard let decisionArguments = try? device.makeArgumentTable(
      descriptor: decisionDescriptor
    ), let motorArguments = try? device.makeArgumentTable(
      descriptor: motorDescriptor
    ) else {
      throw TissueError.metal("failed to allocate NumanX motor-ready arguments")
    }
    self.decisionArguments = decisionArguments
    self.motorArguments = motorArguments
    self.deviceRegistryID = device.registryID
  }

  private func validateMotorBindings(
    evaluation: MetalNumanXMotorReadyEvaluation,
    buffers: MetalTissueRuntime.NumanXMotorBufferLease,
    descendingSomaticBuffer: any MTLBuffer,
    descendingAutonomicBuffer: any MTLBuffer
  ) throws {
    let candidate = evaluation.candidate
    let decision = evaluation.decisionEvaluation
    let headerBytes = Int(candidate.motorOutputHeaderByteCount)
    let excitationBytes = Int(candidate.muscleExcitationByteCount)
    let autonomicBytes = Int(candidate.autonomicCommandByteCount)
    let activeSensingBytes = Int(candidate.activeSensingCommandByteCount)
    let muscleBytes = UInt64(candidate.muscleCount) * 4
    let autonomicCountBytes = UInt64(candidate.autonomicCommandCount) * 16
    let activeSensingCountBytes = UInt64(candidate.activeSensingCommandCount) * 16
    let exactBuffers: [(String, any MTLBuffer, Int, UInt64?, Bool)] = [
      ("motor header", buffers.headerBuffer, headerBytes,
       candidate.motorOutputHeaderGPUAddress, true),
      ("muscle commands", buffers.excitationBuffer, excitationBytes,
       candidate.muscleExcitationGPUAddress, true),
      ("descending somatic", descendingSomaticBuffer, excitationBytes, nil, true),
      ("descending autonomic", descendingAutonomicBuffer, autonomicBytes, nil,
       false),
      ("autonomic output", buffers.autonomicBuffer, autonomicBytes,
       candidate.autonomicCommandGPUAddress, false),
      ("active-sensing output", buffers.activeSensingBuffer,
       activeSensingBytes, candidate.activeSensingCommandGPUAddress, false),
      ("motor expectation", evaluation.expectedBuffer,
       MetalNumanXMotorReadyGateLease.byteCount, nil, true),
      ("motor candidate", evaluation.candidateBuffer,
       NumanXMotorCandidate.byteCount, nil, true),
      ("decision source", decision.sourceBuffer,
       decision.sourceBuffer.length, nil, true),
      ("decision dispatch", decision.dispatchBuffer,
       MetalNumanXDecisionReadyEvaluation.dispatchByteCount, nil, true),
      ("uncertainty policy", decision.uncertaintyPolicyBuffer,
       MemoryLayout<MetalNumanXUncertaintyPolicyRecord>.stride, nil, true),
      ("decision gate", decision.gateBuffer,
       MetalNumanXDecisionReadyGateLease.byteCount, nil, true),
      ("motor gate", evaluation.gateBuffer,
       MetalNumanXMotorReadyGateLease.byteCount, nil, true),
    ]
    guard headerBytes == MemoryLayout<NBMotorOutputHeader>.stride,
      muscleBytes == UInt64(candidate.muscleExcitationByteCount),
      autonomicCountBytes == UInt64(candidate.autonomicCommandByteCount),
      activeSensingCountBytes == UInt64(candidate.activeSensingCommandByteCount),
      excitationBytes == decision.descendingSomaticByteCount,
      autonomicBytes == decision.autonomicCommandByteCount,
      activeSensingBytes == decision.activeSensingCommandByteCount,
      buffers.output.headerGPUAddress == candidate.motorOutputHeaderGPUAddress,
      buffers.output.muscleExcitationGPUAddress
        == candidate.muscleExcitationGPUAddress,
      buffers.output.headerByteCount == headerBytes,
      buffers.output.muscleExcitationByteCount == excitationBytes,
      buffers.output.muscleCount == Int(candidate.muscleCount),
      buffers.output.profileFingerprint == candidate.motorProfileFingerprint,
      buffers.output.actuatorCommandKind == candidate.actuatorCommandKind
    else {
      throw TissueError.transaction(
        "NumanX motor buffers do not match the immutable candidate"
      )
    }
    var ranges: [BoundBufferRange] = []
    ranges.reserveCapacity(exactBuffers.count)
    for (name, buffer, byteCount, expectedAddress, requiresExactLength)
      in exactBuffers
    {
      guard byteCount >= 0 else {
        throw TissueError.transaction("NumanX \(name) byte count is negative")
      }
      let (upperBound, overflow) = buffer.gpuAddress.addingReportingOverflow(
        UInt64(byteCount)
      )
      guard buffer.device.registryID == deviceRegistryID,
        buffer.length >= byteCount,
        !requiresExactLength || buffer.length == byteCount,
        expectedAddress == nil || buffer.gpuAddress == expectedAddress!,
        !overflow,
        upperBound >= buffer.gpuAddress
      else {
        throw TissueError.transaction(
          "NumanX \(name) buffer has stale identity, device, or bounds"
        )
      }
      if byteCount > 0 {
        ranges.append(
          BoundBufferRange(
            name: name,
            lowerBound: buffer.gpuAddress,
            upperBound: upperBound
          )
        )
      }
    }
    for index in ranges.indices {
      for otherIndex in ranges.indices where otherIndex > index {
        let left = ranges[index]
        let right = ranges[otherIndex]
        guard left.upperBound <= right.lowerBound
            || right.upperBound <= left.lowerBound
        else {
          throw TissueError.transaction(
            "NumanX \(left.name) and \(right.name) buffers overlap"
          )
        }
      }
    }
  }

  func makeDecisionEvaluation(
    device: any MTLDevice,
    commandLease: MetalEmbodiedBrainRuntime.NumanXSomaticBufferLease,
    transaction: BrainJointTransactionToken,
    readyPoint: MetalSharedEventPoint,
    compiledSpeciesTemplateFingerprint: UInt64,
    parameterVersionFingerprint: UInt64,
    regionalProgramFingerprint: UInt64,
    scheduleFingerprint: UInt64,
    brainProgramFingerprint: UInt64,
    uncertaintyGate: MetalNumanXUncertaintyGateConfiguration?
  ) throws -> MetalNumanXDecisionReadyEvaluation {
    try MetalNumanXDecisionReadyEvaluation(
      device: device,
      commandLease: commandLease,
      transaction: transaction,
      readyPoint: readyPoint,
      compiledSpeciesTemplateFingerprint: compiledSpeciesTemplateFingerprint,
      parameterVersionFingerprint: parameterVersionFingerprint,
      regionalProgramFingerprint: regionalProgramFingerprint,
      scheduleFingerprint: scheduleFingerprint,
      brainProgramFingerprint: brainProgramFingerprint,
      uncertaintyGate: uncertaintyGate
    )
  }

  func makeMotorEvaluation(
    device: any MTLDevice,
    candidate: NumanXMotorCandidate,
    substep: BrainJointSubstepToken,
    transaction: BrainJointTransactionToken,
    decisionEvaluation: MetalNumanXDecisionReadyEvaluation,
    readyPoint: MetalSharedEventPoint,
    brainProgramFingerprint: UInt64,
    fastProgramFingerprint: UInt64
  ) throws -> MetalNumanXMotorReadyEvaluation {
    try MetalNumanXMotorReadyEvaluation(
      device: device,
      candidate: candidate,
      substep: substep,
      transaction: transaction,
      decisionEvaluation: decisionEvaluation,
      readyPoint: readyPoint,
      brainProgramFingerprint: brainProgramFingerprint,
      fastProgramFingerprint: fastProgramFingerprint
    )
  }

  func makeResidencySet(
    device: any MTLDevice,
    label: String,
    allocations: [any MTLAllocation]
  ) throws -> any MTLResidencySet {
    let descriptor = MTLResidencySetDescriptor()
    descriptor.label = label
    descriptor.initialCapacity = allocations.count
    let set: any MTLResidencySet
    do {
      set = try device.makeResidencySet(descriptor: descriptor)
    } catch {
      throw TissueError.metal("failed to retain \(label): \(error)")
    }
    for allocation in allocations { set.addAllocation(allocation) }
    set.commit()
    set.requestResidency()
    return set
  }

  func encodeDecision(
    encoder: any MTL4ComputeCommandEncoder,
    evaluation: MetalNumanXDecisionReadyEvaluation
  ) {
    decisionArguments.setAddress(evaluation.dispatchBuffer.gpuAddress, index: 0)
    decisionArguments.setAddress(evaluation.sourceBuffer.gpuAddress, index: 1)
    decisionArguments.setAddress(evaluation.gateBuffer.gpuAddress, index: 2)
    decisionArguments.setAddress(evaluation.controlHeaderGPUAddress, index: 3)
    decisionArguments.setAddress(
      evaluation.uncertaintyPolicyBuffer.gpuAddress, index: 4
    )
    encoder.setComputePipelineState(decisionPipeline)
    encoder.setArgumentTable(decisionArguments)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
  }

  func encodeMotor(
    encoder: any MTL4ComputeCommandEncoder,
    evaluation: MetalNumanXMotorReadyEvaluation,
    buffers: MetalTissueRuntime.NumanXMotorBufferLease,
    descendingSomaticBuffer: any MTLBuffer,
    descendingAutonomicBuffer: any MTLBuffer
  ) throws {
    try validateMotorBindings(
      evaluation: evaluation,
      buffers: buffers,
      descendingSomaticBuffer: descendingSomaticBuffer,
      descendingAutonomicBuffer: descendingAutonomicBuffer
    )
    motorArguments.setAddress(evaluation.expectedBuffer.gpuAddress, index: 0)
    motorArguments.setAddress(evaluation.candidateBuffer.gpuAddress, index: 1)
    motorArguments.setAddress(
      evaluation.decisionEvaluation.dispatchBuffer.gpuAddress, index: 2
    )
    motorArguments.setAddress(
      evaluation.decisionEvaluation.gateBuffer.gpuAddress, index: 3
    )
    motorArguments.setAddress(
      evaluation.decisionEvaluation.sourceBuffer.gpuAddress, index: 4
    )
    motorArguments.setAddress(buffers.headerBuffer.gpuAddress, index: 5)
    motorArguments.setAddress(buffers.excitationBuffer.gpuAddress, index: 6)
    motorArguments.setAddress(descendingSomaticBuffer.gpuAddress, index: 7)
    motorArguments.setAddress(descendingAutonomicBuffer.gpuAddress, index: 8)
    motorArguments.setAddress(buffers.autonomicBuffer.gpuAddress, index: 9)
    motorArguments.setAddress(buffers.activeSensingBuffer.gpuAddress, index: 10)
    motorArguments.setAddress(evaluation.gateBuffer.gpuAddress, index: 11)
    motorArguments.setAddress(
      evaluation.decisionEvaluation.controlHeaderGPUAddress, index: 12
    )
    motorArguments.setAddress(
      evaluation.decisionEvaluation.uncertaintyPolicyBuffer.gpuAddress,
      index: 13
    )
    encoder.setComputePipelineState(motorPipeline)
    encoder.setArgumentTable(motorArguments)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
  }
}

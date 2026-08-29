import Foundation
@preconcurrency import Metal
import NumiBrainABI
import NumiBrainCore

private struct ProtectiveCommandUniforms {
  var brainGeneration: UInt64 = 0
  var motorProfileFingerprint: UInt64 = 0
  var moduleCount: UInt32 = 0
  var muscleCount: UInt32 = 0
  var environmentIdentifier: UInt32 = 0
  var reserved: UInt32 = 0
}

private struct FastCPGUniforms {
  var sampleTimestampMicroseconds: UInt64 = 0
  var oscillatorCount: UInt32 = 0
  var synergyCount: UInt32 = 0
  var flags: UInt32 = 0
  var reflexRuleCount: UInt32 = 0
}

private struct FastReflexRule {
  var receptorIdentifier: UInt32 = 0
  var actuatorIdentifier: UInt32 = 0
  var circuitIdentifier: UInt32 = 0
  var circuitKind: UInt32 = 0
  var latencyMicroseconds: UInt32 = 0
  var flags: UInt32 = 0
  var activationThreshold: Float = 0
  var gain: Float = 0
}

private struct FastAutonomicUniforms {
  var sampleTimestampMicroseconds: UInt64 = 0
  var baselineTimestampMicroseconds: UInt64 = 0
  var channelCount: UInt32 = 0
  var flags: UInt32 = 0
  var vitalGain: Float = 0
  var responseTimeMicroseconds: UInt32 = 50_000
  var criticalDecayMicroseconds: UInt32 = 500_000
  var oscillatorCount: UInt32 = 0
}

private struct FastAutonomicChannelDescriptor {
  var channelIdentifier: UInt32 = 0
  var kind: UInt32 = 0
  var flags: UInt32 = 0
  var criticalReceptorCount: UInt32 = 0
  var criticalReceptor0: UInt32 = 0
  var criticalReceptor1: UInt32 = 0
  var criticalReceptor2: UInt32 = 0
  var criticalReceptor3: UInt32 = 0
  var emergencyTarget: Float = 0
  var emergencyGain: Float = 0
  var cpgGain: Float = 0
  var reserved: Float = 0
}

private struct SomaticActuatorDescriptor {
  var actuatorIdentifier: UInt32 = 0
  var commandKind: UInt32 = 0
  var flags: UInt32 = 0
  var reserved: UInt32 = 0
  var outputMinimum: Float = 0
  var outputMaximum: Float = 1
  var neutralCommand: Float = 0
  var emergencyCommand: Float = 0
}

private struct BodyLoadFieldUniforms {
  var attachmentCatalogFingerprint: UInt64 = 0
  var bodyCount: UInt32 = 0
  var updateCount: UInt32 = 0
  var targetTimestampMicroseconds: UInt64 = 0
  var persistenceMicroseconds: UInt32 = 0
  var decayMicroseconds: UInt32 = 0
}

private struct BodyLoadFieldRecord {
  var bodyIdentifier: UInt32 = 0
  var endpointRole: UInt32 = 0
  var sourceMuscleIdentifier: UInt32 = 0
  var maximumAbsoluteMuscleForce: Float = 0
  var acceptedTimestampMicroseconds: UInt64 = 0
  var acceptedPhysicsStateFingerprint: UInt64 = 0
  var effectiveAbsoluteMuscleForce: Float = 0
  var reserved: UInt32 = 0
  var fieldActivationTimestampMicroseconds: UInt64 = 0
  var fieldStateTimestampMicroseconds: UInt64 = 0

  init() {}

  init(cell: BodyLoadFieldCell) {
    bodyIdentifier = cell.bodyIdentifier
    endpointRole = cell.endpointRole.rawValue
    sourceMuscleIdentifier = cell.sourceMuscleIdentifier
    maximumAbsoluteMuscleForce = cell.maximumAbsoluteMuscleForce
    acceptedTimestampMicroseconds = cell.acceptedTimestamp.rawValue
    acceptedPhysicsStateFingerprint = cell.acceptedPhysicsStateFingerprint
    effectiveAbsoluteMuscleForce = cell.effectiveAbsoluteMuscleForce
    fieldActivationTimestampMicroseconds = cell.fieldActivationTimestamp.rawValue
    fieldStateTimestampMicroseconds = cell.fieldStateTimestamp.rawValue
  }

  func value() throws -> BodyLoadFieldCell? {
    guard endpointRole != 0 else { return nil }
    return try BodyLoadFieldCell(
      bodyIdentifier: bodyIdentifier,
      endpointRole: BodyLoadEndpointRole(rawValue: endpointRole),
      sourceMuscleIdentifier: sourceMuscleIdentifier,
      maximumAbsoluteMuscleForce: maximumAbsoluteMuscleForce,
      acceptedTimestamp: BrainTimestamp(microseconds: acceptedTimestampMicroseconds),
      acceptedPhysicsStateFingerprint: acceptedPhysicsStateFingerprint,
      effectiveAbsoluteMuscleForce: effectiveAbsoluteMuscleForce,
      fieldActivationTimestamp: BrainTimestamp(
        microseconds: fieldActivationTimestampMicroseconds
      ),
      fieldStateTimestamp: BrainTimestamp(
        microseconds: fieldStateTimestampMicroseconds
      )
    )
  }
}

private struct BodySchemaUniforms {
  var bodyCount: UInt32 = 0
  var reserved0: UInt32 = 0
  var targetTimestampMicroseconds: UInt64 = 0
  var forceScaleNewtons: Float = 0
  var loadTimeConstantMicroseconds: UInt32 = 0
  var initialVariance: Float = 0
  var maximumVariance: Float = 0
  var processVariancePerSecond: Float = 0
  var observationVariance: Float = 0
  var vulnerabilityGainPerSecond: Float = 0
  var recoveryPerSecond: Float = 0
  var uncertaintyRiskWeight: Float = 0
  var reserved1: Float = 0
}

private struct BodySchemaRecord {
  static let noObservation = UInt64.max

  var bodyIdentifier: UInt32 = 0
  var flags: UInt32 = 0
  var sourceMuscleIdentifier: UInt32 = UInt32.max
  var endpointRole: UInt32 = 0
  var estimatedAbsoluteLoad: Float = 0
  var epistemicVariance: Float = 0
  var vulnerability: Float = 0
  var damageRisk: Float = 0
  var lastObservationTimestampMicroseconds: UInt64 = noObservation
  var stateTimestampMicroseconds: UInt64 = 0

  init() {}

  init(cell: BodySchemaPosteriorCell) {
    bodyIdentifier = cell.bodyIdentifier
    flags = cell.flags.rawValue
    sourceMuscleIdentifier = cell.sourceMuscleIdentifier
    endpointRole = cell.endpointRole.rawValue
    estimatedAbsoluteLoad = cell.estimatedAbsoluteLoad
    epistemicVariance = cell.epistemicVariance
    vulnerability = cell.vulnerability
    damageRisk = cell.damageRisk
    lastObservationTimestampMicroseconds =
      cell.lastObservationTimestamp?.rawValue ?? Self.noObservation
    stateTimestampMicroseconds = cell.stateTimestamp.rawValue
  }

  func value() throws -> BodySchemaPosteriorCell {
    try BodySchemaPosteriorCell(
      bodyIdentifier: bodyIdentifier,
      flags: BodySchemaFlags(rawValue: flags),
      sourceMuscleIdentifier: sourceMuscleIdentifier,
      endpointRole: BodyLoadEndpointRole(rawValue: endpointRole),
      estimatedAbsoluteLoad: estimatedAbsoluteLoad,
      epistemicVariance: epistemicVariance,
      vulnerability: vulnerability,
      damageRisk: damageRisk,
      lastObservationTimestamp: lastObservationTimestampMicroseconds == Self.noObservation
        ? nil
        : BrainTimestamp(microseconds: lastObservationTimestampMicroseconds),
      stateTimestamp: BrainTimestamp(microseconds: stateTimestampMicroseconds)
    )
  }
}

private struct MuscleAttachmentRecord {
  var muscleIdentifier: UInt32 = UInt32.max
  var firstBodyIdentifier: UInt32 = UInt32.max
  var terminalBodyIdentifier: UInt32 = UInt32.max
  var reserved: UInt32 = 0
}

private struct TissueRegionalMaturationRecord {
  var moduleIdentifier: UInt32 = 0
  var unlocked: UInt32 = 1
  var learningRateMultiplier: Float = 1
  var timescaleMultiplier: Float = 1
  var routeGainMultiplier: Float = 1
  var conductionDelayMultiplier: Float = 1
  var capacityFraction: Float = 1
  var flags: UInt32 = 1
}

private struct TissueRegionalPlasticModulationRecord {
  var moduleIdentifier: UInt32 = 0
  var coefficientCount: UInt32 = 0
  var recurrentDelta: Float = 0
  var localDelta: Float = 0
  var routeDelta: Float = 0
  var driveDelta: Float = 0
  var gateDelta: Float = 0
  var flags: UInt32 = 0
}

@available(macOS 26.0, *)
public final class MetalTissueRuntime: @unchecked Sendable {
  static let maximumFastCPGOscillatorCount = 64
  static let fastCPGStateStride = 64
  static let maximumFastReflexRuleCount = 4_096
  static let fastReflexRuleStride = 32
  static let fastReflexStateStride = 128
  static let fastCerebellarStateStride = 64
  static let motorCommandStride = 32
  static let fastAutonomicStateStride = 64
  static let autonomicCommandStride = 16
  static let maximumFastAutonomicChannelCount = 64
  static let fastAutonomicChannelDescriptorStride = 48
  static let activeSensingCommandStride = 16
  static let maximumActiveSensingChannelCount = 64
  static let cognitiveEventRecordStride = 32
  static let cognitiveEventQueueHeaderStride = 32
  static let maximumCognitiveEventCount =
    MetalAgentStateLayout.defaultEventTokenCapacity

  final class AcceptedFastMotorStateLease: @unchecked Sendable {
    let transactionFingerprint: UInt64
    let acceptedTimestamp: BrainTimestamp
    let oscillatorCount: Int
    let byteCount: Int
    let cpgBuffer: any MTLBuffer
    let reflexRuleCount: Int
    let reflexStateByteCount: Int
    let reflexStateBuffer: any MTLBuffer
    let fastCerebellarStateCount: Int
    let fastCerebellarStateByteCount: Int
    let fastCerebellarStateBuffer: any MTLBuffer
    let fastAutonomicStateCount: Int
    let fastAutonomicStateByteCount: Int
    let fastAutonomicStateBuffer: any MTLBuffer
    let acceptedSomaticOutputCount: Int
    let acceptedSomaticOutputByteCount: Int
    let acceptedSomaticOutputBuffer: any MTLBuffer
    let acceptedAutonomicOutputCount: Int
    let acceptedAutonomicOutputByteCount: Int
    let acceptedAutonomicOutputBuffer: any MTLBuffer
    let acceptedActiveSensingOutputCount: Int
    let acceptedActiveSensingOutputByteCount: Int
    let acceptedActiveSensingOutputBuffer: any MTLBuffer
    let actuatorCommandKind: ActuatorCommandKind

    fileprivate init(
      transactionFingerprint: UInt64,
      acceptedTimestamp: BrainTimestamp,
      oscillatorCount: Int,
      byteCount: Int,
      cpgBuffer: any MTLBuffer,
      reflexRuleCount: Int,
      reflexStateByteCount: Int,
      reflexStateBuffer: any MTLBuffer,
      fastCerebellarStateCount: Int,
      fastCerebellarStateByteCount: Int,
      fastCerebellarStateBuffer: any MTLBuffer,
      fastAutonomicStateCount: Int,
      fastAutonomicStateByteCount: Int,
      fastAutonomicStateBuffer: any MTLBuffer,
      acceptedSomaticOutputCount: Int,
      acceptedSomaticOutputByteCount: Int,
      acceptedSomaticOutputBuffer: any MTLBuffer,
      acceptedAutonomicOutputCount: Int,
      acceptedAutonomicOutputByteCount: Int,
      acceptedAutonomicOutputBuffer: any MTLBuffer,
      acceptedActiveSensingOutputCount: Int,
      acceptedActiveSensingOutputByteCount: Int,
      acceptedActiveSensingOutputBuffer: any MTLBuffer,
      actuatorCommandKind: ActuatorCommandKind
    ) {
      self.transactionFingerprint = transactionFingerprint
      self.acceptedTimestamp = acceptedTimestamp
      self.oscillatorCount = oscillatorCount
      self.byteCount = byteCount
      self.cpgBuffer = cpgBuffer
      self.reflexRuleCount = reflexRuleCount
      self.reflexStateByteCount = reflexStateByteCount
      self.reflexStateBuffer = reflexStateBuffer
      self.fastCerebellarStateCount = fastCerebellarStateCount
      self.fastCerebellarStateByteCount = fastCerebellarStateByteCount
      self.fastCerebellarStateBuffer = fastCerebellarStateBuffer
      self.fastAutonomicStateCount = fastAutonomicStateCount
      self.fastAutonomicStateByteCount = fastAutonomicStateByteCount
      self.fastAutonomicStateBuffer = fastAutonomicStateBuffer
      self.acceptedSomaticOutputCount = acceptedSomaticOutputCount
      self.acceptedSomaticOutputByteCount = acceptedSomaticOutputByteCount
      self.acceptedSomaticOutputBuffer = acceptedSomaticOutputBuffer
      self.acceptedAutonomicOutputCount = acceptedAutonomicOutputCount
      self.acceptedAutonomicOutputByteCount = acceptedAutonomicOutputByteCount
      self.acceptedAutonomicOutputBuffer = acceptedAutonomicOutputBuffer
      self.acceptedActiveSensingOutputCount = acceptedActiveSensingOutputCount
      self.acceptedActiveSensingOutputByteCount = acceptedActiveSensingOutputByteCount
      self.acceptedActiveSensingOutputBuffer = acceptedActiveSensingOutputBuffer
      self.actuatorCommandKind = actuatorCommandKind
    }
  }
  /// Retains the exact Metal allocations lent to one immediate NumanX
  /// candidate. The opaque object handles are CF-style, unretained views of
  /// the retained `MTLBuffer` objects; a consumer must not store them beyond
  /// this lease or serialize them as transaction identity.
  public final class NumanXMotorBufferLease: @unchecked Sendable {
    public let output: ProtectiveMotorOutputBufferView

    private let headerBuffer: any MTLBuffer
    private let excitationBuffer: any MTLBuffer
    private let autonomicBuffer: any MTLBuffer
    private let activeSensingBuffer: any MTLBuffer

    fileprivate init(
      output: ProtectiveMotorOutputBufferView,
      headerBuffer: any MTLBuffer,
      excitationBuffer: any MTLBuffer,
      autonomicBuffer: any MTLBuffer,
      activeSensingBuffer: any MTLBuffer
    ) {
      self.output = output
      self.headerBuffer = headerBuffer
      self.excitationBuffer = excitationBuffer
      self.autonomicBuffer = autonomicBuffer
      self.activeSensingBuffer = activeSensingBuffer
    }

    public var headerMetalBufferObject: UnsafeMutableRawPointer {
      Unmanaged.passUnretained(headerBuffer as AnyObject).toOpaque()
    }

    public var excitationMetalBufferObject: UnsafeMutableRawPointer {
      Unmanaged.passUnretained(excitationBuffer as AnyObject).toOpaque()
    }

    public var autonomicMetalBufferObject: UnsafeMutableRawPointer {
      Unmanaged.passUnretained(autonomicBuffer as AnyObject).toOpaque()
    }

    public var activeSensingMetalBufferObject: UnsafeMutableRawPointer {
      Unmanaged.passUnretained(activeSensingBuffer as AnyObject).toOpaque()
    }
  }

  public struct Submission: Equatable, Sendable, Codable {
    public let parameterVersionFingerprint: UInt64
    public let attemptedSubsteps: Int
    public let acceptedSubsteps: Int
    public let eventCompactionDispatches: Int
    public let receptorInterruptTransductionDispatches: Int
    public let schedulerDispatches: Int
    public let regionalDispatches: Int
    public let protectiveDispatches: Int
    public let protectiveMotorDispatches: Int
    public let schedulerHostInputEventCount: Int
    public let schedulerReceptorInputEventCount: Int
    public let schedulerCognitiveInputEventMaximumCount: Int
    public let schedulerInputEventCount: Int
    public let gpuStartSeconds: Double
    public let gpuEndSeconds: Double

    public var gpuDurationSeconds: Double {
      max(gpuEndSeconds - gpuStartSeconds, 0)
    }
  }

  public struct FastSystemResult: Equatable, Sendable {
    public let substep: BrainJointSubstepToken
    public let speciesTemplateFingerprint: UInt64
    public let protectiveCommand: ProtectiveCommandBufferView
    public let protectiveMotorOutput: ProtectiveMotorOutputBufferView
    public let fastAutonomicOutput: FastAutonomicOutputBufferView
    public let activeSensingOutput: ActiveSensingOutputBufferView
    public let gpuStartSeconds: Double
    public let gpuEndSeconds: Double

    public var gpuDurationSeconds: Double {
      max(gpuEndSeconds - gpuStartSeconds, 0)
    }
  }

  public struct ProtectiveCommandBufferView: Equatable, Sendable {
    public let gpuAddress: UInt64
    public let byteCount: Int
    public let timestamp: BrainTimestamp
    public let brainGeneration: UInt64
  }

  public struct ProtectiveMotorOutputBufferView: Equatable, Sendable {
    public let headerGPUAddress: UInt64
    public let muscleExcitationGPUAddress: UInt64
    public let headerByteCount: Int
    public let muscleExcitationByteCount: Int
    public let muscleCount: Int
    public let timestamp: BrainTimestamp
    public let brainGeneration: UInt64
    public let profileFingerprint: UInt64
    public let actuatorCommandKind: ActuatorCommandKind

    /// Species-adapted physical command vector. The muscle-named stored fields
    /// remain ABI-compatible with the original biological handoff.
    public var actuatorCommandGPUAddress: UInt64 { muscleExcitationGPUAddress }
    public var actuatorCommandByteCount: Int { muscleExcitationByteCount }
    public var actuatorCount: Int { muscleCount }
  }

  public struct FastAutonomicOutputBufferView: Equatable, Sendable {
    public let gpuAddress: UInt64
    public let byteCount: Int
    public let channelCount: Int
    public let timestamp: BrainTimestamp
    public let brainGeneration: UInt64
  }

  public struct ActiveSensingOutputBufferView: Equatable, Sendable {
    public let gpuAddress: UInt64
    public let byteCount: Int
    public let channelCount: Int
    public let timestamp: BrainTimestamp
    public let brainGeneration: UInt64
  }

  public struct SchedulerInspection: Equatable, Sendable {
    public let snapshot: BrainSchedulerSnapshot
    public let invocations: [BrainModuleInvocation]
    public let status: UInt32
    public let transducedEventCount: Int
    public let receptorEventCount: Int
    public let transductionStatus: UInt32
  }

  fileprivate struct PreparedRootPublication: Sendable {
    let committedIndex: Int
    let committedHistoryOwnerMask: UInt32
    let committedRelayHistoryTimestamps: [UInt64]
    let committedStep: UInt64
    let committedSchedulerClockIndex: Int
    let committedRegionalStateIndex: Int
    let committedSchedulerTime: BrainTimestamp
    let committedSchedulerGeneration: UInt64
  }

  struct PreparedJointRootCommit: Sendable {
    let receipt: BrainJointCommitToken
    fileprivate let root: PreparedRootPublication
    fileprivate let localizedObservations: [LocalizedMuscleLoadReceptorObservation]
    fileprivate let bodyLoadFrame: CommittedBodyLoadFrame?
    fileprivate let protectiveMuscleSelection: LocalizedProtectiveMuscleSelection?
  }

  public let deviceName: String
  public let deviceRegistryID: UInt64
  public let width: Int
  public let height: Int
  public let parameters: TissueParameters
  public let stimulus: TissueStimulus
  public let structureHash: String
  public let delayFieldHash: String
  public let connectomeHash: String
  public let eventScheduleHash: String
  public let eventSchedule: TissueEventSchedule
  public let randomContext: TissueRandomContext
  public let brainSchedule: BrainModuleSchedule
  public let regionalTokenProgram: RegionalTokenProgram
  public let parameterVersion: BrainParameterVersion
  public let sharedParameterBank: MetalSharedParameterBank
  public let schedulerEnvironmentIdentifier: UInt32
  public let historyCapacity = TissueDelayField.historyCapacity
  public let maximumTissueDelayMicroseconds: UInt64
  public let maxEncodedSubsteps: Int
  public let maxSchedulerEvents: Int
  public let maxSchedulerInvocations: Int
  public private(set) var committedStep: UInt64 = 0
  public private(set) var latestCommittedMuscleLoadObservations:
    [LocalizedMuscleLoadReceptorObservation] = []
  public private(set) var latestCommittedBodyLoadFrame: CommittedBodyLoadFrame?
  public private(set) var latestCommittedProtectiveMuscleSelection:
    LocalizedProtectiveMuscleSelection?

  private let device: any MTLDevice
  private let commandQueue: any MTL4CommandQueue
  private let commandAllocator: any MTL4CommandAllocator
  private let commandBuffer: any MTL4CommandBuffer
  private let tissuePipeline: any MTLComputePipelineState
  private let eventCompactionPipeline: any MTLComputePipelineState
  private let receptorInterruptTransductionPipeline: any MTLComputePipelineState
  private let schedulerPipeline: any MTLComputePipelineState
  private let regionalPipeline: any MTLComputePipelineState
  private let protectivePipeline: any MTLComputePipelineState
  private let protectiveMotorPipeline: any MTLComputePipelineState
  private let bodyLoadFieldPipeline: any MTLComputePipelineState
  private let bodySchemaPipeline: any MTLComputePipelineState
  private let fastCerebellarPipeline: any MTLComputePipelineState
  private let fastAutonomicPipeline: any MTLComputePipelineState
  private let argumentTable: any MTL4ArgumentTable
  private let eventArgumentTable: any MTL4ArgumentTable
  private let receptorInterruptArgumentTable: any MTL4ArgumentTable
  private let schedulerArgumentTable: any MTL4ArgumentTable
  private let regionalArgumentTable: any MTL4ArgumentTable
  private let protectiveArgumentTable: any MTL4ArgumentTable
  private let protectiveMotorArgumentTable: any MTL4ArgumentTable
  private let bodyLoadFieldArgumentTable: any MTL4ArgumentTable
  private let bodySchemaArgumentTable: any MTL4ArgumentTable
  private let fastCerebellarArgumentTable: any MTL4ArgumentTable
  private let fastAutonomicArgumentTable: any MTL4ArgumentTable
  private let residencySet: any MTLResidencySet
  private let stateBuffers: [any MTLBuffer]
  private let structureBuffer: any MTLBuffer
  private let delayBuffer: any MTLBuffer
  private let relayHistoryBuffer: any MTLBuffer
  private let relayHistoryTimestampBuffer: any MTLBuffer
  private let relayScratchBuffer: any MTLBuffer
  private let projectionOffsetBuffer: any MTLBuffer
  private let projectionEdgeBuffer: any MTLBuffer
  private let eventBuffer: any MTLBuffer
  private let activeEventIndexBuffer: any MTLBuffer
  private let uniformBuffer: any MTLBuffer
  private let schedulerDescriptorBuffer: any MTLBuffer
  private let schedulerClockBuffers: [any MTLBuffer]
  private let schedulerEventUploadBuffer: any MTLBuffer
  private let transducedSchedulerEventBuffer: any MTLBuffer
  private let receptorEventTransductionUniformBuffer: any MTLBuffer
  private let receptorEventTransductionResultBuffer: any MTLBuffer
  private let schedulerUniformBuffer: any MTLBuffer
  private let schedulerInvocationBuffer: any MTLBuffer
  private let schedulerResultBuffer: any MTLBuffer
  private let parameterVersionBindingBuffer: any MTLBuffer
  private let regionalStateBuffers: [any MTLBuffer]
  private let regionalProgramHeaderBuffer: any MTLBuffer
  private let regionalLayoutBuffer: any MTLBuffer
  private let regionalRouteBuffer: any MTLBuffer
  private let regionalParameterBuffer: any MTLBuffer
  private let regionalTokenStateBuffers: [any MTLBuffer]
  private let regionalTokenCandidateBuffer: any MTLBuffer
  private let regionalRouteHistoryStateBuffers: [any MTLBuffer]
  private let regionalRouteHistoryTimestampBuffers: [any MTLBuffer]
  private let regionalRouteHistoryValueBuffers: [any MTLBuffer]
  private let regionalResolvedRouteHistorySlotBuffer: any MTLBuffer
  private let regionalRouteRuntimeStateBuffers: [any MTLBuffer]
  private let regionalSelectedRouteIndexBuffer: any MTLBuffer
  private let regionalSelectedRouteCountBuffer: any MTLBuffer
  private let protectiveCommandUniformBuffer: any MTLBuffer
  private let protectiveCommandBuffers: [any MTLBuffer]
  private let protectiveMotorProfileBuffer: any MTLBuffer
  private let somaticActuatorDescriptorBuffer: any MTLBuffer
  private let protectiveSourceInhibitionMaskBuffer: any MTLBuffer
  private let zeroDescendingSomaticBuffer: any MTLBuffer
  private let descendingSomaticBuffer: any MTLBuffer
  private let fastCPGUniformBuffer: any MTLBuffer
  private let stagedFastCPGStateBuffer: any MTLBuffer
  private let fastReflexRuleBuffer: any MTLBuffer
  private let stagedFastReflexStateBuffer: any MTLBuffer
  private let baselineFastCerebellarStateBuffer: any MTLBuffer
  private let stagedFastCerebellarStateBuffer: any MTLBuffer
  private let stagedMotorCommandBuffer: any MTLBuffer
  private let fastAutonomicUniformBuffer: any MTLBuffer
  private let baselineFastAutonomicStateBuffer: any MTLBuffer
  private let stagedFastAutonomicStateBuffer: any MTLBuffer
  private let baselineFastAutonomicCommandBuffer: any MTLBuffer
  private let stagedFastAutonomicOutputBuffer: any MTLBuffer
  private let fastAutonomicChannelDescriptorBuffer: any MTLBuffer
  private let stagedActiveSensingCommandBuffer: any MTLBuffer
  private let stagedCognitiveEventQueueBuffer: any MTLBuffer
  private let defaultRegionalMaturationBuffer: any MTLBuffer
  private let stagedRegionalMaturationBuffer: any MTLBuffer
  private let defaultRegionalPlasticModulationBuffer: any MTLBuffer
  private let stagedRegionalPlasticModulationBuffer: any MTLBuffer
  private let protectiveMotorOutputHeaderBuffers: [any MTLBuffer]
  private let protectiveMuscleExcitationBuffers: [any MTLBuffer]
  private let stagedAcceptedSomaticOutputBuffer: any MTLBuffer
  private let stagedAcceptedAutonomicOutputBuffer: any MTLBuffer
  private let stagedAcceptedActiveSensingOutputBuffer: any MTLBuffer
  private let bodyLoadFieldUniformBuffer: any MTLBuffer
  private let bodyLoadFieldUpdateBuffer: any MTLBuffer
  private let bodyLoadFieldStateBuffers: [any MTLBuffer]
  private let bodySchemaUniformBuffer: any MTLBuffer
  private let bodySchemaStateBuffers: [any MTLBuffer]
  private let muscleAttachmentBuffer: any MTLBuffer
  private let stagingBuffer: any MTLBuffer
  private let stateByteCount: Int
  private let relayByteCount: Int
  public let relayHistoryByteCount: Int
  public let relayHistoryTimestampByteCount: Int
  public let projectionOffsetByteCount: Int
  public let projectionEdgeByteCount: Int
  public let eventByteCount: Int
  public let activeEventIndexByteCount: Int
  public let schedulerDescriptorByteCount: Int
  public let schedulerClockByteCount: Int
  public let schedulerEventCapacityByteCount: Int
  public let receptorEventTransductionUniformByteCount: Int
  public let receptorEventTransductionResultByteCount: Int
  public let schedulerInvocationCapacityByteCount: Int
  public let parameterVersionBindingByteCount: Int
  public let regionalStateByteCount: Int
  public let regionalTokenStateByteCount: Int
  public let regionalRouteByteCount: Int
  public let regionalParameterByteCount: Int
  public let regionalRouteHistoryStateByteCount: Int
  public let regionalRouteHistoryTimestampByteCount: Int
  public let regionalRouteHistoryValueByteCount: Int
  public let regionalRouteRuntimeStateByteCount: Int
  public let regionalSelectedRouteIndexByteCount: Int
  public let regionalSelectedRouteCountByteCount: Int
  public let protectiveCommandByteCount = ProtectiveMotorCommand.byteCount
  public let protectiveCommandUniformByteCount = MemoryLayout<ProtectiveCommandUniforms>.stride
  public let protectiveMotorProfile: ProtectiveMotorProfile
  public let numanXMuscleAttachmentCatalog: NumanXMuscleAttachmentCatalog?
  public let bodyLoadFieldDynamics: BodyLoadFieldDynamics
  public let bodySchemaDynamics: BodySchemaPosteriorDynamics
  public let protectiveMotorProfileByteCount: Int
  public let protectiveSourceInhibitionMaskByteCount: Int
  public let protectiveMotorOutputHeaderByteCount = ProtectiveMotorOutput.headerByteCount
  public let protectiveMuscleExcitationByteCount: Int
  public let developmentalMaturationByteCount: Int
  public let regionalPlasticModulationByteCount: Int
  public let fastCPGStateCapacityByteCount: Int
  public let fastReflexRuleCapacityByteCount: Int
  public let fastReflexStateCapacityByteCount: Int
  public let fastCerebellarStateByteCount: Int
  public let stagedMotorCommandByteCount: Int
  public let fastAutonomicStateByteCount: Int
  public let fastAutonomicCommandByteCount: Int
  public let fastAutonomicChannelDescriptorByteCount: Int
  public let activeSensingCommandByteCount: Int
  public let stagedCognitiveEventQueueByteCount: Int
  public let bodyLoadFieldUpdateCapacityByteCount: Int
  public let bodyLoadFieldStateByteCount: Int
  public let bodySchemaStateByteCount: Int
  public let muscleAttachmentByteCount: Int

  private var committedIndex = 0
  private var committedHistoryOwnerMask: UInt32 = 0
  private var committedRelayHistoryTimestamps = [UInt64](
    repeating: 0,
    count: TissueDelayField.historyCapacity
  )
  private var pendingRootShadowIndex: Int?
  private var pendingRootShadowOwnerMask: UInt32?
  private var pendingRootShadowStep: UInt64?
  private var pendingRelayHistoryTimestamps: [UInt64]?
  private var committedSchedulerClockIndex = 0
  private var committedSchedulerTime: BrainTimestamp?
  private var committedSchedulerGeneration: UInt64 = 0
  private var committedRegionalStateIndex = 0
  private var committedBodyLoadFieldStateIndex = 0
  private var pendingSchedulerClockIndex: Int?
  private var pendingSchedulerTargetTime: BrainTimestamp?
  private var pendingRegionalStateIndex: Int?
  private var pendingSchedulerInitialized = false
  private var hasCommittedSchedulerResult = false
  private var pendingJointTransaction: BrainJointTransaction?
  private var descendingSomaticTransactionFingerprint: UInt64?
  private var stagedFastCPGTransactionFingerprint: UInt64?
  private var stagedFastCPGOscillatorCount: Int = 0
  private var stagedFastCPGSynergyCount: Int = 0
  private var boundFastReflexSpeciesFingerprint: UInt64?
  private var boundFastReflexRuleCount: Int = 0
  private var boundFastAutonomicVitalGain: Float = 0
  private var boundFastAutonomicChannelCount: Int = 0
  private var boundActiveSensingChannelCount: Int = 0
  private var boundActuatorCommandKind: ActuatorCommandKind = .muscleExcitation
  private var stagedCognitiveEventTransactionFingerprint: UInt64?
  private var stagedCognitiveEventMaximumCount: Int = 0

  private struct InteractiveCandidate {
    let substep: BrainJointSubstepToken
    let destinationIndex: Int
    let historyWriteSlot: Int
    let historyWritePlane: UInt32
    let motorStateIndex: Int
  }

  private struct InteractiveJointRoot {
    var transaction: BrainJointTransaction
    var rootShadowIndex: Int
    var historyOwnerMask: UInt32
    var historyStep: UInt64
    var relayHistoryTimestamps: [UInt64]
    var acceptedTimestamp: BrainTimestamp
    var candidate: InteractiveCandidate?
    var fastSchedulerWindow: PreparedSchedulerWindow?
    var firstGPUStartSeconds: Double?
    var lastGPUEndSeconds: Double?
  }

  private var interactiveJointRoot: InteractiveJointRoot?

  public init(
    initialState: TissueGrid,
    parameters: TissueParameters,
    stimulus: TissueStimulus,
    structure requestedStructure: TissueStructure? = nil,
    delayField requestedDelayField: TissueDelayField? = nil,
    connectome requestedConnectome: TissueConnectome? = nil,
    eventSchedule requestedEventSchedule: TissueEventSchedule? = nil,
    randomContext: TissueRandomContext = .deterministicDefault,
    brainSchedule requestedBrainSchedule: BrainModuleSchedule? = nil,
    regionalTokenProgram requestedRegionalTokenProgram: RegionalTokenProgram? = nil,
    parameterVersion requestedParameterVersion: BrainParameterVersion? = nil,
    sharedParameterArtifact: BrainSharedParameterArtifact? = nil,
    initialRegionalTokenValues requestedInitialRegionalTokenValues: [Float]? = nil,
    initialRegionalRoutingState requestedInitialRegionalRoutingState: RegionalRoutingState? = nil,
    protectiveMotorProfile requestedProtectiveMotorProfile: ProtectiveMotorProfile? = nil,
    numanXMuscleAttachmentCatalog requestedNumanXMuscleAttachmentCatalog:
      NumanXMuscleAttachmentCatalog? = nil,
    bodyLoadFieldDynamics requestedBodyLoadFieldDynamics: BodyLoadFieldDynamics? = nil,
    bodySchemaDynamics requestedBodySchemaDynamics: BodySchemaPosteriorDynamics? = nil,
    schedulerEnvironmentIdentifier: UInt32 = 0,
    maxSchedulerEvents: Int = 64,
    maxSchedulerInvocations: Int = 4_096,
    maxEncodedSubsteps: Int = 4_096,
    device requestedDevice: (any MTLDevice)? = nil
  ) throws {
    try parameters.validate()
    try stimulus.validate()
    let structure: TissueStructure
    if let requestedStructure {
      structure = requestedStructure
    } else {
      structure = try TissueStructure.homogeneous(
        width: initialState.width,
        height: initialState.height
      )
    }
    try structure.validate()
    guard structure.width == initialState.width, structure.height == initialState.height else {
      throw TissueError.invalidStructure("structure dimensions must match the initial state")
    }
    let delayField: TissueDelayField
    if let requestedDelayField {
      delayField = requestedDelayField
    } else {
      delayField = try TissueDelayField.instantaneous(
        width: initialState.width,
        height: initialState.height
      )
    }
    try delayField.validate()
    guard delayField.width == initialState.width, delayField.height == initialState.height else {
      throw TissueError.invalidConduction("delay dimensions must match the initial state")
    }
    let connectome: TissueConnectome
    if let requestedConnectome {
      connectome = requestedConnectome
    } else {
      connectome = try TissueConnectome.none(
        width: initialState.width,
        height: initialState.height
      )
    }
    guard connectome.width == initialState.width, connectome.height == initialState.height else {
      throw TissueError.invalidConnectome("connectome dimensions must match the initial state")
    }
    let eventSchedule =
      try requestedEventSchedule
      ?? TissueEventSchedule.singleStimulus(stimulus)
    let brainSchedule =
      try requestedBrainSchedule
      ?? ReferenceBrainSchedule.runtimeFoundationSubset()
    let regionalTokenProgram =
      try requestedRegionalTokenProgram
      ?? RegionalTokenProgram.runtimeFoundationV0(schedule: brainSchedule)
    guard regionalTokenProgram.scheduleFingerprint == brainSchedule.fingerprint else {
      throw TissueError.metal("regional token program does not match the brain schedule")
    }
    let parameterVersion =
      try requestedParameterVersion
      ?? BrainParameterVersion.runtimeFoundationV0(
        schedule: brainSchedule,
        regionalProgram: regionalTokenProgram,
        tissueParameters: parameters
      )
    guard parameterVersion.scheduleFingerprint == brainSchedule.fingerprint,
      parameterVersion.regionalShapeFingerprint == regionalTokenProgram.shapeFingerprint,
      parameterVersion.regionalProgramFingerprint == regionalTokenProgram.fingerprint,
      parameterVersion.components.first(where: { $0.kind == .tissueDynamics })?
        .contentFingerprint == parameters.parameterFingerprint,
      parameterVersion.components.first(where: { $0.kind == .regionalOperator })?
        .contentFingerprint == regionalTokenProgram.fingerprint
    else {
      throw TissueError.metal(
        "parameter version does not match tissue, schedule, or regional program"
      )
    }
    var parameterBindingValidationRecord = parameterVersion.abiBinding
    let parameterComponentValidationRecords = parameterVersion.components.map(\.abiRecord)
    let parameterValidation = parameterComponentValidationRecords.withUnsafeBufferPointer {
      components in
      withUnsafePointer(to: &parameterBindingValidationRecord) { binding in
        nb_brain_abi_validate_parameter_version(binding, components.baseAddress)
      }
    }
    guard parameterValidation == UInt32(NB_PARAMETER_VERSION_VALID.rawValue) else {
      throw TissueError.metal(
        "compiled parameter manifest validation failed with code \(parameterValidation)"
      )
    }
    let initialRegionalTokenValues =
      requestedInitialRegionalTokenValues
      ?? [Float](repeating: 0, count: regionalTokenProgram.scalarCount)
    guard initialRegionalTokenValues.count == regionalTokenProgram.scalarCount,
      initialRegionalTokenValues.allSatisfy(\.isFinite)
    else {
      throw TissueError.metal("initial regional token values do not match the program")
    }
    let initialRegionalRoutingState =
      requestedInitialRegionalRoutingState
      ?? RegionalRoutingState(program: regionalTokenProgram)
    do {
      try initialRegionalRoutingState.validate(program: regionalTokenProgram)
    } catch {
      throw TissueError.metal("initial regional routing state is invalid: \(error)")
    }
    let protectiveMotorProfile =
      try requestedProtectiveMotorProfile
      ?? ProtectiveMotorProfile.runtimeFoundationFixture()
    let bodyLoadFieldDynamics =
      try requestedBodyLoadFieldDynamics
      ?? BodyLoadFieldDynamics.runtimeFoundationV0
    let bodySchemaDynamics =
      try requestedBodySchemaDynamics
      ?? BodySchemaPosteriorDynamics.runtimeFoundationV0
    if let requestedNumanXMuscleAttachmentCatalog {
      do {
        try requestedNumanXMuscleAttachmentCatalog.validate(
          profile: protectiveMotorProfile
        )
      } catch {
        throw TissueError.metal(
          "NumanX attachment catalog does not match the protective profile: \(error)"
        )
      }
    }
    guard maxEncodedSubsteps > 0 else {
      throw TissueError.metal("maxEncodedSubsteps must be positive")
    }
    guard maxSchedulerEvents > 0, maxSchedulerEvents <= 65_536 else {
      throw TissueError.metal("maxSchedulerEvents must be in 1...65536")
    }
    guard maxSchedulerInvocations > 0, maxSchedulerInvocations <= Int(UInt32.max) else {
      throw TissueError.metal("maxSchedulerInvocations must be in 1...UInt32.max")
    }
    let timestepMicrosecondsDouble = Double(parameters.timestepMilliseconds) * 1_000
    let roundedTimestepMicroseconds = timestepMicrosecondsDouble.rounded()
    guard roundedTimestepMicroseconds >= 1,
      roundedTimestepMicroseconds < Double(UInt64.max),
      abs(timestepMicrosecondsDouble - roundedTimestepMicroseconds) <= 0.01
    else {
      throw TissueError.metal(
        "timestepMilliseconds must map to positive integer microseconds for route history"
      )
    }
    let timestepMicroseconds = UInt64(roundedTimestepMicroseconds)
    let maximumTissueDelaySteps = max(
      delayField.maximumConfiguredDelaySteps,
      connectome.maximumProjectionDelaySteps
    )
    let (maximumTissueDelayMicroseconds, tissueDelayOverflow) = UInt64(
      maximumTissueDelaySteps
    ).multipliedReportingOverflow(by: timestepMicroseconds)
    guard !tissueDelayOverflow else {
      throw TissueError.metal("physical tissue delay overflows UInt64")
    }
    let maximumRouteDelay = UInt64(
      regionalTokenProgram.routes.map(\.delayMicroseconds).max() ?? 0
    )
    let delayWindows =
      maximumRouteDelay == 0
      ? UInt64(1)
      : (maximumRouteDelay + timestepMicroseconds - 1) / timestepMicroseconds + 1
    let (historyPublicationsPerWindow, historyPublicationOverflow) =
      UInt64(maxSchedulerEvents + 2).multipliedReportingOverflow(by: delayWindows)
    let (requiredRouteHistoryCapacity, historyCapacityOverflow) =
      historyPublicationsPerWindow.addingReportingOverflow(1)
    guard !historyPublicationOverflow, !historyCapacityOverflow,
      requiredRouteHistoryCapacity <= UInt64(regionalTokenProgram.compiledRouteHistoryCapacity)
    else {
      throw TissueError.metal(
        "scheduler/event bounds require \(requiredRouteHistoryCapacity) regional route-history slots; capacity is \(regionalTokenProgram.compiledRouteHistoryCapacity)"
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
    guard let commandQueue = device.makeMTL4CommandQueue() else {
      throw TissueError.metal("device does not provide a Metal 4 command queue")
    }
    guard let commandAllocator = device.makeCommandAllocator() else {
      throw TissueError.metal("failed to create a Metal 4 command allocator")
    }
    guard let commandBuffer = device.makeCommandBuffer() else {
      throw TissueError.metal("failed to create a reusable Metal 4 command buffer")
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
    guard let tissueFunction = library.makeFunction(name: "neural_tissue_step") else {
      throw TissueError.metal("neural_tissue_step is missing from the Metal library")
    }
    guard let eventCompactionFunction = library.makeFunction(name: "compact_receptor_events") else {
      throw TissueError.metal("compact_receptor_events is missing from the Metal library")
    }
    guard
      let receptorInterruptTransductionFunction = library.makeFunction(
        name: "transduce_receptor_interrupts"
      )
    else {
      throw TissueError.metal("transduce_receptor_interrupts is missing from the Metal library")
    }
    guard let schedulerFunction = library.makeFunction(name: "schedule_due_modules") else {
      throw TissueError.metal("schedule_due_modules is missing from the Metal library")
    }
    guard let regionalFunction = library.makeFunction(name: "advance_due_regional_tokens") else {
      throw TissueError.metal("advance_due_regional_tokens is missing from the Metal library")
    }
    guard let protectiveFunction = library.makeFunction(name: "derive_protective_command") else {
      throw TissueError.metal("derive_protective_command is missing from the Metal library")
    }
    guard
      let protectiveMotorFunction = library.makeFunction(name: "map_protective_motor_output")
    else {
      throw TissueError.metal("map_protective_motor_output is missing from the Metal library")
    }
    guard
      let bodyLoadFieldFunction = library.makeFunction(name: "materialize_body_load_field")
    else {
      throw TissueError.metal("materialize_body_load_field is missing from the Metal library")
    }
    guard let bodySchemaFunction = library.makeFunction(name: "advance_body_schema") else {
      throw TissueError.metal("advance_body_schema is missing from the Metal library")
    }
    guard let fastCerebellarFunction = library.makeFunction(
      name: "adapt_fast_cerebellar_load_correction"
    ) else {
      throw TissueError.metal(
        "adapt_fast_cerebellar_load_correction is missing from the Metal library"
      )
    }
    guard let fastAutonomicFunction = library.makeFunction(
      name: "advance_fast_autonomic_output"
    ) else {
      throw TissueError.metal(
        "advance_fast_autonomic_output is missing from the Metal library"
      )
    }
    let tissuePipeline: any MTLComputePipelineState
    let eventCompactionPipeline: any MTLComputePipelineState
    let receptorInterruptTransductionPipeline: any MTLComputePipelineState
    let schedulerPipeline: any MTLComputePipelineState
    let regionalPipeline: any MTLComputePipelineState
    let protectivePipeline: any MTLComputePipelineState
    let protectiveMotorPipeline: any MTLComputePipelineState
    let bodyLoadFieldPipeline: any MTLComputePipelineState
    let bodySchemaPipeline: any MTLComputePipelineState
    let fastCerebellarPipeline: any MTLComputePipelineState
    let fastAutonomicPipeline: any MTLComputePipelineState
    do {
      tissuePipeline = try device.makeComputePipelineState(function: tissueFunction)
      eventCompactionPipeline = try device.makeComputePipelineState(
        function: eventCompactionFunction
      )
      receptorInterruptTransductionPipeline = try device.makeComputePipelineState(
        function: receptorInterruptTransductionFunction
      )
      schedulerPipeline = try device.makeComputePipelineState(function: schedulerFunction)
      regionalPipeline = try device.makeComputePipelineState(function: regionalFunction)
      protectivePipeline = try device.makeComputePipelineState(function: protectiveFunction)
      protectiveMotorPipeline = try device.makeComputePipelineState(
        function: protectiveMotorFunction
      )
      bodyLoadFieldPipeline = try device.makeComputePipelineState(
        function: bodyLoadFieldFunction
      )
      bodySchemaPipeline = try device.makeComputePipelineState(
        function: bodySchemaFunction
      )
      fastCerebellarPipeline = try device.makeComputePipelineState(
        function: fastCerebellarFunction
      )
      fastAutonomicPipeline = try device.makeComputePipelineState(
        function: fastAutonomicFunction
      )
    } catch {
      throw TissueError.metal(
        "tissue, event/transduction, scheduler, or regional pipeline creation failed: \(error)"
      )
    }

    let argumentDescriptor = MTL4ArgumentTableDescriptor()
    argumentDescriptor.label = "NumiBrain tissue arguments"
    argumentDescriptor.maxBufferBindCount = 12
    argumentDescriptor.initializeBindings = true
    guard let argumentTable = try? device.makeArgumentTable(descriptor: argumentDescriptor) else {
      throw TissueError.metal("failed to create the Metal 4 argument table")
    }
    let eventArgumentDescriptor = MTL4ArgumentTableDescriptor()
    eventArgumentDescriptor.label = "NumiBrain event-compaction arguments"
    eventArgumentDescriptor.maxBufferBindCount = 3
    eventArgumentDescriptor.initializeBindings = true
    guard
      let eventArgumentTable = try? device.makeArgumentTable(
        descriptor: eventArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the event-compaction argument table")
    }
    let receptorInterruptArgumentDescriptor = MTL4ArgumentTableDescriptor()
    receptorInterruptArgumentDescriptor.label = "NumiBrain receptor-interrupt arguments"
    receptorInterruptArgumentDescriptor.maxBufferBindCount = 6
    receptorInterruptArgumentDescriptor.initializeBindings = true
    guard
      let receptorInterruptArgumentTable = try? device.makeArgumentTable(
        descriptor: receptorInterruptArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the receptor-interrupt argument table")
    }
    let schedulerArgumentDescriptor = MTL4ArgumentTableDescriptor()
    schedulerArgumentDescriptor.label = "NumiBrain scheduler arguments"
    schedulerArgumentDescriptor.maxBufferBindCount = 10
    schedulerArgumentDescriptor.initializeBindings = true
    guard
      let schedulerArgumentTable = try? device.makeArgumentTable(
        descriptor: schedulerArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the scheduler argument table")
    }
    let regionalArgumentDescriptor = MTL4ArgumentTableDescriptor()
    regionalArgumentDescriptor.label = "NumiBrain regional-token arguments"
    regionalArgumentDescriptor.maxBufferBindCount = 27
    regionalArgumentDescriptor.initializeBindings = true
    guard
      let regionalArgumentTable = try? device.makeArgumentTable(
        descriptor: regionalArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the regional-state argument table")
    }
    regionalArgumentTable.setAddress(
      try sharedParameterBank.gpuAddress(.route, minimumScalarCount: 8),
      index: 26
    )
    let protectiveArgumentDescriptor = MTL4ArgumentTableDescriptor()
    protectiveArgumentDescriptor.label = "NumiBrain protective-command arguments"
    protectiveArgumentDescriptor.maxBufferBindCount = 6
    protectiveArgumentDescriptor.initializeBindings = true
    guard
      let protectiveArgumentTable = try? device.makeArgumentTable(
        descriptor: protectiveArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the protective-command argument table")
    }
    let protectiveMotorArgumentDescriptor = MTL4ArgumentTableDescriptor()
    protectiveMotorArgumentDescriptor.label = "NumiBrain protective-motor arguments"
    protectiveMotorArgumentDescriptor.maxBufferBindCount = 19
    protectiveMotorArgumentDescriptor.initializeBindings = true
    guard
      let protectiveMotorArgumentTable = try? device.makeArgumentTable(
        descriptor: protectiveMotorArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the protective-motor argument table")
    }
    let bodyLoadFieldArgumentDescriptor = MTL4ArgumentTableDescriptor()
    bodyLoadFieldArgumentDescriptor.label = "NumiBrain body-load field arguments"
    bodyLoadFieldArgumentDescriptor.maxBufferBindCount = 4
    bodyLoadFieldArgumentDescriptor.initializeBindings = true
    guard
      let bodyLoadFieldArgumentTable = try? device.makeArgumentTable(
        descriptor: bodyLoadFieldArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the body-load field argument table")
    }
    let bodySchemaArgumentDescriptor = MTL4ArgumentTableDescriptor()
    bodySchemaArgumentDescriptor.label = "NumiBrain body-schema arguments"
    bodySchemaArgumentDescriptor.maxBufferBindCount = 4
    bodySchemaArgumentDescriptor.initializeBindings = true
    guard
      let bodySchemaArgumentTable = try? device.makeArgumentTable(
        descriptor: bodySchemaArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the body-schema argument table")
    }
    let fastCerebellarArgumentDescriptor = MTL4ArgumentTableDescriptor()
    fastCerebellarArgumentDescriptor.label = "NumiBrain fast-cerebellar arguments"
    fastCerebellarArgumentDescriptor.maxBufferBindCount = 8
    fastCerebellarArgumentDescriptor.initializeBindings = true
    guard
      let fastCerebellarArgumentTable = try? device.makeArgumentTable(
        descriptor: fastCerebellarArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the fast-cerebellar argument table")
    }
    fastCerebellarArgumentTable.setAddress(
      try sharedParameterBank.gpuAddress(.cerebellar, minimumScalarCount: 8),
      index: 7
    )
    let fastAutonomicArgumentDescriptor = MTL4ArgumentTableDescriptor()
    fastAutonomicArgumentDescriptor.label = "NumiBrain fast-autonomic arguments"
    fastAutonomicArgumentDescriptor.maxBufferBindCount = 9
    fastAutonomicArgumentDescriptor.initializeBindings = true
    guard
      let fastAutonomicArgumentTable = try? device.makeArgumentTable(
        descriptor: fastAutonomicArgumentDescriptor
      )
    else {
      throw TissueError.metal("failed to create the fast-autonomic argument table")
    }

    let stateByteCount = initialState.count * MemoryLayout<TissueCell>.stride
    let stateBuffers: [any MTLBuffer] = try (0..<3).map { index in
      guard
        let buffer = device.makeBuffer(
          length: stateByteCount,
          options: [.storageModePrivate, .hazardTrackingModeTracked]
        )
      else {
        throw TissueError.metal("failed to allocate state generation \(index)")
      }
      buffer.label = "NumiBrain tissue state generation \(index)"
      return buffer
    }
    guard
      let structureBuffer = device.makeBuffer(
        length: stateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate the tissue structure field")
    }
    structureBuffer.label = "NumiBrain immutable tissue structure"
    let relayByteCount = initialState.count * MemoryLayout<Float>.stride
    let (historyPlaneByteCount, historyPlaneOverflow) = relayByteCount.multipliedReportingOverflow(
      by: TissueDelayField.historyCapacity
    )
    let (relayHistoryByteCount, relayHistoryOverflow) =
      historyPlaneByteCount
      .multipliedReportingOverflow(by: 2)
    let relayHistoryTimestampByteCount =
      2 * TissueDelayField.historyCapacity
      * MemoryLayout<UInt64>.stride
    guard !historyPlaneOverflow, !relayHistoryOverflow else {
      throw TissueError.metal("relay history byte count overflows Int")
    }
    guard
      let delayBuffer = device.makeBuffer(
        length: delayField.count * MemoryLayout<UInt8>.stride,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let relayHistoryBuffer = device.makeBuffer(
        length: relayHistoryByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let relayHistoryTimestampBuffer = device.makeBuffer(
        length: relayHistoryTimestampByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let relayScratchBuffer = device.makeBuffer(
        length: relayByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate private conduction history buffers")
    }
    delayBuffer.label = "NumiBrain immutable conduction delays"
    relayHistoryBuffer.label = "NumiBrain transactional relay history"
    relayHistoryTimestampBuffer.label = "NumiBrain physical relay-history timestamps"
    relayScratchBuffer.label = "NumiBrain rejected relay scratch"
    let packedProjectionEdges = connectome.packedEdges()
    let projectionOffsetByteCount =
      connectome.destinationOffsets.count
      * MemoryLayout<UInt32>.stride
    let projectionEdgeByteCount =
      packedProjectionEdges.count
      * MemoryLayout<TissueConnectome.PackedEdge>.stride
    guard
      let projectionOffsetBuffer = device.makeBuffer(
        length: projectionOffsetByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let projectionEdgeBuffer = device.makeBuffer(
        length: max(projectionEdgeByteCount, MemoryLayout<TissueConnectome.PackedEdge>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate private sparse projection buffers")
    }
    projectionOffsetBuffer.label = "NumiBrain projection CSR offsets"
    projectionEdgeBuffer.label = "NumiBrain packed delayed projections"
    let packedEvents = eventSchedule.packedRecords()
    let eventByteCount = eventSchedule.packedByteCount
    let activeEventIndexByteCount = eventSchedule.activeIndexByteCapacity
    guard
      let eventBuffer = device.makeBuffer(
        length: max(eventByteCount, MemoryLayout<NBReceptorEvent>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let activeEventIndexBuffer = device.makeBuffer(
        length: activeEventIndexByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate private receptor-event buffers")
    }
    eventBuffer.label = "NumiBrain immutable receptor-event schedule"
    activeEventIndexBuffer.label = "NumiBrain compacted active-event indices"
    guard
      MemoryLayout<NBModuleDescriptor>.stride == Int(NB_MODULE_DESCRIPTOR_BYTE_COUNT),
      MemoryLayout<NBModuleClockState>.stride == Int(NB_MODULE_CLOCK_STATE_BYTE_COUNT),
      MemoryLayout<NBReceptorEvent>.stride == Int(NB_RECEPTOR_EVENT_BYTE_COUNT),
      MemoryLayout<NBInterruptEvent>.stride == Int(NB_INTERRUPT_EVENT_BYTE_COUNT),
      MemoryLayout<NBReceptorEventTransductionUniforms>.stride
        == Int(NB_RECEPTOR_EVENT_TRANSDUCTION_UNIFORMS_BYTE_COUNT),
      MemoryLayout<NBReceptorEventTransductionResult>.stride
        == Int(NB_RECEPTOR_EVENT_TRANSDUCTION_RESULT_BYTE_COUNT),
      MemoryLayout<NBDueInvocation>.stride == Int(NB_DUE_INVOCATION_BYTE_COUNT),
      MemoryLayout<NBSchedulerUniforms>.stride == Int(NB_SCHEDULER_UNIFORMS_BYTE_COUNT),
      MemoryLayout<NBSchedulerResult>.stride == Int(NB_SCHEDULER_RESULT_BYTE_COUNT),
      MemoryLayout<NBRegionalModuleState>.stride == Int(NB_REGIONAL_MODULE_STATE_BYTE_COUNT),
      MemoryLayout<NBRegionalTokenLayout>.stride == Int(NB_REGIONAL_TOKEN_LAYOUT_BYTE_COUNT),
      MemoryLayout<NBRegionalRoute>.stride == Int(NB_REGIONAL_ROUTE_BYTE_COUNT),
      MemoryLayout<NBRegionalTokenParameters>.stride
        == Int(NB_REGIONAL_TOKEN_PARAMETERS_BYTE_COUNT),
      MemoryLayout<NBRegionalProgramHeader>.stride
        == Int(NB_REGIONAL_PROGRAM_HEADER_BYTE_COUNT),
      MemoryLayout<NBRegionalRouteHistoryState>.stride
        == Int(NB_REGIONAL_ROUTE_HISTORY_STATE_BYTE_COUNT),
      MemoryLayout<NBRegionalRouteRuntimeState>.stride
        == Int(NB_REGIONAL_ROUTE_RUNTIME_STATE_BYTE_COUNT),
      MemoryLayout<NBParameterComponent>.stride == Int(NB_PARAMETER_COMPONENT_BYTE_COUNT),
      MemoryLayout<NBParameterVersionBinding>.stride
        == Int(NB_PARAMETER_VERSION_BINDING_BYTE_COUNT),
      MemoryLayout<NBMotorChannelDescriptor>.stride
        == Int(NB_MOTOR_CHANNEL_DESCRIPTOR_BYTE_COUNT),
      MemoryLayout<NBMotorOutputHeader>.stride == Int(NB_MOTOR_OUTPUT_HEADER_BYTE_COUNT)
    else {
      throw TissueError.metal("Swift imported scheduler ABI does not match NumiBrainABI")
    }
    let schedulerDescriptorByteCount =
      brainSchedule.modules.count
      * MemoryLayout<NBModuleDescriptor>.stride
    let schedulerClockByteCount =
      brainSchedule.modules.count
      * MemoryLayout<NBModuleClockState>.stride
    let schedulerEventCapacityByteCount =
      maxSchedulerEvents
      * MemoryLayout<NBInterruptEvent>.stride
    let schedulerInvocationCapacityByteCount =
      maxSchedulerInvocations
      * MemoryLayout<NBDueInvocation>.stride
    let regionalStateByteCount =
      brainSchedule.modules.count
      * MemoryLayout<NBRegionalModuleState>.stride
    let regionalLayoutByteCount =
      regionalTokenProgram.layouts.count
      * MemoryLayout<NBRegionalTokenLayout>.stride
    let regionalRouteByteCount =
      regionalTokenProgram.routes.count
      * MemoryLayout<NBRegionalRoute>.stride
    let regionalParameterByteCount =
      regionalTokenProgram.parameters.count
      * MemoryLayout<NBRegionalTokenParameters>.stride
    let regionalTokenStateByteCount =
      regionalTokenProgram.scalarCount * MemoryLayout<Float>.stride
    let regionalRouteHistoryStateByteCount =
      regionalTokenProgram.routes.count
      * MemoryLayout<NBRegionalRouteHistoryState>.stride
    let regionalRouteHistoryTimestampByteCount =
      regionalTokenProgram.routes.count
      * regionalTokenProgram.compiledRouteHistoryCapacity
      * MemoryLayout<UInt64>.stride
    let regionalRouteHistoryValueByteCount =
      regionalTokenProgram.routeHistoryScalarCount * MemoryLayout<Float>.stride
    let regionalResolvedRouteHistorySlotByteCount =
      regionalTokenProgram.routes.count * MemoryLayout<UInt32>.stride
    let regionalRouteRuntimeStateByteCount =
      regionalTokenProgram.routes.count
      * MemoryLayout<NBRegionalRouteRuntimeState>.stride
    let regionalSelectedRouteIndexByteCount =
      regionalTokenProgram.routes.count * MemoryLayout<UInt32>.stride
    let regionalSelectedRouteCountByteCount =
      regionalTokenProgram.layouts.count * MemoryLayout<UInt32>.stride
    let (protectiveMotorProfileByteCount, protectiveProfileByteOverflow) =
      protectiveMotorProfile.channels.count.multipliedReportingOverflow(
        by: MemoryLayout<NBMotorChannelDescriptor>.stride
      )
    let (protectiveMuscleExcitationByteCount, protectiveExcitationByteOverflow) =
      protectiveMotorProfile.channels.count.multipliedReportingOverflow(
        by: MemoryLayout<Float>.stride
      )
    let (developmentalMaturationByteCount, developmentalMaturationOverflow) =
      brainSchedule.modules.count.multipliedReportingOverflow(
        by: MemoryLayout<TissueRegionalMaturationRecord>.stride
      )
    let (regionalPlasticModulationByteCount, plasticModulationOverflow) =
      brainSchedule.modules.count.multipliedReportingOverflow(
        by: MemoryLayout<TissueRegionalPlasticModulationRecord>.stride
      )
    let fastCPGStateCapacityByteCount = Self.maximumFastCPGOscillatorCount
      * Self.fastCPGStateStride
    let fastReflexRuleCapacityByteCount = Self.maximumFastReflexRuleCount
      * Self.fastReflexRuleStride
    let fastReflexStateCapacityByteCount = Self.maximumFastReflexRuleCount
      * Self.fastReflexStateStride
    let (fastCerebellarStateByteCount, fastCerebellarStateByteOverflow) =
      protectiveMotorProfile.channels.count.multipliedReportingOverflow(
        by: Self.fastCerebellarStateStride
      )
    let (stagedMotorCommandByteCount, stagedMotorCommandByteOverflow) =
      protectiveMotorProfile.channels.count.multipliedReportingOverflow(
        by: Self.motorCommandStride
      )
    let fastAutonomicStateByteCount = Self.maximumFastAutonomicChannelCount
      * Self.fastAutonomicStateStride
    let fastAutonomicCommandByteCount = Self.maximumFastAutonomicChannelCount
      * Self.autonomicCommandStride
    let fastAutonomicChannelDescriptorByteCount =
      Self.maximumFastAutonomicChannelCount
        * Self.fastAutonomicChannelDescriptorStride
    let activeSensingCommandByteCount = Self.maximumActiveSensingChannelCount
      * Self.activeSensingCommandStride
    let stagedCognitiveEventQueueByteCount =
      Self.cognitiveEventQueueHeaderStride
        + Self.maximumCognitiveEventCount * Self.cognitiveEventRecordStride
    guard !protectiveProfileByteOverflow, !protectiveExcitationByteOverflow,
      !developmentalMaturationOverflow, !plasticModulationOverflow,
      !fastCerebellarStateByteOverflow, !stagedMotorCommandByteOverflow,
      MemoryLayout<TissueRegionalMaturationRecord>.stride == 32,
      MemoryLayout<TissueRegionalPlasticModulationRecord>.stride == 32,
      MemoryLayout<FastCPGUniforms>.stride == 24,
      MemoryLayout<FastAutonomicUniforms>.stride == 40,
      MemoryLayout<FastAutonomicChannelDescriptor>.stride
        == Self.fastAutonomicChannelDescriptorStride,
      MemoryLayout<SomaticActuatorDescriptor>.stride == 32,
      MetalAgentStateLayout.eventTokenStride == Self.cognitiveEventRecordStride,
      MemoryLayout<FastReflexRule>.stride == Self.fastReflexRuleStride
    else {
      throw TissueError.metal("protective motor profile byte count overflows Int")
    }
    guard MemoryLayout<BodyLoadFieldUniforms>.stride == 32,
      MemoryLayout<BodyLoadFieldRecord>.stride == 56,
      MemoryLayout<BodySchemaUniforms>.stride == 56,
      MemoryLayout<BodySchemaRecord>.stride == 48,
      MemoryLayout<MuscleAttachmentRecord>.stride == 16
    else {
      throw TissueError.metal("body-load field ABI layout drift")
    }
    let bodyLoadFieldBodyCount = Int(requestedNumanXMuscleAttachmentCatalog?.bodyCount ?? 0)
    let (bodyLoadFieldStateByteCount, bodyLoadStateByteOverflow) =
      max(bodyLoadFieldBodyCount, 1).multipliedReportingOverflow(
        by: MemoryLayout<BodyLoadFieldRecord>.stride
      )
    let (bodyLoadUpdateCapacity, bodyLoadUpdateCapacityOverflow) =
      maxSchedulerEvents.multipliedReportingOverflow(by: 2)
    let (bodyLoadFieldUpdateCapacityByteCount, bodyLoadUpdateByteOverflow) =
      bodyLoadUpdateCapacity.multipliedReportingOverflow(
        by: MemoryLayout<BodyLoadFieldRecord>.stride
      )
    guard !bodyLoadStateByteOverflow, !bodyLoadUpdateCapacityOverflow,
      !bodyLoadUpdateByteOverflow
    else {
      throw TissueError.metal("body-load field byte count overflows Int")
    }
    let (bodySchemaStateByteCount, bodySchemaStateByteOverflow) =
      max(bodyLoadFieldBodyCount, 1).multipliedReportingOverflow(
        by: MemoryLayout<BodySchemaRecord>.stride
      )
    let (muscleAttachmentByteCount, muscleAttachmentByteOverflow) =
      max(protectiveMotorProfile.channels.count, 1).multipliedReportingOverflow(
        by: MemoryLayout<MuscleAttachmentRecord>.stride
      )
    guard !bodySchemaStateByteOverflow, !muscleAttachmentByteOverflow else {
      throw TissueError.metal("body-schema byte count overflows Int")
    }
    guard
      let schedulerDescriptorBuffer = device.makeBuffer(
        length: schedulerDescriptorByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstSchedulerClockBuffer = device.makeBuffer(
        length: schedulerClockByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondSchedulerClockBuffer = device.makeBuffer(
        length: schedulerClockByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let schedulerEventUploadBuffer = device.makeBuffer(
        length: schedulerEventCapacityByteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let transducedSchedulerEventBuffer = device.makeBuffer(
        length: schedulerEventCapacityByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let receptorEventTransductionUniformBuffer = device.makeBuffer(
        length: MemoryLayout<NBReceptorEventTransductionUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let receptorEventTransductionResultBuffer = device.makeBuffer(
        length: MemoryLayout<NBReceptorEventTransductionResult>.stride,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let schedulerUniformBuffer = device.makeBuffer(
        length: MemoryLayout<NBSchedulerUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let schedulerInvocationBuffer = device.makeBuffer(
        length: schedulerInvocationCapacityByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let schedulerResultBuffer = device.makeBuffer(
        length: MemoryLayout<NBSchedulerResult>.stride,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let parameterVersionBindingBuffer = device.makeBuffer(
        length: MemoryLayout<NBParameterVersionBinding>.stride,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstRegionalStateBuffer = device.makeBuffer(
        length: regionalStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondRegionalStateBuffer = device.makeBuffer(
        length: regionalStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalProgramHeaderBuffer = device.makeBuffer(
        length: MemoryLayout<NBRegionalProgramHeader>.stride,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalLayoutBuffer = device.makeBuffer(
        length: regionalLayoutByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalRouteBuffer = device.makeBuffer(
        length: max(regionalRouteByteCount, MemoryLayout<NBRegionalRoute>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalParameterBuffer = device.makeBuffer(
        length: regionalParameterByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstRegionalTokenStateBuffer = device.makeBuffer(
        length: regionalTokenStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondRegionalTokenStateBuffer = device.makeBuffer(
        length: regionalTokenStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalTokenCandidateBuffer = device.makeBuffer(
        length: regionalTokenStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstRegionalRouteHistoryStateBuffer = device.makeBuffer(
        length: max(
          regionalRouteHistoryStateByteCount,
          MemoryLayout<NBRegionalRouteHistoryState>.stride
        ),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondRegionalRouteHistoryStateBuffer = device.makeBuffer(
        length: max(
          regionalRouteHistoryStateByteCount,
          MemoryLayout<NBRegionalRouteHistoryState>.stride
        ),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstRegionalRouteHistoryTimestampBuffer = device.makeBuffer(
        length: max(regionalRouteHistoryTimestampByteCount, MemoryLayout<UInt64>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondRegionalRouteHistoryTimestampBuffer = device.makeBuffer(
        length: max(regionalRouteHistoryTimestampByteCount, MemoryLayout<UInt64>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstRegionalRouteHistoryValueBuffer = device.makeBuffer(
        length: max(regionalRouteHistoryValueByteCount, MemoryLayout<Float>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondRegionalRouteHistoryValueBuffer = device.makeBuffer(
        length: max(regionalRouteHistoryValueByteCount, MemoryLayout<Float>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalResolvedRouteHistorySlotBuffer = device.makeBuffer(
        length: max(regionalResolvedRouteHistorySlotByteCount, MemoryLayout<UInt32>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstRegionalRouteRuntimeStateBuffer = device.makeBuffer(
        length: max(
          regionalRouteRuntimeStateByteCount,
          MemoryLayout<NBRegionalRouteRuntimeState>.stride
        ),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondRegionalRouteRuntimeStateBuffer = device.makeBuffer(
        length: max(
          regionalRouteRuntimeStateByteCount,
          MemoryLayout<NBRegionalRouteRuntimeState>.stride
        ),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalSelectedRouteIndexBuffer = device.makeBuffer(
        length: max(regionalSelectedRouteIndexByteCount, MemoryLayout<UInt32>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let regionalSelectedRouteCountBuffer = device.makeBuffer(
        length: max(regionalSelectedRouteCountByteCount, MemoryLayout<UInt32>.stride),
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let protectiveCommandUniformBuffer = device.makeBuffer(
        length: MemoryLayout<ProtectiveCommandUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let firstProtectiveCommandBuffer = device.makeBuffer(
        length: ProtectiveMotorCommand.byteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondProtectiveCommandBuffer = device.makeBuffer(
        length: ProtectiveMotorCommand.byteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let protectiveMotorProfileBuffer = device.makeBuffer(
        length: protectiveMotorProfileByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let somaticActuatorDescriptorBuffer = device.makeBuffer(
        length: protectiveMotorProfileByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let protectiveSourceInhibitionMaskBuffer = device.makeBuffer(
        length: protectiveMuscleExcitationByteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let zeroDescendingSomaticBuffer = device.makeBuffer(
        length: protectiveMuscleExcitationByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let descendingSomaticBuffer = device.makeBuffer(
        length: protectiveMuscleExcitationByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let fastCPGUniformBuffer = device.makeBuffer(
        length: MemoryLayout<FastCPGUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let stagedFastCPGStateBuffer = device.makeBuffer(
        length: fastCPGStateCapacityByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let fastReflexRuleBuffer = device.makeBuffer(
        length: fastReflexRuleCapacityByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let stagedFastReflexStateBuffer = device.makeBuffer(
        length: fastReflexStateCapacityByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let baselineFastCerebellarStateBuffer = device.makeBuffer(
        length: fastCerebellarStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let stagedFastCerebellarStateBuffer = device.makeBuffer(
        length: fastCerebellarStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let stagedMotorCommandBuffer = device.makeBuffer(
        length: stagedMotorCommandByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let fastAutonomicUniformBuffer = device.makeBuffer(
        length: MemoryLayout<FastAutonomicUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let baselineFastAutonomicStateBuffer = device.makeBuffer(
        length: fastAutonomicStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let stagedFastAutonomicStateBuffer = device.makeBuffer(
        length: fastAutonomicStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let baselineFastAutonomicCommandBuffer = device.makeBuffer(
        length: fastAutonomicCommandByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let stagedFastAutonomicOutputBuffer = device.makeBuffer(
        length: fastAutonomicCommandByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let fastAutonomicChannelDescriptorBuffer = device.makeBuffer(
        length: fastAutonomicChannelDescriptorByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let stagedActiveSensingCommandBuffer = device.makeBuffer(
        length: activeSensingCommandByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let stagedCognitiveEventQueueBuffer = device.makeBuffer(
        length: stagedCognitiveEventQueueByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let defaultRegionalMaturationBuffer = device.makeBuffer(
        length: developmentalMaturationByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let stagedRegionalMaturationBuffer = device.makeBuffer(
        length: developmentalMaturationByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let defaultRegionalPlasticModulationBuffer = device.makeBuffer(
        length: regionalPlasticModulationByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let stagedRegionalPlasticModulationBuffer = device.makeBuffer(
        length: regionalPlasticModulationByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstProtectiveMotorOutputHeaderBuffer = device.makeBuffer(
        length: ProtectiveMotorOutput.headerByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondProtectiveMotorOutputHeaderBuffer = device.makeBuffer(
        length: ProtectiveMotorOutput.headerByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let firstProtectiveMuscleExcitationBuffer = device.makeBuffer(
        length: protectiveMuscleExcitationByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondProtectiveMuscleExcitationBuffer = device.makeBuffer(
        length: protectiveMuscleExcitationByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let stagedAcceptedSomaticOutputBuffer = device.makeBuffer(
        length: protectiveMuscleExcitationByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let stagedAcceptedAutonomicOutputBuffer = device.makeBuffer(
        length: fastAutonomicCommandByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let stagedAcceptedActiveSensingOutputBuffer = device.makeBuffer(
        length: activeSensingCommandByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let bodyLoadFieldUniformBuffer = device.makeBuffer(
        length: MemoryLayout<BodyLoadFieldUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let bodyLoadFieldUpdateBuffer = device.makeBuffer(
        length: bodyLoadFieldUpdateCapacityByteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let firstBodyLoadFieldStateBuffer = device.makeBuffer(
        length: bodyLoadFieldStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondBodyLoadFieldStateBuffer = device.makeBuffer(
        length: bodyLoadFieldStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let bodySchemaUniformBuffer = device.makeBuffer(
        length: MemoryLayout<BodySchemaUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let firstBodySchemaStateBuffer = device.makeBuffer(
        length: bodySchemaStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let secondBodySchemaStateBuffer = device.makeBuffer(
        length: bodySchemaStateByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      ),
      let muscleAttachmentBuffer = device.makeBuffer(
        length: muscleAttachmentByteCount,
        options: [.storageModePrivate, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate scheduler ABI buffers")
    }
    let schedulerClockBuffers: [any MTLBuffer] = [
      firstSchedulerClockBuffer,
      secondSchedulerClockBuffer,
    ]
    let regionalStateBuffers: [any MTLBuffer] = [
      firstRegionalStateBuffer,
      secondRegionalStateBuffer,
    ]
    let regionalTokenStateBuffers: [any MTLBuffer] = [
      firstRegionalTokenStateBuffer,
      secondRegionalTokenStateBuffer,
    ]
    let regionalRouteHistoryStateBuffers: [any MTLBuffer] = [
      firstRegionalRouteHistoryStateBuffer,
      secondRegionalRouteHistoryStateBuffer,
    ]
    let regionalRouteHistoryTimestampBuffers: [any MTLBuffer] = [
      firstRegionalRouteHistoryTimestampBuffer,
      secondRegionalRouteHistoryTimestampBuffer,
    ]
    let regionalRouteHistoryValueBuffers: [any MTLBuffer] = [
      firstRegionalRouteHistoryValueBuffer,
      secondRegionalRouteHistoryValueBuffer,
    ]
    let regionalRouteRuntimeStateBuffers: [any MTLBuffer] = [
      firstRegionalRouteRuntimeStateBuffer,
      secondRegionalRouteRuntimeStateBuffer,
    ]
    let protectiveCommandBuffers: [any MTLBuffer] = [
      firstProtectiveCommandBuffer,
      secondProtectiveCommandBuffer,
    ]
    let protectiveMotorOutputHeaderBuffers: [any MTLBuffer] = [
      firstProtectiveMotorOutputHeaderBuffer,
      secondProtectiveMotorOutputHeaderBuffer,
    ]
    let protectiveMuscleExcitationBuffers: [any MTLBuffer] = [
      firstProtectiveMuscleExcitationBuffer,
      secondProtectiveMuscleExcitationBuffer,
    ]
    let bodyLoadFieldStateBuffers: [any MTLBuffer] = [
      firstBodyLoadFieldStateBuffer,
      secondBodyLoadFieldStateBuffer,
    ]
    let bodySchemaStateBuffers: [any MTLBuffer] = [
      firstBodySchemaStateBuffer,
      secondBodySchemaStateBuffer,
    ]
    schedulerDescriptorBuffer.label = "NumiBrain immutable module descriptors"
    firstSchedulerClockBuffer.label = "NumiBrain scheduler clock generation 0"
    secondSchedulerClockBuffer.label = "NumiBrain scheduler clock generation 1"
    schedulerEventUploadBuffer.label = "NumiBrain committed scheduler event upload"
    schedulerUniformBuffer.label = "NumiBrain scheduler uniforms"
    schedulerInvocationBuffer.label = "NumiBrain compacted due-module invocations"
    schedulerResultBuffer.label = "NumiBrain scheduler result"
    parameterVersionBindingBuffer.label = "NumiBrain immutable parameter-version binding"
    firstRegionalStateBuffer.label = "NumiBrain regional state generation 0"
    secondRegionalStateBuffer.label = "NumiBrain regional state generation 1"
    regionalProgramHeaderBuffer.label = "NumiBrain immutable regional program header"
    regionalLayoutBuffer.label = "NumiBrain immutable region-major token layouts"
    regionalRouteBuffer.label = "NumiBrain immutable sparse regional routes"
    regionalParameterBuffer.label = "NumiBrain immutable regional slow parameters"
    firstRegionalTokenStateBuffer.label = "NumiBrain regional token state generation 0"
    secondRegionalTokenStateBuffer.label = "NumiBrain regional token state generation 1"
    regionalTokenCandidateBuffer.label = "NumiBrain regional token timestamp candidates"
    firstRegionalRouteHistoryStateBuffer.label =
      "NumiBrain regional route-history metadata generation 0"
    secondRegionalRouteHistoryStateBuffer.label =
      "NumiBrain regional route-history metadata generation 1"
    firstRegionalRouteHistoryTimestampBuffer.label =
      "NumiBrain regional route-history timestamps generation 0"
    secondRegionalRouteHistoryTimestampBuffer.label =
      "NumiBrain regional route-history timestamps generation 1"
    firstRegionalRouteHistoryValueBuffer.label =
      "NumiBrain regional route-history values generation 0"
    secondRegionalRouteHistoryValueBuffer.label =
      "NumiBrain regional route-history values generation 1"
    regionalResolvedRouteHistorySlotBuffer.label =
      "NumiBrain resolved delayed regional route slots"
    firstRegionalRouteRuntimeStateBuffer.label =
      "NumiBrain regional routing state generation 0"
    secondRegionalRouteRuntimeStateBuffer.label =
      "NumiBrain regional routing state generation 1"
    regionalSelectedRouteIndexBuffer.label =
      "NumiBrain compacted selected regional route indices"
    regionalSelectedRouteCountBuffer.label =
      "NumiBrain selected regional route counts"
    protectiveCommandUniformBuffer.label = "NumiBrain protective-command uniforms"
    firstProtectiveCommandBuffer.label = "NumiBrain protective command generation 0"
    secondProtectiveCommandBuffer.label = "NumiBrain protective command generation 1"
    protectiveMotorProfileBuffer.label = "NumiBrain immutable protective motor profile"
    somaticActuatorDescriptorBuffer.label =
      "NumiBrain immutable somatic actuator command contracts"
    zeroDescendingSomaticBuffer.label = "NumiBrain zero descending somatic command"
    descendingSomaticBuffer.label = "NumiBrain transaction descending somatic command"
    fastCPGUniformBuffer.label = "NumiBrain accepted fast CPG sampling uniforms"
    stagedFastCPGStateBuffer.label = "NumiBrain transaction fast CPG state"
    fastReflexRuleBuffer.label = "NumiBrain immutable species reflex program"
    stagedFastReflexStateBuffer.label = "NumiBrain transaction fast reflex state"
    baselineFastCerebellarStateBuffer.label =
      "NumiBrain root-baseline fast cerebellar state"
    stagedFastCerebellarStateBuffer.label =
      "NumiBrain transaction fast cerebellar state"
    stagedMotorCommandBuffer.label = "NumiBrain transaction motor command records"
    fastAutonomicUniformBuffer.label = "NumiBrain fast autonomic uniforms"
    baselineFastAutonomicStateBuffer.label =
      "NumiBrain root-baseline fast autonomic state"
    stagedFastAutonomicStateBuffer.label =
      "NumiBrain transaction fast autonomic state"
    baselineFastAutonomicCommandBuffer.label =
      "NumiBrain transaction autonomic baseline"
    stagedFastAutonomicOutputBuffer.label =
      "NumiBrain transaction fast autonomic output"
    fastAutonomicChannelDescriptorBuffer.label =
      "NumiBrain immutable autonomic channel descriptors"
    stagedActiveSensingCommandBuffer.label =
      "NumiBrain transaction active sensing commands"
    stagedCognitiveEventQueueBuffer.label =
      "NumiBrain transaction cognitive receptor events"
    defaultRegionalMaturationBuffer.label =
      "NumiBrain default all-unlocked regional maturation"
    stagedRegionalMaturationBuffer.label =
      "NumiBrain transaction regional maturation"
    defaultRegionalPlasticModulationBuffer.label =
      "NumiBrain default zero regional fast plasticity"
    stagedRegionalPlasticModulationBuffer.label =
      "NumiBrain transaction regional fast plasticity"
    protectiveSourceInhibitionMaskBuffer.label =
      "NumiBrain transaction-local protective source-inhibition mask"
    firstProtectiveMotorOutputHeaderBuffer.label =
      "NumiBrain protective motor header generation 0"
    secondProtectiveMotorOutputHeaderBuffer.label =
      "NumiBrain protective motor header generation 1"
    firstProtectiveMuscleExcitationBuffer.label =
      "NumiBrain protective muscle excitation generation 0"
    secondProtectiveMuscleExcitationBuffer.label =
      "NumiBrain protective muscle excitation generation 1"
    stagedAcceptedSomaticOutputBuffer.label =
      "NumiBrain last accepted physical somatic output"
    stagedAcceptedAutonomicOutputBuffer.label =
      "NumiBrain last accepted physical autonomic output"
    stagedAcceptedActiveSensingOutputBuffer.label =
      "NumiBrain accepted active sensing output"
    bodyLoadFieldUniformBuffer.label = "NumiBrain body-load field uniforms"
    bodyLoadFieldUpdateBuffer.label = "NumiBrain accepted body-load field updates"
    firstBodyLoadFieldStateBuffer.label = "NumiBrain body-load field generation 0"
    secondBodyLoadFieldStateBuffer.label = "NumiBrain body-load field generation 1"
    bodySchemaUniformBuffer.label = "NumiBrain body-schema uniforms"
    firstBodySchemaStateBuffer.label = "NumiBrain body-schema generation 0"
    secondBodySchemaStateBuffer.label = "NumiBrain body-schema generation 1"
    muscleAttachmentBuffer.label = "NumiBrain immutable muscle endpoint map"
    let uniformByteCount = maxEncodedSubsteps * TissueUniforms.byteCount
    guard
      let uniformBuffer = device.makeBuffer(
        length: uniformByteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate the substep uniform arena")
    }
    uniformBuffer.label = "NumiBrain tissue substep uniforms"
    let schedulerInspectionByteCount =
      MemoryLayout<NBReceptorEventTransductionResult>.stride
      + MemoryLayout<NBSchedulerResult>.stride
      + schedulerClockByteCount + schedulerInvocationCapacityByteCount
    let regionalUploadByteCount = max(
      max(
        regionalParameterByteCount,
        regionalRouteHistoryValueByteCount
      ),
      max(
        max(regionalTokenStateByteCount, regionalRouteHistoryTimestampByteCount),
        max(
          max(regionalLayoutByteCount, regionalRouteByteCount),
          max(regionalRouteHistoryStateByteCount, regionalRouteRuntimeStateByteCount)
        )
      )
    )
    guard
      let stagingBuffer = device.makeBuffer(
        length: max(
          max(stateByteCount, schedulerInspectionByteCount),
          max(
            max(eventByteCount, schedulerDescriptorByteCount),
            max(
              schedulerClockByteCount,
              max(
                max(projectionOffsetByteCount, projectionEdgeByteCount),
                max(
                  regionalUploadByteCount,
                  max(
                    max(
                      max(protectiveMotorProfileByteCount, protectiveMuscleExcitationByteCount),
                      max(
                        fastCPGStateCapacityByteCount,
                        max(
                          fastReflexRuleCapacityByteCount,
                          max(
                            fastReflexStateCapacityByteCount,
                            max(
                              fastCerebellarStateByteCount,
                              max(
                                stagedMotorCommandByteCount,
                                max(
                                  fastAutonomicStateByteCount,
                                  max(
                                    fastAutonomicCommandByteCount,
                                    max(
                                      activeSensingCommandByteCount,
                                      max(
                                        fastAutonomicChannelDescriptorByteCount,
                                        stagedCognitiveEventQueueByteCount
                                      )
                                    )
                                  )
                                )
                              )
                            )
                          )
                        )
                      )
                    ),
                    max(
                      developmentalMaturationByteCount,
                      max(
                        max(bodyLoadFieldStateByteCount, bodySchemaStateByteCount),
                        muscleAttachmentByteCount
                      )
                    )
                  )
                )
              )
            )
          )
        ),
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate the explicit upload/inspection buffer")
    }
    stagingBuffer.label = "NumiBrain tissue upload and inspection staging"

    let residencyDescriptor = MTLResidencySetDescriptor()
    residencyDescriptor.label = "NumiBrain tissue residency"
    residencyDescriptor.initialCapacity = stateBuffers.count + 55
      + sharedParameterBank.residencyAllocations.count
    let residencySet: any MTLResidencySet
    do {
      residencySet = try device.makeResidencySet(descriptor: residencyDescriptor)
    } catch {
      throw TissueError.metal("failed to create the residency set: \(error)")
    }
    for buffer in stateBuffers {
      residencySet.addAllocation(buffer)
    }
    for allocation in sharedParameterBank.residencyAllocations {
      residencySet.addAllocation(allocation)
    }
    residencySet.addAllocation(structureBuffer)
    residencySet.addAllocation(delayBuffer)
    residencySet.addAllocation(relayHistoryBuffer)
    residencySet.addAllocation(relayHistoryTimestampBuffer)
    residencySet.addAllocation(relayScratchBuffer)
    residencySet.addAllocation(projectionOffsetBuffer)
    residencySet.addAllocation(projectionEdgeBuffer)
    residencySet.addAllocation(eventBuffer)
    residencySet.addAllocation(activeEventIndexBuffer)
    residencySet.addAllocation(uniformBuffer)
    residencySet.addAllocation(schedulerDescriptorBuffer)
    for buffer in schedulerClockBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(schedulerEventUploadBuffer)
    residencySet.addAllocation(transducedSchedulerEventBuffer)
    residencySet.addAllocation(receptorEventTransductionUniformBuffer)
    residencySet.addAllocation(receptorEventTransductionResultBuffer)
    residencySet.addAllocation(schedulerUniformBuffer)
    residencySet.addAllocation(schedulerInvocationBuffer)
    residencySet.addAllocation(schedulerResultBuffer)
    residencySet.addAllocation(parameterVersionBindingBuffer)
    for buffer in regionalStateBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(regionalProgramHeaderBuffer)
    residencySet.addAllocation(regionalLayoutBuffer)
    residencySet.addAllocation(regionalRouteBuffer)
    residencySet.addAllocation(regionalParameterBuffer)
    for buffer in regionalTokenStateBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(regionalTokenCandidateBuffer)
    for buffer in regionalRouteHistoryStateBuffers {
      residencySet.addAllocation(buffer)
    }
    for buffer in regionalRouteHistoryTimestampBuffers {
      residencySet.addAllocation(buffer)
    }
    for buffer in regionalRouteHistoryValueBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(regionalResolvedRouteHistorySlotBuffer)
    for buffer in regionalRouteRuntimeStateBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(regionalSelectedRouteIndexBuffer)
    residencySet.addAllocation(regionalSelectedRouteCountBuffer)
    residencySet.addAllocation(protectiveCommandUniformBuffer)
    for buffer in protectiveCommandBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(protectiveMotorProfileBuffer)
    residencySet.addAllocation(somaticActuatorDescriptorBuffer)
    residencySet.addAllocation(protectiveSourceInhibitionMaskBuffer)
    residencySet.addAllocation(zeroDescendingSomaticBuffer)
    residencySet.addAllocation(descendingSomaticBuffer)
    residencySet.addAllocation(fastCPGUniformBuffer)
    residencySet.addAllocation(stagedFastCPGStateBuffer)
    residencySet.addAllocation(fastReflexRuleBuffer)
    residencySet.addAllocation(stagedFastReflexStateBuffer)
    residencySet.addAllocation(baselineFastCerebellarStateBuffer)
    residencySet.addAllocation(stagedFastCerebellarStateBuffer)
    residencySet.addAllocation(stagedMotorCommandBuffer)
    residencySet.addAllocation(fastAutonomicUniformBuffer)
    residencySet.addAllocation(baselineFastAutonomicStateBuffer)
    residencySet.addAllocation(stagedFastAutonomicStateBuffer)
    residencySet.addAllocation(baselineFastAutonomicCommandBuffer)
    residencySet.addAllocation(stagedFastAutonomicOutputBuffer)
    residencySet.addAllocation(fastAutonomicChannelDescriptorBuffer)
    residencySet.addAllocation(stagedActiveSensingCommandBuffer)
    residencySet.addAllocation(stagedCognitiveEventQueueBuffer)
    residencySet.addAllocation(defaultRegionalMaturationBuffer)
    residencySet.addAllocation(stagedRegionalMaturationBuffer)
    residencySet.addAllocation(defaultRegionalPlasticModulationBuffer)
    residencySet.addAllocation(stagedRegionalPlasticModulationBuffer)
    for buffer in protectiveMotorOutputHeaderBuffers {
      residencySet.addAllocation(buffer)
    }
    for buffer in protectiveMuscleExcitationBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(stagedAcceptedSomaticOutputBuffer)
    residencySet.addAllocation(stagedAcceptedAutonomicOutputBuffer)
    residencySet.addAllocation(stagedAcceptedActiveSensingOutputBuffer)
    residencySet.addAllocation(bodyLoadFieldUniformBuffer)
    residencySet.addAllocation(bodyLoadFieldUpdateBuffer)
    for buffer in bodyLoadFieldStateBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(bodySchemaUniformBuffer)
    for buffer in bodySchemaStateBuffers {
      residencySet.addAllocation(buffer)
    }
    residencySet.addAllocation(muscleAttachmentBuffer)
    residencySet.addAllocation(stagingBuffer)
    residencySet.commit()
    residencySet.requestResidency()

    self.device = device
    self.deviceName = device.name
    self.deviceRegistryID = device.registryID
    self.width = initialState.width
    self.height = initialState.height
    self.parameters = parameters
    self.stimulus = stimulus
    self.structureHash = structure.stableHash()
    self.delayFieldHash = delayField.stableHash()
    self.connectomeHash = connectome.stableHash()
    self.eventScheduleHash = eventSchedule.stableHash()
    self.eventSchedule = eventSchedule
    self.randomContext = randomContext
    self.brainSchedule = brainSchedule
    self.regionalTokenProgram = regionalTokenProgram
    self.parameterVersion = parameterVersion
    self.sharedParameterBank = sharedParameterBank
    self.protectiveMotorProfile = protectiveMotorProfile
    self.numanXMuscleAttachmentCatalog = requestedNumanXMuscleAttachmentCatalog
    self.bodyLoadFieldDynamics = bodyLoadFieldDynamics
    self.bodySchemaDynamics = bodySchemaDynamics
    self.protectiveSourceInhibitionMaskByteCount = protectiveMuscleExcitationByteCount
    self.schedulerEnvironmentIdentifier = schedulerEnvironmentIdentifier
    self.maximumTissueDelayMicroseconds = maximumTissueDelayMicroseconds
    self.maxEncodedSubsteps = maxEncodedSubsteps
    self.maxSchedulerEvents = maxSchedulerEvents
    self.maxSchedulerInvocations = maxSchedulerInvocations
    self.commandQueue = commandQueue
    self.commandAllocator = commandAllocator
    self.commandBuffer = commandBuffer
    self.tissuePipeline = tissuePipeline
    self.eventCompactionPipeline = eventCompactionPipeline
    self.receptorInterruptTransductionPipeline = receptorInterruptTransductionPipeline
    self.schedulerPipeline = schedulerPipeline
    self.regionalPipeline = regionalPipeline
    self.protectivePipeline = protectivePipeline
    self.protectiveMotorPipeline = protectiveMotorPipeline
    self.bodyLoadFieldPipeline = bodyLoadFieldPipeline
    self.bodySchemaPipeline = bodySchemaPipeline
    self.fastCerebellarPipeline = fastCerebellarPipeline
    self.fastAutonomicPipeline = fastAutonomicPipeline
    self.argumentTable = argumentTable
    self.eventArgumentTable = eventArgumentTable
    self.receptorInterruptArgumentTable = receptorInterruptArgumentTable
    self.schedulerArgumentTable = schedulerArgumentTable
    self.regionalArgumentTable = regionalArgumentTable
    self.protectiveArgumentTable = protectiveArgumentTable
    self.protectiveMotorArgumentTable = protectiveMotorArgumentTable
    self.bodyLoadFieldArgumentTable = bodyLoadFieldArgumentTable
    self.bodySchemaArgumentTable = bodySchemaArgumentTable
    self.fastCerebellarArgumentTable = fastCerebellarArgumentTable
    self.fastAutonomicArgumentTable = fastAutonomicArgumentTable
    self.residencySet = residencySet
    self.stateBuffers = stateBuffers
    self.structureBuffer = structureBuffer
    self.delayBuffer = delayBuffer
    self.relayHistoryBuffer = relayHistoryBuffer
    self.relayHistoryTimestampBuffer = relayHistoryTimestampBuffer
    self.relayScratchBuffer = relayScratchBuffer
    self.projectionOffsetBuffer = projectionOffsetBuffer
    self.projectionEdgeBuffer = projectionEdgeBuffer
    self.eventBuffer = eventBuffer
    self.activeEventIndexBuffer = activeEventIndexBuffer
    self.uniformBuffer = uniformBuffer
    self.schedulerDescriptorBuffer = schedulerDescriptorBuffer
    self.schedulerClockBuffers = schedulerClockBuffers
    self.schedulerEventUploadBuffer = schedulerEventUploadBuffer
    self.transducedSchedulerEventBuffer = transducedSchedulerEventBuffer
    self.receptorEventTransductionUniformBuffer = receptorEventTransductionUniformBuffer
    self.receptorEventTransductionResultBuffer = receptorEventTransductionResultBuffer
    self.schedulerUniformBuffer = schedulerUniformBuffer
    self.schedulerInvocationBuffer = schedulerInvocationBuffer
    self.schedulerResultBuffer = schedulerResultBuffer
    self.parameterVersionBindingBuffer = parameterVersionBindingBuffer
    self.regionalStateBuffers = regionalStateBuffers
    self.regionalProgramHeaderBuffer = regionalProgramHeaderBuffer
    self.regionalLayoutBuffer = regionalLayoutBuffer
    self.regionalRouteBuffer = regionalRouteBuffer
    self.regionalParameterBuffer = regionalParameterBuffer
    self.regionalTokenStateBuffers = regionalTokenStateBuffers
    self.regionalTokenCandidateBuffer = regionalTokenCandidateBuffer
    self.regionalRouteHistoryStateBuffers = regionalRouteHistoryStateBuffers
    self.regionalRouteHistoryTimestampBuffers = regionalRouteHistoryTimestampBuffers
    self.regionalRouteHistoryValueBuffers = regionalRouteHistoryValueBuffers
    self.regionalResolvedRouteHistorySlotBuffer = regionalResolvedRouteHistorySlotBuffer
    self.regionalRouteRuntimeStateBuffers = regionalRouteRuntimeStateBuffers
    self.regionalSelectedRouteIndexBuffer = regionalSelectedRouteIndexBuffer
    self.regionalSelectedRouteCountBuffer = regionalSelectedRouteCountBuffer
    self.protectiveCommandUniformBuffer = protectiveCommandUniformBuffer
    self.protectiveCommandBuffers = protectiveCommandBuffers
    self.protectiveMotorProfileBuffer = protectiveMotorProfileBuffer
    self.somaticActuatorDescriptorBuffer = somaticActuatorDescriptorBuffer
    self.protectiveSourceInhibitionMaskBuffer = protectiveSourceInhibitionMaskBuffer
    self.zeroDescendingSomaticBuffer = zeroDescendingSomaticBuffer
    self.descendingSomaticBuffer = descendingSomaticBuffer
    self.fastCPGUniformBuffer = fastCPGUniformBuffer
    self.stagedFastCPGStateBuffer = stagedFastCPGStateBuffer
    self.fastReflexRuleBuffer = fastReflexRuleBuffer
    self.stagedFastReflexStateBuffer = stagedFastReflexStateBuffer
    self.baselineFastCerebellarStateBuffer = baselineFastCerebellarStateBuffer
    self.stagedFastCerebellarStateBuffer = stagedFastCerebellarStateBuffer
    self.stagedMotorCommandBuffer = stagedMotorCommandBuffer
    self.fastAutonomicUniformBuffer = fastAutonomicUniformBuffer
    self.baselineFastAutonomicStateBuffer = baselineFastAutonomicStateBuffer
    self.stagedFastAutonomicStateBuffer = stagedFastAutonomicStateBuffer
    self.baselineFastAutonomicCommandBuffer = baselineFastAutonomicCommandBuffer
    self.stagedFastAutonomicOutputBuffer = stagedFastAutonomicOutputBuffer
    self.fastAutonomicChannelDescriptorBuffer = fastAutonomicChannelDescriptorBuffer
    self.stagedActiveSensingCommandBuffer = stagedActiveSensingCommandBuffer
    self.stagedCognitiveEventQueueBuffer = stagedCognitiveEventQueueBuffer
    self.defaultRegionalMaturationBuffer = defaultRegionalMaturationBuffer
    self.stagedRegionalMaturationBuffer = stagedRegionalMaturationBuffer
    self.defaultRegionalPlasticModulationBuffer =
      defaultRegionalPlasticModulationBuffer
    self.stagedRegionalPlasticModulationBuffer =
      stagedRegionalPlasticModulationBuffer
    self.protectiveMotorOutputHeaderBuffers = protectiveMotorOutputHeaderBuffers
    self.protectiveMuscleExcitationBuffers = protectiveMuscleExcitationBuffers
    self.stagedAcceptedSomaticOutputBuffer = stagedAcceptedSomaticOutputBuffer
    self.stagedAcceptedAutonomicOutputBuffer = stagedAcceptedAutonomicOutputBuffer
    self.stagedAcceptedActiveSensingOutputBuffer =
      stagedAcceptedActiveSensingOutputBuffer
    self.bodyLoadFieldUniformBuffer = bodyLoadFieldUniformBuffer
    self.bodyLoadFieldUpdateBuffer = bodyLoadFieldUpdateBuffer
    self.bodyLoadFieldStateBuffers = bodyLoadFieldStateBuffers
    self.bodySchemaUniformBuffer = bodySchemaUniformBuffer
    self.bodySchemaStateBuffers = bodySchemaStateBuffers
    self.muscleAttachmentBuffer = muscleAttachmentBuffer
    self.stagingBuffer = stagingBuffer
    self.stateByteCount = stateByteCount
    self.relayByteCount = relayByteCount
    self.relayHistoryByteCount = relayHistoryByteCount
    self.relayHistoryTimestampByteCount = relayHistoryTimestampByteCount
    self.projectionOffsetByteCount = projectionOffsetByteCount
    self.projectionEdgeByteCount = projectionEdgeByteCount
    self.eventByteCount = eventByteCount
    self.activeEventIndexByteCount = activeEventIndexByteCount
    self.schedulerDescriptorByteCount = schedulerDescriptorByteCount
    self.schedulerClockByteCount = schedulerClockByteCount
    self.schedulerEventCapacityByteCount = schedulerEventCapacityByteCount
    self.receptorEventTransductionUniformByteCount =
      MemoryLayout<NBReceptorEventTransductionUniforms>.stride
    self.receptorEventTransductionResultByteCount =
      MemoryLayout<NBReceptorEventTransductionResult>.stride
    self.schedulerInvocationCapacityByteCount = schedulerInvocationCapacityByteCount
    self.parameterVersionBindingByteCount = MemoryLayout<NBParameterVersionBinding>.stride
    self.regionalStateByteCount = regionalStateByteCount
    self.regionalTokenStateByteCount = regionalTokenStateByteCount
    self.regionalRouteByteCount = regionalRouteByteCount
    self.regionalParameterByteCount = regionalParameterByteCount
    self.regionalRouteHistoryStateByteCount = regionalRouteHistoryStateByteCount
    self.regionalRouteHistoryTimestampByteCount = regionalRouteHistoryTimestampByteCount
    self.regionalRouteHistoryValueByteCount = regionalRouteHistoryValueByteCount
    self.regionalRouteRuntimeStateByteCount = regionalRouteRuntimeStateByteCount
    self.regionalSelectedRouteIndexByteCount = regionalSelectedRouteIndexByteCount
    self.regionalSelectedRouteCountByteCount = regionalSelectedRouteCountByteCount
    self.protectiveMotorProfileByteCount = protectiveMotorProfileByteCount
    self.protectiveMuscleExcitationByteCount = protectiveMuscleExcitationByteCount
    self.developmentalMaturationByteCount = developmentalMaturationByteCount
    self.regionalPlasticModulationByteCount = regionalPlasticModulationByteCount
    self.fastCPGStateCapacityByteCount = fastCPGStateCapacityByteCount
    self.fastReflexRuleCapacityByteCount = fastReflexRuleCapacityByteCount
    self.fastReflexStateCapacityByteCount = fastReflexStateCapacityByteCount
    self.fastCerebellarStateByteCount = fastCerebellarStateByteCount
    self.stagedMotorCommandByteCount = stagedMotorCommandByteCount
    self.fastAutonomicStateByteCount = fastAutonomicStateByteCount
    self.fastAutonomicCommandByteCount = fastAutonomicCommandByteCount
    self.fastAutonomicChannelDescriptorByteCount =
      fastAutonomicChannelDescriptorByteCount
    self.activeSensingCommandByteCount = activeSensingCommandByteCount
    self.stagedCognitiveEventQueueByteCount =
      stagedCognitiveEventQueueByteCount
    self.bodyLoadFieldUpdateCapacityByteCount = bodyLoadFieldUpdateCapacityByteCount
    self.bodyLoadFieldStateByteCount = bodyLoadFieldStateByteCount
    self.bodySchemaStateByteCount = bodySchemaStateByteCount
    self.muscleAttachmentByteCount = muscleAttachmentByteCount

    initialState.cells.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: stateByteCount)
    }
    try copy(
      source: stagingBuffer,
      destination: stateBuffers[committedIndex],
      label: "NumiBrain tissue initial upload"
    )
    structure.sites.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: stateByteCount)
    }
    try copy(
      source: stagingBuffer,
      destination: structureBuffer,
      label: "NumiBrain tissue structure upload"
    )
    delayField.delaySteps.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: delayField.count)
    }
    try copy(
      source: stagingBuffer,
      destination: delayBuffer,
      size: delayField.count,
      label: "NumiBrain conduction delay upload"
    )
    let initialRelay = initialState.cells.map(\.w)
    initialRelay.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: relayByteCount)
    }
    try seedRelayHistory()
    let initialRelayTimestamps = [UInt64](
      repeating: 0,
      count: 2 * TissueDelayField.historyCapacity
    )
    initialRelayTimestamps.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: relayHistoryTimestampByteCount
      )
    }
    try copy(
      source: stagingBuffer,
      destination: relayHistoryTimestampBuffer,
      size: relayHistoryTimestampByteCount,
      label: "NumiBrain relay-history timestamp seed"
    )
    connectome.destinationOffsets.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: projectionOffsetByteCount)
    }
    try copy(
      source: stagingBuffer,
      destination: projectionOffsetBuffer,
      size: projectionOffsetByteCount,
      label: "NumiBrain projection offset upload"
    )
    if projectionEdgeByteCount > 0 {
      packedProjectionEdges.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(from: source, byteCount: projectionEdgeByteCount)
      }
      try copy(
        source: stagingBuffer,
        destination: projectionEdgeBuffer,
        size: projectionEdgeByteCount,
        label: "NumiBrain projection edge upload"
      )
    }
    if eventByteCount > 0 {
      packedEvents.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(from: source, byteCount: eventByteCount)
      }
      try copy(
        source: stagingBuffer,
        destination: eventBuffer,
        size: eventByteCount,
        label: "NumiBrain receptor-event upload"
      )
    }
    let descriptorRecords = brainSchedule.modules.map(\.abiRecord)
    descriptorRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: schedulerDescriptorByteCount
      )
    }
    try copy(
      source: stagingBuffer,
      destination: schedulerDescriptorBuffer,
      size: schedulerDescriptorByteCount,
      label: "NumiBrain module descriptor upload"
    )
    var parameterVersionBinding = parameterVersion.abiBinding
    withUnsafeBytes(of: &parameterVersionBinding) { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: MemoryLayout<NBParameterVersionBinding>.stride
      )
    }
    try copy(
      source: stagingBuffer,
      destination: parameterVersionBindingBuffer,
      size: MemoryLayout<NBParameterVersionBinding>.stride,
      label: "NumiBrain parameter-version binding upload"
    )
    let initialClockRecords = brainSchedule.modules.map { _ in
      BrainModuleClockState(nextDue: BrainTimestamp(microseconds: 0)).abiRecord
    }
    initialClockRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: schedulerClockByteCount)
    }
    for (index, buffer) in schedulerClockBuffers.enumerated() {
      try copy(
        source: stagingBuffer,
        destination: buffer,
        size: schedulerClockByteCount,
        label: "NumiBrain scheduler clock generation \(index) upload"
      )
    }
    let initialRegionalRecords = brainSchedule.modules.map { _ in
      RegionalModuleState().abiRecord
    }
    initialRegionalRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: regionalStateByteCount)
    }
    for (index, buffer) in regionalStateBuffers.enumerated() {
      try copy(
        source: stagingBuffer,
        destination: buffer,
        size: regionalStateByteCount,
        label: "NumiBrain regional state generation \(index) upload"
      )
    }
    var regionalHeader = regionalTokenProgram.headerRecord
    withUnsafeBytes(of: &regionalHeader) { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: MemoryLayout<NBRegionalProgramHeader>.stride
      )
    }
    try copy(
      source: stagingBuffer,
      destination: regionalProgramHeaderBuffer,
      size: MemoryLayout<NBRegionalProgramHeader>.stride,
      label: "NumiBrain regional program-header upload"
    )
    let regionalLayoutRecords = regionalTokenProgram.layouts.map(\.abiRecord)
    regionalLayoutRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: regionalLayoutByteCount)
    }
    try copy(
      source: stagingBuffer,
      destination: regionalLayoutBuffer,
      size: regionalLayoutByteCount,
      label: "NumiBrain regional token-layout upload"
    )
    if regionalRouteByteCount > 0 {
      let regionalRouteRecords = regionalTokenProgram.routeABIRecords
      regionalRouteRecords.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(from: source, byteCount: regionalRouteByteCount)
      }
      try copy(
        source: stagingBuffer,
        destination: regionalRouteBuffer,
        size: regionalRouteByteCount,
        label: "NumiBrain sparse regional-route upload"
      )
    }
    let regionalParameterRecords = regionalTokenProgram.parameters.map(\.abiRecord)
    regionalParameterRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: regionalParameterByteCount)
    }
    try copy(
      source: stagingBuffer,
      destination: regionalParameterBuffer,
      size: regionalParameterByteCount,
      label: "NumiBrain regional slow-parameter upload"
    )
    initialRegionalTokenValues.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: regionalTokenStateByteCount)
    }
    for (index, buffer) in regionalTokenStateBuffers.enumerated() {
      try copy(
        source: stagingBuffer,
        destination: buffer,
        size: regionalTokenStateByteCount,
        label: "NumiBrain regional token generation \(index) upload"
      )
    }
    let initialRegionalRouteHistory = RegionalRouteHistory(program: regionalTokenProgram)
    if regionalRouteHistoryStateByteCount > 0 {
      let historyStateRecords = initialRegionalRouteHistory.states.map(\.abiRecord)
      historyStateRecords.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(
          from: source,
          byteCount: regionalRouteHistoryStateByteCount
        )
      }
      for (index, buffer) in regionalRouteHistoryStateBuffers.enumerated() {
        try copy(
          source: stagingBuffer,
          destination: buffer,
          size: regionalRouteHistoryStateByteCount,
          label: "NumiBrain regional route-history metadata generation \(index) upload"
        )
      }
    }
    if regionalRouteHistoryTimestampByteCount > 0 {
      initialRegionalRouteHistory.timestamps.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(
          from: source,
          byteCount: regionalRouteHistoryTimestampByteCount
        )
      }
      for (index, buffer) in regionalRouteHistoryTimestampBuffers.enumerated() {
        try copy(
          source: stagingBuffer,
          destination: buffer,
          size: regionalRouteHistoryTimestampByteCount,
          label: "NumiBrain regional route-history timestamps generation \(index) upload"
        )
      }
    }
    if regionalRouteHistoryValueByteCount > 0 {
      initialRegionalRouteHistory.values.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(
          from: source,
          byteCount: regionalRouteHistoryValueByteCount
        )
      }
      for (index, buffer) in regionalRouteHistoryValueBuffers.enumerated() {
        try copy(
          source: stagingBuffer,
          destination: buffer,
          size: regionalRouteHistoryValueByteCount,
          label: "NumiBrain regional route-history values generation \(index) upload"
        )
      }
    }
    if regionalRouteRuntimeStateByteCount > 0 {
      let routeRuntimeRecords = initialRegionalRoutingState.states.map(\.abiRecord)
      routeRuntimeRecords.withUnsafeBytes { sourceBytes in
        guard let source = sourceBytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(
          from: source,
          byteCount: regionalRouteRuntimeStateByteCount
        )
      }
      for (index, buffer) in regionalRouteRuntimeStateBuffers.enumerated() {
        try copy(
          source: stagingBuffer,
          destination: buffer,
          size: regionalRouteRuntimeStateByteCount,
          label: "NumiBrain regional routing-state generation \(index) upload"
        )
      }
    }
    let initialProtectiveCommand = try ProtectiveMotorCommand.reference(
      timestamp: BrainTimestamp(microseconds: 0),
      brainGeneration: 0,
      environmentIdentifier: schedulerEnvironmentIdentifier,
      schedule: brainSchedule,
      invocations: [],
      regionalStates: brainSchedule.modules.map { _ in RegionalModuleState() }
    )
    var initialProtectiveRecord = initialProtectiveCommand.abiRecord
    withUnsafeBytes(of: &initialProtectiveRecord) { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: ProtectiveMotorCommand.byteCount
      )
    }
    for (index, buffer) in protectiveCommandBuffers.enumerated() {
      try copy(
        source: stagingBuffer,
        destination: buffer,
        size: ProtectiveMotorCommand.byteCount,
        label: "NumiBrain protective command generation \(index) upload"
      )
    }
    let protectiveMotorProfileRecords = protectiveMotorProfile.abiRecords
    protectiveMotorProfileRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: protectiveMotorProfileByteCount
      )
    }
    try copy(
      source: stagingBuffer,
      destination: protectiveMotorProfileBuffer,
      size: protectiveMotorProfileByteCount,
      label: "NumiBrain protective motor-profile upload"
    )
    let initialActuatorDescriptors = protectiveMotorProfile.channels.indices.map {
      SomaticActuatorDescriptor(
        actuatorIdentifier: UInt32($0),
        commandKind: UInt32(ActuatorCommandKind.muscleExcitation.rawValue),
        flags: 1,
        reserved: 0,
        outputMinimum: 0,
        outputMaximum: 1,
        neutralCommand: 0,
        emergencyCommand: 0
      )
    }
    initialActuatorDescriptors.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: protectiveMotorProfileByteCount
      )
    }
    try copy(
      source: stagingBuffer,
      destination: somaticActuatorDescriptorBuffer,
      size: protectiveMotorProfileByteCount,
      label: "NumiBrain default muscle actuator-contract upload"
    )
    protectiveSourceInhibitionMaskBuffer.contents().initializeMemory(
      as: UInt8.self,
      repeating: 0,
      count: protectiveMuscleExcitationByteCount
    )
    stagingBuffer.contents().initializeMemory(
      as: UInt8.self,
      repeating: 0,
      count: protectiveMuscleExcitationByteCount
    )
    try copy(
      source: stagingBuffer,
      destination: zeroDescendingSomaticBuffer,
      size: protectiveMuscleExcitationByteCount,
      label: "NumiBrain zero descending somatic command upload"
    )
    try copy(
      source: stagingBuffer,
      destination: descendingSomaticBuffer,
      size: protectiveMuscleExcitationByteCount,
      label: "NumiBrain initial descending somatic command upload"
    )
    stagingBuffer.contents().initializeMemory(
      as: UInt8.self,
      repeating: 0,
      count: fastCPGStateCapacityByteCount
    )
    try copy(
      source: stagingBuffer,
      destination: stagedFastCPGStateBuffer,
      size: fastCPGStateCapacityByteCount,
      label: "NumiBrain initial fast CPG state upload"
    )
    stagingBuffer.contents().initializeMemory(
      as: UInt8.self,
      repeating: 0,
      count: max(
        fastReflexRuleCapacityByteCount,
        max(
          fastReflexStateCapacityByteCount,
          max(
            fastCerebellarStateByteCount,
            max(
              stagedMotorCommandByteCount,
              max(
                fastAutonomicStateByteCount,
                max(
                  fastAutonomicCommandByteCount,
                  max(
                    activeSensingCommandByteCount,
                    max(
                      fastAutonomicChannelDescriptorByteCount,
                      stagedCognitiveEventQueueByteCount
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
    try copy(
      source: stagingBuffer,
      destination: fastReflexRuleBuffer,
      size: fastReflexRuleCapacityByteCount,
      label: "NumiBrain initial species reflex program upload"
    )
    try copy(
      source: stagingBuffer,
      destination: stagedFastReflexStateBuffer,
      size: fastReflexStateCapacityByteCount,
      label: "NumiBrain initial fast reflex state upload"
    )
    try copy(
      source: stagingBuffer,
      destination: baselineFastCerebellarStateBuffer,
      size: fastCerebellarStateByteCount,
      label: "NumiBrain initial fast cerebellar baseline upload"
    )
    try copy(
      source: stagingBuffer,
      destination: stagedFastCerebellarStateBuffer,
      size: fastCerebellarStateByteCount,
      label: "NumiBrain initial fast cerebellar state upload"
    )
    try copy(
      source: stagingBuffer,
      destination: stagedMotorCommandBuffer,
      size: stagedMotorCommandByteCount,
      label: "NumiBrain initial staged motor-command upload"
    )
    try copy(
      source: stagingBuffer,
      destination: baselineFastAutonomicStateBuffer,
      size: fastAutonomicStateByteCount,
      label: "NumiBrain initial fast autonomic baseline upload"
    )
    try copy(
      source: stagingBuffer,
      destination: stagedFastAutonomicStateBuffer,
      size: fastAutonomicStateByteCount,
      label: "NumiBrain initial fast autonomic state upload"
    )
    try copy(
      source: stagingBuffer,
      destination: baselineFastAutonomicCommandBuffer,
      size: fastAutonomicCommandByteCount,
      label: "NumiBrain initial autonomic baseline upload"
    )
    try copy(
      source: stagingBuffer,
      destination: stagedFastAutonomicOutputBuffer,
      size: fastAutonomicCommandByteCount,
      label: "NumiBrain initial fast autonomic output upload"
    )
    try copy(
      source: stagingBuffer,
      destination: stagedActiveSensingCommandBuffer,
      size: activeSensingCommandByteCount,
      label: "NumiBrain initial active sensing command upload"
    )
    try copy(
      source: stagingBuffer,
      destination: fastAutonomicChannelDescriptorBuffer,
      size: fastAutonomicChannelDescriptorByteCount,
      label: "NumiBrain initial autonomic channel descriptor upload"
    )
    try copy(
      source: stagingBuffer,
      destination: stagedCognitiveEventQueueBuffer,
      size: stagedCognitiveEventQueueByteCount,
      label: "NumiBrain initial cognitive receptor-event queue upload"
    )
    let initialMaturationRecords = brainSchedule.modules.map {
      TissueRegionalMaturationRecord(moduleIdentifier: UInt32($0.moduleIdentifier))
    }
    initialMaturationRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: developmentalMaturationByteCount
      )
    }
    try copy(
      source: stagingBuffer,
      destination: defaultRegionalMaturationBuffer,
      size: developmentalMaturationByteCount,
      label: "NumiBrain default regional maturation upload"
    )
    try copy(
      source: stagingBuffer,
      destination: stagedRegionalMaturationBuffer,
      size: developmentalMaturationByteCount,
      label: "NumiBrain initial regional maturation upload"
    )
    let initialPlasticModulationRecords = brainSchedule.modules.map {
      TissueRegionalPlasticModulationRecord(
        moduleIdentifier: UInt32($0.moduleIdentifier)
      )
    }
    initialPlasticModulationRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: regionalPlasticModulationByteCount
      )
    }
    try copy(
      source: stagingBuffer,
      destination: defaultRegionalPlasticModulationBuffer,
      size: regionalPlasticModulationByteCount,
      label: "NumiBrain default regional fast-plasticity upload"
    )
    try copy(
      source: stagingBuffer,
      destination: stagedRegionalPlasticModulationBuffer,
      size: regionalPlasticModulationByteCount,
      label: "NumiBrain initial regional fast-plasticity upload"
    )
    let initialProtectiveMotorOutput = try ProtectiveMotorOutput.reference(
      command: initialProtectiveCommand,
      profile: protectiveMotorProfile
    )
    var initialProtectiveMotorHeader = initialProtectiveMotorOutput.abiHeader
    withUnsafeBytes(of: &initialProtectiveMotorHeader) { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: ProtectiveMotorOutput.headerByteCount
      )
    }
    for (index, buffer) in protectiveMotorOutputHeaderBuffers.enumerated() {
      try copy(
        source: stagingBuffer,
        destination: buffer,
        size: ProtectiveMotorOutput.headerByteCount,
        label: "NumiBrain protective motor header generation \(index) upload"
      )
    }
    initialProtectiveMotorOutput.muscleExcitations.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: protectiveMuscleExcitationByteCount
      )
    }
    for (index, buffer) in protectiveMuscleExcitationBuffers.enumerated() {
      try copy(
        source: stagingBuffer,
        destination: buffer,
        size: protectiveMuscleExcitationByteCount,
        label: "NumiBrain protective muscle excitation generation \(index) upload"
      )
    }
    var initialBodyLoadRecords = [BodyLoadFieldRecord](
      repeating: BodyLoadFieldRecord(),
      count: max(bodyLoadFieldBodyCount, 1)
    )
    for index in 0..<bodyLoadFieldBodyCount {
      initialBodyLoadRecords[index].bodyIdentifier = UInt32(index)
    }
    initialBodyLoadRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: bodyLoadFieldStateByteCount
      )
    }
    for (index, buffer) in bodyLoadFieldStateBuffers.enumerated() {
      try copy(
        source: stagingBuffer,
        destination: buffer,
        size: bodyLoadFieldStateByteCount,
        label: "NumiBrain body-load field generation \(index) upload"
      )
    }
    var initialBodyLoadUniforms = BodyLoadFieldUniforms(
      attachmentCatalogFingerprint: requestedNumanXMuscleAttachmentCatalog?.fingerprint ?? 0,
      bodyCount: UInt32(bodyLoadFieldBodyCount),
      updateCount: 0,
      targetTimestampMicroseconds: 0,
      persistenceMicroseconds: bodyLoadFieldDynamics.persistenceMicroseconds,
      decayMicroseconds: bodyLoadFieldDynamics.decayMicroseconds
    )
    withUnsafeBytes(of: &initialBodyLoadUniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      bodyLoadFieldUniformBuffer.contents().copyMemory(
        from: source,
        byteCount: bytes.count
      )
    }
    bodyLoadFieldUpdateBuffer.contents().initializeMemory(
      as: UInt8.self,
      repeating: 0,
      count: bodyLoadFieldUpdateCapacityByteCount
    )
    let initialBodySchemaRecords: [BodySchemaRecord]
    if bodyLoadFieldBodyCount > 0 {
      initialBodySchemaRecords = try bodySchemaDynamics.initialState(
        bodyCount: UInt32(bodyLoadFieldBodyCount)
      ).map(BodySchemaRecord.init(cell:))
    } else {
      var empty = BodySchemaRecord()
      empty.epistemicVariance = bodySchemaDynamics.initialVariance
      initialBodySchemaRecords = [empty]
    }
    initialBodySchemaRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: bodySchemaStateByteCount
      )
    }
    for (index, buffer) in bodySchemaStateBuffers.enumerated() {
      try copy(
        source: stagingBuffer,
        destination: buffer,
        size: bodySchemaStateByteCount,
        label: "NumiBrain body-schema generation \(index) upload"
      )
    }
    var initialBodySchemaUniforms = BodySchemaUniforms(
      bodyCount: UInt32(bodyLoadFieldBodyCount),
      reserved0: 0,
      targetTimestampMicroseconds: 0,
      forceScaleNewtons: bodySchemaDynamics.forceScaleNewtons,
      loadTimeConstantMicroseconds: bodySchemaDynamics.loadTimeConstantMicroseconds,
      initialVariance: bodySchemaDynamics.initialVariance,
      maximumVariance: bodySchemaDynamics.maximumVariance,
      processVariancePerSecond: bodySchemaDynamics.processVariancePerSecond,
      observationVariance: bodySchemaDynamics.observationVariance,
      vulnerabilityGainPerSecond: bodySchemaDynamics.vulnerabilityGainPerSecond,
      recoveryPerSecond: bodySchemaDynamics.recoveryPerSecond,
      uncertaintyRiskWeight: bodySchemaDynamics.uncertaintyRiskWeight,
      reserved1: 0
    )
    withUnsafeBytes(of: &initialBodySchemaUniforms) { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      bodySchemaUniformBuffer.contents().copyMemory(
        from: source,
        byteCount: sourceBytes.count
      )
    }
    let attachmentRecords: [MuscleAttachmentRecord]
    if let requestedNumanXMuscleAttachmentCatalog {
      attachmentRecords = requestedNumanXMuscleAttachmentCatalog.attachments.map {
        MuscleAttachmentRecord(
          muscleIdentifier: $0.muscleIdentifier,
          firstBodyIdentifier: $0.firstBodyIdentifier,
          terminalBodyIdentifier: $0.terminalBodyIdentifier,
          reserved: 0
        )
      }
    } else {
      attachmentRecords = protectiveMotorProfile.channels.map {
        MuscleAttachmentRecord(muscleIdentifier: $0.muscleIdentifier)
      }
    }
    attachmentRecords.withUnsafeBytes { sourceBytes in
      guard let source = sourceBytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(
        from: source,
        byteCount: muscleAttachmentByteCount
      )
    }
    try copy(
      source: stagingBuffer,
      destination: muscleAttachmentBuffer,
      size: muscleAttachmentByteCount,
      label: "NumiBrain muscle endpoint-map upload"
    )
  }

  deinit {
    residencySet.endResidency()
  }

  public var hasPendingRootTransaction: Bool {
    pendingRootShadowIndex != nil
  }

  public var hasPendingJointTransaction: Bool {
    pendingJointTransaction != nil
  }

  public var hasOpenInteractiveJointControl: Bool {
    interactiveJointRoot != nil
  }

  public var residencyAllocatedBytes: UInt64 {
    residencySet.allocatedSize
  }

  public var schedulerCommittedTimestamp: BrainTimestamp? {
    committedSchedulerTime
  }

  public var schedulerCommittedGeneration: UInt64 {
    committedSchedulerGeneration
  }

  public var schedulerUniformByteCount: Int {
    MemoryLayout<NBSchedulerUniforms>.stride
  }

  public var schedulerResultByteCount: Int {
    MemoryLayout<NBSchedulerResult>.stride
  }

  public func committedRegionalRecurrentBufferView()
    throws -> MetalRegionalRecurrentBufferView
  {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before borrowing committed recurrence")
    }
    return try MetalRegionalRecurrentBufferView(
      gpuAddress: regionalTokenStateBuffers[committedRegionalStateIndex].gpuAddress,
      scalarCount: regionalTokenProgram.scalarCount,
      regionalProgramFingerprint: regionalTokenProgram.fingerprint
    )
  }

  public func pendingRegionalRecurrentBufferView()
    throws -> MetalRegionalRecurrentBufferView
  {
    guard pendingRootShadowIndex != nil, let pendingRegionalStateIndex else {
      throw TissueError.transaction("encode a root before borrowing shadow recurrence")
    }
    return try MetalRegionalRecurrentBufferView(
      gpuAddress: regionalTokenStateBuffers[pendingRegionalStateIndex].gpuAddress,
      scalarCount: regionalTokenProgram.scalarCount,
      regionalProgramFingerprint: regionalTokenProgram.fingerprint
    )
  }

  /// Compiles the immutable species reflex graph into bounded receptor to
  /// actuator rules. Mutable rule history remains in the per-agent shadow
  /// state and is never shared across minds.
  func bindSpeciesReflexProgram(_ species: SpeciesTemplate) throws {
    guard pendingRootShadowIndex == nil, pendingJointTransaction == nil,
      interactiveJointRoot == nil,
      Int(species.motor.actuatorCount) == protectiveMotorProfile.channels.count,
      Int(species.physiology.autonomicActionDimension)
        <= Self.maximumFastAutonomicChannelCount,
      Int(species.motor.activeSensingActionDimension)
        <= Self.maximumActiveSensingChannelCount
    else {
      throw TissueError.transaction(
        "species reflex program cannot bind to this active motor runtime"
      )
    }
    var rules: [FastReflexRule] = []
    for reflex in species.reflexes {
      for receptorIdentifier in reflex.receptorChannelCodes {
        for actuatorIdentifier in reflex.actuatorIdentifiers {
          rules.append(
            FastReflexRule(
              receptorIdentifier: receptorIdentifier,
              actuatorIdentifier: actuatorIdentifier,
              circuitIdentifier: UInt32(reflex.identifier),
              circuitKind: UInt32(reflex.kind.rawValue),
              latencyMicroseconds: reflex.latencyMicroseconds,
              flags: 1 | (reflex.innateEnabled ? 1 << 1 : 0),
              activationThreshold: reflex.activationThreshold,
              gain: reflex.gain
            )
          )
        }
      }
    }
    guard rules.count <= Self.maximumFastReflexRuleCount,
      rules.count * MemoryLayout<FastReflexRule>.stride
        <= fastReflexRuleCapacityByteCount
    else {
      throw TissueError.metal("species reflex program exceeds fast GPU capacity")
    }
    if !rules.isEmpty {
      rules.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        stagingBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
      }
      try copy(
        source: stagingBuffer,
        destination: fastReflexRuleBuffer,
        size: rules.count * MemoryLayout<FastReflexRule>.stride,
        label: "NumiBrain species reflex-program upload"
      )
    }
    let autonomicDescriptors = species.physiology.autonomicChannels.map { channel in
      let identifiers = channel.criticalReceptorIdentifiers
        + Array(repeating: 0, count: 4 - channel.criticalReceptorIdentifiers.count)
      return FastAutonomicChannelDescriptor(
        channelIdentifier: UInt32(channel.identifier),
        kind: UInt32(channel.kind.rawValue),
        flags: 1 | (channel.respondsToAnyPhysiologicalCritical ? 1 << 1 : 0),
        criticalReceptorCount: UInt32(channel.criticalReceptorIdentifiers.count),
        criticalReceptor0: identifiers[0],
        criticalReceptor1: identifiers[1],
        criticalReceptor2: identifiers[2],
        criticalReceptor3: identifiers[3],
        emergencyTarget: channel.emergencyTarget,
        emergencyGain: channel.emergencyGain,
        cpgGain: channel.cpgGain,
        reserved: 0
      )
    }
    guard autonomicDescriptors.count == Int(species.physiology.autonomicActionDimension),
      autonomicDescriptors.count * MemoryLayout<FastAutonomicChannelDescriptor>.stride
        <= fastAutonomicChannelDescriptorByteCount
    else {
      throw TissueError.metal("species autonomic program exceeds fast GPU capacity")
    }
    autonomicDescriptors.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    try copy(
      source: stagingBuffer,
      destination: fastAutonomicChannelDescriptorBuffer,
      size: autonomicDescriptors.count
        * MemoryLayout<FastAutonomicChannelDescriptor>.stride,
      label: "NumiBrain species autonomic-program upload"
    )
    let actuatorDescriptors = species.motor.actuatorChannels.map { channel in
      SomaticActuatorDescriptor(
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
    guard actuatorDescriptors.count == protectiveMotorProfile.channels.count,
      actuatorDescriptors.count * MemoryLayout<SomaticActuatorDescriptor>.stride
        == protectiveMotorProfileByteCount
    else {
      throw TissueError.metal("species somatic adapter does not match the motor runtime")
    }
    actuatorDescriptors.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      stagingBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    try copy(
      source: stagingBuffer,
      destination: somaticActuatorDescriptorBuffer,
      size: protectiveMotorProfileByteCount,
      label: "NumiBrain species somatic actuator-contract upload"
    )
    boundFastReflexSpeciesFingerprint = species.fingerprint
    boundFastReflexRuleCount = rules.count
    boundFastAutonomicChannelCount = Int(
      species.physiology.autonomicActionDimension
    )
    boundActiveSensingChannelCount = Int(
      species.motor.activeSensingActionDimension
    )
    boundActuatorCommandKind = species.motor.actuatorCommandKind
    boundFastAutonomicVitalGain = species.innateBehaviors
      .filter { $0.kind == .vitalAutonomic }
      .map(\.gain)
      .max() ?? 0
  }

  /// Creates the stable root identity used by a NumanX shadow transaction.
  /// Physical state remains external and is represented only by acceptance
  /// tokens returned through `BrainJointTransaction`.
  public func beginJointControl(
    controlStepIdentifier: UInt64,
    basePhysicsGeneration: UInt64,
    committedTimestamp: BrainTimestamp,
    targetTimestamp: BrainTimestamp
  ) throws -> BrainJointTransaction {
    guard pendingRootShadowIndex == nil, pendingJointTransaction == nil,
      interactiveJointRoot == nil
    else {
      throw TissueError.transaction("commit or abort the pending Metal root first")
    }
    guard randomContext.environmentIdentifier == schedulerEnvironmentIdentifier else {
      throw TissueError.transaction(
        "joint transaction environment does not match the counter-random context"
      )
    }
    if let committedSchedulerTime, committedSchedulerTime != committedTimestamp {
      throw TissueError.transaction(
        "joint root time does not match committed Metal scheduler time"
      )
    }
    let token = try BrainJointTransactionToken(
      environmentIdentifier: schedulerEnvironmentIdentifier,
      episodeIdentifier: UInt64(randomContext.episodeIdentifier),
      controlStepIdentifier: controlStepIdentifier,
      parameterVersionFingerprint: parameterVersion.fingerprint,
      baseBrainGeneration: committedSchedulerGeneration,
      basePhysicsGeneration: basePhysicsGeneration,
      committedTimestamp: committedTimestamp,
      targetTimestamp: targetTimestamp,
      randomCounterGeneration: committedStep
    )
    return BrainJointTransaction(token: token)
  }

  /// Opens an interactive root whose tissue candidate is executed before the
  /// caller returns NumanX acceptance or rejection. No committed generation is
  /// published until `finishInteractiveJointControl` and joint commit.
  public func beginInteractiveJointControl(
    controlStepIdentifier: UInt64,
    basePhysicsGeneration: UInt64,
    committedTimestamp: BrainTimestamp,
    targetTimestamp: BrainTimestamp
  ) throws -> BrainJointTransactionToken {
    let transaction = try beginJointControl(
      controlStepIdentifier: controlStepIdentifier,
      basePhysicsGeneration: basePhysicsGeneration,
      committedTimestamp: committedTimestamp,
      targetTimestamp: targetTimestamp
    )
    interactiveJointRoot = InteractiveJointRoot(
      transaction: transaction,
      rootShadowIndex: committedIndex,
      historyOwnerMask: committedHistoryOwnerMask,
      historyStep: committedStep,
      relayHistoryTimestamps: committedRelayHistoryTimestamps,
      acceptedTimestamp: committedTimestamp,
      candidate: nil,
      fastSchedulerWindow: nil,
      firstGPUStartSeconds: nil,
      lastGPUEndSeconds: nil
    )
    descendingSomaticTransactionFingerprint = nil
    stagedFastCPGTransactionFingerprint = nil
    stagedFastCPGOscillatorCount = 0
    stagedFastCPGSynergyCount = 0
    protectiveSourceInhibitionMaskBuffer.contents().initializeMemory(
      as: UInt8.self,
      repeating: 0,
      count: protectiveSourceInhibitionMaskByteCount
    )
    writeFastCPGUniforms(timestamp: committedTimestamp)
    return transaction.token
  }

  /// Copies the high-level brain's contiguous somatic and autonomic commands
  /// into the fast tissue runtime entirely on GPU. Reflex, body-risk,
  /// localized injury inhibition, and vital overrides remain authoritative
  /// overlays in substep kernels.
  public func stageDescendingSomaticCommand(
    _ lease: MetalEmbodiedBrainRuntime.NumanXSomaticBufferLease,
    for transaction: BrainJointTransactionToken
  ) throws {
    let (cognitiveEventRecordBytes, cognitiveEventRecordOverflow) =
      lease.decision.receptorEventMaximumCount.multipliedReportingOverflow(
        by: Self.cognitiveEventRecordStride
      )
    let (cognitiveEventQueueBytes, cognitiveEventQueueOverflow) =
      Self.cognitiveEventQueueHeaderStride.addingReportingOverflow(
        cognitiveEventRecordBytes
      )
    guard let root = interactiveJointRoot,
      root.transaction.token == transaction,
      root.candidate == nil,
      lease.decision.transactionFingerprint == transaction.fingerprint,
      lease.decision.shadowGeneration == transaction.shadowGeneration,
      lease.decision.somaticOutputCount == protectiveMotorProfile.channels.count,
      lease.decision.somaticOutputByteCount == protectiveMuscleExcitationByteCount,
      lease.decision.regionalMaturationCount == brainSchedule.modules.count,
      lease.decision.regionalMaturationByteCount
        == developmentalMaturationByteCount,
      lease.decision.regionalPlasticModulationCount == brainSchedule.modules.count,
      lease.decision.regionalPlasticModulationByteCount
        == regionalPlasticModulationByteCount,
      lease.decision.cpgStateCount <= Self.maximumFastCPGOscillatorCount,
      lease.decision.cpgStateByteCount
        == lease.decision.cpgStateCount * Self.fastCPGStateStride,
      lease.decision.cpgStateByteCount <= fastCPGStateCapacityByteCount,
      lease.decision.cpgSynergyCount > 0,
      boundFastReflexSpeciesFingerprint == lease.speciesTemplateFingerprint,
      lease.decision.reflexStateCount == boundFastReflexRuleCount,
      lease.decision.reflexStateByteCount
        == lease.decision.reflexStateCount * Self.fastReflexStateStride,
      lease.decision.reflexStateByteCount <= fastReflexStateCapacityByteCount,
      lease.decision.fastCerebellarStateCount
        == protectiveMotorProfile.channels.count,
      lease.decision.fastCerebellarStateByteCount
        == fastCerebellarStateByteCount,
      lease.decision.motorCommandCount == protectiveMotorProfile.channels.count,
      lease.decision.autonomicCommandCount == boundFastAutonomicChannelCount,
      lease.decision.fastAutonomicStateCount == boundFastAutonomicChannelCount,
      lease.decision.fastAutonomicStateByteCount
        == boundFastAutonomicChannelCount * Self.fastAutonomicStateStride,
      lease.decision.activeSensingCommandCount == boundActiveSensingChannelCount,
      !cognitiveEventRecordOverflow, !cognitiveEventQueueOverflow,
      lease.decision.receptorEventMaximumCount <= maxSchedulerEvents,
      lease.decision.receptorEventMaximumCount
        <= Self.maximumCognitiveEventCount,
      cognitiveEventQueueBytes <= stagedCognitiveEventQueueByteCount,
      lease.descendingBaselineSourceOffset <= lease.buffer.length,
      protectiveMuscleExcitationByteCount
        <= lease.buffer.length - lease.descendingBaselineSourceOffset,
      lease.maturationSourceOffset <= lease.buffer.length,
      developmentalMaturationByteCount
        <= lease.buffer.length - lease.maturationSourceOffset,
      lease.plasticModulationSourceOffset <= lease.buffer.length,
      regionalPlasticModulationByteCount
        <= lease.buffer.length - lease.plasticModulationSourceOffset,
      lease.cpgStateSourceOffset <= lease.buffer.length,
      lease.decision.cpgStateByteCount
        <= lease.buffer.length - lease.cpgStateSourceOffset,
      lease.reflexStateSourceOffset <= lease.buffer.length,
      lease.decision.reflexStateByteCount
        <= lease.buffer.length - lease.reflexStateSourceOffset,
      lease.fastCerebellarStateSourceOffset <= lease.buffer.length,
      fastCerebellarStateByteCount
        <= lease.buffer.length - lease.fastCerebellarStateSourceOffset,
      lease.motorCommandSourceOffset <= lease.buffer.length,
      stagedMotorCommandByteCount
        <= lease.buffer.length - lease.motorCommandSourceOffset,
      lease.autonomicSourceOffset <= lease.buffer.length,
      boundFastAutonomicChannelCount * Self.autonomicCommandStride
        <= lease.buffer.length - lease.autonomicSourceOffset,
      lease.fastAutonomicStateSourceOffset <= lease.buffer.length,
      lease.decision.fastAutonomicStateByteCount
        <= lease.buffer.length - lease.fastAutonomicStateSourceOffset,
      lease.activeSensingSourceOffset <= lease.buffer.length,
      boundActiveSensingChannelCount * Self.activeSensingCommandStride
        <= lease.buffer.length - lease.activeSensingSourceOffset,
      lease.receptorEventQueueSourceOffset <= lease.buffer.length,
      cognitiveEventQueueBytes
        <= lease.buffer.length - lease.receptorEventQueueSourceOffset
    else {
      throw TissueError.transaction(
        "descending somatic command is stale or incompatible with the NumanX motor profile"
      )
    }
    let descriptor = MTLResidencySetDescriptor()
    descriptor.label = "NumiBrain borrowed embodied somatic residency"
    descriptor.initialCapacity = 1
    let borrowedResidency: any MTLResidencySet
    do {
      borrowedResidency = try device.makeResidencySet(descriptor: descriptor)
    } catch {
      throw TissueError.metal("failed to retain embodied somatic allocation: \(error)")
    }
    borrowedResidency.addAllocation(lease.buffer)
    borrowedResidency.commit()
    borrowedResidency.requestResidency()
    defer { borrowedResidency.endResidency() }
    writeCognitiveEventTransductionUniforms(
      timestamp: lease.decision.decisionTimestamp,
      maximumEventCount: lease.decision.receptorEventMaximumCount
    )
    writeFastCPGUniforms(
      timestamp: lease.decision.decisionTimestamp,
      oscillatorCount: lease.decision.cpgStateCount,
      synergyCount: lease.decision.cpgSynergyCount,
      consumeInterruptEvents: true
    )
    writeFastAutonomicUniforms(
      timestamp: lease.decision.decisionTimestamp,
      baselineTimestamp: lease.decision.decisionTimestamp,
      oscillatorCount: lease.decision.cpgStateCount,
      consumeInterruptEvents: true
    )
    writeProtectiveCommandUniforms(
      brainGeneration: transaction.shadowGeneration
    )
    let initialMotorStateIndex = 1 - committedSchedulerClockIndex
    _ = try submit(
      label: "NumiBrain descending somatic GPU handoff",
      additionalResidencySet: borrowedResidency
    ) { encoder in
      encoder.copy(
        sourceBuffer: lease.buffer,
        sourceOffset: lease.descendingBaselineSourceOffset,
        destinationBuffer: descendingSomaticBuffer,
        destinationOffset: 0,
        size: protectiveMuscleExcitationByteCount
      )
      encoder.copy(
        sourceBuffer: lease.buffer,
        sourceOffset: lease.maturationSourceOffset,
        destinationBuffer: stagedRegionalMaturationBuffer,
        destinationOffset: 0,
        size: developmentalMaturationByteCount
      )
      encoder.copy(
        sourceBuffer: lease.buffer,
        sourceOffset: lease.plasticModulationSourceOffset,
        destinationBuffer: stagedRegionalPlasticModulationBuffer,
        destinationOffset: 0,
        size: regionalPlasticModulationByteCount
      )
      if lease.decision.cpgStateByteCount > 0 {
        encoder.copy(
          sourceBuffer: lease.buffer,
          sourceOffset: lease.cpgStateSourceOffset,
          destinationBuffer: stagedFastCPGStateBuffer,
          destinationOffset: 0,
          size: lease.decision.cpgStateByteCount
        )
      }
      if lease.decision.reflexStateByteCount > 0 {
        encoder.copy(
          sourceBuffer: lease.buffer,
          sourceOffset: lease.reflexStateSourceOffset,
          destinationBuffer: stagedFastReflexStateBuffer,
          destinationOffset: 0,
          size: lease.decision.reflexStateByteCount
        )
      }
      encoder.copy(
        sourceBuffer: lease.buffer,
        sourceOffset: lease.fastCerebellarStateSourceOffset,
        destinationBuffer: baselineFastCerebellarStateBuffer,
        destinationOffset: 0,
        size: fastCerebellarStateByteCount
      )
      encoder.copy(
        sourceBuffer: lease.buffer,
        sourceOffset: lease.fastCerebellarStateSourceOffset,
        destinationBuffer: stagedFastCerebellarStateBuffer,
        destinationOffset: 0,
        size: fastCerebellarStateByteCount
      )
      encoder.copy(
        sourceBuffer: lease.buffer,
        sourceOffset: lease.motorCommandSourceOffset,
        destinationBuffer: stagedMotorCommandBuffer,
        destinationOffset: 0,
        size: stagedMotorCommandByteCount
      )
      encoder.copy(
        sourceBuffer: lease.buffer,
        sourceOffset: lease.autonomicSourceOffset,
        destinationBuffer: baselineFastAutonomicCommandBuffer,
        destinationOffset: 0,
        size: boundFastAutonomicChannelCount * Self.autonomicCommandStride
      )
      encoder.copy(
        sourceBuffer: lease.buffer,
        sourceOffset: lease.fastAutonomicStateSourceOffset,
        destinationBuffer: baselineFastAutonomicStateBuffer,
        destinationOffset: 0,
        size: lease.decision.fastAutonomicStateByteCount
      )
      if boundActiveSensingChannelCount > 0 {
        encoder.copy(
          sourceBuffer: lease.buffer,
          sourceOffset: lease.activeSensingSourceOffset,
          destinationBuffer: stagedActiveSensingCommandBuffer,
          destinationOffset: 0,
          size: boundActiveSensingChannelCount * Self.activeSensingCommandStride
        )
      }
      encoder.copy(
        sourceBuffer: lease.buffer,
        sourceOffset: lease.receptorEventQueueSourceOffset,
        destinationBuffer: stagedCognitiveEventQueueBuffer,
        destinationOffset: 0,
        size: cognitiveEventQueueBytes
      )
      encoder.copy(
        sourceBuffer: lease.buffer,
        sourceOffset: lease.fastAutonomicStateSourceOffset,
        destinationBuffer: stagedFastAutonomicStateBuffer,
        destinationOffset: 0,
        size: lease.decision.fastAutonomicStateByteCount
      )
      encoder.copy(
        sourceBuffer: protectiveCommandBuffers[committedSchedulerClockIndex],
        sourceOffset: 0,
        destinationBuffer: protectiveCommandBuffers[initialMotorStateIndex],
        destinationOffset: 0,
        size: ProtectiveMotorCommand.byteCount
      )
      encoder.barrier(
        afterEncoderStages: .blit,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      receptorInterruptArgumentTable.setAddress(
        receptorEventTransductionUniformBuffer.gpuAddress,
        index: 0
      )
      receptorInterruptArgumentTable.setAddress(eventBuffer.gpuAddress, index: 1)
      receptorInterruptArgumentTable.setAddress(
        schedulerEventUploadBuffer.gpuAddress,
        index: 2
      )
      receptorInterruptArgumentTable.setAddress(
        transducedSchedulerEventBuffer.gpuAddress,
        index: 3
      )
      receptorInterruptArgumentTable.setAddress(
        receptorEventTransductionResultBuffer.gpuAddress,
        index: 4
      )
      receptorInterruptArgumentTable.setAddress(
        stagedCognitiveEventQueueBuffer.gpuAddress,
        index: 5
      )
      encoder.setComputePipelineState(receptorInterruptTransductionPipeline)
      encoder.setArgumentTable(receptorInterruptArgumentTable)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      fastAutonomicArgumentTable.setAddress(
        fastAutonomicUniformBuffer.gpuAddress,
        index: 0
      )
      fastAutonomicArgumentTable.setAddress(
        baselineFastAutonomicCommandBuffer.gpuAddress,
        index: 1
      )
      fastAutonomicArgumentTable.setAddress(
        transducedSchedulerEventBuffer.gpuAddress,
        index: 2
      )
      fastAutonomicArgumentTable.setAddress(
        receptorEventTransductionResultBuffer.gpuAddress,
        index: 3
      )
      fastAutonomicArgumentTable.setAddress(
        baselineFastAutonomicStateBuffer.gpuAddress,
        index: 4
      )
      fastAutonomicArgumentTable.setAddress(
        stagedFastAutonomicStateBuffer.gpuAddress,
        index: 5
      )
      fastAutonomicArgumentTable.setAddress(
        stagedFastAutonomicOutputBuffer.gpuAddress,
        index: 6
      )
      fastAutonomicArgumentTable.setAddress(
        stagedFastCPGStateBuffer.gpuAddress,
        index: 7
      )
      fastAutonomicArgumentTable.setAddress(
        fastAutonomicChannelDescriptorBuffer.gpuAddress,
        index: 8
      )
      encoder.setComputePipelineState(fastAutonomicPipeline)
      encoder.setArgumentTable(fastAutonomicArgumentTable)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(
          width: boundFastAutonomicChannelCount,
          height: 1,
          depth: 1
        ),
        threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
      )
      protectiveMotorArgumentTable.setAddress(
        protectiveCommandBuffers[initialMotorStateIndex].gpuAddress,
        index: 0
      )
      protectiveMotorArgumentTable.setAddress(
        protectiveMotorProfileBuffer.gpuAddress,
        index: 1
      )
      protectiveMotorArgumentTable.setAddress(
        protectiveCommandUniformBuffer.gpuAddress,
        index: 2
      )
      protectiveMotorArgumentTable.setAddress(
        protectiveMotorOutputHeaderBuffers[initialMotorStateIndex].gpuAddress,
        index: 3
      )
      protectiveMotorArgumentTable.setAddress(
        protectiveMuscleExcitationBuffers[initialMotorStateIndex].gpuAddress,
        index: 4
      )
      protectiveMotorArgumentTable.setAddress(
        protectiveSourceInhibitionMaskBuffer.gpuAddress,
        index: 5
      )
      protectiveMotorArgumentTable.setAddress(
        bodyLoadFieldUniformBuffer.gpuAddress,
        index: 6
      )
      protectiveMotorArgumentTable.setAddress(
        bodyLoadFieldStateBuffers[committedBodyLoadFieldStateIndex].gpuAddress,
        index: 7
      )
      protectiveMotorArgumentTable.setAddress(muscleAttachmentBuffer.gpuAddress, index: 8)
      protectiveMotorArgumentTable.setAddress(
        bodySchemaStateBuffers[committedBodyLoadFieldStateIndex].gpuAddress,
        index: 9
      )
      protectiveMotorArgumentTable.setAddress(descendingSomaticBuffer.gpuAddress, index: 10)
      protectiveMotorArgumentTable.setAddress(fastCPGUniformBuffer.gpuAddress, index: 11)
      protectiveMotorArgumentTable.setAddress(stagedFastCPGStateBuffer.gpuAddress, index: 12)
      protectiveMotorArgumentTable.setAddress(
        transducedSchedulerEventBuffer.gpuAddress,
        index: 13
      )
      protectiveMotorArgumentTable.setAddress(
        receptorEventTransductionResultBuffer.gpuAddress,
        index: 14
      )
      protectiveMotorArgumentTable.setAddress(fastReflexRuleBuffer.gpuAddress, index: 15)
      protectiveMotorArgumentTable.setAddress(
        stagedFastReflexStateBuffer.gpuAddress,
        index: 16
      )
      protectiveMotorArgumentTable.setAddress(
        stagedFastCerebellarStateBuffer.gpuAddress,
        index: 17
      )
      protectiveMotorArgumentTable.setAddress(
        somaticActuatorDescriptorBuffer.gpuAddress,
        index: 18
      )
      encoder.setComputePipelineState(protectiveMotorPipeline)
      encoder.setArgumentTable(protectiveMotorArgumentTable)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
      )
    }
    descendingSomaticTransactionFingerprint = transaction.fingerprint
    stagedFastCPGTransactionFingerprint = transaction.fingerprint
    stagedFastCPGOscillatorCount = lease.decision.cpgStateCount
    stagedFastCPGSynergyCount = lease.decision.cpgSynergyCount
    stagedCognitiveEventTransactionFingerprint = transaction.fingerprint
    stagedCognitiveEventMaximumCount =
      lease.decision.receptorEventMaximumCount
  }

  /// Advances one neural tissue candidate without publishing it. Corrected
  /// durations may shrink from the nominal tissue step; local and sparse
  /// conduction still resolve against accepted physical timestamps.
  public func advanceFastSystems(
    candidateDurationMicroseconds: UInt64
  ) throws -> FastSystemResult {
    guard var root = interactiveJointRoot else {
      throw TissueError.transaction("begin interactive joint control first")
    }
    guard root.candidate == nil else {
      throw TissueError.transaction("accept or reject the active neural candidate first")
    }
    guard root.transaction.acceptedSubstepCount < UInt32(TissueDelayField.historyCapacity) else {
      throw TissueError.transaction(
        "interactive root exhausted its \(TissueDelayField.historyCapacity)-slot delayed history"
      )
    }
    let nominalDuration = try schedulerTimestamp(
      milliseconds: parameters.timestepMilliseconds
    ).rawValue
    guard candidateDurationMicroseconds > 0,
      candidateDurationMicroseconds <= nominalDuration
    else {
      throw TissueError.transaction(
        "interactive candidate duration must be positive and no larger than the nominal tissue step"
      )
    }
    var transaction = root.transaction
    let substep = try transaction.beginPhysicsSubstep(
      durationMicroseconds: candidateDurationMicroseconds
    )
    guard substep.candidateTimestamp <= transaction.token.targetTimestamp else {
      throw TissueError.transaction("interactive candidate would overshoot the root target")
    }
    guard substep.startTimestamp == root.acceptedTimestamp else {
      throw TissueError.transaction("interactive neural and physical start times diverged")
    }
    let (nextHistoryStep, historyOverflow) = root.historyStep.addingReportingOverflow(1)
    guard !historyOverflow else {
      throw TissueError.transaction("interactive tissue history step overflows UInt64")
    }
    let historyWriteSlot = Int(
      nextHistoryStep % UInt64(TissueDelayField.historyCapacity)
    )
    let currentOwner =
      (root.historyOwnerMask >> UInt32(historyWriteSlot)) & 1
    let historyWritePlane = currentOwner ^ 1
    var prospectiveTimestamps = root.relayHistoryTimestamps
    prospectiveTimestamps[historyWriteSlot] = substep.candidateTimestamp.rawValue
    try validateRelayHistoryCoverage(
      at: substep.candidateTimestamp,
      timestamps: prospectiveTimestamps
    )
    let destination = destinationIndex(rootShadowIndex: root.rootShadowIndex)
    let timestepMilliseconds = Float(Double(candidateDurationMicroseconds) / 1_000)
    let values = TissueUniforms.encode(
      width: width,
      height: height,
      timeMilliseconds: Float(Double(root.acceptedTimestamp.rawValue) / 1_000),
      parameters: parameters,
      stimulus: stimulus,
      historyStep: UInt32(root.historyStep % UInt64(TissueDelayField.historyCapacity)),
      historyOwnerMask: root.historyOwnerMask,
      historyWriteSlot: UInt32(historyWriteSlot),
      historyWritePlane: historyWritePlane,
      eventCount: eventSchedule.eventCount,
      randomContext: randomContext,
      acceptedStep: root.historyStep,
      timestepMilliseconds: timestepMilliseconds,
      currentTimestamp: root.acceptedTimestamp,
      candidateTimestamp: substep.candidateTimestamp
    )
    writeUniforms(values, attempt: 0)
    let feedback = try submit(label: "NumiBrain interactive fast neural candidate") {
      encoder in
      eventArgumentTable.setAddress(uniformBuffer.gpuAddress, index: 0)
      eventArgumentTable.setAddress(eventBuffer.gpuAddress, index: 1)
      eventArgumentTable.setAddress(activeEventIndexBuffer.gpuAddress, index: 2)
      encoder.setComputePipelineState(eventCompactionPipeline)
      encoder.setArgumentTable(eventArgumentTable)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      argumentTable.setAddress(stateBuffers[root.rootShadowIndex].gpuAddress, index: 0)
      argumentTable.setAddress(stateBuffers[destination].gpuAddress, index: 1)
      argumentTable.setAddress(uniformBuffer.gpuAddress, index: 2)
      argumentTable.setAddress(structureBuffer.gpuAddress, index: 3)
      argumentTable.setAddress(delayBuffer.gpuAddress, index: 4)
      argumentTable.setAddress(relayHistoryBuffer.gpuAddress, index: 5)
      argumentTable.setAddress(relayScratchBuffer.gpuAddress, index: 6)
      argumentTable.setAddress(projectionOffsetBuffer.gpuAddress, index: 7)
      argumentTable.setAddress(projectionEdgeBuffer.gpuAddress, index: 8)
      argumentTable.setAddress(eventBuffer.gpuAddress, index: 9)
      argumentTable.setAddress(activeEventIndexBuffer.gpuAddress, index: 10)
      argumentTable.setAddress(relayHistoryTimestampBuffer.gpuAddress, index: 11)
      encoder.setComputePipelineState(tissuePipeline)
      encoder.setArgumentTable(argumentTable)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(width: width, height: height, depth: 1),
        threadsPerThreadgroup: threadgroupSize()
      )
    }
    let protectiveStateIndex =
      root.fastSchedulerWindow?.outputClockIndex
      ?? (descendingSomaticTransactionFingerprint
        == root.transaction.token.fingerprint
          ? 1 - committedSchedulerClockIndex
          : committedSchedulerClockIndex)
    root.transaction = transaction
    root.candidate = InteractiveCandidate(
      substep: substep,
      destinationIndex: destination,
      historyWriteSlot: historyWriteSlot,
      historyWritePlane: historyWritePlane,
      motorStateIndex: protectiveStateIndex
    )
    root.firstGPUStartSeconds = root.firstGPUStartSeconds ?? feedback.gpuStartTime
    interactiveJointRoot = root
    let protectiveTimestamp =
      root.fastSchedulerWindow == nil
      ? committedSchedulerTime ?? BrainTimestamp(microseconds: 0)
      : root.acceptedTimestamp
    let protectiveCommandGeneration =
      root.fastSchedulerWindow == nil
      ? root.transaction.token.baseBrainGeneration
      : root.transaction.token.shadowGeneration
    let protectiveMotorGeneration = descendingSomaticTransactionFingerprint
        == root.transaction.token.fingerprint
      ? root.transaction.token.shadowGeneration
      : protectiveCommandGeneration
    return FastSystemResult(
      substep: substep,
      speciesTemplateFingerprint: boundFastReflexSpeciesFingerprint ?? 0,
      protectiveCommand: ProtectiveCommandBufferView(
        gpuAddress: protectiveCommandBuffers[protectiveStateIndex].gpuAddress,
        byteCount: ProtectiveMotorCommand.byteCount,
        timestamp: protectiveTimestamp,
        brainGeneration: protectiveCommandGeneration
      ),
      protectiveMotorOutput: ProtectiveMotorOutputBufferView(
        headerGPUAddress: protectiveMotorOutputHeaderBuffers[protectiveStateIndex].gpuAddress,
        muscleExcitationGPUAddress:
          protectiveMuscleExcitationBuffers[protectiveStateIndex].gpuAddress,
        headerByteCount: ProtectiveMotorOutput.headerByteCount,
        muscleExcitationByteCount: protectiveMuscleExcitationByteCount,
        muscleCount: protectiveMotorProfile.channels.count,
        timestamp: protectiveTimestamp,
        brainGeneration: protectiveMotorGeneration,
        profileFingerprint: protectiveMotorProfile.fingerprint,
        actuatorCommandKind: boundActuatorCommandKind
      ),
      fastAutonomicOutput: FastAutonomicOutputBufferView(
        gpuAddress: stagedFastAutonomicOutputBuffer.gpuAddress,
        byteCount: boundFastAutonomicChannelCount * Self.autonomicCommandStride,
        channelCount: boundFastAutonomicChannelCount,
        timestamp: protectiveTimestamp,
        brainGeneration: protectiveMotorGeneration
      ),
      activeSensingOutput: ActiveSensingOutputBufferView(
        gpuAddress: stagedActiveSensingCommandBuffer.gpuAddress,
        byteCount: boundActiveSensingChannelCount * Self.activeSensingCommandStride,
        channelCount: boundActiveSensingChannelCount,
        timestamp: protectiveTimestamp,
        brainGeneration: protectiveMotorGeneration
      ),
      gpuStartSeconds: feedback.gpuStartTime,
      gpuEndSeconds: feedback.gpuEndTime
    )
  }

  public func acceptPhysicsSubstep(
    _ accepted: AcceptedPhysicsStateToken,
    for substep: BrainJointSubstepToken,
    receptorEvents: [BrainInterruptEvent] = [],
    localizedMuscleLoadObservations: [LocalizedMuscleLoadReceptorObservation] = []
  ) throws {
    guard var root = interactiveJointRoot, let candidate = root.candidate,
      candidate.substep == substep
    else {
      throw TissueError.transaction("stale or missing interactive neural candidate")
    }
    try validateLocalizedMuscleLoadObservations(localizedMuscleLoadObservations)
    var transaction = root.transaction
    try transaction.acceptPhysicsSubstep(
      accepted,
      for: substep,
      receptorEvents: receptorEvents,
      localizedMuscleLoadObservations: localizedMuscleLoadObservations
    )
    let acceptedEvents = transaction.resolutions.lazy
      .filter(\.isAccepted)
      .flatMap(\.receptorEvents)
    let acceptedLocalizedObservations = transaction.resolutions.lazy
      .filter(\.isAccepted)
      .flatMap(\.localizedMuscleLoadObservations)
    try writeProtectiveSourceInhibitionMask(
      observations: Array(acceptedLocalizedObservations),
      targetTimestamp: accepted.acceptedTimestamp
    )
    let schedulerWindow = try prepareSchedulerWindow(
      startTime: transaction.token.committedTimestamp,
      targetTime: accepted.acceptedTimestamp,
      events: Array(acceptedEvents)
    )
    guard committedRegionalStateIndex == schedulerWindow.inputClockIndex else {
      throw TissueError.transaction("interactive regional and scheduler generations diverged")
    }
    writeFastCPGUniforms(
      timestamp: accepted.acceptedTimestamp,
      consumeInterruptEvents: true
    )
    writeFastAutonomicUniforms(
      timestamp: accepted.acceptedTimestamp,
      baselineTimestamp: transaction.token.committedTimestamp,
      consumeInterruptEvents: true
    )
    let feedback = try submit(label: "NumiBrain accepted fast regional prefix") { encoder in
      // Preserve the command that NumanX actually accepted before the
      // post-consequence scheduler overwrites this ping-pong motor generation
      // with the command for the next candidate.
      encoder.copy(
        sourceBuffer: protectiveMuscleExcitationBuffers[candidate.motorStateIndex],
        sourceOffset: 0,
        destinationBuffer: stagedAcceptedSomaticOutputBuffer,
        destinationOffset: 0,
        size: protectiveMuscleExcitationByteCount
      )
      encoder.copy(
        sourceBuffer: stagedFastAutonomicOutputBuffer,
        sourceOffset: 0,
        destinationBuffer: stagedAcceptedAutonomicOutputBuffer,
        destinationOffset: 0,
        size: fastAutonomicCommandByteCount
      )
      encoder.copy(
        sourceBuffer: stagedActiveSensingCommandBuffer,
        sourceOffset: 0,
        destinationBuffer: stagedAcceptedActiveSensingOutputBuffer,
        destinationOffset: 0,
        size: activeSensingCommandByteCount
      )
      encoder.barrier(
        afterEncoderStages: .blit,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      encodeRootFinalization(encoder, schedulerWindow: schedulerWindow)
    }
    root.transaction = transaction
    root.rootShadowIndex = candidate.destinationIndex
    root.historyOwnerMask = settingHistoryOwner(
      mask: root.historyOwnerMask,
      slot: candidate.historyWriteSlot,
      owner: candidate.historyWritePlane
    )
    root.historyStep += 1
    root.relayHistoryTimestamps[candidate.historyWriteSlot] =
      accepted.acceptedTimestamp.rawValue
    root.acceptedTimestamp = accepted.acceptedTimestamp
    root.candidate = nil
    root.fastSchedulerWindow = schedulerWindow
    root.firstGPUStartSeconds = root.firstGPUStartSeconds ?? feedback.gpuStartTime
    root.lastGPUEndSeconds = feedback.gpuEndTime
    hasCommittedSchedulerResult = false
    interactiveJointRoot = root
  }

  /// Lends the private protective-output allocations to the physical runtime
  /// without staging either payload through CPU memory. The fast-system result
  /// must still be the live, unaccepted candidate owned by this runtime.
  public func borrowNumanXMotorBuffers(
    for fastSystems: FastSystemResult
  ) throws -> NumanXMotorBufferLease {
    guard let root = interactiveJointRoot,
      let candidate = root.candidate,
      candidate.substep == fastSystems.substep
    else {
      throw TissueError.transaction(
        "cannot lend motor buffers for a stale or accepted neural candidate"
      )
    }
    let output = fastSystems.protectiveMotorOutput
    let autonomic = fastSystems.fastAutonomicOutput
    let activeSensing = fastSystems.activeSensingOutput
    guard
      fastSystems.speciesTemplateFingerprint == boundFastReflexSpeciesFingerprint,
      let headerBuffer = protectiveMotorOutputHeaderBuffers.first(where: {
        $0.gpuAddress == output.headerGPUAddress
      }),
      let excitationBuffer = protectiveMuscleExcitationBuffers.first(where: {
        $0.gpuAddress == output.muscleExcitationGPUAddress
      }),
      output.headerByteCount == ProtectiveMotorOutput.headerByteCount,
      output.muscleExcitationByteCount == protectiveMuscleExcitationByteCount,
      output.muscleCount == protectiveMotorProfile.channels.count,
      output.actuatorCommandKind == boundActuatorCommandKind,
      headerBuffer.length >= output.headerByteCount,
      excitationBuffer.length >= output.muscleExcitationByteCount,
      autonomic.gpuAddress == stagedFastAutonomicOutputBuffer.gpuAddress,
      autonomic.byteCount
        == boundFastAutonomicChannelCount * Self.autonomicCommandStride,
      autonomic.channelCount == boundFastAutonomicChannelCount,
      autonomic.timestamp == output.timestamp,
      autonomic.brainGeneration == output.brainGeneration,
      stagedFastAutonomicOutputBuffer.length >= autonomic.byteCount,
      activeSensing.gpuAddress == stagedActiveSensingCommandBuffer.gpuAddress,
      activeSensing.byteCount
        == boundActiveSensingChannelCount * Self.activeSensingCommandStride,
      activeSensing.channelCount == boundActiveSensingChannelCount,
      activeSensing.timestamp == output.timestamp,
      activeSensing.brainGeneration == output.brainGeneration,
      stagedActiveSensingCommandBuffer.length >= activeSensing.byteCount
    else {
      throw TissueError.transaction(
        "fast-system motor view does not identify this runtime's resident buffers"
      )
    }
    return NumanXMotorBufferLease(
      output: output,
      headerBuffer: headerBuffer,
      excitationBuffer: excitationBuffer,
      autonomicBuffer: stagedFastAutonomicOutputBuffer,
      activeSensingBuffer: stagedActiveSensingCommandBuffer
    )
  }

  public func rejectPhysicsSubstep(
    _ substep: BrainJointSubstepToken,
    receptorEvents: [BrainInterruptEvent] = []
  ) throws {
    guard var root = interactiveJointRoot, root.candidate?.substep == substep else {
      throw TissueError.transaction("stale or missing interactive neural candidate")
    }
    var transaction = root.transaction
    try transaction.rejectPhysicsSubstep(
      substep,
      receptorEvents: receptorEvents
    )
    root.transaction = transaction
    root.candidate = nil
    interactiveJointRoot = root
  }

  /// Finalizes the slow scheduler and regional systems after NumanX has
  /// accepted enough interactive candidates to reach the root target. The
  /// accepted tissue generation remains unpublished until joint commit.
  public func finishInteractiveJointControl(
    schedulerEvents: [BrainInterruptEvent] = []
  ) throws -> Submission {
    guard let root = interactiveJointRoot else {
      throw TissueError.transaction("there is no interactive joint root to finish")
    }
    guard root.candidate == nil else {
      throw TissueError.transaction("accept or reject the active neural candidate first")
    }
    let transaction = root.transaction
    let token = transaction.token
    guard transaction.status == .open, transaction.activeSubstep == nil,
      !transaction.resolutions.isEmpty,
      transaction.acceptedSubstepCount > 0,
      transaction.acceptedTimestamp == token.targetTimestamp,
      transaction.lastAcceptedPhysicsState != nil
    else {
      throw TissueError.transaction("interactive joint root has not accepted its target")
    }
    guard token.baseBrainGeneration == committedSchedulerGeneration,
      token.randomCounterGeneration == committedStep,
      token.parameterVersionFingerprint == parameterVersion.fingerprint,
      token.environmentIdentifier == schedulerEnvironmentIdentifier
    else {
      throw TissueError.transaction("interactive joint identity is stale for this Metal runtime")
    }
    guard transaction.acceptedSubstepCount <= UInt32(TissueDelayField.historyCapacity) else {
      throw TissueError.transaction(
        "an interactive root cannot accept more than \(TissueDelayField.historyCapacity) delayed substeps"
      )
    }
    let (expectedHistoryStep, historyOverflow) = committedStep.addingReportingOverflow(
      UInt64(transaction.acceptedSubstepCount)
    )
    guard !historyOverflow, root.historyStep == expectedHistoryStep,
      root.acceptedTimestamp == token.targetTimestamp
    else {
      throw TissueError.transaction("interactive tissue shadow diverged from the joint ledger")
    }

    guard var schedulerWindow = root.fastSchedulerWindow,
      schedulerWindow.targetTime == token.targetTimestamp
    else {
      throw TissueError.transaction("interactive fast scheduler did not reach the root target")
    }
    guard schedulerWindow.targetTime == token.targetTimestamp,
      committedRegionalStateIndex == schedulerWindow.inputClockIndex
    else {
      throw TissueError.transaction("interactive scheduler shadow diverged from the joint token")
    }

    var finalGPUStart = root.firstGPUStartSeconds
    var finalGPUEnd = root.lastGPUEndSeconds
    var finalizationDispatches = 0
    if !schedulerEvents.isEmpty {
      let acceptedEvents = transaction.resolutions.lazy
        .filter(\.isAccepted)
        .flatMap(\.receptorEvents)
      let acceptedLocalizedObservations = transaction.resolutions.lazy
        .filter(\.isAccepted)
        .flatMap(\.localizedMuscleLoadObservations)
      try writeProtectiveSourceInhibitionMask(
        observations: Array(acceptedLocalizedObservations),
        targetTimestamp: token.targetTimestamp
      )
      schedulerWindow = try prepareSchedulerWindow(
        startTime: token.committedTimestamp,
        targetTime: token.targetTimestamp,
        events: schedulerEvents + acceptedEvents
      )
      writeFastCPGUniforms(
        timestamp: token.targetTimestamp,
        consumeInterruptEvents: true
      )
      writeFastAutonomicUniforms(
        timestamp: token.targetTimestamp,
        baselineTimestamp: token.committedTimestamp,
        consumeInterruptEvents: true
      )
      let feedback = try submit(label: "NumiBrain interactive joint root finalization") {
        encoder in
        encodeRootFinalization(encoder, schedulerWindow: schedulerWindow)
      }
      finalGPUStart = finalGPUStart ?? feedback.gpuStartTime
      finalGPUEnd = feedback.gpuEndTime
      finalizationDispatches = 1
    }
    guard let finalGPUStart, let finalGPUEnd else {
      throw TissueError.transaction("interactive GPU timing did not cover the accepted root")
    }
    pendingRootShadowIndex = root.rootShadowIndex
    pendingRootShadowOwnerMask = root.historyOwnerMask
    pendingRootShadowStep = root.historyStep
    pendingRelayHistoryTimestamps = root.relayHistoryTimestamps
    pendingSchedulerClockIndex = schedulerWindow.outputClockIndex
    pendingSchedulerTargetTime = schedulerWindow.targetTime
    pendingRegionalStateIndex = schedulerWindow.outputClockIndex
    pendingSchedulerInitialized = schedulerWindow.initialize
    hasCommittedSchedulerResult = false
    pendingJointTransaction = transaction
    interactiveJointRoot = nil

    return Submission(
      parameterVersionFingerprint: parameterVersion.fingerprint,
      attemptedSubsteps: transaction.resolutions.count,
      acceptedSubsteps: Int(transaction.acceptedSubstepCount),
      eventCompactionDispatches: transaction.resolutions.count,
      receptorInterruptTransductionDispatches: Int(transaction.acceptedSubstepCount)
        + finalizationDispatches,
      schedulerDispatches: Int(transaction.acceptedSubstepCount) + finalizationDispatches,
      regionalDispatches: Int(transaction.acceptedSubstepCount) + finalizationDispatches,
      protectiveDispatches: Int(transaction.acceptedSubstepCount) + finalizationDispatches,
      protectiveMotorDispatches: Int(transaction.acceptedSubstepCount)
        + finalizationDispatches,
      schedulerHostInputEventCount: schedulerWindow.hostEventCount,
      schedulerReceptorInputEventCount: schedulerWindow.receptorEventCount,
      schedulerCognitiveInputEventMaximumCount:
        schedulerWindow.cognitiveEventMaximumCount,
      schedulerInputEventCount: schedulerWindow.eventCount,
      gpuStartSeconds: finalGPUStart,
      gpuEndSeconds: finalGPUEnd
    )
  }

  public func abortInteractiveJointControl() throws {
    guard var root = interactiveJointRoot else {
      throw TissueError.transaction("there is no interactive joint root to abort")
    }
    try root.transaction.abort()
    if root.fastSchedulerWindow != nil {
      hasCommittedSchedulerResult = false
    }
    interactiveJointRoot = nil
  }

  /// Lends accepted-only CPG phase, reflex history, per-actuator cerebellar
  /// load correction, and autonomic integration after fast-root finalization
  /// and before joint publication. The cognitive transaction imports every
  /// state into its own shadow generation, so neither runtime can publish a
  /// different fast control history.
  func borrowPreparedAcceptedFastMotorState(
    for transaction: BrainJointTransactionToken
  ) throws -> AcceptedFastMotorStateLease {
    guard let pendingJointTransaction,
      pendingJointTransaction.token == transaction,
      pendingSchedulerTargetTime == transaction.targetTimestamp,
      stagedFastCPGTransactionFingerprint == transaction.fingerprint,
      stagedFastCPGOscillatorCount <= Self.maximumFastCPGOscillatorCount
    else {
      throw TissueError.transaction(
        "accepted fast motor state is not prepared for this joint root"
      )
    }
    return AcceptedFastMotorStateLease(
      transactionFingerprint: transaction.fingerprint,
      acceptedTimestamp: transaction.targetTimestamp,
      oscillatorCount: stagedFastCPGOscillatorCount,
      byteCount: stagedFastCPGOscillatorCount * Self.fastCPGStateStride,
      cpgBuffer: stagedFastCPGStateBuffer,
      reflexRuleCount: boundFastReflexRuleCount,
      reflexStateByteCount: boundFastReflexRuleCount * Self.fastReflexStateStride,
      reflexStateBuffer: stagedFastReflexStateBuffer,
      fastCerebellarStateCount: protectiveMotorProfile.channels.count,
      fastCerebellarStateByteCount: fastCerebellarStateByteCount,
      fastCerebellarStateBuffer: stagedFastCerebellarStateBuffer,
      fastAutonomicStateCount: boundFastAutonomicChannelCount,
      fastAutonomicStateByteCount:
        boundFastAutonomicChannelCount * Self.fastAutonomicStateStride,
      fastAutonomicStateBuffer: stagedFastAutonomicStateBuffer,
      acceptedSomaticOutputCount: protectiveMotorProfile.channels.count,
      acceptedSomaticOutputByteCount: protectiveMuscleExcitationByteCount,
      acceptedSomaticOutputBuffer: stagedAcceptedSomaticOutputBuffer,
      acceptedAutonomicOutputCount: boundFastAutonomicChannelCount,
      acceptedAutonomicOutputByteCount:
        max(boundFastAutonomicChannelCount, 1) * Self.autonomicCommandStride,
      acceptedAutonomicOutputBuffer: stagedAcceptedAutonomicOutputBuffer,
      acceptedActiveSensingOutputCount: boundActiveSensingChannelCount,
      acceptedActiveSensingOutputByteCount:
        max(boundActiveSensingChannelCount, 1) * Self.activeSensingCommandStride,
      acceptedActiveSensingOutputBuffer:
        stagedAcceptedActiveSensingOutputBuffer,
      actuatorCommandKind: boundActuatorCommandKind
    )
  }

  /// Encodes a Metal root from the exact accepted/rejected NumanX ledger.
  /// Candidate durations may shrink from the nominal tissue step, while
  /// physical-time relay lookup preserves the configured conduction interval.
  public func runJointRootTransaction(
    _ transaction: BrainJointTransaction,
    schedulerEvents: [BrainInterruptEvent] = []
  ) throws -> Submission {
    let token = transaction.token
    guard transaction.status == .open, transaction.activeSubstep == nil else {
      throw TissueError.transaction("joint transaction is not ready for Metal encoding")
    }
    guard !transaction.resolutions.isEmpty,
      transaction.acceptedSubstepCount > 0,
      transaction.acceptedTimestamp == token.targetTimestamp,
      transaction.lastAcceptedPhysicsState != nil
    else {
      throw TissueError.transaction("joint transaction has not accepted the root target")
    }
    guard token.environmentIdentifier == schedulerEnvironmentIdentifier,
      token.parameterVersionFingerprint == parameterVersion.fingerprint,
      token.baseBrainGeneration == committedSchedulerGeneration,
      token.randomCounterGeneration == committedStep
    else {
      throw TissueError.transaction("joint transaction identity is stale for this Metal runtime")
    }
    if let committedSchedulerTime {
      guard token.committedTimestamp == committedSchedulerTime else {
        throw TissueError.transaction("joint transaction starts from stale committed time")
      }
    }
    let timestep = try schedulerTimestamp(
      milliseconds: parameters.timestepMilliseconds
    ).rawValue
    guard
      transaction.resolutions.allSatisfy({
        $0.substep.durationMicroseconds > 0
          && $0.substep.durationMicroseconds <= timestep
      })
    else {
      throw TissueError.transaction(
        "joint substep duration must be positive and no larger than the nominal tissue step"
      )
    }
    let acceptance = transaction.resolutions.map(\.isAccepted)
    let acceptedCount = acceptance.lazy.filter({ $0 }).count
    let rejectedCount = acceptance.count - acceptedCount
    guard acceptedCount == Int(transaction.acceptedSubstepCount),
      UInt64(rejectedCount) == transaction.rejectedAttemptCount
    else {
      throw TissueError.transaction("joint substep ledger counters do not match")
    }
    var duration: UInt64 = 0
    var durationOverflow = false
    for resolution in transaction.resolutions where resolution.isAccepted {
      let result = duration.addingReportingOverflow(
        resolution.substep.durationMicroseconds
      )
      duration = result.partialValue
      durationOverflow = durationOverflow || result.overflow
    }
    let (expectedTarget, targetOverflow) = token.committedTimestamp.rawValue
      .addingReportingOverflow(duration)
    guard !durationOverflow, !targetOverflow,
      expectedTarget == token.targetTimestamp.rawValue
    else {
      throw TissueError.transaction("joint accepted duration does not reach the root target")
    }
    let acceptedLocalizedObservations = transaction.resolutions.lazy
      .filter(\.isAccepted)
      .flatMap(\.localizedMuscleLoadObservations)
    let localizedObservations = Array(acceptedLocalizedObservations)
    try validateLocalizedMuscleLoadObservations(localizedObservations)
    let submission = try runRootTransaction(
      startTime: token.committedTimestamp,
      candidateDurationsMicroseconds: transaction.resolutions.map(
        \.substep.durationMicroseconds
      ),
      acceptedSubsteps: acceptance,
      schedulerEvents: schedulerEvents
        + transaction.resolutions.lazy
        .filter(\.isAccepted)
        .flatMap(\.receptorEvents),
      localizedMuscleLoadObservations: localizedObservations
    )
    guard pendingSchedulerTargetTime == token.targetTimestamp else {
      try abortRootTransaction()
      throw TissueError.transaction("Metal shadow target diverged from the joint token")
    }
    pendingJointTransaction = transaction
    return submission
  }

  public func runRootTransaction(
    at timeMilliseconds: Float,
    acceptedSubsteps: [Bool],
    schedulerEvents: [BrainInterruptEvent] = []
  ) throws -> Submission {
    let startTime = try schedulerTimestamp(milliseconds: timeMilliseconds)
    let nominalDuration = try schedulerTimestamp(
      milliseconds: parameters.timestepMilliseconds
    ).rawValue
    return try runRootTransaction(
      startTime: startTime,
      candidateDurationsMicroseconds: Array(
        repeating: nominalDuration,
        count: acceptedSubsteps.count
      ),
      acceptedSubsteps: acceptedSubsteps,
      schedulerEvents: schedulerEvents
    )
  }

  private func runRootTransaction(
    startTime: BrainTimestamp,
    candidateDurationsMicroseconds: [UInt64],
    acceptedSubsteps: [Bool],
    schedulerEvents: [BrainInterruptEvent],
    localizedMuscleLoadObservations: [LocalizedMuscleLoadReceptorObservation] = []
  ) throws -> Submission {
    guard pendingRootShadowIndex == nil, interactiveJointRoot == nil else {
      throw TissueError.transaction("commit or abort the pending Metal root transaction first")
    }
    guard !acceptedSubsteps.isEmpty else {
      throw TissueError.transaction("a root transaction needs at least one candidate substep")
    }
    guard candidateDurationsMicroseconds.count == acceptedSubsteps.count else {
      throw TissueError.transaction("candidate duration and acceptance ledgers differ in shape")
    }
    guard acceptedSubsteps.count <= maxEncodedSubsteps else {
      throw TissueError.transaction(
        "\(acceptedSubsteps.count) attempts exceed the \(maxEncodedSubsteps)-substep uniform arena"
      )
    }
    let acceptedCount = acceptedSubsteps.lazy.filter({ $0 }).count
    guard acceptedCount > 0 else {
      throw TissueError.transaction("a root transaction must accept simulated time")
    }
    guard acceptedCount <= TissueDelayField.historyCapacity else {
      throw TissueError.transaction(
        "a Metal root transaction cannot accept more than \(TissueDelayField.historyCapacity) delayed substeps"
      )
    }
    let nominalDuration = try schedulerTimestamp(
      milliseconds: parameters.timestepMilliseconds
    ).rawValue
    guard
      candidateDurationsMicroseconds.allSatisfy({
        $0 > 0 && $0 <= nominalDuration
      })
    else {
      throw TissueError.transaction(
        "candidate durations must be positive and no larger than the nominal tissue step"
      )
    }
    var acceptedDuration: UInt64 = 0
    for attempt in acceptedSubsteps.indices where acceptedSubsteps[attempt] {
      let (nextDuration, overflow) = acceptedDuration.addingReportingOverflow(
        candidateDurationsMicroseconds[attempt]
      )
      guard !overflow else {
        throw TissueError.transaction("accepted root duration overflows UInt64")
      }
      acceptedDuration = nextDuration
    }
    let (targetValue, targetOverflow) = startTime.rawValue.addingReportingOverflow(
      acceptedDuration
    )
    guard !targetOverflow else {
      throw TissueError.transaction("root target time overflows UInt64")
    }
    let targetTime = BrainTimestamp(microseconds: targetValue)
    descendingSomaticTransactionFingerprint = nil
    stagedFastCPGTransactionFingerprint = nil
    stagedFastCPGOscillatorCount = 0
    stagedFastCPGSynergyCount = 0
    writeFastCPGUniforms(timestamp: targetTime)
    writeFastAutonomicUniforms(
      timestamp: targetTime,
      baselineTimestamp: startTime,
      consumeInterruptEvents: true
    )
    try writeProtectiveSourceInhibitionMask(
      observations: localizedMuscleLoadObservations,
      targetTimestamp: targetTime
    )
    let schedulerWindow = try prepareSchedulerWindow(
      startTime: startTime,
      targetTime: targetTime,
      events: schedulerEvents
    )
    guard committedRegionalStateIndex == schedulerWindow.inputClockIndex else {
      throw TissueError.transaction("regional and scheduler generations diverged")
    }

    var rootShadowIndex = committedIndex
    var acceptedTime = startTime
    var historyOwnerMask = committedHistoryOwnerMask
    var historyStep = committedStep
    var relayHistoryTimestamps = committedRelayHistoryTimestamps

    for attempt in acceptedSubsteps.indices {
      let (nextHistoryStep, historyOverflow) = historyStep.addingReportingOverflow(1)
      guard !historyOverflow else {
        throw TissueError.transaction("tissue history step overflows UInt64")
      }
      let historyWriteSlot = Int(
        nextHistoryStep % UInt64(TissueDelayField.historyCapacity)
      )
      let currentOwner = (historyOwnerMask >> UInt32(historyWriteSlot)) & 1
      let historyWritePlane: UInt32 =
        acceptedSubsteps[attempt]
        ? currentOwner ^ 1
        : 2
      let duration = candidateDurationsMicroseconds[attempt]
      let (candidateTimeValue, candidateTimeOverflow) = acceptedTime.rawValue
        .addingReportingOverflow(duration)
      guard !candidateTimeOverflow else {
        throw TissueError.transaction("candidate timestamp overflows UInt64")
      }
      let candidateTime = BrainTimestamp(microseconds: candidateTimeValue)
      var prospectiveTimestamps = relayHistoryTimestamps
      if acceptedSubsteps[attempt] {
        prospectiveTimestamps[historyWriteSlot] = candidateTime.rawValue
        try validateRelayHistoryCoverage(
          at: candidateTime,
          timestamps: prospectiveTimestamps
        )
      }
      let values = TissueUniforms.encode(
        width: width,
        height: height,
        timeMilliseconds: Float(Double(acceptedTime.rawValue) / 1_000),
        parameters: parameters,
        stimulus: stimulus,
        historyStep: UInt32(historyStep % UInt64(TissueDelayField.historyCapacity)),
        historyOwnerMask: historyOwnerMask,
        historyWriteSlot: UInt32(historyWriteSlot),
        historyWritePlane: historyWritePlane,
        eventCount: eventSchedule.eventCount,
        randomContext: randomContext,
        acceptedStep: historyStep,
        timestepMilliseconds: Float(Double(duration) / 1_000),
        currentTimestamp: acceptedTime,
        candidateTimestamp: candidateTime
      )
      let destination = destinationIndex(rootShadowIndex: rootShadowIndex)
      writeUniforms(values, attempt: attempt)
      if acceptedSubsteps[attempt] {
        rootShadowIndex = destination
        acceptedTime = candidateTime
        historyStep = nextHistoryStep
        relayHistoryTimestamps = prospectiveTimestamps
        historyOwnerMask = settingHistoryOwner(
          mask: historyOwnerMask,
          slot: historyWriteSlot,
          owner: historyWritePlane
        )
      }
    }

    let finalRootShadowIndex = rootShadowIndex
    let finalHistoryOwnerMask = historyOwnerMask
    let finalHistoryStep = historyStep
    let finalRelayHistoryTimestamps = relayHistoryTimestamps

    rootShadowIndex = committedIndex
    let feedback = try submit(label: "NumiBrain tissue root transaction") { encoder in
      for attempt in acceptedSubsteps.indices {
        let uniformAddress =
          uniformBuffer.gpuAddress + UInt64(attempt * TissueUniforms.byteCount)
        eventArgumentTable.setAddress(uniformAddress, index: 0)
        eventArgumentTable.setAddress(eventBuffer.gpuAddress, index: 1)
        eventArgumentTable.setAddress(activeEventIndexBuffer.gpuAddress, index: 2)
        encoder.setComputePipelineState(eventCompactionPipeline)
        encoder.setArgumentTable(eventArgumentTable)
        encoder.dispatchThreads(
          threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
          threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
        )
        encoder.barrier(
          afterEncoderStages: .dispatch,
          beforeEncoderStages: .dispatch,
          visibilityOptions: .device
        )

        let destination = destinationIndex(rootShadowIndex: rootShadowIndex)
        argumentTable.setAddress(stateBuffers[rootShadowIndex].gpuAddress, index: 0)
        argumentTable.setAddress(stateBuffers[destination].gpuAddress, index: 1)
        argumentTable.setAddress(uniformAddress, index: 2)
        argumentTable.setAddress(structureBuffer.gpuAddress, index: 3)
        argumentTable.setAddress(delayBuffer.gpuAddress, index: 4)
        argumentTable.setAddress(relayHistoryBuffer.gpuAddress, index: 5)
        argumentTable.setAddress(relayScratchBuffer.gpuAddress, index: 6)
        argumentTable.setAddress(projectionOffsetBuffer.gpuAddress, index: 7)
        argumentTable.setAddress(projectionEdgeBuffer.gpuAddress, index: 8)
        argumentTable.setAddress(eventBuffer.gpuAddress, index: 9)
        argumentTable.setAddress(activeEventIndexBuffer.gpuAddress, index: 10)
        argumentTable.setAddress(relayHistoryTimestampBuffer.gpuAddress, index: 11)
        encoder.setComputePipelineState(tissuePipeline)
        encoder.setArgumentTable(argumentTable)
        encoder.dispatchThreads(
          threadsPerGrid: MTLSize(width: width, height: height, depth: 1),
          threadsPerThreadgroup: threadgroupSize()
        )
        if attempt != acceptedSubsteps.indices.last {
          encoder.barrier(
            afterEncoderStages: .dispatch,
            beforeEncoderStages: .dispatch,
            visibilityOptions: .device
          )
        }
        if acceptedSubsteps[attempt] {
          rootShadowIndex = destination
        }
      }
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      encodeRootFinalization(encoder, schedulerWindow: schedulerWindow)
    }
    pendingRootShadowIndex = finalRootShadowIndex
    pendingRootShadowOwnerMask = finalHistoryOwnerMask
    pendingRootShadowStep = finalHistoryStep
    pendingRelayHistoryTimestamps = finalRelayHistoryTimestamps
    pendingSchedulerClockIndex = schedulerWindow.outputClockIndex
    pendingSchedulerTargetTime = schedulerWindow.targetTime
    pendingRegionalStateIndex = schedulerWindow.outputClockIndex
    pendingSchedulerInitialized = schedulerWindow.initialize
    hasCommittedSchedulerResult = false
    return Submission(
      parameterVersionFingerprint: parameterVersion.fingerprint,
      attemptedSubsteps: acceptedSubsteps.count,
      acceptedSubsteps: acceptedCount,
      eventCompactionDispatches: acceptedSubsteps.count,
      receptorInterruptTransductionDispatches: 1,
      schedulerDispatches: 1,
      regionalDispatches: 1,
      protectiveDispatches: 1,
      protectiveMotorDispatches: 1,
      schedulerHostInputEventCount: schedulerWindow.hostEventCount,
      schedulerReceptorInputEventCount: schedulerWindow.receptorEventCount,
      schedulerCognitiveInputEventMaximumCount:
        schedulerWindow.cognitiveEventMaximumCount,
      schedulerInputEventCount: schedulerWindow.eventCount,
      gpuStartSeconds: feedback.gpuStartTime,
      gpuEndSeconds: feedback.gpuEndTime
    )
  }

  public func commitRootTransaction() throws {
    guard pendingJointTransaction == nil else {
      throw TissueError.transaction(
        "joint roots require commitJointRootTransaction with the accepted physics token"
      )
    }
    publishPreparedRootTransaction(try prepareRootPublication())
  }

  public func commitJointRootTransaction() throws -> BrainJointCommitToken {
    let prepared = try prepareJointRootTransactionCommit()
    publishPreparedJointRootTransactionCommit(prepared)
    return prepared.receipt
  }

  func prepareJointRootTransactionCommit() throws -> PreparedJointRootCommit {
    guard var transaction = pendingJointTransaction else {
      throw TissueError.transaction("there is no joint Metal root to commit")
    }
    let receipt = try transaction.commit()
    let localizedMuscleLoadObservations = transaction.resolutions.lazy
      .filter(\.isAccepted)
      .flatMap(\.localizedMuscleLoadObservations)
    let localizedObservations = Array(localizedMuscleLoadObservations)
    let bodyLoadFrame: CommittedBodyLoadFrame?
    let protectiveMuscleSelection: LocalizedProtectiveMuscleSelection?
    if let numanXMuscleAttachmentCatalog {
      let frame = try CommittedBodyLoadFrame(
        commit: receipt,
        attachmentCatalog: numanXMuscleAttachmentCatalog,
        observations: localizedObservations
      )
      bodyLoadFrame = frame
      protectiveMuscleSelection = try LocalizedProtectiveMuscleSelection(
        bodyLoadFrame: frame,
        attachmentCatalog: numanXMuscleAttachmentCatalog,
        motorProfile: protectiveMotorProfile
      )
    } else {
      guard localizedObservations.isEmpty else {
        throw TissueError.transaction(
          "localized muscle-load feedback requires a bound NumanX attachment catalog"
        )
      }
      bodyLoadFrame = nil
      protectiveMuscleSelection = nil
    }
    return PreparedJointRootCommit(
      receipt: receipt,
      root: try prepareRootPublication(),
      localizedObservations: localizedObservations,
      bodyLoadFrame: bodyLoadFrame,
      protectiveMuscleSelection: protectiveMuscleSelection
    )
  }

  /// Fallible receipt, anatomy, and generation checks are complete. Only
  /// committed pointer/counter publication remains.
  func publishPreparedJointRootTransactionCommit(
    _ prepared: PreparedJointRootCommit
  ) {
    publishPreparedRootTransaction(prepared.root)
    latestCommittedMuscleLoadObservations = prepared.localizedObservations
    latestCommittedBodyLoadFrame = prepared.bodyLoadFrame
    latestCommittedProtectiveMuscleSelection = prepared.protectiveMuscleSelection
    pendingJointTransaction = nil
  }

  private func validateLocalizedMuscleLoadObservations(
    _ observations: [LocalizedMuscleLoadReceptorObservation]
  ) throws {
    guard !observations.isEmpty else { return }
    guard let numanXMuscleAttachmentCatalog,
      observations.allSatisfy({ observation in
        observation.attachmentCatalogFingerprint
          == numanXMuscleAttachmentCatalog.fingerprint
          && numanXMuscleAttachmentCatalog.attachment(
            forMuscleIdentifier: observation.attachment.muscleIdentifier
          ) == observation.attachment
      })
    else {
      throw TissueError.transaction(
        "localized muscle-load feedback does not match the bound attachment catalog"
      )
    }
  }

  private func writeProtectiveSourceInhibitionMask(
    observations: [LocalizedMuscleLoadReceptorObservation],
    targetTimestamp: BrainTimestamp
  ) throws {
    try validateLocalizedMuscleLoadObservations(observations)
    let inhibitedMuscleIdentifiers = Set(
      observations.map(\.attachment.muscleIdentifier)
    )
    let mask = protectiveSourceInhibitionMaskBuffer.contents().bindMemory(
      to: UInt32.self,
      capacity: protectiveMotorProfile.channels.count
    )
    for (index, channel) in protectiveMotorProfile.channels.enumerated() {
      mask[index] = inhibitedMuscleIdentifiers.contains(channel.muscleIdentifier) ? 1 : 0
    }
    try writeBodyLoadFieldUpdates(
      observations: observations,
      targetTimestamp: targetTimestamp
    )
  }

  private func writeFastCPGUniforms(
    timestamp: BrainTimestamp,
    oscillatorCount: Int? = nil,
    synergyCount: Int? = nil,
    consumeInterruptEvents: Bool = false
  ) {
    let resolvedOscillatorCount = oscillatorCount ?? stagedFastCPGOscillatorCount
    let resolvedSynergyCount = synergyCount ?? stagedFastCPGSynergyCount
    var uniforms = FastCPGUniforms(
      sampleTimestampMicroseconds: timestamp.rawValue,
      oscillatorCount: UInt32(resolvedOscillatorCount),
      synergyCount: UInt32(resolvedSynergyCount),
      flags: resolvedOscillatorCount > 0
        ? 1 | (consumeInterruptEvents ? 1 << 1 : 0)
        : (consumeInterruptEvents ? 1 << 1 : 0),
      reflexRuleCount: UInt32(boundFastReflexRuleCount)
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      fastCPGUniformBuffer.contents().copyMemory(
        from: source,
        byteCount: MemoryLayout<FastCPGUniforms>.stride
      )
    }
  }

  private func writeFastAutonomicUniforms(
    timestamp: BrainTimestamp,
    baselineTimestamp: BrainTimestamp,
    oscillatorCount: Int? = nil,
    consumeInterruptEvents: Bool = false
  ) {
    var uniforms = FastAutonomicUniforms(
      sampleTimestampMicroseconds: timestamp.rawValue,
      baselineTimestampMicroseconds: baselineTimestamp.rawValue,
      channelCount: UInt32(boundFastAutonomicChannelCount),
      flags: consumeInterruptEvents ? 1 : 0,
      vitalGain: boundFastAutonomicVitalGain,
      responseTimeMicroseconds: 50_000,
      criticalDecayMicroseconds: 500_000,
      oscillatorCount: UInt32(oscillatorCount ?? stagedFastCPGOscillatorCount)
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      fastAutonomicUniformBuffer.contents().copyMemory(
        from: source,
        byteCount: MemoryLayout<FastAutonomicUniforms>.stride
      )
    }
  }

  private func writeProtectiveCommandUniforms(brainGeneration: UInt64) {
    var uniforms = ProtectiveCommandUniforms(
      brainGeneration: brainGeneration,
      motorProfileFingerprint: protectiveMotorProfile.fingerprint,
      moduleCount: UInt32(brainSchedule.modules.count),
      muscleCount: UInt32(protectiveMotorProfile.channels.count),
      environmentIdentifier: schedulerEnvironmentIdentifier,
      reserved: 0
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      protectiveCommandUniformBuffer.contents().copyMemory(
        from: source,
        byteCount: MemoryLayout<ProtectiveCommandUniforms>.stride
      )
    }
  }

  private func writeBodyLoadFieldUpdates(
    observations: [LocalizedMuscleLoadReceptorObservation],
    targetTimestamp: BrainTimestamp
  ) throws {
    var records: [BodyLoadFieldRecord] = []
    records.reserveCapacity(observations.count * 2)
    for observation in observations {
      let attachment = observation.attachment
      let firstCell = try BodyLoadFieldCell(
        bodyIdentifier: attachment.firstBodyIdentifier,
        endpointRole: .firstRouteEndpoint,
        sourceMuscleIdentifier: attachment.muscleIdentifier,
        maximumAbsoluteMuscleForce: observation.maximumAbsoluteMuscleForce,
        acceptedTimestamp: observation.event.timestamp,
        acceptedPhysicsStateFingerprint: observation.acceptedPhysicsStateFingerprint,
        fieldActivationTimestamp: targetTimestamp,
        fieldStateTimestamp: targetTimestamp
      )
      if attachment.firstBodyIdentifier == attachment.terminalBodyIdentifier {
        let mergedCell = try BodyLoadFieldCell(
          bodyIdentifier: attachment.firstBodyIdentifier,
          endpointRole: [.firstRouteEndpoint, .terminalRouteEndpoint],
          sourceMuscleIdentifier: attachment.muscleIdentifier,
          maximumAbsoluteMuscleForce: observation.maximumAbsoluteMuscleForce,
          acceptedTimestamp: observation.event.timestamp,
          acceptedPhysicsStateFingerprint: observation.acceptedPhysicsStateFingerprint,
          fieldActivationTimestamp: targetTimestamp,
          fieldStateTimestamp: targetTimestamp
        )
        records.append(BodyLoadFieldRecord(cell: mergedCell))
      } else {
        records.append(BodyLoadFieldRecord(cell: firstCell))
        records.append(
          BodyLoadFieldRecord(
            cell: try BodyLoadFieldCell(
              bodyIdentifier: attachment.terminalBodyIdentifier,
              endpointRole: .terminalRouteEndpoint,
              sourceMuscleIdentifier: attachment.muscleIdentifier,
              maximumAbsoluteMuscleForce: observation.maximumAbsoluteMuscleForce,
              acceptedTimestamp: observation.event.timestamp,
              acceptedPhysicsStateFingerprint: observation.acceptedPhysicsStateFingerprint,
              fieldActivationTimestamp: targetTimestamp,
              fieldStateTimestamp: targetTimestamp
            )
          )
        )
      }
    }
    guard
      records.count * MemoryLayout<BodyLoadFieldRecord>.stride
        <= bodyLoadFieldUpdateCapacityByteCount
    else {
      throw TissueError.transaction("accepted body-load updates exceed GPU capacity")
    }
    records.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      bodyLoadFieldUpdateBuffer.contents().copyMemory(
        from: source,
        byteCount: bytes.count
      )
    }
    var uniforms = BodyLoadFieldUniforms(
      attachmentCatalogFingerprint: numanXMuscleAttachmentCatalog?.fingerprint ?? 0,
      bodyCount: numanXMuscleAttachmentCatalog?.bodyCount ?? 0,
      updateCount: UInt32(records.count),
      targetTimestampMicroseconds: targetTimestamp.rawValue,
      persistenceMicroseconds: bodyLoadFieldDynamics.persistenceMicroseconds,
      decayMicroseconds: bodyLoadFieldDynamics.decayMicroseconds
    )
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      bodyLoadFieldUniformBuffer.contents().copyMemory(
        from: source,
        byteCount: bytes.count
      )
    }
    var bodySchemaUniforms = BodySchemaUniforms(
      bodyCount: numanXMuscleAttachmentCatalog?.bodyCount ?? 0,
      reserved0: 0,
      targetTimestampMicroseconds: targetTimestamp.rawValue,
      forceScaleNewtons: bodySchemaDynamics.forceScaleNewtons,
      loadTimeConstantMicroseconds: bodySchemaDynamics.loadTimeConstantMicroseconds,
      initialVariance: bodySchemaDynamics.initialVariance,
      maximumVariance: bodySchemaDynamics.maximumVariance,
      processVariancePerSecond: bodySchemaDynamics.processVariancePerSecond,
      observationVariance: bodySchemaDynamics.observationVariance,
      vulnerabilityGainPerSecond: bodySchemaDynamics.vulnerabilityGainPerSecond,
      recoveryPerSecond: bodySchemaDynamics.recoveryPerSecond,
      uncertaintyRiskWeight: bodySchemaDynamics.uncertaintyRiskWeight,
      reserved1: 0
    )
    withUnsafeBytes(of: &bodySchemaUniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      bodySchemaUniformBuffer.contents().copyMemory(
        from: source,
        byteCount: bytes.count
      )
    }
  }

  private func prepareRootPublication() throws -> PreparedRootPublication {
    guard let pendingRootShadowIndex, let pendingRootShadowOwnerMask,
      let pendingRootShadowStep, let pendingRelayHistoryTimestamps,
      let pendingSchedulerClockIndex,
      let pendingSchedulerTargetTime, let pendingRegionalStateIndex
    else {
      throw TissueError.transaction("there is no Metal root transaction to commit")
    }
    guard pendingSchedulerInitialized == (committedSchedulerTime == nil) else {
      throw TissueError.transaction("scheduler initialization generation mismatch")
    }
    guard pendingRegionalStateIndex == pendingSchedulerClockIndex else {
      throw TissueError.transaction("regional shadow does not match scheduler shadow")
    }
    let (nextSchedulerGeneration, schedulerGenerationOverflow) =
      committedSchedulerGeneration.addingReportingOverflow(1)
    guard !schedulerGenerationOverflow else {
      throw TissueError.transaction("scheduler generation overflow")
    }
    return PreparedRootPublication(
      committedIndex: pendingRootShadowIndex,
      committedHistoryOwnerMask: pendingRootShadowOwnerMask,
      committedRelayHistoryTimestamps: pendingRelayHistoryTimestamps,
      committedStep: pendingRootShadowStep,
      committedSchedulerClockIndex: pendingSchedulerClockIndex,
      committedRegionalStateIndex: pendingRegionalStateIndex,
      committedSchedulerTime: pendingSchedulerTargetTime,
      committedSchedulerGeneration: nextSchedulerGeneration
    )
  }

  private func publishPreparedRootTransaction(
    _ prepared: PreparedRootPublication
  ) {
    committedIndex = prepared.committedIndex
    committedHistoryOwnerMask = prepared.committedHistoryOwnerMask
    committedRelayHistoryTimestamps = prepared.committedRelayHistoryTimestamps
    committedStep = prepared.committedStep
    committedSchedulerClockIndex = prepared.committedSchedulerClockIndex
    committedRegionalStateIndex = prepared.committedRegionalStateIndex
    committedBodyLoadFieldStateIndex = prepared.committedRegionalStateIndex
    committedSchedulerTime = prepared.committedSchedulerTime
    committedSchedulerGeneration = prepared.committedSchedulerGeneration
    hasCommittedSchedulerResult = true
    self.pendingRootShadowIndex = nil
    self.pendingRootShadowOwnerMask = nil
    self.pendingRootShadowStep = nil
    self.pendingRelayHistoryTimestamps = nil
    self.pendingSchedulerClockIndex = nil
    self.pendingSchedulerTargetTime = nil
    self.pendingRegionalStateIndex = nil
    self.pendingSchedulerInitialized = false
  }

  public func abortRootTransaction() throws {
    var jointTransaction = pendingJointTransaction
    try discardRootTransaction()
    if jointTransaction != nil {
      try jointTransaction?.abort()
      pendingJointTransaction = nil
    }
  }

  private struct TissueCheckpointBinding {
    let kind: MetalTissueCheckpointBufferKind
    let buffer: any MTLBuffer
    let size: Int
  }

  /// Captures every mutable fast-system allocation at a committed root. This
  /// is an explicit orchestration readback and never participates in the hot
  /// physics-brain loop.
  public func saveCheckpoint() throws -> MetalTissueCheckpoint {
    guard pendingRootShadowIndex == nil, pendingJointTransaction == nil,
      interactiveJointRoot == nil
    else {
      throw TissueError.transaction("commit or abort before saving fast tissue")
    }
    let records = try readCheckpointBindings(committedCheckpointBindings())
    return try MetalTissueCheckpoint(
      width: width,
      height: height,
      environmentIdentifier: schedulerEnvironmentIdentifier,
      randomContext: randomContext,
      committedStep: committedStep,
      committedSchedulerTime: committedSchedulerTime,
      committedSchedulerGeneration: committedSchedulerGeneration,
      committedHistoryOwnerMask: committedHistoryOwnerMask,
      committedRelayHistoryTimestamps: committedRelayHistoryTimestamps,
      parameterVersionFingerprint: parameterVersion.fingerprint,
      scheduleFingerprint: brainSchedule.fingerprint,
      regionalProgramFingerprint: regionalTokenProgram.fingerprint,
      sharedArtifactFingerprint: sharedParameterBank.artifactFingerprint,
      protectiveMotorProfileFingerprint: protectiveMotorProfile.fingerprint,
      attachmentCatalogFingerprint: numanXMuscleAttachmentCatalog?.fingerprint ?? 0,
      structureHash: structureHash,
      delayFieldHash: delayFieldHash,
      connectomeHash: connectomeHash,
      eventScheduleHash: eventScheduleHash,
      bodyLoadFieldDynamics: bodyLoadFieldDynamics,
      bodySchemaDynamics: bodySchemaDynamics,
      buffers: records
    )
  }

  public func validateCheckpointCompatibility(
    _ checkpoint: MetalTissueCheckpoint
  ) throws {
    try checkpoint.validate()
    let validHistoryMask: UInt32 =
      TissueDelayField.historyCapacity >= 32
      ? UInt32.max
      : (UInt32(1) << UInt32(TissueDelayField.historyCapacity)) - 1
    let expectedSizes = Dictionary(
      uniqueKeysWithValues: committedCheckpointBindings().map {
        ($0.kind, $0.size)
      }
    )
    guard checkpoint.width == width, checkpoint.height == height,
      checkpoint.environmentIdentifier == schedulerEnvironmentIdentifier,
      checkpoint.randomContext == randomContext,
      checkpoint.parameterVersionFingerprint == parameterVersion.fingerprint,
      checkpoint.scheduleFingerprint == brainSchedule.fingerprint,
      checkpoint.regionalProgramFingerprint == regionalTokenProgram.fingerprint,
      checkpoint.sharedArtifactFingerprint == sharedParameterBank.artifactFingerprint,
      checkpoint.protectiveMotorProfileFingerprint == protectiveMotorProfile.fingerprint,
      checkpoint.attachmentCatalogFingerprint
        == (numanXMuscleAttachmentCatalog?.fingerprint ?? 0),
      checkpoint.structureHash == structureHash,
      checkpoint.delayFieldHash == delayFieldHash,
      checkpoint.connectomeHash == connectomeHash,
      checkpoint.eventScheduleHash == eventScheduleHash,
      checkpoint.bodyLoadFieldDynamics == bodyLoadFieldDynamics,
      checkpoint.bodySchemaDynamics == bodySchemaDynamics,
      checkpoint.committedHistoryOwnerMask & ~validHistoryMask == 0,
      checkpoint.committedRelayHistoryTimestamps.count
        == TissueDelayField.historyCapacity,
      checkpoint.buffers.allSatisfy({ record in
        record.data.count == expectedSizes[record.kind]
      }),
      (checkpoint.committedSchedulerTime == nil)
        == (checkpoint.committedSchedulerGeneration == 0)
    else {
      throw TissueError.transaction(
        "fast-tissue checkpoint is incompatible with this runtime"
      )
    }
  }

  /// Restores into canonical generation zero. Shadow generations remain
  /// disposable; immutable identities and the checkpoint fingerprint prove
  /// that subsequent scheduling and random counters resume the same history.
  public func loadCheckpoint(_ checkpoint: MetalTissueCheckpoint) throws {
    guard pendingRootShadowIndex == nil, pendingJointTransaction == nil,
      interactiveJointRoot == nil
    else {
      throw TissueError.transaction("commit or abort before loading fast tissue")
    }
    try validateCheckpointCompatibility(checkpoint)
    try writeCheckpointBindings(
      restoredCheckpointBindings(),
      checkpoint: checkpoint
    )
    committedIndex = 0
    committedHistoryOwnerMask = checkpoint.committedHistoryOwnerMask
    committedRelayHistoryTimestamps = checkpoint.committedRelayHistoryTimestamps
    committedStep = checkpoint.committedStep
    committedSchedulerClockIndex = 0
    committedSchedulerTime = checkpoint.committedSchedulerTime
    committedSchedulerGeneration = checkpoint.committedSchedulerGeneration
    committedRegionalStateIndex = 0
    committedBodyLoadFieldStateIndex = 0
    pendingRootShadowIndex = nil
    pendingRootShadowOwnerMask = nil
    pendingRootShadowStep = nil
    pendingRelayHistoryTimestamps = nil
    pendingSchedulerClockIndex = nil
    pendingSchedulerTargetTime = nil
    pendingRegionalStateIndex = nil
    pendingSchedulerInitialized = false
    pendingJointTransaction = nil
    interactiveJointRoot = nil
    hasCommittedSchedulerResult = false
    descendingSomaticTransactionFingerprint = nil
    latestCommittedMuscleLoadObservations = []
    latestCommittedBodyLoadFrame = nil
    latestCommittedProtectiveMuscleSelection = nil
    protectiveSourceInhibitionMaskBuffer.contents().initializeMemory(
      as: UInt8.self,
      repeating: 0,
      count: protectiveSourceInhibitionMaskByteCount
    )
    try copy(
      source: zeroDescendingSomaticBuffer,
      destination: descendingSomaticBuffer,
      size: protectiveMuscleExcitationByteCount,
      label: "NumiBrain reset restored descending somatic command"
    )
  }

  private func committedCheckpointBindings() -> [TissueCheckpointBinding] {
    checkpointBindings(
      tissueIndex: committedIndex,
      schedulerIndex: committedSchedulerClockIndex,
      regionalIndex: committedRegionalStateIndex,
      bodyLoadIndex: committedBodyLoadFieldStateIndex
    )
  }

  private func restoredCheckpointBindings() -> [TissueCheckpointBinding] {
    checkpointBindings(
      tissueIndex: 0,
      schedulerIndex: 0,
      regionalIndex: 0,
      bodyLoadIndex: 0
    )
  }

  private func checkpointBindings(
    tissueIndex: Int,
    schedulerIndex: Int,
    regionalIndex: Int,
    bodyLoadIndex: Int
  ) -> [TissueCheckpointBinding] {
    [
      TissueCheckpointBinding(
        kind: .tissueState,
        buffer: stateBuffers[tissueIndex],
        size: stateByteCount
      ),
      TissueCheckpointBinding(
        kind: .relayHistory,
        buffer: relayHistoryBuffer,
        size: relayHistoryByteCount
      ),
      TissueCheckpointBinding(
        kind: .relayHistoryTimestamps,
        buffer: relayHistoryTimestampBuffer,
        size: relayHistoryTimestampByteCount
      ),
      TissueCheckpointBinding(
        kind: .schedulerClocks,
        buffer: schedulerClockBuffers[schedulerIndex],
        size: schedulerClockByteCount
      ),
      TissueCheckpointBinding(
        kind: .regionalStates,
        buffer: regionalStateBuffers[regionalIndex],
        size: regionalStateByteCount
      ),
      TissueCheckpointBinding(
        kind: .regionalTokens,
        buffer: regionalTokenStateBuffers[regionalIndex],
        size: regionalTokenStateByteCount
      ),
      TissueCheckpointBinding(
        kind: .routeHistoryStates,
        buffer: regionalRouteHistoryStateBuffers[regionalIndex],
        size: regionalRouteHistoryStateByteCount
      ),
      TissueCheckpointBinding(
        kind: .routeHistoryTimestamps,
        buffer: regionalRouteHistoryTimestampBuffers[regionalIndex],
        size: regionalRouteHistoryTimestampByteCount
      ),
      TissueCheckpointBinding(
        kind: .routeHistoryValues,
        buffer: regionalRouteHistoryValueBuffers[regionalIndex],
        size: regionalRouteHistoryValueByteCount
      ),
      TissueCheckpointBinding(
        kind: .routeRuntimeStates,
        buffer: regionalRouteRuntimeStateBuffers[regionalIndex],
        size: regionalRouteRuntimeStateByteCount
      ),
      TissueCheckpointBinding(
        kind: .protectiveCommand,
        buffer: protectiveCommandBuffers[regionalIndex],
        size: ProtectiveMotorCommand.byteCount
      ),
      TissueCheckpointBinding(
        kind: .protectiveMotorHeader,
        buffer: protectiveMotorOutputHeaderBuffers[regionalIndex],
        size: ProtectiveMotorOutput.headerByteCount
      ),
      TissueCheckpointBinding(
        kind: .protectiveMuscleExcitations,
        buffer: protectiveMuscleExcitationBuffers[regionalIndex],
        size: protectiveMuscleExcitationByteCount
      ),
      TissueCheckpointBinding(
        kind: .bodyLoadField,
        buffer: bodyLoadFieldStateBuffers[bodyLoadIndex],
        size: bodyLoadFieldStateByteCount
      ),
      TissueCheckpointBinding(
        kind: .bodySchema,
        buffer: bodySchemaStateBuffers[regionalIndex],
        size: bodySchemaStateByteCount
      ),
    ]
  }

  private func readCheckpointBindings(
    _ bindings: [TissueCheckpointBinding]
  ) throws -> [MetalTissueCheckpointBuffer] {
    let (offsets, totalByteCount) = try checkpointOffsets(bindings)
    guard
      let transfer = device.makeBuffer(
        length: max(totalByteCount, 1),
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate fast checkpoint readback")
    }
    transfer.label = "NumiBrain fast checkpoint readback"
    let residency = try makeCheckpointResidency(transfer)
    defer { residency.endResidency() }
    _ = try submit(
      label: "NumiBrain fast checkpoint capture",
      additionalResidencySet: residency
    ) { encoder in
      for (binding, offset) in zip(bindings, offsets) where binding.size > 0 {
        encoder.copy(
          sourceBuffer: binding.buffer,
          sourceOffset: 0,
          destinationBuffer: transfer,
          destinationOffset: offset,
          size: binding.size
        )
      }
    }
    return zip(bindings, offsets).map { binding, offset in
      MetalTissueCheckpointBuffer(
        kind: binding.kind,
        data: Data(
          bytes: transfer.contents().advanced(by: offset),
          count: binding.size
        )
      )
    }
  }

  private func writeCheckpointBindings(
    _ bindings: [TissueCheckpointBinding],
    checkpoint: MetalTissueCheckpoint
  ) throws {
    let (offsets, totalByteCount) = try checkpointOffsets(bindings)
    guard
      let transfer = device.makeBuffer(
        length: max(totalByteCount, 1),
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate fast checkpoint upload")
    }
    transfer.label = "NumiBrain fast checkpoint upload"
    for (binding, offset) in zip(bindings, offsets) {
      checkpoint.buffer(binding.kind).withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        transfer.contents().advanced(by: offset).copyMemory(
          from: source,
          byteCount: binding.size
        )
      }
    }
    let residency = try makeCheckpointResidency(transfer)
    defer { residency.endResidency() }
    _ = try submit(
      label: "NumiBrain fast checkpoint restore",
      additionalResidencySet: residency
    ) { encoder in
      for (binding, offset) in zip(bindings, offsets) where binding.size > 0 {
        encoder.copy(
          sourceBuffer: transfer,
          sourceOffset: offset,
          destinationBuffer: binding.buffer,
          destinationOffset: 0,
          size: binding.size
        )
      }
    }
  }

  private func checkpointOffsets(
    _ bindings: [TissueCheckpointBinding]
  ) throws -> ([Int], Int) {
    var offsets: [Int] = []
    offsets.reserveCapacity(bindings.count)
    var total = 0
    for binding in bindings {
      guard binding.size >= 0, binding.size <= binding.buffer.length else {
        throw TissueError.metal("fast checkpoint buffer size is invalid")
      }
      offsets.append(total)
      let (next, overflow) = total.addingReportingOverflow(binding.size)
      guard !overflow else {
        throw TissueError.metal("fast checkpoint byte count overflows Int")
      }
      total = next
    }
    return (offsets, total)
  }

  private func makeCheckpointResidency(
    _ transfer: any MTLBuffer
  ) throws -> any MTLResidencySet {
    let descriptor = MTLResidencySetDescriptor()
    descriptor.label = "NumiBrain fast checkpoint transfer residency"
    descriptor.initialCapacity = 1
    let residency: any MTLResidencySet
    do {
      residency = try device.makeResidencySet(descriptor: descriptor)
    } catch {
      throw TissueError.metal("failed to create fast checkpoint residency: \(error)")
    }
    residency.addAllocation(transfer)
    residency.commit()
    residency.requestResidency()
    return residency
  }

  private func discardRootTransaction() throws {
    guard pendingRootShadowIndex != nil else {
      throw TissueError.transaction("there is no Metal root transaction to abort")
    }
    pendingRootShadowIndex = nil
    pendingRootShadowOwnerMask = nil
    pendingRootShadowStep = nil
    pendingRelayHistoryTimestamps = nil
    pendingSchedulerClockIndex = nil
    pendingSchedulerTargetTime = nil
    pendingRegionalStateIndex = nil
    pendingSchedulerInitialized = false
    hasCommittedSchedulerResult = false
  }

  public func snapshotCommitted() throws -> TissueGrid {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading committed state")
    }
    try copy(
      source: stateBuffers[committedIndex],
      destination: stagingBuffer,
      label: "NumiBrain tissue committed inspection"
    )
    let pointer = stagingBuffer.contents()
      .bindMemory(to: TissueCell.self, capacity: width * height)
    let cells = Array(UnsafeBufferPointer(start: pointer, count: width * height))
    return try TissueGrid(width: width, height: height, cells: cells)
  }

  public func snapshotCommittedRelayHistoryTimestamps() throws -> [BrainTimestamp] {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading relay-history timestamps")
    }
    try copy(
      source: relayHistoryTimestampBuffer,
      destination: stagingBuffer,
      size: relayHistoryTimestampByteCount,
      label: "NumiBrain committed relay-history timestamp inspection"
    )
    let timestampPointer = stagingBuffer.contents().bindMemory(
      to: UInt64.self,
      capacity: 2 * TissueDelayField.historyCapacity
    )
    let timestamps = (0..<TissueDelayField.historyCapacity).map { slot in
      let plane = Int((committedHistoryOwnerMask >> UInt32(slot)) & 1)
      return timestampPointer[plane * TissueDelayField.historyCapacity + slot]
    }
    guard timestamps == committedRelayHistoryTimestamps else {
      throw TissueError.metal("GPU relay-history timestamp ownership diverged from the runtime")
    }
    return timestamps.map(BrainTimestamp.init(microseconds:))
  }

  public func inspectCommittedScheduler() throws -> SchedulerInspection {
    guard pendingRootShadowIndex == nil, interactiveJointRoot == nil else {
      throw TissueError.transaction("commit or abort before inspecting scheduler state")
    }
    guard let committedSchedulerTime, hasCommittedSchedulerResult else {
      throw TissueError.transaction("there is no committed scheduler result to inspect")
    }
    return try inspectSchedulerState(
      clockIndex: committedSchedulerClockIndex,
      timestamp: committedSchedulerTime,
      generation: committedSchedulerGeneration,
      label: "NumiBrain committed scheduler inspection"
    )
  }

  /// Explicit inspection readback for the latest accepted physical prefix.
  /// It is unavailable while a tissue candidate is unresolved and is not part
  /// of the GPU-resident control hot path.
  public func inspectInteractiveFastScheduler() throws -> SchedulerInspection {
    guard let root = interactiveJointRoot, root.candidate == nil,
      let window = root.fastSchedulerWindow
    else {
      throw TissueError.transaction("there is no accepted fast scheduler prefix to inspect")
    }
    return try inspectSchedulerState(
      clockIndex: window.outputClockIndex,
      timestamp: root.acceptedTimestamp,
      generation: root.transaction.token.shadowGeneration,
      label: "NumiBrain interactive fast scheduler inspection"
    )
  }

  private func inspectSchedulerState(
    clockIndex: Int,
    timestamp: BrainTimestamp,
    generation: UInt64,
    label: String
  ) throws -> SchedulerInspection {
    let transductionResultOffset = 0
    let resultOffset = MemoryLayout<NBReceptorEventTransductionResult>.stride
    let clockOffset = resultOffset + MemoryLayout<NBSchedulerResult>.stride
    let invocationOffset = clockOffset + schedulerClockByteCount
    _ = try submit(label: label) { encoder in
      encoder.copy(
        sourceBuffer: receptorEventTransductionResultBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: transductionResultOffset,
        size: MemoryLayout<NBReceptorEventTransductionResult>.stride
      )
      encoder.copy(
        sourceBuffer: schedulerResultBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: resultOffset,
        size: MemoryLayout<NBSchedulerResult>.stride
      )
      encoder.copy(
        sourceBuffer: schedulerClockBuffers[clockIndex],
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: clockOffset,
        size: schedulerClockByteCount
      )
      encoder.copy(
        sourceBuffer: schedulerInvocationBuffer,
        sourceOffset: 0,
        destinationBuffer: stagingBuffer,
        destinationOffset: invocationOffset,
        size: schedulerInvocationCapacityByteCount
      )
    }
    let transductionResult = stagingBuffer.contents()
      .advanced(by: transductionResultOffset)
      .load(as: NBReceptorEventTransductionResult.self)
    guard
      transductionResult.status
        == UInt32(NB_RECEPTOR_TRANSDUCTION_STATUS_VALID.rawValue)
    else {
      throw TissueError.metal(
        "receptor-event transduction reported status \(transductionResult.status)"
      )
    }
    guard transductionResult.event_count <= UInt32(maxSchedulerEvents),
      transductionResult.receptor_event_count <= transductionResult.event_count
    else {
      throw TissueError.metal("receptor-event transduction count exceeds capacity")
    }
    let result = stagingBuffer.contents()
      .advanced(by: resultOffset)
      .load(as: NBSchedulerResult.self)
    guard result.status == UInt32(NB_SCHEDULER_STATUS_VALID.rawValue) else {
      throw TissueError.metal("scheduler kernel reported status \(result.status)")
    }
    guard result.target_time_microseconds == timestamp.rawValue else {
      throw TissueError.metal("scheduler result target does not match inspected time")
    }
    guard result.invocation_count <= UInt32(maxSchedulerInvocations) else {
      throw TissueError.metal("scheduler result invocation count exceeds capacity")
    }
    let clockPointer = stagingBuffer.contents()
      .advanced(by: clockOffset)
      .bindMemory(
        to: NBModuleClockState.self,
        capacity: brainSchedule.modules.count
      )
    let clocks = UnsafeBufferPointer(
      start: clockPointer,
      count: brainSchedule.modules.count
    ).map(BrainModuleClockState.init(abiRecord:))
    let invocationPointer = stagingBuffer.contents()
      .advanced(by: invocationOffset)
      .bindMemory(
        to: NBDueInvocation.self,
        capacity: Int(result.invocation_count)
      )
    let invocations = try UnsafeBufferPointer(
      start: invocationPointer,
      count: Int(result.invocation_count)
    ).map { record in
      guard record.environment_identifier == schedulerEnvironmentIdentifier else {
        throw TissueError.metal("scheduler invocation environment identity drift")
      }
      return try BrainModuleInvocation(abiRecord: record)
    }
    return SchedulerInspection(
      snapshot: BrainSchedulerSnapshot(
        scheduleFingerprint: brainSchedule.fingerprint,
        parameterVersionFingerprint: parameterVersion.fingerprint,
        committedTime: timestamp,
        generation: generation,
        moduleClocks: clocks
      ),
      invocations: invocations,
      status: result.status,
      transducedEventCount: Int(transductionResult.event_count),
      receptorEventCount: Int(transductionResult.receptor_event_count),
      transductionStatus: transductionResult.status
    )
  }

  public func snapshotCommittedScheduler() throws -> BrainSchedulerSnapshot {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading scheduler clocks")
    }
    guard let committedSchedulerTime else {
      throw TissueError.transaction("there is no committed scheduler state to read")
    }
    try copy(
      source: schedulerClockBuffers[committedSchedulerClockIndex],
      destination: stagingBuffer,
      size: schedulerClockByteCount,
      label: "NumiBrain committed scheduler clock inspection"
    )
    let clockPointer = stagingBuffer.contents()
      .bindMemory(
        to: NBModuleClockState.self,
        capacity: brainSchedule.modules.count
      )
    let clocks = UnsafeBufferPointer(
      start: clockPointer,
      count: brainSchedule.modules.count
    ).map(BrainModuleClockState.init(abiRecord:))
    return BrainSchedulerSnapshot(
      scheduleFingerprint: brainSchedule.fingerprint,
      parameterVersionFingerprint: parameterVersion.fingerprint,
      committedTime: committedSchedulerTime,
      generation: committedSchedulerGeneration,
      moduleClocks: clocks
    )
  }

  public func snapshotCommittedRegionalState() throws -> RegionalModuleSnapshot {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading regional state")
    }
    guard let committedSchedulerTime else {
      throw TissueError.transaction("there is no committed regional state to read")
    }
    return try snapshotRegionalState(
      stateIndex: committedRegionalStateIndex,
      timestamp: committedSchedulerTime,
      generation: committedSchedulerGeneration,
      label: "NumiBrain committed regional-state inspection"
    )
  }

  /// Explicit inspection readback of the regional shadow produced after the
  /// latest accepted physical substep. It never publishes that shadow.
  public func snapshotInteractiveFastRegionalState() throws -> RegionalModuleSnapshot {
    guard let root = interactiveJointRoot, root.candidate == nil,
      let window = root.fastSchedulerWindow
    else {
      throw TissueError.transaction("there is no accepted fast regional prefix to inspect")
    }
    return try snapshotRegionalState(
      stateIndex: window.outputClockIndex,
      timestamp: root.acceptedTimestamp,
      generation: root.transaction.token.shadowGeneration,
      label: "NumiBrain interactive fast regional-state inspection"
    )
  }

  public func snapshotCommittedBodyLoadField() throws -> [BodyLoadFieldCell] {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading body-load field state")
    }
    return try snapshotBodyLoadField(
      stateIndex: committedBodyLoadFieldStateIndex,
      label: "NumiBrain committed body-load field inspection"
    )
  }

  public func snapshotInteractiveBodyLoadField() throws -> [BodyLoadFieldCell] {
    guard let root = interactiveJointRoot else {
      throw TissueError.transaction("there is no interactive body-load field state")
    }
    let stateIndex =
      root.fastSchedulerWindow?.outputClockIndex
      ?? committedBodyLoadFieldStateIndex
    return try snapshotBodyLoadField(
      stateIndex: stateIndex,
      label: "NumiBrain interactive body-load field inspection"
    )
  }

  private func snapshotBodyLoadField(
    stateIndex: Int,
    label: String
  ) throws -> [BodyLoadFieldCell] {
    guard let numanXMuscleAttachmentCatalog else { return [] }
    try copy(
      source: bodyLoadFieldStateBuffers[stateIndex],
      destination: stagingBuffer,
      size: bodyLoadFieldStateByteCount,
      label: label
    )
    let records = stagingBuffer.contents().bindMemory(
      to: BodyLoadFieldRecord.self,
      capacity: Int(numanXMuscleAttachmentCatalog.bodyCount)
    )
    var cells: [BodyLoadFieldCell] = []
    for bodyIdentifier in 0..<numanXMuscleAttachmentCatalog.bodyCount {
      let record = records[Int(bodyIdentifier)]
      guard record.bodyIdentifier == bodyIdentifier else {
        throw TissueError.metal("body-load field identity drift")
      }
      if let cell = try record.value() {
        cells.append(cell)
      }
    }
    return cells
  }

  public func snapshotCommittedBodySchema() throws -> [BodySchemaPosteriorCell] {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading body-schema state")
    }
    return try snapshotBodySchema(
      stateIndex: committedRegionalStateIndex,
      label: "NumiBrain committed body-schema inspection"
    )
  }

  public func snapshotInteractiveBodySchema() throws -> [BodySchemaPosteriorCell] {
    guard let root = interactiveJointRoot else {
      throw TissueError.transaction("there is no interactive body-schema state")
    }
    let stateIndex = root.fastSchedulerWindow?.outputClockIndex
      ?? committedRegionalStateIndex
    return try snapshotBodySchema(
      stateIndex: stateIndex,
      label: "NumiBrain interactive body-schema inspection"
    )
  }

  private func snapshotBodySchema(
    stateIndex: Int,
    label: String
  ) throws -> [BodySchemaPosteriorCell] {
    guard let numanXMuscleAttachmentCatalog else { return [] }
    try copy(
      source: bodySchemaStateBuffers[stateIndex],
      destination: stagingBuffer,
      size: bodySchemaStateByteCount,
      label: label
    )
    let records = stagingBuffer.contents().bindMemory(
      to: BodySchemaRecord.self,
      capacity: Int(numanXMuscleAttachmentCatalog.bodyCount)
    )
    return try (0..<numanXMuscleAttachmentCatalog.bodyCount).map { bodyIdentifier in
      let record = records[Int(bodyIdentifier)]
      guard record.bodyIdentifier == bodyIdentifier else {
        throw TissueError.metal("body-schema identity drift")
      }
      return try record.value()
    }
  }

  public func snapshotCommittedProtectiveCommand() throws -> ProtectiveMotorCommand {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading protective output")
    }
    return try snapshotProtectiveCommand(
      stateIndex: committedRegionalStateIndex,
      timestamp: committedSchedulerTime ?? BrainTimestamp(microseconds: 0),
      generation: committedSchedulerGeneration,
      label: "NumiBrain committed protective-command inspection"
    )
  }

  /// Explicit inspection readback for tests and diagnostics. The normal
  /// physics bridge consumes `FastSystemResult.protectiveCommand` on the GPU.
  public func snapshotInteractiveProtectiveCommand() throws -> ProtectiveMotorCommand {
    guard let root = interactiveJointRoot, root.candidate == nil,
      let window = root.fastSchedulerWindow
    else {
      throw TissueError.transaction("there is no accepted protective command to inspect")
    }
    return try snapshotProtectiveCommand(
      stateIndex: window.outputClockIndex,
      timestamp: root.acceptedTimestamp,
      generation: root.transaction.token.shadowGeneration,
      label: "NumiBrain interactive protective-command inspection"
    )
  }

  public func snapshotCommittedProtectiveMotorOutput() throws -> ProtectiveMotorOutput {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading protective motor output")
    }
    return try snapshotProtectiveMotorOutput(
      stateIndex: committedRegionalStateIndex,
      timestamp: committedSchedulerTime ?? BrainTimestamp(microseconds: 0),
      generation: committedSchedulerGeneration,
      label: "NumiBrain committed protective-motor inspection"
    )
  }

  /// Explicit inspection readback for tests and diagnostics. The normal
  /// physics bridge consumes the paired GPU addresses in `FastSystemResult`.
  public func snapshotInteractiveProtectiveMotorOutput() throws -> ProtectiveMotorOutput {
    guard let root = interactiveJointRoot, root.candidate == nil,
      let window = root.fastSchedulerWindow
    else {
      throw TissueError.transaction("there is no accepted protective motor output to inspect")
    }
    return try snapshotProtectiveMotorOutput(
      stateIndex: window.outputClockIndex,
      timestamp: root.acceptedTimestamp,
      generation: root.transaction.token.shadowGeneration,
      label: "NumiBrain interactive protective-motor inspection"
    )
  }

  private func snapshotProtectiveCommand(
    stateIndex: Int,
    timestamp: BrainTimestamp,
    generation: UInt64,
    label: String
  ) throws -> ProtectiveMotorCommand {
    try copy(
      source: protectiveCommandBuffers[stateIndex],
      destination: stagingBuffer,
      size: ProtectiveMotorCommand.byteCount,
      label: label
    )
    let record = stagingBuffer.contents().load(as: NBProtectiveCommand.self)
    let command = try ProtectiveMotorCommand(validating: record)
    guard command.timestamp == timestamp, command.brainGeneration == generation,
      command.environmentIdentifier == schedulerEnvironmentIdentifier
    else {
      throw TissueError.metal("protective command identity diverged from its state generation")
    }
    return command
  }

  private func snapshotProtectiveMotorOutput(
    stateIndex: Int,
    timestamp: BrainTimestamp,
    generation: UInt64,
    label: String
  ) throws -> ProtectiveMotorOutput {
    try copy(
      source: protectiveMotorOutputHeaderBuffers[stateIndex],
      destination: stagingBuffer,
      size: ProtectiveMotorOutput.headerByteCount,
      label: "\(label) header"
    )
    let header = stagingBuffer.contents().load(as: NBMotorOutputHeader.self)
    try copy(
      source: protectiveMuscleExcitationBuffers[stateIndex],
      destination: stagingBuffer,
      size: protectiveMuscleExcitationByteCount,
      label: "\(label) excitations"
    )
    let pointer = stagingBuffer.contents().bindMemory(
      to: Float.self,
      capacity: protectiveMotorProfile.channels.count
    )
    let excitations = Array(
      UnsafeBufferPointer(start: pointer, count: protectiveMotorProfile.channels.count)
    )
    let output = try ProtectiveMotorOutput(
      validating: header,
      muscleExcitations: excitations,
      expectedProfile: protectiveMotorProfile
    )
    guard output.timestamp == timestamp, output.brainGeneration == generation,
      output.environmentIdentifier == schedulerEnvironmentIdentifier
    else {
      throw TissueError.metal("protective motor output identity diverged from its state generation")
    }
    return output
  }

  private func snapshotRegionalState(
    stateIndex: Int,
    timestamp: BrainTimestamp,
    generation: UInt64,
    label: String
  ) throws -> RegionalModuleSnapshot {
    try copy(
      source: regionalStateBuffers[stateIndex],
      destination: stagingBuffer,
      size: regionalStateByteCount,
      label: label
    )
    let statePointer = stagingBuffer.contents()
      .bindMemory(
        to: NBRegionalModuleState.self,
        capacity: brainSchedule.modules.count
      )
    let states = UnsafeBufferPointer(
      start: statePointer,
      count: brainSchedule.modules.count
    ).map(RegionalModuleState.init(abiRecord:))
    return RegionalModuleSnapshot(
      scheduleFingerprint: brainSchedule.fingerprint,
      committedTime: timestamp,
      generation: generation,
      states: states
    )
  }

  public func snapshotCommittedRegionalTokens() throws -> RegionalTokenSnapshot {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading regional tokens")
    }
    guard let committedSchedulerTime else {
      throw TissueError.transaction("there is no committed regional token state to read")
    }
    try copy(
      source: regionalTokenStateBuffers[committedRegionalStateIndex],
      destination: stagingBuffer,
      size: regionalTokenStateByteCount,
      label: "NumiBrain committed regional-token inspection"
    )
    let values = Array(
      UnsafeBufferPointer(
        start: stagingBuffer.contents().bindMemory(
          to: Float.self,
          capacity: regionalTokenProgram.scalarCount
        ),
        count: regionalTokenProgram.scalarCount
      )
    )
    return RegionalTokenSnapshot(
      scheduleFingerprint: brainSchedule.fingerprint,
      programFingerprint: regionalTokenProgram.fingerprint,
      committedTime: committedSchedulerTime,
      generation: committedSchedulerGeneration,
      values: values
    )
  }

  public func snapshotCommittedRegionalRouteHistory() throws
    -> RegionalRouteHistorySnapshot
  {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading regional route history")
    }
    guard let committedSchedulerTime else {
      throw TissueError.transaction("there is no committed regional route history to read")
    }
    let states: [RegionalRouteHistoryState]
    if regionalTokenProgram.routes.isEmpty {
      states = []
    } else {
      try copy(
        source: regionalRouteHistoryStateBuffers[committedRegionalStateIndex],
        destination: stagingBuffer,
        size: regionalRouteHistoryStateByteCount,
        label: "NumiBrain committed regional route-history metadata inspection"
      )
      let statePointer = stagingBuffer.contents().bindMemory(
        to: NBRegionalRouteHistoryState.self,
        capacity: regionalTokenProgram.routes.count
      )
      states = UnsafeBufferPointer(
        start: statePointer,
        count: regionalTokenProgram.routes.count
      ).map(RegionalRouteHistoryState.init(abiRecord:))
    }
    let timestampCount =
      regionalTokenProgram.routes.count
      * regionalTokenProgram.compiledRouteHistoryCapacity
    let timestamps: [UInt64]
    if timestampCount == 0 {
      timestamps = []
    } else {
      try copy(
        source: regionalRouteHistoryTimestampBuffers[committedRegionalStateIndex],
        destination: stagingBuffer,
        size: regionalRouteHistoryTimestampByteCount,
        label: "NumiBrain committed regional route-history timestamp inspection"
      )
      timestamps = Array(
        UnsafeBufferPointer(
          start: stagingBuffer.contents().bindMemory(
            to: UInt64.self,
            capacity: timestampCount
          ),
          count: timestampCount
        )
      )
    }
    let values: [Float]
    if regionalTokenProgram.routeHistoryScalarCount == 0 {
      values = []
    } else {
      try copy(
        source: regionalRouteHistoryValueBuffers[committedRegionalStateIndex],
        destination: stagingBuffer,
        size: regionalRouteHistoryValueByteCount,
        label: "NumiBrain committed regional route-history value inspection"
      )
      values = Array(
        UnsafeBufferPointer(
          start: stagingBuffer.contents().bindMemory(
            to: Float.self,
            capacity: regionalTokenProgram.routeHistoryScalarCount
          ),
          count: regionalTokenProgram.routeHistoryScalarCount
        )
      )
    }
    let history = try RegionalRouteHistory(
      program: regionalTokenProgram,
      states: states,
      timestamps: timestamps,
      values: values
    )
    return RegionalRouteHistorySnapshot(
      scheduleFingerprint: brainSchedule.fingerprint,
      programFingerprint: regionalTokenProgram.fingerprint,
      committedTime: committedSchedulerTime,
      generation: committedSchedulerGeneration,
      history: history
    )
  }

  public func snapshotCommittedRegionalRoutingState() throws -> RegionalRoutingSnapshot {
    guard pendingRootShadowIndex == nil else {
      throw TissueError.transaction("commit or abort before reading regional routing state")
    }
    guard let committedSchedulerTime else {
      throw TissueError.transaction("there is no committed regional routing state to read")
    }
    let states: [RegionalRouteRuntimeState]
    if regionalTokenProgram.routes.isEmpty {
      states = []
    } else {
      try copy(
        source: regionalRouteRuntimeStateBuffers[committedRegionalStateIndex],
        destination: stagingBuffer,
        size: regionalRouteRuntimeStateByteCount,
        label: "NumiBrain committed regional routing-state inspection"
      )
      let statePointer = stagingBuffer.contents().bindMemory(
        to: NBRegionalRouteRuntimeState.self,
        capacity: regionalTokenProgram.routes.count
      )
      states = UnsafeBufferPointer(
        start: statePointer,
        count: regionalTokenProgram.routes.count
      ).map(RegionalRouteRuntimeState.init(abiRecord:))
    }
    let routingState = try RegionalRoutingState(
      program: regionalTokenProgram,
      states: states
    )
    return RegionalRoutingSnapshot(
      scheduleFingerprint: brainSchedule.fingerprint,
      programFingerprint: regionalTokenProgram.fingerprint,
      committedTime: committedSchedulerTime,
      generation: committedSchedulerGeneration,
      routingState: routingState
    )
  }

  private func encodeRootFinalization(
    _ encoder: any MTL4ComputeCommandEncoder,
    schedulerWindow: PreparedSchedulerWindow
  ) {
    receptorInterruptArgumentTable.setAddress(
      receptorEventTransductionUniformBuffer.gpuAddress,
      index: 0
    )
    receptorInterruptArgumentTable.setAddress(eventBuffer.gpuAddress, index: 1)
    receptorInterruptArgumentTable.setAddress(
      schedulerEventUploadBuffer.gpuAddress,
      index: 2
    )
    receptorInterruptArgumentTable.setAddress(
      transducedSchedulerEventBuffer.gpuAddress,
      index: 3
    )
    receptorInterruptArgumentTable.setAddress(
      receptorEventTransductionResultBuffer.gpuAddress,
      index: 4
    )
    receptorInterruptArgumentTable.setAddress(
      stagedCognitiveEventQueueBuffer.gpuAddress,
      index: 5
    )
    encoder.setComputePipelineState(receptorInterruptTransductionPipeline)
    encoder.setArgumentTable(receptorInterruptArgumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
    schedulerArgumentTable.setAddress(schedulerUniformBuffer.gpuAddress, index: 0)
    schedulerArgumentTable.setAddress(schedulerDescriptorBuffer.gpuAddress, index: 1)
    schedulerArgumentTable.setAddress(
      schedulerClockBuffers[schedulerWindow.inputClockIndex].gpuAddress,
      index: 2
    )
    schedulerArgumentTable.setAddress(
      schedulerClockBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 3
    )
    schedulerArgumentTable.setAddress(transducedSchedulerEventBuffer.gpuAddress, index: 4)
    schedulerArgumentTable.setAddress(schedulerInvocationBuffer.gpuAddress, index: 5)
    schedulerArgumentTable.setAddress(schedulerResultBuffer.gpuAddress, index: 6)
    schedulerArgumentTable.setAddress(
      receptorEventTransductionResultBuffer.gpuAddress,
      index: 7
    )
    schedulerArgumentTable.setAddress(parameterVersionBindingBuffer.gpuAddress, index: 8)
    let maturationBuffer =
      descendingSomaticTransactionFingerprint
        == interactiveJointRoot?.transaction.token.fingerprint
      ? stagedRegionalMaturationBuffer
      : defaultRegionalMaturationBuffer
    schedulerArgumentTable.setAddress(maturationBuffer.gpuAddress, index: 9)
    encoder.setComputePipelineState(schedulerPipeline)
    encoder.setArgumentTable(schedulerArgumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
    regionalArgumentTable.setAddress(regionalProgramHeaderBuffer.gpuAddress, index: 0)
    regionalArgumentTable.setAddress(schedulerDescriptorBuffer.gpuAddress, index: 1)
    regionalArgumentTable.setAddress(regionalLayoutBuffer.gpuAddress, index: 2)
    regionalArgumentTable.setAddress(regionalRouteBuffer.gpuAddress, index: 3)
    regionalArgumentTable.setAddress(regionalParameterBuffer.gpuAddress, index: 4)
    regionalArgumentTable.setAddress(schedulerResultBuffer.gpuAddress, index: 5)
    regionalArgumentTable.setAddress(schedulerInvocationBuffer.gpuAddress, index: 6)
    regionalArgumentTable.setAddress(
      regionalStateBuffers[committedRegionalStateIndex].gpuAddress,
      index: 7
    )
    regionalArgumentTable.setAddress(
      regionalStateBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 8
    )
    regionalArgumentTable.setAddress(
      regionalTokenStateBuffers[committedRegionalStateIndex].gpuAddress,
      index: 9
    )
    regionalArgumentTable.setAddress(
      regionalTokenStateBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 10
    )
    regionalArgumentTable.setAddress(regionalTokenCandidateBuffer.gpuAddress, index: 11)
    regionalArgumentTable.setAddress(
      regionalRouteHistoryStateBuffers[committedRegionalStateIndex].gpuAddress,
      index: 12
    )
    regionalArgumentTable.setAddress(
      regionalRouteHistoryStateBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 13
    )
    regionalArgumentTable.setAddress(
      regionalRouteHistoryTimestampBuffers[committedRegionalStateIndex].gpuAddress,
      index: 14
    )
    regionalArgumentTable.setAddress(
      regionalRouteHistoryTimestampBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 15
    )
    regionalArgumentTable.setAddress(
      regionalRouteHistoryValueBuffers[committedRegionalStateIndex].gpuAddress,
      index: 16
    )
    regionalArgumentTable.setAddress(
      regionalRouteHistoryValueBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 17
    )
    regionalArgumentTable.setAddress(
      regionalResolvedRouteHistorySlotBuffer.gpuAddress,
      index: 18
    )
    regionalArgumentTable.setAddress(
      regionalRouteRuntimeStateBuffers[committedRegionalStateIndex].gpuAddress,
      index: 19
    )
    regionalArgumentTable.setAddress(
      regionalRouteRuntimeStateBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 20
    )
    regionalArgumentTable.setAddress(
      regionalSelectedRouteIndexBuffer.gpuAddress,
      index: 21
    )
    regionalArgumentTable.setAddress(
      regionalSelectedRouteCountBuffer.gpuAddress,
      index: 22
    )
    regionalArgumentTable.setAddress(parameterVersionBindingBuffer.gpuAddress, index: 23)
    let plasticModulationBuffer =
      descendingSomaticTransactionFingerprint
        == interactiveJointRoot?.transaction.token.fingerprint
      ? stagedRegionalPlasticModulationBuffer
      : defaultRegionalPlasticModulationBuffer
    regionalArgumentTable.setAddress(plasticModulationBuffer.gpuAddress, index: 24)
    regionalArgumentTable.setAddress(maturationBuffer.gpuAddress, index: 25)
    encoder.setComputePipelineState(regionalPipeline)
    encoder.setArgumentTable(regionalArgumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: regionalThreadgroupSize(),
      threadsPerThreadgroup: regionalThreadgroupSize()
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
    protectiveArgumentTable.setAddress(schedulerResultBuffer.gpuAddress, index: 0)
    protectiveArgumentTable.setAddress(schedulerInvocationBuffer.gpuAddress, index: 1)
    protectiveArgumentTable.setAddress(schedulerDescriptorBuffer.gpuAddress, index: 2)
    protectiveArgumentTable.setAddress(
      regionalStateBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 3
    )
    protectiveArgumentTable.setAddress(protectiveCommandUniformBuffer.gpuAddress, index: 4)
    protectiveArgumentTable.setAddress(
      protectiveCommandBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 5
    )
    encoder.setComputePipelineState(protectivePipeline)
    encoder.setArgumentTable(protectiveArgumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
    bodyLoadFieldArgumentTable.setAddress(bodyLoadFieldUniformBuffer.gpuAddress, index: 0)
    bodyLoadFieldArgumentTable.setAddress(bodyLoadFieldUpdateBuffer.gpuAddress, index: 1)
    bodyLoadFieldArgumentTable.setAddress(
      bodyLoadFieldStateBuffers[schedulerWindow.inputClockIndex].gpuAddress,
      index: 2
    )
    bodyLoadFieldArgumentTable.setAddress(
      bodyLoadFieldStateBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 3
    )
    encoder.setComputePipelineState(bodyLoadFieldPipeline)
    encoder.setArgumentTable(bodyLoadFieldArgumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
    fastCerebellarArgumentTable.setAddress(bodyLoadFieldUniformBuffer.gpuAddress, index: 0)
    fastCerebellarArgumentTable.setAddress(bodyLoadFieldUpdateBuffer.gpuAddress, index: 1)
    fastCerebellarArgumentTable.setAddress(stagedMotorCommandBuffer.gpuAddress, index: 2)
    fastCerebellarArgumentTable.setAddress(protectiveMotorProfileBuffer.gpuAddress, index: 3)
    fastCerebellarArgumentTable.setAddress(
      baselineFastCerebellarStateBuffer.gpuAddress,
      index: 4
    )
    fastCerebellarArgumentTable.setAddress(
      stagedFastCerebellarStateBuffer.gpuAddress,
      index: 5
    )
    fastCerebellarArgumentTable.setAddress(bodySchemaUniformBuffer.gpuAddress, index: 6)
    encoder.setComputePipelineState(fastCerebellarPipeline)
    encoder.setArgumentTable(fastCerebellarArgumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(
        width: protectiveMotorProfile.channels.count,
        height: 1,
        depth: 1
      ),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
    bodySchemaArgumentTable.setAddress(bodySchemaUniformBuffer.gpuAddress, index: 0)
    bodySchemaArgumentTable.setAddress(
      bodyLoadFieldStateBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 1
    )
    bodySchemaArgumentTable.setAddress(
      bodySchemaStateBuffers[schedulerWindow.inputClockIndex].gpuAddress,
      index: 2
    )
    bodySchemaArgumentTable.setAddress(
      bodySchemaStateBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 3
    )
    encoder.setComputePipelineState(bodySchemaPipeline)
    encoder.setArgumentTable(bodySchemaArgumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(
        width: max(Int(numanXMuscleAttachmentCatalog?.bodyCount ?? 0), 1),
        height: 1,
        depth: 1
      ),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
    protectiveMotorArgumentTable.setAddress(
      protectiveCommandBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 0
    )
    protectiveMotorArgumentTable.setAddress(protectiveMotorProfileBuffer.gpuAddress, index: 1)
    protectiveMotorArgumentTable.setAddress(protectiveCommandUniformBuffer.gpuAddress, index: 2)
    protectiveMotorArgumentTable.setAddress(
      protectiveMotorOutputHeaderBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 3
    )
    protectiveMotorArgumentTable.setAddress(
      protectiveMuscleExcitationBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 4
    )
    protectiveMotorArgumentTable.setAddress(
      protectiveSourceInhibitionMaskBuffer.gpuAddress,
      index: 5
    )
    protectiveMotorArgumentTable.setAddress(bodyLoadFieldUniformBuffer.gpuAddress, index: 6)
    protectiveMotorArgumentTable.setAddress(
      bodyLoadFieldStateBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 7
    )
    protectiveMotorArgumentTable.setAddress(muscleAttachmentBuffer.gpuAddress, index: 8)
    protectiveMotorArgumentTable.setAddress(
      bodySchemaStateBuffers[schedulerWindow.outputClockIndex].gpuAddress,
      index: 9
    )
    let descendingBuffer =
      descendingSomaticTransactionFingerprint
        == interactiveJointRoot?.transaction.token.fingerprint
      ? descendingSomaticBuffer
      : zeroDescendingSomaticBuffer
    protectiveMotorArgumentTable.setAddress(descendingBuffer.gpuAddress, index: 10)
    protectiveMotorArgumentTable.setAddress(fastCPGUniformBuffer.gpuAddress, index: 11)
    protectiveMotorArgumentTable.setAddress(stagedFastCPGStateBuffer.gpuAddress, index: 12)
    protectiveMotorArgumentTable.setAddress(
      transducedSchedulerEventBuffer.gpuAddress,
      index: 13
    )
    protectiveMotorArgumentTable.setAddress(
      receptorEventTransductionResultBuffer.gpuAddress,
      index: 14
    )
    protectiveMotorArgumentTable.setAddress(fastReflexRuleBuffer.gpuAddress, index: 15)
    protectiveMotorArgumentTable.setAddress(stagedFastReflexStateBuffer.gpuAddress, index: 16)
    protectiveMotorArgumentTable.setAddress(
      stagedFastCerebellarStateBuffer.gpuAddress,
      index: 17
    )
    protectiveMotorArgumentTable.setAddress(
      somaticActuatorDescriptorBuffer.gpuAddress,
      index: 18
    )
    encoder.setComputePipelineState(protectiveMotorPipeline)
    encoder.setArgumentTable(protectiveMotorArgumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
    fastAutonomicArgumentTable.setAddress(
      fastAutonomicUniformBuffer.gpuAddress,
      index: 0
    )
    fastAutonomicArgumentTable.setAddress(
      baselineFastAutonomicCommandBuffer.gpuAddress,
      index: 1
    )
    fastAutonomicArgumentTable.setAddress(
      transducedSchedulerEventBuffer.gpuAddress,
      index: 2
    )
    fastAutonomicArgumentTable.setAddress(
      receptorEventTransductionResultBuffer.gpuAddress,
      index: 3
    )
    fastAutonomicArgumentTable.setAddress(
      baselineFastAutonomicStateBuffer.gpuAddress,
      index: 4
    )
    fastAutonomicArgumentTable.setAddress(
      stagedFastAutonomicStateBuffer.gpuAddress,
      index: 5
    )
    fastAutonomicArgumentTable.setAddress(
      stagedFastAutonomicOutputBuffer.gpuAddress,
      index: 6
    )
    fastAutonomicArgumentTable.setAddress(
      stagedFastCPGStateBuffer.gpuAddress,
      index: 7
    )
    fastAutonomicArgumentTable.setAddress(
      fastAutonomicChannelDescriptorBuffer.gpuAddress,
      index: 8
    )
    encoder.setComputePipelineState(fastAutonomicPipeline)
    encoder.setArgumentTable(fastAutonomicArgumentTable)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(
        width: boundFastAutonomicChannelCount,
        height: 1,
        depth: 1
      ),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
  }

  private struct PreparedSchedulerWindow {
    let targetTime: BrainTimestamp
    let inputClockIndex: Int
    let outputClockIndex: Int
    let hostEventCount: Int
    let receptorEventCount: Int
    let cognitiveEventMaximumCount: Int
    let eventCount: Int
    let initialize: Bool
  }

  /// Translates receptor events already present in the committed cognitive
  /// observation at the root boundary. Physical time does not advance here;
  /// the translated queue only seeds immediate reflex, CPG, and autonomic
  /// overlays for the first physical candidate.
  private func writeCognitiveEventTransductionUniforms(
    timestamp: BrainTimestamp,
    maximumEventCount: Int
  ) {
    var uniforms = NBReceptorEventTransductionUniforms()
    uniforms.committed_time_microseconds = timestamp.rawValue
    uniforms.target_time_microseconds = timestamp.rawValue
    uniforms.receptor_event_count = 0
    uniforms.host_event_count = 0
    uniforms.event_capacity = UInt32(maxSchedulerEvents)
    uniforms.flags = 0
    uniforms.reserved_0 = UInt32(maximumEventCount)
    uniforms.reserved_1 = 0
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      receptorEventTransductionUniformBuffer.contents().copyMemory(
        from: source,
        byteCount: MemoryLayout<NBReceptorEventTransductionUniforms>.stride
      )
    }
  }

  private func prepareSchedulerWindow(
    startTime: BrainTimestamp,
    targetTime: BrainTimestamp,
    events: [BrainInterruptEvent]
  ) throws -> PreparedSchedulerWindow {
    if let committedSchedulerTime, startTime != committedSchedulerTime {
      throw TissueError.transaction(
        "root time does not match committed scheduler time \(committedSchedulerTime.rawValue) us"
      )
    }
    guard targetTime > startTime else {
      throw TissueError.transaction("scheduler target must advance physical time")
    }
    let duration = targetTime.rawValue - startTime.rawValue
    let targetMicroseconds = targetTime.rawValue
    let initialize = committedSchedulerTime == nil
    let canonicalEvents = events.sorted { lhs, rhs in
      if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
      if lhs.identifier != rhs.identifier { return lhs.identifier < rhs.identifier }
      if lhs.mask.rawValue != rhs.mask.rawValue {
        return lhs.mask.rawValue < rhs.mask.rawValue
      }
      if lhs.flags != rhs.flags { return lhs.flags < rhs.flags }
      if lhs.magnitude.bitPattern != rhs.magnitude.bitPattern {
        return lhs.magnitude.bitPattern < rhs.magnitude.bitPattern
      }
      return lhs.auxiliaryValue.bitPattern < rhs.auxiliaryValue.bitPattern
    }
    guard
      canonicalEvents.allSatisfy({
        $0.timestamp >= startTime && $0.timestamp <= targetTime
      })
    else {
      throw TissueError.transaction("scheduler event lies outside the root time window")
    }
    let receptorEvents = try eventSchedule.schedulerInterruptEvents(
      committedTime: startTime,
      targetTime: targetTime,
      includeCommittedBoundary: initialize
    )
    let cognitiveEventMaximumCount =
      stagedCognitiveEventTransactionFingerprint
        == interactiveJointRoot?.transaction.token.fingerprint
      ? stagedCognitiveEventMaximumCount
      : 0
    let totalEventCount = canonicalEvents.count + receptorEvents.count
      + cognitiveEventMaximumCount
    guard totalEventCount <= maxSchedulerEvents else {
      throw TissueError.transaction(
        "\(totalEventCount) host and receptor scheduler events exceed capacity \(maxSchedulerEvents)"
      )
    }

    var invocationUpperBound: UInt64 = 0
    for module in brainSchedule.modules {
      guard targetMicroseconds <= UInt64.max - UInt64(module.periodMicroseconds) else {
        throw TissueError.transaction("scheduler next-due time would overflow UInt64")
      }
      let periodic = duration / UInt64(module.periodMicroseconds) + 2
      let (next, overflow) = invocationUpperBound.addingReportingOverflow(periodic)
      guard !overflow else {
        throw TissueError.transaction("scheduler invocation bound overflows UInt64")
      }
      invocationUpperBound = next
    }
    let (interruptBound, interruptOverflow) = UInt64(totalEventCount)
      .multipliedReportingOverflow(by: UInt64(brainSchedule.modules.count))
    let (totalBound, totalOverflow) =
      invocationUpperBound
      .addingReportingOverflow(interruptBound)
    guard !interruptOverflow, !totalOverflow,
      totalBound <= UInt64(maxSchedulerInvocations)
    else {
      throw TissueError.transaction(
        "scheduler window may exceed invocation capacity \(maxSchedulerInvocations)"
      )
    }

    let eventRecords = canonicalEvents.map(\.abiRecord)
    eventRecords.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      schedulerEventUploadBuffer.contents().copyMemory(
        from: source,
        byteCount: bytes.count
      )
    }
    var transductionUniforms = NBReceptorEventTransductionUniforms()
    transductionUniforms.committed_time_microseconds = startTime.rawValue
    transductionUniforms.target_time_microseconds = targetTime.rawValue
    transductionUniforms.receptor_event_count = UInt32(eventSchedule.eventCount)
    transductionUniforms.host_event_count = UInt32(eventRecords.count)
    transductionUniforms.event_capacity = UInt32(maxSchedulerEvents)
    transductionUniforms.flags = initialize ? 1 : 0
    transductionUniforms.reserved_0 = UInt32(cognitiveEventMaximumCount)
    transductionUniforms.reserved_1 = 0
    withUnsafeBytes(of: &transductionUniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      receptorEventTransductionUniformBuffer.contents().copyMemory(
        from: source,
        byteCount: MemoryLayout<NBReceptorEventTransductionUniforms>.stride
      )
    }
    var uniforms = NBSchedulerUniforms()
    uniforms.committed_time_microseconds = startTime.rawValue
    uniforms.target_time_microseconds = targetTime.rawValue
    uniforms.parameter_version_fingerprint = parameterVersion.fingerprint
    uniforms.schedule_fingerprint = brainSchedule.fingerprint
    uniforms.module_count = UInt32(brainSchedule.modules.count)
    uniforms.event_count = UInt32(totalEventCount)
    uniforms.invocation_capacity = UInt32(maxSchedulerInvocations)
    uniforms.environment_identifier = schedulerEnvironmentIdentifier
    uniforms.flags = initialize ? 1 : 0
    uniforms.reserved = 0
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      schedulerUniformBuffer.contents().copyMemory(
        from: source,
        byteCount: MemoryLayout<NBSchedulerUniforms>.stride
      )
    }
    let (protectiveGeneration, protectiveGenerationOverflow) =
      committedSchedulerGeneration.addingReportingOverflow(1)
    guard !protectiveGenerationOverflow else {
      throw TissueError.transaction("protective command generation overflows UInt64")
    }
    writeProtectiveCommandUniforms(brainGeneration: protectiveGeneration)
    let outputClockIndex = 1 - committedSchedulerClockIndex
    return PreparedSchedulerWindow(
      targetTime: targetTime,
      inputClockIndex: committedSchedulerClockIndex,
      outputClockIndex: outputClockIndex,
      hostEventCount: canonicalEvents.count,
      receptorEventCount: receptorEvents.count,
      cognitiveEventMaximumCount: cognitiveEventMaximumCount,
      eventCount: totalEventCount,
      initialize: initialize
    )
  }

  private func schedulerTimestamp(milliseconds: Float) throws -> BrainTimestamp {
    guard milliseconds.isFinite, milliseconds >= 0 else {
      throw TissueError.transaction("scheduler time must be finite and nonnegative")
    }
    let scaled = Double(milliseconds) * 1_000
    let rounded = scaled.rounded()
    guard rounded < Double(UInt64.max), abs(scaled - rounded) <= 0.01 else {
      throw TissueError.transaction("scheduler time is not representable in integer microseconds")
    }
    return BrainTimestamp(microseconds: UInt64(rounded))
  }

  private func validateRelayHistoryCoverage(
    at timestamp: BrainTimestamp,
    timestamps: [UInt64]
  ) throws {
    guard timestamps.count == TissueDelayField.historyCapacity else {
      throw TissueError.transaction("relay-history timestamp shape is invalid")
    }
    let target =
      maximumTissueDelayMicroseconds >= timestamp.rawValue
      ? UInt64(0)
      : timestamp.rawValue - maximumTissueDelayMicroseconds
    guard timestamps.contains(where: { $0 <= target }) else {
      throw TissueError.transaction(
        "physical relay history no longer covers target timestamp \(target) us"
      )
    }
  }

  private func destinationIndex(rootShadowIndex: Int) -> Int {
    (0..<stateBuffers.count).first {
      $0 != committedIndex && $0 != rootShadowIndex
    }!
  }

  private func settingHistoryOwner(
    mask: UInt32,
    slot: Int,
    owner: UInt32
  ) -> UInt32 {
    let bit = UInt32(1) << UInt32(slot)
    return owner == 0 ? mask & ~bit : mask | bit
  }

  private func writeUniforms(_ values: [Float], attempt: Int) {
    let destination = uniformBuffer.contents()
      .advanced(by: attempt * TissueUniforms.byteCount)
    values.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      destination.copyMemory(from: source, byteCount: TissueUniforms.byteCount)
    }
  }

  private struct FeedbackSnapshot {
    let gpuStartTime: Double
    let gpuEndTime: Double
  }

  private func copy(
    source: any MTLBuffer,
    destination: any MTLBuffer,
    size: Int? = nil,
    label: String
  ) throws {
    let size = size ?? stateByteCount
    _ = try submit(label: label) { encoder in
      encoder.copy(
        sourceBuffer: source,
        sourceOffset: 0,
        destinationBuffer: destination,
        destinationOffset: 0,
        size: size
      )
    }
  }

  private func seedRelayHistory() throws {
    _ = try submit(label: "NumiBrain relay history seed") { encoder in
      for plane in 0..<2 {
        for slot in 0..<TissueDelayField.historyCapacity {
          encoder.copy(
            sourceBuffer: stagingBuffer,
            sourceOffset: 0,
            destinationBuffer: relayHistoryBuffer,
            destinationOffset: (plane * TissueDelayField.historyCapacity + slot)
              * relayByteCount,
            size: relayByteCount
          )
        }
      }
    }
  }

  private func submit(
    label: String,
    additionalResidencySet: (any MTLResidencySet)? = nil,
    encode: (any MTL4ComputeCommandEncoder) -> Void
  ) throws -> FeedbackSnapshot {
    commandAllocator.reset()
    commandBuffer.beginCommandBuffer(allocator: commandAllocator)
    commandBuffer.useResidencySet(residencySet)
    if let additionalResidencySet {
      commandBuffer.useResidencySet(additionalResidencySet)
    }
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
    final class FeedbackBox: @unchecked Sendable {
      var feedback: (any MTL4CommitFeedback)?
    }
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

  private func threadgroupSize() -> MTLSize {
    let width = min(16, tissuePipeline.threadExecutionWidth)
    let height = max(1, min(16, tissuePipeline.maxTotalThreadsPerThreadgroup / width))
    return MTLSize(width: width, height: height, depth: 1)
  }

  private func regionalThreadgroupSize() -> MTLSize {
    MTLSize(
      width: min(256, regionalPipeline.maxTotalThreadsPerThreadgroup),
      height: 1,
      depth: 1
    )
  }
}

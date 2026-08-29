import Foundation
@preconcurrency import Metal
import NumiBrainCore

private struct DecisionUniforms {
  var targetTimestampMicroseconds: UInt64 = 0
  var recurrentOffset: UInt64 = 0
  var workspaceOffset: UInt64 = 0
  var workspaceMetadataOffset: UInt64 = 0
  var worldModelOffset: UInt64 = 0
  var driveOffset: UInt64 = 0
  var neuromodulationOffset: UInt64 = 0
  var controlHeaderOffset: UInt64 = 0
  var candidateOffset: UInt64 = 0
  var planOffset: UInt64 = 0
  var motorOffset: UInt64 = 0
  var synergyOffset: UInt64 = 0
  var cerebellarOffset: UInt64 = 0
  var spinalOffset: UInt64 = 0
  var autonomicOffset: UInt64 = 0
  var somaticOutputOffset: UInt64 = 0
  var activeSensingOffset: UInt64 = 0
  var spatialTransformOffset: UInt64 = 0
  var objectSlotOffset: UInt64 = 0
  var internalActionOffset: UInt64 = 0
  var developmentalStateOffset: UInt64 = 0
  var cerebellarExpertMemoryOffset: UInt64 = 0
  var eventQueueOffset: UInt64 = 0
  var cpgStateOffset: UInt64 = 0
  var descendingSomaticBaselineOffset: UInt64 = 0
  var parameterVersionFingerprint: UInt64 = 0
  var reservedIdentity: UInt64 = 0
  var recurrentScalarCount: UInt32 = 0
  var workspaceScalarCount: UInt32 = 0
  var workspaceCapacity: UInt32 = 0
  var workspaceDimension: UInt32 = 0
  var worldModelScalarCount: UInt32 = 0
  var driveCount: UInt32 = 0
  var neuromodulatorCount: UInt32 = 0
  var candidateCapacity: UInt32 = 0
  var planCapacity: UInt32 = 0
  var actuatorCount: UInt32 = 0
  var synergyCount: UInt32 = 0
  var activeCerebellarExpertCount: UInt32 = 0
  var autonomicDimension: UInt32 = 0
  var activeSensingDimension: UInt32 = 0
  var communicationSynergyDescriptorOffset: UInt32 = 0
  var activeSensingDescriptorOffset: UInt32 = 0
  var communicationDescriptorCount: UInt32 = 0
  var spatialTransformCount: UInt32 = 0
  var objectSlotCount: UInt32 = 0
  var internalActionCapacity: UInt32 = 0
  var maximumPlanningHorizon: UInt32 = 0
  var cpgOscillatorCount: UInt32 = 0
  var cpgCouplingCount: UInt32 = 0
  var eventCapacity: UInt32 = 0
  var riskWeight: Float = 0
  var damageRiskBudget: Float = 0
  var switchingMargin: Float = 0
  var curiosityWeight: Float = 0
  var planningCostWeight: Float = 0
  var motorGain: Float = 0
  var stiffnessGain: Float = 0
  var dampingGain: Float = 0
  var observationOffset: UInt64 = 0
  var observationCount: UInt32 = 0
  var cerebellarExpertCapacity: UInt32 = 0
  var fastCerebellarStateOffset: UInt64 = 0
  var bodyBeliefOffset: UInt64 = 0
  var somaticEffectorBeliefOffset: UInt64 = 0
  var bodyBeliefCount: UInt32 = 0
  var somaticEffectorBeliefCount: UInt32 = 0
  var activeSensingEfficacyOffset: UInt64 = 0
  var actuatorCommandKind: UInt32 = 0
  var reservedMotorABI: UInt32 = 0
}

private struct CommunicationChannelDescriptor {
  var effectorKind: UInt32 = 0
  var localChannelIndex: UInt32 = 0
  var gain: Float = 0
  var flags: UInt32 = 0
}

private struct CPGOscillatorDescriptor {
  var identifier: UInt32 = 0
  var outputSynergyIdentifier: UInt32 = 0
  var naturalFrequencyHertz: Float = 0
  var dutyFactor: Float = 0
  var sensoryResetMask: UInt64 = 0
  var outputKind: UInt64 = 0
}

private struct CPGCouplingDescriptor {
  var sourceOscillatorIndex: UInt32 = 0
  var destinationOscillatorIndex: UInt32 = 0
  var phaseOffset: Float = 0
  var gain: Float = 0
}

private struct DecisionAutonomicChannelDescriptor {
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

private struct DecisionActiveSensingChannelDescriptor {
  var channelIdentifier: UInt32 = 0
  var modality: UInt32 = 0
  var modalityLocalIdentifier: UInt32 = 0
  var flags: UInt32 = 0
}

private struct ExternalGoalDirectiveRecord {
  var identifier: UInt64 = 0
  var deadlineTimestampMicroseconds: UInt64 = 0
  var createdTimestampMicroseconds: UInt64 = 0
  var flags: UInt64 = 0
  var priority: Float = 0
  var damageRiskBudget: Float = 0
  var persistence: Float = 0
  var reserved: Float = 0
  var target0: Float = 0
  var target1: Float = 0
  var target2: Float = 0
  var target3: Float = 0
  var target4: Float = 0
  var target5: Float = 0
  var target6: Float = 0
  var target7: Float = 0
  var target8: Float = 0
  var target9: Float = 0
  var target10: Float = 0
  var target11: Float = 0
  var target12: Float = 0
  var target13: Float = 0
  var target14: Float = 0
  var target15: Float = 0
  var success0: Float = 0
  var success1: Float = 0
  var success2: Float = 0
  var success3: Float = 0
  var success4: Float = 0
  var success5: Float = 0
  var success6: Float = 0
  var success7: Float = 0
  var success8: Float = 0
  var success9: Float = 0
  var success10: Float = 0
  var success11: Float = 0
  var success12: Float = 0
  var success13: Float = 0
  var success14: Float = 0
  var success15: Float = 0
  var failure0: Float = 0
  var failure1: Float = 0
  var failure2: Float = 0
  var failure3: Float = 0
  var failure4: Float = 0
  var failure5: Float = 0
  var failure6: Float = 0
  var failure7: Float = 0
  var failure8: Float = 0
  var failure9: Float = 0
  var failure10: Float = 0
  var failure11: Float = 0
  var failure12: Float = 0
  var failure13: Float = 0
  var failure14: Float = 0
  var failure15: Float = 0
}

@available(macOS 26.0, *)
public final class MetalDecisionRuntime: @unchecked Sendable {
  @frozen
  public struct OutputView: Equatable, Sendable {
    public let headerGPUAddress: UInt64
    public let motorCommandGPUAddress: UInt64
    public let motorCommandCount: Int
    public let spinalStateGPUAddress: UInt64
    public let somaticOutputGPUAddress: UInt64
    public let somaticOutputCount: Int
    public let autonomicCommandGPUAddress: UInt64
    public let autonomicCommandCount: Int
    public let activeSensingCommandGPUAddress: UInt64
    public let activeSensingCommandCount: Int
    public let internalActionGPUAddress: UInt64
    public let internalActionCount: Int
  }

  private let arena: MetalAgentStateArena
  private let species: SpeciesTemplate
  private let regionalProgram: RegionalTokenProgram
  private let parameterVersion: BrainParameterVersion
  private let dynamics: DecisionDynamics
  private let controlLayout: MetalActiveControlLayout
  private let goalPipeline: any MTLComputePipelineState
  private let workspaceActionPipeline: any MTLComputePipelineState
  private let proposalPipeline: any MTLComputePipelineState
  private let planningPipeline: any MTLComputePipelineState
  private let selectionPipeline: any MTLComputePipelineState
  private let internalActionPipeline: any MTLComputePipelineState
  private let cerebellarPipeline: any MTLComputePipelineState
  private let cpgPipeline: any MTLComputePipelineState
  private let motorPipeline: any MTLComputePipelineState
  private let cerebellarPredictionPipeline: any MTLComputePipelineState
  private let argumentTable: any MTL4ArgumentTable
  private let uniformBuffer: any MTLBuffer
  private let communicationDescriptorBuffer: any MTLBuffer
  private let cpgOscillatorDescriptorBuffer: any MTLBuffer
  private let cpgCouplingDescriptorBuffer: any MTLBuffer
  private let autonomicChannelDescriptorBuffer: any MTLBuffer
  private let activeSensingChannelDescriptorBuffer: any MTLBuffer
  private let externalGoalDirectiveBuffer: any MTLBuffer
  private let communicationSynergyDescriptorOffset: UInt32
  private let activeSensingDescriptorOffset: UInt32
  private let communicationDescriptorCount: UInt32
  private let valueParameterGPUAddress: UInt64
  private let policyParameterGPUAddress: UInt64
  private let worldParameterGPUAddress: UInt64
  private let motorParameterGPUAddress: UInt64
  private let cerebellarParameterGPUAddress: UInt64

  public init(
    device: any MTLDevice,
    arena: MetalAgentStateArena,
    species: SpeciesTemplate,
    regionalProgram: RegionalTokenProgram,
    parameterVersion: BrainParameterVersion,
    dynamics: DecisionDynamics,
    sharedParameters: MetalSharedParameterBank
  ) throws {
    guard MemoryLayout<DecisionUniforms>.stride == 408,
      MemoryLayout<CommunicationChannelDescriptor>.stride == 16,
      MemoryLayout<CPGOscillatorDescriptor>.stride == 32,
      MemoryLayout<CPGCouplingDescriptor>.stride == 16,
      MemoryLayout<DecisionAutonomicChannelDescriptor>.stride == 48,
      MemoryLayout<DecisionActiveSensingChannelDescriptor>.stride == 16,
      MemoryLayout<ExternalGoalDirectiveRecord>.stride == 240,
      arena.layout.speciesTemplateFingerprint == species.fingerprint,
      arena.layout.regionalProgramFingerprint == regionalProgram.fingerprint,
      parameterVersion.regionalProgramFingerprint == regionalProgram.fingerprint
    else {
      throw TissueError.metal("decision runtime ABI or immutable binding drift")
    }
    let controlLayout = try MetalActiveControlLayout(
      arenaLayout: arena.layout,
      species: species
    )
    let sourceURL =
      Bundle.module.url(
        forResource: "DecisionState",
        withExtension: "metal",
        subdirectory: "Shaders"
      ) ?? Bundle.module.url(forResource: "DecisionState", withExtension: "metal")
    guard let sourceURL else {
      throw TissueError.metal("DecisionState.metal is missing from package resources")
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
      throw TissueError.metal("decision-state Metal 4 compilation failed: \(error)")
    }
    let names = [
      "generate_active_goal_state", "apply_internal_workspace_write",
      "propose_dynamic_options",
      "simulate_candidate_option_outcomes",
      "select_option_and_control_mode", "generate_internal_action_state",
      "select_cerebellar_context_experts",
      "advance_cpg_state",
      "generate_motor_spinal_autonomic_state",
      "predict_delayed_cerebellar_consequences",
    ]
    let functions = try names.map { name -> any MTLFunction in
      guard let function = library.makeFunction(name: name) else {
        throw TissueError.metal("\(name) is missing from decision-state Metal")
      }
      return function
    }
    let pipelines: [any MTLComputePipelineState]
    do {
      pipelines = try functions.map { try device.makeComputePipelineState(function: $0) }
    } catch {
      throw TissueError.metal("decision-state pipeline creation failed: \(error)")
    }
    let descriptor = MTL4ArgumentTableDescriptor()
    descriptor.label = "NumiBrain decision-state arguments"
    descriptor.maxBufferBindCount = 13
    descriptor.initializeBindings = true
    let actuatorDescriptorCount = Int(species.motor.actuatorCount)
    let synergyDescriptorOffset = actuatorDescriptorCount
    let activeSensingDescriptorOffset = synergyDescriptorOffset
      + Int(species.motor.synergyCount)
    let communicationDescriptorCount = activeSensingDescriptorOffset
      + max(Int(species.motor.activeSensingActionDimension), 1)
    guard communicationDescriptorCount <= Int(UInt32.max) else {
      throw TissueError.metal("communication descriptor count exceeds UInt32")
    }
    var communicationDescriptors = [CommunicationChannelDescriptor](
      repeating: CommunicationChannelDescriptor(),
      count: communicationDescriptorCount
    )
    for effector in species.motor.communicationEffectors {
      for (localIndex, identifier) in effector.actuatorIdentifiers.enumerated() {
        communicationDescriptors[Int(identifier)] = CommunicationChannelDescriptor(
          effectorKind: UInt32(effector.kind.rawValue),
          localChannelIndex: UInt32(localIndex),
          gain: effector.gain,
          flags: 1
        )
      }
      for (localIndex, identifier) in effector.synergyIdentifiers.enumerated() {
        communicationDescriptors[synergyDescriptorOffset + Int(identifier)] =
          CommunicationChannelDescriptor(
            effectorKind: UInt32(effector.kind.rawValue),
            localChannelIndex: UInt32(localIndex),
            gain: effector.gain,
            flags: 1
          )
      }
      for (localIndex, identifier) in
          effector.activeSensingChannelIdentifiers.enumerated() {
        communicationDescriptors[activeSensingDescriptorOffset + Int(identifier)] =
          CommunicationChannelDescriptor(
            effectorKind: UInt32(effector.kind.rawValue),
            localChannelIndex: UInt32(localIndex),
            gain: effector.gain,
            flags: 1
          )
      }
    }
    let oscillatorIndices = Dictionary(
      uniqueKeysWithValues: species.cpg.oscillators.enumerated().map {
        ($0.element.identifier, $0.offset)
      }
    )
    var cpgOscillatorDescriptors = species.cpg.oscillators.map {
      CPGOscillatorDescriptor(
        identifier: UInt32($0.identifier),
        outputSynergyIdentifier: UInt32($0.outputSynergyIdentifier),
        naturalFrequencyHertz: $0.naturalFrequencyHertz,
        dutyFactor: $0.dutyFactor,
        sensoryResetMask: $0.sensoryResetMask.rawValue,
        outputKind: UInt64($0.outputKind.rawValue)
      )
    }
    if cpgOscillatorDescriptors.isEmpty {
      cpgOscillatorDescriptors = [CPGOscillatorDescriptor()]
    }
    var cpgCouplingDescriptors = try species.cpg.couplings.map { coupling in
      guard let source = oscillatorIndices[coupling.sourceOscillatorIdentifier],
        let destination = oscillatorIndices[coupling.destinationOscillatorIdentifier]
      else {
        throw TissueError.metal("CPG coupling references an absent oscillator")
      }
      return CPGCouplingDescriptor(
        sourceOscillatorIndex: UInt32(source),
        destinationOscillatorIndex: UInt32(destination),
        phaseOffset: coupling.phaseOffset,
        gain: coupling.gain
      )
    }
    if cpgCouplingDescriptors.isEmpty {
      cpgCouplingDescriptors = [CPGCouplingDescriptor()]
    }
    let autonomicChannelDescriptors = species.physiology.autonomicChannels.map {
      channel in
      let identifiers = channel.criticalReceptorIdentifiers
        + Array(repeating: 0, count: 4 - channel.criticalReceptorIdentifiers.count)
      return DecisionAutonomicChannelDescriptor(
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
    var activeSensingChannelDescriptors = species.activeSensingChannels.map {
      DecisionActiveSensingChannelDescriptor(
        channelIdentifier: UInt32($0.identifier),
        modality: UInt32($0.modality.rawValue),
        modalityLocalIdentifier: UInt32($0.modalityLocalIdentifier),
        flags: 1
      )
    }
    if activeSensingChannelDescriptors.isEmpty {
      activeSensingChannelDescriptors = [DecisionActiveSensingChannelDescriptor()]
    }
    guard let argumentTable = try? device.makeArgumentTable(descriptor: descriptor),
      let uniformBuffer = device.makeBuffer(
        length: MemoryLayout<DecisionUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let communicationDescriptorBuffer = device.makeBuffer(
        length: communicationDescriptors.count
          * MemoryLayout<CommunicationChannelDescriptor>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let cpgOscillatorDescriptorBuffer = device.makeBuffer(
        length: cpgOscillatorDescriptors.count
          * MemoryLayout<CPGOscillatorDescriptor>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let cpgCouplingDescriptorBuffer = device.makeBuffer(
        length: cpgCouplingDescriptors.count
          * MemoryLayout<CPGCouplingDescriptor>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let autonomicChannelDescriptorBuffer = device.makeBuffer(
        length: autonomicChannelDescriptors.count
          * MemoryLayout<DecisionAutonomicChannelDescriptor>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let activeSensingChannelDescriptorBuffer = device.makeBuffer(
        length: activeSensingChannelDescriptors.count
          * MemoryLayout<DecisionActiveSensingChannelDescriptor>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let externalGoalDirectiveBuffer = device.makeBuffer(
        length: MemoryLayout<ExternalGoalDirectiveRecord>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate decision-state bindings")
    }
    uniformBuffer.label = "NumiBrain decision-state uniforms"
    communicationDescriptorBuffer.label =
      "NumiBrain immutable embodied communication map"
    cpgOscillatorDescriptorBuffer.label =
      "NumiBrain immutable species CPG oscillators"
    cpgCouplingDescriptorBuffer.label =
      "NumiBrain immutable species CPG couplings"
    autonomicChannelDescriptorBuffer.label =
      "NumiBrain immutable decision autonomic channels"
    activeSensingChannelDescriptorBuffer.label =
      "NumiBrain immutable species active sensing channels"
    externalGoalDirectiveBuffer.label =
      "NumiBrain transactional external goal directive"
    communicationDescriptors.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      communicationDescriptorBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    cpgOscillatorDescriptors.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      cpgOscillatorDescriptorBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    cpgCouplingDescriptors.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      cpgCouplingDescriptorBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    autonomicChannelDescriptors.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      autonomicChannelDescriptorBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    activeSensingChannelDescriptors.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      activeSensingChannelDescriptorBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    self.arena = arena
    self.species = species
    self.regionalProgram = regionalProgram
    self.parameterVersion = parameterVersion
    self.dynamics = dynamics
    self.controlLayout = controlLayout
    self.goalPipeline = pipelines[0]
    self.workspaceActionPipeline = pipelines[1]
    self.proposalPipeline = pipelines[2]
    self.planningPipeline = pipelines[3]
    self.selectionPipeline = pipelines[4]
    self.internalActionPipeline = pipelines[5]
    self.cerebellarPipeline = pipelines[6]
    self.cpgPipeline = pipelines[7]
    self.motorPipeline = pipelines[8]
    self.cerebellarPredictionPipeline = pipelines[9]
    self.argumentTable = argumentTable
    self.uniformBuffer = uniformBuffer
    self.communicationDescriptorBuffer = communicationDescriptorBuffer
    self.cpgOscillatorDescriptorBuffer = cpgOscillatorDescriptorBuffer
    self.cpgCouplingDescriptorBuffer = cpgCouplingDescriptorBuffer
    self.autonomicChannelDescriptorBuffer = autonomicChannelDescriptorBuffer
    self.activeSensingChannelDescriptorBuffer =
      activeSensingChannelDescriptorBuffer
    self.externalGoalDirectiveBuffer = externalGoalDirectiveBuffer
    self.communicationSynergyDescriptorOffset = UInt32(synergyDescriptorOffset)
    self.activeSensingDescriptorOffset = UInt32(activeSensingDescriptorOffset)
    self.communicationDescriptorCount = UInt32(communicationDescriptorCount)
    self.valueParameterGPUAddress = try sharedParameters.gpuAddress(
      .value, minimumScalarCount: 8
    )
    self.policyParameterGPUAddress = try sharedParameters.gpuAddress(
      .policy, minimumScalarCount: 16
    )
    self.worldParameterGPUAddress = try sharedParameters.gpuAddress(
      .world, minimumScalarCount: 190
    )
    self.motorParameterGPUAddress = try sharedParameters.gpuAddress(
      .motor, minimumScalarCount: 16
    )
    self.cerebellarParameterGPUAddress = try sharedParameters.gpuAddress(
      .cerebellar, minimumScalarCount: 8
    )
  }

  public var residencyAllocations: [any MTLAllocation] {
    [
      uniformBuffer, communicationDescriptorBuffer,
      cpgOscillatorDescriptorBuffer, cpgCouplingDescriptorBuffer,
      autonomicChannelDescriptorBuffer, activeSensingChannelDescriptorBuffer,
      externalGoalDirectiveBuffer,
    ]
  }

  public func encode(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    timestamp: BrainTimestamp,
    externalGoal: ActiveGoal? = nil
  ) throws -> OutputView {
    let hot = try arena.hotStateView(transaction: transaction)
    var uniforms = try makeUniforms(timestamp: timestamp)
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      uniformBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    var externalDirective = ExternalGoalDirectiveRecord()
    if let externalGoal {
      guard externalGoal.origin == .externalTask,
        externalGoal.identifier <= 0x007f_ffff_ffff_ffff,
        externalGoal.createdTimestamp <= timestamp,
        externalGoal.deadline == nil || externalGoal.deadline! >= timestamp,
        externalGoal.targetState.values.count <= 16,
        externalGoal.successModel.values.count <= 16,
        externalGoal.failureModel.values.count <= 16
      else {
        throw TissueError.transaction(
          "external goal directive is invalid at this control boundary"
        )
      }
      var target = externalGoal.targetState.values
      target.append(contentsOf: repeatElement(0, count: 16 - target.count))
      var success = externalGoal.successModel.values
      success.append(contentsOf: repeatElement(0, count: 16 - success.count))
      var failure = externalGoal.failureModel.values
      failure.append(contentsOf: repeatElement(0, count: 16 - failure.count))
      externalDirective = ExternalGoalDirectiveRecord(
        identifier: externalGoal.identifier,
        deadlineTimestampMicroseconds: externalGoal.deadline?.rawValue ?? 0,
        createdTimestampMicroseconds: externalGoal.createdTimestamp.rawValue,
        flags: 1,
        priority: externalGoal.priority,
        damageRiskBudget: externalGoal.damageRiskBudget,
        persistence: externalGoal.persistence,
        reserved: 0,
        target0: target[0], target1: target[1], target2: target[2],
        target3: target[3], target4: target[4], target5: target[5],
        target6: target[6], target7: target[7], target8: target[8],
        target9: target[9], target10: target[10], target11: target[11],
        target12: target[12], target13: target[13], target14: target[14],
        target15: target[15],
        success0: success[0], success1: success[1], success2: success[2],
        success3: success[3], success4: success[4], success5: success[5],
        success6: success[6], success7: success[7], success8: success[8],
        success9: success[9], success10: success[10], success11: success[11],
        success12: success[12], success13: success[13],
        success14: success[14], success15: success[15],
        failure0: failure[0], failure1: failure[1], failure2: failure[2],
        failure3: failure[3], failure4: failure[4], failure5: failure[5],
        failure6: failure[6], failure7: failure[7], failure8: failure[8],
        failure9: failure[9], failure10: failure[10], failure11: failure[11],
        failure12: failure[12], failure13: failure[13],
        failure14: failure[14], failure15: failure[15]
      )
    }
    withUnsafeBytes(of: &externalDirective) { bytes in
      guard let source = bytes.baseAddress else { return }
      externalGoalDirectiveBuffer.contents().copyMemory(
        from: source, byteCount: bytes.count
      )
    }
    argumentTable.setAddress(hot.outputGPUAddress, index: 0)
    argumentTable.setAddress(uniformBuffer.gpuAddress, index: 1)
    argumentTable.setAddress(valueParameterGPUAddress, index: 2)
    argumentTable.setAddress(policyParameterGPUAddress, index: 3)
    argumentTable.setAddress(motorParameterGPUAddress, index: 4)
    argumentTable.setAddress(cerebellarParameterGPUAddress, index: 5)
    argumentTable.setAddress(communicationDescriptorBuffer.gpuAddress, index: 6)
    argumentTable.setAddress(cpgOscillatorDescriptorBuffer.gpuAddress, index: 7)
    argumentTable.setAddress(cpgCouplingDescriptorBuffer.gpuAddress, index: 8)
    argumentTable.setAddress(autonomicChannelDescriptorBuffer.gpuAddress, index: 9)
    argumentTable.setAddress(
      activeSensingChannelDescriptorBuffer.gpuAddress, index: 10
    )
    argumentTable.setAddress(worldParameterGPUAddress, index: 11)
    argumentTable.setAddress(externalGoalDirectiveBuffer.gpuAddress, index: 12)
    dispatch(encoder, pipeline: goalPipeline, count: 1)
    barrier(encoder)
    dispatch(encoder, pipeline: workspaceActionPipeline, count: 1)
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: proposalPipeline,
      count: Int(species.capacities.activeOptionCandidateCapacity)
    )
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: planningPipeline,
      count: Int(species.capacities.activeOptionCandidateCapacity)
    )
    barrier(encoder)
    dispatch(encoder, pipeline: selectionPipeline, count: 1)
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: internalActionPipeline,
      count: InternalActionKind.allCases.count
    )
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: cerebellarPipeline,
      count: 1
    )
    barrier(encoder)
    dispatch(encoder, pipeline: cpgPipeline, count: 1)
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: motorPipeline,
      count: max(
        Int(species.motor.actuatorCount),
        max(
          Int(species.motor.synergyCount),
          max(
            Int(species.physiology.autonomicActionDimension),
            Int(species.motor.activeSensingActionDimension)
          )
        )
      )
    )
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: cerebellarPredictionPipeline,
      count: Int(species.capacities.activeCerebellarExpertCapacity)
    )
    let header = controlLayout.section(.header)
    let motor = controlLayout.section(.motorCommands)
    let spinal = controlLayout.section(.spinalState)
    let somatic = arena.layout.section(.somaticOutput)
    let autonomic = controlLayout.section(.autonomicCommands)
    let activeSensing = controlLayout.section(.activeSensingCommands)
    let internalActions = controlLayout.section(.internalActions)
    return OutputView(
      headerGPUAddress: hot.outputGPUAddress + UInt64(header.byteOffset),
      motorCommandGPUAddress: hot.outputGPUAddress + UInt64(motor.byteOffset),
      motorCommandCount: motor.elementCount,
      spinalStateGPUAddress: hot.outputGPUAddress + UInt64(spinal.byteOffset),
      somaticOutputGPUAddress: hot.outputGPUAddress + UInt64(somatic.byteOffset),
      somaticOutputCount: somatic.elementCount,
      autonomicCommandGPUAddress: hot.outputGPUAddress + UInt64(autonomic.byteOffset),
      autonomicCommandCount: autonomic.elementCount,
      activeSensingCommandGPUAddress:
        hot.outputGPUAddress + UInt64(activeSensing.byteOffset),
      activeSensingCommandCount: Int(species.motor.activeSensingActionDimension),
      internalActionGPUAddress:
        hot.outputGPUAddress + UInt64(internalActions.byteOffset),
      internalActionCount: internalActions.elementCount
    )
  }

  private func makeUniforms(timestamp: BrainTimestamp) throws -> DecisionUniforms {
    let recurrent = arena.layout.section(.regionalRecurrent)
    let workspace = arena.layout.section(.workspaceContent)
    let workspaceMetadata = arena.layout.section(.workspaceMetadata)
    let world = arena.layout.section(.worldModel)
    let observations = arena.layout.section(.sensoryObservations)
    let drives = arena.layout.section(.drives)
    let neuromodulation = arena.layout.section(.neuromodulation)
    let header = controlLayout.section(.header)
    let candidates = controlLayout.section(.optionCandidates)
    let plans = controlLayout.section(.planSteps)
    let motor = controlLayout.section(.motorCommands)
    let synergies = controlLayout.section(.synergyCoefficients)
    let cerebellar = controlLayout.section(.cerebellarExperts)
    let spinal = controlLayout.section(.spinalState)
    let somatic = arena.layout.section(.somaticOutput)
    let autonomic = controlLayout.section(.autonomicCommands)
    let activeSensing = controlLayout.section(.activeSensingCommands)
    let internalActions = controlLayout.section(.internalActions)
    let maximumPlanningHorizon = max(
      species.development.map({ Int($0.planningHorizonSteps) }).max() ?? 0,
      1
    )
    let counts = [
      recurrent.elementCount, workspace.elementCount, world.elementCount,
      workspaceMetadata.elementCount, candidates.elementCount, plans.elementCount,
      observations.elementCount,
    ]
    guard counts.allSatisfy({ $0 <= Int(UInt32.max) }),
      plans.elementCount == candidates.elementCount * maximumPlanningHorizon
    else {
      throw TissueError.metal("decision-state count exceeds UInt32")
    }
    return DecisionUniforms(
      targetTimestampMicroseconds: timestamp.rawValue,
      recurrentOffset: UInt64(recurrent.byteOffset),
      workspaceOffset: UInt64(workspace.byteOffset),
      workspaceMetadataOffset: UInt64(workspaceMetadata.byteOffset),
      worldModelOffset: UInt64(world.byteOffset),
      driveOffset: UInt64(drives.byteOffset),
      neuromodulationOffset: UInt64(neuromodulation.byteOffset),
      controlHeaderOffset: UInt64(header.byteOffset),
      candidateOffset: UInt64(candidates.byteOffset),
      planOffset: UInt64(plans.byteOffset),
      motorOffset: UInt64(motor.byteOffset),
      synergyOffset: UInt64(synergies.byteOffset),
      cerebellarOffset: UInt64(cerebellar.byteOffset),
      spinalOffset: UInt64(spinal.byteOffset),
      autonomicOffset: UInt64(autonomic.byteOffset),
      somaticOutputOffset: UInt64(somatic.byteOffset),
      activeSensingOffset: UInt64(activeSensing.byteOffset),
      spatialTransformOffset: UInt64(
        arena.layout.section(.spatialTransforms).byteOffset
      ),
      objectSlotOffset: UInt64(
        arena.layout.section(.objectSlots).byteOffset
      ),
      internalActionOffset: UInt64(internalActions.byteOffset),
      developmentalStateOffset: UInt64(
        arena.layout.section(.developmentalState).byteOffset
      ),
      cerebellarExpertMemoryOffset: UInt64(
        arena.layout.section(.cerebellarExpertMemory).byteOffset
      ),
      eventQueueOffset: UInt64(arena.layout.section(.eventQueue).byteOffset),
      cpgStateOffset: UInt64(arena.layout.section(.cpgState).byteOffset),
      descendingSomaticBaselineOffset: UInt64(
        arena.layout.section(.descendingSomaticBaseline).byteOffset
      ),
      parameterVersionFingerprint: parameterVersion.fingerprint,
      reservedIdentity: species.fingerprint,
      recurrentScalarCount: UInt32(recurrent.elementCount),
      workspaceScalarCount: UInt32(workspace.elementCount),
      workspaceCapacity: UInt32(workspaceMetadata.elementCount),
      workspaceDimension: UInt32(
        workspace.elementCount / workspaceMetadata.elementCount
      ),
      worldModelScalarCount: UInt32(world.elementCount),
      driveCount: UInt32(DriveKind.allCases.count),
      neuromodulatorCount: UInt32(NeuromodulatorKind.allCases.count),
      candidateCapacity: UInt32(candidates.elementCount),
      planCapacity: UInt32(plans.elementCount),
      actuatorCount: species.motor.actuatorCount,
      synergyCount: UInt32(species.motor.synergyCount),
      activeCerebellarExpertCount: UInt32(
        species.capacities.activeCerebellarExpertCapacity
      ),
      autonomicDimension: UInt32(species.physiology.autonomicActionDimension),
      activeSensingDimension: UInt32(species.motor.activeSensingActionDimension),
      communicationSynergyDescriptorOffset:
        communicationSynergyDescriptorOffset,
      activeSensingDescriptorOffset: activeSensingDescriptorOffset,
      communicationDescriptorCount: communicationDescriptorCount,
      spatialTransformCount: UInt32(
        arena.layout.section(.spatialTransforms).elementCount
      ),
      objectSlotCount: UInt32(
        arena.layout.section(.objectSlots).elementCount
      ),
      internalActionCapacity: UInt32(internalActions.elementCount),
      maximumPlanningHorizon: UInt32(maximumPlanningHorizon),
      cpgOscillatorCount: UInt32(species.cpg.oscillators.count),
      cpgCouplingCount: UInt32(species.cpg.couplings.count),
      eventCapacity: UInt32(
        max(arena.layout.section(.eventQueue).elementCount - 1, 0)
      ),
      riskWeight: dynamics.riskWeight,
      damageRiskBudget: dynamics.damageRiskBudget,
      switchingMargin: dynamics.switchingMargin,
      curiosityWeight: dynamics.curiosityWeight,
      planningCostWeight: dynamics.planningCostWeight,
      motorGain: dynamics.motorGain,
      stiffnessGain: dynamics.stiffnessGain,
      dampingGain: dynamics.dampingGain,
      observationOffset: UInt64(observations.byteOffset),
      observationCount: UInt32(observations.elementCount),
      cerebellarExpertCapacity: UInt32(
        species.capacities.cerebellarExpertCapacity
      ),
      fastCerebellarStateOffset: UInt64(
        arena.layout.section(.fastCerebellarState).byteOffset
      ),
      bodyBeliefOffset: UInt64(
        arena.layout.section(.bodyBelief).byteOffset
      ),
      somaticEffectorBeliefOffset: UInt64(
        arena.layout.section(.muscleBelief).byteOffset
      ),
      bodyBeliefCount: UInt32(
        arena.layout.section(.bodyBelief).elementCount
      ),
      somaticEffectorBeliefCount: UInt32(
        arena.layout.section(.muscleBelief).elementCount
      ),
      activeSensingEfficacyOffset: UInt64(
        arena.layout.section(.activeSensingEfficacy).byteOffset
      ),
      actuatorCommandKind: UInt32(species.motor.actuatorCommandKind.rawValue),
      reservedMotorABI: 0
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
      threadsPerGrid: MTLSize(width: count, height: 1, depth: 1),
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

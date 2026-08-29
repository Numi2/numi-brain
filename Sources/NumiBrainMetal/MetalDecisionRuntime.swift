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
  var internalActionOffset: UInt64 = 0
  var developmentalStateOffset: UInt64 = 0
  var cerebellarExpertMemoryOffset: UInt64 = 0
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
  var internalActionCapacity: UInt32 = 0
  var maximumPlanningHorizon: UInt32 = 0
  var riskWeight: Float = 0
  var damageRiskBudget: Float = 0
  var switchingMargin: Float = 0
  var curiosityWeight: Float = 0
  var planningCostWeight: Float = 0
  var motorGain: Float = 0
  var stiffnessGain: Float = 0
  var dampingGain: Float = 0
}

private struct CommunicationChannelDescriptor {
  var effectorKind: UInt32 = 0
  var localChannelIndex: UInt32 = 0
  var gain: Float = 0
  var flags: UInt32 = 0
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
  private let proposalPipeline: any MTLComputePipelineState
  private let planningPipeline: any MTLComputePipelineState
  private let selectionPipeline: any MTLComputePipelineState
  private let internalActionPipeline: any MTLComputePipelineState
  private let cerebellarPipeline: any MTLComputePipelineState
  private let motorPipeline: any MTLComputePipelineState
  private let argumentTable: any MTL4ArgumentTable
  private let uniformBuffer: any MTLBuffer
  private let communicationDescriptorBuffer: any MTLBuffer
  private let communicationSynergyDescriptorOffset: UInt32
  private let activeSensingDescriptorOffset: UInt32
  private let communicationDescriptorCount: UInt32
  private let valueParameterGPUAddress: UInt64
  private let policyParameterGPUAddress: UInt64
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
    guard MemoryLayout<DecisionUniforms>.stride == 296,
      MemoryLayout<CommunicationChannelDescriptor>.stride == 16,
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
      "generate_active_goal_state", "propose_dynamic_options",
      "simulate_candidate_option_outcomes",
      "select_option_and_control_mode", "generate_internal_action_state",
      "select_cerebellar_context_experts",
      "generate_motor_spinal_autonomic_state",
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
    descriptor.maxBufferBindCount = 7
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
    guard let argumentTable = try? device.makeArgumentTable(descriptor: descriptor),
      let uniformBuffer = device.makeBuffer(
        length: MemoryLayout<DecisionUniforms>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ),
      let communicationDescriptorBuffer = device.makeBuffer(
        length: communicationDescriptors.count
          * MemoryLayout<CommunicationChannelDescriptor>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      )
    else {
      throw TissueError.metal("failed to allocate decision-state bindings")
    }
    uniformBuffer.label = "NumiBrain decision-state uniforms"
    communicationDescriptorBuffer.label =
      "NumiBrain immutable embodied communication map"
    communicationDescriptors.withUnsafeBytes { bytes in
      guard let source = bytes.baseAddress else { return }
      communicationDescriptorBuffer.contents().copyMemory(
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
    self.proposalPipeline = pipelines[1]
    self.planningPipeline = pipelines[2]
    self.selectionPipeline = pipelines[3]
    self.internalActionPipeline = pipelines[4]
    self.cerebellarPipeline = pipelines[5]
    self.motorPipeline = pipelines[6]
    self.argumentTable = argumentTable
    self.uniformBuffer = uniformBuffer
    self.communicationDescriptorBuffer = communicationDescriptorBuffer
    self.communicationSynergyDescriptorOffset = UInt32(synergyDescriptorOffset)
    self.activeSensingDescriptorOffset = UInt32(activeSensingDescriptorOffset)
    self.communicationDescriptorCount = UInt32(communicationDescriptorCount)
    self.valueParameterGPUAddress = try sharedParameters.gpuAddress(
      .value, minimumScalarCount: 8
    )
    self.policyParameterGPUAddress = try sharedParameters.gpuAddress(
      .policy, minimumScalarCount: 16
    )
    self.motorParameterGPUAddress = try sharedParameters.gpuAddress(
      .motor, minimumScalarCount: 16
    )
    self.cerebellarParameterGPUAddress = try sharedParameters.gpuAddress(
      .cerebellar, minimumScalarCount: 8
    )
  }

  public var residencyAllocations: [any MTLAllocation] {
    [uniformBuffer, communicationDescriptorBuffer]
  }

  public func encode(
    encoder: any MTL4ComputeCommandEncoder,
    transaction: MetalAgentStateTransactionToken,
    timestamp: BrainTimestamp
  ) throws -> OutputView {
    let hot = try arena.hotStateView(transaction: transaction)
    var uniforms = try makeUniforms(timestamp: timestamp)
    withUnsafeBytes(of: &uniforms) { bytes in
      guard let source = bytes.baseAddress else { return }
      uniformBuffer.contents().copyMemory(from: source, byteCount: bytes.count)
    }
    argumentTable.setAddress(hot.outputGPUAddress, index: 0)
    argumentTable.setAddress(uniformBuffer.gpuAddress, index: 1)
    argumentTable.setAddress(valueParameterGPUAddress, index: 2)
    argumentTable.setAddress(policyParameterGPUAddress, index: 3)
    argumentTable.setAddress(motorParameterGPUAddress, index: 4)
    argumentTable.setAddress(cerebellarParameterGPUAddress, index: 5)
    argumentTable.setAddress(communicationDescriptorBuffer.gpuAddress, index: 6)
    dispatch(encoder, pipeline: goalPipeline, count: 1)
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
    dispatch(encoder, pipeline: internalActionPipeline, count: 8)
    barrier(encoder)
    dispatch(
      encoder,
      pipeline: cerebellarPipeline,
      count: 1
    )
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
      internalActionOffset: UInt64(internalActions.byteOffset),
      developmentalStateOffset: UInt64(
        arena.layout.section(.developmentalState).byteOffset
      ),
      cerebellarExpertMemoryOffset: UInt64(
        arena.layout.section(.cerebellarExpertMemory).byteOffset
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
      internalActionCapacity: UInt32(internalActions.elementCount),
      maximumPlanningHorizon: UInt32(maximumPlanningHorizon),
      riskWeight: dynamics.riskWeight,
      damageRiskBudget: dynamics.damageRiskBudget,
      switchingMargin: dynamics.switchingMargin,
      curiosityWeight: dynamics.curiosityWeight,
      planningCostWeight: dynamics.planningCostWeight,
      motorGain: dynamics.motorGain,
      stiffnessGain: dynamics.stiffnessGain,
      dampingGain: dynamics.dampingGain
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

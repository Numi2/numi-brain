import Foundation
@preconcurrency import Metal
import NumiBrainCore

private struct MetalMuscleBalanceSourceRecord {
  var scalarIndex: UInt32 = 0
  var receptorIndex: UInt32 = 0
  var requiredValidity: UInt32 = 0
  var inputSlot: UInt32 = 0
  var referenceValue: Float = 0
  var scale: Float = 1
  var bias: Float = 0
  var padding: Float = 0
}

private struct MetalMuscleBalanceRouteRecord {
  var sourceIndex: UInt32 = 0
  var reserved: UInt32 = 0
  var gain: Float = 0
  var maximumCorrection: Float = 0
}

private struct MetalMuscleBalanceRangeRecord {
  var routeStart: UInt32 = 0
  var routeCount: UInt32 = 0
  var reserved0: UInt32 = 0
  var reserved1: UInt32 = 0
}

/// Stateless first execution increment for source-bound whole-body feedback.
/// Delayed and filtered source history is rejected until it can live in the
/// joint root's committed/rollback state rather than private controller state.
@available(macOS 26.0, *)
final class MetalMuscleBalanceController: @unchecked Sendable {
  let program: MuscleBalanceFeedbackProgram

  private let topologyByModality: [SensoryModality: SensoryTopology]
  private let requiredModalities: Set<SensoryModality>
  private let sourceCount: Int
  private let muscleCount: Int
  private let routeCount: Int
  private let sources: any MTLBuffer
  private let routes: any MTLBuffer
  private let ranges: any MTLBuffer
  private let sourceErrors: any MTLBuffer
  private let sourceValidity: any MTLBuffer
  private let corrections: any MTLBuffer
  private let uniforms: any MTLBuffer
  private let dummySensor: any MTLBuffer
  private let dummyValidity: any MTLBuffer
  private let sourcePipeline: any MTLComputePipelineState
  private let routePipeline: any MTLComputePipelineState
  private let sourceArguments: any MTL4ArgumentTable
  private let routeArguments: any MTL4ArgumentTable

  init(
    program: MuscleBalanceFeedbackProgram,
    locomotorProgram: MuscleLocomotorProgram,
    template: CompiledSpeciesTemplate,
    library: any MTLLibrary,
    device: any MTLDevice
  ) throws {
    try program.validate(
      template: template,
      locomotorProgram: locomotorProgram
    )
    guard program.sources.allSatisfy({
      $0.filterTimeConstantSeconds == 0
        && $0.conductionDelayMicroseconds == 0
    }) else {
      throw TissueError.metal(
        "balance feedback delay/filter history requires committed root-state integration"
      )
    }
    guard MemoryLayout<MetalMuscleBalanceSourceRecord>.stride == 32,
      MemoryLayout<MetalMuscleBalanceRouteRecord>.stride == 16,
      MemoryLayout<MetalMuscleBalanceRangeRecord>.stride == 16
    else {
      throw TissueError.metal("muscle balance Metal ABI drift")
    }

    let topologyByModality = Dictionary(
      uniqueKeysWithValues: template.species.senses
        .filter(\.enabled).map { ($0.modality, $0) }
    )
    let bindings = Dictionary(
      uniqueKeysWithValues: template.sensoryProfile.bodyReceptorBindings.map {
        ($0.identifier, $0)
      }
    )
    let orderedSources = program.sources.sorted { $0.identifier < $1.identifier }
    let sourceIndexByIdentifier = Dictionary(
      uniqueKeysWithValues: orderedSources.enumerated().map {
        ($0.element.identifier, UInt32($0.offset))
      }
    )
    var sourceRecords: [MetalMuscleBalanceSourceRecord] = []
    sourceRecords.reserveCapacity(orderedSources.count)
    var requiredModalities = Set<SensoryModality>()
    for source in orderedSources {
      guard let binding = bindings[source.bodyReceptorBindingIdentifier],
        let topology = topologyByModality[binding.modality],
        binding.featureIndex < 32, binding.scale != 0, binding.weight == 1,
        binding.modality == .vestibular || binding.modality == .touch
      else {
        throw TissueError.metal(
          "balance feedback runtime currently supports physical vestibular and touch bindings"
        )
      }
      let scalarIndex64 = UInt64(binding.receptorIndex)
        * UInt64(topology.observationDimension)
        + UInt64(binding.featureIndex)
      guard scalarIndex64 <= UInt64(UInt32.max) else {
        throw TissueError.metal("balance feedback source exceeds Metal indexing")
      }
      requiredModalities.insert(binding.modality)
      sourceRecords.append(
        MetalMuscleBalanceSourceRecord(
          scalarIndex: UInt32(scalarIndex64),
          receptorIndex: binding.receptorIndex,
          requiredValidity: UInt32(1) << binding.featureIndex,
          inputSlot: binding.modality == .vestibular ? 0 : 1,
          referenceValue: source.referenceValue,
          scale: binding.scale,
          bias: binding.bias,
          padding: 0
        )
      )
    }

    let orderedRoutes = program.routes.sorted {
      ($0.muscleIdentifier, $0.sourceIdentifier)
        < ($1.muscleIdentifier, $1.sourceIdentifier)
    }
    var routeRecords: [MetalMuscleBalanceRouteRecord] = []
    routeRecords.reserveCapacity(orderedRoutes.count)
    var rangeRecords = [MetalMuscleBalanceRangeRecord](
      repeating: MetalMuscleBalanceRangeRecord(),
      count: locomotorProgram.channels.count
    )
    var cursor = 0
    for muscle in 0..<locomotorProgram.channels.count {
      let start = cursor
      while cursor < orderedRoutes.count,
        orderedRoutes[cursor].muscleIdentifier == UInt32(muscle)
      {
        let route = orderedRoutes[cursor]
        guard let sourceIndex = sourceIndexByIdentifier[route.sourceIdentifier]
        else {
          throw TissueError.metal("balance route source identity drift")
        }
        routeRecords.append(
          MetalMuscleBalanceRouteRecord(
            sourceIndex: sourceIndex,
            reserved: 0,
            gain: route.gain,
            maximumCorrection: route.maximumCorrection
          )
        )
        cursor += 1
      }
      rangeRecords[muscle] = MetalMuscleBalanceRangeRecord(
        routeStart: UInt32(start),
        routeCount: UInt32(cursor - start),
        reserved0: 0,
        reserved1: 0
      )
    }
    guard cursor == orderedRoutes.count,
      sourceRecords.count <= Int(UInt32.max),
      routeRecords.count <= Int(UInt32.max),
      rangeRecords.count <= Int(UInt32.max)
    else {
      throw TissueError.metal("balance feedback sparse route compilation failed")
    }

    func upload<T>(_ values: [T], label: String) throws -> any MTLBuffer {
      guard !values.isEmpty,
        let buffer = values.withUnsafeBytes({ bytes in
          device.makeBuffer(
            bytes: bytes.baseAddress!,
            length: bytes.count,
            options: [.storageModeShared, .hazardTrackingModeTracked]
          )
        })
      else {
        throw TissueError.metal("\(label) allocation failed")
      }
      buffer.label = label
      return buffer
    }
    func allocate(length: Int, label: String) throws -> any MTLBuffer {
      guard length > 0,
        let buffer = device.makeBuffer(
          length: length,
          options: [.storageModeShared, .hazardTrackingModeTracked]
        )
      else {
        throw TissueError.metal("\(label) allocation failed")
      }
      buffer.label = label
      return buffer
    }

    let sources = try upload(
      sourceRecords,
      label: "NumiBrain muscle balance sources"
    )
    let routes = try upload(
      routeRecords,
      label: "NumiBrain muscle balance routes"
    )
    let ranges = try upload(
      rangeRecords,
      label: "NumiBrain muscle balance ranges"
    )
    let sourceErrors = try allocate(
      length: sourceRecords.count * MemoryLayout<Float>.stride,
      label: "NumiBrain muscle balance source errors"
    )
    let sourceValidity = try allocate(
      length: sourceRecords.count * MemoryLayout<UInt32>.stride,
      label: "NumiBrain muscle balance source validity"
    )
    let corrections = try allocate(
      length: rangeRecords.count * MemoryLayout<Float>.stride,
      label: "NumiBrain muscle balance corrections"
    )
    let uniforms = try allocate(
      length: MemoryLayout<UInt32>.stride * 4,
      label: "NumiBrain muscle balance uniforms"
    )
    let dummySensor = try allocate(
      length: MemoryLayout<Float>.stride,
      label: "NumiBrain unused muscle balance sensor"
    )
    let dummyValidity = try allocate(
      length: MemoryLayout<UInt32>.stride,
      label: "NumiBrain unused muscle balance validity"
    )
    dummySensor.contents().storeBytes(of: Float(0), as: Float.self)
    dummyValidity.contents().storeBytes(of: UInt32(0), as: UInt32.self)

    guard let sourceFunction = library.makeFunction(
      name: "nb_muscle_balance_sources"
    ), let routeFunction = library.makeFunction(
      name: "nb_muscle_balance_routes"
    ) else {
      throw TissueError.metal("muscle balance kernels are missing")
    }
    let sourcePipeline = try device.makeComputePipelineState(
      function: sourceFunction
    )
    let routePipeline = try device.makeComputePipelineState(
      function: routeFunction
    )
    let sourceDescriptor = MTL4ArgumentTableDescriptor()
    sourceDescriptor.label = "NumiBrain muscle balance source arguments"
    sourceDescriptor.maxBufferBindCount = 8
    sourceDescriptor.initializeBindings = true
    let routeDescriptor = MTL4ArgumentTableDescriptor()
    routeDescriptor.label = "NumiBrain muscle balance route arguments"
    routeDescriptor.maxBufferBindCount = 6
    routeDescriptor.initializeBindings = true
    let sourceArguments = try device.makeArgumentTable(
      descriptor: sourceDescriptor
    )
    let routeArguments = try device.makeArgumentTable(
      descriptor: routeDescriptor
    )
    for (index, address) in [
      sources.gpuAddress, sourceErrors.gpuAddress,
      sourceValidity.gpuAddress, uniforms.gpuAddress,
    ].enumerated() {
      sourceArguments.setAddress(address, index: index + 4)
    }
    for (index, address) in [
      sourceErrors.gpuAddress, sourceValidity.gpuAddress,
      routes.gpuAddress, ranges.gpuAddress, corrections.gpuAddress,
      uniforms.gpuAddress,
    ].enumerated() {
      routeArguments.setAddress(address, index: index)
    }

    self.program = program
    self.topologyByModality = topologyByModality
    self.requiredModalities = requiredModalities
    self.sourceCount = sourceRecords.count
    self.muscleCount = rangeRecords.count
    self.routeCount = routeRecords.count
    self.sources = sources
    self.routes = routes
    self.ranges = ranges
    self.sourceErrors = sourceErrors
    self.sourceValidity = sourceValidity
    self.corrections = corrections
    self.uniforms = uniforms
    self.dummySensor = dummySensor
    self.dummyValidity = dummyValidity
    self.sourcePipeline = sourcePipeline
    self.routePipeline = routePipeline
    self.sourceArguments = sourceArguments
    self.routeArguments = routeArguments
  }

  var residencyAllocations: [any MTLAllocation] {
    [
      sources, routes, ranges, sourceErrors, sourceValidity, corrections,
      uniforms, dummySensor, dummyValidity,
    ]
  }

  func encode(
    root: BrainJointTransactionToken,
    locomotorEpochMicroseconds: UInt64,
    encoder: any MTL4ComputeCommandEncoder,
    rawSensors: [MetalRawSensorBufferView]
  ) throws -> any MTLBuffer {
    guard root.committedTimestamp.rawValue >= locomotorEpochMicroseconds else {
      throw TissueError.transaction(
        "balance feedback precedes its locomotor epoch"
      )
    }
    let elapsed = root.committedTimestamp.rawValue - locomotorEpochMicroseconds
    let initialization = UInt64(program.initializationDurationMicroseconds)
    let feedbackEnabled = elapsed >= initialization
    if feedbackEnabled {
      let activeElapsed = elapsed - initialization
      guard activeElapsed % UInt64(program.updatePeriodMicroseconds) == 0 else {
        throw TissueError.transaction(
          "balance feedback root is not aligned to its physical update clock"
        )
      }
    }

    var viewByModality: [SensoryModality: MetalRawSensorBufferView] = [:]
    for view in rawSensors where requiredModalities.contains(view.modality) {
      guard viewByModality.updateValue(view, forKey: view.modality) == nil
      else {
        throw TissueError.transaction(
          "balance feedback received duplicate physical sensor packets"
        )
      }
    }
    for modality in requiredModalities {
      try MetalMuscleBalanceSensorAdmission.validate(
        view: viewByModality[modality],
        topology: topologyByModality[modality],
        committedTimestamp: root.committedTimestamp
      )
    }

    let vestibular = viewByModality[.vestibular]
    let touch = viewByModality[.touch]
    for (index, address) in [
      vestibular?.gpuAddress ?? dummySensor.gpuAddress,
      vestibular?.validityGPUAddress ?? dummyValidity.gpuAddress,
      touch?.gpuAddress ?? dummySensor.gpuAddress,
      touch?.validityGPUAddress ?? dummyValidity.gpuAddress,
    ].enumerated() {
      sourceArguments.setAddress(address, index: index)
    }
    let words = [
      UInt32(sourceCount), UInt32(muscleCount),
      feedbackEnabled ? UInt32(1) : UInt32(0), UInt32(routeCount),
    ]
    words.withUnsafeBytes { bytes in
      uniforms.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }

    encoder.setComputePipelineState(sourcePipeline)
    encoder.setArgumentTable(sourceArguments)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: sourceCount, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(
        width: sourcePipeline.threadExecutionWidth, height: 1, depth: 1
      )
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
    encoder.setComputePipelineState(routePipeline)
    encoder.setArgumentTable(routeArguments)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: muscleCount, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(
        width: routePipeline.threadExecutionWidth, height: 1, depth: 1
      )
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )
    return corrections
  }
}

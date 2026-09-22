import Foundation
@preconcurrency import Metal
import NumiBrainCore

private struct MetalMuscleBalanceHistorySourceRecord {
  var delayMicroseconds: UInt32 = 0
  var filterTimeConstantSeconds: Float = 0
  var reserved0: UInt32 = 0
  var reserved1: UInt32 = 0
}

private struct MetalMuscleBalanceHistoryUniforms {
  var sampleTimestampMicroseconds: UInt64 = 0
  var sourceCount: UInt32 = 0
  var historyCapacity: UInt32 = 0
  var writeIndex: UInt32 = 0
  var correctionEnabled: UInt32 = 0
  var reserved0: UInt32 = 0
  var reserved1: UInt32 = 0
}

/// Transactional delayed/filter state for the source-bound muscle-balance
/// controller. All numerical state remains GPU resident. A root writes a full
/// unpublished shadow image and publication is only an index swap after the
/// owning joint transaction validates its physical commit receipt.
@available(macOS 26.0, *)
final class MetalMuscleBalanceHistoryRuntime: @unchecked Sendable {
  struct OutputView: Sendable {
    let transactionFingerprint: UInt64
    let errorGPUAddress: UInt64
    let validityGPUAddress: UInt64
    let sourceCount: Int
  }

  final class Candidate: @unchecked Sendable {
    let owner: MetalMuscleBalanceHistoryRuntime
    let root: BrainJointTransactionToken
    let stateIndex: Int
    let view: OutputView

    fileprivate init(
      owner: MetalMuscleBalanceHistoryRuntime,
      root: BrainJointTransactionToken,
      stateIndex: Int
    ) {
      self.owner = owner
      self.root = root
      self.stateIndex = stateIndex
      view = OutputView(
        transactionFingerprint: root.fingerprint,
        errorGPUAddress: owner.outputErrors.gpuAddress,
        validityGPUAddress: owner.outputValidity.gpuAddress,
        sourceCount: owner.sourceCount
      )
    }

    var outputBuffers: [any MTLBuffer] { [owner.outputErrors, owner.outputValidity] }

    func validateCommit(_ receipt: BrainJointCommitToken) throws {
      guard receipt.transactionFingerprint == root.fingerprint,
        receipt.brainGeneration == root.shadowGeneration,
        receipt.committedTimestamp == root.targetTimestamp,
        receipt.parameterVersionFingerprint
          == owner.parameterVersionFingerprint
      else {
        throw TissueError.transaction(
          "muscle balance history candidate does not match joint commit"
        )
      }
      owner.lock.lock()
      defer { owner.lock.unlock() }
      guard owner.pendingRoot == root.fingerprint else {
        throw TissueError.transaction(
          "muscle balance history candidate is stale"
        )
      }
    }

    func publish() {
      owner.lock.lock()
      defer { owner.lock.unlock() }
      precondition(owner.pendingRoot == root.fingerprint)
      owner.committedIndex = stateIndex
      owner.generation = root.shadowGeneration
      owner.timestamp = root.targetTimestamp
      owner.pendingRoot = nil
    }

    func abort() {
      owner.lock.lock()
      defer { owner.lock.unlock() }
      if owner.pendingRoot == root.fingerprint {
        owner.pendingRoot = nil
      }
    }
  }

  private struct StateBuffers {
    let values: any MTLBuffer
    let timestamps: any MTLBuffer
    let validity: any MTLBuffer
    let filteredValues: any MTLBuffer
    let filteredTimestamps: any MTLBuffer
    let filteredValidity: any MTLBuffer

    var allocations: [any MTLAllocation] {
      [
        values, timestamps, validity, filteredValues,
        filteredTimestamps, filteredValidity,
      ]
    }
  }

  let sourceCount: Int
  let historyCapacity: Int
  let parameterVersionFingerprint: UInt64

  private let updatePeriodMicroseconds: UInt32
  private let epochMicroseconds: UInt64
  private let lock = NSLock()
  private var generation: UInt64 = 0
  private var timestamp = BrainTimestamp(microseconds: 0)
  private var committedIndex = 0
  private var pendingRoot: UInt64?
  private var originEstablished = false

  private let states: [StateBuffers]
  private let sourceConfiguration: any MTLBuffer
  private let outputErrors: any MTLBuffer
  private let outputValidity: any MTLBuffer
  private let uniforms: any MTLBuffer
  private let pipeline: any MTLComputePipelineState
  private let arguments: any MTL4ArgumentTable

  init(
    program: MuscleBalanceFeedbackProgram,
    locomotorEpochMicroseconds: UInt64,
    parameterVersionFingerprint: UInt64,
    initialGeneration: UInt64,
    library: any MTLLibrary,
    device: any MTLDevice
  ) throws {
    guard program.requiresTransactionalHistory,
      initialGeneration == 0,
      parameterVersionFingerprint > 0,
      MemoryLayout<MetalMuscleBalanceHistorySourceRecord>.stride == 16,
      MemoryLayout<MetalMuscleBalanceHistoryUniforms>.stride == 32,
      let historyFunction = library.makeFunction(
        name: "nb_muscle_balance_history"
      )
    else {
      throw TissueError.metal(
        "transactional muscle balance history construction is invalid"
      )
    }

    let orderedSources = program.sources.sorted { $0.identifier < $1.identifier }
    let sourceCount = orderedSources.count
    let capacity = Int(program.historyCapacity)
    guard sourceCount > 0, capacity > 0,
      sourceCount <= Int(UInt32.max), capacity <= Int(UInt32.max),
      device.maxThreadsPerThreadgroup.width > 0
    else {
      throw TissueError.metal(
        "transactional muscle balance history exceeds device bounds"
      )
    }

    func zero(length: Int, label: String) throws -> any MTLBuffer {
      guard length > 0, length <= device.maxBufferLength,
        let buffer = device.makeBuffer(
          length: length,
          options: [.storageModeShared, .hazardTrackingModeTracked]
        )
      else {
        throw TissueError.metal("\(label) allocation failed")
      }
      buffer.contents().initializeMemory(
        as: UInt8.self,
        repeating: 0,
        count: length
      )
      buffer.label = label
      return buffer
    }

    func upload<T>(_ values: [T], label: String) throws -> any MTLBuffer {
      guard !values.isEmpty else {
        throw TissueError.metal("\(label) cannot be empty")
      }
      let buffer = try zero(
        length: values.count * MemoryLayout<T>.stride,
        label: label
      )
      values.withUnsafeBytes { bytes in
        buffer.contents().copyMemory(
          from: bytes.baseAddress!,
          byteCount: bytes.count
        )
      }
      return buffer
    }

    let scalarCount = sourceCount * capacity
    func state(_ index: Int) throws -> StateBuffers {
      StateBuffers(
        values: try zero(
          length: scalarCount * MemoryLayout<Float>.stride,
          label: "NumiBrain muscle balance history \(index) values"
        ),
        timestamps: try zero(
          length: scalarCount * MemoryLayout<UInt64>.stride,
          label: "NumiBrain muscle balance history \(index) timestamps"
        ),
        validity: try zero(
          length: scalarCount * MemoryLayout<UInt32>.stride,
          label: "NumiBrain muscle balance history \(index) validity"
        ),
        filteredValues: try zero(
          length: sourceCount * MemoryLayout<Float>.stride,
          label: "NumiBrain muscle balance history \(index) filtered values"
        ),
        filteredTimestamps: try zero(
          length: sourceCount * MemoryLayout<UInt64>.stride,
          label: "NumiBrain muscle balance history \(index) filtered timestamps"
        ),
        filteredValidity: try zero(
          length: sourceCount * MemoryLayout<UInt32>.stride,
          label: "NumiBrain muscle balance history \(index) filtered validity"
        )
      )
    }

    states = try [state(0), state(1)]
    sourceConfiguration = try upload(
      orderedSources.map {
        MetalMuscleBalanceHistorySourceRecord(
          delayMicroseconds: $0.conductionDelayMicroseconds,
          filterTimeConstantSeconds: $0.filterTimeConstantSeconds,
          reserved0: 0,
          reserved1: 0
        )
      },
      label: "NumiBrain muscle balance history source configuration"
    )
    outputErrors = try zero(
      length: sourceCount * MemoryLayout<Float>.stride,
      label: "NumiBrain delayed filtered balance errors"
    )
    outputValidity = try zero(
      length: sourceCount * MemoryLayout<UInt32>.stride,
      label: "NumiBrain delayed filtered balance validity"
    )
    uniforms = try zero(
      length: MemoryLayout<MetalMuscleBalanceHistoryUniforms>.stride,
      label: "NumiBrain muscle balance history uniforms"
    )
    pipeline = try device.makeComputePipelineState(function: historyFunction)
    let descriptor = MTL4ArgumentTableDescriptor()
    descriptor.label = "NumiBrain muscle balance history arguments"
    descriptor.maxBufferBindCount = 18
    descriptor.initializeBindings = true
    arguments = try device.makeArgumentTable(descriptor: descriptor)

    self.sourceCount = sourceCount
    historyCapacity = capacity
    updatePeriodMicroseconds = program.updatePeriodMicroseconds
    epochMicroseconds = locomotorEpochMicroseconds
    self.parameterVersionFingerprint = parameterVersionFingerprint
    generation = initialGeneration
  }

  var residencyAllocations: [any MTLAllocation] {
    states.flatMap(\.allocations)
      + [sourceConfiguration, outputErrors, outputValidity, uniforms]
  }

  func encodeCandidate(
    root: BrainJointTransactionToken,
    correctionEnabled: Bool,
    observedErrors: any MTLBuffer,
    observedValidity: any MTLBuffer,
    encoder: MetalMuscleCommandEncoder
  ) throws -> Candidate {
    lock.lock()
    defer { lock.unlock() }

    guard pendingRoot == nil,
      root.parameterVersionFingerprint == parameterVersionFingerprint,
      root.baseBrainGeneration == generation,
      !originEstablished || root.committedTimestamp == timestamp,
      root.committedTimestamp.rawValue >= epochMicroseconds,
      root.targetTimestamp > root.committedTimestamp,
      observedErrors.length >= sourceCount * MemoryLayout<Float>.stride,
      observedValidity.length >= sourceCount * MemoryLayout<UInt32>.stride
    else {
      throw TissueError.transaction(
        "muscle balance history candidate does not match committed root state"
      )
    }

    let elapsed = root.committedTimestamp.rawValue - epochMicroseconds
    let update = UInt64(updatePeriodMicroseconds)
    let duration = root.targetTimestamp.rawValue
      - root.committedTimestamp.rawValue
    guard elapsed % update == 0, duration == update else {
      throw TissueError.transaction(
        "stateful balance requires exactly one history update per joint root"
      )
    }

    if !originEstablished {
      timestamp = root.committedTimestamp
      originEstablished = true
    }

    let destination = committedIndex == 0 ? 1 : 0
    let committed = states[committedIndex]
    let shadow = states[destination]
    let writeIndex = UInt32(
      (elapsed / update) % UInt64(historyCapacity)
    )
    var historyUniforms = MetalMuscleBalanceHistoryUniforms(
      sampleTimestampMicroseconds: root.committedTimestamp.rawValue,
      sourceCount: UInt32(sourceCount),
      historyCapacity: UInt32(historyCapacity),
      writeIndex: writeIndex,
      correctionEnabled: correctionEnabled ? 1 : 0,
      reserved0: 0,
      reserved1: 0
    )
    withUnsafeBytes(of: &historyUniforms) { bytes in
      uniforms.contents().copyMemory(
        from: bytes.baseAddress!,
        byteCount: bytes.count
      )
    }

    let buffers = [
      observedErrors, observedValidity, sourceConfiguration,
      committed.values, committed.timestamps, committed.validity,
      committed.filteredValues, committed.filteredTimestamps, committed.filteredValidity,
      shadow.values, shadow.timestamps, shadow.validity,
      shadow.filteredValues, shadow.filteredTimestamps, shadow.filteredValidity,
      outputErrors, outputValidity, uniforms,
    ]
    try encoder.dispatch(pipeline: pipeline, arguments: arguments,
      addresses: buffers.map(\.gpuAddress), ownedBuffers: buffers, count: sourceCount)
    pendingRoot = root.fingerprint
    return Candidate(owner: self, root: root, stateIndex: destination)
  }
}

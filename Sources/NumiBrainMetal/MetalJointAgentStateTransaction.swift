import Foundation
@preconcurrency import Metal
import NumiBrainCore

@available(macOS 26.0, *)
public final class MetalJointAgentStateTransaction: @unchecked Sendable {
  @frozen
  public enum Status: Equatable, Sendable {
    case open, gpuStateFinished, commitPrepared, committed, aborted
    case recoveryCapturePending, recoveryRestorePending, recoveryFailed
  }

  public let jointToken: BrainJointTransactionToken
  public let agentStateToken: MetalAgentStateTransactionToken
  public let cachedDecisionFingerprint: UInt64
  public let cachedRandomCounterGeneration: UInt64
  private var currentStatus: Status = .open
  private var acceptedPhysicsFingerprint: UInt64?
  public var status: Status { lock.withLock { currentStatus } }
  public var acceptedPhysicsTokenFingerprint: UInt64? { lock.withLock { acceptedPhysicsFingerprint } }

  private let runtime: MetalAgentStateRuntime
  private let lock = NSLock()
  private var preparedCommit: MetalAgentStateRuntime.PreparedCommit?
  private var preparedGPUStateFinish: MetalAgentStateRuntime.PreparedGPUStateFinish?
  private var acceptedFastMotorState: MetalTissueRuntime.AcceptedFastMotorStateLease?

  public init(jointToken: BrainJointTransactionToken, runtime: MetalAgentStateRuntime,
              cachedDecisionFingerprint: UInt64) throws {
    guard jointToken.parameterVersionFingerprint > 0, cachedDecisionFingerprint > 0,
      runtime.arena.committedGeneration == jointToken.baseBrainGeneration else {
      throw TissueError.transaction("joint brain-state transaction does not match committed generation")
    }
    let token = try runtime.beginShadow(expectedBaseGeneration: jointToken.baseBrainGeneration)
    guard token.shadowGeneration == jointToken.shadowGeneration else {
      try? runtime.abort(transaction: token)
      throw TissueError.transaction("joint and complete-state shadow generations diverged")
    }
    self.jointToken = jointToken; self.agentStateToken = token
    self.cachedDecisionFingerprint = cachedDecisionFingerprint
    self.cachedRandomCounterGeneration = jointToken.randomCounterGeneration
    self.runtime = runtime
  }

  public func hotStateView() throws -> MetalAgentStateArena.HotStateView {
    lock.lock(); defer { lock.unlock() }
    try require(.open)
    return try runtime.hotStateView(transaction: agentStateToken)
  }
  public func persistentMemoryView() throws -> MetalAgentStateArena.PersistentMemoryView {
    lock.lock(); defer { lock.unlock() }
    try require(.open)
    return try runtime.persistentMemoryView(transaction: agentStateToken)
  }
  func bindAcceptedFastMotorState(_ lease: MetalTissueRuntime.AcceptedFastMotorStateLease) throws {
    lock.lock(); defer { lock.unlock() }; try require(.open)
    guard lease.transactionFingerprint == jointToken.fingerprint,
      lease.acceptedTimestamp == jointToken.targetTimestamp, acceptedFastMotorState == nil else {
      throw TissueError.transaction("accepted fast state cannot be rebound to this cognitive root")
    }
    acceptedFastMotorState = lease
  }
  func borrowAcceptedFastMotorState() throws -> MetalTissueRuntime.AcceptedFastMotorStateLease? {
    lock.lock(); defer { lock.unlock() }; try require(.open)
    return acceptedFastMotorState
  }

  /// Validate unapplied memory mutations after the owning GPU work has completed.
  public func finishGPUState(acceptedPhysicsState: AcceptedPhysicsStateToken) throws {
    lock.lock(); defer { lock.unlock() }; try require(.open)
    guard acceptedPhysicsState.transactionFingerprint == jointToken.fingerprint,
      acceptedPhysicsState.environmentIdentifier == jointToken.environmentIdentifier,
      acceptedPhysicsState.acceptedTimestamp == jointToken.targetTimestamp,
      acceptedPhysicsState.physicsGeneration > jointToken.basePhysicsGeneration else {
      throw TissueError.transaction("accepted physical consequence does not complete this joint root")
    }
    try runtime.validateMemoryJournalAndFinish(transaction: agentStateToken)
    acceptedPhysicsFingerprint = acceptedPhysicsState.fingerprint
    currentStatus = .gpuStateFinished
  }

  func encodeProvisionalGPUStateFinish(encoder: any MTL4ComputeCommandEncoder,
    provisional: BrainProvisionalPhysicsAcceptance) throws {
    lock.lock(); defer { lock.unlock() }; try require(.open)
    let (generation, overflow) = jointToken.basePhysicsGeneration.addingReportingOverflow(1)
    guard preparedGPUStateFinish == nil,
      provisional.environmentIdentifier == jointToken.environmentIdentifier,
      provisional.transactionFingerprint == jointToken.fingerprint,
      provisional.acceptedTimestamp == jointToken.targetTimestamp,
      provisional.shadowGeneration == agentStateToken.shadowGeneration,
      !overflow, provisional.expectedPhysicsGeneration == generation,
      UInt32(exactly: jointToken.controlStepIdentifier) == provisional.controlStep else {
      throw TissueError.transaction("provisional cognitive finish does not match the joint root")
    }
    preparedGPUStateFinish = try runtime.encodeProvisionalMemoryJournalValidation(
      encoder: encoder, transaction: agentStateToken)
  }
  func finishProvisionalGPUState(acceptedPhysicsState: AcceptedPhysicsStateToken,
    provisional: BrainProvisionalPhysicsAcceptance) throws {
    lock.lock(); defer { lock.unlock() }; try require(.open)
    guard let preparedGPUStateFinish,
      provisional.transactionFingerprint == jointToken.fingerprint,
      acceptedPhysicsState.transactionFingerprint == jointToken.fingerprint,
      acceptedPhysicsState.substepFingerprint == provisional.substepFingerprint,
      acceptedPhysicsState.environmentIdentifier == provisional.environmentIdentifier,
      acceptedPhysicsState.acceptedTimestamp == provisional.acceptedTimestamp,
      acceptedPhysicsState.physicsGeneration == provisional.expectedPhysicsGeneration else {
      throw TissueError.transaction("owner-validated physical token does not match cognitive preflight")
    }
    runtime.publishProvisionalGPUStateFinish(preparedGPUStateFinish)
    self.preparedGPUStateFinish = nil
    acceptedPhysicsFingerprint = acceptedPhysicsState.fingerprint
    currentStatus = .gpuStateFinished
  }

  /// Captures base hot state, shadow hot state, base persistent memory and unapplied journal.
  /// The owning queue must commit commandBuffer with options. No publication/abort is permitted
  /// until its feedback handler completes. Persist the returned image BEFORE voting prepared.
  public func encodePreparedRecoveryCapture(device: any MTLDevice,
    commandBuffer: any MTL4CommandBuffer, options: MTL4CommitOptions,
    maximumBytes: Int = 536_870_912,
    completion: @escaping @Sendable (Result<BrainPreparedGPUImage, Error>) -> Void) throws {
    lock.lock(); defer { lock.unlock() }
    guard currentStatus == .gpuStateFinished || currentStatus == .commitPrepared,
      let physics = acceptedPhysicsFingerprint else {
      throw TissueError.transaction("prepared capture requires completed, unpublished native state")
    }
    let prior = currentStatus
    currentStatus = .recoveryCapturePending
    do {
      try MetalPreparedRecoveryTransfer.capture(runtime: runtime, transaction: agentStateToken,
        root: jointToken, decision: cachedDecisionFingerprint, acceptedPhysics: physics,
        device: device, commandBuffer: commandBuffer, options: options, maximumBytes: maximumBytes) { [self] result in
          lock.lock()
          switch result {
          case .success: currentStatus = prior
          case .failure: currentStatus = .recoveryFailed
          }
          lock.unlock()
          completion(result)
        }
    } catch { currentStatus = prior; throw error }
  }

  /// Restart path: restore the BASE using the existing native checkpoint engine, allocate a new
  /// logical shadow, then encode the saved candidate and its unapplied journal into that shadow.
  /// This never declares the candidate committed; the external durable decision controls that.
  /// The supplied runtime must be exclusively owned and its prior GPU work fully drained.
  public static func restorePreparedRecovery(_ source: BrainPreparedGPUImage,
    runtime: MetalAgentStateRuntime, device: any MTLDevice,
    commandBuffer: any MTL4CommandBuffer, options: MTL4CommitOptions,
    completion: @escaping @Sendable (Result<MetalJointAgentStateTransaction, Error>) -> Void) throws {
    let image = try source.validated()
    guard runtime.arena.layout.fingerprint == image.hotLayoutFingerprint,
      runtime.arena.memoryLayout.fingerprint == image.memoryLayoutFingerprint,
      runtime.arena.layout.totalByteCount == image.baseHotState.count,
      runtime.arena.memoryLayout.totalByteCount == image.basePersistentMemory.count,
      runtime.arena.memoryLayout.journalByteCount == image.shadowJournal.count else {
      throw TissueError.transaction("prepared recovery does not match compiled native layouts")
    }
    let root = try image.root.validatedToken()
    try runtime.restoreRecoveryImage(MetalAgentStateRecoveryImage(generation: root.baseBrainGeneration,
      hotState: image.baseHotState, persistentMemory: image.basePersistentMemory))
    let restored = try MetalJointAgentStateTransaction(jointToken: root, runtime: runtime,
      cachedDecisionFingerprint: image.cachedDecisionFingerprint)
    restored.currentStatus = .recoveryRestorePending
    do {
      try MetalPreparedRecoveryTransfer.restoreShadow(image: image, runtime: runtime,
        transaction: restored.agentStateToken, device: device, commandBuffer: commandBuffer,
        options: options) { result in
          restored.lock.lock()
          let answer: Result<MetalJointAgentStateTransaction, Error>
          do {
            try result.get()
            try runtime.arena.markEncoded(transaction: restored.agentStateToken,
              hotStateFullyDefined: true, memoryJournalFinalized: true)
            restored.acceptedPhysicsFingerprint = image.acceptedPhysicsTokenFingerprint
            restored.currentStatus = .gpuStateFinished
            answer = .success(restored)
          } catch {
            restored.currentStatus = .recoveryFailed
            answer = .failure(error)
          }
          restored.lock.unlock()
          completion(answer)
        }
    } catch {
      restored.currentStatus = .recoveryFailed
      try? restored.abort()
      throw error
    }
  }

  public func commit(with receipt: BrainJointCommitToken) throws {
    try prepareCommit(with: receipt); publishPreparedCommit()
  }
  func prepareCommit(with receipt: BrainJointCommitToken) throws {
    lock.lock(); defer { lock.unlock() }; try require(.gpuStateFinished)
    guard receipt.transactionFingerprint == jointToken.fingerprint,
      receipt.brainGeneration == agentStateToken.shadowGeneration,
      receipt.committedTimestamp == jointToken.targetTimestamp,
      receipt.parameterVersionFingerprint == jointToken.parameterVersionFingerprint,
      receipt.acceptedPhysicsTokenFingerprint == acceptedPhysicsFingerprint else {
      throw TissueError.transaction("joint receipt cannot publish the complete agent-state generation")
    }
    preparedCommit = try runtime.prepareCommit(transaction: agentStateToken)
    currentStatus = .commitPrepared
  }
  func publishPreparedCommit() {
    lock.lock(); defer { lock.unlock() }
    guard currentStatus == .commitPrepared, let preparedCommit else {
      preconditionFailure("joint cognitive commit was not prepared or a recovery transfer is pending")
    }
    runtime.publishPreparedCommit(preparedCommit)
    self.preparedCommit = nil; acceptedFastMotorState = nil; currentStatus = .committed
  }
  public func abort() throws {
    lock.lock(); defer { lock.unlock() }
    guard currentStatus == .open || currentStatus == .gpuStateFinished || currentStatus == .commitPrepared
      || currentStatus == .recoveryFailed else {
      throw TissueError.transaction("joint transaction cannot abort while \(currentStatus)")
    }
    try runtime.abort(transaction: agentStateToken)
    acceptedPhysicsFingerprint = nil; preparedGPUStateFinish = nil
    preparedCommit = nil; acceptedFastMotorState = nil; currentStatus = .aborted
  }
  private func require(_ expected: Status) throws {
    guard currentStatus == expected else {
      throw TissueError.transaction("joint brain-state transaction is \(currentStatus), expected \(expected)")
    }
  }
}

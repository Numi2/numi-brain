import Foundation
@preconcurrency import Metal
import NumiBrainCore

@available(macOS 26.0, *)
enum MetalNumanXPrepareTerminalFeedback: Sendable {
  case success(MetalGPUCompletionFeedback)
  case failure(String)

  var failureDescription: String? {
    guard case .failure(let message) = self else { return nil }
    return message
  }
}

/// Exact-once rendezvous for the independent fast and cognitive Metal
/// completions. Neither callback infers the other submission's state, and the
/// terminal consumer always runs after this latch's lock is released.
@available(macOS 26.0, *)
final class MetalNumanXPrepareFeedbackLatch: @unchecked Sendable {
  typealias Handler = @Sendable (
    MetalNumanXPrepareTerminalFeedback,
    MetalNumanXPrepareTerminalFeedback
  ) -> Void

  private let lock = NSLock()
  private var fast: MetalNumanXPrepareTerminalFeedback?
  private var cognitive: MetalNumanXPrepareTerminalFeedback?
  private var handler: Handler?
  private var handlerInstalled = false
  private var consumed = false

  func installHandler(_ handler: @escaping Handler) throws {
    let ready: (
      Handler,
      MetalNumanXPrepareTerminalFeedback,
      MetalNumanXPrepareTerminalFeedback
    )?
    lock.lock()
    guard !handlerInstalled, !consumed else {
      lock.unlock()
      throw TissueError.transaction(
        "NumanX prepare feedback latch handler is already installed"
      )
    }
    handlerInstalled = true
    self.handler = handler
    ready = takeReadyLocked()
    lock.unlock()
    if let ready { ready.0(ready.1, ready.2) }
  }

  func recordFast(_ feedback: MetalNumanXPrepareTerminalFeedback) {
    record(feedback, isFast: true)
  }

  func recordCognitive(_ feedback: MetalNumanXPrepareTerminalFeedback) {
    record(feedback, isFast: false)
  }

  /// Terminal owner reject/activation failure may make the rendezvous
  /// irrelevant before both host callbacks arrive. Cancellation only drops
  /// the consumer closure; already-recorded value feedback is harmless.
  func cancel() {
    lock.lock()
    consumed = true
    handler = nil
    lock.unlock()
  }

  private func record(
    _ feedback: MetalNumanXPrepareTerminalFeedback,
    isFast: Bool
  ) {
    let ready: (
      Handler,
      MetalNumanXPrepareTerminalFeedback,
      MetalNumanXPrepareTerminalFeedback
    )?
    lock.lock()
    if isFast {
      if fast == nil { fast = feedback }
    } else if cognitive == nil {
      cognitive = feedback
    }
    ready = takeReadyLocked()
    lock.unlock()
    if let ready { ready.0(ready.1, ready.2) }
  }

  private func takeReadyLocked() -> (
    Handler,
    MetalNumanXPrepareTerminalFeedback,
    MetalNumanXPrepareTerminalFeedback
  )? {
    guard !consumed, let handler, let fast, let cognitive else { return nil }
    consumed = true
    self.handler = nil
    return (handler, fast, cognitive)
  }
}

@available(macOS 26.0, *)
fileprivate final class MetalNumanXPublicationCallbackState: @unchecked Sendable {
  private let lock = NSLock()
  private var invocationCountStorage = 0

  @discardableResult
  func markInvoked() -> Bool {
    lock.lock()
    invocationCountStorage += 1
    let accepted = invocationCountStorage == 1
    lock.unlock()
    return accepted
  }

  var invocationCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return invocationCountStorage
  }
}

@available(macOS 26.0, *)
private final class MetalNumanXAggregateCloseState: @unchecked Sendable {
  typealias Handler = @Sendable () -> Void

  private let lock = NSLock()
  private var completed = false
  private var handler: Handler?
  private var registered = false

  /// Installs the owning-handle observer once. It may invoke synchronously if
  /// GPU completion won the race, so callers must never hold the handle lock.
  @discardableResult
  func register(_ handler: @escaping Handler) -> Bool {
    let invokeNow: Bool
    lock.lock()
    guard !registered else {
      lock.unlock()
      return false
    }
    registered = true
    invokeNow = completed
    if !invokeNow { self.handler = handler }
    lock.unlock()
    if invokeNow { handler() }
    return true
  }

  func complete() {
    let ready: Handler?
    lock.lock()
    guard !completed else {
      lock.unlock()
      return
    }
    completed = true
    ready = handler
    handler = nil
    lock.unlock()
    ready?()
  }
}

/// One authoritative Apple-GPU brain runtime spanning cortical cognition,
/// fast tissue, spinal protection, memory journals, and joint rollback.
///
/// Component runtimes are deliberately not public. All mutable control and
/// committed-state observation passes through this coordinator so a caller
/// cannot observe or advance one half of a joint publication independently.
@available(macOS 26.0, *)
public final class MetalNumiBrainRuntime: @unchecked Sendable {
  private enum NumanXCoordinationRecordCodec {
    static let byteCount = 128
    static let fingerprintOffset = 120
    static let fnvOffset: UInt64 = 14_695_981_039_346_656_037
    static let fnvPrime: UInt64 = 1_099_511_628_211

    static func put(_ value: UInt32, at offset: Int, in bytes: inout [UInt8]) {
      for index in 0..<4 {
        bytes[offset + index] = UInt8(
          truncatingIfNeeded: value >> UInt32(index * 8)
        )
      }
    }

    static func put(_ value: UInt64, at offset: Int, in bytes: inout [UInt8]) {
      for index in 0..<8 {
        bytes[offset + index] = UInt8(
          truncatingIfNeeded: value >> UInt64(index * 8)
        )
      }
    }

    static func finish(_ bytes: inout [UInt8]) -> UInt64 {
      precondition(bytes.count == byteCount)
      var hash = fnvOffset
      for byte in bytes[..<fingerprintOffset] {
        hash = (hash ^ UInt64(byte)) &* fnvPrime
      }
      if hash == 0 { hash = fnvOffset }
      put(hash, at: fingerprintOffset, in: &bytes)
      return hash
    }

    static func copy(
      _ bytes: [UInt8],
      to buffer: any MTLBuffer,
      byteOffset: Int = 0
    ) {
      let (end, overflow) = byteOffset.addingReportingOverflow(byteCount)
      precondition(
        bytes.count == byteCount && byteOffset >= 0 && !overflow
          && end <= buffer.length
      )
      bytes.withUnsafeBytes { source in
        buffer.contents().advanced(by: byteOffset).copyMemory(
          from: source.baseAddress!, byteCount: byteCount
        )
      }
    }
  }

  fileprivate final class NumanXBrainCommitPreflightResources:
    @unchecked Sendable
  {
    static let abiVersion: UInt32 = 1
    static let pending: UInt32 = 0
    static let success: UInt32 = 1

    let buffer: any MTLBuffer
    let readyPoint: MetalSharedEventPoint
    let identity: MetalNumanXHumanMatterRootIdentity
    let provisional: BrainProvisionalPhysicsAcceptance
    let fastProgramFingerprint: UInt64
    let brainProgramFingerprint: UInt64

    private let lock = NSLock()
    private var readySignaled = false

    init(
      fastTissue: MetalTissueRuntime,
      brainPreparedPoint: MetalSharedEventPoint,
      readyPoint: MetalSharedEventPoint,
      identity: MetalNumanXHumanMatterRootIdentity,
      provisional: BrainProvisionalPhysicsAcceptance,
      fastProgramFingerprint: UInt64,
      brainProgramFingerprint: UInt64
    ) throws {
      self.buffer = try fastTissue.makeNumanXCoordinationRecordBuffer(
        byteCount: NumanXCoordinationRecordCodec.byteCount,
        label: "NumiBrain Brain-commit preflight",
        readyPoint: readyPoint,
        after: brainPreparedPoint
      )
      self.readyPoint = readyPoint
      self.identity = identity
      self.provisional = provisional
      self.fastProgramFingerprint = fastProgramFingerprint
      self.brainProgramFingerprint = brainProgramFingerprint
      NumanXCoordinationRecordCodec.copy(
        makeRecord(
          status: Self.pending,
          physicsTokenFingerprint: 0,
          fastTargetGeneration: provisional.shadowGeneration,
          cognitiveTargetGeneration: provisional.shadowGeneration,
          jointReceiptFingerprint: 0
        ),
        to: buffer
      )
    }

    /// All throwing receipt/journal/anatomy work must already be complete.
    /// This method only replaces one shared compact record.
    func recordSuccess(
      acceptedPhysicsState: AcceptedPhysicsStateToken,
      fastTargetGeneration: UInt64,
      cognitiveTargetGeneration: UInt64,
      jointReceiptFingerprint: UInt64
    ) {
      precondition(
        acceptedPhysicsState.transactionFingerprint
          == provisional.transactionFingerprint
          && acceptedPhysicsState.substepFingerprint
            == provisional.substepFingerprint
          && acceptedPhysicsState.fingerprint > 0
          && acceptedPhysicsState.physicsGeneration
            == provisional.expectedPhysicsGeneration
          && fastTargetGeneration == provisional.shadowGeneration
          && cognitiveTargetGeneration == provisional.shadowGeneration
          && jointReceiptFingerprint > 0
      )
      NumanXCoordinationRecordCodec.copy(
        makeRecord(
          status: Self.success,
          physicsTokenFingerprint: acceptedPhysicsState.fingerprint,
          fastTargetGeneration: fastTargetGeneration,
          cognitiveTargetGeneration: cognitiveTargetGeneration,
          jointReceiptFingerprint: jointReceiptFingerprint
        ),
        to: buffer
      )
    }

    /// CPU advancement is liveness after the terminal shared record write.
    /// Failures deliberately leave the record PENDING so ACK fails closed.
    func signalReady() {
      lock.lock()
      defer { lock.unlock() }
      guard !readySignaled else { return }
      readySignaled = true
      if readyPoint.event.signaledValue < readyPoint.value {
        readyPoint.event.signaledValue = readyPoint.value
      }
    }

    var hasSignaledReady: Bool {
      lock.lock()
      defer { lock.unlock() }
      return readySignaled
    }

    private func makeRecord(
      status: UInt32,
      physicsTokenFingerprint: UInt64,
      fastTargetGeneration: UInt64,
      cognitiveTargetGeneration: UInt64,
      jointReceiptFingerprint: UInt64
    ) -> [UInt8] {
      var bytes = [UInt8](
        repeating: 0,
        count: NumanXCoordinationRecordCodec.byteCount
      )
      NumanXCoordinationRecordCodec.put(Self.abiVersion, at: 0, in: &bytes)
      NumanXCoordinationRecordCodec.put(
        UInt32(NumanXCoordinationRecordCodec.byteCount), at: 4, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(status, at: 8, in: &bytes)
      NumanXCoordinationRecordCodec.put(identity.environment, at: 12, in: &bytes)
      NumanXCoordinationRecordCodec.put(identity.controlStep, at: 16, in: &bytes)
      NumanXCoordinationRecordCodec.put(identity.substepIndex, at: 20, in: &bytes)
      NumanXCoordinationRecordCodec.put(
        identity.physicsSubstepCount, at: 24, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(identity.transactionSlot, at: 28, in: &bytes)
      NumanXCoordinationRecordCodec.put(
        identity.programFingerprint, at: 32, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(
        identity.transactionFingerprint, at: 40, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(
        identity.linearizationEpoch, at: 48, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(identity.slotGeneration, at: 56, in: &bytes)
      NumanXCoordinationRecordCodec.put(
        provisional.substepFingerprint, at: 64, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(
        physicsTokenFingerprint, at: 72, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(fastTargetGeneration, at: 80, in: &bytes)
      NumanXCoordinationRecordCodec.put(
        cognitiveTargetGeneration, at: 88, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(
        jointReceiptFingerprint, at: 96, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(fastProgramFingerprint, at: 104, in: &bytes)
      NumanXCoordinationRecordCodec.put(brainProgramFingerprint, at: 112, in: &bytes)
      _ = NumanXCoordinationRecordCodec.finish(&bytes)
      return bytes
    }
  }

  final class NumanXJointPublicationFenceResources:
    @unchecked Sendable
  {
    static let abiVersion: UInt32 = 1
    static let pending: UInt32 = 0
    static let committed: UInt32 = 1

    let buffer: any MTLBuffer
    let byteOffset: Int
    let identity: MetalNumanXHumanMatterRootIdentity
    let brainProgramFingerprint: UInt64
    private let preparedCommittedRecord: UnsafeMutableRawPointer
    private var hasPreparedCommittedRecord = false
    private var hasConsumedCommittedRecord = false

    convenience init(
      fastTissue: MetalTissueRuntime,
      identity: MetalNumanXHumanMatterRootIdentity,
      brainProgramFingerprint: UInt64
    ) throws {
      let buffer = try fastTissue.makeNumanXCoordinationRecordBuffer(
        byteCount: NumanXCoordinationRecordCodec.byteCount,
        label: "NumiBrain joint-publication fence"
      )
      try self.init(
        ownerBuffer: buffer,
        byteOffset: 0,
        deviceRegistryID: fastTissue.deviceRegistryID,
        identity: identity,
        brainProgramFingerprint: brainProgramFingerprint
      )
    }

    /// Production admission uses the exact owner-owned persistent fence range
    /// that the physical release capability prevalidates. It must never be
    /// substituted with a Brain allocation after application reservation.
    init(
      ownerBuffer: any MTLBuffer,
      byteOffset: Int,
      deviceRegistryID: UInt64,
      identity: MetalNumanXHumanMatterRootIdentity,
      brainProgramFingerprint: UInt64
    ) throws {
      let (end, overflow) = byteOffset.addingReportingOverflow(
        NumanXCoordinationRecordCodec.byteCount
      )
      guard byteOffset >= 0, byteOffset.isMultiple(of: 16), !overflow,
        end <= ownerBuffer.length, ownerBuffer.gpuAddress > 0,
        ownerBuffer.storageMode == .shared,
        ownerBuffer.device.registryID == deviceRegistryID,
        brainProgramFingerprint > 0
      else {
        throw TissueError.transaction(
          "NumanX publication fence must be the exact owner shared range"
        )
      }
      self.buffer = ownerBuffer
      self.byteOffset = byteOffset
      self.identity = identity
      self.brainProgramFingerprint = brainProgramFingerprint
      preparedCommittedRecord = UnsafeMutableRawPointer.allocate(
        byteCount: NumanXCoordinationRecordCodec.byteCount,
        alignment: 16
      )
      NumanXCoordinationRecordCodec.copy(
        makeRecord(
          status: Self.pending,
          physicsTokenFingerprint: 0,
          brainShadowStateFingerprint: 0,
          brainWitnessFingerprint: 0,
          appliedDecisionFingerprint: 0,
          jointCommitFingerprint: 0,
          brainGeneration: 0
        ),
        to: ownerBuffer,
        byteOffset: byteOffset
      )
    }

    deinit {
      preparedCommittedRecord.deallocate()
    }

    /// Builds and validates the complete terminal record before any private
    /// Brain pointer changes. The retained staging allocation is created with
    /// this resource, so the post-flip path performs only one fixed-size copy.
    func prepareCommittedRecord(
      physicsTokenFingerprint: UInt64,
      brainShadowStateFingerprint: UInt64,
      brainWitnessFingerprint: UInt64,
      appliedDecisionFingerprint: UInt64,
      jointCommitFingerprint: UInt64,
      brainGeneration: UInt64
    ) -> Bool {
      guard !hasPreparedCommittedRecord, !hasConsumedCommittedRecord,
        physicsTokenFingerprint > 0
          && brainShadowStateFingerprint > 0
          && brainWitnessFingerprint > 0
          && appliedDecisionFingerprint > 0
          && jointCommitFingerprint > 0
          && brainGeneration > 0
      else { return false }
      let record = makeRecord(
        status: Self.committed,
        physicsTokenFingerprint: physicsTokenFingerprint,
        brainShadowStateFingerprint: brainShadowStateFingerprint,
        brainWitnessFingerprint: brainWitnessFingerprint,
        appliedDecisionFingerprint: appliedDecisionFingerprint,
        jointCommitFingerprint: jointCommitFingerprint,
        brainGeneration: brainGeneration
      )
      record.withUnsafeBytes { source in
        preparedCommittedRecord.copyMemory(
          from: source.baseAddress!,
          byteCount: NumanXCoordinationRecordCodec.byteCount
        )
      }
      hasPreparedCommittedRecord = true
      return true
    }

    /// Postcondition of `prepareCommittedRecord`. This method allocates,
    /// validates, hashes, locks, and throws nothing; it is the sole fence write
    /// permitted between the private component flip and bridge release.
    @inline(__always)
    func copyPreparedCommittedRecord() {
      precondition(hasPreparedCommittedRecord)
      buffer.contents().advanced(by: byteOffset).copyMemory(
        from: preparedCommittedRecord,
        byteCount: NumanXCoordinationRecordCodec.byteCount
      )
      hasPreparedCommittedRecord = false
      hasConsumedCommittedRecord = true
    }

    private func makeRecord(
      status: UInt32,
      physicsTokenFingerprint: UInt64,
      brainShadowStateFingerprint: UInt64,
      brainWitnessFingerprint: UInt64,
      appliedDecisionFingerprint: UInt64,
      jointCommitFingerprint: UInt64,
      brainGeneration: UInt64
    ) -> [UInt8] {
      var bytes = [UInt8](
        repeating: 0,
        count: NumanXCoordinationRecordCodec.byteCount
      )
      NumanXCoordinationRecordCodec.put(Self.abiVersion, at: 0, in: &bytes)
      NumanXCoordinationRecordCodec.put(
        UInt32(NumanXCoordinationRecordCodec.byteCount), at: 4, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(status, at: 8, in: &bytes)
      NumanXCoordinationRecordCodec.put(identity.environment, at: 12, in: &bytes)
      NumanXCoordinationRecordCodec.put(identity.controlStep, at: 16, in: &bytes)
      NumanXCoordinationRecordCodec.put(identity.substepIndex, at: 20, in: &bytes)
      NumanXCoordinationRecordCodec.put(
        identity.physicsSubstepCount, at: 24, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(UInt32(0), at: 28, in: &bytes)
      NumanXCoordinationRecordCodec.put(
        identity.programFingerprint, at: 32, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(
        identity.transactionFingerprint, at: 40, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(
        identity.linearizationEpoch, at: 48, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(identity.slotGeneration, at: 56, in: &bytes)
      NumanXCoordinationRecordCodec.put(
        physicsTokenFingerprint, at: 64, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(brainProgramFingerprint, at: 72, in: &bytes)
      NumanXCoordinationRecordCodec.put(
        brainShadowStateFingerprint, at: 80, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(
        brainWitnessFingerprint, at: 88, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(
        appliedDecisionFingerprint, at: 96, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(
        jointCommitFingerprint, at: 104, in: &bytes
      )
      NumanXCoordinationRecordCodec.put(brainGeneration, at: 112, in: &bytes)
      _ = NumanXCoordinationRecordCodec.finish(&bytes)
      return bytes
    }
  }

  public final class ControlTransaction: @unchecked Sendable {
    @frozen
    public enum Status: Equatable, Sendable {
      case open
      case decisionSubmitted
      case numanXMotorSubmitted
      case decisionReady
      case substepActive
      case provisionalFastSubmitted
      case numanXPrepareSubmitted
      case numanXPreflightReady
      case numanXPreflightFailed
      case numanXAckSubmitted
      case numanXApplySubmitted
      case numanXAppliedValidationRetryRequired
      case acceptedConsequenceSubmitted
      case committed
      case aborted
      case terminalQuarantined
    }

    public let token: BrainJointTransactionToken
    private let stateLock = NSLock()
    private var statusStorage: Status = .open
    private var decisionStorage: MetalEmbodiedBrainRuntime.DecisionBufferView?
    private var activeSubstepStorage: BrainJointSubstepToken?
    private var lastAcceptedSubstepStorage: BrainJointSubstepToken?
    private var lastAcceptedPhysicsStateStorage: AcceptedPhysicsStateToken?
    private var provisionalPhysicsAcceptanceStorage:
      BrainProvisionalPhysicsAcceptance?

    public fileprivate(set) var status: Status {
      get {
        stateLock.lock()
        defer { stateLock.unlock() }
        return statusStorage
      }
      set {
        stateLock.lock()
        statusStorage = newValue
        stateLock.unlock()
      }
    }

    public fileprivate(set) var decision:
      MetalEmbodiedBrainRuntime.DecisionBufferView?
    {
      get {
        stateLock.lock()
        defer { stateLock.unlock() }
        return decisionStorage
      }
      set {
        stateLock.lock()
        decisionStorage = newValue
        stateLock.unlock()
      }
    }

    public fileprivate(set) var activeSubstep: BrainJointSubstepToken? {
      get {
        stateLock.lock()
        defer { stateLock.unlock() }
        return activeSubstepStorage
      }
      set {
        stateLock.lock()
        activeSubstepStorage = newValue
        stateLock.unlock()
      }
    }

    public fileprivate(set) var lastAcceptedSubstep: BrainJointSubstepToken? {
      get {
        stateLock.lock()
        defer { stateLock.unlock() }
        return lastAcceptedSubstepStorage
      }
      set {
        stateLock.lock()
        lastAcceptedSubstepStorage = newValue
        stateLock.unlock()
      }
    }

    public fileprivate(set) var lastAcceptedPhysicsState:
      AcceptedPhysicsStateToken?
    {
      get {
        stateLock.lock()
        defer { stateLock.unlock() }
        return lastAcceptedPhysicsStateStorage
      }
      set {
        stateLock.lock()
        lastAcceptedPhysicsStateStorage = newValue
        stateLock.unlock()
      }
    }

    public fileprivate(set) var provisionalPhysicsAcceptance:
      BrainProvisionalPhysicsAcceptance?
    {
      get {
        stateLock.lock()
        defer { stateLock.unlock() }
        return provisionalPhysicsAcceptanceStorage
      }
      set {
        stateLock.lock()
        provisionalPhysicsAcceptanceStorage = newValue
        stateLock.unlock()
      }
    }

    fileprivate let cognitiveTransaction: MetalJointAgentStateTransaction
    fileprivate var asyncSubmissionIdentifier: UUID?
    fileprivate var provisionalFastSubmissionIdentifier: UUID?
    fileprivate var numanXPreparedSubmissionIdentifier: UUID?
    fileprivate var provisionalFastMotorState:
      MetalTissueRuntime.AcceptedFastMotorStateLease?

    fileprivate init(
      token: BrainJointTransactionToken,
      cognitiveTransaction: MetalJointAgentStateTransaction
    ) {
      self.token = token
      self.cognitiveTransaction = cognitiveTransaction
    }
  }

  @frozen
  public struct CommitResult: Sendable {
    public let receipt: BrainJointCommitToken
    public let decision: MetalEmbodiedBrainRuntime.DecisionBufferView
    public let acceptedConsequence: MetalEmbodiedBrainRuntime.AcceptedConsequenceView
    public let fastSubmission: MetalTissueRuntime.Submission
  }

  /// Ownership handle for the unpublished complete-brain prepare phase. It
  /// exposes only root identity and safe timeline/status metadata. Compact
  /// proof/fence ranges and cognitive/fast candidate addresses stay in the
  /// module's explicit low-level interop layer until proposal, Brain ACK,
  /// physical apply, and publication-fence release all resolve.
  public final class NumanXPreparedControlTicket: @unchecked Sendable {
    public let identity: MetalNumanXHumanMatterRootIdentity
    public let provisionalPhysicsAcceptance: BrainProvisionalPhysicsAcceptance
    public let physicalPreparedPoint: MetalSharedEventPoint
    public let fastPreparedPoint: MetalSharedEventPoint
    public let brainPreparedPoint: MetalSharedEventPoint
    public let brainProgramFingerprint: UInt64
    public let brainCommitPreflightReadyPoint: MetalSharedEventPoint

    public var status: ControlTransaction.Status {
      owner.numanXPreparedControlStatus(self)
    }

    // Explicit low-level interop only. The public aggregate ticket never
    // exposes a compact proof/fence handle as committed Brain authority.
    @_spi(NumanXInterop) public let brainCommitWitnessGPUAddress: UInt64
    @_spi(NumanXInterop) public let brainCommitWitnessByteCount: Int
    @_spi(NumanXInterop) public let brainCommitWitnessMetalBufferObject:
      UnsafeMutableRawPointer

    private let owner: MetalNumiBrainRuntime
    fileprivate let identifier: UUID
    fileprivate let transaction: ControlTransaction
    fileprivate let fastTicket: MetalTissueRuntime.ProvisionalFastRootSubmissionTicket
    fileprivate let sensorCandidate: MetalNumanXPendingSensorCandidateLease
    let cognitiveTicket:
      MetalEmbodiedBrainRuntime.AcceptedConsequenceSubmissionTicket
    fileprivate let preflightResources: NumanXBrainCommitPreflightResources
    fileprivate var publicationFenceResources:
      NumanXJointPublicationFenceResources?
    fileprivate let prepareFeedbackLatch: MetalNumanXPrepareFeedbackLatch
    @_spi(NumanXInterop) public let brainCommitPreflightBuffer: any MTLBuffer
    fileprivate var acceptedPhysicsState: AcceptedPhysicsStateToken?
    fileprivate var preparedPublication: PreparedAtomicJointPublication?
    fileprivate var brainAckSubmissionReserved = false
    fileprivate var brainAckTicket: MetalNumanXHumanMatterBrainAckTicket?
    fileprivate var brainAckCompletion:
      MetalNumanXHumanMatterBrainAckCompletion?
    fileprivate var appliedValidationSubmissionReserved = false
    fileprivate var appliedValidationTicket:
      MetalNumanXHumanMatterAppliedValidationTicket?
    fileprivate var jointResolutionReservation:
      MetalNumanXJointResolutionReservation?
    fileprivate var publicationProtocolViolationDetected = false
    fileprivate var preflightFailureDescriptionStorage: String?
    fileprivate var qualificationOutcome: BrainPolicyNumanXRootOutcome?
    fileprivate var qualificationAppliedRecordFingerprint: UInt64 = 0
    fileprivate var qualificationJointCommitFingerprint: UInt64 = 0
    fileprivate let publicationCallbackState =
      MetalNumanXPublicationCallbackState()
    private let aggregateCloseState = MetalNumanXAggregateCloseState()

    fileprivate init(
      identifier: UUID,
      owner: MetalNumiBrainRuntime,
      transaction: ControlTransaction,
      identity: MetalNumanXHumanMatterRootIdentity,
      fastTicket: MetalTissueRuntime.ProvisionalFastRootSubmissionTicket,
      sensorCandidate: MetalNumanXPendingSensorCandidateLease,
      cognitiveTicket: MetalEmbodiedBrainRuntime.AcceptedConsequenceSubmissionTicket,
      brainCommitWitnessGPUAddress: UInt64,
      brainCommitWitnessByteCount: Int,
      brainCommitWitnessMetalBufferObject: UnsafeMutableRawPointer,
      brainProgramFingerprint: UInt64,
      preflightResources: NumanXBrainCommitPreflightResources,
      prepareFeedbackLatch: MetalNumanXPrepareFeedbackLatch
    ) {
      self.identifier = identifier
      self.owner = owner
      self.transaction = transaction
      self.identity = identity
      self.fastTicket = fastTicket
      self.sensorCandidate = sensorCandidate
      self.cognitiveTicket = cognitiveTicket
      provisionalPhysicsAcceptance = fastTicket.provisional
      physicalPreparedPoint = fastTicket.waitPoint
      fastPreparedPoint = fastTicket.completionPoint
      brainPreparedPoint = cognitiveTicket.completionPoint
      self.brainCommitWitnessGPUAddress = brainCommitWitnessGPUAddress
      self.brainCommitWitnessByteCount = brainCommitWitnessByteCount
      self.brainCommitWitnessMetalBufferObject =
        brainCommitWitnessMetalBufferObject
      self.brainProgramFingerprint = brainProgramFingerprint
      self.preflightResources = preflightResources
      publicationFenceResources = nil
      self.prepareFeedbackLatch = prepareFeedbackLatch
      brainCommitPreflightReadyPoint = preflightResources.readyPoint
      brainCommitPreflightBuffer = preflightResources.buffer
    }

    public var hasBrainPrepareCompleted: Bool { cognitiveTicket.hasCompleted }

    public func brainPrepareFeedbackIfAvailable() throws
      -> MetalGPUCompletionFeedback?
    {
      try cognitiveTicket.completionFeedbackIfAvailable()
    }

    /// Diagnostic/test wait only. The production authority path proceeds from
    /// shared events through proposal, ACK, apply, and release and never calls
    /// it.
    public func waitUntilBrainPrepareCompleted(
      timeoutMilliseconds: UInt64 = 30_000
    ) throws -> MetalGPUCompletionFeedback {
      try cognitiveTicket.waitUntilCompleted(
        timeoutMilliseconds: timeoutMilliseconds
      )
    }

    /// Safe diagnostic metadata only. A duplicate bridge latch is idempotent:
    /// the already released joint root stays published, while this flag makes
    /// the protocol defect observable without exposing any candidate range.
    public var hasPublicationProtocolViolation: Bool {
      owner.numanXPublicationProtocolViolation(self)
    }

    /// Host diagnostic only. This never authorizes ACK/apply and is populated
    /// only after the exact preflight has already failed closed.
    public var preflightFailureDescription: String? {
      owner.numanXPreparedPreflightFailureDescription(self)
    }

    /// Returns an evidence-grade transcript only after the exact owner root
    /// has reached authoritative release. GPU failure and terminal quarantine
    /// never fabricate a qualification execution.
    func qualificationRootExecution(
      sampleSHA256: String
    ) throws -> BrainPolicyNumanXRootExecution {
      try owner.numanXQualificationRootExecution(
        self,
        sampleSHA256: sampleSHA256
      )
    }

    /// Evidence-grade terminal transcript bound to the exact canonical sample
    /// manifest consumed by this control root. This is the production Gate C
    /// surface; arbitrary caller-provided hashes are intentionally not public.
    public func qualificationRootExecution(
      capturedSample: MetalNumanXCapturedRootSample
    ) throws -> BrainPolicyNumanXRootExecution {
      try owner.numanXQualificationRootExecution(
        self,
        capturedSample: capturedSample
      )
    }

    @discardableResult
    func registerOwningHandleTerminalRelease(
      _ handler: @escaping @Sendable () -> Void
    ) -> Bool {
      aggregateCloseState.register(handler)
    }

    fileprivate func completeOwningHandleTerminalRelease() {
      aggregateCloseState.complete()
    }
  }

  let cognitive: MetalEmbodiedBrainRuntime
  let fastTissue: MetalTissueRuntime
  public let parameterVersionFingerprint: UInt64
  public let compiledSpeciesTemplateFingerprint: UInt64
  public let regionalProgramFingerprint: UInt64
  public let scheduleFingerprint: UInt64
  public let somaticSynergyCatalogFingerprint: UInt64
  public let deviceRegistryID: UInt64

  private let lock = NSLock()
  private var activeTransaction: ControlTransaction?
  // Intentional ownership cycle while a joint close is in flight. It is
  // cleared only by exact reject/release; terminal quarantine retains every
  // lease and compact record for diagnosis or an authorized retry.
  private var activeNumanXPreparedTicket: NumanXPreparedControlTicket?
  private var publishedGeneration: UInt64

  fileprivate struct PreparedAtomicJointPublication {
    let fast: MetalTissueRuntime.PreparedJointRootCommit
    let cognitive: MetalJointAgentStateTransaction
    let jointCommitFingerprint: UInt64
  }

  init(
    cognitive: MetalEmbodiedBrainRuntime,
    fastTissue: MetalTissueRuntime
  ) throws {
    let compiledSpeciesTemplate = cognitive.boundCompiledSpeciesTemplate
    guard cognitive.deviceRegistryID == fastTissue.deviceRegistryID,
      cognitive.parameterVersionFingerprint == fastTissue.parameterVersion.fingerprint,
      cognitive.regionalProgramFingerprint == fastTissue.regionalTokenProgram.fingerprint,
      cognitive.scheduleFingerprint == fastTissue.brainSchedule.fingerprint,
      cognitive.somaticSynergyCatalogFingerprint
        == fastTissue.somaticSynergyCatalog.fingerprint,
      compiledSpeciesTemplate.protectiveMotorProfile
        == fastTissue.protectiveMotorProfile,
      compiledSpeciesTemplate.muscleAttachmentCatalog
        == fastTissue.numanXMuscleAttachmentCatalog,
      compiledSpeciesTemplate.somaticSynergyCatalog
        == fastTissue.somaticSynergyCatalog,
      cognitive.agentStateRuntime.arena.committedGeneration
        == fastTissue.schedulerCommittedGeneration,
      cognitive.sharedParameterBank.artifactFingerprint
        == fastTissue.sharedParameterBank.artifactFingerprint,
      cognitive.sensoryRuntime.maximumEventCount <= fastTissue.maxSchedulerEvents
    else {
      throw TissueError.transaction(
        "cognitive and fast runtimes do not share one device and immutable brain version"
      )
    }
    try fastTissue.bindSpeciesReflexProgram(compiledSpeciesTemplate)
    self.cognitive = cognitive
    self.fastTissue = fastTissue
    self.parameterVersionFingerprint = cognitive.parameterVersionFingerprint
    self.compiledSpeciesTemplateFingerprint =
      cognitive.compiledSpeciesTemplateFingerprint
    self.regionalProgramFingerprint = cognitive.regionalProgramFingerprint
    self.scheduleFingerprint = cognitive.scheduleFingerprint
    self.somaticSynergyCatalogFingerprint = cognitive.somaticSynergyCatalogFingerprint
    self.deviceRegistryID = cognitive.deviceRegistryID
    self.publishedGeneration = cognitive.agentStateRuntime.arena.committedGeneration
  }

  /// The only externally observable neural generation. It advances after both
  /// cognitive and fast pointer generations have published under this lock.
  public var committedGeneration: UInt64 {
    lock.lock()
    defer { lock.unlock() }
    return publishedGeneration
  }

  public var hasOpenControl: Bool {
    lock.lock()
    defer { lock.unlock() }
    return activeTransaction != nil
  }

  /// Establishes that this complete brain consumes the exact immutable bytes
  /// and registry lease of a rollout cohort before the first control begins.
  public func validate(parameterCohort: MetalParameterCohort) throws {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction == nil else {
      throw TissueError.transaction(
        "cannot bind parameter cohort during an active control"
      )
    }
    try parameterCohort.validate(runtime: self)
  }

  /// Freezes one complete mind's committed learner-visible memory only after
  /// its joint brain-physics transaction has closed. The returned allocations
  /// remain immutable while this runtime resumes rollout.
  public func makeLearningBatch() throws -> MetalLearningBatch {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction == nil else {
      throw TissueError.transaction(
        "learning snapshots require a closed complete-brain control root"
      )
    }
    return try cognitive.makeLearningBatch()
  }

  /// Binds the immutable snapshot to the persistent identity owned by the
  /// rollout orchestrator, ready for canonical multi-mind cohort assembly.
  public func makeLearningCohortMember(
    mindIdentifier: UInt64
  ) throws -> MetalLearningCohortMember {
    try MetalLearningCohortMember(
      mindIdentifier: mindIdentifier,
      batch: makeLearningBatch()
    )
  }

  /// Returns only page requests from the last committed brain generation.
  /// Archive orchestration is intentionally unavailable during a control root.
  public func snapshotArchivePageRequests() throws
    -> MetalArchivePageRequestSnapshot
  {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction == nil else {
      throw TissueError.transaction(
        "archive paging waits for the active brain control to finish"
      )
    }
    return try cognitive.agentStateRuntime.snapshotArchivePageRequests()
  }

  public func snapshotArchivePages(
    _ pageIdentifiers: [UInt32]
  ) throws -> [MetalArchivePagePayload] {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction == nil else {
      throw TissueError.transaction(
        "archive pages cannot be exported during joint control"
      )
    }
    return try cognitive.agentStateRuntime.snapshotArchivePages(
      pageIdentifiers
    )
  }

  public func loadArchivePages(
    _ payloads: [MetalArchivePagePayload]
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction == nil else {
      throw TissueError.transaction(
        "archive pages cannot be loaded during joint control"
      )
    }
    try cognitive.agentStateRuntime.loadArchivePages(payloads)
  }

  public func evictArchivePages(_ pageIdentifiers: [UInt32]) throws {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction == nil else {
      throw TissueError.transaction(
        "archive paging waits for the active brain control to finish"
      )
    }
    try cognitive.agentStateRuntime.evictArchivePages(pageIdentifiers)
  }

  public func resolveArchivePageRequests(
    _ snapshot: MetalArchivePageRequestSnapshot,
    residentPageIdentifiers: [UInt32]
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction == nil else {
      throw TissueError.transaction(
        "archive paging waits for the active brain control to finish"
      )
    }
    try cognitive.agentStateRuntime.resolveArchivePageRequests(
      snapshot,
      residentPageIdentifiers: residentPageIdentifiers
    )
  }

  public func resolveArchivePageRequests(
    _ snapshot: MetalArchivePageRequestSnapshot,
    loadedPages: [MetalArchivePagePayload]
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction == nil else {
      throw TissueError.transaction(
        "archive requests cannot be resolved during joint control"
      )
    }
    let requested = Set(snapshot.requests.map(\.pageIdentifier))
    let loaded = Set(loadedPages.map(\.pageIdentifier))
    guard
      snapshot.committedGeneration
        == cognitive.agentStateRuntime.arena.committedGeneration,
      loaded.isSubset(of: requested)
    else {
      throw TissueError.transaction(
        "archive request snapshot is stale or contains an unrequested page"
      )
    }
    try cognitive.agentStateRuntime.loadArchivePages(loadedPages)
    try cognitive.agentStateRuntime.resolveArchivePageRequests(
      snapshot,
      residentPageIdentifiers: loaded.sorted()
    )
  }

  /// Moves one committed embodied mind into an already-created direct
  /// successor runtime. The source remains untouched until the successor has
  /// accepted the complete migrated checkpoint, so a failed activation cannot
  /// destroy the last valid agent state.
  @discardableResult
  public func transferCommittedState(
    to successor: MetalNumiBrainRuntime,
    parameterCohort: MetalParameterCohort,
    controlStepIdentifier: UInt64,
    physicalCheckpointFingerprint: UInt64
  ) throws -> MetalNumiBrainCheckpoint {
    let parentCheckpoint = try saveCheckpoint(
      controlStepIdentifier: controlStepIdentifier,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    let migratedCheckpoint = try parentCheckpoint.migrated(
      from: fastTissue.parameterVersion,
      to: parameterCohort.publication
    )
    try successor.validate(parameterCohort: parameterCohort)
    try successor.loadCheckpoint(
      migratedCheckpoint,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    return migratedCheckpoint
  }

  /// Captures one causally complete brain checkpoint. The caller supplies the
  /// fingerprint returned by the simultaneously saved NumanX body checkpoint;
  /// the envelope refuses to exist if cognitive and fast generations diverge.
  public func saveCheckpoint(
    controlStepIdentifier: UInt64,
    physicalCheckpointFingerprint: UInt64
  ) throws -> MetalNumiBrainCheckpoint {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction == nil, physicalCheckpointFingerprint > 0 else {
      throw TissueError.transaction(
        "finish active control and provide the owning physical checkpoint"
      )
    }
    guard cognitive.agentStateRuntime.arena.committedGeneration
        == publishedGeneration,
      fastTissue.schedulerCommittedGeneration == publishedGeneration
    else {
      throw TissueError.transaction(
        "complete brain components diverged from the joint publication"
      )
    }
    let fast = try fastTissue.saveCheckpoint()
    let timestamp =
      fast.committedSchedulerTime
      ?? BrainTimestamp(microseconds: 0)
    let cognitiveState = try cognitive.saveCheckpoint(
      environmentIdentifier: fast.environmentIdentifier,
      episodeIdentifier: UInt64(fast.randomContext.episodeIdentifier),
      controlStepIdentifier: controlStepIdentifier,
      committedTimestamp: timestamp,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    return try MetalNumiBrainCheckpoint(
      cognitiveState: cognitiveState,
      fastTissueState: fast
    )
  }

  /// Validates the complete envelope before mutating either runtime, then
  /// restores cognitive and fast generations to their shared root boundary.
  public func loadCheckpoint(
    _ checkpoint: MetalNumiBrainCheckpoint,
    physicalCheckpointFingerprint: UInt64
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction == nil,
      physicalCheckpointFingerprint == checkpoint.physicalCheckpointFingerprint
    else {
      throw TissueError.transaction(
        "finish active control and restore the checkpoint's owning physical body"
      )
    }
    try checkpoint.validate()
    try cognitive.validateCheckpointCompatibility(
      checkpoint.cognitiveState,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    try fastTissue.validateCheckpointCompatibility(checkpoint.fastTissueState)
    try cognitive.loadCheckpoint(
      checkpoint.cognitiveState,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    try fastTissue.loadCheckpoint(checkpoint.fastTissueState)
    publishedGeneration = checkpoint.committedGeneration
  }

  /// Opens one root in both complete-agent state and fast tissue. The cached
  /// decision fingerprint identifies deterministic stochastic choices for the
  /// root and therefore must remain unchanged across physical retries.
  public func beginControl(
    controlStepIdentifier: UInt64,
    basePhysicsGeneration: UInt64,
    committedTimestamp: BrainTimestamp,
    targetTimestamp: BrainTimestamp,
    cachedDecisionFingerprint: UInt64
  ) throws -> ControlTransaction {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction == nil,
      activeNumanXPreparedTicket == nil,
      cachedDecisionFingerprint > 0
    else {
      throw TissueError.transaction(
        "finish or abort the active brain control before beginning another"
      )
    }
    guard cognitive.agentStateRuntime.arena.committedGeneration
        == publishedGeneration,
      fastTissue.schedulerCommittedGeneration == publishedGeneration
    else {
      throw TissueError.transaction(
        "joint control cannot begin from divergent component generations"
      )
    }
    let token = try fastTissue.beginInteractiveJointControl(
      controlStepIdentifier: controlStepIdentifier,
      basePhysicsGeneration: basePhysicsGeneration,
      committedTimestamp: committedTimestamp,
      targetTimestamp: targetTimestamp
    )
    do {
      let cognitiveTransaction = try cognitive.beginControl(
        jointToken: token,
        cachedDecisionFingerprint: cachedDecisionFingerprint
      )
      let transaction = ControlTransaction(
        token: token,
        cognitiveTransaction: cognitiveTransaction
      )
      activeTransaction = transaction
      return transaction
    } catch {
      try? fastTissue.abortInteractiveJointControl()
      throw error
    }
  }

  /// Runs causal sensor transduction and the high-level decision once. The
  /// resulting somatic command, developmental mask, and fast plasticity state
  /// are copied GPU-to-GPU into the tissue runtime before any physics attempt.
  @discardableResult
  public func inferAndDecide(
    _ transaction: ControlTransaction,
    numanXSensors: NumanXSensorPacketLease,
    externalGoal: ActiveGoal? = nil
  ) throws -> MetalEmbodiedBrainRuntime.DecisionBufferView {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .open)
    do {
      let recurrence = try fastTissue.committedRegionalRecurrentBufferView()
      let decision = try cognitive.inferAndDecide(
        transaction: transaction.cognitiveTransaction,
        numanXSensors: numanXSensors,
        regionalRecurrentInput: recurrence,
        externalGoal: externalGoal
      )
      let lease = try cognitive.borrowNumanXSomaticBuffer(
        for: decision,
        transaction: transaction.cognitiveTransaction
      )
      try fastTissue.stageDescendingSomaticCommand(lease, for: transaction.token)
      transaction.decision = decision
      transaction.status = .decisionReady
      return decision
    } catch {
      abortLocked(transaction)
      throw error
    }
  }

  /// Submits the high-level embodied decision without a host completion wait.
  /// NumanX can queue GPU work that waits on `completionPoint` immediately.
  /// Finishing the ticket is the explicit host boundary that stages the result
  /// into the fast neural runtime and advances the control to `decisionReady`.
  public func submitInferAndDecide(
    _ transaction: ControlTransaction,
    numanXSensors: NumanXSensorPacketLease,
    externalGoal: ActiveGoal? = nil,
    waitFor waitPoint: MetalSharedEventPoint? = nil,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> DecisionSubmissionTicket {
    try submitInferAndDecide(
      transaction,
      numanXSensors: numanXSensors,
      externalGoal: externalGoal,
      activeSensingCommandScale: 1,
      waitFor: waitPoint,
      signal: completionPoint
    )
  }

  /// Qualification-only command intervention. It is internal so production
  /// callers cannot bypass the autonomous policy; the resulting zeroed command
  /// still passes through the ordinary decision-ready and motor-ready proofs.
  func submitInferAndDecide(
    _ transaction: ControlTransaction,
    numanXSensors: NumanXSensorPacketLease,
    externalGoal: ActiveGoal? = nil,
    activeSensingCommandScale: Float,
    waitFor waitPoint: MetalSharedEventPoint? = nil,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> DecisionSubmissionTicket {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .open)
    do {
      let recurrence = try fastTissue.committedRegionalRecurrentBufferView()
      let cognitiveTicket = try cognitive.submitInferAndDecide(
        transaction: transaction.cognitiveTransaction,
        numanXSensors: numanXSensors,
        regionalRecurrentInput: recurrence,
        externalGoal: externalGoal,
        activeSensingCommandScale: activeSensingCommandScale,
        waitFor: waitPoint,
        signal: completionPoint
      )
      let identifier = UUID()
      transaction.asyncSubmissionIdentifier = identifier
      transaction.status = .decisionSubmitted
      return DecisionSubmissionTicket(
        identifier: identifier,
        owner: self,
        cognitiveTicket: cognitiveTicket
      )
    } catch {
      abortLocked(transaction)
      throw error
    }
  }

  @discardableResult
  public func finishInferAndDecideSubmission(
    _ ticket: DecisionSubmissionTicket,
    transaction: ControlTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws -> MetalEmbodiedBrainRuntime.DecisionBufferView {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .decisionSubmitted)
    guard transaction.asyncSubmissionIdentifier == ticket.identifier,
      ticket.decision.transactionFingerprint == transaction.token.fingerprint
    else {
      throw TissueError.transaction("async complete-brain decision ticket is stale")
    }
    do {
      _ = try cognitive.finishDecisionSubmission(
        ticket.cognitiveTicket,
        transaction: transaction.cognitiveTransaction,
        timeoutMilliseconds: timeoutMilliseconds
      )
      let lease = try cognitive.borrowNumanXSomaticBuffer(
        for: ticket.decision,
        transaction: transaction.cognitiveTransaction
      )
      try fastTissue.stageDescendingSomaticCommand(lease, for: transaction.token)
      transaction.decision = ticket.decision
      transaction.asyncSubmissionIdentifier = nil
      transaction.status = .decisionReady
      return ticket.decision
    } catch {
      if cognitive.ownsOutstandingSubmission(ticket.cognitiveTicket.identifier) {
        throw error
      }
      abortLocked(transaction)
      throw error
    }
  }

  public func abortInferAndDecideSubmission(
    _ ticket: DecisionSubmissionTicket,
    transaction: ControlTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .decisionSubmitted)
    guard transaction.asyncSubmissionIdentifier == ticket.identifier else {
      throw TissueError.transaction("async complete-brain decision ticket is stale")
    }
    do {
      try cognitive.abortDecisionSubmission(
        ticket.cognitiveTicket,
        transaction: transaction.cognitiveTransaction,
        timeoutMilliseconds: timeoutMilliseconds
      )
    } catch {
      if cognitive.ownsOutstandingSubmission(ticket.cognitiveTicket.identifier) {
        throw error
      }
      abortLocked(transaction)
      throw error
    }
    abortLocked(transaction)
  }

  /// Arms the sole physical motor candidate directly behind an already queued
  /// cognitive decision. The decision ticket remains caller-owned until this
  /// method succeeds, so any fallible motor preflight leaves the original
  /// decision submission available for exact abort/teardown.
  public func submitNumanXMotorCandidate(
    _ decisionTicket: DecisionSubmissionTicket,
    transaction: ControlTransaction,
    candidateDurationMicroseconds: UInt64,
    signal motorReadyPoint: MetalSharedEventPoint
  ) throws -> NumanXMotorSubmissionTicket {
    try submitNumanXMotorCandidate(
      decisionTicket,
      transaction: transaction,
      candidateDurationMicroseconds: candidateDurationMicroseconds,
      qualificationInterruptEvents: [],
      signal: motorReadyPoint
    )
  }

  /// Qualification-only same-root safety challenge. The injected interrupts
  /// enter the ordinary private fast-motor overlay after the learned command;
  /// they do not alter accepted history or provide production mutation
  /// authority to callers outside this module.
  func submitNumanXMotorCandidate(
    _ decisionTicket: DecisionSubmissionTicket,
    transaction: ControlTransaction,
    candidateDurationMicroseconds: UInt64,
    qualificationInterruptEvents: [BrainInterruptEvent],
    signal motorReadyPoint: MetalSharedEventPoint
  ) throws -> NumanXMotorSubmissionTicket {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .decisionSubmitted)
    guard transaction.asyncSubmissionIdentifier == decisionTicket.identifier,
      decisionTicket.decision.transactionFingerprint
        == transaction.token.fingerprint
    else {
      throw TissueError.transaction("async NumanX decision ticket is stale")
    }
    do {
      let commandLease = try cognitive.borrowNumanXSomaticBuffer(
        for: decisionTicket.decision,
        transaction: transaction.cognitiveTransaction
      )
      let motorTicket = try fastTissue.submitNumanXMotorCandidate(
        commandLease: commandLease,
        decisionEvaluation:
          decisionTicket.cognitiveTicket.decisionGateEvaluation,
        transaction: transaction.token,
        candidateDurationMicroseconds: candidateDurationMicroseconds,
        waitFor: decisionTicket.completionPoint,
        signal: motorReadyPoint,
        brainProgramFingerprint: cognitive.numanXBrainProgramFingerprint,
        qualificationInterruptEvents: qualificationInterruptEvents
      )
      transaction.decision = decisionTicket.decision
      transaction.activeSubstep = motorTicket.fastSystems.substep
      transaction.status = .numanXMotorSubmitted
      return NumanXMotorSubmissionTicket(
        identifier: decisionTicket.identifier,
        owner: self,
        cognitiveTicket: decisionTicket.cognitiveTicket,
        motorTicket: motorTicket
      )
    } catch {
      // No motor ticket was armed. The cognitive ticket and its retained
      // resources remain valid in `.decisionSubmitted`, so the caller can
      // retry this preflight or explicitly abort without losing authority.
      throw error
    }
  }

  /// Nonblocking settlement for the decision-to-motor chain. A nil result
  /// preserves both submissions and every retained Metal allocation. Only
  /// terminal feedback from both command buffers advances the root into the
  /// ordinary active-substep state.
  public func reapNumanXMotorSubmissionIfCompleted(
    _ ticket: NumanXMotorSubmissionTicket,
    transaction: ControlTransaction
  ) throws -> MetalTissueRuntime.FastSystemResult? {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .numanXMotorSubmitted)
    guard transaction.asyncSubmissionIdentifier == ticket.identifier,
      transaction.activeSubstep == ticket.fastSystems.substep,
      ticket.decision.transactionFingerprint == transaction.token.fingerprint
    else {
      throw TissueError.transaction("async NumanX motor ticket is stale")
    }
    guard ticket.cognitiveTicket.hasCompleted,
      ticket.motorTicket.hasCompleted
    else {
      return nil
    }

    var firstError: Error?
    do {
      _ = try cognitive.reapDecisionSubmissionIfCompleted(
        ticket.cognitiveTicket,
        transaction: transaction.cognitiveTransaction
      )
    } catch {
      firstError = error
    }
    do {
      _ = try fastTissue.reapNumanXMotorSubmissionIfCompleted(
        ticket.motorTicket
      )
    } catch {
      if firstError == nil { firstError = error }
    }
    if let firstError {
      transaction.asyncSubmissionIdentifier = nil
      abortLocked(transaction)
      throw firstError
    }
    transaction.asyncSubmissionIdentifier = nil
    transaction.status = .substepActive
    return ticket.fastSystems
  }

  /// Explicit diagnostic boundary. Production physical work waits on the
  /// motor-ready event and validates its 160-byte gate; this helper is for
  /// tests and teardown paths that intentionally wait on host feedback.
  public func finishNumanXMotorSubmission(
    _ ticket: NumanXMotorSubmissionTicket,
    transaction: ControlTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws -> MetalTissueRuntime.FastSystemResult {
    guard timeoutMilliseconds > 0 else {
      throw TissueError.transaction("GPU completion timeout must be positive")
    }
    _ = try ticket.cognitiveTicket.waitUntilCompleted(
      timeoutMilliseconds: timeoutMilliseconds
    )
    _ = try ticket.motorTicket.waitUntilCompleted(
      timeoutMilliseconds: timeoutMilliseconds
    )
    guard let result = try reapNumanXMotorSubmissionIfCompleted(
      ticket,
      transaction: transaction
    ) else {
      throw TissueError.metal(
        "NumanX motor feedback disappeared after terminal completion"
      )
    }
    return result
  }

  func qualificationProtectiveObservation(
    _ ticket: NumanXMotorSubmissionTicket,
    transaction: ControlTransaction
  ) throws -> MetalTissueRuntime.NumanXProtectiveQualificationObservation {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction === transaction,
      ticket.identifier == transaction.asyncSubmissionIdentifier
        || transaction.asyncSubmissionIdentifier == nil,
      ticket.decision.transactionFingerprint == transaction.token.fingerprint
    else {
      throw TissueError.transaction(
        "NumanX protective qualification ticket is stale"
      )
    }
    return try fastTissue.qualificationObservation(for: ticket.motorTicket)
  }

  /// Qualification/production safety boundary for a command-successful
  /// uncertainty rejection. Unlike command failure, this preserves the open
  /// joint transaction long enough for Human/Matter to restore and emit an
  /// authoritative rejected root. No neural shadow is published here.
  @_spi(NumanXInterop)
  public func finishNumanXPolicyRejectedMotorSubmission(
    _ ticket: NumanXMotorSubmissionTicket,
    transaction: ControlTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws -> NumanXPolicyRejectionSettlement {
    guard timeoutMilliseconds > 0 else {
      throw TissueError.transaction("GPU completion timeout must be positive")
    }
    _ = try ticket.cognitiveTicket.waitUntilCompleted(
      timeoutMilliseconds: timeoutMilliseconds
    )
    _ = try ticket.motorTicket.waitUntilCompleted(
      timeoutMilliseconds: timeoutMilliseconds
    )
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .numanXMotorSubmitted)
    guard transaction.asyncSubmissionIdentifier == ticket.identifier,
      transaction.activeSubstep == ticket.fastSystems.substep,
      ticket.decision.transactionFingerprint == transaction.token.fingerprint,
      let uncertainty = ticket.cognitiveTicket.decisionGateEvaluation
        .qualificationUncertaintyObservation()
    else {
      throw TissueError.transaction(
        "policy-rejected NumanX motor ticket is stale or unproven"
      )
    }
    do {
      guard try cognitive.reapPolicyRejectedDecisionSubmissionIfCompleted(
        ticket.cognitiveTicket,
        transaction: transaction.cognitiveTransaction
      ) != nil,
        try fastTissue.reapPolicyRejectedNumanXMotorSubmissionIfCompleted(
          ticket.motorTicket
        ) != nil
      else {
        throw TissueError.metal(
          "policy-rejected NumanX feedback disappeared after completion"
        )
      }
    } catch {
      transaction.asyncSubmissionIdentifier = nil
      abortLocked(transaction)
      throw error
    }
    transaction.asyncSubmissionIdentifier = nil
    transaction.status = .substepActive
    return NumanXPolicyRejectionSettlement(
      fastSystems: ticket.fastSystems,
      uncertainty: uncertainty
    )
  }

  /// Begins one retryable fast neural/physical candidate. Rejected attempts
  /// reuse the cached decision and do not advance random or neural history.
  public func advanceFastSystems(
    _ transaction: ControlTransaction,
    candidateDurationMicroseconds: UInt64
  ) throws -> MetalTissueRuntime.FastSystemResult {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .decisionReady)
    let result = try fastTissue.advanceFastSystems(
      candidateDurationMicroseconds: candidateDurationMicroseconds
    )
    transaction.activeSubstep = result.substep
    transaction.status = .substepActive
    return result
  }

  public func borrowNumanXMotorBuffers(
    _ transaction: ControlTransaction,
    fastSystems: MetalTissueRuntime.FastSystemResult
  ) throws -> MetalTissueRuntime.NumanXMotorBufferLease {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .substepActive)
    guard transaction.activeSubstep == fastSystems.substep else {
      throw TissueError.transaction("fast motor buffers belong to another candidate")
    }
    return try fastTissue.borrowNumanXMotorBuffers(for: fastSystems)
  }

  /// Lends the complete high-level command allocation for autonomic and
  /// active-sensing consumers. NumanX should take somatic excitation from the
  /// fast-system lease so reflex and protective overlays remain authoritative.
  public func borrowEmbodiedCommandBuffers(
    _ transaction: ControlTransaction
  ) throws -> MetalEmbodiedBrainRuntime.NumanXSomaticBufferLease {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction === transaction,
      transaction.status == .decisionReady || transaction.status == .substepActive,
      let decision = transaction.decision
    else {
      throw TissueError.transaction("embodied command is not ready for this control")
    }
    return try cognitive.borrowNumanXSomaticBuffer(
      for: decision,
      transaction: transaction.cognitiveTransaction
    )
  }

  public func acceptPhysicsSubstep(
    _ transaction: ControlTransaction,
    accepted: AcceptedPhysicsStateToken,
    receptorEvents: [BrainInterruptEvent] = [],
    localizedMuscleLoadObservations: [LocalizedMuscleLoadReceptorObservation] = []
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .substepActive)
    guard let substep = transaction.activeSubstep else {
      throw TissueError.transaction("there is no active fast candidate to accept")
    }
    try fastTissue.acceptPhysicsSubstep(
      accepted,
      for: substep,
      receptorEvents: receptorEvents,
      localizedMuscleLoadObservations: localizedMuscleLoadObservations
    )
    transaction.lastAcceptedSubstep = substep
    transaction.activeSubstep = nil
    transaction.lastAcceptedPhysicsState = accepted
    transaction.status = .decisionReady
  }

  public func rejectPhysicsSubstep(
    _ transaction: ControlTransaction,
    receptorEvents: [BrainInterruptEvent] = []
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .substepActive)
    guard let substep = transaction.activeSubstep else {
      throw TissueError.transaction("there is no active fast candidate to reject")
    }
    try fastTissue.rejectPhysicsSubstep(substep, receptorEvents: receptorEvents)
    transaction.activeSubstep = nil
    transaction.status = .decisionReady
  }

  /// Queues the accepted fast prefix without constructing a host physical
  /// token. The fast shadow waits for the physical prepare event, remains
  /// unpublished, and signals a distinct point consumed by the cognitive
  /// consequence/end-witness command.
  public func submitProvisionalAcceptedFastRoot(
    _ transaction: ControlTransaction,
    waitFor physicalPreparedPoint: MetalSharedEventPoint,
    signal fastPreparedPoint: MetalSharedEventPoint
  ) throws -> MetalTissueRuntime.ProvisionalFastRootSubmissionTicket {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .substepActive)
    guard let substep = transaction.activeSubstep else {
      throw TissueError.transaction("there is no active fast candidate to prepare")
    }
    do {
      let ticket = try fastTissue.submitProvisionalAcceptedFastRoot(
        for: substep,
        waitFor: physicalPreparedPoint,
        signal: fastPreparedPoint
      )
      transaction.provisionalPhysicsAcceptance = ticket.provisional
      transaction.provisionalFastSubmissionIdentifier = ticket.identifier
      transaction.status = .provisionalFastSubmitted
      return ticket
    } catch {
      if fastTissue.hasOpenInteractiveJointControl {
        try? fastTissue.abortInteractiveJointControl()
      }
      try? cognitive.abort(transaction: transaction.cognitiveTransaction)
      transaction.activeSubstep = nil
      transaction.status = .aborted
      activeTransaction = nil
      throw error
    }
  }

  /// Explicit diagnostic rejection boundary. A timeout retains the complete
  /// fast ticket and both transaction halves because it is not GPU completion.
  public func abortProvisionalAcceptedFastRootSubmission(
    _ ticket: MetalTissueRuntime.ProvisionalFastRootSubmissionTicket,
    transaction: ControlTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .provisionalFastSubmitted)
    guard transaction.provisionalFastSubmissionIdentifier == ticket.identifier,
      transaction.provisionalPhysicsAcceptance == ticket.provisional
    else {
      throw TissueError.transaction("provisional complete-brain fast ticket is stale")
    }
    do {
      try fastTissue.abortProvisionalAcceptedFastRootSubmission(
        ticket,
        timeoutMilliseconds: timeoutMilliseconds
      )
    } catch {
      if fastTissue.ownsOutstandingProvisionalFastRootSubmission(ticket.identifier) {
        throw error
      }
      try? cognitive.abort(transaction: transaction.cognitiveTransaction)
      transaction.provisionalFastSubmissionIdentifier = nil
      transaction.provisionalPhysicsAcceptance = nil
      transaction.activeSubstep = nil
      transaction.status = .aborted
      activeTransaction = nil
      throw error
    }
    try? cognitive.abort(transaction: transaction.cognitiveTransaction)
    transaction.provisionalFastSubmissionIdentifier = nil
    transaction.provisionalPhysicsAcceptance = nil
    transaction.activeSubstep = nil
    transaction.status = .aborted
    activeTransaction = nil
  }

  /// Encodes the unpublished complete-brain prepare phase on the Brain-owned
  /// timeline. Cognitive consequence and the end witness wait for the exact
  /// fast-prepared point; neither this method nor its ticket reads a physical
  /// digest, waits on the host, or exposes candidate state as authority.
  public func submitNumanXPreparedControl(
    _ transaction: ControlTransaction,
    provisionalFast ticket: MetalTissueRuntime.ProvisionalFastRootSubmissionTicket,
    identity: MetalNumanXHumanMatterRootIdentity,
    acceptedPhysicsGate: MetalAcceptedPhysicsGateLease,
    sensorCandidate: MetalNumanXPendingSensorCandidateLease,
    developmentalIntents: MetalDevelopmentalCapabilityIntentBufferLease? = nil,
    teacherState: MetalTeacherStateBufferLease? = nil,
    signal brainPreparedPoint: MetalSharedEventPoint,
    thenSignal preflightReadyPoint: MetalSharedEventPoint
  ) throws -> NumanXPreparedControlTicket {
    let prepared: NumanXPreparedControlTicket
    lock.lock()
    do {
      prepared = try makeNumanXPreparedControlLocked(
        transaction,
        provisionalFast: ticket,
        identity: identity,
        acceptedPhysicsGate: acceptedPhysicsGate,
        sensorCandidate: sensorCandidate,
        developmentalIntents: developmentalIntents,
        teacherState: teacherState,
        signal: brainPreparedPoint,
        thenSignal: preflightReadyPoint
      )
      lock.unlock()
    } catch {
      lock.unlock()
      throw error
    }

    // Both feedback handlers are registered only after releasing the runtime's
    // nonrecursive lock. Registration is allowed to invoke synchronously when
    // Metal completion won the race.
    activateNumanXPrepareFeedbackLatch(prepared)
    return prepared
  }

  private func makeNumanXPreparedControlLocked(
    _ transaction: ControlTransaction,
    provisionalFast ticket: MetalTissueRuntime.ProvisionalFastRootSubmissionTicket,
    identity: MetalNumanXHumanMatterRootIdentity,
    acceptedPhysicsGate: MetalAcceptedPhysicsGateLease,
    sensorCandidate: MetalNumanXPendingSensorCandidateLease,
    developmentalIntents: MetalDevelopmentalCapabilityIntentBufferLease?,
    teacherState: MetalTeacherStateBufferLease?,
    signal brainPreparedPoint: MetalSharedEventPoint,
    thenSignal preflightReadyPoint: MetalSharedEventPoint
  ) throws -> NumanXPreparedControlTicket {
    try requireActive(transaction, status: .provisionalFastSubmitted)
    guard transaction.provisionalFastSubmissionIdentifier == ticket.identifier,
      transaction.provisionalPhysicsAcceptance == ticket.provisional,
      fastTissue.ownsOutstandingProvisionalFastRootSubmission(ticket.identifier),
      identity.transactionFingerprint == transaction.token.fingerprint,
      identity.environment == transaction.token.environmentIdentifier,
      identity.controlStep == ticket.provisional.controlStep,
      identity.substepIndex == ticket.provisional.substepIndex,
      identity.physicsSubstepCount == 1,
      let substep = transaction.activeSubstep,
      substep.fingerprint == ticket.provisional.substepFingerprint,
      (preflightReadyPoint.event as AnyObject)
        !== (brainPreparedPoint.event as AnyObject),
      (preflightReadyPoint.event as AnyObject)
        !== (ticket.completionPoint.event as AnyObject),
      (preflightReadyPoint.event as AnyObject)
        !== (ticket.waitPoint.event as AnyObject)
    else {
      throw TissueError.transaction(
        "NumanX complete-brain prepare requires an exact root and distinct preflight event"
      )
    }
    try sensorCandidate.validate(
      identity: identity,
      provisional: ticket.provisional,
      deviceRegistryID: deviceRegistryID
    )
    if let developmentalIntents {
      guard developmentalIntents.view.timestamp == transaction.token.targetTimestamp
      else {
        throw TissueError.transaction(
          "developmental intents do not belong to the prepared NumanX root"
        )
      }
      try developmentalIntents.validate(deviceRegistryID: deviceRegistryID)
    }

    let fastSources = try fastTissue.makeNumanXPreparedFastStateSources(
      for: ticket
    )
    let fastPrepareStatus = try fastTissue.numanXFastPrepareStatus(for: ticket)
    let request = try MetalNumanXBrainCommitPrepareRequest(
      identity: identity,
      provisionalPhysicsAcceptance: ticket.provisional,
      fastPrepareStatus: fastPrepareStatus,
      fastStateSources: fastSources
    )
    let preflightResources = try NumanXBrainCommitPreflightResources(
      fastTissue: fastTissue,
      brainPreparedPoint: brainPreparedPoint,
      readyPoint: preflightReadyPoint,
      identity: identity,
      provisional: ticket.provisional,
      fastProgramFingerprint: fastPrepareStatus.fastProgramFingerprint,
      brainProgramFingerprint: cognitive.numanXBrainProgramFingerprint
    )
    if let retained = transaction.provisionalFastMotorState {
      guard retained.transactionFingerprint == transaction.token.fingerprint,
        retained.acceptedTimestamp == transaction.token.targetTimestamp
      else {
        throw TissueError.transaction(
          "retained provisional fast motor state is stale"
        )
      }
    } else {
      let retained = try fastTissue.borrowPreparedAcceptedFastMotorState(
        for: transaction.token
      )
      try transaction.cognitiveTransaction.bindAcceptedFastMotorState(retained)
      transaction.provisionalFastMotorState = retained
    }

    let acceptedRegionalRecurrent = try fastTissue
      .pendingRegionalRecurrentBufferView()
    let cognitiveTicket: MetalEmbodiedBrainRuntime
      .AcceptedConsequenceSubmissionTicket
    do {
      cognitiveTicket = try cognitive.submitAcceptedConsequence(
        transaction: transaction.cognitiveTransaction,
        candidateSubstep: substep,
        acceptedPhysicsGate: acceptedPhysicsGate,
        rawSensors: sensorCandidate.rawSensors,
        acceptedRegionalRecurrentInput: acceptedRegionalRecurrent,
        developmentalIntents: developmentalIntents,
        teacherState: teacherState,
        numanXRootPrepare: request,
        waitFor: ticket.completionPoint,
        signal: brainPreparedPoint
      )
    } catch {
      // The reserved terminal point must not strand an already-queued owner
      // wait. PENDING remains authoritative and makes ACK reject.
      preflightResources.signalReady()
      throw error
    }
    guard let witnessAddress = cognitiveTicket
      .numanXBrainCommitWitnessGPUAddress,
      let witnessByteCount = cognitiveTicket.numanXBrainCommitWitnessByteCount,
      let witnessObject = cognitiveTicket
        .numanXBrainCommitWitnessMetalBufferObject,
      let brainProgramFingerprint = cognitiveTicket
        .numanXBrainProgramFingerprint
    else {
      preconditionFailure(
        "NumanX low-level prepare omitted its required Brain witness"
      )
    }
    let identifier = UUID()
    let prepareFeedbackLatch = MetalNumanXPrepareFeedbackLatch()
    transaction.numanXPreparedSubmissionIdentifier = identifier
    transaction.status = .numanXPrepareSubmitted
    let prepared = NumanXPreparedControlTicket(
      identifier: identifier,
      owner: self,
      transaction: transaction,
      identity: identity,
      fastTicket: ticket,
      sensorCandidate: sensorCandidate,
      cognitiveTicket: cognitiveTicket,
      brainCommitWitnessGPUAddress: witnessAddress,
      brainCommitWitnessByteCount: witnessByteCount,
      brainCommitWitnessMetalBufferObject: witnessObject,
      brainProgramFingerprint: brainProgramFingerprint,
      preflightResources: preflightResources,
      prepareFeedbackLatch: prepareFeedbackLatch
    )
    activeNumanXPreparedTicket = prepared
    return prepared
  }

  private func activateNumanXPrepareFeedbackLatch(
    _ ticket: NumanXPreparedControlTicket
  ) {
    do {
      try ticket.prepareFeedbackLatch.installHandler {
        [self, ticket] fast, cognitive in
        // This callback is deliberately outside both feedback locks and the
        // runtime lock. All failure publication is compact PENDING + liveness.
        _ = try? prepareNumanXCommitPreflight(
          ticket,
          terminalFastFeedback: fast,
          terminalCognitiveFeedback: cognitive,
          expectedAcceptedPhysicsState: nil
        )
      }
      try ticket.fastTicket.registerTerminalFeedbackHandler {
        [ticket] in
        ticket.prepareFeedbackLatch.recordFast(
          Self.captureNumanXTerminalFeedback {
            try ticket.fastTicket.completionFeedbackIfAvailable()
          }
        )
      }
      try ticket.cognitiveTicket.registerTerminalFeedbackHandler {
        [ticket] in
        ticket.prepareFeedbackLatch.recordCognitive(
          Self.captureNumanXTerminalFeedback {
            try ticket.cognitiveTicket.completionFeedbackIfAvailable()
          }
        )
      }
    } catch {
      // A registration collision is an internal ownership violation. Preserve
      // the returned aggregate handle and signal a PENDING terminal record so
      // owner ACK fails closed and the caller can explicitly abort it.
      lock.lock()
      if activeTransaction === ticket.transaction,
        ticket.transaction.status == .numanXPrepareSubmitted
      {
        ticket.transaction.status = .numanXPreflightFailed
        ticket.preflightFailureDescriptionStorage = String(describing: error)
      }
      lock.unlock()
      ticket.prepareFeedbackLatch.cancel()
      ticket.preflightResources.signalReady()
    }
  }

  private static func captureNumanXTerminalFeedback(
    _ poll: () throws -> MetalGPUCompletionFeedback?
  ) -> MetalNumanXPrepareTerminalFeedback {
    do {
      guard let feedback = try poll() else {
        return .failure(
          "NumanX terminal feedback callback observed a nonterminal state"
        )
      }
      return .success(feedback)
    } catch {
      return .failure(String(describing: error))
    }
  }

  /// Diagnostic/teardown boundary before an owner application is queued.
  /// A timeout is not cancellation: both prepared halves and all borrowed
  /// leases remain quarantined until cognitive Metal feedback is terminal.
  public func abortNumanXPreparedControl(
    _ ticket: NumanXPreparedControlTicket,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    let transaction = ticket.transaction
    guard activeTransaction === transaction,
      activeNumanXPreparedTicket === ticket,
      transaction.status == .numanXPrepareSubmitted
        || transaction.status == .numanXPreflightReady
        || transaction.status == .numanXPreflightFailed
    else {
      throw TissueError.transaction(
        "NumanX prepared-control transaction is stale or already closing"
      )
    }
    guard transaction.numanXPreparedSubmissionIdentifier == ticket.identifier,
      transaction.provisionalFastSubmissionIdentifier
        == ticket.fastTicket.identifier,
      transaction.provisionalPhysicsAcceptance
        == ticket.provisionalPhysicsAcceptance
    else {
      throw TissueError.transaction("NumanX prepared-control ticket is stale")
    }
    do {
      try cognitive.abortAcceptedConsequenceSubmission(
        ticket.cognitiveTicket,
        transaction: transaction.cognitiveTransaction,
        timeoutMilliseconds: timeoutMilliseconds
      )
    } catch {
      guard !cognitive.ownsOutstandingSubmission(
        ticket.cognitiveTicket.identifier
      ) else {
        throw error
      }
      ticket.preflightResources.signalReady()
      finishNumanXCognitiveAbort(transaction.cognitiveTransaction)
      fastTissue.discardResolvedProvisionalFastRootSubmission(
        ticket.fastTicket
      )
      finishNumanXAbort(transaction)
      throw error
    }
    ticket.preflightResources.signalReady()
    finishNumanXCognitiveAbort(transaction.cognitiveTransaction)
    fastTissue.discardResolvedProvisionalFastRootSubmission(ticket.fastTicket)
    finishNumanXAbort(transaction)
  }

  /// Queues the mutation-free Brain ACK against the exact retained physical
  /// proposal and the distinct Brain preflight point. The owner publication
  /// fence is bound here, before ACK, and can never be replaced afterward.
  /// Callback registration occurs after this runtime lock is released.
  @discardableResult
  func submitNumanXBrainAck(
    _ ticket: NumanXPreparedControlTicket,
    proposal: MetalNumanXHumanMatterProposalLease,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> MetalNumanXHumanMatterBrainAckTicket {
    let preflight: MetalNumanXHumanMatterBrainPreflightLease
    lock.lock()
    do {
      let transaction = ticket.transaction
      guard activeTransaction === transaction,
        activeNumanXPreparedTicket === ticket,
        transaction.numanXPreparedSubmissionIdentifier == ticket.identifier,
        transaction.status == .numanXPrepareSubmitted
          || transaction.status == .numanXPreflightReady
          || transaction.status == .numanXPreflightFailed,
        proposal.identity == ticket.identity,
        ticket.brainAckTicket == nil,
        !ticket.brainAckSubmissionReserved
      else {
        throw TissueError.transaction(
          "NumanX Brain ACK proposal is stale or duplicated"
        )
      }
      try bindNumanXOwnerPublicationFenceLocked(ticket, proposal: proposal)
      preflight = try MetalNumanXHumanMatterBrainPreflightLease(
        identity: ticket.identity,
        buffer: ticket.preflightResources.buffer,
        gpuAddress: ticket.preflightResources.buffer.gpuAddress,
        candidatePublicationFingerprint:
          ticket.sensorCandidate.candidatePublicationFingerprint,
        humanIOIdentityFingerprint:
          ticket.sensorCandidate.candidateIdentityFingerprint,
        readyPoint: ticket.preflightResources.readyPoint
      )
      ticket.brainAckSubmissionReserved = true
      transaction.status = .numanXAckSubmitted
      lock.unlock()
    } catch {
      lock.unlock()
      throw error
    }

    let ackTicket: MetalNumanXHumanMatterBrainAckTicket
    do {
      ackTicket = try cognitive.submitNumanXBrainAck(
        prepared: ticket.cognitiveTicket,
        proposal: proposal,
        preflight: preflight,
        signal: completionPoint
      )
    } catch {
      lock.lock()
      if activeNumanXPreparedTicket === ticket,
        ticket.brainAckSubmissionReserved,
        ticket.brainAckTicket == nil
      {
        ticket.brainAckSubmissionReserved = false
        if ticket.preparedPublication != nil {
          ticket.transaction.status = .numanXPreflightReady
        } else if ticket.preflightResources.hasSignaledReady {
          ticket.transaction.status = .numanXPreflightFailed
        } else {
          ticket.transaction.status = .numanXPrepareSubmitted
        }
      }
      lock.unlock()
      throw error
    }

    lock.lock()
    guard activeNumanXPreparedTicket === ticket,
      ticket.brainAckSubmissionReserved,
      ticket.brainAckTicket == nil
    else {
      lock.unlock()
      preconditionFailure("NumanX Brain ACK lost aggregate ownership")
    }
    ticket.brainAckSubmissionReserved = false
    ticket.brainAckTicket = ackTicket
    lock.unlock()

    do {
      try ackTicket.onCompleted { [self, ticket, ackTicket] completion in
        recordNumanXBrainAckCompletion(
          ticket, ackTicket: ackTicket, completion: completion
        )
      }
    } catch {
      lock.lock()
      if activeNumanXPreparedTicket === ticket {
        ticket.transaction.status = .terminalQuarantined
      }
      lock.unlock()
      throw error
    }
    return ackTicket
  }

  /// Submits the nonpublishing applied-root validator only after the owner has
  /// settled its apply disposition and the bridge has fallibly reserved every
  /// range and the HumanIO candidate resolution. ACCEPT publication happens
  /// solely from the exactly-once completion callback below.
  @discardableResult
  func validateNumanXAppliedRoot(
    _ ticket: NumanXPreparedControlTicket,
    ack ackTicket: MetalNumanXHumanMatterBrainAckTicket,
    applied: MetalNumanXHumanMatterAppliedLease,
    resolution: MetalNumanXJointResolutionReservation,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> MetalNumanXHumanMatterAppliedValidationTicket {
    lock.lock()
    do {
      guard activeTransaction === ticket.transaction,
        activeNumanXPreparedTicket === ticket,
        ticket.brainAckTicket === ackTicket,
        ackTicket.proposalLease.identity == ticket.identity,
        applied.identity == ticket.identity,
        ticket.transaction.status == .numanXAckSubmitted
          || ticket.transaction.status
            == .numanXAppliedValidationRetryRequired,
        !ticket.appliedValidationSubmissionReserved,
        ticket.appliedValidationTicket == nil
      else {
        throw TissueError.transaction(
          "NumanX applied validation is stale, duplicated, or lacks preflight"
        )
      }
      try resolution.validate(
        proposal: ackTicket.proposalLease,
        applied: applied,
        sensorCandidate: ticket.sensorCandidate,
        jointCommitFingerprint:
          ticket.preparedPublication?.jointCommitFingerprint ?? 0,
        brainGeneration: ticket.provisionalPhysicsAcceptance.shadowGeneration
      )
      ticket.appliedValidationSubmissionReserved = true
      ticket.jointResolutionReservation = resolution
      ticket.transaction.status = .numanXApplySubmitted
      lock.unlock()
    } catch {
      lock.unlock()
      throw error
    }

    let validationTicket: MetalNumanXHumanMatterAppliedValidationTicket
    do {
      validationTicket = try cognitive.validateNumanXAppliedRoot(
        ack: ackTicket,
        applied: applied,
        signal: completionPoint
      )
    } catch {
      lock.lock()
      if activeNumanXPreparedTicket === ticket,
        ticket.appliedValidationSubmissionReserved,
        ticket.appliedValidationTicket == nil
      {
        ticket.appliedValidationSubmissionReserved = false
        ticket.jointResolutionReservation = nil
        ticket.transaction.status = .numanXAppliedValidationRetryRequired
      }
      lock.unlock()
      throw error
    }

    lock.lock()
    guard activeNumanXPreparedTicket === ticket,
      ticket.appliedValidationSubmissionReserved,
      ticket.appliedValidationTicket == nil
    else {
      lock.unlock()
      preconditionFailure("NumanX applied validation lost aggregate ownership")
    }
    ticket.appliedValidationSubmissionReserved = false
    ticket.appliedValidationTicket = validationTicket
    lock.unlock()

    do {
      try validationTicket.onCompleted {
        [self, ticket, validationTicket] completion in
        finishNumanXAppliedValidation(
          ticket,
          validationTicket: validationTicket,
          completion: completion
        )
      }
    } catch {
      lock.lock()
      if activeNumanXPreparedTicket === ticket {
        ticket.transaction.status = .terminalQuarantined
      }
      lock.unlock()
      throw error
    }
    return validationTicket
  }

  private func recordNumanXBrainAckCompletion(
    _ ticket: NumanXPreparedControlTicket,
    ackTicket: MetalNumanXHumanMatterBrainAckTicket,
    completion: MetalNumanXHumanMatterBrainAckCompletion
  ) {
    lock.lock()
    defer { lock.unlock() }
    guard activeNumanXPreparedTicket === ticket,
      ticket.brainAckTicket === ackTicket,
      ticket.brainAckCompletion == nil
    else { return }
    ticket.brainAckCompletion = completion
  }

  private func finishNumanXAppliedValidation(
    _ ticket: NumanXPreparedControlTicket,
    validationTicket: MetalNumanXHumanMatterAppliedValidationTicket,
    completion: MetalNumanXHumanMatterAppliedCompletion
  ) {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction === ticket.transaction,
      activeNumanXPreparedTicket === ticket,
      ticket.appliedValidationTicket === validationTicket,
      ticket.transaction.status == .numanXApplySubmitted,
      let resolution = ticket.jointResolutionReservation
    else { return }

    guard completion.status == .completed,
      let validation = completion.validation
    else {
      ticket.appliedValidationTicket = nil
      ticket.jointResolutionReservation = nil
      ticket.transaction.status = completion.status == .gpuFailure
        ? .numanXAppliedValidationRetryRequired : .terminalQuarantined
      return
    }

    switch validation.status {
    case .accept:
      guard completion.permitsJointPublication,
        let accepted = completion.acceptedPhysicsState,
        let prepared = ticket.preparedPublication,
        let startAccepted = ticket.acceptedPhysicsState,
        accepted == startAccepted,
        validation.identity == ticket.identity,
        validation.physicsTokenFingerprint == accepted.fingerprint,
        validation.brainProgramFingerprint == ticket.brainProgramFingerprint,
        validation.fastTargetGeneration == prepared.fast.receipt.brainGeneration,
        validation.cognitiveTargetGeneration
          == prepared.cognitive.agentStateToken.shadowGeneration,
        validation.jointCommitFingerprint
          == prepared.jointCommitFingerprint,
        validation.substepFingerprint
          == ticket.provisionalPhysicsAcceptance.substepFingerprint,
        validation.appliedDecisionFingerprint > 0,
        validation.brainShadowStateFingerprint > 0,
        validation.brainWitnessFingerprint > 0,
        let fence = ticket.publicationFenceResources,
        (fence.buffer as AnyObject)
          === (validationTicket.ackTicket.proposalLease
            .publicationFenceBuffer as AnyObject),
        fence.byteOffset == validationTicket.ackTicket.proposalLease
          .publicationFenceByteOffset
      else {
        ticket.transaction.status = .terminalQuarantined
        return
      }

      let targetGeneration = prepared.fast.receipt.brainGeneration
      guard fence.prepareCommittedRecord(
        physicsTokenFingerprint: accepted.fingerprint,
        brainShadowStateFingerprint: validation.brainShadowStateFingerprint,
        brainWitnessFingerprint: validation.brainWitnessFingerprint,
        appliedDecisionFingerprint: validation.appliedDecisionFingerprint,
        jointCommitFingerprint: validation.jointCommitFingerprint,
        brainGeneration: targetGeneration
      ) else {
        ticket.transaction.status = .terminalQuarantined
        return
      }
      let priorPublishedGeneration = publishedGeneration
      let publicationCallback = ticket.publicationCallbackState
      let publishBrainGeneration:
        MetalNumanXJointResolutionReservation.PublishBrainGeneration = {
          [self, publicationCallback] in
          let accepted = publicationCallback.markInvoked()
          if accepted { publishedGeneration = targetGeneration }
          return accepted
        }

      // From this point through external release there are no throwing calls.
      // The callback object, closure capture, and complete fence bytes were
      // allocated/prepared above. Private fast/cognitive pointers flip under
      // this lock, followed only by a fixed-size memcpy and the exact bridge
      // callback. Only successful combined Matter + HumanIO release makes the
      // public Brain generation observable.
      publishPreparedComponentPointers(prepared)
      fence.copyPreparedCommittedRecord()
      let releaseDisposition = resolution.releaseAccepted(
        publishingBrainGeneration: publishBrainGeneration
      )
      guard releaseDisposition == .released,
        publicationCallback.invocationCount > 0
      else {
        // A release capability may not expose physical/sensor state without
        // invoking the Brain generation callback while holding its shared
        // publication gate. Fail closed if that nonthrow contract is broken.
        publishedGeneration = priorPublishedGeneration
        ticket.transaction.status = .terminalQuarantined
        return
      }
      ticket.publicationProtocolViolationDetected =
        publicationCallback.invocationCount != 1
      ticket.qualificationOutcome = .accepted
      ticket.qualificationAppliedRecordFingerprint =
        validation.appliedDecisionFingerprint
      ticket.qualificationJointCommitFingerprint =
        validation.jointCommitFingerprint
      fastTissue.releaseResolvedProvisionalFastRootSubmission(ticket.fastTicket)
      cognitive.releaseResolvedNumanXPreparedSubmission(
        ticket.cognitiveTicket,
        transaction: ticket.transaction.cognitiveTransaction
      )
      ticket.transaction.lastAcceptedPhysicsState = accepted
      finishNumanXPublicationSuccess(
        ticket,
        brainGeneration: targetGeneration
      )

    case .reject:
      guard validation.commandDisposition == .rejectedReleased,
        resolution.releaseRejected() == .released
      else {
        ticket.transaction.status = .terminalQuarantined
        return
      }
      ticket.qualificationOutcome = .rejected
      ticket.qualificationAppliedRecordFingerprint =
        validation.appliedDecisionFingerprint
      ticket.qualificationJointCommitFingerprint = 0
      finishResolvedNumanXRejection(ticket)

    case .terminalNoTouch, .invalid:
      ticket.transaction.status = .terminalQuarantined
    }
  }

  /// Callback entrypoint for the production prepare phase. It never waits:
  /// both queue feedback records must already be terminal. Every throwing
  /// journal, receipt, anatomy, layout, and generation check completes before
  /// the shared preflight record changes from PENDING to SUCCESS.
  @discardableResult
  func prepareNumanXCommitPreflight(
    _ ticket: NumanXPreparedControlTicket,
    acceptedPhysicsState: AcceptedPhysicsStateToken
  ) throws -> BrainJointCommitToken {
    try prepareNumanXCommitPreflight(
      ticket,
      terminalFastFeedback: Self.captureNumanXTerminalFeedback {
        try ticket.fastTicket.completionFeedbackIfAvailable()
      },
      terminalCognitiveFeedback: Self.captureNumanXTerminalFeedback {
        try ticket.cognitiveTicket.completionFeedbackIfAvailable()
      },
      expectedAcceptedPhysicsState: acceptedPhysicsState
    )
  }

  @discardableResult
  private func prepareNumanXCommitPreflight(
    _ ticket: NumanXPreparedControlTicket,
    terminalFastFeedback: MetalNumanXPrepareTerminalFeedback,
    terminalCognitiveFeedback: MetalNumanXPrepareTerminalFeedback,
    expectedAcceptedPhysicsState: AcceptedPhysicsStateToken?
  ) throws -> BrainJointCommitToken {
    lock.lock()
    defer { lock.unlock() }
    let transaction = ticket.transaction
    guard activeTransaction === transaction,
      activeNumanXPreparedTicket === ticket,
      transaction.status == .numanXPrepareSubmitted
        || transaction.status == .numanXAckSubmitted,
      transaction.numanXPreparedSubmissionIdentifier == ticket.identifier,
      transaction.provisionalFastSubmissionIdentifier
        == ticket.fastTicket.identifier,
      transaction.provisionalPhysicsAcceptance
        == ticket.provisionalPhysicsAcceptance,
      ticket.acceptedPhysicsState == nil,
      ticket.preparedPublication == nil
    else {
      throw TissueError.transaction(
        "NumanX Brain-commit preflight ticket is stale or duplicated"
      )
    }

    do {
      guard terminalFastFeedback.failureDescription == nil,
        terminalCognitiveFeedback.failureDescription == nil
      else {
        throw TissueError.transaction(
          "NumanX Brain-commit preflight requires two successful GPU submissions: "
            + (terminalFastFeedback.failureDescription
              ?? terminalCognitiveFeedback.failureDescription
              ?? "unknown terminal failure")
        )
      }
      let acceptedPhysicsState = try ticket.cognitiveTicket.gateEvaluation
        .validateAcceptedResult()
      guard expectedAcceptedPhysicsState == nil
        || acceptedPhysicsState == expectedAcceptedPhysicsState
      else {
        throw TissueError.transaction(
          "NumanX prepared token differs from the GPU gate result"
        )
      }
      try transaction.cognitiveTransaction.finishProvisionalGPUState(
        acceptedPhysicsState: acceptedPhysicsState,
        provisional: ticket.provisionalPhysicsAcceptance
      )
      let fast = try fastTissue.prepareProvisionalJointRootTransactionCommit(
        acceptedPhysicsState: acceptedPhysicsState,
        provisional: ticket.provisionalPhysicsAcceptance
      )
      // The prepared async submission intentionally remains retained through
      // ACK/apply. Its feedback is already terminal, so perform the same exact
      // transaction-level receipt/arena preflight without the compatibility
      // helper's "no active submission" teardown guard.
      try transaction.cognitiveTransaction.prepareCommit(
        with: fast.receipt
      )
      let publication = PreparedAtomicJointPublication(
        fast: fast,
        cognitive: transaction.cognitiveTransaction,
        jointCommitFingerprint:
          MetalNumanXPendingSensorCandidateLease.jointCloseFingerprint(
            receiptFingerprint: fast.receipt.fingerprint,
            sensorCandidateFingerprint:
              ticket.sensorCandidate.publicationFingerprint
          )
      )
      ticket.acceptedPhysicsState = acceptedPhysicsState
      ticket.preparedPublication = publication
      ticket.preflightResources.recordSuccess(
        acceptedPhysicsState: acceptedPhysicsState,
        fastTargetGeneration: fast.receipt.brainGeneration,
        cognitiveTargetGeneration:
          transaction.cognitiveTransaction.agentStateToken.shadowGeneration,
        jointReceiptFingerprint: publication.jointCommitFingerprint
      )
      if transaction.status == .numanXPrepareSubmitted {
        transaction.status = .numanXPreflightReady
      }
      ticket.preflightResources.signalReady()
      return fast.receipt
    } catch {
      if transaction.status == .numanXPrepareSubmitted {
        transaction.status = .numanXPreflightFailed
      }
      ticket.preflightFailureDescriptionStorage = String(describing: error)
      ticket.preflightResources.signalReady()
      throw error
    }
  }

  /// Finalizes accepted consequences, applies memory journals, and publishes
  /// fast and complete-agent generations from the same joint receipt.
  public func commitControl(
    _ transaction: ControlTransaction,
    acceptedSensors: NumanXSensorPacketLease,
    schedulerEvents: [BrainInterruptEvent] = [],
    developmentalEvidence: MetalDevelopmentalEvidenceBufferLease? = nil,
    teacherState: MetalTeacherStateBufferLease? = nil
  ) throws -> CommitResult {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .decisionReady)
    guard let decision = transaction.decision,
      let accepted = transaction.lastAcceptedPhysicsState,
      accepted.acceptedTimestamp == transaction.token.targetTimestamp
    else {
      throw TissueError.transaction(
        "joint commit requires a decision and accepted physics at the root target"
      )
    }

    var fastPrepared = false
    do {
      let submission = try fastTissue.finishInteractiveJointControl(
        schedulerEvents: schedulerEvents
      )
      fastPrepared = true
      let acceptedFastMotorState = try fastTissue.borrowPreparedAcceptedFastMotorState(
        for: transaction.token
      )
      try cognitive.importAcceptedFastMotorState(
        acceptedFastMotorState,
        transaction: transaction.cognitiveTransaction
      )
      let acceptedRegionalRecurrent = try fastTissue.pendingRegionalRecurrentBufferView()
      let consequence = try cognitive.finalizeAcceptedControl(
        transaction: transaction.cognitiveTransaction,
        acceptedPhysicsState: accepted,
        numanXSensors: acceptedSensors,
        acceptedRegionalRecurrentInput: acceptedRegionalRecurrent,
        developmentalEvidence: developmentalEvidence,
        teacherState: teacherState
      )
      guard transaction.cognitiveTransaction.status == .gpuStateFinished,
        transaction.cognitiveTransaction.acceptedPhysicsTokenFingerprint
          == accepted.fingerprint
      else {
        throw TissueError.transaction(
          "complete agent state did not finish the accepted joint generation"
        )
      }
      let preparedPublication = try prepareAtomicJointPublication(
        fast: fastTissue.prepareJointRootTransactionCommit(),
        cognitive: transaction.cognitiveTransaction
      )
      publishAtomicJointPublication(
        preparedPublication,
        transaction: transaction
      )
      return CommitResult(
        receipt: preparedPublication.fast.receipt,
        decision: decision,
        acceptedConsequence: consequence,
        fastSubmission: submission
      )
    } catch {
      if fastPrepared {
        try? fastTissue.abortRootTransaction()
      } else if fastTissue.hasOpenInteractiveJointControl {
        try? fastTissue.abortInteractiveJointControl()
      }
      if transaction.cognitiveTransaction.status == .open
        || transaction.cognitiveTransaction.status == .gpuStateFinished
        || transaction.cognitiveTransaction.status == .commitPrepared
      {
        try? cognitive.abort(transaction: transaction.cognitiveTransaction)
      }
      transaction.activeSubstep = nil
      transaction.status = .aborted
      activeTransaction = nil
      throw error
    }
  }

  /// Prepares the already-accepted fast root and submits accepted cognitive
  /// consequences without a host GPU wait. Scheduler events are deliberately
  /// absent from this path: they must have entered accepted substeps before
  /// submission so root finalization does not require a separate synchronous
  /// fast-tissue command buffer.
  public func submitAcceptedControl(
    _ transaction: ControlTransaction,
    acceptedPhysicsGate: MetalAcceptedPhysicsGateLease,
    acceptedSensors: NumanXSensorPacketLease,
    developmentalEvidence: MetalDevelopmentalEvidenceBufferLease? = nil,
    teacherState: MetalTeacherStateBufferLease? = nil,
    waitFor waitPoint: MetalSharedEventPoint? = nil,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> CommitSubmissionTicket {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .decisionReady)
    guard let decision = transaction.decision,
      let accepted = transaction.lastAcceptedPhysicsState,
      let acceptedSubstep = transaction.lastAcceptedSubstep,
      accepted.acceptedTimestamp == transaction.token.targetTimestamp
    else {
      throw TissueError.transaction(
        "async joint commit requires a decision and accepted target physics"
      )
    }

    var fastPrepared = false
    do {
      let submission = try fastTissue.finishInteractiveJointControl()
      fastPrepared = true
      let acceptedFastMotorState = try fastTissue.borrowPreparedAcceptedFastMotorState(
        for: transaction.token
      )
      try transaction.cognitiveTransaction.bindAcceptedFastMotorState(
        acceptedFastMotorState
      )
      let acceptedRegionalRecurrent = try fastTissue.pendingRegionalRecurrentBufferView()
      let cognitiveTicket = try cognitive.submitAcceptedConsequence(
        transaction: transaction.cognitiveTransaction,
        acceptedPhysicsState: accepted,
        candidateSubstep: acceptedSubstep,
        acceptedPhysicsGate: acceptedPhysicsGate,
        numanXSensors: acceptedSensors,
        acceptedRegionalRecurrentInput: acceptedRegionalRecurrent,
        developmentalEvidence: developmentalEvidence,
        teacherState: teacherState,
        waitFor: waitPoint,
        signal: completionPoint
      )
      let identifier = UUID()
      transaction.asyncSubmissionIdentifier = identifier
      transaction.status = .acceptedConsequenceSubmitted
      return CommitSubmissionTicket(
        identifier: identifier,
        owner: self,
        decision: decision,
        acceptedPhysicsState: accepted,
        fastSubmission: submission,
        cognitiveTicket: cognitiveTicket
      )
    } catch {
      if fastPrepared {
        try? fastTissue.abortRootTransaction()
      } else if fastTissue.hasOpenInteractiveJointControl {
        try? fastTissue.abortInteractiveJointControl()
      }
      if transaction.cognitiveTransaction.status == .open
        || transaction.cognitiveTransaction.status == .gpuStateFinished
        || transaction.cognitiveTransaction.status == .commitPrepared
      {
        try? cognitive.abort(transaction: transaction.cognitiveTransaction)
      }
      transaction.asyncSubmissionIdentifier = nil
      transaction.activeSubstep = nil
      transaction.status = .aborted
      activeTransaction = nil
      throw error
    }
  }

  public func finishAcceptedControlSubmission(
    _ ticket: CommitSubmissionTicket,
    transaction: ControlTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws -> CommitResult {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .acceptedConsequenceSubmitted)
    guard transaction.asyncSubmissionIdentifier == ticket.identifier,
      ticket.acceptedPhysicsState == transaction.lastAcceptedPhysicsState,
      ticket.decision == transaction.decision
    else {
      throw TissueError.transaction("async complete-brain commit ticket is stale")
    }
    do {
      _ = try cognitive.finishAcceptedConsequenceSubmission(
        ticket.cognitiveTicket,
        transaction: transaction.cognitiveTransaction,
        acceptedPhysicsState: ticket.acceptedPhysicsState,
        timeoutMilliseconds: timeoutMilliseconds
      )
      guard transaction.cognitiveTransaction.status == .gpuStateFinished,
        transaction.cognitiveTransaction.acceptedPhysicsTokenFingerprint
          == ticket.acceptedPhysicsState.fingerprint
      else {
        throw TissueError.transaction(
          "complete agent state did not finish the accepted async generation"
        )
      }
      let preparedPublication = try prepareAtomicJointPublication(
        fast: fastTissue.prepareJointRootTransactionCommit(),
        cognitive: transaction.cognitiveTransaction
      )
      transaction.asyncSubmissionIdentifier = nil
      publishAtomicJointPublication(
        preparedPublication,
        transaction: transaction
      )
      return CommitResult(
        receipt: preparedPublication.fast.receipt,
        decision: ticket.decision,
        acceptedConsequence: ticket.consequence,
        fastSubmission: ticket.fastSubmission
      )
    } catch {
      if cognitive.ownsOutstandingSubmission(ticket.cognitiveTicket.identifier) {
        throw error
      }
      try? fastTissue.abortRootTransaction()
      if transaction.cognitiveTransaction.status == .open
        || transaction.cognitiveTransaction.status == .gpuStateFinished
        || transaction.cognitiveTransaction.status == .commitPrepared
      {
        try? cognitive.abort(transaction: transaction.cognitiveTransaction)
      }
      transaction.asyncSubmissionIdentifier = nil
      transaction.activeSubstep = nil
      transaction.status = .aborted
      activeTransaction = nil
      throw error
    }
  }

  public func abortAcceptedControlSubmission(
    _ ticket: CommitSubmissionTicket,
    transaction: ControlTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .acceptedConsequenceSubmitted)
    guard transaction.asyncSubmissionIdentifier == ticket.identifier else {
      throw TissueError.transaction("async complete-brain commit ticket is stale")
    }
    do {
      try cognitive.abortAcceptedConsequenceSubmission(
        ticket.cognitiveTicket,
        transaction: transaction.cognitiveTransaction,
        timeoutMilliseconds: timeoutMilliseconds
      )
    } catch {
      if cognitive.ownsOutstandingSubmission(ticket.cognitiveTicket.identifier) {
        throw error
      }
      try? fastTissue.abortRootTransaction()
      transaction.asyncSubmissionIdentifier = nil
      transaction.activeSubstep = nil
      transaction.status = .aborted
      activeTransaction = nil
      throw error
    }
    try? fastTissue.abortRootTransaction()
    transaction.asyncSubmissionIdentifier = nil
    transaction.activeSubstep = nil
    transaction.status = .aborted
    activeTransaction = nil
  }

  public func abortControl(_ transaction: ControlTransaction) throws {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction === transaction,
      transaction.status == .open || transaction.status == .decisionReady
        || transaction.status == .substepActive
    else {
      throw TissueError.transaction("brain control is not active")
    }
    abortLocked(transaction)
  }

  private func requireActive(
    _ transaction: ControlTransaction,
    status: ControlTransaction.Status
  ) throws {
    guard activeTransaction === transaction, transaction.status == status else {
      throw TissueError.transaction(
        "brain control transaction is stale or in state \(transaction.status)"
      )
    }
  }

  private func numanXPreparedControlStatus(
    _ ticket: NumanXPreparedControlTicket
  ) -> ControlTransaction.Status {
    lock.lock()
    defer { lock.unlock() }
    return ticket.transaction.status
  }

  private func numanXPreparedPreflightFailureDescription(
    _ ticket: NumanXPreparedControlTicket
  ) -> String? {
    lock.lock()
    defer { lock.unlock() }
    guard activeNumanXPreparedTicket === ticket else { return nil }
    return ticket.preflightFailureDescriptionStorage
  }

  private func numanXQualificationRootExecution(
    _ ticket: NumanXPreparedControlTicket,
    sampleSHA256: String
  ) throws -> BrainPolicyNumanXRootExecution {
    lock.lock()
    defer { lock.unlock() }
    let identity = ticket.identity
    guard let outcome = ticket.qualificationOutcome,
      (outcome == .accepted && ticket.transaction.status == .committed)
        || (outcome == .rejected && ticket.transaction.status == .aborted),
      ticket.qualificationAppliedRecordFingerprint > 0,
      outcome == .accepted
        ? ticket.qualificationJointCommitFingerprint > 0
        : ticket.qualificationJointCommitFingerprint == 0
    else {
      throw TissueError.transaction(
        "NumanX root has no authoritative qualification outcome"
      )
    }
    return try BrainPolicyNumanXRootExecution(
      sampleSHA256: sampleSHA256,
      ownerProgramFingerprint: identity.programFingerprint,
      transactionFingerprint: identity.transactionFingerprint,
      linearizationEpoch: identity.linearizationEpoch,
      slotGeneration: identity.slotGeneration,
      transactionSlot: identity.transactionSlot,
      environment: identity.environment,
      stepIndex: identity.stepIndex,
      controlStep: identity.controlStep,
      substepIndex: identity.substepIndex,
      physicsSubstepCount: identity.physicsSubstepCount,
      outcome: outcome,
      appliedRecordFingerprint:
        ticket.qualificationAppliedRecordFingerprint,
      jointCommitFingerprint: ticket.qualificationJointCommitFingerprint
    )
  }

  private func numanXQualificationRootExecution(
    _ ticket: NumanXPreparedControlTicket,
    capturedSample: MetalNumanXCapturedRootSample
  ) throws -> BrainPolicyNumanXRootExecution {
    let sampleArtifact = capturedSample.artifact
    try sampleArtifact.validate()
    let canonicalSampleSHA256 = try sampleArtifact.sampleSHA256
    let transaction = ticket.transaction.token
    guard sampleArtifact.transactionFingerprint == transaction.fingerprint,
      UInt64(sampleArtifact.controlStep) == transaction.controlStepIdentifier,
      sampleArtifact.committedTimestampMicroseconds
        == transaction.committedTimestamp.rawValue,
      sampleArtifact.targetTimestampMicroseconds
        == transaction.targetTimestamp.rawValue,
      sampleArtifact.basePhysicsGeneration == transaction.basePhysicsGeneration,
      sampleArtifact.speciesTemplateFingerprint
        == cognitive.speciesTemplateFingerprint,
      sampleArtifact.sensoryProfileFingerprint
        == cognitive.sensoryRuntime.profileFingerprint,
      capturedSample.sampleSHA256 == canonicalSampleSHA256
    else {
      throw TissueError.transaction(
        "NumanX qualification sample does not identify the exact prepared root"
      )
    }
    return try numanXQualificationRootExecution(
      ticket,
      sampleSHA256: capturedSample.sampleSHA256
    )
  }

  /// Returns the retained host-constructed close fingerprint only while the
  /// exact aggregate ticket owns a terminally successful, unpublished
  /// preflight. This does not inspect the shared preflight record or expose a
  /// candidate buffer range as authority.
  @_spi(NumanXInterop)
  public func numanXPreparedJointCommitFingerprint(
    for ticket: NumanXPreparedControlTicket,
    identity: MetalNumanXHumanMatterRootIdentity
  ) throws -> UInt64 {
    lock.lock()
    defer { lock.unlock() }
    let transaction = ticket.transaction
    let provisional = ticket.provisionalPhysicsAcceptance
    guard activeTransaction === transaction,
      activeNumanXPreparedTicket === ticket,
      transaction.status == .numanXPreflightReady,
      transaction.numanXPreparedSubmissionIdentifier == ticket.identifier,
      transaction.provisionalFastSubmissionIdentifier
        == ticket.fastTicket.identifier,
      transaction.provisionalPhysicsAcceptance == provisional,
      ticket.identity == identity,
      ticket.preflightResources.identity == identity,
      ticket.preflightResources.provisional == provisional,
      identity.transactionFingerprint == transaction.token.fingerprint,
      identity.environment == transaction.token.environmentIdentifier,
      UInt64(identity.controlStep) == transaction.token.controlStepIdentifier,
      identity.controlStep == provisional.controlStep,
      identity.substepIndex == provisional.substepIndex,
      identity.physicsSubstepCount == 1,
      provisional.environmentIdentifier == identity.environment,
      provisional.transactionFingerprint == identity.transactionFingerprint,
      provisional.shadowGeneration == transaction.token.shadowGeneration,
      ticket.preflightResources.brainProgramFingerprint
        == ticket.brainProgramFingerprint,
      ticket.preflightResources.fastProgramFingerprint > 0,
      ticket.preflightResources.hasSignaledReady,
      let accepted = ticket.acceptedPhysicsState,
      accepted.transactionFingerprint == identity.transactionFingerprint,
      accepted.substepFingerprint == provisional.substepFingerprint,
      accepted.physicsGeneration == provisional.expectedPhysicsGeneration,
      accepted.environmentIdentifier == identity.environment,
      let prepared = ticket.preparedPublication,
      prepared.cognitive === transaction.cognitiveTransaction,
      prepared.fast.receipt.transactionFingerprint
        == identity.transactionFingerprint,
      prepared.fast.receipt.acceptedPhysicsTokenFingerprint
        == accepted.fingerprint,
      prepared.fast.receipt.brainGeneration == provisional.shadowGeneration,
      prepared.jointCommitFingerprint > 0,
      !ticket.brainAckSubmissionReserved,
      ticket.brainAckTicket == nil,
      !ticket.appliedValidationSubmissionReserved,
      ticket.appliedValidationTicket == nil,
      ticket.jointResolutionReservation == nil
    else {
      throw TissueError.transaction(
        "NumanX prepared joint-commit fingerprint requires the exact active "
          + "successful preflight root"
      )
    }
    return prepared.jointCommitFingerprint
  }

  private func numanXPublicationProtocolViolation(
    _ ticket: NumanXPreparedControlTicket
  ) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return ticket.publicationProtocolViolationDetected
  }

  /// Binds the exact owner-owned persistent publication-fence range. This is
  /// internal interop, not a public authority view: the range must come from
  /// the retained physical proposal lease and may be bound only once before
  /// Brain ACK. A Brain-owned substitute is intentionally not admitted.
  func bindNumanXOwnerPublicationFence(
    _ ticket: NumanXPreparedControlTicket,
    ownerBuffer: any MTLBuffer,
    byteOffset: Int
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    let transaction = ticket.transaction
    guard activeTransaction === transaction,
      activeNumanXPreparedTicket === ticket,
      transaction.numanXPreparedSubmissionIdentifier == ticket.identifier,
      transaction.status == .numanXPrepareSubmitted
        || transaction.status == .numanXPreflightReady,
      ticket.publicationFenceResources == nil
    else {
      throw TissueError.transaction(
        "NumanX owner publication fence is stale, duplicated, or too late"
      )
    }
    ticket.publicationFenceResources = try NumanXJointPublicationFenceResources(
      ownerBuffer: ownerBuffer,
      byteOffset: byteOffset,
      deviceRegistryID: deviceRegistryID,
      identity: ticket.identity,
      brainProgramFingerprint: ticket.brainProgramFingerprint
    )
  }

  private func bindNumanXOwnerPublicationFenceLocked(
    _ ticket: NumanXPreparedControlTicket,
    proposal: MetalNumanXHumanMatterProposalLease
  ) throws {
    try proposal.validate(for: proposal.publicationFenceBuffer.device)
    guard proposal.identity == ticket.identity,
      proposal.publicationFenceBuffer.device.registryID == deviceRegistryID
    else {
      throw TissueError.transaction(
        "NumanX proposal publication fence is on the wrong root or device"
      )
    }
    if let existing = ticket.publicationFenceResources {
      guard (existing.buffer as AnyObject)
          === (proposal.publicationFenceBuffer as AnyObject),
        existing.byteOffset == proposal.publicationFenceByteOffset,
        existing.identity == proposal.identity,
        existing.brainProgramFingerprint == ticket.brainProgramFingerprint
      else {
        throw TissueError.transaction(
          "NumanX owner publication fence cannot be rebound"
        )
      }
      return
    }
    ticket.publicationFenceResources = try NumanXJointPublicationFenceResources(
      ownerBuffer: proposal.publicationFenceBuffer,
      byteOffset: proposal.publicationFenceByteOffset,
      deviceRegistryID: deviceRegistryID,
      identity: ticket.identity,
      brainProgramFingerprint: ticket.brainProgramFingerprint
    )
  }

  func controlStatus(
    _ transaction: ControlTransaction
  ) -> ControlTransaction.Status {
    lock.lock()
    defer { lock.unlock() }
    return transaction.status
  }

  func controlDecision(
    _ transaction: ControlTransaction
  ) -> MetalEmbodiedBrainRuntime.DecisionBufferView? {
    lock.lock()
    defer { lock.unlock() }
    return transaction.decision
  }

  func controlActiveSubstep(
    _ transaction: ControlTransaction
  ) -> BrainJointSubstepToken? {
    lock.lock()
    defer { lock.unlock() }
    return transaction.activeSubstep
  }

  func controlAcceptedPhysicsState(
    _ transaction: ControlTransaction
  ) -> AcceptedPhysicsStateToken? {
    lock.lock()
    defer { lock.unlock() }
    return transaction.lastAcceptedPhysicsState
  }

  /// Completes every fallible receipt, arena, and generation check before the
  /// paired pointer flip. This is shared by compatibility and event-driven
  /// paths so neither can publish only one half of the brain generation.
  private func prepareAtomicJointPublication(
    fast: MetalTissueRuntime.PreparedJointRootCommit,
    cognitive cognitiveTransaction: MetalJointAgentStateTransaction
  ) throws -> PreparedAtomicJointPublication {
    try cognitive.prepareCommit(
      transaction: cognitiveTransaction,
      receipt: fast.receipt
    )
    return PreparedAtomicJointPublication(
      fast: fast,
      cognitive: cognitiveTransaction,
      jointCommitFingerprint: fast.receipt.fingerprint
    )
  }

  /// Nonthrowing critical section after all fast/cognitive preflight. These
  /// component publications only flip committed pointers/counters; the public
  /// generation advances after both have completed under this runtime lock.
  private func publishAtomicJointPublication(
    _ prepared: PreparedAtomicJointPublication,
    transaction: ControlTransaction
  ) {
    publishPreparedComponentPointers(prepared)
    finishPublicJointPublication(
      brainGeneration: prepared.fast.receipt.brainGeneration,
      transaction: transaction
    )
  }

  /// This is the complete private pointer flip. The NumanX path deliberately
  /// calls it before the external publication-fence release while holding the
  /// coordinator lock, so no public Brain generation can expose only one half.
  private func publishPreparedComponentPointers(
    _ prepared: PreparedAtomicJointPublication
  ) {
    fastTissue.publishPreparedJointRootTransactionCommit(prepared.fast)
    cognitive.publishPreparedCommit(transaction: prepared.cognitive)
  }

  /// Advances the only public complete-brain generation after every external
  /// publication condition has become terminally successful.
  private func finishPublicJointPublication(
    brainGeneration: UInt64,
    transaction: ControlTransaction
  ) {
    publishedGeneration = brainGeneration
    transaction.status = .committed
    activeTransaction = nil
  }

  private func abortLocked(_ transaction: ControlTransaction) {
    if fastTissue.hasOpenInteractiveJointControl {
      try? fastTissue.abortInteractiveJointControl()
    }
    if transaction.cognitiveTransaction.status == .open
      || transaction.cognitiveTransaction.status == .gpuStateFinished
      || transaction.cognitiveTransaction.status == .commitPrepared
    {
      try? cognitive.abort(transaction: transaction.cognitiveTransaction)
    }
    transaction.activeSubstep = nil
    transaction.status = .aborted
    activeTransaction = nil
  }

  private func finishNumanXAbort(_ transaction: ControlTransaction) {
    activeNumanXPreparedTicket?.prepareFeedbackLatch.cancel()
    activeNumanXPreparedTicket = nil
    transaction.numanXPreparedSubmissionIdentifier = nil
    transaction.provisionalFastSubmissionIdentifier = nil
    transaction.provisionalPhysicsAcceptance = nil
    transaction.provisionalFastMotorState = nil
    transaction.activeSubstep = nil
    transaction.status = .aborted
    activeTransaction = nil
  }

  private func finishNumanXPublicationSuccess(
    _ ticket: NumanXPreparedControlTicket,
    brainGeneration: UInt64
  ) {
    precondition(
      activeNumanXPreparedTicket === ticket
        && activeTransaction === ticket.transaction
    )
    ticket.prepareFeedbackLatch.cancel()
    activeNumanXPreparedTicket = nil
    let transaction = ticket.transaction
    transaction.numanXPreparedSubmissionIdentifier = nil
    transaction.provisionalFastSubmissionIdentifier = nil
    transaction.provisionalPhysicsAcceptance = nil
    transaction.provisionalFastMotorState = nil
    transaction.lastAcceptedSubstep = transaction.activeSubstep
    transaction.activeSubstep = nil
    finishPublicJointPublication(
      brainGeneration: brainGeneration,
      transaction: transaction
    )
    ticket.completeOwningHandleTerminalRelease()
  }

  private func finishResolvedNumanXRejection(
    _ ticket: NumanXPreparedControlTicket
  ) {
    cognitive.releaseResolvedNumanXPreparedSubmission(
      ticket.cognitiveTicket,
      transaction: ticket.transaction.cognitiveTransaction
    )
    finishNumanXCognitiveAbort(ticket.transaction.cognitiveTransaction)
    fastTissue.discardResolvedProvisionalFastRootSubmission(ticket.fastTicket)
    finishNumanXAbort(ticket.transaction)
    ticket.completeOwningHandleTerminalRelease()
  }

  private func finishNumanXCognitiveAbort(
    _ transaction: MetalJointAgentStateTransaction
  ) {
    guard transaction.status != .aborted else { return }
    do {
      try cognitive.abort(transaction: transaction)
    } catch {
      preconditionFailure(
        "preflighted NumanX cognitive rejection failed: \(error)"
      )
    }
  }
}

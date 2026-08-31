import Foundation
@preconcurrency import Metal
import NumiBrainCore

@available(macOS 26.0, *)
private enum MetalSharedEventSignalRegistry {
  private final class Entry {
    weak var event: AnyObject?
    var reservedValue: UInt64

    init(event: any MTLSharedEvent, reservedValue: UInt64) {
      self.event = event as AnyObject
      self.reservedValue = reservedValue
    }
  }

  private static let lock = NSLock()
  nonisolated(unsafe) private static var entries: [ObjectIdentifier: Entry] = [:]

  /// Atomically reserves a strictly increasing signal value for this exact
  /// shared-event object. Metal exposes no stable cross-process event ID, so
  /// this closes same-process multi-runtime races while the GPU's own timeline
  /// remains authoritative across process boundaries.
  static func reserve(event: any MTLSharedEvent, value: UInt64) throws {
    lock.lock()
    defer { lock.unlock() }
    if entries.count > 64 {
      entries = entries.filter { $0.value.event != nil }
    }
    let identifier = ObjectIdentifier(event as AnyObject)
    let reachedValue = event.signaledValue
    if let entry = entries[identifier], entry.event != nil {
      guard value > max(reachedValue, entry.reservedValue) else {
        throw TissueError.transaction(
          "shared GPU signal value does not advance its reached or reserved timeline"
        )
      }
      entry.reservedValue = value
    } else {
      guard value > reachedValue else {
        throw TissueError.transaction(
          "shared GPU completion value has already been reached"
        )
      }
      entries[identifier] = Entry(event: event, reservedValue: value)
    }
  }
}

/// One monotonically increasing point on a caller-owned Metal shared-event
/// timeline. Queue waits and signals use this value directly; observing or
/// waiting for it on the host is an explicit publication boundary.
@available(macOS 26.0, *)
public struct MetalSharedEventPoint: @unchecked Sendable {
  public let event: any MTLSharedEvent
  public let value: UInt64

  public init(event: any MTLSharedEvent, value: UInt64) throws {
    guard value > 0 else {
      throw TissueError.transaction("a shared GPU timeline value must be positive")
    }
    self.event = event
    self.value = value
  }

  func validate(for device: any MTLDevice) throws {
    if let eventDevice = event.device {
      guard eventDevice.registryID == device.registryID else {
        throw TissueError.transaction(
          "shared GPU timeline event belongs to a different Metal device"
        )
      }
    } else {
      // Apple deliberately reports nil for MTLSharedEvent.device because the
      // event is shareable. Re-importing its handle through this exact device
      // is the available compatibility/provenance check; fail closed if Metal
      // cannot materialize the event for the owning queue's device.
      let handle = event.makeSharedEventHandle()
      guard device.makeSharedEvent(handle: handle) != nil else {
        throw TissueError.transaction(
          "shared GPU timeline event cannot be imported by this Metal device"
        )
      }
    }
  }

  static func validateProgression(
    wait: MetalSharedEventPoint?,
    signal: MetalSharedEventPoint,
    device: any MTLDevice
  ) throws {
    try wait?.validate(for: device)
    try signal.validate(for: device)
    if let wait, (wait.event as AnyObject) === (signal.event as AnyObject) {
      guard signal.value > wait.value else {
        throw TissueError.transaction(
          "a shared GPU timeline signal must advance beyond its wait value"
        )
      }
    }
    try MetalSharedEventSignalRegistry.reserve(
      event: signal.event,
      value: signal.value
    )
  }
}

/// Immutable completion feedback for one Metal 4 queue submission.
@available(macOS 26.0, *)
@frozen
public struct MetalGPUCompletionFeedback: Equatable, Sendable {
  public let gpuStartSeconds: Double
  public let gpuEndSeconds: Double

  public var gpuDurationSeconds: Double {
    max(gpuEndSeconds - gpuStartSeconds, 0)
  }
}

@available(macOS 26.0, *)
final class MetalAsyncFeedbackState: @unchecked Sendable {
  typealias CompletionHandler = @Sendable () -> Void

  private enum Outcome {
    case success(MetalGPUCompletionFeedback)
    case failure(String)
  }

  private let condition = NSCondition()
  private var outcome: Outcome?
  private var completionHandler: CompletionHandler?
  private var completionHandlerRegistered = false

  var hasCompleted: Bool {
    condition.lock()
    defer { condition.unlock() }
    return outcome != nil
  }

  func record(_ feedback: any MTL4CommitFeedback, label: String) {
    let recorded: Outcome
    if let error = feedback.error {
      recorded = .failure("GPU execution failed during \(label): \(error)")
    } else {
      recorded = .success(
        MetalGPUCompletionFeedback(
          gpuStartSeconds: feedback.gpuStartTime,
          gpuEndSeconds: feedback.gpuEndTime
        )
      )
    }
    let handler: CompletionHandler?
    condition.lock()
    if outcome == nil {
      outcome = recorded
      condition.broadcast()
      handler = completionHandler
      completionHandler = nil
    } else {
      handler = nil
    }
    condition.unlock()
    handler?()
  }

  /// Registers the sole nonwaiting terminal consumer. Completion may invoke
  /// synchronously when feedback won the race, but never while this state's
  /// nonrecursive condition lock is held.
  func registerCompletionHandler(
    _ handler: @escaping CompletionHandler
  ) throws {
    let invokeSynchronously: Bool
    condition.lock()
    guard !completionHandlerRegistered else {
      condition.unlock()
      throw TissueError.transaction(
        "Metal feedback completion handler is already registered"
      )
    }
    completionHandlerRegistered = true
    invokeSynchronously = outcome != nil
    if !invokeSynchronously { completionHandler = handler }
    condition.unlock()
    if invokeSynchronously { handler() }
  }

  func poll() throws -> MetalGPUCompletionFeedback? {
    condition.lock()
    defer { condition.unlock() }
    return try resolve(outcome)
  }

  func wait(timeoutMilliseconds: UInt64) throws -> MetalGPUCompletionFeedback {
    guard timeoutMilliseconds > 0 else {
      throw TissueError.transaction("GPU completion timeout must be positive")
    }
    let timeoutSeconds = min(
      Double(timeoutMilliseconds) / 1_000,
      Double(Int.max)
    )
    let deadline = Date(timeIntervalSinceNow: timeoutSeconds)
    condition.lock()
    defer { condition.unlock() }
    while outcome == nil {
      guard condition.wait(until: deadline) else {
        throw TissueError.metal("timed out waiting for Metal 4 completion feedback")
      }
    }
    guard let feedback = try resolve(outcome) else {
      throw TissueError.metal("Metal 4 completion feedback was not published")
    }
    return feedback
  }

  private func resolve(_ outcome: Outcome?) throws -> MetalGPUCompletionFeedback? {
    switch outcome {
    case .none:
      return nil
    case .success(let feedback):
      return feedback
    case .failure(let message):
      throw TissueError.metal(message)
    }
  }
}

@available(macOS 26.0, *)
final class MetalAsyncCommandResources: @unchecked Sendable {
  let allocator: any MTL4CommandAllocator
  let commandBuffer: any MTL4CommandBuffer
  private var residencySets: [any MTLResidencySet]
  private let lock = NSLock()
  private var released = false

  init(
    allocator: any MTL4CommandAllocator,
    commandBuffer: any MTL4CommandBuffer,
    residencySets: [any MTLResidencySet]
  ) {
    self.allocator = allocator
    self.commandBuffer = commandBuffer
    self.residencySets = residencySets
  }

  func release() {
    lock.lock()
    guard !released else {
      lock.unlock()
      return
    }
    released = true
    let retainedResidency = residencySets
    residencySets.removeAll(keepingCapacity: false)
    lock.unlock()
    for set in retainedResidency {
      set.endResidency()
    }
  }

  deinit { release() }
}

@available(macOS 26.0, *)
extension MetalEmbodiedBrainRuntime {
  /// An encoded decision whose GPU addresses are immediately available for
  /// queue-to-queue consumption. The addresses are not host-ready until the
  /// completion point is reached. The owning runtime retains the complete
  /// shadow allocation and all borrowed sensor allocations until callers
  /// explicitly finish or abort this ticket.
  public final class DecisionSubmissionTicket: @unchecked Sendable {
    public let decision: DecisionBufferView
    public let waitPoint: MetalSharedEventPoint?
    public let completionPoint: MetalSharedEventPoint
    public let decisionReadyGate: MetalNumanXDecisionReadyGateLease

    private let owner: MetalEmbodiedBrainRuntime
    let identifier: UUID
    let feedbackState: MetalAsyncFeedbackState
    let decisionGateEvaluation: MetalNumanXDecisionReadyEvaluation

    init(
      identifier: UUID,
      owner: MetalEmbodiedBrainRuntime,
      decision: DecisionBufferView,
      waitPoint: MetalSharedEventPoint?,
      completionPoint: MetalSharedEventPoint,
      feedbackState: MetalAsyncFeedbackState,
      decisionGateEvaluation: MetalNumanXDecisionReadyEvaluation
    ) {
      self.identifier = identifier
      self.owner = owner
      self.decision = decision
      self.waitPoint = waitPoint
      self.completionPoint = completionPoint
      self.feedbackState = feedbackState
      self.decisionGateEvaluation = decisionGateEvaluation
      self.decisionReadyGate = decisionGateEvaluation.lease
    }

    public var hasCompleted: Bool { feedbackState.hasCompleted }

    /// Nonblocking feedback probe. A `nil` value means Metal has not yet
    /// published completion feedback; a thrown error is the exact GPU failure.
    public func completionFeedbackIfAvailable() throws
      -> MetalGPUCompletionFeedback?
    {
      try feedbackState.poll()
    }

    /// Explicit host publication boundary. Submission itself never calls this
    /// or waits on a semaphore.
    public func waitUntilCompleted(
      timeoutMilliseconds: UInt64 = 30_000
    ) throws -> MetalGPUCompletionFeedback {
      try feedbackState.wait(timeoutMilliseconds: timeoutMilliseconds)
    }
  }

  /// An encoded accepted physical consequence. The cognitive shadow remains
  /// unpublished while this ticket is outstanding; only explicit acceptance
  /// may finish and later publish the joint generation.
  public final class AcceptedConsequenceSubmissionTicket: @unchecked Sendable {
    /// Joint-close tickets deliberately expose only an opaque identity view here:
    /// candidate sensory/event GPU addresses and counts remain private until a
    /// later final ACCEPT publisher constructs an authoritative completion.
    public let consequence: AcceptedConsequenceView
    public let waitPoint: MetalSharedEventPoint?
    public let completionPoint: MetalSharedEventPoint

    private let owner: MetalEmbodiedBrainRuntime
    let identifier: UUID
    let feedbackState: MetalAsyncFeedbackState
    let gateEvaluation: MetalAcceptedPhysicsGateEvaluation
    let numanXPrepareEvaluation: MetalNumanXBrainCommitPrepareEvaluation?
    let candidateConsequence: AcceptedConsequenceView

    init(
      identifier: UUID,
      owner: MetalEmbodiedBrainRuntime,
      consequence: AcceptedConsequenceView,
      waitPoint: MetalSharedEventPoint?,
      completionPoint: MetalSharedEventPoint,
      feedbackState: MetalAsyncFeedbackState,
      gateEvaluation: MetalAcceptedPhysicsGateEvaluation,
      numanXPrepareEvaluation: MetalNumanXBrainCommitPrepareEvaluation? = nil
    ) {
      self.identifier = identifier
      self.owner = owner
      self.candidateConsequence = consequence
      if numanXPrepareEvaluation != nil {
        self.consequence = AcceptedConsequenceView(
          transactionFingerprint: consequence.transactionFingerprint,
          shadowGeneration: consequence.shadowGeneration,
          acceptedPhysicsTokenFingerprint: 0,
          acceptedTimestamp: consequence.acceptedTimestamp,
          sensoryObservationGPUAddress: 0,
          sensoryObservationScalarCount: 0,
          receptorEventQueueGPUAddress: 0,
          receptorEventCapacity: 0,
          gpuStartSeconds: 0,
          gpuEndSeconds: 0
        )
      } else {
        self.consequence = consequence
      }
      self.waitPoint = waitPoint
      self.completionPoint = completionPoint
      self.feedbackState = feedbackState
      self.gateEvaluation = gateEvaluation
      self.numanXPrepareEvaluation = numanXPrepareEvaluation
    }

    public var hasCompleted: Bool { feedbackState.hasCompleted }

    /// Compact GPU-written prepare witness. It stays retained with this ticket
    /// until finish/abort reaps the submission and can be consumed by a later
    /// device-side joint-finalize stage without reading sensor payloads.
    public var acceptedPhysicsWitnessGPUAddress: UInt64 {
      gateEvaluation.resultBuffer.gpuAddress
    }

    public var acceptedPhysicsWitnessByteCount: Int {
      gateEvaluation.resultBuffer.length
    }

    public var acceptedPhysicsWitnessMetalBufferObject: UnsafeMutableRawPointer {
      Unmanaged.passUnretained(
        gateEvaluation.resultBuffer as AnyObject
      ).toOpaque()
    }

    /// True only for the staged NumanX path. The separate 128-byte witness is the
    /// final accepted-consequence writer; it is not the existing start gate.
    public var hasNumanXBrainCommitWitness: Bool {
      numanXPrepareEvaluation != nil
    }

    public var numanXBrainCommitWitnessGPUAddress: UInt64? {
      numanXPrepareEvaluation?.witnessBuffer.gpuAddress
    }

    public var numanXBrainCommitWitnessByteCount: Int? {
      numanXPrepareEvaluation?.witnessBuffer.length
    }

    public var numanXBrainCommitWitnessMetalBufferObject: UnsafeMutableRawPointer? {
      numanXPrepareEvaluation.map {
        Unmanaged.passUnretained($0.witnessBuffer as AnyObject).toOpaque()
      }
    }

    public var numanXBrainProgramFingerprint: UInt64? {
      numanXPrepareEvaluation?.brainProgramFingerprint
    }

    public var numanXHashedByteCount: UInt64? {
      numanXPrepareEvaluation?.hashLayout.totalByteCount
    }

    public var numanXHashChunkCount: UInt32? {
      numanXPrepareEvaluation?.hashLayout.chunkCount
    }

    public var numanXHashReductionLevelCount: Int? {
      numanXPrepareEvaluation?.hashLayout.reductionCounts.count
    }

    public var numanXHashDispatchCount: Int? {
      numanXPrepareEvaluation?.hashDispatchCount
    }

    public var numanXHashScratchByteCount: Int? {
      numanXPrepareEvaluation.map { $0.hashLayout.scratchByteCount * 2 }
    }

    public func completionFeedbackIfAvailable() throws
      -> MetalGPUCompletionFeedback?
    {
      try feedbackState.poll()
    }

    func registerTerminalFeedbackHandler(
      _ handler: @escaping @Sendable () -> Void
    ) throws {
      try feedbackState.registerCompletionHandler(handler)
    }

    public func waitUntilCompleted(
      timeoutMilliseconds: UInt64 = 30_000
    ) throws -> MetalGPUCompletionFeedback {
      try feedbackState.wait(timeoutMilliseconds: timeoutMilliseconds)
    }
  }

}

@available(macOS 26.0, *)
extension MetalNumiBrainRuntime {
  /// Complete-brain ownership ticket for an event-driven cognitive decision.
  /// The root cannot advance into fast systems until this ticket is explicitly
  /// finished, which stages the decision into the fast neural runtime.
  public final class DecisionSubmissionTicket: @unchecked Sendable {
    public let decision: MetalEmbodiedBrainRuntime.DecisionBufferView
    public let waitPoint: MetalSharedEventPoint?
    public let completionPoint: MetalSharedEventPoint

    private let owner: MetalNumiBrainRuntime
    let identifier: UUID
    let cognitiveTicket: MetalEmbodiedBrainRuntime.DecisionSubmissionTicket

    init(
      identifier: UUID,
      owner: MetalNumiBrainRuntime,
      cognitiveTicket: MetalEmbodiedBrainRuntime.DecisionSubmissionTicket
    ) {
      self.identifier = identifier
      self.owner = owner
      self.cognitiveTicket = cognitiveTicket
      self.decision = cognitiveTicket.decision
      self.waitPoint = cognitiveTicket.waitPoint
      self.completionPoint = cognitiveTicket.completionPoint
    }

    public var hasCompleted: Bool { cognitiveTicket.hasCompleted }

    public func completionFeedbackIfAvailable() throws
      -> MetalGPUCompletionFeedback?
    {
      try cognitiveTicket.completionFeedbackIfAvailable()
    }

    public func waitUntilCompleted(
      timeoutMilliseconds: UInt64 = 30_000
    ) throws -> MetalGPUCompletionFeedback {
      try cognitiveTicket.waitUntilCompleted(
        timeoutMilliseconds: timeoutMilliseconds
      )
    }
  }

  /// Complete-brain ownership of one causal GPU decision-to-motor chain. The
  /// output buffers and candidate identity are available immediately for a
  /// physical command buffer that waits on `motorReadyPoint`; the event is
  /// liveness only and consumers must validate `motorReadyGate` on the GPU.
  public final class NumanXMotorSubmissionTicket: @unchecked Sendable {
    public let decision: MetalEmbodiedBrainRuntime.DecisionBufferView
    public let fastSystems: MetalTissueRuntime.FastSystemResult
    public let candidate: NumanXMotorCandidate
    public let buffers: MetalTissueRuntime.NumanXMotorBufferLease
    public let decisionReadyPoint: MetalSharedEventPoint
    public let motorReadyPoint: MetalSharedEventPoint
    public let motorReadyGate: MetalNumanXMotorReadyGateLease

    private let owner: MetalNumiBrainRuntime
    let identifier: UUID
    let cognitiveTicket: MetalEmbodiedBrainRuntime.DecisionSubmissionTicket
    let motorTicket: MetalTissueRuntime.NumanXMotorSubmissionTicket

    init(
      identifier: UUID,
      owner: MetalNumiBrainRuntime,
      cognitiveTicket: MetalEmbodiedBrainRuntime.DecisionSubmissionTicket,
      motorTicket: MetalTissueRuntime.NumanXMotorSubmissionTicket
    ) {
      self.identifier = identifier
      self.owner = owner
      self.cognitiveTicket = cognitiveTicket
      self.motorTicket = motorTicket
      self.decision = cognitiveTicket.decision
      self.fastSystems = motorTicket.fastSystems
      self.candidate = motorTicket.candidate
      self.buffers = motorTicket.buffers
      self.decisionReadyPoint = cognitiveTicket.completionPoint
      self.motorReadyPoint = motorTicket.completionPoint
      self.motorReadyGate = motorTicket.motorReadyGate
    }

    public var hasCompleted: Bool {
      cognitiveTicket.hasCompleted && motorTicket.hasCompleted
    }
  }

  /// Complete-brain ownership ticket for accepted consequence assimilation.
  /// Fast state is prepared but neither fast nor cognitive generations publish
  /// until explicit ticket acceptance.
  public final class CommitSubmissionTicket: @unchecked Sendable {
    public let decision: MetalEmbodiedBrainRuntime.DecisionBufferView
    public let consequence: MetalEmbodiedBrainRuntime.AcceptedConsequenceView
    public let fastSubmission: MetalTissueRuntime.Submission
    public let waitPoint: MetalSharedEventPoint?
    public let completionPoint: MetalSharedEventPoint

    private let owner: MetalNumiBrainRuntime
    let identifier: UUID
    let acceptedPhysicsState: AcceptedPhysicsStateToken
    let cognitiveTicket:
      MetalEmbodiedBrainRuntime.AcceptedConsequenceSubmissionTicket

    init(
      identifier: UUID,
      owner: MetalNumiBrainRuntime,
      decision: MetalEmbodiedBrainRuntime.DecisionBufferView,
      acceptedPhysicsState: AcceptedPhysicsStateToken,
      fastSubmission: MetalTissueRuntime.Submission,
      cognitiveTicket:
        MetalEmbodiedBrainRuntime.AcceptedConsequenceSubmissionTicket
    ) {
      self.identifier = identifier
      self.owner = owner
      self.decision = decision
      self.acceptedPhysicsState = acceptedPhysicsState
      self.fastSubmission = fastSubmission
      self.cognitiveTicket = cognitiveTicket
      self.consequence = cognitiveTicket.consequence
      self.waitPoint = cognitiveTicket.waitPoint
      self.completionPoint = cognitiveTicket.completionPoint
    }

    public var hasCompleted: Bool { cognitiveTicket.hasCompleted }

    public var hasNumanXBrainCommitWitness: Bool {
      cognitiveTicket.hasNumanXBrainCommitWitness
    }

    public var numanXBrainCommitWitnessGPUAddress: UInt64? {
      cognitiveTicket.numanXBrainCommitWitnessGPUAddress
    }

    public var numanXBrainCommitWitnessByteCount: Int? {
      cognitiveTicket.numanXBrainCommitWitnessByteCount
    }

    public var numanXBrainCommitWitnessMetalBufferObject: UnsafeMutableRawPointer? {
      cognitiveTicket.numanXBrainCommitWitnessMetalBufferObject
    }

    public var numanXBrainProgramFingerprint: UInt64? {
      cognitiveTicket.numanXBrainProgramFingerprint
    }

    public func completionFeedbackIfAvailable() throws
      -> MetalGPUCompletionFeedback?
    {
      try cognitiveTicket.completionFeedbackIfAvailable()
    }

    public func waitUntilCompleted(
      timeoutMilliseconds: UInt64 = 30_000
    ) throws -> MetalGPUCompletionFeedback {
      try cognitiveTicket.waitUntilCompleted(
        timeoutMilliseconds: timeoutMilliseconds
      )
    }
  }
}

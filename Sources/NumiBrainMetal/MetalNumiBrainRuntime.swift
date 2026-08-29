import Foundation
import NumiBrainCore

/// One authoritative Apple-GPU brain runtime spanning cortical cognition,
/// fast tissue, spinal protection, memory journals, and joint rollback.
///
/// The component runtimes remain independently inspectable, but all mutable
/// control operations pass through this coordinator. It prevents a caller from
/// advancing cognition under one root token while fast tissue or NumanX uses
/// another, and it publishes both brain generations from one commit receipt.
@available(macOS 26.0, *)
public final class MetalNumiBrainRuntime: @unchecked Sendable {
  public final class ControlTransaction: @unchecked Sendable {
    @frozen
    public enum Status: Equatable, Sendable {
      case open
      case decisionReady
      case substepActive
      case committed
      case aborted
    }

    public let token: BrainJointTransactionToken
    public fileprivate(set) var status: Status = .open
    public fileprivate(set) var decision: MetalEmbodiedBrainRuntime.DecisionBufferView?
    public fileprivate(set) var activeSubstep: BrainJointSubstepToken?
    public fileprivate(set) var lastAcceptedPhysicsState: AcceptedPhysicsStateToken?

    fileprivate let cognitiveTransaction: MetalJointAgentStateTransaction

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

  public let cognitive: MetalEmbodiedBrainRuntime
  public let fastTissue: MetalTissueRuntime
  public let parameterVersionFingerprint: UInt64
  public let regionalProgramFingerprint: UInt64
  public let scheduleFingerprint: UInt64
  public let deviceRegistryID: UInt64

  private let lock = NSLock()
  private var activeTransaction: ControlTransaction?

  public init(
    cognitive: MetalEmbodiedBrainRuntime,
    fastTissue: MetalTissueRuntime
  ) throws {
    guard cognitive.deviceRegistryID == fastTissue.deviceRegistryID,
      cognitive.parameterVersionFingerprint == fastTissue.parameterVersion.fingerprint,
      cognitive.regionalProgramFingerprint == fastTissue.regionalTokenProgram.fingerprint,
      cognitive.scheduleFingerprint == fastTissue.brainSchedule.fingerprint,
      cognitive.sharedParameterBank.artifactFingerprint
        == fastTissue.sharedParameterBank.artifactFingerprint,
      cognitive.sensoryRuntime.maximumEventCount <= fastTissue.maxSchedulerEvents
    else {
      throw TissueError.transaction(
        "cognitive and fast runtimes do not share one device and immutable brain version"
      )
    }
    try fastTissue.bindSpeciesReflexProgram(cognitive.boundSpeciesTemplate)
    self.cognitive = cognitive
    self.fastTissue = fastTissue
    self.parameterVersionFingerprint = cognitive.parameterVersionFingerprint
    self.regionalProgramFingerprint = cognitive.regionalProgramFingerprint
    self.scheduleFingerprint = cognitive.scheduleFingerprint
    self.deviceRegistryID = cognitive.deviceRegistryID
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
    guard activeTransaction == nil, cachedDecisionFingerprint > 0 else {
      throw TissueError.transaction(
        "finish or abort the active brain control before beginning another"
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
    rawSensors: [MetalRawSensorBufferLease]
  ) throws -> MetalEmbodiedBrainRuntime.DecisionBufferView {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction, status: .open)
    do {
      let recurrence = try fastTissue.committedRegionalRecurrentBufferView()
      let decision = try cognitive.inferAndDecide(
        transaction: transaction.cognitiveTransaction,
        rawSensors: rawSensors,
        regionalRecurrentInput: recurrence
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

  /// Finalizes accepted consequences, applies memory journals, and publishes
  /// fast and complete-agent generations from the same joint receipt.
  public func commitControl(
    _ transaction: ControlTransaction,
    acceptedSensors: [MetalRawSensorBufferLease],
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
      let consequence = try cognitive.finalizeAcceptedControl(
        transaction: transaction.cognitiveTransaction,
        acceptedPhysicsState: accepted,
        rawSensors: acceptedSensors,
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
      let preparedFastCommit = try fastTissue.prepareJointRootTransactionCommit()
      try cognitive.prepareCommit(
        transaction: transaction.cognitiveTransaction,
        receipt: preparedFastCommit.receipt
      )
      fastTissue.publishPreparedJointRootTransactionCommit(preparedFastCommit)
      cognitive.publishPreparedCommit(
        transaction: transaction.cognitiveTransaction
      )
      transaction.status = .committed
      activeTransaction = nil
      return CommitResult(
        receipt: preparedFastCommit.receipt,
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
}

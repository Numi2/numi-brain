import Foundation
@preconcurrency import Metal
import NumiBrainABI
import NumiBrainCore

/// Stable owner of one published complete-brain runtime generation. Checkpoint
/// restoration occurs in an isolated candidate runtime; this handle swaps the
/// candidate into service only after every cognitive and fast-state upload has
/// succeeded, leaving the previous mind untouched on failure.
@available(macOS 26.0, *)
public final class MetalNumiBrainHandle: @unchecked Sendable {
  public final class ControlTransaction: @unchecked Sendable {
    fileprivate let runtime: MetalNumiBrainRuntime
    fileprivate let transaction: MetalNumiBrainRuntime.ControlTransaction

    fileprivate init(
      runtime: MetalNumiBrainRuntime,
      transaction: MetalNumiBrainRuntime.ControlTransaction
    ) {
      self.runtime = runtime
      self.transaction = transaction
    }

    public var token: BrainJointTransactionToken { transaction.token }
    public var status: MetalNumiBrainRuntime.ControlTransaction.Status {
      runtime.controlStatus(transaction)
    }
    public var decision: MetalEmbodiedBrainRuntime.DecisionBufferView? {
      runtime.controlDecision(transaction)
    }
    public var activeSubstep: BrainJointSubstepToken? {
      runtime.controlActiveSubstep(transaction)
    }
    public var lastAcceptedPhysicsState: AcceptedPhysicsStateToken? {
      runtime.controlAcceptedPhysicsState(transaction)
    }
  }

  public typealias CommitResult = MetalNumiBrainRuntime.CommitResult

  public let compiledSpeciesTemplateFingerprint: UInt64
  public let regionalProgramFingerprint: UInt64
  public let scheduleFingerprint: UInt64
  public let somaticSynergyCatalogFingerprint: UInt64
  public let deviceRegistryID: UInt64
  public let compiledSpeciesTemplate: CompiledSpeciesTemplate

  private let lock = NSLock()
  private let configuration: MetalNumiBrainConfiguration
  private var publication: BrainParameterPublication
  private let foundationPolicyArchitecture: BrainFoundationPolicyArchitecture?
  private let device: any MTLDevice
  private let numanXTerminalReleaseQueue = DispatchQueue(
    label: "org.numi.brain.numanx-handle-terminal-release"
  )
  private var runtime: MetalNumiBrainRuntime
  private var activeTransaction: ControlTransaction?

  init(
    runtime: MetalNumiBrainRuntime,
    configuration: MetalNumiBrainConfiguration,
    publication: BrainParameterPublication,
    foundationPolicyArchitecture: BrainFoundationPolicyArchitecture?,
    device: any MTLDevice
  ) {
    self.runtime = runtime
    self.configuration = configuration
    self.publication = publication
    self.foundationPolicyArchitecture = foundationPolicyArchitecture
    self.device = device
    self.compiledSpeciesTemplateFingerprint =
      runtime.compiledSpeciesTemplateFingerprint
    self.regionalProgramFingerprint = runtime.regionalProgramFingerprint
    self.scheduleFingerprint = runtime.scheduleFingerprint
    self.somaticSynergyCatalogFingerprint =
      runtime.somaticSynergyCatalogFingerprint
    self.deviceRegistryID = runtime.deviceRegistryID
    self.compiledSpeciesTemplate = configuration.compiledSpeciesTemplate
  }

  public var committedGeneration: UInt64 {
    lock.lock()
    defer { lock.unlock() }
    return runtime.committedGeneration
  }

  public var parameterVersionFingerprint: UInt64 {
    lock.lock()
    defer { lock.unlock() }
    return publication.version.fingerprint
  }

  public var hasOpenControl: Bool {
    lock.lock()
    defer { lock.unlock() }
    return activeTransaction != nil
  }

  public func validate(parameterCohort: MetalParameterCohort) throws {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction == nil else {
      throw TissueError.transaction(
        "cannot bind a parameter cohort during active brain control"
      )
    }
    try runtime.validate(parameterCohort: parameterCohort)
  }

  public func makeLearningBatch() throws -> MetalLearningBatch {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction == nil else {
      throw TissueError.transaction(
        "learning snapshots require a closed brain control"
      )
    }
    return try runtime.makeLearningBatch()
  }

  public func makeLearningCohortMember(
    mindIdentifier: UInt64
  ) throws -> MetalLearningCohortMember {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction == nil else {
      throw TissueError.transaction(
        "learning snapshots require a closed brain control"
      )
    }
    return try runtime.makeLearningCohortMember(
      mindIdentifier: mindIdentifier
    )
  }

  public func snapshotArchivePageRequests() throws
    -> MetalArchivePageRequestSnapshot
  {
    lock.lock()
    defer { lock.unlock() }
    try requireIdle()
    return try runtime.snapshotArchivePageRequests()
  }

  public func snapshotArchivePages(
    _ pageIdentifiers: [UInt32]
  ) throws -> [MetalArchivePagePayload] {
    lock.lock()
    defer { lock.unlock() }
    try requireIdle()
    return try runtime.snapshotArchivePages(pageIdentifiers)
  }

  public func loadArchivePages(
    _ payloads: [MetalArchivePagePayload]
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireIdle()
    try runtime.loadArchivePages(payloads)
  }

  public func evictArchivePages(_ pageIdentifiers: [UInt32]) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireIdle()
    try runtime.evictArchivePages(pageIdentifiers)
  }

  public func resolveArchivePageRequests(
    _ snapshot: MetalArchivePageRequestSnapshot,
    residentPageIdentifiers: [UInt32]
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireIdle()
    try runtime.resolveArchivePageRequests(
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
    try requireIdle()
    try runtime.resolveArchivePageRequests(
      snapshot,
      loadedPages: loadedPages
    )
  }

  public func saveCheckpoint(
    controlStepIdentifier: UInt64,
    physicalCheckpointFingerprint: UInt64
  ) throws -> MetalNumiBrainCheckpoint {
    lock.lock()
    defer { lock.unlock() }
    try requireIdle()
    return try runtime.saveCheckpoint(
      controlStepIdentifier: controlStepIdentifier,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
  }

  /// Restores into an unpublished runtime with its own private allocations.
  /// `runtime` changes only after complete checkpoint validation and both GPU
  /// restores finish successfully.
  public func loadCheckpoint(
    _ checkpoint: MetalNumiBrainCheckpoint,
    physicalCheckpointFingerprint: UInt64
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireIdle()
    let candidate = try MetalNumiBrainRuntime.makeRuntime(
      configuration: configuration,
      publication: publication,
      foundationPolicyArchitecture: foundationPolicyArchitecture,
      device: device
    )
    try candidate.loadCheckpoint(
      checkpoint,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    guard candidate.committedGeneration == checkpoint.committedGeneration,
      candidate.parameterVersionFingerprint == publication.version.fingerprint,
      candidate.compiledSpeciesTemplateFingerprint
        == compiledSpeciesTemplateFingerprint,
      candidate.deviceRegistryID == deviceRegistryID
    else {
      throw TissueError.transaction(
        "restored candidate did not publish the requested brain identity"
      )
    }
    runtime = candidate
  }

  @discardableResult
  public func transferCommittedState(
    to successor: MetalNumiBrainHandle,
    parameterCohort: MetalParameterCohort,
    controlStepIdentifier: UInt64,
    physicalCheckpointFingerprint: UInt64
  ) throws -> MetalNumiBrainCheckpoint {
    lock.lock()
    let parentCheckpoint: MetalNumiBrainCheckpoint
    let parentVersion: BrainParameterVersion
    do {
      try requireIdle()
      parentCheckpoint = try runtime.saveCheckpoint(
        controlStepIdentifier: controlStepIdentifier,
        physicalCheckpointFingerprint: physicalCheckpointFingerprint
      )
      parentVersion = publication.version
      lock.unlock()
    } catch {
      lock.unlock()
      throw error
    }
    let migratedCheckpoint = try parentCheckpoint.migrated(
      from: parentVersion,
      to: parameterCohort.publication
    )
    try successor.validate(parameterCohort: parameterCohort)
    try successor.loadCheckpoint(
      migratedCheckpoint,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    return migratedCheckpoint
  }

  /// Publishes a direct learner successor into this persistent mind at a
  /// closed rollout boundary. The old runtime remains authoritative until the
  /// migrated checkpoint has loaded into a separately allocated successor and
  /// that successor proves it consumes the exact cohort publication.
  @discardableResult
  public func activateSuccessor(
    parameterCohort: MetalParameterCohort,
    controlStepIdentifier: UInt64,
    physicalCheckpointFingerprint: UInt64
  ) throws -> MetalNumiBrainCheckpoint {
    lock.lock()
    defer { lock.unlock() }
    try requireIdle()
    let parentCheckpoint = try runtime.saveCheckpoint(
      controlStepIdentifier: controlStepIdentifier,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    let successorPublication = parameterCohort.publication
    let migratedCheckpoint = try parentCheckpoint.migrated(
      from: publication.version,
      to: successorPublication
    )
    let candidate = try MetalNumiBrainRuntime.makeRuntime(
      configuration: configuration,
      publication: successorPublication,
      foundationPolicyArchitecture: foundationPolicyArchitecture,
      device: device
    )
    try candidate.validate(parameterCohort: parameterCohort)
    try candidate.loadCheckpoint(
      migratedCheckpoint,
      physicalCheckpointFingerprint: physicalCheckpointFingerprint
    )
    guard candidate.committedGeneration
        == migratedCheckpoint.committedGeneration,
      candidate.parameterVersionFingerprint
        == successorPublication.version.fingerprint,
      candidate.compiledSpeciesTemplateFingerprint
        == compiledSpeciesTemplateFingerprint,
      candidate.deviceRegistryID == deviceRegistryID
    else {
      throw TissueError.transaction(
        "learner successor did not preserve the persistent brain identity"
      )
    }
    runtime = candidate
    publication = successorPublication
    return migratedCheckpoint
  }

  public func beginControl(
    controlStepIdentifier: UInt64,
    basePhysicsGeneration: UInt64,
    committedTimestamp: BrainTimestamp,
    targetTimestamp: BrainTimestamp,
    cachedDecisionFingerprint: UInt64
  ) throws -> ControlTransaction {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction == nil else {
      throw TissueError.transaction(
        "finish or abort active brain control before beginning another"
      )
    }
    let transaction = try runtime.beginControl(
      controlStepIdentifier: controlStepIdentifier,
      basePhysicsGeneration: basePhysicsGeneration,
      committedTimestamp: committedTimestamp,
      targetTimestamp: targetTimestamp,
      cachedDecisionFingerprint: cachedDecisionFingerprint
    )
    let owned = ControlTransaction(runtime: runtime, transaction: transaction)
    activeTransaction = owned
    return owned
  }

  @discardableResult
  public func inferAndDecide(
    _ transaction: ControlTransaction,
    numanXSensors: NumanXSensorPacketLease,
    externalGoal: ActiveGoal? = nil
  ) throws -> MetalEmbodiedBrainRuntime.DecisionBufferView {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    do {
      return try runtime.inferAndDecide(
        transaction.transaction,
        numanXSensors: numanXSensors,
        externalGoal: externalGoal
      )
    } catch {
      if !runtime.hasOpenControl { activeTransaction = nil }
      throw error
    }
  }

  public func submitInferAndDecide(
    _ transaction: ControlTransaction,
    numanXSensors: NumanXSensorPacketLease,
    externalGoal: ActiveGoal? = nil,
    waitFor waitPoint: MetalSharedEventPoint? = nil,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> MetalNumiBrainRuntime.DecisionSubmissionTicket {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    do {
      return try runtime.submitInferAndDecide(
        transaction.transaction,
        numanXSensors: numanXSensors,
        externalGoal: externalGoal,
        waitFor: waitPoint,
        signal: completionPoint
      )
    } catch {
      if !runtime.hasOpenControl { activeTransaction = nil }
      throw error
    }
  }

  @discardableResult
  public func finishInferAndDecideSubmission(
    _ ticket: MetalNumiBrainRuntime.DecisionSubmissionTicket,
    transaction: ControlTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws -> MetalEmbodiedBrainRuntime.DecisionBufferView {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    do {
      return try runtime.finishInferAndDecideSubmission(
        ticket,
        transaction: transaction.transaction,
        timeoutMilliseconds: timeoutMilliseconds
      )
    } catch {
      if !runtime.hasOpenControl { activeTransaction = nil }
      throw error
    }
  }

  public func abortInferAndDecideSubmission(
    _ ticket: MetalNumiBrainRuntime.DecisionSubmissionTicket,
    transaction: ControlTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    do {
      try runtime.abortInferAndDecideSubmission(
        ticket,
        transaction: transaction.transaction,
        timeoutMilliseconds: timeoutMilliseconds
      )
      activeTransaction = nil
    } catch {
      if !runtime.hasOpenControl { activeTransaction = nil }
      throw error
    }
  }

  @_spi(NumanXInterop)
  public func submitNumanXMotorCandidate(
    _ decisionTicket: MetalNumiBrainRuntime.DecisionSubmissionTicket,
    transaction: ControlTransaction,
    candidateDurationMicroseconds: UInt64,
    acceptedCulture: MetalNumanXBridgeV1Runtime.AggregateSnapshotV4? = nil,
    signal motorReadyPoint: MetalSharedEventPoint
  ) throws -> MetalNumiBrainRuntime.NumanXMotorSubmissionTicket {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    do {
      return try runtime.submitNumanXMotorCandidate(
        decisionTicket,
        transaction: transaction.transaction,
        candidateDurationMicroseconds: candidateDurationMicroseconds,
        acceptedCulture: acceptedCulture,
        signal: motorReadyPoint
      )
    } catch {
      if !runtime.hasOpenControl { activeTransaction = nil }
      throw error
    }
  }

  public func reapNumanXMotorSubmissionIfCompleted(
    _ ticket: MetalNumiBrainRuntime.NumanXMotorSubmissionTicket,
    transaction: ControlTransaction
  ) throws -> MetalTissueRuntime.FastSystemResult? {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    do {
      return try runtime.reapNumanXMotorSubmissionIfCompleted(
        ticket,
        transaction: transaction.transaction
      )
    } catch {
      if !runtime.hasOpenControl { activeTransaction = nil }
      throw error
    }
  }

  public func finishNumanXMotorSubmission(
    _ ticket: MetalNumiBrainRuntime.NumanXMotorSubmissionTicket,
    transaction: ControlTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws -> MetalTissueRuntime.FastSystemResult {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    do {
      return try runtime.finishNumanXMotorSubmission(
        ticket,
        transaction: transaction.transaction,
        timeoutMilliseconds: timeoutMilliseconds
      )
    } catch {
      if !runtime.hasOpenControl { activeTransaction = nil }
      throw error
    }
  }

  public func advanceFastSystems(
    _ transaction: ControlTransaction,
    candidateDurationMicroseconds: UInt64
  ) throws -> MetalTissueRuntime.FastSystemResult {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    return try runtime.advanceFastSystems(
      transaction.transaction,
      candidateDurationMicroseconds: candidateDurationMicroseconds
    )
  }

  public func borrowNumanXMotorBuffers(
    _ transaction: ControlTransaction,
    fastSystems: MetalTissueRuntime.FastSystemResult
  ) throws -> MetalTissueRuntime.NumanXMotorBufferLease {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    return try runtime.borrowNumanXMotorBuffers(
      transaction.transaction,
      fastSystems: fastSystems
    )
  }

  public func borrowEmbodiedCommandBuffers(
    _ transaction: ControlTransaction
  ) throws -> MetalEmbodiedBrainRuntime.NumanXSomaticBufferLease {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    return try runtime.borrowEmbodiedCommandBuffers(transaction.transaction)
  }

  public func acceptPhysicsSubstep(
    _ transaction: ControlTransaction,
    accepted: AcceptedPhysicsStateToken,
    receptorEvents: [BrainInterruptEvent] = [],
    localizedMuscleLoadObservations: [LocalizedMuscleLoadReceptorObservation] = []
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    try runtime.acceptPhysicsSubstep(
      transaction.transaction,
      accepted: accepted,
      receptorEvents: receptorEvents,
      localizedMuscleLoadObservations: localizedMuscleLoadObservations
    )
  }

  public func rejectPhysicsSubstep(
    _ transaction: ControlTransaction,
    receptorEvents: [BrainInterruptEvent] = []
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    try runtime.rejectPhysicsSubstep(
      transaction.transaction,
      receptorEvents: receptorEvents
    )
  }

  /// Starts the production no-host-token path. The returned ticket owns only
  /// the unpublished fast preparation and its exact device timeline points.
  public func submitProvisionalAcceptedFastRoot(
    _ transaction: ControlTransaction,
    waitFor physicalPreparedPoint: MetalSharedEventPoint,
    signal fastPreparedPoint: MetalSharedEventPoint
  ) throws -> MetalTissueRuntime.ProvisionalFastRootSubmissionTicket {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    do {
      return try runtime.submitProvisionalAcceptedFastRoot(
        transaction.transaction,
        waitFor: physicalPreparedPoint,
        signal: fastPreparedPoint
      )
    } catch {
      if !runtime.hasOpenControl { activeTransaction = nil }
      throw error
    }
  }

  /// Diagnostic/teardown boundary. A timeout keeps the handle and all GPU
  /// leases active because it is not evidence that the fast queue completed.
  public func abortProvisionalAcceptedFastRootSubmission(
    _ ticket: MetalTissueRuntime.ProvisionalFastRootSubmissionTicket,
    transaction: ControlTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    do {
      try runtime.abortProvisionalAcceptedFastRootSubmission(
        ticket,
        transaction: transaction.transaction,
        timeoutMilliseconds: timeoutMilliseconds
      )
      activeTransaction = nil
    } catch {
      if !runtime.hasOpenControl { activeTransaction = nil }
      throw error
    }
  }

  /// Extends the exact provisional fast ticket into an unpublished cognitive
  /// consequence and end witness. Candidate addresses remain private.
  public func submitNumanXPreparedControl(
    _ transaction: ControlTransaction,
    provisionalFast ticket: MetalTissueRuntime.ProvisionalFastRootSubmissionTicket,
    identity: MetalNumanXHumanMatterRootIdentity,
    acceptedPhysicsGate: MetalAcceptedPhysicsGateLease,
    sensorCandidate: MetalNumanXPendingSensorCandidateLease,
    culturePrepared: MetalNumanXCulturePreparedLease? = nil,
    developmentalIntents: MetalDevelopmentalCapabilityIntentBufferLease? = nil,
    teacherState: MetalTeacherStateBufferLease? = nil,
    signal brainPreparedPoint: MetalSharedEventPoint,
    thenSignal preflightReadyPoint: MetalSharedEventPoint
  ) throws -> MetalNumiBrainRuntime.NumanXPreparedControlTicket {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    if let foundationPolicyArchitecture {
      guard identity.programFingerprint
        == foundationPolicyArchitecture.ownerProgramFingerprint
      else {
        throw TissueError.transaction(
          "NumanX owner program does not match the admitted foundation policy"
        )
      }
    }
    do {
      return try runtime.submitNumanXPreparedControl(
        transaction.transaction,
        provisionalFast: ticket,
        identity: identity,
        acceptedPhysicsGate: acceptedPhysicsGate,
        sensorCandidate: sensorCandidate,
        culturePrepared: culturePrepared,
        developmentalIntents: developmentalIntents,
        teacherState: teacherState,
        signal: brainPreparedPoint,
        thenSignal: preflightReadyPoint
      )
    } catch {
      if !runtime.hasOpenControl { activeTransaction = nil }
      throw error
    }
  }

  /// Explicit NumanX interop step. Raw proposal/ACK ranges remain owned by the
  /// retained low-level ticket and never become ordinary Brain state.
  @discardableResult
  @_spi(NumanXInterop)
  public func submitNumanXBrainAck(
    _ ticket: MetalNumiBrainRuntime.NumanXPreparedControlTicket,
    transaction: ControlTransaction,
    proposal: MetalNumanXHumanMatterProposalLease,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> MetalNumanXHumanMatterBrainAckTicket {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    return try runtime.submitNumanXBrainAck(
      ticket,
      proposal: proposal,
      signal: completionPoint
    )
  }

  /// Returns the host-retained joint close identity only after the exact
  /// prepared root has completed every Brain preflight. The bridge uses this
  /// scalar to reserve the owner publication fence; no GPU payload is read.
  @_spi(NumanXInterop)
  public func numanXPreparedJointCommitFingerprint(
    _ ticket: MetalNumiBrainRuntime.NumanXPreparedControlTicket,
    transaction: ControlTransaction,
    identity: MetalNumanXHumanMatterRootIdentity
  ) throws -> UInt64 {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    return try runtime.numanXPreparedJointCommitFingerprint(
      for: ticket, identity: identity
    )
  }

  /// Starts nonpublishing applied-root validation. The low-level GPU callback
  /// owns Brain commit/reject; this wrapper installs its owning-handle cleanup
  /// only after releasing `lock`, because registration may invoke immediately.
  @discardableResult
  @_spi(NumanXInterop)
  public func validateNumanXAppliedRoot(
    _ ticket: MetalNumiBrainRuntime.NumanXPreparedControlTicket,
    transaction: ControlTransaction,
    ack ackTicket: MetalNumanXHumanMatterBrainAckTicket,
    applied: MetalNumanXHumanMatterAppliedLease,
    resolution: MetalNumanXJointResolutionReservation,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> MetalNumanXHumanMatterAppliedValidationTicket {
    let validationTicket: MetalNumanXHumanMatterAppliedValidationTicket
    lock.lock()
    do {
      try requireActive(transaction)
      validationTicket = try runtime.validateNumanXAppliedRoot(
        ticket,
        ack: ackTicket,
        applied: applied,
        resolution: resolution,
        signal: completionPoint
      )
      lock.unlock()
    } catch {
      lock.unlock()
      throw error
    }

    // This registration is deliberately outside the nonrecursive handle lock.
    // A terminal GPU callback that beat registration invokes synchronously.
    _ = ticket.registerOwningHandleTerminalRelease {
      [weak self, weak transaction] in
      guard let self, let transaction else { return }
      self.numanXTerminalReleaseQueue.async { [weak self, weak transaction] in
        guard let self, let transaction else { return }
        self.settleNumanXHandleTerminalRelease(transaction)
      }
    }
    return validationTicket
  }

  public func abortNumanXPreparedControl(
    _ ticket: MetalNumiBrainRuntime.NumanXPreparedControlTicket,
    transaction: ControlTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    do {
      try runtime.abortNumanXPreparedControl(
        ticket,
        timeoutMilliseconds: timeoutMilliseconds
      )
      activeTransaction = nil
    } catch {
      if !runtime.hasOpenControl { activeTransaction = nil }
      throw error
    }
  }

  public func commitControl(
    _ transaction: ControlTransaction,
    acceptedSensors: NumanXSensorPacketLease,
    schedulerEvents: [BrainInterruptEvent] = [],
    developmentalEvidence: MetalDevelopmentalEvidenceBufferLease? = nil,
    teacherState: MetalTeacherStateBufferLease? = nil
  ) throws -> CommitResult {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    do {
      let result = try runtime.commitControl(
        transaction.transaction,
        acceptedSensors: acceptedSensors,
        schedulerEvents: schedulerEvents,
        developmentalEvidence: developmentalEvidence,
        teacherState: teacherState
      )
      activeTransaction = nil
      return result
    } catch {
      activeTransaction = nil
      throw error
    }
  }

  public func submitAcceptedControl(
    _ transaction: ControlTransaction,
    acceptedPhysicsGate: MetalAcceptedPhysicsGateLease,
    acceptedSensors: NumanXSensorPacketLease,
    developmentalEvidence: MetalDevelopmentalEvidenceBufferLease? = nil,
    teacherState: MetalTeacherStateBufferLease? = nil,
    waitFor waitPoint: MetalSharedEventPoint? = nil,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> MetalNumiBrainRuntime.CommitSubmissionTicket {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    do {
      return try runtime.submitAcceptedControl(
        transaction.transaction,
        acceptedPhysicsGate: acceptedPhysicsGate,
        acceptedSensors: acceptedSensors,
        developmentalEvidence: developmentalEvidence,
        teacherState: teacherState,
        waitFor: waitPoint,
        signal: completionPoint
      )
    } catch {
      if !runtime.hasOpenControl { activeTransaction = nil }
      throw error
    }
  }

  public func finishAcceptedControlSubmission(
    _ ticket: MetalNumiBrainRuntime.CommitSubmissionTicket,
    transaction: ControlTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws -> CommitResult {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    do {
      let result = try runtime.finishAcceptedControlSubmission(
        ticket,
        transaction: transaction.transaction,
        timeoutMilliseconds: timeoutMilliseconds
      )
      activeTransaction = nil
      return result
    } catch {
      if !runtime.hasOpenControl { activeTransaction = nil }
      throw error
    }
  }

  public func abortAcceptedControlSubmission(
    _ ticket: MetalNumiBrainRuntime.CommitSubmissionTicket,
    transaction: ControlTransaction,
    timeoutMilliseconds: UInt64 = 30_000
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    do {
      try runtime.abortAcceptedControlSubmission(
        ticket,
        transaction: transaction.transaction,
        timeoutMilliseconds: timeoutMilliseconds
      )
      activeTransaction = nil
    } catch {
      if !runtime.hasOpenControl { activeTransaction = nil }
      throw error
    }
  }

  public func abortControl(_ transaction: ControlTransaction) throws {
    lock.lock()
    defer { lock.unlock() }
    try requireActive(transaction)
    do {
      try runtime.abortControl(transaction.transaction)
      activeTransaction = nil
    } catch {
      if !runtime.hasOpenControl { activeTransaction = nil }
      throw error
    }
  }

  private func requireIdle() throws {
    guard activeTransaction == nil, !runtime.hasOpenControl else {
      throw TissueError.transaction(
        "operation requires a closed complete-brain control root"
      )
    }
  }

  private func settleNumanXHandleTerminalRelease(
    _ transaction: ControlTransaction
  ) {
    lock.lock()
    defer { lock.unlock() }
    guard activeTransaction === transaction, !runtime.hasOpenControl else {
      return
    }
    activeTransaction = nil
  }

  private func requireActive(_ transaction: ControlTransaction) throws {
    guard activeTransaction === transaction,
      transaction.runtime === runtime,
      runtime.hasOpenControl
    else {
      throw TissueError.transaction(
        "brain control transaction is stale or belongs to another runtime generation"
      )
    }
  }
}

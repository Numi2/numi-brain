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
      transaction.status
    }
    public var decision: MetalEmbodiedBrainRuntime.DecisionBufferView? {
      transaction.decision
    }
    public var activeSubstep: BrainJointSubstepToken? {
      transaction.activeSubstep
    }
    public var lastAcceptedPhysicsState: AcceptedPhysicsStateToken? {
      transaction.lastAcceptedPhysicsState
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
  private let device: any MTLDevice
  private var runtime: MetalNumiBrainRuntime
  private var activeTransaction: ControlTransaction?

  init(
    runtime: MetalNumiBrainRuntime,
    configuration: MetalNumiBrainConfiguration,
    publication: BrainParameterPublication,
    device: any MTLDevice
  ) {
    self.runtime = runtime
    self.configuration = configuration
    self.publication = publication
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

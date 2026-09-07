import Dispatch
import Foundation
import NumiBrainCore
import NumiBrainQualification

/// Sequential native collector binding measured wall intervals to the exact
/// terminal root transcript returned by MetalNumanXGateCRootRunner. This first
/// production-facing adapter is intentionally single-environment: it must not
/// fabricate a batched performance result by cloning environment zero.
///
/// A thrown/indeterminate root permanently invalidates this collector because
/// the current Gate C capture surface does not issue an authenticated terminal
/// command-failure transcript. Callers retain that failure separately and start
/// a fresh collector after verified recovery.
@available(macOS 26.0, *)
@_spi(NumanXInterop)
public final class MetalNumanXPerformanceAttemptCollector: @unchecked Sendable {
  public struct Configuration: Sendable {
    public let protocolSHA256: String
    public let sourceRevision: String
    public let binarySHA256: String
    public let metallibSHA256: String
    public let hardware: QualificationHardwareIdentity
    public let workload: PerformanceWorkloadIdentity
    public let warmupRootsPerEnvironment: UInt64

    public init(protocolSHA256: String, sourceRevision: String,
      binarySHA256: String, metallibSHA256: String,
      hardware: QualificationHardwareIdentity, workload: PerformanceWorkloadIdentity,
      warmupRootsPerEnvironment: UInt64) throws {
      self.protocolSHA256 = protocolSHA256; self.sourceRevision = sourceRevision
      self.binarySHA256 = binarySHA256; self.metallibSHA256 = metallibSHA256
      self.hardware = hardware; self.workload = workload
      self.warmupRootsPerEnvironment = warmupRootsPerEnvironment
      try validate()
    }

    public func validate() throws {
      try hardware.validate(); try workload.validate()
      guard [protocolSHA256, binarySHA256, metallibSHA256]
        .allSatisfy(PerformanceRunArtifact.isSHA256),
        !sourceRevision.isEmpty, sourceRevision.utf8.count <= 256,
        workload.environmentCount == 1, warmupRootsPerEnvironment > 0 else {
        throw QualificationError.invalid("invalid native Gate E collector configuration")
      }
    }
  }

  public let configuration: Configuration
  private let runner: MetalNumanXGateCRootRunner
  private let lock = NSLock()
  private var attempts: [PerformanceAttemptObservation] = []
  private var invalidated = false
  private let measurementStartNanoseconds: UInt64

  public init(runner: MetalNumanXGateCRootRunner, configuration: Configuration) throws {
    try configuration.validate()
    self.runner = runner; self.configuration = configuration
    measurementStartNanoseconds = DispatchTime.now().uptimeNanoseconds
  }

  public var attemptedRootCount: UInt64 {
    lock.lock(); defer { lock.unlock() }
    return UInt64(attempts.count)
  }

  public var isInvalidated: Bool {
    lock.lock(); defer { lock.unlock() }
    return invalidated
  }

  public func runRoot(controlStep: UInt32,
    coordinates: BrainPolicyNumanXDatasetCoordinates,
    externalGoal: ActiveGoal? = nil,
    externalGoalProvider: ((BrainTimestamp, BrainTimestamp) throws -> ActiveGoal)? = nil,
    activeSensingCommandScale: Float = 1,
    sensorIntervention: MetalNumanXGateCRootRunner.SensorIntervention = .none,
    hardSafetyIntervention: MetalNumanXGateCRootRunner.HardSafetyIntervention = .none,
    longHorizonContext: MetalNumanXGateCRootRunner.LongHorizonRootContext? = nil) throws
    -> MetalNumanXGateCRootRunner.RootResult {
    lock.lock()
    guard !invalidated else { lock.unlock(); throw QualificationError.invalid("native Gate E collector requires recovery") }
    let attemptIdentifier = UInt64(attempts.count) + 1
    lock.unlock()
    let wallStart = DispatchTime.now().uptimeNanoseconds
    let result: MetalNumanXGateCRootRunner.RootResult
    do {
      result = try runner.runRoot(controlStep: controlStep, coordinates: coordinates,
        externalGoal: externalGoal, externalGoalProvider: externalGoalProvider,
        activeSensingCommandScale: activeSensingCommandScale,
        sensorIntervention: sensorIntervention,
        hardSafetyIntervention: hardSafetyIntervention,
        longHorizonContext: longHorizonContext)
    } catch {
      lock.lock(); invalidated = true; lock.unlock()
      throw error
    }
    let rawEnd = DispatchTime.now().uptimeNanoseconds
    let wallEnd = rawEnd > wallStart ? rawEnd : wallStart + 1
    let sample = result.sample.artifact
    guard sample.targetTimestampMicroseconds - sample.committedTimestampMicroseconds
      == UInt64(configuration.workload.timestepMicroseconds),
      result.execution.controlStep == controlStep,
      result.execution.transactionFingerprint == sample.transactionFingerprint else {
      lock.lock(); invalidated = true; lock.unlock()
      throw QualificationError.invalid("native Gate E root differs from declared workload or retained transaction")
    }
    let outcome: PerformanceAttemptOutcome
    let publishedGeneration: UInt64
    let publishedTime: UInt64
    switch result.execution.outcome {
    case .accepted:
      outcome = .accepted
      let (next, overflow) = sample.basePhysicsGeneration.addingReportingOverflow(1)
      guard !overflow else {
        lock.lock(); invalidated = true; lock.unlock()
        throw QualificationError.invalid("native Gate E generation overflow")
      }
      publishedGeneration = next; publishedTime = sample.targetTimestampMicroseconds
    case .rejected:
      outcome = .rejected
      publishedGeneration = sample.basePhysicsGeneration
      publishedTime = sample.committedTimestampMicroseconds
    case .commandFailure:
      lock.lock(); invalidated = true; lock.unlock()
      throw QualificationError.invalid("terminal command failure requires authenticated failure evidence")
    }
    let row = try PerformanceAttemptObservation(environment: 0,
      attemptIdentifier: attemptIdentifier,
      controlStepIdentifier: UInt64(controlStep),
      transactionFingerprint: sample.transactionFingerprint,
      outcome: outcome, wallStartNanoseconds: wallStart,
      wallEndNanoseconds: wallEnd, baseGeneration: sample.basePhysicsGeneration,
      publishedGeneration: publishedGeneration,
      committedTimeMicroseconds: sample.committedTimestampMicroseconds,
      targetTimeMicroseconds: sample.targetTimestampMicroseconds,
      publishedTimeMicroseconds: publishedTime,
      terminalEvidenceSHA256: result.executionArtifactSHA256)
    lock.lock()
    defer { lock.unlock() }
    guard !invalidated, attemptIdentifier == UInt64(attempts.count) + 1 else {
      invalidated = true
      throw QualificationError.invalid("native Gate E collector was used concurrently or after failure")
    }
    attempts.append(row)
    return result
  }

  /// Finalizes a diagnostic v2 ledger. Resident memory, power and counters must
  /// come from the production measurement owner; this method validates their
  /// shape but cannot authenticate how the host obtained them. The Core
  /// BrainPerformanceAttemptLedgerEvidence verifier separately binds every row
  /// to retained native terminal evidence and the exact protocol bytes.
  public func finish(peakResidentBytes: UInt64, steadyResidentBytes: UInt64,
    meanPowerWatts: Double? = nil, counters: PerformanceCounterSummary) throws
    -> PerformanceAttemptLedger {
    lock.lock(); defer { lock.unlock() }
    guard !invalidated, !attempts.isEmpty else {
      throw QualificationError.invalid("native Gate E collector has no complete trustworthy measurement")
    }
    let rawEnd = DispatchTime.now().uptimeNanoseconds
    let finalAttemptEnd = attempts.last!.wallEndNanoseconds
    let measurementEnd = max(rawEnd, finalAttemptEnd + 1)
    return try PerformanceAttemptLedger(protocolSHA256: configuration.protocolSHA256,
      sourceRevision: configuration.sourceRevision,
      binarySHA256: configuration.binarySHA256,
      metallibSHA256: configuration.metallibSHA256,
      hardware: configuration.hardware, workload: configuration.workload,
      warmupRootsPerEnvironment: configuration.warmupRootsPerEnvironment,
      measurementStartNanoseconds: measurementStartNanoseconds,
      measurementEndNanoseconds: measurementEnd, attempts: attempts,
      peakResidentBytes: peakResidentBytes, steadyResidentBytes: steadyResidentBytes,
      meanPowerWatts: meanPowerWatts, counters: counters)
  }
}

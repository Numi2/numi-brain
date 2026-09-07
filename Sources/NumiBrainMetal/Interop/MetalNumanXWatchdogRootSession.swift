import Dispatch
import NumiBrainCore
import NumiBrainQualification

/// A terminal native result is never discarded merely because its subsequent
/// watchdog file publication failed. Capture owners retain root first, then
/// stop the experiment when reportingFailure is nonnil.
@available(macOS 26.0, *)
@_spi(NumanXInterop)
public struct MetalNumanXSupervisedRootResult: Sendable {
  public let root: MetalNumanXGateCRootRunner.RootResult
  public let reportingFailure: String?
}

@available(macOS 26.0, *)
extension MetalNumanXGateCRootRunner {
  /// One configured session per sequential runner. Every root of a supervised
  /// capture must enter HERE; legacy runRoot remains available for explicitly
  /// unsupervised research. This does not globally intercept other entrypoints,
  /// add a GPU timeline, cancel stuck commands or inhibit external actuators.
  @_spi(NumanXInterop)
  public func runSupervisedRoot(
    watchdog: WatchdogOwnerFileSession,
    controlStep: UInt32,
    coordinates: BrainPolicyNumanXDatasetCoordinates,
    externalGoal: ActiveGoal? = nil,
    externalGoalProvider: ((BrainTimestamp, BrainTimestamp) throws -> ActiveGoal)? = nil,
    activeSensingCommandScale: Float = 1,
    sensorIntervention: SensorIntervention = .none,
    hardSafetyIntervention: HardSafetyIntervention = .none,
    longHorizonContext: LongHorizonRootContext? = nil
  ) throws -> MetalNumanXSupervisedRootResult {
    let permit = try watchdog.beginRoot(nowNanoseconds: DispatchTime.now().uptimeNanoseconds)
    let result: RootResult
    do {
      // The existing runner remains the ONLY authority for Brain/NumanX
      // submission, protection, rollback, publication and terminal evidence.
      result = try runRoot(controlStep: controlStep, coordinates: coordinates,
        externalGoal: externalGoal, externalGoalProvider: externalGoalProvider,
        activeSensingCommandScale: activeSensingCommandScale,
        sensorIntervention: sensorIntervention, hardSafetyIntervention: hardSafetyIntervention,
        longHorizonContext: longHorizonContext)
    } catch {
      // A thrown command or timeout does not establish an authoritative
      // rejection, even if the underlying runner attempted force-restoration.
      try? watchdog.recordIndeterminateRoot(permit)
      watchdog.failClosed()
      throw error
    }
    do {
      guard let aggregate = result.aggregate else {
        throw QualificationError.invalid("supervised root has no published aggregate; bootstrap rejection requires recovery")
      }
      let publishedFingerprint: UInt64
      if result.execution.outcome == .accepted {
        publishedFingerprint = result.execution.transactionFingerprint
      } else {
        guard result.execution.outcome == .rejected,
          let previous = watchdog.lastSettledHeartbeat,
          previous.publicGeneration == aggregate.brainGeneration else {
          throw QualificationError.invalid("supervised rejected root has no matching prior committed authority")
        }
        // A rejected candidate's fingerprint is NOT the public fingerprint.
        publishedFingerprint = previous.transactionFingerprint
      }
      try watchdog.recordSettledRoot(permit, publicGeneration: aggregate.brainGeneration,
        transactionFingerprint: publishedFingerprint,
        settledMonotonicNanoseconds: DispatchTime.now().uptimeNanoseconds,
        terminalEvidenceArtifactSHA256: result.executionArtifactSHA256)
      return MetalNumanXSupervisedRootResult(root: result, reportingFailure: nil)
    } catch {
      try? watchdog.recordIndeterminateRoot(permit)
      watchdog.failClosed()
      // This occurs OUTSIDE the native runner's rollback catch. In particular,
      // failure to write a heartbeat after commit must not attempt rollback.
      return MetalNumanXSupervisedRootResult(root: result, reportingFailure: String(describing: error))
    }
  }
}

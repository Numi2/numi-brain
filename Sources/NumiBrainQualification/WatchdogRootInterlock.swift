import Foundation

/// Submission interlock for ONE sequential native owner. The owner must obtain
/// a permit before submission and settle it only after authoritative close.
/// This class neither submits GPU work nor proves that hardware has stopped.
/// No method clears a stop: verified joint recovery needs a new owner/session.
public final class WatchdogRootInterlock: @unchecked Sendable {
  public struct Permit: Equatable, Sendable {
    fileprivate let issuer: UUID
    fileprivate let identifier: UUID
  }

  public let expectedProcessInstance: UUID
  public let enforcerInstance: UUID
  private let issuer = UUID()
  private let lock = NSLock()
  private var pending: Permit?
  private var stop: WatchdogStopRequest?
  private var failure: String?
  private var heartbeat: WatchdogHeartbeat?
  private var terminalEvidence: String?

  public init(expectedProcessInstance: UUID, enforcerInstance: UUID) {
    self.expectedProcessInstance = expectedProcessInstance
    self.enforcerInstance = enforcerInstance
  }

  public var admissionClosed: Bool {
    lock.lock(); defer { lock.unlock() }
    return stop != nil || failure != nil
  }

  public var lastSettledHeartbeat: WatchdogHeartbeat? {
    lock.lock(); defer { lock.unlock() }
    return heartbeat
  }

  public var retainedStopRequest: WatchdogStopRequest? {
    lock.lock(); defer { lock.unlock() }
    return stop
  }

  public func beginRoot() throws -> Permit {
    lock.lock(); defer { lock.unlock() }
    guard stop == nil, failure == nil, pending == nil else {
      throw QualificationError.invalid("watchdog admission is stopped, indeterminate or already executing")
    }
    let permit = Permit(issuer: issuer, identifier: UUID())
    pending = permit
    return permit
  }

  /// A stop can arrive while a root is in flight. The first request closes
  /// admission immediately, but that root's truthful terminal report is still
  /// required. A malformed or foreign request closes admission too.
  public func latchStop(_ request: WatchdogStopRequest) throws {
    lock.lock(); defer { lock.unlock() }
    do {
      try request.validate()
      guard request.expectedProcessInstance == expectedProcessInstance else {
        throw QualificationError.invalid("watchdog stop targets another process instance")
      }
      if let stop {
        guard stop == request else {
          throw QualificationError.invalid("a different watchdog stop is already latched")
        }
      } else { stop = request }
    } catch {
      failure = failure ?? "invalid_or_conflicting_stop_request"
      throw error
    }
  }

  /// Transport errors are not evidence that no stop exists. Preserve the first
  /// fault and prohibit acknowledgement of an unverified settlement.
  public func failClosed() {
    lock.lock(); defer { lock.unlock() }
    failure = failure ?? "watchdog_owner_transport_or_execution_fault"
  }

  /// Only a retained native terminal artifact may supply these identities.
  /// Rejection uses the unchanged committed generation AND fingerprint, not
  /// the rejected candidate's transaction fingerprint. A heartbeat sequence
  /// advances once per reported terminal root, including restored rejections.
  @discardableResult
  public func recordSettledRoot(_ permit: Permit, publicGeneration: UInt64,
    transactionFingerprint: UInt64, settledMonotonicNanoseconds: UInt64,
    terminalEvidenceArtifactSHA256: String) throws -> WatchdogHeartbeat {
    lock.lock(); defer { lock.unlock() }
    try requirePending(permit)
    do {
      let (sequence, overflow) = (heartbeat?.sequence ?? 0).addingReportingOverflow(1)
      guard !overflow, terminalEvidenceArtifactSHA256.utf8.count == 64,
        terminalEvidenceArtifactSHA256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
        throw QualificationError.invalid("invalid watchdog terminal evidence or exhausted sequence")
      }
      let value = try WatchdogHeartbeat(processInstance: expectedProcessInstance, sequence: sequence,
        monotonicNanoseconds: settledMonotonicNanoseconds, publicGeneration: publicGeneration,
        transactionFingerprint: transactionFingerprint)
      if let previous = heartbeat {
        guard value.monotonicNanoseconds > previous.monotonicNanoseconds,
          value.publicGeneration >= previous.publicGeneration,
          value.publicGeneration != previous.publicGeneration
            || value.transactionFingerprint == previous.transactionFingerprint else {
          throw QualificationError.invalid("watchdog settlement regresses committed authority")
        }
        if value.publicGeneration > previous.publicGeneration {
          let (expected, generationOverflow) = previous.publicGeneration.addingReportingOverflow(1)
          guard !generationOverflow, value.publicGeneration == expected else {
            throw QualificationError.invalid("watchdog sequential owner skipped a public generation")
          }
        }
      }
      pending = nil; heartbeat = value; terminalEvidence = terminalEvidenceArtifactSHA256
      return value
    } catch {
      pending = nil; failure = failure ?? "indeterminate_native_root_settlement"
      throw error
    }
  }

  /// A thrown/timeout root is NOT an authoritative restored rejection. No
  /// acknowledgement is emitted until an external recovery owner resolves it.
  public func recordIndeterminateRoot(_ permit: Permit) throws {
    lock.lock(); defer { lock.unlock() }
    try requirePending(permit)
    pending = nil; failure = failure ?? "indeterminate_native_root_outcome"
  }

  /// This reports only quiescence of this session's simulation root admission.
  /// It cannot report externalActuatorsInhibited. It cannot clear any fault.
  public func makeSimulationAcknowledgement(nowNanoseconds: UInt64) throws -> WatchdogStopAcknowledgement {
    lock.lock(); defer { lock.unlock() }
    guard let stop, pending == nil, failure == nil, let heartbeat, let terminalEvidence else {
      throw QualificationError.invalid("watchdog stop has no determinate, drained native settlement")
    }
    return try WatchdogStopAcknowledgement(request: stop, enforcerInstance: enforcerInstance,
      effect: .simulationRootsQuiesced, settledHeartbeat: heartbeat,
      acknowledgedMonotonicNanoseconds: nowNanoseconds, terminalEvidenceArtifactSHA256: terminalEvidence)
  }

  private func requirePending(_ permit: Permit) throws {
    guard permit.issuer == issuer, pending == permit else {
      throw QualificationError.invalid("watchdog root permit is foreign, consumed or superseded")
    }
  }
}

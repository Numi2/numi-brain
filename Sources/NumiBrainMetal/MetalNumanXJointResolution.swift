import Foundation
@preconcurrency import Metal
import NumiBrainCore

@available(macOS 26.0, *)
@_spi(NumanXInterop)
public enum MetalNumanXJointResolutionDisposition: UInt32, Sendable {
  case released = 1
  case terminalNoTouch = 2
}

/// Opaque result of fallibly reserving the exact owner publication fence,
/// applied-output ranges, Matter root release, and HumanIO candidate swap.
/// Construction happens before final Brain validation. Consuming either
/// closure is allocation-free, nonwaiting, and nonthrowing.
///
/// Lock order is strict: Brain runtime lock -> bridge public-reader gate. The
/// accepted action must latch the generation supplied by its callback and may
/// not re-enter Brain while holding the bridge gate. Aggregate readers take
/// the Brain lock first and consume that latched value without a callback.
@available(macOS 26.0, *)
@_spi(NumanXInterop)
public final class MetalNumanXJointResolutionReservation: @unchecked Sendable {
  /// Returns `true` only for the first exact Brain-generation latch. The
  /// bridge must call this before making Matter or HumanIO externally visible
  /// and may return `.released` only after observing `true` exactly once.
  public typealias PublishBrainGeneration = @Sendable () -> Bool
  public typealias AcceptedResolution = @Sendable (
    PublishBrainGeneration
  ) -> MetalNumanXJointResolutionDisposition
  public typealias RejectedResolution = @Sendable ()
    -> MetalNumanXJointResolutionDisposition

  let identity: MetalNumanXHumanMatterRootIdentity
  let proposal: MetalNumanXHumanMatterProposalLease
  let applied: MetalNumanXHumanMatterAppliedLease
  let sensorCandidate: MetalNumanXPendingSensorCandidateLease
  let jointCommitFingerprint: UInt64
  let brainGeneration: UInt64
  let reservationFingerprint: UInt64

  private let lock = NSLock()
  private var consumed = false
  private let releaseAcceptedAction: AcceptedResolution
  private let releaseRejectedAction: RejectedResolution

  public init(
    identity: MetalNumanXHumanMatterRootIdentity,
    proposal: MetalNumanXHumanMatterProposalLease,
    applied: MetalNumanXHumanMatterAppliedLease,
    sensorCandidate: MetalNumanXPendingSensorCandidateLease,
    jointCommitFingerprint: UInt64,
    brainGeneration: UInt64,
    releaseAccepted: @escaping AcceptedResolution,
    releaseRejected: @escaping RejectedResolution
  ) throws {
    let fenceStart = proposal.publicationFenceGPUAddress
    let appliedStart = applied.appliedGPUAddress
    let tokenStart = applied.finalTokenGPUAddress
    let fenceEnd = try Self.checkedEnd(
      fenceStart, count: MetalNumanXHumanMatterProposalLease.fenceByteCount
    )
    let appliedEnd = try Self.checkedEnd(
      appliedStart, count: MetalNumanXHumanMatterAppliedLease.outcomeByteCount
    )
    let tokenEnd = try Self.checkedEnd(
      tokenStart, count: MetalNumanXHumanMatterAppliedLease.tokenByteCount
    )
    guard proposal.identity == identity, applied.identity == identity,
      sensorCandidate.transactionFingerprint == identity.transactionFingerprint,
      sensorCandidate.acceptedBrainGeneration == brainGeneration,
      brainGeneration > 0,
      (applied.commandDisposition != .acceptedPendingPublication
        || jointCommitFingerprint > 0),
      !Self.overlaps(fenceStart, fenceEnd, appliedStart, appliedEnd),
      !Self.overlaps(fenceStart, fenceEnd, tokenStart, tokenEnd),
      !Self.overlaps(appliedStart, appliedEnd, tokenStart, tokenEnd)
    else {
      throw TissueError.transaction(
        "NumanX joint-resolution reservation is stale or aliases authority ranges"
      )
    }
    self.identity = identity
    self.proposal = proposal
    self.applied = applied
    self.sensorCandidate = sensorCandidate
    self.jointCommitFingerprint = jointCommitFingerprint
    self.brainGeneration = brainGeneration
    self.releaseAcceptedAction = releaseAccepted
    self.releaseRejectedAction = releaseRejected
    reservationFingerprint = Self.makeFingerprint(
      identity: identity,
      jointCommitFingerprint: jointCommitFingerprint,
      brainGeneration: brainGeneration,
      sensorCandidateFingerprint: sensorCandidate.publicationFingerprint,
      fenceGPUAddress: fenceStart,
      appliedGPUAddress: appliedStart,
      tokenGPUAddress: tokenStart
    )
  }

  func validate(
    proposal: MetalNumanXHumanMatterProposalLease,
    applied: MetalNumanXHumanMatterAppliedLease,
    sensorCandidate: MetalNumanXPendingSensorCandidateLease,
    jointCommitFingerprint: UInt64,
    brainGeneration: UInt64
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    guard !consumed, self.proposal === proposal, self.applied === applied,
      self.sensorCandidate === sensorCandidate,
      self.jointCommitFingerprint == jointCommitFingerprint,
      self.brainGeneration == brainGeneration,
      reservationFingerprint > 0
    else {
      throw TissueError.transaction(
        "NumanX joint-resolution reservation does not match the active close"
      )
    }
  }

  func releaseAccepted(
    publishingBrainGeneration publish: @escaping PublishBrainGeneration
  ) -> MetalNumanXJointResolutionDisposition {
    lock.lock()
    guard !consumed else {
      lock.unlock()
      return .terminalNoTouch
    }
    consumed = true
    lock.unlock()
    return releaseAcceptedAction(publish)
  }

  func releaseRejected() -> MetalNumanXJointResolutionDisposition {
    lock.lock()
    guard !consumed else {
      lock.unlock()
      return .terminalNoTouch
    }
    consumed = true
    lock.unlock()
    return releaseRejectedAction()
  }

  private static func checkedEnd(_ start: UInt64, count: Int) throws -> UInt64 {
    let (end, overflow) = start.addingReportingOverflow(UInt64(count))
    guard start > 0, count > 0, !overflow, start < end else {
      throw TissueError.transaction("NumanX resolution interval overflows")
    }
    return end
  }

  private static func overlaps(
    _ aStart: UInt64,
    _ aEnd: UInt64,
    _ bStart: UInt64,
    _ bEnd: UInt64
  ) -> Bool {
    aStart < bEnd && bStart < aEnd
  }

  private static func makeFingerprint(
    identity: MetalNumanXHumanMatterRootIdentity,
    jointCommitFingerprint: UInt64,
    brainGeneration: UInt64,
    sensorCandidateFingerprint: UInt64,
    fenceGPUAddress: UInt64,
    appliedGPUAddress: UInt64,
    tokenGPUAddress: UInt64
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    let prime: UInt64 = 1_099_511_628_211
    func mix<T: FixedWidthInteger>(_ value: T) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { bytes in
        for byte in bytes { hash = (hash ^ UInt64(byte)) &* prime }
      }
    }
    mix(UInt32(0x4e58_4a52))  // "NXJR"
    mix(identity.programFingerprint)
    mix(identity.transactionFingerprint)
    mix(identity.linearizationEpoch)
    mix(identity.slotGeneration)
    mix(identity.transactionSlot)
    mix(identity.controlStep)
    mix(jointCommitFingerprint)
    mix(brainGeneration)
    mix(sensorCandidateFingerprint)
    mix(fenceGPUAddress)
    mix(appliedGPUAddress)
    mix(tokenGPUAddress)
    return hash == 0 ? 14_695_981_039_346_656_037 : hash
  }
}

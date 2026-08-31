import Foundation
@preconcurrency import Metal
import NumiBrainABI
import NumiBrainCore

// Canonical unshipped ABI4 Human-Matter close; no prior wire ABI is retained.

@available(macOS 26.0, *)
struct NumanXGPUInterval: Equatable, Sendable {
  let start: UInt64
  let end: UInt64

  init(buffer: any MTLBuffer, offset: Int, count: Int) throws {
    guard offset >= 0, count > 0, buffer.gpuAddress > 0 else {
      throw TissueError.transaction("NumanX GPU interval is empty or negative")
    }
    let (hostEnd, hostOverflow) = offset.addingReportingOverflow(count)
    let (start, startOverflow) = buffer.gpuAddress.addingReportingOverflow(
      UInt64(offset)
    )
    let (end, endOverflow) = start.addingReportingOverflow(UInt64(count))
    guard !hostOverflow, !startOverflow, !endOverflow,
      hostEnd <= buffer.length, start < end
    else {
      throw TissueError.transaction("NumanX GPU interval overflows")
    }
    self.start = start
    self.end = end
  }

  func overlaps(_ other: Self) -> Bool {
    start < other.end && other.start < end
  }
}

@available(macOS 26.0, *)
@frozen
public enum MetalNumanXHumanMatterRootDecision: UInt32, Sendable {
  case accept = 1
  case reject = 2
}

/// Exact ABI4 root identity shared by physical prepare, Brain consequence
/// preparation, mutation-free proposal, Brain ACK, physical apply, and the
/// final publication fence. `controlStep` is the global root identifier; the
/// local Human `stepIndex` remains zero in the single-substep production ABI.
@available(macOS 26.0, *)
@frozen
public struct MetalNumanXHumanMatterRootIdentity: Equatable, Hashable, Sendable {
  public let programFingerprint: UInt64
  public let transactionFingerprint: UInt64
  public let linearizationEpoch: UInt64
  public let slotGeneration: UInt64
  public let transactionSlot: UInt32
  public let environment: UInt32
  public let stepIndex: UInt32
  public let controlStep: UInt32
  public let substepIndex: UInt32
  public let physicsSubstepCount: UInt32

  public init(
    programFingerprint: UInt64,
    transactionFingerprint: UInt64,
    linearizationEpoch: UInt64,
    slotGeneration: UInt64,
    transactionSlot: UInt32,
    environment: UInt32,
    stepIndex: UInt32 = 0,
    controlStep: UInt32,
    substepIndex: UInt32 = 0,
    physicsSubstepCount: UInt32 = 1
  ) throws {
    guard programFingerprint > 0, transactionFingerprint > 0,
      linearizationEpoch > 0, slotGeneration > 0,
      environment == 0, stepIndex == 0, substepIndex == 0,
      physicsSubstepCount == 1
    else {
      throw TissueError.transaction(
        "NumanX Human-Matter ABI4 requires nonzero identities and one environment/substep"
      )
    }
    self.programFingerprint = programFingerprint
    self.transactionFingerprint = transactionFingerprint
    self.linearizationEpoch = linearizationEpoch
    self.slotGeneration = slotGeneration
    self.transactionSlot = transactionSlot
    self.environment = environment
    self.stepIndex = stepIndex
    self.controlStep = controlStep
    self.substepIndex = substepIndex
    self.physicsSubstepCount = physicsSubstepCount
  }
}

/// One immutable fast-system byte range included in the end-of-prepare digest.
/// Semantic identifiers are caller-defined, nonzero, and canonicalized into
/// ascending order by the prepare request; GPU virtual addresses never
/// participate in the content fingerprint.
@available(macOS 26.0, *)
public final class MetalNumanXBrainFastStateSource: @unchecked Sendable {
  public let byteOffset: Int
  public let byteCount: Int
  public let semanticIdentifier: UInt64

  let buffer: any MTLBuffer

  public init(
    buffer: any MTLBuffer,
    byteOffset: Int = 0,
    byteCount: Int,
    semanticIdentifier: UInt64
  ) throws {
    let (end, overflow) = byteOffset.addingReportingOverflow(byteCount)
    guard byteOffset >= 0, byteCount > 0, !overflow, end <= buffer.length,
      buffer.gpuAddress > 0, semanticIdentifier > 0
    else {
      throw TissueError.transaction("NumanX fast-state hash source is invalid")
    }
    self.buffer = buffer
    self.byteOffset = byteOffset
    self.byteCount = byteCount
    self.semanticIdentifier = semanticIdentifier
  }

  public var gpuAddress: UInt64 { buffer.gpuAddress + UInt64(byteOffset) }

  public var metalBufferObject: UnsafeMutableRawPointer {
    Unmanaged.passUnretained(buffer as AnyObject).toOpaque()
  }
}

/// Retains the fast queue's 128-byte single-producer completion gate. Event
/// advancement is liveness only: the Brain witness accepts the fast shadow
/// solely when the GPU record is exact and SUCCESS.
@available(macOS 26.0, *)
public final class MetalNumanXFastPrepareStatusLease: @unchecked Sendable {
  public static let byteCount = Int(NB_NUMANX_FAST_PREPARE_STATUS_BYTE_COUNT)

  public let byteOffset: Int
  public let readyPoint: MetalSharedEventPoint
  public let fastProgramFingerprint: UInt64
  let buffer: any MTLBuffer

  public init(
    buffer: any MTLBuffer,
    byteOffset: Int = 0,
    readyPoint: MetalSharedEventPoint,
    fastProgramFingerprint: UInt64
  ) throws {
    let (end, overflow) = byteOffset.addingReportingOverflow(Self.byteCount)
    guard byteOffset >= 0, byteOffset.isMultiple(of: 16), !overflow,
      end <= buffer.length, buffer.gpuAddress > 0,
      buffer.storageMode == .shared, fastProgramFingerprint > 0
    else {
      throw TissueError.transaction(
        "NumanX fast-prepare status must be one aligned shared 128-byte record"
      )
    }
    self.buffer = buffer
    self.byteOffset = byteOffset
    self.readyPoint = readyPoint
    self.fastProgramFingerprint = fastProgramFingerprint
  }

  public var gpuAddress: UInt64 {
    buffer.gpuAddress + UInt64(byteOffset)
  }

  public var metalBufferObject: UnsafeMutableRawPointer {
    Unmanaged.passUnretained(buffer as AnyObject).toOpaque()
  }

  func validate(for device: any MTLDevice) throws {
    try readyPoint.validate(for: device)
    guard buffer.device.registryID == device.registryID,
      buffer.storageMode == .shared,
      gpuAddress == buffer.gpuAddress + UInt64(byteOffset),
      buffer.length - byteOffset >= Self.byteCount
    else {
      throw TissueError.transaction(
        "NumanX fast-prepare status device, address, or range is stale"
      )
    }
  }
}

/// End-of-consequence proof request. This is deliberately separate from the
/// existing accepted-physics start gate: it binds the complete unpublished
/// cognitive shadow, finalized memory journal, and an explicit fast-state list.
@available(macOS 26.0, *)
@frozen
public struct MetalNumanXBrainCommitPrepareRequest: @unchecked Sendable {
  public static let maximumFastStateSourceCount = 32
  public static let maximumHashedByteCount: UInt64 = 1 << 30
  public static let hashChunkByteCount: UInt32 = 1_024
  public static let hashTreeFanout: UInt32 = 256

  public let identity: MetalNumanXHumanMatterRootIdentity
  public let decision: MetalNumanXHumanMatterRootDecision
  public let provisionalPhysicsAcceptance: BrainProvisionalPhysicsAcceptance
  public let fastPrepareStatus: MetalNumanXFastPrepareStatusLease
  public let fastProgramFingerprint: UInt64
  public let fastStateSources: [MetalNumanXBrainFastStateSource]

  public init(
    identity: MetalNumanXHumanMatterRootIdentity,
    decision: MetalNumanXHumanMatterRootDecision = .accept,
    provisionalPhysicsAcceptance: BrainProvisionalPhysicsAcceptance,
    fastPrepareStatus: MetalNumanXFastPrepareStatusLease,
    fastStateSources: [MetalNumanXBrainFastStateSource]
  ) throws {
    guard provisionalPhysicsAcceptance.environmentIdentifier == identity.environment,
      provisionalPhysicsAcceptance.controlStep == identity.controlStep,
      provisionalPhysicsAcceptance.transactionFingerprint
        == identity.transactionFingerprint,
      provisionalPhysicsAcceptance.substepIndex == identity.substepIndex,
      provisionalPhysicsAcceptance.shadowGeneration > 0,
      provisionalPhysicsAcceptance.expectedPhysicsGeneration > 0
    else {
      throw TissueError.transaction(
        "NumanX provisional physics identity does not match the root"
      )
    }
    guard fastStateSources.count <= Self.maximumFastStateSourceCount else {
      throw TissueError.transaction("NumanX fast-state source capacity exceeded")
    }
    let sorted = fastStateSources.sorted {
      $0.semanticIdentifier < $1.semanticIdentifier
    }
    guard zip(sorted, sorted.dropFirst()).allSatisfy({
      $0.semanticIdentifier != $1.semanticIdentifier
    }) else {
      throw TissueError.transaction("NumanX fast-state semantic identifiers repeat")
    }
    var total: UInt64 = 0
    for source in sorted {
      let (next, overflow) = total.addingReportingOverflow(UInt64(source.byteCount))
      guard !overflow, next <= Self.maximumHashedByteCount else {
        throw TissueError.transaction("NumanX fast-state hash range is unbounded")
      }
      total = next
    }
    self.identity = identity
    self.decision = decision
    self.provisionalPhysicsAcceptance = provisionalPhysicsAcceptance
    self.fastPrepareStatus = fastPrepareStatus
    fastProgramFingerprint = fastPrepareStatus.fastProgramFingerprint
    self.fastStateSources = sorted
  }
}

/// Internal retained view of the owner-owned mutation-free proposal, immutable
/// proposed token, and exact 128-byte publication fence. The high-level ticket
/// never exposes these mutable ranges as public authority.
@available(macOS 26.0, *)
@_spi(NumanXInterop)
public final class MetalNumanXHumanMatterProposalLease: @unchecked Sendable {
  public static let proposalByteCount = Int(
    NB_NUMANX_HUMAN_MATTER_PROPOSAL_BYTE_COUNT
  )
  public static let tokenByteCount = Int(
    NB_NUMANX_HUMAN_MATTER_ACCEPTED_TOKEN_BYTE_COUNT
  )
  public static let fenceByteCount = Int(
    NB_NUMANX_HUMAN_MATTER_PUBLICATION_FENCE_BYTE_COUNT
  )

  public let identity: MetalNumanXHumanMatterRootIdentity
  public let proposalBuffer: any MTLBuffer
  public let proposedTokenBuffer: any MTLBuffer
  public let publicationFenceBuffer: any MTLBuffer
  public let proposalByteOffset: Int
  public let proposedTokenByteOffset: Int
  public let publicationFenceByteOffset: Int
  public let readyPoint: MetalSharedEventPoint
  let proposalInterval: NumanXGPUInterval
  let proposedTokenInterval: NumanXGPUInterval
  let publicationFenceInterval: NumanXGPUInterval

  public init(
    identity: MetalNumanXHumanMatterRootIdentity,
    proposalBuffer: any MTLBuffer,
    proposalByteOffset: Int = 0,
    proposalGPUAddress: UInt64,
    proposalElementCount: UInt64 = 1,
    proposalStride: Int = 1,
    proposedTokenBuffer: any MTLBuffer,
    proposedTokenByteOffset: Int = 0,
    proposedTokenGPUAddress: UInt64,
    proposedTokenByteCount: UInt64 = UInt64(tokenByteCount),
    proposedTokenStride: Int = tokenByteCount,
    publicationFenceBuffer: any MTLBuffer,
    publicationFenceByteOffset: Int = 0,
    publicationFenceGPUAddress: UInt64,
    publicationFenceElementCount: UInt64 = 1,
    publicationFenceStride: Int = 1,
    readyPoint: MetalSharedEventPoint
  ) throws {
    let proposalInterval = try NumanXGPUInterval(
      buffer: proposalBuffer,
      offset: proposalByteOffset,
      count: Self.proposalByteCount
    )
    let proposedTokenInterval = try NumanXGPUInterval(
      buffer: proposedTokenBuffer,
      offset: proposedTokenByteOffset,
      count: Self.tokenByteCount
    )
    let publicationFenceInterval = try NumanXGPUInterval(
      buffer: publicationFenceBuffer,
      offset: publicationFenceByteOffset,
      count: Self.fenceByteCount
    )
    guard proposalByteOffset.isMultiple(of: 16),
      proposedTokenByteOffset.isMultiple(of: 8),
      publicationFenceByteOffset.isMultiple(of: 16),
      proposalGPUAddress == proposalInterval.start,
      proposedTokenGPUAddress == proposedTokenInterval.start,
      publicationFenceGPUAddress == publicationFenceInterval.start,
      proposalElementCount == 1, proposalStride == 1,
      proposedTokenByteCount == UInt64(Self.tokenByteCount),
      proposedTokenStride == Self.tokenByteCount,
      publicationFenceElementCount == 1,
      publicationFenceStride == 1,
      publicationFenceBuffer.storageMode == .shared,
      !proposalInterval.overlaps(proposedTokenInterval),
      !proposalInterval.overlaps(publicationFenceInterval),
      !proposedTokenInterval.overlaps(publicationFenceInterval)
    else {
      throw TissueError.transaction(
        "NumanX proposal/token/fence lease does not match the exact ABI4 ranges"
      )
    }
    self.identity = identity
    self.proposalBuffer = proposalBuffer
    self.proposedTokenBuffer = proposedTokenBuffer
    self.publicationFenceBuffer = publicationFenceBuffer
    self.proposalByteOffset = proposalByteOffset
    self.proposedTokenByteOffset = proposedTokenByteOffset
    self.publicationFenceByteOffset = publicationFenceByteOffset
    self.readyPoint = readyPoint
    self.proposalInterval = proposalInterval
    self.proposedTokenInterval = proposedTokenInterval
    self.publicationFenceInterval = publicationFenceInterval
  }

  public var proposalGPUAddress: UInt64 { proposalInterval.start }
  public var proposedTokenGPUAddress: UInt64 { proposedTokenInterval.start }
  public var publicationFenceGPUAddress: UInt64 { publicationFenceInterval.start }

  func validate(for device: any MTLDevice) throws {
    try readyPoint.validate(for: device)
    guard proposalBuffer.device.registryID == device.registryID,
      proposedTokenBuffer.device.registryID == device.registryID,
      publicationFenceBuffer.device.registryID == device.registryID,
      publicationFenceBuffer.storageMode == .shared,
      proposalInterval == (try NumanXGPUInterval(
        buffer: proposalBuffer,
        offset: proposalByteOffset,
        count: Self.proposalByteCount
      )),
      proposedTokenInterval == (try NumanXGPUInterval(
        buffer: proposedTokenBuffer,
        offset: proposedTokenByteOffset,
        count: Self.tokenByteCount
      )),
      publicationFenceInterval == (try NumanXGPUInterval(
        buffer: publicationFenceBuffer,
        offset: publicationFenceByteOffset,
        count: Self.fenceByteCount
      ))
    else {
      throw TissueError.transaction("NumanX proposal lease is stale")
    }
  }
}

/// Exact host-written Brain preflight record and its later-than-prepare event.
@available(macOS 26.0, *)
final class MetalNumanXHumanMatterBrainPreflightLease: @unchecked Sendable {
  static let byteCount = Int(NB_NUMANX_HUMAN_MATTER_BRAIN_PREFLIGHT_BYTE_COUNT)

  let identity: MetalNumanXHumanMatterRootIdentity
  let buffer: any MTLBuffer
  let byteOffset: Int
  let readyPoint: MetalSharedEventPoint
  let interval: NumanXGPUInterval
  let candidatePublicationFingerprint: UInt64
  let humanIOIdentityFingerprint: UInt64

  init(
    identity: MetalNumanXHumanMatterRootIdentity,
    buffer: any MTLBuffer,
    byteOffset: Int = 0,
    gpuAddress: UInt64,
    elementCount: UInt64 = 1,
    stride: Int = 1,
    candidatePublicationFingerprint: UInt64,
    humanIOIdentityFingerprint: UInt64,
    readyPoint: MetalSharedEventPoint
  ) throws {
    let interval = try NumanXGPUInterval(
      buffer: buffer, offset: byteOffset, count: Self.byteCount
    )
    guard byteOffset.isMultiple(of: 16), gpuAddress == interval.start,
      elementCount == 1, stride == 1,
      candidatePublicationFingerprint > 0,
      humanIOIdentityFingerprint > 0,
      buffer.storageMode == .shared
    else {
      throw TissueError.transaction("NumanX Brain preflight lease is invalid")
    }
    self.identity = identity
    self.buffer = buffer
    self.byteOffset = byteOffset
    self.readyPoint = readyPoint
    self.interval = interval
    self.candidatePublicationFingerprint = candidatePublicationFingerprint
    self.humanIOIdentityFingerprint = humanIOIdentityFingerprint
  }

  var gpuAddress: UInt64 { interval.start }

  func validate(for device: any MTLDevice) throws {
    try readyPoint.validate(for: device)
    guard buffer.device.registryID == device.registryID,
      buffer.storageMode == .shared,
      interval == (try NumanXGPUInterval(
        buffer: buffer, offset: byteOffset, count: Self.byteCount
      ))
    else {
      throw TissueError.transaction("NumanX Brain preflight lease is stale")
    }
  }
}

@available(macOS 26.0, *)
final class MetalNumanXHumanMatterBrainAckLease: @unchecked Sendable {
  static let byteCount = Int(NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_BYTE_COUNT)

  let identity: MetalNumanXHumanMatterRootIdentity
  let buffer: any MTLBuffer
  let byteOffset: Int
  let readyPoint: MetalSharedEventPoint
  let interval: NumanXGPUInterval

  init(
    identity: MetalNumanXHumanMatterRootIdentity,
    buffer: any MTLBuffer,
    byteOffset: Int = 0,
    readyPoint: MetalSharedEventPoint
  ) throws {
    let interval = try NumanXGPUInterval(
      buffer: buffer, offset: byteOffset, count: Self.byteCount
    )
    guard byteOffset.isMultiple(of: 16), buffer.storageMode == .shared else {
      throw TissueError.transaction("NumanX Brain ACK lease is invalid")
    }
    self.identity = identity
    self.buffer = buffer
    self.byteOffset = byteOffset
    self.readyPoint = readyPoint
    self.interval = interval
  }

  var gpuAddress: UInt64 { interval.start }

  func validate(for device: any MTLDevice) throws {
    try readyPoint.validate(for: device)
    guard buffer.device.registryID == device.registryID,
      buffer.storageMode == .shared,
      interval == (try NumanXGPUInterval(
        buffer: buffer, offset: byteOffset, count: Self.byteCount
      ))
    else {
      throw TissueError.transaction("NumanX Brain ACK lease is stale")
    }
  }
}

@available(macOS 26.0, *)
@_spi(NumanXInterop)
public enum MetalNumanXHumanMatterAppliedCommandDisposition: UInt32, Sendable {
  case acceptedPendingPublication = 1
  case rejectedReleased = 2
  case terminalNoTouch = 3
}

/// Imported only after the owner apply completion callback has settled. The
/// event is ordering/liveness; `commandDisposition` is the independently
/// settled owner-host outcome and must agree with the GPU applied record.
@available(macOS 26.0, *)
@_spi(NumanXInterop)
public final class MetalNumanXHumanMatterAppliedLease: @unchecked Sendable {
  public static let outcomeByteCount = Int(
    NB_NUMANX_HUMAN_MATTER_APPLIED_OUTCOME_BYTE_COUNT
  )
  public static let tokenByteCount = Int(
    NB_NUMANX_HUMAN_MATTER_ACCEPTED_TOKEN_BYTE_COUNT
  )

  public let identity: MetalNumanXHumanMatterRootIdentity
  public let appliedBuffer: any MTLBuffer
  public let finalTokenBuffer: any MTLBuffer
  public let appliedByteOffset: Int
  public let finalTokenByteOffset: Int
  public let readyPoint: MetalSharedEventPoint
  public let commandDisposition: MetalNumanXHumanMatterAppliedCommandDisposition
  let appliedInterval: NumanXGPUInterval
  let finalTokenInterval: NumanXGPUInterval

  public init(
    identity: MetalNumanXHumanMatterRootIdentity,
    appliedBuffer: any MTLBuffer,
    appliedByteOffset: Int = 0,
    appliedGPUAddress: UInt64,
    appliedElementCount: UInt64 = 1,
    appliedStride: Int = 1,
    finalTokenBuffer: any MTLBuffer,
    finalTokenByteOffset: Int = 0,
    finalTokenGPUAddress: UInt64,
    finalTokenByteCount: UInt64 = UInt64(tokenByteCount),
    finalTokenStride: Int = tokenByteCount,
    readyPoint: MetalSharedEventPoint,
    commandDisposition: MetalNumanXHumanMatterAppliedCommandDisposition
  ) throws {
    let appliedInterval = try NumanXGPUInterval(
      buffer: appliedBuffer,
      offset: appliedByteOffset,
      count: Self.outcomeByteCount
    )
    let finalTokenInterval = try NumanXGPUInterval(
      buffer: finalTokenBuffer,
      offset: finalTokenByteOffset,
      count: Self.tokenByteCount
    )
    guard appliedByteOffset.isMultiple(of: 16),
      finalTokenByteOffset.isMultiple(of: 8),
      appliedGPUAddress == appliedInterval.start,
      finalTokenGPUAddress == finalTokenInterval.start,
      appliedElementCount == 1, appliedStride == 1,
      finalTokenByteCount == UInt64(Self.tokenByteCount),
      finalTokenStride == Self.tokenByteCount,
      !appliedInterval.overlaps(finalTokenInterval)
    else {
      throw TissueError.transaction("NumanX applied outcome/token lease is invalid")
    }
    self.identity = identity
    self.appliedBuffer = appliedBuffer
    self.finalTokenBuffer = finalTokenBuffer
    self.appliedByteOffset = appliedByteOffset
    self.finalTokenByteOffset = finalTokenByteOffset
    self.readyPoint = readyPoint
    self.commandDisposition = commandDisposition
    self.appliedInterval = appliedInterval
    self.finalTokenInterval = finalTokenInterval
  }

  public var appliedGPUAddress: UInt64 { appliedInterval.start }
  public var finalTokenGPUAddress: UInt64 { finalTokenInterval.start }

  func validate(for device: any MTLDevice) throws {
    try readyPoint.validate(for: device)
    guard appliedBuffer.device.registryID == device.registryID,
      finalTokenBuffer.device.registryID == device.registryID,
      appliedInterval == (try NumanXGPUInterval(
        buffer: appliedBuffer,
        offset: appliedByteOffset,
        count: Self.outcomeByteCount
      )),
      finalTokenInterval == (try NumanXGPUInterval(
        buffer: finalTokenBuffer,
        offset: finalTokenByteOffset,
        count: Self.tokenByteCount
      ))
    else {
      throw TissueError.transaction("NumanX applied lease is stale")
    }
  }
}

@available(macOS 26.0, *)
struct MetalNumanXHumanMatterBrainAck: Equatable, Sendable {
  let status: UInt32
  let decision: UInt32
  let code: UInt32
  let identity: MetalNumanXHumanMatterRootIdentity
  let physicsTokenFingerprint: UInt64
  let proposalFingerprint: UInt64
  let preflightFingerprint: UInt64
  let fastGateFingerprint: UInt64
  let brainWitnessFingerprint: UInt64
  let brainProgramFingerprint: UInt64
  let ackFingerprint: UInt64

  var permitsPhysicalApply: Bool {
    status == NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_ACCEPT.rawValue
      && decision == NB_NUMANX_HUMAN_MATTER_ROOT_ACCEPT.rawValue
      && code == NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_SUCCESS.rawValue
  }
}

@available(macOS 26.0, *)
enum MetalNumanXHumanMatterSubmissionCompletionStatus: UInt32, Sendable {
  case completed = 1
  case gpuFailure = 2
  case invalidResult = 3
}

@available(macOS 26.0, *)
struct MetalNumanXHumanMatterBrainAckCompletion: Sendable {
  let status: MetalNumanXHumanMatterSubmissionCompletionStatus
  let feedback: MetalGPUCompletionFeedback?
  let ack: MetalNumanXHumanMatterBrainAck?
  let failureDescription: String?
}

@available(macOS 26.0, *)
enum MetalNumanXHumanMatterAppliedValidationStatus: UInt32, Sendable {
  case accept = 1
  case reject = 2
  case invalid = 3
  case terminalNoTouch = 4
}

/// Host mirror of the GPU-validated applied chain. No raw staging range is
/// exposed; ACCEPT carries every identity needed to build the exact owner
/// publication fence without rereading proposal/ACK/applied records.
@available(macOS 26.0, *)
struct MetalNumanXHumanMatterAppliedValidation: Equatable, Sendable {
  let status: MetalNumanXHumanMatterAppliedValidationStatus
  let code: UInt32
  let decision: UInt32
  let identity: MetalNumanXHumanMatterRootIdentity
  let physicsTokenFingerprint: UInt64
  let brainProgramFingerprint: UInt64
  let brainShadowStateFingerprint: UInt64
  let brainWitnessFingerprint: UInt64
  let proposalFingerprint: UInt64
  let preflightFingerprint: UInt64
  let fastGateFingerprint: UInt64
  let ackFingerprint: UInt64
  let matterApplyFingerprint: UInt64
  let appliedDecisionFingerprint: UInt64
  let fastProgramFingerprint: UInt64
  let fastTargetGeneration: UInt64
  let cognitiveTargetGeneration: UInt64
  let jointCommitFingerprint: UInt64
  let substepFingerprint: UInt64
  let commandDisposition: MetalNumanXHumanMatterAppliedCommandDisposition
  let resultFingerprint: UInt64

  var permitsJointPublication: Bool {
    status == .accept
      && commandDisposition == .acceptedPendingPublication
      && physicsTokenFingerprint != 0
  }
}

@available(macOS 26.0, *)
struct MetalNumanXHumanMatterAppliedCompletion: Sendable {
  let status: MetalNumanXHumanMatterSubmissionCompletionStatus
  let feedback: MetalGPUCompletionFeedback?
  let validation: MetalNumanXHumanMatterAppliedValidation?
  let acceptedPhysicsState: AcceptedPhysicsStateToken?
  let failureDescription: String?

  var permitsJointPublication: Bool {
    status == .completed && validation?.permitsJointPublication == true
      && acceptedPhysicsState != nil
  }
}

@available(macOS 26.0, *)
final class NumanXOneShotCompletionState<Value: Sendable>:
  @unchecked Sendable
{
  typealias Handler = @Sendable (Value) -> Void

  private let lock = NSLock()
  private var value: Value?
  private var handler: Handler?
  private var registered = false

  func register(_ handler: @escaping Handler) throws {
    let ready: Value?
    lock.lock()
    guard !registered else {
      lock.unlock()
      throw TissueError.transaction("NumanX completion callback is already registered")
    }
    registered = true
    ready = value
    if ready == nil { self.handler = handler }
    lock.unlock()
    if let ready { handler(ready) }
  }

  func complete(_ value: Value) {
    let readyHandler: Handler?
    lock.lock()
    guard self.value == nil else {
      lock.unlock()
      return
    }
    self.value = value
    readyHandler = handler
    handler = nil
    lock.unlock()
    readyHandler?(value)
  }
}

@available(macOS 26.0, *)
private struct NumanXFastStateSourceRecord {
  var gpuAddress: UInt64 = 0
  var byteCount: UInt64 = 0
  var semanticIdentifier: UInt64 = 0
  var reserved: UInt64 = 0
}

@available(macOS 26.0, *)
private struct NumanXBrainPrepareDispatchRecord {
  var abiVersion: UInt32 = 0
  var environment: UInt32 = 0
  var stepIndex: UInt32 = 0
  var substepIndex: UInt32 = 0
  var transactionSlot: UInt32 = 0
  var physicsSubstepCount: UInt32 = 0
  var fastSourceCount: UInt32 = 0
  var journalFormatVersion: UInt32 = 0
  var journalEntryCapacity: UInt32 = 0
  var rootDecision: UInt32 = 0
  var controlStep: UInt32 = 0
  var hashChunkByteCount: UInt32 = 0
  var programFingerprint: UInt64 = 0
  var transactionFingerprint: UInt64 = 0
  var linearizationEpoch: UInt64 = 0
  var slotGeneration: UInt64 = 0
  var brainProgramFingerprint: UInt64 = 0
  var hotByteCount: UInt64 = 0
  var journalByteCount: UInt64 = 0
  var memoryByteCount: UInt64 = 0
  var baseGeneration: UInt64 = 0
  var shadowGeneration: UInt64 = 0
  var fastStateTotalByteCount: UInt64 = 0
  var maximumHashByteCount: UInt64 = 0
  var totalHashByteCount: UInt64 = 0
  var hashChunkCount: UInt64 = 0
  var fastProgramFingerprint: UInt64 = 0
}

@available(macOS 26.0, *)
private struct NumanXHashReduceDispatchRecord {
  var abiVersion: UInt32 = 0
  var level: UInt32 = 0
  var inputCount: UInt32 = 0
  var outputCount: UInt32 = 0
  var fanout: UInt32 = 0
  var reserved0: UInt32 = 0
  var reserved1: UInt32 = 0
  var reserved2: UInt32 = 0
}

@available(macOS 26.0, *)
struct MetalNumanXBrainHashLayout: Equatable, Sendable {
  let totalByteCount: UInt64
  let chunkCount: UInt32
  let scratchByteCount: Int
  let reductionCounts: [UInt32]

  static func admit(
    hotByteCount: UInt64,
    journalByteCount: UInt64,
    fastByteCount: UInt64
  ) throws -> Self {
    let (hotAndJournal, firstOverflow) = hotByteCount.addingReportingOverflow(
      journalByteCount
    )
    let (total, secondOverflow) = hotAndJournal.addingReportingOverflow(
      fastByteCount
    )
    let chunkBytes = UInt64(MetalNumanXBrainCommitPrepareRequest.hashChunkByteCount)
    guard !firstOverflow, !secondOverflow, total > 0,
      total <= MetalNumanXBrainCommitPrepareRequest.maximumHashedByteCount,
      total <= UInt64.max - (chunkBytes - 1)
    else {
      throw TissueError.transaction("NumanX Brain prepare hash capacity exceeded")
    }
    let chunks64 = (total + chunkBytes - 1) / chunkBytes
    let (scratch64, scratchOverflow) = chunks64.multipliedReportingOverflow(
      by: UInt64(MemoryLayout<UInt64>.stride)
    )
    guard !scratchOverflow, chunks64 > 0, chunks64 <= UInt64(UInt32.max),
      scratch64 <= UInt64(Int.max)
    else {
      throw TissueError.transaction("NumanX Brain hash scratch capacity overflow")
    }
    var reductions: [UInt32] = []
    var input = UInt32(chunks64)
    let fanout = MetalNumanXBrainCommitPrepareRequest.hashTreeFanout
    while input > 1 {
      let output = (input + fanout - 1) / fanout
      reductions.append(output)
      input = output
    }
    return Self(
      totalByteCount: total,
      chunkCount: UInt32(chunks64),
      scratchByteCount: Int(scratch64),
      reductionCounts: reductions
    )
  }
}

@available(macOS 26.0, *)
private struct NumanXBrainAckDispatchRecord {
  var abiVersion: UInt32 = 0
  var environment: UInt32 = 0
  var stepIndex: UInt32 = 0
  var substepIndex: UInt32 = 0
  var transactionSlot: UInt32 = 0
  var physicsSubstepCount: UInt32 = 0
  var controlStep: UInt32 = 0
  var reserved0: UInt32 = 0
  var ownerProgramFingerprint: UInt64 = 0
  var transactionFingerprint: UInt64 = 0
  var linearizationEpoch: UInt64 = 0
  var slotGeneration: UInt64 = 0
  var brainProgramFingerprint: UInt64 = 0
  var fastProgramFingerprint: UInt64 = 0
  var expectedCandidatePublicationFingerprint: UInt64 = 0
  var expectedHumanIOIdentityFingerprint: UInt64 = 0
}

@available(macOS 26.0, *)
private struct NumanXAppliedValidationDispatchRecord {
  var abiVersion: UInt32 = 0
  var environment: UInt32 = 0
  var stepIndex: UInt32 = 0
  var substepIndex: UInt32 = 0
  var transactionSlot: UInt32 = 0
  var physicsSubstepCount: UInt32 = 0
  var controlStep: UInt32 = 0
  var commandDisposition: UInt32 = 0
  var reserved0: UInt32 = 0
  var reserved1: UInt32 = 0
  var reserved2: UInt32 = 0
  var reserved3: UInt32 = 0
  var ownerProgramFingerprint: UInt64 = 0
  var transactionFingerprint: UInt64 = 0
  var linearizationEpoch: UInt64 = 0
  var slotGeneration: UInt64 = 0
  var brainProgramFingerprint: UInt64 = 0
  var fastProgramFingerprint: UInt64 = 0
}

@available(macOS 26.0, *)
private struct NumanXAppliedValidationResultRecord {
  var abiVersion: UInt32 = 0
  var structBytes: UInt32 = 0
  var status: UInt32 = 0
  var code: UInt32 = 0
  var decision: UInt32 = 0
  var environment: UInt32 = 0
  var stepIndex: UInt32 = 0
  var substepIndex: UInt32 = 0
  var transactionSlot: UInt32 = 0
  var physicsSubstepCount: UInt32 = 0
  var controlStep: UInt32 = 0
  var tokenValid: UInt32 = 0
  var ownerProgramFingerprint: UInt64 = 0
  var transactionFingerprint: UInt64 = 0
  var linearizationEpoch: UInt64 = 0
  var slotGeneration: UInt64 = 0
  var physicsTokenFingerprint: UInt64 = 0
  var brainProgramFingerprint: UInt64 = 0
  var brainShadowStateFingerprint: UInt64 = 0
  var brainWitnessFingerprint: UInt64 = 0
  var proposalFingerprint: UInt64 = 0
  var preflightFingerprint: UInt64 = 0
  var fastGateFingerprint: UInt64 = 0
  var ackFingerprint: UInt64 = 0
  var matterApplyFingerprint: UInt64 = 0
  var appliedFingerprint: UInt64 = 0
  var fastProgramFingerprint: UInt64 = 0
  var fastTargetGeneration: UInt64 = 0
  var cognitiveTargetGeneration: UInt64 = 0
  var jointCommitFingerprint: UInt64 = 0
  var substepFingerprint: UInt64 = 0
  var appliedCommandDisposition: UInt64 = 0
  var reserved0: (UInt64, UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0, 0)
  var resultFingerprint: UInt64 = 0
}

@available(macOS 26.0, *)
final class MetalNumanXBrainCommitPrepareEvaluation: @unchecked Sendable {
  let request: MetalNumanXBrainCommitPrepareRequest
  let brainProgramFingerprint: UInt64
  let hashLayout: MetalNumanXBrainHashLayout
  let descriptorBuffer: any MTLBuffer
  let dispatchBuffer: any MTLBuffer
  let reduceDispatchBuffer: any MTLBuffer
  let witnessBuffer: any MTLBuffer
  let hashScratchA: any MTLBuffer
  let hashScratchB: any MTLBuffer
  let hotBuffer: any MTLBuffer
  let journalBuffer: any MTLBuffer
  let hotByteCount: Int
  let journalByteCount: Int
  let startGate: MetalAcceptedPhysicsGateEvaluation

  private let lock = NSLock()
  private var brainAckReserved = false

  init(
    request: MetalNumanXBrainCommitPrepareRequest,
    brainProgramFingerprint: UInt64,
    hashLayout: MetalNumanXBrainHashLayout,
    descriptorBuffer: any MTLBuffer,
    dispatchBuffer: any MTLBuffer,
    reduceDispatchBuffer: any MTLBuffer,
    witnessBuffer: any MTLBuffer,
    hashScratchA: any MTLBuffer,
    hashScratchB: any MTLBuffer,
    hotBuffer: any MTLBuffer,
    journalBuffer: any MTLBuffer,
    hotByteCount: Int,
    journalByteCount: Int,
    startGate: MetalAcceptedPhysicsGateEvaluation
  ) {
    self.request = request
    self.brainProgramFingerprint = brainProgramFingerprint
    self.hashLayout = hashLayout
    self.descriptorBuffer = descriptorBuffer
    self.dispatchBuffer = dispatchBuffer
    self.reduceDispatchBuffer = reduceDispatchBuffer
    self.witnessBuffer = witnessBuffer
    self.hashScratchA = hashScratchA
    self.hashScratchB = hashScratchB
    self.hotBuffer = hotBuffer
    self.journalBuffer = journalBuffer
    self.hotByteCount = hotByteCount
    self.journalByteCount = journalByteCount
    self.startGate = startGate
  }

  var residencyAllocations: [any MTLAllocation] {
    [
      descriptorBuffer, dispatchBuffer, reduceDispatchBuffer, witnessBuffer,
      hashScratchA, hashScratchB, request.fastPrepareStatus.buffer,
    ]
      + request.fastStateSources.map(\.buffer)
  }

  var hashDispatchCount: Int { 2 + hashLayout.reductionCounts.count }

  var rootHashBuffer: any MTLBuffer {
    hashLayout.reductionCounts.count.isMultiple(of: 2)
      ? hashScratchA : hashScratchB
  }

  func reserveBrainAck() throws {
    lock.lock()
    defer { lock.unlock() }
    guard !brainAckReserved else {
      throw TissueError.transaction("NumanX Brain ACK is already reserved")
    }
    brainAckReserved = true
  }

  func markWitnessPrepareFailed() {
    var witness = NBNumanXHumanMatterBrainCommitWitness()
    witness.magic = UInt32(NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_WITNESS_MAGIC)
    witness.abiVersion = UInt32(
      NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_WITNESS_ABI_VERSION
    )
    witness.structBytes = UInt32(
      NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_WITNESS_BYTE_COUNT
    )
    witness.status = NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_PREPARE_FAILED.rawValue
    witness.decision = NB_NUMANX_HUMAN_MATTER_ROOT_REJECT.rawValue
    witness.environment = request.identity.environment
    witness.stepIndex = request.identity.stepIndex
    witness.substepIndex = request.identity.substepIndex
    witness.transactionSlot = request.identity.transactionSlot
    witness.physicsSubstepCount = request.identity.physicsSubstepCount
    witness.controlStep = request.identity.controlStep
    witness.programFingerprint = request.identity.programFingerprint
    witness.transactionFingerprint = request.identity.transactionFingerprint
    witness.linearizationEpoch = request.identity.linearizationEpoch
    witness.slotGeneration = request.identity.slotGeneration
    witness.brainProgramFingerprint = brainProgramFingerprint
    witness.witnessFingerprint = MetalNumanXHumanMatterBrainRuntime.fingerprint(
      witness
    )
    withUnsafeBytes(of: &witness) { bytes in
      witnessBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
  }

  func hasValidPreparedWitness() -> Bool {
    let witness = witnessBuffer.contents().load(
      as: NBNumanXHumanMatterBrainCommitWitness.self
    )
    return witness.magic
      == UInt32(NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_WITNESS_MAGIC)
      && witness.abiVersion
        == UInt32(NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_WITNESS_ABI_VERSION)
      && witness.structBytes
        == UInt32(NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_WITNESS_BYTE_COUNT)
      && witness.status
        == NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_PREPARE_COMPLETE.rawValue
      && witness.decision == request.decision.rawValue
      && witness.environment == request.identity.environment
      && witness.stepIndex == request.identity.stepIndex
      && witness.substepIndex == request.identity.substepIndex
      && witness.transactionSlot == request.identity.transactionSlot
      && witness.physicsSubstepCount == request.identity.physicsSubstepCount
      && witness.controlStep == request.identity.controlStep
      && witness.reserved0 == 0
      && witness.programFingerprint == request.identity.programFingerprint
      && witness.transactionFingerprint
        == request.identity.transactionFingerprint
      && witness.linearizationEpoch == request.identity.linearizationEpoch
      && witness.slotGeneration == request.identity.slotGeneration
      && witness.physicsTokenFingerprint != 0
      && witness.brainProgramFingerprint == brainProgramFingerprint
      && witness.brainShadowStateFingerprint != 0
      && witness.reserved1.0 == 0 && witness.reserved1.1 == 0
      && witness.witnessFingerprint != 0
      && witness.witnessFingerprint
        == MetalNumanXHumanMatterBrainRuntime.fingerprint(witness)
  }
}

@available(macOS 26.0, *)
final class MetalNumanXBrainAckEvaluation: @unchecked Sendable {
  let dispatchBuffer: any MTLBuffer
  let ackBuffer: any MTLBuffer

  init(
    dispatchBuffer: any MTLBuffer,
    ackBuffer: any MTLBuffer
  ) {
    self.dispatchBuffer = dispatchBuffer
    self.ackBuffer = ackBuffer
  }

  func overwriteInvalidAck(
    identity: MetalNumanXHumanMatterRootIdentity,
    brainProgramFingerprint: UInt64
  ) {
    var ack = NBNumanXHumanMatterBrainAckGPU()
    ack.abiVersion = UInt32(NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_ABI_VERSION)
    ack.status = NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_INVALID.rawValue
    ack.decision = NB_NUMANX_HUMAN_MATTER_ROOT_PENDING.rawValue
    ack.code = NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_INVALID_WITNESS.rawValue
    ack.programFingerprint = identity.programFingerprint
    ack.transactionFingerprint = identity.transactionFingerprint
    ack.linearizationEpoch = identity.linearizationEpoch
    ack.slotGeneration = identity.slotGeneration
    ack.brainProgramFingerprint = brainProgramFingerprint
    ack.environment = identity.environment
    ack.stepIndex = identity.stepIndex
    ack.substepIndex = identity.substepIndex
    ack.transactionSlot = identity.transactionSlot
    ack.physicsSubstepCount = identity.physicsSubstepCount
    ack.controlStep = identity.controlStep
    ack.ackFingerprint = MetalNumanXHumanMatterBrainRuntime.fingerprint(ack)
    withUnsafeBytes(of: &ack) { bytes in
      ackBuffer.contents().copyMemory(from: bytes.baseAddress!, byteCount: bytes.count)
    }
  }
}

@available(macOS 26.0, *)
final class MetalNumanXAppliedValidationEvaluation: @unchecked Sendable {
  let dispatchBuffer: any MTLBuffer
  let resultBuffer: any MTLBuffer
  let validatedTokenBuffer: any MTLBuffer

  init(
    dispatchBuffer: any MTLBuffer,
    resultBuffer: any MTLBuffer,
    validatedTokenBuffer: any MTLBuffer
  ) {
    self.dispatchBuffer = dispatchBuffer
    self.resultBuffer = resultBuffer
    self.validatedTokenBuffer = validatedTokenBuffer
  }

  func invalidate() {
    resultBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: resultBuffer.length
    )
    validatedTokenBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: validatedTokenBuffer.length
    )
  }
}

/// Internal ACK ticket retained by the aggregate coordinator through physical
/// apply. Its raw buffer/event lease is SPI for the owner bridge, not public
/// Brain state.
@available(macOS 26.0, *)
@_spi(NumanXInterop)
public final class MetalNumanXHumanMatterBrainAckTicket: @unchecked Sendable {
  let preparedTicket: MetalEmbodiedBrainRuntime.AcceptedConsequenceSubmissionTicket
  let proposalLease: MetalNumanXHumanMatterProposalLease
  let preflightLease: MetalNumanXHumanMatterBrainPreflightLease
  let ackLease: MetalNumanXHumanMatterBrainAckLease
  let feedbackState: MetalAsyncFeedbackState
  private let resources: MetalAsyncCommandResources
  let evaluation: MetalNumanXBrainAckEvaluation
  private let completionState:
    NumanXOneShotCompletionState<MetalNumanXHumanMatterBrainAckCompletion>

  init(
    preparedTicket: MetalEmbodiedBrainRuntime.AcceptedConsequenceSubmissionTicket,
    proposalLease: MetalNumanXHumanMatterProposalLease,
    preflightLease: MetalNumanXHumanMatterBrainPreflightLease,
    ackLease: MetalNumanXHumanMatterBrainAckLease,
    feedbackState: MetalAsyncFeedbackState,
    resources: MetalAsyncCommandResources,
    evaluation: MetalNumanXBrainAckEvaluation,
    completionState:
      NumanXOneShotCompletionState<MetalNumanXHumanMatterBrainAckCompletion>
  ) {
    self.preparedTicket = preparedTicket
    self.proposalLease = proposalLease
    self.preflightLease = preflightLease
    self.ackLease = ackLease
    self.feedbackState = feedbackState
    self.resources = resources
    self.evaluation = evaluation
    self.completionState = completionState
  }

  public var hasCompleted: Bool { feedbackState.hasCompleted }

  public var ackBuffer: any MTLBuffer { ackLease.buffer }
  public var ackByteOffset: Int { ackLease.byteOffset }
  public var ackGPUAddress: UInt64 { ackLease.gpuAddress }
  public var ackReadyPoint: MetalSharedEventPoint { ackLease.readyPoint }

  func onCompleted(
    _ handler: @escaping @Sendable (MetalNumanXHumanMatterBrainAckCompletion) -> Void
  ) throws {
    try completionState.register(handler)
  }

  public func completionFeedbackIfAvailable() throws
    -> MetalGPUCompletionFeedback?
  {
    try feedbackState.poll()
  }
}

/// Non-publishing validation ticket for the owner-applied result. The exact
/// proposal/ACK/preflight/applied/token/fence leases remain retained through
/// the single completion callback. Nothing here flips a Brain generation.
@available(macOS 26.0, *)
@_spi(NumanXInterop)
public final class MetalNumanXHumanMatterAppliedValidationTicket:
  @unchecked Sendable
{
  let preparedTicket: MetalEmbodiedBrainRuntime.AcceptedConsequenceSubmissionTicket
  let ackTicket: MetalNumanXHumanMatterBrainAckTicket
  let appliedLease: MetalNumanXHumanMatterAppliedLease
  let completionPoint: MetalSharedEventPoint
  let feedbackState: MetalAsyncFeedbackState
  private let resources: MetalAsyncCommandResources
  let evaluation: MetalNumanXAppliedValidationEvaluation
  private let completionState:
    NumanXOneShotCompletionState<MetalNumanXHumanMatterAppliedCompletion>

  init(
    preparedTicket: MetalEmbodiedBrainRuntime.AcceptedConsequenceSubmissionTicket,
    ackTicket: MetalNumanXHumanMatterBrainAckTicket,
    appliedLease: MetalNumanXHumanMatterAppliedLease,
    completionPoint: MetalSharedEventPoint,
    feedbackState: MetalAsyncFeedbackState,
    resources: MetalAsyncCommandResources,
    evaluation: MetalNumanXAppliedValidationEvaluation,
    completionState:
      NumanXOneShotCompletionState<MetalNumanXHumanMatterAppliedCompletion>
  ) {
    self.preparedTicket = preparedTicket
    self.ackTicket = ackTicket
    self.appliedLease = appliedLease
    self.completionPoint = completionPoint
    self.feedbackState = feedbackState
    self.resources = resources
    self.evaluation = evaluation
    self.completionState = completionState
  }

  public var hasCompleted: Bool { feedbackState.hasCompleted }

  func onCompleted(
    _ handler: @escaping @Sendable (MetalNumanXHumanMatterAppliedCompletion) -> Void
  ) throws {
    try completionState.register(handler)
  }

  public func completionFeedbackIfAvailable() throws
    -> MetalGPUCompletionFeedback?
  {
    try feedbackState.poll()
  }
}

@available(macOS 26.0, *)
final class MetalNumanXHumanMatterBrainRuntime: @unchecked Sendable {
  private static let shaderResourceNames = [
    "AcceptedConsequence",
    "AcceptedPhysicsGate",
    "AgentStateArena",
    "CognitiveState",
    "DecisionState",
    "DevelopmentalState",
    "MemoryState",
    "NeuralTissue",
    "NumanXHumanMatterV4",
    "SensoryTransduction",
  ]

  let programFingerprint: UInt64

  private let device: any MTLDevice
  private let commandQueue: any MTL4CommandQueue
  private let hashChunkPipeline: any MTLComputePipelineState
  private let hashReducePipeline: any MTLComputePipelineState
  private let preparePipeline: any MTLComputePipelineState
  private let brainAckPipeline: any MTLComputePipelineState
  private let appliedValidationPipeline: any MTLComputePipelineState
  private let hashChunkArguments: any MTL4ArgumentTable
  private let hashReduceArguments: [any MTL4ArgumentTable]
  private let prepareArguments: any MTL4ArgumentTable
  private let brainAckArguments: any MTL4ArgumentTable
  private let appliedValidationArguments: any MTL4ArgumentTable
  private let hashScratchA: any MTLBuffer
  private let hashScratchB: any MTLBuffer
  private let maximumHashLayout: MetalNumanXBrainHashLayout
  private let lock = NSLock()

  init(
    device: any MTLDevice,
    immutableFingerprints: [(String, UInt64)]
  ) throws {
    guard MemoryLayout<NumanXFastStateSourceRecord>.stride == 32,
      MemoryLayout<NumanXBrainPrepareDispatchRecord>.stride == 168,
      MemoryLayout<NumanXHashReduceDispatchRecord>.stride == 32,
      MemoryLayout<NumanXBrainAckDispatchRecord>.stride == 96,
      MemoryLayout<NumanXAppliedValidationDispatchRecord>.stride == 96,
      MemoryLayout<NumanXAppliedValidationResultRecord>.stride == 256,
      MemoryLayout<NBNumanXHumanMatterBrainCommitWitness>.stride == 128,
      MemoryLayout<NBNumanXHumanMatterProposalGPU>.stride == 128,
      MemoryLayout<NBNumanXHumanMatterBrainCommitPreflightGPU>.stride == 128,
      MemoryLayout<NBNumanXHumanMatterBrainAckGPU>.stride == 128,
      MemoryLayout<NBNumanXHumanMatterAppliedOutcomeGPU>.stride == 128,
      MemoryLayout<NBNumanXHumanMatterJointPublicationFenceGPU>.stride == 128,
      let commandQueue = device.makeMTL4CommandQueue()
    else {
      throw TissueError.metal("NumanX Human-Matter ABI4 host layout drift")
    }

    var shaderSources: [(String, Data)] = []
    shaderSources.reserveCapacity(Self.shaderResourceNames.count)
    for name in Self.shaderResourceNames {
      guard let url = Bundle.module.url(
        forResource: name, withExtension: "metal", subdirectory: "Shaders"
      ) ?? Bundle.module.url(forResource: name, withExtension: "metal") else {
        throw TissueError.metal("\(name).metal is missing from bundled Brain program")
      }
      shaderSources.append((name, try Data(contentsOf: url)))
    }
    guard let abi4Data = shaderSources.first(where: {
      $0.0 == "NumanXHumanMatterV4"
    })?.1,
      let abi4Source = String(data: abi4Data, encoding: .utf8),
      Data(abi4Source.utf8) == abi4Data
    else {
      throw TissueError.metal("NumanX Human-Matter ABI4 shader bytes are not exact UTF-8")
    }
    let compileOptions = MTLCompileOptions()
    compileOptions.languageVersion = .version4_0
    compileOptions.mathMode = .safe
    compileOptions.mathFloatingPointFunctions = .precise
    let library: any MTLLibrary
    do {
      library = try device.makeLibrary(source: abi4Source, options: compileOptions)
    } catch {
      throw TissueError.metal("NumanX Human-Matter ABI4 Metal compilation failed: \(error)")
    }
    guard let hashChunkFunction = library.makeFunction(
      name: "hash_numanx_human_matter_brain_chunks"
    ), let hashReduceFunction = library.makeFunction(
      name: "reduce_numanx_human_matter_brain_hashes"
    ), let prepareFunction = library.makeFunction(
      name: "prepare_numanx_human_matter_brain_witness"
    ), let brainAckFunction = library.makeFunction(
      name: "ack_numanx_human_matter_brain_commit"
    ), let appliedValidationFunction = library.makeFunction(
      name: "validate_numanx_human_matter_applied_root"
    ) else {
      throw TissueError.metal("NumanX Human-Matter ABI4 kernels are missing")
    }
    do {
      hashChunkPipeline = try device.makeComputePipelineState(
        function: hashChunkFunction
      )
      hashReducePipeline = try device.makeComputePipelineState(
        function: hashReduceFunction
      )
      preparePipeline = try device.makeComputePipelineState(function: prepareFunction)
      brainAckPipeline = try device.makeComputePipelineState(
        function: brainAckFunction
      )
      appliedValidationPipeline = try device.makeComputePipelineState(
        function: appliedValidationFunction
      )
    } catch {
      throw TissueError.metal("NumanX Human-Matter ABI4 pipeline creation failed: \(error)")
    }
    maximumHashLayout = try MetalNumanXBrainHashLayout.admit(
      hotByteCount: MetalNumanXBrainCommitPrepareRequest.maximumHashedByteCount,
      journalByteCount: 0,
      fastByteCount: 0
    )
    guard let hashScratchA = device.makeBuffer(
      length: maximumHashLayout.scratchByteCount,
      options: [.storageModePrivate, .hazardTrackingModeTracked]
    ), let hashScratchB = device.makeBuffer(
      length: maximumHashLayout.scratchByteCount,
      options: [.storageModePrivate, .hazardTrackingModeTracked]
    ) else {
      throw TissueError.metal("failed to allocate bounded NumanX hash scratch")
    }
    hashScratchA.label = "NumiBrain NumanX hash scratch A"
    hashScratchB.label = "NumiBrain NumanX hash scratch B"
    self.hashScratchA = hashScratchA
    self.hashScratchB = hashScratchB
    hashChunkArguments = try Self.makeArgumentTable(
      device: device, label: "NumiBrain NumanX chunk-hash arguments", count: 5
    )
    hashReduceArguments = try maximumHashLayout.reductionCounts.indices.map { level in
      try Self.makeArgumentTable(
        device: device,
        label: "NumiBrain NumanX hash-reduce arguments level \(level)",
        count: 3
      )
    }
    prepareArguments = try Self.makeArgumentTable(
      device: device, label: "NumiBrain NumanX prepare arguments", count: 7
    )
    brainAckArguments = try Self.makeArgumentTable(
      device: device, label: "NumiBrain NumanX Brain ACK arguments", count: 8
    )
    appliedValidationArguments = try Self.makeArgumentTable(
      device: device,
      label: "NumiBrain NumanX applied-root validation arguments",
      count: 12
    )
    self.programFingerprint = Self.makeProgramFingerprint(
      shaderSources: shaderSources,
      immutableFingerprints: immutableFingerprints,
      hashScratchByteCapacity: maximumHashLayout.scratchByteCount
    )
    guard programFingerprint > 0 else {
      throw TissueError.metal("NumanX Brain program fingerprint is zero")
    }
    self.device = device
    self.commandQueue = commandQueue
  }

  func makePrepareEvaluation(
    request: MetalNumanXBrainCommitPrepareRequest,
    transaction: MetalJointAgentStateTransaction,
    substep: BrainJointSubstepToken,
    startGate: MetalAcceptedPhysicsGateEvaluation,
    hotBuffer: any MTLBuffer,
    journalBuffer: any MTLBuffer,
    fastPreparedPoint: MetalSharedEventPoint?
  ) throws -> MetalNumanXBrainCommitPrepareEvaluation {
    let identity = request.identity
    let provisional = request.provisionalPhysicsAcceptance
    try request.fastPrepareStatus.validate(for: device)
    guard let fastPreparedPoint,
      (fastPreparedPoint.event as AnyObject)
        === (request.fastPrepareStatus.readyPoint.event as AnyObject),
      fastPreparedPoint.value == request.fastPrepareStatus.readyPoint.value
    else {
      throw TissueError.transaction(
        "NumanX Brain prepare does not wait for its exact fast-status producer"
      )
    }
    let (expectedPhysicsGeneration, physicsGenerationOverflow) =
      transaction.jointToken.basePhysicsGeneration.addingReportingOverflow(1)
    let hot = try transaction.hotStateView()
    let memory = try transaction.persistentMemoryView()
    guard identity.transactionFingerprint == transaction.jointToken.fingerprint,
      identity.environment == transaction.jointToken.environmentIdentifier,
      identity.environment == 0,
      identity.stepIndex == 0,
      UInt64(identity.controlStep) == transaction.jointToken.controlStepIdentifier,
      identity.substepIndex == substep.substepIndex,
      identity.substepIndex == 0,
      identity.physicsSubstepCount == 1,
      substep.transactionFingerprint == transaction.jointToken.fingerprint,
      substep.candidateTimestamp == transaction.jointToken.targetTimestamp,
      provisional.environmentIdentifier == identity.environment,
      provisional.controlStep == identity.controlStep,
      provisional.transactionFingerprint == identity.transactionFingerprint,
      provisional.substepFingerprint == substep.fingerprint,
      provisional.substepIndex == identity.substepIndex,
      provisional.acceptedTimestamp == substep.candidateTimestamp,
      !physicsGenerationOverflow,
      provisional.expectedPhysicsGeneration == expectedPhysicsGeneration,
      provisional.shadowGeneration == transaction.agentStateToken.shadowGeneration,
      hot.outputGPUAddress == hotBuffer.gpuAddress,
      hot.byteCount == hotBuffer.length,
      memory.journalGPUAddress == journalBuffer.gpuAddress,
      memory.journalByteCount == journalBuffer.length,
      hotBuffer.device.registryID == device.registryID,
      journalBuffer.device.registryID == device.registryID
    else {
      throw TissueError.transaction("NumanX Brain prepare identity or arena is stale")
    }
    var fastTotal: UInt64 = 0
    var ranges: [(UInt64, UInt64)] = [
      try Self.range(buffer: hotBuffer, offset: 0, count: hotBuffer.length),
      try Self.range(buffer: journalBuffer, offset: 0, count: journalBuffer.length),
      try Self.range(
        buffer: startGate.resultBuffer, offset: 0, count: startGate.resultBuffer.length
      ),
      try Self.range(
        buffer: request.fastPrepareStatus.buffer,
        offset: request.fastPrepareStatus.byteOffset,
        count: MetalNumanXFastPrepareStatusLease.byteCount
      ),
      try Self.range(buffer: hashScratchA, offset: 0, count: hashScratchA.length),
      try Self.range(buffer: hashScratchB, offset: 0, count: hashScratchB.length),
    ]
    guard Self.pairwiseDisjoint(ranges) else {
      throw TissueError.transaction("NumanX Brain proof arenas alias hash scratch")
    }
    for source in request.fastStateSources {
      guard source.buffer.device.registryID == device.registryID else {
        throw TissueError.transaction("NumanX fast-state source belongs to another device")
      }
      let range = try Self.range(
        buffer: source.buffer, offset: source.byteOffset, count: source.byteCount
      )
      guard ranges.allSatisfy({ !Self.overlaps($0, range) }) else {
        throw TissueError.transaction("NumanX fast-state source aliases proof state")
      }
      ranges.append(range)
      let (next, overflow) = fastTotal.addingReportingOverflow(UInt64(source.byteCount))
      guard !overflow else {
        throw TissueError.transaction("NumanX fast-state byte count overflow")
      }
      fastTotal = next
    }
    let hashLayout = try MetalNumanXBrainHashLayout.admit(
      hotByteCount: UInt64(hot.byteCount),
      journalByteCount: UInt64(memory.journalByteCount),
      fastByteCount: fastTotal
    )
    guard hashLayout.scratchByteCount <= maximumHashLayout.scratchByteCount,
      hashLayout.reductionCounts.count <= hashReduceArguments.count,
      request.fastStateSources.count <= Int(UInt32.max),
      memory.journalByteCount >= 48,
      (memory.journalByteCount - 48) / 64 <= Int(UInt32.max)
    else {
      throw TissueError.transaction("NumanX Brain prepare hash capacity exceeded")
    }
    let descriptorLength = max(
      request.fastStateSources.count * MemoryLayout<NumanXFastStateSourceRecord>.stride,
      MemoryLayout<NumanXFastStateSourceRecord>.stride
    )
    guard let descriptorBuffer = device.makeBuffer(
      length: descriptorLength,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ), let dispatchBuffer = device.makeBuffer(
      length: MemoryLayout<NumanXBrainPrepareDispatchRecord>.stride,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ), let reduceDispatchBuffer = device.makeBuffer(
      length: max(
        hashLayout.reductionCounts.count,
        1
      ) * MemoryLayout<NumanXHashReduceDispatchRecord>.stride,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ), let witnessBuffer = device.makeBuffer(
      length: Int(NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_WITNESS_BYTE_COUNT),
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ) else {
      throw TissueError.metal("failed to allocate NumanX Brain prepare records")
    }
    descriptorBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: descriptorBuffer.length
    )
    reduceDispatchBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: reduceDispatchBuffer.length
    )
    witnessBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: witnessBuffer.length
    )
    let records = descriptorBuffer.contents().bindMemory(
      to: NumanXFastStateSourceRecord.self,
      capacity: max(request.fastStateSources.count, 1)
    )
    for (index, source) in request.fastStateSources.enumerated() {
      records[index] = NumanXFastStateSourceRecord(
        gpuAddress: source.gpuAddress,
        byteCount: UInt64(source.byteCount),
        semanticIdentifier: source.semanticIdentifier
      )
    }
    var dispatch = NumanXBrainPrepareDispatchRecord(
      abiVersion: UInt32(NB_NUMANX_HUMAN_MATTER_ABI_VERSION),
      environment: identity.environment,
      stepIndex: identity.stepIndex,
      substepIndex: identity.substepIndex,
      transactionSlot: identity.transactionSlot,
      physicsSubstepCount: identity.physicsSubstepCount,
      fastSourceCount: UInt32(request.fastStateSources.count),
      journalFormatVersion: 1,
      journalEntryCapacity: UInt32(max((memory.journalByteCount - 48) / 64, 1)),
      rootDecision: request.decision.rawValue,
      controlStep: identity.controlStep,
      hashChunkByteCount: MetalNumanXBrainCommitPrepareRequest.hashChunkByteCount,
      programFingerprint: identity.programFingerprint,
      transactionFingerprint: identity.transactionFingerprint,
      linearizationEpoch: identity.linearizationEpoch,
      slotGeneration: identity.slotGeneration,
      brainProgramFingerprint: programFingerprint,
      hotByteCount: UInt64(hot.byteCount),
      journalByteCount: UInt64(memory.journalByteCount),
      memoryByteCount: UInt64(memory.memoryByteCount),
      baseGeneration: transaction.agentStateToken.baseGeneration,
      shadowGeneration: transaction.agentStateToken.shadowGeneration,
      fastStateTotalByteCount: fastTotal,
      maximumHashByteCount: MetalNumanXBrainCommitPrepareRequest.maximumHashedByteCount,
      totalHashByteCount: hashLayout.totalByteCount,
      hashChunkCount: UInt64(hashLayout.chunkCount),
      fastProgramFingerprint: request.fastProgramFingerprint
    )
    withUnsafeBytes(of: &dispatch) { bytes in
      dispatchBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
    let reduceRecords = reduceDispatchBuffer.contents().bindMemory(
      to: NumanXHashReduceDispatchRecord.self,
      capacity: max(hashLayout.reductionCounts.count, 1)
    )
    var inputCount = hashLayout.chunkCount
    for (level, outputCount) in hashLayout.reductionCounts.enumerated() {
      reduceRecords[level] = NumanXHashReduceDispatchRecord(
        abiVersion: UInt32(NB_NUMANX_HUMAN_MATTER_ABI_VERSION),
        level: UInt32(level),
        inputCount: inputCount,
        outputCount: outputCount,
        fanout: MetalNumanXBrainCommitPrepareRequest.hashTreeFanout
      )
      inputCount = outputCount
    }
    var internalRanges = ranges
    for buffer in [descriptorBuffer, dispatchBuffer, reduceDispatchBuffer, witnessBuffer] {
      internalRanges.append(
        try Self.range(buffer: buffer, offset: 0, count: buffer.length)
      )
    }
    guard Self.pairwiseDisjoint(internalRanges) else {
      throw TissueError.transaction("NumanX Brain prepare records alias proof arenas")
    }
    descriptorBuffer.label = "NumiBrain NumanX fast-state hash descriptors"
    dispatchBuffer.label = "NumiBrain NumanX Brain-prepare dispatch"
    reduceDispatchBuffer.label = "NumiBrain NumanX hash-reduce dispatches"
    witnessBuffer.label = "NumiBrain NumanX Brain commit witness"
    return MetalNumanXBrainCommitPrepareEvaluation(
      request: request,
      brainProgramFingerprint: programFingerprint,
      hashLayout: hashLayout,
      descriptorBuffer: descriptorBuffer,
      dispatchBuffer: dispatchBuffer,
      reduceDispatchBuffer: reduceDispatchBuffer,
      witnessBuffer: witnessBuffer,
      hashScratchA: hashScratchA,
      hashScratchB: hashScratchB,
      hotBuffer: hotBuffer,
      journalBuffer: journalBuffer,
      hotByteCount: hot.byteCount,
      journalByteCount: memory.journalByteCount,
      startGate: startGate
    )
  }

  func encodePrepare(
    encoder: any MTL4ComputeCommandEncoder,
    evaluation: MetalNumanXBrainCommitPrepareEvaluation
  ) {
    let chunkCount = Int(evaluation.hashLayout.chunkCount)
    hashChunkArguments.setAddress(evaluation.hotBuffer.gpuAddress, index: 0)
    hashChunkArguments.setAddress(evaluation.journalBuffer.gpuAddress, index: 1)
    hashChunkArguments.setAddress(evaluation.descriptorBuffer.gpuAddress, index: 2)
    hashChunkArguments.setAddress(evaluation.dispatchBuffer.gpuAddress, index: 3)
    hashChunkArguments.setAddress(evaluation.hashScratchA.gpuAddress, index: 4)
    encoder.setComputePipelineState(hashChunkPipeline)
    encoder.setArgumentTable(hashChunkArguments)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: chunkCount, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(
        width: Self.threadgroupWidth(hashChunkPipeline, count: chunkCount),
        height: 1,
        depth: 1
      )
    )
    encoder.barrier(
      afterEncoderStages: .dispatch,
      beforeEncoderStages: .dispatch,
      visibilityOptions: .device
    )

    var input: any MTLBuffer = evaluation.hashScratchA
    for (level, outputCount) in evaluation.hashLayout.reductionCounts.enumerated() {
      let output: any MTLBuffer = level.isMultiple(of: 2)
        ? evaluation.hashScratchB : evaluation.hashScratchA
      let arguments = hashReduceArguments[level]
      arguments.setAddress(input.gpuAddress, index: 0)
      arguments.setAddress(output.gpuAddress, index: 1)
      arguments.setAddress(
        evaluation.reduceDispatchBuffer.gpuAddress + UInt64(
          level * MemoryLayout<NumanXHashReduceDispatchRecord>.stride
        ),
        index: 2
      )
      encoder.setComputePipelineState(hashReducePipeline)
      encoder.setArgumentTable(arguments)
      let count = Int(outputCount)
      encoder.dispatchThreads(
        threadsPerGrid: MTLSize(width: count, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(
          width: Self.threadgroupWidth(hashReducePipeline, count: count),
          height: 1,
          depth: 1
        )
      )
      encoder.barrier(
        afterEncoderStages: .dispatch,
        beforeEncoderStages: .dispatch,
        visibilityOptions: .device
      )
      input = output
    }

    prepareArguments.setAddress(evaluation.journalBuffer.gpuAddress, index: 0)
    prepareArguments.setAddress(evaluation.descriptorBuffer.gpuAddress, index: 1)
    prepareArguments.setAddress(evaluation.startGate.resultBuffer.gpuAddress, index: 2)
    prepareArguments.setAddress(evaluation.dispatchBuffer.gpuAddress, index: 3)
    prepareArguments.setAddress(evaluation.rootHashBuffer.gpuAddress, index: 4)
    prepareArguments.setAddress(
      evaluation.request.fastPrepareStatus.gpuAddress, index: 5
    )
    prepareArguments.setAddress(evaluation.witnessBuffer.gpuAddress, index: 6)
    encoder.setComputePipelineState(preparePipeline)
    encoder.setArgumentTable(prepareArguments)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
  }

  func submitBrainAck(
    preparedTicket: MetalEmbodiedBrainRuntime.AcceptedConsequenceSubmissionTicket,
    proposal: MetalNumanXHumanMatterProposalLease,
    preflight: MetalNumanXHumanMatterBrainPreflightLease,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> MetalNumanXHumanMatterBrainAckTicket {
    lock.lock()
    defer { lock.unlock() }
    guard let prepared = preparedTicket.numanXPrepareEvaluation else {
      throw TissueError.transaction("accepted consequence has no NumanX ABI4 witness")
    }
    let identity = prepared.request.identity
    try proposal.validate(for: device)
    try preflight.validate(for: device)
    guard proposal.identity == identity, preflight.identity == identity,
      (proposal.readyPoint.event as AnyObject)
        !== (preflight.readyPoint.event as AnyObject),
      (proposal.readyPoint.event as AnyObject)
        !== (completionPoint.event as AnyObject),
      (preflight.readyPoint.event as AnyObject)
        !== (completionPoint.event as AnyObject)
    else {
      throw TissueError.transaction(
        "NumanX proposal, preflight, and ACK producers must be exact and distinct"
      )
    }
    guard let dispatchBuffer = device.makeBuffer(
      length: MemoryLayout<NumanXBrainAckDispatchRecord>.stride,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ), let ackBuffer = device.makeBuffer(
      length: Int(NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_BYTE_COUNT),
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ), let allocator = device.makeCommandAllocator(),
      let commandBuffer = device.makeCommandBuffer()
    else {
      throw TissueError.metal("failed to allocate NumanX Brain ACK")
    }
    var dispatch = NumanXBrainAckDispatchRecord(
      abiVersion: UInt32(NB_NUMANX_HUMAN_MATTER_ABI_VERSION),
      environment: identity.environment,
      stepIndex: identity.stepIndex,
      substepIndex: identity.substepIndex,
      transactionSlot: identity.transactionSlot,
      physicsSubstepCount: identity.physicsSubstepCount,
      controlStep: identity.controlStep,
      ownerProgramFingerprint: identity.programFingerprint,
      transactionFingerprint: identity.transactionFingerprint,
      linearizationEpoch: identity.linearizationEpoch,
      slotGeneration: identity.slotGeneration,
      brainProgramFingerprint: programFingerprint,
      fastProgramFingerprint: prepared.request.fastProgramFingerprint,
      expectedCandidatePublicationFingerprint:
        preflight.candidatePublicationFingerprint,
      expectedHumanIOIdentityFingerprint: preflight.humanIOIdentityFingerprint
    )
    withUnsafeBytes(of: &dispatch) { bytes in
      dispatchBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
    ackBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: ackBuffer.length
    )
    dispatchBuffer.label = "NumiBrain NumanX Brain ACK dispatch"
    ackBuffer.label = "NumiBrain NumanX Brain ACK"
    let evaluation = MetalNumanXBrainAckEvaluation(
      dispatchBuffer: dispatchBuffer,
      ackBuffer: ackBuffer
    )
    let ackLease = try MetalNumanXHumanMatterBrainAckLease(
      identity: identity,
      buffer: ackBuffer,
      readyPoint: completionPoint
    )
    var intervals = try preparedIntervals(prepared)
    intervals += [
      proposal.proposalInterval,
      proposal.proposedTokenInterval,
      proposal.publicationFenceInterval,
      preflight.interval,
      try NumanXGPUInterval(
        buffer: dispatchBuffer, offset: 0, count: dispatchBuffer.length
      ),
      ackLease.interval,
    ]
    try Self.requirePairwiseDisjoint(
      intervals, label: "NumanX Brain ACK resources"
    )

    let residencySet = try makeResidencySet(
      label: "NumiBrain NumanX Brain ACK residency",
      allocations: [
        prepared.witnessBuffer,
        prepared.startGate.resultBuffer,
        prepared.request.fastPrepareStatus.buffer,
        proposal.proposalBuffer,
        proposal.proposedTokenBuffer,
        proposal.publicationFenceBuffer,
        preflight.buffer,
        dispatchBuffer,
        ackBuffer,
      ]
    )
    commandBuffer.beginCommandBuffer(allocator: allocator)
    commandBuffer.useResidencySet(residencySet)
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
      commandBuffer.endCommandBuffer()
      residencySet.endResidency()
      throw TissueError.metal("failed to encode NumanX Brain ACK")
    }
    encoder.label = "NumiBrain validate proposal and write Brain ACK"
    brainAckArguments.setAddress(prepared.witnessBuffer.gpuAddress, index: 0)
    brainAckArguments.setAddress(
      prepared.startGate.resultBuffer.gpuAddress, index: 1
    )
    brainAckArguments.setAddress(
      prepared.request.fastPrepareStatus.gpuAddress, index: 2
    )
    brainAckArguments.setAddress(proposal.proposalGPUAddress, index: 3)
    brainAckArguments.setAddress(proposal.proposedTokenGPUAddress, index: 4)
    brainAckArguments.setAddress(preflight.gpuAddress, index: 5)
    brainAckArguments.setAddress(dispatchBuffer.gpuAddress, index: 6)
    brainAckArguments.setAddress(ackBuffer.gpuAddress, index: 7)
    encoder.setComputePipelineState(brainAckPipeline)
    encoder.setArgumentTable(brainAckArguments)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
    encoder.endEncoding()
    commandBuffer.endCommandBuffer()

    try MetalSharedEventPoint.validateProgression(
      wait: proposal.readyPoint, signal: completionPoint, device: device
    )
    try preflight.readyPoint.validate(for: device)
    try prepared.reserveBrainAck()
    let feedbackState = MetalAsyncFeedbackState()
    let completionState =
      NumanXOneShotCompletionState<MetalNumanXHumanMatterBrainAckCompletion>()
    let resources = MetalAsyncCommandResources(
      allocator: allocator,
      commandBuffer: commandBuffer,
      residencySets: [residencySet]
    )
    commandQueue.waitForEvent(
      proposal.readyPoint.event, value: proposal.readyPoint.value
    )
    commandQueue.waitForEvent(
      preflight.readyPoint.event, value: preflight.readyPoint.value
    )
    let options = MTL4CommitOptions()
    options.addFeedbackHandler { feedback in
      let completion: MetalNumanXHumanMatterBrainAckCompletion
      if let error = feedback.error {
        // A GPU error can occur after the ACK kernel wrote ACCEPT. Replace the
        // entire shared record before advancing the liveness event.
        evaluation.overwriteInvalidAck(
          identity: identity,
          brainProgramFingerprint: self.programFingerprint
        )
        Self.advanceForLiveness(completionPoint)
        completion = MetalNumanXHumanMatterBrainAckCompletion(
          status: .gpuFailure,
          feedback: nil,
          ack: nil,
          failureDescription: String(describing: error)
        )
      } else {
        let completedFeedback = MetalGPUCompletionFeedback(
          gpuStartSeconds: feedback.gpuStartTime,
          gpuEndSeconds: feedback.gpuEndTime
        )
        do {
          let ack = try Self.brainAck(buffer: ackBuffer)
          Self.advanceForLiveness(completionPoint)
          completion = MetalNumanXHumanMatterBrainAckCompletion(
            status: .completed,
            feedback: completedFeedback,
            ack: ack,
            failureDescription: nil
          )
        } catch {
          evaluation.overwriteInvalidAck(
            identity: identity,
            brainProgramFingerprint: self.programFingerprint
          )
          Self.advanceForLiveness(completionPoint)
          completion = MetalNumanXHumanMatterBrainAckCompletion(
            status: .invalidResult,
            feedback: completedFeedback,
            ack: nil,
            failureDescription: String(describing: error)
          )
        }
      }
      feedbackState.record(feedback, label: "NumiBrain NumanX Brain ACK")
      completionState.complete(completion)
      _ = resources
      _ = preparedTicket
      _ = proposal
      _ = preflight
    }
    commandQueue.commit([commandBuffer], options: options)
    return MetalNumanXHumanMatterBrainAckTicket(
      preparedTicket: preparedTicket,
      proposalLease: proposal,
      preflightLease: preflight,
      ackLease: ackLease,
      feedbackState: feedbackState,
      resources: resources,
      evaluation: evaluation,
      completionState: completionState
    )
  }

  func submitAppliedValidation(
    ackTicket: MetalNumanXHumanMatterBrainAckTicket,
    applied: MetalNumanXHumanMatterAppliedLease,
    signal completionPoint: MetalSharedEventPoint
  ) throws -> MetalNumanXHumanMatterAppliedValidationTicket {
    lock.lock()
    defer { lock.unlock() }
    let preparedTicket = ackTicket.preparedTicket
    guard let prepared = preparedTicket.numanXPrepareEvaluation else {
      throw TissueError.transaction("applied validation lost its Brain witness")
    }
    let identity = prepared.request.identity
    try ackTicket.ackLease.validate(for: device)
    try ackTicket.proposalLease.validate(for: device)
    try ackTicket.preflightLease.validate(for: device)
    try applied.validate(for: device)
    guard applied.identity == identity,
      ackTicket.ackLease.identity == identity,
      try ackTicket.feedbackState.poll() != nil,
      (applied.readyPoint.event as AnyObject)
        !== (completionPoint.event as AnyObject)
    else {
      throw TissueError.transaction(
        "NumanX applied validation requires the exact settled apply generation"
      )
    }
    guard let dispatchBuffer = device.makeBuffer(
      length: MemoryLayout<NumanXAppliedValidationDispatchRecord>.stride,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ), let resultBuffer = device.makeBuffer(
      length: Int(NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_BYTE_COUNT),
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ), let validatedTokenBuffer = device.makeBuffer(
      length: Int(NB_ACCEPTED_PHYSICS_STATE_TOKEN_BYTE_COUNT),
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ), let allocator = device.makeCommandAllocator(),
      let commandBuffer = device.makeCommandBuffer()
    else {
      throw TissueError.metal("failed to allocate NumanX applied validation")
    }
    var dispatch = NumanXAppliedValidationDispatchRecord(
      abiVersion: UInt32(NB_NUMANX_HUMAN_MATTER_ABI_VERSION),
      environment: identity.environment,
      stepIndex: identity.stepIndex,
      substepIndex: identity.substepIndex,
      transactionSlot: identity.transactionSlot,
      physicsSubstepCount: identity.physicsSubstepCount,
      controlStep: identity.controlStep,
      commandDisposition: applied.commandDisposition.rawValue,
      ownerProgramFingerprint: identity.programFingerprint,
      transactionFingerprint: identity.transactionFingerprint,
      linearizationEpoch: identity.linearizationEpoch,
      slotGeneration: identity.slotGeneration,
      brainProgramFingerprint: programFingerprint,
      fastProgramFingerprint: prepared.request.fastProgramFingerprint
    )
    withUnsafeBytes(of: &dispatch) { bytes in
      dispatchBuffer.contents().copyMemory(
        from: bytes.baseAddress!, byteCount: bytes.count
      )
    }
    resultBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: resultBuffer.length
    )
    validatedTokenBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: validatedTokenBuffer.length
    )
    dispatchBuffer.label = "NumiBrain NumanX applied-validation dispatch"
    resultBuffer.label = "NumiBrain NumanX applied-validation result"
    validatedTokenBuffer.label = "NumiBrain NumanX validated applied token"
    let evaluation = MetalNumanXAppliedValidationEvaluation(
      dispatchBuffer: dispatchBuffer,
      resultBuffer: resultBuffer,
      validatedTokenBuffer: validatedTokenBuffer
    )
    var intervals = try preparedIntervals(prepared)
    intervals += [
      ackTicket.proposalLease.proposalInterval,
      ackTicket.proposalLease.proposedTokenInterval,
      ackTicket.proposalLease.publicationFenceInterval,
      ackTicket.preflightLease.interval,
      ackTicket.ackLease.interval,
      applied.appliedInterval,
      applied.finalTokenInterval,
      try NumanXGPUInterval(
        buffer: dispatchBuffer, offset: 0, count: dispatchBuffer.length
      ),
      try NumanXGPUInterval(
        buffer: resultBuffer, offset: 0, count: resultBuffer.length
      ),
      try NumanXGPUInterval(
        buffer: validatedTokenBuffer,
        offset: 0,
        count: validatedTokenBuffer.length
      ),
    ]
    try Self.requirePairwiseDisjoint(
      intervals, label: "NumanX applied-validation resources"
    )

    let residencySet = try makeResidencySet(
      label: "NumiBrain NumanX applied-validation residency",
      allocations: [
        prepared.witnessBuffer,
        prepared.startGate.resultBuffer,
        prepared.request.fastPrepareStatus.buffer,
        ackTicket.proposalLease.proposalBuffer,
        ackTicket.proposalLease.proposedTokenBuffer,
        ackTicket.proposalLease.publicationFenceBuffer,
        ackTicket.preflightLease.buffer,
        ackTicket.ackLease.buffer,
        applied.appliedBuffer,
        applied.finalTokenBuffer,
        dispatchBuffer,
        resultBuffer,
        validatedTokenBuffer,
      ]
    )
    commandBuffer.beginCommandBuffer(allocator: allocator)
    commandBuffer.useResidencySet(residencySet)
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
      commandBuffer.endCommandBuffer()
      residencySet.endResidency()
      throw TissueError.metal("failed to encode NumanX applied validation")
    }
    encoder.label = "NumiBrain validate quarantined applied Human-Matter root"
    appliedValidationArguments.setAddress(
      prepared.witnessBuffer.gpuAddress, index: 0
    )
    appliedValidationArguments.setAddress(
      prepared.startGate.resultBuffer.gpuAddress, index: 1
    )
    appliedValidationArguments.setAddress(
      prepared.request.fastPrepareStatus.gpuAddress, index: 2
    )
    appliedValidationArguments.setAddress(
      ackTicket.proposalLease.proposalGPUAddress, index: 3
    )
    appliedValidationArguments.setAddress(
      ackTicket.proposalLease.proposedTokenGPUAddress, index: 4
    )
    appliedValidationArguments.setAddress(
      ackTicket.preflightLease.gpuAddress, index: 5
    )
    appliedValidationArguments.setAddress(
      ackTicket.ackLease.gpuAddress, index: 6
    )
    appliedValidationArguments.setAddress(applied.appliedGPUAddress, index: 7)
    appliedValidationArguments.setAddress(applied.finalTokenGPUAddress, index: 8)
    appliedValidationArguments.setAddress(dispatchBuffer.gpuAddress, index: 9)
    appliedValidationArguments.setAddress(resultBuffer.gpuAddress, index: 10)
    appliedValidationArguments.setAddress(validatedTokenBuffer.gpuAddress, index: 11)
    encoder.setComputePipelineState(appliedValidationPipeline)
    encoder.setArgumentTable(appliedValidationArguments)
    encoder.dispatchThreads(
      threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
    encoder.endEncoding()
    commandBuffer.endCommandBuffer()

    try MetalSharedEventPoint.validateProgression(
      wait: applied.readyPoint, signal: completionPoint, device: device
    )
    let feedbackState = MetalAsyncFeedbackState()
    let completionState =
      NumanXOneShotCompletionState<MetalNumanXHumanMatterAppliedCompletion>()
    let resources = MetalAsyncCommandResources(
      allocator: allocator,
      commandBuffer: commandBuffer,
      residencySets: [residencySet]
    )
    commandQueue.waitForEvent(applied.readyPoint.event, value: applied.readyPoint.value)
    let options = MTL4CommitOptions()
    options.addFeedbackHandler { feedback in
      let completion: MetalNumanXHumanMatterAppliedCompletion
      if let error = feedback.error {
        evaluation.invalidate()
        Self.advanceForLiveness(completionPoint)
        completion = MetalNumanXHumanMatterAppliedCompletion(
          status: .gpuFailure,
          feedback: nil,
          validation: nil,
          acceptedPhysicsState: nil,
          failureDescription: String(describing: error)
        )
      } else {
        let completedFeedback = MetalGPUCompletionFeedback(
          gpuStartSeconds: feedback.gpuStartTime,
          gpuEndSeconds: feedback.gpuEndTime
        )
        do {
          let validation = try Self.appliedValidation(
            buffer: resultBuffer,
            expectedIdentity: identity
          )
          let accepted = try Self.validatedAcceptedPhysicsState(
            evaluation: evaluation,
            prepared: prepared,
            validation: validation
          )
          Self.advanceForLiveness(completionPoint)
          completion = MetalNumanXHumanMatterAppliedCompletion(
            status: .completed,
            feedback: completedFeedback,
            validation: validation,
            acceptedPhysicsState: accepted,
            failureDescription: nil
          )
        } catch {
          evaluation.invalidate()
          Self.advanceForLiveness(completionPoint)
          completion = MetalNumanXHumanMatterAppliedCompletion(
            status: .invalidResult,
            feedback: completedFeedback,
            validation: nil,
            acceptedPhysicsState: nil,
            failureDescription: String(describing: error)
          )
        }
      }
      feedbackState.record(feedback, label: "NumiBrain NumanX applied validation")
      completionState.complete(completion)
      _ = resources
      _ = ackTicket
      _ = applied
    }
    commandQueue.commit([commandBuffer], options: options)
    return MetalNumanXHumanMatterAppliedValidationTicket(
      preparedTicket: preparedTicket,
      ackTicket: ackTicket,
      appliedLease: applied,
      completionPoint: completionPoint,
      feedbackState: feedbackState,
      resources: resources,
      evaluation: evaluation,
      completionState: completionState
    )
  }

  private func preparedIntervals(
    _ prepared: MetalNumanXBrainCommitPrepareEvaluation
  ) throws -> [NumanXGPUInterval] {
    var intervals = [
      try NumanXGPUInterval(
        buffer: prepared.witnessBuffer, offset: 0,
        count: prepared.witnessBuffer.length
      ),
      try NumanXGPUInterval(
        buffer: prepared.startGate.resultBuffer, offset: 0,
        count: prepared.startGate.resultBuffer.length
      ),
      try NumanXGPUInterval(
        buffer: prepared.request.fastPrepareStatus.buffer,
        offset: prepared.request.fastPrepareStatus.byteOffset,
        count: MetalNumanXFastPrepareStatusLease.byteCount
      ),
      try NumanXGPUInterval(
        buffer: prepared.descriptorBuffer, offset: 0,
        count: prepared.descriptorBuffer.length
      ),
      try NumanXGPUInterval(
        buffer: prepared.dispatchBuffer, offset: 0,
        count: prepared.dispatchBuffer.length
      ),
      try NumanXGPUInterval(
        buffer: prepared.reduceDispatchBuffer, offset: 0,
        count: prepared.reduceDispatchBuffer.length
      ),
      try NumanXGPUInterval(
        buffer: prepared.hashScratchA, offset: 0,
        count: prepared.hashScratchA.length
      ),
      try NumanXGPUInterval(
        buffer: prepared.hashScratchB, offset: 0,
        count: prepared.hashScratchB.length
      ),
      try NumanXGPUInterval(
        buffer: prepared.hotBuffer, offset: 0,
        count: prepared.hotBuffer.length
      ),
      try NumanXGPUInterval(
        buffer: prepared.journalBuffer, offset: 0,
        count: prepared.journalBuffer.length
      ),
    ]
    for source in prepared.request.fastStateSources {
      intervals.append(
        try NumanXGPUInterval(
          buffer: source.buffer,
          offset: source.byteOffset,
          count: source.byteCount
        )
      )
    }
    return intervals
  }

  private func makeResidencySet(
    label: String,
    allocations: [any MTLAllocation]
  ) throws -> any MTLResidencySet {
    let descriptor = MTLResidencySetDescriptor()
    descriptor.label = label
    descriptor.initialCapacity = allocations.count
    let set: any MTLResidencySet
    do {
      set = try device.makeResidencySet(descriptor: descriptor)
    } catch {
      throw TissueError.metal("failed to make \(label): \(error)")
    }
    for allocation in allocations { set.addAllocation(allocation) }
    set.commit()
    set.requestResidency()
    return set
  }

  private static func requirePairwiseDisjoint(
    _ intervals: [NumanXGPUInterval],
    label: String
  ) throws {
    for first in intervals.indices {
      for second in intervals.indices where second > first {
        guard !intervals[first].overlaps(intervals[second]) else {
          throw TissueError.transaction("\(label) overlap on the GPU")
        }
      }
    }
  }

  private static func advanceForLiveness(_ point: MetalSharedEventPoint) {
    if point.event.signaledValue < point.value {
      point.event.signaledValue = point.value
    }
  }

  static func brainAck(
    buffer: any MTLBuffer
  ) throws -> MetalNumanXHumanMatterBrainAck {
    let record = buffer.contents().load(as: NBNumanXHumanMatterBrainAckGPU.self)
    let knownStatus = record.status
      == NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_ACCEPT.rawValue
      || record.status == NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_REJECT.rawValue
      || record.status == NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_INVALID.rawValue
    let statusConsistent =
      (record.status == NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_ACCEPT.rawValue
        && record.decision == NB_NUMANX_HUMAN_MATTER_ROOT_ACCEPT.rawValue
        && record.code == NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_SUCCESS.rawValue
        && record.physicsTokenFingerprint != 0)
      || (record.status == NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_REJECT.rawValue
        && record.decision == NB_NUMANX_HUMAN_MATTER_ROOT_REJECT.rawValue)
      || (record.status == NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_INVALID.rawValue
        && record.decision == NB_NUMANX_HUMAN_MATTER_ROOT_PENDING.rawValue)
    guard record.abiVersion
        == UInt32(NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_ABI_VERSION),
      knownStatus, statusConsistent,
      record.programFingerprint != 0, record.transactionFingerprint != 0,
      record.linearizationEpoch != 0, record.slotGeneration != 0,
      record.brainProgramFingerprint != 0,
      record.environment == 0, record.stepIndex == 0, record.substepIndex == 0,
      record.physicsSubstepCount == 1,
      record.ackFingerprint != 0,
      record.ackFingerprint == fingerprint(record)
    else {
      throw TissueError.transaction("NumanX Brain ACK record is invalid")
    }
    let identity = try MetalNumanXHumanMatterRootIdentity(
      programFingerprint: record.programFingerprint,
      transactionFingerprint: record.transactionFingerprint,
      linearizationEpoch: record.linearizationEpoch,
      slotGeneration: record.slotGeneration,
      transactionSlot: record.transactionSlot,
      environment: record.environment,
      stepIndex: record.stepIndex,
      controlStep: record.controlStep,
      substepIndex: record.substepIndex,
      physicsSubstepCount: record.physicsSubstepCount
    )
    return MetalNumanXHumanMatterBrainAck(
      status: record.status,
      decision: record.decision,
      code: record.code,
      identity: identity,
      physicsTokenFingerprint: record.physicsTokenFingerprint,
      proposalFingerprint: record.proposalFingerprint,
      preflightFingerprint: record.preflightFingerprint,
      fastGateFingerprint: record.fastGateFingerprint,
      brainWitnessFingerprint: record.brainWitnessFingerprint,
      brainProgramFingerprint: record.brainProgramFingerprint,
      ackFingerprint: record.ackFingerprint
    )
  }

  static func appliedValidation(
    buffer: any MTLBuffer,
    expectedIdentity: MetalNumanXHumanMatterRootIdentity
  ) throws -> MetalNumanXHumanMatterAppliedValidation {
    let record = buffer.contents().load(as: NumanXAppliedValidationResultRecord.self)
    guard record.abiVersion
        == UInt32(NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_ABI_VERSION),
      record.structBytes
        == UInt32(NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_BYTE_COUNT),
      let status = MetalNumanXHumanMatterAppliedValidationStatus(
        rawValue: record.status
      ),
      let disposition = MetalNumanXHumanMatterAppliedCommandDisposition(
        rawValue: UInt32(record.appliedCommandDisposition)
      ),
      record.environment == 0, record.stepIndex == 0, record.substepIndex == 0,
      record.physicsSubstepCount == 1,
      record.ownerProgramFingerprint > 0, record.transactionFingerprint > 0,
      record.linearizationEpoch > 0, record.slotGeneration > 0,
      record.brainProgramFingerprint > 0,
      record.reserved0.0 == 0, record.reserved0.1 == 0,
      record.reserved0.2 == 0, record.reserved0.3 == 0,
      record.reserved0.4 == 0,
      record.resultFingerprint > 0,
      record.resultFingerprint == fingerprint(record)
    else {
      throw TissueError.transaction("NumanX applied-validation result is invalid")
    }
    let identity = try MetalNumanXHumanMatterRootIdentity(
      programFingerprint: record.ownerProgramFingerprint,
      transactionFingerprint: record.transactionFingerprint,
      linearizationEpoch: record.linearizationEpoch,
      slotGeneration: record.slotGeneration,
      transactionSlot: record.transactionSlot,
      environment: record.environment,
      stepIndex: record.stepIndex,
      controlStep: record.controlStep,
      substepIndex: record.substepIndex,
      physicsSubstepCount: record.physicsSubstepCount
    )
    guard identity == expectedIdentity else {
      throw TissueError.transaction("NumanX applied-validation identity is stale")
    }
    return MetalNumanXHumanMatterAppliedValidation(
      status: status,
      code: record.code,
      decision: record.decision,
      identity: identity,
      physicsTokenFingerprint: record.physicsTokenFingerprint,
      brainProgramFingerprint: record.brainProgramFingerprint,
      brainShadowStateFingerprint: record.brainShadowStateFingerprint,
      brainWitnessFingerprint: record.brainWitnessFingerprint,
      proposalFingerprint: record.proposalFingerprint,
      preflightFingerprint: record.preflightFingerprint,
      fastGateFingerprint: record.fastGateFingerprint,
      ackFingerprint: record.ackFingerprint,
      matterApplyFingerprint: record.matterApplyFingerprint,
      appliedDecisionFingerprint: record.appliedFingerprint,
      fastProgramFingerprint: record.fastProgramFingerprint,
      fastTargetGeneration: record.fastTargetGeneration,
      cognitiveTargetGeneration: record.cognitiveTargetGeneration,
      jointCommitFingerprint: record.jointCommitFingerprint,
      substepFingerprint: record.substepFingerprint,
      commandDisposition: disposition,
      resultFingerprint: record.resultFingerprint
    )
  }

  private static func validatedAcceptedPhysicsState(
    evaluation: MetalNumanXAppliedValidationEvaluation,
    prepared: MetalNumanXBrainCommitPrepareEvaluation,
    validation: MetalNumanXHumanMatterAppliedValidation
  ) throws -> AcceptedPhysicsStateToken? {
    let bytes = UnsafeRawBufferPointer(
      start: evaluation.validatedTokenBuffer.contents(),
      count: evaluation.validatedTokenBuffer.length
    )
    guard validation.status == .accept else {
      guard bytes.allSatisfy({ $0 == 0 }) else {
        throw TissueError.transaction(
          "NumanX non-accept applied result exposed a canonical token"
        )
      }
      return nil
    }
    let record = evaluation.validatedTokenBuffer.contents().load(
      as: NBAcceptedPhysicsStateToken.self
    )
    let token = try AcceptedPhysicsStateToken(
      validating: record,
      transaction: prepared.startGate.transaction,
      substep: prepared.startGate.substep
    )
    guard token.fingerprint == validation.physicsTokenFingerprint,
      token.transactionFingerprint == validation.identity.transactionFingerprint,
      token.environmentIdentifier == validation.identity.environment,
      record.reserved == 0
    else {
      throw TissueError.transaction("NumanX applied token is not canonical")
    }
    return token
  }

  static func fingerprint(
    _ witness: NBNumanXHumanMatterBrainCommitWitness
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for value in [
      witness.magic, witness.abiVersion, witness.structBytes, witness.status,
      witness.decision, witness.environment, witness.stepIndex,
      witness.substepIndex, witness.transactionSlot,
      witness.physicsSubstepCount, witness.controlStep, witness.reserved0,
    ] { mix(value, into: &hash) }
    for value in [
      witness.programFingerprint, witness.transactionFingerprint,
      witness.linearizationEpoch, witness.slotGeneration,
      witness.physicsTokenFingerprint, witness.brainProgramFingerprint,
      witness.brainShadowStateFingerprint,
      witness.reserved1.0, witness.reserved1.1,
    ] { mix(value, into: &hash) }
    return hash == 0 ? 14_695_981_039_346_656_037 : hash
  }

  static func fingerprint(_ ack: NBNumanXHumanMatterBrainAckGPU) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for value in [ack.abiVersion, ack.status, ack.decision, ack.code] {
      mix(value, into: &hash)
    }
    for value in [
      ack.programFingerprint, ack.transactionFingerprint,
      ack.linearizationEpoch, ack.slotGeneration,
      ack.physicsTokenFingerprint, ack.proposalFingerprint,
      ack.preflightFingerprint, ack.fastGateFingerprint,
      ack.brainWitnessFingerprint, ack.brainProgramFingerprint,
    ] { mix(value, into: &hash) }
    for value in [
      ack.environment, ack.stepIndex, ack.substepIndex,
      ack.transactionSlot, ack.physicsSubstepCount, ack.controlStep,
    ] { mix(value, into: &hash) }
    return hash == 0 ? 14_695_981_039_346_656_037 : hash
  }

  private static func fingerprint(
    _ record: NumanXAppliedValidationResultRecord
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for value in [
      record.abiVersion, record.structBytes, record.status, record.code,
      record.decision, record.environment, record.stepIndex,
      record.substepIndex, record.transactionSlot,
      record.physicsSubstepCount, record.controlStep, record.tokenValid,
    ] { mix(value, into: &hash) }
    for value in [
      record.ownerProgramFingerprint, record.transactionFingerprint,
      record.linearizationEpoch, record.slotGeneration,
      record.physicsTokenFingerprint, record.brainProgramFingerprint,
      record.brainShadowStateFingerprint, record.brainWitnessFingerprint,
      record.proposalFingerprint, record.preflightFingerprint,
      record.fastGateFingerprint, record.ackFingerprint,
      record.matterApplyFingerprint, record.appliedFingerprint,
      record.fastProgramFingerprint, record.fastTargetGeneration,
      record.cognitiveTargetGeneration, record.jointCommitFingerprint,
      record.substepFingerprint, record.appliedCommandDisposition,
      record.reserved0.0, record.reserved0.1, record.reserved0.2,
      record.reserved0.3, record.reserved0.4,
    ] { mix(value, into: &hash) }
    return hash == 0 ? 14_695_981_039_346_656_037 : hash
  }

  private static func makeProgramFingerprint(
    shaderSources: [(String, Data)],
    immutableFingerprints: [(String, UInt64)],
    hashScratchByteCapacity: Int
  ) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    mix(Data("NumiBrain.NumanX.HumanMatter.Program.v4".utf8), into: &hash)
    mix(Data("Metal4.0.safe.precise".utf8), into: &hash)
    mix(MetalNumanXBrainCommitPrepareRequest.maximumHashedByteCount, into: &hash)
    mix(MetalNumanXBrainCommitPrepareRequest.hashChunkByteCount, into: &hash)
    mix(MetalNumanXBrainCommitPrepareRequest.hashTreeFanout, into: &hash)
    mix(UInt64(hashScratchByteCapacity), into: &hash)
    mix(UInt32(shaderSources.count), into: &hash)
    for (name, bytes) in shaderSources {
      mix(Data(name.utf8), into: &hash)
      mix(UInt64(bytes.count), into: &hash)
      mix(bytes, into: &hash)
    }
    mix(UInt32(immutableFingerprints.count), into: &hash)
    for (name, value) in immutableFingerprints {
      mix(Data(name.utf8), into: &hash)
      mix(value, into: &hash)
    }
    return hash == 0 ? 14_695_981_039_346_656_037 : hash
  }

  private static func mix(_ value: UInt32, into hash: inout UInt64) {
    var little = value.littleEndian
    withUnsafeBytes(of: &little) { bytes in mix(bytes, into: &hash) }
  }

  private static func mix(_ value: UInt64, into hash: inout UInt64) {
    var little = value.littleEndian
    withUnsafeBytes(of: &little) { bytes in mix(bytes, into: &hash) }
  }

  private static func mix(_ data: Data, into hash: inout UInt64) {
    data.withUnsafeBytes { bytes in mix(bytes, into: &hash) }
  }

  private static func mix(_ bytes: UnsafeRawBufferPointer, into hash: inout UInt64) {
    for byte in bytes {
      hash ^= UInt64(byte)
      hash &*= 1_099_511_628_211
    }
  }

  private static func range(
    buffer: any MTLBuffer,
    offset: Int,
    count: Int
  ) throws -> (UInt64, UInt64) {
    guard offset >= 0, count > 0 else {
      throw TissueError.transaction("NumanX GPU range is empty or negative")
    }
    let (hostEnd, hostOverflow) = offset.addingReportingOverflow(count)
    let (start, startOverflow) = buffer.gpuAddress.addingReportingOverflow(
      UInt64(offset)
    )
    let (end, endOverflow) = start.addingReportingOverflow(UInt64(count))
    guard !hostOverflow, !startOverflow, !endOverflow,
      hostEnd <= buffer.length
    else {
      throw TissueError.transaction("NumanX GPU range overflows")
    }
    return (start, end)
  }

  private static func overlaps(
    _ lhs: (UInt64, UInt64),
    _ rhs: (UInt64, UInt64)
  ) -> Bool {
    lhs.0 < rhs.1 && rhs.0 < lhs.1
  }

  private static func pairwiseDisjoint(
    _ ranges: [(UInt64, UInt64)]
  ) -> Bool {
    for left in ranges.indices {
      for right in ranges.indices where right > left {
        if overlaps(ranges[left], ranges[right]) { return false }
      }
    }
    return true
  }

  private static func threadgroupWidth(
    _ pipeline: any MTLComputePipelineState,
    count: Int
  ) -> Int {
    max(
      1,
      min(
        count,
        min(pipeline.threadExecutionWidth, pipeline.maxTotalThreadsPerThreadgroup)
      )
    )
  }

  private static func makeArgumentTable(
    device: any MTLDevice,
    label: String,
    count: Int
  ) throws -> any MTL4ArgumentTable {
    let descriptor = MTL4ArgumentTableDescriptor()
    descriptor.label = label
    descriptor.maxBufferBindCount = count
    descriptor.initializeBindings = true
    do {
      return try device.makeArgumentTable(descriptor: descriptor)
    } catch {
      throw TissueError.metal("failed to create \(label): \(error)")
    }
  }
}

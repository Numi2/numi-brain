import Dispatch
import Foundation
import Metal
import NumiBrainABI
import XCTest

@testable import NumiBrainCore
@_spi(NumanXInterop) @testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalNumanXHumanMatterV4Tests: XCTestCase {
  private struct AcceptedGateResultRecord {
    var version: UInt32 = 0
    var status: UInt32 = 0
    var expectedTransactionFingerprint: UInt64 = 0
    var observedTransactionFingerprint: UInt64 = 0
    var expectedSubstepFingerprint: UInt64 = 0
    var observedSubstepFingerprint: UInt64 = 0
    var computedTokenFingerprint: UInt64 = 0
    var observedTokenFingerprint: UInt64 = 0
    var reserved: UInt64 = 0
    var acceptedToken = NBAcceptedPhysicsStateToken()
  }

  private struct PreparedRoot {
    let device: any MTLDevice
    let runtime: MetalEmbodiedBrainRuntime
    let transaction: MetalJointAgentStateTransaction
    let ticket: MetalEmbodiedBrainRuntime.AcceptedConsequenceSubmissionTicket
    let accepted: AcceptedPhysicsStateToken
    let provisional: BrainProvisionalPhysicsAcceptance
    let identity: MetalNumanXHumanMatterRootIdentity
    let fastStatusBuffer: any MTLBuffer
    let fastProgramFingerprint: UInt64
    let witness: NBNumanXHumanMatterBrainCommitWitness
  }

  private struct AckSubmission {
    let ticket: MetalNumanXHumanMatterBrainAckTicket
    let completion: MetalNumanXHumanMatterBrainAckCompletion
  }

  private final class LockedBox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value?

    func store(_ value: Value) {
      lock.lock()
      self.value = value
      lock.unlock()
    }

    func load() -> Value? {
      lock.lock()
      defer { lock.unlock() }
      return value
    }
  }

  func testCanonicalABI4LayoutsAndOwnerElementStrides() throws {
    XCTAssertEqual(MemoryLayout<NBNumanXFastPrepareStatusGPU>.stride, 128)
    XCTAssertEqual(
      MemoryLayout<NBNumanXHumanMatterBrainCommitWitness>.stride, 128
    )
    XCTAssertEqual(MemoryLayout<NBNumanXHumanMatterProposalGPU>.stride, 128)
    XCTAssertEqual(
      MemoryLayout<NBNumanXHumanMatterBrainCommitPreflightGPU>.stride, 128
    )
    XCTAssertEqual(MemoryLayout<NBNumanXHumanMatterBrainAckGPU>.stride, 128)
    XCTAssertEqual(
      MemoryLayout<NBNumanXHumanMatterAppliedOutcomeGPU>.stride, 128
    )
    XCTAssertEqual(
      MemoryLayout<NBNumanXHumanMatterJointPublicationFenceGPU>.stride, 128
    )
    XCTAssertEqual(
      MemoryLayout<NBNumanXHumanMatterAppliedValidationResultGPU>.stride, 256
    )
    XCTAssertEqual(MemoryLayout<AcceptedGateResultRecord>.stride, 128)

    let device = try requireMetal4Device()
    let identity = try rootIdentity(transactionFingerprint: 0x101, generation: 9)
    let proposal = try sharedBuffer(device, byteCount: 128)
    let token = try sharedBuffer(device, byteCount: 64)
    let fence = try sharedBuffer(device, byteCount: 128)
    let proposalEvent = try XCTUnwrap(device.makeSharedEvent())
    XCTAssertNoThrow(try MetalNumanXHumanMatterProposalLease(
      identity: identity,
      proposalBuffer: proposal,
      proposalGPUAddress: proposal.gpuAddress,
      proposalElementCount: 1,
      proposalStride: 1,
      proposedTokenBuffer: token,
      proposedTokenGPUAddress: token.gpuAddress,
      proposedTokenStride: 64,
      publicationFenceBuffer: fence,
      publicationFenceGPUAddress: fence.gpuAddress,
      publicationFenceElementCount: 1,
      publicationFenceStride: 1,
      readyPoint: try MetalSharedEventPoint(event: proposalEvent, value: 1)
    ))
    XCTAssertThrowsError(try MetalNumanXHumanMatterProposalLease(
      identity: identity,
      proposalBuffer: proposal,
      proposalGPUAddress: proposal.gpuAddress,
      proposalElementCount: 1,
      proposalStride: 128,
      proposedTokenBuffer: token,
      proposedTokenGPUAddress: token.gpuAddress,
      publicationFenceBuffer: fence,
      publicationFenceGPUAddress: fence.gpuAddress,
      publicationFenceStride: 1,
      readyPoint: try MetalSharedEventPoint(event: proposalEvent, value: 1)
    ))
  }

  func testParallelWitnessReplayAndStartGateCannotPublish() throws {
    let first = try prepareRoot(validStartGate: true, slotGeneration: 21)
    let second = try prepareRoot(validStartGate: true, slotGeneration: 21)
    defer {
      try? abort(first)
      try? abort(second)
    }
    XCTAssertEqual(
      first.witness.status,
      NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_PREPARE_COMPLETE.rawValue
    )
    XCTAssertEqual(first.witness.decision, NB_NUMANX_HUMAN_MATTER_ROOT_ACCEPT.rawValue)
    XCTAssertEqual(
      first.witness.witnessFingerprint,
      MetalNumanXHumanMatterBrainRuntime.fingerprint(first.witness)
    )
    XCTAssertEqual(first.witness.physicsTokenFingerprint, first.accepted.fingerprint)
    XCTAssertEqual(
      bytes(first.ticket.numanXPrepareEvaluation!.witnessBuffer, count: 128),
      bytes(second.ticket.numanXPrepareEvaluation!.witnessBuffer, count: 128)
    )
    XCTAssertGreaterThan(try XCTUnwrap(first.ticket.numanXHashChunkCount), 1)
    XCTAssertGreaterThan(try XCTUnwrap(first.ticket.numanXHashDispatchCount), 2)
    XCTAssertEqual(
      first.ticket.numanXHashScratchByteCount,
      first.ticket.numanXPrepareEvaluation!.hashLayout.scratchByteCount * 2
    )
    XCTAssertEqual(first.ticket.consequence.sensoryObservationGPUAddress, 0)
    XCTAssertEqual(first.ticket.consequence.receptorEventQueueGPUAddress, 0)
    XCTAssertEqual(first.ticket.consequence.acceptedPhysicsTokenFingerprint, 0)
    XCTAssertGreaterThan(
      first.ticket.candidateConsequence.sensoryObservationGPUAddress, 0
    )
    XCTAssertEqual(first.transaction.status, .open)
    XCTAssertThrowsError(try first.runtime.finishAcceptedConsequenceSubmission(
      first.ticket,
      transaction: first.transaction,
      timeoutMilliseconds: 10_000
    ))
  }

  func testFailedStartGateLeavesOnlyFailureWitness() throws {
    let prepared = try prepareRoot(validStartGate: false, slotGeneration: 22)
    defer { try? abort(prepared) }
    XCTAssertEqual(
      prepared.witness.status,
      NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_PREPARE_FAILED.rawValue
    )
    XCTAssertEqual(
      prepared.witness.decision,
      NB_NUMANX_HUMAN_MATTER_ROOT_REJECT.rawValue
    )
    XCTAssertEqual(prepared.witness.physicsTokenFingerprint, 0)
    XCTAssertEqual(
      prepared.witness.witnessFingerprint,
      MetalNumanXHumanMatterBrainRuntime.fingerprint(prepared.witness)
    )
    XCTAssertEqual(prepared.transaction.status, .open)
  }

  func testBrainAckAcceptReplayAndCompleteGateBinding() throws {
    let first = try prepareRoot(validStartGate: true, slotGeneration: 23)
    let second = try prepareRoot(validStartGate: true, slotGeneration: 23)
    defer {
      try? abort(first)
      try? abort(second)
    }
    let firstAck = try submitAck(prepared: first, accept: true)
    let secondAck = try submitAck(prepared: second, accept: true)
    let accepted = try XCTUnwrap(firstAck.completion.ack)
    XCTAssertEqual(firstAck.completion.status, .completed)
    XCTAssertTrue(accepted.permitsPhysicalApply)
    XCTAssertEqual(accepted.identity.controlStep, 37)
    XCTAssertEqual(
      bytes(firstAck.ticket.ackLease.buffer, count: 128),
      bytes(secondAck.ticket.ackLease.buffer, count: 128)
    )
    XCTAssertGreaterThanOrEqual(
      firstAck.ticket.ackLease.readyPoint.event.signaledValue,
      firstAck.ticket.ackLease.readyPoint.value
    )

    let wrongGate = try prepareRoot(validStartGate: true, slotGeneration: 24)
    defer { try? abort(wrongGate) }
    var gate = wrongGate.ticket.numanXPrepareEvaluation!.startGate.resultBuffer
      .contents().load(as: AcceptedGateResultRecord.self)
    gate.expectedTransactionFingerprint &+= 1
    gate.observedSubstepFingerprint &+= 1
    gate.reserved = 1
    write(gate, to: wrongGate.ticket.numanXPrepareEvaluation!.startGate.resultBuffer)
    let wrongGateAck = try submitAck(prepared: wrongGate, accept: true)
    XCTAssertFalse(try XCTUnwrap(wrongGateAck.completion.ack).permitsPhysicalApply)
    XCTAssertEqual(
      wrongGateAck.completion.ack?.code,
      NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_INVALID_WITNESS.rawValue
    )
  }

  func testBrainAckRequiresExactHumanIOIdentityOnAcceptAndReject() throws {
    let cases: [(accept: Bool, candidate: UInt64?, identity: UInt64?)] = [
      (true, 0, nil),
      (true, nil, 0),
      (false, 1, nil),
      (false, nil, 1),
    ]
    for (index, testCase) in cases.enumerated() {
      let prepared = try prepareRoot(
        validStartGate: true,
        slotGeneration: UInt64(40 + index)
      )
      defer { try? abort(prepared) }
      let submitted = try submitAck(
        prepared: prepared,
        accept: testCase.accept,
        proposalCandidatePublicationFingerprint: testCase.candidate,
        proposalHumanIOIdentityFingerprint: testCase.identity
      )
      XCTAssertEqual(submitted.completion.status, .completed)
      let ack = try XCTUnwrap(submitted.completion.ack)
      XCTAssertFalse(ack.permitsPhysicalApply)
      XCTAssertEqual(
        ack.code,
        NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_INVALID_PROPOSAL.rawValue
      )
    }
  }

  func testFastShadowMustMatchPreflightTargetGeneration() throws {
    let prepared = try prepareRoot(validStartGate: true, slotGeneration: 25)
    defer { try? abort(prepared) }
    var fast = prepared.fastStatusBuffer.contents().load(
      as: NBNumanXFastPrepareStatusGPU.self
    )
    fast.shadowGeneration &+= 1
    fast.gateFingerprint = terminalFingerprint(fast)
    write(fast, to: prepared.fastStatusBuffer)
    let submitted = try submitAck(prepared: prepared, accept: true)
    XCTAssertEqual(submitted.completion.status, .completed)
    XCTAssertFalse(try XCTUnwrap(submitted.completion.ack).permitsPhysicalApply)
    XCTAssertEqual(
      submitted.completion.ack?.code,
      NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_INVALID_PREFLIGHT.rawValue
    )
  }

  func testAppliedAcceptIsNonpublishingCanonicalAndExactlyOnce() throws {
    let prepared = try prepareRoot(validStartGate: true, slotGeneration: 26)
    defer { try? abort(prepared) }
    let ack = try submitAck(prepared: prepared, accept: true)
    let applied = try submitApplied(
      prepared: prepared,
      ack: ack.ticket,
      accept: true
    )
    XCTAssertEqual(applied.status, .completed)
    XCTAssertTrue(applied.permitsJointPublication)
    XCTAssertEqual(applied.acceptedPhysicsState, prepared.accepted)
    let validation = try XCTUnwrap(applied.validation)
    XCTAssertEqual(validation.status, .accept)
    XCTAssertEqual(validation.identity, prepared.identity)
    XCTAssertEqual(validation.physicsTokenFingerprint, prepared.accepted.fingerprint)
    XCTAssertEqual(validation.proposalFingerprint, ack.completion.ack?.proposalFingerprint)
    XCTAssertEqual(validation.ackFingerprint, ack.completion.ack?.ackFingerprint)
    XCTAssertEqual(
      validation.fastTargetGeneration,
      prepared.provisional.shadowGeneration
    )
    XCTAssertEqual(prepared.transaction.status, .open)
  }

  func testAppliedRejectCarriesNoCanonicalToken() throws {
    let prepared = try prepareRoot(validStartGate: true, slotGeneration: 27)
    defer { try? abort(prepared) }
    let ack = try submitAck(prepared: prepared, accept: false)
    XCTAssertEqual(ack.completion.ack?.status, NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_REJECT.rawValue)
    let applied = try submitApplied(
      prepared: prepared,
      ack: ack.ticket,
      accept: false
    )
    XCTAssertEqual(applied.status, .completed)
    XCTAssertEqual(applied.validation?.status, .reject)
    XCTAssertNil(applied.acceptedPhysicsState)
    XCTAssertFalse(applied.permitsJointPublication)
    XCTAssertEqual(prepared.transaction.status, .open)
  }

  func testPhysicalRejectResolvesWithZeroGatePendingFastAndFailedWitness()
    throws
  {
    let prepared = try prepareRoot(validStartGate: false, slotGeneration: 44)
    defer { try? abort(prepared) }
    prepared.ticket.numanXPrepareEvaluation!.startGate.resultBuffer.contents()
      .initializeMemory(as: UInt8.self, repeating: 0, count: 128)
    var fast = prepared.fastStatusBuffer.contents().load(
      as: NBNumanXFastPrepareStatusGPU.self
    )
    fast.status = NB_NUMANX_FAST_PREPARE_PENDING.rawValue
    fast.gateFingerprint = terminalFingerprint(fast)
    write(fast, to: prepared.fastStatusBuffer)
    XCTAssertEqual(
      prepared.witness.status,
      NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_PREPARE_FAILED.rawValue
    )

    let ack = try submitAck(
      prepared: prepared,
      accept: false,
      preflightStatus:
        NB_NUMANX_HUMAN_MATTER_BRAIN_PREFLIGHT_PENDING.rawValue
    )
    let ackRecord = try XCTUnwrap(ack.completion.ack)
    XCTAssertEqual(ackRecord.status, NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_REJECT.rawValue)
    XCTAssertEqual(ackRecord.physicsTokenFingerprint, 0)
    XCTAssertEqual(ackRecord.preflightFingerprint, 0)
    XCTAssertEqual(ackRecord.fastGateFingerprint, 0)
    XCTAssertEqual(ackRecord.brainWitnessFingerprint, 0)

    let applied = try submitApplied(
      prepared: prepared,
      ack: ack.ticket,
      accept: false
    )
    XCTAssertEqual(applied.status, .completed)
    XCTAssertEqual(applied.validation?.status, .reject)
    XCTAssertEqual(applied.validation?.physicsTokenFingerprint, 0)
    XCTAssertEqual(applied.validation?.preflightFingerprint, 0)
    XCTAssertEqual(applied.validation?.fastGateFingerprint, 0)
    XCTAssertNil(applied.acceptedPhysicsState)
  }

  func testPhysicalRejectRequiresExactAppliedPhysicalRejectCode() throws {
    let prepared = try prepareRoot(validStartGate: false, slotGeneration: 45)
    defer { try? abort(prepared) }
    prepared.ticket.numanXPrepareEvaluation!.startGate.resultBuffer.contents()
      .initializeMemory(as: UInt8.self, repeating: 0, count: 128)
    var fast = prepared.fastStatusBuffer.contents().load(
      as: NBNumanXFastPrepareStatusGPU.self
    )
    fast.status = NB_NUMANX_FAST_PREPARE_PENDING.rawValue
    fast.gateFingerprint = terminalFingerprint(fast)
    write(fast, to: prepared.fastStatusBuffer)
    XCTAssertEqual(
      prepared.witness.status,
      NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_PREPARE_FAILED.rawValue
    )

    let ack = try submitAck(
      prepared: prepared,
      accept: false,
      preflightStatus:
        NB_NUMANX_HUMAN_MATTER_BRAIN_PREFLIGHT_PENDING.rawValue
    )
    let ackRecord = try XCTUnwrap(ack.completion.ack)
    XCTAssertEqual(ackRecord.status, NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_REJECT.rawValue)
    XCTAssertEqual(ackRecord.preflightFingerprint, 0)
    XCTAssertEqual(ackRecord.fastGateFingerprint, 0)
    XCTAssertEqual(ackRecord.brainWitnessFingerprint, 0)

    let applied = try submitApplied(
      prepared: prepared,
      ack: ack.ticket,
      accept: false,
      appliedCode:
        NB_NUMANX_HUMAN_MATTER_APPLIED_INVALID_BRAIN_ACK.rawValue
    )
    XCTAssertEqual(applied.status, .completed)
    XCTAssertEqual(applied.validation?.status, .invalid)
    XCTAssertEqual(
      applied.validation?.code,
      NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_INVALID_APPLIED.rawValue
    )
    XCTAssertNil(applied.acceptedPhysicsState)
    XCTAssertFalse(applied.permitsJointPublication)
  }

  func testIndependentRejectCauseMappingAcceptsEveryCanonicalPair() throws {
    let mappings: [(proposal: UInt32, applied: UInt32)] = [
      (
        NB_NUMANX_HUMAN_MATTER_PROPOSAL_PHYSICAL_REJECT.rawValue,
        NB_NUMANX_HUMAN_MATTER_APPLIED_PHYSICAL_REJECT.rawValue
      ),
      (
        NB_NUMANX_HUMAN_MATTER_PROPOSAL_TOKEN_MISMATCH.rawValue,
        NB_NUMANX_HUMAN_MATTER_APPLIED_TOKEN_MISMATCH.rawValue
      ),
      (
        NB_NUMANX_HUMAN_MATTER_PROPOSAL_FORCED_REJECT.rawValue,
        NB_NUMANX_HUMAN_MATTER_APPLIED_FORCED_REJECT.rawValue
      ),
      (
        NB_NUMANX_HUMAN_MATTER_PROPOSAL_BRAIN_REJECT.rawValue,
        NB_NUMANX_HUMAN_MATTER_APPLIED_BRAIN_REJECT.rawValue
      ),
      (
        NB_NUMANX_HUMAN_MATTER_PROPOSAL_INVALID_BRAIN_WITNESS.rawValue,
        NB_NUMANX_HUMAN_MATTER_APPLIED_BRAIN_REJECT.rawValue
      ),
    ]
    for (index, mapping) in mappings.enumerated() {
      let prepared = try prepareRoot(
        validStartGate: false,
        slotGeneration: UInt64(50 + index)
      )
      defer { try? abort(prepared) }
      let ack = try submitIndependentRejectAck(
        prepared: prepared,
        proposalCode: mapping.proposal
      )
      XCTAssertEqual(
        ack.completion.ack?.code,
        NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_PROPOSAL_REJECT.rawValue
      )
      let applied = try submitApplied(
        prepared: prepared,
        ack: ack.ticket,
        accept: false,
        appliedCode: mapping.applied
      )
      XCTAssertEqual(applied.status, .completed)
      XCTAssertEqual(applied.validation?.status, .reject)
      XCTAssertEqual(
        applied.validation?.code,
        NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_SUCCESS.rawValue
      )
      XCTAssertNil(applied.acceptedPhysicsState)
    }
  }

  func testIndependentRejectCauseMappingRejectsCrossCodeSubstitution() throws {
    let substitutions: [(proposal: UInt32, wrongApplied: UInt32)] = [
      (
        NB_NUMANX_HUMAN_MATTER_PROPOSAL_PHYSICAL_REJECT.rawValue,
        NB_NUMANX_HUMAN_MATTER_APPLIED_TOKEN_MISMATCH.rawValue
      ),
      (
        NB_NUMANX_HUMAN_MATTER_PROPOSAL_TOKEN_MISMATCH.rawValue,
        NB_NUMANX_HUMAN_MATTER_APPLIED_BRAIN_REJECT.rawValue
      ),
      (
        NB_NUMANX_HUMAN_MATTER_PROPOSAL_FORCED_REJECT.rawValue,
        NB_NUMANX_HUMAN_MATTER_APPLIED_PHYSICAL_REJECT.rawValue
      ),
      (
        NB_NUMANX_HUMAN_MATTER_PROPOSAL_BRAIN_REJECT.rawValue,
        NB_NUMANX_HUMAN_MATTER_APPLIED_FORCED_REJECT.rawValue
      ),
      (
        NB_NUMANX_HUMAN_MATTER_PROPOSAL_INVALID_BRAIN_WITNESS.rawValue,
        NB_NUMANX_HUMAN_MATTER_APPLIED_TOKEN_MISMATCH.rawValue
      ),
    ]
    for (index, substitution) in substitutions.enumerated() {
      let prepared = try prepareRoot(
        validStartGate: false,
        slotGeneration: UInt64(60 + index)
      )
      defer { try? abort(prepared) }
      let ack = try submitIndependentRejectAck(
        prepared: prepared,
        proposalCode: substitution.proposal
      )
      let applied = try submitApplied(
        prepared: prepared,
        ack: ack.ticket,
        accept: false,
        appliedCode: substitution.wrongApplied
      )
      XCTAssertEqual(applied.status, .completed)
      XCTAssertEqual(applied.validation?.status, .invalid)
      XCTAssertEqual(
        applied.validation?.code,
        NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_INVALID_APPLIED.rawValue
      )
      XCTAssertNil(applied.acceptedPhysicsState)
      XCTAssertFalse(applied.permitsJointPublication)
    }
  }

  func testIndependentRejectRequiresExactProposalRejectAck() throws {
    let prepared = try prepareRoot(validStartGate: false, slotGeneration: 65)
    defer { try? abort(prepared) }
    let ack = try submitIndependentRejectAck(
      prepared: prepared,
      proposalCode:
        NB_NUMANX_HUMAN_MATTER_PROPOSAL_PHYSICAL_REJECT.rawValue
    )
    var ackRecord = ack.ticket.ackLease.buffer.contents().load(
      as: NBNumanXHumanMatterBrainAckGPU.self
    )
    ackRecord.code = NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_INVALID_PROPOSAL.rawValue
    ackRecord.ackFingerprint = terminalFingerprint(ackRecord)
    write(ackRecord, to: ack.ticket.ackLease.buffer)

    let applied = try submitApplied(
      prepared: prepared,
      ack: ack.ticket,
      accept: false,
      appliedCode: NB_NUMANX_HUMAN_MATTER_APPLIED_PHYSICAL_REJECT.rawValue
    )
    XCTAssertEqual(applied.status, .completed)
    XCTAssertEqual(applied.validation?.status, .invalid)
    XCTAssertEqual(
      applied.validation?.code,
      NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_INVALID_ACK.rawValue
    )
    XCTAssertNil(applied.acceptedPhysicsState)
  }

  func testInvalidOwnerCannotEnterReadyIndependentReject() throws {
    let prepared = try prepareRoot(validStartGate: false, slotGeneration: 66)
    defer { try? abort(prepared) }
    let ack = try submitIndependentRejectAck(
      prepared: prepared,
      proposalCode: NB_NUMANX_HUMAN_MATTER_PROPOSAL_INVALID_OWNER.rawValue
    )
    XCTAssertEqual(ack.completion.status, .completed)
    XCTAssertEqual(
      ack.completion.ack?.status,
      NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_INVALID.rawValue
    )
    XCTAssertEqual(
      ack.completion.ack?.code,
      NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_INVALID_PROPOSAL.rawValue
    )
    XCTAssertFalse(try XCTUnwrap(ack.completion.ack).permitsPhysicalApply)
  }

  func testMaximumHashAdmissionIsBoundedAndPreallocated() throws {
    let layout = try MetalNumanXBrainHashLayout.admit(
      hotByteCount: MetalNumanXBrainCommitPrepareRequest.maximumHashedByteCount,
      journalByteCount: 0,
      fastByteCount: 0
    )
    XCTAssertEqual(layout.totalByteCount, 1 << 30)
    XCTAssertEqual(layout.chunkCount, 1_048_576)
    XCTAssertEqual(layout.scratchByteCount, 8 * 1_048_576)
    XCTAssertEqual(layout.reductionCounts, [4_096, 16, 1])
    XCTAssertThrowsError(try MetalNumanXBrainHashLayout.admit(
      hotByteCount:
        MetalNumanXBrainCommitPrepareRequest.maximumHashedByteCount + 1,
      journalByteCount: 0,
      fastByteCount: 0
    ))
  }

  private func prepareRoot(
    validStartGate: Bool,
    slotGeneration: UInt64
  ) throws -> PreparedRoot {
    let device = try requireMetal4Device()
    let compiled = try makeNumanXInteropCompiledTemplate()
    let parameters = TissueParameters.corticalSheetV0
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: compiled.species,
      tissueParameters: parameters
    )
    let regionalProgram = try compiled.species.regionalProgram()
    let runtime = try MetalEmbodiedBrainRuntime(
      device: device,
      compiledSpeciesTemplate: compiled,
      regionalProgram: regionalProgram,
      parameterVersion: publication.version,
      sharedParameterArtifact: publication.sharedArtifact
    )
    let root = try BrainJointTransactionToken(
      environmentIdentifier: 0,
      episodeIdentifier: 23,
      controlStepIdentifier: 37,
      parameterVersionFingerprint: publication.version.fingerprint,
      baseBrainGeneration: 0,
      basePhysicsGeneration: 100,
      committedTimestamp: BrainTimestamp(microseconds: 10_000),
      targetTimestamp: BrainTimestamp(microseconds: 11_000),
      randomCounterGeneration: 0
    )
    let transaction = try runtime.beginControl(
      jointToken: root,
      cachedDecisionFingerprint: 0x6a7e_9001
    )
    let recurrentBuffer = try XCTUnwrap(device.makeBuffer(
      length: regionalProgram.scalarCount * MemoryLayout<Float>.stride,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ))
    recurrentBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: recurrentBuffer.length
    )
    let recurrent = try MetalRegionalRecurrentBufferView(
      gpuAddress: recurrentBuffer.gpuAddress,
      scalarCount: regionalProgram.scalarCount,
      regionalProgramFingerprint: regionalProgram.fingerprint
    )
    _ = try runtime.inferAndDecide(
      transaction: transaction,
      rawSensors: try makeRawSensors(
        device: device,
        compiled: compiled,
        deliveryTimestamp: root.committedTimestamp
      ),
      regionalRecurrentInput: recurrent
    )
    var physical = BrainJointTransaction(token: root)
    let substep = try physical.beginPhysicsSubstep(durationMicroseconds: 1_000)
    let provisional = try physical.prepareProvisionalPhysicsAcceptance(for: substep)
    let accepted = try AcceptedPhysicsStateToken(
      transaction: root,
      substep: substep,
      physicsStateFingerprint: 0x4d41_5454_4552,
      physicsGeneration: 101
    )
    let gateBuffer = try sharedBuffer(
      device,
      byteCount: MetalAcceptedPhysicsGateLease.byteCount
    )
    gateBuffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: gateBuffer.length
    )
    if validStartGate { write(accepted.abiRecord, to: gateBuffer) }
    let gate = try MetalAcceptedPhysicsGateLease(buffer: gateBuffer)

    let firstFastBuffer = try sharedBuffer(device, byteCount: 768)
    let secondFastBuffer = try sharedBuffer(device, byteCount: 768)
    fill(firstFastBuffer, seed: 0x31)
    fill(secondFastBuffer, seed: 0x72)
    let sources = try [
      MetalNumanXBrainFastStateSource(
        buffer: secondFastBuffer,
        byteOffset: 8,
        byteCount: 704,
        semanticIdentifier: 20
      ),
      MetalNumanXBrainFastStateSource(
        buffer: firstFastBuffer,
        byteOffset: 16,
        byteCount: 704,
        semanticIdentifier: 10
      ),
    ]
    let identity = try rootIdentity(
      transactionFingerprint: root.fingerprint,
      generation: slotGeneration
    )
    let fastProgramFingerprint: UInt64 = 0x4641_5354_5052_4f47
    let fastEvent = try XCTUnwrap(device.makeSharedEvent())
    let fastPoint = try MetalSharedEventPoint(event: fastEvent, value: 1)
    let fastStatusBuffer = try sharedBuffer(device, byteCount: 128)
    var fast = NBNumanXFastPrepareStatusGPU()
    fast.abiVersion = UInt32(NB_NUMANX_FAST_PREPARE_STATUS_ABI_VERSION)
    fast.structBytes = UInt32(NB_NUMANX_FAST_PREPARE_STATUS_BYTE_COUNT)
    fast.status = NB_NUMANX_FAST_PREPARE_SUCCESS.rawValue
    fast.environment = identity.environment
    fast.controlStep = identity.controlStep
    fast.substepIndex = identity.substepIndex
    fast.physicsSubstepCount = identity.physicsSubstepCount
    fast.fastProgramFingerprint = fastProgramFingerprint
    fast.transactionFingerprint = root.fingerprint
    fast.substepFingerprint = substep.fingerprint
    fast.expectedPhysicsGeneration = provisional.expectedPhysicsGeneration
    fast.shadowGeneration = provisional.shadowGeneration
    fast.acceptedTimestampMicroseconds = provisional.acceptedTimestamp.rawValue
    fast.gateFingerprint = terminalFingerprint(fast)
    write(fast, to: fastStatusBuffer)
    let fastStatus = try MetalNumanXFastPrepareStatusLease(
      buffer: fastStatusBuffer,
      readyPoint: fastPoint,
      fastProgramFingerprint: fastProgramFingerprint
    )
    let request = try MetalNumanXBrainCommitPrepareRequest(
      identity: identity,
      provisionalPhysicsAcceptance: provisional,
      fastPrepareStatus: fastStatus,
      fastStateSources: sources
    )
    let prepareEvent = try XCTUnwrap(device.makeSharedEvent())
    let ticket = try runtime.submitAcceptedConsequence(
      transaction: transaction,
      candidateSubstep: substep,
      acceptedPhysicsGate: gate,
      rawSensors: try makeRawSensors(
        device: device,
        compiled: compiled,
        deliveryTimestamp: accepted.acceptedTimestamp
      ),
      acceptedRegionalRecurrentInput: recurrent,
      numanXRootPrepare: request,
      waitFor: fastPoint,
      signal: try MetalSharedEventPoint(event: prepareEvent, value: 1)
    )
    fastEvent.signaledValue = 1
    _ = try ticket.waitUntilCompleted(timeoutMilliseconds: 10_000)
    XCTAssertGreaterThanOrEqual(prepareEvent.signaledValue, 1)
    let witness = ticket.numanXPrepareEvaluation!.witnessBuffer.contents().load(
      as: NBNumanXHumanMatterBrainCommitWitness.self
    )
    return PreparedRoot(
      device: device,
      runtime: runtime,
      transaction: transaction,
      ticket: ticket,
      accepted: accepted,
      provisional: provisional,
      identity: identity,
      fastStatusBuffer: fastStatusBuffer,
      fastProgramFingerprint: fastProgramFingerprint,
      witness: witness
    )
  }

  private func submitAck(
    prepared: PreparedRoot,
    accept: Bool,
    proposalCode: UInt32? = nil,
    proposalCandidatePublicationFingerprint: UInt64? = nil,
    proposalHumanIOIdentityFingerprint: UInt64? = nil,
    expectedCandidatePublicationFingerprint: UInt64? = nil,
    expectedHumanIOIdentityFingerprint: UInt64? = nil,
    preflightStatus: UInt32? = nil
  ) throws -> AckSubmission {
    var proposal = makeProposal(prepared: prepared, accept: accept)
    if let proposalCode { proposal.code = proposalCode }
    if let proposalCandidatePublicationFingerprint {
      proposal.candidatePublicationFingerprint =
        proposalCandidatePublicationFingerprint
    }
    if let proposalHumanIOIdentityFingerprint {
      proposal.humanIOIdentityFingerprint = proposalHumanIOIdentityFingerprint
    }
    proposal.proposalFingerprint = terminalFingerprint(proposal)
    let proposedToken = accept
      ? prepared.accepted.abiRecord : NBAcceptedPhysicsStateToken()
    let fence = makePendingFence(prepared: prepared)
    let proposalBuffer = try sharedBuffer(prepared.device, byteCount: 128)
    let tokenBuffer = try sharedBuffer(prepared.device, byteCount: 64)
    let fenceBuffer = try sharedBuffer(prepared.device, byteCount: 128)
    write(proposal, to: proposalBuffer)
    write(proposedToken, to: tokenBuffer)
    write(fence, to: fenceBuffer)
    let proposalEvent = try XCTUnwrap(prepared.device.makeSharedEvent())
    let proposalPoint = try MetalSharedEventPoint(event: proposalEvent, value: 1)
    let proposalLease = try MetalNumanXHumanMatterProposalLease(
      identity: prepared.identity,
      proposalBuffer: proposalBuffer,
      proposalGPUAddress: proposalBuffer.gpuAddress,
      proposalElementCount: 1,
      proposalStride: 1,
      proposedTokenBuffer: tokenBuffer,
      proposedTokenGPUAddress: tokenBuffer.gpuAddress,
      proposedTokenByteCount: 64,
      proposedTokenStride: 64,
      publicationFenceBuffer: fenceBuffer,
      publicationFenceGPUAddress: fenceBuffer.gpuAddress,
      publicationFenceElementCount: 1,
      publicationFenceStride: 1,
      readyPoint: proposalPoint
    )

    var preflight = makePreflight(prepared: prepared, proposal: proposal)
    if let preflightStatus {
      preflight.status = preflightStatus
      if preflightStatus != NB_NUMANX_HUMAN_MATTER_BRAIN_PREFLIGHT_SUCCESS.rawValue {
        preflight.physicsTokenFingerprint = 0
        preflight.jointReceiptFingerprint = 0
      }
      preflight.preflightFingerprint = terminalFingerprint(preflight)
    }
    let preflightBuffer = try sharedBuffer(prepared.device, byteCount: 128)
    write(preflight, to: preflightBuffer)
    let preflightEvent = try XCTUnwrap(prepared.device.makeSharedEvent())
    let preflightPoint = try MetalSharedEventPoint(event: preflightEvent, value: 1)
    let preflightLease = try MetalNumanXHumanMatterBrainPreflightLease(
      identity: prepared.identity,
      buffer: preflightBuffer,
      gpuAddress: preflightBuffer.gpuAddress,
      elementCount: 1,
      stride: 1,
      candidatePublicationFingerprint:
        expectedCandidatePublicationFingerprint
          ?? makeProposal(prepared: prepared, accept: accept)
            .candidatePublicationFingerprint,
      humanIOIdentityFingerprint:
        expectedHumanIOIdentityFingerprint
          ?? makeProposal(prepared: prepared, accept: accept)
            .humanIOIdentityFingerprint,
      readyPoint: preflightPoint
    )
    let completionEvent = try XCTUnwrap(prepared.device.makeSharedEvent())
    proposalEvent.signaledValue = proposalPoint.value
    preflightEvent.signaledValue = preflightPoint.value
    let ticket = try prepared.runtime.submitNumanXBrainAck(
      prepared: prepared.ticket,
      proposal: proposalLease,
      preflight: preflightLease,
      signal: try MetalSharedEventPoint(event: completionEvent, value: 1)
    )
    let completion = try waitForAck(ticket)
    return AckSubmission(ticket: ticket, completion: completion)
  }

  private func submitIndependentRejectAck(
    prepared: PreparedRoot,
    proposalCode: UInt32
  ) throws -> AckSubmission {
    prepared.ticket.numanXPrepareEvaluation!.startGate.resultBuffer.contents()
      .initializeMemory(as: UInt8.self, repeating: 0, count: 128)
    var fast = prepared.fastStatusBuffer.contents().load(
      as: NBNumanXFastPrepareStatusGPU.self
    )
    fast.status = NB_NUMANX_FAST_PREPARE_PENDING.rawValue
    fast.gateFingerprint = terminalFingerprint(fast)
    write(fast, to: prepared.fastStatusBuffer)
    return try submitAck(
      prepared: prepared,
      accept: false,
      proposalCode: proposalCode,
      preflightStatus:
        NB_NUMANX_HUMAN_MATTER_BRAIN_PREFLIGHT_PENDING.rawValue
    )
  }

  private func submitApplied(
    prepared: PreparedRoot,
    ack: MetalNumanXHumanMatterBrainAckTicket,
    accept: Bool,
    appliedCode: UInt32? = nil
  ) throws -> MetalNumanXHumanMatterAppliedCompletion {
    let ackRecord = ack.ackLease.buffer.contents().load(
      as: NBNumanXHumanMatterBrainAckGPU.self
    )
    var applied = NBNumanXHumanMatterAppliedOutcomeGPU()
    applied.abiVersion = UInt32(NB_NUMANX_HUMAN_MATTER_ABI_VERSION)
    applied.status = accept
      ? NB_NUMANX_HUMAN_MATTER_APPLIED_ACCEPT_QUARANTINED.rawValue
      : NB_NUMANX_HUMAN_MATTER_APPLIED_REJECT_RESTORED.rawValue
    applied.decision = accept
      ? NB_NUMANX_HUMAN_MATTER_ROOT_ACCEPT.rawValue
      : NB_NUMANX_HUMAN_MATTER_ROOT_REJECT.rawValue
    applied.code = appliedCode ?? (accept
      ? NB_NUMANX_HUMAN_MATTER_APPLIED_SUCCESS.rawValue
      : NB_NUMANX_HUMAN_MATTER_APPLIED_PHYSICAL_REJECT.rawValue)
    applied.programFingerprint = prepared.identity.programFingerprint
    applied.transactionFingerprint = prepared.identity.transactionFingerprint
    applied.linearizationEpoch = prepared.identity.linearizationEpoch
    applied.slotGeneration = prepared.identity.slotGeneration
    applied.physicsTokenFingerprint = accept ? prepared.accepted.fingerprint : 0
    applied.proposalFingerprint = ackRecord.proposalFingerprint
    applied.ackFingerprint = ackRecord.ackFingerprint
    applied.preflightFingerprint = ackRecord.preflightFingerprint
    applied.fastGateFingerprint = ackRecord.fastGateFingerprint
    applied.matterApplyFingerprint = 0x4d41_5454_4150_504c
    applied.environment = prepared.identity.environment
    applied.stepIndex = prepared.identity.stepIndex
    applied.substepIndex = prepared.identity.substepIndex
    applied.transactionSlot = prepared.identity.transactionSlot
    applied.physicsSubstepCount = prepared.identity.physicsSubstepCount
    applied.controlStep = prepared.identity.controlStep
    applied.appliedFingerprint = terminalFingerprint(applied)
    let finalToken = accept
      ? prepared.accepted.abiRecord : NBAcceptedPhysicsStateToken()
    let appliedBuffer = try sharedBuffer(prepared.device, byteCount: 128)
    let finalTokenBuffer = try sharedBuffer(prepared.device, byteCount: 64)
    write(applied, to: appliedBuffer)
    write(finalToken, to: finalTokenBuffer)
    let appliedEvent = try XCTUnwrap(prepared.device.makeSharedEvent())
    let appliedPoint = try MetalSharedEventPoint(event: appliedEvent, value: 1)
    let lease = try MetalNumanXHumanMatterAppliedLease(
      identity: prepared.identity,
      appliedBuffer: appliedBuffer,
      appliedGPUAddress: appliedBuffer.gpuAddress,
      appliedElementCount: 1,
      appliedStride: 1,
      finalTokenBuffer: finalTokenBuffer,
      finalTokenGPUAddress: finalTokenBuffer.gpuAddress,
      finalTokenByteCount: 64,
      finalTokenStride: 64,
      readyPoint: appliedPoint,
      commandDisposition: accept
        ? .acceptedPendingPublication : .rejectedReleased
    )
    let completionEvent = try XCTUnwrap(prepared.device.makeSharedEvent())
    appliedEvent.signaledValue = appliedPoint.value
    let ticket = try prepared.runtime.validateNumanXAppliedRoot(
      ack: ack,
      applied: lease,
      signal: try MetalSharedEventPoint(event: completionEvent, value: 1)
    )
    return try waitForApplied(ticket)
  }

  private func makeProposal(
    prepared: PreparedRoot,
    accept: Bool
  ) -> NBNumanXHumanMatterProposalGPU {
    var value = NBNumanXHumanMatterProposalGPU()
    value.abiVersion = UInt32(NB_NUMANX_HUMAN_MATTER_ABI_VERSION)
    value.status = NB_NUMANX_HUMAN_MATTER_PROPOSAL_READY.rawValue
    value.decision = accept
      ? NB_NUMANX_HUMAN_MATTER_ROOT_ACCEPT.rawValue
      : NB_NUMANX_HUMAN_MATTER_ROOT_REJECT.rawValue
    value.code = accept
      ? NB_NUMANX_HUMAN_MATTER_PROPOSAL_SUCCESS.rawValue
      : NB_NUMANX_HUMAN_MATTER_PROPOSAL_PHYSICAL_REJECT.rawValue
    value.programFingerprint = prepared.identity.programFingerprint
    value.transactionFingerprint = prepared.identity.transactionFingerprint
    value.linearizationEpoch = prepared.identity.linearizationEpoch
    value.slotGeneration = prepared.identity.slotGeneration
    value.physicsTokenFingerprint = accept ? prepared.accepted.fingerprint : 0
    if accept {
      value.brainProgramFingerprint = prepared.witness.brainProgramFingerprint
      value.brainShadowStateFingerprint =
        prepared.witness.brainShadowStateFingerprint
      value.brainWitnessFingerprint = prepared.witness.witnessFingerprint
    }
    value.candidatePublicationFingerprint = 0x4341_4e44_5055_4201
    value.humanIOIdentityFingerprint = 0x4855_4d49_4445_4e01
    value.environment = prepared.identity.environment
    value.stepIndex = prepared.identity.stepIndex
    value.substepIndex = prepared.identity.substepIndex
    value.transactionSlot = prepared.identity.transactionSlot
    value.physicsSubstepCount = prepared.identity.physicsSubstepCount
    value.controlStep = prepared.identity.controlStep
    value.proposalFingerprint = terminalFingerprint(value)
    return value
  }

  private func makePreflight(
    prepared: PreparedRoot,
    proposal: NBNumanXHumanMatterProposalGPU
  ) -> NBNumanXHumanMatterBrainCommitPreflightGPU {
    var value = NBNumanXHumanMatterBrainCommitPreflightGPU()
    value.abiVersion = UInt32(NB_NUMANX_HUMAN_MATTER_BRAIN_PREFLIGHT_ABI_VERSION)
    value.structBytes = UInt32(NB_NUMANX_HUMAN_MATTER_BRAIN_PREFLIGHT_BYTE_COUNT)
    value.status = NB_NUMANX_HUMAN_MATTER_BRAIN_PREFLIGHT_SUCCESS.rawValue
    value.environment = prepared.identity.environment
    value.controlStep = prepared.identity.controlStep
    value.substepIndex = prepared.identity.substepIndex
    value.physicsSubstepCount = prepared.identity.physicsSubstepCount
    value.transactionSlot = prepared.identity.transactionSlot
    value.ownerProgramFingerprint = prepared.identity.programFingerprint
    value.transactionFingerprint = prepared.identity.transactionFingerprint
    value.linearizationEpoch = prepared.identity.linearizationEpoch
    value.slotGeneration = prepared.identity.slotGeneration
    value.substepFingerprint = prepared.provisional.substepFingerprint
    // Production preflight is prepared before the owner proposal is reduced
    // to ACCEPT/REJECT and therefore always binds the canonical start token.
    value.physicsTokenFingerprint = prepared.accepted.fingerprint
    value.fastTargetGeneration = prepared.provisional.shadowGeneration
    value.cognitiveTargetGeneration = prepared.provisional.shadowGeneration
    value.jointReceiptFingerprint = 0x5245_4345_4950_5431
    value.fastProgramFingerprint = prepared.fastProgramFingerprint
    value.brainProgramFingerprint = prepared.witness.brainProgramFingerprint
    value.preflightFingerprint = terminalFingerprint(value)
    return value
  }

  private func makePendingFence(
    prepared: PreparedRoot
  ) -> NBNumanXHumanMatterJointPublicationFenceGPU {
    var value = NBNumanXHumanMatterJointPublicationFenceGPU()
    value.abiVersion = UInt32(
      NB_NUMANX_HUMAN_MATTER_PUBLICATION_FENCE_ABI_VERSION
    )
    value.structBytes = UInt32(
      NB_NUMANX_HUMAN_MATTER_PUBLICATION_FENCE_BYTE_COUNT
    )
    value.status = NB_NUMANX_HUMAN_MATTER_PUBLICATION_PENDING.rawValue
    value.environment = prepared.identity.environment
    value.controlStep = prepared.identity.controlStep
    value.substepIndex = prepared.identity.substepIndex
    value.physicsSubstepCount = prepared.identity.physicsSubstepCount
    value.ownerProgramFingerprint = prepared.identity.programFingerprint
    value.transactionFingerprint = prepared.identity.transactionFingerprint
    value.linearizationEpoch = prepared.identity.linearizationEpoch
    value.slotGeneration = prepared.identity.slotGeneration
    value.physicsTokenFingerprint = prepared.accepted.fingerprint
    value.brainProgramFingerprint = prepared.witness.brainProgramFingerprint
    value.brainShadowStateFingerprint =
      prepared.witness.brainShadowStateFingerprint
    value.brainWitnessFingerprint = prepared.witness.witnessFingerprint
    value.fenceFingerprint = terminalFingerprint(value)
    return value
  }

  private func waitForAck(
    _ ticket: MetalNumanXHumanMatterBrainAckTicket
  ) throws -> MetalNumanXHumanMatterBrainAckCompletion {
    let box = LockedBox<MetalNumanXHumanMatterBrainAckCompletion>()
    let semaphore = DispatchSemaphore(value: 0)
    try ticket.onCompleted { completion in
      box.store(completion)
      semaphore.signal()
    }
    XCTAssertThrowsError(try ticket.onCompleted { _ in })
    XCTAssertEqual(semaphore.wait(timeout: .now() + 10), .success)
    return try XCTUnwrap(box.load())
  }

  private func waitForApplied(
    _ ticket: MetalNumanXHumanMatterAppliedValidationTicket
  ) throws -> MetalNumanXHumanMatterAppliedCompletion {
    let box = LockedBox<MetalNumanXHumanMatterAppliedCompletion>()
    let semaphore = DispatchSemaphore(value: 0)
    try ticket.onCompleted { completion in
      box.store(completion)
      semaphore.signal()
    }
    XCTAssertThrowsError(try ticket.onCompleted { _ in })
    XCTAssertEqual(semaphore.wait(timeout: .now() + 10), .success)
    return try XCTUnwrap(box.load())
  }

  private func rootIdentity(
    transactionFingerprint: UInt64,
    generation: UInt64
  ) throws -> MetalNumanXHumanMatterRootIdentity {
    try MetalNumanXHumanMatterRootIdentity(
      programFingerprint: 0x4855_4d41_4e4d_4154,
      transactionFingerprint: transactionFingerprint,
      linearizationEpoch: 0x100,
      slotGeneration: generation,
      transactionSlot: 3,
      environment: 0,
      controlStep: 37
    )
  }

  private func sharedBuffer(
    _ device: any MTLDevice,
    byteCount: Int
  ) throws -> any MTLBuffer {
    let buffer = try XCTUnwrap(device.makeBuffer(
      length: byteCount,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ))
    buffer.contents().initializeMemory(
      as: UInt8.self, repeating: 0, count: buffer.length
    )
    return buffer
  }

  private func write<T>(_ value: T, to buffer: any MTLBuffer) {
    var value = value
    withUnsafeBytes(of: &value) { source in
      precondition(source.count <= buffer.length)
      buffer.contents().copyMemory(
        from: source.baseAddress!, byteCount: source.count
      )
    }
  }

  private func bytes(_ buffer: any MTLBuffer, count: Int) -> Data {
    Data(bytes: buffer.contents(), count: count)
  }

  private var fnvOffset: UInt64 { 14_695_981_039_346_656_037 }

  private func terminalFingerprint<T>(_ value: T) -> UInt64 {
    var value = value
    var hash = fnvOffset
    withUnsafeBytes(of: &value) { bytes in
      precondition(bytes.count >= 8)
      for byte in bytes.dropLast(8) {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
      }
    }
    return hash == 0 ? fnvOffset : hash
  }

  private func fill(_ buffer: any MTLBuffer, seed: UInt8) {
    let bytes = buffer.contents().assumingMemoryBound(to: UInt8.self)
    for index in 0..<buffer.length {
      bytes[index] = seed &+ UInt8(truncatingIfNeeded: index &* 17)
    }
  }

  private func abort(_ prepared: PreparedRoot) throws {
    try prepared.runtime.abortAcceptedConsequenceSubmission(
      prepared.ticket,
      transaction: prepared.transaction,
      timeoutMilliseconds: 10_000
    )
    XCTAssertEqual(prepared.transaction.status, .aborted)
  }

  private func makeRawSensors(
    device: any MTLDevice,
    compiled: CompiledSpeciesTemplate,
    deliveryTimestamp: BrainTimestamp
  ) throws -> [MetalRawSensorBufferLease] {
    try compiled.species.senses.filter(\.enabled).enumerated().map {
      sensorIndex, topology in
      let scalarCount = Int(topology.receptorCount)
        * Int(topology.observationDimension)
      let buffer = try sharedBuffer(
        device,
        byteCount: scalarCount * MemoryLayout<Float>.stride
      )
      let scalars = buffer.contents().assumingMemoryBound(to: Float.self)
      for index in 0..<scalarCount {
        scalars[index] = Float(sensorIndex + 1) * 0.125
          + Float(index) * 0.03125
      }
      let validity: (any MTLBuffer)?
      if topology.modality == .proprioception {
        let created = try sharedBuffer(
          device,
          byteCount: Int(topology.receptorCount) * MemoryLayout<UInt32>.stride
        )
        created.contents().assumingMemoryBound(to: UInt32.self).initialize(
          repeating: 1,
          count: Int(topology.receptorCount)
        )
        validity = created
      } else {
        validity = nil
      }
      return try MetalRawSensorBufferLease(
        buffer: buffer,
        modality: topology.modality,
        receptorTimestamp: BrainTimestamp(
          microseconds: deliveryTimestamp.rawValue
            - UInt64(topology.latencyMicroseconds)
        ),
        receptorCount: topology.receptorCount,
        featureDimension: topology.observationDimension,
        validityBuffer: validity
      )
    }
  }

  private func requireMetal4Device() throws -> any MTLDevice {
    guard let device = MTLCreateSystemDefaultDevice(),
      device.makeMTL4CommandQueue() != nil,
      device.makeCommandAllocator() != nil,
      device.makeCommandBuffer() != nil,
      device.makeSharedEvent() != nil
    else {
      throw XCTSkip("Metal 4 shared-event execution is unavailable")
    }
    return device
  }
}

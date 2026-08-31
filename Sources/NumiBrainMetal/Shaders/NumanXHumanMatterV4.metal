#include <metal_stdlib>
using namespace metal;

constant uint NB_HM_ABI_VERSION = 4u;
constant uint NB_HM_WITNESS_ABI_VERSION = 1u;
constant uint NB_HM_WITNESS_MAGIC = 0x4e584257u;
constant uint NB_HM_WITNESS_BYTES = 128u;
constant uint NB_HM_PHYSICS_SUBSTEP_COUNT = 1u;
constant uint NB_HM_ROOT_ACCEPT = 1u;
constant uint NB_HM_ROOT_REJECT = 2u;
constant uint NB_HM_PREPARE_COMPLETE = 1u;
constant uint NB_HM_PREPARE_FAILED = 2u;
constant uint NB_HM_PROPOSAL_READY = 1u;
constant uint NB_HM_PROPOSAL_SUCCESS = 0u;
constant uint NB_HM_PROPOSAL_PHYSICAL_REJECT = 1u;
constant uint NB_HM_PROPOSAL_INVALID_OWNER = 2u;
constant uint NB_HM_PROPOSAL_INVALID_BRAIN_WITNESS = 3u;
constant uint NB_HM_PROPOSAL_TOKEN_MISMATCH = 4u;
constant uint NB_HM_PROPOSAL_FORCED_REJECT = 5u;
constant uint NB_HM_PROPOSAL_BRAIN_REJECT = 6u;
constant uint NB_HM_BRAIN_PREFLIGHT_ABI_VERSION = 1u;
constant uint NB_HM_BRAIN_PREFLIGHT_BYTES = 128u;
constant uint NB_HM_BRAIN_PREFLIGHT_PENDING = 0u;
constant uint NB_HM_BRAIN_PREFLIGHT_SUCCESS = 1u;
constant uint NB_HM_BRAIN_PREFLIGHT_FAILURE = 2u;
constant uint NB_HM_BRAIN_ACK_ABI_VERSION = 1u;
constant uint NB_HM_BRAIN_ACK_ACCEPT = 1u;
constant uint NB_HM_BRAIN_ACK_REJECT = 2u;
constant uint NB_HM_BRAIN_ACK_INVALID = 3u;
constant uint NB_HM_BRAIN_ACK_SUCCESS = 0u;
constant uint NB_HM_BRAIN_ACK_PROPOSAL_REJECT = 1u;
constant uint NB_HM_BRAIN_ACK_INVALID_PROPOSAL = 2u;
constant uint NB_HM_BRAIN_ACK_INVALID_WITNESS = 3u;
constant uint NB_HM_BRAIN_ACK_INVALID_FAST_GATE = 4u;
constant uint NB_HM_BRAIN_ACK_INVALID_PREFLIGHT = 5u;
constant uint NB_HM_BRAIN_ACK_TOKEN_MISMATCH = 6u;
constant uint NB_HM_APPLIED_ACCEPT_QUARANTINED = 1u;
constant uint NB_HM_APPLIED_REJECT_RESTORED = 2u;
constant uint NB_HM_APPLIED_TERMINAL_NO_TOUCH = 3u;
constant uint NB_HM_APPLIED_SUCCESS = 0u;
constant uint NB_HM_APPLIED_FORCED_REJECT = 1u;
constant uint NB_HM_APPLIED_PHYSICAL_REJECT = 2u;
constant uint NB_HM_APPLIED_TOKEN_MISMATCH = 5u;
constant uint NB_HM_APPLIED_BRAIN_REJECT = 8u;
constant uint NB_HM_INVALID_REJECT_CODE = 0xffffffffu;
constant uint NB_HM_APPLIED_VALIDATION_ABI_VERSION = 1u;
constant uint NB_HM_APPLIED_VALIDATION_BYTES = 256u;
constant uint NB_HM_APPLIED_VALIDATION_ACCEPT = 1u;
constant uint NB_HM_APPLIED_VALIDATION_REJECT = 2u;
constant uint NB_HM_APPLIED_VALIDATION_INVALID = 3u;
constant uint NB_HM_APPLIED_VALIDATION_TERMINAL_NO_TOUCH = 4u;
constant uint NB_HM_APPLIED_VALIDATION_SUCCESS = 0u;
constant uint NB_HM_APPLIED_VALIDATION_INVALID_WITNESS = 1u;
constant uint NB_HM_APPLIED_VALIDATION_INVALID_PROPOSAL = 2u;
constant uint NB_HM_APPLIED_VALIDATION_INVALID_PREFLIGHT = 3u;
constant uint NB_HM_APPLIED_VALIDATION_INVALID_ACK = 4u;
constant uint NB_HM_APPLIED_VALIDATION_INVALID_APPLIED = 5u;
constant uint NB_HM_APPLIED_VALIDATION_INVALID_TOKEN = 6u;
constant uint NB_HM_APPLIED_VALIDATION_IDENTITY_MISMATCH = 7u;
constant uint NB_HM_APPLIED_VALIDATION_COMMAND_NOT_SUCCESSFUL = 8u;
constant uint NB_HM_COMMAND_ACCEPTED_PENDING_PUBLICATION = 1u;
constant uint NB_HM_COMMAND_REJECTED_RELEASED = 2u;
constant uint NB_HM_COMMAND_TERMINAL_NO_TOUCH = 3u;
constant uint NB_ACCEPTED_PHYSICS_GATE_VERSION = 1u;
constant uint NB_ACCEPTED_PHYSICS_GATE_VALID = 1u;
constant uint NB_JOINT_TRANSACTION_VERSION = 1u;
constant uint NB_AGENT_ARENA_VERSION = 1u;
constant uint NB_AGENT_JOURNAL_STATUS_VALID = 1u;
constant ulong NB_FNV_OFFSET = 14695981039346656037ul;
constant ulong NB_FNV_PRIME = 1099511628211ul;
constant uint NB_HM_HASH_CHUNK_BYTES = 1024u;
constant uint NB_HM_HASH_TREE_FANOUT = 256u;
constant ulong NB_HM_MAXIMUM_HASH_BYTES = 1ul << 30u;
constant uint NB_HM_HASH_CHUNK_DOMAIN = 1u;
constant uint NB_HM_HASH_REDUCE_DOMAIN = 2u;
constant uint NB_HM_HASH_FINAL_DOMAIN = 3u;
constant uint NB_FAST_PREPARE_STATUS_ABI_VERSION = 1u;
constant uint NB_FAST_PREPARE_STATUS_BYTES = 128u;
constant uint NB_FAST_PREPARE_SUCCESS = 1u;

/// Canonical owner proposal-cause to applied-cause mapping for the independent
/// zero-gate REJECT path. INVALID_OWNER is intentionally absent: its owner
/// record is TERMINAL_NO_TOUCH, never a READY proposal with rollback authority.
inline uint nb_independent_reject_applied_code(uint proposalCode)
{
  switch (proposalCode) {
    case NB_HM_PROPOSAL_PHYSICAL_REJECT:
      return NB_HM_APPLIED_PHYSICAL_REJECT;
    case NB_HM_PROPOSAL_INVALID_OWNER:
      return NB_HM_INVALID_REJECT_CODE;
    case NB_HM_PROPOSAL_INVALID_BRAIN_WITNESS:
      return NB_HM_APPLIED_BRAIN_REJECT;
    case NB_HM_PROPOSAL_TOKEN_MISMATCH:
      return NB_HM_APPLIED_TOKEN_MISMATCH;
    case NB_HM_PROPOSAL_FORCED_REJECT:
      return NB_HM_APPLIED_FORCED_REJECT;
    case NB_HM_PROPOSAL_BRAIN_REJECT:
      return NB_HM_APPLIED_BRAIN_REJECT;
    default:
      return NB_HM_INVALID_REJECT_CODE;
  }
}

struct NBAcceptedPhysicsStateToken {
  ulong transactionFingerprint;
  ulong substepFingerprint;
  ulong physicsStateFingerprint;
  ulong acceptedTimestampMicroseconds;
  ulong physicsGeneration;
  uint environmentIdentifier;
  uint flags;
  ulong reserved;
  ulong tokenFingerprint;
};

struct NBNumanXFastPrepareStatus {
  uint abiVersion;
  uint structBytes;
  uint status;
  uint environment;
  uint controlStep;
  uint substepIndex;
  uint physicsSubstepCount;
  uint reserved0;
  ulong fastProgramFingerprint;
  ulong transactionFingerprint;
  ulong substepFingerprint;
  ulong expectedPhysicsGeneration;
  ulong shadowGeneration;
  ulong acceptedTimestampMicroseconds;
  ulong reserved1[5];
  ulong gateFingerprint;
};

struct NBAcceptedPhysicsGateResult {
  uint version;
  uint status;
  ulong expectedTransactionFingerprint;
  ulong observedTransactionFingerprint;
  ulong expectedSubstepFingerprint;
  ulong observedSubstepFingerprint;
  ulong computedTokenFingerprint;
  ulong observedTokenFingerprint;
  ulong reserved;
  NBAcceptedPhysicsStateToken acceptedToken;
};

struct NBAgentMemoryJournalHeader {
  uint formatVersion;
  atomic_uint entryCount;
  uint entryCapacity;
  atomic_uint status;
  ulong baseGeneration;
  ulong shadowGeneration;
  ulong memoryByteCount;
  ulong reserved;
};

struct NBAgentMemoryMutation {
  ulong destinationByteOffset;
  ulong shadowGeneration;
  uint payload[4];
  uint byteCount;
  uint section;
  uint sequence;
  uint flags;
  ulong recordIdentifier;
  ulong reserved;
};

struct NBNumanXFastStateSourceGPU {
  ulong gpuAddress;
  ulong byteCount;
  ulong semanticIdentifier;
  ulong reserved;
};

struct NBNumanXBrainPrepareDispatchGPU {
  uint abiVersion;
  uint environment;
  uint stepIndex;
  uint substepIndex;
  uint transactionSlot;
  uint physicsSubstepCount;
  uint fastSourceCount;
  uint journalFormatVersion;
  uint journalEntryCapacity;
  uint rootDecision;
  uint controlStep;
  uint hashChunkByteCount;
  ulong programFingerprint;
  ulong transactionFingerprint;
  ulong linearizationEpoch;
  ulong slotGeneration;
  ulong brainProgramFingerprint;
  ulong hotByteCount;
  ulong journalByteCount;
  ulong memoryByteCount;
  ulong baseGeneration;
  ulong shadowGeneration;
  ulong fastStateTotalByteCount;
  ulong maximumHashByteCount;
  ulong totalHashByteCount;
  ulong hashChunkCount;
  ulong fastProgramFingerprint;
};

struct NBNumanXHashReduceDispatchGPU {
  uint abiVersion;
  uint level;
  uint inputCount;
  uint outputCount;
  uint fanout;
  uint reserved0;
  uint reserved1;
  uint reserved2;
};

struct NBNumanXHumanMatterBrainCommitWitness {
  uint magic;
  uint abiVersion;
  uint structBytes;
  uint status;
  uint decision;
  uint environment;
  uint stepIndex;
  uint substepIndex;
  uint transactionSlot;
  uint physicsSubstepCount;
  uint controlStep;
  uint reserved0;
  ulong programFingerprint;
  ulong transactionFingerprint;
  ulong linearizationEpoch;
  ulong slotGeneration;
  ulong physicsTokenFingerprint;
  ulong brainProgramFingerprint;
  ulong brainShadowStateFingerprint;
  ulong witnessFingerprint;
  ulong reserved1[2];
};

struct NBNumanXHumanMatterProposal {
  uint abiVersion;
  uint status;
  uint decision;
  uint code;
  ulong programFingerprint;
  ulong transactionFingerprint;
  ulong linearizationEpoch;
  ulong slotGeneration;
  ulong physicsTokenFingerprint;
  ulong brainProgramFingerprint;
  ulong brainShadowStateFingerprint;
  ulong brainWitnessFingerprint;
  ulong candidatePublicationFingerprint;
  ulong humanIOIdentityFingerprint;
  uint environment;
  uint stepIndex;
  uint substepIndex;
  uint transactionSlot;
  uint physicsSubstepCount;
  uint controlStep;
  ulong proposalFingerprint;
};

struct NBNumanXHumanMatterBrainCommitPreflight {
  uint abiVersion;
  uint structBytes;
  uint status;
  uint environment;
  uint controlStep;
  uint substepIndex;
  uint physicsSubstepCount;
  uint transactionSlot;
  ulong ownerProgramFingerprint;
  ulong transactionFingerprint;
  ulong linearizationEpoch;
  ulong slotGeneration;
  ulong substepFingerprint;
  ulong physicsTokenFingerprint;
  ulong fastTargetGeneration;
  ulong cognitiveTargetGeneration;
  ulong jointReceiptFingerprint;
  ulong fastProgramFingerprint;
  ulong brainProgramFingerprint;
  ulong preflightFingerprint;
};

struct NBNumanXHumanMatterBrainAck {
  uint abiVersion;
  uint status;
  uint decision;
  uint code;
  ulong programFingerprint;
  ulong transactionFingerprint;
  ulong linearizationEpoch;
  ulong slotGeneration;
  ulong physicsTokenFingerprint;
  ulong proposalFingerprint;
  ulong preflightFingerprint;
  ulong fastGateFingerprint;
  ulong brainWitnessFingerprint;
  ulong brainProgramFingerprint;
  uint environment;
  uint stepIndex;
  uint substepIndex;
  uint transactionSlot;
  uint physicsSubstepCount;
  uint controlStep;
  ulong ackFingerprint;
};

struct NBNumanXHumanMatterAppliedOutcome {
  uint abiVersion;
  uint status;
  uint decision;
  uint code;
  ulong programFingerprint;
  ulong transactionFingerprint;
  ulong linearizationEpoch;
  ulong slotGeneration;
  ulong physicsTokenFingerprint;
  ulong proposalFingerprint;
  ulong ackFingerprint;
  ulong preflightFingerprint;
  ulong fastGateFingerprint;
  ulong matterApplyFingerprint;
  uint environment;
  uint stepIndex;
  uint substepIndex;
  uint transactionSlot;
  uint physicsSubstepCount;
  uint controlStep;
  ulong appliedFingerprint;
};

struct NBNumanXBrainAckDispatchGPU {
  uint abiVersion;
  uint environment;
  uint stepIndex;
  uint substepIndex;
  uint transactionSlot;
  uint physicsSubstepCount;
  uint controlStep;
  uint reserved0;
  ulong ownerProgramFingerprint;
  ulong transactionFingerprint;
  ulong linearizationEpoch;
  ulong slotGeneration;
  ulong brainProgramFingerprint;
  ulong fastProgramFingerprint;
  ulong expectedCandidatePublicationFingerprint;
  ulong expectedHumanIOIdentityFingerprint;
};

struct NBNumanXAppliedValidationDispatchGPU {
  uint abiVersion;
  uint environment;
  uint stepIndex;
  uint substepIndex;
  uint transactionSlot;
  uint physicsSubstepCount;
  uint controlStep;
  uint commandDisposition;
  uint reserved0;
  uint reserved1;
  uint reserved2;
  uint reserved3;
  ulong ownerProgramFingerprint;
  ulong transactionFingerprint;
  ulong linearizationEpoch;
  ulong slotGeneration;
  ulong brainProgramFingerprint;
  ulong fastProgramFingerprint;
};

struct NBNumanXHumanMatterAppliedValidationResult {
  uint abiVersion;
  uint structBytes;
  uint status;
  uint code;
  uint decision;
  uint environment;
  uint stepIndex;
  uint substepIndex;
  uint transactionSlot;
  uint physicsSubstepCount;
  uint controlStep;
  uint tokenValid;
  ulong ownerProgramFingerprint;
  ulong transactionFingerprint;
  ulong linearizationEpoch;
  ulong slotGeneration;
  ulong physicsTokenFingerprint;
  ulong brainProgramFingerprint;
  ulong brainShadowStateFingerprint;
  ulong brainWitnessFingerprint;
  ulong proposalFingerprint;
  ulong preflightFingerprint;
  ulong fastGateFingerprint;
  ulong ackFingerprint;
  ulong matterApplyFingerprint;
  ulong appliedFingerprint;
  ulong fastProgramFingerprint;
  ulong fastTargetGeneration;
  ulong cognitiveTargetGeneration;
  ulong jointCommitFingerprint;
  ulong substepFingerprint;
  ulong appliedCommandDisposition;
  ulong reserved0[5];
  ulong resultFingerprint;
};

static_assert(sizeof(NBAcceptedPhysicsStateToken) == 64);
static_assert(sizeof(NBNumanXFastPrepareStatus) == 128);
static_assert(sizeof(NBAcceptedPhysicsGateResult) == 128);
static_assert(sizeof(NBAgentMemoryJournalHeader) == 48);
static_assert(sizeof(NBAgentMemoryMutation) == 64);
static_assert(sizeof(NBNumanXFastStateSourceGPU) == 32);
static_assert(sizeof(NBNumanXBrainPrepareDispatchGPU) == 168);
static_assert(sizeof(NBNumanXHashReduceDispatchGPU) == 32);
static_assert(sizeof(NBNumanXHumanMatterBrainCommitWitness) == 128);
static_assert(sizeof(NBNumanXHumanMatterProposal) == 128);
static_assert(sizeof(NBNumanXHumanMatterBrainCommitPreflight) == 128);
static_assert(sizeof(NBNumanXHumanMatterBrainAck) == 128);
static_assert(sizeof(NBNumanXHumanMatterAppliedOutcome) == 128);
static_assert(sizeof(NBNumanXBrainAckDispatchGPU) == 96);
static_assert(sizeof(NBNumanXAppliedValidationDispatchGPU) == 96);
static_assert(sizeof(NBNumanXHumanMatterAppliedValidationResult) == 256);

inline ulong nb_fnv_byte(ulong hash, uint value) {
  return (hash ^ ulong(value & 0xffu)) * NB_FNV_PRIME;
}

inline ulong nb_fnv_u32(ulong hash, uint value) {
  for (uint shift = 0u; shift < 32u; shift += 8u) {
    hash = nb_fnv_byte(hash, value >> shift);
  }
  return hash;
}

inline ulong nb_fnv_u64(ulong hash, ulong value) {
  for (uint shift = 0u; shift < 64u; shift += 8u) {
    hash = nb_fnv_byte(hash, uint(value >> shift));
  }
  return hash;
}

inline ulong nb_nonzero_fingerprint(ulong hash) {
  return hash == 0ul ? NB_FNV_OFFSET : hash;
}

inline ulong nb_accepted_token_fingerprint(
  thread const NBAcceptedPhysicsStateToken &token)
{
  ulong hash = NB_FNV_OFFSET;
  hash = nb_fnv_u32(hash, NB_JOINT_TRANSACTION_VERSION);
  hash = nb_fnv_u64(hash, token.transactionFingerprint);
  hash = nb_fnv_u64(hash, token.substepFingerprint);
  hash = nb_fnv_u64(hash, token.physicsStateFingerprint);
  hash = nb_fnv_u64(hash, token.acceptedTimestampMicroseconds);
  hash = nb_fnv_u64(hash, token.physicsGeneration);
  hash = nb_fnv_u32(hash, token.environmentIdentifier);
  hash = nb_fnv_u32(hash, token.flags);
  hash = nb_fnv_u64(hash, token.reserved);
  return hash;
}

inline ulong nb_fast_prepare_gate_fingerprint(
  thread const NBNumanXFastPrepareStatus &gate)
{
  ulong hash = NB_FNV_OFFSET;
  hash = nb_fnv_u32(hash, gate.abiVersion);
  hash = nb_fnv_u32(hash, gate.structBytes);
  hash = nb_fnv_u32(hash, gate.status);
  hash = nb_fnv_u32(hash, gate.environment);
  hash = nb_fnv_u32(hash, gate.controlStep);
  hash = nb_fnv_u32(hash, gate.substepIndex);
  hash = nb_fnv_u32(hash, gate.physicsSubstepCount);
  hash = nb_fnv_u32(hash, gate.reserved0);
  hash = nb_fnv_u64(hash, gate.fastProgramFingerprint);
  hash = nb_fnv_u64(hash, gate.transactionFingerprint);
  hash = nb_fnv_u64(hash, gate.substepFingerprint);
  hash = nb_fnv_u64(hash, gate.expectedPhysicsGeneration);
  hash = nb_fnv_u64(hash, gate.shadowGeneration);
  hash = nb_fnv_u64(hash, gate.acceptedTimestampMicroseconds);
  for (uint index = 0u; index < 5u; ++index)
    hash = nb_fnv_u64(hash, gate.reserved1[index]);
  return nb_nonzero_fingerprint(hash);
}

inline ulong nb_witness_fingerprint(
  thread const NBNumanXHumanMatterBrainCommitWitness &witness)
{
  ulong hash = NB_FNV_OFFSET;
  hash = nb_fnv_u32(hash, witness.magic);
  hash = nb_fnv_u32(hash, witness.abiVersion);
  hash = nb_fnv_u32(hash, witness.structBytes);
  hash = nb_fnv_u32(hash, witness.status);
  hash = nb_fnv_u32(hash, witness.decision);
  hash = nb_fnv_u32(hash, witness.environment);
  hash = nb_fnv_u32(hash, witness.stepIndex);
  hash = nb_fnv_u32(hash, witness.substepIndex);
  hash = nb_fnv_u32(hash, witness.transactionSlot);
  hash = nb_fnv_u32(hash, witness.physicsSubstepCount);
  hash = nb_fnv_u32(hash, witness.controlStep);
  hash = nb_fnv_u32(hash, witness.reserved0);
  hash = nb_fnv_u64(hash, witness.programFingerprint);
  hash = nb_fnv_u64(hash, witness.transactionFingerprint);
  hash = nb_fnv_u64(hash, witness.linearizationEpoch);
  hash = nb_fnv_u64(hash, witness.slotGeneration);
  hash = nb_fnv_u64(hash, witness.physicsTokenFingerprint);
  hash = nb_fnv_u64(hash, witness.brainProgramFingerprint);
  hash = nb_fnv_u64(hash, witness.brainShadowStateFingerprint);
  for (uint index = 0u; index < 2u; ++index) {
    hash = nb_fnv_u64(hash, witness.reserved1[index]);
  }
  return nb_nonzero_fingerprint(hash);
}

inline ulong nb_proposal_fingerprint(
  thread const NBNumanXHumanMatterProposal &value)
{
  ulong hash = NB_FNV_OFFSET;
  hash = nb_fnv_u32(hash, value.abiVersion);
  hash = nb_fnv_u32(hash, value.status);
  hash = nb_fnv_u32(hash, value.decision);
  hash = nb_fnv_u32(hash, value.code);
  hash = nb_fnv_u64(hash, value.programFingerprint);
  hash = nb_fnv_u64(hash, value.transactionFingerprint);
  hash = nb_fnv_u64(hash, value.linearizationEpoch);
  hash = nb_fnv_u64(hash, value.slotGeneration);
  hash = nb_fnv_u64(hash, value.physicsTokenFingerprint);
  hash = nb_fnv_u64(hash, value.brainProgramFingerprint);
  hash = nb_fnv_u64(hash, value.brainShadowStateFingerprint);
  hash = nb_fnv_u64(hash, value.brainWitnessFingerprint);
  hash = nb_fnv_u64(hash, value.candidatePublicationFingerprint);
  hash = nb_fnv_u64(hash, value.humanIOIdentityFingerprint);
  hash = nb_fnv_u32(hash, value.environment);
  hash = nb_fnv_u32(hash, value.stepIndex);
  hash = nb_fnv_u32(hash, value.substepIndex);
  hash = nb_fnv_u32(hash, value.transactionSlot);
  hash = nb_fnv_u32(hash, value.physicsSubstepCount);
  hash = nb_fnv_u32(hash, value.controlStep);
  return nb_nonzero_fingerprint(hash);
}

inline ulong nb_preflight_fingerprint(
  thread const NBNumanXHumanMatterBrainCommitPreflight &value)
{
  ulong hash = NB_FNV_OFFSET;
  hash = nb_fnv_u32(hash, value.abiVersion);
  hash = nb_fnv_u32(hash, value.structBytes);
  hash = nb_fnv_u32(hash, value.status);
  hash = nb_fnv_u32(hash, value.environment);
  hash = nb_fnv_u32(hash, value.controlStep);
  hash = nb_fnv_u32(hash, value.substepIndex);
  hash = nb_fnv_u32(hash, value.physicsSubstepCount);
  hash = nb_fnv_u32(hash, value.transactionSlot);
  hash = nb_fnv_u64(hash, value.ownerProgramFingerprint);
  hash = nb_fnv_u64(hash, value.transactionFingerprint);
  hash = nb_fnv_u64(hash, value.linearizationEpoch);
  hash = nb_fnv_u64(hash, value.slotGeneration);
  hash = nb_fnv_u64(hash, value.substepFingerprint);
  hash = nb_fnv_u64(hash, value.physicsTokenFingerprint);
  hash = nb_fnv_u64(hash, value.fastTargetGeneration);
  hash = nb_fnv_u64(hash, value.cognitiveTargetGeneration);
  hash = nb_fnv_u64(hash, value.jointReceiptFingerprint);
  hash = nb_fnv_u64(hash, value.fastProgramFingerprint);
  hash = nb_fnv_u64(hash, value.brainProgramFingerprint);
  return nb_nonzero_fingerprint(hash);
}

inline ulong nb_ack_fingerprint(
  thread const NBNumanXHumanMatterBrainAck &value)
{
  ulong hash = NB_FNV_OFFSET;
  hash = nb_fnv_u32(hash, value.abiVersion);
  hash = nb_fnv_u32(hash, value.status);
  hash = nb_fnv_u32(hash, value.decision);
  hash = nb_fnv_u32(hash, value.code);
  hash = nb_fnv_u64(hash, value.programFingerprint);
  hash = nb_fnv_u64(hash, value.transactionFingerprint);
  hash = nb_fnv_u64(hash, value.linearizationEpoch);
  hash = nb_fnv_u64(hash, value.slotGeneration);
  hash = nb_fnv_u64(hash, value.physicsTokenFingerprint);
  hash = nb_fnv_u64(hash, value.proposalFingerprint);
  hash = nb_fnv_u64(hash, value.preflightFingerprint);
  hash = nb_fnv_u64(hash, value.fastGateFingerprint);
  hash = nb_fnv_u64(hash, value.brainWitnessFingerprint);
  hash = nb_fnv_u64(hash, value.brainProgramFingerprint);
  hash = nb_fnv_u32(hash, value.environment);
  hash = nb_fnv_u32(hash, value.stepIndex);
  hash = nb_fnv_u32(hash, value.substepIndex);
  hash = nb_fnv_u32(hash, value.transactionSlot);
  hash = nb_fnv_u32(hash, value.physicsSubstepCount);
  hash = nb_fnv_u32(hash, value.controlStep);
  return nb_nonzero_fingerprint(hash);
}

inline ulong nb_applied_fingerprint(
  thread const NBNumanXHumanMatterAppliedOutcome &value)
{
  ulong hash = NB_FNV_OFFSET;
  hash = nb_fnv_u32(hash, value.abiVersion);
  hash = nb_fnv_u32(hash, value.status);
  hash = nb_fnv_u32(hash, value.decision);
  hash = nb_fnv_u32(hash, value.code);
  hash = nb_fnv_u64(hash, value.programFingerprint);
  hash = nb_fnv_u64(hash, value.transactionFingerprint);
  hash = nb_fnv_u64(hash, value.linearizationEpoch);
  hash = nb_fnv_u64(hash, value.slotGeneration);
  hash = nb_fnv_u64(hash, value.physicsTokenFingerprint);
  hash = nb_fnv_u64(hash, value.proposalFingerprint);
  hash = nb_fnv_u64(hash, value.ackFingerprint);
  hash = nb_fnv_u64(hash, value.preflightFingerprint);
  hash = nb_fnv_u64(hash, value.fastGateFingerprint);
  hash = nb_fnv_u64(hash, value.matterApplyFingerprint);
  hash = nb_fnv_u32(hash, value.environment);
  hash = nb_fnv_u32(hash, value.stepIndex);
  hash = nb_fnv_u32(hash, value.substepIndex);
  hash = nb_fnv_u32(hash, value.transactionSlot);
  hash = nb_fnv_u32(hash, value.physicsSubstepCount);
  hash = nb_fnv_u32(hash, value.controlStep);
  return nb_nonzero_fingerprint(hash);
}

inline ulong nb_applied_validation_fingerprint(
  thread const NBNumanXHumanMatterAppliedValidationResult &value)
{
  ulong hash = NB_FNV_OFFSET;
  hash = nb_fnv_u32(hash, value.abiVersion);
  hash = nb_fnv_u32(hash, value.structBytes);
  hash = nb_fnv_u32(hash, value.status);
  hash = nb_fnv_u32(hash, value.code);
  hash = nb_fnv_u32(hash, value.decision);
  hash = nb_fnv_u32(hash, value.environment);
  hash = nb_fnv_u32(hash, value.stepIndex);
  hash = nb_fnv_u32(hash, value.substepIndex);
  hash = nb_fnv_u32(hash, value.transactionSlot);
  hash = nb_fnv_u32(hash, value.physicsSubstepCount);
  hash = nb_fnv_u32(hash, value.controlStep);
  hash = nb_fnv_u32(hash, value.tokenValid);
  hash = nb_fnv_u64(hash, value.ownerProgramFingerprint);
  hash = nb_fnv_u64(hash, value.transactionFingerprint);
  hash = nb_fnv_u64(hash, value.linearizationEpoch);
  hash = nb_fnv_u64(hash, value.slotGeneration);
  hash = nb_fnv_u64(hash, value.physicsTokenFingerprint);
  hash = nb_fnv_u64(hash, value.brainProgramFingerprint);
  hash = nb_fnv_u64(hash, value.brainShadowStateFingerprint);
  hash = nb_fnv_u64(hash, value.brainWitnessFingerprint);
  hash = nb_fnv_u64(hash, value.proposalFingerprint);
  hash = nb_fnv_u64(hash, value.preflightFingerprint);
  hash = nb_fnv_u64(hash, value.fastGateFingerprint);
  hash = nb_fnv_u64(hash, value.ackFingerprint);
  hash = nb_fnv_u64(hash, value.matterApplyFingerprint);
  hash = nb_fnv_u64(hash, value.appliedFingerprint);
  hash = nb_fnv_u64(hash, value.fastProgramFingerprint);
  hash = nb_fnv_u64(hash, value.fastTargetGeneration);
  hash = nb_fnv_u64(hash, value.cognitiveTargetGeneration);
  hash = nb_fnv_u64(hash, value.jointCommitFingerprint);
  hash = nb_fnv_u64(hash, value.substepFingerprint);
  hash = nb_fnv_u64(hash, value.appliedCommandDisposition);
  for (uint index = 0u; index < 5u; ++index)
    hash = nb_fnv_u64(hash, value.reserved0[index]);
  return nb_nonzero_fingerprint(hash);
}

inline bool nb_bytes_zero(
  device const uchar *bytes,
  ulong byteCount)
{
  for (ulong index = 0ul; index < byteCount; ++index) {
    if (bytes[index] != 0u) return false;
  }
  return true;
}

kernel void hash_numanx_human_matter_brain_chunks(
  device const uchar *hotState [[buffer(0)]],
  device const uchar *journalBytes [[buffer(1)]],
  device const NBNumanXFastStateSourceGPU *fastSources [[buffer(2)]],
  constant NBNumanXBrainPrepareDispatchGPU &dispatch [[buffer(3)]],
  device ulong *chunkHashes [[buffer(4)]],
  uint gid [[thread_position_in_grid]])
{
  if (dispatch.abiVersion != NB_HM_ABI_VERSION
      || dispatch.hashChunkByteCount != NB_HM_HASH_CHUNK_BYTES
      || dispatch.hashChunkCount == 0ul
      || dispatch.hashChunkCount > 1048576ul
      || ulong(gid) >= dispatch.hashChunkCount) return;

  const ulong chunkStart = ulong(gid) * ulong(NB_HM_HASH_CHUNK_BYTES);
  if (chunkStart >= dispatch.totalHashByteCount) return;
  const ulong chunkByteCount = min(
    ulong(NB_HM_HASH_CHUNK_BYTES),
    dispatch.totalHashByteCount - chunkStart);
  ulong hash = NB_FNV_OFFSET;
  hash = nb_fnv_u32(hash, NB_HM_HASH_CHUNK_DOMAIN);
  hash = nb_fnv_u64(hash, ulong(gid));
  hash = nb_fnv_u32(hash, uint(chunkByteCount));

  ulong logicalOffset = chunkStart;
  ulong remaining = chunkByteCount;
  if (remaining != 0ul && logicalOffset < dispatch.hotByteCount) {
    const ulong count = min(remaining, dispatch.hotByteCount - logicalOffset);
    for (ulong index = 0ul; index < count; ++index)
      hash = nb_fnv_byte(hash, uint(hotState[logicalOffset + index]));
    logicalOffset += count;
    remaining -= count;
  }
  const ulong journalStart = dispatch.hotByteCount;
  const ulong journalEnd = journalStart + dispatch.journalByteCount;
  if (remaining != 0ul && logicalOffset < journalEnd) {
    const ulong offset = logicalOffset - journalStart;
    const ulong count = min(remaining, dispatch.journalByteCount - offset);
    for (ulong index = 0ul; index < count; ++index)
      hash = nb_fnv_byte(hash, uint(journalBytes[offset + index]));
    logicalOffset += count;
    remaining -= count;
  }
  ulong fastOffset = logicalOffset - journalEnd;
  for (uint sourceIndex = 0u;
       remaining != 0ul && sourceIndex < dispatch.fastSourceCount;
       ++sourceIndex) {
    const NBNumanXFastStateSourceGPU source = fastSources[sourceIndex];
    if (fastOffset >= source.byteCount) {
      fastOffset -= source.byteCount;
      continue;
    }
    const ulong count = min(remaining, source.byteCount - fastOffset);
    device const uchar *sourceBytes =
      reinterpret_cast<device const uchar *>(source.gpuAddress);
    for (ulong index = 0ul; index < count; ++index)
      hash = nb_fnv_byte(hash, uint(sourceBytes[fastOffset + index]));
    remaining -= count;
    fastOffset = 0ul;
  }
  chunkHashes[gid] = remaining == 0ul ? hash : 0ul;
}

kernel void reduce_numanx_human_matter_brain_hashes(
  device const ulong *inputHashes [[buffer(0)]],
  device ulong *outputHashes [[buffer(1)]],
  constant NBNumanXHashReduceDispatchGPU &dispatch [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
  if (dispatch.abiVersion != NB_HM_ABI_VERSION
      || dispatch.fanout != NB_HM_HASH_TREE_FANOUT
      || dispatch.inputCount == 0u || dispatch.outputCount == 0u
      || dispatch.outputCount !=
        (dispatch.inputCount + dispatch.fanout - 1u) / dispatch.fanout
      || dispatch.reserved0 != 0u || dispatch.reserved1 != 0u
      || dispatch.reserved2 != 0u || gid >= dispatch.outputCount) return;
  const uint first = gid * dispatch.fanout;
  const uint childCount = min(dispatch.fanout, dispatch.inputCount - first);
  ulong hash = NB_FNV_OFFSET;
  hash = nb_fnv_u32(hash, NB_HM_HASH_REDUCE_DOMAIN);
  hash = nb_fnv_u32(hash, dispatch.level);
  hash = nb_fnv_u32(hash, gid);
  hash = nb_fnv_u32(hash, childCount);
  for (uint child = 0u; child < childCount; ++child)
    hash = nb_fnv_u64(hash, inputHashes[first + child]);
  outputHashes[gid] = hash;
}

kernel void prepare_numanx_human_matter_brain_witness(
  device const uchar *journalBytes [[buffer(0)]],
  device const NBNumanXFastStateSourceGPU *fastSources [[buffer(1)]],
  device const NBAcceptedPhysicsGateResult *startGate [[buffer(2)]],
  constant NBNumanXBrainPrepareDispatchGPU &dispatch [[buffer(3)]],
  device const ulong *rootHash [[buffer(4)]],
  device const NBNumanXFastPrepareStatus *fastPrepareStatus [[buffer(5)]],
  device NBNumanXHumanMatterBrainCommitWitness *output [[buffer(6)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u) return;

  NBNumanXHumanMatterBrainCommitWitness witness = {};
  witness.magic = NB_HM_WITNESS_MAGIC;
  witness.abiVersion = NB_HM_WITNESS_ABI_VERSION;
  witness.structBytes = NB_HM_WITNESS_BYTES;
  witness.status = NB_HM_PREPARE_FAILED;
  witness.decision = NB_HM_ROOT_REJECT;
  witness.environment = dispatch.environment;
  witness.stepIndex = dispatch.stepIndex;
  witness.substepIndex = dispatch.substepIndex;
  witness.transactionSlot = dispatch.transactionSlot;
  witness.physicsSubstepCount = dispatch.physicsSubstepCount;
  witness.controlStep = dispatch.controlStep;
  witness.programFingerprint = dispatch.programFingerprint;
  witness.transactionFingerprint = dispatch.transactionFingerprint;
  witness.linearizationEpoch = dispatch.linearizationEpoch;
  witness.slotGeneration = dispatch.slotGeneration;
  witness.brainProgramFingerprint = dispatch.brainProgramFingerprint;

  device const NBAgentMemoryJournalHeader *journal =
    reinterpret_cast<device const NBAgentMemoryJournalHeader *>(journalBytes);
  const uint journalEntryCount = atomic_load_explicit(
    &journal->entryCount, memory_order_relaxed);
  const uint journalStatus = atomic_load_explicit(
    &journal->status, memory_order_relaxed);
  const NBAcceptedPhysicsGateResult gate = startGate[0];
  const NBAcceptedPhysicsStateToken token = gate.acceptedToken;
  const NBNumanXFastPrepareStatus fastStatus = fastPrepareStatus[0];
  const ulong computedTokenFingerprint = nb_accepted_token_fingerprint(token);

  ulong recomputedFastBytes = 0ul;
  bool sourcesValid = true;
  ulong previousSemanticIdentifier = 0ul;
  for (uint sourceIndex = 0u;
       sourceIndex < dispatch.fastSourceCount; ++sourceIndex) {
    const NBNumanXFastStateSourceGPU source = fastSources[sourceIndex];
    const ulong next = recomputedFastBytes + source.byteCount;
    sourcesValid = sourcesValid && source.gpuAddress != 0ul
      && source.byteCount != 0ul && source.semanticIdentifier != 0ul
      && source.semanticIdentifier > previousSemanticIdentifier
      && source.reserved == 0ul && next >= recomputedFastBytes;
    previousSemanticIdentifier = source.semanticIdentifier;
    recomputedFastBytes = next;
  }
  const ulong hotAndJournal = dispatch.hotByteCount + dispatch.journalByteCount;
  const ulong totalHashBytes = hotAndJournal + recomputedFastBytes;
  const bool totalDidNotWrap = hotAndJournal >= dispatch.hotByteCount
    && totalHashBytes >= hotAndJournal;
  const bool boundedTotal = totalDidNotWrap && totalHashBytes != 0ul
    && totalHashBytes <= NB_HM_MAXIMUM_HASH_BYTES;
  const ulong expectedChunkCount = boundedTotal
    ? (totalHashBytes + ulong(NB_HM_HASH_CHUNK_BYTES) - 1ul) /
      ulong(NB_HM_HASH_CHUNK_BYTES)
    : 0ul;
  const bool dispatchValid =
    dispatch.abiVersion == NB_HM_ABI_VERSION
    && dispatch.environment == 0u && dispatch.stepIndex == 0u
    && dispatch.substepIndex == 0u
    && dispatch.physicsSubstepCount == NB_HM_PHYSICS_SUBSTEP_COUNT
    && (dispatch.rootDecision == NB_HM_ROOT_ACCEPT
      || dispatch.rootDecision == NB_HM_ROOT_REJECT)
    && dispatch.programFingerprint != 0ul
    && dispatch.transactionFingerprint != 0ul
    && dispatch.linearizationEpoch != 0ul
    && dispatch.slotGeneration != 0ul
    && dispatch.brainProgramFingerprint != 0ul
    && dispatch.fastProgramFingerprint != 0ul
    && dispatch.hotByteCount != 0ul
    && dispatch.journalByteCount >= sizeof(NBAgentMemoryJournalHeader)
    && dispatch.memoryByteCount != 0ul
    && dispatch.fastSourceCount <= 32u
    && dispatch.fastStateTotalByteCount == recomputedFastBytes
    && dispatch.maximumHashByteCount == NB_HM_MAXIMUM_HASH_BYTES
    && dispatch.hashChunkByteCount == NB_HM_HASH_CHUNK_BYTES
    && boundedTotal && totalHashBytes <= dispatch.maximumHashByteCount
    && dispatch.totalHashByteCount == totalHashBytes
    && dispatch.hashChunkCount == expectedChunkCount
    && dispatch.hashChunkCount != 0ul
    && dispatch.hashChunkCount <= 1048576ul;
  const bool gateValid = gate.version == NB_ACCEPTED_PHYSICS_GATE_VERSION
    && gate.status == NB_ACCEPTED_PHYSICS_GATE_VALID
    && gate.expectedTransactionFingerprint == dispatch.transactionFingerprint
    && gate.observedTransactionFingerprint == dispatch.transactionFingerprint
    && gate.expectedSubstepFingerprint == token.substepFingerprint
    && gate.observedSubstepFingerprint == token.substepFingerprint
    && gate.computedTokenFingerprint != 0ul
    && gate.computedTokenFingerprint == gate.observedTokenFingerprint
    && gate.reserved == 0ul
    && token.transactionFingerprint == dispatch.transactionFingerprint
    && token.environmentIdentifier == 0u && token.flags == 0u
    && token.reserved == 0ul && token.physicsStateFingerprint != 0ul
    && token.tokenFingerprint != 0ul
    && token.tokenFingerprint == computedTokenFingerprint
    && token.tokenFingerprint == gate.computedTokenFingerprint;
  const bool fastStatusValid =
    fastStatus.abiVersion == NB_FAST_PREPARE_STATUS_ABI_VERSION
    && fastStatus.structBytes == NB_FAST_PREPARE_STATUS_BYTES
    && fastStatus.status == NB_FAST_PREPARE_SUCCESS
    && fastStatus.environment == dispatch.environment
    && fastStatus.controlStep == dispatch.controlStep
    && fastStatus.substepIndex == dispatch.substepIndex
    && fastStatus.physicsSubstepCount == dispatch.physicsSubstepCount
    && fastStatus.reserved0 == 0u
    && fastStatus.fastProgramFingerprint == dispatch.fastProgramFingerprint
    && fastStatus.transactionFingerprint == dispatch.transactionFingerprint
    && fastStatus.substepFingerprint == token.substepFingerprint
    && fastStatus.expectedPhysicsGeneration == token.physicsGeneration
    && fastStatus.shadowGeneration == dispatch.shadowGeneration
    && fastStatus.acceptedTimestampMicroseconds
      == token.acceptedTimestampMicroseconds
    && fastStatus.reserved1[0] == 0ul && fastStatus.reserved1[1] == 0ul
    && fastStatus.reserved1[2] == 0ul && fastStatus.reserved1[3] == 0ul
    && fastStatus.reserved1[4] == 0ul
    && fastStatus.gateFingerprint != 0ul
    && fastStatus.gateFingerprint
      == nb_fast_prepare_gate_fingerprint(fastStatus);
  device const NBAgentMemoryMutation *journalEntries =
    reinterpret_cast<device const NBAgentMemoryMutation *>(journal + 1);
  bool journalEntriesValid =
    journalEntryCount <= dispatch.journalEntryCapacity;
  const uint boundedJournalEntryCount = min(
    journalEntryCount, dispatch.journalEntryCapacity);
  for (uint entryIndex = 0u;
       entryIndex < boundedJournalEntryCount; ++entryIndex) {
    const NBAgentMemoryMutation mutation = journalEntries[entryIndex];
    const ulong mutationEnd = mutation.destinationByteOffset
      + ulong(mutation.byteCount);
    journalEntriesValid = journalEntriesValid
      && mutation.shadowGeneration == dispatch.shadowGeneration
      && mutation.byteCount != 0u
      && mutation.byteCount <= sizeof(mutation.payload)
      && mutationEnd >= mutation.destinationByteOffset
      && mutationEnd <= dispatch.memoryByteCount;
  }
  const bool journalValid =
    journal->formatVersion == dispatch.journalFormatVersion
    && journal->formatVersion == NB_AGENT_ARENA_VERSION
    && journal->entryCapacity == dispatch.journalEntryCapacity
    && journalEntryCount <= journal->entryCapacity
    && journalStatus == NB_AGENT_JOURNAL_STATUS_VALID
    && journal->baseGeneration == dispatch.baseGeneration
    && journal->shadowGeneration == dispatch.shadowGeneration
    && journal->memoryByteCount == dispatch.memoryByteCount
    && journal->reserved == 0ul && journalEntriesValid;

  if (dispatchValid && gateValid && fastStatusValid
      && journalValid && sourcesValid) {
    ulong stateHash = NB_FNV_OFFSET;
    stateHash = nb_fnv_u32(stateHash, NB_HM_HASH_FINAL_DOMAIN);
    stateHash = nb_fnv_u64(stateHash, dispatch.hotByteCount);
    stateHash = nb_fnv_u64(stateHash, dispatch.journalByteCount);
    stateHash = nb_fnv_u32(stateHash, dispatch.fastSourceCount);
    for (uint sourceIndex = 0u;
         sourceIndex < dispatch.fastSourceCount; ++sourceIndex) {
      const NBNumanXFastStateSourceGPU source = fastSources[sourceIndex];
      stateHash = nb_fnv_u64(stateHash, source.semanticIdentifier);
      stateHash = nb_fnv_u64(stateHash, source.byteCount);
    }
    stateHash = nb_fnv_u64(stateHash, dispatch.totalHashByteCount);
    stateHash = nb_fnv_u32(stateHash, dispatch.hashChunkByteCount);
    stateHash = nb_fnv_u64(stateHash, dispatch.hashChunkCount);
    stateHash = nb_fnv_u64(stateHash, dispatch.fastProgramFingerprint);
    stateHash = nb_fnv_u64(stateHash, fastStatus.gateFingerprint);
    stateHash = nb_fnv_u64(stateHash, rootHash[0]);
    witness.status = NB_HM_PREPARE_COMPLETE;
    witness.decision = dispatch.rootDecision;
    witness.physicsTokenFingerprint = token.tokenFingerprint;
    witness.brainShadowStateFingerprint = nb_nonzero_fingerprint(stateHash);
  }
  witness.witnessFingerprint = nb_witness_fingerprint(witness);
  output[0] = witness;
}

kernel void ack_numanx_human_matter_brain_commit(
  device const NBNumanXHumanMatterBrainCommitWitness *witnesses [[buffer(0)]],
  device const NBAcceptedPhysicsGateResult *startGate [[buffer(1)]],
  device const NBNumanXFastPrepareStatus *fastPrepareStatus [[buffer(2)]],
  device const NBNumanXHumanMatterProposal *proposals [[buffer(3)]],
  device const NBAcceptedPhysicsStateToken *proposedTokens [[buffer(4)]],
  device const NBNumanXHumanMatterBrainCommitPreflight *preflights [[buffer(5)]],
  constant NBNumanXBrainAckDispatchGPU &dispatch [[buffer(6)]],
  device NBNumanXHumanMatterBrainAck *output [[buffer(7)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u) return;
  const NBNumanXHumanMatterBrainCommitWitness witness = witnesses[0];
  const NBAcceptedPhysicsGateResult gate = startGate[0];
  const NBAcceptedPhysicsStateToken token = gate.acceptedToken;
  const NBNumanXFastPrepareStatus fast = fastPrepareStatus[0];
  const NBNumanXHumanMatterProposal proposal = proposals[0];
  const NBAcceptedPhysicsStateToken proposedToken = proposedTokens[0];
  const NBNumanXHumanMatterBrainCommitPreflight preflight = preflights[0];

  NBNumanXHumanMatterBrainAck ack = {};
  ack.abiVersion = NB_HM_BRAIN_ACK_ABI_VERSION;
  ack.status = NB_HM_BRAIN_ACK_INVALID;
  ack.decision = 0u;
  ack.code = NB_HM_BRAIN_ACK_INVALID_WITNESS;
  ack.programFingerprint = dispatch.ownerProgramFingerprint;
  ack.transactionFingerprint = dispatch.transactionFingerprint;
  ack.linearizationEpoch = dispatch.linearizationEpoch;
  ack.slotGeneration = dispatch.slotGeneration;
  ack.brainProgramFingerprint = dispatch.brainProgramFingerprint;
  ack.environment = dispatch.environment;
  ack.stepIndex = dispatch.stepIndex;
  ack.substepIndex = dispatch.substepIndex;
  ack.transactionSlot = dispatch.transactionSlot;
  ack.physicsSubstepCount = dispatch.physicsSubstepCount;
  ack.controlStep = dispatch.controlStep;

  const bool dispatchValid = dispatch.abiVersion == NB_HM_ABI_VERSION
    && dispatch.environment == 0u && dispatch.stepIndex == 0u
    && dispatch.substepIndex == 0u
    && dispatch.physicsSubstepCount == NB_HM_PHYSICS_SUBSTEP_COUNT
    && dispatch.ownerProgramFingerprint != 0ul
    && dispatch.transactionFingerprint != 0ul
    && dispatch.linearizationEpoch != 0ul
    && dispatch.slotGeneration != 0ul
    && dispatch.brainProgramFingerprint != 0ul
    && dispatch.fastProgramFingerprint != 0ul
    && dispatch.expectedCandidatePublicationFingerprint != 0ul
    && dispatch.expectedHumanIOIdentityFingerprint != 0ul
    && dispatch.reserved0 == 0u;
  const bool witnessValid = dispatchValid
    && witness.magic == NB_HM_WITNESS_MAGIC
    && witness.abiVersion == NB_HM_WITNESS_ABI_VERSION
    && witness.structBytes == NB_HM_WITNESS_BYTES
    && witness.status == NB_HM_PREPARE_COMPLETE
    && (witness.decision == NB_HM_ROOT_ACCEPT
      || witness.decision == NB_HM_ROOT_REJECT)
    && witness.environment == dispatch.environment
    && witness.stepIndex == dispatch.stepIndex
    && witness.substepIndex == dispatch.substepIndex
    && witness.transactionSlot == dispatch.transactionSlot
    && witness.physicsSubstepCount == dispatch.physicsSubstepCount
    && witness.controlStep == dispatch.controlStep
    && witness.reserved0 == 0u
    && witness.programFingerprint == dispatch.ownerProgramFingerprint
    && witness.transactionFingerprint == dispatch.transactionFingerprint
    && witness.linearizationEpoch == dispatch.linearizationEpoch
    && witness.slotGeneration == dispatch.slotGeneration
    && witness.physicsTokenFingerprint != 0ul
    && witness.brainProgramFingerprint == dispatch.brainProgramFingerprint
    && witness.brainShadowStateFingerprint != 0ul
    && witness.witnessFingerprint != 0ul
    && witness.reserved1[0] == 0ul && witness.reserved1[1] == 0ul
    && witness.witnessFingerprint == nb_witness_fingerprint(witness);
  const ulong computedTokenFingerprint = nb_accepted_token_fingerprint(token);
  const bool gateValid = witnessValid
    && gate.version == NB_ACCEPTED_PHYSICS_GATE_VERSION
    && gate.status == NB_ACCEPTED_PHYSICS_GATE_VALID
    && gate.expectedTransactionFingerprint == dispatch.transactionFingerprint
    && gate.observedTransactionFingerprint == dispatch.transactionFingerprint
    && gate.expectedSubstepFingerprint == token.substepFingerprint
    && gate.observedSubstepFingerprint == token.substepFingerprint
    && gate.computedTokenFingerprint == gate.observedTokenFingerprint
    && gate.computedTokenFingerprint == computedTokenFingerprint
    && gate.reserved == 0ul
    && token.transactionFingerprint == dispatch.transactionFingerprint
    && token.environmentIdentifier == 0u && token.flags == 0u
    && token.reserved == 0ul && token.physicsStateFingerprint != 0ul
    && token.tokenFingerprint == computedTokenFingerprint
    && token.tokenFingerprint == witness.physicsTokenFingerprint;
  const bool fastValid = gateValid
    && fast.abiVersion == NB_FAST_PREPARE_STATUS_ABI_VERSION
    && fast.structBytes == NB_FAST_PREPARE_STATUS_BYTES
    && fast.status == NB_FAST_PREPARE_SUCCESS
    && fast.environment == dispatch.environment
    && fast.controlStep == dispatch.controlStep
    && fast.substepIndex == dispatch.substepIndex
    && fast.physicsSubstepCount == dispatch.physicsSubstepCount
    && fast.reserved0 == 0u
    && fast.fastProgramFingerprint == dispatch.fastProgramFingerprint
    && fast.transactionFingerprint == dispatch.transactionFingerprint
    && fast.substepFingerprint == token.substepFingerprint
    && fast.expectedPhysicsGeneration == token.physicsGeneration
    && fast.acceptedTimestampMicroseconds == token.acceptedTimestampMicroseconds
    && fast.reserved1[0] == 0ul && fast.reserved1[1] == 0ul
    && fast.reserved1[2] == 0ul && fast.reserved1[3] == 0ul
    && fast.reserved1[4] == 0ul && fast.gateFingerprint != 0ul
    && fast.gateFingerprint == nb_fast_prepare_gate_fingerprint(fast);
  const uint independentRejectAppliedCode =
    nb_independent_reject_applied_code(proposal.code);
  const bool proposalStatusConsistent =
    (proposal.decision == NB_HM_ROOT_ACCEPT
      && proposal.code == NB_HM_PROPOSAL_SUCCESS
      && proposal.physicsTokenFingerprint != 0ul
      && proposal.brainProgramFingerprint != 0ul
      && proposal.brainShadowStateFingerprint != 0ul
      && proposal.brainWitnessFingerprint != 0ul)
    || (proposal.decision == NB_HM_ROOT_REJECT
      && independentRejectAppliedCode != NB_HM_INVALID_REJECT_CODE
      && proposal.physicsTokenFingerprint == 0ul
      && proposal.brainProgramFingerprint == 0ul
      && proposal.brainShadowStateFingerprint == 0ul
      && proposal.brainWitnessFingerprint == 0ul);
  const bool proposalValid = dispatchValid
    && proposal.abiVersion == NB_HM_ABI_VERSION
    && proposal.status == NB_HM_PROPOSAL_READY
    && proposalStatusConsistent
    && proposal.programFingerprint == dispatch.ownerProgramFingerprint
    && proposal.transactionFingerprint == dispatch.transactionFingerprint
    && proposal.linearizationEpoch == dispatch.linearizationEpoch
    && proposal.slotGeneration == dispatch.slotGeneration
    && proposal.environment == dispatch.environment
    && proposal.stepIndex == dispatch.stepIndex
    && proposal.substepIndex == dispatch.substepIndex
    && proposal.transactionSlot == dispatch.transactionSlot
    && proposal.physicsSubstepCount == dispatch.physicsSubstepCount
    && proposal.controlStep == dispatch.controlStep
    && proposal.candidatePublicationFingerprint
      == dispatch.expectedCandidatePublicationFingerprint
    && proposal.humanIOIdentityFingerprint
      == dispatch.expectedHumanIOIdentityFingerprint
    && proposal.proposalFingerprint != 0ul
    && proposal.proposalFingerprint == nb_proposal_fingerprint(proposal);
  const bool proposalAcceptProof = proposalValid
    && proposal.decision == NB_HM_ROOT_ACCEPT
    && witness.decision == NB_HM_ROOT_ACCEPT
    && proposal.physicsTokenFingerprint == witness.physicsTokenFingerprint
    && proposal.brainProgramFingerprint == witness.brainProgramFingerprint
    && proposal.brainShadowStateFingerprint
      == witness.brainShadowStateFingerprint
    && proposal.brainWitnessFingerprint == witness.witnessFingerprint;
  const bool proposedTokenZero = nb_bytes_zero(
    reinterpret_cast<device const uchar *>(proposedTokens),
    sizeof(NBAcceptedPhysicsStateToken));
  const bool proposedTokenValid = proposalAcceptProof
    && proposedToken.transactionFingerprint == token.transactionFingerprint
    && proposedToken.substepFingerprint == token.substepFingerprint
    && proposedToken.physicsStateFingerprint == token.physicsStateFingerprint
    && proposedToken.acceptedTimestampMicroseconds
      == token.acceptedTimestampMicroseconds
    && proposedToken.physicsGeneration == token.physicsGeneration
    && proposedToken.environmentIdentifier == token.environmentIdentifier
    && proposedToken.flags == token.flags && proposedToken.reserved == 0ul
    && proposedToken.tokenFingerprint == token.tokenFingerprint
    && nb_accepted_token_fingerprint(proposedToken)
      == proposedToken.tokenFingerprint;
  const bool preflightValid = proposalAcceptProof
    && preflight.abiVersion == NB_HM_BRAIN_PREFLIGHT_ABI_VERSION
    && preflight.structBytes == NB_HM_BRAIN_PREFLIGHT_BYTES
    && preflight.status == NB_HM_BRAIN_PREFLIGHT_SUCCESS
    && preflight.environment == dispatch.environment
    && preflight.controlStep == dispatch.controlStep
    && preflight.substepIndex == dispatch.substepIndex
    && preflight.physicsSubstepCount == dispatch.physicsSubstepCount
    && preflight.transactionSlot == dispatch.transactionSlot
    && preflight.ownerProgramFingerprint == dispatch.ownerProgramFingerprint
    && preflight.transactionFingerprint == dispatch.transactionFingerprint
    && preflight.linearizationEpoch == dispatch.linearizationEpoch
    && preflight.slotGeneration == dispatch.slotGeneration
    && preflight.substepFingerprint == token.substepFingerprint
    && preflight.physicsTokenFingerprint == token.tokenFingerprint
    && preflight.fastTargetGeneration != 0ul
    && preflight.fastTargetGeneration == preflight.cognitiveTargetGeneration
    && fast.shadowGeneration == preflight.fastTargetGeneration
    && preflight.jointReceiptFingerprint != 0ul
    && preflight.fastProgramFingerprint == dispatch.fastProgramFingerprint
    && preflight.brainProgramFingerprint == dispatch.brainProgramFingerprint
    && preflight.preflightFingerprint != 0ul
    && preflight.preflightFingerprint == nb_preflight_fingerprint(preflight);

  ack.proposalFingerprint = proposal.proposalFingerprint;
  if (!dispatchValid || !proposalValid) {
    ack.code = NB_HM_BRAIN_ACK_INVALID_PROPOSAL;
  } else if (proposal.decision == NB_HM_ROOT_REJECT) {
    if (proposedTokenZero) {
      ack.status = NB_HM_BRAIN_ACK_REJECT;
      ack.decision = NB_HM_ROOT_REJECT;
      ack.code = NB_HM_BRAIN_ACK_PROPOSAL_REJECT;
    } else {
      ack.code = NB_HM_BRAIN_ACK_TOKEN_MISMATCH;
    }
  } else if (!witnessValid || !gateValid) {
    ack.code = NB_HM_BRAIN_ACK_INVALID_WITNESS;
  } else if (!fastValid) {
    ack.code = NB_HM_BRAIN_ACK_INVALID_FAST_GATE;
  } else if (!preflightValid) {
    ack.code = NB_HM_BRAIN_ACK_INVALID_PREFLIGHT;
  } else if (!proposedTokenValid) {
    ack.code = NB_HM_BRAIN_ACK_TOKEN_MISMATCH;
  } else {
    ack.status = NB_HM_BRAIN_ACK_ACCEPT;
    ack.decision = NB_HM_ROOT_ACCEPT;
    ack.code = NB_HM_BRAIN_ACK_SUCCESS;
  }
  if (ack.status == NB_HM_BRAIN_ACK_ACCEPT) {
    ack.physicsTokenFingerprint = proposal.physicsTokenFingerprint;
    ack.preflightFingerprint = preflight.preflightFingerprint;
    ack.fastGateFingerprint = fast.gateFingerprint;
    ack.brainWitnessFingerprint = proposal.brainWitnessFingerprint;
  }
  ack.ackFingerprint = nb_ack_fingerprint(ack);
  output[0] = ack;
}

kernel void validate_numanx_human_matter_applied_root(
  device const NBNumanXHumanMatterBrainCommitWitness *witnesses [[buffer(0)]],
  device const NBAcceptedPhysicsGateResult *startGate [[buffer(1)]],
  device const NBNumanXFastPrepareStatus *fastPrepareStatus [[buffer(2)]],
  device const NBNumanXHumanMatterProposal *proposals [[buffer(3)]],
  device const NBAcceptedPhysicsStateToken *proposedTokens [[buffer(4)]],
  device const NBNumanXHumanMatterBrainCommitPreflight *preflights [[buffer(5)]],
  device const NBNumanXHumanMatterBrainAck *acks [[buffer(6)]],
  device const NBNumanXHumanMatterAppliedOutcome *appliedOutcomes [[buffer(7)]],
  device const NBAcceptedPhysicsStateToken *finalTokens [[buffer(8)]],
  constant NBNumanXAppliedValidationDispatchGPU &dispatch [[buffer(9)]],
  device NBNumanXHumanMatterAppliedValidationResult *output [[buffer(10)]],
  device NBAcceptedPhysicsStateToken *validatedToken [[buffer(11)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u) return;
  const NBNumanXHumanMatterBrainCommitWitness witness = witnesses[0];
  const NBAcceptedPhysicsGateResult gate = startGate[0];
  const NBAcceptedPhysicsStateToken startToken = gate.acceptedToken;
  const NBNumanXFastPrepareStatus fast = fastPrepareStatus[0];
  const NBNumanXHumanMatterProposal proposal = proposals[0];
  const NBAcceptedPhysicsStateToken proposedToken = proposedTokens[0];
  const NBNumanXHumanMatterBrainCommitPreflight preflight = preflights[0];
  const NBNumanXHumanMatterBrainAck ack = acks[0];
  const NBNumanXHumanMatterAppliedOutcome applied = appliedOutcomes[0];
  const NBAcceptedPhysicsStateToken finalToken = finalTokens[0];

  NBNumanXHumanMatterAppliedValidationResult result = {};
  validatedToken[0] = {};
  result.abiVersion = NB_HM_APPLIED_VALIDATION_ABI_VERSION;
  result.structBytes = NB_HM_APPLIED_VALIDATION_BYTES;
  result.status = NB_HM_APPLIED_VALIDATION_INVALID;
  result.code = NB_HM_APPLIED_VALIDATION_IDENTITY_MISMATCH;
  result.decision = applied.decision;
  result.environment = dispatch.environment;
  result.stepIndex = dispatch.stepIndex;
  result.substepIndex = dispatch.substepIndex;
  result.transactionSlot = dispatch.transactionSlot;
  result.physicsSubstepCount = dispatch.physicsSubstepCount;
  result.controlStep = dispatch.controlStep;
  result.ownerProgramFingerprint = dispatch.ownerProgramFingerprint;
  result.transactionFingerprint = dispatch.transactionFingerprint;
  result.linearizationEpoch = dispatch.linearizationEpoch;
  result.slotGeneration = dispatch.slotGeneration;
  result.brainProgramFingerprint = dispatch.brainProgramFingerprint;
  result.fastProgramFingerprint = dispatch.fastProgramFingerprint;
  result.appliedCommandDisposition = ulong(dispatch.commandDisposition);

  const bool dispatchValid = dispatch.abiVersion == NB_HM_ABI_VERSION
    && dispatch.environment == 0u && dispatch.stepIndex == 0u
    && dispatch.substepIndex == 0u
    && dispatch.physicsSubstepCount == NB_HM_PHYSICS_SUBSTEP_COUNT
    && dispatch.ownerProgramFingerprint != 0ul
    && dispatch.transactionFingerprint != 0ul
    && dispatch.linearizationEpoch != 0ul
    && dispatch.slotGeneration != 0ul
    && dispatch.brainProgramFingerprint != 0ul
    && dispatch.fastProgramFingerprint != 0ul
    && (dispatch.commandDisposition
        == NB_HM_COMMAND_ACCEPTED_PENDING_PUBLICATION
      || dispatch.commandDisposition == NB_HM_COMMAND_REJECTED_RELEASED
      || dispatch.commandDisposition == NB_HM_COMMAND_TERMINAL_NO_TOUCH)
    && dispatch.reserved0 == 0u && dispatch.reserved1 == 0u
    && dispatch.reserved2 == 0u && dispatch.reserved3 == 0u;
  const bool witnessValid = dispatchValid
    && witness.magic == NB_HM_WITNESS_MAGIC
    && witness.abiVersion == NB_HM_WITNESS_ABI_VERSION
    && witness.structBytes == NB_HM_WITNESS_BYTES
    && witness.status == NB_HM_PREPARE_COMPLETE
    && witness.environment == dispatch.environment
    && witness.stepIndex == dispatch.stepIndex
    && witness.substepIndex == dispatch.substepIndex
    && witness.transactionSlot == dispatch.transactionSlot
    && witness.physicsSubstepCount == dispatch.physicsSubstepCount
    && witness.controlStep == dispatch.controlStep
    && witness.reserved0 == 0u
    && witness.programFingerprint == dispatch.ownerProgramFingerprint
    && witness.transactionFingerprint == dispatch.transactionFingerprint
    && witness.linearizationEpoch == dispatch.linearizationEpoch
    && witness.slotGeneration == dispatch.slotGeneration
    && witness.brainProgramFingerprint == dispatch.brainProgramFingerprint
    && witness.brainShadowStateFingerprint != 0ul
    && witness.witnessFingerprint != 0ul
    && witness.reserved1[0] == 0ul && witness.reserved1[1] == 0ul
    && witness.witnessFingerprint == nb_witness_fingerprint(witness);
  const ulong startTokenFingerprint = nb_accepted_token_fingerprint(startToken);
  const bool gateValid = witnessValid
    && gate.version == NB_ACCEPTED_PHYSICS_GATE_VERSION
    && gate.status == NB_ACCEPTED_PHYSICS_GATE_VALID
    && gate.expectedTransactionFingerprint == dispatch.transactionFingerprint
    && gate.observedTransactionFingerprint == dispatch.transactionFingerprint
    && gate.expectedSubstepFingerprint == startToken.substepFingerprint
    && gate.observedSubstepFingerprint == startToken.substepFingerprint
    && gate.computedTokenFingerprint == gate.observedTokenFingerprint
    && gate.computedTokenFingerprint == startTokenFingerprint
    && gate.reserved == 0ul
    && startToken.transactionFingerprint == dispatch.transactionFingerprint
    && startToken.environmentIdentifier == 0u && startToken.flags == 0u
    && startToken.reserved == 0ul
    && startToken.tokenFingerprint == startTokenFingerprint
    && startToken.tokenFingerprint == witness.physicsTokenFingerprint;
  const bool fastValid = gateValid
    && fast.abiVersion == NB_FAST_PREPARE_STATUS_ABI_VERSION
    && fast.structBytes == NB_FAST_PREPARE_STATUS_BYTES
    && fast.status == NB_FAST_PREPARE_SUCCESS
    && fast.environment == dispatch.environment
    && fast.controlStep == dispatch.controlStep
    && fast.substepIndex == dispatch.substepIndex
    && fast.physicsSubstepCount == dispatch.physicsSubstepCount
    && fast.reserved0 == 0u
    && fast.fastProgramFingerprint == dispatch.fastProgramFingerprint
    && fast.transactionFingerprint == dispatch.transactionFingerprint
    && fast.substepFingerprint == startToken.substepFingerprint
    && fast.expectedPhysicsGeneration == startToken.physicsGeneration
    && fast.acceptedTimestampMicroseconds
      == startToken.acceptedTimestampMicroseconds
    && fast.reserved1[0] == 0ul && fast.reserved1[1] == 0ul
    && fast.reserved1[2] == 0ul && fast.reserved1[3] == 0ul
    && fast.reserved1[4] == 0ul && fast.gateFingerprint != 0ul
    && fast.gateFingerprint == nb_fast_prepare_gate_fingerprint(fast);
  const bool proposalAcceptIdentity =
    proposal.decision == NB_HM_ROOT_ACCEPT
    && proposal.code == NB_HM_PROPOSAL_SUCCESS
    && proposal.physicsTokenFingerprint == startToken.tokenFingerprint
    && proposal.brainProgramFingerprint == witness.brainProgramFingerprint
    && proposal.brainShadowStateFingerprint
      == witness.brainShadowStateFingerprint
    && proposal.brainWitnessFingerprint == witness.witnessFingerprint;
  const bool proposalRejectIdentity =
    proposal.decision == NB_HM_ROOT_REJECT
    && ((proposal.physicsTokenFingerprint == 0ul
        && proposal.brainProgramFingerprint == 0ul
        && proposal.brainShadowStateFingerprint == 0ul
        && proposal.brainWitnessFingerprint == 0ul)
      || (proposal.physicsTokenFingerprint == startToken.tokenFingerprint
        && proposal.brainProgramFingerprint == witness.brainProgramFingerprint
        && proposal.brainShadowStateFingerprint
          == witness.brainShadowStateFingerprint
        && proposal.brainWitnessFingerprint == witness.witnessFingerprint));
  const bool proposalValid = fastValid
    && proposal.abiVersion == NB_HM_ABI_VERSION
    && proposal.status == NB_HM_PROPOSAL_READY
    && (proposalAcceptIdentity || proposalRejectIdentity)
    && proposal.programFingerprint == dispatch.ownerProgramFingerprint
    && proposal.transactionFingerprint == dispatch.transactionFingerprint
    && proposal.linearizationEpoch == dispatch.linearizationEpoch
    && proposal.slotGeneration == dispatch.slotGeneration
    && proposal.environment == dispatch.environment
    && proposal.stepIndex == dispatch.stepIndex
    && proposal.substepIndex == dispatch.substepIndex
    && proposal.transactionSlot == dispatch.transactionSlot
    && proposal.physicsSubstepCount == dispatch.physicsSubstepCount
    && proposal.controlStep == dispatch.controlStep
    && proposal.candidatePublicationFingerprint != 0ul
    && proposal.humanIOIdentityFingerprint != 0ul
    && proposal.proposalFingerprint != 0ul
    && proposal.proposalFingerprint == nb_proposal_fingerprint(proposal);
  const bool preflightStatusKnown =
    preflight.status == NB_HM_BRAIN_PREFLIGHT_PENDING
    || preflight.status == NB_HM_BRAIN_PREFLIGHT_SUCCESS
    || preflight.status == NB_HM_BRAIN_PREFLIGHT_FAILURE;
  const bool preflightRecordValid = proposalValid
    && preflight.abiVersion == NB_HM_BRAIN_PREFLIGHT_ABI_VERSION
    && preflight.structBytes == NB_HM_BRAIN_PREFLIGHT_BYTES
    && preflightStatusKnown
    && preflight.environment == dispatch.environment
    && preflight.controlStep == dispatch.controlStep
    && preflight.substepIndex == dispatch.substepIndex
    && preflight.physicsSubstepCount == dispatch.physicsSubstepCount
    && preflight.transactionSlot == dispatch.transactionSlot
    && preflight.ownerProgramFingerprint == dispatch.ownerProgramFingerprint
    && preflight.transactionFingerprint == dispatch.transactionFingerprint
    && preflight.linearizationEpoch == dispatch.linearizationEpoch
    && preflight.slotGeneration == dispatch.slotGeneration
    && preflight.substepFingerprint == startToken.substepFingerprint
    && (preflight.physicsTokenFingerprint == 0ul
      || preflight.physicsTokenFingerprint == startToken.tokenFingerprint)
    && ((preflight.fastTargetGeneration == 0ul
        && preflight.cognitiveTargetGeneration == 0ul)
      || (preflight.fastTargetGeneration == fast.shadowGeneration
        && preflight.cognitiveTargetGeneration == fast.shadowGeneration))
    && preflight.fastProgramFingerprint == dispatch.fastProgramFingerprint
    && preflight.brainProgramFingerprint == dispatch.brainProgramFingerprint
    && preflight.preflightFingerprint != 0ul
    && preflight.preflightFingerprint == nb_preflight_fingerprint(preflight);
  const bool preflightAcceptValid = preflightRecordValid
    && proposal.decision == NB_HM_ROOT_ACCEPT
    && preflight.status == NB_HM_BRAIN_PREFLIGHT_SUCCESS
    && preflight.physicsTokenFingerprint == startToken.tokenFingerprint
    && preflight.fastTargetGeneration != 0ul
    && preflight.jointReceiptFingerprint != 0ul;
  const bool preflightRejectValid = preflightRecordValid
    && proposal.decision == NB_HM_ROOT_REJECT;
  const bool ackStatusConsistent =
    (ack.status == NB_HM_BRAIN_ACK_ACCEPT
      && ack.decision == NB_HM_ROOT_ACCEPT
      && ack.code == NB_HM_BRAIN_ACK_SUCCESS)
    || (ack.status == NB_HM_BRAIN_ACK_REJECT
      && ack.decision == NB_HM_ROOT_REJECT);
  const bool ackIdentityValid = ackStatusConsistent
    && ack.abiVersion == NB_HM_BRAIN_ACK_ABI_VERSION
    && ack.programFingerprint == dispatch.ownerProgramFingerprint
    && ack.transactionFingerprint == dispatch.transactionFingerprint
    && ack.linearizationEpoch == dispatch.linearizationEpoch
    && ack.slotGeneration == dispatch.slotGeneration
    && ack.physicsTokenFingerprint == proposal.physicsTokenFingerprint
    && ack.proposalFingerprint == proposal.proposalFingerprint
    && ack.preflightFingerprint == preflight.preflightFingerprint
    && ack.fastGateFingerprint == fast.gateFingerprint
    && ack.brainWitnessFingerprint == proposal.brainWitnessFingerprint
    && ack.brainProgramFingerprint == dispatch.brainProgramFingerprint
    && ack.environment == dispatch.environment
    && ack.stepIndex == dispatch.stepIndex
    && ack.substepIndex == dispatch.substepIndex
    && ack.transactionSlot == dispatch.transactionSlot
    && ack.physicsSubstepCount == dispatch.physicsSubstepCount
    && ack.controlStep == dispatch.controlStep
    && ack.ackFingerprint != 0ul
    && ack.ackFingerprint == nb_ack_fingerprint(ack);
  const bool ackAcceptValid = ackIdentityValid && preflightAcceptValid
    && ack.status == NB_HM_BRAIN_ACK_ACCEPT;
  const bool ackRejectValid = ackIdentityValid && preflightRejectValid
    && ack.status == NB_HM_BRAIN_ACK_REJECT
    && ack.code == NB_HM_BRAIN_ACK_PROPOSAL_REJECT;
  const bool ackValid = ackAcceptValid || ackRejectValid;
  const bool appliedStatusConsistent =
    (applied.status == NB_HM_APPLIED_ACCEPT_QUARANTINED
      && applied.decision == NB_HM_ROOT_ACCEPT
      && applied.code == NB_HM_APPLIED_SUCCESS)
    || (applied.status == NB_HM_APPLIED_REJECT_RESTORED
      && applied.decision == NB_HM_ROOT_REJECT)
    || (applied.status == NB_HM_APPLIED_TERMINAL_NO_TOUCH
      && applied.decision == 0u);
  const bool appliedValid = ackValid && appliedStatusConsistent
    && applied.abiVersion == NB_HM_ABI_VERSION
    && applied.programFingerprint == dispatch.ownerProgramFingerprint
    && applied.transactionFingerprint == dispatch.transactionFingerprint
    && applied.linearizationEpoch == dispatch.linearizationEpoch
    && applied.slotGeneration == dispatch.slotGeneration
    && applied.physicsTokenFingerprint == proposal.physicsTokenFingerprint
    && applied.proposalFingerprint == proposal.proposalFingerprint
    && applied.ackFingerprint == ack.ackFingerprint
    && applied.preflightFingerprint == preflight.preflightFingerprint
    && applied.fastGateFingerprint == fast.gateFingerprint
    && applied.matterApplyFingerprint != 0ul
    && applied.environment == dispatch.environment
    && applied.stepIndex == dispatch.stepIndex
    && applied.substepIndex == dispatch.substepIndex
    && applied.transactionSlot == dispatch.transactionSlot
    && applied.physicsSubstepCount == dispatch.physicsSubstepCount
    && applied.controlStep == dispatch.controlStep
    && applied.appliedFingerprint != 0ul
    && applied.appliedFingerprint == nb_applied_fingerprint(applied);
  const bool proposedTokenValid = proposal.decision == NB_HM_ROOT_ACCEPT
    && proposedToken.transactionFingerprint == startToken.transactionFingerprint
    && proposedToken.substepFingerprint == startToken.substepFingerprint
    && proposedToken.physicsStateFingerprint
      == startToken.physicsStateFingerprint
    && proposedToken.acceptedTimestampMicroseconds
      == startToken.acceptedTimestampMicroseconds
    && proposedToken.physicsGeneration == startToken.physicsGeneration
    && proposedToken.environmentIdentifier == startToken.environmentIdentifier
    && proposedToken.flags == startToken.flags && proposedToken.reserved == 0ul
    && proposedToken.tokenFingerprint == startToken.tokenFingerprint
    && nb_accepted_token_fingerprint(proposedToken)
      == proposedToken.tokenFingerprint;
  const bool finalTokenValid = applied.decision == NB_HM_ROOT_ACCEPT
    && finalToken.transactionFingerprint == proposedToken.transactionFingerprint
    && finalToken.substepFingerprint == proposedToken.substepFingerprint
    && finalToken.physicsStateFingerprint == proposedToken.physicsStateFingerprint
    && finalToken.acceptedTimestampMicroseconds
      == proposedToken.acceptedTimestampMicroseconds
    && finalToken.physicsGeneration == proposedToken.physicsGeneration
    && finalToken.environmentIdentifier == proposedToken.environmentIdentifier
    && finalToken.flags == proposedToken.flags && finalToken.reserved == 0ul
    && finalToken.tokenFingerprint == proposedToken.tokenFingerprint
    && nb_accepted_token_fingerprint(finalToken) == finalToken.tokenFingerprint;
  const bool rejectedTokensZero = nb_bytes_zero(
      reinterpret_cast<device const uchar *>(proposedTokens),
      sizeof(NBAcceptedPhysicsStateToken))
    && nb_bytes_zero(
      reinterpret_cast<device const uchar *>(finalTokens),
      sizeof(NBAcceptedPhysicsStateToken));

  // A physical REJECT is authoritative from the exact owner proposal and
  // restored applied record. It must remain resolvable when the start gate,
  // fast preparation, witness, and Brain preflight stayed PENDING/zero.
  const uint independentRejectAppliedCode =
    nb_independent_reject_applied_code(proposal.code);
  const bool independentRejectProposalValid = dispatchValid
    && proposal.abiVersion == NB_HM_ABI_VERSION
    && proposal.status == NB_HM_PROPOSAL_READY
    && proposal.decision == NB_HM_ROOT_REJECT
    && independentRejectAppliedCode != NB_HM_INVALID_REJECT_CODE
    && proposal.programFingerprint == dispatch.ownerProgramFingerprint
    && proposal.transactionFingerprint == dispatch.transactionFingerprint
    && proposal.linearizationEpoch == dispatch.linearizationEpoch
    && proposal.slotGeneration == dispatch.slotGeneration
    && proposal.physicsTokenFingerprint == 0ul
    && proposal.brainProgramFingerprint == 0ul
    && proposal.brainShadowStateFingerprint == 0ul
    && proposal.brainWitnessFingerprint == 0ul
    && proposal.candidatePublicationFingerprint != 0ul
    && proposal.humanIOIdentityFingerprint != 0ul
    && proposal.environment == dispatch.environment
    && proposal.stepIndex == dispatch.stepIndex
    && proposal.substepIndex == dispatch.substepIndex
    && proposal.transactionSlot == dispatch.transactionSlot
    && proposal.physicsSubstepCount == dispatch.physicsSubstepCount
    && proposal.controlStep == dispatch.controlStep
    && proposal.proposalFingerprint != 0ul
    && proposal.proposalFingerprint == nb_proposal_fingerprint(proposal);
  const bool independentRejectAckValid = independentRejectProposalValid
    && ack.abiVersion == NB_HM_BRAIN_ACK_ABI_VERSION
    && ack.status == NB_HM_BRAIN_ACK_REJECT
    && ack.decision == NB_HM_ROOT_REJECT
    && ack.code == NB_HM_BRAIN_ACK_PROPOSAL_REJECT
    && ack.programFingerprint == dispatch.ownerProgramFingerprint
    && ack.transactionFingerprint == dispatch.transactionFingerprint
    && ack.linearizationEpoch == dispatch.linearizationEpoch
    && ack.slotGeneration == dispatch.slotGeneration
    && ack.physicsTokenFingerprint == 0ul
    && ack.proposalFingerprint == proposal.proposalFingerprint
    && ack.preflightFingerprint == 0ul
    && ack.fastGateFingerprint == 0ul
    && ack.brainWitnessFingerprint == 0ul
    && ack.brainProgramFingerprint == dispatch.brainProgramFingerprint
    && ack.environment == dispatch.environment
    && ack.stepIndex == dispatch.stepIndex
    && ack.substepIndex == dispatch.substepIndex
    && ack.transactionSlot == dispatch.transactionSlot
    && ack.physicsSubstepCount == dispatch.physicsSubstepCount
    && ack.controlStep == dispatch.controlStep
    && ack.ackFingerprint != 0ul
    && ack.ackFingerprint == nb_ack_fingerprint(ack);
  const bool independentRejectAppliedValid = independentRejectAckValid
    && applied.abiVersion == NB_HM_ABI_VERSION
    && applied.status == NB_HM_APPLIED_REJECT_RESTORED
    && applied.decision == NB_HM_ROOT_REJECT
    && applied.code == independentRejectAppliedCode
    && applied.programFingerprint == dispatch.ownerProgramFingerprint
    && applied.transactionFingerprint == dispatch.transactionFingerprint
    && applied.linearizationEpoch == dispatch.linearizationEpoch
    && applied.slotGeneration == dispatch.slotGeneration
    && applied.physicsTokenFingerprint == 0ul
    && applied.proposalFingerprint == proposal.proposalFingerprint
    && applied.ackFingerprint == ack.ackFingerprint
    && applied.preflightFingerprint == 0ul
    && applied.fastGateFingerprint == 0ul
    && applied.matterApplyFingerprint != 0ul
    && applied.environment == dispatch.environment
    && applied.stepIndex == dispatch.stepIndex
    && applied.substepIndex == dispatch.substepIndex
    && applied.transactionSlot == dispatch.transactionSlot
    && applied.physicsSubstepCount == dispatch.physicsSubstepCount
    && applied.controlStep == dispatch.controlStep
    && applied.appliedFingerprint != 0ul
    && applied.appliedFingerprint == nb_applied_fingerprint(applied);

  result.physicsTokenFingerprint = proposal.decision == NB_HM_ROOT_REJECT
    ? 0ul : applied.physicsTokenFingerprint;
  result.brainShadowStateFingerprint = proposal.decision == NB_HM_ROOT_REJECT
    ? 0ul : witness.brainShadowStateFingerprint;
  result.brainWitnessFingerprint = proposal.decision == NB_HM_ROOT_REJECT
    ? 0ul : witness.witnessFingerprint;
  result.proposalFingerprint = proposal.proposalFingerprint;
  result.preflightFingerprint = proposal.decision == NB_HM_ROOT_REJECT
    ? 0ul : preflight.preflightFingerprint;
  result.fastGateFingerprint = proposal.decision == NB_HM_ROOT_REJECT
    ? 0ul : fast.gateFingerprint;
  result.ackFingerprint = ack.ackFingerprint;
  result.matterApplyFingerprint = applied.matterApplyFingerprint;
  result.appliedFingerprint = applied.appliedFingerprint;
  result.fastTargetGeneration = proposal.decision == NB_HM_ROOT_REJECT
    ? 0ul : preflight.fastTargetGeneration;
  result.cognitiveTargetGeneration = proposal.decision == NB_HM_ROOT_REJECT
    ? 0ul : preflight.cognitiveTargetGeneration;
  result.jointCommitFingerprint = proposal.decision == NB_HM_ROOT_REJECT
    ? 0ul : preflight.jointReceiptFingerprint;
  result.substepFingerprint = proposal.decision == NB_HM_ROOT_REJECT
    ? 0ul : preflight.substepFingerprint;

  if (!dispatchValid) {
    result.code = NB_HM_APPLIED_VALIDATION_IDENTITY_MISMATCH;
  } else if (proposal.decision == NB_HM_ROOT_REJECT) {
    if (!independentRejectProposalValid) {
      result.code = NB_HM_APPLIED_VALIDATION_INVALID_PROPOSAL;
    } else if (!independentRejectAckValid) {
      result.code = NB_HM_APPLIED_VALIDATION_INVALID_ACK;
    } else if (dispatch.commandDisposition
        == NB_HM_COMMAND_TERMINAL_NO_TOUCH
        || applied.status == NB_HM_APPLIED_TERMINAL_NO_TOUCH) {
      result.status = NB_HM_APPLIED_VALIDATION_TERMINAL_NO_TOUCH;
      result.code = NB_HM_APPLIED_VALIDATION_COMMAND_NOT_SUCCESSFUL;
      result.decision = 0u;
    } else if (!independentRejectAppliedValid) {
      result.code = NB_HM_APPLIED_VALIDATION_INVALID_APPLIED;
    } else if (dispatch.commandDisposition
        == NB_HM_COMMAND_REJECTED_RELEASED && rejectedTokensZero) {
      result.status = NB_HM_APPLIED_VALIDATION_REJECT;
      result.code = NB_HM_APPLIED_VALIDATION_SUCCESS;
      result.decision = NB_HM_ROOT_REJECT;
    } else if (!rejectedTokensZero) {
      result.code = NB_HM_APPLIED_VALIDATION_INVALID_TOKEN;
    } else {
      result.code = NB_HM_APPLIED_VALIDATION_COMMAND_NOT_SUCCESSFUL;
    }
  } else if (!witnessValid || !gateValid || !fastValid) {
    result.code = NB_HM_APPLIED_VALIDATION_INVALID_WITNESS;
  } else if (!proposalValid) {
    result.code = NB_HM_APPLIED_VALIDATION_INVALID_PROPOSAL;
  } else if ((proposal.decision == NB_HM_ROOT_ACCEPT
        && !preflightAcceptValid)
      || (proposal.decision == NB_HM_ROOT_REJECT
        && !preflightRejectValid)) {
    result.code = NB_HM_APPLIED_VALIDATION_INVALID_PREFLIGHT;
  } else if (!ackValid) {
    result.code = NB_HM_APPLIED_VALIDATION_INVALID_ACK;
  } else if (dispatch.commandDisposition == NB_HM_COMMAND_TERMINAL_NO_TOUCH
      || applied.status == NB_HM_APPLIED_TERMINAL_NO_TOUCH) {
    result.status = NB_HM_APPLIED_VALIDATION_TERMINAL_NO_TOUCH;
    result.code = NB_HM_APPLIED_VALIDATION_COMMAND_NOT_SUCCESSFUL;
    result.decision = 0u;
  } else if (!appliedValid) {
    result.code = NB_HM_APPLIED_VALIDATION_INVALID_APPLIED;
  } else if (applied.decision == NB_HM_ROOT_ACCEPT
      && dispatch.commandDisposition
        == NB_HM_COMMAND_ACCEPTED_PENDING_PUBLICATION
      && proposedTokenValid && finalTokenValid) {
    result.status = NB_HM_APPLIED_VALIDATION_ACCEPT;
    result.code = NB_HM_APPLIED_VALIDATION_SUCCESS;
    result.decision = NB_HM_ROOT_ACCEPT;
    result.tokenValid = 1u;
    validatedToken[0] = finalToken;
  } else if (applied.decision == NB_HM_ROOT_REJECT
      && dispatch.commandDisposition == NB_HM_COMMAND_REJECTED_RELEASED
      && rejectedTokensZero) {
    result.status = NB_HM_APPLIED_VALIDATION_REJECT;
    result.code = NB_HM_APPLIED_VALIDATION_SUCCESS;
    result.decision = NB_HM_ROOT_REJECT;
  } else if (!proposedTokenValid || !finalTokenValid) {
    result.code = NB_HM_APPLIED_VALIDATION_INVALID_TOKEN;
  } else {
    result.code = NB_HM_APPLIED_VALIDATION_COMMAND_NOT_SUCCESSFUL;
  }
  result.resultFingerprint = nb_applied_validation_fingerprint(result);
  output[0] = result;
}

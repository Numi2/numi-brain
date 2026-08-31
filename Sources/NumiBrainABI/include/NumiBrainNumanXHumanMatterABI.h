#ifndef NUMI_BRAIN_NUMANX_HUMAN_MATTER_ABI_H
#define NUMI_BRAIN_NUMANX_HUMAN_MATTER_ABI_H

#include <stddef.h>
#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif

enum {
  NB_NUMANX_HUMAN_MATTER_ABI_VERSION = 4,
  NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_WITNESS_ABI_VERSION = 1,
  NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_WITNESS_MAGIC = 0x4e584257,
  NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_WITNESS_BYTE_COUNT = 128,
  NB_NUMANX_HUMAN_MATTER_PROPOSAL_BYTE_COUNT = 128,
  NB_NUMANX_HUMAN_MATTER_BRAIN_PREFLIGHT_ABI_VERSION = 1,
  NB_NUMANX_HUMAN_MATTER_BRAIN_PREFLIGHT_BYTE_COUNT = 128,
  NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_ABI_VERSION = 1,
  NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_BYTE_COUNT = 128,
  NB_NUMANX_HUMAN_MATTER_APPLIED_OUTCOME_BYTE_COUNT = 128,
  NB_NUMANX_HUMAN_MATTER_PUBLICATION_FENCE_ABI_VERSION = 1,
  NB_NUMANX_HUMAN_MATTER_PUBLICATION_FENCE_BYTE_COUNT = 128,
  NB_NUMANX_HUMAN_MATTER_ACCEPTED_TOKEN_BYTE_COUNT = 64,
  NB_NUMANX_HUMAN_MATTER_PHYSICS_SUBSTEP_COUNT = 1,
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_ABI_VERSION = 1,
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_BYTE_COUNT = 256,
  NB_NUMANX_FAST_PREPARE_STATUS_ABI_VERSION = 1,
  NB_NUMANX_FAST_PREPARE_STATUS_BYTE_COUNT = 128,
};

typedef enum NBNumanXFastPrepareStatusCode {
  NB_NUMANX_FAST_PREPARE_PENDING = 0,
  NB_NUMANX_FAST_PREPARE_SUCCESS = 1,
  NB_NUMANX_FAST_PREPARE_FAILURE = 2,
} NBNumanXFastPrepareStatusCode;

typedef enum NBNumanXHumanMatterBrainCommitStatus {
  NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_UNINITIALIZED = 0,
  NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_PREPARE_COMPLETE = 1,
  NB_NUMANX_HUMAN_MATTER_BRAIN_COMMIT_PREPARE_FAILED = 2,
} NBNumanXHumanMatterBrainCommitStatus;

typedef enum NBNumanXHumanMatterRootDecision {
  NB_NUMANX_HUMAN_MATTER_ROOT_PENDING = 0,
  NB_NUMANX_HUMAN_MATTER_ROOT_ACCEPT = 1,
  NB_NUMANX_HUMAN_MATTER_ROOT_REJECT = 2,
} NBNumanXHumanMatterRootDecision;

typedef enum NBNumanXHumanMatterProposalStatus {
  NB_NUMANX_HUMAN_MATTER_PROPOSAL_PENDING = 0,
  NB_NUMANX_HUMAN_MATTER_PROPOSAL_READY = 1,
  NB_NUMANX_HUMAN_MATTER_PROPOSAL_FAILURE = 2,
  NB_NUMANX_HUMAN_MATTER_PROPOSAL_TERMINAL_NO_TOUCH = 3,
} NBNumanXHumanMatterProposalStatus;

typedef enum NBNumanXHumanMatterProposalCode {
  NB_NUMANX_HUMAN_MATTER_PROPOSAL_SUCCESS = 0,
  NB_NUMANX_HUMAN_MATTER_PROPOSAL_PHYSICAL_REJECT = 1,
  NB_NUMANX_HUMAN_MATTER_PROPOSAL_INVALID_OWNER = 2,
  NB_NUMANX_HUMAN_MATTER_PROPOSAL_INVALID_BRAIN_WITNESS = 3,
  NB_NUMANX_HUMAN_MATTER_PROPOSAL_TOKEN_MISMATCH = 4,
  NB_NUMANX_HUMAN_MATTER_PROPOSAL_FORCED_REJECT = 5,
  NB_NUMANX_HUMAN_MATTER_PROPOSAL_BRAIN_REJECT = 6,
} NBNumanXHumanMatterProposalCode;

typedef enum NBNumanXHumanMatterBrainPreflightStatus {
  NB_NUMANX_HUMAN_MATTER_BRAIN_PREFLIGHT_PENDING = 0,
  NB_NUMANX_HUMAN_MATTER_BRAIN_PREFLIGHT_SUCCESS = 1,
  NB_NUMANX_HUMAN_MATTER_BRAIN_PREFLIGHT_FAILURE = 2,
} NBNumanXHumanMatterBrainPreflightStatus;

typedef enum NBNumanXHumanMatterBrainAckStatus {
  NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_PENDING = 0,
  NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_ACCEPT = 1,
  NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_REJECT = 2,
  NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_INVALID = 3,
} NBNumanXHumanMatterBrainAckStatus;

typedef enum NBNumanXHumanMatterBrainAckCode {
  NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_SUCCESS = 0,
  NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_PROPOSAL_REJECT = 1,
  NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_INVALID_PROPOSAL = 2,
  NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_INVALID_WITNESS = 3,
  NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_INVALID_FAST_GATE = 4,
  NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_INVALID_PREFLIGHT = 5,
  NB_NUMANX_HUMAN_MATTER_BRAIN_ACK_TOKEN_MISMATCH = 6,
} NBNumanXHumanMatterBrainAckCode;

typedef enum NBNumanXHumanMatterAppliedStatus {
  NB_NUMANX_HUMAN_MATTER_APPLIED_PENDING = 0,
  NB_NUMANX_HUMAN_MATTER_APPLIED_ACCEPT_QUARANTINED = 1,
  NB_NUMANX_HUMAN_MATTER_APPLIED_REJECT_RESTORED = 2,
  NB_NUMANX_HUMAN_MATTER_APPLIED_TERMINAL_NO_TOUCH = 3,
} NBNumanXHumanMatterAppliedStatus;

typedef enum NBNumanXHumanMatterAppliedCode {
  NB_NUMANX_HUMAN_MATTER_APPLIED_SUCCESS = 0,
  NB_NUMANX_HUMAN_MATTER_APPLIED_FORCED_REJECT = 1,
  NB_NUMANX_HUMAN_MATTER_APPLIED_PHYSICAL_REJECT = 2,
  NB_NUMANX_HUMAN_MATTER_APPLIED_INVALID_OWNER = 3,
  NB_NUMANX_HUMAN_MATTER_APPLIED_INVALID_BRAIN_ACK = 4,
  NB_NUMANX_HUMAN_MATTER_APPLIED_TOKEN_MISMATCH = 5,
  NB_NUMANX_HUMAN_MATTER_APPLIED_MATTER_REJECT = 6,
  NB_NUMANX_HUMAN_MATTER_APPLIED_INVALID_MATTER_OUTCOME = 7,
  NB_NUMANX_HUMAN_MATTER_APPLIED_BRAIN_REJECT = 8,
} NBNumanXHumanMatterAppliedCode;

typedef enum NBNumanXHumanMatterPublicationFenceStatus {
  NB_NUMANX_HUMAN_MATTER_PUBLICATION_PENDING = 0,
  NB_NUMANX_HUMAN_MATTER_PUBLICATION_COMMITTED = 1,
  NB_NUMANX_HUMAN_MATTER_PUBLICATION_FAILURE = 2,
} NBNumanXHumanMatterPublicationFenceStatus;

typedef enum NBNumanXHumanMatterAppliedValidationStatus {
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_UNINITIALIZED = 0,
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_ACCEPT = 1,
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_REJECT = 2,
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_INVALID = 3,
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_TERMINAL_NO_TOUCH = 4,
} NBNumanXHumanMatterAppliedValidationStatus;

typedef enum NBNumanXHumanMatterAppliedValidationCode {
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_SUCCESS = 0,
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_INVALID_WITNESS = 1,
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_INVALID_PROPOSAL = 2,
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_INVALID_PREFLIGHT = 3,
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_INVALID_ACK = 4,
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_INVALID_APPLIED = 5,
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_INVALID_TOKEN = 6,
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_IDENTITY_MISMATCH = 7,
  NB_NUMANX_HUMAN_MATTER_APPLIED_VALIDATION_COMMAND_NOT_SUCCESSFUL = 8,
} NBNumanXHumanMatterAppliedValidationCode;

typedef enum NBNumanXHumanMatterAppliedCommandDisposition {
  NB_NUMANX_HUMAN_MATTER_COMMAND_ACCEPTED_PENDING_PUBLICATION = 1,
  NB_NUMANX_HUMAN_MATTER_COMMAND_REJECTED_RELEASED = 2,
  NB_NUMANX_HUMAN_MATTER_COMMAND_TERMINAL_NO_TOUCH = 3,
} NBNumanXHumanMatterAppliedCommandDisposition;

#if defined(__clang__) || defined(__GNUC__)
#define NB_NUMANX_ALIGN16 __attribute__((aligned(16)))
#else
#define NB_NUMANX_ALIGN16
#endif

typedef struct NB_NUMANX_ALIGN16 NBNumanXFastPrepareStatusGPU {
  uint32_t abiVersion;
  uint32_t structBytes;
  uint32_t status;
  uint32_t environment;
  uint32_t controlStep;
  uint32_t substepIndex;
  uint32_t physicsSubstepCount;
  uint32_t reserved0;
  uint64_t fastProgramFingerprint;
  uint64_t transactionFingerprint;
  uint64_t substepFingerprint;
  uint64_t expectedPhysicsGeneration;
  uint64_t shadowGeneration;
  uint64_t acceptedTimestampMicroseconds;
  uint64_t reserved1[5];
  uint64_t gateFingerprint;
} NBNumanXFastPrepareStatusGPU;

// Exact binary mirror of MRNumanXHumanMatterBrainCommitWitnessGPU.
typedef struct NB_NUMANX_ALIGN16 NBNumanXHumanMatterBrainCommitWitness {
  uint32_t magic;
  uint32_t abiVersion;
  uint32_t structBytes;
  uint32_t status;
  uint32_t decision;
  uint32_t environment;
  uint32_t stepIndex;
  uint32_t substepIndex;
  uint32_t transactionSlot;
  uint32_t physicsSubstepCount;
  uint32_t controlStep;
  uint32_t reserved0;
  uint64_t programFingerprint;
  uint64_t transactionFingerprint;
  uint64_t linearizationEpoch;
  uint64_t slotGeneration;
  uint64_t physicsTokenFingerprint;
  uint64_t brainProgramFingerprint;
  uint64_t brainShadowStateFingerprint;
  uint64_t witnessFingerprint;
  uint64_t reserved1[2];
} NBNumanXHumanMatterBrainCommitWitness;

// Exact binary mirror of MRNumanXHumanMatterProposalGPU.
typedef struct NB_NUMANX_ALIGN16 NBNumanXHumanMatterProposalGPU {
  uint32_t abiVersion;
  uint32_t status;
  uint32_t decision;
  uint32_t code;
  uint64_t programFingerprint;
  uint64_t transactionFingerprint;
  uint64_t linearizationEpoch;
  uint64_t slotGeneration;
  uint64_t physicsTokenFingerprint;
  uint64_t brainProgramFingerprint;
  uint64_t brainShadowStateFingerprint;
  uint64_t brainWitnessFingerprint;
  uint64_t candidatePublicationFingerprint;
  uint64_t humanIOIdentityFingerprint;
  uint32_t environment;
  uint32_t stepIndex;
  uint32_t substepIndex;
  uint32_t transactionSlot;
  uint32_t physicsSubstepCount;
  uint32_t controlStep;
  uint64_t proposalFingerprint;
} NBNumanXHumanMatterProposalGPU;

// Exact binary mirror of MRNumanXHumanMatterBrainCommitPreflightGPU.
typedef struct NB_NUMANX_ALIGN16 NBNumanXHumanMatterBrainCommitPreflightGPU {
  uint32_t abiVersion;
  uint32_t structBytes;
  uint32_t status;
  uint32_t environment;
  uint32_t controlStep;
  uint32_t substepIndex;
  uint32_t physicsSubstepCount;
  uint32_t transactionSlot;
  uint64_t ownerProgramFingerprint;
  uint64_t transactionFingerprint;
  uint64_t linearizationEpoch;
  uint64_t slotGeneration;
  uint64_t substepFingerprint;
  uint64_t physicsTokenFingerprint;
  uint64_t fastTargetGeneration;
  uint64_t cognitiveTargetGeneration;
  uint64_t jointReceiptFingerprint;
  uint64_t fastProgramFingerprint;
  uint64_t brainProgramFingerprint;
  uint64_t preflightFingerprint;
} NBNumanXHumanMatterBrainCommitPreflightGPU;

// Exact binary mirror of MRNumanXHumanMatterBrainAckGPU.
typedef struct NB_NUMANX_ALIGN16 NBNumanXHumanMatterBrainAckGPU {
  uint32_t abiVersion;
  uint32_t status;
  uint32_t decision;
  uint32_t code;
  uint64_t programFingerprint;
  uint64_t transactionFingerprint;
  uint64_t linearizationEpoch;
  uint64_t slotGeneration;
  uint64_t physicsTokenFingerprint;
  uint64_t proposalFingerprint;
  uint64_t preflightFingerprint;
  uint64_t fastGateFingerprint;
  uint64_t brainWitnessFingerprint;
  uint64_t brainProgramFingerprint;
  uint32_t environment;
  uint32_t stepIndex;
  uint32_t substepIndex;
  uint32_t transactionSlot;
  uint32_t physicsSubstepCount;
  uint32_t controlStep;
  uint64_t ackFingerprint;
} NBNumanXHumanMatterBrainAckGPU;

// Exact binary mirror of MRNumanXHumanMatterAppliedOutcomeGPU.
typedef struct NB_NUMANX_ALIGN16 NBNumanXHumanMatterAppliedOutcomeGPU {
  uint32_t abiVersion;
  uint32_t status;
  uint32_t decision;
  uint32_t code;
  uint64_t programFingerprint;
  uint64_t transactionFingerprint;
  uint64_t linearizationEpoch;
  uint64_t slotGeneration;
  uint64_t physicsTokenFingerprint;
  uint64_t proposalFingerprint;
  uint64_t ackFingerprint;
  uint64_t preflightFingerprint;
  uint64_t fastGateFingerprint;
  uint64_t matterApplyFingerprint;
  uint32_t environment;
  uint32_t stepIndex;
  uint32_t substepIndex;
  uint32_t transactionSlot;
  uint32_t physicsSubstepCount;
  uint32_t controlStep;
  uint64_t appliedFingerprint;
} NBNumanXHumanMatterAppliedOutcomeGPU;

// Exact binary mirror of MRNumanXHumanMatterJointPublicationFenceGPU.
typedef struct NB_NUMANX_ALIGN16 NBNumanXHumanMatterJointPublicationFenceGPU {
  uint32_t abiVersion;
  uint32_t structBytes;
  uint32_t status;
  uint32_t environment;
  uint32_t controlStep;
  uint32_t substepIndex;
  uint32_t physicsSubstepCount;
  uint32_t reserved0;
  uint64_t ownerProgramFingerprint;
  uint64_t transactionFingerprint;
  uint64_t linearizationEpoch;
  uint64_t slotGeneration;
  uint64_t physicsTokenFingerprint;
  uint64_t brainProgramFingerprint;
  uint64_t brainShadowStateFingerprint;
  uint64_t brainWitnessFingerprint;
  uint64_t appliedDecisionFingerprint;
  uint64_t jointCommitFingerprint;
  uint64_t brainGeneration;
  uint64_t fenceFingerprint;
} NBNumanXHumanMatterJointPublicationFenceGPU;

// Brain-private compact result written only after the GPU validates the full
// proposal -> preflight -> ACK -> applied chain. It never publishes state.
// resultFingerprint is FNV-1a-64 over every prior declared field, including
// reserved words. The record is exactly 256 bytes with no implicit padding.
typedef struct NB_NUMANX_ALIGN16 NBNumanXHumanMatterAppliedValidationResultGPU {
  uint32_t abiVersion;
  uint32_t structBytes;
  uint32_t status;
  uint32_t code;
  uint32_t decision;
  uint32_t environment;
  uint32_t stepIndex;
  uint32_t substepIndex;
  uint32_t transactionSlot;
  uint32_t physicsSubstepCount;
  uint32_t controlStep;
  uint32_t tokenValid;
  uint64_t ownerProgramFingerprint;
  uint64_t transactionFingerprint;
  uint64_t linearizationEpoch;
  uint64_t slotGeneration;
  uint64_t physicsTokenFingerprint;
  uint64_t brainProgramFingerprint;
  uint64_t brainShadowStateFingerprint;
  uint64_t brainWitnessFingerprint;
  uint64_t proposalFingerprint;
  uint64_t preflightFingerprint;
  uint64_t fastGateFingerprint;
  uint64_t ackFingerprint;
  uint64_t matterApplyFingerprint;
  uint64_t appliedFingerprint;
  uint64_t fastProgramFingerprint;
  uint64_t fastTargetGeneration;
  uint64_t cognitiveTargetGeneration;
  uint64_t jointCommitFingerprint;
  uint64_t substepFingerprint;
  uint64_t appliedCommandDisposition;
  uint64_t reserved0[5];
  uint64_t resultFingerprint;
} NBNumanXHumanMatterAppliedValidationResultGPU;

#if defined(__cplusplus)
static_assert(sizeof(NBNumanXFastPrepareStatusGPU) == 128);
static_assert(alignof(NBNumanXFastPrepareStatusGPU) == 16);
static_assert(sizeof(NBNumanXHumanMatterBrainCommitWitness) == 128);
static_assert(offsetof(NBNumanXHumanMatterBrainCommitWitness, controlStep) == 40);
static_assert(offsetof(NBNumanXHumanMatterBrainCommitWitness, programFingerprint) == 48);
static_assert(sizeof(NBNumanXHumanMatterProposalGPU) == 128);
static_assert(offsetof(NBNumanXHumanMatterProposalGPU, programFingerprint) == 16);
static_assert(offsetof(NBNumanXHumanMatterProposalGPU, candidatePublicationFingerprint) == 80);
static_assert(offsetof(NBNumanXHumanMatterProposalGPU, humanIOIdentityFingerprint) == 88);
static_assert(offsetof(NBNumanXHumanMatterProposalGPU, environment) == 96);
static_assert(offsetof(NBNumanXHumanMatterProposalGPU, proposalFingerprint) == 120);
static_assert(sizeof(NBNumanXHumanMatterBrainCommitPreflightGPU) == 128);
static_assert(offsetof(NBNumanXHumanMatterBrainCommitPreflightGPU, ownerProgramFingerprint) == 32);
static_assert(offsetof(NBNumanXHumanMatterBrainCommitPreflightGPU, preflightFingerprint) == 120);
static_assert(sizeof(NBNumanXHumanMatterBrainAckGPU) == 128);
static_assert(offsetof(NBNumanXHumanMatterBrainAckGPU, programFingerprint) == 16);
static_assert(offsetof(NBNumanXHumanMatterBrainAckGPU, environment) == 96);
static_assert(offsetof(NBNumanXHumanMatterBrainAckGPU, ackFingerprint) == 120);
static_assert(sizeof(NBNumanXHumanMatterAppliedOutcomeGPU) == 128);
static_assert(offsetof(NBNumanXHumanMatterAppliedOutcomeGPU, programFingerprint) == 16);
static_assert(offsetof(NBNumanXHumanMatterAppliedOutcomeGPU, environment) == 96);
static_assert(offsetof(NBNumanXHumanMatterAppliedOutcomeGPU, appliedFingerprint) == 120);
static_assert(sizeof(NBNumanXHumanMatterJointPublicationFenceGPU) == 128);
static_assert(offsetof(NBNumanXHumanMatterJointPublicationFenceGPU, ownerProgramFingerprint) == 32);
static_assert(offsetof(NBNumanXHumanMatterJointPublicationFenceGPU, fenceFingerprint) == 120);
static_assert(sizeof(NBNumanXHumanMatterAppliedValidationResultGPU) == 256);
static_assert(alignof(NBNumanXHumanMatterAppliedValidationResultGPU) == 16);
static_assert(offsetof(NBNumanXHumanMatterAppliedValidationResultGPU, ownerProgramFingerprint) == 48);
static_assert(offsetof(NBNumanXHumanMatterAppliedValidationResultGPU, resultFingerprint) == 248);
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
_Static_assert(sizeof(NBNumanXFastPrepareStatusGPU) == 128, "fast status ABI");
_Static_assert(sizeof(NBNumanXHumanMatterBrainCommitWitness) == 128, "witness ABI");
_Static_assert(sizeof(NBNumanXHumanMatterProposalGPU) == 128, "proposal ABI");
_Static_assert(sizeof(NBNumanXHumanMatterBrainCommitPreflightGPU) == 128, "preflight ABI");
_Static_assert(sizeof(NBNumanXHumanMatterBrainAckGPU) == 128, "ack ABI");
_Static_assert(sizeof(NBNumanXHumanMatterAppliedOutcomeGPU) == 128, "applied ABI");
_Static_assert(sizeof(NBNumanXHumanMatterJointPublicationFenceGPU) == 128, "fence ABI");
_Static_assert(sizeof(NBNumanXHumanMatterAppliedValidationResultGPU) == 256, "validation ABI");
#endif

#undef NB_NUMANX_ALIGN16

#if defined(__cplusplus)
} // extern "C"
#endif

#endif // NUMI_BRAIN_NUMANX_HUMAN_MATTER_ABI_H

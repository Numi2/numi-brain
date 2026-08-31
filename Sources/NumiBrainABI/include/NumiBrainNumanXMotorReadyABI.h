#ifndef NUMI_BRAIN_NUMANX_MOTOR_READY_ABI_H
#define NUMI_BRAIN_NUMANX_MOTOR_READY_ABI_H

#include <stddef.h>
#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif

enum {
  NB_NUMANX_MOTOR_READY_ABI_VERSION = 1,
  NB_NUMANX_DECISION_READY_GATE_BYTE_COUNT = 160,
  NB_NUMANX_MOTOR_READY_GATE_BYTE_COUNT = 160,
  NB_NUMANX_DECISION_READY_MAX_RANGES = 12,
};

typedef enum NBNumanXReadyGateStatus {
  NB_NUMANX_READY_GATE_PENDING = 0,
  NB_NUMANX_READY_GATE_SUCCESS = 1,
  NB_NUMANX_READY_GATE_FAILURE = 2,
} NBNumanXReadyGateStatus;

#if defined(__clang__) || defined(__GNUC__)
#define NB_NUMANX_READY_ALIGN16 __attribute__((aligned(16)))
#else
#define NB_NUMANX_READY_ALIGN16
#endif

/// Brain-owned terminal record for an asynchronous cognitive decision. The
/// shared event paired with this record proves liveness only; consumers must
/// validate SUCCESS and the complete fingerprint before touching decision
/// bytes. `decisionOutputFingerprint` covers every range consumed by the fast
/// motor handoff in canonical range order.
typedef struct NB_NUMANX_READY_ALIGN16 NBNumanXDecisionReadyGateGPU {
  uint32_t abiVersion;
  uint32_t structBytes;
  uint32_t status;
  uint32_t environment;
  uint32_t rangeCount;
  uint32_t flags;
  uint32_t reserved32_0;
  uint32_t reserved32_1;
  uint64_t controlStep;
  uint64_t transactionFingerprint;
  uint64_t shadowGeneration;
  uint64_t decisionTimestampMicroseconds;
  uint64_t randomCounterGeneration;
  uint64_t speciesTemplateFingerprint;
  uint64_t compiledSpeciesTemplateFingerprint;
  uint64_t parameterVersionFingerprint;
  uint64_t regionalProgramFingerprint;
  uint64_t scheduleFingerprint;
  uint64_t brainProgramFingerprint;
  uint64_t decisionOutputFingerprint;
  uint64_t descendingSomaticFingerprint;
  uint64_t autonomicCommandFingerprint;
  uint64_t activeSensingCommandFingerprint;
  uint64_t gateFingerprint;
} NBNumanXDecisionReadyGateGPU;

/// Brain-owned terminal record for one exact physical motor candidate. A new
/// allocation is required for every attempt. The record binds the immutable
/// 152-byte candidate identity, the recomputed motor-output payload digest,
/// both Brain programs, and the exact upstream decision gate.
typedef struct NB_NUMANX_READY_ALIGN16 NBNumanXMotorReadyGateGPU {
  uint32_t abiVersion;
  uint32_t structBytes;
  uint32_t status;
  uint32_t environment;
  uint32_t substepIndex;
  uint32_t attemptIndex;
  uint32_t muscleCount;
  uint32_t actuatorCommandKind;
  uint64_t controlStep;
  uint64_t transactionFingerprint;
  uint64_t substepFingerprint;
  uint64_t candidateFingerprint;
  uint64_t motorOutputFingerprint;
  uint64_t motorProfileFingerprint;
  uint64_t brainGeneration;
  uint64_t acceptedBrainTimestampMicroseconds;
  uint64_t randomCounterGeneration;
  uint64_t speciesTemplateFingerprint;
  uint64_t compiledSpeciesTemplateFingerprint;
  uint64_t brainProgramFingerprint;
  uint64_t fastProgramFingerprint;
  uint64_t decisionGateFingerprint;
  uint64_t reserved64_0;
  uint64_t gateFingerprint;
} NBNumanXMotorReadyGateGPU;

#if defined(__cplusplus)
static_assert(sizeof(NBNumanXDecisionReadyGateGPU) == 160);
static_assert(alignof(NBNumanXDecisionReadyGateGPU) == 16);
static_assert(offsetof(NBNumanXDecisionReadyGateGPU, gateFingerprint) == 152);
static_assert(sizeof(NBNumanXMotorReadyGateGPU) == 160);
static_assert(alignof(NBNumanXMotorReadyGateGPU) == 16);
static_assert(offsetof(NBNumanXMotorReadyGateGPU, gateFingerprint) == 152);
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
_Static_assert(sizeof(NBNumanXDecisionReadyGateGPU) == 160,
               "decision-ready gate ABI");
_Static_assert(_Alignof(NBNumanXDecisionReadyGateGPU) == 16,
               "decision-ready gate alignment");
_Static_assert(offsetof(NBNumanXDecisionReadyGateGPU, gateFingerprint) == 152,
               "decision-ready fingerprint offset");
_Static_assert(sizeof(NBNumanXMotorReadyGateGPU) == 160,
               "motor-ready gate ABI");
_Static_assert(_Alignof(NBNumanXMotorReadyGateGPU) == 16,
               "motor-ready gate alignment");
_Static_assert(offsetof(NBNumanXMotorReadyGateGPU, gateFingerprint) == 152,
               "motor-ready fingerprint offset");
#endif

#undef NB_NUMANX_READY_ALIGN16

#if defined(__cplusplus)
} // extern "C"
#endif

#endif // NUMI_BRAIN_NUMANX_MOTOR_READY_ABI_H

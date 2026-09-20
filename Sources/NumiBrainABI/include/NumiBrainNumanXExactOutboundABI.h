#ifndef NUMI_BRAIN_NUMANX_EXACT_OUTBOUND_ABI_H
#define NUMI_BRAIN_NUMANX_EXACT_OUTBOUND_ABI_H

#include <stddef.h>
#include <stdint.h>

// This header is also directly includable by C/C++ consumers. When it is
// reached through NumiBrainABI.h, that include guard is already active and all
// Brain-owned request-v3 records have been declared above this point.
#include "NumiBrainABI.h"

#if defined(__cplusplus)
extern "C" {
#endif

enum {
  NB_NUMANX_EXACT_INBOUND_AUTHORITY_ABI_V2 = 2,
  NB_NUMANX_EXACT_SENSOR_CHANNEL_ABI_V2 = 2,
  NB_NUMANX_EXACT_SENSOR_TIMING_ABI_V2 = 2,
  NB_NUMANX_EXACT_SENSOR_PACKET_ABI_V2 = 2,
  NB_NUMANX_EXACT_PUBLICATION_ABI_V2 = 2,
  NB_NUMANX_EXACT_ACCEPTED_STATE_PROOF_ABI_V2 = 3,
  NB_NUMANX_EXACT_ACCEPTED_PHYSICS_TOKEN_VERSION_V2 = 2,
  NB_NUMANX_EXACT_INBOUND_AUTHORITY_V2_BYTE_COUNT = 112,
  NB_NUMANX_EXACT_ACCEPTED_STATE_PROOF_V2_BYTE_COUNT = 160,
  NB_NUMANX_EXACT_ACCEPTED_PHYSICS_TOKEN_V2_BYTE_COUNT = 64,
  NB_NUMANX_EXACT_SENSOR_TIMING_V2_BYTE_COUNT = 56,
  NB_NUMANX_EXACT_SENSOR_CHANNEL_V2_BYTE_COUNT = 144,
  NB_NUMANX_EXACT_SENSOR_PACKET_V2_BYTE_COUNT = 128,
  NB_NUMANX_EXACT_PUBLICATION_V2_BYTE_COUNT = 72,
  NB_NUMANX_EXACT_MAX_SENSOR_CHANNELS_V2 = 8,
  NB_NUMANX_EXACT_ACCEPTED_STATE_PROOF_VALID = 1,
  NB_NUMANX_EXACT_METAL_RANGE_ABI_V1 = 1,
  NB_NUMANX_EXACT_ELEMENT_FLOAT32_V1 = 1,
  NB_NUMANX_EXACT_ELEMENT_UINT32_V1 = 2,
  NB_NUMANX_EXACT_SENSOR_CHANNEL_HAS_VALIDITY_V1 = 1 << 0,
  NB_NUMANX_EXACT_MODALITY_VISION_V1 = 1,
  NB_NUMANX_EXACT_MODALITY_AUDITION_V1 = 2,
  NB_NUMANX_EXACT_MODALITY_TOUCH_V1 = 3,
  NB_NUMANX_EXACT_MODALITY_PROPRIOCEPTION_V1 = 4,
  NB_NUMANX_EXACT_MODALITY_VESTIBULAR_V1 = 5,
  NB_NUMANX_EXACT_MODALITY_INTEROCEPTION_V1 = 8,
  NB_NUMANX_EXACT_MODALITY_KINESTHESIA_V1 = 9,
  NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_INBOUND_AUTHORITY_V2 = 0x4e584941,
  NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_PHYSICS_STATE_V2 = 0x4e585053,
  NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_ACCEPTED_STATE_PROOF_V2 = 0x4e584150,
  NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_ACCEPTED_PHYSICS_TOKEN_V2 = 0x4e584154,
  NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_SENSOR_TIMING_V2 = 0x4e58544d,
  NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_SENSOR_CHANNEL_V2 = 0x4e584348,
  NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_SENSOR_CHANNEL_SET_V2 = 0x4e584353,
  NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_SENSOR_PACKET_V2 = 0x4e585350,
  NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_PUBLICATION_V2 = 0x4e585050,
};

typedef enum NBNumanXExactOutboundValidation {
  NB_NUMANX_EXACT_OUTBOUND_VALID = 0,
  NB_NUMANX_EXACT_OUTBOUND_NULL = 1,
  NB_NUMANX_EXACT_OUTBOUND_FORMAT = 2,
  NB_NUMANX_EXACT_OUTBOUND_CLOCK = 3,
  NB_NUMANX_EXACT_OUTBOUND_IDENTITY = 4,
  NB_NUMANX_EXACT_OUTBOUND_RELATION = 5,
  NB_NUMANX_EXACT_OUTBOUND_TIME_ORDER = 6,
  NB_NUMANX_EXACT_OUTBOUND_GENERATION = 7,
  NB_NUMANX_EXACT_OUTBOUND_RANGE = 8,
  NB_NUMANX_EXACT_OUTBOUND_ORDER = 9,
  NB_NUMANX_EXACT_OUTBOUND_FINGERPRINT = 10,
  NB_NUMANX_EXACT_OUTBOUND_OVERFLOW = 11,
} NBNumanXExactOutboundValidation;

#if defined(__clang__) || defined(__GNUC__)
#define NB_NUMANX_EXACT_ALIGN16 __attribute__((aligned(16)))
#else
#define NB_NUMANX_EXACT_ALIGN16
#endif

// Brain-owned, pointer-free receipt for every identity emitted by the exact
// request-v3 producer. The terminal digest is consumed by the native matcher;
// it never grants physical acceptance on its own.
typedef struct NBNumanXExactInboundAuthorityV2 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint32_t clock_domain;
  uint32_t clock_quantum_nanoseconds;
  uint64_t accepted_brain_timestamp_nanoseconds;
  uint64_t brain_generation;
  uint64_t transaction_fingerprint;
  uint64_t substep_fingerprint;
  uint64_t motor_candidate_fingerprint;
  uint64_t motor_output_fingerprint;
  uint64_t motor_profile_fingerprint;
  uint64_t motor_ready_gate_fingerprint;
  uint64_t brain_program_fingerprint;
  uint64_t fast_program_fingerprint;
  uint64_t decision_gate_fingerprint;
  uint64_t inbound_authority_fingerprint;
} NBNumanXExactInboundAuthorityV2;

// Native-produced HumanMatter acceptance proof. NumiBrain validates this
// immutable receipt but does not derive or own its physical state identities.
typedef struct NB_NUMANX_EXACT_ALIGN16 NBNumanXAcceptedStateProofV2 {
  uint32_t abiVersion;
  uint32_t structSize;
  uint32_t status;
  uint32_t environment;
  uint64_t transactionFingerprint;
  uint64_t substepFingerprint;
  uint64_t acceptedTimestampNanoseconds;
  uint64_t physicsGeneration;
  uint32_t clockDomain;
  uint32_t clockQuantumNanoseconds;
  uint64_t humanStateFingerprint;
  uint64_t matterStateFingerprint;
  uint64_t physicsStateFingerprint;
  uint64_t matterSourcePhysicsFingerprint;
  uint64_t matterDeviceProgramFingerprint;
  uint64_t stateProofProgramFingerprint;
  uint64_t adapterProgramFingerprint;
  uint64_t transactionPolicyFingerprint;
  uint64_t linearizationEpoch;
  uint64_t slotGeneration;
  uint64_t motorCandidateFingerprint;
  uint64_t inboundAuthorityFingerprint;
  uint64_t proofFingerprint;
} NBNumanXAcceptedStateProofV2;

// This record intentionally has its own NXAT hash family. It is byte-compatible
// with the native accepted-token lease but does not redefine the already
// published NBAcceptedPhysicsStateTokenV2 fingerprint.
typedef struct NB_NUMANX_EXACT_ALIGN16 NBNumanXExactAcceptedPhysicsTokenV2 {
  uint64_t transactionFingerprint;
  uint64_t substepFingerprint;
  uint64_t physicsStateFingerprint;
  uint64_t acceptedTimestampNanoseconds;
  uint64_t physicsGeneration;
  uint32_t environmentIdentifier;
  uint32_t flags;
  uint32_t clockDomain;
  uint32_t clockQuantumNanoseconds;
  uint64_t tokenFingerprint;
} NBNumanXExactAcceptedPhysicsTokenV2;

typedef struct NBNumanXExactMetalRangeV1 {
  uint32_t abi_version;
  uint32_t struct_size;
  void *metal_buffer;
  uint64_t gpu_address;
  uint64_t byte_offset;
  uint64_t byte_count;
  uint32_t element_type;
  uint32_t element_byte_count;
} NBNumanXExactMetalRangeV1;

typedef struct NBNumanXExactSensorChannelV2 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint32_t modality;
  uint32_t flags;
  uint64_t receptor_timestamp_nanoseconds;
  uint32_t clock_domain;
  uint32_t clock_quantum_nanoseconds;
  uint32_t receptor_count;
  uint32_t feature_dimension;
  NBNumanXExactMetalRangeV1 values;
  NBNumanXExactMetalRangeV1 validity;
  uint64_t channel_fingerprint;
} NBNumanXExactSensorChannelV2;

typedef struct NBNumanXExactSensorTimingV2 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint64_t capture_timestamp_nanoseconds;
  uint64_t delivery_timestamp_nanoseconds;
  uint64_t latency_nanoseconds;
  uint64_t sample_interval_nanoseconds;
  uint32_t clock_domain;
  uint32_t clock_quantum_nanoseconds;
  uint64_t timing_fingerprint;
} NBNumanXExactSensorTimingV2;

typedef struct NBNumanXExactSensorPacketV2 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint32_t clock_domain;
  uint32_t clock_quantum_nanoseconds;
  uint32_t channel_count;
  uint32_t channel_capacity;
  uint64_t transaction_fingerprint;
  uint64_t substep_fingerprint;
  uint64_t accepted_physics_token_fingerprint;
  uint64_t inbound_authority_fingerprint;
  uint64_t human_io_program_fingerprint;
  uint64_t sensor_fingerprint;
  uint64_t transaction_instance_fingerprint;
  uint64_t sensor_generation;
  uint64_t accepted_brain_generation;
  uint64_t device_registry_id;
  uint64_t timing_fingerprint;
  uint64_t channel_set_fingerprint;
  uint64_t candidate_publication_fingerprint;
} NBNumanXExactSensorPacketV2;

typedef struct NBNumanXExactPublicationV2 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint32_t clock_domain;
  uint32_t clock_quantum_nanoseconds;
  uint64_t transaction_fingerprint;
  uint64_t accepted_physics_token_fingerprint;
  uint64_t candidate_publication_fingerprint;
  uint64_t joint_commit_fingerprint;
  uint64_t brain_generation;
  uint64_t committed_timestamp_nanoseconds;
  uint64_t publication_fingerprint;
} NBNumanXExactPublicationV2;

size_t nb_brain_abi_numanx_exact_inbound_authority_v2_size(void);
size_t nb_brain_abi_numanx_exact_accepted_state_proof_v2_size(void);
size_t nb_brain_abi_numanx_exact_accepted_physics_token_v2_size(void);
size_t nb_brain_abi_numanx_exact_sensor_timing_v2_size(void);
size_t nb_brain_abi_numanx_exact_sensor_channel_v2_size(void);
size_t nb_brain_abi_numanx_exact_sensor_packet_v2_size(void);
size_t nb_brain_abi_numanx_exact_publication_v2_size(void);

uint64_t nb_brain_abi_numanx_exact_inbound_authority_v2_fingerprint(
    const NBNumanXExactInboundAuthorityV2 *authority
);

uint32_t nb_brain_abi_validate_numanx_exact_inbound_authority_v2(
    const NBNumanXExactInboundAuthorityV2 *authority,
    const NBJointTransactionTokenV2 *root,
    const NBJointSubstepTokenV2 *substep,
    const NBNumanXMotorCandidateV2 *candidate,
    const NBMotorOutputHeaderV2 *output,
    const float *muscle_excitations,
    const NBNumanXMotorReadyGateGPUV2 *ready_gate
);

uint64_t nb_brain_abi_numanx_exact_physics_state_v2_fingerprint(
    const NBNumanXAcceptedStateProofV2 *proof
);

uint64_t nb_brain_abi_numanx_exact_accepted_state_proof_v2_fingerprint(
    const NBNumanXAcceptedStateProofV2 *proof
);

uint32_t nb_brain_abi_validate_numanx_exact_accepted_state_proof_v2(
    const NBNumanXExactInboundAuthorityV2 *authority,
    const NBNumanXAcceptedStateProofV2 *proof
);

uint64_t nb_brain_abi_numanx_exact_accepted_physics_token_v2_fingerprint(
    const NBNumanXExactAcceptedPhysicsTokenV2 *token
);

uint32_t nb_brain_abi_validate_numanx_exact_accepted_physics_token_v2(
    const NBNumanXAcceptedStateProofV2 *proof,
    const NBNumanXExactAcceptedPhysicsTokenV2 *token
);

uint64_t nb_brain_abi_numanx_exact_sensor_timing_v2_fingerprint(
    const NBNumanXExactSensorTimingV2 *timing
);

uint32_t nb_brain_abi_validate_numanx_exact_sensor_timing_v2(
    const NBNumanXExactSensorTimingV2 *timing
);

uint64_t nb_brain_abi_numanx_exact_sensor_channel_v2_fingerprint(
    const NBNumanXExactSensorChannelV2 *channel
);

uint32_t nb_brain_abi_validate_numanx_exact_sensor_channel_v2(
    const NBNumanXExactSensorChannelV2 *channel,
    const NBNumanXExactSensorTimingV2 *timing
);

uint64_t nb_brain_abi_numanx_exact_sensor_channel_set_v2_fingerprint(
    const NBNumanXExactSensorChannelV2 *channels,
    size_t channel_count
);

uint64_t nb_brain_abi_numanx_exact_sensor_packet_v2_fingerprint(
    const NBNumanXExactSensorPacketV2 *packet
);

uint32_t nb_brain_abi_validate_numanx_exact_sensor_packet_v2(
    const NBNumanXExactInboundAuthorityV2 *authority,
    const NBNumanXAcceptedStateProofV2 *proof,
    const NBNumanXExactAcceptedPhysicsTokenV2 *token,
    const NBNumanXExactSensorTimingV2 *timing,
    const NBNumanXExactSensorChannelV2 *channels,
    size_t channel_count,
    const NBNumanXExactSensorPacketV2 *packet
);

uint64_t nb_brain_abi_numanx_exact_publication_v2_fingerprint(
    const NBNumanXExactPublicationV2 *publication
);

uint32_t nb_brain_abi_validate_numanx_exact_publication_v2(
    const NBNumanXExactAcceptedPhysicsTokenV2 *token,
    const NBNumanXExactSensorPacketV2 *packet,
    const NBNumanXExactPublicationV2 *publication
);

uint32_t nb_brain_abi_validate_numanx_exact_outbound_family_v2(
    const NBNumanXExactInboundAuthorityV2 *authority,
    const NBNumanXAcceptedStateProofV2 *proof,
    const NBNumanXExactAcceptedPhysicsTokenV2 *token,
    const NBNumanXExactSensorTimingV2 *timing,
    const NBNumanXExactSensorChannelV2 *channels,
    size_t channel_count,
    const NBNumanXExactSensorPacketV2 *packet,
    const NBNumanXExactPublicationV2 *publication
);

#if defined(__cplusplus)
static_assert(sizeof(NBNumanXExactInboundAuthorityV2) == 112u);
static_assert(alignof(NBNumanXExactInboundAuthorityV2) == 8u);
static_assert(offsetof(NBNumanXExactInboundAuthorityV2,
                       accepted_brain_timestamp_nanoseconds) == 16u);
static_assert(offsetof(NBNumanXExactInboundAuthorityV2,
                       transaction_fingerprint) == 32u);
static_assert(offsetof(NBNumanXExactInboundAuthorityV2,
                       inbound_authority_fingerprint) == 104u);
static_assert(sizeof(NBNumanXAcceptedStateProofV2) == 160u);
static_assert(alignof(NBNumanXAcceptedStateProofV2) == 16u);
static_assert(offsetof(NBNumanXAcceptedStateProofV2,
                       inboundAuthorityFingerprint) == 144u);
static_assert(offsetof(NBNumanXAcceptedStateProofV2, proofFingerprint) == 152u);
static_assert(sizeof(NBNumanXExactAcceptedPhysicsTokenV2) == 64u);
static_assert(alignof(NBNumanXExactAcceptedPhysicsTokenV2) == 16u);
static_assert(offsetof(NBNumanXExactAcceptedPhysicsTokenV2, clockDomain) == 48u);
static_assert(offsetof(NBNumanXExactAcceptedPhysicsTokenV2, tokenFingerprint) == 56u);
static_assert(sizeof(NBNumanXExactMetalRangeV1) == 48u);
static_assert(sizeof(NBNumanXExactSensorChannelV2) == 144u);
static_assert(offsetof(NBNumanXExactSensorChannelV2, values) == 40u);
static_assert(offsetof(NBNumanXExactSensorChannelV2, validity) == 88u);
static_assert(offsetof(NBNumanXExactSensorChannelV2, channel_fingerprint) == 136u);
static_assert(sizeof(NBNumanXExactSensorTimingV2) == 56u);
static_assert(offsetof(NBNumanXExactSensorTimingV2, timing_fingerprint) == 48u);
static_assert(sizeof(NBNumanXExactSensorPacketV2) == 128u);
static_assert(offsetof(NBNumanXExactSensorPacketV2,
                       candidate_publication_fingerprint) == 120u);
static_assert(sizeof(NBNumanXExactPublicationV2) == 72u);
static_assert(offsetof(NBNumanXExactPublicationV2, publication_fingerprint) == 64u);
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
_Static_assert(sizeof(NBNumanXExactInboundAuthorityV2) == 112u,
               "exact inbound authority ABI");
_Static_assert(_Alignof(NBNumanXExactInboundAuthorityV2) == 8u,
               "exact inbound authority alignment");
_Static_assert(offsetof(NBNumanXExactInboundAuthorityV2,
                        accepted_brain_timestamp_nanoseconds) == 16u,
               "exact inbound timestamp offset");
_Static_assert(offsetof(NBNumanXExactInboundAuthorityV2,
                        transaction_fingerprint) == 32u,
               "exact inbound transaction offset");
_Static_assert(offsetof(NBNumanXExactInboundAuthorityV2,
                        inbound_authority_fingerprint) == 104u,
               "exact inbound fingerprint offset");
_Static_assert(sizeof(NBNumanXAcceptedStateProofV2) == 160u,
               "exact accepted proof ABI");
_Static_assert(_Alignof(NBNumanXAcceptedStateProofV2) == 16u,
               "exact accepted proof alignment");
_Static_assert(offsetof(NBNumanXAcceptedStateProofV2,
                        inboundAuthorityFingerprint) == 144u,
               "exact accepted proof authority offset");
_Static_assert(offsetof(NBNumanXAcceptedStateProofV2,
                        proofFingerprint) == 152u,
               "exact accepted proof fingerprint offset");
_Static_assert(sizeof(NBNumanXExactAcceptedPhysicsTokenV2) == 64u,
               "exact accepted token ABI");
_Static_assert(_Alignof(NBNumanXExactAcceptedPhysicsTokenV2) == 16u,
               "exact accepted token alignment");
_Static_assert(offsetof(NBNumanXExactAcceptedPhysicsTokenV2,
                        clockDomain) == 48u,
               "exact accepted token clock offset");
_Static_assert(offsetof(NBNumanXExactAcceptedPhysicsTokenV2,
                        tokenFingerprint) == 56u,
               "exact accepted token fingerprint offset");
_Static_assert(sizeof(NBNumanXExactMetalRangeV1) == 48u,
               "exact Metal range ABI");
_Static_assert(sizeof(NBNumanXExactSensorChannelV2) == 144u,
               "exact sensor channel ABI");
_Static_assert(offsetof(NBNumanXExactSensorChannelV2, values) == 40u,
               "exact sensor values offset");
_Static_assert(offsetof(NBNumanXExactSensorChannelV2, validity) == 88u,
               "exact sensor validity offset");
_Static_assert(offsetof(NBNumanXExactSensorChannelV2,
                        channel_fingerprint) == 136u,
               "exact sensor channel fingerprint offset");
_Static_assert(sizeof(NBNumanXExactSensorTimingV2) == 56u,
               "exact sensor timing ABI");
_Static_assert(offsetof(NBNumanXExactSensorTimingV2,
                        timing_fingerprint) == 48u,
               "exact sensor timing fingerprint offset");
_Static_assert(sizeof(NBNumanXExactSensorPacketV2) == 128u,
               "exact sensor packet ABI");
_Static_assert(offsetof(NBNumanXExactSensorPacketV2,
                        candidate_publication_fingerprint) == 120u,
               "exact sensor packet fingerprint offset");
_Static_assert(sizeof(NBNumanXExactPublicationV2) == 72u,
               "exact publication ABI");
_Static_assert(offsetof(NBNumanXExactPublicationV2,
                        publication_fingerprint) == 64u,
               "exact publication fingerprint offset");
#endif

#undef NB_NUMANX_EXACT_ALIGN16

#if defined(__cplusplus)
} // extern "C"
#endif

#endif // NUMI_BRAIN_NUMANX_EXACT_OUTBOUND_ABI_H

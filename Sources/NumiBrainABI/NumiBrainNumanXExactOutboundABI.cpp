#include "NumiBrainNumanXExactOutboundABI.h"

#include <cstddef>
#include <cstdint>
#include <limits>
#include <type_traits>

static_assert(std::is_standard_layout_v<NBNumanXExactInboundAuthorityV2>);
static_assert(std::is_standard_layout_v<NBNumanXAcceptedStateProofV2>);
static_assert(std::is_standard_layout_v<NBNumanXExactAcceptedPhysicsTokenV2>);
static_assert(std::is_standard_layout_v<NBNumanXExactSensorChannelV2>);
static_assert(std::is_standard_layout_v<NBNumanXExactSensorTimingV2>);
static_assert(std::is_standard_layout_v<NBNumanXExactSensorPacketV2>);
static_assert(std::is_standard_layout_v<NBNumanXExactPublicationV2>);

namespace {

constexpr std::uint64_t kFNVOffset = 14695981039346656037ull;
constexpr std::uint64_t kFNVPrime = 1099511628211ull;

void mixByte(std::uint64_t &hash, const std::uint8_t byte) noexcept {
  hash ^= static_cast<std::uint64_t>(byte);
  hash *= kFNVPrime;
}

void mixU32(std::uint64_t &hash, const std::uint32_t value) noexcept {
  for (std::uint32_t index = 0; index < 4; ++index) {
    mixByte(hash, static_cast<std::uint8_t>(value >> (index * 8)));
  }
}

void mixU64(std::uint64_t &hash, const std::uint64_t value) noexcept {
  for (std::uint32_t index = 0; index < 8; ++index) {
    mixByte(hash, static_cast<std::uint8_t>(value >> (index * 8)));
  }
}

bool exactClock(const std::uint32_t domain,
                const std::uint32_t quantumNanoseconds) noexcept {
  return domain == NB_PHYSICAL_CLOCK_DOMAIN_EXACT_NANOSECONDS
      && quantumNanoseconds
          == NB_EXACT_NANOSECOND_CLOCK_QUANTUM_NANOSECONDS;
}

bool checkedMultiply(const std::uint64_t lhs, const std::uint64_t rhs,
                     std::uint64_t &result) noexcept {
  if (lhs != 0 && rhs > std::numeric_limits<std::uint64_t>::max() / lhs) {
    return false;
  }
  result = lhs * rhs;
  return true;
}

bool checkedAdd(const std::uint64_t lhs, const std::uint64_t rhs,
                std::uint64_t &result) noexcept {
  if (lhs > std::numeric_limits<std::uint64_t>::max() - rhs) {
    return false;
  }
  result = lhs + rhs;
  return true;
}

bool validModality(const std::uint32_t modality) noexcept {
  switch (modality) {
    case NB_NUMANX_EXACT_MODALITY_VISION_V1:
    case NB_NUMANX_EXACT_MODALITY_AUDITION_V1:
    case NB_NUMANX_EXACT_MODALITY_TOUCH_V1:
    case NB_NUMANX_EXACT_MODALITY_PROPRIOCEPTION_V1:
    case NB_NUMANX_EXACT_MODALITY_VESTIBULAR_V1:
    case NB_NUMANX_EXACT_MODALITY_INTEROCEPTION_V1:
    case NB_NUMANX_EXACT_MODALITY_KINESTHESIA_V1:
      return true;
    default:
      return false;
  }
}

bool validRange(const NBNumanXExactMetalRangeV1 &range,
                const std::uint32_t expectedType,
                const std::uint32_t expectedElementBytes,
                const std::uint64_t expectedBytes) noexcept {
  std::uint64_t offsetEnd = 0;
  std::uint64_t addressEnd = 0;
  return range.abi_version == NB_NUMANX_EXACT_METAL_RANGE_ABI_V1
      && range.struct_size == sizeof(range)
      && range.metal_buffer != nullptr
      && range.gpu_address != 0
      && expectedBytes != 0
      && range.byte_count == expectedBytes
      && range.element_type == expectedType
      && range.element_byte_count == expectedElementBytes
      && range.byte_offset % expectedElementBytes == 0
      && range.gpu_address % expectedElementBytes == 0
      && range.gpu_address >= range.byte_offset
      && checkedAdd(range.byte_offset, range.byte_count, offsetEnd)
      && checkedAdd(range.gpu_address, range.byte_count, addressEnd);
}

bool disjointRanges(const NBNumanXExactMetalRangeV1 &lhs,
                    const NBNumanXExactMetalRangeV1 &rhs) noexcept {
  std::uint64_t lhsEnd = 0;
  std::uint64_t rhsEnd = 0;
  if (lhs.metal_buffer == rhs.metal_buffer) {
    return lhs.gpu_address >= lhs.byte_offset
        && rhs.gpu_address >= rhs.byte_offset
        && lhs.gpu_address - lhs.byte_offset
            == rhs.gpu_address - rhs.byte_offset
        && checkedAdd(lhs.byte_offset, lhs.byte_count, lhsEnd)
        && checkedAdd(rhs.byte_offset, rhs.byte_count, rhsEnd)
        && (lhsEnd <= rhs.byte_offset || rhsEnd <= lhs.byte_offset);
  }
  return checkedAdd(lhs.gpu_address, lhs.byte_count, lhsEnd)
      && checkedAdd(rhs.gpu_address, rhs.byte_count, rhsEnd)
      && (lhsEnd <= rhs.gpu_address || rhsEnd <= lhs.gpu_address);
}

void mixRange(std::uint64_t &hash,
              const NBNumanXExactMetalRangeV1 &range) noexcept {
  mixU32(hash, range.abi_version);
  mixU32(hash, range.struct_size);
  mixU64(hash, static_cast<std::uint64_t>(
      reinterpret_cast<std::uintptr_t>(range.metal_buffer)));
  mixU64(hash, range.gpu_address);
  mixU64(hash, range.byte_offset);
  mixU64(hash, range.byte_count);
  mixU32(hash, range.element_type);
  mixU32(hash, range.element_byte_count);
}

std::uint32_t validateAuthorityRecord(
    const NBNumanXExactInboundAuthorityV2 *authority) noexcept {
  if (authority == nullptr) {
    return NB_NUMANX_EXACT_OUTBOUND_NULL;
  }
  if (authority->abi_version != NB_NUMANX_EXACT_INBOUND_AUTHORITY_ABI_V2
      || authority->struct_size != sizeof(*authority)) {
    return NB_NUMANX_EXACT_OUTBOUND_FORMAT;
  }
  if (!exactClock(authority->clock_domain,
                  authority->clock_quantum_nanoseconds)) {
    return NB_NUMANX_EXACT_OUTBOUND_CLOCK;
  }
  if (authority->transaction_fingerprint == 0
      || authority->substep_fingerprint == 0
      || authority->motor_candidate_fingerprint == 0
      || authority->motor_output_fingerprint == 0
      || authority->motor_profile_fingerprint == 0
      || authority->motor_ready_gate_fingerprint == 0
      || authority->brain_program_fingerprint == 0
      || authority->fast_program_fingerprint == 0
      || authority->decision_gate_fingerprint == 0
      || authority->accepted_brain_timestamp_nanoseconds == 0
      || authority->brain_generation == 0) {
    return NB_NUMANX_EXACT_OUTBOUND_IDENTITY;
  }
  if (authority->inbound_authority_fingerprint == 0
      || authority->inbound_authority_fingerprint
          != nb_brain_abi_numanx_exact_inbound_authority_v2_fingerprint(
              authority)) {
    return NB_NUMANX_EXACT_OUTBOUND_FINGERPRINT;
  }
  return NB_NUMANX_EXACT_OUTBOUND_VALID;
}

std::uint32_t validateProofRecord(
    const NBNumanXAcceptedStateProofV2 *proof) noexcept {
  if (proof == nullptr) {
    return NB_NUMANX_EXACT_OUTBOUND_NULL;
  }
  if (proof->abiVersion != NB_NUMANX_EXACT_ACCEPTED_STATE_PROOF_ABI_V2
      || proof->structSize != sizeof(*proof)
      || proof->status != NB_NUMANX_EXACT_ACCEPTED_STATE_PROOF_VALID) {
    return NB_NUMANX_EXACT_OUTBOUND_FORMAT;
  }
  if (!exactClock(proof->clockDomain, proof->clockQuantumNanoseconds)) {
    return NB_NUMANX_EXACT_OUTBOUND_CLOCK;
  }
  if (proof->transactionFingerprint == 0 || proof->substepFingerprint == 0
      || proof->acceptedTimestampNanoseconds == 0
      || proof->physicsGeneration == 0 || proof->humanStateFingerprint == 0
      || proof->matterStateFingerprint == 0
      || proof->matterSourcePhysicsFingerprint == 0
      || proof->matterDeviceProgramFingerprint == 0
      || proof->stateProofProgramFingerprint == 0
      || proof->adapterProgramFingerprint == 0
      || proof->transactionPolicyFingerprint == 0
      || proof->linearizationEpoch == 0 || proof->slotGeneration == 0
      || proof->motorCandidateFingerprint == 0
      || proof->inboundAuthorityFingerprint == 0) {
    return NB_NUMANX_EXACT_OUTBOUND_IDENTITY;
  }
  if (proof->physicsStateFingerprint == 0
      || proof->physicsStateFingerprint
          != nb_brain_abi_numanx_exact_physics_state_v2_fingerprint(proof)
      || proof->proofFingerprint == 0
      || proof->proofFingerprint
          != nb_brain_abi_numanx_exact_accepted_state_proof_v2_fingerprint(
              proof)) {
    return NB_NUMANX_EXACT_OUTBOUND_FINGERPRINT;
  }
  return NB_NUMANX_EXACT_OUTBOUND_VALID;
}

std::uint32_t validateTokenRecord(
    const NBNumanXExactAcceptedPhysicsTokenV2 *token) noexcept {
  if (token == nullptr) {
    return NB_NUMANX_EXACT_OUTBOUND_NULL;
  }
  if (!exactClock(token->clockDomain, token->clockQuantumNanoseconds)) {
    return NB_NUMANX_EXACT_OUTBOUND_CLOCK;
  }
  if (token->flags != 0) {
    return NB_NUMANX_EXACT_OUTBOUND_FORMAT;
  }
  if (token->transactionFingerprint == 0 || token->substepFingerprint == 0
      || token->physicsStateFingerprint == 0
      || token->acceptedTimestampNanoseconds == 0
      || token->physicsGeneration == 0) {
    return NB_NUMANX_EXACT_OUTBOUND_IDENTITY;
  }
  if (token->tokenFingerprint == 0
      || token->tokenFingerprint
          != nb_brain_abi_numanx_exact_accepted_physics_token_v2_fingerprint(
              token)) {
    return NB_NUMANX_EXACT_OUTBOUND_FINGERPRINT;
  }
  return NB_NUMANX_EXACT_OUTBOUND_VALID;
}

} // namespace

size_t nb_brain_abi_numanx_exact_inbound_authority_v2_size(void) {
  return sizeof(NBNumanXExactInboundAuthorityV2);
}

size_t nb_brain_abi_numanx_exact_accepted_state_proof_v2_size(void) {
  return sizeof(NBNumanXAcceptedStateProofV2);
}

size_t nb_brain_abi_numanx_exact_accepted_physics_token_v2_size(void) {
  return sizeof(NBNumanXExactAcceptedPhysicsTokenV2);
}

size_t nb_brain_abi_numanx_exact_sensor_timing_v2_size(void) {
  return sizeof(NBNumanXExactSensorTimingV2);
}

size_t nb_brain_abi_numanx_exact_sensor_channel_v2_size(void) {
  return sizeof(NBNumanXExactSensorChannelV2);
}

size_t nb_brain_abi_numanx_exact_sensor_packet_v2_size(void) {
  return sizeof(NBNumanXExactSensorPacketV2);
}

size_t nb_brain_abi_numanx_exact_publication_v2_size(void) {
  return sizeof(NBNumanXExactPublicationV2);
}

uint64_t nb_brain_abi_numanx_exact_inbound_authority_v2_fingerprint(
    const NBNumanXExactInboundAuthorityV2 *authority) {
  if (authority == nullptr) {
    return 0;
  }
  std::uint64_t hash = kFNVOffset;
  mixU32(hash, NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_INBOUND_AUTHORITY_V2);
  mixU32(hash, authority->abi_version);
  mixU32(hash, authority->struct_size);
  mixU32(hash, authority->clock_domain);
  mixU32(hash, authority->clock_quantum_nanoseconds);
  mixU64(hash, authority->accepted_brain_timestamp_nanoseconds);
  mixU64(hash, authority->brain_generation);
  mixU64(hash, authority->transaction_fingerprint);
  mixU64(hash, authority->substep_fingerprint);
  mixU64(hash, authority->motor_candidate_fingerprint);
  mixU64(hash, authority->motor_output_fingerprint);
  mixU64(hash, authority->motor_profile_fingerprint);
  mixU64(hash, authority->motor_ready_gate_fingerprint);
  mixU64(hash, authority->brain_program_fingerprint);
  mixU64(hash, authority->fast_program_fingerprint);
  mixU64(hash, authority->decision_gate_fingerprint);
  return hash;
}

uint32_t nb_brain_abi_validate_numanx_exact_inbound_authority_v2(
    const NBNumanXExactInboundAuthorityV2 *authority,
    const NBJointTransactionTokenV2 *root,
    const NBJointSubstepTokenV2 *substep,
    const NBNumanXMotorCandidateV2 *candidate,
    const NBMotorOutputHeaderV2 *output,
    const float *muscle_excitations,
    const NBNumanXMotorReadyGateGPUV2 *readyGate) {
  if (authority == nullptr || root == nullptr || substep == nullptr
      || candidate == nullptr || output == nullptr
      || muscle_excitations == nullptr || readyGate == nullptr) {
    return NB_NUMANX_EXACT_OUTBOUND_NULL;
  }
  const std::uint32_t authorityValidation = validateAuthorityRecord(authority);
  if (authorityValidation != NB_NUMANX_EXACT_OUTBOUND_VALID) {
    return authorityValidation;
  }
  if (!exactClock(root->clock_domain, root->clock_quantum_nanoseconds)
      || substep->clock_domain != root->clock_domain
      || substep->clock_quantum_nanoseconds
          != root->clock_quantum_nanoseconds
      || candidate->clock_domain != root->clock_domain
      || output->clock_domain != root->clock_domain
      || readyGate->clockDomain != root->clock_domain
      || readyGate->clockQuantumNanoseconds
          != root->clock_quantum_nanoseconds
      || authority->clock_domain != root->clock_domain
      || authority->clock_quantum_nanoseconds
          != root->clock_quantum_nanoseconds) {
    return NB_NUMANX_EXACT_OUTBOUND_CLOCK;
  }
  if (nb_brain_abi_validate_joint_transaction_v2(root)
          != NB_JOINT_TRANSACTION_VALID
      || nb_brain_abi_validate_joint_substep_v2(root, substep)
          != NB_JOINT_TRANSACTION_VALID
      || nb_brain_abi_validate_numanx_motor_candidate_v2(
          root, substep, candidate) != NB_NUMANX_MOTOR_CANDIDATE_VALID
      || nb_brain_abi_validate_motor_output_v2(
          candidate, output, muscle_excitations) != NB_MOTOR_OUTPUT_VALID
      || nb_brain_abi_validate_numanx_motor_ready_gate_v2(
          root, substep, candidate, output, readyGate)
          != NB_NUMANX_MOTOR_READY_VALID) {
    return NB_NUMANX_EXACT_OUTBOUND_RELATION;
  }
  if (authority->transaction_fingerprint != root->transaction_fingerprint
      || authority->substep_fingerprint != substep->substep_fingerprint
      || authority->motor_candidate_fingerprint
          != candidate->candidate_fingerprint
      || authority->motor_output_fingerprint != output->output_fingerprint
      || authority->motor_profile_fingerprint
          != candidate->motor_profile_fingerprint
      || authority->motor_profile_fingerprint != output->profile_fingerprint
      || authority->motor_ready_gate_fingerprint
          != readyGate->gateFingerprint
      || authority->brain_program_fingerprint
          != readyGate->brainProgramFingerprint
      || authority->fast_program_fingerprint
          != readyGate->fastProgramFingerprint
      || authority->decision_gate_fingerprint
          != readyGate->decisionGateFingerprint) {
    return NB_NUMANX_EXACT_OUTBOUND_RELATION;
  }
  if (authority->accepted_brain_timestamp_nanoseconds
          != candidate->accepted_brain_timestamp_nanoseconds
      || authority->accepted_brain_timestamp_nanoseconds
          != output->timestamp_nanoseconds
      || authority->accepted_brain_timestamp_nanoseconds
          != readyGate->acceptedBrainTimestampNanoseconds) {
    return NB_NUMANX_EXACT_OUTBOUND_TIME_ORDER;
  }
  if (authority->brain_generation != candidate->brain_generation
      || authority->brain_generation != output->brain_generation
      || authority->brain_generation != readyGate->brainGeneration) {
    return NB_NUMANX_EXACT_OUTBOUND_GENERATION;
  }
  return NB_NUMANX_EXACT_OUTBOUND_VALID;
}

uint64_t nb_brain_abi_numanx_exact_physics_state_v2_fingerprint(
    const NBNumanXAcceptedStateProofV2 *proof) {
  if (proof == nullptr) {
    return 0;
  }
  std::uint64_t hash = kFNVOffset;
  mixU32(hash, NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_PHYSICS_STATE_V2);
  mixU32(hash, NB_NUMANX_EXACT_ACCEPTED_STATE_PROOF_ABI_V2);
  mixU32(hash, proof->clockDomain);
  mixU32(hash, proof->clockQuantumNanoseconds);
  mixU64(hash, proof->humanStateFingerprint);
  mixU64(hash, proof->matterStateFingerprint);
  mixU64(hash, proof->matterSourcePhysicsFingerprint);
  mixU64(hash, proof->matterDeviceProgramFingerprint);
  mixU64(hash, proof->stateProofProgramFingerprint);
  mixU64(hash, proof->adapterProgramFingerprint);
  mixU64(hash, proof->transactionPolicyFingerprint);
  mixU64(hash, proof->motorCandidateFingerprint);
  mixU64(hash, proof->inboundAuthorityFingerprint);
  mixU64(hash, proof->transactionFingerprint);
  mixU64(hash, proof->substepFingerprint);
  mixU64(hash, proof->acceptedTimestampNanoseconds);
  mixU64(hash, proof->physicsGeneration);
  mixU32(hash, proof->environment);
  return hash;
}

uint64_t nb_brain_abi_numanx_exact_accepted_state_proof_v2_fingerprint(
    const NBNumanXAcceptedStateProofV2 *proof) {
  if (proof == nullptr) {
    return 0;
  }
  std::uint64_t hash = kFNVOffset;
  mixU32(hash, NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_ACCEPTED_STATE_PROOF_V2);
  mixU32(hash, proof->abiVersion);
  mixU32(hash, proof->structSize);
  mixU32(hash, proof->status);
  mixU32(hash, proof->environment);
  mixU64(hash, proof->transactionFingerprint);
  mixU64(hash, proof->substepFingerprint);
  mixU64(hash, proof->acceptedTimestampNanoseconds);
  mixU64(hash, proof->physicsGeneration);
  mixU32(hash, proof->clockDomain);
  mixU32(hash, proof->clockQuantumNanoseconds);
  mixU64(hash, proof->humanStateFingerprint);
  mixU64(hash, proof->matterStateFingerprint);
  mixU64(hash, proof->physicsStateFingerprint);
  mixU64(hash, proof->matterSourcePhysicsFingerprint);
  mixU64(hash, proof->matterDeviceProgramFingerprint);
  mixU64(hash, proof->stateProofProgramFingerprint);
  mixU64(hash, proof->adapterProgramFingerprint);
  mixU64(hash, proof->transactionPolicyFingerprint);
  mixU64(hash, proof->linearizationEpoch);
  mixU64(hash, proof->slotGeneration);
  mixU64(hash, proof->motorCandidateFingerprint);
  mixU64(hash, proof->inboundAuthorityFingerprint);
  return hash;
}

uint32_t nb_brain_abi_validate_numanx_exact_accepted_state_proof_v2(
    const NBNumanXExactInboundAuthorityV2 *authority,
    const NBNumanXAcceptedStateProofV2 *proof) {
  if (authority == nullptr || proof == nullptr) {
    return NB_NUMANX_EXACT_OUTBOUND_NULL;
  }
  const std::uint32_t authorityValidation = validateAuthorityRecord(authority);
  if (authorityValidation != NB_NUMANX_EXACT_OUTBOUND_VALID) {
    return authorityValidation;
  }
  const std::uint32_t proofValidation = validateProofRecord(proof);
  if (proofValidation != NB_NUMANX_EXACT_OUTBOUND_VALID) {
    return proofValidation;
  }
  if (proof->clockDomain != authority->clock_domain
      || proof->clockQuantumNanoseconds
          != authority->clock_quantum_nanoseconds) {
    return NB_NUMANX_EXACT_OUTBOUND_CLOCK;
  }
  if (proof->transactionFingerprint != authority->transaction_fingerprint
      || proof->substepFingerprint != authority->substep_fingerprint
      || proof->motorCandidateFingerprint
          != authority->motor_candidate_fingerprint
      || proof->inboundAuthorityFingerprint
          != authority->inbound_authority_fingerprint) {
    return NB_NUMANX_EXACT_OUTBOUND_RELATION;
  }
  return NB_NUMANX_EXACT_OUTBOUND_VALID;
}

uint64_t nb_brain_abi_numanx_exact_accepted_physics_token_v2_fingerprint(
    const NBNumanXExactAcceptedPhysicsTokenV2 *token) {
  if (token == nullptr) {
    return 0;
  }
  std::uint64_t hash = kFNVOffset;
  mixU32(hash, NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_ACCEPTED_PHYSICS_TOKEN_V2);
  mixU32(hash, NB_NUMANX_EXACT_ACCEPTED_PHYSICS_TOKEN_VERSION_V2);
  mixU64(hash, token->transactionFingerprint);
  mixU64(hash, token->substepFingerprint);
  mixU64(hash, token->physicsStateFingerprint);
  mixU64(hash, token->acceptedTimestampNanoseconds);
  mixU64(hash, token->physicsGeneration);
  mixU32(hash, token->environmentIdentifier);
  mixU32(hash, token->flags);
  mixU32(hash, token->clockDomain);
  mixU32(hash, token->clockQuantumNanoseconds);
  return hash;
}

uint32_t nb_brain_abi_validate_numanx_exact_accepted_physics_token_v2(
    const NBNumanXAcceptedStateProofV2 *proof,
    const NBNumanXExactAcceptedPhysicsTokenV2 *token) {
  if (proof == nullptr || token == nullptr) {
    return NB_NUMANX_EXACT_OUTBOUND_NULL;
  }
  const std::uint32_t proofValidation = validateProofRecord(proof);
  if (proofValidation != NB_NUMANX_EXACT_OUTBOUND_VALID) {
    return proofValidation;
  }
  const std::uint32_t tokenValidation = validateTokenRecord(token);
  if (tokenValidation != NB_NUMANX_EXACT_OUTBOUND_VALID) {
    return tokenValidation;
  }
  if (token->clockDomain != proof->clockDomain
      || token->clockQuantumNanoseconds != proof->clockQuantumNanoseconds) {
    return NB_NUMANX_EXACT_OUTBOUND_CLOCK;
  }
  if (token->transactionFingerprint != proof->transactionFingerprint
      || token->substepFingerprint != proof->substepFingerprint
      || token->physicsStateFingerprint != proof->physicsStateFingerprint
      || token->environmentIdentifier != proof->environment) {
    return NB_NUMANX_EXACT_OUTBOUND_RELATION;
  }
  if (token->acceptedTimestampNanoseconds
          != proof->acceptedTimestampNanoseconds) {
    return NB_NUMANX_EXACT_OUTBOUND_TIME_ORDER;
  }
  if (token->physicsGeneration != proof->physicsGeneration) {
    return NB_NUMANX_EXACT_OUTBOUND_GENERATION;
  }
  return NB_NUMANX_EXACT_OUTBOUND_VALID;
}

uint64_t nb_brain_abi_numanx_exact_sensor_timing_v2_fingerprint(
    const NBNumanXExactSensorTimingV2 *timing) {
  if (timing == nullptr) {
    return 0;
  }
  std::uint64_t hash = kFNVOffset;
  mixU32(hash, NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_SENSOR_TIMING_V2);
  mixU32(hash, timing->abi_version);
  mixU32(hash, timing->struct_size);
  mixU64(hash, timing->capture_timestamp_nanoseconds);
  mixU64(hash, timing->delivery_timestamp_nanoseconds);
  mixU64(hash, timing->latency_nanoseconds);
  mixU64(hash, timing->sample_interval_nanoseconds);
  mixU32(hash, timing->clock_domain);
  mixU32(hash, timing->clock_quantum_nanoseconds);
  return hash;
}

uint32_t nb_brain_abi_validate_numanx_exact_sensor_timing_v2(
    const NBNumanXExactSensorTimingV2 *timing) {
  if (timing == nullptr) {
    return NB_NUMANX_EXACT_OUTBOUND_NULL;
  }
  if (timing->abi_version != NB_NUMANX_EXACT_SENSOR_TIMING_ABI_V2
      || timing->struct_size != sizeof(*timing)) {
    return NB_NUMANX_EXACT_OUTBOUND_FORMAT;
  }
  if (!exactClock(timing->clock_domain,
                  timing->clock_quantum_nanoseconds)) {
    return NB_NUMANX_EXACT_OUTBOUND_CLOCK;
  }
  if (timing->delivery_timestamp_nanoseconds
          <= timing->capture_timestamp_nanoseconds
      || timing->latency_nanoseconds
          != timing->delivery_timestamp_nanoseconds
              - timing->capture_timestamp_nanoseconds
      || timing->sample_interval_nanoseconds == 0) {
    return NB_NUMANX_EXACT_OUTBOUND_TIME_ORDER;
  }
  if (timing->timing_fingerprint == 0
      || timing->timing_fingerprint
          != nb_brain_abi_numanx_exact_sensor_timing_v2_fingerprint(timing)) {
    return NB_NUMANX_EXACT_OUTBOUND_FINGERPRINT;
  }
  return NB_NUMANX_EXACT_OUTBOUND_VALID;
}

uint64_t nb_brain_abi_numanx_exact_sensor_channel_v2_fingerprint(
    const NBNumanXExactSensorChannelV2 *channel) {
  if (channel == nullptr) {
    return 0;
  }
  std::uint64_t hash = kFNVOffset;
  mixU32(hash, NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_SENSOR_CHANNEL_V2);
  mixU32(hash, channel->abi_version);
  mixU32(hash, channel->struct_size);
  mixU32(hash, channel->modality);
  mixU32(hash, channel->flags);
  mixU64(hash, channel->receptor_timestamp_nanoseconds);
  mixU32(hash, channel->clock_domain);
  mixU32(hash, channel->clock_quantum_nanoseconds);
  mixU32(hash, channel->receptor_count);
  mixU32(hash, channel->feature_dimension);
  mixRange(hash, channel->values);
  mixRange(hash, channel->validity);
  return hash;
}

uint32_t nb_brain_abi_validate_numanx_exact_sensor_channel_v2(
    const NBNumanXExactSensorChannelV2 *channel,
    const NBNumanXExactSensorTimingV2 *timing) {
  if (channel == nullptr || timing == nullptr) {
    return NB_NUMANX_EXACT_OUTBOUND_NULL;
  }
  const std::uint32_t timingValidation =
      nb_brain_abi_validate_numanx_exact_sensor_timing_v2(timing);
  if (timingValidation != NB_NUMANX_EXACT_OUTBOUND_VALID) {
    return timingValidation;
  }
  if (channel->abi_version != NB_NUMANX_EXACT_SENSOR_CHANNEL_ABI_V2
      || channel->struct_size != sizeof(*channel)
      || channel->flags
          != NB_NUMANX_EXACT_SENSOR_CHANNEL_HAS_VALIDITY_V1
      || !validModality(channel->modality)) {
    return NB_NUMANX_EXACT_OUTBOUND_FORMAT;
  }
  if (!exactClock(channel->clock_domain,
                  channel->clock_quantum_nanoseconds)
      || channel->clock_domain != timing->clock_domain
      || channel->clock_quantum_nanoseconds
          != timing->clock_quantum_nanoseconds) {
    return NB_NUMANX_EXACT_OUTBOUND_CLOCK;
  }
  if (channel->receptor_timestamp_nanoseconds
          != timing->capture_timestamp_nanoseconds) {
    return NB_NUMANX_EXACT_OUTBOUND_TIME_ORDER;
  }
  if (channel->receptor_count == 0 || channel->feature_dimension == 0) {
    return NB_NUMANX_EXACT_OUTBOUND_RANGE;
  }
  std::uint64_t valueElements = 0;
  std::uint64_t valueBytes = 0;
  std::uint64_t validityBytes = 0;
  if (!checkedMultiply(channel->receptor_count, channel->feature_dimension,
                       valueElements)
      || !checkedMultiply(valueElements, sizeof(float), valueBytes)
      || !checkedMultiply(channel->receptor_count, sizeof(std::uint32_t),
                          validityBytes)) {
    return NB_NUMANX_EXACT_OUTBOUND_OVERFLOW;
  }
  if (!validRange(channel->values, NB_NUMANX_EXACT_ELEMENT_FLOAT32_V1,
                  sizeof(float), valueBytes)
      || !validRange(channel->validity, NB_NUMANX_EXACT_ELEMENT_UINT32_V1,
                     sizeof(std::uint32_t), validityBytes)
      || !disjointRanges(channel->values, channel->validity)) {
    return NB_NUMANX_EXACT_OUTBOUND_RANGE;
  }
  if (channel->channel_fingerprint == 0
      || channel->channel_fingerprint
          != nb_brain_abi_numanx_exact_sensor_channel_v2_fingerprint(
              channel)) {
    return NB_NUMANX_EXACT_OUTBOUND_FINGERPRINT;
  }
  return NB_NUMANX_EXACT_OUTBOUND_VALID;
}

uint64_t nb_brain_abi_numanx_exact_sensor_channel_set_v2_fingerprint(
    const NBNumanXExactSensorChannelV2 *channels,
    const size_t channelCount) {
  if (channels == nullptr || channelCount == 0
      || channelCount > NB_NUMANX_EXACT_MAX_SENSOR_CHANNELS_V2) {
    return 0;
  }
  std::uint64_t hash = kFNVOffset;
  mixU32(hash, NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_SENSOR_CHANNEL_SET_V2);
  mixU32(hash, NB_NUMANX_EXACT_SENSOR_PACKET_ABI_V2);
  mixU32(hash, static_cast<std::uint32_t>(channelCount));
  for (size_t index = 0; index < channelCount; ++index) {
    mixU64(hash, channels[index].channel_fingerprint);
  }
  return hash;
}

uint64_t nb_brain_abi_numanx_exact_sensor_packet_v2_fingerprint(
    const NBNumanXExactSensorPacketV2 *packet) {
  if (packet == nullptr) {
    return 0;
  }
  std::uint64_t hash = kFNVOffset;
  mixU32(hash, NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_SENSOR_PACKET_V2);
  mixU32(hash, packet->abi_version);
  mixU32(hash, packet->struct_size);
  mixU32(hash, packet->clock_domain);
  mixU32(hash, packet->clock_quantum_nanoseconds);
  mixU32(hash, packet->channel_count);
  mixU32(hash, packet->channel_capacity);
  mixU64(hash, packet->transaction_fingerprint);
  mixU64(hash, packet->substep_fingerprint);
  mixU64(hash, packet->accepted_physics_token_fingerprint);
  mixU64(hash, packet->inbound_authority_fingerprint);
  mixU64(hash, packet->human_io_program_fingerprint);
  mixU64(hash, packet->sensor_fingerprint);
  mixU64(hash, packet->transaction_instance_fingerprint);
  mixU64(hash, packet->sensor_generation);
  mixU64(hash, packet->accepted_brain_generation);
  mixU64(hash, packet->device_registry_id);
  mixU64(hash, packet->timing_fingerprint);
  mixU64(hash, packet->channel_set_fingerprint);
  return hash;
}

uint32_t nb_brain_abi_validate_numanx_exact_sensor_packet_v2(
    const NBNumanXExactInboundAuthorityV2 *authority,
    const NBNumanXAcceptedStateProofV2 *proof,
    const NBNumanXExactAcceptedPhysicsTokenV2 *token,
    const NBNumanXExactSensorTimingV2 *timing,
    const NBNumanXExactSensorChannelV2 *channels,
    const size_t channelCount,
    const NBNumanXExactSensorPacketV2 *packet) {
  if (authority == nullptr || proof == nullptr || token == nullptr
      || timing == nullptr || channels == nullptr || packet == nullptr) {
    return NB_NUMANX_EXACT_OUTBOUND_NULL;
  }
  std::uint32_t validation =
      nb_brain_abi_validate_numanx_exact_accepted_state_proof_v2(
          authority, proof);
  if (validation != NB_NUMANX_EXACT_OUTBOUND_VALID) {
    return validation;
  }
  validation = nb_brain_abi_validate_numanx_exact_accepted_physics_token_v2(
      proof, token);
  if (validation != NB_NUMANX_EXACT_OUTBOUND_VALID) {
    return validation;
  }
  validation = nb_brain_abi_validate_numanx_exact_sensor_timing_v2(timing);
  if (validation != NB_NUMANX_EXACT_OUTBOUND_VALID) {
    return validation;
  }
  if (channelCount == 0
      || channelCount > NB_NUMANX_EXACT_MAX_SENSOR_CHANNELS_V2
      || packet->abi_version != NB_NUMANX_EXACT_SENSOR_PACKET_ABI_V2
      || packet->struct_size != sizeof(*packet)
      || packet->channel_count != channelCount
      || packet->channel_capacity != NB_NUMANX_EXACT_MAX_SENSOR_CHANNELS_V2) {
    return NB_NUMANX_EXACT_OUTBOUND_FORMAT;
  }
  if (!exactClock(packet->clock_domain,
                  packet->clock_quantum_nanoseconds)
      || packet->clock_domain != token->clockDomain
      || packet->clock_quantum_nanoseconds != token->clockQuantumNanoseconds) {
    return NB_NUMANX_EXACT_OUTBOUND_CLOCK;
  }
  if (timing->capture_timestamp_nanoseconds
          != authority->accepted_brain_timestamp_nanoseconds
      || timing->delivery_timestamp_nanoseconds
          != token->acceptedTimestampNanoseconds) {
    return NB_NUMANX_EXACT_OUTBOUND_TIME_ORDER;
  }
  if (packet->transaction_fingerprint != proof->transactionFingerprint
      || packet->substep_fingerprint != proof->substepFingerprint
      || packet->accepted_physics_token_fingerprint != token->tokenFingerprint
      || packet->inbound_authority_fingerprint
          != authority->inbound_authority_fingerprint
      || packet->timing_fingerprint != timing->timing_fingerprint) {
    return NB_NUMANX_EXACT_OUTBOUND_RELATION;
  }
  if (packet->human_io_program_fingerprint == 0
      || packet->sensor_fingerprint == 0
      || packet->transaction_instance_fingerprint == 0
      || packet->sensor_generation == 0 || packet->device_registry_id == 0) {
    return NB_NUMANX_EXACT_OUTBOUND_IDENTITY;
  }
  if (packet->accepted_brain_generation != authority->brain_generation) {
    return NB_NUMANX_EXACT_OUTBOUND_GENERATION;
  }
  std::uint32_t previousModality = 0;
  for (size_t index = 0; index < channelCount; ++index) {
    validation = nb_brain_abi_validate_numanx_exact_sensor_channel_v2(
        &channels[index], timing);
    if (validation != NB_NUMANX_EXACT_OUTBOUND_VALID) {
      return validation;
    }
    if (channels[index].modality <= previousModality) {
      return NB_NUMANX_EXACT_OUTBOUND_ORDER;
    }
    for (size_t previous = 0; previous < index; ++previous) {
      if (!disjointRanges(channels[index].values, channels[previous].values)
          || !disjointRanges(channels[index].values,
                             channels[previous].validity)
          || !disjointRanges(channels[index].validity,
                             channels[previous].values)
          || !disjointRanges(channels[index].validity,
                             channels[previous].validity)) {
        return NB_NUMANX_EXACT_OUTBOUND_RANGE;
      }
    }
    previousModality = channels[index].modality;
  }
  if (packet->channel_set_fingerprint == 0
      || packet->channel_set_fingerprint
          != nb_brain_abi_numanx_exact_sensor_channel_set_v2_fingerprint(
              channels, channelCount)
      || packet->candidate_publication_fingerprint == 0
      || packet->candidate_publication_fingerprint
          != nb_brain_abi_numanx_exact_sensor_packet_v2_fingerprint(packet)) {
    return NB_NUMANX_EXACT_OUTBOUND_FINGERPRINT;
  }
  return NB_NUMANX_EXACT_OUTBOUND_VALID;
}

uint64_t nb_brain_abi_numanx_exact_publication_v2_fingerprint(
    const NBNumanXExactPublicationV2 *publication) {
  if (publication == nullptr) {
    return 0;
  }
  std::uint64_t hash = kFNVOffset;
  mixU32(hash, NB_NUMANX_FINGERPRINT_DOMAIN_EXACT_PUBLICATION_V2);
  mixU32(hash, publication->abi_version);
  mixU32(hash, publication->struct_size);
  mixU32(hash, publication->clock_domain);
  mixU32(hash, publication->clock_quantum_nanoseconds);
  mixU64(hash, publication->transaction_fingerprint);
  mixU64(hash, publication->accepted_physics_token_fingerprint);
  mixU64(hash, publication->candidate_publication_fingerprint);
  mixU64(hash, publication->joint_commit_fingerprint);
  mixU64(hash, publication->brain_generation);
  mixU64(hash, publication->committed_timestamp_nanoseconds);
  return hash;
}

uint32_t nb_brain_abi_validate_numanx_exact_publication_v2(
    const NBNumanXExactAcceptedPhysicsTokenV2 *token,
    const NBNumanXExactSensorPacketV2 *packet,
    const NBNumanXExactPublicationV2 *publication) {
  if (token == nullptr || packet == nullptr || publication == nullptr) {
    return NB_NUMANX_EXACT_OUTBOUND_NULL;
  }
  const std::uint32_t tokenValidation = validateTokenRecord(token);
  if (tokenValidation != NB_NUMANX_EXACT_OUTBOUND_VALID) {
    return tokenValidation;
  }
  if (publication->abi_version != NB_NUMANX_EXACT_PUBLICATION_ABI_V2
      || publication->struct_size != sizeof(*publication)) {
    return NB_NUMANX_EXACT_OUTBOUND_FORMAT;
  }
  if (!exactClock(publication->clock_domain,
                  publication->clock_quantum_nanoseconds)
      || publication->clock_domain != token->clockDomain
      || publication->clock_quantum_nanoseconds
          != token->clockQuantumNanoseconds) {
    return NB_NUMANX_EXACT_OUTBOUND_CLOCK;
  }
  if (publication->transaction_fingerprint != token->transactionFingerprint
      || publication->accepted_physics_token_fingerprint
          != token->tokenFingerprint
      || publication->candidate_publication_fingerprint
          != packet->candidate_publication_fingerprint) {
    return NB_NUMANX_EXACT_OUTBOUND_RELATION;
  }
  if (publication->joint_commit_fingerprint == 0) {
    return NB_NUMANX_EXACT_OUTBOUND_IDENTITY;
  }
  if (packet->candidate_publication_fingerprint == 0
      || packet->candidate_publication_fingerprint
          != nb_brain_abi_numanx_exact_sensor_packet_v2_fingerprint(packet)) {
    return NB_NUMANX_EXACT_OUTBOUND_FINGERPRINT;
  }
  if (publication->brain_generation == 0
      || publication->brain_generation != packet->accepted_brain_generation) {
    return NB_NUMANX_EXACT_OUTBOUND_GENERATION;
  }
  if (publication->committed_timestamp_nanoseconds
          != token->acceptedTimestampNanoseconds) {
    return NB_NUMANX_EXACT_OUTBOUND_TIME_ORDER;
  }
  if (publication->publication_fingerprint == 0
      || publication->publication_fingerprint
          != nb_brain_abi_numanx_exact_publication_v2_fingerprint(
              publication)) {
    return NB_NUMANX_EXACT_OUTBOUND_FINGERPRINT;
  }
  return NB_NUMANX_EXACT_OUTBOUND_VALID;
}

uint32_t nb_brain_abi_validate_numanx_exact_outbound_family_v2(
    const NBNumanXExactInboundAuthorityV2 *authority,
    const NBNumanXAcceptedStateProofV2 *proof,
    const NBNumanXExactAcceptedPhysicsTokenV2 *token,
    const NBNumanXExactSensorTimingV2 *timing,
    const NBNumanXExactSensorChannelV2 *channels,
    const size_t channelCount,
    const NBNumanXExactSensorPacketV2 *packet,
    const NBNumanXExactPublicationV2 *publication) {
  const std::uint32_t packetValidation =
      nb_brain_abi_validate_numanx_exact_sensor_packet_v2(
          authority, proof, token, timing, channels, channelCount, packet);
  if (packetValidation != NB_NUMANX_EXACT_OUTBOUND_VALID) {
    return packetValidation;
  }
  return nb_brain_abi_validate_numanx_exact_publication_v2(
      token, packet, publication);
}

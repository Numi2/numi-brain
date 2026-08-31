#include <metal_stdlib>
using namespace metal;

constant uint NB_ACCEPTED_PHYSICS_GATE_VERSION = 1u;
constant uint NB_ACCEPTED_PHYSICS_GATE_VALID = 1u;
constant uint NB_ACCEPTED_PHYSICS_GATE_MISMATCH = 2u;
constant uint NB_JOINT_TRANSACTION_VERSION = 1u;
constant ulong NB_FNV_OFFSET = 14695981039346656037ul;
constant ulong NB_FNV_PRIME = 1099511628211ul;

struct NBAcceptedPhysicsStateToken {
  ulong transaction_fingerprint;
  ulong substep_fingerprint;
  ulong physics_state_fingerprint;
  ulong accepted_timestamp_microseconds;
  ulong physics_generation;
  uint environment_identifier;
  uint flags;
  ulong reserved;
  ulong token_fingerprint;
};

struct NBAcceptedPhysicsGateExpectation {
  ulong transaction_fingerprint;
  ulong substep_fingerprint;
  ulong accepted_timestamp_microseconds;
  ulong physics_generation;
  uint environment_identifier;
  uint flags;
  ulong reserved_0;
  ulong reserved_1;
  ulong reserved_2;
};

struct NBAcceptedPhysicsGateResult {
  uint version;
  uint status;
  ulong expected_transaction_fingerprint;
  ulong observed_transaction_fingerprint;
  ulong expected_substep_fingerprint;
  ulong observed_substep_fingerprint;
  ulong computed_token_fingerprint;
  ulong observed_token_fingerprint;
  ulong reserved;
  NBAcceptedPhysicsStateToken accepted_token;
};

struct NBGatedCopyUniforms {
  uint word_count;
  uint reserved_0;
  uint reserved_1;
  uint reserved_2;
};

static_assert(sizeof(NBAcceptedPhysicsStateToken) == 64);
static_assert(sizeof(NBAcceptedPhysicsGateExpectation) == 64);
static_assert(sizeof(NBAcceptedPhysicsGateResult) == 128);
static_assert(sizeof(NBGatedCopyUniforms) == 16);

inline void nb_fnv_mix_uint(thread ulong &hash, uint value) {
  for (uint byte_index = 0u; byte_index < 4u; ++byte_index) {
    hash ^= ulong((value >> (byte_index * 8u)) & 0xffu);
    hash *= NB_FNV_PRIME;
  }
}

inline void nb_fnv_mix_ulong(thread ulong &hash, ulong value) {
  for (uint byte_index = 0u; byte_index < 8u; ++byte_index) {
    hash ^= (value >> (byte_index * 8u)) & 0xfful;
    hash *= NB_FNV_PRIME;
  }
}

inline ulong nb_accepted_token_fingerprint(
  thread const NBAcceptedPhysicsStateToken &token)
{
  ulong hash = NB_FNV_OFFSET;
  nb_fnv_mix_uint(hash, NB_JOINT_TRANSACTION_VERSION);
  nb_fnv_mix_ulong(hash, token.transaction_fingerprint);
  nb_fnv_mix_ulong(hash, token.substep_fingerprint);
  nb_fnv_mix_ulong(hash, token.physics_state_fingerprint);
  nb_fnv_mix_ulong(hash, token.accepted_timestamp_microseconds);
  nb_fnv_mix_ulong(hash, token.physics_generation);
  nb_fnv_mix_uint(hash, token.environment_identifier);
  nb_fnv_mix_uint(hash, token.flags);
  nb_fnv_mix_ulong(hash, token.reserved);
  return hash;
}

kernel void validate_accepted_physics_gate(
  device const NBAcceptedPhysicsStateToken *observed [[buffer(0)]],
  constant NBAcceptedPhysicsGateExpectation &expected [[buffer(1)]],
  device NBAcceptedPhysicsGateResult *result [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u) return;
  const NBAcceptedPhysicsStateToken value = observed[0];
  const ulong computed_fingerprint = nb_accepted_token_fingerprint(value);
  const bool exact_relation =
    value.transaction_fingerprint == expected.transaction_fingerprint
    && value.substep_fingerprint == expected.substep_fingerprint
    && value.accepted_timestamp_microseconds
      == expected.accepted_timestamp_microseconds
    && value.physics_generation == expected.physics_generation
    && value.environment_identifier == expected.environment_identifier
    && value.flags == expected.flags
    && value.reserved == 0ul
    && value.physics_state_fingerprint != 0ul
    && value.token_fingerprint != 0ul
    && value.token_fingerprint == computed_fingerprint;
  NBAcceptedPhysicsGateResult output = {};
  output.version = NB_ACCEPTED_PHYSICS_GATE_VERSION;
  output.status = exact_relation
    ? NB_ACCEPTED_PHYSICS_GATE_VALID
    : NB_ACCEPTED_PHYSICS_GATE_MISMATCH;
  output.expected_transaction_fingerprint = expected.transaction_fingerprint;
  output.observed_transaction_fingerprint = value.transaction_fingerprint;
  output.expected_substep_fingerprint = expected.substep_fingerprint;
  output.observed_substep_fingerprint = value.substep_fingerprint;
  output.computed_token_fingerprint = computed_fingerprint;
  output.observed_token_fingerprint = value.token_fingerprint;
  output.reserved = 0ul;
  if (exact_relation) output.accepted_token = value;
  result[0] = output;
}

kernel void copy_if_accepted_physics_gate(
  device const uint *source [[buffer(0)]],
  device uint *destination [[buffer(1)]],
  device const NBAcceptedPhysicsGateResult *gate [[buffer(2)]],
  constant NBGatedCopyUniforms &uniforms [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  if (gate->version != NB_ACCEPTED_PHYSICS_GATE_VERSION
      || gate->status != NB_ACCEPTED_PHYSICS_GATE_VALID
      || gid >= uniforms.word_count) {
    return;
  }
  destination[gid] = source[gid];
}

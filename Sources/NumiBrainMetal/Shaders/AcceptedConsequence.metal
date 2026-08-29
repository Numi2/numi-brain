#include <metal_stdlib>
using namespace metal;

constant uint NB_ACCEPTED_STATE_VALID = 1u;
constant uint NB_WORLD_RECEPTOR_DIMENSION = 128u;
constant uint NB_WORLD_HEAD_COUNT = 5u;

struct NBAcceptedConsequenceUniforms {
  ulong target_timestamp_microseconds;
  ulong delta_microseconds;
  ulong observation_offset;
  ulong event_queue_offset;
  ulong body_belief_offset;
  ulong muscle_belief_offset;
  ulong physiology_offset;
  ulong world_model_offset;
  ulong neuromodulation_offset;
  ulong fast_plasticity_offset;
  ulong workspace_content_offset;
  ulong workspace_metadata_offset;
  ulong control_header_offset;
  ulong motor_command_offset;
  ulong cerebellar_offset;
  ulong cerebellar_expert_memory_offset;
  ulong somatic_output_offset;
  ulong physics_state_fingerprint;
  uint observation_count;
  uint body_count;
  uint muscle_count;
  uint physiology_count;
  uint world_model_count;
  uint neuromodulator_count;
  uint fast_plasticity_count;
  uint workspace_capacity;
  uint workspace_dimension;
  uint active_cerebellar_count;
  uint actuator_count;
  uint event_capacity;
  uint proprioception_offset;
  uint proprioception_count;
  uint touch_offset;
  uint touch_count;
  uint vestibular_offset;
  uint vestibular_count;
  uint interoception_offset;
  uint interoception_count;
  float belief_gain;
  float world_correction_gain;
  float cerebellar_learning_rate;
  float plasticity_learning_rate;
};

struct NBEventQueueHeader {
  atomic_uint count;
  uint capacity;
  atomic_uint overflow_count;
  uint flags;
  ulong target_timestamp_microseconds;
  ulong generation;
};

struct NBReceptorEventRecord {
  uint environment_identifier;
  uint kind;
  uint source_identifier;
  uint flags;
  ulong timestamp_microseconds;
  float magnitude;
  float auxiliary_value;
};

struct NBNeuromodulatorRecord {
  float value;
  float decay_time_constant_seconds;
  uint kind;
  uint flags;
};

struct NBFastPlasticityRecord {
  float coefficient;
  float eligibility;
  float coefficient_retention;
  float eligibility_retention;
  float learning_rate;
  float maximum_magnitude;
  ushort region_identifier;
  ushort basis_identifier;
  uint flags;
};

struct NBWorkspaceMetadataRecord {
  ulong identifier;
  ulong source_timestamp_microseconds;
  ulong last_refresh_timestamp_microseconds;
  ulong entity_identifier;
  ulong goal_identifier;
  ulong bound_token_identifier;
  ulong provenance_record_identifier;
  uint kind_and_source;
  float confidence;
};

struct NBControlHeader {
  ulong active_goal_identifier;
  ulong active_option_identifier;
  ulong active_plan_identifier;
  ulong selected_timestamp_microseconds;
  uint mode;
  uint candidate_count;
  uint plan_step_count;
  uint flags;
  float selected_score;
  float selected_damage_cvar;
  float confidence;
  float vigor;
  float exploration_temperature;
  float controller_phase;
  float interruption_cost;
  float progress;
  float predicted_effort;
  float predicted_information_gain;
  float unsupported_uncertainty;
  float reserved_float;
  ulong reserved0;
  ulong reserved1;
  ulong reserved2;
  ulong reserved3;
};

struct NBMotorCommandRecord {
  float excitation;
  float force_target;
  float stiffness_target;
  float damping_target;
  float cerebellar_residual;
  float risk_inhibition;
  uint synergy_identifier;
  uint flags;
};

struct NBCerebellarExpertRecord {
  uint expert_identifier;
  uint flags;
  float weight;
  float prediction_error;
  float state[60];
};

static_assert(sizeof(NBAcceptedConsequenceUniforms) == 240);
static_assert(sizeof(NBEventQueueHeader) == 32);
static_assert(sizeof(NBReceptorEventRecord) == 32);
static_assert(sizeof(NBNeuromodulatorRecord) == 16);
static_assert(sizeof(NBFastPlasticityRecord) == 32);
static_assert(sizeof(NBWorkspaceMetadataRecord) == 64);
static_assert(sizeof(NBControlHeader) == 128);
static_assert(sizeof(NBMotorCommandRecord) == 32);
static_assert(sizeof(NBCerebellarExpertRecord) == 256);

inline float nb_observation(
  device const float *observations,
  uint offset,
  uint count,
  uint index)
{
  return count == 0u ? 0.0f : observations[offset + index % count];
}

inline float nb_mean_prediction_error(
  device const float *observations,
  uint observation_count,
  device const float *world,
  uint world_count)
{
  const bool structured_world_available = world_count
    >= 9u * NB_WORLD_RECEPTOR_DIMENSION;
  const uint sample_count = structured_world_available
    ? min(observation_count, NB_WORLD_RECEPTOR_DIMENSION)
    : min(min(observation_count, world_count), 256u);
  if (sample_count == 0u) return 0.0f;
  float total = 0.0f;
  for (uint index = 0u; index < sample_count; ++index) {
    float prediction = world[index];
    if (structured_world_available) {
      prediction = 0.0f;
      for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
        prediction += world[
          (3u + head) * NB_WORLD_RECEPTOR_DIMENSION + index
        ] / float(NB_WORLD_HEAD_COUNT);
      }
    }
    total += abs(observations[index] - prediction);
  }
  return total / float(sample_count);
}

inline float nb_mean_epistemic_disagreement(
  device const float *world,
  uint world_count)
{
  if (world_count < 9u * NB_WORLD_RECEPTOR_DIMENSION) return 0.0f;
  float total_variance = 0.0f;
  for (uint index = 0u; index < NB_WORLD_RECEPTOR_DIMENSION; ++index) {
    float mean = 0.0f;
    for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
      mean += world[(3u + head) * NB_WORLD_RECEPTOR_DIMENSION + index]
        / float(NB_WORLD_HEAD_COUNT);
    }
    for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
      const float difference = world[
        (3u + head) * NB_WORLD_RECEPTOR_DIMENSION + index
      ] - mean;
      total_variance += difference * difference
        / float(NB_WORLD_HEAD_COUNT);
    }
  }
  return sqrt(total_variance / float(NB_WORLD_RECEPTOR_DIMENSION));
}

inline float nb_mean_aleatoric_uncertainty(
  device const float *world,
  uint world_count)
{
  if (world_count < 9u * NB_WORLD_RECEPTOR_DIMENSION) return 0.0f;
  float total = 0.0f;
  for (uint index = 0u; index < NB_WORLD_RECEPTOR_DIMENSION; ++index) {
    total += max(world[8u * NB_WORLD_RECEPTOR_DIMENSION + index], 0.0f);
  }
  return sqrt(total / float(NB_WORLD_RECEPTOR_DIMENSION));
}

kernel void assimilate_accepted_body_and_physiology(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *belief_parameters [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  const float gain = clamp(
    min(uniforms.belief_gain, max(belief_parameters[0], 0.0f)), 0.0f, 1.0f
  );
  const float velocity_gain = min(gain, max(belief_parameters[1], 0.0f));
  const float contact_gain = min(gain, max(belief_parameters[2], 0.0f));
  const float physiology_gain = min(gain, max(belief_parameters[3], 0.0f));
  if (gid < uniforms.body_count) {
    device float *body = reinterpret_cast<device float *>(
      hot_state + uniforms.body_belief_offset + ulong(gid) * 256ul
    );
    const float proprioception = nb_observation(
      observations, uniforms.proprioception_offset,
      uniforms.proprioception_count, gid
    );
    const float touch = nb_observation(
      observations, uniforms.touch_offset, uniforms.touch_count, gid
    );
    const float vestibular = nb_observation(
      observations, uniforms.vestibular_offset,
      uniforms.vestibular_count, gid
    );
    const float prior_position = body[0];
    body[0] = mix(prior_position, proprioception, gain);
    body[1] = mix(body[1], proprioception - prior_position, velocity_gain);
    body[2] = mix(body[2], clamp(abs(touch), 0.0f, 1.0f), contact_gain);
    body[3] = mix(body[3], clamp(1.0f - abs(vestibular), 0.0f, 1.0f), gain);
    body[4] = mix(body[4], max(touch, 0.0f), gain);
    body[5] = max(
      body[5] * clamp(belief_parameters[7], 0.0f, 1.0f),
      clamp(abs(touch), 0.0f, 1.0f)
    );
    body[6] = abs(proprioception - prior_position);
    body[7] = max(body[7] * (1.0f - gain), body[6] * gain);
    device ulong *identity = reinterpret_cast<device ulong *>(body + 16);
    identity[0] = ulong(gid);
    identity[1] = uniforms.target_timestamp_microseconds;
    identity[2] = uniforms.physics_state_fingerprint;
    identity[3] = NB_ACCEPTED_STATE_VALID;
  }
  if (gid < uniforms.muscle_count) {
    device float *muscle = reinterpret_cast<device float *>(
      hot_state + uniforms.muscle_belief_offset + ulong(gid) * 192ul
    );
    device const float *somatic = reinterpret_cast<device const float *>(
      hot_state + uniforms.somatic_output_offset
    );
    const float proprioception = nb_observation(
      observations, uniforms.proprioception_offset,
      uniforms.proprioception_count, gid
    );
    const float command = uniforms.actuator_count == 0u
      ? 0.0f : somatic[gid % uniforms.actuator_count];
    muscle[0] = mix(muscle[0], command, gain);
    muscle[1] = mix(muscle[1], proprioception, gain);
    muscle[2] = proprioception - muscle[1];
    muscle[3] = mix(muscle[3], abs(proprioception), gain);
    muscle[4] = clamp(muscle[4] + abs(command) * float(uniforms.delta_microseconds)
      * 1.0e-8f, 0.0f, 1.0f);
    muscle[5] = abs(proprioception - command);
  }
  if (gid < uniforms.physiology_count) {
    device float *physiology = reinterpret_cast<device float *>(
      hot_state + uniforms.physiology_offset
    );
    const float interoception = nb_observation(
      observations, uniforms.interoception_offset,
      uniforms.interoception_count, gid
    );
    physiology[gid] = mix(physiology[gid], interoception, physiology_gain);
  }
}

kernel void reconcile_accepted_world_model(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *world_parameters [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= min(uniforms.world_model_count, NB_WORLD_RECEPTOR_DIMENSION)
      || uniforms.observation_count == 0u
      || uniforms.world_model_count < 9u * NB_WORLD_RECEPTOR_DIMENSION) return;
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  device float *world = reinterpret_cast<device float *>(
    hot_state + uniforms.world_model_offset
  );
  const float observed = observations[gid % uniforms.observation_count];
  float predicted_mean = 0.0f;
  for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
    predicted_mean += world[(3u + head) * NB_WORLD_RECEPTOR_DIMENSION + gid]
      / float(NB_WORLD_HEAD_COUNT);
  }
  const float residual = observed - predicted_mean;
  const float gain = clamp(
    min(uniforms.world_correction_gain, max(world_parameters[150], 0.0f)),
    0.0f,
    1.0f
  );
  world[gid] = mix(world[gid], observed, gain);
  world[NB_WORLD_RECEPTOR_DIMENSION + gid] = residual;
  const uint aleatoric_index = 8u * NB_WORLD_RECEPTOR_DIMENSION + gid;
  world[aleatoric_index] = mix(
    max(world[aleatoric_index], 0.0f), residual * residual,
    gain * clamp(world_parameters[152], 0.0f, 1.0f)
  );
}

kernel void broadcast_accepted_prediction_error(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *world_parameters [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u) return;
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  device const float *world = reinterpret_cast<device const float *>(
    hot_state + uniforms.world_model_offset
  );
  const float error = nb_mean_prediction_error(
    observations, uniforms.observation_count, world, uniforms.world_model_count
  );
  const float epistemic = nb_mean_epistemic_disagreement(
    world, uniforms.world_model_count
  );
  const float aleatoric = nb_mean_aleatoric_uncertainty(
    world, uniforms.world_model_count
  );
  device NBNeuromodulatorRecord *neuromodulators =
    reinterpret_cast<device NBNeuromodulatorRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  if (uniforms.neuromodulator_count > 1u) {
    neuromodulators[1].value = error;
    neuromodulators[1].kind = 2u;
    neuromodulators[1].flags = NB_ACCEPTED_STATE_VALID;
  }
  if (uniforms.neuromodulator_count > 3u) {
    neuromodulators[3].value = epistemic;
    neuromodulators[3].kind = 4u;
    neuromodulators[3].flags = NB_ACCEPTED_STATE_VALID;
  }
  if (uniforms.workspace_capacity > 2u && uniforms.workspace_dimension > 0u) {
    device float *workspace = reinterpret_cast<device float *>(
      hot_state + uniforms.workspace_content_offset
    );
    device NBWorkspaceMetadataRecord *metadata =
      reinterpret_cast<device NBWorkspaceMetadataRecord *>(
        hot_state + uniforms.workspace_metadata_offset
      );
    const uint base = 2u * uniforms.workspace_dimension;
    workspace[base] = error;
    if (uniforms.workspace_dimension > 1u) {
      workspace[base + 1u] = as_type<float>(uint(uniforms.physics_state_fingerprint));
    }
    NBWorkspaceMetadataRecord token = metadata[2];
    token.identifier = (uniforms.target_timestamp_microseconds << 8) | 3ul;
    token.source_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    token.last_refresh_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    token.provenance_record_identifier = uniforms.physics_state_fingerprint;
    token.kind_and_source = 7u | (50u << 16);
    token.confidence = clamp(1.0f - error, 0.0f, 1.0f);
    metadata[2] = token;
  }
  device NBControlHeader *control = reinterpret_cast<device NBControlHeader *>(
    hot_state + uniforms.control_header_offset
  );
  control->unsupported_uncertainty = max(
    epistemic * max(world_parameters[157], 0.0f), aleatoric
  );
  control->progress = clamp(control->progress + (1.0f - error) * 0.01f, 0.0f, 1.0f);
}

kernel void adapt_cerebellar_experts_from_accepted_error(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *cerebellar_parameters [[buffer(4)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.active_cerebellar_count) return;
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  device const float *world = reinterpret_cast<device const float *>(
    hot_state + uniforms.world_model_offset
  );
  device NBCerebellarExpertRecord *experts =
    reinterpret_cast<device NBCerebellarExpertRecord *>(
      hot_state + uniforms.cerebellar_offset
    );
  device NBCerebellarExpertRecord *expert_bank =
    reinterpret_cast<device NBCerebellarExpertRecord *>(
      hot_state + uniforms.cerebellar_expert_memory_offset
    );
  device const NBMotorCommandRecord *motor =
    reinterpret_cast<device const NBMotorCommandRecord *>(
      hot_state + uniforms.motor_command_offset
    );
  const float error = nb_mean_prediction_error(
    observations, uniforms.observation_count, world, uniforms.world_model_count
  );
  NBCerebellarExpertRecord expert = experts[gid];
  expert.prediction_error = error;
  const float learning_rate = clamp(
    min(uniforms.cerebellar_learning_rate, max(cerebellar_parameters[0], 0.0f)),
    0.0f,
    1.0f
  );
  expert.state[0] = mix(
    expert.state[0], error,
    learning_rate
  );
  const float command_direction = uniforms.actuator_count == 0u
    ? 0.0f
    : 2.0f * motor[gid % uniforms.actuator_count].excitation - 1.0f;
  const float inverse_correction = -error * command_direction
    * cerebellar_parameters[3];
  expert.state[1] = mix(
    expert.state[1], inverse_correction,
    learning_rate
  );
  expert.state[2] = mix(
    expert.state[2], 1.0f - clamp(error, 0.0f, 1.0f),
    clamp(cerebellar_parameters[2], 0.0f, 1.0f)
  );
  expert.flags |= NB_ACCEPTED_STATE_VALID;
  experts[gid] = expert;
  if (expert.expert_identifier < 128u) {
    expert_bank[expert.expert_identifier] = expert;
  }
}

kernel void update_fast_plasticity_from_accepted_error(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *plasticity_parameters [[buffer(5)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.fast_plasticity_count) return;
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  device const float *world = reinterpret_cast<device const float *>(
    hot_state + uniforms.world_model_offset
  );
  device const NBNeuromodulatorRecord *neuromodulators =
    reinterpret_cast<device const NBNeuromodulatorRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  device NBFastPlasticityRecord *sites =
    reinterpret_cast<device NBFastPlasticityRecord *>(
      hot_state + uniforms.fast_plasticity_offset
    );
  const float error = nb_mean_prediction_error(
    observations, uniforms.observation_count, world, uniforms.world_model_count
  );
  NBFastPlasticityRecord site = sites[gid];
  const float modulation = uniforms.neuromodulator_count == 0u
    ? 0.0f
    : neuromodulators[gid % uniforms.neuromodulator_count].value;
  const float eligibility_retention = min(
    site.eligibility_retention,
    clamp(plasticity_parameters[2], 0.0f, 1.0f)
  );
  site.eligibility = eligibility_retention * site.eligibility
    + error * plasticity_parameters[3];
  const float coefficient_retention = min(
    site.coefficient_retention,
    clamp(plasticity_parameters[1], 0.0f, 1.0f)
  );
  const float learning_rate = min(
    uniforms.plasticity_learning_rate,
    max(plasticity_parameters[0], 0.0f)
  );
  const float limit = max(
    site.maximum_magnitude * max(plasticity_parameters[7], 0.0f), 1.0e-4f
  );
  site.coefficient = clamp(
    coefficient_retention * site.coefficient
      + learning_rate * modulation * site.eligibility,
    -limit,
    limit
  );
  site.flags |= NB_ACCEPTED_STATE_VALID;
  sites[gid] = site;
}

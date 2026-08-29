#include <metal_stdlib>
using namespace metal;

constant uint NB_ACCEPTED_STATE_VALID = 1u;
constant uint NB_ACCEPTED_CEREBELLAR_PREDICTION_VALID = 1u << 5;
constant uint NB_ACCEPTED_TRACE_COMPLETE = 1u << 1;
constant uint NB_ACCEPTED_TRACE_FAILED = 1u << 2;
constant uint NB_ACCEPTED_CONTROL_HYPERDIRECT_STOP = 1u << 1;
constant ulong NB_ACCEPTED_INNATE_OPTION_NAMESPACE = 0x8000000000000000ul;
constant ulong NB_ACCEPTED_REST_OPTION_IDENTIFIER =
  NB_ACCEPTED_INNATE_OPTION_NAMESPACE | 4ul;
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
  ulong option_candidate_offset;
  ulong procedural_trace_offset;
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
  uint option_candidate_capacity;
  uint procedural_trace_record_capacity;
  uint procedural_trace_phase_capacity;
  uint cerebellar_expert_capacity;
  uint vision_offset;
  uint vision_count;
  uint audition_offset;
  uint audition_count;
  uint proprioception_offset;
  uint proprioception_count;
  uint touch_offset;
  uint touch_count;
  uint vestibular_offset;
  uint vestibular_count;
  uint olfaction_offset;
  uint olfaction_count;
  uint gustation_offset;
  uint gustation_count;
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

struct NBOptionCandidateRecord {
  ulong option_identifier;
  ulong goal_identifier;
  float task_value;
  float homeostatic_value;
  float social_value;
  float information_gain;
  float damage_cvar;
  float effort_cost;
  float switching_cost;
  float competence;
  uint proposal_kind;
  uint source_module;
  uint flags;
  uint parameter_count;
  float parameters[16];
};

struct NBProceduralTracePhase {
  ulong option_identifier;
  ulong start_timestamp_microseconds;
  ulong last_timestamp_microseconds;
  float duration_seconds;
  float mean_value;
  float maximum_damage;
  float mean_uncertainty;
  uint sample_count;
  uint parameter_count;
  float parameters[16];
};

struct NBProceduralExecutionTrace {
  ulong identifier;
  ulong goal_identifier;
  ulong plan_identifier;
  ulong start_timestamp_microseconds;
  ulong last_timestamp_microseconds;
  uint format_version;
  uint flags;
  uint phase_count;
  uint sample_count;
  float cumulative_value;
  float maximum_damage;
  float cumulative_effort;
  float mean_uncertainty;
  float final_progress;
  float reserved[13];
  NBProceduralTracePhase phases[8];
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
  ulong prediction_timestamp_microseconds;
  uint prediction_count;
  uint reserved;
  float state[56];
};

static_assert(sizeof(NBAcceptedConsequenceUniforms) == 304);
static_assert(sizeof(NBEventQueueHeader) == 32);
static_assert(sizeof(NBReceptorEventRecord) == 32);
static_assert(sizeof(NBNeuromodulatorRecord) == 16);
static_assert(sizeof(NBFastPlasticityRecord) == 32);
static_assert(sizeof(NBWorkspaceMetadataRecord) == 64);
static_assert(sizeof(NBControlHeader) == 128);
static_assert(sizeof(NBOptionCandidateRecord) == 128);
static_assert(sizeof(NBProceduralTracePhase) == 112);
static_assert(sizeof(NBProceduralExecutionTrace) == 1024);
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

inline float nb_world_observation(
  device const float *observations,
  constant NBAcceptedConsequenceUniforms &uniforms,
  uint world_index)
{
  uint local_index = world_index;
  uint offset = uniforms.vision_offset;
  uint count = uniforms.vision_count;
  if (world_index >= 32u) {
    local_index = world_index - 32u;
    offset = uniforms.audition_offset;
    count = uniforms.audition_count;
  }
  if (world_index >= 48u) {
    local_index = world_index - 48u;
    offset = uniforms.touch_offset;
    count = uniforms.touch_count;
  }
  if (world_index >= 64u) {
    local_index = world_index - 64u;
    offset = uniforms.proprioception_offset;
    count = uniforms.proprioception_count;
  }
  if (world_index >= 80u) {
    local_index = world_index - 80u;
    offset = uniforms.vestibular_offset;
    count = uniforms.vestibular_count;
  }
  if (world_index >= 96u) {
    local_index = world_index - 96u;
    offset = uniforms.olfaction_offset;
    count = uniforms.olfaction_count;
  }
  if (world_index >= 108u) {
    local_index = world_index - 108u;
    offset = uniforms.gustation_offset;
    count = uniforms.gustation_count;
  }
  if (world_index >= 116u) {
    local_index = world_index - 116u;
    offset = uniforms.interoception_offset;
    count = uniforms.interoception_count;
  }
  if (count > 0u) return nb_observation(observations, offset, count, local_index);
  const uint fallback = uint(
    (ulong(world_index) * ulong(uniforms.observation_count))
      / ulong(NB_WORLD_RECEPTOR_DIMENSION)
  );
  return observations[min(fallback, uniforms.observation_count - 1u)];
}

inline float nb_mean_prediction_error(
  device const float *observations,
  device const float *world,
  constant NBAcceptedConsequenceUniforms &uniforms)
{
  const bool structured_world_available = uniforms.world_model_count
    >= 9u * NB_WORLD_RECEPTOR_DIMENSION;
  const uint sample_count = structured_world_available
    ? (uniforms.observation_count > 0u ? NB_WORLD_RECEPTOR_DIMENSION : 0u)
    : min(
        min(uniforms.observation_count, uniforms.world_model_count),
        256u
      );
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
    const float observed = structured_world_available
      ? nb_world_observation(observations, uniforms, index)
      : observations[index];
    total += abs(observed - prediction);
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
  const float observed = nb_world_observation(observations, uniforms, gid);
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
    observations, world, uniforms
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
  device NBCerebellarExpertRecord *experts =
    reinterpret_cast<device NBCerebellarExpertRecord *>(
      hot_state + uniforms.cerebellar_offset
    );
  device NBCerebellarExpertRecord *expert_bank =
    reinterpret_cast<device NBCerebellarExpertRecord *>(
      hot_state + uniforms.cerebellar_expert_memory_offset
    );
  NBCerebellarExpertRecord expert = experts[gid];
  const bool prediction_is_causal =
    (expert.flags & NB_ACCEPTED_CEREBELLAR_PREDICTION_VALID) != 0u
    && expert.prediction_count > 0u
    && uniforms.observation_count > 0u
    && expert.prediction_timestamp_microseconds
      < uniforms.target_timestamp_microseconds
    && uniforms.target_timestamp_microseconds
      - expert.prediction_timestamp_microseconds == uniforms.delta_microseconds;
  if (!prediction_is_causal) {
    expert.flags &= ~NB_ACCEPTED_CEREBELLAR_PREDICTION_VALID;
    experts[gid] = expert;
    return;
  }
  const float learning_rate = clamp(
    min(uniforms.cerebellar_learning_rate, max(cerebellar_parameters[0], 0.0f)),
    0.0f,
    1.0f
  );
  const uint prediction_count = min(expert.prediction_count, 8u);
  float absolute_error_sum = 0.0f;
  float command_error_sum = 0.0f;
  for (uint sample = 0u; sample < prediction_count; ++sample) {
    const uint observation_index =
      (expert.expert_identifier * 17u + sample * 31u)
        % uniforms.observation_count;
    const float signed_error = observations[observation_index]
      - expert.state[4u + sample];
    const float command_feature = expert.state[20u + sample];
    absolute_error_sum += abs(signed_error);
    command_error_sum += signed_error * command_feature;
    expert.state[28u + sample] = clamp(
      expert.state[28u + sample]
        + learning_rate * signed_error * command_feature,
      -1.0f,
      1.0f
    );
  }
  const float error = absolute_error_sum / float(prediction_count);
  expert.prediction_error = error;
  expert.state[0] = mix(
    expert.state[0], error,
    learning_rate
  );
  const float inverse_correction = clamp(
    -(command_error_sum / float(prediction_count))
      * cerebellar_parameters[3],
    -0.25f,
    0.25f
  );
  expert.state[1] = mix(
    expert.state[1], inverse_correction,
    learning_rate
  );
  expert.state[2] = mix(
    expert.state[2], 1.0f - clamp(error, 0.0f, 1.0f),
    clamp(cerebellar_parameters[2], 0.0f, 1.0f)
  );
  expert.flags = (expert.flags | NB_ACCEPTED_STATE_VALID)
    & ~NB_ACCEPTED_CEREBELLAR_PREDICTION_VALID;
  experts[gid] = expert;
  if (expert.expert_identifier < uniforms.cerebellar_expert_capacity) {
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
    observations, world, uniforms
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

inline ulong nb_trace_hash(ulong value) {
  value ^= value >> 30;
  value *= 0xbf58476d1ce4e5b9ul;
  value ^= value >> 27;
  value *= 0x94d049bb133111ebul;
  return value ^ (value >> 31);
}

/// Records only the option phases whose physical consequences were accepted.
/// Completed traces remain in the transactional hot arena until rest-time
/// procedural consolidation consumes them.
kernel void update_accepted_procedural_trace(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.procedural_trace_record_capacity == 0u
      || uniforms.procedural_trace_phase_capacity == 0u) return;
  device const NBControlHeader *control =
    reinterpret_cast<device const NBControlHeader *>(
      hot_state + uniforms.control_header_offset
    );
  device NBProceduralExecutionTrace *traces =
    reinterpret_cast<device NBProceduralExecutionTrace *>(
      hot_state + uniforms.procedural_trace_offset
    );
  if (control->active_option_identifier == NB_ACCEPTED_REST_OPTION_IDENTIFIER) {
    for (uint index = 0u; index < uniforms.procedural_trace_record_capacity;
        ++index) {
      if ((traces[index].flags & NB_ACCEPTED_STATE_VALID) != 0u
          && (traces[index].flags & NB_ACCEPTED_TRACE_COMPLETE) == 0u
          && traces[index].phase_count > 0u) {
        traces[index].flags |= NB_ACCEPTED_TRACE_COMPLETE;
        traces[index].last_timestamp_microseconds =
          uniforms.target_timestamp_microseconds;
      }
    }
    return;
  }
  if (uniforms.option_candidate_capacity == 0u) return;
  const uint selected_index = min(
    uint(control->reserved0), uniforms.option_candidate_capacity - 1u
  );
  device const NBOptionCandidateRecord *candidates =
    reinterpret_cast<device const NBOptionCandidateRecord *>(
      hot_state + uniforms.option_candidate_offset
    );
  const NBOptionCandidateRecord candidate = candidates[selected_index];
  if ((candidate.flags & NB_ACCEPTED_STATE_VALID) == 0u
      || candidate.option_identifier != control->active_option_identifier) return;

  uint trace_index = uniforms.procedural_trace_record_capacity;
  uint reusable_index = uniforms.procedural_trace_record_capacity;
  ulong reusable_timestamp = ~0ul;
  for (uint index = 0u; index < uniforms.procedural_trace_record_capacity;
      ++index) {
    const NBProceduralExecutionTrace trace = traces[index];
    const bool valid = trace.format_version == 1u
      && (trace.flags & NB_ACCEPTED_STATE_VALID) != 0u;
    if (valid && (trace.flags & NB_ACCEPTED_TRACE_COMPLETE) == 0u
        && trace.goal_identifier == control->active_goal_identifier) {
      trace_index = index;
      break;
    }
    if (!valid) {
      if (reusable_index == uniforms.procedural_trace_record_capacity) {
        reusable_index = index;
      }
    } else if ((trace.flags & NB_ACCEPTED_TRACE_COMPLETE) != 0u
        && trace.last_timestamp_microseconds < reusable_timestamp) {
      reusable_index = index;
      reusable_timestamp = trace.last_timestamp_microseconds;
    }
  }
  if (trace_index == uniforms.procedural_trace_record_capacity) {
    if (reusable_index == uniforms.procedural_trace_record_capacity) return;
    trace_index = reusable_index;
    NBProceduralExecutionTrace initial = {};
    initial.identifier = nb_trace_hash(
      control->active_goal_identifier
        ^ control->active_option_identifier
        ^ uniforms.target_timestamp_microseconds
    ) | 1ul;
    initial.goal_identifier = control->active_goal_identifier;
    initial.plan_identifier = control->active_plan_identifier;
    initial.start_timestamp_microseconds =
      uniforms.target_timestamp_microseconds - uniforms.delta_microseconds;
    initial.last_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    initial.format_version = 1u;
    initial.flags = NB_ACCEPTED_STATE_VALID;
    traces[trace_index] = initial;
  }

  device NBProceduralExecutionTrace *trace = &traces[trace_index];
  if ((control->flags & NB_ACCEPTED_CONTROL_HYPERDIRECT_STOP) != 0u) {
    trace->flags |= NB_ACCEPTED_TRACE_COMPLETE | NB_ACCEPTED_TRACE_FAILED;
  }
  uint phase_index = trace->phase_count;
  if (trace->phase_count > 0u
      && trace->phases[trace->phase_count - 1u].option_identifier
        == candidate.option_identifier) {
    phase_index = trace->phase_count - 1u;
  } else {
    if (trace->phase_count >= min(
        uniforms.procedural_trace_phase_capacity, 8u
      )) {
      trace->flags |= NB_ACCEPTED_TRACE_COMPLETE;
      return;
    }
    phase_index = trace->phase_count;
    NBProceduralTracePhase phase = {};
    phase.option_identifier = candidate.option_identifier;
    phase.start_timestamp_microseconds =
      uniforms.target_timestamp_microseconds - uniforms.delta_microseconds;
    phase.parameter_count = min(candidate.parameter_count, 16u);
    trace->phases[phase_index] = phase;
    trace->phase_count += 1u;
  }
  device NBProceduralTracePhase *phase = &trace->phases[phase_index];
  const uint next_phase_samples = phase->sample_count == ~0u
    ? phase->sample_count : phase->sample_count + 1u;
  const float phase_rate = 1.0f / float(max(next_phase_samples, 1u));
  phase->last_timestamp_microseconds = uniforms.target_timestamp_microseconds;
  phase->duration_seconds += float(uniforms.delta_microseconds) * 1.0e-6f;
  phase->mean_value = mix(
    phase->mean_value, control->selected_score, phase_rate
  );
  phase->maximum_damage = max(
    phase->maximum_damage, control->selected_damage_cvar
  );
  phase->mean_uncertainty = mix(
    phase->mean_uncertainty, control->unsupported_uncertainty, phase_rate
  );
  phase->sample_count = next_phase_samples;
  for (uint component = 0u; component < 16u; ++component) {
    phase->parameters[component] = mix(
      phase->parameters[component], candidate.parameters[component], phase_rate
    );
  }
  const uint next_samples = trace->sample_count == ~0u
    ? trace->sample_count : trace->sample_count + 1u;
  const float trace_rate = 1.0f / float(max(next_samples, 1u));
  trace->sample_count = next_samples;
  trace->last_timestamp_microseconds = uniforms.target_timestamp_microseconds;
  trace->plan_identifier = control->active_plan_identifier != 0ul
    ? control->active_plan_identifier : trace->plan_identifier;
  trace->cumulative_value += control->selected_score;
  trace->maximum_damage = max(
    trace->maximum_damage, control->selected_damage_cvar
  );
  trace->cumulative_effort += max(control->predicted_effort, 0.0f);
  trace->mean_uncertainty = mix(
    trace->mean_uncertainty, control->unsupported_uncertainty, trace_rate
  );
  trace->final_progress = control->progress;
  if (control->progress >= 0.99f) trace->flags |= NB_ACCEPTED_TRACE_COMPLETE;
}

#include <metal_stdlib>
using namespace metal;

constant uint NB_ACCEPTED_STATE_VALID = 1u;
constant uint NB_ACCEPTED_CEREBELLAR_PREDICTION_VALID = 1u << 5;
constant uint NB_ACCEPTED_TRACE_COMPLETE = 1u << 1;
constant uint NB_ACCEPTED_TRACE_FAILED = 1u << 2;
constant uint NB_ACCEPTED_CONTROL_HYPERDIRECT_STOP = 1u << 1;
constant uint NB_ACCEPTED_CONTROL_MODE_REFLEX = 1u;
constant uint NB_ACCEPTED_REFLEX_ACTIVATED_IN_ROOT = 1u << 5;
constant uint NB_ACCEPTED_PROTECTIVE_VALID = 1u;
constant uint NB_ACCEPTED_PROTECTIVE_EMERGENCY_STOP = 1u << 1;
constant ulong NB_ACCEPTED_INNATE_OPTION_NAMESPACE = 0x8000000000000000ul;
constant ulong NB_ACCEPTED_REST_OPTION_IDENTIFIER =
  NB_ACCEPTED_INNATE_OPTION_NAMESPACE | 4ul;
constant uint NB_WORLD_RECEPTOR_DIMENSION = 128u;
constant uint NB_WORLD_HEAD_COUNT = 5u;
constant uint NB_WORLD_EVENT_OPTION_BASE = 5760u;
constant uint NB_WORLD_EVENT_OPTION_DIMENSION = 256u;
constant uint NB_ACCEPTED_ACTUATOR_MUSCLE_EXCITATION = 1u;

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
  ulong drive_offset;
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
  ulong active_sensing_command_offset;
  ulong active_sensing_efficacy_offset;
  ulong accepted_somatic_output_offset;
  ulong reflex_state_offset;
  ulong fast_autonomic_state_offset;
  ulong physics_state_fingerprint;
  uint observation_count;
  uint body_count;
  uint muscle_count;
  uint physiology_count;
  uint world_model_count;
  uint neuromodulator_count;
  uint drive_count;
  uint maximum_planning_horizon;
  uint fast_plasticity_count;
  uint workspace_capacity;
  uint workspace_dimension;
  uint active_cerebellar_count;
  uint actuator_count;
  uint active_sensing_count;
  uint reflex_state_count;
  uint fast_autonomic_state_count;
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

struct NBDriveStateRecord {
  float level;
  float viable_minimum;
  float viable_maximum;
  float priority_weight;
  float estimated_rate;
  float deficit;
  float potential;
  uint kind;
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

struct NBActiveSensingCommandRecord {
  float command;
  float confidence;
  uint attention_allocation_mask;
  uint kind_and_flags;
};

struct NBActiveSensingEfficacyRecord {
  float prior_uncertainty;
  float accepted_uncertainty;
  float efficacy;
  float realized_information_gain;
  uint sample_count;
  uint flags;
  float allocation;
  float reserved;
};

struct NBAcceptedActuatorDescriptor {
  uint actuator_identifier;
  uint command_kind;
  uint flags;
  uint reserved;
  float output_minimum;
  float output_maximum;
  float neutral_command;
  float emergency_command;
};

struct NBFastBodySchemaRecord {
  uint body_identifier;
  uint flags;
  uint source_muscle_identifier;
  uint endpoint_role;
  float estimated_absolute_load;
  float epistemic_variance;
  float vulnerability;
  float damage_risk;
  ulong last_observation_timestamp_microseconds;
  ulong state_timestamp_microseconds;
};

struct NBFastReflexStateRecord {
  ulong last_event_timestamp_microseconds;
  ulong state_timestamp_microseconds;
  float output;
  float event_magnitude;
  uint circuit_identifier;
  uint flags;
  ulong pending_delivery_timestamp_microseconds[4];
  ulong pending_event_timestamp_microseconds[4];
  float pending_output[4];
  float pending_event_magnitude[4];
};

struct NBFastAutonomicStateRecord {
  ulong last_event_timestamp_microseconds;
  ulong state_timestamp_microseconds;
  float command;
  float target;
  float critical_drive;
  float integration;
  uint update_count;
  uint flags;
  float reserved[6];
};

struct NBAcceptedProtectiveCommandRecord {
  uint format_version;
  uint flags;
  ulong timestamp_microseconds;
  ulong brain_generation;
  ulong interrupt_mask;
  float withdrawal_drive;
  float postural_stiffness;
  float motor_inhibition;
  float autonomic_arousal;
  uint environment_identifier;
  uint reserved;
  ulong command_fingerprint;
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

static_assert(sizeof(NBAcceptedConsequenceUniforms) == 376);
static_assert(sizeof(NBEventQueueHeader) == 32);
static_assert(sizeof(NBReceptorEventRecord) == 32);
static_assert(sizeof(NBNeuromodulatorRecord) == 16);
static_assert(sizeof(NBFastPlasticityRecord) == 32);
static_assert(sizeof(NBWorkspaceMetadataRecord) == 64);
static_assert(sizeof(NBControlHeader) == 128);
static_assert(sizeof(NBActiveSensingCommandRecord) == 16);
static_assert(sizeof(NBActiveSensingEfficacyRecord) == 32);
static_assert(sizeof(NBAcceptedActuatorDescriptor) == 32);
static_assert(sizeof(NBFastBodySchemaRecord) == 48);
static_assert(sizeof(NBFastReflexStateRecord) == 128);
static_assert(sizeof(NBFastAutonomicStateRecord) == 64);
static_assert(sizeof(NBAcceptedProtectiveCommandRecord) == 64);
static_assert(sizeof(NBOptionCandidateRecord) == 128);
static_assert(sizeof(NBProceduralTracePhase) == 112);
static_assert(sizeof(NBProceduralExecutionTrace) == 1024);
static_assert(sizeof(NBMotorCommandRecord) == 32);
static_assert(sizeof(NBCerebellarExpertRecord) == 256);

/// Converts the exact accepted physical actuator command back into the
/// species-neutral causal feature used by body-effect and policy learning.
/// Muscle excitation remains [0, 1]; other actuators are signed around their
/// explicit physical neutral and preserve asymmetric ranges.
inline float nb_accepted_actuator_feature(
  const float physical_command,
  const NBAcceptedActuatorDescriptor actuator)
{
  if (actuator.command_kind == NB_ACCEPTED_ACTUATOR_MUSCLE_EXCITATION) {
    return clamp(
      (physical_command - actuator.output_minimum)
        / max(actuator.output_maximum - actuator.output_minimum, 1.0e-6f),
      0.0f,
      1.0f
    );
  }
  const float bounded_command = clamp(
    physical_command, actuator.output_minimum, actuator.output_maximum
  );
  if (bounded_command >= actuator.neutral_command) {
    return clamp(
      (bounded_command - actuator.neutral_command)
        / max(actuator.output_maximum - actuator.neutral_command, 1.0e-6f),
      0.0f,
      1.0f
    );
  }
  return -clamp(
    (actuator.neutral_command - bounded_command)
      / max(actuator.neutral_command - actuator.output_minimum, 1.0e-6f),
    0.0f,
    1.0f
  );
}

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

inline float nb_modality_epistemic_uncertainty(
  device const float *world,
  uint world_count,
  uint modality)
{
  if (world_count < 8u * NB_WORLD_RECEPTOR_DIMENSION) return 0.0f;
  uint begin = 0u;
  uint end = 32u;
  switch (modality) {
    case 2u: begin = 32u; end = 48u; break;
    case 3u: begin = 48u; end = 64u; break;
    case 4u: begin = 64u; end = 80u; break;
    case 5u: begin = 80u; end = 96u; break;
    case 6u: begin = 96u; end = 108u; break;
    case 7u: begin = 108u; end = 116u; break;
    case 8u: begin = 116u; end = 128u; break;
    default: break;
  }
  float total_variance = 0.0f;
  for (uint index = begin; index < end; ++index) {
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
  return sqrt(total_variance / float(max(end - begin, 1u)));
}

inline float nb_modality_aleatoric_uncertainty(
  device const float *world,
  uint world_count,
  uint modality)
{
  if (world_count < 9u * NB_WORLD_RECEPTOR_DIMENSION) return 1.0f;
  uint begin = 0u;
  uint end = 32u;
  switch (modality) {
    case 2u: begin = 32u; end = 48u; break;
    case 3u: begin = 48u; end = 64u; break;
    case 4u: begin = 64u; end = 80u; break;
    case 5u: begin = 80u; end = 96u; break;
    case 6u: begin = 96u; end = 108u; break;
    case 7u: begin = 108u; end = 116u; break;
    case 8u: begin = 116u; end = 128u; break;
    default: break;
  }
  float total = 0.0f;
  for (uint index = begin; index < end; ++index) {
    total += max(world[8u * NB_WORLD_RECEPTOR_DIMENSION + index], 0.0f);
  }
  return sqrt(total / float(max(end - begin, 1u)));
}

inline float nb_body_schema_epistemic_uncertainty(
  device const uchar *hot_state,
  constant NBAcceptedConsequenceUniforms &uniforms)
{
  float uncertainty = 0.0f;
  for (uint body_index = 0u; body_index < uniforms.body_count; ++body_index) {
    device const float *body = reinterpret_cast<device const float *>(
      hot_state + uniforms.body_belief_offset + ulong(body_index) * 256ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      body + 16
    );
    if ((identity[3] & 1ul) == 0ul || !isfinite(body[9])) continue;
    const float standard_deviation = sqrt(max(body[9], 0.0f));
    uncertainty = max(
      uncertainty,
      standard_deviation / (1.0f + standard_deviation)
    );
  }
  return uncertainty;
}

kernel void assimilate_accepted_body_and_physiology(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *belief_parameters [[buffer(2)]],
  device const NBAcceptedActuatorDescriptor *actuator_descriptors
    [[buffer(6)]],
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
    device float *somatic = reinterpret_cast<device float *>(
      hot_state + uniforms.somatic_output_offset
    );
    device const float *accepted_somatic =
      reinterpret_cast<device const float *>(
        hot_state + uniforms.accepted_somatic_output_offset
      );
    const float proprioception = nb_observation(
      observations, uniforms.proprioception_offset,
      uniforms.proprioception_count, gid
    );
    const uint actuator_index = gid % max(uniforms.actuator_count, 1u);
    const NBAcceptedActuatorDescriptor actuator =
      actuator_descriptors[actuator_index];
    const float physical_command = uniforms.actuator_count == 0u
      ? 0.0f : accepted_somatic[actuator_index];
    const float command = uniforms.actuator_count == 0u
      || (actuator.flags & NB_ACCEPTED_STATE_VALID) == 0u
      ? 0.0f
      : nb_accepted_actuator_feature(physical_command, actuator);
    if (gid < uniforms.actuator_count) {
      // Committed transition records consume this exact accepted action
      // feature after consequence assimilation, never the rejected decision.
      somatic[gid] = command;
    }
    const float prior_proprioception = muscle[1];
    const float observed_delta = proprioception - prior_proprioception;
    const float effect_learning_rate = clamp(
      min(gain, max(belief_parameters[4], 0.0f)), 0.0f, 1.0f
    );
    const float prior_effect_gain = muscle[6];
    const float prior_effect_bias = muscle[7];
    const float predicted_delta = fma(
      prior_effect_gain, command, prior_effect_bias
    );
    const float effect_error = observed_delta - predicted_delta;
    const float normalized_command_energy = fma(command, command, 1.0e-4f);
    const float effect_limit = max(belief_parameters[6], 1.0f);
    const float learned_effect_gain = clamp(
      prior_effect_gain
        + effect_learning_rate * command * effect_error
          / normalized_command_energy,
      -effect_limit,
      effect_limit
    );
    const float learned_effect_bias = clamp(
      prior_effect_bias + 0.25f * effect_learning_rate * effect_error,
      -effect_limit,
      effect_limit
    );
    const float agency_error_scale = max(belief_parameters[5], 1.0f);
    const float agency_confidence = 1.0f
      / (1.0f + agency_error_scale * abs(effect_error));
    const float external_disturbance = abs(effect_error)
      * (1.0f - agency_confidence);
    muscle[0] = mix(muscle[0], command, gain);
    muscle[1] = mix(muscle[1], proprioception, gain);
    muscle[2] = observed_delta;
    muscle[3] = mix(muscle[3], abs(proprioception), gain);
    muscle[4] = clamp(muscle[4] + abs(command) * float(uniforms.delta_microseconds)
      * 1.0e-8f, 0.0f, 1.0f);
    muscle[5] = effect_error;
    muscle[6] = learned_effect_gain;
    muscle[7] = learned_effect_bias;
    muscle[8] = agency_confidence;
    muscle[9] = external_disturbance;
    muscle[10] = predicted_delta;
    muscle[11] = command;
    device ulong *effector_identity = reinterpret_cast<device ulong *>(
      muscle + 16
    );
    effector_identity[0] = ulong(actuator.actuator_identifier);
    effector_identity[1] = uniforms.target_timestamp_microseconds;
    effector_identity[2] = ulong(actuator.command_kind);
    effector_identity[3] = NB_ACCEPTED_STATE_VALID;
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

/// Joins the accepted fast load posterior into the compatible cognitive body
/// factor. The fast record remains the estimator of load and vulnerability;
/// the cognitive factor retains receptor pose/contact evidence and publishes
/// the maximum compatible risk used by planning and motor arbitration.
kernel void assimilate_accepted_fast_body_schema(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const NBFastBodySchemaRecord *fast_body_schema [[buffer(7)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.body_count) return;
  const NBFastBodySchemaRecord schema = fast_body_schema[gid];
  if (schema.body_identifier != gid
      || schema.state_timestamp_microseconds
        != uniforms.target_timestamp_microseconds
      || !isfinite(schema.estimated_absolute_load)
      || !isfinite(schema.epistemic_variance)
      || !isfinite(schema.vulnerability)
      || !isfinite(schema.damage_risk)) {
    return;
  }
  device float *body = reinterpret_cast<device float *>(
    hot_state + uniforms.body_belief_offset + ulong(gid) * 256ul
  );
  body[8] = max(schema.estimated_absolute_load, 0.0f);
  body[9] = max(schema.epistemic_variance, 0.0f);
  body[10] = clamp(schema.vulnerability, 0.0f, 1.0f);
  body[11] = clamp(schema.damage_risk, 0.0f, 1.0f);
  if ((schema.flags & 1u) != 0u) {
    body[5] = max(body[5], body[11]);
    body[7] = max(body[7], max(body[10], body[11]));
  }
  device ulong *identity = reinterpret_cast<device ulong *>(body + 16);
  identity[0] = ulong(schema.body_identifier);
  identity[1] = uniforms.target_timestamp_microseconds;
  identity[3] |= 1ul;
  if ((schema.flags & 1u) != 0u) identity[3] |= 1ul << 4u;
  identity[4] = schema.last_observation_timestamp_microseconds;
  identity[5] = schema.state_timestamp_microseconds;
  identity[6] = (ulong(schema.source_muscle_identifier) << 32u)
    | ulong(schema.endpoint_role);
  identity[7] = ulong(schema.flags);
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
  for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
    const uint head_index =
      (3u + head) * NB_WORLD_RECEPTOR_DIMENSION + gid;
    world[head_index] = mix(world[head_index], observed, gain);
  }
  world[gid] = mix(world[gid], observed, gain);
  world[NB_WORLD_RECEPTOR_DIMENSION + gid] = residual;
  const uint aleatoric_index = 8u * NB_WORLD_RECEPTOR_DIMENSION + gid;
  world[aleatoric_index] = mix(
    max(world[aleatoric_index], 0.0f), residual * residual,
    gain * clamp(world_parameters[152], 0.0f, 1.0f)
  );
}

/// Updates one mind's per-channel sensing efficacy from accepted receptor
/// consequences. The pending bit is written during decision generation and is
/// cleared only here, so a rejected physical trajectory cannot become a
/// calibration sample.
kernel void update_active_sensing_efficacy(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *belief_parameters [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.active_sensing_count) return;
  device const NBActiveSensingCommandRecord *commands =
    reinterpret_cast<device const NBActiveSensingCommandRecord *>(
      hot_state + uniforms.active_sensing_command_offset
    );
  device NBActiveSensingEfficacyRecord *states =
    reinterpret_cast<device NBActiveSensingEfficacyRecord *>(
      hot_state + uniforms.active_sensing_efficacy_offset
    );
  NBActiveSensingEfficacyRecord state = states[gid];
  const NBActiveSensingCommandRecord command = commands[gid];
  const bool pending = (state.flags & (1u << 1u)) != 0u;
  const bool command_valid = (command.kind_and_flags & (1u << 16u)) != 0u;
  const float allocation = min(
    clamp(state.allocation, 0.0f, 1.0f),
    clamp(command.confidence, 0.0f, 1.0f)
  );
  if (!pending || !command_valid || allocation <= 0.0f) {
    state.flags = NB_ACCEPTED_STATE_VALID;
    state.allocation = 0.0f;
    states[gid] = state;
    return;
  }
  const uint modality = command.kind_and_flags & 0xffu;
  device const float *world = reinterpret_cast<device const float *>(
    hot_state + uniforms.world_model_offset
  );
  float accepted_uncertainty = nb_modality_epistemic_uncertainty(
    world, uniforms.world_model_count, modality
  );
  if (modality == 3u || modality == 4u) {
    accepted_uncertainty = max(
      accepted_uncertainty,
      nb_body_schema_epistemic_uncertainty(hot_state, uniforms)
    );
  }
  const float aleatoric_uncertainty = clamp(
    nb_modality_aleatoric_uncertainty(
      world, uniforms.world_model_count, modality
    ),
    0.0f,
    1.0f
  );
  const float epistemic_reduction = max(
    state.prior_uncertainty - accepted_uncertainty, 0.0f
  );
  const float realized_information_gain = epistemic_reduction
    * (1.0f - aleatoric_uncertainty) * allocation;
  const float opportunity = max(state.prior_uncertainty * allocation, 1.0e-6f);
  const float efficacy_target = clamp(
    realized_information_gain / opportunity, 0.0f, 2.0f
  );
  const float retention = clamp(belief_parameters[7], 0.0f, 0.999f);
  const float prior_efficacy = state.sample_count > 0u
    ? clamp(state.efficacy, 0.0f, 2.0f) : 1.0f;
  state.accepted_uncertainty = accepted_uncertainty;
  state.efficacy = mix(prior_efficacy, efficacy_target, 1.0f - retention);
  state.realized_information_gain = realized_information_gain;
  state.sample_count = state.sample_count == 0xffffffffu
    ? state.sample_count : state.sample_count + 1u;
  state.flags = NB_ACCEPTED_STATE_VALID;
  state.allocation = allocation;
  state.reserved = aleatoric_uncertainty;
  states[gid] = state;
}

inline float nb_accepted_fast_autonomic_critical(
  device const uchar *hot_state,
  constant NBAcceptedConsequenceUniforms &uniforms)
{
  device const NBFastAutonomicStateRecord *states =
    reinterpret_cast<device const NBFastAutonomicStateRecord *>(
      hot_state + uniforms.fast_autonomic_state_offset
    );
  float critical = 0.0f;
  for (uint index = 0u; index < uniforms.fast_autonomic_state_count; ++index) {
    const NBFastAutonomicStateRecord state = states[index];
    if ((state.flags & NB_ACCEPTED_STATE_VALID) != 0u
        && (state.flags & (1u << 1u)) != 0u
        && isfinite(state.critical_drive)) {
      critical = max(critical, clamp(state.critical_drive, 0.0f, 1.0f));
    }
  }
  return critical;
}

inline float nb_accepted_protective_command_risk(
  device const NBAcceptedProtectiveCommandRecord *command,
  constant NBAcceptedConsequenceUniforms &uniforms)
{
  if (command->format_version != 1u
      || (command->flags & NB_ACCEPTED_PROTECTIVE_VALID) == 0u
      || (command->flags & NB_ACCEPTED_PROTECTIVE_EMERGENCY_STOP) == 0u
      || command->timestamp_microseconds != uniforms.target_timestamp_microseconds
      || command->interrupt_mask == 0ul) {
    return 0.0f;
  }
  return max(
    0.5f,
    clamp(
      max(
        max(command->motor_inhibition, command->withdrawal_drive),
        max(command->postural_stiffness, command->autonomic_arousal)
      ),
      0.0f,
      1.0f
    )
  );
}

inline float3 nb_accepted_embodied_risk(
  device const uchar *hot_state,
  constant NBAcceptedConsequenceUniforms &uniforms,
  const float physiological_critical)
{
  float pain = 0.0f;
  float threat = 0.0f;
  float evidence = 0.0f;
  for (uint body_index = 0u; body_index < uniforms.body_count; ++body_index) {
    device const float *body = reinterpret_cast<device const float *>(
      hot_state + uniforms.body_belief_offset + ulong(body_index) * 256ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      body + 16
    );
    if ((identity[3] & 1ul) == 0ul) continue;
    evidence = 1.0f;
    if (isfinite(body[5])) {
      pain = max(pain, clamp(body[5], 0.0f, 1.0f));
    }
    if (isfinite(body[7])) {
      threat = max(threat, clamp(body[7], 0.0f, 1.0f));
    }
    if (isfinite(body[10])) {
      threat = max(threat, clamp(body[10], 0.0f, 1.0f));
    }
    if (isfinite(body[11])) {
      const float damage_risk = clamp(body[11], 0.0f, 1.0f);
      pain = max(pain, damage_risk);
      threat = max(threat, damage_risk);
    }
  }
  return float3(
    pain,
    max(max(threat, pain), physiological_critical),
    max(evidence, physiological_critical > 0.0f ? 1.0f : 0.0f)
  );
}

inline void nb_raise_accepted_drive(
  device NBDriveStateRecord *drives,
  uint drive_count,
  uint index,
  float signal,
  float elapsed_seconds)
{
  if (index >= drive_count || signal <= 0.0f) return;
  NBDriveStateRecord state = drives[index];
  const float previous = state.level;
  state.level = max(previous, clamp(signal, 0.0f, 1.0f));
  state.estimated_rate = elapsed_seconds > 0.0f
    ? (state.level - previous) / elapsed_seconds : 0.0f;
  state.deficit = state.level < state.viable_minimum
    ? state.viable_minimum - state.level
    : (state.level > state.viable_maximum
      ? state.level - state.viable_maximum : 0.0f);
  state.potential = state.priority_weight * state.deficit * state.deficit;
  state.kind = index + 1u;
  drives[index] = state;
}

inline bool nb_has_accepted_protective_reflex(
  device const uchar *hot_state,
  constant NBAcceptedConsequenceUniforms &uniforms)
{
  device const NBFastReflexStateRecord *states =
    reinterpret_cast<device const NBFastReflexStateRecord *>(
      hot_state + uniforms.reflex_state_offset
    );
  for (uint index = 0u; index < uniforms.reflex_state_count; ++index) {
    const NBFastReflexStateRecord state = states[index];
    if ((state.flags & NB_ACCEPTED_STATE_VALID) == 0u
        || (state.flags & NB_ACCEPTED_REFLEX_ACTIVATED_IN_ROOT) == 0u) {
      continue;
    }
    const uint circuit_kind = (state.flags >> 8u) & 0xffu;
    const bool protective = circuit_kind == 3u   // withdrawal
      || circuit_kind == 4u                     // crossed extension
      || circuit_kind == 7u                     // joint-limit protection
      || circuit_kind == 9u                     // pain inhibition
      || circuit_kind == 10u;                   // muscle-overload inhibition
    if (protective) return true;
  }
  return false;
}

kernel void broadcast_accepted_prediction_error(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *world_parameters [[buffer(3)]],
  device const NBAcceptedProtectiveCommandRecord *protective_command
    [[buffer(8)]],
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
  device const uchar *muscle_bytes = hot_state + uniforms.muscle_belief_offset;
  float mean_agency = 0.0f;
  float mean_external_disturbance = 0.0f;
  for (uint index = 0u; index < uniforms.muscle_count; ++index) {
    device const float *muscle = reinterpret_cast<device const float *>(
      muscle_bytes + ulong(index) * 192ul
    );
    mean_agency += muscle[8] / float(max(uniforms.muscle_count, 1u));
    mean_external_disturbance += muscle[9]
      / float(max(uniforms.muscle_count, 1u));
  }
  device NBNeuromodulatorRecord *neuromodulators =
    reinterpret_cast<device NBNeuromodulatorRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  device NBControlHeader *control = reinterpret_cast<device NBControlHeader *>(
    hot_state + uniforms.control_header_offset
  );
  const float physiological_critical = nb_accepted_fast_autonomic_critical(
    hot_state, uniforms
  );
  const float protective_risk = nb_accepted_protective_command_risk(
    protective_command, uniforms
  );
  if (nb_has_accepted_protective_reflex(hot_state, uniforms)
      || physiological_critical > 0.0f || protective_risk > 0.0f) {
    // Preserve the cached option identifier as causal provenance while
    // recording that accepted fast protection interrupted its execution.
    control->flags |= NB_ACCEPTED_CONTROL_HYPERDIRECT_STOP;
    control->mode = NB_ACCEPTED_CONTROL_MODE_REFLEX;
    control->active_plan_identifier = 0ul;
    control->plan_step_count = 0u;
    control->vigor = 0.0f;
  }
  const float3 embodied_risk = nb_accepted_embodied_risk(
    hot_state, uniforms, max(physiological_critical, protective_risk)
  );
  device NBDriveStateRecord *drives =
    reinterpret_cast<device NBDriveStateRecord *>(
      hot_state + uniforms.drive_offset
    );
  const float elapsed_seconds = float(uniforms.delta_microseconds) * 1.0e-6f;
  nb_raise_accepted_drive(
    drives, uniforms.drive_count, 5u, embodied_risk.x, elapsed_seconds
  );
  nb_raise_accepted_drive(
    drives, uniforms.drive_count, 11u, embodied_risk.y, elapsed_seconds
  );
  if (uniforms.neuromodulator_count > 4u) {
    neuromodulators[4].value = max(
      neuromodulators[4].value, embodied_risk.x
    );
    neuromodulators[4].kind = 5u;
    neuromodulators[4].flags = NB_ACCEPTED_STATE_VALID;
  }
  if (uniforms.neuromodulator_count > 5u) {
    neuromodulators[5].value = max(
      neuromodulators[5].value, embodied_risk.y
    );
    neuromodulators[5].kind = 6u;
    neuromodulators[5].flags = NB_ACCEPTED_STATE_VALID;
  }
  if (uniforms.neuromodulator_count > 6u) {
    neuromodulators[6].value = max(
      neuromodulators[6].value, embodied_risk.y
    );
    neuromodulators[6].kind = 7u;
    neuromodulators[6].flags = NB_ACCEPTED_STATE_VALID;
  }
  if (embodied_risk.z > 0.0f && uniforms.maximum_planning_horizon > 0u
      && uint(control->reserved0) < uniforms.option_candidate_capacity
      && uniforms.world_model_count >= NB_WORLD_EVENT_OPTION_BASE
        + 9u * NB_WORLD_EVENT_OPTION_DIMENSION) {
    const uint selected_candidate = uint(control->reserved0);
    const uint component = (
      selected_candidate * uniforms.maximum_planning_horizon
    ) % NB_WORLD_EVENT_OPTION_DIMENSION;
    device float *mutable_world = reinterpret_cast<device float *>(
      hot_state + uniforms.world_model_offset
    );
    const float accepted_risk = max(embodied_risk.x, embodied_risk.y);
    float predicted_mean = 0.0f;
    for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
      predicted_mean += mutable_world[NB_WORLD_EVENT_OPTION_BASE
        + (3u + head) * NB_WORLD_EVENT_OPTION_DIMENSION + component]
        / float(NB_WORLD_HEAD_COUNT);
    }
    const float residual = accepted_risk - predicted_mean;
    const float gain = clamp(
      min(uniforms.world_correction_gain, max(world_parameters[150], 0.0f)),
      0.0f,
      1.0f
    );
    mutable_world[NB_WORLD_EVENT_OPTION_BASE + component] = mix(
      mutable_world[NB_WORLD_EVENT_OPTION_BASE + component],
      accepted_risk,
      gain
    );
    mutable_world[NB_WORLD_EVENT_OPTION_BASE
      + NB_WORLD_EVENT_OPTION_DIMENSION + component] = residual;
    for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
      const uint head_index = NB_WORLD_EVENT_OPTION_BASE
        + (3u + head) * NB_WORLD_EVENT_OPTION_DIMENSION + component;
      mutable_world[head_index] = mix(
        mutable_world[head_index], accepted_risk, gain
      );
    }
    const uint aleatoric_index = NB_WORLD_EVENT_OPTION_BASE
      + 8u * NB_WORLD_EVENT_OPTION_DIMENSION + component;
    mutable_world[aleatoric_index] = mix(
      max(mutable_world[aleatoric_index], 0.0f),
      residual * residual,
      gain * clamp(world_parameters[152], 0.0f, 1.0f)
    );
  }
  if (uniforms.neuromodulator_count > 2u) {
    device const NBActiveSensingEfficacyRecord *sensing_states =
      reinterpret_cast<device const NBActiveSensingEfficacyRecord *>(
        hot_state + uniforms.active_sensing_efficacy_offset
      );
    float usable_information = 0.0f;
    uint sensing_count = 0u;
    for (uint channel = 0u; channel < uniforms.active_sensing_count; ++channel) {
      const NBActiveSensingEfficacyRecord sensing = sensing_states[channel];
      if ((sensing.flags & NB_ACCEPTED_STATE_VALID) == 0u
          || sensing.allocation <= 0.0f) continue;
      usable_information += clamp(
        sensing.realized_information_gain, 0.0f, 1.0f
      );
      sensing_count += 1u;
    }
    neuromodulators[2].value = sensing_count > 0u
      ? usable_information / float(sensing_count) : 0.0f;
    neuromodulators[2].kind = 3u;
    neuromodulators[2].flags = NB_ACCEPTED_STATE_VALID;
  }
  if (uniforms.neuromodulator_count > 1u) {
    neuromodulators[1].value = max(error, mean_external_disturbance);
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
    if (uniforms.workspace_dimension > 2u) {
      workspace[base + 2u] = mean_agency;
    }
    if (uniforms.workspace_dimension > 3u) {
      workspace[base + 3u] = mean_external_disturbance;
    }
    NBWorkspaceMetadataRecord token = metadata[2];
    token.identifier = (uniforms.target_timestamp_microseconds << 8) | 3ul;
    token.source_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    token.last_refresh_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    token.provenance_record_identifier = uniforms.physics_state_fingerprint;
    token.kind_and_source = 7u | (50u << 16);
    token.confidence = clamp(
      min(1.0f - error, mean_agency), 0.0f, 1.0f
    );
    metadata[2] = token;
  }
  control->unsupported_uncertainty = max(
    max(epistemic * max(world_parameters[157], 0.0f), aleatoric),
    mean_external_disturbance
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
  device const NBAcceptedProtectiveCommandRecord *protective_command
    [[buffer(8)]],
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
  const float physiological_critical = nb_accepted_fast_autonomic_critical(
    hot_state, uniforms
  );
  const float protective_risk = nb_accepted_protective_command_risk(
    protective_command, uniforms
  );
  const float3 embodied_risk = nb_accepted_embodied_risk(
    hot_state, uniforms, max(physiological_critical, protective_risk)
  );
  const float accepted_damage = max(
    clamp(control->selected_damage_cvar, 0.0f, 1.0f),
    max(embodied_risk.x, embodied_risk.y)
  );

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
    phase->maximum_damage, accepted_damage
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
    trace->maximum_damage, accepted_damage
  );
  trace->cumulative_effort += max(control->predicted_effort, 0.0f);
  trace->mean_uncertainty = mix(
    trace->mean_uncertainty, control->unsupported_uncertainty, trace_rate
  );
  trace->final_progress = control->progress;
  if (control->progress >= 0.99f) trace->flags |= NB_ACCEPTED_TRACE_COMPLETE;
}

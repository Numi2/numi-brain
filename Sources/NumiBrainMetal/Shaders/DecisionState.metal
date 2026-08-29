#include <metal_stdlib>
using namespace metal;

constant uint NB_CONTROL_MODE_REFLEX = 1u;
constant uint NB_CONTROL_MODE_PROCEDURAL = 2u;
constant uint NB_CONTROL_MODE_PLANNING = 3u;
constant uint NB_CONTROL_FLAG_VALID = 1u;
constant uint NB_CONTROL_FLAG_HYPERDIRECT_STOP = 1u << 1;
constant uint NB_CEREBELLAR_PREDICTION_VALID = 1u << 5;
constant ulong NB_INNATE_OPTION_NAMESPACE = 0x8000000000000000ul;
constant uint NB_OPTION_PROPOSAL_LOCOMOTION = 1u;
constant uint NB_OPTION_PROPOSAL_ACTIVE_SENSING = 4u;
constant uint NB_OPTION_PROPOSAL_EXPLORATION = 7u;
constant uint NB_CPG_OUTPUT_SOMATIC_SYNERGY = 1u;
constant uint NB_CPG_OUTPUT_AUTONOMIC_CHANNEL = 2u;
constant uint NB_ACTUATOR_COMMAND_MUSCLE_EXCITATION = 1u;
constant uint NB_OPTION_PROPOSAL_REST_RECOVERY = 3u;
constant ulong NB_REST_OPTION_IDENTIFIER = NB_INNATE_OPTION_NAMESPACE | 4ul;
constant uint NB_WORLD_EVENT_OPTION_BASE = 5760u;
constant uint NB_WORLD_EVENT_OPTION_DIMENSION = 256u;
constant uint NB_WORLD_HEAD_COUNT = 5u;
constant uint NB_WORLD_RECEPTOR_DIMENSION = 128u;

struct NBDecisionUniforms {
  ulong target_timestamp_microseconds;
  ulong recurrent_offset;
  ulong workspace_offset;
  ulong workspace_metadata_offset;
  ulong world_model_offset;
  ulong drive_offset;
  ulong neuromodulation_offset;
  ulong control_header_offset;
  ulong candidate_offset;
  ulong plan_offset;
  ulong motor_offset;
  ulong synergy_offset;
  ulong cerebellar_offset;
  ulong spinal_offset;
  ulong autonomic_offset;
  ulong somatic_output_offset;
  ulong active_sensing_offset;
  ulong spatial_transform_offset;
  ulong object_slot_offset;
  ulong internal_action_offset;
  ulong developmental_state_offset;
  ulong cerebellar_expert_memory_offset;
  ulong event_queue_offset;
  ulong cpg_state_offset;
  ulong descending_somatic_baseline_offset;
  ulong parameter_version_fingerprint;
  ulong reserved_identity;
  uint recurrent_scalar_count;
  uint workspace_scalar_count;
  uint workspace_capacity;
  uint workspace_dimension;
  uint world_model_scalar_count;
  uint drive_count;
  uint neuromodulator_count;
  uint candidate_capacity;
  uint plan_capacity;
  uint actuator_count;
  uint synergy_count;
  uint active_cerebellar_expert_count;
  uint autonomic_dimension;
  uint active_sensing_dimension;
  uint communication_synergy_descriptor_offset;
  uint active_sensing_descriptor_offset;
  uint communication_descriptor_count;
  uint spatial_transform_count;
  uint object_slot_count;
  uint internal_action_capacity;
  uint maximum_planning_horizon;
  uint cpg_oscillator_count;
  uint cpg_coupling_count;
  uint event_capacity;
  float risk_weight;
  float damage_risk_budget;
  float switching_margin;
  float curiosity_weight;
  float planning_cost_weight;
  float motor_gain;
  float stiffness_gain;
  float damping_gain;
  ulong observation_offset;
  uint observation_count;
  uint cerebellar_expert_capacity;
  ulong fast_cerebellar_state_offset;
  ulong body_belief_offset;
  ulong somatic_effector_belief_offset;
  uint body_belief_count;
  uint somatic_effector_belief_count;
  ulong active_sensing_efficacy_offset;
  uint actuator_command_kind;
  uint reserved_motor_abi;
};

struct NBDriveRecord {
  float level;
  float viable_minimum;
  float viable_maximum;
  float priority_weight;
  float estimated_rate;
  float deficit;
  float potential;
  uint kind;
};

struct NBNeuromodulatorRecord {
  float value;
  float decay_time_constant_seconds;
  uint kind;
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

struct NBPlanStepRecord {
  ulong option_identifier;
  ulong goal_identifier;
  float objective_value;
  float damage_cvar;
  float epistemic_uncertainty;
  float predicted_effort;
  float predicted_information_gain;
  float duration_seconds;
  float predicted_drive_change;
  float admissibility;
  uint sequence;
  uint flags;
  uint parameter_count;
  uint reserved;
  float predicted_state[16];
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

struct NBSpinalStateRecord {
  float reflex_output;
  float cpg_output;
  float motor_neuron_state;
  float final_excitation;
};

struct NBAutonomicCommandRecord {
  float command;
  float target;
  float confidence;
  uint flags;
};

struct NBCommunicationChannelDescriptor {
  uint effector_kind;
  uint local_channel_index;
  float gain;
  uint flags;
};

struct NBAutonomicChannelDescriptor {
  uint channel_identifier;
  uint kind;
  uint flags;
  uint critical_receptor_count;
  uint critical_receptors[4];
  float emergency_target;
  float emergency_gain;
  float cpg_gain;
  float reserved;
};

struct NBActiveSensingChannelDescriptor {
  uint channel_identifier;
  uint modality;
  uint modality_local_identifier;
  uint flags;
};

struct NBCPGOscillatorDescriptor {
  uint identifier;
  uint output_synergy_identifier;
  float natural_frequency_hertz;
  float duty_factor;
  ulong sensory_reset_mask;
  ulong output_kind;
};

struct NBCPGCouplingDescriptor {
  uint source_oscillator_index;
  uint destination_oscillator_index;
  float phase_offset;
  float gain;
};

struct NBCPGStateRecord {
  float phase;
  float output;
  float effective_frequency_hertz;
  float duty_factor;
  ulong timestamp_microseconds;
  ulong sensory_reset_mask;
  float reset_magnitude;
  float output_gain;
  float decision_output;
  float reserved_float;
  uint output_synergy_identifier;
  uint oscillator_identifier;
  uint flags;
  uint output_kind;
};

struct NBFastCerebellarStateRecord {
  ulong last_observation_timestamp_microseconds;
  ulong state_timestamp_microseconds;
  float learned_load_gain;
  float predicted_load;
  float observed_load;
  float prediction_error;
  float correction;
  float desired_load;
  uint update_count;
  uint flags;
  float reserved[4];
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

struct NBSpatialTransformRecord {
  uint source_frame;
  uint destination_frame;
  uint flags;
  uint reserved;
  float translation[4];
  float rotation[4];
  float linear_velocity[4];
  float angular_velocity[4];
  float uncertainty;
  float confidence;
  ulong last_evidence_timestamp_microseconds;
};

struct NBObjectSlotRecord {
  ulong identifier;
  ulong last_seen_timestamp_microseconds;
  uint format_version;
  uint flags;
  float existence_probability;
  float identity_confidence;
  float visibility;
  float uncertainty;
  float pose[4];
  float velocity[4];
  float affordances[8];
  float latent[102];
};

struct NBInternalActionRecord {
  ulong target_identifier;
  ulong timestamp_microseconds;
  uint kind;
  uint flags;
  uint parameter_count;
  uint reserved;
  float priority;
  float confidence;
  float parameters[6];
};

struct NBDevelopmentalHeader {
  uint format_version;
  uint stage;
  uint stage_count;
  uint flags;
  ulong developmental_age_microseconds;
  ulong last_transition_timestamp_microseconds;
  float maturation_progress;
  float sensor_precision_multiplier;
  float muscle_strength_multiplier;
  float replay_allocation_multiplier;
  float learning_rate_multiplier;
  uint workspace_capacity;
  uint planning_horizon_steps;
  uint module_count;
  uint evidence_count;
  ulong species_template_fingerprint;
  ulong accepted_physics_state_fingerprint;
  ulong reserved[21];
};

static_assert(sizeof(NBDecisionUniforms) == 408);
static_assert(sizeof(NBDriveRecord) == 32);
static_assert(sizeof(NBNeuromodulatorRecord) == 16);
static_assert(sizeof(NBWorkspaceMetadataRecord) == 64);
static_assert(sizeof(NBControlHeader) == 128);
static_assert(sizeof(NBOptionCandidateRecord) == 128);
static_assert(sizeof(NBPlanStepRecord) == 128);
static_assert(sizeof(NBMotorCommandRecord) == 32);
static_assert(sizeof(NBCerebellarExpertRecord) == 256);
static_assert(sizeof(NBSpinalStateRecord) == 16);
static_assert(sizeof(NBAutonomicCommandRecord) == 16);
static_assert(sizeof(NBCommunicationChannelDescriptor) == 16);
static_assert(sizeof(NBAutonomicChannelDescriptor) == 48);
static_assert(sizeof(NBActiveSensingChannelDescriptor) == 16);
static_assert(sizeof(NBCPGOscillatorDescriptor) == 32);
static_assert(sizeof(NBCPGCouplingDescriptor) == 16);
static_assert(sizeof(NBCPGStateRecord) == 64);
static_assert(sizeof(NBFastCerebellarStateRecord) == 64);
static_assert(sizeof(NBEventQueueHeader) == 32);
static_assert(sizeof(NBReceptorEventRecord) == 32);
static_assert(sizeof(NBActiveSensingCommandRecord) == 16);
static_assert(sizeof(NBActiveSensingEfficacyRecord) == 32);
static_assert(sizeof(NBSpatialTransformRecord) == 96);
static_assert(sizeof(NBObjectSlotRecord) == 512);
static_assert(sizeof(NBInternalActionRecord) == 64);
static_assert(sizeof(NBDevelopmentalHeader) == 256);

inline bool nb_uses_muscle_excitation(const uint actuator_command_kind) {
  return actuator_command_kind == NB_ACTUATOR_COMMAND_MUSCLE_EXCITATION;
}

/// Converts an unconstrained policy logit into the species' normalized neural
/// command space. Biological muscle excitation is zero-based. Other actuator
/// kinds are signed around 0.5 so a zero logit is an exact neutral command.
inline float nb_motor_drive_from_logit(
  const float logit,
  const uint actuator_command_kind)
{
  const float signed_drive = tanh(logit);
  return nb_uses_muscle_excitation(actuator_command_kind)
    ? clamp(signed_drive, 0.0f, 1.0f)
    : fma(0.5f, signed_drive, 0.5f);
}

/// Applies gain or inhibition without moving a non-muscle command's neutral.
inline float nb_scale_motor_drive(
  const float drive,
  const float scale,
  const uint actuator_command_kind)
{
  const float bounded_scale = max(scale, 0.0f);
  return nb_uses_muscle_excitation(actuator_command_kind)
    ? drive * bounded_scale
    : fma(drive - 0.5f, bounded_scale, 0.5f);
}

inline float nb_motor_neutral(const uint actuator_command_kind) {
  return nb_uses_muscle_excitation(actuator_command_kind) ? 0.0f : 0.5f;
}

inline float nb_motor_feature(
  const float drive,
  const uint actuator_command_kind)
{
  return nb_uses_muscle_excitation(actuator_command_kind)
    ? clamp(drive, 0.0f, 1.0f)
    : clamp(fma(2.0f, drive, -1.0f), -1.0f, 1.0f);
}

inline uint nb_active_candidate_limit(
  constant NBDecisionUniforms &uniforms,
  device const NBDevelopmentalHeader *development)
{
  const uint memory_candidate_limit = 10u
    + (uniforms.workspace_capacity > 3u
      ? uniforms.workspace_capacity - 3u
      : 0u);
  return min(
    min(uniforms.candidate_capacity, memory_candidate_limit),
    max(4u, min(uniforms.candidate_capacity, 4u + development->stage * 3u))
  );
}

inline ulong nb_goal_identifier(uint origin, ulong source_identifier) {
  return (ulong(origin) << 56) | ((source_identifier + 1ul)
    & 0x00fffffffffffffful);
}

inline float3 nb_rotate_vector(float3 vector, float4 quaternion) {
  const float norm_squared = dot(quaternion, quaternion);
  if (norm_squared <= 1.0e-8f) return vector;
  const float4 normalized = quaternion * rsqrt(norm_squared);
  const float3 twice_cross = 2.0f * cross(normalized.xyz, vector);
  return vector + normalized.w * twice_cross
    + cross(normalized.xyz, twice_cross);
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

inline float nb_embodied_self_risk(
  device const uchar *hot_state,
  constant NBDecisionUniforms &uniforms)
{
  float risk = 0.0f;
  device const uchar *body_belief = hot_state + uniforms.body_belief_offset;
  for (uint body_index = 0u;
      body_index < uniforms.body_belief_count; ++body_index) {
    device const float *body = reinterpret_cast<device const float *>(
      body_belief + ulong(body_index) * 256ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      body + 16
    );
    if ((identity[3] & 1ul) == 0ul) continue;
    risk = max(
      risk,
      max(clamp(body[5], 0.0f, 1.0f), clamp(body[7], 0.0f, 1.0f))
    );
  }
  device const uchar *effector_belief =
    hot_state + uniforms.somatic_effector_belief_offset;
  for (uint index = 0u;
      index < uniforms.somatic_effector_belief_count; ++index) {
    device const float *effector = reinterpret_cast<device const float *>(
      effector_belief + ulong(index) * 192ul
    );
    risk = max(risk, clamp(effector[9], 0.0f, 1.0f));
  }
  return risk;
}

inline ulong nb_interrupt_mask_for_event_kind(uint kind) {
  switch (kind) {
    case 3u: return 1ul << 3u;
    case 5u: return 1ul << 2u;
    case 6u: return 1ul << 5u;
    case 7u: return 1ul << 6u;
    case 8u: return 1ul << 0u;
    case 9u: return 1ul << 1u;
    case 10u: return 1ul << 7u;
    case 11u: return 1ul << 8u;
    case 12u: return 1ul << 4u;
    case 13u: return 1ul << 9u;
    default: return 0ul;
  }
}

kernel void generate_active_goal_state(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  device const float *value_parameters [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u) return;
  device const NBDriveRecord *drives = reinterpret_cast<device const NBDriveRecord *>(
    hot_state + uniforms.drive_offset
  );
  device float *workspace = reinterpret_cast<device float *>(
    hot_state + uniforms.workspace_offset
  );
  device NBWorkspaceMetadataRecord *metadata =
    reinterpret_cast<device NBWorkspaceMetadataRecord *>(
      hot_state + uniforms.workspace_metadata_offset
    );
  device NBControlHeader *header = reinterpret_cast<device NBControlHeader *>(
    hot_state + uniforms.control_header_offset
  );
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  const uint active_workspace_capacity = min(
    uniforms.workspace_capacity, development->workspace_capacity
  );
  const ulong previous_goal_identifier = header->active_goal_identifier;
  ulong goal_identifiers[4] = {};
  uint goal_origins[4] = {};
  uint goal_sources[4] = {};
  float goal_priorities[4] = {-INFINITY, -INFINITY, -INFINITY, -INFINITY};
  for (uint drive_index = 0u; drive_index < uniforms.drive_count; ++drive_index) {
    uint origin = 1u;
    if (drive_index == 8u) origin = 5u;
    if (drive_index == 9u) origin = 4u;
    if (drive_index == 10u) origin = 2u;
    if (drive_index == 5u || drive_index == 6u || drive_index == 11u) origin = 6u;
    float priority = drives[drive_index].priority_weight
      * max(drives[drive_index].deficit, 0.0f);
    priority *= max(value_parameters[min(origin - 1u, 7u)], 0.0f);
    if (origin == 6u) priority += clamp(drives[drive_index].level, 0.0f, 1.0f);
    const ulong identifier = nb_goal_identifier(origin, ulong(drive_index));
    if (identifier == header->active_goal_identifier) priority += 0.1f;
    for (uint rank = 0u; rank < 4u; ++rank) {
      if (priority > goal_priorities[rank]
          || (priority == goal_priorities[rank]
            && identifier < goal_identifiers[rank])) {
        for (uint shift = 3u; shift > rank; --shift) {
          goal_identifiers[shift] = goal_identifiers[shift - 1u];
          goal_origins[shift] = goal_origins[shift - 1u];
          goal_sources[shift] = goal_sources[shift - 1u];
          goal_priorities[shift] = goal_priorities[shift - 1u];
        }
        goal_identifiers[rank] = identifier;
        goal_origins[rank] = origin;
        goal_sources[rank] = drive_index;
        goal_priorities[rank] = priority;
        break;
      }
    }
  }
  for (uint slot = 0u; slot < active_workspace_capacity; ++slot) {
    const NBWorkspaceMetadataRecord token = metadata[slot];
    const uint source_module = token.kind_and_source >> 16;
    const uint token_kind = token.kind_and_source & 0xffffu;
    const bool prospective = source_module == 61u;
    const bool social = source_module == 44u;
    const bool communication = source_module == 51u;
    const bool active_plan = source_module == 25u && token_kind == 9u;
    if ((!prospective && !social && !communication && !active_plan)
        || token.entity_identifier == 0ul) continue;
    const uint origin = prospective ? 3u
      : (communication ? 8u : (active_plan ? 7u : 4u));
    const ulong identifier = nb_goal_identifier(origin, token.entity_identifier);
    float priority = clamp(token.confidence, 0.0f, 1.0f)
      * max(value_parameters[min(origin - 1u, 7u)], 0.0f);
    if (prospective) priority += 0.25f;
    if (social && uniforms.drive_count > 9u) {
      priority += 0.25f * drives[9].deficit;
    }
    if (identifier == header->active_goal_identifier) priority += 0.1f;
    for (uint rank = 0u; rank < 4u; ++rank) {
      if (priority > goal_priorities[rank]
          || (priority == goal_priorities[rank]
            && identifier < goal_identifiers[rank])) {
        for (uint shift = 3u; shift > rank; --shift) {
          goal_identifiers[shift] = goal_identifiers[shift - 1u];
          goal_origins[shift] = goal_origins[shift - 1u];
          goal_sources[shift] = goal_sources[shift - 1u];
          goal_priorities[shift] = goal_priorities[shift - 1u];
        }
        goal_identifiers[rank] = identifier;
        goal_origins[rank] = origin;
        goal_sources[rank] = slot;
        goal_priorities[rank] = priority;
        break;
      }
    }
  }
  header->active_goal_identifier = goal_identifiers[0];
  if (previous_goal_identifier != goal_identifiers[0]) {
    header->progress = 0.0f;
  }
  for (uint rank = 0u; rank < 4u; ++rank) {
    const uint slot = 7u + rank;
    if (slot >= active_workspace_capacity) break;
    const uint base = slot * uniforms.workspace_dimension;
    for (uint feature = 0u; feature < uniforms.workspace_dimension; ++feature) {
      float value = 0.0f;
      if (feature == 0u) value = max(goal_priorities[rank], 0.0f);
      if (feature == 1u) value = float(goal_origins[rank]) / 9.0f;
      if (feature == 2u) value = float(goal_sources[rank]) / 64.0f;
      if (feature == 3u) value = rank == 0u ? 1.0f : 0.0f;
      workspace[base + feature] = value;
    }
    NBWorkspaceMetadataRecord token = {};
    token.identifier = (uniforms.target_timestamp_microseconds << 8)
      | ulong(slot + 1u);
    token.source_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    token.last_refresh_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    token.entity_identifier = goal_identifiers[rank];
    token.goal_identifier = goal_identifiers[rank];
    token.kind_and_source = 2u | (48u << 16);
    token.confidence = clamp(goal_priorities[rank], 0.0f, 1.0f);
    metadata[slot] = token;
  }
}

/// Materializes the prior committed workspace-write request after ordinary
/// goal publication. Slot ten is the reserved internal-action handoff in the
/// complete workspace; reduced developmental capacities use their final
/// non-foundational slot.
kernel void apply_internal_workspace_write(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.workspace_dimension == 0u) return;
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  const uint active_capacity = min(
    uniforms.workspace_capacity, development->workspace_capacity
  );
  if (active_capacity <= 2u) return;
  device const NBInternalActionRecord *internal_actions =
    reinterpret_cast<device const NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  const NBInternalActionRecord request = internal_actions[1];
  if (request.kind != 2u || (request.flags & NB_CONTROL_FLAG_VALID) == 0u
      || request.target_identifier == 0ul) return;
  const uint slot = min(active_capacity, 11u) - 1u;
  const uint base = slot * uniforms.workspace_dimension;
  device float *workspace = reinterpret_cast<device float *>(
    hot_state + uniforms.workspace_offset
  );
  for (uint feature = 0u; feature < uniforms.workspace_dimension; ++feature) {
    float value = feature < min(request.parameter_count, 6u)
      ? request.parameters[feature] : 0.0f;
    if (feature == 6u) value = request.priority;
    if (feature == 7u) value = request.confidence;
    workspace[base + feature] = value;
  }
  device NBWorkspaceMetadataRecord *metadata =
    reinterpret_cast<device NBWorkspaceMetadataRecord *>(
      hot_state + uniforms.workspace_metadata_offset
    );
  NBWorkspaceMetadataRecord token = {};
  token.identifier = (uniforms.target_timestamp_microseconds << 8u)
    | ulong(slot + 1u);
  token.source_timestamp_microseconds = request.timestamp_microseconds;
  token.last_refresh_timestamp_microseconds =
    uniforms.target_timestamp_microseconds;
  token.entity_identifier = request.target_identifier;
  token.goal_identifier = request.target_identifier;
  token.kind_and_source = 9u | (25u << 16u);
  token.confidence = clamp(request.confidence * request.priority, 0.0f, 1.0f);
  metadata[slot] = token;
}

kernel void propose_dynamic_options(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  device const float *value_parameters [[buffer(2)]],
  device const float *policy_parameters [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  const uint candidate_limit = nb_active_candidate_limit(uniforms, development);
  if (gid >= uniforms.candidate_capacity) return;
  device const float *recurrent = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  device const float *workspace = reinterpret_cast<device const float *>(
    hot_state + uniforms.workspace_offset
  );
  device const NBWorkspaceMetadataRecord *workspace_metadata =
    reinterpret_cast<device const NBWorkspaceMetadataRecord *>(
      hot_state + uniforms.workspace_metadata_offset
    );
  device const NBSpatialTransformRecord *spatial_transforms =
    reinterpret_cast<device const NBSpatialTransformRecord *>(
      hot_state + uniforms.spatial_transform_offset
    );
  device const NBObjectSlotRecord *object_slots =
    reinterpret_cast<device const NBObjectSlotRecord *>(
      hot_state + uniforms.object_slot_offset
    );
  device const NBDriveRecord *drives = reinterpret_cast<device const NBDriveRecord *>(
    hot_state + uniforms.drive_offset
  );
  device const NBNeuromodulatorRecord *neuromodulators =
    reinterpret_cast<device const NBNeuromodulatorRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  device const NBControlHeader *control = reinterpret_cast<device const NBControlHeader *>(
    hot_state + uniforms.control_header_offset
  );
  device NBOptionCandidateRecord *candidates =
    reinterpret_cast<device NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  if (gid >= candidate_limit) {
    NBOptionCandidateRecord inactive = {};
    candidates[gid] = inactive;
    return;
  }
  const uint procedural_base = candidate_limit > 4u
    ? max(10u, candidate_limit - 4u)
    : candidate_limit;
  if (gid >= procedural_base) {
    const uint workspace_slot = 3u + (gid - procedural_base);
    if (workspace_slot >= uniforms.workspace_capacity) {
      NBOptionCandidateRecord inactive = {};
      candidates[gid] = inactive;
      return;
    }
    const NBWorkspaceMetadataRecord memory_token =
      workspace_metadata[workspace_slot];
    const uint source_module = memory_token.kind_and_source >> 16;
    if (source_module != 60u || memory_token.entity_identifier == 0ul
        || memory_token.confidence <= 0.0f) {
      NBOptionCandidateRecord inactive = {};
      candidates[gid] = inactive;
      return;
    }
    NBOptionCandidateRecord learned;
    learned.option_identifier = memory_token.entity_identifier;
    learned.goal_identifier = memory_token.goal_identifier != 0ul
      ? memory_token.goal_identifier
      : control->active_goal_identifier;
    const uint workspace_base = workspace_slot * uniforms.workspace_dimension;
    const bool structured_skill = uniforms.workspace_dimension >= 80u;
    float initiation_dot = 0.0f;
    float initiation_norm = 1.0e-6f;
    float recurrent_norm = 1.0e-6f;
    for (uint component = 0u; component < 16u; ++component) {
      const float initiation = structured_skill
        ? workspace[workspace_base + 16u + component] : 0.0f;
      const float state = recurrent[component % uniforms.recurrent_scalar_count];
      initiation_dot += initiation * state;
      initiation_norm += initiation * initiation;
      recurrent_norm += state * state;
    }
    const float initiation_match = structured_skill
      ? clamp(0.5f + 0.5f * initiation_dot
          * rsqrt(initiation_norm * recurrent_norm), 0.0f, 1.0f)
      : memory_token.confidence;
    float termination_logit = 0.0f;
    for (uint component = 0u; component < 8u; ++component) {
      termination_logit += (structured_skill
        ? workspace[workspace_base + 32u + component] : 0.0f)
        * recurrent[component % uniforms.recurrent_scalar_count];
    }
    const float termination_probability = structured_skill
      ? max(
          1.0f / (1.0f + exp(-termination_logit / 8.0f)),
          workspace[workspace_base + 78u]
        )
      : 0.0f;
    learned.task_value = structured_skill
      ? workspace[workspace_base + 59u] + workspace[workspace_base + 65u]
        - max(workspace[workspace_base + 62u], 0.0f)
      : workspace[workspace_base % max(uniforms.workspace_scalar_count, 1u)];
    learned.homeostatic_value = structured_skill
      ? workspace[workspace_base + 64u] : 0.0f;
    learned.social_value = structured_skill
      ? workspace[workspace_base + 66u] : 0.0f;
    learned.information_gain = structured_skill
      ? max(workspace[workspace_base + 67u], 0.0f)
      : 0.0f;
    learned.damage_cvar = structured_skill
      ? clamp(workspace[workspace_base + 57u], 0.0f, 1.0f)
      : clamp(1.0f - memory_token.confidence, 0.0f, 1.0f);
    learned.effort_cost = structured_skill
      ? max(workspace[workspace_base + 58u], 0.0f) : 0.02f;
    learned.switching_cost = 0.025f;
    learned.competence = clamp(
      memory_token.confidence
        * (structured_skill ? workspace[workspace_base + 56u] : 1.0f)
        * initiation_match,
      0.0f,
      1.0f
    );
    if (structured_skill
        && control->active_option_identifier == learned.option_identifier) {
      const float termination_confidence = clamp(
        workspace[workspace_base + 61u], 0.0f, 1.0f
      );
      learned.task_value -= termination_probability * termination_confidence;
      learned.competence *= 1.0f
        - 0.5f * termination_probability * termination_confidence;
    }
    learned.proposal_kind = 10u;
    learned.source_module = 60u;
    learned.flags = NB_CONTROL_FLAG_VALID;
    learned.parameter_count = 16u;
    for (uint index = 0u; index < 16u; ++index) {
      learned.parameters[index] = workspace[
        workspace_base + index % max(uniforms.workspace_dimension, 1u)
      ];
    }
    candidates[gid] = learned;
    return;
  }
  if (gid >= 10u) {
    const uint object_index = gid - 10u;
    if (object_index >= uniforms.object_slot_count) {
      NBOptionCandidateRecord inactive = {};
      candidates[gid] = inactive;
      return;
    }
    const NBObjectSlotRecord object = object_slots[object_index];
    if (object.identifier == 0ul || (object.flags & NB_CONTROL_FLAG_VALID) == 0u
        || object.existence_probability <= 0.01f) {
      NBOptionCandidateRecord inactive = {};
      candidates[gid] = inactive;
      return;
    }
    uint strongest_affordance = 0u;
    float strongest_affordance_value = object.affordances[0];
    for (uint affordance = 1u; affordance < 8u; ++affordance) {
      if (object.affordances[affordance] > strongest_affordance_value) {
        strongest_affordance = affordance;
        strongest_affordance_value = object.affordances[affordance];
      }
    }
    const float safety = uniforms.drive_count > 11u
      ? clamp(drives[11].level, 0.0f, 1.0f) : 0.0f;
    const float physiological_need =
      (uniforms.drive_count > 0u ? drives[0].deficit : 0.0f)
      + (uniforms.drive_count > 1u ? drives[1].deficit : 0.0f);
    const float distance = length(float3(
      object.pose[0], object.pose[1], object.pose[2]
    ));
    NBOptionCandidateRecord affordance_option = {};
    affordance_option.option_identifier = 0x4000000000000000ul
      | (object.identifier & 0x0fffffffffffff00ul)
      | ulong(strongest_affordance + 1u);
    affordance_option.goal_identifier = control->active_goal_identifier;
    affordance_option.task_value = max(strongest_affordance_value, 0.0f)
      * object.existence_probability * value_parameters[0];
    affordance_option.homeostatic_value = max(object.affordances[0], 0.0f)
      * physiological_need * value_parameters[1];
    affordance_option.social_value = 0.0f;
    affordance_option.information_gain = object.uncertainty
      * value_parameters[3];
    affordance_option.damage_cvar = clamp(
      safety + 0.25f * object.uncertainty
        + 0.25f * max(-strongest_affordance_value, 0.0f),
      0.0f,
      1.0f
    );
    affordance_option.effort_cost = clamp(0.02f * distance, 0.0f, 1.0f);
    affordance_option.switching_cost = 0.025f;
    affordance_option.competence = clamp(
      object.existence_probability * object.identity_confidence
        * (1.0f - object.uncertainty),
      0.0f,
      1.0f
    );
    affordance_option.proposal_kind = 20u + strongest_affordance;
    affordance_option.source_module = 71u;
    affordance_option.flags = NB_CONTROL_FLAG_VALID;
    affordance_option.parameter_count = 16u;
    for (uint component = 0u; component < 4u; ++component) {
      affordance_option.parameters[component] = object.pose[component];
      affordance_option.parameters[4u + component] = object.velocity[component];
    }
    for (uint component = 0u; component < 8u; ++component) {
      affordance_option.parameters[8u + component] = object.affordances[component];
    }
    candidates[gid] = affordance_option;
    return;
  }
  NBOptionCandidateRecord candidate;
  candidate.option_identifier = NB_INNATE_OPTION_NAMESPACE | ulong(gid + 1u);
  candidate.goal_identifier = control->active_goal_identifier;
  const float task_signal = workspace[gid % uniforms.workspace_scalar_count];
  const float homeostatic = drives[gid % uniforms.drive_count].deficit;
  const float safety = uniforms.drive_count > 11u ? drives[11].level : 0.0f;
  const float pain = uniforms.drive_count > 5u ? drives[5].level : 0.0f;
  const float epistemic = uniforms.neuromodulator_count > 3u
    ? neuromodulators[3].value
    : 0.0f;
  const float usable_information_opportunity = uniforms.drive_count > 8u
    ? clamp(drives[8].level, 0.0f, 1.0f) : 0.0f;
  const bool information_option = gid == NB_OPTION_PROPOSAL_ACTIVE_SENSING
    || gid == NB_OPTION_PROPOSAL_EXPLORATION;
  const bool curiosity_goal = (control->active_goal_identifier >> 56u) == 5ul;
  candidate.task_value = task_signal * value_parameters[0];
  const float fatigue_deficit = uniforms.drive_count > 4u ? drives[4].deficit : 0.0f;
  const float injury_deficit = uniforms.drive_count > 6u ? drives[6].deficit : 0.0f;
  const float sleep_deficit = uniforms.drive_count > 7u ? drives[7].deficit : 0.0f;
  candidate.homeostatic_value = gid == NB_OPTION_PROPOSAL_REST_RECOVERY
    ? (fatigue_deficit + injury_deficit + sleep_deficit) * value_parameters[1]
    : (information_option
      ? 0.0f
      : -policy_parameters[8] * homeostatic * value_parameters[1]);
  if (curiosity_goal && information_option && uniforms.drive_count > 8u) {
    candidate.homeostatic_value += drives[8].deficit * value_parameters[1];
  }
  float social_token_confidence = 0.0f;
  uint social_token_source = 0u;
  uint social_workspace_base = 0u;
  if (uniforms.workspace_capacity > 11u) {
    const NBWorkspaceMetadataRecord social_token = workspace_metadata[11];
    social_token_source = social_token.kind_and_source >> 16;
    const uint social_token_kind = social_token.kind_and_source & 0xffffu;
    if ((social_token_source == 44u || social_token_source == 51u)
        && (social_token_kind == 4u || social_token_kind == 10u)
        && social_token.entity_identifier != 0ul) {
      social_token_confidence = clamp(social_token.confidence, 0.0f, 1.0f);
      social_workspace_base = 11u * uniforms.workspace_dimension;
    }
  }
  candidate.social_value = gid == 8u && uniforms.drive_count > 9u
    ? (drives[9].deficit + social_token_confidence) * value_parameters[2]
    : 0.0f;
  if (gid == 8u && social_token_source == 51u) {
    candidate.task_value += social_token_confidence * value_parameters[0];
  }
  candidate.information_gain = information_option
    ? max(epistemic, usable_information_opportunity) * value_parameters[3]
    : 0.0f;
  if (gid == 8u && social_token_confidence > 0.0f
      && uniforms.workspace_dimension > 6u) {
    candidate.information_gain = max(
      candidate.information_gain,
      clamp(workspace[social_workspace_base + 6u], 0.0f, 1.0f)
        * value_parameters[3]
    );
  }
  candidate.damage_cvar = clamp(safety + pain * (gid > 4u ? 0.5f : 0.1f), 0.0f, 1.0f);
  candidate.effort_cost = gid == NB_OPTION_PROPOSAL_REST_RECOVERY
    ? 0.0f
    : 0.02f * float(gid % 8u);
  candidate.switching_cost = gid == 0u ? 0.0f : 0.025f;
  candidate.competence = clamp(
    0.5f + 0.5f * recurrent[gid % uniforms.recurrent_scalar_count],
    0.0f,
    1.0f
  );
  candidate.proposal_kind = gid % 10u;
  candidate.source_module = information_option ? 65u : 72u;
  candidate.flags = NB_CONTROL_FLAG_VALID;
  candidate.parameter_count = 16u;
  for (uint index = 0u; index < 16u; ++index) {
    candidate.parameters[index] = gid == 8u && social_token_confidence > 0.0f
      ? workspace[
          social_workspace_base + index % max(uniforms.workspace_dimension, 1u)
        ]
      : recurrent[(gid * 16u + index) % uniforms.recurrent_scalar_count];
  }
  if (gid == 8u && social_token_confidence > 0.0f) {
    candidate.source_module = social_token_source;
    candidate.competence = max(candidate.competence, social_token_confidence);
    if (uniforms.spatial_transform_count > 4u
        && (spatial_transforms[4].flags & NB_CONTROL_FLAG_VALID) != 0u) {
      const NBSpatialTransformRecord sensor_to_body = spatial_transforms[4];
      const float3 sensor_relative = float3(
        candidate.parameters[8] - sensor_to_body.translation[0],
        candidate.parameters[9] - sensor_to_body.translation[1],
        candidate.parameters[10] - sensor_to_body.translation[2]
      );
      const float3 body_relative = nb_rotate_vector(
        sensor_relative,
        float4(
          sensor_to_body.rotation[0], sensor_to_body.rotation[1],
          sensor_to_body.rotation[2], sensor_to_body.rotation[3]
        )
      );
      candidate.parameters[8] = body_relative.x;
      candidate.parameters[9] = body_relative.y;
      candidate.parameters[10] = body_relative.z;
      candidate.competence *= sensor_to_body.confidence;
    }
  }
  candidates[gid] = candidate;
}

kernel void simulate_candidate_option_outcomes(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  device const float *value_parameters [[buffer(2)]],
  device const float *policy_parameters [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  const uint candidate_limit = nb_active_candidate_limit(uniforms, development);
  if (gid >= uniforms.candidate_capacity
      || uniforms.maximum_planning_horizon == 0u) return;
  device const NBOptionCandidateRecord *candidates =
    reinterpret_cast<device const NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  device const float *world = reinterpret_cast<device const float *>(
    hot_state + uniforms.world_model_offset
  );
  device NBPlanStepRecord *plans = reinterpret_cast<device NBPlanStepRecord *>(
    hot_state + uniforms.plan_offset
  );
  const uint active_horizon = min(
    max(development->planning_horizon_steps, 1u),
    uniforms.maximum_planning_horizon
  );
  const uint plan_base = gid * uniforms.maximum_planning_horizon;
  if (plan_base + uniforms.maximum_planning_horizon > uniforms.plan_capacity) return;
  if (gid >= candidate_limit
      || (candidates[gid].flags & NB_CONTROL_FLAG_VALID) == 0u) {
    for (uint step = 0u; step < uniforms.maximum_planning_horizon; ++step) {
      NBPlanStepRecord inactive = {};
      plans[plan_base + step] = inactive;
    }
    return;
  }
  const bool structured_world_available = uniforms.world_model_scalar_count
    >= NB_WORLD_EVENT_OPTION_BASE + 9u * NB_WORLD_EVENT_OPTION_DIMENSION;
  const float embodied_self_risk = nb_embodied_self_risk(hot_state, uniforms);
  float rollout_state[16];
  for (uint component = 0u; component < 16u; ++component) {
    rollout_state[component] = candidates[gid].parameters[component];
  }
  float accumulated_objective = 0.0f;
  float accumulated_damage = 0.0f;
  float accumulated_effort = 0.0f;
  float accumulated_information = 0.0f;
  float accumulated_drive_change = 0.0f;
  uint selected_option = gid;
  for (uint step = 0u; step < uniforms.maximum_planning_horizon; ++step) {
    if (step >= active_horizon) {
      NBPlanStepRecord inactive = {};
      plans[plan_base + step] = inactive;
      continue;
    }
    if (step > 0u) {
      float best_followup_score = -INFINITY;
      uint best_followup = selected_option;
      for (uint candidate_index = 0u; candidate_index < candidate_limit;
          ++candidate_index) {
        const NBOptionCandidateRecord followup = candidates[candidate_index];
        if ((followup.flags & NB_CONTROL_FLAG_VALID) == 0u) continue;
        float compatibility = 0.0f;
        for (uint component = 0u; component < 4u; ++component) {
          compatibility += rollout_state[component]
            * followup.parameters[component] * 0.05f;
        }
        const float followup_score = value_parameters[0] * followup.task_value
          + value_parameters[1] * followup.homeostatic_value
          + value_parameters[2] * followup.social_value
          + value_parameters[3] * uniforms.curiosity_weight
            * followup.information_gain
          + compatibility - value_parameters[4] * uniforms.risk_weight
            * followup.damage_cvar
          - value_parameters[5] * followup.effort_cost
          - value_parameters[6] * followup.switching_cost;
        if (max(followup.damage_cvar, embodied_self_risk)
              <= uniforms.damage_risk_budget
            && (followup_score > best_followup_score
              || (followup_score == best_followup_score
                && candidate_index < best_followup))) {
          best_followup_score = followup_score;
          best_followup = candidate_index;
        }
      }
      selected_option = best_followup;
    }
    const NBOptionCandidateRecord candidate = candidates[selected_option];
    const uint world_component = (gid * uniforms.maximum_planning_horizon + step)
      % NB_WORLD_EVENT_OPTION_DIMENSION;
    float ensemble_mean = 0.0f;
    float head_values[NB_WORLD_HEAD_COUNT];
    for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
      const float prediction = structured_world_available
        ? world[NB_WORLD_EVENT_OPTION_BASE
            + (3u + head) * NB_WORLD_EVENT_OPTION_DIMENSION + world_component]
        : world[(world_component * NB_WORLD_HEAD_COUNT + head)
            % uniforms.world_model_scalar_count];
      head_values[head] = prediction;
      ensemble_mean += prediction / float(NB_WORLD_HEAD_COUNT);
    }
    float epistemic_variance = 0.0f;
    for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
      const float difference = head_values[head] - ensemble_mean;
      epistemic_variance += difference * difference / float(NB_WORLD_HEAD_COUNT);
    }
    const float epistemic = sqrt(max(epistemic_variance, 0.0f));
    const float aleatoric_variance = structured_world_available
      ? max(world[NB_WORLD_EVENT_OPTION_BASE
          + 8u * NB_WORLD_EVENT_OPTION_DIMENSION + world_component], 0.0f)
      : 0.0f;
    const float predicted_world_damage = clamp(ensemble_mean, 0.0f, 1.0f);
    const float step_damage = clamp(
      max(candidate.damage_cvar, predicted_world_damage)
        + 0.05f * sqrt(aleatoric_variance)
        + embodied_self_risk * (0.25f + 0.75f * candidate.effort_cost),
      0.0f, 1.0f
    );
    accumulated_damage = 1.0f
      - (1.0f - accumulated_damage) * (1.0f - step_damage);
    const float step_effort = candidate.effort_cost * (1.0f + epistemic);
    const float step_information = max(candidate.information_gain, epistemic);
    const float discount = pow(0.97f, float(step));
    accumulated_effort += discount * step_effort;
    accumulated_information += discount * step_information;
    accumulated_drive_change += discount * candidate.homeostatic_value;
    accumulated_objective += discount * (
      value_parameters[0] * candidate.task_value
        + value_parameters[1] * candidate.homeostatic_value
        + value_parameters[2] * candidate.social_value
        + value_parameters[3] * uniforms.curiosity_weight * step_information
        - value_parameters[4] * uniforms.risk_weight * step_damage
        - value_parameters[5] * step_effort
        - value_parameters[6]
          * (step == 0u ? candidate.switching_cost : 0.0f)
    );
    NBPlanStepRecord plan = {};
    plan.option_identifier = candidate.option_identifier;
    plan.goal_identifier = candidate.goal_identifier;
    plan.objective_value = accumulated_objective;
    plan.damage_cvar = accumulated_damage;
    plan.epistemic_uncertainty = epistemic;
    plan.predicted_effort = accumulated_effort;
    plan.predicted_information_gain = accumulated_information;
    plan.duration_seconds = 0.1f + 0.05f * float(selected_option % 8u);
    plan.predicted_drive_change = accumulated_drive_change;
    plan.admissibility = accumulated_damage <= uniforms.damage_risk_budget
      ? 1.0f : 0.0f;
    plan.sequence = step;
    plan.flags = NB_CONTROL_FLAG_VALID;
    plan.parameter_count = 16u;
    for (uint component = 0u; component < 16u; ++component) {
      rollout_state[component] = tanh(
        policy_parameters[11] * rollout_state[component]
          + policy_parameters[12] * ensemble_mean
          + policy_parameters[13] * candidate.parameters[component]
      );
      plan.predicted_state[component] = rollout_state[component];
    }
    plans[plan_base + step] = plan;
  }
}

kernel void select_option_and_control_mode(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u) return;
  device NBControlHeader *header = reinterpret_cast<device NBControlHeader *>(
    hot_state + uniforms.control_header_offset
  );
  device const NBOptionCandidateRecord *candidates =
    reinterpret_cast<device const NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  device const NBPlanStepRecord *plans = reinterpret_cast<device const NBPlanStepRecord *>(
    hot_state + uniforms.plan_offset
  );
  device const NBDriveRecord *drives = reinterpret_cast<device const NBDriveRecord *>(
    hot_state + uniforms.drive_offset
  );
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
  );
  const uint candidate_limit = nb_active_candidate_limit(uniforms, development);
  const uint active_horizon = min(
    max(development->planning_horizon_steps, 1u),
    uniforms.maximum_planning_horizon
  );
  const float embodied_self_risk = nb_embodied_self_risk(hot_state, uniforms);
  const float safety = max(
    uniforms.drive_count > 11u ? drives[11].level : 0.0f,
    embodied_self_risk
  );
  device const NBInternalActionRecord *internal_actions =
    reinterpret_cast<device const NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  const NBInternalActionRecord planning_request = internal_actions[4];
  const NBInternalActionRecord planning_end_request = internal_actions[5];
  const bool continue_planning = planning_request.kind == 5u
    && (planning_request.flags & NB_CONTROL_FLAG_VALID) != 0u;
  const bool end_planning = planning_end_request.kind == 6u
    && (planning_end_request.flags & NB_CONTROL_FLAG_VALID) != 0u;
  const uint previous_mode = header->mode;
  const ulong previous_option_identifier = header->active_option_identifier;
  const ulong previous_selected_timestamp = header->selected_timestamp_microseconds;
  const float previous_controller_phase = header->controller_phase;
  uint selected = 0u;
  float selected_score = -INFINITY;
  for (uint index = 0u; index < candidate_limit; ++index) {
    const uint terminal_index = index * uniforms.maximum_planning_horizon
      + active_horizon - 1u;
    const NBPlanStepRecord plan = plans[terminal_index];
    if (plan.admissibility > 0.5f && plan.objective_value > selected_score) {
      selected = index;
      selected_score = plan.objective_value;
    }
  }
  uint previous_candidate = uniforms.candidate_capacity;
  float previous_score = -INFINITY;
  for (uint index = 0u; index < candidate_limit; ++index) {
    if (candidates[index].option_identifier != previous_option_identifier) continue;
    const NBPlanStepRecord previous_plan = plans[
      index * uniforms.maximum_planning_horizon + active_horizon - 1u
    ];
    if (previous_plan.admissibility > 0.5f) {
      previous_candidate = index;
      previous_score = previous_plan.objective_value;
    }
    break;
  }
  if (previous_candidate < candidate_limit && selected != previous_candidate
      && isfinite(previous_score)
      && selected_score < previous_score + uniforms.switching_margin) {
    selected = previous_candidate;
    selected_score = previous_score;
  }
  uint flags = NB_CONTROL_FLAG_VALID;
  uint mode = NB_CONTROL_MODE_PROCEDURAL;
  if (safety > 0.8f || !isfinite(selected_score)) {
    selected = 0u;
    selected_score = 0.0f;
    flags |= NB_CONTROL_FLAG_HYPERDIRECT_STOP;
    mode = NB_CONTROL_MODE_REFLEX;
  } else if (development->stage >= 8u
      && (continue_planning || (!end_planning
        && (plans[selected * uniforms.maximum_planning_horizon
          + active_horizon - 1u].epistemic_uncertainty > 0.25f
      || plans[selected * uniforms.maximum_planning_horizon
          + active_horizon - 1u].damage_cvar > 0.25f)))) {
    mode = NB_CONTROL_MODE_PLANNING;
  }
  const NBOptionCandidateRecord candidate = candidates[selected];
  const NBPlanStepRecord plan = plans[
    selected * uniforms.maximum_planning_horizon + active_horizon - 1u
  ];
  header->active_goal_identifier = candidate.goal_identifier;
  header->active_option_identifier = candidate.option_identifier;
  header->active_plan_identifier = mode == NB_CONTROL_MODE_PLANNING
    ? (candidate.option_identifier ^ uniforms.parameter_version_fingerprint)
    : 0ul;
  const bool option_changed = candidate.option_identifier
    != previous_option_identifier;
  header->selected_timestamp_microseconds = option_changed
    ? uniforms.target_timestamp_microseconds
    : previous_selected_timestamp;
  header->mode = mode;
  header->candidate_count = candidate_limit;
  header->plan_step_count = mode == NB_CONTROL_MODE_PLANNING ? active_horizon : 0u;
  header->flags = flags;
  header->selected_score = selected_score;
  header->selected_damage_cvar = plan.damage_cvar;
  header->confidence = clamp(candidate.competence * (1.0f - plan.epistemic_uncertainty), 0.0f, 1.0f);
  header->vigor = clamp(1.0f - candidate.effort_cost - safety, 0.0f, 1.0f);
  header->exploration_temperature = clamp(plan.epistemic_uncertainty, 0.0f, 1.0f);
  header->controller_phase = option_changed
    ? 0.0f
    : previous_controller_phase + 1.0f;
  header->interruption_cost = option_changed
    ? clamp(previous_score - selected_score, 0.0f, 1.0f)
    : 0.0f;
  header->predicted_effort = plan.predicted_effort;
  header->predicted_information_gain = plan.predicted_information_gain;
  header->unsupported_uncertainty = plan.epistemic_uncertainty;
  header->reserved0 = ulong(selected);
  header->reserved1 = ulong(previous_mode);
}

/// Emits compact transactional internal actions. These records describe
/// deliberate memory, workspace, routing, planning, inhibition, and replay
/// requests; they never advance time or mutate persistent memory directly.
kernel void generate_internal_action_state(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.internal_action_capacity || gid >= 8u) return;
  device const NBControlHeader *header =
    reinterpret_cast<device const NBControlHeader *>(
      hot_state + uniforms.control_header_offset
    );
  device const NBOptionCandidateRecord *candidates =
    reinterpret_cast<device const NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  device const NBDriveRecord *drives =
    reinterpret_cast<device const NBDriveRecord *>(
      hot_state + uniforms.drive_offset
    );
  device const NBNeuromodulatorRecord *neuromodulators =
    reinterpret_cast<device const NBNeuromodulatorRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  device const NBWorkspaceMetadataRecord *workspace_metadata =
    reinterpret_cast<device const NBWorkspaceMetadataRecord *>(
      hot_state + uniforms.workspace_metadata_offset
    );
  device NBInternalActionRecord *actions =
    reinterpret_cast<device NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  const uint selected = min(
    uint(header->reserved0), max(uniforms.candidate_capacity, 1u) - 1u
  );
  const NBOptionCandidateRecord candidate = candidates[selected];
  const float model_error = uniforms.neuromodulator_count > 1u
    ? clamp(neuromodulators[1].value, 0.0f, 1.0f) : 0.0f;
  const float epistemic = uniforms.neuromodulator_count > 3u
    ? clamp(neuromodulators[3].value, 0.0f, 1.0f) : 0.0f;
  const float safety = uniforms.drive_count > 11u
    ? clamp(drives[11].level, 0.0f, 1.0f) : 0.0f;
  const float sleep_pressure = uniforms.drive_count > 7u
    ? clamp(max(drives[7].level, drives[7].deficit), 0.0f, 1.0f) : 0.0f;
  float maximum_token_age = 0.0f;
  ulong stalest_token_identifier = 0ul;
  for (uint slot = 2u; slot < uniforms.workspace_capacity; ++slot) {
    const NBWorkspaceMetadataRecord token = workspace_metadata[slot];
    if (token.identifier == 0ul) continue;
    const ulong age_microseconds = uniforms.target_timestamp_microseconds
      >= token.last_refresh_timestamp_microseconds
      ? uniforms.target_timestamp_microseconds
        - token.last_refresh_timestamp_microseconds
      : 0ul;
    const float age = clamp(float(age_microseconds) * 1.0e-6f, 0.0f, 1.0f);
    if (age > maximum_token_age) {
      maximum_token_age = age;
      stalest_token_identifier = token.identifier;
    }
  }

  NBInternalActionRecord action = {};
  action.timestamp_microseconds = uniforms.target_timestamp_microseconds;
  action.kind = gid + 1u;
  action.parameter_count = 6u;
  action.confidence = header->confidence;
  if (gid == 0u) {
    action.priority = max(
      header->unsupported_uncertainty,
      max(epistemic, header->predicted_information_gain)
    );
    action.target_identifier = header->active_goal_identifier;
  } else if (gid == 1u) {
    action.priority = max(model_error, 1.0f - header->progress) * header->confidence;
    action.target_identifier = header->active_goal_identifier;
  } else if (gid == 2u) {
    action.priority = maximum_token_age;
    action.target_identifier = stalest_token_identifier;
  } else if (gid == 3u) {
    action.priority = max(epistemic, candidate.information_gain);
    action.target_identifier = ulong(candidate.source_module);
  } else if (gid == 4u) {
    action.priority = header->mode == NB_CONTROL_MODE_PLANNING
      && uint(header->reserved1) != NB_CONTROL_MODE_PLANNING ? 1.0f : 0.0f;
    action.target_identifier = header->active_option_identifier;
  } else if (gid == 5u) {
    action.priority = header->mode != NB_CONTROL_MODE_PLANNING
      && uint(header->reserved1) == NB_CONTROL_MODE_PLANNING
      && header->confidence > 0.75f ? header->confidence : 0.0f;
    action.target_identifier = header->active_option_identifier;
  } else if (gid == 6u) {
    action.priority = max(
      safety,
      (header->flags & NB_CONTROL_FLAG_HYPERDIRECT_STOP) != 0u ? 1.0f : 0.0f
    );
    action.target_identifier = header->active_option_identifier;
  } else {
    const bool rest_selected = header->active_option_identifier
      == NB_REST_OPTION_IDENTIFIER;
    action.priority = max(sleep_pressure, rest_selected ? 1.0f : 0.0f);
    action.target_identifier = header->active_goal_identifier;
  }
  action.priority = clamp(action.priority, 0.0f, 1.0f);
  action.flags = action.priority > 0.05f ? NB_CONTROL_FLAG_VALID : 0u;
  action.parameters[0] = header->confidence;
  action.parameters[1] = header->unsupported_uncertainty;
  action.parameters[2] = header->selected_damage_cvar;
  action.parameters[3] = header->predicted_information_gain;
  action.parameters[4] = header->progress;
  action.parameters[5] = header->vigor;
  actions[gid] = action;
}

kernel void select_cerebellar_context_experts(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  device const float *cerebellar_parameters [[buffer(5)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.active_cerebellar_expert_count == 0u) return;
  device const NBControlHeader *header = reinterpret_cast<device const NBControlHeader *>(
    hot_state + uniforms.control_header_offset
  );
  device const float *recurrent = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  device NBCerebellarExpertRecord *experts =
    reinterpret_cast<device NBCerebellarExpertRecord *>(
      hot_state + uniforms.cerebellar_offset
    );
  device NBCerebellarExpertRecord *bank =
    reinterpret_cast<device NBCerebellarExpertRecord *>(
      hot_state + uniforms.cerebellar_expert_memory_offset
    );
  uint selected_identifiers[4] = {};
  float selected_scores[4] = {-INFINITY, -INFINITY, -INFINITY, -INFINITY};
  const uint active_count = min(uniforms.active_cerebellar_expert_count, 4u);
  const float option_context = float(
    uint(header->active_option_identifier ^ (header->active_option_identifier >> 32))
  ) * 2.3283064365386963e-10f;
  for (uint expert_identifier = 0u;
      expert_identifier < uniforms.cerebellar_expert_capacity;
      ++expert_identifier) {
    NBCerebellarExpertRecord memory = bank[expert_identifier];
    if ((memory.flags & NB_CONTROL_FLAG_VALID) == 0u) {
      memory.expert_identifier = expert_identifier;
      memory.flags = NB_CONTROL_FLAG_VALID;
      memory.weight = 0.0f;
      memory.prediction_error = 0.0f;
      bank[expert_identifier] = memory;
    }
    const float neural_context = recurrent[
      (expert_identifier * 17u) % uniforms.recurrent_scalar_count
    ];
    const float expert_context = float(expert_identifier)
      / float(max(uniforms.cerebellar_expert_capacity - 1u, 1u));
    const float adaptation_bonus = clamp(abs(memory.state[2]), 0.0f, 0.25f);
    const float score = cerebellar_parameters[3]
      - abs(tanh(cerebellar_parameters[7] * neural_context + option_context)
        - expert_context) + adaptation_bonus;
    for (uint rank = 0u; rank < active_count; ++rank) {
      if (score > selected_scores[rank]
          || (score == selected_scores[rank]
            && expert_identifier < selected_identifiers[rank])) {
        for (uint shift = active_count - 1u; shift > rank; --shift) {
          selected_scores[shift] = selected_scores[shift - 1u];
          selected_identifiers[shift] = selected_identifiers[shift - 1u];
        }
        selected_scores[rank] = score;
        selected_identifiers[rank] = expert_identifier;
        break;
      }
    }
  }
  float weight_sum = 0.0f;
  for (uint rank = 0u; rank < active_count; ++rank) {
    weight_sum += exp(selected_scores[rank]);
  }
  for (uint rank = 0u; rank < active_count; ++rank) {
    NBCerebellarExpertRecord expert = bank[selected_identifiers[rank]];
    expert.weight = exp(selected_scores[rank]) / max(weight_sum, 1.0e-6f);
    experts[rank] = expert;
  }
  for (uint rank = active_count; rank < uniforms.active_cerebellar_expert_count;
      ++rank) {
    NBCerebellarExpertRecord inactive = {};
    experts[rank] = inactive;
  }
}

/// Advances the species-defined central pattern generator as independent,
/// transactional per-agent state. This first production path is analytic at
/// the committed control timestamp; physical-substep sampling can consume the
/// resulting state without making oscillator phase a shared parameter.
kernel void advance_cpg_state(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  device const NBCPGOscillatorDescriptor *oscillator_descriptors [[buffer(7)]],
  device const NBCPGCouplingDescriptor *coupling_descriptors [[buffer(8)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.cpg_oscillator_count == 0u) return;
  device const NBControlHeader *header =
    reinterpret_cast<device const NBControlHeader *>(
      hot_state + uniforms.control_header_offset
    );
  device const NBOptionCandidateRecord *candidates =
    reinterpret_cast<device const NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  device NBCPGStateRecord *states =
    reinterpret_cast<device NBCPGStateRecord *>(
      hot_state + uniforms.cpg_state_offset
    );
  const uint selected = min(
    uint(header->reserved0), max(uniforms.candidate_capacity, 1u) - 1u
  );
  const NBOptionCandidateRecord candidate = candidates[selected];
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  device const NBInternalActionRecord *internal_actions =
    reinterpret_cast<device const NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  const NBInternalActionRecord inhibition_request = internal_actions[6];
  const float deliberate_inhibition = inhibition_request.kind == 7u
      && (inhibition_request.flags & NB_CONTROL_FLAG_VALID) != 0u
    ? clamp(inhibition_request.priority, 0.0f, 1.0f)
    : 0.0f;
  device const NBDriveRecord *drives =
    reinterpret_cast<device const NBDriveRecord *>(
      hot_state + uniforms.drive_offset
    );
  const float safety = uniforms.drive_count > 11u
    ? clamp(drives[11].level, 0.0f, 1.0f)
    : 0.0f;
  const float motor_inhibition = max(
    (header->flags & NB_CONTROL_FLAG_HYPERDIRECT_STOP) != 0u ? 1.0f : safety,
    deliberate_inhibition
  );
  const bool locomotor_active = ((
    candidate.source_module == 72u
      && candidate.proposal_kind == NB_OPTION_PROPOSAL_LOCOMOTION
  ) || (
    candidate.source_module == 65u
      && candidate.proposal_kind == NB_OPTION_PROPOSAL_EXPLORATION
  ))
    && (header->flags & NB_CONTROL_FLAG_HYPERDIRECT_STOP) == 0u;

  device NBEventQueueHeader *event_header =
    reinterpret_cast<device NBEventQueueHeader *>(
      hot_state + uniforms.event_queue_offset
    );
  const uint event_count = min(
    min(
      atomic_load_explicit(&event_header->count, memory_order_relaxed),
      event_header->capacity
    ),
    uniforms.event_capacity
  );
  device const NBReceptorEventRecord *events =
    reinterpret_cast<device const NBReceptorEventRecord *>(event_header + 1);
  ulong delivered_interrupt_mask = 0ul;
  for (uint event_index = 0u; event_index < event_count; ++event_index) {
    if (events[event_index].timestamp_microseconds
        <= uniforms.target_timestamp_microseconds) {
      delivered_interrupt_mask |= nb_interrupt_mask_for_event_kind(
        events[event_index].kind
      );
    }
  }

  float prior_phases[64];
  for (uint oscillator = 0u; oscillator < uniforms.cpg_oscillator_count;
      ++oscillator) {
    const float phase = states[oscillator].phase;
    prior_phases[oscillator] = isfinite(phase)
      ? phase - floor(phase)
      : 0.0f;
  }
  constexpr float two_pi = 6.28318530717958647692f;
  for (uint oscillator = 0u; oscillator < uniforms.cpg_oscillator_count;
      ++oscillator) {
    const NBCPGOscillatorDescriptor descriptor = oscillator_descriptors[oscillator];
    NBCPGStateRecord state = states[oscillator];
    const bool vital = descriptor.output_kind
      == ulong(NB_CPG_OUTPUT_AUTONOMIC_CHANNEL);
    const bool active = vital || locomotor_active;
    const ulong prior_timestamp = state.timestamp_microseconds;
    const float elapsed_seconds = prior_timestamp > 0ul
        && uniforms.target_timestamp_microseconds > prior_timestamp
      ? float(uniforms.target_timestamp_microseconds - prior_timestamp) * 1.0e-6f
      : 0.0f;
    const bool reset = active && (descriptor.sensory_reset_mask
      & delivered_interrupt_mask) != 0ul;
    float reset_magnitude = 0.0f;
    if (reset) {
      for (uint event_index = 0u; event_index < event_count; ++event_index) {
        const NBReceptorEventRecord event = events[event_index];
        if (event.timestamp_microseconds <= uniforms.target_timestamp_microseconds
            && (descriptor.sensory_reset_mask
              & nb_interrupt_mask_for_event_kind(event.kind)) != 0ul) {
          reset_magnitude = max(reset_magnitude, clamp(event.magnitude, 0.0f, 1.0f));
        }
      }
    }
    float phase = active ? prior_phases[oscillator] : 0.0f;
    float coupling_frequency = 0.0f;
    if (active && !reset) {
      for (uint coupling = 0u; coupling < uniforms.cpg_coupling_count;
          ++coupling) {
        const NBCPGCouplingDescriptor edge = coupling_descriptors[coupling];
        if (edge.destination_oscillator_index == oscillator
            && edge.source_oscillator_index < uniforms.cpg_oscillator_count) {
          coupling_frequency += edge.gain * sin(
            two_pi * (prior_phases[edge.source_oscillator_index]
              - prior_phases[oscillator]) - edge.phase_offset
          );
        }
      }
    }
    const float vigor_scale = vital
      ? 1.0f
      : clamp(0.5f + header->vigor, 0.25f, 1.5f);
    const float effective_frequency = active
      ? max(descriptor.natural_frequency_hertz * vigor_scale
          + coupling_frequency, 0.0f)
      : descriptor.natural_frequency_hertz;
    if (reset) {
      phase = 0.0f;
    } else if (active && elapsed_seconds > 0.0f) {
      phase = fract(phase + elapsed_seconds * effective_frequency);
    }
    const float normalized_active_phase = phase / max(descriptor.duty_factor, 1.0e-6f);
    const float raw_output = active && phase < descriptor.duty_factor
      ? 0.5f - 0.5f * cos(two_pi * normalized_active_phase)
      : 0.0f;
    const float output_gain = vital
      ? 1.0f
      : (active
        ? (1.0f - motor_inhibition) * development->muscle_strength_multiplier
        : 0.0f);
    state.phase = phase;
    state.output = clamp(raw_output * output_gain, 0.0f, 1.0f);
    state.effective_frequency_hertz = effective_frequency;
    state.duty_factor = descriptor.duty_factor;
    state.sensory_reset_mask = descriptor.sensory_reset_mask;
    state.reset_magnitude = reset_magnitude;
    state.output_gain = output_gain;
    state.decision_output = state.output;
    state.reserved_float = 0.0f;
    state.timestamp_microseconds = uniforms.target_timestamp_microseconds;
    state.output_synergy_identifier = descriptor.output_synergy_identifier;
    state.oscillator_identifier = descriptor.identifier;
    state.flags = NB_CONTROL_FLAG_VALID
      | (active ? (1u << 1u) : 0u)
      | (reset ? (1u << 2u) : 0u);
    state.output_kind = uint(descriptor.output_kind);
    states[oscillator] = state;
  }
}

kernel void generate_motor_spinal_autonomic_state(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  device const float *policy_parameters [[buffer(3)]],
  device const float *motor_parameters [[buffer(4)]],
  device const NBCommunicationChannelDescriptor *communication_descriptors
    [[buffer(6)]],
  device const NBAutonomicChannelDescriptor *autonomic_descriptors
    [[buffer(9)]],
  device const NBActiveSensingChannelDescriptor *active_sensing_descriptors
    [[buffer(10)]],
  uint gid [[thread_position_in_grid]])
{
  device const NBControlHeader *header = reinterpret_cast<device const NBControlHeader *>(
    hot_state + uniforms.control_header_offset
  );
  device const NBOptionCandidateRecord *candidates =
    reinterpret_cast<device const NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  device const NBDriveRecord *drives = reinterpret_cast<device const NBDriveRecord *>(
    hot_state + uniforms.drive_offset
  );
  device const NBNeuromodulatorRecord *neuromodulators =
    reinterpret_cast<device const NBNeuromodulatorRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  const uint selected = min(
    uint(header->reserved0), max(uniforms.candidate_capacity, 1u) - 1u
  );
  const NBOptionCandidateRecord candidate = candidates[selected];
  const uint parameter_count = max(candidate.parameter_count, 1u);
  const bool communication_selected = development->stage >= 10u
    && candidate.source_module == 51u;
  const bool rest_selected = header->active_option_identifier
    == NB_REST_OPTION_IDENTIFIER;
  const float safety = uniforms.drive_count > 11u ? clamp(drives[11].level, 0.0f, 1.0f) : 0.0f;
  device const NBInternalActionRecord *internal_actions =
    reinterpret_cast<device const NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  const NBInternalActionRecord inhibition_request = internal_actions[6];
  const float deliberate_inhibition = inhibition_request.kind == 7u
      && (inhibition_request.flags & NB_CONTROL_FLAG_VALID) != 0u
    ? clamp(inhibition_request.priority, 0.0f, 1.0f)
    : 0.0f;
  device const NBCerebellarExpertRecord *experts =
    reinterpret_cast<device const NBCerebellarExpertRecord *>(
      hot_state + uniforms.cerebellar_offset
    );
  float learned_cerebellar_residual = 0.0f;
  for (uint expert_index = 0u;
      expert_index < uniforms.active_cerebellar_expert_count; ++expert_index) {
    learned_cerebellar_residual += experts[expert_index].weight
      * experts[expert_index].state[1];
  }
  device const NBCPGStateRecord *cpg_states =
    reinterpret_cast<device const NBCPGStateRecord *>(
      hot_state + uniforms.cpg_state_offset
    );
  device NBFastCerebellarStateRecord *fast_cerebellar =
    reinterpret_cast<device NBFastCerebellarStateRecord *>(
      hot_state + uniforms.fast_cerebellar_state_offset
    );
  if (gid < uniforms.actuator_count) {
    device NBMotorCommandRecord *motor =
      reinterpret_cast<device NBMotorCommandRecord *>(hot_state + uniforms.motor_offset);
    device NBSpinalStateRecord *spinal =
      reinterpret_cast<device NBSpinalStateRecord *>(hot_state + uniforms.spinal_offset);
    device float *somatic_output = reinterpret_cast<device float *>(
      hot_state + uniforms.somatic_output_offset
    );
    device float *descending_baseline = reinterpret_cast<device float *>(
      hot_state + uniforms.descending_somatic_baseline_offset
    );
    device const uchar *body_belief = hot_state + uniforms.body_belief_offset;
    float body_risk = 0.0f;
    float support_confidence = 0.0f;
    uint body_evidence_count = 0u;
    for (uint body_index = 0u;
        body_index < uniforms.body_belief_count; ++body_index) {
      device const float *body = reinterpret_cast<device const float *>(
        body_belief + ulong(body_index) * 256ul
      );
      device const ulong *identity = reinterpret_cast<device const ulong *>(
        body + 16
      );
      if ((identity[3] & 1ul) == 0ul) continue;
      body_risk = max(
        body_risk,
        max(clamp(body[5], 0.0f, 1.0f), clamp(body[7], 0.0f, 1.0f))
      );
      support_confidence = max(
        support_confidence, clamp(body[3], 0.0f, 1.0f)
      );
      body_evidence_count += 1u;
    }
    const uint effector_index = gid % max(
      uniforms.somatic_effector_belief_count, 1u
    );
    device const float *effector = reinterpret_cast<device const float *>(
      hot_state + uniforms.somatic_effector_belief_offset
        + ulong(effector_index) * 192ul
    );
    const float agency_confidence =
      uniforms.somatic_effector_belief_count > 0u
        ? clamp(effector[8], 0.0f, 1.0f) : 0.0f;
    const float external_disturbance =
      uniforms.somatic_effector_belief_count > 0u
        ? clamp(effector[9], 0.0f, 1.0f) : 0.0f;
    const float embodied_risk = clamp(
      body_risk * max(motor_parameters[11], 0.0f)
        + external_disturbance * max(motor_parameters[12], 0.0f),
      0.0f,
      1.0f
    );
    const NBCommunicationChannelDescriptor communication_descriptor =
      communication_descriptors[gid];
    const bool communication_actuator =
      (communication_descriptor.flags & NB_CONTROL_FLAG_VALID) != 0u;
    const bool muscle_excitation = nb_uses_muscle_excitation(
      uniforms.actuator_command_kind
    );
    const float motor_neutral = nb_motor_neutral(
      uniforms.actuator_command_kind
    );
    const float motor_logit = candidate.parameters[gid % parameter_count]
      * uniforms.motor_gain * motor_parameters[0];
    const float ordinary_descending = rest_selected
      ? motor_neutral
      : nb_motor_drive_from_logit(motor_logit, uniforms.actuator_command_kind);
    float descending = ordinary_descending;
    if (communication_selected) {
      if (communication_actuator) {
        const float communication_logit = candidate.parameters[
          communication_descriptor.local_channel_index % parameter_count
        ];
        const float communication_drive = nb_motor_drive_from_logit(
          communication_logit, uniforms.actuator_command_kind
        );
        descending = nb_scale_motor_drive(
          communication_drive,
          communication_descriptor.gain,
          uniforms.actuator_command_kind
        );
      } else {
        descending = nb_scale_motor_drive(
          ordinary_descending,
          motor_parameters[8],
          uniforms.actuator_command_kind
        );
      }
    }
    const float inhibition = max(
      (header->flags & NB_CONTROL_FLAG_HYPERDIRECT_STOP) != 0u
        ? 1.0f : max(safety, embodied_risk),
      deliberate_inhibition
    );
    NBFastCerebellarStateRecord fast_state = fast_cerebellar[gid];
    const bool fast_correction_active = !rest_selected && inhibition < 1.0f;
    fast_state.flags = (fast_state.flags | NB_CONTROL_FLAG_VALID)
      & ~(1u << 1u);
    fast_state.flags |= fast_correction_active ? (1u << 1u) : 0u;
    fast_cerebellar[gid] = fast_state;
    const float fast_cerebellar_residual = fast_correction_active
      ? clamp(fast_state.correction, -0.25f, 0.25f) : 0.0f;
    descending = nb_scale_motor_drive(
      descending,
      1.0f - inhibition,
      uniforms.actuator_command_kind
    );
    const float developed_descending = nb_scale_motor_drive(
      descending,
      development->muscle_strength_multiplier,
      uniforms.actuator_command_kind
    );
    NBMotorCommandRecord command;
    command.excitation = clamp(developed_descending, 0.0f, 1.0f);
    command.force_target = nb_motor_feature(
      descending, uniforms.actuator_command_kind
    );
    command.stiffness_target = clamp(
      uniforms.stiffness_gain * motor_parameters[1]
        * (max(safety, body_risk)
          + (body_evidence_count > 0u ? 1.0f - support_confidence : 0.0f)
            * max(motor_parameters[13], 0.0f)
          + abs(candidate.parameters[(gid + 1u) % 16u])),
      0.0f,
      1.0f
    );
    command.damping_target = clamp(
      uniforms.damping_gain * motor_parameters[2] * command.stiffness_target,
      0.0f,
      1.0f
    );
    const float slow_cerebellar_residual = rest_selected
      ? 0.0f
      : clamp(
          learned_cerebellar_residual
            - header->unsupported_uncertainty * motor_parameters[10],
          -0.25f, 0.25f
        ) * (0.5f + 0.5f * agency_confidence);
    command.cerebellar_residual = clamp(
      slow_cerebellar_residual + fast_cerebellar_residual,
      -0.25f,
      0.25f
    );
    command.risk_inhibition = inhibition;
    command.synergy_identifier = gid % max(uniforms.synergy_count, 1u);
    command.flags = NB_CONTROL_FLAG_VALID
      | (communication_selected && communication_actuator ? (1u << 4u) : 0u)
      | (muscle_excitation ? (1u << 5u) : 0u);
    motor[gid] = command;
    float cpg_output = 0.0f;
    const uint actuator_synergy = gid % max(uniforms.synergy_count, 1u);
    for (uint oscillator = 0u; oscillator < uniforms.cpg_oscillator_count;
        ++oscillator) {
      const NBCPGStateRecord oscillator_state = cpg_states[oscillator];
      if ((oscillator_state.flags & NB_CONTROL_FLAG_VALID) != 0u
          && oscillator_state.output_kind == NB_CPG_OUTPUT_SOMATIC_SYNERGY
          && oscillator_state.output_synergy_identifier == actuator_synergy) {
        cpg_output += oscillator_state.output;
      }
    }
    cpg_output = clamp(cpg_output, 0.0f, 1.0f);
    NBSpinalStateRecord spinal_state;
    spinal_state.reflex_output = safety > 0.5f ? -0.25f : 0.0f;
    spinal_state.cpg_output = cpg_output;
    spinal_state.motor_neuron_state = command.excitation
      + command.cerebellar_residual + spinal_state.cpg_output;
    const float baseline_excitation = clamp(
      command.excitation + slow_cerebellar_residual
        + spinal_state.reflex_output,
      0.0f,
      1.0f
    );
    descending_baseline[gid] = baseline_excitation;
    spinal_state.final_excitation = clamp(
      baseline_excitation + fast_cerebellar_residual
        + spinal_state.cpg_output,
      0.0f,
      1.0f
    );
    spinal[gid] = spinal_state;
    somatic_output[gid] = spinal_state.final_excitation;
  }
  if (gid < uniforms.synergy_count) {
    device float *synergies = reinterpret_cast<device float *>(
      hot_state + uniforms.synergy_offset
    );
    const uint descriptor_index =
      uniforms.communication_synergy_descriptor_offset + gid;
    const NBCommunicationChannelDescriptor communication_descriptor =
      communication_descriptors[descriptor_index];
    const bool communication_synergy = descriptor_index
      < uniforms.communication_descriptor_count
      && (communication_descriptor.flags & NB_CONTROL_FLAG_VALID) != 0u;
    const uint parameter_index = communication_selected && communication_synergy
      ? communication_descriptor.local_channel_index % parameter_count
      : gid % parameter_count;
    const float gain = communication_selected
      ? (communication_synergy
        ? communication_descriptor.gain
        : clamp(motor_parameters[8], 0.0f, 1.0f))
      : policy_parameters[7];
    synergies[gid] = rest_selected
      ? 0.0f
      : candidate.parameters[parameter_index] * gain
        * (1.0f - deliberate_inhibition);
  }
  if (gid < uniforms.autonomic_dimension) {
    device NBAutonomicCommandRecord *autonomic =
      reinterpret_cast<device NBAutonomicCommandRecord *>(
        hot_state + uniforms.autonomic_offset
      );
    const NBAutonomicChannelDescriptor descriptor = autonomic_descriptors[gid];
    const float energy = uniforms.drive_count > 0u
      ? clamp(drives[0].level, 0.0f, 1.0f) : 0.0f;
    const float oxygen = uniforms.drive_count > 2u
      ? clamp(drives[2].level, 0.0f, 1.0f) : 0.0f;
    const float temperature = uniforms.drive_count > 3u
      ? clamp(drives[3].level, 0.0f, 1.0f) : 0.0f;
    const float fatigue = uniforms.drive_count > 4u
      ? clamp(drives[4].level, 0.0f, 1.0f) : 0.0f;
    const float sleep = uniforms.drive_count > 7u
      ? clamp(drives[7].level, 0.0f, 1.0f) : 0.0f;
    float target = 0.0f;
    switch (descriptor.kind) {
      case 1u:
        target = max(oxygen, max(0.75f * safety, 0.25f * fatigue));
        break;
      case 2u:
        target = max(oxygen, max(safety, 0.25f * fatigue));
        break;
      case 3u:
        target = max(oxygen, max(safety, header->vigor));
        break;
      case 4u:
        target = max(safety, oxygen);
        break;
      case 5u:
        target = temperature;
        break;
      case 6u:
        target = max(safety, 0.5f * header->vigor);
        break;
      case 7u:
        target = energy * (1.0f - safety) * (rest_selected ? 1.0f : 0.5f);
        break;
      case 8u:
        target = safety;
        break;
      case 9u:
        target = max(sleep, fatigue) * (1.0f - safety);
        break;
      default:
        target = clamp(
          candidate.parameters[(gid + 8u) % parameter_count]
            * max(policy_parameters[10], 0.0f),
          0.0f,
          1.0f
        );
        break;
    }
    device NBEventQueueHeader *event_header =
      reinterpret_cast<device NBEventQueueHeader *>(
        hot_state + uniforms.event_queue_offset
      );
    const uint event_count = min(
      min(
        atomic_load_explicit(&event_header->count, memory_order_relaxed),
        event_header->capacity
      ),
      uniforms.event_capacity
    );
    device const NBReceptorEventRecord *events =
      reinterpret_cast<device const NBReceptorEventRecord *>(event_header + 1);
    float critical_strength = 0.0f;
    for (uint event_index = 0u; event_index < event_count; ++event_index) {
      const NBReceptorEventRecord event = events[event_index];
      if (event.kind != 12u) continue;
      bool receptor_match = (descriptor.flags & (1u << 1u)) != 0u;
      for (uint receptor_index = 0u;
          receptor_index < min(descriptor.critical_receptor_count, 4u);
          ++receptor_index) {
        receptor_match = receptor_match
          || descriptor.critical_receptors[receptor_index]
            == event.source_identifier;
      }
      if (receptor_match) {
        critical_strength = max(
          critical_strength,
          clamp(event.magnitude * descriptor.emergency_gain, 0.0f, 1.0f)
        );
      }
    }
    target = mix(
      clamp(target, 0.0f, 1.0f),
      clamp(descriptor.emergency_target, 0.0f, 1.0f),
      critical_strength
    );
    NBAutonomicCommandRecord command;
    command.command = target;
    command.target = command.command;
    command.confidence = max(header->confidence, critical_strength);
    command.flags = NB_CONTROL_FLAG_VALID
      | (critical_strength > 0.0f ? (1u << 1u) : 0u);
    autonomic[gid] = command;
  }
  if (gid < uniforms.active_sensing_dimension) {
    device NBActiveSensingCommandRecord *active_sensing =
      reinterpret_cast<device NBActiveSensingCommandRecord *>(
        hot_state + uniforms.active_sensing_offset
      );
    const uint descriptor_index = uniforms.active_sensing_descriptor_offset + gid;
    const NBCommunicationChannelDescriptor communication_descriptor =
      communication_descriptors[descriptor_index];
    const bool communication_sensing = descriptor_index
      < uniforms.communication_descriptor_count
      && (communication_descriptor.flags & NB_CONTROL_FLAG_VALID) != 0u;
    const NBActiveSensingChannelDescriptor sensing_descriptor =
      active_sensing_descriptors[gid];
    const uint parameter_index = communication_selected && communication_sensing
      ? communication_descriptor.local_channel_index % parameter_count
      : (gid + 8u) % parameter_count;
    const float epistemic = uniforms.neuromodulator_count > 3u
      ? clamp(neuromodulators[3].value, 0.0f, 1.0f) : 0.0f;
    device const float *world = reinterpret_cast<device const float *>(
      hot_state + uniforms.world_model_offset
    );
    const float prior_modality_uncertainty =
      nb_modality_epistemic_uncertainty(
        world, uniforms.world_model_scalar_count, sensing_descriptor.modality
      );
    device NBActiveSensingEfficacyRecord *sensing_efficacy =
      reinterpret_cast<device NBActiveSensingEfficacyRecord *>(
        hot_state + uniforms.active_sensing_efficacy_offset
      );
    NBActiveSensingEfficacyRecord efficacy_state = sensing_efficacy[gid];
    const float learned_efficacy = efficacy_state.sample_count > 0u
        && (efficacy_state.flags & NB_CONTROL_FLAG_VALID) != 0u
      ? clamp(efficacy_state.efficacy, 0.0f, 2.0f)
      : 1.0f;
    float modality_uncertainty = max(epistemic, prior_modality_uncertainty);
    uint epistemic_target_slot = 0u;
    float epistemic_target_command = 0.0f;
    float epistemic_target_score = 0.0f;
    if (sensing_descriptor.modality == 1u) {
      device const NBObjectSlotRecord *object_slots =
        reinterpret_cast<device const NBObjectSlotRecord *>(
          hot_state + uniforms.object_slot_offset
        );
      float weighted_uncertainty = 0.0f;
      float evidence_weight = 0.0f;
      for (uint object_index = 0u; object_index < uniforms.object_slot_count;
          ++object_index) {
        const NBObjectSlotRecord object = object_slots[object_index];
        if (object.identifier == 0ul
            || (object.flags & NB_CONTROL_FLAG_VALID) == 0u
            || object.existence_probability <= 0.01f) continue;
        const float weight = clamp(
          object.existence_probability * max(object.visibility, 0.1f),
          0.0f, 1.0f
        );
        weighted_uncertainty += clamp(object.uncertainty, 0.0f, 1.0f) * weight;
        evidence_weight += weight;
        const float target_score = object.existence_probability
          * clamp(object.uncertainty, 0.0f, 1.0f)
          * (1.0f - 0.5f * clamp(object.visibility, 0.0f, 1.0f));
        if (target_score > epistemic_target_score) {
          epistemic_target_score = target_score;
          epistemic_target_slot = object_index + 1u;
          epistemic_target_command = object.pose[
            sensing_descriptor.modality_local_identifier % 3u
          ];
        }
      }
      if (evidence_weight > 0.0f) {
        modality_uncertainty = max(
          modality_uncertainty,
          clamp(weighted_uncertainty / evidence_weight, 0.0f, 1.0f)
        );
      }
    } else if (sensing_descriptor.modality == 3u
        || sensing_descriptor.modality == 4u) {
      float agency_uncertainty = 0.0f;
      float body_model_uncertainty = 0.0f;
      for (uint effector_index = 0u;
          effector_index < uniforms.somatic_effector_belief_count;
          ++effector_index) {
        device const float *effector = reinterpret_cast<device const float *>(
          hot_state + uniforms.somatic_effector_belief_offset
            + ulong(effector_index) * 192ul
        );
        agency_uncertainty = max(
          agency_uncertainty, 1.0f - clamp(effector[8], 0.0f, 1.0f)
        );
      }
      device const uchar *body_belief = hot_state + uniforms.body_belief_offset;
      for (uint body_index = 0u;
          body_index < uniforms.body_belief_count; ++body_index) {
        device const float *body = reinterpret_cast<device const float *>(
          body_belief + ulong(body_index) * 256ul
        );
        device const ulong *identity = reinterpret_cast<device const ulong *>(
          body + 16
        );
        if ((identity[3] & 1ul) == 0ul || !isfinite(body[9])) continue;
        const float standard_deviation = sqrt(max(body[9], 0.0f));
        body_model_uncertainty = max(
          body_model_uncertainty,
          standard_deviation / (1.0f + standard_deviation)
        );
      }
      modality_uncertainty = max(
        modality_uncertainty,
        max(agency_uncertainty, body_model_uncertainty)
      );
    } else if (sensing_descriptor.modality == 5u) {
      float support_uncertainty = 0.0f;
      device const uchar *body_belief = hot_state + uniforms.body_belief_offset;
      for (uint body_index = 0u;
          body_index < uniforms.body_belief_count; ++body_index) {
        device const float *body = reinterpret_cast<device const float *>(
          body_belief + ulong(body_index) * 256ul
        );
        device const ulong *identity = reinterpret_cast<device const ulong *>(
          body + 16
        );
        if ((identity[3] & 1ul) == 0ul) continue;
        support_uncertainty = max(
          support_uncertainty, 1.0f - clamp(body[3], 0.0f, 1.0f)
        );
      }
      modality_uncertainty = max(modality_uncertainty, support_uncertainty);
    }
    const float expected_information = clamp(
      max(modality_uncertainty, candidate.information_gain), 0.0f, 1.0f
    );
    const float fatigue = uniforms.drive_count > 4u
      ? clamp(drives[4].level, 0.0f, 1.0f) : 0.0f;
    const float embodied_risk = max(
      safety, nb_embodied_self_risk(hot_state, uniforms)
    );
    const float sensing_cost = clamp(
      embodied_risk + 0.5f * fatigue + 0.25f * candidate.effort_cost,
      0.0f, 1.0f
    );
    const float expected_sensing_value = clamp(
      expected_information * max(policy_parameters[15], 0.0f)
        * learned_efficacy,
      0.0f, 1.0f
    );
    const float information_allocation = expected_sensing_value
        > max(policy_parameters[14], 0.0f)
      ? expected_sensing_value * (1.0f - sensing_cost)
      : 0.0f;
    const float communication_allocation =
      communication_selected && communication_sensing
        ? header->confidence * (1.0f - sensing_cost) : 0.0f;
    const float allocation = rest_selected ? 0.0f : clamp(
      max(information_allocation, communication_allocation)
        * (1.0f - deliberate_inhibition),
      0.0f, 1.0f
    );
    const float policy_command = communication_selected && communication_sensing
      ? candidate.parameters[parameter_index] * communication_descriptor.gain
      : tanh(candidate.parameters[parameter_index])
        * clamp(policy_parameters[9], 0.0f, 1.0f);
    const bool grounded_visual_target = sensing_descriptor.modality == 1u
      && sensing_descriptor.modality_local_identifier < 3u
      && epistemic_target_slot > 0u;
    const float raw_command = grounded_visual_target
      ? mix(
          policy_command,
          clamp(epistemic_target_command, -1.0f, 1.0f),
          clamp(epistemic_target_score, 0.0f, 1.0f)
        )
      : policy_command;
    NBActiveSensingCommandRecord command;
    command.command = clamp(raw_command * allocation, -1.0f, 1.0f);
    command.confidence = rest_selected ? 1.0f
      : clamp(allocation * max(header->confidence, expected_information), 0.0f, 1.0f);
    command.attention_allocation_mask = allocation > 0.0f
      ? (1u << min(max(sensing_descriptor.modality, 1u) - 1u, 7u))
        | ((epistemic_target_slot & 0xffffu) << 16u)
      : 0u;
    command.kind_and_flags =
      (sensing_descriptor.modality & 0xffu)
      | ((sensing_descriptor.modality_local_identifier & 0xffu) << 8u)
      | (NB_CONTROL_FLAG_VALID << 16u)
      | (communication_selected && communication_sensing ? (1u << 17u) : 0u)
      | ((communication_sensing ? communication_descriptor.effector_kind : 0u)
        << 24u);
    active_sensing[gid] = command;
    efficacy_state.prior_uncertainty = modality_uncertainty;
    efficacy_state.allocation = allocation;
    efficacy_state.flags = NB_CONTROL_FLAG_VALID
      | (allocation > 0.0f ? (1u << 1u) : 0u);
    sensing_efficacy[gid] = efficacy_state;
  }
}

/// Arms the active mixture experts with timestamped sensory predictions after
/// the exact motor command has been generated. These records live only in the
/// agent shadow generation; accepted feedback may adapt them, while a root
/// abort discards the predictions without changing expert memory.
kernel void predict_delayed_cerebellar_consequences(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  device const float *cerebellar_parameters [[buffer(5)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.active_cerebellar_expert_count) return;
  device NBCerebellarExpertRecord *experts =
    reinterpret_cast<device NBCerebellarExpertRecord *>(
      hot_state + uniforms.cerebellar_offset
    );
  NBCerebellarExpertRecord expert = experts[gid];
  if ((expert.flags & NB_CONTROL_FLAG_VALID) == 0u) return;
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  device const float *somatic_output = reinterpret_cast<device const float *>(
    hot_state + uniforms.somatic_output_offset
  );
  const uint prediction_count = min(uniforms.observation_count, 8u);
  float mean_command = 0.0f;
  for (uint sample = 0u; sample < prediction_count; ++sample) {
    const uint observation_index =
      (expert.expert_identifier * 17u + sample * 31u)
        % uniforms.observation_count;
    const uint actuator_index = sample % max(uniforms.actuator_count, 1u);
    const float command_feature = uniforms.actuator_count == 0u
      ? 0.0f
      : nb_motor_feature(
          somatic_output[actuator_index], uniforms.actuator_command_kind
        );
    const float baseline = observations[observation_index];
    const float learned_effect = clamp(
      cerebellar_parameters[4] + expert.state[28u + sample],
      -1.0f,
      1.0f
    );
    expert.state[4u + sample] = baseline
      + clamp(command_feature * learned_effect, -1.0f, 1.0f);
    expert.state[12u + sample] = baseline;
    expert.state[20u + sample] = command_feature;
    mean_command += command_feature;
  }
  expert.state[3] = prediction_count == 0u
    ? 0.0f : mean_command / float(prediction_count);
  expert.prediction_timestamp_microseconds =
    uniforms.target_timestamp_microseconds;
  expert.prediction_count = prediction_count;
  expert.reserved = 0u;
  expert.flags = prediction_count == 0u
    ? (expert.flags & ~NB_CEREBELLAR_PREDICTION_VALID)
    : (expert.flags | NB_CEREBELLAR_PREDICTION_VALID);
  experts[gid] = expert;
}

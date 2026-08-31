#include <metal_stdlib>
using namespace metal;

constant uint NB_SENSORY_FRAME_REUSED = 1u << 1u;
constant uint NB_BODY_ORIENTATION = 3u;
constant uint NB_BODY_LINEAR_VELOCITY = 7u;
constant uint NB_BODY_POSITION_VARIANCE = 13u;
constant uint NB_BODY_ORIENTATION_VARIANCE = 16u;
constant uint NB_BODY_CONTACT = 19u;
constant uint NB_BODY_SUPPORT = 20u;
constant uint NB_BODY_PAIN = 24u;
constant uint NB_BODY_VULNERABILITY = 25u;
constant uint NB_BODY_REACHABILITY = 26u;
constant uint NB_BODY_OWNERSHIP = 27u;
constant uint NB_BODY_LOAD_VARIANCE = 29u;
constant uint NB_BODY_DAMAGE_RISK = 30u;
constant uint NB_BODY_EXTERNAL_DISTURBANCE = 32u;
constant uint NB_BODY_SENSORIMOTOR_FEATURE_COUNT = 33u;
constant uint NB_BODY_IDENTITY_FLOAT_OFFSET = 40u;
constant uint NB_JOINT_POSITION_VARIANCE = 12u;
constant uint NB_JOINT_VELOCITY_VARIANCE = 18u;
constant uint NB_JOINT_LIMIT_ACTIVATION = 24u;
constant uint NB_JOINT_OWNERSHIP = 30u;
constant uint NB_JOINT_PREDICTION_ERROR = 31u;
constant uint NB_JOINT_IDENTITY_FLOAT_OFFSET = 32u;
constant uint NB_MUSCLE_SENSORIMOTOR_FEATURE_COUNT = 16u;
constant uint NB_MUSCLE_IDENTITY_FLOAT_OFFSET = 16u;
constant uint NB_WORLD_SENSORIMOTOR_DIMENSION = 256u;

struct NBCognitiveUniforms {
  ulong target_timestamp_microseconds;
  ulong delta_microseconds;
  ulong recurrent_offset;
  ulong workspace_content_offset;
  ulong workspace_metadata_offset;
  ulong world_model_offset;
  ulong drive_offset;
  ulong neuromodulation_offset;
  ulong fast_plasticity_offset;
  ulong active_control_offset;
  ulong internal_action_offset;
  ulong event_queue_offset;
  ulong developmental_state_offset;
  ulong regional_maturation_offset;
  ulong regional_plastic_modulation_offset;
  ulong hot_state_byte_count;
  ulong observation_offset;
  ulong observation_validity_offset;
  ulong object_slot_offset;
  ulong other_agent_slot_offset;
  ulong context_belief_offset;
  ulong relation_slot_offset;
  ulong spatial_transform_offset;
  ulong physiology_belief_offset;
  ulong body_belief_offset;
  ulong joint_belief_offset;
  ulong muscle_belief_offset;
  ulong active_sensing_efficacy_offset;
  ulong somatic_output_offset;
  ulong accepted_autonomic_output_offset;
  ulong accepted_active_sensing_output_offset;
  uint recurrent_scalar_count;
  uint workspace_capacity;
  uint workspace_dimension;
  uint world_model_scalar_count;
  uint drive_count;
  uint neuromodulator_count;
  uint fast_plasticity_count;
  uint active_control_scalar_count;
  uint event_count;
  uint actuator_count;
  uint synergy_count;
  uint module_count;
  uint world_level_count;
  uint world_head_count;
  uint proprioception_observation_offset;
  uint proprioception_observation_count;
  uint observation_count;
  uint vision_observation_offset;
  uint vision_observation_count;
  uint audition_observation_offset;
  uint audition_observation_count;
  uint object_slot_count;
  uint other_agent_slot_count;
  uint context_belief_count;
  uint relation_slot_count;
  uint vestibular_observation_offset;
  uint vestibular_observation_count;
  uint spatial_transform_count;
  uint physiology_belief_count;
  uint body_belief_count;
  uint joint_belief_count;
  uint muscle_belief_count;
  uint olfaction_observation_offset;
  uint olfaction_observation_count;
  uint gustation_observation_offset;
  uint gustation_observation_count;
  uint interoception_observation_offset;
  uint interoception_observation_count;
  uint active_sensing_count;
  uint body_sensing_mask;
  uint autonomic_action_count;
  uint internal_action_count;
  uint plasticity_parameter_count;
  uint reserved;
};

struct NBWorldModelLevelRecord {
  uint level;
  uint base_scalar_offset;
  uint latent_dimension;
  uint update_period_microseconds;
  ulong minimum_horizon_microseconds;
  ulong maximum_horizon_microseconds;
  uint head_count;
  uint flags;
  ulong reserved;
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

struct NBNeuromodulatorStateRecord {
  float value;
  float decay_time_constant_seconds;
  uint kind;
  uint flags;
};

struct NBFastPlasticityStateRecord {
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

struct NBReceptorEventStateRecord {
  uint environment_identifier;
  uint kind;
  uint source_identifier;
  uint flags;
  ulong timestamp_microseconds;
  float magnitude;
  float auxiliary_value;
};

struct NBEventQueueStateHeader {
  atomic_uint count;
  uint capacity;
  atomic_uint overflow_count;
  uint flags;
  ulong target_timestamp_microseconds;
  ulong generation;
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
  float persistence_priority;
  float selection_score;
  uint provenance_kind;
  uint flags;
  ulong provenance_source_generation;
  ulong last_score_update_timestamp_microseconds;
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

struct NBAutonomicCommandRecord {
  float command;
  float target;
  float confidence;
  uint flags;
};

struct NBActiveSensingCommandRecord {
  float command;
  float confidence;
  uint attention_allocation_mask;
  uint kind_and_flags;
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

struct NBOtherAgentSlotRecord {
  ulong identifier;
  ulong last_seen_timestamp_microseconds;
  uint format_version;
  uint flags;
  float existence_probability;
  float identity_confidence;
  float gaze_confidence;
  float goal_confidence;
  float social_relation;
  float predicted_action;
  float uncertainty;
  float communication_evidence;
  float body_pose[8];
  float gaze[4];
  float latent[102];
};

struct NBRelationSlotRecord {
  ulong subject_identifier;
  ulong object_identifier;
  ulong last_evidence_timestamp_microseconds;
  uint relation_kind;
  uint flags;
  float probability;
  float uncertainty;
  float latent[6];
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

struct NBRegionalMaturationRecord {
  uint module_identifier;
  uint unlocked;
  float learning_rate_multiplier;
  float timescale_multiplier;
  float route_gain_multiplier;
  float conduction_delay_multiplier;
  float capacity_fraction;
  uint flags;
};

struct NBRegionalPlasticModulationRecord {
  uint module_identifier;
  uint coefficient_count;
  float recurrent_delta;
  float local_delta;
  float route_delta;
  float drive_delta;
  float gate_delta;
  uint flags;
  float update_gain_multiplier;
  float timescale_multiplier;
  float route_threshold_delta;
  float inhibition_delta;
  float plasticity_decay_multiplier;
  float memory_write_multiplier;
  float vigor_multiplier;
  float exploration_temperature_multiplier;
};

struct NBPlasticityRegionRangeRecord {
  uint module_identifier;
  uint scalar_offset;
  uint scalar_count;
  uint flags;
  ushort token_count;
  ushort token_dimension;
  uint reserved;
};

static_assert(sizeof(NBCognitiveUniforms) == 424);
static_assert(sizeof(NBWorldModelLevelRecord) == 48);
static_assert(sizeof(NBDriveStateRecord) == 32);
static_assert(sizeof(NBNeuromodulatorStateRecord) == 16);
static_assert(sizeof(NBFastPlasticityStateRecord) == 32);
static_assert(sizeof(NBActiveSensingEfficacyRecord) == 32);
static_assert(sizeof(NBReceptorEventStateRecord) == 32);
static_assert(sizeof(NBEventQueueStateHeader) == 32);
static_assert(sizeof(NBWorkspaceMetadataRecord) == 96);
static_assert(sizeof(NBInternalActionRecord) == 64);
static_assert(sizeof(NBAutonomicCommandRecord) == 16);
static_assert(sizeof(NBActiveSensingCommandRecord) == 16);
static_assert(sizeof(NBObjectSlotRecord) == 512);
static_assert(sizeof(NBOtherAgentSlotRecord) == 512);
static_assert(sizeof(NBRelationSlotRecord) == 64);
static_assert(sizeof(NBSpatialTransformRecord) == 96);
static_assert(sizeof(NBDevelopmentalHeader) == 256);
static_assert(sizeof(NBRegionalMaturationRecord) == 32);
static_assert(sizeof(NBRegionalPlasticModulationRecord) == 64);
static_assert(sizeof(NBPlasticityRegionRangeRecord) == 24);

inline float nb_saturate(float value) {
  return clamp(value, 0.0f, 1.0f);
}

inline float nb_plasticity_interval_scale(const ulong delta_microseconds) {
  return float(delta_microseconds) / 20000.0f;
}

inline float nb_plasticity_interval_retention(
  const float reference_retention,
  const float interval_scale)
{
  return interval_scale > 0.0f
    ? pow(clamp(reference_retention, 0.0f, 1.0f), interval_scale)
    : 1.0f;
}

inline float nb_regional_neuromodulator_effect(
  device const float *plasticity_parameters,
  constant NBCognitiveUniforms &uniforms,
  device const NBNeuromodulatorStateRecord *neuromodulators,
  const uint region_index,
  const uint effect_index)
{
  constexpr uint hyperparameter_count = 8u;
  constexpr uint basis_stride = 517u;
  constexpr uint receptor_effect_count = 14u;
  const uint receptor_scalar_count = uniforms.module_count
    * uniforms.neuromodulator_count * receptor_effect_count;
  if (uniforms.plasticity_parameter_count
        < hyperparameter_count + receptor_scalar_count
      || effect_index >= receptor_effect_count) {
    return 0.0f;
  }
  const uint plasticity_scalar_count = uniforms.plasticity_parameter_count
    - hyperparameter_count - receptor_scalar_count;
  const uint basis_capacity = plasticity_scalar_count
    / (uniforms.module_count * basis_stride);
  const uint receptor_offset = hyperparameter_count
    + uniforms.module_count * basis_capacity * basis_stride;
  float effect = 0.0f;
  for (uint channel = 0u; channel < uniforms.neuromodulator_count; ++channel) {
    const uint weight_index = receptor_offset
      + (region_index * uniforms.neuromodulator_count + channel)
        * receptor_effect_count
      + effect_index;
    effect += neuromodulators[channel].value
      * plasticity_parameters[weight_index];
  }
  return effect;
}

/// Converts a learned per-second memory retention into the retention for the
/// exact accepted simulation-time interval. Cognitive dispatch frequency can
/// change with development, arousal, and cohort compaction, so applying the
/// coefficient once per dispatch would make entity lifetime depend on the
/// scheduler rather than physical time.
inline float nb_time_scaled_retention(
  float retained_per_second,
  float elapsed_seconds)
{
  const float bounded = clamp(retained_per_second, 0.0f, 1.0f);
  if (bounded <= 0.0f) return 0.0f;
  if (bounded >= 1.0f) return 1.0f;
  return pow(bounded, max(elapsed_seconds, 0.0f));
}

inline float nb_event_signal(
  device const NBReceptorEventStateRecord *events,
  uint event_count,
  uint event_kind)
{
  float signal = 0.0f;
  for (uint index = 0u; index < event_count; ++index) {
    if (events[index].kind == event_kind) {
      signal = max(signal, nb_saturate(events[index].magnitude));
    }
  }
  return signal;
}

inline float nb_observation_feature(
  device const float *observations,
  device const uint *validity,
  uint range_offset,
  uint range_count,
  uint index)
{
  if (range_count == 0u) return 0.0f;
  const uint scalar_index = range_offset + index % range_count;
  return validity[scalar_index] == 0u ? 0.0f : observations[scalar_index];
}

inline float nb_observation_energy(
  device const float *observations,
  device const uint *validity,
  uint range_offset,
  uint range_count,
  uint seed)
{
  if (range_count == 0u) return 0.0f;
  float energy = 0.0f;
  uint valid_count = 0u;
  for (uint sample = 0u; sample < 8u; ++sample) {
    const uint scalar_index = range_offset
      + (seed * 17u + sample * 29u) % range_count;
    if (validity[scalar_index] == 0u) continue;
    energy += abs(observations[scalar_index]);
    valid_count += 1u;
  }
  return valid_count > 0u ? nb_saturate(energy / float(valid_count)) : 0.0f;
}

inline float nb_fused_interoceptive_feature(
  device const float *observations,
  device const uint *validity,
  uint observation_offset,
  uint observation_count,
  device const float *physiology,
  uint physiology_count,
  uint index)
{
  const uint scalar_index = observation_count > 0u
    ? observation_offset + index % observation_count : 0u;
  const bool has_receptor = observation_count > 0u
    && validity[scalar_index] != 0u;
  const bool has_belief = physiology_count > 0u;
  const float receptor = has_receptor
    ? nb_observation_feature(
        observations, validity, observation_offset, observation_count, index
      )
    : 0.0f;
  const float belief = has_belief
    ? physiology[index % physiology_count]
    : 0.0f;
  if (has_receptor && has_belief) {
    return clamp(0.5f * (receptor + belief), -1.0f, 1.0f);
  }
  return clamp(has_receptor ? receptor : belief, -1.0f, 1.0f);
}

inline ulong nb_latent_slot_identifier(
  ulong name_space,
  float primary_feature,
  float secondary_feature,
  uint slot_index)
{
  uint mixed = as_type<uint>(primary_feature)
    ^ (as_type<uint>(secondary_feature) * 0x9e3779b9u)
    ^ ((slot_index + 1u) * 0x85ebca6bu);
  mixed ^= mixed >> 16u;
  mixed *= 0x7feb352du;
  mixed ^= mixed >> 15u;
  return name_space | (ulong(mixed) << 16u) | ulong(slot_index + 1u);
}

kernel void ingest_regional_recurrent_state(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  device const float *regional_input [[buffer(2)]],
  device const uint *acceptance_gate [[buffer(4)]],
  uint gid [[thread_position_in_grid]])
{
  if (acceptance_gate[0] != 1u) return;
  if (gid >= uniforms.recurrent_scalar_count) return;
  device float *recurrent = reinterpret_cast<device float *>(
    hot_state + uniforms.recurrent_offset
  );
  recurrent[gid] = regional_input[gid];
}

kernel void advance_homeostasis_and_neuromodulation(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= max(uniforms.drive_count, uniforms.neuromodulator_count)) {
    return;
  }
  device NBDriveStateRecord *drives =
    reinterpret_cast<device NBDriveStateRecord *>(hot_state + uniforms.drive_offset);
  device NBNeuromodulatorStateRecord *neuromodulators =
    reinterpret_cast<device NBNeuromodulatorStateRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  device const uint *validity = reinterpret_cast<device const uint *>(
    hot_state + uniforms.observation_validity_offset
  );
  device const float *physiology = reinterpret_cast<device const float *>(
    hot_state + uniforms.physiology_belief_offset
  );
  device NBEventQueueStateHeader *event_header =
    reinterpret_cast<device NBEventQueueStateHeader *>(
      hot_state + uniforms.event_queue_offset
    );
  const uint event_count = min(
    min(atomic_load_explicit(&event_header->count, memory_order_relaxed),
      event_header->capacity),
    uniforms.event_count
  );
  device const NBReceptorEventStateRecord *events =
    reinterpret_cast<device const NBReceptorEventStateRecord *>(event_header + 1);
  const float elapsed_seconds = float(uniforms.delta_microseconds) * 1.0e-6f;
  const float pain = nb_event_signal(events, event_count, 8u);
  const float injury = nb_event_signal(events, event_count, 9u);
  const float support_loss = nb_event_signal(events, event_count, 5u);
  const float overload = nb_event_signal(events, event_count, 7u);
  const float physiological_critical = nb_event_signal(
    events,
    event_count,
    12u
  );
  const float impact = nb_event_signal(events, event_count, 3u);

  if (gid < uniforms.drive_count) {
    NBDriveStateRecord state = drives[gid];
    if (state.kind == 0u) {
      state.kind = gid + 1u;
      state.viable_minimum = -0.1f;
      state.viable_maximum = 0.1f;
      state.priority_weight = 1.0f;
    }
    float target = state.level;
    if (gid < 8u) {
      state.viable_minimum = 0.0f;
      state.viable_maximum = 0.1f;
    }
    const float energy_availability = nb_saturate(nb_fused_interoceptive_feature(
      observations,
      validity,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      0u
    ));
    const float hydration = nb_saturate(nb_fused_interoceptive_feature(
      observations,
      validity,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      1u
    ));
    const float oxygen = nb_saturate(nb_fused_interoceptive_feature(
      observations,
      validity,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      2u
    ));
    const float carbon_dioxide = nb_saturate(nb_fused_interoceptive_feature(
      observations,
      validity,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      3u
    ));
    const float temperature = nb_fused_interoceptive_feature(
      observations,
      validity,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      4u
    );
    const float sensed_fatigue = nb_saturate(nb_fused_interoceptive_feature(
      observations,
      validity,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      5u
    ));
    const float tissue_damage = nb_saturate(nb_fused_interoceptive_feature(
      observations,
      validity,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      6u
    ));
    const float inflammation = nb_saturate(nb_fused_interoceptive_feature(
      observations,
      validity,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      7u
    ));
    const float sleep_pressure = nb_saturate(nb_fused_interoceptive_feature(
      observations,
      validity,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      8u
    ));
    const float interoceptive_alpha = 1.0f - exp(-elapsed_seconds / 0.1f);
    const bool has_interoceptive_evidence =
      uniforms.interoception_observation_count > 0u;
    if (has_interoceptive_evidence && gid == 0u) {
      target = mix(state.level, 1.0f - energy_availability, interoceptive_alpha);
    }
    if (has_interoceptive_evidence && gid == 1u) {
      target = mix(state.level, 1.0f - hydration, interoceptive_alpha);
    }
    if (has_interoceptive_evidence && gid == 2u) target = mix(
      state.level,
      max(1.0f - oxygen, carbon_dioxide),
      interoceptive_alpha
    );
    if (has_interoceptive_evidence && gid == 3u) {
      target = mix(state.level, abs(temperature), interoceptive_alpha);
    }
    if (gid == 4u) target = max(
      has_interoceptive_evidence
        ? mix(state.level, sensed_fatigue, interoceptive_alpha)
        : state.level,
      nb_saturate(state.level + overload * elapsed_seconds)
    );
    if (gid == 5u) target = max(target * exp(-elapsed_seconds * 0.5f), pain);
    if (gid == 6u) target = max(
      max(target * exp(-elapsed_seconds * 0.02f), injury),
      has_interoceptive_evidence ? max(tissue_damage, inflammation) : 0.0f
    );
    if (has_interoceptive_evidence && gid == 7u) {
      target = mix(state.level, sleep_pressure, interoceptive_alpha);
    }
    if (gid == 2u) target = max(target, physiological_critical);
    if (gid == 11u) {
      target = max(max(injury, support_loss), max(impact, physiological_critical));
    }
    const float previous = state.level;
    state.level = target;
    state.estimated_rate = elapsed_seconds > 0.0f
      ? (state.level - previous) / elapsed_seconds
      : 0.0f;
    state.deficit = state.level < state.viable_minimum
      ? state.viable_minimum - state.level
      : (state.level > state.viable_maximum
        ? state.level - state.viable_maximum
        : 0.0f);
    state.potential = state.priority_weight * state.deficit * state.deficit;
    drives[gid] = state;
  }

  if (gid < uniforms.neuromodulator_count) {
    NBNeuromodulatorStateRecord state = neuromodulators[gid];
    if (state.kind == 0u) {
      state.kind = gid + 1u;
      state.decay_time_constant_seconds = 0.1f;
    }
    const float time_constant = max(state.decay_time_constant_seconds, 1.0e-4f);
    float signal = state.value * exp(-elapsed_seconds / time_constant);
    if (gid == 4u) signal = max(signal, pain);
    if (gid == 5u) signal = max(signal, max(injury, support_loss));
    if (gid == 6u) signal = max(signal, max(impact, physiological_critical));
    if (gid == 9u) signal = max(signal, overload);
    if (gid == 11u) signal = max(signal, physiological_critical);
    state.value = signal;
    neuromodulators[gid] = state;
  }
}

inline float nb_world_action_context(
  device const uchar *hot_state,
  constant NBCognitiveUniforms &uniforms,
  const uint level,
  const uint component)
{
  device const float *somatic = reinterpret_cast<device const float *>(
    hot_state + uniforms.somatic_output_offset
  );
  device const NBAutonomicCommandRecord *autonomic =
    reinterpret_cast<device const NBAutonomicCommandRecord *>(
      hot_state + uniforms.accepted_autonomic_output_offset
    );
  device const NBActiveSensingCommandRecord *sensing =
    reinterpret_cast<device const NBActiveSensingCommandRecord *>(
      hot_state + uniforms.accepted_active_sensing_output_offset
    );
  device const NBInternalActionRecord *internal_actions =
    reinterpret_cast<device const NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  const float somatic_value = uniforms.actuator_count > 0u
    ? somatic[component % uniforms.actuator_count] : 0.0f;
  const NBAutonomicCommandRecord autonomic_record = autonomic[
    component % max(uniforms.autonomic_action_count, 1u)
  ];
  const float autonomic_value = uniforms.autonomic_action_count > 0u
      && (autonomic_record.flags & 1u) != 0u
    ? autonomic_record.command : 0.0f;
  const NBActiveSensingCommandRecord sensing_record = sensing[
    component % max(uniforms.active_sensing_count, 1u)
  ];
  const float sensing_value = uniforms.active_sensing_count > 0u
      && (sensing_record.kind_and_flags & (1u << 16u)) != 0u
    ? sensing_record.command : 0.0f;
  const NBInternalActionRecord internal_record = internal_actions[
    component % max(uniforms.internal_action_count, 1u)
  ];
  const float internal_value = uniforms.internal_action_count > 0u
      && (internal_record.flags & 1u) != 0u
    ? internal_record.priority * internal_record.confidence : 0.0f;
  float action_context;
  switch (level) {
    case 0u:
      if (component < 48u) {
        // Vision and audition depend on physically accepted orienting/sensing.
        action_context = sensing_value;
      } else if (component < 64u) {
        // Touch combines active palpation with self-generated body motion.
        action_context = 0.5f * somatic_value + 0.5f * sensing_value;
      } else if (component < 96u) {
        // Proprioception and vestibular consequences are somatic.
        action_context = somatic_value;
      } else if (component < 116u) {
        // Olfaction and taste include sniffing and sampling actions.
        action_context = sensing_value;
      } else {
        // Interoceptive receptor dynamics follow accepted autonomic output.
        action_context = autonomic_value;
      }
      break;
    case 1u:
      action_context = 0.5f * somatic_value + 0.25f * autonomic_value
        + 0.25f * sensing_value;
      break;
    case 2u:
      action_context = 0.35f * somatic_value + 0.4f * sensing_value
        + 0.25f * internal_value;
      break;
    case 3u:
      action_context = 0.4f * autonomic_value + 0.6f * internal_value;
      break;
    default:
      action_context = 0.25f * autonomic_value + 0.75f * internal_value;
      break;
  }
  return isfinite(action_context) ? clamp(action_context, -1.0f, 1.0f) : 0.0f;
}

inline float nb_body_sensorimotor_feature(
  device const float *body,
  uint feature)
{
  const float value = body[feature];
  if (!isfinite(value)) return 0.0f;
  if (feature >= NB_BODY_ORIENTATION
      && feature < NB_BODY_ORIENTATION + 4u) {
    return clamp(value, -1.0f, 1.0f);
  }
  if ((feature >= NB_BODY_POSITION_VARIANCE
        && feature < NB_BODY_POSITION_VARIANCE + 3u)
      || (feature >= NB_BODY_ORIENTATION_VARIANCE
        && feature < NB_BODY_ORIENTATION_VARIANCE + 3u)
      || feature == NB_BODY_LOAD_VARIANCE) {
    const float standard_deviation = sqrt(max(value, 0.0f));
    return standard_deviation / (1.0f + standard_deviation);
  }
  if (feature == NB_BODY_CONTACT || feature == NB_BODY_SUPPORT
      || feature == NB_BODY_PAIN || feature == NB_BODY_VULNERABILITY
      || feature == NB_BODY_REACHABILITY || feature == NB_BODY_OWNERSHIP
      || feature == NB_BODY_DAMAGE_RISK
      || feature == NB_BODY_EXTERNAL_DISTURBANCE) {
    return clamp(value, 0.0f, 1.0f);
  }
  return value / (1.0f + abs(value));
}

/// Gives every sensorimotor latent a deterministic projection of one full
/// accepted body-node posterior. Repeated components form independent signed
/// projections, preserving vector state without a scalar body summary.
inline float nb_body_sensorimotor_projection(
  device const uchar *hot_state,
  constant NBCognitiveUniforms &uniforms,
  uint component,
  thread bool &has_evidence)
{
  has_evidence = false;
  if (uniforms.body_belief_count == 0u) return 0.0f;
  const uint body_index = min(
    uint((ulong(component) * ulong(uniforms.body_belief_count))
      / ulong(NB_WORLD_SENSORIMOTOR_DIMENSION)),
    uniforms.body_belief_count - 1u
  );
  const uint projection = component;
  device const float *body = reinterpret_cast<device const float *>(
    hot_state + uniforms.body_belief_offset + ulong(body_index) * 256ul
  );
  device const ulong *identity = reinterpret_cast<device const ulong *>(
    body + NB_BODY_IDENTITY_FLOAT_OFFSET
  );
  if ((identity[3] & 1ul) == 0ul) return 0.0f;
  float total = 0.0f;
  uint finite_count = 0u;
  for (uint feature = 0u; feature < NB_BODY_SENSORIMOTOR_FEATURE_COUNT;
      ++feature) {
    if (!isfinite(body[feature])) continue;
    uint hash = (feature + 1u) * 0x9e3779b9u
      ^ (projection + 1u) * 0x85ebca6bu
      ^ (body_index + 1u) * 0xc2b2ae35u;
    hash ^= hash >> 16u;
    const float sign = (hash & 1u) == 0u ? -1.0f : 1.0f;
    total += sign * nb_body_sensorimotor_feature(body, feature);
    finite_count += 1u;
  }
  has_evidence = finite_count > 0u;
  return has_evidence ? clamp(
    total * rsqrt(float(finite_count)), -1.0f, 1.0f
  ) : 0.0f;
}

inline float nb_joint_sensorimotor_feature(
  device const float *joint,
  uint feature)
{
  const float value = joint[feature];
  if (!isfinite(value)) return 0.0f;
  if ((feature >= NB_JOINT_POSITION_VARIANCE
        && feature < NB_JOINT_POSITION_VARIANCE + 6u)
      || (feature >= NB_JOINT_VELOCITY_VARIANCE
        && feature < NB_JOINT_VELOCITY_VARIANCE + 6u)) {
    const float standard_deviation = sqrt(max(value, 0.0f));
    return standard_deviation / (1.0f + standard_deviation);
  }
  if ((feature >= NB_JOINT_LIMIT_ACTIVATION
        && feature < NB_JOINT_LIMIT_ACTIVATION + 6u)
      || feature == NB_JOINT_OWNERSHIP) {
    return clamp(value, 0.0f, 1.0f);
  }
  if (feature == NB_JOINT_PREDICTION_ERROR) {
    const float magnitude = abs(value);
    return magnitude / (1.0f + magnitude);
  }
  return value / (1.0f + abs(value));
}

inline bool nb_joint_feature_is_active(uint feature, uint coordinate_count) {
  if (feature < 6u) return feature < coordinate_count;
  if (feature < 12u) return feature - 6u < coordinate_count;
  if (feature < 18u) return feature - 12u < coordinate_count;
  if (feature < 24u) return feature - 18u < coordinate_count;
  if (feature < 30u) return feature - 24u < coordinate_count;
  return feature < 32u;
}

/// Projects exact articulated coordinate posteriors into the level-1 latent.
/// Each component owns a deterministic strided subset, so joints beyond the
/// 256-dimensional latent still contribute without a host-side reduction.
inline float nb_joint_sensorimotor_projection(
  device const uchar *hot_state,
  constant NBCognitiveUniforms &uniforms,
  uint component,
  thread bool &has_evidence)
{
  has_evidence = false;
  if (uniforms.joint_belief_count == 0u) return 0.0f;
  const uint lane_count = min(
    uniforms.joint_belief_count, NB_WORLD_SENSORIMOTOR_DIMENSION
  );
  const uint first_joint = component % lane_count;
  float projection_total = 0.0f;
  uint projection_count = 0u;
  for (uint joint_index = first_joint;
      joint_index < uniforms.joint_belief_count;
      joint_index += lane_count) {
    device const float *joint = reinterpret_cast<device const float *>(
      hot_state + uniforms.joint_belief_offset + ulong(joint_index) * 256ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      joint + NB_JOINT_IDENTITY_FLOAT_OFFSET
    );
    if ((identity[7] & 1ul) == 0ul) continue;
    const uint coordinate_count = min(uint(identity[3]), 6u);
    float total = 0.0f;
    uint finite_count = 0u;
    for (uint feature = 0u; feature < 32u; ++feature) {
      if (!nb_joint_feature_is_active(feature, coordinate_count)
          || !isfinite(joint[feature])) continue;
      uint hash = (feature + 1u) * 0x27d4eb2du
        ^ (component + 1u) * 0x165667b1u
        ^ (joint_index + 1u) * 0x9e3779b9u;
      hash ^= hash >> 15u;
      const float sign = (hash & 1u) == 0u ? -1.0f : 1.0f;
      total += sign * nb_joint_sensorimotor_feature(joint, feature);
      finite_count += 1u;
    }
    if (finite_count == 0u) continue;
    projection_total += clamp(
      total * rsqrt(float(finite_count)), -1.0f, 1.0f
    );
    projection_count += 1u;
  }
  has_evidence = projection_count > 0u;
  return has_evidence
    ? clamp(projection_total / float(projection_count), -1.0f, 1.0f)
    : 0.0f;
}

inline float nb_muscle_sensorimotor_feature(
  device const float *muscle,
  uint feature)
{
  const float value = muscle[feature];
  if (!isfinite(value)) return 0.0f;
  if (feature == 0u || feature == 4u || feature == 8u || feature == 9u) {
    return clamp(value, 0.0f, 1.0f);
  }
  if (feature == 3u || feature == 5u) {
    const float magnitude = abs(value);
    return magnitude / (1.0f + magnitude);
  }
  return value / (1.0f + abs(value));
}

/// Projects muscle or actuator belief without assuming its record count fits
/// inside the latent width. Validity remains owned by accepted consequences.
inline float nb_muscle_sensorimotor_projection(
  device const uchar *hot_state,
  constant NBCognitiveUniforms &uniforms,
  uint component,
  thread bool &has_evidence)
{
  has_evidence = false;
  if (uniforms.muscle_belief_count == 0u) return 0.0f;
  const uint lane_count = min(
    uniforms.muscle_belief_count, NB_WORLD_SENSORIMOTOR_DIMENSION
  );
  const uint first_muscle = component % lane_count;
  float projection_total = 0.0f;
  uint projection_count = 0u;
  for (uint muscle_index = first_muscle;
      muscle_index < uniforms.muscle_belief_count;
      muscle_index += lane_count) {
    device const float *muscle = reinterpret_cast<device const float *>(
      hot_state + uniforms.muscle_belief_offset + ulong(muscle_index) * 192ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      muscle + NB_MUSCLE_IDENTITY_FLOAT_OFFSET
    );
    if ((identity[3] & 1ul) == 0ul) continue;
    float total = 0.0f;
    uint finite_count = 0u;
    for (uint feature = 0u;
        feature < NB_MUSCLE_SENSORIMOTOR_FEATURE_COUNT; ++feature) {
      if (!isfinite(muscle[feature])) continue;
      uint hash = (feature + 1u) * 0x85ebca6bu
        ^ (component + 1u) * 0xc2b2ae35u
        ^ (muscle_index + 1u) * 0x27d4eb2du;
      hash ^= hash >> 16u;
      const float sign = (hash & 1u) == 0u ? -1.0f : 1.0f;
      total += sign * nb_muscle_sensorimotor_feature(muscle, feature);
      finite_count += 1u;
    }
    if (finite_count == 0u) continue;
    projection_total += clamp(
      total * rsqrt(float(finite_count)), -1.0f, 1.0f
    );
    projection_count += 1u;
  }
  has_evidence = projection_count > 0u;
  return has_evidence
    ? clamp(projection_total / float(projection_count), -1.0f, 1.0f)
    : 0.0f;
}

inline float nb_embodied_sensorimotor_projection(
  device const uchar *hot_state,
  constant NBCognitiveUniforms &uniforms,
  uint component)
{
  bool has_body = false;
  bool has_joint = false;
  bool has_muscle = false;
  const float body = nb_body_sensorimotor_projection(
    hot_state, uniforms, component, has_body
  );
  const float joint = nb_joint_sensorimotor_projection(
    hot_state, uniforms, component, has_joint
  );
  const float muscle = nb_muscle_sensorimotor_projection(
    hot_state, uniforms, component, has_muscle
  );
  float total = 0.0f;
  float weight = 0.0f;
  if (has_body) { total += 0.5f * body; weight += 0.5f; }
  if (has_joint) { total += 0.25f * joint; weight += 0.25f; }
  if (has_muscle) { total += 0.25f * muscle; weight += 0.25f; }
  return weight > 0.0f ? clamp(total / weight, -1.0f, 1.0f) : 0.0f;
}

/// Projects the explicit compatible belief factors into the matching world
/// level. The world update runs before this tick's posterior slot correction,
/// so these are strictly X_t priors used to predict X_t+1.
inline float nb_world_structured_belief_context(
  device const uchar *hot_state,
  constant NBCognitiveUniforms &uniforms,
  const uint level,
  const uint component)
{
  float total = 0.0f;
  uint count = 0u;
  if (level == 0u) {
    device const NBSpatialTransformRecord *transforms =
      reinterpret_cast<device const NBSpatialTransformRecord *>(
        hot_state + uniforms.spatial_transform_offset
      );
    for (uint index = 0u; index < min(uniforms.spatial_transform_count, 5u);
        ++index) {
      const NBSpatialTransformRecord transform = transforms[index];
      if ((transform.flags & 1u) == 0u) continue;
      const float motion = (transform.linear_velocity[0]
        + transform.linear_velocity[1] + transform.linear_velocity[2]) / 3.0f;
      total += transform.confidence
        * (0.5f * tanh(motion) + 0.5f * (1.0f - transform.uncertainty));
      count += 1u;
    }
  } else if (level == 1u || level == 2u) {
    const float embodied_context = level == 1u
      ? nb_embodied_sensorimotor_projection(hot_state, uniforms, component)
      : 0.0f;
    device const NBObjectSlotRecord *objects =
      reinterpret_cast<device const NBObjectSlotRecord *>(
        hot_state + uniforms.object_slot_offset
      );
    for (uint index = 0u; index < uniforms.object_slot_count; ++index) {
      const NBObjectSlotRecord object = objects[index];
      if (object.identifier == 0ul || object.existence_probability <= 0.0f) {
        continue;
      }
      const float certainty = object.existence_probability
        * (1.0f - object.uncertainty);
      if (level == 1u) {
        const float motion = (object.velocity[0] + object.velocity[1]
          + object.velocity[2]) / 3.0f;
        total += certainty
          * (0.5f * tanh(motion) + 0.5f * object.affordances[0]);
      } else {
        const float position = (object.pose[0] + object.pose[1]
          + object.pose[2]) / 3.0f;
        total += certainty * (
          0.25f * tanh(position) + 0.25f * object.identity_confidence
            + 0.25f * object.visibility + 0.25f * object.affordances[0]
        );
      }
      count += 1u;
    }
    if (level == 1u) {
      const float object_context = count == 0u ? 0.0f : total / float(count);
      return clamp(
        0.75f * embodied_context + 0.25f * object_context, -1.0f, 1.0f
      );
    }
  } else if (level == 3u) {
    device const NBRelationSlotRecord *relations =
      reinterpret_cast<device const NBRelationSlotRecord *>(
        hot_state + uniforms.relation_slot_offset
      );
    for (uint index = 0u; index < uniforms.relation_slot_count; ++index) {
      const NBRelationSlotRecord relation = relations[index];
      if ((relation.flags & 1u) == 0u || relation.probability <= 0.0f) continue;
      total += relation.probability * (1.0f - relation.uncertainty)
        * tanh(relation.latent[0]);
      count += 1u;
    }
  } else {
    device const NBOtherAgentSlotRecord *agents =
      reinterpret_cast<device const NBOtherAgentSlotRecord *>(
        hot_state + uniforms.other_agent_slot_offset
      );
    for (uint index = 0u; index < uniforms.other_agent_slot_count; ++index) {
      const NBOtherAgentSlotRecord agent = agents[index];
      if (agent.identifier == 0ul || agent.existence_probability <= 0.0f) continue;
      const float social = 0.25f * (
        agent.predicted_action + agent.social_relation
          + agent.communication_evidence + agent.goal_confidence
      );
      total += agent.existence_probability * (1.0f - agent.uncertainty)
        * tanh(social);
      count += 1u;
    }
  }
  return count == 0u ? 0.0f : clamp(total / float(count), -1.0f, 1.0f);
}

kernel void advance_hierarchical_world_model(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  device const float *world_parameters [[buffer(2)]],
  constant NBWorldModelLevelRecord &level [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= level.latent_dimension || uniforms.recurrent_scalar_count == 0u
      || level.head_count != 5u || uniforms.world_head_count != 5u
      || level.level >= uniforms.world_level_count) {
    return;
  }
  const ulong previous_timestamp = uniforms.target_timestamp_microseconds
      > uniforms.delta_microseconds
    ? uniforms.target_timestamp_microseconds - uniforms.delta_microseconds
    : 0ul;
  if (previous_timestamp / ulong(level.update_period_microseconds)
      == uniforms.target_timestamp_microseconds
        / ulong(level.update_period_microseconds)) return;
  device const float *recurrent = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  device float *world = reinterpret_cast<device float *>(
    hot_state + uniforms.world_model_offset
  );
  device const NBDriveStateRecord *drives =
    reinterpret_cast<device const NBDriveStateRecord *>(hot_state + uniforms.drive_offset);
  device const NBNeuromodulatorStateRecord *neuromodulators =
    reinterpret_cast<device const NBNeuromodulatorStateRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  const uint base = level.base_scalar_offset;
  const uint dimension = level.latent_dimension;
  const uint latent_index = base + gid;
  const uint error_index = base + dimension + gid;
  const uint context_index = base + 2u * dimension + gid;
  if (base + 9u * dimension > uniforms.world_model_scalar_count) return;
  float bottom_up = recurrent[
    (gid + level.level * 131u) % uniforms.recurrent_scalar_count
  ];
  if (level.level > 0u) {
    uint lower_base = 0u;
    uint lower_dimension = 0u;
    if (level.level == 1u) {
      lower_base = 0u;
      lower_dimension = 128u;
    } else if (level.level == 2u) {
      lower_base = 128u * 9u;
      lower_dimension = 256u;
    } else if (level.level == 3u) {
      lower_base = (128u + 256u) * 9u;
      lower_dimension = 256u;
    } else {
      lower_base = (128u + 256u + 256u) * 9u;
      lower_dimension = 256u;
    }
    bottom_up = world[lower_base + (gid % lower_dimension)]
      + 0.25f * world[
        lower_base + lower_dimension + (gid % lower_dimension)
      ];
  }
  float top_down = 0.0f;
  if (level.level + 1u < uniforms.world_level_count) {
    const uint upper_base = base + 9u * dimension;
    const uint upper_dimension = 256u;
    top_down = world[upper_base + (gid % upper_dimension)];
  }
  const float previous_latent = world[latent_index];
  const float drive = drives[gid % uniforms.drive_count].deficit;
  const float modulation = neuromodulators[gid % uniforms.neuromodulator_count].value;
  const float action_context = nb_world_action_context(
    hot_state, uniforms, level.level, gid
  );
  const float structured_context = nb_world_structured_belief_context(
    hot_state, uniforms, level.level, gid
  );
  float mean_prediction = 0.0f;
  float head_predictions[5];
  for (uint head = 0u; head < 5u; ++head) {
    const uint parameter_base = (level.level * 5u + head) * 6u;
    const float prediction = tanh(
      world_parameters[parameter_base] * previous_latent
        + world_parameters[parameter_base + 1u] * bottom_up
        + world_parameters[parameter_base + 2u] * top_down
        + world_parameters[parameter_base + 3u] * drive
        + world_parameters[parameter_base + 4u] * modulation
        + world_parameters[160u + level.level * 5u + head] * action_context
        + world_parameters[185u + level.level] * structured_context
        + world_parameters[parameter_base + 5u]
    );
    head_predictions[head] = prediction;
    mean_prediction += prediction * 0.2f;
    world[base + (3u + head) * dimension + gid] = prediction;
  }
  float epistemic_variance = 0.0f;
  for (uint head = 0u; head < 5u; ++head) {
    const float difference = head_predictions[head] - mean_prediction;
    epistemic_variance += difference * difference * 0.2f;
  }
  const float residual = bottom_up - mean_prediction;
  const uint aleatoric_index = base + 8u * dimension + gid;
  const float elapsed_seconds = float(level.update_period_microseconds) * 1.0e-6f;
  const float horizon_seconds = max(
    float(level.minimum_horizon_microseconds) * 1.0e-6f,
    elapsed_seconds
  );
  const float alpha = 1.0f - exp(-elapsed_seconds / horizon_seconds);
  world[latent_index] = mix(
    previous_latent, mean_prediction, nb_saturate(alpha)
  );
  world[error_index] = residual;
  world[context_index] = top_down;
  world[aleatoric_index] = mix(
    max(world[aleatoric_index], 0.0f), residual * residual,
    nb_saturate(alpha * 0.25f)
  );
  if (gid == 0u && level.level == 0u && uniforms.neuromodulator_count > 3u) {
    device NBNeuromodulatorStateRecord *mutable_neuromodulators =
      reinterpret_cast<device NBNeuromodulatorStateRecord *>(
        hot_state + uniforms.neuromodulation_offset
      );
    mutable_neuromodulators[3].value = nb_saturate(
      sqrt(max(epistemic_variance, 0.0f))
    );
  }
}

/// Converts predictive ensemble disagreement into an autonomous information
/// drive after every due world-model level has advanced. Accepted per-channel
/// efficacy determines whether uncertainty is actually actionable; pain,
/// injury, fatigue, sleep pressure, and safety demand suppress exploration.
kernel void update_curiosity_drive_from_world_model(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.drive_count <= 8u) return;
  device const float *world = reinterpret_cast<device const float *>(
    hot_state + uniforms.world_model_offset
  );
  device NBDriveStateRecord *drives =
    reinterpret_cast<device NBDriveStateRecord *>(
      hot_state + uniforms.drive_offset
    );
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  device const NBActiveSensingEfficacyRecord *sensing_efficacy =
    reinterpret_cast<device const NBActiveSensingEfficacyRecord *>(
      hot_state + uniforms.active_sensing_efficacy_offset
    );
  float epistemic_variance = 0.0f;
  if (uniforms.world_model_scalar_count >= 9u * 128u) {
    for (uint index = 0u; index < 128u; ++index) {
      float mean = 0.0f;
      for (uint head = 0u; head < 5u; ++head) {
        mean += world[(3u + head) * 128u + index] * 0.2f;
      }
      for (uint head = 0u; head < 5u; ++head) {
        const float difference = world[
          (3u + head) * 128u + index
        ] - mean;
        epistemic_variance += difference * difference * 0.2f;
      }
    }
    epistemic_variance /= 128.0f;
  }
  float best_sensing_efficacy =
    uniforms.active_sensing_count == 0u ? 1.0f : 0.0f;
  float best_body_sensing_efficacy = 0.0f;
  for (uint channel = 0u; channel < uniforms.active_sensing_count; ++channel) {
    const NBActiveSensingEfficacyRecord sensing = sensing_efficacy[channel];
    const float efficacy = sensing.sample_count > 0u
        && (sensing.flags & 1u) != 0u
      ? clamp(sensing.efficacy, 0.0f, 1.0f)
      : 1.0f;
    best_sensing_efficacy = max(best_sensing_efficacy, efficacy);
    if (channel < 32u
        && (uniforms.body_sensing_mask & (1u << channel)) != 0u) {
      best_body_sensing_efficacy = max(
        best_body_sensing_efficacy, efficacy
      );
    }
  }
  float body_model_uncertainty = 0.0f;
  for (uint body_index = 0u;
      body_index < uniforms.body_belief_count; ++body_index) {
    device const float *body = reinterpret_cast<device const float *>(
      hot_state + uniforms.body_belief_offset + ulong(body_index) * 256ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      body + NB_BODY_IDENTITY_FLOAT_OFFSET
    );
    if ((identity[3] & 1ul) == 0ul
        || !isfinite(body[NB_BODY_LOAD_VARIANCE])) continue;
    const float standard_deviation = sqrt(
      max(body[NB_BODY_LOAD_VARIANCE], 0.0f)
    );
    body_model_uncertainty = max(
      body_model_uncertainty,
      standard_deviation / (1.0f + standard_deviation)
    );
  }
  for (uint joint_index = 0u;
      joint_index < uniforms.joint_belief_count; ++joint_index) {
    device const float *joint = reinterpret_cast<device const float *>(
      hot_state + uniforms.joint_belief_offset + ulong(joint_index) * 256ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      joint + NB_JOINT_IDENTITY_FLOAT_OFFSET
    );
    if ((identity[7] & 1ul) == 0ul) continue;
    const uint coordinate_count = min(uint(identity[3]), 6u);
    for (uint coordinate = 0u; coordinate < coordinate_count; ++coordinate) {
      const float joint_variance = max(
        max(joint[NB_JOINT_POSITION_VARIANCE + coordinate], 0.0f),
        max(joint[NB_JOINT_VELOCITY_VARIANCE + coordinate], 0.0f)
      );
      const float standard_deviation = sqrt(joint_variance);
      body_model_uncertainty = max(
        body_model_uncertainty,
        standard_deviation / (1.0f + standard_deviation)
      );
    }
    const float prediction_error = abs(joint[NB_JOINT_PREDICTION_ERROR]);
    body_model_uncertainty = max(
      body_model_uncertainty,
      prediction_error / (1.0f + prediction_error)
    );
  }
  for (uint muscle_index = 0u;
      muscle_index < uniforms.muscle_belief_count; ++muscle_index) {
    device const float *muscle = reinterpret_cast<device const float *>(
      hot_state + uniforms.muscle_belief_offset + ulong(muscle_index) * 192ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      muscle + NB_MUSCLE_IDENTITY_FLOAT_OFFSET
    );
    if ((identity[3] & 1ul) == 0ul) continue;
    const float prediction_error = abs(muscle[5]);
    const float low_agency = 1.0f - clamp(muscle[8], 0.0f, 1.0f);
    body_model_uncertainty = max(
      body_model_uncertainty,
      max(prediction_error / (1.0f + prediction_error), low_agency)
    );
  }
  float structured_belief_uncertainty = 0.0f;
  device const NBObjectSlotRecord *objects =
    reinterpret_cast<device const NBObjectSlotRecord *>(
      hot_state + uniforms.object_slot_offset
    );
  for (uint index = 0u; index < uniforms.object_slot_count; ++index) {
    const NBObjectSlotRecord object = objects[index];
    if (object.identifier == 0ul || object.existence_probability <= 0.0f) continue;
    structured_belief_uncertainty = max(
      structured_belief_uncertainty,
      object.existence_probability * clamp(object.uncertainty, 0.0f, 1.0f)
    );
  }
  device const NBOtherAgentSlotRecord *agents =
    reinterpret_cast<device const NBOtherAgentSlotRecord *>(
      hot_state + uniforms.other_agent_slot_offset
    );
  for (uint index = 0u; index < uniforms.other_agent_slot_count; ++index) {
    const NBOtherAgentSlotRecord agent = agents[index];
    if (agent.identifier == 0ul || agent.existence_probability <= 0.0f) continue;
    structured_belief_uncertainty = max(
      structured_belief_uncertainty,
      agent.existence_probability * clamp(agent.uncertainty, 0.0f, 1.0f)
    );
  }
  device const NBRelationSlotRecord *relations =
    reinterpret_cast<device const NBRelationSlotRecord *>(
      hot_state + uniforms.relation_slot_offset
    );
  for (uint index = 0u; index < uniforms.relation_slot_count; ++index) {
    const NBRelationSlotRecord relation = relations[index];
    if ((relation.flags & 1u) == 0u || relation.probability <= 0.0f) continue;
    structured_belief_uncertainty = max(
      structured_belief_uncertainty,
      relation.probability * clamp(relation.uncertainty, 0.0f, 1.0f)
    );
  }
  device const NBSpatialTransformRecord *transforms =
    reinterpret_cast<device const NBSpatialTransformRecord *>(
      hot_state + uniforms.spatial_transform_offset
    );
  for (uint index = 0u; index < uniforms.spatial_transform_count; ++index) {
    const NBSpatialTransformRecord transform = transforms[index];
    if ((transform.flags & 1u) == 0u) continue;
    structured_belief_uncertainty = max(
      structured_belief_uncertainty,
      clamp(transform.uncertainty, 0.0f, 1.0f)
    );
  }
  const float fatigue = uniforms.drive_count > 4u
    ? clamp(drives[4].level, 0.0f, 1.0f) : 0.0f;
  const float pain = uniforms.drive_count > 5u
    ? clamp(drives[5].level, 0.0f, 1.0f) : 0.0f;
  const float injury = uniforms.drive_count > 6u
    ? clamp(drives[6].level, 0.0f, 1.0f) : 0.0f;
  const float sleep_pressure = uniforms.drive_count > 7u
    ? clamp(drives[7].level, 0.0f, 1.0f) : 0.0f;
  const float safety = uniforms.drive_count > 11u
    ? clamp(drives[11].level, 0.0f, 1.0f) : 0.0f;
  const float safe_capacity = (1.0f - max(max(pain, injury), safety))
    * (1.0f - 0.5f * fatigue) * (1.0f - sleep_pressure);
  NBDriveStateRecord curiosity = drives[8];
  if (curiosity.kind == 0u) curiosity.kind = 9u;
  if (curiosity.priority_weight <= 0.0f) curiosity.priority_weight = 1.0f;
  curiosity.viable_minimum = 0.0f;
  curiosity.viable_maximum = 0.1f;
  const float previous = curiosity.level;
  curiosity.level = development->stage > 0u
    ? clamp(
        max(
          max(
            sqrt(max(epistemic_variance, 0.0f)) * best_sensing_efficacy,
            structured_belief_uncertainty * best_sensing_efficacy
          ),
          body_model_uncertainty * best_body_sensing_efficacy
        ) * safe_capacity,
        0.0f,
        1.0f
      )
    : 0.0f;
  const float elapsed_seconds = max(
    float(uniforms.delta_microseconds) * 1.0e-6f, 1.0e-6f
  );
  curiosity.estimated_rate = (curiosity.level - previous) / elapsed_seconds;
  curiosity.deficit = curiosity.level > curiosity.viable_maximum
    ? curiosity.level - curiosity.viable_maximum : 0.0f;
  curiosity.potential = curiosity.priority_weight
    * curiosity.deficit * curiosity.deficit;
  drives[8] = curiosity;
}

/// Maintains causal latent object and other-agent factors. These records never
/// consume privileged entity identifiers: their identity is a persistent,
/// deterministic hypothesis formed only from transduced observations.
kernel void advance_entity_and_social_slots(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  device const float *belief_parameters [[buffer(2)]],
  device const uint *acceptance_gate [[buffer(4)]],
  uint gid [[thread_position_in_grid]])
{
  if (acceptance_gate[0] != 1u) return;
  device const NBEventQueueStateHeader *event_header =
    reinterpret_cast<device const NBEventQueueStateHeader *>(
      hot_state + uniforms.event_queue_offset
    );
  if ((event_header->flags & NB_SENSORY_FRAME_REUSED) != 0u) return;
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  device const uint *validity = reinterpret_cast<device const uint *>(
    hot_state + uniforms.observation_validity_offset
  );
  device const float *recurrent = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  const uint event_count = min(
    min(atomic_load_explicit(&event_header->count, memory_order_relaxed),
      event_header->capacity),
    uniforms.event_count
  );
  device const NBReceptorEventStateRecord *events =
    reinterpret_cast<device const NBReceptorEventStateRecord *>(event_header + 1);
  const float visual_transient = nb_event_signal(events, event_count, 11u);
  const float sound_onset = nb_event_signal(events, event_count, 10u);
  const float elapsed_seconds = max(
    float(uniforms.delta_microseconds) * 1.0e-6f, 1.0e-6f
  );
  const float retention = nb_time_scaled_retention(
    belief_parameters[7], elapsed_seconds
  );
  const float correction_gain = clamp(
    belief_parameters[0] + belief_parameters[2] * visual_transient,
    0.001f,
    1.0f
  );

  if (gid < uniforms.object_slot_count) {
    device NBObjectSlotRecord *object_slots =
      reinterpret_cast<device NBObjectSlotRecord *>(
        hot_state + uniforms.object_slot_offset
      );
    if (development->stage < 6u
        || (uniforms.vision_observation_count == 0u
          && uniforms.olfaction_observation_count == 0u
          && uniforms.gustation_observation_count == 0u)) {
      NBObjectSlotRecord inactive = {};
      object_slots[gid] = inactive;
    } else {
      NBObjectSlotRecord slot = object_slots[gid];
      const uint seed = gid * 23u + 3u;
      const float energy = nb_observation_energy(
        observations,
        validity,
        uniforms.vision_observation_offset,
        uniforms.vision_observation_count,
        seed
      );
      const float olfactory_energy = nb_observation_energy(
        observations,
        validity,
        uniforms.olfaction_observation_offset,
        uniforms.olfaction_observation_count,
        seed + 11u
      );
      const float gustatory_energy = nb_observation_energy(
        observations,
        validity,
        uniforms.gustation_observation_offset,
        uniforms.gustation_observation_count,
        seed + 19u
      );
      const float visual_presence = nb_saturate(
        (energy - max(belief_parameters[4], 0.0f))
          * max(4.0f * belief_parameters[3], 0.25f)
          + 0.5f * visual_transient
      );
      const float chemical_presence = nb_saturate(
        max(olfactory_energy, gustatory_energy)
          - max(0.5f * belief_parameters[4], 0.0f)
      );
      const float candidate_presence = max(visual_presence, chemical_presence);
      float observed_pose[4];
      for (uint component = 0u; component < 4u; ++component) {
        const uint pose_offset = uniforms.vision_observation_count > 0u
          ? uniforms.vision_observation_offset
          : (uniforms.olfaction_observation_count > 0u
            ? uniforms.olfaction_observation_offset
            : uniforms.gustation_observation_offset);
        const uint pose_count = uniforms.vision_observation_count > 0u
          ? uniforms.vision_observation_count
          : (uniforms.olfaction_observation_count > 0u
            ? uniforms.olfaction_observation_count
            : uniforms.gustation_observation_count);
        observed_pose[component] = nb_observation_feature(
          observations,
          validity,
          pose_offset,
          pose_count,
          seed * 11u + component * 31u
        );
      }
      if (slot.format_version == 0u) {
        slot.format_version = 1u;
        slot.uncertainty = 1.0f;
      }

      const bool had_identity = slot.identifier != 0ul;
      float predicted_pose[4];
      float pose_difference = 0.0f;
      for (uint component = 0u; component < 4u; ++component) {
        predicted_pose[component] = slot.pose[component]
          + retention * slot.velocity[component] * elapsed_seconds;
        pose_difference += abs(
          observed_pose[component] - predicted_pose[component]
        ) * 0.25f;
      }
      const float association_precision = max(
        0.5f,
        development->sensor_precision_multiplier
          * (1.0f - 0.75f * slot.uncertainty)
      );
      const float association_likelihood = had_identity
        ? exp(-association_precision * pose_difference)
        : 1.0f;
      const float observed_presence = candidate_presence
        * association_likelihood;

      if (!had_identity && observed_presence > 0.05f) {
        slot.identifier = nb_latent_slot_identifier(
          0x1000000000000000ul,
          observed_pose[0],
          observed_pose[1],
          gid
        );
        for (uint component = 0u; component < 4u; ++component) {
          slot.pose[component] = observed_pose[component];
          slot.velocity[component] = 0.0f;
          predicted_pose[component] = observed_pose[component];
        }
        pose_difference = 0.0f;
      }
      for (uint component = 0u; component < 4u; ++component) {
        const float difference = observed_pose[component]
          - predicted_pose[component];
        slot.velocity[component] = mix(
          retention * slot.velocity[component],
          difference / elapsed_seconds,
          correction_gain * observed_presence
        );
        slot.pose[component] = mix(
          predicted_pose[component],
          observed_pose[component],
          correction_gain * observed_presence
        );
      }
      slot.existence_probability = max(
        observed_presence,
        retention * slot.existence_probability
      );
      slot.visibility = visual_presence * association_likelihood;
      slot.identity_confidence = nb_saturate(mix(
        retention * slot.identity_confidence,
        association_likelihood,
        correction_gain * observed_presence
      ));
      slot.uncertainty = nb_saturate(mix(
        min(1.0f, slot.uncertainty + (1.0f - retention)),
        1.0f - slot.identity_confidence,
        correction_gain * observed_presence
      ));
      if (observed_presence > 0.05f) {
        slot.last_seen_timestamp_microseconds =
          uniforms.target_timestamp_microseconds;
      }
      slot.flags = slot.existence_probability > 0.01f ? 1u : 0u;
      if (observed_presence > 0.05f) slot.flags |= 2u;
      if (slot.existence_probability > observed_presence + 0.05f) slot.flags |= 4u;
      if (olfactory_energy > 0.05f) slot.flags |= 8u;
      if (gustatory_energy > 0.05f) slot.flags |= 16u;
      for (uint affordance = 0u; affordance < 8u; ++affordance) {
        const float visual_feature = nb_observation_feature(
          observations,
          validity,
          uniforms.vision_observation_offset,
          uniforms.vision_observation_count,
          seed * 37u + affordance * 19u
        );
        const float olfactory_feature = nb_observation_feature(
          observations,
          validity,
          uniforms.olfaction_observation_offset,
          uniforms.olfaction_observation_count,
          seed * 43u + affordance * 23u
        );
        const float gustatory_feature = nb_observation_feature(
          observations,
          validity,
          uniforms.gustation_observation_offset,
          uniforms.gustation_observation_count,
          seed * 47u + affordance * 29u
        );
        slot.affordances[affordance] = mix(
          retention * slot.affordances[affordance],
          tanh(visual_feature + 0.5f * olfactory_feature
            + 0.75f * gustatory_feature + recurrent[
            (gid * 8u + affordance) % uniforms.recurrent_scalar_count
          ] * belief_parameters[1]),
          correction_gain * observed_presence
        );
      }
      // The last seven object-latent channels belong to the causal tool/body
      // extension posterior. Generic visual appearance must not overwrite it.
      for (uint component = 0u; component < 95u; ++component) {
        const float sensed = nb_observation_feature(
          observations,
          validity,
          uniforms.vision_observation_offset,
          uniforms.vision_observation_count,
          seed * 53u + component * 7u
        );
        const float olfactory = nb_observation_feature(
          observations,
          validity,
          uniforms.olfaction_observation_offset,
          uniforms.olfaction_observation_count,
          seed * 59u + component * 11u
        );
        const float gustatory = nb_observation_feature(
          observations,
          validity,
          uniforms.gustation_observation_offset,
          uniforms.gustation_observation_count,
          seed * 61u + component * 13u
        );
        slot.latent[component] = mix(
          retention * slot.latent[component],
          tanh(sensed + 0.5f * olfactory + 0.75f * gustatory
            + belief_parameters[5] * recurrent[
            (gid * 103u + component) % uniforms.recurrent_scalar_count
          ]),
          correction_gain * observed_presence
        );
      }
      // A nearby visible object is not part of the body schema. Tool
      // incorporation requires accepted self-contact, body ownership, low
      // external disturbance, and movement coherent with an owned body part.
      // This path reads only committed receptor-derived belief state.
      float contact_agency = 0.0f;
      float3 contacted_body_velocity = float3(0.0f);
      for (uint body_index = 0u;
          body_index < uniforms.body_belief_count; ++body_index) {
        device const float *body = reinterpret_cast<device const float *>(
          hot_state + uniforms.body_belief_offset + ulong(body_index) * 256ul
        );
        device const ulong *body_identity =
          reinterpret_cast<device const ulong *>(
            body + NB_BODY_IDENTITY_FLOAT_OFFSET
          );
        if ((body_identity[3] & 1ul) == 0ul) continue;
        const float candidate_agency = clamp(
          body[NB_BODY_CONTACT] * body[NB_BODY_OWNERSHIP]
            * (1.0f - body[NB_BODY_EXTERNAL_DISTURBANCE]),
          0.0f,
          1.0f
        );
        if (candidate_agency > contact_agency) {
          contact_agency = candidate_agency;
          contacted_body_velocity = float3(
            body[NB_BODY_LINEAR_VELOCITY],
            body[NB_BODY_LINEAR_VELOCITY + 1u],
            body[NB_BODY_LINEAR_VELOCITY + 2u]
          );
        }
      }
      const float3 object_velocity = float3(
        slot.velocity[0], slot.velocity[1], slot.velocity[2]
      );
      const float object_speed = length(object_velocity);
      const float body_speed = length(contacted_body_velocity);
      const float movement_evidence = clamp(
        min(object_speed, body_speed), 0.0f, 1.0f
      );
      const float movement_coherence = object_speed > 1.0e-4f
          && body_speed > 1.0e-4f
        ? clamp(dot(
            object_velocity / object_speed,
            contacted_body_velocity / body_speed
          ), 0.0f, 1.0f)
        : 0.0f;
      const float3 tool_vector = float3(
        slot.pose[0], slot.pose[1], slot.pose[2]
      );
      const float tool_extension = length(tool_vector);
      const float proximity_evidence = exp(-0.5f * tool_extension);
      const float attachment_evidence = clamp(
        observed_presence * contact_agency * movement_evidence
          * movement_coherence * proximity_evidence,
        0.0f,
        1.0f
      );
      const float prior_attachment = clamp(slot.latent[95], 0.0f, 1.0f);
      float attachment = retention * prior_attachment;
      if (contact_agency > 0.05f && movement_evidence > 0.01f) {
        attachment = mix(
          attachment,
          attachment_evidence,
          correction_gain * observed_presence
        );
      } else if (contact_agency <= 0.01f) {
        attachment *= retention;
      }
      attachment = clamp(attachment, 0.0f, 1.0f);
      float coherence_trace = retention
        * clamp(slot.latent[96], 0.0f, 1.0f);
      if (movement_evidence > 0.01f) {
        coherence_trace = mix(
          coherence_trace,
          movement_coherence,
          correction_gain * observed_presence
        );
      }
      const float3 tool_direction = tool_extension > 1.0e-4f
        ? tool_vector / tool_extension : float3(0.0f);
      slot.latent[95] = attachment;
      slot.latent[96] = clamp(coherence_trace, 0.0f, 1.0f);
      slot.latent[97] = contact_agency;
      slot.latent[98] = tool_extension;
      slot.latent[99] = tool_direction.x;
      slot.latent[100] = tool_direction.y;
      slot.latent[101] = tool_direction.z;
      if (attachment > max(belief_parameters[4], 0.05f)) {
        slot.flags |= 1u << 5u;
      }
      if (slot.existence_probability <= 0.01f) {
        NBObjectSlotRecord inactive = {};
        inactive.format_version = 1u;
        inactive.uncertainty = 1.0f;
        slot = inactive;
      }
      object_slots[gid] = slot;
    }
  }

  if (gid < uniforms.other_agent_slot_count) {
    device NBOtherAgentSlotRecord *agent_slots =
      reinterpret_cast<device NBOtherAgentSlotRecord *>(
        hot_state + uniforms.other_agent_slot_offset
      );
    if (development->stage < 9u
        || (uniforms.vision_observation_count == 0u
          && uniforms.audition_observation_count == 0u
          && uniforms.olfaction_observation_count == 0u)) {
      NBOtherAgentSlotRecord inactive = {};
      agent_slots[gid] = inactive;
    } else {
      NBOtherAgentSlotRecord slot = agent_slots[gid];
      const uint seed = gid * 41u + 5u;
      const float visual_energy = nb_observation_energy(
        observations,
        validity,
        uniforms.vision_observation_offset,
        uniforms.vision_observation_count,
        seed
      );
      const float auditory_energy = nb_observation_energy(
        observations,
        validity,
        uniforms.audition_observation_offset,
        uniforms.audition_observation_count,
        seed + 17u
      );
      const float olfactory_energy = nb_observation_energy(
        observations,
        validity,
        uniforms.olfaction_observation_offset,
        uniforms.olfaction_observation_count,
        seed + 29u
      );
      const float communication = nb_saturate(max(
        sound_onset,
        auditory_energy - max(belief_parameters[4], 0.0f)
      ));
      const float visual_presence = nb_saturate(
        (visual_energy - max(belief_parameters[4], 0.0f))
          * max(4.0f * belief_parameters[3], 0.25f)
          + 0.25f * visual_transient
      );
      const float candidate_presence = nb_saturate(max(
        max(visual_presence, 0.5f * communication),
        olfactory_energy - max(0.5f * belief_parameters[4], 0.0f)
      ));
      float observed_body[8];
      for (uint component = 0u; component < 8u; ++component) {
        const uint body_offset = uniforms.vision_observation_count > 0u
          ? uniforms.vision_observation_offset
          : uniforms.olfaction_observation_offset;
        const uint body_count = uniforms.vision_observation_count > 0u
          ? uniforms.vision_observation_count
          : uniforms.olfaction_observation_count;
        observed_body[component] = nb_observation_feature(
          observations,
          validity,
          body_offset,
          body_count,
          seed * 13u + component * 23u
        );
      }
      if (slot.format_version == 0u) {
        slot.format_version = 1u;
        slot.uncertainty = 1.0f;
      }

      const bool had_identity = slot.identifier != 0ul;
      float body_change = 0.0f;
      float observed_body_velocity[8];
      for (uint component = 0u; component < 8u; ++component) {
        const float body_delta = observed_body[component]
          - slot.body_pose[component];
        observed_body_velocity[component] = had_identity
          ? body_delta / elapsed_seconds : 0.0f;
        body_change += abs(body_delta)
          * 0.125f;
      }
      const float identity_cue = max(visual_presence, olfactory_energy);
      const float association_precision = max(
        0.5f,
        development->sensor_precision_multiplier
          * (1.0f - 0.75f * slot.uncertainty)
      );
      const float association_likelihood = had_identity
        ? mix(
            1.0f,
            exp(-association_precision * body_change),
            identity_cue
          )
        : 1.0f;
      const float observed_presence = candidate_presence
        * association_likelihood;

      if (!had_identity && observed_presence > 0.05f) {
        slot.identifier = nb_latent_slot_identifier(
          0x2000000000000000ul,
          observed_body[0],
          observed_body[1] + communication,
          gid
        );
        for (uint component = 0u; component < 8u; ++component) {
          slot.body_pose[component] = observed_body[component];
        }
        body_change = 0.0f;
      }
      for (uint component = 0u; component < 8u; ++component) {
        slot.body_pose[component] = mix(
          slot.body_pose[component],
          observed_body[component],
          correction_gain * observed_presence
        );
      }
      for (uint component = 0u; component < 4u; ++component) {
        const float gaze_feature = nb_observation_feature(
          observations,
          validity,
          uniforms.vision_observation_offset,
          uniforms.vision_observation_count,
          seed * 29u + component * 43u
        );
        slot.gaze[component] = mix(
          retention * slot.gaze[component],
          gaze_feature,
          correction_gain * observed_presence
        );
      }
      slot.existence_probability = max(
        observed_presence,
        retention * slot.existence_probability
      );
      slot.identity_confidence = nb_saturate(mix(
        retention * slot.identity_confidence,
        association_likelihood,
        correction_gain * observed_presence
      ));
      slot.gaze_confidence = nb_saturate(mix(
        retention * slot.gaze_confidence,
        0.5f * observed_presence + 0.5f * visual_transient,
        correction_gain * visual_presence * association_likelihood
      ));
      slot.goal_confidence = nb_saturate(mix(
        retention * slot.goal_confidence,
        1.0f - nb_saturate(body_change),
        correction_gain * observed_presence
      ));
      slot.predicted_action = mix(
        retention * slot.predicted_action,
        tanh(body_change / elapsed_seconds),
        correction_gain * observed_presence
      );
      slot.social_relation = mix(
        retention * slot.social_relation,
        tanh(communication + slot.gaze_confidence - slot.uncertainty),
        correction_gain * observed_presence
      );
      slot.communication_evidence = mix(
        retention * slot.communication_evidence,
        communication,
        correction_gain * observed_presence
      );
      slot.uncertainty = nb_saturate(mix(
        min(1.0f, slot.uncertainty + (1.0f - retention)),
        1.0f - 0.5f * (slot.identity_confidence + slot.goal_confidence),
        correction_gain * observed_presence
      ));
      if (observed_presence > 0.05f) {
        slot.last_seen_timestamp_microseconds =
          uniforms.target_timestamp_microseconds;
      }
      slot.flags = slot.existence_probability > 0.01f ? 1u : 0u;
      if (observed_presence > 0.05f) slot.flags |= 2u;
      if (slot.existence_probability > observed_presence + 0.05f) slot.flags |= 4u;
      if (communication > 0.05f) slot.flags |= 8u;
      if (olfactory_energy > 0.05f) slot.flags |= 16u;
      // The final eight latent channels are an explicit morphology-neutral
      // observed body-velocity code. Decision code can map this movement into
      // the learner's body frame without copying foreign joint coordinates.
      for (uint component = 0u; component < 94u; ++component) {
        const float visual = nb_observation_feature(
          observations,
          validity,
          uniforms.vision_observation_offset,
          uniforms.vision_observation_count,
          seed * 61u + component * 11u
        );
        const float auditory = nb_observation_feature(
          observations,
          validity,
          uniforms.audition_observation_offset,
          uniforms.audition_observation_count,
          seed * 31u + component * 17u
        );
        const float olfactory = nb_observation_feature(
          observations,
          validity,
          uniforms.olfaction_observation_offset,
          uniforms.olfaction_observation_count,
          seed * 37u + component * 19u
        );
        slot.latent[component] = mix(
          retention * slot.latent[component],
          tanh(visual + communication * auditory + 0.5f * olfactory
            + belief_parameters[5] * recurrent[
              (gid * 107u + component) % uniforms.recurrent_scalar_count
            ]),
          correction_gain * observed_presence
        );
      }
      for (uint component = 0u; component < 8u; ++component) {
        slot.latent[94u + component] = mix(
          retention * slot.latent[94u + component],
          tanh(observed_body_velocity[component]),
          correction_gain * observed_presence
        );
      }
      if (slot.existence_probability <= 0.01f) {
        NBOtherAgentSlotRecord inactive = {};
        inactive.format_version = 1u;
        inactive.uncertainty = 1.0f;
        slot = inactive;
      }
      agent_slots[gid] = slot;
    }
  }
}

/// Materializes the compatible relation factor from the current entity slots.
/// Kind 2 is causal tool attachment, kind 6 is self-to-object reachability,
/// kind 10 is communication with self, and kind 11 is an explicit attention
/// edge used for joint attention.
kernel void advance_entity_relation_graph(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  device const float *belief_parameters [[buffer(2)]],
  device const uint *acceptance_gate [[buffer(4)]],
  uint gid [[thread_position_in_grid]])
{
  if (acceptance_gate[0] != 1u) return;
  if (gid >= uniforms.relation_slot_count) return;
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  device const NBObjectSlotRecord *object_slots =
    reinterpret_cast<device const NBObjectSlotRecord *>(
      hot_state + uniforms.object_slot_offset
    );
  device const NBOtherAgentSlotRecord *agent_slots =
    reinterpret_cast<device const NBOtherAgentSlotRecord *>(
      hot_state + uniforms.other_agent_slot_offset
    );
  device NBRelationSlotRecord *relations =
    reinterpret_cast<device NBRelationSlotRecord *>(
      hot_state + uniforms.relation_slot_offset
    );
  const uint attention_base = uniforms.object_slot_count;
  const uint communication_base = attention_base
    + uniforms.object_slot_count * uniforms.other_agent_slot_count;
  const uint attachment_base = communication_base
    + uniforms.other_agent_slot_count;
  const uint active_relation_count = attachment_base
    + uniforms.object_slot_count;
  if (development->stage < 6u || gid >= active_relation_count) {
    NBRelationSlotRecord inactive = {};
    relations[gid] = inactive;
    return;
  }

  NBRelationSlotRecord relation = {};
  const ulong self_identifier = 0x3000000000000001ul;
  if (gid < uniforms.object_slot_count) {
    const NBObjectSlotRecord object = object_slots[gid];
    if (object.identifier != 0ul && object.existence_probability > 0.0f) {
      relation.subject_identifier = self_identifier;
      relation.object_identifier = object.identifier;
      relation.last_evidence_timestamp_microseconds =
        object.last_seen_timestamp_microseconds;
      relation.relation_kind = 6u;
      relation.flags = 1u;
      relation.probability = nb_saturate(
        object.existence_probability
          * (0.5f + 0.5f * object.affordances[0])
      );
      relation.uncertainty = object.uncertainty;
      for (uint component = 0u; component < 3u; ++component) {
        relation.latent[component] = object.pose[component];
        relation.latent[component + 3u] = object.velocity[component];
      }
    }
  } else if (gid < communication_base && development->stage >= 9u
      && uniforms.object_slot_count > 0u) {
    const uint pair_index = gid - attention_base;
    const uint agent_index = pair_index / uniforms.object_slot_count;
    const uint object_index = pair_index % uniforms.object_slot_count;
    const NBOtherAgentSlotRecord agent = agent_slots[agent_index];
    const NBObjectSlotRecord object = object_slots[object_index];
    if (agent.identifier != 0ul && object.identifier != 0ul
        && agent.existence_probability > 0.0f
        && object.existence_probability > 0.0f) {
      relation.subject_identifier = agent.identifier;
      relation.object_identifier = object.identifier;
      relation.last_evidence_timestamp_microseconds =
        agent.last_seen_timestamp_microseconds
          > object.last_seen_timestamp_microseconds
        ? agent.last_seen_timestamp_microseconds
        : object.last_seen_timestamp_microseconds;
      relation.relation_kind = 11u;
      relation.flags = 1u | 2u;
      const float gaze_alignment = nb_saturate(
        1.0f - 0.25f * (
          abs(agent.gaze[0] - object.pose[0])
            + abs(agent.gaze[1] - object.pose[1])
            + abs(agent.gaze[2] - object.pose[2])
            + abs(agent.gaze[3] - object.pose[3])
        )
      );
      relation.probability = nb_saturate(
        agent.existence_probability * object.existence_probability
          * agent.gaze_confidence * gaze_alignment
      );
      relation.uncertainty = nb_saturate(
        0.5f * (agent.uncertainty + object.uncertainty)
      );
      for (uint component = 0u; component < 3u; ++component) {
        relation.latent[component] = agent.gaze[component];
        relation.latent[component + 3u] = object.pose[component];
      }
    }
  } else if (gid < attachment_base && development->stage >= 9u) {
    const uint agent_index = gid - communication_base;
    const NBOtherAgentSlotRecord agent = agent_slots[agent_index];
    if (agent.identifier != 0ul
        && agent.communication_evidence > max(belief_parameters[4], 0.01f)) {
      relation.subject_identifier = agent.identifier;
      relation.object_identifier = self_identifier;
      relation.last_evidence_timestamp_microseconds =
        agent.last_seen_timestamp_microseconds;
      relation.relation_kind = 10u;
      relation.flags = 1u;
      relation.probability = nb_saturate(
        agent.existence_probability * agent.communication_evidence
      );
      relation.uncertainty = agent.uncertainty;
      relation.latent[0] = agent.communication_evidence;
      relation.latent[1] = agent.social_relation;
      relation.latent[2] = agent.predicted_action;
      relation.latent[3] = agent.goal_confidence;
      relation.latent[4] = agent.identity_confidence;
      relation.latent[5] = agent.gaze_confidence;
    }
  } else if (gid >= attachment_base && gid < active_relation_count) {
    const uint object_index = gid - attachment_base;
    const NBObjectSlotRecord object = object_slots[object_index];
    const float attachment = clamp(object.latent[95], 0.0f, 1.0f);
    if (object.identifier != 0ul && object.existence_probability > 0.0f
        && attachment > max(belief_parameters[4], 0.01f)) {
      relation.subject_identifier = self_identifier;
      relation.object_identifier = object.identifier;
      relation.last_evidence_timestamp_microseconds =
        object.last_seen_timestamp_microseconds;
      relation.relation_kind = 2u;
      relation.flags = 1u | (1u << 2u);
      relation.probability = clamp(
        object.existence_probability * attachment, 0.0f, 1.0f
      );
      relation.uncertainty = clamp(
        max(object.uncertainty, 1.0f - object.latent[96]), 0.0f, 1.0f
      );
      relation.latent[0] = object.latent[98];
      relation.latent[1] = object.latent[99];
      relation.latent[2] = object.latent[100];
      relation.latent[3] = object.latent[101];
      relation.latent[4] = object.latent[96];
      relation.latent[5] = object.latent[97];
    }
  }
  relations[gid] = relation;
}

/// Advances the five canonical coordinate frames from causal receptor
/// evidence. The persistent-map transform integrates its own prior; no exact
/// simulator pose or privileged world transform enters this path.
kernel void advance_spatial_coordinate_transforms(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  device const float *belief_parameters [[buffer(2)]],
  device const uint *acceptance_gate [[buffer(4)]],
  uint gid [[thread_position_in_grid]])
{
  if (acceptance_gate[0] != 1u) return;
  if (gid >= uniforms.spatial_transform_count) return;
  device const NBEventQueueStateHeader *event_header =
    reinterpret_cast<device const NBEventQueueStateHeader *>(
      hot_state + uniforms.event_queue_offset
    );
  if ((event_header->flags & NB_SENSORY_FRAME_REUSED) != 0u) return;
  device NBSpatialTransformRecord *transforms =
    reinterpret_cast<device NBSpatialTransformRecord *>(
      hot_state + uniforms.spatial_transform_offset
    );
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  if (gid >= 5u) {
    NBSpatialTransformRecord inactive = {};
    transforms[gid] = inactive;
    return;
  }
  uint minimum_stage = 0u;
  if (gid == 1u || gid == 4u) minimum_stage = 2u;
  if (gid == 2u) minimum_stage = 4u;
  if (gid == 3u) minimum_stage = 6u;
  if (development->stage < minimum_stage) {
    NBSpatialTransformRecord inactive = {};
    transforms[gid] = inactive;
    return;
  }
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  device const uint *validity = reinterpret_cast<device const uint *>(
    hot_state + uniforms.observation_validity_offset
  );
  NBSpatialTransformRecord transform = transforms[gid];
  if (gid == 0u) {
    transform.source_frame = 1u;
    transform.destination_frame = 2u;
  } else if (gid == 1u) {
    transform.source_frame = 2u;
    transform.destination_frame = 3u;
  } else if (gid == 2u) {
    transform.source_frame = 3u;
    transform.destination_frame = 4u;
  } else if (gid == 3u) {
    transform.source_frame = 4u;
    transform.destination_frame = 5u;
  } else {
    transform.source_frame = 1u;
    transform.destination_frame = 3u;
  }
  const float visual_energy = nb_observation_energy(
    observations,
    validity,
    uniforms.vision_observation_offset,
    uniforms.vision_observation_count,
    gid * 17u + 1u
  );
  const float proprioceptive_energy = nb_observation_energy(
    observations,
    validity,
    uniforms.proprioception_observation_offset,
    uniforms.proprioception_observation_count,
    gid * 19u + 2u
  );
  const float vestibular_energy = nb_observation_energy(
    observations,
    validity,
    uniforms.vestibular_observation_offset,
    uniforms.vestibular_observation_count,
    gid * 23u + 3u
  );
  float translation_evidence = 0.0f;
  if (gid == 0u || gid == 3u) translation_evidence = visual_energy;
  else if (gid == 1u) translation_evidence = proprioceptive_energy;
  else if (gid == 2u) {
    translation_evidence = max(proprioceptive_energy, vestibular_energy);
  } else {
    translation_evidence = max(visual_energy, proprioceptive_energy);
  }
  const float evidence = nb_saturate(max(
    translation_evidence, vestibular_energy
  ));
  const float elapsed_seconds = max(
    float(uniforms.delta_microseconds) * 1.0e-6f, 1.0e-6f
  );
  const float correction_gain = clamp(
    belief_parameters[0] * development->sensor_precision_multiplier,
    0.001f,
    1.0f
  );
  const float retention = nb_time_scaled_retention(
    belief_parameters[7], elapsed_seconds
  );
  if ((transform.flags & 1u) == 0u) {
    transform.translation[3] = 1.0f;
    transform.rotation[0] = 0.0f;
    transform.rotation[1] = 0.0f;
    transform.rotation[2] = 0.0f;
    transform.rotation[3] = 1.0f;
    transform.confidence = 0.0f;
    transform.uncertainty = 1.0f;
  }
  float previous_translation[4];
  float predicted_translation[4];
  for (uint component = 0u; component < 4u; ++component) {
    previous_translation[component] = transform.translation[component];
    transform.linear_velocity[component] *= retention;
    predicted_translation[component] = transform.translation[component]
      + transform.linear_velocity[component] * elapsed_seconds;
  }
  float observed_translation[4] = {};
  for (uint component = 0u; component < 3u; ++component) {
    const float visual = nb_observation_feature(
      observations,
      validity,
      uniforms.vision_observation_offset,
      uniforms.vision_observation_count,
      gid * 47u + component * 13u
    );
    const float proprioception = nb_observation_feature(
      observations,
      validity,
      uniforms.proprioception_observation_offset,
      uniforms.proprioception_observation_count,
      gid * 43u + component * 17u
    );
    const float vestibular = nb_observation_feature(
      observations,
      validity,
      uniforms.vestibular_observation_offset,
      uniforms.vestibular_observation_count,
      gid * 37u + component * 19u
    );
    if (gid == 0u) observed_translation[component] = visual;
    else if (gid == 1u) observed_translation[component] = proprioception;
    else if (gid == 2u) {
      observed_translation[component] = proprioception + vestibular;
    } else if (gid == 3u) {
      observed_translation[component] = predicted_translation[component]
        + belief_parameters[6] * visual;
    } else {
      observed_translation[component] = visual + proprioception;
    }
  }
  observed_translation[3] = 1.0f;
  float translation_mismatch = 0.0f;
  for (uint component = 0u; component < 4u; ++component) {
    const float difference = observed_translation[component]
      - predicted_translation[component];
    translation_mismatch += abs(difference) * 0.25f;
    transform.linear_velocity[component] = mix(
      transform.linear_velocity[component],
      (observed_translation[component] - previous_translation[component])
        / elapsed_seconds,
      correction_gain * translation_evidence
    );
    transform.translation[component] = mix(
      predicted_translation[component],
      observed_translation[component],
      correction_gain * translation_evidence
    );
  }
  float observed_rotation[4];
  float rotation_norm = 0.0f;
  for (uint component = 0u; component < 4u; ++component) {
    observed_rotation[component] = nb_observation_feature(
      observations,
      validity,
      uniforms.vestibular_observation_offset,
      uniforms.vestibular_observation_count,
      gid * 31u + component * 11u
    );
    rotation_norm += observed_rotation[component] * observed_rotation[component];
  }
  if (rotation_norm <= 1.0e-8f) {
    observed_rotation[0] = 0.0f;
    observed_rotation[1] = 0.0f;
    observed_rotation[2] = 0.0f;
    observed_rotation[3] = 1.0f;
  } else {
    const float inverse_norm = rsqrt(rotation_norm);
    for (uint component = 0u; component < 4u; ++component) {
      observed_rotation[component] *= inverse_norm;
    }
  }
  float predicted_rotation[4];
  float predicted_rotation_norm = 0.0f;
  for (uint component = 0u; component < 4u; ++component) {
    transform.angular_velocity[component] *= retention;
    predicted_rotation[component] = transform.rotation[component]
      + transform.angular_velocity[component] * elapsed_seconds;
    predicted_rotation_norm += predicted_rotation[component]
      * predicted_rotation[component];
  }
  const float inverse_predicted_rotation_norm = rsqrt(max(
    predicted_rotation_norm, 1.0e-8f
  ));
  for (uint component = 0u; component < 4u; ++component) {
    predicted_rotation[component] *= inverse_predicted_rotation_norm;
  }
  float rotation_mismatch = 0.0f;
  for (uint component = 0u; component < 4u; ++component) {
    const float difference = observed_rotation[component]
      - predicted_rotation[component];
    rotation_mismatch += abs(difference) * 0.25f;
    transform.angular_velocity[component] = mix(
      transform.angular_velocity[component],
      difference / elapsed_seconds,
      correction_gain * vestibular_energy
    );
    transform.rotation[component] = mix(
      predicted_rotation[component],
      observed_rotation[component],
      correction_gain * vestibular_energy
    );
  }
  const float updated_rotation_norm = sqrt(max(
    transform.rotation[0] * transform.rotation[0]
      + transform.rotation[1] * transform.rotation[1]
      + transform.rotation[2] * transform.rotation[2]
      + transform.rotation[3] * transform.rotation[3],
    1.0e-8f
  ));
  for (uint component = 0u; component < 4u; ++component) {
    transform.rotation[component] /= updated_rotation_norm;
  }
  const float evidence_sum = translation_evidence + vestibular_energy;
  const float fused_mismatch = evidence_sum > 1.0e-6f
    ? (translation_evidence * translation_mismatch
        + vestibular_energy * rotation_mismatch) / evidence_sum
    : 0.0f;
  transform.confidence = nb_saturate(mix(
    transform.confidence * retention,
    1.0f - nb_saturate(fused_mismatch),
    correction_gain * evidence
  ));
  transform.uncertainty = nb_saturate(
    1.0f - transform.confidence
      + belief_parameters[4] * (1.0f - evidence) * elapsed_seconds
  );
  transform.flags = 1u;
  if (gid == 3u) transform.flags |= 2u | 4u;
  if (evidence > 0.05f) {
    transform.last_evidence_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
  } else {
    transform.flags |= 8u;
  }
  transforms[gid] = transform;
}

kernel void advance_fast_plasticity_foundation(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  device const float *plasticity_parameters [[buffer(2)]],
  device const NBPlasticityRegionRangeRecord *region_ranges [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.fast_plasticity_count
      || uniforms.recurrent_scalar_count == 0u
      || uniforms.module_count == 0u) {
    return;
  }
  device const float *recurrent = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  device const NBNeuromodulatorStateRecord *neuromodulators =
    reinterpret_cast<device const NBNeuromodulatorStateRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  device NBFastPlasticityStateRecord *sites =
    reinterpret_cast<device NBFastPlasticityStateRecord *>(
      hot_state + uniforms.fast_plasticity_offset
    );
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  device const NBRegionalMaturationRecord *maturation =
    reinterpret_cast<device const NBRegionalMaturationRecord *>(
      hot_state + uniforms.regional_maturation_offset
    );
  NBFastPlasticityStateRecord site = sites[gid];
  if (site.region_identifier == 0u) {
    site.region_identifier = ushort(
      maturation[gid % uniforms.module_count].module_identifier
    );
    site.basis_identifier = ushort(gid / uniforms.module_count);
    site.coefficient_retention = clamp(plasticity_parameters[1], 0.0f, 1.0f);
    site.eligibility_retention = clamp(plasticity_parameters[2], 0.0f, 1.0f);
    site.learning_rate = max(plasticity_parameters[0], 0.0f);
    site.maximum_magnitude = max(plasticity_parameters[7], 1.0e-4f);
  }
  site.flags |= 1u;
  uint region_index = gid % uniforms.module_count;
  for (uint index = 0u; index < uniforms.module_count; ++index) {
    if (maturation[index].module_identifier == uint(site.region_identifier)) {
      region_index = index;
      break;
    }
  }
  const NBPlasticityRegionRangeRecord region = region_ranges[region_index];
  constexpr uint hyperparameter_count = 8u;
  constexpr uint basis_operator_channel_count = 5u;
  constexpr uint basis_maximum_feature_count = 256u;
  constexpr uint basis_stride = 517u;
  constexpr uint receptor_effect_count = 14u;
  const uint receptor_scalar_count = uniforms.module_count
    * uniforms.neuromodulator_count * receptor_effect_count;
  const uint basis_scalar_count = uniforms.plasticity_parameter_count
      > hyperparameter_count + receptor_scalar_count
    ? uniforms.plasticity_parameter_count - hyperparameter_count
        - receptor_scalar_count
    : 0u;
  const uint basis_capacity = uniforms.module_count > 0u
    ? basis_scalar_count / (uniforms.module_count * basis_stride)
    : 0u;
  const uint token_count = uint(region.token_count);
  const uint token_dimension = uint(region.token_dimension);
  const bool valid_region = region.module_identifier
        == uint(site.region_identifier)
    && token_count > 0u
    && token_dimension > 0u
    && token_dimension <= basis_maximum_feature_count
    && region.scalar_count == token_count * token_dimension
    && region.scalar_offset < uniforms.recurrent_scalar_count
    && region.scalar_count
      <= uniforms.recurrent_scalar_count - region.scalar_offset
    && basis_capacity > 0u
    && region.reserved == 0u
    && (region.flags & 1u) != 0u;
  float activity_product = 0.0f;
  if (valid_region) {
    const uint basis_identifier = uint(site.basis_identifier) % basis_capacity;
    const uint basis_offset = hyperparameter_count
      + (region_index * basis_capacity + basis_identifier) * basis_stride;
    const uint left_offset = basis_offset + basis_operator_channel_count;
    const uint right_offset = left_offset + basis_maximum_feature_count;
    const float inverse_dimension_scale = rsqrt(float(token_dimension));
    // Rotate deterministically across a region's tokens in physical time. One
    // complete rank-one projection per site keeps the update basis-aligned
    // without multiplying work by every token in large regional populations.
    const uint token = (
      basis_identifier
        + uint((uniforms.target_timestamp_microseconds / 20000ul)
          % ulong(token_count))
    ) % token_count;
    const uint token_offset = region.scalar_offset + token * token_dimension;
    float left_projection = 0.0f;
    float right_projection = 0.0f;
    for (uint feature = 0u; feature < token_dimension; ++feature) {
      const float activity = recurrent[token_offset + feature];
      left_projection += plasticity_parameters[left_offset + feature]
        * activity;
      right_projection += plasticity_parameters[right_offset + feature]
        * activity;
    }
    activity_product = left_projection * right_projection
      * inverse_dimension_scale * inverse_dimension_scale;
  }
  const float interval_scale = nb_plasticity_interval_scale(
    uniforms.delta_microseconds
  );
  device const NBRegionalPlasticModulationRecord *prior_regional_modulation =
    reinterpret_cast<device const NBRegionalPlasticModulationRecord *>(
      hot_state + uniforms.regional_plastic_modulation_offset
    );
  const NBRegionalPlasticModulationRecord prior_modulation =
    prior_regional_modulation[region_index];
  const bool valid_prior_modulation = prior_modulation.module_identifier
        == uint(site.region_identifier)
    && (prior_modulation.flags & 1u) != 0u;
  const float decay_interval_scale = interval_scale * max(
    valid_prior_modulation
      ? prior_modulation.plasticity_decay_multiplier : 1.0f,
    0.05f
  );
  const float eligibility_retention = nb_plasticity_interval_retention(min(
    site.eligibility_retention,
    clamp(plasticity_parameters[2], 0.0f, 1.0f)
  ), decay_interval_scale);
  site.eligibility = eligibility_retention * site.eligibility
    + interval_scale * plasticity_parameters[3] * activity_product;
  const float local_modulation = nb_regional_neuromodulator_effect(
    plasticity_parameters,
    uniforms,
    neuromodulators,
    region_index,
    0u
  );
  const float coefficient_retention = nb_plasticity_interval_retention(min(
    site.coefficient_retention,
    clamp(plasticity_parameters[1], 0.0f, 1.0f)
  ), decay_interval_scale);
  site.coefficient = clamp(
    coefficient_retention * site.coefficient
      + interval_scale
        * min(site.learning_rate, max(plasticity_parameters[0], 0.0f))
        * development->learning_rate_multiplier
        * local_modulation * site.eligibility,
    -min(site.maximum_magnitude, max(plasticity_parameters[7], 1.0e-4f)),
    min(site.maximum_magnitude, max(plasticity_parameters[7], 1.0e-4f))
  );
  sites[gid] = site;
}

kernel void reduce_fast_plasticity_by_region(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  device const float *plasticity_parameters [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.module_count || uniforms.fast_plasticity_count == 0u) return;
  device const NBRegionalMaturationRecord *maturation =
    reinterpret_cast<device const NBRegionalMaturationRecord *>(
      hot_state + uniforms.regional_maturation_offset
    );
  device const NBFastPlasticityStateRecord *sites =
    reinterpret_cast<device const NBFastPlasticityStateRecord *>(
      hot_state + uniforms.fast_plasticity_offset
    );
  device NBRegionalPlasticModulationRecord *regional =
    reinterpret_cast<device NBRegionalPlasticModulationRecord *>(
      hot_state + uniforms.regional_plastic_modulation_offset
    );
  const uint module_identifier = maturation[gid].module_identifier;
  constexpr uint hyperparameter_count = 8u;
  constexpr uint basis_operator_channel_count = 5u;
  constexpr uint basis_stride = 517u;
  constexpr uint receptor_effect_count = 14u;
  const uint receptor_scalar_count = uniforms.module_count
    * uniforms.neuromodulator_count * receptor_effect_count;
  const uint basis_scalar_count = uniforms.plasticity_parameter_count
      > hyperparameter_count + receptor_scalar_count
    ? uniforms.plasticity_parameter_count - hyperparameter_count
        - receptor_scalar_count
    : 0u;
  const uint basis_capacity = basis_scalar_count
    / (uniforms.module_count * basis_stride);
  float projection[basis_operator_channel_count] = {};
  uint coefficient_count = 0u;
  for (uint index = 0u; index < uniforms.fast_plasticity_count; ++index) {
    const NBFastPlasticityStateRecord site = sites[index];
    if (uint(site.region_identifier) != module_identifier) continue;
    if (basis_capacity == 0u) continue;
    const uint basis_identifier = uint(site.basis_identifier) % basis_capacity;
    const uint basis_offset = hyperparameter_count
      + (gid * basis_capacity + basis_identifier) * basis_stride;
    for (uint channel = 0u;
        channel < basis_operator_channel_count; ++channel) {
      projection[channel] += site.coefficient
        * plasticity_parameters[basis_offset + channel];
    }
    coefficient_count += 1u;
  }
  device const NBNeuromodulatorStateRecord *neuromodulators =
    reinterpret_cast<device const NBNeuromodulatorStateRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  for (uint channel = 0u;
      channel < basis_operator_channel_count; ++channel) {
    projection[channel] += nb_regional_neuromodulator_effect(
      plasticity_parameters,
      uniforms,
      neuromodulators,
      gid,
      channel + 1u
    );
  }
  NBRegionalPlasticModulationRecord record;
  record.module_identifier = module_identifier;
  record.coefficient_count = coefficient_count;
  record.recurrent_delta = clamp(projection[0], -0.20f, 0.20f);
  record.local_delta = clamp(projection[1], -0.15f, 0.15f);
  record.route_delta = clamp(projection[2], -0.20f, 0.20f);
  record.drive_delta = clamp(projection[3], -0.10f, 0.10f);
  record.gate_delta = clamp(projection[4], -0.10f, 0.10f);
  record.update_gain_multiplier = exp(clamp(
    nb_regional_neuromodulator_effect(
      plasticity_parameters, uniforms, neuromodulators, gid, 6u
    ),
    -1.0f,
    1.0f
  ));
  record.timescale_multiplier = exp(clamp(
    nb_regional_neuromodulator_effect(
      plasticity_parameters, uniforms, neuromodulators, gid, 7u
    ),
    -1.0f,
    1.0f
  ));
  record.route_threshold_delta = clamp(
    nb_regional_neuromodulator_effect(
      plasticity_parameters, uniforms, neuromodulators, gid, 8u
    ),
    -0.50f,
    0.50f
  );
  record.inhibition_delta = clamp(
    nb_regional_neuromodulator_effect(
      plasticity_parameters, uniforms, neuromodulators, gid, 9u
    ),
    -0.50f,
    0.50f
  );
  record.plasticity_decay_multiplier = exp(clamp(
    nb_regional_neuromodulator_effect(
      plasticity_parameters, uniforms, neuromodulators, gid, 10u
    ),
    -1.0f,
    1.0f
  ));
  record.memory_write_multiplier = exp(clamp(
    nb_regional_neuromodulator_effect(
      plasticity_parameters, uniforms, neuromodulators, gid, 11u
    ),
    -1.0f,
    1.0f
  ));
  record.vigor_multiplier = exp(clamp(
    nb_regional_neuromodulator_effect(
      plasticity_parameters, uniforms, neuromodulators, gid, 12u
    ),
    -1.0f,
    1.0f
  ));
  record.exploration_temperature_multiplier = exp(clamp(
    nb_regional_neuromodulator_effect(
      plasticity_parameters, uniforms, neuromodulators, gid, 13u
    ),
    -1.0f,
    1.0f
  ));
  record.flags = coefficient_count > 0u ? 1u : 0u;
  regional[gid] = record;
}

/// Converts the prior committed routing request into a bounded per-region
/// gain overlay consumed by the fast regional tissue runtime. The immutable
/// species route graph remains authoritative; this action only allocates
/// bandwidth within that graph.
kernel void apply_internal_route_allocation(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.module_count == 0u) return;
  device const NBInternalActionRecord *internal_actions =
    reinterpret_cast<device const NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  const NBInternalActionRecord request = internal_actions[3];
  if (request.kind != 4u || (request.flags & 1u) == 0u
      || request.target_identifier == 0ul) return;
  device const NBRegionalMaturationRecord *maturation =
    reinterpret_cast<device const NBRegionalMaturationRecord *>(
      hot_state + uniforms.regional_maturation_offset
    );
  device NBRegionalPlasticModulationRecord *regional =
    reinterpret_cast<device NBRegionalPlasticModulationRecord *>(
      hot_state + uniforms.regional_plastic_modulation_offset
    );
  for (uint index = 0u; index < uniforms.module_count; ++index) {
    if (ulong(maturation[index].module_identifier) != request.target_identifier
        || maturation[index].unlocked == 0u) continue;
    NBRegionalPlasticModulationRecord record = regional[index];
    record.route_delta = clamp(
      record.route_delta + 0.5f * request.priority * request.confidence,
      0.0f,
      1.0f
    );
    record.coefficient_count = max(record.coefficient_count, 1u);
    record.flags |= 1u | (1u << 1u);
    regional[index] = record;
    return;
  }
}

/// Applies the prior committed clear request before this tick publishes new
/// workspace state. One lane owns both metadata and content so matching and
/// clearing are deterministic and race-free.
kernel void clear_requested_workspace_token(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.workspace_capacity <= 2u) return;
  device const NBInternalActionRecord *internal_actions =
    reinterpret_cast<device const NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  const NBInternalActionRecord request = internal_actions[2];
  if (request.kind != 3u || (request.flags & 1u) == 0u
      || request.target_identifier == 0ul) return;
  device float *content = reinterpret_cast<device float *>(
    hot_state + uniforms.workspace_content_offset
  );
  device NBWorkspaceMetadataRecord *metadata =
    reinterpret_cast<device NBWorkspaceMetadataRecord *>(
      hot_state + uniforms.workspace_metadata_offset
    );
  for (uint slot = 2u; slot < uniforms.workspace_capacity; ++slot) {
    if (metadata[slot].identifier != request.target_identifier) continue;
    const uint base = slot * uniforms.workspace_dimension;
    for (uint feature = 0u; feature < uniforms.workspace_dimension; ++feature) {
      content[base + feature] = 0.0f;
    }
    metadata[slot] = {};
    return;
  }
}

inline void nb_clear_workspace_slot(
  device float *content,
  device NBWorkspaceMetadataRecord *metadata,
  const uint slot,
  const uint dimension)
{
  const uint base = slot * dimension;
  for (uint feature = 0u; feature < dimension; ++feature) {
    content[base + feature] = 0.0f;
  }
  metadata[slot] = {};
}

inline float nb_workspace_retention(
  device const float *memory_parameters,
  const float persistence_priority,
  const float elapsed_seconds)
{
  const float base_retention = clamp(memory_parameters[7], 0.0f, 1.0f);
  const float persistence_coupling = clamp(
    memory_parameters[12], 0.0f, 1.0f
  );
  const float retained_per_second = mix(
    base_retention,
    1.0f,
    clamp(persistence_priority, 0.0f, 1.0f) * persistence_coupling
  );
  return nb_time_scaled_retention(retained_per_second, elapsed_seconds);
}

inline bool nb_workspace_identity_matches(
  const NBWorkspaceMetadataRecord token,
  const uint kind,
  const uint source_module,
  const ulong entity_identifier)
{
  return token.identifier != 0ul
    && (token.kind_and_source & 0xffffu) == kind
    && (token.kind_and_source >> 16u) == source_module
    && token.entity_identifier == entity_identifier;
}

inline float nb_workspace_elapsed_seconds(
  const NBWorkspaceMetadataRecord token,
  const ulong target_timestamp_microseconds,
  const float fallback_elapsed_seconds)
{
  const ulong last_update = token.last_score_update_timestamp_microseconds != 0ul
    ? token.last_score_update_timestamp_microseconds
    : token.last_refresh_timestamp_microseconds;
  return last_update != 0ul && target_timestamp_microseconds >= last_update
    ? float(target_timestamp_microseconds - last_update) * 1.0e-6f
    : max(fallback_elapsed_seconds, 0.0f);
}

inline bool nb_decay_workspace_slot(
  device float *content,
  device NBWorkspaceMetadataRecord *metadata,
  const uint slot,
  const uint dimension,
  const float retained_per_second,
  const ulong target_timestamp_microseconds,
  const float fallback_elapsed_seconds,
  const float minimum_score)
{
  NBWorkspaceMetadataRecord token = metadata[slot];
  if (token.identifier == 0ul || (token.flags & 1u) == 0u) return false;
  const float elapsed_seconds = nb_workspace_elapsed_seconds(
    token, target_timestamp_microseconds, fallback_elapsed_seconds
  );
  const float persistence = clamp(token.persistence_priority, 0.0f, 1.0f);
  const float effective_retention = mix(
    clamp(retained_per_second, 0.0f, 1.0f),
    1.0f,
    0.75f * persistence
  );
  const float retention = nb_time_scaled_retention(
    effective_retention, elapsed_seconds
  );
  token.confidence = clamp(token.confidence, 0.0f, 1.0f) * retention;
  token.selection_score = clamp(token.selection_score, 0.0f, 1.0f)
    * retention;
  token.last_score_update_timestamp_microseconds =
    target_timestamp_microseconds;
  if (token.selection_score < minimum_score) {
    nb_clear_workspace_slot(content, metadata, slot, dimension);
    return false;
  }
  metadata[slot] = token;
  return true;
}

/// Selects and merges the foundational drive and embodied-self broadcasts.
/// One lane owns the complete operation so identity refresh, persistence, and
/// replacement are deterministic. Slots 2+ remain owned by accepted error,
/// memory, decision, and social publishers.
kernel void select_and_merge_foundation_workspace(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  device const float *memory_parameters [[buffer(2)]],
  device const NBPlasticityRegionRangeRecord *region_ranges [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.workspace_capacity == 0u
      || uniforms.workspace_dimension == 0u
      || uniforms.recurrent_scalar_count == 0u) return;
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  const uint active_workspace_capacity = min(
    uniforms.workspace_capacity, development->workspace_capacity
  );
  device float *content = reinterpret_cast<device float *>(
    hot_state + uniforms.workspace_content_offset
  );
  device NBWorkspaceMetadataRecord *metadata =
    reinterpret_cast<device NBWorkspaceMetadataRecord *>(
      hot_state + uniforms.workspace_metadata_offset
    );
  device const float *recurrent = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  device const NBDriveStateRecord *drives =
    reinterpret_cast<device const NBDriveStateRecord *>(hot_state + uniforms.drive_offset);
  device const NBRegionalMaturationRecord *maturation =
    reinterpret_cast<device const NBRegionalMaturationRecord *>(
      hot_state + uniforms.regional_maturation_offset
    );
  device const NBRegionalPlasticModulationRecord *regional_modulation =
    reinterpret_cast<device const NBRegionalPlasticModulationRecord *>(
      hot_state + uniforms.regional_plastic_modulation_offset
    );

  for (uint slot = active_workspace_capacity;
      slot < uniforms.workspace_capacity; ++slot) {
    nb_clear_workspace_slot(
      content, metadata, slot, uniforms.workspace_dimension
    );
  }

  const ulong previous_timestamp = uniforms.target_timestamp_microseconds
      > uniforms.delta_microseconds
    ? uniforms.target_timestamp_microseconds - uniforms.delta_microseconds
    : 0ul;
  constexpr ulong workspace_period_microseconds = 50000ul;
  const bool workspace_due = previous_timestamp
      / workspace_period_microseconds
    != uniforms.target_timestamp_microseconds
      / workspace_period_microseconds;
  if (!workspace_due || active_workspace_capacity == 0u) return;

  const ulong elapsed_workspace_periods =
    uniforms.target_timestamp_microseconds / workspace_period_microseconds
      - previous_timestamp / workspace_period_microseconds;
  const float elapsed_seconds = float(elapsed_workspace_periods)
    * float(workspace_period_microseconds) * 1.0e-6f;
  const float minimum_score = max(memory_parameters[16], 0.0f);
  const float replacement_margin = max(memory_parameters[13], 0.0f);
  const float refresh_gain = clamp(memory_parameters[17], 0.0f, 1.0f);

  uint selected_drive = 0xffffffffu;
  float selected_drive_score = 0.0f;
  for (uint index = 0u; index < uniforms.drive_count; ++index) {
    const NBDriveStateRecord candidate = drives[index];
    const float deficit_salience = sqrt(max(candidate.potential, 0.0f));
    const float rate_salience = clamp(
      abs(candidate.estimated_rate) * 0.1f, 0.0f, 1.0f
    );
    const float score = clamp(
      max(memory_parameters[8], 0.0f) * deficit_salience
        + max(memory_parameters[9], 0.0f) * rate_salience,
      0.0f,
      1.0f
    );
    if (score > selected_drive_score
        || (score == selected_drive_score && index < selected_drive)) {
      selected_drive = index;
      selected_drive_score = score;
    }
  }

  if (active_workspace_capacity > 0u) {
    constexpr uint drive_kind = 8u;
    constexpr uint drive_source_module = 70u;
    const float persistence = clamp(memory_parameters[14], 0.0f, 1.0f);
    NBWorkspaceMetadataRecord prior = metadata[0];
    const float prior_persistence = (prior.flags & 1u) != 0u
      ? clamp(prior.persistence_priority, 0.0f, 1.0f)
      : persistence;
    const float prior_elapsed_seconds = nb_workspace_elapsed_seconds(
      prior, uniforms.target_timestamp_microseconds, elapsed_seconds
    );
    const float retained_confidence = clamp(prior.confidence, 0.0f, 1.0f)
      * nb_workspace_retention(
        memory_parameters, prior_persistence, prior_elapsed_seconds
      );
    const float retained_selection_score = clamp(
      (prior.flags & 1u) != 0u ? prior.selection_score : prior.confidence,
      0.0f,
      1.0f
    ) * nb_workspace_retention(
      memory_parameters, prior_persistence, prior_elapsed_seconds
    );
    const ulong drive_identity = selected_drive == 0xffffffffu
      ? 0ul : ulong(drives[selected_drive].kind);
    const bool matches = selected_drive != 0xffffffffu
      && nb_workspace_identity_matches(
        prior, drive_kind, drive_source_module, drive_identity
      );
    const bool replace = selected_drive_score >= minimum_score
      && (prior.identifier == 0ul || matches
        || selected_drive_score > retained_selection_score
          + replacement_margin * (0.25f + 0.75f * prior_persistence));
    if (replace) {
      const uint base = 0u;
      const NBDriveStateRecord selected = drives[selected_drive];
      for (uint feature = 0u; feature < uniforms.workspace_dimension; ++feature) {
        float value = 0.0f;
        if (feature == 0u) value = selected.level;
        else if (feature == 1u) value = selected.viable_minimum;
        else if (feature == 2u) value = selected.viable_maximum;
        else if (feature == 3u) value = selected.deficit;
        else if (feature == 4u) value = selected.potential;
        else if (feature == 5u) value = selected.estimated_rate;
        else if (feature == 6u) value = selected.priority_weight;
        else if (feature == 7u) value = float(selected.kind);
        else if (feature >= 16u
            && feature < 16u + uniforms.drive_count) {
          value = drives[feature - 16u].deficit;
        } else if (feature >= 32u
            && feature < 32u + uniforms.drive_count) {
          value = drives[feature - 32u].potential;
        }
        content[base + feature] = value;
      }
      NBWorkspaceMetadataRecord token = matches ? prior
        : NBWorkspaceMetadataRecord{};
      if (!matches) {
        token.identifier = (uniforms.target_timestamp_microseconds << 8u) | 1ul;
        token.source_timestamp_microseconds =
          uniforms.target_timestamp_microseconds;
      }
      token.last_refresh_timestamp_microseconds =
        uniforms.target_timestamp_microseconds;
      token.entity_identifier = drive_identity;
      token.goal_identifier = 0ul;
      token.bound_token_identifier = 0ul;
      token.provenance_record_identifier = 0ul;
      token.kind_and_source = drive_kind | (drive_source_module << 16u);
      token.confidence = matches
        ? mix(retained_confidence, selected_drive_score, refresh_gain)
        : selected_drive_score;
      token.persistence_priority = persistence;
      token.selection_score = selected_drive_score;
      token.provenance_kind = 0u;
      token.flags = 1u;
      token.provenance_source_generation = 0ul;
      token.last_score_update_timestamp_microseconds =
        uniforms.target_timestamp_microseconds;
      metadata[0] = token;
    } else if (prior.identifier != 0ul) {
      prior.confidence = retained_confidence;
      prior.selection_score = retained_selection_score;
      prior.last_score_update_timestamp_microseconds =
        uniforms.target_timestamp_microseconds;
      if (retained_selection_score < minimum_score) {
        nb_clear_workspace_slot(
          content, metadata, 0u, uniforms.workspace_dimension
        );
      } else {
        metadata[0] = prior;
      }
    }
  }

  if (active_workspace_capacity <= 1u) return;
  uint selected_region = 0xffffffffu;
  uint selected_token = 0xffffffffu;
  float selected_self_score = 0.0f;
  for (uint region = 0u; region < uniforms.module_count; ++region) {
    const NBPlasticityRegionRangeRecord range = region_ranges[region];
    if (range.module_identifier < 27u || range.module_identifier > 36u
        || maturation[region].unlocked == 0u || range.token_count == 0u
        || range.token_dimension == 0u || range.scalar_count == 0u
        || range.scalar_offset + range.scalar_count
          > uniforms.recurrent_scalar_count) continue;
    for (uint token_index = 0u; token_index < uint(range.token_count);
        ++token_index) {
      float energy = 0.0f;
      const uint sample_count = min(uint(range.token_dimension), 32u);
      for (uint sample = 0u; sample < sample_count; ++sample) {
        const uint feature = sample_count == uint(range.token_dimension)
          ? sample
          : (sample * uint(range.token_dimension)) / sample_count;
        const uint scalar = range.scalar_offset
          + token_index * uint(range.token_dimension) + feature;
        if (scalar < range.scalar_offset + range.scalar_count) {
          energy += abs(recurrent[scalar]);
        }
      }
      energy = sample_count > 0u
        ? clamp(energy / float(sample_count), 0.0f, 1.0f) : 0.0f;
      const float regional_salience = clamp(
        regional_modulation[region].memory_write_multiplier - 1.0f,
        0.0f,
        1.0f
      );
      const float score = clamp(
        maturation[region].capacity_fraction * (
          max(memory_parameters[10], 0.0f) * energy
            + max(memory_parameters[11], 0.0f) * regional_salience
        ),
        0.0f,
        1.0f
      );
      if (score > selected_self_score
          || (score == selected_self_score
            && (range.module_identifier
                < (selected_region == 0xffffffffu
                  ? 0xffffffffu
                  : region_ranges[selected_region].module_identifier)
              || (selected_region != 0xffffffffu
                && range.module_identifier
                  == region_ranges[selected_region].module_identifier
                && token_index < selected_token)))) {
        selected_region = region;
        selected_token = token_index;
        selected_self_score = score;
      }
    }
  }

  constexpr uint self_kind = 1u;
  const float self_persistence = clamp(memory_parameters[15], 0.0f, 1.0f);
  NBWorkspaceMetadataRecord prior_self = metadata[1];
  const float prior_self_persistence = (prior_self.flags & 1u) != 0u
    ? clamp(prior_self.persistence_priority, 0.0f, 1.0f)
    : self_persistence;
  const float prior_self_elapsed_seconds = nb_workspace_elapsed_seconds(
    prior_self, uniforms.target_timestamp_microseconds, elapsed_seconds
  );
  const float retained_self_confidence = clamp(
    prior_self.confidence, 0.0f, 1.0f
  ) * nb_workspace_retention(
    memory_parameters, prior_self_persistence, prior_self_elapsed_seconds
  );
  const float retained_self_selection_score = clamp(
    (prior_self.flags & 1u) != 0u
      ? prior_self.selection_score : prior_self.confidence,
    0.0f,
    1.0f
  ) * nb_workspace_retention(
    memory_parameters, prior_self_persistence, prior_self_elapsed_seconds
  );
  const uint self_source_module = selected_region == 0xffffffffu
    ? 0u : region_ranges[selected_region].module_identifier;
  const ulong self_identity = selected_region == 0xffffffffu
    ? 0ul : (ulong(self_source_module) << 32u) | ulong(selected_token + 1u);
  const bool self_matches = selected_region != 0xffffffffu
    && nb_workspace_identity_matches(
      prior_self, self_kind, self_source_module, self_identity
    );
  const bool replace_self = selected_self_score >= minimum_score
    && (prior_self.identifier == 0ul || self_matches
      || selected_self_score > retained_self_selection_score
        + replacement_margin * (0.25f + 0.75f * prior_self_persistence));
  if (replace_self) {
    const NBPlasticityRegionRangeRecord selected_range =
      region_ranges[selected_region];
    const uint token_base = selected_range.scalar_offset
      + selected_token * uint(selected_range.token_dimension);
    const uint workspace_base = uniforms.workspace_dimension;
    for (uint feature = 0u; feature < uniforms.workspace_dimension; ++feature) {
      content[workspace_base + feature] = feature
          < uint(selected_range.token_dimension)
        ? recurrent[token_base + feature]
        : 0.0f;
    }
    NBWorkspaceMetadataRecord token = self_matches ? prior_self
      : NBWorkspaceMetadataRecord{};
    if (!self_matches) {
      token.identifier = (uniforms.target_timestamp_microseconds << 8u) | 2ul;
      token.source_timestamp_microseconds =
        uniforms.target_timestamp_microseconds;
    }
    token.last_refresh_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    token.entity_identifier = self_identity;
    token.goal_identifier = 0ul;
    token.bound_token_identifier = 0ul;
    token.provenance_record_identifier = 0ul;
    token.kind_and_source = self_kind | (self_source_module << 16u);
    token.confidence = self_matches
      ? mix(retained_self_confidence, selected_self_score, refresh_gain)
      : selected_self_score;
    token.persistence_priority = self_persistence;
    token.selection_score = selected_self_score;
    token.provenance_kind = 0u;
    token.flags = 1u;
    token.provenance_source_generation = 0ul;
    token.last_score_update_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    metadata[1] = token;
  } else if (prior_self.identifier != 0ul) {
    prior_self.confidence = retained_self_confidence;
    prior_self.selection_score = retained_self_selection_score;
    prior_self.last_score_update_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    if (retained_self_selection_score < minimum_score) {
      nb_clear_workspace_slot(
        content, metadata, 1u, uniforms.workspace_dimension
      );
    } else {
      metadata[1] = prior_self;
    }
  }
}

/// Publishes the strongest inferred social hypotheses into the global
/// workspace and binds joint attention to the strongest inferred object. A
/// communication token is still a sensory latent association, not a
/// privileged symbolic input.
kernel void broadcast_social_context(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  device const float *belief_parameters [[buffer(2)]],
  device const uint *acceptance_gate [[buffer(4)]],
  uint gid [[thread_position_in_grid]])
{
  if (acceptance_gate[0] != 1u) return;
  if (gid != 0u) return;
  device const NBEventQueueStateHeader *event_header =
    reinterpret_cast<device const NBEventQueueStateHeader *>(
      hot_state + uniforms.event_queue_offset
    );
  const bool frame_reused =
    (event_header->flags & NB_SENSORY_FRAME_REUSED) != 0u;
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  device const NBOtherAgentSlotRecord *agent_slots =
    reinterpret_cast<device const NBOtherAgentSlotRecord *>(
      hot_state + uniforms.other_agent_slot_offset
    );
  device const NBObjectSlotRecord *object_slots =
    reinterpret_cast<device const NBObjectSlotRecord *>(
      hot_state + uniforms.object_slot_offset
    );
  device const NBRelationSlotRecord *relations =
    reinterpret_cast<device const NBRelationSlotRecord *>(
      hot_state + uniforms.relation_slot_offset
    );
  device float *context = reinterpret_cast<device float *>(
    hot_state + uniforms.context_belief_offset
  );
  device float *workspace = reinterpret_cast<device float *>(
    hot_state + uniforms.workspace_content_offset
  );
  device NBWorkspaceMetadataRecord *metadata =
    reinterpret_cast<device NBWorkspaceMetadataRecord *>(
      hot_state + uniforms.workspace_metadata_offset
    );
  device NBDriveStateRecord *drives =
    reinterpret_cast<device NBDriveStateRecord *>(
      hot_state + uniforms.drive_offset
    );
  device NBNeuromodulatorStateRecord *neuromodulators =
    reinterpret_cast<device NBNeuromodulatorStateRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  const uint active_workspace_capacity = min(
    uniforms.workspace_capacity, development->workspace_capacity
  );

  const float social_elapsed_seconds = float(uniforms.delta_microseconds)
    * 1.0e-6f;
  const float social_retention = clamp(belief_parameters[7], 0.0f, 1.0f);
  const float social_minimum_score = max(belief_parameters[6], 0.01f);
  for (uint slot = 11u; slot < uniforms.workspace_capacity; ++slot) {
    if (slot >= active_workspace_capacity) {
      nb_clear_workspace_slot(
        workspace, metadata, slot, uniforms.workspace_dimension
      );
      continue;
    }
    nb_decay_workspace_slot(
      workspace,
      metadata,
      slot,
      uniforms.workspace_dimension,
      social_retention,
      uniforms.target_timestamp_microseconds,
      social_elapsed_seconds,
      social_minimum_score
    );
  }

  uint best_agent_index = 0xffffffffu;
  float best_agent_score = 0.0f;
  NBOtherAgentSlotRecord best_agent = {};
  if (development->stage >= 9u) {
    for (uint index = 0u; index < uniforms.other_agent_slot_count; ++index) {
      const NBOtherAgentSlotRecord candidate = agent_slots[index];
      const float score = candidate.existence_probability
        * (1.0f - candidate.uncertainty)
        * (0.5f + 0.5f * candidate.identity_confidence);
      if (score > best_agent_score
          || (score == best_agent_score && index < best_agent_index)) {
        best_agent_index = index;
        best_agent_score = score;
        best_agent = candidate;
      }
    }
  }

  uint best_object_index = 0xffffffffu;
  float best_object_score = 0.0f;
  float best_attention_probability = 0.0f;
  float best_attention_uncertainty = 1.0f;
  ulong attended_object_identifier = 0ul;
  NBObjectSlotRecord best_object = {};
  if (best_agent_index != 0xffffffffu) {
    for (uint index = 0u; index < uniforms.relation_slot_count; ++index) {
      const NBRelationSlotRecord relation = relations[index];
      if (relation.relation_kind != 11u
          || relation.subject_identifier != best_agent.identifier) continue;
      const float score = relation.probability * (1.0f - relation.uncertainty);
      if (score > best_attention_probability) {
        best_attention_probability = score;
        best_attention_uncertainty = relation.uncertainty;
        attended_object_identifier = relation.object_identifier;
      }
    }
  }
  if (development->stage >= 6u) {
    for (uint index = 0u; index < uniforms.object_slot_count; ++index) {
      const NBObjectSlotRecord candidate = object_slots[index];
      if (attended_object_identifier != 0ul
          && candidate.identifier != attended_object_identifier) continue;
      const float score = candidate.existence_probability
        * max(candidate.visibility, 0.25f)
        * (1.0f - candidate.uncertainty)
        * (attended_object_identifier == 0ul
          ? 1.0f : max(best_attention_probability, 0.01f));
      if (score > best_object_score
          || (score == best_object_score && index < best_object_index)) {
        best_object_index = index;
        best_object_score = score;
        best_object = candidate;
      }
    }
  }

  for (uint feature = 0u; feature < uniforms.context_belief_count; ++feature) {
    float value = 0.0f;
    if (best_agent_index != 0xffffffffu) {
      if (feature == 0u) value = best_agent.existence_probability;
      else if (feature == 1u) value = best_agent.identity_confidence;
      else if (feature == 2u) value = best_agent.gaze_confidence;
      else if (feature == 3u) value = best_agent.goal_confidence;
      else if (feature == 4u) value = best_agent.social_relation;
      else if (feature == 5u) value = best_agent.predicted_action;
      else if (feature == 6u) value = best_agent.uncertainty;
      else if (feature == 7u) value = best_agent.communication_evidence;
      else if (feature < 16u) value = best_agent.body_pose[feature - 8u];
      else if (feature < 20u) value = best_agent.gaze[feature - 16u];
      else value = best_agent.latent[(feature - 20u) % 102u];
    }
    if (feature == 126u) value = best_attention_probability;
    if (feature == 127u) value = best_attention_uncertainty;
    if (best_object_index != 0xffffffffu && feature >= 128u && feature < 144u) {
      const uint object_feature = feature - 128u;
      if (object_feature == 0u) value = best_object.existence_probability;
      else if (object_feature == 1u) value = best_object.identity_confidence;
      else if (object_feature == 2u) value = best_object.visibility;
      else if (object_feature == 3u) value = best_object.uncertainty;
      else if (object_feature < 8u) value = best_object.pose[object_feature - 4u];
      else if (object_feature < 12u) value = best_object.velocity[object_feature - 8u];
      else value = best_object.affordances[object_feature - 12u];
    }
    context[feature] = value;
  }

  if (!frame_reused && uniforms.drive_count > 9u) {
    NBDriveStateRecord social_drive = drives[9];
    if (social_drive.kind == 0u) social_drive.kind = 10u;
    if (social_drive.priority_weight <= 0.0f) social_drive.priority_weight = 1.0f;
    social_drive.viable_minimum = 0.0f;
    social_drive.viable_maximum = 0.25f;
    const float previous = social_drive.level;
    social_drive.level = development->stage >= 9u
      ? 1.0f - nb_saturate(best_agent_score)
      : 0.0f;
    const float elapsed_seconds = max(
      float(uniforms.delta_microseconds) * 1.0e-6f, 1.0e-6f
    );
    social_drive.estimated_rate =
      (social_drive.level - previous) / elapsed_seconds;
    social_drive.deficit = social_drive.level > social_drive.viable_maximum
      ? social_drive.level - social_drive.viable_maximum
      : 0.0f;
    social_drive.potential = social_drive.priority_weight
      * social_drive.deficit * social_drive.deficit;
    drives[9] = social_drive;
  }
  if (!frame_reused && uniforms.neuromodulator_count > 8u) {
    NBNeuromodulatorStateRecord social_modulator = neuromodulators[8];
    if (social_modulator.kind == 0u) social_modulator.kind = 9u;
    if (social_modulator.decay_time_constant_seconds <= 0.0f) {
      social_modulator.decay_time_constant_seconds = 0.1f;
    }
    social_modulator.value = nb_saturate(
      best_agent_score
        * (0.5f + 0.5f * max(best_agent.social_relation, 0.0f))
    );
    neuromodulators[8] = social_modulator;
  }

  ulong object_token_identifier = active_workspace_capacity > 12u
    ? metadata[12].identifier : 0ul;
  if (best_object_index != 0xffffffffu && active_workspace_capacity > 12u) {
    const uint slot = 12u;
    const uint base = slot * uniforms.workspace_dimension;
    for (uint feature = 0u; feature < uniforms.workspace_dimension; ++feature) {
      float value = 0.0f;
      if (feature == 0u) value = best_object.existence_probability;
      else if (feature == 1u) value = best_object.identity_confidence;
      else if (feature == 2u) value = best_object.visibility;
      else if (feature == 3u) value = best_object.uncertainty;
      else if (feature < 8u) value = best_object.pose[feature - 4u];
      else if (feature < 12u) value = best_object.velocity[feature - 8u];
      else if (feature < 20u) value = best_object.affordances[feature - 12u];
      else value = best_object.latent[(feature - 20u) % 102u];
      workspace[base + feature] = value;
    }
    const NBWorkspaceMetadataRecord prior_object = metadata[slot];
    const bool same_object = nb_workspace_identity_matches(
      prior_object, 3u, 39u, best_object.identifier
    );
    NBWorkspaceMetadataRecord object_token = same_object
      ? prior_object : NBWorkspaceMetadataRecord{};
    if (!same_object) {
      object_token.identifier =
        (uniforms.target_timestamp_microseconds << 8u) | ulong(slot + 1u);
      object_token.source_timestamp_microseconds =
        best_object.last_seen_timestamp_microseconds;
    }
    object_token_identifier = object_token.identifier;
    object_token.last_refresh_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    object_token.entity_identifier = best_object.identifier;
    object_token.kind_and_source = 3u | (39u << 16u);
    object_token.confidence = nb_saturate(best_object_score);
    object_token.persistence_priority = 0.65f;
    object_token.selection_score = nb_saturate(best_object_score);
    object_token.provenance_kind = 0u;
    object_token.flags = 1u;
    object_token.last_score_update_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    metadata[slot] = object_token;
  }

  if (development->stage < 9u || best_agent_index == 0xffffffffu
      || active_workspace_capacity <= 11u) {
    return;
  }

  uint selected_indices[4] = {
    0xffffffffu, 0xffffffffu, 0xffffffffu, 0xffffffffu
  };
  uint target_slots[4] = {11u, 13u, 14u, 15u};
  for (uint rank = 0u; rank < 4u; ++rank) {
    const uint target_slot = target_slots[rank];
    if (target_slot >= active_workspace_capacity) continue;
    uint selected_index = 0xffffffffu;
    float selected_score = 0.0f;
    NBOtherAgentSlotRecord selected_agent = {};
    for (uint index = 0u; index < uniforms.other_agent_slot_count; ++index) {
      bool already_selected = false;
      for (uint prior = 0u; prior < rank; ++prior) {
        already_selected = already_selected || selected_indices[prior] == index;
      }
      if (already_selected) continue;
      const NBOtherAgentSlotRecord candidate = agent_slots[index];
      const float score = candidate.existence_probability
        * (1.0f - candidate.uncertainty)
        * (0.5f + 0.5f * candidate.identity_confidence);
      if (score > selected_score
          || (score == selected_score && index < selected_index)) {
        selected_index = index;
        selected_score = score;
        selected_agent = candidate;
      }
    }
    if (selected_index == 0xffffffffu || selected_score <= 0.0f) continue;
    selected_indices[rank] = selected_index;
    const uint base = target_slot * uniforms.workspace_dimension;
    for (uint feature = 0u; feature < uniforms.workspace_dimension; ++feature) {
      float value = 0.0f;
      if (feature == 0u) value = selected_agent.existence_probability;
      else if (feature == 1u) value = selected_agent.identity_confidence;
      else if (feature == 2u) value = selected_agent.gaze_confidence;
      else if (feature == 3u) value = selected_agent.goal_confidence;
      else if (feature == 4u) value = selected_agent.social_relation;
      else if (feature == 5u) value = selected_agent.predicted_action;
      else if (feature == 6u) value = selected_agent.uncertainty;
      else if (feature == 7u) value = selected_agent.communication_evidence;
      else if (feature < 16u) value = selected_agent.body_pose[feature - 8u];
      else if (feature < 20u) value = selected_agent.gaze[feature - 16u];
      else value = selected_agent.latent[(feature - 20u) % 102u];
      workspace[base + feature] = value;
    }
    const bool communication_token = development->stage >= 10u
      && selected_agent.communication_evidence
        > max(belief_parameters[4], 0.01f);
    const uint token_kind = communication_token ? 10u : 4u;
    const uint source_module = communication_token ? 51u : 44u;
    const NBWorkspaceMetadataRecord prior_token = metadata[target_slot];
    const bool same_agent = nb_workspace_identity_matches(
      prior_token, token_kind, source_module, selected_agent.identifier
    );
    NBWorkspaceMetadataRecord token = same_agent
      ? prior_token : NBWorkspaceMetadataRecord{};
    if (!same_agent) {
      token.identifier = (uniforms.target_timestamp_microseconds << 8u)
        | ulong(target_slot + 1u);
      token.source_timestamp_microseconds =
        selected_agent.last_seen_timestamp_microseconds;
    }
    token.last_refresh_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    token.entity_identifier = selected_agent.identifier;
    // Bind a referent only when the agent-to-object attention edge actually
    // exists. The most visually salient object is not automatically the
    // demonstrator's goal or the referent of a communication event.
    token.bound_token_identifier = rank == 0u
        && attended_object_identifier != 0ul
        && best_attention_probability > max(belief_parameters[4], 0.01f)
      ? object_token_identifier : 0ul;
    token.kind_and_source = token_kind | (source_module << 16u);
    token.confidence = nb_saturate(selected_score);
    token.persistence_priority = communication_token ? 0.8f : 0.65f;
    token.selection_score = nb_saturate(selected_score);
    token.provenance_kind = communication_token ? 5u : 0u;
    token.flags = 1u;
    token.last_score_update_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    metadata[target_slot] = token;
  }
}

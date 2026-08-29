#include <metal_stdlib>
using namespace metal;

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
  ulong object_slot_offset;
  ulong other_agent_slot_offset;
  ulong context_belief_offset;
  ulong relation_slot_offset;
  ulong spatial_transform_offset;
  ulong physiology_belief_offset;
  ulong body_belief_offset;
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
};

static_assert(sizeof(NBCognitiveUniforms) == 384);
static_assert(sizeof(NBWorldModelLevelRecord) == 48);
static_assert(sizeof(NBDriveStateRecord) == 32);
static_assert(sizeof(NBNeuromodulatorStateRecord) == 16);
static_assert(sizeof(NBFastPlasticityStateRecord) == 32);
static_assert(sizeof(NBActiveSensingEfficacyRecord) == 32);
static_assert(sizeof(NBReceptorEventStateRecord) == 32);
static_assert(sizeof(NBEventQueueStateHeader) == 32);
static_assert(sizeof(NBWorkspaceMetadataRecord) == 64);
static_assert(sizeof(NBInternalActionRecord) == 64);
static_assert(sizeof(NBAutonomicCommandRecord) == 16);
static_assert(sizeof(NBActiveSensingCommandRecord) == 16);
static_assert(sizeof(NBObjectSlotRecord) == 512);
static_assert(sizeof(NBOtherAgentSlotRecord) == 512);
static_assert(sizeof(NBRelationSlotRecord) == 64);
static_assert(sizeof(NBSpatialTransformRecord) == 96);
static_assert(sizeof(NBDevelopmentalHeader) == 256);
static_assert(sizeof(NBRegionalMaturationRecord) == 32);
static_assert(sizeof(NBRegionalPlasticModulationRecord) == 32);

inline float nb_saturate(float value) {
  return clamp(value, 0.0f, 1.0f);
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
  uint range_offset,
  uint range_count,
  uint index)
{
  return range_count == 0u
    ? 0.0f
    : observations[range_offset + index % range_count];
}

inline float nb_observation_energy(
  device const float *observations,
  uint range_offset,
  uint range_count,
  uint seed)
{
  if (range_count == 0u) return 0.0f;
  float energy = 0.0f;
  for (uint sample = 0u; sample < 8u; ++sample) {
    energy += abs(nb_observation_feature(
      observations, range_offset, range_count, seed * 17u + sample * 29u
    )) * 0.125f;
  }
  return nb_saturate(energy);
}

inline float nb_fused_interoceptive_feature(
  device const float *observations,
  uint observation_offset,
  uint observation_count,
  device const float *physiology,
  uint physiology_count,
  uint index)
{
  const bool has_receptor = observation_count > 0u;
  const bool has_belief = physiology_count > 0u;
  const float receptor = has_receptor
    ? nb_observation_feature(
        observations, observation_offset, observation_count, index
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
  uint gid [[thread_position_in_grid]])
{
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
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      0u
    ));
    const float hydration = nb_saturate(nb_fused_interoceptive_feature(
      observations,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      1u
    ));
    const float oxygen = nb_saturate(nb_fused_interoceptive_feature(
      observations,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      2u
    ));
    const float carbon_dioxide = nb_saturate(nb_fused_interoceptive_feature(
      observations,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      3u
    ));
    const float temperature = nb_fused_interoceptive_feature(
      observations,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      4u
    );
    const float sensed_fatigue = nb_saturate(nb_fused_interoceptive_feature(
      observations,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      5u
    ));
    const float tissue_damage = nb_saturate(nb_fused_interoceptive_feature(
      observations,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      6u
    ));
    const float inflammation = nb_saturate(nb_fused_interoceptive_feature(
      observations,
      uniforms.interoception_observation_offset,
      uniforms.interoception_observation_count,
      physiology,
      uniforms.physiology_belief_count,
      7u
    ));
    const float sleep_pressure = nb_saturate(nb_fused_interoceptive_feature(
      observations,
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
      body + 16
    );
    if ((identity[3] & 1ul) == 0ul || !isfinite(body[9])) continue;
    const float standard_deviation = sqrt(max(body[9], 0.0f));
    body_model_uncertainty = max(
      body_model_uncertainty,
      standard_deviation / (1.0f + standard_deviation)
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
          sqrt(max(epistemic_variance, 0.0f)) * best_sensing_efficacy,
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
  uint gid [[thread_position_in_grid]])
{
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  device const float *recurrent = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
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
        uniforms.vision_observation_offset,
        uniforms.vision_observation_count,
        seed
      );
      const float olfactory_energy = nb_observation_energy(
        observations,
        uniforms.olfaction_observation_offset,
        uniforms.olfaction_observation_count,
        seed + 11u
      );
      const float gustatory_energy = nb_observation_energy(
        observations,
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
          uniforms.vision_observation_offset,
          uniforms.vision_observation_count,
          seed * 37u + affordance * 19u
        );
        const float olfactory_feature = nb_observation_feature(
          observations,
          uniforms.olfaction_observation_offset,
          uniforms.olfaction_observation_count,
          seed * 43u + affordance * 23u
        );
        const float gustatory_feature = nb_observation_feature(
          observations,
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
      for (uint component = 0u; component < 102u; ++component) {
        const float sensed = nb_observation_feature(
          observations,
          uniforms.vision_observation_offset,
          uniforms.vision_observation_count,
          seed * 53u + component * 7u
        );
        const float olfactory = nb_observation_feature(
          observations,
          uniforms.olfaction_observation_offset,
          uniforms.olfaction_observation_count,
          seed * 59u + component * 11u
        );
        const float gustatory = nb_observation_feature(
          observations,
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
        uniforms.vision_observation_offset,
        uniforms.vision_observation_count,
        seed
      );
      const float auditory_energy = nb_observation_energy(
        observations,
        uniforms.audition_observation_offset,
        uniforms.audition_observation_count,
        seed + 17u
      );
      const float olfactory_energy = nb_observation_energy(
        observations,
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
      for (uint component = 0u; component < 8u; ++component) {
        body_change += abs(observed_body[component] - slot.body_pose[component])
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
      for (uint component = 0u; component < 102u; ++component) {
        const float visual = nb_observation_feature(
          observations,
          uniforms.vision_observation_offset,
          uniforms.vision_observation_count,
          seed * 61u + component * 11u
        );
        const float auditory = nb_observation_feature(
          observations,
          uniforms.audition_observation_offset,
          uniforms.audition_observation_count,
          seed * 31u + component * 17u
        );
        const float olfactory = nb_observation_feature(
          observations,
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
/// Kind 6 is self-to-object reachability, kind 10 is communication with self,
/// and kind 11 is an explicit attention edge used for joint attention.
kernel void advance_entity_relation_graph(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  device const float *belief_parameters [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
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
  const uint active_relation_count = communication_base
    + uniforms.other_agent_slot_count;
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
  } else if (gid < active_relation_count && development->stage >= 9u) {
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
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.spatial_transform_count) return;
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
    uniforms.vision_observation_offset,
    uniforms.vision_observation_count,
    gid * 17u + 1u
  );
  const float proprioceptive_energy = nb_observation_energy(
    observations,
    uniforms.proprioception_observation_offset,
    uniforms.proprioception_observation_count,
    gid * 19u + 2u
  );
  const float vestibular_energy = nb_observation_energy(
    observations,
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
      uniforms.vision_observation_offset,
      uniforms.vision_observation_count,
      gid * 47u + component * 13u
    );
    const float proprioception = nb_observation_feature(
      observations,
      uniforms.proprioception_observation_offset,
      uniforms.proprioception_observation_count,
      gid * 43u + component * 17u
    );
    const float vestibular = nb_observation_feature(
      observations,
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
  const uint pre_index = gid % uniforms.recurrent_scalar_count;
  const uint post_index = (pre_index + 1u) % uniforms.recurrent_scalar_count;
  const float activity_product = recurrent[pre_index] * recurrent[post_index];
  site.eligibility = min(
    site.eligibility_retention,
    clamp(plasticity_parameters[2], 0.0f, 1.0f)
  ) * site.eligibility + plasticity_parameters[3] * activity_product;
  const float local_modulation = neuromodulators[
    uint(site.region_identifier - 1u) % uniforms.neuromodulator_count
  ].value;
  site.coefficient = clamp(
    min(site.coefficient_retention, clamp(plasticity_parameters[1], 0.0f, 1.0f))
      * site.coefficient
      + min(site.learning_rate, max(plasticity_parameters[0], 0.0f))
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
  float signed_sum = 0.0f;
  float magnitude_sum = 0.0f;
  float eligibility_sum = 0.0f;
  uint coefficient_count = 0u;
  for (uint index = 0u; index < uniforms.fast_plasticity_count; ++index) {
    const NBFastPlasticityStateRecord site = sites[index];
    if (uint(site.region_identifier) != module_identifier) continue;
    signed_sum += site.coefficient;
    magnitude_sum += abs(site.coefficient);
    eligibility_sum += site.eligibility;
    coefficient_count += 1u;
  }
  const float divisor = coefficient_count > 0u
    ? 1.0f / float(coefficient_count) : 0.0f;
  const float mean = signed_sum * divisor;
  const float magnitude = magnitude_sum * divisor;
  const float eligibility = eligibility_sum * divisor;
  NBRegionalPlasticModulationRecord record;
  record.module_identifier = module_identifier;
  record.coefficient_count = coefficient_count;
  record.recurrent_delta = clamp(0.10f * mean, -0.20f, 0.20f);
  record.local_delta = clamp(0.08f * mean, -0.15f, 0.15f);
  record.route_delta = clamp(0.10f * magnitude, 0.0f, 0.20f);
  record.drive_delta = clamp(0.05f * eligibility, -0.10f, 0.10f);
  record.gate_delta = clamp(0.05f * mean, -0.10f, 0.10f);
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

kernel void broadcast_foundation_workspace(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  device const float *memory_parameters [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  const uint active_workspace_capacity = min(
    uniforms.workspace_capacity, development->workspace_capacity
  );
  const uint content_count = uniforms.workspace_capacity * uniforms.workspace_dimension;
  if (gid >= max(content_count, uniforms.workspace_capacity)) {
    return;
  }
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

  if (gid < content_count) {
    const uint slot = gid / uniforms.workspace_dimension;
    const uint feature = gid % uniforms.workspace_dimension;
    if (slot >= active_workspace_capacity) {
      content[gid] = 0.0f;
    } else if (slot == 0u) {
      content[gid] = feature < uniforms.drive_count
        ? drives[feature].deficit
        : recurrent[feature % uniforms.recurrent_scalar_count];
    } else if (slot == 1u) {
      content[gid] = recurrent[feature % uniforms.recurrent_scalar_count];
    } else {
      content[gid] *= clamp(memory_parameters[7], 0.0f, 1.0f);
    }
  }
  if (gid < active_workspace_capacity && gid < 2u) {
    NBWorkspaceMetadataRecord token = metadata[gid];
    token.identifier = (uniforms.target_timestamp_microseconds << 8) | ulong(gid + 1u);
    token.source_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    token.last_refresh_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    token.kind_and_source = gid == 0u ? (8u | (70u << 16)) : (1u | (25u << 16));
    token.confidence = gid == 0u ? 1.0f : 0.5f;
    metadata[gid] = token;
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
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u) return;
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

  for (uint slot = 11u; slot < uniforms.workspace_capacity; ++slot) {
    const uint base = slot * uniforms.workspace_dimension;
    for (uint feature = 0u; feature < uniforms.workspace_dimension; ++feature) {
      workspace[base + feature] = 0.0f;
    }
    NBWorkspaceMetadataRecord empty = {};
    metadata[slot] = empty;
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

  if (uniforms.drive_count > 9u) {
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
  if (uniforms.neuromodulator_count > 8u) {
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

  if (development->stage < 9u || best_agent_index == 0xffffffffu
      || active_workspace_capacity <= 11u) {
    return;
  }

  ulong object_token_identifier = 0ul;
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
    object_token_identifier = (uniforms.target_timestamp_microseconds << 8u)
      | ulong(slot + 1u);
    NBWorkspaceMetadataRecord object_token = {};
    object_token.identifier = object_token_identifier;
    object_token.source_timestamp_microseconds =
      best_object.last_seen_timestamp_microseconds;
    object_token.last_refresh_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    object_token.entity_identifier = best_object.identifier;
    object_token.kind_and_source = 3u | (39u << 16u);
    object_token.confidence = nb_saturate(best_object_score);
    metadata[slot] = object_token;
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
    NBWorkspaceMetadataRecord token = {};
    token.identifier = (uniforms.target_timestamp_microseconds << 8u)
      | ulong(target_slot + 1u);
    token.source_timestamp_microseconds =
      selected_agent.last_seen_timestamp_microseconds;
    token.last_refresh_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    token.entity_identifier = selected_agent.identifier;
    token.bound_token_identifier = rank == 0u
      ? object_token_identifier : 0ul;
    token.kind_and_source = communication_token
      ? (10u | (51u << 16u))
      : (4u | (44u << 16u));
    token.confidence = nb_saturate(selected_score);
    metadata[target_slot] = token;
  }
}

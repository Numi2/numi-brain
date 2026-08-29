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
  ulong event_queue_offset;
  ulong developmental_state_offset;
  ulong regional_maturation_offset;
  ulong regional_plastic_modulation_offset;
  ulong hot_state_byte_count;
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
  uint reserved2;
  uint reserved3;
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

static_assert(sizeof(NBCognitiveUniforms) == 184);
static_assert(sizeof(NBWorldModelLevelRecord) == 48);
static_assert(sizeof(NBDriveStateRecord) == 32);
static_assert(sizeof(NBNeuromodulatorStateRecord) == 16);
static_assert(sizeof(NBFastPlasticityStateRecord) == 32);
static_assert(sizeof(NBReceptorEventStateRecord) == 32);
static_assert(sizeof(NBEventQueueStateHeader) == 32);
static_assert(sizeof(NBWorkspaceMetadataRecord) == 64);
static_assert(sizeof(NBDevelopmentalHeader) == 256);
static_assert(sizeof(NBRegionalMaturationRecord) == 32);
static_assert(sizeof(NBRegionalPlasticModulationRecord) == 32);

inline float nb_saturate(float value) {
  return clamp(value, 0.0f, 1.0f);
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
    if (gid == 5u) target = max(target * exp(-elapsed_seconds * 0.5f), pain);
    if (gid == 6u) target = max(target * exp(-elapsed_seconds * 0.02f), injury);
    if (gid == 2u) target = max(target, physiological_critical);
    if (gid == 4u) target = nb_saturate(target + overload * elapsed_seconds);
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

kernel void advance_fast_plasticity_foundation(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
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
    site.coefficient_retention = 0.999f;
    site.eligibility_retention = 0.95f;
    site.learning_rate = 0.001f;
    site.maximum_magnitude = 1.0f;
  }
  const uint pre_index = gid % uniforms.recurrent_scalar_count;
  const uint post_index = (pre_index + 1u) % uniforms.recurrent_scalar_count;
  const float activity_product = recurrent[pre_index] * recurrent[post_index];
  site.eligibility = site.eligibility_retention * site.eligibility + activity_product;
  const float local_modulation = neuromodulators[
    uint(site.region_identifier - 1u) % uniforms.neuromodulator_count
  ].value;
  site.coefficient = clamp(
    site.coefficient_retention * site.coefficient
      + site.learning_rate * development->learning_rate_multiplier
        * local_modulation * site.eligibility,
    -site.maximum_magnitude,
    site.maximum_magnitude
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

kernel void broadcast_foundation_workspace(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
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
      content[gid] *= 0.995f;
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

kernel void advance_foundation_motor_control(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.active_control_scalar_count
      || uniforms.recurrent_scalar_count == 0u) {
    return;
  }
  device float *control = reinterpret_cast<device float *>(
    hot_state + uniforms.active_control_offset
  );
  device const float *recurrent = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  device const NBDriveStateRecord *drives =
    reinterpret_cast<device const NBDriveStateRecord *>(hot_state + uniforms.drive_offset);
  const float safety = uniforms.drive_count > 11u ? nb_saturate(drives[11].level) : 0.0f;
  if (gid < uniforms.actuator_count) {
    const uint source = (uniforms.recurrent_scalar_count - 1u -
      (gid % uniforms.recurrent_scalar_count));
    const float descending = 1.0f / (1.0f + exp(-recurrent[source]));
    control[gid] = nb_saturate(descending * (1.0f - safety));
  } else if (gid < uniforms.actuator_count + uniforms.synergy_count) {
    const uint source = gid % uniforms.recurrent_scalar_count;
    control[gid] = tanh(recurrent[source]);
  } else {
    control[gid] *= 0.999f;
  }
}

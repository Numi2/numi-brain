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
  uint reserved0;
  uint reserved1;
  uint reserved2;
  uint reserved3;
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

static_assert(sizeof(NBCognitiveUniforms) == 160);
static_assert(sizeof(NBDriveStateRecord) == 32);
static_assert(sizeof(NBNeuromodulatorStateRecord) == 16);
static_assert(sizeof(NBFastPlasticityStateRecord) == 32);
static_assert(sizeof(NBReceptorEventStateRecord) == 32);
static_assert(sizeof(NBEventQueueStateHeader) == 32);
static_assert(sizeof(NBWorkspaceMetadataRecord) == 64);

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
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.world_model_scalar_count
      || uniforms.recurrent_scalar_count == 0u) {
    return;
  }
  device float *recurrent = reinterpret_cast<device float *>(
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
  const float elapsed_seconds = float(uniforms.delta_microseconds) * 1.0e-6f;
  const float recurrent_value = recurrent[gid % uniforms.recurrent_scalar_count];
  const float drive = drives[gid % uniforms.drive_count].deficit;
  const float modulation = neuromodulators[gid % uniforms.neuromodulator_count].value;
  const float target = tanh(
    0.68f * recurrent_value + 0.18f * world[gid]
      + 0.09f * drive + 0.05f * modulation
  );
  const float alpha = 1.0f - exp(-elapsed_seconds / 0.05f);
  world[gid] = mix(world[gid], target, nb_saturate(alpha));
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
  NBFastPlasticityStateRecord site = sites[gid];
  if (site.region_identifier == 0u) {
    site.region_identifier = ushort(gid % uniforms.module_count + 1u);
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
      + site.learning_rate * local_modulation * site.eligibility,
    -site.maximum_magnitude,
    site.maximum_magnitude
  );
  sites[gid] = site;
}

kernel void broadcast_foundation_workspace(
  device uchar *hot_state [[buffer(0)]],
  constant NBCognitiveUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
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
    if (slot == 0u) {
      content[gid] = feature < uniforms.drive_count
        ? drives[feature].deficit
        : recurrent[feature % uniforms.recurrent_scalar_count];
    } else if (slot == 1u) {
      content[gid] = recurrent[feature % uniforms.recurrent_scalar_count];
    } else {
      content[gid] *= 0.995f;
    }
  }
  if (gid < uniforms.workspace_capacity && gid < 2u) {
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

#include <metal_stdlib>
using namespace metal;

constant uint NB_SENSORY_FRAME_VALID = 1u;
constant uint NB_RECEPTOR_EVENT_DERIVED = 1u;

struct NBSensoryUniforms {
  ulong target_timestamp_microseconds;
  ulong episode_identifier;
  ulong control_step_identifier;
  ulong random_counter_generation;
  ulong observation_offset;
  ulong adaptation_offset;
  ulong frame_metadata_offset;
  ulong event_queue_offset;
  ulong developmental_state_offset;
  uint environment_identifier;
  uint descriptor_count;
  uint total_observation_scalars;
  uint total_receptors;
  uint event_capacity;
  uint event_rule_count;
  uint delta_microseconds;
  uint reserved1;
};

struct NBSensoryDescriptor {
  uint modality;
  uint receptor_count;
  uint feature_dimension;
  uint input_buffer_index;
  uint output_scalar_offset;
  uint adaptation_offset;
  uint raw_scalar_count;
  uint flags;
  ulong latency_microseconds;
  float adaptation_time_constant_seconds;
  float noise_standard_deviation;
  ulong reserved0;
  ulong reserved1;
};

struct NBReceptorEventRule {
  uint identifier;
  uint modality;
  uint receptor_start;
  uint receptor_count;
  uint feature_index;
  uint comparison;
  uint event_kind;
  uint event_flags;
  float threshold;
  float magnitude_scale;
  uint source_identifier;
  uint rule_flags;
};

struct NBSensoryFrameMetadata {
  ulong receptor_timestamp_microseconds;
  ulong delivery_timestamp_microseconds;
  uint modality;
  uint receptor_count;
  uint feature_dimension;
  uint flags;
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

static_assert(sizeof(NBSensoryUniforms) == 104);
static_assert(sizeof(NBSensoryDescriptor) == 64);
static_assert(sizeof(NBReceptorEventRule) == 48);
static_assert(sizeof(NBSensoryFrameMetadata) == 32);
static_assert(sizeof(NBEventQueueHeader) == 32);
static_assert(sizeof(NBReceptorEventRecord) == 32);
static_assert(sizeof(NBDevelopmentalHeader) == 256);

inline uint nb_hash32(uint value) {
  value ^= value >> 16;
  value *= 0x7feb352du;
  value ^= value >> 15;
  value *= 0x846ca68bu;
  value ^= value >> 16;
  return value;
}

inline float nb_counter_noise(
  constant NBSensoryUniforms &uniforms,
  uint modality,
  uint sample_index)
{
  uint key = uniforms.environment_identifier;
  key = nb_hash32(key ^ uint(uniforms.episode_identifier));
  key = nb_hash32(key ^ uint(uniforms.control_step_identifier));
  key = nb_hash32(key ^ uint(uniforms.random_counter_generation));
  key = nb_hash32(key ^ uint(uniforms.target_timestamp_microseconds));
  key = nb_hash32(key ^ uint(uniforms.target_timestamp_microseconds >> 32));
  key = nb_hash32(key ^ modality);
  key = nb_hash32(key ^ sample_index);
  return (float(key) / 4294967295.0f) * 2.0f - 1.0f;
}

inline float nb_raw_input(
  uint input_index,
  uint scalar_index,
  device const float *input0,
  device const float *input1,
  device const float *input2,
  device const float *input3,
  device const float *input4,
  device const float *input5,
  device const float *input6,
  device const float *input7)
{
  switch (input_index) {
    case 0u: return input0[scalar_index];
    case 1u: return input1[scalar_index];
    case 2u: return input2[scalar_index];
    case 3u: return input3[scalar_index];
    case 4u: return input4[scalar_index];
    case 5u: return input5[scalar_index];
    case 6u: return input6[scalar_index];
    default: return input7[scalar_index];
  }
}

inline uint nb_descriptor_for_scalar(
  device const NBSensoryDescriptor *descriptors,
  uint descriptor_count,
  uint scalar_index)
{
  for (uint index = 0u; index < descriptor_count; ++index) {
    const NBSensoryDescriptor descriptor = descriptors[index];
    if (scalar_index >= descriptor.output_scalar_offset
        && scalar_index < descriptor.output_scalar_offset + descriptor.raw_scalar_count) {
      return index;
    }
  }
  return descriptor_count;
}

inline uint nb_descriptor_for_receptor(
  device const NBSensoryDescriptor *descriptors,
  uint descriptor_count,
  uint receptor_index)
{
  for (uint index = 0u; index < descriptor_count; ++index) {
    const NBSensoryDescriptor descriptor = descriptors[index];
    if (receptor_index >= descriptor.adaptation_offset
        && receptor_index < descriptor.adaptation_offset + descriptor.receptor_count) {
      return index;
    }
  }
  return descriptor_count;
}

kernel void begin_sensory_frame(
  device uchar *hot_state [[buffer(0)]],
  device const NBSensoryDescriptor *descriptors [[buffer(1)]],
  constant NBSensoryUniforms &uniforms [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
  device NBEventQueueHeader *header = reinterpret_cast<device NBEventQueueHeader *>(
    hot_state + uniforms.event_queue_offset
  );
  device NBSensoryFrameMetadata *metadata =
    reinterpret_cast<device NBSensoryFrameMetadata *>(
      hot_state + uniforms.frame_metadata_offset
    );
  if (gid == 0u) {
    atomic_store_explicit(&header->count, 0u, memory_order_relaxed);
    header->capacity = uniforms.event_capacity;
    atomic_store_explicit(&header->overflow_count, 0u, memory_order_relaxed);
    header->flags = NB_SENSORY_FRAME_VALID;
    header->target_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    header->generation = uniforms.random_counter_generation;
  }
  if (gid < uniforms.descriptor_count) {
    const NBSensoryDescriptor descriptor = descriptors[gid];
    NBSensoryFrameMetadata frame;
    frame.receptor_timestamp_microseconds =
      uniforms.target_timestamp_microseconds >= descriptor.latency_microseconds
      ? uniforms.target_timestamp_microseconds - descriptor.latency_microseconds
      : 0ul;
    frame.delivery_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    frame.modality = descriptor.modality;
    frame.receptor_count = descriptor.receptor_count;
    frame.feature_dimension = descriptor.feature_dimension;
    frame.flags = NB_SENSORY_FRAME_VALID;
    metadata[gid] = frame;
  }
}

kernel void update_receptor_adaptation(
  device uchar *hot_state [[buffer(0)]],
  device const NBSensoryDescriptor *descriptors [[buffer(1)]],
  constant NBSensoryUniforms &uniforms [[buffer(2)]],
  device const float *input0 [[buffer(3)]],
  device const float *input1 [[buffer(4)]],
  device const float *input2 [[buffer(5)]],
  device const float *input3 [[buffer(6)]],
  device const float *input4 [[buffer(7)]],
  device const float *input5 [[buffer(8)]],
  device const float *input6 [[buffer(9)]],
  device const float *input7 [[buffer(10)]],
  device const float *sensory_parameters [[buffer(11)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.total_receptors) return;
  const uint descriptor_index = nb_descriptor_for_receptor(
    descriptors,
    uniforms.descriptor_count,
    gid
  );
  if (descriptor_index >= uniforms.descriptor_count) return;
  const NBSensoryDescriptor descriptor = descriptors[descriptor_index];
  const uint local_receptor = gid - descriptor.adaptation_offset;
  const uint raw_index = local_receptor * descriptor.feature_dimension;
  const float raw_value = sensory_parameters[0] * nb_raw_input(
    descriptor.input_buffer_index,
    raw_index,
    input0, input1, input2, input3, input4, input5, input6, input7
  );
  device float *adaptation = reinterpret_cast<device float *>(
    hot_state + uniforms.adaptation_offset
  );
  const float elapsed_seconds = float(uniforms.delta_microseconds) * 1.0e-6f;
  const float alpha = 1.0f - exp(
    -elapsed_seconds / max(descriptor.adaptation_time_constant_seconds, 1.0e-4f)
  );
  const float learned_alpha = clamp(alpha * max(sensory_parameters[4], 0.0f), 0.0f, 1.0f);
  adaptation[gid] = mix(adaptation[gid], raw_value, learned_alpha);
}

kernel void transduce_receptor_observations(
  device uchar *hot_state [[buffer(0)]],
  device const NBSensoryDescriptor *descriptors [[buffer(1)]],
  constant NBSensoryUniforms &uniforms [[buffer(2)]],
  device const float *input0 [[buffer(3)]],
  device const float *input1 [[buffer(4)]],
  device const float *input2 [[buffer(5)]],
  device const float *input3 [[buffer(6)]],
  device const float *input4 [[buffer(7)]],
  device const float *input5 [[buffer(8)]],
  device const float *input6 [[buffer(9)]],
  device const float *input7 [[buffer(10)]],
  device const float *sensory_parameters [[buffer(11)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.total_observation_scalars) return;
  const uint descriptor_index = nb_descriptor_for_scalar(
    descriptors,
    uniforms.descriptor_count,
    gid
  );
  if (descriptor_index >= uniforms.descriptor_count) return;
  const NBSensoryDescriptor descriptor = descriptors[descriptor_index];
  const uint local_scalar = gid - descriptor.output_scalar_offset;
  const uint local_receptor = local_scalar / descriptor.feature_dimension;
  const uint global_receptor = descriptor.adaptation_offset + local_receptor;
  const float raw_value = sensory_parameters[0] * nb_raw_input(
    descriptor.input_buffer_index,
    local_scalar,
    input0, input1, input2, input3, input4, input5, input6, input7
  );
  device const float *adaptation = reinterpret_cast<device const float *>(
    hot_state + uniforms.adaptation_offset
  );
  device float *observations = reinterpret_cast<device float *>(
    hot_state + uniforms.observation_offset
  );
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  const float effective_noise = descriptor.noise_standard_deviation
    / max(development->sensor_precision_multiplier, 0.1f);
  const float noise = effective_noise * nb_counter_noise(
    uniforms,
    descriptor.modality,
    local_scalar
  );
  observations[gid] = raw_value
    - max(sensory_parameters[2], 0.0f) * adaptation[global_receptor]
    + sensory_parameters[3] * noise + sensory_parameters[1];
}

kernel void extract_receptor_events(
  device uchar *hot_state [[buffer(0)]],
  device const NBSensoryDescriptor *descriptors [[buffer(1)]],
  device const NBReceptorEventRule *rules [[buffer(2)]],
  constant NBSensoryUniforms &uniforms [[buffer(3)]],
  device const float *sensory_parameters [[buffer(11)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.event_rule_count) return;
  const NBReceptorEventRule rule = rules[gid];
  uint descriptor_index = uniforms.descriptor_count;
  for (uint index = 0u; index < uniforms.descriptor_count; ++index) {
    if (descriptors[index].modality == rule.modality) {
      descriptor_index = index;
      break;
    }
  }
  if (descriptor_index >= uniforms.descriptor_count) return;
  const NBSensoryDescriptor descriptor = descriptors[descriptor_index];
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  float strongest = 0.0f;
  uint strongest_receptor = rule.receptor_start;
  for (uint receptor = 0u; receptor < rule.receptor_count; ++receptor) {
    const uint receptor_index = rule.receptor_start + receptor;
    const uint scalar_index = descriptor.output_scalar_offset
      + receptor_index * descriptor.feature_dimension + rule.feature_index;
    const float value = observations[scalar_index];
    bool active = false;
    float magnitude = 0.0f;
    const float threshold = (rule.rule_flags & 1u) != 0u
      ? rule.threshold
      : max(rule.threshold, sensory_parameters[6]);
    if (rule.comparison == 1u) {
      active = value > threshold;
      magnitude = value - threshold;
    } else if (rule.comparison == 2u) {
      active = value < threshold;
      magnitude = threshold - value;
    } else {
      active = abs(value) > threshold;
      magnitude = abs(value) - threshold;
    }
    magnitude = active
      ? magnitude * rule.magnitude_scale * max(sensory_parameters[5], 0.0f)
      : 0.0f;
    if (magnitude > strongest) {
      strongest = magnitude;
      strongest_receptor = receptor_index;
    }
  }
  if (strongest <= 0.0f) return;

  device NBEventQueueHeader *header = reinterpret_cast<device NBEventQueueHeader *>(
    hot_state + uniforms.event_queue_offset
  );
  const uint slot = atomic_fetch_add_explicit(
    &header->count,
    1u,
    memory_order_relaxed
  );
  if (slot >= header->capacity) {
    atomic_fetch_add_explicit(&header->overflow_count, 1u, memory_order_relaxed);
    return;
  }
  device NBReceptorEventRecord *events = reinterpret_cast<device NBReceptorEventRecord *>(
    header + 1
  );
  NBReceptorEventRecord event;
  event.environment_identifier = uniforms.environment_identifier;
  event.kind = rule.event_kind;
  event.source_identifier = rule.source_identifier != 0u
    ? rule.source_identifier
    : strongest_receptor;
  event.flags = rule.event_flags | NB_RECEPTOR_EVENT_DERIVED;
  event.timestamp_microseconds = uniforms.target_timestamp_microseconds;
  event.magnitude = strongest;
  event.auxiliary_value = float(rule.identifier);
  events[slot] = event;
}

#include <metal_stdlib>
using namespace metal;

struct NBMuscleLocomotorChannel {
  uint length_index, velocity_index, receptor_index, required_validity;
  float reference_length, tonic, length_gain, velocity_gain;
  float gait_sine, gait_cosine, maximum_excitation, padding;
};

struct NBMuscleBalanceSource {
  uint scalar_index, receptor_index, required_validity, input_slot;
  float reference_value, scale, bias, padding;
};

struct NBMuscleBalanceRoute {
  uint source_index, reserved;
  float gain, maximum_correction;
};

struct NBMuscleBalanceRange {
  uint route_start, route_count, reserved0, reserved1;
};

struct NBMuscleBalanceHistorySource {
  uint delay_microseconds;
  float filter_time_constant_seconds;
  float event_threshold;
  uint event_consecutive_samples;
  uint reserved0, reserved1;
};

struct NBMuscleBalanceHistoryUniforms {
  ulong sample_timestamp_microseconds;
  uint source_count;
  uint history_capacity;
  uint write_index;
  uint correction_enabled;
  uint reserved0, reserved1;
};

inline bool nb_muscle_locomotor_inputs(
  device const float *spindles,
  device const uint *validity,
  NBMuscleLocomotorChannel c,
  thread float &length,
  thread float &velocity) {
  length = spindles[c.length_index];
  velocity = spindles[c.velocity_index];
  return (validity[c.receptor_index] & c.required_validity) == c.required_validity
    && isfinite(length) && length > 0.0f && isfinite(velocity);
}

inline float nb_muscle_locomotor_logit(
  NBMuscleLocomotorChannel c,
  float length,
  float velocity,
  float phase,
  float balance_correction) {
  const float feedback = c.length_gain * (length / c.reference_length - 1.0f)
    + c.velocity_gain * velocity / c.reference_length;
  const float gait = c.gait_sine * sin(phase) + c.gait_cosine * cos(phase);
  if (!isfinite(feedback) || !isfinite(gait) || !isfinite(balance_correction)) {
    return 0.0f;
  }
  const float excitation = clamp(
    c.tonic + feedback + gait + balance_correction,
    0.0f,
    c.maximum_excitation);
  // The common decision kernel converts positive logits with tanh, then
  // applies ordinary inhibition and the private protective motor adapter.
  // tanh(10) rounds to 1 in FP32, without the infinite atanh(1).
  return excitation == 1.0f ? 10.0f : atanh(excitation);
}

// Packed phase uses integer physical time modulo period before FP32 conversion.
// Only the delivered spindle packet is visible here; no pose or force buffers.
kernel void nb_muscle_locomotor(
  device const float *spindles [[buffer(0)]],
  device const uint *validity [[buffer(1)]],
  device const NBMuscleLocomotorChannel *channels [[buffer(2)]],
  device float *logits [[buffer(3)]],
  constant uint4 &uniforms [[buffer(4)]], uint gid [[thread_position_in_grid]]) {
  if (gid >= uniforms.x) return;
  const auto c = channels[gid];
  float length = 0.0f, velocity = 0.0f;
  if (!nb_muscle_locomotor_inputs(
      spindles, validity, c, length, velocity)) {
    logits[gid] = 0.0f;
    return;
  }
  logits[gid] = nb_muscle_locomotor_logit(
    c, length, velocity, as_type<float>(uniforms.y), 0.0f);
}

// Standalone v3 keeps the v1 kernel untouched. The host sets uniforms.z from
// committed physical time. Before onset, only the two spindle gains are zero;
// valid delivered spindle evidence and tonic recruitment are still required.
kernel void nb_muscle_locomotor_delayed(
  device const float *spindles [[buffer(0)]],
  device const uint *validity [[buffer(1)]],
  device const NBMuscleLocomotorChannel *channels [[buffer(2)]],
  device float *logits [[buffer(3)]],
  constant uint4 &uniforms [[buffer(4)]], uint gid [[thread_position_in_grid]]) {
  if (gid >= uniforms.x) return;
  auto c = channels[gid];
  float length = 0.0f, velocity = 0.0f;
  if (!nb_muscle_locomotor_inputs(spindles, validity, c, length, velocity)) {
    logits[gid] = 0.0f;
    return;
  }
  if (uniforms.z == 0u) {
    c.length_gain = 0.0f;
    c.velocity_gain = 0.0f;
  }
  logits[gid] = nb_muscle_locomotor_logit(
    c, length, velocity, as_type<float>(uniforms.y), 0.0f);
}

// Standalone v4 uses the prepared native reference-path Jacobian and only
// delivered physical joint receptors. Rows 6...127 are articulated DoFs;
// features 0/1 are each mapped q coordinate and joint velocity. Root motion
// is never a joint correction input. Native physics still owns acceptance.
kernel void nb_muscle_locomotor_joint_path(
  device const float *spindles [[buffer(0)]],
  device const uint *spindle_validity [[buffer(1)]],
  device const float *kinesthesia [[buffer(2)]],
  device const uint *joint_validity [[buffer(3)]],
  device const NBMuscleLocomotorChannel *channels [[buffer(4)]],
  device float *logits [[buffer(5)]],
  constant uint4 &uniforms [[buffer(6)]],
  device const float *reference_position [[buffer(7)]],
  device const float *optimal_length [[buffer(8)]],
  device const float *path_jacobian [[buffer(9)]],
  uint gid [[thread_position_in_grid]]) {
  if (gid >= uniforms.x) return;
  const auto c = channels[gid];
  float spindle_length = 0.0f, spindle_velocity = 0.0f;
  // Keep physical spindle admission, although this law uses joint q/v.
  if (!nb_muscle_locomotor_inputs(spindles, spindle_validity, c,
      spindle_length, spindle_velocity)) {
    logits[gid] = NAN;
    return;
  }
  float length_error = 0.0f;
  float velocity = 0.0f;
  for (uint local = 0u; local < 122u; ++local) {
    const uint row = local + 6u;
    if ((joint_validity[row] & 3u) != 3u) {
      logits[gid] = NAN;
      return;
    }
    const float q = kinesthesia[row * 7u];
    const float v = kinesthesia[row * 7u + 1u];
    const float q_reference = reference_position[local];
    const float derivative = path_jacobian[gid * 122u + local];
    if (!isfinite(q) || !isfinite(v) || !isfinite(q_reference) ||
        !isfinite(derivative)) {
      logits[gid] = NAN;
      return;
    }
    length_error += derivative * (q - q_reference);
    velocity += derivative * v;
  }
  const float length = optimal_length[gid];
  const float error = as_type<float>(uniforms.y) * length_error / length
    + as_type<float>(uniforms.z) * velocity / length;
  if (!isfinite(length) || length <= 0.0f || !isfinite(error)) {
    logits[gid] = NAN;
    return;
  }
  const float excitation = clamp(c.tonic +
    clamp(error, -as_type<float>(uniforms.w), as_type<float>(uniforms.w)),
    0.0f, 1.0f);
  logits[gid] = excitation == 1.0f ? 10.0f : atanh(excitation);
}

// v5 retains the qualified joint-proprioception standing command and adds
// only bounded, accepted-history-gated body-receptor correction. The event
// detector and route kernels precede this dispatch on the same command buffer.
kernel void nb_muscle_locomotor_joint_path_recovery(
  device const float *spindles [[buffer(0)]],
  device const uint *spindle_validity [[buffer(1)]],
  device const float *kinesthesia [[buffer(2)]],
  device const uint *joint_validity [[buffer(3)]],
  device const NBMuscleLocomotorChannel *channels [[buffer(4)]],
  device float *logits [[buffer(5)]],
  constant uint4 &uniforms [[buffer(6)]],
  device const float *reference_position [[buffer(7)]],
  device const float *optimal_length [[buffer(8)]],
  device const float *path_jacobian [[buffer(9)]],
  device const float *recovery_event_error [[buffer(10)]],
  uint gid [[thread_position_in_grid]]) {
  if (gid >= uniforms.x) return;
  const auto c = channels[gid];
  float spindle_length = 0.0f, spindle_velocity = 0.0f;
  if (!nb_muscle_locomotor_inputs(spindles, spindle_validity, c,
      spindle_length, spindle_velocity)) {
    logits[gid] = NAN;
    return;
  }
  float length_error = 0.0f;
  float velocity = 0.0f;
  for (uint local = 0u; local < 122u; ++local) {
    const uint row = local + 6u;
    if ((joint_validity[row] & 3u) != 3u) {
      logits[gid] = NAN;
      return;
    }
    const float q = kinesthesia[row * 7u];
    const float v = kinesthesia[row * 7u + 1u];
    const float derivative = path_jacobian[gid * 122u + local];
    if (!isfinite(q) || !isfinite(v) || !isfinite(reference_position[local])
        || !isfinite(derivative)) {
      logits[gid] = NAN;
      return;
    }
    length_error += derivative * (q - reference_position[local]);
    velocity += derivative * v;
  }
  const float length = optimal_length[gid];
  const float error = as_type<float>(uniforms.y) * length_error / length
    + as_type<float>(uniforms.z) * velocity / length;
  const float spindle_feedback = c.length_gain
      * (spindle_length / c.reference_length - 1.0f)
    + c.velocity_gain * spindle_velocity / c.reference_length;
  const float event_error = recovery_event_error[0];
  // The opposite direction has not passed a physical recovery comparison.
  // Keep the established joint-path standing command for that event.
  const float correction = event_error > 0.0f
    ? clamp(spindle_feedback, -0.2f, 0.2f) : 0.0f;
  if (!isfinite(length) || length <= 0.0f || !isfinite(error)
      || !isfinite(spindle_feedback) || !isfinite(event_error)
      || !isfinite(correction)) {
    logits[gid] = NAN;
    return;
  }
  const float excitation = clamp(c.tonic +
    clamp(error, -as_type<float>(uniforms.w), as_type<float>(uniforms.w))
    + correction, 0.0f, 1.0f);
  logits[gid] = excitation == 1.0f ? 10.0f : atanh(excitation);
}

// Reads only the exact body-receptor rows named by the immutable feedback
// program. Invalid receptor evidence is recorded as invalid and is never
// interpreted as a measured zero error. Extraction continues during baseline
// warmup so delayed and filtered state can become ready before correction.
kernel void nb_muscle_balance_sources(
  device const float *vestibular [[buffer(0)]],
  device const uint *vestibular_validity [[buffer(1)]],
  device const float *touch [[buffer(2)]],
  device const uint *touch_validity [[buffer(3)]],
  device const NBMuscleBalanceSource *sources [[buffer(4)]],
  device float *source_errors [[buffer(5)]],
  device uint *source_validity [[buffer(6)]],
  constant uint4 &uniforms [[buffer(7)]],
  uint gid [[thread_position_in_grid]]) {
  if (gid >= uniforms.x) return;
  source_errors[gid] = 0.0f;
  source_validity[gid] = 0u;

  const auto source = sources[gid];
  float raw = 0.0f;
  uint validity = 0u;
  if (source.input_slot == 0u) {
    raw = vestibular[source.scalar_index];
    validity = vestibular_validity[source.receptor_index];
  } else if (source.input_slot == 1u) {
    raw = touch[source.scalar_index];
    validity = touch_validity[source.receptor_index];
  } else {
    return;
  }
  if ((validity & source.required_validity) != source.required_validity
      || !isfinite(raw)) return;
  const float calibrated = fma(raw, source.scale, source.bias);
  const float error = calibrated - source.reference_value;
  if (!isfinite(calibrated) || !isfinite(error)) return;
  source_errors[gid] = error;
  source_validity[gid] = 1u;
}

// Builds a complete unpublished shadow history from the last committed state,
// inserts this root's exact sample, resolves the declared delay by timestamp,
// and advances a causal first-order filter. Publication or rollback is a host
// pointer swap performed only with the joint root decision.
kernel void nb_muscle_balance_history(
  device const float *observed_errors [[buffer(0)]],
  device const uint *observed_validity [[buffer(1)]],
  device const NBMuscleBalanceHistorySource *source_config [[buffer(2)]],
  device const float *committed_values [[buffer(3)]],
  device const ulong *committed_timestamps [[buffer(4)]],
  device const uint *committed_validity [[buffer(5)]],
  device const float *committed_filtered_values [[buffer(6)]],
  device const ulong *committed_filtered_timestamps [[buffer(7)]],
  device const uint *committed_filtered_validity [[buffer(8)]],
  device float *shadow_values [[buffer(9)]],
  device ulong *shadow_timestamps [[buffer(10)]],
  device uint *shadow_validity [[buffer(11)]],
  device float *shadow_filtered_values [[buffer(12)]],
  device ulong *shadow_filtered_timestamps [[buffer(13)]],
  device uint *shadow_filtered_validity [[buffer(14)]],
  device float *output_errors [[buffer(15)]],
  device uint *output_validity [[buffer(16)]],
  constant NBMuscleBalanceHistoryUniforms &uniforms [[buffer(17)]],
  uint gid [[thread_position_in_grid]]) {
  if (gid >= uniforms.source_count || uniforms.history_capacity == 0u) return;
  output_errors[gid] = 0.0f;
  output_validity[gid] = 0u;

  const uint capacity = uniforms.history_capacity;
  const uint base = gid * capacity;
  for (uint slot = 0u; slot < capacity; ++slot) {
    const uint index = base + slot;
    shadow_values[index] = committed_values[index];
    shadow_timestamps[index] = committed_timestamps[index];
    shadow_validity[index] = committed_validity[index];
  }
  shadow_filtered_values[gid] = committed_filtered_values[gid];
  shadow_filtered_timestamps[gid] = committed_filtered_timestamps[gid];
  shadow_filtered_validity[gid] = committed_filtered_validity[gid];

  if (uniforms.write_index >= capacity) return;
  const uint write_index = base + uniforms.write_index;
  const float observed = observed_errors[gid];
  const bool observation_valid = observed_validity[gid] != 0u
    && isfinite(observed);
  shadow_values[write_index] = observation_valid ? observed : 0.0f;
  shadow_timestamps[write_index] = uniforms.sample_timestamp_microseconds;
  shadow_validity[write_index] = observation_valid ? 1u : 0u;
  const auto config = source_config[gid];
  // A valid delayed sample cannot authorize actuation when this root's
  // physical receptor is absent. Keep the invalid shadow for accepted roots.
  if (!observation_valid) {
    if (config.event_consecutive_samples != 0u) {
      shadow_filtered_values[gid] = 0.0f;
      shadow_filtered_timestamps[gid] = 0u;
      shadow_filtered_validity[gid] = 0u;
    }
    return;
  }

  if (config.event_consecutive_samples != 0u) {
    if (config.event_consecutive_samples != 3u || capacity < 3u
        || !isfinite(config.event_threshold) || config.event_threshold <= 0.0f
        || uniforms.reserved0 == 0u) return;
    float direction = 0.0f;
    const ulong now = uniforms.sample_timestamp_microseconds;
    if (committed_filtered_validity[gid] != 0u) {
      direction = committed_filtered_values[gid];
      const ulong last_motion = committed_filtered_timestamps[gid];
      if (!isfinite(direction) || abs(direction) != 1.0f
          || last_motion > now) return;
      if (abs(observed) >= 0.5f * config.event_threshold) {
        shadow_filtered_timestamps[gid] = now;
      } else if (now - last_motion >= 50000ul) {
        direction = 0.0f;
        shadow_filtered_values[gid] = 0.0f;
        shadow_filtered_timestamps[gid] = 0ul;
        shadow_filtered_validity[gid] = 0u;
      }
    }
    if (direction == 0.0f) {
      const float candidate_direction = observed > 0.0f ? 1.0f : -1.0f;
      bool triggered = true;
      for (uint prior = 0u; prior < 3u && triggered; ++prior) {
        if (now < ulong(prior) * ulong(uniforms.reserved0)) {
          triggered = false;
          break;
        }
        const ulong target = now - ulong(prior) * ulong(uniforms.reserved0);
        bool found = false;
        for (uint slot = 0u; slot < capacity; ++slot) {
          const uint index = base + slot;
          if (shadow_validity[index] != 0u
              && shadow_timestamps[index] == target
              && isfinite(shadow_values[index])
              && shadow_values[index] * candidate_direction >= config.event_threshold) {
            found = true;
            break;
          }
        }
        triggered = triggered && found;
      }
      if (triggered) {
        direction = candidate_direction;
        shadow_filtered_values[gid] = direction;
        shadow_filtered_timestamps[gid] = now;
        shadow_filtered_validity[gid] = 1u;
      }
    }
    if (uniforms.correction_enabled != 0u) {
      output_errors[gid] = direction > 0.0f && observed <= 0.0f
        ? 0.0f : direction;
      output_validity[gid] = direction != 0.0f ? 1u : 0u;
    }
    return;
  }
  if (uniforms.sample_timestamp_microseconds
      < ulong(config.delay_microseconds)) return;
  const ulong target_timestamp = uniforms.sample_timestamp_microseconds
    - ulong(config.delay_microseconds);
  float delayed = 0.0f;
  bool delayed_valid = false;
  for (uint slot = 0u; slot < capacity; ++slot) {
    const uint index = base + slot;
    if (shadow_validity[index] != 0u
        && shadow_timestamps[index] == target_timestamp) {
      delayed = shadow_values[index];
      delayed_valid = isfinite(delayed);
      break;
    }
  }
  if (!delayed_valid) return;

  float filtered = delayed;
  const float tau = config.filter_time_constant_seconds;
  const bool filter_was_ready = committed_filtered_validity[gid] != 0u;
  if (!isfinite(tau) || tau < 0.0f) return;
  if (tau > 0.0f && filter_was_ready) {
    const ulong prior_timestamp = committed_filtered_timestamps[gid];
    const float prior = committed_filtered_values[gid];
    if (!isfinite(prior)
        || prior_timestamp >= uniforms.sample_timestamp_microseconds) return;
    const float dt = float(
      uniforms.sample_timestamp_microseconds - prior_timestamp) * 0.000001f;
    const float alpha = 1.0f - exp(-dt / tau);
    filtered = fma(alpha, delayed - prior, prior);
  }
  if (!isfinite(filtered)) return;

  shadow_filtered_values[gid] = filtered;
  shadow_filtered_timestamps[gid] = uniforms.sample_timestamp_microseconds;
  shadow_filtered_validity[gid] = 1u;
  const bool filter_output_ready = tau == 0.0f || filter_was_ready;
  if (uniforms.correction_enabled != 0u && filter_output_ready) {
    output_errors[gid] = filtered;
    output_validity[gid] = 1u;
  }
}

// Routes source errors through a canonical per-muscle sparse range. All
// declared sources are routed by admission, so one missing physical source
// holds the prepared baseline for every muscle at this root. Each route is
// independently bounded and the final correction cannot exceed 0.5.
kernel void nb_muscle_balance_routes(
  device const float *source_errors [[buffer(0)]],
  device const uint *source_validity [[buffer(1)]],
  device const NBMuscleBalanceRoute *routes [[buffer(2)]],
  device const NBMuscleBalanceRange *ranges [[buffer(3)]],
  device float *corrections [[buffer(4)]],
  constant uint4 &uniforms [[buffer(5)]],
  uint gid [[thread_position_in_grid]]) {
  if (gid >= uniforms.y) return;
  if (uniforms.z == 0u) {
    corrections[gid] = 0.0f;
    return;
  }
  if (uniforms.x == 0u || uniforms.x > 64u) {
    corrections[gid] = 0.0f;
    return;
  }
  for (uint source = 0u; source < uniforms.x; ++source) {
    if (source_validity[source] == 0u || !isfinite(source_errors[source])) {
      corrections[gid] = 0.0f;
      return;
    }
  }
  const auto range = ranges[gid];
  if (range.route_start > uniforms.w
      || range.route_count > uniforms.w - range.route_start) {
    corrections[gid] = 0.0f;
    return;
  }
  float correction = 0.0f;
  for (uint index = 0u; index < range.route_count; ++index) {
    const auto route = routes[range.route_start + index];
    if (route.source_index >= uniforms.x
        || source_validity[route.source_index] == 0u) continue;
    const float contribution = clamp(
      route.gain * source_errors[route.source_index],
      -route.maximum_correction,
      route.maximum_correction);
    if (isfinite(contribution)) correction += contribution;
  }
  corrections[gid] = isfinite(correction)
    ? clamp(correction, -0.5f, 0.5f) : 0.0f;
}

// The correction is combined with the original prepared/spindle command before
// the existing decision, inhibition, and protective motor path.
kernel void nb_muscle_locomotor_balanced(
  device const float *spindles [[buffer(0)]],
  device const uint *validity [[buffer(1)]],
  device const NBMuscleLocomotorChannel *channels [[buffer(2)]],
  device float *logits [[buffer(3)]],
  constant uint4 &uniforms [[buffer(4)]],
  device const float *corrections [[buffer(5)]],
  uint gid [[thread_position_in_grid]]) {
  if (gid >= uniforms.x) return;
  const auto c = channels[gid];
  float length = 0.0f, velocity = 0.0f;
  if (!nb_muscle_locomotor_inputs(
      spindles, validity, c, length, velocity)) {
    logits[gid] = 0.0f;
    return;
  }
  logits[gid] = nb_muscle_locomotor_logit(
    c, length, velocity, as_type<float>(uniforms.y), corrections[gid]);
}

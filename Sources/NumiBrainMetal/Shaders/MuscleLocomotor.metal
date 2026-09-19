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

// Reads only the exact body-receptor rows named by the immutable feedback
// program. Invalid receptor evidence produces no correction and is never
// interpreted as a measured zero error.
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
  if (uniforms.z == 0u) return;

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

// Routes source errors through a canonical per-muscle sparse range. Each route
// is independently bounded and the final correction cannot exceed 0.5.
kernel void nb_muscle_balance_routes(
  device const float *source_errors [[buffer(0)]],
  device const uint *source_validity [[buffer(1)]],
  device const NBMuscleBalanceRoute *routes [[buffer(2)]],
  device const NBMuscleBalanceRange *ranges [[buffer(3)]],
  device float *corrections [[buffer(4)]],
  constant uint4 &uniforms [[buffer(5)]],
  uint gid [[thread_position_in_grid]]) {
  if (gid >= uniforms.y) return;
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

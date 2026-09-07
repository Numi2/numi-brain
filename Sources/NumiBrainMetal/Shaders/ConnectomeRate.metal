#include <metal_stdlib>
using namespace metal;
// Mirrors NumiBrainConnectomeABI.h; no float3 or implicit SIMD padding.
struct NBCNSNode {
  float alpha, bias, recurrent_gain, sensory_gain;
  float output_gain, legacy_clip, homeostatic_target, reserved;
  uint identity_low, identity_high, flags, class_hash;
};
struct NBCNSInput {
  uint node, scalar, receptor, reserved;
  float weight, scale, bias, clip;
};
struct NBCNSReadout { uint node, channel; float weight; uint reserved; };
struct NBCNSDispatch {
  uint nodes, inputs, readouts, channels;
  uint step_count, reserved0, reserved1, reserved2;
  float time_ratio, output_clip, reserved3, reserved4;
};


// Metal does not expose log1p/expm1. Fifth-order expansions avoid cancellation
// for small positive alpha and small negative exponent; outside that interval
// ordinary log/exp are well conditioned for the bounded model timestep.
inline float nb_cns_time_alpha(float alpha, float ratio) {
  if (alpha == 1.0f) return 1.0f;
  const float log_decay = alpha < 0.01f
    ? -alpha * (1.0f + alpha * (0.5f + alpha * (1.0f/3.0f + alpha * (0.25f + alpha/5.0f))))
    : log(1.0f-alpha);
  const float exponent = log_decay * ratio;
  return abs(exponent) < 0.01f
    ? -exponent * (1.0f + exponent * (0.5f + exponent * (1.0f/6.0f + exponent * (1.0f/24.0f + exponent/120.0f))))
    : 1.0f-exp(exponent);
}

kernel void nb_connectome_rate_step(
  device const NBCNSNode *nodes [[buffer(0)]],
  device const uint *offsets [[buffer(1)]],
  device const uint *sources [[buffer(2)]],
  device const float *weights [[buffer(3)]],
  device const uint *inputOffsets [[buffer(4)]],
  device const NBCNSInput *inputs [[buffer(5)]],
  device const float *observations [[buffer(6)]],
  device const uint *validity [[buffer(7)]],
  device const float *previous [[buffer(8)]],
  device float *next [[buffer(9)]],
  constant NBCNSDispatch &u [[buffer(10)]],
  uint i [[thread_position_in_grid]]) {
  if (i >= u.nodes) return;
  const NBCNSNode node = nodes[i];
  float recurrent = 0.0f, sensory = 0.0f;
  for (uint e = offsets[i]; e < offsets[i+1]; ++e)
    recurrent += weights[e] * previous[sources[e]];
  for (uint k = inputOffsets[i]; k < inputOffsets[i+1]; ++k) {
    const NBCNSInput p = inputs[k];
    const float value = observations[p.scalar];
    // Explicit missing-measurement policy: invalid/non-finite contributes zero,
    // including its bias. Receptor validity remains available to the owner.
    if (validity[p.scalar] == 0u || !isfinite(value)) continue;
    const float normalized = clamp(value, -p.clip, p.clip) * p.scale + p.bias;
    sensory += p.weight * clamp(normalized, -p.clip, p.clip);
  }
  const float target = tanh(node.bias + node.recurrent_gain*recurrent + node.sensory_gain*sensory);
  // alpha in NUMICNS1 is defined at the explicit nominal physical interval.
  const float alpha = nb_cns_time_alpha(node.alpha, u.time_ratio);
  const float candidate = previous[i] + alpha*(target-previous[i]);
  next[i] = isfinite(candidate) ? clamp(candidate, -1.0f, 1.0f) : NAN;
}

kernel void nb_connectome_descending_readout(
  device const NBCNSNode *nodes [[buffer(0)]],
  device const uint *offsets [[buffer(1)]],
  device const NBCNSReadout *readouts [[buffer(2)]],
  device const float *state [[buffer(3)]],
  device float *output [[buffer(4)]],
  constant NBCNSDispatch &u [[buffer(10)]],
  uint channel [[thread_position_in_grid]]) {
  if (channel >= u.channels) return;
  float value = 0.0f;
  for (uint k=offsets[channel]; k<offsets[channel+1]; ++k) {
    const NBCNSReadout r = readouts[k];
    value += r.weight * nodes[r.node].output_gain * state[r.node];
  }
  output[channel] = isfinite(value) ? clamp(value, -u.output_clip, u.output_clip) : NAN;
}

struct NBCNSDecoderDispatch {
  uint channels, actuators, command_kind, reserved;
  float delta_seconds, maximum_drive_change_per_second, reserved1, reserved2;
};
static_assert(sizeof(NBCNSNode) == 48);
static_assert(sizeof(NBCNSInput) == 32);
static_assert(sizeof(NBCNSDispatch) == 48);
static_assert(sizeof(NBCNSDecoderDispatch) == 32);

kernel void nb_connectome_motor_decode(
  device const float *features [[buffer(0)]],
  device const float *weights [[buffer(1)]],
  device const float *bias [[buffer(2)]],
  device const float4 *previous [[buffer(3)]],
  device float4 *control [[buffer(4)]],
  constant NBCNSDecoderDispatch &u [[buffer(5)]],
  uint actuator [[thread_position_in_grid]]) {
  if (actuator >= u.actuators) return;
  float logit = bias[actuator];
  bool valid = isfinite(logit);
  for (uint c = 0; c < u.channels; ++c) {
    valid = valid && isfinite(features[c]);
    logit += weights[actuator*u.channels+c]*features[c];
  }
  const bool muscle = u.command_kind == 1u;
  const float neutral = muscle ? 0.0f : 0.5f;
  valid = valid && isfinite(logit);
  if (!valid) { control[actuator] = float4(neutral, 0.0f, 0.0f, 0.0f); return; }
  const float signed_drive = tanh(logit);
  const float requested = muscle ? max(signed_drive, 0.0f) : 0.5f*(signed_drive+1.0f);
  const float4 old = previous[actuator];
  const float base = old.y == 1.0f && isfinite(old.x) ? clamp(old.x,0.0f,1.0f) : neutral;
  const float change = u.maximum_drive_change_per_second*u.delta_seconds;
  control[actuator] = float4(clamp(requested, max(0.0f,base-change), min(1.0f,base+change)),
    1.0f, logit, 0.0f);
}

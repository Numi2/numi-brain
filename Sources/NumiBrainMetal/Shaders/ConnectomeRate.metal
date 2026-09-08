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

// Algebraically 1-(1-alpha)^ratio. Direct subtraction rounds valid slow
// dynamics to zero when either alpha or the physical time ratio is small.
// Sixth-order Taylor branches avoid cancellation without requiring optional
// math intrinsics; their omitted terms are below FP32 roundoff at 1/16.
inline float nb_connectome_physical_alpha(float alpha, float ratio) {
  if (ratio == 1.0f) return alpha;
  if (alpha == 1.0f) return 1.0f;
  const float decay = alpha < 0.0625f
    ? alpha * (1.0f + alpha * (0.5f + alpha * (1.0f/3.0f
      + alpha * (0.25f + alpha * (0.2f + alpha/6.0f)))))
    : -log(1.0f-alpha);
  const float x = decay * ratio;
  const float result = x < 0.0625f
    ? x * (1.0f + x * (-0.5f + x * (1.0f/6.0f
      + x * (-1.0f/24.0f + x * (1.0f/120.0f-x/720.0f)))))
    : 1.0f-exp(-x);
  return clamp(result, 0.0f, 1.0f);
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
  const float alpha = nb_connectome_physical_alpha(node.alpha, u.time_ratio);
  next[i] = clamp(previous[i] + alpha*(target-previous[i]), -1.0f, 1.0f);
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
  output[channel] = clamp(value, -u.output_clip, u.output_clip);
}

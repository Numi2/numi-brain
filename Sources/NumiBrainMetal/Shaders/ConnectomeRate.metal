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
  const float alpha = node.alpha == 1.0f ? 1.0f : 1.0f - pow(1.0f-node.alpha, u.time_ratio);
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

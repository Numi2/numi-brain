#include <metal_stdlib>
using namespace metal;
struct NBMuscleLocomotorChannel {
  uint length_index, velocity_index, receptor_index, required_validity;
  float reference_length, tonic, length_gain, velocity_gain;
  float gait_sine, gait_cosine, maximum_excitation, padding;
};
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
  const float length = spindles[c.length_index], velocity = spindles[c.velocity_index];
  if ((validity[c.receptor_index] & c.required_validity) != c.required_validity || !isfinite(length) || length <= 0.0f || !isfinite(velocity)) {
    logits[gid] = 0.0f; return;
  }
  const float phase = as_type<float>(uniforms.y);
  const float feedback = c.length_gain * (length / c.reference_length - 1.0f)
    + c.velocity_gain * velocity / c.reference_length;
  const float gait = c.gait_sine * sin(phase) + c.gait_cosine * cos(phase);
  if (!isfinite(feedback) || !isfinite(gait)) { logits[gid] = 0.0f; return; }
  const float excitation = clamp(c.tonic + feedback + gait, 0.0f, c.maximum_excitation);
  // The common decision kernel converts positive logits with tanh, then
  // applies ordinary inhibition and the private protective motor adapter.
  logits[gid] = atanh(excitation);
}

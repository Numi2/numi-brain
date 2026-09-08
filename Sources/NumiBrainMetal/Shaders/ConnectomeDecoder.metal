#include <metal_stdlib>
using namespace metal;
struct NBCNSDecoder { uint channels, actuators; float maximum_logit; uint reserved; };
kernel void nb_connectome_decode_motor(
  device const float *descending [[buffer(0)]],
  device const float *weights [[buffer(1)]],
  device const float *biases [[buffer(2)]],
  device float *logits [[buffer(3)]],
  constant NBCNSDecoder &u [[buffer(4)]], uint actuator [[thread_position_in_grid]]) {
  if (actuator >= u.actuators) return;
  float value = biases[actuator];
  for (uint j = 0; j < u.channels; ++j) value += weights[actuator*u.channels+j] * descending[j];
  logits[actuator] = clamp(value, -u.maximum_logit, u.maximum_logit);
}

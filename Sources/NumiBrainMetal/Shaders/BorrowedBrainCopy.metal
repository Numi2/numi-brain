#include <metal_stdlib>
using namespace metal;

// Transport only: ordinary compute encoders cannot append a blit operation.
// All neural and protective arithmetic remains in the existing kernels.
kernel void borrowed_brain_copy_bytes(device const uchar *source [[buffer(0)]],
    device uchar *destination [[buffer(1)]], constant uint &byteCount [[buffer(2)]],
    uint index [[thread_position_in_grid]]) {
    if (index < byteCount) destination[index] = source[index];
}

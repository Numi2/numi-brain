#include <metal_stdlib>
using namespace metal;

enum TissueUniformIndex : uint {
    TissueWidth = 0,
    TissueHeight = 1,
    TissueTimestepMilliseconds = 2,
    TissueTimeMilliseconds = 3,
    TissueExcitatoryTimeConstant = 4,
    TissueInhibitoryTimeConstant = 5,
    TissueAdaptationTimeConstant = 6,
    TissueExcitatorySelfWeight = 8,
    TissueInhibitoryToExcitatoryWeight = 9,
    TissueExcitatoryToInhibitoryWeight = 10,
    TissueInhibitorySelfWeight = 11,
    TissueExcitatorySpatialMix = 12,
    TissueInhibitorySpatialMix = 13,
    TissueAdaptationStrength = 14,
    TissueExcitatoryBias = 16,
    TissueInhibitoryBias = 17,
    TissueExcitatoryGain = 18,
    TissueInhibitoryGain = 19,
    TissueStimulusCenterX = 20,
    TissueStimulusCenterY = 21,
    TissueStimulusRadius = 22,
    TissueStimulusExcitatoryDrive = 23,
    TissueStimulusInhibitoryDrive = 24,
    TissueStimulusStartMilliseconds = 25,
    TissueStimulusEndMilliseconds = 26,
};

inline float tissue_sigmoid(float value) {
    return 1.0f / (1.0f + exp(-value));
}

kernel void neural_tissue_step(
    device const float4 *input [[buffer(0)]],
    device float4 *output [[buffer(1)]],
    constant float *uniforms [[buffer(2)]],
    uint2 position [[thread_position_in_grid]]
) {
    const uint width = uint(uniforms[TissueWidth]);
    const uint height = uint(uniforms[TissueHeight]);
    if (position.x >= width || position.y >= height) {
        return;
    }

    const uint x = position.x;
    const uint y = position.y;
    const uint left = x == 0 ? 0 : x - 1;
    const uint right = min(x + 1, width - 1);
    const uint up = y == 0 ? 0 : y - 1;
    const uint down = min(y + 1, height - 1);
    const uint index = y * width + x;

    const float4 center = input[index];
    const float4 north = input[up * width + x];
    const float4 south = input[down * width + x];
    const float4 west = input[y * width + left];
    const float4 east = input[y * width + right];
    const float neighborE = 0.25f * (north.x + south.x + west.x + east.x);
    const float neighborI = 0.25f * (north.y + south.y + west.y + east.y);
    const float spatialE = center.x
        + uniforms[TissueExcitatorySpatialMix] * (neighborE - center.x);
    const float spatialI = center.y
        + uniforms[TissueInhibitorySpatialMix] * (neighborI - center.y);

    float stimulusE = 0.0f;
    float stimulusI = 0.0f;
    const float time = uniforms[TissueTimeMilliseconds];
    const float radius = uniforms[TissueStimulusRadius];
    if (time >= uniforms[TissueStimulusStartMilliseconds]
        && time < uniforms[TissueStimulusEndMilliseconds]
        && radius > 0.0f) {
        const float widthScale = float(max(width - 1, 1u));
        const float heightScale = float(max(height - 1, 1u));
        const float dx = float(x) / widthScale - uniforms[TissueStimulusCenterX];
        const float dy = float(y) / heightScale - uniforms[TissueStimulusCenterY];
        if (dx * dx + dy * dy <= radius * radius) {
            stimulusE = uniforms[TissueStimulusExcitatoryDrive];
            stimulusI = uniforms[TissueStimulusInhibitoryDrive];
        }
    }

    const float targetE = tissue_sigmoid(
        uniforms[TissueExcitatoryGain] * (
            uniforms[TissueExcitatorySelfWeight] * spatialE
            - uniforms[TissueInhibitoryToExcitatoryWeight] * center.y
            - uniforms[TissueAdaptationStrength] * center.z
            + uniforms[TissueExcitatoryBias]
            + stimulusE
        )
    );
    const float targetI = tissue_sigmoid(
        uniforms[TissueInhibitoryGain] * (
            uniforms[TissueExcitatoryToInhibitoryWeight] * spatialE
            - uniforms[TissueInhibitorySelfWeight] * spatialI
            + uniforms[TissueInhibitoryBias]
            + stimulusI
        )
    );
    const float dt = uniforms[TissueTimestepMilliseconds];
    const float nextE = clamp(
        center.x + dt / uniforms[TissueExcitatoryTimeConstant] * (targetE - center.x),
        0.0f,
        1.0f
    );
    const float nextI = clamp(
        center.y + dt / uniforms[TissueInhibitoryTimeConstant] * (targetI - center.y),
        0.0f,
        1.0f
    );
    const float nextA = clamp(
        center.z + dt / uniforms[TissueAdaptationTimeConstant] * (center.x - center.z),
        0.0f,
        1.0f
    );
    output[index] = float4(nextE, nextI, nextA, 0.0f);
}

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
    TissueAxonalRelayTimeConstant = 7,
    TissueExcitatorySelfWeight = 8,
    TissueInhibitoryToExcitatoryWeight = 9,
    TissueExcitatoryToInhibitoryWeight = 10,
    TissueInhibitorySelfWeight = 11,
    TissueExcitatorySpatialMix = 12,
    TissueInhibitorySpatialMix = 13,
    TissueAdaptationStrength = 14,
    TissueLongRangeProjectionGain = 15,
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
    TissueHistoryStep = 27,
    TissueHistoryCapacity = 28,
    TissueHistoryOwnerMask = 29,
    TissueHistoryWriteSlot = 30,
    TissueHistoryWritePlane = 31,
    TissueEventCount = 32,
    TissueRandomSeed = 33,
    TissueRandomEnvironmentIdentifier = 34,
    TissueRandomEpisodeIdentifier = 35,
    TissueRandomModuleIdentifier = 36,
    TissueAcceptedStepLow = 37,
    TissueAcceptedStepHigh = 38,
};

inline float tissue_sigmoid(float value) {
    return 1.0f / (1.0f + exp(-value));
}

inline float tissue_delayed_relay(
    device const uchar *delaySteps,
    device const float *relayHistory,
    uint siteIndex,
    uint siteCount,
    uint historyStep,
    uint historyCapacity,
    uint historyOwnerMask
) {
    const uint delay = uint(delaySteps[siteIndex]);
    const uint slot = (historyStep + historyCapacity - delay) % historyCapacity;
    const uint plane = (historyOwnerMask >> slot) & 1u;
    const uint historyIndex = (plane * historyCapacity + slot) * siteCount + siteIndex;
    return relayHistory[historyIndex];
}

inline float tissue_relay_at_delay(
    device const float *relayHistory,
    uint siteIndex,
    uint delay,
    uint siteCount,
    uint historyStep,
    uint historyCapacity,
    uint historyOwnerMask
) {
    const uint slot = (historyStep + historyCapacity - delay) % historyCapacity;
    const uint plane = (historyOwnerMask >> slot) & 1u;
    const uint historyIndex = (plane * historyCapacity + slot) * siteCount + siteIndex;
    return relayHistory[historyIndex];
}

inline void tissue_random_combine(thread uint &state, uint value) {
    state += value * 0x9e3779b9u;
    state ^= state >> 16;
    state *= 0x7feb352du;
    state ^= state >> 15;
    state *= 0x846ca68bu;
    state ^= state >> 16;
}

inline uint tissue_random_bits(
    uint seed,
    uint environmentIdentifier,
    uint episodeIdentifier,
    uint moduleIdentifier,
    uint acceptedStepLow,
    uint acceptedStepHigh,
    uint eventIdentifier,
    uint siteIndex,
    uint sampleIndex
) {
    uint state = seed ^ 0xa511e9b3u;
    tissue_random_combine(state, environmentIdentifier);
    tissue_random_combine(state, episodeIdentifier);
    tissue_random_combine(state, moduleIdentifier);
    tissue_random_combine(state, acceptedStepLow);
    tissue_random_combine(state, acceptedStepHigh);
    tissue_random_combine(state, eventIdentifier);
    tissue_random_combine(state, siteIndex);
    tissue_random_combine(state, sampleIndex);
    return state;
}

inline float tissue_random_symmetric_unit(
    uint seed,
    uint environmentIdentifier,
    uint episodeIdentifier,
    uint moduleIdentifier,
    uint acceptedStepLow,
    uint acceptedStepHigh,
    uint eventIdentifier,
    uint siteIndex,
    uint sampleIndex
) {
    const uint bits = tissue_random_bits(
        seed,
        environmentIdentifier,
        episodeIdentifier,
        moduleIdentifier,
        acceptedStepLow,
        acceptedStepHigh,
        eventIdentifier,
        siteIndex,
        sampleIndex
    );
    const float uniform = float(bits >> 8) * (1.0f / 16777216.0f);
    return 2.0f * uniform - 1.0f;
}

kernel void neural_tissue_step(
    device const float4 *input [[buffer(0)]],
    device float4 *output [[buffer(1)]],
    constant float *uniforms [[buffer(2)]],
    device const float4 *structure [[buffer(3)]],
    device const uchar *delaySteps [[buffer(4)]],
    device float *relayHistory [[buffer(5)]],
    device float *relayScratch [[buffer(6)]],
    device const uint *projectionOffsets [[buffer(7)]],
    device const uint4 *projectionEdges [[buffer(8)]],
    device const float4 *receptorEvents [[buffer(9)]],
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
    const uint siteCount = width * height;
    const uint historyStep = uint(uniforms[TissueHistoryStep]);
    const uint historyCapacity = uint(uniforms[TissueHistoryCapacity]);
    const uint historyOwnerMask = as_type<uint>(uniforms[TissueHistoryOwnerMask]);

    const float4 center = input[index];
    const float4 north = input[up * width + x];
    const float4 south = input[down * width + x];
    const float4 west = input[y * width + left];
    const float4 east = input[y * width + right];
    const float4 centerSite = structure[index];
    const float4 northSite = structure[up * width + x];
    const float4 southSite = structure[down * width + x];
    const float4 westSite = structure[y * width + left];
    const float4 eastSite = structure[y * width + right];
    const float northRelay = tissue_delayed_relay(
        delaySteps,
        relayHistory,
        up * width + x,
        siteCount,
        historyStep,
        historyCapacity,
        historyOwnerMask
    );
    const float southRelay = tissue_delayed_relay(
        delaySteps,
        relayHistory,
        down * width + x,
        siteCount,
        historyStep,
        historyCapacity,
        historyOwnerMask
    );
    const float westRelay = tissue_delayed_relay(
        delaySteps,
        relayHistory,
        y * width + left,
        siteCount,
        historyStep,
        historyCapacity,
        historyOwnerMask
    );
    const float eastRelay = tissue_delayed_relay(
        delaySteps,
        relayHistory,
        y * width + right,
        siteCount,
        historyStep,
        historyCapacity,
        historyOwnerMask
    );
    const float neighborRelay = 0.25f * (
        northRelay * northSite.z * northSite.w
        + southRelay * southSite.z * southSite.w
        + westRelay * westSite.z * westSite.w
        + eastRelay * eastSite.z * eastSite.w
    );
    const float neighborI = 0.25f * (
        north.y * northSite.z * northSite.w
        + south.y * southSite.z * southSite.w
        + west.y * westSite.z * westSite.w
        + east.y * eastSite.z * eastSite.w
    );
    const float spatialE = center.x
        + uniforms[TissueExcitatorySpatialMix] * (neighborRelay - center.x);
    const float spatialI = center.y
        + uniforms[TissueInhibitorySpatialMix] * (neighborI - center.y);
    float projectionDrive = 0.0f;
    const uint projectionStart = projectionOffsets[index];
    const uint projectionEnd = projectionOffsets[index + 1];
    for (uint edgeIndex = projectionStart; edgeIndex < projectionEnd; ++edgeIndex) {
        const uint4 edge = projectionEdges[edgeIndex];
        const float sourceRelay = tissue_relay_at_delay(
            relayHistory,
            edge.x,
            edge.y,
            siteCount,
            historyStep,
            historyCapacity,
            historyOwnerMask
        );
        projectionDrive += as_type<float>(edge.z) * sourceRelay;
    }

    float stimulusE = 0.0f;
    float stimulusI = 0.0f;
    const float time = uniforms[TissueTimeMilliseconds];
    const float normalizedX = float(x) / float(max(width - 1, 1u));
    const float normalizedY = float(y) / float(max(height - 1, 1u));
    const uint eventCount = uint(uniforms[TissueEventCount]);
    const uint randomSeed = as_type<uint>(uniforms[TissueRandomSeed]);
    const uint randomEnvironment = as_type<uint>(
        uniforms[TissueRandomEnvironmentIdentifier]
    );
    const uint randomEpisode = as_type<uint>(uniforms[TissueRandomEpisodeIdentifier]);
    const uint randomModule = as_type<uint>(uniforms[TissueRandomModuleIdentifier]);
    const uint acceptedStepLow = as_type<uint>(uniforms[TissueAcceptedStepLow]);
    const uint acceptedStepHigh = as_type<uint>(uniforms[TissueAcceptedStepHigh]);
    for (uint eventIndex = 0; eventIndex < eventCount; ++eventIndex) {
        const float4 geometryAndStart = receptorEvents[eventIndex * 3];
        const float4 endDriveAndNoise = receptorEvents[eventIndex * 3 + 1];
        const float4 metadata = receptorEvents[eventIndex * 3 + 2];
        const float radius = geometryAndStart.z;
        if (time < geometryAndStart.w
            || time >= endDriveAndNoise.x
            || radius <= 0.0f) {
            continue;
        }
        const float dx = normalizedX - geometryAndStart.x;
        const float dy = normalizedY - geometryAndStart.y;
        if (dx * dx + dy * dy > radius * radius) {
            continue;
        }
        const uint eventIdentifier = as_type<uint>(metadata.x);
        const float noiseAmplitude = endDriveAndNoise.w;
        const float excitatoryNoise = noiseAmplitude * tissue_random_symmetric_unit(
            randomSeed,
            randomEnvironment,
            randomEpisode,
            randomModule,
            acceptedStepLow,
            acceptedStepHigh,
            eventIdentifier,
            index,
            0u
        );
        const float inhibitoryNoise = noiseAmplitude * tissue_random_symmetric_unit(
            randomSeed,
            randomEnvironment,
            randomEpisode,
            randomModule,
            acceptedStepLow,
            acceptedStepHigh,
            eventIdentifier,
            index,
            1u
        );
        stimulusE += endDriveAndNoise.y + excitatoryNoise;
        stimulusI += endDriveAndNoise.z + inhibitoryNoise;
    }

    const float targetE = tissue_sigmoid(
        uniforms[TissueExcitatoryGain] * centerSite.x * (
            uniforms[TissueExcitatorySelfWeight] * spatialE
            - uniforms[TissueInhibitoryToExcitatoryWeight] * center.y
            - uniforms[TissueAdaptationStrength] * center.z
            + uniforms[TissueExcitatoryBias]
            + stimulusE
        )
        + uniforms[TissueLongRangeProjectionGain] * projectionDrive
    );
    const float targetI = tissue_sigmoid(
        uniforms[TissueInhibitoryGain] * centerSite.y * (
            uniforms[TissueExcitatoryToInhibitoryWeight] * spatialE
            - uniforms[TissueInhibitorySelfWeight] * spatialI
            + uniforms[TissueInhibitoryBias]
            + stimulusI
        )
    );
    const float dt = uniforms[TissueTimestepMilliseconds];
    const float nextE = clamp(
        center.x + dt / uniforms[TissueExcitatoryTimeConstant]
            * (centerSite.w * targetE - center.x),
        0.0f,
        1.0f
    );
    const float nextI = clamp(
        center.y + dt / uniforms[TissueInhibitoryTimeConstant]
            * (centerSite.w * targetI - center.y),
        0.0f,
        1.0f
    );
    const float nextA = clamp(
        center.z + dt / uniforms[TissueAdaptationTimeConstant] * (center.x - center.z),
        0.0f,
        1.0f
    );
    const float nextRelay = clamp(
        center.w + dt / uniforms[TissueAxonalRelayTimeConstant] * (center.x - center.w),
        0.0f,
        1.0f
    );
    output[index] = float4(nextE, nextI, nextA, nextRelay);
    const uint historyWriteSlot = uint(uniforms[TissueHistoryWriteSlot]);
    const uint historyWritePlane = uint(uniforms[TissueHistoryWritePlane]);
    if (historyWritePlane < 2u) {
        const uint historyWriteIndex =
            (historyWritePlane * historyCapacity + historyWriteSlot) * siteCount + index;
        relayHistory[historyWriteIndex] = nextRelay;
    } else {
        relayScratch[index] = nextRelay;
    }
}

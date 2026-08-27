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

/// Compacts temporally due receptor events into canonical schedule order.
/// One deterministic GPU lane is sufficient for the bounded v0 schedule;
/// larger cohort queues will replace this with a prefix-sum implementation.
kernel void compact_receptor_events(
    constant float *uniforms [[buffer(0)]],
    device const float4 *receptorEvents [[buffer(1)]],
    device uint *activeEventIndices [[buffer(2)]],
    uint threadIndex [[thread_position_in_grid]]
) {
    if (threadIndex != 0u) {
        return;
    }
    const uint eventCount = uint(uniforms[TissueEventCount]);
    const float time = uniforms[TissueTimeMilliseconds];
    uint activeCount = 0u;
    for (uint eventIndex = 0u; eventIndex < eventCount; ++eventIndex) {
        const float4 geometryAndStart = receptorEvents[eventIndex * 3u];
        const float4 endDriveAndNoise = receptorEvents[eventIndex * 3u + 1u];
        if (geometryAndStart.z > 0.0f
            && time >= geometryAndStart.w
            && time < endDriveAndNoise.x) {
            activeEventIndices[activeCount + 1u] = eventIndex;
            activeCount += 1u;
        }
    }
    activeEventIndices[0] = activeCount;
}

struct NBModuleDescriptorABI {
    ushort module_id;
    ushort clock_class;
    uint period_microseconds;
    uint conduction_delay_microseconds;
    uint intrinsic_timescale_microseconds;
    ulong interrupt_mask;
    ushort token_count;
    ushort token_dimension;
    uint flags;
};

struct NBModuleClockStateABI {
    ulong next_due_microseconds;
    ulong last_update_microseconds;
};

struct NBInterruptEventABI {
    ulong timestamp_microseconds;
    ulong interrupt_mask;
    uint identifier;
    uint flags;
};

struct NBDueInvocationABI {
    ulong timestamp_microseconds;
    ulong interrupt_mask;
    uint environment_identifier;
    ushort module_id;
    ushort clock_class;
    uint reason_flags;
    uint reserved;
};

struct NBSchedulerUniformsABI {
    ulong committed_time_microseconds;
    ulong target_time_microseconds;
    uint module_count;
    uint event_count;
    uint invocation_capacity;
    uint environment_identifier;
    uint flags;
    uint reserved;
};

struct NBSchedulerResultABI {
    uint invocation_count;
    uint status;
    ulong target_time_microseconds;
};

struct NBRegionalModuleStateABI {
    float activation;
    float integration;
    float interrupt_salience;
    float phase;
    uint update_count;
    uint interrupt_count;
    ulong last_update_microseconds;
};

struct NBRegionalTokenLayoutABI {
    uint scalar_offset;
    uint scalar_count;
    uint parameter_offset;
    uint incoming_route_offset;
    ushort module_id;
    ushort token_count;
    ushort token_dimension;
    ushort incoming_route_count;
    uint flags;
    uint reserved;
};

struct NBRegionalRouteABI {
    ushort sender_module_id;
    ushort receiver_module_id;
    ushort sender_token;
    ushort flags;
    uint delay_microseconds;
    float gain;
    uint reserved0;
    uint reserved1;
};

struct NBRegionalTokenParametersABI {
    float recurrent_gain;
    float local_gain;
    float route_gain;
    float drive_gain;
    float bias;
    float gate_bias;
    float gate_recurrent_gain;
    float gate_input_gain;
};

struct NBRegionalProgramHeaderABI {
    uint module_count;
    uint token_scalar_count;
    uint route_count;
    uint parameter_count;
    ulong program_fingerprint;
    uint flags;
    uint reserved;
};

static_assert(sizeof(NBModuleDescriptorABI) == 32, "module descriptor ABI drift");
static_assert(sizeof(NBModuleClockStateABI) == 16, "module clock ABI drift");
static_assert(sizeof(NBInterruptEventABI) == 24, "interrupt event ABI drift");
static_assert(sizeof(NBDueInvocationABI) == 32, "due invocation ABI drift");
static_assert(sizeof(NBSchedulerUniformsABI) == 40, "scheduler uniform ABI drift");
static_assert(sizeof(NBSchedulerResultABI) == 16, "scheduler result ABI drift");
static_assert(sizeof(NBRegionalModuleStateABI) == 32, "regional state ABI drift");
static_assert(sizeof(NBRegionalTokenLayoutABI) == 32, "regional layout ABI drift");
static_assert(sizeof(NBRegionalRouteABI) == 24, "regional route ABI drift");
static_assert(sizeof(NBRegionalTokenParametersABI) == 32, "regional parameter ABI drift");
static_assert(sizeof(NBRegionalProgramHeaderABI) == 32, "regional header ABI drift");

constant uint NBSchedulerFlagInitialize = 1u << 0;
constant uint NBSchedulerReasonPeriodic = 1u << 0;
constant uint NBSchedulerReasonInterrupt = 1u << 1;
constant uint NBSchedulerStatusValid = 0u;
constant uint NBSchedulerStatusInvocationCapacity = 1u;
constant uint NBSchedulerStatusTimeOverflow = 2u;

inline bool scheduler_invocation_less(
    thread const NBDueInvocationABI &lhs,
    thread const NBDueInvocationABI &rhs
) {
    if (lhs.timestamp_microseconds != rhs.timestamp_microseconds) {
        return lhs.timestamp_microseconds < rhs.timestamp_microseconds;
    }
    if (lhs.clock_class != rhs.clock_class) {
        return lhs.clock_class < rhs.clock_class;
    }
    return lhs.module_id < rhs.module_id;
}

/// Deterministic one-agent reference kernel. It consumes the compiled v1 ABI,
/// advances private shadow clocks, and compacts periodic/event invocations.
/// Later cohort kernels will assign one lane per agent and prefix-sum groups.
kernel void schedule_due_modules(
    constant NBSchedulerUniformsABI *uniforms [[buffer(0)]],
    device const NBModuleDescriptorABI *modules [[buffer(1)]],
    device const NBModuleClockStateABI *inputClocks [[buffer(2)]],
    device NBModuleClockStateABI *outputClocks [[buffer(3)]],
    device const NBInterruptEventABI *events [[buffer(4)]],
    device NBDueInvocationABI *invocations [[buffer(5)]],
    device NBSchedulerResultABI *result [[buffer(6)]],
    uint threadIndex [[thread_position_in_grid]]
) {
    if (threadIndex != 0u) {
        return;
    }

    const ulong neverUpdated = ~0ul;
    const bool initialize = (uniforms->flags & NBSchedulerFlagInitialize) != 0u;
    uint invocationCount = 0u;
    result->invocation_count = 0u;
    result->status = NBSchedulerStatusValid;
    result->target_time_microseconds = uniforms->target_time_microseconds;

    for (uint moduleIndex = 0u; moduleIndex < uniforms->module_count; ++moduleIndex) {
        const NBModuleDescriptorABI module = modules[moduleIndex];
        NBModuleClockStateABI clock = inputClocks[moduleIndex];
        if (initialize) {
            clock.next_due_microseconds = uniforms->committed_time_microseconds;
            clock.last_update_microseconds = neverUpdated;
        }
        ulong nextDue = clock.next_due_microseconds;
        while (nextDue <= uniforms->target_time_microseconds) {
            if (invocationCount >= uniforms->invocation_capacity) {
                result->invocation_count = invocationCount;
                result->status = NBSchedulerStatusInvocationCapacity;
                return;
            }
            NBDueInvocationABI invocation;
            invocation.timestamp_microseconds = nextDue;
            invocation.interrupt_mask = 0ul;
            invocation.environment_identifier = uniforms->environment_identifier;
            invocation.module_id = module.module_id;
            invocation.clock_class = module.clock_class;
            invocation.reason_flags = NBSchedulerReasonPeriodic;
            invocation.reserved = 0u;
            invocations[invocationCount++] = invocation;
            clock.last_update_microseconds = nextDue;
            const ulong period = ulong(module.period_microseconds);
            if (nextDue > (~0ul) - period) {
                result->invocation_count = invocationCount;
                result->status = NBSchedulerStatusTimeOverflow;
                return;
            }
            nextDue += period;
        }
        clock.next_due_microseconds = nextDue;
        outputClocks[moduleIndex] = clock;
    }

    for (uint eventIndex = 0u; eventIndex < uniforms->event_count; ++eventIndex) {
        const NBInterruptEventABI event = events[eventIndex];
        for (uint moduleIndex = 0u; moduleIndex < uniforms->module_count; ++moduleIndex) {
            const NBModuleDescriptorABI module = modules[moduleIndex];
            const ulong deliveredMask = module.interrupt_mask & event.interrupt_mask;
            if (deliveredMask == 0ul) {
                continue;
            }
            bool merged = false;
            for (uint invocationIndex = 0u;
                 invocationIndex < invocationCount;
                 ++invocationIndex) {
                NBDueInvocationABI existing = invocations[invocationIndex];
                if (existing.timestamp_microseconds == event.timestamp_microseconds
                    && existing.module_id == module.module_id) {
                    existing.reason_flags |= NBSchedulerReasonInterrupt;
                    existing.interrupt_mask |= deliveredMask;
                    invocations[invocationIndex] = existing;
                    merged = true;
                    break;
                }
            }
            if (!merged) {
                if (invocationCount >= uniforms->invocation_capacity) {
                    result->invocation_count = invocationCount;
                    result->status = NBSchedulerStatusInvocationCapacity;
                    return;
                }
                NBDueInvocationABI invocation;
                invocation.timestamp_microseconds = event.timestamp_microseconds;
                invocation.interrupt_mask = deliveredMask;
                invocation.environment_identifier = uniforms->environment_identifier;
                invocation.module_id = module.module_id;
                invocation.clock_class = module.clock_class;
                invocation.reason_flags = NBSchedulerReasonInterrupt;
                invocation.reserved = 0u;
                invocations[invocationCount++] = invocation;
            }
            NBModuleClockStateABI clock = outputClocks[moduleIndex];
            if (clock.last_update_microseconds == neverUpdated
                || clock.last_update_microseconds < event.timestamp_microseconds) {
                clock.last_update_microseconds = event.timestamp_microseconds;
                outputClocks[moduleIndex] = clock;
            }
        }
    }

    for (uint index = 1u; index < invocationCount; ++index) {
        const NBDueInvocationABI key = invocations[index];
        uint destination = index;
        while (destination > 0u) {
            const NBDueInvocationABI previous = invocations[destination - 1u];
            if (!scheduler_invocation_less(key, previous)) {
                break;
            }
            invocations[destination] = previous;
            destination -= 1u;
        }
        invocations[destination] = key;
    }

    result->invocation_count = invocationCount;
}

inline uint regional_module_index(
    device const NBRegionalTokenLayoutABI *layouts,
    uint moduleCount,
    ushort moduleID
) {
    for (uint moduleIndex = 0u; moduleIndex < moduleCount; ++moduleIndex) {
        if (layouts[moduleIndex].module_id == moduleID) {
            return moduleIndex;
        }
    }
    return ~0u;
}

inline bool regional_invocation_for_module(
    device const NBDueInvocationABI *invocations,
    uint begin,
    uint end,
    ushort moduleID,
    thread NBDueInvocationABI &result
) {
    for (uint index = begin; index < end; ++index) {
        if (invocations[index].module_id == moduleID) {
            result = invocations[index];
            return true;
        }
    }
    return false;
}

/// Executable factorized recurrent token operator. Exactly one threadgroup owns
/// an agent. All due modules at one timestamp read the same pre-timestamp state,
/// then publish together, preventing route cycles from observing partial peers.
kernel void advance_due_regional_tokens(
    device const NBRegionalProgramHeaderABI *header [[buffer(0)]],
    device const NBModuleDescriptorABI *modules [[buffer(1)]],
    device const NBRegionalTokenLayoutABI *layouts [[buffer(2)]],
    device const NBRegionalRouteABI *routes [[buffer(3)]],
    device const NBRegionalTokenParametersABI *parameters [[buffer(4)]],
    device const NBSchedulerResultABI *schedulerResult [[buffer(5)]],
    device const NBDueInvocationABI *invocations [[buffer(6)]],
    device const NBRegionalModuleStateABI *inputDiagnostics [[buffer(7)]],
    device NBRegionalModuleStateABI *outputDiagnostics [[buffer(8)]],
    device const float *inputTokens [[buffer(9)]],
    device float *outputTokens [[buffer(10)]],
    device float *candidateTokens [[buffer(11)]],
    uint lane [[thread_index_in_threadgroup]],
    uint3 lanesPerThreadgroup [[threads_per_threadgroup]]
) {
    const uint laneCount = lanesPerThreadgroup.x;
    for (uint moduleIndex = lane;
         moduleIndex < header->module_count;
         moduleIndex += laneCount) {
        outputDiagnostics[moduleIndex] = inputDiagnostics[moduleIndex];
    }
    for (uint scalarIndex = lane;
         scalarIndex < header->token_scalar_count;
         scalarIndex += laneCount) {
        outputTokens[scalarIndex] = inputTokens[scalarIndex];
    }
    threadgroup_barrier(mem_flags::mem_device);

    if (schedulerResult->status != NBSchedulerStatusValid) {
        return;
    }

    const ulong neverUpdated = ~0ul;
    uint cursor = 0u;
    while (cursor < schedulerResult->invocation_count) {
        const ulong timestamp = invocations[cursor].timestamp_microseconds;
        uint groupEnd = cursor + 1u;
        while (groupEnd < schedulerResult->invocation_count
               && invocations[groupEnd].timestamp_microseconds == timestamp) {
            groupEnd += 1u;
        }

        for (uint scalarIndex = lane;
             scalarIndex < header->token_scalar_count;
             scalarIndex += laneCount) {
            uint moduleIndex = 0u;
            for (; moduleIndex < header->module_count; ++moduleIndex) {
                const NBRegionalTokenLayoutABI candidateLayout = layouts[moduleIndex];
                if (scalarIndex >= candidateLayout.scalar_offset
                    && scalarIndex < candidateLayout.scalar_offset + candidateLayout.scalar_count) {
                    break;
                }
            }
            const NBRegionalTokenLayoutABI layout = layouts[moduleIndex];
            NBDueInvocationABI invocation;
            const bool due = regional_invocation_for_module(
                invocations,
                cursor,
                groupEnd,
                layout.module_id,
                invocation
            );
            if (!due) {
                candidateTokens[scalarIndex] = outputTokens[scalarIndex];
                continue;
            }

            const NBModuleDescriptorABI module = modules[moduleIndex];
            const NBRegionalModuleStateABI diagnostic = outputDiagnostics[moduleIndex];
            const ulong elapsedMicroseconds = diagnostic.last_update_microseconds == neverUpdated
                ? ulong(module.period_microseconds)
                : invocation.timestamp_microseconds - diagnostic.last_update_microseconds;
            const float alpha = 1.0f - exp(
                -float(elapsedMicroseconds) / float(module.intrinsic_timescale_microseconds)
            );
            const float periodicDrive =
                (invocation.reason_flags & NBSchedulerReasonPeriodic) != 0u ? 0.25f : 0.0f;
            const float interruptDrive = min(
                float(popcount(invocation.interrupt_mask)) * 0.125f,
                1.0f
            );
            const float drive = periodicDrive + interruptDrive;
            const uint localScalar = scalarIndex - layout.scalar_offset;
            const uint dimension = uint(layout.token_dimension);
            const uint tokenStart = layout.scalar_offset + (localScalar / dimension) * dimension;
            const uint feature = localScalar % dimension;
            float localSum = 0.0f;
            for (uint localFeature = 0u; localFeature < dimension; ++localFeature) {
                localSum += outputTokens[tokenStart + localFeature];
            }
            const float localMean = localSum / float(dimension);
            float routedInput = 0.0f;
            const uint routeEnd = layout.incoming_route_offset
                + uint(layout.incoming_route_count);
            for (uint routeIndex = layout.incoming_route_offset;
                 routeIndex < routeEnd;
                 ++routeIndex) {
                const NBRegionalRouteABI route = routes[routeIndex];
                const uint senderIndex = regional_module_index(
                    layouts,
                    header->module_count,
                    route.sender_module_id
                );
                const NBRegionalTokenLayoutABI sender = layouts[senderIndex];
                const uint senderFeature = feature % uint(sender.token_dimension);
                const uint senderScalar = sender.scalar_offset
                    + uint(route.sender_token) * uint(sender.token_dimension)
                    + senderFeature;
                routedInput += route.gain * outputTokens[senderScalar];
            }
            const NBRegionalTokenParametersABI parameter =
                parameters[layout.parameter_offset + localScalar];
            const float current = outputTokens[scalarIndex];
            const float candidate = tanh(
                parameter.recurrent_gain * current
                + parameter.local_gain * localMean
                + parameter.route_gain * routedInput
                + parameter.drive_gain * drive
                + parameter.bias
            );
            const float gateInput = parameter.gate_bias
                + parameter.gate_recurrent_gain * current
                + parameter.gate_input_gain * (routedInput + drive);
            const float gate = 1.0f / (1.0f + exp(-gateInput));
            candidateTokens[scalarIndex] = current
                + alpha * gate * (candidate - current);
        }
        threadgroup_barrier(mem_flags::mem_device);

        for (uint scalarIndex = lane;
             scalarIndex < header->token_scalar_count;
             scalarIndex += laneCount) {
            uint moduleIndex = 0u;
            for (; moduleIndex < header->module_count; ++moduleIndex) {
                const NBRegionalTokenLayoutABI layout = layouts[moduleIndex];
                if (scalarIndex >= layout.scalar_offset
                    && scalarIndex < layout.scalar_offset + layout.scalar_count) {
                    break;
                }
            }
            NBDueInvocationABI invocation;
            if (regional_invocation_for_module(
                    invocations,
                    cursor,
                    groupEnd,
                    layouts[moduleIndex].module_id,
                    invocation)) {
                outputTokens[scalarIndex] = candidateTokens[scalarIndex];
            }
        }
        for (uint moduleIndex = lane;
             moduleIndex < header->module_count;
             moduleIndex += laneCount) {
            const NBModuleDescriptorABI module = modules[moduleIndex];
            NBDueInvocationABI invocation;
            if (!regional_invocation_for_module(
                    invocations,
                    cursor,
                    groupEnd,
                    module.module_id,
                    invocation)) {
                continue;
            }
            NBRegionalModuleStateABI state = outputDiagnostics[moduleIndex];
            const ulong elapsedMicroseconds = state.last_update_microseconds == neverUpdated
                ? ulong(module.period_microseconds)
                : invocation.timestamp_microseconds - state.last_update_microseconds;
            const float decay = exp(
                -float(elapsedMicroseconds) / float(module.intrinsic_timescale_microseconds)
            );
            const float blend = 1.0f - decay;
            const float periodicDrive =
                (invocation.reason_flags & NBSchedulerReasonPeriodic) != 0u ? 0.25f : 0.0f;
            const float interruptDrive = min(
                float(popcount(invocation.interrupt_mask)) * 0.125f,
                1.0f
            );
            const float target = min(periodicDrive + interruptDrive, 1.0f);
            state.activation = clamp(
                decay * state.activation + blend * target,
                0.0f,
                1.0f
            );
            state.integration = clamp(
                decay * state.integration + blend * state.activation,
                0.0f,
                1.0f
            );
            state.interrupt_salience = clamp(
                decay * state.interrupt_salience + blend * interruptDrive,
                0.0f,
                1.0f
            );
            state.phase = float(
                invocation.timestamp_microseconds % ulong(module.period_microseconds)
            ) / float(module.period_microseconds);
            if (state.update_count != ~0u) {
                state.update_count += 1u;
            }
            if ((invocation.reason_flags & NBSchedulerReasonInterrupt) != 0u
                && state.interrupt_count != ~0u) {
                state.interrupt_count += 1u;
            }
            state.last_update_microseconds = invocation.timestamp_microseconds;
            outputDiagnostics[moduleIndex] = state;
        }
        threadgroup_barrier(mem_flags::mem_device);
        cursor = groupEnd;
    }
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
    device const uint *activeEventIndices [[buffer(10)]],
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
    const float normalizedX = float(x) / float(max(width - 1, 1u));
    const float normalizedY = float(y) / float(max(height - 1, 1u));
    const uint activeEventCount = activeEventIndices[0];
    const uint randomSeed = as_type<uint>(uniforms[TissueRandomSeed]);
    const uint randomEnvironment = as_type<uint>(
        uniforms[TissueRandomEnvironmentIdentifier]
    );
    const uint randomEpisode = as_type<uint>(uniforms[TissueRandomEpisodeIdentifier]);
    const uint randomModule = as_type<uint>(uniforms[TissueRandomModuleIdentifier]);
    const uint acceptedStepLow = as_type<uint>(uniforms[TissueAcceptedStepLow]);
    const uint acceptedStepHigh = as_type<uint>(uniforms[TissueAcceptedStepHigh]);
    for (uint activeEventIndex = 0u;
         activeEventIndex < activeEventCount;
         ++activeEventIndex) {
        const uint eventIndex = activeEventIndices[activeEventIndex + 1u];
        const float4 geometryAndStart = receptorEvents[eventIndex * 3];
        const float4 endDriveAndNoise = receptorEvents[eventIndex * 3 + 1];
        const float4 metadata = receptorEvents[eventIndex * 3 + 2];
        const float radius = geometryAndStart.z;
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

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

struct NBReceptorEventABI {
    float center_x;
    float center_y;
    float radius;
    float start_milliseconds;
    float end_milliseconds;
    float excitatory_drive;
    float inhibitory_drive;
    float noise_amplitude;
    uint identifier;
    uint flags;
    ulong interrupt_mask;
    uint conduction_latency_microseconds;
    uint receptor_identifier;
    float magnitude;
    float auxiliary_value;
};

/// Compacts temporally due receptor events into canonical schedule order.
/// One deterministic GPU lane is sufficient for the bounded v0 schedule;
/// larger cohort queues will replace this with a prefix-sum implementation.
kernel void compact_receptor_events(
    constant float *uniforms [[buffer(0)]],
    device const NBReceptorEventABI *receptorEvents [[buffer(1)]],
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
        const NBReceptorEventABI event = receptorEvents[eventIndex];
        if (event.radius > 0.0f
            && time >= event.start_milliseconds
            && time < event.end_milliseconds) {
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

struct NBReceptorEventTransductionUniformsABI {
    ulong committed_time_microseconds;
    ulong target_time_microseconds;
    uint receptor_event_count;
    uint host_event_count;
    uint event_capacity;
    uint flags;
    uint reserved_0;
    uint reserved_1;
};

struct NBReceptorEventTransductionResultABI {
    uint event_count;
    uint receptor_event_count;
    uint status;
    uint reserved;
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
    ulong parameter_version_fingerprint;
    ulong schedule_fingerprint;
    uint module_count;
    uint event_count;
    uint invocation_capacity;
    uint environment_identifier;
    uint flags;
    uint reserved;
};

struct NBParameterVersionBindingABI {
    uint format_version;
    uint component_count;
    ulong version_sequence;
    ulong version_fingerprint;
    ulong parent_version_fingerprint;
    ulong schedule_fingerprint;
    ulong regional_shape_fingerprint;
    ulong regional_program_fingerprint;
    ulong total_parameter_bytes;
};

struct NBDispatchPlanHeaderABI {
    ulong schedule_fingerprint;
    ulong parameter_version_fingerprint;
    ulong cohort_fingerprint;
    ulong plan_fingerprint;
    uint group_count;
    uint entry_count;
    uint plan_version;
    uint flags;
};

struct NBDispatchGroupABI {
    ulong timestamp_microseconds;
    uint entry_offset;
    uint entry_count;
    ushort module_id;
    ushort clock_class;
    uint reserved;
};

struct NBDispatchEntryABI {
    ulong interrupt_mask;
    uint environment_identifier;
    uint reason_flags;
};

struct NBDispatchPlanResultABI {
    uint group_count;
    uint entry_count;
    uint status;
    uint reserved;
    ulong plan_fingerprint;
    ulong parameter_version_fingerprint;
};

struct NBDispatchWorkItemABI {
    ulong timestamp_microseconds;
    ulong interrupt_mask;
    uint environment_identifier;
    uint reason_flags;
    ushort module_id;
    ushort clock_class;
    uint group_index;
};

struct NBDispatchIndirectArgumentsABI {
    uint threadgroups_x;
    uint threadgroups_y;
    uint threadgroups_z;
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
    ushort normal_route_budget;
    ushort reserved;
};

struct NBRegionalRouteABI {
    ushort sender_module_id;
    ushort receiver_module_id;
    ushort sender_token;
    ushort flags;
    uint delay_microseconds;
    float gain;
    uint history_value_offset;
    uint message_dimension;
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
    uint history_capacity;
    uint history_scalar_count;
    uint program_version;
    uint minimum_route_persistence_microseconds;
    float salience_gain;
    float persistence_bonus;
};

struct NBRegionalRouteHistoryStateABI {
    uint next_slot;
    uint count;
    ulong latest_timestamp_microseconds;
};

struct NBRegionalRouteRuntimeStateABI {
    float score;
    float strength;
    uint active;
    uint selection_count;
    ulong last_selected_timestamp_microseconds;
    uint switch_count;
    uint reserved;
};

static_assert(sizeof(NBModuleDescriptorABI) == 32, "module descriptor ABI drift");
static_assert(sizeof(NBModuleClockStateABI) == 16, "module clock ABI drift");
static_assert(sizeof(NBReceptorEventABI) == 64, "receptor event ABI drift");
static_assert(sizeof(NBInterruptEventABI) == 24, "interrupt event ABI drift");
static_assert(
    sizeof(NBReceptorEventTransductionUniformsABI) == 40,
    "receptor transduction uniform ABI drift"
);
static_assert(
    sizeof(NBReceptorEventTransductionResultABI) == 16,
    "receptor transduction result ABI drift"
);
static_assert(sizeof(NBDueInvocationABI) == 32, "due invocation ABI drift");
static_assert(sizeof(NBSchedulerUniformsABI) == 56, "scheduler uniform ABI drift");
static_assert(sizeof(NBParameterVersionBindingABI) == 64, "parameter binding ABI drift");
static_assert(sizeof(NBDispatchPlanHeaderABI) == 48, "dispatch-plan header ABI drift");
static_assert(sizeof(NBDispatchGroupABI) == 24, "dispatch group ABI drift");
static_assert(sizeof(NBDispatchEntryABI) == 16, "dispatch entry ABI drift");
static_assert(sizeof(NBDispatchPlanResultABI) == 32, "dispatch result ABI drift");
static_assert(sizeof(NBDispatchWorkItemABI) == 32, "dispatch work-item ABI drift");
static_assert(sizeof(NBDispatchIndirectArgumentsABI) == 12, "indirect ABI drift");
static_assert(sizeof(NBSchedulerResultABI) == 16, "scheduler result ABI drift");
static_assert(sizeof(NBRegionalModuleStateABI) == 32, "regional state ABI drift");
static_assert(sizeof(NBRegionalTokenLayoutABI) == 32, "regional layout ABI drift");
static_assert(sizeof(NBRegionalRouteABI) == 24, "regional route ABI drift");
static_assert(sizeof(NBRegionalTokenParametersABI) == 32, "regional parameter ABI drift");
static_assert(sizeof(NBRegionalProgramHeaderABI) == 48, "regional header ABI drift");
static_assert(sizeof(NBRegionalRouteHistoryStateABI) == 16, "route history ABI drift");
static_assert(sizeof(NBRegionalRouteRuntimeStateABI) == 32, "route state ABI drift");

constant uint NBSchedulerFlagInitialize = 1u << 0;
constant uint NBSchedulerReasonPeriodic = 1u << 0;
constant uint NBSchedulerReasonInterrupt = 1u << 1;
constant uint NBSchedulerStatusValid = 0u;
constant uint NBSchedulerStatusInvocationCapacity = 1u;
constant uint NBSchedulerStatusTimeOverflow = 2u;
constant uint NBSchedulerStatusEventTransduction = 3u;
constant uint NBSchedulerStatusParameterVersion = 4u;
constant uint NBSchedulerStatusRegionalProgram = 5u;
constant uint NBParameterManifestVersion = 1u;
constant uint NBDispatchPlanVersion = 1u;
constant uint NBDispatchPlanStatusValid = 0u;
constant uint NBDispatchPlanStatusIdentity = 1u;
constant uint NBDispatchPlanStatusCapacity = 2u;
constant uint NBDispatchConsumerThreadgroupWidth = 64u;
constant uint NBReceptorTransductionStatusValid = 0u;
constant uint NBReceptorTransductionStatusEventCapacity = 1u;
constant uint NBReceptorTransductionStatusTimeOverflow = 2u;
constant uint NBInterruptEventFlagReceptorDerived = 1u << 0;

inline bool interrupt_event_less(
    thread const NBInterruptEventABI &lhs,
    thread const NBInterruptEventABI &rhs
) {
    if (lhs.timestamp_microseconds != rhs.timestamp_microseconds) {
        return lhs.timestamp_microseconds < rhs.timestamp_microseconds;
    }
    if (lhs.identifier != rhs.identifier) {
        return lhs.identifier < rhs.identifier;
    }
    if (lhs.interrupt_mask != rhs.interrupt_mask) {
        return lhs.interrupt_mask < rhs.interrupt_mask;
    }
    return lhs.flags < rhs.flags;
}

/// Materializes one already compiled active-module cohort plan into private
/// region-major dispatch buffers. One grid row owns one timestamp/module group;
/// columns copy its independent active-environment entries without atomics.
kernel void materialize_dispatch_plan(
    device const NBDispatchPlanHeaderABI *header [[buffer(0)]],
    device const NBDispatchGroupABI *inputGroups [[buffer(1)]],
    device const NBDispatchEntryABI *inputEntries [[buffer(2)]],
    device const NBParameterVersionBindingABI *parameterVersion [[buffer(3)]],
    device NBDispatchGroupABI *outputGroups [[buffer(4)]],
    device NBDispatchEntryABI *outputEntries [[buffer(5)]],
    device NBDispatchPlanResultABI *result [[buffer(6)]],
    device NBDispatchIndirectArgumentsABI *indirectArguments [[buffer(7)]],
    uint2 position [[thread_position_in_grid]]
) {
    const uint groupIndex = position.y;
    if (groupIndex >= header->group_count) {
        return;
    }
    if (groupIndex == 0u && position.x == 0u) {
        result->group_count = header->group_count;
        result->entry_count = header->entry_count;
        result->status = NBDispatchPlanStatusValid;
        result->reserved = 0u;
        result->plan_fingerprint = header->plan_fingerprint;
        result->parameter_version_fingerprint = header->parameter_version_fingerprint;
        indirectArguments->threadgroups_x = 0u;
        indirectArguments->threadgroups_y = 0u;
        indirectArguments->threadgroups_z = 0u;
        if (header->plan_version != NBDispatchPlanVersion
            || header->flags != 0u
            || header->group_count == 0u
            || header->entry_count == 0u
            || header->plan_fingerprint == 0ul
            || header->cohort_fingerprint == 0ul
            || parameterVersion->format_version != NBParameterManifestVersion
            || header->parameter_version_fingerprint
                != parameterVersion->version_fingerprint
            || header->schedule_fingerprint
                != parameterVersion->schedule_fingerprint) {
            result->status = NBDispatchPlanStatusIdentity;
        } else {
            for (uint index = 0u; index < header->group_count; ++index) {
                const NBDispatchGroupABI candidate = inputGroups[index];
                if (candidate.entry_offset > header->entry_count
                    || candidate.entry_count
                        > header->entry_count - candidate.entry_offset) {
                    result->status = NBDispatchPlanStatusCapacity;
                    break;
                }
            }
        }
        if (result->status == NBDispatchPlanStatusValid) {
            indirectArguments->threadgroups_x =
                header->entry_count / NBDispatchConsumerThreadgroupWidth
                + (header->entry_count % NBDispatchConsumerThreadgroupWidth == 0u
                    ? 0u
                    : 1u);
            indirectArguments->threadgroups_y = 1u;
            indirectArguments->threadgroups_z = 1u;
        }
    }
    const NBDispatchGroupABI group = inputGroups[groupIndex];
    if (position.x == 0u) {
        outputGroups[groupIndex] = group;
    }
    if (group.entry_offset > header->entry_count
        || group.entry_count > header->entry_count - group.entry_offset) {
        return;
    }
    if (position.x < group.entry_count) {
        const uint entryIndex = group.entry_offset + position.x;
        outputEntries[entryIndex] = inputEntries[entryIndex];
    }
}

/// Expands the private canonical plan through GPU-generated indirect dispatch.
/// Each flattened entry is owned by one lane and retains its source group.
kernel void consume_dispatch_plan(
    device const NBDispatchPlanHeaderABI *header [[buffer(0)]],
    device const NBDispatchGroupABI *groups [[buffer(1)]],
    device const NBDispatchEntryABI *entries [[buffer(2)]],
    device NBDispatchWorkItemABI *workItems [[buffer(3)]],
    uint entryIndex [[thread_position_in_grid]]
) {
    if (entryIndex >= header->entry_count) {
        return;
    }
    uint lower = 0u;
    uint upper = header->group_count;
    uint groupIndex = ~0u;
    while (lower < upper) {
        const uint middle = lower + (upper - lower) / 2u;
        const NBDispatchGroupABI group = groups[middle];
        if (entryIndex < group.entry_offset) {
            upper = middle;
        } else if (entryIndex >= group.entry_offset + group.entry_count) {
            lower = middle + 1u;
        } else {
            groupIndex = middle;
            break;
        }
    }
    if (groupIndex == ~0u) {
        return;
    }
    const NBDispatchGroupABI group = groups[groupIndex];
    const NBDispatchEntryABI entry = entries[entryIndex];
    NBDispatchWorkItemABI item;
    item.timestamp_microseconds = group.timestamp_microseconds;
    item.interrupt_mask = entry.interrupt_mask;
    item.environment_identifier = entry.environment_identifier;
    item.reason_flags = entry.reason_flags;
    item.module_id = group.module_id;
    item.clock_class = group.clock_class;
    item.group_index = groupIndex;
    workItems[entryIndex] = item;
}

/// Converts immutable receptor-event onsets into the scheduler's compact
/// interrupt ABI. The output remains private GPU memory and is consumed by the
/// scheduler in the same command-buffer timeline.
kernel void transduce_receptor_interrupts(
    constant NBReceptorEventTransductionUniformsABI *uniforms [[buffer(0)]],
    device const NBReceptorEventABI *receptorEvents [[buffer(1)]],
    device const NBInterruptEventABI *hostEvents [[buffer(2)]],
    device NBInterruptEventABI *outputEvents [[buffer(3)]],
    device NBReceptorEventTransductionResultABI *result [[buffer(4)]],
    uint threadIndex [[thread_position_in_grid]]
) {
    if (threadIndex != 0u) {
        return;
    }
    result->event_count = 0u;
    result->receptor_event_count = 0u;
    result->status = NBReceptorTransductionStatusValid;
    result->reserved = 0u;

    uint outputCount = 0u;
    for (uint index = 0u; index < uniforms->host_event_count; ++index) {
        if (outputCount >= uniforms->event_capacity) {
            result->status = NBReceptorTransductionStatusEventCapacity;
            return;
        }
        outputEvents[outputCount++] = hostEvents[index];
    }

    const bool includeCommittedBoundary =
        (uniforms->flags & NBSchedulerFlagInitialize) != 0u;
    uint receptorCount = 0u;
    for (uint index = 0u; index < uniforms->receptor_event_count; ++index) {
        const NBReceptorEventABI receptor = receptorEvents[index];
        if (receptor.interrupt_mask == 0ul
            || receptor.radius <= 0.0f
            || receptor.end_milliseconds <= receptor.start_milliseconds) {
            continue;
        }
        const float onsetScaled = receptor.start_milliseconds * 1000.0f;
        if (!isfinite(onsetScaled) || onsetScaled < 0.0f) {
            result->status = NBReceptorTransductionStatusTimeOverflow;
            return;
        }
        const ulong onset = ulong(round(onsetScaled));
        const ulong latency = ulong(receptor.conduction_latency_microseconds);
        if (onset > (~0ul) - latency) {
            result->status = NBReceptorTransductionStatusTimeOverflow;
            return;
        }
        const ulong timestamp = onset + latency;
        const bool afterLowerBound = includeCommittedBoundary
            ? timestamp >= uniforms->committed_time_microseconds
            : timestamp > uniforms->committed_time_microseconds;
        if (!afterLowerBound || timestamp > uniforms->target_time_microseconds) {
            continue;
        }
        if (outputCount >= uniforms->event_capacity) {
            result->status = NBReceptorTransductionStatusEventCapacity;
            return;
        }
        NBInterruptEventABI event;
        event.timestamp_microseconds = timestamp;
        event.interrupt_mask = receptor.interrupt_mask;
        event.identifier = receptor.receptor_identifier;
        event.flags = NBInterruptEventFlagReceptorDerived;
        outputEvents[outputCount++] = event;
        receptorCount += 1u;
    }

    for (uint index = 1u; index < outputCount; ++index) {
        const NBInterruptEventABI key = outputEvents[index];
        uint destination = index;
        while (destination > 0u) {
            const NBInterruptEventABI previous = outputEvents[destination - 1u];
            if (!interrupt_event_less(key, previous)) {
                break;
            }
            outputEvents[destination] = previous;
            destination -= 1u;
        }
        outputEvents[destination] = key;
    }
    result->event_count = outputCount;
    result->receptor_event_count = receptorCount;
}

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
    device const NBReceptorEventTransductionResultABI *eventResult [[buffer(7)]],
    device const NBParameterVersionBindingABI *parameterVersion [[buffer(8)]],
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
    if (parameterVersion->format_version != NBParameterManifestVersion
        || parameterVersion->version_fingerprint
            != uniforms->parameter_version_fingerprint
        || parameterVersion->schedule_fingerprint != uniforms->schedule_fingerprint) {
        result->status = NBSchedulerStatusParameterVersion;
        return;
    }
    if (eventResult->status != NBReceptorTransductionStatusValid) {
        result->status = NBSchedulerStatusEventTransduction;
        return;
    }

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

    for (uint eventIndex = 0u; eventIndex < eventResult->event_count; ++eventIndex) {
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

inline float regional_route_message_value(
    uint routeIndex,
    ulong timestamp,
    uint feature,
    device const NBRegionalProgramHeaderABI *header,
    device const NBRegionalTokenLayoutABI *layouts,
    device const NBRegionalRouteABI *routes,
    device const float *tokens,
    device const float *routeHistoryValues,
    device const uint *resolvedRouteHistorySlots
) {
    const NBRegionalRouteABI route = routes[routeIndex];
    if (route.delay_microseconds == 0u) {
        const uint senderIndex = regional_module_index(
            layouts,
            header->module_count,
            route.sender_module_id
        );
        const NBRegionalTokenLayoutABI sender = layouts[senderIndex];
        const uint senderFeature = feature % uint(sender.token_dimension);
        return tokens[
            sender.scalar_offset
            + uint(route.sender_token) * uint(sender.token_dimension)
            + senderFeature
        ];
    }
    if (timestamp < ulong(route.delay_microseconds)) {
        return 0.0f;
    }
    const uint resolvedSlot = resolvedRouteHistorySlots[routeIndex];
    if (resolvedSlot == ~0u) {
        return 0.0f;
    }
    return routeHistoryValues[
        route.history_value_offset
        + resolvedSlot * route.message_dimension
        + feature % route.message_dimension
    ];
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
    device NBSchedulerResultABI *schedulerResult [[buffer(5)]],
    device const NBDueInvocationABI *invocations [[buffer(6)]],
    device const NBRegionalModuleStateABI *inputDiagnostics [[buffer(7)]],
    device NBRegionalModuleStateABI *outputDiagnostics [[buffer(8)]],
    device const float *inputTokens [[buffer(9)]],
    device float *outputTokens [[buffer(10)]],
    device float *candidateTokens [[buffer(11)]],
    device const NBRegionalRouteHistoryStateABI *inputRouteHistoryStates [[buffer(12)]],
    device NBRegionalRouteHistoryStateABI *outputRouteHistoryStates [[buffer(13)]],
    device const ulong *inputRouteHistoryTimestamps [[buffer(14)]],
    device ulong *outputRouteHistoryTimestamps [[buffer(15)]],
    device const float *inputRouteHistoryValues [[buffer(16)]],
    device float *outputRouteHistoryValues [[buffer(17)]],
    device uint *resolvedRouteHistorySlots [[buffer(18)]],
    device const NBRegionalRouteRuntimeStateABI *inputRouteRuntimeStates [[buffer(19)]],
    device NBRegionalRouteRuntimeStateABI *outputRouteRuntimeStates [[buffer(20)]],
    device uint *selectedRouteIndices [[buffer(21)]],
    device uint *selectedRouteCounts [[buffer(22)]],
    device const NBParameterVersionBindingABI *parameterVersion [[buffer(23)]],
    uint lane [[thread_index_in_threadgroup]],
    uint3 lanesPerThreadgroup [[threads_per_threadgroup]]
) {
    const uint laneCount = lanesPerThreadgroup.x;
    if (lane == 0u
        && (parameterVersion->regional_program_fingerprint
                != header->program_fingerprint
            || parameterVersion->schedule_fingerprint == 0ul)) {
        schedulerResult->status = NBSchedulerStatusRegionalProgram;
    }
    threadgroup_barrier(mem_flags::mem_device);
    if (schedulerResult->status != NBSchedulerStatusValid) {
        return;
    }
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
    for (uint routeIndex = lane;
         routeIndex < header->route_count;
         routeIndex += laneCount) {
        outputRouteHistoryStates[routeIndex] = inputRouteHistoryStates[routeIndex];
    }
    const uint historyTimestampCount = header->route_count * header->history_capacity;
    for (uint timestampIndex = lane;
         timestampIndex < historyTimestampCount;
         timestampIndex += laneCount) {
        outputRouteHistoryTimestamps[timestampIndex] =
            inputRouteHistoryTimestamps[timestampIndex];
    }
    for (uint historyScalarIndex = lane;
         historyScalarIndex < header->history_scalar_count;
         historyScalarIndex += laneCount) {
        outputRouteHistoryValues[historyScalarIndex] =
            inputRouteHistoryValues[historyScalarIndex];
    }
    for (uint routeIndex = lane;
         routeIndex < header->route_count;
         routeIndex += laneCount) {
        outputRouteRuntimeStates[routeIndex] = inputRouteRuntimeStates[routeIndex];
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

        for (uint routeIndex = lane;
             routeIndex < header->route_count;
             routeIndex += laneCount) {
            const NBRegionalRouteABI route = routes[routeIndex];
            uint resolvedSlot = ~0u;
            if (route.delay_microseconds > 0u
                && timestamp >= ulong(route.delay_microseconds)) {
                const ulong targetTimestamp = timestamp - ulong(route.delay_microseconds);
                const NBRegionalRouteHistoryStateABI history =
                    outputRouteHistoryStates[routeIndex];
                for (uint age = 0u; age < history.count; ++age) {
                    const uint slot = (
                        history.next_slot + header->history_capacity - 1u - age
                    ) % header->history_capacity;
                    const ulong messageTimestamp = outputRouteHistoryTimestamps[
                        routeIndex * header->history_capacity + slot
                    ];
                    if (messageTimestamp <= targetTimestamp) {
                        resolvedSlot = slot;
                        break;
                    }
                }
            }
            resolvedRouteHistorySlots[routeIndex] = resolvedSlot;
        }
        threadgroup_barrier(mem_flags::mem_device);

        for (uint moduleIndex = lane;
             moduleIndex < header->module_count;
             moduleIndex += laneCount) {
            selectedRouteCounts[moduleIndex] = 0u;
            const NBRegionalTokenLayoutABI receiver = layouts[moduleIndex];
            NBDueInvocationABI receiverInvocation;
            if (!regional_invocation_for_module(
                    invocations,
                    cursor,
                    groupEnd,
                    receiver.module_id,
                    receiverInvocation)) {
                continue;
            }
            const uint routeBegin = receiver.incoming_route_offset;
            const uint routeEnd = routeBegin + uint(receiver.incoming_route_count);
            if (routeBegin == routeEnd) {
                continue;
            }
            const uint queryDimension = uint(receiver.token_dimension);
            for (uint routeIndex = routeBegin;
                 routeIndex < routeEnd;
                 ++routeIndex) {
                float dot = 0.0f;
                float salience = 0.0f;
                for (uint feature = 0u; feature < queryDimension; ++feature) {
                    const float message = regional_route_message_value(
                        routeIndex,
                        timestamp,
                        feature,
                        header,
                        layouts,
                        routes,
                        outputTokens,
                        outputRouteHistoryValues,
                        resolvedRouteHistorySlots
                    );
                    dot += outputTokens[receiver.scalar_offset + feature] * message;
                    salience += abs(message);
                }
                NBRegionalRouteRuntimeStateABI state =
                    outputRouteRuntimeStates[routeIndex];
                state.score = dot / sqrt(float(queryDimension))
                    + header->salience_gain * salience / float(queryDimension);
                if (state.active != 0u) {
                    state.score += header->persistence_bonus;
                }
                outputRouteRuntimeStates[routeIndex] = state;
            }

            uint selectedCount = 0u;
            uint normalSelected = 0u;
            for (uint routeIndex = routeBegin;
                 routeIndex < routeEnd;
                 ++routeIndex) {
                if ((routes[routeIndex].flags & 1u) != 0u) {
                    selectedRouteIndices[routeBegin + selectedCount] = routeIndex;
                    selectedCount += 1u;
                }
            }
            for (uint routeIndex = routeBegin;
                 routeIndex < routeEnd
                     && normalSelected < uint(receiver.normal_route_budget);
                 ++routeIndex) {
                const NBRegionalRouteABI route = routes[routeIndex];
                const NBRegionalRouteRuntimeStateABI state =
                    outputRouteRuntimeStates[routeIndex];
                if ((route.flags & 1u) != 0u
                    || state.active == 0u
                    || state.last_selected_timestamp_microseconds == ~0ul
                    || timestamp < state.last_selected_timestamp_microseconds) {
                    continue;
                }
                if (timestamp - state.last_selected_timestamp_microseconds
                    < ulong(header->minimum_route_persistence_microseconds)) {
                    selectedRouteIndices[routeBegin + selectedCount] = routeIndex;
                    selectedCount += 1u;
                    normalSelected += 1u;
                }
            }
            while (normalSelected < uint(receiver.normal_route_budget)) {
                uint bestRoute = ~0u;
                float bestScore = -INFINITY;
                for (uint routeIndex = routeBegin;
                     routeIndex < routeEnd;
                     ++routeIndex) {
                    if ((routes[routeIndex].flags & 1u) != 0u) {
                        continue;
                    }
                    bool alreadySelected = false;
                    for (uint selectedIndex = 0u;
                         selectedIndex < selectedCount;
                         ++selectedIndex) {
                        if (selectedRouteIndices[routeBegin + selectedIndex] == routeIndex) {
                            alreadySelected = true;
                            break;
                        }
                    }
                    if (alreadySelected) {
                        continue;
                    }
                    const float score = outputRouteRuntimeStates[routeIndex].score;
                    if (score > bestScore) {
                        bestScore = score;
                        bestRoute = routeIndex;
                    }
                }
                if (bestRoute == ~0u) {
                    break;
                }
                selectedRouteIndices[routeBegin + selectedCount] = bestRoute;
                selectedCount += 1u;
                normalSelected += 1u;
            }

            float maximumScore = 0.0f;
            if (selectedCount > 0u) {
                maximumScore = outputRouteRuntimeStates[
                    selectedRouteIndices[routeBegin]
                ].score;
                for (uint selectedIndex = 1u;
                     selectedIndex < selectedCount;
                     ++selectedIndex) {
                    maximumScore = max(
                        maximumScore,
                        outputRouteRuntimeStates[
                            selectedRouteIndices[routeBegin + selectedIndex]
                        ].score
                    );
                }
            }
            float strengthDenominator = 0.0f;
            for (uint selectedIndex = 0u;
                 selectedIndex < selectedCount;
                 ++selectedIndex) {
                strengthDenominator += exp(
                    outputRouteRuntimeStates[
                        selectedRouteIndices[routeBegin + selectedIndex]
                    ].score - maximumScore
                );
            }
            for (uint routeIndex = routeBegin;
                 routeIndex < routeEnd;
                 ++routeIndex) {
                NBRegionalRouteRuntimeStateABI state =
                    outputRouteRuntimeStates[routeIndex];
                const bool wasActive = state.active != 0u;
                bool isActive = false;
                for (uint selectedIndex = 0u;
                     selectedIndex < selectedCount;
                     ++selectedIndex) {
                    if (selectedRouteIndices[routeBegin + selectedIndex] == routeIndex) {
                        isActive = true;
                        break;
                    }
                }
                state.active = isActive ? 1u : 0u;
                state.strength = isActive && strengthDenominator > 0.0f
                    ? exp(state.score - maximumScore) / strengthDenominator
                    : 0.0f;
                if (isActive) {
                    if (state.selection_count != ~0u) {
                        state.selection_count += 1u;
                    }
                    state.last_selected_timestamp_microseconds = timestamp;
                }
                if (isActive != wasActive && state.switch_count != ~0u) {
                    state.switch_count += 1u;
                }
                outputRouteRuntimeStates[routeIndex] = state;
            }
            selectedRouteCounts[moduleIndex] = selectedCount;
        }
        threadgroup_barrier(mem_flags::mem_device);

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
            const uint selectedCount = selectedRouteCounts[moduleIndex];
            for (uint selectedIndex = 0u;
                 selectedIndex < selectedCount;
                 ++selectedIndex) {
                const uint routeIndex = selectedRouteIndices[
                    layout.incoming_route_offset + selectedIndex
                ];
                const NBRegionalRouteABI route = routes[routeIndex];
                routedInput += route.gain
                    * outputRouteRuntimeStates[routeIndex].strength
                    * regional_route_message_value(
                        routeIndex,
                        timestamp,
                        feature,
                        header,
                        layouts,
                        routes,
                        outputTokens,
                        outputRouteHistoryValues,
                        resolvedRouteHistorySlots
                    );
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

        for (uint routeIndex = 0u;
             routeIndex < header->route_count;
             ++routeIndex) {
            const NBRegionalRouteABI route = routes[routeIndex];
            NBDueInvocationABI senderInvocation;
            if (!regional_invocation_for_module(
                    invocations,
                    cursor,
                    groupEnd,
                    route.sender_module_id,
                    senderInvocation)) {
                continue;
            }
            const uint senderIndex = regional_module_index(
                layouts,
                header->module_count,
                route.sender_module_id
            );
            const NBRegionalTokenLayoutABI sender = layouts[senderIndex];
            const uint senderTokenBase = sender.scalar_offset
                + uint(route.sender_token) * uint(sender.token_dimension);
            const uint writeSlot = outputRouteHistoryStates[routeIndex].next_slot;
            const uint historyValueBase = route.history_value_offset
                + writeSlot * route.message_dimension;
            for (uint feature = lane;
                 feature < route.message_dimension;
                 feature += laneCount) {
                outputRouteHistoryValues[historyValueBase + feature] =
                    outputTokens[senderTokenBase + feature];
            }
        }
        threadgroup_barrier(mem_flags::mem_device);

        for (uint routeIndex = lane;
             routeIndex < header->route_count;
             routeIndex += laneCount) {
            const NBRegionalRouteABI route = routes[routeIndex];
            NBDueInvocationABI senderInvocation;
            if (!regional_invocation_for_module(
                    invocations,
                    cursor,
                    groupEnd,
                    route.sender_module_id,
                    senderInvocation)) {
                continue;
            }
            NBRegionalRouteHistoryStateABI history =
                outputRouteHistoryStates[routeIndex];
            const uint writeSlot = history.next_slot;
            outputRouteHistoryTimestamps[
                routeIndex * header->history_capacity + writeSlot
            ] = timestamp;
            history.next_slot = (writeSlot + 1u) % header->history_capacity;
            history.count = min(history.count + 1u, header->history_capacity);
            history.latest_timestamp_microseconds = timestamp;
            outputRouteHistoryStates[routeIndex] = history;
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
    device const NBReceptorEventABI *receptorEvents [[buffer(9)]],
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
        const NBReceptorEventABI event = receptorEvents[eventIndex];
        const float radius = event.radius;
        const float dx = normalizedX - event.center_x;
        const float dy = normalizedY - event.center_y;
        if (dx * dx + dy * dy > radius * radius) {
            continue;
        }
        const uint eventIdentifier = event.identifier;
        const float noiseAmplitude = event.noise_amplitude;
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
        stimulusE += event.excitatory_drive + excitatoryNoise;
        stimulusI += event.inhibitory_drive + inhibitoryNoise;
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

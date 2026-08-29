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
    TissueCurrentTimestampLow = 39,
    TissueCurrentTimestampHigh = 40,
    TissueCandidateTimestampLow = 41,
    TissueCandidateTimestampHigh = 42,
    TissueNominalTimestepMicrosecondsLow = 43,
    TissueNominalTimestepMicrosecondsHigh = 44,
};

inline float tissue_sigmoid(float value) {
    return 1.0f / (1.0f + exp(-value));
}

inline ulong tissue_uint64_from_uniforms(
    constant float *uniforms,
    uint lowIndex,
    uint highIndex
) {
    return ulong(as_type<uint>(uniforms[lowIndex]))
        | (ulong(as_type<uint>(uniforms[highIndex])) << 32u);
}

inline uint tissue_history_plane(uint historyOwnerMask, uint slot) {
    return (historyOwnerMask >> slot) & 1u;
}

inline float tissue_relay_at_physical_delay(
    device const float *relayHistory,
    device const ulong *relayHistoryTimestamps,
    uint siteIndex,
    uint delaySteps,
    uint siteCount,
    uint historyCapacity,
    uint historyOwnerMask,
    ulong currentTimestamp,
    ulong nominalTimestepMicroseconds
) {
    const ulong delayMicroseconds = ulong(delaySteps) * nominalTimestepMicroseconds;
    const ulong targetTimestamp = delayMicroseconds >= currentTimestamp
        ? 0ul
        : currentTimestamp - delayMicroseconds;
    bool hasLower = false;
    bool hasUpper = false;
    ulong lowerTimestamp = 0ul;
    ulong upperTimestamp = ~0ul;
    uint lowerSlot = 0u;
    uint upperSlot = 0u;
    uint lowerPlane = 0u;
    uint upperPlane = 0u;
    for (uint slot = 0u; slot < historyCapacity; ++slot) {
        const uint plane = tissue_history_plane(historyOwnerMask, slot);
        const ulong timestamp = relayHistoryTimestamps[plane * historyCapacity + slot];
        if (timestamp <= targetTimestamp
            && (!hasLower || timestamp > lowerTimestamp)) {
            hasLower = true;
            lowerTimestamp = timestamp;
            lowerSlot = slot;
            lowerPlane = plane;
        }
        if (timestamp >= targetTimestamp
            && (!hasUpper || timestamp < upperTimestamp)) {
            hasUpper = true;
            upperTimestamp = timestamp;
            upperSlot = slot;
            upperPlane = plane;
        }
    }
    if (!hasLower && hasUpper) {
        lowerTimestamp = upperTimestamp;
        lowerSlot = upperSlot;
        lowerPlane = upperPlane;
        hasLower = true;
    }
    const uint lowerIndex =
        (lowerPlane * historyCapacity + lowerSlot) * siteCount + siteIndex;
    const float lowerValue = relayHistory[lowerIndex];
    if (!hasUpper || upperTimestamp == lowerTimestamp) {
        return lowerValue;
    }
    const uint upperIndex =
        (upperPlane * historyCapacity + upperSlot) * siteCount + siteIndex;
    const float upperValue = relayHistory[upperIndex];
    const float fraction = float(targetTimestamp - lowerTimestamp)
        / float(upperTimestamp - lowerTimestamp);
    return lowerValue + fraction * (upperValue - lowerValue);
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
    float magnitude;
    float auxiliary_value;
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

struct NBCognitiveEventQueueHeaderABI {
    atomic_uint count;
    uint capacity;
    atomic_uint overflow_count;
    uint flags;
    ulong target_timestamp_microseconds;
    ulong generation;
};

struct NBCognitiveReceptorEventABI {
    uint environment_identifier;
    uint kind;
    uint source_identifier;
    uint flags;
    ulong timestamp_microseconds;
    float magnitude;
    float auxiliary_value;
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

struct NBRegionalMaturationRecordABI {
    uint module_identifier;
    uint unlocked;
    float learning_rate_multiplier;
    float timescale_multiplier;
    float route_gain_multiplier;
    float conduction_delay_multiplier;
    float capacity_fraction;
    uint flags;
};

struct NBRegionalPlasticModulationRecordABI {
    uint module_identifier;
    uint coefficient_count;
    float recurrent_delta;
    float local_delta;
    float route_delta;
    float drive_delta;
    float gate_delta;
    uint flags;
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

struct NBDispatchCohortUniformsABI {
    ulong plan_fingerprint;
    ulong parameter_version_fingerprint;
    uint environment_count;
    uint module_count;
    uint state_count;
    uint flags;
};

struct NBDispatchTokenUniformsABI {
    ulong regional_program_fingerprint;
    ulong schedule_fingerprint;
    uint environment_count;
    uint scalar_count_per_environment;
    ulong total_scalar_count;
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

struct NBProtectiveCommandUniformsABI {
    ulong brain_generation;
    ulong motor_profile_fingerprint;
    uint module_count;
    uint muscle_count;
    uint environment_identifier;
    uint reserved;
};

struct NBFastCPGUniformsABI {
    ulong sample_timestamp_microseconds;
    uint oscillator_count;
    uint synergy_count;
    uint flags;
    uint reflex_rule_count;
};

struct NBFastCPGStateABI {
    float phase;
    float output;
    float effective_frequency_hertz;
    float duty_factor;
    ulong timestamp_microseconds;
    ulong sensory_reset_mask;
    float reset_magnitude;
    float output_gain;
    float decision_output;
    float reserved_float;
    uint output_synergy_identifier;
    uint oscillator_identifier;
    uint flags;
    uint output_kind;
};

struct NBFastReflexRuleABI {
    uint receptor_identifier;
    uint actuator_identifier;
    uint circuit_identifier;
    uint circuit_kind;
    uint latency_microseconds;
    uint flags;
    float activation_threshold;
    float gain;
};

struct NBFastReflexStateABI {
    ulong last_event_timestamp_microseconds;
    ulong state_timestamp_microseconds;
    float output;
    float event_magnitude;
    uint circuit_identifier;
    uint flags;
    ulong pending_delivery_timestamp_microseconds[4];
    ulong pending_event_timestamp_microseconds[4];
    float pending_output[4];
    float pending_event_magnitude[4];
};

struct NBFastCerebellarStateABI {
    ulong last_observation_timestamp_microseconds;
    ulong state_timestamp_microseconds;
    float learned_load_gain;
    float predicted_load;
    float observed_load;
    float prediction_error;
    float correction;
    float desired_load;
    uint update_count;
    uint flags;
    float reserved[4];
};

struct NBFastAutonomicUniformsABI {
    ulong sample_timestamp_microseconds;
    ulong baseline_timestamp_microseconds;
    uint channel_count;
    uint flags;
    float vital_gain;
    uint response_time_microseconds;
    uint critical_decay_microseconds;
    uint oscillator_count;
};

struct NBFastAutonomicChannelDescriptorABI {
    uint channel_identifier;
    uint kind;
    uint flags;
    uint critical_receptor_count;
    uint critical_receptors[4];
    float emergency_target;
    float emergency_gain;
    float cpg_gain;
    float reserved;
};

struct NBFastAutonomicStateABI {
    ulong last_event_timestamp_microseconds;
    ulong state_timestamp_microseconds;
    float command;
    float target;
    float critical_drive;
    float integration;
    uint update_count;
    uint flags;
    float reserved[6];
};

struct NBAutonomicCommandRecordABI {
    float command;
    float target;
    float confidence;
    uint flags;
};

struct NBMotorCommandRecordABI {
    float excitation;
    float force_target;
    float stiffness_target;
    float damping_target;
    float cerebellar_residual;
    float risk_inhibition;
    uint synergy_identifier;
    uint flags;
};

struct NBProtectiveCommandABI {
    uint format_version;
    uint flags;
    ulong timestamp_microseconds;
    ulong brain_generation;
    ulong interrupt_mask;
    float withdrawal_drive;
    float postural_stiffness;
    float motor_inhibition;
    float autonomic_arousal;
    uint environment_identifier;
    uint reserved;
    ulong command_fingerprint;
};

struct NBMotorChannelDescriptorABI {
    uint muscle_id;
    uint flags;
    float resting_excitation;
    float withdrawal_gain;
    float brace_gain;
    float maximum_excitation;
    uint reserved0;
    uint reserved1;
};

struct NBMotorOutputHeaderABI {
    uint format_version;
    uint flags;
    ulong timestamp_microseconds;
    ulong brain_generation;
    ulong profile_fingerprint;
    ulong protective_command_fingerprint;
    uint muscle_count;
    uint environment_identifier;
    float motor_inhibition;
    float autonomic_arousal;
    ulong output_fingerprint;
};

struct NBBodyLoadFieldUniformsABI {
    ulong attachment_catalog_fingerprint;
    uint body_count;
    uint update_count;
    ulong target_timestamp_microseconds;
    uint persistence_microseconds;
    uint decay_microseconds;
};

struct NBBodyLoadFieldRecordABI {
    uint body_identifier;
    uint endpoint_role;
    uint source_muscle_identifier;
    float maximum_absolute_muscle_force;
    ulong accepted_timestamp_microseconds;
    ulong accepted_physics_state_fingerprint;
    float effective_absolute_muscle_force;
    uint reserved;
    ulong field_activation_timestamp_microseconds;
    ulong field_state_timestamp_microseconds;
};

struct NBBodySchemaUniformsABI {
    uint body_count;
    uint reserved0;
    ulong target_timestamp_microseconds;
    float force_scale_newtons;
    uint load_time_constant_microseconds;
    float initial_variance;
    float maximum_variance;
    float process_variance_per_second;
    float observation_variance;
    float vulnerability_gain_per_second;
    float recovery_per_second;
    float uncertainty_risk_weight;
    float reserved1;
};

struct NBBodySchemaRecordABI {
    uint body_identifier;
    uint flags;
    uint source_muscle_identifier;
    uint endpoint_role;
    float estimated_absolute_load;
    float epistemic_variance;
    float vulnerability;
    float damage_risk;
    ulong last_observation_timestamp_microseconds;
    ulong state_timestamp_microseconds;
};

struct NBMuscleAttachmentRecordABI {
    uint muscle_identifier;
    uint first_body_identifier;
    uint terminal_body_identifier;
    uint reserved;
};

constant uint NBBodySchemaFlagEverObserved = 1u << 0u;
constant uint NBBodySchemaFlagObservedThisUpdate = 1u << 1u;
constant uint NBBodySchemaFlagFirstRouteEndpoint = 1u << 2u;
constant uint NBBodySchemaFlagTerminalRouteEndpoint = 1u << 3u;
constant ulong NBBodySchemaNoObservation = ~0ul;

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
static_assert(sizeof(NBInterruptEventABI) == 32, "interrupt event ABI drift");
static_assert(
    sizeof(NBReceptorEventTransductionUniformsABI) == 40,
    "receptor transduction uniform ABI drift"
);
static_assert(
    sizeof(NBReceptorEventTransductionResultABI) == 16,
    "receptor transduction result ABI drift"
);
static_assert(sizeof(NBCognitiveEventQueueHeaderABI) == 32,
              "cognitive event queue header drift");
static_assert(sizeof(NBCognitiveReceptorEventABI) == 32,
              "cognitive receptor event drift");
static_assert(sizeof(NBDueInvocationABI) == 32, "due invocation ABI drift");
static_assert(sizeof(NBSchedulerUniformsABI) == 56, "scheduler uniform ABI drift");
static_assert(sizeof(NBRegionalMaturationRecordABI) == 32,
              "regional maturation ABI drift");
static_assert(sizeof(NBRegionalPlasticModulationRecordABI) == 32,
              "regional plastic modulation ABI drift");
static_assert(sizeof(NBParameterVersionBindingABI) == 64, "parameter binding ABI drift");
static_assert(sizeof(NBDispatchPlanHeaderABI) == 48, "dispatch-plan header ABI drift");
static_assert(sizeof(NBDispatchGroupABI) == 24, "dispatch group ABI drift");
static_assert(sizeof(NBDispatchEntryABI) == 16, "dispatch entry ABI drift");
static_assert(sizeof(NBDispatchPlanResultABI) == 32, "dispatch result ABI drift");
static_assert(sizeof(NBDispatchWorkItemABI) == 32, "dispatch work-item ABI drift");
static_assert(sizeof(NBDispatchCohortUniformsABI) == 32, "cohort uniform ABI drift");
static_assert(sizeof(NBDispatchTokenUniformsABI) == 32, "token uniform ABI drift");
static_assert(sizeof(NBDispatchIndirectArgumentsABI) == 12, "indirect ABI drift");
static_assert(sizeof(NBSchedulerResultABI) == 16, "scheduler result ABI drift");
static_assert(sizeof(NBRegionalModuleStateABI) == 32, "regional state ABI drift");
static_assert(sizeof(NBProtectiveCommandUniformsABI) == 32, "protective uniforms drift");
static_assert(sizeof(NBFastCPGUniformsABI) == 24, "fast CPG uniforms drift");
static_assert(sizeof(NBFastCPGStateABI) == 64, "fast CPG state drift");
static_assert(sizeof(NBFastReflexRuleABI) == 32, "fast reflex rule drift");
static_assert(sizeof(NBFastReflexStateABI) == 128, "fast reflex state drift");
static_assert(sizeof(NBFastCerebellarStateABI) == 64, "fast cerebellar state drift");
static_assert(sizeof(NBFastAutonomicUniformsABI) == 40,
              "fast autonomic uniforms drift");
static_assert(sizeof(NBFastAutonomicChannelDescriptorABI) == 48,
              "fast autonomic channel descriptor drift");
static_assert(sizeof(NBFastAutonomicStateABI) == 64,
              "fast autonomic state drift");
static_assert(sizeof(NBAutonomicCommandRecordABI) == 16,
              "autonomic command record drift");
static_assert(sizeof(NBMotorCommandRecordABI) == 32, "motor command record drift");
static_assert(sizeof(NBProtectiveCommandABI) == 64, "protective command ABI drift");
static_assert(sizeof(NBMotorChannelDescriptorABI) == 32, "motor channel ABI drift");
static_assert(sizeof(NBMotorOutputHeaderABI) == 64, "motor output ABI drift");
static_assert(sizeof(NBBodyLoadFieldUniformsABI) == 32, "body-load uniforms drift");
static_assert(sizeof(NBBodyLoadFieldRecordABI) == 56, "body-load record drift");
static_assert(sizeof(NBBodySchemaUniformsABI) == 56, "body-schema uniforms drift");
static_assert(sizeof(NBBodySchemaRecordABI) == 48, "body-schema record drift");
static_assert(sizeof(NBMuscleAttachmentRecordABI) == 16, "attachment record drift");
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
constant uint NBProtectiveCommandVersion = 1u;
constant uint NBProtectiveCommandFlagValid = 1u << 0;
constant uint NBProtectiveCommandFlagEmergencyStop = 1u << 1;
constant uint NBProtectiveCommandFlagWithdrawal = 1u << 2;
constant uint NBProtectiveCommandFlagPosturalBrace = 1u << 3;
constant uint NBProtectiveCommandFlagAutonomicArousal = 1u << 4;
constant uint NBMotorOutputVersion = 2u;
constant uint NBMotorOutputFlagValid = 1u << 0;
constant uint NBMotorOutputFlagEmergencyStop = 1u << 1;
constant uint NBMotorOutputFlagLocalizedSourceInhibition = 1u << 2;
constant uint NBMotorOutputFlagLocalizedWithdrawal = 1u << 3;
constant ulong NBInterruptPain = 1ul << 0;
constant ulong NBInterruptDamagingContact = 1ul << 1;
constant ulong NBInterruptLossOfSupport = 1ul << 2;
constant ulong NBInterruptImpact = 1ul << 3;
constant ulong NBInterruptPhysiologicalCritical = 1ul << 4;
constant ulong NBInterruptJointLimit = 1ul << 5;
constant ulong NBInterruptMuscleOverload = 1ul << 6;
constant ulong NBInterruptRescue = 1ul << 9;
constant uint NBCPGOutputSomaticSynergy = 1u;
constant uint NBCPGOutputAutonomicChannel = 2u;

inline ulong cognitive_interrupt_mask_for_event_kind(uint kind) {
    switch (kind) {
        case 3u: return NBInterruptImpact;
        case 5u: return NBInterruptLossOfSupport;
        case 6u: return NBInterruptJointLimit;
        case 7u: return NBInterruptMuscleOverload;
        case 8u: return NBInterruptPain;
        case 9u: return NBInterruptDamagingContact;
        case 10u: return 1ul << 7u;
        case 11u: return 1ul << 8u;
        case 12u: return NBInterruptPhysiologicalCritical;
        case 13u: return NBInterruptRescue;
        default: return 0ul;
    }
}

inline void protective_mix_byte(thread ulong &hash, uchar byte) {
    hash ^= ulong(byte);
    hash *= 0x100000001b3ul;
}

inline void protective_mix_uint(thread ulong &hash, uint value) {
    for (uint byte = 0u; byte < 4u; ++byte) {
        protective_mix_byte(hash, uchar(value >> (byte * 8u)));
    }
}

inline void protective_mix_ulong(thread ulong &hash, ulong value) {
    for (uint byte = 0u; byte < 8u; ++byte) {
        protective_mix_byte(hash, uchar(value >> (byte * 8u)));
    }
}

inline void protective_mix_float(thread ulong &hash, float value) {
    protective_mix_uint(hash, as_type<uint>(value));
}

inline ulong protective_command_fingerprint(
    thread const NBProtectiveCommandABI &command
) {
    ulong hash = 0xcbf29ce484222325ul;
    protective_mix_uint(hash, NBProtectiveCommandVersion);
    protective_mix_uint(hash, command.format_version);
    protective_mix_uint(hash, command.flags);
    protective_mix_ulong(hash, command.timestamp_microseconds);
    protective_mix_ulong(hash, command.brain_generation);
    protective_mix_ulong(hash, command.interrupt_mask);
    protective_mix_float(hash, command.withdrawal_drive);
    protective_mix_float(hash, command.postural_stiffness);
    protective_mix_float(hash, command.motor_inhibition);
    protective_mix_float(hash, command.autonomic_arousal);
    protective_mix_uint(hash, command.environment_identifier);
    protective_mix_uint(hash, command.reserved);
    return hash;
}

inline ulong motor_output_fingerprint(
    thread const NBMotorOutputHeaderABI &header,
    device const float *muscleExcitations
) {
    ulong hash = 0xcbf29ce484222325ul;
    protective_mix_uint(hash, NBMotorOutputVersion);
    protective_mix_uint(hash, header.format_version);
    protective_mix_uint(hash, header.flags);
    protective_mix_ulong(hash, header.timestamp_microseconds);
    protective_mix_ulong(hash, header.brain_generation);
    protective_mix_ulong(hash, header.profile_fingerprint);
    protective_mix_ulong(hash, header.protective_command_fingerprint);
    protective_mix_uint(hash, header.muscle_count);
    protective_mix_uint(hash, header.environment_identifier);
    protective_mix_float(hash, header.motor_inhibition);
    protective_mix_float(hash, header.autonomic_arousal);
    for (uint index = 0u; index < header.muscle_count; ++index) {
        protective_mix_float(hash, muscleExcitations[index]);
    }
    return hash;
}

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
    if (lhs.flags != rhs.flags) {
        return lhs.flags < rhs.flags;
    }
    if (as_type<uint>(lhs.magnitude) != as_type<uint>(rhs.magnitude)) {
        return as_type<uint>(lhs.magnitude) < as_type<uint>(rhs.magnitude);
    }
    return as_type<uint>(lhs.auxiliary_value)
        < as_type<uint>(rhs.auxiliary_value);
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
    device const NBDispatchCohortUniformsABI *cohortUniforms [[buffer(8)]],
    device const NBDispatchTokenUniformsABI *tokenUniforms [[buffer(9)]],
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
        indirectArguments[0].threadgroups_x = 0u;
        indirectArguments[0].threadgroups_y = 0u;
        indirectArguments[0].threadgroups_z = 0u;
        indirectArguments[1].threadgroups_x = 0u;
        indirectArguments[1].threadgroups_y = 0u;
        indirectArguments[1].threadgroups_z = 0u;
        indirectArguments[2].threadgroups_x = 0u;
        indirectArguments[2].threadgroups_y = 0u;
        indirectArguments[2].threadgroups_z = 0u;
        if (header->plan_version != NBDispatchPlanVersion
            || header->flags != 0u
            || header->group_count == 0u
            || header->entry_count == 0u
            || header->plan_fingerprint == 0ul
            || header->cohort_fingerprint == 0ul
            || parameterVersion->format_version != NBParameterManifestVersion
            || cohortUniforms->plan_fingerprint != header->plan_fingerprint
            || cohortUniforms->parameter_version_fingerprint
                != header->parameter_version_fingerprint
            || cohortUniforms->environment_count == 0u
            || cohortUniforms->module_count == 0u
            || cohortUniforms->flags != 0u
            || tokenUniforms->regional_program_fingerprint
                != parameterVersion->regional_program_fingerprint
            || tokenUniforms->schedule_fingerprint
                != header->schedule_fingerprint
            || tokenUniforms->environment_count
                != cohortUniforms->environment_count
            || tokenUniforms->scalar_count_per_environment == 0u
            || tokenUniforms->total_scalar_count
                != ulong(tokenUniforms->environment_count)
                    * ulong(tokenUniforms->scalar_count_per_environment)
            || header->parameter_version_fingerprint
                != parameterVersion->version_fingerprint
            || header->schedule_fingerprint
                != parameterVersion->schedule_fingerprint) {
            result->status = NBDispatchPlanStatusIdentity;
        } else if (cohortUniforms->environment_count
                > ~0u / cohortUniforms->module_count
            || cohortUniforms->state_count
                != cohortUniforms->environment_count * cohortUniforms->module_count) {
            result->status = NBDispatchPlanStatusCapacity;
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
            indirectArguments[0].threadgroups_x =
                header->entry_count / NBDispatchConsumerThreadgroupWidth
                + (header->entry_count % NBDispatchConsumerThreadgroupWidth == 0u
                    ? 0u
                    : 1u);
            indirectArguments[0].threadgroups_y = 1u;
            indirectArguments[0].threadgroups_z = 1u;
            indirectArguments[1].threadgroups_x =
                cohortUniforms->environment_count / NBDispatchConsumerThreadgroupWidth
                + (cohortUniforms->environment_count
                        % NBDispatchConsumerThreadgroupWidth == 0u
                    ? 0u
                    : 1u);
            indirectArguments[1].threadgroups_y = 1u;
            indirectArguments[1].threadgroups_z = 1u;
            indirectArguments[2].threadgroups_x = tokenUniforms->environment_count;
            indirectArguments[2].threadgroups_y = 1u;
            indirectArguments[2].threadgroups_z = 1u;
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

/// Advances one independent compact regional-state vector per active
/// environment. A lane owns one environment and walks canonical groups in
/// physical-time order, so repeated module updates cannot race.
kernel void advance_cohort_regional_diagnostics(
    device const NBDispatchPlanHeaderABI *header [[buffer(0)]],
    device const NBDispatchCohortUniformsABI *uniforms [[buffer(1)]],
    device const NBDispatchGroupABI *groups [[buffer(2)]],
    device const NBDispatchEntryABI *entries [[buffer(3)]],
    device const uint *environmentIdentifiers [[buffer(4)]],
    device const NBModuleDescriptorABI *modules [[buffer(5)]],
    device const NBRegionalModuleStateABI *inputStates [[buffer(6)]],
    device NBRegionalModuleStateABI *outputStates [[buffer(7)]],
    uint environmentIndex [[thread_position_in_grid]]
) {
    if (environmentIndex >= uniforms->environment_count) {
        return;
    }
    const uint environmentIdentifier = environmentIdentifiers[environmentIndex];
    const uint stateBase = environmentIndex * uniforms->module_count;
    for (uint moduleIndex = 0u;
         moduleIndex < uniforms->module_count;
         ++moduleIndex) {
        outputStates[stateBase + moduleIndex] = inputStates[stateBase + moduleIndex];
    }
    for (uint groupIndex = 0u; groupIndex < header->group_count; ++groupIndex) {
        const NBDispatchGroupABI group = groups[groupIndex];
        uint lower = group.entry_offset;
        uint upper = group.entry_offset + group.entry_count;
        uint entryIndex = ~0u;
        while (lower < upper) {
            const uint middle = lower + (upper - lower) / 2u;
            const uint candidate = entries[middle].environment_identifier;
            if (candidate < environmentIdentifier) {
                lower = middle + 1u;
            } else if (candidate > environmentIdentifier) {
                upper = middle;
            } else {
                entryIndex = middle;
                break;
            }
        }
        if (entryIndex == ~0u) {
            continue;
        }
        uint moduleIndex = ~0u;
        for (uint candidateIndex = 0u;
             candidateIndex < uniforms->module_count;
             ++candidateIndex) {
            if (modules[candidateIndex].module_id == group.module_id) {
                moduleIndex = candidateIndex;
                break;
            }
        }
        if (moduleIndex == ~0u) {
            continue;
        }
        const NBModuleDescriptorABI module = modules[moduleIndex];
        const NBDispatchEntryABI entry = entries[entryIndex];
        const uint stateIndex = stateBase + moduleIndex;
        NBRegionalModuleStateABI state = outputStates[stateIndex];
        const ulong elapsedMicroseconds = state.last_update_microseconds == ~0ul
            ? ulong(module.period_microseconds)
            : group.timestamp_microseconds - state.last_update_microseconds;
        const float decay = exp(
            -float(elapsedMicroseconds) / float(module.intrinsic_timescale_microseconds)
        );
        const float blend = 1.0f - decay;
        const float periodicDrive =
            (entry.reason_flags & NBSchedulerReasonPeriodic) != 0u ? 0.25f : 0.0f;
        const float interruptDrive = min(
            float(popcount(entry.interrupt_mask)) * 0.125f,
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
            group.timestamp_microseconds % ulong(module.period_microseconds)
        ) / float(module.period_microseconds);
        if (state.update_count != ~0u) {
            state.update_count += 1u;
        }
        if ((entry.reason_flags & NBSchedulerReasonInterrupt) != 0u
            && state.interrupt_count != ~0u) {
            state.interrupt_count += 1u;
        }
        state.last_update_microseconds = group.timestamp_microseconds;
        outputStates[stateIndex] = state;
    }
}

/// Advances the authoritative environment-major recurrent token generation
/// for an unrouted regional program. One threadgroup owns one environment;
/// groups remain in canonical physical-time order and each module update reads
/// a stable pre-update token vector before publishing its candidate values.
kernel void advance_cohort_regional_tokens_unrouted(
    device const NBDispatchPlanHeaderABI *planHeader [[buffer(0)]],
    device const NBDispatchCohortUniformsABI *cohortUniforms [[buffer(1)]],
    device const NBDispatchTokenUniformsABI *tokenUniforms [[buffer(2)]],
    device const NBParameterVersionBindingABI *parameterVersion [[buffer(3)]],
    device const NBDispatchGroupABI *groups [[buffer(4)]],
    device const NBDispatchEntryABI *entries [[buffer(5)]],
    device const uint *environmentIdentifiers [[buffer(6)]],
    device const NBModuleDescriptorABI *modules [[buffer(7)]],
    device const NBRegionalProgramHeaderABI *programHeader [[buffer(8)]],
    device const NBRegionalTokenLayoutABI *layouts [[buffer(9)]],
    device const NBRegionalTokenParametersABI *parameters [[buffer(10)]],
    device const NBRegionalModuleStateABI *inputDiagnostics [[buffer(11)]],
    device const float *inputTokens [[buffer(12)]],
    device float *outputTokens [[buffer(13)]],
    device float *candidateTokens [[buffer(14)]],
    device ulong *tokenLastUpdates [[buffer(15)]],
    uint lane [[thread_index_in_threadgroup]],
    uint3 lanesPerThreadgroup [[threads_per_threadgroup]],
    uint3 threadgroupPosition [[threadgroup_position_in_grid]]
) {
    const uint environmentIndex = threadgroupPosition.x;
    if (environmentIndex >= cohortUniforms->environment_count
        || programHeader->route_count != 0u
        || programHeader->module_count != cohortUniforms->module_count
        || programHeader->token_scalar_count
            != tokenUniforms->scalar_count_per_environment
        || programHeader->parameter_count != programHeader->token_scalar_count
        || programHeader->program_fingerprint
            != tokenUniforms->regional_program_fingerprint
        || programHeader->program_fingerprint
            != parameterVersion->regional_program_fingerprint
        || tokenUniforms->schedule_fingerprint
            != parameterVersion->schedule_fingerprint) {
        return;
    }
    const uint laneCount = lanesPerThreadgroup.x;
    const uint environmentIdentifier = environmentIdentifiers[environmentIndex];
    const ulong tokenBase = ulong(environmentIndex)
        * ulong(programHeader->token_scalar_count);
    const uint diagnosticBase = environmentIndex * cohortUniforms->module_count;
    for (uint scalarIndex = lane;
         scalarIndex < programHeader->token_scalar_count;
         scalarIndex += laneCount) {
        outputTokens[tokenBase + ulong(scalarIndex)] =
            inputTokens[tokenBase + ulong(scalarIndex)];
    }
    for (uint moduleIndex = lane;
         moduleIndex < cohortUniforms->module_count;
         moduleIndex += laneCount) {
        tokenLastUpdates[diagnosticBase + moduleIndex] =
            inputDiagnostics[diagnosticBase + moduleIndex].last_update_microseconds;
    }
    threadgroup_barrier(mem_flags::mem_device);

    threadgroup uint active;
    threadgroup uint activeModuleIndex;
    threadgroup float activeAlpha;
    threadgroup float activeDrive;
    for (uint groupIndex = 0u; groupIndex < planHeader->group_count; ++groupIndex) {
        const NBDispatchGroupABI group = groups[groupIndex];
        if (lane == 0u) {
            active = 0u;
            uint lower = group.entry_offset;
            uint upper = group.entry_offset + group.entry_count;
            while (lower < upper) {
                const uint middle = lower + (upper - lower) / 2u;
                const uint candidate = entries[middle].environment_identifier;
                if (candidate < environmentIdentifier) {
                    lower = middle + 1u;
                } else if (candidate > environmentIdentifier) {
                    upper = middle;
                } else {
                    uint moduleIndex = ~0u;
                    for (uint candidateIndex = 0u;
                         candidateIndex < cohortUniforms->module_count;
                         ++candidateIndex) {
                        if (modules[candidateIndex].module_id == group.module_id) {
                            moduleIndex = candidateIndex;
                            break;
                        }
                    }
                    if (moduleIndex != ~0u) {
                        const NBModuleDescriptorABI module = modules[moduleIndex];
                        const NBDispatchEntryABI entry = entries[middle];
                        const ulong lastUpdate = tokenLastUpdates[
                            diagnosticBase + moduleIndex
                        ];
                        const ulong elapsedMicroseconds = lastUpdate == ~0ul
                            ? ulong(module.period_microseconds)
                            : group.timestamp_microseconds - lastUpdate;
                        activeModuleIndex = moduleIndex;
                        activeAlpha = 1.0f - exp(
                            -float(elapsedMicroseconds)
                                / float(module.intrinsic_timescale_microseconds)
                        );
                        const float periodicDrive =
                            (entry.reason_flags & NBSchedulerReasonPeriodic) != 0u
                            ? 0.25f
                            : 0.0f;
                        const float interruptDrive = min(
                            float(popcount(entry.interrupt_mask)) * 0.125f,
                            1.0f
                        );
                        activeDrive = periodicDrive + interruptDrive;
                        active = 1u;
                    }
                    break;
                }
            }
        }
        threadgroup_barrier(mem_flags::mem_device);
        if (active == 0u) {
            continue;
        }

        const NBRegionalTokenLayoutABI layout = layouts[activeModuleIndex];
        for (uint localScalar = lane;
             localScalar < layout.scalar_count;
             localScalar += laneCount) {
            const uint scalarIndex = layout.scalar_offset + localScalar;
            const uint dimension = uint(layout.token_dimension);
            const uint tokenStart = layout.scalar_offset
                + (localScalar / dimension) * dimension;
            float localSum = 0.0f;
            for (uint localFeature = 0u;
                 localFeature < dimension;
                 ++localFeature) {
                localSum += outputTokens[
                    tokenBase + ulong(tokenStart + localFeature)
                ];
            }
            const float localMean = localSum / float(dimension);
            const NBRegionalTokenParametersABI parameter = parameters[
                layout.parameter_offset + localScalar
            ];
            const ulong absoluteScalar = tokenBase + ulong(scalarIndex);
            const float current = outputTokens[absoluteScalar];
            const float candidate = tanh(
                parameter.recurrent_gain * current
                + parameter.local_gain * localMean
                + parameter.drive_gain * activeDrive
                + parameter.bias
            );
            const float gateInput = parameter.gate_bias
                + parameter.gate_recurrent_gain * current
                + parameter.gate_input_gain * activeDrive;
            const float gate = 1.0f / (1.0f + exp(-gateInput));
            candidateTokens[absoluteScalar] = current
                + activeAlpha * gate * (candidate - current);
        }
        threadgroup_barrier(mem_flags::mem_device);
        for (uint localScalar = lane;
             localScalar < layout.scalar_count;
             localScalar += laneCount) {
            const ulong absoluteScalar = tokenBase
                + ulong(layout.scalar_offset + localScalar);
            outputTokens[absoluteScalar] = candidateTokens[absoluteScalar];
        }
        if (lane == 0u) {
            tokenLastUpdates[diagnosticBase + activeModuleIndex] =
                group.timestamp_microseconds;
        }
        threadgroup_barrier(mem_flags::mem_device);
    }
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
    device NBCognitiveEventQueueHeaderABI *cognitiveEventQueue
        [[buffer(5)]],
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
    uint receptorCount = 0u;
    for (uint index = 0u; index < uniforms->host_event_count; ++index) {
        if (outputCount >= uniforms->event_capacity) {
            result->status = NBReceptorTransductionStatusEventCapacity;
            return;
        }
        outputEvents[outputCount++] = hostEvents[index];
    }

    const uint cognitiveMaximumCount = uniforms->reserved_0;
    if (cognitiveMaximumCount > 0u) {
        const uint cognitiveCount = atomic_load_explicit(
            &cognitiveEventQueue->count,
            memory_order_relaxed
        );
        const uint overflowCount = atomic_load_explicit(
            &cognitiveEventQueue->overflow_count,
            memory_order_relaxed
        );
        if ((cognitiveEventQueue->flags & 1u) == 0u
            || cognitiveEventQueue->target_timestamp_microseconds
                != uniforms->committed_time_microseconds
            || cognitiveEventQueue->capacity < cognitiveMaximumCount
            || cognitiveCount > cognitiveMaximumCount
            || overflowCount != 0u) {
            result->status = NBReceptorTransductionStatusEventCapacity;
            return;
        }
        device const NBCognitiveReceptorEventABI *cognitiveEvents =
            reinterpret_cast<device const NBCognitiveReceptorEventABI *>(
                cognitiveEventQueue + 1
            );
        for (uint index = 0u; index < cognitiveCount; ++index) {
            const NBCognitiveReceptorEventABI receptor = cognitiveEvents[index];
            if (receptor.timestamp_microseconds
                    < uniforms->committed_time_microseconds
                || receptor.timestamp_microseconds
                    > uniforms->target_time_microseconds
                || !isfinite(receptor.magnitude)
                || receptor.magnitude < 0.0f
                || !isfinite(receptor.auxiliary_value)) {
                result->status = NBReceptorTransductionStatusTimeOverflow;
                return;
            }
            if (outputCount >= uniforms->event_capacity) {
                result->status = NBReceptorTransductionStatusEventCapacity;
                return;
            }
            NBInterruptEventABI event;
            event.timestamp_microseconds = receptor.timestamp_microseconds;
            event.interrupt_mask = cognitive_interrupt_mask_for_event_kind(
                receptor.kind
            );
            event.identifier = receptor.source_identifier;
            event.flags = receptor.flags | NBInterruptEventFlagReceptorDerived;
            event.magnitude = receptor.magnitude;
            event.auxiliary_value = receptor.auxiliary_value;
            outputEvents[outputCount++] = event;
            receptorCount += 1u;
        }
    }

    const bool includeCommittedBoundary =
        (uniforms->flags & NBSchedulerFlagInitialize) != 0u;
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
        event.magnitude = receptor.magnitude;
        event.auxiliary_value = receptor.auxiliary_value;
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
    device const NBRegionalMaturationRecordABI *maturation [[buffer(9)]],
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
        const bool unlocked = maturation[moduleIndex].module_identifier
                == uint(module.module_id)
            && maturation[moduleIndex].unlocked != 0u;
        NBModuleClockStateABI clock = inputClocks[moduleIndex];
        if (initialize) {
            clock.next_due_microseconds = uniforms->committed_time_microseconds;
            clock.last_update_microseconds = neverUpdated;
        }
        ulong nextDue = clock.next_due_microseconds;
        while (nextDue <= uniforms->target_time_microseconds) {
            if (unlocked) {
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
            }
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

inline float cohort_regional_route_message_value(
    uint routeIndex,
    ulong timestamp,
    uint feature,
    device const NBRegionalProgramHeaderABI *header,
    device const NBRegionalTokenLayoutABI *layouts,
    device const NBRegionalRouteABI *routes,
    device const float *tokens,
    ulong tokenBase,
    device const float *routeHistoryValues,
    ulong historyValueBase,
    device const uint *resolvedRouteHistorySlots,
    uint routeBase
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
            tokenBase + ulong(sender.scalar_offset)
            + ulong(route.sender_token) * ulong(sender.token_dimension)
            + ulong(senderFeature)
        ];
    }
    if (timestamp < ulong(route.delay_microseconds)) {
        return 0.0f;
    }
    const uint resolvedSlot = resolvedRouteHistorySlots[routeBase + routeIndex];
    if (resolvedSlot == ~0u) {
        return 0.0f;
    }
    return routeHistoryValues[
        historyValueBase + ulong(route.history_value_offset)
        + ulong(resolvedSlot) * ulong(route.message_dimension)
        + ulong(feature % route.message_dimension)
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
    device const NBRegionalPlasticModulationRecordABI *plasticModulation
        [[buffer(24)]],
    device const NBRegionalMaturationRecordABI *maturation [[buffer(25)]],
    device const float *routeParameters [[buffer(26)]],
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
            const NBRegionalMaturationRecordABI maturationRecord =
                maturation[moduleIndex];
            const bool validMaturation = maturationRecord.module_identifier
                    == uint(receiver.module_id)
                && maturationRecord.unlocked != 0u;
            const uint effectiveNormalRouteBudget = validMaturation
                ? min(
                    uint(receiver.normal_route_budget),
                    uint(ceil(
                        float(receiver.normal_route_budget)
                            * clamp(maturationRecord.capacity_fraction, 0.0f, 1.0f)
                    ))
                )
                : 0u;
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
                state.score = routeParameters[0] * dot / sqrt(float(queryDimension))
                    + routeParameters[1] * header->salience_gain
                        * salience / float(queryDimension);
                if (state.active != 0u) {
                    state.score += routeParameters[2] * header->persistence_bonus;
                } else {
                    state.score -= max(routeParameters[4], 0.0f);
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
                     && normalSelected < effectiveNormalRouteBudget;
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
            while (normalSelected < effectiveNormalRouteBudget) {
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
                    (outputRouteRuntimeStates[
                        selectedRouteIndices[routeBegin + selectedIndex]
                    ].score - maximumScore) / max(routeParameters[5], 1.0e-4f)
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
                    ? exp(
                        (state.score - maximumScore)
                            / max(routeParameters[5], 1.0e-4f)
                      ) / strengthDenominator
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
            const NBRegionalMaturationRecordABI maturationRecord =
                maturation[moduleIndex];
            const NBRegionalPlasticModulationRecordABI plastic =
                plasticModulation[moduleIndex];
            const bool validMaturation = maturationRecord.module_identifier
                    == uint(module.module_id)
                && maturationRecord.unlocked != 0u;
            const bool validPlastic = plastic.module_identifier
                    == uint(module.module_id)
                && plastic.coefficient_count > 0u
                && (plastic.flags & 1u) != 0u;
            const NBRegionalModuleStateABI diagnostic = outputDiagnostics[moduleIndex];
            const ulong elapsedMicroseconds = diagnostic.last_update_microseconds == neverUpdated
                ? ulong(module.period_microseconds)
                : invocation.timestamp_microseconds - diagnostic.last_update_microseconds;
            const float alpha = 1.0f - exp(
                -float(elapsedMicroseconds) /
                    (float(module.intrinsic_timescale_microseconds)
                        * max(
                            validMaturation
                                ? maturationRecord.timescale_multiplier
                                : 1.0f,
                            0.05f
                        ))
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
                routedInput += routeParameters[3] * route.gain
                    * (validMaturation ? maturationRecord.route_gain_multiplier : 1.0f)
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
                (parameter.recurrent_gain
                    + (validPlastic ? plastic.recurrent_delta : 0.0f)) * current
                + (parameter.local_gain
                    + (validPlastic ? plastic.local_delta : 0.0f)) * localMean
                + (parameter.route_gain
                    + (validPlastic ? plastic.route_delta : 0.0f)) * routedInput
                + (parameter.drive_gain
                    + (validPlastic ? plastic.drive_delta : 0.0f)) * drive
                + parameter.bias
            );
            const float gateInput = parameter.gate_bias
                + (validPlastic ? plastic.gate_delta : 0.0f)
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

inline uint cohort_entry_index(
    NBDispatchGroupABI group,
    device const NBDispatchEntryABI *entries,
    uint environmentIdentifier
) {
    uint lower = group.entry_offset;
    uint upper = group.entry_offset + group.entry_count;
    while (lower < upper) {
        const uint middle = lower + (upper - lower) / 2u;
        const uint candidate = entries[middle].environment_identifier;
        if (candidate < environmentIdentifier) {
            lower = middle + 1u;
        } else if (candidate > environmentIdentifier) {
            upper = middle;
        } else {
            return middle;
        }
    }
    return ~0u;
}

/// Converts the group-major dispatch plan into one fixed-capacity canonical
/// invocation span per environment. Lanes own contiguous group ranges, perform
/// a deterministic inclusive scan of match counts, and scatter in group order.
kernel void compact_cohort_invocations(
    device const NBDispatchPlanHeaderABI *planHeader [[buffer(0)]],
    device const NBDispatchCohortUniformsABI *cohortUniforms [[buffer(1)]],
    device const NBDispatchGroupABI *groups [[buffer(2)]],
    device const NBDispatchEntryABI *entries [[buffer(3)]],
    device const uint *environmentIdentifiers [[buffer(4)]],
    device NBDueInvocationABI *outputInvocations [[buffer(5)]],
    device uint *outputCounts [[buffer(6)]],
    uint lane [[thread_index_in_threadgroup]],
    uint3 lanesPerThreadgroup [[threads_per_threadgroup]],
    uint3 threadgroupPosition [[threadgroup_position_in_grid]]
) {
    const uint environmentIndex = threadgroupPosition.x;
    const uint laneCount = lanesPerThreadgroup.x;
    if (environmentIndex >= cohortUniforms->environment_count
        || laneCount == 0u
        || laneCount > 64u) {
        return;
    }
    const uint environmentIdentifier = environmentIdentifiers[environmentIndex];
    const ulong outputBase =
        ulong(environmentIndex) * ulong(planHeader->group_count);
    const uint groupsPerLane =
        (planHeader->group_count + laneCount - 1u) / laneCount;
    const uint groupBegin = min(lane * groupsPerLane, planHeader->group_count);
    const uint groupEnd = min(groupBegin + groupsPerLane, planHeader->group_count);
    uint localCount = 0u;
    for (uint groupIndex = groupBegin; groupIndex < groupEnd; ++groupIndex) {
        const NBDispatchGroupABI group = groups[groupIndex];
        if (cohort_entry_index(group, entries, environmentIdentifier) != ~0u) {
            localCount += 1u;
        }
    }
    threadgroup uint inclusiveCounts[64];
    inclusiveCounts[lane] = localCount;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint offset = 1u; offset < laneCount; offset <<= 1u) {
        const uint addend = lane >= offset
            ? inclusiveCounts[lane - offset]
            : 0u;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        inclusiveCounts[lane] += addend;
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    uint outputIndex = lane == 0u ? 0u : inclusiveCounts[lane - 1u];
    for (uint groupIndex = groupBegin; groupIndex < groupEnd; ++groupIndex) {
        const NBDispatchGroupABI group = groups[groupIndex];
        const uint entryIndex = cohort_entry_index(
            group,
            entries,
            environmentIdentifier
        );
        if (entryIndex == ~0u) {
            continue;
        }
        const NBDispatchEntryABI entry = entries[entryIndex];
        NBDueInvocationABI invocation;
        invocation.timestamp_microseconds = group.timestamp_microseconds;
        invocation.interrupt_mask = entry.interrupt_mask;
        invocation.environment_identifier = environmentIdentifier;
        invocation.module_id = group.module_id;
        invocation.clock_class = group.clock_class;
        invocation.reason_flags = entry.reason_flags;
        invocation.reserved = 0u;
        outputInvocations[outputBase + ulong(outputIndex)] = invocation;
        outputIndex += 1u;
    }
    if (lane == 0u) {
        outputCounts[environmentIndex] = inclusiveCounts[laneCount - 1u];
    }
}

/// Routed cohort token operator. One 64-lane threadgroup owns every recurrent,
/// history, and routing-state write for one environment. Modules sharing a
/// physical timestamp read one pre-timestamp generation and publish together.
kernel void advance_cohort_regional_tokens_routed(
    device const NBDispatchPlanHeaderABI *planHeader [[buffer(0)]],
    device const NBDispatchCohortUniformsABI *cohortUniforms [[buffer(1)]],
    device const NBDispatchTokenUniformsABI *tokenUniforms [[buffer(2)]],
    device const NBParameterVersionBindingABI *parameterVersion [[buffer(3)]],
    device const NBDueInvocationABI *compactedInvocations [[buffer(4)]],
    device const uint *compactedInvocationCounts [[buffer(5)]],
    device const uint *environmentIdentifiers [[buffer(6)]],
    device const NBModuleDescriptorABI *modules [[buffer(7)]],
    device const NBRegionalProgramHeaderABI *header [[buffer(8)]],
    device const NBRegionalTokenLayoutABI *layouts [[buffer(9)]],
    device const NBRegionalTokenParametersABI *parameters [[buffer(10)]],
    device const NBRegionalModuleStateABI *inputDiagnostics [[buffer(11)]],
    device const float *inputTokens [[buffer(12)]],
    device float *outputTokens [[buffer(13)]],
    device float *candidateTokens [[buffer(14)]],
    device ulong *tokenLastUpdates [[buffer(15)]],
    device const NBRegionalRouteABI *routes [[buffer(16)]],
    device const NBRegionalRouteHistoryStateABI *inputRouteHistoryStates [[buffer(17)]],
    device NBRegionalRouteHistoryStateABI *outputRouteHistoryStates [[buffer(18)]],
    device const ulong *inputRouteHistoryTimestamps [[buffer(19)]],
    device ulong *outputRouteHistoryTimestamps [[buffer(20)]],
    device const float *inputRouteHistoryValues [[buffer(21)]],
    device float *outputRouteHistoryValues [[buffer(22)]],
    device uint *resolvedRouteHistorySlots [[buffer(23)]],
    device const NBRegionalRouteRuntimeStateABI *inputRouteRuntimeStates [[buffer(24)]],
    device NBRegionalRouteRuntimeStateABI *outputRouteRuntimeStates [[buffer(25)]],
    device uint *selectedRouteIndices [[buffer(26)]],
    device uint *selectedRouteCounts [[buffer(27)]],
    device const float *routeParameters [[buffer(28)]],
    uint lane [[thread_index_in_threadgroup]],
    uint3 lanesPerThreadgroup [[threads_per_threadgroup]],
    uint3 threadgroupPosition [[threadgroup_position_in_grid]]
) {
    const uint environmentIndex = threadgroupPosition.x;
    if (environmentIndex >= cohortUniforms->environment_count
        || header->route_count == 0u
        || header->module_count != cohortUniforms->module_count
        || header->token_scalar_count
            != tokenUniforms->scalar_count_per_environment
        || header->parameter_count != header->token_scalar_count
        || header->program_fingerprint
            != tokenUniforms->regional_program_fingerprint
        || header->program_fingerprint
            != parameterVersion->regional_program_fingerprint
        || tokenUniforms->schedule_fingerprint
            != parameterVersion->schedule_fingerprint) {
        return;
    }
    const uint laneCount = lanesPerThreadgroup.x;
    const uint environmentIdentifier = environmentIdentifiers[environmentIndex];
    const ulong tokenBase = ulong(environmentIndex)
        * ulong(header->token_scalar_count);
    const uint diagnosticBase = environmentIndex * header->module_count;
    const uint routeBase = environmentIndex * header->route_count;
    const ulong historyTimestampBase = ulong(environmentIndex)
        * ulong(header->route_count) * ulong(header->history_capacity);
    const ulong historyValueBase = ulong(environmentIndex)
        * ulong(header->history_scalar_count);
    device const NBDueInvocationABI *invocations = compactedInvocations
        + ulong(environmentIndex) * ulong(planHeader->group_count);
    const uint invocationCount = compactedInvocationCounts[environmentIndex];
    if (invocationCount > planHeader->group_count
        || (invocationCount > 0u
            && invocations[0].environment_identifier != environmentIdentifier)) {
        return;
    }

    for (uint scalarIndex = lane;
         scalarIndex < header->token_scalar_count;
         scalarIndex += laneCount) {
        outputTokens[tokenBase + ulong(scalarIndex)] =
            inputTokens[tokenBase + ulong(scalarIndex)];
    }
    for (uint moduleIndex = lane;
         moduleIndex < header->module_count;
         moduleIndex += laneCount) {
        tokenLastUpdates[diagnosticBase + moduleIndex] =
            inputDiagnostics[diagnosticBase + moduleIndex].last_update_microseconds;
    }
    for (uint routeIndex = lane;
         routeIndex < header->route_count;
         routeIndex += laneCount) {
        outputRouteHistoryStates[routeBase + routeIndex] =
            inputRouteHistoryStates[routeBase + routeIndex];
        outputRouteRuntimeStates[routeBase + routeIndex] =
            inputRouteRuntimeStates[routeBase + routeIndex];
    }
    const uint historyTimestampCount =
        header->route_count * header->history_capacity;
    for (uint timestampIndex = lane;
         timestampIndex < historyTimestampCount;
         timestampIndex += laneCount) {
        outputRouteHistoryTimestamps[historyTimestampBase + ulong(timestampIndex)] =
            inputRouteHistoryTimestamps[historyTimestampBase + ulong(timestampIndex)];
    }
    for (uint historyScalarIndex = lane;
         historyScalarIndex < header->history_scalar_count;
         historyScalarIndex += laneCount) {
        outputRouteHistoryValues[historyValueBase + ulong(historyScalarIndex)] =
            inputRouteHistoryValues[historyValueBase + ulong(historyScalarIndex)];
    }
    threadgroup_barrier(mem_flags::mem_device);

    const ulong neverUpdated = ~0ul;
    uint cursor = 0u;
    while (cursor < invocationCount) {
        const ulong timestamp = invocations[cursor].timestamp_microseconds;
        uint groupEnd = cursor + 1u;
        while (groupEnd < invocationCount
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
                const ulong targetTimestamp =
                    timestamp - ulong(route.delay_microseconds);
                const NBRegionalRouteHistoryStateABI history =
                    outputRouteHistoryStates[routeBase + routeIndex];
                for (uint age = 0u; age < history.count; ++age) {
                    const uint slot = (
                        history.next_slot + header->history_capacity - 1u - age
                    ) % header->history_capacity;
                    const ulong messageTimestamp = outputRouteHistoryTimestamps[
                        historyTimestampBase
                        + ulong(routeIndex * header->history_capacity + slot)
                    ];
                    if (messageTimestamp <= targetTimestamp) {
                        resolvedSlot = slot;
                        break;
                    }
                }
            }
            resolvedRouteHistorySlots[routeBase + routeIndex] = resolvedSlot;
        }
        threadgroup_barrier(mem_flags::mem_device);

        for (uint moduleIndex = lane;
             moduleIndex < header->module_count;
             moduleIndex += laneCount) {
            selectedRouteCounts[diagnosticBase + moduleIndex] = 0u;
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
                    const float message = cohort_regional_route_message_value(
                        routeIndex,
                        timestamp,
                        feature,
                        header,
                        layouts,
                        routes,
                        outputTokens,
                        tokenBase,
                        outputRouteHistoryValues,
                        historyValueBase,
                        resolvedRouteHistorySlots,
                        routeBase
                    );
                    dot += outputTokens[
                        tokenBase + ulong(receiver.scalar_offset + feature)
                    ] * message;
                    salience += abs(message);
                }
                NBRegionalRouteRuntimeStateABI state =
                    outputRouteRuntimeStates[routeBase + routeIndex];
                state.score = routeParameters[0] * dot / sqrt(float(queryDimension))
                    + routeParameters[1] * header->salience_gain
                        * salience / float(queryDimension);
                if (state.active != 0u) {
                    state.score += routeParameters[2] * header->persistence_bonus;
                } else {
                    state.score -= max(routeParameters[4], 0.0f);
                }
                outputRouteRuntimeStates[routeBase + routeIndex] = state;
            }

            uint selectedCount = 0u;
            uint normalSelected = 0u;
            for (uint routeIndex = routeBegin;
                 routeIndex < routeEnd;
                 ++routeIndex) {
                if ((routes[routeIndex].flags & 1u) != 0u) {
                    selectedRouteIndices[routeBase + routeBegin + selectedCount] =
                        routeIndex;
                    selectedCount += 1u;
                }
            }
            for (uint routeIndex = routeBegin;
                 routeIndex < routeEnd
                     && normalSelected < uint(receiver.normal_route_budget);
                 ++routeIndex) {
                const NBRegionalRouteABI route = routes[routeIndex];
                const NBRegionalRouteRuntimeStateABI state =
                    outputRouteRuntimeStates[routeBase + routeIndex];
                if ((route.flags & 1u) != 0u
                    || state.active == 0u
                    || state.last_selected_timestamp_microseconds == ~0ul
                    || timestamp < state.last_selected_timestamp_microseconds) {
                    continue;
                }
                if (timestamp - state.last_selected_timestamp_microseconds
                    < ulong(header->minimum_route_persistence_microseconds)) {
                    selectedRouteIndices[routeBase + routeBegin + selectedCount] =
                        routeIndex;
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
                        if (selectedRouteIndices[
                                routeBase + routeBegin + selectedIndex
                            ] == routeIndex) {
                            alreadySelected = true;
                            break;
                        }
                    }
                    if (alreadySelected) {
                        continue;
                    }
                    const float score = outputRouteRuntimeStates[
                        routeBase + routeIndex
                    ].score;
                    if (score > bestScore) {
                        bestScore = score;
                        bestRoute = routeIndex;
                    }
                }
                if (bestRoute == ~0u) {
                    break;
                }
                selectedRouteIndices[routeBase + routeBegin + selectedCount] =
                    bestRoute;
                selectedCount += 1u;
                normalSelected += 1u;
            }

            float maximumScore = 0.0f;
            if (selectedCount > 0u) {
                maximumScore = outputRouteRuntimeStates[
                    routeBase + selectedRouteIndices[routeBase + routeBegin]
                ].score;
                for (uint selectedIndex = 1u;
                     selectedIndex < selectedCount;
                     ++selectedIndex) {
                    maximumScore = max(
                        maximumScore,
                        outputRouteRuntimeStates[
                            routeBase + selectedRouteIndices[
                                routeBase + routeBegin + selectedIndex
                            ]
                        ].score
                    );
                }
            }
            float strengthDenominator = 0.0f;
            for (uint selectedIndex = 0u;
                 selectedIndex < selectedCount;
                 ++selectedIndex) {
                strengthDenominator += exp(
                    (outputRouteRuntimeStates[
                        routeBase + selectedRouteIndices[
                            routeBase + routeBegin + selectedIndex
                        ]
                    ].score - maximumScore) / max(routeParameters[5], 1.0e-4f)
                );
            }
            for (uint routeIndex = routeBegin;
                 routeIndex < routeEnd;
                 ++routeIndex) {
                NBRegionalRouteRuntimeStateABI state =
                    outputRouteRuntimeStates[routeBase + routeIndex];
                const bool wasActive = state.active != 0u;
                bool isActive = false;
                for (uint selectedIndex = 0u;
                     selectedIndex < selectedCount;
                     ++selectedIndex) {
                    if (selectedRouteIndices[
                            routeBase + routeBegin + selectedIndex
                        ] == routeIndex) {
                        isActive = true;
                        break;
                    }
                }
                state.active = isActive ? 1u : 0u;
                state.strength = isActive && strengthDenominator > 0.0f
                    ? exp(
                        (state.score - maximumScore)
                            / max(routeParameters[5], 1.0e-4f)
                      ) / strengthDenominator
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
                outputRouteRuntimeStates[routeBase + routeIndex] = state;
            }
            selectedRouteCounts[diagnosticBase + moduleIndex] = selectedCount;
        }
        threadgroup_barrier(mem_flags::mem_device);

        for (uint scalarIndex = lane;
             scalarIndex < header->token_scalar_count;
             scalarIndex += laneCount) {
            uint moduleIndex = 0u;
            for (; moduleIndex < header->module_count; ++moduleIndex) {
                const NBRegionalTokenLayoutABI candidateLayout = layouts[moduleIndex];
                if (scalarIndex >= candidateLayout.scalar_offset
                    && scalarIndex < candidateLayout.scalar_offset
                        + candidateLayout.scalar_count) {
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
            const ulong absoluteScalar = tokenBase + ulong(scalarIndex);
            if (!due) {
                candidateTokens[absoluteScalar] = outputTokens[absoluteScalar];
                continue;
            }

            const NBModuleDescriptorABI module = modules[moduleIndex];
            const ulong lastUpdate = tokenLastUpdates[diagnosticBase + moduleIndex];
            const ulong elapsedMicroseconds = lastUpdate == neverUpdated
                ? ulong(module.period_microseconds)
                : timestamp - lastUpdate;
            const float alpha = 1.0f - exp(
                -float(elapsedMicroseconds)
                    / float(module.intrinsic_timescale_microseconds)
            );
            const float periodicDrive =
                (invocation.reason_flags & NBSchedulerReasonPeriodic) != 0u
                ? 0.25f
                : 0.0f;
            const float interruptDrive = min(
                float(popcount(invocation.interrupt_mask)) * 0.125f,
                1.0f
            );
            const float drive = periodicDrive + interruptDrive;
            const uint localScalar = scalarIndex - layout.scalar_offset;
            const uint dimension = uint(layout.token_dimension);
            const uint tokenStart = layout.scalar_offset
                + (localScalar / dimension) * dimension;
            const uint feature = localScalar % dimension;
            float localSum = 0.0f;
            for (uint localFeature = 0u;
                 localFeature < dimension;
                 ++localFeature) {
                localSum += outputTokens[
                    tokenBase + ulong(tokenStart + localFeature)
                ];
            }
            const float localMean = localSum / float(dimension);
            float routedInput = 0.0f;
            const uint selectedCount =
                selectedRouteCounts[diagnosticBase + moduleIndex];
            for (uint selectedIndex = 0u;
                 selectedIndex < selectedCount;
                 ++selectedIndex) {
                const uint routeIndex = selectedRouteIndices[
                    routeBase + layout.incoming_route_offset + selectedIndex
                ];
                const NBRegionalRouteABI route = routes[routeIndex];
                routedInput += routeParameters[3] * route.gain
                    * outputRouteRuntimeStates[routeBase + routeIndex].strength
                    * cohort_regional_route_message_value(
                        routeIndex,
                        timestamp,
                        feature,
                        header,
                        layouts,
                        routes,
                        outputTokens,
                        tokenBase,
                        outputRouteHistoryValues,
                        historyValueBase,
                        resolvedRouteHistorySlots,
                        routeBase
                    );
            }
            const NBRegionalTokenParametersABI parameter =
                parameters[layout.parameter_offset + localScalar];
            const float current = outputTokens[absoluteScalar];
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
            candidateTokens[absoluteScalar] = current
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
                const ulong absoluteScalar = tokenBase + ulong(scalarIndex);
                outputTokens[absoluteScalar] = candidateTokens[absoluteScalar];
            }
        }
        for (uint moduleIndex = lane;
             moduleIndex < header->module_count;
             moduleIndex += laneCount) {
            NBDueInvocationABI invocation;
            if (regional_invocation_for_module(
                    invocations,
                    cursor,
                    groupEnd,
                    layouts[moduleIndex].module_id,
                    invocation)) {
                tokenLastUpdates[diagnosticBase + moduleIndex] = timestamp;
            }
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
            const uint writeSlot =
                outputRouteHistoryStates[routeBase + routeIndex].next_slot;
            const ulong destinationBase = historyValueBase
                + ulong(route.history_value_offset)
                + ulong(writeSlot) * ulong(route.message_dimension);
            for (uint feature = lane;
                 feature < route.message_dimension;
                 feature += laneCount) {
                outputRouteHistoryValues[destinationBase + ulong(feature)] =
                    outputTokens[
                        tokenBase + ulong(senderTokenBase + feature)
                    ];
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
                outputRouteHistoryStates[routeBase + routeIndex];
            const uint writeSlot = history.next_slot;
            outputRouteHistoryTimestamps[
                historyTimestampBase
                + ulong(routeIndex * header->history_capacity + writeSlot)
            ] = timestamp;
            history.next_slot = (writeSlot + 1u) % header->history_capacity;
            history.count = min(history.count + 1u, header->history_capacity);
            history.latest_timestamp_microseconds = timestamp;
            outputRouteHistoryStates[routeBase + routeIndex] = history;
        }
        threadgroup_barrier(mem_flags::mem_device);
        cursor = groupEnd;
    }
}

/// Derives one species-neutral protective command from the accepted regional
/// prefix. The command remains in private GPU memory for the next physical
/// candidate; a species adapter owns its final muscle/actuator mapping.
kernel void derive_protective_command(
    device const NBSchedulerResultABI *schedulerResult [[buffer(0)]],
    device const NBDueInvocationABI *invocations [[buffer(1)]],
    device const NBModuleDescriptorABI *modules [[buffer(2)]],
    device const NBRegionalModuleStateABI *regionalStates [[buffer(3)]],
    constant NBProtectiveCommandUniformsABI *uniforms [[buffer(4)]],
    device NBProtectiveCommandABI *output [[buffer(5)]],
    uint threadIndex [[thread_position_in_grid]]
) {
    if (threadIndex != 0u) {
        return;
    }
    ulong interruptMask = 0ul;
    if (schedulerResult->status == NBSchedulerStatusValid) {
        for (uint index = 0u; index < schedulerResult->invocation_count; ++index) {
            const NBDueInvocationABI invocation = invocations[index];
            if ((invocation.reason_flags & NBSchedulerReasonInterrupt) != 0u) {
                interruptMask |= invocation.interrupt_mask;
            }
        }
    }
    float regionalSalience = 0.0f;
    for (uint index = 0u; index < uniforms->module_count; ++index) {
        const ushort clockClass = modules[index].clock_class;
        if (clockClass == 1u || clockClass == 2u) {
            regionalSalience = max(
                regionalSalience,
                clamp(regionalStates[index].interrupt_salience, 0.0f, 1.0f)
            );
        }
    }
    const ulong withdrawalCauses =
        NBInterruptPain | NBInterruptDamagingContact
        | NBInterruptJointLimit | NBInterruptMuscleOverload;
    const ulong braceCauses = NBInterruptLossOfSupport | NBInterruptImpact;
    const ulong stopCauses =
        withdrawalCauses | braceCauses | NBInterruptPhysiologicalCritical
        | NBInterruptRescue;
    const bool withdrawal = (interruptMask & withdrawalCauses) != 0ul;
    const bool brace = (interruptMask & braceCauses) != 0ul;
    const bool emergencyStop = (interruptMask & stopCauses) != 0ul;
    const bool arousal = interruptMask != 0ul;
    NBProtectiveCommandABI command;
    command.format_version = NBProtectiveCommandVersion;
    command.flags = NBProtectiveCommandFlagValid;
    if (emergencyStop) {
        command.flags |= NBProtectiveCommandFlagEmergencyStop;
    }
    if (withdrawal) {
        command.flags |= NBProtectiveCommandFlagWithdrawal;
    }
    if (brace) {
        command.flags |= NBProtectiveCommandFlagPosturalBrace;
    }
    if (arousal) {
        command.flags |= NBProtectiveCommandFlagAutonomicArousal;
    }
    command.timestamp_microseconds = schedulerResult->target_time_microseconds;
    command.brain_generation = uniforms->brain_generation;
    command.interrupt_mask = interruptMask;
    command.withdrawal_drive = withdrawal ? max(0.5f, regionalSalience) : 0.0f;
    command.postural_stiffness = brace ? max(0.75f, regionalSalience) : 0.0f;
    command.motor_inhibition = emergencyStop ? 1.0f : 0.0f;
    command.autonomic_arousal = arousal ? max(0.5f, regionalSalience) : 0.0f;
    command.environment_identifier = uniforms->environment_identifier;
    command.reserved = 0u;
    command.command_fingerprint = protective_command_fingerprint(command);
    output[0] = command;
}

/// Maps the accepted species-neutral command through one immutable body
/// profile. This first bounded kernel is serial so the output fingerprint is
/// independent of reduction order; production profiles will use a parallel
/// excitation pass followed by a canonical hash pass.
kernel void map_protective_motor_output(
    device const NBProtectiveCommandABI *commandBuffer [[buffer(0)]],
    device const NBMotorChannelDescriptorABI *channels [[buffer(1)]],
    constant NBProtectiveCommandUniformsABI *uniforms [[buffer(2)]],
    device NBMotorOutputHeaderABI *outputHeader [[buffer(3)]],
    device float *muscleExcitations [[buffer(4)]],
    device const uint *sourceInhibitionMask [[buffer(5)]],
    constant NBBodyLoadFieldUniformsABI *bodyLoadUniforms [[buffer(6)]],
    device const NBBodyLoadFieldRecordABI *bodyLoadField [[buffer(7)]],
    device const NBMuscleAttachmentRecordABI *attachments [[buffer(8)]],
    device const NBBodySchemaRecordABI *bodySchema [[buffer(9)]],
    device const float *descendingSomaticExcitations [[buffer(10)]],
    constant NBFastCPGUniformsABI *cpgUniforms [[buffer(11)]],
    device NBFastCPGStateABI *cpgStates [[buffer(12)]],
    device const NBInterruptEventABI *interruptEvents [[buffer(13)]],
    device const NBReceptorEventTransductionResultABI *interruptResult
        [[buffer(14)]],
    device const NBFastReflexRuleABI *reflexRules [[buffer(15)]],
    device NBFastReflexStateABI *reflexStates [[buffer(16)]],
    device const NBFastCerebellarStateABI *fastCerebellarStates [[buffer(17)]],
    uint threadIndex [[thread_position_in_grid]]
) {
    if (threadIndex != 0u) {
        return;
    }
    const NBProtectiveCommandABI command = commandBuffer[0];
    const uint oscillatorCount = (cpgUniforms->flags & 1u) != 0u
        ? min(cpgUniforms->oscillator_count, 64u)
        : 0u;
    const uint interruptEventCount = (cpgUniforms->flags & (1u << 1u)) != 0u
        ? interruptResult->event_count
        : 0u;
    constexpr float twoPi = 6.28318530717958647692f;
    for (uint oscillator = 0u; oscillator < oscillatorCount; ++oscillator) {
        NBFastCPGStateABI state = cpgStates[oscillator];
        const bool valid = (state.flags & 1u) != 0u;
        const bool active = (state.flags & (1u << 1u)) != 0u;
        float resetMagnitude = 0.0f;
        if (valid && active) {
            for (uint eventIndex = 0u; eventIndex < interruptEventCount;
                 ++eventIndex) {
                const NBInterruptEventABI event = interruptEvents[eventIndex];
                if (event.timestamp_microseconds > state.timestamp_microseconds &&
                    event.timestamp_microseconds
                        <= cpgUniforms->sample_timestamp_microseconds &&
                    (event.interrupt_mask & state.sensory_reset_mask) != 0ul) {
                    resetMagnitude = max(
                        resetMagnitude,
                        max(event.magnitude, 0.0f)
                    );
                }
            }
        }
        const bool reset = resetMagnitude > 0.0f;
        const float elapsedSeconds = valid && active
                && cpgUniforms->sample_timestamp_microseconds
                    > state.timestamp_microseconds
            ? float(cpgUniforms->sample_timestamp_microseconds
                - state.timestamp_microseconds) * 1.0e-6f
            : 0.0f;
        if (reset) {
            state.phase = 0.0f;
        } else if (valid && active && elapsedSeconds > 0.0f) {
            state.phase = fract(
                state.phase + elapsedSeconds * state.effective_frequency_hertz
            );
        }
        const float normalizedActivePhase = state.phase
            / max(state.duty_factor, 1.0e-6f);
        const float rawOutput = valid && active
                && state.phase < state.duty_factor
            ? 0.5f - 0.5f * cos(twoPi * normalizedActivePhase)
            : 0.0f;
        state.output = clamp(rawOutput * state.output_gain, 0.0f, 1.0f);
        state.reset_magnitude = resetMagnitude;
        state.timestamp_microseconds = cpgUniforms->sample_timestamp_microseconds;
        state.flags = (state.flags & ~(1u << 2u))
            | (reset ? (1u << 2u) : 0u);
        cpgStates[oscillator] = state;
    }
    const uint reflexRuleCount = min(cpgUniforms->reflex_rule_count, 4096u);
    for (uint ruleIndex = 0u; ruleIndex < reflexRuleCount; ++ruleIndex) {
        const NBFastReflexRuleABI rule = reflexRules[ruleIndex];
        NBFastReflexStateABI state = reflexStates[ruleIndex];
        float selectedOutput = 0.0f;
        float selectedMagnitude = 0.0f;
        ulong latestEventTimestamp = state.last_event_timestamp_microseconds;
        const bool hadSeenEvent = (state.flags & (1u << 4u)) != 0u;
        bool hasSeenEvent = hadSeenEvent;
        bool queueOverflow = false;
        for (uint pendingIndex = 0u; pendingIndex < 4u; ++pendingIndex) {
            const ulong delivery =
                state.pending_delivery_timestamp_microseconds[pendingIndex];
            if (delivery != 0ul &&
                delivery <= cpgUniforms->sample_timestamp_microseconds) {
                selectedOutput += state.pending_output[pendingIndex];
                selectedMagnitude = max(
                    selectedMagnitude,
                    state.pending_event_magnitude[pendingIndex]
                );
                state.pending_delivery_timestamp_microseconds[pendingIndex] = 0ul;
                state.pending_event_timestamp_microseconds[pendingIndex] = 0ul;
                state.pending_output[pendingIndex] = 0.0f;
                state.pending_event_magnitude[pendingIndex] = 0.0f;
            }
        }
        const bool innateEnabled = (rule.flags & 3u) == 3u;
        if (innateEnabled) {
            for (uint eventIndex = 0u; eventIndex < interruptEventCount;
                 ++eventIndex) {
                const NBInterruptEventABI event = interruptEvents[eventIndex];
                if (event.identifier != rule.receptor_identifier ||
                    (hadSeenEvent && event.timestamp_microseconds
                        <= state.last_event_timestamp_microseconds)) {
                    continue;
                }
                hasSeenEvent = true;
                latestEventTimestamp = max(
                    latestEventTimestamp,
                    event.timestamp_microseconds
                );
                if (event.magnitude < rule.activation_threshold) {
                    continue;
                }
                const ulong latency = ulong(rule.latency_microseconds);
                const bool deliveryOverflow = event.timestamp_microseconds
                    > (~0ul) - latency;
                const ulong deliveryTimestamp = deliveryOverflow
                    ? ~0ul
                    : event.timestamp_microseconds + latency;
                if (deliveryOverflow) {
                    queueOverflow = true;
                    continue;
                }
                const float response = clamp(
                    max(event.magnitude - rule.activation_threshold, 0.0f)
                        * rule.gain,
                    -1.0f,
                    1.0f
                );
                if (deliveryTimestamp
                    <= cpgUniforms->sample_timestamp_microseconds) {
                    selectedOutput += response;
                    selectedMagnitude = max(selectedMagnitude, event.magnitude);
                    continue;
                }
                uint emptyPendingIndex = 4u;
                uint matchingPendingIndex = 4u;
                for (uint pendingIndex = 0u; pendingIndex < 4u;
                     ++pendingIndex) {
                    const ulong pendingDelivery =
                        state.pending_delivery_timestamp_microseconds[pendingIndex];
                    if (pendingDelivery == deliveryTimestamp) {
                        matchingPendingIndex = pendingIndex;
                        break;
                    }
                    if (pendingDelivery == 0ul && emptyPendingIndex == 4u) {
                        emptyPendingIndex = pendingIndex;
                    }
                }
                const uint pendingIndex = matchingPendingIndex != 4u
                    ? matchingPendingIndex
                    : emptyPendingIndex;
                if (pendingIndex == 4u) {
                    queueOverflow = true;
                    continue;
                }
                state.pending_delivery_timestamp_microseconds[pendingIndex] =
                    deliveryTimestamp;
                state.pending_event_timestamp_microseconds[pendingIndex] = max(
                    state.pending_event_timestamp_microseconds[pendingIndex],
                    event.timestamp_microseconds
                );
                state.pending_output[pendingIndex] = clamp(
                    state.pending_output[pendingIndex] + response,
                    -1.0f,
                    1.0f
                );
                state.pending_event_magnitude[pendingIndex] = max(
                    state.pending_event_magnitude[pendingIndex],
                    event.magnitude
                );
            }
        }
        bool hasPending = false;
        for (uint pendingIndex = 0u; pendingIndex < 4u; ++pendingIndex) {
            hasPending = hasPending ||
                state.pending_delivery_timestamp_microseconds[pendingIndex] != 0ul;
        }
        state.last_event_timestamp_microseconds = latestEventTimestamp;
        state.state_timestamp_microseconds = cpgUniforms->sample_timestamp_microseconds;
        state.output = clamp(selectedOutput, -1.0f, 1.0f);
        state.event_magnitude = selectedMagnitude;
        state.circuit_identifier = rule.circuit_identifier;
        state.flags = 1u
            | (state.output != 0.0f ? (1u << 1u) : 0u)
            | (hasPending ? (1u << 2u) : 0u)
            | (queueOverflow ? (1u << 3u) : 0u)
            | (hasSeenEvent ? (1u << 4u) : 0u);
        reflexStates[ruleIndex] = state;
    }
    const ulong unlocalizedWithdrawalCauses =
        NBInterruptPain | NBInterruptDamagingContact | NBInterruptJointLimit;
    bool hasLocalizedWithdrawalSource = false;
    if ((command.interrupt_mask & NBInterruptMuscleOverload) != 0ul &&
        (command.interrupt_mask & unlocalizedWithdrawalCauses) == 0ul) {
        for (uint sourceIndex = 0u;
             sourceIndex < uniforms->muscle_count;
             ++sourceIndex) {
            hasLocalizedWithdrawalSource = hasLocalizedWithdrawalSource ||
                sourceInhibitionMask[sourceIndex] != 0u;
        }
    }
    bool hasLocalizedSourceInhibition = false;
    for (uint index = 0u; index < uniforms->muscle_count; ++index) {
        const NBMotorChannelDescriptorABI channel = channels[index];
        const NBMuscleAttachmentRecordABI attachment = attachments[index];
        bool sharesLocalizedWithdrawalEndpoint = false;
        if (hasLocalizedWithdrawalSource &&
            attachment.muscle_identifier == channel.muscle_id) {
            for (uint sourceIndex = 0u;
                 sourceIndex < uniforms->muscle_count;
                 ++sourceIndex) {
                if (sourceInhibitionMask[sourceIndex] == 0u) {
                    continue;
                }
                const NBMuscleAttachmentRecordABI sourceAttachment =
                    attachments[sourceIndex];
                if (sourceAttachment.muscle_identifier !=
                    channels[sourceIndex].muscle_id) {
                    continue;
                }
                sharesLocalizedWithdrawalEndpoint =
                    attachment.first_body_identifier ==
                        sourceAttachment.first_body_identifier ||
                    attachment.first_body_identifier ==
                        sourceAttachment.terminal_body_identifier ||
                    attachment.terminal_body_identifier ==
                        sourceAttachment.first_body_identifier ||
                    attachment.terminal_body_identifier ==
                        sourceAttachment.terminal_body_identifier;
                if (sharesLocalizedWithdrawalEndpoint) {
                    break;
                }
            }
        }
        const float withdrawalDrive =
            !hasLocalizedWithdrawalSource || sharesLocalizedWithdrawalEndpoint
            ? command.withdrawal_drive
            : 0.0f;
        const float withdrawalExcitation = fma(
            withdrawalDrive,
            channel.withdrawal_gain,
            channel.resting_excitation
        );
        float localizedRisk = 0.0f;
        if (attachment.muscle_identifier == channel.muscle_id) {
            if (attachment.first_body_identifier < bodyLoadUniforms->body_count) {
                localizedRisk = max(
                    localizedRisk,
                    bodySchema[attachment.first_body_identifier].damage_risk
                );
            }
            if (attachment.terminal_body_identifier < bodyLoadUniforms->body_count) {
                localizedRisk = max(
                    localizedRisk,
                    bodySchema[attachment.terminal_body_identifier].damage_risk
                );
            }
        }
        const float protectiveExcitation = fma(
            max(command.postural_stiffness, localizedRisk),
            channel.brace_gain,
            withdrawalExcitation
        );
        float sampledCPGOutput = 0.0f;
        float sampledReflexOutput = 0.0f;
        const uint actuatorSynergy = index % max(cpgUniforms->synergy_count, 1u);
        for (uint oscillator = 0u; oscillator < oscillatorCount; ++oscillator) {
            const NBFastCPGStateABI state = cpgStates[oscillator];
            if ((state.flags & 1u) != 0u &&
                state.output_kind == NBCPGOutputSomaticSynergy &&
                state.output_synergy_identifier == actuatorSynergy) {
                sampledCPGOutput += state.output;
            }
        }
        for (uint ruleIndex = 0u; ruleIndex < reflexRuleCount; ++ruleIndex) {
            if (reflexRules[ruleIndex].actuator_identifier == index) {
                sampledReflexOutput += reflexStates[ruleIndex].output;
            }
        }
        const NBFastCerebellarStateABI fastCerebellar =
            fastCerebellarStates[index];
        const float fastCerebellarCorrection =
            (fastCerebellar.flags & 3u) == 3u
            ? clamp(fastCerebellar.correction, -0.25f, 0.25f)
            : 0.0f;
        const float descendingExcitation = clamp(
            descendingSomaticExcitations[index] + sampledCPGOutput
                + sampledReflexOutput + fastCerebellarCorrection,
            0.0f,
            channel.maximum_excitation
        ) * (1.0f - clamp(command.motor_inhibition, 0.0f, 1.0f));
        const float excitation = min(
            descendingExcitation + protectiveExcitation,
            channel.maximum_excitation
        );
        bool retainedSourceInhibition = false;
        for (uint bodyIndex = 0u;
             bodyIndex < bodyLoadUniforms->body_count;
             ++bodyIndex) {
            const NBBodyLoadFieldRecordABI bodyLoad = bodyLoadField[bodyIndex];
            retainedSourceInhibition = retainedSourceInhibition ||
                (bodyLoad.endpoint_role != 0u &&
                 bodyLoad.effective_absolute_muscle_force > 0.0f &&
                 bodyLoad.source_muscle_identifier == channel.muscle_id);
        }
        const bool inhibitSource = sourceInhibitionMask[index] != 0u ||
            retainedSourceInhibition;
        hasLocalizedSourceInhibition = hasLocalizedSourceInhibition || inhibitSource;
        muscleExcitations[index] = inhibitSource
            ? 0.0f
            : clamp(excitation, 0.0f, channel.maximum_excitation);
    }
    NBMotorOutputHeaderABI header;
    header.format_version = NBMotorOutputVersion;
    header.flags = NBMotorOutputFlagValid;
    if ((command.flags & NBProtectiveCommandFlagEmergencyStop) != 0u) {
        header.flags |= NBMotorOutputFlagEmergencyStop;
    }
    if (hasLocalizedSourceInhibition) {
        header.flags |= NBMotorOutputFlagLocalizedSourceInhibition;
    }
    if (hasLocalizedWithdrawalSource) {
        header.flags |= NBMotorOutputFlagLocalizedWithdrawal;
    }
    header.timestamp_microseconds = command.timestamp_microseconds;
    header.brain_generation = uniforms->brain_generation;
    header.profile_fingerprint = uniforms->motor_profile_fingerprint;
    header.protective_command_fingerprint = command.command_fingerprint;
    header.muscle_count = uniforms->muscle_count;
    header.environment_identifier = command.environment_identifier;
    header.motor_inhibition = command.motor_inhibition;
    header.autonomic_arousal = command.autonomic_arousal;
    header.output_fingerprint = motor_output_fingerprint(header, muscleExcitations);
    outputHeader[0] = header;
}

inline bool body_load_same_source(
    const NBBodyLoadFieldRecordABI lhs,
    const NBBodyLoadFieldRecordABI rhs
) {
    return lhs.body_identifier == rhs.body_identifier &&
        lhs.source_muscle_identifier == rhs.source_muscle_identifier &&
        lhs.maximum_absolute_muscle_force == rhs.maximum_absolute_muscle_force &&
        lhs.accepted_timestamp_microseconds == rhs.accepted_timestamp_microseconds &&
        lhs.accepted_physics_state_fingerprint ==
            rhs.accepted_physics_state_fingerprint;
}

inline NBBodyLoadFieldRecordABI body_load_retained_at_target(
    const NBBodyLoadFieldRecordABI previous,
    constant NBBodyLoadFieldUniformsABI *uniforms
) {
    if (previous.endpoint_role == 0u ||
        uniforms->target_timestamp_microseconds <
            previous.field_activation_timestamp_microseconds ||
        uniforms->target_timestamp_microseconds <
            previous.field_state_timestamp_microseconds) {
        NBBodyLoadFieldRecordABI empty{};
        empty.body_identifier = previous.body_identifier;
        return empty;
    }
    const ulong age = uniforms->target_timestamp_microseconds -
        previous.field_activation_timestamp_microseconds;
    const ulong persistence = ulong(uniforms->persistence_microseconds);
    const ulong decay = ulong(uniforms->decay_microseconds);
    const ulong expiry = persistence + decay;
    if (age >= expiry) {
        NBBodyLoadFieldRecordABI empty{};
        empty.body_identifier = previous.body_identifier;
        return empty;
    }
    NBBodyLoadFieldRecordABI retained = previous;
    retained.effective_absolute_muscle_force =
        age <= persistence
        ? previous.maximum_absolute_muscle_force
        : previous.maximum_absolute_muscle_force *
            (float(expiry - age) / float(decay));
    retained.field_state_timestamp_microseconds =
        uniforms->target_timestamp_microseconds;
    return retained;
}

inline bool body_load_is_stronger(
    const NBBodyLoadFieldRecordABI candidate,
    const NBBodyLoadFieldRecordABI current
) {
    if (current.endpoint_role == 0u) {
        return true;
    }
    if (candidate.effective_absolute_muscle_force !=
        current.effective_absolute_muscle_force) {
        return candidate.effective_absolute_muscle_force >
            current.effective_absolute_muscle_force;
    }
    if (candidate.accepted_timestamp_microseconds !=
        current.accepted_timestamp_microseconds) {
        return candidate.accepted_timestamp_microseconds >
            current.accepted_timestamp_microseconds;
    }
    if (candidate.source_muscle_identifier != current.source_muscle_identifier) {
        return candidate.source_muscle_identifier < current.source_muscle_identifier;
    }
    return candidate.accepted_physics_state_fingerprint <
        current.accepted_physics_state_fingerprint;
}

/// Materializes one temporally retained peak-load cell per Core body. The
/// committed generation is decayed to the root target before accepted updates
/// compete with it; rejected candidates never enter the update list.
kernel void materialize_body_load_field(
    constant NBBodyLoadFieldUniformsABI *uniforms [[buffer(0)]],
    device const NBBodyLoadFieldRecordABI *updates [[buffer(1)]],
    device const NBBodyLoadFieldRecordABI *previous [[buffer(2)]],
    device NBBodyLoadFieldRecordABI *output [[buffer(3)]],
    uint threadIndex [[thread_position_in_grid]]
) {
    if (threadIndex != 0u) {
        return;
    }
    for (uint bodyIndex = 0u; bodyIndex < uniforms->body_count; ++bodyIndex) {
        NBBodyLoadFieldRecordABI selected = body_load_retained_at_target(
            previous[bodyIndex],
            uniforms
        );
        selected.body_identifier = bodyIndex;
        for (uint updateIndex = 0u;
             updateIndex < uniforms->update_count;
             ++updateIndex) {
            const NBBodyLoadFieldRecordABI candidate = updates[updateIndex];
            if (candidate.body_identifier != bodyIndex) {
                continue;
            }
            if (body_load_same_source(candidate, selected)) {
                const uint combinedRole = selected.endpoint_role |
                    candidate.endpoint_role;
                if (candidate.field_activation_timestamp_microseconds >=
                    selected.field_activation_timestamp_microseconds) {
                    selected = candidate;
                }
                selected.endpoint_role = combinedRole;
            } else if (body_load_is_stronger(candidate, selected)) {
                selected = candidate;
            }
        }
        output[bodyIndex] = selected;
    }
}

/// Replays the cumulative accepted load observations for one root from the
/// committed per-actuator baseline. Duplicate endpoint records are rejected
/// by their accepted timestamp, so every physical load sample adapts a local
/// forward gain and inverse correction at most once. Rejected candidates
/// never reach this kernel or its update list.
kernel void adapt_fast_cerebellar_load_correction(
    constant NBBodyLoadFieldUniformsABI *bodyLoadUniforms [[buffer(0)]],
    device const NBBodyLoadFieldRecordABI *updates [[buffer(1)]],
    device const NBMotorCommandRecordABI *motorCommands [[buffer(2)]],
    device const NBMotorChannelDescriptorABI *channels [[buffer(3)]],
    device const NBFastCerebellarStateABI *baselineStates [[buffer(4)]],
    device NBFastCerebellarStateABI *outputStates [[buffer(5)]],
    constant NBBodySchemaUniformsABI *bodySchemaUniforms [[buffer(6)]],
    device const float *cerebellarParameters [[buffer(7)]],
    uint actuatorIndex [[thread_position_in_grid]])
{
    const NBMotorChannelDescriptorABI channel = channels[actuatorIndex];
    const NBMotorCommandRecordABI command = motorCommands[actuatorIndex];
    NBFastCerebellarStateABI state = baselineStates[actuatorIndex];
    ulong latestTimestamp = state.last_observation_timestamp_microseconds;
    bool observed = false;
    const float learningRate = clamp(cerebellarParameters[0], 0.0f, 1.0f);
    const float inverseRate = clamp(abs(cerebellarParameters[5]), 0.0f, 0.25f);
    const float forceScale = max(bodySchemaUniforms->force_scale_newtons, 1.0e-6f);
    for (uint updateIndex = 0u;
         updateIndex < bodyLoadUniforms->update_count;
         ++updateIndex) {
        const NBBodyLoadFieldRecordABI update = updates[updateIndex];
        if (update.source_muscle_identifier != channel.muscle_id
            || update.accepted_timestamp_microseconds <= latestTimestamp) {
            continue;
        }
        const float excitation = clamp(command.excitation, 0.0f, 1.0f);
        const float observedLoad = clamp(
            update.maximum_absolute_muscle_force / forceScale,
            0.0f,
            1.0f
        );
        const float effectiveGain = clamp(
            cerebellarParameters[4] + state.learned_load_gain,
            0.0f,
            2.0f
        );
        const float predictedLoad = clamp(
            excitation * effectiveGain,
            0.0f,
            1.0f
        );
        const float predictionError = observedLoad - predictedLoad;
        const float desiredLoad = clamp(command.force_target, 0.0f, 1.0f);
        state.learned_load_gain = clamp(
            state.learned_load_gain
                + learningRate * predictionError * excitation,
            -1.0f,
            1.0f
        );
        state.correction = clamp(
            state.correction + inverseRate * (desiredLoad - observedLoad),
            -0.25f,
            0.25f
        );
        state.predicted_load = predictedLoad;
        state.observed_load = observedLoad;
        state.prediction_error = predictionError;
        state.desired_load = desiredLoad;
        latestTimestamp = update.accepted_timestamp_microseconds;
        state.update_count = state.update_count == 0xffffffffu
            ? 0xffffffffu : state.update_count + 1u;
        observed = true;
    }
    state.last_observation_timestamp_microseconds = latestTimestamp;
    state.state_timestamp_microseconds =
        bodyLoadUniforms->target_timestamp_microseconds;
    state.flags = (state.flags | 1u) & ~(1u << 2u);
    state.flags |= observed ? (1u << 2u) : 0u;
    outputStates[actuatorIndex] = state;
}

inline void fast_autonomic_advance_to(
    thread NBFastAutonomicStateABI &state,
    float highLevelTarget,
    ulong targetTimestamp,
    constant NBFastAutonomicUniformsABI *uniforms)
{
    if (targetTimestamp <= state.state_timestamp_microseconds) {
        return;
    }
    const ulong elapsedMicroseconds =
        targetTimestamp - state.state_timestamp_microseconds;
    const float elapsed = float(elapsedMicroseconds);
    const float decayTime = float(max(
        uniforms->critical_decay_microseconds,
        1u
    ));
    state.critical_drive *= exp(-elapsed / decayTime);
    const float criticalStrength = clamp(state.critical_drive, 0.0f, 1.0f);
    const float criticalTarget = clamp(state.reserved[0], 0.0f, 1.0f);
    const float effectiveTarget = clamp(
        mix(highLevelTarget, criticalTarget, criticalStrength),
        0.0f,
        1.0f
    );
    const float responseTime = float(max(uniforms->response_time_microseconds, 1u));
    const float alpha = 1.0f - exp(-elapsed / responseTime);
    state.command = clamp(
        state.command + alpha * (effectiveTarget - state.command),
        0.0f,
        1.0f
    );
    state.target = effectiveTarget;
    state.integration += state.command * elapsed * 1.0e-6f;
    state.state_timestamp_microseconds = targetTimestamp;
}

/// Recomputes fast brainstem/autonomic output from the committed state and
/// the cumulative accepted event prefix. Intermediate accepted prefixes may
/// overwrite this shadow repeatedly, but no prefix can integrate twice and a
/// rejected physical candidate never reaches the state or output buffers.
kernel void advance_fast_autonomic_output(
    constant NBFastAutonomicUniformsABI *uniforms [[buffer(0)]],
    device const NBAutonomicCommandRecordABI *baselineCommands [[buffer(1)]],
    device const NBInterruptEventABI *interruptEvents [[buffer(2)]],
    device const NBReceptorEventTransductionResultABI *interruptResult
        [[buffer(3)]],
    device const NBFastAutonomicStateABI *baselineStates [[buffer(4)]],
    device NBFastAutonomicStateABI *outputStates [[buffer(5)]],
    device NBAutonomicCommandRecordABI *outputCommands [[buffer(6)]],
    device const NBFastCPGStateABI *cpgStates [[buffer(7)]],
    device const NBFastAutonomicChannelDescriptorABI *channelDescriptors
        [[buffer(8)]],
    uint channelIndex [[thread_position_in_grid]])
{
    if (channelIndex >= uniforms->channel_count) {
        return;
    }
    const NBAutonomicCommandRecordABI baselineCommand =
        baselineCommands[channelIndex];
    const NBFastAutonomicChannelDescriptorABI descriptor =
        channelDescriptors[channelIndex];
    const float highLevelCommand = isfinite(baselineCommand.command)
        ? clamp(baselineCommand.command, 0.0f, 1.0f)
        : 0.0f;
    const float cognitiveTarget = isfinite(baselineCommand.target)
        ? clamp(baselineCommand.target, 0.0f, 1.0f)
        : highLevelCommand;
    float vitalRhythmicDrive = 0.0f;
    for (uint oscillator = 0u; oscillator < uniforms->oscillator_count;
         ++oscillator) {
        const NBFastCPGStateABI oscillatorState = cpgStates[oscillator];
        if ((oscillatorState.flags & 1u) != 0u
            && (oscillatorState.flags & (1u << 1u)) != 0u
            && oscillatorState.output_kind == NBCPGOutputAutonomicChannel
            && oscillatorState.output_synergy_identifier == channelIndex) {
            vitalRhythmicDrive += oscillatorState.output;
        }
    }
    const float highLevelTarget = max(
        cognitiveTarget,
        clamp(
            vitalRhythmicDrive * descriptor.cpg_gain * uniforms->vital_gain,
            0.0f,
            1.0f
        )
    );
    NBFastAutonomicStateABI state = baselineStates[channelIndex];
    const bool valid = (state.flags & 1u) != 0u;
    bool hasSeenEvent = valid && (state.flags & (1u << 2u)) != 0u;
    if (!valid) {
        state.last_event_timestamp_microseconds = 0ul;
        state.state_timestamp_microseconds =
            uniforms->baseline_timestamp_microseconds;
        state.command = highLevelCommand;
        state.target = highLevelTarget;
        state.critical_drive = 0.0f;
        state.integration = 0.0f;
        state.update_count = 0u;
        state.flags = 1u;
        for (uint index = 0u; index < 6u; ++index) {
            state.reserved[index] = 0.0f;
        }
        state.reserved[0] = highLevelTarget;
    } else if (state.state_timestamp_microseconds
               < uniforms->baseline_timestamp_microseconds) {
        fast_autonomic_advance_to(
            state,
            highLevelTarget,
            uniforms->baseline_timestamp_microseconds,
            uniforms
        );
    }
    const uint eventCount = (uniforms->flags & 1u) != 0u
        ? interruptResult->event_count
        : 0u;
    for (uint eventIndex = 0u; eventIndex < eventCount; ++eventIndex) {
        const NBInterruptEventABI event = interruptEvents[eventIndex];
        bool receptorMatch = (descriptor.flags & (1u << 1u)) != 0u;
        for (uint receptorIndex = 0u;
             receptorIndex < min(descriptor.critical_receptor_count, 4u);
             ++receptorIndex) {
            receptorMatch = receptorMatch
                || descriptor.critical_receptors[receptorIndex]
                    == event.identifier;
        }
        if ((descriptor.flags & 1u) == 0u
            || descriptor.channel_identifier != channelIndex
            || !receptorMatch
            || (event.interrupt_mask & NBInterruptPhysiologicalCritical) == 0ul
            || event.timestamp_microseconds
                < uniforms->baseline_timestamp_microseconds
            || event.timestamp_microseconds
                > uniforms->sample_timestamp_microseconds
            || (hasSeenEvent && event.timestamp_microseconds
                <= state.last_event_timestamp_microseconds)) {
            continue;
        }
        fast_autonomic_advance_to(
            state,
            highLevelTarget,
            event.timestamp_microseconds,
            uniforms
        );
        state.critical_drive = max(
            state.critical_drive,
            clamp(
                max(event.magnitude, 0.0f) * descriptor.emergency_gain
                    * uniforms->vital_gain,
                0.0f,
                1.0f
            )
        );
        state.reserved[0] = clamp(descriptor.emergency_target, 0.0f, 1.0f);
        // A physiological emergency bypasses the normal response time on its
        // rising edge; subsequent recovery still follows the decay dynamics.
        state.command = mix(
            state.command,
            state.reserved[0],
            clamp(state.critical_drive, 0.0f, 1.0f)
        );
        state.target = state.command;
        state.last_event_timestamp_microseconds = event.timestamp_microseconds;
        state.update_count = state.update_count == 0xffffffffu
            ? 0xffffffffu
            : state.update_count + 1u;
        hasSeenEvent = true;
    }
    fast_autonomic_advance_to(
        state,
        highLevelTarget,
        uniforms->sample_timestamp_microseconds,
        uniforms
    );
    const bool critical = state.critical_drive > 1.0e-6f;
    state.flags = 1u
        | (critical ? (1u << 1u) : 0u)
        | (hasSeenEvent ? (1u << 2u) : 0u);
    outputStates[channelIndex] = state;

    NBAutonomicCommandRecordABI output;
    output.command = state.command;
    output.target = state.target;
    output.confidence = critical
        ? 1.0f
        : clamp(baselineCommand.confidence, 0.0f, 1.0f);
    output.flags = 1u | (critical ? (1u << 1u) : 0u);
    outputCommands[channelIndex] = output;
}

/// Advances the dense brain-owned body posterior from causal load evidence.
/// Retained load-field cells are memory, not fresh observations: only a cell
/// activated at this target timestamp performs the posterior measurement
/// update. Every body advances on physical time in the same root generation.
kernel void advance_body_schema(
    constant NBBodySchemaUniformsABI *uniforms [[buffer(0)]],
    device const NBBodyLoadFieldRecordABI *bodyLoadField [[buffer(1)]],
    device const NBBodySchemaRecordABI *previous [[buffer(2)]],
    device NBBodySchemaRecordABI *output [[buffer(3)]],
    uint bodyIndex [[thread_position_in_grid]]
) {
    if (bodyIndex >= uniforms->body_count) {
        return;
    }
    const NBBodySchemaRecordABI priorState = previous[bodyIndex];
    if (uniforms->target_timestamp_microseconds <
        priorState.state_timestamp_microseconds) {
        output[bodyIndex] = priorState;
        return;
    }
    const ulong elapsedMicroseconds =
        uniforms->target_timestamp_microseconds -
        priorState.state_timestamp_microseconds;
    const float elapsedSeconds = float(elapsedMicroseconds) * 0.000001f;
    const float retention = max(
        0.0f,
        1.0f - float(elapsedMicroseconds) /
            float(uniforms->load_time_constant_microseconds)
    );
    const float priorLoad = priorState.estimated_absolute_load * retention;
    const float priorVariance = min(
        uniforms->maximum_variance,
        priorState.epistemic_variance +
            uniforms->process_variance_per_second * elapsedSeconds
    );
    const NBBodyLoadFieldRecordABI load = bodyLoadField[bodyIndex];
    const bool freshObservation = load.endpoint_role != 0u &&
        load.field_activation_timestamp_microseconds ==
            uniforms->target_timestamp_microseconds;

    NBBodySchemaRecordABI next = priorState;
    next.body_identifier = bodyIndex;
    next.flags &= ~NBBodySchemaFlagObservedThisUpdate;
    if (freshObservation) {
        const float gain = priorVariance /
            (priorVariance + uniforms->observation_variance);
        next.estimated_absolute_load = max(
            0.0f,
            fma(
                gain,
                load.effective_absolute_muscle_force - priorLoad,
                priorLoad
            )
        );
        next.epistemic_variance = max(
            0.0f,
            (1.0f - gain) * priorVariance
        );
        next.source_muscle_identifier = load.source_muscle_identifier;
        next.endpoint_role = load.endpoint_role;
        next.last_observation_timestamp_microseconds =
            uniforms->target_timestamp_microseconds;
        next.flags |= NBBodySchemaFlagEverObserved |
            NBBodySchemaFlagObservedThisUpdate;
        next.flags &= ~(NBBodySchemaFlagFirstRouteEndpoint |
            NBBodySchemaFlagTerminalRouteEndpoint);
        if ((load.endpoint_role & 1u) != 0u) {
            next.flags |= NBBodySchemaFlagFirstRouteEndpoint;
        }
        if ((load.endpoint_role & 2u) != 0u) {
            next.flags |= NBBodySchemaFlagTerminalRouteEndpoint;
        }
    } else {
        next.estimated_absolute_load = priorLoad;
        next.epistemic_variance = priorVariance;
    }

    const float normalizedLoad = clamp(
        next.estimated_absolute_load / uniforms->force_scale_newtons,
        0.0f,
        1.0f
    );
    next.vulnerability = clamp(
        priorState.vulnerability + elapsedSeconds *
            (uniforms->vulnerability_gain_per_second * normalizedLoad -
             uniforms->recovery_per_second * (1.0f - normalizedLoad)),
        0.0f,
        1.0f
    );
    const float normalizedUncertainty = min(
        sqrt(next.epistemic_variance) / uniforms->force_scale_newtons,
        1.0f
    );
    next.damage_risk =
        next.last_observation_timestamp_microseconds == NBBodySchemaNoObservation
        ? 0.0f
        : min(
            normalizedLoad * (0.25f + 0.75f * next.vulnerability) +
                uniforms->uncertainty_risk_weight * normalizedUncertainty,
            1.0f
        );
    next.state_timestamp_microseconds =
        uniforms->target_timestamp_microseconds;
    output[bodyIndex] = next;
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
    device ulong *relayHistoryTimestamps [[buffer(11)]],
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
    const uint historyCapacity = uint(uniforms[TissueHistoryCapacity]);
    const uint historyOwnerMask = as_type<uint>(uniforms[TissueHistoryOwnerMask]);
    const ulong currentTimestamp = tissue_uint64_from_uniforms(
        uniforms,
        TissueCurrentTimestampLow,
        TissueCurrentTimestampHigh
    );
    const ulong candidateTimestamp = tissue_uint64_from_uniforms(
        uniforms,
        TissueCandidateTimestampLow,
        TissueCandidateTimestampHigh
    );
    const ulong nominalTimestepMicroseconds = tissue_uint64_from_uniforms(
        uniforms,
        TissueNominalTimestepMicrosecondsLow,
        TissueNominalTimestepMicrosecondsHigh
    );

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
    const float northRelay = tissue_relay_at_physical_delay(
        relayHistory,
        relayHistoryTimestamps,
        up * width + x,
        uint(delaySteps[up * width + x]),
        siteCount,
        historyCapacity,
        historyOwnerMask,
        currentTimestamp,
        nominalTimestepMicroseconds
    );
    const float southRelay = tissue_relay_at_physical_delay(
        relayHistory,
        relayHistoryTimestamps,
        down * width + x,
        uint(delaySteps[down * width + x]),
        siteCount,
        historyCapacity,
        historyOwnerMask,
        currentTimestamp,
        nominalTimestepMicroseconds
    );
    const float westRelay = tissue_relay_at_physical_delay(
        relayHistory,
        relayHistoryTimestamps,
        y * width + left,
        uint(delaySteps[y * width + left]),
        siteCount,
        historyCapacity,
        historyOwnerMask,
        currentTimestamp,
        nominalTimestepMicroseconds
    );
    const float eastRelay = tissue_relay_at_physical_delay(
        relayHistory,
        relayHistoryTimestamps,
        y * width + right,
        uint(delaySteps[y * width + right]),
        siteCount,
        historyCapacity,
        historyOwnerMask,
        currentTimestamp,
        nominalTimestepMicroseconds
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
        const float sourceRelay = tissue_relay_at_physical_delay(
            relayHistory,
            relayHistoryTimestamps,
            edge.x,
            edge.y,
            siteCount,
            historyCapacity,
            historyOwnerMask,
            currentTimestamp,
            nominalTimestepMicroseconds
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
        if (index == 0u) {
            relayHistoryTimestamps[
                historyWritePlane * historyCapacity + historyWriteSlot
            ] = candidateTimestamp;
        }
    } else {
        relayScratch[index] = nextRelay;
    }
}

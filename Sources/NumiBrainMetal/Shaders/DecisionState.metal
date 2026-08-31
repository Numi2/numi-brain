#include <metal_stdlib>
using namespace metal;

constant uint NB_CONTROL_MODE_REFLEX = 1u;
constant uint NB_CONTROL_MODE_PROCEDURAL = 2u;
constant uint NB_CONTROL_MODE_PLANNING = 3u;
constant uint NB_CONTROL_FLAG_VALID = 1u;
constant uint NB_CONTROL_FLAG_HYPERDIRECT_STOP = 1u << 1;
constant uint NB_CONTROL_FLAG_EXTERNAL_GOAL_FAILED = 1u << 8;
constant uint NB_CEREBELLAR_PREDICTION_VALID = 1u << 5;
constant ulong NB_INNATE_OPTION_NAMESPACE = 0x8000000000000000ul;
constant uint NB_OPTION_PROPOSAL_LOCOMOTION = 1u;
constant uint NB_OPTION_PROPOSAL_ACTIVE_SENSING = 4u;
constant uint NB_OPTION_PROPOSAL_EXPLORATION = 7u;
constant uint NB_OPTION_PROPOSAL_IMITATION = 8u;
constant uint NB_CPG_OUTPUT_SOMATIC_SYNERGY = 1u;
constant uint NB_CPG_OUTPUT_AUTONOMIC_CHANNEL = 2u;
constant uint NB_ACTUATOR_COMMAND_MUSCLE_EXCITATION = 1u;
constant uint NB_OPTION_PROPOSAL_REST_RECOVERY = 3u;
constant ulong NB_REST_OPTION_IDENTIFIER = NB_INNATE_OPTION_NAMESPACE | 4ul;
constant uint NB_WORLD_EVENT_OPTION_BASE = 5760u;
constant uint NB_WORLD_EVENT_OPTION_DIMENSION = 256u;
constant uint NB_WORLD_HEAD_COUNT = 5u;
constant uint NB_WORLD_CVAR_TAIL_COUNT = 2u;
constant uint NB_WORLD_RECEPTOR_DIMENSION = 128u;
constant uint NB_BODY_POSITION = 0u;
constant uint NB_BODY_ORIENTATION = 3u;
constant uint NB_BODY_LINEAR_VELOCITY = 7u;
constant uint NB_BODY_POSITION_VARIANCE = 13u;
constant uint NB_BODY_ORIENTATION_VARIANCE = 16u;
constant uint NB_BODY_CONTACT = 19u;
constant uint NB_BODY_SUPPORT = 20u;
constant uint NB_BODY_LOCAL_FORCE = 21u;
constant uint NB_BODY_PAIN = 24u;
constant uint NB_BODY_VULNERABILITY = 25u;
constant uint NB_BODY_REACHABILITY = 26u;
constant uint NB_BODY_OWNERSHIP = 27u;
constant uint NB_BODY_LOAD_VARIANCE = 29u;
constant uint NB_BODY_DAMAGE_RISK = 30u;
constant uint NB_BODY_EXTERNAL_DISTURBANCE = 32u;
constant uint NB_BODY_SENSORIMOTOR_FEATURE_COUNT = 33u;
constant uint NB_BODY_IDENTITY_FLOAT_OFFSET = 40u;
constant uint NB_JOINT_POSITION_VARIANCE = 12u;
constant uint NB_JOINT_VELOCITY_VARIANCE = 18u;
constant uint NB_JOINT_LIMIT_ACTIVATION = 24u;
constant uint NB_JOINT_OWNERSHIP = 30u;
constant uint NB_JOINT_PREDICTION_ERROR = 31u;
constant uint NB_JOINT_IDENTITY_FLOAT_OFFSET = 32u;
constant uint NB_MUSCLE_TASK_EFFECT = 13u;
constant uint NB_MUSCLE_SENSORIMOTOR_FEATURE_COUNT = 16u;
constant uint NB_MUSCLE_IDENTITY_FLOAT_OFFSET = 16u;
constant uint NB_CEREBELLAR_JOINT_FEATURE_BASE = 64u;
constant uint NB_CEREBELLAR_MUSCLE_FEATURE_BASE = 128u;
constant uint NB_CEREBELLAR_FEATURE_MASK = 0xffu;
constant uint NB_CEREBELLAR_ACTUATOR_SHIFT = 8u;

struct NBDecisionUniforms {
  ulong target_timestamp_microseconds;
  ulong recurrent_offset;
  ulong workspace_offset;
  ulong workspace_metadata_offset;
  ulong world_model_offset;
  ulong drive_offset;
  ulong neuromodulation_offset;
  ulong control_header_offset;
  ulong candidate_offset;
  ulong plan_offset;
  ulong motor_goal_offset;
  ulong motor_offset;
  ulong synergy_offset;
  ulong cerebellar_offset;
  ulong spinal_offset;
  ulong autonomic_offset;
  ulong somatic_output_offset;
  ulong active_sensing_offset;
  ulong spatial_transform_offset;
  ulong object_slot_offset;
  ulong internal_action_offset;
  ulong developmental_state_offset;
  ulong cerebellar_expert_memory_offset;
  ulong event_queue_offset;
  ulong cpg_state_offset;
  ulong descending_somatic_baseline_offset;
  ulong regional_plastic_modulation_offset;
  ulong parameter_version_fingerprint;
  ulong reserved_identity;
  uint recurrent_scalar_count;
  uint workspace_scalar_count;
  uint workspace_capacity;
  uint workspace_dimension;
  uint world_model_scalar_count;
  uint drive_count;
  uint neuromodulator_count;
  uint candidate_capacity;
  uint plan_capacity;
  uint actuator_count;
  uint synergy_count;
  uint active_cerebellar_expert_count;
  uint autonomic_dimension;
  uint active_sensing_dimension;
  uint communication_synergy_descriptor_offset;
  uint active_sensing_descriptor_offset;
  uint communication_descriptor_count;
  uint spatial_transform_count;
  uint object_slot_count;
  uint internal_action_capacity;
  uint maximum_planning_horizon;
  uint cpg_oscillator_count;
  uint cpg_coupling_count;
  uint event_capacity;
  uint regional_plastic_modulation_count;
  uint reserved_regional_modulation;
  float risk_weight;
  float damage_risk_budget;
  float switching_margin;
  float curiosity_weight;
  float planning_cost_weight;
  float motor_gain;
  float stiffness_gain;
  float damping_gain;
  ulong observation_offset;
  uint observation_count;
  uint cerebellar_expert_capacity;
  ulong fast_cerebellar_state_offset;
  ulong body_belief_offset;
  ulong joint_belief_offset;
  ulong somatic_effector_belief_offset;
  uint body_belief_count;
  uint joint_belief_count;
  uint somatic_effector_belief_count;
  ulong active_sensing_efficacy_offset;
  uint actuator_command_kind;
  uint active_sensing_command_scale_bits;
};

struct NBDriveRecord {
  float level;
  float viable_minimum;
  float viable_maximum;
  float priority_weight;
  float estimated_rate;
  float deficit;
  float potential;
  uint kind;
};

struct NBNeuromodulatorRecord {
  float value;
  float decay_time_constant_seconds;
  uint kind;
  uint flags;
};

struct NBRegionalPlasticModulationRecord {
  uint module_identifier;
  uint coefficient_count;
  float recurrent_delta;
  float local_delta;
  float route_delta;
  float drive_delta;
  float gate_delta;
  uint flags;
  float update_gain_multiplier;
  float timescale_multiplier;
  float route_threshold_delta;
  float inhibition_delta;
  float plasticity_decay_multiplier;
  float memory_write_multiplier;
  float vigor_multiplier;
  float exploration_temperature_multiplier;
};

struct NBExternalGoalDirectiveRecord {
  ulong identifier;
  ulong deadline_timestamp_microseconds;
  ulong created_timestamp_microseconds;
  ulong flags;
  float priority;
  float damage_risk_budget;
  float persistence;
  float reserved;
  float target[16];
  float success_model[16];
  float failure_model[16];
};

struct NBWorkspaceMetadataRecord {
  ulong identifier;
  ulong source_timestamp_microseconds;
  ulong last_refresh_timestamp_microseconds;
  ulong entity_identifier;
  ulong goal_identifier;
  ulong bound_token_identifier;
  ulong provenance_record_identifier;
  uint kind_and_source;
  float confidence;
  float persistence_priority;
  float selection_score;
  uint provenance_kind;
  uint flags;
  ulong provenance_source_generation;
  ulong last_score_update_timestamp_microseconds;
};

struct NBControlHeader {
  ulong active_goal_identifier;
  ulong active_option_identifier;
  ulong active_plan_identifier;
  ulong selected_timestamp_microseconds;
  uint mode;
  uint candidate_count;
  uint plan_step_count;
  uint flags;
  float selected_score;
  float selected_damage_cvar;
  float confidence;
  float vigor;
  float exploration_temperature;
  float controller_phase;
  float interruption_cost;
  float progress;
  float predicted_effort;
  float predicted_information_gain;
  float unsupported_uncertainty;
  float reserved_float;
  ulong reserved0;
  ulong reserved1;
  ulong reserved2;
  ulong reserved3;
};

struct NBOptionCandidateRecord {
  ulong option_identifier;
  ulong goal_identifier;
  float task_value;
  float homeostatic_value;
  float social_value;
  float information_gain;
  float damage_cvar;
  float effort_cost;
  float switching_cost;
  float competence;
  uint proposal_kind;
  uint source_module;
  uint flags;
  uint parameter_count;
  float parameters[16];
};

struct NBPlanStepRecord {
  ulong option_identifier;
  ulong goal_identifier;
  float objective_value;
  float damage_cvar;
  float epistemic_uncertainty;
  float predicted_effort;
  float predicted_information_gain;
  float duration_seconds;
  float predicted_drive_change;
  float admissibility;
  uint sequence;
  uint flags;
  uint parameter_count;
  uint reserved;
  float predicted_state[16];
};

struct NBCounterfactualWorldOutcome {
  float mean_prediction;
  float epistemic_uncertainty;
  float damage_cvar;
  float aleatoric_variance;
};

struct NBRetrievedOptionOutcome {
  float support;
  float damage;
  float uncertainty;
  float reinforcement;
};

struct NBSemanticGoalOutcome {
  float support;
  float damage;
  float reinforcement;
};

struct NBExternalGoalContext {
  float valid;
  float priority;
  float damage_risk_budget;
  float persistence;
  float target[16];
};

struct NBMotorCommandRecord {
  float excitation;
  float force_target;
  float stiffness_target;
  float damping_target;
  float cerebellar_residual;
  float risk_inhibition;
  uint synergy_identifier;
  uint flags;
};

struct NBMotorGoalRecord {
  ulong option_identifier;
  ulong goal_identifier;
  ulong timestamp_microseconds;
  ulong movement_duration_microseconds;
  float task_space_target[4];
  float velocity_target[4];
  float force_target[4];
  float stiffness_target[4];
  float damping_target[4];
  float orientation_target[4];
  float confidence;
  float risk;
  float support;
  float uncertainty;
  uint target_body_identifier;
  uint flags;
  uint synergy_count;
  uint parameter_count;
  float synergy_coefficients[16];
  float reserved[8];
};

struct NBCerebellarExpertRecord {
  uint expert_identifier;
  uint flags;
  float weight;
  float prediction_error;
  ulong prediction_timestamp_microseconds;
  uint prediction_count;
  uint reserved;
  // 4...11 forward predictions, 12...19 actuator-local inverse corrections,
  // 20...27 command features, 28...35 learned forward effects,
  // 36...43 packed actuator/feature identities, 44...51 source records.
  float state[56];
};

struct NBSpinalStateRecord {
  float reflex_output;
  float cpg_output;
  float motor_neuron_state;
  float final_excitation;
};

struct NBAutonomicCommandRecord {
  float command;
  float target;
  float confidence;
  uint flags;
};

struct NBCommunicationChannelDescriptor {
  uint effector_kind;
  uint local_channel_index;
  float gain;
  uint flags;
};

struct NBAutonomicChannelDescriptor {
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

struct NBActiveSensingChannelDescriptor {
  uint channel_identifier;
  uint modality;
  uint modality_local_identifier;
  uint flags;
};

struct NBCPGOscillatorDescriptor {
  uint identifier;
  uint output_synergy_identifier;
  float natural_frequency_hertz;
  float duty_factor;
  ulong sensory_reset_mask;
  ulong output_kind;
};

struct NBCPGCouplingDescriptor {
  uint source_oscillator_index;
  uint destination_oscillator_index;
  float phase_offset;
  float gain;
};

struct NBCPGStateRecord {
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

struct NBFastCerebellarStateRecord {
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

struct NBEventQueueHeader {
  atomic_uint count;
  uint capacity;
  atomic_uint overflow_count;
  uint flags;
  ulong target_timestamp_microseconds;
  ulong generation;
};

struct NBReceptorEventRecord {
  uint environment_identifier;
  uint kind;
  uint source_identifier;
  uint flags;
  ulong timestamp_microseconds;
  float magnitude;
  float auxiliary_value;
};

struct NBActiveSensingCommandRecord {
  float command;
  float confidence;
  uint attention_allocation_mask;
  uint kind_and_flags;
};

struct NBActiveSensingEfficacyRecord {
  float prior_uncertainty;
  float accepted_uncertainty;
  float efficacy;
  float realized_information_gain;
  uint sample_count;
  uint flags;
  float allocation;
  float reserved;
};

struct NBSpatialTransformRecord {
  uint source_frame;
  uint destination_frame;
  uint flags;
  uint reserved;
  float translation[4];
  float rotation[4];
  float linear_velocity[4];
  float angular_velocity[4];
  float uncertainty;
  float confidence;
  ulong last_evidence_timestamp_microseconds;
};

struct NBObjectSlotRecord {
  ulong identifier;
  ulong last_seen_timestamp_microseconds;
  uint format_version;
  uint flags;
  float existence_probability;
  float identity_confidence;
  float visibility;
  float uncertainty;
  float pose[4];
  float velocity[4];
  float affordances[8];
  float latent[102];
};

struct NBInternalActionRecord {
  ulong target_identifier;
  ulong timestamp_microseconds;
  uint kind;
  uint flags;
  uint parameter_count;
  uint reserved;
  float priority;
  float confidence;
  float parameters[6];
};

struct NBDevelopmentalHeader {
  uint format_version;
  uint stage;
  uint stage_count;
  uint flags;
  ulong developmental_age_microseconds;
  ulong last_transition_timestamp_microseconds;
  float maturation_progress;
  float sensor_precision_multiplier;
  float muscle_strength_multiplier;
  float replay_allocation_multiplier;
  float learning_rate_multiplier;
  uint workspace_capacity;
  uint planning_horizon_steps;
  uint module_count;
  uint evidence_count;
  ulong species_template_fingerprint;
  ulong accepted_physics_state_fingerprint;
  ulong reserved[21];
};

static_assert(sizeof(NBDecisionUniforms) == 448);
static_assert(sizeof(NBDriveRecord) == 32);
static_assert(sizeof(NBNeuromodulatorRecord) == 16);
static_assert(sizeof(NBRegionalPlasticModulationRecord) == 64);
static_assert(sizeof(NBWorkspaceMetadataRecord) == 96);
static_assert(sizeof(NBControlHeader) == 128);
static_assert(sizeof(NBOptionCandidateRecord) == 128);
static_assert(sizeof(NBPlanStepRecord) == 128);
static_assert(sizeof(NBMotorCommandRecord) == 32);
static_assert(sizeof(NBMotorGoalRecord) == 256);
static_assert(sizeof(NBCerebellarExpertRecord) == 256);
static_assert(sizeof(NBSpinalStateRecord) == 16);
static_assert(sizeof(NBAutonomicCommandRecord) == 16);
static_assert(sizeof(NBCommunicationChannelDescriptor) == 16);
static_assert(sizeof(NBAutonomicChannelDescriptor) == 48);
static_assert(sizeof(NBActiveSensingChannelDescriptor) == 16);
static_assert(sizeof(NBCPGOscillatorDescriptor) == 32);
static_assert(sizeof(NBCPGCouplingDescriptor) == 16);
static_assert(sizeof(NBCPGStateRecord) == 64);
static_assert(sizeof(NBFastCerebellarStateRecord) == 64);
static_assert(sizeof(NBEventQueueHeader) == 32);
static_assert(sizeof(NBReceptorEventRecord) == 32);
static_assert(sizeof(NBActiveSensingCommandRecord) == 16);
static_assert(sizeof(NBExternalGoalDirectiveRecord) == 240);
static_assert(sizeof(NBActiveSensingEfficacyRecord) == 32);
static_assert(sizeof(NBSpatialTransformRecord) == 96);
static_assert(sizeof(NBObjectSlotRecord) == 512);
static_assert(sizeof(NBInternalActionRecord) == 64);
static_assert(sizeof(NBDevelopmentalHeader) == 256);

inline bool nb_uses_muscle_excitation(const uint actuator_command_kind) {
  return actuator_command_kind == NB_ACTUATOR_COMMAND_MUSCLE_EXCITATION;
}

inline float2 nb_decision_regional_modulation(
  device const uchar *hot_state,
  constant NBDecisionUniforms &uniforms)
{
  device const NBRegionalPlasticModulationRecord *regional =
    reinterpret_cast<device const NBRegionalPlasticModulationRecord *>(
      hot_state + uniforms.regional_plastic_modulation_offset
    );
  float2 effects = float2(0.0f);
  uint count = 0u;
  for (uint index = 0u;
      index < uniforms.regional_plastic_modulation_count; ++index) {
    const NBRegionalPlasticModulationRecord record = regional[index];
    if (record.module_identifier < 71u || record.module_identifier > 78u
        || record.coefficient_count == 0u || (record.flags & 1u) == 0u) {
      continue;
    }
    effects += float2(
      record.vigor_multiplier,
      record.exploration_temperature_multiplier
    );
    count += 1u;
  }
  return count > 0u ? effects / float(count) : float2(1.0f);
}

/// Converts an unconstrained policy logit into the species' normalized neural
/// command space. Biological muscle excitation is zero-based. Other actuator
/// kinds are signed around 0.5 so a zero logit is an exact neutral command.
inline float nb_motor_drive_from_logit(
  const float logit,
  const uint actuator_command_kind)
{
  const float signed_drive = tanh(logit);
  return nb_uses_muscle_excitation(actuator_command_kind)
    ? clamp(signed_drive, 0.0f, 1.0f)
    : fma(0.5f, signed_drive, 0.5f);
}

/// Applies gain or inhibition without moving a non-muscle command's neutral.
inline float nb_scale_motor_drive(
  const float drive,
  const float scale,
  const uint actuator_command_kind)
{
  const float bounded_scale = max(scale, 0.0f);
  return nb_uses_muscle_excitation(actuator_command_kind)
    ? drive * bounded_scale
    : fma(drive - 0.5f, bounded_scale, 0.5f);
}

inline float nb_motor_neutral(const uint actuator_command_kind) {
  return nb_uses_muscle_excitation(actuator_command_kind) ? 0.0f : 0.5f;
}

inline float nb_motor_feature(
  const float drive,
  const uint actuator_command_kind)
{
  return nb_uses_muscle_excitation(actuator_command_kind)
    ? clamp(drive, 0.0f, 1.0f)
    : clamp(fma(2.0f, drive, -1.0f), -1.0f, 1.0f);
}

/// The exact sixteen-coordinate slow policy head differentiated by
/// MLXBrainLearner. Its output is a cortical synergy command; the immutable
/// species decoder, task controller, spinal state, reflexes, cerebellum, and
/// final actuator clamps remain the physical execution authority.
inline float nb_learned_policy_synergy(
  device const float *recurrent,
  const uint recurrent_count,
  device const float *policy_parameters,
  device const float *belief_parameters,
  device const float *policy_observation_sketch,
  const uint synergy)
{
  if (recurrent_count == 0u || synergy >= 16u) return 0.0f;
  // The learner journals three coordinates for each of up to eight sensory
  // modalities (24 total), while the enacted action has sixteen synergies.
  // Preserve the first sixteen coordinates as the primary basis and fold the
  // remaining eight into the corresponding first eight synergies. Without
  // this fold, the final modalities in canonical order (including the full
  // kinesthetic slot) could be published and learned but never affect action.
  float folded_observation = policy_observation_sketch[synergy];
  float folded_validity = policy_observation_sketch[24u + synergy];
  if (synergy < 8u) {
    folded_observation += 0.25f
      * policy_observation_sketch[16u + synergy];
    folded_validity += 0.25f
      * policy_observation_sketch[40u + synergy];
  }
  const float posterior = tanh(
    belief_parameters[7] * recurrent[synergy % recurrent_count]
      + belief_parameters[0] * folded_observation
      + belief_parameters[15] * folded_validity
      + belief_parameters[4]
  );
  return tanh(
    posterior * policy_parameters[0] + policy_parameters[8]
  );
}

inline ulong nb_policy_observation_hash(ulong value) {
  value ^= value >> 30;
  value *= 0xbf58476d1ce4e5b9ul;
  value ^= value >> 27;
  value *= 0x94d049bb133111ebul;
  return value ^ (value >> 31);
}

inline float nb_policy_raw_sensor_value(
  const uint modality_slot,
  const uint scalar_index,
  device const float *raw0,
  device const float *raw1,
  device const float *raw2,
  device const float *raw3,
  device const float *raw4,
  device const float *raw5,
  device const float *raw6,
  device const float *raw7)
{
  switch (modality_slot) {
    case 0u: return raw0[scalar_index];
    case 1u: return raw1[scalar_index];
    case 2u: return raw2[scalar_index];
    case 3u: return raw3[scalar_index];
    case 4u: return raw4[scalar_index];
    case 5u: return raw5[scalar_index];
    case 6u: return raw6[scalar_index];
    default: return raw7[scalar_index];
  }
}

/// Reconstructs the exact deterministic 24-coordinate raw-sensor projection
/// journaled for the slow learner. One thread owns one projection coordinate;
/// the second 24-float half is the evaluator's exact validity mask.
kernel void sketch_policy_observations(
  device const uchar *hot_state [[buffer(0)]],
  device float *policy_observation_sketch [[buffer(14)]],
  device const float *raw_sensor0 [[buffer(16)]],
  device const float *raw_sensor1 [[buffer(17)]],
  device const float *raw_sensor2 [[buffer(18)]],
  device const float *raw_sensor3 [[buffer(19)]],
  device const float *raw_sensor4 [[buffer(20)]],
  device const float *raw_sensor5 [[buffer(21)]],
  device const float *raw_sensor6 [[buffer(22)]],
  device const float *raw_sensor7 [[buffer(23)]],
  device const uint *metadata [[buffer(24)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= 24u) return;
  const uint modality_slot = gid / 3u;
  const uint projection = gid % 3u;
  const uint modality_count = min(metadata[0], 8u);
  policy_observation_sketch[gid] = 0.0f;
  policy_observation_sketch[24u + gid] = 0.0f;
  if (modality_slot >= modality_count) return;
  const uint range_base = 4u + modality_slot * 3u;
  const uint modality_code = metadata[range_base];
  const uint scalar_offset = metadata[range_base + 1u];
  const uint scalar_count = metadata[range_base + 2u];
  const uint observation_count = metadata[1];
  if (modality_code == 0u || scalar_count == 0u
      || scalar_offset >= observation_count
      || scalar_count > observation_count - scalar_offset) {
    return;
  }
  const ulong validity_offset = ulong(metadata[2])
    | (ulong(metadata[3]) << 32u);
  device const uint *observation_validity =
    reinterpret_cast<device const uint *>(hot_state + validity_offset);
  const uint sample_count = min(scalar_count, 1024u);
  float projection_sum = 0.0f;
  uint valid_sample_count = 0u;
  for (uint sample = 0u; sample < sample_count; ++sample) {
    const uint local_index = uint(
      (ulong(sample) * ulong(scalar_count)) / ulong(sample_count)
    );
    if (observation_validity[scalar_offset + local_index] == 0u) continue;
    const float value = nb_policy_raw_sensor_value(
      modality_slot, local_index,
      raw_sensor0, raw_sensor1, raw_sensor2, raw_sensor3,
      raw_sensor4, raw_sensor5, raw_sensor6, raw_sensor7
    );
    if (!isfinite(value)) continue;
    const ulong projection_key =
      (ulong(modality_code) << 48u)
      ^ (ulong(local_index) << 8u)
      ^ ulong(projection)
      ^ 0x4e58534b45544348ul;
    const float sign = (nb_policy_observation_hash(projection_key) & 1ul) != 0ul
      ? 1.0f : -1.0f;
    projection_sum += sign * value;
    valid_sample_count += 1u;
  }
  if (valid_sample_count == 0u) return;
  policy_observation_sketch[gid] = projection_sum
    / float(valid_sample_count);
  policy_observation_sketch[24u + gid] = 1.0f;
}

inline float nb_normalized_body_feature_value(float value, uint feature) {
  if (!isfinite(value)) return 0.0f;
  if (feature >= NB_BODY_ORIENTATION
      && feature < NB_BODY_ORIENTATION + 4u) {
    return clamp(value, -1.0f, 1.0f);
  }
  if ((feature >= NB_BODY_POSITION_VARIANCE
        && feature < NB_BODY_POSITION_VARIANCE + 3u)
      || (feature >= NB_BODY_ORIENTATION_VARIANCE
        && feature < NB_BODY_ORIENTATION_VARIANCE + 3u)
      || feature == NB_BODY_LOAD_VARIANCE) {
    const float standard_deviation = sqrt(max(value, 0.0f));
    return standard_deviation / (1.0f + standard_deviation);
  }
  if (feature == NB_BODY_CONTACT || feature == NB_BODY_SUPPORT
      || feature == NB_BODY_PAIN
      || feature == NB_BODY_VULNERABILITY
      || feature == NB_BODY_REACHABILITY || feature == NB_BODY_OWNERSHIP
      || feature == NB_BODY_DAMAGE_RISK
      || feature == NB_BODY_EXTERNAL_DISTURBANCE) {
    return clamp(value, 0.0f, 1.0f);
  }
  return value / (1.0f + abs(value));
}

inline float nb_normalized_joint_feature_value(float value, uint feature) {
  if (!isfinite(value)) return 0.0f;
  if ((feature >= NB_JOINT_POSITION_VARIANCE
        && feature < NB_JOINT_POSITION_VARIANCE + 6u)
      || (feature >= NB_JOINT_VELOCITY_VARIANCE
        && feature < NB_JOINT_VELOCITY_VARIANCE + 6u)) {
    const float standard_deviation = sqrt(max(value, 0.0f));
    return standard_deviation / (1.0f + standard_deviation);
  }
  if ((feature >= NB_JOINT_LIMIT_ACTIVATION
        && feature < NB_JOINT_LIMIT_ACTIVATION + 6u)
      || feature == NB_JOINT_OWNERSHIP) {
    return clamp(value, 0.0f, 1.0f);
  }
  if (feature == NB_JOINT_PREDICTION_ERROR) {
    const float magnitude = abs(value);
    return magnitude / (1.0f + magnitude);
  }
  return value / (1.0f + abs(value));
}

inline float nb_normalized_muscle_feature_value(float value, uint feature) {
  if (!isfinite(value)) return 0.0f;
  if (feature == 0u || feature == 4u || feature == 8u || feature == 9u) {
    return clamp(value, 0.0f, 1.0f);
  }
  if (feature == 3u || feature == 5u) {
    const float magnitude = abs(value);
    return magnitude / (1.0f + magnitude);
  }
  return value / (1.0f + abs(value));
}

inline float nb_motor_goal_body_feature(
  device const NBMotorGoalRecord *goal,
  uint feature,
  float baseline)
{
  if (feature < NB_BODY_POSITION + 3u) {
    return nb_normalized_body_feature_value(
      goal->task_space_target[feature - NB_BODY_POSITION], feature
    );
  }
  if (feature >= NB_BODY_ORIENTATION
      && feature < NB_BODY_ORIENTATION + 4u) {
    return goal->orientation_target[feature - NB_BODY_ORIENTATION];
  }
  if (feature >= NB_BODY_LINEAR_VELOCITY
      && feature < NB_BODY_LINEAR_VELOCITY + 3u) {
    return nb_normalized_body_feature_value(
      goal->velocity_target[feature - NB_BODY_LINEAR_VELOCITY], feature
    );
  }
  if (feature == NB_BODY_SUPPORT) return goal->support;
  if (feature >= NB_BODY_LOCAL_FORCE
      && feature < NB_BODY_LOCAL_FORCE + 3u) {
    return nb_normalized_body_feature_value(
      goal->force_target[feature - NB_BODY_LOCAL_FORCE], feature
    );
  }
  if (feature == NB_BODY_DAMAGE_RISK) return goal->risk;
  if (feature == NB_BODY_LOAD_VARIANCE) return goal->uncertainty;
  return baseline;
}

inline uint nb_active_candidate_limit(
  constant NBDecisionUniforms &uniforms,
  device const NBDevelopmentalHeader *development)
{
  const uint memory_candidate_limit = 10u
    + (uniforms.workspace_capacity > 3u
      ? uniforms.workspace_capacity - 3u
      : 0u);
  return min(
    min(uniforms.candidate_capacity, memory_candidate_limit),
    max(4u, min(uniforms.candidate_capacity, 4u + development->stage * 3u))
  );
}

inline ulong nb_goal_identifier(uint origin, ulong source_identifier) {
  return (ulong(origin) << 56) | ((source_identifier + 1ul)
    & 0x00fffffffffffffful);
}

inline float3 nb_rotate_vector(float3 vector, float4 quaternion) {
  const float norm_squared = dot(quaternion, quaternion);
  if (norm_squared <= 1.0e-8f) return vector;
  const float4 normalized = quaternion * rsqrt(norm_squared);
  const float3 twice_cross = 2.0f * cross(normalized.xyz, vector);
  return vector + normalized.w * twice_cross
    + cross(normalized.xyz, twice_cross);
}

inline float nb_modality_epistemic_uncertainty(
  device const float *world,
  uint world_count,
  uint modality)
{
  if (world_count < 8u * NB_WORLD_RECEPTOR_DIMENSION) return 0.0f;
  uint begin = 0u;
  uint end = 32u;
  switch (modality) {
    case 2u: begin = 32u; end = 48u; break;
    case 3u: begin = 48u; end = 64u; break;
    case 4u: begin = 64u; end = 80u; break;
    case 5u: begin = 80u; end = 96u; break;
    case 6u: begin = 96u; end = 108u; break;
    case 7u: begin = 108u; end = 116u; break;
    case 8u: begin = 116u; end = 128u; break;
    default: break;
  }
  float total_variance = 0.0f;
  for (uint index = begin; index < end; ++index) {
    float mean = 0.0f;
    for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
      mean += world[(3u + head) * NB_WORLD_RECEPTOR_DIMENSION + index]
        / float(NB_WORLD_HEAD_COUNT);
    }
    for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
      const float difference = world[
        (3u + head) * NB_WORLD_RECEPTOR_DIMENSION + index
      ] - mean;
      total_variance += difference * difference
        / float(NB_WORLD_HEAD_COUNT);
    }
  }
  return sqrt(total_variance / float(max(end - begin, 1u)));
}

inline float nb_articulated_joint_risk(
  device const uchar *hot_state,
  constant NBDecisionUniforms &uniforms,
  thread float &uncertainty)
{
  float risk = 0.0f;
  uncertainty = 0.0f;
  device const uchar *joint_belief = hot_state + uniforms.joint_belief_offset;
  for (uint joint_index = 0u;
      joint_index < uniforms.joint_belief_count; ++joint_index) {
    device const float *joint = reinterpret_cast<device const float *>(
      joint_belief + ulong(joint_index) * 256ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      joint + NB_JOINT_IDENTITY_FLOAT_OFFSET
    );
    if ((identity[7] & 1ul) == 0ul) continue;
    const uint coordinate_count = min(uint(identity[3]), 6u);
    float variance = 0.0f;
    float limit_activation = 0.0f;
    for (uint coordinate = 0u; coordinate < coordinate_count; ++coordinate) {
      variance += max(joint[NB_JOINT_POSITION_VARIANCE + coordinate], 0.0f)
        + max(joint[NB_JOINT_VELOCITY_VARIANCE + coordinate], 0.0f);
      limit_activation = max(
        limit_activation,
        clamp(joint[NB_JOINT_LIMIT_ACTIVATION + coordinate], 0.0f, 1.0f)
      );
    }
    const float normalized_uncertainty = sqrt(
      variance / max(float(coordinate_count * 2u), 1.0f)
    );
    const float unsupported = normalized_uncertainty
      / (1.0f + normalized_uncertainty);
    uncertainty = max(
      uncertainty,
      max(unsupported, 1.0f - clamp(joint[NB_JOINT_OWNERSHIP], 0.0f, 1.0f))
    );
    risk = max(
      risk,
      max(
        limit_activation,
        abs(joint[NB_JOINT_PREDICTION_ERROR])
          / (1.0f + abs(joint[NB_JOINT_PREDICTION_ERROR]))
      )
    );
  }
  return clamp(risk, 0.0f, 1.0f);
}

inline float nb_embodied_self_risk(
  device const uchar *hot_state,
  constant NBDecisionUniforms &uniforms)
{
  float risk = 0.0f;
  device const uchar *body_belief = hot_state + uniforms.body_belief_offset;
  for (uint body_index = 0u;
      body_index < uniforms.body_belief_count; ++body_index) {
    device const float *body = reinterpret_cast<device const float *>(
      body_belief + ulong(body_index) * 256ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      body + NB_BODY_IDENTITY_FLOAT_OFFSET
    );
    if ((identity[3] & 1ul) == 0ul) continue;
    risk = max(risk, max(
      clamp(body[NB_BODY_PAIN], 0.0f, 1.0f),
      max(
        clamp(body[NB_BODY_VULNERABILITY], 0.0f, 1.0f),
        clamp(body[NB_BODY_DAMAGE_RISK], 0.0f, 1.0f)
      )
    ));
  }
  device const uchar *effector_belief =
    hot_state + uniforms.somatic_effector_belief_offset;
  for (uint index = 0u;
      index < uniforms.somatic_effector_belief_count; ++index) {
    device const float *effector = reinterpret_cast<device const float *>(
      effector_belief + ulong(index) * 192ul
    );
    risk = max(risk, clamp(effector[9], 0.0f, 1.0f));
  }
  float joint_uncertainty = 0.0f;
  risk = max(
    risk,
    nb_articulated_joint_risk(hot_state, uniforms, joint_uncertainty)
  );
  return risk;
}

inline ulong nb_interrupt_mask_for_event_kind(uint kind) {
  switch (kind) {
    case 3u: return 1ul << 3u;
    case 5u: return 1ul << 2u;
    case 6u: return 1ul << 5u;
    case 7u: return 1ul << 6u;
    case 8u: return 1ul << 0u;
    case 9u: return 1ul << 1u;
    case 10u: return 1ul << 7u;
    case 11u: return 1ul << 8u;
    case 12u: return 1ul << 4u;
    case 13u: return 1ul << 9u;
    default: return 0ul;
  }
}

/// Maps one parameterized option into the scalar action context expected by
/// the learned hierarchical world dynamics. Every planning branch starts from
/// the same world feature; only its proposed action and rolled latent state
/// perturb the head preactivation.
inline float nb_counterfactual_option_context(
  const NBOptionCandidateRecord candidate,
  thread const float *rollout_state,
  const uint component)
{
  const uint parameter_count = min(max(candidate.parameter_count, 1u), 16u);
  const uint primary = component % parameter_count;
  const uint paired = (component + 7u) % parameter_count;
  return tanh(
    0.5f * candidate.parameters[primary]
      + 0.25f * candidate.parameters[paired]
      + 0.25f * rollout_state[component % 16u]
  );
}

inline NBCounterfactualWorldOutcome nb_counterfactual_world_outcome(
  device const float *world,
  device const float *world_parameters,
  constant NBDecisionUniforms &uniforms,
  const NBOptionCandidateRecord candidate,
  thread const float *rollout_state,
  const uint step,
  const bool structured_world_available)
{
  NBCounterfactualWorldOutcome outcome = {};
  float head_values[NB_WORLD_HEAD_COUNT];
  const uint planning_level = step == 0u ? 3u : 4u;
  for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
    float prediction = 0.0f;
    for (uint feature = 0u; feature < 16u; ++feature) {
      const uint world_component = (step * 16u + feature)
        % NB_WORLD_EVENT_OPTION_DIMENSION;
      const float baseline = structured_world_available
        ? world[NB_WORLD_EVENT_OPTION_BASE
            + (3u + head) * NB_WORLD_EVENT_OPTION_DIMENSION + world_component]
        : world[(world_component * NB_WORLD_HEAD_COUNT + head)
            % uniforms.world_model_scalar_count];
      const float base_logit = atanh(clamp(baseline, -0.999f, 0.999f));
      const float option_context = nb_counterfactual_option_context(
        candidate, rollout_state, world_component
      );
      prediction += tanh(
        base_logit
          + world_parameters[
            160u + planning_level * NB_WORLD_HEAD_COUNT + head
          ] * option_context
      ) / 16.0f;
    }
    head_values[head] = prediction;
    outcome.mean_prediction += prediction / float(NB_WORLD_HEAD_COUNT);
  }
  float epistemic_variance = 0.0f;
  float largest_head_damage = 0.0f;
  float second_largest_head_damage = 0.0f;
  for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
    const float difference = head_values[head] - outcome.mean_prediction;
    epistemic_variance += difference * difference / float(NB_WORLD_HEAD_COUNT);
    const float head_damage = clamp(head_values[head], 0.0f, 1.0f);
    if (head_damage >= largest_head_damage) {
      second_largest_head_damage = largest_head_damage;
      largest_head_damage = head_damage;
    } else if (head_damage > second_largest_head_damage) {
      second_largest_head_damage = head_damage;
    }
  }
  outcome.epistemic_uncertainty = sqrt(max(epistemic_variance, 0.0f));
  // Five heads make the exact upper 40 percent tail the two worst learned
  // outcomes. Aleatoric observation variance remains a separate risk input.
  outcome.damage_cvar =
    (largest_head_damage + second_largest_head_damage)
      / float(NB_WORLD_CVAR_TAIL_COUNT);
  outcome.aleatoric_variance = structured_world_available
    ? max(world[NB_WORLD_EVENT_OPTION_BASE
        + 8u * NB_WORLD_EVENT_OPTION_DIMENSION
        + (step * 16u) % NB_WORLD_EVENT_OPTION_DIMENSION], 0.0f)
    : 0.0f;
  return outcome;
}

inline NBRetrievedOptionOutcome nb_retrieved_option_outcome(
  device const float *workspace,
  device const NBWorkspaceMetadataRecord *workspace_metadata,
  constant NBDecisionUniforms &uniforms,
  const ulong option_identifier)
{
  NBRetrievedOptionOutcome outcome = {};
  if (uniforms.workspace_dimension < 14u) return outcome;
  for (uint memory_slot = 3u;
      memory_slot < min(uniforms.workspace_capacity, 7u); ++memory_slot) {
    const NBWorkspaceMetadataRecord memory_token =
      workspace_metadata[memory_slot];
    const uint memory_source = memory_token.kind_and_source >> 16u;
    if (memory_source != 56u
        || memory_token.bound_token_identifier != option_identifier
        || memory_token.confidence <= outcome.support) continue;
    const uint memory_base = memory_slot * uniforms.workspace_dimension;
    outcome.support = clamp(memory_token.confidence, 0.0f, 1.0f);
    outcome.uncertainty = clamp(workspace[memory_base + 11u], 0.0f, 1.0f);
    outcome.damage = clamp(workspace[memory_base + 12u], 0.0f, 1.0f);
    outcome.reinforcement = clamp(
      workspace[memory_base + 13u], -1.0f, 1.0f
    );
  }
  return outcome;
}

inline ulong nb_semantic_hash(ulong value) {
  value ^= value >> 30u;
  value *= 0xbf58476d1ce4e5b9ul;
  value ^= value >> 27u;
  value *= 0x94d049bb133111ebul;
  return value ^ (value >> 31u);
}

inline NBSemanticGoalOutcome nb_retrieved_semantic_goal_outcome(
  device const float *workspace,
  device const NBWorkspaceMetadataRecord *workspace_metadata,
  constant NBDecisionUniforms &uniforms,
  const ulong goal_identifier)
{
  NBSemanticGoalOutcome outcome = {};
  if (goal_identifier == 0ul || uniforms.workspace_dimension < 14u) {
    return outcome;
  }
  const ulong semantic_goal_identifier = max(
    nb_semantic_hash(goal_identifier ^ 0x474f414c434f4e43ul)
      & 0x3ffffffffffffffful,
    1ul
  );
  for (uint memory_slot = 3u;
      memory_slot < min(uniforms.workspace_capacity, 7u); ++memory_slot) {
    const NBWorkspaceMetadataRecord memory_token =
      workspace_metadata[memory_slot];
    const uint memory_source = memory_token.kind_and_source >> 16u;
    if (memory_source != 58u
        || memory_token.goal_identifier != semantic_goal_identifier
        || memory_token.confidence <= outcome.support) continue;
    const uint memory_base = memory_slot * uniforms.workspace_dimension;
    outcome.support = clamp(memory_token.confidence, 0.0f, 1.0f);
    outcome.reinforcement = clamp(
      workspace[memory_base + 12u], -1.0f, 1.0f
    );
    outcome.damage = clamp(workspace[memory_base + 13u], 0.0f, 1.0f);
  }
  // Resolve an explicit goal-to-event relation only when the related event
  // concept is present in the same bounded retrieval set. This preserves the
  // graph edge, its contradiction evidence, and the destination outcome as
  // one joined planning fact instead of treating a relation embedding as an
  // ungrounded scalar preference.
  for (uint relation_slot = 3u;
      relation_slot < min(uniforms.workspace_capacity, 7u); ++relation_slot) {
    const NBWorkspaceMetadataRecord relation_token =
      workspace_metadata[relation_slot];
    const uint relation_source = relation_token.kind_and_source >> 16u;
    if (relation_source != 59u
        || relation_token.goal_identifier != semantic_goal_identifier
        || relation_token.bound_token_identifier == 0ul) continue;
    const uint relation_base = relation_slot * uniforms.workspace_dimension;
    const float relation_support = clamp(relation_token.confidence, 0.0f, 1.0f)
      * (1.0f - clamp(workspace[relation_base + 11u], 0.0f, 1.0f));
    for (uint concept_slot = 3u;
        concept_slot < min(uniforms.workspace_capacity, 7u); ++concept_slot) {
      const NBWorkspaceMetadataRecord concept_token =
        workspace_metadata[concept_slot];
      const uint concept_source = concept_token.kind_and_source >> 16u;
      if (concept_source != 58u
          || concept_token.entity_identifier
            != relation_token.bound_token_identifier) continue;
      const float joined_support = relation_support
        * clamp(concept_token.confidence, 0.0f, 1.0f);
      if (joined_support <= outcome.support) continue;
      const uint concept_base = concept_slot * uniforms.workspace_dimension;
      outcome.support = joined_support;
      outcome.reinforcement = clamp(
        workspace[concept_base + 13u], -1.0f, 1.0f
      );
      outcome.damage = clamp(workspace[concept_base + 12u], 0.0f, 1.0f);
    }
  }
  return outcome;
}

inline NBExternalGoalContext nb_external_goal_context(
  device const float *workspace,
  device const NBWorkspaceMetadataRecord *workspace_metadata,
  constant NBDecisionUniforms &uniforms,
  const ulong goal_identifier)
{
  NBExternalGoalContext context = {};
  context.damage_risk_budget = uniforms.damage_risk_budget;
  if (uint(goal_identifier >> 56u) != 2u
      || (goal_identifier & (1ul << 55u)) == 0ul
      || uniforms.workspace_dimension < 22u) return context;
  for (uint slot = 7u; slot < min(uniforms.workspace_capacity, 11u); ++slot) {
    const NBWorkspaceMetadataRecord token = workspace_metadata[slot];
    if (token.goal_identifier != goal_identifier
        || token.provenance_record_identifier == 0ul) continue;
    const uint base = slot * uniforms.workspace_dimension;
    context.valid = 1.0f;
    context.priority = max(workspace[base], 0.0f);
    context.damage_risk_budget = clamp(
      workspace[base + 20u], 0.0f, 1.0f
    );
    context.persistence = clamp(workspace[base + 21u], 0.0f, 1.0f);
    for (uint component = 0u; component < 16u; ++component) {
      context.target[component] = workspace[base + 4u + component];
    }
    break;
  }
  return context;
}

inline float nb_external_goal_state_alignment(
  const NBExternalGoalContext context,
  thread const float *predicted_state)
{
  if (context.valid <= 0.0f) return 0.0f;
  float dot_product = 0.0f;
  float target_norm = 1.0e-6f;
  float state_norm = 1.0e-6f;
  for (uint component = 0u; component < 16u; ++component) {
    dot_product += context.target[component] * predicted_state[component];
    target_norm += context.target[component] * context.target[component];
    state_norm += predicted_state[component] * predicted_state[component];
  }
  return dot_product * rsqrt(target_norm * state_norm);
}

kernel void generate_active_goal_state(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  device const float *value_parameters [[buffer(2)]],
  device const NBExternalGoalDirectiveRecord *external_goal [[buffer(12)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u) return;
  device const NBDriveRecord *drives = reinterpret_cast<device const NBDriveRecord *>(
    hot_state + uniforms.drive_offset
  );
  device float *workspace = reinterpret_cast<device float *>(
    hot_state + uniforms.workspace_offset
  );
  device NBWorkspaceMetadataRecord *metadata =
    reinterpret_cast<device NBWorkspaceMetadataRecord *>(
      hot_state + uniforms.workspace_metadata_offset
    );
  device NBControlHeader *header = reinterpret_cast<device NBControlHeader *>(
    hot_state + uniforms.control_header_offset
  );
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  const uint active_workspace_capacity = min(
    uniforms.workspace_capacity, development->workspace_capacity
  );
  NBWorkspaceMetadataRecord prior_goal_tokens[4] = {};
  for (uint rank = 0u; rank < 4u; ++rank) {
    const uint slot = 7u + rank;
    if (slot < active_workspace_capacity) {
      prior_goal_tokens[rank] = metadata[slot];
    }
  }
  const ulong previous_goal_identifier = header->active_goal_identifier;
  ulong goal_identifiers[4] = {};
  uint goal_origins[4] = {};
  uint goal_sources[4] = {};
  float goal_priorities[4] = {-INFINITY, -INFINITY, -INFINITY, -INFINITY};
  ulong external_goal_identifier = 0ul;
  ulong external_goal_source_identifier = 0ul;
  ulong external_goal_created_timestamp = 0ul;
  ulong external_goal_deadline = 0ul;
  float external_goal_base_priority = 0.0f;
  float external_goal_priority = 0.0f;
  float external_goal_risk_budget = uniforms.damage_risk_budget;
  float external_goal_persistence = 0.0f;
  float external_goal_target[16] = {};
  float external_goal_success_model[16] = {};
  float external_goal_failure_model[16] = {};
  for (uint drive_index = 0u; drive_index < uniforms.drive_count; ++drive_index) {
    uint origin = 1u;
    if (drive_index == 8u) origin = 5u;
    if (drive_index == 9u) origin = 4u;
    if (drive_index == 10u) origin = 2u;
    if (drive_index == 5u || drive_index == 6u || drive_index == 11u) origin = 6u;
    float priority = drives[drive_index].priority_weight
      * max(drives[drive_index].deficit, 0.0f);
    priority *= max(value_parameters[min(origin - 1u, 7u)], 0.0f);
    if (origin == 6u) priority += clamp(drives[drive_index].level, 0.0f, 1.0f);
    if (!isfinite(priority) || priority <= 0.0f) continue;
    const ulong identifier = nb_goal_identifier(origin, ulong(drive_index));
    if (identifier == header->active_goal_identifier) priority += 0.1f;
    for (uint rank = 0u; rank < 4u; ++rank) {
      if (priority > goal_priorities[rank]
          || (priority == goal_priorities[rank]
            && identifier < goal_identifiers[rank])) {
        for (uint shift = 3u; shift > rank; --shift) {
          goal_identifiers[shift] = goal_identifiers[shift - 1u];
          goal_origins[shift] = goal_origins[shift - 1u];
          goal_sources[shift] = goal_sources[shift - 1u];
          goal_priorities[shift] = goal_priorities[shift - 1u];
        }
        goal_identifiers[rank] = identifier;
        goal_origins[rank] = origin;
        goal_sources[rank] = drive_index;
        goal_priorities[rank] = priority;
        break;
      }
    }
  }
  const bool external_goal_valid = (external_goal->flags & 1ul) != 0ul
    && external_goal->identifier != 0ul
    && external_goal->created_timestamp_microseconds
      <= uniforms.target_timestamp_microseconds
    && (external_goal->deadline_timestamp_microseconds == 0ul
      || uniforms.target_timestamp_microseconds
        <= external_goal->deadline_timestamp_microseconds)
    && isfinite(external_goal->priority)
    && external_goal->priority > 0.0f;
  if (external_goal_valid) {
    external_goal_identifier = (2ul << 56u) | (1ul << 55u)
      | (external_goal->identifier & 0x007ffffffffffffful);
    external_goal_source_identifier = external_goal->identifier;
    external_goal_created_timestamp =
      external_goal->created_timestamp_microseconds;
    external_goal_deadline = external_goal->deadline_timestamp_microseconds;
    external_goal_risk_budget = clamp(
      external_goal->damage_risk_budget, 0.0f, 1.0f
    );
    external_goal_persistence = clamp(external_goal->persistence, 0.0f, 1.0f);
    for (uint component = 0u; component < 16u; ++component) {
      external_goal_target[component] = external_goal->target[component];
      external_goal_success_model[component] =
        external_goal->success_model[component];
      external_goal_failure_model[component] =
        external_goal->failure_model[component];
    }
    external_goal_base_priority = external_goal->priority
      * max(value_parameters[1], 0.0f);
    external_goal_priority = external_goal_base_priority;
    if (external_goal_identifier == previous_goal_identifier) {
      external_goal_priority += external_goal_persistence;
    }
    const bool completed_same_directive = external_goal_identifier
        == previous_goal_identifier
      && (header->progress >= 0.95f
        || (header->flags & NB_CONTROL_FLAG_EXTERNAL_GOAL_FAILED) != 0u)
      && external_goal_created_timestamp <= header->selected_timestamp_microseconds;
    for (uint rank = 0u; rank < 4u && !completed_same_directive
        && isfinite(external_goal_priority)
        && external_goal_priority > 0.0f; ++rank) {
      if (external_goal_priority > goal_priorities[rank]
          || (external_goal_priority == goal_priorities[rank]
            && external_goal_identifier < goal_identifiers[rank])) {
        for (uint shift = 3u; shift > rank; --shift) {
          goal_identifiers[shift] = goal_identifiers[shift - 1u];
          goal_origins[shift] = goal_origins[shift - 1u];
          goal_sources[shift] = goal_sources[shift - 1u];
          goal_priorities[shift] = goal_priorities[shift - 1u];
        }
        goal_identifiers[rank] = external_goal_identifier;
        goal_origins[rank] = 2u;
        goal_sources[rank] = 0xffffffffu;
        goal_priorities[rank] = external_goal_priority;
        break;
      }
    }
  }
  for (uint slot = 0u; slot < active_workspace_capacity; ++slot) {
    const NBWorkspaceMetadataRecord token = metadata[slot];
    const uint source_module = token.kind_and_source >> 16;
    const uint token_kind = token.kind_and_source & 0xffffu;
    const bool retained_external = external_goal_identifier == 0ul
      && source_module == 48u && token_kind == 2u
      && uint(token.goal_identifier >> 56u) == 2u
      && (token.goal_identifier & (1ul << 55u)) != 0ul
      && token.provenance_record_identifier != 0ul
      && !(token.goal_identifier == previous_goal_identifier
        && (header->progress >= 0.95f
          || (header->flags & NB_CONTROL_FLAG_EXTERNAL_GOAL_FAILED) != 0u))
      && (token.bound_token_identifier == 0ul
        || uniforms.target_timestamp_microseconds
          <= token.bound_token_identifier);
    if (retained_external) {
      const uint external_base = slot * uniforms.workspace_dimension;
      external_goal_identifier = token.goal_identifier;
      external_goal_source_identifier = token.provenance_record_identifier;
      external_goal_created_timestamp = token.source_timestamp_microseconds;
      external_goal_deadline = token.bound_token_identifier;
      external_goal_persistence = uniforms.workspace_dimension > 21u
        ? clamp(workspace[external_base + 21u], 0.0f, 1.0f) : 0.0f;
      external_goal_base_priority = uniforms.workspace_dimension > 22u
        ? max(workspace[external_base + 22u], 0.0f)
        : max(workspace[external_base] - external_goal_persistence, 0.0f);
      external_goal_risk_budget = uniforms.workspace_dimension > 20u
        ? clamp(workspace[external_base + 20u], 0.0f, 1.0f)
        : uniforms.damage_risk_budget;
      for (uint component = 0u; component < 16u; ++component) {
        external_goal_target[component] = uniforms.workspace_dimension
            > 4u + component
          ? workspace[external_base + 4u + component] : 0.0f;
        external_goal_success_model[component] = uniforms.workspace_dimension
            > 23u + component
          ? workspace[external_base + 23u + component] : 0.0f;
        external_goal_failure_model[component] = uniforms.workspace_dimension
            > 39u + component
          ? workspace[external_base + 39u + component] : 0.0f;
      }
      external_goal_priority = external_goal_base_priority
        + (external_goal_identifier == previous_goal_identifier
          ? external_goal_persistence : 0.0f);
      for (uint rank = 0u; rank < 4u; ++rank) {
        if (external_goal_priority > goal_priorities[rank]
            || (external_goal_priority == goal_priorities[rank]
              && external_goal_identifier < goal_identifiers[rank])) {
          for (uint shift = 3u; shift > rank; --shift) {
            goal_identifiers[shift] = goal_identifiers[shift - 1u];
            goal_origins[shift] = goal_origins[shift - 1u];
            goal_sources[shift] = goal_sources[shift - 1u];
            goal_priorities[shift] = goal_priorities[shift - 1u];
          }
          goal_identifiers[rank] = external_goal_identifier;
          goal_origins[rank] = 2u;
          goal_sources[rank] = slot;
          goal_priorities[rank] = external_goal_priority;
          break;
        }
      }
      continue;
    }
    const bool prospective = source_module == 61u;
    const bool social = source_module == 44u;
    const bool communication = source_module == 51u;
    const bool active_plan = source_module == 25u && token_kind == 9u;
    if ((!prospective && !social && !communication && !active_plan)
        || token.entity_identifier == 0ul) continue;
    const bool prospective_external = prospective
      && uint(token.goal_identifier >> 56u) == 2u
      && (token.goal_identifier & (1ul << 55u)) != 0ul;
    if (prospective_external && external_goal_identifier == 0ul
        && uniforms.workspace_dimension >= 67u) {
      const uint prospective_base = slot * uniforms.workspace_dimension;
      external_goal_identifier = token.goal_identifier;
      external_goal_source_identifier = token.goal_identifier
        & 0x007ffffffffffffful;
      external_goal_created_timestamp = token.source_timestamp_microseconds;
      external_goal_deadline = token.bound_token_identifier;
      external_goal_risk_budget = clamp(
        workspace[prospective_base + 64u], 0.0f, 1.0f
      );
      external_goal_persistence = clamp(
        workspace[prospective_base + 65u], 0.0f, 1.0f
      );
      external_goal_base_priority = max(
        workspace[prospective_base + 66u], 0.0f
      );
      for (uint component = 0u; component < 16u; ++component) {
        external_goal_target[component] =
          workspace[prospective_base + 16u + component];
        external_goal_success_model[component] =
          workspace[prospective_base + 32u + component];
        external_goal_failure_model[component] =
          workspace[prospective_base + 48u + component];
      }
    }
    const uint origin = prospective ? 3u
      : (communication ? 8u : (active_plan ? 7u : 4u));
    // A prospective record reactivates the goal it remembers. Its own record
    // identifier remains orthogonal lifecycle provenance in reserved2; using
    // it as the goal would erase the original physiological/task/social
    // semantics from action generation and accepted progress evaluation.
    const ulong identifier = prospective && token.goal_identifier != 0ul
      ? token.goal_identifier
      : nb_goal_identifier(origin, token.entity_identifier);
    float priority = clamp(token.confidence, 0.0f, 1.0f)
      * max(value_parameters[min(origin - 1u, 7u)], 0.0f);
    if (prospective) priority += 0.25f;
    if (social && uniforms.drive_count > 9u) {
      priority += 0.25f * drives[9].deficit;
    }
    if (!isfinite(priority) || priority <= 0.0f) continue;
    if (identifier == header->active_goal_identifier) priority += 0.1f;
    for (uint rank = 0u; rank < 4u; ++rank) {
      if (priority > goal_priorities[rank]
          || (priority == goal_priorities[rank]
            && identifier < goal_identifiers[rank])) {
        for (uint shift = 3u; shift > rank; --shift) {
          goal_identifiers[shift] = goal_identifiers[shift - 1u];
          goal_origins[shift] = goal_origins[shift - 1u];
          goal_sources[shift] = goal_sources[shift - 1u];
          goal_priorities[shift] = goal_priorities[shift - 1u];
        }
        goal_identifiers[rank] = identifier;
        goal_origins[rank] = prospective ? uint(identifier >> 56u) : origin;
        goal_sources[rank] = slot;
        goal_priorities[rank] = priority;
        break;
      }
    }
  }
  uint continuing_goal_rank = 4u;
  for (uint rank = 0u; rank < 4u; ++rank) {
    if (goal_identifiers[rank] == previous_goal_identifier) {
      continuing_goal_rank = rank;
      break;
    }
  }
  const bool emergency_preemption = goal_origins[0] == 6u
    && uint(previous_goal_identifier >> 56u) != 6u;
  if (continuing_goal_rank > 0u && continuing_goal_rank < 4u
      && !emergency_preemption) {
    const float accepted_progress = clamp(header->progress, 0.0f, 1.0f);
    const float midcourse_commitment =
      4.0f * accepted_progress * (1.0f - accepted_progress);
    const float required_switch_advantage = uniforms.switching_margin
      * (1.0f + midcourse_commitment)
      + max(header->interruption_cost, 0.0f);
    if (goal_priorities[0]
        < goal_priorities[continuing_goal_rank] + required_switch_advantage) {
      const ulong retained_identifier = goal_identifiers[continuing_goal_rank];
      const uint retained_origin = goal_origins[continuing_goal_rank];
      const uint retained_source = goal_sources[continuing_goal_rank];
      const float retained_priority = goal_priorities[continuing_goal_rank];
      for (uint rank = continuing_goal_rank; rank > 0u; --rank) {
        goal_identifiers[rank] = goal_identifiers[rank - 1u];
        goal_origins[rank] = goal_origins[rank - 1u];
        goal_sources[rank] = goal_sources[rank - 1u];
        goal_priorities[rank] = goal_priorities[rank - 1u];
      }
      goal_identifiers[0] = retained_identifier;
      goal_origins[0] = retained_origin;
      goal_sources[0] = retained_source;
      goal_priorities[0] = retained_priority;
    }
  }
  header->active_goal_identifier = goal_identifiers[0];
  header->reserved2 = 0ul;
  float active_intention_confidence = -INFINITY;
  for (uint slot = 0u; slot < active_workspace_capacity; ++slot) {
    const NBWorkspaceMetadataRecord token = metadata[slot];
    const uint source_module = token.kind_and_source >> 16;
    if (source_module != 61u || token.entity_identifier == 0ul
        || token.goal_identifier != goal_identifiers[0]) continue;
    const float confidence = clamp(token.confidence, 0.0f, 1.0f);
    if (confidence > active_intention_confidence
        || (confidence == active_intention_confidence
          && token.entity_identifier < header->reserved2)) {
      active_intention_confidence = confidence;
      header->reserved2 = token.entity_identifier;
    }
  }
  if (previous_goal_identifier != goal_identifiers[0]) {
    header->progress = 0.0f;
  }
  for (uint rank = 0u; rank < 4u; ++rank) {
    const uint slot = 7u + rank;
    if (slot >= active_workspace_capacity) break;
    const uint base = slot * uniforms.workspace_dimension;
    if (goal_identifiers[rank] == 0ul) {
      for (uint feature = 0u; feature < uniforms.workspace_dimension; ++feature) {
        workspace[base + feature] = 0.0f;
      }
      NBWorkspaceMetadataRecord empty = {};
      metadata[slot] = empty;
      continue;
    }
    for (uint feature = 0u; feature < uniforms.workspace_dimension; ++feature) {
      float value = 0.0f;
      if (feature == 0u) value = max(goal_priorities[rank], 0.0f);
      if (feature == 1u) value = float(goal_origins[rank]) / 9.0f;
      if (feature == 2u) value = goal_identifiers[rank]
          == external_goal_identifier
        ? 0.0f : float(goal_sources[rank]) / 64.0f;
      if (feature == 3u) value = rank == 0u ? 1.0f : 0.0f;
      if (goal_identifiers[rank] == external_goal_identifier) {
        if (feature >= 4u && feature < 20u) {
          value = external_goal_target[feature - 4u];
        } else if (feature == 20u) {
          value = external_goal_risk_budget;
        } else if (feature == 21u) {
          value = external_goal_persistence;
        } else if (feature == 22u) {
          value = external_goal_base_priority;
        } else if (feature >= 23u && feature < 39u) {
          value = external_goal_success_model[feature - 23u];
        } else if (feature >= 39u && feature < 55u) {
          value = external_goal_failure_model[feature - 39u];
        }
      }
      workspace[base + feature] = value;
    }
    uint matching_prior_rank = 0xffffffffu;
    for (uint prior_rank = 0u; prior_rank < 4u; ++prior_rank) {
      const NBWorkspaceMetadataRecord candidate = prior_goal_tokens[prior_rank];
      if (candidate.identifier != 0ul && (candidate.flags & 1u) != 0u
          && (candidate.kind_and_source & 0xffffu) == 2u
          && (candidate.kind_and_source >> 16u) == 48u
          && candidate.goal_identifier == goal_identifiers[rank]
          && candidate.entity_identifier == goal_identifiers[rank]) {
        matching_prior_rank = prior_rank;
        break;
      }
    }
    const bool existing_goal = matching_prior_rank != 0xffffffffu;
    NBWorkspaceMetadataRecord token = existing_goal
      ? prior_goal_tokens[matching_prior_rank]
      : NBWorkspaceMetadataRecord{};
    if (!existing_goal) {
      token.identifier = (uniforms.target_timestamp_microseconds << 8)
        | ulong(slot + 1u);
      token.source_timestamp_microseconds =
        goal_identifiers[rank] == external_goal_identifier
          ? external_goal_created_timestamp
          : uniforms.target_timestamp_microseconds;
    }
    token.last_refresh_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    token.entity_identifier = goal_identifiers[rank];
    token.goal_identifier = goal_identifiers[rank];
    if (goal_identifiers[rank] == external_goal_identifier) {
      token.bound_token_identifier = external_goal_deadline;
      token.provenance_record_identifier = external_goal_source_identifier;
    }
    token.kind_and_source = 2u | (48u << 16);
    token.confidence = clamp(goal_priorities[rank], 0.0f, 1.0f);
    token.persistence_priority = goal_identifiers[rank]
        == external_goal_identifier
      ? external_goal_persistence : (rank == 0u ? 0.8f : 0.5f);
    token.selection_score = clamp(goal_priorities[rank], 0.0f, 1.0f);
    token.provenance_kind = 0u;
    token.flags = 1u;
    token.provenance_source_generation = 0ul;
    token.last_score_update_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    metadata[slot] = token;
  }
}

/// Materializes the prior committed workspace-write request after ordinary
/// goal publication. Slot ten is the reserved internal-action handoff in the
/// complete workspace; reduced developmental capacities use their final
/// non-foundational slot.
kernel void apply_internal_workspace_write(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.workspace_dimension == 0u) return;
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  const uint active_capacity = min(
    uniforms.workspace_capacity, development->workspace_capacity
  );
  if (active_capacity <= 2u) return;
  device const NBInternalActionRecord *internal_actions =
    reinterpret_cast<device const NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  const NBInternalActionRecord request = internal_actions[1];
  if (request.kind != 2u || (request.flags & NB_CONTROL_FLAG_VALID) == 0u
      || request.target_identifier == 0ul) return;
  const uint slot = min(active_capacity, 11u) - 1u;
  const uint base = slot * uniforms.workspace_dimension;
  device float *workspace = reinterpret_cast<device float *>(
    hot_state + uniforms.workspace_offset
  );
  for (uint feature = 0u; feature < uniforms.workspace_dimension; ++feature) {
    float value = feature < min(request.parameter_count, 6u)
      ? request.parameters[feature] : 0.0f;
    if (feature == 6u) value = request.priority;
    if (feature == 7u) value = request.confidence;
    workspace[base + feature] = value;
  }
  device NBWorkspaceMetadataRecord *metadata =
    reinterpret_cast<device NBWorkspaceMetadataRecord *>(
      hot_state + uniforms.workspace_metadata_offset
    );
  const NBWorkspaceMetadataRecord prior = metadata[slot];
  const bool same_request = prior.identifier != 0ul
    && (prior.flags & NB_CONTROL_FLAG_VALID) != 0u
    && (prior.kind_and_source & 0xffffu) == 9u
    && (prior.kind_and_source >> 16u) == 25u
    && prior.entity_identifier == request.target_identifier;
  NBWorkspaceMetadataRecord token = same_request
    ? prior : NBWorkspaceMetadataRecord{};
  if (!same_request) {
    token.identifier = (uniforms.target_timestamp_microseconds << 8u)
      | ulong(slot + 1u);
    token.source_timestamp_microseconds = request.timestamp_microseconds;
  }
  token.last_refresh_timestamp_microseconds =
    uniforms.target_timestamp_microseconds;
  token.entity_identifier = request.target_identifier;
  token.goal_identifier = request.target_identifier;
  token.kind_and_source = 9u | (25u << 16u);
  token.confidence = clamp(request.confidence * request.priority, 0.0f, 1.0f);
  token.persistence_priority = clamp(request.priority, 0.0f, 1.0f);
  token.selection_score = token.confidence;
  token.provenance_kind = 0u;
  token.flags = 1u;
  token.provenance_source_generation = 0ul;
  token.last_score_update_timestamp_microseconds =
    uniforms.target_timestamp_microseconds;
  metadata[slot] = token;
}

kernel void propose_dynamic_options(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  device const float *value_parameters [[buffer(2)]],
  device const float *policy_parameters [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  const uint candidate_limit = nb_active_candidate_limit(uniforms, development);
  if (gid >= uniforms.candidate_capacity) return;
  device const float *recurrent = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  device const float *workspace = reinterpret_cast<device const float *>(
    hot_state + uniforms.workspace_offset
  );
  device const NBWorkspaceMetadataRecord *workspace_metadata =
    reinterpret_cast<device const NBWorkspaceMetadataRecord *>(
      hot_state + uniforms.workspace_metadata_offset
    );
  device const NBSpatialTransformRecord *spatial_transforms =
    reinterpret_cast<device const NBSpatialTransformRecord *>(
      hot_state + uniforms.spatial_transform_offset
    );
  device const NBObjectSlotRecord *object_slots =
    reinterpret_cast<device const NBObjectSlotRecord *>(
      hot_state + uniforms.object_slot_offset
    );
  device const NBDriveRecord *drives = reinterpret_cast<device const NBDriveRecord *>(
    hot_state + uniforms.drive_offset
  );
  device const NBNeuromodulatorRecord *neuromodulators =
    reinterpret_cast<device const NBNeuromodulatorRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  device const NBControlHeader *control = reinterpret_cast<device const NBControlHeader *>(
    hot_state + uniforms.control_header_offset
  );
  device NBOptionCandidateRecord *candidates =
    reinterpret_cast<device NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  if (gid >= candidate_limit) {
    NBOptionCandidateRecord inactive = {};
    candidates[gid] = inactive;
    return;
  }
  const uint procedural_base = candidate_limit > 4u
    ? max(10u, candidate_limit - 4u)
    : candidate_limit;
  if (gid >= procedural_base) {
    const uint workspace_slot = 3u + (gid - procedural_base);
    if (workspace_slot >= uniforms.workspace_capacity) {
      NBOptionCandidateRecord inactive = {};
      candidates[gid] = inactive;
      return;
    }
    const NBWorkspaceMetadataRecord memory_token =
      workspace_metadata[workspace_slot];
    const uint source_module = memory_token.kind_and_source >> 16;
    if (source_module != 60u || memory_token.entity_identifier == 0ul
        || memory_token.confidence <= 0.0f) {
      NBOptionCandidateRecord inactive = {};
      candidates[gid] = inactive;
      return;
    }
    NBOptionCandidateRecord learned;
    learned.option_identifier = memory_token.entity_identifier;
    learned.goal_identifier = control->active_goal_identifier != 0ul
      ? control->active_goal_identifier
      : memory_token.goal_identifier;
    const uint workspace_base = workspace_slot * uniforms.workspace_dimension;
    const bool structured_skill = uniforms.workspace_dimension >= 80u;
    float initiation_dot = 0.0f;
    float initiation_norm = 1.0e-6f;
    float recurrent_norm = 1.0e-6f;
    for (uint component = 0u; component < 16u; ++component) {
      const float initiation = structured_skill
        ? workspace[workspace_base + 16u + component] : 0.0f;
      const float state = recurrent[component % uniforms.recurrent_scalar_count];
      initiation_dot += initiation * state;
      initiation_norm += initiation * initiation;
      recurrent_norm += state * state;
    }
    const float initiation_match = structured_skill
      ? clamp(0.5f + 0.5f * initiation_dot
          * rsqrt(initiation_norm * recurrent_norm), 0.0f, 1.0f)
      : memory_token.confidence;
    float termination_logit = 0.0f;
    for (uint component = 0u; component < 8u; ++component) {
      termination_logit += (structured_skill
        ? workspace[workspace_base + 32u + component] : 0.0f)
        * recurrent[component % uniforms.recurrent_scalar_count];
    }
    const float termination_probability = structured_skill
      ? max(
          1.0f / (1.0f + exp(-termination_logit / 8.0f)),
          workspace[workspace_base + 78u]
        )
      : 0.0f;
    learned.task_value = structured_skill
      ? workspace[workspace_base + 59u] + workspace[workspace_base + 65u]
        - max(workspace[workspace_base + 62u], 0.0f)
      : workspace[workspace_base % max(uniforms.workspace_scalar_count, 1u)];
    learned.homeostatic_value = structured_skill
      ? workspace[workspace_base + 64u] : 0.0f;
    learned.social_value = structured_skill
      ? workspace[workspace_base + 66u] : 0.0f;
    learned.information_gain = structured_skill
      ? max(workspace[workspace_base + 67u], 0.0f)
      : 0.0f;
    learned.damage_cvar = structured_skill
      ? clamp(workspace[workspace_base + 57u], 0.0f, 1.0f)
      : clamp(1.0f - memory_token.confidence, 0.0f, 1.0f);
    learned.effort_cost = structured_skill
      ? max(workspace[workspace_base + 58u], 0.0f) : 0.02f;
    learned.switching_cost = 0.025f;
    learned.competence = clamp(
      memory_token.confidence
        * (structured_skill ? workspace[workspace_base + 56u] : 1.0f)
        * initiation_match,
      0.0f,
      1.0f
    );
    if (structured_skill
        && control->active_option_identifier == learned.option_identifier) {
      const float termination_confidence = clamp(
        workspace[workspace_base + 61u], 0.0f, 1.0f
      );
      learned.task_value -= termination_probability * termination_confidence;
      learned.competence *= 1.0f
        - 0.5f * termination_probability * termination_confidence;
    }
    learned.proposal_kind = 10u;
    const ulong phase_option_identifier = memory_token.bound_token_identifier;
    const ulong innate_phase_identifier = phase_option_identifier
      & ~NB_INNATE_OPTION_NAMESPACE;
    if ((phase_option_identifier & NB_INNATE_OPTION_NAMESPACE) != 0ul
        && innate_phase_identifier > 0ul) {
      learned.proposal_kind = uint((innate_phase_identifier - 1ul) % 10ul);
    }
    learned.source_module = 60u;
    learned.flags = NB_CONTROL_FLAG_VALID;
    learned.parameter_count = 16u;
    for (uint index = 0u; index < 16u; ++index) {
      learned.parameters[index] = workspace[
        workspace_base + index % max(uniforms.workspace_dimension, 1u)
      ];
    }
    candidates[gid] = learned;
    return;
  }
  if (gid >= 10u) {
    const uint object_index = gid - 10u;
    if (object_index >= uniforms.object_slot_count) {
      NBOptionCandidateRecord inactive = {};
      candidates[gid] = inactive;
      return;
    }
    const NBObjectSlotRecord object = object_slots[object_index];
    if (object.identifier == 0ul || (object.flags & NB_CONTROL_FLAG_VALID) == 0u
        || object.existence_probability <= 0.01f) {
      NBOptionCandidateRecord inactive = {};
      candidates[gid] = inactive;
      return;
    }
    uint strongest_affordance = 0u;
    float strongest_affordance_value = object.affordances[0];
    for (uint affordance = 1u; affordance < 8u; ++affordance) {
      if (object.affordances[affordance] > strongest_affordance_value) {
        strongest_affordance = affordance;
        strongest_affordance_value = object.affordances[affordance];
      }
    }
    const float safety = uniforms.drive_count > 11u
      ? clamp(drives[11].level, 0.0f, 1.0f) : 0.0f;
    const float physiological_need =
      (uniforms.drive_count > 0u ? drives[0].deficit : 0.0f)
      + (uniforms.drive_count > 1u ? drives[1].deficit : 0.0f);
    const float distance = length(float3(
      object.pose[0], object.pose[1], object.pose[2]
    ));
    const float3 target_direction = distance > 1.0e-4f
      ? float3(object.pose[0], object.pose[1], object.pose[2]) / distance
      : float3(0.0f);
    float tool_reach_extension = 0.0f;
    float tool_reach_confidence = 0.0f;
    for (uint tool_index = 0u;
        tool_index < uniforms.object_slot_count; ++tool_index) {
      if (tool_index == object_index) continue;
      const NBObjectSlotRecord tool = object_slots[tool_index];
      const float attachment = clamp(tool.latent[95], 0.0f, 1.0f);
      if (tool.identifier == 0ul || attachment <= 0.01f) continue;
      const float direction_alignment = clamp(dot(
        target_direction,
        float3(tool.latent[99], tool.latent[100], tool.latent[101])
      ), 0.0f, 1.0f);
      const float extension = max(tool.latent[98], 0.0f)
        * attachment * direction_alignment;
      if (extension > tool_reach_extension) {
        tool_reach_extension = extension;
        tool_reach_confidence = attachment
          * clamp(tool.latent[96], 0.0f, 1.0f);
      }
    }
    const float effective_distance = max(
      distance - tool_reach_extension, 0.0f
    );
    NBOptionCandidateRecord affordance_option = {};
    affordance_option.option_identifier = 0x4000000000000000ul
      | (object.identifier & 0x0fffffffffffff00ul)
      | ulong(strongest_affordance + 1u);
    affordance_option.goal_identifier = control->active_goal_identifier;
    affordance_option.task_value = max(strongest_affordance_value, 0.0f)
      * object.existence_probability * value_parameters[0];
    affordance_option.homeostatic_value = max(object.affordances[0], 0.0f)
      * physiological_need * value_parameters[1];
    affordance_option.social_value = 0.0f;
    affordance_option.information_gain = object.uncertainty
      * value_parameters[3];
    affordance_option.damage_cvar = clamp(
      safety + 0.25f * object.uncertainty
        + 0.25f * max(-strongest_affordance_value, 0.0f),
      0.0f,
      1.0f
    );
    affordance_option.effort_cost = clamp(
      0.02f * effective_distance, 0.0f, 1.0f
    );
    affordance_option.switching_cost = 0.025f;
    affordance_option.competence = clamp(
      object.existence_probability * object.identity_confidence
        * (1.0f - object.uncertainty)
        * (1.0f + 0.5f * tool_reach_confidence),
      0.0f,
      1.0f
    );
    affordance_option.proposal_kind = 20u + strongest_affordance;
    affordance_option.source_module = 71u;
    affordance_option.flags = NB_CONTROL_FLAG_VALID;
    if (tool_reach_extension > 0.01f) {
      affordance_option.flags |= 1u << 5u;
    }
    affordance_option.parameter_count = 16u;
    for (uint component = 0u; component < 4u; ++component) {
      affordance_option.parameters[component] = object.pose[component];
      affordance_option.parameters[4u + component] = object.velocity[component];
    }
    for (uint component = 0u; component < 8u; ++component) {
      affordance_option.parameters[8u + component] = object.affordances[component];
    }
    affordance_option.parameters[14] = tool_reach_extension;
    affordance_option.parameters[15] = tool_reach_confidence;
    candidates[gid] = affordance_option;
    return;
  }
  NBOptionCandidateRecord candidate;
  candidate.option_identifier = NB_INNATE_OPTION_NAMESPACE | ulong(gid + 1u);
  candidate.goal_identifier = control->active_goal_identifier;
  const float task_signal = workspace[gid % uniforms.workspace_scalar_count];
  const float homeostatic = drives[gid % uniforms.drive_count].deficit;
  const float safety = uniforms.drive_count > 11u ? drives[11].level : 0.0f;
  const float pain = uniforms.drive_count > 5u ? drives[5].level : 0.0f;
  const float epistemic = uniforms.neuromodulator_count > 3u
    ? neuromodulators[3].value
    : 0.0f;
  const float usable_information_opportunity = uniforms.drive_count > 8u
    ? clamp(drives[8].level, 0.0f, 1.0f) : 0.0f;
  const bool information_option = gid == NB_OPTION_PROPOSAL_ACTIVE_SENSING
    || gid == NB_OPTION_PROPOSAL_EXPLORATION;
  const bool curiosity_goal = (control->active_goal_identifier >> 56u) == 5ul;
  candidate.task_value = task_signal * value_parameters[0];
  const float fatigue_deficit = uniforms.drive_count > 4u ? drives[4].deficit : 0.0f;
  const float injury_deficit = uniforms.drive_count > 6u ? drives[6].deficit : 0.0f;
  const float sleep_deficit = uniforms.drive_count > 7u ? drives[7].deficit : 0.0f;
  candidate.homeostatic_value = gid == NB_OPTION_PROPOSAL_REST_RECOVERY
    ? (fatigue_deficit + injury_deficit + sleep_deficit) * value_parameters[1]
    : (information_option
      ? 0.0f
      : -policy_parameters[8] * homeostatic * value_parameters[1]);
  if (curiosity_goal && information_option && uniforms.drive_count > 8u) {
    candidate.homeostatic_value += drives[8].deficit * value_parameters[1];
  }
  float social_token_confidence = 0.0f;
  uint social_token_source = 0u;
  uint social_workspace_base = 0u;
  ulong social_bound_token_identifier = 0ul;
  if (uniforms.workspace_capacity > 11u) {
    const NBWorkspaceMetadataRecord social_token = workspace_metadata[11];
    social_token_source = social_token.kind_and_source >> 16;
    const uint social_token_kind = social_token.kind_and_source & 0xffffu;
    if ((social_token_source == 44u || social_token_source == 51u)
        && (social_token_kind == 4u || social_token_kind == 10u)
        && (social_token.flags & NB_CONTROL_FLAG_VALID) != 0u
        && social_token.entity_identifier != 0ul) {
      social_token_confidence = clamp(social_token.confidence, 0.0f, 1.0f);
      social_workspace_base = 11u * uniforms.workspace_dimension;
      social_bound_token_identifier = social_token.bound_token_identifier;
    }
  }
  candidate.social_value = gid == 8u && uniforms.drive_count > 9u
    ? (drives[9].deficit + social_token_confidence) * value_parameters[2]
    : 0.0f;
  if (gid == 8u && social_token_source == 51u) {
    candidate.task_value += social_token_confidence * value_parameters[0];
  }
  candidate.information_gain = information_option
    ? max(epistemic, usable_information_opportunity) * value_parameters[3]
    : 0.0f;
  if (gid == 8u && social_token_confidence > 0.0f
      && uniforms.workspace_dimension > 6u) {
    candidate.information_gain = max(
      candidate.information_gain,
      clamp(workspace[social_workspace_base + 6u], 0.0f, 1.0f)
        * value_parameters[3]
    );
  }
  candidate.damage_cvar = clamp(safety + pain * (gid > 4u ? 0.5f : 0.1f), 0.0f, 1.0f);
  candidate.effort_cost = gid == NB_OPTION_PROPOSAL_REST_RECOVERY
    ? 0.0f
    : 0.02f * float(gid % 8u);
  candidate.switching_cost = gid == 0u ? 0.0f : 0.025f;
  candidate.competence = clamp(
    0.5f + 0.5f * recurrent[gid % uniforms.recurrent_scalar_count],
    0.0f,
    1.0f
  );
  candidate.proposal_kind = gid % 10u;
  candidate.source_module = information_option ? 65u : 72u;
  candidate.flags = NB_CONTROL_FLAG_VALID;
  candidate.parameter_count = 16u;
  for (uint index = 0u; index < 16u; ++index) {
    candidate.parameters[index] = gid == 8u && social_token_confidence > 0.0f
      ? workspace[
          social_workspace_base + index % max(uniforms.workspace_dimension, 1u)
        ]
      : recurrent[(gid * 16u + index) % uniforms.recurrent_scalar_count];
  }
  if (gid == 8u && social_token_confidence > 0.0f) {
    candidate.source_module = social_token_source;
    candidate.competence = max(candidate.competence, social_token_confidence);
    if (social_token_source == 44u && uniforms.workspace_dimension > 116u) {
      const bool sensor_to_body_valid = uniforms.spatial_transform_count > 4u
        && (spatial_transforms[4].flags & NB_CONTROL_FLAG_VALID) != 0u;
      NBSpatialTransformRecord sensor_to_body = {};
      if (sensor_to_body_valid) {
        sensor_to_body = spatial_transforms[4];
      }
      float3 body_relative_velocity = float3(
        workspace[social_workspace_base + 114u],
        workspace[social_workspace_base + 115u],
        workspace[social_workspace_base + 116u]
      );
      if (sensor_to_body_valid) {
        body_relative_velocity = nb_rotate_vector(
          body_relative_velocity,
          float4(
            sensor_to_body.rotation[0], sensor_to_body.rotation[1],
            sensor_to_body.rotation[2], sensor_to_body.rotation[3]
          )
        );
        candidate.competence *= sensor_to_body.confidence;
      }
      const float movement_magnitude = clamp(
        length(body_relative_velocity), 0.0f, 1.0f
      );
      const float predicted_action = clamp(
        workspace[social_workspace_base + 5u], 0.0f, 1.0f
      );
      const float goal_confidence = clamp(
        workspace[social_workspace_base + 3u], 0.0f, 1.0f
      );
      const float observation_uncertainty = clamp(
        workspace[social_workspace_base + 6u], 0.0f, 1.0f
      );
      float3 inferred_goal_offset = body_relative_velocity
        * max(predicted_action, movement_magnitude);
      float referent_confidence = 0.0f;
      float referent_uncertainty = 1.0f;
      if (sensor_to_body_valid && social_bound_token_identifier != 0ul
          && uniforms.workspace_capacity > 12u
          && uniforms.workspace_dimension > 6u) {
        const NBWorkspaceMetadataRecord referent_token =
          workspace_metadata[12];
        const uint referent_kind = referent_token.kind_and_source & 0xffffu;
        const uint referent_source = referent_token.kind_and_source >> 16u;
        if ((referent_token.flags & NB_CONTROL_FLAG_VALID) != 0u
            && referent_token.identifier == social_bound_token_identifier
            && referent_kind == 3u && referent_source == 39u
            && referent_token.entity_identifier != 0ul) {
          const uint referent_base = 12u * uniforms.workspace_dimension;
          const float3 sensor_relative_goal = float3(
            workspace[referent_base + 4u] - sensor_to_body.translation[0],
            workspace[referent_base + 5u] - sensor_to_body.translation[1],
            workspace[referent_base + 6u] - sensor_to_body.translation[2]
          );
          const float3 body_relative_goal = nb_rotate_vector(
            sensor_relative_goal,
            float4(
              sensor_to_body.rotation[0], sensor_to_body.rotation[1],
              sensor_to_body.rotation[2], sensor_to_body.rotation[3]
            )
          );
          referent_uncertainty = clamp(
            workspace[referent_base + 3u], 0.0f, 1.0f
          );
          referent_confidence = clamp(
            referent_token.confidence * goal_confidence
              * sensor_to_body.confidence * (1.0f - referent_uncertainty),
            0.0f,
            1.0f
          );
          inferred_goal_offset = mix(
            inferred_goal_offset,
            body_relative_goal,
            referent_confidence
          );
        }
      }
      for (uint index = 0u; index < 16u; ++index) {
        candidate.parameters[index] = 0.0f;
      }
      for (uint axis = 0u; axis < 3u; ++axis) {
        const float movement = body_relative_velocity[axis]
          * max(predicted_action, movement_magnitude);
        candidate.parameters[axis] = inferred_goal_offset[axis];
        candidate.parameters[4u + axis] = body_relative_velocity[axis];
        candidate.parameters[8u + axis] = movement;
      }
      candidate.parameters[3] = max(goal_confidence, referent_confidence);
      candidate.parameters[7] = observation_uncertainty;
      candidate.parameters[11] = predicted_action;
      candidate.proposal_kind = NB_OPTION_PROPOSAL_IMITATION;
      candidate.task_value += movement_magnitude * goal_confidence
        * social_token_confidence * value_parameters[0];
      candidate.task_value += referent_confidence * value_parameters[0];
      candidate.social_value += movement_magnitude
        * social_token_confidence * value_parameters[2];
      candidate.damage_cvar = clamp(
        candidate.damage_cvar + 0.25f * max(
          observation_uncertainty,
          referent_confidence > 0.0f ? referent_uncertainty : 0.0f
        ),
        0.0f,
        1.0f
      );
      candidate.competence = clamp(
        candidate.competence * goal_confidence
          * (1.0f - observation_uncertainty)
          * (0.5f + 0.5f * referent_confidence),
        0.0f,
        1.0f
      );
      if (movement_magnitude > 0.01f) {
        uint movement_signature = 0u;
        movement_signature |= body_relative_velocity.x >= 0.0f ? 1u : 0u;
        movement_signature |= body_relative_velocity.y >= 0.0f ? 2u : 0u;
        movement_signature |= body_relative_velocity.z >= 0.0f ? 4u : 0u;
        const float3 absolute_velocity = abs(body_relative_velocity);
        uint dominant_axis = 0u;
        if (absolute_velocity.y > absolute_velocity.x) dominant_axis = 1u;
        if (absolute_velocity.z > absolute_velocity[dominant_axis]) {
          dominant_axis = 2u;
        }
        movement_signature |= dominant_axis << 4u;
        movement_signature |= uint(
          floor(3.0f * movement_magnitude + 0.5f)
        ) << 8u;
        candidate.option_identifier = 0x5000000000000000ul
          | (nb_semantic_hash(
              ulong(movement_signature) ^ 0x494d49544154494ful
            ) & 0x0ffffffffffffffful);
        candidate.flags |= 1u << 4u;
        if (referent_confidence > 0.01f) {
          candidate.flags |= 1u << 6u;
        }
      }
    } else if (uniforms.spatial_transform_count > 4u
        && (spatial_transforms[4].flags & NB_CONTROL_FLAG_VALID) != 0u) {
      const NBSpatialTransformRecord sensor_to_body = spatial_transforms[4];
      const float3 sensor_relative = float3(
        candidate.parameters[8] - sensor_to_body.translation[0],
        candidate.parameters[9] - sensor_to_body.translation[1],
        candidate.parameters[10] - sensor_to_body.translation[2]
      );
      const float3 body_relative = nb_rotate_vector(
        sensor_relative,
        float4(
          sensor_to_body.rotation[0], sensor_to_body.rotation[1],
          sensor_to_body.rotation[2], sensor_to_body.rotation[3]
        )
      );
      candidate.parameters[8] = body_relative.x;
      candidate.parameters[9] = body_relative.y;
      candidate.parameters[10] = body_relative.z;
      candidate.competence *= sensor_to_body.confidence;
    }
  }
  // An authenticated external goal must own a real candidate, not merely
  // reweight unrelated innate options. Slot zero is the bounded task-space
  // proposal: its sixteen target coordinates become the ordinary relative
  // position/velocity/force/stiffness/synergy parameters consumed by the
  // existing motor-goal, risk, anatomy, and spinal pipeline. Module 73 is
  // deliberately distinct from module 72's locomotor/CPG policy.
  const NBExternalGoalContext external_task = nb_external_goal_context(
    workspace, workspace_metadata, uniforms, control->active_goal_identifier
  );
  if (gid == 0u && external_task.valid > 0.0f) {
    candidate.option_identifier = 0x6000000000000000ul
      | (control->active_goal_identifier & 0x0ffffffffffffffful);
    candidate.goal_identifier = control->active_goal_identifier;
    // Goal arbitration already authenticated and ranked this directive. Keep
    // that priority causally present in option valuation instead of silently
    // dropping it and allowing unrelated innate options to win by default.
    candidate.task_value = external_task.priority
      + external_task.persistence;
    candidate.homeostatic_value = 0.0f;
    candidate.social_value = 0.0f;
    candidate.information_gain = 0.0f;
    candidate.damage_cvar = clamp(safety + pain, 0.0f, 1.0f);
    candidate.effort_cost = 0.01f;
    candidate.switching_cost = 0.0f;
    candidate.competence = 1.0f;
    candidate.proposal_kind = 0u;
    candidate.source_module = 73u;
    candidate.flags = NB_CONTROL_FLAG_VALID | (1u << 7u);
    candidate.parameter_count = 16u;
    for (uint index = 0u; index < 16u; ++index) {
      candidate.parameters[index] = external_task.target[index];
    }
  }
  candidates[gid] = candidate;
}

kernel void simulate_candidate_option_outcomes(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  device const float *value_parameters [[buffer(2)]],
  device const float *policy_parameters [[buffer(3)]],
  device const float *world_parameters [[buffer(11)]],
  uint gid [[thread_position_in_grid]])
{
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  const uint candidate_limit = nb_active_candidate_limit(uniforms, development);
  if (gid >= uniforms.candidate_capacity
      || uniforms.maximum_planning_horizon == 0u) return;
  device const NBOptionCandidateRecord *candidates =
    reinterpret_cast<device const NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  device const float *world = reinterpret_cast<device const float *>(
    hot_state + uniforms.world_model_offset
  );
  device const float *workspace = reinterpret_cast<device const float *>(
    hot_state + uniforms.workspace_offset
  );
  device const NBWorkspaceMetadataRecord *workspace_metadata =
    reinterpret_cast<device const NBWorkspaceMetadataRecord *>(
      hot_state + uniforms.workspace_metadata_offset
    );
  device NBPlanStepRecord *plans = reinterpret_cast<device NBPlanStepRecord *>(
    hot_state + uniforms.plan_offset
  );
  const uint active_horizon = min(
    max(development->planning_horizon_steps, 1u),
    uniforms.maximum_planning_horizon
  );
  const uint plan_base = gid * uniforms.maximum_planning_horizon;
  if (plan_base + uniforms.maximum_planning_horizon > uniforms.plan_capacity) return;
  if (gid >= candidate_limit
      || (candidates[gid].flags & NB_CONTROL_FLAG_VALID) == 0u) {
    for (uint step = 0u; step < uniforms.maximum_planning_horizon; ++step) {
      NBPlanStepRecord inactive = {};
      plans[plan_base + step] = inactive;
    }
    return;
  }
  const bool structured_world_available = uniforms.world_model_scalar_count
    >= NB_WORLD_EVENT_OPTION_BASE + 9u * NB_WORLD_EVENT_OPTION_DIMENSION;
  const float embodied_self_risk = nb_embodied_self_risk(hot_state, uniforms);
  float rollout_state[16];
  for (uint component = 0u; component < 16u; ++component) {
    rollout_state[component] = candidates[gid].parameters[component];
  }
  float accumulated_objective = 0.0f;
  float accumulated_damage = 0.0f;
  float accumulated_effort = 0.0f;
  float accumulated_information = 0.0f;
  float accumulated_drive_change = 0.0f;
  uint selected_option = gid;
  for (uint step = 0u; step < uniforms.maximum_planning_horizon; ++step) {
    if (step >= active_horizon) {
      NBPlanStepRecord inactive = {};
      plans[plan_base + step] = inactive;
      continue;
    }
    if (step > 0u) {
      float best_followup_score = -INFINITY;
      uint best_followup = selected_option;
      for (uint candidate_index = 0u; candidate_index < candidate_limit;
          ++candidate_index) {
        const NBOptionCandidateRecord followup = candidates[candidate_index];
        if ((followup.flags & NB_CONTROL_FLAG_VALID) == 0u) continue;
        float compatibility = 0.0f;
        for (uint component = 0u; component < 4u; ++component) {
          compatibility += rollout_state[component]
            * followup.parameters[component] * 0.05f;
        }
        const NBCounterfactualWorldOutcome followup_world =
          nb_counterfactual_world_outcome(
            world, world_parameters, uniforms, followup, rollout_state,
            step, structured_world_available
          );
        const NBRetrievedOptionOutcome followup_memory =
          nb_retrieved_option_outcome(
            workspace, workspace_metadata, uniforms,
            followup.option_identifier
          );
        const NBSemanticGoalOutcome followup_semantic =
          nb_retrieved_semantic_goal_outcome(
            workspace, workspace_metadata, uniforms,
            followup.goal_identifier
          );
        const NBExternalGoalContext followup_external =
          nb_external_goal_context(
            workspace, workspace_metadata, uniforms,
            followup.goal_identifier
          );
        float predicted_followup_state[16];
        for (uint component = 0u; component < 16u; ++component) {
          predicted_followup_state[component] = tanh(
            policy_parameters[11] * rollout_state[component]
              + policy_parameters[12] * followup_world.mean_prediction
              + policy_parameters[13] * followup.parameters[component]
          );
        }
        const float followup_goal_alignment =
          nb_external_goal_state_alignment(
            followup_external, predicted_followup_state
          );
        const float followup_risk = clamp(
          max(
            max(
              max(followup.damage_cvar, followup_world.damage_cvar),
              followup_memory.support * followup_memory.damage
            ),
            followup_semantic.support * followup_semantic.damage
          )
            + 0.05f * sqrt(followup_world.aleatoric_variance)
            + embodied_self_risk * (0.25f + 0.75f * followup.effort_cost),
          0.0f, 1.0f
        );
        const float followup_score = value_parameters[0] * followup.task_value
          + value_parameters[1] * followup.homeostatic_value
          + value_parameters[2] * followup.social_value
          + value_parameters[3] * uniforms.curiosity_weight
            * followup.information_gain
          + value_parameters[0] * followup_memory.support
            * followup_memory.reinforcement
          + value_parameters[0] * followup_semantic.support
            * followup_semantic.reinforcement
          + value_parameters[0] * followup_goal_alignment
          + compatibility - value_parameters[4] * uniforms.risk_weight
            * followup_risk
          - value_parameters[5] * followup.effort_cost
          - value_parameters[6] * followup.switching_cost;
        if (followup_risk <= followup_external.damage_risk_budget
            && (followup_score > best_followup_score
              || (followup_score == best_followup_score
                && candidate_index < best_followup))) {
          best_followup_score = followup_score;
          best_followup = candidate_index;
        }
      }
      selected_option = best_followup;
    }
    const NBOptionCandidateRecord candidate = candidates[selected_option];
    const NBRetrievedOptionOutcome episodic = nb_retrieved_option_outcome(
      workspace, workspace_metadata, uniforms, candidate.option_identifier
    );
    const NBSemanticGoalOutcome semantic =
      nb_retrieved_semantic_goal_outcome(
        workspace, workspace_metadata, uniforms, candidate.goal_identifier
      );
    const NBExternalGoalContext external = nb_external_goal_context(
      workspace, workspace_metadata, uniforms, candidate.goal_identifier
    );
    const NBCounterfactualWorldOutcome world_outcome =
      nb_counterfactual_world_outcome(
        world, world_parameters, uniforms, candidate, rollout_state,
        step, structured_world_available
      );
    const float ensemble_mean = world_outcome.mean_prediction;
    float predicted_state[16];
    for (uint component = 0u; component < 16u; ++component) {
      predicted_state[component] = tanh(
        policy_parameters[11] * rollout_state[component]
          + policy_parameters[12] * ensemble_mean
          + policy_parameters[13] * candidate.parameters[component]
      );
    }
    const float external_goal_alignment =
      nb_external_goal_state_alignment(external, predicted_state);
    const float epistemic = max(
      world_outcome.epistemic_uncertainty,
      episodic.support * episodic.uncertainty
    );
    const float step_damage = clamp(
      max(
        max(
          max(candidate.damage_cvar, world_outcome.damage_cvar),
          episodic.support * episodic.damage
        ),
        semantic.support * semantic.damage
      )
        + 0.05f * sqrt(world_outcome.aleatoric_variance)
        + embodied_self_risk * (0.25f + 0.75f * candidate.effort_cost),
      0.0f, 1.0f
    );
    accumulated_damage = 1.0f
      - (1.0f - accumulated_damage) * (1.0f - step_damage);
    const float step_effort = candidate.effort_cost * (1.0f + epistemic);
    const float step_information = max(candidate.information_gain, epistemic);
    const float discount = pow(0.97f, float(step));
    accumulated_effort += discount * step_effort;
    accumulated_information += discount * step_information;
    accumulated_drive_change += discount * candidate.homeostatic_value;
    accumulated_objective += discount * (
      value_parameters[0] * candidate.task_value
        + value_parameters[1] * candidate.homeostatic_value
        + value_parameters[2] * candidate.social_value
        + value_parameters[3] * uniforms.curiosity_weight * step_information
        + value_parameters[0] * episodic.support * episodic.reinforcement
        + value_parameters[0] * semantic.support * semantic.reinforcement
        + value_parameters[0] * external_goal_alignment
        - value_parameters[4] * uniforms.risk_weight * step_damage
        - value_parameters[5] * step_effort
        - value_parameters[6]
          * (step == 0u ? candidate.switching_cost : 0.0f)
    );
    NBPlanStepRecord plan = {};
    plan.option_identifier = candidate.option_identifier;
    plan.goal_identifier = candidate.goal_identifier;
    plan.objective_value = accumulated_objective;
    plan.damage_cvar = accumulated_damage;
    plan.epistemic_uncertainty = epistemic;
    plan.predicted_effort = accumulated_effort;
    plan.predicted_information_gain = accumulated_information;
    plan.duration_seconds = 0.1f + 0.05f * float(selected_option % 8u);
    plan.predicted_drive_change = accumulated_drive_change;
    plan.admissibility = accumulated_damage <= external.damage_risk_budget
      ? 1.0f : 0.0f;
    plan.sequence = step;
    plan.flags = NB_CONTROL_FLAG_VALID;
    plan.parameter_count = 16u;
    for (uint component = 0u; component < 16u; ++component) {
      rollout_state[component] = predicted_state[component];
      plan.predicted_state[component] = rollout_state[component];
    }
    plans[plan_base + step] = plan;
  }
}

kernel void select_option_and_control_mode(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u) return;
  device NBControlHeader *header = reinterpret_cast<device NBControlHeader *>(
    hot_state + uniforms.control_header_offset
  );
  device const NBOptionCandidateRecord *candidates =
    reinterpret_cast<device const NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  device const NBPlanStepRecord *plans = reinterpret_cast<device const NBPlanStepRecord *>(
    hot_state + uniforms.plan_offset
  );
  device const NBDriveRecord *drives = reinterpret_cast<device const NBDriveRecord *>(
    hot_state + uniforms.drive_offset
  );
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
  );
  const uint candidate_limit = nb_active_candidate_limit(uniforms, development);
  const uint active_horizon = min(
    max(development->planning_horizon_steps, 1u),
    uniforms.maximum_planning_horizon
  );
  const float embodied_self_risk = nb_embodied_self_risk(hot_state, uniforms);
  const float safety = max(
    uniforms.drive_count > 11u ? drives[11].level : 0.0f,
    embodied_self_risk
  );
  device const NBInternalActionRecord *internal_actions =
    reinterpret_cast<device const NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  const NBInternalActionRecord planning_request = internal_actions[4];
  const NBInternalActionRecord planning_end_request = internal_actions[5];
  const bool continue_planning = planning_request.kind == 5u
    && (planning_request.flags & NB_CONTROL_FLAG_VALID) != 0u;
  const bool end_planning = planning_end_request.kind == 6u
    && (planning_end_request.flags & NB_CONTROL_FLAG_VALID) != 0u;
  const uint previous_mode = header->mode;
  const ulong previous_option_identifier = header->active_option_identifier;
  const ulong previous_selected_timestamp = header->selected_timestamp_microseconds;
  const float previous_controller_phase = header->controller_phase;
  const float2 regional_modulation = nb_decision_regional_modulation(
    hot_state,
    uniforms
  );
  uint selected = 0u;
  float selected_score = -INFINITY;
  for (uint index = 0u; index < candidate_limit; ++index) {
    const uint terminal_index = index * uniforms.maximum_planning_horizon
      + active_horizon - 1u;
    const NBPlanStepRecord plan = plans[terminal_index];
    const float exploration_adjustment = 0.25f
      * (regional_modulation.y - 1.0f)
      * plan.predicted_information_gain;
    const float modulated_score = plan.objective_value + exploration_adjustment;
    if (plan.admissibility > 0.5f && modulated_score > selected_score) {
      selected = index;
      selected_score = modulated_score;
    }
  }
  uint previous_candidate = uniforms.candidate_capacity;
  float previous_score = -INFINITY;
  for (uint index = 0u; index < candidate_limit; ++index) {
    if (candidates[index].option_identifier != previous_option_identifier) continue;
    const NBPlanStepRecord previous_plan = plans[
      index * uniforms.maximum_planning_horizon + active_horizon - 1u
    ];
    if (previous_plan.admissibility > 0.5f) {
      previous_candidate = index;
      previous_score = previous_plan.objective_value
        + 0.25f * (regional_modulation.y - 1.0f)
          * previous_plan.predicted_information_gain;
    }
    break;
  }
  if (previous_candidate < candidate_limit && selected != previous_candidate
      && isfinite(previous_score)
      && selected_score < previous_score + uniforms.switching_margin) {
    selected = previous_candidate;
    selected_score = previous_score;
  }
  uint flags = NB_CONTROL_FLAG_VALID;
  uint mode = NB_CONTROL_MODE_PROCEDURAL;
  if (safety > 0.8f || !isfinite(selected_score)) {
    selected = 0u;
    selected_score = 0.0f;
    flags |= NB_CONTROL_FLAG_HYPERDIRECT_STOP;
    mode = NB_CONTROL_MODE_REFLEX;
  } else if (development->stage >= 8u
      && (continue_planning || (!end_planning
        && (plans[selected * uniforms.maximum_planning_horizon
          + active_horizon - 1u].epistemic_uncertainty > 0.25f
      || plans[selected * uniforms.maximum_planning_horizon
          + active_horizon - 1u].damage_cvar > 0.25f)))) {
    mode = NB_CONTROL_MODE_PLANNING;
  }
  const NBOptionCandidateRecord candidate = candidates[selected];
  const NBPlanStepRecord plan = plans[
    selected * uniforms.maximum_planning_horizon + active_horizon - 1u
  ];
  header->active_goal_identifier = candidate.goal_identifier;
  header->active_option_identifier = candidate.option_identifier;
  header->active_plan_identifier = mode == NB_CONTROL_MODE_PLANNING
    ? (candidate.option_identifier ^ uniforms.parameter_version_fingerprint)
    : 0ul;
  const bool option_changed = candidate.option_identifier
    != previous_option_identifier;
  header->selected_timestamp_microseconds = option_changed
    ? uniforms.target_timestamp_microseconds
    : previous_selected_timestamp;
  header->mode = mode;
  header->candidate_count = candidate_limit;
  header->plan_step_count = mode == NB_CONTROL_MODE_PLANNING ? active_horizon : 0u;
  header->flags = flags;
  header->selected_score = selected_score;
  header->selected_damage_cvar = plan.damage_cvar;
  header->confidence = clamp(candidate.competence * (1.0f - plan.epistemic_uncertainty), 0.0f, 1.0f);
  header->vigor = clamp(
    (1.0f - candidate.effort_cost - safety) * regional_modulation.x,
    0.0f,
    1.0f
  );
  header->exploration_temperature = clamp(
    plan.epistemic_uncertainty * regional_modulation.y,
    0.0f,
    1.0f
  );
  header->controller_phase = option_changed
    ? 0.0f
    : previous_controller_phase + 1.0f;
  header->interruption_cost = option_changed
    ? clamp(previous_score - selected_score, 0.0f, 1.0f)
    : 0.0f;
  header->predicted_effort = plan.predicted_effort;
  header->predicted_information_gain = plan.predicted_information_gain;
  header->unsupported_uncertainty = plan.epistemic_uncertainty;
  header->reserved0 = ulong(selected);
  header->reserved1 = ulong(previous_mode);
}

/// Emits compact transactional internal actions. These records describe
/// deliberate memory, workspace, routing, planning, inhibition, and replay
/// requests; they never advance time or mutate persistent memory directly.
kernel void generate_internal_action_state(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.internal_action_capacity || gid >= 8u) return;
  device const NBControlHeader *header =
    reinterpret_cast<device const NBControlHeader *>(
      hot_state + uniforms.control_header_offset
    );
  device const NBOptionCandidateRecord *candidates =
    reinterpret_cast<device const NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  device const NBDriveRecord *drives =
    reinterpret_cast<device const NBDriveRecord *>(
      hot_state + uniforms.drive_offset
    );
  device const NBNeuromodulatorRecord *neuromodulators =
    reinterpret_cast<device const NBNeuromodulatorRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  device const NBWorkspaceMetadataRecord *workspace_metadata =
    reinterpret_cast<device const NBWorkspaceMetadataRecord *>(
      hot_state + uniforms.workspace_metadata_offset
    );
  device NBInternalActionRecord *actions =
    reinterpret_cast<device NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  const uint selected = min(
    uint(header->reserved0), max(uniforms.candidate_capacity, 1u) - 1u
  );
  const NBOptionCandidateRecord candidate = candidates[selected];
  const float model_error = uniforms.neuromodulator_count > 1u
    ? clamp(neuromodulators[1].value, 0.0f, 1.0f) : 0.0f;
  const float epistemic = uniforms.neuromodulator_count > 3u
    ? clamp(neuromodulators[3].value, 0.0f, 1.0f) : 0.0f;
  const float safety = uniforms.drive_count > 11u
    ? clamp(drives[11].level, 0.0f, 1.0f) : 0.0f;
  const float sleep_pressure = uniforms.drive_count > 7u
    ? clamp(max(drives[7].level, drives[7].deficit), 0.0f, 1.0f) : 0.0f;
  float maximum_token_age = 0.0f;
  ulong stalest_token_identifier = 0ul;
  ulong focused_entity_identifier = 0ul;
  float focused_entity_confidence = 0.0f;
  for (uint slot = 2u; slot < uniforms.workspace_capacity; ++slot) {
    const NBWorkspaceMetadataRecord token = workspace_metadata[slot];
    if (token.identifier == 0ul) continue;
    const uint token_kind = token.kind_and_source & 0xffffu;
    if (token_kind == 3u && token.entity_identifier != 0ul
        && token.confidence > focused_entity_confidence) {
      focused_entity_identifier = token.entity_identifier;
      focused_entity_confidence = token.confidence;
    }
    const ulong age_microseconds = uniforms.target_timestamp_microseconds
      >= token.last_refresh_timestamp_microseconds
      ? uniforms.target_timestamp_microseconds
        - token.last_refresh_timestamp_microseconds
      : 0ul;
    const float age = clamp(float(age_microseconds) * 1.0e-6f, 0.0f, 1.0f);
    if (age > maximum_token_age) {
      maximum_token_age = age;
      stalest_token_identifier = token.identifier;
    }
  }

  NBInternalActionRecord action = {};
  action.timestamp_microseconds = uniforms.target_timestamp_microseconds;
  action.kind = gid + 1u;
  action.parameter_count = 6u;
  action.confidence = header->confidence;
  if (gid == 0u) {
    action.priority = max(
      header->unsupported_uncertainty,
      max(epistemic, header->predicted_information_gain)
    );
    action.target_identifier = focused_entity_identifier != 0ul
      ? focused_entity_identifier : header->active_goal_identifier;
  } else if (gid == 1u) {
    action.priority = max(model_error, 1.0f - header->progress) * header->confidence;
    action.target_identifier = header->active_goal_identifier;
  } else if (gid == 2u) {
    action.priority = maximum_token_age;
    action.target_identifier = stalest_token_identifier;
  } else if (gid == 3u) {
    action.priority = max(epistemic, candidate.information_gain);
    action.target_identifier = ulong(candidate.source_module);
  } else if (gid == 4u) {
    action.priority = header->mode == NB_CONTROL_MODE_PLANNING
      && uint(header->reserved1) != NB_CONTROL_MODE_PLANNING ? 1.0f : 0.0f;
    action.target_identifier = header->active_option_identifier;
  } else if (gid == 5u) {
    action.priority = header->mode != NB_CONTROL_MODE_PLANNING
      && uint(header->reserved1) == NB_CONTROL_MODE_PLANNING
      && header->confidence > 0.75f ? header->confidence : 0.0f;
    action.target_identifier = header->active_option_identifier;
  } else if (gid == 6u) {
    action.priority = max(
      safety,
      (header->flags & NB_CONTROL_FLAG_HYPERDIRECT_STOP) != 0u ? 1.0f : 0.0f
    );
    action.target_identifier = header->active_option_identifier;
  } else {
    const bool rest_selected = header->active_option_identifier
      == NB_REST_OPTION_IDENTIFIER;
    action.priority = max(sleep_pressure, rest_selected ? 1.0f : 0.0f);
    action.target_identifier = header->active_goal_identifier;
  }
  action.priority = clamp(action.priority, 0.0f, 1.0f);
  action.flags = action.priority > 0.05f ? NB_CONTROL_FLAG_VALID : 0u;
  action.parameters[0] = header->confidence;
  action.parameters[1] = header->unsupported_uncertainty;
  action.parameters[2] = header->selected_damage_cvar;
  action.parameters[3] = header->predicted_information_gain;
  action.parameters[4] = header->progress;
  action.parameters[5] = header->vigor;
  actions[gid] = action;
}

/// Materializes the selected option into one structured task-space motor goal.
/// The record is shadow-generation state: physical rejection cannot publish a
/// target, duration, impedance request, or synergy basis that was not lived.
kernel void generate_structured_motor_goal_state(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  device const float *policy_parameters [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u) return;
  device NBMotorGoalRecord *goal =
    reinterpret_cast<device NBMotorGoalRecord *>(
      hot_state + uniforms.motor_goal_offset
    );
  NBMotorGoalRecord next = {};
  device const NBControlHeader *header =
    reinterpret_cast<device const NBControlHeader *>(
      hot_state + uniforms.control_header_offset
    );
  if (uniforms.candidate_capacity == 0u || uniforms.body_belief_count == 0u) {
    *goal = next;
    return;
  }
  const uint selected = min(
    uint(header->reserved0), uniforms.candidate_capacity - 1u
  );
  device const NBOptionCandidateRecord *candidates =
    reinterpret_cast<device const NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  const NBOptionCandidateRecord candidate = candidates[selected];
  if ((candidate.flags & NB_CONTROL_FLAG_VALID) == 0u) {
    *goal = next;
    return;
  }
  device const NBPlanStepRecord *plans =
    reinterpret_cast<device const NBPlanStepRecord *>(
      hot_state + uniforms.plan_offset
    );
  const uint plan_index = selected * uniforms.maximum_planning_horizon;
  const bool plan_valid = plan_index < uniforms.plan_capacity
    && (plans[plan_index].flags & NB_CONTROL_FLAG_VALID) != 0u;
  const float duration_seconds = plan_valid
    ? max(plans[plan_index].duration_seconds, 1.0e-3f) : 0.1f;

  device const uchar *body_belief = hot_state + uniforms.body_belief_offset;
  uint selected_body_index = 0u;
  float selected_body_score = -INFINITY;
  bool body_found = false;
  float selected_body_uncertainty = 1.0f;
  for (uint body_index = 0u; body_index < uniforms.body_belief_count;
      ++body_index) {
    device const float *body = reinterpret_cast<device const float *>(
      body_belief + ulong(body_index) * 256ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      body + NB_BODY_IDENTITY_FLOAT_OFFSET
    );
    if ((identity[3] & NB_CONTROL_FLAG_VALID) == 0ul) continue;
    float variance = max(body[NB_BODY_LOAD_VARIANCE], 0.0f);
    for (uint axis = 0u; axis < 3u; ++axis) {
      variance += max(body[NB_BODY_POSITION_VARIANCE + axis], 0.0f);
      variance += max(body[NB_BODY_ORIENTATION_VARIANCE + axis], 0.0f);
    }
    const float uncertainty = sqrt(variance / 7.0f);
    const float normalized_uncertainty = uncertainty / (1.0f + uncertainty);
    const float risk = max(
      clamp(body[NB_BODY_PAIN], 0.0f, 1.0f),
      max(
        clamp(body[NB_BODY_VULNERABILITY], 0.0f, 1.0f),
        clamp(body[NB_BODY_DAMAGE_RISK], 0.0f, 1.0f)
      )
    );
    const float score = clamp(body[NB_BODY_REACHABILITY], 0.0f, 1.0f)
      * clamp(body[NB_BODY_OWNERSHIP], 0.0f, 1.0f)
      * (1.0f - risk)
      + 0.1f * clamp(body[NB_BODY_SUPPORT], 0.0f, 1.0f)
      - 0.1f * normalized_uncertainty;
    if (!body_found || score > selected_body_score) {
      body_found = true;
      selected_body_index = body_index;
      selected_body_score = score;
      selected_body_uncertainty = normalized_uncertainty;
    }
  }
  if (!body_found) {
    *goal = next;
    return;
  }
  device const float *body = reinterpret_cast<device const float *>(
    body_belief + ulong(selected_body_index) * 256ul
  );
  device const ulong *body_identity = reinterpret_cast<device const ulong *>(
    body + NB_BODY_IDENTITY_FLOAT_OFFSET
  );
  const bool absolute_task_target = candidate.source_module == 71u
    || candidate.source_module == 60u || candidate.source_module == 51u;
  float joint_uncertainty = 0.0f;
  const float joint_limit_risk = nb_articulated_joint_risk(
    hot_state, uniforms, joint_uncertainty
  );
  const uint parameter_count = min(max(candidate.parameter_count, 1u), 16u);
  for (uint axis = 0u; axis < 3u; ++axis) {
    const float parameter = candidate.parameters[axis % parameter_count];
    next.task_space_target[axis] = absolute_task_target
      ? parameter
      : body[NB_BODY_POSITION + axis] + 0.25f * tanh(parameter);
    next.velocity_target[axis] = tanh(
      candidate.parameters[(4u + axis) % parameter_count]
    );
    next.force_target[axis] = tanh(
      candidate.parameters[(8u + axis) % parameter_count]
    );
    next.stiffness_target[axis] = clamp(
      max(
        max(header->selected_damage_cvar, joint_limit_risk),
        1.0f - body[NB_BODY_SUPPORT]
      )
        + 0.25f * abs(candidate.parameters[(12u + axis) % parameter_count]),
      0.0f,
      1.0f
    );
    next.damping_target[axis] = clamp(
      0.5f * next.stiffness_target[axis]
        + 0.5f * selected_body_uncertainty,
      0.0f,
      1.0f
    );
  }
  next.task_space_target[3] = candidate.parameters[3u % parameter_count];
  next.velocity_target[3] = duration_seconds;
  next.force_target[3] = length(float3(
    next.force_target[0], next.force_target[1], next.force_target[2]
  ));
  next.stiffness_target[3] = max(
    next.stiffness_target[0],
    max(next.stiffness_target[1], next.stiffness_target[2])
  );
  next.damping_target[3] = max(
    next.damping_target[0],
    max(next.damping_target[1], next.damping_target[2])
  );
  float4 orientation = float4(
    body[NB_BODY_ORIENTATION], body[NB_BODY_ORIENTATION + 1u],
    body[NB_BODY_ORIENTATION + 2u], body[NB_BODY_ORIENTATION + 3u]
  );
  if (candidate.source_module == 60u) {
    const float4 requested = float4(
      candidate.parameters[12u % parameter_count],
      candidate.parameters[13u % parameter_count],
      candidate.parameters[14u % parameter_count],
      candidate.parameters[15u % parameter_count]
    );
    if (length_squared(requested) > 1.0e-8f) orientation = requested;
  }
  orientation = length_squared(orientation) > 1.0e-8f
    ? normalize(orientation) : float4(0.0f, 0.0f, 0.0f, 1.0f);
  for (uint component = 0u; component < 4u; ++component) {
    next.orientation_target[component] = orientation[component];
  }
  next.option_identifier = candidate.option_identifier;
  next.goal_identifier = candidate.goal_identifier;
  next.timestamp_microseconds = uniforms.target_timestamp_microseconds;
  next.movement_duration_microseconds = ulong(
    max(duration_seconds * 1.0e6f, 1.0f)
  );
  next.confidence = clamp(
    header->confidence * (1.0f - selected_body_uncertainty), 0.0f, 1.0f
  );
  next.risk = clamp(
    max(header->selected_damage_cvar, joint_limit_risk), 0.0f, 1.0f
  );
  next.support = clamp(body[NB_BODY_SUPPORT], 0.0f, 1.0f);
  next.uncertainty = max(
    selected_body_uncertainty,
    max(
      clamp(header->unsupported_uncertainty, 0.0f, 1.0f),
      joint_uncertainty
    )
  );
  next.target_body_identifier = uint(body_identity[0]);
  next.flags = NB_CONTROL_FLAG_VALID
    | (absolute_task_target ? (1u << 1u) : 0u)
    | (candidate.source_module == 60u ? (1u << 2u) : 0u);
  next.synergy_count = min(uniforms.synergy_count, 16u);
  next.parameter_count = candidate.parameter_count;
  const bool rest_selected = candidate.option_identifier
    == NB_REST_OPTION_IDENTIFIER;
  for (uint index = 0u; index < 16u; ++index) {
    next.synergy_coefficients[index] = rest_selected ? 0.0f
      : tanh(candidate.parameters[index % parameter_count])
        * policy_parameters[7];
  }
  *goal = next;
}

inline float nb_cerebellar_embodied_context(
  device const uchar *hot_state,
  constant NBDecisionUniforms &uniforms,
  uint target_body_identifier)
{
  float body_total = 0.0f;
  uint body_count = 0u;
  for (uint body_index = 0u; body_index < uniforms.body_belief_count;
      ++body_index) {
    device const float *body = reinterpret_cast<device const float *>(
      hot_state + uniforms.body_belief_offset + ulong(body_index) * 256ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      body + NB_BODY_IDENTITY_FLOAT_OFFSET
    );
    if ((identity[3] & NB_CONTROL_FLAG_VALID) == 0ul
        || uint(identity[0]) != target_body_identifier) continue;
    const uint features[9] = {
      NB_BODY_POSITION, NB_BODY_POSITION + 1u, NB_BODY_POSITION + 2u,
      NB_BODY_LINEAR_VELOCITY, NB_BODY_LINEAR_VELOCITY + 1u,
      NB_BODY_LINEAR_VELOCITY + 2u, NB_BODY_SUPPORT,
      NB_BODY_DAMAGE_RISK, NB_BODY_LOAD_VARIANCE,
    };
    for (uint index = 0u; index < 9u; ++index) {
      body_total += nb_normalized_body_feature_value(
        body[features[index]], features[index]
      );
      body_count += 1u;
    }
    break;
  }
  float joint_total = 0.0f;
  uint joint_count = 0u;
  for (uint joint_index = 0u;
      joint_index < uniforms.joint_belief_count; ++joint_index) {
    device const float *joint = reinterpret_cast<device const float *>(
      hot_state + uniforms.joint_belief_offset + ulong(joint_index) * 256ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      joint + NB_JOINT_IDENTITY_FLOAT_OFFSET
    );
    if ((identity[7] & 1ul) == 0ul
        || (uint(identity[1]) != target_body_identifier
          && uint(identity[2]) != target_body_identifier)) continue;
    const uint coordinate_count = min(uint(identity[3]), 6u);
    for (uint coordinate = 0u; coordinate < coordinate_count; ++coordinate) {
      const uint position_feature = coordinate;
      const uint velocity_feature = 6u + coordinate;
      const uint limit_feature = NB_JOINT_LIMIT_ACTIVATION + coordinate;
      joint_total += nb_normalized_joint_feature_value(
        joint[position_feature], position_feature
      );
      joint_total += nb_normalized_joint_feature_value(
        joint[velocity_feature], velocity_feature
      );
      joint_total += nb_normalized_joint_feature_value(
        joint[limit_feature], limit_feature
      );
      joint_count += 3u;
    }
    joint_total += nb_normalized_joint_feature_value(
      joint[NB_JOINT_PREDICTION_ERROR], NB_JOINT_PREDICTION_ERROR
    );
    joint_count += 1u;
  }
  float muscle_total = 0.0f;
  uint muscle_count = 0u;
  for (uint muscle_index = 0u;
      muscle_index < uniforms.somatic_effector_belief_count; ++muscle_index) {
    device const float *muscle = reinterpret_cast<device const float *>(
      hot_state + uniforms.somatic_effector_belief_offset
        + ulong(muscle_index) * 192ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      muscle + NB_MUSCLE_IDENTITY_FLOAT_OFFSET
    );
    const uint first_body_identifier = uint(identity[7]);
    const uint terminal_body_identifier = uint(identity[7] >> 32u);
    if ((identity[3] & 1ul) == 0ul
        || (identity[2] != 0ul
          && first_body_identifier != target_body_identifier
          && terminal_body_identifier != target_body_identifier)) continue;
    const uint features[10] = {
      0u, 1u, 2u, 3u, 4u, 8u, 9u,
      NB_MUSCLE_TASK_EFFECT, NB_MUSCLE_TASK_EFFECT + 1u,
      NB_MUSCLE_TASK_EFFECT + 2u,
    };
    for (uint index = 0u; index < 10u; ++index) {
      muscle_total += nb_normalized_muscle_feature_value(
        muscle[features[index]], features[index]
      );
      muscle_count += 1u;
    }
  }
  float total = 0.0f;
  uint factor_count = 0u;
  if (body_count > 0u) {
    total += body_total / float(body_count);
    factor_count += 1u;
  }
  if (joint_count > 0u) {
    total += joint_total / float(joint_count);
    factor_count += 1u;
  }
  if (muscle_count > 0u) {
    total += muscle_total / float(muscle_count);
    factor_count += 1u;
  }
  return factor_count > 0u
    ? clamp(total / float(factor_count), -1.0f, 1.0f) : 0.0f;
}

/// Selects only from physical actuators whose immutable muscle attachment
/// reaches the current motor-goal body. Index cycling distributes an expert's
/// delayed samples across eligible anatomy; it never invents anatomy. Robot
/// templates without biological attachment fingerprints retain their explicit
/// contiguous actuator fallback.
inline uint nb_cerebellar_anatomical_actuator(
  device const uchar *hot_state,
  constant NBDecisionUniforms &uniforms,
  uint target_body_identifier,
  uint selection_seed)
{
  if (uniforms.actuator_count == 0u) return 0u;
  uint eligible_count = 0u;
  for (uint muscle_index = 0u;
      muscle_index < uniforms.somatic_effector_belief_count; ++muscle_index) {
    device const float *muscle = reinterpret_cast<device const float *>(
      hot_state + uniforms.somatic_effector_belief_offset
        + ulong(muscle_index) * 192ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      muscle + NB_MUSCLE_IDENTITY_FLOAT_OFFSET
    );
    const uint actuator_identifier = uint(identity[5]);
    const uint first_body_identifier = uint(identity[7]);
    const uint terminal_body_identifier = uint(identity[7] >> 32u);
    const bool reaches_target = identity[2] == 0ul
      || first_body_identifier == target_body_identifier
      || terminal_body_identifier == target_body_identifier;
    if ((identity[3] & ulong(NB_CONTROL_FLAG_VALID)) != 0ul
        && actuator_identifier < uniforms.actuator_count
        && reaches_target) {
      eligible_count += 1u;
    }
  }
  if (eligible_count == 0u) {
    return selection_seed % uniforms.actuator_count;
  }
  const uint selected_rank = selection_seed % eligible_count;
  uint rank = 0u;
  for (uint muscle_index = 0u;
      muscle_index < uniforms.somatic_effector_belief_count; ++muscle_index) {
    device const float *muscle = reinterpret_cast<device const float *>(
      hot_state + uniforms.somatic_effector_belief_offset
        + ulong(muscle_index) * 192ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      muscle + NB_MUSCLE_IDENTITY_FLOAT_OFFSET
    );
    const uint actuator_identifier = uint(identity[5]);
    const uint first_body_identifier = uint(identity[7]);
    const uint terminal_body_identifier = uint(identity[7] >> 32u);
    const bool reaches_target = identity[2] == 0ul
      || first_body_identifier == target_body_identifier
      || terminal_body_identifier == target_body_identifier;
    if ((identity[3] & ulong(NB_CONTROL_FLAG_VALID)) == 0ul
        || actuator_identifier >= uniforms.actuator_count
        || !reaches_target) continue;
    if (rank == selected_rank) return actuator_identifier;
    rank += 1u;
  }
  return selection_seed % uniforms.actuator_count;
}

kernel void select_cerebellar_context_experts(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  device const float *cerebellar_parameters [[buffer(5)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.active_cerebellar_expert_count == 0u) return;
  device const NBControlHeader *header = reinterpret_cast<device const NBControlHeader *>(
    hot_state + uniforms.control_header_offset
  );
  device const NBMotorGoalRecord *motor_goal =
    reinterpret_cast<device const NBMotorGoalRecord *>(
      hot_state + uniforms.motor_goal_offset
    );
  device const float *recurrent = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  device NBCerebellarExpertRecord *experts =
    reinterpret_cast<device NBCerebellarExpertRecord *>(
      hot_state + uniforms.cerebellar_offset
    );
  device NBCerebellarExpertRecord *bank =
    reinterpret_cast<device NBCerebellarExpertRecord *>(
      hot_state + uniforms.cerebellar_expert_memory_offset
    );
  uint selected_identifiers[4] = {};
  float selected_scores[4] = {-INFINITY, -INFINITY, -INFINITY, -INFINITY};
  const uint active_count = min(uniforms.active_cerebellar_expert_count, 4u);
  const float option_context = float(
    uint(header->active_option_identifier ^ (header->active_option_identifier >> 32))
  ) * 2.3283064365386963e-10f;
  const bool motor_goal_valid =
    (motor_goal->flags & NB_CONTROL_FLAG_VALID) != 0u
      && motor_goal->option_identifier == header->active_option_identifier;
  const float motor_goal_context = motor_goal_valid
    ? clamp(
        0.25f * tanh(
          motor_goal->task_space_target[0]
            + motor_goal->task_space_target[1]
            + motor_goal->task_space_target[2]
        )
          + 0.25f * tanh(
            motor_goal->velocity_target[0]
              + motor_goal->velocity_target[1]
              + motor_goal->velocity_target[2]
          )
          + 0.25f * motor_goal->confidence
          - 0.25f * motor_goal->risk,
        -1.0f,
        1.0f
      )
    : 0.0f;
  const float embodied_context = motor_goal_valid
    ? nb_cerebellar_embodied_context(
        hot_state, uniforms, motor_goal->target_body_identifier
      )
    : 0.0f;
  for (uint expert_identifier = 0u;
      expert_identifier < uniforms.cerebellar_expert_capacity;
      ++expert_identifier) {
    NBCerebellarExpertRecord memory = bank[expert_identifier];
    if ((memory.flags & NB_CONTROL_FLAG_VALID) == 0u) {
      memory.expert_identifier = expert_identifier;
      memory.flags = NB_CONTROL_FLAG_VALID;
      memory.weight = 0.0f;
      memory.prediction_error = 0.0f;
      bank[expert_identifier] = memory;
    }
    const float neural_context = recurrent[
      (expert_identifier * 17u) % uniforms.recurrent_scalar_count
    ];
    const float expert_context = float(expert_identifier)
      / float(max(uniforms.cerebellar_expert_capacity - 1u, 1u));
    const float adaptation_bonus = clamp(abs(memory.state[2]), 0.0f, 0.25f);
    const float score = cerebellar_parameters[3]
      - abs(tanh(cerebellar_parameters[7] * neural_context + option_context
        + motor_goal_context + embodied_context)
        - expert_context) + adaptation_bonus;
    for (uint rank = 0u; rank < active_count; ++rank) {
      if (score > selected_scores[rank]
          || (score == selected_scores[rank]
            && expert_identifier < selected_identifiers[rank])) {
        for (uint shift = active_count - 1u; shift > rank; --shift) {
          selected_scores[shift] = selected_scores[shift - 1u];
          selected_identifiers[shift] = selected_identifiers[shift - 1u];
        }
        selected_scores[rank] = score;
        selected_identifiers[rank] = expert_identifier;
        break;
      }
    }
  }
  float weight_sum = 0.0f;
  for (uint rank = 0u; rank < active_count; ++rank) {
    weight_sum += exp(selected_scores[rank]);
  }
  for (uint rank = 0u; rank < active_count; ++rank) {
    NBCerebellarExpertRecord expert = bank[selected_identifiers[rank]];
    expert.weight = exp(selected_scores[rank]) / max(weight_sum, 1.0e-6f);
    experts[rank] = expert;
  }
  for (uint rank = active_count; rank < uniforms.active_cerebellar_expert_count;
      ++rank) {
    NBCerebellarExpertRecord inactive = {};
    experts[rank] = inactive;
  }
}

/// Advances the species-defined central pattern generator as independent,
/// transactional per-agent state. This first production path is analytic at
/// the committed control timestamp; physical-substep sampling can consume the
/// resulting state without making oscillator phase a shared parameter.
kernel void advance_cpg_state(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  device const NBCPGOscillatorDescriptor *oscillator_descriptors [[buffer(7)]],
  device const NBCPGCouplingDescriptor *coupling_descriptors [[buffer(8)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.cpg_oscillator_count == 0u) return;
  device const NBControlHeader *header =
    reinterpret_cast<device const NBControlHeader *>(
      hot_state + uniforms.control_header_offset
    );
  device const NBOptionCandidateRecord *candidates =
    reinterpret_cast<device const NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  device NBCPGStateRecord *states =
    reinterpret_cast<device NBCPGStateRecord *>(
      hot_state + uniforms.cpg_state_offset
    );
  const uint selected = min(
    uint(header->reserved0), max(uniforms.candidate_capacity, 1u) - 1u
  );
  const NBOptionCandidateRecord candidate = candidates[selected];
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  device const NBInternalActionRecord *internal_actions =
    reinterpret_cast<device const NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  const NBInternalActionRecord inhibition_request = internal_actions[6];
  const float deliberate_inhibition = inhibition_request.kind == 7u
      && (inhibition_request.flags & NB_CONTROL_FLAG_VALID) != 0u
    ? clamp(inhibition_request.priority, 0.0f, 1.0f)
    : 0.0f;
  device const NBDriveRecord *drives =
    reinterpret_cast<device const NBDriveRecord *>(
      hot_state + uniforms.drive_offset
    );
  const float safety = uniforms.drive_count > 11u
    ? clamp(drives[11].level, 0.0f, 1.0f)
    : 0.0f;
  const float motor_inhibition = max(
    (header->flags & NB_CONTROL_FLAG_HYPERDIRECT_STOP) != 0u ? 1.0f : safety,
    deliberate_inhibition
  );
  const bool locomotor_source = candidate.source_module == 72u
    || candidate.source_module == 65u || candidate.source_module == 60u;
  const bool locomotor_active = locomotor_source
    && (candidate.proposal_kind == NB_OPTION_PROPOSAL_LOCOMOTION
      || candidate.proposal_kind == NB_OPTION_PROPOSAL_EXPLORATION)
    && (header->flags & NB_CONTROL_FLAG_HYPERDIRECT_STOP) == 0u;

  device NBEventQueueHeader *event_header =
    reinterpret_cast<device NBEventQueueHeader *>(
      hot_state + uniforms.event_queue_offset
    );
  const uint event_count = min(
    min(
      atomic_load_explicit(&event_header->count, memory_order_relaxed),
      event_header->capacity
    ),
    uniforms.event_capacity
  );
  device const NBReceptorEventRecord *events =
    reinterpret_cast<device const NBReceptorEventRecord *>(event_header + 1);
  ulong delivered_interrupt_mask = 0ul;
  for (uint event_index = 0u; event_index < event_count; ++event_index) {
    if (events[event_index].timestamp_microseconds
        <= uniforms.target_timestamp_microseconds) {
      delivered_interrupt_mask |= nb_interrupt_mask_for_event_kind(
        events[event_index].kind
      );
    }
  }

  float prior_phases[64];
  for (uint oscillator = 0u; oscillator < uniforms.cpg_oscillator_count;
      ++oscillator) {
    const float phase = states[oscillator].phase;
    prior_phases[oscillator] = isfinite(phase)
      ? phase - floor(phase)
      : 0.0f;
  }
  constexpr float two_pi = 6.28318530717958647692f;
  for (uint oscillator = 0u; oscillator < uniforms.cpg_oscillator_count;
      ++oscillator) {
    const NBCPGOscillatorDescriptor descriptor = oscillator_descriptors[oscillator];
    NBCPGStateRecord state = states[oscillator];
    const bool vital = descriptor.output_kind
      == ulong(NB_CPG_OUTPUT_AUTONOMIC_CHANNEL);
    const bool active = vital || locomotor_active;
    const ulong prior_timestamp = state.timestamp_microseconds;
    const float elapsed_seconds = prior_timestamp > 0ul
        && uniforms.target_timestamp_microseconds > prior_timestamp
      ? float(uniforms.target_timestamp_microseconds - prior_timestamp) * 1.0e-6f
      : 0.0f;
    const bool reset = active && (descriptor.sensory_reset_mask
      & delivered_interrupt_mask) != 0ul;
    float reset_magnitude = 0.0f;
    if (reset) {
      for (uint event_index = 0u; event_index < event_count; ++event_index) {
        const NBReceptorEventRecord event = events[event_index];
        if (event.timestamp_microseconds <= uniforms.target_timestamp_microseconds
            && (descriptor.sensory_reset_mask
              & nb_interrupt_mask_for_event_kind(event.kind)) != 0ul) {
          reset_magnitude = max(reset_magnitude, clamp(event.magnitude, 0.0f, 1.0f));
        }
      }
    }
    float phase = active ? prior_phases[oscillator] : 0.0f;
    float coupling_frequency = 0.0f;
    if (active && !reset) {
      for (uint coupling = 0u; coupling < uniforms.cpg_coupling_count;
          ++coupling) {
        const NBCPGCouplingDescriptor edge = coupling_descriptors[coupling];
        if (edge.destination_oscillator_index == oscillator
            && edge.source_oscillator_index < uniforms.cpg_oscillator_count) {
          coupling_frequency += edge.gain * sin(
            two_pi * (prior_phases[edge.source_oscillator_index]
              - prior_phases[oscillator]) - edge.phase_offset
          );
        }
      }
    }
    const float vigor_scale = vital
      ? 1.0f
      : clamp(0.5f + header->vigor, 0.25f, 1.5f);
    const float effective_frequency = active
      ? max(descriptor.natural_frequency_hertz * vigor_scale
          + coupling_frequency, 0.0f)
      : descriptor.natural_frequency_hertz;
    if (reset) {
      phase = 0.0f;
    } else if (active && elapsed_seconds > 0.0f) {
      phase = fract(phase + elapsed_seconds * effective_frequency);
    }
    const float normalized_active_phase = phase / max(descriptor.duty_factor, 1.0e-6f);
    const float raw_output = active && phase < descriptor.duty_factor
      ? 0.5f - 0.5f * cos(two_pi * normalized_active_phase)
      : 0.0f;
    const float output_gain = vital
      ? 1.0f
      : (active
        ? (1.0f - motor_inhibition) * development->muscle_strength_multiplier
        : 0.0f);
    state.phase = phase;
    state.output = clamp(raw_output * output_gain, 0.0f, 1.0f);
    state.effective_frequency_hertz = effective_frequency;
    state.duty_factor = descriptor.duty_factor;
    state.sensory_reset_mask = descriptor.sensory_reset_mask;
    state.reset_magnitude = reset_magnitude;
    state.output_gain = output_gain;
    state.decision_output = state.output;
    state.reserved_float = 0.0f;
    state.timestamp_microseconds = uniforms.target_timestamp_microseconds;
    state.output_synergy_identifier = descriptor.output_synergy_identifier;
    state.oscillator_identifier = descriptor.identifier;
    state.flags = NB_CONTROL_FLAG_VALID
      | (active ? (1u << 1u) : 0u)
      | (reset ? (1u << 2u) : 0u);
    state.output_kind = uint(descriptor.output_kind);
    states[oscillator] = state;
  }
}

kernel void generate_motor_spinal_autonomic_state(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  device const float *policy_parameters [[buffer(3)]],
  device const float *motor_parameters [[buffer(4)]],
  device const NBCommunicationChannelDescriptor *communication_descriptors
    [[buffer(6)]],
  device const NBAutonomicChannelDescriptor *autonomic_descriptors
    [[buffer(9)]],
  device const NBActiveSensingChannelDescriptor *active_sensing_descriptors
    [[buffer(10)]],
  device const float *somatic_synergy_decoder [[buffer(13)]],
  device const float *policy_observation_sketch [[buffer(14)]],
  device const float *belief_parameters [[buffer(15)]],
  uint gid [[thread_position_in_grid]])
{
  device const float *recurrent = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  device const NBControlHeader *header = reinterpret_cast<device const NBControlHeader *>(
    hot_state + uniforms.control_header_offset
  );
  device const NBOptionCandidateRecord *candidates =
    reinterpret_cast<device const NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  device const NBDriveRecord *drives = reinterpret_cast<device const NBDriveRecord *>(
    hot_state + uniforms.drive_offset
  );
  device const NBNeuromodulatorRecord *neuromodulators =
    reinterpret_cast<device const NBNeuromodulatorRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  const uint selected = min(
    uint(header->reserved0), max(uniforms.candidate_capacity, 1u) - 1u
  );
  const NBOptionCandidateRecord candidate = candidates[selected];
  const uint parameter_count = min(max(candidate.parameter_count, 1u), 16u);
  device const NBMotorGoalRecord *motor_goal =
    reinterpret_cast<device const NBMotorGoalRecord *>(
      hot_state + uniforms.motor_goal_offset
    );
  const bool motor_goal_valid =
    (motor_goal->flags & NB_CONTROL_FLAG_VALID) != 0u
      && motor_goal->option_identifier == header->active_option_identifier;
  const bool communication_selected = development->stage >= 10u
    && candidate.source_module == 51u;
  const bool rest_selected = header->active_option_identifier
    == NB_REST_OPTION_IDENTIFIER;
  const float safety = uniforms.drive_count > 11u ? clamp(drives[11].level, 0.0f, 1.0f) : 0.0f;
  device const NBInternalActionRecord *internal_actions =
    reinterpret_cast<device const NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  const NBInternalActionRecord inhibition_request = internal_actions[6];
  const float deliberate_inhibition = inhibition_request.kind == 7u
      && (inhibition_request.flags & NB_CONTROL_FLAG_VALID) != 0u
    ? clamp(inhibition_request.priority, 0.0f, 1.0f)
    : 0.0f;
  device const NBCerebellarExpertRecord *experts =
    reinterpret_cast<device const NBCerebellarExpertRecord *>(
      hot_state + uniforms.cerebellar_offset
    );
  device const NBCPGStateRecord *cpg_states =
    reinterpret_cast<device const NBCPGStateRecord *>(
      hot_state + uniforms.cpg_state_offset
    );
  device NBFastCerebellarStateRecord *fast_cerebellar =
    reinterpret_cast<device NBFastCerebellarStateRecord *>(
      hot_state + uniforms.fast_cerebellar_state_offset
    );
  if (gid < uniforms.actuator_count) {
    device NBMotorCommandRecord *motor =
      reinterpret_cast<device NBMotorCommandRecord *>(hot_state + uniforms.motor_offset);
    device NBSpinalStateRecord *spinal =
      reinterpret_cast<device NBSpinalStateRecord *>(hot_state + uniforms.spinal_offset);
    device float *somatic_output = reinterpret_cast<device float *>(
      hot_state + uniforms.somatic_output_offset
    );
    device float *descending_baseline = reinterpret_cast<device float *>(
      hot_state + uniforms.descending_somatic_baseline_offset
    );
    device const uchar *body_belief = hot_state + uniforms.body_belief_offset;
    float body_risk = 0.0f;
    float support_confidence = 0.0f;
    uint body_evidence_count = 0u;
    uint target_body_index = 0u;
    bool target_body_found = false;
    for (uint body_index = 0u;
        body_index < uniforms.body_belief_count; ++body_index) {
      device const float *body = reinterpret_cast<device const float *>(
        body_belief + ulong(body_index) * 256ul
      );
      device const ulong *identity = reinterpret_cast<device const ulong *>(
        body + NB_BODY_IDENTITY_FLOAT_OFFSET
      );
      if ((identity[3] & 1ul) == 0ul) continue;
      body_risk = max(body_risk, max(
        clamp(body[NB_BODY_PAIN], 0.0f, 1.0f),
        max(
          clamp(body[NB_BODY_VULNERABILITY], 0.0f, 1.0f),
          clamp(body[NB_BODY_DAMAGE_RISK], 0.0f, 1.0f)
        )
      ));
      support_confidence = max(
        support_confidence, clamp(body[NB_BODY_SUPPORT], 0.0f, 1.0f)
      );
      if (motor_goal_valid
          && uint(identity[0]) == motor_goal->target_body_identifier) {
        target_body_index = body_index;
        target_body_found = true;
      }
      body_evidence_count += 1u;
    }
    device const float *effector = nullptr;
    device const ulong *effector_identity = nullptr;
    for (uint effector_index = 0u;
        effector_index < uniforms.somatic_effector_belief_count;
        ++effector_index) {
      device const float *candidate_effector =
        reinterpret_cast<device const float *>(
          hot_state + uniforms.somatic_effector_belief_offset
            + ulong(effector_index) * 192ul
        );
      device const ulong *candidate_identity =
        reinterpret_cast<device const ulong *>(
          candidate_effector + NB_MUSCLE_IDENTITY_FLOAT_OFFSET
        );
      if ((candidate_identity[3] & ulong(NB_CONTROL_FLAG_VALID)) != 0ul
          && uint(candidate_identity[5]) == gid) {
        effector = candidate_effector;
        effector_identity = candidate_identity;
        break;
      }
    }
    const bool effector_valid = effector != nullptr;
    const float agency_confidence =
      effector_valid
        ? clamp(effector[8], 0.0f, 1.0f) : 0.0f;
    const float external_disturbance =
      effector_valid
        ? clamp(effector[9], 0.0f, 1.0f) : 0.0f;
    float joint_uncertainty = 0.0f;
    const float joint_limit_risk = nb_articulated_joint_risk(
      hot_state, uniforms, joint_uncertainty
    );
    const float embodied_risk = clamp(
      body_risk * max(motor_parameters[11], 0.0f)
        + external_disturbance * max(motor_parameters[12], 0.0f)
        + joint_limit_risk * max(motor_parameters[14], 0.25f)
        + joint_uncertainty * max(motor_parameters[15], 0.1f),
      0.0f,
      1.0f
    );
    const NBCommunicationChannelDescriptor communication_descriptor =
      communication_descriptors[gid];
    const bool communication_actuator =
      (communication_descriptor.flags & NB_CONTROL_FLAG_VALID) != 0u;
    const bool muscle_excitation = nb_uses_muscle_excitation(
      uniforms.actuator_command_kind
    );
    const float motor_neutral = nb_motor_neutral(
      uniforms.actuator_command_kind
    );
    const bool anatomical_effector = effector_valid
      && effector_identity[2] != 0ul;
    const uint first_body_identifier = anatomical_effector
      ? uint(effector_identity[7]) : 0u;
    const uint terminal_body_identifier = anatomical_effector
      ? uint(effector_identity[7] >> 32u) : 0u;
    const bool effector_targets_body = motor_goal_valid
      && (first_body_identifier == motor_goal->target_body_identifier
        || terminal_body_identifier == motor_goal->target_body_identifier);
    const float endpoint_sign = terminal_body_identifier
        == motor_goal->target_body_identifier
      ? 1.0f : -1.0f;
    const float3 learned_task_effect = anatomical_effector
      && effector_targets_body
      ? endpoint_sign * float3(
          effector[NB_MUSCLE_TASK_EFFECT],
          effector[NB_MUSCLE_TASK_EFFECT + 1u],
          effector[NB_MUSCLE_TASK_EFFECT + 2u]
        )
      : float3(0.0f);
    const float3 absolute_task_effect = abs(learned_task_effect);
    uint task_axis = anatomical_effector ? 0u : gid % 3u;
    if (absolute_task_effect.y > absolute_task_effect[task_axis]) {
      task_axis = 1u;
    }
    if (absolute_task_effect.z > absolute_task_effect[task_axis]) {
      task_axis = 2u;
    }
    float task_correction = 0.0f;
    if (motor_goal_valid && target_body_found) {
      device const float *target_body = reinterpret_cast<device const float *>(
        body_belief + ulong(target_body_index) * 256ul
      );
      if (anatomical_effector) {
        if (effector_targets_body
            && length_squared(learned_task_effect) > 1.0e-8f) {
          float3 task_error = float3(0.0f);
          for (uint component = 0u; component < 3u; ++component) {
            const float position_error =
              motor_goal->task_space_target[component]
                - target_body[NB_BODY_POSITION + component];
            const float velocity_error = motor_goal->velocity_target[component]
              - target_body[NB_BODY_LINEAR_VELOCITY + component];
            const float force_error = motor_goal->force_target[component]
              - target_body[NB_BODY_LOCAL_FORCE + component];
            task_error[component] =
              motor_parameters[3] * tanh(position_error)
              + motor_parameters[4] * tanh(velocity_error)
              + motor_parameters[5] * tanh(force_error);
          }
          task_correction = motor_goal->confidence * dot(
            learned_task_effect, task_error
          );
        }
      } else {
        const float position_error = motor_goal->task_space_target[task_axis]
          - target_body[NB_BODY_POSITION + task_axis];
        const float velocity_error = motor_goal->velocity_target[task_axis]
          - target_body[NB_BODY_LINEAR_VELOCITY + task_axis];
        const float force_error = motor_goal->force_target[task_axis]
          - target_body[NB_BODY_LOCAL_FORCE + task_axis];
        task_correction = motor_goal->confidence * (
          motor_parameters[3] * tanh(position_error)
            + motor_parameters[4] * tanh(velocity_error)
            + motor_parameters[5] * tanh(force_error)
        );
      }
    }
    float cortical_synergy = 0.0f;
    uint dominant_synergy = 0u;
    float dominant_synergy_gain = 0.0f;
    const uint available_synergy_count = min(
      min(motor_goal->synergy_count, uniforms.synergy_count), 16u
    );
    for (uint synergy = 0u; synergy < uniforms.synergy_count; ++synergy) {
      const float decoder_gain = somatic_synergy_decoder[
        gid * uniforms.synergy_count + synergy
      ];
      if (abs(decoder_gain) > abs(dominant_synergy_gain)) {
        dominant_synergy = synergy;
        dominant_synergy_gain = decoder_gain;
      }
      const uint descriptor_index =
        uniforms.communication_synergy_descriptor_offset + synergy;
      const NBCommunicationChannelDescriptor synergy_descriptor =
        communication_descriptors[descriptor_index];
      const bool communication_synergy = descriptor_index
        < uniforms.communication_descriptor_count
        && (synergy_descriptor.flags & NB_CONTROL_FLAG_VALID) != 0u;
      const uint synergy_parameter_index =
        communication_selected && communication_synergy
          ? synergy_descriptor.local_channel_index % parameter_count
          : synergy % parameter_count;
      const float planned_gain = communication_selected
        ? (communication_synergy
          ? synergy_descriptor.gain
          : clamp(motor_parameters[8], 0.0f, 1.0f))
        : policy_parameters[7];
      const bool use_structured_synergy = motor_goal_valid
        && motor_goal->synergy_count > 0u && !communication_selected;
      const float planned_synergy = use_structured_synergy
        ? (synergy < available_synergy_count
          ? motor_goal->synergy_coefficients[synergy] : 0.0f)
        : candidate.parameters[synergy_parameter_index] * planned_gain;
      const float learned_synergy = motor_goal_valid
          && !communication_selected && synergy < 16u
        ? nb_learned_policy_synergy(
            recurrent, uniforms.recurrent_scalar_count,
            policy_parameters, belief_parameters,
            policy_observation_sketch, synergy
          ) * motor_parameters[7]
        : 0.0f;
      const float effective_synergy = rest_selected ? 0.0f : clamp(
        planned_synergy + learned_synergy, -1.0f, 1.0f
      ) * (1.0f - deliberate_inhibition);
      cortical_synergy += decoder_gain * effective_synergy;
    }
    cortical_synergy = clamp(cortical_synergy, -1.0f, 1.0f);
    const float motor_logit =
      candidate.parameters[gid % parameter_count]
        * uniforms.motor_gain * motor_parameters[0]
      + task_correction + cortical_synergy * motor_parameters[6];
    const float ordinary_descending = rest_selected
      ? motor_neutral
      : nb_motor_drive_from_logit(motor_logit, uniforms.actuator_command_kind);
    float descending = ordinary_descending;
    if (communication_selected) {
      if (communication_actuator) {
        const float communication_logit = candidate.parameters[
          communication_descriptor.local_channel_index % parameter_count
        ];
        const float communication_drive = nb_motor_drive_from_logit(
          communication_logit, uniforms.actuator_command_kind
        );
        descending = nb_scale_motor_drive(
          communication_drive,
          communication_descriptor.gain,
          uniforms.actuator_command_kind
        );
      } else {
        descending = nb_scale_motor_drive(
          ordinary_descending,
          motor_parameters[8],
          uniforms.actuator_command_kind
        );
      }
    }
    const float inhibition = max(
      (header->flags & NB_CONTROL_FLAG_HYPERDIRECT_STOP) != 0u
        ? 1.0f : max(safety, embodied_risk),
      deliberate_inhibition
    );
    NBFastCerebellarStateRecord fast_state = fast_cerebellar[gid];
    const bool fast_correction_active = !rest_selected && inhibition < 1.0f;
    fast_state.flags = (fast_state.flags | NB_CONTROL_FLAG_VALID)
      & ~(1u << 1u);
    fast_state.flags |= fast_correction_active ? (1u << 1u) : 0u;
    fast_cerebellar[gid] = fast_state;
    const float fast_cerebellar_residual = fast_correction_active
      ? clamp(fast_state.correction, -0.25f, 0.25f) : 0.0f;
    float learned_cerebellar_residual = 0.0f;
    float learned_cerebellar_weight = 0.0f;
    for (uint expert_index = 0u;
        expert_index < uniforms.active_cerebellar_expert_count;
        ++expert_index) {
      const NBCerebellarExpertRecord expert = experts[expert_index];
      if ((expert.flags & NB_CONTROL_FLAG_VALID) == 0u) continue;
      const uint sample_count = min(expert.prediction_count, 8u);
      const float expert_weight = max(expert.weight, 0.0f)
        * clamp(expert.state[2], 0.05f, 1.0f);
      for (uint sample = 0u; sample < sample_count; ++sample) {
        const uint feature_actuator = as_type<uint>(
          expert.state[36u + sample]
        );
        const uint actuator_identifier = feature_actuator
          >> NB_CEREBELLAR_ACTUATOR_SHIFT;
        if (actuator_identifier != gid) continue;
        learned_cerebellar_residual += expert_weight
          * expert.state[12u + sample];
        learned_cerebellar_weight += expert_weight;
      }
    }
    learned_cerebellar_residual = learned_cerebellar_weight > 0.0f
      ? learned_cerebellar_residual / learned_cerebellar_weight : 0.0f;
    descending = nb_scale_motor_drive(
      descending,
      1.0f - inhibition,
      uniforms.actuator_command_kind
    );
    const float developed_descending = nb_scale_motor_drive(
      descending,
      development->muscle_strength_multiplier,
      uniforms.actuator_command_kind
    );
    NBMotorCommandRecord command;
    command.excitation = clamp(developed_descending, 0.0f, 1.0f);
    float anatomical_force_target = 0.0f;
    const float task_effect_magnitude = length(learned_task_effect);
    if (motor_goal_valid && anatomical_effector
        && task_effect_magnitude > 1.0e-4f) {
      anatomical_force_target = clamp(abs(dot(
        learned_task_effect / task_effect_magnitude,
        float3(
          motor_goal->force_target[0],
          motor_goal->force_target[1],
          motor_goal->force_target[2]
        )
      )), 0.0f, 1.0f);
    }
    command.force_target = motor_goal_valid
      ? (muscle_excitation
        ? (anatomical_effector
          ? anatomical_force_target
          : clamp(abs(motor_goal->force_target[task_axis]), 0.0f, 1.0f))
        : clamp(motor_goal->force_target[task_axis], -1.0f, 1.0f))
      : nb_motor_feature(descending, uniforms.actuator_command_kind);
    const float goal_stiffness = motor_goal_valid
      ? motor_goal->stiffness_target[task_axis] * motor_goal->confidence
      : abs(candidate.parameters[(gid + 1u) % parameter_count]);
    command.stiffness_target = clamp(
      uniforms.stiffness_gain * motor_parameters[1]
        * (max(safety, body_risk)
          + joint_limit_risk
          + 0.5f * joint_uncertainty
          + (body_evidence_count > 0u ? 1.0f - support_confidence : 0.0f)
            * max(motor_parameters[13], 0.0f)
          + goal_stiffness),
      0.0f,
      1.0f
    );
    command.damping_target = clamp(
      uniforms.damping_gain * motor_parameters[2]
        * max(
          command.stiffness_target,
          motor_goal_valid ? motor_goal->damping_target[task_axis] : 0.0f
        ),
      0.0f,
      1.0f
    );
    const float slow_cerebellar_residual = rest_selected
      ? 0.0f
      : clamp(
          learned_cerebellar_residual * clamp(
            1.0f - header->unsupported_uncertainty
              * abs(motor_parameters[10]),
            0.0f,
            1.0f
          ),
          -0.25f, 0.25f
        ) * (0.5f + 0.5f * agency_confidence);
    command.cerebellar_residual = clamp(
      slow_cerebellar_residual + fast_cerebellar_residual,
      -0.25f,
      0.25f
    );
    command.risk_inhibition = inhibition;
    command.synergy_identifier = dominant_synergy;
    command.flags = NB_CONTROL_FLAG_VALID
      | (communication_selected && communication_actuator ? (1u << 4u) : 0u)
      | (muscle_excitation ? (1u << 5u) : 0u);
    motor[gid] = command;
    float cpg_output = 0.0f;
    for (uint oscillator = 0u; oscillator < uniforms.cpg_oscillator_count;
        ++oscillator) {
      const NBCPGStateRecord oscillator_state = cpg_states[oscillator];
      if ((oscillator_state.flags & NB_CONTROL_FLAG_VALID) != 0u
          && oscillator_state.output_kind == NB_CPG_OUTPUT_SOMATIC_SYNERGY
          && oscillator_state.output_synergy_identifier
            < uniforms.synergy_count) {
        cpg_output += oscillator_state.output * somatic_synergy_decoder[
          gid * uniforms.synergy_count
            + oscillator_state.output_synergy_identifier
        ];
      }
    }
    // Antagonist decoder gains remain signed until final motor-neuron
    // excitation is bounded; otherwise the negative half of a gait vanishes.
    cpg_output = clamp(cpg_output, -1.0f, 1.0f);
    NBSpinalStateRecord spinal_state;
    spinal_state.reflex_output = safety > 0.5f ? -0.25f : 0.0f;
    spinal_state.cpg_output = cpg_output;
    spinal_state.motor_neuron_state = command.excitation
      + command.cerebellar_residual + spinal_state.cpg_output;
    const float baseline_excitation = clamp(
      command.excitation + slow_cerebellar_residual
        + spinal_state.reflex_output,
      0.0f,
      1.0f
    );
    descending_baseline[gid] = baseline_excitation;
    spinal_state.final_excitation = clamp(
      baseline_excitation + fast_cerebellar_residual
        + spinal_state.cpg_output,
      0.0f,
      1.0f
    );
    spinal[gid] = spinal_state;
    somatic_output[gid] = spinal_state.final_excitation;
  }
  if (gid < uniforms.synergy_count) {
    device float *synergies = reinterpret_cast<device float *>(
      hot_state + uniforms.synergy_offset
    );
    const uint descriptor_index =
      uniforms.communication_synergy_descriptor_offset + gid;
    const NBCommunicationChannelDescriptor communication_descriptor =
      communication_descriptors[descriptor_index];
    const bool communication_synergy = descriptor_index
      < uniforms.communication_descriptor_count
      && (communication_descriptor.flags & NB_CONTROL_FLAG_VALID) != 0u;
    const uint parameter_index = communication_selected && communication_synergy
      ? communication_descriptor.local_channel_index % parameter_count
      : gid % parameter_count;
    const float gain = communication_selected
      ? (communication_synergy
        ? communication_descriptor.gain
        : clamp(motor_parameters[8], 0.0f, 1.0f))
      : policy_parameters[7];
    const bool use_structured_synergy = motor_goal_valid
      && motor_goal->synergy_count > 0u && !communication_selected;
    const float structured_synergy = use_structured_synergy
      ? (gid < min(motor_goal->synergy_count, 16u)
        ? motor_goal->synergy_coefficients[gid] : 0.0f)
      : candidate.parameters[parameter_index];
    const float planned_synergy = structured_synergy
      * (use_structured_synergy ? 1.0f : gain);
    const float learned_synergy = motor_goal_valid
        && !communication_selected && gid < 16u
      ? nb_learned_policy_synergy(
          recurrent, uniforms.recurrent_scalar_count,
          policy_parameters, belief_parameters,
          policy_observation_sketch, gid
        ) * motor_parameters[7]
      : 0.0f;
    synergies[gid] = rest_selected ? 0.0f : clamp(
      planned_synergy + learned_synergy, -1.0f, 1.0f
    ) * (1.0f - deliberate_inhibition);
  }
  if (gid < uniforms.autonomic_dimension) {
    device NBAutonomicCommandRecord *autonomic =
      reinterpret_cast<device NBAutonomicCommandRecord *>(
        hot_state + uniforms.autonomic_offset
      );
    const NBAutonomicChannelDescriptor descriptor = autonomic_descriptors[gid];
    const float energy = uniforms.drive_count > 0u
      ? clamp(drives[0].level, 0.0f, 1.0f) : 0.0f;
    const float oxygen = uniforms.drive_count > 2u
      ? clamp(drives[2].level, 0.0f, 1.0f) : 0.0f;
    const float temperature = uniforms.drive_count > 3u
      ? clamp(drives[3].level, 0.0f, 1.0f) : 0.0f;
    const float fatigue = uniforms.drive_count > 4u
      ? clamp(drives[4].level, 0.0f, 1.0f) : 0.0f;
    const float sleep = uniforms.drive_count > 7u
      ? clamp(drives[7].level, 0.0f, 1.0f) : 0.0f;
    float target = 0.0f;
    switch (descriptor.kind) {
      case 1u:
        target = max(oxygen, max(0.75f * safety, 0.25f * fatigue));
        break;
      case 2u:
        target = max(oxygen, max(safety, 0.25f * fatigue));
        break;
      case 3u:
        target = max(oxygen, max(safety, header->vigor));
        break;
      case 4u:
        target = max(safety, oxygen);
        break;
      case 5u:
        target = temperature;
        break;
      case 6u:
        target = max(safety, 0.5f * header->vigor);
        break;
      case 7u:
        target = energy * (1.0f - safety) * (rest_selected ? 1.0f : 0.5f);
        break;
      case 8u:
        target = safety;
        break;
      case 9u:
        target = max(sleep, fatigue) * (1.0f - safety);
        break;
      default:
        target = clamp(
          candidate.parameters[(gid + 8u) % parameter_count]
            * max(policy_parameters[10], 0.0f),
          0.0f,
          1.0f
        );
        break;
    }
    device NBEventQueueHeader *event_header =
      reinterpret_cast<device NBEventQueueHeader *>(
        hot_state + uniforms.event_queue_offset
      );
    const uint event_count = min(
      min(
        atomic_load_explicit(&event_header->count, memory_order_relaxed),
        event_header->capacity
      ),
      uniforms.event_capacity
    );
    device const NBReceptorEventRecord *events =
      reinterpret_cast<device const NBReceptorEventRecord *>(event_header + 1);
    float critical_strength = 0.0f;
    for (uint event_index = 0u; event_index < event_count; ++event_index) {
      const NBReceptorEventRecord event = events[event_index];
      if (event.kind != 12u) continue;
      bool receptor_match = (descriptor.flags & (1u << 1u)) != 0u;
      for (uint receptor_index = 0u;
          receptor_index < min(descriptor.critical_receptor_count, 4u);
          ++receptor_index) {
        receptor_match = receptor_match
          || descriptor.critical_receptors[receptor_index]
            == event.source_identifier;
      }
      if (receptor_match) {
        critical_strength = max(
          critical_strength,
          clamp(event.magnitude * descriptor.emergency_gain, 0.0f, 1.0f)
        );
      }
    }
    target = mix(
      clamp(target, 0.0f, 1.0f),
      clamp(descriptor.emergency_target, 0.0f, 1.0f),
      critical_strength
    );
    NBAutonomicCommandRecord command;
    command.command = target;
    command.target = command.command;
    command.confidence = max(header->confidence, critical_strength);
    command.flags = NB_CONTROL_FLAG_VALID
      | (critical_strength > 0.0f ? (1u << 1u) : 0u);
    autonomic[gid] = command;
  }
  if (gid < uniforms.active_sensing_dimension) {
    device NBActiveSensingCommandRecord *active_sensing =
      reinterpret_cast<device NBActiveSensingCommandRecord *>(
        hot_state + uniforms.active_sensing_offset
      );
    const uint descriptor_index = uniforms.active_sensing_descriptor_offset + gid;
    const NBCommunicationChannelDescriptor communication_descriptor =
      communication_descriptors[descriptor_index];
    const bool communication_sensing = descriptor_index
      < uniforms.communication_descriptor_count
      && (communication_descriptor.flags & NB_CONTROL_FLAG_VALID) != 0u;
    const NBActiveSensingChannelDescriptor sensing_descriptor =
      active_sensing_descriptors[gid];
    const uint parameter_index = communication_selected && communication_sensing
      ? communication_descriptor.local_channel_index % parameter_count
      : (gid + 8u) % parameter_count;
    const float epistemic = uniforms.neuromodulator_count > 3u
      ? clamp(neuromodulators[3].value, 0.0f, 1.0f) : 0.0f;
    device const float *world = reinterpret_cast<device const float *>(
      hot_state + uniforms.world_model_offset
    );
    const float prior_modality_uncertainty =
      nb_modality_epistemic_uncertainty(
        world, uniforms.world_model_scalar_count, sensing_descriptor.modality
      );
    device NBActiveSensingEfficacyRecord *sensing_efficacy =
      reinterpret_cast<device NBActiveSensingEfficacyRecord *>(
        hot_state + uniforms.active_sensing_efficacy_offset
      );
    NBActiveSensingEfficacyRecord efficacy_state = sensing_efficacy[gid];
    const float learned_efficacy = efficacy_state.sample_count > 0u
        && (efficacy_state.flags & NB_CONTROL_FLAG_VALID) != 0u
      ? clamp(efficacy_state.efficacy, 0.0f, 2.0f)
      : 1.0f;
    float modality_uncertainty = max(epistemic, prior_modality_uncertainty);
    uint epistemic_target_slot = 0u;
    float epistemic_target_command = 0.0f;
    float epistemic_target_score = 0.0f;
    float epistemic_target_uncertainty = 0.0f;
    if (sensing_descriptor.modality == 1u) {
      device const NBObjectSlotRecord *object_slots =
        reinterpret_cast<device const NBObjectSlotRecord *>(
          hot_state + uniforms.object_slot_offset
        );
      float weighted_uncertainty = 0.0f;
      float evidence_weight = 0.0f;
      for (uint object_index = 0u; object_index < uniforms.object_slot_count;
          ++object_index) {
        const NBObjectSlotRecord object = object_slots[object_index];
        if (object.identifier == 0ul
            || (object.flags & NB_CONTROL_FLAG_VALID) == 0u
            || object.existence_probability <= 0.01f) continue;
        const float weight = clamp(
          object.existence_probability * max(object.visibility, 0.1f),
          0.0f, 1.0f
        );
        weighted_uncertainty += clamp(object.uncertainty, 0.0f, 1.0f) * weight;
        evidence_weight += weight;
        const float target_score = object.existence_probability
          * clamp(object.uncertainty, 0.0f, 1.0f)
          * (1.0f - 0.5f * clamp(object.visibility, 0.0f, 1.0f));
        if (target_score > epistemic_target_score) {
          epistemic_target_score = target_score;
          epistemic_target_slot = object_index + 1u;
          epistemic_target_uncertainty = clamp(object.uncertainty, 0.0f, 1.0f);
          epistemic_target_command = object.pose[
            sensing_descriptor.modality_local_identifier % 3u
          ];
        }
      }
      if (evidence_weight > 0.0f) {
        modality_uncertainty = max(
          modality_uncertainty,
          clamp(weighted_uncertainty / evidence_weight, 0.0f, 1.0f)
        );
      }
      modality_uncertainty = max(
        modality_uncertainty, epistemic_target_uncertainty
      );
    } else if (sensing_descriptor.modality == 3u
        || sensing_descriptor.modality == 4u) {
      float agency_uncertainty = 0.0f;
      float body_model_uncertainty = 0.0f;
      for (uint effector_index = 0u;
          effector_index < uniforms.somatic_effector_belief_count;
          ++effector_index) {
        device const float *effector = reinterpret_cast<device const float *>(
          hot_state + uniforms.somatic_effector_belief_offset
            + ulong(effector_index) * 192ul
        );
        agency_uncertainty = max(
          agency_uncertainty, 1.0f - clamp(effector[8], 0.0f, 1.0f)
        );
      }
      device const uchar *body_belief = hot_state + uniforms.body_belief_offset;
      for (uint body_index = 0u;
          body_index < uniforms.body_belief_count; ++body_index) {
        device const float *body = reinterpret_cast<device const float *>(
          body_belief + ulong(body_index) * 256ul
        );
        device const ulong *identity = reinterpret_cast<device const ulong *>(
          body + NB_BODY_IDENTITY_FLOAT_OFFSET
        );
        if ((identity[3] & 1ul) == 0ul
            || !isfinite(body[NB_BODY_LOAD_VARIANCE])) continue;
        const float standard_deviation = sqrt(
          max(body[NB_BODY_LOAD_VARIANCE], 0.0f)
        );
        body_model_uncertainty = max(
          body_model_uncertainty,
          standard_deviation / (1.0f + standard_deviation)
        );
      }
      modality_uncertainty = max(
        modality_uncertainty,
        max(agency_uncertainty, body_model_uncertainty)
      );
    } else if (sensing_descriptor.modality == 5u) {
      float support_uncertainty = 0.0f;
      device const uchar *body_belief = hot_state + uniforms.body_belief_offset;
      for (uint body_index = 0u;
          body_index < uniforms.body_belief_count; ++body_index) {
        device const float *body = reinterpret_cast<device const float *>(
          body_belief + ulong(body_index) * 256ul
        );
        device const ulong *identity = reinterpret_cast<device const ulong *>(
          body + NB_BODY_IDENTITY_FLOAT_OFFSET
        );
        if ((identity[3] & 1ul) == 0ul) continue;
        support_uncertainty = max(
          support_uncertainty,
          1.0f - clamp(body[NB_BODY_SUPPORT], 0.0f, 1.0f)
        );
      }
      modality_uncertainty = max(modality_uncertainty, support_uncertainty);
    }
    const float expected_information = clamp(
      max(modality_uncertainty, candidate.information_gain), 0.0f, 1.0f
    );
    const float fatigue = uniforms.drive_count > 4u
      ? clamp(drives[4].level, 0.0f, 1.0f) : 0.0f;
    const float embodied_risk = max(
      safety, nb_embodied_self_risk(hot_state, uniforms)
    );
    const float sensing_cost = clamp(
      embodied_risk + 0.5f * fatigue + 0.25f * candidate.effort_cost,
      0.0f, 1.0f
    );
    const float expected_sensing_value = clamp(
      expected_information * max(policy_parameters[15], 0.0f)
        * learned_efficacy,
      0.0f, 1.0f
    );
    const float information_allocation = expected_sensing_value
        > max(policy_parameters[14], 0.0f)
      ? expected_sensing_value * (1.0f - sensing_cost)
      : 0.0f;
    const float communication_allocation =
      communication_selected && communication_sensing
        ? header->confidence * (1.0f - sensing_cost) : 0.0f;
    // Active sensing is an independent effector. A rest option suppresses
    // somatic drive above, but must not deadlock a zero-reaction camera or eye
    // actuator when uncertainty still makes observation valuable.
    const float allocation = clamp(
      max(information_allocation, communication_allocation)
        * (1.0f - deliberate_inhibition),
      0.0f, 1.0f
    );
    const float policy_command = communication_selected && communication_sensing
      ? candidate.parameters[parameter_index] * communication_descriptor.gain
      : tanh(candidate.parameters[parameter_index])
        * clamp(policy_parameters[9], 0.0f, 1.0f);
    const bool grounded_visual_target = sensing_descriptor.modality == 1u
      && sensing_descriptor.modality_local_identifier < 3u
      && epistemic_target_slot > 0u;
    const uint scan_index = uint(
      (uniforms.target_timestamp_microseconds / 1000ul
        + ulong(gid) * 73ul) & 255ul
    );
    const float exploratory_visual_command = sensing_descriptor.modality == 1u
        && allocation > 0.0f
      ? sin(6.28318530717958647692f * float(scan_index) / 256.0f)
      : 0.0f;
    const float ungrounded_command = abs(policy_command) > 1.0e-6f
      ? policy_command : exploratory_visual_command;
    const float raw_command = grounded_visual_target
      ? mix(
          policy_command,
          clamp(epistemic_target_command, -1.0f, 1.0f),
          clamp(epistemic_target_score, 0.0f, 1.0f)
        )
      : ungrounded_command;
    const float authored_command_scale =
      as_type<float>(uniforms.active_sensing_command_scale_bits);
    const float command_scale = isfinite(authored_command_scale)
        && authored_command_scale >= 0.0f
        && authored_command_scale <= 1.0f
      ? authored_command_scale : 0.0f;
    NBActiveSensingCommandRecord command;
    command.command = clamp(
      raw_command * allocation * command_scale, -1.0f, 1.0f
    );
    command.confidence = clamp(
      allocation * max(header->confidence, expected_information) * command_scale,
      0.0f, 1.0f
    );
    command.attention_allocation_mask = allocation > 0.0f
      ? (1u << min(max(sensing_descriptor.modality, 1u) - 1u, 7u))
        | ((epistemic_target_slot & 0xffffu) << 16u)
      : 0u;
    command.kind_and_flags =
      (sensing_descriptor.modality & 0xffu)
      | ((sensing_descriptor.modality_local_identifier & 0xffu) << 8u)
      | (NB_CONTROL_FLAG_VALID << 16u)
      | (communication_selected && communication_sensing ? (1u << 17u) : 0u)
      | ((communication_sensing ? communication_descriptor.effector_kind : 0u)
        << 24u);
    active_sensing[gid] = command;
    efficacy_state.prior_uncertainty = modality_uncertainty;
    efficacy_state.allocation = allocation;
    efficacy_state.flags = NB_CONTROL_FLAG_VALID
      | (allocation > 0.0f ? (1u << 1u) : 0u);
    sensing_efficacy[gid] = efficacy_state;
  }
}

/// Arms each expert with eight timestamped articulated predictions after the
/// exact motor command has been generated. Each sample retains its physical
/// actuator, typed feature, and source record so delayed body, joint, and
/// muscle feedback cannot alias one another during accepted-only learning.
kernel void predict_delayed_cerebellar_consequences(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  device const float *cerebellar_parameters [[buffer(5)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.active_cerebellar_expert_count) return;
  device NBCerebellarExpertRecord *experts =
    reinterpret_cast<device NBCerebellarExpertRecord *>(
      hot_state + uniforms.cerebellar_offset
  );
  NBCerebellarExpertRecord expert = experts[gid];
  if ((expert.flags & NB_CONTROL_FLAG_VALID) == 0u) return;
  device const NBMotorGoalRecord *motor_goal =
    reinterpret_cast<device const NBMotorGoalRecord *>(
      hot_state + uniforms.motor_goal_offset
    );
  const bool motor_goal_valid =
    (motor_goal->flags & NB_CONTROL_FLAG_VALID) != 0u
      && motor_goal->timestamp_microseconds
        == uniforms.target_timestamp_microseconds;
  device const uchar *body_belief = hot_state + uniforms.body_belief_offset;
  device const float *body = nullptr;
  uint target_body_index = 0u;
  if (motor_goal_valid) {
    for (uint body_index = 0u; body_index < uniforms.body_belief_count;
        ++body_index) {
      device const float *candidate_body = reinterpret_cast<device const float *>(
        body_belief + ulong(body_index) * 256ul
      );
      device const ulong *identity = reinterpret_cast<device const ulong *>(
        candidate_body + NB_BODY_IDENTITY_FLOAT_OFFSET
      );
      if ((identity[3] & NB_CONTROL_FLAG_VALID) != 0ul
          && uint(identity[0]) == motor_goal->target_body_identifier) {
        body = candidate_body;
        target_body_index = body_index;
        break;
      }
    }
  }
  if (body == nullptr) {
    expert.prediction_count = 0u;
    expert.flags &= ~NB_CEREBELLAR_PREDICTION_VALID;
    experts[gid] = expert;
    return;
  }
  device const float *somatic_output = reinterpret_cast<device const float *>(
    hot_state + uniforms.somatic_output_offset
  );
  const uint prediction_count = 8u;
  float mean_command = 0.0f;
  for (uint sample = 0u; sample < prediction_count; ++sample) {
    uint feature_code =
      (expert.expert_identifier * 17u + sample * 31u)
        % NB_BODY_SENSORIMOTOR_FEATURE_COUNT;
    uint source_index = target_body_index;
    float baseline = nb_normalized_body_feature_value(
      body[feature_code], feature_code
    );
    uint actuator_index = nb_cerebellar_anatomical_actuator(
      hot_state,
      uniforms,
      motor_goal->target_body_identifier,
      expert.expert_identifier * prediction_count + sample
    );
    float command_feature = 0.0f;
    bool articulated_source = false;
    if (sample >= 4u && sample < 6u && uniforms.joint_belief_count > 0u) {
      const uint first_joint = (
        expert.expert_identifier * 17u + sample * 13u
      ) % uniforms.joint_belief_count;
      for (uint joint_lane = 0u; joint_lane < uniforms.joint_belief_count;
          ++joint_lane) {
        const uint joint_index = (
          first_joint + joint_lane
        ) % uniforms.joint_belief_count;
        device const float *joint = reinterpret_cast<device const float *>(
          hot_state + uniforms.joint_belief_offset
            + ulong(joint_index) * 256ul
        );
        device const ulong *identity = reinterpret_cast<device const ulong *>(
          joint + NB_JOINT_IDENTITY_FLOAT_OFFSET
        );
        const uint coordinate_count = min(uint(identity[3]), 6u);
        if ((identity[7] & ulong(NB_CONTROL_FLAG_VALID)) == 0ul
            || coordinate_count == 0u
            || (uint(identity[1]) != motor_goal->target_body_identifier
              && uint(identity[2]) != motor_goal->target_body_identifier)) {
          continue;
        }
        const uint coordinate = (
          expert.expert_identifier + sample + joint_index
        ) % coordinate_count;
        const uint joint_feature = sample == 4u
          ? coordinate : NB_JOINT_LIMIT_ACTIVATION + coordinate;
        if (!isfinite(joint[joint_feature])) continue;
        feature_code = NB_CEREBELLAR_JOINT_FEATURE_BASE + joint_feature;
        source_index = joint_index;
        baseline = nb_normalized_joint_feature_value(
          joint[joint_feature], joint_feature
        );
        articulated_source = true;
        break;
      }
    } else if (sample >= 6u
        && uniforms.somatic_effector_belief_count > 0u) {
      const uint first_muscle = (
        expert.expert_identifier * 7u + sample
      ) % uniforms.somatic_effector_belief_count;
      for (uint muscle_lane = 0u;
          muscle_lane < uniforms.somatic_effector_belief_count;
          ++muscle_lane) {
        const uint muscle_index = (
          first_muscle + muscle_lane
        ) % uniforms.somatic_effector_belief_count;
        device const float *muscle = reinterpret_cast<device const float *>(
          hot_state + uniforms.somatic_effector_belief_offset
            + ulong(muscle_index) * 192ul
        );
        device const ulong *identity = reinterpret_cast<device const ulong *>(
          muscle + NB_MUSCLE_IDENTITY_FLOAT_OFFSET
        );
        const uint first_body_identifier = uint(identity[7]);
        const uint terminal_body_identifier = uint(identity[7] >> 32u);
        if ((identity[3] & ulong(NB_CONTROL_FLAG_VALID)) == 0ul
            || uint(identity[5]) >= uniforms.actuator_count
            || (identity[2] != 0ul
              && first_body_identifier
                != motor_goal->target_body_identifier
              && terminal_body_identifier
                != motor_goal->target_body_identifier)) continue;
        const uint muscle_feature = sample == 6u
          ? 1u + (expert.expert_identifier & 1u)
          : (expert.expert_identifier % 3u == 0u ? 4u
            : (expert.expert_identifier % 3u == 1u ? 5u : 9u));
        if (muscle_feature >= NB_MUSCLE_SENSORIMOTOR_FEATURE_COUNT
            || !isfinite(muscle[muscle_feature])) continue;
        feature_code = NB_CEREBELLAR_MUSCLE_FEATURE_BASE + muscle_feature;
        source_index = muscle_index;
        baseline = nb_normalized_muscle_feature_value(
          muscle[muscle_feature], muscle_feature
        );
        actuator_index = uint(identity[5]);
        articulated_source = true;
        break;
      }
    }
    const float actuator_feature = uniforms.actuator_count == 0u
      ? 0.0f
      : nb_motor_feature(
          somatic_output[actuator_index], uniforms.actuator_command_kind
        );
    if (articulated_source) {
      command_feature = clamp(
        actuator_feature * motor_goal->confidence
          * (1.0f - clamp(motor_goal->risk, 0.0f, 1.0f)),
        -1.0f,
        1.0f
      );
    } else {
      const uint body_feature = feature_code;
      const float goal_feature = nb_motor_goal_body_feature(
        motor_goal, body_feature, baseline
      );
      command_feature = clamp(
        0.5f * actuator_feature
          + 0.5f * (goal_feature - baseline) * motor_goal->confidence,
        -1.0f,
        1.0f
      );
    }
    const float learned_effect = clamp(
      cerebellar_parameters[4] + expert.state[28u + sample],
      -1.0f,
      1.0f
    );
    expert.state[4u + sample] = baseline
      + clamp(command_feature * learned_effect, -1.0f, 1.0f);
    expert.state[20u + sample] = command_feature;
    expert.state[36u + sample] = as_type<float>(
      (actuator_index << NB_CEREBELLAR_ACTUATOR_SHIFT)
        | (feature_code & NB_CEREBELLAR_FEATURE_MASK)
    );
    expert.state[44u + sample] = float(source_index);
    mean_command += command_feature;
  }
  expert.state[3] = prediction_count == 0u
    ? 0.0f : mean_command / float(prediction_count);
  expert.prediction_timestamp_microseconds =
    uniforms.target_timestamp_microseconds;
  expert.prediction_count = prediction_count;
  expert.reserved = motor_goal->target_body_identifier;
  expert.flags |= NB_CEREBELLAR_PREDICTION_VALID;
  experts[gid] = expert;
}

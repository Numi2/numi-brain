#include <metal_stdlib>
using namespace metal;

constant uint NB_ACCEPTED_STATE_VALID = 1u;
constant uint NB_ACCEPTED_MUSCLE_LENGTH_VALID = 1u << 1;
constant uint NB_ACCEPTED_MUSCLE_VELOCITY_VALID = 1u << 2;
constant uint NB_ACCEPTED_MUSCLE_FORCE_VALID = 1u << 3;
constant uint NB_ACCEPTED_MUSCLE_FATIGUE_VALID = 1u << 4;
constant ulong NB_ACCEPTED_BODY_ARTICULATED = 1ul << 5;
constant uint NB_ACCEPTED_CEREBELLAR_PREDICTION_VALID = 1u << 5;
constant uint NB_ACCEPTED_TRACE_COMPLETE = 1u << 1;
constant uint NB_ACCEPTED_TRACE_FAILED = 1u << 2;
constant uint NB_ACCEPTED_CONTROL_HYPERDIRECT_STOP = 1u << 1;
constant uint NB_ACCEPTED_CONTROL_EXTERNAL_GOAL_FAILED = 1u << 8;
constant uint NB_ACCEPTED_CONTROL_MODE_REFLEX = 1u;
constant uint NB_ACCEPTED_REFLEX_ACTIVATED_IN_ROOT = 1u << 5;
constant uint NB_ACCEPTED_PROTECTIVE_VALID = 1u;
constant uint NB_ACCEPTED_PROTECTIVE_EMERGENCY_STOP = 1u << 1;
constant ulong NB_ACCEPTED_INNATE_OPTION_NAMESPACE = 0x8000000000000000ul;
constant ulong NB_ACCEPTED_REST_OPTION_IDENTIFIER =
  NB_ACCEPTED_INNATE_OPTION_NAMESPACE | 4ul;
constant uint NB_WORLD_RECEPTOR_DIMENSION = 128u;
constant uint NB_WORLD_HEAD_COUNT = 5u;
constant uint NB_WORLD_SENSORIMOTOR_BASE = 9u * NB_WORLD_RECEPTOR_DIMENSION;
constant uint NB_WORLD_SENSORIMOTOR_DIMENSION = 256u;
constant uint NB_WORLD_EVENT_OPTION_BASE = 5760u;
constant uint NB_WORLD_EVENT_OPTION_DIMENSION = 256u;
constant uint NB_ACCEPTED_ACTUATOR_MUSCLE_EXCITATION = 1u;
constant ulong NB_ACCEPTED_GOAL_SOURCE_MASK = 0x00fffffffffffffful;

// Canonical full-vector BodyNodeBelief prefix inside each 256-byte record.
// Forty FP32 values precede eight UInt64 identity/provenance fields. This is
// layout version 2 and must remain aligned across every shader consumer.
constant uint NB_BODY_POSITION = 0u;               // float3
constant uint NB_BODY_ORIENTATION = 3u;            // float4 quaternion
constant uint NB_BODY_LINEAR_VELOCITY = 7u;        // float3
constant uint NB_BODY_ANGULAR_VELOCITY = 10u;      // float3
constant uint NB_BODY_POSITION_VARIANCE = 13u;     // float3
constant uint NB_BODY_ORIENTATION_VARIANCE = 16u;  // float3
constant uint NB_BODY_CONTACT = 19u;
constant uint NB_BODY_SUPPORT = 20u;
constant uint NB_BODY_LOCAL_FORCE = 21u;            // float3
constant uint NB_BODY_PAIN = 24u;
constant uint NB_BODY_VULNERABILITY = 25u;
constant uint NB_BODY_REACHABILITY = 26u;
constant uint NB_BODY_OWNERSHIP = 27u;
constant uint NB_BODY_LOAD = 28u;
constant uint NB_BODY_LOAD_VARIANCE = 29u;
constant uint NB_BODY_DAMAGE_RISK = 30u;
constant uint NB_BODY_PROPRIOCEPTIVE_ERROR = 31u;
constant uint NB_BODY_EXTERNAL_DISTURBANCE = 32u;
constant uint NB_BODY_SENSORIMOTOR_FEATURE_COUNT = 33u;
constant uint NB_BODY_IDENTITY_FLOAT_OFFSET = 40u;

struct NBAcceptedConsequenceUniforms {
  ulong target_timestamp_microseconds;
  ulong delta_microseconds;
  ulong observation_offset;
  ulong observation_validity_offset;
  ulong event_queue_offset;
  ulong body_belief_offset;
  ulong joint_belief_offset;
  ulong muscle_belief_offset;
  ulong physiology_offset;
  ulong object_slot_offset;
  ulong world_model_offset;
  ulong neuromodulation_offset;
  ulong drive_offset;
  ulong fast_plasticity_offset;
  ulong workspace_content_offset;
  ulong workspace_metadata_offset;
  ulong control_header_offset;
  ulong option_candidate_offset;
  ulong procedural_trace_offset;
  ulong motor_command_offset;
  ulong cerebellar_offset;
  ulong cerebellar_expert_memory_offset;
  ulong somatic_output_offset;
  ulong active_sensing_command_offset;
  ulong active_sensing_efficacy_offset;
  ulong accepted_somatic_output_offset;
  ulong accepted_active_sensing_output_offset;
  ulong reflex_state_offset;
  ulong fast_autonomic_state_offset;
  ulong physics_state_fingerprint;
  ulong regional_maturation_offset;
  uint observation_count;
  uint body_count;
  uint joint_count;
  uint anatomical_muscle_count;
  uint muscle_count;
  uint physiology_count;
  uint object_slot_count;
  uint world_model_count;
  uint neuromodulator_count;
  uint drive_count;
  uint maximum_planning_horizon;
  uint fast_plasticity_count;
  uint workspace_capacity;
  uint workspace_dimension;
  uint active_cerebellar_count;
  uint actuator_count;
  uint active_sensing_count;
  uint reflex_state_count;
  uint fast_autonomic_state_count;
  uint event_capacity;
  uint option_candidate_capacity;
  uint procedural_trace_record_capacity;
  uint procedural_trace_phase_capacity;
  uint cerebellar_expert_capacity;
  uint vision_offset;
  uint vision_count;
  uint audition_offset;
  uint audition_count;
  uint proprioception_offset;
  uint proprioception_count;
  uint touch_offset;
  uint touch_count;
  uint vestibular_offset;
  uint vestibular_count;
  uint olfaction_offset;
  uint olfaction_count;
  uint gustation_offset;
  uint gustation_count;
  uint interoception_offset;
  uint interoception_count;
  uint module_count;
  uint plasticity_parameter_count;
  float belief_gain;
  float world_correction_gain;
  float cerebellar_learning_rate;
  float plasticity_learning_rate;
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

struct NBNeuromodulatorRecord {
  float value;
  float decay_time_constant_seconds;
  uint kind;
  uint flags;
};

struct NBDriveStateRecord {
  float level;
  float viable_minimum;
  float viable_maximum;
  float priority_weight;
  float estimated_rate;
  float deficit;
  float potential;
  uint kind;
};

struct NBFastPlasticityRecord {
  float coefficient;
  float eligibility;
  float coefficient_retention;
  float eligibility_retention;
  float learning_rate;
  float maximum_magnitude;
  ushort region_identifier;
  ushort basis_identifier;
  uint flags;
};

struct NBRegionalMaturationRecord {
  uint module_identifier;
  uint unlocked;
  float learning_rate_multiplier;
  float timescale_multiplier;
  float route_gain_multiplier;
  float conduction_delay_multiplier;
  float capacity_fraction;
  uint flags;
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

struct NBAcceptedActuatorDescriptor {
  uint actuator_identifier;
  uint command_kind;
  uint flags;
  uint reserved;
  float output_minimum;
  float output_maximum;
  float neutral_command;
  float emergency_command;
};

struct NBBodyReceptorBindingTableHeader {
  uint binding_count;
  uint body_count;
  ulong profile_fingerprint;
};

struct NBBodyReceptorBindingRange {
  uint binding_offset;
  uint binding_count;
};

struct NBBodyReceptorBindingRecord {
  uint body_identifier;
  uint signal;
  uint observation_scalar_index;
  uint flags;
  float scale;
  float bias;
  float weight;
  float reserved;
};

struct NBJointReceptorBindingTableHeader {
  uint binding_count;
  uint joint_count;
  ulong profile_fingerprint;
  ulong topology_fingerprint;
};

struct NBJointTopologyRecord {
  uint4 identifiers;
  float4 axes[6];
  float4 limits[6];
  float4 parent_local_anchor;
  float4 child_local_anchor;
  float4 rest_relative_orientation;
};

struct NBJointReceptorBindingRecord {
  uint joint_index;
  uint coordinate_slot;
  uint signal;
  uint observation_scalar_index;
  float scale;
  float bias;
  float weight;
  uint flags;
};

struct NBMuscleReceptorBindingTableHeader {
  uint binding_count;
  uint muscle_count;
  ulong profile_fingerprint;
  ulong attachment_fingerprint;
};

struct NBMuscleReceptorBindingRecord {
  uint muscle_index;
  uint signal;
  uint observation_scalar_index;
  uint flags;
  float scale;
  float bias;
  float weight;
  float reserved;
};

struct NBFastBodySchemaRecord {
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

struct NBFastReflexStateRecord {
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

struct NBFastAutonomicStateRecord {
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

struct NBAcceptedProtectiveCommandRecord {
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

struct NBProceduralTracePhase {
  ulong option_identifier;
  ulong start_timestamp_microseconds;
  ulong last_timestamp_microseconds;
  float duration_seconds;
  float mean_value;
  float maximum_damage;
  float mean_uncertainty;
  uint sample_count;
  uint parameter_count;
  float parameters[16];
};

struct NBProceduralExecutionTrace {
  ulong identifier;
  ulong goal_identifier;
  ulong plan_identifier;
  ulong start_timestamp_microseconds;
  ulong last_timestamp_microseconds;
  uint format_version;
  uint flags;
  uint phase_count;
  uint sample_count;
  float cumulative_value;
  float maximum_damage;
  float cumulative_effort;
  float mean_uncertainty;
  float final_progress;
  float reserved[13];
  NBProceduralTracePhase phases[8];
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

struct NBCerebellarExpertRecord {
  uint expert_identifier;
  uint flags;
  float weight;
  float prediction_error;
  ulong prediction_timestamp_microseconds;
  uint prediction_count;
  uint reserved;
  float state[56];
};

static_assert(sizeof(NBAcceptedConsequenceUniforms) == 432);
static_assert(sizeof(NBEventQueueHeader) == 32);
static_assert(sizeof(NBReceptorEventRecord) == 32);
static_assert(sizeof(NBNeuromodulatorRecord) == 16);
static_assert(sizeof(NBFastPlasticityRecord) == 32);
static_assert(sizeof(NBRegionalMaturationRecord) == 32);
static_assert(sizeof(NBWorkspaceMetadataRecord) == 96);
static_assert(sizeof(NBControlHeader) == 128);
static_assert(sizeof(NBActiveSensingCommandRecord) == 16);
static_assert(sizeof(NBActiveSensingEfficacyRecord) == 32);
static_assert(sizeof(NBObjectSlotRecord) == 512);
static_assert(sizeof(NBAcceptedActuatorDescriptor) == 32);
static_assert(sizeof(NBBodyReceptorBindingTableHeader) == 16);
static_assert(sizeof(NBBodyReceptorBindingRange) == 8);
static_assert(sizeof(NBBodyReceptorBindingRecord) == 32);
static_assert(sizeof(NBJointReceptorBindingTableHeader) == 24);
static_assert(sizeof(NBJointTopologyRecord) == 256);
static_assert(sizeof(NBJointReceptorBindingRecord) == 32);
static_assert(sizeof(NBMuscleReceptorBindingTableHeader) == 24);
static_assert(sizeof(NBMuscleReceptorBindingRecord) == 32);
static_assert(sizeof(NBFastBodySchemaRecord) == 48);
static_assert(sizeof(NBFastReflexStateRecord) == 128);
static_assert(sizeof(NBFastAutonomicStateRecord) == 64);
static_assert(sizeof(NBAcceptedProtectiveCommandRecord) == 64);
static_assert(sizeof(NBOptionCandidateRecord) == 128);
static_assert(sizeof(NBProceduralTracePhase) == 112);
static_assert(sizeof(NBProceduralExecutionTrace) == 1024);
static_assert(sizeof(NBMotorCommandRecord) == 32);
static_assert(sizeof(NBCerebellarExpertRecord) == 256);

/// Converts the exact accepted physical actuator command back into the
/// species-neutral causal feature used by body-effect and policy learning.
/// Muscle excitation remains [0, 1]; other actuators are signed around their
/// explicit physical neutral and preserve asymmetric ranges.
inline float nb_accepted_actuator_feature(
  const float physical_command,
  const NBAcceptedActuatorDescriptor actuator)
{
  if (actuator.command_kind == NB_ACCEPTED_ACTUATOR_MUSCLE_EXCITATION) {
    return clamp(
      (physical_command - actuator.output_minimum)
        / max(actuator.output_maximum - actuator.output_minimum, 1.0e-6f),
      0.0f,
      1.0f
    );
  }
  const float bounded_command = clamp(
    physical_command, actuator.output_minimum, actuator.output_maximum
  );
  if (bounded_command >= actuator.neutral_command) {
    return clamp(
      (bounded_command - actuator.neutral_command)
        / max(actuator.output_maximum - actuator.neutral_command, 1.0e-6f),
      0.0f,
      1.0f
    );
  }
  return -clamp(
    (actuator.neutral_command - bounded_command)
      / max(actuator.neutral_command - actuator.output_minimum, 1.0e-6f),
    0.0f,
    1.0f
  );
}

inline float nb_observation(
  device const float *observations,
  uint offset,
  uint count,
  uint index)
{
  return count == 0u ? 0.0f : observations[offset + index % count];
}

inline float nb_valid_observation(
  device const float *observations,
  device const uint *validity,
  uint offset,
  uint count,
  uint index,
  thread bool &is_valid)
{
  if (count == 0u) {
    is_valid = false;
    return 0.0f;
  }
  const uint scalar_index = offset + index % count;
  is_valid = validity[scalar_index] != 0u;
  return is_valid ? observations[scalar_index] : 0.0f;
}

inline float nb_observation_energy(
  device const float *observations,
  device const uint *validity,
  uint offset,
  uint count,
  uint seed,
  thread bool &has_evidence)
{
  has_evidence = false;
  if (count == 0u) return 0.0f;
  float energy = 0.0f;
  uint valid_count = 0u;
  for (uint sample = 0u; sample < 8u; ++sample) {
    bool sample_valid = false;
    const float observed = nb_valid_observation(
      observations, validity, offset, count,
      seed * 17u + sample * 29u, sample_valid
    );
    if (!sample_valid) continue;
    energy += abs(observed);
    valid_count += 1u;
  }
  has_evidence = valid_count > 0u;
  return has_evidence ? clamp(energy / float(valid_count), 0.0f, 1.0f)
    : 0.0f;
}

inline float nb_physical_alpha(float elapsed_seconds, float time_constant_seconds) {
  return clamp(
    1.0f - exp(-max(elapsed_seconds, 0.0f)
      / max(time_constant_seconds, 1.0e-4f)),
    0.0f,
    1.0f
  );
}

/// Estimates the selected object's accepted epistemic posterior from the exact
/// receptor buffer without mutating its slot ahead of the next cognitive tick.
/// This lets sensing efficacy learn from the committed physical consequence
/// while preserving the normal entity-posterior ownership boundary.
inline float nb_selected_object_accepted_uncertainty(
  device const uchar *hot_state,
  constant NBAcceptedConsequenceUniforms &uniforms,
  device const float *belief_parameters,
  uint one_based_slot)
{
  if (one_based_slot == 0u || one_based_slot > uniforms.object_slot_count
      || uniforms.vision_count == 0u) return 1.0f;
  device const NBObjectSlotRecord *objects =
    reinterpret_cast<device const NBObjectSlotRecord *>(
      hot_state + uniforms.object_slot_offset
    );
  const NBObjectSlotRecord object = objects[one_based_slot - 1u];
  if (object.identifier == 0ul || object.existence_probability <= 0.0f) {
    return 1.0f;
  }
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  device const uint *validity = reinterpret_cast<device const uint *>(
    hot_state + uniforms.observation_validity_offset
  );
  const uint seed = (one_based_slot - 1u) * 23u + 3u;
  bool has_visual_energy = false;
  const float visual_presence = clamp(
    (nb_observation_energy(
      observations, validity, uniforms.vision_offset, uniforms.vision_count,
      seed, has_visual_energy
    ) - max(belief_parameters[4], 0.0f))
      * max(4.0f * belief_parameters[3], 0.25f),
    0.0f,
    1.0f
  );
  if (!has_visual_energy) return 1.0f;
  const float elapsed_seconds = max(
    float(uniforms.delta_microseconds) * 1.0e-6f, 1.0e-6f
  );
  float pose_difference = 0.0f;
  uint valid_pose_components = 0u;
  for (uint component = 0u; component < 4u; ++component) {
    bool pose_valid = false;
    const float observed_pose = nb_valid_observation(
      observations, validity,
      uniforms.vision_offset,
      uniforms.vision_count,
      seed * 11u + component * 31u,
      pose_valid
    );
    if (!pose_valid) continue;
    const float predicted_pose = object.pose[component]
      + object.velocity[component] * elapsed_seconds;
    pose_difference += abs(observed_pose - predicted_pose);
    valid_pose_components += 1u;
  }
  if (valid_pose_components == 0u) return 1.0f;
  pose_difference /= float(valid_pose_components);
  const float association_likelihood = exp(
    -max(0.5f, 4.0f * max(belief_parameters[3], 0.0f))
      * (1.0f - 0.75f * clamp(object.uncertainty, 0.0f, 1.0f))
      * pose_difference
  );
  const float assigned_evidence = visual_presence * association_likelihood;
  const float retained_per_second = clamp(belief_parameters[7], 0.0f, 1.0f);
  const float retention = retained_per_second <= 0.0f ? 0.0f
    : (retained_per_second >= 1.0f ? 1.0f
      : pow(retained_per_second, elapsed_seconds));
  const float correction_gain = clamp(belief_parameters[0], 0.001f, 1.0f);
  const float identity_confidence = clamp(mix(
    retention * object.identity_confidence,
    association_likelihood,
    correction_gain * assigned_evidence
  ), 0.0f, 1.0f);
  return clamp(mix(
    min(1.0f, object.uncertainty + (1.0f - retention)),
    1.0f - identity_confidence,
    correction_gain * assigned_evidence
  ), 0.0f, 1.0f);
}

inline float nb_world_observation(
  device const float *observations,
  device const uint *validity,
  constant NBAcceptedConsequenceUniforms &uniforms,
  uint world_index,
  thread bool &is_valid)
{
  uint local_index = world_index;
  uint offset = uniforms.vision_offset;
  uint count = uniforms.vision_count;
  if (world_index >= 32u) {
    local_index = world_index - 32u;
    offset = uniforms.audition_offset;
    count = uniforms.audition_count;
  }
  if (world_index >= 48u) {
    local_index = world_index - 48u;
    offset = uniforms.touch_offset;
    count = uniforms.touch_count;
  }
  if (world_index >= 64u) {
    local_index = world_index - 64u;
    offset = uniforms.proprioception_offset;
    count = uniforms.proprioception_count;
  }
  if (world_index >= 80u) {
    local_index = world_index - 80u;
    offset = uniforms.vestibular_offset;
    count = uniforms.vestibular_count;
  }
  if (world_index >= 96u) {
    local_index = world_index - 96u;
    offset = uniforms.olfaction_offset;
    count = uniforms.olfaction_count;
  }
  if (world_index >= 108u) {
    local_index = world_index - 108u;
    offset = uniforms.gustation_offset;
    count = uniforms.gustation_count;
  }
  if (world_index >= 116u) {
    local_index = world_index - 116u;
    offset = uniforms.interoception_offset;
    count = uniforms.interoception_count;
  }
  return nb_valid_observation(
    observations, validity, offset, count, local_index, is_valid
  );
}

inline float nb_mean_prediction_error(
  device const float *observations,
  device const uint *validity,
  device const float *world,
  constant NBAcceptedConsequenceUniforms &uniforms)
{
  const bool structured_world_available = uniforms.world_model_count
    >= 9u * NB_WORLD_RECEPTOR_DIMENSION;
  const uint sample_count = structured_world_available
    ? (uniforms.observation_count > 0u ? NB_WORLD_RECEPTOR_DIMENSION : 0u)
    : min(
        min(uniforms.observation_count, uniforms.world_model_count),
        256u
      );
  if (sample_count == 0u) return 0.0f;
  float total = 0.0f;
  uint valid_count = 0u;
  for (uint index = 0u; index < sample_count; ++index) {
    float prediction = world[index];
    if (structured_world_available) {
      prediction = 0.0f;
      for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
        prediction += world[
          (3u + head) * NB_WORLD_RECEPTOR_DIMENSION + index
        ] / float(NB_WORLD_HEAD_COUNT);
      }
    }
    bool observation_valid = false;
    const float observed = structured_world_available
      ? nb_world_observation(
          observations, validity, uniforms, index, observation_valid
        )
      : nb_valid_observation(
          observations, validity, 0u, uniforms.observation_count, index,
          observation_valid
        );
    if (!observation_valid) continue;
    total += abs(observed - prediction);
    valid_count += 1u;
  }
  return valid_count > 0u ? total / float(valid_count) : 0.0f;
}

inline float nb_mean_sensorimotor_prediction_error(
  device const float *world,
  uint world_count)
{
  const uint required_count = NB_WORLD_SENSORIMOTOR_BASE
    + 9u * NB_WORLD_SENSORIMOTOR_DIMENSION;
  if (world_count < required_count) return 0.0f;
  float total = 0.0f;
  const uint error_base = NB_WORLD_SENSORIMOTOR_BASE
    + NB_WORLD_SENSORIMOTOR_DIMENSION;
  for (uint index = 0u; index < NB_WORLD_SENSORIMOTOR_DIMENSION; ++index) {
    total += abs(world[error_base + index]);
  }
  return total / float(NB_WORLD_SENSORIMOTOR_DIMENSION);
}

inline float nb_mean_epistemic_disagreement(
  device const float *world,
  uint world_count)
{
  if (world_count < 9u * NB_WORLD_RECEPTOR_DIMENSION) return 0.0f;
  float total_variance = 0.0f;
  for (uint index = 0u; index < NB_WORLD_RECEPTOR_DIMENSION; ++index) {
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
  return sqrt(total_variance / float(NB_WORLD_RECEPTOR_DIMENSION));
}

inline float nb_mean_aleatoric_uncertainty(
  device const float *world,
  uint world_count)
{
  if (world_count < 9u * NB_WORLD_RECEPTOR_DIMENSION) return 0.0f;
  float total = 0.0f;
  for (uint index = 0u; index < NB_WORLD_RECEPTOR_DIMENSION; ++index) {
    total += max(world[8u * NB_WORLD_RECEPTOR_DIMENSION + index], 0.0f);
  }
  return sqrt(total / float(NB_WORLD_RECEPTOR_DIMENSION));
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

inline float nb_modality_aleatoric_uncertainty(
  device const float *world,
  uint world_count,
  uint modality)
{
  if (world_count < 9u * NB_WORLD_RECEPTOR_DIMENSION) return 1.0f;
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
  float total = 0.0f;
  for (uint index = begin; index < end; ++index) {
    total += max(world[8u * NB_WORLD_RECEPTOR_DIMENSION + index], 0.0f);
  }
  return sqrt(total / float(max(end - begin, 1u)));
}

inline float nb_body_schema_epistemic_uncertainty(
  device const uchar *hot_state,
  constant NBAcceptedConsequenceUniforms &uniforms)
{
  float uncertainty = 0.0f;
  for (uint body_index = 0u; body_index < uniforms.body_count; ++body_index) {
    device const float *body = reinterpret_cast<device const float *>(
      hot_state + uniforms.body_belief_offset + ulong(body_index) * 256ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      body + NB_BODY_IDENTITY_FLOAT_OFFSET
    );
    if ((identity[3] & 1ul) == 0ul
        || !isfinite(body[NB_BODY_LOAD_VARIANCE])) continue;
    const float standard_deviation = sqrt(max(
      body[NB_BODY_LOAD_VARIANCE], 0.0f
    ));
    uncertainty = max(
      uncertainty,
      standard_deviation / (1.0f + standard_deviation)
    );
  }
  return uncertainty;
}

inline float nb_body_sensorimotor_feature(
  device const float *body,
  uint feature)
{
  const float value = body[feature];
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
      || feature == NB_BODY_PAIN || feature == NB_BODY_VULNERABILITY
      || feature == NB_BODY_REACHABILITY || feature == NB_BODY_OWNERSHIP
      || feature == NB_BODY_DAMAGE_RISK
      || feature == NB_BODY_EXTERNAL_DISTURBANCE) {
    return clamp(value, 0.0f, 1.0f);
  }
  return value / (1.0f + abs(value));
}

inline float nb_body_sensorimotor_projection(
  device const uchar *hot_state,
  constant NBAcceptedConsequenceUniforms &uniforms,
  uint component,
  thread bool &has_evidence)
{
  has_evidence = false;
  if (uniforms.body_count == 0u) return 0.0f;
  const uint body_index = min(
    uint((ulong(component) * ulong(uniforms.body_count))
      / ulong(NB_WORLD_SENSORIMOTOR_DIMENSION)),
    uniforms.body_count - 1u
  );
  const uint projection = component;
  device const float *body = reinterpret_cast<device const float *>(
    hot_state + uniforms.body_belief_offset + ulong(body_index) * 256ul
  );
  device const ulong *identity = reinterpret_cast<device const ulong *>(
    body + NB_BODY_IDENTITY_FLOAT_OFFSET
  );
  if ((identity[3] & NB_ACCEPTED_STATE_VALID) == 0ul) return 0.0f;
  float total = 0.0f;
  uint finite_count = 0u;
  for (uint feature = 0u; feature < NB_BODY_SENSORIMOTOR_FEATURE_COUNT;
      ++feature) {
    if (!isfinite(body[feature])) continue;
    uint hash = (feature + 1u) * 0x9e3779b9u
      ^ (projection + 1u) * 0x85ebca6bu
      ^ (body_index + 1u) * 0xc2b2ae35u;
    hash ^= hash >> 16u;
    const float sign = (hash & 1u) == 0u ? -1.0f : 1.0f;
    total += sign * nb_body_sensorimotor_feature(body, feature);
    finite_count += 1u;
  }
  has_evidence = finite_count > 0u;
  return has_evidence ? clamp(
    total * rsqrt(float(finite_count)), -1.0f, 1.0f
  ) : 0.0f;
}

kernel void assimilate_accepted_body_and_physiology(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *belief_parameters [[buffer(2)]],
  device const NBAcceptedActuatorDescriptor *actuator_descriptors
    [[buffer(6)]],
  device const NBBodyReceptorBindingTableHeader *body_receptor_table
    [[buffer(9)]],
  uint gid [[thread_position_in_grid]])
{
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  device const uint *validity = reinterpret_cast<device const uint *>(
    hot_state + uniforms.observation_validity_offset
  );
  const float gain = clamp(
    min(uniforms.belief_gain, max(belief_parameters[0], 0.0f)), 0.0f, 1.0f
  );
  const float velocity_gain = min(gain, max(belief_parameters[1], 0.0f));
  const float contact_gain = min(gain, max(belief_parameters[2], 0.0f));
  const float physiology_gain = min(gain, max(belief_parameters[3], 0.0f));
  const float elapsed_seconds = max(
    float(uniforms.delta_microseconds) * 1.0e-6f, 1.0e-6f
  );
  const float body_time_constant = max(belief_parameters[8], 1.0e-4f);
  const float body_gain = min(
    gain, nb_physical_alpha(elapsed_seconds, body_time_constant)
  );
  if (gid < uniforms.body_count) {
    device float *body = reinterpret_cast<device float *>(
      hot_state + uniforms.body_belief_offset + ulong(gid) * 256ul
    );
    device ulong *identity = reinterpret_cast<device ulong *>(
      body + NB_BODY_IDENTITY_FLOAT_OFFSET
    );
    const bool prior_valid =
      (identity[3] & NB_ACCEPTED_STATE_VALID) != 0ul;
    float position_total[3] = {0.0f, 0.0f, 0.0f};
    float position_weight[3] = {0.0f, 0.0f, 0.0f};
    float velocity_total[3] = {0.0f, 0.0f, 0.0f};
    float velocity_weight[3] = {0.0f, 0.0f, 0.0f};
    float orientation_total[4] = {0.0f, 0.0f, 0.0f, 0.0f};
    float orientation_weight[4] = {0.0f, 0.0f, 0.0f, 0.0f};
    float angular_velocity_total[3] = {0.0f, 0.0f, 0.0f};
    float angular_velocity_weight[3] = {0.0f, 0.0f, 0.0f};
    float position_variance_total[3] = {0.0f, 0.0f, 0.0f};
    float position_variance_weight[3] = {0.0f, 0.0f, 0.0f};
    float orientation_variance_total[3] = {0.0f, 0.0f, 0.0f};
    float orientation_variance_weight[3] = {0.0f, 0.0f, 0.0f};
    float contact_total = 0.0f;
    float contact_weight = 0.0f;
    float support_total = 0.0f;
    float support_weight = 0.0f;
    float force_total[3] = {0.0f, 0.0f, 0.0f};
    float force_weight[3] = {0.0f, 0.0f, 0.0f};
    float pain_total = 0.0f;
    float pain_weight = 0.0f;
    float vestibular_total = 0.0f;
    float vestibular_weight = 0.0f;
    device const NBBodyReceptorBindingRange *body_receptor_ranges =
      reinterpret_cast<device const NBBodyReceptorBindingRange *>(
        body_receptor_table + 1
      );
    device const NBBodyReceptorBindingRecord *body_receptor_bindings =
      reinterpret_cast<device const NBBodyReceptorBindingRecord *>(
        body_receptor_ranges + body_receptor_table->body_count
      );
    const NBBodyReceptorBindingRange body_receptor_range =
      gid < body_receptor_table->body_count
        ? body_receptor_ranges[gid] : NBBodyReceptorBindingRange{0u, 0u};
    const uint binding_end = min(
      body_receptor_range.binding_offset + body_receptor_range.binding_count,
      body_receptor_table->binding_count
    );
    for (uint binding_index = body_receptor_range.binding_offset;
        binding_index < binding_end; ++binding_index) {
      const NBBodyReceptorBindingRecord binding =
        body_receptor_bindings[binding_index];
      if ((binding.flags & NB_ACCEPTED_STATE_VALID) == 0u
          || binding.body_identifier != gid
          || binding.observation_scalar_index >= uniforms.observation_count
          || validity[binding.observation_scalar_index] == 0u
          || !isfinite(binding.scale) || !isfinite(binding.bias)
          || !isfinite(binding.weight) || binding.weight <= 0.0f) continue;
      const float evidence = fma(
        observations[binding.observation_scalar_index],
        binding.scale,
        binding.bias
      );
      const uint component = (binding.flags >> 16u) & 0xffffu;
      switch (binding.signal) {
        case 1u:
          if (component < 3u) {
            position_total[component] += evidence * binding.weight;
            position_weight[component] += binding.weight;
          }
          break;
        case 2u:
          if (component < 3u) {
            velocity_total[component] += evidence * binding.weight;
            velocity_weight[component] += binding.weight;
          }
          break;
        case 3u:
          contact_total += clamp(evidence, 0.0f, 1.0f) * binding.weight;
          contact_weight += binding.weight;
          break;
        case 4u:
          support_total += clamp(evidence, 0.0f, 1.0f) * binding.weight;
          support_weight += binding.weight;
          break;
        case 5u:
          if (component < 3u) {
            force_total[component] += evidence * binding.weight;
            force_weight[component] += binding.weight;
          }
          break;
        case 6u:
          pain_total += clamp(evidence, 0.0f, 1.0f) * binding.weight;
          pain_weight += binding.weight;
          break;
        case 7u:
          vestibular_total += clamp(evidence, 0.0f, 1.0f)
            * binding.weight;
          vestibular_weight += binding.weight;
          break;
        case 8u:
          if (component < 4u) {
            orientation_total[component] += evidence * binding.weight;
            orientation_weight[component] += binding.weight;
          }
          break;
        case 9u:
          if (component < 3u) {
            angular_velocity_total[component] += evidence * binding.weight;
            angular_velocity_weight[component] += binding.weight;
          }
          break;
        case 10u:
          if (component < 3u) {
            position_variance_total[component] += max(evidence, 0.0f)
              * binding.weight;
            position_variance_weight[component] += binding.weight;
          }
          break;
        case 11u:
          if (component < 3u) {
            orientation_variance_total[component] += max(evidence, 0.0f)
              * binding.weight;
            orientation_variance_weight[component] += binding.weight;
          }
          break;
        default:
          break;
      }
    }
    const bool has_current_body_evidence =
      contact_weight > 0.0f || support_weight > 0.0f
      || pain_weight > 0.0f || vestibular_weight > 0.0f
      || any(float3(position_weight[0], position_weight[1], position_weight[2])
        > 0.0f)
      || any(float3(velocity_weight[0], velocity_weight[1], velocity_weight[2])
        > 0.0f)
      || any(float4(
          orientation_weight[0], orientation_weight[1],
          orientation_weight[2], orientation_weight[3]
        ) > 0.0f)
      || any(float3(
          angular_velocity_weight[0], angular_velocity_weight[1],
          angular_velocity_weight[2]
        ) > 0.0f)
      || any(float3(force_weight[0], force_weight[1], force_weight[2]) > 0.0f)
      || any(float3(
          position_variance_weight[0], position_variance_weight[1],
          position_variance_weight[2]
        ) > 0.0f)
      || any(float3(
          orientation_variance_weight[0], orientation_variance_weight[1],
          orientation_variance_weight[2]
        ) > 0.0f);
    if (prior_valid || has_current_body_evidence) {
      const float contact_evidence = contact_weight > 0.0f
        ? contact_total / contact_weight
        : body[NB_BODY_CONTACT];
      const float velocity_limit = max(belief_parameters[13], 1.0f);
      const float support_evidence = support_weight > 0.0f
        ? support_total / support_weight
        : (vestibular_weight > 0.0f
          ? vestibular_total / vestibular_weight
          : body[NB_BODY_SUPPORT]);
      const float pain_evidence = pain_weight > 0.0f
        ? pain_total / pain_weight
        : 0.0f;
      const float retained_per_second = clamp(
        belief_parameters[7], 0.0f, 1.0f
      );
      const float pain_retention = retained_per_second <= 0.0f ? 0.0f
        : (retained_per_second >= 1.0f ? 1.0f
          : pow(retained_per_second, elapsed_seconds));
      float maximum_proprioceptive_error = 0.0f;
      for (uint component = 0u; component < 3u; ++component) {
        const float prior_position = body[NB_BODY_POSITION + component];
        const float position_evidence = position_weight[component] > 0.0f
          ? position_total[component] / position_weight[component]
          : prior_position;
        const float observed_velocity = clamp(
          velocity_weight[component] > 0.0f
            ? velocity_total[component] / velocity_weight[component]
            : (position_evidence - prior_position) / elapsed_seconds,
          -velocity_limit,
          velocity_limit
        );
        const float corrected_position = mix(
          prior_position, position_evidence, body_gain
        );
        const float corrected_velocity = mix(
          body[NB_BODY_LINEAR_VELOCITY + component],
          observed_velocity,
          min(velocity_gain, body_gain)
        );
        body[NB_BODY_POSITION + component] = corrected_position;
        body[NB_BODY_LINEAR_VELOCITY + component] = corrected_velocity;
        const float position_residual = position_evidence - corrected_position;
        const float prior_variance = prior_valid
          ? max(body[NB_BODY_POSITION_VARIANCE + component], 0.0f) : 1.0f;
        const bool has_position_evidence = position_weight[component] > 0.0f;
        const float variance_evidence =
          position_variance_weight[component] > 0.0f
          ? position_variance_total[component]
            / position_variance_weight[component]
          : (has_position_evidence
            ? position_residual * position_residual : prior_variance);
        body[NB_BODY_POSITION_VARIANCE + component] = max(mix(
          prior_variance, variance_evidence, body_gain
        ), 0.0f);
        maximum_proprioceptive_error = max(
          maximum_proprioceptive_error,
          abs(observed_velocity - corrected_velocity)
        );
        const float angular_target = angular_velocity_weight[component] > 0.0f
          ? angular_velocity_total[component]
            / angular_velocity_weight[component]
          : body[NB_BODY_ANGULAR_VELOCITY + component];
        body[NB_BODY_ANGULAR_VELOCITY + component] = mix(
          body[NB_BODY_ANGULAR_VELOCITY + component],
          angular_target,
          body_gain
        );
        const float prior_orientation_variance = prior_valid
          ? max(body[NB_BODY_ORIENTATION_VARIANCE + component], 0.0f) : 1.0f;
        const float orientation_variance_evidence =
          orientation_variance_weight[component] > 0.0f
          ? orientation_variance_total[component]
            / orientation_variance_weight[component]
          : prior_orientation_variance;
        body[NB_BODY_ORIENTATION_VARIANCE + component] = max(mix(
          prior_orientation_variance,
          orientation_variance_evidence,
          body_gain
        ), 0.0f);
        const float force_evidence = force_weight[component] > 0.0f
          ? force_total[component] / force_weight[component]
          : body[NB_BODY_LOCAL_FORCE + component];
        body[NB_BODY_LOCAL_FORCE + component] = mix(
          body[NB_BODY_LOCAL_FORCE + component], force_evidence, body_gain
        );
      }
      float4 prior_orientation = prior_valid
        ? float4(
          body[NB_BODY_ORIENTATION],
          body[NB_BODY_ORIENTATION + 1u],
          body[NB_BODY_ORIENTATION + 2u],
          body[NB_BODY_ORIENTATION + 3u]
        )
        : float4(0.0f, 0.0f, 0.0f, 1.0f);
      if (length_squared(prior_orientation) <= 1.0e-8f) {
        prior_orientation = float4(0.0f, 0.0f, 0.0f, 1.0f);
      } else {
        prior_orientation = normalize(prior_orientation);
      }
      float4 orientation_evidence = prior_orientation;
      bool has_orientation_evidence = false;
      for (uint component = 0u; component < 4u; ++component) {
        if (orientation_weight[component] <= 0.0f) continue;
        orientation_evidence[component] = orientation_total[component]
          / orientation_weight[component];
        has_orientation_evidence = true;
      }
      if (has_orientation_evidence
          && length_squared(orientation_evidence) > 1.0e-8f) {
        orientation_evidence = normalize(orientation_evidence);
      } else {
        orientation_evidence = prior_orientation;
      }
      float4 corrected_orientation = mix(
        prior_orientation, orientation_evidence, body_gain
      );
      corrected_orientation = length_squared(corrected_orientation) > 1.0e-8f
        ? normalize(corrected_orientation) : prior_orientation;
      for (uint component = 0u; component < 4u; ++component) {
        body[NB_BODY_ORIENTATION + component] = corrected_orientation[component];
      }
      body[NB_BODY_CONTACT] = mix(
        body[NB_BODY_CONTACT], contact_evidence, min(contact_gain, body_gain)
      );
      body[NB_BODY_SUPPORT] = mix(
        body[NB_BODY_SUPPORT],
        support_evidence,
        body_gain
      );
      body[NB_BODY_PAIN] = max(
        body[NB_BODY_PAIN] * pain_retention,
        pain_evidence
      );
      body[NB_BODY_PROPRIOCEPTIVE_ERROR] = maximum_proprioceptive_error;
      identity[0] = ulong(gid);
      identity[1] = uniforms.target_timestamp_microseconds;
      identity[2] = uniforms.physics_state_fingerprint;
      identity[3] = NB_ACCEPTED_STATE_VALID;
    }
  }
  if (gid < uniforms.muscle_count) {
    device float *muscle = reinterpret_cast<device float *>(
      hot_state + uniforms.muscle_belief_offset + ulong(gid) * 192ul
    );
    device float *somatic = reinterpret_cast<device float *>(
      hot_state + uniforms.somatic_output_offset
    );
    device const float *accepted_somatic =
      reinterpret_cast<device const float *>(
        hot_state + uniforms.accepted_somatic_output_offset
      );
    device ulong *effector_identity = reinterpret_cast<device ulong *>(
      muscle + 16
    );
    const bool anatomical_muscle = gid < uniforms.anatomical_muscle_count;
    bool proprioception_valid = anatomical_muscle
      && effector_identity[1] == uniforms.target_timestamp_microseconds
      && (effector_identity[3]
        & ulong(NB_ACCEPTED_MUSCLE_LENGTH_VALID)) != 0ul;
    float sensed_proprioception = muscle[1];
    if (!anatomical_muscle) {
      sensed_proprioception = nb_valid_observation(
        observations, validity, uniforms.proprioception_offset,
        uniforms.proprioception_count, gid, proprioception_valid
      );
    }
    const uint actuator_index = gid % max(uniforms.actuator_count, 1u);
    const NBAcceptedActuatorDescriptor actuator =
      actuator_descriptors[actuator_index];
    const float physical_command = uniforms.actuator_count == 0u
      ? 0.0f : accepted_somatic[actuator_index];
    const float command = uniforms.actuator_count == 0u
      || (actuator.flags & NB_ACCEPTED_STATE_VALID) == 0u
      ? 0.0f
      : nb_accepted_actuator_feature(physical_command, actuator);
    if (gid < uniforms.actuator_count) {
      // Committed transition records consume this exact accepted action
      // feature after consequence assimilation, never the rejected decision.
      somatic[gid] = command;
    }
    const float prior_proprioception = anatomical_muscle
      ? muscle[12] : muscle[1];
    const float proprioception = proprioception_valid
      ? sensed_proprioception : prior_proprioception;
    const float observed_delta = proprioception - prior_proprioception;
    const float effect_learning_rate = proprioception_valid
      ? clamp(
          min(gain, max(belief_parameters[4], 0.0f)), 0.0f, 1.0f
        ) : 0.0f;
    const float prior_effect_gain = muscle[6];
    const float prior_effect_bias = muscle[7];
    const float predicted_delta = fma(
      prior_effect_gain, command, prior_effect_bias
    );
    const float effect_error = proprioception_valid
      ? observed_delta - predicted_delta : muscle[5];
    const float normalized_command_energy = fma(command, command, 1.0e-4f);
    const float effect_limit = max(belief_parameters[6], 1.0f);
    const float learned_effect_gain = clamp(
      prior_effect_gain
        + effect_learning_rate * command * effect_error
          / normalized_command_energy,
      -effect_limit,
      effect_limit
    );
    const float learned_effect_bias = clamp(
      prior_effect_bias + 0.25f * effect_learning_rate * effect_error,
      -effect_limit,
      effect_limit
    );
    const float agency_error_scale = max(belief_parameters[5], 1.0f);
    const float agency_measurement = 1.0f
      / (1.0f + agency_error_scale * abs(effect_error));
    const float causal_evidence = clamp(
      proprioception_valid ? abs(command)
        + abs(observed_delta) * max(belief_parameters[14], 0.0f)
        : 0.0f,
      0.0f,
      1.0f
    );
    const float state_retained_per_second = clamp(
      belief_parameters[7], 0.0f, 1.0f
    );
    const float state_retention = state_retained_per_second <= 0.0f ? 0.0f
      : (state_retained_per_second >= 1.0f ? 1.0f
        : pow(state_retained_per_second, elapsed_seconds));
    const float agency_update_gain = clamp(
      effect_learning_rate * causal_evidence, 0.0f, 1.0f
    );
    const float agency_confidence = clamp(mix(
      clamp(muscle[8], 0.0f, 1.0f) * state_retention,
      agency_measurement,
      agency_update_gain
    ), 0.0f, 1.0f);
    const float disturbance_measurement = clamp(
      abs(effect_error) * (1.0f - agency_measurement)
        * max(belief_parameters[14], 0.0f),
      0.0f,
      1.0f
    );
    const float external_disturbance = clamp(mix(
      clamp(muscle[9], 0.0f, 1.0f) * state_retention,
      disturbance_measurement,
      agency_update_gain
    ), 0.0f, 1.0f);
    muscle[0] = mix(muscle[0], command, gain);
    if (!anatomical_muscle) {
      muscle[1] = mix(muscle[1], proprioception, gain);
      muscle[2] = proprioception_valid
        ? observed_delta : muscle[2] * state_retention;
      muscle[3] = proprioception_valid
        ? mix(muscle[3], abs(proprioception), gain) : muscle[3];
      muscle[4] = clamp(
        muscle[4]
          + elapsed_seconds * (
            max(belief_parameters[11], 0.0f) * abs(command)
              - max(belief_parameters[12], 0.0f) * (1.0f - abs(command))
          ),
        0.0f,
        1.0f
      );
    }
    muscle[5] = effect_error;
    muscle[6] = learned_effect_gain;
    muscle[7] = learned_effect_bias;
    muscle[8] = agency_confidence;
    muscle[9] = external_disturbance;
    muscle[10] = predicted_delta;
    muscle[11] = command;
    effector_identity[0] = ulong(actuator.actuator_identifier);
    effector_identity[1] = uniforms.target_timestamp_microseconds;
    if (!anatomical_muscle) {
      effector_identity[2] = 0ul;
      effector_identity[3] = NB_ACCEPTED_STATE_VALID;
      effector_identity[4] = uniforms.physics_state_fingerprint;
    }
    effector_identity[5] = ulong(actuator.actuator_identifier);
    effector_identity[6] = ulong(actuator.command_kind);
  }
  if (gid < uniforms.physiology_count) {
    device float *physiology = reinterpret_cast<device float *>(
      hot_state + uniforms.physiology_offset
    );
    bool interoception_valid = false;
    const float interoception = nb_valid_observation(
      observations, validity, uniforms.interoception_offset,
      uniforms.interoception_count, gid, interoception_valid
    );
    if (interoception_valid) {
      physiology[gid] = mix(physiology[gid], interoception, physiology_gain);
    }
  }
}

/// Fuses NumanX muscle length, velocity, tendon force, and fatigue receptors
/// into the biological muscle graph before causal command-effect learning.
kernel void assimilate_accepted_muscle_schema(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *belief_parameters [[buffer(2)]],
  device const NBMuscleReceptorBindingTableHeader *muscle_receptor_table
    [[buffer(11)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.anatomical_muscle_count
      || gid >= muscle_receptor_table->muscle_count) return;
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  device const uint *validity = reinterpret_cast<device const uint *>(
    hot_state + uniforms.observation_validity_offset
  );
  device const NBBodyReceptorBindingRange *ranges =
    reinterpret_cast<device const NBBodyReceptorBindingRange *>(
      muscle_receptor_table + 1
    );
  device const NBMuscleReceptorBindingRecord *bindings =
    reinterpret_cast<device const NBMuscleReceptorBindingRecord *>(
      ranges + muscle_receptor_table->muscle_count
    );
  const NBBodyReceptorBindingRange range = ranges[gid];
  const uint binding_end = min(
    range.binding_offset + range.binding_count,
    muscle_receptor_table->binding_count
  );
  float totals[4] = {0.0f, 0.0f, 0.0f, 0.0f};
  float weights[4] = {0.0f, 0.0f, 0.0f, 0.0f};
  for (uint binding_index = range.binding_offset;
      binding_index < binding_end; ++binding_index) {
    const NBMuscleReceptorBindingRecord binding = bindings[binding_index];
    if ((binding.flags & NB_ACCEPTED_STATE_VALID) == 0u
        || binding.muscle_index != gid || binding.signal == 0u
        || binding.signal > 4u
        || binding.observation_scalar_index >= uniforms.observation_count
        || validity[binding.observation_scalar_index] == 0u
        || !isfinite(binding.scale) || !isfinite(binding.bias)
        || !isfinite(binding.weight) || binding.weight <= 0.0f) continue;
    const float evidence = fma(
      observations[binding.observation_scalar_index],
      binding.scale,
      binding.bias
    );
    if (!isfinite(evidence)) continue;
    const uint slot = binding.signal - 1u;
    totals[slot] += evidence * binding.weight;
    weights[slot] += binding.weight;
  }
  uint flags = 0u;
  if (weights[0] > 0.0f) flags |= NB_ACCEPTED_MUSCLE_LENGTH_VALID;
  if (weights[1] > 0.0f) flags |= NB_ACCEPTED_MUSCLE_VELOCITY_VALID;
  if (weights[2] > 0.0f) flags |= NB_ACCEPTED_MUSCLE_FORCE_VALID;
  if (weights[3] > 0.0f) flags |= NB_ACCEPTED_MUSCLE_FATIGUE_VALID;
  if (flags == 0u) return;
  flags |= NB_ACCEPTED_STATE_VALID;
  device float *muscle = reinterpret_cast<device float *>(
    hot_state + uniforms.muscle_belief_offset + ulong(gid) * 192ul
  );
  device ulong *identity = reinterpret_cast<device ulong *>(muscle + 16u);
  const bool prior_valid = (identity[3] & ulong(NB_ACCEPTED_STATE_VALID)) != 0ul;
  muscle[12] = prior_valid ? muscle[1] : 0.0f;
  const float elapsed_seconds = max(
    float(uniforms.delta_microseconds) * 1.0e-6f, 1.0e-6f
  );
  const float gain = clamp(min(
    uniforms.belief_gain,
    nb_physical_alpha(elapsed_seconds, max(belief_parameters[8], 1.0e-4f))
  ), 0.0f, 1.0f);
  if (weights[0] > 0.0f) {
    muscle[1] = mix(
      prior_valid ? muscle[1] : totals[0] / weights[0],
      totals[0] / weights[0],
      gain
    );
  }
  if (weights[1] > 0.0f) {
    muscle[2] = mix(
      prior_valid ? muscle[2] : totals[1] / weights[1],
      totals[1] / weights[1],
      gain
    );
  }
  if (weights[2] > 0.0f) {
    muscle[3] = max(mix(
      prior_valid ? muscle[3] : totals[2] / weights[2],
      totals[2] / weights[2],
      gain
    ), 0.0f);
  }
  if (weights[3] > 0.0f) {
    muscle[4] = clamp(mix(
      prior_valid ? muscle[4] : totals[3] / weights[3],
      totals[3] / weights[3],
      gain
    ), 0.0f, 1.0f);
  }
  identity[1] = uniforms.target_timestamp_microseconds;
  identity[2] = muscle_receptor_table->attachment_fingerprint;
  identity[3] = ulong(flags);
  identity[4] = uniforms.physics_state_fingerprint;
}

/// Fuses only valid causal proprioceptors into the articulated joint
/// posterior. The topology table is immutable and content addressed; the
/// posterior remains inside the current shadow generation until root commit.
kernel void assimilate_accepted_joint_schema(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *belief_parameters [[buffer(2)]],
  device const NBJointReceptorBindingTableHeader *joint_receptor_table
    [[buffer(10)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.joint_count
      || gid >= joint_receptor_table->joint_count) return;
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  device const uint *validity = reinterpret_cast<device const uint *>(
    hot_state + uniforms.observation_validity_offset
  );
  device const NBJointTopologyRecord *topologies =
    reinterpret_cast<device const NBJointTopologyRecord *>(
      joint_receptor_table + 1
    );
  device const NBBodyReceptorBindingRange *ranges =
    reinterpret_cast<device const NBBodyReceptorBindingRange *>(
      topologies + joint_receptor_table->joint_count
    );
  device const NBJointReceptorBindingRecord *bindings =
    reinterpret_cast<device const NBJointReceptorBindingRecord *>(
      ranges + joint_receptor_table->joint_count
    );
  const NBJointTopologyRecord topology = topologies[gid];
  const NBBodyReceptorBindingRange range = ranges[gid];
  const uint binding_end = min(
    range.binding_offset + range.binding_count,
    joint_receptor_table->binding_count
  );
  device float *joint = reinterpret_cast<device float *>(
    hot_state + uniforms.joint_belief_offset + ulong(gid) * 256ul
  );
  device ulong *identity = reinterpret_cast<device ulong *>(joint + 32u);
  const bool prior_valid = (identity[7] & ulong(NB_ACCEPTED_STATE_VALID)) != 0ul;
  const float elapsed_seconds = max(
    float(uniforms.delta_microseconds) * 1.0e-6f, 1.0e-6f
  );
  const float gain = clamp(min(
    uniforms.belief_gain,
    nb_physical_alpha(elapsed_seconds, max(belief_parameters[8], 1.0e-4f))
  ), 0.0f, 1.0f);
  float maximum_error = 0.0f;
  uint evidence_channels = 0u;
  const uint coordinate_count = min(topology.identifiers.w, 6u);
  for (uint coordinate = 0u; coordinate < coordinate_count; ++coordinate) {
    float position_total = 0.0f;
    float position_weight = 0.0f;
    float velocity_total = 0.0f;
    float velocity_weight = 0.0f;
    float limit_total = 0.0f;
    float limit_weight = 0.0f;
    for (uint binding_index = range.binding_offset;
        binding_index < binding_end; ++binding_index) {
      const NBJointReceptorBindingRecord binding = bindings[binding_index];
      if ((binding.flags & NB_ACCEPTED_STATE_VALID) == 0u
          || binding.joint_index != gid
          || binding.coordinate_slot != coordinate
          || binding.observation_scalar_index >= uniforms.observation_count
          || validity[binding.observation_scalar_index] == 0u
          || !isfinite(binding.scale) || !isfinite(binding.bias)
          || !isfinite(binding.weight) || binding.weight <= 0.0f) continue;
      const float evidence = fma(
        observations[binding.observation_scalar_index],
        binding.scale,
        binding.bias
      );
      if (!isfinite(evidence)) continue;
      switch (binding.signal) {
        case 1u:
          position_total += evidence * binding.weight;
          position_weight += binding.weight;
          break;
        case 2u:
          velocity_total += evidence * binding.weight;
          velocity_weight += binding.weight;
          break;
        case 3u:
          limit_total += clamp(evidence, 0.0f, 1.0f) * binding.weight;
          limit_weight += binding.weight;
          break;
        default:
          break;
      }
    }
    const float prior_position = prior_valid
      ? joint[coordinate] : topology.limits[coordinate].z;
    const float prior_velocity = prior_valid ? joint[6u + coordinate] : 0.0f;
    const bool has_position = position_weight > 0.0f;
    const bool has_velocity = velocity_weight > 0.0f;
    const bool has_limit = limit_weight > 0.0f;
    const float observed_position = has_position
      ? position_total / position_weight : prior_position;
    const float observed_velocity = has_velocity
      ? velocity_total / velocity_weight : prior_velocity;
    const float corrected_position = mix(
      prior_position, observed_position, has_position ? gain : 0.0f
    );
    const float corrected_velocity = mix(
      prior_velocity, observed_velocity, has_velocity ? gain : 0.0f
    );
    joint[coordinate] = corrected_position;
    joint[6u + coordinate] = corrected_velocity;
    const float position_residual = observed_position - corrected_position;
    const float velocity_residual = observed_velocity - corrected_velocity;
    joint[12u + coordinate] = max(mix(
      prior_valid ? max(joint[12u + coordinate], 0.0f) : 1.0f,
      position_residual * position_residual,
      has_position ? gain : 0.0f
    ), 0.0f);
    joint[18u + coordinate] = max(mix(
      prior_valid ? max(joint[18u + coordinate], 0.0f) : 1.0f,
      velocity_residual * velocity_residual,
      has_velocity ? gain : 0.0f
    ), 0.0f);
    if (has_limit) {
      joint[24u + coordinate] = mix(
        prior_valid ? joint[24u + coordinate] : 0.0f,
        limit_total / limit_weight,
        gain
      );
    }
    evidence_channels += uint(has_position) + uint(has_velocity) + uint(has_limit);
    maximum_error = max(
      maximum_error,
      max(abs(position_residual), abs(velocity_residual))
    );
  }
  if (evidence_channels == 0u) return;
  const float evidence_fraction = float(evidence_channels)
    / max(float(coordinate_count * 3u), 1.0f);
  joint[30] = clamp(mix(
    prior_valid ? joint[30] : 0.0f,
    evidence_fraction,
    gain
  ), 0.0f, 1.0f);
  joint[31] = maximum_error;
  identity[0] = ulong(topology.identifiers.x);
  identity[1] = ulong(topology.identifiers.y);
  identity[2] = ulong(topology.identifiers.z);
  identity[3] = ulong(coordinate_count);
  identity[4] = uniforms.target_timestamp_microseconds;
  identity[5] = uniforms.physics_state_fingerprint;
  identity[6] = joint_receptor_table->topology_fingerprint;
  identity[7] = ulong(NB_ACCEPTED_STATE_VALID);
}

inline float4 nb_accepted_quaternion_multiply(float4 lhs, float4 rhs) {
  return float4(
    lhs.w * rhs.xyz + rhs.w * lhs.xyz + cross(lhs.xyz, rhs.xyz),
    lhs.w * rhs.w - dot(lhs.xyz, rhs.xyz)
  );
}

inline float3 nb_accepted_rotate(float3 vector, float4 quaternion) {
  const float norm_squared = dot(quaternion, quaternion);
  if (norm_squared <= 1.0e-12f) return vector;
  const float4 normalized = quaternion * rsqrt(norm_squared);
  const float3 twice_cross = 2.0f * cross(normalized.xyz, vector);
  return vector + normalized.w * twice_cross
    + cross(normalized.xyz, twice_cross);
}

inline float4 nb_accepted_axis_angle(float3 axis, float angle) {
  const float axis_length_squared = dot(axis, axis);
  if (axis_length_squared <= 1.0e-12f || !isfinite(angle)) {
    return float4(0.0f, 0.0f, 0.0f, 1.0f);
  }
  const float half_angle = 0.5f * angle;
  return float4(
    axis * rsqrt(axis_length_squared) * sin(half_angle),
    cos(half_angle)
  );
}

/// Reconciles the topologically ordered articulation posterior into the one
/// compatible body factor. This is belief-space forward kinematics from
/// receptor estimates, not access to authoritative NumanX pose state.
kernel void reconcile_accepted_articulated_body_graph(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *belief_parameters [[buffer(2)]],
  device const NBJointReceptorBindingTableHeader *joint_receptor_table
    [[buffer(10)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.joint_count == 0u) return;
  device const NBJointTopologyRecord *topologies =
    reinterpret_cast<device const NBJointTopologyRecord *>(
      joint_receptor_table + 1
    );
  const uint joint_count = min(
    uniforms.joint_count, joint_receptor_table->joint_count
  );
  const float base_gain = clamp(
    min(uniforms.belief_gain, max(belief_parameters[0], 0.0f)),
    0.0f,
    1.0f
  );
  for (uint joint_index = 0u; joint_index < joint_count; ++joint_index) {
    const NBJointTopologyRecord topology = topologies[joint_index];
    const uint parent_index = topology.identifiers.y;
    const uint child_index = topology.identifiers.z;
    if (parent_index >= uniforms.body_count
        || child_index >= uniforms.body_count) continue;
    device const float *joint = reinterpret_cast<device const float *>(
      hot_state + uniforms.joint_belief_offset
        + ulong(joint_index) * 256ul
    );
    device const ulong *joint_identity =
      reinterpret_cast<device const ulong *>(joint + 32u);
    if ((joint_identity[7] & ulong(NB_ACCEPTED_STATE_VALID)) == 0ul
        || joint_identity[6] != joint_receptor_table->topology_fingerprint) {
      continue;
    }
    device float *parent = reinterpret_cast<device float *>(
      hot_state + uniforms.body_belief_offset + ulong(parent_index) * 256ul
    );
    device float *child = reinterpret_cast<device float *>(
      hot_state + uniforms.body_belief_offset + ulong(child_index) * 256ul
    );
    device const ulong *parent_identity =
      reinterpret_cast<device const ulong *>(parent + NB_BODY_IDENTITY_FLOAT_OFFSET);
    device ulong *child_identity =
      reinterpret_cast<device ulong *>(child + NB_BODY_IDENTITY_FLOAT_OFFSET);
    if ((parent_identity[3] & ulong(NB_ACCEPTED_STATE_VALID)) == 0ul) continue;
    float4 parent_orientation = float4(
      parent[NB_BODY_ORIENTATION],
      parent[NB_BODY_ORIENTATION + 1u],
      parent[NB_BODY_ORIENTATION + 2u],
      parent[NB_BODY_ORIENTATION + 3u]
    );
    parent_orientation = dot(parent_orientation, parent_orientation) > 1.0e-12f
      ? normalize(parent_orientation) : float4(0.0f, 0.0f, 0.0f, 1.0f);
    float4 coordinate_rotation = float4(0.0f, 0.0f, 0.0f, 1.0f);
    float3 local_translation = float3(0.0f);
    float3 local_linear_velocity = float3(0.0f);
    float3 local_angular_velocity = float3(0.0f);
    float joint_variance = 0.0f;
    const uint coordinate_count = min(topology.identifiers.w, 6u);
    for (uint coordinate = 0u; coordinate < coordinate_count; ++coordinate) {
      const float3 axis = topology.axes[coordinate].xyz;
      const uint kind = uint(round(topology.axes[coordinate].w));
      const float position = joint[coordinate];
      const float displacement = position - topology.limits[coordinate].z;
      const float velocity = joint[6u + coordinate];
      joint_variance += max(joint[12u + coordinate], 0.0f)
        + max(joint[18u + coordinate], 0.0f);
      if (kind == 1u) {
        coordinate_rotation = nb_accepted_quaternion_multiply(
          coordinate_rotation,
          nb_accepted_axis_angle(axis, displacement)
        );
        local_angular_velocity += normalize(axis) * velocity;
      } else if (kind == 2u) {
        const float3 normalized_axis = normalize(axis);
        local_translation += normalized_axis * displacement;
        local_linear_velocity += normalized_axis * velocity;
      }
    }
    float4 predicted_orientation = nb_accepted_quaternion_multiply(
      parent_orientation,
      nb_accepted_quaternion_multiply(
        coordinate_rotation,
        topology.rest_relative_orientation
      )
    );
    predicted_orientation = dot(predicted_orientation, predicted_orientation)
        > 1.0e-12f
      ? normalize(predicted_orientation) : parent_orientation;
    const float3 parent_position = float3(
      parent[NB_BODY_POSITION],
      parent[NB_BODY_POSITION + 1u],
      parent[NB_BODY_POSITION + 2u]
    );
    const float3 parent_linear_velocity = float3(
      parent[NB_BODY_LINEAR_VELOCITY],
      parent[NB_BODY_LINEAR_VELOCITY + 1u],
      parent[NB_BODY_LINEAR_VELOCITY + 2u]
    );
    const float3 parent_angular_velocity = float3(
      parent[NB_BODY_ANGULAR_VELOCITY],
      parent[NB_BODY_ANGULAR_VELOCITY + 1u],
      parent[NB_BODY_ANGULAR_VELOCITY + 2u]
    );
    const float3 parent_joint_offset = nb_accepted_rotate(
      topology.parent_local_anchor.xyz + local_translation,
      parent_orientation
    );
    const float3 child_anchor_offset = nb_accepted_rotate(
      topology.child_local_anchor.xyz,
      predicted_orientation
    );
    const float3 predicted_position = parent_position + parent_joint_offset
      - child_anchor_offset;
    const float3 predicted_angular_velocity = parent_angular_velocity
      + nb_accepted_rotate(local_angular_velocity, parent_orientation);
    const float3 predicted_linear_velocity = parent_linear_velocity
      + cross(parent_angular_velocity, parent_joint_offset)
      + nb_accepted_rotate(local_linear_velocity, parent_orientation)
      - cross(predicted_angular_velocity, child_anchor_offset);
    const bool child_valid =
      (child_identity[3] & ulong(NB_ACCEPTED_STATE_VALID)) != 0ul;
    const float mean_joint_variance = joint_variance
      / max(float(coordinate_count * 2u), 1.0f);
    const float certainty = clamp(joint[30], 0.0f, 1.0f)
      / (1.0f + sqrt(mean_joint_variance));
    const float graph_gain = child_valid
      ? min(base_gain * certainty, 0.75f) : 1.0f;
    for (uint component = 0u; component < 3u; ++component) {
      child[NB_BODY_POSITION + component] = mix(
        child_valid ? child[NB_BODY_POSITION + component]
          : predicted_position[component],
        predicted_position[component],
        graph_gain
      );
      child[NB_BODY_LINEAR_VELOCITY + component] = mix(
        child_valid ? child[NB_BODY_LINEAR_VELOCITY + component]
          : predicted_linear_velocity[component],
        predicted_linear_velocity[component],
        graph_gain
      );
      child[NB_BODY_ANGULAR_VELOCITY + component] = mix(
        child_valid ? child[NB_BODY_ANGULAR_VELOCITY + component]
          : predicted_angular_velocity[component],
        predicted_angular_velocity[component],
        graph_gain
      );
      const float predicted_position_variance = max(
        parent[NB_BODY_POSITION_VARIANCE + component], 0.0f
      ) + mean_joint_variance;
      const float predicted_orientation_variance = max(
        parent[NB_BODY_ORIENTATION_VARIANCE + component], 0.0f
      ) + mean_joint_variance;
      child[NB_BODY_POSITION_VARIANCE + component] = mix(
        child_valid ? max(child[NB_BODY_POSITION_VARIANCE + component], 0.0f)
          : predicted_position_variance,
        predicted_position_variance,
        graph_gain
      );
      child[NB_BODY_ORIENTATION_VARIANCE + component] = mix(
        child_valid ? max(child[NB_BODY_ORIENTATION_VARIANCE + component], 0.0f)
          : predicted_orientation_variance,
        predicted_orientation_variance,
        graph_gain
      );
    }
    float4 child_orientation = child_valid
      ? float4(
          child[NB_BODY_ORIENTATION],
          child[NB_BODY_ORIENTATION + 1u],
          child[NB_BODY_ORIENTATION + 2u],
          child[NB_BODY_ORIENTATION + 3u]
        ) : predicted_orientation;
    if (dot(child_orientation, predicted_orientation) < 0.0f) {
      predicted_orientation = -predicted_orientation;
    }
    child_orientation = mix(
      child_orientation, predicted_orientation, graph_gain
    );
    child_orientation = dot(child_orientation, child_orientation) > 1.0e-12f
      ? normalize(child_orientation) : predicted_orientation;
    for (uint component = 0u; component < 4u; ++component) {
      child[NB_BODY_ORIENTATION + component] = child_orientation[component];
    }
    child[NB_BODY_OWNERSHIP] = clamp(max(
      child_valid ? child[NB_BODY_OWNERSHIP] : 0.0f,
      certainty
    ), 0.0f, 1.0f);
    child[NB_BODY_PROPRIOCEPTIVE_ERROR] = max(
      child_valid ? child[NB_BODY_PROPRIOCEPTIVE_ERROR] : 0.0f,
      joint[31]
    );
    child_identity[0] = ulong(child_index);
    child_identity[1] = uniforms.target_timestamp_microseconds;
    child_identity[2] = uniforms.physics_state_fingerprint;
    child_identity[3] = (child_valid ? child_identity[3] : 0ul)
      | ulong(NB_ACCEPTED_STATE_VALID) | NB_ACCEPTED_BODY_ARTICULATED;
  }
}

/// Joins the accepted fast load posterior into the compatible cognitive body
/// factor. The fast record remains the estimator of load and vulnerability;
/// the cognitive factor retains receptor pose/contact evidence and publishes
/// the maximum compatible risk used by planning and motor arbitration.
kernel void assimilate_accepted_fast_body_schema(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const NBFastBodySchemaRecord *fast_body_schema [[buffer(7)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.body_count) return;
  const NBFastBodySchemaRecord schema = fast_body_schema[gid];
  if (schema.body_identifier != gid
      || schema.state_timestamp_microseconds
        != uniforms.target_timestamp_microseconds
      || !isfinite(schema.estimated_absolute_load)
      || !isfinite(schema.epistemic_variance)
      || !isfinite(schema.vulnerability)
      || !isfinite(schema.damage_risk)) {
    return;
  }
  device float *body = reinterpret_cast<device float *>(
    hot_state + uniforms.body_belief_offset + ulong(gid) * 256ul
  );
  body[NB_BODY_LOAD] = max(schema.estimated_absolute_load, 0.0f);
  body[NB_BODY_LOAD_VARIANCE] = max(schema.epistemic_variance, 0.0f);
  body[NB_BODY_VULNERABILITY] = clamp(schema.vulnerability, 0.0f, 1.0f);
  body[NB_BODY_DAMAGE_RISK] = clamp(schema.damage_risk, 0.0f, 1.0f);
  device ulong *identity = reinterpret_cast<device ulong *>(
    body + NB_BODY_IDENTITY_FLOAT_OFFSET
  );
  identity[0] = ulong(schema.body_identifier);
  identity[1] = uniforms.target_timestamp_microseconds;
  identity[3] |= 1ul;
  if ((schema.flags & 1u) != 0u) identity[3] |= 1ul << 4u;
  identity[4] = schema.last_observation_timestamp_microseconds;
  identity[5] = schema.state_timestamp_microseconds;
  identity[6] = (ulong(schema.source_muscle_identifier) << 32u)
    | ulong(schema.endpoint_role);
  identity[7] = ulong(schema.flags);
}

/// Updates the learned body ownership and reachability factors only after the
/// accepted somatic effect model and optional fast load posterior are visible.
/// This is a separate dispatch so no body thread observes a partially updated
/// effector record. The state therefore reflects accepted causal consequence,
/// never the cached intention alone.
kernel void update_accepted_embodied_self_model(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *belief_parameters [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.body_count) return;
  device float *body = reinterpret_cast<device float *>(
    hot_state + uniforms.body_belief_offset + ulong(gid) * 256ul
  );
  device ulong *identity = reinterpret_cast<device ulong *>(
    body + NB_BODY_IDENTITY_FLOAT_OFFSET
  );
  if ((identity[3] & NB_ACCEPTED_STATE_VALID) == 0ul) return;
  const float elapsed_seconds = max(
    float(uniforms.delta_microseconds) * 1.0e-6f, 1.0e-6f
  );
  float reachability_target = 0.0f;
  float ownership_target = 0.0f;
  float proprioceptive_error = body[NB_BODY_PROPRIOCEPTIVE_ERROR];
  float external_disturbance = 0.0f;
  if (uniforms.muscle_count > 0u) {
    uint effector_index = gid % uniforms.muscle_count;
    bool effector_found = true;
    if ((identity[3] & (1ul << 4u)) != 0ul) {
      const uint source_muscle_identifier = uint(identity[6] >> 32u);
      if (source_muscle_identifier != 0xffffffffu) {
        effector_found = false;
        for (uint candidate_index = 0u;
            candidate_index < uniforms.muscle_count; ++candidate_index) {
          device const float *candidate = reinterpret_cast<device const float *>(
            hot_state + uniforms.muscle_belief_offset
              + ulong(candidate_index) * 192ul
          );
          device const ulong *candidate_identity =
            reinterpret_cast<device const ulong *>(candidate + 16);
          if ((candidate_identity[3] & NB_ACCEPTED_STATE_VALID) != 0ul
              && uint(candidate_identity[0]) == source_muscle_identifier) {
            effector_index = candidate_index;
            effector_found = true;
            break;
          }
        }
      }
    }
    if (effector_found) {
      device const float *effector = reinterpret_cast<device const float *>(
        hot_state + uniforms.muscle_belief_offset
          + ulong(effector_index) * 192ul
      );
      const float agency = clamp(effector[8], 0.0f, 1.0f);
      external_disturbance = clamp(effector[9], 0.0f, 1.0f);
      proprioceptive_error = max(proprioceptive_error, abs(effector[5]));
      const float learned_effect_evidence = clamp(
        abs(effector[6]) * max(belief_parameters[14], 0.0f), 0.0f, 1.0f
      );
      reachability_target = learned_effect_evidence * agency;
      ownership_target = agency / (1.0f + external_disturbance);
    }
  }
  const float reachability_gain = nb_physical_alpha(
    elapsed_seconds, max(belief_parameters[9], 1.0e-4f)
  );
  const float ownership_gain = nb_physical_alpha(
    elapsed_seconds, max(belief_parameters[10], 1.0e-4f)
  );
  body[NB_BODY_REACHABILITY] = clamp(mix(
    body[NB_BODY_REACHABILITY], reachability_target, reachability_gain
  ), 0.0f, 1.0f);
  body[NB_BODY_OWNERSHIP] = clamp(mix(
    body[NB_BODY_OWNERSHIP], ownership_target, ownership_gain
  ), 0.0f, 1.0f);
  body[NB_BODY_PROPRIOCEPTIVE_ERROR] = proprioceptive_error;
  body[NB_BODY_EXTERNAL_DISTURBANCE] = external_disturbance;
  identity[3] |= 1ul << 5u;
}

kernel void reconcile_accepted_world_model(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *world_parameters [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= min(uniforms.world_model_count, NB_WORLD_RECEPTOR_DIMENSION)
      || uniforms.observation_count == 0u
      || uniforms.world_model_count < 9u * NB_WORLD_RECEPTOR_DIMENSION) return;
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  device const uint *validity = reinterpret_cast<device const uint *>(
    hot_state + uniforms.observation_validity_offset
  );
  device float *world = reinterpret_cast<device float *>(
    hot_state + uniforms.world_model_offset
  );
  bool observation_valid = false;
  const float observed = nb_world_observation(
    observations, validity, uniforms, gid, observation_valid
  );
  if (!observation_valid) return;
  float predicted_mean = 0.0f;
  for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
    predicted_mean += world[(3u + head) * NB_WORLD_RECEPTOR_DIMENSION + gid]
      / float(NB_WORLD_HEAD_COUNT);
  }
  const float residual = observed - predicted_mean;
  const float gain = clamp(
    min(uniforms.world_correction_gain, max(world_parameters[150], 0.0f)),
    0.0f,
    1.0f
  );
  for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
    const uint head_index =
      (3u + head) * NB_WORLD_RECEPTOR_DIMENSION + gid;
    world[head_index] = mix(world[head_index], observed, gain);
  }
  world[gid] = mix(world[gid], observed, gain);
  world[NB_WORLD_RECEPTOR_DIMENSION + gid] = residual;
  const uint aleatoric_index = 8u * NB_WORLD_RECEPTOR_DIMENSION + gid;
  world[aleatoric_index] = mix(
    max(world[aleatoric_index], 0.0f), residual * residual,
    gain * clamp(world_parameters[152], 0.0f, 1.0f)
  );
}

/// Reconciles the level-1 prediction against the accepted full body posterior.
/// This runs only after body assimilation and the accepted agency update, so a
/// rejected physical candidate cannot alter sensorimotor dynamics or error.
kernel void reconcile_accepted_sensorimotor_world_model(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *world_parameters [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  const uint required_count = NB_WORLD_SENSORIMOTOR_BASE
    + 9u * NB_WORLD_SENSORIMOTOR_DIMENSION;
  if (gid >= NB_WORLD_SENSORIMOTOR_DIMENSION
      || uniforms.world_model_count < required_count) return;
  bool has_evidence = false;
  const float observed = nb_body_sensorimotor_projection(
    hot_state, uniforms, gid, has_evidence
  );
  if (!has_evidence) return;
  device float *world = reinterpret_cast<device float *>(
    hot_state + uniforms.world_model_offset
  );
  float predicted_mean = 0.0f;
  for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
    predicted_mean += world[NB_WORLD_SENSORIMOTOR_BASE
      + (3u + head) * NB_WORLD_SENSORIMOTOR_DIMENSION + gid]
      / float(NB_WORLD_HEAD_COUNT);
  }
  const float residual = observed - predicted_mean;
  const float gain = clamp(
    min(uniforms.world_correction_gain, max(world_parameters[150], 0.0f)),
    0.0f,
    1.0f
  );
  world[NB_WORLD_SENSORIMOTOR_BASE + gid] = mix(
    world[NB_WORLD_SENSORIMOTOR_BASE + gid], observed, gain
  );
  world[NB_WORLD_SENSORIMOTOR_BASE
    + NB_WORLD_SENSORIMOTOR_DIMENSION + gid] = residual;
  for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
    const uint head_index = NB_WORLD_SENSORIMOTOR_BASE
      + (3u + head) * NB_WORLD_SENSORIMOTOR_DIMENSION + gid;
    world[head_index] = mix(world[head_index], observed, gain);
  }
  const uint aleatoric_index = NB_WORLD_SENSORIMOTOR_BASE
    + 8u * NB_WORLD_SENSORIMOTOR_DIMENSION + gid;
  world[aleatoric_index] = mix(
    max(world[aleatoric_index], 0.0f), residual * residual,
    gain * clamp(world_parameters[152], 0.0f, 1.0f)
  );
}

/// Updates one mind's per-channel sensing efficacy from accepted receptor
/// consequences. The pending bit is written during decision generation and is
/// cleared only here, so a rejected physical trajectory cannot become a
/// calibration sample.
kernel void update_active_sensing_efficacy(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *belief_parameters [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.active_sensing_count) return;
  device const NBActiveSensingCommandRecord *commands =
    reinterpret_cast<device const NBActiveSensingCommandRecord *>(
      hot_state + uniforms.accepted_active_sensing_output_offset
    );
  device NBActiveSensingEfficacyRecord *states =
    reinterpret_cast<device NBActiveSensingEfficacyRecord *>(
      hot_state + uniforms.active_sensing_efficacy_offset
    );
  NBActiveSensingEfficacyRecord state = states[gid];
  const NBActiveSensingCommandRecord command = commands[gid];
  const bool pending = (state.flags & (1u << 1u)) != 0u;
  const bool command_valid = (command.kind_and_flags & (1u << 16u)) != 0u;
  const float allocation = min(
    clamp(state.allocation, 0.0f, 1.0f),
    clamp(command.confidence, 0.0f, 1.0f)
  );
  if (!pending || !command_valid || allocation <= 0.0f) {
    state.flags = NB_ACCEPTED_STATE_VALID;
    state.allocation = 0.0f;
    states[gid] = state;
    return;
  }
  const uint modality = command.kind_and_flags & 0xffu;
  device const float *world = reinterpret_cast<device const float *>(
    hot_state + uniforms.world_model_offset
  );
  float accepted_uncertainty = nb_modality_epistemic_uncertainty(
    world, uniforms.world_model_count, modality
  );
  const uint selected_object_slot = command.attention_allocation_mask >> 16u;
  if (modality == 1u && selected_object_slot > 0u) {
    accepted_uncertainty = max(
      accepted_uncertainty,
      nb_selected_object_accepted_uncertainty(
        hot_state, uniforms, belief_parameters, selected_object_slot
      )
    );
  }
  if (modality == 3u || modality == 4u) {
    accepted_uncertainty = max(
      accepted_uncertainty,
      nb_body_schema_epistemic_uncertainty(hot_state, uniforms)
    );
  }
  const float aleatoric_uncertainty = clamp(
    nb_modality_aleatoric_uncertainty(
      world, uniforms.world_model_count, modality
    ),
    0.0f,
    1.0f
  );
  const float epistemic_reduction = max(
    state.prior_uncertainty - accepted_uncertainty, 0.0f
  );
  const float realized_information_gain = epistemic_reduction
    * (1.0f - aleatoric_uncertainty) * allocation;
  const float opportunity = max(state.prior_uncertainty * allocation, 1.0e-6f);
  const float efficacy_target = clamp(
    realized_information_gain / opportunity, 0.0f, 2.0f
  );
  const float retention = clamp(belief_parameters[7], 0.0f, 0.999f);
  const float prior_efficacy = state.sample_count > 0u
    ? clamp(state.efficacy, 0.0f, 2.0f) : 1.0f;
  state.accepted_uncertainty = accepted_uncertainty;
  state.efficacy = mix(prior_efficacy, efficacy_target, 1.0f - retention);
  state.realized_information_gain = realized_information_gain;
  state.sample_count = state.sample_count == 0xffffffffu
    ? state.sample_count : state.sample_count + 1u;
  state.flags = NB_ACCEPTED_STATE_VALID;
  state.allocation = allocation;
  state.reserved = aleatoric_uncertainty;
  states[gid] = state;
}

inline float nb_accepted_fast_autonomic_critical(
  device const uchar *hot_state,
  constant NBAcceptedConsequenceUniforms &uniforms)
{
  device const NBFastAutonomicStateRecord *states =
    reinterpret_cast<device const NBFastAutonomicStateRecord *>(
      hot_state + uniforms.fast_autonomic_state_offset
    );
  float critical = 0.0f;
  for (uint index = 0u; index < uniforms.fast_autonomic_state_count; ++index) {
    const NBFastAutonomicStateRecord state = states[index];
    if ((state.flags & NB_ACCEPTED_STATE_VALID) != 0u
        && (state.flags & (1u << 1u)) != 0u
        && isfinite(state.critical_drive)) {
      critical = max(critical, clamp(state.critical_drive, 0.0f, 1.0f));
    }
  }
  return critical;
}

inline float nb_accepted_protective_command_risk(
  device const NBAcceptedProtectiveCommandRecord *command,
  constant NBAcceptedConsequenceUniforms &uniforms)
{
  if (command->format_version != 1u
      || (command->flags & NB_ACCEPTED_PROTECTIVE_VALID) == 0u
      || (command->flags & NB_ACCEPTED_PROTECTIVE_EMERGENCY_STOP) == 0u
      || command->timestamp_microseconds != uniforms.target_timestamp_microseconds
      || command->interrupt_mask == 0ul) {
    return 0.0f;
  }
  return max(
    0.5f,
    clamp(
      max(
        max(command->motor_inhibition, command->withdrawal_drive),
        max(command->postural_stiffness, command->autonomic_arousal)
      ),
      0.0f,
      1.0f
    )
  );
}

inline float3 nb_accepted_embodied_risk(
  device const uchar *hot_state,
  constant NBAcceptedConsequenceUniforms &uniforms,
  const float physiological_critical)
{
  float pain = 0.0f;
  float threat = 0.0f;
  float evidence = 0.0f;
  for (uint body_index = 0u; body_index < uniforms.body_count; ++body_index) {
    device const float *body = reinterpret_cast<device const float *>(
      hot_state + uniforms.body_belief_offset + ulong(body_index) * 256ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      body + NB_BODY_IDENTITY_FLOAT_OFFSET
    );
    if ((identity[3] & 1ul) == 0ul) continue;
    evidence = 1.0f;
    if (isfinite(body[NB_BODY_PAIN])) {
      pain = max(pain, clamp(body[NB_BODY_PAIN], 0.0f, 1.0f));
    }
    if (isfinite(body[NB_BODY_VULNERABILITY])) {
      threat = max(
        threat, clamp(body[NB_BODY_VULNERABILITY], 0.0f, 1.0f)
      );
    }
    if (isfinite(body[NB_BODY_DAMAGE_RISK])) {
      const float damage_risk = clamp(
        body[NB_BODY_DAMAGE_RISK], 0.0f, 1.0f
      );
      pain = max(pain, damage_risk);
      threat = max(threat, damage_risk);
    }
  }
  return float3(
    pain,
    max(max(threat, pain), physiological_critical),
    max(evidence, physiological_critical > 0.0f ? 1.0f : 0.0f)
  );
}

inline void nb_raise_accepted_drive(
  device NBDriveStateRecord *drives,
  uint drive_count,
  uint index,
  float signal,
  float elapsed_seconds)
{
  if (index >= drive_count || signal <= 0.0f) return;
  NBDriveStateRecord state = drives[index];
  const float previous = state.level;
  state.level = max(previous, clamp(signal, 0.0f, 1.0f));
  state.estimated_rate = elapsed_seconds > 0.0f
    ? (state.level - previous) / elapsed_seconds : 0.0f;
  state.deficit = state.level < state.viable_minimum
    ? state.viable_minimum - state.level
    : (state.level > state.viable_maximum
      ? state.level - state.viable_maximum : 0.0f);
  state.potential = state.priority_weight * state.deficit * state.deficit;
  state.kind = index + 1u;
  drives[index] = state;
}

inline bool nb_has_accepted_protective_reflex(
  device const uchar *hot_state,
  constant NBAcceptedConsequenceUniforms &uniforms)
{
  device const NBFastReflexStateRecord *states =
    reinterpret_cast<device const NBFastReflexStateRecord *>(
      hot_state + uniforms.reflex_state_offset
    );
  for (uint index = 0u; index < uniforms.reflex_state_count; ++index) {
    const NBFastReflexStateRecord state = states[index];
    if ((state.flags & NB_ACCEPTED_STATE_VALID) == 0u
        || (state.flags & NB_ACCEPTED_REFLEX_ACTIVATED_IN_ROOT) == 0u) {
      continue;
    }
    const uint circuit_kind = (state.flags >> 8u) & 0xffu;
    const bool protective = circuit_kind == 3u   // withdrawal
      || circuit_kind == 4u                     // crossed extension
      || circuit_kind == 7u                     // joint-limit protection
      || circuit_kind == 9u                     // pain inhibition
      || circuit_kind == 10u;                   // muscle-overload inhibition
    if (protective) return true;
  }
  return false;
}

kernel void broadcast_accepted_prediction_error(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *world_parameters [[buffer(3)]],
  device const NBAcceptedProtectiveCommandRecord *protective_command
    [[buffer(8)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u) return;
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  device const uint *validity = reinterpret_cast<device const uint *>(
    hot_state + uniforms.observation_validity_offset
  );
  device const float *world = reinterpret_cast<device const float *>(
    hot_state + uniforms.world_model_offset
  );
  const float error = max(
    nb_mean_prediction_error(observations, validity, world, uniforms),
    nb_mean_sensorimotor_prediction_error(world, uniforms.world_model_count)
  );
  const float epistemic = nb_mean_epistemic_disagreement(
    world, uniforms.world_model_count
  );
  const float aleatoric = nb_mean_aleatoric_uncertainty(
    world, uniforms.world_model_count
  );
  device const uchar *muscle_bytes = hot_state + uniforms.muscle_belief_offset;
  float mean_agency = 0.0f;
  float mean_external_disturbance = 0.0f;
  for (uint index = 0u; index < uniforms.muscle_count; ++index) {
    device const float *muscle = reinterpret_cast<device const float *>(
      muscle_bytes + ulong(index) * 192ul
    );
    mean_agency += muscle[8] / float(max(uniforms.muscle_count, 1u));
    mean_external_disturbance += muscle[9]
      / float(max(uniforms.muscle_count, 1u));
  }
  device NBNeuromodulatorRecord *neuromodulators =
    reinterpret_cast<device NBNeuromodulatorRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  device NBControlHeader *control = reinterpret_cast<device NBControlHeader *>(
    hot_state + uniforms.control_header_offset
  );
  const float physiological_critical = nb_accepted_fast_autonomic_critical(
    hot_state, uniforms
  );
  const float protective_risk = nb_accepted_protective_command_risk(
    protective_command, uniforms
  );
  const bool protective_reflex = nb_has_accepted_protective_reflex(
    hot_state, uniforms
  );
  const bool fast_protective_stop = protective_reflex
    || physiological_critical > 0.0f || protective_risk > 0.0f;
  if (fast_protective_stop) {
    // Preserve the cached option identifier as causal provenance while
    // recording that accepted fast protection interrupted its execution.
    control->flags |= NB_ACCEPTED_CONTROL_HYPERDIRECT_STOP;
    control->mode = NB_ACCEPTED_CONTROL_MODE_REFLEX;
    control->active_plan_identifier = 0ul;
    control->plan_step_count = 0u;
    control->vigor = 0.0f;
  }
  const bool accepted_stop = fast_protective_stop
    || (control->flags & NB_ACCEPTED_CONTROL_HYPERDIRECT_STOP) != 0u;
  const float3 embodied_risk = nb_accepted_embodied_risk(
    hot_state, uniforms, max(physiological_critical, protective_risk)
  );
  device NBDriveStateRecord *drives =
    reinterpret_cast<device NBDriveStateRecord *>(
      hot_state + uniforms.drive_offset
    );
  const float elapsed_seconds = float(uniforms.delta_microseconds) * 1.0e-6f;
  nb_raise_accepted_drive(
    drives, uniforms.drive_count, 5u, embodied_risk.x, elapsed_seconds
  );
  nb_raise_accepted_drive(
    drives, uniforms.drive_count, 11u, embodied_risk.y, elapsed_seconds
  );
  if (uniforms.neuromodulator_count > 4u) {
    neuromodulators[4].value = max(
      neuromodulators[4].value, embodied_risk.x
    );
    neuromodulators[4].kind = 5u;
    neuromodulators[4].flags = NB_ACCEPTED_STATE_VALID;
  }
  if (uniforms.neuromodulator_count > 5u) {
    neuromodulators[5].value = max(
      neuromodulators[5].value, embodied_risk.y
    );
    neuromodulators[5].kind = 6u;
    neuromodulators[5].flags = NB_ACCEPTED_STATE_VALID;
  }
  if (uniforms.neuromodulator_count > 6u) {
    neuromodulators[6].value = max(
      neuromodulators[6].value, embodied_risk.y
    );
    neuromodulators[6].kind = 7u;
    neuromodulators[6].flags = NB_ACCEPTED_STATE_VALID;
  }
  if (embodied_risk.z > 0.0f && uniforms.maximum_planning_horizon > 0u
      && uint(control->reserved0) < uniforms.option_candidate_capacity
      && uniforms.world_model_count >= NB_WORLD_EVENT_OPTION_BASE
        + 9u * NB_WORLD_EVENT_OPTION_DIMENSION) {
    device float *mutable_world = reinterpret_cast<device float *>(
      hot_state + uniforms.world_model_offset
    );
    const float accepted_risk = max(embodied_risk.x, embodied_risk.y);
    const float gain = clamp(
      min(uniforms.world_correction_gain, max(world_parameters[150], 0.0f)),
      0.0f,
      1.0f
    );
    // Counterfactual branches now share the first sixteen event features and
    // diverge through action context. Correct those same features after the
    // accepted outcome; candidate-array position is never a learned cause.
    for (uint feature = 0u; feature < 16u; ++feature) {
      const uint component = feature % NB_WORLD_EVENT_OPTION_DIMENSION;
      float predicted_mean = 0.0f;
      for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
        predicted_mean += mutable_world[NB_WORLD_EVENT_OPTION_BASE
          + (3u + head) * NB_WORLD_EVENT_OPTION_DIMENSION + component]
          / float(NB_WORLD_HEAD_COUNT);
      }
      const float residual = accepted_risk - predicted_mean;
      mutable_world[NB_WORLD_EVENT_OPTION_BASE + component] = mix(
        mutable_world[NB_WORLD_EVENT_OPTION_BASE + component],
        accepted_risk,
        gain
      );
      mutable_world[NB_WORLD_EVENT_OPTION_BASE
        + NB_WORLD_EVENT_OPTION_DIMENSION + component] = residual;
      for (uint head = 0u; head < NB_WORLD_HEAD_COUNT; ++head) {
        const uint head_index = NB_WORLD_EVENT_OPTION_BASE
          + (3u + head) * NB_WORLD_EVENT_OPTION_DIMENSION + component;
        mutable_world[head_index] = mix(
          mutable_world[head_index], accepted_risk, gain
        );
      }
      const uint aleatoric_index = NB_WORLD_EVENT_OPTION_BASE
        + 8u * NB_WORLD_EVENT_OPTION_DIMENSION + component;
      mutable_world[aleatoric_index] = mix(
        max(mutable_world[aleatoric_index], 0.0f),
        residual * residual,
        gain * clamp(world_parameters[152], 0.0f, 1.0f)
      );
    }
  }
  if (uniforms.neuromodulator_count > 2u) {
    device const NBActiveSensingEfficacyRecord *sensing_states =
      reinterpret_cast<device const NBActiveSensingEfficacyRecord *>(
        hot_state + uniforms.active_sensing_efficacy_offset
      );
    float usable_information = 0.0f;
    uint sensing_count = 0u;
    for (uint channel = 0u; channel < uniforms.active_sensing_count; ++channel) {
      const NBActiveSensingEfficacyRecord sensing = sensing_states[channel];
      if ((sensing.flags & NB_ACCEPTED_STATE_VALID) == 0u
          || sensing.allocation <= 0.0f) continue;
      usable_information += clamp(
        sensing.realized_information_gain, 0.0f, 1.0f
      );
      sensing_count += 1u;
    }
    neuromodulators[2].value = sensing_count > 0u
      ? usable_information / float(sensing_count) : 0.0f;
    neuromodulators[2].kind = 3u;
    neuromodulators[2].flags = NB_ACCEPTED_STATE_VALID;
  }
  if (uniforms.neuromodulator_count > 1u) {
    neuromodulators[1].value = max(error, mean_external_disturbance);
    neuromodulators[1].kind = 2u;
    neuromodulators[1].flags = NB_ACCEPTED_STATE_VALID;
  }
  if (uniforms.neuromodulator_count > 3u) {
    neuromodulators[3].value = epistemic;
    neuromodulators[3].kind = 4u;
    neuromodulators[3].flags = NB_ACCEPTED_STATE_VALID;
  }
  if (uniforms.workspace_capacity > 2u && uniforms.workspace_dimension > 0u) {
    device float *workspace = reinterpret_cast<device float *>(
      hot_state + uniforms.workspace_content_offset
    );
    device NBWorkspaceMetadataRecord *metadata =
      reinterpret_cast<device NBWorkspaceMetadataRecord *>(
        hot_state + uniforms.workspace_metadata_offset
      );
    const uint base = 2u * uniforms.workspace_dimension;
    workspace[base] = error;
    if (uniforms.workspace_dimension > 1u) {
      workspace[base + 1u] = as_type<float>(uint(uniforms.physics_state_fingerprint));
    }
    if (uniforms.workspace_dimension > 2u) {
      workspace[base + 2u] = mean_agency;
    }
    if (uniforms.workspace_dimension > 3u) {
      workspace[base + 3u] = mean_external_disturbance;
    }
    if (uniforms.workspace_dimension > 4u) {
      workspace[base + 4u] = embodied_risk.x;
    }
    if (uniforms.workspace_dimension > 5u) {
      workspace[base + 5u] = embodied_risk.y;
    }
    if (uniforms.workspace_dimension > 6u) {
      workspace[base + 6u] = accepted_stop ? 1.0f : 0.0f;
    }
    if (uniforms.workspace_dimension > 7u) {
      workspace[base + 7u] = protective_risk;
    }
    if (uniforms.workspace_dimension > 8u) {
      workspace[base + 8u] = physiological_critical;
    }
    NBWorkspaceMetadataRecord token = metadata[2];
    token.identifier = (uniforms.target_timestamp_microseconds << 8) | 3ul;
    token.source_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    token.last_refresh_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    token.entity_identifier = control->active_option_identifier;
    token.goal_identifier = control->active_goal_identifier;
    token.provenance_record_identifier = uniforms.physics_state_fingerprint;
    token.kind_and_source = 7u | (50u << 16);
    token.confidence = accepted_stop
      ? max(
          0.5f,
          protective_reflex
            ? 1.0f : max(protective_risk, physiological_critical)
        )
      : clamp(min(1.0f - error, mean_agency), 0.0f, 1.0f);
    const float accepted_error_salience = clamp(max(
      error,
      max(protective_risk, physiological_critical)
    ), 0.0f, 1.0f);
    token.persistence_priority = accepted_stop
      ? 1.0f : 0.35f + 0.45f * accepted_error_salience;
    token.selection_score = accepted_stop ? 1.0f : accepted_error_salience;
    token.provenance_kind = 0u;
    token.flags = 1u | (1u << 1u);
    token.provenance_source_generation = 0ul;
    token.last_score_update_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    metadata[2] = token;
  }
  control->unsupported_uncertainty = max(
    max(epistemic * max(world_parameters[157], 0.0f), aleatoric),
    mean_external_disturbance
  );
  if (!accepted_stop) {
    const uint goal_origin = uint(control->active_goal_identifier >> 56u);
    const ulong goal_code = control->active_goal_identifier
      & NB_ACCEPTED_GOAL_SOURCE_MASK;
    const bool external_goal = goal_origin == 2u
      && (goal_code & (1ul << 55u)) != 0ul;
    const uint drive_index = goal_code > 0ul ? uint(goal_code - 1ul) : ~0u;
    const bool drive_bound_goal = drive_index < uniforms.drive_count
      && (goal_origin == 1u || goal_origin == 2u || goal_origin == 4u
        || goal_origin == 5u || goal_origin == 6u);
    float satisfaction = 0.0f;
    float progress_time_constant = 2.0f;
    bool external_goal_evaluated = false;
    if (external_goal && uniforms.workspace_dimension >= 55u) {
      device const float *workspace = reinterpret_cast<device const float *>(
        hot_state + uniforms.workspace_content_offset
      );
      device const NBWorkspaceMetadataRecord *metadata =
        reinterpret_cast<device const NBWorkspaceMetadataRecord *>(
          hot_state + uniforms.workspace_metadata_offset
        );
      for (uint slot = 7u; slot < min(uniforms.workspace_capacity, 11u); ++slot) {
        const NBWorkspaceMetadataRecord goal_token = metadata[slot];
        if (goal_token.goal_identifier != control->active_goal_identifier
            || goal_token.provenance_record_identifier == 0ul) continue;
        const uint base = slot * uniforms.workspace_dimension;
        const float accepted_features[16] = {
          1.0f,
          1.0f - clamp(error, 0.0f, 1.0f),
          clamp(mean_agency, 0.0f, 1.0f),
          clamp(mean_external_disturbance, 0.0f, 1.0f),
          clamp(embodied_risk.x, 0.0f, 1.0f),
          clamp(embodied_risk.y, 0.0f, 1.0f),
          clamp(embodied_risk.z, 0.0f, 1.0f),
          clamp(protective_risk, 0.0f, 1.0f),
          clamp(physiological_critical, 0.0f, 1.0f),
          clamp(epistemic, 0.0f, 1.0f),
          clamp(aleatoric, 0.0f, 1.0f),
          0.0f,
          clamp(control->confidence, 0.0f, 1.0f),
          clamp(control->vigor, 0.0f, 1.0f),
          1.0f - clamp(control->predicted_effort, 0.0f, 1.0f),
          1.0f - clamp(control->unsupported_uncertainty, 0.0f, 1.0f),
        };
        float success_logit = 0.0f;
        float failure_logit = 0.0f;
        for (uint component = 0u; component < 16u; ++component) {
          success_logit += workspace[base + 23u + component]
            * accepted_features[component];
          failure_logit += workspace[base + 39u + component]
            * accepted_features[component];
        }
        const float success_probability = 1.0f / (
          1.0f + exp(-clamp(success_logit * 0.25f, -20.0f, 20.0f))
        );
        const float failure_probability = 1.0f / (
          1.0f + exp(-clamp(failure_logit * 0.25f, -20.0f, 20.0f))
        );
        satisfaction = success_probability * (1.0f - failure_probability);
        if (failure_probability >= 0.8f) {
          control->flags |= NB_ACCEPTED_CONTROL_EXTERNAL_GOAL_FAILED;
        } else {
          control->progress = max(
            clamp(control->progress, 0.0f, 1.0f),
            success_probability >= 0.95f ? 1.0f : satisfaction
          );
        }
        external_goal_evaluated = true;
        break;
      }
    }
    if (!external_goal_evaluated && drive_bound_goal) {
      const NBDriveStateRecord goal_drive = drives[drive_index];
      const float viable_span = max(
        abs(goal_drive.viable_maximum - goal_drive.viable_minimum), 0.1f
      );
      const float deficit = max(goal_drive.deficit, 0.0f);
      satisfaction = viable_span / (viable_span + deficit);
    } else if (!external_goal_evaluated
        && control->active_goal_identifier != 0ul) {
      const float accepted_risk = max(
        max(embodied_risk.x, embodied_risk.y), protective_risk
      );
      satisfaction = clamp(
        (1.0f - clamp(error, 0.0f, 1.0f))
          * (0.5f + 0.5f * clamp(mean_agency, 0.0f, 1.0f))
          * (1.0f - clamp(accepted_risk, 0.0f, 1.0f)),
        0.0f, 1.0f
      );
    }
    if (external_goal_evaluated) {
      // External success/failure predicates consume accepted features above;
      // generic prediction quality must not double-advance the same task.
    } else if (drive_bound_goal) {
      // A viable accepted drive state is completion evidence now; retaining a
      // lag here would turn a satisfied disappearing goal into a false
      // prospective-memory interruption on the following root.
      control->progress = clamp(satisfaction, 0.0f, 1.0f);
    } else {
      const float progress_alpha = 1.0f - exp(
        -max(elapsed_seconds, 1.0e-6f) / progress_time_constant
      );
      control->progress = mix(
        clamp(control->progress, 0.0f, 1.0f),
        satisfaction,
        clamp(progress_alpha, 0.0f, 1.0f)
      );
    }
  }
}

kernel void adapt_cerebellar_experts_from_accepted_error(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *cerebellar_parameters [[buffer(4)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.active_cerebellar_count) return;
  device NBCerebellarExpertRecord *experts =
    reinterpret_cast<device NBCerebellarExpertRecord *>(
      hot_state + uniforms.cerebellar_offset
    );
  device NBCerebellarExpertRecord *expert_bank =
    reinterpret_cast<device NBCerebellarExpertRecord *>(
      hot_state + uniforms.cerebellar_expert_memory_offset
    );
  NBCerebellarExpertRecord expert = experts[gid];
  const bool prediction_is_causal =
    (expert.flags & NB_ACCEPTED_CEREBELLAR_PREDICTION_VALID) != 0u
    && expert.prediction_count > 0u
    && uniforms.body_count > 0u
    && expert.prediction_timestamp_microseconds
      < uniforms.target_timestamp_microseconds
    && uniforms.target_timestamp_microseconds
      - expert.prediction_timestamp_microseconds == uniforms.delta_microseconds;
  if (!prediction_is_causal) {
    expert.flags &= ~NB_ACCEPTED_CEREBELLAR_PREDICTION_VALID;
    experts[gid] = expert;
    return;
  }
  const float learning_rate = clamp(
    min(uniforms.cerebellar_learning_rate, max(cerebellar_parameters[0], 0.0f)),
    0.0f,
    1.0f
  );
  const uint prediction_count = min(expert.prediction_count, 8u);
  float absolute_error_sum = 0.0f;
  float command_error_sum = 0.0f;
  uint accepted_count = 0u;
  device const uchar *body_belief = hot_state + uniforms.body_belief_offset;
  const uint body_identifier = expert.reserved;
  device const float *accepted_body = nullptr;
  for (uint body_index = 0u; body_index < uniforms.body_count; ++body_index) {
    device const float *body = reinterpret_cast<device const float *>(
      body_belief + ulong(body_index) * 256ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      body + NB_BODY_IDENTITY_FLOAT_OFFSET
    );
    if ((identity[3] & NB_ACCEPTED_STATE_VALID) != 0ul
        && uint(identity[0]) == body_identifier) {
      accepted_body = body;
      break;
    }
  }
  if (accepted_body == nullptr) {
    expert.flags &= ~NB_ACCEPTED_CEREBELLAR_PREDICTION_VALID;
    experts[gid] = expert;
    return;
  }
  for (uint sample = 0u; sample < prediction_count; ++sample) {
    const uint body_feature = uint(expert.state[36u + sample]);
    if (body_feature >= NB_BODY_SENSORIMOTOR_FEATURE_COUNT) continue;
    const float accepted_feature = nb_body_sensorimotor_feature(
      accepted_body, body_feature
    );
    const float signed_error = accepted_feature - expert.state[4u + sample];
    const float command_feature = expert.state[20u + sample];
    absolute_error_sum += abs(signed_error);
    command_error_sum += signed_error * command_feature;
    accepted_count += 1u;
    expert.state[28u + sample] = clamp(
      expert.state[28u + sample]
        + learning_rate * signed_error * command_feature,
      -1.0f,
      1.0f
    );
  }
  if (accepted_count == 0u) {
    expert.flags &= ~NB_ACCEPTED_CEREBELLAR_PREDICTION_VALID;
    experts[gid] = expert;
    return;
  }
  const float error = absolute_error_sum / float(accepted_count);
  expert.prediction_error = error;
  expert.state[0] = mix(
    expert.state[0], error,
    learning_rate
  );
  const float inverse_correction = clamp(
    -(command_error_sum / float(accepted_count))
      * cerebellar_parameters[3],
    -0.25f,
    0.25f
  );
  expert.state[1] = mix(
    expert.state[1], inverse_correction,
    learning_rate
  );
  expert.state[2] = mix(
    expert.state[2], 1.0f - clamp(error, 0.0f, 1.0f),
    clamp(cerebellar_parameters[2], 0.0f, 1.0f)
  );
  expert.flags = (expert.flags | NB_ACCEPTED_STATE_VALID)
    & ~NB_ACCEPTED_CEREBELLAR_PREDICTION_VALID;
  experts[gid] = expert;
  if (expert.expert_identifier < uniforms.cerebellar_expert_capacity) {
    expert_bank[expert.expert_identifier] = expert;
  }
}

kernel void update_fast_plasticity_from_accepted_error(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const float *plasticity_parameters [[buffer(5)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.fast_plasticity_count) return;
  device const NBNeuromodulatorRecord *neuromodulators =
    reinterpret_cast<device const NBNeuromodulatorRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  device NBFastPlasticityRecord *sites =
    reinterpret_cast<device NBFastPlasticityRecord *>(
      hot_state + uniforms.fast_plasticity_offset
    );
  NBFastPlasticityRecord site = sites[gid];
  device const NBRegionalMaturationRecord *maturation =
    reinterpret_cast<device const NBRegionalMaturationRecord *>(
      hot_state + uniforms.regional_maturation_offset
    );
  constexpr uint hyperparameter_count = 8u;
  constexpr uint basis_stride = 517u;
  constexpr uint receptor_effect_count = 14u;
  const uint receptor_scalar_count = uniforms.module_count
    * uniforms.neuromodulator_count * receptor_effect_count;
  const uint basis_scalar_count = uniforms.plasticity_parameter_count
      > hyperparameter_count + receptor_scalar_count
    ? uniforms.plasticity_parameter_count - hyperparameter_count
        - receptor_scalar_count
    : 0u;
  const uint basis_capacity = uniforms.module_count > 0u
    ? basis_scalar_count / (uniforms.module_count * basis_stride)
    : 0u;
  const uint receptor_offset = hyperparameter_count
    + uniforms.module_count * basis_capacity * basis_stride;
  uint region_index = uniforms.module_count > 0u
    ? gid % uniforms.module_count : 0u;
  for (uint index = 0u; index < uniforms.module_count; ++index) {
    if (maturation[index].module_identifier == uint(site.region_identifier)) {
      region_index = index;
      break;
    }
  }
  float modulation = 0.0f;
  if (basis_capacity > 0u) {
    for (uint channel = 0u; channel < uniforms.neuromodulator_count; ++channel) {
      const uint weight_index = receptor_offset
        + (region_index * uniforms.neuromodulator_count + channel)
          * receptor_effect_count;
      modulation += neuromodulators[channel].value
        * plasticity_parameters[weight_index];
    }
  }
  // The cognitive shadow step already formed and retained the basis-aligned
  // local eligibility. Accepted prediction error is present in the regional
  // neuromodulator projection above; it must not become a global eligibility
  // term shared by every synaptic basis.
  const float interval_scale = float(uniforms.delta_microseconds) / 20000.0f;
  const float learning_rate = min(
    uniforms.plasticity_learning_rate,
    max(plasticity_parameters[0], 0.0f)
  );
  const float limit = max(
    site.maximum_magnitude * max(plasticity_parameters[7], 0.0f), 1.0e-4f
  );
  site.coefficient = clamp(
    site.coefficient
      + interval_scale * learning_rate * modulation * site.eligibility,
    -limit,
    limit
  );
  site.flags |= NB_ACCEPTED_STATE_VALID;
  sites[gid] = site;
}

inline ulong nb_trace_hash(ulong value) {
  value ^= value >> 30;
  value *= 0xbf58476d1ce4e5b9ul;
  value ^= value >> 27;
  value *= 0x94d049bb133111ebul;
  return value ^ (value >> 31);
}

/// Records only the option phases whose physical consequences were accepted.
/// Completed traces remain in the transactional hot arena until rest-time
/// procedural consolidation consumes them.
kernel void update_accepted_procedural_trace(
  device uchar *hot_state [[buffer(0)]],
  constant NBAcceptedConsequenceUniforms &uniforms [[buffer(1)]],
  device const NBAcceptedProtectiveCommandRecord *protective_command
    [[buffer(8)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.procedural_trace_record_capacity == 0u
      || uniforms.procedural_trace_phase_capacity == 0u) return;
  device const NBControlHeader *control =
    reinterpret_cast<device const NBControlHeader *>(
      hot_state + uniforms.control_header_offset
    );
  device NBProceduralExecutionTrace *traces =
    reinterpret_cast<device NBProceduralExecutionTrace *>(
      hot_state + uniforms.procedural_trace_offset
    );
  if (control->active_option_identifier == NB_ACCEPTED_REST_OPTION_IDENTIFIER) {
    for (uint index = 0u; index < uniforms.procedural_trace_record_capacity;
        ++index) {
      if ((traces[index].flags & NB_ACCEPTED_STATE_VALID) != 0u
          && (traces[index].flags & NB_ACCEPTED_TRACE_COMPLETE) == 0u
          && traces[index].phase_count > 0u) {
        traces[index].flags |= NB_ACCEPTED_TRACE_COMPLETE;
        traces[index].last_timestamp_microseconds =
          uniforms.target_timestamp_microseconds;
      }
    }
    return;
  }
  if (uniforms.option_candidate_capacity == 0u) return;
  const uint selected_index = min(
    uint(control->reserved0), uniforms.option_candidate_capacity - 1u
  );
  device const NBOptionCandidateRecord *candidates =
    reinterpret_cast<device const NBOptionCandidateRecord *>(
      hot_state + uniforms.option_candidate_offset
    );
  const NBOptionCandidateRecord candidate = candidates[selected_index];
  if ((candidate.flags & NB_ACCEPTED_STATE_VALID) == 0u
      || candidate.option_identifier != control->active_option_identifier) return;
  const float physiological_critical = nb_accepted_fast_autonomic_critical(
    hot_state, uniforms
  );
  const float protective_risk = nb_accepted_protective_command_risk(
    protective_command, uniforms
  );
  const float3 embodied_risk = nb_accepted_embodied_risk(
    hot_state, uniforms, max(physiological_critical, protective_risk)
  );
  const float accepted_damage = max(
    clamp(control->selected_damage_cvar, 0.0f, 1.0f),
    max(embodied_risk.x, embodied_risk.y)
  );

  uint trace_index = uniforms.procedural_trace_record_capacity;
  uint reusable_index = uniforms.procedural_trace_record_capacity;
  ulong reusable_timestamp = ~0ul;
  for (uint index = 0u; index < uniforms.procedural_trace_record_capacity;
      ++index) {
    const NBProceduralExecutionTrace trace = traces[index];
    const bool valid = trace.format_version == 1u
      && (trace.flags & NB_ACCEPTED_STATE_VALID) != 0u;
    if (valid && (trace.flags & NB_ACCEPTED_TRACE_COMPLETE) == 0u
        && trace.goal_identifier == control->active_goal_identifier) {
      trace_index = index;
      break;
    }
    if (!valid) {
      if (reusable_index == uniforms.procedural_trace_record_capacity) {
        reusable_index = index;
      }
    } else if ((trace.flags & NB_ACCEPTED_TRACE_COMPLETE) != 0u
        && trace.last_timestamp_microseconds < reusable_timestamp) {
      reusable_index = index;
      reusable_timestamp = trace.last_timestamp_microseconds;
    }
  }
  if (trace_index == uniforms.procedural_trace_record_capacity) {
    if (reusable_index == uniforms.procedural_trace_record_capacity) return;
    trace_index = reusable_index;
    NBProceduralExecutionTrace initial = {};
    initial.identifier = nb_trace_hash(
      control->active_goal_identifier
        ^ control->active_option_identifier
        ^ uniforms.target_timestamp_microseconds
    ) | 1ul;
    initial.goal_identifier = control->active_goal_identifier;
    initial.plan_identifier = control->active_plan_identifier;
    initial.start_timestamp_microseconds =
      uniforms.target_timestamp_microseconds - uniforms.delta_microseconds;
    initial.last_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    initial.format_version = 1u;
    initial.flags = NB_ACCEPTED_STATE_VALID;
    traces[trace_index] = initial;
  }

  device NBProceduralExecutionTrace *trace = &traces[trace_index];
  if ((control->flags & NB_ACCEPTED_CONTROL_HYPERDIRECT_STOP) != 0u) {
    trace->flags |= NB_ACCEPTED_TRACE_COMPLETE | NB_ACCEPTED_TRACE_FAILED;
  }
  uint phase_index = trace->phase_count;
  if (trace->phase_count > 0u
      && trace->phases[trace->phase_count - 1u].option_identifier
        == candidate.option_identifier) {
    phase_index = trace->phase_count - 1u;
  } else {
    if (trace->phase_count >= min(
        uniforms.procedural_trace_phase_capacity, 8u
      )) {
      trace->flags |= NB_ACCEPTED_TRACE_COMPLETE;
      return;
    }
    phase_index = trace->phase_count;
    NBProceduralTracePhase phase = {};
    phase.option_identifier = candidate.option_identifier;
    phase.start_timestamp_microseconds =
      uniforms.target_timestamp_microseconds - uniforms.delta_microseconds;
    phase.parameter_count = min(candidate.parameter_count, 16u);
    trace->phases[phase_index] = phase;
    trace->phase_count += 1u;
  }
  device NBProceduralTracePhase *phase = &trace->phases[phase_index];
  const uint next_phase_samples = phase->sample_count == ~0u
    ? phase->sample_count : phase->sample_count + 1u;
  const float phase_rate = 1.0f / float(max(next_phase_samples, 1u));
  phase->last_timestamp_microseconds = uniforms.target_timestamp_microseconds;
  phase->duration_seconds += float(uniforms.delta_microseconds) * 1.0e-6f;
  phase->mean_value = mix(
    phase->mean_value, control->selected_score, phase_rate
  );
  phase->maximum_damage = max(
    phase->maximum_damage, accepted_damage
  );
  phase->mean_uncertainty = mix(
    phase->mean_uncertainty, control->unsupported_uncertainty, phase_rate
  );
  phase->sample_count = next_phase_samples;
  for (uint component = 0u; component < 16u; ++component) {
    phase->parameters[component] = mix(
      phase->parameters[component], candidate.parameters[component], phase_rate
    );
  }
  const uint next_samples = trace->sample_count == ~0u
    ? trace->sample_count : trace->sample_count + 1u;
  const float trace_rate = 1.0f / float(max(next_samples, 1u));
  trace->sample_count = next_samples;
  trace->last_timestamp_microseconds = uniforms.target_timestamp_microseconds;
  trace->plan_identifier = control->active_plan_identifier != 0ul
    ? control->active_plan_identifier : trace->plan_identifier;
  trace->cumulative_value += control->selected_score;
  trace->maximum_damage = max(
    trace->maximum_damage, accepted_damage
  );
  trace->cumulative_effort += max(control->predicted_effort, 0.0f);
  trace->mean_uncertainty = mix(
    trace->mean_uncertainty, control->unsupported_uncertainty, trace_rate
  );
  trace->final_progress = control->progress;
  if (control->progress >= 0.99f) trace->flags |= NB_ACCEPTED_TRACE_COMPLETE;
}

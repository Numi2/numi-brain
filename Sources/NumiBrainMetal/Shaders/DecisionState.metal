#include <metal_stdlib>
using namespace metal;

constant uint NB_CONTROL_MODE_REFLEX = 1u;
constant uint NB_CONTROL_MODE_PROCEDURAL = 2u;
constant uint NB_CONTROL_MODE_PLANNING = 3u;
constant uint NB_CONTROL_FLAG_VALID = 1u;
constant uint NB_CONTROL_FLAG_HYPERDIRECT_STOP = 1u << 1;
constant ulong NB_INNATE_OPTION_NAMESPACE = 0x8000000000000000ul;

struct NBDecisionUniforms {
  ulong target_timestamp_microseconds;
  ulong recurrent_offset;
  ulong workspace_offset;
  ulong world_model_offset;
  ulong drive_offset;
  ulong neuromodulation_offset;
  ulong control_header_offset;
  ulong candidate_offset;
  ulong plan_offset;
  ulong motor_offset;
  ulong synergy_offset;
  ulong cerebellar_offset;
  ulong spinal_offset;
  ulong autonomic_offset;
  ulong somatic_output_offset;
  ulong parameter_version_fingerprint;
  ulong reserved_identity;
  uint recurrent_scalar_count;
  uint workspace_scalar_count;
  uint world_model_scalar_count;
  uint drive_count;
  uint neuromodulator_count;
  uint candidate_capacity;
  uint plan_capacity;
  uint actuator_count;
  uint synergy_count;
  uint active_cerebellar_expert_count;
  uint autonomic_dimension;
  uint module_count;
  float risk_weight;
  float damage_risk_budget;
  float switching_margin;
  float curiosity_weight;
  float planning_cost_weight;
  float motor_gain;
  float stiffness_gain;
  float damping_gain;
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
  float state[60];
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

static_assert(sizeof(NBDecisionUniforms) == 216);
static_assert(sizeof(NBDriveRecord) == 32);
static_assert(sizeof(NBNeuromodulatorRecord) == 16);
static_assert(sizeof(NBControlHeader) == 128);
static_assert(sizeof(NBOptionCandidateRecord) == 128);
static_assert(sizeof(NBPlanStepRecord) == 128);
static_assert(sizeof(NBMotorCommandRecord) == 32);
static_assert(sizeof(NBCerebellarExpertRecord) == 256);
static_assert(sizeof(NBSpinalStateRecord) == 16);
static_assert(sizeof(NBAutonomicCommandRecord) == 16);

kernel void propose_dynamic_options(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.candidate_capacity) return;
  device const float *recurrent = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  device const float *workspace = reinterpret_cast<device const float *>(
    hot_state + uniforms.workspace_offset
  );
  device const NBDriveRecord *drives = reinterpret_cast<device const NBDriveRecord *>(
    hot_state + uniforms.drive_offset
  );
  device const NBNeuromodulatorRecord *neuromodulators =
    reinterpret_cast<device const NBNeuromodulatorRecord *>(
      hot_state + uniforms.neuromodulation_offset
    );
  device NBOptionCandidateRecord *candidates =
    reinterpret_cast<device NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  NBOptionCandidateRecord candidate;
  candidate.option_identifier = NB_INNATE_OPTION_NAMESPACE | ulong(gid + 1u);
  candidate.goal_identifier = 0ul;
  const float task_signal = workspace[gid % uniforms.workspace_scalar_count];
  const float homeostatic = drives[gid % uniforms.drive_count].deficit;
  const float safety = uniforms.drive_count > 11u ? drives[11].level : 0.0f;
  const float pain = uniforms.drive_count > 5u ? drives[5].level : 0.0f;
  const float epistemic = uniforms.neuromodulator_count > 3u
    ? neuromodulators[3].value
    : 0.0f;
  candidate.task_value = task_signal;
  candidate.homeostatic_value = gid == 3u ? homeostatic : -0.1f * homeostatic;
  candidate.social_value = gid == 8u && uniforms.drive_count > 9u
    ? drives[9].deficit
    : 0.0f;
  candidate.information_gain = (gid == 4u || gid == 7u) ? epistemic : 0.0f;
  candidate.damage_cvar = clamp(safety + pain * (gid > 4u ? 0.5f : 0.1f), 0.0f, 1.0f);
  candidate.effort_cost = 0.02f * float(gid % 8u);
  candidate.switching_cost = gid == 0u ? 0.0f : 0.025f;
  candidate.competence = clamp(
    0.5f + 0.5f * recurrent[gid % uniforms.recurrent_scalar_count],
    0.0f,
    1.0f
  );
  candidate.proposal_kind = gid % 10u;
  candidate.source_module = 72u;
  candidate.flags = NB_CONTROL_FLAG_VALID;
  candidate.parameter_count = 16u;
  for (uint index = 0u; index < 16u; ++index) {
    candidate.parameters[index] = recurrent[
      (gid * 16u + index) % uniforms.recurrent_scalar_count
    ];
  }
  candidates[gid] = candidate;
}

kernel void simulate_candidate_option_outcomes(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= min(uniforms.candidate_capacity, uniforms.plan_capacity)) return;
  device const NBOptionCandidateRecord *candidates =
    reinterpret_cast<device const NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  device const float *world = reinterpret_cast<device const float *>(
    hot_state + uniforms.world_model_offset
  );
  device NBPlanStepRecord *plans = reinterpret_cast<device NBPlanStepRecord *>(
    hot_state + uniforms.plan_offset
  );
  const NBOptionCandidateRecord candidate = candidates[gid];
  NBPlanStepRecord plan;
  plan.option_identifier = candidate.option_identifier;
  plan.goal_identifier = candidate.goal_identifier;
  plan.damage_cvar = clamp(
    candidate.damage_cvar + 0.1f * abs(world[gid % uniforms.world_model_scalar_count]),
    0.0f,
    1.0f
  );
  plan.epistemic_uncertainty = abs(
    world[(gid * 5u + 1u) % uniforms.world_model_scalar_count]
      - world[(gid * 5u + 2u) % uniforms.world_model_scalar_count]
  );
  plan.predicted_effort = candidate.effort_cost * (1.0f + plan.epistemic_uncertainty);
  plan.predicted_information_gain = candidate.information_gain;
  plan.duration_seconds = 0.1f + 0.05f * float(gid % 8u);
  plan.predicted_drive_change = candidate.homeostatic_value;
  plan.objective_value = candidate.task_value + candidate.homeostatic_value
    + candidate.social_value + uniforms.curiosity_weight * candidate.information_gain
    - uniforms.risk_weight * plan.damage_cvar - plan.predicted_effort
    - candidate.switching_cost;
  plan.admissibility = plan.damage_cvar <= uniforms.damage_risk_budget ? 1.0f : 0.0f;
  plan.sequence = 0u;
  plan.flags = NB_CONTROL_FLAG_VALID;
  plan.parameter_count = 16u;
  plan.reserved = 0u;
  for (uint index = 0u; index < 16u; ++index) {
    plan.predicted_state[index] = tanh(
      world[(gid * 16u + index) % uniforms.world_model_scalar_count]
        + candidate.parameters[index]
    );
  }
  plans[gid] = plan;
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
  const float safety = uniforms.drive_count > 11u ? drives[11].level : 0.0f;
  uint selected = 0u;
  float selected_score = -INFINITY;
  for (uint index = 0u; index < uniforms.candidate_capacity; ++index) {
    const NBPlanStepRecord plan = plans[index];
    if (plan.admissibility > 0.5f && plan.objective_value > selected_score) {
      selected = index;
      selected_score = plan.objective_value;
    }
  }
  uint flags = NB_CONTROL_FLAG_VALID;
  uint mode = NB_CONTROL_MODE_PROCEDURAL;
  if (safety > 0.8f) {
    selected = 0u;
    flags |= NB_CONTROL_FLAG_HYPERDIRECT_STOP;
    mode = NB_CONTROL_MODE_REFLEX;
  } else if (plans[selected].epistemic_uncertainty > 0.25f
      || plans[selected].damage_cvar > 0.25f) {
    mode = NB_CONTROL_MODE_PLANNING;
  }
  const NBOptionCandidateRecord candidate = candidates[selected];
  const NBPlanStepRecord plan = plans[selected];
  header->active_option_identifier = candidate.option_identifier;
  header->active_plan_identifier = mode == NB_CONTROL_MODE_PLANNING
    ? (candidate.option_identifier ^ uniforms.parameter_version_fingerprint)
    : 0ul;
  header->selected_timestamp_microseconds = uniforms.target_timestamp_microseconds;
  header->mode = mode;
  header->candidate_count = uniforms.candidate_capacity;
  header->plan_step_count = mode == NB_CONTROL_MODE_PLANNING ? 1u : 0u;
  header->flags = flags;
  header->selected_score = selected_score;
  header->selected_damage_cvar = plan.damage_cvar;
  header->confidence = clamp(candidate.competence * (1.0f - plan.epistemic_uncertainty), 0.0f, 1.0f);
  header->vigor = clamp(1.0f - candidate.effort_cost - safety, 0.0f, 1.0f);
  header->exploration_temperature = clamp(plan.epistemic_uncertainty, 0.0f, 1.0f);
  header->predicted_effort = plan.predicted_effort;
  header->predicted_information_gain = plan.predicted_information_gain;
  header->unsupported_uncertainty = plan.epistemic_uncertainty;
}

kernel void select_cerebellar_context_experts(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.active_cerebellar_expert_count) return;
  device const NBControlHeader *header = reinterpret_cast<device const NBControlHeader *>(
    hot_state + uniforms.control_header_offset
  );
  device NBCerebellarExpertRecord *experts =
    reinterpret_cast<device NBCerebellarExpertRecord *>(
      hot_state + uniforms.cerebellar_offset
    );
  NBCerebellarExpertRecord expert;
  expert.expert_identifier = uint(
    (header->active_option_identifier + ulong(gid * 31u)) % 128ul
  );
  expert.flags = NB_CONTROL_FLAG_VALID;
  expert.weight = 1.0f / float(max(uniforms.active_cerebellar_expert_count, 1u));
  expert.prediction_error = header->unsupported_uncertainty;
  for (uint index = 0u; index < 60u; ++index) {
    expert.state[index] = 0.0f;
  }
  experts[gid] = expert;
}

kernel void generate_motor_spinal_autonomic_state(
  device uchar *hot_state [[buffer(0)]],
  constant NBDecisionUniforms &uniforms [[buffer(1)]],
  uint gid [[thread_position_in_grid]])
{
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
  const uint selected = uint((header->active_option_identifier & 0xfffful) - 1ul)
    % max(uniforms.candidate_capacity, 1u);
  const NBOptionCandidateRecord candidate = candidates[selected];
  const float safety = uniforms.drive_count > 11u ? clamp(drives[11].level, 0.0f, 1.0f) : 0.0f;
  if (gid < uniforms.actuator_count) {
    device NBMotorCommandRecord *motor =
      reinterpret_cast<device NBMotorCommandRecord *>(hot_state + uniforms.motor_offset);
    device NBSpinalStateRecord *spinal =
      reinterpret_cast<device NBSpinalStateRecord *>(hot_state + uniforms.spinal_offset);
    device float *somatic_output = reinterpret_cast<device float *>(
      hot_state + uniforms.somatic_output_offset
    );
    const float descending = 1.0f / (
      1.0f + exp(-candidate.parameters[gid % candidate.parameter_count] * uniforms.motor_gain)
    );
    const float inhibition = (header->flags & NB_CONTROL_FLAG_HYPERDIRECT_STOP) != 0u
      ? 1.0f
      : safety;
    NBMotorCommandRecord command;
    command.excitation = clamp(descending * (1.0f - inhibition), 0.0f, 1.0f);
    command.force_target = descending;
    command.stiffness_target = clamp(
      uniforms.stiffness_gain * (safety + abs(candidate.parameters[(gid + 1u) % 16u])),
      0.0f,
      1.0f
    );
    command.damping_target = clamp(
      uniforms.damping_gain * command.stiffness_target,
      0.0f,
      1.0f
    );
    command.cerebellar_residual = -header->unsupported_uncertainty * 0.05f;
    command.risk_inhibition = inhibition;
    command.synergy_identifier = gid % max(uniforms.synergy_count, 1u);
    command.flags = NB_CONTROL_FLAG_VALID;
    motor[gid] = command;
    NBSpinalStateRecord spinal_state;
    spinal_state.reflex_output = safety > 0.5f ? -0.25f : 0.0f;
    spinal_state.cpg_output = 0.0f;
    spinal_state.motor_neuron_state = command.excitation + command.cerebellar_residual;
    spinal_state.final_excitation = clamp(
      spinal_state.motor_neuron_state + spinal_state.reflex_output,
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
    synergies[gid] = candidate.parameters[gid % candidate.parameter_count];
  }
  if (gid < uniforms.autonomic_dimension) {
    device NBAutonomicCommandRecord *autonomic =
      reinterpret_cast<device NBAutonomicCommandRecord *>(
        hot_state + uniforms.autonomic_offset
      );
    NBAutonomicCommandRecord command;
    command.command = clamp(safety + (gid == 0u ? header->vigor : 0.0f), 0.0f, 1.0f);
    command.target = command.command;
    command.confidence = header->confidence;
    command.flags = NB_CONTROL_FLAG_VALID;
    autonomic[gid] = command;
  }
}

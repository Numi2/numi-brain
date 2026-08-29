#include <metal_stdlib>
using namespace metal;

#define NB_MEMORY_ARCHIVE_SHORTLIST_COUNT 32u

constant uint NB_MEMORY_EPISODE_RECORD_VERSION = 2u;
constant uint NB_MEMORY_MUTATION_SECTION_ACTIVE_EPISODE = 1u;
constant uint NB_MEMORY_MUTATION_SECTION_COMPRESSED_EPISODE = 2u;
constant uint NB_MEMORY_MUTATION_SECTION_ARCHIVE_EPISODE = 9u;
constant uint NB_MEMORY_MUTATION_SECTION_SEMANTIC_CONCEPT = 3u;
constant uint NB_MEMORY_MUTATION_SECTION_SEMANTIC_RELATION = 4u;
constant uint NB_MEMORY_MUTATION_SECTION_PROCEDURAL_SKILL = 5u;
constant uint NB_MEMORY_MUTATION_SECTION_PROSPECTIVE_INTENTION = 6u;
constant uint NB_MEMORY_MUTATION_SECTION_REPLAY_QUEUE = 7u;
constant uint NB_MEMORY_MUTATION_SECTION_COMMITTED_TRANSITION = 8u;
constant uint NB_MEMORY_MUTATION_SECTION_COUNTERFACTUAL_ROLLOUT = 10u;
constant uint NB_MEMORY_MUTATION_SECTION_REGIONAL_TRANSITION = 11u;
constant uint NB_COUNTERFACTUAL_RECORD_VERSION = 1u;
constant uint NB_COUNTERFACTUAL_VALID = 1u;
constant uint NB_COUNTERFACTUAL_IMAGINED = 2u;
constant uint NB_COUNTERFACTUAL_ADMISSIBLE = 4u;
constant uint NB_MEMORY_JOURNAL_STATUS_CAPACITY = 1u << 4;
constant uint NB_MEMORY_RECORD_VERSION = 1u;
constant uint NB_COMMITTED_TRANSITION_RECORD_VERSION = 6u;
constant uint NB_COMMITTED_TRANSITION_HAS_BODY_TRACE = 1u << 1;
constant uint NB_COMMITTED_TRANSITION_ACCEPTED_STOP = 1u << 2;
constant uint NB_REGIONAL_TRANSITION_RECORD_VERSION = 1u;
constant uint NB_PROCEDURAL_SKILL_RECORD_VERSION = 3u;
constant uint NB_PROCEDURAL_SKILL_TRAINABLE = 1u;
constant uint NB_PROCEDURAL_SKILL_FROZEN = 2u;
constant uint NB_PROCEDURAL_SKILL_RETIRED = 4u;
constant uint NB_PROCEDURAL_SKILL_RECONSOLIDATED = 8u;
constant uint NB_PROCEDURAL_SKILL_MERGED = 16u;
constant uint NB_PROCEDURAL_SKILL_COMPOSED = 32u;
constant uint NB_PROCEDURAL_SKILL_LIFECYCLE_MASK = 7u;
constant uint NB_MEMORY_CONTROL_FLAG_VALID = 1u;
constant uint NB_MEMORY_CONTROL_FLAG_HYPERDIRECT_STOP = 1u << 1;
constant uint NB_MEMORY_CONTROL_FLAG_EXTERNAL_GOAL_FAILED = 1u << 8;
constant uint NB_MEMORY_LIFECYCLE_STOP_ACTIVE = 1u;
constant uint NB_MEMORY_LIFECYCLE_STOP_ONSET = 1u << 1;
constant uint NB_MEMORY_LIFECYCLE_EXTERNAL_GOAL_FAILED = 1u << 2;
constant ulong NB_MEMORY_GOAL_SOURCE_MASK = 0x00fffffffffffffful;
constant ulong NB_MEMORY_INNATE_OPTION_NAMESPACE = 0x8000000000000000ul;
constant ulong NB_MEMORY_REST_OPTION_IDENTIFIER =
  NB_MEMORY_INNATE_OPTION_NAMESPACE | 4ul;
constant uint NB_MEMORY_ARCHIVE_CLUSTER_COUNT = 256u;

struct NBMemoryUniforms {
  ulong target_timestamp_microseconds;
  ulong base_generation;
  ulong shadow_generation;
  ulong parameter_version_fingerprint;
  ulong episode_identifier;
  ulong control_step_identifier;
  ulong recurrent_offset;
  ulong event_queue_offset;
  ulong workspace_content_offset;
  ulong control_header_offset;
  ulong body_belief_offset;
  ulong accepted_active_sensing_offset;
  ulong active_sensing_efficacy_offset;
  ulong object_slot_offset;
  ulong prospective_lifecycle_offset;
  ulong active_episode_accumulator_offset;
  ulong active_episode_memory_offset;
  ulong compressed_episode_memory_offset;
  ulong archive_episode_memory_offset;
  ulong replay_memory_offset;
  ulong archive_page_epoch_offset;
  ulong journal_byte_count;
  ulong persistent_memory_byte_count;
  uint recurrent_scalar_count;
  uint workspace_scalar_count;
  uint active_episode_capacity;
  uint active_episode_stride;
  uint compressed_episode_capacity;
  uint compressed_episode_stride;
  uint archive_episode_capacity;
  uint archive_episode_stride;
  uint replay_capacity;
  uint replay_stride;
  uint archive_records_per_page;
  uint archive_page_count;
  uint journal_entry_capacity;
  uint surprise_sample_count;
  uint body_belief_count;
  uint active_sensing_count;
  uint object_slot_count;
  float boundary_threshold;
  float event_salience_weight;
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

struct NBMemoryJournalHeader {
  uint format_version;
  atomic_uint entry_count;
  uint entry_capacity;
  atomic_uint status;
  ulong base_generation;
  ulong shadow_generation;
  ulong memory_byte_count;
  ulong reserved;
};

struct NBMemoryMutation {
  ulong destination_byte_offset;
  ulong shadow_generation;
  uint payload[4];
  uint byte_count;
  uint section;
  uint sequence;
  uint flags;
  ulong record_identifier;
  ulong reserved;
};

struct NBEpisodicSummaryRecord {
  ulong identifier;
  ulong start_timestamp_microseconds;
  ulong end_timestamp_microseconds;
  ulong parameter_version_fingerprint;
  ulong source_generation;
  ulong active_goal_identifier;
  ulong active_option_identifier;
  uint format_version;
  uint event_kind;
  uint source_identifier;
  uint flags;
  float salience;
  float epistemic_uncertainty;
  float damage_severity;
  float factored_reinforcement;
  float retrieval_key[10];
};

/// Quantized Tier-2 lived episode. Identity, provenance, time, outcome, and
/// uncertainty remain explicit while the retrieval key is compacted.
struct NBArchivedEpisodicRecord {
  ulong identifier;
  ulong start_timestamp_microseconds;
  ulong end_timestamp_microseconds;
  ulong parameter_version_fingerprint;
  ulong source_generation;
  ulong active_goal_identifier;
  ulong active_option_identifier;
  ulong archived_timestamp_microseconds;
  uint format_version;
  uint event_kind;
  uint source_identifier;
  uint flags;
  uint coarse_cluster;
  uint quantized_component_count;
  float salience;
  float epistemic_uncertainty;
  float damage_severity;
  float factored_reinforcement;
  float retrieval_key_scale;
  char quantized_retrieval_key[16];
  uint reserved;
};

struct NBActiveEpisodeAccumulator {
  ulong identifier;
  ulong start_timestamp_microseconds;
  ulong last_timestamp_microseconds;
  ulong parameter_version_fingerprint;
  ulong source_generation;
  ulong active_goal_identifier;
  ulong active_option_identifier;
  ulong last_boundary_timestamp_microseconds;
  ulong reserved_identity;
  uint format_version;
  uint sample_count;
  uint event_kind;
  uint source_identifier;
  uint flags;
  uint event_count;
  uint goal_transition_count;
  uint option_transition_count;
  float maximum_salience;
  float epistemic_sum;
  float maximum_damage;
  float reinforcement_sum;
  float latest_surprise;
  float latest_boundary_score;
  float latest_event_salience;
  float reserved_float;
  float retrieval_key_sum[30];
};

struct NBMemoryRetrievalUniforms {
  ulong target_timestamp_microseconds;
  ulong shadow_generation;
  ulong recurrent_offset;
  ulong workspace_content_offset;
  ulong workspace_metadata_offset;
  ulong retrieval_scratch_offset;
  ulong active_episode_memory_offset;
  ulong compressed_episode_memory_offset;
  ulong archive_episode_memory_offset;
  ulong semantic_memory_offset;
  ulong semantic_relation_memory_offset;
  ulong procedural_memory_offset;
  ulong prospective_memory_offset;
  ulong control_header_offset;
  ulong internal_action_offset;
  ulong developmental_state_offset;
  ulong archive_page_residency_offset;
  ulong archive_page_request_offset;
  ulong parameter_version_fingerprint;
  uint recurrent_scalar_count;
  uint workspace_capacity;
  uint workspace_dimension;
  uint active_episode_capacity;
  uint active_episode_stride;
  uint compressed_episode_capacity;
  uint compressed_episode_stride;
  uint archive_episode_capacity;
  uint archive_episode_stride;
  uint archive_search_candidate_count;
  uint archive_records_per_page;
  uint archive_page_count;
  uint archive_page_request_capacity;
  uint semantic_capacity;
  uint semantic_stride;
  uint semantic_relation_capacity;
  uint semantic_relation_stride;
  uint procedural_capacity;
  uint procedural_stride;
  uint prospective_capacity;
  uint prospective_stride;
  uint candidate_count;
  uint retrieval_pass;
  uint maximum_results;
  float minimum_score;
  float episodic_weight;
  float semantic_weight;
  float procedural_weight;
  float prospective_weight;
};

struct NBMemoryConsolidationUniforms {
  ulong target_timestamp_microseconds;
  ulong base_generation;
  ulong shadow_generation;
  ulong control_header_offset;
  ulong internal_action_offset;
  ulong developmental_state_offset;
  ulong drive_offset;
  ulong active_episode_memory_offset;
  ulong compressed_episode_memory_offset;
  ulong semantic_memory_offset;
  ulong semantic_relation_memory_offset;
  ulong procedural_memory_offset;
  ulong replay_memory_offset;
  ulong procedural_trace_offset;
  ulong persistent_memory_byte_count;
  ulong journal_byte_count;
  uint active_episode_capacity;
  uint active_episode_stride;
  uint compressed_episode_capacity;
  uint compressed_episode_stride;
  uint semantic_capacity;
  uint semantic_stride;
  uint semantic_relation_capacity;
  uint semantic_relation_stride;
  uint procedural_capacity;
  uint procedural_stride;
  uint replay_capacity;
  uint replay_stride;
  uint procedural_trace_capacity;
  uint procedural_trace_stride;
  uint journal_entry_capacity;
  uint minimum_procedural_episodes;
  uint flags;
  uint reserved;
  float maximum_damage;
  float minimum_salience;
  float procedural_learning_rate;
  float semantic_learning_rate;
  float freeze_competence;
  float freeze_maximum_damage;
  float freeze_maximum_uncertainty;
  float retire_competence;
  float retire_minimum_damage;
  float degradation_margin;
  float merge_similarity;
};

struct NBMemoryReconsolidationUniforms {
  ulong target_timestamp_microseconds;
  ulong base_generation;
  ulong shadow_generation;
  ulong recurrent_offset;
  ulong observation_offset;
  ulong retrieval_scratch_offset;
  ulong active_episode_memory_offset;
  ulong compressed_episode_memory_offset;
  ulong archive_episode_memory_offset;
  ulong semantic_memory_offset;
  ulong semantic_relation_memory_offset;
  ulong procedural_memory_offset;
  ulong replay_memory_offset;
  ulong archive_page_epoch_offset;
  ulong control_header_offset;
  ulong drive_offset;
  ulong body_belief_offset;
  ulong persistent_memory_byte_count;
  ulong journal_byte_count;
  uint recurrent_scalar_count;
  uint observation_count;
  uint active_episode_capacity;
  uint active_episode_stride;
  uint compressed_episode_capacity;
  uint compressed_episode_stride;
  uint archive_episode_capacity;
  uint archive_episode_stride;
  uint archive_search_candidate_count;
  uint semantic_capacity;
  uint semantic_stride;
  uint semantic_relation_capacity;
  uint semantic_relation_stride;
  uint procedural_capacity;
  uint procedural_stride;
  uint replay_capacity;
  uint replay_stride;
  uint archive_records_per_page;
  uint archive_page_count;
  uint drive_count;
  uint body_belief_count;
  uint reserved_body_belief;
  uint maximum_results;
  uint journal_entry_capacity;
  float learning_rate;
  float confirmation_similarity;
  float conflict_similarity;
  float maximum_damage;
  float freeze_competence;
  float freeze_maximum_damage;
  float freeze_maximum_uncertainty;
  float retire_competence;
  float retire_minimum_damage;
  float degradation_margin;
};

struct NBProspectiveLifecycleUniforms {
  ulong target_timestamp_microseconds;
  ulong base_generation;
  ulong shadow_generation;
  ulong recurrent_offset;
  ulong control_header_offset;
  ulong lifecycle_state_offset;
  ulong prospective_memory_offset;
  ulong persistent_memory_byte_count;
  ulong journal_byte_count;
  ulong default_deadline_microseconds;
  uint recurrent_scalar_count;
  uint prospective_capacity;
  uint prospective_stride;
  uint journal_entry_capacity;
  float trigger_threshold;
  float completion_threshold;
  float failure_risk_threshold;
  float default_priority;
};

struct NBCommittedTransitionUniforms {
  ulong target_timestamp_microseconds;
  ulong previous_timestamp_microseconds;
  ulong base_generation;
  ulong shadow_generation;
  ulong parameter_version_fingerprint;
  ulong episode_identifier;
  ulong control_step_identifier;
  ulong physics_state_fingerprint;
  ulong teacher_content_fingerprint;
  ulong recurrent_offset;
  ulong observation_offset;
  ulong event_queue_offset;
  ulong control_header_offset;
  ulong somatic_output_offset;
  ulong autonomic_action_offset;
  ulong active_sensing_action_offset;
  ulong internal_action_offset;
  ulong active_sensing_efficacy_offset;
  ulong body_belief_offset;
  ulong object_slot_offset;
  ulong other_agent_slot_offset;
  ulong relation_slot_offset;
  ulong spatial_transform_offset;
  ulong drive_offset;
  ulong neuromodulation_offset;
  ulong fast_plasticity_offset;
  ulong regional_plastic_modulation_offset;
  ulong cerebellar_offset;
  ulong cerebellar_expert_memory_offset;
  ulong transition_memory_offset;
  ulong regional_transition_memory_offset;
  ulong persistent_memory_byte_count;
  ulong journal_byte_count;
  uint recurrent_scalar_count;
  uint observation_count;
  uint action_count;
  uint autonomic_action_count;
  uint active_sensing_count;
  uint internal_action_count;
  uint body_belief_count;
  uint object_slot_count;
  uint other_agent_slot_count;
  uint relation_slot_count;
  uint spatial_transform_count;
  uint drive_count;
  uint neuromodulator_count;
  uint fast_plasticity_count;
  uint regional_plastic_modulation_count;
  uint active_cerebellar_count;
  uint cerebellar_expert_capacity;
  uint transition_capacity;
  uint transition_stride;
  uint regional_transition_capacity;
  uint regional_transition_stride;
  uint regional_module_count;
  uint journal_entry_capacity;
  uint teacher_scalar_count;
  uint teacher_flags;
};

struct NBRegionalTokenLayoutRecord {
  uint scalar_offset;
  uint scalar_count;
  uint parameter_offset;
  uint incoming_route_offset;
  uint dense_weight_offset;
  uint dense_weight_count;
  ushort module_id;
  ushort token_count;
  ushort token_dimension;
  ushort incoming_route_count;
  uint flags;
  ushort normal_route_budget;
  ushort reserved;
};

struct NBCounterfactualLearningUniforms {
  ulong target_timestamp_microseconds;
  ulong source_belief_timestamp_microseconds;
  ulong base_generation;
  ulong shadow_generation;
  ulong parameter_version_fingerprint;
  ulong episode_identifier;
  ulong control_step_identifier;
  ulong candidate_offset;
  ulong plan_offset;
  ulong counterfactual_memory_offset;
  ulong persistent_memory_byte_count;
  ulong journal_byte_count;
  uint candidate_capacity;
  uint plan_capacity;
  uint maximum_planning_horizon;
  uint counterfactual_capacity;
  uint counterfactual_stride;
  uint journal_entry_capacity;
  uint maximum_samples;
  uint reserved;
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

struct NBAutonomicCommandRecord {
  float command;
  float target;
  float confidence;
  uint flags;
};

struct NBActiveSensingCommandRecord {
  float command;
  float confidence;
  uint attention_allocation_mask;
  uint kind_and_flags;
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

struct NBOtherAgentSlotRecord {
  ulong identifier;
  ulong last_seen_timestamp_microseconds;
  uint format_version;
  uint flags;
  float existence_probability;
  float identity_confidence;
  float gaze_confidence;
  float goal_confidence;
  float social_relation;
  float predicted_action;
  float uncertainty;
  float communication_evidence;
  float body_pose[8];
  float gaze[4];
  float latent[102];
};

struct NBRelationSlotRecord {
  ulong subject_identifier;
  ulong object_identifier;
  ulong last_evidence_timestamp_microseconds;
  uint relation_kind;
  uint flags;
  float probability;
  float uncertainty;
  float latent[6];
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

struct NBRegionalPlasticModulationRecord {
  uint module_identifier;
  uint coefficient_count;
  float recurrent_delta;
  float local_delta;
  float route_delta;
  float drive_delta;
  float gate_delta;
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

struct NBMemoryRetrievalScratch {
  atomic_uint winner_keys[4];
  ulong winner_record_identifiers[4];
  uint winner_kinds[4];
  uint winner_indices[4];
  float winner_scores[4];
  uint flags;
  atomic_uint archive_shortlist_keys[NB_MEMORY_ARCHIVE_SHORTLIST_COUNT];
  uint reserved[71];
};

struct NBArchivePageRequestQueueHeader {
  atomic_uint request_count;
  uint request_capacity;
  atomic_uint overflow_count;
  uint flags;
  ulong latest_request_timestamp_microseconds;
  ulong shadow_generation;
};

struct NBArchivePageRequestRecord {
  uint page_identifier;
  uint flags;
  ulong requested_timestamp_microseconds;
  ulong target_record_identifier;
  float priority;
  uint reserved;
};

struct NBSemanticConceptSummaryRecord {
  ulong identifier;
  ulong last_used_timestamp_microseconds;
  ulong usage_count;
  ulong source_episode_identifier;
  uint format_version;
  uint kind;
  uint flags;
  uint reserved;
  float confidence;
  float embedding[19];
};

struct NBSemanticRelationSummaryRecord {
  ulong identifier;
  ulong source_concept_identifier;
  ulong destination_concept_identifier;
  ulong last_used_timestamp_microseconds;
  uint format_version;
  uint kind;
  uint flags;
  uint supporting_episode_count;
  float confidence;
  float contradiction;
  float evidence_embedding[10];
};

struct NBProceduralSkillSummaryRecord {
  ulong identifier;
  ulong last_execution_timestamp_microseconds;
  ulong execution_count;
  ulong parent_skill_identifier;
  ulong created_timestamp_microseconds;
  ulong last_training_timestamp_microseconds;
  ulong initiation_goal_identifier;
  ulong outcome_event_identifier;
  uint format_version;
  uint flags;
  uint goal_parameter_dimension;
  uint phase_count;
  float competence;
  float damage_cvar;
  float expected_effort;
  float expected_value;
  float initiation_confidence;
  float termination_confidence;
  float outcome_uncertainty;
  float adaptation_rate;
  float expected_factored_value[8];
  float initiation_model[16];
  float policy_code[16];
  float termination_model[8];
  float outcome_model[16];
  float adaptation_state[4];
  ulong phase_option_identifiers[8];
  float phase_durations[8];
  float phase_parameters[8][16];
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

struct NBProspectiveIntentionSummaryRecord {
  ulong identifier;
  ulong goal_identifier;
  ulong deadline_timestamp_microseconds;
  ulong created_timestamp_microseconds;
  uint format_version;
  uint status;
  uint flags;
  uint reserved;
  float priority;
  float trigger_confidence;
  float context_match;
  float reserved_float;
  float trigger_code[16];
};

struct NBProspectiveLifecycleState {
  ulong previous_goal_identifier;
  ulong previous_goal_timestamp_microseconds;
  ulong previous_intention_identifier;
  ulong last_update_timestamp_microseconds;
  uint format_version;
  uint previous_control_mode;
  uint flags;
  uint reserved;
  float previous_progress;
  float context[51];
};

struct NBCommittedTransitionRecord {
  ulong identifier;
  ulong start_timestamp_microseconds;
  ulong end_timestamp_microseconds;
  ulong parameter_version_fingerprint;
  ulong source_generation;
  ulong physics_state_fingerprint;
  ulong active_goal_identifier;
  ulong active_option_identifier;
  uint format_version;
  uint flags;
  uint recurrent_sample_count;
  uint observation_sample_count;
  uint action_sample_count;
  uint event_count;
  uint control_mode;
  uint reserved;
  float selected_score;
  float damage_cvar;
  float progress;
  float uncertainty;
  float mean_drive_deficit;
  float pain;
  float model_error;
  float predicted_information_gain;
  float prior_state[24];
  float posterior_state[24];
  float observation[24];
  float action[16];
  float factored_reinforcement[8];
  ulong teacher_content_fingerprint;
  uint teacher_scalar_count;
  uint teacher_flags;
  float teacher_state[24];
  float fast_plasticity_trace[16];
  float cerebellar_trace[16];
  float active_sensing_trace[4];
  uint autonomic_action_sample_count;
  uint active_sensing_action_sample_count;
  uint internal_action_sample_count;
  uint complete_action_flags;
  float autonomic_action[16];
  float active_sensing_action[16];
  float internal_action[32];
  float body_schema_trace[16];
};

/// One committed full-token sample for the exact dense matrix of one module.
/// FP16 storage bounds persistent cohort memory while the learner promotes the
/// values to FP32 before differentiation.
struct NBRegionalTransitionRecord {
  ulong identifier;
  ulong start_timestamp_microseconds;
  ulong end_timestamp_microseconds;
  ulong parameter_version_fingerprint;
  ulong source_generation;
  uint format_version;
  uint flags;
  uint module_index;
  uint module_identifier;
  uint token_index;
  uint feature_count;
  uint dense_weight_offset;
  uint dense_weight_count;
  uint reserved_0;
  uint reserved_1;
  half prior_state[256];
  half posterior_state[256];
};

/// Planning-only learner record. Its explicit imagined flag and disjoint
/// persistent section prevent counterfactual predictions from becoming lived
/// episodic records while preserving them for actor, value, and risk updates.
struct NBCounterfactualLearningRecord {
  ulong identifier;
  ulong source_timestamp_microseconds;
  ulong parameter_version_fingerprint;
  ulong source_generation;
  ulong episode_identifier;
  ulong control_step_identifier;
  ulong option_identifier;
  ulong goal_identifier;
  uint format_version;
  uint flags;
  uint sequence;
  uint state_component_count;
  float objective_value;
  float damage_cvar;
  float epistemic_uncertainty;
  float predicted_effort;
  float predicted_information_gain;
  float duration_seconds;
  float predicted_drive_change;
  float admissibility;
  float predicted_state[16];
  float action_parameters[16];
  float reserved[4];
};

struct NBReplayQueueSummaryRecord {
  uint queue_kind;
  uint record_kind;
  ulong record_identifier;
  float priority;
  uint replay_count;
  ulong enqueued_timestamp_microseconds;
};

static_assert(sizeof(NBMemoryUniforms) == 264);
static_assert(sizeof(NBEventQueueHeader) == 32);
static_assert(sizeof(NBReceptorEventRecord) == 32);
static_assert(sizeof(NBMemoryJournalHeader) == 48);
static_assert(sizeof(NBMemoryMutation) == 64);
static_assert(sizeof(NBEpisodicSummaryRecord) == 128);
static_assert(sizeof(NBArchivedEpisodicRecord) == 128);
static_assert(sizeof(NBActiveEpisodeAccumulator) == 256);
static_assert(sizeof(NBMemoryRetrievalUniforms) == 272);
static_assert(sizeof(NBMemoryConsolidationUniforms) == 248);
static_assert(sizeof(NBMemoryReconsolidationUniforms) == 288);
static_assert(sizeof(NBProspectiveLifecycleUniforms) == 112);
static_assert(sizeof(NBCommittedTransitionUniforms) == 368);
static_assert(sizeof(NBCounterfactualLearningUniforms) == 128);
static_assert(sizeof(NBWorkspaceMetadataRecord) == 64);
static_assert(sizeof(NBControlHeader) == 128);
static_assert(sizeof(NBOptionCandidateRecord) == 128);
static_assert(sizeof(NBPlanStepRecord) == 128);
static_assert(sizeof(NBInternalActionRecord) == 64);
static_assert(sizeof(NBAutonomicCommandRecord) == 16);
static_assert(sizeof(NBActiveSensingCommandRecord) == 16);
static_assert(sizeof(NBDevelopmentalHeader) == 256);
static_assert(sizeof(NBDriveRecord) == 32);
static_assert(sizeof(NBNeuromodulatorRecord) == 16);
static_assert(sizeof(NBActiveSensingEfficacyRecord) == 32);
static_assert(sizeof(NBObjectSlotRecord) == 512);
static_assert(sizeof(NBOtherAgentSlotRecord) == 512);
static_assert(sizeof(NBRelationSlotRecord) == 64);
static_assert(sizeof(NBSpatialTransformRecord) == 96);
static_assert(sizeof(NBFastPlasticityRecord) == 32);
static_assert(sizeof(NBRegionalPlasticModulationRecord) == 32);
static_assert(sizeof(NBCerebellarExpertRecord) == 256);
static_assert(sizeof(NBMemoryRetrievalScratch) == 512);
static_assert(sizeof(NBArchivePageRequestQueueHeader) == 32);
static_assert(sizeof(NBArchivePageRequestRecord) == 32);
static_assert(sizeof(NBSemanticConceptSummaryRecord) == 128);
static_assert(sizeof(NBSemanticRelationSummaryRecord) == 96);
static_assert(sizeof(NBProceduralSkillSummaryRecord) == 992);
static_assert(sizeof(NBProceduralTracePhase) == 112);
static_assert(sizeof(NBProceduralExecutionTrace) == 1024);
static_assert(sizeof(NBProspectiveIntentionSummaryRecord) == 128);
static_assert(sizeof(NBProspectiveLifecycleState) == 256);
static_assert(sizeof(NBCommittedTransitionRecord) == 1104);
static_assert(sizeof(NBRegionalTokenLayoutRecord) == 40);
static_assert(sizeof(NBRegionalTransitionRecord) == 1104);
static_assert(sizeof(NBCounterfactualLearningRecord) == 256);
static_assert(sizeof(NBReplayQueueSummaryRecord) == 32);

inline ulong consolidation_hash(ulong value) {
  value ^= value >> 30;
  value *= 0xbf58476d1ce4e5b9ul;
  value ^= value >> 27;
  value *= 0x94d049bb133111ebul;
  return value ^ (value >> 31);
}

/// Must remain numerically identical to CognitiveState.metal's structured
/// world context projection. It records X_t and accepted X_t+1 summaries in
/// the final five learner-state features without exposing teacher state.
inline float committed_structured_world_context(
  device const uchar *hot_state,
  constant NBCommittedTransitionUniforms &uniforms,
  const uint level)
{
  float total = 0.0f;
  uint count = 0u;
  if (level == 0u) {
    device const NBSpatialTransformRecord *transforms =
      reinterpret_cast<device const NBSpatialTransformRecord *>(
        hot_state + uniforms.spatial_transform_offset
      );
    for (uint index = 0u; index < min(uniforms.spatial_transform_count, 5u);
        ++index) {
      const NBSpatialTransformRecord transform = transforms[index];
      if ((transform.flags & 1u) == 0u) continue;
      const float motion = (transform.linear_velocity[0]
        + transform.linear_velocity[1] + transform.linear_velocity[2]) / 3.0f;
      total += transform.confidence
        * (0.5f * tanh(motion) + 0.5f * (1.0f - transform.uncertainty));
      count += 1u;
    }
  } else if (level == 1u || level == 2u) {
    device const NBObjectSlotRecord *objects =
      reinterpret_cast<device const NBObjectSlotRecord *>(
        hot_state + uniforms.object_slot_offset
      );
    for (uint index = 0u; index < uniforms.object_slot_count; ++index) {
      const NBObjectSlotRecord object = objects[index];
      if (object.identifier == 0ul || object.existence_probability <= 0.0f) {
        continue;
      }
      const float certainty = object.existence_probability
        * (1.0f - object.uncertainty);
      if (level == 1u) {
        const float motion = (object.velocity[0] + object.velocity[1]
          + object.velocity[2]) / 3.0f;
        total += certainty
          * (0.5f * tanh(motion) + 0.5f * object.affordances[0]);
      } else {
        const float position = (object.pose[0] + object.pose[1]
          + object.pose[2]) / 3.0f;
        total += certainty * (
          0.25f * tanh(position) + 0.25f * object.identity_confidence
            + 0.25f * object.visibility + 0.25f * object.affordances[0]
        );
      }
      count += 1u;
    }
  } else if (level == 3u) {
    device const NBRelationSlotRecord *relations =
      reinterpret_cast<device const NBRelationSlotRecord *>(
        hot_state + uniforms.relation_slot_offset
      );
    for (uint index = 0u; index < uniforms.relation_slot_count; ++index) {
      const NBRelationSlotRecord relation = relations[index];
      if ((relation.flags & 1u) == 0u || relation.probability <= 0.0f) continue;
      total += relation.probability * (1.0f - relation.uncertainty)
        * tanh(relation.latent[0]);
      count += 1u;
    }
  } else {
    device const NBOtherAgentSlotRecord *agents =
      reinterpret_cast<device const NBOtherAgentSlotRecord *>(
        hot_state + uniforms.other_agent_slot_offset
      );
    for (uint index = 0u; index < uniforms.other_agent_slot_count; ++index) {
      const NBOtherAgentSlotRecord agent = agents[index];
      if (agent.identifier == 0ul || agent.existence_probability <= 0.0f) continue;
      const float social = 0.25f * (
        agent.predicted_action + agent.social_relation
          + agent.communication_evidence + agent.goal_confidence
      );
      total += agent.existence_probability * (1.0f - agent.uncertainty)
        * tanh(social);
      count += 1u;
    }
  }
  return count == 0u ? 0.0f : clamp(total / float(count), -1.0f, 1.0f);
}

inline void advance_archive_page_epoch(
  device uchar *hot_state,
  ulong epoch_offset,
  uint page_count,
  uint page_identifier)
{
  if (page_identifier >= page_count) return;
  device atomic_uint *epochs = reinterpret_cast<device atomic_uint *>(
    hot_state + epoch_offset
  );
  uint current = atomic_load_explicit(
    &epochs[page_identifier], memory_order_relaxed
  );
  while (current != 0xffffffffu) {
    const uint next = current + 1u;
    if (atomic_compare_exchange_weak_explicit(
        &epochs[page_identifier], &current, next,
        memory_order_relaxed, memory_order_relaxed
      )) return;
  }
}

inline uint archive_cluster(thread const float *key) {
  uint cluster = 0u;
  for (uint component = 0u; component < 8u; ++component) {
    if (key[component] >= 0.0f) cluster |= 1u << component;
  }
  return cluster;
}

inline uint archive_query_cluster(
  device const float *query,
  uint query_count)
{
  uint cluster = 0u;
  for (uint component = 0u; component < 8u; ++component) {
    if (component < query_count && query[component] >= 0.0f) {
      cluster |= 1u << component;
    }
  }
  return cluster;
}

inline uint archive_secondary_query_cluster(
  device const float *query,
  uint query_count,
  uint primary_cluster)
{
  uint weakest_component = 0u;
  float weakest_magnitude = INFINITY;
  for (uint component = 0u; component < 8u; ++component) {
    const float magnitude = component < query_count
      ? abs(query[component]) : 0.0f;
    if (magnitude < weakest_magnitude) {
      weakest_magnitude = magnitude;
      weakest_component = component;
    }
  }
  return primary_cluster ^ (1u << weakest_component);
}

inline NBArchivedEpisodicRecord compress_archived_episode(
  thread const NBEpisodicSummaryRecord &episode,
  ulong archived_timestamp_microseconds)
{
  NBArchivedEpisodicRecord archived = {};
  archived.identifier = episode.identifier;
  archived.start_timestamp_microseconds = episode.start_timestamp_microseconds;
  archived.end_timestamp_microseconds = episode.end_timestamp_microseconds;
  archived.parameter_version_fingerprint = episode.parameter_version_fingerprint;
  archived.source_generation = episode.source_generation;
  archived.active_goal_identifier = episode.active_goal_identifier;
  archived.active_option_identifier = episode.active_option_identifier;
  archived.archived_timestamp_microseconds = archived_timestamp_microseconds;
  archived.format_version = episode.format_version;
  archived.event_kind = episode.event_kind;
  archived.source_identifier = episode.source_identifier;
  archived.flags = episode.flags | 4u;
  archived.coarse_cluster = archive_cluster(episode.retrieval_key);
  archived.quantized_component_count = 10u;
  archived.salience = episode.salience;
  archived.epistemic_uncertainty = episode.epistemic_uncertainty;
  archived.damage_severity = episode.damage_severity;
  archived.factored_reinforcement = episode.factored_reinforcement;
  float maximum_magnitude = 0.0f;
  for (uint component = 0u; component < 10u; ++component) {
    maximum_magnitude = max(maximum_magnitude, abs(episode.retrieval_key[component]));
  }
  archived.retrieval_key_scale = maximum_magnitude > 0.0f
    ? maximum_magnitude / 127.0f : 1.0f;
  for (uint component = 0u; component < 10u; ++component) {
    archived.quantized_retrieval_key[component] = char(clamp(
      rint(episode.retrieval_key[component] / archived.retrieval_key_scale),
      -127.0f,
      127.0f
    ));
  }
  return archived;
}

inline float archive_retrieval_similarity(
  device const float *query,
  uint query_count,
  device const NBArchivedEpisodicRecord *record)
{
  const uint count = min(
    min(query_count, record->quantized_component_count), 16u
  );
  if (count == 0u || !isfinite(record->retrieval_key_scale)
      || record->retrieval_key_scale <= 0.0f) return 0.0f;
  float dot = 0.0f;
  float query_norm = 1.0e-6f;
  float key_norm = 1.0e-6f;
  for (uint component = 0u; component < count; ++component) {
    const float key = float(record->quantized_retrieval_key[component])
      * record->retrieval_key_scale;
    dot += query[component] * key;
    query_norm += query[component] * query[component];
    key_norm += key * key;
  }
  return dot * rsqrt(query_norm * key_norm);
}

template<typename Uniforms>
inline uint archive_storage_index_for_search_candidate(
  device const float *query,
  uint query_count,
  constant Uniforms &uniforms,
  uint search_index)
{
  const uint slots_per_cluster = uniforms.archive_episode_capacity
    / NB_MEMORY_ARCHIVE_CLUSTER_COUNT;
  const uint cluster_choice = search_index / slots_per_cluster;
  const uint within_cluster = search_index % slots_per_cluster;
  const uint primary_cluster = archive_query_cluster(query, query_count);
  const uint selected_cluster = cluster_choice == 0u
    ? primary_cluster
    : archive_secondary_query_cluster(query, query_count, primary_cluster);
  return selected_cluster
    + NB_MEMORY_ARCHIVE_CLUSTER_COUNT * within_cluster;
}

inline bool archive_page_is_resident_or_request(
  device uchar *hot_state,
  constant NBMemoryRetrievalUniforms &uniforms,
  uint archive_index,
  ulong target_record_identifier,
  float priority)
{
  if (uniforms.archive_records_per_page == 0u) return false;
  const uint page_identifier = archive_index / uniforms.archive_records_per_page;
  if (page_identifier >= uniforms.archive_page_count) return false;
  device atomic_uint *page_states =
    reinterpret_cast<device atomic_uint *>(
      hot_state + uniforms.archive_page_residency_offset
    );
  uint state = atomic_load_explicit(
    &page_states[page_identifier], memory_order_relaxed
  );
  if (state == 1u) return true;
  if (state != 0u) return false;
  uint expected = 0u;
  if (!atomic_compare_exchange_weak_explicit(
      &page_states[page_identifier], &expected, 2u,
      memory_order_relaxed, memory_order_relaxed
    )) return expected == 1u;

  device NBArchivePageRequestQueueHeader *queue =
    reinterpret_cast<device NBArchivePageRequestQueueHeader *>(
      hot_state + uniforms.archive_page_request_offset
    );
  const uint capacity = min(
    queue->request_capacity, uniforms.archive_page_request_capacity
  );
  uint count = atomic_load_explicit(&queue->request_count, memory_order_relaxed);
  uint slot = capacity;
  while (count < capacity) {
    uint desired = count + 1u;
    if (atomic_compare_exchange_weak_explicit(
        &queue->request_count, &count, desired,
        memory_order_relaxed, memory_order_relaxed
      )) {
      slot = count;
      break;
    }
  }
  if (slot >= capacity) {
    atomic_fetch_add_explicit(
      &queue->overflow_count, 1u, memory_order_relaxed
    );
    atomic_store_explicit(
      &page_states[page_identifier], 0u, memory_order_relaxed
    );
    return false;
  }
  device NBArchivePageRequestRecord *requests =
    reinterpret_cast<device NBArchivePageRequestRecord *>(queue + 1);
  NBArchivePageRequestRecord request = {};
  request.page_identifier = page_identifier;
  request.flags = 1u;
  request.requested_timestamp_microseconds =
    uniforms.target_timestamp_microseconds;
  request.target_record_identifier = target_record_identifier;
  request.priority = clamp(priority, 0.0f, 1.0f);
  requests[slot] = request;
  return false;
}

inline float archive_coarse_similarity(
  device const float *query,
  uint query_count,
  device const NBArchivedEpisodicRecord *record)
{
  const uint count = min(
    min(query_count, record->quantized_component_count), 8u
  );
  if (count == 0u) return 0.0f;
  uint sign_matches = 0u;
  for (uint component = 0u; component < count; ++component) {
    const bool query_positive = query[component] >= 0.0f;
    const bool record_positive = record->quantized_retrieval_key[component] >= 0;
    sign_matches += query_positive == record_positive ? 1u : 0u;
  }
  return float(sign_matches) / float(count);
}

template<typename Record, typename Uniforms>
inline bool append_memory_record(
  device NBMemoryJournalHeader *journal,
  constant Uniforms &uniforms,
  thread const Record &record,
  ulong destination,
  uint section,
  ulong identifier)
{
  constexpr uint chunk_byte_count = 16u;
  constexpr uint chunk_count = sizeof(Record) / chunk_byte_count;
  static_assert(sizeof(Record) % chunk_byte_count == 0u);
  if (destination + sizeof(Record) < destination
      || destination + sizeof(Record) > uniforms.persistent_memory_byte_count) {
    atomic_fetch_or_explicit(
      &journal->status, NB_MEMORY_JOURNAL_STATUS_CAPACITY, memory_order_relaxed
    );
    return false;
  }
  const uint first_entry = atomic_fetch_add_explicit(
    &journal->entry_count, chunk_count, memory_order_relaxed
  );
  if (first_entry + chunk_count > journal->entry_capacity
      || first_entry + chunk_count > uniforms.journal_entry_capacity) {
    atomic_fetch_or_explicit(
      &journal->status, NB_MEMORY_JOURNAL_STATUS_CAPACITY, memory_order_relaxed
    );
    return false;
  }
  device NBMemoryMutation *entries =
    reinterpret_cast<device NBMemoryMutation *>(journal + 1);
  const thread uint *words = reinterpret_cast<const thread uint *>(&record);
  for (uint chunk = 0u; chunk < chunk_count; ++chunk) {
    NBMemoryMutation mutation;
    mutation.destination_byte_offset = destination
      + ulong(chunk * chunk_byte_count);
    mutation.shadow_generation = uniforms.shadow_generation;
    for (uint word = 0u; word < 4u; ++word) {
      mutation.payload[word] = words[chunk * 4u + word];
    }
    mutation.byte_count = chunk_byte_count;
    mutation.section = section;
    mutation.sequence = chunk;
    mutation.flags = 0u;
    mutation.record_identifier = identifier;
    mutation.reserved = 0ul;
    entries[first_entry + chunk] = mutation;
  }
  return true;
}

inline void enqueue_semantic_consolidation_replay(
  device const uchar *persistent_memory,
  device NBMemoryJournalHeader *journal,
  constant NBMemoryConsolidationUniforms &uniforms,
  uint record_kind,
  ulong record_identifier,
  float confidence,
  uint supporting_episode_count)
{
  if (uniforms.replay_capacity == 0u || record_identifier == 0ul
      || (record_kind != 3u && record_kind != 4u)) return;
  NBReplayQueueSummaryRecord replay = {};
  replay.queue_kind = 5u;
  replay.record_kind = record_kind;
  replay.record_identifier = record_identifier;
  replay.priority = clamp(
    confidence + 0.1f * log2(float(supporting_episode_count) + 1.0f),
    0.0f,
    2.0f
  );
  replay.replay_count = 0u;
  replay.enqueued_timestamp_microseconds =
    uniforms.target_timestamp_microseconds;
  const uint replay_slot = uint(
    consolidation_hash(
      record_identifier ^ (ulong(record_kind) << 56)
        ^ 0x53454d414e544943ul
    ) % ulong(uniforms.replay_capacity)
  );
  const ulong replay_destination = uniforms.replay_memory_offset
    + ulong(replay_slot) * ulong(uniforms.replay_stride);
  device const NBReplayQueueSummaryRecord *existing =
    reinterpret_cast<device const NBReplayQueueSummaryRecord *>(
      persistent_memory + replay_destination
    );
  if (existing->record_identifier == 0ul
      || existing->record_identifier == record_identifier
      || existing->priority <= replay.priority) {
    append_memory_record(
      journal, uniforms, replay, replay_destination,
      NB_MEMORY_MUTATION_SECTION_REPLAY_QUEUE, record_identifier
    );
  }
}

inline bool journal_accumulated_episode(
  device uchar *hot_state,
  device const uchar *persistent_memory,
  device NBMemoryJournalHeader *journal,
  constant NBMemoryUniforms &uniforms,
  device const NBActiveEpisodeAccumulator *accumulator)
{
  if (accumulator->format_version != NB_MEMORY_EPISODE_RECORD_VERSION
      || accumulator->identifier == 0ul || accumulator->sample_count == 0u) {
    return false;
  }
  NBEpisodicSummaryRecord record = {};
  record.identifier = accumulator->identifier;
  record.start_timestamp_microseconds = accumulator->start_timestamp_microseconds;
  record.end_timestamp_microseconds = accumulator->last_timestamp_microseconds;
  record.parameter_version_fingerprint =
    accumulator->parameter_version_fingerprint;
  record.source_generation = uniforms.shadow_generation;
  record.active_goal_identifier = accumulator->active_goal_identifier;
  record.active_option_identifier = accumulator->active_option_identifier;
  record.format_version = NB_MEMORY_EPISODE_RECORD_VERSION;
  record.event_kind = accumulator->event_kind;
  record.source_identifier = accumulator->source_identifier;
  record.flags = accumulator->flags | 1u;
  record.salience = clamp(accumulator->maximum_salience, 0.0f, 1.0f);
  const float divisor = 1.0f / float(accumulator->sample_count);
  record.epistemic_uncertainty = accumulator->epistemic_sum * divisor;
  record.damage_severity = accumulator->maximum_damage;
  record.factored_reinforcement = accumulator->reinforcement_sum;
  for (uint index = 0u; index < 10u; ++index) {
    record.retrieval_key[index] = accumulator->retrieval_key_sum[index] * divisor;
  }

  const uint slot = uint(record.identifier % ulong(uniforms.active_episode_capacity));
  const ulong destination = uniforms.active_episode_memory_offset
    + ulong(slot) * ulong(uniforms.active_episode_stride);
  device const NBEpisodicSummaryRecord *displaced =
    reinterpret_cast<device const NBEpisodicSummaryRecord *>(
      persistent_memory + destination
    );
  NBEpisodicSummaryRecord compressed = *displaced;
  const bool should_compress = uniforms.compressed_episode_capacity > 0u
    && compressed.format_version == NB_MEMORY_EPISODE_RECORD_VERSION
    && compressed.identifier != 0ul && compressed.identifier != record.identifier;
  uint compressed_slot = 0u;
  ulong compressed_destination = 0ul;
  NBEpisodicSummaryRecord archive_source = {};
  bool should_archive = false;
  if (should_compress) {
    compressed_slot = uint(
      compressed.identifier % ulong(uniforms.compressed_episode_capacity)
    );
    compressed_destination = uniforms.compressed_episode_memory_offset
      + ulong(compressed_slot) * ulong(uniforms.compressed_episode_stride);
    device const NBEpisodicSummaryRecord *warm_displaced =
      reinterpret_cast<device const NBEpisodicSummaryRecord *>(
        persistent_memory + compressed_destination
      );
    archive_source = *warm_displaced;
    should_archive = uniforms.archive_episode_capacity
        >= NB_MEMORY_ARCHIVE_CLUSTER_COUNT
      && archive_source.format_version == NB_MEMORY_EPISODE_RECORD_VERSION
      && archive_source.identifier != 0ul
      && archive_source.identifier != compressed.identifier;
  }
  if (!append_memory_record(
      journal, uniforms, record, destination,
      NB_MEMORY_MUTATION_SECTION_ACTIVE_EPISODE, record.identifier
    )) {
    return false;
  }
  if (should_compress) {
    compressed.flags |= 2u;
    const bool compressed_written = append_memory_record(
      journal, uniforms, compressed, compressed_destination,
      NB_MEMORY_MUTATION_SECTION_COMPRESSED_EPISODE, compressed.identifier
    );
    if (compressed_written && should_archive) {
      const NBArchivedEpisodicRecord archived = compress_archived_episode(
        archive_source, uniforms.target_timestamp_microseconds
      );
      const uint slots_per_cluster = uniforms.archive_episode_capacity
        / NB_MEMORY_ARCHIVE_CLUSTER_COUNT;
      const uint archive_slot = archived.coarse_cluster
        + NB_MEMORY_ARCHIVE_CLUSTER_COUNT * uint(
          consolidation_hash(archived.identifier) % ulong(slots_per_cluster)
        );
      const ulong archive_destination = uniforms.archive_episode_memory_offset
        + ulong(archive_slot) * ulong(uniforms.archive_episode_stride);
      const bool archived_written = append_memory_record(
        journal, uniforms, archived, archive_destination,
        NB_MEMORY_MUTATION_SECTION_ARCHIVE_EPISODE, archived.identifier
      );
      if (archived_written && uniforms.archive_records_per_page > 0u) {
        advance_archive_page_epoch(
          hot_state,
          uniforms.archive_page_epoch_offset,
          uniforms.archive_page_count,
          archive_slot / uniforms.archive_records_per_page
        );
      }
    }
  }
  if (uniforms.replay_capacity > 0u) {
    const bool threat_or_failure = record.event_kind == 3u
      || record.event_kind == 5u || record.event_kind == 7u
      || record.event_kind == 8u || record.event_kind == 9u
      || record.event_kind == 12u || record.damage_severity > 0.20f;
    const uint queue_kind = threat_or_failure
      ? 3u : (record.salience >= 0.80f ? 6u : 1u);
    NBReplayQueueSummaryRecord replay = {};
    replay.queue_kind = queue_kind;
    replay.record_kind = 1u;
    replay.record_identifier = record.identifier;
    replay.priority = clamp(
      record.salience + 0.5f * record.epistemic_uncertainty
        + record.damage_severity + 0.25f * abs(record.factored_reinforcement),
      0.0f,
      2.0f
    );
    replay.replay_count = 0u;
    replay.enqueued_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    const uint replay_slot = uint(
      consolidation_hash(
        record.identifier ^ (ulong(queue_kind) << 56)
          ^ 0x455049534f444943ul
      ) % ulong(uniforms.replay_capacity)
    );
    const ulong replay_destination = uniforms.replay_memory_offset
      + ulong(replay_slot) * ulong(uniforms.replay_stride);
    device const NBReplayQueueSummaryRecord *existing_replay =
      reinterpret_cast<device const NBReplayQueueSummaryRecord *>(
        persistent_memory + replay_destination
      );
    if (existing_replay->record_identifier == 0ul
        || existing_replay->record_identifier == replay.record_identifier
        || existing_replay->priority <= replay.priority) {
      append_memory_record(
        journal, uniforms, replay, replay_destination,
        NB_MEMORY_MUTATION_SECTION_REPLAY_QUEUE, replay.record_identifier
      );
    }
  }
  return true;
}

inline float retrieval_similarity(
  device const float *query,
  uint query_count,
  device const float *key,
  uint key_count)
{
  const uint count = min(min(query_count, key_count), 32u);
  if (count == 0u) return 0.0f;
  float dot = 0.0f;
  float query_norm = 1.0e-6f;
  float key_norm = 1.0e-6f;
  for (uint index = 0u; index < count; ++index) {
    dot += query[index] * key[index];
    query_norm += query[index] * query[index];
    key_norm += key[index] * key[index];
  }
  return dot * rsqrt(query_norm * key_norm);
}

inline float procedural_similarity(
  thread const float *query,
  device const float *key,
  uint count)
{
  float dot = 0.0f;
  float query_norm = 1.0e-6f;
  float key_norm = 1.0e-6f;
  for (uint index = 0u; index < count; ++index) {
    dot += query[index] * key[index];
    query_norm += query[index] * query[index];
    key_norm += key[index] * key[index];
  }
  return dot * rsqrt(query_norm * key_norm);
}

kernel void begin_memory_retrieval(
  device uchar *hot_state [[buffer(0)]],
  device const uchar *persistent_memory [[buffer(1)]],
  constant NBMemoryRetrievalUniforms &uniforms [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.maximum_results || gid >= 4u) return;
  device NBMemoryRetrievalScratch *scratch =
    reinterpret_cast<device NBMemoryRetrievalScratch *>(
      hot_state + uniforms.retrieval_scratch_offset
    );
  atomic_store_explicit(&scratch->winner_keys[gid], 0u, memory_order_relaxed);
  scratch->winner_record_identifiers[gid] = 0ul;
  scratch->winner_kinds[gid] = 0u;
  scratch->winner_indices[gid] = 0u;
  scratch->winner_scores[gid] = 0.0f;
  if (gid == 0u) scratch->flags = 0u;
}

kernel void clear_archive_retrieval_shortlist(
  device uchar *hot_state [[buffer(0)]],
  device const uchar *persistent_memory [[buffer(1)]],
  constant NBMemoryRetrievalUniforms &uniforms [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= NB_MEMORY_ARCHIVE_SHORTLIST_COUNT) return;
  device NBMemoryRetrievalScratch *scratch =
    reinterpret_cast<device NBMemoryRetrievalScratch *>(
      hot_state + uniforms.retrieval_scratch_offset
    );
  atomic_store_explicit(
    &scratch->archive_shortlist_keys[gid], 0u, memory_order_relaxed
  );
}

/// Coarse cluster-local archive selection. Each deterministic shard retains
/// one candidate using only key signs, salience, and uncertainty; fine vector
/// similarity is intentionally deferred to the bounded rerank kernel.
kernel void score_archive_retrieval_shortlist(
  device uchar *hot_state [[buffer(0)]],
  device const uchar *persistent_memory [[buffer(1)]],
  constant NBMemoryRetrievalUniforms &uniforms [[buffer(2)]],
  device const float *memory_parameters [[buffer(6)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.archive_search_candidate_count
      || uniforms.retrieval_pass >= min(uniforms.maximum_results, 4u)) return;
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  device const NBInternalActionRecord *internal_actions =
    reinterpret_cast<device const NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  if (development->stage < 7u || internal_actions[0].kind != 1u
      || (internal_actions[0].flags & NB_MEMORY_CONTROL_FLAG_VALID) == 0u) return;

  device NBMemoryRetrievalScratch *scratch =
    reinterpret_cast<device NBMemoryRetrievalScratch *>(
      hot_state + uniforms.retrieval_scratch_offset
    );
  const uint global_index = uniforms.active_episode_capacity
    + uniforms.compressed_episode_capacity + gid;
  for (uint pass = 0u; pass < uniforms.retrieval_pass; ++pass) {
    const uint previous_key = atomic_load_explicit(
      &scratch->winner_keys[pass], memory_order_relaxed
    );
    if (previous_key != 0u
        && 0xfffffu - (previous_key & 0xfffffu) == global_index) return;
  }

  device const float *query = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  const uint archive_index = archive_storage_index_for_search_candidate(
    query, uniforms.recurrent_scalar_count, uniforms, gid
  );
  if (!archive_page_is_resident_or_request(
      hot_state, uniforms, archive_index,
      internal_actions[0].target_identifier,
      internal_actions[0].priority
    )) return;
  device const NBArchivedEpisodicRecord *record =
    reinterpret_cast<device const NBArchivedEpisodicRecord *>(
      persistent_memory + uniforms.archive_episode_memory_offset
        + ulong(archive_index) * ulong(uniforms.archive_episode_stride)
    );
  if (record->format_version != NB_MEMORY_EPISODE_RECORD_VERSION
      || record->identifier == 0ul) return;
  const uint expected_cluster = archive_query_cluster(
    query, uniforms.recurrent_scalar_count
  );
  const uint selected_cluster = gid
      < uniforms.archive_search_candidate_count / 2u
    ? expected_cluster
    : archive_secondary_query_cluster(
        query, uniforms.recurrent_scalar_count, expected_cluster
      );
  if (record->coarse_cluster != selected_cluster) return;

  const float coarse_score = archive_coarse_similarity(
    query, uniforms.recurrent_scalar_count, record
  ) + 0.25f * record->salience
    - 0.10f * max(memory_parameters[6], 0.0f)
      * record->epistemic_uncertainty
    + (((internal_actions[0].target_identifier & 0xf000000000000000ul)
          == 0x1000000000000000ul
        && (record->flags & (1u << 8u)) != 0u
        && record->source_identifier == uint(
          internal_actions[0].target_identifier
            ^ (internal_actions[0].target_identifier >> 32u)
        )) ? 1.0f : 0.0f);
  if (!isfinite(coarse_score)) return;
  const uint quantized_score = min(
    uint(clamp(coarse_score / 1.25f, 0.0f, 1.0f) * 4095.0f), 4095u
  );
  const uint key = (quantized_score << 20) | (0xfffffu - gid);
  atomic_fetch_max_explicit(
    &scratch->archive_shortlist_keys[gid % NB_MEMORY_ARCHIVE_SHORTLIST_COUNT],
    key,
    memory_order_relaxed
  );
}

/// Fine rerank of the bounded archive shortlist. The resulting key uses the
/// global candidate index so publication and duplicate suppression remain
/// identical across every memory tier.
kernel void rerank_archive_retrieval_shortlist(
  device uchar *hot_state [[buffer(0)]],
  device const uchar *persistent_memory [[buffer(1)]],
  constant NBMemoryRetrievalUniforms &uniforms [[buffer(2)]],
  device const float *memory_parameters [[buffer(6)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= NB_MEMORY_ARCHIVE_SHORTLIST_COUNT
      || uniforms.retrieval_pass >= min(uniforms.maximum_results, 4u)) return;
  device NBMemoryRetrievalScratch *scratch =
    reinterpret_cast<device NBMemoryRetrievalScratch *>(
      hot_state + uniforms.retrieval_scratch_offset
    );
  const uint shortlist_key = atomic_load_explicit(
    &scratch->archive_shortlist_keys[gid], memory_order_relaxed
  );
  if (shortlist_key == 0u) return;
  const uint search_index = 0xfffffu - (shortlist_key & 0xfffffu);
  const uint global_index = uniforms.active_episode_capacity
    + uniforms.compressed_episode_capacity + search_index;
  device const float *query = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  const uint archive_index = archive_storage_index_for_search_candidate(
    query, uniforms.recurrent_scalar_count, uniforms, search_index
  );
  device const NBArchivedEpisodicRecord *record =
    reinterpret_cast<device const NBArchivedEpisodicRecord *>(
      persistent_memory + uniforms.archive_episode_memory_offset
        + ulong(archive_index) * ulong(uniforms.archive_episode_stride)
    );
  if (record->format_version != NB_MEMORY_EPISODE_RECORD_VERSION
      || record->identifier == 0ul) return;
  const NBInternalActionRecord retrieval_request =
    reinterpret_cast<device const NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    )[0];
  float score = 0.65f * uniforms.episodic_weight
    * max(memory_parameters[0], 0.0f) * (
      archive_retrieval_similarity(
        query, uniforms.recurrent_scalar_count, record
      ) + record->salience
        - max(memory_parameters[6], 0.0f) * record->epistemic_uncertainty
    );
  if ((retrieval_request.target_identifier & 0xf000000000000000ul)
        == 0x1000000000000000ul
      && (record->flags & (1u << 8u)) != 0u
      && record->source_identifier == uint(
        retrieval_request.target_identifier
          ^ (retrieval_request.target_identifier >> 32u)
      )) score += 1.0f;
  if (record->identifier == retrieval_request.target_identifier) score += 1.0f;
  score += 0.25f * retrieval_request.priority;
  if (!isfinite(score) || score < uniforms.minimum_score) return;
  const float normalized = clamp(
    (score - uniforms.minimum_score) / (16.0f + abs(uniforms.minimum_score)),
    0.0f,
    1.0f
  );
  const uint quantized_score = min(uint(normalized * 4095.0f), 4095u);
  const uint key = (quantized_score << 20) | (0xfffffu - global_index);
  atomic_fetch_max_explicit(
    &scratch->winner_keys[uniforms.retrieval_pass], key, memory_order_relaxed
  );
}

kernel void score_memory_retrieval_candidates(
  device uchar *hot_state [[buffer(0)]],
  device const uchar *persistent_memory [[buffer(1)]],
  constant NBMemoryRetrievalUniforms &uniforms [[buffer(2)]],
  device const float *memory_parameters [[buffer(6)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.candidate_count
      || uniforms.retrieval_pass >= min(uniforms.maximum_results, 4u)) return;
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  if (development->stage < 7u) return;
  device const NBInternalActionRecord *internal_actions =
    reinterpret_cast<device const NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  const NBInternalActionRecord retrieval_request = internal_actions[0];
  if (retrieval_request.kind != 1u
      || (retrieval_request.flags & NB_MEMORY_CONTROL_FLAG_VALID) == 0u) return;
  device NBMemoryRetrievalScratch *scratch =
    reinterpret_cast<device NBMemoryRetrievalScratch *>(
      hot_state + uniforms.retrieval_scratch_offset
    );
  for (uint pass = 0u; pass < uniforms.retrieval_pass; ++pass) {
    const uint previous_key = atomic_load_explicit(
      &scratch->winner_keys[pass], memory_order_relaxed
    );
    if (previous_key != 0u
        && 0xfffffu - (previous_key & 0xfffffu) == gid) return;
  }
  device const float *query = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  uint kind = 0u;
  ulong identifier = 0ul;
  uint episodic_source_identifier = 0u;
  uint episodic_flags = 0u;
  float score = -INFINITY;
  uint local_index = gid;
  if (local_index < uniforms.active_episode_capacity) {
    device const NBEpisodicSummaryRecord *record =
      reinterpret_cast<device const NBEpisodicSummaryRecord *>(
        persistent_memory + uniforms.active_episode_memory_offset
          + ulong(local_index) * ulong(uniforms.active_episode_stride)
      );
    if (record->format_version == NB_MEMORY_EPISODE_RECORD_VERSION
        && record->identifier != 0ul) {
      kind = 1u;
      identifier = record->identifier;
      episodic_source_identifier = record->source_identifier;
      episodic_flags = record->flags;
      score = uniforms.episodic_weight * max(memory_parameters[0], 0.0f) * (
        retrieval_similarity(
          query, uniforms.recurrent_scalar_count, record->retrieval_key, 10u
        ) + record->salience
          - max(memory_parameters[6], 0.0f) * record->epistemic_uncertainty
      );
    }
  } else {
    local_index -= uniforms.active_episode_capacity;
    if (local_index < uniforms.compressed_episode_capacity) {
      device const NBEpisodicSummaryRecord *record =
        reinterpret_cast<device const NBEpisodicSummaryRecord *>(
          persistent_memory + uniforms.compressed_episode_memory_offset
            + ulong(local_index) * ulong(uniforms.compressed_episode_stride)
        );
      if (record->format_version == NB_MEMORY_EPISODE_RECORD_VERSION
          && record->identifier != 0ul) {
        kind = 6u;
        identifier = record->identifier;
        episodic_source_identifier = record->source_identifier;
        episodic_flags = record->flags;
        score = 0.85f * uniforms.episodic_weight
          * max(memory_parameters[0], 0.0f) * (
            retrieval_similarity(
              query, uniforms.recurrent_scalar_count, record->retrieval_key, 10u
            ) + record->salience
              - max(memory_parameters[6], 0.0f)
                * record->epistemic_uncertainty
          );
      }
    } else {
      local_index -= uniforms.compressed_episode_capacity;
    if (local_index < uniforms.archive_search_candidate_count) {
      // Tier-2 is scored by the coarse shortlist and bounded fine-rerank
      // kernels. Keeping its global index range here preserves deterministic
      // winner identities without paying a fine-vector score in this pass.
    } else {
      local_index -= uniforms.archive_search_candidate_count;
    if (local_index < uniforms.semantic_capacity) {
      device const NBSemanticConceptSummaryRecord *record =
        reinterpret_cast<device const NBSemanticConceptSummaryRecord *>(
          persistent_memory + uniforms.semantic_memory_offset
            + ulong(local_index) * ulong(uniforms.semantic_stride)
        );
      if (record->format_version == 1u && record->identifier != 0ul) {
        kind = 2u;
        identifier = record->identifier;
        score = uniforms.semantic_weight * max(memory_parameters[1], 0.0f) * (
          retrieval_similarity(
            query, uniforms.recurrent_scalar_count, record->embedding, 19u
          ) + record->confidence
        );
      }
    } else {
      local_index -= uniforms.semantic_capacity;
      if (local_index < uniforms.semantic_relation_capacity) {
        device const NBSemanticRelationSummaryRecord *record =
          reinterpret_cast<device const NBSemanticRelationSummaryRecord *>(
            persistent_memory + uniforms.semantic_relation_memory_offset
              + ulong(local_index) * ulong(uniforms.semantic_relation_stride)
          );
        if (record->format_version == 1u && record->identifier != 0ul) {
          kind = 5u;
          identifier = record->identifier;
          score = uniforms.semantic_weight * max(memory_parameters[1], 0.0f) * (
            retrieval_similarity(
              query, uniforms.recurrent_scalar_count,
              record->evidence_embedding, 10u
            ) + record->confidence - record->contradiction
          );
        }
      } else {
        local_index -= uniforms.semantic_relation_capacity;
        if (local_index < uniforms.procedural_capacity) {
        device const NBProceduralSkillSummaryRecord *record =
          reinterpret_cast<device const NBProceduralSkillSummaryRecord *>(
            persistent_memory + uniforms.procedural_memory_offset
              + ulong(local_index) * ulong(uniforms.procedural_stride)
          );
        if (record->format_version == NB_PROCEDURAL_SKILL_RECORD_VERSION
            && record->identifier != 0ul
            && (record->flags & NB_PROCEDURAL_SKILL_RETIRED) == 0u) {
          kind = 3u;
          identifier = record->identifier;
          score = uniforms.procedural_weight * max(memory_parameters[2], 0.0f) * (
            0.55f * retrieval_similarity(
              query, uniforms.recurrent_scalar_count,
              record->initiation_model, 16u
            ) + 0.45f * retrieval_similarity(
              query, uniforms.recurrent_scalar_count, record->policy_code, 16u
            ) + record->competence + 0.25f * record->initiation_confidence
              - record->damage_cvar - 0.25f * record->outcome_uncertainty
          );
        }
        } else {
          local_index -= uniforms.procedural_capacity;
          if (local_index < uniforms.prospective_capacity) {
          device const NBProspectiveIntentionSummaryRecord *record =
            reinterpret_cast<device const NBProspectiveIntentionSummaryRecord *>(
              persistent_memory + uniforms.prospective_memory_offset
                + ulong(local_index) * ulong(uniforms.prospective_stride)
            );
          if (record->format_version == NB_MEMORY_RECORD_VERSION
              && record->identifier != 0ul
              && (record->status == 1u || record->status == 2u)) {
            const bool before_deadline =
              record->deadline_timestamp_microseconds == 0ul
                || uniforms.target_timestamp_microseconds
                  <= record->deadline_timestamp_microseconds;
            const float trigger_match = retrieval_similarity(
              query, uniforms.recurrent_scalar_count, record->trigger_code, 16u
            );
            const float trigger_threshold = clamp(
              record->trigger_confidence, 0.0f, 1.0f
            );
            const bool trigger_detected = record->status == 2u
              || trigger_match >= trigger_threshold;
            if (!before_deadline || !trigger_detected) return;
            kind = 4u;
            identifier = record->identifier;
            // Once an intention is active, lifecycle context_match supplies
            // persistence even if active sensing temporarily moves the live
            // recurrent state away from the original trigger context.
            const float effective_match = record->status == 2u
              ? max(trigger_match, record->context_match) : trigger_match;
            score = uniforms.prospective_weight * max(memory_parameters[3], 0.0f) * (
              effective_match + record->priority + record->trigger_confidence
                + (record->status == 2u ? 0.15f : 0.0f)
            );
          }
          }
        }
      }
    }
    }
    }
  }
  if ((retrieval_request.target_identifier & 0xf000000000000000ul)
        == 0x1000000000000000ul
      && (episodic_flags & (1u << 8u)) != 0u
      && episodic_source_identifier == uint(
        retrieval_request.target_identifier
          ^ (retrieval_request.target_identifier >> 32u)
      )) score += 1.0f;
  if (identifier == retrieval_request.target_identifier) score += 1.0f;
  score += 0.25f * retrieval_request.priority;
  if (kind == 0u || !isfinite(score) || score < uniforms.minimum_score) return;
  const float normalized = clamp(
    (score - uniforms.minimum_score) / (16.0f + abs(uniforms.minimum_score)),
    0.0f,
    1.0f
  );
  const uint quantized_score = min(uint(normalized * 4095.0f), 4095u);
  const uint key = (quantized_score << 20) | (0xfffffu - gid);
  atomic_fetch_max_explicit(
    &scratch->winner_keys[uniforms.retrieval_pass],
    key,
    memory_order_relaxed
  );
}

kernel void publish_memory_retrieval_winner(
  device uchar *hot_state [[buffer(0)]],
  device const uchar *persistent_memory [[buffer(1)]],
  constant NBMemoryRetrievalUniforms &uniforms [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.retrieval_pass >= min(uniforms.maximum_results, 4u)) return;
  device NBMemoryRetrievalScratch *scratch =
    reinterpret_cast<device NBMemoryRetrievalScratch *>(
      hot_state + uniforms.retrieval_scratch_offset
    );
  const uint key = atomic_load_explicit(
    &scratch->winner_keys[uniforms.retrieval_pass], memory_order_relaxed
  );
  if (key == 0u) return;
  const uint candidate_index = 0xfffffu - (key & 0xfffffu);
  const float retrieval_relevance = float((key >> 20u) & 0xfffu) / 4095.0f;
  uint kind = 0u;
  ulong identifier = 0ul;
  float score = 0.0f;
  device const float *value = nullptr;
  device const NBEpisodicSummaryRecord *episodic_value = nullptr;
  device const NBArchivedEpisodicRecord *archived_value = nullptr;
  device const NBSemanticConceptSummaryRecord *semantic_value = nullptr;
  device const NBSemanticRelationSummaryRecord *semantic_relation_value = nullptr;
  device const NBProceduralSkillSummaryRecord *procedural_value = nullptr;
  device const NBProspectiveIntentionSummaryRecord *prospective_value = nullptr;
  uint value_count = 0u;
  device const float *query = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  device const NBControlHeader *control =
    reinterpret_cast<device const NBControlHeader *>(
      hot_state + uniforms.control_header_offset
    );
  uint local_index = candidate_index;
  if (local_index < uniforms.active_episode_capacity) {
    device const NBEpisodicSummaryRecord *record =
      reinterpret_cast<device const NBEpisodicSummaryRecord *>(
        persistent_memory + uniforms.active_episode_memory_offset
          + ulong(local_index) * ulong(uniforms.active_episode_stride)
      );
    kind = 1u;
    identifier = record->identifier;
    score = record->salience;
    episodic_value = record;
    value = record->retrieval_key;
    value_count = 14u;
  } else {
    local_index -= uniforms.active_episode_capacity;
    if (local_index < uniforms.compressed_episode_capacity) {
      device const NBEpisodicSummaryRecord *record =
        reinterpret_cast<device const NBEpisodicSummaryRecord *>(
          persistent_memory + uniforms.compressed_episode_memory_offset
            + ulong(local_index) * ulong(uniforms.compressed_episode_stride)
        );
      kind = 6u;
      identifier = record->identifier;
      score = record->salience;
      episodic_value = record;
      value = record->retrieval_key;
      value_count = 14u;
    } else {
      local_index -= uniforms.compressed_episode_capacity;
    if (local_index < uniforms.archive_search_candidate_count) {
      const uint slots_per_cluster = uniforms.archive_episode_capacity
        / NB_MEMORY_ARCHIVE_CLUSTER_COUNT;
      const uint cluster_choice = local_index / slots_per_cluster;
      const uint within_cluster = local_index % slots_per_cluster;
      const uint primary_cluster = archive_query_cluster(
        query, uniforms.recurrent_scalar_count
      );
      const uint selected_cluster = cluster_choice == 0u
        ? primary_cluster
        : archive_secondary_query_cluster(
            query, uniforms.recurrent_scalar_count, primary_cluster
          );
      const uint archive_index = selected_cluster
        + NB_MEMORY_ARCHIVE_CLUSTER_COUNT * within_cluster;
      archived_value = reinterpret_cast<device const NBArchivedEpisodicRecord *>(
        persistent_memory + uniforms.archive_episode_memory_offset
          + ulong(archive_index) * ulong(uniforms.archive_episode_stride)
      );
      kind = 7u;
      identifier = archived_value->identifier;
      score = archived_value->salience;
      value_count = 14u;
    } else {
      local_index -= uniforms.archive_search_candidate_count;
    if (local_index < uniforms.semantic_capacity) {
      device const NBSemanticConceptSummaryRecord *record =
        reinterpret_cast<device const NBSemanticConceptSummaryRecord *>(
          persistent_memory + uniforms.semantic_memory_offset
            + ulong(local_index) * ulong(uniforms.semantic_stride)
        );
      kind = 2u;
      identifier = record->identifier;
      score = record->confidence;
      semantic_value = record;
      value = record->embedding;
      value_count = 19u;
    } else {
      local_index -= uniforms.semantic_capacity;
      if (local_index < uniforms.semantic_relation_capacity) {
        device const NBSemanticRelationSummaryRecord *record =
          reinterpret_cast<device const NBSemanticRelationSummaryRecord *>(
            persistent_memory + uniforms.semantic_relation_memory_offset
              + ulong(local_index) * ulong(uniforms.semantic_relation_stride)
          );
        kind = 5u;
        identifier = record->identifier;
        score = record->confidence;
        semantic_relation_value = record;
        value = record->evidence_embedding;
        value_count = 10u;
      } else {
        local_index -= uniforms.semantic_relation_capacity;
        if (local_index < uniforms.procedural_capacity) {
        device const NBProceduralSkillSummaryRecord *record =
          reinterpret_cast<device const NBProceduralSkillSummaryRecord *>(
            persistent_memory + uniforms.procedural_memory_offset
              + ulong(local_index) * ulong(uniforms.procedural_stride)
          );
        kind = 3u;
        identifier = record->identifier;
        score = record->competence;
        procedural_value = record;
        value_count = 80u;
        } else {
          local_index -= uniforms.procedural_capacity;
          device const NBProspectiveIntentionSummaryRecord *record =
          reinterpret_cast<device const NBProspectiveIntentionSummaryRecord *>(
            persistent_memory + uniforms.prospective_memory_offset
              + ulong(local_index) * ulong(uniforms.prospective_stride)
          );
          kind = 4u;
          identifier = record->identifier;
          score = record->priority;
          prospective_value = record;
          value = record->trigger_code;
          value_count = 16u;
        }
      }
    }
    }
    }
  }
  const uint slot = 3u + uniforms.retrieval_pass;
  if (slot >= uniforms.workspace_capacity) return;
  device float *workspace = reinterpret_cast<device float *>(
    hot_state + uniforms.workspace_content_offset
  );
  const uint base = slot * uniforms.workspace_dimension;
  uint procedural_phase = 0u;
  float procedural_total_duration = 0.0f;
  bool procedural_complete = false;
  if (procedural_value != nullptr && procedural_value->phase_count > 0u) {
    const uint phase_count = min(procedural_value->phase_count, 8u);
    const bool continuing = control->active_option_identifier
      == procedural_value->identifier;
    const float elapsed = continuing
        && uniforms.target_timestamp_microseconds
          >= control->selected_timestamp_microseconds
      ? float(uniforms.target_timestamp_microseconds
          - control->selected_timestamp_microseconds) * 1.0e-6f
      : 0.0f;
    float boundary = 0.0f;
    for (uint phase = 0u; phase < phase_count; ++phase) {
      boundary += max(procedural_value->phase_durations[phase], 0.0f);
      if (elapsed >= boundary && phase + 1u < phase_count) {
        procedural_phase = phase + 1u;
      }
    }
    procedural_total_duration = boundary;
    procedural_complete = continuing && elapsed >= boundary && boundary > 0.0f;
  }
  for (uint index = 0u; index < uniforms.workspace_dimension; ++index) {
    if ((kind == 1u || kind == 6u) && episodic_value != nullptr) {
      float episodic_component = 0.0f;
      if (index < 10u) {
        episodic_component = episodic_value->retrieval_key[index];
      } else if (index == 10u) {
        episodic_component = episodic_value->salience;
      } else if (index == 11u) {
        episodic_component = episodic_value->epistemic_uncertainty;
      } else if (index == 12u) {
        episodic_component = episodic_value->damage_severity;
      } else if (index == 13u) {
        episodic_component = episodic_value->factored_reinforcement;
      }
      workspace[base + index] = episodic_component;
    } else if (kind == 7u && archived_value != nullptr) {
      float archived_component = 0.0f;
      if (index < min(archived_value->quantized_component_count, 10u)) {
        archived_component = float(archived_value->quantized_retrieval_key[index])
          * archived_value->retrieval_key_scale;
      } else if (index == 10u) {
        archived_component = archived_value->salience;
      } else if (index == 11u) {
        archived_component = archived_value->epistemic_uncertainty;
      } else if (index == 12u) {
        archived_component = archived_value->damage_severity;
      } else if (index == 13u) {
        archived_component = archived_value->factored_reinforcement;
      }
      workspace[base + index] = archived_component;
    } else if (kind == 5u && semantic_relation_value != nullptr) {
      float relation_component = 0.0f;
      if (index < 10u) {
        relation_component =
          semantic_relation_value->evidence_embedding[index];
      } else if (index == 10u) {
        relation_component = semantic_relation_value->confidence;
      } else if (index == 11u) {
        relation_component = semantic_relation_value->contradiction;
      } else if (index == 12u) {
        relation_component = float(semantic_relation_value->kind) / 32.0f;
      } else if (index == 13u) {
        relation_component = 1.0f - exp(
          -float(semantic_relation_value->supporting_episode_count) / 8.0f
        );
      }
      workspace[base + index] = relation_component;
    } else if (kind == 3u && procedural_value != nullptr) {
      float procedural_component = 0.0f;
      if (index < 16u) {
        procedural_component = procedural_value->phase_count > 0u
          ? procedural_value->phase_parameters[procedural_phase][index]
          : procedural_value->policy_code[index];
      } else if (index < 32u) {
        procedural_component = procedural_value->initiation_model[index - 16u];
      } else if (index < 40u) {
        procedural_component = procedural_value->termination_model[index - 32u];
      } else if (index < 56u) {
        procedural_component = procedural_value->outcome_model[index - 40u];
      } else if (index == 56u) {
        procedural_component = procedural_value->competence;
      } else if (index == 57u) {
        procedural_component = procedural_value->damage_cvar;
      } else if (index == 58u) {
        procedural_component = procedural_value->expected_effort;
      } else if (index == 59u) {
        procedural_component = procedural_value->expected_value;
      } else if (index == 60u) {
        procedural_component = procedural_value->initiation_confidence;
      } else if (index == 61u) {
        procedural_component = procedural_value->termination_confidence;
      } else if (index == 62u) {
        procedural_component = procedural_value->outcome_uncertainty;
      } else if (index == 63u) {
        procedural_component = procedural_value->adaptation_rate;
      } else if (index < 72u) {
        procedural_component = procedural_value->expected_factored_value[index - 64u];
      } else if (index < 76u) {
        procedural_component = procedural_value->adaptation_state[index - 72u];
      } else if (index == 76u) {
        procedural_component = float(procedural_phase);
      } else if (index == 77u) {
        procedural_component = float(procedural_value->phase_count);
      } else if (index == 78u) {
        procedural_component = procedural_complete ? 1.0f : 0.0f;
      } else if (index == 79u) {
        procedural_component = procedural_total_duration;
      }
      workspace[base + index] = procedural_component;
    } else {
      workspace[base + index] = index < value_count ? value[index] : 0.0f;
    }
  }
  device NBWorkspaceMetadataRecord *metadata =
    reinterpret_cast<device NBWorkspaceMetadataRecord *>(
      hot_state + uniforms.workspace_metadata_offset
    );
  NBWorkspaceMetadataRecord token = {};
  token.identifier = (uniforms.target_timestamp_microseconds << 8) | ulong(slot + 1u);
  token.source_timestamp_microseconds = episodic_value != nullptr
    ? episodic_value->end_timestamp_microseconds
    : (archived_value != nullptr
      ? archived_value->end_timestamp_microseconds
      : (prospective_value != nullptr
        ? prospective_value->created_timestamp_microseconds
        : uniforms.target_timestamp_microseconds));
  token.last_refresh_timestamp_microseconds = uniforms.target_timestamp_microseconds;
  token.entity_identifier = identifier;
  token.goal_identifier = episodic_value != nullptr
    ? episodic_value->active_goal_identifier
    : (archived_value != nullptr
      ? archived_value->active_goal_identifier
      : (semantic_value != nullptr && semantic_value->kind == 6u
        ? semantic_value->identifier
        : (semantic_relation_value != nullptr
          ? semantic_relation_value->source_concept_identifier
      : (prospective_value != nullptr
        ? prospective_value->goal_identifier
        : (kind == 3u && procedural_value != nullptr
          ? procedural_value->initiation_goal_identifier : 0ul)))));
  token.bound_token_identifier = episodic_value != nullptr
    ? episodic_value->active_option_identifier
    : (archived_value != nullptr
      ? archived_value->active_option_identifier
      : (semantic_relation_value != nullptr
        ? semantic_relation_value->destination_concept_identifier : 0ul));
  token.provenance_record_identifier = identifier;
  const uint source_module = kind == 2u
    ? 58u
    : (kind == 5u ? 59u
      : (kind == 3u ? 60u : (kind == 4u ? 61u : 56u)));
  token.kind_and_source = 5u | (source_module << 16);
  token.confidence = sqrt(
    clamp(score, 0.0f, 1.0f) * clamp(retrieval_relevance, 0.0f, 1.0f)
  );
  metadata[slot] = token;
  scratch->winner_record_identifiers[uniforms.retrieval_pass] = identifier;
  scratch->winner_kinds[uniforms.retrieval_pass] = kind;
  scratch->winner_indices[uniforms.retrieval_pass] = candidate_index;
  scratch->winner_scores[uniforms.retrieval_pass] = retrieval_relevance;
  scratch->flags |= 1u << uniforms.retrieval_pass;
}

inline float accepted_memory_evidence_component(
  device const float *recurrent,
  uint recurrent_count,
  device const float *observations,
  uint observation_count,
  uint component)
{
  const float recurrent_value = recurrent_count > 0u
    ? recurrent[component % recurrent_count] : 0.0f;
  const float observation_value = observation_count > 0u
    ? observations[component % observation_count] : recurrent_value;
  return 0.65f * recurrent_value + 0.35f * observation_value;
}

inline float accepted_memory_similarity(
  device const float *recurrent,
  uint recurrent_count,
  device const float *observations,
  uint observation_count,
  device const float *key,
  uint key_count)
{
  const uint count = min(key_count, 32u);
  if (count == 0u) return 0.0f;
  float dot = 0.0f;
  float evidence_norm = 1.0e-6f;
  float key_norm = 1.0e-6f;
  for (uint component = 0u; component < count; ++component) {
    const float evidence = accepted_memory_evidence_component(
      recurrent, recurrent_count, observations, observation_count, component
    );
    dot += evidence * key[component];
    evidence_norm += evidence * evidence;
    key_norm += key[component] * key[component];
  }
  return dot * rsqrt(evidence_norm * key_norm);
}

inline float accepted_archive_memory_similarity(
  device const float *recurrent,
  uint recurrent_count,
  device const float *observations,
  uint observation_count,
  device const NBArchivedEpisodicRecord *record)
{
  const uint count = min(record->quantized_component_count, 16u);
  if (count == 0u || !isfinite(record->retrieval_key_scale)
      || record->retrieval_key_scale <= 0.0f) return 0.0f;
  float dot = 0.0f;
  float evidence_norm = 1.0e-6f;
  float key_norm = 1.0e-6f;
  for (uint component = 0u; component < count; ++component) {
    const float evidence = accepted_memory_evidence_component(
      recurrent, recurrent_count, observations, observation_count, component
    );
    const float key = float(record->quantized_retrieval_key[component])
      * record->retrieval_key_scale;
    dot += evidence * key;
    evidence_norm += evidence * evidence;
    key_norm += key * key;
  }
  return dot * rsqrt(evidence_norm * key_norm);
}

/// Accepted-evidence reconsolidation of the bounded records recalled by this
/// root. Identity, original time, source generation, and parameter provenance
/// are copied unchanged; the reconsolidated flag records that content or
/// confidence has been revised after retrieval.
kernel void reconsolidate_retrieved_memory(
  device uchar *hot_state [[buffer(0)]],
  device const uchar *persistent_memory [[buffer(1)]],
  device NBMemoryJournalHeader *journal [[buffer(2)]],
  constant NBMemoryReconsolidationUniforms &uniforms [[buffer(3)]],
  device const float *memory_parameters [[buffer(6)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= min(uniforms.maximum_results, 4u)) return;
  if (journal->base_generation != uniforms.base_generation
      || journal->shadow_generation != uniforms.shadow_generation
      || journal->memory_byte_count != uniforms.persistent_memory_byte_count) {
    atomic_fetch_or_explicit(
      &journal->status, NB_MEMORY_JOURNAL_STATUS_CAPACITY, memory_order_relaxed
    );
    return;
  }
  device NBMemoryRetrievalScratch *scratch =
    reinterpret_cast<device NBMemoryRetrievalScratch *>(
      hot_state + uniforms.retrieval_scratch_offset
    );
  if ((scratch->flags & (1u << gid)) == 0u) return;
  const uint kind = scratch->winner_kinds[gid];
  const uint candidate_index = scratch->winner_indices[gid];
  const ulong identifier = scratch->winner_record_identifiers[gid];
  if (kind == 0u || identifier == 0ul) return;

  device const float *recurrent = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  device const float *observations = reinterpret_cast<device const float *>(
    hot_state + uniforms.observation_offset
  );
  const float rate = clamp(
    min(uniforms.learning_rate, max(memory_parameters[4], 0.0f)),
    0.0f,
    1.0f
  );
  if (rate <= 0.0f) return;

  if (kind == 1u || kind == 6u) {
    uint local_index = candidate_index;
    ulong base_offset = uniforms.active_episode_memory_offset;
    uint stride = uniforms.active_episode_stride;
    uint capacity = uniforms.active_episode_capacity;
    if (kind == 6u) {
      if (local_index < uniforms.active_episode_capacity) return;
      local_index -= uniforms.active_episode_capacity;
      base_offset = uniforms.compressed_episode_memory_offset;
      stride = uniforms.compressed_episode_stride;
      capacity = uniforms.compressed_episode_capacity;
    }
    if (local_index >= capacity) return;
    const ulong destination = base_offset + ulong(local_index) * ulong(stride);
    device const NBEpisodicSummaryRecord *record =
      reinterpret_cast<device const NBEpisodicSummaryRecord *>(
        persistent_memory + destination
      );
    if (record->identifier != identifier
        || record->format_version != NB_MEMORY_EPISODE_RECORD_VERSION) return;
    NBEpisodicSummaryRecord updated = *record;
    const float similarity = accepted_memory_similarity(
      recurrent, uniforms.recurrent_scalar_count,
      observations, uniforms.observation_count,
      record->retrieval_key, 10u
    );
    float content_rate = rate * 0.5f;
    if (similarity >= uniforms.confirmation_similarity) {
      updated.epistemic_uncertainty = max(
        record->epistemic_uncertainty * (1.0f - rate), 0.0f
      );
      content_rate = rate;
    } else if (similarity <= uniforms.conflict_similarity) {
      updated.epistemic_uncertainty = record->epistemic_uncertainty
        + rate * (1.0f + abs(similarity));
      content_rate = rate * 0.25f;
    }
    for (uint component = 0u; component < 10u; ++component) {
      const float evidence = accepted_memory_evidence_component(
        recurrent, uniforms.recurrent_scalar_count,
        observations, uniforms.observation_count, component
      );
      updated.retrieval_key[component] = mix(
        record->retrieval_key[component], evidence, content_rate
      );
    }
    updated.flags = record->flags | 8u;
    append_memory_record(
      journal, uniforms, updated, destination,
      kind == 1u ? NB_MEMORY_MUTATION_SECTION_ACTIVE_EPISODE
        : NB_MEMORY_MUTATION_SECTION_COMPRESSED_EPISODE,
      updated.identifier
    );
    return;
  }

  const uint archive_base = uniforms.active_episode_capacity
    + uniforms.compressed_episode_capacity;
  if (kind == 7u) {
    if (candidate_index < archive_base) return;
    const uint search_index = candidate_index - archive_base;
    if (search_index >= uniforms.archive_search_candidate_count) return;
    const uint archive_index = archive_storage_index_for_search_candidate(
      recurrent, uniforms.recurrent_scalar_count, uniforms, search_index
    );
    const ulong destination = uniforms.archive_episode_memory_offset
      + ulong(archive_index) * ulong(uniforms.archive_episode_stride);
    device const NBArchivedEpisodicRecord *record =
      reinterpret_cast<device const NBArchivedEpisodicRecord *>(
        persistent_memory + destination
      );
    if (record->identifier != identifier
        || record->format_version != NB_MEMORY_EPISODE_RECORD_VERSION) return;
    NBArchivedEpisodicRecord updated = *record;
    const float similarity = accepted_archive_memory_similarity(
      recurrent, uniforms.recurrent_scalar_count,
      observations, uniforms.observation_count, record
    );
    float content_rate = rate * 0.5f;
    if (similarity >= uniforms.confirmation_similarity) {
      updated.epistemic_uncertainty = max(
        record->epistemic_uncertainty * (1.0f - rate), 0.0f
      );
      content_rate = rate;
    } else if (similarity <= uniforms.conflict_similarity) {
      updated.epistemic_uncertainty = record->epistemic_uncertainty
        + rate * (1.0f + abs(similarity));
      content_rate = rate * 0.25f;
    }
    float reconstructed[16] = {};
    float maximum_magnitude = 0.0f;
    const uint count = min(record->quantized_component_count, 16u);
    for (uint component = 0u; component < count; ++component) {
      const float prior = float(record->quantized_retrieval_key[component])
        * record->retrieval_key_scale;
      const float evidence = accepted_memory_evidence_component(
        recurrent, uniforms.recurrent_scalar_count,
        observations, uniforms.observation_count, component
      );
      reconstructed[component] = mix(prior, evidence, content_rate);
      // Tier-2 placement is keyed by the first eight signs. Preserve that
      // coarse identity during in-place reconsolidation so the record never
      // becomes unreachable from the cluster that physically owns it.
      if (component < 8u) {
        reconstructed[component] = record->quantized_retrieval_key[component] >= 0
          ? max(reconstructed[component], 0.0f)
          : min(reconstructed[component], -1.0e-6f);
      }
      maximum_magnitude = max(maximum_magnitude, abs(reconstructed[component]));
    }
    updated.retrieval_key_scale = maximum_magnitude > 0.0f
      ? maximum_magnitude / 127.0f : 1.0f;
    for (uint component = 0u; component < count; ++component) {
      updated.quantized_retrieval_key[component] = char(clamp(
        rint(reconstructed[component] / updated.retrieval_key_scale),
        -127.0f,
        127.0f
      ));
    }
    updated.flags = record->flags | 8u;
    const bool archived_written = append_memory_record(
      journal, uniforms, updated, destination,
      NB_MEMORY_MUTATION_SECTION_ARCHIVE_EPISODE, updated.identifier
    );
    if (archived_written && uniforms.archive_records_per_page > 0u) {
      advance_archive_page_epoch(
        hot_state,
        uniforms.archive_page_epoch_offset,
        uniforms.archive_page_count,
        archive_index / uniforms.archive_records_per_page
      );
    }
    return;
  }

  const uint semantic_base = archive_base
    + uniforms.archive_search_candidate_count;
  if (kind == 2u) {
    if (candidate_index < semantic_base) return;
    const uint local_index = candidate_index - semantic_base;
    if (local_index >= uniforms.semantic_capacity) return;
    const ulong destination = uniforms.semantic_memory_offset
      + ulong(local_index) * ulong(uniforms.semantic_stride);
    device const NBSemanticConceptSummaryRecord *record =
      reinterpret_cast<device const NBSemanticConceptSummaryRecord *>(
        persistent_memory + destination
      );
    if (record->identifier != identifier
        || record->format_version != NB_MEMORY_RECORD_VERSION) return;
    NBSemanticConceptSummaryRecord updated = *record;
    const float similarity = accepted_memory_similarity(
      recurrent, uniforms.recurrent_scalar_count,
      observations, uniforms.observation_count, record->embedding, 19u
    );
    if (similarity >= uniforms.confirmation_similarity) {
      updated.confidence = clamp(
        record->confidence + rate * (1.0f - record->confidence), 0.0f, 1.0f
      );
    } else if (similarity <= uniforms.conflict_similarity) {
      updated.confidence = clamp(record->confidence * (1.0f - rate), 0.0f, 1.0f);
    }
    for (uint component = 0u; component < 19u; ++component) {
      const float evidence = accepted_memory_evidence_component(
        recurrent, uniforms.recurrent_scalar_count,
        observations, uniforms.observation_count, component
      );
      updated.embedding[component] = mix(
        record->embedding[component], evidence, rate * 0.25f
      );
    }
    updated.last_used_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    updated.usage_count = record->usage_count == ~0ul
      ? record->usage_count : record->usage_count + 1ul;
    updated.flags = record->flags | 8u;
    append_memory_record(
      journal, uniforms, updated, destination,
      NB_MEMORY_MUTATION_SECTION_SEMANTIC_CONCEPT, updated.identifier
    );
    return;
  }

  const uint relation_base = semantic_base + uniforms.semantic_capacity;
  if (kind == 5u) {
    if (candidate_index < relation_base) return;
    const uint local_index = candidate_index - relation_base;
    if (local_index >= uniforms.semantic_relation_capacity) return;
    const ulong destination = uniforms.semantic_relation_memory_offset
      + ulong(local_index) * ulong(uniforms.semantic_relation_stride);
    device const NBSemanticRelationSummaryRecord *record =
      reinterpret_cast<device const NBSemanticRelationSummaryRecord *>(
        persistent_memory + destination
      );
    if (record->identifier != identifier
        || record->format_version != NB_MEMORY_RECORD_VERSION) return;
    NBSemanticRelationSummaryRecord updated = *record;
    const float similarity = accepted_memory_similarity(
      recurrent, uniforms.recurrent_scalar_count,
      observations, uniforms.observation_count,
      record->evidence_embedding, 10u
    );
    if (similarity >= uniforms.confirmation_similarity) {
      updated.confidence = clamp(
        record->confidence + rate * (1.0f - record->confidence), 0.0f, 1.0f
      );
      updated.contradiction = max(record->contradiction * (1.0f - rate), 0.0f);
    } else if (similarity <= uniforms.conflict_similarity) {
      updated.confidence = clamp(record->confidence * (1.0f - rate), 0.0f, 1.0f);
      updated.contradiction = clamp(
        record->contradiction + rate * (1.0f - record->contradiction),
        0.0f,
        1.0f
      );
    }
    for (uint component = 0u; component < 10u; ++component) {
      const float evidence = accepted_memory_evidence_component(
        recurrent, uniforms.recurrent_scalar_count,
        observations, uniforms.observation_count, component
      );
      updated.evidence_embedding[component] = mix(
        record->evidence_embedding[component], evidence, rate * 0.25f
      );
    }
    updated.last_used_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    updated.flags = record->flags | 8u;
    append_memory_record(
      journal, uniforms, updated, destination,
      NB_MEMORY_MUTATION_SECTION_SEMANTIC_RELATION, updated.identifier
    );
    return;
  }

  const uint procedural_base = relation_base
    + uniforms.semantic_relation_capacity;
  if (kind == 3u) {
    if (candidate_index < procedural_base) return;
    const uint local_index = candidate_index - procedural_base;
    if (local_index >= uniforms.procedural_capacity) return;
    const ulong destination = uniforms.procedural_memory_offset
      + ulong(local_index) * ulong(uniforms.procedural_stride);
    device const NBProceduralSkillSummaryRecord *record =
      reinterpret_cast<device const NBProceduralSkillSummaryRecord *>(
        persistent_memory + destination
      );
    device const NBControlHeader *control =
      reinterpret_cast<device const NBControlHeader *>(
        hot_state + uniforms.control_header_offset
      );
    if (record->identifier != identifier
        || record->format_version != NB_PROCEDURAL_SKILL_RECORD_VERSION
        || control->active_option_identifier != record->identifier) return;
    device const NBDriveRecord *drives =
      reinterpret_cast<device const NBDriveRecord *>(
        hot_state + uniforms.drive_offset
      );
    float accepted_damage = control->selected_damage_cvar;
    if (uniforms.drive_count > 5u) accepted_damage = max(
      accepted_damage, drives[5].level
    );
    if (uniforms.drive_count > 6u) accepted_damage = max(
      accepted_damage, drives[6].level
    );
    if (uniforms.drive_count > 11u) accepted_damage = max(
      accepted_damage, drives[11].level
    );
    for (uint body_index = 0u;
        body_index < uniforms.body_belief_count; ++body_index) {
      device const float *body = reinterpret_cast<device const float *>(
        hot_state + uniforms.body_belief_offset + ulong(body_index) * 256ul
      );
      device const ulong *identity = reinterpret_cast<device const ulong *>(
        body + 16
      );
      if ((identity[3] & 1ul) == 0ul) continue;
      if (isfinite(body[5])) {
        accepted_damage = max(
          accepted_damage, clamp(body[5], 0.0f, 1.0f)
        );
      }
      if (isfinite(body[7])) {
        accepted_damage = max(
          accepted_damage, clamp(body[7], 0.0f, 1.0f)
        );
      }
      if (isfinite(body[11])) {
        accepted_damage = max(
          accepted_damage, clamp(body[11], 0.0f, 1.0f)
        );
      }
    }
    accepted_damage = clamp(accepted_damage, 0.0f, uniforms.maximum_damage);
    const float success = clamp(
      control->progress * (1.0f - accepted_damage), 0.0f, 1.0f
    );
    const bool was_frozen =
      (record->flags & NB_PROCEDURAL_SKILL_FROZEN) != 0u;
    const bool degraded = was_frozen && (
      accepted_damage > record->damage_cvar + uniforms.degradation_margin
      || success + uniforms.degradation_margin < record->competence
    );
    const float statistics_rate = was_frozen && !degraded
      ? min(rate, 0.02f) : rate;
    const float model_rate = was_frozen && !degraded ? 0.0f : rate;
    NBProceduralSkillSummaryRecord updated = *record;
    updated.competence = mix(
      record->competence, success, statistics_rate
    );
    updated.damage_cvar = mix(
      record->damage_cvar, accepted_damage, statistics_rate
    );
    updated.expected_effort = mix(
      record->expected_effort, max(control->predicted_effort, 0.0f),
      statistics_rate
    );
    updated.expected_value = mix(
      record->expected_value, control->selected_score, statistics_rate
    );
    updated.initiation_confidence = clamp(
      record->initiation_confidence
        + statistics_rate * (1.0f - record->initiation_confidence),
      0.0f,
      1.0f
    );
    updated.termination_confidence = mix(
      record->termination_confidence,
      clamp(control->progress, 0.0f, 1.0f),
      statistics_rate
    );
    updated.outcome_uncertainty = mix(
      record->outcome_uncertainty,
      abs(control->selected_score - record->expected_value)
        + abs(accepted_damage - record->damage_cvar),
      statistics_rate
    );
    updated.adaptation_rate = model_rate;
    updated.expected_factored_value[1] = mix(
      record->expected_factored_value[1], control->selected_score,
      statistics_rate
    );
    updated.expected_factored_value[4] = mix(
      record->expected_factored_value[4], -accepted_damage, statistics_rate
    );
    updated.expected_factored_value[5] = mix(
      record->expected_factored_value[5],
      -max(control->predicted_effort, 0.0f), statistics_rate
    );
    updated.expected_factored_value[6] = mix(
      record->expected_factored_value[6], -accepted_damage, statistics_rate
    );
    for (uint component = 0u; component < 16u; ++component) {
      const float evidence = accepted_memory_evidence_component(
        recurrent, uniforms.recurrent_scalar_count,
        observations, uniforms.observation_count, component
      );
      updated.outcome_model[component] = mix(
        record->outcome_model[component],
        component < 10u ? evidence
          : (component == 10u ? control->selected_score
            : (component == 11u ? accepted_damage
              : (component == 12u ? control->progress
                : record->outcome_model[component]))),
        model_rate
      );
    }
    updated.adaptation_state[0] = updated.competence;
    updated.adaptation_state[1] = updated.damage_cvar;
    updated.adaptation_state[2] = updated.outcome_uncertainty;
    updated.adaptation_state[3] = control->progress;
    updated.last_execution_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    updated.last_training_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    updated.execution_count = record->execution_count == ~0ul
      ? record->execution_count : record->execution_count + 1ul;
    const bool harmful = updated.execution_count >= 8ul
      && updated.competence <= uniforms.retire_competence
      && updated.damage_cvar >= uniforms.retire_minimum_damage;
    const bool mastered = updated.competence >= uniforms.freeze_competence
      && updated.damage_cvar <= uniforms.freeze_maximum_damage
      && updated.outcome_uncertainty <= uniforms.freeze_maximum_uncertainty;
    const uint lifecycle = harmful
      ? NB_PROCEDURAL_SKILL_RETIRED
      : (mastered && !degraded
        ? NB_PROCEDURAL_SKILL_FROZEN
        : NB_PROCEDURAL_SKILL_TRAINABLE);
    updated.flags = (record->flags & ~NB_PROCEDURAL_SKILL_LIFECYCLE_MASK)
      | lifecycle | NB_PROCEDURAL_SKILL_RECONSOLIDATED;
    const bool wrote_skill = append_memory_record(
      journal, uniforms, updated, destination,
      NB_MEMORY_MUTATION_SECTION_PROCEDURAL_SKILL, updated.identifier
    );
    if (wrote_skill && degraded && uniforms.replay_capacity > 0u) {
      NBReplayQueueSummaryRecord replay = {};
      replay.queue_kind = 2u;
      replay.record_kind = 2u;
      replay.record_identifier = updated.identifier;
      replay.priority = clamp(
        1.0f - updated.competence + updated.damage_cvar
          + updated.outcome_uncertainty,
        0.0f,
        2.0f
      );
      replay.replay_count = 0u;
      replay.enqueued_timestamp_microseconds =
        uniforms.target_timestamp_microseconds;
      const uint replay_slot = uint(
        updated.identifier % ulong(uniforms.replay_capacity)
      );
      append_memory_record(
        journal,
        uniforms,
        replay,
        uniforms.replay_memory_offset
          + ulong(replay_slot) * ulong(uniforms.replay_stride),
        NB_MEMORY_MUTATION_SECTION_REPLAY_QUEUE,
        updated.identifier
      );
    }
  }
}

/// Maintains intended future goals only from accepted physical consequences.
/// Persistent changes are journaled, while the causal previous-goal/context
/// tracker remains in the root shadow and therefore rolls back on rejection.
kernel void advance_prospective_memory(
  device uchar *hot_state [[buffer(0)]],
  device const uchar *persistent_memory [[buffer(1)]],
  device NBMemoryJournalHeader *journal [[buffer(2)]],
  constant NBProspectiveLifecycleUniforms &uniforms [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.recurrent_scalar_count == 0u
      || uniforms.prospective_capacity == 0u) return;
  if (journal->base_generation != uniforms.base_generation
      || journal->shadow_generation != uniforms.shadow_generation
      || journal->memory_byte_count != uniforms.persistent_memory_byte_count) {
    atomic_fetch_or_explicit(
      &journal->status, NB_MEMORY_JOURNAL_STATUS_CAPACITY, memory_order_relaxed
    );
    return;
  }
  device const NBControlHeader *control =
    reinterpret_cast<device const NBControlHeader *>(
      hot_state + uniforms.control_header_offset
    );
  if ((control->flags & NB_MEMORY_CONTROL_FLAG_VALID) == 0u) return;
  device NBProspectiveLifecycleState *lifecycle =
    reinterpret_cast<device NBProspectiveLifecycleState *>(
      hot_state + uniforms.lifecycle_state_offset
    );
  device const float *recurrent = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  const bool lifecycle_valid = lifecycle->format_version
    == NB_MEMORY_RECORD_VERSION;
  const bool current_stop =
    (control->flags & NB_MEMORY_CONTROL_FLAG_HYPERDIRECT_STOP) != 0u;
  const bool current_external_failure =
    (control->flags & NB_MEMORY_CONTROL_FLAG_EXTERNAL_GOAL_FAILED) != 0u;
  const bool previous_stop = lifecycle_valid
    && (lifecycle->flags & NB_MEMORY_LIFECYCLE_STOP_ACTIVE) != 0u;
  const bool stop_onset = current_stop && !previous_stop;
  const ulong previous_goal = lifecycle_valid
    ? lifecycle->previous_goal_identifier : 0ul;
  const bool goal_changed = lifecycle_valid
    && previous_goal != control->active_goal_identifier;
  const ulong current_intention_identifier = control->reserved2;
  const ulong previous_intention_identifier = lifecycle_valid
    ? lifecycle->previous_intention_identifier : 0ul;
  const bool intention_changed = lifecycle_valid
    && previous_intention_identifier != current_intention_identifier;

  for (uint index = 0u; index < uniforms.prospective_capacity; ++index) {
    const ulong destination = uniforms.prospective_memory_offset
      + ulong(index) * ulong(uniforms.prospective_stride);
    device const NBProspectiveIntentionSummaryRecord *record =
      reinterpret_cast<device const NBProspectiveIntentionSummaryRecord *>(
        persistent_memory + destination
      );
    if (record->format_version != NB_MEMORY_RECORD_VERSION
        || record->identifier == 0ul) continue;
    uint next_status = record->status;
    const bool expired = (record->status == 1u || record->status == 2u)
      && record->deadline_timestamp_microseconds != 0ul
      && uniforms.target_timestamp_microseconds
        > record->deadline_timestamp_microseconds;
    if (expired) {
      next_status = 5u;
    } else if (record->identifier == current_intention_identifier) {
      if (control->progress >= uniforms.completion_threshold) {
        next_status = 3u;
      } else if ((control->flags & NB_MEMORY_CONTROL_FLAG_HYPERDIRECT_STOP) != 0u
          || current_external_failure
          || control->selected_damage_cvar >= uniforms.failure_risk_threshold) {
        next_status = 4u;
      } else {
        next_status = 2u;
      }
    } else if ((goal_changed || intention_changed)
        && record->identifier == previous_intention_identifier
        && record->status == 2u) {
      next_status = 1u;
    }
    if (next_status != record->status) {
      NBProspectiveIntentionSummaryRecord updated = *record;
      updated.status = next_status;
      updated.context_match = next_status == 2u ? 1.0f : 0.0f;
      append_memory_record(
        journal, uniforms, updated, destination,
        NB_MEMORY_MUTATION_SECTION_PROSPECTIVE_INTENTION, updated.identifier
      );
    }
  }

  const bool interrupted_goal = goal_changed && previous_goal != 0ul
    && previous_intention_identifier == 0ul
    && (lifecycle->flags & NB_MEMORY_LIFECYCLE_EXTERNAL_GOAL_FAILED) == 0u
    && lifecycle->previous_goal_timestamp_microseconds != 0ul
    && lifecycle->previous_progress < uniforms.completion_threshold;
  if (interrupted_goal) {
    const ulong identity_space = NB_MEMORY_GOAL_SOURCE_MASK - 1ul;
    const ulong intention_identifier =
      consolidation_hash(previous_goal ^ 0x50524f5350454354ul)
        % identity_space + 1ul;
    const uint slot = uint(
      intention_identifier % ulong(uniforms.prospective_capacity)
    );
    const ulong destination = uniforms.prospective_memory_offset
      + ulong(slot) * ulong(uniforms.prospective_stride);
    device const NBProspectiveIntentionSummaryRecord *existing =
      reinterpret_cast<device const NBProspectiveIntentionSummaryRecord *>(
        persistent_memory + destination
      );
    const bool collision = existing->format_version == NB_MEMORY_RECORD_VERSION
      && existing->identifier != 0ul
      && existing->identifier != intention_identifier;
    if (!collision) {
      NBProspectiveIntentionSummaryRecord intention = {};
      intention.identifier = intention_identifier;
      intention.goal_identifier = previous_goal;
      const ulong deadline = uniforms.target_timestamp_microseconds
        + uniforms.default_deadline_microseconds;
      intention.deadline_timestamp_microseconds =
        deadline < uniforms.target_timestamp_microseconds ? ~0ul : deadline;
      intention.created_timestamp_microseconds =
        uniforms.target_timestamp_microseconds;
      intention.format_version = NB_MEMORY_RECORD_VERSION;
      intention.status = 1u;
      intention.flags = 1u;
      intention.priority = clamp(
        max(uniforms.default_priority, control->confidence), 0.0f, 1.0f
      );
      intention.trigger_confidence = clamp(
        max(uniforms.trigger_threshold, 0.5f), 0.0f, 1.0f
      );
      intention.context_match = 0.0f;
      for (uint component = 0u; component < 16u; ++component) {
        intention.trigger_code[component] = lifecycle->context[component];
      }
      append_memory_record(
        journal, uniforms, intention, destination,
        NB_MEMORY_MUTATION_SECTION_PROSPECTIVE_INTENTION,
        intention.identifier
      );
    }
  }

  lifecycle->previous_goal_identifier = control->active_goal_identifier;
  lifecycle->previous_intention_identifier = current_intention_identifier;
  lifecycle->previous_goal_timestamp_microseconds =
    uniforms.target_timestamp_microseconds;
  lifecycle->last_update_timestamp_microseconds =
    uniforms.target_timestamp_microseconds;
  lifecycle->format_version = NB_MEMORY_RECORD_VERSION;
  lifecycle->previous_control_mode = control->mode;
  lifecycle->flags = (current_stop ? NB_MEMORY_LIFECYCLE_STOP_ACTIVE : 0u)
    | (stop_onset ? NB_MEMORY_LIFECYCLE_STOP_ONSET : 0u)
    | (current_external_failure
      ? NB_MEMORY_LIFECYCLE_EXTERNAL_GOAL_FAILED : 0u);
  lifecycle->previous_progress = control->progress;
  for (uint component = 0u; component < 51u; ++component) {
    lifecycle->context[component] = recurrent[
      component % uniforms.recurrent_scalar_count
    ];
  }
}

/// Consolidates only previously committed lived episodes. The kernel is
/// intentionally single-lane: slot choice, evidence aggregation, and journal
/// ordering must remain deterministic for replay and rollback.
kernel void consolidate_lived_memory_during_rest(
  device uchar *hot_state [[buffer(0)]],
  device const uchar *persistent_memory [[buffer(1)]],
  device NBMemoryJournalHeader *journal [[buffer(2)]],
  constant NBMemoryConsolidationUniforms &uniforms [[buffer(3)]],
  device const float *memory_parameters [[buffer(6)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.active_episode_capacity == 0u
      || uniforms.semantic_capacity == 0u
      || uniforms.semantic_relation_capacity == 0u
      || uniforms.procedural_capacity == 0u
      || uniforms.replay_capacity == 0u) return;
  if (journal->base_generation != uniforms.base_generation
      || journal->shadow_generation != uniforms.shadow_generation
      || journal->memory_byte_count != uniforms.persistent_memory_byte_count) {
    atomic_fetch_or_explicit(
      &journal->status, NB_MEMORY_JOURNAL_STATUS_CAPACITY, memory_order_relaxed
    );
    return;
  }
  device const NBControlHeader *control =
    reinterpret_cast<device const NBControlHeader *>(
      hot_state + uniforms.control_header_offset
    );
  device const NBInternalActionRecord *internal_actions =
    reinterpret_cast<device const NBInternalActionRecord *>(
      hot_state + uniforms.internal_action_offset
    );
  const NBInternalActionRecord replay_request = internal_actions[7];
  device const NBDevelopmentalHeader *development =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  device const NBDriveRecord *drives =
    reinterpret_cast<device const NBDriveRecord *>(
      hot_state + uniforms.drive_offset
    );
  const bool rest_selected = control->active_option_identifier
    == NB_MEMORY_REST_OPTION_IDENTIFIER;
  const float pain = clamp(drives[5].level, 0.0f, 1.0f);
  const float injury = clamp(drives[6].level, 0.0f, 1.0f);
  const float immediate_risk = clamp(drives[11].level, 0.0f, 1.0f);
  if (development->stage < 7u || development->replay_allocation_multiplier <= 0.0f
      || (control->flags & NB_MEMORY_CONTROL_FLAG_VALID) == 0u
      || replay_request.kind != 8u
      || (replay_request.flags & NB_MEMORY_CONTROL_FLAG_VALID) == 0u
      || !rest_selected || max(max(pain, injury), immediate_risk) > 0.35f) return;

  device const NBReplayQueueSummaryRecord *selected_replay = nullptr;
  uint selected_replay_index = 0u;
  float selected_replay_score = -INFINITY;
  for (uint index = 0u; index < uniforms.replay_capacity; ++index) {
    device const NBReplayQueueSummaryRecord *candidate =
      reinterpret_cast<device const NBReplayQueueSummaryRecord *>(
        persistent_memory + uniforms.replay_memory_offset
          + ulong(index) * ulong(uniforms.replay_stride)
      );
    if (candidate->record_identifier == 0ul
        || candidate->record_kind < 1u || candidate->record_kind > 4u
        || !isfinite(candidate->priority) || candidate->priority <= 0.0f) continue;
    const float score = candidate->priority
      / (1.0f + 0.25f * float(candidate->replay_count));
    if (selected_replay == nullptr || score > selected_replay_score
        || (score == selected_replay_score
          && candidate->enqueued_timestamp_microseconds
            < selected_replay->enqueued_timestamp_microseconds)
        || (score == selected_replay_score
          && candidate->enqueued_timestamp_microseconds
            == selected_replay->enqueued_timestamp_microseconds
          && candidate->record_identifier < selected_replay->record_identifier)) {
      selected_replay = candidate;
      selected_replay_index = index;
      selected_replay_score = score;
    }
  }

  ulong target_episode_identifier = selected_replay != nullptr
      && selected_replay->record_kind == 1u
    ? selected_replay->record_identifier : 0ul;
  ulong semantic_replay_source_episode_identifier = 0ul;
  ulong target_option_identifier = 0ul;
  if (selected_replay != nullptr && selected_replay->record_kind == 2u) {
    for (uint index = 0u; index < uniforms.procedural_capacity; ++index) {
      device const NBProceduralSkillSummaryRecord *skill =
        reinterpret_cast<device const NBProceduralSkillSummaryRecord *>(
          persistent_memory + uniforms.procedural_memory_offset
            + ulong(index) * ulong(uniforms.procedural_stride)
        );
      if (skill->format_version == NB_PROCEDURAL_SKILL_RECORD_VERSION
          && skill->identifier == selected_replay->record_identifier) {
        target_option_identifier = skill->parent_skill_identifier;
        break;
      }
    }
  }
  if (selected_replay != nullptr && selected_replay->record_kind == 3u) {
    for (uint index = 0u; index < uniforms.semantic_capacity; ++index) {
      device const NBSemanticConceptSummaryRecord *concept =
        reinterpret_cast<device const NBSemanticConceptSummaryRecord *>(
          persistent_memory + uniforms.semantic_memory_offset
            + ulong(index) * ulong(uniforms.semantic_stride)
        );
      if (concept->format_version == NB_MEMORY_RECORD_VERSION
          && concept->identifier == selected_replay->record_identifier) {
        semantic_replay_source_episode_identifier =
          concept->source_episode_identifier;
        target_episode_identifier = concept->source_episode_identifier;
        break;
      }
    }
  }
  if (selected_replay != nullptr && selected_replay->record_kind == 4u) {
    ulong source_concept_identifier = 0ul;
    for (uint index = 0u; index < uniforms.semantic_relation_capacity; ++index) {
      device const NBSemanticRelationSummaryRecord *relation =
        reinterpret_cast<device const NBSemanticRelationSummaryRecord *>(
          persistent_memory + uniforms.semantic_relation_memory_offset
            + ulong(index) * ulong(uniforms.semantic_relation_stride)
        );
      if (relation->format_version == NB_MEMORY_RECORD_VERSION
          && relation->identifier == selected_replay->record_identifier) {
        source_concept_identifier = relation->source_concept_identifier;
        break;
      }
    }
    if (source_concept_identifier != 0ul) {
      for (uint index = 0u; index < uniforms.semantic_capacity; ++index) {
        device const NBSemanticConceptSummaryRecord *concept =
          reinterpret_cast<device const NBSemanticConceptSummaryRecord *>(
            persistent_memory + uniforms.semantic_memory_offset
              + ulong(index) * ulong(uniforms.semantic_stride)
          );
        if (concept->format_version == NB_MEMORY_RECORD_VERSION
            && concept->identifier == source_concept_identifier) {
          semantic_replay_source_episode_identifier =
            concept->source_episode_identifier;
          target_episode_identifier = concept->source_episode_identifier;
          break;
        }
      }
    }
  }

  device const NBEpisodicSummaryRecord *latest = nullptr;
  uint latest_index = 0u;
  for (uint index = 0u; index < uniforms.active_episode_capacity; ++index) {
    device const NBEpisodicSummaryRecord *candidate =
      reinterpret_cast<device const NBEpisodicSummaryRecord *>(
        persistent_memory + uniforms.active_episode_memory_offset
          + ulong(index) * ulong(uniforms.active_episode_stride)
      );
    const bool committed_lived_record = candidate->format_version
        == NB_MEMORY_EPISODE_RECORD_VERSION
      && candidate->identifier != 0ul
      && candidate->source_generation <= uniforms.base_generation
      && candidate->end_timestamp_microseconds <= uniforms.target_timestamp_microseconds
      && candidate->salience >= uniforms.minimum_salience;
    const bool matches_replay = selected_replay == nullptr
      || (target_episode_identifier != 0ul
        && candidate->identifier == target_episode_identifier)
      || (target_option_identifier != 0ul
        && candidate->active_option_identifier == target_option_identifier);
    if (committed_lived_record && matches_replay && (latest == nullptr
        || candidate->end_timestamp_microseconds
          > latest->end_timestamp_microseconds
        || (candidate->end_timestamp_microseconds
              == latest->end_timestamp_microseconds
            && candidate->identifier > latest->identifier))) {
      latest = candidate;
      latest_index = index;
    }
  }
  for (uint index = 0u; index < uniforms.compressed_episode_capacity; ++index) {
    device const NBEpisodicSummaryRecord *candidate =
      reinterpret_cast<device const NBEpisodicSummaryRecord *>(
        persistent_memory + uniforms.compressed_episode_memory_offset
          + ulong(index) * ulong(uniforms.compressed_episode_stride)
      );
    const bool committed_lived_record = candidate->format_version
        == NB_MEMORY_EPISODE_RECORD_VERSION
      && candidate->identifier != 0ul
      && candidate->source_generation <= uniforms.base_generation
      && candidate->end_timestamp_microseconds <= uniforms.target_timestamp_microseconds
      && candidate->salience >= uniforms.minimum_salience;
    const bool matches_replay = selected_replay == nullptr
      || (target_episode_identifier != 0ul
        && candidate->identifier == target_episode_identifier)
      || (target_option_identifier != 0ul
        && candidate->active_option_identifier == target_option_identifier);
    if (committed_lived_record && matches_replay && (latest == nullptr
        || candidate->end_timestamp_microseconds
          > latest->end_timestamp_microseconds
        || (candidate->end_timestamp_microseconds
              == latest->end_timestamp_microseconds
            && candidate->identifier > latest->identifier))) {
      latest = candidate;
      latest_index = uniforms.active_episode_capacity + index;
    }
  }
  // A queue entry can outlive both exact tiers. Fall back only after checking
  // hot and warm memory; the stale queue entry is then decayed below.
  if (latest == nullptr && selected_replay != nullptr) {
    for (uint index = 0u; index < uniforms.active_episode_capacity; ++index) {
      device const NBEpisodicSummaryRecord *candidate =
        reinterpret_cast<device const NBEpisodicSummaryRecord *>(
          persistent_memory + uniforms.active_episode_memory_offset
            + ulong(index) * ulong(uniforms.active_episode_stride)
        );
      const bool committed_lived_record = candidate->format_version
          == NB_MEMORY_EPISODE_RECORD_VERSION
        && candidate->identifier != 0ul
        && candidate->source_generation <= uniforms.base_generation
        && candidate->end_timestamp_microseconds
          <= uniforms.target_timestamp_microseconds
        && candidate->salience >= uniforms.minimum_salience;
      if (committed_lived_record && (latest == nullptr
          || candidate->end_timestamp_microseconds
            > latest->end_timestamp_microseconds
          || (candidate->end_timestamp_microseconds
                == latest->end_timestamp_microseconds
              && candidate->identifier > latest->identifier))) {
        latest = candidate;
        latest_index = index;
      }
    }
    for (uint index = 0u; index < uniforms.compressed_episode_capacity; ++index) {
      device const NBEpisodicSummaryRecord *candidate =
        reinterpret_cast<device const NBEpisodicSummaryRecord *>(
          persistent_memory + uniforms.compressed_episode_memory_offset
            + ulong(index) * ulong(uniforms.compressed_episode_stride)
        );
      const bool committed_lived_record = candidate->format_version
          == NB_MEMORY_EPISODE_RECORD_VERSION
        && candidate->identifier != 0ul
        && candidate->source_generation <= uniforms.base_generation
        && candidate->end_timestamp_microseconds
          <= uniforms.target_timestamp_microseconds
        && candidate->salience >= uniforms.minimum_salience;
      if (committed_lived_record && (latest == nullptr
          || candidate->end_timestamp_microseconds
            > latest->end_timestamp_microseconds
          || (candidate->end_timestamp_microseconds
                == latest->end_timestamp_microseconds
              && candidate->identifier > latest->identifier))) {
        latest = candidate;
        latest_index = uniforms.active_episode_capacity + index;
      }
    }
  }
  if (latest == nullptr) return;

  const float semantic_learning_rate = min(
    uniforms.semantic_learning_rate, max(memory_parameters[5], 0.0f)
  );
  const float procedural_learning_rate = min(
    uniforms.procedural_learning_rate, max(memory_parameters[5], 0.0f)
  );

  uint semantic_count = 0u;
  uint procedural_count = 0u;
  float semantic_embedding[19] = {};
  float procedural_code[16] = {};
  float accumulated_damage = 0.0f;
  float accumulated_value = 0.0f;
  float accumulated_procedural_uncertainty = 0.0f;
  for (uint index = 0u; index < uniforms.active_episode_capacity; ++index) {
    device const NBEpisodicSummaryRecord *episode =
      reinterpret_cast<device const NBEpisodicSummaryRecord *>(
        persistent_memory + uniforms.active_episode_memory_offset
          + ulong(index) * ulong(uniforms.active_episode_stride)
      );
    const bool committed_lived_record = episode->format_version
        == NB_MEMORY_EPISODE_RECORD_VERSION
      && episode->identifier != 0ul
      && episode->source_generation <= uniforms.base_generation
      && episode->end_timestamp_microseconds <= uniforms.target_timestamp_microseconds;
    if (!committed_lived_record) continue;
    if (episode->event_kind == latest->event_kind
        && episode->source_identifier == latest->source_identifier) {
      semantic_count += 1u;
      for (uint component = 0u; component < 10u; ++component) {
        semantic_embedding[component] += episode->retrieval_key[component];
      }
      semantic_embedding[10] += episode->salience;
      semantic_embedding[11] += episode->epistemic_uncertainty;
      semantic_embedding[12] += episode->damage_severity;
      semantic_embedding[13] += episode->factored_reinforcement;
    }
    if (latest->active_option_identifier != 0ul
        && episode->active_option_identifier == latest->active_option_identifier
        && episode->damage_severity <= uniforms.maximum_damage) {
      procedural_count += 1u;
      accumulated_damage += episode->damage_severity;
      accumulated_value += episode->factored_reinforcement;
      accumulated_procedural_uncertainty += episode->epistemic_uncertainty;
      for (uint component = 0u; component < 10u; ++component) {
        procedural_code[component] += episode->retrieval_key[component];
      }
    }
  }

  for (uint index = 0u; index < uniforms.compressed_episode_capacity; ++index) {
    device const NBEpisodicSummaryRecord *episode =
      reinterpret_cast<device const NBEpisodicSummaryRecord *>(
        persistent_memory + uniforms.compressed_episode_memory_offset
          + ulong(index) * ulong(uniforms.compressed_episode_stride)
      );
    const bool committed_lived_record = episode->format_version
        == NB_MEMORY_EPISODE_RECORD_VERSION
      && episode->identifier != 0ul
      && episode->source_generation <= uniforms.base_generation
      && episode->end_timestamp_microseconds <= uniforms.target_timestamp_microseconds;
    if (!committed_lived_record) continue;
    if (episode->event_kind == latest->event_kind
        && episode->source_identifier == latest->source_identifier) {
      semantic_count += 1u;
      for (uint component = 0u; component < 10u; ++component) {
        semantic_embedding[component] += episode->retrieval_key[component];
      }
      semantic_embedding[10] += episode->salience;
      semantic_embedding[11] += episode->epistemic_uncertainty;
      semantic_embedding[12] += episode->damage_severity;
      semantic_embedding[13] += episode->factored_reinforcement;
    }
    if (latest->active_option_identifier != 0ul
        && episode->active_option_identifier == latest->active_option_identifier
        && episode->damage_severity <= uniforms.maximum_damage) {
      procedural_count += 1u;
      accumulated_damage += episode->damage_severity;
      accumulated_value += episode->factored_reinforcement;
      accumulated_procedural_uncertainty += episode->epistemic_uncertainty;
      for (uint component = 0u; component < 10u; ++component) {
        procedural_code[component] += episode->retrieval_key[component];
      }
    }
  }

  const ulong semantic_identity = consolidation_hash(
    (ulong(latest->event_kind) << 32) | ulong(latest->source_identifier)
  ) & 0x3ffffffffffffffful;
  const ulong semantic_identifier = max(semantic_identity, 1ul);
  const uint semantic_slot = uint(
    semantic_identifier % ulong(uniforms.semantic_capacity)
  );
  if (semantic_count >= 2u) {
    const ulong destination = uniforms.semantic_memory_offset
      + ulong(semantic_slot) * ulong(uniforms.semantic_stride);
    device const NBSemanticConceptSummaryRecord *existing =
      reinterpret_cast<device const NBSemanticConceptSummaryRecord *>(
        persistent_memory + destination
      );
    const bool collision = existing->format_version
        == NB_MEMORY_RECORD_VERSION
      && existing->identifier != 0ul
      && existing->identifier != semantic_identifier;
    if (!collision && (existing->identifier == 0ul
        || existing->source_episode_identifier != latest->identifier
        || existing->usage_count < ulong(semantic_count))) {
      const float divisor = 1.0f / float(semantic_count);
      NBSemanticConceptSummaryRecord concept = {};
      concept.identifier = semantic_identifier;
      concept.last_used_timestamp_microseconds =
        latest->end_timestamp_microseconds;
      concept.usage_count = ulong(semantic_count);
      concept.source_episode_identifier = latest->identifier;
      concept.format_version = NB_MEMORY_RECORD_VERSION;
      concept.kind = 5u;
      concept.flags = 1u;
      concept.confidence = clamp(
        1.0f - exp(-semantic_learning_rate * float(semantic_count)),
        0.0f, 1.0f
      );
      for (uint component = 0u; component < 14u; ++component) {
        concept.embedding[component] = semantic_embedding[component] * divisor;
      }
      concept.embedding[14] = float(latest->event_kind) / 16.0f;
      concept.embedding[15] = float(latest->source_identifier & 0xffffu) / 65535.0f;
      concept.embedding[16] = float(latest_index)
        / float(max(
          uniforms.active_episode_capacity
            + uniforms.compressed_episode_capacity,
          1u
        ));
      concept.embedding[17] = development->maturation_progress;
      concept.embedding[18] = development->replay_allocation_multiplier;
      if (append_memory_record(
        journal, uniforms, concept, destination,
        NB_MEMORY_MUTATION_SECTION_SEMANTIC_CONCEPT, concept.identifier
      )) {
        enqueue_semantic_consolidation_replay(
          persistent_memory,
          journal,
          uniforms,
          3u,
          concept.identifier,
          concept.confidence,
          semantic_count
        );
      }
    }
  }

  if (semantic_count >= 2u && latest->active_goal_identifier != 0ul) {
    const ulong goal_identity = consolidation_hash(
      latest->active_goal_identifier ^ 0x474f414c434f4e43ul
    ) & 0x3ffffffffffffffful;
    const ulong goal_identifier = max(goal_identity, 1ul);
    const uint goal_slot = uint(goal_identifier % ulong(uniforms.semantic_capacity));
    const ulong goal_destination = uniforms.semantic_memory_offset
      + ulong(goal_slot) * ulong(uniforms.semantic_stride);
    device const NBSemanticConceptSummaryRecord *existing_goal =
      reinterpret_cast<device const NBSemanticConceptSummaryRecord *>(
        persistent_memory + goal_destination
      );
    const bool goal_collision = goal_slot == semantic_slot
      || (existing_goal->format_version == NB_MEMORY_RECORD_VERSION
        && existing_goal->identifier != 0ul
        && existing_goal->identifier != goal_identifier);
    if (!goal_collision && (existing_goal->identifier == 0ul
        || existing_goal->source_episode_identifier != latest->identifier
        || existing_goal->usage_count < ulong(semantic_count))) {
      NBSemanticConceptSummaryRecord goal = {};
      goal.identifier = goal_identifier;
      goal.last_used_timestamp_microseconds = latest->end_timestamp_microseconds;
      goal.usage_count = ulong(semantic_count);
      goal.source_episode_identifier = latest->identifier;
      goal.format_version = NB_MEMORY_RECORD_VERSION;
      goal.kind = 6u;
      goal.flags = 1u;
      goal.confidence = clamp(
        1.0f - exp(-semantic_learning_rate * float(semantic_count)),
        0.0f, 1.0f
      );
      for (uint component = 0u; component < 10u; ++component) {
        goal.embedding[component] = latest->retrieval_key[component];
      }
      goal.embedding[10] = float(
        uint(latest->active_goal_identifier)
      ) * 2.3283064365386963e-10f;
      goal.embedding[11] = float(
        uint(latest->active_goal_identifier >> 32)
      ) * 2.3283064365386963e-10f;
      goal.embedding[12] = latest->factored_reinforcement;
      goal.embedding[13] = latest->damage_severity;
      if (append_memory_record(
        journal, uniforms, goal, goal_destination,
        NB_MEMORY_MUTATION_SECTION_SEMANTIC_CONCEPT, goal.identifier
      )) {
        enqueue_semantic_consolidation_replay(
          persistent_memory,
          journal,
          uniforms,
          3u,
          goal.identifier,
          goal.confidence,
          semantic_count
        );
      }
    }

    if (!goal_collision) {
      const ulong relation_identity = consolidation_hash(
        goal_identifier ^ (semantic_identifier << 1)
          ^ 0x52454c4154494f4eul
      ) & 0x3ffffffffffffffful;
      const ulong relation_identifier = max(relation_identity, 1ul);
      const uint relation_slot = uint(
        relation_identifier % ulong(uniforms.semantic_relation_capacity)
      );
      const ulong relation_destination = uniforms.semantic_relation_memory_offset
        + ulong(relation_slot) * ulong(uniforms.semantic_relation_stride);
      device const NBSemanticRelationSummaryRecord *existing_relation =
        reinterpret_cast<device const NBSemanticRelationSummaryRecord *>(
          persistent_memory + relation_destination
        );
      const bool relation_collision = existing_relation->format_version
          == NB_MEMORY_RECORD_VERSION
        && existing_relation->identifier != 0ul
        && existing_relation->identifier != relation_identifier;
      if (!relation_collision && (existing_relation->identifier == 0ul
          || existing_relation->supporting_episode_count < semantic_count
          || existing_relation->last_used_timestamp_microseconds
            < latest->end_timestamp_microseconds)) {
        NBSemanticRelationSummaryRecord relation = {};
        relation.identifier = relation_identifier;
        relation.source_concept_identifier = goal_identifier;
        relation.destination_concept_identifier = semantic_identifier;
        relation.last_used_timestamp_microseconds =
          latest->end_timestamp_microseconds;
        relation.format_version = NB_MEMORY_RECORD_VERSION;
        relation.kind = 12u;
        relation.flags = 1u;
        relation.supporting_episode_count = semantic_count;
        relation.confidence = clamp(
          1.0f - exp(-semantic_learning_rate * float(semantic_count)),
          0.0f, 1.0f
        );
        relation.contradiction = 0.0f;
        for (uint component = 0u; component < 10u; ++component) {
          relation.evidence_embedding[component] = latest->retrieval_key[component];
        }
        if (append_memory_record(
          journal, uniforms, relation, relation_destination,
          NB_MEMORY_MUTATION_SECTION_SEMANTIC_RELATION, relation.identifier
        )) {
          enqueue_semantic_consolidation_replay(
            persistent_memory,
            journal,
            uniforms,
            4u,
            relation.identifier,
            relation.confidence,
            semantic_count
          );
        }
      }
    }
  }

  if (procedural_count >= uniforms.minimum_procedural_episodes) {
    const float divisor = 1.0f / float(procedural_count);
    float mean_procedural_code[16] = {};
    for (uint component = 0u; component < 16u; ++component) {
      mean_procedural_code[component] = component < 10u
        ? procedural_code[component] * divisor
        : latest->retrieval_key[component % 10u];
    }
    const ulong proposed_identity = consolidation_hash(
      latest->active_option_identifier
        ^ consolidation_hash(
          latest->active_goal_identifier ^ 0x50524f4345445552ul
        )
    ) & 0x3ffffffffffffffful;
    const ulong proposed_identifier = max(proposed_identity, 1ul);
    uint exact_slot = uniforms.procedural_capacity;
    uint available_slot = uniforms.procedural_capacity;
    uint merge_slot = uniforms.procedural_capacity;
    float best_merge_similarity = uniforms.merge_similarity;
    ulong best_merge_identifier = ~0ul;
    for (uint index = 0u; index < uniforms.procedural_capacity; ++index) {
      device const NBProceduralSkillSummaryRecord *candidate =
        reinterpret_cast<device const NBProceduralSkillSummaryRecord *>(
          persistent_memory + uniforms.procedural_memory_offset
            + ulong(index) * ulong(uniforms.procedural_stride)
        );
      const bool valid = candidate->format_version
          == NB_PROCEDURAL_SKILL_RECORD_VERSION
        && candidate->identifier != 0ul;
      if (valid && candidate->identifier == proposed_identifier) {
        exact_slot = index;
        continue;
      }
      if ((!valid
          || (candidate->flags & NB_PROCEDURAL_SKILL_RETIRED) != 0u)
          && available_slot == uniforms.procedural_capacity) {
        available_slot = index;
      }
      if (!valid
          || (candidate->flags & NB_PROCEDURAL_SKILL_RETIRED) != 0u
          || candidate->phase_count != 1u
          || candidate->parent_skill_identifier
            != latest->active_option_identifier) continue;
      const float similarity = procedural_similarity(
        mean_procedural_code, candidate->policy_code, 16u
      );
      if (similarity > best_merge_similarity
          || (similarity == best_merge_similarity
            && candidate->identifier < best_merge_identifier)) {
        best_merge_similarity = similarity;
        best_merge_identifier = candidate->identifier;
        merge_slot = index;
      }
    }
    const uint procedural_slot = exact_slot < uniforms.procedural_capacity
      ? exact_slot
      : (merge_slot < uniforms.procedural_capacity
        ? merge_slot : available_slot);
    if (procedural_slot < uniforms.procedural_capacity) {
      const ulong destination = uniforms.procedural_memory_offset
        + ulong(procedural_slot) * ulong(uniforms.procedural_stride);
      device const NBProceduralSkillSummaryRecord *existing =
        reinterpret_cast<device const NBProceduralSkillSummaryRecord *>(
          persistent_memory + destination
        );
      const bool merged_skill = exact_slot >= uniforms.procedural_capacity
        && merge_slot < uniforms.procedural_capacity;
      const ulong procedural_identifier = merged_skill
        ? existing->identifier : proposed_identifier;
      const bool existing_skill = existing->format_version
        == NB_PROCEDURAL_SKILL_RECORD_VERSION
        && existing->identifier == procedural_identifier;
      if (!existing_skill || existing->last_execution_timestamp_microseconds
          < latest->end_timestamp_microseconds) {
      const float mean_damage = accumulated_damage * divisor;
      const float mean_value = accumulated_value * divisor;
      const float mean_uncertainty =
        accumulated_procedural_uncertainty * divisor;
      const float learned_competence = clamp(
        (1.0f - mean_damage)
          * (1.0f - exp(-procedural_learning_rate
            * float(procedural_count))),
        0.0f, 1.0f
      );
      const float observed_competence = clamp(
        1.0f - mean_damage - 0.25f * mean_uncertainty, 0.0f, 1.0f
      );
      const bool stable_frozen = existing_skill
        && (existing->flags & NB_PROCEDURAL_SKILL_FROZEN) != 0u
        && mean_damage <= existing->damage_cvar + uniforms.degradation_margin
        && observed_competence + uniforms.degradation_margin
          >= existing->competence;
      const float skill_learning_rate = stable_frozen
        ? 0.0f : procedural_learning_rate;
      NBProceduralSkillSummaryRecord skill = {};
      skill.identifier = procedural_identifier;
      skill.last_execution_timestamp_microseconds =
        latest->end_timestamp_microseconds;
      skill.execution_count = existing_skill
        ? max(existing->execution_count, ulong(procedural_count))
        : ulong(procedural_count);
      skill.parent_skill_identifier = existing_skill
        ? existing->parent_skill_identifier
        : latest->active_option_identifier;
      skill.created_timestamp_microseconds = existing_skill
        ? existing->created_timestamp_microseconds
        : latest->start_timestamp_microseconds;
      skill.last_training_timestamp_microseconds =
        uniforms.target_timestamp_microseconds;
      skill.initiation_goal_identifier = merged_skill
          && existing->initiation_goal_identifier
            != latest->active_goal_identifier
        ? 0ul : latest->active_goal_identifier;
      skill.outcome_event_identifier =
        (ulong(latest->event_kind) << 32) | ulong(latest->source_identifier);
      skill.format_version = NB_PROCEDURAL_SKILL_RECORD_VERSION;
      skill.goal_parameter_dimension = 16u;
      skill.phase_count = 1u;
      skill.competence = existing_skill
        ? mix(existing->competence, observed_competence,
            stable_frozen ? min(procedural_learning_rate, 0.02f)
              : procedural_learning_rate)
        : learned_competence;
      skill.damage_cvar = existing_skill
        ? mix(existing->damage_cvar, mean_damage,
            stable_frozen ? min(procedural_learning_rate, 0.02f)
              : procedural_learning_rate)
        : mean_damage;
      skill.expected_effort = existing_skill
        ? mix(existing->expected_effort, mean_damage * 0.25f,
            skill_learning_rate)
        : mean_damage * 0.25f;
      skill.expected_value = existing_skill
        ? mix(existing->expected_value, mean_value, skill_learning_rate)
        : mean_value;
      const float learned_initiation_confidence = clamp(
        1.0f - exp(-procedural_learning_rate * float(procedural_count)),
        0.0f,
        1.0f
      );
      skill.initiation_confidence = existing_skill
        ? mix(existing->initiation_confidence,
            learned_initiation_confidence,
            stable_frozen ? min(procedural_learning_rate, 0.02f)
              : procedural_learning_rate)
        : learned_initiation_confidence;
      const float learned_termination_confidence = clamp(
        learned_initiation_confidence * (1.0f - mean_uncertainty),
        0.0f,
        1.0f
      );
      skill.termination_confidence = existing_skill
        ? mix(existing->termination_confidence,
            learned_termination_confidence,
            stable_frozen ? min(procedural_learning_rate, 0.02f)
              : procedural_learning_rate)
        : learned_termination_confidence;
      skill.outcome_uncertainty = existing_skill
        ? mix(existing->outcome_uncertainty, max(mean_uncertainty, 0.0f),
            stable_frozen ? min(procedural_learning_rate, 0.02f)
              : procedural_learning_rate)
        : max(mean_uncertainty, 0.0f);
      skill.adaptation_rate = skill_learning_rate;
      skill.expected_factored_value[0] = -mean_damage;
      skill.expected_factored_value[1] = mean_value;
      skill.expected_factored_value[4] = -mean_damage;
      skill.expected_factored_value[5] = -skill.expected_effort;
      skill.expected_factored_value[6] = -mean_damage;
      for (uint component = 0u; component < 16u; ++component) {
        const float learned_code = mean_procedural_code[component];
        skill.initiation_model[component] = existing_skill
          ? mix(existing->initiation_model[component], learned_code,
              skill_learning_rate)
          : learned_code;
        skill.policy_code[component] = existing_skill
          ? mix(existing->policy_code[component], learned_code,
              skill_learning_rate)
          : learned_code;
      }
      skill.phase_option_identifiers[0] =
        latest->active_option_identifier;
      skill.phase_durations[0] = max(
        float(latest->end_timestamp_microseconds
          - latest->start_timestamp_microseconds) * 1.0e-6f,
        0.02f
      );
      for (uint component = 0u; component < 16u; ++component) {
        skill.phase_parameters[0][component] = skill.policy_code[component];
      }
      for (uint component = 0u; component < 8u; ++component) {
        const float termination_code = component == 0u
          ? latest->salience
          : (component == 1u ? latest->epistemic_uncertainty
            : (component == 2u ? latest->damage_severity
              : (component == 3u ? latest->factored_reinforcement
                : latest->retrieval_key[(component - 4u) % 10u])));
        skill.termination_model[component] = existing_skill
          ? mix(existing->termination_model[component], termination_code,
              skill_learning_rate)
          : termination_code;
      }
      for (uint component = 0u; component < 16u; ++component) {
        const float outcome_code = component < 10u
          ? latest->retrieval_key[component]
          : (component == 10u ? mean_value
            : (component == 11u ? mean_damage
              : (component == 12u ? mean_uncertainty
                : float((latest->event_kind + component) & 0xffu) / 255.0f)));
        skill.outcome_model[component] = existing_skill
          ? mix(existing->outcome_model[component], outcome_code,
              skill_learning_rate)
          : outcome_code;
      }
      skill.adaptation_state[0] = skill.competence;
      skill.adaptation_state[1] = skill.damage_cvar;
      skill.adaptation_state[2] = skill.outcome_uncertainty;
      skill.adaptation_state[3] = development->maturation_progress;
      const bool harmful = skill.execution_count >= 8ul
        && skill.competence <= uniforms.retire_competence
        && skill.damage_cvar >= uniforms.retire_minimum_damage;
      const bool mastered = skill.competence >= uniforms.freeze_competence
        && skill.damage_cvar <= uniforms.freeze_maximum_damage
        && skill.outcome_uncertainty <= uniforms.freeze_maximum_uncertainty;
      const uint lifecycle = harmful
        ? NB_PROCEDURAL_SKILL_RETIRED
        : (mastered
          ? NB_PROCEDURAL_SKILL_FROZEN
          : NB_PROCEDURAL_SKILL_TRAINABLE);
      skill.flags = lifecycle
        | (merged_skill
          || (existing_skill
            && (existing->flags & NB_PROCEDURAL_SKILL_MERGED) != 0u)
          ? NB_PROCEDURAL_SKILL_MERGED : 0u);
      if (append_memory_record(
          journal, uniforms, skill, destination,
          NB_MEMORY_MUTATION_SECTION_PROCEDURAL_SKILL, skill.identifier
        )) {
        if ((skill.flags & NB_PROCEDURAL_SKILL_TRAINABLE) != 0u) {
          NBReplayQueueSummaryRecord replay = {};
          replay.queue_kind = 2u;
          replay.record_kind = 2u;
          replay.record_identifier = skill.identifier;
          replay.priority = clamp(
            development->replay_allocation_multiplier
              * (1.0f - skill.competence + mean_damage),
            0.0f, 2.0f
          );
          replay.replay_count = 0u;
          replay.enqueued_timestamp_microseconds =
            uniforms.target_timestamp_microseconds;
          const uint replay_slot = uint(
            skill.identifier % ulong(uniforms.replay_capacity)
          );
          const ulong replay_destination = uniforms.replay_memory_offset
            + ulong(replay_slot) * ulong(uniforms.replay_stride);
          append_memory_record(
            journal, uniforms, replay, replay_destination,
            NB_MEMORY_MUTATION_SECTION_REPLAY_QUEUE, skill.identifier
          );
        }
      }
    }
  }
  }

  device NBProceduralExecutionTrace *selected_trace = nullptr;
  float selected_trace_score = -INFINITY;
  for (uint index = 0u; index < uniforms.procedural_trace_capacity; ++index) {
    device NBProceduralExecutionTrace *trace =
      reinterpret_cast<device NBProceduralExecutionTrace *>(
        hot_state + uniforms.procedural_trace_offset
          + ulong(index) * ulong(uniforms.procedural_trace_stride)
      );
    const bool complete = trace->format_version == 1u
      && (trace->flags & 3u) == 3u;
    if (!complete) continue;
    const bool admissible = (trace->flags & 4u) == 0u
      && trace->phase_count >= 2u && trace->phase_count <= 8u
      && trace->sample_count > 0u
      && trace->maximum_damage <= uniforms.maximum_damage
      && trace->final_progress >= 0.5f;
    if (!admissible) {
      NBProceduralExecutionTrace cleared = {};
      *trace = cleared;
      continue;
    }
    const float mean_value = trace->cumulative_value
      / float(trace->sample_count);
    const float score = mean_value + trace->final_progress
      - trace->maximum_damage - 0.25f * trace->mean_uncertainty;
    if (selected_trace == nullptr || score > selected_trace_score
        || (score == selected_trace_score
          && trace->identifier < selected_trace->identifier)) {
      selected_trace = trace;
      selected_trace_score = score;
    }
  }

  if (selected_trace != nullptr) {
    ulong composed_identity = consolidation_hash(
      selected_trace->goal_identifier ^ 0x434f4d504f534544ul
    );
    const uint phase_count = min(selected_trace->phase_count, 8u);
    for (uint phase = 0u; phase < phase_count; ++phase) {
      composed_identity = consolidation_hash(
        composed_identity
          ^ selected_trace->phases[phase].option_identifier
          ^ (ulong(phase + 1u) << 56)
      );
    }
    const ulong composed_identifier = max(
      composed_identity & 0x3ffffffffffffffful, 1ul
    );
    uint composed_slot = uniforms.procedural_capacity;
    uint reusable_slot = uniforms.procedural_capacity;
    for (uint index = 0u; index < uniforms.procedural_capacity; ++index) {
      device const NBProceduralSkillSummaryRecord *candidate =
        reinterpret_cast<device const NBProceduralSkillSummaryRecord *>(
          persistent_memory + uniforms.procedural_memory_offset
            + ulong(index) * ulong(uniforms.procedural_stride)
        );
      const bool valid = candidate->format_version
          == NB_PROCEDURAL_SKILL_RECORD_VERSION
        && candidate->identifier != 0ul;
      if (valid && candidate->identifier == composed_identifier) {
        composed_slot = index;
        break;
      }
      if ((!valid
          || (candidate->flags & NB_PROCEDURAL_SKILL_RETIRED) != 0u)
          && reusable_slot == uniforms.procedural_capacity) {
        reusable_slot = index;
      }
    }
    if (composed_slot == uniforms.procedural_capacity) {
      composed_slot = reusable_slot;
    }
    if (composed_slot < uniforms.procedural_capacity) {
      const ulong destination = uniforms.procedural_memory_offset
        + ulong(composed_slot) * ulong(uniforms.procedural_stride);
      device const NBProceduralSkillSummaryRecord *existing =
        reinterpret_cast<device const NBProceduralSkillSummaryRecord *>(
          persistent_memory + destination
        );
      const bool existing_skill = existing->format_version
          == NB_PROCEDURAL_SKILL_RECORD_VERSION
        && existing->identifier == composed_identifier;
      const float trace_mean_value = selected_trace->cumulative_value
        / float(selected_trace->sample_count);
      const float trace_mean_effort = selected_trace->cumulative_effort
        / float(selected_trace->sample_count);
      const float trace_success = clamp(
        selected_trace->final_progress
          * (1.0f - selected_trace->maximum_damage),
        0.0f,
        1.0f
      );
      const float update_rate = existing_skill
        ? procedural_learning_rate : 1.0f;
      NBProceduralSkillSummaryRecord skill = {};
      skill.identifier = composed_identifier;
      skill.last_execution_timestamp_microseconds =
        selected_trace->last_timestamp_microseconds;
      skill.execution_count = existing_skill
        ? (existing->execution_count == ~0ul
          ? existing->execution_count : existing->execution_count + 1ul)
        : 1ul;
      skill.parent_skill_identifier =
        selected_trace->phases[0].option_identifier;
      skill.created_timestamp_microseconds = existing_skill
        ? existing->created_timestamp_microseconds
        : selected_trace->start_timestamp_microseconds;
      skill.last_training_timestamp_microseconds =
        uniforms.target_timestamp_microseconds;
      skill.initiation_goal_identifier = selected_trace->goal_identifier;
      skill.outcome_event_identifier = selected_trace->plan_identifier;
      skill.format_version = NB_PROCEDURAL_SKILL_RECORD_VERSION;
      skill.goal_parameter_dimension = 16u;
      skill.phase_count = phase_count;
      const float initial_competence = 0.25f * trace_success;
      skill.competence = existing_skill
        ? mix(existing->competence, trace_success, update_rate)
        : initial_competence;
      skill.damage_cvar = existing_skill
        ? mix(existing->damage_cvar, selected_trace->maximum_damage,
            update_rate)
        : selected_trace->maximum_damage;
      skill.expected_effort = existing_skill
        ? mix(existing->expected_effort, trace_mean_effort, update_rate)
        : trace_mean_effort;
      skill.expected_value = existing_skill
        ? mix(existing->expected_value, trace_mean_value, update_rate)
        : trace_mean_value;
      skill.initiation_confidence = clamp(
        1.0f - exp(-0.25f * float(skill.execution_count)), 0.0f, 1.0f
      );
      skill.termination_confidence = clamp(
        skill.initiation_confidence
          * (1.0f - selected_trace->mean_uncertainty),
        0.0f,
        1.0f
      );
      skill.outcome_uncertainty = existing_skill
        ? mix(existing->outcome_uncertainty,
            selected_trace->mean_uncertainty, update_rate)
        : selected_trace->mean_uncertainty;
      skill.adaptation_rate = procedural_learning_rate;
      skill.expected_factored_value[1] = skill.expected_value;
      skill.expected_factored_value[4] = -skill.damage_cvar;
      skill.expected_factored_value[5] = -skill.expected_effort;
      skill.expected_factored_value[6] = -skill.damage_cvar;
      for (uint component = 0u; component < 16u; ++component) {
        const float initiation = selected_trace->phases[0].parameters[component];
        const float outcome =
          selected_trace->phases[phase_count - 1u].parameters[component];
        skill.initiation_model[component] = existing_skill
          ? mix(existing->initiation_model[component], initiation, update_rate)
          : initiation;
        skill.policy_code[component] = skill.initiation_model[component];
        skill.outcome_model[component] = existing_skill
          ? mix(existing->outcome_model[component], outcome, update_rate)
          : outcome;
      }
      for (uint component = 0u; component < 8u; ++component) {
        const float termination =
          selected_trace->phases[phase_count - 1u].parameters[component];
        skill.termination_model[component] = existing_skill
          ? mix(existing->termination_model[component], termination, update_rate)
          : termination;
      }
      for (uint phase = 0u; phase < phase_count; ++phase) {
        skill.phase_option_identifiers[phase] =
          selected_trace->phases[phase].option_identifier;
        skill.phase_durations[phase] = max(
          selected_trace->phases[phase].duration_seconds, 0.02f
        );
        for (uint component = 0u; component < 16u; ++component) {
          skill.phase_parameters[phase][component] =
            selected_trace->phases[phase].parameters[component];
        }
      }
      skill.adaptation_state[0] = skill.competence;
      skill.adaptation_state[1] = skill.damage_cvar;
      skill.adaptation_state[2] = skill.outcome_uncertainty;
      skill.adaptation_state[3] = float(phase_count) / 8.0f;
      const bool mastered = skill.execution_count >= 4ul
        && skill.competence >= uniforms.freeze_competence
        && skill.damage_cvar <= uniforms.freeze_maximum_damage
        && skill.outcome_uncertainty <= uniforms.freeze_maximum_uncertainty;
      skill.flags = NB_PROCEDURAL_SKILL_COMPOSED
        | (mastered
          ? NB_PROCEDURAL_SKILL_FROZEN
          : NB_PROCEDURAL_SKILL_TRAINABLE);
      if (append_memory_record(
          journal, uniforms, skill, destination,
          NB_MEMORY_MUTATION_SECTION_PROCEDURAL_SKILL, skill.identifier
        )) {
        NBReplayQueueSummaryRecord replay = {};
        replay.queue_kind = 2u;
        replay.record_kind = 2u;
        replay.record_identifier = skill.identifier;
        replay.priority = clamp(
          development->replay_allocation_multiplier
            * (1.0f - skill.competence + skill.outcome_uncertainty),
          0.0f,
          2.0f
        );
        replay.enqueued_timestamp_microseconds =
          uniforms.target_timestamp_microseconds;
        const uint replay_slot = uint(
          skill.identifier % ulong(uniforms.replay_capacity)
        );
        append_memory_record(
          journal,
          uniforms,
          replay,
          uniforms.replay_memory_offset
            + ulong(replay_slot) * ulong(uniforms.replay_stride),
          NB_MEMORY_MUTATION_SECTION_REPLAY_QUEUE,
          skill.identifier
        );
        NBProceduralExecutionTrace cleared = {};
        *selected_trace = cleared;
      }
    }
  }

  if (selected_replay != nullptr) {
    NBReplayQueueSummaryRecord serviced = *selected_replay;
    serviced.replay_count = serviced.replay_count == 0xffffffffu
      ? serviced.replay_count : serviced.replay_count + 1u;
    const bool serviced_exact_target =
      (serviced.record_kind == 1u
        && latest->identifier == serviced.record_identifier)
      || (serviced.record_kind == 2u && target_option_identifier != 0ul
        && latest->active_option_identifier == target_option_identifier)
      || ((serviced.record_kind == 3u || serviced.record_kind == 4u)
        && semantic_replay_source_episode_identifier != 0ul
        && latest->identifier == semantic_replay_source_episode_identifier);
    const float decay = serviced_exact_target ? 0.70f : 0.35f;
    serviced.priority = max(serviced.priority * decay, 0.0f);
    const ulong replay_destination = uniforms.replay_memory_offset
      + ulong(selected_replay_index) * ulong(uniforms.replay_stride);
    append_memory_record(
      journal, uniforms, serviced, replay_destination,
      NB_MEMORY_MUTATION_SECTION_REPLAY_QUEUE, serviced.record_identifier
    );
  }
}

/// Emits exactly one compressed learning transition for an accepted root.
/// The journal makes the record visible only after joint brain-physics commit;
/// rejected trajectories therefore cannot enter replay or slow learning.
kernel void journal_committed_learning_transition(
  device const uchar *input_hot_state [[buffer(0)]],
  device const uchar *output_hot_state [[buffer(1)]],
  device const uchar *persistent_memory [[buffer(2)]],
  device NBMemoryJournalHeader *journal [[buffer(3)]],
  constant NBCommittedTransitionUniforms &uniforms [[buffer(4)]],
  device const float *teacher_state [[buffer(5)]],
  device const NBRegionalTokenLayoutRecord *regional_layouts [[buffer(7)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.recurrent_scalar_count == 0u
      || uniforms.observation_count == 0u || uniforms.action_count == 0u
      || uniforms.transition_capacity == 0u
      || uniforms.regional_transition_capacity == 0u
      || uniforms.regional_module_count == 0u) return;
  if (journal->base_generation != uniforms.base_generation
      || journal->shadow_generation != uniforms.shadow_generation
      || journal->memory_byte_count != uniforms.persistent_memory_byte_count) {
    atomic_fetch_or_explicit(
      &journal->status, NB_MEMORY_JOURNAL_STATUS_CAPACITY, memory_order_relaxed
    );
    return;
  }
  device const float *prior = reinterpret_cast<device const float *>(
    input_hot_state + uniforms.recurrent_offset
  );
  device const float *posterior = reinterpret_cast<device const float *>(
    output_hot_state + uniforms.recurrent_offset
  );
  device const float *observations = reinterpret_cast<device const float *>(
    output_hot_state + uniforms.observation_offset
  );
  device const float *actions = reinterpret_cast<device const float *>(
    output_hot_state + uniforms.somatic_output_offset
  );
  device const NBAutonomicCommandRecord *autonomic_actions =
    reinterpret_cast<device const NBAutonomicCommandRecord *>(
      output_hot_state + uniforms.autonomic_action_offset
    );
  device const NBActiveSensingCommandRecord *active_sensing_actions =
    reinterpret_cast<device const NBActiveSensingCommandRecord *>(
      output_hot_state + uniforms.active_sensing_action_offset
    );
  device const NBInternalActionRecord *internal_actions =
    reinterpret_cast<device const NBInternalActionRecord *>(
      output_hot_state + uniforms.internal_action_offset
    );
  device const NBActiveSensingEfficacyRecord *active_sensing_efficacy =
    reinterpret_cast<device const NBActiveSensingEfficacyRecord *>(
      output_hot_state + uniforms.active_sensing_efficacy_offset
    );
  device const uchar *prior_body_belief =
    input_hot_state + uniforms.body_belief_offset;
  device const uchar *accepted_body_belief =
    output_hot_state + uniforms.body_belief_offset;
  device const NBControlHeader *control =
    reinterpret_cast<device const NBControlHeader *>(
      output_hot_state + uniforms.control_header_offset
    );
  device const NBEventQueueHeader *events =
    reinterpret_cast<device const NBEventQueueHeader *>(
      output_hot_state + uniforms.event_queue_offset
    );
  device const NBDriveRecord *drives =
    reinterpret_cast<device const NBDriveRecord *>(
      output_hot_state + uniforms.drive_offset
    );
  device const NBNeuromodulatorRecord *neuromodulators =
    reinterpret_cast<device const NBNeuromodulatorRecord *>(
      output_hot_state + uniforms.neuromodulation_offset
    );
  device const NBFastPlasticityRecord *prior_plasticity =
    reinterpret_cast<device const NBFastPlasticityRecord *>(
      input_hot_state + uniforms.fast_plasticity_offset
    );
  device const NBFastPlasticityRecord *accepted_plasticity =
    reinterpret_cast<device const NBFastPlasticityRecord *>(
      output_hot_state + uniforms.fast_plasticity_offset
    );
  device const NBRegionalPlasticModulationRecord *regional_plasticity =
    reinterpret_cast<device const NBRegionalPlasticModulationRecord *>(
      output_hot_state + uniforms.regional_plastic_modulation_offset
    );
  device const NBCerebellarExpertRecord *active_cerebellar =
    reinterpret_cast<device const NBCerebellarExpertRecord *>(
      output_hot_state + uniforms.cerebellar_offset
    );
  device const NBCerebellarExpertRecord *cerebellar_bank =
    reinterpret_cast<device const NBCerebellarExpertRecord *>(
      output_hot_state + uniforms.cerebellar_expert_memory_offset
    );

  NBCommittedTransitionRecord record = {};
  record.identifier = consolidation_hash(
    uniforms.episode_identifier ^ (uniforms.control_step_identifier << 1)
      ^ (uniforms.shadow_generation << 17)
  ) | 1ul;
  record.start_timestamp_microseconds = uniforms.previous_timestamp_microseconds;
  record.end_timestamp_microseconds = uniforms.target_timestamp_microseconds;
  record.parameter_version_fingerprint = uniforms.parameter_version_fingerprint;
  record.source_generation = uniforms.shadow_generation;
  record.physics_state_fingerprint = uniforms.physics_state_fingerprint;
  record.active_goal_identifier = control->active_goal_identifier;
  record.active_option_identifier = control->active_option_identifier;
  record.format_version = NB_COMMITTED_TRANSITION_RECORD_VERSION;
  record.flags = 1u
    | ((control->flags & NB_MEMORY_CONTROL_FLAG_HYPERDIRECT_STOP) != 0u
      ? NB_COMMITTED_TRANSITION_ACCEPTED_STOP : 0u);
  record.recurrent_sample_count = min(uniforms.recurrent_scalar_count, 19u) + 5u;
  record.observation_sample_count = min(uniforms.observation_count, 24u);
  record.action_sample_count = min(uniforms.action_count, 16u);
  record.autonomic_action_sample_count = min(
    uniforms.autonomic_action_count, 8u
  );
  record.active_sensing_action_sample_count = min(
    uniforms.active_sensing_count, 8u
  );
  record.internal_action_sample_count = min(
    uniforms.internal_action_count, 8u
  );
  record.complete_action_flags = 1u
    | (record.autonomic_action_sample_count > 0u ? 2u : 0u)
    | (record.active_sensing_action_sample_count > 0u ? 4u : 0u)
    | (record.internal_action_sample_count > 0u ? 8u : 0u);
  record.event_count = min(
    atomic_load_explicit(&events->count, memory_order_relaxed), events->capacity
  );
  record.control_mode = control->mode;
  record.selected_score = control->selected_score;
  record.damage_cvar = control->selected_damage_cvar;
  record.progress = control->progress;
  record.uncertainty = control->unsupported_uncertainty;
  float drive_deficit = 0.0f;
  for (uint index = 0u; index < uniforms.drive_count; ++index) {
    drive_deficit += max(drives[index].deficit, 0.0f);
  }
  record.mean_drive_deficit = uniforms.drive_count == 0u
    ? 0.0f : drive_deficit / float(uniforms.drive_count);
  record.pain = uniforms.drive_count > 5u ? drives[5].level : 0.0f;
  record.model_error = uniforms.neuromodulator_count > 1u
    ? neuromodulators[1].value : 0.0f;
  record.predicted_information_gain = control->predicted_information_gain;
  float prior_epistemic = 0.0f;
  float accepted_epistemic = 0.0f;
  float sensing_allocation = 0.0f;
  float realized_information_gain = 0.0f;
  uint sensing_sample_count = 0u;
  for (uint channel = 0u; channel < uniforms.active_sensing_count; ++channel) {
    const NBActiveSensingEfficacyRecord sensing =
      active_sensing_efficacy[channel];
    if ((sensing.flags & 1u) == 0u || sensing.allocation <= 0.0f) continue;
    prior_epistemic += clamp(sensing.prior_uncertainty, 0.0f, 1.0f);
    accepted_epistemic += clamp(sensing.accepted_uncertainty, 0.0f, 1.0f);
    sensing_allocation += clamp(sensing.allocation, 0.0f, 1.0f);
    realized_information_gain += clamp(
      sensing.realized_information_gain, 0.0f, 1.0f
    );
    sensing_sample_count += 1u;
  }
  if (sensing_sample_count > 0u) {
    const float inverse_count = 1.0f / float(sensing_sample_count);
    prior_epistemic *= inverse_count;
    accepted_epistemic *= inverse_count;
    sensing_allocation *= inverse_count;
    realized_information_gain *= inverse_count;
  }
  for (uint component = 0u; component < 24u; ++component) {
    if (component < 19u) {
      record.prior_state[component] = prior[
        component % uniforms.recurrent_scalar_count
      ];
      record.posterior_state[component] = posterior[
        component % uniforms.recurrent_scalar_count
      ];
    } else {
      const uint level = component - 19u;
      record.prior_state[component] = committed_structured_world_context(
        input_hot_state, uniforms, level
      );
      record.posterior_state[component] = committed_structured_world_context(
        output_hot_state, uniforms, level
      );
    }
    record.observation[component] = observations[
      component % uniforms.observation_count
    ];
  }
  for (uint component = 0u; component < 16u; ++component) {
    record.action[component] = actions[component % uniforms.action_count];
  }
  for (uint sample = 0u; sample < 8u; ++sample) {
    if (sample < record.autonomic_action_sample_count) {
      const NBAutonomicCommandRecord autonomic = autonomic_actions[sample];
      record.autonomic_action[2u * sample] = autonomic.command;
      record.autonomic_action[2u * sample + 1u] = autonomic.target;
    }
    if (sample < record.active_sensing_action_sample_count) {
      const NBActiveSensingCommandRecord sensing = active_sensing_actions[sample];
      record.active_sensing_action[2u * sample] = sensing.command;
      record.active_sensing_action[2u * sample + 1u] = sensing.confidence;
    }
    if (sample < record.internal_action_sample_count) {
      const NBInternalActionRecord internal = internal_actions[sample];
      record.internal_action[4u * sample] = float(internal.kind);
      record.internal_action[4u * sample + 1u] = internal.priority;
      record.internal_action[4u * sample + 2u] = internal.confidence;
      record.internal_action[4u * sample + 3u] = internal.parameter_count > 0u
        ? internal.parameters[0] : 0.0f;
    }
  }
  uint prior_body_count = 0u;
  uint accepted_body_count = 0u;
  for (uint body_index = 0u;
      body_index < uniforms.body_belief_count; ++body_index) {
    device const float *prior_body = reinterpret_cast<device const float *>(
      prior_body_belief + ulong(body_index) * 256ul
    );
    device const float *accepted_body = reinterpret_cast<device const float *>(
      accepted_body_belief + ulong(body_index) * 256ul
    );
    device const ulong *prior_identity =
      reinterpret_cast<device const ulong *>(prior_body + 16);
    device const ulong *accepted_identity =
      reinterpret_cast<device const ulong *>(accepted_body + 16);
    if ((prior_identity[3] & 1ul) != 0ul
        && isfinite(prior_body[8]) && isfinite(prior_body[9])
        && isfinite(prior_body[10]) && isfinite(prior_body[11])) {
      const float load = max(prior_body[8], 0.0f);
      const float uncertainty = sqrt(max(prior_body[9], 0.0f));
      const float values[4] = {
        load / (1.0f + load), uncertainty / (1.0f + uncertainty),
        clamp(prior_body[10], 0.0f, 1.0f),
        clamp(prior_body[11], 0.0f, 1.0f)
      };
      for (uint value = 0u; value < 4u; ++value) {
        record.body_schema_trace[2u * value] += values[value];
        record.body_schema_trace[2u * value + 1u] = max(
          record.body_schema_trace[2u * value + 1u], values[value]
        );
      }
      prior_body_count += 1u;
    }
    if ((accepted_identity[3] & 1ul) != 0ul
        && isfinite(accepted_body[8]) && isfinite(accepted_body[9])
        && isfinite(accepted_body[10]) && isfinite(accepted_body[11])) {
      const float load = max(accepted_body[8], 0.0f);
      const float uncertainty = sqrt(max(accepted_body[9], 0.0f));
      const float values[4] = {
        load / (1.0f + load), uncertainty / (1.0f + uncertainty),
        clamp(accepted_body[10], 0.0f, 1.0f),
        clamp(accepted_body[11], 0.0f, 1.0f)
      };
      for (uint value = 0u; value < 4u; ++value) {
        const uint base = 8u + 2u * value;
        record.body_schema_trace[base] += values[value];
        record.body_schema_trace[base + 1u] = max(
          record.body_schema_trace[base + 1u], values[value]
        );
      }
      accepted_body_count += 1u;
    }
  }
  if (prior_body_count > 0u) {
    const float inverse_count = 1.0f / float(prior_body_count);
    for (uint value = 0u; value < 4u; ++value) {
      record.body_schema_trace[2u * value] *= inverse_count;
    }
  }
  if (accepted_body_count > 0u) {
    const float inverse_count = 1.0f / float(accepted_body_count);
    for (uint value = 0u; value < 4u; ++value) {
      record.body_schema_trace[8u + 2u * value] *= inverse_count;
    }
  }
  if (prior_body_count > 0u && accepted_body_count > 0u) {
    record.flags |= NB_COMMITTED_TRANSITION_HAS_BODY_TRACE;
  }
  record.damage_cvar = max(
    record.damage_cvar, record.body_schema_trace[15]
  );
  record.factored_reinforcement[0] = -record.mean_drive_deficit;
  record.factored_reinforcement[1] = control->selected_score;
  record.factored_reinforcement[2] = uniforms.drive_count > 9u
    ? drives[9].potential : 0.0f;
  record.factored_reinforcement[3] = realized_information_gain;
  record.factored_reinforcement[4] = -record.pain;
  record.factored_reinforcement[5] = -control->predicted_effort;
  record.factored_reinforcement[6] = -record.damage_cvar;
  record.factored_reinforcement[7] = -record.model_error;
  record.teacher_content_fingerprint = uniforms.teacher_content_fingerprint;
  record.teacher_scalar_count = min(uniforms.teacher_scalar_count, 24u);
  record.teacher_flags = uniforms.teacher_flags;
  for (uint component = 0u; component < record.teacher_scalar_count; ++component) {
    record.teacher_state[component] = teacher_state[component];
  }

  // Compress the accepted local plastic state and its actual within-root
  // change into a fixed meta-learning target. No per-agent coefficient becomes
  // a shared parameter; only these bounded statistics enter the slow learner.
  for (uint index = 0u; index < uniforms.fast_plasticity_count; ++index) {
    const NBFastPlasticityRecord prior_site = prior_plasticity[index];
    const NBFastPlasticityRecord accepted_site = accepted_plasticity[index];
    record.fast_plasticity_trace[0] += accepted_site.coefficient;
    record.fast_plasticity_trace[1] += abs(accepted_site.coefficient);
    record.fast_plasticity_trace[2] += accepted_site.eligibility;
    record.fast_plasticity_trace[3] += abs(accepted_site.eligibility);
    record.fast_plasticity_trace[4] += accepted_site.coefficient_retention;
    record.fast_plasticity_trace[5] += accepted_site.eligibility_retention;
    record.fast_plasticity_trace[6] += accepted_site.learning_rate;
    record.fast_plasticity_trace[7] += accepted_site.maximum_magnitude;
    const float coefficient_delta =
      accepted_site.coefficient - prior_site.coefficient;
    const float eligibility_delta =
      accepted_site.eligibility - prior_site.eligibility;
    record.fast_plasticity_trace[8] += coefficient_delta;
    record.fast_plasticity_trace[9] += abs(coefficient_delta);
    record.fast_plasticity_trace[10] += eligibility_delta;
    record.fast_plasticity_trace[11] += abs(eligibility_delta);
  }
  if (uniforms.fast_plasticity_count > 0u) {
    const float inverse_count = 1.0f / float(uniforms.fast_plasticity_count);
    for (uint component = 0u; component < 12u; ++component) {
      record.fast_plasticity_trace[component] *= inverse_count;
    }
  }
  uint valid_regional_count = 0u;
  for (uint index = 0u;
      index < uniforms.regional_plastic_modulation_count; ++index) {
    const NBRegionalPlasticModulationRecord regional = regional_plasticity[index];
    if ((regional.flags & 1u) == 0u || regional.coefficient_count == 0u) continue;
    record.fast_plasticity_trace[12] += regional.recurrent_delta;
    record.fast_plasticity_trace[13] += regional.local_delta;
    record.fast_plasticity_trace[14] += regional.route_delta;
    record.fast_plasticity_trace[15] +=
      0.5f * (regional.drive_delta + regional.gate_delta);
    valid_regional_count += 1u;
  }
  if (valid_regional_count > 0u) {
    const float inverse_count = 1.0f / float(valid_regional_count);
    for (uint component = 12u; component < 16u; ++component) {
      record.fast_plasticity_trace[component] *= inverse_count;
    }
  }

  // Preserve the four active experts' accepted forward error, forward state,
  // inverse correction, and competence. These are local adaptation outcomes,
  // not authoritative body state or privileged teacher information.
  const uint active_expert_count = min(uniforms.active_cerebellar_count, 4u);
  for (uint rank = 0u; rank < active_expert_count; ++rank) {
    const NBCerebellarExpertRecord active = active_cerebellar[rank];
    const NBCerebellarExpertRecord expert =
      active.expert_identifier < uniforms.cerebellar_expert_capacity
        ? cerebellar_bank[active.expert_identifier] : active;
    const uint base = rank * 4u;
    record.cerebellar_trace[base] = expert.prediction_error;
    record.cerebellar_trace[base + 1u] = expert.state[0];
    record.cerebellar_trace[base + 2u] = expert.state[1];
    record.cerebellar_trace[base + 3u] = expert.state[2];
  }
  record.active_sensing_trace[0] = prior_epistemic;
  record.active_sensing_trace[1] = accepted_epistemic;
  record.active_sensing_trace[2] = sensing_allocation;
  record.active_sensing_trace[3] = realized_information_gain;

  const uint slot = uint(
    uniforms.shadow_generation % ulong(uniforms.transition_capacity)
  );
  const ulong destination = uniforms.transition_memory_offset
    + ulong(slot) * ulong(uniforms.transition_stride);
  append_memory_record(
    journal, uniforms, record, destination,
    NB_MEMORY_MUTATION_SECTION_COMMITTED_TRANSITION, record.identifier
  );

  const uint module_index = uint(
    uniforms.control_step_identifier % ulong(uniforms.regional_module_count)
  );
  const NBRegionalTokenLayoutRecord regional_layout =
    regional_layouts[module_index];
  if (regional_layout.token_count == 0u
      || regional_layout.token_dimension == 0u
      || regional_layout.token_dimension > 256u
      || regional_layout.dense_weight_count
        != uint(regional_layout.token_dimension)
          * uint(regional_layout.token_dimension)) return;
  NBRegionalTransitionRecord regional_record = {};
  regional_record.identifier = consolidation_hash(
    record.identifier ^ (ulong(module_index) << 32) ^ 0x524547494f4e414cul
  ) | 1ul;
  regional_record.start_timestamp_microseconds =
    uniforms.previous_timestamp_microseconds;
  regional_record.end_timestamp_microseconds =
    uniforms.target_timestamp_microseconds;
  regional_record.parameter_version_fingerprint =
    uniforms.parameter_version_fingerprint;
  regional_record.source_generation = uniforms.shadow_generation;
  regional_record.format_version = NB_REGIONAL_TRANSITION_RECORD_VERSION;
  regional_record.flags = 0u;
  regional_record.module_index = module_index;
  regional_record.module_identifier = uint(regional_layout.module_id);
  regional_record.token_index = uint(
    (uniforms.control_step_identifier / ulong(uniforms.regional_module_count))
      % ulong(regional_layout.token_count)
  );
  regional_record.feature_count = uint(regional_layout.token_dimension);
  regional_record.dense_weight_offset = regional_layout.dense_weight_offset;
  regional_record.dense_weight_count = regional_layout.dense_weight_count;
  const uint regional_scalar_offset = regional_layout.scalar_offset
    + regional_record.token_index * uint(regional_layout.token_dimension);
  float regional_delta_energy = 0.0f;
  bool regional_values_finite = true;
  for (uint feature = 0u; feature < regional_record.feature_count; ++feature) {
    const float prior_value = prior[regional_scalar_offset + feature];
    const float posterior_value = posterior[regional_scalar_offset + feature];
    regional_values_finite = regional_values_finite
      && isfinite(prior_value) && isfinite(posterior_value);
    const float delta = posterior_value - prior_value;
    regional_delta_energy += delta * delta;
    regional_record.prior_state[feature] = half(prior_value);
    regional_record.posterior_state[feature] = half(posterior_value);
  }
  regional_record.flags = regional_values_finite
      && regional_delta_energy > 1.0e-10f
    ? 1u : 0u;
  const uint regional_slot = uint(
    uniforms.shadow_generation % ulong(uniforms.regional_transition_capacity)
  );
  const ulong regional_destination = uniforms.regional_transition_memory_offset
    + ulong(regional_slot) * ulong(uniforms.regional_transition_stride);
  append_memory_record(
    journal, uniforms, regional_record, regional_destination,
    NB_MEMORY_MUTATION_SECTION_REGIONAL_TRANSITION,
    regional_record.identifier
  );
}

/// Freezes a bounded, risk-balanced subset of the option planner's imagined
/// trajectories only after the physical root is accepted. The records occupy
/// a disjoint persistent ring and are never visible to episodic retrieval.
kernel void journal_committed_counterfactual_rollouts(
  device const uchar *hot_state [[buffer(0)]],
  device const uchar *persistent_memory [[buffer(2)]],
  device NBMemoryJournalHeader *journal [[buffer(3)]],
  constant NBCounterfactualLearningUniforms &uniforms [[buffer(4)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.candidate_capacity == 0u
      || uniforms.plan_capacity == 0u
      || uniforms.maximum_planning_horizon == 0u
      || uniforms.counterfactual_capacity == 0u
      || uniforms.maximum_samples == 0u) return;
  if (journal->base_generation != uniforms.base_generation
      || journal->shadow_generation != uniforms.shadow_generation
      || journal->memory_byte_count != uniforms.persistent_memory_byte_count) {
    atomic_fetch_or_explicit(
      &journal->status, NB_MEMORY_JOURNAL_STATUS_CAPACITY, memory_order_relaxed
    );
    return;
  }
  device const NBOptionCandidateRecord *candidates =
    reinterpret_cast<device const NBOptionCandidateRecord *>(
      hot_state + uniforms.candidate_offset
    );
  device const NBPlanStepRecord *plans =
    reinterpret_cast<device const NBPlanStepRecord *>(
      hot_state + uniforms.plan_offset
    );
  const uint candidate_count = min(uniforms.candidate_capacity, 32u);
  const uint sample_limit = min(
    min(uniforms.maximum_samples, candidate_count), 8u
  );
  bool selected[32] = {};
  for (uint sample = 0u; sample < sample_limit; ++sample) {
    uint selected_candidate = candidate_count;
    uint selected_plan_index = uniforms.plan_capacity;
    float selected_score = -INFINITY;
    for (uint candidate_index = 0u; candidate_index < candidate_count;
        ++candidate_index) {
      if (selected[candidate_index]) continue;
      const uint plan_base = candidate_index * uniforms.maximum_planning_horizon;
      if (plan_base + uniforms.maximum_planning_horizon
          > uniforms.plan_capacity) continue;
      uint terminal_index = uniforms.plan_capacity;
      for (uint step = 0u; step < uniforms.maximum_planning_horizon; ++step) {
        const uint plan_index = plan_base + step;
        if ((plans[plan_index].flags & 1u) != 0u) terminal_index = plan_index;
      }
      if (terminal_index == uniforms.plan_capacity) continue;
      const NBPlanStepRecord terminal = plans[terminal_index];
      const float score = (sample & 1u) == 0u
        ? terminal.objective_value - terminal.damage_cvar
          + 0.1f * terminal.predicted_information_gain
        : terminal.damage_cvar + 0.25f * terminal.epistemic_uncertainty
          - 0.05f * terminal.objective_value;
      if (selected_candidate == candidate_count || score > selected_score
          || (score == selected_score
            && candidate_index < selected_candidate)) {
        selected_candidate = candidate_index;
        selected_plan_index = terminal_index;
        selected_score = score;
      }
    }
    if (selected_candidate == candidate_count
        || selected_plan_index == uniforms.plan_capacity) break;
    selected[selected_candidate] = true;
    const NBPlanStepRecord terminal = plans[selected_plan_index];
    uint action_candidate = selected_candidate;
    for (uint candidate_index = 0u; candidate_index < candidate_count;
        ++candidate_index) {
      if ((candidates[candidate_index].flags & 1u) != 0u
          && candidates[candidate_index].option_identifier
            == terminal.option_identifier) {
        action_candidate = candidate_index;
        break;
      }
    }
    NBCounterfactualLearningRecord record = {};
    record.identifier = consolidation_hash(
      uniforms.episode_identifier
        ^ (uniforms.control_step_identifier << 1)
        ^ (uniforms.shadow_generation << 17)
        ^ (ulong(selected_candidate + 1u) << 48)
        ^ terminal.option_identifier
    ) | 1ul;
    record.source_timestamp_microseconds =
      uniforms.source_belief_timestamp_microseconds;
    record.parameter_version_fingerprint =
      uniforms.parameter_version_fingerprint;
    record.source_generation = uniforms.shadow_generation;
    record.episode_identifier = uniforms.episode_identifier;
    record.control_step_identifier = uniforms.control_step_identifier;
    record.option_identifier = terminal.option_identifier;
    record.goal_identifier = terminal.goal_identifier;
    record.format_version = NB_COUNTERFACTUAL_RECORD_VERSION;
    record.flags = NB_COUNTERFACTUAL_VALID | NB_COUNTERFACTUAL_IMAGINED
      | (terminal.admissibility > 0.5f ? NB_COUNTERFACTUAL_ADMISSIBLE : 0u);
    record.sequence = terminal.sequence;
    record.state_component_count = 16u;
    record.objective_value = terminal.objective_value;
    record.damage_cvar = terminal.damage_cvar;
    record.epistemic_uncertainty = terminal.epistemic_uncertainty;
    record.predicted_effort = terminal.predicted_effort;
    record.predicted_information_gain = terminal.predicted_information_gain;
    record.duration_seconds = terminal.duration_seconds;
    record.predicted_drive_change = terminal.predicted_drive_change;
    record.admissibility = terminal.admissibility;
    for (uint component = 0u; component < 16u; ++component) {
      record.predicted_state[component] = terminal.predicted_state[component];
      record.action_parameters[component] =
        candidates[action_candidate].parameters[component];
    }
    const uint slot = uint(
      (uniforms.shadow_generation * ulong(sample_limit) + ulong(sample))
        % ulong(uniforms.counterfactual_capacity)
    );
    append_memory_record(
      journal,
      uniforms,
      record,
      uniforms.counterfactual_memory_offset
        + ulong(slot) * ulong(uniforms.counterfactual_stride),
      NB_MEMORY_MUTATION_SECTION_COUNTERFACTUAL_ROLLOUT,
      record.identifier
    );
  }
}

kernel void segment_and_journal_episode(
  device uchar *hot_state [[buffer(0)]],
  device uchar *persistent_memory [[buffer(1)]],
  device NBMemoryJournalHeader *journal [[buffer(2)]],
  constant NBMemoryUniforms &uniforms [[buffer(3)]],
  device const float *memory_parameters [[buffer(6)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.active_episode_capacity == 0u) return;
  device const float *recurrent = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
  );
  device const float *workspace = reinterpret_cast<device const float *>(
    hot_state + uniforms.workspace_content_offset
  );
  device const NBControlHeader *control = reinterpret_cast<device const NBControlHeader *>(
    hot_state + uniforms.control_header_offset
  );
  device const NBProspectiveLifecycleState *lifecycle =
    reinterpret_cast<device const NBProspectiveLifecycleState *>(
      hot_state + uniforms.prospective_lifecycle_offset
    );
  const bool control_interrupt_onset = lifecycle->format_version
      == NB_MEMORY_RECORD_VERSION
    && (lifecycle->flags & NB_MEMORY_LIFECYCLE_STOP_ONSET) != 0u;
  device NBEventQueueHeader *event_header =
    reinterpret_cast<device NBEventQueueHeader *>(
      hot_state + uniforms.event_queue_offset
    );
  const uint event_count = min(
    atomic_load_explicit(&event_header->count, memory_order_relaxed),
    event_header->capacity
  );
  device const NBReceptorEventRecord *events =
    reinterpret_cast<device const NBReceptorEventRecord *>(event_header + 1);
  device const NBActiveSensingCommandRecord *sensing_commands =
    reinterpret_cast<device const NBActiveSensingCommandRecord *>(
      hot_state + uniforms.accepted_active_sensing_offset
    );
  device const NBActiveSensingEfficacyRecord *sensing_efficacy =
    reinterpret_cast<device const NBActiveSensingEfficacyRecord *>(
      hot_state + uniforms.active_sensing_efficacy_offset
    );
  device const NBObjectSlotRecord *object_slots =
    reinterpret_cast<device const NBObjectSlotRecord *>(
      hot_state + uniforms.object_slot_offset
    );

  const uint sample_count = min(
    min(uniforms.surprise_sample_count, uniforms.recurrent_scalar_count),
    64u
  );
  float surprise = 0.0f;
  for (uint index = 0u; index < sample_count; ++index) {
    surprise += abs(recurrent[index] - workspace[index % uniforms.workspace_scalar_count]);
  }
  surprise = sample_count > 0u ? surprise / float(sample_count) : 0.0f;
  float event_salience = 0.0f;
  uint strongest_event_kind = 0u;
  uint strongest_source = 0u;
  uint strongest_flags = 0u;
  float damage = 0.0f;
  for (uint index = 0u; index < event_count; ++index) {
    const NBReceptorEventRecord event = events[index];
    if (event.magnitude > event_salience) {
      event_salience = event.magnitude;
      strongest_event_kind = event.kind;
      strongest_source = event.source_identifier;
      strongest_flags = event.flags;
    }
    if (event.kind == 8u || event.kind == 9u) {
      damage = max(damage, event.magnitude);
    }
  }
  float embodied_salience = 0.0f;
  float embodied_uncertainty = 0.0f;
  uint embodied_source = 0u;
  for (uint body_index = 0u;
      body_index < uniforms.body_belief_count; ++body_index) {
    device const float *body = reinterpret_cast<device const float *>(
      hot_state + uniforms.body_belief_offset + ulong(body_index) * 256ul
    );
    device const ulong *identity = reinterpret_cast<device const ulong *>(
      body + 16
    );
    if ((identity[3] & 1ul) == 0ul
        || !isfinite(body[8]) || !isfinite(body[9])
        || !isfinite(body[10]) || !isfinite(body[11])) continue;
    const float load = max(body[8], 0.0f);
    const float normalized_load = load / (1.0f + load);
    const float uncertainty = sqrt(max(body[9], 0.0f));
    const float normalized_uncertainty = uncertainty / (1.0f + uncertainty);
    const float vulnerability = clamp(body[10], 0.0f, 1.0f);
    const float damage_risk = clamp(body[11], 0.0f, 1.0f);
    const float salience = max(
      max(damage_risk, vulnerability), 0.5f * normalized_load
    );
    if (salience > embodied_salience) {
      embodied_salience = salience;
      embodied_source = body_index;
    }
    embodied_uncertainty = max(
      embodied_uncertainty, normalized_uncertainty
    );
    damage = max(damage, damage_risk);
  }
  if (embodied_salience > event_salience) {
    strongest_event_kind = 9u;
    strongest_source = embodied_source;
    strongest_flags = 0u;
  }
  float information_salience = 0.0f;
  float information_prior_uncertainty = 0.0f;
  ulong information_entity_identifier = 0ul;
  for (uint channel = 0u; channel < uniforms.active_sensing_count; ++channel) {
    const NBActiveSensingCommandRecord command = sensing_commands[channel];
    const NBActiveSensingEfficacyRecord efficacy = sensing_efficacy[channel];
    const uint target_slot = command.attention_allocation_mask >> 16u;
    if ((command.kind_and_flags & (1u << 16u)) == 0u
        || (command.kind_and_flags & 0xffu) != 1u
        || target_slot == 0u || target_slot > uniforms.object_slot_count
        || (efficacy.flags & 1u) == 0u || efficacy.allocation <= 0.0f) continue;
    const NBObjectSlotRecord object = object_slots[target_slot - 1u];
    if (object.identifier == 0ul || object.existence_probability <= 0.0f) continue;
    const float realized = clamp(efficacy.realized_information_gain, 0.0f, 1.0f);
    if (realized > information_salience) {
      information_salience = realized;
      information_prior_uncertainty = clamp(
        efficacy.prior_uncertainty, 0.0f, 1.0f
      );
      information_entity_identifier = object.identifier;
    }
  }
  const float control_interrupt_salience = control_interrupt_onset ? 1.0f : 0.0f;
  if (control_interrupt_salience > max(event_salience, embodied_salience)) {
    strongest_event_kind = 9u;
    strongest_source = uint(
      control->active_option_identifier
        ^ (control->active_option_identifier >> 32u)
    );
    strongest_flags = 0u;
  }
  if (information_salience > max(
      max(event_salience, embodied_salience), control_interrupt_salience
    )) {
    strongest_event_kind = 11u;
    strongest_source = uint(
      information_entity_identifier ^ (information_entity_identifier >> 32u)
    );
    strongest_flags = 1u << 8u;
  }
  const float boundary_score = max(memory_parameters[0], 0.0f) * surprise
    + uniforms.event_salience_weight * max(memory_parameters[4], 0.0f)
      * max(max(event_salience, embodied_salience), control_interrupt_salience)
    + 0.25f * embodied_uncertainty
    + 0.25f * information_salience;
  device NBActiveEpisodeAccumulator *accumulator =
    reinterpret_cast<device NBActiveEpisodeAccumulator *>(
      hot_state + uniforms.active_episode_accumulator_offset
    );
  bool valid_accumulator = accumulator->format_version
      == NB_MEMORY_EPISODE_RECORD_VERSION
    && accumulator->identifier != 0ul;
  const bool goal_transition = valid_accumulator
    && accumulator->active_goal_identifier != control->active_goal_identifier;
  const bool option_transition = valid_accumulator
    && accumulator->active_option_identifier != control->active_option_identifier;
  bool completed_episode_this_root = false;
  if (goal_transition || option_transition) {
    if (goal_transition && accumulator->goal_transition_count != ~0u) {
      accumulator->goal_transition_count += 1u;
    }
    if (option_transition && accumulator->option_transition_count != ~0u) {
      accumulator->option_transition_count += 1u;
    }
    journal_accumulated_episode(
      hot_state, persistent_memory, journal, uniforms, accumulator
    );
    completed_episode_this_root = true;
    NBActiveEpisodeAccumulator cleared = {};
    *accumulator = cleared;
    valid_accumulator = false;
  }
  if (!valid_accumulator) {
    NBActiveEpisodeAccumulator initial = {};
    initial.identifier = ((uniforms.episode_identifier << 32)
      ^ uniforms.control_step_identifier ^ uniforms.shadow_generation
      ^ uniforms.target_timestamp_microseconds) | 1ul;
    initial.start_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    initial.last_timestamp_microseconds = uniforms.target_timestamp_microseconds;
    initial.parameter_version_fingerprint = uniforms.parameter_version_fingerprint;
    initial.source_generation = uniforms.shadow_generation;
    initial.active_goal_identifier = control->active_goal_identifier;
    initial.active_option_identifier = control->active_option_identifier;
    initial.last_boundary_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    initial.format_version = NB_MEMORY_EPISODE_RECORD_VERSION;
    *accumulator = initial;
  }

  accumulator->last_timestamp_microseconds = uniforms.target_timestamp_microseconds;
  accumulator->source_generation = uniforms.shadow_generation;
  if (accumulator->sample_count != ~0u) accumulator->sample_count += 1u;
  if (accumulator->event_count <= ~0u - event_count) {
    accumulator->event_count += event_count;
  } else {
    accumulator->event_count = ~0u;
  }
  accumulator->maximum_salience = max(
    accumulator->maximum_salience, boundary_score
  );
  accumulator->epistemic_sum += max(
    max(surprise, embodied_uncertainty), information_prior_uncertainty
  );
  accumulator->maximum_damage = max(accumulator->maximum_damage, damage);
  accumulator->reinforcement_sum += information_salience - damage;
  accumulator->latest_surprise = surprise;
  accumulator->latest_boundary_score = boundary_score;
  const float accepted_salience = max(
    max(max(event_salience, embodied_salience), control_interrupt_salience),
    information_salience
  );
  if (accepted_salience >= accumulator->latest_event_salience) {
    accumulator->event_kind = strongest_event_kind;
    accumulator->source_identifier = strongest_source;
    accumulator->flags |= strongest_flags;
    accumulator->latest_event_salience = accepted_salience;
    if ((strongest_flags & (1u << 8u)) != 0u) {
      accumulator->reserved_identity = information_entity_identifier;
    }
  }
  for (uint index = 0u; index < 30u; ++index) {
    if (index == 8u && accumulator->reserved_identity != 0ul) {
      accumulator->retrieval_key_sum[index] += float(
        uint(accumulator->reserved_identity)
      ) / 4294967295.0f;
    } else if (index == 9u && accumulator->reserved_identity != 0ul) {
      accumulator->retrieval_key_sum[index] += float(
        uint(accumulator->reserved_identity >> 32u)
      ) / 4294967295.0f;
    } else {
      accumulator->retrieval_key_sum[index] += recurrent[
        index % uniforms.recurrent_scalar_count
      ];
    }
  }

  const bool salient_boundary = boundary_score >= uniforms.boundary_threshold
    || event_count > 0u
    || embodied_salience >= uniforms.boundary_threshold
    || information_salience >= uniforms.boundary_threshold
    || control_interrupt_onset
    || uniforms.target_timestamp_microseconds
      - accumulator->start_timestamp_microseconds >= 2000000ul;
  if (salient_boundary && !completed_episode_this_root) {
    accumulator->last_boundary_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    journal_accumulated_episode(
      hot_state, persistent_memory, journal, uniforms, accumulator
    );
    NBActiveEpisodeAccumulator cleared = {};
    *accumulator = cleared;
  }
}

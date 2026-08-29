#include <metal_stdlib>
using namespace metal;

constant uint NB_MEMORY_EPISODE_RECORD_VERSION = 1u;
constant uint NB_MEMORY_MUTATION_SECTION_ACTIVE_EPISODE = 1u;
constant uint NB_MEMORY_MUTATION_SECTION_COMPRESSED_EPISODE = 2u;
constant uint NB_MEMORY_MUTATION_SECTION_ARCHIVE_EPISODE = 9u;
constant uint NB_MEMORY_MUTATION_SECTION_SEMANTIC_CONCEPT = 3u;
constant uint NB_MEMORY_MUTATION_SECTION_SEMANTIC_RELATION = 4u;
constant uint NB_MEMORY_MUTATION_SECTION_PROCEDURAL_SKILL = 5u;
constant uint NB_MEMORY_MUTATION_SECTION_PROSPECTIVE_INTENTION = 6u;
constant uint NB_MEMORY_MUTATION_SECTION_REPLAY_QUEUE = 7u;
constant uint NB_MEMORY_MUTATION_SECTION_COMMITTED_TRANSITION = 8u;
constant uint NB_MEMORY_JOURNAL_STATUS_CAPACITY = 1u << 4;
constant uint NB_MEMORY_RECORD_VERSION = 1u;
constant uint NB_MEMORY_CONTROL_FLAG_VALID = 1u;
constant uint NB_MEMORY_CONTROL_FLAG_HYPERDIRECT_STOP = 1u << 1;
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
  ulong active_episode_accumulator_offset;
  ulong active_episode_memory_offset;
  ulong compressed_episode_memory_offset;
  ulong archive_episode_memory_offset;
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
  uint journal_entry_capacity;
  uint surprise_sample_count;
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
  ulong semantic_memory_offset;
  ulong semantic_relation_memory_offset;
  ulong procedural_memory_offset;
  ulong replay_memory_offset;
  ulong persistent_memory_byte_count;
  ulong journal_byte_count;
  uint active_episode_capacity;
  uint active_episode_stride;
  uint semantic_capacity;
  uint semantic_stride;
  uint semantic_relation_capacity;
  uint semantic_relation_stride;
  uint procedural_capacity;
  uint procedural_stride;
  uint replay_capacity;
  uint replay_stride;
  uint journal_entry_capacity;
  uint minimum_procedural_episodes;
  uint flags;
  uint reserved;
  float maximum_damage;
  float minimum_salience;
  float procedural_learning_rate;
  float semantic_learning_rate;
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
  ulong drive_offset;
  ulong neuromodulation_offset;
  ulong transition_memory_offset;
  ulong persistent_memory_byte_count;
  ulong journal_byte_count;
  uint recurrent_scalar_count;
  uint observation_count;
  uint action_count;
  uint drive_count;
  uint neuromodulator_count;
  uint transition_capacity;
  uint transition_stride;
  uint journal_entry_capacity;
  uint teacher_scalar_count;
  uint teacher_flags;
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

struct NBMemoryRetrievalScratch {
  atomic_uint winner_keys[4];
  ulong winner_record_identifiers[4];
  uint winner_kinds[4];
  uint winner_indices[4];
  float winner_scores[4];
  uint flags;
  uint reserved[39];
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
  uint format_version;
  uint flags;
  uint goal_parameter_dimension;
  uint reserved;
  float competence;
  float damage_cvar;
  float expected_effort;
  float expected_value;
  float policy_code[16];
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
  ulong last_intention_identifier;
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
  float reserved_tail[4];
};

struct NBReplayQueueSummaryRecord {
  uint queue_kind;
  uint record_kind;
  ulong record_identifier;
  float priority;
  uint replay_count;
  ulong enqueued_timestamp_microseconds;
};

static_assert(sizeof(NBMemoryUniforms) == 176);
static_assert(sizeof(NBEventQueueHeader) == 32);
static_assert(sizeof(NBReceptorEventRecord) == 32);
static_assert(sizeof(NBMemoryJournalHeader) == 48);
static_assert(sizeof(NBMemoryMutation) == 64);
static_assert(sizeof(NBEpisodicSummaryRecord) == 128);
static_assert(sizeof(NBArchivedEpisodicRecord) == 128);
static_assert(sizeof(NBActiveEpisodeAccumulator) == 256);
static_assert(sizeof(NBMemoryRetrievalUniforms) == 232);
static_assert(sizeof(NBMemoryConsolidationUniforms) == 184);
static_assert(sizeof(NBProspectiveLifecycleUniforms) == 112);
static_assert(sizeof(NBCommittedTransitionUniforms) == 192);
static_assert(sizeof(NBWorkspaceMetadataRecord) == 64);
static_assert(sizeof(NBControlHeader) == 128);
static_assert(sizeof(NBInternalActionRecord) == 64);
static_assert(sizeof(NBDevelopmentalHeader) == 256);
static_assert(sizeof(NBDriveRecord) == 32);
static_assert(sizeof(NBNeuromodulatorRecord) == 16);
static_assert(sizeof(NBMemoryRetrievalScratch) == 256);
static_assert(sizeof(NBSemanticConceptSummaryRecord) == 128);
static_assert(sizeof(NBSemanticRelationSummaryRecord) == 96);
static_assert(sizeof(NBProceduralSkillSummaryRecord) == 128);
static_assert(sizeof(NBProspectiveIntentionSummaryRecord) == 128);
static_assert(sizeof(NBProspectiveLifecycleState) == 256);
static_assert(sizeof(NBCommittedTransitionRecord) == 640);
static_assert(sizeof(NBReplayQueueSummaryRecord) == 32);

inline ulong consolidation_hash(ulong value) {
  value ^= value >> 30;
  value *= 0xbf58476d1ce4e5b9ul;
  value ^= value >> 27;
  value *= 0x94d049bb133111ebul;
  return value ^ (value >> 31);
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

inline bool journal_accumulated_episode(
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
      append_memory_record(
        journal, uniforms, archived, archive_destination,
        NB_MEMORY_MUTATION_SECTION_ARCHIVE_EPISODE, archived.identifier
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
      device const NBArchivedEpisodicRecord *record =
        reinterpret_cast<device const NBArchivedEpisodicRecord *>(
          persistent_memory + uniforms.archive_episode_memory_offset
            + ulong(archive_index) * ulong(uniforms.archive_episode_stride)
        );
      if (record->format_version == NB_MEMORY_EPISODE_RECORD_VERSION
          && record->identifier != 0ul
          && record->coarse_cluster == selected_cluster) {
        kind = 7u;
        identifier = record->identifier;
        score = 0.65f * uniforms.episodic_weight
          * max(memory_parameters[0], 0.0f) * (
            archive_retrieval_similarity(
              query, uniforms.recurrent_scalar_count, record
            ) + record->salience
              - max(memory_parameters[6], 0.0f)
                * record->epistemic_uncertainty
          );
      }
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
        if (record->format_version == 1u && record->identifier != 0ul
            && (record->flags & 4u) == 0u) {
          kind = 3u;
          identifier = record->identifier;
          score = uniforms.procedural_weight * max(memory_parameters[2], 0.0f) * (
            retrieval_similarity(
              query, uniforms.recurrent_scalar_count, record->policy_code, 16u
            ) + record->competence - record->damage_cvar
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
          const bool before_deadline = record->deadline_timestamp_microseconds == 0ul
            || uniforms.target_timestamp_microseconds
              <= record->deadline_timestamp_microseconds;
          if (record->format_version == 1u && record->identifier != 0ul
              && (record->status == 1u || record->status == 2u)
              && before_deadline) {
            kind = 4u;
            identifier = record->identifier;
            score = uniforms.prospective_weight * max(memory_parameters[3], 0.0f) * (
              retrieval_similarity(
                query, uniforms.recurrent_scalar_count, record->trigger_code, 16u
              ) + record->priority + record->trigger_confidence
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
  uint kind = 0u;
  ulong identifier = 0ul;
  float score = 0.0f;
  device const float *value = nullptr;
  device const NBArchivedEpisodicRecord *archived_value = nullptr;
  uint value_count = 0u;
  device const float *query = reinterpret_cast<device const float *>(
    hot_state + uniforms.recurrent_offset
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
    value = record->retrieval_key;
    value_count = 10u;
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
      value = record->retrieval_key;
      value_count = 10u;
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
      value_count = min(archived_value->quantized_component_count, 16u);
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
        value = record->policy_code;
        value_count = 16u;
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
  for (uint index = 0u; index < uniforms.workspace_dimension; ++index) {
    if (kind == 7u && archived_value != nullptr) {
      workspace[base + index] = index < value_count
        ? float(archived_value->quantized_retrieval_key[index])
          * archived_value->retrieval_key_scale
        : 0.0f;
    } else {
      workspace[base + index] = index < value_count ? value[index] : 0.0f;
    }
  }
  device NBWorkspaceMetadataRecord *metadata =
    reinterpret_cast<device NBWorkspaceMetadataRecord *>(
      hot_state + uniforms.workspace_metadata_offset
    );
  NBWorkspaceMetadataRecord token = metadata[slot];
  token.identifier = (uniforms.target_timestamp_microseconds << 8) | ulong(slot + 1u);
  token.source_timestamp_microseconds = uniforms.target_timestamp_microseconds;
  token.last_refresh_timestamp_microseconds = uniforms.target_timestamp_microseconds;
  token.entity_identifier = identifier;
  token.provenance_record_identifier = identifier;
  const uint source_module = kind == 2u
    ? 58u
    : (kind == 5u ? 59u
      : (kind == 3u ? 60u : (kind == 4u ? 61u : 56u)));
  token.kind_and_source = 5u | (source_module << 16);
  token.confidence = clamp(score, 0.0f, 1.0f);
  metadata[slot] = token;
  scratch->winner_record_identifiers[uniforms.retrieval_pass] = identifier;
  scratch->winner_kinds[uniforms.retrieval_pass] = kind;
  scratch->winner_indices[uniforms.retrieval_pass] = candidate_index;
  scratch->winner_scores[uniforms.retrieval_pass] = score;
  scratch->flags |= 1u << uniforms.retrieval_pass;
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
  const ulong previous_goal = lifecycle_valid
    ? lifecycle->previous_goal_identifier : 0ul;
  const bool goal_changed = lifecycle_valid
    && previous_goal != control->active_goal_identifier;
  const uint current_goal_origin = uint(control->active_goal_identifier >> 56);
  const ulong current_goal_code = control->active_goal_identifier
    & NB_MEMORY_GOAL_SOURCE_MASK;
  const ulong current_intention_identifier = current_goal_origin == 3u
      && current_goal_code != 0ul
    ? current_goal_code - 1ul : 0ul;
  const uint previous_goal_origin = uint(previous_goal >> 56);
  const ulong previous_goal_code = previous_goal & NB_MEMORY_GOAL_SOURCE_MASK;
  const ulong previous_intention_identifier = previous_goal_origin == 3u
      && previous_goal_code != 0ul
    ? previous_goal_code - 1ul : 0ul;

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
          || control->selected_damage_cvar >= uniforms.failure_risk_threshold) {
        next_status = 4u;
      } else {
        next_status = 2u;
      }
    } else if (goal_changed
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
    && previous_goal_origin != 3u
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
      if (append_memory_record(
          journal, uniforms, intention, destination,
          NB_MEMORY_MUTATION_SECTION_PROSPECTIVE_INTENTION,
          intention.identifier
        )) {
        lifecycle->last_intention_identifier = intention.identifier;
      }
    }
  }

  lifecycle->previous_goal_identifier = control->active_goal_identifier;
  lifecycle->previous_goal_timestamp_microseconds =
    uniforms.target_timestamp_microseconds;
  lifecycle->last_update_timestamp_microseconds =
    uniforms.target_timestamp_microseconds;
  lifecycle->format_version = NB_MEMORY_RECORD_VERSION;
  lifecycle->previous_control_mode = control->mode;
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
  device const uchar *hot_state [[buffer(0)]],
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
    const bool collision = existing->format_version == NB_MEMORY_RECORD_VERSION
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
        / float(max(uniforms.active_episode_capacity, 1u));
      concept.embedding[17] = development->maturation_progress;
      concept.embedding[18] = development->replay_allocation_multiplier;
      append_memory_record(
        journal, uniforms, concept, destination,
        NB_MEMORY_MUTATION_SECTION_SEMANTIC_CONCEPT, concept.identifier
      );
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
      append_memory_record(
        journal, uniforms, goal, goal_destination,
        NB_MEMORY_MUTATION_SECTION_SEMANTIC_CONCEPT, goal.identifier
      );
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
        append_memory_record(
          journal, uniforms, relation, relation_destination,
          NB_MEMORY_MUTATION_SECTION_SEMANTIC_RELATION, relation.identifier
        );
      }
    }
  }

  if (procedural_count >= uniforms.minimum_procedural_episodes) {
    const ulong procedural_identity = consolidation_hash(
      latest->active_option_identifier ^ 0x50524f4345445552ul
    ) & 0x3ffffffffffffffful;
    const ulong procedural_identifier = max(procedural_identity, 1ul);
    const uint procedural_slot = uint(
      procedural_identifier % ulong(uniforms.procedural_capacity)
    );
    const ulong destination = uniforms.procedural_memory_offset
      + ulong(procedural_slot) * ulong(uniforms.procedural_stride);
    device const NBProceduralSkillSummaryRecord *existing =
      reinterpret_cast<device const NBProceduralSkillSummaryRecord *>(
        persistent_memory + destination
      );
    const bool collision = existing->format_version == NB_MEMORY_RECORD_VERSION
      && existing->identifier != 0ul
      && existing->identifier != procedural_identifier;
    if (!collision && (existing->identifier == 0ul
        || existing->last_execution_timestamp_microseconds
          < latest->end_timestamp_microseconds)) {
      const float divisor = 1.0f / float(procedural_count);
      const float mean_damage = accumulated_damage * divisor;
      NBProceduralSkillSummaryRecord skill = {};
      skill.identifier = procedural_identifier;
      skill.last_execution_timestamp_microseconds =
        latest->end_timestamp_microseconds;
      skill.execution_count = ulong(procedural_count);
      skill.parent_skill_identifier = latest->active_option_identifier;
      skill.format_version = NB_MEMORY_RECORD_VERSION;
      skill.flags = 1u;
      skill.goal_parameter_dimension = 16u;
      skill.competence = clamp(
        (1.0f - mean_damage)
          * (1.0f - exp(-procedural_learning_rate
            * float(procedural_count))),
        0.0f, 1.0f
      );
      skill.damage_cvar = mean_damage;
      skill.expected_effort = 0.0f;
      skill.expected_value = accumulated_value * divisor;
      for (uint component = 0u; component < 10u; ++component) {
        skill.policy_code[component] = procedural_code[component] * divisor;
      }
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
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.recurrent_scalar_count == 0u
      || uniforms.observation_count == 0u || uniforms.action_count == 0u
      || uniforms.transition_capacity == 0u) return;
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
  record.format_version = NB_MEMORY_RECORD_VERSION;
  record.flags = 1u;
  record.recurrent_sample_count = min(uniforms.recurrent_scalar_count, 24u);
  record.observation_sample_count = min(uniforms.observation_count, 24u);
  record.action_sample_count = min(uniforms.action_count, 16u);
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
  for (uint component = 0u; component < 24u; ++component) {
    record.prior_state[component] = prior[
      component % uniforms.recurrent_scalar_count
    ];
    record.posterior_state[component] = posterior[
      component % uniforms.recurrent_scalar_count
    ];
    record.observation[component] = observations[
      component % uniforms.observation_count
    ];
  }
  for (uint component = 0u; component < 16u; ++component) {
    record.action[component] = actions[component % uniforms.action_count];
  }
  record.factored_reinforcement[0] = -record.mean_drive_deficit;
  record.factored_reinforcement[1] = control->selected_score;
  record.factored_reinforcement[2] = uniforms.drive_count > 9u
    ? drives[9].potential : 0.0f;
  record.factored_reinforcement[3] = control->predicted_information_gain;
  record.factored_reinforcement[4] = -record.pain;
  record.factored_reinforcement[5] = -control->predicted_effort;
  record.factored_reinforcement[6] = -control->selected_damage_cvar;
  record.factored_reinforcement[7] = -record.model_error;
  record.teacher_content_fingerprint = uniforms.teacher_content_fingerprint;
  record.teacher_scalar_count = min(uniforms.teacher_scalar_count, 24u);
  record.teacher_flags = uniforms.teacher_flags;
  for (uint component = 0u; component < record.teacher_scalar_count; ++component) {
    record.teacher_state[component] = teacher_state[component];
  }

  const uint slot = uint(
    uniforms.shadow_generation % ulong(uniforms.transition_capacity)
  );
  const ulong destination = uniforms.transition_memory_offset
    + ulong(slot) * ulong(uniforms.transition_stride);
  append_memory_record(
    journal, uniforms, record, destination,
    NB_MEMORY_MUTATION_SECTION_COMMITTED_TRANSITION, record.identifier
  );
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
  const float boundary_score = max(memory_parameters[0], 0.0f) * surprise
    + uniforms.event_salience_weight * max(memory_parameters[4], 0.0f)
      * event_salience;
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
      persistent_memory, journal, uniforms, accumulator
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
  accumulator->epistemic_sum += surprise;
  accumulator->maximum_damage = max(accumulator->maximum_damage, damage);
  accumulator->reinforcement_sum -= damage;
  accumulator->latest_surprise = surprise;
  accumulator->latest_boundary_score = boundary_score;
  if (event_salience >= accumulator->latest_event_salience) {
    accumulator->event_kind = strongest_event_kind;
    accumulator->source_identifier = strongest_source;
    accumulator->flags |= strongest_flags;
    accumulator->latest_event_salience = event_salience;
  }
  for (uint index = 0u; index < 30u; ++index) {
    accumulator->retrieval_key_sum[index] += recurrent[
      index % uniforms.recurrent_scalar_count
    ];
  }

  const bool salient_boundary = boundary_score >= uniforms.boundary_threshold
    || event_count > 0u
    || uniforms.target_timestamp_microseconds
      - accumulator->start_timestamp_microseconds >= 2000000ul;
  if (salient_boundary && !completed_episode_this_root) {
    accumulator->last_boundary_timestamp_microseconds =
      uniforms.target_timestamp_microseconds;
    journal_accumulated_episode(
      persistent_memory, journal, uniforms, accumulator
    );
    NBActiveEpisodeAccumulator cleared = {};
    *accumulator = cleared;
  }
}

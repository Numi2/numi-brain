#include <metal_stdlib>
using namespace metal;

constant uint NB_MEMORY_EPISODE_RECORD_VERSION = 1u;
constant uint NB_MEMORY_MUTATION_SECTION_ACTIVE_EPISODE = 1u;
constant uint NB_MEMORY_JOURNAL_STATUS_CAPACITY = 1u << 4;

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
  ulong active_episode_memory_offset;
  ulong journal_byte_count;
  ulong persistent_memory_byte_count;
  uint recurrent_scalar_count;
  uint workspace_scalar_count;
  uint active_episode_capacity;
  uint active_episode_stride;
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

struct NBMemoryRetrievalUniforms {
  ulong target_timestamp_microseconds;
  ulong recurrent_offset;
  ulong workspace_content_offset;
  ulong workspace_metadata_offset;
  ulong retrieval_scratch_offset;
  ulong active_episode_memory_offset;
  ulong semantic_memory_offset;
  ulong procedural_memory_offset;
  ulong prospective_memory_offset;
  ulong control_header_offset;
  ulong parameter_version_fingerprint;
  uint recurrent_scalar_count;
  uint workspace_capacity;
  uint workspace_dimension;
  uint active_episode_capacity;
  uint active_episode_stride;
  uint semantic_capacity;
  uint semantic_stride;
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

static_assert(sizeof(NBMemoryUniforms) == 136);
static_assert(sizeof(NBEventQueueHeader) == 32);
static_assert(sizeof(NBReceptorEventRecord) == 32);
static_assert(sizeof(NBMemoryJournalHeader) == 48);
static_assert(sizeof(NBMemoryMutation) == 64);
static_assert(sizeof(NBEpisodicSummaryRecord) == 128);
static_assert(sizeof(NBMemoryRetrievalUniforms) == 168);
static_assert(sizeof(NBWorkspaceMetadataRecord) == 64);
static_assert(sizeof(NBControlHeader) == 128);
static_assert(sizeof(NBMemoryRetrievalScratch) == 256);
static_assert(sizeof(NBSemanticConceptSummaryRecord) == 128);
static_assert(sizeof(NBProceduralSkillSummaryRecord) == 128);
static_assert(sizeof(NBProspectiveIntentionSummaryRecord) == 128);

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
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.candidate_count
      || uniforms.retrieval_pass >= min(uniforms.maximum_results, 4u)) return;
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
      score = uniforms.episodic_weight * (
        retrieval_similarity(
          query, uniforms.recurrent_scalar_count, record->retrieval_key, 10u
        ) + record->salience - 0.25f * record->epistemic_uncertainty
      );
    }
  } else {
    local_index -= uniforms.active_episode_capacity;
    if (local_index < uniforms.semantic_capacity) {
      device const NBSemanticConceptSummaryRecord *record =
        reinterpret_cast<device const NBSemanticConceptSummaryRecord *>(
          persistent_memory + uniforms.semantic_memory_offset
            + ulong(local_index) * ulong(uniforms.semantic_stride)
        );
      if (record->format_version == 1u && record->identifier != 0ul) {
        kind = 2u;
        identifier = record->identifier;
        score = uniforms.semantic_weight * (
          retrieval_similarity(
            query, uniforms.recurrent_scalar_count, record->embedding, 19u
          ) + record->confidence
        );
      }
    } else {
      local_index -= uniforms.semantic_capacity;
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
          score = uniforms.procedural_weight * (
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
              && record->status == 1u && before_deadline) {
            kind = 4u;
            identifier = record->identifier;
            score = uniforms.prospective_weight * (
              retrieval_similarity(
                query, uniforms.recurrent_scalar_count, record->trigger_code, 16u
              ) + record->priority + record->trigger_confidence
            );
          }
        }
      }
    }
  }
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
  uint value_count = 0u;
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
  const uint slot = 3u + uniforms.retrieval_pass;
  if (slot >= uniforms.workspace_capacity) return;
  device float *workspace = reinterpret_cast<device float *>(
    hot_state + uniforms.workspace_content_offset
  );
  const uint base = slot * uniforms.workspace_dimension;
  for (uint index = 0u; index < uniforms.workspace_dimension; ++index) {
    workspace[base + index] = index < value_count ? value[index] : 0.0f;
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
  token.kind_and_source = 5u | (56u << 16);
  token.confidence = clamp(score, 0.0f, 1.0f);
  metadata[slot] = token;
  scratch->winner_record_identifiers[uniforms.retrieval_pass] = identifier;
  scratch->winner_kinds[uniforms.retrieval_pass] = kind;
  scratch->winner_indices[uniforms.retrieval_pass] = candidate_index;
  scratch->winner_scores[uniforms.retrieval_pass] = score;
  scratch->flags |= 1u << uniforms.retrieval_pass;
}

kernel void segment_and_journal_episode(
  device uchar *hot_state [[buffer(0)]],
  device uchar *persistent_memory [[buffer(1)]],
  device NBMemoryJournalHeader *journal [[buffer(2)]],
  constant NBMemoryUniforms &uniforms [[buffer(3)]],
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
  const float boundary_score = surprise
    + uniforms.event_salience_weight * event_salience;
  if (boundary_score < uniforms.boundary_threshold && event_count == 0u) return;

  NBEpisodicSummaryRecord record;
  record.identifier = (uniforms.episode_identifier << 32)
    ^ uniforms.control_step_identifier ^ uniforms.shadow_generation;
  record.start_timestamp_microseconds = uniforms.base_generation == 0ul
    ? 0ul
    : uniforms.target_timestamp_microseconds;
  record.end_timestamp_microseconds = uniforms.target_timestamp_microseconds;
  record.parameter_version_fingerprint = uniforms.parameter_version_fingerprint;
  record.source_generation = uniforms.shadow_generation;
  record.active_goal_identifier = control->active_goal_identifier;
  record.active_option_identifier = control->active_option_identifier;
  record.format_version = NB_MEMORY_EPISODE_RECORD_VERSION;
  record.event_kind = strongest_event_kind;
  record.source_identifier = strongest_source;
  record.flags = strongest_flags | 1u;
  record.salience = clamp(boundary_score, 0.0f, 1.0f);
  record.epistemic_uncertainty = surprise;
  record.damage_severity = damage;
  record.factored_reinforcement = -damage;
  for (uint index = 0u; index < 10u; ++index) {
    record.retrieval_key[index] = recurrent[index % uniforms.recurrent_scalar_count];
  }

  constexpr uint chunk_byte_count = 16u;
  constexpr uint chunk_count = sizeof(NBEpisodicSummaryRecord) / chunk_byte_count;
  const uint first_entry = atomic_fetch_add_explicit(
    &journal->entry_count,
    chunk_count,
    memory_order_relaxed
  );
  if (first_entry + chunk_count > journal->entry_capacity
      || first_entry + chunk_count > uniforms.journal_entry_capacity) {
    atomic_fetch_or_explicit(
      &journal->status,
      NB_MEMORY_JOURNAL_STATUS_CAPACITY,
      memory_order_relaxed
    );
    return;
  }
  const uint slot = uint(record.identifier % ulong(uniforms.active_episode_capacity));
  const ulong record_destination = uniforms.active_episode_memory_offset
    + ulong(slot) * ulong(uniforms.active_episode_stride);
  if (record_destination + sizeof(NBEpisodicSummaryRecord)
      > uniforms.persistent_memory_byte_count) {
    atomic_fetch_or_explicit(
      &journal->status,
      NB_MEMORY_JOURNAL_STATUS_CAPACITY,
      memory_order_relaxed
    );
    return;
  }
  device NBMemoryMutation *entries =
    reinterpret_cast<device NBMemoryMutation *>(journal + 1);
  const thread uint *record_words = reinterpret_cast<const thread uint *>(&record);
  for (uint chunk = 0u; chunk < chunk_count; ++chunk) {
    NBMemoryMutation mutation;
    mutation.destination_byte_offset = record_destination
      + ulong(chunk * chunk_byte_count);
    mutation.shadow_generation = uniforms.shadow_generation;
    for (uint word = 0u; word < 4u; ++word) {
      mutation.payload[word] = record_words[chunk * 4u + word];
    }
    mutation.byte_count = chunk_byte_count;
    mutation.section = NB_MEMORY_MUTATION_SECTION_ACTIVE_EPISODE;
    mutation.sequence = chunk;
    mutation.flags = 0u;
    mutation.record_identifier = record.identifier;
    mutation.reserved = 0ul;
    entries[first_entry + chunk] = mutation;
  }
}

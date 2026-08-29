#include <metal_stdlib>
using namespace metal;

constant uint NB_DEVELOPMENTAL_STATE_VERSION = 1u;
constant uint NB_DEVELOPMENTAL_STATE_VALID = 1u;

struct NBDevelopmentalUniforms {
  ulong target_timestamp_microseconds;
  ulong delta_microseconds;
  ulong developmental_state_offset;
  ulong evidence_state_offset;
  ulong maturation_state_offset;
  ulong accepted_physics_state_fingerprint;
  ulong species_template_fingerprint;
  uint stage_count;
  uint capability_code_count;
  uint evidence_capacity;
  uint module_count;
  uint imported_evidence_count;
  uint reserved0;
  uint reserved1;
  uint reserved2;
};

struct NBDevelopmentalStageDescriptor {
  uint stage;
  uint workspace_capacity;
  uint planning_horizon_steps;
  uint capability_start;
  uint capability_count;
  uint reserved0;
  float learning_rate_multiplier;
  float sensor_precision_multiplier;
  float muscle_strength_multiplier;
  float replay_allocation_multiplier;
  ulong unlocked_module_mask_low;
  ulong unlocked_module_mask_high;
  ulong reserved1;
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

struct NBDevelopmentalEvidenceRecord {
  ulong code;
  ulong timestamp_microseconds;
  ulong accepted_physics_state_fingerprint;
  float confidence;
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

static_assert(sizeof(NBDevelopmentalUniforms) == 88);
static_assert(sizeof(NBDevelopmentalStageDescriptor) == 64);
static_assert(sizeof(NBDevelopmentalHeader) == 256);
static_assert(sizeof(NBDevelopmentalEvidenceRecord) == 32);
static_assert(sizeof(NBRegionalMaturationRecord) == 32);

inline bool nb_module_unlocked(
  const NBDevelopmentalStageDescriptor stage,
  uint module_identifier)
{
  if (module_identifier == 0u || module_identifier > 128u) return false;
  const uint bit = module_identifier - 1u;
  return bit < 64u
    ? ((stage.unlocked_module_mask_low >> bit) & 1ul) != 0ul
    : ((stage.unlocked_module_mask_high >> (bit - 64u)) & 1ul) != 0ul;
}

kernel void initialize_developmental_state(
  device uchar *hot_state [[buffer(0)]],
  device const NBDevelopmentalStageDescriptor *stages [[buffer(1)]],
  device const ulong *capability_codes [[buffer(2)]],
  device const uint *module_identifiers [[buffer(3)]],
  constant NBDevelopmentalUniforms &uniforms [[buffer(4)]],
  device const NBDevelopmentalEvidenceRecord *imported_evidence [[buffer(5)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.stage_count == 0u) return;
  device NBDevelopmentalHeader *header =
    reinterpret_cast<device NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  if (header->format_version == NB_DEVELOPMENTAL_STATE_VERSION) return;
  const NBDevelopmentalStageDescriptor stage = stages[0];
  NBDevelopmentalHeader initial;
  initial.format_version = NB_DEVELOPMENTAL_STATE_VERSION;
  initial.stage = 0u;
  initial.stage_count = uniforms.stage_count;
  initial.flags = NB_DEVELOPMENTAL_STATE_VALID;
  initial.developmental_age_microseconds = 0ul;
  initial.last_transition_timestamp_microseconds = uniforms.target_timestamp_microseconds;
  initial.maturation_progress = 0.0f;
  initial.sensor_precision_multiplier = stage.sensor_precision_multiplier;
  initial.muscle_strength_multiplier = stage.muscle_strength_multiplier;
  initial.replay_allocation_multiplier = stage.replay_allocation_multiplier;
  initial.learning_rate_multiplier = stage.learning_rate_multiplier;
  initial.workspace_capacity = stage.workspace_capacity;
  initial.planning_horizon_steps = stage.planning_horizon_steps;
  initial.module_count = uniforms.module_count;
  initial.evidence_count = 0u;
  initial.species_template_fingerprint = uniforms.species_template_fingerprint;
  initial.accepted_physics_state_fingerprint = 0ul;
  for (uint index = 0u; index < 21u; ++index) initial.reserved[index] = 0ul;
  *header = initial;
}

kernel void record_developmental_capability_evidence(
  device uchar *hot_state [[buffer(0)]],
  device const NBDevelopmentalStageDescriptor *stages [[buffer(1)]],
  device const ulong *capability_codes [[buffer(2)]],
  device const uint *module_identifiers [[buffer(3)]],
  constant NBDevelopmentalUniforms &uniforms [[buffer(4)]],
  device const NBDevelopmentalEvidenceRecord *imported_evidence [[buffer(5)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.imported_evidence_count) return;
  const NBDevelopmentalEvidenceRecord evidence = imported_evidence[gid];
  if (evidence.code == 0ul || evidence.confidence < 0.5f
      || evidence.timestamp_microseconds != uniforms.target_timestamp_microseconds
      || evidence.accepted_physics_state_fingerprint
        != uniforms.accepted_physics_state_fingerprint) return;
  device NBDevelopmentalEvidenceRecord *state =
    reinterpret_cast<device NBDevelopmentalEvidenceRecord *>(
      hot_state + uniforms.evidence_state_offset
    );
  for (uint index = 0u; index < uniforms.capability_code_count; ++index) {
    if (capability_codes[index] == evidence.code) state[index] = evidence;
  }
}

kernel void advance_developmental_stage_from_capabilities(
  device uchar *hot_state [[buffer(0)]],
  device const NBDevelopmentalStageDescriptor *stages [[buffer(1)]],
  device const ulong *capability_codes [[buffer(2)]],
  device const uint *module_identifiers [[buffer(3)]],
  constant NBDevelopmentalUniforms &uniforms [[buffer(4)]],
  device const NBDevelopmentalEvidenceRecord *imported_evidence [[buffer(5)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u || uniforms.stage_count == 0u) return;
  device NBDevelopmentalHeader *header =
    reinterpret_cast<device NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  header->developmental_age_microseconds += uniforms.delta_microseconds;
  header->accepted_physics_state_fingerprint =
    uniforms.accepted_physics_state_fingerprint;
  const uint current_stage = min(header->stage, uniforms.stage_count - 1u);
  const ulong elapsed = uniforms.target_timestamp_microseconds
    >= header->last_transition_timestamp_microseconds
    ? uniforms.target_timestamp_microseconds
      - header->last_transition_timestamp_microseconds
    : 0ul;
  header->maturation_progress = clamp(float(elapsed) * 1.0e-6f, 0.0f, 1.0f);
  if (current_stage + 1u >= uniforms.stage_count) return;
  const NBDevelopmentalStageDescriptor next_stage = stages[current_stage + 1u];
  if (next_stage.capability_count == 0u) return;
  device const NBDevelopmentalEvidenceRecord *evidence_state =
    reinterpret_cast<device const NBDevelopmentalEvidenceRecord *>(
      hot_state + uniforms.evidence_state_offset
    );
  bool qualified = true;
  for (uint gate = 0u; gate < next_stage.capability_count; ++gate) {
    const uint index = next_stage.capability_start + gate;
    if (index >= uniforms.capability_code_count
        || evidence_state[index].code != capability_codes[index]
        || evidence_state[index].confidence < 0.5f
        || evidence_state[index].timestamp_microseconds
          > uniforms.target_timestamp_microseconds) {
      qualified = false;
      break;
    }
  }
  if (!qualified) return;
  header->stage = current_stage + 1u;
  header->last_transition_timestamp_microseconds =
    uniforms.target_timestamp_microseconds;
  header->maturation_progress = 0.0f;
  header->sensor_precision_multiplier = next_stage.sensor_precision_multiplier;
  header->muscle_strength_multiplier = next_stage.muscle_strength_multiplier;
  header->replay_allocation_multiplier = next_stage.replay_allocation_multiplier;
  header->learning_rate_multiplier = next_stage.learning_rate_multiplier;
  header->workspace_capacity = next_stage.workspace_capacity;
  header->planning_horizon_steps = next_stage.planning_horizon_steps;
  header->evidence_count += next_stage.capability_count;
}

kernel void update_regional_maturation_state(
  device uchar *hot_state [[buffer(0)]],
  device const NBDevelopmentalStageDescriptor *stages [[buffer(1)]],
  device const ulong *capability_codes [[buffer(2)]],
  device const uint *module_identifiers [[buffer(3)]],
  constant NBDevelopmentalUniforms &uniforms [[buffer(4)]],
  device const NBDevelopmentalEvidenceRecord *imported_evidence [[buffer(5)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid >= uniforms.module_count || uniforms.stage_count == 0u) return;
  device const NBDevelopmentalHeader *header =
    reinterpret_cast<device const NBDevelopmentalHeader *>(
      hot_state + uniforms.developmental_state_offset
    );
  const NBDevelopmentalStageDescriptor stage = stages[
    min(header->stage, uniforms.stage_count - 1u)
  ];
  const uint module_identifier = module_identifiers[gid];
  const bool unlocked = nb_module_unlocked(stage, module_identifier);
  device NBRegionalMaturationRecord *records =
    reinterpret_cast<device NBRegionalMaturationRecord *>(
      hot_state + uniforms.maturation_state_offset
    );
  NBRegionalMaturationRecord record;
  record.module_identifier = module_identifier;
  record.unlocked = unlocked ? 1u : 0u;
  record.learning_rate_multiplier = unlocked
    ? stage.learning_rate_multiplier : 0.0f;
  record.timescale_multiplier = unlocked ? 1.0f : 4.0f;
  record.route_gain_multiplier = unlocked ? 1.0f : 0.0f;
  record.conduction_delay_multiplier = unlocked ? 1.0f : 4.0f;
  record.capacity_fraction = unlocked
    ? max(header->maturation_progress, 0.05f) : 0.0f;
  record.flags = NB_DEVELOPMENTAL_STATE_VALID;
  records[gid] = record;
}

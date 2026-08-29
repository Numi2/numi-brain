#include <metal_stdlib>
using namespace metal;

constant uint NB_AGENT_ARENA_VERSION = 1u;
constant uint NB_AGENT_JOURNAL_ENTRY_WORD_COUNT = 4u;
constant uint NB_AGENT_JOURNAL_STATUS_VALID = 1u;
constant uint NB_AGENT_JOURNAL_STATUS_INVALID_HEADER = 1u << 1;
constant uint NB_AGENT_JOURNAL_STATUS_OUT_OF_BOUNDS = 1u << 2;
constant uint NB_AGENT_JOURNAL_STATUS_INVALID_ENTRY = 1u << 3;

struct NBAgentArenaUniforms {
  ulong base_generation;
  ulong shadow_generation;
  ulong hot_byte_count;
  ulong memory_byte_count;
  ulong journal_byte_count;
  ulong archive_page_residency_offset;
  ulong archive_page_request_offset;
  uint journal_entry_capacity;
  uint apply_mutations;
  uint archive_page_count;
  uint archive_page_request_capacity;
};

struct NBCheckpointCopyUniforms {
  ulong hot_byte_count;
  ulong memory_byte_count;
  ulong journal_byte_count;
};

struct NBMemoryRangeCopyUniforms {
  ulong byte_count;
};

struct NBArchivePageResidencyUniforms {
  uint page_count;
  uint update_count;
  uint resident_state;
  uint clear_requests;
};

struct NBArchivePageRequestQueueHeader {
  atomic_uint request_count;
  uint request_capacity;
  atomic_uint overflow_count;
  uint flags;
  ulong latest_request_timestamp_microseconds;
  ulong shadow_generation;
};

struct NBAgentMemoryJournalHeader {
  uint format_version;
  atomic_uint entry_count;
  uint entry_capacity;
  atomic_uint status;
  ulong base_generation;
  ulong shadow_generation;
  ulong memory_byte_count;
  ulong reserved;
};

/// One fixed 16-byte write into persistent individual memory. Larger logical
/// mutations are emitted as ordered, non-overlapping chunks by the owning
/// memory kernel.
struct NBAgentMemoryMutation {
  ulong destination_byte_offset;
  ulong shadow_generation;
  uint payload[NB_AGENT_JOURNAL_ENTRY_WORD_COUNT];
  uint byte_count;
  uint section;
  uint sequence;
  uint flags;
  ulong record_identifier;
  ulong reserved;
};

static_assert(sizeof(NBAgentArenaUniforms) == 72);
static_assert(sizeof(NBCheckpointCopyUniforms) == 24);
static_assert(sizeof(NBMemoryRangeCopyUniforms) == 8);
static_assert(sizeof(NBArchivePageResidencyUniforms) == 16);
static_assert(sizeof(NBArchivePageRequestQueueHeader) == 32);
static_assert(sizeof(NBAgentMemoryJournalHeader) == 48);
static_assert(sizeof(NBAgentMemoryMutation) == 64);

kernel void snapshot_agent_checkpoint(
  device const uint *committed_hot_state [[buffer(0)]],
  device const uint *persistent_memory [[buffer(1)]],
  device uint *hot_snapshot [[buffer(2)]],
  device uint *memory_snapshot [[buffer(3)]],
  constant NBCheckpointCopyUniforms &uniforms [[buffer(4)]],
  uint gid [[thread_position_in_grid]])
{
  const ulong byte_offset = ulong(gid) * sizeof(uint);
  if (byte_offset < uniforms.hot_byte_count) {
    hot_snapshot[gid] = committed_hot_state[gid];
  }
  if (byte_offset < uniforms.memory_byte_count) {
    memory_snapshot[gid] = persistent_memory[gid];
  }
}

kernel void restore_agent_checkpoint(
  device const uint *hot_snapshot [[buffer(0)]],
  device const uint *memory_snapshot [[buffer(1)]],
  device uint *first_hot_state [[buffer(2)]],
  device uint *second_hot_state [[buffer(3)]],
  device uint *persistent_memory [[buffer(4)]],
  device uint *first_journal [[buffer(5)]],
  device uint *second_journal [[buffer(6)]],
  constant NBCheckpointCopyUniforms &uniforms [[buffer(7)]],
  uint gid [[thread_position_in_grid]])
{
  const ulong byte_offset = ulong(gid) * sizeof(uint);
  if (byte_offset < uniforms.hot_byte_count) {
    const uint value = hot_snapshot[gid];
    first_hot_state[gid] = value;
    second_hot_state[gid] = value;
  }
  if (byte_offset < uniforms.memory_byte_count) {
    persistent_memory[gid] = memory_snapshot[gid];
  }
  if (byte_offset < uniforms.journal_byte_count) {
    first_journal[gid] = 0u;
    second_journal[gid] = 0u;
  }
}

kernel void snapshot_agent_memory_range(
  device const uint *source [[buffer(0)]],
  device uint *snapshot [[buffer(1)]],
  constant NBMemoryRangeCopyUniforms &uniforms [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
  const ulong byte_offset = ulong(gid) * sizeof(uint);
  if (byte_offset < uniforms.byte_count) {
    snapshot[gid] = source[gid];
  }
}

kernel void update_archive_page_residency(
  device atomic_uint *page_states [[buffer(0)]],
  device const uint *page_identifiers [[buffer(1)]],
  device NBArchivePageRequestQueueHeader *requests [[buffer(2)]],
  constant NBArchivePageResidencyUniforms &uniforms [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid < uniforms.update_count) {
    const uint page_identifier = page_identifiers[gid];
    if (page_identifier < uniforms.page_count) {
      atomic_store_explicit(
        &page_states[page_identifier], uniforms.resident_state,
        memory_order_relaxed
      );
    }
  }
  if (gid == 0u && uniforms.clear_requests != 0u) {
    atomic_store_explicit(&requests->request_count, 0u, memory_order_relaxed);
    atomic_store_explicit(&requests->overflow_count, 0u, memory_order_relaxed);
    requests->flags = 0u;
    requests->latest_request_timestamp_microseconds = 0ul;
    requests->shadow_generation = 0ul;
  }
}

kernel void initialize_agent_state_arena(
  device uint *hot_state [[buffer(0)]],
  device uint *persistent_memory [[buffer(1)]],
  device uint *journal_zero [[buffer(2)]],
  device uint *journal_one [[buffer(3)]],
  constant NBAgentArenaUniforms &uniforms [[buffer(4)]],
  uint gid [[thread_position_in_grid]])
{
  const ulong byte_offset = ulong(gid) * sizeof(uint);
  if (byte_offset < uniforms.hot_byte_count) {
    uint initial_value = 0u;
    const ulong residency_end = uniforms.archive_page_residency_offset
      + ulong(uniforms.archive_page_count) * sizeof(uint);
    if (byte_offset >= uniforms.archive_page_residency_offset
        && byte_offset < residency_end) {
      initial_value = 1u;
    }
    if (byte_offset == uniforms.archive_page_request_offset + sizeof(uint)) {
      initial_value = uniforms.archive_page_request_capacity;
    }
    hot_state[gid] = initial_value;
  }
  if (byte_offset < uniforms.memory_byte_count) {
    persistent_memory[gid] = 0u;
  }
  if (byte_offset < uniforms.journal_byte_count) {
    journal_zero[gid] = 0u;
    journal_one[gid] = 0u;
  }
}

kernel void begin_agent_state_shadow(
  device const uint *committed_hot_state [[buffer(0)]],
  device uint *shadow_hot_state [[buffer(1)]],
  device uint *shadow_journal_words [[buffer(2)]],
  constant NBAgentArenaUniforms &uniforms [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  const ulong byte_offset = ulong(gid) * sizeof(uint);
  if (byte_offset < uniforms.hot_byte_count) {
    shadow_hot_state[gid] = committed_hot_state[gid];
  }
  if (byte_offset < uniforms.journal_byte_count) {
    shadow_journal_words[gid] = 0u;
  }
  if (gid == 0u) {
    device NBAgentMemoryJournalHeader *header =
      reinterpret_cast<device NBAgentMemoryJournalHeader *>(shadow_journal_words);
    header->format_version = NB_AGENT_ARENA_VERSION;
    atomic_store_explicit(&header->entry_count, 0u, memory_order_relaxed);
    header->entry_capacity = uniforms.journal_entry_capacity;
    atomic_store_explicit(
      &header->status,
      NB_AGENT_JOURNAL_STATUS_VALID,
      memory_order_relaxed
    );
    header->base_generation = uniforms.base_generation;
    header->shadow_generation = uniforms.shadow_generation;
    header->memory_byte_count = uniforms.memory_byte_count;
    header->reserved = 0ul;
  }
}

kernel void apply_agent_memory_journal(
  device uchar *persistent_memory [[buffer(0)]],
  device NBAgentMemoryJournalHeader *header [[buffer(1)]],
  constant NBAgentArenaUniforms &uniforms [[buffer(2)]],
  uint gid [[thread_position_in_grid]])
{
  const uint entry_count = atomic_load_explicit(
    &header->entry_count,
    memory_order_relaxed
  );
  if (header->format_version != NB_AGENT_ARENA_VERSION
      || header->base_generation != uniforms.base_generation
      || header->shadow_generation != uniforms.shadow_generation
      || header->entry_capacity != uniforms.journal_entry_capacity
      || header->memory_byte_count != uniforms.memory_byte_count
      || entry_count > header->entry_capacity) {
    if (gid == 0u) {
      atomic_fetch_or_explicit(
        &header->status,
        NB_AGENT_JOURNAL_STATUS_INVALID_HEADER,
        memory_order_relaxed
      );
    }
    return;
  }
  if (gid >= entry_count) {
    return;
  }

  device NBAgentMemoryMutation *entries =
    reinterpret_cast<device NBAgentMemoryMutation *>(header + 1);
  const NBAgentMemoryMutation mutation = entries[gid];
  if (mutation.shadow_generation != uniforms.shadow_generation
      || mutation.byte_count == 0u
      || mutation.byte_count > sizeof(mutation.payload)) {
    atomic_fetch_or_explicit(
      &header->status,
      NB_AGENT_JOURNAL_STATUS_INVALID_ENTRY,
      memory_order_relaxed
    );
    return;
  }
  const ulong end = mutation.destination_byte_offset + ulong(mutation.byte_count);
  if (end < mutation.destination_byte_offset || end > uniforms.memory_byte_count) {
    atomic_fetch_or_explicit(
      &header->status,
      NB_AGENT_JOURNAL_STATUS_OUT_OF_BOUNDS,
      memory_order_relaxed
    );
    return;
  }

  if (uniforms.apply_mutations != 0u) {
    const thread uchar *payload =
      reinterpret_cast<const thread uchar *>(mutation.payload);
    for (uint byte_index = 0u; byte_index < mutation.byte_count; ++byte_index) {
      persistent_memory[mutation.destination_byte_offset + ulong(byte_index)] =
        payload[byte_index];
    }
  }
}

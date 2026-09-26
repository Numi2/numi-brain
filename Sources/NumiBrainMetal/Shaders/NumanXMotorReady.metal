#include <metal_stdlib>
using namespace metal;

constant uint NB_NUMANX_READY_ABI_VERSION = 1u;
constant uint NB_NUMANX_READY_PENDING = 0u;
constant uint NB_NUMANX_READY_SUCCESS = 1u;
constant uint NB_NUMANX_READY_FAILURE = 2u;
constant uint NB_NUMANX_DECISION_UNCERTAINTY_POLICY_BOUND = 1u << 0u;
constant uint NB_NUMANX_DECISION_SUPERVISION_REQUIRED = 1u << 1u;
constant uint NB_NUMANX_DECISION_ROOT_REJECTED = 1u << 2u;
constant uint NB_NUMANX_UNCERTAINTY_POLICY_ABI_VERSION = 1u;
constant uint NB_NUMANX_DECISION_GATE_BYTES = 160u;
constant uint NB_NUMANX_MOTOR_GATE_BYTES = 160u;
constant uint NB_NUMANX_DECISION_MAX_RANGES = 12u;
constant uint NB_NUMANX_MOTOR_CANDIDATE_VERSION = 7u;
constant uint NB_NUMANX_MOTOR_CANDIDATE_VALID = 1u;
constant uint NB_NUMANX_MOTOR_CANDIDATE_DECISION_SHADOW = 2u;
constant uint NB_MOTOR_OUTPUT_VERSION = 3u;
constant uint NB_MOTOR_OUTPUT_VALID = 1u;
constant uint NB_MOTOR_OUTPUT_EMERGENCY_STOP = 2u;
constant uint NB_MOTOR_OUTPUT_KNOWN_FLAGS = 15u;
constant ulong NB_FNV_OFFSET = 14695981039346656037ul;
constant ulong NB_FNV_PRIME = 1099511628211ul;
// Fill the bounded 256-lane source digest on the live full Human layout:
// 704-byte chunks cover all 256 pieces while shortening each ordered chain.
constant uint NB_DECISION_CHUNK_BYTES = 704u;
constant uint NB_DECISION_CHUNK_LANES = 256u;

struct NBNumanXDecisionReadyGateGPU {
  uint abiVersion;
  uint structBytes;
  uint status;
  uint environment;
  uint rangeCount;
  uint flags;
  uint unsupportedUncertaintyBits;
  uint reserved32_1;
  ulong controlStep;
  ulong transactionFingerprint;
  ulong shadowGeneration;
  ulong decisionTimestampMicroseconds;
  ulong randomCounterGeneration;
  ulong speciesTemplateFingerprint;
  ulong compiledSpeciesTemplateFingerprint;
  ulong parameterVersionFingerprint;
  ulong regionalProgramFingerprint;
  ulong scheduleFingerprint;
  ulong brainProgramFingerprint;
  ulong decisionOutputFingerprint;
  ulong descendingSomaticFingerprint;
  ulong autonomicCommandFingerprint;
  ulong activeSensingCommandFingerprint;
  ulong gateFingerprint;
};

struct NBNumanXMotorReadyGateGPU {
  uint abiVersion;
  uint structBytes;
  uint status;
  uint environment;
  uint substepIndex;
  uint attemptIndex;
  uint muscleCount;
  uint actuatorCommandKind;
  ulong controlStep;
  ulong transactionFingerprint;
  ulong substepFingerprint;
  ulong candidateFingerprint;
  ulong motorOutputFingerprint;
  ulong motorProfileFingerprint;
  ulong brainGeneration;
  ulong acceptedBrainTimestampMicroseconds;
  ulong randomCounterGeneration;
  ulong speciesTemplateFingerprint;
  ulong compiledSpeciesTemplateFingerprint;
  ulong brainProgramFingerprint;
  ulong fastProgramFingerprint;
  ulong decisionGateFingerprint;
  ulong reserved64_0;
  ulong gateFingerprint;
};

struct NBNumanXDecisionRangeGPU {
  uint byteOffset;
  uint byteCount;
};

struct NBNumanXDecisionReadyDispatchGPU {
  NBNumanXDecisionReadyGateGPU expected;
  ulong sourceByteCount;
  ulong reserved;
  NBNumanXDecisionRangeGPU ranges[NB_NUMANX_DECISION_MAX_RANGES];
};

struct NBNumanXUncertaintyPolicyGPU {
  uint abiVersion;
  uint flags;
  float supervisionRequestThreshold;
  float rootRejectionThreshold;
};

struct NBControlHeaderGPU {
  ulong activeGoalIdentifier;
  ulong activeOptionIdentifier;
  ulong activePlanIdentifier;
  ulong selectedTimestampMicroseconds;
  uint mode;
  uint candidateCount;
  uint planStepCount;
  uint flags;
  float selectedScore;
  float selectedDamageCVaR;
  float confidence;
  float vigor;
  float explorationTemperature;
  float controllerPhase;
  float interruptionCost;
  float progress;
  float predictedEffort;
  float predictedInformationGain;
  float unsupportedUncertainty;
  float reservedFloat;
  ulong reserved0;
  ulong reserved1;
  ulong reserved2;
  ulong reserved3;
};

struct NBNumanXCultureActionGPU {
  uint abiVersion;
  uint structBytes;
  uint status;
  uint electrodeCount;
  ulong cultureFingerprint;
  ulong cultureGeneration;
  ulong sourcePhysicsGeneration;
  ulong transactionFingerprint;
  ulong controlStep;
  ulong countsByteCount;
  ulong sourceRootFingerprint;
  ulong receiptFingerprint;
  float gain;
  uint reserved0;
  ulong actionFingerprint;
};

static_assert(sizeof(NBNumanXCultureActionGPU) == 96);

struct NBNumanXMotorCandidateGPU {
  uint formatVersion;
  uint flags;
  ulong transactionFingerprint;
  ulong substepFingerprint;
  ulong acceptedBrainTimestampMicroseconds;
  ulong brainGeneration;
  ulong motorProfileFingerprint;
  ulong motorOutputHeaderGPUAddress;
  ulong muscleExcitationGPUAddress;
  ulong randomCounterGeneration;
  uint motorOutputHeaderByteCount;
  uint muscleExcitationByteCount;
  uint muscleCount;
  uint environmentIdentifier;
  ulong autonomicCommandGPUAddress;
  uint autonomicCommandByteCount;
  uint autonomicCommandCount;
  ulong activeSensingCommandGPUAddress;
  uint activeSensingCommandByteCount;
  uint activeSensingCommandCount;
  uint actuatorCommandKind;
  uint reserved;
  ulong speciesTemplateFingerprint;
  ulong compiledSpeciesTemplateFingerprint;
  ulong candidateFingerprint;
};

struct NBMotorOutputHeaderGPU {
  uint formatVersion;
  uint flags;
  ulong timestampMicroseconds;
  ulong brainGeneration;
  ulong profileFingerprint;
  ulong protectiveCommandFingerprint;
  uint muscleCount;
  uint environmentIdentifier;
  float motorInhibition;
  float autonomicArousal;
  uint actuatorCommandKind;
  uint reserved;
  float outputMinimum;
  float outputMaximum;
  ulong outputFingerprint;
};

static_assert(sizeof(NBNumanXDecisionReadyGateGPU) == 160);
static_assert(sizeof(NBNumanXMotorReadyGateGPU) == 160);
static_assert(sizeof(NBNumanXDecisionReadyDispatchGPU) == 272);
static_assert(sizeof(NBNumanXUncertaintyPolicyGPU) == 16);
static_assert(sizeof(NBControlHeaderGPU) == 128);
static_assert(sizeof(NBNumanXMotorCandidateGPU) == 152);
static_assert(sizeof(NBMotorOutputHeaderGPU) == 80);

inline void nb_mix_byte(thread ulong &hash, uchar value) {
  hash = (hash ^ ulong(value)) * NB_FNV_PRIME;
}

inline void nb_mix_uint(thread ulong &hash, uint value) {
  for (uint index = 0u; index < 4u; ++index) {
    nb_mix_byte(hash, uchar((value >> (index * 8u)) & 0xffu));
  }
}

inline void nb_mix_ulong(thread ulong &hash, ulong value) {
  for (uint index = 0u; index < 8u; ++index) {
    nb_mix_byte(hash, uchar((value >> (index * 8u)) & 0xfful));
  }
}

inline void nb_mix_float(thread ulong &hash, float value) {
  nb_mix_uint(hash, as_type<uint>(value));
}

inline void nb_mix_bytes(
  thread ulong &hash,
  device const uchar *bytes,
  ulong byteCount
) {
  for (ulong index = 0ul; index < byteCount; ++index) {
    nb_mix_byte(hash, bytes[index]);
  }
}

template <typename T>
inline ulong nb_record_fingerprint(thread const T &record) {
  ulong hash = NB_FNV_OFFSET;
  thread const uchar *bytes = reinterpret_cast<thread const uchar *>(&record);
  for (uint index = 0u; index < 152u; ++index) {
    nb_mix_byte(hash, bytes[index]);
  }
  return hash == 0ul ? NB_FNV_OFFSET : hash;
}

inline ulong nb_range_fingerprint(
  uint domain,
  device const uchar *bytes,
  ulong byteCount
) {
  ulong hash = NB_FNV_OFFSET;
  nb_mix_uint(hash, domain);
  nb_mix_ulong(hash, byteCount);
  nb_mix_bytes(hash, bytes, byteCount);
  return hash == 0ul ? NB_FNV_OFFSET : hash;
}

inline void nb_publish_decision_gate(
  device NBNumanXDecisionReadyGateGPU *gate,
  thread NBNumanXDecisionReadyGateGPU &terminal
) {
  const uint terminalStatus = terminal.status;
  terminal.gateFingerprint = nb_record_fingerprint(terminal);
  terminal.status = NB_NUMANX_READY_PENDING;
  gate[0] = terminal;
  atomic_store_explicit(
    reinterpret_cast<device atomic_uint *>(&gate->status),
    terminalStatus,
    memory_order_relaxed
  );
}

inline void nb_publish_motor_gate(
  device NBNumanXMotorReadyGateGPU *gate,
  thread NBNumanXMotorReadyGateGPU &terminal
) {
  const uint terminalStatus = terminal.status;
  terminal.gateFingerprint = nb_record_fingerprint(terminal);
  terminal.status = NB_NUMANX_READY_PENDING;
  gate[0] = terminal;
  atomic_store_explicit(
    reinterpret_cast<device atomic_uint *>(&gate->status),
    terminalStatus,
    memory_order_relaxed
  );
}

inline ulong nb_candidate_fingerprint(
  thread const NBNumanXMotorCandidateGPU &candidate
) {
  ulong hash = NB_FNV_OFFSET;
  nb_mix_uint(hash, NB_NUMANX_MOTOR_CANDIDATE_VERSION);
  nb_mix_uint(hash, candidate.formatVersion);
  nb_mix_uint(hash, candidate.flags);
  nb_mix_ulong(hash, candidate.transactionFingerprint);
  nb_mix_ulong(hash, candidate.substepFingerprint);
  nb_mix_ulong(hash, candidate.acceptedBrainTimestampMicroseconds);
  nb_mix_ulong(hash, candidate.brainGeneration);
  nb_mix_ulong(hash, candidate.motorProfileFingerprint);
  nb_mix_ulong(hash, candidate.motorOutputHeaderGPUAddress);
  nb_mix_ulong(hash, candidate.muscleExcitationGPUAddress);
  nb_mix_ulong(hash, candidate.randomCounterGeneration);
  nb_mix_uint(hash, candidate.motorOutputHeaderByteCount);
  nb_mix_uint(hash, candidate.muscleExcitationByteCount);
  nb_mix_uint(hash, candidate.muscleCount);
  nb_mix_uint(hash, candidate.environmentIdentifier);
  nb_mix_ulong(hash, candidate.autonomicCommandGPUAddress);
  nb_mix_uint(hash, candidate.autonomicCommandByteCount);
  nb_mix_uint(hash, candidate.autonomicCommandCount);
  nb_mix_ulong(hash, candidate.activeSensingCommandGPUAddress);
  nb_mix_uint(hash, candidate.activeSensingCommandByteCount);
  nb_mix_uint(hash, candidate.activeSensingCommandCount);
  nb_mix_uint(hash, candidate.actuatorCommandKind);
  nb_mix_uint(hash, candidate.reserved);
  nb_mix_ulong(hash, candidate.speciesTemplateFingerprint);
  nb_mix_ulong(hash, candidate.compiledSpeciesTemplateFingerprint);
  return hash;
}

inline ulong nb_somatic_output_fingerprint(
  thread const NBMotorOutputHeaderGPU &header,
  device const float *commands,
  uint trustedMuscleCount
) {
  ulong hash = NB_FNV_OFFSET;
  nb_mix_uint(hash, NB_MOTOR_OUTPUT_VERSION);
  nb_mix_uint(hash, header.formatVersion);
  nb_mix_uint(hash, header.flags);
  nb_mix_ulong(hash, header.timestampMicroseconds);
  nb_mix_ulong(hash, header.brainGeneration);
  nb_mix_ulong(hash, header.profileFingerprint);
  nb_mix_ulong(hash, header.protectiveCommandFingerprint);
  nb_mix_uint(hash, header.muscleCount);
  nb_mix_uint(hash, header.environmentIdentifier);
  nb_mix_float(hash, header.motorInhibition);
  nb_mix_float(hash, header.autonomicArousal);
  nb_mix_uint(hash, header.actuatorCommandKind);
  nb_mix_uint(hash, header.reserved);
  nb_mix_float(hash, header.outputMinimum);
  nb_mix_float(hash, header.outputMaximum);
  for (uint index = 0u; index < trustedMuscleCount; ++index) {
    nb_mix_float(hash, commands[index]);
  }
  return hash;
}

struct NBDecisionSourceDigestGPU {
  ulong fingerprint;
  bool rangesValid;
};

inline NBDecisionSourceDigestGPU nb_decision_source_digest(
  constant const NBNumanXDecisionReadyDispatchGPU &dispatch,
  constant const NBNumanXUncertaintyPolicyGPU &policy,
  device const NBControlHeaderGPU *controlHeader,
  device const uchar *decisionBytes
) {
  NBDecisionSourceDigestGPU result{NB_FNV_OFFSET, true};
  nb_mix_uint(result.fingerprint, 0x44454331u);
  nb_mix_uint(result.fingerprint, dispatch.expected.rangeCount);
  nb_mix_uint(result.fingerprint, policy.abiVersion);
  nb_mix_uint(result.fingerprint, policy.flags);
  nb_mix_float(result.fingerprint, policy.supervisionRequestThreshold);
  nb_mix_float(result.fingerprint, policy.rootRejectionThreshold);
  nb_mix_float(result.fingerprint, controlHeader[0].unsupportedUncertainty);
  for (uint index = 0u; index < NB_NUMANX_DECISION_MAX_RANGES; ++index) {
    const NBNumanXDecisionRangeGPU range = dispatch.ranges[index];
    const ulong end = ulong(range.byteOffset) + ulong(range.byteCount);
    if (end < ulong(range.byteOffset) || end > dispatch.sourceByteCount) {
      result.rangesValid = false;
      continue;
    }
    nb_mix_uint(result.fingerprint, index);
    nb_mix_uint(result.fingerprint, range.byteOffset);
    nb_mix_uint(result.fingerprint, range.byteCount);
    nb_mix_bytes(result.fingerprint,
      decisionBytes + ulong(range.byteOffset), ulong(range.byteCount));
  }
  if (result.fingerprint == 0ul) result.fingerprint = NB_FNV_OFFSET;
  return result;
}

inline NBDecisionSourceDigestGPU nb_decision_source_digest_simd(
  constant const NBNumanXDecisionReadyDispatchGPU &dispatch,
  constant const NBNumanXUncertaintyPolicyGPU &policy,
  device const NBControlHeaderGPU *controlHeader,
  device const uchar *decisionBytes,
  uint lane
) {
  NBDecisionSourceDigestGPU result{NB_FNV_OFFSET, true};
  if (lane == 0u) {
    nb_mix_uint(result.fingerprint, 0x44454331u);
    nb_mix_uint(result.fingerprint, dispatch.expected.rangeCount);
    nb_mix_uint(result.fingerprint, policy.abiVersion);
    nb_mix_uint(result.fingerprint, policy.flags);
    nb_mix_float(result.fingerprint, policy.supervisionRequestThreshold);
    nb_mix_float(result.fingerprint, policy.rootRejectionThreshold);
    nb_mix_float(result.fingerprint, controlHeader[0].unsupportedUncertainty);
  }
  for (uint index = 0u; index < NB_NUMANX_DECISION_MAX_RANGES; ++index) {
    const NBNumanXDecisionRangeGPU range = dispatch.ranges[index];
    const ulong end = ulong(range.byteOffset) + ulong(range.byteCount);
    if (end < ulong(range.byteOffset) || end > dispatch.sourceByteCount) {
      result.rangesValid = false;
      continue;
    }
    if (lane == 0u) {
      nb_mix_uint(result.fingerprint, index);
      nb_mix_uint(result.fingerprint, range.byteOffset);
      nb_mix_uint(result.fingerprint, range.byteCount);
    }
    const device uchar *bytes = decisionBytes + ulong(range.byteOffset);
    for (ulong base = 0ul; base < ulong(range.byteCount); base += 32ul) {
      const ulong byteIndex = base + ulong(lane);
      const uchar loaded = byteIndex < ulong(range.byteCount)
        ? bytes[byteIndex] : uchar(0u);
      const uint limit = uint(min(ulong(range.byteCount) - base, 32ul));
      for (uint offset = 0u; offset < limit; ++offset) {
        const uchar value = simd_broadcast(loaded, offset);
        if (lane == 0u) nb_mix_byte(result.fingerprint, value);
      }
    }
  }
  if (result.fingerprint == 0ul) result.fingerprint = NB_FNV_OFFSET;
  return result;
}

inline uint nb_decision_source_chunk_count(
  constant const NBNumanXDecisionReadyDispatchGPU &dispatch
) {
  uint count = 0u;
  for (uint index = 0u; index < NB_NUMANX_DECISION_MAX_RANGES; ++index) {
    const uint length = dispatch.ranges[index].byteCount;
    const uint chunks = length / NB_DECISION_CHUNK_BYTES
      + uint(length % NB_DECISION_CHUNK_BYTES != 0u);
    if (chunks > NB_DECISION_CHUNK_LANES - count)
      return NB_DECISION_CHUNK_LANES + 1u;
    count += chunks;
  }
  return count;
}

// One lane owns one canonical range chunk. Its ordered FNV chain is bounded
// to 704 bytes; no source byte is omitted or sampled. The range metadata and
// chunk hashes are folded in source order below. The old serial digest remains
// available when a model exceeds the bounded GPU chunk capacity.
inline ulong nb_decision_source_chunk_fingerprint(
  constant const NBNumanXDecisionReadyDispatchGPU &dispatch,
  device const uchar *decisionBytes,
  uint ordinal
) {
  for (uint index = 0u; index < NB_NUMANX_DECISION_MAX_RANGES; ++index) {
    const NBNumanXDecisionRangeGPU range = dispatch.ranges[index];
    const uint chunks = range.byteCount / NB_DECISION_CHUNK_BYTES
      + uint(range.byteCount % NB_DECISION_CHUNK_BYTES != 0u);
    if (ordinal >= chunks) {
      ordinal -= chunks;
      continue;
    }
    const ulong end = ulong(range.byteOffset) + ulong(range.byteCount);
    if (end < ulong(range.byteOffset) || end > dispatch.sourceByteCount)
      return 0ul;
    const uint offset = ordinal * NB_DECISION_CHUNK_BYTES;
    const uint length = min(NB_DECISION_CHUNK_BYTES,
                            range.byteCount - offset);
    ulong fingerprint = NB_FNV_OFFSET;
    nb_mix_uint(fingerprint, 0x43484e32u);
    nb_mix_uint(fingerprint, index);
    nb_mix_uint(fingerprint, ordinal);
    nb_mix_uint(fingerprint, length);
    nb_mix_bytes(fingerprint,
      decisionBytes + ulong(range.byteOffset) + ulong(offset), ulong(length));
    return fingerprint == 0ul ? NB_FNV_OFFSET : fingerprint;
  }
  return 0ul;
}

inline NBDecisionSourceDigestGPU nb_decision_source_digest_chunks(
  constant const NBNumanXDecisionReadyDispatchGPU &dispatch,
  constant const NBNumanXUncertaintyPolicyGPU &policy,
  device const NBControlHeaderGPU *controlHeader,
  threadgroup const ulong *chunks
) {
  NBDecisionSourceDigestGPU result{NB_FNV_OFFSET, true};
  // A new domain prevents an older serial-digest gate from being accepted as
  // this tree-shaped source identity under the same fixed-size gate record.
  nb_mix_uint(result.fingerprint, 0x44454332u);
  nb_mix_uint(result.fingerprint, dispatch.expected.rangeCount);
  nb_mix_uint(result.fingerprint, policy.abiVersion);
  nb_mix_uint(result.fingerprint, policy.flags);
  nb_mix_float(result.fingerprint, policy.supervisionRequestThreshold);
  nb_mix_float(result.fingerprint, policy.rootRejectionThreshold);
  nb_mix_float(result.fingerprint, controlHeader[0].unsupportedUncertainty);
  uint ordinal = 0u;
  for (uint index = 0u; index < NB_NUMANX_DECISION_MAX_RANGES; ++index) {
    const NBNumanXDecisionRangeGPU range = dispatch.ranges[index];
    const ulong end = ulong(range.byteOffset) + ulong(range.byteCount);
    if (end < ulong(range.byteOffset) || end > dispatch.sourceByteCount)
      result.rangesValid = false;
    nb_mix_uint(result.fingerprint, index);
    nb_mix_uint(result.fingerprint, range.byteOffset);
    nb_mix_uint(result.fingerprint, range.byteCount);
    const uint count = range.byteCount / NB_DECISION_CHUNK_BYTES
      + uint(range.byteCount % NB_DECISION_CHUNK_BYTES != 0u);
    for (uint chunk = 0u; chunk < count; ++chunk) {
      const uint length = min(NB_DECISION_CHUNK_BYTES,
                              range.byteCount - chunk * NB_DECISION_CHUNK_BYTES);
      nb_mix_uint(result.fingerprint, length);
      nb_mix_ulong(result.fingerprint, chunks[ordinal++]);
    }
  }
  if (result.fingerprint == 0ul) result.fingerprint = NB_FNV_OFFSET;
  return result;
}

kernel void numanx_apply_accepted_culture_action(
  constant NBNumanXCultureActionGPU &action [[buffer(0)]],
  device const uint *electrodeCounts [[buffer(1)]],
  device NBMotorOutputHeaderGPU *motorHeader [[buffer(2)]],
  device float *muscleCommands [[buffer(3)]],
  uint gid [[thread_position_in_grid]])
{
  if (gid != 0u) return;
  ulong fingerprint = NB_FNV_OFFSET;
  constant const uchar *actionBytes =
    reinterpret_cast<constant const uchar *>(&action);
  for (uint index = 0u; index < 88u; ++index) {
    nb_mix_byte(fingerprint, actionBytes[index]);
  }
  if (fingerprint == 0ul) fingerprint = NB_FNV_OFFSET;
  NBMotorOutputHeaderGPU header = motorHeader[0];
  const bool valid = action.abiVersion == 1u
    && action.structBytes == 96u
    && action.status == 1u
    && action.electrodeCount == 60u
    && action.cultureFingerprint != 0ul
    && action.cultureGeneration != 0ul
    && action.sourcePhysicsGeneration != 0ul
    && action.transactionFingerprint != 0ul
    && action.controlStep != 0ul
    && action.countsByteCount == 240ul
    && action.sourceRootFingerprint != 0ul
    && action.receiptFingerprint != 0ul
    && isfinite(action.gain) && action.gain > 0.0f && action.gain <= 0.10f
    && action.reserved0 == 0u
    && action.actionFingerprint == fingerprint
    && header.formatVersion == NB_MOTOR_OUTPUT_VERSION
    && header.muscleCount != 0u;
  if (!valid) {
    motorHeader[0].outputFingerprint = 0ul;
    return;
  }
  ulong total = 0ul;
  float weightedX = 0.0f;
  float weightedY = 0.0f;
  uint electrode = 0u;
  for (uint row = 0u; row < 8u; ++row) {
    for (uint column = 0u; column < 8u; ++column) {
      const bool corner = (row == 0u || row == 7u)
        && (column == 0u || column == 7u);
      if (corner) continue;
      const uint count = electrodeCounts[electrode++];
      total += ulong(count);
      weightedX += float(count) * (float(column) - 3.5f);
      weightedY += float(count) * (float(row) - 3.5f);
    }
  }
  if (total != 0ul) {
    const float inverse = 1.0f / (float(total) * 3.5f);
    const float2 actionVector = clamp(
      float2(weightedX, weightedY) * inverse,
      float2(-1.0f),
      float2(1.0f)
    );
    const float span = header.outputMaximum - header.outputMinimum;
    for (uint index = 0u; index < header.muscleCount; ++index) {
      const uint phase = index & 3u;
      const float drive = phase == 0u ? actionVector.x
        : (phase == 1u ? -actionVector.x
          : (phase == 2u ? actionVector.y : -actionVector.y));
      muscleCommands[index] = clamp(
        muscleCommands[index] + action.gain * span * drive,
        header.outputMinimum,
        header.outputMaximum
      );
    }
  }
  motorHeader[0].outputFingerprint = nb_somatic_output_fingerprint(
    header, muscleCommands, header.muscleCount
  );
}

kernel void numanx_publish_decision_ready(
  constant NBNumanXDecisionReadyDispatchGPU &dispatch [[buffer(0)]],
  device const uchar *decisionBytes [[buffer(1)]],
  device NBNumanXDecisionReadyGateGPU *gate [[buffer(2)]],
  device const NBControlHeaderGPU *controlHeader [[buffer(3)]],
  constant NBNumanXUncertaintyPolicyGPU &uncertaintyPolicy [[buffer(4)]],
  uint lane [[thread_index_in_threadgroup]],
  uint3 lanesPerThreadgroup [[threads_per_threadgroup]])
{
  threadgroup ulong chunkFingerprints[NB_DECISION_CHUNK_LANES];
  const uint chunkCount = nb_decision_source_chunk_count(dispatch);
  const bool chunked = lanesPerThreadgroup.x >= NB_DECISION_CHUNK_LANES
    && chunkCount <= NB_DECISION_CHUNK_LANES;
  NBDecisionSourceDigestGPU sourceDigest{NB_FNV_OFFSET, false};
  if (chunked) {
    if (lane < chunkCount)
      chunkFingerprints[lane] = nb_decision_source_chunk_fingerprint(
        dispatch, decisionBytes, lane);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (lane == 0u)
      sourceDigest = nb_decision_source_digest_chunks(
        dispatch, uncertaintyPolicy, controlHeader, chunkFingerprints);
  } else if (lanesPerThreadgroup.x >= 32u) {
    if (lane < 32u)
      sourceDigest = nb_decision_source_digest_simd(
        dispatch, uncertaintyPolicy, controlHeader, decisionBytes, lane);
  } else if (lane == 0u) {
    sourceDigest = nb_decision_source_digest(
      dispatch, uncertaintyPolicy, controlHeader, decisionBytes);
  }
  if (lane != 0u) return;
  NBNumanXDecisionReadyGateGPU output = dispatch.expected;
  const NBControlHeaderGPU control = controlHeader[0];
  const bool uncertaintyPolicyDisabled = uncertaintyPolicy.flags == 0u
    && uncertaintyPolicy.supervisionRequestThreshold == 0.0f
    && uncertaintyPolicy.rootRejectionThreshold == 0.0f
    && output.flags == 0u;
  const bool uncertaintyPolicyEnabled =
    uncertaintyPolicy.flags == NB_NUMANX_DECISION_UNCERTAINTY_POLICY_BOUND
    && isfinite(uncertaintyPolicy.supervisionRequestThreshold)
    && isfinite(uncertaintyPolicy.rootRejectionThreshold)
    && uncertaintyPolicy.supervisionRequestThreshold >= 0.0f
    && uncertaintyPolicy.supervisionRequestThreshold <= 1.0f
    && uncertaintyPolicy.rootRejectionThreshold
      >= uncertaintyPolicy.supervisionRequestThreshold
    && uncertaintyPolicy.rootRejectionThreshold <= 1.0f
    && output.flags == NB_NUMANX_DECISION_UNCERTAINTY_POLICY_BOUND;
  bool valid = output.abiVersion == NB_NUMANX_READY_ABI_VERSION
    && output.structBytes == NB_NUMANX_DECISION_GATE_BYTES
    && output.status == NB_NUMANX_READY_PENDING
    && output.rangeCount == NB_NUMANX_DECISION_MAX_RANGES
    && (uncertaintyPolicyDisabled || uncertaintyPolicyEnabled)
    && uncertaintyPolicy.abiVersion
      == NB_NUMANX_UNCERTAINTY_POLICY_ABI_VERSION
    && output.unsupportedUncertaintyBits == 0u
    && output.reserved32_1 == 0u
    && output.transactionFingerprint != 0ul
    && output.shadowGeneration != 0ul
    && output.speciesTemplateFingerprint != 0ul
    && output.compiledSpeciesTemplateFingerprint != 0ul
    && output.parameterVersionFingerprint != 0ul
    && output.regionalProgramFingerprint != 0ul
    && output.scheduleFingerprint != 0ul
    && output.brainProgramFingerprint != 0ul
    && output.decisionOutputFingerprint == 0ul
    && output.descendingSomaticFingerprint == 0ul
    && output.autonomicCommandFingerprint == 0ul
    && output.activeSensingCommandFingerprint == 0ul
    && dispatch.reserved == 0ul
    && sourceDigest.rangesValid
    && output.gateFingerprint == nb_record_fingerprint(output);
  const ulong aggregate = sourceDigest.fingerprint;
  const bool uncertaintyValid = isfinite(control.unsupportedUncertainty)
    && control.unsupportedUncertainty >= 0.0f;
  const float normalizedUncertainty = uncertaintyValid
    ? clamp(control.unsupportedUncertainty, 0.0f, 1.0f) : 1.0f;
  const bool supervisionRequired = uncertaintyPolicyEnabled
    && normalizedUncertainty
      >= uncertaintyPolicy.supervisionRequestThreshold;
  const bool rootRejected = uncertaintyPolicyEnabled
    && normalizedUncertainty >= uncertaintyPolicy.rootRejectionThreshold;
  output.unsupportedUncertaintyBits = uncertaintyPolicyEnabled
    ? as_type<uint>(normalizedUncertainty) : 0u;
  if (valid && uncertaintyValid && !supervisionRequired) {
    const NBNumanXDecisionRangeGPU descending = dispatch.ranges[0];
    const NBNumanXDecisionRangeGPU autonomic = dispatch.ranges[8];
    const NBNumanXDecisionRangeGPU activeSensing = dispatch.ranges[10];
    output.decisionOutputFingerprint = aggregate == 0ul
      ? NB_FNV_OFFSET : aggregate;
    output.descendingSomaticFingerprint = nb_range_fingerprint(
      0x534f4d31u,
      decisionBytes + ulong(descending.byteOffset),
      ulong(descending.byteCount)
    );
    output.autonomicCommandFingerprint = nb_range_fingerprint(
      0x41555431u,
      decisionBytes + ulong(autonomic.byteOffset),
      ulong(autonomic.byteCount)
    );
    output.activeSensingCommandFingerprint = nb_range_fingerprint(
      0x41435431u,
      decisionBytes + ulong(activeSensing.byteOffset),
      ulong(activeSensing.byteCount)
    );
    output.status = NB_NUMANX_READY_SUCCESS;
  } else {
    if (uncertaintyPolicyEnabled && (!uncertaintyValid || supervisionRequired)) {
      output.flags |= NB_NUMANX_DECISION_SUPERVISION_REQUIRED;
    }
    if (uncertaintyPolicyEnabled && (!uncertaintyValid || rootRejected)) {
      output.flags |= NB_NUMANX_DECISION_ROOT_REJECTED;
    }
    output.decisionOutputFingerprint = 0ul;
    output.descendingSomaticFingerprint = 0ul;
    output.autonomicCommandFingerprint = 0ul;
    output.activeSensingCommandFingerprint = 0ul;
    output.status = NB_NUMANX_READY_FAILURE;
  }
  nb_publish_decision_gate(gate, output);
}

// Preserve the ordered motor ABI digest while letting its independent byte
// stream run concurrently with the decision and descending-command digests.
inline ulong nb_motor_output_aggregate(
  constant const NBNumanXMotorCandidateGPU &candidate,
  device const NBMotorOutputHeaderGPU *motorHeader,
  device const float *muscleCommands,
  device const uchar *autonomicCommands,
  device const uchar *activeSensingCommands
) {
  ulong aggregate = NB_FNV_OFFSET;
  nb_mix_uint(aggregate, 0x4d4f5431u);
  nb_mix_ulong(aggregate, ulong(sizeof(NBMotorOutputHeaderGPU)));
  nb_mix_bytes(
    aggregate,
    reinterpret_cast<device const uchar *>(motorHeader),
    ulong(sizeof(NBMotorOutputHeaderGPU))
  );
  nb_mix_ulong(aggregate, ulong(candidate.muscleExcitationByteCount));
  nb_mix_bytes(
    aggregate,
    reinterpret_cast<device const uchar *>(muscleCommands),
    ulong(candidate.muscleExcitationByteCount)
  );
  nb_mix_ulong(aggregate, ulong(candidate.autonomicCommandByteCount));
  nb_mix_bytes(
    aggregate, autonomicCommands, ulong(candidate.autonomicCommandByteCount)
  );
  nb_mix_ulong(aggregate, ulong(candidate.activeSensingCommandByteCount));
  nb_mix_bytes(
    aggregate,
    activeSensingCommands,
    ulong(candidate.activeSensingCommandByteCount)
  );
  return aggregate == 0ul ? NB_FNV_OFFSET : aggregate;
}

kernel void numanx_publish_motor_ready(
  constant NBNumanXMotorReadyGateGPU &expected [[buffer(0)]],
  constant NBNumanXMotorCandidateGPU &candidate [[buffer(1)]],
  constant NBNumanXDecisionReadyDispatchGPU &decisionExpected [[buffer(2)]],
  device const NBNumanXDecisionReadyGateGPU *decisionGate [[buffer(3)]],
  device const uchar *decisionBytes [[buffer(4)]],
  device const NBMotorOutputHeaderGPU *motorHeader [[buffer(5)]],
  device const float *muscleCommands [[buffer(6)]],
  device const uchar *descendingSomatic [[buffer(7)]],
  device const uchar *descendingAutonomic [[buffer(8)]],
  device const uchar *autonomicCommands [[buffer(9)]],
  device const uchar *activeSensingCommands [[buffer(10)]],
  device NBNumanXMotorReadyGateGPU *gate [[buffer(11)]],
  device const NBControlHeaderGPU *controlHeader [[buffer(12)]],
  constant NBNumanXUncertaintyPolicyGPU &uncertaintyPolicy [[buffer(13)]],
  uint tid [[thread_index_in_threadgroup]],
  uint3 lanesPerThreadgroup [[threads_per_threadgroup]])
{
  // Each long FNV chain retains its byte order. Independent chains run on
  // separate SIMD groups so device loads and integer multiplies can overlap.
  threadgroup ulong partialFingerprint[6];
  threadgroup uint partialValid[2];
  threadgroup ulong decisionChunks[NB_DECISION_CHUNK_LANES];
  // The candidate identity and byte counts are checked before any lane reads
  // the aggregate's ranges. All remaining gate predicates stay below.
  threadgroup uint candidateValidForAggregate;
  if (tid == 0u) {
    const NBNumanXMotorCandidateGPU candidateValue = candidate;
    const ulong candidateFingerprint = nb_candidate_fingerprint(candidateValue);
    const bool candidateValid =
      candidate.formatVersion == NB_NUMANX_MOTOR_CANDIDATE_VERSION
      && candidate.flags == (NB_NUMANX_MOTOR_CANDIDATE_VALID
        | NB_NUMANX_MOTOR_CANDIDATE_DECISION_SHADOW)
      && candidate.transactionFingerprint == expected.transactionFingerprint
      && candidate.substepFingerprint == expected.substepFingerprint
      && candidate.acceptedBrainTimestampMicroseconds
        == expected.acceptedBrainTimestampMicroseconds
      && candidate.brainGeneration == expected.brainGeneration
      && candidate.motorProfileFingerprint == expected.motorProfileFingerprint
      && candidate.randomCounterGeneration == expected.randomCounterGeneration
      && candidate.muscleCount == expected.muscleCount
      && candidate.environmentIdentifier == expected.environment
      && candidate.actuatorCommandKind == expected.actuatorCommandKind
      && candidate.speciesTemplateFingerprint == expected.speciesTemplateFingerprint
      && candidate.compiledSpeciesTemplateFingerprint
        == expected.compiledSpeciesTemplateFingerprint
      && candidate.motorOutputHeaderByteCount == sizeof(NBMotorOutputHeaderGPU)
      && candidate.muscleCount != 0u
      && ulong(candidate.muscleExcitationByteCount)
        == ulong(candidate.muscleCount) * 4ul
      && candidate.autonomicCommandCount != 0u
      && ulong(candidate.autonomicCommandByteCount)
        == ulong(candidate.autonomicCommandCount) * 16ul
      && ulong(candidate.activeSensingCommandByteCount)
        == ulong(candidate.activeSensingCommandCount) * 16ul
      && candidate.reserved == 0u
      && candidate.candidateFingerprint != 0ul
      && candidate.candidateFingerprint == candidateFingerprint
      && candidate.candidateFingerprint == expected.candidateFingerprint;
    candidateValidForAggregate = candidateValid ? 1u : 0u;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  const bool chunkedDecision =
    lanesPerThreadgroup.x >= 416u &&
    nb_decision_source_chunk_count(decisionExpected)
      <= NB_DECISION_CHUNK_LANES;
  if (lanesPerThreadgroup.x >= 192u) {
    if (tid == 0u) {
      const NBMotorOutputHeaderGPU header = motorHeader[0];
      partialFingerprint[0] = nb_somatic_output_fingerprint(
        header, muscleCommands, expected.muscleCount
      );
    } else if (tid == 32u) {
      partialFingerprint[1] = nb_range_fingerprint(
        0x534f4d31u, descendingSomatic,
        ulong(candidate.muscleExcitationByteCount)
      );
    } else if (tid == 64u) {
      partialFingerprint[2] = nb_range_fingerprint(
        0x41555431u, descendingAutonomic,
        ulong(candidate.autonomicCommandByteCount)
      );
    } else if (tid == 96u) {
      partialFingerprint[3] = nb_range_fingerprint(
        0x41435431u, activeSensingCommands,
        ulong(candidate.activeSensingCommandByteCount)
      );
    } else if (chunkedDecision && tid >= 128u && tid < 384u) {
      const uint ordinal = tid - 128u;
      if (ordinal < nb_decision_source_chunk_count(decisionExpected))
        decisionChunks[ordinal] = nb_decision_source_chunk_fingerprint(
          decisionExpected, decisionBytes, ordinal);
    } else if (!chunkedDecision && tid >= 128u && tid < 160u) {
      const NBDecisionSourceDigestGPU digest = nb_decision_source_digest_simd(
        decisionExpected, uncertaintyPolicy, controlHeader, decisionBytes,
        tid - 128u
      );
      if (tid == 128u) {
        partialFingerprint[4] = digest.fingerprint;
        partialValid[0] = digest.rangesValid ? 1u : 0u;
      }
    } else if (tid == (chunkedDecision ? 385u : 161u)) {
      partialFingerprint[5] = candidateValidForAggregate != 0u
        ? nb_motor_output_aggregate(candidate, motorHeader, muscleCommands,
            autonomicCommands, activeSensingCommands)
        : 0ul;
    } else if (tid == (chunkedDecision ? 384u : 160u)) {
      bool commandsValid = true;
      const NBMotorOutputHeaderGPU header = motorHeader[0];
      for (uint index = 0u; index < expected.muscleCount; ++index) {
        const float command = muscleCommands[index];
        commandsValid = commandsValid && isfinite(command)
          && command >= header.outputMinimum
          && command <= header.outputMaximum;
      }
      partialValid[1] = commandsValid ? 1u : 0u;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (chunkedDecision) {
      if (tid == 128u) {
        const NBDecisionSourceDigestGPU digest =
          nb_decision_source_digest_chunks(decisionExpected,
            uncertaintyPolicy, controlHeader, decisionChunks);
        partialFingerprint[4] = digest.fingerprint;
        partialValid[0] = digest.rangesValid ? 1u : 0u;
      }
      threadgroup_barrier(mem_flags::mem_threadgroup);
    }
  } else if (tid == 0u) {
    const NBMotorOutputHeaderGPU header = motorHeader[0];
    partialFingerprint[0] = nb_somatic_output_fingerprint(
      header, muscleCommands, expected.muscleCount
    );
    partialFingerprint[1] = nb_range_fingerprint(
      0x534f4d31u, descendingSomatic,
      ulong(candidate.muscleExcitationByteCount)
    );
    partialFingerprint[2] = nb_range_fingerprint(
      0x41555431u, descendingAutonomic,
      ulong(candidate.autonomicCommandByteCount)
    );
    partialFingerprint[3] = nb_range_fingerprint(
      0x41435431u, activeSensingCommands,
      ulong(candidate.activeSensingCommandByteCount)
    );
    const NBDecisionSourceDigestGPU digest = nb_decision_source_digest(
      decisionExpected, uncertaintyPolicy, controlHeader, decisionBytes
    );
    partialFingerprint[4] = digest.fingerprint;
    partialValid[0] = digest.rangesValid ? 1u : 0u;
    bool commandsValid = true;
    for (uint index = 0u; index < expected.muscleCount; ++index) {
      const float command = muscleCommands[index];
      commandsValid = commandsValid && isfinite(command)
        && command >= header.outputMinimum
        && command <= header.outputMaximum;
    }
    partialValid[1] = commandsValid ? 1u : 0u;
    partialFingerprint[5] = candidateValidForAggregate != 0u
      ? nb_motor_output_aggregate(candidate, motorHeader, muscleCommands,
          autonomicCommands, activeSensingCommands)
      : 0ul;
  }
  if (tid != 0u) return;
  NBNumanXMotorReadyGateGPU output = expected;
  const NBNumanXDecisionReadyGateGPU decisionPending =
    decisionExpected.expected;
  const NBNumanXDecisionReadyGateGPU decision = decisionGate[0];
  const NBMotorOutputHeaderGPU header = motorHeader[0];
  const ulong somaticFingerprint = partialFingerprint[0];
  const ulong descendingFingerprint = partialFingerprint[1];
  const ulong autonomicFingerprint = partialFingerprint[2];
  const ulong activeSensingFingerprint = partialFingerprint[3];
  const bool commandsValid = partialValid[1] != 0u;
  const bool decisionExpectedValid =
    decisionPending.abiVersion == NB_NUMANX_READY_ABI_VERSION
    && decisionPending.structBytes == NB_NUMANX_DECISION_GATE_BYTES
    && decisionPending.status == NB_NUMANX_READY_PENDING
    && decisionPending.rangeCount == NB_NUMANX_DECISION_MAX_RANGES
    && (decisionPending.flags == 0u
      || decisionPending.flags
        == NB_NUMANX_DECISION_UNCERTAINTY_POLICY_BOUND)
    && decisionPending.unsupportedUncertaintyBits == 0u
    && decisionPending.reserved32_1 == 0u
    && decisionExpected.reserved == 0ul
    && decisionPending.decisionOutputFingerprint == 0ul
    && decisionPending.descendingSomaticFingerprint == 0ul
    && decisionPending.autonomicCommandFingerprint == 0ul
    && decisionPending.activeSensingCommandFingerprint == 0ul
    && decisionPending.gateFingerprint == nb_record_fingerprint(decisionPending);
  const bool decisionSourceValid =
    decisionExpectedValid && partialValid[0] != 0u;
  const ulong decisionOutputFingerprint = partialFingerprint[4];
  const bool uncertaintyPolicyEnabled =
    decisionPending.flags == NB_NUMANX_DECISION_UNCERTAINTY_POLICY_BOUND
    && uncertaintyPolicy.abiVersion
      == NB_NUMANX_UNCERTAINTY_POLICY_ABI_VERSION
    && uncertaintyPolicy.flags == NB_NUMANX_DECISION_UNCERTAINTY_POLICY_BOUND;
  const bool decisionValid = decisionSourceValid
    && decision.abiVersion == NB_NUMANX_READY_ABI_VERSION
    && decision.structBytes == NB_NUMANX_DECISION_GATE_BYTES
    && decision.status == NB_NUMANX_READY_SUCCESS
    && decision.environment == decisionPending.environment
    && decision.rangeCount == decisionPending.rangeCount
    && decision.flags == decisionPending.flags
    && decision.unsupportedUncertaintyBits
      == (uncertaintyPolicyEnabled
        ? as_type<uint>(clamp(controlHeader[0].unsupportedUncertainty, 0.0f, 1.0f))
        : 0u)
    && decision.reserved32_1 == decisionPending.reserved32_1
    && decision.controlStep == decisionPending.controlStep
    && decision.transactionFingerprint
      == decisionPending.transactionFingerprint
    && decision.shadowGeneration == decisionPending.shadowGeneration
    && decision.decisionTimestampMicroseconds
      == decisionPending.decisionTimestampMicroseconds
    && decision.randomCounterGeneration
      == decisionPending.randomCounterGeneration
    && decision.speciesTemplateFingerprint
      == decisionPending.speciesTemplateFingerprint
    && decision.compiledSpeciesTemplateFingerprint
      == decisionPending.compiledSpeciesTemplateFingerprint
    && decision.parameterVersionFingerprint
      == decisionPending.parameterVersionFingerprint
    && decision.regionalProgramFingerprint
      == decisionPending.regionalProgramFingerprint
    && decision.scheduleFingerprint == decisionPending.scheduleFingerprint
    && decision.brainProgramFingerprint
      == decisionPending.brainProgramFingerprint
    && decision.environment == expected.environment
    && decision.controlStep == expected.controlStep
    && decision.transactionFingerprint == expected.transactionFingerprint
    && decision.shadowGeneration == expected.brainGeneration
    && decision.decisionTimestampMicroseconds
      == expected.acceptedBrainTimestampMicroseconds
    && decision.randomCounterGeneration == expected.randomCounterGeneration
    && decision.speciesTemplateFingerprint == expected.speciesTemplateFingerprint
    && decision.compiledSpeciesTemplateFingerprint
      == expected.compiledSpeciesTemplateFingerprint
    && decision.brainProgramFingerprint == expected.brainProgramFingerprint
    && decision.decisionOutputFingerprint == decisionOutputFingerprint
    && decision.descendingSomaticFingerprint == descendingFingerprint
    && decision.autonomicCommandFingerprint == autonomicFingerprint
    && decision.activeSensingCommandFingerprint == activeSensingFingerprint
    && decision.gateFingerprint == nb_record_fingerprint(decision);
  const bool candidateValid = candidateValidForAggregate != 0u;
  const bool headerValid =
    header.formatVersion == NB_MOTOR_OUTPUT_VERSION
    && (header.flags & NB_MOTOR_OUTPUT_VALID) != 0u
    && (header.flags & ~NB_MOTOR_OUTPUT_KNOWN_FLAGS) == 0u
    && header.timestampMicroseconds == expected.acceptedBrainTimestampMicroseconds
    && header.brainGeneration == expected.brainGeneration
    && header.profileFingerprint == expected.motorProfileFingerprint
    && header.protectiveCommandFingerprint != 0ul
    && header.muscleCount != 0u
    && header.muscleCount == expected.muscleCount
    && header.environmentIdentifier == expected.environment
    && isfinite(header.motorInhibition)
    && isfinite(header.autonomicArousal)
    && isfinite(header.outputMinimum)
    && isfinite(header.outputMaximum)
    && header.motorInhibition >= 0.0f
    && header.motorInhibition <= 1.0f
    && header.autonomicArousal >= 0.0f
    && header.autonomicArousal <= 1.0f
    && header.outputMinimum < header.outputMaximum
    && header.actuatorCommandKind >= 1u
    && header.actuatorCommandKind <= 7u
    && header.actuatorCommandKind == expected.actuatorCommandKind
    && header.reserved == 0u
    && ((header.flags & NB_MOTOR_OUTPUT_EMERGENCY_STOP) != 0u)
      == (header.motorInhibition == 1.0f)
    && header.outputFingerprint != 0ul
    && header.outputFingerprint == somaticFingerprint
    && commandsValid;
  const bool expectedValid =
    expected.abiVersion == NB_NUMANX_READY_ABI_VERSION
    && expected.structBytes == NB_NUMANX_MOTOR_GATE_BYTES
    && expected.status == NB_NUMANX_READY_PENDING
    && expected.transactionFingerprint != 0ul
    && expected.substepFingerprint != 0ul
    && expected.candidateFingerprint != 0ul
    && expected.motorOutputFingerprint == 0ul
    && expected.brainProgramFingerprint != 0ul
    && expected.fastProgramFingerprint != 0ul
    && expected.decisionGateFingerprint == 0ul
    && expected.reserved64_0 == 0ul
    && expected.gateFingerprint == nb_record_fingerprint(output);
  if (expectedValid && decisionValid && candidateValid && headerValid) {
    output.motorOutputFingerprint = partialFingerprint[5];
    output.decisionGateFingerprint = decision.gateFingerprint;
    output.status = NB_NUMANX_READY_SUCCESS;
  } else {
    output.motorOutputFingerprint = 0ul;
    output.decisionGateFingerprint = 0ul;
    output.status = NB_NUMANX_READY_FAILURE;
  }
  nb_publish_motor_gate(gate, output);
}

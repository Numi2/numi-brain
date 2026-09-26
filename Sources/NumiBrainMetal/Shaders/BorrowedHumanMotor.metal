// Compiled after the unmodified NumanXMotorReady.metal definitions and hash
// helpers. This transport is restricted to the native 416-muscle float4 ABI.
kernel void borrowed_human_motor_excitation(
    device const float *excitation [[buffer(0)]],
    device const NBMotorOutputHeaderGPU *headerBuffer [[buffer(1)]],
    device const NBNumanXMotorReadyGateGPU *gateBuffer [[buffer(2)]],
    constant NBNumanXMotorReadyGateGPU &expected [[buffer(3)]],
    constant NBNumanXMotorCandidateGPU &candidate [[buffer(4)]],
    device float4 *muscleStates [[buffer(5)]],
    constant uint4 &shape [[buffer(6)]],
    device const uint *standStatus [[buffer(7)]],
    device const uchar *autonomicCommands [[buffer(8)]],
    device const uchar *activeSensingCommands [[buffer(9)]],
    uint tid [[thread_index_in_threadgroup]]) {
  if (shape.y != 0u && standStatus[0] != 0u) return;
  const uint count = shape.x;
  threadgroup uint proofValid;
  threadgroup ulong aggregate;
  if (tid == 0u) {
    const NBNumanXMotorReadyGateGPU expectedValue = expected;
    const NBNumanXMotorReadyGateGPU gate = gateBuffer[0];
    const NBMotorOutputHeaderGPU header = headerBuffer[0];
    const NBNumanXMotorCandidateGPU candidateValue = candidate;
    NBNumanXMotorReadyGateGPU normalized = gate;
    normalized.status = NB_NUMANX_READY_PENDING;
    normalized.motorOutputFingerprint = 0ul;
    normalized.decisionGateFingerprint = 0ul;
    bool valid = count == 416u && expected.muscleCount == count
      && expected.abiVersion == NB_NUMANX_READY_ABI_VERSION
      && expected.structBytes == NB_NUMANX_MOTOR_GATE_BYTES
      && expected.status == NB_NUMANX_READY_PENDING
      && expected.actuatorCommandKind == 1u
      && expected.motorOutputFingerprint == 0ul
      && expected.decisionGateFingerprint == 0ul
      && expected.reserved64_0 == 0ul
      && expected.gateFingerprint == nb_record_fingerprint(expectedValue)
      && gate.status == NB_NUMANX_READY_SUCCESS
      && gate.gateFingerprint == nb_record_fingerprint(gate)
      && expected.gateFingerprint == nb_record_fingerprint(normalized)
      && gate.motorOutputFingerprint != 0ul && gate.decisionGateFingerprint != 0ul
      && candidate.formatVersion == NB_NUMANX_MOTOR_CANDIDATE_VERSION
      && candidate.flags == (NB_NUMANX_MOTOR_CANDIDATE_VALID | NB_NUMANX_MOTOR_CANDIDATE_DECISION_SHADOW)
      && candidate.muscleCount == count && candidate.actuatorCommandKind == 1u
      && candidate.motorOutputHeaderByteCount == sizeof(NBMotorOutputHeaderGPU)
      && candidate.muscleExcitationByteCount == count * sizeof(float)
      && candidate.autonomicCommandByteCount == shape.z
      && candidate.activeSensingCommandByteCount == shape.w
      && candidate.candidateFingerprint == gate.candidateFingerprint
      && candidate.candidateFingerprint == nb_candidate_fingerprint(candidateValue)
      && header.formatVersion == NB_MOTOR_OUTPUT_VERSION
      && (header.flags & NB_MOTOR_OUTPUT_VALID) != 0u
      && (header.flags & ~NB_MOTOR_OUTPUT_KNOWN_FLAGS) == 0u
      && header.muscleCount == count && header.actuatorCommandKind == 1u
      && header.timestampMicroseconds == expected.acceptedBrainTimestampMicroseconds
      && header.brainGeneration == expected.brainGeneration
      && header.profileFingerprint == expected.motorProfileFingerprint
      && header.environmentIdentifier == expected.environment
      && header.outputFingerprint == nb_somatic_output_fingerprint(header, excitation, count);
    for (uint muscle = 0u; muscle < count; ++muscle) {
      valid = valid && isfinite(excitation[muscle])
        && excitation[muscle] >= 0.0f && excitation[muscle] <= 1.0f;
    }
    proofValid = valid ? 1u : 0u;
  }
  // This byte stream is independent of the somatic output fingerprint. Keep
  // its original byte order while running it in a second SIMD group.
  if (tid == 32u) {
    ulong hash = NB_FNV_OFFSET;
    nb_mix_uint(hash, 0x4d4f5431u);
    nb_mix_ulong(hash, ulong(sizeof(NBMotorOutputHeaderGPU)));
    nb_mix_bytes(hash, reinterpret_cast<device const uchar *>(headerBuffer), sizeof(NBMotorOutputHeaderGPU));
    nb_mix_ulong(hash, ulong(count * sizeof(float)));
    nb_mix_bytes(hash, reinterpret_cast<device const uchar *>(excitation), count * sizeof(float));
    nb_mix_ulong(hash, ulong(shape.z));
    nb_mix_bytes(hash, autonomicCommands, shape.z);
    nb_mix_ulong(hash, ulong(shape.w));
    nb_mix_bytes(hash, activeSensingCommands, shape.w);
    aggregate = hash == 0ul ? NB_FNV_OFFSET : hash;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  if (tid == 0u) {
    proofValid = (proofValid != 0u
      && gateBuffer[0].motorOutputFingerprint == aggregate) ? 1u : 0u;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  for (uint muscle = tid; muscle < count; muscle += 64u) {
    // Activation, fibre length, and fibre velocity remain native state.
    // Invalid neural output must enter native rejection, never hidden zeroing.
    muscleStates[muscle].x = proofValid != 0u ? excitation[muscle] : NAN;
  }
}

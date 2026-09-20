import NumiBrainABI
import XCTest

@testable import NumiBrainCore

final class ExactOutboundV2ContractTests: XCTestCase {
  private let rootGolden: UInt64 = 0x9862_5287_1c86_7014
  private let substepGolden: UInt64 = 0x3397_6074_2e9d_5b13
  private let candidateGolden: UInt64 = 0xd545_ffb8_4702_f6cc
  private let outputGolden: UInt64 = 0xd299_7dd6_7ccf_83f4
  private let readyGateGolden: UInt64 = 0x7a7c_4daa_7709_eef0
  private let authorityGolden: UInt64 = 0x67f2_43f6_67d0_323d
  private let physicsStateGolden: UInt64 = 0x18c6_c3b2_7fbf_de9b
  private let proofGolden: UInt64 = 0xb931_1ace_7f60_9680
  private let tokenGolden: UInt64 = 0x49da_ecb7_8237_5620
  private let timingGolden: UInt64 = 0x5cf5_d8e7_31b2_34a0
  private let channelGolden: UInt64 = 0x29c4_e62c_fb23_78e8
  private let channelSetGolden: UInt64 = 0xc5e8_1577_5b80_108f
  private let packetGolden: UInt64 = 0xa2a4_0136_1deb_9f57
  private let publicationGolden: UInt64 = 0x7bad_b8d7_c8ee_a93e

  private struct Fixture {
    var root: NBJointTransactionTokenV2
    var substep: NBJointSubstepTokenV2
    var candidate: NBNumanXMotorCandidateV2
    var output: NBMotorOutputHeaderV2
    var readyGate: NBNumanXMotorReadyGateGPUV2
    var authority: NBNumanXExactInboundAuthorityV2
    var proof: NBNumanXAcceptedStateProofV2
    var token: NBNumanXExactAcceptedPhysicsTokenV2
    var timing: NBNumanXExactSensorTimingV2
    var channels: [NBNumanXExactSensorChannelV2]
    var packet: NBNumanXExactSensorPacketV2
    var publication: NBNumanXExactPublicationV2
    let excitations: [Float]
  }

  private func makeRange(
    pointer: UInt,
    gpuAddress: UInt64,
    byteOffset: UInt64 = 0,
    byteCount: UInt64,
    elementType: UInt32
  ) -> NBNumanXExactMetalRangeV1 {
    var range = NBNumanXExactMetalRangeV1()
    range.abi_version = UInt32(NB_NUMANX_EXACT_METAL_RANGE_ABI_V1)
    range.struct_size = UInt32(MemoryLayout<NBNumanXExactMetalRangeV1>.stride)
    range.metal_buffer = UnsafeMutableRawPointer(bitPattern: pointer)!
    range.gpu_address = gpuAddress
    range.byte_offset = byteOffset
    range.byte_count = byteCount
    range.element_type = elementType
    range.element_byte_count = 4
    return range
  }

  private func makeFixture() throws -> Fixture {
    let rootValue = try BrainJointTransactionTokenV2.exactNanoseconds(
      environmentIdentifier: 7,
      episodeIdentifier: 23,
      controlStepIdentifier: 17,
      parameterVersionFingerprint: 0x1234_5678_9abc_def0,
      baseBrainGeneration: 9,
      basePhysicsGeneration: 100,
      committedTimestampNanoseconds: 12_500,
      targetTimestampNanoseconds: 25_000,
      randomCounterGeneration: 55
    )
    let substepValue = try BrainJointSubstepTokenV2.exactNanoseconds(
      transaction: rootValue,
      substepIndex: 0,
      attemptIndex: 0,
      startTimestampNanoseconds: 12_500,
      durationNanoseconds: 12_500
    )
    let root = rootValue.abiRecord
    let substep = substepValue.abiRecord

    var candidate = NBNumanXMotorCandidateV2()
    candidate.format_version = UInt32(NB_NUMANX_MOTOR_CANDIDATE_V2_VERSION)
    candidate.flags = UInt32(NB_NUMANX_MOTOR_CANDIDATE_FLAG_VALID)
      | UInt32(NB_NUMANX_MOTOR_CANDIDATE_FLAG_DECISION_SHADOW)
    candidate.transaction_fingerprint = rootValue.fingerprint
    candidate.substep_fingerprint = substepValue.fingerprint
    candidate.accepted_brain_timestamp_nanoseconds = 12_500
    candidate.brain_generation = 10
    candidate.motor_profile_fingerprint = 0x4444
    candidate.motor_output_header_gpu_address = 0x1000
    candidate.muscle_excitation_gpu_address = 0x2000
    candidate.random_counter_generation = 55
    candidate.motor_output_header_byte_count = 80
    candidate.muscle_excitation_byte_count = 12
    candidate.muscle_count = 3
    candidate.environment_identifier = 7
    candidate.autonomic_command_gpu_address = 0x3000
    candidate.autonomic_command_byte_count = 16
    candidate.autonomic_command_count = 1
    candidate.active_sensing_command_gpu_address = 0x4000
    candidate.active_sensing_command_byte_count = 16
    candidate.active_sensing_command_count = 1
    candidate.actuator_command_kind = 1
    candidate.clock_domain = UInt32(NB_PHYSICAL_CLOCK_DOMAIN_EXACT_NANOSECONDS)
    candidate.species_template_fingerprint = 0x5555
    candidate.compiled_species_template_fingerprint = 0x6666
    candidate.candidate_fingerprint = withUnsafePointer(to: &candidate) {
      nb_brain_abi_numanx_motor_candidate_v2_fingerprint($0)
    }

    let excitations: [Float] = [0.25, 0.5, 0.75]
    var output = NBMotorOutputHeaderV2()
    output.format_version = UInt32(NB_MOTOR_OUTPUT_V2_VERSION)
    output.flags = UInt32(NB_MOTOR_OUTPUT_FLAG_VALID)
    output.timestamp_nanoseconds = candidate.accepted_brain_timestamp_nanoseconds
    output.brain_generation = candidate.brain_generation
    output.profile_fingerprint = candidate.motor_profile_fingerprint
    output.protective_command_fingerprint = 0x7777
    output.muscle_count = candidate.muscle_count
    output.environment_identifier = candidate.environment_identifier
    output.motor_inhibition = 0.125
    output.autonomic_arousal = 0.25
    output.actuator_command_kind = candidate.actuator_command_kind
    output.clock_domain = candidate.clock_domain
    output.output_minimum = 0
    output.output_maximum = 1
    output.output_fingerprint = excitations.withUnsafeBufferPointer { values in
      withUnsafePointer(to: &output) {
        nb_brain_abi_motor_output_v2_fingerprint($0, values.baseAddress)
      }
    }

    var readyGate = NBNumanXMotorReadyGateGPUV2()
    readyGate.abiVersion = UInt32(NB_NUMANX_MOTOR_READY_ABI_VERSION_V2)
    readyGate.structBytes = UInt32(NB_NUMANX_MOTOR_READY_GATE_V2_BYTE_COUNT)
    readyGate.status = UInt32(NB_NUMANX_READY_GATE_SUCCESS.rawValue)
    readyGate.environment = candidate.environment_identifier
    readyGate.substepIndex = substep.substep_index
    readyGate.attemptIndex = substep.attempt_index
    readyGate.muscleCount = candidate.muscle_count
    readyGate.actuatorCommandKind = candidate.actuator_command_kind
    readyGate.controlStep = root.control_step_identifier
    readyGate.transactionFingerprint = root.transaction_fingerprint
    readyGate.substepFingerprint = substep.substep_fingerprint
    readyGate.candidateFingerprint = candidate.candidate_fingerprint
    readyGate.motorOutputFingerprint = output.output_fingerprint
    readyGate.motorProfileFingerprint = candidate.motor_profile_fingerprint
    readyGate.brainGeneration = candidate.brain_generation
    readyGate.acceptedBrainTimestampNanoseconds =
      candidate.accepted_brain_timestamp_nanoseconds
    readyGate.randomCounterGeneration = candidate.random_counter_generation
    readyGate.speciesTemplateFingerprint = candidate.species_template_fingerprint
    readyGate.compiledSpeciesTemplateFingerprint =
      candidate.compiled_species_template_fingerprint
    readyGate.brainProgramFingerprint = 0x8888
    readyGate.fastProgramFingerprint = 0x9999
    readyGate.decisionGateFingerprint = 0xaaaa
    readyGate.clockDomain = candidate.clock_domain
    readyGate.clockQuantumNanoseconds = 1
    readyGate.gateFingerprint = withUnsafePointer(to: &readyGate) {
      nb_brain_abi_numanx_motor_ready_gate_v2_fingerprint($0)
    }

    var authority = NBNumanXExactInboundAuthorityV2()
    authority.abi_version = UInt32(NB_NUMANX_EXACT_INBOUND_AUTHORITY_ABI_V2)
    authority.struct_size = UInt32(
      NB_NUMANX_EXACT_INBOUND_AUTHORITY_V2_BYTE_COUNT
    )
    authority.clock_domain = UInt32(NB_PHYSICAL_CLOCK_DOMAIN_EXACT_NANOSECONDS)
    authority.clock_quantum_nanoseconds = 1
    authority.accepted_brain_timestamp_nanoseconds = 12_500
    authority.brain_generation = 10
    authority.transaction_fingerprint = root.transaction_fingerprint
    authority.substep_fingerprint = substep.substep_fingerprint
    authority.motor_candidate_fingerprint = candidate.candidate_fingerprint
    authority.motor_output_fingerprint = output.output_fingerprint
    authority.motor_profile_fingerprint = candidate.motor_profile_fingerprint
    authority.motor_ready_gate_fingerprint = readyGate.gateFingerprint
    authority.brain_program_fingerprint = readyGate.brainProgramFingerprint
    authority.fast_program_fingerprint = readyGate.fastProgramFingerprint
    authority.decision_gate_fingerprint = readyGate.decisionGateFingerprint
    authority.inbound_authority_fingerprint = withUnsafePointer(to: &authority) {
      nb_brain_abi_numanx_exact_inbound_authority_v2_fingerprint($0)
    }

    var proof = NBNumanXAcceptedStateProofV2()
    proof.abiVersion = UInt32(NB_NUMANX_EXACT_ACCEPTED_STATE_PROOF_ABI_V2)
    proof.structSize = UInt32(NB_NUMANX_EXACT_ACCEPTED_STATE_PROOF_V2_BYTE_COUNT)
    proof.status = UInt32(NB_NUMANX_EXACT_ACCEPTED_STATE_PROOF_VALID)
    proof.environment = 7
    proof.transactionFingerprint = authority.transaction_fingerprint
    proof.substepFingerprint = authority.substep_fingerprint
    proof.acceptedTimestampNanoseconds = 25_000
    proof.physicsGeneration = 101
    proof.clockDomain = authority.clock_domain
    proof.clockQuantumNanoseconds = authority.clock_quantum_nanoseconds
    proof.humanStateFingerprint = 0x1111_1111_1111_1111
    proof.matterStateFingerprint = 0x2222_2222_2222_2222
    proof.matterSourcePhysicsFingerprint = 0x3333_3333_3333_3333
    proof.matterDeviceProgramFingerprint = 0x4444_4444_4444_4444
    proof.stateProofProgramFingerprint = 0x5555_5555_5555_5555
    proof.adapterProgramFingerprint = 0x6666_6666_6666_6666
    proof.transactionPolicyFingerprint = 0x7777_7777_7777_7777
    proof.linearizationEpoch = 13
    proof.slotGeneration = 17
    proof.motorCandidateFingerprint = authority.motor_candidate_fingerprint
    proof.inboundAuthorityFingerprint = authority.inbound_authority_fingerprint
    proof.physicsStateFingerprint = withUnsafePointer(to: &proof) {
      nb_brain_abi_numanx_exact_physics_state_v2_fingerprint($0)
    }
    proof.proofFingerprint = withUnsafePointer(to: &proof) {
      nb_brain_abi_numanx_exact_accepted_state_proof_v2_fingerprint($0)
    }

    var token = NBNumanXExactAcceptedPhysicsTokenV2()
    token.transactionFingerprint = proof.transactionFingerprint
    token.substepFingerprint = proof.substepFingerprint
    token.physicsStateFingerprint = proof.physicsStateFingerprint
    token.acceptedTimestampNanoseconds = proof.acceptedTimestampNanoseconds
    token.physicsGeneration = proof.physicsGeneration
    token.environmentIdentifier = proof.environment
    token.flags = 0
    token.clockDomain = proof.clockDomain
    token.clockQuantumNanoseconds = proof.clockQuantumNanoseconds
    token.tokenFingerprint = withUnsafePointer(to: &token) {
      nb_brain_abi_numanx_exact_accepted_physics_token_v2_fingerprint($0)
    }

    var timing = NBNumanXExactSensorTimingV2()
    timing.abi_version = UInt32(NB_NUMANX_EXACT_SENSOR_TIMING_ABI_V2)
    timing.struct_size = UInt32(NB_NUMANX_EXACT_SENSOR_TIMING_V2_BYTE_COUNT)
    timing.capture_timestamp_nanoseconds = 12_500
    timing.delivery_timestamp_nanoseconds = 25_000
    timing.latency_nanoseconds = 12_500
    timing.sample_interval_nanoseconds = 12_500
    timing.clock_domain = authority.clock_domain
    timing.clock_quantum_nanoseconds = authority.clock_quantum_nanoseconds
    timing.timing_fingerprint = withUnsafePointer(to: &timing) {
      nb_brain_abi_numanx_exact_sensor_timing_v2_fingerprint($0)
    }

    var proprioception = NBNumanXExactSensorChannelV2()
    proprioception.abi_version = UInt32(NB_NUMANX_EXACT_SENSOR_CHANNEL_ABI_V2)
    proprioception.struct_size = UInt32(
      NB_NUMANX_EXACT_SENSOR_CHANNEL_V2_BYTE_COUNT
    )
    proprioception.modality = UInt32(NB_NUMANX_EXACT_MODALITY_PROPRIOCEPTION_V1)
    proprioception.flags = UInt32(
      NB_NUMANX_EXACT_SENSOR_CHANNEL_HAS_VALIDITY_V1
    )
    proprioception.receptor_timestamp_nanoseconds =
      timing.capture_timestamp_nanoseconds
    proprioception.clock_domain = timing.clock_domain
    proprioception.clock_quantum_nanoseconds = timing.clock_quantum_nanoseconds
    proprioception.receptor_count = 3
    proprioception.feature_dimension = 10
    proprioception.values = makeRange(
      pointer: 0x5000_0000,
      gpuAddress: 0x1000,
      byteCount: 120,
      elementType: UInt32(NB_NUMANX_EXACT_ELEMENT_FLOAT32_V1)
    )
    proprioception.validity = makeRange(
      pointer: 0x6000_0000,
      gpuAddress: 0x2000,
      byteCount: 12,
      elementType: UInt32(NB_NUMANX_EXACT_ELEMENT_UINT32_V1)
    )
    proprioception.channel_fingerprint = withUnsafePointer(to: &proprioception) {
      nb_brain_abi_numanx_exact_sensor_channel_v2_fingerprint($0)
    }

    var interoception = proprioception
    interoception.modality = UInt32(NB_NUMANX_EXACT_MODALITY_INTEROCEPTION_V1)
    interoception.feature_dimension = 1
    interoception.values = makeRange(
      pointer: 0x7000_0000,
      gpuAddress: 0x3000,
      byteCount: 12,
      elementType: UInt32(NB_NUMANX_EXACT_ELEMENT_FLOAT32_V1)
    )
    interoception.validity = makeRange(
      pointer: 0x8000_0000,
      gpuAddress: 0x4000,
      byteCount: 12,
      elementType: UInt32(NB_NUMANX_EXACT_ELEMENT_UINT32_V1)
    )
    interoception.channel_fingerprint = withUnsafePointer(to: &interoception) {
      nb_brain_abi_numanx_exact_sensor_channel_v2_fingerprint($0)
    }
    let channels = [proprioception, interoception]

    var packet = NBNumanXExactSensorPacketV2()
    packet.abi_version = UInt32(NB_NUMANX_EXACT_SENSOR_PACKET_ABI_V2)
    packet.struct_size = UInt32(NB_NUMANX_EXACT_SENSOR_PACKET_V2_BYTE_COUNT)
    packet.clock_domain = authority.clock_domain
    packet.clock_quantum_nanoseconds = authority.clock_quantum_nanoseconds
    packet.channel_count = UInt32(channels.count)
    packet.channel_capacity = UInt32(NB_NUMANX_EXACT_MAX_SENSOR_CHANNELS_V2)
    packet.transaction_fingerprint = proof.transactionFingerprint
    packet.substep_fingerprint = proof.substepFingerprint
    packet.accepted_physics_token_fingerprint = token.tokenFingerprint
    packet.inbound_authority_fingerprint = authority.inbound_authority_fingerprint
    packet.human_io_program_fingerprint = 0xdddd_dddd_dddd_dddd
    packet.sensor_fingerprint = 0x9999_9999_9999_9999
    packet.transaction_instance_fingerprint = 0xaaaa_aaaa_aaaa_aaaa
    packet.sensor_generation = 19
    packet.accepted_brain_generation = authority.brain_generation
    packet.device_registry_id = 0xbbbb_bbbb_bbbb_bbbb
    packet.timing_fingerprint = timing.timing_fingerprint
    packet.channel_set_fingerprint = channels.withUnsafeBufferPointer {
      nb_brain_abi_numanx_exact_sensor_channel_set_v2_fingerprint(
        $0.baseAddress, $0.count
      )
    }
    packet.candidate_publication_fingerprint = withUnsafePointer(to: &packet) {
      nb_brain_abi_numanx_exact_sensor_packet_v2_fingerprint($0)
    }

    var publication = NBNumanXExactPublicationV2()
    publication.abi_version = UInt32(NB_NUMANX_EXACT_PUBLICATION_ABI_V2)
    publication.struct_size = UInt32(NB_NUMANX_EXACT_PUBLICATION_V2_BYTE_COUNT)
    publication.clock_domain = token.clockDomain
    publication.clock_quantum_nanoseconds = token.clockQuantumNanoseconds
    publication.transaction_fingerprint = token.transactionFingerprint
    publication.accepted_physics_token_fingerprint = token.tokenFingerprint
    publication.candidate_publication_fingerprint =
      packet.candidate_publication_fingerprint
    publication.joint_commit_fingerprint = 0xcccc_cccc_cccc_cccc
    publication.brain_generation = packet.accepted_brain_generation
    publication.committed_timestamp_nanoseconds =
      token.acceptedTimestampNanoseconds
    publication.publication_fingerprint = withUnsafePointer(to: &publication) {
      nb_brain_abi_numanx_exact_publication_v2_fingerprint($0)
    }

    return Fixture(
      root: root,
      substep: substep,
      candidate: candidate,
      output: output,
      readyGate: readyGate,
      authority: authority,
      proof: proof,
      token: token,
      timing: timing,
      channels: channels,
      packet: packet,
      publication: publication,
      excitations: excitations
    )
  }

  private func validateInbound(
    _ fixture: Fixture,
    authority: NBNumanXExactInboundAuthorityV2? = nil
  ) -> UInt32 {
    var authority = authority ?? fixture.authority
    var root = fixture.root
    var substep = fixture.substep
    var candidate = fixture.candidate
    var output = fixture.output
    var readyGate = fixture.readyGate
    return fixture.excitations.withUnsafeBufferPointer { excitations in
      withUnsafePointer(to: &authority) { authority in
        withUnsafePointer(to: &root) { root in
          withUnsafePointer(to: &substep) { substep in
            withUnsafePointer(to: &candidate) { candidate in
              withUnsafePointer(to: &output) { output in
                withUnsafePointer(to: &readyGate) { readyGate in
                  nb_brain_abi_validate_numanx_exact_inbound_authority_v2(
                    authority, root, substep, candidate, output,
                    excitations.baseAddress, readyGate
                  )
                }
              }
            }
          }
        }
      }
    }
  }

  private func validateFamily(
    _ fixture: Fixture,
    authority: NBNumanXExactInboundAuthorityV2? = nil,
    proof: NBNumanXAcceptedStateProofV2? = nil,
    token: NBNumanXExactAcceptedPhysicsTokenV2? = nil,
    timing: NBNumanXExactSensorTimingV2? = nil,
    channels: [NBNumanXExactSensorChannelV2]? = nil,
    packet: NBNumanXExactSensorPacketV2? = nil,
    publication: NBNumanXExactPublicationV2? = nil
  ) -> UInt32 {
    var authority = authority ?? fixture.authority
    var proof = proof ?? fixture.proof
    var token = token ?? fixture.token
    var timing = timing ?? fixture.timing
    let channels = channels ?? fixture.channels
    var packet = packet ?? fixture.packet
    var publication = publication ?? fixture.publication
    return channels.withUnsafeBufferPointer { channels in
      withUnsafePointer(to: &authority) { authority in
        withUnsafePointer(to: &proof) { proof in
          withUnsafePointer(to: &token) { token in
            withUnsafePointer(to: &timing) { timing in
              withUnsafePointer(to: &packet) { packet in
                withUnsafePointer(to: &publication) { publication in
                  nb_brain_abi_validate_numanx_exact_outbound_family_v2(
                    authority, proof, token, timing, channels.baseAddress,
                    channels.count, packet, publication
                  )
                }
              }
            }
          }
        }
      }
    }
  }

  func testExactOutboundLayoutsAndIndependentCanonicalGoldens() throws {
    var fixture = try makeFixture()
    XCTAssertEqual(nb_brain_abi_numanx_exact_inbound_authority_v2_size(), 112)
    XCTAssertEqual(nb_brain_abi_numanx_exact_accepted_state_proof_v2_size(), 160)
    XCTAssertEqual(nb_brain_abi_numanx_exact_accepted_physics_token_v2_size(), 64)
    XCTAssertEqual(nb_brain_abi_numanx_exact_sensor_timing_v2_size(), 56)
    XCTAssertEqual(nb_brain_abi_numanx_exact_sensor_channel_v2_size(), 144)
    XCTAssertEqual(nb_brain_abi_numanx_exact_sensor_packet_v2_size(), 128)
    XCTAssertEqual(nb_brain_abi_numanx_exact_publication_v2_size(), 72)
    XCTAssertEqual(
      MemoryLayout<NBNumanXExactInboundAuthorityV2>.offset(
        of: \.accepted_brain_timestamp_nanoseconds
      ),
      16
    )
    XCTAssertEqual(
      MemoryLayout<NBNumanXExactInboundAuthorityV2>.offset(
        of: \.inbound_authority_fingerprint
      ),
      104
    )
    XCTAssertEqual(
      MemoryLayout<NBNumanXAcceptedStateProofV2>.offset(of: \.proofFingerprint),
      152
    )
    XCTAssertEqual(
      MemoryLayout<NBNumanXExactSensorChannelV2>.offset(
        of: \.channel_fingerprint
      ),
      136
    )

    XCTAssertEqual(fixture.root.transaction_fingerprint, rootGolden)
    XCTAssertEqual(fixture.substep.substep_fingerprint, substepGolden)
    XCTAssertEqual(fixture.candidate.candidate_fingerprint, candidateGolden)
    XCTAssertEqual(fixture.output.output_fingerprint, outputGolden)
    XCTAssertEqual(fixture.readyGate.gateFingerprint, readyGateGolden)
    XCTAssertEqual(
      fixture.authority.inbound_authority_fingerprint, authorityGolden
    )
    XCTAssertEqual(fixture.proof.physicsStateFingerprint, physicsStateGolden)
    XCTAssertEqual(fixture.proof.proofFingerprint, proofGolden)
    XCTAssertEqual(fixture.token.tokenFingerprint, tokenGolden)
    XCTAssertEqual(fixture.timing.timing_fingerprint, timingGolden)
    XCTAssertEqual(fixture.channels[0].channel_fingerprint, channelGolden)
    XCTAssertEqual(fixture.packet.channel_set_fingerprint, channelSetGolden)
    XCTAssertEqual(
      fixture.packet.candidate_publication_fingerprint, packetGolden
    )
    XCTAssertEqual(
      fixture.publication.publication_fingerprint, publicationGolden
    )

    XCTAssertEqual(
      validateInbound(fixture),
      UInt32(NB_NUMANX_EXACT_OUTBOUND_VALID.rawValue)
    )
    XCTAssertEqual(
      validateFamily(fixture),
      UInt32(NB_NUMANX_EXACT_OUTBOUND_VALID.rawValue)
    )

    let fingerprints = [
      fixture.authority.inbound_authority_fingerprint,
      fixture.proof.physicsStateFingerprint,
      fixture.proof.proofFingerprint,
      fixture.token.tokenFingerprint,
      fixture.timing.timing_fingerprint,
      fixture.channels[0].channel_fingerprint,
      fixture.packet.channel_set_fingerprint,
      fixture.packet.candidate_publication_fingerprint,
      fixture.publication.publication_fingerprint,
    ]
    XCTAssertEqual(Set(fingerprints).count, fingerprints.count)

    // The existing transaction-v2 accepted token remains a separate published
    // hash family even though the native outbound token has the same byte size.
    var legacyFamily = NBAcceptedPhysicsStateTokenV2()
    legacyFamily.transaction_fingerprint = fixture.token.transactionFingerprint
    legacyFamily.substep_fingerprint = fixture.token.substepFingerprint
    legacyFamily.physics_state_fingerprint = fixture.token.physicsStateFingerprint
    legacyFamily.accepted_timestamp_ticks =
      fixture.token.acceptedTimestampNanoseconds
    legacyFamily.physics_generation = fixture.token.physicsGeneration
    legacyFamily.environment_identifier = fixture.token.environmentIdentifier
    legacyFamily.clock_domain = UInt32(NB_PHYSICAL_CLOCK_DOMAIN_EXACT_NANOSECONDS)
    legacyFamily.clock_quantum_nanoseconds = 1
    legacyFamily.token_fingerprint = withUnsafePointer(to: &legacyFamily) {
      nb_brain_abi_accepted_physics_state_v2_fingerprint($0)
    }
    XCTAssertNotEqual(legacyFamily.token_fingerprint, tokenGolden)
    let mixedValidation = withUnsafePointer(to: &fixture.proof) { proof in
      withUnsafePointer(to: &legacyFamily) { legacy in
        legacy.withMemoryRebound(
          to: NBNumanXExactAcceptedPhysicsTokenV2.self,
          capacity: 1
        ) {
          nb_brain_abi_validate_numanx_exact_accepted_physics_token_v2(
            proof, $0
          )
        }
      }
    }
    XCTAssertNotEqual(
      mixedValidation,
      UInt32(NB_NUMANX_EXACT_OUTBOUND_VALID.rawValue)
    )
  }

  func testStaleBrainAuthorityAndMixedClocksFailClosed() throws {
    let fixture = try makeFixture()

    var mixedClock = fixture.authority
    mixedClock.clock_domain = UInt32(NB_PHYSICAL_CLOCK_DOMAIN_LEGACY_MICROSECONDS)
    mixedClock.clock_quantum_nanoseconds = 1_000
    mixedClock.inbound_authority_fingerprint = withUnsafePointer(to: &mixedClock) {
      nb_brain_abi_numanx_exact_inbound_authority_v2_fingerprint($0)
    }
    XCTAssertEqual(
      validateInbound(fixture, authority: mixedClock),
      UInt32(NB_NUMANX_EXACT_OUTBOUND_CLOCK.rawValue)
    )

    var staleCandidate = fixture.authority
    staleCandidate.motor_candidate_fingerprint &+= 1
    staleCandidate.inbound_authority_fingerprint = withUnsafePointer(
      to: &staleCandidate
    ) {
      nb_brain_abi_numanx_exact_inbound_authority_v2_fingerprint($0)
    }
    XCTAssertEqual(
      validateInbound(fixture, authority: staleCandidate),
      UInt32(NB_NUMANX_EXACT_OUTBOUND_RELATION.rawValue)
    )

    let staleIdentityPaths: [WritableKeyPath<
      NBNumanXExactInboundAuthorityV2, UInt64
    >] = [
      \.transaction_fingerprint,
      \.substep_fingerprint,
      \.motor_candidate_fingerprint,
      \.motor_output_fingerprint,
      \.motor_profile_fingerprint,
      \.motor_ready_gate_fingerprint,
      \.brain_program_fingerprint,
      \.fast_program_fingerprint,
      \.decision_gate_fingerprint,
    ]
    for path in staleIdentityPaths {
      var stale = fixture.authority
      stale[keyPath: path] &+= 1
      stale.inbound_authority_fingerprint = withUnsafePointer(to: &stale) {
        nb_brain_abi_numanx_exact_inbound_authority_v2_fingerprint($0)
      }
      XCTAssertNotEqual(
        validateInbound(fixture, authority: stale),
        UInt32(NB_NUMANX_EXACT_OUTBOUND_VALID.rawValue)
      )
    }

    var staleTimestamp = fixture.authority
    staleTimestamp.accepted_brain_timestamp_nanoseconds &+= 1
    staleTimestamp.inbound_authority_fingerprint = withUnsafePointer(
      to: &staleTimestamp
    ) {
      nb_brain_abi_numanx_exact_inbound_authority_v2_fingerprint($0)
    }
    XCTAssertEqual(
      validateInbound(fixture, authority: staleTimestamp),
      UInt32(NB_NUMANX_EXACT_OUTBOUND_TIME_ORDER.rawValue)
    )

    var staleGeneration = fixture.authority
    staleGeneration.brain_generation &+= 1
    staleGeneration.inbound_authority_fingerprint = withUnsafePointer(
      to: &staleGeneration
    ) {
      nb_brain_abi_numanx_exact_inbound_authority_v2_fingerprint($0)
    }
    XCTAssertEqual(
      validateInbound(fixture, authority: staleGeneration),
      UInt32(NB_NUMANX_EXACT_OUTBOUND_GENERATION.rawValue)
    )

    var stalePacket = fixture.packet
    stalePacket.accepted_brain_generation &+= 1
    stalePacket.candidate_publication_fingerprint = withUnsafePointer(
      to: &stalePacket
    ) {
      nb_brain_abi_numanx_exact_sensor_packet_v2_fingerprint($0)
    }
    XCTAssertEqual(
      validateFamily(fixture, packet: stalePacket),
      UInt32(NB_NUMANX_EXACT_OUTBOUND_GENERATION.rawValue)
    )

    var mixedProof = fixture.proof
    mixedProof.clockQuantumNanoseconds = 1_000
    mixedProof.physicsStateFingerprint = withUnsafePointer(to: &mixedProof) {
      nb_brain_abi_numanx_exact_physics_state_v2_fingerprint($0)
    }
    mixedProof.proofFingerprint = withUnsafePointer(to: &mixedProof) {
      nb_brain_abi_numanx_exact_accepted_state_proof_v2_fingerprint($0)
    }
    XCTAssertEqual(
      validateFamily(fixture, proof: mixedProof),
      UInt32(NB_NUMANX_EXACT_OUTBOUND_CLOCK.rawValue)
    )
  }

  func testCanonicalChannelOrderAndDescriptorRangesFailClosed() throws {
    let fixture = try makeFixture()

    let reversed = Array(fixture.channels.reversed())
    var reorderedPacket = fixture.packet
    reorderedPacket.channel_set_fingerprint = reversed.withUnsafeBufferPointer {
      nb_brain_abi_numanx_exact_sensor_channel_set_v2_fingerprint(
        $0.baseAddress, $0.count
      )
    }
    reorderedPacket.candidate_publication_fingerprint = withUnsafePointer(
      to: &reorderedPacket
    ) {
      nb_brain_abi_numanx_exact_sensor_packet_v2_fingerprint($0)
    }
    XCTAssertEqual(
      validateFamily(
        fixture,
        channels: reversed,
        packet: reorderedPacket
      ),
      UInt32(NB_NUMANX_EXACT_OUTBOUND_ORDER.rawValue)
    )

    var overflow = fixture.channels[0]
    overflow.values.gpu_address = UInt64.max - 3
    overflow.values.byte_offset = UInt64.max - 3
    overflow.channel_fingerprint = withUnsafePointer(to: &overflow) {
      nb_brain_abi_numanx_exact_sensor_channel_v2_fingerprint($0)
    }
    var timing = fixture.timing
    let overflowValidation = withUnsafePointer(to: &overflow) { channel in
      withUnsafePointer(to: &timing) {
        nb_brain_abi_validate_numanx_exact_sensor_channel_v2(channel, $0)
      }
    }
    XCTAssertEqual(
      overflowValidation,
      UInt32(NB_NUMANX_EXACT_OUTBOUND_RANGE.rawValue)
    )

    var overlap = fixture.channels[0]
    overlap.validity.metal_buffer = overlap.values.metal_buffer
    overlap.validity.byte_offset = 4
    overlap.validity.gpu_address = overlap.values.gpu_address + 4
    overlap.channel_fingerprint = withUnsafePointer(to: &overlap) {
      nb_brain_abi_numanx_exact_sensor_channel_v2_fingerprint($0)
    }
    let overlapValidation = withUnsafePointer(to: &overlap) { channel in
      withUnsafePointer(to: &timing) {
        nb_brain_abi_validate_numanx_exact_sensor_channel_v2(channel, $0)
      }
    }
    XCTAssertEqual(
      overlapValidation,
      UInt32(NB_NUMANX_EXACT_OUTBOUND_RANGE.rawValue)
    )

    var crossOverlap = fixture.channels
    crossOverlap[1].values.metal_buffer = crossOverlap[0].values.metal_buffer
    crossOverlap[1].values.gpu_address = crossOverlap[0].values.gpu_address
    crossOverlap[1].values.byte_offset = crossOverlap[0].values.byte_offset
    crossOverlap[1].channel_fingerprint = withUnsafePointer(
      to: &crossOverlap[1]
    ) {
      nb_brain_abi_numanx_exact_sensor_channel_v2_fingerprint($0)
    }
    var crossPacket = fixture.packet
    crossPacket.channel_set_fingerprint = crossOverlap.withUnsafeBufferPointer {
      nb_brain_abi_numanx_exact_sensor_channel_set_v2_fingerprint(
        $0.baseAddress, $0.count
      )
    }
    crossPacket.candidate_publication_fingerprint = withUnsafePointer(
      to: &crossPacket
    ) {
      nb_brain_abi_numanx_exact_sensor_packet_v2_fingerprint($0)
    }
    XCTAssertEqual(
      validateFamily(
        fixture,
        channels: crossOverlap,
        packet: crossPacket
      ),
      UInt32(NB_NUMANX_EXACT_OUTBOUND_RANGE.rawValue)
    )
  }
}

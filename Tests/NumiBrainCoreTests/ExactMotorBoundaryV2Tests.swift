import NumiBrainABI
import XCTest

@testable import NumiBrainCore

final class ExactMotorBoundaryV2Tests: XCTestCase {
  private let rootGolden: UInt64 = 0x9862_5287_1c86_7014
  private let substepGolden: UInt64 = 0x3397_6074_2e9d_5b13
  private let candidateGolden: UInt64 = 0xd545_ffb8_4702_f6cc
  private let outputGolden: UInt64 = 0xd299_7dd6_7ccf_83f4
  private let gateGolden: UInt64 = 0x7a7c_4daa_7709_eef0

  private func exactRoot() throws -> BrainJointTransactionTokenV2 {
    try .exactNanoseconds(
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
  }

  private func exactSubstep(
    root: BrainJointTransactionTokenV2
  ) throws -> BrainJointSubstepTokenV2 {
    try .exactNanoseconds(
      transaction: root,
      substepIndex: 0,
      attemptIndex: 0,
      startTimestampNanoseconds: 12_500,
      durationNanoseconds: 12_500
    )
  }

  private func exactCandidate(
    root: BrainJointTransactionTokenV2,
    substep: BrainJointSubstepTokenV2
  ) -> NBNumanXMotorCandidateV2 {
    var candidate = NBNumanXMotorCandidateV2()
    candidate.format_version = UInt32(NB_NUMANX_MOTOR_CANDIDATE_V2_VERSION)
    candidate.flags = UInt32(NB_NUMANX_MOTOR_CANDIDATE_FLAG_VALID)
      | UInt32(NB_NUMANX_MOTOR_CANDIDATE_FLAG_DECISION_SHADOW)
    candidate.transaction_fingerprint = root.fingerprint
    candidate.substep_fingerprint = substep.fingerprint
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
    return candidate
  }

  private func exactOutput(
    candidate: NBNumanXMotorCandidateV2,
    excitations: [Float]
  ) -> NBMotorOutputHeaderV2 {
    var header = NBMotorOutputHeaderV2()
    header.format_version = UInt32(NB_MOTOR_OUTPUT_V2_VERSION)
    header.flags = UInt32(NB_MOTOR_OUTPUT_FLAG_VALID)
    header.timestamp_nanoseconds = candidate.accepted_brain_timestamp_nanoseconds
    header.brain_generation = candidate.brain_generation
    header.profile_fingerprint = candidate.motor_profile_fingerprint
    header.protective_command_fingerprint = 0x7777
    header.muscle_count = candidate.muscle_count
    header.environment_identifier = candidate.environment_identifier
    header.motor_inhibition = 0.125
    header.autonomic_arousal = 0.25
    header.actuator_command_kind = candidate.actuator_command_kind
    header.clock_domain = candidate.clock_domain
    header.output_minimum = 0
    header.output_maximum = 1
    header.output_fingerprint = excitations.withUnsafeBufferPointer { buffer in
      withUnsafePointer(to: &header) {
        nb_brain_abi_motor_output_v2_fingerprint($0, buffer.baseAddress)
      }
    }
    return header
  }

  private func exactGate(
    root: BrainJointTransactionTokenV2,
    substep: BrainJointSubstepTokenV2,
    candidate: NBNumanXMotorCandidateV2,
    header: NBMotorOutputHeaderV2
  ) -> NBNumanXMotorReadyGateGPUV2 {
    var gate = NBNumanXMotorReadyGateGPUV2()
    gate.abiVersion = UInt32(NB_NUMANX_MOTOR_READY_ABI_VERSION_V2)
    gate.structBytes = UInt32(NB_NUMANX_MOTOR_READY_GATE_V2_BYTE_COUNT)
    gate.status = UInt32(NB_NUMANX_READY_GATE_SUCCESS.rawValue)
    gate.environment = candidate.environment_identifier
    gate.substepIndex = substep.substepIndex
    gate.attemptIndex = substep.attemptIndex
    gate.muscleCount = candidate.muscle_count
    gate.actuatorCommandKind = candidate.actuator_command_kind
    gate.controlStep = root.controlStepIdentifier
    gate.transactionFingerprint = root.fingerprint
    gate.substepFingerprint = substep.fingerprint
    gate.candidateFingerprint = candidate.candidate_fingerprint
    gate.motorOutputFingerprint = header.output_fingerprint
    gate.motorProfileFingerprint = candidate.motor_profile_fingerprint
    gate.brainGeneration = candidate.brain_generation
    gate.acceptedBrainTimestampNanoseconds =
      candidate.accepted_brain_timestamp_nanoseconds
    gate.randomCounterGeneration = candidate.random_counter_generation
    gate.speciesTemplateFingerprint = candidate.species_template_fingerprint
    gate.compiledSpeciesTemplateFingerprint =
      candidate.compiled_species_template_fingerprint
    gate.brainProgramFingerprint = 0x8888
    gate.fastProgramFingerprint = 0x9999
    gate.decisionGateFingerprint = 0xaaaa
    gate.clockDomain = candidate.clock_domain
    gate.clockQuantumNanoseconds =
      UInt32(NB_EXACT_NANOSECOND_CLOCK_QUANTUM_NANOSECONDS)
    gate.gateFingerprint = withUnsafePointer(to: &gate) {
      nb_brain_abi_numanx_motor_ready_gate_v2_fingerprint($0)
    }
    return gate
  }

  func testExactMotorLayoutsAndSharedGoldenFingerprints() throws {
    XCTAssertEqual(nb_brain_abi_motor_output_header_v2_size(), 80)
    XCTAssertEqual(nb_brain_abi_numanx_motor_candidate_v2_size(), 152)
    XCTAssertEqual(nb_brain_abi_numanx_motor_ready_gate_v2_size(), 160)
    XCTAssertEqual(MemoryLayout<NBMotorOutputHeaderV2>.stride, 80)
    XCTAssertEqual(MemoryLayout<NBMotorOutputHeaderV2>.alignment, 16)
    XCTAssertEqual(MemoryLayout<NBNumanXMotorCandidateV2>.stride, 152)
    XCTAssertEqual(MemoryLayout<NBNumanXMotorReadyGateGPUV2>.stride, 160)
    XCTAssertEqual(
      MemoryLayout<NBMotorOutputHeaderV2>.offset(of: \.clock_domain), 60
    )
    XCTAssertEqual(
      MemoryLayout<NBNumanXMotorCandidateV2>.offset(of: \.clock_domain), 124
    )
    XCTAssertEqual(
      MemoryLayout<NBNumanXMotorReadyGateGPUV2>.offset(of: \.clockDomain), 144
    )

    let root = try exactRoot()
    let substep = try exactSubstep(root: root)
    var rootRecord = root.abiRecord
    var substepRecord = substep.abiRecord
    var candidate = exactCandidate(root: root, substep: substep)
    let excitations: [Float] = [0.25, 0.5, 0.75]
    var header = exactOutput(candidate: candidate, excitations: excitations)
    var gate = exactGate(
      root: root,
      substep: substep,
      candidate: candidate,
      header: header
    )

    XCTAssertEqual(root.fingerprint, rootGolden)
    XCTAssertEqual(substep.fingerprint, substepGolden)
    XCTAssertEqual(candidate.candidate_fingerprint, candidateGolden)
    XCTAssertEqual(header.output_fingerprint, outputGolden)
    XCTAssertEqual(gate.gateFingerprint, gateGolden)
    XCTAssertEqual(
      withUnsafePointer(to: &rootRecord) { rootPointer in
        withUnsafePointer(to: &substepRecord) { substepPointer in
          withUnsafePointer(to: &candidate) {
            nb_brain_abi_validate_numanx_motor_candidate_v2(
              rootPointer, substepPointer, $0
            )
          }
        }
      },
      UInt32(NB_NUMANX_MOTOR_CANDIDATE_VALID.rawValue)
    )
    XCTAssertEqual(
      excitations.withUnsafeBufferPointer { buffer in
        withUnsafePointer(to: &candidate) { candidatePointer in
          withUnsafePointer(to: &header) {
            nb_brain_abi_validate_motor_output_v2(
              candidatePointer, $0, buffer.baseAddress
            )
          }
        }
      },
      UInt32(NB_MOTOR_OUTPUT_VALID.rawValue)
    )
    XCTAssertEqual(
      withUnsafePointer(to: &rootRecord) { rootPointer in
        withUnsafePointer(to: &substepRecord) { substepPointer in
          withUnsafePointer(to: &candidate) { candidatePointer in
            withUnsafePointer(to: &header) { headerPointer in
              withUnsafePointer(to: &gate) {
                nb_brain_abi_validate_numanx_motor_ready_gate_v2(
                  rootPointer, substepPointer, candidatePointer, headerPointer, $0
                )
              }
            }
          }
        }
      },
      UInt32(NB_NUMANX_MOTOR_READY_VALID.rawValue)
    )
  }

  func testExactMotorFamilyRejectsMixedClocksAndWeakAlignment() throws {
    let root = try exactRoot()
    let substep = try exactSubstep(root: root)
    var rootRecord = root.abiRecord
    var substepRecord = substep.abiRecord
    var candidate = exactCandidate(root: root, substep: substep)

    var mixedCandidate = candidate
    mixedCandidate.format_version = UInt32(NB_NUMANX_MOTOR_CANDIDATE_VERSION)
    mixedCandidate.candidate_fingerprint = withUnsafePointer(to: &mixedCandidate) {
      nb_brain_abi_numanx_motor_candidate_v2_fingerprint($0)
    }
    XCTAssertEqual(
      withUnsafePointer(to: &rootRecord) { rootPointer in
        withUnsafePointer(to: &substepRecord) { substepPointer in
          withUnsafePointer(to: &mixedCandidate) {
            nb_brain_abi_validate_numanx_motor_candidate_v2(
              rootPointer, substepPointer, $0
            )
          }
        }
      },
      UInt32(NB_NUMANX_MOTOR_CANDIDATE_FORMAT.rawValue)
    )

    var legacyDomain = candidate
    legacyDomain.clock_domain = UInt32(
      NB_PHYSICAL_CLOCK_DOMAIN_LEGACY_MICROSECONDS
    )
    legacyDomain.candidate_fingerprint = withUnsafePointer(to: &legacyDomain) {
      nb_brain_abi_numanx_motor_candidate_v2_fingerprint($0)
    }
    XCTAssertEqual(
      withUnsafePointer(to: &rootRecord) { rootPointer in
        withUnsafePointer(to: &substepRecord) { substepPointer in
          withUnsafePointer(to: &legacyDomain) {
            nb_brain_abi_validate_numanx_motor_candidate_v2(
              rootPointer, substepPointer, $0
            )
          }
        }
      },
      UInt32(NB_NUMANX_MOTOR_CANDIDATE_CLOCK.rawValue)
    )

    candidate.motor_output_header_gpu_address = 0x1008
    candidate.candidate_fingerprint = withUnsafePointer(to: &candidate) {
      nb_brain_abi_numanx_motor_candidate_v2_fingerprint($0)
    }
    XCTAssertEqual(
      withUnsafePointer(to: &rootRecord) { rootPointer in
        withUnsafePointer(to: &substepRecord) { substepPointer in
          withUnsafePointer(to: &candidate) {
            nb_brain_abi_validate_numanx_motor_candidate_v2(
              rootPointer, substepPointer, $0
            )
          }
        }
      },
      UInt32(NB_NUMANX_MOTOR_CANDIDATE_ADDRESS.rawValue)
    )
  }

  func testReadyGateRejectsWrongClockAndMismatchedHeaderMetadata() throws {
    let root = try exactRoot()
    let substep = try exactSubstep(root: root)
    var rootRecord = root.abiRecord
    var substepRecord = substep.abiRecord
    var candidate = exactCandidate(root: root, substep: substep)
    let excitations: [Float] = [0.25, 0.5, 0.75]
    var header = exactOutput(candidate: candidate, excitations: excitations)
    var gate = exactGate(
      root: root,
      substep: substep,
      candidate: candidate,
      header: header
    )

    gate.clockQuantumNanoseconds = 1_000
    gate.gateFingerprint = withUnsafePointer(to: &gate) {
      nb_brain_abi_numanx_motor_ready_gate_v2_fingerprint($0)
    }
    XCTAssertEqual(
      withUnsafePointer(to: &rootRecord) { rootPointer in
        withUnsafePointer(to: &substepRecord) { substepPointer in
          withUnsafePointer(to: &candidate) { candidatePointer in
            withUnsafePointer(to: &header) { headerPointer in
              withUnsafePointer(to: &gate) {
                nb_brain_abi_validate_numanx_motor_ready_gate_v2(
                  rootPointer, substepPointer, candidatePointer, headerPointer, $0
                )
              }
            }
          }
        }
      },
      UInt32(NB_NUMANX_MOTOR_READY_CLOCK.rawValue)
    )

    header.profile_fingerprint = 0xdead
    header.output_fingerprint = excitations.withUnsafeBufferPointer { buffer in
      withUnsafePointer(to: &header) {
        nb_brain_abi_motor_output_v2_fingerprint($0, buffer.baseAddress)
      }
    }
    gate = exactGate(
      root: root,
      substep: substep,
      candidate: candidate,
      header: header
    )
    XCTAssertEqual(
      withUnsafePointer(to: &rootRecord) { rootPointer in
        withUnsafePointer(to: &substepRecord) { substepPointer in
          withUnsafePointer(to: &candidate) { candidatePointer in
            withUnsafePointer(to: &header) { headerPointer in
              withUnsafePointer(to: &gate) {
                nb_brain_abi_validate_numanx_motor_ready_gate_v2(
                  rootPointer, substepPointer, candidatePointer, headerPointer, $0
                )
              }
            }
          }
        }
      },
      UInt32(NB_NUMANX_MOTOR_READY_IDENTITY.rawValue)
    )
  }

  func testMotorOutputRejectsUnauthenticatedCandidateAndInvalidHeaderState() throws {
    let root = try exactRoot()
    let substep = try exactSubstep(root: root)
    var candidate = exactCandidate(root: root, substep: substep)
    let excitations: [Float] = [0.25, 0.5, 0.75]
    var header = exactOutput(candidate: candidate, excitations: excitations)

    candidate.candidate_fingerprint ^= 1
    XCTAssertEqual(
      excitations.withUnsafeBufferPointer { buffer in
        withUnsafePointer(to: &candidate) { candidatePointer in
          withUnsafePointer(to: &header) {
            nb_brain_abi_validate_motor_output_v2(
              candidatePointer, $0, buffer.baseAddress
            )
          }
        }
      },
      UInt32(NB_MOTOR_OUTPUT_RELATION.rawValue)
    )

    candidate = exactCandidate(root: root, substep: substep)
    header.protective_command_fingerprint = 0
    header.output_fingerprint = excitations.withUnsafeBufferPointer { buffer in
      withUnsafePointer(to: &header) {
        nb_brain_abi_motor_output_v2_fingerprint($0, buffer.baseAddress)
      }
    }
    var rootRecord = root.abiRecord
    var substepRecord = substep.abiRecord
    var gate = exactGate(
      root: root,
      substep: substep,
      candidate: candidate,
      header: header
    )
    XCTAssertEqual(
      withUnsafePointer(to: &rootRecord) { rootPointer in
        withUnsafePointer(to: &substepRecord) { substepPointer in
          withUnsafePointer(to: &candidate) { candidatePointer in
            withUnsafePointer(to: &header) { headerPointer in
              withUnsafePointer(to: &gate) {
                nb_brain_abi_validate_numanx_motor_ready_gate_v2(
                  rootPointer, substepPointer, candidatePointer, headerPointer, $0
                )
              }
            }
          }
        }
      },
      UInt32(NB_NUMANX_MOTOR_READY_IDENTITY.rawValue)
    )
  }
}

import Foundation
import XCTest

@_spi(NumanXInterop) @testable import NumiBrainMetal
import NumiBrainMetalBridgeABI

@available(macOS 26.0, *)
final class MetalNumanXRuntimeConfigV8Tests: XCTestCase {
  func testRuntimeConfigV8LayoutAndNesting() {
    XCTAssertEqual(UInt32(MRNX_RUNTIME_CONFIG_ABI_V8), 8)
    XCTAssertEqual(MemoryLayout<mrnx_runtime_config_v8>.stride, 280)
    XCTAssertEqual(MemoryLayout<mrnx_runtime_config_v8>.offset(of: \.runtime), 8)
    XCTAssertEqual(
      MemoryLayout<mrnx_runtime_config_v8>.offset(of: \.timestep_nanoseconds),
      272
    )

    "initial.nhinit".withCString { initialPath in
      let configuration = MetalNumanXBridgeV1Runtime
        .preparedRuntimeConfiguration(
          limited: limitedConfiguration(timestepMicroseconds: 100),
          initialStatePayloadPath: initialPath,
          initialStateFingerprint: 0x1234,
          timestepNanoseconds: 12_500
        )
      guard case .v8(let exact) = configuration else {
        return XCTFail("exact clock did not select v8")
      }
      XCTAssertEqual(exact.abi_version, UInt32(MRNX_RUNTIME_CONFIG_ABI_V8))
      XCTAssertEqual(exact.struct_size, 280)
      XCTAssertEqual(exact.timestep_nanoseconds, 12_500)
      XCTAssertEqual(exact.runtime.abi_version, UInt32(MRNX_RUNTIME_CONFIG_ABI_V7))
      XCTAssertEqual(exact.runtime.struct_size, 264)
      XCTAssertEqual(exact.runtime.runtime.abi_version, UInt32(MRNX_RUNTIME_CONFIG_ABI_V6))
      XCTAssertEqual(exact.runtime.runtime.runtime.abi_version, UInt32(MRNX_RUNTIME_CONFIG_ABI_V4))
      XCTAssertEqual(exact.runtime.runtime.runtime.runtime.abi_version, UInt32(MRNX_RUNTIME_CONFIG_ABI_V3))
      XCTAssertEqual(exact.runtime.runtime.runtime.runtime.runtime.abi_version,
        UInt32(MRNX_RUNTIME_CONFIG_ABI_V2))
      XCTAssertEqual(exact.runtime.initial_state_payload_path, initialPath)
      XCTAssertEqual(exact.runtime.expected_initial_state_fingerprint, 0x1234)
    }
  }

  func testExactClockAndPhysicalRootRequestLayoutsMirrorNativeContract() {
    XCTAssertEqual(UInt32(MRNX_EXACT_CLOCK_INFO_ABI_V1), 1)
    XCTAssertEqual(MemoryLayout<mrnx_exact_clock_info_v1>.stride, 40)
    XCTAssertEqual(
      MemoryLayout<mrnx_exact_clock_info_v1>.offset(
        of: \.published_timestamp_nanoseconds
      ),
      24
    )
    XCTAssertEqual(UInt32(MRNX_PHYSICAL_ROOT_REQUEST_ABI_V2), 2)
    XCTAssertEqual(MemoryLayout<mrnx_physical_root_request_v2>.stride, 600)
    var historicalV2 = mrnx_physical_root_request_v2()
    historicalV2.root.committed_timestamp_microseconds = 12
    historicalV2.substep.start_timestamp_microseconds = 12
    historicalV2.candidate.accepted_brain_timestamp_microseconds = 12
    XCTAssertEqual(historicalV2.root.committed_timestamp_microseconds, 12)
    XCTAssertEqual(historicalV2.substep.start_timestamp_microseconds, 12)
    XCTAssertEqual(
      historicalV2.candidate.accepted_brain_timestamp_microseconds, 12
    )
    XCTAssertEqual(
      MemoryLayout<mrnx_physical_root_request_v2>.offset(of: \.candidate),
      176
    )
    XCTAssertEqual(
      MemoryLayout<mrnx_physical_root_request_v2>.offset(of: \.motor_header),
      328
    )
    XCTAssertEqual(
      MemoryLayout<mrnx_physical_root_request_v2>.offset(of: \.motor_ready),
      568
    )

    XCTAssertEqual(UInt32(MRNX_PHYSICAL_ROOT_REQUEST_ABI_V3), 3)
    XCTAssertEqual(MemoryLayout<mrnx_physical_root_request_v3>.stride, 600)
    XCTAssertEqual(
      MemoryLayout<mrnx_physical_root_request_v3>.offset(of: \.candidate),
      176
    )
    XCTAssertEqual(
      MemoryLayout<mrnx_physical_root_request_v3>.offset(of: \.motor_header),
      328
    )
    XCTAssertEqual(
      MemoryLayout<mrnx_physical_root_request_v3>.offset(of: \.motor_ready_gate),
      520
    )
    XCTAssertEqual(
      MemoryLayout<mrnx_physical_root_request_v3>.offset(of: \.motor_ready),
      568
    )
    XCTAssertEqual(
      UInt32(MRNX_ELEMENT_BRAIN_MOTOR_OUTPUT_HEADER_V2.rawValue), 3
    )
    XCTAssertEqual(
      UInt32(MRNX_ELEMENT_BRAIN_MOTOR_READY_GATE_V2.rawValue), 4
    )

    XCTAssertEqual(UInt32(MRNX_AGGREGATE_SNAPSHOT_ABI_V5), 5)
    XCTAssertEqual(UInt32(MRNX_PHYSICAL_CLOCK_DOMAIN_EXACT_NANOSECONDS), 2)
    XCTAssertEqual(UInt32(MRNX_EXACT_CLOCK_QUANTUM_NANOSECONDS), 1)
    XCTAssertEqual(
      UInt32(MRNX_FINGERPRINT_DOMAIN_EXACT_INBOUND_AUTHORITY_V2),
      0x4e58_4941
    )
    XCTAssertEqual(
      UInt32(MR_NUMANX_FINGERPRINT_DOMAIN_ACCEPTED_PHYSICS_TOKEN_V2),
      0x4e58_4154
    )
    XCTAssertEqual(MemoryLayout<mrnx_exact_inbound_authority_v2>.stride, 112)
    XCTAssertEqual(MemoryLayout<MRNumanXAcceptedStateProofGPUV2>.stride, 160)
    XCTAssertEqual(
      MemoryLayout<MRNumanXAcceptedPhysicsStateTokenGPUV2>.stride, 64
    )
    XCTAssertEqual(MemoryLayout<mrnx_candidate_timing_v2>.stride, 56)
    XCTAssertEqual(MemoryLayout<mrnx_candidate_channel_v2>.stride, 144)
    XCTAssertEqual(MemoryLayout<mrnx_exact_sensor_packet_v2>.stride, 128)
    XCTAssertEqual(MemoryLayout<mrnx_publication_v2>.stride, 72)
    XCTAssertEqual(MemoryLayout<mrnx_aggregate_snapshot_v5>.stride, 2_392)
    XCTAssertEqual(
      MemoryLayout<mrnx_aggregate_snapshot_v5>.offset(of: \.timing), 248
    )
    XCTAssertEqual(
      MemoryLayout<mrnx_aggregate_snapshot_v5>.offset(
        of: \.inbound_authority
      ),
      304
    )
    XCTAssertEqual(
      MemoryLayout<mrnx_aggregate_snapshot_v5>.offset(of: \.sensor_packet),
      416
    )
    XCTAssertEqual(
      MemoryLayout<mrnx_aggregate_snapshot_v5>.offset(of: \.publication), 544
    )
    XCTAssertEqual(
      MemoryLayout<mrnx_aggregate_snapshot_v5>.offset(of: \.channels), 616
    )
    XCTAssertEqual(
      MemoryLayout<mrnx_aggregate_snapshot_v5>.offset(of: \.culture), 1_768
    )
  }

  func testExactClockRejectsZeroAndInvalidNanoseconds() {
    for invalid in [UInt64(0), 1_000_000_001, UInt64.max] {
      XCTAssertThrowsError(
        try MetalNumanXBridgeV1Runtime.validateExactTimestepNanoseconds(
          invalid
        )
      )
    }
  }

  func testExactClockIsForwardedWithoutMicrosecondRounding() {
    "initial.nhinit".withCString { initialPath in
      let configuration = MetalNumanXBridgeV1Runtime
        .preparedRuntimeConfiguration(
          limited: limitedConfiguration(timestepMicroseconds: 13),
          initialStatePayloadPath: initialPath,
          initialStateFingerprint: 8,
          timestepNanoseconds: 12_500
        )
      guard case .v8(let exact) = configuration else {
        return XCTFail("exact clock did not select v8")
      }
      XCTAssertEqual(exact.timestep_nanoseconds, 12_500)
      XCTAssertEqual(
        exact.runtime.runtime.runtime.runtime.runtime.timestep_microseconds,
        0,
        "v8 must carry no second, rounded clock authority"
      )
    }
  }

  func testNoExactClockPreservesV7Compatibility() {
    "initial.nhinit".withCString { initialPath in
      let configuration = MetalNumanXBridgeV1Runtime
        .preparedRuntimeConfiguration(
          limited: limitedConfiguration(timestepMicroseconds: 100),
          initialStatePayloadPath: initialPath,
          initialStateFingerprint: 8,
          timestepNanoseconds: nil
        )
      guard case .v7(let prepared) = configuration else {
        return XCTFail("legacy prepared clock did not select v7")
      }
      XCTAssertEqual(prepared.abi_version, UInt32(MRNX_RUNTIME_CONFIG_ABI_V7))
      XCTAssertEqual(prepared.struct_size, 264)
      XCTAssertEqual(
        prepared.runtime.runtime.runtime.runtime.timestep_microseconds,
        100
      )
      XCTAssertEqual(prepared.expected_initial_state_fingerprint, 8)
    }
  }

  func testExactClockRequiresPreparedStateAndNoLegacyClockAuthority() throws {
    let exactWithoutPreparedState = configuration(
      timestepMicroseconds: 0,
      timestepNanoseconds: 12_500,
      authoredMatterWorld: nil
    )
    XCTAssertThrowsError(
      try MetalNumanXBridgeV1Runtime.validateExactClockConfiguration(
        exactWithoutPreparedState
      )
    )

    let initial = try MetalNumanXBridgeV1Runtime.PreparedInitialState(
      payloadPath: "initial.nhinit",
      fingerprint: 8
    )
    let world = try MetalNumanXBridgeV1Runtime.AuthoredMatterWorld(
      packagePath: "world.nmatterpack",
      humanSourceFingerprint: 1,
      worldFingerprint: 2,
      sourceJointEqualities: .init(payloadPath: "source.nheq", fingerprint: 3),
      sourceJointLimits: .init(payloadPath: "source.nhlim", fingerprint: 4),
      preparedInitialState: initial
    )
    XCTAssertThrowsError(
      try MetalNumanXBridgeV1Runtime.validateExactClockConfiguration(
        configuration(
          timestepMicroseconds: 12,
          timestepNanoseconds: 12_500,
          authoredMatterWorld: world
        )
      )
    )
    XCTAssertNoThrow(
      try MetalNumanXBridgeV1Runtime.validateExactClockConfiguration(
        configuration(
          timestepMicroseconds: 0,
          timestepNanoseconds: 12_500,
          authoredMatterWorld: world
        )
      )
    )
  }

  func testGateCRunnerAdmitsOnlyPositiveWholeMicrosecondClock() throws {
    XCTAssertEqual(
      try MetalNumanXGateCRootRunner.admittedBrainTimestepMicroseconds(
        for: configuration(
          timestepMicroseconds: 100,
          timestepNanoseconds: nil,
          authoredMatterWorld: nil
        )
      ),
      100
    )
    XCTAssertThrowsError(
      try MetalNumanXGateCRootRunner.admittedBrainTimestepMicroseconds(
        for: configuration(
          timestepMicroseconds: 0,
          timestepNanoseconds: nil,
          authoredMatterWorld: nil
        )
      )
    )
    XCTAssertThrowsError(
      try MetalNumanXGateCRootRunner.admittedBrainTimestepMicroseconds(
        for: configuration(
          timestepMicroseconds: 0,
          timestepNanoseconds: 12_500,
          authoredMatterWorld: nil
        )
      )
    )
    XCTAssertThrowsError(
      try MetalNumanXGateCRootRunner.admittedBrainTimestepMicroseconds(
        for: configuration(
          timestepMicroseconds: UInt64(UInt32.max) + 1,
          timestepNanoseconds: nil,
          authoredMatterWorld: nil
        )
      )
    )
  }

  private func limitedConfiguration(
    timestepMicroseconds: UInt64
  ) -> mrnx_runtime_config_v6 {
    var base = mrnx_runtime_config_v2()
    base.abi_version = UInt32(MRNX_RUNTIME_CONFIG_ABI_V2)
    base.struct_size = UInt32(MemoryLayout<mrnx_runtime_config_v2>.stride)
    base.timestep_microseconds = timestepMicroseconds

    var authored = mrnx_runtime_config_v3()
    authored.abi_version = UInt32(MRNX_RUNTIME_CONFIG_ABI_V3)
    authored.struct_size = UInt32(MemoryLayout<mrnx_runtime_config_v3>.stride)
    authored.runtime = base

    var constrained = mrnx_runtime_config_v4()
    constrained.abi_version = UInt32(MRNX_RUNTIME_CONFIG_ABI_V4)
    constrained.struct_size = UInt32(MemoryLayout<mrnx_runtime_config_v4>.stride)
    constrained.runtime = authored

    var limited = mrnx_runtime_config_v6()
    limited.abi_version = UInt32(MRNX_RUNTIME_CONFIG_ABI_V6)
    limited.struct_size = UInt32(MemoryLayout<mrnx_runtime_config_v6>.stride)
    limited.runtime = constrained
    return limited
  }

  private func configuration(
    timestepMicroseconds: UInt64,
    timestepNanoseconds: UInt64?,
    authoredMatterWorld: MetalNumanXBridgeV1Runtime.AuthoredMatterWorld?
  ) -> MetalNumanXBridgeV1Runtime.Configuration {
    .init(
      rigidPayloadPath: "rigid",
      musclePayloadPath: "muscle",
      supportContactPayloadPath: "contacts",
      visualPackPath: "visual",
      visionProfilePath: "vision-profile",
      metalRoboMetallibPath: "metalrobo.metallib",
      matterMetallibPath: "matter.metallib",
      timestepMicroseconds: timestepMicroseconds,
      timestepNanoseconds: timestepNanoseconds,
      authoredMatterWorld: authoredMatterWorld
    )
  }
}

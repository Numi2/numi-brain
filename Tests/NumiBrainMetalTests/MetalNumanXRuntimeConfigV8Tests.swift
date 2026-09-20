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

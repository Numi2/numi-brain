import Foundation
import XCTest
import NumiBrainCore
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalMuscleBalanceSensorAdmissionTests: XCTestCase {
  private func topology(latency: UInt32 = 3_000) throws -> SensoryTopology {
    try SensoryTopology(
      modality: .vestibular,
      receptorCount: 1,
      observationDimension: 1,
      latencyMicroseconds: latency,
      adaptationTimeConstantMicroseconds: 10_000,
      noiseStandardDeviation: 0,
      activeSensingActionDimension: 0,
      enabled: true
    )
  }

  private func view(timestamp: UInt64) throws -> MetalRawSensorBufferView {
    try MetalRawSensorBufferView(
      modality: .vestibular,
      gpuAddress: 0x1000,
      byteCount: MemoryLayout<Float>.stride,
      receptorTimestamp: BrainTimestamp(microseconds: timestamp),
      receptorCount: 1,
      featureDimension: 1,
      validityGPUAddress: 0x2000,
      validityByteCount: MemoryLayout<UInt32>.stride
    )
  }

  func testAdmitsOnlyFrameWhoseLatencyLandsOnCommittedRoot() throws {
    let topology = try topology()
    let committed = BrainTimestamp(microseconds: 10_000)

    XCTAssertNoThrow(
      try MetalMuscleBalanceSensorAdmission.validate(
        view: try view(timestamp: 7_000),
        topology: topology,
        committedTimestamp: committed
      )
    )
    XCTAssertThrowsError(
      try MetalMuscleBalanceSensorAdmission.validate(
        view: try view(timestamp: 6_999),
        topology: topology,
        committedTimestamp: committed
      )
    )
    XCTAssertThrowsError(
      try MetalMuscleBalanceSensorAdmission.validate(
        view: try view(timestamp: 7_001),
        topology: topology,
        committedTimestamp: committed
      )
    )
  }

  func testRejectsMissingValidityAndTimestampUnderflow() throws {
    let topology = try topology()
    let missingValidity = try MetalRawSensorBufferView(
      modality: .vestibular,
      gpuAddress: 0x1000,
      byteCount: MemoryLayout<Float>.stride,
      receptorTimestamp: BrainTimestamp(microseconds: 0),
      receptorCount: 1,
      featureDimension: 1
    )

    XCTAssertThrowsError(
      try MetalMuscleBalanceSensorAdmission.validate(
        view: missingValidity,
        topology: topology,
        committedTimestamp: BrainTimestamp(microseconds: 10_000)
      )
    )
    XCTAssertThrowsError(
      try MetalMuscleBalanceSensorAdmission.validate(
        view: try view(timestamp: 0),
        topology: topology,
        committedTimestamp: BrainTimestamp(microseconds: 2_999)
      )
    )
  }
}

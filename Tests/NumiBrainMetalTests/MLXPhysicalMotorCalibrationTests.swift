import Foundation
import Metal
import XCTest
import NumiBrainCore
import NumiBrainMLX

@available(macOS 26.0, *)
final class MLXPhysicalMotorCalibrationTests: XCTestCase {
  override func setUpWithError() throws {
    guard let device = MTLCreateSystemDefaultDevice(), device.makeMTL4CommandQueue() != nil else {
      throw XCTSkip("Metal 4 unavailable")
    }
  }
  private func parent() throws -> BrainMotorStudyPublication {
    let compiled = try NumanXFullBodyTransportTemplate.compile(latencyMicroseconds: 100)
    return try BrainMotorStudyPublication(publication: BrainParameterPublication.developmentalSeedV1(
      species: compiled.species, tissueParameters: .corticalSheetV0))
  }
  func testProbeChangesOnlyDeclaredMotorCoordinate() throws {
    let parent = try parent()
    let probe = try MLXPhysicalMotorCalibration.probe(parent: parent, coordinate: 3, offset: 0.01)
    XCTAssertEqual(probe.version.parentFingerprint, parent.version.fingerprint)
    for kind in BrainSharedParameterArtifact.requiredKinds {
      let a = parent.sharedArtifact.payload(kind).data, b = probe.sharedArtifact.payload(kind).data
      if kind == .motor {
        XCTAssertEqual(a.prefix(12), b.prefix(12)); XCTAssertEqual(a.dropFirst(16), b.dropFirst(16))
        XCTAssertNotEqual(a, b)
      } else { XCTAssertEqual(a, b) }
    }
    XCTAssertEqual(try probe.unverifiedPublication.learnerUpdateFingerprint, 0)
  }
  func testProbesCannotChangeSafetyOrUnrelatedPolicyParameters() throws {
    let parent = try parent()
    for coordinate in [0, 1, 2, 5, 1000] {
      XCTAssertThrowsError(try MLXPhysicalMotorCalibration.probe(parent: parent, coordinate: coordinate, offset: 0.01))
    }
    XCTAssertThrowsError(try MLXPhysicalMotorCalibration.probe(parent: parent, coordinate: 3, offset: .nan))
    XCTAssertThrowsError(try MLXPhysicalMotorCalibration.probe(parent: parent, coordinate: 3, offset: 0.5))
  }
}

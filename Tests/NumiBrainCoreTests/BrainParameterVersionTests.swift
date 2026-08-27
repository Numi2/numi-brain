import Foundation
import NumiBrainABI
@testable import NumiBrainCore
import XCTest

final class BrainParameterVersionTests: XCTestCase {
  private func makeFoundation() throws -> (
    BrainModuleSchedule,
    RegionalTokenProgram,
    BrainParameterVersion
  ) {
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let program = try RegionalTokenProgram.runtimeFoundationV0(schedule: schedule)
    let version = try BrainParameterVersion.runtimeFoundationV0(
      schedule: schedule,
      regionalProgram: program,
      tissueParameters: .corticalSheetV0
    )
    return (schedule, program, version)
  }

  func testCompiledParameterManifestABIAndCanonicalFingerprint() throws {
    XCTAssertEqual(
      nb_brain_abi_parameter_component_size(),
      Int(NB_PARAMETER_COMPONENT_BYTE_COUNT)
    )
    XCTAssertEqual(
      nb_brain_abi_parameter_version_binding_size(),
      Int(NB_PARAMETER_VERSION_BINDING_BYTE_COUNT)
    )
    XCTAssertEqual(MemoryLayout<NBParameterComponent>.stride, 32)
    XCTAssertEqual(MemoryLayout<NBParameterVersionBinding>.stride, 64)

    let (_, program, version) = try makeFoundation()
    XCTAssertEqual(version.sequence, 0)
    XCTAssertEqual(version.parentFingerprint, 0)
    XCTAssertEqual(version.regionalShapeFingerprint, program.shapeFingerprint)
    XCTAssertEqual(version.regionalProgramFingerprint, program.fingerprint)
    XCTAssertEqual(version.components.map(\.kind), [.tissueDynamics, .regionalOperator])
    XCTAssertGreaterThan(version.totalParameterBytes, 0)

    var binding = version.abiBinding
    let records = version.components.map(\.abiRecord)
    let validation = records.withUnsafeBufferPointer { records in
      withUnsafePointer(to: &binding) { binding in
        nb_brain_abi_validate_parameter_version(binding, records.baseAddress)
      }
    }
    XCTAssertEqual(validation, UInt32(NB_PARAMETER_VERSION_VALID.rawValue))
    let recomputed = records.withUnsafeBufferPointer { records in
      withUnsafePointer(to: &binding) { binding in
        nb_brain_abi_parameter_version_fingerprint(binding, records.baseAddress)
      }
    }
    XCTAssertEqual(recomputed, version.fingerprint)

    let recanonicalized = try BrainParameterVersion(
      sequence: version.sequence,
      parentFingerprint: version.parentFingerprint,
      scheduleFingerprint: version.scheduleFingerprint,
      regionalShapeFingerprint: version.regionalShapeFingerprint,
      regionalProgramFingerprint: version.regionalProgramFingerprint,
      components: Array(version.components.reversed())
    )
    XCTAssertEqual(recanonicalized, version)
  }

  func testShapeFingerprintExcludesLearnedValuesButContentDoesNot() throws {
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let first = try RegionalTokenProgram.runtimeFoundationV0(schedule: schedule)
    var changed = first.parameters
    let old = changed[0]
    changed[0] = RegionalTokenParameters(
      recurrentGain: old.recurrentGain + 0.125,
      localGain: old.localGain,
      routeGain: old.routeGain,
      driveGain: old.driveGain,
      bias: old.bias,
      gateBias: old.gateBias,
      gateRecurrentGain: old.gateRecurrentGain,
      gateInputGain: old.gateInputGain
    )
    let second = try RegionalTokenProgram(
      schedule: schedule,
      routes: first.routes,
      parameters: changed,
      normalRouteBudgets: Dictionary(
        uniqueKeysWithValues: first.layouts.map {
          ($0.moduleIdentifier, $0.normalRouteBudget)
        }
      )
    )
    XCTAssertEqual(first.shapeFingerprint, second.shapeFingerprint)
    XCTAssertNotEqual(first.fingerprint, second.fingerprint)
  }

  func testVersionSerializationRejectsTamperedIdentity() throws {
    let (_, _, version) = try makeFoundation()
    let data = try JSONEncoder().encode(version)
    XCTAssertEqual(try JSONDecoder().decode(BrainParameterVersion.self, from: data), version)

    var text = try XCTUnwrap(String(data: data, encoding: .utf8))
    let original = "\"fingerprint\":\(version.fingerprint)"
    XCTAssertTrue(text.contains(original))
    text = text.replacingOccurrences(
      of: original,
      with: "\"fingerprint\":\(version.fingerprint &+ 1)"
    )
    XCTAssertThrowsError(
      try JSONDecoder().decode(
        BrainParameterVersion.self,
        from: try XCTUnwrap(text.data(using: .utf8))
      )
    )
  }

  func testRegistryPublishesOnlyAtSynchronizationBoundary() throws {
    let (_, _, version) = try makeFoundation()
    let registry = BrainParameterRegistry(initialVersion: version)
    let lease = try registry.beginCohort(expectedVersionFingerprint: version.fingerprint)

    var successorComponents = version.components
    let regionalIndex = try XCTUnwrap(
      successorComponents.firstIndex(where: { $0.kind == .regionalOperator })
    )
    let nextProgramFingerprint = version.regionalProgramFingerprint &+ 1
    let old = successorComponents[regionalIndex]
    successorComponents[regionalIndex] = try BrainParameterComponent(
      kind: old.kind,
      elementType: old.elementType,
      flags: old.flags,
      elementCount: old.elementCount,
      byteCount: old.byteCount,
      contentFingerprint: nextProgramFingerprint
    )
    let successor = try version.successor(
      regionalProgramFingerprint: nextProgramFingerprint,
      components: successorComponents
    )
    XCTAssertThrowsError(try registry.publish(successor))
    XCTAssertEqual(registry.currentVersion, version)

    try registry.endCohort(lease)
    try registry.publish(successor)
    XCTAssertEqual(registry.currentVersion, successor)
    XCTAssertEqual(successor.parentFingerprint, version.fingerprint)
    XCTAssertEqual(successor.sequence, 1)
    XCTAssertThrowsError(try registry.publish(successor))
    XCTAssertThrowsError(
      try registry.beginCohort(expectedVersionFingerprint: version.fingerprint)
    )
  }

  func testSchedulerCheckpointAndCohortBindParameterVersion() throws {
    let (schedule, _, version) = try makeFoundation()
    var first = CPUMultiRateScheduler(
      schedule: schedule,
      parameterVersionFingerprint: version.fingerprint
    )
    _ = try first.advance(to: BrainTimestamp(microseconds: 20_000))
    XCTAssertEqual(first.snapshot.parameterVersionFingerprint, version.fingerprint)
    XCTAssertThrowsError(
      try CPUMultiRateScheduler(
        schedule: schedule,
        parameterVersionFingerprint: version.fingerprint &+ 1,
        restoring: first.snapshot
      )
    )
    let restored = try CPUMultiRateScheduler(
      schedule: schedule,
      parameterVersionFingerprint: version.fingerprint,
      restoring: first.snapshot
    )
    XCTAssertEqual(restored.snapshot.stableHash(), first.snapshot.stableHash())

    let firstTransaction = try first.beginAdvance(to: BrainTimestamp(microseconds: 40_000))
    let other = CPUMultiRateScheduler(
      schedule: schedule,
      parameterVersionFingerprint: version.fingerprint &+ 1,
      initialTime: BrainTimestamp(microseconds: 20_000)
    )
    let otherTransaction = try other.beginAdvance(to: BrainTimestamp(microseconds: 40_000))
    XCTAssertThrowsError(
      try BrainSchedulerCohort.compact([
        BrainScheduledEnvironment(environmentIdentifier: 1, transaction: firstTransaction),
        BrainScheduledEnvironment(environmentIdentifier: 2, transaction: otherTransaction),
      ])
    )
  }
}

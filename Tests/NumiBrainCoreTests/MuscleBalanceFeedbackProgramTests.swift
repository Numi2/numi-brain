import Foundation
import XCTest
@testable import NumiBrainCore

final class MuscleBalanceFeedbackProgramTests: XCTestCase {
  private func fixture() throws -> CompiledSpeciesTemplate {
    let zero = try NumanXBodyLocalPoint(x: 0, y: 0, z: 0)
    let joints = try (UInt32(0)..<122).map { index in
      try NumanXJointTopology(
        jointIdentifier: index + 1,
        parentBodyIdentifier: index,
        childBodyIdentifier: index + 1,
        parentLocalAnchor: zero,
        childLocalAnchor: zero,
        restRelativeOrientation: .identity,
        coordinates: [
          .init(
            identifier: 0,
            kind: .angular,
            kinesthesiaReceptorIndex: index + 6,
            parentLocalAxis: .init(x: 1, y: 0, z: 0),
            minimumPosition: -1,
            maximumPosition: 1,
            restPosition: 0
          )
        ]
      )
    }
    let topology = try NumanXJointTopologyCatalog(
      numanXModelFingerprint: 123,
      bodyCount: 123,
      joints: joints
    )
    let attachments = try (UInt32(0)..<416).map {
      try NumanXMuscleAttachment(
        muscleIdentifier: $0,
        firstBodyIdentifier: 0,
        terminalBodyIdentifier: 1,
        routeNodeCount: 2,
        firstLocalPoint: zero,
        terminalLocalPoint: zero
      )
    }
    return try NumanXFullBodyTransportTemplate.compile(
      anatomy: .init(
        jointTopologyCatalog: topology,
        muscleAttachmentCatalog: .init(
          bodyCount: 123,
          attachments: attachments
        ),
        headBodyIdentifier: 1
      )
    )
  }

  private func locomotor(
    template: CompiledSpeciesTemplate
  ) -> MuscleLocomotorProgram {
    let channels = (UInt32(0)..<416).map {
      MuscleLocomotorChannel(
        muscleIdentifier: $0,
        referenceLengthMeters: 0.25,
        tonicExcitation: 0.03,
        lengthGain: 0.4,
        velocityGainSeconds: 0.02
      )
    }
    return MuscleLocomotorProgram(
      modelSourceFingerprint: 123,
      sensoryProfileFingerprint: template.sensoryProfile.fingerprint,
      calibrationArtifactSHA256: String(repeating: "a", count: 64),
      channels: channels
    )
  }

  func testProgramBindsExactBaselineAndPhysicalBodyReceptors() throws {
    let template = try fixture()
    let locomotor = locomotor(template: template)
    try locomotor.validate(template: template)
    let orientation = try XCTUnwrap(
      template.sensoryProfile.bodyReceptorBindings.first {
        $0.signal == .orientation && $0.component == 0
      }
    )
    let source = MuscleBalanceFeedbackSource(
      identifier: 1,
      bodyReceptorBindingIdentifier: orientation.identifier,
      referenceValue: 0,
      filterTimeConstantSeconds: 0.04,
      conductionDelayMicroseconds: 80_000
    )
    let route = MuscleBalanceFeedbackRoute(
      sourceIdentifier: 1,
      muscleIdentifier: 0,
      gain: -0.2,
      maximumCorrection: 0.1
    )
    func program(
      mode: MuscleBalanceFeedbackMode = .posture,
      baseline: UInt64? = nil,
      sensor: UInt64? = nil,
      sources: [MuscleBalanceFeedbackSource]? = nil,
      routes: [MuscleBalanceFeedbackRoute]? = nil
    ) -> MuscleBalanceFeedbackProgram {
      MuscleBalanceFeedbackProgram(
        locomotorProgramFingerprint: baseline ?? locomotor.fingerprint,
        modelSourceFingerprint: 123,
        sensoryProfileFingerprint: sensor ?? template.sensoryProfile.fingerprint,
        calibrationArtifactSHA256: String(repeating: "b", count: 64),
        mode: mode,
        updatePeriodMicroseconds: 4_000,
        initializationDurationMicroseconds: 100_000,
        sources: sources ?? [source],
        routes: routes ?? [route]
      )
    }

    let posture = program()
    try posture.validate(template: template, locomotorProgram: locomotor)
    XCTAssertEqual(
      posture,
      try JSONDecoder().decode(
        MuscleBalanceFeedbackProgram.self,
        from: JSONEncoder().encode(posture)
      )
    )
    XCTAssertNotEqual(
      posture.fingerprint,
      program(
        sources: [
          MuscleBalanceFeedbackSource(
            identifier: 1,
            bodyReceptorBindingIdentifier: orientation.identifier,
            referenceValue: 0.01,
            filterTimeConstantSeconds: 0.04,
            conductionDelayMicroseconds: 80_000
          )
        ]
      ).fingerprint
    )

    XCTAssertThrowsError(
      try program(mode: .supportAware).validate(
        template: template,
        locomotorProgram: locomotor
      )
    )
    XCTAssertThrowsError(
      try program(baseline: locomotor.fingerprint &+ 1).validate(
        template: template,
        locomotorProgram: locomotor
      )
    )
    XCTAssertThrowsError(
      try program(sensor: template.sensoryProfile.fingerprint &+ 1).validate(
        template: template,
        locomotorProgram: locomotor
      )
    )
    XCTAssertThrowsError(
      try program(
        sources: [
          MuscleBalanceFeedbackSource(
            identifier: 1,
            bodyReceptorBindingIdentifier: UInt32.max,
            referenceValue: 0
          )
        ]
      ).validate(template: template, locomotorProgram: locomotor)
    )
    XCTAssertThrowsError(
      try program(routes: [route, route]).validate(
        template: template,
        locomotorProgram: locomotor
      )
    )
    XCTAssertThrowsError(
      try program(
        routes: [
          MuscleBalanceFeedbackRoute(
            sourceIdentifier: 1,
            muscleIdentifier: 416,
            gain: 0.1
          )
        ]
      ).validate(template: template, locomotorProgram: locomotor)
    )
  }
}

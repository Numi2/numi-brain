import Foundation
import XCTest
@testable import NumiBrainCore

final class NumanXFullBodyBalanceTransportTests: XCTestCase {
  private func anatomy() throws -> NumanXFullBodyAnatomy {
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
    return try NumanXFullBodyAnatomy(
      jointTopologyCatalog: topology,
      muscleAttachmentCatalog: .init(
        bodyCount: 123,
        attachments: attachments
      ),
      headBodyIdentifier: 1
    )
  }

  private func locomotor(
    template: CompiledSpeciesTemplate
  ) -> MuscleLocomotorProgram {
    MuscleLocomotorProgram(
      modelSourceFingerprint: 123,
      sensoryProfileFingerprint: template.sensoryProfile.fingerprint,
      calibrationArtifactSHA256: String(repeating: "a", count: 64),
      channels: (UInt32(0)..<416).map {
        MuscleLocomotorChannel(
          muscleIdentifier: $0,
          referenceLengthMeters: 0.25,
          tonicExcitation: 0.03,
          lengthGain: 0.4,
          velocityGainSeconds: 0.02
        )
      }
    )
  }

  func testSupportBindingsAdmitSupportAwareFeedback() throws {
    let anatomy = try anatomy()
    let endpoints = [
      NumanXFullBodySupportEndpoint(
        sourceEndpointIdentifier: 0x5355_0001,
        bodyIdentifier: 121,
        touchReceptorIndex: 0
      ),
      NumanXFullBodySupportEndpoint(
        sourceEndpointIdentifier: 0x5355_0002,
        bodyIdentifier: 122,
        touchReceptorIndex: 1
      ),
    ]
    let template = try NumanXFullBodyTransportTemplate
      .compileWithSupportReceptors(
        anatomy: anatomy,
        supportEndpoints: endpoints
      )
    let support = template.sensoryProfile.bodyReceptorBindings.filter {
      $0.signal == .support
    }
    XCTAssertEqual(support.count, 2)
    XCTAssertEqual(support.map(\.bodyIdentifier), [121, 122])
    XCTAssertEqual(support.map(\.modality), [.touch, .touch])
    XCTAssertEqual(support.map(\.receptorIndex), [0, 1])
    XCTAssertEqual(support.map(\.featureIndex), [4, 4])
    XCTAssertTrue(support.allSatisfy { $0.sourceModelFingerprint == 123 })

    let locomotor = locomotor(template: template)
    let orientation = try XCTUnwrap(
      template.sensoryProfile.bodyReceptorBindings.first {
        $0.signal == .orientation && $0.component == 0
      }
    )
    let feedback = MuscleBalanceFeedbackProgram(
      locomotorProgramFingerprint: locomotor.fingerprint,
      modelSourceFingerprint: 123,
      sensoryProfileFingerprint: template.sensoryProfile.fingerprint,
      calibrationArtifactSHA256: String(repeating: "b", count: 64),
      mode: .supportAware,
      updatePeriodMicroseconds: 4_000,
      initializationDurationMicroseconds: 100_000,
      sources: [
        .init(
          identifier: 1,
          bodyReceptorBindingIdentifier: orientation.identifier,
          referenceValue: 0,
          filterTimeConstantSeconds: 0.04,
          conductionDelayMicroseconds: 80_000
        ),
        .init(
          identifier: 2,
          bodyReceptorBindingIdentifier: support[0].identifier,
          referenceValue: 350,
          filterTimeConstantSeconds: 0.02,
          conductionDelayMicroseconds: 40_000
        ),
      ],
      routes: [
        .init(
          sourceIdentifier: 1,
          muscleIdentifier: 0,
          gain: -0.2,
          maximumCorrection: 0.1
        ),
        .init(
          sourceIdentifier: 2,
          muscleIdentifier: 1,
          gain: 0.001,
          maximumCorrection: 0.1
        ),
      ]
    )
    XCTAssertNoThrow(
      try feedback.validate(
        template: template,
        locomotorProgram: locomotor
      )
    )
  }

  func testSupportEndpointValidationFailsClosed() throws {
    let anatomy = try anatomy()
    func endpoint(
      source: UInt64 = 0x5355_0001,
      body: UInt32 = 121,
      receptor: UInt32 = 0,
      scale: Float = 1
    ) -> NumanXFullBodySupportEndpoint {
      .init(
        sourceEndpointIdentifier: source,
        bodyIdentifier: body,
        touchReceptorIndex: receptor,
        scale: scale
      )
    }
    XCTAssertThrowsError(
      try NumanXFullBodyTransportTemplate.compileWithSupportReceptors(
        anatomy: anatomy,
        supportEndpoints: []
      )
    )
    XCTAssertThrowsError(
      try NumanXFullBodyTransportTemplate.compileWithSupportReceptors(
        anatomy: anatomy,
        supportEndpoints: [endpoint(), endpoint(source: 0x5355_0002)]
      )
    )
    XCTAssertThrowsError(
      try NumanXFullBodyTransportTemplate.compileWithSupportReceptors(
        anatomy: anatomy,
        supportEndpoints: [endpoint(body: 123)]
      )
    )
    XCTAssertThrowsError(
      try NumanXFullBodyTransportTemplate.compileWithSupportReceptors(
        anatomy: anatomy,
        supportEndpoints: [endpoint(receptor: 10)]
      )
    )
    XCTAssertThrowsError(
      try NumanXFullBodyTransportTemplate.compileWithSupportReceptors(
        anatomy: anatomy,
        supportEndpoints: [endpoint(scale: 0)]
      )
    )
  }
}

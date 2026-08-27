import Foundation
import XCTest

@testable import NumiBrainCore

final class CommittedBodyLoadFrameTests: XCTestCase {
  func testFrameCanonicalizesEndpointLoadsAndRetainsCommitProvenance() throws {
    let firstAttachment = try NumanXMuscleAttachment(
      muscleIdentifier: 10,
      firstBodyIdentifier: 4,
      terminalBodyIdentifier: 2,
      routeNodeCount: 3,
      firstLocalPoint: try NumanXBodyLocalPoint(x: 0.1, y: 0.2, z: 0.3),
      terminalLocalPoint: try NumanXBodyLocalPoint(x: 0.4, y: 0.5, z: 0.6)
    )
    let secondAttachment = try NumanXMuscleAttachment(
      muscleIdentifier: 11,
      firstBodyIdentifier: 2,
      terminalBodyIdentifier: 2,
      routeNodeCount: 2,
      firstLocalPoint: try NumanXBodyLocalPoint(x: 0.7, y: 0.8, z: 0.9),
      terminalLocalPoint: try NumanXBodyLocalPoint(x: 1, y: 1.1, z: 1.2)
    )
    let neighboringAttachment = try NumanXMuscleAttachment(
      muscleIdentifier: 12,
      firstBodyIdentifier: 4,
      terminalBodyIdentifier: 5,
      routeNodeCount: 2,
      firstLocalPoint: try NumanXBodyLocalPoint(x: 1.3, y: 1.4, z: 1.5),
      terminalLocalPoint: try NumanXBodyLocalPoint(x: 1.6, y: 1.7, z: 1.8)
    )
    let catalog = try NumanXMuscleAttachmentCatalog(
      bodyCount: 6,
      attachments: [firstAttachment, secondAttachment, neighboringAttachment]
    )
    let root = try BrainJointTransactionToken(
      environmentIdentifier: 7,
      episodeIdentifier: 8,
      controlStepIdentifier: 9,
      parameterVersionFingerprint: 10,
      baseBrainGeneration: 20,
      basePhysicsGeneration: 30,
      committedTimestamp: BrainTimestamp(microseconds: 0),
      targetTimestamp: BrainTimestamp(microseconds: 20_000),
      randomCounterGeneration: 40
    )
    var transaction = BrainJointTransaction(token: root)
    let transducer = try MuscleLoadReceptorTransducer(overloadThreshold: 1)
    var observations: [LocalizedMuscleLoadReceptorObservation] = []
    for (index, muscleIdentifier, force) in [(1, UInt32(10), Float(8)), (2, 11, 5)] {
      let substep = try transaction.beginPhysicsSubstep(durationMicroseconds: 10_000)
      let accepted = try AcceptedPhysicsStateToken(
        transaction: root,
        substep: substep,
        physicsStateFingerprint: UInt64(100 + index),
        physicsGeneration: UInt64(30 + index)
      )
      let observation = try XCTUnwrap(
        transducer.transduceLocalized(
          maximumAbsoluteMuscleForce: force,
          acceptedPhysicsState: accepted,
          muscleIdentifier: muscleIdentifier,
          attachmentCatalog: catalog
        )
      )
      try transaction.acceptPhysicsSubstep(
        accepted,
        for: substep,
        receptorEvents: [observation.event],
        localizedMuscleLoadObservations: [observation]
      )
      observations.append(observation)
    }
    let commit = try transaction.commit()
    let frame = try CommittedBodyLoadFrame(
      commit: commit,
      attachmentCatalog: catalog,
      observations: Array(observations.reversed())
    )

    XCTAssertEqual(frame.jointCommitFingerprint, commit.fingerprint)
    XCTAssertEqual(frame.committedTimestamp, BrainTimestamp(microseconds: 20_000))
    XCTAssertEqual(frame.brainGeneration, 21)
    XCTAssertEqual(frame.attachmentCatalogFingerprint, catalog.fingerprint)
    XCTAssertEqual(frame.bodyCount, 6)
    XCTAssertEqual(frame.affectedBodyIdentifiers, [2, 4])
    XCTAssertEqual(frame.maximumAbsoluteMuscleForce, 8)
    XCTAssertEqual(frame.samples.count, 3)
    XCTAssertEqual(frame.samples.map(\.bodyIdentifier), [2, 2, 4])
    XCTAssertEqual(frame.samples.map(\.sourceMuscleIdentifier), [10, 11, 10])
    XCTAssertEqual(frame.samples[0].endpointRole, .terminalRouteEndpoint)
    XCTAssertEqual(
      frame.samples[1].endpointRole,
      [.firstRouteEndpoint, .terminalRouteEndpoint]
    )
    XCTAssertEqual(frame.samples(forBodyIdentifier: 2).count, 2)
    XCTAssertTrue(frame.samples(forBodyIdentifier: 3).isEmpty)
    XCTAssertEqual(frame.peakBodyLoadCells.map(\.bodyIdentifier), [2, 4])
    XCTAssertEqual(frame.peakBodyLoadCells.map(\.sourceMuscleIdentifier), [10, 10])
    XCTAssertEqual(
      frame.peakBodyLoadCells.map(\.endpointRole),
      [.terminalRouteEndpoint, .firstRouteEndpoint]
    )
    XCTAssertEqual(
      try JSONDecoder().decode(
        CommittedBodyLoadFrame.self,
        from: JSONEncoder().encode(frame)
      ),
      frame
    )

    let dynamics = try BodyLoadFieldDynamics(
      persistenceMicroseconds: 10_000,
      decayMicroseconds: 20_000
    )
    let initialField = frame.peakBodyLoadCells
    XCTAssertEqual(
      initialField.map(\.fieldActivationTimestamp),
      [frame.committedTimestamp, frame.committedTimestamp]
    )
    let heldField = try dynamics.advance(
      previous: initialField,
      updates: [],
      bodyCount: frame.bodyCount,
      targetTimestamp: BrainTimestamp(microseconds: 30_000)
    )
    XCTAssertEqual(
      heldField.map(\.effectiveAbsoluteMuscleForce),
      initialField.map(\.maximumAbsoluteMuscleForce)
    )
    let halfDecayedField = try dynamics.advance(
      previous: heldField,
      updates: [],
      bodyCount: frame.bodyCount,
      targetTimestamp: BrainTimestamp(microseconds: 40_000)
    )
    XCTAssertEqual(
      halfDecayedField.map(\.effectiveAbsoluteMuscleForce),
      initialField.map { $0.maximumAbsoluteMuscleForce * 0.5 }
    )
    XCTAssertEqual(
      try dynamics.advance(
        previous: halfDecayedField,
        updates: [],
        bodyCount: frame.bodyCount,
        targetTimestamp: BrainTimestamp(microseconds: 50_000)
      ),
      []
    )

    var serialized = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(frame)) as? [String: Any]
    )
    serialized["fingerprint"] = 1
    XCTAssertThrowsError(
      try JSONDecoder().decode(
        CommittedBodyLoadFrame.self,
        from: JSONSerialization.data(withJSONObject: serialized)
      )
    )

    let mismatchedCatalog = try NumanXMuscleAttachmentCatalog(
      bodyCount: 6,
      attachments: [firstAttachment]
    )
    XCTAssertThrowsError(
      try CommittedBodyLoadFrame(
        commit: commit,
        attachmentCatalog: mismatchedCatalog,
        observations: observations
      )
    )

    let motorProfile = try ProtectiveMotorProfile(
      channels: [10, 11, 12].map {
        ProtectiveMuscleChannel(muscleIdentifier: $0, flags: [])
      }
    )
    let selection = try LocalizedProtectiveMuscleSelection(
      bodyLoadFrame: frame,
      attachmentCatalog: catalog,
      motorProfile: motorProfile
    )
    XCTAssertEqual(selection.selectedMuscleIdentifiers, [10, 11, 12])
    XCTAssertEqual(selection.overloadedSourceMuscleIdentifiers, [10, 11])
    XCTAssertEqual(selection.candidates[2].sharedBodyIdentifiers, [4])
    XCTAssertFalse(selection.candidates[2].flags.contains(.overloadedSource))
    XCTAssertEqual(selection.candidates[2].maximumObservedForce, 8)
    XCTAssertEqual(
      try JSONDecoder().decode(
        LocalizedProtectiveMuscleSelection.self,
        from: JSONEncoder().encode(selection)
      ),
      selection
    )
  }
}

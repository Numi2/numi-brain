import Foundation
import Metal
import XCTest

@testable import NumiBrainCore
@_spi(NumanXInterop) @testable import NumiBrainMetal
import NumiBrainMLX

@available(macOS 26.0, *)
final class MetalNumanXBridgeV1EndToEndTests: XCTestCase {
  func testGateBAcceptedDevelopmentEnablesAutonomousPhysicalGaze() throws {
    let paths = try bridgePaths()
    guard let device = MTLCreateSystemDefaultDevice(),
      device.makeMTL4CommandQueue() != nil,
      device.makeCommandAllocator() != nil,
      device.makeCommandBuffer() != nil
    else {
      throw XCTSkip("Metal 4 execution is unavailable")
    }
    let compiled = try makeNumanXFullBodyTransportCompiledTemplate()
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: compiled.species,
      tissueParameters: .corticalSheetV0
    )
    let capabilityCodes = compiled.species.development
      .dropFirst()
      .flatMap(\.capabilityGateCodes)
    XCTAssertEqual(capabilityCodes, Array(UInt64(1)...UInt64(11)))

    let immature = try runAcceptedScenario(
      paths: paths,
      contactPath: paths.contacts,
      compiled: compiled,
      publication: publication,
      device: device,
      rootCount: 7
    )
    let mature = try runAcceptedScenario(
      paths: paths,
      contactPath: paths.contacts,
      compiled: compiled,
      publication: publication,
      device: device,
      rootCount: 7,
      developmentalCapabilityCodes: capabilityCodes
    )
    let replay = try runAcceptedScenario(
      paths: paths,
      contactPath: paths.contacts,
      compiled: compiled,
      publication: publication,
      device: device,
      rootCount: 7,
      developmentalCapabilityCodes: capabilityCodes
    )
    XCTAssertEqual(immature.activeVisionCommands, [Float](repeating: 0, count: 7))
    XCTAssertEqual(mature.activeVisionCommands.count, 7)
    XCTAssertTrue(mature.activeVisionCommands.allSatisfy(\.isFinite))
    XCTAssertEqual(Array(mature.activeVisionCommands.prefix(6)), [Float](repeating: 0, count: 6))
    XCTAssertGreaterThan(abs(try XCTUnwrap(mature.activeVisionCommands.last)), 1.0e-6)
    XCTAssertGreaterThan(try XCTUnwrap(mature.activeVisionConfidences.last), 0)
    XCTAssertEqual(mature.activeVisionCommands, replay.activeVisionCommands)
    XCTAssertEqual(mature.activeVisionConfidences, replay.activeVisionConfidences)
    XCTAssertEqual(mature.sensorFingerprints, replay.sensorFingerprints)
    XCTAssertEqual(mature.finalSensorValuesByModality, replay.finalSensorValuesByModality)
    let visionDelta = maximumAbsoluteDelta(
      try XCTUnwrap(immature.finalSensorValuesByModality[.vision]),
      try XCTUnwrap(mature.finalSensorValuesByModality[.vision])
    )
    XCTAssertGreaterThan(visionDelta, 1.0e-6)
    if ProcessInfo.processInfo.environment["NUMANX_GATE_B_EVIDENCE"] == "1" {
      print(
        "gate_b_autonomous_gaze=pass command=\(try XCTUnwrap(mature.activeVisionCommands.last)) "
          + "confidence=\(try XCTUnwrap(mature.activeVisionConfidences.last)) "
          + "vision_delta=\(visionDelta) replay=byte_exact"
      )
    }
  }

  func testGateBRejectedDevelopmentDoesNotUnlockAutonomousGazeEarly() throws {
    let paths = try bridgePaths()
    guard let device = MTLCreateSystemDefaultDevice(),
      device.makeMTL4CommandQueue() != nil,
      device.makeCommandAllocator() != nil,
      device.makeCommandBuffer() != nil
    else {
      throw XCTSkip("Metal 4 execution is unavailable")
    }
    let compiled = try makeNumanXFullBodyTransportCompiledTemplate()
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: compiled.species,
      tissueParameters: .corticalSheetV0
    )
    let capabilityCodes = compiled.species.development
      .dropFirst()
      .flatMap(\.capabilityGateCodes)
    let parameters = TissueParameters.corticalSheetV0
    let brain = try MetalNumiBrainRuntime.makeRuntime(
      configuration: MetalNumiBrainConfiguration(
        initialTissueState: try CPUTissueDynamics.makeRestingGrid(
          width: 8, height: 8, parameters: parameters
        ),
        tissueParameters: parameters,
        tissueStimulus: .none,
        compiledSpeciesTemplate: compiled,
        randomContext: TissueRandomContext(
          seed: 0x4e55_4d49,
          environmentIdentifier: 0,
          episodeIdentifier: 1
        ),
        schedulerEnvironmentIdentifier: 0,
        maximumEncodedSubsteps: 1
      ),
      publication: publication,
      device: device
    )
    let native = try MetalNumanXBridgeV1Runtime(
      libraryPath: paths.library,
      device: device,
      configuration: .init(
        rigidPayloadPath: paths.rigid,
        musclePayloadPath: paths.muscle,
        supportContactPayloadPath: paths.contacts,
        visualPackPath: paths.visualPack,
        visionProfilePath: paths.visionProfile,
        metalRoboMetallibPath: paths.metalRoboMetallib,
        matterMetallibPath: paths.matterMetallib,
        matterMaterialPath: paths.material,
        timestepMicroseconds: 1_000,
        transactionSlotCount: 2
      )
    )
    var aggregate: MetalNumanXBridgeV1Runtime.AggregateSnapshot?
    var acceptedCommands: [Float] = []

    func transaction(_ controlStep: UInt64)
      throws -> MetalNumiBrainRuntime.ControlTransaction
    {
      try brain.beginControl(
        controlStepIdentifier: controlStep,
        basePhysicsGeneration: aggregate?.physicsGeneration ?? 0,
        committedTimestamp: BrainTimestamp(
          microseconds: controlStep * 1_000
        ),
        targetTimestamp: BrainTimestamp(
          microseconds: (controlStep + 1) * 1_000
        ),
        cachedDecisionFingerprint: 0x4e58_4742_524a_0000 | controlStep
      )
    }

    func sensors(
      for transaction: MetalNumiBrainRuntime.ControlTransaction
    ) throws -> NumanXSensorPacketLease {
      if let aggregate {
        return try aggregate.sensorPacket(
          for: transaction.token,
          compiledSpeciesTemplate: compiled
        )
      }
      return try bootstrapSensorPacket(
        device: device,
        compiled: compiled,
        transaction: transaction.token
      )
    }

    func accept(_ controlStep: UInt64) throws {
      let transaction = try transaction(controlStep)
      let published = try publishRoot(
        brain: brain,
        native: native,
        transaction: transaction,
        sensors: try sensors(for: transaction),
        device: device,
        developmentalCapabilityCodes: capabilityCodes
      )
      aggregate = published.aggregate
      acceptedCommands.append(published.activeVisionCommand)
    }

    for controlStep in UInt64(1)...UInt64(4) {
      try accept(controlStep)
    }
    XCTAssertEqual(acceptedCommands, [Float](repeating: 0, count: 4))

    // Encode all capability claims into the private developmental shadow, then
    // reject the exact physical root. None may become committed authority.
    let rejectedTransaction = try transaction(5)
    let rejected = try prepareRoot(
      brain: brain,
      native: native,
      transaction: rejectedTransaction,
      sensors: try sensors(for: rejectedTransaction),
      device: device,
      developmentalCapabilityCodes: capabilityCodes
    )
    XCTAssertEqual(rejected.activeVisionCommand, 0)
    XCTAssertTrue(rejected.physical.quarantineTimeout())
    let proposalLatch = AsyncResultLatch<MetalNumanXHumanMatterProposalLease>()
    try rejected.physical.submitTimeoutRejectProposal {
      proposalLatch.complete($0)
    }
    _ = try proposalLatch.wait()
    try rejected.physical.reserveTimeoutRejectApplication(
      brain: rejected.prepared
    )
    let applyLatch = AsyncResultLatch<MetalNumanXHumanMatterAppliedLease>()
    try rejected.physical.submitTimeoutRejectApply {
      applyLatch.complete($0)
    }
    XCTAssertEqual(
      try applyLatch.wait().commandDisposition,
      .rejectedReleased
    )
    XCTAssertTrue(rejected.physical.releaseRejected())
    try brain.abortNumanXPreparedControl(rejected.prepared)
    XCTAssertFalse(brain.hasOpenControl)
    XCTAssertEqual(brain.committedGeneration, 4)
    let afterReject = try XCTUnwrap(native.aggregateSnapshotIfAvailable())
    XCTAssertEqual(afterReject.brainGeneration, 4)
    XCTAssertEqual(afterReject.physicsGeneration, 4)
    aggregate = afterReject

    // If the rejected claims had advanced maturity, step 6 would already see
    // stage 6 and emit gaze. The retry and step 6 must remain silent; only the
    // next decision, after six accepted roots, may actuate the physical camera.
    try accept(5)
    try accept(6)
    XCTAssertEqual(Array(acceptedCommands.suffix(2)), [0, 0])
    try accept(7)
    let matureCommand = try XCTUnwrap(acceptedCommands.last)
    XCTAssertGreaterThan(abs(matureCommand), 1.0e-6)
    XCTAssertEqual(brain.committedGeneration, 7)
    XCTAssertEqual(aggregate?.physicsGeneration, 7)
    if ProcessInfo.processInfo.environment["NUMANX_GATE_B_EVIDENCE"] == "1" {
      print(
        "gate_b_rejected_development=pass committed_after_reject=4 "
          + "step6_command=0.0 step7_command=\(matureCommand)"
      )
    }
  }

  func testGateBMalformedDevelopmentalIntentCannotUnlockGaze() throws {
    let paths = try bridgePaths()
    guard let device = MTLCreateSystemDefaultDevice(),
      device.makeMTL4CommandQueue() != nil,
      device.makeCommandAllocator() != nil,
      device.makeCommandBuffer() != nil
    else {
      throw XCTSkip("Metal 4 execution is unavailable")
    }
    let compiled = try makeNumanXFullBodyTransportCompiledTemplate()
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: compiled.species,
      tissueParameters: .corticalSheetV0
    )
    let capabilityCodes = compiled.species.development
      .dropFirst()
      .flatMap(\.capabilityGateCodes)
    let malformed = try runAcceptedScenario(
      paths: paths,
      contactPath: paths.contacts,
      compiled: compiled,
      publication: publication,
      device: device,
      rootCount: 7,
      developmentalCapabilityCodes: capabilityCodes,
      developmentalIntentFingerprintXor: 1
    )
    XCTAssertEqual(malformed.activeVisionCommands, [Float](repeating: 0, count: 7))
    XCTAssertEqual(malformed.activeVisionConfidences, [Float](repeating: 0, count: 7))
    if ProcessInfo.processInfo.environment["NUMANX_GATE_B_EVIDENCE"] == "1" {
      print("gate_b_malformed_developmental_intent=pass gaze_locked=true")
    }
  }

  func testGateBAutonomousGazeImprovesPredeclaredVisualSearchCoverage() throws {
    let paths = try bridgePaths()
    guard let device = MTLCreateSystemDefaultDevice(),
      device.makeMTL4CommandQueue() != nil,
      device.makeCommandAllocator() != nil,
      device.makeCommandBuffer() != nil
    else {
      throw XCTSkip("Metal 4 execution is unavailable")
    }
    let compiled = try makeNumanXFullBodyTransportCompiledTemplate()
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: compiled.species,
      tissueParameters: .corticalSheetV0
    )
    let capabilityCodes = compiled.species.development
      .dropFirst()
      .flatMap(\.capabilityGateCodes)

    // Predeclared outcome: maximize physically valid RGB-D geometry coverage
    // in the seventh root. The ablation scales only the active-sensing record
    // to zero before the ordinary decision-ready proof hashes it.
    let intact = try runAcceptedScenario(
      paths: paths,
      contactPath: paths.contacts,
      compiled: compiled,
      publication: publication,
      device: device,
      rootCount: 7,
      developmentalCapabilityCodes: capabilityCodes
    )
    let ablated = try runAcceptedScenario(
      paths: paths,
      contactPath: paths.contacts,
      compiled: compiled,
      publication: publication,
      device: device,
      rootCount: 7,
      developmentalCapabilityCodes: capabilityCodes,
      activeSensingCommandScale: 0
    )
    XCTAssertGreaterThan(abs(try XCTUnwrap(intact.activeVisionCommands.last)), 0)
    XCTAssertEqual(ablated.activeVisionCommands, [Float](repeating: 0, count: 7))
    XCTAssertEqual(ablated.activeVisionConfidences, [Float](repeating: 0, count: 7))
    XCTAssertEqual(
      intact.motorExcitationsByGeneration,
      ablated.motorExcitationsByGeneration
    )
    XCTAssertEqual(
      intact.descendingSomaticByGeneration,
      ablated.descendingSomaticByGeneration
    )
    XCTAssertEqual(
      Array(intact.visionDepthValidCounts.prefix(6)),
      Array(ablated.visionDepthValidCounts.prefix(6))
    )
    XCTAssertEqual(
      Array(intact.visionGeometryValidCounts.prefix(6)),
      Array(ablated.visionGeometryValidCounts.prefix(6))
    )
    let intactDepth = try XCTUnwrap(intact.visionDepthValidCounts.last)
    let ablatedDepth = try XCTUnwrap(ablated.visionDepthValidCounts.last)
    let intactGeometry = try XCTUnwrap(intact.visionGeometryValidCounts.last)
    let ablatedGeometry = try XCTUnwrap(ablated.visionGeometryValidCounts.last)
    XCTAssertGreaterThan(intactDepth, ablatedDepth)
    XCTAssertGreaterThan(intactGeometry, ablatedGeometry)
    for modality in compiled.species.senses.map(\.modality) where modality != .vision {
      XCTAssertEqual(
        intact.finalSensorValuesByModality[modality],
        ablated.finalSensorValuesByModality[modality],
        "active-gaze command ablation perturbed nonvisual \(modality)"
      )
    }
    if ProcessInfo.processInfo.environment["NUMANX_GATE_B_EVIDENCE"] == "1" {
      print(
        "gate_b_gaze_search_benefit=pass depth=\(ablatedDepth)->\(intactDepth) "
          + "geometry=\(ablatedGeometry)->\(intactGeometry) "
          + "nonvisual=byte_exact"
      )
    }
  }

  func testGateBExternalTaskOptionAdmission() throws {
    let paths = try bridgePaths()
    guard let device = MTLCreateSystemDefaultDevice(),
      device.makeMTL4CommandQueue() != nil,
      device.makeCommandAllocator() != nil,
      device.makeCommandBuffer() != nil
    else {
      throw XCTSkip("Metal 4 execution is unavailable")
    }
    let compiled = try makeNumanXFullBodyTransportCompiledTemplate()
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: compiled.species,
      tissueParameters: .corticalSheetV0
    )
    let heldoutTilt = try tiltedSupportContactAsset(
      sourcePath: paths.contacts, degrees: 0.1
    )
    defer { try? FileManager.default.removeItem(at: heldoutTilt) }
    var target = [Float](repeating: 0, count: 16)
    target[12] = 0.05
    target[13] = 0.05
    target[14] = 0.05
    let scenario = try runAcceptedScenario(
      paths: paths, contactPath: heldoutTilt.path,
      compiled: compiled, publication: publication,
      device: device, rootCount: 3,
      externalGoal: { controlStep in
        try self.supportStabilityGoal(target: target, controlStep: controlStep)
      }
    )
    let accepted = try acceptedTransitionEvidence(scenario.batch)
    XCTAssertEqual(accepted.count, 3)
    XCTAssertTrue(accepted.allSatisfy { $0.activeGoalIdentifier != 0 })
    XCTAssertTrue(accepted.allSatisfy { $0.activeOptionIdentifier >> 60 == 0x6 })
    XCTAssertTrue(accepted.allSatisfy { $0.damageCVaR <= 1 })
    XCTAssertTrue(accepted.allSatisfy { ($0.actions.map(abs).max() ?? 0) > 0 })
    XCTAssertGreaterThan(
      scenario.descendingSomaticByGeneration.dropFirst().flatMap { $0 }
        .map(abs).max() ?? 0,
      1.0e-6
    )
    let evidence = try XCTUnwrap(accepted.last)
    if ProcessInfo.processInfo.environment["NUMANX_GATE_B_EVIDENCE"] == "1" {
      let descending = try XCTUnwrap(
        scenario.descendingSomaticByGeneration.last
      )
      let groupMaxima = (0..<16).map { synergy in
        stride(from: synergy, to: descending.count, by: 16)
          .map { descending[$0] }.max() ?? 0
      }
      print(
        "GateB external-task admission goal=\(evidence.activeGoalIdentifier) "
          + "option=\(evidence.activeOptionIdentifier) "
          + "score=\(evidence.selectedScore) damage=\(evidence.damageCVaR) "
          + "actions=\(evidence.actions) "
          + "descendingGroupMaxima=\(groupMaxima)"
      )
    }
  }

  func testZZGateBHeldOutSupportTiltPolicyInterventions() throws {
    guard ProcessInfo.processInfo.environment["NUMANX_GATE_B_EVIDENCE"] == "1"
    else {
      throw XCTSkip(
        "the Gate B causal cohort is an explicit isolated qualification"
      )
    }
    let paths = try bridgePaths()
    guard let device = MTLCreateSystemDefaultDevice(),
      device.makeMTL4CommandQueue() != nil,
      device.makeCommandAllocator() != nil,
      device.makeCommandBuffer() != nil
    else {
      throw XCTSkip("Metal 4 execution is unavailable")
    }
    let compiled = try makeNumanXFullBodyTransportCompiledTemplate()
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: compiled.species,
      tissueParameters: .corticalSheetV0
    )
    let negativeTilt = try tiltedSupportContactAsset(
      sourcePath: paths.contacts, degrees: -2
    )
    let positiveTilt = try tiltedSupportContactAsset(
      sourcePath: paths.contacts, degrees: 2
    )
    let heldoutTilt = try tiltedSupportContactAsset(
      sourcePath: paths.contacts, degrees: 1
    )
    defer {
      try? FileManager.default.removeItem(at: negativeTilt)
      try? FileManager.default.removeItem(at: positiveTilt)
      try? FileManager.default.removeItem(at: heldoutTilt)
    }
    let negativeScenario = try runAcceptedScenario(
      paths: paths, contactPath: negativeTilt.path,
      compiled: compiled, publication: publication,
      device: device, rootCount: 9
    )
    let positiveScenario = try runAcceptedScenario(
      paths: paths, contactPath: positiveTilt.path,
      compiled: compiled, publication: publication,
      device: device, rootCount: 9
    )
    let cohort = try MetalLearningCohortBatch(members: [
      try MetalLearningCohortMember(
        mindIdentifier: 0x4e58_4742_0000_0001, batch: negativeScenario.batch
      ),
      try MetalLearningCohortMember(
        mindIdentifier: 0x4e58_4742_0000_0002, batch: positiveScenario.batch
      ),
    ])
    let negativeEvidence = try acceptedTransitionEvidence(negativeScenario.batch)
    let positiveEvidence = try acceptedTransitionEvidence(positiveScenario.batch)
    XCTAssertEqual(negativeEvidence.count, 9)
    XCTAssertEqual(positiveEvidence.count, 9)
    let cohortObservationDelta = maximumAbsoluteDelta(
      negativeEvidence.flatMap(\.observations),
      positiveEvidence.flatMap(\.observations)
    )
    let cohortActionDelta = maximumAbsoluteDelta(
      negativeEvidence.flatMap(\.actions),
      positiveEvidence.flatMap(\.actions)
    )
    let cohortSensorDelta = maximumAbsoluteDelta(
      negativeScenario.finalSensorValues,
      positiveScenario.finalSensorValues
    )
    let modalitySensorDeltas = Dictionary(uniqueKeysWithValues:
      negativeScenario.finalSensorValuesByModality.keys.map { modality in
        (
          modality,
          maximumAbsoluteDelta(
            negativeScenario.finalSensorValuesByModality[modality] ?? [],
            positiveScenario.finalSensorValuesByModality[modality] ?? []
          )
        )
      }
    )
    let firstSensorDivergence = Array(zip(
      negativeScenario.sensorFingerprints,
      positiveScenario.sensorFingerprints
    )).firstIndex { pair in pair.0 != pair.1 }.map { $0 + 1 }
    let firstCandidateSensorDivergence = Array(zip(
      negativeScenario.candidateSensorFingerprints,
      positiveScenario.candidateSensorFingerprints
    )).firstIndex { pair in pair.0 != pair.1 }.map { $0 + 1 }
    let foundationLearner = MLXBrainLearnerConfiguration.foundationV1
    let learner = MLXBrainLearner(configuration: try MLXBrainLearnerConfiguration(
      learningRate: 0.01,
      gradientNormLimit: foundationLearner.gradientNormLimit,
      parameterMagnitudeLimit: foundationLearner.parameterMagnitudeLimit,
      lossWeights: foundationLearner.lossWeights
    ))
    let update = try learner.update(
      parentPublication: publication, cohort: cohort
    )
    XCTAssertEqual(
      try learner.update(
        parentPublication: publication, cohort: cohort
      ),
      update
    )
    let successor = try BrainParameterPublication(
      parentVersion: publication.version,
      learnerUpdate: update
    )
    // External-task coordinates are the same structured motor-goal basis used
    // by Metal: zero relative displacement/velocity/force with bounded
    // postural stiffness on three independent synergy axes.
    var stableTaskTarget = [Float](repeating: 0, count: 16)
    stableTaskTarget[12] = 0.05
    stableTaskTarget[13] = 0.05
    stableTaskTarget[14] = 0.05
    XCTAssertEqual(stableTaskTarget.count, 16)
    let taskGoal: (UInt64) throws -> ActiveGoal = { controlStep in
      try self.supportStabilityGoal(
        target: stableTaskTarget, controlStep: controlStep
      )
    }
    let heldoutScenario = try runAcceptedScenario(
      paths: paths, contactPath: heldoutTilt.path,
      compiled: compiled, publication: publication,
      device: device, rootCount: 11
    )
    let taskParentScenario = try runAcceptedScenario(
      paths: paths, contactPath: heldoutTilt.path,
      compiled: compiled, publication: publication,
      device: device, rootCount: 3,
      externalGoal: taskGoal
    )
    let taskLearnedScenario = try runAcceptedScenario(
      paths: paths, contactPath: heldoutTilt.path,
      compiled: compiled, publication: successor,
      device: device, rootCount: 3,
      externalGoal: taskGoal
    )
    let selectedIntervention: (
      modality: SensoryModality,
      intervention: ClosedLoopSensorIntervention,
      outcomeModality: SensoryModality,
      label: String
    ) = switch ProcessInfo.processInfo.environment[
      "NUMANX_GATE_B_INTERVENTION_MODALITY"
    ] ?? "audition" {
    case "audition": (
      .audition, .scaled(.audition, 0.9), .vestibular, "scaled0.9"
    )
    case "vestibular": (
      .vestibular, .ablated(.vestibular), .vestibular, "ablated"
    )
    case "touch": (.touch, .ablated(.touch), .touch, "ablated")
    case "proprioception": (
      .proprioception,
      .ablated(.proprioception),
      .proprioception,
      "ablated"
    )
    case "interoception": (
      .interoception,
      .ablated(.interoception),
      .vestibular,
      "ablated"
    )
    case "kinesthesia": (
      .kinesthesia,
      .ablated(.kinesthesia),
      .kinesthesia,
      "ablated"
    )
    case "vision": (.vision, .ablated(.vision), .vestibular, "ablated")
    case let name:
      throw TissueError.transaction(
        "unsupported Gate B closed-loop intervention modality \(name)"
      )
    }
    let taskIntervenedScenario = try runAcceptedScenario(
      paths: paths, contactPath: heldoutTilt.path,
      compiled: compiled, publication: successor,
      device: device, rootCount: 3,
      externalGoal: taskGoal,
      sensorIntervention: selectedIntervention.intervention
    )
    let taskParentEvidence = try acceptedTransitionEvidence(
      taskParentScenario.batch
    )
    let taskLearnedEvidence = try acceptedTransitionEvidence(
      taskLearnedScenario.batch
    )
    let taskActionDelta = maximumAbsoluteDelta(
      taskParentEvidence.flatMap(\.actions),
      taskLearnedEvidence.flatMap(\.actions)
    )
    let taskSensorDelta = maximumAbsoluteDelta(
      taskParentScenario.finalSensorValues,
      taskLearnedScenario.finalSensorValues
    )
    let taskIntervenedEvidence = try acceptedTransitionEvidence(
      taskIntervenedScenario.batch
    )
    let interventionActionDelta = maximumAbsoluteDelta(
      taskLearnedEvidence.flatMap(\.actions),
      taskIntervenedEvidence.flatMap(\.actions)
    )
    let interventionPhysicalDelta = maximumAbsoluteDelta(
      taskLearnedScenario.finalSensorValues,
      taskIntervenedScenario.finalSensorValues
    )
    let interventionPhysicalDeltas = Dictionary(uniqueKeysWithValues:
      taskLearnedScenario.finalSensorValuesByModality.keys.map { modality in
        (
          modality,
          maximumAbsoluteDelta(
            taskLearnedScenario.finalSensorValuesByModality[modality] ?? [],
            taskIntervenedScenario
              .finalSensorValuesByModality[modality] ?? []
          )
        )
      }
    )
    let interventionMotorDelta = maximumAbsoluteDelta(
      taskLearnedScenario.motorExcitationsByGeneration.flatMap { $0 },
      taskIntervenedScenario.motorExcitationsByGeneration.flatMap { $0 }
    )
    let interventionDescendingDelta = maximumAbsoluteDelta(
      taskLearnedScenario.descendingSomaticByGeneration.flatMap { $0 },
      taskIntervenedScenario.descendingSomaticByGeneration.flatMap { $0 }
    )
    let intactTaskDrift = modalityDriftCost(
      taskLearnedScenario, modality: selectedIntervention.outcomeModality
    )
    let interventionTaskDrift = modalityDriftCost(
      taskIntervenedScenario, modality: selectedIntervention.outcomeModality
    )
    let learnedHeldoutScenario = try runAcceptedScenario(
      paths: paths, contactPath: heldoutTilt.path,
      compiled: compiled, publication: successor,
      device: device, rootCount: 11
    )
    let heldoutEvidence = try acceptedTransitionEvidence(heldoutScenario.batch)
    let learnedHeldoutEvidence = try acceptedTransitionEvidence(
      learnedHeldoutScenario.batch
    )
    let learnedClosedLoopActionDelta = maximumAbsoluteDelta(
      heldoutEvidence.flatMap(\.actions),
      learnedHeldoutEvidence.flatMap(\.actions)
    )
    let learnedClosedLoopSensorDelta = maximumAbsoluteDelta(
      heldoutScenario.finalSensorValues,
      learnedHeldoutScenario.finalSensorValues
    )
    let learnedClosedLoopPhysicsChanged = zip(
      heldoutEvidence, learnedHeldoutEvidence
    ).contains {
      $0.physicsStateFingerprint != $1.physicsStateFingerprint
    }
    let evaluator = MLXGateBCausalEvaluator()
    var evaluations: [NumanXGateBPolicyHeadEvaluation] = []
    for modality in compiled.species.senses.filter(\.enabled).map(\.modality) {
      let first = try evaluator.evaluate(
        publication: successor,
        batch: heldoutScenario.batch,
        species: compiled.species,
        modality: modality,
        minimumGeneration: 10,
        maximumGeneration: 11,
        shuffleSeed: 0x4e58_4742_5449_4c54
      )
      XCTAssertEqual(
        try evaluator.evaluate(
          publication: successor,
          batch: heldoutScenario.batch,
          species: compiled.species,
          modality: modality,
          minimumGeneration: 10,
          maximumGeneration: 11,
          shuffleSeed: 0x4e58_4742_5449_4c54
        ),
        first
      )
      evaluations.append(contentsOf: first)
    }
    XCTAssertEqual(evaluations.count, 28)
    XCTAssertEqual(firstSensorDivergence, 1)
    XCTAssertEqual(firstCandidateSensorDivergence, 1)
    XCTAssertGreaterThan(cohortSensorDelta, 0)
    XCTAssertGreaterThan(cohortObservationDelta, 0)
    XCTAssertEqual(cohortActionDelta, 0)
    XCTAssertTrue(taskParentEvidence.allSatisfy {
      $0.activeOptionIdentifier >> 60 == 0x6
        && ($0.actions.map(abs).max() ?? 0) > 0
    })
    XCTAssertTrue(taskLearnedEvidence.allSatisfy {
      $0.activeOptionIdentifier >> 60 == 0x6
        && ($0.actions.map(abs).max() ?? 0) > 0
    })
    XCTAssertEqual(taskIntervenedEvidence.count, 3)
    XCTAssertEqual(
      taskIntervenedEvidence.map(\.activeGoalIdentifier),
      taskLearnedEvidence.map(\.activeGoalIdentifier)
    )
    XCTAssertEqual(
      taskIntervenedEvidence.map(\.activeOptionIdentifier),
      taskLearnedEvidence.map(\.activeOptionIdentifier)
    )
    XCTAssertGreaterThan(taskActionDelta, 0)
    XCTAssertGreaterThan(taskSensorDelta, 0)
    XCTAssertGreaterThan(interventionActionDelta, 1.0e-7)
    XCTAssertGreaterThan(interventionDescendingDelta, 1.0e-8)
    XCTAssertGreaterThan(interventionMotorDelta, 1.0e-8)
    XCTAssertGreaterThan(interventionPhysicalDelta, 1.0e-8)
    XCTAssertGreaterThan(
      interventionTaskDrift,
      intactTaskDrift + 1.0e-4
    )
    XCTAssertTrue(interventionPhysicalDeltas.contains {
      $0.key != selectedIntervention.modality && $0.value > 1.0e-8
    })
    XCTAssertTrue(evaluations.filter {
      $0.intervention == .intact
    }.allSatisfy { $0.actionDeltaFromIntact == 0 })
    XCTAssertTrue(evaluations.contains {
      $0.intervention == .valueShuffled && $0.actionDeltaFromIntact > 0
    })
    XCTAssertTrue(evaluations.contains {
      $0.intervention == .timestampShifted && $0.actionDeltaFromIntact > 0
    })
    XCTAssertEqual(
      Set(evaluations.filter {
        $0.intervention == .ablated && $0.actionDeltaFromIntact > 0
      }.map(\.modality)),
      Set(compiled.species.senses.filter(\.enabled).map(\.modality))
    )
    if ProcessInfo.processInfo.environment["NUMANX_GATE_B_EVIDENCE"] == "1" {
      let firstSensorDivergenceDescription = firstSensorDivergence.map {
        String($0)
      } ?? "none"
      let firstCandidateSensorDivergenceDescription =
        firstCandidateSensorDivergence.map { String($0) } ?? "none"
      print(
        "GateB tilted cohort physicalFingerprintsDiffer="
          + "\(zip(negativeEvidence, positiveEvidence).contains { $0.physicsStateFingerprint != $1.physicsStateFingerprint }) "
          + "sensorMaxDelta=\(cohortSensorDelta) "
          + "firstSensorDivergence=\(firstSensorDivergenceDescription) "
          + "firstCandidateSensorDivergence="
          + "\(firstCandidateSensorDivergenceDescription) "
          + "observationMaxDelta=\(cohortObservationDelta) "
          + "actionMaxDelta=\(cohortActionDelta)"
      )
      print(
        "GateB learned heldout physicalFingerprintsDiffer="
          + "\(learnedClosedLoopPhysicsChanged) "
          + "sensorMaxDelta=\(learnedClosedLoopSensorDelta) "
          + "actionMaxDelta=\(learnedClosedLoopActionDelta)"
      )
      print(
        "GateB task heldout sensorMaxDelta=\(taskSensorDelta) "
          + "actionMaxDelta=\(taskActionDelta) "
          + "parentGoalOptions=\(taskParentEvidence.map { "\($0.activeGoalIdentifier):\($0.activeOptionIdentifier)" }) "
          + "learnedGoalOptions=\(taskLearnedEvidence.map { "\($0.activeGoalIdentifier):\($0.activeOptionIdentifier)" })"
      )
      print(
        "GateB task closed-loop modality=\(selectedIntervention.modality) "
          + "intervention=\(selectedIntervention.label) "
          + "actionMaxDelta=\(interventionActionDelta) "
          + "descendingMaxDelta=\(interventionDescendingDelta) "
          + "motorMaxDelta=\(interventionMotorDelta) "
          + "intactMotorMax=\(taskLearnedScenario.motorExcitationsByGeneration.flatMap { $0 }.max() ?? .nan) "
          + "intervenedMotorMax=\(taskIntervenedScenario.motorExcitationsByGeneration.flatMap { $0 }.max() ?? .nan) "
          + "physicalSensorMaxDelta=\(interventionPhysicalDelta) "
          + "outcomeModality=\(selectedIntervention.outcomeModality) "
          + "intactDrift=\(intactTaskDrift) "
          + "intervenedDrift=\(interventionTaskDrift)"
      )
      for modality in interventionPhysicalDeltas.keys.sorted(by: {
        $0.rawValue < $1.rawValue
      }) {
        print(
          "GateB task intervention=\(selectedIntervention.modality) "
            + "physical modality=\(modality) "
            + "maxDelta=\(interventionPhysicalDeltas[modality] ?? .infinity)"
        )
      }
      for modality in modalitySensorDeltas.keys.sorted(by: {
        $0.rawValue < $1.rawValue
      }) {
        print(
          "GateB tilted sensor modality=\(modality) "
            + "maxDelta=\(modalitySensorDeltas[modality] ?? .infinity)"
        )
      }
      for result in evaluations.sorted(by: {
        ($0.modality.rawValue, $0.intervention.rawValue)
          < ($1.modality.rawValue, $1.intervention.rawValue)
      }) {
        print(
          "GateB tilted policy-head modality=\(result.modality) "
            + "intervention=\(result.intervention) "
            + "mse=\(result.actionMeanSquaredError) "
            + "delta=\(result.actionDeltaFromIntact)"
        )
      }
    }
  }

  private struct AcceptedTransitionEvidence {
    let generation: UInt64
    let physicsStateFingerprint: UInt64
    let activeGoalIdentifier: UInt64
    let activeOptionIdentifier: UInt64
    let selectedScore: Float
    let damageCVaR: Float
    let posteriorState: [Float]
    let observations: [Float]
    let actions: [Float]
  }

  private func acceptedTransitionEvidence(
    _ batch: MetalLearningBatch
  ) throws -> [AcceptedTransitionEvidence] {
    let lease = try batch.makeSharedStorageLease()
    var result: [AcceptedTransitionEvidence] = []
    for index in 0..<batch.transitionCapacity {
      let record = lease.baseAddress.advanced(
        by: index * batch.transitionStride
      )
      let identifier = record.load(as: UInt64.self)
      let generation = record.advanced(by: 32).load(as: UInt64.self)
      let format = record.advanced(by: 64).load(as: UInt32.self)
      let flags = record.advanced(by: 68).load(as: UInt32.self)
      guard identifier > 0, generation > 0,
        format == MetalLearningBatch.transitionRecordVersion,
        (flags & 1) == 1
      else { continue }
      let observations = Array(
        UnsafeBufferPointer(
          start: record.advanced(by: 320).assumingMemoryBound(to: Float.self),
          count: 24
        )
      )
      let posteriorState = Array(
        UnsafeBufferPointer(
          start: record.advanced(by: 224).assumingMemoryBound(to: Float.self),
          count: 24
        )
      )
      let actions = Array(
        UnsafeBufferPointer(
          start: record.advanced(by: 416).assumingMemoryBound(to: Float.self),
          count: 16
        )
      )
      result.append(AcceptedTransitionEvidence(
        generation: generation,
        physicsStateFingerprint: record.advanced(by: 40).load(as: UInt64.self),
        activeGoalIdentifier: record.advanced(by: 48).load(as: UInt64.self),
        activeOptionIdentifier: record.advanced(by: 56).load(as: UInt64.self),
        selectedScore: record.advanced(by: 96).load(as: Float.self),
        damageCVaR: record.advanced(by: 100).load(as: Float.self),
        posteriorState: posteriorState,
        observations: observations,
        actions: actions
      ))
    }
    return result.sorted { $0.generation < $1.generation }
  }

  private func maximumAbsoluteDelta(
    _ lhs: [Float], _ rhs: [Float]
  ) -> Float {
    guard lhs.count == rhs.count else { return .infinity }
    return zip(lhs, rhs).reduce(Float(0)) {
      max($0, abs($1.0 - $1.1))
    }
  }

  func testRealFullBodyBrainProposalApplyAndJointPublication() throws {
    let paths = try bridgePaths()
    guard let device = MTLCreateSystemDefaultDevice(),
      device.makeMTL4CommandQueue() != nil,
      device.makeCommandAllocator() != nil,
      device.makeCommandBuffer() != nil
    else {
      throw XCTSkip("Metal 4 execution is unavailable")
    }
    let parameters = TissueParameters.corticalSheetV0
    let compiled = try makeNumanXFullBodyTransportCompiledTemplate()
    XCTAssertEqual(compiled.species.activeSensingChannels.count, 1)
    XCTAssertEqual(
      compiled.species.activeSensingChannels.first?.modality, .vision
    )
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: compiled.species,
      tissueParameters: parameters
    )
    let initial = try CPUTissueDynamics.makeRestingGrid(
      width: 8,
      height: 8,
      parameters: parameters
    )
    let brainConfiguration = MetalNumiBrainConfiguration(
      initialTissueState: initial,
      tissueParameters: parameters,
      tissueStimulus: .none,
      compiledSpeciesTemplate: compiled,
      randomContext: TissueRandomContext(
        seed: 0x4e55_4d49,
        environmentIdentifier: 0,
        episodeIdentifier: 1
      ),
      schedulerEnvironmentIdentifier: 0,
      maximumEncodedSubsteps: 1
    )
    let brain = try MetalNumiBrainRuntime.makeRuntime(
      configuration: brainConfiguration,
      publication: publication,
      device: device
    )
    let native = try MetalNumanXBridgeV1Runtime(
      libraryPath: paths.library,
      device: device,
      configuration: .init(
        rigidPayloadPath: paths.rigid,
        musclePayloadPath: paths.muscle,
        supportContactPayloadPath: paths.contacts,
        visualPackPath: paths.visualPack,
        visionProfilePath: paths.visionProfile,
        metalRoboMetallibPath: paths.metalRoboMetallib,
        matterMetallibPath: paths.matterMetallib,
        matterMaterialPath: paths.material,
        timestepMicroseconds: 1_000,
        transactionSlotCount: 2
      )
    )
    XCTAssertEqual(native.info.bodyCount, 157)
    XCTAssertEqual(native.info.qCoordinateCount, 129)
    XCTAssertEqual(native.info.dofCount, 128)
    XCTAssertEqual(native.info.muscleCount, 416)
    XCTAssertEqual(native.info.residentContinuationCount, 0)
    XCTAssertNil(try native.aggregateSnapshotIfAvailable())

    let transaction = try brain.beginControl(
      controlStepIdentifier: 1,
      basePhysicsGeneration: 0,
      committedTimestamp: BrainTimestamp(microseconds: 1_000),
      targetTimestamp: BrainTimestamp(microseconds: 2_000),
      cachedDecisionFingerprint: 0x4e58_4445_4349_5349
    )
    // Generation zero is the canonical first deterministic random stream; it
    // is an authenticated value, not an absent identity.
    XCTAssertEqual(transaction.token.randomCounterGeneration, 0)
    let initialSensors = try bootstrapSensorPacket(
      device: device,
      compiled: compiled,
      transaction: transaction.token
    )
    let first = try publishRoot(
      brain: brain,
      native: native,
      transaction: transaction,
      sensors: initialSensors,
      device: device
    )
    let physical = first.physical
    let aggregate = first.aggregate
    XCTAssertEqual(aggregate.publicationEpoch, 1)
    XCTAssertEqual(aggregate.brainGeneration, brain.committedGeneration)
    XCTAssertEqual(aggregate.physicsGeneration, 1)
    XCTAssertEqual(aggregate.sensorGeneration, 1)
    XCTAssertEqual(aggregate.identity, physical.identity)
    XCTAssertEqual(aggregate.proprioception.receptorCount, 416)
    XCTAssertEqual(aggregate.proprioception.featureDimension, 10)
    XCTAssertEqual(aggregate.interoception.receptorCount, 416)
    XCTAssertEqual(aggregate.interoception.featureDimension, 6)
    XCTAssertEqual(aggregate.channels.count, 7)
    XCTAssertEqual(aggregate.touch.receptorCount, 10)
    XCTAssertEqual(aggregate.touch.featureDimension, 7)
    let kinesthesia = try XCTUnwrap(
      aggregate.channels.first { $0.modality == .kinesthesia }
    )
    XCTAssertEqual(kinesthesia.receptorCount, 128)
    XCTAssertEqual(kinesthesia.featureDimension, 7)
    let vestibular = try XCTUnwrap(
      aggregate.channels.first { $0.modality == .vestibular }
    )
    XCTAssertEqual(vestibular.receptorCount, 1)
    XCTAssertEqual(vestibular.featureDimension, 22)
    XCTAssertEqual(aggregate.audition.receptorCount, 24)
    XCTAssertEqual(aggregate.audition.featureDimension, 8)
    let firstAuditionValidity = try qualificationUInt32s(
      from: try qualificationReadback(
        aggregate.audition.validity!, device: device
      )
    )
    XCTAssertEqual(firstAuditionValidity.count, 24)
    XCTAssertTrue(
      firstAuditionValidity.allSatisfy { $0 == 0xfb },
      "first audition masks: \(firstAuditionValidity)"
    )
    let firstTouchValidity = try qualificationUInt32s(
      from: try qualificationReadback(
        aggregate.touch.validity!, device: device
      )
    )
    let firstProprioceptionValidity = try qualificationUInt32s(
      from: try qualificationReadback(
        aggregate.proprioception.validity!, device: device
      )
    )
    XCTAssertTrue(
      firstTouchValidity.allSatisfy { $0 == 0x7f },
      "first touch masks: \(firstTouchValidity)"
    )
    XCTAssertTrue(
      firstProprioceptionValidity.allSatisfy { $0 == 0x3ff },
      "first proprio masks: \(firstProprioceptionValidity.prefix(8))"
    )
    let vision = try XCTUnwrap(
      aggregate.channels.first { $0.modality == .vision }
    )
    XCTAssertEqual(vision.receptorCount, 64 * 48)
    XCTAssertEqual(vision.featureDimension, 8)
    XCTAssertEqual(vision.receptorTimestamp, BrainTimestamp(microseconds: 1_000))
    for channel in aggregate.channels {
      XCTAssertEqual(channel.receptorTimestamp, BrainTimestamp(microseconds: 1_000))
      XCTAssertEqual(channel.deliveryTimestamp, BrainTimestamp(microseconds: 2_000))
      XCTAssertEqual(channel.latencyMicroseconds, 1_000)
      XCTAssertEqual(channel.sampleIntervalMicroseconds, 1_000)
    }
    XCTAssertEqual(try native.currentInfo().residentContinuationCount, 0)

    let secondTransaction = try brain.beginControl(
      controlStepIdentifier: 2,
      basePhysicsGeneration: aggregate.physicsGeneration,
      committedTimestamp: BrainTimestamp(microseconds: 2_000),
      targetTimestamp: BrainTimestamp(microseconds: 3_000),
      cachedDecisionFingerprint: 0x4e58_4445_4349_534a
    )
    let publishedSensors = try aggregate.sensorPacket(
      for: secondTransaction.token,
      compiledSpeciesTemplate: compiled
    )
    let second = try publishRoot(
      brain: brain,
      native: native,
      transaction: secondTransaction,
      sensors: publishedSensors,
      device: device
    )
    XCTAssertEqual(second.physical.identity.controlStep, 2)
    XCTAssertEqual(second.aggregate.publicationEpoch, 2)
    XCTAssertEqual(second.aggregate.brainGeneration, 2)
    XCTAssertEqual(second.aggregate.physicsGeneration, 2)
    XCTAssertEqual(second.aggregate.sensorGeneration, 2)
    XCTAssertEqual(try native.currentInfo().residentContinuationCount, 1)
    XCTAssertEqual(
      second.aggregate.identity.transactionFingerprint,
      secondTransaction.token.fingerprint
    )
    XCTAssertEqual(second.aggregate.proprioception.receptorTimestamp,
                   BrainTimestamp(microseconds: 2_000))
    XCTAssertEqual(second.aggregate.interoception.receptorTimestamp,
                   BrainTimestamp(microseconds: 2_000))
    XCTAssertTrue(second.aggregate.channels.allSatisfy {
      $0.deliveryTimestamp == BrainTimestamp(microseconds: 3_000)
        && $0.latencyMicroseconds == 1_000
        && $0.sampleIntervalMicroseconds == 1_000
    })
    let secondAuditionValidity = try qualificationUInt32s(
      from: try qualificationReadback(
        second.aggregate.audition.validity!, device: device
      )
    )
    XCTAssertEqual(secondAuditionValidity.count, 24)
    let secondTouchValidity = try qualificationUInt32s(
      from: try qualificationReadback(
        second.aggregate.touch.validity!, device: device
      )
    )
    let secondProprioceptionValidity = try qualificationUInt32s(
      from: try qualificationReadback(
        second.aggregate.proprioception.validity!, device: device
      )
    )
    XCTAssertTrue(secondAuditionValidity.allSatisfy { $0 == 0xff })
    XCTAssertTrue(secondTouchValidity.allSatisfy { $0 == 0x7f })
    XCTAssertTrue(secondProprioceptionValidity.allSatisfy { $0 == 0x3ff })
    // The copied epoch-1 metadata remains an immutable value even though the
    // native runtime has advanced its sole public aggregate root.
    XCTAssertEqual(aggregate.publicationEpoch, 1)
    XCTAssertEqual(aggregate.physicsGeneration, 1)

    // A fully valid Brain/motor root with a stale physics predecessor is
    // rejected by the native causal-chain gate before it consumes a runtime
    // slot or touches the resident Human state.
    let staleTransaction = try brain.beginControl(
      controlStepIdentifier: 3,
      basePhysicsGeneration: 1,
      committedTimestamp: BrainTimestamp(microseconds: 3_000),
      targetTimestamp: BrainTimestamp(microseconds: 4_000),
      cachedDecisionFingerprint: 0x4e58_5354_414c_4501
    )
    let staleSensors = try bootstrapSensorPacket(
      device: device,
      compiled: compiled,
      transaction: staleTransaction.token
    )
    let staleDecision = try brain.submitInferAndDecide(
      staleTransaction,
      numanXSensors: staleSensors,
      signal: point(device, value: 1)
    )
    let staleMotor = try brain.submitNumanXMotorCandidate(
      staleDecision,
      transaction: staleTransaction,
      candidateDurationMicroseconds: 1_000,
      signal: point(device, value: 1)
    )
    XCTAssertThrowsError(
      try native.beginPhysicalRoot(
        transaction: staleTransaction.token,
        motor: staleMotor
      ) { _ in
        XCTFail("stale native root unexpectedly armed a completion")
      }
    )
    _ = try brain.finishNumanXMotorSubmission(
      staleMotor,
      transaction: staleTransaction,
      timeoutMilliseconds: 10_000
    )
    try brain.abortControl(staleTransaction)
    XCTAssertEqual(
      try XCTUnwrap(native.aggregateSnapshotIfAvailable()).publicationEpoch,
      2
    )
    XCTAssertEqual(try native.currentInfo().residentContinuationCount, 1)

    // The exact successor is still admissible and receives generation 3,
    // proving the failed stale request did not consume native generation or
    // sensor-publication authority.
    let thirdTransaction = try brain.beginControl(
      controlStepIdentifier: 3,
      basePhysicsGeneration: second.aggregate.physicsGeneration,
      committedTimestamp: BrainTimestamp(microseconds: 3_000),
      targetTimestamp: BrainTimestamp(microseconds: 4_000),
      cachedDecisionFingerprint: 0x4e58_4445_4349_534b
    )
    let thirdSensors = try second.aggregate.sensorPacket(
      for: thirdTransaction.token,
      compiledSpeciesTemplate: compiled
    )
    let third = try publishRoot(
      brain: brain,
      native: native,
      transaction: thirdTransaction,
      sensors: thirdSensors,
      device: device
    )
    XCTAssertEqual(third.aggregate.publicationEpoch, 3)
    XCTAssertEqual(third.aggregate.brainGeneration, 3)
    XCTAssertEqual(third.aggregate.physicsGeneration, 3)
    XCTAssertEqual(third.aggregate.sensorGeneration, 3)
    XCTAssertEqual(try native.currentInfo().residentContinuationCount, 2)

    let rejectedTransaction = try brain.beginControl(
      controlStepIdentifier: 4,
      basePhysicsGeneration: third.aggregate.physicsGeneration,
      committedTimestamp: BrainTimestamp(microseconds: 4_000),
      targetTimestamp: BrainTimestamp(microseconds: 5_000),
      cachedDecisionFingerprint: 0x4e58_5245_4a45_4354
    )
    let rejectedSensors = try third.aggregate.sensorPacket(
      for: rejectedTransaction.token,
      compiledSpeciesTemplate: compiled
    )
    let rejected = try prepareRoot(
      brain: brain,
      native: native,
      transaction: rejectedTransaction,
      sensors: rejectedSensors,
      device: device
    )
    let rejectedAcceptedToken = acceptedGateBytes(
      rejected.physical.acceptedPhysicsGate
    )
    let rejectedSensorPayload = sensorPayloadBytes(
      rejected.physical.sensorCandidate
    )
    XCTAssertTrue(rejected.physical.quarantineTimeout())
    let rejectProposalLatch =
      AsyncResultLatch<MetalNumanXHumanMatterProposalLease>()
    try rejected.physical.submitTimeoutRejectProposal {
      rejectProposalLatch.complete($0)
    }
    _ = try rejectProposalLatch.wait()
    try rejected.physical.reserveTimeoutRejectApplication(
      brain: rejected.prepared
    )
    let rejectApplyLatch =
      AsyncResultLatch<MetalNumanXHumanMatterAppliedLease>()
    try rejected.physical.submitTimeoutRejectApply {
      rejectApplyLatch.complete($0)
    }
    let rejectedApplied = try rejectApplyLatch.wait()
    XCTAssertEqual(rejectedApplied.commandDisposition, .rejectedReleased)
    XCTAssertTrue(rejected.physical.releaseRejected())
    try brain.abortNumanXPreparedControl(rejected.prepared)
    XCTAssertFalse(brain.hasOpenControl)
    XCTAssertEqual(brain.committedGeneration, 3)
    let afterReject = try XCTUnwrap(native.aggregateSnapshotIfAvailable())
    XCTAssertEqual(afterReject.publicationEpoch, 3)
    XCTAssertEqual(afterReject.physicsGeneration, 3)
    XCTAssertEqual(afterReject.sensorGeneration, 3)
    XCTAssertEqual(try native.currentInfo().residentContinuationCount, 3)

    // Retry the rejected causal step. Physics generation is reused from the
    // restored predecessor, while the private HumanIO sensor generation stays
    // monotonic and therefore skips the rejected candidate's generation 4.
    let retryTransaction = try brain.beginControl(
      controlStepIdentifier: 4,
      basePhysicsGeneration: afterReject.physicsGeneration,
      committedTimestamp: BrainTimestamp(microseconds: 4_000),
      targetTimestamp: BrainTimestamp(microseconds: 5_000),
      cachedDecisionFingerprint: 0x4e58_5245_4a45_4354
    )
    XCTAssertEqual(
      retryTransaction.token.fingerprint,
      rejectedTransaction.token.fingerprint
    )
    let retrySensors = try afterReject.sensorPacket(
      for: retryTransaction.token,
      compiledSpeciesTemplate: compiled
    )
    let retried = try publishRoot(
      brain: brain,
      native: native,
      transaction: retryTransaction,
      sensors: retrySensors,
      device: device
    )
    XCTAssertEqual(retried.aggregate.publicationEpoch, 4)
    XCTAssertEqual(retried.aggregate.brainGeneration, 4)
    XCTAssertEqual(retried.aggregate.physicsGeneration, 4)
    XCTAssertEqual(retried.aggregate.sensorGeneration, 5)
    XCTAssertEqual(try native.currentInfo().residentContinuationCount, 4)
    XCTAssertEqual(
      acceptedGateBytes(retried.physical.acceptedPhysicsGate),
      rejectedAcceptedToken
    )
    XCTAssertEqual(
      sensorPayloadBytes(retried.physical.sensorCandidate),
      rejectedSensorPayload
    )

    // The accepted full-body roots are learner authority, not merely an
    // inference fixture. Freeze their immutable committed batch, perform the
    // real off-rollout MLX update, and materialize the exact successor on the
    // same Apple GPU. Held-out causal sensor intervention remains a separate
    // Gate B qualification; this establishes the production root-to-learner
    // and learner-to-runtime boundary it depends on.
    let learningBatch = try brain.makeLearningBatch()
    XCTAssertEqual(learningBatch.sourceGeneration, retried.aggregate.brainGeneration)
    XCTAssertEqual(
      learningBatch.parameterVersionFingerprint,
      publication.version.fingerprint
    )
    try assertAcceptedLearningRecordCoversEveryModality(
      learningBatch,
      compiled: compiled,
      sourceGeneration: retried.aggregate.brainGeneration
    )
    let learnerUpdate = try MLXBrainLearner().update(
      parentPublication: publication,
      batch: learningBatch
    )
    let replayedLearnerUpdate = try MLXBrainLearner().update(
      parentPublication: publication,
      batch: learningBatch
    )
    XCTAssertEqual(replayedLearnerUpdate, learnerUpdate)
    XCTAssertEqual(learnerUpdate.sourceMindCount, 1)
    XCTAssertEqual(learnerUpdate.sourceGeneration, retried.aggregate.brainGeneration)
    XCTAssertEqual(
      Set(learnerUpdate.losses.map(\.kind)),
      Set(BrainSlowLossKind.allCases)
    )
    XCTAssertTrue(learnerUpdate.losses.allSatisfy {
      $0.value.isFinite && $0.weight.isFinite
    })
    let learnedPublication = try BrainParameterPublication(
      parentVersion: publication.version,
      learnerUpdate: learnerUpdate
    )
    XCTAssertNotEqual(
      learnedPublication.version.fingerprint,
      publication.version.fingerprint
    )
    XCTAssertNotEqual(
      learnedPublication.sharedArtifact.artifactFingerprint,
      publication.sharedArtifact.artifactFingerprint
    )
    XCTAssertEqual(
      learnedPublication.sourceBatchFingerprint,
      learningBatch.batchFingerprint
    )
    let learnedBrain = try MetalNumiBrainRuntime.makeRuntime(
      configuration: brainConfiguration,
      publication: learnedPublication,
      device: device
    )
    XCTAssertEqual(learnedBrain.committedGeneration, 0)
    XCTAssertEqual(
      learnedBrain.parameterVersionFingerprint,
      learnedPublication.version.fingerprint
    )
    XCTAssertEqual(learnedBrain.deviceRegistryID, device.registryID)

    // Keep rollout on the immutable parent for four later accepted roots. The
    // successor never saw generations 5...8 during optimization, so they form
    // an exact temporal holdout for the first versioned intervention runner.
    var heldoutAggregate = retried.aggregate
    for controlStep in UInt64(5)...UInt64(8) {
      let transaction = try brain.beginControl(
        controlStepIdentifier: controlStep,
        basePhysicsGeneration: heldoutAggregate.physicsGeneration,
        committedTimestamp: BrainTimestamp(
          microseconds: controlStep * 1_000
        ),
        targetTimestamp: BrainTimestamp(
          microseconds: (controlStep + 1) * 1_000
        ),
        cachedDecisionFingerprint: 0x4e58_484f_4c44_0000 | controlStep
      )
      let sensors = try heldoutAggregate.sensorPacket(
        for: transaction.token,
        compiledSpeciesTemplate: compiled
      )
      heldoutAggregate = try publishRoot(
        brain: brain,
        native: native,
        transaction: transaction,
        sensors: sensors,
        device: device
      ).aggregate
    }
    XCTAssertEqual(heldoutAggregate.brainGeneration, 8)
    let heldoutBatch = try brain.makeLearningBatch()
    let evaluator = MLXGateBCausalEvaluator()
    var evaluations: [NumanXGateBPolicyHeadEvaluation] = []
    for modality in compiled.species.senses.filter(\.enabled).map(\.modality) {
      let first = try evaluator.evaluate(
        publication: learnedPublication,
        batch: heldoutBatch,
        species: compiled.species,
        modality: modality,
        minimumGeneration: 5,
        maximumGeneration: 8,
        shuffleSeed: 0x4e58_4741_5445_4201
      )
      let replay = try evaluator.evaluate(
        publication: learnedPublication,
        batch: heldoutBatch,
        species: compiled.species,
        modality: modality,
        minimumGeneration: 5,
        maximumGeneration: 8,
        shuffleSeed: 0x4e58_4741_5445_4201
      )
      XCTAssertEqual(first, replay)
      XCTAssertEqual(Set(first.map(\.intervention)), Set(
        NumanXGateBInterventionKind.allCases
      ))
      XCTAssertTrue(first.allSatisfy {
        $0.transitionCount == 4
          && $0.minimumGeneration == 5
          && $0.maximumGeneration == 8
      })
      evaluations.append(contentsOf: first)
    }
    XCTAssertEqual(evaluations.count, 7 * 4)
    XCTAssertTrue(evaluations.filter {
      $0.intervention == .intact
    }.allSatisfy { $0.actionDeltaFromIntact == 0 })
    XCTAssertTrue(evaluations.contains {
      $0.intervention == .ablated && $0.actionDeltaFromIntact > 0
    })
    XCTAssertThrowsError(try evaluator.evaluate(
      publication: learnedPublication,
      batch: heldoutBatch,
      species: compiled.species,
      modality: .vision,
      minimumGeneration: 4,
      maximumGeneration: 8
    ))
    XCTAssertThrowsError(try evaluator.evaluate(
      publication: learnedPublication,
      batch: heldoutBatch,
      species: compiled.species,
      modality: .olfaction,
      minimumGeneration: 5,
      maximumGeneration: 8
    ))
    if ProcessInfo.processInfo.environment["NUMANX_GATE_B_EVIDENCE"] == "1" {
      for result in evaluations.sorted(by: {
        ($0.modality.rawValue, $0.intervention.rawValue)
          < ($1.modality.rawValue, $1.intervention.rawValue)
      }) {
        print(
          "GateB policy-head modality=\(result.modality) "
            + "intervention=\(result.intervention) "
            + "mse=\(result.actionMeanSquaredError) "
            + "delta=\(result.actionDeltaFromIntact)"
        )
      }
    }
  }

  private func publishRoot(
    brain: MetalNumiBrainRuntime,
    native: MetalNumanXBridgeV1Runtime,
    transaction: MetalNumiBrainRuntime.ControlTransaction,
    sensors: NumanXSensorPacketLease,
    device: any MTLDevice,
    externalGoal: ActiveGoal? = nil,
    developmentalCapabilityCodes: [UInt64] = [],
    developmentalIntentFingerprintXor: UInt64 = 0,
    activeSensingCommandScale: Float = 1
  ) throws -> (
    physical: MetalNumanXBridgeV1PreparedRoot,
    aggregate: MetalNumanXBridgeV1Runtime.AggregateSnapshot,
    candidateSensorValues: [Float],
    motorExcitations: [Float],
    descendingSomatic: [Float],
    activeVisionCommand: Float,
    activeVisionConfidence: Float
  ) {
    let staged = try prepareRoot(
      brain: brain,
      native: native,
      transaction: transaction,
      sensors: sensors,
      device: device,
      externalGoal: externalGoal,
      developmentalCapabilityCodes: developmentalCapabilityCodes,
      developmentalIntentFingerprintXor: developmentalIntentFingerprintXor,
      activeSensingCommandScale: activeSensingCommandScale
    )
    let physical = staged.physical
    let prepared = staged.prepared
    let candidateSensorValues = try qualificationSensorValues(
      physical.sensorCandidate, device: device
    )
    let proposalLatch = AsyncResultLatch<MetalNumanXHumanMatterProposalLease>()
    try physical.submitProposal(brain: prepared) { proposalLatch.complete($0) }

    _ = try prepared.waitUntilBrainPrepareCompleted(timeoutMilliseconds: 10_000)
    let proposal = try proposalLatch.wait()
    let preflightStatus = waitForPreflight(prepared)
    guard preflightStatus == .numanXPreflightReady else {
      throw TissueError.transaction(
        prepared.preflightFailureDescription
          ?? "NumanX preflight settled as \(preflightStatus)"
      )
    }
    let jointCommitFingerprint = try brain.numanXPreparedJointCommitFingerprint(
      for: prepared,
      identity: physical.identity
    )
    try physical.reserveApplication(brain: prepared)

    let ackPoint = try point(device, value: 1)
    let ack = try brain.submitNumanXBrainAck(
      prepared,
      proposal: proposal,
      signal: ackPoint
    )
    let appliedLatch = AsyncResultLatch<MetalNumanXHumanMatterAppliedLease>()
    try physical.submitApply(ack: ack) { appliedLatch.complete($0) }
    let applied = try appliedLatch.wait()
    XCTAssertEqual(applied.commandDisposition, .acceptedPendingPublication)

    let resolution = try physical.makeResolution(
      proposal: proposal,
      applied: applied,
      jointCommitFingerprint: jointCommitFingerprint,
      brainGeneration: transaction.token.shadowGeneration
    )
    let validationPoint = try point(device, value: 1)
    _ = try brain.validateNumanXAppliedRoot(
      prepared,
      ack: ack,
      applied: applied,
      resolution: resolution,
      signal: validationPoint
    )
    XCTAssertEqual(waitForClose(prepared), .committed)
    XCTAssertFalse(brain.hasOpenControl)
    XCTAssertEqual(brain.committedGeneration, transaction.token.shadowGeneration)
    return (
      physical,
      try XCTUnwrap(native.aggregateSnapshotIfAvailable()),
      candidateSensorValues,
      staged.motorExcitations,
      staged.descendingSomatic,
      staged.activeVisionCommand,
      staged.activeVisionConfidence
    )
  }

  private struct AcceptedScenario {
    let batch: MetalLearningBatch
    let finalSensorValues: [Float]
    let finalSensorValuesByModality: [SensoryModality: [Float]]
    let sensorValuesByGeneration: [[SensoryModality: [Float]]]
    let sensorFingerprints: [UInt64]
    let candidateSensorFingerprints: [UInt64]
    let motorExcitationsByGeneration: [[Float]]
    let descendingSomaticByGeneration: [[Float]]
    let activeVisionCommands: [Float]
    let activeVisionConfidences: [Float]
    let visionDepthValidCounts: [Int]
    let visionGeometryValidCounts: [Int]
  }

  private enum ClosedLoopSensorIntervention {
    case ablated(SensoryModality)
    case scaled(SensoryModality, Float)
  }

  private func runAcceptedScenario(
    paths: BridgePaths,
    contactPath: String,
    compiled: CompiledSpeciesTemplate,
    publication: BrainParameterPublication,
    device: any MTLDevice,
    rootCount: UInt64,
    externalGoal: ((UInt64) throws -> ActiveGoal)? = nil,
    sensorIntervention: ClosedLoopSensorIntervention? = nil,
    developmentalCapabilityCodes: [UInt64] = [],
    developmentalIntentFingerprintXor: UInt64 = 0,
    activeSensingCommandScale: Float = 1
  ) throws -> AcceptedScenario {
    guard rootCount > 0 else {
      throw TissueError.transaction("Gate B scenario requires accepted roots")
    }
    let parameters = TissueParameters.corticalSheetV0
    let brain = try MetalNumiBrainRuntime.makeRuntime(
      configuration: MetalNumiBrainConfiguration(
        initialTissueState: try CPUTissueDynamics.makeRestingGrid(
          width: 8, height: 8, parameters: parameters
        ),
        tissueParameters: parameters,
        tissueStimulus: .none,
        compiledSpeciesTemplate: compiled,
        randomContext: TissueRandomContext(
          seed: 0x4e55_4d49,
          environmentIdentifier: 0,
          episodeIdentifier: 1
        ),
        schedulerEnvironmentIdentifier: 0,
        maximumEncodedSubsteps: 1
      ),
      publication: publication,
      device: device
    )
    let native = try MetalNumanXBridgeV1Runtime(
      libraryPath: paths.library,
      device: device,
      configuration: .init(
        rigidPayloadPath: paths.rigid,
        musclePayloadPath: paths.muscle,
        supportContactPayloadPath: contactPath,
        visualPackPath: paths.visualPack,
        visionProfilePath: paths.visionProfile,
        metalRoboMetallibPath: paths.metalRoboMetallib,
        matterMetallibPath: paths.matterMetallib,
        matterMaterialPath: paths.material,
        timestepMicroseconds: 1_000,
        transactionSlotCount: 2
      )
    )
    var aggregate: MetalNumanXBridgeV1Runtime.AggregateSnapshot?
    var sensorFingerprints: [UInt64] = []
    var candidateSensorFingerprints: [UInt64] = []
    var finalSensorValues: [Float] = []
    var finalSensorValuesByModality: [SensoryModality: [Float]] = [:]
    var sensorValuesByGeneration: [[SensoryModality: [Float]]] = []
    var motorExcitationsByGeneration: [[Float]] = []
    var descendingSomaticByGeneration: [[Float]] = []
    var activeVisionCommands: [Float] = []
    var activeVisionConfidences: [Float] = []
    var visionDepthValidCounts: [Int] = []
    var visionGeometryValidCounts: [Int] = []
    for controlStep in UInt64(1)...rootCount {
      let transaction = try brain.beginControl(
        controlStepIdentifier: controlStep,
        basePhysicsGeneration: aggregate?.physicsGeneration ?? 0,
        committedTimestamp: BrainTimestamp(
          microseconds: controlStep * 1_000
        ),
        targetTimestamp: BrainTimestamp(
          microseconds: (controlStep + 1) * 1_000
        ),
        cachedDecisionFingerprint: 0x4e58_4742_0000_0000 | controlStep
      )
      let sensors = if let aggregate {
        if let sensorIntervention {
          try qualificationIntervenedSensorPacket(
            aggregate: aggregate,
            transaction: transaction.token,
            compiled: compiled,
            intervention: sensorIntervention,
            device: device
          )
        } else {
          try aggregate.sensorPacket(
            for: transaction.token,
            compiledSpeciesTemplate: compiled
          )
        }
      } else {
        try bootstrapSensorPacket(
          device: device,
          compiled: compiled,
          transaction: transaction.token
        )
      }
      do {
        let published = try publishRoot(
          brain: brain,
          native: native,
          transaction: transaction,
          sensors: sensors,
          device: device,
          externalGoal: try externalGoal?(controlStep),
          developmentalCapabilityCodes: developmentalCapabilityCodes,
          developmentalIntentFingerprintXor: developmentalIntentFingerprintXor,
          activeSensingCommandScale: activeSensingCommandScale
        )
        aggregate = published.aggregate
        candidateSensorFingerprints.append(
          fingerprint(published.candidateSensorValues)
        )
        finalSensorValuesByModality = try qualificationSensorValuesByModality(
          try XCTUnwrap(aggregate), device: device
        )
        finalSensorValues = finalSensorValuesByModality.keys.sorted(by: {
          $0.rawValue < $1.rawValue
        }).flatMap { finalSensorValuesByModality[$0] ?? [] }
        sensorValuesByGeneration.append(finalSensorValuesByModality)
        sensorFingerprints.append(fingerprint(finalSensorValues))
        motorExcitationsByGeneration.append(published.motorExcitations)
        descendingSomaticByGeneration.append(published.descendingSomatic)
        activeVisionCommands.append(published.activeVisionCommand)
        activeVisionConfidences.append(published.activeVisionConfidence)
        let vision = try XCTUnwrap(
          aggregate?.channels.first { $0.modality == .vision }
        )
        let visionValidity = try qualificationUInt32s(
          from: try qualificationReadback(
            try XCTUnwrap(vision.validity), device: device
          )
        )
        visionDepthValidCounts.append(
          visionValidity.count { ($0 & 0x08) != 0 }
        )
        visionGeometryValidCounts.append(
          visionValidity.count { ($0 & 0x70) == 0x70 }
        )
      } catch {
        throw TissueError.transaction(
          "Gate B scenario \(contactPath) root \(controlStep) failed: \(error)"
        )
      }
    }
    XCTAssertEqual(aggregate?.brainGeneration, rootCount)
    XCTAssertEqual(aggregate?.physicsGeneration, rootCount)
    _ = try XCTUnwrap(aggregate)
    return AcceptedScenario(
      batch: try brain.makeLearningBatch(),
      finalSensorValues: finalSensorValues,
      finalSensorValuesByModality: finalSensorValuesByModality,
      sensorValuesByGeneration: sensorValuesByGeneration,
      sensorFingerprints: sensorFingerprints,
      candidateSensorFingerprints: candidateSensorFingerprints,
      motorExcitationsByGeneration: motorExcitationsByGeneration,
      descendingSomaticByGeneration: descendingSomaticByGeneration,
      activeVisionCommands: activeVisionCommands,
      activeVisionConfidences: activeVisionConfidences,
      visionDepthValidCounts: visionDepthValidCounts,
      visionGeometryValidCounts: visionGeometryValidCounts
    )
  }

  // Qualification-only intervention laboratory. The production path remains
  // zero-copy; this helper copies one accepted channel into a separately owned
  // same-device buffer and changes only the named modality before the next
  // Brain root. Published physical sensors are still read back independently
  // after that root, so intervention input never substitutes outcome evidence.
  private func qualificationIntervenedSensorPacket(
    aggregate: MetalNumanXBridgeV1Runtime.AggregateSnapshot,
    transaction: BrainJointTransactionToken,
    compiled: CompiledSpeciesTemplate,
    intervention: ClosedLoopSensorIntervention,
    device: any MTLDevice
  ) throws -> NumanXSensorPacketLease {
    guard transaction.baseBrainGeneration == aggregate.brainGeneration,
      transaction.basePhysicsGeneration == aggregate.physicsGeneration
    else {
      throw TissueError.transaction(
        "Gate B intervention does not immediately follow its accepted root"
      )
    }
    let target: SensoryModality
    let scale: Float
    switch intervention {
    case .ablated(let modality):
      target = modality
      scale = 0
    case .scaled(let modality, let factor):
      guard factor.isFinite, factor >= 0, factor <= 1 else {
        throw TissueError.transaction(
          "Gate B intervention scale must be finite and normalized"
        )
      }
      target = modality
      scale = factor
    }
    var replaced = false
    let sensors = try aggregate.channels.map { channel in
      guard channel.modality == target else { return channel.rawSensor }
      replaced = true
      guard let buffer = device.makeBuffer(
        length: channel.values.byteCount,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ) else {
        throw TissueError.metal("failed to allocate Gate B intervention buffer")
      }
      let source = try qualificationReadback(channel.rawSensor.buffer, device: device)
      guard source.count >= channel.values.byteCount else {
        throw TissueError.transaction(
          "Gate B intervention source range is truncated"
        )
      }
      let destination = buffer.contents().assumingMemoryBound(to: Float.self)
      let scalarCount = channel.values.byteCount / MemoryLayout<Float>.stride
      source.withUnsafeBytes { raw in
        let values = raw.bindMemory(to: Float.self)
        for index in 0..<scalarCount {
          destination[index] = values[index] * scale
        }
      }
      return try MetalRawSensorBufferLease(
        buffer: buffer,
        modality: channel.modality,
        receptorTimestamp: channel.receptorTimestamp,
        receptorCount: channel.receptorCount,
        featureDimension: channel.featureDimension,
        validityBuffer: channel.rawSensor.validityBuffer
      )
    }
    guard replaced else {
      throw TissueError.transaction(
        "Gate B intervention modality is absent from the aggregate root"
      )
    }
    return try NumanXSensorPacketLease(
      transaction: transaction,
      compiledSpeciesTemplate: compiled,
      rawSensors: sensors
    )
  }

  private func modalityDriftCost(
    _ scenario: AcceptedScenario,
    modality: SensoryModality
  ) -> Float {
    guard let first = scenario.sensorValuesByGeneration.first?[modality],
      let last = scenario.sensorValuesByGeneration.last?[modality],
      first.count == last.count, !first.isEmpty
    else { return .infinity }
    return zip(first, last).reduce(Float(0)) {
      let delta = $1.0 - $1.1
      return $0 + delta * delta
    } / Float(first.count)
  }

  private func qualificationSensorValues(
    _ candidate: MetalNumanXPendingSensorCandidateLease,
    device: any MTLDevice
  ) throws -> [Float] {
    try candidate.rawSensors
      .sorted { $0.view.modality.rawValue < $1.view.modality.rawValue }
      .flatMap { sensor -> [Float] in
        let bytes = try qualificationReadback(sensor.buffer, device: device)
        let scalarCount = Int(sensor.view.receptorCount)
          * Int(sensor.view.featureDimension)
        let logicalByteCount = scalarCount * MemoryLayout<Float>.stride
        guard bytes.count >= logicalByteCount else {
          throw TissueError.transaction(
            "Gate B unpublished sensor qualification range is malformed"
          )
        }
        return bytes.prefix(logicalByteCount).withUnsafeBytes { raw in
          stride(from: 0, to: logicalByteCount, by: MemoryLayout<Float>.stride).map {
            raw.loadUnaligned(fromByteOffset: $0, as: Float.self)
          }
        }
      }
  }

  private func qualificationSensorValuesByModality(
    _ aggregate: MetalNumanXBridgeV1Runtime.AggregateSnapshot,
    device: any MTLDevice
  ) throws -> [SensoryModality: [Float]] {
    try Dictionary(uniqueKeysWithValues: aggregate.channels.map { channel in
        let bytes = try qualificationReadback(channel.values, device: device)
        let scalarCount = Int(channel.receptorCount)
          * Int(channel.featureDimension)
        let logicalByteCount = scalarCount * MemoryLayout<Float>.stride
        guard bytes.count >= logicalByteCount else {
          throw TissueError.transaction(
            "Gate B sensor qualification range is malformed"
          )
        }
        let values = bytes.prefix(logicalByteCount).withUnsafeBytes { raw in
          stride(from: 0, to: logicalByteCount, by: MemoryLayout<Float>.stride).map {
            raw.loadUnaligned(fromByteOffset: $0, as: Float.self)
          }
        }
        return (channel.modality, values)
      })
  }

  private func fingerprint(_ values: [Float]) -> UInt64 {
    values.withUnsafeBytes { bytes in
      bytes.reduce(UInt64(14_695_981_039_346_656_037)) {
        ($0 ^ UInt64($1)) &* 1_099_511_628_211
      }
    }
  }

  private func tiltedSupportContactAsset(
    sourcePath: String,
    degrees: Float
  ) throws -> URL {
    guard degrees.isFinite, abs(degrees) <= 15 else {
      throw TissueError.transaction("Gate B support tilt is outside its range")
    }
    var bytes = [UInt8](try Data(contentsOf: URL(fileURLWithPath: sourcePath)))
    guard bytes.count >= 84 else {
      throw TissueError.transaction("Gate B support-contact asset is truncated")
    }
    func loadUInt32(_ offset: Int) -> UInt32 {
      UInt32(bytes[offset])
        | UInt32(bytes[offset + 1]) << 8
        | UInt32(bytes[offset + 2]) << 16
        | UInt32(bytes[offset + 3]) << 24
    }
    func loadFloat(_ offset: Int) -> Float {
      Float(bitPattern: loadUInt32(offset))
    }
    func storeUInt32(_ value: UInt32, _ offset: Int) {
      bytes[offset] = UInt8(truncatingIfNeeded: value)
      bytes[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
      bytes[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
      bytes[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
    }
    func storeFloat(_ value: Float, _ offset: Int) {
      storeUInt32(value.bitPattern, offset)
    }
    let magic = Array("NHCNT1\0\0".utf8)
    let supportCount = Int(loadUInt32(16))
    guard Array(bytes[0..<8]) == magic,
      loadUInt32(8) == 1, supportCount == 10, loadUInt32(20) == 0,
      bytes.count == 84 + supportCount * 48
    else {
      throw TissueError.transaction(
        "Gate B support-contact asset has unexpected provenance"
      )
    }
    let point = (0..<3).map { loadFloat(56 + $0 * 4) }
    let oldNormal = (0..<3).map { loadFloat(68 + $0 * 4) }
    let radians = degrees * .pi / 180
    let newNormal: [Float] = [sin(radians), 0, cos(radians)]
    for index in 0..<supportCount {
      let record = 84 + index * 48
      let witness = (0..<3).map { loadFloat(record + 20 + $0 * 4) }
      let oldDistance = loadFloat(record + 36)
      let sourceWorld = (0..<3).map {
        witness[$0] + oldDistance * oldNormal[$0]
      }
      let newDistance = (0..<3).reduce(Float(0)) {
        $0 + (sourceWorld[$1] - point[$1]) * newNormal[$1]
      }
      storeFloat(newDistance, record + 36)
      for axis in 0..<3 {
        storeFloat(
          sourceWorld[axis] - newDistance * newNormal[axis],
          record + 20 + axis * 4
        )
      }
    }
    for axis in 0..<3 {
      storeFloat(newNormal[axis], 68 + axis * 4)
    }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "numanx-gate-b-support-\(UUID().uuidString).nhcnt"
    )
    try Data(bytes).write(to: url, options: .atomic)
    return url
  }

  private func supportStabilityGoal(
    target: [Float],
    controlStep: UInt64
  ) throws -> ActiveGoal {
    guard target.count == 16, controlStep > 0 else {
      throw TissueError.transaction(
        "Gate B support-stability goal has invalid target or control step"
      )
    }
    let committedTimestamp = BrainTimestamp(
      microseconds: controlStep * 1_000
    )
    return try ActiveGoal(
      identifier: 0x0047_4253_5441_0000 | controlStep,
      origin: .externalTask,
      targetState: BrainLatentVector(values: target, expectedCount: 16),
      priority: 10,
      deadline: BrainTimestamp(
        microseconds: (controlStep + 1) * 1_000
      ),
      successModel: BrainLatentVector(values: target, expectedCount: 16),
      failureModel: BrainLatentVector(
        values: target.map { -$0 }, expectedCount: 16
      ),
      // This qualification goal must remain admissible whenever the global
      // hyperdirect safety stop has not fired. The runtime's independent
      // safety > 0.8 stop remains authoritative; this per-goal budget only
      // prevents ordinary counterfactual pruning from hiding the task option.
      damageRiskBudget: 1.0,
      persistence: 1,
      createdTimestamp: committedTimestamp
    )
  }

  private func assertAcceptedLearningRecordCoversEveryModality(
    _ batch: MetalLearningBatch,
    compiled: CompiledSpeciesTemplate,
    sourceGeneration: UInt64
  ) throws {
    let enabledModalities = compiled.species.senses
      .filter(\.enabled)
      .sorted { $0.modality.rawValue < $1.modality.rawValue }
      .map(\.modality)
    XCTAssertLessThanOrEqual(enabledModalities.count, 8)
    let storage = try batch.makeSharedStorageLease()
    var matchingRecordCount = 0
    for index in 0..<batch.transitionCapacity {
      let record = storage.baseAddress.advanced(
        by: index * batch.transitionStride
      )
      let identifier = record.load(as: UInt64.self)
      let generation = record.advanced(by: 32).load(as: UInt64.self)
      guard identifier != 0, generation == sourceGeneration else { continue }
      matchingRecordCount += 1
      XCTAssertEqual(
        record.advanced(by: 64).load(as: UInt32.self),
        MetalLearningBatch.transitionRecordVersion
      )
      let validityMask = record.advanced(by: 92).load(as: UInt32.self)
      let observations = record.advanced(by: 320)
        .assumingMemoryBound(to: Float.self)
      for (slot, modality) in enabledModalities.enumerated() {
        let component = slot * 3
        XCTAssertEqual(
          validityMask & (UInt32(7) << UInt32(component)),
          UInt32(7) << UInt32(component),
          "accepted learning record omitted \(modality)"
        )
        XCTAssertTrue(observations[component].isFinite)
        XCTAssertTrue(observations[component + 1].isFinite)
        XCTAssertTrue(observations[component + 2].isFinite)
      }
    }
    XCTAssertGreaterThan(matchingRecordCount, 0)
  }

  private func prepareRoot(
    brain: MetalNumiBrainRuntime,
    native: MetalNumanXBridgeV1Runtime,
    transaction: MetalNumiBrainRuntime.ControlTransaction,
    sensors: NumanXSensorPacketLease,
    device: any MTLDevice,
    externalGoal: ActiveGoal? = nil,
    developmentalCapabilityCodes: [UInt64] = [],
    developmentalIntentFingerprintXor: UInt64 = 0,
    activeSensingCommandScale: Float = 1
  ) throws -> (
    physical: MetalNumanXBridgeV1PreparedRoot,
    prepared: MetalNumiBrainRuntime.NumanXPreparedControlTicket,
    motorExcitations: [Float],
    descendingSomatic: [Float],
    activeVisionCommand: Float,
    activeVisionConfidence: Float
  ) {
    let decisionPoint = try point(device, value: 1)
    let motorPoint = try point(device, value: 1)
    let decision = try brain.submitInferAndDecide(
      transaction,
      numanXSensors: sensors,
      externalGoal: externalGoal,
      activeSensingCommandScale: activeSensingCommandScale,
      signal: decisionPoint
    )
    let motor = try brain.submitNumanXMotorCandidate(
      decision,
      transaction: transaction,
      candidateDurationMicroseconds: 1_000,
      signal: motorPoint
    )
    let rootLatch = AsyncResultLatch<MetalNumanXBridgeV1PreparedRoot>()
    try native.beginPhysicalRoot(transaction: transaction.token, motor: motor) {
      rootLatch.complete($0)
    }
    let physical = try rootLatch.wait()

    // Diagnostic settlement only: the physical queue already consumed the
    // GPU motor gate without a host wait. This advances Brain's host phase
    // after both exact terminal feedbacks are available.
    _ = try brain.finishNumanXMotorSubmission(
      motor,
      transaction: transaction,
      timeoutMilliseconds: 10_000
    )
    XCTAssertEqual(
      physical.identity.transactionFingerprint,
      transaction.token.fingerprint
    )
    let motorExcitations = try qualificationUInt32s(
      from: qualificationReadback(motor.buffers.excitationBuffer, device: device)
    ).map { Float(bitPattern: $0) }
    let activeSensingByteCount = Int(motor.candidate.activeSensingCommandByteCount)
    guard activeSensingByteCount <= motor.buffers.activeSensingBuffer.length else {
      throw TissueError.transaction(
        "Gate B active-sensing command exceeds its retained buffer"
      )
    }
    let activeSensingWords = try qualificationUInt32s(
      from: Array(UnsafeRawBufferPointer(
        start: motor.buffers.activeSensingBuffer.contents(),
        count: activeSensingByteCount
      ))
    )
    guard activeSensingWords.count == 4 else {
      throw TissueError.transaction(
        "Gate B active-sensing command has the wrong ABI size"
      )
    }
    let activeSensingCommand = Float(bitPattern: activeSensingWords[0])
    let activeSensingConfidence = Float(bitPattern: activeSensingWords[1])
    XCTAssertTrue(activeSensingCommand.isFinite)
    XCTAssertTrue((-1...1).contains(activeSensingCommand))
    XCTAssertTrue((0...1).contains(activeSensingConfidence))
    XCTAssertEqual(
      activeSensingWords[3] & 0xff,
      UInt32(SensoryModality.vision.rawValue)
    )
    XCTAssertNotEqual(activeSensingWords[3] & (1 << 16), 0)
    let decisionSource = motor.motorTicket.motorEvaluation
      .decisionEvaluation.sourceBuffer
    guard motor.decision.descendingSomaticBaselineGPUAddress
        >= decisionSource.gpuAddress,
      let descendingStart = Int(exactly:
        motor.decision.descendingSomaticBaselineGPUAddress
          - decisionSource.gpuAddress
      )
    else {
      throw TissueError.transaction(
        "Gate B descending somatic address is outside its retained decision buffer"
      )
    }
    let descendingEnd = descendingStart
      + motor.decision.descendingSomaticBaselineByteCount
    let decisionBytes = try qualificationReadback(decisionSource, device: device)
    guard descendingStart >= 0, descendingEnd <= decisionBytes.count else {
      throw TissueError.transaction(
        "Gate B descending somatic range is truncated"
      )
    }
    let descendingSomatic = decisionBytes[descendingStart..<descendingEnd]
      .withUnsafeBytes { raw in
        Array(raw.bindMemory(to: Float.self))
      }
    guard motor.decision.motorCommandGPUAddress >= decisionSource.gpuAddress,
      let motorCommandStart = Int(exactly:
        motor.decision.motorCommandGPUAddress - decisionSource.gpuAddress
      )
    else {
      throw TissueError.transaction(
        "Gate B motor command address is outside its retained decision buffer"
      )
    }
    let motorCommandByteCount = motor.decision.motorCommandCount * 32
    let motorCommandEnd = motorCommandStart + motorCommandByteCount
    guard motorCommandStart >= 0, motorCommandEnd <= decisionBytes.count else {
      throw TissueError.transaction(
        "Gate B motor command range is truncated"
      )
    }
    let motorCommandWords = try qualificationUInt32s(
      from: Array(decisionBytes[motorCommandStart..<motorCommandEnd])
    )
    let commandExcitations = stride(
      from: 0, to: motorCommandWords.count, by: 8
    ).map { Float(bitPattern: motorCommandWords[$0]) }
    let riskInhibitions = stride(
      from: 5, to: motorCommandWords.count, by: 8
    ).map { Float(bitPattern: motorCommandWords[$0]) }
    guard motor.decision.activeControlGPUAddress >= decisionSource.gpuAddress,
      let controlStart = Int(exactly:
        motor.decision.activeControlGPUAddress - decisionSource.gpuAddress
      )
    else {
      throw TissueError.transaction(
        "Gate B control header is outside its retained decision buffer"
      )
    }
    let controlEnd = controlStart + motor.decision.activeControlByteCount
    guard controlStart >= 0, controlEnd <= decisionBytes.count else {
      throw TissueError.transaction("Gate B control header is truncated")
    }
    let controlWords = try qualificationUInt32s(
      from: Array(decisionBytes[controlStart..<controlEnd])
    )
    let controlMode = controlWords[8]
    let controlFlags = controlWords[11]
    let predictedInformationGain = Float(bitPattern: controlWords[21])
    let unsupportedUncertainty = Float(bitPattern: controlWords[22])
    guard motor.decision.internalActionGPUAddress >= decisionSource.gpuAddress,
      let internalActionStart = Int(exactly:
        motor.decision.internalActionGPUAddress - decisionSource.gpuAddress
      )
    else {
      throw TissueError.transaction(
        "Gate B internal actions are outside their retained decision buffer"
      )
    }
    let internalActionByteCount = motor.decision.internalActionCount * 64
    let internalActionEnd = internalActionStart + internalActionByteCount
    guard internalActionStart >= 0, internalActionEnd <= decisionBytes.count else {
      throw TissueError.transaction("Gate B internal actions are truncated")
    }
    let internalActionWords = try qualificationUInt32s(
      from: Array(decisionBytes[internalActionStart..<internalActionEnd])
    )
    let inhibitionActionBase = 6 * 16
    let inhibitionActionKind = internalActionWords[inhibitionActionBase + 4]
    let inhibitionActionFlags = internalActionWords[inhibitionActionBase + 5]
    let inhibitionActionPriority = Float(
      bitPattern: internalActionWords[inhibitionActionBase + 8]
    )
    if ProcessInfo.processInfo.environment["NUMANX_GATE_B_EVIDENCE"] == "1" {
      print(
        "GateB motor-command excitationMax=\(commandExcitations.max() ?? .nan) "
          + "riskMin=\(riskInhibitions.min() ?? .nan) "
          + "riskMax=\(riskInhibitions.max() ?? .nan) "
          + "controlMode=\(controlMode) controlFlags=0x\(String(controlFlags, radix: 16)) "
          + "inhibitionKind=\(inhibitionActionKind) "
          + "inhibitionFlags=0x\(String(inhibitionActionFlags, radix: 16)) "
          + "inhibitionPriority=\(inhibitionActionPriority) "
          + "predictedInformation=\(predictedInformationGain) "
          + "unsupportedUncertainty=\(unsupportedUncertainty) "
          + "activeVisionCommand=\(activeSensingCommand) "
          + "activeVisionConfidence=\(activeSensingConfidence)"
      )
    }
    XCTAssertEqual(physical.sensorCandidate.rawSensors.count, 7)

    let fastPoint = try point(device, value: 1)
    let brainPoint = try point(device, value: 1)
    let preflightPoint = try point(device, value: 1)
    let fast = try brain.submitProvisionalAcceptedFastRoot(
      transaction,
      waitFor: physical.physicalPreparedPoint,
      signal: fastPoint
    )
    let developmentalIntents = try developmentalIntentLease(
      device: device,
      codes: developmentalCapabilityCodes,
      timestamp: transaction.token.targetTimestamp,
      fingerprintXor: developmentalIntentFingerprintXor
    )
    let prepared = try brain.submitNumanXPreparedControl(
      transaction,
      provisionalFast: fast,
      identity: physical.identity,
      acceptedPhysicsGate: physical.acceptedPhysicsGate,
      sensorCandidate: physical.sensorCandidate,
      developmentalIntents: developmentalIntents,
      signal: brainPoint,
      thenSignal: preflightPoint
    )
    _ = try prepared.waitUntilBrainPrepareCompleted(timeoutMilliseconds: 10_000)
    let preflightStatus = waitForPreflight(prepared)
    guard preflightStatus == .numanXPreflightReady else {
      throw TissueError.transaction(
        prepared.preflightFailureDescription
          ?? "NumanX preflight settled as \(preflightStatus)"
      )
    }
    return (
      physical,
      prepared,
      motorExcitations,
      descendingSomatic,
      activeSensingCommand,
      activeSensingConfidence
    )
  }

  private func developmentalIntentLease(
    device: any MTLDevice,
    codes: [UInt64],
    timestamp: BrainTimestamp,
    fingerprintXor: UInt64 = 0
  ) throws -> MetalDevelopmentalCapabilityIntentBufferLease? {
    guard !codes.isEmpty else { return nil }
    let records = try codes.map { code in
      var record = try MetalDevelopmentalCapabilityIntentRecord(
        code: code,
        timestamp: timestamp,
        confidence: 1
      )
      record.intentFingerprint ^= fingerprintXor
      return record
    }
    let byteCount = records.count
      * MetalDevelopmentalCapabilityIntentRecord.byteCount
    guard let buffer = device.makeBuffer(
      length: byteCount,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ) else {
      throw TissueError.metal("failed to allocate developmental intent buffer")
    }
    records.withUnsafeBytes { bytes in
      if let source = bytes.baseAddress {
        buffer.contents().copyMemory(from: source, byteCount: bytes.count)
      }
    }
    return try MetalDevelopmentalCapabilityIntentBufferLease(
      buffer: buffer,
      intentCount: records.count,
      timestamp: timestamp
    )
  }

  private struct BridgePaths {
    let library: String
    let rigid: String
    let muscle: String
    let contacts: String
    let visualPack: String
    let visionProfile: String
    let metalRoboMetallib: String
    let matterMetallib: String
    let material: String
  }

  private func bridgePaths() throws -> BridgePaths {
    let environment = ProcessInfo.processInfo.environment
    let keys = [
      "NUMANX_METALROBO_LIBRARY", "NUMANX_FULLBODY_RIGID",
      "NUMANX_FULLBODY_MUSCLE", "NUMANX_METALROBO_METALLIB",
      "NUMANX_FULLBODY_CONTACT", "NUMANX_MATTER_METALLIB",
      "NUMANX_FULLBODY_VISUAL_PACK", "NUMANX_FULLBODY_VISION_PROFILE",
      "NUMANX_MATTER_MATERIAL",
    ]
    guard keys.allSatisfy({ !(environment[$0] ?? "").isEmpty }) else {
      throw XCTSkip("real NumanX bridge paths are not configured")
    }
    return BridgePaths(
      library: environment[keys[0]]!, rigid: environment[keys[1]]!,
      muscle: environment[keys[2]]!, contacts: environment[keys[4]]!,
      visualPack: environment[keys[6]]!, visionProfile: environment[keys[7]]!,
      metalRoboMetallib: environment[keys[3]]!,
      matterMetallib: environment[keys[5]]!, material: environment[keys[8]]!
    )
  }

  private func point(
    _ device: any MTLDevice,
    value: UInt64
  ) throws -> MetalSharedEventPoint {
    guard let event = device.makeSharedEvent() else {
      throw TissueError.metal("failed to allocate NumanX test event")
    }
    return try MetalSharedEventPoint(event: event, value: value)
  }

  // Test-only replay evidence. Production authority never reads these shared
  // payloads on the host; it consumes the accepted token and sensors on GPU.
  private func acceptedGateBytes(
    _ gate: MetalAcceptedPhysicsGateLease
  ) -> [UInt8] {
    Array(UnsafeRawBufferPointer(
      start: gate.buffer.contents().advanced(by: gate.byteOffset),
      count: MetalAcceptedPhysicsGateLease.byteCount
    ))
  }

  // Test-only evidence for private native sensor bytes. Production consumers
  // retain and bind these ranges on GPU; they never synchronize or copy them
  // through the host.
  private func qualificationReadback(
    _ range: MetalNumanXHumanIOCandidateRangeLease,
    device: any MTLDevice
  ) throws -> [UInt8] {
    guard let staging = device.makeBuffer(
      length: range.byteCount,
      options: [.storageModeShared, .hazardTrackingModeTracked]
    ), let queue = device.makeCommandQueue(),
      let commandBuffer = queue.makeCommandBuffer(),
      let blit = commandBuffer.makeBlitCommandEncoder()
    else {
      throw TissueError.metal("failed to allocate qualification readback")
    }
    blit.copy(
      from: range.buffer, sourceOffset: range.byteOffset,
      to: staging, destinationOffset: 0, size: range.byteCount
    )
    blit.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    guard commandBuffer.status == .completed else {
      throw TissueError.metal("qualification readback command failed")
    }
    return Array(UnsafeRawBufferPointer(
      start: staging.contents(), count: staging.length
    ))
  }

  private func qualificationReadback(
    _ buffer: any MTLBuffer,
    device: any MTLDevice
  ) throws -> [UInt8] {
    let object = Unmanaged.passUnretained(buffer as AnyObject).toOpaque()
    let range = try MetalNumanXHumanIOCandidateRangeLease(
      buffer: buffer,
      metalBufferObject: object,
      gpuAddress: buffer.gpuAddress,
      byteOffset: 0,
      byteCount: buffer.length,
      elementType: MetalNumanXHumanIOCandidateRangeLease.float32ElementType,
      elementByteCount: UInt32(MemoryLayout<Float>.stride)
    )
    return try qualificationReadback(range, device: device)
  }

  private func qualificationUInt32s(from bytes: [UInt8]) throws -> [UInt32] {
    guard bytes.count.isMultiple(of: MemoryLayout<UInt32>.stride) else {
      throw TissueError.transaction("qualification UInt32 range is malformed")
    }
    return bytes.withUnsafeBytes { raw in
      stride(from: 0, to: raw.count, by: MemoryLayout<UInt32>.stride).map {
        raw.loadUnaligned(fromByteOffset: $0, as: UInt32.self)
      }
    }
  }

  private func sensorPayloadBytes(
    _ candidate: MetalNumanXPendingSensorCandidateLease
  ) -> [UInt8] {
    candidate.rawSensors.flatMap { sensor in
      var result = Array(UnsafeRawBufferPointer(
        start: sensor.buffer.contents(), count: sensor.buffer.length
      ))
      if let validity = sensor.validityBuffer {
        result.append(contentsOf: UnsafeRawBufferPointer(
          start: validity.contents(), count: validity.length
        ))
      }
      return result
    }
  }

  private func bootstrapSensorPacket(
    device: any MTLDevice,
    compiled: CompiledSpeciesTemplate,
    transaction: BrainJointTransactionToken
  ) throws -> NumanXSensorPacketLease {
    let sensors = try compiled.species.senses.filter(\.enabled).map { topology in
      let scalarCount = Int(topology.receptorCount)
        * Int(topology.observationDimension)
      guard let values = device.makeBuffer(
        length: scalarCount * MemoryLayout<Float>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ), let validity = device.makeBuffer(
        length: Int(topology.receptorCount) * MemoryLayout<UInt32>.stride,
        options: [.storageModeShared, .hazardTrackingModeTracked]
      ) else {
        throw TissueError.metal("failed to allocate bootstrap HumanIO sensors")
      }
      values.contents().assumingMemoryBound(to: Float.self).initialize(
        repeating: topology.modality == .proprioception ? 0.25 : 0.5,
        count: scalarCount
      )
      validity.contents().assumingMemoryBound(to: UInt32.self).initialize(
        repeating: 1,
        count: Int(topology.receptorCount)
      )
      return try MetalRawSensorBufferLease(
        buffer: values,
        modality: topology.modality,
        receptorTimestamp: BrainTimestamp(
          microseconds: transaction.committedTimestamp.rawValue
            - UInt64(topology.latencyMicroseconds)
        ),
        receptorCount: topology.receptorCount,
        featureDimension: topology.observationDimension,
        validityBuffer: validity
      )
    }
    return try NumanXSensorPacketLease(
      transaction: transaction,
      compiledSpeciesTemplate: compiled,
      rawSensors: sensors
    )
  }

  private func waitForPreflight(
    _ ticket: MetalNumiBrainRuntime.NumanXPreparedControlTicket
  ) -> MetalNumiBrainRuntime.ControlTransaction.Status {
    let deadline = Date(timeIntervalSinceNow: 10)
    var status = ticket.status
    while status == .numanXPrepareSubmitted, Date() < deadline {
      Thread.sleep(forTimeInterval: 0.001)
      status = ticket.status
    }
    return status
  }

  private func waitForClose(
    _ ticket: MetalNumiBrainRuntime.NumanXPreparedControlTicket
  ) -> MetalNumiBrainRuntime.ControlTransaction.Status {
    let deadline = Date(timeIntervalSinceNow: 10)
    var status = ticket.status
    while status != .committed, status != .aborted,
      status != .terminalQuarantined,
      status != .numanXAppliedValidationRetryRequired,
      Date() < deadline
    {
      Thread.sleep(forTimeInterval: 0.001)
      status = ticket.status
    }
    return status
  }
}

@available(macOS 26.0, *)
private final class AsyncResultLatch<Value: Sendable>: @unchecked Sendable {
  private let condition = NSCondition()
  private var result: Result<Value, Error>?

  func complete(_ value: Result<Value, Error>) {
    condition.lock()
    guard result == nil else {
      condition.unlock()
      return
    }
    result = value
    condition.broadcast()
    condition.unlock()
  }

  func wait(timeout: TimeInterval = 10) throws -> Value {
    condition.lock()
    defer { condition.unlock() }
    let deadline = Date(timeIntervalSinceNow: timeout)
    while result == nil, condition.wait(until: deadline) {}
    guard let result else {
      throw TissueError.transaction("NumanX callback did not settle before timeout")
    }
    return try result.get()
  }
}

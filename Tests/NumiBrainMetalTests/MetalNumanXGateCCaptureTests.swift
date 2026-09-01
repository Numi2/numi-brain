import Foundation
import Metal
import XCTest

@testable import NumiBrainCore
@_spi(NumanXInterop) @testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalNumanXGateCCaptureTests: XCTestCase {
  func testFullBodySparseModalitiesUseCompactNonGateSlots() throws {
    let compiled = try NumanXFullBodyTransportTemplate.compile()
    let modalities = compiled.species.senses.filter(\.enabled).map(\.modality)
    let slots = try MetalSensoryTransductionRuntime.compactInputSlots(
      for: modalities
    )
    XCTAssertEqual(slots.count, 7)
    XCTAssertEqual(slots[.vision], 0)
    XCTAssertEqual(slots[.interoception], 5)
    XCTAssertEqual(slots[.kinesthesia], 6)
    XCTAssertTrue(slots.values.allSatisfy { $0 >= 0 && $0 < 8 })
    XCTAssertTrue(slots.values.allSatisfy { $0 + 12 < 20 })
    XCTAssertThrowsError(try MetalSensoryTransductionRuntime.compactInputSlots(
      for: modalities + [.vision]
    ))
  }
  func testSettledFullBodySampleWritesExactContentAddressedArtifacts() throws {
    guard let device = MTLCreateSystemDefaultDevice() else {
      throw XCTSkip("Metal is unavailable")
    }
    let compiled = try NumanXFullBodyTransportTemplate.compile()
    let transaction = try BrainJointTransactionToken(
      environmentIdentifier: 0,
      episodeIdentifier: 41,
      controlStepIdentifier: 1,
      parameterVersionFingerprint: 0x4e58_4743_5041_0001,
      baseBrainGeneration: 0,
      basePhysicsGeneration: 0,
      committedTimestamp: BrainTimestamp(microseconds: 10_000),
      targetTimestamp: BrainTimestamp(microseconds: 11_000),
      randomCounterGeneration: 1
    )
    let rawSensors = try compiled.species.senses.filter(\.enabled).map {
      topology in
      let scalarCount = Int(topology.receptorCount)
        * Int(topology.observationDimension)
      guard let values = device.makeBuffer(
        length: scalarCount * MemoryLayout<Float>.stride,
        options: .storageModeShared
      ) else {
        throw TissueError.metal("failed to allocate Gate C capture values")
      }
      let words = values.contents().assumingMemoryBound(to: UInt32.self)
      for index in 0..<scalarCount {
        words[index] = UInt32(index) ^ UInt32(topology.modality.rawValue)
      }
      let validity: (any MTLBuffer)?
      if topology.modality == .proprioception {
        guard let buffer = device.makeBuffer(
          length: Int(topology.receptorCount) * MemoryLayout<UInt32>.stride,
          options: .storageModeShared
        ) else {
          throw TissueError.metal("failed to allocate Gate C validity")
        }
        buffer.contents().assumingMemoryBound(to: UInt32.self).initialize(
          repeating: 1,
          count: Int(topology.receptorCount)
        )
        validity = buffer
      } else {
        validity = nil
      }
      return try MetalRawSensorBufferLease(
        buffer: values,
        modality: topology.modality,
        receptorTimestamp: BrainTimestamp(
          microseconds: 10_000 - UInt64(topology.latencyMicroseconds)
        ),
        receptorCount: topology.receptorCount,
        featureDimension: topology.observationDimension,
        validityBuffer: validity
      )
    }
    let sensors = try NumanXSensorPacketLease(
      transaction: transaction,
      compiledSpeciesTemplate: compiled,
      rawSensors: rawSensors
    )
    let coordinates = try BrainPolicyNumanXDatasetCoordinates(
      datasetSourceIdentifier: "numanx-gate-c-capture-test",
      datasetSourceRevision: "test-revision",
      episodeIdentifier: 41,
      taskFingerprint: 0x101,
      sceneFingerprint: 0x102,
      objectFingerprint: 0x103,
      embodimentFingerprint: 0x104
    )
    let directory = FileManager.default.temporaryDirectory.appending(
      path: UUID().uuidString,
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: directory) }

    let first = try MetalNumanXGateCCapture.writeSettledRootSample(
      transaction: transaction,
      sensors: sensors,
      coordinates: coordinates,
      artifactDirectory: directory
    )
    let replay = try MetalNumanXGateCCapture.writeSettledRootSample(
      transaction: transaction,
      sensors: sensors,
      coordinates: coordinates,
      artifactDirectory: directory
    )
    XCTAssertEqual(first.sampleSHA256, replay.sampleSHA256)
    let manifestURL = try BrainPolicyEvidenceArtifact.url(
      forSHA256: first.sampleSHA256,
      in: directory
    )
    let manifest = try BrainPolicyNumanXRootSampleArtifact.decode(
      Data(contentsOf: manifestURL)
    )
    XCTAssertEqual(manifest.channels.count, 7)
    XCTAssertEqual(manifest.transactionFingerprint, transaction.fingerprint)
    XCTAssertEqual(manifest.coordinates, coordinates)
    for channel in manifest.channels {
      XCTAssertTrue(FileManager.default.fileExists(atPath:
        try BrainPolicyEvidenceArtifact.url(
          forSHA256: channel.valuesSHA256,
          in: directory
        ).path()
      ))
      if let validitySHA256 = channel.validitySHA256 {
        XCTAssertTrue(FileManager.default.fileExists(atPath:
          try BrainPolicyEvidenceArtifact.url(
            forSHA256: validitySHA256,
            in: directory
          ).path()
        ))
      }
    }

    let firstSensor = try XCTUnwrap(rawSensors.first)
    firstSensor.buffer.contents().assumingMemoryBound(to: UInt32.self)[0] ^= 1
    let mutated = try MetalNumanXGateCCapture.writeSettledRootSample(
      transaction: transaction,
      sensors: sensors,
      coordinates: coordinates,
      artifactDirectory: directory
    )
    XCTAssertNotEqual(mutated.sampleSHA256, first.sampleSHA256)
  }

  func testHealthyRawInteroceptionCannotBePromotedToCriticalByLearnedBias()
    throws
  {
    guard let device = MTLCreateSystemDefaultDevice() else {
      throw XCTSkip("Metal is unavailable")
    }
    let environment = ProcessInfo.processInfo.environment
    let requiredPaths = [
      "NUMANX_METALROBO_LIBRARY", "NUMANX_FULLBODY_RIGID",
      "NUMANX_FULLBODY_MUSCLE", "NUMANX_FULLBODY_CONTACT",
      "NUMANX_FULLBODY_VISUAL_PACK", "NUMANX_FULLBODY_VISION_PROFILE",
      "NUMANX_METALROBO_METALLIB", "NUMANX_MATTER_METALLIB",
      "NUMANX_MATTER_MATERIAL",
    ]
    guard requiredPaths.allSatisfy({ !(environment[$0] ?? "").isEmpty }) else {
      throw XCTSkip("real NumanX bridge paths are not configured")
    }
    let timestepMicroseconds: UInt32 = 10
    let compiled = try NumanXFullBodyTransportTemplate.compile(
      latencyMicroseconds: timestepMicroseconds
    )
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: compiled.species,
      tissueParameters: .corticalSheetV0
    )
    let sensoryParameters = publication.sharedArtifact.payload(.sensory).data
      .withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    XCTAssertEqual(sensoryParameters[1], 0.05)
    let directory = FileManager.default.temporaryDirectory.appending(
      path: UUID().uuidString,
      directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: false
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    let runner = try MetalNumanXGateCRootRunner(
      libraryPath: environment["NUMANX_METALROBO_LIBRARY"]!,
      bridgeConfiguration: MetalNumanXBridgeV1Runtime.Configuration(
        rigidPayloadPath: environment["NUMANX_FULLBODY_RIGID"]!,
        musclePayloadPath: environment["NUMANX_FULLBODY_MUSCLE"]!,
        supportContactPayloadPath: environment["NUMANX_FULLBODY_CONTACT"]!,
        visualPackPath: environment["NUMANX_FULLBODY_VISUAL_PACK"]!,
        visionProfilePath: environment["NUMANX_FULLBODY_VISION_PROFILE"]!,
        metalRoboMetallibPath: environment["NUMANX_METALROBO_METALLIB"]!,
        matterMetallibPath: environment["NUMANX_MATTER_METALLIB"]!,
        matterMaterialPath: environment["NUMANX_MATTER_MATERIAL"]!,
        timestepMicroseconds: UInt64(timestepMicroseconds),
        transactionSlotCount: 2
      ),
      publication: publication,
      artifactDirectory: directory,
      episodeIdentifier: 9_940,
      randomSeed: 914_040,
      device: device
    )
    XCTAssertEqual(runner.compiledSpeciesTemplate.species.body.bodyCount, 157)
    XCTAssertEqual(runner.compiledSpeciesTemplate.species.body.jointCount, 156)
    XCTAssertEqual(runner.compiledSpeciesTemplate.species.body.muscleCount, 416)
    XCTAssertEqual(
      runner.compiledSpeciesTemplate.muscleAttachmentCatalog?.attachments.count,
      416
    )
    let headAttachments = try XCTUnwrap(
      runner.compiledSpeciesTemplate.muscleAttachmentCatalog
    ).attachments.filter {
      $0.firstBodyIdentifier
          == BrainPolicyNumanXHeadPostureEvaluationArtifact.targetBodyIdentifier
        || $0.terminalBodyIdentifier
          == BrainPolicyNumanXHeadPostureEvaluationArtifact.targetBodyIdentifier
    }
    XCTAssertTrue(
      headAttachments.isEmpty,
      "head fixture unexpectedly gained a direct muscle endpoint"
    )
    let topology = runner.compiledSpeciesTemplate.jointTopologyCatalog
    let attachmentBodies = Set(
      runner.compiledSpeciesTemplate.muscleAttachmentCatalog!.attachments
        .flatMap { [$0.firstBodyIdentifier, $0.terminalBodyIdentifier] }
    )
    var nearestActuatedAncestor: UInt32?
    var targetChainCoordinateCounts: [Int] = []
    var targetAncestorDistances: [UInt32: Int] = [
      BrainPolicyNumanXHeadPostureEvaluationArtifact.targetBodyIdentifier: 0
    ]
    var body = BrainPolicyNumanXHeadPostureEvaluationArtifact
      .targetBodyIdentifier
    for _ in 0..<topology.bodyCount {
      guard let joint = topology.joints.first(where: {
        $0.childBodyIdentifier == body
      }) else { break }
      let parent = joint.parentBodyIdentifier
      targetChainCoordinateCounts.append(joint.coordinates.count)
      targetAncestorDistances[parent] = targetChainCoordinateCounts.count
      if attachmentBodies.contains(parent) {
        nearestActuatedAncestor = parent
        break
      }
      body = parent
    }
    XCTAssertNotNil(
      nearestActuatedAncestor,
      "head body has no muscle-actuated joint ancestor"
    )
    XCTAssertTrue(
      targetChainCoordinateCounts.allSatisfy { $0 == 0 },
      "head-to-actuated-ancestor path must be fixed, got coordinate counts "
        + "\(targetChainCoordinateCounts)"
    )
    let targetingAttachments = runner.compiledSpeciesTemplate
      .muscleAttachmentCatalog!.attachments.filter {
        targetAncestorDistances[$0.firstBodyIdentifier]
          != targetAncestorDistances[$0.terminalBodyIdentifier]
          && (targetAncestorDistances[$0.firstBodyIdentifier] != nil
            || targetAncestorDistances[$0.terminalBodyIdentifier] != nil)
      }
    XCTAssertFalse(
      targetingAttachments.isEmpty,
      "fixed head chain has no signed anatomical muscle endpoint"
    )
    XCTAssertFalse(
      runner.compiledSpeciesTemplate.sensoryProfile.muscleReceptorBindings
        .isEmpty
    )
    XCTAssertNotEqual(
      runner.compiledSpeciesTemplate.somaticSynergyCatalog.fingerprint,
      try SomaticSynergyCatalog.runtimeFoundationFixture(
        actuatorCount: 416,
        synergyCount: 16
      ).fingerprint
    )
    let coordinates = try BrainPolicyNumanXDatasetCoordinates(
      datasetSourceIdentifier: "numanx-raw-vital-regression",
      datasetSourceRevision: String(repeating: "a", count: 64),
      episodeIdentifier: 9_940,
      taskFingerprint: 0x6761_7465_635f_6001,
      sceneFingerprint: 0x6761_7465_635f_7005,
      objectFingerprint: 0x6761_7465_635f_6003,
      embodimentFingerprint: 0x6761_7465_635f_6004
    )

    func headPostureGoal(
      controlStep: UInt32,
      committedMicroseconds: UInt64,
      targetMicroseconds: UInt64
    ) throws -> ActiveGoal {
      var target = [Float](repeating: 0, count: 16)
      target[2] = 0.25
      target[6] = 0.10
      target[10] = 0.05
      target[14] = 0.20
      return try ActiveGoal(
        identifier: 0x0047_4348_4541_0000 | UInt64(controlStep),
        origin: .externalTask,
        targetState: BrainLatentVector(values: target, expectedCount: 16),
        priority: 10,
        deadline: BrainTimestamp(microseconds: targetMicroseconds),
        successModel: BrainLatentVector(values: target, expectedCount: 16),
        failureModel: BrainLatentVector(
          values: target.map { -$0 }, expectedCount: 16
        ),
        damageRiskBudget: 1,
        persistence: 1,
        createdTimestamp: BrainTimestamp(microseconds: committedMicroseconds),
        targetBodyIdentifier:
          BrainPolicyNumanXHeadPostureEvaluationArtifact.targetBodyIdentifier
      )
    }

    let initial = try runner.runAcceptedRoot(
      controlStep: 1,
      coordinates: coordinates,
      externalGoal: try headPostureGoal(
        controlStep: 1,
        committedMicroseconds: 10,
        targetMicroseconds: 20
      )
    )
    let probe = try runner.runAcceptedRoot(
      controlStep: 2, coordinates: coordinates,
      externalGoal: try headPostureGoal(
        controlStep: 2,
        committedMicroseconds: 20,
        targetMicroseconds: 30
      )
    )
    let settled = try runner.runAcceptedRoot(
      controlStep: 3, coordinates: coordinates,
      externalGoal: try headPostureGoal(
        controlStep: 3,
        committedMicroseconds: 30,
        targetMicroseconds: 40
      )
    )
    let initialActionURL = try BrainPolicyEvidenceArtifact.url(
      forSHA256: initial.motorActionArtifactSHA256,
      in: directory
    )
    let initialAction = try BrainPolicyNumanXMotorActionArtifact.decode(
      Data(contentsOf: initialActionURL)
    )
    let actionURL = try BrainPolicyEvidenceArtifact.url(
      forSHA256: settled.motorActionArtifactSHA256,
      in: directory
    )
    let action = try BrainPolicyNumanXMotorActionArtifact.decode(
      Data(contentsOf: actionURL)
    )
    let probeActionURL = try BrainPolicyEvidenceArtifact.url(
      forSHA256: probe.motorActionArtifactSHA256,
      in: directory
    )
    let probeAction = try BrainPolicyNumanXMotorActionArtifact.decode(
      Data(contentsOf: probeActionURL)
    )
    XCTAssertEqual(action.controlStep, 3)
    XCTAssertEqual(
      action.protectiveFlags,
      ProtectiveMotorOutputFlags.valid.rawValue
    )
    XCTAssertEqual(action.protectiveInterruptMask, 0)
    XCTAssertEqual(action.motorInhibition, 0)
    XCTAssertEqual(
      action.actuatorCommands.count,
      Int(NumanXFullBodyTransportTemplate.actuatorCount)
    )
    XCTAssertTrue(action.actuatorCommands.contains { $0 > 0 })
    let orderedIdentificationMuscles = targetingAttachments.sorted {
      let lhsDistance = min(
        targetAncestorDistances[$0.firstBodyIdentifier] ?? Int.max,
        targetAncestorDistances[$0.terminalBodyIdentifier] ?? Int.max
      )
      let rhsDistance = min(
        targetAncestorDistances[$1.firstBodyIdentifier] ?? Int.max,
        targetAncestorDistances[$1.terminalBodyIdentifier] ?? Int.max
      )
      return lhsDistance == rhsDistance
        ? $0.muscleIdentifier < $1.muscleIdentifier
        : lhsDistance < rhsDistance
    }
    let identificationMuscle = try XCTUnwrap(
      orderedIdentificationMuscles.first
    )
    XCTAssertGreaterThanOrEqual(
      orderedIdentificationMuscles.count, 2,
      "head-chain identification needs a second independently testable actuator"
    )
    let identificationIndex = Int(identificationMuscle.muscleIdentifier)
    XCTAssertEqual(
      initialAction.learnedDescendingCommands[identificationIndex], 0,
      "the first root acted before target-body evidence was accepted"
    )
    XCTAssertTrue(
      initialAction.learnedDescendingCommands.allSatisfy { $0 == 0 },
      "the first anatomical root must hold zero learned drive until its "
        + "target-body belief is available"
    )
    let probedActuators = probeAction.learnedDescendingCommands.indices.filter {
      abs(probeAction.learnedDescendingCommands[$0]) > 1e-10
    }
    XCTAssertEqual(
      probedActuators, [identificationIndex],
      "anatomical identification was not confined to the nearest actuator"
    )
    XCTAssertGreaterThan(
      probeAction.learnedDescendingCommands[identificationIndex], 0
    )
    XCTAssertLessThanOrEqual(
      probeAction.learnedDescendingCommands[identificationIndex], 0.02,
      "anatomical identification exceeded its bounded probe"
    )
    XCTAssertTrue(
      action.learnedDescendingCommands.allSatisfy { $0.isFinite && abs($0) <= 1 }
    )
    let secondIdentificationIndex = Int(
      orderedIdentificationMuscles[1].muscleIdentifier
    )
    let settledProbedActuators = action.learnedDescendingCommands.indices.filter {
      abs(action.learnedDescendingCommands[$0]) > 1e-10
    }
    XCTAssertEqual(
      settledProbedActuators, [secondIdentificationIndex],
      "one muscle-model residual globally stopped or broadened identification"
    )
    XCTAssertGreaterThan(
      action.learnedDescendingCommands[secondIdentificationIndex], 0
    )
    XCTAssertLessThanOrEqual(
      action.learnedDescendingCommands[secondIdentificationIndex], 0.02
    )
  }
}

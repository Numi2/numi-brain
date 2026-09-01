import Foundation
import XCTest

@testable import NumiBrainCore

final class NumanXGateCArtifactTests: XCTestCase {
  func testProductionFullBodyTransportShapeIsExact() throws {
    let compiled = try NumanXFullBodyTransportTemplate.compile()
    XCTAssertEqual(compiled.species.motor.actuatorCount, 416)
    XCTAssertEqual(compiled.species.motor.synergyCount, 16)
    XCTAssertEqual(compiled.species.motor.activeSensingActionDimension, 1)
    let senses = Dictionary(
      uniqueKeysWithValues: compiled.species.senses.map { ($0.modality, $0) }
    )
    XCTAssertEqual(senses[.proprioception]?.receptorCount, 416)
    XCTAssertEqual(senses[.proprioception]?.observationDimension, 10)
    XCTAssertEqual(senses[.kinesthesia]?.receptorCount, 128)
    XCTAssertEqual(senses[.kinesthesia]?.observationDimension, 7)
    XCTAssertEqual(senses[.vestibular]?.observationDimension, 22)
    XCTAssertEqual(senses[.audition]?.receptorCount, 24)
    XCTAssertEqual(senses[.vision]?.receptorCount, 64 * 48)
    XCTAssertEqual(senses[.vision]?.observationDimension, 8)
    XCTAssertEqual(senses[.touch]?.receptorCount, 10)
    XCTAssertEqual(senses[.interoception]?.receptorCount, 416)
    XCTAssertFalse(try XCTUnwrap(senses[.olfaction]).enabled)
    XCTAssertThrowsError(
      try NumanXFullBodyTransportTemplate.compile(latencyMicroseconds: 0)
    )
  }

  func testRootSampleManifestIsCanonicalAndContentAddressed() throws {
    let channel = try BrainPolicyNumanXSensorChannelArtifact(
      modality: .kinesthesia,
      receptorTimestampMicroseconds: 9_000,
      receptorCount: 1,
      featureDimension: 2,
      valuesByteCount: 8,
      valuesSHA256: String(repeating: "a", count: 64)
    )
    let coordinates = try BrainPolicyNumanXDatasetCoordinates(
      datasetSourceIdentifier: "numanx-gate-c-local-v1",
      datasetSourceRevision: "test-revision",
      episodeIdentifier: 1,
      taskFingerprint: 2,
      sceneFingerprint: 3,
      objectFingerprint: 4,
      embodimentFingerprint: 5
    )
    let artifact = try BrainPolicyNumanXRootSampleArtifact(
      coordinates: coordinates,
      transactionFingerprint: 6,
      controlStep: 7,
      committedTimestampMicroseconds: 10_000,
      targetTimestampMicroseconds: 11_000,
      basePhysicsGeneration: 8,
      acceptedPhysicsTokenFingerprint: 0,
      physicsGeneration: 8,
      speciesTemplateFingerprint: 9,
      sensoryProfileFingerprint: 10,
      sensorPacketFingerprint: 11,
      channels: [channel]
    )
    let encoded = try artifact.encoded()
    XCTAssertEqual(try BrainPolicyNumanXRootSampleArtifact.decode(encoded), artifact)
    XCTAssertEqual(
      try artifact.sampleSHA256,
      BrainPolicyEvidenceArtifact.sha256(encoded)
    )
    let directory = FileManager.default.temporaryDirectory.appending(
      path: UUID().uuidString,
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    let hash = try artifact.write(to: directory)
    XCTAssertEqual(hash, try artifact.sampleSHA256)
    XCTAssertEqual(
      try Data(contentsOf: BrainPolicyEvidenceArtifact.url(
        forSHA256: hash,
        in: directory
      )),
      encoded
    )
    XCTAssertThrowsError(try BrainPolicyNumanXRootSampleArtifact(
      coordinates: coordinates,
      transactionFingerprint: 6,
      controlStep: 7,
      committedTimestampMicroseconds: 10_000,
      targetTimestampMicroseconds: 11_000,
      basePhysicsGeneration: UInt64.max,
      acceptedPhysicsTokenFingerprint: 1,
      physicsGeneration: 0,
      speciesTemplateFingerprint: 9,
      sensoryProfileFingerprint: 10,
      sensorPacketFingerprint: 11,
      channels: [channel]
    ))
  }

  func testRetainedLearningBatchRecomputesExactMetalFingerprints() throws {
    let versions: [UInt32] = [11, 2, 2, 3, 1, 1, 1, 1, 2]
    let sectionData = Dictionary(uniqueKeysWithValues: (UInt16(1)...9).map {
      ($0, Data([UInt8($0), UInt8($0 &* 7)]))
    })
    let sections = try (UInt16(1)...9).map { identifier in
      try BrainPolicyNumanXLearningBatchSectionArtifact(
        sectionIdentifier: identifier,
        recordFormatVersion: versions[Int(identifier - 1)],
        elementCount: 1,
        elementStride: 2,
        byteCount: 2,
        contentSHA256: BrainPolicyEvidenceArtifact.sha256(
          try XCTUnwrap(sectionData[identifier])
        )
      )
    }
    func mix(_ value: UInt64, into hash: inout UInt64) {
      var littleEndian = value.littleEndian
      withUnsafeBytes(of: &littleEndian) { bytes in
        for byte in bytes {
          hash ^= UInt64(byte)
          hash &*= 1_099_511_628_211
        }
      }
    }
    for sourceGeneration in [UInt64(0), UInt64(3)] {
      var metadata: UInt64 = 14_695_981_039_346_656_037
      for value in [
        UInt64(12), UInt64(11), UInt64(2), UInt64(3), UInt64(1),
        UInt64(1), UInt64(1), sourceGeneration, UInt64(2), UInt64(5),
        UInt64(6), UInt64(7), UInt64(8), UInt64(9),
      ] {
        mix(value, into: &metadata)
      }
      var content: UInt64 = 14_695_981_039_346_656_037
      for section in sections {
        mix(UInt64(section.sectionIdentifier), into: &metadata)
        mix(section.elementCount, into: &metadata)
        mix(section.elementStride, into: &metadata)
        mix(section.byteCount, into: &metadata)
        mix(UInt64(section.sectionIdentifier), into: &content)
        for byte in try XCTUnwrap(sectionData[section.sectionIdentifier]) {
          content ^= UInt64(byte)
          content &*= 1_099_511_628_211
        }
      }
      var batch = metadata
      mix(content, into: &batch)
      let artifact = try BrainPolicyNumanXLearningBatchArtifact(
        learningBatchFormatVersion: 12,
        sourceGeneration: sourceGeneration,
        speciesTemplateFingerprint: 6,
        regionalProgramFingerprint: 7,
        scheduleFingerprint: 8,
        parameterVersionFingerprint: 9,
        regionalModuleCount: 5,
        metadataFingerprint: metadata,
        contentFingerprint: content,
        batchFingerprint: batch,
        sections: sections
      )
      XCTAssertNoThrow(try BrainPolicyNumanXCaptureVerifier
        .validateLearningBatchFingerprints(artifact, sectionData: sectionData))
      var corrupted = sectionData
      corrupted[4] = Data([4, 29])
      XCTAssertThrowsError(try BrainPolicyNumanXCaptureVerifier
        .validateLearningBatchFingerprints(artifact, sectionData: corrupted))
    }
  }

  func testCaptureRunRetainsExactTimestepWithoutBreakingLegacyEncoding() throws {
    let root = try BrainPolicyNumanXCaptureRootReference(
      controlStep: 1,
      sampleSHA256: String(repeating: "a", count: 64),
      executionSHA256: String(repeating: "b", count: 64)
    )
    func run(
      timestep: UInt32?,
      latencyBudget: UInt64? = nil
    ) throws -> BrainPolicyNumanXCaptureRunArtifact {
      try BrainPolicyNumanXCaptureRunArtifact(
        runIdentifier: "timestep-test",
        sourceRevision: "revision",
        datasetSourceIdentifier: "dataset",
        datasetSourceRevision: "dataset-revision",
        deviceRegistryID: 1,
        nativeModelSourceFingerprint: 2,
        acceptedStateProofProgramFingerprint: 3,
        compiledSpeciesTemplateFingerprint: 4,
        parameterVersionFingerprint: 5,
        timestepMicroseconds: timestep,
        declaredMaximumInferenceLatencyMicroseconds: latencyBudget,
        learningBatchArtifactSHA256: String(repeating: "c", count: 64),
        learningBatchFingerprint: 6,
        roots: [root]
      )
    }
    let legacy = try run(timestep: nil)
    let retained = try run(timestep: 100)
    let predeclared = try run(timestep: 100, latencyBudget: 20_000)
    XCTAssertNil(legacy.timestepMicroseconds)
    XCTAssertEqual(retained.timestepMicroseconds, 100)
    XCTAssertEqual(
      predeclared.declaredMaximumInferenceLatencyMicroseconds,
      20_000
    )
    XCTAssertFalse(String(decoding: try legacy.encoded(), as: UTF8.self)
      .contains("timestepMicroseconds"))
    XCTAssertTrue(String(decoding: try retained.encoded(), as: UTF8.self)
      .contains("\"timestepMicroseconds\":100"))
    XCTAssertTrue(String(decoding: try predeclared.encoded(), as: UTF8.self)
      .contains("\"declaredMaximumInferenceLatencyMicroseconds\":20000"))
    XCTAssertEqual(
      try BrainPolicyNumanXCaptureRunArtifact.decode(legacy.encoded()),
      legacy
    )
    XCTAssertEqual(
      try BrainPolicyNumanXCaptureRunArtifact.decode(retained.encoded()),
      retained
    )
    XCTAssertThrowsError(try run(timestep: 0))
    XCTAssertThrowsError(try run(timestep: 100, latencyBudget: 0))
  }

  func testOODEvaluationUsesExactPredeclaredMetricsAndClasses() throws {
    let observations = try (0..<40).map { index in
      try BrainPolicyMetricObservation(
        sampleSHA256: String(format: "%064x", index + 1),
        value: index < 20 ? 0.01 : 1.0,
        referenceClass: index < 20 ? 0 : 1
      )
    }
    let oodSamples = Array(observations.suffix(20))
    let artifact = try BrainPolicyNumanXOODEvaluationArtifact(
      candidateArtifactSHA256: String(repeating: "a", count: 64),
      captureRunArtifactSHA256: String(repeating: "b", count: 64),
      metrics: [
        try BrainPolicyQualificationMetricEvidence(
          identifier: "ood_auroc", unit: "ratio", reducer: .binaryAUROC,
          threshold: 0.9, direction: .atLeast, observations: observations
        ),
        try BrainPolicyQualificationMetricEvidence(
          identifier: "supervision_or_reject_recall", unit: "ratio",
          reducer: .mean, threshold: 0.95, direction: .atLeast,
          observations: oodSamples.map {
            try BrainPolicyMetricObservation(
              sampleSHA256: $0.sampleSHA256, value: 1
            )
          }
        ),
        try BrainPolicyQualificationMetricEvidence(
          identifier: "unsafe_accept_rate", unit: "ratio", reducer: .maximum,
          threshold: 0.01, direction: .atMost,
          observations: oodSamples.map {
            try BrainPolicyMetricObservation(
              sampleSHA256: $0.sampleSHA256, value: 0
            )
          }
        ),
      ]
    )
    XCTAssertTrue(artifact.passesPredeclaredThresholds)
    XCTAssertEqual(
      try BrainPolicyNumanXOODEvaluationArtifact.decode(artifact.encoded()),
      artifact
    )
    XCTAssertThrowsError(try BrainPolicyNumanXOODEvaluationArtifact(
      candidateArtifactSHA256: String(repeating: "a", count: 64),
      captureRunArtifactSHA256: String(repeating: "b", count: 64),
      metrics: artifact.metrics.map { metric in
        metric.identifier == "ood_auroc"
          ? try BrainPolicyQualificationMetricEvidence(
              identifier: metric.identifier, unit: metric.unit,
              reducer: metric.reducer, threshold: 0.89,
              direction: metric.direction, observations: metric.observations
            ) : metric
      }
    ))
  }

  func testHardSafetyEvaluationUsesExactZeroToleranceContract() throws {
    let observations = try (0..<20).map { index in
      try BrainPolicyMetricObservation(
        sampleSHA256: String(format: "%064x", index + 1),
        value: 0
      )
    }
    let artifact = try BrainPolicyNumanXHardSafetyEvaluationArtifact(
      candidateArtifactSHA256: String(repeating: "a", count: 64),
      captureRunArtifactSHA256: String(repeating: "b", count: 64),
      metrics: [
        try BrainPolicyQualificationMetricEvidence(
          identifier: "protective_bypass_count", unit: "count",
          reducer: .maximum, threshold: 0, direction: .atMost,
          observations: observations
        ),
        try BrainPolicyQualificationMetricEvidence(
          identifier: "safety_violation_rate", unit: "ratio",
          reducer: .maximum, threshold: 0, direction: .atMost,
          observations: observations
        ),
      ]
    )
    XCTAssertTrue(artifact.passesPredeclaredThresholds)
    XCTAssertEqual(
      try BrainPolicyNumanXHardSafetyEvaluationArtifact.decode(
        artifact.encoded()
      ),
      artifact
    )
    XCTAssertThrowsError(try BrainPolicyNumanXHardSafetyEvaluationArtifact(
      candidateArtifactSHA256: String(repeating: "a", count: 64),
      captureRunArtifactSHA256: String(repeating: "b", count: 64),
      metrics: artifact.metrics.map { metric in
        metric.identifier == "protective_bypass_count"
          ? try BrainPolicyQualificationMetricEvidence(
              identifier: metric.identifier, unit: metric.unit,
              reducer: metric.reducer, threshold: 1,
              direction: metric.direction, observations: metric.observations
            ) : metric
      }
    ))
  }

  func testSupportContactVariantIsContentAddressedAndPreservesWitnesses() throws {
    var bytes = [UInt8](repeating: 0, count: 84 + 48)
    func storeUInt32(_ value: UInt32, _ offset: Int) {
      bytes[offset] = UInt8(truncatingIfNeeded: value)
      bytes[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
      bytes[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
      bytes[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
    }
    func storeFloat(_ value: Float, _ offset: Int) {
      storeUInt32(value.bitPattern, offset)
    }
    bytes.replaceSubrange(0..<8, with: Array("NHCNT1\0\0".utf8))
    storeUInt32(1, 8)
    storeUInt32(1, 16)
    storeFloat(1, 76)
    storeFloat(0.25, 84 + 20)
    storeFloat(-0.5, 84 + 24)
    storeFloat(0, 84 + 28)
    storeFloat(2, 84 + 36)
    let directory = FileManager.default.temporaryDirectory.appending(
      path: UUID().uuidString,
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    let source = directory.appending(path: "source.nhcnt")
    try Data(bytes).write(to: source)
    let receipt = try BrainPolicyNumanXSupportContactVariant.create(
      sourceURL: source,
      tiltDegrees: 2,
      artifactDirectory: directory
    )
    XCTAssertEqual(receipt.artifact.supportCount, 1)
    XCTAssertEqual(receipt.artifact.tiltDegrees, 2)
    XCTAssertNotEqual(
      receipt.artifact.sourceAssetSHA256,
      receipt.artifact.variantAssetSHA256
    )
    XCTAssertEqual(
      try BrainPolicyNumanXSupportContactVariantArtifact.decode(
        Data(contentsOf: BrainPolicyEvidenceArtifact.url(
          forSHA256: receipt.artifactSHA256,
          in: directory
        ))
      ),
      receipt.artifact
    )
    XCTAssertEqual(
      try BrainPolicyNumanXSupportContactVariant.verify(
        artifactSHA256: receipt.artifactSHA256,
        artifactDirectory: directory
      ),
      receipt.artifact
    )
    XCTAssertThrowsError(try BrainPolicyNumanXSupportContactVariant.create(
      sourceURL: source,
      tiltDegrees: 0,
      artifactDirectory: directory
    ))
  }

  func testSupportStabilityArtifactUsesPredeclaredPhysicalThresholds() throws {
    let thresholds = BrainPolicyNumanXSupportStabilityThresholds
      .gateCCrossSceneV1
    func observation(_ hash: Character, step: UInt32, velocity: Float)
      throws -> BrainPolicyNumanXSupportStabilityObservation
    {
      try BrainPolicyNumanXSupportStabilityObservation(
        sampleSHA256: String(repeating: String(hash), count: 64),
        controlStep: step,
        rootOutcome: .accepted,
        vestibularValidityMask: (UInt32(1) << 22) - 1,
        headGroundClearance: 1.67,
        groundNormalVelocity: velocity,
        headQuaternionNormError: 0.001,
        thresholds: thresholds
      )
    }
    let artifact = try BrainPolicyNumanXSupportStabilityEvaluationArtifact(
      candidateArtifactSHA256: String(repeating: "a", count: 64),
      contactVariantArtifactSHA256: String(repeating: "b", count: 64),
      baselineRunArtifactSHA256: String(repeating: "c", count: 64),
      learnedRunArtifactSHA256: String(repeating: "d", count: 64),
      thresholds: thresholds,
      baselineObservations: [
        try observation("e", step: 2, velocity: 0.6),
        try observation("f", step: 3, velocity: 0.1),
      ],
      learnedObservations: [
        try observation("1", step: 2, velocity: 0.1),
        try observation("2", step: 3, velocity: 0.2),
      ]
    )
    XCTAssertEqual(artifact.baselineSuccessRate, 0.5)
    XCTAssertEqual(artifact.learnedSuccessRate, 1)
    XCTAssertEqual(artifact.learnedMinusBaselineSuccessRate, 0.5)
    XCTAssertEqual(try artifact.learnedSuccessMetricEvidence.reducedValue, 1)
    XCTAssertEqual(
      try BrainPolicyNumanXSupportStabilityEvaluationArtifact.decode(
        artifact.encoded()
      ),
      artifact
    )
  }

  func testSupportReplaySeparatesSemanticEvidenceFromUniqueAuthority() throws {
    let artifact = try BrainPolicyNumanXSupportStabilityReplayArtifact(
      referenceEvaluationArtifactSHA256: String(repeating: "a", count: 64),
      replayEvaluationArtifactSHA256: String(repeating: "b", count: 64),
      candidateArtifactSHA256: String(repeating: "c", count: 64),
      contactVariantArtifactSHA256: String(repeating: "d", count: 64),
      baselineRootCount: 11,
      learnedRootCount: 11,
      transactionUniqueIdentityDifferenceCount: 22
    )
    XCTAssertTrue(artifact.exactSemanticReplay)
    XCTAssertFalse(artifact.promotable)
    XCTAssertEqual(
      try BrainPolicyNumanXSupportStabilityReplayArtifact.decode(
        artifact.encoded()
      ),
      artifact
    )
    XCTAssertThrowsError(try BrainPolicyNumanXSupportStabilityReplayArtifact(
      referenceEvaluationArtifactSHA256: String(repeating: "a", count: 64),
      replayEvaluationArtifactSHA256: String(repeating: "a", count: 64),
      candidateArtifactSHA256: String(repeating: "c", count: 64),
      contactVariantArtifactSHA256: String(repeating: "d", count: 64),
      baselineRootCount: 11,
      learnedRootCount: 11,
      transactionUniqueIdentityDifferenceCount: 0
    ))
  }

  func testInferenceLatencyUsesMetalFeedbackAndPredeclaredP99Budget() throws {
    let observations = try (1...100).map { index in
      try BrainPolicyNumanXInferenceLatencyObservation(
        sampleSHA256: BrainPolicyEvidenceArtifact.sha256(
          Data("latency-\(index)".utf8)
        ),
        controlStep: UInt32(index),
        gpuDurationMicroseconds: Double(index)
      )
    }
    let artifact = try BrainPolicyNumanXInferenceLatencyEvaluationArtifact(
      candidateArtifactSHA256: String(repeating: "a", count: 64),
      captureRunArtifactSHA256: String(repeating: "b", count: 64),
      maximumInferenceLatencyMicroseconds: 99,
      observations: Array(observations.reversed())
    )
    XCTAssertEqual(artifact.percentile99Microseconds, 99)
    XCTAssertTrue(artifact.passesDeclaredBudget)
    XCTAssertEqual(try artifact.metricEvidence.reducedValue, 99)
    XCTAssertEqual(
      try BrainPolicyNumanXInferenceLatencyEvaluationArtifact.decode(
        artifact.encoded()
      ),
      artifact
    )
    XCTAssertThrowsError(try BrainPolicyNumanXInferenceLatencyEvaluationArtifact(
      candidateArtifactSHA256: String(repeating: "a", count: 64),
      captureRunArtifactSHA256: String(repeating: "b", count: 64),
      maximumInferenceLatencyMicroseconds: 99,
      observations: Array(observations.dropLast())
    ))
  }

  func testFewShotArtifactRetainsExamplesTimeGainAndPriorPerformance() throws {
    func hash(_ label: String) -> String {
      BrainPolicyEvidenceArtifact.sha256(Data(label.utf8))
    }
    let training = try BrainPolicyNumanXAdaptationTrainingArtifact(
      parentCandidateArtifactSHA256: hash("parent"),
      adaptedCandidateArtifactSHA256: hash("adapted"),
      adaptationRunArtifactSHA256: hash("adaptation-run"),
      adaptationExampleCount: 8,
      adaptationWallClockSeconds: 0.25
    )
    XCTAssertEqual(
      try BrainPolicyNumanXAdaptationTrainingArtifact.decode(training.encoded()),
      training
    )
    let thresholds = BrainPolicyNumanXSupportStabilityThresholds
      .gateCCrossSceneV1
    func observations(_ cohort: String, successes: Int)
      throws -> [BrainPolicyNumanXSupportStabilityObservation]
    {
      try (0..<10).map { index in
        try BrainPolicyNumanXSupportStabilityObservation(
          sampleSHA256: hash("\(cohort)-\(index)"),
          controlStep: UInt32(index + 2),
          rootOutcome: .accepted,
          vestibularValidityMask: (UInt32(1) << 22) - 1,
          headGroundClearance: 1.67,
          groundNormalVelocity: index < successes ? 0.1 : 0.6,
          headQuaternionNormError: 0,
          thresholds: thresholds
        )
      }
    }
    let artifact = try BrainPolicyNumanXFewShotEvaluationArtifact(
      trainingArtifactSHA256: hash("training"),
      parentCandidateArtifactSHA256: hash("parent"),
      adaptedCandidateArtifactSHA256: hash("adapted"),
      preAdaptationRunArtifactSHA256: hash("pre-run"),
      postAdaptationRunArtifactSHA256: hash("post-run"),
      retainedPriorRunArtifactSHA256: hash("prior-run"),
      adaptationThresholds: thresholds,
      retainedPriorThresholds: thresholds,
      adaptationExampleCount: 8,
      adaptationWallClockSeconds: 0.25,
      adaptationSampleSHA256: hash("adaptation-sample"),
      preAdaptationObservations: try observations("pre", successes: 5),
      postAdaptationObservations: try observations("post", successes: 8),
      retainedPriorObservations: try observations("prior", successes: 7)
    )
    XCTAssertEqual(artifact.preAdaptationSuccessRate, 0.5)
    XCTAssertEqual(artifact.postAdaptationSuccessRate, 0.8)
    XCTAssertEqual(artifact.retainedPriorSuccessRate, 0.7)
    XCTAssertEqual(artifact.postMinusPreAdaptationSuccessRate, 0.3, accuracy: 1e-12)
    XCTAssertTrue(artifact.passesPredeclaredThresholds)
    XCTAssertTrue(artifact.demonstratesPositiveAdaptation)
    XCTAssertFalse(artifact.promotable)
    XCTAssertEqual(
      try BrainPolicyNumanXFewShotEvaluationArtifact.decode(artifact.encoded()),
      artifact
    )
  }

  func testDelayedSupportLearningBindsTaskAndFuturePhysicalConsequence() throws {
    func hash(_ label: String) -> String {
      BrainPolicyEvidenceArtifact.sha256(Data(label.utf8))
    }
    let coordinates = try BrainPolicyNumanXDatasetCoordinates(
      datasetSourceIdentifier: "delayed-support-test",
      datasetSourceRevision: "v1",
      episodeIdentifier: 7,
      taskFingerprint: 11,
      sceneFingerprint: 12,
      objectFingerprint: 13,
      embodimentFingerprint: 14
    )
    func example(_ index: Int, success: Bool)
      throws -> BrainPolicyNumanXDelayedSupportExample
    {
      try BrainPolicyNumanXDelayedSupportExample(
        startControlStep: UInt32(index * 4 + 1),
        consequenceControlStep: UInt32(index * 4 + 4),
        startSampleSHA256: hash("start-\(index)"),
        consequenceSampleSHA256: hash("end-\(index)"),
        horizonMicroseconds: 40_000,
        startVestibularValidityMask: (UInt32(1) << 22) - 1,
        startGroundNormalVelocity: 0.002,
        consequenceGroundNormalVelocity: success ? 0.004 : 0.02,
        consequenceHeadGroundClearance: 1.67,
        consequenceQuaternionNormError: 0,
        meanActuatorCommand: 0.2,
        peakActuatorCommand: 0.4,
        stabilizationDemand: success ? 0.4 : 1,
        success: success
      )
    }
    let examples = [try example(0, success: true), try example(1, success: false)]
    let artifact = try BrainPolicyNumanXDelayedSupportLearningArtifact(
      sourceRunArtifactSHA256: hash("source-run"),
      coordinates: coordinates,
      timestepMicroseconds: 10_000,
      horizonRootCount: 4,
      objectiveWeight: 8,
      thresholds: .gateCFewShotSupportV1,
      examples: Array(examples.reversed())
    )
    XCTAssertEqual(
      artifact.examples.map { $0.startControlStep },
      [UInt32(1), UInt32(5)]
    )
    XCTAssertEqual(artifact.taskFingerprint, 11)
    XCTAssertEqual(
      try BrainPolicyNumanXDelayedSupportLearningArtifact.decode(
        artifact.encoded()
      ),
      artifact
    )
    XCTAssertThrowsError(try BrainPolicyNumanXDelayedSupportLearningArtifact(
      sourceRunArtifactSHA256: hash("source-run"),
      coordinates: coordinates,
      timestepMicroseconds: 10_000,
      horizonRootCount: 1,
      objectiveWeight: 8,
      thresholds: .gateCFewShotSupportV1,
      examples: examples
    ))
  }

  func testLongHorizonRootEvidenceIsAllOrNothingAndActionIsCanonical() throws {
    func hash(_ label: String) -> String {
      BrainPolicyEvidenceArtifact.sha256(Data(label.utf8))
    }
    let action = try BrainPolicyNumanXMotorActionArtifact(
      controlStep: 9,
      protectiveFlags: 1,
      protectiveInterruptMask: 0,
      motorInhibition: 0.25,
      autonomicArousal: 0.5,
      actuatorCommandKind: 1,
      learnedDescendingCommands: [0.1, -0.2],
      actuatorCommands: [0.3, 0.4],
      autonomicCommands: [0.5],
      activeSensingCommands: [0.6]
    )
    XCTAssertEqual(
      try BrainPolicyNumanXMotorActionArtifact.decode(action.encoded()),
      action
    )
    let before = hash("memory-before")
    let after = hash("memory-after")
    let actionHash = hash("action")
    let root = try BrainPolicyNumanXCaptureRootReference(
      controlStep: 9,
      sampleSHA256: hash("sample"),
      executionSHA256: hash("execution"),
      memoryBeforeLearningBatchArtifactSHA256: before,
      memoryAfterLearningBatchArtifactSHA256: after,
      motorActionArtifactSHA256: actionHash
    )
    XCTAssertEqual(root.memoryBeforeLearningBatchArtifactSHA256, before)
    XCTAssertEqual(root.memoryAfterLearningBatchArtifactSHA256, after)
    XCTAssertEqual(root.motorActionArtifactSHA256, actionHash)
    let ordinaryGoal = try BrainPolicyNumanXCaptureRootReference(
      controlStep: 10,
      sampleSHA256: hash("ordinary-goal-sample"),
      executionSHA256: hash("ordinary-goal-execution"),
      memoryBeforeLearningBatchArtifactSHA256: hash("ordinary-before"),
      memoryAfterLearningBatchArtifactSHA256: hash("ordinary-after"),
      motorActionArtifactSHA256: hash("ordinary-action"),
      externalGoalArtifactSHA256: hash("ordinary-goal")
    )
    XCTAssertEqual(
      ordinaryGoal.externalGoalArtifactSHA256,
      hash("ordinary-goal")
    )
    XCTAssertThrowsError(try BrainPolicyNumanXCaptureRootReference(
      controlStep: 9,
      sampleSHA256: hash("sample"),
      executionSHA256: hash("execution"),
      memoryBeforeLearningBatchArtifactSHA256: before
    ))
    XCTAssertThrowsError(try BrainPolicyNumanXMotorActionArtifact(
      controlStep: 9,
      protectiveFlags: 1,
      protectiveInterruptMask: 0,
      motorInhibition: 0.25,
      autonomicArousal: 0.5,
      actuatorCommandKind: 1,
      learnedDescendingCommands: [0.1],
      actuatorCommands: [0.3, 0.4],
      autonomicCommands: [0.5],
      activeSensingCommands: [0.6]
    ))
  }

  func testLongHorizonProtocolFreezesScheduleBeforeCapture() throws {
    func protocolFor(
      _ axis: BrainPolicyQualificationAxis
    ) throws -> BrainPolicyNumanXLongHorizonProtocolArtifact {
      try BrainPolicyNumanXLongHorizonProtocolArtifact(
        protocolIdentifier: "gate-c-long-horizon-\(axis.rawValue)-v1",
        candidateArtifactSHA256: String(repeating: "a", count: 64),
        axis: axis,
        datasetSourceIdentifier: "held-out-long-horizon-v1",
        episodeIdentifier: 44,
        taskFingerprint: 1,
        sceneFingerprint: 2,
        objectFingerprint: 3,
        embodimentFingerprint: 4,
        timestepMicroseconds: 100,
        cohortCount: 10
      )
    }
    let delayed = try protocolFor(.delayedConsequences)
    XCTAssertEqual(delayed.totalRootCount, 41)
    XCTAssertEqual(try delayed.phase(controlStep: 1).phase, .warmup)
    XCTAssertEqual(try delayed.phase(controlStep: 2).phase, .delayedCue)
    XCTAssertEqual(try delayed.phase(controlStep: 3).phase, .delayedWait)
    XCTAssertEqual(try delayed.phase(controlStep: 5).phase, .delayedConsequence)
    let interrupted = try protocolFor(.interruptedTasks)
    XCTAssertEqual(interrupted.totalRootCount, 31)
    XCTAssertEqual(try interrupted.phase(controlStep: 3).phase, .interruption)
    XCTAssertEqual(
      try interrupted.phase(controlStep: 4).phase,
      .interruptionRecovery
    )
    let alias = try protocolFor(.stateAliasing)
    XCTAssertEqual(alias.totalRootCount, 21)
    XCTAssertEqual(try alias.phase(controlStep: 2).phase, .aliasReference)
    XCTAssertEqual(try alias.phase(controlStep: 3).phase, .aliasProbe)
    XCTAssertThrowsError(try protocolFor(.crossTask))
    XCTAssertThrowsError(try BrainPolicyNumanXLongHorizonProtocolArtifact(
      protocolIdentifier: "too-small",
      candidateArtifactSHA256: String(repeating: "a", count: 64),
      axis: .stateAliasing,
      datasetSourceIdentifier: "held-out",
      episodeIdentifier: 1,
      taskFingerprint: 1,
      sceneFingerprint: 2,
      objectFingerprint: 3,
      embodimentFingerprint: 4,
      timestepMicroseconds: 100,
      cohortCount: 9
    ))

    let goal = try ActiveGoal(
      identifier: 99,
      origin: .externalTask,
      targetState: BrainLatentVector(values: [Float](repeating: 0.25, count: 16)),
      priority: 10,
      deadline: BrainTimestamp(microseconds: 200),
      successModel: BrainLatentVector(values: [Float](repeating: 0.5, count: 16)),
      failureModel: BrainLatentVector(values: [Float](repeating: -0.5, count: 16)),
      damageRiskBudget: 1,
      persistence: 1,
      createdTimestamp: BrainTimestamp(microseconds: 100),
      targetBodyIdentifier: 23
    )
    let goalArtifact = try BrainPolicyNumanXActiveGoalArtifact(goal: goal)
    XCTAssertEqual(try goalArtifact.activeGoal, goal)
    XCTAssertEqual(
      try BrainPolicyNumanXActiveGoalArtifact.decode(goalArtifact.encoded()),
      goalArtifact
    )
  }

  func testHeadPostureEvaluationRetainsSignedPhysicalAdvantage() throws {
    func hash(_ label: String) -> String {
      BrainPolicyEvidenceArtifact.sha256(Data(label.utf8))
    }
    func observation(_ label: String, terminal: Float)
      throws -> BrainPolicyNumanXHeadPostureObservation
    {
      try BrainPolicyNumanXHeadPostureObservation(
        runArtifactSHA256: hash("run-\(label)"),
        rootCount: 100,
        initialControlStep: 2,
        terminalControlStep: 100,
        initialSampleSHA256: hash("initial-\(label)"),
        terminalSampleSHA256: hash("terminal-\(label)"),
        initialRelativeHeadHeightMeters: -0.33,
        terminalRelativeHeadHeightMeters: terminal,
        meanActuatorCommand: 0.01,
        peakActuatorCommand: 0.3
      )
    }
    let baseline = try observation("baseline", terminal: -0.330_100)
    let candidate = try observation("candidate", terminal: -0.330_098)
    let artifact = try BrainPolicyNumanXHeadPostureEvaluationArtifact(
      candidateArtifactSHA256: hash("candidate"),
      trainingRunArtifactSHA256: hash("training"),
      baselineRunArtifactSHA256: baseline.runArtifactSHA256,
      candidateRunArtifactSHA256: candidate.runArtifactSHA256,
      taskFingerprint: 1,
      trainingSceneFingerprint: 2,
      evaluationSceneFingerprint: 3,
      objectFingerprint: 4,
      embodimentFingerprint: 5,
      timestepMicroseconds: 100,
      baseline: baseline,
      candidate: candidate
    )
    XCTAssertTrue(artifact.succeeds)
    XCTAssertGreaterThanOrEqual(
      artifact.candidateMinusBaselineLiftMeters,
      BrainPolicyNumanXHeadPostureEvaluationArtifact
        .minimumLiftAdvantageMeters
    )
    XCTAssertEqual(
      try BrainPolicyNumanXHeadPostureEvaluationArtifact.decode(
        artifact.encoded()
      ),
      artifact
    )
    XCTAssertThrowsError(try BrainPolicyNumanXHeadPostureEvaluationArtifact(
      candidateArtifactSHA256: hash("candidate"),
      trainingRunArtifactSHA256: hash("training"),
      baselineRunArtifactSHA256: baseline.runArtifactSHA256,
      candidateRunArtifactSHA256: candidate.runArtifactSHA256,
      taskFingerprint: 1,
      trainingSceneFingerprint: 3,
      evaluationSceneFingerprint: 3,
      objectFingerprint: 4,
      embodimentFingerprint: 5,
      timestepMicroseconds: 100,
      baseline: baseline,
      candidate: candidate
    ))
  }

  func testHeadPostureLearningRetainsSignedAcceptedResponse() throws {
    func hash(_ label: String) -> String {
      BrainPolicyEvidenceArtifact.sha256(Data(label.utf8))
    }
    let runHash = hash("head-learning-run")
    let observation = try BrainPolicyNumanXHeadPostureObservation(
      runArtifactSHA256: runHash,
      rootCount: 100,
      initialControlStep: 2,
      terminalControlStep: 100,
      initialSampleSHA256: hash("head-learning-initial"),
      terminalSampleSHA256: hash("head-learning-terminal"),
      initialRelativeHeadHeightMeters: -0.33,
      terminalRelativeHeadHeightMeters: -0.330_093_45,
      meanActuatorCommand: 0.01,
      peakActuatorCommand: 0.3
    )
    let coordinates = try BrainPolicyNumanXDatasetCoordinates(
      datasetSourceIdentifier: "head-learning",
      datasetSourceRevision: "training",
      episodeIdentifier: 1,
      taskFingerprint: 1,
      sceneFingerprint: 2,
      objectFingerprint: 3,
      embodimentFingerprint: 4
    )
    let artifact = try BrainPolicyNumanXHeadPostureLearningArtifact(
      sourceRunArtifactSHA256: runHash,
      coordinates: coordinates,
      timestepMicroseconds: 100,
      objectiveWeight: 4,
      observation: observation
    )
    XCTAssertGreaterThan(artifact.responseDeficit, 0.9)
    XCTAssertLessThanOrEqual(artifact.responseDeficit, 1)
    XCTAssertEqual(
      try BrainPolicyNumanXHeadPostureLearningArtifact.decode(
        artifact.encoded()
      ),
      artifact
    )
    let calibrated = try BrainPolicyNumanXHeadPostureLearningArtifact(
      sourceRunArtifactSHA256: runHash,
      coordinates: coordinates,
      timestepMicroseconds: 100,
      objectiveWeight: 4,
      observation: observation,
      calibrationEvaluationArtifactSHA256: hash("head-calibration"),
      responseGainDirection: -1
    )
    XCTAssertEqual(calibrated.effectiveResponseGainDirection, -1)
    XCTAssertNotEqual(calibrated.objectiveFingerprint, artifact.objectiveFingerprint)
    XCTAssertEqual(
      try BrainPolicyNumanXHeadPostureLearningArtifact.decode(
        calibrated.encoded()
      ),
      calibrated
    )
    XCTAssertThrowsError(try BrainPolicyNumanXHeadPostureLearningArtifact(
      sourceRunArtifactSHA256: runHash,
      coordinates: coordinates,
      timestepMicroseconds: 100,
      objectiveWeight: 4,
      observation: observation,
      calibrationEvaluationArtifactSHA256: hash("head-calibration"),
      responseGainDirection: nil
    ))
    XCTAssertEqual(
      try BrainPolicyNumanXHeadPostureLearningBuilder
        .resolvedCalibrationDirection(
          candidateMinusBaselineLiftMeters: 1.0e-6,
          minimumAbsoluteResponseMeters: 1.0e-6
        ),
      1
    )
    XCTAssertEqual(
      try BrainPolicyNumanXHeadPostureLearningBuilder
        .resolvedCalibrationDirection(
          candidateMinusBaselineLiftMeters: -1.0e-6,
          minimumAbsoluteResponseMeters: 1.0e-6
        ),
      -1
    )
    XCTAssertThrowsError(
      try BrainPolicyNumanXHeadPostureLearningBuilder
        .resolvedCalibrationDirection(
          candidateMinusBaselineLiftMeters: -2.384_185_8e-7,
          minimumAbsoluteResponseMeters: 1.0e-6
        )
    )
    let weights = try BrainSlowLossKind.allCases.map {
      try BrainPolicyNumanXLossWeight(kind: $0, weight: 1)
    }
    XCTAssertNoThrow(try BrainPolicyNumanXLearnerConfigurationArtifact(
      learnerIdentifier: "numibrain.mlx-slow-learner.head-posture.v1",
      learningRate: 0.1,
      gradientNormLimit: 1,
      parameterMagnitudeLimit: 4,
      lossWeights: weights,
      headPostureObjectiveIdentifier: artifact.objectiveIdentifier,
      headPostureObjectiveWeight: artifact.objectiveWeight
    ))
    XCTAssertThrowsError(try BrainPolicyNumanXLearnerConfigurationArtifact(
      learnerIdentifier: "invalid-two-physical-objectives",
      learningRate: 0.1,
      gradientNormLimit: 1,
      parameterMagnitudeLimit: 4,
      lossWeights: weights,
      delayedSupportObjectiveIdentifier:
        BrainPolicyNumanXDelayedSupportLearningArtifact.objectiveIdentifier,
      delayedSupportObjectiveWeight: 1,
      headPostureObjectiveIdentifier: artifact.objectiveIdentifier,
      headPostureObjectiveWeight: artifact.objectiveWeight
    ))
    let solved = try BrainPolicyNumanXHeadPostureObservation(
      runArtifactSHA256: runHash,
      rootCount: 100,
      initialControlStep: 2,
      terminalControlStep: 100,
      initialSampleSHA256: hash("solved-initial"),
      terminalSampleSHA256: hash("solved-terminal"),
      initialRelativeHeadHeightMeters: -0.33,
      terminalRelativeHeadHeightMeters: -0.329_998,
      meanActuatorCommand: 0.01,
      peakActuatorCommand: 0.3
    )
    XCTAssertThrowsError(try BrainPolicyNumanXHeadPostureLearningArtifact(
      sourceRunArtifactSHA256: runHash,
      coordinates: coordinates,
      timestepMicroseconds: 100,
      objectiveWeight: 4,
      observation: solved
    ))
  }

  func testLongHorizonEvaluationRecomputesAliasedStateSuccess() throws {
    func hash(_ label: String) -> String {
      BrainPolicyEvidenceArtifact.sha256(Data(label.utf8))
    }
    func observation(_ cohort: UInt32, succeeds: Bool)
      throws -> BrainPolicyNumanXLongHorizonCohortObservation
    {
      let middle = hash("memory-middle-\(cohort)")
      return try BrainPolicyNumanXLongHorizonCohortObservation(
        cohort: cohort,
        axis: .stateAliasing,
        phases: [.aliasReference, .aliasProbe],
        sampleSHA256: [
          hash("sample-reference-\(cohort)"), hash("sample-probe-\(cohort)"),
        ],
        rootOutcomes: [.accepted, .accepted],
        semanticSensorSHA256: [
          hash("sensor-\(cohort)"), hash("sensor-\(cohort)"),
        ],
        memoryBeforeSHA256: [hash("memory-before-\(cohort)"), middle],
        memoryAfterSHA256: [middle, hash("memory-after-\(cohort)")],
        semanticMotorActionSHA256: [
          hash("action-reference-\(cohort)"),
          succeeds
            ? hash("action-probe-\(cohort)")
            : hash("action-reference-\(cohort)"),
        ],
        externalGoalArtifactSHA256: [nil, nil],
        supportStable: [true, true],
        semanticMotorActionDistance: succeeds ? 0.01 : 0
      )
    }
    let passing = try (UInt32(1)...UInt32(10)).map {
      try observation($0, succeeds: true)
    }
    let artifact = try BrainPolicyNumanXLongHorizonEvaluationArtifact(
      candidateArtifactSHA256: hash("candidate"),
      protocolArtifactSHA256: hash("protocol"),
      captureRunArtifactSHA256: hash("run"),
      axis: .stateAliasing,
      cohortObservations: passing.reversed()
    )
    XCTAssertEqual(artifact.metrics[0].reducedValue, 1)
    XCTAssertTrue(artifact.passesPredeclaredThresholds)
    XCTAssertTrue(artifact.cohortObservations.allSatisfy(\.success))
    XCTAssertEqual(
      try BrainPolicyNumanXLongHorizonEvaluationArtifact.decode(
        artifact.encoded()
      ),
      artifact
    )
    var tampered = try JSONSerialization.jsonObject(
      with: artifact.encoded()
    ) as! [String: Any]
    var cohorts = tampered["cohortObservations"] as! [[String: Any]]
    cohorts[0]["success"] = false
    tampered["cohortObservations"] = cohorts
    XCTAssertThrowsError(
      try BrainPolicyNumanXLongHorizonEvaluationArtifact.decode(
        JSONSerialization.data(withJSONObject: tampered)
      )
    )

    let failing = try (UInt32(1)...UInt32(10)).map {
      try observation($0, succeeds: $0 <= 6)
    }
    let belowThreshold = try BrainPolicyNumanXLongHorizonEvaluationArtifact(
      candidateArtifactSHA256: hash("candidate"),
      protocolArtifactSHA256: hash("protocol"),
      captureRunArtifactSHA256: hash("run"),
      axis: .stateAliasing,
      cohortObservations: failing
    )
    XCTAssertEqual(belowThreshold.metrics[0].reducedValue, 0.6)
    XCTAssertFalse(belowThreshold.passesPredeclaredThresholds)

    let interrupted = try BrainPolicyNumanXLongHorizonCohortObservation(
      cohort: 1,
      axis: .interruptedTasks,
      phases: [
        .interruptionBaseline, .interruption, .interruptionRecovery,
      ],
      sampleSHA256: [hash("ib"), hash("ii"), hash("ir")],
      rootOutcomes: [.accepted, .rejected, .accepted],
      semanticSensorSHA256: [hash("isb"), hash("isi"), hash("isr")],
      memoryBeforeSHA256: [hash("im0"), hash("im1"), hash("im1")],
      memoryAfterSHA256: [hash("im1"), hash("im1"), hash("im2")],
      semanticMotorActionSHA256: [hash("ia0"), hash("ia1"), hash("ia2")],
      externalGoalArtifactSHA256: [hash("ig"), nil, nil],
      supportStable: [true, false, true],
      semanticMotorActionDistance: 0
    )
    XCTAssertTrue(interrupted.success)

    let delayed = try BrainPolicyNumanXLongHorizonCohortObservation(
      cohort: 1,
      axis: .delayedConsequences,
      phases: [
        .delayedCue, .delayedWait, .delayedWait, .delayedConsequence,
      ],
      sampleSHA256: [hash("dc"), hash("dw0"), hash("dw1"), hash("do")],
      rootOutcomes: [.accepted, .accepted, .accepted, .accepted],
      semanticSensorSHA256: [
        hash("ds0"), hash("ds1"), hash("ds2"), hash("ds3"),
      ],
      memoryBeforeSHA256: [
        hash("dm0"), hash("dm1"), hash("dm2"), hash("dm3"),
      ],
      memoryAfterSHA256: [
        hash("dm1"), hash("dm2"), hash("dm3"), hash("dm4"),
      ],
      semanticMotorActionSHA256: [
        hash("da0"), hash("da1"), hash("da2"), hash("da3"),
      ],
      externalGoalArtifactSHA256: [hash("dg"), nil, nil, nil],
      supportStable: [true, true, true, true],
      semanticMotorActionDistance: 0.1
    )
    XCTAssertTrue(delayed.success)
  }
}

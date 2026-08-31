import Foundation
import XCTest

@testable import NumiBrainCore

final class BrainFoundationPolicyPackageTests: XCTestCase {
  private func learnedPublication() throws -> BrainParameterPublication {
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let program = try RegionalTokenProgram.runtimeFoundationV0(schedule: schedule)
    let parentVersion = try BrainParameterVersion.runtimeFoundationV0(
      schedule: schedule,
      regionalProgram: program,
      tissueParameters: .corticalSheetV0
    )
    let parentArtifact = try BrainSharedParameterArtifact.foundation(
      parameterVersion: parentVersion
    )
    let updatedPayloads = try parentArtifact.payloads.map { payload in
      var data = payload.data
      if payload.kind == .policy {
        data[0] ^= 1
      }
      return try BrainParameterPayload(
        kind: payload.kind,
        elementType: payload.elementType,
        data: data
      )
    }
    let successor = try BrainSharedParameterArtifact.successor(
      parentVersion: parentVersion,
      updatedPayloads: updatedPayloads
    )
    let update = try BrainLearnerUpdate(
      parentVersion: parentVersion,
      sourceBatchFingerprint: 0xabc0_0001,
      sourceGeneration: 12,
      sourceMindCount: 3,
      minimumSourceGeneration: 9,
      candidateVersion: successor.version,
      sharedArtifact: successor.artifact,
      losses: try BrainSlowLossKind.allCases.map {
        try BrainSlowLossTerm(kind: $0, weight: 1, value: 0.25)
      }
    )
    return try BrainParameterPublication(
      parentVersion: parentVersion,
      learnerUpdate: update
    )
  }

  private func sha(_ nibble: Int) -> String {
    String(repeating: String(format: "%x", nibble), count: 64)
  }

  private func architecture(
    publication: BrainParameterPublication
  ) throws -> BrainFoundationPolicyArchitecture {
    try BrainFoundationPolicyArchitecture(
      family: .hierarchicalEmbodied,
      modelIdentifier: "numibrain.foundation-policy.test",
      modelRevision: "r1",
      modelWeightsSHA256:
        try BrainFoundationPolicyPackage
        .parameterWeightsSHA256(publication),
      speciesFingerprint: 0x1001,
      runtimeProgramFingerprint: publication.version.regionalProgramFingerprint,
      lowLevelControllerFingerprint: 0x1003,
      hardSafetyProgramFingerprint: 0x1004,
      inputModalities: [
        .kinesthesia, .vision, .touch, .audition, .interoception,
        .vestibular, .proprioception,
      ],
      goalInterfaces: [.demonstration, .structuredTask],
      actionGeneration: .chunked,
      actionHorizon: 8,
      inferencePrecision: .fp16,
      maximumInferenceLatencyMicroseconds: 20_000,
      uncertaintyMethod: "ensemble-conformal-v1",
      supervisionRequestThreshold: 0.7,
      rootRejectionThreshold: 0.9
    )
  }

  private func sources() throws -> [BrainPolicyDatasetSource] {
    [
      try BrainPolicyDatasetSource(
        identifier: "sim-v1",
        revision: "2026-09-01",
        sourceKind: .simulated,
        purposes: [.simulationDemonstration, .multimodalPretraining],
        sourceURI: "https://example.invalid/sim-v1",
        licenseIdentifier: "Apache-2.0",
        contentSHA256: sha(2)
      ),
      try BrainPolicyDatasetSource(
        identifier: "external-v1",
        revision: "2026-09-01",
        sourceKind: .independentlySourced,
        purposes: [.embodiment],
        sourceURI: "https://example.invalid/external-v1",
        licenseIdentifier: "CC-BY-4.0",
        contentSHA256: sha(3)
      ),
    ]
  }

  private func partitions() throws -> [BrainPolicyDatasetPartition] {
    try BrainPolicyDatasetSplit.allCases.enumerated().map { index, split in
      try BrainPolicyDatasetPartition(
        identifier: "partition-\(split.rawValue)",
        split: split,
        datasetIdentifier: split == .training ? "sim-v1" : "external-v1",
        membershipArtifactSHA256: sha(index + 4),
        sampleCount: UInt64(1_000 + index),
        learnerBatchFingerprint: split == .training ? 0xabc0_0001 : 0,
        taskSetFingerprint: UInt64(0x2000 + index),
        sceneSetFingerprint: UInt64(0x3000 + index),
        objectSetFingerprint: UInt64(0x4000 + index),
        embodimentSetFingerprint: UInt64(0x5000 + index)
      )
    }
  }

  private func results(
    failingAxis: BrainPolicyQualificationAxis? = nil
  ) throws -> [BrainPolicyQualificationResult] {
    try BrainPolicyQualificationAxis.allCases.enumerated().map { index, axis in
      try BrainPolicyQualificationResult(
        axis: axis,
        evaluationArtifactSHA256: sha(index + 4),
        sampleCount: 128,
        metrics: [
          try BrainPolicyQualificationMetric(
            identifier: "\(axis.rawValue)-score",
            unit: "ratio",
            value: axis == failingAxis ? 0.4 : 0.9,
            threshold: 0.8,
            direction: .atLeast
          )
        ]
      )
    }
  }

  private func package(
    results: [BrainPolicyQualificationResult]? = nil
  ) throws -> BrainFoundationPolicyPackage {
    let publication = try learnedPublication()
    return try BrainFoundationPolicyPackage(
      packageIdentifier: "numibrain.foundation-policy.test.r1",
      createdAtUnixMicroseconds: 1_788_220_800_000_000,
      sourceRevision: "0123456789abcdef0123456789abcdef01234567",
      toolchainIdentifier: "swift-6.3-metal-4",
      architecture: architecture(publication: publication),
      parameterPublication: publication,
      datasetSources: sources(),
      datasetPartitions: partitions(),
      splitIntegrityReportSHA256: sha(15),
      qualificationResults: try results ?? self.results()
    )
  }

  func testCompleteEvidenceManifestRoundTripsAndRestoresPublication() throws {
    let package = try package()
    try package.validateGateCEvidenceManifest()
    XCTAssertTrue(package.isGateCEvidenceManifestComplete)
    XCTAssertEqual(
      Set(package.datasetPartitions.map(\.split)),
      Set(BrainPolicyDatasetSplit.allCases)
    )
    XCTAssertEqual(
      Set(package.qualificationResults.map(\.axis)),
      Set(BrainPolicyQualificationAxis.allCases)
    )

    let first = try package.encoded()
    let second = try package.encoded()
    XCTAssertEqual(first, second)
    let decoded = try BrainFoundationPolicyPackage.decode(first)
    XCTAssertEqual(decoded, package)
    XCTAssertEqual(try decoded.publication(), try learnedPublication())

    let url = FileManager.default.temporaryDirectory.appending(
      path: "\(UUID().uuidString).nbpolicy"
    )
    defer { try? FileManager.default.removeItem(at: url) }
    try package.write(to: url)
    XCTAssertEqual(try Data(contentsOf: url), first)
  }

  func testCandidateMayBeStructurallyValidWithoutPassingGateC() throws {
    let incompleteResults = Array(try results().dropLast())
    let incomplete = try package(results: incompleteResults)
    try incomplete.validate()
    XCTAssertFalse(incomplete.isGateCEvidenceManifestComplete)
    XCTAssertThrowsError(try incomplete.validateGateCEvidenceManifest())

    let failed = try package(results: results(failingAxis: .uncertaintyAndOOD))
    try failed.validate()
    XCTAssertFalse(failed.isGateCEvidenceManifestComplete)
    XCTAssertThrowsError(try failed.validateGateCEvidenceManifest())
  }

  func testPackageRejectsSeedTamperingAndSplitAlias() throws {
    let schedule = try ReferenceBrainSchedule.runtimeFoundationSubset()
    let program = try RegionalTokenProgram.runtimeFoundationV0(schedule: schedule)
    let seedVersion = try BrainParameterVersion.runtimeFoundationV0(
      schedule: schedule,
      regionalProgram: program,
      tissueParameters: .corticalSheetV0
    )
    let seed = try BrainParameterPublication(
      version: seedVersion,
      sharedArtifact: BrainSharedParameterArtifact.foundation(
        parameterVersion: seedVersion
      )
    )
    XCTAssertThrowsError(try BrainPackagedParameterPublication(seed))

    let package = try package()
    var text = try XCTUnwrap(String(data: package.encoded(), encoding: .utf8))
    text = text.replacingOccurrences(
      of: "numibrain.foundation-policy.test.r1",
      with: "numibrain.foundation-policy.tampered"
    )
    XCTAssertThrowsError(
      try BrainFoundationPolicyPackage.decode(
        try XCTUnwrap(text.data(using: .utf8))
      )
    )

    var aliased = try partitions()
    aliased[1] = try BrainPolicyDatasetPartition(
      identifier: aliased[1].identifier,
      split: aliased[1].split,
      datasetIdentifier: aliased[1].datasetIdentifier,
      membershipArtifactSHA256: aliased[0].membershipArtifactSHA256,
      sampleCount: aliased[1].sampleCount,
      learnerBatchFingerprint: 0,
      taskSetFingerprint: aliased[1].taskSetFingerprint,
      sceneSetFingerprint: aliased[1].sceneSetFingerprint,
      objectSetFingerprint: aliased[1].objectSetFingerprint,
      embodimentSetFingerprint: aliased[1].embodimentSetFingerprint
    )
    let publication = try learnedPublication()
    XCTAssertThrowsError(
      try BrainFoundationPolicyPackage(
        packageIdentifier: "alias",
        createdAtUnixMicroseconds: 1,
        sourceRevision: "r1",
        toolchainIdentifier: "swift",
        architecture: architecture(publication: publication),
        parameterPublication: publication,
        datasetSources: sources(),
        datasetPartitions: aliased,
        splitIntegrityReportSHA256: sha(15),
        qualificationResults: results()
      )
    )
  }

  private struct EvidenceFixture {
    let package: BrainFoundationPolicyPackage
    let directory: URL
  }

  private func requiredSplit(
    for axis: BrainPolicyQualificationAxis
  ) -> BrainPolicyDatasetSplit {
    switch axis {
    case .actionGenerationLatency: .validation
    case .crossTask: .heldOutTask
    case .crossScene: .heldOutScene
    case .crossObject: .heldOutObject
    case .crossEmbodiment: .heldOutEmbodiment
    case .fewShotAdaptation: .adaptation
    case .delayedConsequences, .interruptedTasks, .stateAliasing: .heldOutTask
    case .uncertaintyAndOOD, .hardSafetyRetention: .safety
    }
  }

  private func evidenceFixture(
    overlapSplits: Bool = false,
    foreignMetricSample: Bool = false
  ) throws -> EvidenceFixture {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: UUID().uuidString,
      directoryHint: .isDirectory
    )
    let simHash = try BrainPolicyEvidenceArtifact.write(
      Data("simulated-dataset".utf8),
      to: directory
    )
    let externalHash = try BrainPolicyEvidenceArtifact.write(
      Data("independent-embodiment-dataset".utf8),
      to: directory
    )
    let sources = [
      try BrainPolicyDatasetSource(
        identifier: "sim-v1",
        revision: "r1",
        sourceKind: .simulated,
        purposes: [.multimodalPretraining, .simulationDemonstration],
        sourceURI: "https://example.invalid/sim-v1",
        licenseIdentifier: "Apache-2.0",
        contentSHA256: simHash
      ),
      try BrainPolicyDatasetSource(
        identifier: "external-v1",
        revision: "r1",
        sourceKind: .independentlySourced,
        purposes: [.embodiment],
        sourceURI: "https://example.invalid/external-v1",
        licenseIdentifier: "CC-BY-4.0",
        contentSHA256: externalHash
      ),
    ]
    var membersByPartition: [String: [String]] = [:]
    var partitions: [BrainPolicyDatasetPartition] = []
    for (index, split) in BrainPolicyDatasetSplit.allCases.enumerated() {
      let identifier = "partition-\(split.rawValue)"
      var members = [
        BrainPolicyEvidenceArtifact.sha256(Data("\(identifier)-0".utf8)),
        BrainPolicyEvidenceArtifact.sha256(Data("\(identifier)-1".utf8)),
      ]
      if overlapSplits, index == 1,
        let first = membersByPartition["partition-training"]?.first
      {
        members[0] = first
      }
      let evidence = try BrainPolicyDatasetMembershipEvidence(
        partitionIdentifier: identifier,
        memberSHA256: members
      )
      let membershipHash = try BrainPolicyEvidenceArtifact.write(
        evidence.encoded(),
        to: directory
      )
      membersByPartition[identifier] = members
      partitions.append(
        try BrainPolicyDatasetPartition(
          identifier: identifier,
          split: split,
          datasetIdentifier: split == .training ? "sim-v1" : "external-v1",
          membershipArtifactSHA256: membershipHash,
          sampleCount: UInt64(members.count),
          learnerBatchFingerprint: split == .training ? 0xabc0_0001 : 0,
          taskSetFingerprint: UInt64(0x6000 + index),
          sceneSetFingerprint: UInt64(0x7000 + index),
          objectSetFingerprint: UInt64(0x8000 + index),
          embodimentSetFingerprint: UInt64(0x9000 + index)
        ))
    }
    let splitEvidence = try BrainPolicySplitIntegrityEvidence(
      bindings: try partitions.map {
        try BrainPolicySplitIntegrityBinding(
          partitionIdentifier: $0.identifier,
          membershipArtifactSHA256: $0.membershipArtifactSHA256
        )
      }
    )
    let splitHash = try BrainPolicyEvidenceArtifact.write(
      splitEvidence.encoded(),
      to: directory
    )
    let publication = try learnedPublication()
    let architecture = try architecture(publication: publication)
    let results = try BrainPolicyQualificationAxis.allCases.map { axis in
      let split = requiredSplit(for: axis)
      let partition = try XCTUnwrap(partitions.first(where: { $0.split == split }))
      var sampleHashes = try XCTUnwrap(membersByPartition[partition.identifier])
      if foreignMetricSample, axis == .crossTask {
        sampleHashes[0] = BrainPolicyEvidenceArtifact.sha256(Data("foreign".utf8))
      }
      let metricEvidence = try BrainPolicyQualificationMetricEvidence(
        identifier: "\(axis.rawValue)-success",
        unit: "ratio",
        reducer: .mean,
        threshold: 0.8,
        direction: .atLeast,
        observations: try sampleHashes.map {
          try BrainPolicyMetricObservation(sampleSHA256: $0, value: 1)
        }
      )
      let evidence = try BrainPolicyQualificationEvidence(
        axis: axis,
        modelWeightsSHA256: architecture.modelWeightsSHA256,
        partitionIdentifiers: [partition.identifier],
        metrics: [metricEvidence]
      )
      _ = try BrainPolicyEvidenceArtifact.write(evidence.encoded(), to: directory)
      return try evidence.qualificationResult()
    }
    return EvidenceFixture(
      package: try BrainFoundationPolicyPackage(
        packageIdentifier: "numibrain.foundation-policy.evidence.r1",
        createdAtUnixMicroseconds: 1_788_220_800_000_000,
        sourceRevision: "0123456789abcdef0123456789abcdef01234567",
        toolchainIdentifier: "swift-6.3-metal-4",
        architecture: architecture,
        parameterPublication: publication,
        datasetSources: sources,
        datasetPartitions: partitions,
        splitIntegrityReportSHA256: splitHash,
        qualificationResults: results
      ),
      directory: directory
    )
  }

  func testEvidenceVerifierStreamsHashesProvesSplitsAndRecomputesMetrics() throws {
    let fixture = try evidenceFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let receipt = try BrainFoundationPolicyEvidenceVerifier.verify(
      package: fixture.package,
      artifactDirectory: fixture.directory
    )
    try receipt.validate(package: fixture.package)
    XCTAssertTrue(BrainPolicyEvidenceArtifact.isSHA256(receipt.evidenceRootSHA256))
    XCTAssertEqual(
      receipt.evidenceRootSHA256,
      try BrainFoundationPolicyEvidenceVerifier.verify(
        package: fixture.package,
        artifactDirectory: fixture.directory
      ).evidenceRootSHA256
    )

    let sourceHash = fixture.package.datasetSources[0].contentSHA256
    let sourceURL = try BrainPolicyEvidenceArtifact.url(
      forSHA256: sourceHash,
      in: fixture.directory
    )
    try Data("tampered".utf8).write(to: sourceURL, options: [.atomic])
    XCTAssertThrowsError(
      try BrainFoundationPolicyEvidenceVerifier.verify(
        package: fixture.package,
        artifactDirectory: fixture.directory
      )
    )

    try FileManager.default.removeItem(at: sourceURL)
    let symlinkTarget = fixture.directory.appending(path: "source-target")
    try Data("simulated-dataset".utf8).write(to: symlinkTarget)
    try FileManager.default.createSymbolicLink(
      at: sourceURL,
      withDestinationURL: symlinkTarget
    )
    XCTAssertThrowsError(
      try BrainFoundationPolicyEvidenceVerifier.verify(
        package: fixture.package,
        artifactDirectory: fixture.directory
      )
    )
  }

  func testEvidenceVerifierRejectsOverlapAndForeignMetricSamples() throws {
    let overlap = try evidenceFixture(overlapSplits: true)
    defer { try? FileManager.default.removeItem(at: overlap.directory) }
    XCTAssertThrowsError(
      try BrainFoundationPolicyEvidenceVerifier.verify(
        package: overlap.package,
        artifactDirectory: overlap.directory
      )
    )

    let foreign = try evidenceFixture(foreignMetricSample: true)
    defer { try? FileManager.default.removeItem(at: foreign.directory) }
    XCTAssertThrowsError(
      try BrainFoundationPolicyEvidenceVerifier.verify(
        package: foreign.package,
        artifactDirectory: foreign.directory
      )
    )
  }
}

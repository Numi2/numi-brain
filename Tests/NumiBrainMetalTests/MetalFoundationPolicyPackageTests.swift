import Foundation
import Metal
import NumiBrainCore
import XCTest

@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalFoundationPolicyPackageTests: XCTestCase {
  private func compiledTemplate() throws -> CompiledSpeciesTemplate {
    try makeNumanXInteropCompiledTemplate(
      vestibularReceptorCount: 1,
      vestibularFeatureDimension: 3,
      auditionReceptorCount: 1,
      auditionFeatureDimension: 2,
      visionReceptorCount: 2,
      visionFeatureDimension: 3,
      touchReceptorCount: 1,
      touchFeatureDimension: 3,
      planningHorizonSteps: 4,
      workspaceCapacity: 4,
      name: "Gate C package runtime fixture"
    )
  }

  private func learnedPublication(
    compiled: CompiledSpeciesTemplate
  ) throws -> BrainParameterPublication {
    let parent = try BrainParameterPublication.developmentalSeedV1(
      species: compiled.species,
      tissueParameters: .corticalSheetV0
    )
    let payloads = try parent.sharedArtifact.payloads.map { payload in
      var data = payload.data
      if payload.kind == .policy { data[0] ^= 1 }
      return try BrainParameterPayload(
        kind: payload.kind,
        elementType: payload.elementType,
        data: data
      )
    }
    let successor = try BrainSharedParameterArtifact.successor(
      parentVersion: parent.version,
      updatedPayloads: payloads
    )
    let update = try BrainLearnerUpdate(
      parentVersion: parent.version,
      sourceBatchFingerprint: 0xc001,
      sourceGeneration: 4,
      sourceMindCount: 2,
      minimumSourceGeneration: 3,
      candidateVersion: successor.version,
      sharedArtifact: successor.artifact,
      losses: try BrainSlowLossKind.allCases.map {
        try BrainSlowLossTerm(kind: $0, weight: 1, value: 0.1)
      }
    )
    return try BrainParameterPublication(
      parentVersion: parent.version,
      learnerUpdate: update
    )
  }

  private func sha(_ value: Int) -> String {
    String(repeating: String(format: "%02x", value & 0xff), count: 32)
  }

  private func package(
    compiled: CompiledSpeciesTemplate,
    publication: BrainParameterPublication,
    qualified: Bool,
    hardSafetyFingerprint: UInt64? = nil
  ) throws -> BrainFoundationPolicyPackage {
    let enabledModalities = compiled.species.senses.filter(\.enabled).map(\.modality)
    let architecture = try BrainFoundationPolicyArchitecture(
      family: .hierarchicalEmbodied,
      modelIdentifier: "numibrain.metal.package.test",
      modelRevision: "r1",
      modelWeightsSHA256:
        try BrainFoundationPolicyPackage
        .parameterWeightsSHA256(publication),
      speciesFingerprint: compiled.species.fingerprint,
      runtimeProgramFingerprint: publication.version.regionalProgramFingerprint,
      lowLevelControllerFingerprint: compiled.somaticSynergyCatalog.fingerprint,
      hardSafetyProgramFingerprint: hardSafetyFingerprint
        ?? compiled.protectiveMotorProfile.fingerprint,
      inputModalities: enabledModalities,
      goalInterfaces: [.structuredTask, .demonstration],
      actionGeneration: .autoregressive,
      actionHorizon: 4,
      inferencePrecision: .fp32,
      maximumInferenceLatencyMicroseconds: 10_000,
      uncertaintyMethod: "ensemble-conformal-v1",
      supervisionRequestThreshold: 0.7,
      rootRejectionThreshold: 0.9
    )
    let sources = [
      try BrainPolicyDatasetSource(
        identifier: "sim",
        revision: "r1",
        sourceKind: .simulated,
        purposes: [.multimodalPretraining, .simulationDemonstration],
        sourceURI: "https://example.invalid/sim",
        licenseIdentifier: "Apache-2.0",
        contentSHA256: sha(1)
      ),
      try BrainPolicyDatasetSource(
        identifier: "external",
        revision: "r1",
        sourceKind: .independentlySourced,
        purposes: [.embodiment],
        sourceURI: "https://example.invalid/external",
        licenseIdentifier: "CC-BY-4.0",
        contentSHA256: sha(2)
      ),
    ]
    let partitions = try BrainPolicyDatasetSplit.allCases.enumerated().map {
      index, split in
      try BrainPolicyDatasetPartition(
        identifier: split.rawValue,
        split: split,
        datasetIdentifier: split == .training ? "sim" : "external",
        membershipArtifactSHA256: sha(index + 3),
        sampleCount: 32,
        learnerBatchFingerprint: split == .training ? 0xc001 : 0,
        taskSetFingerprint: UInt64(10 + index),
        sceneSetFingerprint: UInt64(20 + index),
        objectSetFingerprint: UInt64(30 + index),
        embodimentSetFingerprint: UInt64(40 + index)
      )
    }
    var results = try BrainPolicyQualificationAxis.allCases.enumerated().map {
      index, axis in
      try BrainPolicyQualificationResult(
        axis: axis,
        evaluationArtifactSHA256: sha(index + 16),
        sampleCount: 16,
        metrics: [
          try BrainPolicyQualificationMetric(
            identifier: "score",
            unit: "ratio",
            value: 1,
            threshold: 0.9,
            direction: .atLeast
          )
        ]
      )
    }
    if !qualified { results.removeLast() }
    return try BrainFoundationPolicyPackage(
      packageIdentifier: "numibrain.metal.package.test.r1",
      createdAtUnixMicroseconds: 1,
      sourceRevision: "r1",
      toolchainIdentifier: "swift-metal-test",
      architecture: architecture,
      parameterPublication: publication,
      datasetSources: sources,
      datasetPartitions: partitions,
      splitIntegrityReportSHA256: sha(31),
      qualificationResults: results
    )
  }

  private func configuration(
    compiled: CompiledSpeciesTemplate
  ) throws -> MetalNumiBrainConfiguration {
    try MetalNumiBrainConfiguration(
      initialTissueState: CPUTissueDynamics.makeRestingGrid(
        width: 4,
        height: 4,
        parameters: .corticalSheetV0
      ),
      tissueParameters: .corticalSheetV0,
      tissueStimulus: .none,
      compiledSpeciesTemplate: compiled,
      maximumEncodedSubsteps: 1
    )
  }

  func testMetalFactoryLoadsOnlyCompleteExactPolicyManifestByDefault() throws {
    guard let device = MTLCreateSystemDefaultDevice() else {
      throw XCTSkip("Metal device is unavailable")
    }
    let compiled = try compiledTemplate()
    let publication = try learnedPublication(compiled: compiled)
    let configuration = try configuration(compiled: compiled)
    let qualified = try package(
      compiled: compiled,
      publication: publication,
      qualified: true
    )
    let handle = try MetalNumiBrainHandle.create(
      configuration: configuration,
      policyPackage: qualified,
      device: device
    )
    XCTAssertEqual(handle.committedGeneration, 0)
    XCTAssertEqual(
      handle.parameterVersionFingerprint,
      publication.version.fingerprint
    )

    let candidate = try package(
      compiled: compiled,
      publication: publication,
      qualified: false
    )
    XCTAssertThrowsError(
      try MetalNumiBrainHandle.create(
        configuration: configuration,
        policyPackage: candidate,
        device: device
      )
    )
    let evaluationHandle = try MetalNumiBrainHandle.create(
      configuration: configuration,
      policyPackage: candidate,
      requireGateCEvidenceManifest: false,
      device: device
    )
    XCTAssertEqual(
      evaluationHandle.parameterVersionFingerprint,
      publication.version.fingerprint
    )

    let wrongSafety = try package(
      compiled: compiled,
      publication: publication,
      qualified: true,
      hardSafetyFingerprint: compiled.protectiveMotorProfile.fingerprint &+ 1
    )
    XCTAssertThrowsError(
      try MetalNumiBrainHandle.create(
        configuration: configuration,
        policyPackage: wrongSafety,
        requireGateCEvidenceManifest: false,
        device: device
      )
    )
  }
}

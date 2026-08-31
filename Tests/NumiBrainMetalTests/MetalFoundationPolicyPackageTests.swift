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
    hardSafetyFingerprint: UInt64? = nil,
    modelIdentifier: String = BrainFoundationPolicyRuntimeContract.modelIdentifier
  ) throws -> BrainFoundationPolicyPackage {
    let enabledModalities = compiled.species.senses.filter(\.enabled).map(\.modality)
    let architecture = try BrainFoundationPolicyArchitecture(
      family: .hierarchicalEmbodied,
      modelIdentifier: modelIdentifier,
      modelRevision: BrainFoundationPolicyRuntimeContract.modelRevision,
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
      uncertaintyMethod: BrainFoundationPolicyRuntimeContract.uncertaintyMethod,
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
      let requirements = BrainPolicyGateCMetricContract.requirements(
        for: axis,
        architecture: architecture
      )
      return try BrainPolicyQualificationResult(
        axis: axis,
        evaluationArtifactSHA256: sha(index + 16),
        sampleCount: 16,
        metrics: try requirements.map { requirement in
          try BrainPolicyQualificationMetric(
            identifier: requirement.identifier,
            unit: requirement.unit,
            value: requirement.threshold,
            threshold: requirement.threshold,
            direction: requirement.direction
          )
        }
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

  private struct EvidenceFixture {
    let policyPackage: BrainFoundationPolicyPackage
    let receipt: BrainFoundationPolicyEvidenceReceipt
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
    compiled: CompiledSpeciesTemplate,
    publication: BrainParameterPublication,
    hardSafetyFingerprint: UInt64? = nil
  ) throws -> EvidenceFixture {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: UUID().uuidString,
      directoryHint: .isDirectory
    )
    do {
      let simHash = try BrainPolicyEvidenceArtifact.write(
        Data("metal-sim-source".utf8),
        to: directory
      )
      let externalHash = try BrainPolicyEvidenceArtifact.write(
        Data("metal-external-source".utf8),
        to: directory
      )
      let sources = [
        try BrainPolicyDatasetSource(
          identifier: "sim",
          revision: "r1",
          sourceKind: .simulated,
          purposes: [.multimodalPretraining, .simulationDemonstration],
          sourceURI: "https://example.invalid/sim",
          licenseIdentifier: "Apache-2.0",
          contentSHA256: simHash
        ),
        try BrainPolicyDatasetSource(
          identifier: "external",
          revision: "r1",
          sourceKind: .independentlySourced,
          purposes: [.embodiment],
          sourceURI: "https://example.invalid/external",
          licenseIdentifier: "CC-BY-4.0",
          contentSHA256: externalHash
        ),
      ]
      var membersByPartition: [String: [String]] = [:]
      var partitions: [BrainPolicyDatasetPartition] = []
      for (index, split) in BrainPolicyDatasetSplit.allCases.enumerated() {
        let identifier = "partition-\(split.rawValue)"
        let members = [
          BrainPolicyEvidenceArtifact.sha256(Data("\(identifier)-0".utf8)),
          BrainPolicyEvidenceArtifact.sha256(Data("\(identifier)-1".utf8)),
        ]
        let membership = try BrainPolicyDatasetMembershipEvidence(
          partitionIdentifier: identifier,
          memberSHA256: members
        )
        let membershipHash = try BrainPolicyEvidenceArtifact.write(
          membership.encoded(),
          to: directory
        )
        membersByPartition[identifier] = members
        partitions.append(
          try BrainPolicyDatasetPartition(
            identifier: identifier,
            split: split,
            datasetIdentifier: split == .training ? "sim" : "external",
            membershipArtifactSHA256: membershipHash,
            sampleCount: UInt64(members.count),
            learnerBatchFingerprint: split == .training ? 0xc001 : 0,
            taskSetFingerprint: UInt64(10 + index),
            sceneSetFingerprint: UInt64(20 + index),
            objectSetFingerprint: UInt64(30 + index),
            embodimentSetFingerprint: UInt64(40 + index)
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
      let enabledModalities = compiled.species.senses.filter(\.enabled).map(\.modality)
      let architecture = try BrainFoundationPolicyArchitecture(
        family: .hierarchicalEmbodied,
        modelIdentifier: BrainFoundationPolicyRuntimeContract.modelIdentifier,
        modelRevision: BrainFoundationPolicyRuntimeContract.modelRevision,
        modelWeightsSHA256:
          try BrainFoundationPolicyPackage.parameterWeightsSHA256(publication),
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
        uncertaintyMethod: BrainFoundationPolicyRuntimeContract.uncertaintyMethod,
        supervisionRequestThreshold: 0.7,
        rootRejectionThreshold: 0.9
      )
      let results = try BrainPolicyQualificationAxis.allCases.map { axis in
        let split = requiredSplit(for: axis)
        let partition = try XCTUnwrap(partitions.first(where: { $0.split == split }))
        let members = try XCTUnwrap(membersByPartition[partition.identifier])
        let requirements = BrainPolicyGateCMetricContract.requirements(
          for: axis,
          architecture: architecture
        )
        let metrics = try requirements.map { requirement in
          let passingValue =
            requirement.direction == .atLeast
            ? requirement.threshold : min(requirement.threshold, 1)
          let observations: [BrainPolicyMetricObservation]
          if requirement.reducer == .binaryAUROC {
            observations = try members.enumerated().map { index, sampleHash in
              try BrainPolicyMetricObservation(
                sampleSHA256: sampleHash,
                value: index == 0 ? 0 : 1,
                referenceClass: index == 0 ? 0 : 1
              )
            }
          } else {
            observations = try members.map {
              try BrainPolicyMetricObservation(
                sampleSHA256: $0,
                value: passingValue
              )
            }
          }
          return try BrainPolicyQualificationMetricEvidence(
            identifier: requirement.identifier,
            unit: requirement.unit,
            reducer: requirement.reducer,
            threshold: requirement.threshold,
            direction: requirement.direction,
            observations: observations
          )
        }
        let axisOrdinal = try XCTUnwrap(
          BrainPolicyQualificationAxis.allCases.firstIndex(of: axis)
        )
        let transactionBase = UInt64(axisOrdinal + 1) * 1_000
        var rootExecutions = try members.enumerated().map { index, sampleHash in
          let transaction = transactionBase + UInt64(index + 1)
          return try BrainPolicyNumanXRootExecution(
            sampleSHA256: sampleHash,
            ownerProgramFingerprint: architecture.lowLevelControllerFingerprint,
            transactionFingerprint: transaction,
            linearizationEpoch: 1,
            slotGeneration: UInt64(index + 1),
            transactionSlot: UInt32(index % 2),
            environment: 0,
            stepIndex: 0,
            controlStep: UInt32(index),
            substepIndex: 0,
            physicsSubstepCount: 1,
            outcome: .accepted,
            appliedRecordFingerprint: transaction + 10_000,
            jointCommitFingerprint: transaction + 20_000
          )
        }
        if axis == .uncertaintyAndOOD || axis == .hardSafetyRetention {
          let transaction = transactionBase + 500
          rootExecutions.append(
            try BrainPolicyNumanXRootExecution(
              sampleSHA256: members[0],
              ownerProgramFingerprint: architecture.lowLevelControllerFingerprint,
              transactionFingerprint: transaction,
              linearizationEpoch: 1,
              slotGeneration: 500,
              transactionSlot: 1,
              environment: 0,
              stepIndex: 0,
              controlStep: 500,
              substepIndex: 0,
              physicsSubstepCount: 1,
              outcome: .rejected,
              appliedRecordFingerprint: transaction + 10_000,
              jointCommitFingerprint: 0
            )
          )
        }
        let evidence = try BrainPolicyQualificationEvidence(
          axis: axis,
          executionKind: .authoritativeNumanX,
          modelWeightsSHA256: architecture.modelWeightsSHA256,
          runtimeProgramFingerprint: architecture.runtimeProgramFingerprint,
          lowLevelControllerFingerprint: architecture.lowLevelControllerFingerprint,
          hardSafetyProgramFingerprint: architecture.hardSafetyProgramFingerprint,
          rootExecutions: rootExecutions,
          partitionIdentifiers: [partition.identifier],
          metrics: metrics
        )
        _ = try BrainPolicyEvidenceArtifact.write(evidence.encoded(), to: directory)
        return try evidence.qualificationResult()
      }
      let policyPackage = try BrainFoundationPolicyPackage(
        packageIdentifier: "numibrain.metal.package.evidence.r1",
        createdAtUnixMicroseconds: 1,
        sourceRevision: "r1",
        toolchainIdentifier: "swift-metal-test",
        architecture: architecture,
        parameterPublication: publication,
        datasetSources: sources,
        datasetPartitions: partitions,
        splitIntegrityReportSHA256: splitHash,
        qualificationResults: results
      )
      return EvidenceFixture(
        policyPackage: policyPackage,
        receipt: try BrainFoundationPolicyEvidenceVerifier.verify(
          package: policyPackage,
          artifactDirectory: directory
        ),
        directory: directory
      )
    } catch {
      try? FileManager.default.removeItem(at: directory)
      throw error
    }
  }

  func testMetalFactoryRequiresVerifiedExactPolicyEvidence() throws {
    guard let device = MTLCreateSystemDefaultDevice() else {
      throw XCTSkip("Metal device is unavailable")
    }
    let compiled = try compiledTemplate()
    let publication = try learnedPublication(compiled: compiled)
    let configuration = try configuration(compiled: compiled)
    let qualified = try evidenceFixture(
      compiled: compiled,
      publication: publication
    )
    defer { try? FileManager.default.removeItem(at: qualified.directory) }
    let handle = try MetalNumiBrainHandle.create(
      configuration: configuration,
      policyPackage: qualified.policyPackage,
      evidenceReceipt: qualified.receipt,
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
      try BrainFoundationPolicyEvidenceVerifier.verify(
        package: candidate,
        artifactDirectory: qualified.directory
      )
    )
    let evaluationHandle = try MetalNumiBrainHandle.createUnverifiedPolicyCandidate(
      configuration: configuration,
      policyPackage: candidate,
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
      try MetalNumiBrainHandle.createUnverifiedPolicyCandidate(
        configuration: configuration,
        policyPackage: wrongSafety,
        device: device
      )
    )

    let wrongModel = try package(
      compiled: compiled,
      publication: publication,
      qualified: true,
      modelIdentifier: "unimplemented.model"
    )
    XCTAssertThrowsError(
      try MetalNumiBrainHandle.createUnverifiedPolicyCandidate(
        configuration: configuration,
        policyPackage: wrongModel,
        device: device
      )
    )

    let otherPackage = try package(
      compiled: compiled,
      publication: publication,
      qualified: true,
      hardSafetyFingerprint: compiled.protectiveMotorProfile.fingerprint
    )
    XCTAssertThrowsError(
      try MetalNumiBrainHandle.create(
        configuration: configuration,
        policyPackage: otherPackage,
        evidenceReceipt: qualified.receipt,
        device: device
      )
    )
  }
}

import Foundation
import XCTest
import NumiBrainCore
import NumiBrainConnectomeTestSupport
@testable import NumiBrainMetal

/// Pure compiled-body/ownership tests: no device allocation, physical receipts
/// or claim that this authored one-body fixture is a particular robot asset.
@available(macOS 26.0, *)
final class ConnectomeBodyContractTests: XCTestCase {
  private func body(modelIdentity: UInt64 = 0x5349_4e47_4c45) throws -> CompiledSpeciesTemplate {
    let reference = try ReferenceBrainGraph.mammalianV1()
    let modules = reference.modules.map(\.identifier)
    let jointCatalog = try NumanXJointTopologyCatalog(
      numanXModelFingerprint: modelIdentity, bodyCount: 1, joints: [])
    let senses = try SensoryModality.allCases.map { modality in
      let enabled = modality == .vestibular || modality == .interoception
      return try SensoryTopology(modality: modality, receptorCount: enabled ? 1 : 0,
        observationDimension: enabled ? 1 : 0, latencyMicroseconds: enabled ? 1_000 : 0,
        adaptationTimeConstantMicroseconds: 10_000, noiseStandardDeviation: 0,
        activeSensingActionDimension: 0, enabled: enabled)
    }
    let motor = try MotorTopology(actuatorCommandKind: .motorCurrent, actuatorCount: 4,
      synergyCount: 4, motorNucleusCount: 1, autonomicActionDimension: 1,
      activeSensingActionDimension: 0, outputMinimum: -1, outputMaximum: 1,
      actuatorChannels: (0..<4).map {
        try ActuatorChannelTemplate(identifier: UInt32($0), outputMinimum: -1,
          outputMaximum: 1, neutralCommand: 0, emergencyCommand: 0)
      })
    let physiology = try PhysiologyTemplate(modelClass: .artificialEnergyThermal,
      stateDimension: 1, autonomicActionDimension: 1,
      viableMinimums: [0.2], viableMaximums: [0.8], criticalMinimums: [0], criticalMaximums: [1],
      receptorMappings: [PhysiologicalReceptorTemplate(stateIdentifier: 0,
        receptorIdentifier: 900, interoceptiveReceptorIndex: 0, featureIndex: 0, magnitudeScale: 1)],
      autonomicChannels: [AutonomicChannelTemplate(identifier: 0, kind: .generic,
        criticalReceptorIdentifiers: [900], respondsToAnyPhysiologicalCritical: false,
        emergencyTarget: 1, emergencyGain: 1, cpgGain: 0)])
    let development = try DevelopmentalStage.allCases.map { stage in
      try DevelopmentalStageTemplate(stage: stage, unlockedModuleIdentifiers: modules,
        learningRateMultiplier: 1, sensorPrecisionMultiplier: 1, muscleStrengthMultiplier: 1,
        planningHorizonSteps: 1, workspaceCapacity: 1,
        capabilityGateCodes: stage == .innateScaffold ? [] : [UInt64(stage.rawValue)])
    }
    let species = try SpeciesTemplate(family: .genericRobot,
      name: "Authored single-body contract test", referenceGraph: reference,
      enabledModuleIdentifiers: modules,
      body: SpeciesBodyTopology(bodyCount: 1, jointCount: 0,
        jointTopologyFingerprint: jointCatalog.fingerprint, muscleCount: 0,
        muscleAttachmentFingerprint: 0, skinSurfaceCount: 1, actuatorCount: 4,
        morphologyCode: modelIdentity), senses: senses, motor: motor, reflexes: [],
      cpg: CPGTopology(oscillators: [], couplings: []), physiology: physiology,
      innateBehaviors: [], development: development, capacities: BrainCapacityProfile.fullCognitiveV1)
    let receptors = try NumanXReceptorAnatomyCatalog(species: species,
      jointTopologyCatalog: jointCatalog, muscleAttachmentCatalog: nil,
      numanXModelFingerprint: modelIdentity,
      endpoints: [NumanXReceptorEndpoint(identifier: 1, sourceEndpointIdentifier: 101,
        bodyIdentifier: 0, modality: .vestibular, receptorIndex: 0, featureIndex: 0,
        signal: .angularVelocity, component: 0)], jointEndpoints: [], muscleEndpoints: [])
    let sensory = try SensoryTransductionProfile(species: species, eventRules: [],
      numanXReceptorAnatomy: receptors, jointTopologyCatalog: jointCatalog,
      muscleAttachmentCatalog: nil)
    return try SpeciesTemplateCompiler.compileRuntimeTemplate(referenceBrainGraph: reference,
      species: species, sensoryProfile: sensory, numanXReceptorAnatomyCatalog: receptors,
      jointTopologyCatalog: jointCatalog, muscleAttachmentCatalog: nil,
      somaticSynergyCatalog: SomaticSynergyCatalog.runtimeFoundationFixture(actuatorCount: 4, synergyCount: 4))
  }

  func testSingletonBodyCompilesAndRoundTripsWithoutFabricatedJoints() throws {
    let template = try body()
    XCTAssertEqual(template.species.body.bodyCount, 1)
    XCTAssertEqual(template.species.body.jointCount, 0)
    XCTAssertTrue(template.jointTopologyCatalog.joints.isEmpty)
    XCTAssertTrue(template.sensoryProfile.jointReceptorBindings.isEmpty)
    XCTAssertNil(template.muscleAttachmentCatalog)
    XCTAssertEqual(template.species.motor.actuatorCount, 4)
    XCTAssertEqual(template.species.motor.actuatorCommandKind, .motorCurrent)
    let decoded = try JSONDecoder().decode(CompiledSpeciesTemplate.self,
      from: JSONEncoder().encode(template))
    XCTAssertEqual(decoded, template)
  }

  func testAbsentJointStateRetainsLogicalZeroAndOnlyBindablePadding() throws {
    let template = try body()
    let layout = try MetalAgentStateLayout(species: template.species,
      regionalProgram: template.species.regionalProgram())
    let joints = layout.section(.jointBelief)
    XCTAssertEqual(joints.elementCount, 0)
    XCTAssertEqual(joints.byteCount, MetalAgentStateLayout.jointBeliefStride)
    XCTAssertTrue(joints.byteOffset.isMultiple(of: MetalAgentStateLayout.alignment))
    XCTAssertEqual(layout.section(.bodyBelief).elementCount, 1)
    XCTAssertEqual(layout.section(.somaticOutput).elementCount, 4)
    XCTAssertEqual(try JSONDecoder().decode(MetalAgentStateLayout.self,
      from: JSONEncoder().encode(layout)), layout)
  }

  func testInnateMindContainsNoInventedJointOrMuscleBeliefs() throws {
    let template = try body()
    let publication = try BrainParameterPublication.developmentalSeedV1(
      species: template.species, tissueParameters: .corticalSheetV0)
    let state = try BrainAgentStateFactory.makeInnateState(environmentIdentifier: 0,
      episodeIdentifier: 1, species: template.species,
      jointTopologyCatalog: template.jointTopologyCatalog, graph: template.referenceBrainGraph,
      regionalProgram: template.species.regionalProgram(), parameterVersion: publication.version)
    XCTAssertEqual(state.belief.bodyNodes.count, 1)
    XCTAssertTrue(state.belief.jointEdges.isEmpty)
    XCTAssertTrue(state.belief.muscleEdges.isEmpty)
    XCTAssertEqual(state.belief.actuatorEffects.count, 4)
  }

  func testSameShapeForeignBodyCannotOwnConnectomeCandidate() throws {
    let first = try body(modelIdentity: 1), second = try body(modelIdentity: 2)
    XCTAssertEqual(first.species.motor.actuatorCount, second.species.motor.actuatorCount)
    XCTAssertEqual(first.species.senses, second.species.senses)
    let graph = try ConnectomeGraph(data: ConnectomeTestFixture.data())
    let binding = try ConnectomeBinding(graph: graph, template: first,
      parameterVersionFingerprint: 123, channelCount: 1,
      nominalStepMicroseconds: 1_000, integrationStepMicroseconds: 100,
      receptors: [ConnectomeReceptorProjection(neuronIdentifier: 10, modality: .vestibular,
        receptorIndex: 0, featureIndex: 0)],
      descending: [ConnectomeDescendingProjection(neuronIdentifier: 30, channel: 0)])
    try MetalJointAgentStateTransaction.validateConnectomeSpecies(binding: binding,
      ownerSpeciesFingerprint: first.species.fingerprint)
    XCTAssertThrowsError(try MetalJointAgentStateTransaction.validateConnectomeSpecies(
      binding: binding, ownerSpeciesFingerprint: second.species.fingerprint))
    XCTAssertThrowsError(try MetalJointAgentStateTransaction.validateConnectomeSpecies(
      binding: binding, ownerSpeciesFingerprint: 0))
  }

  func testEmptyBodyAndDisconnectedMultiBodyStillFail() throws {
    XCTAssertThrowsError(try NumanXJointTopologyCatalog(numanXModelFingerprint: 1, bodyCount: 0, joints: []))
    XCTAssertThrowsError(try NumanXJointTopologyCatalog(numanXModelFingerprint: 1, bodyCount: 2, joints: []))
    XCTAssertThrowsError(try SpeciesBodyTopology(bodyCount: 1, jointCount: 1,
      jointTopologyFingerprint: 1, muscleCount: 0, muscleAttachmentFingerprint: 0,
      skinSurfaceCount: 1, actuatorCount: 4, morphologyCode: 1))
  }

  func testNegativeLogicalArenaCountCannotBeDecodedAsEmpty() {
    XCTAssertThrowsError(try MetalArenaSectionLayout(section: MetalAgentHotSection.jointBelief,
      byteOffset: 0, byteCount: 256, elementCount: -1, elementStride: 256))
  }
}

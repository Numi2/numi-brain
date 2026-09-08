import Foundation
import XCTest
import NumiBrainCore
import NumiBrainConnectomeTestSupport
@testable import NumiBrainMetal

/// Metadata/byte-preservation checks; these authored buffers are not a physics
/// simulation or a device-runtime checkpoint qualification.
final class ConnectomeDecoderForkTests: XCTestCase {
  private struct Fixture {
    let template: CompiledSpeciesTemplate
    let parent: ConnectomeControllerProgram
    let source: MetalNumiBrainCheckpoint
    let encoded: Data
    let physical: Data
    func program(delta: Float, parameters: UInt64 = 123) throws -> ConnectomeControllerProgram {
      var values = parent.spec.decoderParameters; values[0] += delta
      return try ConnectomeControllerProgram(graph: parent.graph,
        spec: parent.spec.replacingDecoderParameters(values), template: template,
        parameterVersionFingerprint: parameters)
    }
    func fork(delta: Float, identifier: String = "probe", physical: Data? = nil,
      fingerprint: UInt64 = 555, budget: Int = 536_870_912) throws -> MetalConnectomeDecoderFork {
      try MetalConnectomeDecoderFork.prepare(identifier: identifier, sourceBrainData: encoded,
        physicalData: physical ?? self.physical, physicalCheckpointFingerprint: fingerprint,
        parent: parent, target: program(delta: delta), template: template, maximumSnapshotBytes: budget)
    }
  }

  private func fixture() throws -> Fixture {
    let template = try NumanXFullBodyTransportTemplate.compile(latencyMicroseconds: 1_000)
    let graph = try ConnectomeGraph(data: ConnectomeTestFixture.data())
    let sense = try XCTUnwrap(template.species.senses.first(where: \.enabled))
    let spec = ConnectomeControllerSpec(graphFingerprint: graph.fingerprint,
      speciesFingerprint: template.species.fingerprint, sensoryProfileFingerprint: template.sensoryProfile.fingerprint,
      nominalStepMicroseconds: 20_000, integrationStepMicroseconds: 1_000, channelCount: 1,
      receptors: [.init(neuronIdentifier: 10, modality: sense.modality, receptorIndex: 0, featureIndex: 0)],
      descending: [.init(neuronIdentifier: 30, channel: 0)],
      decoderWeights: Array(repeating: Float(0.1), count: Int(template.species.motor.actuatorCount)),
      decoderBiases: Array(repeating: Float(0), count: Int(template.species.motor.actuatorCount)))
    let parent = try ConnectomeControllerProgram(graph: graph, spec: spec, template: template,
      parameterVersionFingerprint: 123)
    let random = TissueRandomContext.deterministicDefault
    let neural = try ConnectomeCheckpoint(graphFingerprint: graph.fingerprint,
      topologyFingerprint: parent.topologyFingerprint, programFingerprint: parent.programFingerprint,
      parameterVersionFingerprint: 123, environmentIdentifier: random.environmentIdentifier,
      episodeIdentifier: UInt64(random.episodeIdentifier), generation: 3, timestampMicroseconds: 60_000,
      activity: [Float(0.25), -0.0, -0.5].withUnsafeBytes { Data($0) })
    let c = try MetalBrainCheckpoint(committedGeneration: 3, committedTimestamp: .init(microseconds: 60_000),
      environmentIdentifier: random.environmentIdentifier, episodeIdentifier: UInt64(random.episodeIdentifier),
      controlStepIdentifier: 7, speciesTemplateFingerprint: template.species.fingerprint,
      compiledSpeciesTemplateFingerprint: template.fingerprint, regionalProgramFingerprint: 12,
      scheduleFingerprint: 11, parameterVersionFingerprint: 123, hotLayoutFingerprint: 13,
      memoryLayoutFingerprint: 14, physicalCheckpointFingerprint: 555,
      hotState: Data((0..<64).map(UInt8.init)), persistentMemory: Data([200, 201, 202, 203]),
      connectomeState: neural)
    let buffers = MetalTissueCheckpointBufferKind.allCases.map { kind in
      MetalTissueCheckpointBuffer(kind: kind, data: Data(repeating: UInt8(kind.rawValue), count: 16))
    }
    let fast = try MetalTissueCheckpoint(width: 1, height: 1, environmentIdentifier: random.environmentIdentifier,
      randomContext: random, committedStep: 12, committedSchedulerTime: c.committedTimestamp,
      committedSchedulerGeneration: 3, committedHistoryOwnerMask: 1,
      committedRelayHistoryTimestamps: Array(repeating: 0, count: TissueDelayField.historyCapacity),
      parameterVersionFingerprint: 123, scheduleFingerprint: 11, regionalProgramFingerprint: 12,
      sharedArtifactFingerprint: 15, protectiveMotorProfileFingerprint: 16, attachmentCatalogFingerprint: 0,
      somaticSynergyCatalogFingerprint: 17, structureHash: "synthetic", delayFieldHash: "synthetic",
      connectomeHash: "synthetic", eventScheduleHash: "synthetic",
      bodyLoadFieldDynamics: .runtimeFoundationV0, bodySchemaDynamics: .runtimeFoundationV0, buffers: buffers)
    let source = try MetalNumiBrainCheckpoint(cognitiveState: c, fastTissueState: fast)
    return Fixture(template: template, parent: parent, source: source,
      encoded: try source.encoded(), physical: Data("synthetic physical checkpoint bytes".utf8))
  }

  func testDecoderForkPreservesAllMutableBytesAndCounters() throws {
    let f = try fixture(), fork = try f.fork(delta: 0.1)
    let before = f.source.cognitiveState, after = fork.checkpoint.cognitiveState
    XCTAssertEqual(fork.sourceBrainData, f.encoded)
    XCTAssertEqual(fork.physicalData, f.physical)
    XCTAssertEqual(after.hotState, before.hotState)
    XCTAssertEqual(after.persistentMemory, before.persistentMemory)
    XCTAssertEqual(after.connectomeState?.activity, before.connectomeState?.activity)
    XCTAssertEqual(fork.checkpoint.fastTissueState, f.source.fastTissueState)
    XCTAssertEqual(after.environmentIdentifier, before.environmentIdentifier)
    XCTAssertEqual(after.episodeIdentifier, before.episodeIdentifier)
    XCTAssertEqual(after.controlStepIdentifier, before.controlStepIdentifier)
    XCTAssertEqual(after.committedTimestamp, before.committedTimestamp)
    XCTAssertEqual(after.committedGeneration, before.committedGeneration)
    XCTAssertNotEqual(after.connectomeState?.programFingerprint, before.connectomeState?.programFingerprint)
    XCTAssertNotEqual(after.connectomeState?.sha256, before.connectomeState?.sha256)
    XCTAssertEqual(try MetalNumiBrainCheckpoint.decode(fork.targetBrainData), fork.checkpoint)
    XCTAssertEqual(try MetalNumiBrainCheckpoint.decode(f.encoded), f.source)
  }

  func testOppositeProbesRequireTheSameCompleteInitialSnapshots() throws {
    let f = try fixture()
    let negative = try f.fork(delta: -0.05, identifier: "negative")
    let positive = try f.fork(delta: 0.05, identifier: "positive")
    try negative.identity.validatePairedInitialization(with: positive.identity)
    let changedPhysics = try f.fork(delta: 0.05, identifier: "changed", physical: Data([0, 1, 2]))
    XCTAssertThrowsError(try negative.identity.validatePairedInitialization(with: changedPhysics.identity))
    XCTAssertThrowsError(try negative.identity.validatePairedInitialization(with: negative.identity))
    let duplicateIdentifier = try f.fork(delta: 0.05, identifier: "negative")
    XCTAssertThrowsError(try negative.identity.validatePairedInitialization(with: duplicateIdentifier.identity))
  }

  func testSameVisibleStateWithDifferentMemoryCannotBePaired() throws {
    let f = try fixture(), negative = try f.fork(delta: -0.05, identifier: "negative")
    let c = f.source.cognitiveState
    let changed = try MetalBrainCheckpoint(committedGeneration: c.committedGeneration,
      committedTimestamp: c.committedTimestamp, environmentIdentifier: c.environmentIdentifier,
      episodeIdentifier: c.episodeIdentifier, controlStepIdentifier: c.controlStepIdentifier,
      speciesTemplateFingerprint: c.speciesTemplateFingerprint,
      compiledSpeciesTemplateFingerprint: c.compiledSpeciesTemplateFingerprint,
      regionalProgramFingerprint: c.regionalProgramFingerprint, scheduleFingerprint: c.scheduleFingerprint,
      parameterVersionFingerprint: c.parameterVersionFingerprint, hotLayoutFingerprint: c.hotLayoutFingerprint,
      memoryLayoutFingerprint: c.memoryLayoutFingerprint, physicalCheckpointFingerprint: c.physicalCheckpointFingerprint,
      hotState: c.hotState, persistentMemory: Data([1, 2, 3, 4]), connectomeState: c.connectomeState)
    let encoded = try MetalNumiBrainCheckpoint(cognitiveState: changed, fastTissueState: f.source.fastTissueState).encoded()
    let positive = try MetalConnectomeDecoderFork.prepare(identifier: "positive", sourceBrainData: encoded,
      physicalData: f.physical, physicalCheckpointFingerprint: 555, parent: f.parent,
      target: f.program(delta: 0.05), template: f.template)
    XCTAssertThrowsError(try negative.identity.validatePairedInitialization(with: positive.identity))
  }

  func testUnchangedControllerForeignPublicationAndWrongPhysicalIdentityFail() throws {
    let f = try fixture()
    XCTAssertThrowsError(try f.fork(delta: 0))
    XCTAssertThrowsError(try f.fork(delta: 0.1, fingerprint: 556))
    XCTAssertThrowsError(try MetalConnectomeDecoderFork.prepare(identifier: "other", sourceBrainData: f.encoded,
      physicalData: f.physical, physicalCheckpointFingerprint: 555, parent: f.parent,
      target: f.program(delta: 0.1, parameters: 124), template: f.template))
  }

  func testNeuralOperatorChangesAreNotDecoderForks() throws {
    let f = try fixture(), target = try f.program(delta: 0.1)
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(target.spec)) as? [String: Any])
    for (key, value) in [("integrationStepMicroseconds", 500), ("maximumLogit", 7)] {
      var changed = json; changed[key] = value
      let spec = try JSONDecoder().decode(ConnectomeControllerSpec.self, from: JSONSerialization.data(withJSONObject: changed))
      let program = try ConnectomeControllerProgram(graph: f.parent.graph, spec: spec, template: f.template,
        parameterVersionFingerprint: 123)
      XCTAssertThrowsError(try program.validateDecoderOnlyChange(from: f.parent))
    }
    let receptor: [String: Any] = ["neuronIdentifier": 10, "modality": f.parent.spec.receptors[0].modality.rawValue,
      "receptorIndex": 0, "featureIndex": 0, "weight": 2, "scale": 1, "bias": 0, "clip": 8]
    json["receptors"] = [receptor]
    let spec = try JSONDecoder().decode(ConnectomeControllerSpec.self, from: JSONSerialization.data(withJSONObject: json))
    let program = try ConnectomeControllerProgram(graph: f.parent.graph, spec: spec, template: f.template,
      parameterVersionFingerprint: 123)
    XCTAssertThrowsError(try program.validateDecoderOnlyChange(from: f.parent))
  }

  func testBoundsAndResearchIdentityCannotBeWeakenedByDecoding() throws {
    let f = try fixture()
    XCTAssertThrowsError(try f.fork(delta: 0.1, identifier: "../unsafe"))
    XCTAssertThrowsError(try f.fork(delta: 0.1, identifier: ""))
    XCTAssertThrowsError(try f.fork(delta: 0.1, physical: Data()))
    XCTAssertThrowsError(try f.fork(delta: 0.1, budget: f.encoded.count))
    let fork = try f.fork(delta: 0.1)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(fork.identity)) as? [String: Any])
    object["promotable"] = true
    let decoded = try JSONDecoder().decode(ConnectomeDecoderForkIdentity.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertThrowsError(try decoded.validate())
  }
}

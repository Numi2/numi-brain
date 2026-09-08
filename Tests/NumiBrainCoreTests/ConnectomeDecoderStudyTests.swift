import Foundation
import XCTest
import NumiBrainConnectomeTestSupport
@testable import NumiBrainCore

final class ConnectomeDecoderStudyTests: XCTestCase {
  private func source() throws -> (ConnectomeControllerProgram, CompiledSpeciesTemplate) {
    let graph = try ConnectomeGraph(data: ConnectomeTestFixture.data())
    let body = try NumanXFullBodyTransportTemplate.compile(latencyMicroseconds: 1_000)
    let sense = try XCTUnwrap(body.species.senses.first(where: \.enabled))
    let spec = ConnectomeControllerSpec(graphFingerprint: graph.fingerprint,
      speciesFingerprint: body.species.fingerprint, sensoryProfileFingerprint: body.sensoryProfile.fingerprint,
      nominalStepMicroseconds: 1_000, integrationStepMicroseconds: 100, channelCount: 1,
      receptors: [.init(neuronIdentifier: 10, modality: sense.modality, receptorIndex: 0, featureIndex: 0)],
      descending: [.init(neuronIdentifier: 30, channel: 0)],
      decoderWeights: .init(repeating: 0.125, count: Int(body.species.motor.actuatorCount)),
      decoderBiases: .init(repeating: 0, count: Int(body.species.motor.actuatorCount)))
    return (try ConnectomeControllerProgram(graph: graph, spec: spec, template: body, parameterVersionFingerprint: 123), body)
  }
  private func settings(_ coordinates: [Int] = [0, 3]) throws -> ConnectomeDecoderStudySettings {
    try .init(coordinates: coordinates, directionSeed: 42, probeRadius: 0.05,
      learningRate: 0.01, gradientLimit: 10, trustRadius: 0.1, magnitudeLimit: 4,
      minimumResolvableLossDifference: 0.000001)
  }
  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    addTeardownBlock { try FileManager.default.removeItem(at: url) }
    return url
  }
  private func execution(program: UInt64? = nil, brain: UInt64? = nil) throws -> BrainPolicyNumanXRootExecution {
    try .init(sampleSHA256: String(repeating: "a", count: 64), ownerProgramFingerprint: 1,
      transactionFingerprint: 2, linearizationEpoch: 1, slotGeneration: 1,
      transactionSlot: 0, environment: 0, stepIndex: 0, controlStep: 1, substepIndex: 0,
      physicsSubstepCount: 1, outcome: .accepted, appliedRecordFingerprint: 3,
      jointCommitFingerprint: 4, brainProgramFingerprint: brain, connectomeProgramFingerprint: program)
  }
  private func captureFixture(_ identity: ConnectomeCaptureIdentity? = nil,
    dataset: String = "unit-test") throws -> BrainPolicyNumanXCaptureRunArtifact {
    try .init(runIdentifier: "synthetic-metadata-test-not-physical-evidence", sourceRevision: "test",
      datasetSourceIdentifier: dataset, datasetSourceRevision: "test", deviceRegistryID: 1,
      nativeModelSourceFingerprint: 2, acceptedStateProofProgramFingerprint: 3,
      compiledSpeciesTemplateFingerprint: identity?.compiledTemplateFingerprint ?? 4,
      parameterVersionFingerprint: identity?.parameterVersionFingerprint ?? 5,
      learningBatchArtifactSHA256: String(repeating: "d", count: 64), learningBatchFingerprint: 6,
      roots: [.init(controlStep: 1, sampleSHA256: String(repeating: "a", count: 64),
        executionSHA256: String(repeating: "b", count: 64), inferenceLatencyMicroseconds: 1)], connectome: identity)
  }

  func testSettingsAreCanonicalAndDirectionsRepeat() throws {
    let s = try settings(), t = try settings([0, 4])
    try s.validate(parameterCount: 5)
    XCTAssertEqual(try s.directions(), try s.directions())
    XCTAssertTrue(try s.directions().allSatisfy { abs($0) == 1 })
    XCTAssertNotEqual(try s.sha256, try t.sha256)
    XCTAssertThrowsError(try settings([3, 0]))
    XCTAssertThrowsError(try settings([0, 0]))
    XCTAssertThrowsError(try settings([-1]))
    XCTAssertThrowsError(try s.validate(parameterCount: 3))
    XCTAssertThrowsError(try settings([]))
  }
  func testDecoderReplacementPreservesGraphAndSensorOperator() throws {
    let (parent, body) = try source()
    var values = parent.spec.decoderParameters
    values[0] += 0.05; values[parent.spec.decoderWeights.count] -= 0.05
    let next = try ConnectomeControllerProgram(graph: parent.graph,
      spec: parent.spec.replacingDecoderParameters(values), template: body, parameterVersionFingerprint: 123)
    XCTAssertEqual(next.topologyFingerprint, parent.topologyFingerprint)
    XCTAssertEqual(next.binding.fingerprint, parent.binding.fingerprint)
    XCTAssertNotEqual(next.programFingerprint, parent.programFingerprint)
    XCTAssertEqual(next.spec.decoderWeights.dropFirst(), parent.spec.decoderWeights.dropFirst())
    XCTAssertEqual(next.spec.decoderBiases.dropFirst(), parent.spec.decoderBiases.dropFirst())
    XCTAssertThrowsError(try parent.spec.replacingDecoderParameters([0]))
  }
  func testRetainedIdentityRecompilesAndMissingSourceFails() throws {
    let directory = try temporaryDirectory(), (program, body) = try source()
    let identity = try ConnectomeCaptureIdentity.retain(program: program, template: body,
      brainProgramFingerprint: 99, directory: directory)
    let result = try identity.verify(directory: directory, expectedTemplateFingerprint: body.fingerprint,
      parameterVersionFingerprint: 123)
    XCTAssertEqual(result.programFingerprint, program.programFingerprint)
    XCTAssertThrowsError(try identity.verify(directory: directory, expectedTemplateFingerprint: body.fingerprint,
      parameterVersionFingerprint: 124))
    try Data([0]).write(to: BrainPolicyEvidenceArtifact.url(forSHA256: identity.specificationSHA256, in: directory))
    XCTAssertThrowsError(try identity.verify(directory: directory, expectedTemplateFingerprint: body.fingerprint,
      parameterVersionFingerprint: 123))
  }
  func testResearchScopeAndRecordCannotBeSilentlyRemoved() throws {
    let directory = try temporaryDirectory(), (program, body) = try source()
    let identity = try ConnectomeCaptureIdentity.retain(program: program, template: body,
      brainProgramFingerprint: 99, directory: directory)
    let capture = try captureFixture(identity)
    XCTAssertEqual(capture.formatVersion, 3)
    XCTAssertThrowsError(try ConnectomeCaptureIdentity.requireScope(run: capture, allowingResearch: false))
    try ConnectomeCaptureIdentity.requireScope(run: capture, allowingResearch: true)
    let legacy = try captureFixture()
    XCTAssertEqual(legacy.formatVersion, 2)
    XCTAssertFalse(String(decoding: try legacy.encoded(), as: UTF8.self).contains("connectome"))
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: capture.encoded()) as? [String: Any])
    object.removeValue(forKey: "connectome")
    XCTAssertThrowsError(try BrainPolicyNumanXCaptureRunArtifact.decode(JSONSerialization.data(withJSONObject: object)))
    XCTAssertThrowsError(try ConnectomeCaptureIdentity.requireScope(
      run: captureFixture(dataset: ConnectomeCaptureIdentity.datasetIdentifier), allowingResearch: true))
  }
  func testNativeExecutionMustNameTheExactDecoderAndBrain() throws {
    let directory = try temporaryDirectory(), (program, body) = try source()
    let identity = try ConnectomeCaptureIdentity.retain(program: program, template: body,
      brainProgramFingerprint: 99, directory: directory)
    try identity.validate(execution: execution(program: program.programFingerprint, brain: 99))
    XCTAssertThrowsError(try identity.validate(execution: execution()))
    XCTAssertThrowsError(try identity.validate(execution: execution(program: 1, brain: 99)))
    XCTAssertThrowsError(try identity.validate(execution: execution(program: program.programFingerprint, brain: 100)))
    XCTAssertThrowsError(try execution(program: program.programFingerprint))
    let legacy = try execution()
    XCTAssertEqual(legacy, try BrainPolicyNumanXRootExecution.decode(legacy.encoded()))
    XCTAssertFalse(String(decoding: try legacy.encoded(), as: UTF8.self).contains("connectomeProgramFingerprint"))
  }
}

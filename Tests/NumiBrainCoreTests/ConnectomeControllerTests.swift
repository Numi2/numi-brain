import Foundation
import XCTest
import NumiBrainCore
import NumiBrainConnectomeTestSupport

final class ConnectomeControllerTests: XCTestCase {
  func testBodyBoundControllerAndStableOperatorIdentity() throws {
    let graph = try ConnectomeGraph(data: ConnectomeTestFixture.data())
    let body = try NumanXFullBodyTransportTemplate.compile(latencyMicroseconds: 1_000)
    let modality = try XCTUnwrap(body.species.senses.first(where: \.enabled)).modality
    let spec = ConnectomeControllerSpec(graphFingerprint: graph.fingerprint,
      speciesFingerprint: body.species.fingerprint, sensoryProfileFingerprint: body.sensoryProfile.fingerprint,
      nominalStepMicroseconds: 20_000, integrationStepMicroseconds: 1_000,
      channelCount: 1, receptors: [ConnectomeReceptorProjection(neuronIdentifier: 10,
        modality: modality, receptorIndex: 0, featureIndex: 0)],
      descending: [ConnectomeDescendingProjection(neuronIdentifier: 30, channel: 0)],
      decoderWeights: [Float](repeating: 0.1, count: Int(body.species.motor.actuatorCount)),
      decoderBiases: [Float](repeating: 0, count: Int(body.species.motor.actuatorCount)))
    let first = try ConnectomeControllerProgram(graph: graph, spec: spec, template: body, parameterVersionFingerprint: 123)
    let successor = try ConnectomeControllerProgram(graph: graph, spec: spec, template: body, parameterVersionFingerprint: 124)
    XCTAssertEqual(first.programFingerprint, successor.programFingerprint)
    XCTAssertEqual(first.topologyFingerprint, successor.topologyFingerprint)
    XCTAssertNotEqual(first.binding.fingerprint, successor.binding.fingerprint)
    XCTAssertEqual(first.actuatorCount, body.species.motor.actuatorCount)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(spec)) as? [String: Any])
    object["decoderWeights"] = [Float(0)]
    let malformed = try JSONDecoder().decode(ConnectomeControllerSpec.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertThrowsError(try ConnectomeControllerProgram(graph: graph, spec: malformed, template: body, parameterVersionFingerprint: 123))
  }

  func testCheckpointRoundTripCorruptionAndMigration() throws {
    var values: [Float] = [0, -0.25, 0.75]
    let data = values.withUnsafeMutableBytes { Data($0) }
    let checkpoint = try ConnectomeCheckpoint(graphFingerprint: 1, topologyFingerprint: 2,
      programFingerprint: 3, parameterVersionFingerprint: 4, environmentIdentifier: 0,
      episodeIdentifier: 1, generation: 7, timestampMicroseconds: 20_000, activity: data)
    let encoded = try JSONEncoder().encode(checkpoint)
    let decoded = try JSONDecoder().decode(ConnectomeCheckpoint.self, from: encoded)
    try decoded.validate(); XCTAssertEqual(checkpoint, decoded)
    let rebound = try checkpoint.rebinding(parameterVersionFingerprint: 5)
    XCTAssertEqual(rebound.activity, checkpoint.activity)
    XCTAssertEqual(rebound.programFingerprint, checkpoint.programFingerprint)
    XCTAssertNotEqual(rebound.sha256, checkpoint.sha256)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object["generation"] = 8
    let corrupt = try JSONDecoder().decode(ConnectomeCheckpoint.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertThrowsError(try corrupt.validate())
    values[1] = .nan
    XCTAssertThrowsError(try ConnectomeCheckpoint(graphFingerprint: 1, topologyFingerprint: 2,
      programFingerprint: 3, parameterVersionFingerprint: 4, environmentIdentifier: 0,
      episodeIdentifier: 1, generation: 7, timestampMicroseconds: 20_000,
      activity: values.withUnsafeBytes { Data($0) }))
  }

  func testPreparedNeuralImageBindsBothGenerationsAndCachedReadout() throws {
    let root = try BrainJointTransactionToken(environmentIdentifier: 0, episodeIdentifier: 1,
      controlStepIdentifier: 1, parameterVersionFingerprint: 4,
      baseBrainGeneration: 0, basePhysicsGeneration: 0,
      committedTimestamp: BrainTimestamp(microseconds: 1_000),
      targetTimestamp: BrainTimestamp(microseconds: 2_000), randomCounterGeneration: 1)
    func checkpoint(_ generation: UInt64, _ time: UInt64) throws -> ConnectomeCheckpoint {
      try ConnectomeCheckpoint(graphFingerprint: 1, topologyFingerprint: 2,
        programFingerprint: 3, parameterVersionFingerprint: 4, environmentIdentifier: 0,
        episodeIdentifier: 1, generation: generation, timestampMicroseconds: time,
        activity: [Float(0.25)].withUnsafeBytes { Data($0) })
    }
    let image = try ConnectomePreparedState(base: checkpoint(0, 1_000),
      candidate: checkpoint(1, 2_000), descending: [Float(0.5)].withUnsafeBytes { Data($0) }, root: root)
    try image.validate(root: root)
    XCTAssertEqual(image.digestChunks.count, 6)
    XCTAssertThrowsError(try ConnectomePreparedState(base: checkpoint(1, 1_000),
      candidate: checkpoint(1, 2_000), descending: image.descending, root: root))
  }
}

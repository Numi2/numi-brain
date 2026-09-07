import Foundation
import XCTest
import NumiBrainCore
import NumiBrainConnectomeTestSupport
@testable import NumiBrainMetal
import NumiBrainMLX
import MLX

/// Synthetic numerical learning fixtures. They are never persisted as native
/// demonstrations and do not establish physical task success.
@available(macOS 26.0, *)
final class ConnectomeDecoderLearningTests: XCTestCase {
  private func program(actuators: Int = 6, mode: ConnectomeExecutionMode = .observeTeacher) throws -> ConnectomeProgram {
    let template = try makeNumanXInteropCompiledTemplate(actuatorCount: UInt32(actuators))
    let publication = try BrainParameterPublication.developmentalSeedV1(species: template.species, tissueParameters: .corticalSheetV0)
    let graph = try ConnectomeGraph(data: ConnectomeTestFixture.data())
    let binding = try ConnectomeBinding(graph: graph, template: template,
      parameterVersionFingerprint: publication.version.fingerprint, channelCount: 1,
      nominalStepMicroseconds: 1_000, integrationStepMicroseconds: 1_000,
      receptors: [.init(neuronIdentifier: 10, modality: .proprioception, receptorIndex: 0, featureIndex: 0)],
      descending: [.init(neuronIdentifier: 30, channel: 0)])
    let decoder = try ConnectomeMotorDecoder(binding: binding, template: template,
      weights: Array(repeating: 0, count: actuators), bias: Array(repeating: 0, count: actuators),
      maximumDriveChangePerSecond: 2)
    return try ConnectomeProgram(graph: graph, binding: binding, decoder: decoder, executionMode: mode)
  }
  private func rows(_ program: ConnectomeProgram, episode: UInt64) throws -> [ConnectomeTrainingRow] {
    try (1...24).map { i in
      let feature = Float(i)/24
      let hash = String(format: "%064llx", episode*100+UInt64(i))
      return try ConnectomeTrainingRow(program: program, episodeIdentifier: episode, generation: UInt64(i),
        controlStep: UInt32(i), transactionFingerprint: episode*100+UInt64(i), timestampMicroseconds: UInt64(i)*1000,
        executionSHA256: hash, motorActionSHA256: hash, features: [feature],
        normalizedDrives: Array(repeating: tanh(0.7*feature+0.1), count: Int(program.decoder.actuatorCount)))
    }
  }
  func testModeAndMorphologyAreDistinctRuntimeIdentities() throws {
    let teacher = try program(), student = try program(mode: .actuate), other = try program(actuators: 8)
    XCTAssertNotEqual(teacher.fingerprint, student.fingerprint)
    XCTAssertEqual(teacher.graph.fingerprint, other.graph.fingerprint)
    XCTAssertNotEqual(teacher.decoder.compiledSpeciesFingerprint, other.decoder.compiledSpeciesFingerprint)
    XCTAssertThrowsError(try rows(student, episode: 1))
  }
  func testSameEpisodeAndDuplicateRootsAreRejected() throws {
    let p = try program(), a = try rows(p, episode: 1), b = try rows(p, episode: 2)
    XCTAssertNoThrow(try ConnectomeTrainingSplit(program: p, training: a, heldOut: b))
    XCTAssertThrowsError(try ConnectomeTrainingSplit(program: p, training: Array(a.prefix(12)), heldOut: Array(a.suffix(12))))
    XCTAssertThrowsError(try ConnectomeTrainingSplit(program: p, training: a+a, heldOut: b))
    XCTAssertThrowsError(try ConnectomeTrainingSplit(program: p, training: [], heldOut: b))
  }
  func testOfflineDecoderCPUReferenceLearnsWithoutMutatingGraphOrParent() throws {
    let p = try program(), a = try rows(p, episode: 1), b = try rows(p, episode: 2)
    let oldWeights = p.decoder.weights, graph = p.graph.bytes
    let result = try Device.withDefaultDevice(.cpu) { try MLXConnectomeDecoderLearner.train(program: p,
      split: ConnectomeTrainingSplit(program: p, training: a, heldOut: b),
      settings: .init(iterations: 300, learningRate: 0.1, l2: 0.0001)) }
    XCTAssertFalse(result.promotable)
    XCTAssertLessThan(result.trainingActionMSEAfter, result.trainingActionMSEBefore*0.02)
    XCTAssertLessThan(result.heldOutActionMSEAfter, result.heldOutActionMSEBefore*0.02)
    XCTAssertNotEqual(result.decoder.fingerprint, p.decoder.fingerprint)
    XCTAssertEqual(p.decoder.weights, oldWeights); XCTAssertEqual(p.graph.bytes, graph)
    _ = try result.decoder.validated()
  }
}

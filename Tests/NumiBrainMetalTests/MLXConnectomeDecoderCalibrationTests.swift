import Foundation
import XCTest
import Metal
import NumiBrainConnectomeTestSupport
import NumiBrainCore
@testable import NumiBrainMLX

/// Learner arithmetic only. No synthetic scalar can mint a physical evaluation;
/// the public update entrypoint rereads and verifies native capture artifacts.
@available(macOS 26.0, *)
final class MLXConnectomeDecoderCalibrationTests: XCTestCase {
  private func settings(_ coordinates: [Int] = [0, 2]) throws -> ConnectomeDecoderStudySettings {
    try .init(coordinates: coordinates, directionSeed: 42, probeRadius: 0.125,
      learningRate: 0.1, gradientLimit: 10, trustRadius: 0.05, magnitudeLimit: 4,
      minimumResolvableLossDifference: 0.000001)
  }
  func testDirectionEstimateUpdatesSelectedCoordinatesOnly() throws {
    let s = try settings(), old: [Float] = [0, 0.25, 0], signs = try s.directions()
    var negative = old, positive = old
    for (j, i) in s.coordinates.enumerated() {
      negative[i] -= signs[j]*s.probeRadius; positive[i] += signs[j]*s.probeRadius
    }
    let updated = try MLXConnectomeDecoderCalibration.proposedParameters(parent: old,
      negative: negative, positive: positive, negativeLoss: 1, positiveLoss: 1.5, settings: s)
    XCTAssertEqual(updated[1].bitPattern, old[1].bitPattern)
    for (j, i) in s.coordinates.enumerated() {
      XCTAssertEqual(updated[i], -signs[j]*0.05, accuracy: 0.000001)
      XCTAssertLessThanOrEqual(abs(updated[i]-old[i]), s.trustRadius)
    }
  }
  func testUnresolvedAndNonfinitePhysicalDifferencesAreRejected() throws {
    let s = try settings([0])
    for (n, p) in [(1.0, 1.0), (Double.nan, 1.0), (1.0, Double.infinity)] {
      XCTAssertThrowsError(try MLXConnectomeDecoderCalibration.proposedParameters(parent: [0],
        negative: [-0.125], positive: [0.125], negativeLoss: n, positiveLoss: p, settings: s))
    }
    XCTAssertThrowsError(try MLXConnectomeDecoderCalibration.proposedParameters(parent: [0],
      negative: [0], positive: [0.125], negativeLoss: 1, positiveLoss: 2, settings: s))
  }
  func testProbesPerturbActualWeightsAndBiasesWithFrozenNeuralTopology() throws {
    let graph = try ConnectomeGraph(data: ConnectomeTestFixture.data())
    let body = try NumanXFullBodyTransportTemplate.compile(latencyMicroseconds: 1_000)
    let sense = try XCTUnwrap(body.species.senses.first(where: \.enabled))
    let count = Int(body.species.motor.actuatorCount)
    let spec = ConnectomeControllerSpec(graphFingerprint: graph.fingerprint,
      speciesFingerprint: body.species.fingerprint, sensoryProfileFingerprint: body.sensoryProfile.fingerprint,
      nominalStepMicroseconds: 1_000, integrationStepMicroseconds: 100, channelCount: 1,
      receptors: [.init(neuronIdentifier: 10, modality: sense.modality, receptorIndex: 0, featureIndex: 0)],
      descending: [.init(neuronIdentifier: 30, channel: 0)],
      decoderWeights: .init(repeating: 0, count: count), decoderBiases: .init(repeating: 0, count: count))
    let parent = try ConnectomeControllerProgram(graph: graph, spec: spec, template: body, parameterVersionFingerprint: 123)
    let s = try settings([0, count]), a = try MLXConnectomeDecoderCalibration.probes(parent: parent, settings: s)
    let repeatPair = try MLXConnectomeDecoderCalibration.probes(parent: parent, settings: s)
    XCTAssertEqual(a.negative.decoderParameters, repeatPair.negative.decoderParameters)
    for candidate in [a.negative, a.positive] {
      let program = try ConnectomeControllerProgram(graph: graph, spec: candidate, template: body, parameterVersionFingerprint: 123)
      XCTAssertEqual(program.topologyFingerprint, parent.topologyFingerprint)
      XCTAssertNotEqual(program.programFingerprint, parent.programFingerprint)
      XCTAssertEqual(candidate.decoderWeights.dropFirst(), spec.decoderWeights.dropFirst())
      XCTAssertEqual(candidate.decoderBiases.dropFirst(), spec.decoderBiases.dropFirst())
    }
    var saturated = spec.decoderParameters; saturated[0] = 4
    let boundary = try ConnectomeControllerProgram(graph: graph,
      spec: spec.replacingDecoderParameters(saturated), template: body, parameterVersionFingerprint: 123)
    XCTAssertThrowsError(try MLXConnectomeDecoderCalibration.probes(parent: boundary, settings: s))
  }
  func testPublicLearningRejectsMissingEvidenceInsteadOfAcceptingScalarLosses() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    XCTAssertThrowsError(try MLXConnectomeDecoderCalibration.update(planSHA256: String(repeating: "a", count: 64),
      negativeEvaluationSHA256: String(repeating: "b", count: 64),
      positiveEvaluationSHA256: String(repeating: "c", count: 64), directory: path))
  }
  func testTrustIntervalIsHonoredAfterFP32Rounding() throws {
    let s = try settings([0]), old: [Float] = [0.6]
    let result = try MLXConnectomeDecoderCalibration.proposedParameters(parent: old,
      negative: [old[0]-s.probeRadius], positive: [old[0]+s.probeRadius],
      negativeLoss: 1, positiveLoss: 0, settings: s)
    XCTAssertGreaterThan(result[0], old[0])
    XCTAssertLessThanOrEqual(Double(result[0])-Double(old[0]), Double(s.trustRadius))
  }
  func testUnrepresentableLearningStepIsRejected() throws {
    let s = try ConnectomeDecoderStudySettings(coordinates: [0], directionSeed: 1,
      probeRadius: 0.125, learningRate: 0.1, gradientLimit: 10, trustRadius: 1e-10,
      magnitudeLimit: 4, minimumResolvableLossDifference: 0.000001)
    XCTAssertThrowsError(try MLXConnectomeDecoderCalibration.proposedParameters(parent: [0.75],
      negative: [0.625], positive: [0.875], negativeLoss: 1, positiveLoss: 0, settings: s))
  }

}

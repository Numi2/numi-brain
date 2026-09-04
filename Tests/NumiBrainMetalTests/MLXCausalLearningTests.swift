import Foundation
import Metal
import MLX
import XCTest
import NumiBrainCore
@testable import NumiBrainMLX

/// Device-side tensor regressions, not physical-task qualification evidence.
@available(macOS 26.0, *)
final class MLXCausalLearningTests: XCTestCase {
  override func setUpWithError() throws {
    guard let device = MTLCreateSystemDefaultDevice(),
      device.makeMTL4CommandQueue() != nil
    else { throw XCTSkip("Apple Metal 4 execution is unavailable") }
  }

  private func parameters() -> (MLXArray, MLXArray) {
    var belief = [Float](repeating: 0, count: 16)
    belief[0] = 0.8
    belief[4] = 0.1
    belief[7] = 0.6
    var policy = [Float](repeating: 0, count: 32)
    policy[0] = 0.7
    policy[8] = -0.05
    return (MLXArray(belief), MLXArray(policy))
  }

  private func sequence(_ generations: [UInt64?]) throws -> BrainCommittedSequenceIndex {
    try BrainCommittedSequenceIndex(
      records: generations.map { generation in
        generation.map {
          BrainCommittedSequenceRecord(
            identifier: $0, sourceGeneration: $0,
            startTimestampMicroseconds: ($0 - 1) * 100,
            endTimestampMicroseconds: $0 * 100,
            parameterVersionFingerprint: 7
          )
        }
      },
      parameterVersionFingerprint: 7, maximumSourceGeneration: UInt64.max
    )
  }

  func testPolicyHeadMatchesIndependentScalarReference() {
    let rows = 3
    let prior = (0..<(rows * 24)).map { Float($0 % 11 - 5) * 0.03 }
    let observation = (0..<(rows * 24)).map { Float($0 % 7 - 3) * 0.06 }
    let mask = (0..<(rows * 24)).map { $0 % 4 == 0 ? Float(0) : Float(1) }
    let (belief, policy) = parameters()
    let actual = MLXEmbodiedPolicyHead.predict(
      prior: MLXArray(prior, [rows, 24]),
      observations: MLXArray(observation, [rows, 24]),
      observationMask: MLXArray(mask, [rows, 24]), belief: belief, policy: policy
    ).asArray(Float.self)
    for row in 0..<rows {
      for synergy in 0..<16 {
        let base = row * 24
        var evidence = mask[base + synergy] > 0 ? observation[base + synergy] : 0
        if synergy < 8, mask[base + 16 + synergy] > 0 {
          evidence += 0.25 * observation[base + 16 + synergy]
        }
        let posterior = Float(tanh(Double(
          0.6 * prior[base + synergy] + 0.8 * evidence + 0.1
        )))
        let expected = Float(tanh(Double(0.7 * posterior - 0.05)))
        XCTAssertEqual(actual[row * 16 + synergy], expected, accuracy: 1.0e-6)
      }
    }
  }

  func testAllTwentyFourObservationComponentsReachTheExpectedSynergy() {
    var belief = [Float](repeating: 0, count: 16)
    belief[0] = 1
    var policy = [Float](repeating: 0, count: 32)
    policy[0] = 1
    for component in 0..<24 {
      var observation = [Float](repeating: 0, count: 24)
      observation[component] = 0.4
      let output = MLXEmbodiedPolicyHead.predict(
        prior: MLXArray([Float](repeating: 0, count: 24), [1, 24]),
        observations: MLXArray(observation, [1, 24]),
        observationMask: MLXArray([Float](repeating: 1, count: 24), [1, 24]),
        belief: MLXArray(belief), policy: MLXArray(policy)
      ).asArray(Float.self)
      let expectedSynergy = component < 16 ? component : component - 16
      for synergy in 0..<16 {
        if synergy == expectedSynergy {
          XCTAssertGreaterThan(output[synergy], 0.01)
        } else {
          XCTAssertEqual(output[synergy], 0, accuracy: 1.0e-7)
        }
      }
    }
  }

  func testAvailabilityAloneAddsNoMotorBiasAndMissingNaNsAreExcluded() {
    let zero = MLXArray([Float](repeating: 0, count: 24), [1, 24])
    let ones = MLXArray([Float](repeating: 1, count: 24), [1, 24])
    let missing = MLXArray([Float](repeating: .nan, count: 24), [1, 24])
    let (belief, policy) = parameters()
    let present = MLXEmbodiedPolicyHead.predict(
      prior: zero, observations: zero, observationMask: ones, belief: belief, policy: policy
    ).asArray(Float.self)
    let absent = MLXEmbodiedPolicyHead.predict(
      prior: zero, observations: missing, observationMask: zero, belief: belief, policy: policy
    ).asArray(Float.self)
    XCTAssertEqual(present, absent)
    XCTAssertTrue(absent.allSatisfy(\.isFinite))
  }

  func testPolicyObjectiveDifferentiatesCausalBeliefButNotFutureState() {
    let (belief, policy) = parameters()
    let prior = MLXArray([Float](repeating: 0.1, count: 24), [1, 24])
    let observation = MLXArray([Float](repeating: 0.2, count: 24), [1, 24])
    let mask = MLXArray([Float](repeating: 1, count: 24), [1, 24])
    let future = MLXArray([Float](repeating: 0.9, count: 24), [1, 24])
    let differentiated = valueAndGrad({ parameters -> [MLXArray] in
      let action = MLXEmbodiedPolicyHead.predict(
        prior: prior, observations: observation, observationMask: mask,
        belief: parameters[0], policy: parameters[1]
      )
      return [square(action).mean()]
    }, argumentNumbers: 0..<3)
    let (_, gradient) = differentiated([belief, policy, future])
    XCTAssertGreaterThan(abs(gradient[0][0].item(Float.self)), 1.0e-6)
    XCTAssertGreaterThan(abs(gradient[1][0].item(Float.self)), 1.0e-6)
    XCTAssertEqual(gradient[2].asArray(Float.self), [Float](repeating: 0, count: 24))
  }

  func testFrozenCoordinatesSurviveClippingBitForBit() {
    let parent: [Float] = [9, -0.0, -3, 1, 1, 0.25]
    let output = MLXImmutableParameterUpdate.project(
      parent: MLXArray(parent), delta: MLXArray([Float](arrayLiteral: 1, 1, 1, 100, -100, 1)),
      magnitudeLimit: 2, mutableMask: MLXArray([Float](arrayLiteral: 0, 0, 0, 1, 1, 0))
    ).asArray(Float.self)
    for coordinate in [0, 1, 2, 5] {
      XCTAssertEqual(output[coordinate].bitPattern, parent[coordinate].bitPattern)
    }
    XCTAssertEqual(output[3], -2)
    XCTAssertEqual(output[4], 2)
  }

  func testUnmaskedParameterProjectionRetainsOrdinaryUpdateSemantics() {
    let output = MLXImmutableParameterUpdate.project(
      parent: MLXArray([Float](arrayLiteral: 0.5, -0.5, 1.5)),
      delta: MLXArray([Float](arrayLiteral: 0.25, 3, -3)), magnitudeLimit: 2
    ).asArray(Float.self)
    XCTAssertEqual(output, [0.25, -2, 2])
  }

  func testGatherValuesFollowWrappedIdentityAndUseZeroForMissingLinks() throws {
    let index = try sequence([3, 1, nil, 2, 4])
    let gathers = MLXCommittedSequenceGathers(
      index: index, validMask: MLXArray([Float](arrayLiteral: 1, 1, 0, 1, 1), [5, 1])
    )
    let values = MLXArray([Float](arrayLiteral: 30, 300, 10, 100, .nan, .nan, 20, 200, 40, 400), [5, 2])
    XCTAssertEqual(gathers.oneStepSuccessors(values).asArray(Float.self),
      [40, 400, 20, 200, 0, 0, 30, 300, 0, 0])
    XCTAssertEqual(gathers.twoStepSuccessors(values).asArray(Float.self),
      [0, 0, 30, 300, 0, 0, 40, 400, 0, 0])
  }

  func testInvalidIntermediateRecordBlocksTwoStepLearning() throws {
    let gathers = MLXCommittedSequenceGathers(
      index: try sequence([1, 2, 3]),
      validMask: MLXArray([Float](arrayLiteral: 1, 0, 1), [3, 1])
    )
    let values = MLXArray([Float](arrayLiteral: 10, .nan, 30), [3, 1])
    XCTAssertEqual(gathers.oneStepSuccessors(values).asArray(Float.self), [0, 0, 0])
    XCTAssertEqual(gathers.twoStepSuccessors(values).asArray(Float.self), [0, 0, 0])
  }

  func testMissingEdgeDoesNotMultiplyAnUnrelatedNaNByZero() throws {
    let gathers = MLXCommittedSequenceGathers(
      index: try sequence([nil, 8]),
      validMask: MLXArray([Float](arrayLiteral: 0, 1), [2, 1])
    )
    let values = MLXArray([Float](arrayLiteral: .nan, 10), [2, 1])
    XCTAssertEqual(gathers.oneStepSuccessors(values).asArray(Float.self), [0, 0])
    XCTAssertEqual(gathers.twoStepSuccessors(values).asArray(Float.self), [0, 0])
  }

  func testTemporalTensorStorageIsLinearInRingCapacity() throws {
    let count = 10_000
    let gathers = MLXCommittedSequenceGathers(
      index: try sequence((1...count).map { UInt64($0) }),
      validMask: MLXArray([Float](repeating: 1, count: count), [count, 1])
    )
    XCTAssertEqual(gathers.oneStepIndices.shape, [count])
    XCTAssertEqual(gathers.twoStepIndices.shape, [count])
    XCTAssertEqual(gathers.oneStepMask.shape, [count, 1])
    XCTAssertEqual(gathers.twoStepMask.shape, [count, 1])
  }
}

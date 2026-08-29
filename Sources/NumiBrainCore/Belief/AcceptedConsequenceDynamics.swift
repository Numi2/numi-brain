import Foundation

/// Immutable gains for reconciling a shadow decision with receptor signals
/// generated from an accepted physical outcome. These updates never run for a
/// rejected NumanX candidate.
@frozen
public struct AcceptedConsequenceDynamics: Codable, Equatable, Hashable, Sendable {
  public let beliefGain: Float
  public let worldCorrectionGain: Float
  public let cerebellarLearningRate: Float
  public let plasticityLearningRate: Float

  public init(
    beliefGain: Float,
    worldCorrectionGain: Float,
    cerebellarLearningRate: Float,
    plasticityLearningRate: Float
  ) throws {
    let values = [
      beliefGain, worldCorrectionGain, cerebellarLearningRate,
      plasticityLearningRate,
    ]
    guard values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
      throw BrainRuntimeError.invalidDescriptor(
        "accepted-consequence dynamics must contain finite unit gains"
      )
    }
    self.beliefGain = beliefGain
    self.worldCorrectionGain = worldCorrectionGain
    self.cerebellarLearningRate = cerebellarLearningRate
    self.plasticityLearningRate = plasticityLearningRate
  }

  public static var foundationV1: Self {
    try! Self(
      beliefGain: 0.2,
      worldCorrectionGain: 0.1,
      cerebellarLearningRate: 0.25,
      plasticityLearningRate: 0.001
    )
  }
}

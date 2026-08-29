import Foundation

/// Shared policy for deadline-bounded retrieval across explicit memory stores.
/// The GPU scans stores in parallel and publishes deterministic winners into
/// workspace tokens; unavailable archive pages are intentionally not waited on.
@frozen
public struct MemoryRetrievalDynamics: Codable, Equatable, Hashable, Sendable {
  public let minimumScore: Float
  public let episodicWeight: Float
  public let semanticWeight: Float
  public let proceduralWeight: Float
  public let prospectiveWeight: Float
  public let maximumResults: UInt16

  public init(
    minimumScore: Float,
    episodicWeight: Float,
    semanticWeight: Float,
    proceduralWeight: Float,
    prospectiveWeight: Float,
    maximumResults: UInt16
  ) throws {
    let weights = [
      episodicWeight, semanticWeight, proceduralWeight, prospectiveWeight,
    ]
    guard minimumScore.isFinite,
      weights.allSatisfy({ $0.isFinite && $0 >= 0 }),
      maximumResults > 0, maximumResults <= 4
    else {
      throw BrainRuntimeError.invalidDescriptor("memory retrieval dynamics are invalid")
    }
    self.minimumScore = minimumScore
    self.episodicWeight = episodicWeight
    self.semanticWeight = semanticWeight
    self.proceduralWeight = proceduralWeight
    self.prospectiveWeight = prospectiveWeight
    self.maximumResults = maximumResults
  }

  public static var foundationV1: Self {
    get throws {
      try Self(
        minimumScore: 0.1,
        episodicWeight: 1,
        semanticWeight: 0.8,
        proceduralWeight: 0.9,
        prospectiveWeight: 1.1,
        maximumResults: 4
      )
    }
  }
}

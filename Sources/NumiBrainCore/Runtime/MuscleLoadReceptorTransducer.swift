import Foundation
import NumiBrainABI

/// Converts one accepted physical muscle-load consequence into a causal
/// receptor-derived interrupt. The neural scheduler receives only the event;
/// it does not receive the authoritative generalized-force vector.
@frozen
public struct MuscleLoadReceptorTransducer: Codable, Equatable, Hashable, Sendable {
  public let overloadThreshold: Float

  public init(overloadThreshold: Float) throws {
    guard overloadThreshold.isFinite, overloadThreshold > 0 else {
      throw BrainRuntimeError.invalidEvent(
        "muscle-overload threshold must be finite and positive"
      )
    }
    self.overloadThreshold = overloadThreshold
  }

  public func transduce(
    maximumAbsoluteMuscleForce: Float,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    receptorIdentifier: UInt32
  ) throws -> BrainInterruptEvent? {
    guard maximumAbsoluteMuscleForce.isFinite,
      maximumAbsoluteMuscleForce >= 0
    else {
      throw BrainRuntimeError.invalidEvent(
        "accepted muscle-load observation must be finite and nonnegative"
      )
    }
    guard receptorIdentifier != 0 else {
      throw BrainRuntimeError.invalidEvent("receptor identifier zero is reserved")
    }
    guard maximumAbsoluteMuscleForce > overloadThreshold else { return nil }
    return try BrainInterruptEvent(
      timestamp: acceptedPhysicsState.acceptedTimestamp,
      mask: .muscleOverload,
      identifier: receptorIdentifier,
      flags: UInt32(NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED)
    )
  }
}

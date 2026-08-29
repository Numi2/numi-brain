import Foundation
import NumiBrainABI

@frozen
public struct LocalizedMuscleLoadReceptorObservation:
  Codable, Equatable, Hashable, Sendable
{
  public let event: BrainInterruptEvent
  public let acceptedPhysicsStateFingerprint: UInt64
  public let attachmentCatalogFingerprint: UInt64
  public let maximumAbsoluteMuscleForce: Float
  public let attachment: NumanXMuscleAttachment

  public init(
    event: BrainInterruptEvent,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    attachmentCatalogFingerprint: UInt64,
    maximumAbsoluteMuscleForce: Float,
    attachment: NumanXMuscleAttachment
  ) throws {
    guard event.timestamp == acceptedPhysicsState.acceptedTimestamp,
      event.mask == .muscleOverload,
      event.identifier == attachment.muscleIdentifier,
      event.flags & UInt32(NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED) != 0,
      attachmentCatalogFingerprint != 0,
      maximumAbsoluteMuscleForce.isFinite,
      maximumAbsoluteMuscleForce >= 0
    else {
      throw BrainRuntimeError.invalidEvent(
        "localized muscle-load observation does not match accepted physics"
      )
    }
    self.event = event
    self.acceptedPhysicsStateFingerprint = acceptedPhysicsState.fingerprint
    self.attachmentCatalogFingerprint = attachmentCatalogFingerprint
    self.maximumAbsoluteMuscleForce = maximumAbsoluteMuscleForce
    self.attachment = attachment
  }
}

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
    guard maximumAbsoluteMuscleForce > overloadThreshold else { return nil }
    return try BrainInterruptEvent(
      timestamp: acceptedPhysicsState.acceptedTimestamp,
      mask: .muscleOverload,
      identifier: receptorIdentifier,
      flags: UInt32(NB_INTERRUPT_EVENT_FLAG_RECEPTOR_DERIVED),
      magnitude: maximumAbsoluteMuscleForce,
      auxiliaryValue: overloadThreshold
    )
  }

  public func transduceLocalized(
    maximumAbsoluteMuscleForce: Float,
    acceptedPhysicsState: AcceptedPhysicsStateToken,
    muscleIdentifier: UInt32,
    attachmentCatalog: NumanXMuscleAttachmentCatalog
  ) throws -> LocalizedMuscleLoadReceptorObservation? {
    guard
      let attachment = attachmentCatalog.attachment(
        forMuscleIdentifier: muscleIdentifier
      )
    else {
      throw BrainRuntimeError.invalidEvent(
        "muscle-load identifier is absent from the attachment catalog"
      )
    }
    guard
      let event = try transduce(
        maximumAbsoluteMuscleForce: maximumAbsoluteMuscleForce,
        acceptedPhysicsState: acceptedPhysicsState,
        receptorIdentifier: muscleIdentifier
      )
    else { return nil }
    return try LocalizedMuscleLoadReceptorObservation(
      event: event,
      acceptedPhysicsState: acceptedPhysicsState,
      attachmentCatalogFingerprint: attachmentCatalog.fingerprint,
      maximumAbsoluteMuscleForce: maximumAbsoluteMuscleForce,
      attachment: attachment
    )
  }
}

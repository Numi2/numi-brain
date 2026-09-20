/// Evidence conditions required before a paired affect study can expose a
/// behavior comparison. This is an eligibility gate, not a qualification claim.
@frozen
public struct BrainPolicyNumanXAffectPairEligibility:
  Equatable, Sendable
{
  public let matchedNativeRuntimeIdentity: Bool
  public let matchedNativeWorldIdentity: Bool
  public let matchedPreparedInitialStateFingerprint: Bool
  public let affectConfigurationProvenanceMatches: Bool
  public let matchedSyntheticBootstrapProvenance: Bool
  public let matchedBootstrapSensorSample: Bool
  public let hasAcceptedNativeAggregateEvidence: Bool
  public let enabledBehaviorResultAvailable: Bool
  public let disabledBehaviorResultAvailable: Bool

  public init(
    matchedNativeRuntimeIdentity: Bool,
    matchedNativeWorldIdentity: Bool,
    matchedPreparedInitialStateFingerprint: Bool,
    affectConfigurationProvenanceMatches: Bool,
    matchedSyntheticBootstrapProvenance: Bool,
    matchedBootstrapSensorSample: Bool,
    hasAcceptedNativeAggregateEvidence: Bool,
    enabledBehaviorResultAvailable: Bool,
    disabledBehaviorResultAvailable: Bool
  ) {
    self.matchedNativeRuntimeIdentity = matchedNativeRuntimeIdentity
    self.matchedNativeWorldIdentity = matchedNativeWorldIdentity
    self.matchedPreparedInitialStateFingerprint =
      matchedPreparedInitialStateFingerprint
    self.affectConfigurationProvenanceMatches =
      affectConfigurationProvenanceMatches
    self.matchedSyntheticBootstrapProvenance =
      matchedSyntheticBootstrapProvenance
    self.matchedBootstrapSensorSample = matchedBootstrapSensorSample
    self.hasAcceptedNativeAggregateEvidence =
      hasAcceptedNativeAggregateEvidence
    self.enabledBehaviorResultAvailable = enabledBehaviorResultAvailable
    self.disabledBehaviorResultAvailable = disabledBehaviorResultAvailable
  }

  public var isEligible: Bool {
    matchedNativeRuntimeIdentity
      && matchedNativeWorldIdentity
      && matchedPreparedInitialStateFingerprint
      && affectConfigurationProvenanceMatches
      && matchedSyntheticBootstrapProvenance
      && matchedBootstrapSensorSample
      && hasAcceptedNativeAggregateEvidence
      && enabledBehaviorResultAvailable
      && disabledBehaviorResultAvailable
  }
}

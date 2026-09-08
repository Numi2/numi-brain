import NumiBrainCore

@available(macOS 26.0, *)
extension NumiLabLiveRolloutSnapshot {
  /// Physical generation is the native accepted-step count of this fresh,
  /// single-environment compatibility world, never an application-chosen offset.
  func nextPhysicsGeneration(expectedBase: UInt64) throws -> UInt64 {
    let next = completedEnvironmentSteps.addingReportingOverflow(1)
    guard identity.environmentCount == 1, !next.overflow,
      completedEnvironmentSteps == expectedBase,
      submittedControlSteps == completedEnvironmentSteps,
      submissionCount == completedEnvironmentSteps else {
      throw TissueError.transaction("NumiLab root is stale or does not match the native physical generation")
    }
    return next.partialValue
  }
}

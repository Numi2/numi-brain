public enum ReferenceBrainSchedule {
  /// Executable Phase 1 subset of the 96-module mammalian reference graph.
  /// It is a scheduler qualification fixture, not a complete active brain graph.
  public static func runtimeFoundationSubset() throws -> BrainModuleSchedule {
    try BrainModuleSchedule(modules: [
      BrainModuleDescriptor(
        moduleIdentifier: 12,
        clockClass: .emergency,
        periodMicroseconds: 1_000,
        intrinsicTimescaleMicroseconds: 5_000,
        interruptMask: [.pain, .damagingContact, .impact, .muscleOverload],
        tokenCount: 4,
        tokenDimension: 64
      ),
      BrainModuleDescriptor(
        moduleIdentifier: 25,
        clockClass: .workspace,
        periodMicroseconds: 50_000,
        conductionDelayMicroseconds: 2_000,
        intrinsicTimescaleMicroseconds: 100_000,
        tokenCount: 16,
        tokenDimension: 256
      ),
      BrainModuleDescriptor(
        moduleIdentifier: 26,
        clockClass: .emergency,
        periodMicroseconds: 1_000,
        intrinsicTimescaleMicroseconds: 2_000,
        interruptMask: [
          .pain, .damagingContact, .lossOfSupport, .impact,
          .physiologicalCritical, .jointLimit, .muscleOverload, .rescue,
        ],
        tokenCount: 8,
        tokenDimension: 64
      ),
      BrainModuleDescriptor(
        moduleIdentifier: 37,
        clockClass: .cortical,
        periodMicroseconds: 20_000,
        conductionDelayMicroseconds: 2_000,
        intrinsicTimescaleMicroseconds: 20_000,
        interruptMask: [.soundOnset, .visualTransient],
        tokenCount: 16,
        tokenDimension: 128
      ),
      BrainModuleDescriptor(
        moduleIdentifier: 77,
        clockClass: .planning,
        periodMicroseconds: 100_000,
        conductionDelayMicroseconds: 5_000,
        intrinsicTimescaleMicroseconds: 250_000,
        tokenCount: 8,
        tokenDimension: 256
      ),
      BrainModuleDescriptor(
        moduleIdentifier: 83,
        clockClass: .cerebellar,
        periodMicroseconds: 5_000,
        conductionDelayMicroseconds: 1_000,
        intrinsicTimescaleMicroseconds: 10_000,
        interruptMask: [.lossOfSupport, .impact],
        tokenCount: 8,
        tokenDimension: 128
      ),
      BrainModuleDescriptor(
        moduleIdentifier: 90,
        clockClass: .cpg,
        periodMicroseconds: 2_000,
        conductionDelayMicroseconds: 500,
        intrinsicTimescaleMicroseconds: 5_000,
        interruptMask: [.lossOfSupport],
        tokenCount: 4,
        tokenDimension: 64
      ),
      BrainModuleDescriptor(
        moduleIdentifier: 95,
        clockClass: .spinal,
        periodMicroseconds: 1_000,
        conductionDelayMicroseconds: 250,
        intrinsicTimescaleMicroseconds: 5_000,
        interruptMask: [
          .pain, .damagingContact, .lossOfSupport, .impact, .jointLimit,
          .muscleOverload,
        ],
        tokenCount: 8,
        tokenDimension: 64
      ),
    ])
  }
}

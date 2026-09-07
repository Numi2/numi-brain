import Foundation

/// A terminal, accepted neural/action pairing. The native owner records these
/// only AFTER joint publication. Serialized rows are research data, not runtime
/// admission receipts. Target drives retain the teacher's existing protections.
public struct ConnectomeTrainingRow: Codable, Equatable, Sendable {
  public let programFingerprint: UInt64
  public let episodeIdentifier: UInt64
  public let generation: UInt64
  public let controlStep: UInt32
  public let transactionFingerprint: UInt64
  public let timestampMicroseconds: UInt64
  public let executionSHA256: String
  public let motorActionSHA256: String
  public let features: [Float]
  public let normalizedDrives: [Float]

  public init(program: ConnectomeProgram, episodeIdentifier: UInt64, generation: UInt64,
    controlStep: UInt32, transactionFingerprint: UInt64, timestampMicroseconds: UInt64,
    executionSHA256: String, motorActionSHA256: String, features: [Float], normalizedDrives: [Float]) throws {
    programFingerprint = program.fingerprint; self.episodeIdentifier = episodeIdentifier
    self.generation = generation; self.controlStep = controlStep
    self.transactionFingerprint = transactionFingerprint; self.timestampMicroseconds = timestampMicroseconds
    self.executionSHA256 = executionSHA256; self.motorActionSHA256 = motorActionSHA256
    self.features = features; self.normalizedDrives = normalizedDrives
    try validate(program: program)
  }

  public func validate(program: ConnectomeProgram) throws {
    guard program.executionMode == .observeTeacher, programFingerprint == program.fingerprint,
      episodeIdentifier > 0, generation > 0, controlStep > 0, timestampMicroseconds > 0,
      transactionFingerprint > 0, BrainPolicyEvidenceArtifact.isSHA256(executionSHA256),
      BrainPolicyEvidenceArtifact.isSHA256(motorActionSHA256),
      features.count == Int(program.binding.channelCount), normalizedDrives.count == Int(program.decoder.actuatorCount),
      features.allSatisfy({ $0.isFinite && abs($0) <= 1 }),
      normalizedDrives.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
      throw ConnectomeError.invalid("training row lacks exact accepted teacher identity, shape or finite values")
    }
  }
}

/// Content-addressed link to the existing authoritative native capture, not a
/// second simulation transcript or an inferred 'committed' Boolean.
public struct ConnectomeTrainingRun: Codable, Sendable {
  public let version: UInt32
  public let nativeRunSHA256: String
  public let programFingerprint: UInt64
  public let rows: [ConnectomeTrainingRow]

  public init(nativeRunSHA256: String, program: ConnectomeProgram, rows: [ConnectomeTrainingRow]) throws {
    guard BrainPolicyEvidenceArtifact.isSHA256(nativeRunSHA256), !rows.isEmpty, rows.count <= 65_536 else {
      throw ConnectomeError.invalid("empty or oversized native teacher capture")
    }
    for row in rows { try row.validate(program: program) }
    guard Set(rows.map(\.executionSHA256)).count == rows.count,
      Set(rows.map(\.transactionFingerprint)).count == rows.count else {
      throw ConnectomeError.invalid("duplicate native roots in training capture")
    }
    version = 1; self.nativeRunSHA256 = nativeRunSHA256
    programFingerprint = program.fingerprint; self.rows = rows
  }

  /// Reuses the existing transitive capture verifier, then checks that every
  /// neural row names a genuinely accepted terminal root and its exact action.
  /// This is data validation. It does not grant a policy-promotion capability.
  public func verifiedRows(program: ConnectomeProgram, directory: URL) throws -> [ConnectomeTrainingRow] {
    guard version == 1, programFingerprint == program.fingerprint else {
      throw ConnectomeError.invalid("training run version or controller identity mismatch")
    }
    _ = try Self(nativeRunSHA256: nativeRunSHA256, program: program, rows: rows)
    _ = try BrainPolicyNumanXCaptureVerifier.verify(runArtifactSHA256: nativeRunSHA256, artifactDirectory: directory)
    let native = try BrainReachHoldExperiment.read(BrainPolicyNumanXCaptureRunArtifact.self,
      hash: nativeRunSHA256, directory: directory)
    try native.validate()
    guard native.compiledSpeciesTemplateFingerprint == program.decoder.compiledSpeciesFingerprint,
      native.parameterVersionFingerprint == program.binding.parameterVersionFingerprint else {
      throw ConnectomeError.invalid("teacher native run belongs to a different body/publication")
    }
    let references = Dictionary(uniqueKeysWithValues: native.roots.map { ($0.executionSHA256, $0) })
    for row in rows {
      guard let ref = references[row.executionSHA256], ref.controlStep == row.controlStep,
        ref.motorActionArtifactSHA256 == row.motorActionSHA256 else {
        throw ConnectomeError.invalid("teacher row is not part of its retained native run")
      }
      let execution = try BrainReachHoldExperiment.read(BrainPolicyNumanXRootExecution.self,
        hash: row.executionSHA256, directory: directory)
      let action = try BrainReachHoldExperiment.read(BrainPolicyNumanXMotorActionArtifact.self,
        hash: row.motorActionSHA256, directory: directory)
      let sample = try BrainReachHoldExperiment.read(BrainPolicyNumanXRootSampleArtifact.self,
        hash: ref.sampleSHA256, directory: directory)
      try execution.validate(); try action.validate(); try sample.validate()
      guard execution.outcome == .accepted, execution.transactionFingerprint == row.transactionFingerprint,
        action.controlStep == row.controlStep, action.learnedDescendingCommands == row.normalizedDrives,
        UInt32(action.actuatorCommandKind) == program.decoder.commandKind,
        sample.coordinates.episodeIdentifier == row.episodeIdentifier,
        sample.targetTimestampMicroseconds == row.timestampMicroseconds,
        sample.transactionFingerprint == row.transactionFingerprint else {
        throw ConnectomeError.invalid("rejected, mismatched or altered teacher root/action")
      }
      guard let memoryHash = ref.memoryAfterLearningBatchArtifactSHA256 else {
        throw ConnectomeError.invalid("accepted teacher root has no committed generation witness")
      }
      let memory = try BrainReachHoldExperiment.read(BrainPolicyNumanXLearningBatchArtifact.self,
        hash: memoryHash, directory: directory)
      guard memory.sourceGeneration == row.generation else {
        throw ConnectomeError.invalid("neural teacher capture generation mismatch")
      }
    }
    return rows
  }
}

public struct ConnectomeTrainingSplit: Sendable {
  public let training: [ConnectomeTrainingRow]
  public let heldOut: [ConnectomeTrainingRow]
  public init(program: ConnectomeProgram, training: [ConnectomeTrainingRow], heldOut: [ConnectomeTrainingRow]) throws {
    guard !training.isEmpty, !heldOut.isEmpty, training.count <= 65_536, heldOut.count <= 65_536 else {
      throw ConnectomeError.invalid("training requires bounded nonempty training and held-out episodes")
    }
    for row in training + heldOut { try row.validate(program: program) }
    let trainingEpisodes = Set(training.map(\.episodeIdentifier)), heldOutEpisodes = Set(heldOut.map(\.episodeIdentifier))
    let all = training + heldOut
    guard trainingEpisodes.isDisjoint(with: heldOutEpisodes),
      Set(all.map(\.executionSHA256)).count == all.count,
      Set(all.map(\.transactionFingerprint)).count == all.count else {
      throw ConnectomeError.invalid("teacher train/held-out split leaks an episode or repeats a root")
    }
    self.training = training; self.heldOut = heldOut
  }
}

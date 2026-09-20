import Dispatch
import Foundation
import Metal
import NumiBrainCore
import NumiBrainQualification
import NumiBrainMLX
import NumiBrainValidation
@_spi(NumanXInterop) import NumiBrainMetal
import Darwin

/// One experiment frontend; all physical stepping reuses the existing native
/// root runner. Configurations and products are retained, never gate admission.
private struct SettingsInput: Codable { let artifactDirectory: String; let settings: MLXPhysicalMotorCalibration.Settings }
private struct ProtocolInput: Codable { let artifactDirectory: String; let experiment: BrainReachHoldProtocol }
private struct SeedInput: Codable { let artifactDirectory: String; let timestepMicroseconds: UInt32 }
private struct ProbeInput: Codable {
  let artifactDirectory: String; let parentPublicationSHA256: String; let coordinate: Int; let offset: Float
}
private struct WatchdogLifecycleInput: Codable {
  let armPath: String
  let readyPath: String
  let completionPath: String
}
private struct AuthoredMatterWorldInput: Codable, Equatable {
  let packagePath: String
  let humanSourceFingerprint: UInt64
  let worldFingerprint: UInt64
  let sourceJointEqualitiesPath: String?
  let sourceJointEqualitiesFingerprint: UInt64?
  let sourceJointLimitsPath: String?
  let sourceJointLimitsFingerprint: UInt64?
  let preparedInitialStatePath: String?
  let preparedInitialStateFingerprint: UInt64?

  var hasPreparedInitialState: Bool {
    preparedInitialStatePath != nil && preparedInitialStateFingerprint != nil
  }

  func bridgeValue() throws -> MetalNumanXBridgeV1Runtime.AuthoredMatterWorld {
    let equalities: MetalNumanXBridgeV1Runtime.SourceJointEqualities?
    if let path = sourceJointEqualitiesPath,
      let fingerprint = sourceJointEqualitiesFingerprint {
      equalities = try .init(payloadPath: path, fingerprint: fingerprint)
    } else {
      guard sourceJointEqualitiesPath == nil,
        sourceJointEqualitiesFingerprint == nil
      else {
        throw BrainRuntimeError.transaction(
          "authored-world joint equalities require both path and fingerprint"
        )
      }
      equalities = nil
    }
    let limits: MetalNumanXBridgeV1Runtime.SourceJointLimits?
    if let path = sourceJointLimitsPath,
      let fingerprint = sourceJointLimitsFingerprint {
      limits = try .init(payloadPath: path, fingerprint: fingerprint)
    } else {
      guard sourceJointLimitsPath == nil,
        sourceJointLimitsFingerprint == nil
      else {
        throw BrainRuntimeError.transaction(
          "authored-world joint limits require both path and fingerprint"
        )
      }
      limits = nil
    }
    let initialState: MetalNumanXBridgeV1Runtime.PreparedInitialState?
    if let path = preparedInitialStatePath,
      let fingerprint = preparedInitialStateFingerprint {
      initialState = try .init(payloadPath: path, fingerprint: fingerprint)
    } else {
      guard preparedInitialStatePath == nil,
        preparedInitialStateFingerprint == nil
      else {
        throw BrainRuntimeError.transaction(
          "prepared initial state requires both path and fingerprint"
        )
      }
      initialState = nil
    }
    return try .init(
      packagePath: packagePath,
      humanSourceFingerprint: humanSourceFingerprint,
      worldFingerprint: worldFingerprint,
      sourceJointEqualities: equalities,
      sourceJointLimits: limits,
      preparedInitialState: initialState
    )
  }
}
private struct CaptureInput: Codable {
  let artifactDirectory: String; let protocolSHA256: String; let publicationSHA256: String
  let runIdentifier: String; let nativePaths: [String: String]
  let authoredMatterWorld: AuthoredMatterWorldInput?
  let connectomeGraphPath: String?
  let connectomeSpecificationPath: String?
  let affectiveModelConfiguration: AffectiveModelConfiguration?
  let watchdog: WatchdogOwnerFileConfiguration?
  let watchdogLifecycle: WatchdogLifecycleInput?
}
private struct EvaluationInput: Codable { let artifactDirectory: String; let protocolSHA256: String; let runSHA256: String }
private struct CalibrationInput: Codable {
  let artifactDirectory: String; let parentPublicationSHA256: String
  let negativePublicationSHA256: String; let positivePublicationSHA256: String
  let negativeEvaluationSHA256: String; let positiveEvaluationSHA256: String
  let settings: MLXPhysicalMotorCalibration.Settings
}
private struct DecoderSettingsInput: Codable {
  let artifactDirectory: String; let settings: ConnectomeDecoderStudySettings
}
private struct DecoderProbeInput: Codable {
  let artifactDirectory: String; let parentRunSHA256: String; let protocolSHA256: String
  let settings: ConnectomeDecoderStudySettings
}
private struct DecoderCalibrationInput: Codable {
  let artifactDirectory: String; let probePlanSHA256: String
  let negativeEvaluationSHA256: String; let positiveEvaluationSHA256: String
}
private struct DecoderStudyInput: Codable {
  let artifactDirectory: String; let parentRunSHA256: String; let protocolSHA256: String
  let settings: ConnectomeDecoderStudySettings
  let negativeCapture: CaptureInput; let positiveCapture: CaptureInput
}
private struct AffectStudyInput: Codable {
  let artifactDirectory: String
  let protocolSHA256: String
  let enabledCapture: CaptureInput
  let disabledCapture: CaptureInput
}
private struct AffectStudyArtifact: Codable {
  let formatVersion: UInt32
  let promotable: Bool
  let protocolSHA256: String
  let enabledRunSHA256: String
  let disabledRunSHA256: String
  let enabledCaptureConfigurationSHA256: String
  let disabledCaptureConfigurationSHA256: String
  let enabledEvaluationSHA256: String
  let disabledEvaluationSHA256: String
  let enabledAffectConfigurationFingerprint: UInt64
  let disabledAffectConfigurationFingerprint: UInt64
  let enabledBootstrapSampleSHA256: String
  let disabledBootstrapSampleSHA256: String
  let enabledBootstrapSampleSource: BrainPolicyNumanXRootSampleArtifact.Source?
  let disabledBootstrapSampleSource: BrainPolicyNumanXRootSampleArtifact.Source?
  let matchedBootstrapSensorSample: Bool
  let enabledFirstAcceptedNativeAggregateSampleSHA256: String?
  let disabledFirstAcceptedNativeAggregateSampleSHA256: String?
  let matchedPreparedInitialStateFingerprint: Bool
  let matchedNativeRuntimeIdentity: Bool
  let matchedNativeWorldIdentity: Bool
  let hasAcceptedNativeAggregateEvidence: Bool
  let affectConfigurationProvenanceMatchesInputs: Bool
  let behaviorComparisonEligible: Bool
  let enabledBehavior: ReachHoldResult?
  let disabledBehavior: ReachHoldResult?
}
private struct CommandResult: Encodable {
  let promotable = false
  let scope = "native-muscle-control-experiment"
  let configurationSHA256: String
  let artifactSHA256: String
  let kind: String
  var parameterVersionFingerprint: UInt64? = nil
  var affectiveModelConfiguration: AffectiveModelConfiguration? = nil
}
private struct FailureRecord: Encodable {
  let promotable = false
  let configurationSHA256: String
  let protocolSHA256: String
  let completedExecutionSHA256: [String]
  let error: String
}
private func read<T: Decodable>(_ type: T.Type, bytes: Data) throws -> T { try JSONDecoder().decode(type, from: bytes) }
private func emit<T: Encodable>(_ value: T) throws {
  var bytes = try QualificationFileDirectory.canonicalJSON(value); bytes.append(10)
  FileHandle.standardOutput.write(bytes)
}
private func directory(_ path: String) throws -> URL {
  let url = URL(fileURLWithPath: path, isDirectory: true)
  _ = try QualificationFileDirectory(url: url)
  return url
}
private func publication(_ sha: String, _ directory: URL) throws -> BrainMotorStudyPublication {
  let value = try BrainReachHoldExperiment.read(BrainMotorStudyPublication.self, hash: sha, directory: directory)
  try value.validate(); return value
}
private func capture(_ input: CaptureInput, configSHA: String, directory: URL, connectomeResearch: Bool = false) throws -> String {
  let protocolValue = try BrainReachHoldExperiment.read(BrainReachHoldProtocol.self, hash: input.protocolSHA256, directory: directory)
  try protocolValue.validate()
  let weights = try publication(input.publicationSHA256, directory)
  let sharedNativePathKeys: Set<String> = [
    "library", "rigid", "muscle", "contacts", "visualPack", "visionProfile",
    "metalRoboMetallib", "matterMetallib",
  ]
  let expectedNativePathKeys = input.authoredMatterWorld == nil
    ? sharedNativePathKeys.union(["material"]) : sharedNativePathKeys
  let nativePathsAreValid = Set(input.nativePaths.keys) == expectedNativePathKeys
    && input.nativePaths.values.allSatisfy({ !$0.isEmpty })
  guard weights.version.fingerprint == protocolValue.parameterVersionFingerprint,
    !input.runIdentifier.isEmpty, input.runIdentifier.utf8.count <= 256,
    nativePathsAreValid,
    (input.watchdog == nil) == (input.watchdogLifecycle == nil),
    let device = MTLCreateSystemDefaultDevice() else {
    throw BrainRuntimeError.transaction("experiment configuration, model identity, watchdog lifecycle or Metal device is invalid")
  }
  let connectome: MetalConnectomeConfiguration?
  if connectomeResearch {
    guard let graphPath = input.connectomeGraphPath, let specPath = input.connectomeSpecificationPath else {
      throw ConnectomeError.invalid("capture-connectome requires graph and specification paths")
    }
    connectome = try MetalConnectomeConfiguration(
      graph: ConnectomeGraph(contentsOf: URL(fileURLWithPath: graphPath)),
      specification: ConnectomeControllerSpec.read(from: URL(fileURLWithPath: specPath)))
  } else {
    guard input.connectomeGraphPath == nil, input.connectomeSpecificationPath == nil else {
      throw ConnectomeError.invalid("use explicit capture-connectome research command for a changed controller")
    }
    connectome = nil
  }
  var roots: [MetalNumanXGateCRootRunner.RootResult] = []
  do {
    let watchdog = try input.watchdog.map { try WatchdogOwnerFileSession(configuration: $0) }
    let lifecycle: WatchdogOwnerLifecycle? = try {
      guard let watchdog, let life = input.watchdogLifecycle else { return nil }
      let paths = [life.armPath, life.readyPath, life.completionPath]
      guard paths.allSatisfy({ $0.hasPrefix("/") }) else {
        throw BrainRuntimeError.transaction("watchdog lifecycle paths must be absolute")
      }
      let value = try WatchdogOwnerLifecycle(owner: watchdog,
        armURL: URL(fileURLWithPath: life.armPath), readyURL: URL(fileURLWithPath: life.readyPath),
        completionURL: URL(fileURLWithPath: life.completionPath),
        nowNanoseconds: DispatchTime.now().uptimeNanoseconds)
      try value.activate(nowNanoseconds: DispatchTime.now().uptimeNanoseconds)
      return value
    }()
    let paths = input.nativePaths
    let authoredMatterWorld = try input.authoredMatterWorld?.bridgeValue()
    let runner = try MetalNumanXGateCRootRunner(libraryPath: paths["library"]!,
      bridgeConfiguration: MetalNumanXBridgeV1Runtime.Configuration(rigidPayloadPath: paths["rigid"]!,
        musclePayloadPath: paths["muscle"]!, supportContactPayloadPath: paths["contacts"]!,
        visualPackPath: paths["visualPack"]!, visionProfilePath: paths["visionProfile"]!,
        metalRoboMetallibPath: paths["metalRoboMetallib"]!, matterMetallibPath: paths["matterMetallib"]!,
        matterMaterialPath: paths["material"] ?? "", timestepMicroseconds: UInt64(protocolValue.timestepMicroseconds), transactionSlotCount: 2,
        authoredMatterWorld: authoredMatterWorld),
      publication: weights.unverifiedPublication, artifactDirectory: directory,
      episodeIdentifier: protocolValue.episodeIdentifier, randomSeed: protocolValue.randomSeed,
      enableProductionUncertaintyGate: !connectomeResearch, connectome: connectome,
      affectiveModelConfiguration: input.affectiveModelConfiguration ?? .reference,
      device: device)
    guard runner.nativeInfo.modelSourceFingerprint == protocolValue.expectedNativeModelFingerprint else {
      throw BrainRuntimeError.transaction("native model differs from frozen experiment")
    }
    let coordinates = try BrainPolicyNumanXDatasetCoordinates(datasetSourceIdentifier: connectomeResearch ? ConnectomeCaptureIdentity.datasetIdentifier : "numibrain.reach-hold.v1",
      datasetSourceRevision: input.protocolSHA256, episodeIdentifier: protocolValue.episodeIdentifier,
      taskFingerprint: protocolValue.taskFingerprint, sceneFingerprint: protocolValue.sceneFingerprint,
      objectFingerprint: protocolValue.objectFingerprint, embodimentFingerprint: protocolValue.embodimentFingerprint)
    let rootCount = try protocolValue.captureRootCount
    roots.reserveCapacity(Int(rootCount))
    for step in UInt32(1)...rootCount {
      let goalProvider: (BrainTimestamp, BrainTimestamp) throws -> ActiveGoal = { committed, target in
        try protocolValue.goal(controlStep: step, committed: committed, target: target)
      }
      if let watchdog {
        let supervised = try runner.runSupervisedRoot(watchdog: watchdog, controlStep: step,
          coordinates: coordinates, externalGoalProvider: goalProvider)
        roots.append(supervised.root)
        if let failure = supervised.reportingFailure {
          throw BrainRuntimeError.transaction("watchdog reporting failed after retained terminal root: " + failure)
        }
        guard !watchdog.admissionClosed else {
          throw BrainRuntimeError.transaction("watchdog stopped capture after terminal root settlement")
        }
      } else {
        roots.append(try runner.runRoot(controlStep: step, coordinates: coordinates, externalGoalProvider: goalProvider))
      }
    }
    if let watchdog {
      try watchdog.poll(nowNanoseconds: DispatchTime.now().uptimeNanoseconds)
      guard !watchdog.admissionClosed else {
        throw BrainRuntimeError.transaction("watchdog stopped capture before final artifact publication")
      }
    }
    let runHash = try runner.writeCaptureRunArtifact(runIdentifier: input.runIdentifier,
      sourceRevision: protocolValue.sourceRevision, roots: roots,
      learningBatch: runner.captureLearningBatch())
    if let lifecycle {
      _ = try lifecycle.complete(terminalEvidenceArtifactSHA256: runHash,
        nowNanoseconds: DispatchTime.now().uptimeNanoseconds)
    }
    return runHash
  } catch {
    let failure = FailureRecord(configurationSHA256: configSHA, protocolSHA256: input.protocolSHA256,
      completedExecutionSHA256: roots.map(\.executionArtifactSHA256), error: String(describing: error))
    let hash = try BrainReachHoldExperiment.retain(failure, directory: directory)
    FileHandle.standardError.write(Data("experiment failure artifact: \(hash)\n".utf8))
    throw error
  }
}

/// Two fresh native runs, then a verified decoder-only proposal. This bounded
/// orchestrator does not accept raw losses, replace physics, or publish a policy.
private func decoderStudy(_ input: DecoderStudyInput, directory: URL) throws -> String {
  let negative = input.negativeCapture, positive = input.positiveCapture
  guard negative.artifactDirectory == input.artifactDirectory,
    positive.artifactDirectory == input.artifactDirectory,
    negative.protocolSHA256 == input.protocolSHA256, positive.protocolSHA256 == input.protocolSHA256,
    negative.publicationSHA256 == positive.publicationSHA256,
    negative.runIdentifier != positive.runIdentifier,
    negative.connectomeSpecificationPath == nil, positive.connectomeSpecificationPath == nil else {
    throw ConnectomeError.invalid("paired decoder study requires distinct runs, one frozen protocol/publication and plan-owned specifications")
  }
  let plan = try MLXConnectomeDecoderCalibration.prepare(parentRunSHA256: input.parentRunSHA256,
    protocolSHA256: input.protocolSHA256, settings: input.settings, directory: directory)
  let planHash = try BrainReachHoldExperiment.retain(plan, directory: directory)
  func evaluate(_ base: CaptureInput, specificationSHA256: String) throws -> String {
    let specURL = try BrainPolicyEvidenceArtifact.url(forSHA256: specificationSHA256, in: directory)
    let configured = CaptureInput(artifactDirectory: base.artifactDirectory,
      protocolSHA256: base.protocolSHA256, publicationSHA256: base.publicationSHA256,
      runIdentifier: base.runIdentifier, nativePaths: base.nativePaths,
      authoredMatterWorld: base.authoredMatterWorld,
      connectomeGraphPath: base.connectomeGraphPath, connectomeSpecificationPath: specURL.path,
      affectiveModelConfiguration: base.affectiveModelConfiguration,
      watchdog: base.watchdog, watchdogLifecycle: base.watchdogLifecycle)
    let configHash = try BrainReachHoldExperiment.retain(configured, directory: directory)
    let runHash = try capture(configured, configSHA: configHash, directory: directory, connectomeResearch: true)
    return try BrainReachHoldExperiment.evaluate(protocolSHA256: input.protocolSHA256,
      runSHA256: runHash, directory: directory, allowingResearchConnectome: true).artifactSHA256
  }
  let n = try evaluate(negative, specificationSHA256: plan.negativeSpecificationSHA256)
  let p = try evaluate(positive, specificationSHA256: plan.positiveSpecificationSHA256)
  let proposal = try MLXConnectomeDecoderCalibration.update(planSHA256: planHash,
    negativeEvaluationSHA256: n, positiveEvaluationSHA256: p, directory: directory)
  return try BrainReachHoldExperiment.retain(proposal, directory: directory)
}

/// Runs two fresh native captures from one frozen experiment, changing only
/// whether derived affect is enabled. The synthetic bootstrap's sensor
/// channels must match before the pair is considered behavior-comparable.
private func affectStudy(_ input: AffectStudyInput, directory: URL) throws -> String {
  let enabled = input.enabledCapture
  let disabled = input.disabledCapture
  guard enabled.artifactDirectory == input.artifactDirectory,
    disabled.artifactDirectory == input.artifactDirectory,
    enabled.protocolSHA256 == input.protocolSHA256,
    disabled.protocolSHA256 == input.protocolSHA256,
    enabled.publicationSHA256 == disabled.publicationSHA256,
    enabled.nativePaths == disabled.nativePaths,
    enabled.authoredMatterWorld == disabled.authoredMatterWorld,
    enabled.authoredMatterWorld?.hasPreparedInitialState == true,
    enabled.connectomeGraphPath == nil, disabled.connectomeGraphPath == nil,
    enabled.connectomeSpecificationPath == nil,
    disabled.connectomeSpecificationPath == nil,
    enabled.watchdog == nil, disabled.watchdog == nil,
    enabled.watchdogLifecycle == nil, disabled.watchdogLifecycle == nil,
    !enabled.runIdentifier.isEmpty, !disabled.runIdentifier.isEmpty,
    enabled.runIdentifier != disabled.runIdentifier,
    let enabledConfiguration = enabled.affectiveModelConfiguration,
    let disabledConfiguration = disabled.affectiveModelConfiguration,
    enabledConfiguration.isEnabled, !disabledConfiguration.isEnabled,
    try AffectiveModelConfiguration(
      isEnabled: true,
      painDecayMicroseconds: disabledConfiguration.painDecayMicroseconds,
      pleasureDecayMicroseconds: disabledConfiguration.pleasureDecayMicroseconds,
      reliefDecayMicroseconds: disabledConfiguration.reliefDecayMicroseconds,
      maximumEvidenceAgeMicroseconds: disabledConfiguration.maximumEvidenceAgeMicroseconds,
      recoveryGain: disabledConfiguration.recoveryGain,
      reliefGain: disabledConfiguration.reliefGain,
      sourceWeights: disabledConfiguration.sourceWeights
    ) == enabledConfiguration
  else {
    throw BrainRuntimeError.transaction(
      "affect study requires one frozen protocol, publication and native asset set; only affect mode may differ"
    )
  }

  let enabledConfigSHA = try BrainReachHoldExperiment.retain(enabled, directory: directory)
  let enabledRunSHA = try capture(enabled, configSHA: enabledConfigSHA, directory: directory)
  let disabledConfigSHA = try BrainReachHoldExperiment.retain(disabled, directory: directory)
  let disabledRunSHA = try capture(disabled, configSHA: disabledConfigSHA, directory: directory)
  let enabledEvaluation = try BrainReachHoldExperiment.evaluate(
    protocolSHA256: input.protocolSHA256,
    runSHA256: enabledRunSHA,
    directory: directory
  )
  let disabledEvaluation = try BrainReachHoldExperiment.evaluate(
    protocolSHA256: input.protocolSHA256,
    runSHA256: disabledRunSHA,
    directory: directory
  )
  let enabledRun = try BrainReachHoldExperiment.read(
    BrainPolicyNumanXCaptureRunArtifact.self,
    hash: enabledRunSHA,
    directory: directory
  )
  let disabledRun = try BrainReachHoldExperiment.read(
    BrainPolicyNumanXCaptureRunArtifact.self,
    hash: disabledRunSHA,
    directory: directory
  )
  func samples(
    in run: BrainPolicyNumanXCaptureRunArtifact
  ) throws -> [BrainPolicyNumanXRootSampleArtifact] {
    try run.roots.map { root in
      let sample = try BrainReachHoldExperiment.read(
        BrainPolicyNumanXRootSampleArtifact.self,
        hash: root.sampleSHA256,
        directory: directory
      )
      guard sample.controlStep == root.controlStep else {
        throw BrainRuntimeError.transaction(
          "affect study root sample identity does not match its run"
        )
      }
      return sample
    }
  }
  let enabledSamples = try samples(in: enabledRun)
  let disabledSamples = try samples(in: disabledRun)
  guard let enabledBootstrapSample = enabledRun.roots.first?.sampleSHA256,
    let disabledBootstrapSample = disabledRun.roots.first?.sampleSHA256
  else {
    throw BrainRuntimeError.transaction("affect study captures have no initial sensor sample")
  }
  let matchedRuntime = enabledRun.nativeModelSourceFingerprint
      == disabledRun.nativeModelSourceFingerprint
    && enabledRun.deviceRegistryID == disabledRun.deviceRegistryID
    && enabledRun.acceptedStateProofProgramFingerprint
      == disabledRun.acceptedStateProofProgramFingerprint
    && enabledRun.compiledSpeciesTemplateFingerprint
      == disabledRun.compiledSpeciesTemplateFingerprint
    && enabledRun.parameterVersionFingerprint == disabledRun.parameterVersionFingerprint
    && enabledRun.timestepMicroseconds == disabledRun.timestepMicroseconds
    && enabledRun.roots.count == disabledRun.roots.count
  let matchedWorld = enabledRun.nativeWorldIdentity != nil
    && enabledRun.nativeWorldIdentity == disabledRun.nativeWorldIdentity
  let enabledInitialStateFingerprint = enabledRun.nativeWorldIdentity?
    .preparedInitialStateFingerprint
  let disabledInitialStateFingerprint = disabledRun.nativeWorldIdentity?
    .preparedInitialStateFingerprint
  let matchedInitialState = enabledRun.nativeWorldIdentity?.authoredPackage == true
    && enabledInitialStateFingerprint != nil
    && enabledInitialStateFingerprint == disabledInitialStateFingerprint
    && enabledInitialStateFingerprint
      == enabled.authoredMatterWorld?.preparedInitialStateFingerprint
  let affectProvenanceMatches = enabledRun.affectiveModelConfiguration
      == enabledConfiguration
    && disabledRun.affectiveModelConfiguration == disabledConfiguration
  let enabledBootstrapSource = enabledSamples.first?.source
  let disabledBootstrapSource = disabledSamples.first?.source
  let matchedBootstrapSample = enabledSamples.first?.channels
    == disabledSamples.first?.channels
  let enabledFirstNativeAggregate = enabledRun.roots.enumerated().first {
    enabledSamples[$0.offset].source == .acceptedNativeAggregate
  }?.element.sampleSHA256
  let disabledFirstNativeAggregate = disabledRun.roots.enumerated().first {
    disabledSamples[$0.offset].source == .acceptedNativeAggregate
  }?.element.sampleSHA256
  let hasAcceptedNativeAggregate = enabledFirstNativeAggregate != nil
    && disabledFirstNativeAggregate != nil
  let matchedBootstrapProvenance = enabledBootstrapSource == .syntheticBootstrap
    && disabledBootstrapSource == .syntheticBootstrap
  let behaviorComparisonEligible = matchedRuntime && matchedWorld
    && matchedInitialState && affectProvenanceMatches
    && matchedBootstrapProvenance && matchedBootstrapSample
    && hasAcceptedNativeAggregate
  let artifact = AffectStudyArtifact(
    formatVersion: 1,
    promotable: false,
    protocolSHA256: input.protocolSHA256,
    enabledRunSHA256: enabledRunSHA,
    disabledRunSHA256: disabledRunSHA,
    enabledCaptureConfigurationSHA256: enabledConfigSHA,
    disabledCaptureConfigurationSHA256: disabledConfigSHA,
    enabledEvaluationSHA256: enabledEvaluation.artifactSHA256,
    disabledEvaluationSHA256: disabledEvaluation.artifactSHA256,
    enabledAffectConfigurationFingerprint: enabledConfiguration.fingerprint,
    disabledAffectConfigurationFingerprint: disabledConfiguration.fingerprint,
    enabledBootstrapSampleSHA256: enabledBootstrapSample,
    disabledBootstrapSampleSHA256: disabledBootstrapSample,
    enabledBootstrapSampleSource: enabledBootstrapSource,
    disabledBootstrapSampleSource: disabledBootstrapSource,
    matchedBootstrapSensorSample: matchedBootstrapSample,
    enabledFirstAcceptedNativeAggregateSampleSHA256:
      enabledFirstNativeAggregate,
    disabledFirstAcceptedNativeAggregateSampleSHA256:
      disabledFirstNativeAggregate,
    matchedPreparedInitialStateFingerprint: matchedInitialState,
    matchedNativeRuntimeIdentity: matchedRuntime,
    matchedNativeWorldIdentity: matchedWorld,
    hasAcceptedNativeAggregateEvidence: hasAcceptedNativeAggregate,
    affectConfigurationProvenanceMatchesInputs: affectProvenanceMatches,
    behaviorComparisonEligible: behaviorComparisonEligible,
    enabledBehavior: enabledEvaluation.artifact.result,
    disabledBehavior: disabledEvaluation.artifact.result
  )
  return try BrainReachHoldExperiment.retain(artifact, directory: directory)
}

let args = Array(CommandLine.arguments.dropFirst())
do {
  guard args.count == 3, args[1] == "--config",
    ["seed", "freeze-settings", "freeze-protocol", "probe", "capture", "capture-connectome", "evaluate", "calibrate",
     "freeze-connectome-settings", "probe-connectome", "evaluate-connectome", "calibrate-connectome", "study-connectome", "study-affect"].contains(args[0]) else {
    print("numi-brain-experiment COMMAND --config FILE\nLegacy: seed|freeze-settings|freeze-protocol|probe|capture|evaluate|calibrate\nConnectome: capture-connectome|freeze-connectome-settings|probe-connectome|evaluate-connectome|calibrate-connectome|study-connectome\nAffect: study-affect (fresh enabled/disabled captures with matched prepared state)\nResearch-only; see docs/CONNECTOME_DECODER_LEARNING.md and docs/AFFECTIVE_STATE.md.")
    exit(64)
  }
  let bytes = try QualificationFileDirectory.readFile(URL(fileURLWithPath: args[2]), maximumBytes: 1_048_576)
  let result: CommandResult
  switch args[0] {
  case "freeze-settings":
    let input = try read(SettingsInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    try input.settings.validate()
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    result = CommandResult(configurationSHA256: configHash,
      artifactSHA256: try BrainReachHoldExperiment.retain(input.settings, directory: store), kind: "predeclared-calibration-settings")
  case "freeze-protocol":
    let input = try read(ProtocolInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    try input.experiment.validate()
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    result = CommandResult(configurationSHA256: configHash,
      artifactSHA256: try BrainReachHoldExperiment.retain(input.experiment, directory: store), kind: "predeclared-physical-task",
      parameterVersionFingerprint: input.experiment.parameterVersionFingerprint)
  case "seed":
    let input = try read(SeedInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    guard input.timestepMicroseconds > 0 else { throw BrainRuntimeError.transaction("invalid seed timestep") }
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    let compiled = try NumanXFullBodyTransportTemplate.compile(latencyMicroseconds: input.timestepMicroseconds)
    let seed = try BrainParameterPublication.developmentalSeedV1(species: compiled.species, tissueParameters: .corticalSheetV0)
    let artifact = try BrainMotorStudyPublication(publication: seed)
    let hash = try BrainReachHoldExperiment.retain(artifact, directory: store)
    result = CommandResult(configurationSHA256: configHash, artifactSHA256: hash, kind: "untrained-publication", parameterVersionFingerprint: seed.version.fingerprint)
  case "probe":
    let input = try read(ProbeInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    let probe = try MLXPhysicalMotorCalibration.probe(parent: publication(input.parentPublicationSHA256, store),
      coordinate: input.coordinate, offset: input.offset)
    result = CommandResult(configurationSHA256: configHash,
      artifactSHA256: try BrainReachHoldExperiment.retain(probe, directory: store), kind: "unverified-gain-probe", parameterVersionFingerprint: probe.version.fingerprint)
  case "capture", "capture-connectome":
    let input = try read(CaptureInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    result = CommandResult(configurationSHA256: configHash,
      artifactSHA256: try capture(input, configSHA: configHash, directory: store,
        connectomeResearch: args[0] == "capture-connectome"),
      kind: args[0] == "capture-connectome" ? "unqualified-connectome-native-run" : "retained-native-run",
      affectiveModelConfiguration: input.affectiveModelConfiguration ?? .reference)
  case "evaluate", "evaluate-connectome":
    let input = try read(EvaluationInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    let evaluation = try BrainReachHoldExperiment.evaluate(protocolSHA256: input.protocolSHA256, runSHA256: input.runSHA256,
      directory: store, allowingResearchConnectome: args[0] == "evaluate-connectome")
    guard args[0] != "evaluate-connectome" || evaluation.connectome != nil else {
      throw ConnectomeError.invalid("evaluate-connectome requires exact decoder capture provenance")
    }
    result = CommandResult(configurationSHA256: configHash, artifactSHA256: evaluation.artifactSHA256, kind: "physical-task-evaluation")
    try emit(result)
    exit(evaluation.artifact.result?.succeeds == true ? 0 : 1)
  case "calibrate":
    let input = try read(CalibrationInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    let negative = try BrainReachHoldExperiment.verify(evaluationSHA256: input.negativeEvaluationSHA256, directory: store)
    let positive = try BrainReachHoldExperiment.verify(evaluationSHA256: input.positiveEvaluationSHA256, directory: store)
    let candidate = try MLXPhysicalMotorCalibration.update(parent: publication(input.parentPublicationSHA256, store),
      negative: publication(input.negativePublicationSHA256, store), positive: publication(input.positivePublicationSHA256, store),
      negativeEvaluation: negative, positiveEvaluation: positive, settings: input.settings)
    result = CommandResult(configurationSHA256: configHash,
      artifactSHA256: try BrainReachHoldExperiment.retain(candidate, directory: store), kind: "unevaluated-physical-loss-proposal", parameterVersionFingerprint: candidate.version.fingerprint)
  case "freeze-connectome-settings":
    let input = try read(DecoderSettingsInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    try input.settings.validate()
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    result = CommandResult(configurationSHA256: configHash,
      artifactSHA256: try BrainReachHoldExperiment.retain(input.settings, directory: store), kind: "predeclared-connectome-decoder-settings")
  case "probe-connectome":
    let input = try read(DecoderProbeInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    let plan = try MLXConnectomeDecoderCalibration.prepare(parentRunSHA256: input.parentRunSHA256,
      protocolSHA256: input.protocolSHA256, settings: input.settings, directory: store)
    result = CommandResult(configurationSHA256: configHash,
      artifactSHA256: try BrainReachHoldExperiment.retain(plan, directory: store), kind: "unevaluated-connectome-decoder-probes")
  case "calibrate-connectome":
    let input = try read(DecoderCalibrationInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    let proposal = try MLXConnectomeDecoderCalibration.update(planSHA256: input.probePlanSHA256,
      negativeEvaluationSHA256: input.negativeEvaluationSHA256,
      positiveEvaluationSHA256: input.positiveEvaluationSHA256, directory: store)
    result = CommandResult(configurationSHA256: configHash,
      artifactSHA256: try BrainReachHoldExperiment.retain(proposal, directory: store), kind: "unevaluated-connectome-decoder-proposal")
  case "study-connectome":
    let input = try read(DecoderStudyInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    result = CommandResult(configurationSHA256: configHash,
      artifactSHA256: try decoderStudy(input, directory: store), kind: "unevaluated-connectome-decoder-proposal")
  case "study-affect":
    let input = try read(AffectStudyInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    result = CommandResult(configurationSHA256: configHash,
      artifactSHA256: try affectStudy(input, directory: store), kind: "native-affect-paired-behavior-study")
  default:
    throw ConnectomeError.invalid("unsupported experiment command")
  }
  let storePath: String = try {
    let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
    guard let path = object?["artifactDirectory"] as? String else { throw BrainRuntimeError.transaction("missing artifact directory") }
    return path
  }()
  _ = try BrainReachHoldExperiment.retain(result, directory: directory(storePath))
  try emit(result)
} catch { FileHandle.standardError.write(Data("numi-brain-experiment: \(error)\n".utf8)); exit(65) }

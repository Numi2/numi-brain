import Foundation
import Metal
import NumiBrainCore
import NumiBrainQualification
import NumiBrainMLX
@_spi(NumanXInterop) import NumiBrainMetal
import Darwin

/// One experiment frontend; all physical stepping reuses the existing native
/// root runner. Configurations and products are retained, never gate admission.
private struct SeedInput: Codable { let artifactDirectory: String; let timestepMicroseconds: UInt32 }
private struct ProbeInput: Codable {
  let artifactDirectory: String; let parentPublicationSHA256: String; let coordinate: Int; let offset: Float
}
private struct CaptureInput: Codable {
  let artifactDirectory: String; let protocolSHA256: String; let publicationSHA256: String
  let runIdentifier: String; let nativePaths: [String: String]
}
private struct EvaluationInput: Codable { let artifactDirectory: String; let protocolSHA256: String; let runSHA256: String }
private struct CalibrationInput: Codable {
  let artifactDirectory: String; let parentPublicationSHA256: String
  let negativePublicationSHA256: String; let positivePublicationSHA256: String
  let negativeEvaluationSHA256: String; let positiveEvaluationSHA256: String
  let settings: MLXPhysicalMotorCalibration.Settings
}
private struct CommandResult: Encodable {
  let promotable = false
  let scope = "native-muscle-control-experiment"
  let configurationSHA256: String
  let artifactSHA256: String
  let kind: String
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
private func capture(_ input: CaptureInput, configSHA: String, directory: URL) throws -> String {
  let protocolValue = try BrainReachHoldExperiment.read(BrainReachHoldProtocol.self, hash: input.protocolSHA256, directory: directory)
  try protocolValue.validate()
  let weights = try publication(input.publicationSHA256, directory)
  guard weights.version.fingerprint == protocolValue.parameterVersionFingerprint,
    !input.runIdentifier.isEmpty, input.runIdentifier.utf8.count <= 256,
    Set(input.nativePaths.keys) == Set(["library", "rigid", "muscle", "contacts", "visualPack", "visionProfile", "metalRoboMetallib", "matterMetallib", "material"]),
    input.nativePaths.values.allSatisfy({ !$0.isEmpty }), let device = MTLCreateSystemDefaultDevice() else {
    throw BrainRuntimeError.transaction("experiment configuration, model identity or Metal device is invalid")
  }
  let paths = input.nativePaths
  let runner = try MetalNumanXGateCRootRunner(libraryPath: paths["library"]!,
    bridgeConfiguration: MetalNumanXBridgeV1Runtime.Configuration(rigidPayloadPath: paths["rigid"]!,
      musclePayloadPath: paths["muscle"]!, supportContactPayloadPath: paths["contacts"]!,
      visualPackPath: paths["visualPack"]!, visionProfilePath: paths["visionProfile"]!,
      metalRoboMetallibPath: paths["metalRoboMetallib"]!, matterMetallibPath: paths["matterMetallib"]!,
      matterMaterialPath: paths["material"]!, timestepMicroseconds: UInt64(protocolValue.timestepMicroseconds), transactionSlotCount: 2),
    publication: weights.unverifiedPublication, artifactDirectory: directory,
    episodeIdentifier: protocolValue.episodeIdentifier, randomSeed: protocolValue.randomSeed,
    enableProductionUncertaintyGate: true, device: device)
  guard runner.nativeInfo.modelSourceFingerprint == protocolValue.expectedNativeModelFingerprint else {
    throw BrainRuntimeError.transaction("native model differs from frozen experiment")
  }
  let coordinates = try BrainPolicyNumanXDatasetCoordinates(datasetSourceIdentifier: "numibrain.reach-hold.v1",
    datasetSourceRevision: input.protocolSHA256, episodeIdentifier: protocolValue.episodeIdentifier,
    taskFingerprint: protocolValue.taskFingerprint, sceneFingerprint: protocolValue.sceneFingerprint,
    objectFingerprint: protocolValue.objectFingerprint, embodimentFingerprint: protocolValue.embodimentFingerprint)
  var roots: [MetalNumanXGateCRootRunner.RootResult] = []
  let rootCount = try protocolValue.captureRootCount
  roots.reserveCapacity(Int(rootCount))
  do {
    for step in UInt32(1)...rootCount {
      let root = try runner.runRoot(controlStep: step, coordinates: coordinates, externalGoalProvider: { committed, target in
        try protocolValue.goal(controlStep: step, committed: committed, target: target)
      })
      roots.append(root)
    }
    return try runner.writeCaptureRunArtifact(runIdentifier: input.runIdentifier, sourceRevision: protocolValue.sourceRevision,
      roots: roots, learningBatch: runner.captureLearningBatch())
  } catch {
    let failure = FailureRecord(configurationSHA256: configSHA, protocolSHA256: input.protocolSHA256,
      completedExecutionSHA256: roots.map(\.executionArtifactSHA256), error: String(describing: error))
    let hash = try BrainReachHoldExperiment.retain(failure, directory: directory)
    FileHandle.standardError.write(Data("experiment failure artifact: \(hash)\n".utf8))
    throw error
  }
}

let args = Array(CommandLine.arguments.dropFirst())
do {
  guard args.count == 3, args[1] == "--config",
    ["seed", "probe", "capture", "evaluate", "calibrate"].contains(args[0]) else {
    print("numi-brain-experiment seed|probe|capture|evaluate|calibrate --config FILE\nExplicit research-only configurations; see docs/CREDIBLE_ROUTE_PROGRESS.md.")
    exit(64)
  }
  let bytes = try QualificationFileDirectory.readFile(URL(fileURLWithPath: args[2]), maximumBytes: 1_048_576)
  let result: CommandResult
  switch args[0] {
  case "seed":
    let input = try read(SeedInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    guard input.timestepMicroseconds > 0 else { throw BrainRuntimeError.transaction("invalid seed timestep") }
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    let compiled = try NumanXFullBodyTransportTemplate.compile(latencyMicroseconds: input.timestepMicroseconds)
    let seed = try BrainParameterPublication.developmentalSeedV1(species: compiled.species, tissueParameters: .corticalSheetV0)
    let artifact = try BrainMotorStudyPublication(publication: seed)
    let hash = try BrainReachHoldExperiment.retain(artifact, directory: store)
    result = CommandResult(configurationSHA256: configHash, artifactSHA256: hash, kind: "untrained-publication")
  case "probe":
    let input = try read(ProbeInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    let probe = try MLXPhysicalMotorCalibration.probe(parent: publication(input.parentPublicationSHA256, store),
      coordinate: input.coordinate, offset: input.offset)
    result = CommandResult(configurationSHA256: configHash,
      artifactSHA256: try BrainReachHoldExperiment.retain(probe, directory: store), kind: "unverified-gain-probe")
  case "capture":
    let input = try read(CaptureInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    result = CommandResult(configurationSHA256: configHash,
      artifactSHA256: try capture(input, configSHA: configHash, directory: store), kind: "retained-native-run")
  case "evaluate":
    let input = try read(EvaluationInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    let evaluation = try BrainReachHoldExperiment.evaluate(protocolSHA256: input.protocolSHA256, runSHA256: input.runSHA256, directory: store)
    result = CommandResult(configurationSHA256: configHash, artifactSHA256: evaluation.artifactSHA256, kind: "physical-task-evaluation")
    try emit(result)
    exit(evaluation.artifact.result?.succeeds == true ? 0 : 1)
  default:
    let input = try read(CalibrationInput.self, bytes: bytes), store = try directory(input.artifactDirectory)
    let configHash = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
    let negative = try BrainReachHoldExperiment.verify(evaluationSHA256: input.negativeEvaluationSHA256, directory: store)
    let positive = try BrainReachHoldExperiment.verify(evaluationSHA256: input.positiveEvaluationSHA256, directory: store)
    let candidate = try MLXPhysicalMotorCalibration.update(parent: publication(input.parentPublicationSHA256, store),
      negative: publication(input.negativePublicationSHA256, store), positive: publication(input.positivePublicationSHA256, store),
      negativeEvaluation: negative, positiveEvaluation: positive, settings: input.settings)
    result = CommandResult(configurationSHA256: configHash,
      artifactSHA256: try BrainReachHoldExperiment.retain(candidate, directory: store), kind: "unevaluated-physical-loss-proposal")
  }
  let storePath: String = try {
    let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
    guard let path = object?["artifactDirectory"] as? String else { throw BrainRuntimeError.transaction("missing artifact directory") }
    return path
  }()
  _ = try BrainReachHoldExperiment.retain(result, directory: directory(storePath))
  try emit(result)
} catch { FileHandle.standardError.write(Data("numi-brain-experiment: \(error)\n".utf8)); exit(65) }

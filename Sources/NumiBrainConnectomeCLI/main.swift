import Foundation
import NumiBrainCore
import NumiBrainMLX

private struct Context: Decodable {
  let artifactDirectory: String
  let graphPath: String
  let graphSHA256: String
  let compiledSpeciesSHA256: String
  let publicationSHA256: String
}
private struct PrepareInput: Decodable {
  let context: Context
  let channelCount: UInt32
  let nominalStepMicroseconds: UInt32
  let integrationStepMicroseconds: UInt32
  let maximumSubsteps: Int
  let maximumDriveChangePerSecond: Float
  let receptors: [ConnectomeReceptorProjection]
  let descending: [ConnectomeDescendingProjection]
}
private struct LearnInput: Decodable {
  let context: Context
  let teacherLaunchSHA256: String
  let trainingRunSHA256: [String]
  let heldOutRunSHA256: [String]
  let settings: MLXConnectomeDecoderLearner.Settings
}
private struct ValidateInput: Decodable { let context: Context; let launchSHA256: String }
private struct Result: Encodable {
  let promotable = false
  let kind: String
  let artifactSHA256: String
  let launchSHA256: String?
}

private func load(_ context: Context) throws -> (URL, ConnectomeGraph, CompiledSpeciesTemplate, BrainMotorStudyPublication) {
  guard context.artifactDirectory.hasPrefix("/"), context.graphPath.hasPrefix("/"),
    BrainPolicyEvidenceArtifact.isSHA256(context.graphSHA256) else {
    throw ConnectomeError.invalid("absolute paths and pinned graph SHA-256 required")
  }
  let store = URL(fileURLWithPath: context.artifactDirectory, isDirectory: true)
  let graph = try ConnectomeGraph(contentsOf: URL(fileURLWithPath: context.graphPath))
  guard BrainPolicyEvidenceArtifact.sha256(graph.bytes) == context.graphSHA256 else {
    throw ConnectomeError.invalid("graph SHA-256 mismatch")
  }
  let template = try BrainReachHoldExperiment.read(CompiledSpeciesTemplate.self,
    hash: context.compiledSpeciesSHA256, directory: store)
  let publication = try BrainReachHoldExperiment.read(BrainMotorStudyPublication.self,
    hash: context.publicationSHA256, directory: store)
  try publication.validate()
  return (store, graph, template, publication)
}
private func emit<T: Encodable>(_ value: T) throws {
  var bytes = try BrainPolicyEvidenceArtifact.encodeCanonical(value); bytes.append(10)
  FileHandle.standardOutput.write(bytes)
}

do {
  let args = Array(CommandLine.arguments.dropFirst())
  if args.count == 2, args[0] == "inspect" {
    let graph = try ConnectomeGraph(contentsOf: URL(fileURLWithPath: args[1]))
    let result: [String: Any] = ["format": "NUMICNS1", "nodes": graph.nodeCount, "edges": graph.edgeCount,
      "resolution": graph.isPopulationGraph ? "population" : "neuron",
      "graphFingerprint": String(format: "%016llx", graph.fingerprint),
      "sha256": BrainPolicyEvidenceArtifact.sha256(graph.bytes),
      "bytes": graph.bytes.count, "manifest": try JSONSerialization.jsonObject(with: Data(graph.manifestJSON.utf8)),
      "runtimeQualification": "not established by inspection"]
    var data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]); data.append(10)
    FileHandle.standardOutput.write(data)
  } else {
    guard args.count == 3, args[1] == "--config", ["prepare", "train", "validate-launch"].contains(args[0]) else {
      throw ConnectomeError.invalid("usage: numi-brain-connectome inspect GRAPH | prepare|train|validate-launch --config FILE")
    }
    let url = URL(fileURLWithPath: args[2])
    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard size > 0, size <= 16_777_216 else { throw ConnectomeError.invalid("configuration size limit") }
    let bytes = try Data(contentsOf: url)
    guard bytes.count <= 16_777_216 else { throw ConnectomeError.invalid("configuration grew beyond limit") }
    switch args[0] {
    case "prepare":
      let input = try JSONDecoder().decode(PrepareInput.self, from: bytes)
      let (store, graph, template, publication) = try load(input.context)
      let binding = try ConnectomeBinding(graph: graph, template: template,
        parameterVersionFingerprint: publication.version.fingerprint, channelCount: input.channelCount,
        nominalStepMicroseconds: input.nominalStepMicroseconds, integrationStepMicroseconds: input.integrationStepMicroseconds,
        receptors: input.receptors, descending: input.descending)
      guard template.species.motor.actuatorCount <= 4096 else { throw ConnectomeError.invalid("decoder actuator capacity") }
      let decoder = try ConnectomeMotorDecoder(binding: binding, template: template,
        weights: Array(repeating: 0, count: Int(binding.channelCount)*Int(template.species.motor.actuatorCount)),
        bias: Array(repeating: 0, count: Int(template.species.motor.actuatorCount)),
        maximumDriveChangePerSecond: input.maximumDriveChangePerSecond)
      let launch = try ConnectomeLaunch(graph: graph, template: template,
        parameterVersionFingerprint: publication.version.fingerprint,
        nominalStepMicroseconds: input.nominalStepMicroseconds, integrationStepMicroseconds: input.integrationStepMicroseconds,
        maximumSubsteps: input.maximumSubsteps, receptors: input.receptors, descending: input.descending,
        decoder: decoder, executionMode: .observeTeacher)
      _ = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
      let hash = try BrainReachHoldExperiment.retain(launch, directory: store)
      try emit(Result(kind: "untrained-teacher-observer", artifactSHA256: hash, launchSHA256: hash))
    case "train":
      let input = try JSONDecoder().decode(LearnInput.self, from: bytes)
      let (store, graph, template, publication) = try load(input.context)
      guard !input.trainingRunSHA256.isEmpty, !input.heldOutRunSHA256.isEmpty,
        input.trainingRunSHA256.count + input.heldOutRunSHA256.count <= 256,
        Set(input.trainingRunSHA256 + input.heldOutRunSHA256).count == input.trainingRunSHA256.count + input.heldOutRunSHA256.count else {
        throw ConnectomeError.invalid("empty, repeated or oversized teacher run selection")
      }
      let launch = try BrainReachHoldExperiment.read(ConnectomeLaunch.self, hash: input.teacherLaunchSHA256, directory: store)
      let program = try launch.compile(graph: graph, template: template, parameterVersionFingerprint: publication.version.fingerprint)
      func rows(_ hashes: [String]) throws -> [ConnectomeTrainingRow] {
        var values: [ConnectomeTrainingRow] = []
        for hash in hashes {
          let run = try BrainReachHoldExperiment.read(ConnectomeTrainingRun.self, hash: hash, directory: store)
          let batch = try run.verifiedRows(program: program, directory: store)
          guard batch.count <= 65_536-values.count else { throw ConnectomeError.invalid("teacher row capacity") }
          values.append(contentsOf: batch)
        }
        return values
      }
      let split = try ConnectomeTrainingSplit(program: program, training: rows(input.trainingRunSHA256), heldOut: rows(input.heldOutRunSHA256))
      let learned = try MLXConnectomeDecoderLearner.train(program: program, split: split, settings: input.settings)
      let candidate = try ConnectomeLaunch(graph: graph, template: template,
        parameterVersionFingerprint: publication.version.fingerprint,
        nominalStepMicroseconds: launch.nominalStepMicroseconds, integrationStepMicroseconds: launch.integrationStepMicroseconds,
        maximumSubsteps: launch.maximumSubsteps, receptors: launch.receptors, descending: launch.descending,
        decoder: learned.decoder, executionMode: .actuate)
      _ = try BrainPolicyEvidenceArtifact.write(bytes, to: store)
      try emit(Result(kind: "unevaluated-decoder-candidate",
        artifactSHA256: try BrainReachHoldExperiment.retain(learned, directory: store),
        launchSHA256: try BrainReachHoldExperiment.retain(candidate, directory: store)))
    default:
      let input = try JSONDecoder().decode(ValidateInput.self, from: bytes)
      let (store, graph, template, publication) = try load(input.context)
      let launch = try BrainReachHoldExperiment.read(ConnectomeLaunch.self, hash: input.launchSHA256, directory: store)
      _ = try launch.compile(graph: graph, template: template, parameterVersionFingerprint: publication.version.fingerprint)
      try emit(Result(kind: "structurally-valid-unqualified-launch", artifactSHA256: input.launchSHA256, launchSHA256: input.launchSHA256))
    }
  }
} catch { FileHandle.standardError.write(Data("numi-brain-connectome: \(error)\n".utf8)); exit(1) }

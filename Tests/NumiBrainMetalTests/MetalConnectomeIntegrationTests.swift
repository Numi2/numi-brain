import Foundation
import Metal
import XCTest
import NumiBrainConnectomeABI
import NumiBrainConnectomeTestSupport
@testable import NumiBrainCore
@testable import NumiBrainMetal

/// Synthetic receptor/physics-token fixtures. These exercise the REAL Metal
/// arena and root lifecycle, not a claim of physical robot or fly behavior.
@available(macOS 26.0, *)
final class MetalConnectomeIntegrationTests: XCTestCase {
  private func program(_ compiled: CompiledSpeciesTemplate, _ publication: BrainParameterPublication,
    bias: Float = 0) throws -> ConnectomeProgram {
    let graph = try ConnectomeGraph(data: ConnectomeTestFixture.data())
    let binding = try ConnectomeBinding(graph: graph, template: compiled,
      parameterVersionFingerprint: publication.version.fingerprint, channelCount: 1,
      nominalStepMicroseconds: 1_000, integrationStepMicroseconds: 1_000,
      receptors: [.init(neuronIdentifier: 10, modality: .proprioception, receptorIndex: 0, featureIndex: 0)],
      descending: [.init(neuronIdentifier: 30, channel: 0)])
    let decoder = try ConnectomeMotorDecoder(binding: binding, template: compiled,
      weights: Array(repeating: -1, count: Int(compiled.species.motor.actuatorCount)),
      bias: Array(repeating: bias, count: Int(compiled.species.motor.actuatorCount)),
      maximumDriveChangePerSecond: 1)
    return try ConnectomeProgram(graph: graph, binding: binding, decoder: decoder)
  }
  private func root(_ generation: UInt64, _ version: UInt64) throws -> BrainJointTransactionToken {
    try BrainJointTransactionToken(environmentIdentifier: 7, episodeIdentifier: 23,
      controlStepIdentifier: generation+1, parameterVersionFingerprint: version,
      baseBrainGeneration: generation, basePhysicsGeneration: 100+generation,
      committedTimestamp: .init(microseconds: 10_000+generation*5_000),
      targetTimestamp: .init(microseconds: 15_000+generation*5_000), randomCounterGeneration: generation)
  }
  private func sensors(_ compiled: CompiledSpeciesTemplate, _ root: BrainJointTransactionToken,
    _ device: any MTLDevice, value: Float) throws -> [MetalRawSensorBufferLease] {
    try compiled.species.senses.filter(\.enabled).map { sense in
      let count = Int(sense.receptorCount)*Int(sense.observationDimension)
      let values = Array(repeating: sense.modality == .interoception ? Float(0.5) : value, count: count)
      let buffer = try XCTUnwrap(values.withUnsafeBytes {
        device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
      })
      return try MetalRawSensorBufferLease(buffer: buffer, modality: sense.modality,
        receptorTimestamp: .init(microseconds: root.committedTimestamp.rawValue-UInt64(sense.latencyMicroseconds)),
        receptorCount: sense.receptorCount, featureDimension: sense.observationDimension)
    }
  }
  private func accepted(_ root: BrainJointTransactionToken) throws -> (AcceptedPhysicsStateToken, BrainJointCommitToken) {
    var physical = BrainJointTransaction(token: root)
    let step = try physical.beginPhysicsSubstep(durationMicroseconds: root.targetTimestamp.rawValue-root.committedTimestamp.rawValue)
    let token = try AcceptedPhysicsStateToken(transaction: root, substep: step,
      physicsStateFingerprint: 0x123+root.basePhysicsGeneration, physicsGeneration: root.basePhysicsGeneration+1)
    try physical.acceptPhysicsSubstep(token, for: step)
    return (token, try physical.commit())
  }
  private func section(_ bytes: Data, _ runtime: MetalEmbodiedBrainRuntime, _ section: MetalAgentHotSection) -> Data {
    let layout = runtime.agentStateRuntime.arena.layout.section(section)
    return bytes.subdata(in: layout.byteOffset..<layout.byteOffset+layout.byteCount)
  }
  func testArenaCommitAbortCheckpointAndIdentityIsolation() throws {
    // A missing device fails this execution test; CI must not turn a skip into
    // GPU evidence. Separate source-build checks do not require a GPU.
    let device = try XCTUnwrap(MTLCreateSystemDefaultDevice(), "Metal GPU required for execution qualification")
    _ = try XCTUnwrap(device.makeMTL4CommandQueue(), "Metal 4 required")
    let compiled = try makeNumanXInteropCompiledTemplate()
    let publication = try BrainParameterPublication.developmentalSeedV1(species: compiled.species, tissueParameters: .corticalSheetV0)
    let module = try program(compiled, publication)
    func make(_ program: ConnectomeProgram?) throws -> MetalEmbodiedBrainRuntime {
      try MetalEmbodiedBrainRuntime(device: device, compiledSpeciesTemplate: compiled,
        regionalProgram: compiled.species.regionalProgram(), parameterVersion: publication.version,
        sharedParameterArtifact: publication.sharedArtifact, connectomeProgram: program)
    }
    let runtime = try make(module)
    let original = try runtime.agentStateRuntime.snapshotCommittedState()
    let token = try root(0, publication.version.fingerprint)
    var transaction = try runtime.beginControl(jointToken: token, cachedDecisionFingerprint: 1)
    _ = try runtime.inferAndDecide(transaction: transaction, rawSensors: sensors(compiled, token, device, value: 1))
    try transaction.abort()
    let aborted = try runtime.agentStateRuntime.snapshotCommittedState()
    XCTAssertEqual(aborted.hotState, original.hotState)
    XCTAssertEqual(aborted.persistentMemory, original.persistentMemory)
    transaction = try runtime.beginControl(jointToken: token, cachedDecisionFingerprint: 1)
    _ = try runtime.inferAndDecide(transaction: transaction, rawSensors: sensors(compiled, token, device, value: 1))
    let (physical, receipt) = try accepted(token)
    try transaction.finishGPUState(acceptedPhysicsState: physical)
    try transaction.commit(with: receipt)
    let committed = try runtime.saveCheckpoint(environmentIdentifier: 7, episodeIdentifier: 23,
      controlStepIdentifier: 1, committedTimestamp: token.targetTimestamp, physicalCheckpointFingerprint: 77)
    XCTAssertNotEqual(section(committed.hotState, runtime, .connectomeState), section(original.hotState, runtime, .connectomeState))
    let controls = section(committed.hotState, runtime, .connectomeControl)
    for index in 0..<Int(module.decoder.actuatorCount) {
      let drive = controls.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: index*16, as: Float.self) }
      let valid = controls.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: index*16+4, as: Float.self) }
      XCTAssertTrue(drive.isFinite); XCTAssertGreaterThanOrEqual(drive, 0)
      XCTAssertLessThanOrEqual(drive, 0.005001); XCTAssertEqual(valid, 1)
    }
    let restored = try make(module)
    XCTAssertTrue(runtime.connectomeRuntime!.sharedGraph === restored.connectomeRuntime!.sharedGraph)
    try restored.loadCheckpoint(committed, physicalCheckpointFingerprint: 77)
    XCTAssertEqual(try restored.agentStateRuntime.snapshotCommittedState().hotState, committed.hotState)
    // Changed decoder, same dimensions: checkpoint MUST NOT silently restore.
    let altered = try make(program(compiled, publication, bias: 0.1))
    XCTAssertThrowsError(try altered.loadCheckpoint(committed, physicalCheckpointFingerprint: 77))
    let baseline = try make(nil)
    XCTAssertThrowsError(try baseline.loadCheckpoint(committed, physicalCheckpointFingerprint: 77))
    let next = try root(1, publication.version.fingerprint)
    var snapshots: [Data] = []
    for mind in [runtime, restored] {
      let rootTransaction = try mind.beginControl(jointToken: next, cachedDecisionFingerprint: 2)
      _ = try mind.inferAndDecide(transaction: rootTransaction, rawSensors: sensors(compiled, next, device, value: 0.75))
      let (physical, receipt) = try accepted(next)
      try rootTransaction.finishGPUState(acceptedPhysicsState: physical)
      try rootTransaction.commit(with: receipt)
      snapshots.append(try mind.agentStateRuntime.snapshotCommittedState().hotState)
    }
    XCTAssertEqual(snapshots[0], snapshots[1], "resumed root must replay the whole committed neural state")
  }
  func testProgramBindsExactMorphologyAndLaunch() throws {
    let graph = try ConnectomeGraph(data: ConnectomeTestFixture.data())
    let first = try makeNumanXInteropCompiledTemplate(actuatorCount: 6)
    let second = try makeNumanXInteropCompiledTemplate(actuatorCount: 8)
    let publication = try BrainParameterPublication.developmentalSeedV1(species: first.species, tissueParameters: .corticalSheetV0)
    let value = try program(first, publication)
    XCTAssertThrowsError(try value.validate(template: second, parameterVersionFingerprint: publication.version.fingerprint))
    let launch = try ConnectomeLaunch(graph: graph, template: first, parameterVersionFingerprint: publication.version.fingerprint,
      nominalStepMicroseconds: 1_000, integrationStepMicroseconds: 1_000,
      receptors: [.init(neuronIdentifier: 10, modality: .proprioception, receptorIndex: 0, featureIndex: 0)],
      descending: [.init(neuronIdentifier: 30, channel: 0)], decoder: value.decoder)
    let decoded = try JSONDecoder().decode(ConnectomeLaunch.self, from: JSONEncoder().encode(launch))
    XCTAssertEqual(try decoded.compile(graph: graph, template: first, parameterVersionFingerprint: publication.version.fingerprint).fingerprint, value.fingerprint)
    XCTAssertThrowsError(try decoded.compile(graph: graph, template: second, parameterVersionFingerprint: publication.version.fingerprint))
  }
}

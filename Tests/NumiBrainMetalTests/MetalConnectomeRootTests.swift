import Foundation
import Metal
import XCTest
import NumiBrainConnectomeTestSupport
@testable import NumiBrainCore
@testable import NumiBrainMetal

/// Synthetic physical receipts exercise transaction ownership, not body physics
/// or task success. Uses the normal complete-brain factory and both GPU paths.
@available(macOS 26.0, *)
final class MetalConnectomeRootTests: XCTestCase {
  private struct Fixture {
    let device: any MTLDevice
    let body: CompiledSpeciesTemplate
    let publication: BrainParameterPublication
    let configuration: MetalNumiBrainConfiguration
    let runtime: MetalNumiBrainRuntime
  }

  private func makeFixture(shared: MetalConnectomeGraph? = nil, actuatorCount: UInt32 = 6,
    sensoryID: UInt64 = 10, descendingID: UInt64 = 30) throws -> Fixture {
    guard let device = shared?.device ?? MTLCreateSystemDefaultDevice(),
      device.makeMTL4CommandQueue() != nil, device.makeCommandAllocator() != nil,
      device.makeCommandBuffer() != nil else { throw XCTSkip("Metal 4 required") }
    let body = try makeNumanXInteropCompiledTemplate(actuatorCount: actuatorCount)
    let parameters = TissueParameters.corticalSheetV0
    let publication = try BrainParameterPublication.developmentalSeedV1(species: body.species, tissueParameters: parameters)
    let graph = try shared?.graph ?? ConnectomeGraph(data: ConnectomeTestFixture.data())
    let modality = try XCTUnwrap(body.species.senses.first(where: \.enabled)).modality
    let spec = ConnectomeControllerSpec(graphFingerprint: graph.fingerprint,
      speciesFingerprint: body.species.fingerprint, sensoryProfileFingerprint: body.sensoryProfile.fingerprint,
      nominalStepMicroseconds: 1_000, integrationStepMicroseconds: 100, channelCount: 1,
      receptors: [ConnectomeReceptorProjection(neuronIdentifier: sensoryID, modality: modality, receptorIndex: 0, featureIndex: 0)],
      descending: [ConnectomeDescendingProjection(neuronIdentifier: descendingID, channel: 0)],
      decoderWeights: [Float](repeating: 2, count: Int(body.species.motor.actuatorCount)),
      decoderBiases: [Float](repeating: 0, count: Int(body.species.motor.actuatorCount)))
    let configuration = MetalNumiBrainConfiguration(
      initialTissueState: try CPUTissueDynamics.makeRestingGrid(width: 8, height: 8, parameters: parameters),
      tissueParameters: parameters, tissueStimulus: .none, compiledSpeciesTemplate: body,
      randomContext: TissueRandomContext(seed: 0x4e55_4d49, environmentIdentifier: 7, episodeIdentifier: 23),
      schedulerEnvironmentIdentifier: 7, maximumEncodedSubsteps: 1,
      connectome: try MetalConnectomeConfiguration(graph: graph, specification: spec, sharedGraph: shared))
    let runtime = try MetalNumiBrainRuntime.makeRuntime(configuration: configuration, publication: publication, device: device)
    return Fixture(device: device, body: body, publication: publication, configuration: configuration, runtime: runtime)
  }

  private func sensors(_ f: Fixture, _ root: BrainJointTransactionToken,
    accepted: AcceptedPhysicsStateToken? = nil) throws -> NumanXSensorPacketLease {
    let timestamp = accepted?.acceptedTimestamp ?? root.committedTimestamp
    let raw = try f.body.species.senses.filter(\.enabled).enumerated().map { index, sense in
      let count = Int(sense.receptorCount) * Int(sense.observationDimension)
      let buffer = try XCTUnwrap(f.device.makeBuffer(length: count*4, options: .storageModeShared))
      buffer.contents().assumingMemoryBound(to: Float.self).initialize(repeating: Float(index+1)*0.125, count: count)
      return try MetalRawSensorBufferLease(buffer: buffer, modality: sense.modality,
        receptorTimestamp: BrainTimestamp(microseconds: timestamp.rawValue-UInt64(sense.latencyMicroseconds)),
        receptorCount: sense.receptorCount, featureDimension: sense.observationDimension)
    }
    return try NumanXSensorPacketLease(transaction: root, acceptedPhysicsState: accepted,
      compiledSpeciesTemplate: f.body, rawSensors: raw)
  }

  private func advance(_ f: Fixture, step: UInt64, asynchronous: Bool = false,
    abort: Bool = false) throws -> MetalNumiBrainCheckpoint {
    let generation = f.runtime.committedGeneration
    let start = 10_000 + generation*1_000
    let root = try f.runtime.beginControl(controlStepIdentifier: step,
      basePhysicsGeneration: 100+generation,
      committedTimestamp: BrainTimestamp(microseconds: start),
      targetTimestamp: BrainTimestamp(microseconds: start+1_000), cachedDecisionFingerprint: 0x5500+step)
    let input = try sensors(f, root.token)
    if asynchronous {
      let event = try XCTUnwrap(f.device.makeSharedEvent())
      let ticket = try f.runtime.submitInferAndDecide(root, numanXSensors: input,
        signal: MetalSharedEventPoint(event: event, value: 1))
      _ = try f.runtime.finishInferAndDecideSubmission(ticket, transaction: root, timeoutMilliseconds: 10_000)
    } else {
      _ = try f.runtime.inferAndDecide(root, numanXSensors: input)
    }
    if abort {
      try f.runtime.abortControl(root)
      return try f.runtime.saveCheckpoint(controlStepIdentifier: step-1, physicalCheckpointFingerprint: 99)
    }
    let fast = try f.runtime.advanceFastSystems(root, candidateDurationMicroseconds: 1_000)
    let accepted = try AcceptedPhysicsStateToken(transaction: root.token, substep: fast.substep,
      physicsStateFingerprint: 0x8800+step, physicsGeneration: 101+generation)
    try f.runtime.acceptPhysicsSubstep(root, accepted: accepted)
    _ = try f.runtime.commitControl(root, acceptedSensors: sensors(f, root.token, accepted: accepted))
    return try f.runtime.saveCheckpoint(controlStepIdentifier: step, physicalCheckpointFingerprint: 99)
  }

  func testNormalFactoryPublishesNeuralStateAndAbortDoesNotAdvanceIt() throws {
    let fixture = try makeFixture()
    let committed = try advance(fixture, step: 1)
    let neural = try XCTUnwrap(committed.cognitiveState.connectomeState)
    XCTAssertEqual(neural.generation, 1)
    XCTAssertEqual(neural.timestampMicroseconds, 11_000)
    XCTAssertTrue(neural.activity.contains { $0 != 0 }, "the normal decision path must execute the connectome")
    let afterAbort = try advance(fixture, step: 2, abort: true)
    XCTAssertEqual(afterAbort.cognitiveState.connectomeState, neural)
    XCTAssertEqual(afterAbort.committedGeneration, 1)
  }

  func testSharedGraphKeepsMindsIndependentAndAsyncMatchesSync() throws {
    guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("Metal required") }
    let shared = try MetalConnectomeGraph(graph: ConnectomeGraph(data: ConnectomeTestFixture.data()), device: device)
    let first = try makeFixture(shared: shared), second = try makeFixture(shared: shared)
    let a = try advance(first, step: 1)
    XCTAssertEqual(second.runtime.committedGeneration, 0)
    let b = try advance(second, step: 1, asynchronous: true)
    XCTAssertEqual(a.cognitiveState.connectomeState, b.cognitiveState.connectomeState)
    _ = try advance(first, step: 2)
    XCTAssertEqual(second.runtime.committedGeneration, 1)
  }

  func testCompleteCheckpointRestorationPreservesNeuralStateExactly() throws {
    let source = try makeFixture(), checkpoint = try advance(source, step: 1)
    let restored = try MetalNumiBrainHandle.create(configuration: source.configuration,
      publication: source.publication, device: source.device)
    try restored.loadCheckpoint(checkpoint, physicalCheckpointFingerprint: 99)
    let roundTrip = try restored.saveCheckpoint(controlStepIdentifier: 1, physicalCheckpointFingerprint: 99)
    XCTAssertEqual(roundTrip, checkpoint)
    XCTAssertEqual(roundTrip.cognitiveState.connectomeState, checkpoint.cognitiveState.connectomeState)
  }
  func testDistinctActuatorBodiesShareOnlyTheGraph() throws {
    guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("Metal required") }
    let shared = try MetalConnectomeGraph(graph: ConnectomeGraph(data: ConnectomeTestFixture.data()), device: device)
    let a = try makeFixture(shared: shared, actuatorCount: 4)
    let b = try makeFixture(shared: shared, actuatorCount: 6)
    XCTAssertNotEqual(a.body.fingerprint, b.body.fingerprint)
    let ca = try advance(a, step: 1), cb = try advance(b, step: 1)
    XCTAssertNotEqual(ca.cognitiveState.connectomeState?.programFingerprint,
                      cb.cognitiveState.connectomeState?.programFingerprint)
    XCTAssertEqual(ca.cognitiveState.connectomeState?.graphFingerprint,
                   cb.cognitiveState.connectomeState?.graphFingerprint)
  }

  func testDecoderForkRestoresIndependentCompleteMindWithoutChangingParent() throws {
    let source = try makeFixture(), checkpoint = try advance(source, step: 1)
    let encoded = try checkpoint.encoded()
    let spec = try XCTUnwrap(source.configuration.connectome).specification
    var coefficients = spec.decoderParameters
    coefficients[0] += 0.125
    let changed = try spec.replacingDecoderParameters(coefficients)
    let child = try MetalNumiBrainHandle.createConnectomeDecoderFork(
      from: encoded, configuration: source.configuration, publication: source.publication,
      identifier: "root-fork", specification: changed, physicalCheckpointFingerprint: 99,
      physicalData: Data("explicit synthetic physical fixture".utf8), device: source.device)
    let observed = try child.brain.saveCheckpoint(controlStepIdentifier: 1, physicalCheckpointFingerprint: 99)
    XCTAssertEqual(observed, child.fork.checkpoint)
    XCTAssertEqual(observed.cognitiveState.hotState, checkpoint.cognitiveState.hotState)
    XCTAssertEqual(observed.cognitiveState.persistentMemory, checkpoint.cognitiveState.persistentMemory)
    XCTAssertEqual(observed.fastTissueState, checkpoint.fastTissueState)
    XCTAssertEqual(observed.cognitiveState.connectomeState?.activity, checkpoint.cognitiveState.connectomeState?.activity)
    XCTAssertNotEqual(observed.cognitiveState.connectomeState?.programFingerprint, checkpoint.cognitiveState.connectomeState?.programFingerprint)
    _ = try advance(source, step: 2)
    XCTAssertEqual(child.brain.committedGeneration, 1)
    XCTAssertEqual(try child.brain.saveCheckpoint(controlStepIdentifier: 1, physicalCheckpointFingerprint: 99), observed)
  }

  /// Optional full-source execution, not an animal-behavior or physics benchmark.
  /// The root still uses the explicit synthetic receipt documented above.
  func testFullReleasedGraphUsesTheNormalMetalController() throws {
    guard let path = ProcessInfo.processInfo.environment["NUMIBRAIN_CONNECTOME_GRAPH"] else {
      throw XCTSkip("full release pack is not configured")
    }
    guard let device = MTLCreateSystemDefaultDevice(), device.supportsFamily(.metal4) else {
      XCTFail("full-source execution requires a Metal 4 device"); return
    }
    let graph = try ConnectomeGraph(contentsOf: URL(fileURLWithPath: path))
    XCTAssertEqual(graph.nodeCount, 166_700)
    XCTAssertEqual(graph.edgeCount, 25_582_938)
    XCTAssertEqual(graph.fingerprint, 0x5e1e89f366e0157a)
    var sensory: UInt64?, descending: UInt64?
    for i in 0..<graph.nodeCount {
      let node = try graph.node(at: i)
      let id = UInt64(node.identity_low) | (UInt64(node.identity_high) << 32)
      if sensory == nil, node.flags & 1 != 0 { sensory = id }
      if descending == nil, node.flags & 10 != 0 { descending = id }
      if sensory != nil && descending != nil { break }
    }
    let shared = try MetalConnectomeGraph(graph: graph, device: device)
    let f = try makeFixture(shared: shared, sensoryID: XCTUnwrap(sensory), descendingID: XCTUnwrap(descending))
    let started = DispatchTime.now().uptimeNanoseconds
    let checkpoint = try advance(f, step: 1)
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started)/1_000_000
    let neural = try XCTUnwrap(checkpoint.cognitiveState.connectomeState)
    try neural.validate()
    XCTAssertEqual(neural.activity.count, 4*graph.nodeCount)
    XCTAssertEqual(neural.generation, 1)
    XCTAssertTrue(neural.activity.contains(where: { $0 != 0 }))
    print("NUMIBRAIN_FULL_CONNECTOME device=\(device.name) nodes=\(graph.nodeCount) edges=\(graph.edgeCount) neuralCheckpointSHA256=\(neural.sha256) rootAndCheckpointWallMilliseconds=\(elapsed) syntheticPhysicsReceipt=true")
  }

}

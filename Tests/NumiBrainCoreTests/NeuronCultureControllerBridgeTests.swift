import XCTest

@testable import NumiBrainCore

final class NeuronCultureControllerBridgeTests: XCTestCase {
  private func token(controlStep: UInt64 = 3) throws -> BrainJointTransactionToken {
    try BrainJointTransactionToken(
      environmentIdentifier: 0,
      episodeIdentifier: 1,
      controlStepIdentifier: controlStep,
      parameterVersionFingerprint: 0x1001,
      baseBrainGeneration: 8,
      basePhysicsGeneration: 13,
      committedTimestamp: BrainTimestamp(microseconds: 10_000),
      targetTimestamp: BrainTimestamp(microseconds: 30_000),
      randomCounterGeneration: 21
    )
  }

  private func culture(fingerprint: UInt64 = 0xc011_7e) throws
    -> NeuronCultureModuleIdentity
  {
    try NeuronCultureModuleIdentity(
      cultureFingerprint: fingerprint,
      neuronCount: 1_000,
      synapseCount: 50_000,
      electrodeCount: 60
    )
  }

  func testPrepareDoesNotPublishAndExactAcceptPublishesOnce() throws {
    let root = try token()
    let identity = try culture()
    let profile = try NeuronCultureControllerProfile.potterReference60(
      culture: identity
    )
    var bridge = try NeuronCultureControllerBridge(
      culture: identity,
      profile: profile
    )
    var counts = Array(repeating: UInt32(0), count: 60)
    counts[9] = 12
    counts[24] = 4
    let frame = try NeuronCultureMEAFrame(
      transaction: root,
      culture: identity,
      neuralTick: 80,
      electrodeSpikeCounts: counts
    )
    let action = try bridge.prepare(frame: frame, for: root)
    XCTAssertNil(bridge.acceptedAction)
    XCTAssertEqual(bridge.preparedAction, action)
    XCTAssertGreaterThan(action.lateralCommand, 0)
    XCTAssertNotEqual(action.fingerprint, 0)

    try bridge.publishAccepted(action, for: root)
    XCTAssertNil(bridge.preparedAction)
    XCTAssertEqual(bridge.acceptedAction, action)
    XCTAssertThrowsError(try bridge.publishAccepted(action, for: root))
  }

  func testRejectPreservesAcceptedAuthorityAndReplayIsDeterministic() throws {
    let root = try token()
    let identity = try culture()
    let profile = try NeuronCultureControllerProfile.potterReference60(
      culture: identity,
      gain: 0.75
    )
    var counts = Array(repeating: UInt32(1), count: 60)
    counts[0] = 8
    let frame = try NeuronCultureMEAFrame(
      transaction: root,
      culture: identity,
      neuralTick: 11,
      electrodeSpikeCounts: counts
    )
    var first = try NeuronCultureControllerBridge(culture: identity, profile: profile)
    var replay = try NeuronCultureControllerBridge(culture: identity, profile: profile)
    let firstAction = try first.prepare(frame: frame, for: root)
    let replayAction = try replay.prepare(frame: frame, for: root)
    XCTAssertEqual(firstAction, replayAction)
    try first.rejectPrepared(for: root)
    XCTAssertNil(first.preparedAction)
    XCTAssertNil(first.acceptedAction)
  }

  func testIdentityShapeAndStaleRootFailClosed() throws {
    let root = try token()
    let stale = try token(controlStep: 4)
    let identity = try culture()
    let other = try culture(fingerprint: 0xbad5_eed)
    let profile = try NeuronCultureControllerProfile.potterReference60(
      culture: identity
    )
    XCTAssertThrowsError(
      try NeuronCultureControllerBridge(culture: other, profile: profile)
    )
    XCTAssertThrowsError(
      try NeuronCultureMEAFrame(
        transaction: root,
        culture: identity,
        neuralTick: 1,
        electrodeSpikeCounts: Array(repeating: 1, count: 59)
      )
    )
    let frame = try NeuronCultureMEAFrame(
      transaction: root,
      culture: identity,
      neuralTick: 1,
      electrodeSpikeCounts: Array(repeating: 1, count: 60)
    )
    var bridge = try NeuronCultureControllerBridge(culture: identity, profile: profile)
    XCTAssertThrowsError(try bridge.prepare(frame: frame, for: stale))
    XCTAssertNil(bridge.preparedAction)
    XCTAssertNil(bridge.acceptedAction)
  }

  func testSilentMEAFrameProducesCanonicalZeroAction() throws {
    let root = try token()
    let identity = try culture()
    let profile = try NeuronCultureControllerProfile.potterReference60(
      culture: identity
    )
    let frame = try NeuronCultureMEAFrame(
      transaction: root,
      culture: identity,
      neuralTick: 2,
      electrodeSpikeCounts: Array(repeating: 0, count: 60)
    )
    var bridge = try NeuronCultureControllerBridge(culture: identity, profile: profile)
    let action = try bridge.prepare(frame: frame, for: root)
    XCTAssertEqual(action.lateralCommand.bitPattern, Float(0).bitPattern)
    XCTAssertEqual(action.forwardCommand.bitPattern, Float(0).bitPattern)
  }
}

import Foundation
import XCTest
import NumiBrainCore
import NumiBrainConnectomeABI
import NumiBrainConnectomeTestSupport

final class ConnectomeGraphTests: XCTestCase {
  static let fixture = ConnectomeTestFixture.data()
  func testNativeRoundTripAndIdentities() throws {
    let graph = try ConnectomeGraph(data: Self.fixture)
    XCTAssertEqual(graph.nodeCount, 3); XCTAssertEqual(graph.edgeCount, 2)
    XCTAssertEqual(try graph.index(of: 30), 2)
    XCTAssertEqual(try graph.label(at: 1), "interneuron")
    XCTAssertThrowsError(try graph.index(of: 999))
    XCTAssertThrowsError(try graph.node(at: -1))
  }
  func testExactBodyBindingAndSemanticRejection() throws {
    let graph = try ConnectomeGraph(data: Self.fixture)
    let input = NBConnectomeInput(node: 0, scalar: 1, receptor: 0, reserved: 0,
      weight: 1, scale: 1, bias: 0, clip: 8)
    let output = NBConnectomeReadout(node: 2, channel: 0, weight: 1, reserved: 0)
    func bind(species: UInt64 = 1, ins: [NBConnectomeInput] = [input],
      outs: [NBConnectomeReadout] = [output]) throws -> ConnectomeBinding {
      try ConnectomeBinding(graph: graph, speciesFingerprint: species,
        sensoryProfileFingerprint: 2, parameterVersionFingerprint: 3,
        scalarCount: 2, receptorCount: 1, channelCount: 1,
        nominalStepMicroseconds: 20_000, integrationStepMicroseconds: 1_000,
        inputs: ins, readouts: outs)
    }
    let a = try bind(), b = try bind(species: 2)
    XCTAssertNotEqual(a.fingerprint, b.fingerprint)
    XCTAssertEqual(a.inputOffsets, [0, 1, 1, 1])
    XCTAssertThrowsError(try bind(species: 0))
    XCTAssertThrowsError(try bind(ins: [input, input]))
    var bad = input; bad.node = 1
    XCTAssertThrowsError(try bind(ins: [bad]))
    var wrongOutput = output; wrongOutput.node = 0
    XCTAssertThrowsError(try bind(outs: [wrongOutput]))
  }
  func testAllTruncationsFail() {
    for count in 0..<Self.fixture.count {
      XCTAssertThrowsError(try ConnectomeGraph(data: Self.fixture.prefix(count)))
    }
  }
}

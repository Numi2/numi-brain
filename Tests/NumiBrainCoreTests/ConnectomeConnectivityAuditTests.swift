import XCTest
import NumiBrainCore
import NumiBrainConnectomeABI
import NumiBrainConnectomeTestSupport

final class ConnectomeConnectivityAuditTests: XCTestCase {
  func binding(_ graph: ConnectomeGraph, inputScale: Float = 1, channels: UInt32 = 1) throws -> ConnectomeBinding {
    try ConnectomeBinding(graph: graph, speciesFingerprint: 1,
      sensoryProfileFingerprint: 2, parameterVersionFingerprint: 3,
      scalarCount: 2, receptorCount: 1, channelCount: channels,
      nominalStepMicroseconds: 1000, integrationStepMicroseconds: 1000,
      inputs: [NBConnectomeInput(node: 0, scalar: 1, receptor: 0, reserved: 0,
        weight: 1, scale: inputScale, bias: 0, clip: 8)],
      readouts: (0..<channels).map { NBConnectomeReadout(node: 2, channel: $0, weight: $0 == 0 ? 1 : 0, reserved: 0) })
  }
  func testNativeDistancesAndJSONRoundTrip() throws {
    let graph = try ConnectomeGraph(data: ConnectomeTestFixture.data())
    let audit = try ConnectomeConnectivityAudit(graph: graph, binding: binding(graph))
    XCTAssertEqual(audit.channelHopsFromInput, [2])
    XCTAssertEqual(audit.inputHopsToReadout, [2])
    XCTAssertEqual(audit.reachableNodes, 3)
    XCTAssertTrue(audit.allChannelsReachable)
    try audit.requireAllChannelsReachable()
    XCTAssertEqual(try JSONDecoder().decode(ConnectomeConnectivityAudit.self,
      from: JSONEncoder().encode(audit)), audit)
  }
  func testDisabledSensorAndReadoutCannotPassPreflight() throws {
    let graph = try ConnectomeGraph(data: ConnectomeTestFixture.data())
    for binding in [try binding(graph, inputScale: 0), try binding(graph, channels: 2)] {
      let audit = try ConnectomeConnectivityAudit(graph: graph, binding: binding)
      XCTAssertFalse(audit.allChannelsReachable)
      XCTAssertThrowsError(try audit.requireAllChannelsReachable())
    }
  }
  func testScratchBudgetRejectedBeforeTraversal() throws {
    let graph = try ConnectomeGraph(data: ConnectomeTestFixture.data())
    XCTAssertThrowsError(try ConnectomeConnectivityAudit(graph: graph,
      binding: binding(graph), maximumScratchBytes: 1))
  }
}

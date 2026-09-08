import Foundation
import XCTest
@testable import NumiBrainCore

final class SourceCompliantJointTopologyTests: XCTestCase {
  func testOnlyExplicitSourceComplianceAdmitsResetOutsideRange() throws {
    let axis = try NumanXBodyLocalPoint(x: 0, y: 1, z: 0)
    XCTAssertThrowsError(try NumanXJointCoordinateTopology(identifier: 0, kind: .linear,
      parentLocalAxis: axis, minimumPosition: 7.69e-11, maximumPosition: 0.006792, restPosition: 0))
    let source = try NumanXJointCoordinateTopology(identifier: 0, kind: .linear,
      parentLocalAxis: axis, minimumPosition: 7.69e-11, maximumPosition: 0.006792,
      restPosition: 0, sourceCompliantLimit: true)
    XCTAssertEqual(source.restPosition.bitPattern, Float(0).bitPattern)
    let encoded = try JSONEncoder().encode(source)
    XCTAssertEqual(try JSONDecoder().decode(NumanXJointCoordinateTopology.self, from: encoded), source)
    XCTAssertThrowsError(try NumanXJointCoordinateTopology(identifier: 0, kind: .linear,
      parentLocalAxis: axis, minimumPosition: 1, maximumPosition: -1,
      restPosition: 0, sourceCompliantLimit: true))
  }

  func testLegacyEncodingAndDecodeRetainStrictBounds() throws {
    let legacy = try NumanXJointCoordinateTopology(identifier: 0, kind: .angular,
      parentLocalAxis: .init(x: 0, y: 1, z: 0), minimumPosition: -1, maximumPosition: 1, restPosition: 0)
    let encoded = try JSONEncoder().encode(legacy)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    XCTAssertNil(json["sourceCompliantLimit"])
    XCTAssertEqual(try JSONDecoder().decode(NumanXJointCoordinateTopology.self, from: encoded), legacy)
  }
}

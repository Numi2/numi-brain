import Foundation
import XCTest
@testable import NumiBrainValidation

final class PhysicalSensorFieldTests: XCTestCase {
  private func bytes(_ values: [UInt32]) -> Data {
    var data = Data()
    for value in values { var little = value.littleEndian; withUnsafeBytes(of: &little) { data.append(contentsOf: $0) } }
    return data
  }
  func testBitZeroCannotValidateAnUnrelatedFeature() throws {
    let data = bytes((0..<22).map { Float($0).bitPattern })
    let head = try PhysicalSensorField.decode(values: data, validity: bytes([1]), receptorCount: 1,
      featureDimension: 22, receptorIndex: 0, featureIndex: 15, requiredValidityMask: 1 << 15)
    XCTAssertEqual(head.value, 15); XCTAssertFalse(head.valid)
    XCTAssertTrue(try PhysicalSensorField.decode(values: data, validity: bytes([1 << 15]), receptorCount: 1,
      featureDimension: 22, receptorIndex: 0, featureIndex: 15, requiredValidityMask: 1 << 15).valid)
  }
  func testCompositeMaskRequiresEveryDeclaredBit() throws {
    let data = bytes([Float(2).bitPattern])
    XCTAssertFalse(try PhysicalSensorField.decode(values: data, validity: bytes([4]), receptorCount: 1,
      featureDimension: 1, receptorIndex: 0, featureIndex: 0, requiredValidityMask: 12).valid)
    XCTAssertTrue(try PhysicalSensorField.decode(values: data, validity: bytes([12]), receptorCount: 1,
      featureDimension: 1, receptorIndex: 0, featureIndex: 0, requiredValidityMask: 12).valid)
  }
  func testReceptorSelectionUsesItsOwnValidityWord() throws {
    let result = try PhysicalSensorField.decode(values: bytes([Float(1).bitPattern, Float(-2).bitPattern]),
      validity: bytes([0, 1]), receptorCount: 2, featureDimension: 1, receptorIndex: 1, featureIndex: 0, requiredValidityMask: 1)
    XCTAssertEqual(result.value, -2); XCTAssertTrue(result.valid)
  }
  func testMalformedShapesZeroMaskAndNonfiniteValuesFail() throws {
    XCTAssertThrowsError(try PhysicalSensorField.decode(values: bytes([0]), validity: bytes([1]), receptorCount: UInt32.max,
      featureDimension: UInt32.max, receptorIndex: 0, featureIndex: 0, requiredValidityMask: 1))
    XCTAssertThrowsError(try PhysicalSensorField.decode(values: bytes([0]), validity: bytes([1]), receptorCount: 1,
      featureDimension: 1, receptorIndex: 0, featureIndex: 0, requiredValidityMask: 0))
    XCTAssertThrowsError(try PhysicalSensorField.decode(values: bytes([Float.nan.bitPattern]), validity: bytes([1]), receptorCount: 1,
      featureDimension: 1, receptorIndex: 0, featureIndex: 0, requiredValidityMask: 1))
  }
}

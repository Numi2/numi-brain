import XCTest
@testable import NumiBrainValidation

final class PhysicalReferenceImportTests: XCTestCase {
  private func source(_ body: String = "0 1 2\n0.001 3 4\n0.003 5 6", header: String = "inDegrees=no") -> Data {
    Data("Synthetic fixture\nnRows=3\nnColumns=3\nversion=1\n\(header)\nendheader\ntime tendon angle\n\(body)\n".utf8)
  }
  private func selection(column: String = "tendon", unit: String = "N", origin: Double = 0,
    quantization: Double = 0.01) throws -> OpenSimStorageSelection {
    try .init(column: column, quantity: "testQuantity", unit: unit, frame: "testFrame", coordinate: "test:0",
      timeOriginSeconds: origin, maximumTimeQuantizationErrorMicroseconds: quantization)
  }
  func testIrregularOpenSimScalarTableImportsExactly() throws {
    let trace = try OpenSimStorageReader.read(source(), selection: selection())
    XCTAssertEqual(trace.timestampsMicroseconds, [0, 1000, 3000])
    XCTAssertEqual(trace.values, [1, 3, 5])
    XCTAssertEqual(trace.validity, [true, true, true])
  }
  func testDeclaredOriginDoesNotFitAnOffsetToReference() throws {
    let trace = try OpenSimStorageReader.read(source("1 1 2\n1.001 3 4\n1.003 5 6"), selection: selection(origin: 1))
    XCTAssertEqual(trace.timestampsMicroseconds, [0, 1000, 3000])
  }
  func testAngularMetadataCannotSilentlyRelabelDegrees() throws {
    XCTAssertThrowsError(try OpenSimStorageReader.read(source(header: "inDegrees=yes"), selection: selection(column: "angle", unit: "rad")))
    let trace = try OpenSimStorageReader.read(source(header: "inDegrees=yes"), selection: selection(column: "angle", unit: "deg"))
    XCTAssertEqual(trace.values, [2, 4, 6])
  }
  func testMissingColumnRaggedRowAndHeaderCountDriftFail() throws {
    XCTAssertThrowsError(try OpenSimStorageReader.read(source(), selection: selection(column: "missing")))
    XCTAssertThrowsError(try OpenSimStorageReader.read(source("0 1\n0.001 3 4\n0.003 5 6"), selection: selection()))
    XCTAssertThrowsError(try OpenSimStorageReader.read(source("0 1 2\n0.001 3 4"), selection: selection()))
    XCTAssertThrowsError(try OpenSimStorageReader.read(source(header: "nRows=3"), selection: selection()))
  }
  func testNonfiniteUnselectedColumnIsStillRejected() throws {
    XCTAssertThrowsError(try OpenSimStorageReader.read(source("0 1 nan\n0.001 3 4\n0.003 5 6"), selection: selection()))
    XCTAssertThrowsError(try OpenSimStorageReader.read(source("0 1 2,3,4\n0.001 3 4\n0.003 5 6"), selection: selection()))
  }
  func testTimeReversalAliasingAndQuantizationAreRejected() throws {
    XCTAssertThrowsError(try OpenSimStorageReader.read(source("0 1 2\n0 3 4\n0.003 5 6"), selection: selection()))
    XCTAssertThrowsError(try OpenSimStorageReader.read(source("0 1 2\n0.0000001 3 4\n0.003 5 6"), selection: selection(quantization: 0.5)))
    XCTAssertThrowsError(try OpenSimStorageReader.read(source("0 1 2\n0.0010001 3 4\n0.003 5 6"), selection: selection(quantization: 0.01)))
    XCTAssertThrowsError(try OpenSimStorageReader.read(source(), selection: selection(origin: 1)))
  }
  func testJSONImportRevalidatesSourceAndRoundTripsPlan() throws {
    let specification = PhysicalReferenceImport.openSimStorage(selection: try selection())
    let decoded = try JSONDecoder().decode(PhysicalReferenceImport.self, from: JSONEncoder().encode(specification))
    XCTAssertEqual(decoded, specification)
    let trace = try decoded.decode(source())
    XCTAssertEqual(try PhysicalReferenceImport.traceJSON.decode(JSONEncoder().encode(trace)), trace)
    XCTAssertThrowsError(try PhysicalReferenceImport.traceJSON.decode(Data("{}".utf8)))
  }
  func testUnsupportedFormatAndMalformedUnitFlagFailClosed() throws {
    XCTAssertThrowsError(try OpenSimStorageReader.read(source(header: "DataType=Vec3"), selection: selection()))
    XCTAssertThrowsError(try OpenSimStorageReader.read(source(header: "inDegrees=maybe"), selection: selection()))
    XCTAssertThrowsError(try OpenSimStorageReader.read(Data("time tendon\n0 1\n1 2".utf8), selection: selection()))
  }
}

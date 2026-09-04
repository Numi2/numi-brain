import XCTest
@testable import NumiBrainValidation

final class PhysicalTraceValidationTests: XCTestCase {
  private func trace(_ times: [UInt64], _ values: [Double], validity: [Bool]? = nil,
    unit: String = "N", coordinate: String = "muscle:23") throws -> PhysicalTrace {
    try PhysicalTrace(quantity: "tendonForce", unit: unit, frame: "muscleLocal", coordinate: coordinate,
      timestampsMicroseconds: times, values: values, validity: validity ?? values.map { _ in true })
  }
  private func plan(alignment: PhysicalTraceComparisonPlan.Alignment = .exact,
    candidateOrigin: UInt64 = 0, referenceOrigin: UInt64 = 0, gap: UInt64 = 0,
    minimum: UInt64 = 1, tolerance: Double = 1e-8) throws -> PhysicalTraceComparisonPlan {
    try .init(alignment: alignment, candidateTimeOriginMicroseconds: candidateOrigin,
      referenceTimeOriginMicroseconds: referenceOrigin, maximumInterpolationGapMicroseconds: gap,
      minimumDurationMicroseconds: minimum, physicalScale: 10, maximumNormalizedRMSE: tolerance,
      maximumNormalizedPeakError: tolerance, maximumNormalizedAbsoluteBias: tolerance)
  }

  func testExactIdenticalTracePassesWithoutFittedNormalization() throws {
    let value = try trace([0,10,20],[1,2,3])
    let result = try PhysicalTraceValidation.compare(candidate: value, reference: value, plan: plan())
    XCTAssertEqual(result.result.status, .passed)
    XCTAssertEqual(result.sampleCount, 3)
    XCTAssertEqual(result.durationMicroseconds, 20)
  }

  func testPhysicalTimeWeightedRMSEUsesExactLinearErrorIntegral() throws {
    let result = try PhysicalTraceValidation.compare(candidate: trace([0,10],[0,10]),
      reference: trace([0,10],[0,0]), plan: plan(tolerance: 2))
    XCTAssertEqual(result.result.metrics[0].residual, sqrt(1.0/3), accuracy: 1e-14)
    XCTAssertEqual(result.normalizedSignedBias, 0.5, accuracy: 1e-14)
    XCTAssertEqual(result.result.metrics[1].residual, 1)
  }

  func testIrregularSamplingDoesNotOverweightDenseFrames() throws {
    let coarse = try PhysicalTraceValidation.compare(candidate: trace([0,10],[0,10]),
      reference: trace([0,10],[0,0]), plan: plan(tolerance: 2))
    let dense = try PhysicalTraceValidation.compare(candidate: trace([0,1,2,10],[0,1,2,10]),
      reference: trace([0,1,2,10],[0,0,0,0]), plan: plan(tolerance: 2))
    XCTAssertEqual(coarse.result.metrics[0].residual, dense.result.metrics[0].residual, accuracy: 1e-14)
  }

  func testExplicitInterpolationAndTimeOrigins() throws {
    let result = try PhysicalTraceValidation.compare(candidate: trace([100,105,110],[0,5,10]),
      reference: trace([200,210],[0,10]), plan: plan(alignment: .linearReference,
        candidateOrigin: 100, referenceOrigin: 200, gap: 10))
    XCTAssertEqual(result.result.status, .passed)
  }

  func testIntegerClockSubtractionBeforeConversion() throws {
    let t: UInt64 = (1 << 54) + 3
    let result = try PhysicalTraceValidation.compare(candidate: trace([t,t+1,t+2],[0,1,2]),
      reference: trace([0,2],[0,2]), plan: plan(alignment: .linearReference, candidateOrigin: t, gap: 2))
    XCTAssertEqual(result.result.status, .passed)
  }

  func testNoExtrapolationOrUnboundedGap() throws {
    XCTAssertThrowsError(try PhysicalTraceValidation.compare(candidate: trace([0,5,20],[0,5,20]),
      reference: trace([0,10],[0,10]), plan: plan(alignment: .linearReference, gap: 10)))
    XCTAssertThrowsError(try PhysicalTraceValidation.compare(candidate: trace([0,5,10],[0,5,10]),
      reference: trace([0,10],[0,10]), plan: plan(alignment: .linearReference, gap: 9)))
  }

  func testInvalidObservationsAreNotSilentlyDropped() throws {
    let good = try trace([0,1,2],[1,2,3])
    let invalid = try trace([0,1,2],[1,2,3], validity: [true,false,true])
    XCTAssertThrowsError(try PhysicalTraceValidation.compare(candidate: invalid, reference: good, plan: plan()))
    XCTAssertThrowsError(try PhysicalTraceValidation.compare(candidate: good, reference: invalid, plan: plan()))
  }

  func testUnitsCoordinatesTimestampsAndHorizonMustMatch() throws {
    let good = try trace([0,10],[1,2])
    for other in [try trace([0,10],[1,2], unit: "m"), try trace([0,10],[1,2], coordinate: "muscle:24"),
      try trace([0,11],[1,2])] {
      XCTAssertThrowsError(try PhysicalTraceValidation.compare(candidate: good, reference: other, plan: plan()))
    }
    XCTAssertThrowsError(try PhysicalTraceValidation.compare(candidate: good, reference: good, plan: plan(minimum: 11)))
  }

  func testNoAutomaticTimeShiftCanHideLag() throws {
    let result = try PhysicalTraceValidation.compare(candidate: trace([0,1,2,3],[0,0,1,0]),
      reference: trace([0,1,2,3],[0,1,0,0]), plan: plan())
    XCTAssertEqual(result.result.status, .failed)
  }

  func testDecodedInvalidTraceAndPlanAreRevalidated() throws {
    let encoded = try JSONEncoder().encode(trace([0,1],[1,2]))
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object["timestampsMicroseconds"] = [1,1]
    let decoded = try JSONDecoder().decode(PhysicalTrace.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertThrowsError(try decoded.validate())
    XCTAssertThrowsError(try trace([0,1],[1,.nan]))
    XCTAssertThrowsError(try plan(tolerance: -1))
  }
}

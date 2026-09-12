import Foundation
import XCTest
@testable import NumiBrainMetal

final class MetalNumanXBehaviorTelemetryTests: XCTestCase {
  private func fixture() -> [String: Any] { [
    "schema":"numi.human.accepted-metric-snapshot.v1","metric_program_sha256":String(repeating:"a",count:64),
    "program_fingerprint":1,"initial_physics_generation":4,"initial_timestamp_ns":100000,"end_ns":150000,"step_ns":25000,
    "accepted_root_count":2,"rejected_attempt_count":1,"completed_attempt_count":3,"metric_sample_count":2,
    "audit_covered_root_count":0,"audit_covered_attempt_count":0,"posture_violation_count":0,"settled_suffix_steps":2,
    "speed_error_sample_count":0,"audit_violation_counts":[0,0,0,0,0,0,0,0],
    "minimum_root_height_m_hi_lo":[1.0,1e-8],"maximum_trunk_tilt_rad_hi_lo":[0.0,0.0],
    "maximum_planar_speed_mps_hi_lo":[0.0,0.0],"speed_squared_error_sum_hi_lo":[0.0,0.0],
    "last_transaction_fingerprint":12,"last_joint_fence_fingerprint":23,
    "initial_posture_valid":NSNull(),"initial_settled":NSNull(),"forbidden_contact_coverage":"unavailable",
    "native_audit_coverage":"unavailable","generic_taskpack_lowering":"unavailable",
    "full_behavior_qualified":false,"accepted_root_proof_sha256":NSNull(),"finalized":true] }
  private func decode(_ x: [String:Any]) throws -> MetalNumanXBehaviorMetricSnapshot {
    try .decode(JSONSerialization.data(withJSONObject:x,options:[.sortedKeys]))
  }
  func testPartialNativeSnapshotWithNonzeroEpoch() throws {
    let x=try decode(fixture());XCTAssertEqual(x.acceptedRootCount,2);XCTAssertEqual(x.rejectedAttemptCount,1)
    XCTAssertFalse(x.fullBehaviorQualified);XCTAssertNil(x.initialSettled)
  }
  func testFalsePromotionDenied() {var x=fixture();x["full_behavior_qualified"]=true;XCTAssertThrowsError(try decode(x))}
  func testMissingAuditOwnerCannotClaimCoverage() {var x=fixture();x["audit_covered_root_count"]=2;XCTAssertThrowsError(try decode(x))}
  func testMissingResetCannotBeInvented() {var x=fixture();x["initial_settled"]=true;XCTAssertThrowsError(try decode(x))}
  func testPendingPublicationDenied() {var x=fixture();x["finalized"]=false;XCTAssertThrowsError(try decode(x))}
  func testCandidateCannotIncreaseMetricCount() {var x=fixture();x["metric_sample_count"]=3;XCTAssertThrowsError(try decode(x))}
  func testMissingRejectedAttemptDenied() {var x=fixture();x["completed_attempt_count"]=2;XCTAssertThrowsError(try decode(x))}
  func testMalformedPairDenied() {var x=fixture();x["minimum_root_height_m_hi_lo"]=[1];XCTAssertThrowsError(try decode(x))}
  func testWholeStateProofCannotBeInvented() {var x=fixture();x["accepted_root_proof_sha256"]=String(repeating:"b",count:64);XCTAssertThrowsError(try decode(x))}
  func testBackwardClockDenied() {var x=fixture();x["end_ns"]=99999;XCTAssertThrowsError(try decode(x))}
  func testClockCountMismatchDenied() {var x=fixture();x["end_ns"]=150001;XCTAssertThrowsError(try decode(x))}
  func testZeroStepDenied() {var x=fixture();x["step_ns"]=0;XCTAssertThrowsError(try decode(x))}
  func testMissingStepDenied() {var x=fixture();x.removeValue(forKey:"step_ns");XCTAssertThrowsError(try decode(x))}
  func testElapsedClockOverflowDenied() {var x=fixture();x["step_ns"]=UInt64.max;XCTAssertThrowsError(try decode(x))}
  func testAbsoluteClockOverflowDenied() {var x=fixture();x["initial_timestamp_ns"]=UInt64.max;XCTAssertThrowsError(try decode(x))}
  func testGenerationOverflowDenied() {var x=fixture();x["initial_physics_generation"]=UInt64.max;XCTAssertThrowsError(try decode(x))}

}

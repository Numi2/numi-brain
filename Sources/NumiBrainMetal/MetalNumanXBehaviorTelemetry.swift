import Foundation

/// Privileged accepted-root diagnostics. This never enters the Brain sensory
/// channel and is deliberately not a behavior-trial.v1 qualification trace.
public struct MetalNumanXBehaviorMetricSnapshot: Sendable, Decodable {
  public let schema: String
  public let metricProgramSHA256: String
  public let programFingerprint: UInt64
  public let initialPhysicsGeneration: UInt64
  public let initialTimestampNanoseconds: UInt64
  public let stepNanoseconds: UInt64
  public let endNanoseconds: UInt64
  public let acceptedRootCount: UInt64
  public let rejectedAttemptCount: UInt64
  public let completedAttemptCount: UInt64
  public let metricSampleCount: UInt64
  public let auditCoveredRootCount: UInt64
  public let auditCoveredAttemptCount: UInt64
  public let postureViolationCount: UInt64
  public let settledSuffixSteps: UInt64
  public let speedErrorSampleCount: UInt64
  public let auditViolationCounts: [UInt64]
  public let minimumRootHeightHighLow: [Double]
  public let maximumTrunkTiltHighLow: [Double]
  public let maximumPlanarSpeedHighLow: [Double]
  public let speedSquaredErrorSumHighLow: [Double]
  public let lastTransactionFingerprint: UInt64
  public let lastJointFenceFingerprint: UInt64
  public let initialPostureValid: Bool?
  public let initialSettled: Bool?
  public let forbiddenContactCoverage: String
  public let nativeAuditCoverage: String
  public let genericTaskPackLowering: String
  public let fullBehaviorQualified: Bool
  public let acceptedRootProofSHA256: String?
  public let finalized: Bool

  enum CodingKeys: String, CodingKey {
    case schema
    case metricProgramSHA256 = "metric_program_sha256"
    case programFingerprint = "program_fingerprint"
    case initialPhysicsGeneration = "initial_physics_generation"
    case initialTimestampNanoseconds = "initial_timestamp_ns"
    case stepNanoseconds = "step_ns"
    case endNanoseconds = "end_ns"
    case acceptedRootCount = "accepted_root_count"
    case rejectedAttemptCount = "rejected_attempt_count"
    case completedAttemptCount = "completed_attempt_count"
    case metricSampleCount = "metric_sample_count"
    case auditCoveredRootCount = "audit_covered_root_count"
    case auditCoveredAttemptCount = "audit_covered_attempt_count"
    case postureViolationCount = "posture_violation_count"
    case settledSuffixSteps = "settled_suffix_steps"
    case speedErrorSampleCount = "speed_error_sample_count"
    case auditViolationCounts = "audit_violation_counts"
    case minimumRootHeightHighLow = "minimum_root_height_m_hi_lo"
    case maximumTrunkTiltHighLow = "maximum_trunk_tilt_rad_hi_lo"
    case maximumPlanarSpeedHighLow = "maximum_planar_speed_mps_hi_lo"
    case speedSquaredErrorSumHighLow = "speed_squared_error_sum_hi_lo"
    case lastTransactionFingerprint = "last_transaction_fingerprint"
    case lastJointFenceFingerprint = "last_joint_fence_fingerprint"
    case initialPostureValid = "initial_posture_valid"
    case initialSettled = "initial_settled"
    case forbiddenContactCoverage = "forbidden_contact_coverage"
    case nativeAuditCoverage = "native_audit_coverage"
    case genericTaskPackLowering = "generic_taskpack_lowering"
    case fullBehaviorQualified = "full_behavior_qualified"
    case acceptedRootProofSHA256 = "accepted_root_proof_sha256"
    case finalized
  }

  public static func decode(_ bytes: Data) throws -> Self {
    let value = try JSONDecoder().decode(Self.self, from: bytes)
    let (attempts, overflow) = value.acceptedRootCount.addingReportingOverflow(value.rejectedAttemptCount)
    let (elapsed, elapsedOverflow) = value.acceptedRootCount.multipliedReportingOverflow(by: value.stepNanoseconds)
    let (expectedEnd, clockOverflow) = value.initialTimestampNanoseconds.addingReportingOverflow(elapsed)
    let (_, generationOverflow) = value.initialPhysicsGeneration.addingReportingOverflow(value.acceptedRootCount)
    let pairs = [value.minimumRootHeightHighLow, value.maximumTrunkTiltHighLow,
      value.maximumPlanarSpeedHighLow, value.speedSquaredErrorSumHighLow]
    guard value.schema == "numi.human.accepted-metric-snapshot.v1",
      value.metricProgramSHA256.utf8.count == 64,
      value.metricProgramSHA256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
      value.programFingerprint != 0, !overflow, attempts == value.completedAttemptCount,
      value.metricSampleCount == value.acceptedRootCount,
      value.auditCoveredRootCount == 0, value.auditCoveredAttemptCount == 0,
      value.auditViolationCounts.count == 8, value.auditViolationCounts.allSatisfy({ $0 == 0 }),
      value.postureViolationCount <= value.acceptedRootCount,
      value.settledSuffixSteps <= value.acceptedRootCount,
      value.speedErrorSampleCount == 0 || value.speedErrorSampleCount == value.acceptedRootCount,
      value.stepNanoseconds > 0, !elapsedOverflow, !clockOverflow, !generationOverflow,
      value.endNanoseconds == expectedEnd,
      pairs.allSatisfy({ $0.count == 2 && $0.allSatisfy(\.isFinite) }),
      value.initialPostureValid == nil, value.initialSettled == nil,
      value.forbiddenContactCoverage == "unavailable", value.nativeAuditCoverage == "unavailable",
      value.genericTaskPackLowering == "unavailable", !value.fullBehaviorQualified,
      value.acceptedRootProofSHA256 == nil, value.finalized,
      value.acceptedRootCount == 0 || value.lastTransactionFingerprint != 0 else {
      throw DecodingError.dataCorrupted(.init(codingPath: [],
        debugDescription: "Invalid, incomplete, or falsely promoted native metric snapshot"))
    }
    return value
  }
}

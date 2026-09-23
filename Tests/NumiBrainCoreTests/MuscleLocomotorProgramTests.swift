import Foundation
import XCTest
@testable import NumiBrainCore

final class MuscleLocomotorProgramTests: XCTestCase {
  func fixture() throws -> CompiledSpeciesTemplate {
    let zero = try NumanXBodyLocalPoint(x: 0, y: 0, z: 0)
    let joints = try (UInt32(0)..<122).map { index in
      try NumanXJointTopology(jointIdentifier: index + 1, parentBodyIdentifier: index, childBodyIdentifier: index + 1,
        parentLocalAnchor: zero, childLocalAnchor: zero, restRelativeOrientation: .identity,
        coordinates: [.init(identifier: 0, kind: .angular, kinesthesiaReceptorIndex: index + 6,
          parentLocalAxis: .init(x: 1, y: 0, z: 0), minimumPosition: -1, maximumPosition: 1, restPosition: 0)])
    }
    let topology = try NumanXJointTopologyCatalog(numanXModelFingerprint: 123, bodyCount: 123, joints: joints)
    let attachments = try (UInt32(0)..<416).map {
      try NumanXMuscleAttachment(muscleIdentifier: $0, firstBodyIdentifier: 0, terminalBodyIdentifier: 1,
        routeNodeCount: 2, firstLocalPoint: zero, terminalLocalPoint: zero)
    }
    return try NumanXFullBodyTransportTemplate.compile(anatomy: .init(jointTopologyCatalog: topology,
      muscleAttachmentCatalog: .init(bodyCount: 123, attachments: attachments), headBodyIdentifier: 1))
  }
  func testProgramBindsEveryChannelSourceAndMode() throws {
    let template = try fixture()
    XCTAssertTrue(template.protectiveMotorProfile.channels.allSatisfy {
      $0.restingExcitation == 0 && $0.withdrawalGain == 0 && $0.braceGain == 0
    })
    let channels = (UInt32(0)..<416).map { MuscleLocomotorChannel(muscleIdentifier: $0,
      referenceLengthMeters: 0.25, tonicExcitation: 0.03, lengthGain: 0.4, velocityGainSeconds: 0.02) }
    func program(_ channels: [MuscleLocomotorChannel], source: UInt64 = 123,
      sensor: UInt64? = nil, period: UInt64 = 0) -> MuscleLocomotorProgram {
      .init(modelSourceFingerprint: source, sensoryProfileFingerprint: sensor ?? template.sensoryProfile.fingerprint,
        calibrationArtifactSHA256: String(repeating: "a", count: 64), periodMicroseconds: period, channels: channels)
    }
    let standing = program(channels); try standing.validate(template: template)
    XCTAssertEqual(standing, try JSONDecoder().decode(MuscleLocomotorProgram.self, from: JSONEncoder().encode(standing)))
    XCTAssertNotEqual(standing.fingerprint, program(channels, period: 1_000_000).fingerprint)
    XCTAssertThrowsError(try program(channels, source: 124).validate(template: template))
    XCTAssertThrowsError(try program(channels, sensor: 124).validate(template: template))
    XCTAssertThrowsError(try program(Array(channels.dropLast())).validate(template: template))
    XCTAssertThrowsError(try program(channels.reversed()).validate(template: template))
    XCTAssertThrowsError(try program(channels, period: 1).validate(template: template))
    for invalid in [Float.nan, Float.infinity, -1, 0] {
      var modified = channels
      modified[0] = .init(muscleIdentifier: 0, referenceLengthMeters: invalid,
        tonicExcitation: 0.03, lengthGain: 0.4, velocityGainSeconds: 0.02)
      XCTAssertThrowsError(try program(modified).validate(template: template))
    }
    var saturated = channels
    saturated[0] = .init(muscleIdentifier: 0, referenceLengthMeters: 0.25,
      tonicExcitation: 1, lengthGain: 0, velocityGainSeconds: 0, maximumExcitation: 1)
    XCTAssertNoThrow(try program(saturated).validate(template: template))
    for maximum: Float in [1.0001, .infinity, .nan] {
      saturated[0] = .init(muscleIdentifier: 0, referenceLengthMeters: 0.25,
        tonicExcitation: 1, lengthGain: 0, velocityGainSeconds: 0, maximumExcitation: maximum)
      XCTAssertThrowsError(try program(saturated).validate(template: template))
    }
    var gait = channels
    gait[0] = .init(muscleIdentifier: 0, referenceLengthMeters: 0.25,
      tonicExcitation: 0.03, lengthGain: 0.4, velocityGainSeconds: 0.02, gaitSine: 0.02)
    XCTAssertThrowsError(try program(gait).validate(template: template))
    XCTAssertNoThrow(try program(gait, period: 1_000_000).validate(template: template))
    XCTAssertNotEqual(program(gait, period: 1_000_000).fingerprint, standing.fingerprint)
    XCTAssertThrowsError(try standing.validate(template: NumanXFullBodyTransportTemplate.compile()))
  }

  func testStandaloneDelayedSpindleOnsetIsVersionedBoundAndDecoded() throws {
    let template = try fixture()
    let channels = (UInt32(0)..<416).map {
      MuscleLocomotorChannel(muscleIdentifier: $0, referenceLengthMeters: 0.25,
        tonicExcitation: 0.03, lengthGain: 1, velocityGainSeconds: 0.02,
        maximumExcitation: 1)
    }
    func program(onset: UInt64? = nil, period: UInt64 = 0) -> MuscleLocomotorProgram {
      .init(modelSourceFingerprint: 123,
        sensoryProfileFingerprint: template.sensoryProfile.fingerprint,
        calibrationArtifactSHA256: String(repeating: "a", count: 64),
        epochMicroseconds: 1_000, periodMicroseconds: period, channels: channels,
        spindleFeedbackOnsetMicroseconds: onset)
    }
    let immediate = program(), delayed = program(onset: 102_000)
    try immediate.validate(template: template)
    try delayed.validate(template: template)
    XCTAssertEqual(immediate.version, 1)
    XCTAssertEqual(delayed.version, 3)
    XCTAssertEqual(delayed.baselineFingerprint, immediate.fingerprint)
    XCTAssertNotEqual(delayed.fingerprint, immediate.fingerprint)
    XCTAssertNotEqual(delayed.fingerprint, program(onset: 103_000).fingerprint)
    let oldJSON = try XCTUnwrap(JSONSerialization.jsonObject(
      with: JSONEncoder().encode(immediate)) as? [String: Any])
    XCTAssertNil(oldJSON["spindleFeedbackOnsetMicroseconds"])
    let delayedData = try JSONEncoder().encode(delayed)
    let delayedJSON = try XCTUnwrap(JSONSerialization.jsonObject(
      with: delayedData) as? [String: Any])
    XCTAssertEqual(delayedJSON["spindleFeedbackOnsetMicroseconds"] as? UInt64, 102_000)
    XCTAssertEqual(delayed, try JSONDecoder().decode(MuscleLocomotorProgram.self,
      from: delayedData))
    func checkRejected(_ json: [String: Any]) throws {
      let data = try JSONSerialization.data(withJSONObject: json)
      let candidate = try JSONDecoder().decode(MuscleLocomotorProgram.self, from: data)
      XCTAssertThrowsError(try candidate.validate(template: template))
    }
    var changed = delayedJSON
    changed.removeValue(forKey: "spindleFeedbackOnsetMicroseconds")
    try checkRejected(changed)
    changed = delayedJSON
    changed["spindleFeedbackOnsetMicroseconds"] = 0
    try checkRejected(changed)
    changed["spindleFeedbackOnsetMicroseconds"] = 102_001
    try checkRejected(changed)
    changed = delayedJSON
    changed["version"] = 1
    try checkRejected(changed)
    XCTAssertThrowsError(try program(onset: 102_000, period: 1_000_000)
      .validate(template: template))
  }

  func testJointPathV4IsDistinctAndRequiresExactTonicOnlyProgram() throws {
    let template = try fixture()
    let channels = (UInt32(0)..<416).map {
      MuscleLocomotorChannel(muscleIdentifier: $0, referenceLengthMeters: 0.25,
        tonicExcitation: 0.03, lengthGain: 0, velocityGainSeconds: 0,
        maximumExcitation: 1)
    }
    let feedback = MuscleJointPathFeedbackProgram(lengthGain: 10,
      velocityGainSeconds: 1, maximumCorrection: 0.2)
    func program(_ override: [MuscleLocomotorChannel]? = nil,
      joint: Bool = true,
      invalidFeedback: MuscleJointPathFeedbackProgram? = nil,
      onset: UInt64? = nil) -> MuscleLocomotorProgram {
      MuscleLocomotorProgram(modelSourceFingerprint: 123,
        sensoryProfileFingerprint: template.sensoryProfile.fingerprint,
        calibrationArtifactSHA256: String(repeating: "a", count: 64),
        channels: override ?? channels, spindleFeedbackOnsetMicroseconds: onset,
        jointPathFeedback: joint ? (invalidFeedback ?? feedback) : nil)
    }
    let legacy = program(joint: false)
    let joint = program()
    try legacy.validate(template: template)
    try joint.validate(template: template)
    XCTAssertEqual(legacy.version, 1)
    XCTAssertEqual(joint.version, 4)
    XCTAssertEqual(joint.baselineFingerprint, legacy.fingerprint)
    XCTAssertNotEqual(joint.fingerprint, legacy.fingerprint)
    XCTAssertEqual(joint, try JSONDecoder().decode(MuscleLocomotorProgram.self,
      from: JSONEncoder().encode(joint)))
    let legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(
      with: JSONEncoder().encode(legacy)) as? [String: Any])
    XCTAssertNil(legacyObject["jointPathFeedback"])
    XCTAssertThrowsError(try program(onset: 102_000).validate(template: template))
    for correction: Float in [0, 0.1, .nan] {
      XCTAssertThrowsError(try program(invalidFeedback: .init(lengthGain: 10,
        velocityGainSeconds: 1, maximumCorrection: correction)).validate(template: template))
    }
    var activeSpindle = channels
    activeSpindle[0] = .init(muscleIdentifier: 0,
      referenceLengthMeters: 0.25, tonicExcitation: 0.03,
      lengthGain: 1, velocityGainSeconds: 0.02, maximumExcitation: 1)
    XCTAssertThrowsError(try program(activeSpindle).validate(template: template))
    var limited = channels
    limited[0] = .init(muscleIdentifier: 0,
      referenceLengthMeters: 0.25, tonicExcitation: 0.03,
      lengthGain: 0, velocityGainSeconds: 0, maximumExcitation: 0.95)
    XCTAssertThrowsError(try program(limited).validate(template: template))
  }

  func testJointPathCalibrationRejectsPartialAndNonfiniteSourceValues() throws {
    func calibration(reference: [UInt32], optimal: [UInt32],
      jacobian: [UInt32]) -> MuscleJointPathCalibration {
      .init(referencePositionBitsByDof: reference,
        optimalFiberLengthBitsByMuscle: optimal,
        lengthJacobianBitsByMuscleDof: jacobian)
    }
    let reference = [UInt32](repeating: Float(0).bitPattern, count: 122)
    let optimal = [UInt32](repeating: Float(0.25).bitPattern, count: 416)
    let jacobian = [UInt32](repeating: Float(0).bitPattern, count: 416 * 122)
    let valid = calibration(reference: reference, optimal: optimal, jacobian: jacobian)
    XCTAssertNoThrow(try valid.validate())
    XCTAssertEqual(valid, try JSONDecoder().decode(MuscleJointPathCalibration.self,
      from: JSONEncoder().encode(valid)))
    XCTAssertThrowsError(try calibration(reference: Array(reference.dropLast()),
      optimal: optimal, jacobian: jacobian).validate())
    XCTAssertThrowsError(try calibration(reference: reference,
      optimal: Array(optimal.dropLast()), jacobian: jacobian).validate())
    XCTAssertThrowsError(try calibration(reference: reference,
      optimal: optimal, jacobian: Array(jacobian.dropLast())).validate())
    var invalid = reference; invalid[0] = Float.nan.bitPattern
    XCTAssertThrowsError(try calibration(reference: invalid,
      optimal: optimal, jacobian: jacobian).validate())
    var zeroOptimal = optimal; zeroOptimal[0] = Float(0).bitPattern
    XCTAssertThrowsError(try calibration(reference: reference,
      optimal: zeroOptimal, jacobian: jacobian).validate())
    var infinite = jacobian; infinite[0] = Float.infinity.bitPattern
    XCTAssertThrowsError(try calibration(reference: reference,
      optimal: optimal, jacobian: infinite).validate())
  }
}

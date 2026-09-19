import Foundation
@testable import NumiBrainCore
import XCTest

final class AffectiveStateTests: XCTestCase {
  private func time(_ microseconds: UInt64) -> BrainTimestamp {
    BrainTimestamp(microseconds: microseconds)
  }

  private func physiology(
    interoceptionAt: UInt64? = nil,
    nociceptionAt: UInt64? = nil,
    painEventAt: UInt64? = nil,
    energy: Float? = nil,
    respiration: Float? = nil,
    temperature: Float? = nil,
    fatigue: Float? = nil,
    damage: Float? = nil,
    nociception: Float? = nil,
    painEvent: Float? = nil
  ) throws -> AffectivePhysiologySample {
    try AffectivePhysiologySample(
      interoceptionTimestamp: interoceptionAt.map { time($0) },
      nociceptionTimestamp: nociceptionAt.map { time($0) },
      painEventTimestamp: painEventAt.map { time($0) },
      energyDeficit: energy,
      respiratoryDeficit: respiration,
      temperatureDeviation: temperature,
      fatigue: fatigue,
      tissueDamage: damage,
      nociception: nociception,
      painEvent: painEvent
    )
  }

  func testNeutralInitializationAndFirstObservationDoNotCreatePleasure() throws {
    let neutral = try AffectiveState.neutral(at: time(0))
    XCTAssertEqual(neutral.pain, 0)
    XCTAssertEqual(neutral.pleasure, 0)
    XCTAssertEqual(neutral.relief, 0)
    XCTAssertEqual(neutral.sourceValidityMask, 0)
    XCTAssertEqual(neutral.sourceEvidence, Array(repeating: 0, count: 5))

    let firstObservation = try neutral.advanced(
      to: time(10),
      sample: physiology(
        interoceptionAt: 10,
        energy: 1,
        respiration: 0.8,
        temperature: 0.6,
        fatigue: 0.4,
        damage: 0.2
      )
    )
    XCTAssertEqual(firstObservation.pleasure, 0)
    XCTAssertEqual(firstObservation.relief, 0)
    XCTAssertEqual(firstObservation.sourceValidityMask, 0x1f)
    XCTAssertEqual(firstObservation.previousSampleTimestamp, time(10))
  }

  func testFreshRecoveryCreatesPleasureFromComparableBodilyEvidence() throws {
    let baseline = try AffectiveState.neutral(at: time(0)).advanced(
      to: time(10),
      sample: physiology(
        interoceptionAt: 10,
        energy: 1,
        respiration: 1,
        temperature: 1,
        fatigue: 1,
        damage: 1
      )
    )
    let recovered = try baseline.advanced(
      to: time(20),
      sample: physiology(
        interoceptionAt: 20,
        energy: 0,
        respiration: 0,
        temperature: 0,
        fatigue: 0,
        damage: 0
      )
    )

    XCTAssertEqual(recovered.pleasure, 1, accuracy: 1e-6)
    XCTAssertEqual(recovered.relief, 0)
    XCTAssertEqual(recovered.sourceValidityMask, 0x1f)
  }

  func testFreshNociceptionRaisesPainAndFreshReductionCreatesRelief() throws {
    let painful = try AffectiveState.neutral(at: time(0)).advanced(
      to: time(10),
      sample: physiology(nociceptionAt: 10, nociception: 0.8)
    )
    XCTAssertEqual(painful.pain, 0.8, accuracy: 1e-6)
    XCTAssertEqual(painful.pleasure, 0)
    XCTAssertEqual(painful.relief, 0)

    let relieved = try painful.advanced(
      to: time(20),
      sample: physiology(nociceptionAt: 20, nociception: 0.2)
    )
    XCTAssertGreaterThan(relieved.pain, 0.79)
    XCTAssertEqual(relieved.relief, 0.6, accuracy: 1e-6)
    XCTAssertEqual(relieved.pleasure, 0.6, accuracy: 1e-6)
  }

  func testPainEventsAndFreshTissueDamageRaisePainWithoutCreatingPleasure() throws {
    let neutral = try AffectiveState.neutral(at: time(0))
    let eventPain = try neutral.advanced(
      to: time(10),
      sample: physiology(painEventAt: 10, painEvent: 0.7)
    )
    XCTAssertEqual(eventPain.pain, 0.7, accuracy: 1e-6)
    XCTAssertEqual(eventPain.pleasure, 0)
    XCTAssertEqual(eventPain.relief, 0)
    XCTAssertEqual(eventPain.sourceValidityMask & (1 << 5), 1 << 5)

    let tissuePain = try neutral.advanced(
      to: time(10),
      sample: physiology(interoceptionAt: 10, damage: 0.6)
    )
    XCTAssertEqual(tissuePain.pain, 0.6, accuracy: 1e-6)
    XCTAssertEqual(tissuePain.pleasure, 0)
    XCTAssertEqual(tissuePain.relief, 0)
  }

  func testPainDropoutBreaksReliefComparability() throws {
    let painful = try AffectiveState.neutral(at: time(0)).advanced(
      to: time(10),
      sample: physiology(nociceptionAt: 10, nociception: 0.8)
    )
    let dropout = try painful.advanced(to: time(20), sample: physiology())
    XCTAssertEqual(dropout.previousPainSampleTimestamp, time(10))
    XCTAssertNil(dropout.previousPainObservation)

    let repeatedOldFrame = try dropout.advanced(
      to: time(25),
      sample: physiology(nociceptionAt: 10, nociception: 0.2)
    )
    XCTAssertEqual(repeatedOldFrame.sourceValidityMask, 0)
    XCTAssertEqual(repeatedOldFrame.relief, 0, accuracy: 1e-6)
    XCTAssertNil(repeatedOldFrame.previousPainObservation)

    let returned = try dropout.advanced(
      to: time(30),
      sample: physiology(nociceptionAt: 30, nociception: 0.2)
    )
    XCTAssertEqual(returned.relief, 0, accuracy: 1e-6)
    XCTAssertEqual(returned.pleasure, 0, accuracy: 1e-6)
    XCTAssertGreaterThan(returned.pain, 0.79)
  }

  func testPainAndBodilyRecoveryCanProducePainAndPleasureTogether() throws {
    let baseline = try AffectiveState.neutral(at: time(0)).advanced(
      to: time(10),
      sample: physiology(interoceptionAt: 10, energy: 1)
    )
    let mixed = try baseline.advanced(
      to: time(20),
      sample: physiology(
        interoceptionAt: 20,
        nociceptionAt: 20,
        energy: 0.5,
        nociception: 0.7
      )
    )

    XCTAssertEqual(mixed.pain, 0.7, accuracy: 1e-6)
    XCTAssertEqual(mixed.pleasure, 0.12, accuracy: 1e-6)
    XCTAssertEqual(mixed.relief, 0)
  }

  func testAffectDecaysByPhysicalElapsedTimeWithoutNewEvidence() throws {
    let baseline = try AffectiveState.neutral(at: time(0)).advanced(
      to: time(10),
      sample: physiology(interoceptionAt: 10, nociceptionAt: 10,
        energy: 1, nociception: 0.8)
    )
    let affect = try baseline.advanced(
      to: time(20),
      sample: physiology(interoceptionAt: 20, nociceptionAt: 20,
        energy: 0.5, nociception: 0.4)
    )
    let decayed = try affect.advanced(to: time(1_000_020), sample: physiology())

    XCTAssertEqual(decayed.pain, affect.pain * Float(Foundation.exp(-0.5)), accuracy: 1e-5)
    XCTAssertEqual(decayed.pleasure, affect.pleasure * Float(Foundation.exp(-1.0)), accuracy: 1e-5)
    XCTAssertEqual(decayed.relief, affect.relief * Float(Foundation.exp(-2.0)), accuracy: 1e-5)
    XCTAssertEqual(decayed.sourceValidityMask, 0)
  }

  func testMissingStaleAndRepeatedSamplesCannotCreatePleasure() throws {
    let neutral = try AffectiveState.neutral(at: time(0))
    let missing = try neutral.advanced(to: time(10), sample: physiology())
    XCTAssertEqual(missing.pleasure, 0)
    XCTAssertEqual(missing.sourceValidityMask, 0)
    XCTAssertNil(missing.previousSampleTimestamp)

    let stale = try neutral.advanced(
      to: time(200_000),
      sample: physiology(interoceptionAt: 0, energy: 1)
    )
    XCTAssertEqual(stale.pleasure, 0)
    XCTAssertEqual(stale.sourceValidityMask, 0)
    XCTAssertEqual(stale.previousSourceValidityMask, 0)
    XCTAssertNil(stale.previousSampleTimestamp)

    let baseline = try neutral.advanced(
      to: time(10),
      sample: physiology(interoceptionAt: 10, energy: 1)
    )
    let repeated = try baseline.advanced(
      to: time(20),
      sample: physiology(interoceptionAt: 10, energy: 0)
    )
    XCTAssertEqual(repeated.pleasure, 0)
    XCTAssertEqual(repeated.sourceValidityMask, 0)
    XCTAssertEqual(repeated.previousSampleTimestamp, time(10))

    let afterRepeat = try repeated.advanced(
      to: time(30),
      sample: physiology(interoceptionAt: 30, energy: 0)
    )
    XCTAssertEqual(afterRepeat.pleasure, 0)
  }

  func testConfigurationValidationFingerprintAndStateBinding() throws {
    let reference = AffectiveModelConfiguration.reference
    XCTAssertEqual(try AffectiveModelConfiguration(), reference)
    XCTAssertGreaterThan(reference.fingerprint, 0)

    let changed = try AffectiveModelConfiguration(painDecayMicroseconds: 2_000_001)
    XCTAssertNotEqual(changed.fingerprint, reference.fingerprint)
    XCTAssertThrowsError(try AffectiveModelConfiguration(painDecayMicroseconds: 0))
    XCTAssertThrowsError(try AffectiveModelConfiguration(recoveryGain: 4.1))
    XCTAssertThrowsError(try AffectiveModelConfiguration(sourceWeights: [1, 0, 0, 0]))
    XCTAssertThrowsError(try AffectiveModelConfiguration(sourceWeights: [0.2, 0.2, 0.2, 0.2, 0.1]))

    let bound = try AffectiveState.neutral(at: time(0), configuration: changed)
    XCTAssertEqual(bound.configurationFingerprint, changed.fingerprint)
    XCTAssertThrowsError(
      try bound.advanced(to: time(1), sample: physiology(), configuration: reference)
    )
  }

  func testCausalFingerprintIncludesAffectBaselinesUsedByFutureUpdates() throws {
    let first = try AffectiveState(
      timestamp: time(10),
      pain: 0.5,
      pleasure: 0.2,
      relief: 0,
      sourceValidityMask: 0,
      sourceEvidence: Array(repeating: 0.4, count: 5),
      previousSourceValidityMask: 0,
      previousSampleTimestamp: time(8),
      previousPainSampleTimestamp: time(8),
      previousPainObservation: 0.7,
      configurationFingerprint: AffectiveModelConfiguration.reference.fingerprint
    )
    let differentPainBaseline = try AffectiveState(
      timestamp: time(10),
      pain: first.pain,
      pleasure: first.pleasure,
      relief: first.relief,
      sourceValidityMask: first.sourceValidityMask,
      sourceEvidence: first.sourceEvidence,
      previousSourceValidityMask: first.previousSourceValidityMask,
      previousSampleTimestamp: first.previousSampleTimestamp,
      previousPainSampleTimestamp: first.previousPainSampleTimestamp,
      previousPainObservation: 0.3,
      configurationFingerprint: first.configurationFingerprint
    )
    let differentInteroceptionBaseline = try AffectiveState(
      timestamp: time(10),
      pain: first.pain,
      pleasure: first.pleasure,
      relief: first.relief,
      sourceValidityMask: first.sourceValidityMask,
      sourceEvidence: first.sourceEvidence,
      previousSourceValidityMask: first.previousSourceValidityMask,
      previousSampleTimestamp: time(9),
      previousPainSampleTimestamp: first.previousPainSampleTimestamp,
      previousPainObservation: first.previousPainObservation,
      configurationFingerprint: first.configurationFingerprint
    )

    XCTAssertNotEqual(first.causalFingerprint, differentPainBaseline.causalFingerprint)
    XCTAssertNotEqual(first.causalFingerprint, differentInteroceptionBaseline.causalFingerprint)
  }

  func testDriveHomeostaticReinforcementKeepsInjuryAndRecoverySigned() throws {
    func drives(at timestamp: UInt64, injured: Bool) throws -> DriveState {
      let channels = try DriveKind.allCases.map { kind in
        let affected = injured && (kind == .pain || kind == .injury)
        return try DriveChannelState(
          kind: kind,
          level: affected ? 0 : 1,
          viableMinimum: 1,
          viableMaximum: 1,
          priorityWeight: 1,
          estimatedRate: 0
        )
      }
      return try DriveState(timestamp: time(timestamp), channels: channels)
    }

    let healthy0 = try drives(at: 0, injured: false)
    let injured1 = try drives(at: 1, injured: true)
    let healthy2 = try drives(at: 2, injured: false)
    let injured3 = try drives(at: 3, injured: true)
    let healthy4 = try drives(at: 4, injured: false)

    let firstDeterioration = try healthy0.homeostaticReinforcement(
      successor: injured1, damageCost: 0.25, effortCost: 0
    )
    let firstRecovery = try injured1.homeostaticReinforcement(
      successor: healthy2, damageCost: 0, effortCost: 0
    )
    let secondDeterioration = try healthy2.homeostaticReinforcement(
      successor: injured3, damageCost: 0.25, effortCost: 0
    )
    let secondRecovery = try injured3.homeostaticReinforcement(
      successor: healthy4, damageCost: 0, effortCost: 0
    )

    XCTAssertLessThan(firstDeterioration, 0)
    XCTAssertGreaterThan(firstRecovery, 0)
    XCTAssertLessThan(secondDeterioration, 0)
    XCTAssertGreaterThan(secondRecovery, 0)
    XCTAssertLessThanOrEqual(
      firstDeterioration + firstRecovery + secondDeterioration + secondRecovery,
      0
    )
  }
}

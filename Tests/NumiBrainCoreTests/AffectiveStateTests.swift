import Foundation
@testable import NumiBrainCore
import XCTest

final class AffectiveStateTests: XCTestCase {
  private func time(_ microseconds: UInt64) -> BrainTimestamp {
    BrainTimestamp(microseconds: microseconds)
  }

  func testTypedNumanXSchemaRequiresItsDeclaredFeatureDimension() throws {
    let fingerprint =
      InteroceptiveFeatureSchema.NumanXFullBodyV1.fingerprint
    XCTAssertNoThrow(
      try SensoryTopology(
        modality: .interoception,
        receptorCount: 1,
        observationDimension: 6,
        latencyMicroseconds: 1_000,
        adaptationTimeConstantMicroseconds: 10_000,
        noiseStandardDeviation: 0,
        activeSensingActionDimension: 0,
        enabled: true,
        featureSchemaFingerprint: fingerprint
      )
    )
    XCTAssertThrowsError(
      try SensoryTopology(
        modality: .interoception,
        receptorCount: 1,
        observationDimension: 5,
        latencyMicroseconds: 1_000,
        adaptationTimeConstantMicroseconds: 10_000,
        noiseStandardDeviation: 0,
        activeSensingActionDimension: 0,
        enabled: true,
        featureSchemaFingerprint: fingerprint
      )
    )
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

  func testInvalidPhysiologyEvidenceIsRejectedAtTheBoundary() throws {
    XCTAssertThrowsError(try physiology(interoceptionAt: 10, energy: -0.01))
    XCTAssertThrowsError(try physiology(interoceptionAt: 10, respiration: 1.01))
    XCTAssertThrowsError(try physiology(interoceptionAt: 10, temperature: .infinity))
    XCTAssertThrowsError(try physiology(interoceptionAt: 10, fatigue: .nan))
    XCTAssertThrowsError(try physiology(interoceptionAt: 10, damage: -.infinity))
    XCTAssertThrowsError(
      try physiology(nociceptionAt: 10, nociception: -0.01)
    )
    XCTAssertThrowsError(
      try physiology(painEventAt: 10, painEvent: .infinity)
    )
    XCTAssertThrowsError(try physiology(energy: 0.5))
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

  func testPassiveDecayIsEquivalentAcrossChunking() throws {
    let baseline = try AffectiveState.neutral(at: time(0)).advanced(
      to: time(10),
      sample: physiology(
        interoceptionAt: 10,
        nociceptionAt: 10,
        energy: 1,
        nociception: 0.8
      )
    )
    let seeded = try baseline.advanced(
      to: time(20),
      sample: physiology(
        interoceptionAt: 20,
        nociceptionAt: 20,
        energy: 0.5,
        nociception: 0.2
      )
    )
    XCTAssertGreaterThan(seeded.pain, 0)
    XCTAssertGreaterThan(seeded.pleasure, 0)
    XCTAssertGreaterThan(seeded.relief, 0)

    let target = time(1_000_020)
    let oneStep = try seeded.advanced(to: target, sample: physiology())
    var chunked = seeded
    for timestamp: UInt64 in [20_000, 100_000, 250_000, 500_000, 750_000,
      target.rawValue]
    {
      chunked = try chunked.advanced(to: time(timestamp), sample: physiology())
    }

    XCTAssertEqual(chunked.pain, oneStep.pain, accuracy: 1e-5)
    XCTAssertEqual(chunked.pleasure, oneStep.pleasure, accuracy: 1e-5)
    XCTAssertEqual(chunked.relief, oneStep.relief, accuracy: 1e-5)
    XCTAssertEqual(oneStep.sourceValidityMask, 0)
    XCTAssertEqual(chunked.sourceValidityMask, 0)
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

  func testTimestampedAllInvalidFrameBreaksComparisonAndAdvancesBaseline() throws {
    let neutral = try AffectiveState.neutral(at: time(0))
    let baseline = try neutral.advanced(
      to: time(10),
      sample: physiology(interoceptionAt: 10, energy: 1)
    )
    let allInvalid = try baseline.advanced(
      to: time(20),
      sample: physiology(interoceptionAt: 20)
    )
    XCTAssertEqual(allInvalid.sourceValidityMask, 0)
    XCTAssertEqual(allInvalid.previousSourceValidityMask, 0)
    XCTAssertEqual(allInvalid.previousSampleTimestamp, time(20))

    let olderFrame = try allInvalid.advanced(
      to: time(30),
      sample: physiology(interoceptionAt: 15, energy: 0)
    )
    XCTAssertEqual(olderFrame.sourceValidityMask, 0)
    XCTAssertEqual(olderFrame.pleasure, 0)
    XCTAssertEqual(olderFrame.previousSampleTimestamp, time(20))

    let freshFrame = try olderFrame.advanced(
      to: time(40),
      sample: physiology(interoceptionAt: 40, energy: 0)
    )
    XCTAssertEqual(freshFrame.sourceValidityMask, 1)
    XCTAssertEqual(freshFrame.pleasure, 0)
    XCTAssertEqual(freshFrame.previousSampleTimestamp, time(40))
  }

  func testConfigurationValidationFingerprintAndStateBinding() throws {
    let reference = AffectiveModelConfiguration.reference
    XCTAssertEqual(try AffectiveModelConfiguration(), reference)
    XCTAssertGreaterThan(reference.fingerprint, 0)
    XCTAssertNotEqual(reference.fingerprint, AffectiveModelConfiguration.disabled.fingerprint)
    XCTAssertFalse(AffectiveModelConfiguration.disabled.isEnabled)
    XCTAssertEqual(
      try JSONDecoder().decode(
        AffectiveModelConfiguration.self,
        from: JSONEncoder().encode(reference)
      ),
      reference
    )

    let changed = try AffectiveModelConfiguration(painDecayMicroseconds: 2_000_001)
    XCTAssertNotEqual(changed.fingerprint, reference.fingerprint)
    XCTAssertThrowsError(try AffectiveModelConfiguration(painDecayMicroseconds: 0))
    XCTAssertThrowsError(try AffectiveModelConfiguration(recoveryGain: 4.1))
    XCTAssertThrowsError(try AffectiveModelConfiguration(reliefGain: 4.1))
    XCTAssertThrowsError(try AffectiveModelConfiguration(recoveryGain: -0.01))
    XCTAssertThrowsError(try AffectiveModelConfiguration(reliefGain: -0.01))
    XCTAssertNoThrow(try AffectiveModelConfiguration(recoveryGain: 0, reliefGain: 0))
    XCTAssertNoThrow(try AffectiveModelConfiguration(recoveryGain: 4, reliefGain: 4))
    XCTAssertThrowsError(try AffectiveModelConfiguration(sourceWeights: [1, 0, 0, 0]))
    XCTAssertThrowsError(try AffectiveModelConfiguration(sourceWeights: [0.2, 0.2, 0.2, 0.2, 0.1]))
    let invalidDecodedConfiguration = Data(
      #"{"painDecayMicroseconds":0,"pleasureDecayMicroseconds":1000000,"reliefDecayMicroseconds":500000,"maximumEvidenceAgeMicroseconds":100000,"recoveryGain":1,"reliefGain":1,"sourceWeights":[0.24,0.24,0.16,0.18,0.18]}"#.utf8
    )
    XCTAssertThrowsError(
      try JSONDecoder().decode(
        AffectiveModelConfiguration.self,
        from: invalidDecodedConfiguration
      )
    )

    let legacyConfiguration = Data(
      #"{"painDecayMicroseconds":2000000,"pleasureDecayMicroseconds":1000000,"reliefDecayMicroseconds":500000,"maximumEvidenceAgeMicroseconds":100000,"recoveryGain":1,"reliefGain":1,"sourceWeights":[0.24,0.24,0.16,0.18,0.18]}"#.utf8
    )
    XCTAssertTrue(
      try JSONDecoder().decode(AffectiveModelConfiguration.self, from: legacyConfiguration)
        .isEnabled
    )

    let bound = try AffectiveState.neutral(at: time(0), configuration: changed)
    XCTAssertEqual(bound.configurationFingerprint, changed.fingerprint)
    XCTAssertThrowsError(
      try bound.advanced(to: time(1), sample: physiology(), configuration: reference)
    )
  }

  func testDisabledAffectRemainsNeutralForPainAndRecoveryEvidence() throws {
    let configuration = AffectiveModelConfiguration.disabled
    let baseline = try AffectiveState.neutral(at: time(0), configuration: configuration)
      .advanced(
        to: time(10),
        sample: physiology(
          interoceptionAt: 10,
          nociceptionAt: 10,
          painEventAt: 10,
          energy: 1,
          respiration: 1,
          temperature: 1,
          fatigue: 1,
          damage: 1,
          nociception: 1,
          painEvent: 1
        ),
        configuration: configuration
      )
    let update = try baseline.advanced(
      to: time(20),
      sample: physiology(
        interoceptionAt: 20,
        nociceptionAt: 20,
        painEventAt: 20,
        energy: 0,
        respiration: 0,
        temperature: 0,
        fatigue: 0,
        damage: 0,
        nociception: 0,
        painEvent: 0
      ),
      configuration: configuration
    )

    XCTAssertEqual(update.pain, 0)
    XCTAssertEqual(update.pleasure, 0)
    XCTAssertEqual(update.relief, 0)
    XCTAssertEqual(update.sourceValidityMask, 0)
    XCTAssertEqual(update.sourceEvidence, Array(repeating: 0, count: 5))
    XCTAssertEqual(update.configurationFingerprint, configuration.fingerprint)
  }

  func testPainPleasureAndReliefOutputsSaturateAtUnitUpperBound() throws {
    let configuration = try AffectiveModelConfiguration(
      recoveryGain: 2,
      reliefGain: 2
    )

    // Pain has no configurable gain: maximal fresh nociception, tissue damage,
    // and a pain event each provide a bounded unit signal directly.
    let painful = try AffectiveState.neutral(at: time(0), configuration: configuration)
      .advanced(
        to: time(10),
        sample: physiology(
          interoceptionAt: 10,
          nociceptionAt: 10,
          painEventAt: 10,
          damage: 1,
          nociception: 1,
          painEvent: 1
        ),
        configuration: configuration
      )
    XCTAssertEqual(painful.pain, 1)
    XCTAssertEqual(painful.pleasure, 0)
    XCTAssertEqual(painful.relief, 0)

    // A single unit of fresh homeostatic recovery is amplified by a gain > 1;
    // the reported pleasure remains in the unit interval.
    let depleted = try AffectiveState.neutral(at: time(0), configuration: configuration)
      .advanced(
        to: time(10),
        sample: physiology(
          interoceptionAt: 10,
          energy: 1,
          respiration: 1,
          temperature: 1,
          fatigue: 1,
          damage: 1
        ),
        configuration: configuration
      )
    let recovered = try depleted.advanced(
      to: time(20),
      sample: physiology(
        interoceptionAt: 20,
        energy: 0,
        respiration: 0,
        temperature: 0,
        fatigue: 0,
        damage: 0
      ),
      configuration: configuration
    )
    XCTAssertEqual(recovered.pleasure, 1)
    XCTAssertEqual(recovered.relief, 0)

    // A full reduction in fresh nociception is amplified by reliefGain > 1.
    // The same bounded signal feeds pleasure, which is clamped independently.
    let severePain = try AffectiveState.neutral(at: time(0), configuration: configuration)
      .advanced(
        to: time(10),
        sample: physiology(nociceptionAt: 10, nociception: 1),
        configuration: configuration
      )
    let relieved = try severePain.advanced(
      to: time(20),
      sample: physiology(
        nociceptionAt: 20,
        painEventAt: 20,
        nociception: 0,
        painEvent: 1
      ),
      configuration: configuration
    )
    XCTAssertEqual(relieved.pain, 1)
    XCTAssertEqual(relieved.pleasure, 1)
    XCTAssertEqual(relieved.relief, 1)
  }

  func testZeroRecoveryAndReliefGainsPreserveZeroLowerBound() throws {
    let configuration = try AffectiveModelConfiguration(
      recoveryGain: 0,
      reliefGain: 0
    )
    let depletedAndPainful = try AffectiveState.neutral(
      at: time(0), configuration: configuration
    ).advanced(
      to: time(10),
      sample: physiology(
        interoceptionAt: 10,
        nociceptionAt: 10,
        energy: 1,
        respiration: 1,
        temperature: 1,
        fatigue: 1,
        damage: 1,
        nociception: 1
      ),
      configuration: configuration
    )
    let recoveredAndRelieved = try depletedAndPainful.advanced(
      to: time(20),
      sample: physiology(
        interoceptionAt: 20,
        nociceptionAt: 20,
        energy: 0,
        respiration: 0,
        temperature: 0,
        fatigue: 0,
        damage: 0,
        nociception: 0
      ),
      configuration: configuration
    )

    XCTAssertGreaterThan(recoveredAndRelieved.pain, 0.99)
    XCTAssertEqual(recoveredAndRelieved.pleasure, 0)
    XCTAssertEqual(recoveredAndRelieved.relief, 0)
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

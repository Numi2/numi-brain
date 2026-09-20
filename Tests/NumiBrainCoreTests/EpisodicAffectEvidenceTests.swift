import XCTest

@testable import NumiBrainCore

final class EpisodicAffectEvidenceTests: XCTestCase {
  func testEpisodicRecordEncodesAffectAndRejectsOlderFormat() throws {
    let vector = try BrainLatentVector(values: [0.25, -0.5])
    let reinforcement = try FactoredReinforcement(
      homeostatic: 0, task: 0.2, social: 0, information: 0,
      pain: 0.1, effort: 0, risk: 0
    )
    let outcome = try EpisodicOutcome(
      factoredReinforcement: reinforcement,
      successProbability: 0.5,
      damageSeverity: 0.1,
      terminationCode: 0
    )
    let provenance = try EpisodicProvenance(
      kind: .livedCommitted,
      sourceEpisodeIdentifier: 23,
      parameterVersionFingerprint: 7,
      physicalGeneration: 9
    )
    let affect = try EpisodicAffectEvidence(
      pain: 0.8,
      pleasure: 0.7,
      relief: 0.3,
      sourceEvidence: [0.1, 0.2, 0.3, 0.4, 0.5],
      sourceValidityMask: 0x1f,
      acceptedTimestamp: BrainTimestamp(microseconds: 2_000)
    )
    let record = try EpisodicRecord(
      identifier: 31,
      retrievalKey: vector,
      compressedTrajectory: [vector],
      startTimestamp: BrainTimestamp(microseconds: 1_000),
      endTimestamp: BrainTimestamp(microseconds: 2_000),
      context: vector,
      activeGoalIdentifier: nil,
      optionIdentifiers: [4],
      outcome: outcome,
      epistemicUncertainty: 0.2,
      salience: 0.8,
      redundancy: 0,
      provenance: provenance,
      affectEvidence: affect
    )

    let data = try JSONEncoder().encode(record)
    let decoded = try JSONDecoder().decode(EpisodicRecord.self, from: data)
    XCTAssertEqual(decoded, record)
    XCTAssertEqual(decoded.formatVersion, EpisodicRecord.currentFormatVersion)
    XCTAssertEqual(decoded.affectEvidence.sourceValidityMask, 0x1f)
    XCTAssertEqual(decoded.affectEvidence.acceptedTimestamp?.rawValue, 2_000)
    let outOfEpisodeAffect = try EpisodicAffectEvidence(
      pain: 0.8,
      pleasure: 0.7,
      relief: 0.3,
      sourceEvidence: [0.1, 0.2, 0.3, 0.4, 0.5],
      sourceValidityMask: 0x1f,
      acceptedTimestamp: BrainTimestamp(microseconds: 2_001)
    )
    XCTAssertThrowsError(
      try EpisodicRecord(
        identifier: 32,
        retrievalKey: vector,
        compressedTrajectory: [vector],
        startTimestamp: BrainTimestamp(microseconds: 1_000),
        endTimestamp: BrainTimestamp(microseconds: 2_000),
        context: vector,
        activeGoalIdentifier: nil,
        optionIdentifiers: [4],
        outcome: outcome,
        epistemicUncertainty: 0.2,
        salience: 0.8,
        redundancy: 0,
        provenance: provenance,
        affectEvidence: outOfEpisodeAffect
      )
    )

    var oldObject = try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    oldObject["formatVersion"] = 1
    let oldData = try JSONSerialization.data(withJSONObject: oldObject)
    XCTAssertThrowsError(try JSONDecoder().decode(EpisodicRecord.self, from: oldData))
  }

  func testEpisodicAffectRequiresBoundedSourceEvidenceAndTimestamp() throws {
    XCTAssertThrowsError(
      try EpisodicAffectEvidence(
        pain: 0.2, pleasure: 0.2, relief: 0,
        sourceEvidence: [0, 0, 0, 0, 0],
        sourceValidityMask: 1,
        acceptedTimestamp: nil
      )
    )
    XCTAssertThrowsError(
      try EpisodicAffectEvidence(
        pain: 1.1, pleasure: 0, relief: 0,
        sourceEvidence: [0, 0, 0, 0, 0],
        sourceValidityMask: 1,
        acceptedTimestamp: BrainTimestamp(microseconds: 1)
      )
    )
    XCTAssertThrowsError(
      try EpisodicAffectEvidence(
        pain: 0.2, pleasure: 0, relief: 0,
        sourceEvidence: [0, 0, 0, 0, 0],
        sourceValidityMask: 0,
        acceptedTimestamp: nil
      ),
      "unsourced affect values must use the all-zero unavailable sentinel"
    )
  }
}

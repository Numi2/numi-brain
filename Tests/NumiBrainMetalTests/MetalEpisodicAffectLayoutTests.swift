import Foundation
import XCTest

@testable import NumiBrainCore
@testable import NumiBrainMetal

@available(macOS 26.0, *)
final class MetalEpisodicAffectLayoutTests: XCTestCase {
  func testEpisodeAndWorkspaceLayoutsAreAppendOnlyAndVersioned() {
    XCTAssertEqual(MetalAgentMemoryLayout.recordLayoutVersion, 19)
    XCTAssertEqual(MetalAgentMemoryLayout.activeEpisodeStride, 1_536)
    XCTAssertEqual(MetalAgentMemoryLayout.compressedEpisodeMetadataStride, 192)
    XCTAssertEqual(MetalAgentMemoryLayout.archiveIndexStride, 320)
    XCTAssertEqual(MetalAgentStateLayout.workspaceMetadataStride, 112)
    XCTAssertEqual(MetalLearningBatch.episodicRecordVersion, 3)
    XCTAssertEqual(MetalLearningBatch.formatVersion, 14)
    XCTAssertEqual(MetalArchivePagePayload.currentFormatVersion, 2)
    XCTAssertEqual(
      BrainExecutableModelContract.CommittedTransition.Count.factoredReinforcement,
      8
    )
  }

  func testVersionOneArchivePagePayloadFailsClosed() throws {
    let payload = try MetalArchivePagePayload(
      pageIdentifier: 0,
      sourceGeneration: 1,
      pageEpoch: 1,
      memoryLayoutFingerprint: 7,
      recordLayoutVersion: MetalAgentMemoryLayout.recordLayoutVersion,
      recordStride: UInt32(MetalAgentMemoryLayout.archiveIndexStride),
      recordCount: 1,
      bytes: Data(repeating: 0, count: MetalAgentMemoryLayout.archiveIndexStride)
    )
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(payload))
        as? [String: Any]
    )
    object["formatVersion"] = 1
    let legacyData = try JSONSerialization.data(withJSONObject: object)
    let legacy = try JSONDecoder().decode(MetalArchivePagePayload.self, from: legacyData)
    XCTAssertFalse(legacy.validateChecksum())
  }
}

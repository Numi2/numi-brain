import Foundation
import XCTest
@testable import NumiBrainQualification
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

final class QualificationFileIOTests: XCTestCase {
  private func directory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("qualification-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    addTeardownBlock { try FileManager.default.removeItem(at: url) }
    return url
  }

  func testCreateOnlyNeverOverwritesAndAtomicReplacementPreservesOpenReader() throws {
    let url = try directory(), store = try QualificationFileDirectory(url: url)
    XCTAssertTrue(try store.publish(Data("first".utf8), named: "state"))
    XCTAssertFalse(try store.publish(Data("wrong".utf8), named: "state"))
    let old = try FileHandle(forReadingFrom: url.appendingPathComponent("state"))
    defer { try? old.close() }
    XCTAssertTrue(try store.publish(Data("second".utf8), named: "state", replaceExisting: true))
    XCTAssertEqual(try old.readToEnd(), Data("first".utf8))
    XCTAssertEqual(try store.read("state", maximumBytes: 100), Data("second".utf8))
  }

  func testMissingAndEmptyAreDifferentAndReadsAreBounded() throws {
    let url = try directory(), store = try QualificationFileDirectory(url: url)
    XCTAssertNil(try store.readIfPresent("absent", maximumBytes: 8))
    XCTAssertThrowsError(try store.read("absent", maximumBytes: 8))
    try Data().write(to: url.appendingPathComponent("empty"))
    XCTAssertThrowsError(try store.read("empty", maximumBytes: 8))
    try store.publish(Data(repeating: 1, count: 16), named: "large")
    XCTAssertThrowsError(try store.read("large", maximumBytes: 8))
  }

  func testLeafAndIntermediateSymlinksAreRejected() throws {
    let url = try directory(), store = try QualificationFileDirectory(url: url)
    try store.publish(Data([1]), named: "real")
    try FileManager.default.createSymbolicLink(at: url.appendingPathComponent("alias"),
      withDestinationURL: url.appendingPathComponent("real"))
    XCTAssertThrowsError(try store.read("alias", maximumBytes: 8))
    XCTAssertThrowsError(try store.publish(Data([2]), named: "alias", replaceExisting: true))
    let nested = url.appendingPathComponent("nested")
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: false)
    try FileManager.default.createSymbolicLink(at: url.appendingPathComponent("link"), withDestinationURL: nested)
    XCTAssertThrowsError(try QualificationFileDirectory(url: url.appendingPathComponent("link")))
    XCTAssertEqual(try store.read("real", maximumBytes: 8), Data([1]))
  }

  func testFIFOIsRejectedWithoutWaitingForAWriter() throws {
    let url = try directory(), store = try QualificationFileDirectory(url: url)
    XCTAssertEqual(mkfifo(url.appendingPathComponent("pipe").path, mode_t(0o600)), 0)
    XCTAssertThrowsError(try store.read("pipe", maximumBytes: 8))
  }

  func testNamesCannotEscapeAnchoredDirectory() throws {
    let store = try QualificationFileDirectory(url: directory())
    for name in ["", ".", "..", "../escape", "nested/file", "a\0b"] {
      XCTAssertThrowsError(try store.read(name, maximumBytes: 8))
      XCTAssertThrowsError(try store.publish(Data([1]), named: name))
    }
  }

  func testFailedPublicationPoisonsWriterButDoesNotRemovePreviousState() throws {
    let url = try directory(), store = try QualificationFileDirectory(url: url)
    try store.publish(Data([1]), named: "state")
    try FileManager.default.createDirectory(at: url.appendingPathComponent("not-a-file"), withIntermediateDirectories: false)
    XCTAssertThrowsError(try store.publish(Data([2]), named: "not-a-file", replaceExisting: true))
    XCTAssertThrowsError(try store.publish(Data([3]), named: "state", replaceExisting: true))
    XCTAssertEqual(try store.read("state", maximumBytes: 8), Data([1]))
  }

  func testExclusiveWriterLocksExcludeSecondStoreAndReleaseOnClose() throws {
    let url = try directory()
    let a = try QualificationFileDirectory(url: url), b = try QualificationFileDirectory(url: url)
    let first = try a.acquireExclusiveWriterLock(named: ".writer.lock")
    XCTAssertThrowsError(try b.acquireExclusiveWriterLock(named: ".writer.lock"))
    try first.close()
    let second = try b.acquireExclusiveWriterLock(named: ".writer.lock")
    try second.close()
  }
}

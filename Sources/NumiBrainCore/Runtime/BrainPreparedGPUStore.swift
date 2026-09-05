import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum BrainPreparedResolution: String, Codable, Sendable { case commit, abort }
public struct BrainPreparedGPUDecision: Codable, Equatable, Sendable {
  public let root: BrainPreparedRoot
  public let imageSHA256: String
  public let resolution: BrainPreparedResolution
}

/// Single-writer local filesystem store. Native GPU transfer must complete before persist().
/// Immutable image publication precedes the prepare record; a decision is never overwritten.
/// Undecided means WAIT FOR THE TRANSACTION MANAGER, not rollback or presumed commit.
public actor BrainPreparedGPUStore {
  private struct Header: Codable {
    var version: UInt32
    var root: BrainPreparedRoot
    var decisionFingerprint: UInt64
    var physicsFingerprint: UInt64
    var hotLayout: UInt64
    var memoryLayout: UInt64
    var lengths: [Int]
    var imageSHA256: String
  }
  private struct PrepareRecord: Codable, Equatable {
    var root: BrainPreparedRoot
    var imageSHA256: String
  }
  private let directory: FileHandle
  private let writerLock: FileHandle
  private let maximumBytes: Int
  private var poisoned = false

  public init(directoryURL: URL, maximumBytes: Int = 536_870_912) throws {
    guard directoryURL.isFileURL, maximumBytes > 0, maximumBytes <= 536_870_912,
      !directoryURL.pathComponents.contains("..") else { throw BrainRuntimeError.transaction("prepared store path/budget") }
    var parent = directoryURL
    while parent.path != "/" {
      let values = try parent.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
      guard values.isSymbolicLink != true, values.isDirectory == true else {
        throw BrainRuntimeError.transaction("prepared store requires existing nonsymlink directories")
      }
      parent.deleteLastPathComponent()
    }
    let fd = directoryURL.path.withCString { open($0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW) }
    guard fd >= 0 else { throw BrainRuntimeError.transaction("open prepared-store directory") }
    let directory = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    let lockFD = openat(fd, ".writer.lock", O_RDWR | O_CREAT | O_NOFOLLOW, mode_t(0o600))
    guard lockFD >= 0 else { try? directory.close(); throw BrainRuntimeError.transaction("prepared-store lock") }
    let lock = FileHandle(fileDescriptor: lockFD, closeOnDealloc: true)
    guard flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
      try? lock.close(); try? directory.close()
      throw BrainRuntimeError.transaction("prepared store already has a writer")
    }
    self.directory = directory; self.writerLock = lock; self.maximumBytes = maximumBytes
  }

  @discardableResult public func persist(_ source: BrainPreparedGPUImage) throws -> String {
    try requireUsable()
    let image = try source.validated(maximumBytes: maximumBytes)
    let chunks = [image.baseHotState, image.shadowHotState, image.basePersistentMemory, image.shadowJournal]
    let header = Header(version: 1, root: image.root, decisionFingerprint: image.cachedDecisionFingerprint,
      physicsFingerprint: image.acceptedPhysicsTokenFingerprint, hotLayout: image.hotLayoutFingerprint,
      memoryLayout: image.memoryLayoutFingerprint, lengths: chunks.map(\.count), imageSHA256: image.sha256)
    let headerData = try encode(header)
    guard headerData.count <= 16_384 else { throw BrainRuntimeError.capacity("prepared header") }
    var prefix = Data("NBPIMG01".utf8)
    var size = UInt64(headerData.count).littleEndian
    withUnsafeBytes(of: &size) { prefix.append(contentsOf: $0) }
    let imageName = image.sha256 + ".image"
    if try exists(imageName) {
      guard try loadImage(image.sha256) == image else { throw BrainRuntimeError.transaction("existing prepared image conflicts") }
    } else {
      try publish(name: imageName, chunks: [prefix, headerData] + chunks)
    }
    let record = PrepareRecord(root: image.root, imageSHA256: image.sha256)
    let name = prepareName(image.root.fingerprint)
    if try exists(name) {
      let prior: PrepareRecord = try readJSON(name)
      guard prior == record else { throw BrainRuntimeError.transaction("different candidate already prepared for this root") }
    } else { try publish(name: name, chunks: [encode(record)]) }
    return image.sha256
  }

  public func decide(rootFingerprint: UInt64, imageSHA256: String,
                     resolution: BrainPreparedResolution) throws -> BrainPreparedGPUDecision {
    try requireUsable()
    let prepared: PrepareRecord = try readJSON(prepareName(rootFingerprint))
    guard prepared.root.fingerprint == rootFingerprint, prepared.imageSHA256 == imageSHA256 else {
      throw BrainRuntimeError.transaction("decision does not match durable prepared image")
    }
    _ = try loadImage(imageSHA256) // Verify all bytes before authorizing a recovery action.
    let value = BrainPreparedGPUDecision(root: prepared.root, imageSHA256: imageSHA256, resolution: resolution)
    let name = decisionName(rootFingerprint)
    if try exists(name) {
      let prior: BrainPreparedGPUDecision = try readJSON(name)
      guard prior == value else { throw BrainRuntimeError.transaction("prepared decision is irreversible") }
      return prior
    }
    try publish(name: name, chunks: [encode(value)])
    return value
  }

  public func recover(rootFingerprint: UInt64) throws -> (image: BrainPreparedGPUImage, decision: BrainPreparedGPUDecision?) {
    try requireUsable()
    let record: PrepareRecord = try readJSON(prepareName(rootFingerprint))
    let image = try loadImage(record.imageSHA256)
    guard image.root == record.root, record.root.fingerprint == rootFingerprint else {
      throw BrainRuntimeError.transaction("prepared manifest/root mismatch")
    }
    var decision: BrainPreparedGPUDecision?
    if try exists(decisionName(rootFingerprint)) {
      let found: BrainPreparedGPUDecision = try readJSON(decisionName(rootFingerprint))
      guard found.root == image.root, found.imageSHA256 == image.sha256 else {
        throw BrainRuntimeError.transaction("prepared decision/image mismatch")
      }
      decision = found
    }
    return (image, decision)
  }

  public func loadImage(_ digest: String) throws -> BrainPreparedGPUImage {
    try requireUsable()
    guard digest.utf8.count == 64, digest.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
      throw BrainRuntimeError.transaction("prepared image digest is not lowercase SHA-256")
    }
    let file = try openRead(digest + ".image")
    defer { try? file.close() }
    let fileSize = try file.seekToEnd()
    guard fileSize <= UInt64(maximumBytes) + 16_400 else { throw BrainRuntimeError.capacity("prepared image file") }
    try file.seek(toOffset: 0)
    let prefix = try readExactly(file, 16)
    guard prefix.prefix(8) == Data("NBPIMG01".utf8) else { throw BrainRuntimeError.transaction("prepared file magic") }
    let length = prefix.withUnsafeBytes { UInt64(littleEndian: $0.loadUnaligned(fromByteOffset: 8, as: UInt64.self)) }
    guard length > 0, length <= 16_384 else { throw BrainRuntimeError.capacity("prepared header size") }
    let header = try JSONDecoder().decode(Header.self, from: readExactly(file, Int(length)))
    guard header.version == 1, header.lengths.count == 4, header.imageSHA256 == digest else {
      throw BrainRuntimeError.transaction("prepared header schema/identity")
    }
    var count = 0
    for size in header.lengths {
      guard size > 0, size <= maximumBytes - count else { throw BrainRuntimeError.capacity("prepared section") }
      count += size
    }
    guard fileSize == UInt64(count) + length + 16 else { throw BrainRuntimeError.transaction("truncated or trailing prepared bytes") }
    let data = try header.lengths.map { try readExactly(file, $0) }
    let image = try BrainPreparedGPUImage(root: header.root, cachedDecisionFingerprint: header.decisionFingerprint,
      acceptedPhysicsTokenFingerprint: header.physicsFingerprint, hotLayoutFingerprint: header.hotLayout,
      memoryLayoutFingerprint: header.memoryLayout, baseHotState: data[0], shadowHotState: data[1],
      basePersistentMemory: data[2], shadowJournal: data[3], maximumBytes: maximumBytes)
    guard image.sha256 == digest else { throw BrainRuntimeError.transaction("prepared file digest mismatch") }
    return image
  }

  private func publish(name: String, chunks: [Data]) throws {
    let temporary = ".\(UUID().uuidString).tmp"
    let fd = openat(directory.fileDescriptor, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, mode_t(0o400))
    guard fd >= 0 else { throw BrainRuntimeError.transaction("prepared temporary creation") }
    let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? file.close(); _ = unlinkat(directory.fileDescriptor, temporary, 0) }
    do {
      for chunk in chunks { try file.write(contentsOf: chunk) }
      try file.synchronize()
      #if canImport(Darwin)
      guard fcntl(fd, F_FULLFSYNC) == 0 else { throw BrainRuntimeError.transaction("prepared full file synchronization") }
      #endif
      guard linkat(directory.fileDescriptor, temporary, directory.fileDescriptor, name, 0) == 0 else {
        throw BrainRuntimeError.transaction("prepared immutable publication failed; existing files are never replaced")
      }
      guard fsync(directory.fileDescriptor) == 0 else { throw BrainRuntimeError.transaction("prepared directory synchronization") }
    } catch { poisoned = true; throw error }
  }
  private func openRead(_ name: String) throws -> FileHandle {
    let fd = openat(directory.fileDescriptor, name, O_RDONLY | O_NOFOLLOW)
    guard fd >= 0 else { throw BrainRuntimeError.transaction("prepared file is missing or unsafe") }
    var info = stat()
    guard fstat(fd, &info) == 0, (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else {
      _ = close(fd); throw BrainRuntimeError.transaction("prepared artifact must be regular")
    }
    return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
  }
  private func exists(_ name: String) throws -> Bool {
    var info = stat()
    if fstatat(directory.fileDescriptor, name, &info, AT_SYMLINK_NOFOLLOW) == 0 {
      guard (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { throw BrainRuntimeError.transaction("unsafe prepared artifact") }
      return true
    }
    guard errno == ENOENT else { throw BrainRuntimeError.transaction("prepared artifact inspection failed") }
    return false
  }
  private func readJSON<T: Decodable>(_ name: String) throws -> T {
    let file = try openRead(name); defer { try? file.close() }
    let count = try file.seekToEnd()
    guard count > 0, count <= 16_384 else { throw BrainRuntimeError.capacity("prepared record size") }
    try file.seek(toOffset: 0)
    return try JSONDecoder().decode(T.self, from: readExactly(file, Int(count)))
  }
  private func readExactly(_ file: FileHandle, _ count: Int) throws -> Data {
    var result = Data(); result.reserveCapacity(count)
    while result.count < count {
      guard let next = try file.read(upToCount: min(count - result.count, 1_048_576)), !next.isEmpty else {
        throw BrainRuntimeError.transaction("short prepared-file read")
      }
      result.append(next)
    }
    return result
  }
  private func encode<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
  }
  private func requireUsable() throws {
    guard !poisoned else { throw BrainRuntimeError.transaction("ambiguous store write; close and recover before continuing") }
  }
  private func prepareName(_ root: UInt64) -> String { "\(String(root, radix: 16)).prepared" }
  private func decisionName(_ root: UInt64) -> String { "\(String(root, radix: 16)).decision" }
}

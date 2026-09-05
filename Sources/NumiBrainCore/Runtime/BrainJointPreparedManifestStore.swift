import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public actor BrainJointPreparedManifestStore {
  private let directory: FileHandle
  private let writerLock: FileHandle
  private var poisoned = false

  public init(directoryURL: URL) throws {
    guard directoryURL.isFileURL, !directoryURL.pathComponents.contains("..") else {
      throw BrainRuntimeError.transaction("joint prepared-store path")
    }
    var path = directoryURL
    while path.path != "/" {
      let values = try path.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
      guard values.isDirectory == true, values.isSymbolicLink != true else {
        throw BrainRuntimeError.transaction("joint prepared-store parents must be real directories")
      }
      path.deleteLastPathComponent()
    }
    let fd = directoryURL.path.withCString { open($0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW) }
    guard fd >= 0 else { throw BrainRuntimeError.transaction("open joint prepared-store directory") }
    let directory = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    let lockFD = openat(fd, ".joint-writer.lock", O_RDWR | O_CREAT | O_NOFOLLOW, mode_t(0o600))
    guard lockFD >= 0 else { try? directory.close(); throw BrainRuntimeError.transaction("open joint prepared-store lock") }
    let lock = FileHandle(fileDescriptor: lockFD, closeOnDealloc: true)
    guard flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
      try? lock.close(); try? directory.close()
      throw BrainRuntimeError.transaction("joint prepared store already has a writer")
    }
    self.directory = directory; writerLock = lock
  }

  @discardableResult
  public func prepare(_ source: BrainJointPreparedManifest) throws -> BrainJointPreparedManifest {
    try usable()
    let manifest = try source.validated()
    let name = manifestName(manifest.root.fingerprint)
    if try exists(name) {
      let prior: BrainJointPreparedManifest = try read(name)
      guard try prior.validated() == manifest else {
        throw BrainRuntimeError.transaction("different whole-root manifest is already prepared")
      }
      return prior
    }
    try publish(name, data: try encode(manifest))
    return manifest
  }

  public func decide(rootFingerprint: UInt64, decision: BrainJointPreparedDecision) throws
    -> BrainJointPreparedDecisionRecord {
    try usable()
    let manifest: BrainJointPreparedManifest = try read(manifestName(rootFingerprint))
    guard manifest.root.fingerprint == rootFingerprint else {
      throw BrainRuntimeError.transaction("joint prepared manifest root mismatch")
    }
    let record = try BrainJointPreparedDecisionRecord(manifest: manifest, decision: decision)
    let name = decisionName(rootFingerprint)
    if try exists(name) {
      let prior: BrainJointPreparedDecisionRecord = try read(name)
      guard prior == record else { throw BrainRuntimeError.transaction("whole-root decision is irreversible") }
      return prior
    }
    try publish(name, data: try encode(record))
    return record
  }

  public func recover(rootFingerprint: UInt64) throws
    -> (manifest: BrainJointPreparedManifest, decision: BrainJointPreparedDecisionRecord?) {
    try usable()
    let manifest: BrainJointPreparedManifest = try read(manifestName(rootFingerprint))
    _ = try manifest.validated()
    guard manifest.root.fingerprint == rootFingerprint else { throw BrainRuntimeError.transaction("joint recovery root mismatch") }
    guard try exists(decisionName(rootFingerprint)) else { return (manifest, nil) }
    let decision: BrainJointPreparedDecisionRecord = try read(decisionName(rootFingerprint))
    guard decision.rootFingerprint == rootFingerprint,
      decision.manifestSHA256 == manifest.manifestSHA256,
      decision == (try BrainJointPreparedDecisionRecord(manifest: manifest, decision: decision.decision)) else {
      throw BrainRuntimeError.transaction("joint recovery decision integrity mismatch")
    }
    return (manifest, decision)
  }

  private func publish(_ name: String, data: Data) throws {
    guard data.count > 0, data.count <= 64 * 1024 else { throw BrainRuntimeError.capacity("joint prepared record") }
    let temporary = ".\(UUID().uuidString).tmp"
    let fd = openat(directory.fileDescriptor, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, mode_t(0o400))
    guard fd >= 0 else { throw BrainRuntimeError.transaction("joint prepared temporary file") }
    let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? file.close(); _ = unlinkat(directory.fileDescriptor, temporary, 0) }
    do {
      try file.write(contentsOf: data)
      try file.synchronize()
      #if canImport(Darwin)
      guard fcntl(fd, F_FULLFSYNC) == 0 else { throw BrainRuntimeError.transaction("joint prepared full sync") }
      #endif
      guard linkat(directory.fileDescriptor, temporary, directory.fileDescriptor, name, 0) == 0,
        fsync(directory.fileDescriptor) == 0 else {
        throw BrainRuntimeError.transaction("joint prepared immutable publication")
      }
    } catch { poisoned = true; throw error }
  }

  private func read<T: Decodable>(_ name: String) throws -> T {
    let fd = openat(directory.fileDescriptor, name, O_RDONLY | O_NOFOLLOW)
    guard fd >= 0 else { throw BrainRuntimeError.transaction("joint prepared artifact missing") }
    let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? file.close() }
    var statBuffer = stat()
    guard fstat(fd, &statBuffer) == 0,
      statBuffer.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
      statBuffer.st_size > 0, statBuffer.st_size <= 64 * 1024 else {
      throw BrainRuntimeError.transaction("joint prepared artifact type/size")
    }
    let data = try file.readToEnd() ?? Data()
    return try JSONDecoder().decode(T.self, from: data)
  }

  private func exists(_ name: String) throws -> Bool {
    var statBuffer = stat()
    if fstatat(directory.fileDescriptor, name, &statBuffer, AT_SYMLINK_NOFOLLOW) == 0 {
      guard statBuffer.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
        throw BrainRuntimeError.transaction("unsafe joint prepared artifact")
      }
      return true
    }
    guard errno == ENOENT else { throw BrainRuntimeError.transaction("joint prepared artifact inspection") }
    return false
  }

  private func encode<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
  }

  private func usable() throws {
    guard !poisoned else { throw BrainRuntimeError.transaction("ambiguous whole-root store write; reopen before continuing") }
  }

  private func manifestName(_ root: UInt64) -> String { "\(String(root, radix: 16)).joint-prepared" }
  private func decisionName(_ root: UInt64) -> String { "\(String(root, radix: 16)).joint-decision" }
}

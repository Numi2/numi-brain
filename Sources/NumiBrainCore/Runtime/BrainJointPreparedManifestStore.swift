import Foundation
import CryptoKit
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// File-backed whole-root authority. A manifest containing plausible SHA-256 strings is not enough:
/// every participant payload must already exist in this locked store and verify byte-for-byte.
/// Storage integrity does not authenticate the native producer or authorize physical stimulation.
public actor BrainJointPreparedManifestStore {
  private let directory: FileHandle
  private let writerLock: FileHandle
  private let maximumParticipantBytes: UInt64
  private let maximumRootBytes: UInt64
  private var poisoned = false
  private var closed = false

  public init(directoryURL: URL, maximumParticipantBytes: UInt64 = 1_073_741_824,
    maximumRootBytes: UInt64 = 2_147_483_648) throws {
    guard directoryURL.isFileURL, !directoryURL.pathComponents.contains(".."),
      maximumParticipantBytes > 0, maximumParticipantBytes <= 1_073_741_824,
      maximumRootBytes >= maximumParticipantBytes, maximumRootBytes <= 4_294_967_296 else {
      throw BrainRuntimeError.transaction("joint prepared-store path or byte budgets")
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
    let lockFD = openat(fd, ".joint-writer.lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_NONBLOCK, mode_t(0o600))
    guard lockFD >= 0 else { try? directory.close(); throw BrainRuntimeError.transaction("open joint prepared-store lock") }
    let lock = FileHandle(fileDescriptor: lockFD, closeOnDealloc: true)
    var lockInfo = stat()
    guard fstat(lockFD, &lockInfo) == 0,
      lockInfo.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
      flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
      try? lock.close(); try? directory.close()
      throw BrainRuntimeError.transaction("joint prepared store lock is unsafe or already held")
    }
    self.directory = directory; writerLock = lock
    self.maximumParticipantBytes = maximumParticipantBytes; self.maximumRootBytes = maximumRootBytes
  }

  public func close() throws {
    guard !closed else { return }
    closed = true
    var failure: Error?
    do { try writerLock.close() } catch { failure = error }
    do { try directory.close() } catch { if failure == nil { failure = error } }
    if let failure { throw failure }
  }

  @discardableResult
  public func storeParticipant(_ source: BrainPreparedParticipantArtifact, bytes: Data) throws -> String {
    try usable()
    let artifact = try source.validated()
    guard artifact.payloadBytes <= maximumParticipantBytes,
      artifact.payloadBytes == UInt64(bytes.count), sha256(bytes) == artifact.payloadSHA256 else {
      throw BrainRuntimeError.transaction("participant payload byte count or SHA-256 mismatch")
    }
    let name = payloadName(artifact.payloadSHA256)
    if try exists(name) {
      try verifyParticipant(artifact)
    } else {
      try publish(name, data: bytes, maximumBytes: maximumParticipantBytes)
    }
    return artifact.payloadSHA256
  }

  /// Old digest-only records require their exact payload bytes before prepare/decide/recover.
  /// Never synthesize missing native state to make an older manifest pass verification.
  @discardableResult
  public func prepare(_ source: BrainJointPreparedManifest) throws -> BrainJointPreparedManifest {
    try usable()
    let manifest = try source.validated()
    try verifyParticipants(manifest)
    let name = manifestName(manifest.root.fingerprint)
    if try exists(name) {
      let prior: BrainJointPreparedManifest = try readRecord(name)
      guard try prior.validated() == manifest else {
        throw BrainRuntimeError.transaction("different whole-root manifest is already prepared")
      }
      return prior
    }
    try publish(name, data: try encode(manifest), maximumBytes: 65_536)
    return manifest
  }

  public func decide(rootFingerprint: UInt64, decision: BrainJointPreparedDecision) throws
    -> BrainJointPreparedDecisionRecord {
    try usable()
    let manifest: BrainJointPreparedManifest = try readRecord(manifestName(rootFingerprint))
    _ = try manifest.validated()
    guard manifest.root.fingerprint == rootFingerprint else {
      throw BrainRuntimeError.transaction("joint prepared manifest root mismatch")
    }
    if decision == .commit { try verifyParticipants(manifest) }
    let record = try BrainJointPreparedDecisionRecord(manifest: manifest, decision: decision)
    let name = decisionName(rootFingerprint)
    if try exists(name) {
      let prior: BrainJointPreparedDecisionRecord = try readRecord(name)
      guard prior == record else { throw BrainRuntimeError.transaction("whole-root decision is irreversible") }
      return prior
    }
    try publish(name, data: try encode(record), maximumBytes: 65_536)
    return record
  }

  public func recover(rootFingerprint: UInt64) throws
    -> (manifest: BrainJointPreparedManifest, decision: BrainJointPreparedDecisionRecord?) {
    try usable()
    let manifest: BrainJointPreparedManifest = try readRecord(manifestName(rootFingerprint))
    _ = try manifest.validated()
    guard manifest.root.fingerprint == rootFingerprint else { throw BrainRuntimeError.transaction("joint recovery root mismatch") }
    var decision: BrainJointPreparedDecisionRecord?
    if try exists(decisionName(rootFingerprint)) {
      let value: BrainJointPreparedDecisionRecord = try readRecord(decisionName(rootFingerprint))
      guard value == (try BrainJointPreparedDecisionRecord(manifest: manifest, decision: value.decision)) else {
        throw BrainRuntimeError.transaction("joint recovery decision integrity mismatch")
      }
      decision = value
    }
    // An explicit abort remains inspectable even when damaged candidate files cannot be restored.
    // Undecided and committed roots still require all exact bytes. Absent decision never means abort.
    if decision?.decision != .abort { try verifyParticipants(manifest) }
    return (manifest, decision)
  }

  public func participantBytes(rootFingerprint: UInt64, kind: BrainPreparedParticipantKind) throws -> Data {
    try usable()
    let manifest: BrainJointPreparedManifest = try readRecord(manifestName(rootFingerprint))
    _ = try manifest.validated()
    guard manifest.root.fingerprint == rootFingerprint,
      let artifact = manifest.participants.first(where: { $0.kind == kind }) else {
      throw BrainRuntimeError.transaction("participant does not belong to this root")
    }
    return try readParticipant(artifact)
  }

  private func verifyParticipants(_ manifest: BrainJointPreparedManifest) throws {
    var total: UInt64 = 0
    for artifact in manifest.participants {
      guard artifact.payloadBytes <= maximumRootBytes - total else { throw BrainRuntimeError.capacity("joint root payload budget") }
      total += artifact.payloadBytes
      try verifyParticipant(artifact)
    }
  }

  private func verifyParticipant(_ artifact: BrainPreparedParticipantArtifact) throws {
    _ = try artifact.validated()
    guard artifact.payloadBytes <= maximumParticipantBytes else { throw BrainRuntimeError.capacity("participant payload") }
    let file = try openRegular(payloadName(artifact.payloadSHA256), maximumBytes: maximumParticipantBytes,
      expectedBytes: artifact.payloadBytes)
    defer { try? file.close() }
    var hash = SHA256(), count: UInt64 = 0
    while count < artifact.payloadBytes {
      let requested = Int(min(1_048_576, artifact.payloadBytes - count))
      guard let chunk = try file.read(upToCount: requested), !chunk.isEmpty else {
        throw BrainRuntimeError.transaction("truncated participant payload")
      }
      hash.update(data: chunk); count += UInt64(chunk.count)
    }
    guard (try file.read(upToCount: 1) ?? Data()).isEmpty,
      hash.finalize().map({ String(format: "%02x", $0) }).joined() == artifact.payloadSHA256 else {
      throw BrainRuntimeError.transaction("participant payload has trailing bytes or SHA-256 mismatch")
    }
  }

  private func readParticipant(_ source: BrainPreparedParticipantArtifact) throws -> Data {
    let artifact = try source.validated()
    guard artifact.payloadBytes <= maximumParticipantBytes, artifact.payloadBytes <= UInt64(Int.max) else {
      throw BrainRuntimeError.capacity("participant payload")
    }
    let file = try openRegular(payloadName(artifact.payloadSHA256), maximumBytes: maximumParticipantBytes,
      expectedBytes: artifact.payloadBytes)
    defer { try? file.close() }
    let data = try readExactly(file, count: Int(artifact.payloadBytes))
    guard (try file.read(upToCount: 1) ?? Data()).isEmpty, sha256(data) == artifact.payloadSHA256 else {
      throw BrainRuntimeError.transaction("participant changed while reading")
    }
    return data
  }

  private func publish(_ name: String, data: Data, maximumBytes: UInt64) throws {
    guard !data.isEmpty, UInt64(data.count) <= maximumBytes else { throw BrainRuntimeError.capacity("joint prepared record") }
    let temporary = ".\(UUID().uuidString).tmp"
    let fd = openat(directory.fileDescriptor, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, mode_t(0o400))
    guard fd >= 0 else { throw BrainRuntimeError.transaction("joint prepared temporary file") }
    let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? file.close(); _ = unlinkat(directory.fileDescriptor, temporary, 0) }
    do {
      var offset = 0
      while offset < data.count {
        let end = min(data.count, offset + 1_048_576)
        try file.write(contentsOf: data.subdata(in: offset..<end)); offset = end
      }
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

  private func openRegular(_ name: String, maximumBytes: UInt64, expectedBytes: UInt64? = nil) throws -> FileHandle {
    // O_NONBLOCK avoids blocking on a substituted FIFO before fstat can reject its type.
    let fd = openat(directory.fileDescriptor, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
    guard fd >= 0 else { throw BrainRuntimeError.transaction("joint prepared artifact missing or unsafe") }
    let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    var info = stat()
    guard fstat(fd, &info) == 0, info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
      info.st_size > 0, UInt64(info.st_size) <= maximumBytes,
      expectedBytes.map({ $0 == UInt64(info.st_size) }) ?? true else {
      try? file.close()
      throw BrainRuntimeError.transaction("joint prepared artifact type/size")
    }
    return file
  }

  private func readRecord<T: Decodable>(_ name: String) throws -> T {
    let file = try openRegular(name, maximumBytes: 65_536)
    defer { try? file.close() }
    let count = try file.seekToEnd()
    // A file can grow between fstat and seek. Recheck before Int conversion/allocation.
    guard count > 0, count <= 65_536 else {
      throw BrainRuntimeError.capacity("joint metadata changed size before reading")
    }
    try file.seek(toOffset: 0)
    let data = try readExactly(file, count: Int(count))
    guard (try file.read(upToCount: 1) ?? Data()).isEmpty else { throw BrainRuntimeError.transaction("record grew during read") }
    return try JSONDecoder().decode(T.self, from: data)
  }

  private func readExactly(_ file: FileHandle, count: Int) throws -> Data {
    guard count > 0, UInt64(count) <= max(maximumParticipantBytes, 65_536) else {
      throw BrainRuntimeError.capacity("joint artifact read budget")
    }
    var result = Data(); result.reserveCapacity(count)
    while result.count < count {
      guard let bytes = try file.read(upToCount: min(1_048_576, count - result.count)), !bytes.isEmpty else {
        throw BrainRuntimeError.transaction("truncated joint artifact")
      }
      result.append(bytes)
    }
    return result
  }
  private func exists(_ name: String) throws -> Bool {
    var info = stat()
    if fstatat(directory.fileDescriptor, name, &info, AT_SYMLINK_NOFOLLOW) == 0 {
      guard info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
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
  private func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
  private func usable() throws {
    guard !closed, !poisoned else { throw BrainRuntimeError.transaction("closed or ambiguous whole-root store; reopen before continuing") }
  }
  private func manifestName(_ root: UInt64) -> String { "\(String(root, radix: 16)).joint-prepared" }
  private func decisionName(_ root: UInt64) -> String { "\(String(root, radix: 16)).joint-decision" }
  private func payloadName(_ sha: String) -> String { "\(sha).joint-payload" }
}

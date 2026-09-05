import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public enum QualificationFileError: Error, Equatable, Sendable {
  case invalidPath
  case missing(String)
  case unsafe(String)
  case sizeLimit
  case systemCall(String, Int32)
}

/// Bounded off-rollout artifact I/O. Paths are walked using directory handles;
/// no component or leaf may be a symlink. Callers must supply an existing,
/// absolute, resolved directory (for example /private/tmp on macOS).
/// This type is not a production stepping or GPU synchronization primitive.
public final class QualificationFileDirectory: @unchecked Sendable {
  private let directory: FileHandle
  private let lock = NSLock()
  private var poisoned = false

  public init(url: URL) throws {
    guard url.isFileURL, url.path.hasPrefix("/"), !url.path.utf8.contains(0) else {
      throw QualificationFileError.invalidPath
    }
    let components = url.path.split(separator: "/").map(String.init)
    guard components.allSatisfy({ $0 != "." && $0 != ".." }) else {
      throw QualificationFileError.invalidPath
    }
    var fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
    guard fd >= 0 else { throw QualificationFileError.systemCall("open directory", errno) }
    do {
      for component in components {
        let next = openat(fd, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard next >= 0 else { throw QualificationFileError.systemCall("open directory component", errno) }
        _ = close(fd); fd = next
      }
    } catch { _ = close(fd); throw error }
    directory = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
  }

  public func read(_ name: String, maximumBytes: Int) throws -> Data {
    guard let bytes = try readIfPresent(name, maximumBytes: maximumBytes) else {
      throw QualificationFileError.missing(name)
    }
    return bytes
  }

  public func readIfPresent(_ name: String, maximumBytes: Int) throws -> Data? {
    try Self.validateName(name)
    guard maximumBytes > 0, maximumBytes <= 536_870_912 else { throw QualificationFileError.sizeLimit }
    // O_NONBLOCK ensures that a malicious FIFO cannot block before fstat.
    let fd = openat(directory.fileDescriptor, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
    if fd < 0 {
      if errno == ENOENT { return nil }
      throw QualificationFileError.systemCall("open artifact", errno)
    }
    let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? file.close() }
    var info = stat()
    guard fstat(fd, &info) == 0 else { throw QualificationFileError.systemCall("stat artifact", errno) }
    guard (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { throw QualificationFileError.unsafe(name) }
    guard info.st_size > 0, info.st_size <= maximumBytes else { throw QualificationFileError.sizeLimit }
    let count = Int(info.st_size)
    var data = Data(); data.reserveCapacity(count)
    while data.count < count {
      guard let part = try file.read(upToCount: min(count - data.count, 1_048_576)), !part.isEmpty else {
        throw QualificationFileError.unsafe("truncated artifact: " + name)
      }
      data.append(part)
    }
    let tail = try file.read(upToCount: 1)
    var after = stat()
    guard tail?.isEmpty != false, fstat(fd, &after) == 0, after.st_size == info.st_size else {
      throw QualificationFileError.unsafe("artifact changed while reading: " + name)
    }
    return data
  }

  /// Atomically publishes all bytes. With replaceExisting=false, an existing
  /// regular file is never overwritten and false is returned; the caller must
  /// compare its contents before considering an operation idempotent.
  /// An ambiguous write/sync failure poisons this writer until it is reopened.
  @discardableResult
  public func publish(_ data: Data, named name: String, replaceExisting: Bool = false,
                      durable: Bool = true) throws -> Bool {
    try Self.validateName(name)
    guard !data.isEmpty, data.count <= 536_870_912 else { throw QualificationFileError.sizeLimit }
    lock.lock(); defer { lock.unlock() }
    guard !poisoned else { throw QualificationFileError.unsafe("writer requires recovery after a failed publication") }
    let temporary = ".qualification-\(UUID().uuidString).tmp"
    let fd = openat(directory.fileDescriptor, temporary,
      O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode_t(0o600))
    guard fd >= 0 else { throw QualificationFileError.systemCall("create temporary", errno) }
    let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? file.close(); _ = unlinkat(directory.fileDescriptor, temporary, 0) }
    do {
      try file.write(contentsOf: data)
      if durable {
        try file.synchronize()
        #if canImport(Darwin)
        guard fcntl(fd, F_FULLFSYNC) == 0 else { throw QualificationFileError.systemCall("full file sync", errno) }
        #endif
      }
      var existing = stat()
      let present = fstatat(directory.fileDescriptor, name, &existing, AT_SYMLINK_NOFOLLOW)
      if present == 0 {
        guard (existing.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { throw QualificationFileError.unsafe(name) }
        if !replaceExisting { return false }
      } else if errno != ENOENT {
        throw QualificationFileError.systemCall("stat destination", errno)
      }
      if replaceExisting {
        // renameat replaces the directory entry atomically. Never unlink the
        // old generation first; readers retain either the old or the new file.
        guard renameat(directory.fileDescriptor, temporary, directory.fileDescriptor, name) == 0 else {
          throw QualificationFileError.systemCall("atomic replacement", errno)
        }
      } else if linkat(directory.fileDescriptor, temporary, directory.fileDescriptor, name, 0) != 0 {
        if errno == EEXIST {
          var raced = stat()
          guard fstatat(directory.fileDescriptor, name, &raced, AT_SYMLINK_NOFOLLOW) == 0,
            (raced.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { throw QualificationFileError.unsafe(name) }
          return false
        }
        throw QualificationFileError.systemCall("create-only publication", errno)
      }
      if durable, fsync(directory.fileDescriptor) != 0 {
        throw QualificationFileError.systemCall("directory sync", errno)
      }
      return true
    } catch { poisoned = true; throw error }
  }

  public static func readFile(_ url: URL, maximumBytes: Int) throws -> Data {
    try QualificationFileDirectory(url: url.deletingLastPathComponent())
      .read(url.lastPathComponent, maximumBytes: maximumBytes)
  }

  public static func canonicalJSON<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
  }

  private static func validateName(_ name: String) throws {
    guard !name.isEmpty, name != ".", name != "..", name.utf8.count <= 255,
      !name.contains("/"), !name.utf8.contains(0) else { throw QualificationFileError.invalidPath }
  }
}

import Foundation

extension BrainPreparedGPUImage {
  /// Recovery-only byte materialization, not a neural stepping path. The owning Metal recovery
  /// layer must verify the durable whole-root COMMIT decision before calling this package method.
  /// NBAgentMemoryMutation is 64 bytes: destination[0:8], generation[8:16], payload[16:32],
  /// byteCount[32:36], section[36:40], sequence/flags[40:48], recordID/reserved[48:64].
  /// The record identifier at offset 48 is NOT the mutation payload.
  package func materializedCommittedMemory() throws -> Data {
    _ = try validated()
    let count = shadowJournal.withUnsafeBytes {
      UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self))
    }
    var result = basePersistentMemory
    for index in 0..<Int(count) {
      let record = 48 + index * 64
      let destination = shadowJournal.withUnsafeBytes {
        UInt64(littleEndian: $0.loadUnaligned(fromByteOffset: record, as: UInt64.self))
      }
      let length = shadowJournal.withUnsafeBytes {
        UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: record + 32, as: UInt32.self))
      }
      // validated() checked generation, alignment, capacity, overlap and destination bounds.
      guard destination <= UInt64(Int.max), destination <= UInt64(result.count),
        UInt64(length) <= UInt64(result.count) - destination else {
        throw BrainRuntimeError.transaction("native journal destination is not host-representable")
      }
      let start = Int(destination), end = start + Int(length)
      let payload = shadowJournal.subdata(in: (record + 16)..<(record + 16 + Int(length)))
      result.replaceSubrange(start..<end, with: payload)
    }
    return result
  }
}

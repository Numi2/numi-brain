import Foundation

/// Deterministic three-node fixture, built from semantic values rather than an
/// opaque base64 literal. Matches tools/test_connectome_native.py byte for byte.
public enum ConnectomeTestFixture {
  public static func data() -> Data {
    var ids = Data(), nodes = Data(), offsets = Data(), sources = Data(), weights = Data()
    for (id, flag) in [(UInt32(10), UInt32(1)), (20, 4), (30, 8)] {
      ids.appendLE(UInt64(id))
      for value: Float in [0.2, 0, 1, 1, 1, 8, 0, 0] { nodes.appendLE(value.bitPattern) }
      for value in [id, 0, flag, 0] { nodes.appendLE(value) }
    }
    for value: UInt32 in [0, 0, 1, 2] { offsets.appendLE(value) }
    for value: UInt32 in [0, 1] { sources.appendLE(value) }
    for value: Float in [1, -1] { weights.appendLE(value.bitPattern) }
    let labels = ["sensory", "interneuron", "descending"].map { Data($0.utf8) }
    var labelData = Data(), position: UInt32 = 0
    labelData.appendLE(position)
    for label in labels { position += UInt32(label.count); labelData.appendLE(position) }
    for label in labels { labelData.append(label) }
    let manifest = Data("{\"source\": \"native-regression\", \"synthetic\": true}".utf8)
    var payload = Data()
    payload.appendLE(UInt32(1)); payload.appendLE(UInt32(0))
    for value: UInt64 in [123, 3, 2] { payload.appendLE(value) }
    for section in [ids, nodes, offsets, sources, weights] { payload.append(section) }
    for label in labels { payload.appendLE(UInt64(label.count)); payload.append(label) }
    payload.appendLE(UInt64(manifest.count)); payload.append(manifest)
    var fingerprint: UInt64 = 14_695_981_039_346_656_037
    for byte in payload { fingerprint ^= UInt64(byte); fingerprint &*= 1_099_511_628_211 }
    if fingerprint == 0 { fingerprint = 1 }
    var data = Data(repeating: 0, count: 256), starts: [UInt64] = []
    for section in [ids, nodes, offsets, sources, weights, labelData, manifest] {
      data.append(Data(repeating: 0, count: (64-data.count%64)%64))
      starts.append(UInt64(data.count)); data.append(section)
    }
    let words: [UInt64] = [3, 2, fingerprint, 123] + Array(starts.prefix(5))
      + [starts[5], UInt64(labelData.count), starts[6], UInt64(manifest.count), UInt64(data.count)]
      + Array(repeating: 0, count: 15)
    var header = Data("NUMICNS1".utf8)
    for value: UInt32 in [256, 1, 0, 0] { header.appendLE(value) }
    for word in words { header.appendLE(word) }
    precondition(header.count == 256)
    data.replaceSubrange(0..<256, with: header)
    return data
  }
}

private extension Data {
  mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
    var little = value.littleEndian
    Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
  }
}

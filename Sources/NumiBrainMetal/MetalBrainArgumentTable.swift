@preconcurrency import Metal

/// Records the same argument bindings for Metal 4 and a borrowed native encoder.
/// Addresses are resolved only against the caller's retained allocation leases.
@available(macOS 26.0, *)
final class MetalBrainArgumentTable {
  let metal4: any MTL4ArgumentTable
  private(set) var bindings: [Int: UInt64] = [:]

  init(_ metal4: any MTL4ArgumentTable) { self.metal4 = metal4 }

  func setAddress(_ address: UInt64, index: Int) {
    bindings[index] = address
    metal4.setAddress(address, index: index)
  }
}

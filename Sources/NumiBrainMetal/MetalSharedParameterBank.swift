import Foundation
@preconcurrency import Metal
import NumiBrainCore

/// Device-visible immutable slow weights for one exact parameter version.
/// Per-agent state never enters these buffers; a successor version creates a
/// new bank instead of mutating the bank owned by an active rollout cohort.
@available(macOS 26.0, *)
public final class MetalSharedParameterBank: @unchecked Sendable {
  public let parameterVersionFingerprint: UInt64
  public let artifactFingerprint: UInt64

  private let buffers: [BrainParameterComponentKind: any MTLBuffer]
  private let scalarCounts: [BrainParameterComponentKind: Int]

  public init(
    device: any MTLDevice,
    parameterVersion: BrainParameterVersion,
    artifact requestedArtifact: BrainSharedParameterArtifact? = nil
  ) throws {
    let artifact = try requestedArtifact
      ?? BrainSharedParameterArtifact.foundation(parameterVersion: parameterVersion)
    guard artifact.parameterVersionFingerprint == parameterVersion.fingerprint else {
      throw TissueError.metal("shared parameter artifact version mismatch")
    }
    try artifact.validate(parameterVersion: parameterVersion)
    var buffers: [BrainParameterComponentKind: any MTLBuffer] = [:]
    var scalarCounts: [BrainParameterComponentKind: Int] = [:]
    for payload in artifact.payloads {
      guard payload.elementType == .fp32,
        payload.data.count % MemoryLayout<Float>.stride == 0,
        let buffer = device.makeBuffer(
          length: payload.data.count,
          options: [.storageModeShared, .hazardTrackingModeTracked]
        )
      else {
        throw TissueError.metal(
          "shared parameter component \(payload.kind) is not executable FP32"
        )
      }
      payload.data.withUnsafeBytes { bytes in
        guard let source = bytes.baseAddress else { return }
        buffer.contents().copyMemory(from: source, byteCount: bytes.count)
      }
      buffer.label = "NumiBrain immutable \(payload.kind) parameters"
      buffers[payload.kind] = buffer
      scalarCounts[payload.kind] = payload.data.count / MemoryLayout<Float>.stride
    }
    self.parameterVersionFingerprint = parameterVersion.fingerprint
    self.artifactFingerprint = artifact.artifactFingerprint
    self.buffers = buffers
    self.scalarCounts = scalarCounts
  }

  public func gpuAddress(
    _ kind: BrainParameterComponentKind,
    minimumScalarCount: Int
  ) throws -> UInt64 {
    guard let buffer = buffers[kind],
      let scalarCount = scalarCounts[kind], scalarCount >= minimumScalarCount
    else {
      throw TissueError.metal("shared parameter component \(kind) is undersized")
    }
    return buffer.gpuAddress
  }

  public func scalarCount(_ kind: BrainParameterComponentKind) -> Int {
    scalarCounts[kind] ?? 0
  }

  public var residencyAllocations: [any MTLAllocation] {
    BrainSharedParameterArtifact.requiredKinds.compactMap { buffers[$0] }
  }
}

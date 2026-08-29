import Foundation
@preconcurrency import Metal
import NumiBrainCore

/// Runtime-ready immutable slow parameters for one registry-owned rollout
/// cohort. Construction allocates a new Metal bank from the exact bytes in the
/// publication; it never reuses or mutates buffers owned by the parent cohort.
@available(macOS 26.0, *)
public final class MetalParameterCohort: @unchecked Sendable {
  public let binding: BrainRolloutCohortBinding
  public let sharedParameterBank: MetalSharedParameterBank
  public let deviceRegistryID: UInt64

  public var publication: BrainParameterPublication { binding.publication }
  public var lease: BrainRolloutCohortLease { binding.lease }
  public var parameterVersion: BrainParameterVersion { publication.version }

  public init(
    device: any MTLDevice,
    binding: BrainRolloutCohortBinding
  ) throws {
    let bank = try MetalSharedParameterBank(
      device: device,
      publication: binding.publication
    )
    guard bank.parameterVersionFingerprint == binding.lease.parameterFingerprint else {
      throw TissueError.metal("Metal parameter bank does not match its cohort lease")
    }
    self.binding = binding
    self.sharedParameterBank = bank
    self.deviceRegistryID = device.registryID
  }

  /// Refuses to associate a complete runtime with a stale lease or a bank
  /// materialized on another Apple GPU.
  public func validate(runtime: MetalNumiBrainRuntime) throws {
    guard runtime.deviceRegistryID == deviceRegistryID,
      runtime.parameterVersionFingerprint == lease.parameterFingerprint,
      runtime.cognitive.sharedParameterBank.artifactFingerprint
        == publication.sharedArtifact.artifactFingerprint,
      runtime.fastTissue.sharedParameterBank.artifactFingerprint
        == publication.sharedArtifact.artifactFingerprint
    else {
      throw TissueError.transaction(
        "complete brain runtime does not consume this immutable Metal cohort"
      )
    }
  }
}

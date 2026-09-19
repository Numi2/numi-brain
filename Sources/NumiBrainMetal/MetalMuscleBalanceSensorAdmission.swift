import Foundation
import NumiBrainCore

/// Fail-closed admission for physical receptor packets consumed by the
/// source-bound muscle balance controller. The packet must be the exact
/// acquisition frame whose declared physical latency lands on this committed
/// control root; merely being old enough is not sufficient.
@available(macOS 26.0, *)
enum MetalMuscleBalanceSensorAdmission {
  static func validate(
    view: MetalRawSensorBufferView?,
    topology: SensoryTopology?,
    committedTimestamp: BrainTimestamp
  ) throws {
    guard let view, let topology,
      view.modality == topology.modality,
      view.hasValidity,
      view.receptorCount == topology.receptorCount,
      view.featureDimension == topology.observationDimension,
      committedTimestamp.rawValue >= UInt64(topology.latencyMicroseconds),
      view.receptorTimestamp.rawValue
        == committedTimestamp.rawValue - UInt64(topology.latencyMicroseconds)
    else {
      throw TissueError.transaction(
        "balance feedback requires the exact source-bound physical receptor frame"
      )
    }
  }
}

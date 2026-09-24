import Foundation

/// SwiftPM's generated Bundle.module accessor prefers the executable's copy of
/// the resource bundle. A dynamically loaded Brain library can then compile
/// stale shaders from the host executable. Resolve resources beside the image
/// that contains the Metal runtime before using SwiftPM's normal fallback.
enum MetalBrainResourceBundle {
  static nonisolated let bundle: Bundle = {
    let imageDirectory = Bundle(for: MetalTissueRuntime.self).bundleURL
    let siblingURL = imageDirectory.appendingPathComponent(
      "NumiBrain_NumiBrainMetal.bundle", isDirectory: true)
    return Bundle(url: siblingURL) ?? Bundle.module
  }()
}

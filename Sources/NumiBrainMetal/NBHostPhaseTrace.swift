import Foundation

/// Optional first-eight-step host instrumentation. These intervals measure
/// host preparation/encoding and any existing waits; they are not GPU timings.
/// Emission is deferred by callers until their runtime lock is released.
struct NBHostPhaseTrace {
  private let enabled: Bool
  private let step: UInt64
  private var last: UInt64
  private var samples: [(String, UInt64)] = []

  init(step: UInt64, eligible: Bool) {
    self.step = step
    enabled = eligible && ProcessInfo.processInfo.environment[
      "NUMI_HUMAN_BRAIN_HOST_PROFILE"] == "1"
    last = enabled ? DispatchTime.now().uptimeNanoseconds : 0
  }

  mutating func mark(_ name: String) {
    guard enabled else { return }
    let now = DispatchTime.now().uptimeNanoseconds
    samples.append((name, now - last))
    last = now
  }

  func emit() {
    guard enabled, !samples.isEmpty else { return }
    let text = samples.map { name, elapsed in
      "brain_host_segment=\(name) step=\(step) elapsed_ns=\(elapsed)\n"
    }.joined()
    FileHandle.standardError.write(Data(text.utf8))
  }
}

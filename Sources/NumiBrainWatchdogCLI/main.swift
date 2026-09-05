import Dispatch
import Foundation
import NumiBrainQualification
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

private func usage() {
  print("numi-brain-watchdog check --heartbeat FILE --max-age-ns N [--stop-request FILE]")
}

let args = Array(CommandLine.arguments.dropFirst())
do {
  guard args.count == 5 || args.count == 7, args[0] == "check", args[1] == "--heartbeat",
    args[3] == "--max-age-ns", let maximumAge = UInt64(args[4]) else {
    usage(); exit(64)
  }
  let stopURL: URL?
  if args.count == 7 {
    guard args[5] == "--stop-request" else { usage(); exit(64) }
    stopURL = URL(fileURLWithPath: args[6])
  } else { stopURL = nil }

  let heartbeat = try WatchdogFileProtocol.readHeartbeat(URL(fileURLWithPath: args[2]))
  let now = DispatchTime.now().uptimeNanoseconds
  let decision = try WatchdogDecision(previous: nil, current: heartbeat,
    nowNanoseconds: now, maximumAgeNanoseconds: maximumAge)
  if decision.mustRequestSafeState, let stopURL, let reason = decision.reason {
    let seconds = Date().timeIntervalSince1970
    guard seconds.isFinite, seconds > 0, seconds <= Double(UInt64.max) / 1_000_000_000 else {
      throw QualificationError.invalid("wall clock lies outside watchdog incident range")
    }
    let wall = UInt64((seconds * 1_000_000_000).rounded(.down))
    let request = try WatchdogStopRequest(watchdogInstance: UUID(), observed: heartbeat,
      reason: reason, createdUnixNanoseconds: wall)
    try WatchdogFileProtocol.publishStopRequest(request, to: stopURL)
  }
  let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  var output = try encoder.encode(decision); output.append(10)
  FileHandle.standardOutput.write(output)
  exit(decision.mustRequestSafeState ? 1 : 0)
} catch {
  FileHandle.standardError.write(Data("numi-brain-watchdog: \(error)\n".utf8)); exit(65)
}

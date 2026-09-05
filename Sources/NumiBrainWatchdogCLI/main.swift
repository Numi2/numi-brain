import Dispatch
import Foundation
import NumiBrainQualification
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

private func usage() {
  print("""
  numi-brain-watchdog check|watch --heartbeat FILE --stop-request FILE \
    --expected-process UUID --max-age-ns N --max-progress-age-ns N [--poll-ns N]
  watch retains sequence, generation and process history. Any fault latches a
  sticky stop request. The native/hardware owner must independently enforce it.
  check is one observation only, not a deployment-safety qualification.
  """)
}

private func run() throws -> Int32 {
  let args = Array(CommandLine.arguments.dropFirst())
  guard let command = args.first, ["check", "watch"].contains(command), args.count % 2 == 1 else { usage(); return 64 }
  var options: [String: String] = [:]
  for index in stride(from: 1, to: args.count, by: 2) {
    guard options[args[index]] == nil else { usage(); return 64 }
    options[args[index]] = args[index + 1]
  }
  let required: Set<String> = ["--heartbeat", "--stop-request", "--expected-process", "--max-age-ns", "--max-progress-age-ns"]
  guard required.isSubset(of: Set(options.keys)), Set(options.keys).isSubset(of: required.union(["--poll-ns"])),
    let expected = UUID(uuidString: options["--expected-process"]!),
    let age = UInt64(options["--max-age-ns"]!), let progressAge = UInt64(options["--max-progress-age-ns"]!),
    age >= 1_000_000, progressAge >= age,
    let poll = UInt64(options["--poll-ns"] ?? String(min(age / 4, 100_000_000))),
    poll >= 100_000, poll <= age / 2 else { usage(); return 64 }
  let heartbeatURL = URL(fileURLWithPath: options["--heartbeat"]!)
  let stopURL = URL(fileURLWithPath: options["--stop-request"]!)
  guard heartbeatURL.standardizedFileURL != stopURL.standardizedFileURL else {
    throw QualificationError.invalid("heartbeat and stop marker must be disjoint")
  }
  // Validate the stop transport before entering the monitoring loop. Existing
  // markers, including markers from prior sessions, are never cleared here.
  if let existing = try WatchdogFileProtocol.readStopRequestIfPresent(stopURL) {
    var data = try QualificationFileDirectory.canonicalJSON(existing); data.append(10)
    FileHandle.standardOutput.write(data); return 1
  }
  var monitor = try WatchdogMonitor(expectedProcessInstance: expected,
    maximumAgeNanoseconds: age, maximumProgressAgeNanoseconds: progressAge)
  let watchdogInstance = UUID()
  while true {
    var heartbeat: WatchdogHeartbeat?, failed = false
    do { heartbeat = try WatchdogFileProtocol.readHeartbeat(heartbeatURL) }
    catch QualificationFileError.missing { heartbeat = nil }
    catch { failed = true }
    let decision = monitor.observe(heartbeat, readFailed: failed, nowNanoseconds: DispatchTime.now().uptimeNanoseconds)
    if decision.mustRequestSafeState {
      let wall = Date().timeIntervalSince1970 * 1_000_000_000
      guard wall.isFinite, wall >= 1, wall < Double(UInt64.max) else {
        throw QualificationError.invalid("wall clock outside incident timestamp range")
      }
      let request = try WatchdogStopRequest(watchdogInstance: watchdogInstance,
        expectedProcessInstance: expected, observed: heartbeat,
        reason: decision.reason ?? "watchdog_fault", createdUnixNanoseconds: UInt64(wall.rounded(.down)))
      try WatchdogFileProtocol.publishStopRequest(request, to: stopURL)
    }
    if command == "check" || decision.mustRequestSafeState {
      var data = try QualificationFileDirectory.canonicalJSON(decision); data.append(10)
      FileHandle.standardOutput.write(data); return decision.mustRequestSafeState ? 1 : 0
    }
    Thread.sleep(forTimeInterval: Double(poll) / 1_000_000_000)
  }
}

do { exit(try run()) }
catch { FileHandle.standardError.write(Data("numi-brain-watchdog: \(error)\n".utf8)); exit(65) }

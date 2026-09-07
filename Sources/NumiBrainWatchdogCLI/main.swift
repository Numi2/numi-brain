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
  numi-brain-watchdog check|watch|supervise --heartbeat FILE --stop-request FILE \
    --expected-process UUID --max-age-ns N --max-progress-age-ns N [--poll-ns N]
  supervise additionally requires --acknowledgement FILE --expected-enforcer UUID \
    --required-effect simulationRootsQuiesced|externalActuatorsInhibited --max-stop-age-ns N
  check observes once; watch retains heartbeat history until the first fault.
  supervise waits for the exact stop report until a monotonic deadline. A report
  is not physical-stop verification. No command clears a stop or permits resume.
  Exit: 0 healthy check; 1 retained stop/report; 2 escalation; 64 usage; 65 I/O/data error.
  """)
}

private func emit<T: Encodable>(_ value: T) throws {
  var data = try QualificationFileDirectory.canonicalJSON(value); data.append(10)
  FileHandle.standardOutput.write(data)
}

private struct StopReport: Encodable {
  let status: WatchdogStopSupervisionStatus
  let request: WatchdogStopRequest
  let acknowledgement: WatchdogStopAcknowledgement?
  let mustKeepStopped = true
  let physicalStopVerified = false
  var requiresEscalation: Bool { status.requiresEscalation }
  // Computed properties are not synthesized into Encodable output.
  enum CodingKeys: String, CodingKey {
    case status, request, acknowledgement, mustKeepStopped, physicalStopVerified, requiresEscalation
  }
  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(status, forKey: .status); try c.encode(request, forKey: .request)
    try c.encodeIfPresent(acknowledgement, forKey: .acknowledgement)
    try c.encode(mustKeepStopped, forKey: .mustKeepStopped)
    try c.encode(physicalStopVerified, forKey: .physicalStopVerified)
    try c.encode(requiresEscalation, forKey: .requiresEscalation)
  }
}

private func run() throws -> Int32 {
  let args = Array(CommandLine.arguments.dropFirst())
  guard let command = args.first, ["check", "watch", "supervise"].contains(command), args.count % 2 == 1 else {
    usage(); return 64
  }
  var options: [String: String] = [:]
  for index in stride(from: 1, to: args.count, by: 2) {
    guard options[args[index]] == nil else { usage(); return 64 }
    options[args[index]] = args[index + 1]
  }
  var required: Set<String> = ["--heartbeat", "--stop-request", "--expected-process", "--max-age-ns", "--max-progress-age-ns"]
  if command == "supervise" {
    required.formUnion(["--acknowledgement", "--expected-enforcer", "--required-effect", "--max-stop-age-ns"])
  }
  guard required.isSubset(of: Set(options.keys)), Set(options.keys).isSubset(of: required.union(["--poll-ns"])),
    let expected = UUID(uuidString: options["--expected-process"]!),
    let age = UInt64(options["--max-age-ns"]!), let progressAge = UInt64(options["--max-progress-age-ns"]!),
    age >= 1_000_000, progressAge >= age,
    let poll = UInt64(options["--poll-ns"] ?? String(min(age / 4, 100_000_000))),
    poll >= 100_000, poll <= age / 2 else { usage(); return 64 }
  let enforcer = options["--expected-enforcer"].flatMap(UUID.init(uuidString:))
  let effect = options["--required-effect"].flatMap(WatchdogStopEffect.init(rawValue:))
  let stopAge = options["--max-stop-age-ns"].flatMap(UInt64.init)
  if command == "supervise", enforcer == nil || effect == nil || stopAge == nil || stopAge! < poll {
    usage(); return 64
  }
  let pathKeys = ["--heartbeat", "--stop-request"] + (command == "supervise" ? ["--acknowledgement"] : [])
  guard pathKeys.allSatisfy({ options[$0]!.hasPrefix("/") }) else { usage(); return 64 }
  let paths = pathKeys.map { URL(fileURLWithPath: options[$0]!) }
  guard Set(paths.map(\.standardizedFileURL)).count == paths.count else {
    throw QualificationError.invalid("watchdog heartbeat, stop and acknowledgement paths must be disjoint")
  }
  let heartbeatURL = paths[0], stopURL = paths[1]
  let lockURL = stopURL.deletingLastPathComponent().appendingPathComponent(".watchdog-supervisor.lock")
  guard !paths.map(\.standardizedFileURL).contains(lockURL.standardizedFileURL) else {
    throw QualificationError.invalid("watchdog data cannot alias its supervisor lock")
  }
  let stopDirectory = try QualificationFileDirectory(url: stopURL.deletingLastPathComponent())
  // Retained for the entire monitor and ACK interval, never just a single poll.
  let writerLock: FileHandle? = command == "supervise"
    ? try stopDirectory.acquireExclusiveWriterLock(named: ".watchdog-supervisor.lock") : nil
  defer { withExtendedLifetime(writerLock) {} }
  if let existing = try WatchdogFileProtocol.readStopRequestIfPresent(stopURL) {
    try emit(existing)
    // V2 incidents have no monotonic issue time. A restarted supervisor MUST
    // NOT reset an already issued stop's acknowledgement deadline.
    if command == "supervise" {
      FileHandle.standardError.write(Data("existing stop requires escalation/recovery; its deadline cannot be restarted\n".utf8))
      return 2
    }
    return 1
  }
  var monitor = try WatchdogMonitor(expectedProcessInstance: expected,
    maximumAgeNanoseconds: age, maximumProgressAgeNanoseconds: progressAge)
  let watchdogInstance = UUID()
  while true {
    // Another supervisor's stop is binding even while this heartbeat is healthy.
    if let existing = try WatchdogFileProtocol.readStopRequestIfPresent(stopURL) {
      try emit(existing); return command == "supervise" ? 2 : 1
    }
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
      let started = DispatchTime.now().uptimeNanoseconds
      let retained = try WatchdogFileProtocol.publishAndReadStopRequest(request, to: stopURL)
      guard command == "supervise" else { try emit(decision); return 1 }
      guard retained == request else { try emit(retained); return 2 }
      var supervisor = try WatchdogStopSupervisor(request: retained, expectedEnforcerInstance: enforcer!,
        requiredEffect: effect!, requestedMonotonicNanoseconds: started,
        maximumAcknowledgementAgeNanoseconds: stopAge!)
      while true {
        var acknowledgement: WatchdogStopAcknowledgement?, readFailed = false
        do { acknowledgement = try WatchdogFileProtocol.readStopAcknowledgementIfPresent(paths[2]) }
        catch { readFailed = true }
        // Removal/replacement of the incident during supervision is not recovery.
        do { if try WatchdogFileProtocol.readStopRequestIfPresent(stopURL) != retained { readFailed = true } }
        catch { readFailed = true }
        let status = supervisor.observe(acknowledgement, readFailed: readFailed,
          nowNanoseconds: DispatchTime.now().uptimeNanoseconds)
        if status != .awaitingAcknowledgement {
          try emit(StopReport(status: status, request: retained, acknowledgement: supervisor.acknowledgement))
          return status.requiresEscalation ? 2 : 1
        }
        Thread.sleep(forTimeInterval: Double(poll) / 1_000_000_000)
      }
    }
    if command == "check" { try emit(decision); return 0 }
    Thread.sleep(forTimeInterval: Double(poll) / 1_000_000_000)
  }
}

do { exit(try run()) }
catch { FileHandle.standardError.write(Data("numi-brain-watchdog: \(error)\n".utf8)); exit(65) }

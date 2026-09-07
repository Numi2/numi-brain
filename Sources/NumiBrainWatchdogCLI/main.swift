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
  supervise-lifecycle requires all supervise options plus --arm FILE --ready FILE \
    --completion FILE --max-ready-age-ns N
  Lifecycle mode creates one immutable supervisor arm, waits within its retained
  startup deadline, permits one bounded first-heartbeat window, monitors normal
  liveness, and exits 0 only for an exact clean completion. A stop always wins.
  No report clears a stop or proves physical actuator inhibition.
  Exit: 0 healthy check/clean lifecycle completion; 1 retained stop/report;
        2 escalation; 64 usage; 65 I/O/data error.
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

private struct LifecycleReport: Encodable {
  let status: WatchdogLifecycleStatus
  let arm: WatchdogSupervisorArm
  let ready: WatchdogOwnerReady?
  let completion: WatchdogOwnerCompletion?
  let cleanCompletion: Bool
  let physicalStopVerified = false
}

private func wallNanoseconds() throws -> UInt64 {
  let wall = Date().timeIntervalSince1970 * 1_000_000_000
  guard wall.isFinite, wall >= 1, wall < Double(UInt64.max) else {
    throw QualificationError.invalid("wall clock outside incident timestamp range")
  }
  return UInt64(wall.rounded(.down))
}

private func run() throws -> Int32 {
  let args = Array(CommandLine.arguments.dropFirst())
  guard let command = args.first,
    ["check", "watch", "supervise", "supervise-lifecycle"].contains(command),
    args.count % 2 == 1 else { usage(); return 64 }
  var options: [String: String] = [:]
  for index in stride(from: 1, to: args.count, by: 2) {
    guard options[args[index]] == nil else { usage(); return 64 }
    options[args[index]] = args[index + 1]
  }
  let supervised = command == "supervise" || command == "supervise-lifecycle"
  let lifecycleMode = command == "supervise-lifecycle"
  var required: Set<String> = ["--heartbeat", "--stop-request", "--expected-process",
    "--max-age-ns", "--max-progress-age-ns"]
  if supervised {
    required.formUnion(["--acknowledgement", "--expected-enforcer", "--required-effect", "--max-stop-age-ns"])
  }
  if lifecycleMode {
    required.formUnion(["--arm", "--ready", "--completion", "--max-ready-age-ns"])
  }
  guard required.isSubset(of: Set(options.keys)),
    Set(options.keys).isSubset(of: required.union(["--poll-ns"])),
    let expected = UUID(uuidString: options["--expected-process"]!),
    let age = UInt64(options["--max-age-ns"]!),
    let progressAge = UInt64(options["--max-progress-age-ns"]!),
    age >= 1_000_000, progressAge >= age,
    let poll = UInt64(options["--poll-ns"] ?? String(min(age / 4, 100_000_000))),
    poll >= 100_000, poll <= age / 2 else { usage(); return 64 }
  let enforcer = options["--expected-enforcer"].flatMap(UUID.init(uuidString:))
  let effect = options["--required-effect"].flatMap(WatchdogStopEffect.init(rawValue:))
  let stopAge = options["--max-stop-age-ns"].flatMap(UInt64.init)
  let readyAge = options["--max-ready-age-ns"].flatMap(UInt64.init)
  if supervised, enforcer == nil || effect == nil || stopAge == nil || stopAge! < poll {
    usage(); return 64
  }
  if lifecycleMode, readyAge == nil || readyAge! < poll { usage(); return 64 }

  var pathKeys = ["--heartbeat", "--stop-request"]
  if supervised { pathKeys.append("--acknowledgement") }
  if lifecycleMode { pathKeys.append(contentsOf: ["--arm", "--ready", "--completion"]) }
  guard pathKeys.allSatisfy({ options[$0]!.hasPrefix("/") }) else { usage(); return 64 }
  let urls = Dictionary(uniqueKeysWithValues: pathKeys.map { ($0, URL(fileURLWithPath: options[$0]!)) })
  let standardized = urls.values.map(\.standardizedFileURL)
  guard Set(standardized).count == standardized.count else {
    throw QualificationError.invalid("watchdog protocol paths must be disjoint")
  }
  let heartbeatURL = urls["--heartbeat"]!, stopURL = urls["--stop-request"]!
  let ackURL = urls["--acknowledgement"]
  let lockURL = stopURL.deletingLastPathComponent().appendingPathComponent(".watchdog-supervisor.lock")
  guard !standardized.contains(lockURL.standardizedFileURL) else {
    throw QualificationError.invalid("watchdog data cannot alias its supervisor lock")
  }
  let stopDirectory = try QualificationFileDirectory(url: stopURL.deletingLastPathComponent())
  let writerLock: FileHandle? = supervised
    ? try stopDirectory.acquireExclusiveWriterLock(named: ".watchdog-supervisor.lock") : nil
  defer { withExtendedLifetime(writerLock) {} }

  if let existing = try WatchdogFileProtocol.readStopRequestIfPresent(stopURL) {
    try emit(existing)
    if supervised {
      FileHandle.standardError.write(Data("existing stop requires escalation/recovery; its deadline cannot be restarted\n".utf8))
      return 2
    }
    return 1
  }

  var lifecycle: WatchdogLifecycleSupervisor?
  if lifecycleMode {
    let armURL = urls["--arm"]!, readyURL = urls["--ready"]!, completionURL = urls["--completion"]!
    guard try WatchdogFileProtocol.readSupervisorArmIfPresent(armURL) == nil,
      try WatchdogFileProtocol.readOwnerReadyIfPresent(readyURL) == nil,
      try WatchdogFileProtocol.readOwnerCompletionIfPresent(completionURL) == nil else {
      throw QualificationError.invalid("watchdog lifecycle requires a fresh arm/ready/completion namespace")
    }
    let created = DispatchTime.now().uptimeNanoseconds
    let arm = try WatchdogSupervisorArm(supervisorInstance: UUID(),
      expectedProcessInstance: expected, expectedEnforcerInstance: enforcer!,
      createdMonotonicNanoseconds: created, maximumReadyAgeNanoseconds: readyAge!)
    try WatchdogFileProtocol.publishSupervisorArm(arm, to: armURL)
    lifecycle = try WatchdogLifecycleSupervisor(arm: arm)
    while true {
      var ready: WatchdogOwnerReady?, failed = false
      do { ready = try WatchdogFileProtocol.readOwnerReadyIfPresent(readyURL) }
      catch { failed = true }
      let stopPresent = (try? WatchdogFileProtocol.readStopRequestIfPresent(stopURL)) != nil
      let now = DispatchTime.now().uptimeNanoseconds
      let status = lifecycle!.observeReady(ready, readFailed: failed,
        stopPresent: stopPresent, nowNanoseconds: now)
      if status == .monitoring { break }
      if status.requiresEscalation {
        if !stopPresent {
          let request = try WatchdogStopRequest(watchdogInstance: arm.supervisorInstance,
            expectedProcessInstance: expected, observed: nil,
            reason: "lifecycle_" + status.rawValue, createdUnixNanoseconds: wallNanoseconds())
          _ = try WatchdogFileProtocol.publishAndReadStopRequest(request, to: stopURL)
        }
        try emit(LifecycleReport(status: status, arm: arm, ready: lifecycle!.ready,
          completion: nil, cleanCompletion: false))
        return 2
      }
      Thread.sleep(forTimeInterval: Double(poll) / 1_000_000_000)
    }
  }

  var monitor = try WatchdogMonitor(expectedProcessInstance: expected,
    maximumAgeNanoseconds: age, maximumProgressAgeNanoseconds: progressAge)
  let watchdogInstance = lifecycle?.arm.supervisorInstance ?? UUID()
  var firstHeartbeatDeadlineStart = lifecycle?.ready?.readyMonotonicNanoseconds

  func superviseStop(_ proposed: WatchdogStopRequest, started: UInt64) throws -> Int32 {
    let retained = try WatchdogFileProtocol.publishAndReadStopRequest(proposed, to: stopURL)
    guard supervised else { return 1 }
    guard retained == proposed else { try emit(retained); return 2 }
    var supervisor = try WatchdogStopSupervisor(request: retained,
      expectedEnforcerInstance: enforcer!, requiredEffect: effect!,
      requestedMonotonicNanoseconds: started,
      maximumAcknowledgementAgeNanoseconds: stopAge!)
    while true {
      var acknowledgement: WatchdogStopAcknowledgement?, readFailed = false
      do { acknowledgement = try WatchdogFileProtocol.readStopAcknowledgementIfPresent(ackURL!) }
      catch { readFailed = true }
      do { if try WatchdogFileProtocol.readStopRequestIfPresent(stopURL) != retained { readFailed = true } }
      catch { readFailed = true }
      let status = supervisor.observe(acknowledgement, readFailed: readFailed,
        nowNanoseconds: DispatchTime.now().uptimeNanoseconds)
      if status != .awaitingAcknowledgement {
        try emit(StopReport(status: status, request: retained,
          acknowledgement: supervisor.acknowledgement))
        return status.requiresEscalation ? 2 : 1
      }
      Thread.sleep(forTimeInterval: Double(poll) / 1_000_000_000)
    }
  }

  while true {
    if let existing = try WatchdogFileProtocol.readStopRequestIfPresent(stopURL) {
      try emit(existing); return supervised ? 2 : 1
    }
    var heartbeat: WatchdogHeartbeat?, heartbeatFailed = false
    do { heartbeat = try WatchdogFileProtocol.readHeartbeat(heartbeatURL) }
    catch QualificationFileError.missing { heartbeat = nil }
    catch { heartbeatFailed = true }
    let now = DispatchTime.now().uptimeNanoseconds

    if lifecycleMode {
      var completion: WatchdogOwnerCompletion?, completionFailed = false
      do { completion = try WatchdogFileProtocol.readOwnerCompletionIfPresent(urls["--completion"]!) }
      catch { completionFailed = true }
      if completion != nil || completionFailed {
        let status = lifecycle!.observeCompletion(completion, currentHeartbeat: heartbeat,
          readFailed: completionFailed, stopPresent: false, nowNanoseconds: now)
        if status == .completedNormally {
          try emit(LifecycleReport(status: status, arm: lifecycle!.arm,
            ready: lifecycle!.ready, completion: lifecycle!.completion,
            cleanCompletion: true))
          return 0
        }
        if status.requiresEscalation {
          let request = try WatchdogStopRequest(watchdogInstance: watchdogInstance,
            expectedProcessInstance: expected, observed: heartbeat,
            reason: "lifecycle_" + status.rawValue,
            createdUnixNanoseconds: wallNanoseconds())
          return try superviseStop(request, started: now)
        }
      }
      // Readiness precedes the first authoritative heartbeat. Give exactly one
      // configured heartbeat-age window from the immutable ready timestamp;
      // after that, ordinary missing-heartbeat semantics apply.
      if monitor.lastHeartbeat == nil, !heartbeatFailed, heartbeat == nil,
        let start = firstHeartbeatDeadlineStart, now >= start, now - start <= age {
        Thread.sleep(forTimeInterval: Double(poll) / 1_000_000_000)
        continue
      }
    }

    let decision = monitor.observe(heartbeat, readFailed: heartbeatFailed,
      nowNanoseconds: now)
    if !decision.mustRequestSafeState { firstHeartbeatDeadlineStart = nil }
    if decision.mustRequestSafeState {
      let request = try WatchdogStopRequest(watchdogInstance: watchdogInstance,
        expectedProcessInstance: expected, observed: heartbeat,
        reason: decision.reason ?? "watchdog_fault",
        createdUnixNanoseconds: wallNanoseconds())
      let code = try superviseStop(request, started: now)
      if !supervised { try emit(decision) }
      return code
    }
    if command == "check" { try emit(decision); return 0 }
    Thread.sleep(forTimeInterval: Double(poll) / 1_000_000_000)
  }
}

do { exit(try run()) }
catch { FileHandle.standardError.write(Data("numi-brain-watchdog: \(error)\n".utf8)); exit(65) }

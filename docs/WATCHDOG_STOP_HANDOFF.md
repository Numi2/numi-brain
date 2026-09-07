# Watchdog stop handoff and supervised native capture

Status: portable implementation checked; native integration authored, not Apple-qualified.
The implementation through `2734cae4ba1f2cccf0f6b149dc210fe34867faf5` builds on
`e3ff9f44244d38d8ee525bb2799575f540685b44`. Existing recovery work, native
protection, physical ownership and qualification thresholds are unchanged.
This is an implementation increment, not completion of Gate F or all gates.

## What is connected

`numi-brain-watchdog supervise` monitors the existing heartbeat protocol, retains
the first fault, and waits for its exact acknowledgement under one monotonic
deadline. The expected process, enforcer and stop effect are configured rather
than inferred from whatever file happens to arrive. Missing, late, malformed,
foreign or wrong-effect reports fail closed. A restarted supervisor refuses to
assign a fresh deadline to an existing version-2 incident: that format does not
retain a trustworthy monotonic issue time.

`WatchdogRootInterlock` admits one root with a controller-specific, single-use
permit. A latched stop closes new admission immediately. An already admitted
root must still report its truthful authoritative settlement. Command failures
and timeouts remain indeterminate, not fabricated restored rejections. No
method resets a stopped owner or authorizes resumption.

`WatchdogOwnerFileSession` connects that state machine to bounded, anchored,
non-symlink file I/O. It holds one exclusive owner lock, refuses stale heartbeat
and acknowledgement namespaces, preserves the first fault, and writes durable,
create-only acknowledgements. Repeated polls retain identical acknowledgement
bytes. Removing a marker cannot reopen admission. UUIDs, file locks and artifact
hashes coordinate cooperating processes; they do not authenticate a writer.

`MetalNumanXGateCRootRunner.runSupervisedRoot` calls the EXISTING native runner.
It adds no physical solver, neural stepper, GPU command timeline or protective
motor alternative. The native owner still decides accepted publication versus
restored rejection. Accepted roots supply their actual public generation and
transaction fingerprint. Rejected roots retain the prior committed fingerprint,
not the rejected candidate's fingerprint. Their terminal evidence remains the
actual rejection artifact. A first-root rejection without a public aggregate
cannot produce an invented bootstrap heartbeat or acknowledgement.

The supervised result always retains a completed native `RootResult`, even if
subsequent watchdog reporting fails. The experiment frontend appends that result
BEFORE retaining its separate reporting failure. Reporting errors never enter
the native runner's rollback handler after a completed publication.

## Configuring the existing experiment

The existing `numi-brain-experiment capture --config FILE` accepts an optional
`watchdog` object alongside its existing capture fields. The complete capture
configuration is retained by the existing content-addressed artifact path.
Omitting the object preserves explicitly unsupervised research behavior; this
change does not silently claim protection for legacy entrypoints.

```json
{
  "watchdog": {
    "processInstance": "REPLACE_WITH_A_NEW_PROCESS_UUID",
    "enforcerInstance": "REPLACE_WITH_A_NEW_ENFORCER_UUID",
    "directoryPath": "/absolute/existing/private/watchdog-run-directory",
    "heartbeatName": "heartbeat.json",
    "stopRequestName": "stop.json",
    "acknowledgementName": "stop-ack.json"
  }
}
```

This is a configuration fragment with deliberate placeholders, not a runnable
capture configuration. Use one fresh, existing, resolved private directory per
owner session. Never reuse an old heartbeat or acknowledgement as restart
material. The owner and supervisor hold different lock files in this directory.

After the native owner has published its first real heartbeat, the independent
supervisor process uses the same process/enforcer UUIDs and file paths. Declare
all deadlines from the actual bounded workload and safety requirements; no
example deadline is a qualified actuator or physiological limit.

```sh
swift run -c release numi-brain-watchdog supervise \
  --heartbeat "$WATCHDOG_DIRECTORY/heartbeat.json" \
  --stop-request "$WATCHDOG_DIRECTORY/stop.json" \
  --acknowledgement "$WATCHDOG_DIRECTORY/stop-ack.json" \
  --expected-process "$PROCESS_UUID" \
  --expected-enforcer "$ENFORCER_UUID" \
  --required-effect simulationRootsQuiesced \
  --max-age-ns "$HEARTBEAT_DEADLINE_NS" \
  --max-progress-age-ns "$PROGRESS_DEADLINE_NS" \
  --max-stop-age-ns "$STOP_DEADLINE_NS" \
  --poll-ns "$POLL_NS"
```

A missing heartbeat is immediately a fault, not an implicit startup grace
period. This increment does not implement an independently supervised bootstrap
handshake. A host orchestrator must coordinate process startup and normal
capture completion. An owner which exits or remains idle without further
polling cannot acknowledge a later stop: the supervisor escalates. It does not
silently excuse completion, extend a deadline or invent a terminal state.

Exit codes are `0` for a healthy single check, `1` for a retained stop or matching
report, `2` for required escalation, `64` for usage and `65` for data/I/O errors.
A matching report is not exit-zero deployment approval. Supervision output
keeps `mustKeepStopped=true` and `physicalStopVerified=false`. Existing-stop
responses retain the incident itself and exit nonzero. The owner must treat all
nonzero exits as non-resumption, with an independent response to escalation and
supervisor faults; this command does not itself actuate that response.

## Verification actually performed

Swift 6.2.1 on x86_64 Linux:

- **47 focused XCTest cases passed, zero failures**: 20 acknowledgement,
  14 admission/settlement and 13 owner file-session cases.
- **Eight actual CLI process checks passed**: healthy check, missing heartbeat,
  missing acknowledgement deadline, matching report without resume authority,
  foreign enforcer, malformed report, wrong stop effect and old-incident deadline
  restart refusal.
- The portable watchdog executable compiled and ran.
- The new Metal adapter and modified experiment frontend were syntax-parsed.
  Syntax parsing is not Apple type checking, linking or native execution.

These were isolated source checks, not a full repository build. The local
package contained the new watchdog sources, exact existing file-I/O and watchdog
protocol files, and the owning heartbeat/verifier/error declarations extracted
verbatim from their existing files. No substitute physical runner supplied the
reported results. The script below uses the complete repository's original
modules instead; its full combined run was not executed in this partial local
checkout.

```sh
bash scripts/validate-credible-route-portable.sh
# Supported Apple host and native prerequisites:
swift build -c release --product numi-brain-experiment
swift test --filter Watchdog
```

Portable CI covers these tests and process checks on matching pushes to `main`
as well as pull requests. A configured workflow is not a recorded successful
CI run, and portable CI does not validate the Metal integration.

## Remaining completion boundary

Native Apple qualification must demonstrate pre-root stop rejection, a stop
arriving during an actual root, exact accepted/rejected settlement identities,
post-commit reporting failure retention, unknown-outcome quarantine and refusal
to submit another root. Retain the exact revision, device, configuration, native
terminal artifacts and failure outcomes. None of those native experiments is
reported as executed here.

The supported report effect is only `simulationRootsQuiesced`: the configured
session has no admitted root outstanding and will not admit another. Polling is
at capture orchestration boundaries, not a new per-environment production hot
loop. A GPU or native owner stuck inside a root cannot be forcibly stopped by
this file session. The supervisor can detect a missing acknowledgement and exit
for escalation, but independent physical enforcement remains necessary.

`externalActuatorsInhibited` is a distinct report effect that the simulation
owner CANNOT emit. Mandatory independent inhibition, verified force/thermal/
actuator instrumentation, authentication, supervisor-failure handling, bootstrap
and completion handshakes, and deployment fault campaigns remain open. Matching
an effect field or referencing an artifact hash is not verification of those
capabilities. No real hardware is moved by this increment.

The broader implementation priorities remain those in
[CREDIBLE_ROUTE_PROGRESS.md](CREDIBLE_ROUTE_PROGRESS.md): complete native paired
brain/physics restoration, useful held-out physical-outcome learning, verified
measurement adapters and an authoritative all-gates verifier. This watchdog
increment neither closes those requirements nor supplies evidence of successful
physical learning.

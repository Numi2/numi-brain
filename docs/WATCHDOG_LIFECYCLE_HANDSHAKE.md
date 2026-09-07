# Watchdog bootstrap and normal-completion handshake

Status: portable protocol/state machine implemented; orchestration integration
and independent physical enforcement remain open.

A supervisor now has a create-only `WatchdogSupervisorArm` carrying its exact
process/enforcer identity, monotonic creation time and maximum owner-ready age.
The deadline travels in the retained arm itself: restarting a supervisor cannot
reset startup grace. The owner can publish an exact `WatchdogOwnerReady` only
inside that original window and only for the configured process/enforcer.

Normal completion is a different artifact from a stop acknowledgement.
`WatchdogOwnerCompletion` must name the exact last settled heartbeat and a
content-addressed terminal/run artifact. A supervisor accepts it only when it
matches the heartbeat it currently observes. Any retained stop request outranks
both readiness and normal completion.

`WatchdogOwnerLifecycle` wraps the existing root-admission session only for the
lifecycle files. It refuses completion before activation, while a root is active,
after owner failure, without a settled heartbeat, or after completion. It does
not admit roots itself and does not clear a stop.

This closes the protocol ambiguity in which a supervisor had no typed way to
distinguish bounded startup or clean owner completion from ordinary liveness
failure. It does not yet launch the owner/supervisor pair, authenticate either
process, force a stuck GPU command to terminate, or prove external actuator
inhibition. The production experiment frontend and watchdog CLI must next wire
this handshake around the existing supervised capture loop.

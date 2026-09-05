# Gate F — safety and deployment

Status: core safety/deployment primitives present; qualification and external watchdog integration open.

Gate F adds an explicit layered safety decision model over semantic, kinematic, contact, force, thermal, actuator and uncertainty risks. Malformed records, stale generations, resource aliasing and device faults outrank learned policy and fail closed. Hard physical limits produce a protective stop. Intermediate uncertainty requests supervision; high uncertainty stops. The thresholds are versioned deployment inputs, not values fitted after incidents.

`SafetyCampaignVerifier` requires a complete predeclared scenario set, rejects missing/duplicate scenarios, and requires every challenged scenario to avoid public-root mutation and rejected-shadow exposure within its declared latency budget. Required scenario classes include all six physical/semantic limits, uncertainty, malformed records, stale generation, resource alias, event replay, GPU fault and process restart.

`WatchdogHeartbeat` and `WatchdogVerifier` define the independent process-facing liveness contract: process instance, monotonic sequence/time, public generation and transaction fingerprint. A process restart is distinguishable from a stale or regressed heartbeat. The repository's durable prepared-generation/recovery chain supplies restart material, but a real independent watchdog process/device remains a deployment responsibility.

`SafetyIncidentArtifact` refuses to encode an incident that exposes rejected shadow state. Incidents bind runtime revision, parameter version, public generation, transaction identity, safety vector and decision, with an optional content-addressed recovery artifact.

`numi-brain-gate-f decide` executes the deterministic safety decision function offline. This is not itself the independent watchdog and it does not bypass the existing GPU protective path or transactional root authority.

Promotion requires executable red-team evidence for malformed records, stale generations, aliasing and event replay; bounded protective-stop latency; GPU/process/device failure behavior; calibrated uncertainty and supervision transitions; durable recovery/rollback; reproducible incident capture; versioned model/data/runtime manifests; and rollbackable releases. No clinical-safety claim follows from Gate F qualification.

# Gate E native outcome-ledger binding

Status: source integration added; Apple measurement qualification remains open.

This increment removes one major ambiguity from the v2 performance-attempt
ledger: accepted and rejected rows can now be generated directly around the
existing authoritative `MetalNumanXGateCRootRunner`, then independently checked
against the content-addressed Gate C capture transcript.

`MetalNumanXPerformanceAttemptCollector` records the monotonic wall interval of
each sequential native root and derives outcome, physical generation, physical
time and terminal-evidence identity from the returned authoritative root result.
It supports exactly one environment because the current root runner is
sequential environment zero. It refuses to manufacture scale by copying that
root into multiple logical environments. A thrown or indeterminate root
permanently invalidates the collector; the existing capture surface does not yet
issue a terminal command-failure transcript that could safely populate a v2
`commandFailed` row.

`BrainPerformanceAttemptLedgerEvidence.verify` then reopens the frozen protocol
bytes, hashes them canonically, runs the existing transitive Gate C capture
verifier and checks every ledger row against its exact retained sample and root
execution. Accepted rows must advance one physical generation and target time;
rejected rows must retain the base generation and committed time. Outcome counts
must equal the authoritative capture receipt. Reused, foreign or altered root
evidence therefore cannot be converted into a passing Gate E ledger.

The resulting receipt is deliberately diagnostic and reports
`collectorAuthorityVerified=false`. The capture evidence can prove terminal
root identity and the frozen protocol can prove its own hash. They cannot prove
that host RSS, wall time, executable/metallib hashes, power, GPU counters or the
reported hardware identity came from the claimed production measurement owner.
Those fields still require a low-overhead native collector with independently
bound process/device evidence.

This is also not a throughput claim for the existing artifact-heavy Gate C
capture. The adapter establishes evidence semantics first. Production Gate E
still needs batched environment ownership, low-overhead terminal evidence,
authenticated command-failure outcomes, matched Apple campaigns and measured
limits without capture/readback instrumentation contaminating the benchmark.

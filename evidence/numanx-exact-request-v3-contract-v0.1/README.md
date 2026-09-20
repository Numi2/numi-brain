# NumanX exact request-v3 contract qualification

Status: `inbound_contract_passed_execution_blocked`

NumiBrain contract commit `5d9398bdeb4304224398f9b2df9f321cf549da12`
and Metal-validation follow-up `53d90bc57066c8d46185e9cfdc31543af7ba8eba`
on `main`, together with Numi Human native integration commit
`e7ad0ac14c14f8552509225076e21f0373d7da98` agree on an additive,
domain-separated exact-nanosecond inbound motor contract.

The immutable request-v2 ABI remains the historical all-v1/microsecond shape.
An exact runtime rejects that shape at failure stage 901 before inspecting any
borrowed resource. Request-v3 is the first all-exact inbound shape: v2 root,
substep, candidate, motor-output header, and ready gate, with explicit clock
domain 2, one-nanosecond quantum, typed resource declarations, and 16-byte
header/gate alignment. Brain and native independently reproduce the five fixed
fingerprints recorded in `receipt.json`.

On the physical Apple M4 Pro Mac mini, a fresh warnings-as-errors native build
passed the registered fixed-vector CPU contract and the asset-backed exact
full-body admission probe with Metal API validation enabled. The probe admitted
the request-v3 scalar and descriptor contract, rejected mixed v1 records, and
then stopped at the deliberate outbound-unavailable boundary (stage 900)
before resource import, event import, GPU command construction or submission,
callback, event signal, accepted publication, or persistent-state advance.

Brain qualification passed 15 exact-domain/layout tests and then all 33 focused
exact/v1 compatibility tests with Metal API validation enabled. That broad run
first exposed a pre-existing zero-sized fast-autonomic dispatch in
`MetalJointTransactionTests.testCorrectedDurationHistoryCoverageFailsBeforeOverwrite`;
the same assertion reproduces at baseline commit `a2783fc`. Follow-up
`53d90bc` skips the optional kernel when no autonomic channels are bound and
strengthens the test to require its intended relay-history coverage error. The
33-test physical-M4 rerun passes with Metal validation. Both the retained
baseline failure and passing follow-up are included.

This evidence qualifies the inbound ABI and fail-closed physical admission
boundary only. It does **not** qualify exact outbound sensors, HumanMatter
close, accepted-root execution or publication, persistent exact continuation,
standing, performance, or production.

All fresh build and Metal-dependent work for this receipt ran through
`ssh macmini`.

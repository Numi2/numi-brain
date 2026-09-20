# NumanX exact-domain construction qualification

Status: `construction_and_clock_introspection_passed`

NumiBrain commit `a2783fcf2b78a2e64eca08da9ee9683794344d71`
passed a fresh full test-graph build and the environment-gated native admission
test against clean Numi Human native commit
`b1a9bdd3b27afa6daedff37c276a5b0b2b600c54` on the physical Apple M4 Pro
Mac mini with Metal API validation enabled.

The test admitted the prepared `12,500 ns` authored world, required the native
exact-clock introspection entry point, and checked a `1 ns` clock quantum, zero
initial published timestamp, and zero initial publication epoch. This closes
the construction and exact-clock-copy boundary for the named source and
artifact identities in `receipt.json`.

This evidence does **not** qualify an executed Brain v2 root, accepted-state or
commit publication, persistent exact-clock continuation, support-history
continuity, equilibrium, standing, behavior, performance, or production.
Those claims remain false until the native outbound sensor, HumanMatter,
accepted-token, commit, snapshot, and persistent-state lanes have exact-domain
owners and pass an accepted-root run.

All build and GPU-dependent qualification work for this receipt ran through
`ssh macmini`. `native-qualification.log` is the retained focused run; ordinary
local unit tests are not promoted into physical Metal evidence.

# Connectome numerical revision 2

The cancellation-safe physical-time gain in `ConnectomeRate.metal` changes
FP32 execution relative to the earlier `1 - pow(1 - alpha, ratio)` expression.
It evaluates the same mathematical rate model while retaining representable
small updates that the earlier subtraction could round to zero.

The native binding fingerprint domain is therefore revised from
`0x4e42434e53000001` to `0x4e42434e53000002`. Graph NUMICNS1 bytes and graph
fingerprints are unchanged. Compiled bindings, decoder programs and their
checkpoint identities change transitively. Old checkpoint/program identities
must not be relabeled or accepted as exact revision-2 replay. Recompile the
controller from its source specification and begin a new run, or develop an
explicitly qualified migration rather than bypassing identity checks.

The portable test reconstructs both revision hashes independently and checks
that native binding and decoder identities distinguish them. All 23 native
checks pass locally with C++20 warnings treated as errors. The actual shader
has small-step and full-data regression tests; test presence is not GPU
execution evidence. See the named Apple CI results for their execution status.

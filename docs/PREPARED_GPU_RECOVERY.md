# Unpublished native GPU recovery

Status: implemented in source; not compiled, tested, benchmarked or qualified in this development
session. This is a native cognitive-arena recovery path, not a claim that every Numi suite participant
is already restart-recoverable.

## What changed

The prior `MetalAgentStateRecoveryImage` exported committed hot state and committed persistent
memory. It could not represent the unpublished generation between prepare and commit. The new
`BrainPreparedGPUImage` stores four distinct byte images:

1. Base committed hot state.
2. Completed candidate hot state.
3. Base persistent memory, before pending mutations are applied.
4. The complete unapplied candidate memory journal, including header, capacity and generation.

The image binds the actual `BrainJointTransactionToken`, base/shadow generations, physical root
fingerprint, cached decision, random-counter generation and exact hot/memory layout fingerprints.
Its SHA-256 is domain-separated and length-framed over explicit little-endian scalar encodings and
all four buffers. GPU virtual addresses and ping-pong buffer indices are deliberately absent.

`BrainPreparedGPUImage.validated()` rejects wrong roots, corrupt bytes, inconsistent generations,
invalid journal headers/status, unsupported mutation section IDs, unaligned or out-of-bounds writes,
overlapping mutation destinations and allocations exceeding the configured byte budget. Codable
loading must be followed by this validation; decoding alone is not validation.

## Actual Metal path

`MetalJointAgentStateTransaction.encodePreparedRecoveryCapture(...)` calls
`MetalPreparedRecoveryTransfer` after native shadow validation, while the root is unpublished.
It finds the real buffers in the existing arena, retains their allocations and staging buffers,
and records byte-exact copies on the **owner-supplied Metal 4 command buffer**.

The caller must close a prior compute encoder, supply the command buffer's actual commit options,
and submit that command buffer using those same options. Producer/consumer barriers order the copies
on the owning queue. Cross-queue producers require an owner-established event dependency. The API
never creates a competing neural hot-loop queue and never treats command encoding as completion.

The completion handler reads staging memory only after successful Metal feedback. Publication and
abort are fenced while the transfer is pending. A command error leaves an explicit recovery-failed
state, not a successful prepare. If the owner never submits the buffer, the transaction remains
fenced; the owner must resolve that command lifecycle rather than reuse the buffers early.

Apple API references used for this implementation:

- https://developer.apple.com/documentation/metal/mtl4computecommandencoder
- https://developer.apple.com/documentation/metal/mtl4computecommandencoder/copy(sourcebuffer:sourceoffset:destinationbuffer:destinationoffset:size:)
- https://developer.apple.com/documentation/metal/synchronizing-passes-with-consumer-barriers

## Durable ordering

`BrainPreparedGPUStore` writes a binary image with a bounded JSON header, then an immutable prepare
record naming its SHA-256. It uses descriptor-relative file access, rejects symbolic links, holds
an exclusive writer lock, and publishes through no-replace hard links. File synchronization and
Darwin `F_FULLFSYNC` precede the durable directory entry. A write with an ambiguous outcome poisons
the open store; close/reopen and inspect rather than continuing to issue decisions.

The required owner sequence is:

```
finish/validate native candidate on GPU
capture all candidate bytes and wait for completion feedback
persist image and prepare record
report prepared to the joint owner
persist the joint owner's commit-or-abort decision
publish the matching candidate, or discard an explicitly aborted candidate
persist final joint publication receipt
```

`persist` is idempotent for exactly the same image. A different candidate for an already-prepared
root is rejected. Commit cannot become abort and abort cannot become commit. A prepared record with
no decision means **wait/reconcile with the same transaction manager**. It never implies rollback.
The store is local persistence, not consensus, authorization, a signed timestamp service or a
replacement for the suite's joint decision authority.

## Restore without replaying computation

After process restart, reconstruct immutable species/program/parameter layouts first. Load and
validate the image, then call `MetalJointAgentStateTransaction.restorePreparedRecovery(...)` against
an isolated native runtime with matching layout fingerprints and sizes.

The existing native checkpoint engine restores the base hot state and base persistent memory. The
runtime allocates a new shadow generation. On the caller's Metal 4 command buffer, the new transfer
copies saved candidate hot state and its unapplied journal into that new shadow. Only successful
GPU completion marks it `gpuStateFinished` and restores the accepted physical fingerprint.

At this point the candidate is **still not committed**. The owner must resolve the durable joint
decision and provide the authentic matching native commit receipt through the existing commit path.
Recovery does not recompute a physical consequence, resample RNG, retrain a model, or apply the
memory journal early. Reconstructed GPU addresses require rebuilt argument tables/residency in the
native owner before any subsequent compute command.

## Scope and remaining integration

This image covers `MetalAgentStateArena`, not every buffer in `MetalTissueRuntime`, NumanX, the
NumiTissue runtime, external archive storage, or a physical instrument. The owning root must retain:

- The native accepted physical token/commit receipt and complete root-level decision authority.
- Fast tissue, voltage/ion/history/event state and its immutable model identities.
- NumanX physical state, contact/friction history, topology, transport, RNG and pending outputs.
- Referenced archive pages/parameter artifacts and all additional owner-managed arenas.

A capture of only this cognitive arena must not be advertised as a complete brain/body snapshot.
The new native APIs are callable implementation, but automatic insertion into every NumanX/MyoSim
owner transaction has not been performed. The separate `Numi2/numanx` repository contains recovery
support, not the full native solver. No undocumented solver types or local-only source paths are
invented to claim that integration.

The former `BrainMetalRecoveryBundle` remains a committed-checkpoint facility. It is not the new
prepared format and cannot be substituted for `BrainPreparedGPUImage`.

## User-side execution

```sh
swift build
swift test --filter BrainPreparedGPURecoveryTests
```

The test source covers exact bytes, native root validation, SHA-256 corruption, invalid/overlapping
journals, bounded allocations, idempotent persistence, conflicting candidates, irreversible
decisions, single-writer locking and truncated-file detection. It has not been executed here.

Required Apple Silicon fault matrix: completion failure; process death after image publication,
after prepare, after decision and during participant publication; different GPU allocation addresses;
corrupt journal/header; old parameter layout; missing archive; and exact continuation after restore.
Measure checkpoint size, staging-memory peak, transfer time and durable-write latency separately
from the GPU hot loop. No wall-clock real-time or zero-overhead persistence claim is made.

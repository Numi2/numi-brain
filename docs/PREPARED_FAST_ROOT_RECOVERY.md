# Native fast-root and paired brain recovery

## Implementation status

This increment continues the native prepared-GPU work from repository baseline
`9fc0f8842c5dbea58b8d59b723b1c682b64947d6`. It implements capture of the existing fast-root witness
sources, verified persistence of actual participant bytes, preservation of native acceptance and
commit records, and reconstruction of a paired cognitive/fast checkpoint.

**Source implementation only.** No Swift compilation, regression execution, shader compilation,
GPU capture/restore, process-kill campaign, device operation or biological qualification was
performed during this increment. The regression sources describe checks to execute on the target
Mac. A source-level round-trip assertion is not a recorded successful GPU round trip.

## What is captured

The implementation uses `MetalTissueRuntime.makeNumanXPreparedFastStateSources(for:)`, the existing
source list used by the native end-of-prepare witness. It does not guess GPU addresses, enumerate
unrelated residency allocations, or create another model of fast neural state.

The persistent fast-state kinds are:

| State group | Native checkpoint kinds |
| --- | --- |
| Tissue and conduction | tissue state, relay history, relay timestamps |
| Scheduling and regional computation | scheduler clocks, regional states, regional tokens |
| Delayed regional routing | route-history metadata, timestamps, values, route-runtime state |
| Protective control | protective command, motor header, muscle excitation |
| Body feedback | body-load field, body-schema posterior |

Nonempty ranges are captured together with the native 512-byte fast-root metadata record. The
metadata identifies the root, substep, generations, target time, immutable model/program bindings,
RNG continuation, selected relay-history planes, species and compiled species. Saved ping-pong
indices are validated as metadata but are not used as destination addresses after restart.

The native accepted-consequence path already imports CPG, reflex, cerebellar, autonomic and accepted
control state into the cognitive candidate. Therefore the fast image must be paired with the
**same root's complete cognitive image**. It is not a standalone checkpoint for every staging or
scratch allocation in the fast runtime. Temporary upload arenas and already-consumed command
arguments are reconstructed by the native owner instead of being mistaken for persistent identity.

## Source entry points

| Source | Responsibility |
| --- | --- |
| `MetalPreparedFastRootImage.swift` | Native fast metadata validation, exact semantic ranges, relay-plane reconstruction |
| `MetalPreparedFastRootTransfer.swift` | Completion-gated capture from retained native Metal source leases |
| `BrainPreparedNativeReceipts.swift` | Saved substep, physical acceptance and commit ABI records, checked by compiled validators |
| `BrainPreparedJournalMaterialization.swift` | Recovery-only application of saved fixed-byte memory writes |
| `MetalPreparedBrainRootRecovery.swift` | Pair validation, participant storage, decided recovery and isolated native restore |
| `BrainJointPreparedManifestStore.swift` | Actual participant payload files required before prepare/commit |

Core files are under `Sources/NumiBrainCore/Runtime/`; Metal files are under `Sources/NumiBrainMetal/`.
The earlier cognitive capture remains in `MetalJointAgentStateTransaction` and
`MetalPreparedRecoveryTransfer`.

## Capture order and ownership

Before opening a root, retain a matching committed checkpoint for the cognitive and fast state.
Run the existing native transaction and finish its fast and cognitive producers. At the explicit
recovery boundary:

1. Keep the root exclusively quarantined: no publication, abort, new root or concurrent component mutation.
2. Require successful terminal fast submission feedback and its matching native SUCCESS gate.
3. Call `encodePreparedFastRootCapture` with the existing fast ticket, root, base checkpoint,
   device, owner command buffer and the exact commit options used to submit that buffer.
4. Wait for completion of the capture copy before persisting its returned image.
5. Capture the matching cognitive candidate and its unapplied memory journal through the existing native API.
6. Preserve the original native substep, accepted-physics and joint-commit records; obtain the actual
   physical checkpoint fingerprint from the physical owner.
7. Persist all participant bytes before reporting the root prepared. Record the joint decision before publication.

The capture method records byte copies on the supplied Metal 4 timeline. It creates no alternate
queue, performs no neural stepping, and does not read a private allocation as if it were CPU memory.
Staging and source residency remain retained through completion. The caller must supply an already
begun command buffer with no open encoder and submit it using the same commit options. A buffer
that is never submitted cannot produce a valid capture result.

**The fast capture extension does not independently lock every existing owner publication path.**
Its caller must hold the native root's ownership quarantine through completion. This increment does
not automatically insert capture into every production prepare callback or make checkpoint I/O part
of a millisecond hot loop. Such insertion belongs at the owning transaction boundary, with explicit
latency and memory budgets. Disk synchronization and base64 JSON encoding have real costs; neither
zero overhead nor real-time completion is claimed.

## Actual files, not digest declarations

`BrainJointPreparedManifestStore.storeParticipant(artifact, bytes:)` checks byte length and SHA-256
and durably stores an immutable content-addressed payload. `prepare` verifies every participant
file before creating the whole-root manifest. `decide(..., .commit)` verifies them again.

The store requires the complete cognitive, fast, physical and archive participant set. A plausible
SHA-256 string without its actual bytes cannot vote prepared or authorize commit. Aggregate and
per-participant byte budgets are explicit. Reads are bounded, verify the full digest and reject
trailing or truncated data. Symbolic links and nonregular files are rejected; nonblocking opens
prevent a substituted FIFO from blocking before its file type can be checked.

Writes use temporary files, full synchronization on Darwin, immutable no-replace publication and
directory synchronization. An ambiguous write poisons the open store. Reopen and reconcile the
actual files before continuing. A commit decision cannot become abort. An absent decision remains
undecided. An explicit abort is inspectable even when damaged candidate payloads cannot be restored.

Earlier digest-only records are intentionally not silently promoted. Import their exact matching
payloads before preparation/commit/recovery, or preserve the old store and use a separately
identified new run. Do not fabricate placeholders to bypass a missing native artifact.

Checksums provide storage integrity, not producer authentication, consensus, operator approval,
proof of measured physical execution, or validation of another subsystem's opaque payload format.
The store assumes exclusive ownership under the existing trusted application boundary.

## Native receipts and memory mutation format

`BrainPreparedNativeReceipts` preserves the original native ABI bytes for the accepted substep,
physical acceptance and joint commit. Loading revalidates these records using the repository's
compiled C++ validators. The current prepared-fast path supports the native single-whole-root
physical substep and requires its exact start, target and next physical generation.

The memory-journal audit also corrected an erroneous earlier test fixture. A 64-byte
`NBAgentMemoryMutation` contains its 16-byte write payload at offset **16**. Offset **48** is the
record identifier. The journal has a separate 48-byte header. Recovery validates bounds, generation,
alignment and nonoverlap, then copies only the declared payload bytes into an isolated copy of base
memory. It does not write the record identifier into neural memory, change the saved base, re-run
inference, resample RNG, or apply pending writes before a matching commit decision.

## Paired recovery through the real native handle

`MetalPreparedBrainRootPersistence.prepare(...)` takes the captured cognitive and fast images plus
the physical/archive artifacts and their actual bytes. It verifies every supplied byte identity,
checks the paired root/species/substep and base checkpoint, stores the payloads, then prepares the
whole-root manifest. Physical and archive payloads still belong to their native producers; this
method cannot determine whether an arbitrary foreign byte format includes every required state.

`recoverCommitted(...)` rejects missing and abort decisions. It loads the stored cognitive and fast
images, verifies their identity against the decided manifest, checks the native receipts, and only
then materializes the saved memory writes. It reconstructs the fast candidate from the captured
semantic ranges and the selected relay-history timestamp planes. The result is a normal native
`MetalNumiBrainCheckpoint`, with exact target generation and physical-checkpoint binding.

`MetalPreparedBrainRecoveryMaterial.restoreIsolatedBrain(...)` then:

- Requires the restored physical owner's actual acceptance token and physical checkpoint identity to
  match the preserved native records.
- Obtains a new unpublished handle from the application's already-admitted species/parameter/policy factory.
- Calls the existing `MetalNumiBrainHandle.loadCheckpoint`, which creates and validates a separately
  allocated native runtime before replacing the candidate handle's runtime.
- Saves that restored native checkpoint and requires equality with the requested paired checkpoint.

The factory must not return a currently serving agent. Trained-policy evidence validation remains in
the existing factory; recovery neither bypasses it nor invents a new authorization mechanism. Keep
the global suite publication fence closed until physical, archive and other required owners have
also restored and verified their state. Returning a reconstructed brain handle is not by itself
atomic publication of the physical body or proof that the archive owner has installed its pages.

## Regression sources to execute

```sh
swift build
swift test --filter BrainPreparedGPURecoveryTests
swift test --filter BrainJointPreparedPayloadStoreTests
swift test --filter BrainPreparedNativeReceiptsTests
swift test --filter MetalPreparedFastRootImageTests
```

The tests cover payload-versus-record-ID journal offsets; missing and altered participant files;
symlinks/FIFOs; store reopen and irreversible decisions; exact native receipt identity; missing or
duplicate fast ranges; wrong immutable metadata; selected relay planes; future timestamps; byte
budgets; and paired recovery from a decided store. Artifact fixtures are explicitly synthetic. The
opaque physical/archive fixture strings in storage tests are not native physical-state adapters and
must never be used to claim a successful full-suite restoration.

## Remaining owner-level work

This increment supplies callable native capture and paired restore, not universal automatic crash
recovery. Remaining work is explicit:

- Place capture and persistence into each actual native owner's prepare sequence, maintaining the
  quarantine until capture and durable writes finish. Persist the same owner's decision and native receipts.
- Connect the physical solver's full prepared-state serializer and archive installation through the
  suite's common publication fence. Authenticate or otherwise trust actual producer identities at
  the application boundary; a matching JSON receipt alone is not independent proof of restored physics.
- Preserve any additional owner-managed state not represented by the paired checkpoint, including
  required NumiTissue participant state and external immutable artifacts.
- Execute cross-process failure injection after payload publication, after prepare, after decision,
  during GPU upload and during final suite publication. Verify new allocation addresses and exact continuation.
- Measure staging-memory peak, copy latency, file synchronization and restart latency on the target Mac.

This work does not enable CL1 or FinalSpark physical stimulation. Their independently enforced
hardware safety requirements and biological validation remain separate gates.

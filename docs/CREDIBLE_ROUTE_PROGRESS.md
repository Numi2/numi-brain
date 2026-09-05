# Integrity repairs and the first physical-outcome learning route

Status: source implementation in progress, not all gates completed.
Work began from `1381cd2c4fea9ed04ff1d4be70a2e47ea4651d3c` and preserves concurrent
GPU prepared-state recovery work. Changes are committed directly to main without
force-pushing. No native result from an older revision is relabeled as this one.

## Implemented repairs

- Gate manifests are declarations. Qualified declarations need evidence names,
  but hashes/status labels do not mint admission authority. The old
  `promotionReady` property fails closed; `declaredPromotionReady` is inspection
  only. `numi-brain-qualify verify` exits 2 rather than claiming verification.
  Existing gate-specific production policy receipts are unchanged.
- Safety vectors, envelopes and heartbeats validate during decoding. Campaigns
  require their exact predeclared response, not merely anything other than
  allow. Actual incidents with exposed shadows remain retainable failures.
- Host admission receipts are controller-specific, single-use and superseded by
  reevaluation. Rejection does not advance accepted state. Scalar-only recovery
  reset fails closed. This actor is bookkeeping, not a replacement for the
  existing mandatory GPU protective motor gate or physical publication proof.
- The watchdog can retain state across polls, detect stale/regressed/restarted,
  missing/malformed observations and stalled committed progress, and latch a
  sticky safe-state request. A marker is not an independently enforced physical
  stop; that integration remains explicitly open.
- Shared bounded file I/O anchors directory descriptors, rejects symlinks and
  nonregular leaves before reading, supports create-only publication and atomic
  replacement, and provides nonblocking single-writer locks. Durable writes
  synchronize before publication and synchronize the directory afterwards.
- Semantic recovery v2 hashes the complete encoded brain state and archive,
  recomputes every journal record, rejects illegal decision sequences and never
  removes the old archive before replacement. Legacy v1 archives are retained
  but refused, not silently migrated. The concurrently developed native GPU
  candidate image/store format and joint-recovery ownership remain separate.
- Performance attempt ledgers distinguish acceptance, rejection and command
  faults. Only accepted physical time contributes to progress. Failure latency,
  retries, incomplete environments, unknown publication after command failure,
  worst-environment latency and stalled environments stay visible. Legacy v1
  summaries can be inspected, not used to assert accepted progress.
- Sensor scalar decoding now requires a reviewed validity mask. Gate D schema
  version 2 replaces the unsafe universal-bit-zero assumption; absence of a
  validity payload does not become a valid physical observation. The same
  decoder serves Gate D and the new reach/hold adapter.

## The implemented experiment route

`numi-brain-experiment` is one thin frontend over the EXISTING
`MetalNumanXGateCRootRunner`. It does not implement another physical solver,
CPU neural stepper, or production GPU timeline. It supplies ordinary
body-targeted goals, uses the existing protective motor path and enables the
production uncertainty gate. It retains configurations, native run transcripts,
physical objective results, parameter probes and unevaluated successors.

The first native task is deliberately **one-dimensional head-relative
reach-and-hold**, not arm reaching, balance, locomotion or generalist behavior.
The generic numerical objective supports one to three dimensions, but the
native adapter admits only the reviewed vestibular layout: one receptor,
22 FP32 features, body-0 world-z at index 2 and body-23 world-z at index 15.
Each value requires its own validity bit. The task measures head z minus root z
and targets body 23. Adding other coordinates requires native-owner semantics;
a field position or label is not sufficient evidence of anatomical meaning.

The objective is integrated normalized position error plus a declared weight
on mean squared muscle excitation. Success additionally requires bounded
terminal hold error, bounded terminal secant speed, bounded excitation effort
and no rejected or failed attempts. Excitation squared is NOT measured work,
tendon force, fatigue or metabolism. Secant speed cannot resolve motion between
samples; native velocity observations and capture-rate studies remain needed.

The minimum declared physical horizon is one second and the minimum terminal
hold is 250 milliseconds. At the existing 100-microsecond cadence, a one-second
study requests 10,002 roots: bootstrap plus initial and terminal input samples.
Root count alone cannot pass: actual receptor timestamps must span the exact
horizon without excessive gaps. Repeated identical acquisitions are counted
once; changed contents at the same acquisition time fail.

Gate C samples occur BEFORE each attempted root. This adapter does not invent
post-root endpoint data. Receptor acquisition time controls position scoring;
actual accepted command-application intervals independently control effort.
The capture is artifact-heavy offline research, not a throughput benchmark.

### Local physical-loss update

`MLXPhysicalMotorCalibration` produces small two-sided probes of motor coordinate
3 or 4, checks all unrelated bytes remain identical, and accepts only verified
reach/hold evaluations for the corresponding probe publications. Source, native
model, task, scene, object, body, episode, random seed, objective, goal and initial
observed relative height must match. Update settings are hashed into BOTH frozen
capture protocols; a post-hoc changed resolution floor or learning rate fails.

A resolved physical-loss difference supplies a secant gradient. MLX applies the
clipped gradient and trust-radius-limited FP32 parameter update off rollout.
Unselected payloads are reused exactly. No change is emitted for an unresolved
signal. This is outcome-based local calibration, NOT actor-critic training,
whole-model differentiation, state-of-the-art learning, or a successful task.
Matching initial observations is not proof of equal complete checkpoints.

Research publications deliberately contain no fabricated standard learner
update or `.nbpolicy` receipt. Every proposed successor needs a fresh matched
parent/candidate evaluation and independent held-out episodes. A lower training
loss alone cannot promote a policy, establish adaptation or prove biology.

## Executable workflow

Use the supported Apple host and real native assets. The templates under
`Examples/ReachHold/` contain explicit placeholders; they are not a fabricated
experiment or a passing default. The settings template has a zero resolution
floor and is deliberately invalid until a justified positive floor is declared.
The task tolerances in the example are authored research choices, not validated
physiological or clinical limits. Review target feasibility and physical scales
against the actual model before capture.

Create one existing absolute nonsymlinked artifact directory outside tracked
source. Set its path in each configuration. Use the native owner's actual model
fingerprint and the exact runtime source revision, not a guessed number.

```sh
swift run -c release numi-brain-experiment seed --config seed.json
swift run -c release numi-brain-experiment freeze-settings --config settings.json
swift run -c release numi-brain-experiment probe --config probe-negative.json
swift run -c release numi-brain-experiment probe --config probe-positive.json
```

Seed/probe outputs include the exact publication SHA and parameter fingerprint.
Set each arm's protocol parameter fingerprint to its OWN publication. Retain
all other matched task inputs. Put the canonical settings SHA returned by
`freeze-settings` into both protocols; do not substitute a hash of differently
formatted JSON. Then freeze each protocol separately:

```sh
swift run -c release numi-brain-experiment freeze-protocol --config protocol-negative.json
swift run -c release numi-brain-experiment freeze-protocol --config protocol-positive.json
swift run -c release numi-brain-experiment capture --config capture-negative.json
swift run -c release numi-brain-experiment capture --config capture-positive.json
swift run -c release numi-brain-experiment evaluate --config evaluate-negative.json
swift run -c release numi-brain-experiment evaluate --config evaluate-positive.json
swift run -c release numi-brain-experiment calibrate --config calibrate.json
```

Evaluation exits 1 for a retained failed task. Invalid evidence exits 65. Keep
failed attempts, do not relax thresholds to make them pass. A command failure
retains completed root identities and a separate error artifact rather than
fabricating an accepted/rejected terminal root. An unresolved physical response
is an informative failure, not permission to train from arbitrary gain targets.

Next capture the immutable parent and the proposed successor on NEW held-out
conditions, with new frozen protocols, and require actual useful improvement
and retained safety. Do not overwrite training artifacts or call reused scene
identifiers independent physical experiments.

## Consolidation performed and remaining ownership

| Function | Owner / decision |
|---|---|
| Root stepping and publication | Existing native root runner and GPU root protocol; reused, not reimplemented |
| Physical task arithmetic | `NumiBrainValidation/ReachHoldObjective.swift`; independent offline reference |
| Retained physical observation decoding | `PhysicalSensorField`; one decoder with explicit per-field validity |
| Artifact I/O | Shared `QualificationFileDirectory` for repaired diagnostic, watchdog and semantic recovery boundaries; existing cryptographic capture verifier remains intact |
| Slow parameter update | MLX only; research proposals distinct from standard trained-policy provenance |
| Safety enforcement | Existing GPU protective path; the host actor is not a second physical authority |
| Restart | Semantic archive and native candidate arenas remain distinct typed sections; joint physical owner remains authoritative |

`scripts/inventory-functions.py` creates a read-only lexical inventory with
source hashes, declaration locations, same-name call candidates and ownership
hints. It is NOT a compiler call graph, runtime coverage, or proof that a
function is unused. Native callbacks, overloads, operator/constructor calls and
string-bound shader entries need explicit review. It never authorizes deletion.

```sh
python3 scripts/inventory-functions.py --output /absolute/path/function-inventory-REVISION.json
```

Do not build a general model compiler merely to remove a few duplicated heads.
Next consolidate the actual observation/recurrent/action contract against
measured task behavior, preserving independent reference tests. Remove dormant
modules only after real call-path and intervention evidence, not lexical counts.

## Work NOT completed by these commits

1. A true all-gates verifier consuming authoritative evidence for A through F.
   Declaration-only success is disabled; missing adapters are not replaced by
   trusted Booleans.
2. Independent watchdog stop enforcement and acknowledgement, mandatory native
   force/thermal/actuator limit instrumentation, and complete deployment fault
   campaigns. The repaired host actor is not newly wired into native authority.
3. A native post-commit full-state/force-ledger observer, production low-overhead
   timing/counter collector and verified outcome-ledger adapter. V2 supplied
   ledgers remain diagnostic until their actual measurement/evidence is linked.
4. Complete paired brain-plus-physics checkpoint restoration for causal probes.
   Preserve the concurrent GPU candidate recovery work and finish the native
   physical participant before calling probes identical-state experiments.
5. A generated single-source MLX/Metal model contract, morphology-conditioned
   recurrent motor learning, actor-critic residual adaptation, long-horizon
   useful memory, cross-embodiment transfer and biological calibration.
6. Empirical proof that this task succeeds or that the proposed update improves
   it. No native rollout, Apple MLX execution or performance claim is made here.

## Verification actually performed

Swift 6.2.1, x86_64 Linux: **38 focused XCTest cases passed, zero failures** in an
isolated package of the authored Foundation boundary/reference source files.
This covers 27 qualification/I/O/safety/attempt cases plus 11 physical-objective
and sensor-field cases. The portable watchdog CLI also executed a missing-file
case and produced a sticky stop request with exit 1. This was NOT a full
repository build, an Apple test, or hardware stop enforcement.

The Core admission/recovery/experiment integration and MLX/native experiment
source were syntax-parsed only. Their Apple-target tests are authored but were
not executed here. Syntax parsing is not type checking. The source inventory
script executed against the partial local working snapshot, not the full repo;
no claim of complete function usage or removability is made.

```sh
bash scripts/validate-credible-route-portable.sh
# Supported Apple host, native prerequisites available:
swift test --filter BrainSafetyAdmissionTests
swift test --filter BrainRecoveryRecordTests
swift test --filter BrainGateDValiditySchemaTests
swift test --filter BrainReachHoldProtocolTests
swift test --filter MLXPhysicalMotorCalibrationTests
```

The prior Gate D/E/F “source complete” descriptions are not the completion
status of this work. Implementation, integration, measured capability and
production admission remain distinct.

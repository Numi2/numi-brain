# NumanX Gate C — learned embodied foundation policy

Gate C is a capability and evidence gate, not a runtime-architecture gate. A
parameter update, a passing simulation task, or a manifest containing passing
numbers is insufficient. Promotion requires one immutable learned policy, the
exact data and split provenance that produced it, retained evaluation artifacts,
and rerunnable held-out evidence through the authoritative NumanX transaction.

## Promotion requirements

The current Gate C contract requires all of the following:

1. A vision-language-action policy or an equivalent multimodal hierarchical
   embodied policy running on the Metal GPU timeline.
2. Exact binding to the species, runtime program, learned parameter bytes,
   whole-body controller, and hard safety program that execute the policy.
3. Multimodal pretraining, simulation demonstrations, and real or independently
   sourced embodiment data with revision, license, URI, and SHA-256 provenance.
4. Autoregressive, diffusion, or chunked action generation evaluated under one
   declared inference-latency budget.
5. Disjoint training, validation, held-out task, scene, object, embodiment,
   adaptation, and safety partitions with content-addressed membership and a
   retained split-integrity report.
6. Few-shot adaptation reporting examples, wall-clock training, and retained
   prior-task performance.
7. Long-horizon evaluation covering delayed consequences, interrupted tasks,
   and observationally aliased states.
8. Calibrated uncertainty and out-of-distribution handling that can request
   supervision or reject the physical root before publication.
9. Evidence that the learned controller cannot bypass the existing protective
   motor and root-rejection path.
10. Cross-task, scene, object, and embodiment results from independently retained
    evaluation artifacts, not training telemetry.

Comparisons with generalist robotics systems are permitted only after NumanX
runs comparable held-out tasks. Model size, a changed action, or successful
loading is not comparative generalist evidence.

## Packaged policy boundary

`BrainFoundationPolicyPackage` is the version-1 candidate package. It contains:

- the exact learned `BrainParameterPublication` and all immutable parameter
  bytes;
- a canonical SHA-256 over those ordered bytes and a canonical SHA-256 over the
  complete package;
- model family, revision, input modalities, goal interface, action-generation
  method/horizon, precision, latency budget, and uncertainty thresholds;
- species, regional program, somatic controller, and hard-safety fingerprints;
- dataset source and split manifests; and
- one thresholded, content-addressed result for every Gate C qualification axis.

Developmental seed publications are rejected. Duplicate partition membership,
unknown datasets, incomplete provenance, missing axes, failed declared metrics,
or parameter/model identity drift are rejected. Encoding uses sorted-key JSON,
round-trips byte-identically, and supports atomic `.nbpolicy` writes.

`MetalNumiBrainHandle.create(configuration:policyPackage:)` admits a package only
when its complete evidence manifest is present and its species, enabled sensor
set, regional program, autoregressive planning horizon, somatic-synergy catalog,
protective motor profile, and learned parameter bytes match the actual runtime.
Candidate evaluation must opt out explicitly; it still retains all structural
and runtime identity checks.

The inspection tool is:

```sh
swift run numi-brain-policy inspect candidate.nbpolicy
swift run numi-brain-policy validate candidate.nbpolicy
```

`validate` means that the content-addressed evidence manifest is complete and
its declared metrics satisfy their thresholds. It deliberately does **not**
mean that Codex or the CLI reran, reproduced, or independently authenticated the
referenced datasets and evaluations.

## Current evidence and remaining work

The package boundary is executable: focused Core tests prove deterministic
round-trip, atomic write, exact publication recovery, seed rejection, tamper
rejection, split-alias rejection, incomplete-axis rejection, and failed-metric
rejection. A focused Apple Metal test proves default complete-manifest admission,
explicit candidate admission, exact learned-version loading, and fail-closed
hard-safety identity drift.

Gate C remains open. There is no retained production dataset manifest, no
production `.nbpolicy`, no independently sourced embodiment cohort, no
same-latency action-generation comparison, no cross-task/scene/object/body
benchmark, no few-shot retention curve, no long-horizon delayed/interrupted/
aliased-state suite, and no calibrated OOD rejection report. The present v11
Gate B learner is a small bounded successor update, not a generalist foundation
policy. Those missing artifacts and physical results—not additional schema—are
the next promotion work.

At this checkpoint the four focused package/Metal tests pass, the complete
Swift package passes 154 tests with seven intentionally unconfigured bridge/
stress skips and zero failures in 63.356 seconds, `git diff --check` is clean,
and a fresh production build including `numi-brain-policy` passes in 86.85
seconds. These are implementation-correctness and build results, not Gate C
task-performance evidence.

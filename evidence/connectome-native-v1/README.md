# Native connectome integration evidence

Date: September 7, 2026, America/Los_Angeles (CI timestamps use UTC September 8).

## Published source and Apple execution

Source publication: `dea0bbcb991b0adf6be8de0ff9c8462ab52dec0d`.
CI run: `34173283415`; job: `101897629163`.
Host: macOS 26.6.2, Xcode 26.6, Swift 6.3.3, arm64.

- `numi-brain-connectome` release build passed.
- `numi-brain-experiment` release build passed, including the normal Metal factory
  and protected actuator integration.
- Seven connectome tests passed, zero failures. The Metal recurrence/readout
  test executed and passed; it was not skipped.
- Fourteen prepared-GPU recovery regressions passed.
- Three all-gates qualification boundary regressions passed.
- Twenty-two C++ native tests and four initial Arrow/import tests passed.
- Source-model executable contract check passed.

The workflow published only after these checks through a non-forced fast-forward
and removed its own temporary integration payload. Existing source-constrained
Human/Matter configuration changes were preserved. This run does not include
the later `MetalConnectomeRootTests` added with the audited neuronal scope fix.

Retained CI artifact: `10036641797`.
Archive SHA-256: `0229dd6b0283234da3297e2755a0374f165e56be3d220ca9e1f8bd31e60eeb8f`.

## Official source acquisition and compilation

Audited release compilation run: `34173965507`.
Source-annotation audit run: `34173532811`.
Data artifact: `10036630660`, `male-cns-v1.0-classified-neuron-pack`.
Artifact ZIP SHA-256: `091d67ee9b8045e5d713f75d2468c4f525ad06e7404af1c0f8e9a8c5649856d6`.

The compilation retained 166,700 classified neuronal entries, 25,582,938 directed
weighted pairs and 217 isolated neurons. It excluded 44,877 non-neuronal or
unclassified annotation records and explicitly counted all unmatched source
edge rows. The initial diagnostic compilation included 211,577 annotation
records and is superseded; it must not be labeled a 211,577-neuron brain.

Audited NUMICNS1 fingerprint: `5e1e89f366e0157a`.
Audited pack SHA-256: `58314f44a02afe0726e5ba699a533d203b85b2fd6125bc0542b5db72cf993a1c`.
The downloaded pack was independently accepted by the local native C++ reader.

Original v1.0 source SHA-256 pins:

- annotations: `2177e246113e4cfbf1e7772ec37c6da1955ff22e8063d0b1f833101f99a9a3b2`
- neurotransmitters: `95c9289220663abeb3409f3ad9e5a7f8a53f8093f5139d15502cd08da8879621`
- weights: `e35da783d1c686b2b58b3b87cd6a403ae43bfcfba8bff28e08ef752c1a56afc1`

## Interpretation

The released connectivity is real data. The unsigned normalized weights and
bounded rate dynamics are declared modeling assumptions. The pair count is not
the number of individual synapses. Source import/build tests do not establish
full-graph GPU performance, valid electrophysiology or successful embodiment.

Normal-root fixtures use synthetic physical receipts, explicitly identified in
the test source. They exercise software ownership and neural/motor computation,
not a solved robot-control task. No learned decoder, training result, physical
robot outcome or production qualification is claimed by this record.

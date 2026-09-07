# Generated executable MLX/Metal model contract

`Contracts/NumiBrainExecutableModelV1.json` is now the canonical source for the
committed-transition ABI and the deployed sensor-conditioned somatic policy-head
dimensions/indices. The generator emits a Swift contract consumed by MLX and a
Metal header for native shader migration. CI regenerates both into temporary
files and fails if checked generated outputs drift.

The checker also validates the current production Metal arena stride and
`NBCommittedTransitionRecord` version, flags and array widths against the same
contract. This makes existing Metal literals a checked compatibility surface
while they are progressively replaced by generated macros; they can no longer
silently change independently of MLX.

The MLX policy head now consumes generated recurrent, observation, tail-fold,
synergy and parameter-index constants rather than maintaining its own numeric
copy. This is a contract consolidation change, not a model-capability claim and
not evidence that training or physical behavior improved.

Regenerate after an intentional ABI/model change:

```sh
python3 scripts/generate-executable-model-contract.py
python3 scripts/check-executable-model-contract.py
```

Any record-layout change requires the normal format-version migration and
retained compatibility decision. Do not edit generated files directly.

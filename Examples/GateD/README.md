# Gate D executable examples

`energy-pass.json` is an authored balanced-energy fixture. `energy-fail.json`
adds one unaccounted joule and must exit 1. `tangent-inconclusive.json` changes
an active set and must exit 2 instead of claiming smooth derivative agreement.

`synthetic-force.sto` is authored synthetic data, not experimental biological
measurements. `force-import.json` selects its scalar force column without
fitting, filtering, retargeting, or unit conversion.

`trace-protocol.template.json` is intentionally invalid. Replace every marked
identity, the zero physical scale and duration, and all experiment thresholds
with a reviewed, predeclared protocol. Its source, schema and reference hashes
must resolve to retained artifacts. Do not substitute these synthetic fixtures
for the independent evidence required for Gate D.

See `docs/NUMANX_GATE_D_REQUIREMENTS.md` for commands and ownership boundaries.

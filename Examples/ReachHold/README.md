# Physical reach-and-hold study templates

These are configuration templates, not native experiment evidence. Replace
absolute paths, source/model/parameter identities and artifact SHA placeholders.
Choose and predeclare a positive physical-loss resolution floor; the zero in
`settings.template.json` intentionally fails validation. Review the authored
position, hold and effort thresholds against the real native model.

The native task is only body-23 head height relative to body-0 along world z.
It does not claim arm reaching, balance, biological calibration or generalist
behavior. The goal is emitted through the normal muscle-control path.

Use `freeze-settings` to get the canonical settings SHA before freezing the
negative/positive protocols. The negative/positive probes modify only coordinate
3 in this template; coordinate 4 is the other supported local motor gain.
Never change both at once in a single-coordinate study.

`seed` and `probe` report both publication SHA and parameter fingerprint.
Each capture protocol must name that arm's exact parameter fingerprint.
Each capture configuration must name its own frozen protocol SHA and publication
SHA. The two arms must keep native model, task, geometry, seed and objective
matched. A paired observation is not proof of an identical complete checkpoint.

`calibrate` consumes verified physical losses, not manually entered scores.
It refuses rejected or unresolved evidence and emits an UNEVALUATED successor.
Capture fresh parent/candidate and held-out runs before interpreting that
successor as a behavioral improvement. See `docs/CREDIBLE_ROUTE_PROGRESS.md`.

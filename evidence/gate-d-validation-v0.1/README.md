# Gate D reference implementation checks

Date: 2026-09-04. Environment: Swift 6.2.1, x86_64 Linux.
Runtime base: `59892e55eca06dc00d3fb80f0979afd9ef419e26`.

`portable-validation.log` is a bounded verbatim excerpt of the isolated reference package and
CLI harness output (`scripts/validate-gate-d-portable.sh`): 55 XCTest tests passed,
zero failures. The harness includes authored positive/negative/inconclusive examples and
synthetic OpenSim import; the full local log is retained separately. `cli-smoke.log` additionally records exact exit codes
for six separate CLI invocations, including usage and malformed-data errors.

`source-sha256.json` binds the exact reference/CLI/Core integration sources,
repository manifest, tests, examples and script for this implementation. The
manifest's membership does not expand what was tested: Apple-only integration
and its six Core tests were parsed but not compiled or executed here.

This original log is not a full NumiBrain build, an Apple execution result,
physical or biological calibration, an independent dataset evaluation, or Gate
D promotion. The tests verify the reference algorithms and diagnostic command
behavior, not that NumanX's native physical model satisfies the evaluated
equations.

`apple-validation.log` records the later Apple M4 Pro Mac mini follow-up. It
includes the corrected deployment-target harness, the six Core integration
tests, the 55 validation tests, and the full package result (245 passed, 9
explicit skips, zero failures). The skips are retained separately because the
real NumanX bridge paths are not configured. This follow-up still does not
constitute native physical qualification.

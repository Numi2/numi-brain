# Connectome decoder development evidence

Base source: f2cdb88ce41245b3d9b87565476dcf27e59b88aa.
The earlier audited 7-file final-source increment is included, with its
checkpoint diagnostic corrected to the actual `sha256` property.

## Recorded boundary before this increment

Run 34176206539 compiled the owning Apple modules and passed seven core/shader
tests. Four production-root tests were skipped because Metal 4 command creation
was unavailable; the explicit full-source root test failed for that same reason.
It did not publish its staged source. No successful full-root result is inferred.
The larger-runner probe 34176647924 failed before any job steps executed; it
provides no hardware capability measurement.

## Portable checks performed

The updated native frontend passed 22 tests under strict C++20 warnings. The
local import suite passed four tests and skipped two that require PyArrow; CI
installs PyArrow to execute those cases. The actual retained full neuronal pack
passed the native C++ reader with 166700 nodes, 25582938 directed pairs,
fingerprint 5e1e89f366e0157a, size 216144031 bytes and SHA-256
58314f44a02afe0726e5ba699a533d203b85b2fd6125bc0542b5db72cf993a1c.
New Swift files passed frontend syntax parsing, which is not an Apple SDK build.

## Scope

Core regressions cover decoder identity, preserved topology, exact artifact
retention/recompilation, legacy-byte compatibility, scope downgrade rejection
and native execution-program linkage. MLX tests cover selected-coordinate
updates, bounded probes, unchanged unselected weights, loss rejection and
missing-evidence rejection. Their synthetic values are arithmetic fixtures,
not physical outcomes. The full-graph shader regression uses a declared
synthetic recurrent state and compares sampled destinations against a CPU
reference; it does not replace or qualify the production Metal 4 command path.

No physical decoder-learning campaign or trained robotic skill was executed
in this environment. Updated Apple build and execution results are appended
only after the named CI job actually succeeds.

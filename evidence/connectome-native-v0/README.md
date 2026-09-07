# Connectome native-source verification, 2026-09-07

Base: `b3ff9883bd42d5274114598e49d01d7e0ae0c538`.
Initial native pack commit: `7e5f32eeb46d14e7c77c07cd70eb5a103d505f59`.

Environment: Linux x86_64, clang++ C++20, Swift 6.2.1. No Apple Metal SDK or GPU.

Executed:

- `python3 tools/test_connectome_native.py`: 18/18 tests passed. The command
  compiles the real C++ validator with `-Wall -Wextra -Wpedantic -Werror`.
- Standalone compilation/link/execution of the actual `ConnectomeGraph.swift`
  implementation with its C++ ABI: graph identity, labels, projection offsets,
  distinct species fingerprints and invalid projection rejection passed.
- Earlier NumiLab synthetic NUMICNS1 pack: 4 nodes / 3 edges, fingerprint
  `54963d204b21c364` validated without conversion.
- New Swift files passed frontend syntax parsing. This is not Apple compilation.
- The reconstructed pre-change joint-transaction file's Git blob is exactly
  `fa7bac189553b27aad5471d0fb3104cac29822a2`, matching the fetched upstream file;
  only the optional connectome participant and its publication guards differ.

Not executed: complete SwiftPM package tests, Metal shader compilation,
Metal kernel/root transaction tests, full-release graph runtime, robot decoder
training, embodied simulation, throughput or physical-outcome measurements.

The tests added for Apple execution are `ConnectomeGraphTests` and
`MetalConnectomeKernelTests`. The latter checks recurrence, signed output,
readout, fractional timesteps and per-scalar validity. Their presence is not a
passing test result. No qualification receipt is minted by this report.

#!/usr/bin/env python3
"""Test exact owning sources, with an optional real MLX decoder-learner build.

The repository's full package remains authoritative. This read-only harness
copies its exact owning source modules and selected existing tests; it does not
supply substitute implementations, physics or mock Metal backends.
"""
from pathlib import Path
import hashlib
import argparse
import os
import json
import platform
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MODULES = ['NumiBrainABI', 'NumiBrainConnectomeABI', 'NumiBrainValidation',
           'NumiBrainQualification', 'NumiBrainCore', 'NumiBrainMetalBridgeABI', 'NumiBrainMetal']
TESTS = {
    'NumiBrainCoreTests': ['ConnectomeGraphTests.swift', 'ConnectomeControllerTests.swift', 'ConnectomeDecoderStudyTests.swift'],
    'NumiBrainMetalTests': ['NumanXInteropTests.swift', 'MetalConnectomeKernelTests.swift', 'MetalConnectomeRootTests.swift', 'ConnectomeDecoderForkTests.swift'],
}
MANIFEST = '''// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "NumiBrainConnectomeFocus", platforms: [.macOS("26.0")], targets: [
.target(name: "NumiBrainABI", publicHeadersPath: "include"),
.target(name: "NumiBrainConnectomeABI", publicHeadersPath: "include"),
.target(name: "NumiBrainValidation"),
.target(name: "NumiBrainQualification"),
.target(name: "NumiBrainCore", dependencies: ["NumiBrainABI", "NumiBrainConnectomeABI", "NumiBrainValidation", "NumiBrainQualification"]),
.target(name: "NumiBrainMetalBridgeABI", dependencies: ["NumiBrainABI"], publicHeadersPath: "include"),
.target(name: "NumiBrainMetal", dependencies: ["NumiBrainABI", "NumiBrainConnectomeABI", "NumiBrainCore", "NumiBrainQualification", "NumiBrainMetalBridgeABI"], resources: [.process("Shaders")]),
.target(name: "NumiBrainConnectomeTestSupport", path: "Tests/NumiBrainConnectomeTestSupport"),
.testTarget(name: "NumiBrainCoreTests", dependencies: ["NumiBrainCore", "NumiBrainABI", "NumiBrainConnectomeABI", "NumiBrainConnectomeTestSupport"]),
.testTarget(name: "NumiBrainMetalTests", dependencies: ["NumiBrainCore", "NumiBrainMetal", "NumiBrainABI", "NumiBrainConnectomeABI", "NumiBrainMetalBridgeABI", "NumiBrainConnectomeTestSupport"]),
], cxxLanguageStandard: .cxx20)
'''

def main():
    if platform.system() != 'Darwin':
        raise SystemExit('Apple SDK/Metal test harness requires macOS; it does not fall back to another backend.')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--with-learning', action='store_true', help='Build the real decoder learner, experiment CLI and pinned MLX dependency')
    parser.add_argument('--require-metal4', action='store_true', help='Require and execute the full production-root test scope; never accept hardware skips')
    options = parser.parse_args()
    if options.require_metal4 and not os.environ.get('NUMIBRAIN_CONNECTOME_GRAPH'):
        raise SystemExit('--require-metal4 also requires NUMIBRAIN_CONNECTOME_GRAPH for the full-source root')
    if options.with_learning:
        required = ['Sources/NumiBrainCore/Connectome/ConnectomeCaptureIdentity.swift',
                    'Sources/NumiBrainCore/Connectome/ConnectomeDecoderStudy.swift',
                    'Sources/NumiBrainMLX/MLXConnectomeDecoderCalibration.swift',
                    'Tests/NumiBrainCoreTests/ConnectomeDecoderStudyTests.swift',
                    'Tests/NumiBrainMetalTests/MLXConnectomeDecoderCalibrationTests.swift']
        missing = [name for name in required if not (ROOT/name).is_file()]
        if missing: raise SystemExit('Decoder integration source is not present: ' + ', '.join(missing))
    if options.require_metal4 and not (ROOT/'Tests/NumiBrainMetalTests/MetalConnectomeRootTests.swift').is_file():
        raise SystemExit('Production-root test source is missing; root execution cannot be selected.')
    with tempfile.TemporaryDirectory(prefix='numi-connectome-apple-') as directory:
        work = Path(directory)
        for module in MODULES:
            shutil.copytree(ROOT/'Sources'/module, work/'Sources'/module)
        shutil.copytree(ROOT/'Tests/NumiBrainConnectomeTestSupport', work/'Tests/NumiBrainConnectomeTestSupport')
        for target, files in TESTS.items():
            destination = work/'Tests'/target; destination.mkdir(parents=True)
            for name in files:
                source = ROOT/'Tests'/target/name
                if not source.is_file():
                    if name in ['ConnectomeDecoderStudyTests.swift', 'MetalConnectomeRootTests.swift']: continue
                    raise SystemExit('Required test source is missing: ' + str(source))
                shutil.copy2(source, destination/name)
        manifest = MANIFEST
        if options.with_learning:
            target = work/'Sources/NumiBrainMLX'; target.mkdir(parents=True)
            for name in ['MLXPhysicalMotorCalibration.swift', 'MLXConnectomeDecoderCalibration.swift']:
                shutil.copy2(ROOT/'Sources/NumiBrainMLX'/name, target/name)
            shutil.copytree(ROOT/'Sources/NumiBrainExperimentCLI', work/'Sources/NumiBrainExperimentCLI')
            shutil.copy2(ROOT/'Tests/NumiBrainMetalTests/MLXConnectomeDecoderCalibrationTests.swift',
                         work/'Tests/NumiBrainMetalTests/MLXConnectomeDecoderCalibrationTests.swift')
            manifest = manifest.replace('targets: [', 'products: [.executable(name: "numi-brain-experiment", targets: ["NumiBrainExperimentCLI"])], dependencies: [.package(url: "https://github.com/ml-explore/mlx-swift.git", exact: "0.31.3")], targets: [', 1)
            manifest = manifest.replace('.target(name: "NumiBrainConnectomeTestSupport",', '.target(name: "NumiBrainMLX", dependencies: ["NumiBrainCore", .product(name: "MLX", package: "mlx-swift")]),\n.executableTarget(name: "NumiBrainExperimentCLI", dependencies: ["NumiBrainCore", "NumiBrainMetal", "NumiBrainQualification", "NumiBrainMLX"]),\n.target(name: "NumiBrainConnectomeTestSupport",', 1)
            manifest = manifest.replace('dependencies: ["NumiBrainCore", "NumiBrainMetal", "NumiBrainABI",', 'dependencies: ["NumiBrainMLX", "NumiBrainCore", "NumiBrainMetal", "NumiBrainABI",', 1)
            (work/'tools').mkdir()
            shutil.copy2(ROOT/'tools/build_swiftpm_mlx_metallib.sh', work/'tools/build_swiftpm_mlx_metallib.sh')
        hashes = {str(p.relative_to(work)): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in sorted(work.rglob('*')) if p.is_file()}
        print('EXACT_SOURCE_MANIFEST '+json.dumps(hashes,sort_keys=True),flush=True)
        (work/'Package.swift').write_text(manifest)
        selection = 'Connectome' if options.require_metal4 else '(ConnectomeControllerTests|ConnectomeDecoderForkTests|ConnectomeGraphTests|ConnectomeDecoderStudyTests|MetalConnectomeKernelTests|MLXConnectomeDecoderCalibrationTests)'
        print('TEST_SCOPE '+('production Metal 4 roots required' if options.require_metal4 else 'source, kernel and learner only; production root execution NOT selected'), flush=True)
        if options.with_learning:
            subprocess.run(['swift','build','--package-path',str(work),'-c','release','-Xswiftc','-enable-testing','--build-tests'],check=True)
            subprocess.run(['sh',str(work/'tools/build_swiftpm_mlx_metallib.sh'),'release'],check=True)
        subprocess.run(['swift','test','--package-path',str(work),'-c','release','-Xswiftc','-enable-testing','--filter',selection],check=True)

if __name__ == '__main__': main()

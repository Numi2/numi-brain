#!/usr/bin/env python3
"""Qualify the exact owner workload on physical Apple Silicon with Metal 4.

Output and build directories must be new and outside both clean checkouts.
Every command, exit code, source identity, pipeline result and log is retained.
This is a fresh-process construction test, not a purge of driver shader caches.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native-owner', type=Path, required=True)
    parser.add_argument('--numilab-sha', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    brain = Path(__file__).resolve().parents[1]
    lab = args.native_owner.resolve()
    out = args.output.resolve()
    for repo in (brain, lab):
        if out == repo or repo in out.parents:
            parser.error('output must be outside the source checkouts')
    out.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ, PATH='/opt/homebrew/bin:' + os.environ['PATH'])
    steps = []
    result = {'qualified': False, 'steps': steps}

    def write(name, value):
        (out / name).write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + '\n')

    def git(repo, *argv):
        return subprocess.check_output(['git', '-C', str(repo), *argv], text=True).strip()

    def run(name, argv, cwd=brain):
        argv = [str(v) for v in argv]
        write(name + '-command.json', {'argv': argv, 'cwd': str(cwd)})
        start = time.monotonic()
        with (out / (name + '.txt')).open('x') as log:
            completed = subprocess.run(argv, cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT)
        step = {'name': name, 'exit_code': completed.returncode,
                'seconds': time.monotonic() - start, 'log_sha256': sha(out / (name + '.txt'))}
        steps.append(step)
        write(name + '-result.json', step)
        print(json.dumps(step), flush=True)
        return completed.returncode

    def require(condition, message):
        if not condition:
            raise RuntimeError(message)

    try:
        identities = {name: {'sha': git(repo, 'rev-parse', 'HEAD'),
                            'status': git(repo, 'status', '--porcelain')}
                      for name, repo in [('brain', brain), ('numilab', lab)]}
        write('source-identity.json', identities)
        require(all(not v['status'] for v in identities.values()), 'clean source checkouts required')
        require(identities['numilab']['sha'] == args.numilab_sha, 'native owner revision mismatch')
        gpu_env = {k: v for k, v in env.items() if k.startswith(('MTL_', 'METALROBO_', 'NUMI_'))}
        write('gpu-environment.json', gpu_env)
        require(not gpu_env, 'qualification requires the default production GPU environment')
        paths = ['tools/numilab_owner_replay_check.cpp', 'tools/numilab_pipeline_probe.mm',
                 'tools/numilab_hardware_probe.mm', 'tools/numilab_required_kernels.txt',
                 'tools/qualify_numilab_reference.py',
                 'Sources/NumiBrainNumiLabBridgeABI/NumiBrainNumiLabBridgeABI.c',
                 'Sources/NumiBrainNumiLabBridgeABI/include/NumiBrainNumiLabBridgeABI.h']
        source_hashes = {p: sha(brain / p) for p in paths}
        write('workload-hashes.json', source_hashes)
        for name, argv in [('os', ['sw_vers']), ('xcode', ['xcodebuild', '-version']),
                           ('metal', ['xcrun', 'metal', '--version']), ('cmake', ['cmake', '--version'])]:
            require(run(name, argv) == 0, name)
        strict = ['clang++', '-std=c++20', '-fobjc-arc', '-Wall', '-Wextra', '-Wpedantic', '-Werror']
        require(run('hardware-build', strict + [brain / paths[2], '-framework', 'Foundation',
                    '-framework', 'Metal', '-o', out / 'hardware-probe']) == 0, 'hardware build')
        require(run('hardware', [out / 'hardware-probe']) == 0, 'physical Apple Silicon Metal 4 required')
        hardware = json.loads((out / 'hardware.txt').read_text())
        require(hardware['metal4'] and hardware['apple_families'] and
                'paravirtual' not in hardware['device_name'].lower(), 'unsupported reference device')
        result['hardware'] = hardware
        source = (lab / 'src/metal/MetalWorld.mm').read_text()
        begin = source.index('MetalWorldDiagnostics initializeContext(')
        end = source.index('std::size_t growthCapacity(', begin)
        kernels = sorted(set(re.findall(r'@"(mr_[a-z0-9_]+)"', source[begin:end])))
        inventory = '\n'.join(kernels) + '\n'
        (out / 'required-kernels.txt').write_text(inventory)
        require(len(kernels) == 109 and inventory == (brain / paths[3]).read_text(), '109-kernel inventory drift')
        build = out / 'build'
        require(run('configure', ['cmake', '-S', lab, '-B', build, '-DCMAKE_BUILD_TYPE=Release']) == 0, 'configure')
        require(run('native-build', ['cmake', '--build', build, '--target', 'metalrobo', '-j', '4']) == 0, 'native build')
        library = build / 'lib/libmetalrobo.dylib'
        metallib = build / 'shaders/MetalRobo.metallib'
        write('native-binaries.json', {str(p.relative_to(build)): sha(p) for p in (library, metallib)})
        require(run('pipeline-build', strict + [brain / paths[1], '-framework', 'Foundation',
                    '-framework', 'Metal', '-o', out / 'pipeline-probe']) == 0, 'pipeline probe build')
        pipeline_exit = run('pipelines', [out / 'pipeline-probe', metallib, out / 'required-kernels.txt'])
        records = [json.loads(line.split(' ', 1)[1]) for line in (out / 'pipelines.txt').read_text().splitlines()
                   if line.startswith('NUMILAB_PIPELINE ')]
        result['pipeline_count'] = len(records)
        result['failed_pipelines'] = [r for r in records if not r['success']]
        require(len(records) == 109 and sorted(r['kernel'] for r in records) == kernels, 'incomplete pipeline results')
        # Preserve every pipeline result before admitting any physical run.
        require(pipeline_exit == 0 and not result['failed_pipelines'], 'production pipeline construction failed')
        include = brain / 'Sources/NumiBrainNumiLabBridgeABI/include'
        require(run('bridge-build', ['clang', '-std=c11', '-Wall', '-Wextra', '-Wpedantic', '-Werror',
                    '-c', brain / paths[5], '-I', include, '-o', out / 'bridge.o']) == 0, 'bridge build')
        require(run('replay-build', ['clang++', '-std=c++20', '-Wall', '-Wextra', '-Wpedantic', '-Werror',
                    brain / paths[0], out / 'bridge.o', '-I', include, '-I', lab / 'include', library,
                    '-Wl,-rpath,' + str(build / 'lib'), '-o', out / 'native-replay']) == 0, 'replay build')
        replay_exit = run('replay', [out / 'native-replay', library, metallib])
        replay = [json.loads(line.split(' ', 1)[1]) for line in (out / 'replay.txt').read_text().splitlines()
                  if line.startswith('NUMILAB_NATIVE_REPLAY ')]
        result['replay'] = replay
        require(replay_exit == 0 and sorted(r['robot'] for r in replay) == ['franka', 'g1', 'x500'], 'exact owner replay failed')
        require(run('regression-build', ['cmake', '--build', build, '--target',
                    'metalrobo_task_owner_replay_probe', '-j', '4']) == 0, 'owner regression build')
        require(run('owner-regression', [build / 'bin/metalrobo_task_owner_replay_probe', metallib]) == 0,
                'native owner regression failed')
        for name, repo in [('brain', brain), ('numilab', lab)]:
            require(git(repo, 'rev-parse', 'HEAD') == identities[name]['sha'] and
                    not git(repo, 'status', '--porcelain'), 'source changed during qualification')
        require(all(sha(brain / p) == value for p, value in source_hashes.items()), 'workload changed')
        result['qualified'] = True
    except Exception as error:
        result['error'] = f'{type(error).__name__}: {error}'
    finally:
        result['scope'] = ('109 production pipelines; exact four-step original/replay/changed-action workload; '
                           'Franka/G1/X500; native GPU owner. No neural, learning, task-success or robot-hardware qualification.')
        write('result.json', result)
        write('receipt-hashes.json', {str(p.relative_to(out)): sha(p) for p in sorted(out.iterdir()) if p.is_file()})
    return 0 if result['qualified'] else 1


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""Export actual NumiLab joint/actuator metadata with native kinematics checks.

This is cold compilation, not robot physics stepping. It uses existing native
asset builders and their analytic kinematics without duplicating model tables.
"""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REVISION = '4a369ca846fde93016f3708f3fd9386c992b52a4'
SOURCES = ['RunProgram', 'EngineModel', 'PX4X500', 'G1', 'FrankaHand',
           'SurgicalPSM', 'Franka', 'FrankaEngine', 'ConstraintIR', 'Model',
           'GeometryCooker', 'LocomotionWorld', 'ArticulatedDynamics']


def export(native: Path, destination: Path, revision: str, robots: list[str], cxx: str) -> dict:
    native = native.resolve(strict=True)
    if not re.fullmatch('[0-9a-f]{40}', revision):
        raise ValueError('revision must be a complete lowercase Git commit SHA')
    if not robots or len(set(robots)) != len(robots) or any(not re.fullmatch('[a-zA-Z0-9_-]{1,128}', r) for r in robots):
        raise ValueError('robot IDs must be unique bounded catalog identifiers')
    head = subprocess.check_output(['git', '-C', str(native), 'rev-parse', 'HEAD'], text=True).strip()
    if head != revision:
        raise ValueError(f'native source revision mismatch: {head} != {revision}')
    dirty = subprocess.check_output(['git', '-C', str(native), 'status', '--porcelain', '--untracked-files=all', '--', 'include', 'src/core'], text=True)
    if dirty.strip():
        raise ValueError('native include/src/core contains local modifications or untracked files')
    destination = destination.absolute()
    if destination.exists() or destination.is_symlink():
        raise ValueError('output directory already exists')
    if not destination.parent.is_dir():
        raise ValueError('output parent directory must exist')
    for parent in destination.parents:
        if parent.is_symlink():
            raise ValueError('output parent must not be a symlink')
    source = ROOT / 'tools/export_numilab_robot.cpp'
    with tempfile.TemporaryDirectory(prefix='numi-native-robot-') as temp, \
            tempfile.TemporaryDirectory(prefix='.numi-native-stage-', dir=destination.parent) as stage:
        work = Path(temp)
        common = [cxx, '-std=c++23', '-O1', '-ffunction-sections', '-fdata-sections', '-I', str(native/'include')]
        def compile_one(name: str) -> Path:
            path = native / 'src/core' / (name+'.cpp')
            output = work / (name+'.o')
            subprocess.run([*common, '-c', str(path), '-o', str(output)], check=True)
            return output
        with ThreadPoolExecutor(max_workers=min(4, os.cpu_count() or 1)) as executor:
            objects = list(executor.map(compile_one, SOURCES))
        executable = work/'export-robot'
        strip = '-Wl,-dead_strip' if platform.system() == 'Darwin' else '-Wl,--gc-sections'
        subprocess.run([*common, '-Wall', '-Wextra', '-Wpedantic', '-Werror',
                        f'-DNUMILAB_SOURCE_REVISION="{revision}"', str(source),
                        *map(str, objects), strip, '-o', str(executable)], check=True)
        manifest = {'version': 1, 'nativeRevision': head,
                    'exporterSHA256': hashlib.sha256(source.read_bytes()).hexdigest(),
                    'compiler': subprocess.check_output([cxx, '--version'], text=True).splitlines()[0],
                    'scope': 'cold topology/actuator import; not runtime or robot-task qualification',
                    'files': []}
        for robot in robots:
            data = subprocess.check_output([str(executable), robot])
            decoded = json.loads(data)
            if decoded['robotID'] != robot or decoded['nativeRepositoryRevision'] != head:
                raise ValueError('native exporter identity mismatch')
            (Path(stage)/(robot+'.json')).write_bytes(data)
            manifest['files'].append({'robotID': robot, 'path': robot+'.json',
                                      'sha256': hashlib.sha256(data).hexdigest(),
                                      'bodies': len(decoded['bodyNames']),
                                      'joints': len(decoded['joints']), 'actuators': len(decoded['actuators'])})
        (Path(stage)/'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True)+'\n')
        destination.mkdir()
        try:
            for p in Path(stage).iterdir():
                shutil.move(str(p), destination/p.name)
        except Exception:
            shutil.rmtree(destination)
            raise
        return manifest


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--numilab', required=True, type=Path)
    p.add_argument('--output-dir', required=True, type=Path)
    p.add_argument('--revision', default=DEFAULT_REVISION)
    p.add_argument('--robot', action='append')
    p.add_argument('--cxx', default=os.environ.get('CXX', 'clang++'))
    a = p.parse_args()
    try:
        print(json.dumps(export(a.numilab, a.output_dir, a.revision,
                                a.robot or ['franka_panda', 'unitree_g1', 'px4_x500'], a.cxx), sort_keys=True))
    except (ValueError, OSError, subprocess.CalledProcessError) as e:
        p.exit(1, f'robot import failed: {e}\n')


if __name__ == '__main__':
    main()

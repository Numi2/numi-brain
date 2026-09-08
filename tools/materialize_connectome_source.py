#!/usr/bin/env python3
"""Materialize the reviewed connectome increment locally; never commit or push.

Default is a dry run. --apply changes only the declared source paths after all
patches have been checked in an isolated directory. Exact source hashes prevent
reinterpreting an old staged increment as a newer one. Existing edits are refused.
"""
from pathlib import Path
import argparse
import base64
import difflib
import hashlib
import json
import lzma
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED = ['tools/run_connectome_apple_tests.py',
            'Tests/NumiBrainMetalTests/MetalConnectomeKernelTests.swift']
STAGES = [
    ('connectome-finalize', 2, 'd9246b682ce717093f70208b8fa022d231a0ca6988ee4f0f48168a25fbe5f63c', 48786),
    ('connectome-decoder', 4, 'd8dbd751f4fc957ea9f381747db6e9e71ee580481772ff5b0916dbf788103c09', 93536),
]
CORRECTION = '.numi/connectome-decoder/numerical-publication.patch'
CORRECTION_SHA = '2df6f012ddc58d23dcaf36ddbcd516831e983f12124047cdcf2c58b97ad112f5'

def git(*args, cwd=ROOT):
    result = subprocess.run(['git', *args], cwd=cwd, capture_output=True)
    if result.returncode:
        raise ValueError('git ' + ' '.join(args[:3]) + ': ' + result.stderr.decode(errors='replace'))
    return result.stdout

def digest(data):
    return hashlib.sha256(data).hexdigest()

def snapshot(path):
    if path.is_symlink() or any(parent.is_symlink() for parent in path.parents):
        raise ValueError('refusing symlinked source: ' + str(path))
    return path.read_bytes() if path.is_file() else None

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--expected-head')
    parser.add_argument('--output-patch', type=Path)
    args = parser.parse_args()
    manifest = json.loads((ROOT/'.numi/connectome-decoder/materialized-source.json').read_text())
    if manifest['version'] != 1 or manifest['promotable'] is not False:
        raise ValueError('unsupported or misclassified source manifest')
    expected = manifest['files']
    paths = sorted(expected)
    if not paths or len(paths) > 64:
        raise ValueError('invalid source path count')
    for name in paths:
        p = Path(name)
        if p.is_absolute() or '..' in p.parts or name in EXCLUDED or not name.startswith(('Sources/', 'Tests/', 'tools/', 'docs/', 'evidence/', 'README.md')):
            raise ValueError('unsafe source path: ' + name)
    if args.output_patch:
        output = args.output_patch.absolute()
        if output in {ROOT/name for name in paths} or output.is_symlink():
            raise ValueError('output patch cannot overwrite an affected source or symlink')
    head = git('rev-parse', 'HEAD').decode().strip()
    if args.expected_head and head != args.expected_head:
        raise ValueError('repository HEAD differs from the requested revision')
    before = {name: snapshot(ROOT/name) for name in paths}
    if all(before[name] is not None and digest(before[name]) == expected[name] for name in paths):
        print('Connectome increment is already materialized; no files changed.')
        return
    if git('status', '--porcelain', '--untracked-files=all', '--', *paths):
        raise ValueError('affected source paths contain existing edits; preserve or commit them first')
    with tempfile.TemporaryDirectory(prefix='numibrain-source-') as directory:
        work = Path(directory)
        git('init', '-q', cwd=work)
        for name, data in before.items():
            if data is not None:
                (work/name).parent.mkdir(parents=True, exist_ok=True)
                (work/name).write_bytes(data)
        for name, count, sha, size in STAGES:
            encoded = ''.join((ROOT/'.numi'/name/f'{i:02}.b64').read_text().strip() for i in range(count))
            compressed = base64.b64decode(encoded, validate=True)
            if digest(compressed) != sha:
                raise ValueError('staged source checksum mismatch: ' + name)
            patch = lzma.decompress(compressed)
            if len(patch) != size:
                raise ValueError('staged source size mismatch: ' + name)
            target = work/(name+'.patch'); target.write_bytes(patch)
            exclusions = ['--exclude='+p for p in EXCLUDED]
            git('apply', '--check', '--whitespace=error', *exclusions, str(target), cwd=work)
            git('apply', '--whitespace=error', *exclusions, str(target), cwd=work)
        correction = (ROOT/CORRECTION).read_bytes()
        if digest(correction) != CORRECTION_SHA:
            raise ValueError('numerical correction checksum mismatch')
        target = work/'correction.patch'; target.write_bytes(correction)
        git('apply', '--check', '--whitespace=error', str(target), cwd=work)
        git('apply', '--whitespace=error', str(target), cwd=work)
        root_test = work/'Tests/NumiBrainMetalTests/MetalConnectomeRootTests.swift'
        text = root_test.read_text()
        if text.count('neural.activitySHA256') != 1:
            raise ValueError('unexpected checkpoint test revision')
        root_test.write_text(text.replace('neuralSHA256=\\(neural.activitySHA256)', 'neuralCheckpointSHA256=\\(neural.sha256)'))
        combined = ''
        for name in paths:
            data = (work/name).read_bytes()
            if digest(data) != expected[name]:
                raise ValueError('materialized source hash mismatch: ' + name)
            if data == before[name]:
                continue
            combined += 'diff --git a/'+name+' b/'+name+'\n'
            if before[name] is None:
                combined += 'new file mode 100644\n'
            combined += ''.join(difflib.unified_diff((before[name] or b'').decode().splitlines(True),
                data.decode().splitlines(True), fromfile='a/'+name if before[name] is not None else '/dev/null',
                tofile='b/'+name))
        target = work/'combined.patch'; target.write_text(combined)
        git('apply', '--check', '--whitespace=error', str(target))
        if args.output_patch:
            args.output_patch.parent.mkdir(parents=True, exist_ok=True)
            args.output_patch.write_text(combined)
        if args.apply:
            if git('rev-parse', 'HEAD').decode().strip() != head or any(snapshot(ROOT/name) != data for name, data in before.items()):
                raise ValueError('source changed during preflight; refusing to apply')
            git('apply', '--whitespace=error', str(target))
        print(json.dumps({'paths': paths, 'applied': args.apply, 'patchSHA256': digest(combined.encode()),
                          'promotable': False, 'scope': 'source only; no git commit or remote publication'}, sort_keys=True))

if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error))

#!/usr/bin/env python3
"""Acquire exact public derived data; no simulator, credentials or source edits."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import urllib.request
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LOCK = ROOT/'Datasets/male-cns-v1.0/release.json'


def read_lock(path: Path) -> dict[str, Any]:
    with path.open('rb') as f:
        data=f.read(65537)
    if len(data)>65536:
        raise ValueError('release lock exceeds 64 KiB')
    value=json.loads(data)
    if (value.get('version')!=1 or value.get('repository')!='Numi2/numi-brain'
        or value.get('format')!='NUMICNS1' or value.get('policyQualified') is not False
        or not re.fullmatch(r'data-[a-zA-Z0-9._-]+',value.get('tag',''))):
        raise ValueError('unsupported release lock or scope')
    assets=value.get('assets')
    if not isinstance(assets,list) or not 1<=len(assets)<=16:
        raise ValueError('invalid release asset count')
    names=set()
    for a in assets:
        name=a.get('name','')
        if (not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9._-]*',name) or name in names
            or type(a.get('bytes')) is not int or not 0<a['bytes']<=1<<30
            or not re.fullmatch(r'[a-f0-9]{64}',a.get('sha256',''))):
            raise ValueError('invalid asset name, capacity or checksum')
        names.add(name)
    return value


def verify(path: Path, asset: dict[str, Any]) -> None:
    if path.is_symlink() or not path.is_file() or path.stat().st_size!=asset['bytes']:
        raise ValueError(f"missing, linked or wrong-size asset: {asset['name']}")
    digest=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(8<<20),b''):
            digest.update(block)
    if digest.hexdigest()!=asset['sha256']:
        raise ValueError(f"asset checksum mismatch: {asset['name']}")


def acquire(lock: dict[str, Any], destination: Path, verify_only: bool=False,
            opener: Callable[..., Any]=urllib.request.urlopen) -> dict[str, Any]:
    if verify_only and not destination.is_dir():
        raise ValueError('release directory does not exist')
    if not verify_only:
        destination.mkdir(parents=True,exist_ok=True)
    result=[]
    for asset in lock['assets']:
        target=destination/asset['name']
        # Existing files are never refreshed or overwritten implicitly.
        if target.exists() or target.is_symlink() or verify_only:
            verify(target,asset); result.append({'name':asset['name'],'cached':True}); continue
        url=f"https://github.com/{lock['repository']}/releases/download/{lock['tag']}/{asset['name']}"
        fd,name=tempfile.mkstemp(prefix='.download-',dir=destination)
        temporary=Path(name)
        try:
            digest=hashlib.sha256(); count=0
            request=urllib.request.Request(url,headers={'User-Agent':'NumiBrain-data/1'})
            with os.fdopen(fd,'wb') as f, opener(request,timeout=120) as response:
                length=response.headers.get('Content-Length')
                if length is not None and int(length)!=asset['bytes']:
                    raise ValueError('release server returned unexpected content length')
                while block:=response.read(8<<20):
                    count+=len(block)
                    if count>asset['bytes']:
                        raise ValueError('release asset exceeds its pinned size')
                    f.write(block); digest.update(block)
                f.flush(); os.fsync(f.fileno())
            if count!=asset['bytes'] or digest.hexdigest()!=asset['sha256']:
                raise ValueError('incomplete or corrupted release asset')
            try:
                # Same-filesystem hard link gives atomic create-only publication.
                os.link(temporary,target)
            except FileExistsError:
                verify(target,asset)
            verify(target,asset)
            result.append({'name':asset['name'],'cached':False})
        finally:
            temporary.unlink(missing_ok=True)
    return {'dataset':lock['dataset'],'tag':lock['tag'],'verified':True,
            'policyQualified':False,'assets':result}


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir',required=True,type=Path)
    parser.add_argument('--lock',type=Path,default=DEFAULT_LOCK)
    parser.add_argument('--verify-only',action='store_true')
    args=parser.parse_args()
    try:
        print(json.dumps(acquire(read_lock(args.lock),args.output_dir,args.verify_only),sort_keys=True))
        return 0
    except (OSError,ValueError,KeyError) as error:
        print(f'connectome data: {error}',file=sys.stderr)
        return 1

if __name__=='__main__':
    raise SystemExit(main())

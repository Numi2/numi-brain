#!/usr/bin/env python3
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock
import fetch_connectome_release as release

class Response(io.BytesIO):
    def __init__(self,data):
        super().__init__(data); self.headers={'Content-Length':str(len(data))}

class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.root=Path(self.temp.name)
        self.content=b'checked dataset'
        self.lock={'version':1,'repository':'Numi2/numi-brain','tag':'data-test-v1',
            'dataset':'test','format':'NUMICNS1','policyQualified':False,
            'assets':[{'name':'graph.numicns','bytes':len(self.content),'sha256':hashlib.sha256(self.content).hexdigest()}]}
    def tearDown(self): self.temp.cleanup()
    def test_exact_download_cache_and_verify(self):
        opener=Mock(side_effect=lambda *a,**k:Response(self.content))
        self.assertTrue(release.acquire(self.lock,self.root,opener=opener)['verified'])
        opener.assert_called_once()
        release.acquire(self.lock,self.root,opener=Mock(side_effect=AssertionError('cache must not download')))
        release.acquire(self.lock,self.root,verify_only=True)
    def test_corrupt_and_truncated_download_never_publishes(self):
        for content in [b'x'*len(self.content),self.content[:-1],self.content+b'x']:
            with self.assertRaises(ValueError):
                release.acquire(self.lock,self.root,opener=lambda *a,**k:Response(content))
            self.assertEqual(list(self.root.iterdir()),[])
    def test_wrong_cache_is_not_overwritten(self):
        target=self.root/'graph.numicns'; target.write_bytes(b'wrong')
        with self.assertRaises(ValueError): release.acquire(self.lock,self.root)
        self.assertEqual(target.read_bytes(),b'wrong')
    def test_symlink_rejected(self):
        other=self.root/'other'; other.write_bytes(self.content)
        (self.root/'graph.numicns').symlink_to(other)
        with self.assertRaises(ValueError): release.acquire(self.lock,self.root,verify_only=True)
    def test_verification_has_no_creation_side_effect(self):
        missing=self.root/'missing'
        with self.assertRaises(ValueError): release.acquire(self.lock,missing,verify_only=True)
        self.assertFalse(missing.exists())
    def test_lock_validation(self):
        path=self.root/'lock.json'
        for mutation in [('name','../graph'),('bytes',0),('bytes',True),('sha256','xx')]:
            value=json.loads(json.dumps(self.lock)); value['assets'][0][mutation[0]]=mutation[1]
            path.write_text(json.dumps(value))
            with self.assertRaises(ValueError): release.read_lock(path)
        path.write_text(json.dumps(self.lock)); self.assertEqual(release.read_lock(path),self.lock)
    def test_actual_checked_pack(self):
        value=release.read_lock(release.DEFAULT_LOCK)
        self.assertEqual(value['nodes'],166700)
        self.assertEqual(value['directedNeuronPairs'],25582938)
        self.assertFalse(value['policyQualified'])

if __name__=='__main__': unittest.main()

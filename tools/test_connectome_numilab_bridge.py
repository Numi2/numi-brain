#!/usr/bin/env python3
"""Compile the real dynamic bridge and inject synthetic owner ABI faults.

No Metal or physics emulation. Set NUMIBRAIN_NUMILAB_INCLUDE to the pinned
NumiLab include directory to compile the fixture against its actual c_api.h.
"""
from __future__ import annotations
import ctypes as C
import os
from pathlib import Path
import platform
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ABI = ROOT / 'Sources/NumiBrainNumiLabBridgeABI'
FIXTURES = ROOT / 'Tests/NumiBrainNumiLabBridgeFixtures'

class Identity(C.Structure):
    _fields_ = [('environments', C.c_uint32), ('actions', C.c_uint32)] + [
        (x, C.c_uint64) for x in ('run', 'world', 'task', 'action', 'robot', 'steps', 'completed', 'submissions')]

class Result(C.Structure):
    _fields_ = [(x, C.c_uint32) for x in ('steps', 'successful', 'failed', 'first_env',
        'first_step', 'gpu_status', 'resets', 'contacts', 'manifolds')] + [
        ('gpu_ms', C.c_double), ('submission_ms', C.c_double)]

class Binding(C.Structure):
    _fields_ = [(x, C.c_uint32) for x in ('action', 'dof', 'q', 'v')] + [
        (x, C.c_float) for x in ('scale', 'lower', 'upper', 'response', 'stiffness', 'damping')] + [
        (x, C.c_uint32) for x in ('motion', 'reserved', 'kind', 'component', 'lane', 'flags')]

class NativeBridgeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='numilab-bridge-test-')
        work = Path(cls.temp.name)
        cc = os.environ.get('CC', 'clang')
        common = [cc, '-std=c11', '-Wall', '-Wextra', '-Wpedantic', '-Werror', '-fPIC', '-shared']
        ext = '.dylib' if platform.system() == 'Darwin' else '.so'
        bridge = work / ('bridge'+ext)
        link = [] if platform.system() == 'Darwin' else ['-ldl']
        subprocess.run([*common, '-I', str(ABI/'include'), str(ABI/'NumiBrainNumiLabBridgeABI.c'),
                        *link, '-o', str(bridge)], check=True)
        cls.owner_path = work/('owner'+ext); cls.missing_path = work/('missing'+ext)
        native_include = os.environ.get('NUMIBRAIN_NUMILAB_INCLUDE')
        args = ['-DNUMIBRAIN_TEST_REAL_NATIVE_HEADER', '-I', native_include] if native_include else []
        for path, extra in [(cls.owner_path, []), (cls.missing_path, ['-DNUMIBRAIN_TEST_MISSING_SYMBOL'])]:
            subprocess.run([*common, *args, *extra, str(FIXTURES/'NativeOwnerFixture.c'), '-o', str(path)], check=True)
        cls.owner = C.CDLL(str(cls.owner_path)); cls.bridge = C.CDLL(str(bridge))
        def signature(lib, name, returns, args):
            f = getattr(lib, name); f.restype = returns; f.argtypes = args; return f
        signature(cls.owner,'fixture_create',C.c_void_p,[])
        signature(cls.owner,'fixture_destroy',None,[C.c_void_p])
        signature(cls.owner,'fixture_fault',None,[C.c_void_p,C.c_int])
        signature(cls.owner,'fixture_mutate',None,[C.c_void_p,C.c_int,C.c_uint64])
        signature(cls.owner,'fixture_calls',C.c_uint64,[C.c_void_p])
        signature(cls.owner,'fixture_revision',C.c_uint64,[C.c_void_p])
        cls.open = staticmethod(signature(cls.bridge,'nb_numilab_borrowed_rollout_open',C.c_void_p,
            [C.c_char_p,C.c_void_p,C.c_void_p,C.c_size_t]))
        cls.close = staticmethod(signature(cls.bridge,'nb_numilab_borrowed_rollout_destroy',None,[C.c_void_p]))
        cls.identity = staticmethod(signature(cls.bridge,'nb_numilab_borrowed_rollout_identity',C.c_int,[C.c_void_p,C.POINTER(Identity)]))
        cls.execute = staticmethod(signature(cls.bridge,'nb_numilab_borrowed_rollout_advance',C.c_int,
            [C.c_void_p,C.POINTER(C.c_float),C.c_size_t,C.c_uint64,C.POINTER(Result)]))
        cls.digest = staticmethod(signature(cls.bridge,'nb_numilab_borrowed_rollout_resident_state_fingerprint',C.c_uint64,[C.c_void_p]))
        cls.error = staticmethod(signature(cls.bridge,'nb_numilab_borrowed_rollout_last_error',C.c_char_p,[C.c_void_p]))
        cls.bindings = staticmethod(signature(cls.bridge,'nb_numilab_borrowed_rollout_copy_action_bindings',C.c_int,
            [C.c_void_p,C.POINTER(Binding),C.c_size_t]))
    @classmethod
    def tearDownClass(cls): cls.temp.cleanup()
    def setUp(self): self.handles=[]; self.bridges=[]
    def tearDown(self):
        for b in self.bridges: self.close(b)
        for h in self.handles: self.owner.fixture_destroy(h)
    def new(self, changes=(), fault=0, path=None, admitted=True):
        h=self.owner.fixture_create(); self.handles.append(h)
        for field,value in changes: self.owner.fixture_mutate(h,field,value)
        self.owner.fixture_fault(h,fault)
        error=C.create_string_buffer(1024)
        b=self.open(str(path or self.owner_path).encode(),h,error,len(error))
        if admitted: self.assertTrue(b,error.value)
        else: self.assertFalse(b); self.assertTrue(error.value)
        if b: self.bridges.append(b)
        return h,b
    def advance(self, b, values=(0.25,-0.125), revision=0):
        out=Result(); C.memset(C.byref(out),0x7f,C.sizeof(out))
        args=(C.c_float*len(values))(*values)
        status=self.execute(b,args,len(values),revision,C.byref(out))
        if status: self.assertEqual(bytes(out),bytes(C.sizeof(out)))
        return status,out
    def test_success_preserves_policy_revision_and_exact_counters(self):
        h,b=self.new()
        self.assertEqual(self.digest(b),0)  # fresh inspection must not poison
        for n in range(1,4):
            status,r=self.advance(b,revision=2**63+n); self.assertEqual(status,0)
            self.assertEqual(r.successful,1); self.assertEqual(self.owner.fixture_revision(h),2**63+n)
            x=Identity(); self.assertEqual(self.identity(b,C.byref(x)),0)
            self.assertEqual((x.submissions,x.steps,x.completed),(n,n,n)); self.assertEqual(self.digest(b),1000+n)
    def test_nonfinite_inputs_are_rejected_without_native_mutation(self):
        for value in (float('nan'),float('inf'),-float('inf')):
            with self.subTest(value=value):
                h,b=self.new(); self.assertNotEqual(self.advance(b,(value,0))[0],0)
                self.assertEqual(self.owner.fixture_calls(h),0); self.assertEqual(self.advance(b)[0],0)
    def test_counter_overflow_is_rejected_before_execution(self):
        for field in (3,4,5):
            h,b=self.new(changes=[(field,2**64-1)])
            self.assertNotEqual(self.advance(b)[0],0); self.assertEqual(self.owner.fixture_calls(h),0)
    def test_open_rejects_bad_identity_and_action_tables(self):
        for field,value in [(0,0),(12,0),(12,4097),(7,0),(9,1),(10,0),(11,1)]:
            with self.subTest(field=field): self.new(changes=[(field,value)],admitted=False)
        self.new(fault=13,admitted=False); self.new(fault=14,admitted=False)
    def test_missing_required_symbol_is_rejected(self): self.new(path=self.missing_path,admitted=False)
    def test_out_of_band_mutation_quarantines_before_execution(self):
        for field,value in [(0,999),(1,3),(2,999),(3,1),(4,1),(5,1),(7,2),(8,1),(13,91),(14,13)]:
            with self.subTest(field=field):
                h,b=self.new(); self.owner.fixture_mutate(h,field,value)
                self.assertNotEqual(self.advance(b)[0],0); self.assertEqual(self.owner.fixture_calls(h),0)
                self.assertNotEqual(self.advance(b)[0],0)
    def test_native_faults_are_terminal_and_never_publish_results(self):
        for fault in (1,2,3,4,5,6,7,8,9,10,15,16,17):
            with self.subTest(fault=fault):
                h,b=self.new(); self.owner.fixture_fault(h,fault)
                self.assertNotEqual(self.advance(b)[0],0); reason=self.error(b)
                self.assertTrue(reason); self.owner.fixture_fault(h,0)
                self.assertNotEqual(self.advance(b)[0],0); self.assertEqual(self.owner.fixture_calls(h),1)
                self.assertEqual(self.digest(b),0); self.assertEqual(self.error(b),reason)
    def test_digest_failure_or_boundary_drift_quarantines(self):
        for fault in (11,12):
            h,b=self.new(); self.assertEqual(self.advance(b)[0],0); self.owner.fixture_fault(h,fault)
            self.assertEqual(self.digest(b),0); self.owner.fixture_fault(h,0)
            self.assertNotEqual(self.advance(b)[0],0); self.assertEqual(self.owner.fixture_calls(h),1)
    def test_binding_copy_failure_cannot_expose_partial_table(self):
        h,b=self.new(); self.owner.fixture_fault(h,13)
        out=(Binding*2)(); C.memset(out,0x7f,C.sizeof(out))
        self.assertNotEqual(self.bindings(b,out,2),0); self.assertEqual(bytes(out),bytes(C.sizeof(out)))
        self.owner.fixture_fault(h,0); self.assertNotEqual(self.advance(b)[0],0)
    def test_wrong_shape_does_not_mutate_or_poison(self):
        h,b=self.new(); self.assertNotEqual(self.advance(b,(0,))[0],0)
        self.assertEqual(self.owner.fixture_calls(h),0); self.assertEqual(self.advance(b)[0],0)
    def test_batched_owner_cannot_be_advanced_as_one_agent(self):
        h,b=self.new(changes=[(6,2)]); self.assertNotEqual(self.advance(b)[0],0)
        self.assertEqual(self.owner.fixture_calls(h),0)
    def test_null_outputs_and_handles_do_not_crash(self):
        h,b=self.new(); a=(C.c_float*2)(0,0)
        self.assertNotEqual(self.execute(b,a,2,0,None),0); self.assertEqual(self.owner.fixture_calls(h),0)
        self.assertNotEqual(self.advance(None)[0],0); self.close(None)
        x=Identity(); C.memset(C.byref(x),0x7f,C.sizeof(x))
        self.assertNotEqual(self.identity(None,C.byref(x)),0); self.assertEqual(bytes(x),bytes(C.sizeof(x)))
        self.assertEqual(self.advance(b)[0],0)

if __name__=='__main__': unittest.main(verbosity=2)

#!/usr/bin/env python3
"""Native structural-path regressions. No simulator or alternate controller."""
import ctypes as C
import importlib.util
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('native', HERE/'test_connectome_native.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

class Summary(C.Structure):
    _fields_ = [(x, C.c_uint64) for x in ('graph', 'scratch')] + [(x, C.c_uint32) for x in
        ('edges', 'active_inputs', 'active_readouts', 'nodes', 'useful_inputs', 'reachable_readouts', 'channels', 'max_hops')]


def resign(data):
    q=struct.unpack_from('<29Q', data, 24)
    n,e,_,source=q[:4]
    payload=struct.pack('<IIQQQ',1,struct.unpack_from('<I',data,16)[0],source,n,e)
    for offset,count in zip(q[4:9],(n*8,n*48,(n+1)*4,e*4,e*4)):
        payload += data[offset:offset+count]
    lo=struct.unpack_from(f'<{n+1}I',data,q[9]); label_base=q[9]+(n+1)*4
    for a,z in zip(lo,lo[1:]):
        payload += struct.pack('<Q',z-a)+data[label_base+a:label_base+z]
    payload += struct.pack('<Q',q[12])+data[q[11]:q[11]+q[12]]
    struct.pack_into('<Q',data,40,base.fnv(payload))
    return data

class AuditTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp=tempfile.TemporaryDirectory(); out=Path(cls.tmp.name)/'audit.so'
        root=HERE.parent/'Sources/NumiBrainConnectomeABI'
        subprocess.run([os.environ.get('CXX','clang++'),'-std=c++20','-O2','-Wall','-Wextra','-Wpedantic','-Werror',
            '-shared','-fPIC','-I',str(root/'include'),str(root/'NumiBrainConnectomeABI.cpp'),
            str(root/'NumiBrainConnectomeAudit.cpp'),'-o',str(out)],check=True)
        cls.lib=C.CDLL(str(out)); cls.audit=cls.lib.nb_connectome_audit
        cls.audit.argtypes=[C.c_void_p,C.c_size_t,C.c_uint64,C.c_uint64,C.POINTER(base.Input),C.c_uint32,
            C.POINTER(base.Readout),C.c_uint32,C.c_uint32,C.POINTER(C.c_uint32),C.POINTER(C.c_uint32),
            C.POINTER(C.c_uint32),C.POINTER(Summary)]
        cls.audit.restype=C.c_uint32
    @classmethod
    def tearDownClass(cls): cls.tmp.cleanup()
    def call(self,data=None,ins=None,outs=None,channels=1,budget=1<<20):
        data=base.fixture() if data is None else data
        ins=[base.Input(0,1,0,0,1,1,0,8)] if ins is None else ins
        outs=[base.Readout(2,0,1,0)] if outs is None else outs
        b=C.create_string_buffer(bytes(data)); a=(base.Input*len(ins))(*ins); z=(base.Readout*len(outs))(*outs)
        ih=(C.c_uint32*len(ins))(); oh=(C.c_uint32*len(outs))(); ch=(C.c_uint32*channels)(); summary=Summary()
        status=self.audit(b,len(data),1<<30,budget,a,len(a),z,len(z),channels,ih,oh,ch,C.byref(summary))
        if status: self.assertEqual(summary.graph,0)
        return status,summary,list(ih),list(oh),list(ch)
    def test_direction_distance_and_negative_edge(self):
        code,s,i,o,ch=self.call(); self.assertEqual(code,0)
        self.assertEqual((i,o,ch),([2],[2],[2])); self.assertEqual((s.edges,s.nodes,s.channels),(2,3,1))
        self.assertEqual(s.scratch,(3*5+1+2)*4)
    def test_zero_input_scale_or_weight_is_not_a_path(self):
        for field in ('scale','weight'):
            p=base.Input(0,1,0,0,1,1,1,8); setattr(p,field,0)
            code,s,i,o,ch=self.call(ins=[p]); self.assertEqual(code,0)
            self.assertEqual(s.channels,0); self.assertEqual(s.useful_inputs,0); self.assertEqual(ch,[0xffffffff])
    def test_zero_readout_weight_disables_backward_path(self):
        code,s,i,o,ch=self.call(outs=[base.Readout(2,0,0,0)])
        self.assertEqual(code,0); self.assertEqual(s.useful_inputs,0); self.assertEqual(i,[0xffffffff])
    def test_zero_recurrent_weight_breaks_path(self):
        data=base.fixture(); q=struct.unpack_from('<29Q',data,24)
        struct.pack_into('<f',data,q[8],0); resign(data)
        code,s,*_=self.call(data); self.assertEqual(code,0); self.assertEqual((s.edges,s.channels),(1,0))
    def test_zero_recurrent_gain_breaks_path(self):
        data=base.fixture(); q=struct.unpack_from('<29Q',data,24)
        struct.pack_into('<f',data,q[5]+48+8,0); resign(data)
        code,s,*_=self.call(data); self.assertEqual(code,0); self.assertEqual((s.edges,s.channels),(1,0))
    def test_zero_sensory_gain_breaks_input(self):
        data=base.fixture(); q=struct.unpack_from('<29Q',data,24)
        struct.pack_into('<f',data,q[5]+12,0); resign(data)
        code,s,*_=self.call(data); self.assertEqual(code,0); self.assertEqual(s.active_inputs,0)
    def test_uncovered_channel_reported(self):
        code,s,i,o,ch=self.call(channels=2); self.assertEqual(code,0)
        self.assertEqual(ch,[2,0xffffffff]); self.assertEqual(s.channels,1)
    def test_multiple_sources_and_readouts(self):
        data=base.fixture(); q=struct.unpack_from('<29Q',data,24)
        struct.pack_into('<I',data,q[5]+48+40,4|16|8); resign(data)
        ins=[base.Input(0,0,0,0,1,1,0,8),base.Input(1,1,0,0,1,1,0,8)]
        outs=[base.Readout(1,0,1,0),base.Readout(2,1,1,0)]
        code,s,i,o,ch=self.call(data,ins,outs,2)
        self.assertEqual(code,0); self.assertEqual((i,o,ch),([1,0],[0,1],[0,1]))
    def test_invalid_role_index_nan(self):
        for p in [base.Input(1,0,0,0,1,1,0,8),base.Input(3,0,0,0,1,1,0,8),base.Input(0,0,0,0,float('nan'),1,0,8)]:
            self.assertEqual(self.call(ins=[p])[0],100)
    def test_corrupted_graph_is_not_trusted(self):
        d=base.fixture(); d[-1]^=1; self.assertEqual(self.call(d)[0],7)
    def test_exact_scratch_budget(self):
        required=(3*5+1+2)*4
        self.assertEqual(self.call(budget=required)[0],0)
        self.assertEqual(self.call(budget=required-1)[0],101)
    def test_missing_projection_rejected(self):
        self.assertEqual(self.call(ins=[])[0],100); self.assertEqual(self.call(outs=[])[0],100)

if __name__=='__main__': unittest.main()

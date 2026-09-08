#!/usr/bin/env python3
"""Bounded native pack regressions; no downloads, SDK, NumPy or simulation loop."""
import ctypes as C
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MASK = (1 << 64) - 1

def fnv(data):
    h = 14695981039346656037
    for b in data:
        h = ((h ^ b) * 1099511628211) & MASK
    return h or 1

def fixture():
    ids = struct.pack('<3Q', 10, 20, 30)
    nodes = b''.join(struct.pack('<8f4I', .2, 0, 1, 1, 1, 8, 0, 0, i, 0, flag, 0)
                     for i, flag in [(10, 1), (20, 4), (30, 8)])
    offsets, sources, weights = struct.pack('<4I', 0, 0, 1, 2), struct.pack('<2I', 0, 1), struct.pack('<2f', 1, -1)
    labels = [b'sensory', b'interneuron', b'descending']
    label_offsets = [0]
    for label in labels: label_offsets.append(label_offsets[-1] + len(label))
    label_data = struct.pack('<4I', *label_offsets) + b''.join(labels)
    manifest = json.dumps({'synthetic': True, 'source': 'native-regression'}, sort_keys=True).encode()
    source = 123
    payload = struct.pack('<IIQQQ', 1, 0, source, 3, 2) + ids + nodes + offsets + sources + weights
    for label in labels: payload += struct.pack('<Q', len(label)) + label
    payload += struct.pack('<Q', len(manifest)) + manifest
    sections = [ids, nodes, offsets, sources, weights, label_data, manifest]
    data = bytearray(256); starts = []
    for section in sections:
        data += b'\0' * (-len(data) % 64)
        starts.append(len(data)); data += section
    q = [3, 2, fnv(payload), source, *starts[:5], starts[5], len(label_data), starts[6], len(manifest), len(data), *([0]*15)]
    data[:256] = struct.pack('<8s4I29Q', b'NUMICNS1', 256, 1, 0, 0, *q)
    return data

class View(C.Structure):
    _fields_ = [(x, C.c_uint64) for x in ('fingerprint', 'source', 'ids', 'nodes', 'offsets', 'sources', 'weights', 'labels', 'label_bytes', 'manifest', 'manifest_bytes')] + [(x, C.c_uint32) for x in ('n', 'e', 'resolution', 'reserved')]

class Input(C.Structure):
    _fields_ = [(x, C.c_uint32) for x in ('node', 'scalar', 'receptor', 'reserved')] + [(x, C.c_float) for x in ('weight', 'scale', 'bias', 'clip')]

class Readout(C.Structure):
    _fields_ = [('node', C.c_uint32), ('channel', C.c_uint32), ('weight', C.c_float), ('reserved', C.c_uint32)]

class NativePackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        path = Path(cls.tmp.name) / 'libconnectome.so'
        abi = ROOT / 'Sources/NumiBrainConnectomeABI'
        subprocess.run([os.environ.get('CXX', 'clang++'), '-std=c++20', '-Wall', '-Wextra', '-Wpedantic', '-Werror', '-shared', '-fPIC', '-I', str(abi/'include'), str(abi/'NumiBrainConnectomeABI.cpp'), '-o', str(path)], check=True)
        cls.lib = C.CDLL(str(path))
        cls.lib.nb_connectome_validate.argtypes = [C.c_void_p, C.c_size_t, C.c_uint64, C.POINTER(View)]
        cls.lib.nb_connectome_validate.restype = C.c_uint32
        cls.lib.nb_connectome_binding_fingerprint.argtypes = [C.c_uint64]*4 + [C.c_uint32]*6 + [C.POINTER(Input), C.c_uint32, C.POINTER(Readout), C.c_uint32]
        cls.lib.nb_connectome_binding_fingerprint.restype = C.c_uint64
    @classmethod
    def tearDownClass(cls): cls.tmp.cleanup()
    def check(self, data, budget=1<<20):
        buf=C.create_string_buffer(bytes(data)); view=View()
        status=self.lib.nb_connectome_validate(buf,len(data),budget,C.byref(view))
        if status: self.assertEqual(view.fingerprint,0)
        return status,view
    def test_round_trip(self):
        status,v=self.check(fixture()); self.assertEqual(status,0); self.assertEqual((v.n,v.e),(3,2))
    def test_every_truncation(self):
        data=fixture()
        for n in range(len(data)): self.assertNotEqual(self.check(data[:n])[0],0)
    def test_budget(self): self.assertNotEqual(self.check(fixture(),256)[0],0)
    def test_corrupt_payload(self):
        data=fixture(); _,v=self.check(data); data[v.weights]^=1
        self.assertEqual(self.check(data)[0],7)
    def test_duplicate_identity(self):
        data=fixture(); _,v=self.check(data)
        struct.pack_into('<Q',data,v.ids+8,10); struct.pack_into('<I',data,v.nodes+48+32,10)
        self.assertEqual(self.check(data)[0],4)
    def test_bad_offsets(self):
        data=fixture(); _,v=self.check(data); struct.pack_into('<I',data,v.offsets+4,3)
        self.assertEqual(self.check(data)[0],5)
    def test_nonfinite(self):
        data=fixture(); _,v=self.check(data); struct.pack_into('<f',data,v.weights,float('nan'))
        self.assertEqual(self.check(data)[0],5)
    def test_section_alias(self):
        data=fixture(); struct.pack_into('<Q',data,24+5*8,256)
        self.assertEqual(self.check(data)[0],3)
    def test_reserved_header(self):
        data=fixture(); data[24+14*8]=1
        self.assertEqual(self.check(data)[0],2)
    def test_padding(self):
        data=fixture(); data[280]=1
        self.assertEqual(self.check(data)[0],3)
    def test_bad_label_range(self):
        data=fixture(); _,v=self.check(data); struct.pack_into('<I',data,v.labels+4,0xffffffff)
        self.assertEqual(self.check(data)[0],6)

    def binding(self, identities=(1,2,3,4), scalars=2, receptors=1, channels=1,
                nominal=20000, integration=1000, inputs=None, outputs=None):
        ins = [Input(0,1,0,0,1,1,0,8)] if inputs is None else inputs
        outs = [Readout(2,0,1,0)] if outputs is None else outputs
        return self.lib.nb_connectome_binding_fingerprint(*identities,3,scalars,receptors,
            channels,nominal,integration,(Input*len(ins))(*ins),len(ins),
            (Readout*len(outs))(*outs),len(outs))
    def test_binding_deterministic(self):
        self.assertNotEqual(self.binding(),0)
        self.assertEqual(self.binding(),self.binding())
    def test_binding_requires_every_identity(self):
        for i in range(4):
            ids=[1,2,3,4]; ids[i]=0
            self.assertEqual(self.binding(identities=ids),0)
    def test_binding_identity_and_time_change_fingerprint(self):
        self.assertNotEqual(self.binding(),self.binding(integration=500))
        for i in range(4):
            ids=[1,2,3,4]; ids[i]+=1
            self.assertNotEqual(self.binding(),self.binding(identities=ids))
    def test_binding_invalid_values(self):
        for field,value in [('weight',float('nan')),('scale',float('inf')),('clip',0),('reserved',1)]:
            item=Input(0,1,0,0,1,1,0,8); setattr(item,field,value)
            self.assertEqual(self.binding(inputs=[item]),0)
    def test_binding_readout_coverage(self):
        self.assertEqual(self.binding(channels=2),0)
        self.assertEqual(self.binding(outputs=[]),0)
        self.assertNotEqual(self.binding(channels=2,outputs=[Readout(2,0,1,0),Readout(2,1,1,0)]),0)
    def test_binding_index_bounds(self):
        for field,value in [('node',3),('scalar',2),('receptor',1)]:
            item=Input(0,1,0,0,1,1,0,8); setattr(item,field,value)
            self.assertEqual(self.binding(inputs=[item]),0)
    def test_binding_invalid_time_and_shape(self):
        self.assertEqual(self.binding(integration=20001),0)
        self.assertEqual(self.binding(nominal=0),0)
        self.assertEqual(self.binding(scalars=0),0)
        self.assertEqual(self.binding(channels=257),0)
        self.assertEqual(self.binding(inputs=[]),0)

    def decoder(self, graph=1, topology=2, species=3, kind=1, channels=2,
                actuators=2, weights=(1.,0.,0.,1.), biases=(0.,0.), limit=8.):
        f = self.lib.nb_connectome_decoder_fingerprint
        f.argtypes = [C.c_uint64]*3 + [C.c_uint32]*3 + [C.POINTER(C.c_float), C.c_uint32, C.POINTER(C.c_float), C.c_uint32, C.c_float]
        f.restype = C.c_uint64
        return f(graph, topology, species, kind, channels, actuators,
            (C.c_float*len(weights))(*weights), len(weights),
            (C.c_float*len(biases))(*biases), len(biases), limit)
    def test_decoder_round_trip_and_exact_body(self):
        self.assertNotEqual(self.decoder(), 0)
        self.assertEqual(self.decoder(), self.decoder())
        self.assertNotEqual(self.decoder(), self.decoder(species=4))
        self.assertNotEqual(self.decoder(), self.decoder(weights=(1.,1.,0.,1.)))
    def test_decoder_missing_identity(self):
        for key in ('graph','topology','species'):
            self.assertEqual(self.decoder(**{key:0}),0)
    def test_decoder_shape_limits(self):
        self.assertEqual(self.decoder(weights=(1.,)),0)
        self.assertEqual(self.decoder(actuators=0),0)
        self.assertEqual(self.decoder(channels=257),0)
        self.assertEqual(self.decoder(kind=0),0)
    def test_decoder_numeric_domain(self):
        self.assertEqual(self.decoder(weights=(float('nan'),0.,0.,1.)),0)
        self.assertEqual(self.decoder(biases=(float('inf'),0.)),0)
        self.assertEqual(self.decoder(limit=0),0)
        self.assertEqual(self.decoder(limit=17),0)

if __name__ == '__main__': unittest.main()

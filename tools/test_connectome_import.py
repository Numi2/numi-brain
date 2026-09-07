#!/usr/bin/env python3
"""Synthetic release-format tests. No download and no neural simulation."""
from pathlib import Path
import struct
import tempfile
import unittest
import numpy as np
import pyarrow as pa
import pyarrow.feather as feather
import import_male_cns as imp

class ImportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.root = Path(self.temp.name)
        self.big = 2**53+7
        self.annotations = {'bodyId':[10,20,30,self.big,40,50],
            'status':['Traced','Traced','Traced','Traced','Glia','Unimportant'],
            'superclass':['cb_sensory','cb_intrinsic','descending_neuron',None,None,'vnc_motor'],
            'type':['sensory','interneuron','DN','isolated',None,'excluded'],
            'somaSide':['L','R','L',None,None,None]}
        self.weights = {'body_pre':[10,10,20,40,50], 'body_post':[20,20,30,30,30], 'weight':[1,1,3,99,99]}
    def tearDown(self): self.temp.cleanup()
    def source(self):
        tables={'annotations':pa.table(self.annotations),
                'neurotransmitters':pa.table({'body':[10,20,30,self.big], 'consensus_nt':['acetylcholine','gaba','unclear',None]}),
                'weights':pa.table(self.weights)}
        files={}
        for key,table in tables.items():
            path=self.root/(key+'.feather'); feather.write_feather(table,path,compression='uncompressed',chunksize=1)
            files[key]={'name':path.name,'url':imp.BASE+path.name,'bytes':path.stat().st_size,'sha256':imp.sha256(path)}
        return {'dataset':'synthetic-test-only','license':'test','files':files}
    def test_exact_id_isolate_and_pair_aggregation(self):
        report=imp.compile_graph(self.root,self.root/'graph.numicns',self.source(),minimum_synapses=2)
        count=report['manifest']['counts']
        self.assertEqual((count['neurons'],count['neuron_pair_edges'],count['isolated_neurons']),(4,2,1))
        self.assertEqual(count['retained_synapses'],5)
        data=(self.root/'graph.numicns').read_bytes(); q=struct.unpack_from('<29Q',data,24)
        self.assertEqual(struct.unpack_from('<4Q',data,q[4]),(10,20,30,self.big))
        self.assertEqual(struct.unpack_from('<2f',data,q[8]),(1,-1))
        # Changing output location has no effect on the complete artifact bytes.
        other=imp.compile_graph(self.root,self.root/'graph2.numicns',self.source(),minimum_synapses=2)
        self.assertEqual(report['sha256'],other['sha256'])
    def test_source_corruption(self):
        lock=self.source(); p=self.root/'weights.feather'; p.write_bytes(p.read_bytes()+b'x')
        with self.assertRaisesRegex(ValueError,'size mismatch'): imp.compile_graph(self.root,self.root/'bad',lock)
    def test_float_ids_fail(self):
        self.weights['body_pre']=[float(x) for x in self.weights['body_pre']]
        with self.assertRaisesRegex(ValueError,'non-null integer'): imp.compile_graph(self.root,self.root/'bad',self.source())
    def test_duplicate_neurons_fail(self):
        self.annotations['bodyId'][1]=10
        with self.assertRaisesRegex(ValueError,'duplicate'): imp.compile_graph(self.root,self.root/'bad',self.source())
    def test_missing_values_fail(self):
        self.weights['weight'][1]=None
        with self.assertRaisesRegex(ValueError,'non-null integer'): imp.compile_graph(self.root,self.root/'bad',self.source())
    def test_capacity_and_overwrite(self):
        lock=self.source()
        with self.assertRaisesRegex(ValueError,'capacity'): imp.compile_graph(self.root,self.root/'bad',lock,maximum_edges=1)
        (self.root/'existing').write_text('keep')
        with self.assertRaisesRegex(ValueError,'exists'): imp.compile_graph(self.root,self.root/'existing',lock)
        self.assertEqual((self.root/'existing').read_text(),'keep')

if __name__=='__main__': unittest.main()

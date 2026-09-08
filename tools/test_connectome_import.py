"""Portable real compiler/ABI regressions, including Arrow source semantics."""
import tempfile
import unittest
from pathlib import Path
import numi_connectome as c
import numpy as np

class ImportTests(unittest.TestCase):
    def test_existing_interchange_preserved(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'graph.numicns'
            c.write_graph_pack(p,c.synthetic_graph());c.verify_native(p)
            self.assertEqual(c.read_graph_pack(p).fingerprint,0x54963d204b21c364)
    def test_official_content_pins_are_not_only_versioned_urls(self):
        for name, digest in c.OFFICIAL_SHA256.items():
            c.verify_official_digest(name, digest)
            with self.assertRaises(c.ConnectomeError):c.verify_official_digest(name, "0"*64)
        with self.assertRaises(c.ConnectomeError):c.verify_official_digest("foreign", "0"*64)
    def test_native_hash_chunking(self):
        a=c.FNV64();a.update(b'abc');b=c.FNV64();b.update(b'a');b.update(b'bc')
        self.assertEqual(a.finish(),b.finish())
    def test_mutated_pack_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'graph.numicns';c.write_graph_pack(p,c.synthetic_graph())
            data=bytearray(p.read_bytes());data[-3]^=1;p.write_bytes(data)
            with self.assertRaises(c.ConnectomeError):c.verify_native(p)
    def test_arrow_compilation_keeps_isolates_and_reports_unmapped_segments(self):
        try:
            import pyarrow as pa
            import pyarrow.feather as f
        except ImportError:
            self.skipTest('PyArrow required for source-table test')
        with tempfile.TemporaryDirectory() as d:
            d=Path(d)
            f.write_feather(pa.table({'bodyId':[10,20,30,40], 'type':['S','I','D','isolated'],
                'superclass':['sensory','intrinsic','descending','intrinsic']}),d/'annotations.feather')
            f.write_feather(pa.table({'body_pre':[10,20,999], 'body_post':[20,30,30],
                'weight':[5,2,1]}),d/'weights.feather')
            g=c.compile_official_graph(c.SourcePaths(d/'annotations.feather',None,d/'weights.feather'),sign_mode='unsigned')
            self.assertEqual(g.node_count,4);self.assertEqual(g.edge_count,2)
            self.assertIn(40,g.node_ids)
            import json
            m=json.loads(g.manifest_json)
            self.assertEqual(m['counts']['unmapped_endpoint_rows'],1)
            self.assertEqual(m['counts']['isolated_retained_nodes'],1)
            c.write_graph_pack(d/'g.numicns',g);c.verify_native(d/'g.numicns')
            f.write_feather(pa.table({'body_pre':[10], 'body_post':[20], 'weight':[float('nan')]}),d/'weights.feather')
            with self.assertRaises(c.ConnectomeError):
                c.compile_official_graph(c.SourcePaths(d/'annotations.feather',None,d/'weights.feather'),sign_mode='unsigned')
    def test_non_neuronal_annotation_entries_are_not_simulated(self):
        try:
            import pyarrow as pa
            import pyarrow.feather as f
        except ImportError:
            self.skipTest('PyArrow required for source-table test')
        with tempfile.TemporaryDirectory() as directory:
            d=Path(directory)
            f.write_feather(pa.table({'bodyId':[10,20,30,40,50],
                'type':['S','D',None,'glia','typed-artifact'],
                'superclass':['sensory','descending_neuron',None,'glia','intrinsic'],
                'status':['Traced','Traced','Orphan','Glia','Orphan-artifact']}),d/'annotations.feather')
            f.write_feather(pa.table({'body_pre':[10,30,40,50],
                'body_post':[20,20,20,20], 'weight':[3,1,1,1]}),d/'weights.feather')
            graph=c.compile_official_graph(c.SourcePaths(d/'annotations.feather',None,d/'weights.feather'),sign_mode='unsigned')
            self.assertEqual(list(graph.node_ids),[10,20])
            self.assertEqual(graph.edge_count,1)
            import json
            manifest=json.loads(graph.manifest_json)
            self.assertEqual(manifest['source']['dataset'],'unverified:user-tables')
            self.assertEqual(manifest['source']['license'],'unverified')
            counts=manifest['counts']
            self.assertEqual(counts['annotation_records'],5)
            self.assertEqual(counts['excluded_annotation_records'],3)
            self.assertEqual(counts['classified_neuronal_entries'],2)
            c.write_graph_pack(d/'g.numicns',graph);c.verify_native(d/'g.numicns')
if __name__=='__main__':unittest.main()

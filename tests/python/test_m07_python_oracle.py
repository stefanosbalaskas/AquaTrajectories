#!/usr/bin/env python3
"""Source-separation and arithmetic contracts for the M07 Python bridge."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
    return m
bridge=load('m07_bridge',ROOT/'inst/python/aqt_m07_brackish_dual_path.py')
oracle=load('m07_oracle',ROOT/'inst/python/aqt_m07_independent_frame_oracle.py')

class M07Contracts(unittest.TestCase):
    def test_centre_and_image_geometry(self):
        row=bridge.make_observation('reference','brackishMOT-55',0,'0003',4,8,12,14,100,50,'','published')
        self.assertEqual(row[:5],['reference','brackishMOT-55','camera_1',0,'0003'])
        self.assertEqual(row[5:7],[8,11])
        self.assertEqual(row[7:11],[4,8,8,6])
        for coords in [(0,0,101,8),(0,0,0,8),(-1,0,8,10),(0,0,8,60)]:
            with self.subTest(coords=coords):
                with self.assertRaises(ValueError):
                    bridge.make_observation('model','brackishMOT-55',0,'1',*coords,100,50,.4,'model')
        for score in (-.2,1.01,float('nan')):
            with self.assertRaises(ValueError):
                bridge.make_observation('model','brackishMOT-55',0,'1',0,0,5,6,100,50,score,'model')
        with self.assertRaises(ValueError):
            bridge.make_observation('model','brackishMOT-55',256,'1',0,0,5,6,100,50,.4,'model')

    def test_hash_and_csv_contract(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'rows.csv'
            bridge.write_csv(p,['track_id','time_s'],[['00001',''],['00002','']])
            self.assertEqual(bridge.read_csv(p)[0]['track_id'],'00001')
            h=bridge.sha256(p)
            p.write_text(p.read_text()+'\n',encoding='utf8')
            self.assertNotEqual(h,bridge.sha256(p))

    def test_no_real_study_claim_without_real_inputs(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)
            with self.assertRaises((FileNotFoundError,ValueError)):
                bridge.check_evidence(root,root)
            with self.assertRaises((FileNotFoundError,ValueError)):
                oracle.analyze(root)

if __name__=='__main__':unittest.main()

"""3D-ZeF real-label oracle ID-association contracts, no XYZ survey claims."""
import importlib.util
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"inst/python"))
import aqt_3dzef_oracle_id_trackeval as m

HAS_METRICS=(importlib.util.find_spec("numpy") is not None and
             importlib.util.find_spec("scipy") is not None and
             importlib.util.find_spec("trackeval") is not None)

class RealFish3DOracleID(unittest.TestCase):
    def test_true_gt_id_never_enters_association_measurements(self):
        gt=[(1,99,(0.,0.,0.)),(2,99,(.1,0.,0.)),
            (1,13,(10.,0.,0.)),(2,13,(9.9,0.,0.))]
        stripped=m.oracle_positions(gt)
        self.assertEqual(stripped[1],[(0.,0.,0.),(10.,0.,0.)])
        self.assertEqual(stripped[2],[(.1,0.,0.),(9.9,0.,0.)])
        self.assertNotIn(99,stripped[1])

    @unittest.skipUnless(HAS_METRICS,"NumPy SciPy and official TrackEval required")
    def test_conditional_3d_oracle_tracking_and_switch_detection(self):
        gt=[(f,1,(float(f),0.,0.)) for f in range(1,5)]
        gt += [(f,2,(float(f),10.,0.)) for f in range(1,5)]
        pred=m.assign_3d_nearest(gt,gate_cm=2.)
        self.assertEqual(len(pred),8)
        self.assertEqual(len({x[1] for x in pred}),2)
        good=m.evaluate_3d_label_id_agreement(gt,pred,"known_truth_fixture",2.)
        self.assertAlmostEqual(good["HOTA"],1.,places=8)
        self.assertAlmostEqual(good["IDF1"],1.,places=8)
        self.assertEqual(good["IDSW"],0)
        swapped=[(f,3-tid,xyz) if f>=3 else (f,tid,xyz)
                 for f,tid,xyz in pred]
        bad=m.evaluate_3d_label_id_agreement(gt,swapped,"known_truth_fixture",2.)
        self.assertLess(bad["HOTA"],good["HOTA"])
        self.assertLess(bad["IDF1"],good["IDF1"])
        self.assertGreater(bad["IDSW"],0)
        self.assertTrue(good["oracle_ground_truth_xyz_input_used"])
        self.assertFalse(good["independent_physical_underwater_xyz_accuracy_certified"])

if __name__=="__main__":
    unittest.main()

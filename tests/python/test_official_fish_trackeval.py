"""Official TrackEval fish identity scoring contracts, with synthetic known IDs.

Synthetic tests demonstrate metric correctness ONLY, not real-fish accuracy.
"""
import csv
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"inst/python"))
import aqt_official_fish_trackeval as m

def write_mot(path,rows):
    with open(path,"w",newline="") as fh:
        csv.writer(fh).writerows(rows)

def write_frames(path,n):
    with open(path,"w",newline="") as fh:
        w=csv.writer(fh);w.writerow(["frame","review_status"])
        w.writerows((i,"fully_annotated") for i in range(1,n+1))

class OfficialFishMetrics(unittest.TestCase):
    def test_declared_original_empty_frames_and_frame_origin(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            frames=root/"f.csv";write_frames(frames,4)
            self.assertEqual(m.manifest(frames),4)
            gt=root/"gt.txt";write_mot(gt,[[1,1,2,2,10,8,1,1,1],
                                         [4,1,2,2,10,8,1,1,1]])
            self.assertEqual(len(m.mot_rows(gt,4,is_ground_truth=True)),2)
            write_mot(gt,[[0,1,2,2,10,8]])
            with self.assertRaisesRegex(ValueError,"Invalid/duplicate"):
                m.mot_rows(gt,4)
            write_frames(frames,4)
            text=frames.read_text().replace("3,fully_annotated","3,partial")
            frames.write_text(text)
            with self.assertRaisesRegex(ValueError,"non-reviewed"):
                m.manifest(frames)

    def test_duplicate_fish_id_in_same_frame_fails(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"a.txt"
            write_mot(p,[[1,1,10,10,2,2],[1,1,12,12,2,2]])
            with self.assertRaisesRegex(ValueError,"Invalid/duplicate"):
                m.mot_rows(p,2)

    def test_ground_truth_ignore_class_requires_review(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"a.txt"
            write_mot(p,[[1,1,10,10,2,2,0,1,1]])
            with self.assertRaisesRegex(ValueError,"explicit external review"):
                m.mot_rows(p,2,is_ground_truth=True)

    def test_observation_overlap_has_expected_iou(self):
        if importlib.util.find_spec("numpy") is None:
            self.skipTest("NumPy installed by dedicated TrackEval CI")
        s=m.similarities([(0,0,10,10)],[(0,0,10,10),(20,20,4,4)])
        self.assertEqual(s.shape,(1,2))
        self.assertAlmostEqual(s[0,0],1)
        self.assertAlmostEqual(s[0,1],0)

    @unittest.skipUnless(importlib.util.find_spec("numpy") is not None and
                         importlib.util.find_spec("trackeval") is not None,
                         "Official TrackEval installed in dedicated CI")
    def test_official_metrics_perfect_and_identity_switch(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            frames=root/"frames.csv";write_frames(frames,4)
            truth=root/"truth.txt"
            cases=[]
            for f in (1,2,3,4):
                cases.extend(((f,1,10,10,8,8,1),(f,2,40,40,8,8,1)))
            write_mot(truth,cases)
            pred=root/"pred.txt";write_mot(pred,cases)
            perfect=m.run(truth,pred,frames,"real_style_fixture",
                "oracle_box_association","unverified")
            self.assertAlmostEqual(perfect["HOTA"],1,places=8)
            self.assertAlmostEqual(perfect["IDF1"],1,places=8)
            self.assertAlmostEqual(perfect["DetA"],1,places=8)
            self.assertEqual(perfect["IDSW"],0)
            self.assertTrue(perfect["prediction_bytes_identical_to_gt_rows"])
            switched=[]
            for row in cases:
                x=list(row)
                if x[0]>=3:x[1]=3-x[1]
                switched.append(x)
            write_mot(pred,switched)
            different=m.run(truth,pred,frames,"real_style_fixture",
                "oracle_box_association","unverified")
            self.assertLess(different["IDF1"],perfect["IDF1"])
            self.assertLess(different["HOTA"],perfect["HOTA"])
            self.assertGreater(different["IDSW"],0)
            self.assertAlmostEqual(different["DetA"],1,places=8)
            self.assertFalse(different["independent_prediction_accuracy_certified"])

if __name__=="__main__":
    unittest.main()

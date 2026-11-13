"""Wave 14H: model-generated dense-fish alternative and error strata contracts."""
from pathlib import Path
import csv
import importlib.util
import json
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"inst/python"))
import aqt_external_fish_comparative_robustness as m

HAS_NUMPY_SCIP=(importlib.util.find_spec("numpy") is not None and
                 importlib.util.find_spec("scipy") is not None)

class FishModelAlternativeTracker(unittest.TestCase):
    def test_density_buckets_and_no_invented_animal_occlusion(self):
        self.assertEqual([m.density_bucket(x) for x in (0,25,26,75,76,260)],
                         ["0-25","0-25","26-75","26-75","76+","76+"])
        self.assertTrue(m.GT_SHA.startswith("b70a"))
        self.assertEqual(m.FRAME_START,43450)

    @unittest.skipUnless(HAS_NUMPY_SCIP,"Dedicated CI installs SciPy")
    def test_independent_alternative_association_on_original_model_boxes(self):
        model=[(1,(10.,10.,5.,5.),.80),(1,(60.,60.,5.,5.),.70),
               (2,(11.,10.,5.,5.),.81),(2,(59.,60.,5.,5.),.75),
               (3,(12.,10.,5.,5.),.90)]
        association=m.hungarian_from_model(model)
        self.assertEqual(len(association),5)
        self.assertEqual(association[0][1],association[2][1])
        self.assertEqual(association[1][1],association[3][1])
        self.assertEqual(association[2][1],association[4][1])
        self.assertNotEqual(association[0][1],association[1][1])

    @unittest.skipUnless(HAS_NUMPY_SCIP,"Dedicated CI installs SciPy")
    def test_dense_box_overlap_not_misrepresented_as_annotated_occlusion(self):
        truth=[(1,1,(0.,0.,10.,10.),1.),(1,2,(2.,2.,10.,10.),1.),
               (2,1,(0.,0.,10.,10.),1.)]
        model=[(1,(0.,0.,10.,10.),.9),(2,(0.,0.,10.,10.),.7)]
        out=m.analysis_of_model_detection_errors(truth,model,.5,.5,.1)
        self.assertFalse(out["independently_adjudicated_fish_occlusion_labels"])
        self.assertEqual(out["density_strata"]["0-25"]["GT"],3)
        self.assertEqual(out["density_strata"]["0-25"]["TP"],2)
        self.assertEqual(out["density_strata"]["0-25"]["FN"],1)
        self.assertEqual(out["GT_2D_box_overlap_proxy"]["GT_box_overlap_proxy"]["GT"],2)
        self.assertEqual(out["GT_2D_box_overlap_proxy"]["GT_box_no_overlap_proxy"]["GT"],1)

    def test_original_model_derived_csv_schema_and_artifact_hash_mismatch_fail(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)
            de=root/"fish_model_detections.csv"
            bt=root/"fish_model_bytetrack.csv"
            report=root/"report.json"
            with de.open("w",newline="") as f:
                w=csv.writer(f);w.writerow(m.MODEL_HEADER)
                w.writerow([43450,1,5,5,8,8,.9,1])
            with bt.open("w",newline="") as f:
                w=csv.writer(f);w.writerow(m.BYTE_HEADER)
            rep={
                "n_real_original_source_images_inferred":101,
                "n_reference_fish_boxes":9214,
                "n_source_gt_IDs":260,
                "original_archive_sha256":m.A_SHA,
                "original_fish_IDs_visible_to_model_or_tracker":False,
                "source_original_frame_start":m.FRAME_START,
                "source_original_frame_end":m.FRAME_START+m.FRAME_COUNT-1,
                "derived_artifact_sha256":{
                    de.name:"0"*64,bt.name:m.metrics.digest(bt)}
                }
            report.write_text(json.dumps(rep))
            with self.assertRaisesRegex(ValueError,"mismatch with original CI hashes"):
                m.parse_source_predictions(de,bt,report)
            rep["derived_artifact_sha256"][de.name]=m.metrics.digest(de)
            rep["n_model_generated_fish_boxes_score_ge_0_25"]=1
            rep["n_model_bytetrack_observations"]=0
            report.write_text(json.dumps(rep))
            source,tracker,_=m.parse_source_predictions(de,bt,report)
            self.assertEqual(len(source),1)
            self.assertEqual(len(tracker),0)
            self.assertEqual(source[0][0],1)

if __name__=="__main__":
    unittest.main()

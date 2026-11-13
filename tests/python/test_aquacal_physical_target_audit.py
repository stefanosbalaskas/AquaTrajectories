"""External real aquarium target source audit numerical contracts."""
import json
import math
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"inst/python"))
import aqt_aquacal_physical_target_audit as m

class OriginalExternalTankPhysicalTargets(unittest.TestCase):
    def example(self,root):
        mm=root/"real_rig_metrics.json";bb=root/"benchmark.json"
        mean=.00025
        std=math.sqrt(.5**2-.25**2)/1000
        mm.write_text(json.dumps({
            "n_comparisons":101,
            "inter_corner_mae_mm":.25,"inter_corner_rmse_mm":.5,
            "mean_relative_error_pct":.25/60*100,
            "mean_reprojection_px":.9,
            "mean_per_camera_reprojection_px":.8}))
        bb.write_text(json.dumps({
            "accuracy":{"validation_3d_error_mean":mean,
                        "validation_3d_error_std":std,
                        "reprojection_rms":.9},
            "environment":{"aquacal_version":"2.0.1",
                           "opencv_version":"4.13.0"},
            "problem_shape":{"n_cameras":13,"n_frames_holdout":52}}))
        return mm,bb

    def test_known_real_geometry_summary_consistency_contract(self):
        with tempfile.TemporaryDirectory() as d:
            source,benchmark=self.example(Path(d))
            checks={"real_rig_metrics.json":m.git_blob(source),
                    "benchmark.json":m.git_blob(benchmark)}
            with patch.dict(m.ORIGINAL_BLOBS,checks,clear=True):
                out=m.audit(source,benchmark)
                self.assertEqual(out["original_heldout_physical_length_comparisons"],101)
                self.assertAlmostEqual(out["source_reported_intercorner_RMSE_mm"],.5)
                self.assertFalse(out["AquaTrajectories_own_XYZ_RMSE_measured"])
                self.assertFalse(out["independent_AquaTrajectories_metrology_certified"])

    def test_original_source_blob_change_and_bad_moment_fails(self):
        with tempfile.TemporaryDirectory() as d:
            source,benchmark=self.example(Path(d))
            with self.assertRaisesRegex(ValueError,"Git blob mismatch"):
                m.audit(source,benchmark)
            content=json.loads(benchmark.read_text())
            content["accuracy"]["validation_3d_error_std"]=.1
            benchmark.write_text(json.dumps(content))
            checks={"real_rig_metrics.json":m.git_blob(source),
                    "benchmark.json":m.git_blob(benchmark)}
            with patch.dict(m.ORIGINAL_BLOBS,checks,clear=True):
                with self.assertRaisesRegex(ValueError,"RMSE differs"):
                    m.audit(source,benchmark)

if __name__=="__main__":
    unittest.main()

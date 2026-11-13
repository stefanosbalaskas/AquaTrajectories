"""Known-truth software tests for tank-blocked joint empirical fish uncertainty."""
import csv
import json
import math
from pathlib import Path
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"inst/python"))
import aqt_joint_empirical_uncertainty as m

def reference_rows(train_tanks=25,holdout_tanks=5,with_failure=False):
    data=[]
    for k in range(train_tanks+holdout_tanks):
        part="train" if k<train_tanks else "holdout"
        for i in range(2):
            error=.01*(k+1) if part=="train" else .005
            row={
                "tank_id":f"TANK_{k:03d}","session_id":f"S{k}",
                "fish_id":"F1","time_s":str(i*.1),
                "partition":part,
                "truth_x":"0","truth_y":"0","truth_z":"5",
                "pred_x":str(error),"pred_y":"0","pred_z":"5",
                "detection_success":"1","identity_correct":"1",
                "pixel_error_a_px":str(error*100),
                "pixel_error_b_px":str(error*50),
                "camera_clock_error_s":str(error/10),
                "calibration_geometry_error_units":str(error/2)
            }
            if with_failure and k==0 and i==0:
                row["detection_success"]="0"
                row["identity_correct"]="0"
                row["pred_x"]=row["pred_y"]=row["pred_z"]=""
            data.append(row)
    return data

def to_csv(path,records):
    with path.open("w",newline="") as f:
        w=csv.DictWriter(f,fieldnames=m.COLUMNS)
        w.writeheader();w.writerows(records)

class JointFishEmpiricalUncertainty(unittest.TestCase):
    def test_source_holdout_tanks_and_conformal_coverage(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/"source.csv"
            to_csv(p,reference_rows())
            data=m.calibrate(m.read_source(p),alpha=.05,n_draws=40,seed=17)
            self.assertEqual(data["n_original_train_tanks"],25)
            self.assertEqual(data["n_original_holdout_tanks"],5)
            self.assertEqual(data["finite_sample_order_statistic_rank"],25)
            self.assertTrue(data["finite_sample_unconditional_joint_interval_available"])
            self.assertAlmostEqual(data["finite_sample_group_max_radial_radius"],.25)
            self.assertEqual(data["holdout_all_frame_tank_coverage_fraction"],1.)
            self.assertEqual(data["holdout_individual_observation_coverage_including_failures"],1.)
            self.assertFalse(data["external_empirical_accuracy_scientifically_certified"])
            self.assertFalse(data["original_physical_XYZ_independent_survey_authenticated"])
            self.assertEqual(len(data["empirical_joint_correlated_draws"]),40)
            cov=data["joint_tank_mean_residual_covariance"]
            self.assertGreater(cov[0][5],0)
            for row in data["empirical_joint_correlated_draws"]:
                self.assertAlmostEqual(row["dx"],10*row["camera_clock_error_s"])

    def test_no_fake_confidence_when_misses_prevent_unconditional_coverage(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/"source.csv"
            to_csv(p,reference_rows(with_failure=True))
            out=m.calibrate(m.read_source(p),n_draws=20)
            self.assertIsNone(out["finite_sample_group_max_radial_radius"])
            self.assertFalse(out["finite_sample_unconditional_joint_interval_available"])
            self.assertIsNone(out["holdout_all_frame_tank_coverage_fraction"])
            self.assertGreater(out["train_holdout_fish_source_failures"]
                ["source_train_detection_failure_fraction"],0)

    def test_missing_tank_holdout_and_frame_pseudoreplication_detected(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/"source.csv"
            rows=reference_rows()
            rows[0]["partition"]="holdout"
            to_csv(p,rows)
            with self.assertRaisesRegex(ValueError,"tank leakage"):
                m.read_source(p)
            rows=reference_rows()
            rows[0]["fish_id"]=rows[1]["fish_id"]
            rows[0]["time_s"]=rows[1]["time_s"]
            to_csv(p,rows)
            with self.assertRaisesRegex(ValueError,"Duplicate original fish/time"):
                m.read_source(p)

    def test_no_wrong_fish_position_on_missing_detection(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/"source.csv"
            rows=reference_rows()
            rows[0]["detection_success"]="0"
            rows[0]["identity_correct"]="0"
            with self.assertRaisesRegex(ValueError,"invented reconstructed"):
                to_csv(p,rows)
                m.read_source(p)
            rows[0]["pred_x"]=rows[0]["pred_y"]=rows[0]["pred_z"]=""
            to_csv(p,rows)
            self.assertFalse(m.read_source(p)[0]["detected"])

    def test_cli_reports_sha_and_does_not_overwrite(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);source=root/"original_empirical.csv";output=root/"report.json"
            to_csv(source,reference_rows())
            argv=["--empirical-source-csv",str(source),
                  "--draws","20","--out",str(output)]
            self.assertEqual(m.main(argv),0)
            r=json.loads(output.read_text())
            self.assertEqual(r["original_source_csv_sha256"],m.sha256(source))
            self.assertFalse(r["source_fish_ID_ground_truth_independently_adjudicated"])
            with self.assertRaisesRegex(FileExistsError,"overwrite"):
                m.main(argv)

if __name__=="__main__":
    unittest.main()

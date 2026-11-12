"""Real FishSizing calibration file schema and safe length-CSV contracts."""
from __future__ import annotations

import csv
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "inst" / "python" / "aqt_ros_stereo_audit.py"
SPEC = importlib.util.spec_from_file_location("aqt_ros_stereo_audit", SRC)
assert SPEC is not None and SPEC.loader is not None
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)

YAML_PRESENT = importlib.util.find_spec("yaml") is not None
FIXTURES = ROOT / "tests" / "fixtures" / "fishsizing"


class FishSizingSchemaContracts(unittest.TestCase):
    @unittest.skipUnless(YAML_PRESENT, "Optional PyYAML not installed")
    def test_real_published_fishsizing_ros_stereo_yaml(self):
        left = audit._load_yaml(FIXTURES / "left.yaml")
        right = audit._load_yaml(FIXTURES / "right.yaml")
        data = audit.audit_ros_stereo_pair(left, right)
        self.assertEqual(data["left"]["image_width"], 2048)
        self.assertEqual(data["left"]["image_height"], 1536)
        self.assertEqual(data["left"]["distortion_model"], "plumb_bob")
        self.assertEqual(len(data["left"]["D"]), 5)
        self.assertEqual(len(data["right"]["P"]), 3)
        self.assertEqual(len(data["right"]["P"][0]), 4)
        self.assertAlmostEqual(data["left"]["K"][0][0], 1433.86998)
        self.assertAlmostEqual(data["right"]["P"][0][3], -179.77544)
        self.assertGreater(
            data["rectified_baseline_magnitude_in_unspecified_units"], 0)
        self.assertEqual(
            data["baseline_unit"],
            "unknown_not_provided_in_calibration_yaml")
        self.assertTrue(data["requires_raw_ROS_image_header_timestamps"])
        self.assertTrue(data["refractive_port_model_requires_separate_metrology"])
        self.assertFalse(data["physical_xyz_accuracy_certified"])

    @unittest.skipUnless(YAML_PRESENT, "Optional PyYAML not installed")
    def test_bad_ros_stereo_intrinsics_are_not_silently_accepted(self):
        left = audit._load_yaml(FIXTURES / "left.yaml")
        right = audit._load_yaml(FIXTURES / "right.yaml")
        right["image_width"] += 1
        with self.assertRaisesRegex(ValueError, "dimensions differ"):
            audit.audit_ros_stereo_pair(left, right)
        right["image_width"] -= 1
        right["distortion_model"] = "fisheye"
        with self.assertRaisesRegex(ValueError, "plumb_bob only"):
            audit.audit_ros_stereo_pair(left, right)
        right["distortion_model"] = "plumb_bob"
        right["projection_matrix"]["data"][3] = 0
        with self.assertRaisesRegex(ValueError, "positive stereo baseline"):
            audit.audit_ros_stereo_pair(left, right)
        right["projection_matrix"]["data"][3] = -179.77544
        left["camera_matrix"]["data"][0] = -3
        with self.assertRaisesRegex(ValueError, "focal lengths"):
            audit.audit_ros_stereo_pair(left, right)

    def test_real_published_nine_specimen_manual_length_source(self):
        path = FIXTURES / "fish_gt_measures.csv"
        original = audit.audit_length_csv(path)
        self.assertEqual(original["n_specimens"], 9)
        self.assertEqual(original["records"][0]["dataset"], "Dataset A")
        self.assertEqual(original["records"][0]["total_length_cm"], 31.5)
        self.assertEqual(original["records"][-1]["total_length_cm"], 32.3)
        self.assertEqual(
            len({row["species_scientific"] for row in original["records"]}), 4)
        self.assertFalse(original["measured_true_XYZ_positions_provided"])
        self.assertFalse(
            original["fish_trajectories_or_swimming_behaviour_certified"])

    def test_quoted_comma_decimal_fish_lengths_from_real_source_convention(self):
        self.assertAlmostEqual(audit.parse_length_cm("31,5"), 31.5)
        self.assertAlmostEqual(audit.parse_length_cm("29,1"), 29.1)
        self.assertEqual(audit.parse_length_cm("30"), 30.)
        for bad in ("", "3.5,2", "-3,0", "0", "nan", "abc"):
            with self.subTest(raw=bad), self.assertRaises(ValueError):
                audit.parse_length_cm(bad)

    def test_manual_fish_measurement_schema_does_not_imply_xyz_or_living_motion(self):
        cols = ["Dataset", "Identifier", "Species_Common_Name",
                "Species_Scientific_Name", "Total_Length_cm"]
        with tempfile.TemporaryDirectory() as folder:
            sample = Path(folder) / "measurements.csv"
            with sample.open("w", encoding="utf-8", newline="") as fh:
                w = csv.writer(fh)
                w.writerow(cols)
                w.writerow(["Dataset A", "Fish 0", "European seabass",
                            "D. labrax", "31,5"])
                w.writerow(["Dataset B", "Red Tag", "European seabass",
                            "D. labrax", "29,1"])
            result = audit.audit_length_csv(sample)
            self.assertEqual(result["n_specimens"], 2)
            self.assertEqual(result["records"][0]["total_length_cm"], 31.5)
            self.assertEqual(result["records"][1]["total_length_cm"], 29.1)
            self.assertFalse(result["measured_true_XYZ_positions_provided"])
            self.assertFalse(
                result["fish_trajectories_or_swimming_behaviour_certified"])
            with sample.open("a", encoding="utf-8", newline="") as fh:
                w = csv.writer(fh)
                w.writerow(["Dataset A", "Fish 0", "European seabass",
                            "D. labrax", "30"])
            with self.assertRaisesRegex(ValueError, "Duplicate biological"):
                audit.audit_length_csv(sample)


if __name__ == "__main__":
    unittest.main()

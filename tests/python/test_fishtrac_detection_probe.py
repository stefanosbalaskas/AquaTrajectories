"""FISHTRAC real public export format, not independent fish ground truth."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

PATH = Path(__file__).resolve().parents[2] / "inst/python/aqt_fishtrac_detection_probe.py"
spec = importlib.util.spec_from_file_location("aqt_fishtrac_detection_probe", PATH)
assert spec and spec.loader
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class FishtracDetectionOnlyContracts(unittest.TestCase):
    def test_original_five_column_normalized_xywh_schema(self):
        with tempfile.TemporaryDirectory() as folder:
            f = Path(folder) / "detections.csv"
            f.write_text(
                "1,0.3375,0.4217592592592593,0.08645833333333333,0.10462962962962963\n"
                "1,0.22473958333333333,0.46064814814814814,0.07447916666666667,0.11388888888888889\n"
                "3,0.5,0.5,0.2,0.2\n")
            result = probe.parse_fishtrac(f, frame_origin=1)
            self.assertEqual(result["n_detection_rows"],3)
            self.assertEqual(result["n_frames_with_detections"],2)
            self.assertEqual(result["unobserved_frame_indices_within_range"],1)
            self.assertEqual(result["observations"][0]["frame_id_zero_based"],0)
            self.assertAlmostEqual(result["observations"][0]["xmin_normalized"],
                                   .3375-.08645833333333333/2)
            for flag in ("individual_fish_ids_provided",
                         "detector_confidence_provided",
                         "independent_ground_truth_provided",
                         "actual_camera_pts_provided",
                         "underwater_xyz_certified"):
                self.assertFalse(result[flag])

    def test_pixel_projection_needs_explicit_dimensions(self):
        with tempfile.TemporaryDirectory() as folder:
            f = Path(folder) / "detections.csv"
            f.write_text("1,0.5,0.5,0.2,0.4\n")
            with self.assertRaisesRegex(ValueError,"Both source image dimensions"):
                probe.parse_fishtrac(f,image_width=100)
            data = probe.parse_fishtrac(f,image_width=100,image_height=80)
            self.assertAlmostEqual(data["observations"][0]["xmin_px"],40.)
            self.assertAlmostEqual(data["observations"][0]["ymin_px"],24.)
            self.assertAlmostEqual(data["observations"][0]["xmax_px"],60.)
            self.assertAlmostEqual(data["observations"][0]["ymax_px"],56.)

    def test_invalid_geometry_and_unknown_frame_origin_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            f = Path(folder) / "detections.csv"
            for invalid in (
                "0,0.5,0.5,0.2,0.4\n",
                "1,0.01,0.5,0.2,0.4\n",
                "1,0.5,0.5,0,0.4\n",
                "1,0.5,nan,0.2,0.4\n",
                "1,0.5,0.5,0.2\n"):
                f.write_text(invalid)
                with self.subTest(invalid=invalid),self.assertRaises(ValueError):
                    probe.parse_fishtrac(f)
            f.write_text("1,0.5,0.5,0.2,0.4\n")
            with self.assertRaisesRegex(ValueError,"frame origin"):
                probe.parse_fishtrac(f,frame_origin=-1)


if __name__=="__main__":
    unittest.main()

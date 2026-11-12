"""Physical header-time pairing does not assume stereo row-count equality."""
from pathlib import Path
import importlib.util
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "inst" / "python" / "aqt_ros_image_header_pairing.py"
SPEC = importlib.util.spec_from_file_location("aqt_ros_image_header_pairing", PATH)
assert SPEC and SPEC.loader
pair = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pair)


class TimestampBasedStereoContracts(unittest.TestCase):
    def test_exact_integer_ros_stamp_and_extra_right_image(self):
        stamp = SimpleNamespace(sec=1700000000, nanosec=987654321)
        self.assertEqual(pair.stamp_ns(stamp), 1700000000987654321)
        with self.assertRaises(ValueError):
            pair.stamp_ns(SimpleNamespace(secs=0, nsecs=1_000_000_000))
        left = [{
            "frame_index": i, "topic": "/left/image",
            "header_stamp_ns": 1_000_000_000 + i * 100_000_000,
            "bag_time_ns": 1_001_000_000 + i * 100_000_000,
        } for i in range(3)]
        right = [{
            "frame_index": i, "topic": "/right/image",
            "header_stamp_ns": t,
            "bag_time_ns": t + 2000,
        } for i, t in enumerate([
            1_000_001_000, 1_100_001_000,
            1_150_000_000, 1_200_001_000])]
        x = pair.stereo_pair(left, right, 2000)
        self.assertEqual(x["audit"]["n_paired"], 3)
        self.assertEqual(x["unmatched_right_frame_indices"], [2])
        self.assertEqual(x["audit"]["max_abs_corrected_header_residual_ns"],
                         1000)
        self.assertFalse(x["audit"]["shared_camera_clock_verified"])
        self.assertFalse(
            x["audit"]["header_stamp_is_verified_hardware_exposure"])
        self.assertFalse(
            x["audit"]["absolute_underwater_xyz_accuracy_certified"])

    def test_offset_sensitivity_and_bad_header_monotonicity(self):
        left = [{
            "frame_index": i, "topic": "L",
            "header_stamp_ns": 100 + i * 100,
            "bag_time_ns": 100 + i * 100,
        } for i in range(3)]
        right = [{
            "frame_index": i, "topic": "R",
            "header_stamp_ns": 110 + i * 100,
            "bag_time_ns": 110 + i * 100,
        } for i in range(3)]
        self.assertEqual(pair.stereo_pair(left,right,2)["audit"]["n_paired"],0)
        self.assertEqual(pair.stereo_pair(left,right,2,-10)["audit"]["n_paired"],3)
        right[1]["header_stamp_ns"] = 100
        with self.assertRaisesRegex(ValueError, "increase strictly"):
            pair.stereo_pair(left, right, 2)

    def test_topic_identity_must_not_be_conflated(self):
        a = [{
            "frame_index": 0, "topic": "camera-A",
            "header_stamp_ns": 100, "bag_time_ns": 101}]
        with self.assertRaisesRegex(ValueError, "topics must differ"):
            pair.stereo_pair(a, a, 10)


if __name__ == "__main__":
    unittest.main()

"""Dependency-free unit contracts for optional AquaTrajectories video runner.

No artificial CI claim of independently validated fish detection.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest


RUNNER = Path(__file__).resolve().parents[2] / "inst" / "python" / "aqt_track_video.py"
SPEC = importlib.util.spec_from_file_location("aqt_track_video", RUNNER)
assert SPEC is not None and SPEC.loader is not None
aqt = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(aqt)


class DummyTensor:
    def __init__(self, data):
        self.data = data

    def cpu(self):
        return self

    def tolist(self):
        return self.data


class DummyBoxes:
    def __init__(self, xyxy, ids, confidence, classes):
        self.xyxy = DummyTensor(xyxy)
        self.id = DummyTensor(ids) if ids is not None else None
        self.conf = DummyTensor(confidence)
        self.cls = DummyTensor(classes)


class DummyResult:
    def __init__(self, boxes):
        self.boxes = boxes


class VideoIngestContracts(unittest.TestCase):
    def test_pts_uses_actual_decoded_timestamps(self):
        origin, t0 = aqt.local_pts(123.5, None, None)
        origin, t1 = aqt.local_pts(123.542, origin, t0)
        origin, t2 = aqt.local_pts(123.710, origin, t1)
        self.assertAlmostEqual(origin, 123.5)
        self.assertEqual(t0, 0.0)
        self.assertAlmostEqual(t1, .042)
        self.assertAlmostEqual(t2, .210)
        # Large presentation gaps are not replaced by 1/nominal_fps.
        self.assertNotAlmostEqual(t2 - t1, 1 / 30)
        with self.assertRaisesRegex(ValueError, "strictly increase"):
            aqt.local_pts(123.710, origin, t2)
        with self.assertRaisesRegex(ValueError, "strictly increase"):
            aqt.local_pts(123.650, origin, t2)
        with self.assertRaisesRegex(ValueError, "finite PyAV PTS"):
            aqt.local_pts(None, origin, t2)

    def test_mot_rows_export_correct_frame_origin_and_xywh(self):
        boxes = [{
            "track_id": 10.0, "confidence": .9, "class_id": 2.0,
            "xyxy": [10, 20, 30, 50]
        }]
        mot, classes = aqt.mot_rows(boxes, frame_id=4,
                                    width_px=100, height_px=80)
        self.assertEqual(len(mot), 1)
        self.assertEqual(mot[0][:2], [5, 10])
        self.assertEqual(mot[0][2:6], [10., 20., 20., 30.])
        self.assertEqual(mot[0][6], .9)
        self.assertEqual(mot[0][7:], [-1, -1, -1])
        self.assertEqual(classes, [[4, 10, 2]])
        self.assertEqual(aqt.mot_rows([], 0, 100, 80), ([], []))

    def test_bounding_box_and_identity_fail_closed(self):
        good = {"track_id": 3, "confidence": .7, "class_id": 1,
                "xyxy": [2, 3, 10, 11]}
        for variation, expected in [
            ({"track_id": -1}, "Tracking IDs"),
            ({"track_id": 1.5}, "Tracking IDs"),
            ({"confidence": -1}, "confidence"),
            ({"confidence": 1.1}, "confidence"),
            ({"class_id": -1}, "Species/class"),
            ({"xyxy": [10, 10, 2, 20]}, "outside image"),
            ({"xyxy": [2, 3, 101, 10]}, "outside image"),
            ({"xyxy": [2, 3, float("nan"), 10]}, "four finite"),
        ]:
            candidate = {**good, **variation}
            with self.subTest(variation=variation), \
                    self.assertRaisesRegex(ValueError, expected):
                aqt.mot_rows([candidate], 0, 100, 80)
        with self.assertRaisesRegex(ValueError, "Duplicate tracker"):
            aqt.mot_rows([good, good], 0, 100, 80)

    def test_ultralytics_adapter_only_exports_real_tracker_ids(self):
        source = DummyResult(DummyBoxes(
            [[1, 2, 10, 20], [30, 40, 50, 60]],
            [3., 9.], [.8, .6], [0., 1.]))
        tracked, skipped = aqt._extract_tracked_boxes(source)
        self.assertEqual(skipped, 0)
        self.assertEqual(len(tracked), 2)
        self.assertEqual(tracked[1]["class_id"], 1.)
        untracked = DummyResult(DummyBoxes(
            [[1, 2, 10, 20]], None, [.8], [0.]))
        self.assertEqual(aqt._extract_tracked_boxes(untracked), ([], 1))
        empty = DummyResult(DummyBoxes([], None, [], []))
        self.assertEqual(aqt._extract_tracked_boxes(empty), ([], 0))

    def test_model_and_video_validation_prior_to_optional_dependencies(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            video = folder / "synthetic.mp4"
            weights = folder / "fish.pt"
            video.write_bytes(b"video example bytes, not a real video")
            weights.write_bytes(b"model example bytes, not real weights")
            for prefix in ("../escape", "two spaces", "bad/path"):
                with self.subTest(prefix=prefix), \
                        self.assertRaisesRegex(ValueError, "prefix"):
                    aqt.run_video(video, weights, folder, prefix,
                                  "session", "camera")
            with self.assertRaisesRegex(ValueError, "confidence"):
                aqt.run_video(video, weights, folder, "valid",
                              "session", "camera", confidence=0)
            with self.assertRaisesRegex(ValueError, "Session/camera"):
                aqt.run_video(video, weights, folder, "valid",
                              "session,unexpected", "camera")
            with self.assertRaisesRegex(ValueError, "Class filter"):
                aqt.run_video(video, weights, folder, "valid",
                              "session", "camera", class_filter=[1, 1])
            self.assertEqual(len(aqt.sha256_file(video)), 64)


if __name__ == "__main__":
    unittest.main()

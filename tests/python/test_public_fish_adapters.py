"""No invented fish identities, PTS, or independent annotation certification."""
from pathlib import Path
import csv
import importlib.util
import json
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
MOD = ROOT / "inst" / "python" / "aqt_public_fish_adapters.py"
SPEC = importlib.util.spec_from_file_location("aqt_public_fish_adapters", MOD)
assert SPEC and SPEC.loader
adapter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(adapter)


class PublicFishAdapterContract(unittest.TestCase):
    def test_fraunhofer_style_datumaro_boxes_tracks_empty_and_ignored(self):
        obj = {
            "categories": {"label": {"labels": [{"name": "fish"}]}},
            "items": [
                {"id": "frame_000001", "annotations": [
                    {"id": 1, "type": "bbox", "group": 1, "label_id": 0,
                     "bbox": [10., 20., 30., 10.], "attributes": {"track_id": 7}},
                    {"id": 2, "type": "polygon", "group": 1, "label_id": 0,
                     "points": [10.,20.,40.,20.,40.,30.,10.,30.],
                     "attributes": {"track_id": 7}}]},
                {"id": "frame_000002", "annotations": []},
                {"id": "frame_000003", "annotations": [
                    {"id": 3, "type": "bbox", "label_id": 0,
                     "bbox": [30., 20., 10., 10.], "attributes": {}},
                    {"id": 4, "type": "bbox", "label_id": 0,
                     "bbox": [50., 20., 10., 10.],
                     "attributes": {"ignored": True}}]}
            ]}
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "fish_datumaro.zip"
            with zipfile.ZipFile(path, "w") as z:
                z.writestr("annotations/default.json", json.dumps(obj))
            data = adapter.convert_datumaro(
                path, "session_A", "TOP", 1, 100, 80)
            self.assertEqual([f["frame_id"] for f in data["frames"]],
                             [0, 1, 2])
            self.assertEqual(len(data["boxes"]), 2)
            self.assertEqual(len(data["tracks"]), 1)
            self.assertEqual(data["tracks"][0]["track_id"], "7")
            self.assertEqual(data["tracks"][0]["x"], 25.)
            self.assertEqual(len(data["issues"]), 1)
            report = adapter.save_dataset(data, root / "output", [path])
            self.assertEqual(report["n_annotated_frames"], 3)
            self.assertEqual(report["n_track_rows"], 1)
            self.assertFalse(report["real_image_pts_verified"])
            self.assertFalse(
                report["source_human_annotation_independently_reverified"])
            with (root / "output/frames.csv").open(newline="") as f:
                frames = list(csv.DictReader(f))
            self.assertEqual(frames[2]["annotation_status"],
                "requires_ignore_mask_or_adjudication")
            with self.assertRaises(FileExistsError):
                adapter.save_dataset(data, root / "output", [path])

    def test_mot_ground_truth_flag_is_not_detector_confidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "seqinfo.ini").write_text(
                "[Sequence]\nname=A\nseqLength=4\nimWidth=100\nimHeight=80\nframeRate=30\n")
            (root / "gt.txt").write_text(
                "1,42,10,20,20,10,1,1,0.8\n"
                "2,42,11,20,20,10,1,1,0.7\n"
                "3,43,10,10,20,20,0,1,0.5\n")
            data = adapter.convert_mot(
                root / "gt.txt", root / "seqinfo.ini", "A", "TOP")
            self.assertEqual(len(data["frames"]), 4)
            self.assertEqual(len(data["boxes"]), 2)
            self.assertEqual(len(data["tracks"]), 2)
            self.assertEqual(len(data["issues"]), 1)
            self.assertEqual(data["frames"][3]["frame_id"], 3)
            self.assertNotIn("confidence", data["boxes"][0])
            report = adapter.save_dataset(
                data, root / "out", [root / "gt.txt", root / "seqinfo.ini"])
            self.assertEqual(report["n_unresolved_annotations"], 1)
            with (root / "out/frames.csv").open(newline="") as f:
                frames = list(csv.DictReader(f))
            self.assertEqual(frames[2]["annotation_status"],
                             "requires_ignore_mask_or_adjudication")

    def test_detection_only_datumaro_never_fabricates_track_ids(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "reference.json"
            path.write_text(json.dumps({
                "categories": {"label": {"labels": [{"name": "fish"}]}},
                "items": [{"id": "frame_0", "annotations": [
                    {"type": "bbox", "label_id": 0,
                     "bbox": [1,2,3,4], "attributes": {}}]}]}))
            data = adapter.convert_datumaro(path, "S", "TOP", 0, 40, 40)
            self.assertEqual(len(data["boxes"]), 1)
            self.assertEqual(len(data["tracks"]), 0)
            with self.assertRaisesRegex(ValueError, "origin"):
                adapter.convert_datumaro(path, "S", "TOP", 1, 40, 40)

    def test_ambiguous_frames_need_explicit_mapping(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "reference.json"
            path.write_text(json.dumps({
                "categories": {"label": {"labels": [{"name": "fish"}]}},
                "items": [{"id": "arbitrary_image", "annotations": []}]}))
            with self.assertRaisesRegex(ValueError, "Ambiguous frame ID"):
                adapter.convert_datumaro(path, "S", "TOP", 0, 20, 20)
            data = adapter.convert_datumaro(
                path, "S", "TOP", 0, 20, 20, {"arbitrary_image": 12})
            self.assertEqual(data["frames"][0]["frame_id"], 12)
            self.assertEqual(len(data["boxes"]), 0)


if __name__ == "__main__":
    unittest.main()

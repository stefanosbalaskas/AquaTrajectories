"""Synthetic contract fixtures for the actual-real-data Oxford source bridge.

These tests are NOT evidence that actual fish inference was run in this test:
real source video, model and tracker bytes are authenticated separately in CI.
"""
from __future__ import annotations

import csv
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "inst" / "python"))
import aqt_m05_real_oxford_bridge as m05


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


class RealSourceBridgeContract(unittest.TestCase):
    def make_sources(self, root):
        root = Path(root)
        source_mp4 = root / "fake_video_not_real.mp4"
        source_mp4.write_bytes(b"SYNTHETIC CONTRACT TEST VIDEO PLACEHOLDER")
        frames = root / "frames.csv"
        reprobed = root / "reprobed_frames.csv"
        with frames.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=m05.FRAME_COLUMNS)
            w.writeheader()
            for i in range(149):
                w.writerow({"session_id": "oxford_eval",
                   "camera_id": "oxford_single_video", "frame_id": i,
                   "time_s": format(i / 25, ".17g"),
                   "width_px": 1920, "height_px": 1080})
        reprobed.write_bytes(frames.read_bytes())
        tracks = root / "model_generated_bytetrack.csv"
        with tracks.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=m05.COLUMNS)
            w.writeheader()
            for i in range(3):
                w.writerow(dict(recording="F30_T15", frame_id=i,
                    frame_mot=i+1, track_id="7", xmin_px=10+i,
                    ymin_px=20, width_px=10, height_px=5,
                    confidence=.81, class_id=0,
                    time_s=format(i/25, ".17g")))
        report = root / "summary.json"
        info = {
            "source_video_model_forward_pass_count": 149,
            "real_source_video_sha256": sha(source_mp4),
            "original_source_labels_prediction_blind_externally_verified": False,
            "official_HOTA_IDF1_measured": False,
            "files_sha256": {"model_generated_bytetrack.csv": sha(tracks)},
            "original_frame_pts_manifest_sha256": sha(frames),
            "newly_generated_bytetrack_rows": 3,
            "scoring": {"0.5": {"F1": .6}},
            "model_components": {"model": "SYNTHETIC_MOCK_ONLY"},
            "tracker_runtime": "MOCK"
        }
        report.write_text(json.dumps(info), encoding="utf-8")
        return source_mp4, frames, reprobed, tracks, report

    def test_preserves_original_clock_and_identity_as_unverified(self):
        with tempfile.TemporaryDirectory() as t:
            video, frames, reprobe, tracks, report = self.make_sources(t)
            with patch.object(m05,"SOURCE_CLIP_SHA256",sha(video)):
                result = m05.run(report,frames,tracks,reprobe,video,
                                 Path(t)/"out")
            self.assertEqual(result["full_original_source_frames"],149)
            self.assertEqual(
                result["n_native_model_generated_bytetrack_observations"],3)
            self.assertFalse(result["fish_id_accuracy_HOTA_IDF1_certified"])
            self.assertFalse(result["new_session_independent_holdout"])
            self.assertFalse(result["new_model_inference_in_this_integration_job"])
            output = (Path(t)/"out"/"oxford_real_bytetrack_mot.csv").read_text()
            self.assertTrue(output.startswith("1,7,10,20,10,5,0.810"))
            self.assertEqual(len(output.splitlines()),3)

    def test_rejects_wrong_source_model_hash_and_partial_manifest(self):
        with tempfile.TemporaryDirectory() as t:
            video, frames, reprobe, tracks, report = self.make_sources(t)
            with patch.object(m05,"SOURCE_CLIP_SHA256",sha(video)):
                data = json.loads(report.read_text())
                data["newly_generated_bytetrack_rows"] = 5
                report.write_text(json.dumps(data))
                with self.assertRaisesRegex(ValueError,"count"):
                    m05.run(report,frames,tracks,reprobe,video,Path(t)/"out1")
                data["newly_generated_bytetrack_rows"] = 3
                report.write_text(json.dumps(data))
                lines = reprobe.read_text().splitlines()
                reprobe.write_text("\n".join(lines[:-1])+"\n")
                with self.assertRaisesRegex(ValueError,"full 149"):
                    m05.run(report,frames,tracks,reprobe,video,Path(t)/"out2")

    def test_rejects_source_time_mismatch_without_manufacturing_timing(self):
        with tempfile.TemporaryDirectory() as t:
            video, frames, reprobe, tracks, report = self.make_sources(t)
            with patch.object(m05,"SOURCE_CLIP_SHA256",sha(video)):
                body = tracks.read_text()
                tracks.write_text(body.replace("0.04","0.33"))
                data = json.loads(report.read_text())
                data["files_sha256"]["model_generated_bytetrack.csv"] = sha(tracks)
                report.write_text(json.dumps(data))
                with self.assertRaisesRegex(ValueError,"time mismatched"):
                    m05.run(report,frames,tracks,reprobe,video,Path(t)/"out")


if __name__=="__main__":
    unittest.main()

#!/usr/bin/env python3
"""Synthetic research-bundle interchange regression tests; no videos or model weights."""
import csv
import json
import sys
import tempfile
import unittest
from argparse import Namespace
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "inst" / "python"))
import aqt_research_bundle as rb


def csv_write(path, rows):
    with path.open("w", newline="", encoding="utf-8") as f:
        csv.writer(f).writerows(rows)


def fixture(root, kind="mot_bytetrack", time_status="source_pts", filename="bundle"):
    root.mkdir(parents=True, exist_ok=True)
    frames = root / "input_frames.csv"
    csv_write(frames, [rb.FRAME_COLUMNS, ["S01","TOP","0","" if time_status=="unknown" else "0","100","80"],
                       ["S01","TOP","1","" if time_status=="unknown" else "0.055","100","80"],
                       ["S01","TOP","2","" if time_status=="unknown" else "0.17","100","80"]])
    source = root / ("input_mot.txt" if kind.startswith("mot_") else "input_tidy.csv")
    if kind.startswith("mot_"):
        csv_write(source, [["1","0007","10","20","10","10","0.8","-1","-1","-1"],
                           ["2","0007","11","20","10","10","0.9","-1","-1","-1"]])
    elif kind == "idtracker_tidy":
        csv_write(source, [["frame","time","individual","x","y","probability"],
                           ["1","0","0007","15","25","0.99"],
                           ["2","0.055","0007","16","25","0.8"],
                           ["3","0.17","0007","NaN","nan","0"]])
    else:
        csv_write(source, [["frame_id","track_id","x_px","y_px","confidence"],
                           ["0","0007","15","25","0.8"],
                           ["1","0007","16","25","0.9"]])
    args = Namespace(kind=kind, source=source, frames=frames, session_id="S01",
                     camera_id="TOP", time_status=time_status,
                     frame_origin=1 if kind.startswith("mot_") or kind=="idtracker_tidy" else 0,
                     model=None, tracker_config=None, clock_evidence=None,
                     out=root / filename)
    return args


class TestResearchBundle(unittest.TestCase):
    def test_mot_both_trackers_and_yolo(self):
        for kind in ("mot_bytetrack", "mot_botsort", "yolo_csv"):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as td:
                args = fixture(Path(td), kind)
                m = rb.create(args)
                self.assertEqual(m["n_frames"], 3)
                self.assertEqual(m["n_observations"], 2)
                self.assertEqual(rb.verify(args.out)["tracking_kind"], kind)
                with (args.out/"observations.csv").open() as f:
                    rows=list(csv.DictReader(f))
                self.assertEqual([r["track_id"] for r in rows], ["0007","0007"])
                self.assertEqual([r["time_s"] for r in rows], ["0","0.055"])
                self.assertEqual(rows[0]["identity_probability"], "")
                if kind.startswith("mot_"):
                    self.assertEqual(rows[0]["x"], "15")
                    self.assertEqual(rows[0]["y"], "25")
                    self.assertEqual(rows[0]["position_definition"], "bbox_center")

    def test_idtracker_native_probability_missing_and_no_fabricated_box(self):
        with tempfile.TemporaryDirectory() as td:
            a = fixture(Path(td), "idtracker_tidy")
            rb.create(a)
            with (a.out/"observations.csv").open() as f:
                rows=list(csv.DictReader(f))
            self.assertEqual(len(rows), 3)
            self.assertEqual(rows[0]["identity_probability"], "0.98999999999999999")
            self.assertEqual(rows[0]["detection_confidence"], "")
            self.assertEqual(rows[0]["bbox_left"], "")
            self.assertEqual(rows[2]["observed"], "FALSE")
            self.assertEqual(rows[2]["quality_flag"], "source_missing_position")
            self.assertEqual(rows[2]["x"], "")
            self.assertEqual(rows[2]["y"], "")
            self.assertEqual(rows[2]["identity_probability"], "0")
            rb.verify(a.out)

    def test_unknown_clock_is_explicit_and_never_inferred(self):
        with tempfile.TemporaryDirectory() as td:
            a = fixture(Path(td), time_status="unknown")
            rb.create(a)
            with (a.out/"observations.csv").open() as f:
                self.assertEqual(next(csv.DictReader(f))["time_s"], "")
            self.assertEqual(rb.verify(a.out)["time_status"], "unknown")

    def test_declared_external_clock_needs_evidence(self):
        with tempfile.TemporaryDirectory() as td:
            a = fixture(Path(td), time_status="externally_verified")
            with self.assertRaisesRegex(ValueError,"clock-evidence"):
                rb.create(a)
            ev = Path(td)/"clock.txt"
            ev.write_text("Synthetic timing evidence; not a real synchronization test")
            a.clock_evidence=ev
            m=rb.create(a)
            self.assertEqual(m["source_files"]["clock_evidence"]["sha256"],rb.sha(ev))

    def test_tamper_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            a=fixture(Path(td))
            rb.create(a)
            with (a.out/"observations.csv").open("a") as f:
                f.write("S01,TOP,7,3,0.20,0,0,TRUE,unreviewed,source_xy,,,,,,,3\n")
            with self.assertRaisesRegex(ValueError,"SHA-256 mismatch"):
                rb.verify(a.out)

    def test_duplicate_identity_rejected_without_partial_publication(self):
        with tempfile.TemporaryDirectory() as td:
            a=fixture(Path(td))
            with a.source.open("a") as f:
                f.write("1,0007,10,20,10,10,0.5,-1,-1,-1\n")
            with self.assertRaisesRegex(ValueError,"Duplicated track identity"):
                rb.create(a)
            self.assertFalse(a.out.exists())

    def test_wrong_time_and_missing_frame_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            a=fixture(Path(td),"idtracker_tidy")
            s=a.source.read_text()
            a.source.write_text(s.replace("2,0.055","2,0.1"))
            with self.assertRaisesRegex(ValueError,"disagrees"):
                rb.create(a)
            self.assertFalse(a.out.exists())
        with tempfile.TemporaryDirectory() as td:
            a=fixture(Path(td))
            a.source.write_text("4,7,10,20,10,10,0.8,-1,-1,-1\n")
            with self.assertRaisesRegex(ValueError,"no matching"):
                rb.create(a)

    def test_explicit_frame_origin(self):
        with tempfile.TemporaryDirectory() as td:
            a=fixture(Path(td))
            a.frame_origin=None
            with self.assertRaisesRegex(ValueError,"origin"):
                rb.create(a)


if __name__ == "__main__":
    unittest.main()

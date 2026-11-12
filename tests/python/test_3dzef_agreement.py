"""Wave 12A: 3D-ZeF agreement is not a physical underwater accuracy claim."""
import csv
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/"inst/python"))
import aqt_3dzef_agreement as z


class ThreeDZeFAgreementContracts(unittest.TestCase):
    def test_original_five_field_rows_and_duplicate_guard(self):
        rows = z.read_tracks("1,1,1.0,2.0,3.0,9,9\n2,1,2,3,4\n", "original")
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0], (1, 1, (1.0, 2.0, 3.0)))
        for bad in ("0,1,1,2,3\n", "1,0,1,2,3\n",
                    "1,1,nan,2,3\n", "1,1,1,2\n",
                    "1,1,1,2,3\n1,1,2,3,4\n"):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                z.read_tracks(bad, "invalid")

    def test_hungarian_global_optimum_and_cardinality(self):
        gt = [(1, 1, (0, 0, 0)), (1, 2, (1, 0, 0))]
        pred = [(1, 7, (.3, 0, 0)), (1, 8, (-.8, 0, 0))]
        result = z.frame_match(gt, pred, .8)
        self.assertEqual(len(result), 2)
        self.assertEqual({(i, j) for i, j, _ in result}, {(0, 1), (1, 0)})

    def test_id_permutation_invariance_and_empty_frame_false_positive(self):
        gt = [(1, 1, (0, 0, 0)), (1, 2, (10, 0, 0)),
              (2, 1, (.1, 0, 0)), (2, 2, (10.1, 0, 0))]
        pred = [(1, 8, (0, 0, 0)), (1, 9, (10, 0, 0)),
                (2, 8, (.1, 0, 0)), (2, 9, (10.1, 0, 0)),
                (3, 77, (4, 4, 4))]
        summary, frames, matches = z.score_agreement(gt, pred, {1, 2, 3}, 5, 1.0)
        self.assertEqual(summary["n_matches"], 4)
        self.assertEqual(summary["false_positives"], 1)
        self.assertEqual(summary["false_positives_on_declared_empty_frames"], 1)
        self.assertEqual(summary["false_negatives"], 0)
        self.assertEqual(summary["IDTP"], 4)
        self.assertEqual(summary["IDFP"], 1)
        self.assertEqual(summary["camera_local_3d_IDF1_like"], 8/9)
        self.assertEqual(summary["matched_3d_euclidean_rmse_cm"], 0)
        self.assertEqual(summary["adjacent_identity_switches"], 0)
        self.assertAlmostEqual(summary["evaluated_frame_fraction"], .6)
        self.assertFalse(summary["independent_physical_xyz_ground_truth_verified"])
        self.assertFalse(summary["official_TrackEval_HOTA_computed"])
        self.assertEqual(len(frames), 3)
        self.assertEqual(len(matches), 4)

    def test_identity_swaps_and_nonadjacent_gaps(self):
        gt = [(1, 1, (1, 1, 1)), (2, 1, (1, 1, 1)), (4, 1, (1, 1, 1))]
        pred = [(1, 5, (1, 1, 1)), (2, 6, (1, 1, 1)), (4, 5, (1, 1, 1))]
        result, _, _ = z.score_agreement(gt, pred, {1, 2, 3, 4}, 4, .1)
        self.assertEqual(result["adjacent_identity_switches"], 1)
        self.assertEqual(result["comparable_adjacent_pairs"], 1)
        self.assertEqual(result["IDTP"], 2)
        self.assertAlmostEqual(result["camera_local_3d_IDF1_like"], 2/3)

    def test_unmatched_and_zero_truth_no_undefined_optimistic_metrics(self):
        data, _, _ = z.score_agreement([], [(1, 1, (1, 1, 1))], {1}, 2, 1)
        self.assertEqual(data["false_positives"], 1)
        self.assertIsNone(data["match_recall"])
        self.assertIsNone(data["matched_3d_euclidean_rmse_cm"])
        self.assertEqual(data["camera_local_3d_IDF1_like"], 0)
        data, _, _ = z.score_agreement([], [], {1}, 2, 1)
        self.assertIsNone(data["camera_local_3d_IDF1_like"])
        self.assertIsNone(data["match_precision"])

    def test_strict_annotation_frame_manifest(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td)/"manifest.csv"
            p.write_text("frame,review_status\n1,fully_annotated\n3,fully_annotated\n")
            frames, reviewers = z.read_evaluated_frames(p, 3)
            self.assertEqual(frames, {1, 3})
            self.assertEqual(reviewers, [])
            for bad in ("frame,review_status\n1,unreviewed\n",
                        "frame,review_status\n1,fully_annotated\n1,fully_annotated\n",
                        "frame,review_status\n4,fully_annotated\n",
                        "frame,review_status\n"):
                with self.subTest(bad=bad):
                    p.write_text(bad)
                    with self.assertRaises(ValueError):
                        z.read_evaluated_frames(p, 3)

    def test_archive_real_format_audit_and_scoring_cli(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            zip_path = root/"labels.zip"
            with zipfile.ZipFile(zip_path, "w") as archive:
                archive.writestr("ZebraFish-01/gt/gt.txt",
                                 "1,1,1,2,3,0,0,0,0\n2,1,2,2,3,0,0,0,0\n")
            audit_json = root/"audit.json"
            self.assertEqual(z.main(["--labels-zip", str(zip_path),
                                    "--audit-json", str(audit_json)]), 0)
            audit = json.loads(audit_json.read_text())
            self.assertEqual(audit["native_gt_count"], 1)
            self.assertEqual(audit["sequences"][0]["observations"], 2)
            self.assertFalse(audit["actual_fish_predictions_scored"])
            predictions = root/"pred.txt"
            predictions.write_text("1,8,1.1,2,3\n2,8,2.1,2,3\n3,9,3,4,5\n")
            reviewed = root/"review.csv"
            reviewed.write_text("frame,review_status,reviewer_id\n"
                                "1,fully_annotated,reviewerA\n"
                                "2,fully_annotated,reviewerA\n"
                                "3,fully_annotated,reviewerA\n")
            output = root/"out"
            self.assertEqual(z.main([
                "--labels-zip", str(zip_path),
                "--archive-member", "ZebraFish-01/gt/gt.txt",
                "--predictions", str(predictions),
                "--evaluated-frames", str(reviewed),
                "--frame-count", "3", "--threshold-cm", "1",
                "--output-dir", str(output)]), 0)
            summary = json.loads((output/"summary.json").read_text())
            self.assertEqual(summary["n_matches"], 2)
            self.assertEqual(summary["false_positives_on_declared_empty_frames"], 1)
            self.assertAlmostEqual(summary["matched_3d_euclidean_rmse_cm"], .1)
            self.assertEqual(summary["reviewer_ids_declared_by_manifest"], ["reviewerA"])
            self.assertFalse(summary["reviewer_independence_externally_verified"])
            self.assertIn("matches.csv", summary["artifact_sha256"])
            self.assertEqual(len(list(csv.DictReader((output/"matches.csv").open()))), 2)
            with self.assertRaises(FileExistsError):
                z.main(["--labels-zip", str(zip_path), "--archive-member",
                        "ZebraFish-01/gt/gt.txt", "--predictions", str(predictions),
                        "--evaluated-frames", str(reviewed),
                        "--frame-count", "3", "--output-dir", str(output)])

    def test_identical_source_label_prediction_leakage_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            gt = root/"gt.txt"
            gt.write_text("1,1,1,2,3\n")
            p = root/"pred.txt"
            p.write_text("1,1,1.0,2.0,3.0\n")
            m = root/"eval.csv"
            m.write_text("frame,review_status\n1,fully_annotated\n")
            with self.assertRaisesRegex(ValueError, "oracle/leakage"):
                z.main(["--truth", str(gt), "--predictions", str(p),
                        "--evaluated-frames", str(m), "--frame-count", "1",
                        "--output-dir", str(root/"out")])
            self.assertFalse((root/"out").exists())

    def test_score_rejects_predictions_outside_declared_video(self):
        with self.assertRaisesRegex(ValueError, "exceeds"):
            z.score_agreement([], [(3, 1, (0, 0, 0))], {1}, 2, 1)
        with self.assertRaisesRegex(ValueError, "threshold"):
            z.score_agreement([], [], {1}, 2, 0)


if __name__ == "__main__":
    unittest.main()

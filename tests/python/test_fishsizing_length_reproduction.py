"""Reproduces original FishSizing filtered-length errors, not fish XYZ truth."""
from pathlib import Path
import csv
import importlib.util
import math
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/"inst/python/aqt_fishsizing_length_reproduction.py"
spec=importlib.util.spec_from_file_location("aqt_fishsizing_length_reproduction",SRC)
assert spec and spec.loader
audit=importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


def source_results(path):
    fields=["frame_id","object_id","fish_3d_ok","filtered_length",
            "gt","abs_error_cm","rel_error_%"]
    with path.open("w",newline="") as f:
        writer=csv.DictWriter(f,fieldnames=fields)
        writer.writeheader()
        writer.writerow({
            "frame_id":"frame_1","object_id":"255","fish_3d_ok":"True",
            "filtered_length":"0.5039277487373863","gt":"29.1",
            "abs_error_cm":"21.29277487373863",
            "rel_error_%":"73.17104767607776"
        })
        writer.writerow({
            "frame_id":"frame_2","object_id":"255","fish_3d_ok":"False",
            "filtered_length":"","gt":"29.1",
            "abs_error_cm":"","rel_error_%":""
        })
        writer.writerow({
            "frame_id":"frame_3","object_id":"255","fish_3d_ok":"False",
            "filtered_length":"0.291","gt":"29.1",
            "abs_error_cm":"0","rel_error_%":"0"
        })


class FishSizingLengthReproductionContracts(unittest.TestCase):
    def test_source_filtered_length_is_meters_and_gt_cm(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/"source.csv"
            source_results(source)
            result=audit.inspect_source_results(source)
            self.assertEqual(result["n_original_result_rows"],3)
            self.assertEqual(result["n_rows_with_filtered_length"],2)
            self.assertEqual(result["n_rows_with_reproducible_source_errors"],2)
            self.assertEqual(result["n_rows_fish_3d_ok_true"],1)
            self.assertEqual(result["n_rows_fish_3d_ok_with_reproduced_error"],1)
            self.assertAlmostEqual(
                result["source_model_per_frame_mae_cm"],
                21.29277487373863/2)
            self.assertFalse(result["source_model_predictions_are_aquatrajectories"])
            self.assertFalse(result["underwater_xyz_position_truth_certified"])
            self.assertFalse(result["statistical_inference_over_frames_permitted"])

    def test_manual_reference_match_does_not_assert_specimen_identity(self):
        with tempfile.TemporaryDirectory() as tmp:
            results=Path(tmp)/"result.csv"
            source_results(results)
            manual=Path(tmp)/"manual.csv"
            manual.write_text(
                'Dataset,Identifier,Species_Scientific_Name,Total_Length_cm\n'
                'Dataset B,Red Tag,D. labrax,"29,1"\n')
            value=audit.inspect_source_results(results,manual)
            self.assertTrue(value["manual_gt_matches_published_length_values_only"])
            self.assertFalse(value["manual_specimen_identity_from_this_csv_certified"])
            manual.write_text(
                'Dataset,Identifier,Species_Scientific_Name,Total_Length_cm\n'
                'Dataset B,Red Tag,D. labrax,"28,9"\n')
            with self.assertRaisesRegex(ValueError,"not among"):
                audit.inspect_source_results(results,manual)

    def test_real_source_negative_one_invalid_sentinel_is_counted_not_used(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/"source.csv"
            source_results(source)
            with source.open("a", newline="") as stream:
                stream.write("frame_86,255,False,-1.0,29.1,,\n")
            report=audit.inspect_source_results(source)
            self.assertEqual(report["n_original_result_rows"],4)
            self.assertEqual(
                report["n_rows_with_invalid_length_sentinel_minus_one"],1)
            self.assertEqual(report["n_rows_with_filtered_length"],2)
            self.assertEqual(
                report["n_rows_with_reproducible_source_errors"],2)
            source.write_text(source.read_text().replace(
                "frame_86,255,False,-1.0,29.1,,",
                "frame_86,255,True,-1.0,29.1,,"))
            with self.assertRaisesRegex(ValueError, "Invalid sentinel"):
                audit.inspect_source_results(source)

    def test_bad_source_reported_error_does_not_silently_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/"source.csv"
            source_results(source)
            text=source.read_text().replace(
                "21.29277487373863","0.000001")
            source.write_text(text)
            with self.assertRaisesRegex(ValueError,"not reproduced"):
                audit.inspect_source_results(source)
            source_results(source)
            source.write_text(source.read_text().replace(
                "73.17104767607776","5.0"))
            with self.assertRaisesRegex(ValueError,"relative error"):
                audit.inspect_source_results(source)


if __name__=="__main__":
    unittest.main()

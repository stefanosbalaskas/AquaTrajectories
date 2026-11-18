"""Source-frame behavioural measurement error: synthetic known-answer contracts.

No real fish truth, physical clock, model execution or ethology in tests.
"""
import math
import importlib.util
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"inst/python"))
import aqt_real_fraunhofer_behaviour_error as e


def gt_fixture():
    truth=[]
    for f in range(1,5):
        for k,bx in ((1,10+f),(2,80+f)):
            truth.append((f,k,(bx,10,10,10),1.))
    return truth


@unittest.skipUnless(
    importlib.util.find_spec("numpy") is not None and
    importlib.util.find_spec("scipy") is not None,
    "Dedicated real-fish error CI installs pinned NumPy/SciPy")
class RealFishErrorContract(unittest.TestCase):
    def test_contiguous_support_gap_and_switch_are_not_interpolated(self):
        truth=gt_fixture()
        pred=[
            (1,41,(11,10,10,10),.9),
            (2,41,(12.5,10,10,10),.9),
            (2,42,(82,10,10,10),.9),
            (3,43,(83,10,10,10),.9),   # fish2 changes predicted ID
            (4,43,(84,10,10,10),.9),
            (4,44,(14,10,10,10),.9),  # fish1 reacquires after missed frame
        ]
        result=e.compute(truth,pred,nframes=4)
        self.assertEqual(result["n_GT_observations"],8)
        self.assertEqual(result["n_IoU_matched_fish_positions"],6)
        self.assertEqual(result["n_adjacent_original_source_GT_fish_intervals"],6)
        self.assertEqual(result["n_same_predicted_identity_supported_adjacent_intervals"],2)
        self.assertEqual(result["n_matched_adjacent_intervals_with_predicted_ID_change"],1)
        self.assertEqual(result["n_adjacent_GT_intervals_without_both_matches"],3)
        self.assertAlmostEqual(result["source_adjacent_interval_support_fraction"],1/3)
        self.assertEqual(result["n_matched_simultaneous_school_pair_distances"],2)
        self.assertEqual(result["missed_detections_followed_by_reacquisition_episodes"],1)
        self.assertEqual(result["identity_changes_on_contiguous_successful_GT_matches"],1)
        self.assertTrue(result["no_unobserved_segment_interpolation"])
        self.assertFalse(result["physical_time_s_or_physical_speed_computed"])
        self.assertEqual(result["observable_units"],"image_px_and_per_adjacent_source_frame_index")
        self.assertIsNotNone(result["common_support_path_length_bias_px"])

    def test_perfect_trajectory_support_exact_zero_errors(self):
        truth=gt_fixture()
        pred=[(f,k,box,.99) for f,k,box,_ in truth]
        r=e.compute(truth,pred,nframes=4)
        self.assertEqual(r["n_same_predicted_identity_supported_adjacent_intervals"],6)
        self.assertAlmostEqual(r["source_adjacent_interval_support_fraction"],1)
        self.assertAlmostEqual(r["common_support_path_length_bias_px"],0)
        self.assertAlmostEqual(r["IoU_0_50_matched_centre_MAE_px"],0)
        self.assertAlmostEqual(
           r["common_support_mean_abs_adjacent_displacement_error_px_per_frame_index"],0)
        self.assertAlmostEqual(r["school_pair_distance_mean_abs_error_px"],0)
        self.assertEqual(r["n_matched_adjacent_intervals_with_predicted_ID_change"],0)
        self.assertEqual(r["missed_detections_followed_by_reacquisition_episodes"],0)

    def test_all_missing_predictions_report_coverage_zero_errors_null(self):
        r=e.compute(gt_fixture(),[],nframes=4)
        self.assertEqual(r["n_IoU_matched_fish_positions"],0)
        self.assertEqual(r["n_adjacent_original_source_GT_fish_intervals"],6)
        self.assertEqual(r["n_same_predicted_identity_supported_adjacent_intervals"],0)
        self.assertEqual(r["n_adjacent_GT_intervals_without_both_matches"],6)
        self.assertEqual(r["source_adjacent_interval_support_fraction"],0)
        self.assertIsNone(r["IoU_0_50_matched_centre_MAE_px"])
        self.assertIsNone(r["common_support_path_length_bias_px"])
        self.assertIsNone(r["school_pair_distance_mean_abs_error_px"])

    def test_an_annotation_gap_is_not_tracker_fragmentation(self):
        source=[(1,1,(10,10,8,8),1.),(3,1,(12,10,8,8),1.)]
        predictions=[(1,10,(10,10,8,8),.9),(3,11,(12,10,8,8),.9)]
        r=e.compute(source,predictions,nframes=3)
        self.assertEqual(r["n_adjacent_original_source_GT_fish_intervals"],0)
        self.assertEqual(r["n_matched_adjacent_intervals_with_predicted_ID_change"],0)
        self.assertEqual(r["identity_changes_on_contiguous_successful_GT_matches"],0)
        self.assertEqual(r["missed_detections_followed_by_reacquisition_episodes"],0)
        self.assertIsNone(r["source_adjacent_interval_support_fraction"])

    def test_gated_false_positive_and_duplicate_fish_id_rejected(self):
        source=[(1,1,(1,1,10,10),1.)]
        predictions=[(1,5,(50,50,8,8),.9)]
        self.assertEqual(e.frame_matches(source,predictions,nframes=1),[])
        with self.assertRaisesRegex(ValueError,"Duplicate"):
            e.frame_matches(source,predictions+predictions,nframes=1)
        with self.assertRaisesRegex(ValueError,"Source tracker frame outside"):
            e.frame_matches(source,[(2,5,(1,1,10,10),.9)],nframes=1)
        with self.assertRaisesRegex(ValueError,"positive IoU"):
            e.frame_matches(source,predictions,gate=0.,nframes=1)

if __name__=="__main__":
    unittest.main()

"""3D-ZeF uses camera pair JSON and 3D tracking labels, not surveyed XYZ."""
import importlib.util
from pathlib import Path
import json
import tempfile
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/"inst/python/aqt_3dzef_source_probe.py"
spec=importlib.util.spec_from_file_location("aqt_3dzef_source_probe",SOURCE)
assert spec and spec.loader
mod=importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class ThreeDZeFSourceContracts(unittest.TestCase):
    def test_original_intrinsic_and_aquarium_correspondence_convention(self):
        lens=mod.inspect_camera_intrinsics({
            "K":[[1400,0,1200],[0,1400,760],[0,0,1]],
            "Distortion":[[.01,-.03,0,0,0]]})
        self.assertEqual(len(lens["distortion_coefficients"]),5)
        self.assertFalse(lens["camera_intrinsic_accuracy_certified"])
        refs=mod.inspect_camera_world_references([
            {"world":{"x":x,"y":y,"z":0},
             "camera":{"x":100+20*x,"y":200+20*y}}
            for x,y in ((0,0),(1,0),(1,1),(0,1))])
        self.assertEqual(refs["reference_count"],4)
        self.assertEqual(refs["world_coordinate_unit_from_original_source"],"cm")
        self.assertTrue(refs["references_are_fitted_calibration_inputs"])
        self.assertFalse(refs["independent_target_holdouts_provided"])
        self.assertFalse(refs["real_xyz_fish_accuracy_certified"])
        with self.assertRaisesRegex(ValueError,"four aquarium corners"):
            mod.inspect_camera_world_references([])

    def test_original_3d_zef_label_fields_and_one_based_origin(self):
        csv="1,1,2.0,3.0,4.0,1,1,0.8,0\n1,2,4.0,5.0,6.0,1,1,0.6,0\n2,1,2.5,3.0,3.7,1,1,0.8,0\n"
        t=mod.inspect_zef_gt_csv(csv)
        self.assertEqual(t["fields"],["frame","id","3d_x","3d_y","3d_z"])
        self.assertEqual(t["n_observations"],3)
        self.assertEqual(t["n_distinct_fish_ids"],2)
        self.assertEqual(t["source_frame_origin"],1)
        self.assertFalse(t["independent_physical_xyz_survey_certified"])
        with self.assertRaisesRegex(ValueError,"Repeated fish"):
            mod.inspect_zef_gt_csv("1,1,1,2,3\n1,1,2,3,4\n")
        with self.assertRaisesRegex(ValueError,"1-based"):
            mod.inspect_zef_gt_csv("0,1,1,2,3\n")

    def test_small_archive_handoff_preserves_original_files_and_provenance(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/"original_labels.zip"
            with zipfile.ZipFile(path,"w") as archive:
                archive.writestr("ZebraFish-01/gt/gt.txt",
                                 "1,1,3.0,4.0,5.0\n2,1,3.3,4.3,5.1\n")
                archive.writestr("ZebraFish-01/cam1_intrinsic.json",
                                 json.dumps({"K":[[1,0,0],[0,1,0],[0,0,1]],
                                             "Distortion":[0,0,0,0,0]}))
            report=mod.inspect_labels_zip(path)
            self.assertEqual(report["n_member_files"],2)
            self.assertEqual(len(report["native_mot_3d_gt_inspections"]),1)
            self.assertEqual(
                report["native_mot_3d_gt_inspections"][0]["inspection"]["n_observations"],2)
            self.assertFalse(report["independent_real_underwater_xyz_certified"])

    def test_unsafe_archive_member_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/"unsafe.zip"
            with zipfile.ZipFile(path,"w") as archive:
                archive.writestr("../unsafe.txt","bad")
            with self.assertRaisesRegex(ValueError,"unsafe path"):
                mod.inspect_labels_zip(path)


if __name__=="__main__":
    unittest.main()

"""Wave 14J real experimental intake fail-closed contracts and test fixtures.

All fixture camera pulses, tank xyz and video bytes are SYNTHETIC
known-truth software tests, not actual fish aquarium evidence.
"""
import hashlib
from pathlib import Path
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"inst/python"))
import aqt_real_multiview_lab_intake as m

SHA="0"*64
def fixtures():
    videos=[]
    for camera in ("TOP","SIDE"):
        videos.append(dict(session_id="S1",camera_id=camera,
            video_path_relative=f"{camera}.mp4",video_sha256=SHA,
            codec="h264",width_px="1920",height_px="1080",
            nominal_fps="25",timestamp_origin="video_local_pts",
            calibration_sha256=SHA))
    pulses=[]
    for camera in ("TOP","SIDE"):
        for i in range(6):
            pulses.append(dict(
                session_id="S1",camera_id=camera,
                marker_id=f"pulse_{i}",time_s=str(float(i)+(0 if camera=="TOP" else .01)),
                measurement_type="hardware_exposure_pulse",
                external_pulse_reference=f"pulse_hardware_ref_{i}"))
    targets=[]
    for i in range(9):
        targets.append(dict(
            trial_id="T1",tank_id="TANK_A",session_id="S1",
            camera_a_id="TOP",camera_b_id="SIDE",
            target_id=f"marker_{i}",
            target_group="BOARD_FIT" if i<6 else "BOARD_HOLDOUT",
            partition="fit" if i<6 else "holdout",
            truth_x=str(i*.02),truth_y=str(i*.01),truth_z=str(.3+i*.05),
            a_u_px=str(50+i),a_v_px=str(90+i),
            b_u_px=str(120+i),b_v_px=str(180+i),
            units="cm",external_survey_record_sha256=SHA))
    events=[dict(
        session_id="S1",tank_id="TANK_A",
        event_id="external_stimulus_1",event_time_s="2.5",
        treatment_arm="exposure_A",randomization_unit="tank",
        randomization_record_sha256=SHA,
        device_id="offline-unverified",ethics_protocol_reference="unverified")]
    return videos,pulses,targets,events

class MultiviewPhysicalCaptureIntake(unittest.TestCase):
    def test_known_truth_software_fixture_to_correct_R_contracts(self):
        v,p,t,e=fixtures()
        result=m.qualify(v,p,t,e,
            [f"pulse_{i}" for i in range(4)],["pulse_4","pulse_5"])
        self.assertEqual(result["source_camera_count"],2)
        self.assertEqual(result["n_raw_original_pulse_rows"],12)
        self.assertEqual(result["n_disjoint_heldout_target_rows"],3)
        self.assertEqual(len(result["R_aqt_target_trial_table_targets"]),9)
        self.assertEqual(set(result["R_aqt_target_trial_table_targets"][0]),
                         set(m.TARGET_COLUMNS[:15]))
        self.assertEqual(set(result["R_aqt_sync_holdout_fit_markers"][0]),
                         {"session_id","camera_id","marker_id","time_s"})
        self.assertFalse(result["physical_XYZ_calibration_error_measured_by_AquaTrajectories"])
        self.assertFalse(result["biological_welfare_or_intervention_effect_validated"])
        self.assertFalse(result["source_video_bytes_hash_verified"])
        self.assertTrue(result["source_hardware_exposure_pulses_alone"])

    def test_same_target_board_or_nonindependent_pulse_fails(self):
        v,p,t,e=fixtures()
        for row in t:row["target_group"]="same_board"
        with self.assertRaisesRegex(ValueError,"Disjoint physical survey boards"):
            m.qualify(v,p,t,e,[f"pulse_{i}" for i in range(4)],["pulse_4","pulse_5"])
        v,p,t,e=fixtures()
        p[-1]["external_pulse_reference"]="different_reference"
        with self.assertRaisesRegex(ValueError,"No common physical pulse reference"):
            m.qualify(v,p,t,e,[f"pulse_{i}" for i in range(4)],["pulse_4","pulse_5"])

    def test_frame_pseudoreplication_and_missing_physical_holdout_fail(self):
        v,p,t,e=fixtures()
        e[0]["randomization_unit"]="fish_frame"
        with self.assertRaisesRegex(ValueError,"independent randomized"):
            m.qualify(v,p,t,e,[f"pulse_{i}" for i in range(4)],["pulse_4","pulse_5"])
        v,p,t,e=fixtures()
        with self.assertRaisesRegex(ValueError,"At least 4 train"):
            m.qualify(v,p,t,e,["pulse_0","pulse_1"],["pulse_4","pulse_5"])
        with self.assertRaisesRegex(ValueError,"distinct independent heldout"):
            m.qualify(v,p,t,e,[f"pulse_{i}" for i in range(4)],["pulse_3","pulse_4"])

    def test_actual_video_bytes_can_be_hashed_but_not_autocertified(self):
        v,p,t,e=fixtures()
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)
            for row in v:
                payload=(row["camera_id"]*8).encode()
                path=root/row["video_path_relative"]
                path.write_bytes(payload)
                row["video_sha256"]=hashlib.sha256(payload).hexdigest()
            out=m.qualify(v,p,t,e,[f"pulse_{i}" for i in range(4)],
                          ["pulse_4","pulse_5"],video_root=root)
            self.assertTrue(out["source_video_bytes_hash_verified"])
            self.assertFalse(out["physical_Hardware_pulse_correspondence_independently_verified"])
            (root/"SIDE.mp4").write_bytes(b"corrupt original")
            with self.assertRaisesRegex(ValueError,"byte SHA differs"):
                m.qualify(v,p,t,e,[f"pulse_{i}" for i in range(4)],
                          ["pulse_4","pulse_5"],video_root=root)

if __name__=="__main__":
    unittest.main()

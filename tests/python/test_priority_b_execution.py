"""Stdlib-only Priority B execution, YOLO split and R handoff contracts.

Fixtures use fake PNG/YOLO weight file bytes solely to validate the data
manifest, hashes and dry-run guards. No neural-network training or fish model
inference occurs and none is claimed.
"""
from __future__ import annotations
import csv
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
from types import SimpleNamespace

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"inst/python"))
import aqt_priority_b_splits as split
import aqt_priority_b_yolo_finetune as train
import aqt_priority_b_run_models as run
import aqt_priority_b_to_r as bridge

def write_csv(path,headers,rows):
    with path.open("w",newline="",encoding="utf-8") as f:
        w=csv.writer(f);w.writerow(headers);w.writerows(rows)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

class PriorityBExecutionContract(unittest.TestCase):
    def make_training(self,root):
        for sub in ("train","val","test"):
            (root/(sub+".png")).write_bytes(
                b"\x89PNG\r\n\x1a\n"+sub.encode()+b"_fake_unreadable_training_guard_only")
            (root/(sub+".txt")).write_text("0 0.5 0.5 0.2 0.2\n")
        weight=root/"original_pretrained.pt";weight.write_bytes(b"FAKE_NO_NETWORK_TRAINING")
        records=[]
        for i,name in enumerate(("train","val","test"),1):
            records.append([name,str(i)*64,0,
                name+".png",name+".txt",sha(root/(name+".png")),
                sha(root/(name+".txt"))])
        manifest=root/"images.csv";write_csv(manifest,train.COLUMNS,records)
        groups=root/"recording_splits.csv"
        write_csv(groups,split.COLUMNS,[
            ["FISH","run1","tank1","session1","1"*64,"train","training_labels"],
            ["FISH","run2","tank2","session2","2"*64,"val","training_labels"],
            ["FISH","run3","tank3","session3","3"*64,"test","fully_annotated"]])
        return manifest,groups,weight

    def test_yolo_training_dry_run_requires_real_bytes_and_leak_free_manifests(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);images,groups,weights=self.make_training(root)
            result=train.train(root/"uncreated",groups,root,images,weights,
                               dry_run=True)
            self.assertFalse(result["training_execution_performed"])
            self.assertTrue(result["no_test_images_or_labels_in_training_yaml"])
            self.assertEqual(result["image_counts"],{"train":1,"val":1,"test":1})
            self.assertFalse((root/"uncreated").exists())
            self.assertEqual(result["initial_weights_sha256"],sha(weights))
            (root/"train.png").write_bytes(b"changed original training input")
            with self.assertRaisesRegex(ValueError,"hash mismatch"):
                train.train(root/"new",groups,root,images,weights,dry_run=True)

    def test_yolo_training_refuses_reused_test_image_or_other_source_split(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);images,groups,weights=self.make_training(root)
            rows=list(csv.DictReader(images.open()))
            rows[2]["image_path"]=rows[0]["image_path"]
            rows[2]["image_sha256"]=rows[0]["image_sha256"]
            write_csv(images,train.COLUMNS,
                      ([row[h] for h in train.COLUMNS] for row in rows))
            with self.assertRaisesRegex(ValueError,"duplicate image"):
                train.train(root/"new",groups,root,images,weights,dry_run=True)
            rows[2]["image_path"]="test.png"
            rows[2]["image_sha256"]=sha(root/"test.png")
            rows[0]["source_video_sha256"]="3"*64
            write_csv(images,train.COLUMNS,
                      ([row[h] for h in train.COLUMNS] for row in rows))
            with self.assertRaisesRegex(ValueError,"source video group or split"):
                train.train(root/"new",groups,root,images,weights,dry_run=True)

    def test_yolo_training_rejects_overlapping_groups_even_if_hashes_differ(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);images,groups,weights=self.make_training(root)
            rows=list(csv.DictReader(groups.open()))
            rows[2]["fish_group_id"]="tank1"
            write_csv(groups,split.COLUMNS,
                      ([row[h] for h in split.COLUMNS] for row in rows))
            with self.assertRaisesRegex(ValueError,"fish_group_id"):
                train.train(root/"new",groups,root,images,weights,dry_run=True)

    def test_actual_runner_command_construction_does_not_execute_models(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            vid=root/"video.mp4";vid.write_bytes(b"FAKE_VIDEO_CONTRACT_ONLY")
            settings=root/"settings.toml";settings.write_text("model='example'\n")
            model=root/"model.pt";model.write_bytes(b"FAKE_WEIGHTS_CONTRACT_ONLY")
            for method in ("idtrackerai","sleap","yolo_bytetrack"):
                plan=run.run(method,vid,model,settings,root/(method+"-out"),
                    root/(method+".slp"),"cpu","hostA",3,"tank1","A","TOP",.25,
                    dry_run=True)
                self.assertFalse(plan["real_video_inference_performed"])
                self.assertEqual(plan["original_video_sha256"],sha(vid))
                self.assertIn(str(vid),plan["full_execution_command"])
                self.assertIn("cpu",plan["full_execution_command"])
                self.assertFalse((root/(method+"-out")).exists())
            with self.assertRaisesRegex(ValueError,"video and verified frame count"):
                run.run("sleap",vid,model,settings,root/"z",root/"p.slp",
                        "cpu","hostA",0,"A","B","C",.25,dry_run=True)
            with self.assertRaisesRegex(ValueError,"fitted source-compatible"):
                run.run("sleap",vid,root/"absent",settings,root/"z",
                        root/"p.slp","cpu","hostA",3,"A","B","C",.25,
                        dry_run=True)
            with self.assertRaisesRegex(ValueError,"independently frozen"):
                run.run("idtrackerai",vid,model,None,root/"z",root/"p.slp",
                        "cpu","hostA",3,"A","B","C",.25,dry_run=True)

    def test_real_pts_to_r_import_uses_no_nominal_fps_or_imputed_frames(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            frames=root/"review.csv"
            write_csv(frames,["frame","review_status"],
                      ((f,"fully_annotated") for f in range(1,5)))
            pts=root/"times.csv"
            write_csv(pts,["frame","time_s"],
                      [(1,0.),(2,.061),(3,.243),(4,2.0)])
            tracks=root/"external.csv"
            write_csv(tracks,["frame","track_id","x_px","y_px","score"],
                      [(1,17,1,2,""),(3,17,3,2,""),(4,17,4,3,""),
                       (1,18,8,9,"")])
            dest=root/"r_native.csv"
            report=bridge.export(tracks,frames,pts,dest,"S","TOP")
            rows=list(csv.DictReader(dest.open()))
            self.assertEqual(len(rows),4)
            self.assertEqual([float(r["time_s"]) for r in rows
                 if r["track_id"]=="17"],[0,.243,2.0])
            self.assertTrue(all(x["observed"]=="TRUE" for x in rows))
            self.assertTrue(report["missing_frames_not_synthetically_interpolated"])
            self.assertEqual(report["units"],"px")
            self.assertEqual(report["source_centres_sha256"],sha(tracks))
            with self.assertRaises(FileExistsError):
                bridge.export(tracks,frames,pts,dest,"S","TOP")

    def test_unverified_pts_or_partial_reference_frames_block_r_export(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            frames=root/"frames.csv";pts=root/"pts.csv";cen=root/"fish.csv"
            write_csv(frames,["frame","review_status"],[
                (1,"fully_annotated"),(2,"fully_annotated")])
            write_csv(pts,["frame","time_s"],[(1,0),(2,0)])
            write_csv(cen,["frame","track_id","x_px","y_px","score"],[
                (1,1,1,1,"")])
            with self.assertRaisesRegex(ValueError,"strictly increasing"):
                bridge.export(cen,frames,pts,root/"r.csv","S","CAM")
            write_csv(pts,["frame","time_s"],[(1,0),(2,.1)])
            write_csv(frames,["frame","review_status"],[
                (1,"fully_annotated"),(2,"partial")])
            with self.assertRaisesRegex(ValueError,"non-reviewed"):
                bridge.export(cen,frames,pts,root/"r.csv","S","CAM")


    def test_idtracker_native_session_output_is_checked_and_preserved(self):
        # Mock the external executable only; the session path handling and
        # frame-completeness checks run as the production code does.
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            video=root/"vid.mp4";video.write_bytes(b"FAKE_NO_REAL_INFERENCE")
            settings=root/"params.toml";settings.write_text("number_of_animals=1\n")
            out=root/"session_results"
            native=root/"preserved"/"trajectories_tidy.csv"
            def fake_subprocess(command,**kwargs):
                self.assertIn("--output_dir",command)
                self.assertIn(str(out),command)
                self.assertIn("--device",command)
                exported=out/"session_vid"/"trajectories"/"trajectories_tidy.csv"
                exported.parent.mkdir(parents=True,exist_ok=True)
                write_csv(exported,["frame","time","individual","x","y","probability"],[
                   [0,0,0,3,5,.99],[1,.1,0,4,5,.99],[2,.2,0,5,6,.99]])
                return SimpleNamespace(returncode=0,stdout="mock",stderr="")
            with mock.patch.object(run.subprocess,"run",side_effect=fake_subprocess):
                record=run.run("idtrackerai",video,None,settings,out,native,
                        "cpu","bench-host",3,"fish","S","CAM",.25)
            self.assertTrue(record["n_input_frames_actually_decoded_verified"])
            self.assertEqual(record["input_video_sha256"],sha(video))
            self.assertEqual(record["native_artifact_sha256"],sha(native))
            self.assertEqual(len(list(csv.DictReader(native.open()))),3)
            self.assertEqual(record["execution_status"],"completed_on_actual_video")
            # This test uses mocked subprocess: cannot certify actual model.
            self.assertEqual(record["native_command"][0],"idtrackerai")

    def test_idtracker_incomplete_native_session_cannot_claim_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            video=root/"vid.mp4";video.write_bytes(b"FAKE_NO_REAL_INFERENCE")
            settings=root/"params.toml";settings.write_text("number_of_animals=1\n")
            out=root/"session_results";native=root/"frozen.csv"
            def missing_frame_subprocess(command,**kwargs):
                exported=out/"session_vid"/"trajectories"/"trajectories_tidy.csv"
                exported.parent.mkdir(parents=True,exist_ok=True)
                write_csv(exported,["frame","time","individual","x","y","probability"],[
                   [0,0,0,3,5,.99],[2,.2,0,5,6,.99]])
                return SimpleNamespace(returncode=0,stdout="",stderr="")
            with mock.patch.object(run.subprocess,"run",side_effect=missing_frame_subprocess):
                with self.assertRaisesRegex(ValueError,"complete frame schedule"):
                    run.run("idtrackerai",video,None,settings,out,native,
                            "cpu","bench-host",3,"fish","S","CAM",.25)
            self.assertFalse(native.exists())
            self.assertFalse((out/"runtime.json").exists())



    def test_sleap_native_slp_preserves_all_frames_including_empty(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            video=root/"example.mp4";video.write_bytes(b"SYNTHETIC_MOCKED_VIDEO")
            model=root/"pose_model";model.mkdir()
            out=root/"sleap_out";native=root/"predicted"/"fish.slp"
            shared_video=object()
            def mocked_command(command,**kwargs):
                self.assertEqual(command[:2],["sleap","predict"])
                native.write_bytes(b"FAKE_SLP_EXTERNAL_EXECUTION_MOCK_ONLY")
                return SimpleNamespace(returncode=0,stdout="mock",stderr="")
            fake_sleap=SimpleNamespace(load_slp=lambda p: [
                SimpleNamespace(frame_idx=i,video=shared_video) for i in range(3)])
            with mock.patch.object(run.subprocess,"run",side_effect=mocked_command), \
                 mock.patch.dict(sys.modules,{"sleap_io":fake_sleap}):
                r=run.run("sleap",video,model,None,out,native,"cpu","hostA",3,
                          "fish","S","CAM",.25)
            self.assertTrue(r["n_input_frames_actually_decoded_verified"])
            self.assertEqual(r["native_artifact_sha256"],sha(native))

    def test_sleap_native_slp_refuses_dropped_zero_detection_frames(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            video=root/"example.mp4";video.write_bytes(b"SYNTHETIC_MOCKED_VIDEO")
            model=root/"pose_model";model.mkdir()
            out=root/"sleap_out";native=root/"predicted"/"fish.slp"
            shared_video=object()
            def mocked_command(command,**kwargs):
                native.write_bytes(b"FAKE_SLP_MISSING_FRAME")
                return SimpleNamespace(returncode=0,stdout="",stderr="")
            fake_sleap=SimpleNamespace(load_slp=lambda p: [
                SimpleNamespace(frame_idx=i,video=shared_video) for i in (0,2)])
            with mock.patch.object(run.subprocess,"run",side_effect=mocked_command), \
                 mock.patch.dict(sys.modules,{"sleap_io":fake_sleap}):
                with self.assertRaisesRegex(ValueError,"complete original frame schedule"):
                    run.run("sleap",video,model,None,out,native,"cpu","hostA",3,
                            "fish","S","CAM",.25)
            self.assertFalse((out/"runtime.json").exists())


if __name__=="__main__":
    unittest.main()

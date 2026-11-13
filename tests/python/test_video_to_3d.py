"""Actual original video-to-3D CLI contract and dependency failure tests.

Every fake camera file / simulated R engine is a software fixture, NOT a
real fish video or independent physical calibration.
"""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"inst/python"))
import aqt_video_to_3d as m

K=[[100.,0.,0.],[0.,100.,0.],[0.,0.,1.]]
R=[[1.,0.,0.],[0.,1.,0.],[0.,0.,1.]]

def config(root,mode="prepared"):
    sources=[]
    for i,camera in enumerate(("TOP","SIDE")):
        bundle=root/camera
        bundle.mkdir(exist_ok=True)
        c={"camera_id":camera,"prefix":camera.lower(),
           "bundle_dir":str(bundle),"calibration":{
              "model":"single_interface","units":"cm",
              "K":K,"R_c2w":R,
              "center":[float(i),0.,0.],
              "plane_point":[0.,0.,1.],"plane_normal":[0.,0.,1.],
              "n_before":1.0,"n_after":1.333},
            "clock":{"source":"unverified_relative_pts",
                     "offset_s":0.,"scale":1.}}
        if mode=="infer":
            video=root/(camera+".mp4")
            weights=root/(camera+".pt")
            video.write_bytes(camera.encode())
            weights.write_bytes(("weights"+camera).encode())
            c["video"]=str(video);c["weights"]=str(weights)
            c["video_sha256"]=m.source_hash(video)
            c["weights_sha256"]=m.source_hash(weights)
        sources.append(c)
    return {"schema_version":"1.0","session_id":"synthetic_S1",
            "cameras":sources,"max_skew_s":.025,
            "max_ray_separation":.5,"min_support":3,
            "ambiguity_margin":.05}

class Video3DOrchestration(unittest.TestCase):
    def test_external_calibration_and_source_video_validation(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            cfg=config(root)
            self.assertEqual(len(m.validated_config(cfg,"prepared")["cameras"]),2)
            cfg["cameras"][1]["calibration"]["units"]="m"
            with self.assertRaisesRegex(ValueError,"one physical unit"):
                m.validated_config(cfg,"prepared")
            cfg=config(root)
            cfg["cameras"][0]["calibration"]["model"]="unknown_air"
            with self.assertRaisesRegex(ValueError,"refractive calibration"):
                m.validated_config(cfg,"prepared")
            cfg=config(root)
            cfg["cameras"][1]["camera_id"]="TOP"
            with self.assertRaisesRegex(ValueError,"unique"):
                m.validated_config(cfg,"prepared")

    def test_video_mode_hash_error_blocks_inference(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            cfg=config(root,"infer")
            path=root/"source.json";path.write_text(json.dumps(cfg))
            (root/"TOP.mp4").write_bytes(b"tampered original fish pixels")
            with self.assertRaisesRegex(ValueError,"source SHA-256 mismatch"):
                m.execute(path,root/"destination",mode="infer")
            self.assertFalse((root/"destination").exists())

    def test_reject_source_clock_or_source_support_omission(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            cfg=config(root)
            cfg["cameras"][0]["clock"].pop("source")
            with self.assertRaisesRegex(ValueError,"clock source"):
                m.validated_config(cfg,"prepared")
            cfg=config(root);cfg.pop("min_support")
            with self.assertRaisesRegex(ValueError,"gates"):
                m.validated_config(cfg,"prepared")

    def test_prepared_mode_calls_native_engine_and_publishes_qualifications_atomically(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            cfg=config(root)
            path=root/"source.json";path.write_text(json.dumps(cfg))
            out=root/"finished_3d"
            commands=[]
            def fake_native(cmd,check,timeout,**kwargs):
                commands.append(cmd)
                self.assertEqual(cmd[0],"Rscript")
                engine=json.loads(Path(cmd[2]).read_text())
                self.assertEqual(len(engine["cameras"]),2)
                self.assertFalse(engine["physical_underwater_accuracy_certified"])
                (Path(cmd[3])/"stereo_audit.json").write_text(json.dumps({
                  "schema_version":"1.0","input_config_sha256":
                      engine["input_config_sha256"],
                  "status":"auto_video_to_3d_provisional_geometry",
                  "n_3d_rows":6,"n_provisional_pair_ids":2,
                  "biological_identity_certified":False,
                  "underwater_physical_xyz_accuracy_certified":False}))
            with patch.object(m.subprocess,"run",side_effect=fake_native):
                report=m.execute(path,out,mode="prepared")
            self.assertEqual(report["n_3d_rows"],6)
            self.assertEqual(len(commands),1)
            self.assertTrue((out/"stereo_audit.json").is_file())
            self.assertTrue((out/"evidence_sha256.json").is_file())
            with self.assertRaisesRegex(FileExistsError,"overwrite"):
                m.execute(path,out,mode="prepared")

    def test_native_engine_cannot_publish_scientific_inflation(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            cfg=config(root)
            path=root/"source.json";path.write_text(json.dumps(cfg))
            dest=root/"out"
            def fake_bad(cmd,check,timeout,**kwargs):
                info=json.loads(Path(cmd[2]).read_text())
                (Path(cmd[3])/"stereo_audit.json").write_text(json.dumps({
                  "schema_version":"1.0",
                  "input_config_sha256":info["input_config_sha256"],
                  "biological_identity_certified":True,
                  "underwater_physical_xyz_accuracy_certified":True}))
            with patch.object(m.subprocess,"run",side_effect=fake_bad):
                with self.assertRaisesRegex(ValueError,"scientific claims"):
                    m.execute(path,dest,mode="prepared")
            self.assertFalse(dest.exists())

if __name__=="__main__":
    unittest.main()

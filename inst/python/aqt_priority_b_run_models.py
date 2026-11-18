#!/usr/bin/env python3
"""Execute native video inference end-to-end and time it on ONE declared host.

idtracker.ai and SLEAP install in their own verified environments; YOLO uses
the existing PyAV+Ultralytics ByteTrack runner. No source GT is supplied to
inference. Captures elapsed wall clock; never creates a synthetic runtime.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time

from aqt_official_fish_trackeval import digest

TOOLS = {"idtrackerai", "sleap", "yolo_bytetrack"}

def cli(method,video,model,settings,native_output,outdir,device,prefix,
        session,camera,confidence):
    if method=="idtrackerai":
        if not settings or not settings.is_file():
            raise ValueError("idtracker.ai requires an independently frozen source TOML")
        return ["idtrackerai","--load",str(settings),"--video_paths",
                str(video),"--trajectories_formats","csv_tidy","--track"]
    if method=="sleap":
        if not model or not model.exists():
            raise ValueError("SLEAP requires fitted source-compatible pose model")
        return ["sleap","predict","-i",str(video),"-m",str(model),
                "--tracking","-o",str(native_output)]
    if method=="yolo_bytetrack":
        if not model or not model.is_file():
            raise ValueError("YOLO must receive original frozen .pt model weights")
        return [sys.executable,str(Path(__file__).resolve().with_name("aqt_track_video.py")),
                "--video",str(video),"--weights",str(model),
                "--output-dir",str(outdir),"--prefix",prefix,
                "--session-id",session,"--camera-id",camera,
                "--confidence",str(confidence),
                "--device",device]
    raise ValueError("Unsupported method")

def installed_versions():
    v={"python":platform.python_version()}
    for pkg in ("idtrackerai","sleap","sleap-io","ultralytics",
                "torch","av","numpy"):
        try: v[pkg]=importlib.metadata.version(pkg)
        except importlib.metadata.PackageNotFoundError:continue
    return v

def run(method,video,model,settings,outdir,native_output,device,
        hardware_id,expected_frames,prefix,session,camera,confidence,
        dry_run=False):
    if method not in TOOLS:raise ValueError("Unsupported method")
    if not video.is_file() or not 1<=expected_frames<=100000:
        raise ValueError("Actual source video and verified frame count required")
    if not hardware_id or not device or not prefix:
        raise ValueError("Declared machine identity, actual device and prefix required")
    if native_output.exists() or outdir.exists():
        raise FileExistsError("Refuse overwriting previously computed fish predictions")
    command=cli(method,video,model,settings,native_output,outdir,device,
                prefix,session,camera,confidence)
    plan={"method":method,"full_execution_command":command,
          "original_video_sha256":digest(video),
          "settings_sha256":digest(settings) if settings else None,
          "weights_sha256":digest(model) if model and model.is_file() else None,
          "machine":hardware_id,"requested_device":device,
          "expected_full_frame_count":expected_frames,
          "real_video_inference_performed":False}
    if dry_run:return plan
    outdir.mkdir(parents=True)
    start=time.perf_counter()
    proc=subprocess.run(command,cwd=str(video.parent),capture_output=True,
                        text=True,check=False)
    wall=time.perf_counter()-start
    (outdir/"native_stdout.log").write_text(proc.stdout,encoding="utf-8")
    (outdir/"native_stderr.log").write_text(proc.stderr,encoding="utf-8")
    if proc.returncode!=0:
        raise RuntimeError("Native inference failed (exit "+str(proc.returncode)+
                           "); inspect retained stderr; no runtime certification")
    if method=="yolo_bytetrack":
        metadata_path=outdir/(prefix+".run.json")
        if not metadata_path.is_file():
            raise RuntimeError("Original YOLO/PyAV inference manifest missing")
        metadata=json.loads(metadata_path.read_text())
        if metadata.get("n_decoded_frames")!=expected_frames or \
            metadata.get("video_sha256")!=plan["original_video_sha256"]:
            raise ValueError("YOLO did not decode the exact full frozen video")
    elif not native_output.is_file() or native_output.stat().st_size<1:
        raise RuntimeError("Native tracker output missing/empty, no benchmark evidence")
    record={
      "phase":"full_inference_and_tracking","method":method,
      "wall_seconds":wall,"hardware_id":hardware_id,"device":device,
      "input_video_sha256":plan["original_video_sha256"],
      "n_input_frames":expected_frames,
      "n_input_frames_actually_decoded_verified":method=="yolo_bytetrack",
      "software_versions":installed_versions(),
      "native_command":command,
      "source_settings_sha256":plan["settings_sha256"],
      "frozen_model_sha256":plan["weights_sha256"],
      "native_artifact_sha256":(digest(native_output)
                                if method!="yolo_bytetrack" else
                                digest(outdir/(prefix+".mot.txt"))),
      "timed_phases":"entire model call including decoding tracking and output",
      "hardware_id_independently_verified":False,
      "model_reference_ids_not_accessible_to_executable":True,
      "reference_truth_used_in_training_not_verified_by_this_runner":True,
      "execution_status":"completed_on_actual_video"
    }
    target=outdir/"runtime.json"
    if target.exists():raise FileExistsError("Native output already includes runtime.json")
    target.write_text(json.dumps(record,sort_keys=True,indent=2,allow_nan=False)+"\n")
    return record

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--method",choices=sorted(TOOLS),required=True)
    p.add_argument("--video",type=Path,required=True)
    p.add_argument("--model",type=Path)
    p.add_argument("--settings",type=Path)
    p.add_argument("--output-dir",type=Path,required=True)
    p.add_argument("--native-output",type=Path,required=True)
    p.add_argument("--device",required=True)
    p.add_argument("--hardware-id",required=True)
    p.add_argument("--expected-frames",type=int,required=True)
    p.add_argument("--prefix",default="fish")
    p.add_argument("--session-id",default="FISH_TEST")
    p.add_argument("--camera-id",default="CAM_1")
    p.add_argument("--confidence",type=float,default=.25)
    p.add_argument("--dry-run",action="store_true")
    a=p.parse_args()
    result=run(a.method,a.video,a.model,a.settings,a.output_dir,
               a.native_output,a.device,a.hardware_id,
               a.expected_frames,a.prefix,a.session_id,
               a.camera_id,a.confidence,a.dry_run)
    print(json.dumps(result,sort_keys=True,indent=2,allow_nan=False))

if __name__=="__main__":main()

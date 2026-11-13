#!/usr/bin/env python3
"""Run original multi-camera videos -> real detector/tracker -> native R 3D.

Each original camera video is decoded using the existing single-pass PyAV
+ Ultralytics YOLO/ByteTrack runner. The verified source bundles, original
PTS, and externally supplied refractive calibration/clock maps are then
passed to the native R crossview matcher and triangulator.

Requires fish detector weights, calibrated camera models and independently
measured synchronization to claim physically meaningful 3D. This script
NEVER invents those inputs, trains fish detectors, controls ACI hardware,
or asserts biological/scientific certification.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ID=re.compile(r"[A-Za-z0-9_-]+\Z")
HEX=re.compile(r"[a-f0-9]{64}\Z")
MAX_VIEWS=6

def source_hash(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda:f.read(1<<20),b""):
            h.update(chunk)
    return h.hexdigest()

def _finite(v,label,lower=None):
    if type(v) not in (int,float) or not math.isfinite(v) or (
        lower is not None and v<lower):
        raise ValueError("Invalid numeric source parameter "+label)
    return float(v)

def _vec(v,n,label):
    if not isinstance(v,list) or len(v)!=n:
        raise ValueError("Invalid source vector "+label)
    return [_finite(x,label) for x in v]

def validated_config(config,mode):
    if not isinstance(config,dict) or config.get("schema_version")!="1.0":
        raise ValueError("Expected AquaTrajectories video-to-3D config schema 1.0")
    if mode not in ("infer","prepared"):
        raise ValueError("source mode must be infer or prepared")
    session=config.get("session_id")
    if not isinstance(session,str) or not ID.fullmatch(session):
        raise ValueError("Unsafe or missing session ID")
    sources=config.get("cameras")
    if not isinstance(sources,list) or not (2<=len(sources)<=MAX_VIEWS):
        raise ValueError("Require 2–6 independently named camera streams")
    names=set();prefixes=set();world_units=set()
    for c in sources:
        if not isinstance(c,dict):
            raise ValueError("Camera declaration must be an object")
        for field in ("camera_id","prefix"):
            v=c.get(field)
            if not isinstance(v,str) or not ID.fullmatch(v):
                raise ValueError("Unsafe or absent camera/prefix identifier")
        if c["camera_id"] in names or c["prefix"] in prefixes:
            raise ValueError("Each camera/prefix must be unique")
        names.add(c["camera_id"]);prefixes.add(c["prefix"])
        cal=c.get("calibration")
        if not isinstance(cal,dict) or cal.get("model") not in (
            "single_interface","parallel_flatport"):
            raise ValueError("Camera must have explicit refractive calibration model")
        if cal.get("units") not in ("cm","m"):
            raise ValueError("Physical camera units must be cm or m")
        world_units.add(cal["units"])
        if not isinstance(cal.get("K"),list) or len(cal["K"])!=3 or (
            not isinstance(cal.get("R_c2w"),list) or len(cal["R_c2w"])!=3):
            raise ValueError("Physical intrinsic/extrinsic matrices required")
        for field in ("K","R_c2w"):
            for row in cal[field]:_vec(row,3,field)
        for field in ("center","plane_point","plane_normal"):
            _vec(cal.get(field),3,field)
        if _finite(cal.get("n_before"),"n_before")<=0 or (
            _finite(cal.get("n_after"),"n_after")<=0):
            raise ValueError("Invalid physical optical indices")
        if cal["model"]=="parallel_flatport":
            if _finite(cal.get("glass_thickness"),"glass_thickness")<=0 or (
                _finite(cal.get("n_water"),"n_water")<=0):
                raise ValueError("Complete two-interface physical glass model required")
        clock=c.get("clock")
        if not isinstance(clock,dict) or clock.get("source") not in (
            "unverified_relative_pts","externally_measured_affine"):
            raise ValueError("Explicit camera clock source must be declared")
        _finite(clock.get("offset_s"),"clock offset")
        if _finite(clock.get("scale"),"clock scale")<=0:
            raise ValueError("Clock scale must be strictly positive")
        if mode=="infer":
            for key in ("video","weights"):
                path=c.get(key)
                if not isinstance(path,str) or not Path(path).is_file():
                    raise FileNotFoundError("Missing original source camera "+key)
            for key in ("video_sha256","weights_sha256"):
                if not isinstance(c.get(key),str) or not HEX.fullmatch(c[key]):
                    raise ValueError("Record original "+key+" SHA-256 before inference")
        else:
            if not isinstance(c.get("bundle_dir"),str) or not Path(c["bundle_dir"]).is_dir():
                raise ValueError("Prepared mode requires actual existing video bundle directory")
    if len(world_units)!=1:
        raise ValueError("All camera calibrations must use one physical unit")
    if any(config.get(key) is None for key in (
        "max_skew_s","max_ray_separation","min_support","ambiguity_margin")):
        raise ValueError("Prespecified camera geometric gates are mandatory")
    _finite(config["max_skew_s"],"max_skew_s",0)
    _finite(config["max_ray_separation"],"max_ray_separation",0)
    _finite(config["ambiguity_margin"],"ambiguity_margin",0)
    support=config["min_support"]
    if type(support) is not int or support<1:
        raise ValueError("Require positive integer temporal support for crossview IDs")
    return config

def execute(config_path,output,mode="prepared",rscript="Rscript",python=sys.executable,
            empirical_source=None,events_source=None):
    original=Path(config_path)
    cfg=validated_config(json.loads(original.read_text(encoding="utf-8")),mode)
    out=Path(output)
    if out.exists():raise FileExistsError("Never overwrite original 3D fish analysis")
    if empirical_source is not None and not Path(empirical_source).is_file():
        raise FileNotFoundError("Actual joint empirical source truth/residual CSV absent")
    if events_source is not None and not Path(events_source).is_file():
        raise FileNotFoundError("Actual fish intervention events source CSV absent")
    out.parent.mkdir(parents=True,exist_ok=True)
    here=Path(__file__).resolve()
    repo=here.parents[2]
    native=repo/"inst/scripts/aqt_video_to_3d_native.R"
    if not native.is_file():raise FileNotFoundError("Native 3D R engine missing")
    temp=Path(tempfile.mkdtemp(prefix=".aqt-3d-",dir=out.parent))
    try:
        bundles=[]
        for index,c in enumerate(cfg["cameras"]):
            if mode=="infer":
                # Source video/weights integrity is a hard precondition.
                for kind in ("video","weights"):
                    actual=source_hash(c[kind])
                    if actual!=c[kind+"_sha256"]:
                        raise ValueError("Original "+kind+" source SHA-256 mismatch")
                bundle_dir=temp/"bundles"/c["camera_id"]
                bundle_dir.mkdir(parents=True,exist_ok=False)
                cmd=[python,str(repo/"inst/python/aqt_track_video.py"),
                     "--video",c["video"],"--weights",c["weights"],
                     "--output-dir",str(bundle_dir),
                     "--prefix",c["prefix"],"--session-id",cfg["session_id"],
                     "--camera-id",c["camera_id"]]
                if c.get("class_filter") is not None:
                    classes=c["class_filter"]
                    if (not isinstance(classes,list) or not classes or
                        any(type(v) is not int or v<0 for v in classes)):
                        raise ValueError("Invalid externally specified fish class IDs")
                    cmd+=["--classes"]+[str(x) for x in classes]
                subprocess.run(cmd,check=True,timeout=36000)
            else:
                bundle_dir=Path(c["bundle_dir"]).resolve()
            bundles.append(dict(camera_id=c["camera_id"],
                                prefix=c["prefix"],bundle_dir=str(bundle_dir),
                                calibration=c["calibration"],clock=c["clock"]))
        # Never accept a numeric FPS in lieu of original decoded PTS.
        engine={"schema_version":"1.0","session_id":cfg["session_id"],
                "cameras":bundles,
                "max_skew_s":cfg["max_skew_s"],
                "max_ray_separation":cfg["max_ray_separation"],
                "min_support":cfg["min_support"],
                "ambiguity_margin":cfg["ambiguity_margin"],
                "input_config_sha256":source_hash(original),
                "source_execution_mode":mode,
                "hardware_sync_certified":False,
                "fish_biological_identity_certified":False,
                "physical_underwater_accuracy_certified":False}
        engine_path=temp/"input_engine.json"
        engine_path.write_text(json.dumps(engine,indent=2,sort_keys=True)+"\n")
        # The R bridge sees verified bundle files, not user-controlled R code.
        subprocess.run([rscript,str(native),str(engine_path),str(temp)],
                       check=True,timeout=1800,cwd=repo)
        result=temp/"stereo_audit.json"
        if not result.is_file():
            raise RuntimeError("Native 3D engine produced no audited output")
        report=json.loads(result.read_text())
        if (report.get("schema_version")!="1.0" or
            report.get("input_config_sha256")!=engine["input_config_sha256"] or
            report.get("biological_identity_certified") is not False or
            report.get("underwater_physical_xyz_accuracy_certified") is not False):
            raise ValueError("Unqualified 3D native output or scientific claims")
        # Optional original event source and independently collected,
        # heldout tank measurement residuals are NEVER fabricated from
        # predictions. The caller must supply them explicitly.
        optional={}
        if events_source is not None:
            with Path(events_source).open(newline="",encoding="utf-8-sig") as fh:
                reader=csv.DictReader(fh)
                if reader.fieldnames!=["event_id","time_s","event_type"]:
                    raise ValueError("Expected original event_id,time_s,event_type source")
                seen=set()
                for row in reader:
                    if not row["event_id"] or row["event_id"] in seen or (
                        not row["event_type"]):
                        raise ValueError("Duplicate or incomplete external fish event")
                    seen.add(row["event_id"])
                    try:t=float(row["time_s"])
                    except (ValueError,TypeError) as e:
                        raise ValueError("Non-numeric original source event time") from e
                    if not math.isfinite(t):
                        raise ValueError("Nonfinite original source event time")
            shutil.copyfile(events_source,temp/"events.csv")
            optional["events_source_sha256"]=source_hash(events_source)
            optional["events_rows"]=len(seen)
            optional["externally_verified_intervention_times"]=False
        if empirical_source is not None:
            module=repo/"inst/python/aqt_joint_empirical_uncertainty.py"
            if not module.is_file():
                raise FileNotFoundError(
                    "Joint empirical calibration module unavailable; merge Wave15B")
            empirical_out=temp/"joint_empirical_calibration.json"
            subprocess.run([python,str(module),
                            "--empirical-source-csv",str(empirical_source),
                            "--xyz-units",cfg["cameras"][0]["calibration"]["units"],
                            "--out",str(empirical_out)],
                           cwd=repo,check=True,timeout=600)
            from_source=json.loads(empirical_out.read_text())
            if (from_source.get("schema")!="aqt_empirical_joint_fish_uncertainty_v1" or
                from_source.get("original_physical_XYZ_independent_survey_authenticated") is not False or
                from_source.get("source_fish_ID_ground_truth_independently_adjudicated") is not False):
                raise ValueError("Empirical source uncertainty claims are not qualified")
            if from_source.get("radius_units")!=cfg["cameras"][0]["calibration"]["units"]:
                raise ValueError("Original empirical source units conflict with the 3D camera model")
            optional["joint_empirical_source_xyz_units"]=from_source["radius_units"]
            optional["joint_empirical_source_csv_sha256"]=source_hash(empirical_source)
            optional["joint_empirical_report_sha256"]=source_hash(empirical_out)
            optional["empirical_joint_source_data_supplied"]=True
            optional["empirical_joint_source_accuracy_independently_certified"]=False
        else:
            optional["empirical_joint_source_data_supplied"]=False
        report["optional_external_evidence"]=optional
        result.write_text(json.dumps(report,indent=2,sort_keys=True)+"\n")
        derivatives=[
            "source_frames.csv","source_2d_tracks.csv","fish_3d_tracks.csv",
            "pairwise_3d_hypotheses.csv","crossview_links.csv",
            "rejected_multiview_3d.csv","stereo_audit.json"]
        evidence={
            "source_config_sha256":source_hash(original),
            "engine_manifest_sha256":source_hash(engine_path),
            "derived_evidence_file_sha256":{
                filename:source_hash(temp/filename)
                for filename in derivatives},
            "source_video_or_bundle_certification":"unverified_external",
            "fish_identity_accuracy_certified":False,
            "physical_xyz_accuracy_certified":False,
            "physical_ACI_device_contacted":False,
            "optional_original_external_evidence":optional}
        (temp/"evidence_sha256.json").write_text(
            json.dumps(evidence,indent=2,sort_keys=True)+"\n")
        os.replace(temp,out)
        return report
    finally:
        if temp.exists():shutil.rmtree(temp,ignore_errors=True)

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--config",required=True,type=Path)
    p.add_argument("--output-dir",required=True,type=Path)
    p.add_argument("--mode",choices=("prepared","infer"),default="prepared")
    p.add_argument("--rscript",default="Rscript")
    p.add_argument("--empirical-source-csv",type=Path,default=None,
       help="Original heldout-tank measured error/XYZ rows; optional, never synthetic")
    p.add_argument("--events-csv",type=Path,default=None,
       help="Original event_id,time_s,event_type source; no timecode inference")
    a=p.parse_args(argv)
    result=execute(a.config,a.output_dir,a.mode,rscript=a.rscript,
                   empirical_source=a.empirical_source_csv,
                   events_source=a.events_csv)
    print(json.dumps({"status":result["status"],
        "n_stereo_observations":result["n_3d_rows"],
        "n_auto_linked_pairs":result["n_provisional_pair_ids"],
        "hardware_sync_certified":False,
        "scientifically_certified_3d":False},indent=2,sort_keys=True))
    return 0

if __name__=="__main__":raise SystemExit(main())

#!/usr/bin/env python3
"""Fail-closed raw real-tank laboratory intake for AquaTrajectories R holdouts.

Converts externally collected camera clock pulses and independently surveyed
underwater targets into aqt_sync_holdout_fit/aqt_target_trial_table inputs.
Never invents an exposure timestamp, a physical XYZ survey, independent
tank replication or fish welfare truth. All physical certification flags
remain FALSE pending external measurement/adjudication.

No real measurements are bundled in this repository.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re

VIDEO_COLUMNS=[
    "session_id","camera_id","video_path_relative","video_sha256",
    "codec","width_px","height_px","nominal_fps",
    "timestamp_origin","calibration_sha256"]
PULSE_COLUMNS=[
    "session_id","camera_id","marker_id","time_s",
    "measurement_type","external_pulse_reference"]
TARGET_COLUMNS=[
    "trial_id","tank_id","session_id","camera_a_id","camera_b_id",
    "target_id","target_group","partition",
    "truth_x","truth_y","truth_z",
    "a_u_px","a_v_px","b_u_px","b_v_px",
    "units","external_survey_record_sha256"]
EVENT_COLUMNS=[
    "session_id","tank_id","event_id","event_time_s",
    "treatment_arm","randomization_unit","randomization_record_sha256",
    "device_id","ethics_protocol_reference"]
HEX64=re.compile(r"[a-fA-F0-9]{64}\Z")

def file_sha256(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda:f.read(1<<20),b""):
            h.update(chunk)
    return h.hexdigest()

def source_table(path,columns,*,allow_empty=False):
    with Path(path).open(newline="",encoding="utf-8-sig") as f:
        r=csv.DictReader(f)
        if r.fieldnames!=columns:
            raise ValueError(f"Laboratory source CSV schema mismatch: {path}")
        rows=list(r)
    if len(rows)>300000 or (not rows and not allow_empty):
        raise ValueError("Empty/oversized empirical laboratory table")
    for row in rows:
        if any(row.get(c) is None or not str(row[c]).strip() for c in columns):
            raise ValueError("Missing empirical source measurement field")
    return rows

def positive(v,label,zero_allowed=False):
    try:x=float(v)
    except (TypeError,ValueError) as e:raise ValueError("Invalid "+label) from e
    if not math.isfinite(x) or (x<0 if zero_allowed else x<=0):
        raise ValueError("Nonfinite/nonpositive "+label)
    return x

def source_id(v,label):
    if not isinstance(v,str) or not v.strip() or len(v)>180:
        raise ValueError("Invalid "+label)
    return v

def digest_field(s,label):
    if not isinstance(s,str) or not HEX64.fullmatch(s):
        raise ValueError("Invalid original source SHA256 "+label)
    return s.lower()

def cameras_and_original_video(video_rows,video_root=None):
    scopes={}
    real_bytes_verified=video_root is not None
    root=Path(video_root).resolve() if video_root is not None else None
    for row in video_rows:
        scope=(source_id(row["session_id"],"session"),
               source_id(row["camera_id"],"camera"))
        if scope in scopes:
            raise ValueError("Duplicate session/camera original source video")
        if row["timestamp_origin"] not in (
            "video_local_pts","hardware_exposure_pulse","unknown"):
            raise ValueError("Never infer exposure clocks from unlabeled PTS")
        pp=PurePosixPath(row["video_path_relative"])
        if (pp.is_absolute() or ".." in pp.parts or
            "\\" in row["video_path_relative"] or pp.suffix.lower() not in
            (".mp4",".mov",".mkv",".avi")):
            raise ValueError("Unsafe/non-video raw capture file path")
        video_sha=digest_field(row["video_sha256"],"video")
        digest_field(row["calibration_sha256"],"camera calibration")
        if not 0<positive(row["width_px"],"frame width")<=20000 or (
            not 0<positive(row["height_px"],"frame height")<=20000):
            raise ValueError("Implausible original frame dimensions")
        positive(row["nominal_fps"],"nominal FPS")
        if root is not None:
            actual=(root/Path(str(pp))).resolve()
            if not actual.is_relative_to(root) or not actual.is_file():
                raise ValueError("Original fish video file inaccessible/outside root")
            if file_sha256(actual)!=video_sha:
                raise ValueError("Original physical video byte SHA differs")
        scopes[scope]=row
    sessions={x[0] for x in scopes}
    for sess in sessions:
        if sum(x[0]==sess for x in scopes)<2:
            raise ValueError("Each real stereo session requires two distinct camera videos")
    return scopes,real_bytes_verified

def source_clock_pulses(rows,scope,training,holdout):
    if len(training)<4 or len(holdout)<2 or len(set(training))!=len(training) or (
        len(set(holdout))!=len(holdout)) or set(training)&set(holdout):
        raise ValueError("At least 4 train and 2 distinct independent heldout pulses required")
    keys=set()
    per_scope={}
    kinds=set()
    for row in rows:
        key=(row["session_id"],row["camera_id"])
        if key not in scope:
            raise ValueError("Pulse camera/session not in original video capture")
        pid=source_id(row["marker_id"],"physical exposure pulse ID")
        composite=(*key,pid)
        if composite in keys:
            raise ValueError("Duplicate pulse ID in physical camera scope")
        keys.add(composite)
        kind=row["measurement_type"]
        if kind not in ("hardware_exposure_pulse","visual_flash","video_local_pts"):
            raise ValueError("Unknown source marker measurement type")
        kinds.add(kind)
        t=float(row["time_s"])
        if not math.isfinite(t):
            raise ValueError("Nonfinite measured camera clock")
        source_id(row["external_pulse_reference"],"external recorded pulse reference")
        per_scope.setdefault(key,{})[pid]=(t,row["external_pulse_reference"],kind)
    required=training+holdout
    for key in scope:
        pulses=per_scope.get(key,{})
        if any(x not in pulses for x in required):
            raise ValueError("Missing independent camera-heldout marker")
    for sess in {key[0] for key in scope}:
        related=[key for key in scope if key[0]==sess]
        for pid in required:
            references={per_scope[key][pid][1] for key in related}
            if len(references)!=1:
                raise ValueError("No common physical pulse reference across actual cameras")
        # A common TEXT reference is NOT hardware proof. Check only
        # internally consistent physical pulse ORDER across cameras.
        reference=per_scope[related[0]]
        order=sorted(required,key=lambda pid:reference[pid][0])
        for key in related:
            arr=[per_scope[key][pid][0] for pid in order]
            if any(y<=x for x,y in zip(arr,arr[1:])):
                raise ValueError("Non-monotonic camera clock matching physical pulse order")
    r_input=[{key:row[key] for key in ("session_id","camera_id","marker_id","time_s")}
             for row in rows]
    return r_input,kinds

def measured_underwater_targets(rows,scopes):
    groups={}
    clean=[]
    for row in rows:
        session=row["session_id"]
        pair=((session,row["camera_a_id"]),(session,row["camera_b_id"]))
        if pair[0]==pair[1] or not all(v in scopes for v in pair):
            raise ValueError("Physical target camera pair must name original dual-view captures")
        if row["partition"] not in ("fit","holdout"):
            raise ValueError("Source target assembly requires fit vs holdout")
        if row["units"] not in ("cm","m"):
            raise ValueError("Physical XYZ measurement units unknown")
        digest_field(row["external_survey_record_sha256"],"independent survey")
        for key in ("truth_x","truth_y","truth_z",
                    "a_u_px","a_v_px","b_u_px","b_v_px"):
            try:v=float(row[key])
            except (TypeError,ValueError) as e:
                raise ValueError("Invalid physical XYZ/pixel measurement") from e
            if not math.isfinite(v):
                raise ValueError("Nonfinite physical XYZ/pixel measurement")
        g=groups.setdefault(row["trial_id"],[])
        g.append(row)
        clean.append({k:row[k] for k in TARGET_COLUMNS[:15]})
    for trial,subset in groups.items():
        single=(subset[0]["tank_id"],subset[0]["session_id"],
                subset[0]["camera_a_id"],subset[0]["camera_b_id"],subset[0]["units"])
        if any((r["tank_id"],r["session_id"],r["camera_a_id"],
                r["camera_b_id"],r["units"])!=single for r in subset):
            raise ValueError("Each physical trial must hold one tank and camera pair")
        ids=[r["target_id"] for r in subset]
        if len(set(ids))!=len(ids):
            raise ValueError("Repeated physical surveyed target ID")
        fit=[r for r in subset if r["partition"]=="fit"]
        test=[r for r in subset if r["partition"]=="holdout"]
        if len(fit)<6 or len(test)<3:
            raise ValueError("Physical target trial requires >=6 fit and >=3 holdout XYZ points")
        if {r["target_group"] for r in fit}&{r["target_group"] for r in test}:
            raise ValueError("Disjoint physical survey boards required for independent holdout")
        for z in (fit,test):
            if len({float(r["truth_z"]) for r in z})<2:
                raise ValueError("True underwater depth variation absent")
        coords=[(r["truth_x"],r["truth_y"],r["truth_z"]) for r in subset]
        if len(set(coords))!=len(coords):
            raise ValueError("Repeated physical XYZ truth coordinate")
    return clean,groups

def event_design(rows,scopes,targets):
    trials={(g[0]["session_id"],g[0]["tank_id"]) for g in targets.values()}
    keys=set()
    for row in rows:
        if (row["session_id"],row["tank_id"]) not in trials:
            raise ValueError("Intervention events outside measured fish tank/session")
        key=(row["session_id"],row["tank_id"],row["event_id"])
        if key in keys:raise ValueError("Duplicate actual intervention event ID")
        keys.add(key)
        if row["randomization_unit"]!="tank":
            raise ValueError("Do not treat fish/frames as independent randomized experimental tanks")
        digest_field(row["randomization_record_sha256"],"randomization record")
        float_time=float(row["event_time_s"])
        if not math.isfinite(float_time):
            raise ValueError("Invalid original intervention event timestamp")
    return {"n_events":len(rows),
            "n_distinct_observed_tanks":len({r["tank_id"] for r in rows}),
            "independent_tank_randomization_externally_audited":False,
            "ethics_approval_externally_verified":False,
            "physical_ACI_actuator_emergency_stop_tested":False}

def qualify(videos,pulses,targets,events,training,holdout,video_root=None):
    captures,verified=cameras_and_original_video(videos,video_root)
    clock,kinds=source_clock_pulses(pulses,captures,training,holdout)
    target_rows,groups=measured_underwater_targets(targets,captures)
    event_state=event_design(events,captures,groups)
    return {
        "source_camera_count":len(captures),
        "n_source_sessions":len({x[0] for x in captures}),
        "source_video_bytes_hash_verified":verified,
        "n_raw_original_pulse_rows":len(clock),
        "n_independent_fit_pulse_IDs":len(training),
        "n_disjoint_heldout_pulse_IDs":len(holdout),
        "pulse_measurement_types":sorted(kinds),
        "source_hardware_exposure_pulses_alone":kinds=={"hardware_exposure_pulse"},
        "n_real_recorded_target_rows":len(target_rows),
        "n_target_trials":len(groups),
        "n_disjoint_heldout_target_rows":sum(
            row["partition"]=="holdout" for row in target_rows),
        "event_intake":event_state,
        "R_aqt_sync_holdout_fit_markers":clock,
        "R_aqt_target_trial_table_targets":target_rows,
        "independently_surveyed_target_authenticity_verified":False,
        "physical_Hardware_pulse_correspondence_independently_verified":False,
        "physical_XYZ_calibration_error_measured_by_AquaTrajectories":False,
        "real_fish_cross_view_ID_accuracy_certified":False,
        "uncertainty_interval_coverage_calibrated":False,
        "biological_welfare_or_intervention_effect_validated":False,
        "note":"Contract validation prepares R holdout inputs. It never establishes the "
               "physical authenticity of user-declared coordinates/pulses or "
               "independent tank-level treatment inference."
    }

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--videos",type=Path,required=True)
    p.add_argument("--pulses",type=Path,required=True)
    p.add_argument("--targets",type=Path,required=True)
    p.add_argument("--events",type=Path,required=True)
    p.add_argument("--training-pulses",required=True,
                   help="Comma-separated >=4 original shared physical pulse IDs")
    p.add_argument("--heldout-pulses",required=True,
                   help="Comma-separated >=2 disjoint original shared physical pulse IDs")
    p.add_argument("--video-root",type=Path,default=None)
    p.add_argument("--out",type=Path,required=True)
    a=p.parse_args(argv)
    out_markers=a.out.with_name(a.out.stem+"_R_markers.csv")
    out_targets=a.out.with_name(a.out.stem+"_R_targets.csv")
    if any(p.exists() for p in (a.out,out_markers,out_targets)):
        raise FileExistsError("Never overwrite original lab intake evidence or R handoff tables")
    sources={"videos":a.videos,"pulses":a.pulses,"targets":a.targets,
             "events":a.events}
    result=qualify(source_table(a.videos,VIDEO_COLUMNS),
                   source_table(a.pulses,PULSE_COLUMNS),
                   source_table(a.targets,TARGET_COLUMNS),
                   source_table(a.events,EVENT_COLUMNS,allow_empty=True),
                   a.training_pulses.split(","),a.heldout_pulses.split(","),
                   video_root=a.video_root)
    result["source_CSV_sha256"]={name:file_sha256(path)
                                  for name,path in sources.items()}
    a.out.parent.mkdir(parents=True,exist_ok=True)
    with out_markers.open("w",newline="",encoding="utf-8") as f:
        columns=["session_id","camera_id","marker_id","time_s"]
        w=csv.DictWriter(f,fieldnames=columns)
        w.writeheader()
        w.writerows(result["R_aqt_sync_holdout_fit_markers"])
    with out_targets.open("w",newline="",encoding="utf-8") as f:
        columns=TARGET_COLUMNS[:15]
        w=csv.DictWriter(f,fieldnames=columns)
        w.writeheader()
        w.writerows(result["R_aqt_target_trial_table_targets"])
    result["R_handoff_csv_sha256"]={
        out_markers.name:file_sha256(out_markers),
        out_targets.name:file_sha256(out_targets)}
    result["R_handoff_paths"]={
        "aqt_sync_holdout_fit_markers":out_markers.name,
        "aqt_target_trial_table_targets":out_targets.name}
    result["real_video_codec_stream_decode_verified"]=False
    a.out.write_text(json.dumps(result,sort_keys=True,indent=2)+"\n")
    print(json.dumps({key:result[key] for key in (
        "source_camera_count","n_source_sessions","n_raw_original_pulse_rows",
        "n_disjoint_heldout_target_rows",
        "source_video_bytes_hash_verified",
        "physical_XYZ_calibration_error_measured_by_AquaTrajectories")},indent=2))
    return 0

if __name__=="__main__":
    raise SystemExit(main())

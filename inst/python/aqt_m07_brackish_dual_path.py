#!/usr/bin/env python3
"""M07: authenticated real BrackishMOT source and frozen model tracks to R tables.

No timestamp generation, biology-ID adjudication, detector scoring, or model
inference. Reference and predicted IDs remain separate, source-local namespaces.
Usage:
    python aqt_m07_brackish_dual_path.py --holdout DIR --model-run DIR --out NEW_DIR
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path

PROTOCOL = "AQT_M07_BRACKISH_REAL_FRAME_INDEX_DUAL_PATH_V1"
SEQUENCES = {"brackishMOT-23":121,"brackishMOT-55":256,"brackishMOT-74":111,
             "brackishMOT-93":150,"brackishMOT-98":230}
FRAME_FIELDS = ["data_path","session_id","camera_id","frame_id",
                "width_px","height_px","time_s","source_frame_id"]
OBS_FIELDS = ["data_path","session_id","camera_id","frame_id",
              "track_id","x","y","bbox_left","bbox_top","bbox_width",
              "bbox_height","detection_confidence","annotation_status"]


def sha256(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):
            h.update(chunk)
    return h.hexdigest()


def read_csv(path):
    with Path(path).open(newline="",encoding="utf-8-sig") as f:
        rd=csv.DictReader(f)
        if not rd.fieldnames or len(set(rd.fieldnames))!=len(rd.fieldnames):
            raise ValueError("Missing/duplicate CSV columns: "+str(path))
        rows=list(rd)
        if any(None in r or None in r.values() for r in rows):
            raise ValueError("Malformed CSV: "+str(path))
    return rows


def number(v,name):
    try:x=float(v)
    except (ValueError,TypeError):raise ValueError("Invalid "+name) from None
    if not math.isfinite(x):raise ValueError("Nonfinite "+name)
    return x


def integer(v,name):
    x=number(v,name)
    if int(x)!=x:raise ValueError("Noninteger "+name)
    return int(x)


def check_evidence(holdout,run):
    holdout=Path(holdout)
    run=Path(run)
    manifest=read_csv(holdout/"SHA256_MANIFEST.csv")
    if set(manifest[0])!={"file","bytes","sha256"} or len(manifest)!=906:
        raise ValueError("Expected original 906-file frozen source manifest")
    if len({r["file"] for r in manifest})!=len(manifest):
        raise ValueError("Duplicate frozen source manifest filename")
    for r in manifest:
        rel=Path(r["file"])
        if rel.is_absolute() or ".." in rel.parts or "\\" in r["file"]:
            raise ValueError("Unsafe manifest path")
        p=holdout/rel
        if not p.is_file() or p.stat().st_size!=integer(r["bytes"],"bytes") or sha256(p)!=r["sha256"]:
            raise ValueError("Frozen source SHA-256 mismatch: "+r["file"])
    protocol_path=holdout/"FROZEN_BENCHMARK_PROTOCOL.json"
    proto=json.loads(protocol_path.read_text(encoding="utf8"))
    if proto.get("protocol")!="AQT_M06_BRACKISH_REAL_FISH_FROZEN_TEST_V2" or not proto.get("frozen_before_model_scoring"):
        raise ValueError("Not qualified real source holdout V2")
    if {z["name"]:z["frames"] for z in proto["selected_sequences"]}!=SEQUENCES:
        raise ValueError("Source holdout sequence coverage drift")
    pred=json.loads((run/"PREDICTION_PROVENANCE.json").read_text(encoding="utf8"))
    if pred.get("protocol")!="AQT_M06_FROZEN_MODEL_PREDICTIONS_V1" or not pred.get("predictions_created"):
        raise ValueError("Not authentic saved model predictions")
    if pred.get("holdout_protocol_sha256")!=sha256(protocol_path):
        raise ValueError("Original frozen source/provenance mismatch")
    if pred.get("original_GT_not_passed_to_model_or_tracker") is not True or pred.get("reference_files_accessed_during_inference") is not False:
        raise ValueError("Prediction-source separation not declared")
    hashes={"model_tracked.csv":"tracks_sha256",
            "model_detections.csv":"detections_sha256",
            "model_invalid_predictions.csv":"invalid_predictions_sha256",
            "model_geometry_adjustments.csv":"geometry_adjustments_sha256"}
    for name,field in hashes.items():
        if sha256(run/name)!=pred.get(field):
            raise ValueError("Frozen model output hash mismatch: "+name)
    return proto,pred,len(manifest)


def make_observation(path,seq,frame,identity,left,top,right,bottom,width,height,confidence,annotation):
    if frame<0 or frame>=SEQUENCES[seq] or not identity or any(c in identity for c in "\r\n"):
        raise ValueError("Invalid scoped frame/identity")
    if not (0<=left<right<=width+1e-5 and 0<=top<bottom<=height+1e-5):
        raise ValueError("Invalid original image geometry")
    if confidence!="" and not 0<=number(confidence,"confidence")<=1:
        raise ValueError("Invalid confidence")
    return [path,seq,"camera_1",frame,identity,(left+right)/2,
            (top+bottom)/2,left,top,right-left,bottom-top,
            confidence,annotation]


def write_csv(path,header,rows):
    with Path(path).open("w",encoding="utf8",newline="") as f:
        w=csv.writer(f,lineterminator="\n")
        w.writerow(header); w.writerows(rows)


def prepare(holdout,run,out):
    holdout=Path(holdout);run=Path(run);out=Path(out)
    if out.exists():raise FileExistsError("Output must be new; refusing overwrite")
    if not out.parent.is_dir():raise FileNotFoundError("Output parent directory missing")
    proto,pred,n_checked=check_evidence(holdout,run)
    model=read_csv(run/"model_tracked.csv")
    if set(model[0])!={"sequence","frame","track_id","xmin","ymin","xmax","ymax","score"}:
        raise ValueError("Unexpected model tracking table columns")
    from collections import defaultdict
    by_seq=defaultdict(list)
    for r in model:
        if r["sequence"] not in SEQUENCES:raise ValueError("Unrecognized model sequence")
        by_seq[r["sequence"]].append(r)
    frame_rows=[]; observation_rows=[]; coverage=[]; original_reference_rows=0
    for seq,nframes in SEQUENCES.items():
        base=holdout/"sequences"/seq
        frames=read_csv(base/"all_frames.csv")
        reference=read_csv(base/"fish_reference.csv")
        if len(frames)!=nframes:
            raise ValueError("Incomplete real source frame manifest")
        if not {"session_id","camera_id","frame_id","source_frame_id","width_px","height_px","time_seconds"}.issubset(frames[0]):
            raise ValueError("Unexpected original manifest")
        dims={}
        for j,r in enumerate(frames):
            f=integer(r["frame_id"],"reference frame")
            if f!=j or integer(r["source_frame_id"],"original frame")!=j+1:
                raise ValueError("Inconsistent original/local frame indexing")
            if r["time_seconds"].strip():raise ValueError("Measured time unexpectedly present: not a frame-indexed-only study")
            if r["session_id"]!=seq or r["camera_id"]!="camera_1":
                raise ValueError("Original source scope mismatch")
            width=integer(r["width_px"],"image width");height=integer(r["height_px"],"image height")
            if width<=0 or height<=0:raise ValueError("Invalid frame dimensions")
            dims[f]=(width,height)
            for source in ("reference","model"):
                frame_rows.append([source,seq,"camera_1",f,width,height,"",j+1])
        pairs=set();nref=0;npred=0
        for r in reference:
            if not {"session_id","camera_id","frame_id","source_frame_id","track_id","xmin","ymin","xmax","ymax","class_id"}.issubset(r):
                raise ValueError("Unexpected original fish annotation fields")
            f=integer(r["frame_id"],"ref frame")
            if r["session_id"]!=seq or r["camera_id"]!="camera_1" or r["class_id"]!="fish" or integer(r["source_frame_id"],"source ref frame")!=f+1:
                raise ValueError("Mixed reference class/source scope")
            width,height=dims[f]
            identity=r["track_id"]
            key=(f,identity)
            if key in pairs:raise ValueError("Duplicate reference frame/identity")
            pairs.add(key)
            box=[number(r[x],x) for x in ("xmin","ymin","xmax","ymax")]
            observation_rows.append(make_observation("reference",seq,f,identity,*box,width,height,"",r.get("annotation_status","published_unadjudicated")))
            nref+=1
        pairs.clear()
        for r in by_seq[seq]:
            f=integer(r["frame"],"model frame")-1
            if f not in dims:raise ValueError("Model frame outside source")
            identity=r["track_id"]
            key=(f,identity)
            if key in pairs:raise ValueError("Duplicate predicted frame/identity")
            pairs.add(key)
            width,height=dims[f]
            box=[number(r[x],x) for x in ("xmin","ymin","xmax","ymax")]
            conf=number(r["score"],"model score")
            observation_rows.append(make_observation("model",seq,f,identity,*box,width,height,conf,"model_generated_not_biologically_adjudicated"))
            npred+=1
        coverage.append({"sequence":seq,"n_frames":nframes,"reference_rows":nref,"model_track_rows":npred})
        original_reference_rows+=nref        selected=next(z for z in proto["selected_sequences"] if z["name"]==seq)
        if nref!=selected["fish_gt_rows"]:
            raise ValueError("Published fish reference row count changed")
    if original_reference_rows!=6621 or len(model)!=2830:
        raise ValueError("Original M06 source/predicted observation denominators changed")
    out.mkdir()
    write_csv(out/"M07_FRAMES.csv",FRAME_FIELDS,frame_rows)
    write_csv(out/"M07_OBSERVATIONS.csv",OBS_FIELDS,observation_rows)
    write_csv(out/"M07_PER_SEQUENCE_SOURCE_COUNTS.csv",["sequence","n_frames","reference_rows","model_track_rows"],
              ([r[k] for k in ("sequence","n_frames","reference_rows","model_track_rows")] for r in coverage))
    record={
        "schema":PROTOCOL,"source_data_origin":"real published BrackishMOT annotations; not independently re-adjudicated",
        "model_data_origin":"real NMFS-OSI YOLO inference + genuine ByteTrack outputs",
        "biological_identification_certified":False,
        "camera_calibration_supplied":False,
        "measured_frame_timestamps_supplied":False,
        "physical_speed_and_acceleration_supported":False,
        "feeding_treatment_event_or_replication_supported":False,
        "score_against_source_reference_is_not_blind_re_adjudication":True,
        "selected_sequences":sorted(SEQUENCES),
        "n_reference_rows":original_reference_rows,"n_model_track_rows":len(model),
        "n_source_frames":sum(SEQUENCES.values()),
        "n_frame_index_path_rows":len(frame_rows),
        "independent_unchanged_source_checks":n_checked,
        "source_manifest_sha256":sha256(holdout/"SHA256_MANIFEST.csv"),
        "source_protocol_sha256":sha256(holdout/"FROZEN_BENCHMARK_PROTOCOL.json"),
        "model_provenance_sha256":sha256(run/"PREDICTION_PROVENANCE.json"),
        "upstream_scientific_scores_sha256":sha256(run/"SCIENTIFIC_SCORES.json") if (run/"SCIENTIFIC_SCORES.json").is_file() else None,
        "input_shas":{x:sha256(out/x) for x in ("M07_FRAMES.csv","M07_OBSERVATIONS.csv","M07_PER_SEQUENCE_SOURCE_COUNTS.csv")},
        "scoped_id_warning":"Model and reference identities are NOT pairwise matched or assumed interchangeable",
        "time_warning":"Never interpret frame index or nominal seqinfo FPS as measured time; use px per adjacent recorded frame only",
    }
    (out/"M07_PROVENANCE.json").write_text(json.dumps(record,indent=2,sort_keys=True)+"\n",encoding="utf8")
    print("M07_REAL_SOURCE_DUAL_PATH_PASS", "frames",sum(SEQUENCES.values()),
          "reference",original_reference_rows,"model",len(model),
          "source_checks",n_checked)
    print("OUTPUT",out)
    return record


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--holdout",type=Path,required=True)
    p.add_argument("--model-run",type=Path,required=True)
    p.add_argument("--out",type=Path,required=True)
    a=p.parse_args()
    prepare(a.holdout,a.model_run,a.out)

if __name__=="__main__":main()

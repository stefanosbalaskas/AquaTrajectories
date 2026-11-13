#!/usr/bin/env python3
"""Compare two trackers on THE SAME real external fish-model predictions.

Consumes Wave14G's cryptographically-hashed derived detector+ByteTrack CSVs
and genuine source HHI ricefish A original MOT labels, with original-image
frame mapping; runs independent IoU/Hungarian association on MODEL boxes.
Computes official TrackEval and real density/2D box-overlap error strata.
Box overlap is a geometric proxy, NOT validated manual occlusion labels.

This is an exploratory domain transfer to 101 frames from one source, not a
blind independently adjudicated species-general detector certificate.
"""
from __future__ import annotations
import argparse
from collections import defaultdict
import csv
import hashlib
import io
import json
import math
from pathlib import Path, PurePosixPath
import tempfile
import zipfile

import aqt_official_fish_trackeval as metrics

A_SHA="18c39619b1f84ea774f16fedfac5911d92de86ab7da4aa03cf365b9b4be58ceb"
GT_SHA="b70a699b4e41cbec636e5f4b500482451d40ddad29fb387dc36dc0c6392021d3"
FRAME_START=43450
FRAME_COUNT=101
WIDTH=2448
HEIGHT=2048

MODEL_HEADER=["source_frame","frame","x","y","w","h","confidence","unverified_fish_class_index"]
BYTE_HEADER=["local_frame","track_id","x","y","w","h","confidence"]

def source_gt(path):
    if metrics.digest(path)!=A_SHA:
        raise ValueError("Original archived external fish source SHA differs")
    with zipfile.ZipFile(path) as z:
        names=z.namelist()
        if len(names)>300 or any(
            PurePosixPath(v).is_absolute() or ".." in PurePosixPath(v).parts or
            "\\" in v for v in names):
            raise ValueError("Original archive paths are unsafe")
        gt=[v for v in names if v.lower().endswith("/gt/gt.txt")]
        imgs=[v for v in names if v.lower().endswith((".jpg",".jpeg",".png"))]
        if len(gt)!=1 or len(imgs)!=FRAME_COUNT:
            raise ValueError("Expected exact original HHI ricefish A full GT/image coverage")
        raw=z.read(gt[0])
        if hashlib.sha256(raw).hexdigest()!=GT_SHA:
            raise ValueError("Original fish GT source hash differs")
        try: frame_ids=[int(PurePosixPath(f).stem) for f in imgs]
        except ValueError as e:raise ValueError("Nonnumeric original frame") from e
        if sorted(frame_ids)!=list(range(FRAME_START,FRAME_START+FRAME_COUNT)):
            raise ValueError("Source image timestamp/frame provenance differs")
    observed=set()
    rows=[]
    for source in csv.reader(io.StringIO(raw.decode("utf-8-sig"))):
        if not source:continue
        if len(source)<7:raise ValueError("Malformed original fish identity GT")
        try:f=int(source[0])
        except ValueError as e:raise ValueError("Invalid original absolute fish GT frame") from e
        if not FRAME_START<=f<FRAME_START+FRAME_COUNT:
            raise ValueError("GT row absent from original image sequence")
        observed.add(f)
        modified=list(source)
        modified[0]=str(f-FRAME_START+1)
        rows.append(modified)
    if len(rows)!=9214 or observed!=set(frame_ids):
        raise ValueError("Original source GT source fish row/frame count mismatch")
    with tempfile.TemporaryDirectory() as td:
        temp=Path(td)/"source_local.txt"
        with temp.open("w",newline="") as fh:
            csv.writer(fh).writerows(rows)
        gt=metrics.mot_rows(temp,FRAME_COUNT,is_ground_truth=True)
    if len({x[1] for x in gt})!=260:
        raise ValueError("Source original 260 unique fish IDs mismatch")
    return gt

def strict_csv(path,fields):
    with Path(path).open(newline="",encoding="utf-8-sig") as f:
        reader=csv.DictReader(f)
        if reader.fieldnames!=fields:
            raise ValueError("Unexpected original model-derived CSV schema")
        data=list(reader)
    if len(data)>100000:
        raise ValueError("Unreasonably large source tracker export")
    return data

def finite_row(row,fields):
    values={}
    for name in fields:
        try:v=float(row[name])
        except (ValueError,TypeError) as e:
            raise ValueError("Invalid source prediction numeric "+name) from e
        if not math.isfinite(v):
            raise ValueError("Nonfinite source prediction numeric "+name)
        values[name]=v
    return values

def parse_source_predictions(model_csv,byte_csv,report_json):
    report=json.loads(Path(report_json).read_text(encoding="utf-8"))
    if (report.get("n_real_original_source_images_inferred")!=FRAME_COUNT or
        report.get("n_reference_fish_boxes")!=9214 or
        report.get("n_source_gt_IDs")!=260 or
        report.get("original_archive_sha256")!=A_SHA or
        report.get("original_fish_IDs_visible_to_model_or_tracker") is not False or
        report.get("source_original_frame_start")!=FRAME_START or
        report.get("source_original_frame_end")!=FRAME_START+FRAME_COUNT-1):
        raise ValueError("Unqualified external model source evidence")
    expected=report.get("derived_artifact_sha256",{})
    for path in (model_csv,byte_csv):
        if expected.get(Path(path).name)!=metrics.digest(path):
            raise ValueError("Derived model/ByteTrack CSV mismatch with original CI hashes")
    model=[]
    for row in strict_csv(model_csv,MODEL_HEADER):
        v=finite_row(row,MODEL_HEADER)
        frame=int(v["frame"])
        original=int(v["source_frame"])
        if frame!=v["frame"] or original!=v["source_frame"] or (
            frame<1 or frame>FRAME_COUNT or original!=FRAME_START+frame-1):
            raise ValueError("Source frame / local identity mismatch")
        x,y,w,h=(v[k] for k in ("x","y","w","h"))
        if not(0<=x<x+w<=WIDTH+1 and 0<=y<y+h<=HEIGHT+1 and
               0<=v["confidence"]<=1):
            raise ValueError("Unphysical source model detector output")
        model.append((frame,(x,y,w,h),v["confidence"]))
    assigned=[]
    keys=set()
    for row in strict_csv(byte_csv,BYTE_HEADER):
        v=finite_row(row,BYTE_HEADER)
        frame=int(v["local_frame"])
        identity=int(v["track_id"])
        if (frame!=v["local_frame"] or identity!=v["track_id"] or
            not 1<=frame<=FRAME_COUNT or identity<1 or
            (frame,identity) in keys):
            raise ValueError("Original ByteTrack fish ID duplication or invalid source frame")
        keys.add((frame,identity))
        x,y,w,h=(v[k] for k in ("x","y","w","h"))
        if not(0<=x<x+w<=WIDTH+1 and 0<=y<y+h<=HEIGHT+1 and
               0<=v["confidence"]<=1):
            raise ValueError("Invalid original model-generated ByteTrack rectangle")
        assigned.append((frame,identity,(x,y,w,h),v["confidence"]))
    if len(model)!=report.get("n_model_generated_fish_boxes_score_ge_0_25"):
        raise ValueError("Model source row count mismatch")
    if len(assigned)!=report.get("n_model_bytetrack_observations"):
        raise ValueError("ByteTrack original row count mismatch")
    return model,assigned,report

def iou(a,b):
    x,y,w,h=a
    q,r,s,t=b
    area=max(0.,min(x+w,q+s)-max(x,q))*max(0.,min(y+h,r+t)-max(y,r))
    return area/(w*h+s*t-area) if (w*h+s*t-area)>0 else 0.

def hungarian_from_model(model,gate=.1,max_gap=5):
    import numpy as np
    from scipy.optimize import linear_sum_assignment
    if not 0<gate<=1 or max_gap<0:
        raise ValueError("Invalid alternate association thresholds")
    by_frame=[[] for _ in range(FRAME_COUNT)]
    for frame,box,score in model:
        by_frame[frame-1].append((box,score))
    active={}
    output=[]
    next_id=1
    for frame,obs in enumerate(by_frame,1):
        active={k:v for k,v in active.items() if frame-v[0]<=max_gap+1}
        ids=sorted(active)
        similarities=np.asarray([[iou(active[ident][1],box) for box,sc in obs]
                                 for ident in ids],dtype=float).reshape((len(ids),len(obs)))
        matches=[]
        if ids and obs:
            r,c=linear_sum_assignment(-similarities)
            matches=[(int(i),int(j)) for i,j in zip(r,c)
                     if similarities[i,j]>=gate]
        seen=set()
        for i,j in matches:
            track=ids[i]
            box,score=obs[j]
            active[track]=(frame,box)
            output.append((frame,track,box,score))
            seen.add(j)
        for j,(box,score) in enumerate(obs):
            if j not in seen:
                track=next_id
                next_id+=1
                active[track]=(frame,box)
                output.append((frame,track,box,score))
    return output

def density_bucket(n):
    return "0-25" if n<=25 else ("26-75" if n<=75 else "76+")

def analysis_of_model_detection_errors(gt,model,conf=.5,iou_threshold=.5,overlap_proxy=.1):
    """GT-box intersectivity proxy, not animal occlusion ground truth."""
    import numpy as np
    from scipy.optimize import linear_sum_assignment
    truth=[[] for _ in range(FRAME_COUNT)]
    detections=[[] for _ in range(FRAME_COUNT)]
    for frame,ident,box,_ in gt:truth[frame-1].append(box)
    for frame,box,score in model:
        if score>=conf:detections[frame-1].append(box)
    data={}
    overlaps={"GT_box_overlap_proxy":{"GT":0,"matched":0},
              "GT_box_no_overlap_proxy":{"GT":0,"matched":0}}
    for frame,(refs,proposals) in enumerate(zip(truth,detections),1):
        density=density_bucket(len(refs))
        d=data.setdefault(density,{"n_frames":0,"GT":0,"pred":0,"TP":0,"FP":0,"FN":0})
        d["n_frames"]+=1
        d["GT"]+=len(refs)
        d["pred"]+=len(proposals)
        pairs=[]
        if refs and proposals:
            sim=np.asarray([[iou(a,b) for b in proposals] for a in refs],dtype=float)
            ri,ci=linear_sum_assignment(-sim)
            pairs=[(int(i),int(j)) for i,j in zip(ri,ci)
                   if sim[i,j]>=iou_threshold]
        hits={i for i,j in pairs}
        d["TP"]+=len(hits)
        d["FP"]+=len(proposals)-len(hits)
        d["FN"]+=len(refs)-len(hits)
        for i,box in enumerate(refs):
            is_overlap=any(j!=i and iou(box,other)>=overlap_proxy
                           for j,other in enumerate(refs))
            key="GT_box_overlap_proxy" if is_overlap else "GT_box_no_overlap_proxy"
            overlaps[key]["GT"]+=1
            overlaps[key]["matched"]+=int(i in hits)
    if sum(z["GT"] for z in data.values())!=len(gt):
        raise RuntimeError("Fish source GT observation denominator changed")
    for z in data.values():
        z["precision"]=z["TP"]/(z["TP"]+z["FP"]) if z["TP"]+z["FP"] else None
        z["recall"]=z["TP"]/(z["TP"]+z["FN"]) if z["TP"]+z["FN"] else None
    for z in overlaps.values():
        z["detection_recall"]=z["matched"]/z["GT"] if z["GT"] else None
    return {"confidence_threshold":conf,"IoU_threshold":iou_threshold,
            "overlap_proxy_source_gt_IoU_threshold":overlap_proxy,
            "density_strata":data,"GT_2D_box_overlap_proxy":overlaps,
            "independently_adjudicated_fish_occlusion_labels":False}

def benchmark(original_archive,model_csv,byte_csv,report_json):
    gt=source_gt(original_archive)
    model,bytet,upstream=parse_source_predictions(model_csv,byte_csv,report_json)
    alt=hungarian_from_model(model)
    official_byte=metrics.evaluate(gt,bytet,FRAME_COUNT,"HHI_A_MODEL_BYTE")
    official_alt=metrics.evaluate(gt,alt,FRAME_COUNT,"HHI_A_MODEL_HUNGARIAN")
    source_held=upstream["official_trackeval_model_generated_tracks"]
    for name in ("HOTA","DetA","AssA","IDF1","MOTA","IDSW"):
        if abs(official_byte[name]-source_held[name])>1e-9:
            raise ValueError("Prior frozen ByteTrack official metrics not reproducible")
    return {
        "schema":"aqt_wave14h_model_source_tracker_comparison_v1",
        "original_source_sha256":metrics.digest(original_archive),
        "original_frozen_model_report_sha256":metrics.digest(report_json),
        "original_model_boxes_sha256":metrics.digest(model_csv),
        "original_bytetrack_rows_sha256":metrics.digest(byte_csv),
        "n_source_GT_boxes":len(gt),
        "n_original_model_generated_boxes":len(model),
        "n_bytetrack_assigned_boxes":len(bytet),
        "n_alternative_tracker_assigned_boxes":len(alt),
        "official_source":"JonathonLuiten/TrackEval",
        "official_source_commit":metrics.TRACK_EVAL_COMMIT,
        "external_video_sequence":"HHI_A",
        "model_generated_predictions_not_detection_oracle":True,
        "fish_identity_input_to_trackers":False,
        "ByteTrack_original_model_predictions":official_byte,
        "Hungarian_same_model_predictions":official_alt,
        "source_detection_failure_strata":analysis_of_model_detection_errors(gt,model),
        "Blinded_independent_source_GT_adjudication":False,
        "Original_HHI_download_peer_TLS_verified":False,
        "Experimentally_measured_fish_occlusion_truth":False,
        "real_physical_stereo_XYZ_certified":False,
        "animal_welfare_or_ACI_certified":False
    }

def main(argv=None):
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--original-mot-archive",type=Path,required=True)
    ap.add_argument("--model-csv",type=Path,required=True)
    ap.add_argument("--byte-csv",type=Path,required=True)
    ap.add_argument("--model-report",type=Path,required=True)
    ap.add_argument("--out",type=Path,required=True)
    args=ap.parse_args(argv)
    if args.out.exists():raise FileExistsError("No original source evidence overwrites")
    r=benchmark(args.original_mot_archive,args.model_csv,args.byte_csv,args.model_report)
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(r,sort_keys=True,indent=2,allow_nan=False)+"\n")
    print(json.dumps({"ByteTrack":r["ByteTrack_original_model_predictions"],
          "Hungarian":r["Hungarian_same_model_predictions"],
          "source_detection_failure_strata":r["source_detection_failure_strata"]},
          indent=2,sort_keys=True))
    return 0
if __name__=="__main__":
    raise SystemExit(main())

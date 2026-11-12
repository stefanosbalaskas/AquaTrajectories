#!/usr/bin/env python3
"""Reproduce Oxford published detector-vs-final-reviewed fish box agreement.

Not AquaTrajectories model accuracy; final annotations may be informed by the
source model, and source videos were not re-inferred here.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from functools import lru_cache
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re

SOURCE_COMMIT="0d57a17148f750ed7c327ba5d36ce587d3b7dcfe"
PRED_BLOB_SHA="831418e7780864d1caecb1469b31f3a908e2269d"
TRUTH_BLOB_SHA="8e2b2a30d87dae2f0624450cf7c8f51c4fbb0760"


def sha256(path):
    digest=hashlib.sha256()
    with Path(path).open("rb") as stream:
        for data in iter(lambda: stream.read(1<<20), b""):
            digest.update(data)
    return digest.hexdigest()


def parsed_annotations(path):
    p=Path(path)
    if not p.is_file() or p.stat().st_size>4_000_000:
        raise ValueError("Missing or oversized Oxford LISA annotation")
    obj=json.loads(p.read_text(encoding="utf-8-sig"))
    if not isinstance(obj,dict) or not isinstance(obj.get("files"),list):
        raise ValueError("Oxford LISA requires files list")
    lookup={}
    frame_ids=defaultdict(set)
    for item in obj["files"]:
        if not isinstance(item,dict) or not isinstance(item.get("src"),str):
            raise ValueError("Invalid original LISA frame")
        source=item["src"]
        m=re.fullmatch(r"(F\d+_T\d+)/f(\d+)\.jpg",source)
        if not m:
            raise ValueError("Unexpected Oxford frame path/name")
        sequence,frame=m.group(1),int(m.group(2))
        if source in lookup or frame in frame_ids[sequence]:
            raise ValueError("Duplicate Oxford source frame")
        frame_ids[sequence].add(frame)
        width=(item.get("fdata") or {}).get("width")
        height=(item.get("fdata") or {}).get("height")
        if not isinstance(width,int) or not isinstance(height,int) or width<1 or height<1:
            raise ValueError("Invalid source annotated image dimensions")
        regions=item.get("regions")
        meta=item.get("rdata")
        if not isinstance(regions,list) or not isinstance(meta,list) or len(regions)!=len(meta):
            raise ValueError("Malformed LISA fish annotation regions")
        boxes=[]
        for xywh in regions:
            if (not isinstance(xywh,list) or len(xywh)!=4 or
                any(not isinstance(v,(float,int)) or not math.isfinite(v) for v in xywh)):
                raise ValueError("Nonfinite Oxford fish bounding box")
            x,y,w,h=xywh
            if w<=0 or h<=0 or x<0 or y<0 or x+w>width+1e-4 or y+h>height+1e-4:
                raise ValueError("Out-of-frame Oxford fish bounding box")
            boxes.append(tuple(map(float,xywh)))
        lookup[source]={"sequence":sequence,"frame":frame,"boxes":boxes,
                        "image_width_px":width,"image_height_px":height}
    if not lookup:
        raise ValueError("Empty Oxford manual/prediction LISA source")
    return lookup


def iou(a,b):
    x1=max(a[0],b[0]);y1=max(a[1],b[1])
    x2=min(a[0]+a[2],b[0]+b[2]);y2=min(a[1]+a[3],b[1]+b[3])
    inter=max(0.0,x2-x1)*max(0.0,y2-y1)
    return inter/(a[2]*a[3]+b[2]*b[3]-inter)


def optimal_matches(gt,pred,threshold):
    if len(gt)>12 or len(pred)>12:
        raise ValueError("Oxford source validation supports at most 12 fish per frame")
    score=[[iou(g,p) for p in pred] for g in gt]
    @lru_cache(None)
    def step(i,mask):
        if i==len(gt):
            return (0,0.0,())
        best=step(i+1,mask)
        for j in range(len(pred)):
            if not mask>>j & 1 and score[i][j]>=threshold:
                n,q,pairs=step(i+1,mask | (1<<j))
                candidate=(n+1,q+score[i][j],((i,j,score[i][j]),)+pairs)
                if candidate[0:2]>best[0:2]:
                    best=candidate
        return best
    return step(0,0)[2]


def score_sources(truth,auto,threshold=.5):
    if not isinstance(threshold,(float,int)) or not 0<threshold<=1:
        raise ValueError("IoU threshold must be in (0,1]")
    if set(truth)!=set(auto):
        raise ValueError("Original auto/manual annotated-frame key sets differ")
    stats=defaultdict(lambda:{"frames":0,"reference_boxes":0,
                             "automatic_boxes":0,"tp":0,"fp":0,"fn":0,
                             "reference_empty_frames":0,
                             "false_positives_on_reference_empty_frames":0})
    agreement=[]
    for src in truth:
        g,p=truth[src],auto[src]
        if (g["image_width_px"],g["image_height_px"])!=(
                p["image_width_px"],p["image_height_px"]):
            raise ValueError("Human/pred image geometry mismatch")
        gt,pred=g["boxes"],p["boxes"]
        pairs=optimal_matches(gt,pred,float(threshold))
        tp=len(pairs);fp=len(pred)-tp;fn=len(gt)-tp
        group=stats[g["sequence"]]
        group["frames"]+=1;group["reference_boxes"]+=len(gt)
        group["automatic_boxes"]+=len(pred);group["tp"]+=tp
        group["fp"]+=fp;group["fn"]+=fn
        if not gt:
            group["reference_empty_frames"]+=1
            group["false_positives_on_reference_empty_frames"]+=len(pred)
        agreement.extend(z[2] for z in pairs)
    def enriched(d):
        d=dict(d)
        a,b,c=d["tp"],d["fp"],d["fn"]
        d["precision"]=a/(a+b) if a+b else None
        d["recall"]=a/(a+c) if a+c else None
        d["f1"]=2*a/(2*a+b+c) if 2*a+b+c else None
        return d
    keys=["frames","reference_boxes","automatic_boxes","tp","fp","fn",
          "reference_empty_frames","false_positives_on_reference_empty_frames"]
    total={k:sum(v[k] for v in stats.values()) for k in keys}
    return {
        "iou_threshold":float(threshold),
        "pooled":enriched(total),
        "by_recording":{k:enriched(v) for k,v in sorted(stats.items())},
        "mean_iou_among_matched_boxes":sum(agreement)/len(agreement) if agreement else None,
        "n_recordings":len(stats),
        "original_human_annotation_prediction_blind_certified":False,
        "prediction_source":"Oxford published EfficientDet automatic detections; no new model inference",
        "AquaTrajectories_detector_accuracy_measured":False,
        "track_identity_HOTA_or_IDF1_measured":False,
        "physical_xyz_accuracy_certified":False
    }


def main(argv=None):
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--auto",type=Path,required=True)
    ap.add_argument("--manual",type=Path,required=True)
    ap.add_argument("--threshold",type=float,default=.5)
    ap.add_argument("--out",type=Path,required=True)
    a=ap.parse_args(argv)
    auto=parsed_annotations(a.auto)
    manual=parsed_annotations(a.manual)
    report=score_sources(manual,auto,a.threshold)
    report.update({
        "schema_version":"1.0",
        "source_repository":"https://github.com/ox-vgg/fish-tank-obstacles",
        "source_commit":SOURCE_COMMIT,
        "auto_annotation_source_blob_sha":PRED_BLOB_SHA,
        "manual_annotation_source_blob_sha":TRUTH_BLOB_SHA,
        "auto_input_sha256":sha256(a.auto),
        "manual_input_sha256":sha256(a.manual),
        "publication":"Dutta et al. Royal Society Open Science (2025), doi:10.1098/rsos.242086",
        "source_license":"CC BY-NC 4.0",
    })
    a.out.parent.mkdir(parents=True,exist_ok=True)
    if a.out.exists():
        raise FileExistsError("Refuse overwrite source agreement report")
    a.out.write_text(json.dumps(report,sort_keys=True,indent=2)+"\n",
                     encoding="utf-8")
    print(json.dumps(report["pooled"],sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())

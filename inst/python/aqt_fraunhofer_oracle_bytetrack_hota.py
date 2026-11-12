#!/usr/bin/env python3
"""REAL external crowded-ricefish association benchmark with oracle GT boxes.

Runs real ByteTrack and independently implemented IoU/Hungarian on only the
original per-frame fish BOXES (never the GT ID labels), then computes official
TrackEval HOTA/IDF1/CLEAR against original persistent IDs.

Scores are **DETECTION ORACLE**: original source GT geometry is supplied
to trackers. NOT model-based detection/tracking accuracy or physical XYZ
accuracy. Original Fraunhofer host has currently failed TLS verification.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path, PurePosixPath
import tempfile
import zipfile

import aqt_official_fish_trackeval as official

def original_zip_gt(path,frame_count):
    p=Path(path)
    if not p.is_file() or p.stat().st_size>1_200_000_000:
        raise ValueError("Missing/oversized original fish source archive")
    with zipfile.ZipFile(p) as z:
        for m in z.infolist():
            member=PurePosixPath(m.filename)
            if (member.is_absolute() or ".." in member.parts or
                "\\" in m.filename or len(m.filename)>320):
                raise ValueError("Unsafe original annotation source path")
        gt=[i for i in z.infolist() if
            i.filename.lower().endswith("/gt/gt.txt") or
            i.filename.lower() in ("gt.txt","gt/gt.txt")]
        if len(gt)!=1 or gt[0].file_size>40000000:
            raise ValueError("Require one original MOT gt/gt.txt file")
        raw=z.read(gt[0]).decode("utf-8-sig")
        member_sha=hashlib.sha256(raw.encode("utf-8")).hexdigest()
        image_files=[i.filename for i in z.infolist() if
                     i.filename.lower().endswith((".jpg",".jpeg",".png"))]
    with tempfile.TemporaryDirectory() as td:
        path=Path(td)/"source_gt.txt"
        path.write_text(raw,encoding="utf-8")
        rows=official.mot_rows(path,frame_count,is_ground_truth=True)
    if len(rows)<10:
        raise ValueError("Not enough actual source fish observations")
    return rows,{"source_gt_sha256":member_sha,"gt_rows":len(rows),
                 "image_members":len(image_files),
                 "source_gt_member":gt[0].filename}

def group_frames(rows,n):
    frames=[[] for _ in range(n)]
    for frame,real_id,box,score in rows:
        # Discard source real_id for tracking; retain it ONLY in evaluation GT.
        frames[frame-1].append(box)
    return frames

def iou(a,b):
    ax,ay,aw,ah=a
    bx,by,bw,bh=b
    overlap=max(0,min(ax+aw,bx+bw)-max(ax,bx))*max(
        0,min(ay+ah,by+bh)-max(ay,by))
    union=aw*ah+bw*bh-overlap
    return overlap/union if union>0 else 0.

def simple_iou_hungarian(frames,gate=.1,max_missing=5):
    from scipy.optimize import linear_sum_assignment
    import numpy as np
    active={}
    output=[]
    next_id=1
    for frame_id,boxes in enumerate(frames,1):
        active={tid:v for tid,v in active.items()
                if frame_id-v[0]<=max_missing+1}
        ids=sorted(active)
        similarity=np.asarray([[iou(active[k][1],box) for box in boxes]
                                for k in ids],dtype=float).reshape(len(ids),len(boxes))
        pairs=[]
        if ids and boxes:
            rr,cc=linear_sum_assignment(-similarity)
            pairs=[(int(i),int(j)) for i,j in zip(rr,cc)
                   if similarity[i,j]>=gate and similarity[i,j]>0]
        matched=set()
        for i,j in pairs:
            tid=ids[i]
            active[tid]=(frame_id,boxes[j])
            output.append((frame_id,tid,boxes[j],1.))
            matched.add(j)
        for j,box in enumerate(boxes):
            if j not in matched:
                active[next_id]=(frame_id,box)
                output.append((frame_id,next_id,box,1.))
                next_id+=1
    return output

def run_bytetrack(frames, width,height):
    import numpy as np
    import supervision as sv
    tracker=sv.ByteTrack(track_activation_threshold=.25,
                         lost_track_buffer=30,
                         minimum_matching_threshold=.8,
                         frame_rate=30,minimum_consecutive_frames=1)
    output=[]
    for frame_id,boxes in enumerate(frames,1):
        arrays=np.asarray([[x,y,x+w,y+h] for x,y,w,h in boxes],
                          dtype=np.float32).reshape((-1,4))
        source=sv.Detections(
            xyxy=arrays,confidence=np.full(len(boxes),.99,dtype=np.float32),
            class_id=np.zeros(len(boxes),dtype=int))
        tracked=tracker.update_with_detections(source)
        ids=set()
        for i in range(len(tracked)):
            tid=int(tracked.tracker_id[i])+1
            if tid<1 or tid in ids:
                raise RuntimeError("ByteTrack returned duplicated/invalid fish identity")
            ids.add(tid)
            x1,y1,x2,y2=map(float,tracked.xyxy[i])
            if x1<0 or y1<0 or x2<=x1 or y2<=y1 or x2>width+1 or y2>height+1:
                raise ValueError("Tracker reconstructed source box outside image")
            output.append((frame_id,tid,(x1,y1,x2-x1,y2-y1),.99))
    return output

def benchmark(archive,sequence,frame_count,width,height,source_url):
    if sequence not in ("A","B") or not source_url.startswith("https://cvg.hhi.fraunhofer.de/FishTrackingData/"):
        raise ValueError("Only real HHI A/B original discovered archive URLs")
    gt,source=original_zip_gt(archive,frame_count)
    frames=group_frames(gt,frame_count)
    tracker_outputs={
        "ByteTrack_actual":run_bytetrack(frames,width,height),
        "IoU_Hungarian":simple_iou_hungarian(frames)}
    metrics={}
    for method,pred in tracker_outputs.items():
        report=official.evaluate(gt,pred,frame_count,f"HHI_{sequence}")
        report["prediction_source_kind"]="oracle_box_association"
        report["model_generated_boxes_used"]=False
        report["original_gt_ids_passed_to_tracker"]=False
        report["fish_biological_identity_independently_verified"]=False
        metrics[method]=report
    return {
        "sequence":sequence,"source":source_url,
        "archive_sha256":official.digest(archive),
        "source_original_tls_peer_verified":False,
        "published_source":source,
        "declared_original_frame_count":frame_count,
        "original_source_box_count":len(gt),
        "real_id_count":len({r[1] for r in gt}),
        "frame_declarations_completed_from_independent_source_images":False,
        "algorithm_output_rows":{k:len(v) for k,v in tracker_outputs.items()},
        "metrics":metrics,
        "official_trackeval_source_commit":official.TRACK_EVAL_COMMIT,
        "actual_real_fish_annotations_scored":True,
        "independent_model_based_detection_accuracy_certified":False,
        "tracking_identity_under_oracle_detections_only":True,
        "physical_xyz_accuracy_certified":False,
        "animal_welfare_validated":False,
        "source_label_blinded_review_certified":False
    }

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--archive",type=Path,required=True)
    p.add_argument("--sequence",choices=("A","B"),required=True)
    p.add_argument("--source-url",required=True)
    p.add_argument("--frames",type=int,default=101)
    p.add_argument("--width",type=int,default=2448)
    p.add_argument("--height",type=int,default=2048)
    p.add_argument("--out",type=Path,required=True)
    a=p.parse_args(argv)
    if a.out.exists():raise FileExistsError("Refuse overwrite original fish identity evidence")
    result=benchmark(a.archive,a.sequence,a.frames,a.width,a.height,
                     a.source_url)
    a.out.parent.mkdir(parents=True,exist_ok=True)
    a.out.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,indent=2,sort_keys=True))
    return 0
if __name__=="__main__":
    raise SystemExit(main())

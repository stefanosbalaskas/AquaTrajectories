#!/usr/bin/env python3
"""Official TrackEval HOTA/IDF1/CLEAR metrics for *declared* fish MOT tracks.

Scores an auditable frame-complete source-GT vs model-tracker box pair using
the unmodified JonathonLuiten/TrackEval metric classes. It is NOT a license
to call model-assisted annotations prediction-blind; no true hardware/XYZ
accuracy or animal-welfare conclusions are inferred.

Inputs: MOT text, 1-based frame,id,x,y,w,h[,score/class/etc], and a
fully reviewed CSV frame manifest. Tracker rows must be independent
model-produced track estimates, or explicitly labelled detection-oracle.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path

TRACK_EVAL_COMMIT="12c8791b303e0a0b50f753af204249e622d0281a"
MAX_ROWS=500000
MAX_FRAMES=100000

def digest(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda:f.read(1<<20),b""):
            h.update(chunk)
    return h.hexdigest()

def manifest(path):
    with Path(path).open(newline="",encoding="utf-8-sig") as f:
        reader=csv.DictReader(f)
        if reader.fieldnames not in (
            ["frame","review_status"],
            ["frame","review_status","reviewer_id"]):
            raise ValueError("Frames must declare frame,review_status[,reviewer_id]")
        sequence=[]
        for row in reader:
            try: frame=int(row["frame"])
            except (ValueError,TypeError) as e:
                raise ValueError("Invalid declared frame number") from e
            if (frame<1 or frame>MAX_FRAMES or
                row["review_status"]!="fully_annotated"):
                raise ValueError("Refuse incomplete/non-reviewed frame manifest")
            sequence.append(frame)
    if not sequence or sequence!=list(range(1,len(sequence)+1)):
        raise ValueError("Frame manifest must enumerate 1..N INCLUDING empty frames")
    return len(sequence)

def mot_rows(path,nframes,*,is_ground_truth=False):
    p=Path(path)
    if not p.is_file() or p.stat().st_size>90_000_000:
        raise ValueError("Missing or oversized original MOT annotation")
    out=[]
    keys=set()
    with p.open(newline="",encoding="utf-8-sig") as f:
        for lineno,row in enumerate(csv.reader(f),1):
            if not row:continue
            if len(row)<6:
                raise ValueError(f"MOT row {lineno} requires frame,id,x,y,w,h")
            try:
                frame=int(row[0]);identity=int(row[1])
                box=tuple(float(v) for v in row[2:6])
                score=float(row[6]) if len(row)>=7 else 1.0
            except (ValueError,TypeError) as e:
                raise ValueError(f"Invalid original MOT record at row {lineno}") from e
            if (frame<1 or frame>nframes or identity<1 or
                (frame,identity) in keys or
                not all(math.isfinite(x) for x in box) or
                box[0]<0 or box[1]<0 or box[2]<=0 or box[3]<=0 or
                not math.isfinite(score) or score<0 or score>1):
                raise ValueError(f"Invalid/duplicate MOT frame/track/box at row {lineno}")
            if is_ground_truth and score!=1:
                raise ValueError("GT confidence/ignore flags need explicit external review; refusing silent filtering")
            if len(out)>=MAX_ROWS:
                raise ValueError("Too many source fish observations")
            keys.add((frame,identity))
            out.append((frame,identity,box,score))
    return out

def similarities(a,b):
    import numpy as np
    scores=np.zeros((len(a),len(b)),dtype=float)
    for i,x in enumerate(a):
        ax,ay,aw,ah=x
        for j,y in enumerate(b):
            bx,by,bw,bh=y
            left=max(ax,bx);top=max(ay,by)
            right=min(ax+aw,bx+bw);bottom=min(ay+ah,by+bh)
            area=max(0.,right-left)*max(0.,bottom-top)
            union=aw*ah+bw*bh-area
            scores[i,j]=area/union if union>0 else 0.
    return scores

def trackeval_data(gt,pred,nframes,sequence):
    import numpy as np
    by_gt=[[] for _ in range(nframes)]
    by_pred=[[] for _ in range(nframes)]
    for f,idx,box,_ in gt:by_gt[f-1].append((idx,box))
    for f,idx,box,_ in pred:by_pred[f-1].append((idx,box))
    gt_idmap={k:i for i,k in enumerate(sorted({row[1] for row in gt}))}
    pred_idmap={k:i for i,k in enumerate(sorted({row[1] for row in pred}))}
    return {
        "seq":sequence,
        "num_timesteps":nframes,
        "num_gt_ids":len(gt_idmap),
        "num_tracker_ids":len(pred_idmap),
        "num_gt_dets":len(gt),
        "num_tracker_dets":len(pred),
        "gt_ids":[np.asarray([gt_idmap[x[0]] for x in frame],dtype=int)
                  for frame in by_gt],
        "tracker_ids":[np.asarray([pred_idmap[x[0]] for x in frame],dtype=int)
                       for frame in by_pred],
        "similarity_scores":[similarities([x[1] for x in a],
                                         [x[1] for x in b])
                             for a,b in zip(by_gt,by_pred)]
    }

def evaluate(gt,pred,frame_count,sequence):
    import numpy as np
    import trackeval
    data=trackeval_data(gt,pred,frame_count,sequence)
    hota=trackeval.metrics.HOTA().eval_sequence(data)
    identity=trackeval.metrics.Identity().eval_sequence(data)
    clear=trackeval.metrics.CLEAR().eval_sequence(data)
    def score(x):
        if not np.isfinite(x):raise RuntimeError("Nonfinite official fish tracking metric")
        return float(x)
    return {
        "official_metric_implementation":"JonathonLuiten/TrackEval",
        "official_metric_source_commit":TRACK_EVAL_COMMIT,
        "official_fish_benchmark_server_submission":False,
        "HOTA":score(np.mean(hota["HOTA"])),
        "DetA":score(np.mean(hota["DetA"])),
        "AssA":score(np.mean(hota["AssA"])),
        "LocA":score(np.mean(hota["LocA"])),
        "HOTA_at_alpha_0_50":score(hota["HOTA"][9]),
        "DetA_at_alpha_0_50":score(hota["DetA"][9]),
        "AssA_at_alpha_0_50":score(hota["AssA"][9]),
        "IDF1":score(identity["IDF1"]),
        "IDTP":int(identity["IDTP"]),
        "IDFP":int(identity["IDFP"]),
        "IDFN":int(identity["IDFN"]),
        "MOTA":score(clear["MOTA"]),
        "IDSW":int(clear["IDSW"]),
        "CLR_TP":int(clear["CLR_TP"]),
        "CLR_FP":int(clear["CLR_FP"]),
        "CLR_FN":int(clear["CLR_FN"]),
        "n_frames_including_declared_empty":frame_count,
        "n_gt_fish_observations":len(gt),
        "n_predicted_fish_observations":len(pred),
        "n_gt_unique_ids":data["num_gt_ids"],
        "n_prediction_unique_ids":data["num_tracker_ids"]
    }

def run(gt_path,track_path,frame_manifest,sequence,source_kind,
        reference_blindness):
    if not sequence or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" for c in sequence):
        raise ValueError("Unsafe or absent source sequence name")
    if source_kind not in ("model_tracker","oracle_box_association"):
        raise ValueError("Explicit prediction source kind required")
    if reference_blindness not in ("unverified","independent_blind_reviewed"):
        raise ValueError("Source truth-review status must be explicit")
    count=manifest(frame_manifest)
    gt=mot_rows(gt_path,count,is_ground_truth=True)
    pred=mot_rows(track_path,count,is_ground_truth=False)
    metrics=evaluate(gt,pred,count,sequence)
    matching_gt=([(a,b,c) for a,b,c,_ in gt] ==
                 [(a,b,c) for a,b,c,_ in pred])
    metrics.update({
        "source_sequence":sequence,
        "gt_mot_sha256":digest(gt_path),
        "predicted_mot_sha256":digest(track_path),
        "fully_reviewed_frame_manifest_sha256":digest(frame_manifest),
        "prediction_source_kind":source_kind,
        "human_reference_blindness_declaration":reference_blindness,
        "prediction_bytes_identical_to_gt_rows":matching_gt,
        "independent_prediction_accuracy_certified":False,
        "underwater_physical_xyz_accuracy_certified":False,
        "animal_welfare_or_stress_certified":False,
        "comparability_to_dataset_organizer_official_submission_verified":False,
        "warning":"Direct official TrackEval metric classes on declared fish MOT rows. "
                   "Independent biological identity annotations and original dataset "
                   "preprocessing must be externally verified. Perfect ground-truth "
                   "box association, if used, is oracle detection."
    })
    return metrics

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--gt",type=Path,required=True)
    p.add_argument("--pred",type=Path,required=True)
    p.add_argument("--frames",type=Path,required=True)
    p.add_argument("--sequence",required=True)
    p.add_argument("--source-kind",choices=("model_tracker","oracle_box_association"),
                   required=True)
    p.add_argument("--reference-blindness",choices=("unverified","independent_blind_reviewed"),
                   default="unverified")
    p.add_argument("--out",type=Path,required=True)
    args=p.parse_args(argv)
    if args.out.exists():raise FileExistsError("Refuse overwrite source identity evidence")
    result=run(args.gt,args.pred,args.frames,args.sequence,args.source_kind,
               args.reference_blindness)
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,indent=2,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""3D-ZeF original zebrafish 3D-position oracle association vs real source IDs.

Published source GT XYZ (cm) is supplied as PERFECT localizations, but original
GT fish ID is *not* supplied to the association algorithm. Score assigned IDs
using pinned unmodified TrackEval HOTA/Identity/CLEAR with explicitly declared
3D Euclidean similarity, not the organizer's official ZF3D submission protocol.

GT reconstructed XYZ is NOT separately surveyed physical underwater XYZ.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import zipfile

from aqt_3dzef_agreement import read_tracks
from aqt_3dzef_source_probe import inspect_labels_zip, file_sha256

SOURCE_URI="https://motchallenge.net/data/3DZeF20Lables.zip"
METRIC_COMMIT="12c8791b303e0a0b50f753af204249e622d0281a"

def oracle_positions(gt):
    by_frame=defaultdict(list)
    for frame,fish_id,xyz in gt:
        by_frame[frame].append(xyz)  # do not expose source true fish IDs
    return by_frame

def assign_3d_nearest(gt,gate_cm=5.0,max_gap_frames=5):
    import numpy as np
    from scipy.optimize import linear_sum_assignment
    if gate_cm<=0 or max_gap_frames<0:
        raise ValueError("Invalid 3D motion association gate")
    boxes=oracle_positions(gt)
    active={}
    result=[]
    next_id=1
    for frame in range(1,max(boxes)+1):
        observed=boxes.get(frame,[])
        active={key:v for key,v in active.items()
                if frame-v[0]<=max_gap_frames+1}
        ids=sorted(active)
        matrix=np.asarray([[math.dist(active[tid][1],xyz) for xyz in observed]
                           for tid in ids],dtype=float).reshape((len(ids),len(observed)))
        accepted=[]
        if ids and observed:
            rr,cc=linear_sum_assignment(matrix)
            accepted=[(int(a),int(b)) for a,b in zip(rr,cc)
                      if matrix[a,b]<=gate_cm]
        found=set()
        for row,col in accepted:
            tid=ids[row]
            active[tid]=(frame,observed[col])
            result.append((frame,tid,observed[col]))
            found.add(col)
        for j,xyz in enumerate(observed):
            if j not in found:
                active[next_id]=(frame,xyz)
                result.append((frame,next_id,xyz))
                next_id+=1
    return result

def evaluate_3d_label_id_agreement(gt,pred,sequence,zero_distance_cm=2.0):
    import numpy as np
    import trackeval
    if zero_distance_cm<=0 or not math.isfinite(zero_distance_cm):
        raise ValueError("Zero-distance similarity must have cm units and be positive")
    n=max(max(x[0] for x in gt),max(x[0] for x in pred))
    gt_f=[[] for _ in range(n)]
    pred_f=[[] for _ in range(n)]
    for frame,tid,xyz in gt:gt_f[frame-1].append((tid,xyz))
    for frame,tid,xyz in pred:pred_f[frame-1].append((tid,xyz))
    gt_ids={k:i for i,k in enumerate(sorted({z[1] for z in gt}))}
    pr_ids={k:i for i,k in enumerate(sorted({z[1] for z in pred}))}
    similarity=[]
    for a,b in zip(gt_f,pred_f):
        sim=np.asarray([[max(0.,1.-math.dist(x[1],y[1])/zero_distance_cm)
                         for y in b] for x in a],dtype=float).reshape((len(a),len(b)))
        similarity.append(sim)
    data={"seq":sequence,
          "num_timesteps":n,
          "num_gt_dets":len(gt),
          "num_tracker_dets":len(pred),
          "num_gt_ids":len(gt_ids),
          "num_tracker_ids":len(pr_ids),
          "gt_ids":[np.asarray([gt_ids[x[0]] for x in a],dtype=int) for a in gt_f],
          "tracker_ids":[np.asarray([pr_ids[x[0]] for x in a],dtype=int) for a in pred_f],
          "similarity_scores":similarity}
    h=trackeval.metrics.HOTA().eval_sequence(data)
    i=trackeval.metrics.Identity().eval_sequence(data)
    c=trackeval.metrics.CLEAR().eval_sequence(data)
    return {
        "HOTA":float(np.mean(h["HOTA"])),
        "DetA":float(np.mean(h["DetA"])),
        "AssA":float(np.mean(h["AssA"])),
        "HOTA_at_alpha_0_50":float(h["HOTA"][9]),
        "IDF1":float(i["IDF1"]),
        "IDSW":int(c["IDSW"]),
        "MOTA":float(c["MOTA"]),
        "gt_observations":len(gt),
        "algorithm_assigned_observations":len(pred),
        "gt_unique_fish_ids":len(gt_ids),
        "algorithm_unique_fish_ids":len(pr_ids),
        "frame_count_up_to_last_published_gt":n,
        "source_gt_frame_completeness_independently_certified":False,
        "similarity":"max(0, 1 - euclidean_distance_cm / zero_distance_cm)",
        "zero_distance_cm":float(zero_distance_cm),
        "distance_at_similarity_0_5_cm":float(zero_distance_cm)/2,
        "official_trackeval_metric_classes_run":True,
        "official_ZF3D_benchmark_submission_method_used":False,
        "oracle_ground_truth_xyz_input_used":True,
        "GT_fish_identity_supplied_to_associator":False,
        "independent_physical_underwater_xyz_accuracy_certified":False,
        "real_multi_camera_fish_detector_inference_performed":False,
        "fish_welfare_or_stress_certified":False
    }

def benchmark_archive(source,gate_cm=5.,distance_cm=2.):
    archive=Path(source)
    audit=inspect_labels_zip(archive)
    reports={}
    with zipfile.ZipFile(archive) as z:
        for item in audit["native_mot_3d_gt_inspections"]:
            path=item["path"]
            gt=read_tracks(z.read(path).decode("utf-8-sig"),path)
            pred=assign_3d_nearest(gt,gate_cm=gate_cm)
            scores=evaluate_3d_label_id_agreement(gt,pred,path,distance_cm)
            scores["source_gt_member_sha256"]=hashlib.sha256(z.read(path)).hexdigest()
            scores["source_GT_fish_ID_separated_from_association_algorithm"]=True
            reports[path]=scores
    return {
        "original_source":SOURCE_URI,
        "original_zip_sha256":file_sha256(archive),
        "n_real_source_sequences":len(reports),
        "n_source_gt_observations":sum(v["gt_observations"] for v in reports.values()),
        "tracker":"3D nearest-neighbour Hungarian with fixed gate",
        "association_distance_gate_cm":gate_cm,
        "official_metric_implementation":"JonathonLuiten/TrackEval",
        "official_metric_commit":METRIC_COMMIT,
        "results_by_sequence":reports,
        "uses_oracle_positions_not_real_model_detections":True,
        "official_ZF3D_scoring_or_submission_certified":False,
        "independently_surveyed_physical_xyz_certified":False,
        "actual_two_GoPro_synchronization_certified":False
    }

def main(argv=None):
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--original-labels-zip",type=Path,required=True)
    ap.add_argument("--gate-cm",type=float,default=5.)
    ap.add_argument("--zero-distance-cm",type=float,default=2.)
    ap.add_argument("--out",type=Path,required=True)
    a=ap.parse_args(argv)
    if a.out.exists():raise FileExistsError("Never overwrite scientific evidence")
    report=benchmark_archive(a.original_labels_zip,a.gate_cm,a.zero_distance_cm)
    a.out.parent.mkdir(parents=True,exist_ok=True)
    a.out.write_text(json.dumps(report,sort_keys=True,indent=2)+"\n")
    print(json.dumps(report,sort_keys=True,indent=2))
    return 0

if __name__=="__main__":
    raise SystemExit(main())

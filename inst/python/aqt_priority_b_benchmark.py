#!/usr/bin/env python3
"""Frozen same-recording fish tracker comparison; numerical scoring, NOT model training.

Requires original 1-based MOT boxes with human fish IDs, *every* fully
annotated frame, real frame times, externally generated tracker centres, and
an SHA-256 lock. HOTA/IDF1 use JonathonLuiten/TrackEval itself, not a proxy.
Centre-distance metrics are explicitly distinct from standard IoU HOTA.
No fabricated bbox is created from centre-only idtracker.ai exports.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
from collections import defaultdict
from pathlib import Path

import aqt_official_fish_trackeval as official

LOCK_SCHEMA = "AQT_PRIORITY_B_LOCK_V1"
PROTOCOL = "AQT_PRIORITY_B_COMPARISON_V1"
ALLOWED_METHODS = {"idtrackerai", "sleap", "yolo_bytetrack", "yolo_botsort",
                   "frozen_fish_bytetrack", "alternative_hungarian"}
ALLOWED_SCORE_SEMANTICS = {"detection_confidence", "identity_probability", "absent"}
MAX_POINTS = 500000


def _path(base, relative):
    if not isinstance(relative, str) or not relative or "\\" in relative:
        raise ValueError("Paths must be safe relative POSIX paths")
    p = Path(relative)
    if p.is_absolute() or ".." in p.parts:
        raise ValueError("No absolute or parent-relative paths in frozen inputs")
    out = (base / p).resolve()
    if not out.is_relative_to(base.resolve()):
        raise ValueError("Input path escapes frozen benchmark root")
    return out


def _unique_files(spec):
    paths = [spec["gt_mot"], spec["frame_manifest"], spec["timestamps"]]
    if "source_video" in spec:
        paths.append(spec["source_video"])
    names = set()
    for item in spec["methods"]:
        for name in ("centres_csv", "boxes_mot", "runtime_json", "training_provenance_json"):
            if item.get(name):
                paths.append(item[name])
        if item["method"] in names:
            raise ValueError("Duplicate tracker method")
        names.add(item["method"])
    if len(paths) != len(set(paths)):
        raise ValueError("Reference/prediction files must not alias")
    return paths


def validate_spec(base, spec):
    if not isinstance(spec, dict) or spec.get("protocol") != PROTOCOL:
        raise ValueError("Unknown priority-B benchmark protocol")
    if spec.get("source_split") != "test":
        raise ValueError("Only independent frozen TEST split can be scored")
    if spec.get("annotation_independence") not in ("unverified", "independent_blind_reviewed"):
        raise ValueError("Annotation independence must be explicitly declared")
    if spec.get("dataset_annotator_model_assistance") not in (True, False):
        raise ValueError("Source-label model assistance must be declared")
    methods = spec.get("methods")
    if not isinstance(methods, list) or not methods:
        raise ValueError("Must supply at least one actual method output")
    for item in methods:
        if not isinstance(item, dict) or item.get("method") not in ALLOWED_METHODS:
            raise ValueError("Unsupported tracking method")
        if item.get("prediction_source") != "model_generated":
            raise ValueError("No detection-oracle inputs for end-to-end method comparison")
        if item.get("test_video_used_for_training_or_selection") is not False:
            raise ValueError("Cannot benchmark a model tuned on test recording")
        if item.get("score_semantics") not in ALLOWED_SCORE_SEMANTICS:
            raise ValueError("Explicit scoring semantics required")
        if item.get("score_semantics") == "detection_confidence" and not item.get("centres_csv"):
            raise ValueError("Detection AP requires scored canonical centres")
        if not item.get("centres_csv") or not item.get("runtime_json"):
            raise ValueError("Each method requires genuine centre predictions and runtime provenance")
        if not item.get("training_provenance_json"):
            raise ValueError("Training/inference provenance must be supplied")
    if not isinstance(spec.get("centre_gate_px"), (int,float)) or \
            not 0 < spec["centre_gate_px"] < 500:
        raise ValueError("Finite prespecified centre gate (pixels) required")
    if not isinstance(spec.get("detection_confidence_threshold"),(int,float)) or \
            not 0 <= spec["detection_confidence_threshold"] <= 1:
        raise ValueError("Prespecified detection threshold required")
    if not isinstance(spec.get("iou_threshold"),(int,float)) or \
            not 0 < spec["iou_threshold"] <= 1:
        raise ValueError("Prespecified IoU threshold required")
    for p in _unique_files(spec):
        if not _path(base,p).is_file():
            raise ValueError("Missing source/baseline file: "+p)


def freeze(base, spec, path):
    validate_spec(base,spec)
    if path.exists():
        raise FileExistsError("Refusing overwrite of locked benchmark")
    hashes = {p:official.digest(_path(base,p)) for p in _unique_files(spec)}
    # Lock the protocol definition as well as all source and predictions.
    hashes["_protocol.json"] = hashlib.sha256(
        json.dumps(spec,sort_keys=True,separators=(",",":")).encode()).hexdigest()
    path.write_text(json.dumps({"schema":LOCK_SCHEMA,"files":hashes},
                               indent=2,sort_keys=True)+"\n",encoding="utf-8")


def check_lock(base,spec,lock):
    if lock.get("schema") != LOCK_SCHEMA:
        raise ValueError("Missing supported immutable SHA-256 lock")
    expected={p:official.digest(_path(base,p)) for p in _unique_files(spec)}
    expected["_protocol.json"]=hashlib.sha256(
        json.dumps(spec,sort_keys=True,separators=(",",":")).encode()).hexdigest()
    if lock.get("files") != expected:
        raise ValueError("Frozen benchmark content hash mismatch")
    return expected


def times_csv(path,n):
    with path.open(newline="",encoding="utf-8-sig") as f:
        rows=list(csv.DictReader(f))
    if len(rows)!=n or (rows and set(rows[0])!={"frame","time_s"}):
        raise ValueError("Frame times must be exactly frame,time_s for every evaluated frame")
    result=[]
    for i,row in enumerate(rows,1):
        try:
            fr=int(row["frame"]);t=float(row["time_s"])
        except (ValueError,TypeError) as e:
            raise ValueError("Invalid observed frame PTS") from e
        if fr!=i or not math.isfinite(t) or (result and t<=result[-1]):
            raise ValueError("Frame PTS must be strictly increasing in 1..N order")
        result.append(t)
    return result


def centres(path,n):
    with path.open(newline="",encoding="utf-8-sig") as f:
        r=csv.DictReader(f)
        if r.fieldnames!=["frame","track_id","x_px","y_px","score"]:
            raise ValueError("Centre output requires frame,track_id,x_px,y_px,score")
        result=[];seen=set()
        for row in r:
            try:
                frame=int(row["frame"]);ident=int(row["track_id"])
                x=float(row["x_px"]);y=float(row["y_px"])
                score=float(row["score"]) if row["score"]!="" else None
            except (ValueError,TypeError) as e:
                raise ValueError("Invalid track centre") from e
            if (not 1<=frame<=n or ident<1 or (frame,ident) in seen or
                not (math.isfinite(x) and math.isfinite(y)) or
                (score is not None and (not math.isfinite(score) or not 0<=score<=1))):
                raise ValueError("Duplicate, nonfinite or out-of-schedule track centre")
            seen.add((frame,ident))
            result.append((frame,ident,x,y,score))
            if len(result)>MAX_POINTS:
                raise ValueError("Too many centre observations")
    return result


def gt_centres(gt):
    return [(f,i,x+w/2,y+h/2,1.)
            for f,i,(x,y,w,h),_ in gt]


def assignment(ref,pred,gate,*,metric="centre"):
    """One-to-one matching, maximum TP cardinality, then minimum distance."""
    import numpy as np
    from scipy.optimize import linear_sum_assignment
    if not ref or not pred:
        return []
    a=np.asarray(ref,dtype=float)
    b=np.asarray(pred,dtype=float)
    if metric=="centre":
        distance=np.linalg.norm(a[:,None,:]-b[None,:,:],axis=2)
        eligible=distance<=gate
        quality=np.where(eligible,1-distance/(gate+1e-12)*0.1,-1000.)
    else:
        similarity=official.similarities(ref,pred)
        eligible=similarity>=gate
        quality=np.where(eligible,1+0.1*similarity,-1000.)
    # Explicit dummy columns allow unmatched truth rather than forcing bad IoU.
    n,m=quality.shape
    w=np.zeros((n,n+m),dtype=float)
    w[:,:m]=quality
    rr,cc=linear_sum_assignment(-w)
    return [(int(i),int(j)) for i,j in zip(rr,cc)
            if j<m and eligible[i,j]]


def matched_frames(gt,pred,n,gate,threshold=0):
    ga=defaultdict(list);pa=defaultdict(list)
    for row in gt:ga[row[0]].append(row)
    for row in pred:
        if row[4] is None or row[4]>=threshold:
            pa[row[0]].append(row)
    matches=[];tp=0;ng=0;npred=0
    for f in range(1,n+1):
        g=ga[f];p=pa[f]
        pairs=assignment([(z[2],z[3]) for z in g],
                         [(z[2],z[3]) for z in p],gate)
        matches.extend((g[i],p[j]) for i,j in pairs)
        tp+=len(pairs);ng+=len(g);npred+=len(p)
    return matches,{"TP":tp,"FP":npred-tp,"FN":ng-tp,
                    "F1":2*tp/(ng+npred) if ng+npred else 1.,
                    "precision":tp/npred if npred else (1. if ng==0 else 0.),
                    "recall":tp/ng if ng else 1.}


def confidence_ap(gt,pred,n,gate,*,bbox=False):
    """COCO-style 101-point interpolated AP at ONE declared match threshold.

    Detection scores must be independently generated detection confidences;
    identity probabilities are not valid scores for this calculation.
    """
    if any(z[-1] is None for z in pred):
        raise ValueError("AP requires complete detection confidence values")
    gt_by=defaultdict(list);pr_by=defaultdict(list)
    for z in gt:gt_by[z[0]].append(z)
    for z in pred:pr_by[z[0]].append(z)
    total=len(gt);out=[]
    for threshold in sorted({z[-1] for z in pred},reverse=True):
        tp=pcount=0
        for frame in range(1,n+1):
            a=gt_by[frame]
            b=[q for q in pr_by[frame] if q[-1]>=threshold]
            if bbox:
                pairs=assignment([q[2] for q in a],[q[2] for q in b],
                                 gate,metric="bbox")
            else:
                pairs=assignment([(q[2],q[3]) for q in a],
                                 [(q[2],q[3]) for q in b],gate)
            tp+=len(pairs);pcount+=len(b)
        out.append((tp/total if total else 1.,
                    tp/pcount if pcount else 1.))
    if total==0:
        return None  # AP cannot be defined over a zero-positive dataset.
    return sum(max((precision for recall,precision in out if recall>=k/100),
                   default=0.) for k in range(101))/101


def trackeval_centres(gt,pred,n,gate,sequence):
    """Run original TrackEval HOTA/Identity/CLEAR classes on explicit
    centre-distance similarity. NOT standard MOTChallenge box-IoU HOTA.
    Similarity = max(0,1-d/(2*gate)), hence alpha=.50 is d <= gate.
    """
    import numpy as np
    import trackeval
    x=defaultdict(list);y=defaultdict(list)
    for z in gt:x[z[0]].append(z)
    for z in pred:y[z[0]].append(z)
    gt_ids={v:i for i,v in enumerate(sorted({z[1] for z in gt}))}
    pr_ids={v:i for i,v in enumerate(sorted({z[1] for z in pred}))}
    a=[];b=[];s=[]
    for frame in range(1,n+1):
        ga=x[frame];pa=y[frame]
        a.append(np.asarray([gt_ids[q[1]] for q in ga],dtype=int))
        b.append(np.asarray([pr_ids[q[1]] for q in pa],dtype=int))
        dis=np.asarray([[math.hypot(g[2]-p[2],g[3]-p[3])
                         for p in pa] for g in ga],dtype=float).reshape((len(ga),len(pa)))
        s.append(np.maximum(0,1-dis/(2*gate)))
    d={"seq":sequence,"num_timesteps":n,"num_gt_ids":len(gt_ids),
       "num_tracker_ids":len(pr_ids),"num_gt_dets":len(gt),
       "num_tracker_dets":len(pred),"gt_ids":a,"tracker_ids":b,
       "similarity_scores":s}
    h=trackeval.metrics.HOTA().eval_sequence(d)
    ii=trackeval.metrics.Identity().eval_sequence(d)
    clear=trackeval.metrics.CLEAR().eval_sequence(d)
    return {
       "centre_HOTA":float(np.mean(h["HOTA"])),
       "centre_HOTA_at_distance_gate":float(h["HOTA"][9]),
       "centre_DetA":float(np.mean(h["DetA"])),
       "centre_AssA":float(np.mean(h["AssA"])),
       "centre_IDF1":float(ii["IDF1"]),
       "centre_IDTP":int(ii["IDTP"]),
       "centre_IDSW":int(clear["IDSW"]),
       "centre_MOTA":float(clear["MOTA"]),
       "similarity_definition":"max(0,1-distance_px/(2*centre_gate_px))",
       "official_metric_classes_executed":True,
       "standard_MOTChallenge_box_HOTA":False,
       "TrackEval_source_commit":official.TRACK_EVAL_COMMIT
    }


def tracking_fragmentation(matches, gt, n):
    """Missing matched episodes and changed predicted IDs, per GT individual.

    Each frame in the frozen full-manifest schedule is evaluated. A gap in GT
    annotation itself is NOT counted as tracker fragmentation.
    """
    by_gt=defaultdict(dict);matched=defaultdict(dict)
    for x in gt:by_gt[x[1]][x[0]]=True
    for truth,pred in matches:matched[truth[1]][truth[0]]=pred[1]
    episodes=changes=0
    fish=[]
    for ident,frames in sorted(by_gt.items()):
        active=False;last_id=None;frags=switches=0
        for frame in sorted(frames):
            selected=matched[ident].get(frame)
            if selected is None:
                active=False
            else:
                if not active and last_id is not None:frags+=1
                if last_id is not None and active and selected!=last_id:switches+=1
                active=True;last_id=selected
        episodes+=frags;changes+=switches
        fish.append({"gt_id":ident,"missed_match_fragments":frags,
                     "within_contiguous_matched_identity_changes":switches,
                     "n_annotated":len(frames),
                     "n_matched":len(matched[ident])})
    return {"identity_fragmentations":episodes,
            "adjacent_identity_label_changes":changes,
            "fish":fish}


def downstream_errors(matches,gt,times):
    """Strictly supported, timestamp-weighted movement errors. Never bridges
    missing detections or switches. GT is bounding-box centre, NOT anatomical
    fish centroid. Units remain px and px/s; never claim physical speed.
    """
    truth=defaultdict(dict);pred=defaultdict(dict)
    for q in gt:truth[q[1]][q[0]]=(q[2],q[3])
    for g,p in matches:pred[g[1]][g[0]]=(p[2],p[3],p[1])
    ref_dist=pred_dist=0.;gt_pairs=supported=0;speed_error=[];time_supported=0.
    for ident,positions in truth.items():
        for f in sorted(positions):
            if f+1 not in positions:continue
            dt=times[f]-times[f-1]
            if dt<=0:raise ValueError("Nonincreasing source PTS")
            gt_pairs+=1
            if f not in pred[ident] or f+1 not in pred[ident]:
                continue
            p1=pred[ident][f];p2=pred[ident][f+1]
            if p1[2]!=p2[2]:
                continue  # a false continuity must never be counted
            dist_truth=math.dist(positions[f],positions[f+1])
            dist_pred=math.dist(p1[:2],p2[:2])
            ref_dist+=dist_truth;pred_dist+=dist_pred
            speed_error.append(abs(dist_pred-dist_truth)/dt)
            supported+=1;time_supported+=dt
    matched_by_frame=defaultdict(list)
    for g,p in matches: matched_by_frame[g[0]].append((g,p))
    schooling=[]
    for frame, pairs in matched_by_frame.items():
        for i in range(len(pairs)):
            for j in range(i+1,len(pairs)):
                a,b=pairs[i],pairs[j]
                true_d=math.dist((a[0][2],a[0][3]),(b[0][2],b[0][3]))
                pred_d=math.dist((a[1][2],a[1][3]),(b[1][2],b[1][3]))
                schooling.append(pred_d-true_d)
    return {
      "units_distance":"image_px","units_speed":"image_px_per_second",
      "n_gt_consecutive_fish_pairs":gt_pairs,
      "n_supported_pairs_same_predicted_identity":supported,
      "supported_pair_fraction":supported/gt_pairs if gt_pairs else None,
      "supported_duration_s":time_supported,
      "gt_path_length_on_supported_px":ref_dist,
      "prediction_path_length_on_supported_px":pred_dist,
      "supported_path_length_error_px":pred_dist-ref_dist if supported else None,
      "mean_absolute_instantaneous_speed_error_px_s":
            sum(speed_error)/len(speed_error) if speed_error else None,
      "n_school_pair_distances_compared":len(schooling),
      "mean_absolute_school_pair_distance_error_px":
            sum(map(abs,schooling))/len(schooling) if schooling else None,
      "school_pair_distance_bias_px":
            sum(schooling)/len(schooling) if schooling else None,
      "missing_or_switched_frames_never_interpolated":True,
      "physical_speed_or_welfare_claim":False
    }


def read_runtime(path,expected_sha,n):
    record=json.loads(path.read_text(encoding="utf-8"))
    required=("wall_seconds","hardware_id","device","input_video_sha256",
              "n_input_frames","software_versions","phase")
    if any(k not in record for k in required) or \
            type(record["wall_seconds"]) not in (int,float) or \
            not 0<record["wall_seconds"]<1e8 or \
            record["n_input_frames"]!=n or \
            not isinstance(record["software_versions"],dict) or \
            not record["software_versions"]:
        raise ValueError("Missing measured runtime, frames, hardware or software provenance")
    if record["input_video_sha256"]!=expected_sha or \
            record["phase"]!="full_inference_and_tracking" or \
            not all(isinstance(record[k],str) and record[k]
                    for k in ("hardware_id","device")):
        raise ValueError("Runtime not from the frozen input or full pipeline")
    return record


def compare(base,spec,lock):
    validate_spec(base,spec); hashes=check_lock(base,spec,lock)
    n=official.manifest(_path(base,spec["frame_manifest"]))
    times=times_csv(_path(base,spec["timestamps"]),n)
    gt=official.mot_rows(_path(base,spec["gt_mot"]),n,is_ground_truth=True)
    gt_c=gt_centres(gt)
    expected_video_hash=hashes.get(spec.get("source_video",""))
    if not expected_video_hash:
        if not isinstance(spec.get("declared_source_video_sha256"),str) or \
                len(spec["declared_source_video_sha256"])!=64:
            raise ValueError("Frozen source video SHA-256 must be supplied")
        expected_video_hash=spec["declared_source_video_sha256"]
    results=[]
    for item in spec["methods"]:
        method=item["method"]
        pd=centres(_path(base,item["centres_csv"]),n)
        if not pd and not item.get("allow_zero_predictions",False):
            raise ValueError("Empty predictions require an explicit no-detection declaration")
        if item["score_semantics"]=="detection_confidence" and \
                any(v[-1] is None for v in pd):
            raise ValueError("Missing detector confidences")
        runtime=read_runtime(_path(base,item["runtime_json"]),expected_video_hash,n)
        provenance=json.loads(_path(base,item["training_provenance_json"]).read_text())
        if not isinstance(provenance,dict) or not provenance.get("model_or_config_sha256") or \
                provenance.get("test_split_used_for_training_or_tuning") is not False:
            raise ValueError("Missing frozen training provenance or leakage")
        matches, cm=matched_frames(gt_c,pd,n,spec["centre_gate_px"],
                 threshold=spec["detection_confidence_threshold"]
                 if item["score_semantics"]=="detection_confidence" else 0)
        centre_ap=(confidence_ap(gt_c,pd,n,spec["centre_gate_px"])
                   if item["score_semantics"]=="detection_confidence" else None)
        filtered=[p for p in pd if p[-1] is None or
          item["score_semantics"]!="detection_confidence" or
          p[-1]>=spec["detection_confidence_threshold"]]
        tracker=trackeval_centres(gt_c,filtered,n,spec["centre_gate_px"],
                                   spec["sequence"])
        fragmentation=tracking_fragmentation(matches,gt_c,n)
        behaviour=downstream_errors(matches,gt_c,times)
        box=None
        if item.get("boxes_mot"):
            pb=official.mot_rows(_path(base,item["boxes_mot"]),n)
            # An original idtracker centroid is NOT a fish body bounding box.
            if method=="idtrackerai" and item.get("box_origin")!="native_verified_segmentation":
                raise ValueError("No boxes synthesized from idtracker centres")
            for f,ident,(x,y,w,h),sc in pb:
                if any(k[0]==f and k[1]==ident and
                       math.dist((x+w/2,y+h/2),(k[2],k[3]))>2
                       for k in pd):
                    raise ValueError("Native box centre differs from canonical centre")
            boxmetric=official.evaluate(gt,pb,n,spec["sequence"])
            boxap=(confidence_ap(gt,pb,n,spec["iou_threshold"],bbox=True)
                   if item["score_semantics"]=="detection_confidence" else None)
            box={"official_iou_HOTA":boxmetric["HOTA"],
                 "official_iou_IDF1":boxmetric["IDF1"],
                 "official_iou_IDSW":boxmetric["IDSW"],
                 "box_AP50_101":boxap,
                 "same_body_extent_annotation_definition_required":True}
        results.append({
          "method":method,"prediction_source":"model_generated",
          "runtime":runtime,"n_raw_predictions":len(pd),
          "detection_at_frozen_threshold":cm,
          "centre_AP101":centre_ap,
          "centre_AP_score_semantics":item["score_semantics"],
          "tracking":tracker,"fragmentation":fragmentation,
          "behaviour_error":behaviour,"bbox_metrics":box,
          "source_files_sha256":{key:hashes[val] for key,val in item.items()
                                  if key in ("centres_csv","boxes_mot","runtime_json",
                                             "training_provenance_json") and val},
          "training_provenance":provenance,
          "independent_real_accuracy_certified":False,
        })
    runtime_comparable=(len({r["runtime"]["hardware_id"] for r in results})==1
           and len({r["runtime"]["device"] for r in results})==1
           and len({r["runtime"]["n_input_frames"] for r in results})==1
           and len({r["runtime"]["phase"] for r in results})==1)
    return {
        "protocol":PROTOCOL,"sequence":spec["sequence"],
        "n_fully_annotated_frames_including_empty":n,"n_gt_fish_boxes":len(gt),
        "annotation_independence":spec["annotation_independence"],
        "dataset_annotator_model_assistance":spec["dataset_annotator_model_assistance"],
        "same_original_video_sha256":expected_video_hash,
        "score_input_lock_sha256":hashlib.sha256(
            json.dumps(lock,sort_keys=True).encode()).hexdigest(),
        "prespecified_centre_gate_px":spec["centre_gate_px"],
        "prespecified_box_iou_threshold":spec["iou_threshold"],
        "prespecified_detection_confidence_threshold":spec["detection_confidence_threshold"],
        "runtime_same_hardware_and_device":runtime_comparable,
        "runtime_rank_valid":runtime_comparable,
        "results":results,
        "all_methods_scored_on_same_original_frames":True,
        "cross_method_AP_comparable_only_for_matching_detection_score_semantics":True,
        "different_body_extents_or_pose_boxes_may_invalidate_box_IoU_comparisons":True,
        "physical_units_validated":False,"welfare_or_stress_inferred":False,
        "test_video_used_for_method_selection":False,
        "reference_ground_truth_not_independently_audited_by_this_script":True
    }


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root",type=Path,required=True)
    parser.add_argument("--protocol-json",type=Path,required=True)
    parser.add_argument("--lock-json",type=Path,required=True)
    parser.add_argument("--output-json",type=Path)
    parser.add_argument("--freeze",action="store_true")
    a=parser.parse_args()
    root=a.root.resolve()
    spec=json.loads(a.protocol_json.read_text(encoding="utf-8"))
    if a.freeze:
        freeze(root,spec,a.lock_json)
        return
    if a.output_json is None or a.output_json.exists():
        raise ValueError("Evaluation output must be a new path")
    lock=json.loads(a.lock_json.read_text(encoding="utf-8"))
    result=compare(root,spec,lock)
    a.output_json.parent.mkdir(parents=True,exist_ok=True)
    a.output_json.write_text(json.dumps(result,indent=2,sort_keys=True,
                                       allow_nan=False)+"\n",encoding="utf-8")
    print(json.dumps({
      "sequence":result["sequence"],"frames":result["n_fully_annotated_frames_including_empty"],
      "methods":[r["method"] for r in result["results"]],
      "runtime_comparable":result["runtime_rank_valid"],
      "real_accuracy_certified":False},sort_keys=True))


if __name__=="__main__":
    main()

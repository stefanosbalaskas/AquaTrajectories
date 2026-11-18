#!/usr/bin/env python3
"""Wave 14K: REAL Fraunhofer fish-source tracking errors -> observable 2D behaviour.

Consumes only the original HHI video-A source GT and *original, frozen*
Oxford EfficientDet/ByteTrack predictions from successful Wave 14G.
Association alternative gets the EXACT same model boxes, never GT boxes.

This is a 101-JPEG SOURCE-FRAME-INDEX analysis; original exposure PTS is
NOT available. Valid units are pixels and pixels per adjacent source-frame
index, NOT cm/s, acceleration, school stress or animal welfare.

Source IDs have not been independently blinded-adjudicated, and the source
label archive originated from a server with incomplete HTTPS CA chain.
"""
from __future__ import annotations
import argparse
from collections import defaultdict
import json
import math
from pathlib import Path
import os
from itertools import combinations

from aqt_external_fish_comparative_robustness import (
    A_SHA, FRAME_COUNT, GT_SHA, hungarian_from_model, iou,
    parse_source_predictions, source_gt)
from aqt_official_fish_trackeval import digest

IOU_GATE=0.5
SCHEMA="AQT_REAL_FRAUNHOFER_BEHAVIOUR_MEASUREMENT_ERROR_V1"


def centre(box):
    x,y,w,h=box
    return x+w/2,y+h/2


def frame_matches(gt,pred,gate=IOU_GATE,nframes=FRAME_COUNT):
    """Unique maximum-cardinality IoU matches; GT IDs NEVER enter tracker."""
    import numpy as np
    from scipy.optimize import linear_sum_assignment
    if not 0<gate<=1 or nframes<1:
        raise ValueError("Require declared positive IoU gate/frame schedule")
    gt_by=defaultdict(list)
    pred_by=defaultdict(list)
    for row in gt:
        if not 1<=row[0]<=nframes:
            raise ValueError("Source GT frame outside exact reference schedule")
        gt_by[row[0]].append(row)
    for row in pred:
        if not 1<=row[0]<=nframes:
            raise ValueError("Source tracker frame outside exact reference schedule")
        pred_by[row[0]].append(row)
    pairs=[]
    for frame in range(1,nframes+1):
        g=gt_by[frame];p=pred_by[frame]
        if len({a[1] for a in g})!=len(g) or len({a[1] for a in p})!=len(p):
            raise ValueError("Duplicate source or estimated identity in one frame")
        if not g or not p:
            continue
        n,m=len(g),len(p)
        score=np.asarray([[iou(a[2],b[2]) for b in p] for a in g],dtype=float)
        eligible=score>=gate
        weights=np.zeros((n,m+n),dtype=float)
        # A feasible match scores > every dummy/unmatched assignment.
        # This maximizes TP count before maximizing summed IoU.
        weights[:,:m]=np.where(eligible,1.+0.1*score,-1000.)
        ri,ci=linear_sum_assignment(-weights)
        for a,b in zip(ri,ci):
            if b<m and eligible[a,b]:
                gtrow,prrow=g[int(a)],p[int(b)]
                pairs.append((frame,gtrow[1],prrow[1],
                              centre(gtrow[2]),centre(prrow[2]),
                              float(score[a,b])))
    return pairs


def finite_summary(values):
    return sum(values)/len(values) if values else None


def compute(gt,pred,*,gate=IOU_GATE,nframes=FRAME_COUNT):
    """Match on exactly the same original image frames, no interpolation."""
    matches=frame_matches(gt,pred,gate,nframes)
    gt_id_frames=defaultdict(dict)
    for frame,identity,box,_ in gt:
        gt_id_frames[identity][frame]=centre(box)
    assoc=defaultdict(dict)
    per_frame=defaultdict(list)
    for frame,gt_id,pr_id,gtxy,prxy,overlap in matches:
        assoc[gt_id][frame]=(pr_id,gtxy,prxy,overlap)
        per_frame[frame].append((gt_id,pr_id,gtxy,prxy,overlap))
    n_gt_intervals=n_supported=n_switched=n_missed=0
    source_common_length=pred_common_length=0.
    abs_step_errors=[]
    missed_match_reacquisition_episodes=0
    identity_changes_on_contiguous_matches=0
    source_per_animal=[]
    for gt_id,frames in sorted(gt_id_frames.items()):
        supported=total=switched=missing=0
        original_frames=sorted(frames)
        last_frame=None;last_match=None;gap=False
        reacquisitions=0
        for fr in original_frames:
            current=assoc[gt_id].get(fr)
            if last_frame is not None and fr!=last_frame+1:
                # A GT annotation gap is not itself tracker failure.
                last_match=None;gap=False
            if current is None:
                if last_match is not None:
                    gap=True
            else:
                after_unmatched_gap=gap
                if gap:
                    reacquisitions+=1
                    gap=False
                if (last_match is not None and not after_unmatched_gap and
                    current[0]!=last_match[0]):
                    identity_changes_on_contiguous_matches+=1
                last_match=current
            last_frame=fr
        missed_match_reacquisition_episodes+=reacquisitions
        for fr in original_frames:
            if fr+1 not in frames:
                continue
            total+=1;n_gt_intervals+=1
            left=assoc[gt_id].get(fr);right=assoc[gt_id].get(fr+1)
            if left is None or right is None:
                missing+=1;n_missed+=1
                continue
            if left[0]!=right[0]:
                switched+=1;n_switched+=1
                continue
            true_distance=math.dist(frames[fr],frames[fr+1])
            predicted_distance=math.dist(left[2],right[2])
            source_common_length+=true_distance
            pred_common_length+=predicted_distance
            abs_step_errors.append(abs(predicted_distance-true_distance))
            supported+=1;n_supported+=1
        source_per_animal.append({"source_GT_fish_id":gt_id,
            "n_adjacent_source_GT_pairs":total,
            "n_same_prediction_ID_supported_pairs":supported,
            "n_adjacent_pairs_with_missing_matching_observation":missing,
            "n_adjacent_pairs_with_changed_prediction_ID":switched,
            "support_fraction":supported/total if total else None})
    school_absolute_errors=[]
    school_signed_errors=[]
    for frame in range(1,nframes+1):
        for a,b in combinations(per_frame[frame],2):
            true_dist=math.dist(a[3],b[3])
            predicted_dist=math.dist(a[4],b[4])
            school_signed_errors.append(predicted_dist-true_dist)
            school_absolute_errors.append(abs(predicted_dist-true_dist))
    position_errors=[math.dist(pair[3],pair[4]) for pair in matches]
    if n_supported+n_switched+n_missed!=n_gt_intervals:
        raise RuntimeError("Truth interval denominator reconciliation failed")
    return {
      "n_source_frames":nframes,
      "n_GT_observations":len(gt),
      "n_predicted_observations":len(pred),
      "n_IoU_matched_fish_positions":len(matches),
      "source_GT_position_match_coverage":
          len(matches)/len(gt) if gt else None,
      "IoU_0_50_matched_centre_MAE_px":finite_summary(position_errors),
      "n_adjacent_original_source_GT_fish_intervals":n_gt_intervals,
      "n_same_predicted_identity_supported_adjacent_intervals":n_supported,
      "n_matched_adjacent_intervals_with_predicted_ID_change":n_switched,
      "n_adjacent_GT_intervals_without_both_matches":n_missed,
      "source_adjacent_interval_support_fraction":
          n_supported/n_gt_intervals if n_gt_intervals else None,
      "GT_common_support_path_length_px":source_common_length if n_supported else None,
      "prediction_common_support_path_length_px":
          pred_common_length if n_supported else None,
      "common_support_path_length_bias_px":
          pred_common_length-source_common_length if n_supported else None,
      "common_support_mean_abs_adjacent_displacement_error_px_per_frame_index":
          finite_summary(abs_step_errors),
      "n_matched_simultaneous_school_pair_distances":len(school_absolute_errors),
      "school_pair_distance_mean_abs_error_px":
          finite_summary(school_absolute_errors),
      "school_pair_distance_signed_bias_px":
          finite_summary(school_signed_errors),
      "missed_detections_followed_by_reacquisition_episodes":
          missed_match_reacquisition_episodes,
      "identity_changes_on_contiguous_successful_GT_matches":
          identity_changes_on_contiguous_matches,
      "per_fish_reference_support":source_per_animal,
      "no_unobserved_segment_interpolation":True,
      "source_GT_frame_discontinuities_not_tracker_fragmentation":True,
      "observable_units":"image_px_and_per_adjacent_source_frame_index",
      "physical_time_s_or_physical_speed_computed":False,
      "stress_welfare_or_causality_inferred":False,
      "error_means_conditioned_on_scarce_successful_matches":True,
      "single_tank_replicate_causal_inference_qualified":False,
      "reference_IDs_independently_blind_adjudicated":False
    }


def run(original_archive,model_csv,byte_csv,model_report):
    gt=source_gt(original_archive)
    model,byte,upstream=parse_source_predictions(model_csv,byte_csv,model_report)
    alt=hungarian_from_model(model)
    byte_result=compute(gt,byte)
    alternate_result=compute(gt,alt)
    if byte_result["n_GT_observations"]!=9214 or \
       alternate_result["n_GT_observations"]!=9214:
        raise RuntimeError("Original source truth denominator mismatch")
    if byte_result["n_predicted_observations"]!=len(byte) or \
       alternate_result["n_predicted_observations"]!=len(alt):
        raise RuntimeError("Tracker source support changed")
    return {
      "schema":SCHEMA,
      "source_kind":"original_real_fraunhofer_ricefish_A",
      "source_original_full_JPEG_source_byte_truth":True,
      "n_original_source_JPEG_frames":FRAME_COUNT,
      "original_source_absolute_frames":[43450,43550],
      "source_video_PTS_seconds_independently_known":False,
      "original_HHI_source_archive_SHA256":digest(original_archive),
      "original_HHI_GT_SHA256":GT_SHA,
      "original_Wave14G_model_predictions_SHA256":digest(model_csv),
      "original_Wave14G_model_report_SHA256":digest(model_report),
      "original_Wave14G_ByteTrack_predictions_SHA256":digest(byte_csv),
      "source_original_model_generated_predictions_not_oracle":True,
      "reference_GT_fish_identity_input_to_trackers":False,
      "reused_frozen_prediction_Source_TF_EfficientDet_not_YOLO":True,
      "model_finetuned_to_HHI_ricefish":False,
      "source_reference_annotation_prediction_blind_reviewed":False,
      "IoU_association_threshold":IOU_GATE,
      "ByteTrack_real_source_model":byte_result,
      "Hungarian_same_real_model":alternate_result,
      "note":"Real source-label measurement agreement, conditional on extremely "
             "sparse IoU-valid predicted fish. No real source PTS => no "
             "speed/acceleration, cm, stress or welfare estimates."
    }


def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source-archive",type=Path,required=True)
    p.add_argument("--model-csv",type=Path,required=True)
    p.add_argument("--bytetrack-csv",type=Path,required=True)
    p.add_argument("--model-report",type=Path,required=True)
    p.add_argument("--out",type=Path,required=True)
    a=p.parse_args(argv)
    if a.out.exists():raise FileExistsError("Refuse overwriting original scientific evidence")
    result=run(a.source_archive,a.model_csv,a.bytetrack_csv,a.model_report)
    a.out.parent.mkdir(parents=True,exist_ok=True)
    a.out.write_text(json.dumps(result,indent=2,sort_keys=True,allow_nan=False)+"\n")
    summary={key:{"n_gt_intervals":v["n_adjacent_original_source_GT_fish_intervals"],
                  "supported_intervals":v["n_same_predicted_identity_supported_adjacent_intervals"],
                  "support_fraction":v["source_adjacent_interval_support_fraction"],
                  "n_matched_positions":v["n_IoU_matched_fish_positions"],
                  "n_school_pairs":v["n_matched_simultaneous_school_pair_distances"]}
             for key,v in result.items()
             if key in ("ByteTrack_real_source_model","Hungarian_same_real_model")}
    print(json.dumps(summary,indent=2,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())

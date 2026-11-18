#!/usr/bin/env python3
"""Produce a publication-table *candidate* from a locked Priority B score report.

The input must originate from aqt_priority_b_benchmark.compare(). This module
does not claim independent empirical accuracy, review model training, or make
real fish/synthetic predictions interchangeable.
"""
from __future__ import annotations
import argparse
import csv
import json
import math
from pathlib import Path

REQUIRED=("protocol","source_kind","sequence","results",
          "n_fully_annotated_frames_including_empty",
          "n_gt_fish_boxes","same_original_video_sha256")
HEADERS=("source_kind","recording","method","reference_truth_independence",
   "fish_gt_boxes","evaluated_frames","centre_TP","centre_FP","centre_FN",
   "centre_F1","centre_AP101_optional","AP_score_semantics",
   "centre_HOTA_nonstandard_similarity","centre_IDF1","centre_IDSW",
   "native_body_box_HOTA_optional","native_box_AP50_optional",
   "matched_fish_identity_fragmentations","same_ID_contiguous_label_changes",
   "consecutive_GT_intervals","supported_same_ID_intervals",
   "support_fraction","supported_speed_MAE_px_s",
   "matched_school_pair_distance_MAE_px","measured_runtime_wall_s",
   "same_hardware_device","all_frame_processing_verified",
   "runtime_ranking_valid","annotation_independence_certified",
   "independent_real_accuracy_certified",
   "notes")

def row(report,record):
    t=record["tracking"];det=record["detection_at_frozen_threshold"]
    frag=record["fragmentation"];down=record["behaviour_error"]
    box=record["bbox_metrics"];rt=record["runtime"]
    source=report["source_kind"]
    if source not in ("real_recording","synthetic_known_truth"):
        raise ValueError("Unrecognized source video provenance; refuse publication table")
    if source=="synthetic_known_truth" and report.get("original_real_video_bytes_present_and_hashed"):
        raise ValueError("Synthetic report conflicts with declared original video")
    note="SYNTHETIC_ONLY_NOT_REAL_MODEL_BENCHMARK" if source=="synthetic_known_truth" else (
       "Real original video bytes declared; independent source truth and model"
       " inference chain still require external verification")
    if record["method"]=="idtrackerai":
        note+="; TRANSductive_unlabelled_test_video_ID_learning"
    if record["centre_AP_score_semantics"]=="pose_instance_score":
        note+="; SLEAP_POSE_INSTANCE_SCORES_NOT_YOLO_DETECTOR_CONFIDENCE"
    if box is None:
        note+="; NATIVE_BODY_BOX_AP_NOT_AVAILABLE"
    return {
       "source_kind":source,"recording":report["sequence"],
       "method":record["method"],
       "reference_truth_independence":report["annotation_independence"],
       "fish_gt_boxes":report["n_gt_fish_boxes"],
       "evaluated_frames":report["n_fully_annotated_frames_including_empty"],
       "centre_TP":det["TP"],"centre_FP":det["FP"],
       "centre_FN":det["FN"],"centre_F1":det["F1"],
       "centre_AP101_optional":record["centre_AP101"],
       "AP_score_semantics":record["centre_AP_score_semantics"],
       "centre_HOTA_nonstandard_similarity":t["centre_HOTA"],
       "centre_IDF1":t["centre_IDF1"],
       "centre_IDSW":t["centre_IDSW"],
       "native_body_box_HOTA_optional":box["official_iou_HOTA"] if box else None,
       "native_box_AP50_optional":box["box_AP50_101"] if box else None,
       "matched_fish_identity_fragmentations":frag["identity_fragmentations"],
       "same_ID_contiguous_label_changes":frag["adjacent_identity_label_changes"],
       "consecutive_GT_intervals":down["n_gt_consecutive_fish_pairs"],
       "supported_same_ID_intervals":down["n_supported_pairs_same_predicted_identity"],
       "support_fraction":down["supported_pair_fraction"],
       "supported_speed_MAE_px_s":down["mean_absolute_instantaneous_speed_error_px_s"],
       "matched_school_pair_distance_MAE_px":down["mean_absolute_school_pair_distance_error_px"],
       "measured_runtime_wall_s":rt["wall_seconds"],
       "same_hardware_device":report["runtime_same_hardware_and_device"],
       "all_frame_processing_verified":rt.get("n_input_frames_actually_decoded_verified",False),
       "runtime_ranking_valid":report["runtime_rank_valid"],
       "annotation_independence_certified":report["annotation_independence"]=="independent_blind_reviewed"
                                          and report["source_kind"]=="real_recording",
       "independent_real_accuracy_certified":False,
       "notes":note
    }

def write_table(report_path,out):
    if out.exists():raise FileExistsError("Refuse overwriting earlier benchmark evidence")
    report=json.loads(report_path.read_text(encoding="utf-8"))
    if any(x not in report for x in REQUIRED) or \
       report["protocol"]!="AQT_PRIORITY_B_COMPARISON_V1" or \
       not report["results"]:
        raise ValueError("Unqualified or incomplete Priority B benchmark report")
    records=[row(report,r) for r in report["results"]]
    if len({v["method"] for v in records})!=len(records):
        raise ValueError("Duplicated model in supposedly comparable results")
    out.parent.mkdir(parents=True,exist_ok=True)
    with out.open("w",newline="",encoding="utf-8") as f:
        writer=csv.DictWriter(f,fieldnames=HEADERS)
        writer.writeheader()
        writer.writerows(records)
    return {"rows":len(records),"source_kind":report["source_kind"],
            "table":str(out),
            "independent_real_accuracy_certified":False}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--report",type=Path,required=True)
    p.add_argument("--out",type=Path,required=True)
    a=p.parse_args()
    print(json.dumps(write_table(a.report,a.out),indent=2,sort_keys=True))

if __name__=="__main__":main()

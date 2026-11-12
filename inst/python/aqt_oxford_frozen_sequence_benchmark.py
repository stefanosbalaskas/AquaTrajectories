#!/usr/bin/env python3
"""Full original Oxford fish video -> frozen EfficientDet -> real ByteTrack.

Uses independent source files, real frame timestamps, source-reviewed Oxford
fish boxes. Reviewed labels MAY have been seeded by original model detections,
so output is SOURCE-REVIEW AGREEMENT, not prediction-blind scientific accuracy.
No independent multi-fish ID labels, no HOTA, no surveyed physical XYZ.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path

from aqt_oxford_frozen_model_smoke import check_frozen_model, input_array, digest_file
from aqt_oxford_detection_audit import (parsed_annotations, optimal_matches,
                                         iou, TRUTH_BLOB_SHA, SOURCE_COMMIT)
from aqt_oxford_real_bytetrack import track_detections

SEQUENCE="F30_T15"
THRESHOLDS=(0.5,0.7)
TRACKER_CONF=.25


def read_video_manifest(path, sequence=SEQUENCE):
    with Path(path).open(newline="",encoding="utf-8-sig") as f:
        reader=csv.DictReader(f)
        expected=["session_id","camera_id","frame_id","time_s","width_px","height_px"]
        if reader.fieldnames!=expected:
            raise ValueError("Video source frame manifest schema mismatch")
        rows=list(reader)
    if not rows:
        raise ValueError("Empty original video frame manifest")
    times=[]
    for i,row in enumerate(rows):
        if row["session_id"]!="oxford_eval" or row["camera_id"]!="oxford_single_video":
            raise ValueError("Video clock provenance scope mismatch")
        if row["frame_id"]!=str(i):
            raise ValueError("Noncontiguous or permuted video frame IDs")
        if row["width_px"]!="1920" or row["height_px"]!="1080":
            raise ValueError("Original source clip pixel dimensions mismatch")
        try: t=float(row["time_s"])
        except ValueError as e: raise ValueError("Invalid source PTS") from e
        if not math.isfinite(t) or (i==0 and t!=0) or (times and t<=times[-1]):
            raise ValueError("Invalid/nonmonotonic source video-local PTS")
        times.append(t)
    return times


def validate_frames(images, clock, reviewed, sequence=SEQUENCE):
    files=sorted(Path(images).glob("f*.jpg"))
    if len(files)!=len(clock):
        raise ValueError("Original decoded image count differs from source PTS")
    expected={f"{sequence}/f{i:05d}.jpg" for i in range(len(clock))}
    actual={f"{sequence}/{x.name}" for x in files}
    if actual!=expected:
        raise ValueError("Source decoded image names do not map to original reviewed frames")
    reviewed_sequence={k:v for k,v in reviewed.items() if k.startswith(sequence+"/")}
    if set(reviewed_sequence)!=expected:
        raise ValueError("Original reviewed image frame coverage differs from decoded video")
    if any(v["unsupported_annotation_regions"] for v in reviewed_sequence.values()):
        raise ValueError("Selected original video has unadjudicated box annotations")
    return files,reviewed_sequence


def source_tensor_boxes(array,width,height,min_conf=TRACKER_CONF):
    """Oxford source detect-efficientdet.py: [batch,y0,x0,y1,x1,score,class].

    These coordinates are output-source pixel geometry. Never treat class
    as a verified taxonomic fish species, and never silently clip invalid
    detections or change a score threshold after reviewing test labels.
    """
    import numpy as np
    a=np.asarray(array)
    if a.ndim!=3 or a.shape[0]!=1 or a.shape[-1]!=7:
        raise ValueError("Unrecognized Oxford original EfficientDet output schema")
    boxes=[]
    invalid=[]
    for row in a[0]:
        values=list(map(float,row))
        if not all(math.isfinite(z) for z in values):
            raise ValueError("Nonfinite original model detection tensor")
        _,y0,x0,y1,x1,score,category=values
        if score<min_conf:
            continue
        if score>1 or score<0:
            raise ValueError("Impossible fish-detector confidence")
        if not (0<=x0<x1<=width+1e-5 and 0<=y0<y1<=height+1e-5):
            invalid.append(dict(score=score,box=[x0,y0,x1,y1]))
            continue
        boxes.append({"xywh":[x0,y0,x1-x0,y1-y0],
                      "score":score,
                      "model_class_index":category})
    return boxes,invalid


def compare_boxes(source,reference,threshold):
    """One-to-one IoU >= 0.50, maximal cardinality; all empty frames included."""
    n_gt=n_pred=tp=bad=empty=0
    rows=[]
    for frame in sorted(reference):
        gt=reference[frame]["boxes"]
        detections=source[frame]
        pred=[d["xywh"] for d in detections["boxes"] if d["score"]>=threshold]
        invalid=sum(d["score"]>=threshold for d in detections["invalid"])
        pairs=optimal_matches(gt,pred,.5)
        tp+=len(pairs);n_gt+=len(gt);n_pred+=len(pred)+invalid;bad+=invalid
        if not gt: empty+=1
        rows.append(dict(frame_src=frame,truth=len(gt),
                         model_predictions=len(pred)+invalid,
                         valid_predictions=len(pred),invalid_predictions=invalid,
                         matched=len(pairs),
                         false_positives=len(pred)+invalid-len(pairs),
                         false_negatives=len(gt)-len(pairs)))
    fp=n_pred-tp;fn=n_gt-tp
    return dict(n_frames=len(reference),n_reference_boxes=n_gt,
                n_inferred_model_detections=n_pred,
                n_invalid_high_confidence_detections=bad,
                n_reference_empty_frames=empty,
                true_positives=tp,false_positives=fp,false_negatives=fn,
                precision=tp/(tp+fp) if tp+fp else None,
                recall=tp/(tp+fn) if tp+fn else None,
                F1=2*tp/(2*tp+fp+fn) if 2*tp+fp+fn else None,
                detector_confidence_threshold=threshold,
                localization_IoU_threshold=.5),rows


def write_csv(path,records,columns):
    with Path(path).open("w",newline="",encoding="utf-8") as f:
        writer=csv.DictWriter(f,fieldnames=columns)
        writer.writeheader()
        writer.writerows(records)


def run(model_dir,images,manifest,original_review,video_path,out_dir):
    import numpy as np
    import tensorflow as tf
    original=Path(original_review)
    review_sha=hashlib.sha1(
        b"blob "+str(original.stat().st_size).encode()+b"\0"+
        original.read_bytes()).hexdigest()
    if review_sha!=TRUTH_BLOB_SHA:
        raise ValueError("Original reviewed Oxford GT Git object mismatch")
    weights=check_frozen_model(model_dir)
    times=read_video_manifest(manifest)
    review=parsed_annotations(original_review)
    files,truth=validate_frames(images,times,review)
    if not files:
        raise ValueError("No real fish video frames")
    if out_dir.exists():
        raise FileExistsError("Refuse nonempty or existing benchmark output")
    model=tf.saved_model.load(str(model_dir))
    signature=model.signatures.get("serving_default")
    if signature is None:
        raise RuntimeError("Original fish model missing serving_default")
    _,specs=signature.structured_input_signature
    if len(specs)!=1: raise RuntimeError("Unknown fish detector input schema")
    key,spec=next(iter(specs.items()))
    outputs_by_frame={}
    predicted_csv=[]
    by_track={}
    transformations=set()
    for i,path in enumerate(files):
        tensor,transform=input_array(path,spec)
        transformations.add(transform["input_transform"])
        output=signature(**{key:tensor})
        if set(output)!={"detections:0"}:
            raise RuntimeError("Original fish detector output contract changed")
        box,invalid=source_tensor_boxes(output["detections:0"].numpy(),1920,1080)
        src=f"{SEQUENCE}/{path.name}"
        outputs_by_frame[src]={"boxes":box,"invalid":invalid}
        by_track[src]={"sequence":SEQUENCE,"frame":i,
                       "boxes":[tuple(d["xywh"]) for d in box],
                       "scores":[d["score"] for d in box]}
        for d in box:
            x,y,w,h=d["xywh"]
            predicted_csv.append(dict(recording=SEQUENCE,frame_id=i,
                time_s=times[i],xmin_px=x,ymin_px=y,
                width_px=w,height_px=h,confidence=d["score"],
                class_index_unverified=d["model_class_index"]))
    summary_by_threshold={}
    for threshold in THRESHOLDS:
        score,frame_rows=compare_boxes(outputs_by_frame,truth,threshold)
        summary_by_threshold[str(threshold)]=score
    tracks,tracker_info=track_detections(by_track)
    if len(tracks)>len(predicted_csv):
        raise RuntimeError("Tracker cannot produce more boxes than model source")
    tracker_rows=[{**row,"time_s":times[row["frame_id"]]} for row in tracks]
    out_dir.mkdir(parents=True)
    detector_path=out_dir/"model_generated_detections.csv"
    track_path=out_dir/"model_generated_bytetrack.csv"
    write_csv(detector_path,predicted_csv,
        ["recording","frame_id","time_s","xmin_px","ymin_px",
         "width_px","height_px","confidence","class_index_unverified"])
    write_csv(track_path,tracker_rows,
        ["recording","frame_id","frame_mot","track_id","xmin_px","ymin_px",
         "width_px","height_px","confidence","class_id","time_s"])
    info={
        "schema_version":"1.0",
        "source":"Oxford original frozen EfficientDet-D2 v2 model on original GoPro-origin fish MP4",
        "source_repo_commit":SOURCE_COMMIT,
        "real_source_video_sha256":digest_file(video_path),
        "reviewed_source_git_blob_sha1":review_sha,
        "original_frame_pts_manifest_sha256":digest_file(manifest),
        "source_image_count":len(files),
        "source_video_clock":"decoded_MP4_PTS_local_not_exposure_UTC",
        "tf_version":tf.__version__,
        "model_components":weights,
        "model_signature_input":key,
        "input_transforms":sorted(transformations),
        "scoring":summary_by_threshold,
        "source_video_model_forward_pass_count":len(files),
        "newly_inferred_detector_rows_at_min_confidence":len(predicted_csv),
        "newly_generated_bytetrack_rows":len(tracker_rows),
        "tracker_runtime":"supervision==0.26.1",
        "tracker_diagnostics":tracker_info,
        "files_sha256":{p.name:digest_file(p)
                        for p in (detector_path,track_path)},
        "all_video_frames_included":True,
        "original_source_labels_prediction_blind_externally_verified":False,
        "original_weights_training_cohort_disjoint_verified":False,
        "independent_tracking_identity_gt_available":False,
        "official_HOTA_IDF1_measured":False,
        "independent_3D_physical_ground_truth":False,
        "biological_stress_or_welfare_validated":False,
        "notes":"Descriptive published reviewed-label agreement for newly "
                "generated fish detections on one Oxford clip. Not "
                "independently certified fish detection accuracy."
    }
    (out_dir/"summary.json").write_text(
        json.dumps(info,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    return info


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir",type=Path,required=True)
    parser.add_argument("--images",type=Path,required=True)
    parser.add_argument("--frame-manifest",type=Path,required=True)
    parser.add_argument("--reviewed-lisa",type=Path,required=True)
    parser.add_argument("--original-video",type=Path,required=True)
    parser.add_argument("--output-dir",type=Path,required=True)
    a=parser.parse_args(argv)
    report=run(a.model_dir,a.images,a.frame_manifest,a.reviewed_lisa,
               a.original_video,a.output_dir)
    print(json.dumps({k:report[k] for k in
        ("source_video_model_forward_pass_count",
         "newly_inferred_detector_rows_at_min_confidence",
         "newly_generated_bytetrack_rows","scoring")},indent=2))
    return 0


if __name__=="__main__":
    raise SystemExit(main())

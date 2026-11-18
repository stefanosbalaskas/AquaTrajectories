#!/usr/bin/env python3
"""Convert native third-party fish trajectories into immutable centre observations.

No fabricated detection boxes or confidence probabilities. Native idtracker.ai
identity probabilities NEVER become fish-detection confidence. SLEAP pose
centroids are arithmetic centres of VISIBLE keypoints, not fish body centroids
or validated physical positions. All frame origins require explicit declaration.
"""
import argparse
import csv
import json
import math
from pathlib import Path

from aqt_official_fish_trackeval import digest


def _integer(x,field):
    try:
        val=int(x)
    except (TypeError,ValueError) as e:
        raise ValueError("Invalid "+field) from e
    if val<0 or str(val)!=str(x).strip():
        raise ValueError("Nonnegative integer required for "+field)
    return val


def idtracker_rows(path,frame_origin,expected_frames):
    with path.open(newline="",encoding="utf-8-sig") as f:
        rd=csv.DictReader(f)
        if rd.fieldnames!=["frame","time","individual","x","y","probability"]:
            raise ValueError("Expected idtracker.ai 6 CSV tidy original field names")
        raw=list(rd)
    numeric=set();observed=[];excluded=0
    for row in raw:
        fr=_integer(row["frame"],"frame")-frame_origin+1
        if not 1<=fr<=expected_frames:
            raise ValueError("idtracker frame convention disagrees with source timeline")
        individual=_integer(row["individual"],"individual")
        numeric.add(individual)
        try:
            x=float(row["x"]);y=float(row["y"])
            prob=float(row["probability"])
            t=float(row["time"])
        except ValueError as e:
            raise ValueError("Invalid idtracker exported numeric value") from e
        if not math.isfinite(t):
            raise ValueError("Invalid original idtracker time")
        if not math.isfinite(x) or not math.isfinite(y):
            excluded+=1
            continue
        if math.isfinite(prob) and not 0<=prob<=1:
            raise ValueError("Invalid idtracker ID probability")
        observed.append((fr,individual,x,y))
    mapping={v:i+1 for i,v in enumerate(sorted(numeric))}
    output=[(f,mapping[i],x,y,"") for f,i,x,y in observed]
    return output,{"native_source":"idtrackerai_6_csv_tidy",
       "native_individual_id_map":{str(k):v for k,v in mapping.items()},
       "frame_origin_original":frame_origin,
       "n_missing_centres_excluded":excluded,
       "confidence_absent":True,
       "identity_probability_not_used_as_detection_confidence":True,
       "native_segmentation_boxes_preserved":False}


def sleap_rows(path,frame_origin,expected_frames):
    try:
        import numpy as np
        import sleap_io
    except ImportError as e:
        raise RuntimeError("SLEAP conversion requires independently installed sleap-io and numpy") from e
    labels=sleap_io.load_slp(str(path))
    videos=set()
    names=set();raw=[];miss=0;bad_score=0
    for lf in labels:
        videos.add(id(lf.video))
        frame=int(lf.frame_idx)-frame_origin+1
        if not 1<=frame<=expected_frames:
            raise ValueError("SLEAP source frame convention disagrees with test timeline")
        for instance in lf:
            if instance.__class__.__name__!="PredictedInstance":
                raise ValueError("SLEAP input includes non-predicted/hand-labelled instances")
            if instance.track is None or not getattr(instance.track,"name",None):
                raise ValueError("SLEAP prediction without native individual track")
            name=str(instance.track.name)
            names.add(name)
            positions=np.asarray(instance.numpy(),dtype=float)
            if positions.ndim!=2 or positions.shape[1]!=2:
                raise ValueError("SLEAP predicted keypoints must form N-by-2")
            valid=np.isfinite(positions).all(axis=1)
            if not valid.any():
                miss+=1
                continue
            score=getattr(instance,"score",None)
            if score is None or not math.isfinite(float(score)):
                bad_score+=1;score=None
            # Pose/grouping scores can be unbounded, unlike YOLO probabilities.
            # Preserve the native finite score; never normalize against test data.
            mid=positions[valid].mean(axis=0)
            raw.append((frame,name,float(mid[0]),float(mid[1]),score))
    if len(videos)!=1:
        raise ValueError("One benchmark sequence must reference exactly one SLEAP video")
    mapping={v:i+1 for i,v in enumerate(sorted(names))}
    output=[(f,mapping[name],x,y,("" if sc is None else sc))
            for f,name,x,y,sc in raw]
    return output,{
      "native_source":"sleap_io_sleap_predicted_instances",
      "track_name_to_id":mapping,"frame_origin_original":frame_origin,
      "centroid_definition":"mean_of_visible_model_predicted_pose_keypoints",
      "n_no_visible_keypoint_instances_excluded":miss,
      "n_missing_instance_confidence":bad_score,
      "pose_instance_scores_are_not_probabilities":True,
      "score_semantics":"pose_instance_score" if bad_score==0 else "absent",
      "native_fish_bbox_supplied":False,
      "pose_centroid_not_independently_annotated_body_center":True}


def yolo_rows(path,expected_frames):
    from aqt_official_fish_trackeval import mot_rows
    mot=mot_rows(path,expected_frames,is_ground_truth=False)
    output=[(f,i,x+w/2,y+h/2,sc)
            for f,i,(x,y,w,h),sc in mot]
    return output,{"native_source":"YOLO_tracking_MOT_box",
      "bbox_available_in_original_MOT":True,
      "confidence_semantics":"model_detection_confidence",
      "frame_origin_original":1}


def convert(source,kind,origin,nframes,out):
    if out.exists() or out.with_suffix(".provenance.json").exists():
        raise FileExistsError("Refuse overwrite native prediction conversion")
    if kind=="idtrackerai":
        rows,report=idtracker_rows(source,origin,nframes)
    elif kind=="sleap":
        rows,report=sleap_rows(source,origin,nframes)
    elif kind=="yolo_mot":
        if origin!=1:
            raise ValueError("MOT source frames are 1-based")
        rows,report=yolo_rows(source,nframes)
    else:
        raise ValueError("Unknown source export format")
    if len({(r[0],r[1]) for r in rows})!=len(rows):
        raise ValueError("Native source has duplicate track observations per frame")
    if not rows:
        raise ValueError("No scored fish centres; do not fabricate zero detections")
    out.parent.mkdir(parents=True,exist_ok=True)
    with out.open("w",newline="",encoding="utf-8") as f:
        w=csv.writer(f);w.writerow(["frame","track_id","x_px","y_px","score"])
        w.writerows(sorted(rows,key=lambda q:(q[0],q[1])))
    report.update({"native_source_sha256":digest(source),
        "converted_centres_sha256":digest(out),
        "n_centres":len(rows),"expected_frames":nframes,
        "no_ground_truth_injected":True,
        "video_inference_performed_by_converter":False})
    out.with_suffix(".provenance.json").write_text(
        json.dumps(report,sort_keys=True,indent=2,allow_nan=False)+"\n")
    return report


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--input",type=Path,required=True)
    p.add_argument("--format",choices=("idtrackerai","sleap","yolo_mot"),
                   required=True)
    p.add_argument("--frame-origin",type=int,choices=(0,1),required=True)
    p.add_argument("--expected-frames",type=int,required=True)
    p.add_argument("--out",type=Path,required=True)
    a=p.parse_args()
    print(json.dumps(convert(a.input,a.format,a.frame_origin,a.expected_frames,
                             a.out),indent=2,sort_keys=True))


if __name__=="__main__":
    main()

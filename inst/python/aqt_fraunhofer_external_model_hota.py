#!/usr/bin/env python3
"""Real external-domain fish video frames -> frozen Oxford detector -> ByteTrack -> official HOTA.

Fraunhofer HHI ricefish A; Oxford EfficientDet trained on different study fish.
Source-original GT IDs are used for evaluation ONLY, not tracking or inference.
Original 101 image frames are named 043450..043550 (NOT local 1..101).
Original source server's TLS issuer is broken; exact ZIP SHA from prior
independent CI is required, but peer identity is NOT independently verified.
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

import aqt_official_fish_trackeval as metric
from aqt_oxford_frozen_model_smoke import check_frozen_model,input_array
from aqt_oxford_frozen_sequence_benchmark import source_tensor_boxes

ORIGINAL_A_SHA="18c39619b1f84ea774f16fedfac5911d92de86ab7da4aa03cf365b9b4be58ceb"
ORIGINAL_GT_SHA="b70a699b4e41cbec636e5f4b500482451d40ddad29fb387dc36dc0c6392021d3"
SOURCE_URI="https://cvg.hhi.fraunhofer.de/FishTrackingData/video_a/mot_a.zip"
N_FRAMES=101
ORIG_FIRST=43450
ORIG_LAST=43550
W,H=2448,2048

def _numpy_json_scalar(value):
    """Permit only finite scalar/array NumPy metrics, without hiding errors."""
    import numpy as np
    if isinstance(value,np.integer):
        return int(value)
    if isinstance(value,np.floating):
        number=float(value)
        if not math.isfinite(number):
            raise ValueError("Nonfinite floating point scientific metric")
        return number
    if isinstance(value,np.bool_):
        return bool(value)
    if isinstance(value,np.ndarray):
        return value.tolist()
    raise TypeError(f"Unexpected scientific JSON evidence type: {type(value).__name__}")


def _dump_evidence(value):
    return json.dumps(value,sort_keys=True,indent=2,
                      default=_numpy_json_scalar,allow_nan=False)


def source_archive(path):
    if metric.digest(path)!=ORIGINAL_A_SHA:
        raise ValueError("Source archive hash differs from frozen independently observed source")
    with zipfile.ZipFile(path) as z:
        names=z.namelist()
        if len(names)>300 or any(
            PurePosixPath(n).is_absolute() or ".." in PurePosixPath(n).parts or
            "\\" in n for n in names):
            raise ValueError("Unexpected/unsafe original HHI source archive")
        gt=[n for n in names if n.lower().endswith("/gt/gt.txt")]
        imgs=[n for n in names if n.lower().endswith((".jpg",".jpeg",".png"))]
        if len(gt)!=1 or len(imgs)!=N_FRAMES:
            raise ValueError("Original GT/image source coverage mismatch")
        raw=z.read(gt[0])
        if hashlib.sha256(raw).hexdigest()!=ORIGINAL_GT_SHA:
            raise ValueError("Source GT hash mismatch")
        ids=[int(PurePosixPath(n).stem) for n in imgs]
        if sorted(ids)!=list(range(ORIG_FIRST,ORIG_LAST+1)):
            raise ValueError("Source image frame IDs not the original A 43450..43550")
        image_by_frame={int(PurePosixPath(n).stem):n for n in imgs}
        gt_lines=list(csv.reader(io.StringIO(raw.decode("utf-8-sig"))))
        if len(gt_lines)!=9214:
            raise ValueError("Original A source annotation row count differs from audit")
        local=[]
        source_ids=set()
        for line in gt_lines:
            if len(line)<7:
                raise ValueError("Incomplete HHI original MOT GT record")
            frame=int(line[0])
            if frame<ORIG_FIRST or frame>ORIG_LAST:
                raise ValueError("Original source frame outside evaluated image window")
            source_ids.add(frame)
            new=list(line)
            new[0]=str(frame-ORIG_FIRST+1)
            local.append(new)
        if source_ids!=set(ids):
            raise ValueError("Unannotated original source frame; completeness not established")
        with tempfile.TemporaryDirectory() as td:
            loc=Path(td)/"gt_local.txt"
            with loc.open("w",newline="",encoding="utf-8") as f:
                csv.writer(f).writerows(local)
            gt_tracks=metric.mot_rows(loc,N_FRAMES,is_ground_truth=True)
        if len({v[1] for v in gt_tracks})!=260:
            raise ValueError("Original source GT fish ID count not 260")
        # The archive stays open only in the outer with. Caller receives byte
        # stream via generator? No: bounded 101x JPEGs loaded in memory.
        # Each source JPEG ~1.8 MB, total 180MB. Hashes recorded per image.
        ordered=[(frame,z.read(image_by_frame[frame]))
                 for frame in range(ORIG_FIRST,ORIG_LAST+1)]
    return gt_tracks,ordered

def evaluate_frozen_model(archive,model_dir,out):
    if out.exists():
        raise FileExistsError("Refuse overwrite real external source benchmark")
    import numpy as np
    import tensorflow as tf
    import supervision as sv
    if sv.__version__!="0.26.1":
        raise ValueError("Frozen ByteTrack supervision version changed")
    weights=check_frozen_model(model_dir)
    gt,images=source_archive(archive)
    model=tf.saved_model.load(str(model_dir))
    if "serving_default" not in model.signatures:
        raise ValueError("Original Oxford frozen model lacks serving_default")
    sig=model.signatures["serving_default"]
    _,named=sig.structured_input_signature
    if len(named)!=1:
        raise ValueError("Unverified original frozen detector tensor input layout")
    key,spec=next(iter(named.items()))
    tracker=sv.ByteTrack(track_activation_threshold=.25,
                         lost_track_buffer=30,
                         minimum_matching_threshold=.8,
                         frame_rate=30,minimum_consecutive_frames=1)
    produced=[]
    tracked=[]
    invalid=[]
    transforms=set()
    sha_by_source={}
    for local,(source_frame,pixels) in enumerate(images,1):
        with tempfile.TemporaryDirectory() as td:
            name=Path(td)/"current_original_ricefish.jpg"
            name.write_bytes(pixels)
            tensor,transform=input_array(name,spec)
        if (transform["original_width_px"],transform["original_height_px"])!=(W,H):
            raise ValueError("Original real fish source image geometry differs from published dimensions")
        transforms.add(transform["input_transform"])
        sha_by_source[str(source_frame)]=hashlib.sha256(pixels).hexdigest()
        result=sig(**{key:tensor})
        if set(result)!={"detections:0"}:
            raise ValueError("Frozen Oxford model output schema changed")
        boxes,rejected=source_tensor_boxes(result["detections:0"].numpy(),W,H,.25)
        for b in rejected:
            invalid.append({"source_frame":source_frame,"local_frame":local,**b})
        source=[]
        for b in boxes:
            x,y,w,h=b["xywh"]
            produced.append({
                "source_frame":source_frame,"frame":local,
                "x":x,"y":y,"w":w,"h":h,
                "confidence":float(b["score"]),
                "unverified_fish_class_index":float(b["model_class_index"])})
            source.append(b)
        xyxy=np.asarray(
            [[b["xywh"][0],b["xywh"][1],
              b["xywh"][0]+b["xywh"][2],b["xywh"][1]+b["xywh"][3]]
             for b in source],dtype=np.float32).reshape((-1,4))
        det=sv.Detections(
            xyxy=xyxy,
            confidence=np.asarray([b["score"] for b in source],dtype=np.float32),
            class_id=np.zeros(len(source),dtype=int))
        assigned=tracker.update_with_detections(det)
        frame_ids=set()
        for i in range(len(assigned)):
            fid=int(assigned.tracker_id[i])+1
            if fid in frame_ids or fid<1:
                raise ValueError("ByteTrack produced duplicate or negative frame ID")
            frame_ids.add(fid)
            x1,y1,x2,y2=map(float,assigned.xyxy[i])
            if not(0<=x1<x2<=W+1 and 0<=y1<y2<=H+1):
                raise ValueError("Invalid tracked fish box geometry")
            tracked.append((local,fid,(x1,y1,x2-x1,y2-y1),
                           float(assigned.confidence[i])))
    official=metric.evaluate(gt,tracked,N_FRAMES,"HHI_RICEFISH_A_EXTERNAL")
    source_eval={}
    for score_threshold in (.25,.5,.7):
        import numpy as np
        as_gt=[[] for _ in range(N_FRAMES)]
        as_pred=[[] for _ in range(N_FRAMES)]
        for f,k,box,c in gt:as_gt[f-1].append(box)
        for b in produced:
            if b["confidence"]>=score_threshold:
                as_pred[b["frame"]-1].append(
                    (b["x"],b["y"],b["w"],b["h"]))
        from scipy.optimize import linear_sum_assignment
        tp=0;fp=0;fn=0
        for aa,bb in zip(as_gt,as_pred):
            sim=metric.similarities(aa,bb)
            n=0
            if len(aa) and len(bb):
                ri,ci=linear_sum_assignment(-sim)
                n=sum(sim[i,j]>=.5 for i,j in zip(ri,ci))
            tp+=n;fp+=len(bb)-n;fn+=len(aa)-n
        # Original model boxes rejected for invalid image geometry are
        # false positives rather than silently omitted from detection metrics.
        extra_fp=sum(v["score"]>=score_threshold for v in invalid)
        fp+=extra_fp
        source_eval[str(score_threshold)]={
            "invalid_source_boxes_counted_as_FP":extra_fp,
            "tp":tp,"fp":fp,"fn":fn,
            "precision":tp/(tp+fp) if tp+fp else None,
            "recall":tp/(tp+fn) if tp+fn else None,
            "F1":2*tp/(2*tp+fp+fn) if 2*tp+fp+fn else None}
    out.mkdir(parents=True)
    raw_csv=out/"fish_model_detections.csv"
    with raw_csv.open("w",newline="") as f:
        writer=csv.DictWriter(f,fieldnames=[
            "source_frame","frame","x","y","w","h",
            "confidence","unverified_fish_class_index"])
        writer.writeheader();writer.writerows(produced)
    tracked_csv=out/"fish_model_bytetrack.csv"
    with tracked_csv.open("w",newline="") as f:
        writer=csv.writer(f);writer.writerow(
            ["local_frame","track_id","x","y","w","h","confidence"])
        for frame,tid,box,score in tracked:
            writer.writerow([frame,tid,*box,score])
    status={
        "source":"Original Fraunhofer HHI Video A Sulawesi ricefish",
        "original_archive_url":SOURCE_URI,
        "original_archive_sha256":ORIGINAL_A_SHA,
        "source_original_frame_start":ORIG_FIRST,
        "source_original_frame_end":ORIG_LAST,
        "source_to_local_frame_mapping":"source_frame - 43449, 1-based",
        "source_original_image_sha256":sha_by_source,
        "original_fish_IDs_visible_to_model_or_tracker":False,
        "n_reference_fish_boxes":len(gt),
        "n_source_gt_IDs":len({x[1] for x in gt}),
        "n_real_original_source_images_inferred":len(images),
        "n_model_generated_fish_boxes_score_ge_0_25":len(produced),
        "n_invalid_model_source_boxes_score_ge_0_25":len(invalid),
        "n_model_bytetrack_observations":len(tracked),
        "detector_source":"Oxford frozen published EfficientDet fish-trained v2",
        "detector_source_weights":weights,
        "detector_input_transforms":sorted(transforms),
        "tensorflow_version":tf.__version__,
        "tracker_source":"supervision.ByteTrack==0.26.1",
        "tracker_frame_rate_assumption_not_actual_PTS":30,
        "real_video_original_PTS_available":False,
        "detection_score_against_published_source_MOT_GT":source_eval,
        "official_trackeval_metric_source_commit":metric.TRACK_EVAL_COMMIT,
        "official_trackeval_model_generated_tracks":official,
        "derived_artifact_sha256":{
            raw_csv.name:metric.digest(raw_csv),
            tracked_csv.name:metric.digest(tracked_csv)},
        "original_fraunhofer_host_TLS_peer_auth_verified":False,
        "source_ground_truth_blinded_independently_reviewed":False,
        "model_training_source_overlap_audited":False,
        "physical_underwater_3d_or_multicam_accuracy_certified":False,
        "fish_welfare_validated":False
    }
    (out/"report.json").write_text(_dump_evidence(status)+"\n")
    return status

def main(argv=None):
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--source-archive",type=Path,required=True)
    ap.add_argument("--oxford-frozen-model-dir",type=Path,required=True)
    ap.add_argument("--out",type=Path,required=True)
    a=ap.parse_args(argv)
    data=evaluate_frozen_model(a.source_archive,a.oxford_frozen_model_dir,a.out)
    print(_dump_evidence({
        x:data[x] for x in (
            "n_real_original_source_images_inferred",
            "n_model_generated_fish_boxes_score_ge_0_25",
            "n_model_bytetrack_observations",
            "official_trackeval_model_generated_tracks",
            "detection_score_against_published_source_MOT_GT")}))
    return 0
if __name__=="__main__":
    raise SystemExit(main())

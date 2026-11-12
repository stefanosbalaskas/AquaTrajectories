#!/usr/bin/env python3
"""Run ACTUAL ByteTrack on original Oxford published fish detections.

This runs a tracker, not a detector. The inputs are Oxford's own published
EfficientDet predictions (not AquaTrajectories model-inferred predictions).
The published LISA reviewed boxes have no independent multi-fish ID truth;
HOTA/IDF1, physical XYZ and biological stress cannot be inferred here.

Dependency-qualified against supervision==0.26.1 (older ByteTrack API).
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from collections import defaultdict
from pathlib import Path

from aqt_oxford_detection_audit import parsed_annotations, sha256, PRED_BLOB_SHA, SOURCE_COMMIT


def source_detections(path):
    """Read exact original predictions and confidence; retain empty frames."""
    source = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    frames = parsed_annotations(path)
    info = {}
    for row in source["files"]:
        name = row["src"]
        if name not in frames or len(row["rdata"]) != len(row["regions"]):
            raise ValueError("Source box/score correspondence missing")
        boxes = frames[name]["boxes"]
        if len(boxes) != len(row["regions"]):
            raise ValueError("Original detections include unsupported geometry")
        scores = []
        for label in row["rdata"]:
            try:
                score = float(label["confidence"])
            except (TypeError, ValueError, KeyError) as exc:
                raise ValueError("Missing real published detector confidence") from exc
            if not math.isfinite(score) or score < 0 or score > 1:
                raise ValueError("Bad original detector confidence")
            scores.append(score)
        info[name] = {**frames[name], "scores": scores}
    return info


def group_sequences(source):
    result = defaultdict(list)
    for name, info in source.items():
        result[info["sequence"]].append(info)
    for sequence, rows in result.items():
        rows.sort(key=lambda r: r["frame"])
        actual = [x["frame"] for x in rows]
        if actual != list(range(len(rows))):
            raise ValueError(f"Missing/repeated source frames: {sequence}")
    return dict(sorted(result.items()))


def track_detections(frames, track_activation_threshold=0.25,
                     lost_track_buffer=30, minimum_matching_threshold=0.8,
                     frame_rate=25):
    """One new ByteTrack per original session; return observable associations."""
    import numpy as np
    import supervision as sv
    if not hasattr(sv, "ByteTrack"):
        raise RuntimeError("Expected supervision==0.26.1 ByteTrack API")
    if not (0 < track_activation_threshold < 1 and
            0 < minimum_matching_threshold <= 1 and
            isinstance(lost_track_buffer, int) and lost_track_buffer >= 0 and
            isinstance(frame_rate, int) and frame_rate > 0):
        raise ValueError("Invalid tracker configuration")
    by_sequence = group_sequences(frames)
    all_rows, summary = [], {}
    for sequence, source_frames in by_sequence.items():
        tracker = sv.ByteTrack(
            track_activation_threshold=track_activation_threshold,
            lost_track_buffer=lost_track_buffer,
            minimum_matching_threshold=minimum_matching_threshold,
            frame_rate=frame_rate,
            minimum_consecutive_frames=1)
        n_source, n_assigned, unassigned = 0, 0, 0
        track_frames = defaultdict(list)
        for frame in source_frames:
            xyxy = np.asarray([[x, y, x + w, y + h] for x, y, w, h in frame["boxes"]],
                              dtype=np.float32).reshape((-1, 4))
            confidence = np.asarray(frame["scores"], dtype=np.float32)
            n_source += len(xyxy)
            detections = sv.Detections(
                xyxy=xyxy, confidence=confidence,
                class_id=np.zeros(len(xyxy), dtype=int))
            output = tracker.update_with_detections(detections)
            ids = getattr(output, "tracker_id", None)
            if ids is None and len(output):
                raise RuntimeError("No tracker identities returned")
            if len(output) > len(xyxy):
                raise RuntimeError("ByteTrack emitted more fish than input detections")
            seen = set()
            for i in range(len(output)):
                tid = int(output.tracker_id[i])
                if tid < 0 or tid in seen:
                    raise RuntimeError("Negative or duplicated frame-local fish identity")
                seen.add(tid)
                x1, y1, x2, y2 = map(float, output.xyxy[i])
                if not (0 <= x1 < x2 <= 1920.01 and
                        0 <= y1 < y2 <= 1080.01):
                    raise ValueError("Tracker emitted outside source fish frame")
                score = float(output.confidence[i])
                if not (math.isfinite(score) and 0 <= score <= 1):
                    raise ValueError("Invalid tracked source confidence")
                all_rows.append(dict(
                    recording=sequence, frame_id=int(frame["frame"]),
                    frame_mot=int(frame["frame"])+1, track_id=tid,
                    xmin_px=x1, ymin_px=y1, width_px=x2-x1,
                    height_px=y2-y1, confidence=score, class_id=0))
                track_frames[tid].append(frame["frame"])
            n_assigned += len(output)
            unassigned += len(xyxy) - len(output)
        temporal_gaps = sum(sum(b-a>1 for a,b in zip(f, f[1:]))
                            for f in track_frames.values())
        summary[sequence] = dict(
            source_frames=len(source_frames),
            source_detector_boxes=n_source,
            tracker_assigned_boxes=n_assigned,
            unassigned_source_boxes=unassigned,
            observed_local_track_ids=len(track_frames),
            local_track_gaps=temporal_gaps,
            idf1_hota_measured=False)
    return all_rows, summary


def export_results(rows, session_stats, predictions_file, target,
                   *, version="0.26.1"):
    out=Path(target)
    if out.exists():
        raise FileExistsError("Refuse overwrite existing tracker evidence")
    out.mkdir(parents=True)
    csv_path=out/"real_source_bytetrack.csv"
    columns=["recording","frame_id","frame_mot","track_id",
             "xmin_px","ymin_px","width_px","height_px","confidence","class_id"]
    with csv_path.open("w",encoding="utf-8",newline="") as stream:
        writer=csv.DictWriter(stream,fieldnames=columns)
        writer.writeheader()
        writer.writerows(rows)
    metadata={
        "schema_version":"1.0",
        "source_repository":"https://github.com/ox-vgg/fish-tank-obstacles",
        "source_commit":SOURCE_COMMIT,
        "source_publication_annotation_blob_sha":PRED_BLOB_SHA,
        "source_predictions_sha256":sha256(predictions_file),
        "tracker":"supervision.ByteTrack",
        "tracker_version_expected":version,
        "tracker_configuration":{
            "track_activation_threshold":0.25,"lost_track_buffer":30,
            "minimum_matching_threshold":0.8,"frame_rate_assumed_for_tracker":25,
            "minimum_consecutive_frames":1},
        "recordings":session_stats,
        "n_recordings":len(session_stats),
        "n_original_frames":sum(s["source_frames"] for s in session_stats.values()),
        "n_original_detections":sum(s["source_detector_boxes"] for s in session_stats.values()),
        "n_tracker_observations":len(rows),
        "output_sha256":sha256(csv_path),
        "detector_run_on_video_here":False,
        "uses_original_published_oxford_detector_outputs":True,
        "source_score_range_min_max":[0.7,0.909],
        "original_video_pts_used_for_tracker":False,
        "human_ground_truth_identity_ids_available":False,
        "official_HOTA_IDF1_measured":False,
        "cross_view_identity_verified":False,
        "underwater_physical_xyz_certified":False,
        "model_weights_frozen_and_run_here":False,
        "fish_welfare_scientifically_validated":False}
    (out/"audit.json").write_text(json.dumps(metadata,indent=2,sort_keys=True)+"\n",
                                 encoding="utf-8")
    return metadata


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--detections",type=Path,required=True)
    parser.add_argument("--output-dir",type=Path,required=True)
    args=parser.parse_args(argv)
    frames=source_detections(args.detections)
    rows, stats=track_detections(frames)
    result=export_results(rows,stats,args.detections,args.output_dir)
    print(json.dumps({key:result[key] for key in
        ("n_recordings","n_original_frames","n_original_detections",
         "n_tracker_observations","official_HOTA_IDF1_measured")},indent=2))
    return 0


if __name__=="__main__":
    raise SystemExit(main())

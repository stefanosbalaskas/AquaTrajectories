#!/usr/bin/env python3
"""Real Oxford original-source experiment -> loss-audited MOT Research Bundle input.

Reads ONLY archived, real model-generated Oxford EfficientDet/ByteTrack rows,
the EXACT original Oxford source MP4 bytes, its independently re-probed PTS,
and the immutable Wave13E report. It never fabricates fish IDs/frames/PTS,
re-runs a model, or calls original labels "prediction-blind independent GT".
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path

SOURCE_ARCHIVE_SHA256 = "91c71d297b7bfa6bd19c6f34ec5d12e1534bf7ef2f90d3249662605507ca9ae4"
SOURCE_CLIP_SHA256 = "acd118909b7bd44b013450e35525409ab2bfe53e15e81f48834fe33bfea682c0"
SOURCE_FRAME_COUNT = 149
UPSTREAM_REAL_RUN_ID = 43287906771
COLUMNS = ["recording", "frame_id", "frame_mot", "track_id", "xmin_px",
           "ymin_px", "width_px", "height_px", "confidence", "class_id", "time_s"]
FRAME_COLUMNS = ["session_id", "camera_id", "frame_id", "time_s",
                 "width_px", "height_px"]


def sha(p: Path) -> str:
    digest = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_csv(path, fields):
    with Path(path).open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames != fields:
            raise ValueError("Unexpected source CSV contract: " + str(path))
        rows = list(reader)
        if any(None in row or None in row.values() for row in rows):
            raise ValueError("Malformed source CSV")
    return rows


def numeric(x, field):
    try:
        v = float(x)
    except (TypeError, ValueError):
        raise ValueError("Invalid numeric " + field) from None
    if not math.isfinite(v):
        raise ValueError("Nonfinite " + field)
    return v


def run(archived_report, archived_frames, archived_tracks, reverified_frames,
        original_clip, out):
    report = json.loads(Path(archived_report).read_text(encoding="utf-8"))
    if report.get("source_video_model_forward_pass_count") != SOURCE_FRAME_COUNT:
        raise ValueError("Archive is not the complete original 149-frame inference")
    if report.get("real_source_video_sha256") != SOURCE_CLIP_SHA256:
        raise ValueError("Archived benchmark has wrong original source MP4")
    if sha(Path(original_clip)) != SOURCE_CLIP_SHA256:
        raise ValueError("Freshly downloaded real MP4 source integrity mismatch")
    if report.get("original_source_labels_prediction_blind_externally_verified") is not False:
        raise ValueError("Unexpected reference label independence field")
    if report.get("official_HOTA_IDF1_measured") is not False:
        raise ValueError("Unexpected official ID accuracy claim")
    archived_hashes = report.get("files_sha256", {})
    for p in (archived_tracks,):
        if archived_hashes.get(Path(p).name) != sha(Path(p)):
            raise ValueError("Archived real model-generated track digest mismatch")
    if report.get("original_frame_pts_manifest_sha256") != sha(Path(archived_frames)):
        raise ValueError("Archived real source PTS file SHA-256 mismatch")
    a = read_csv(archived_frames, FRAME_COLUMNS)
    b = read_csv(reverified_frames, FRAME_COLUMNS)
    if len(a) != SOURCE_FRAME_COUNT or len(b) != SOURCE_FRAME_COUNT:
        raise ValueError("Not the full 149-frame source recording")
    if a != b:
        # FFprobe float printing can differ between runtime releases;
        # require all source numeric PTS and image geometry to agree.
        for i, (x, y) in enumerate(zip(a, b)):
            if (x["session_id"], x["camera_id"], x["frame_id"],
                x["width_px"], x["height_px"]) != (
                y["session_id"], y["camera_id"], y["frame_id"],
                y["width_px"], y["height_px"]):
                raise ValueError("Original source re-probe geometry/frame differs")
            if abs(numeric(x["time_s"], "archived PTS") -
                   numeric(y["time_s"], "re-probed PTS")) > 1e-6:
                raise ValueError("Reprobed video clock differs at frame " + str(i))
    expected_frames = list(range(SOURCE_FRAME_COUNT))
    if [int(x["frame_id"]) for x in a] != expected_frames:
        raise ValueError("Source manifest frame schedule is not exact 0..148")
    scope = {(x["session_id"], x["camera_id"]) for x in a}
    if scope != {("oxford_eval", "oxford_single_video")}:
        raise ValueError("Source session/camera scope changed")
    if any(x["width_px"] != "1920" or x["height_px"] != "1080" for x in a):
        raise ValueError("Original fish MP4 image geometry changed")
    times = [numeric(x["time_s"], "source PTS") for x in a]
    if times[0] != 0 or any(y <= x for x,y in zip(times,times[1:])):
        raise ValueError("Original source clock is not strictly increasing")
    tracks = read_csv(archived_tracks, COLUMNS)
    if not tracks:
        raise ValueError("No genuinely produced real-source fish tracks")
    if report.get("newly_generated_bytetrack_rows") != len(tracks):
        raise ValueError("Tracker observation count disagrees with original model run")
    out = Path(out)
    if out.exists():
        raise FileExistsError("Refuse overwriting real study evidence")
    if not out.parent.is_dir():
        raise ValueError("Output parent missing")
    out.mkdir()
    canonical = out / "oxford_real_bytetrack_mot.csv"
    seen = set()
    n_obs = 0
    observed_frames = set()
    with canonical.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        for r in tracks:
            frame = int(r["frame_id"])
            source_frame = int(r["frame_mot"])
            if not (0 <= frame < SOURCE_FRAME_COUNT) or source_frame != frame + 1:
                raise ValueError("Original tracker frame origin changed")
            if r["recording"] != "F30_T15":
                raise ValueError("Wrong original Oxford recording")
            ident = r["track_id"]
            if not ident or (frame, ident) in seen:
                raise ValueError("Missing or repeated camera-local track identity")
            seen.add((frame, ident))
            x = numeric(r["xmin_px"], "box left")
            y = numeric(r["ymin_px"], "box top")
            w = numeric(r["width_px"], "box width")
            h = numeric(r["height_px"], "box height")
            confidence = numeric(r["confidence"], "detector score")
            if not (0 <= x and 0 <= y and w > 0 and h > 0 and
                    x + w <= 1920.000001 and y + h <= 1080.000001):
                raise ValueError("Outside-image tracker bounding box")
            if not (0 <= confidence <= 1):
                raise ValueError("Invalid original detector confidence")
            if abs(numeric(r["time_s"], "tracker PTS")-times[frame]) > 1e-6:
                raise ValueError("Original ByteTrack row time mismatched source frame")
            writer.writerow([source_frame, ident, format(x, ".17g"),
                format(y, ".17g"), format(w, ".17g"), format(h, ".17g"),
                format(confidence, ".17g"), -1, -1, -1])
            n_obs += 1
            observed_frames.add(frame)
    record = {
        "schema": "AQT_M05_REAL_OXFORD_DEVELOPMENT_DEMONSTRATION_V1",
        "dataset_type": "genuine_original_oxford_fish_video",
        "source_archive_sha256": SOURCE_ARCHIVE_SHA256,
        "source_clip_sha256": SOURCE_CLIP_SHA256,
        "source_clip": "eval/F30_T15.mp4",
        "full_original_source_frames": SOURCE_FRAME_COUNT,
        "original_source_PTS_reprobed_against_archive": True,
        "original_video_local_PTS_not_camera_exposure_UTC": True,
        "n_native_model_generated_bytetrack_observations": n_obs,
        "n_source_frames_containing_tracker_predictions":len(observed_frames),
        "model": "original frozen Oxford EfficientDet-D2 v2; NOT YOLO",
        "tracker": "original genuinely executed ByteTrack",
        "archived_real_inference_run_id":UPSTREAM_REAL_RUN_ID,
        "new_model_inference_in_this_integration_job":False,
        "archived_real_model_inference_passes":SOURCE_FRAME_COUNT,
        "source_labels_prediction_blind_independently_verified":False,
        "fish_id_accuracy_HOTA_IDF1_certified":False,
        "original_weights_training_cohort_disjoint_verified":False,
        "new_session_independent_holdout":False,
        "physical_underwater_calibration_verified":False,
        "feeding_event_times_supplied":False,
        "animal_stress_or_welfare_validated":False,
        "original_scoring_against_source_reviewed_boxes":report.get("scoring"),
        "source_model_components":report.get("model_components"),
        "original_tracker_runtime":report.get("tracker_runtime"),
        "input_provenance_sha256": {
            "source_mp4":sha(Path(original_clip)),
            "archived_frames":sha(Path(archived_frames)),
            "freshly_reprobed_frames":sha(Path(reverified_frames)),
            "archived_tracks":sha(Path(archived_tracks)),
            "archived_report":sha(Path(archived_report)),
            "canonical_mot":sha(canonical),
        },
        "no_source_images_or_gt_used_as_inference_inputs_in_this_job":True,
    }
    (out / "REAL_SOURCE_AUDIT.json").write_text(
        json.dumps(record, indent=2, sort_keys=True, allow_nan=False)+"\n",
        encoding="utf-8")
    return record


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    for arg in ("archived-report","archived-frames","archived-tracks",
                "reverified-frames","original-clip","out"):
        p.add_argument("--"+arg,required=True,type=Path)
    a = p.parse_args(argv)
    result = run(a.archived_report,a.archived_frames,a.archived_tracks,
        a.reverified_frames,a.original_clip,a.out)
    print(json.dumps({k:result[k] for k in ("schema","full_original_source_frames",
        "n_native_model_generated_bytetrack_observations",
        "new_session_independent_holdout")},indent=2))
    return 0


if __name__=="__main__":
    raise SystemExit(main())

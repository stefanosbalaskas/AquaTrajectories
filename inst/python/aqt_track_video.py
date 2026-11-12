#!/usr/bin/env python3
"""AquaTrajectories optional, explicitly unvalidated fish-video tracker.

Decode a local video ONCE with PyAV to preserve the decoded-frame PTS and
pass the exact corresponding BGR array to an externally supplied
Ultralytics YOLO model configured for ByteTrack. Export all acquired frames
(including those with no fish) and strict MOTChallenge positional tracks.

The script does not train/validate a fish detector, certify camera-clock
synchronization, identify fish across views or infer fish welfare.
Run with a fish-specific model that has been independently evaluated.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import tempfile


def local_pts(raw_pts: float, origin: float | None,
              previous: float | None) -> tuple[float, float]:
    """Convert a decoded-frame presentation timestamp to local seconds."""
    if raw_pts is None or not isinstance(raw_pts, (int, float)) or \
            not math.isfinite(raw_pts):
        raise ValueError("Every decoded video frame requires finite PyAV PTS")
    if origin is None:
        origin = float(raw_pts)
    t = float(raw_pts) - origin
    if t < -1e-9:
        raise ValueError("Decoded frame PTS precedes first video timestamp")
    if t < 0:
        t = 0.0  # sub-nanosecond floating-point noise only
    if previous is not None and t <= previous:
        raise ValueError("Video PTS must strictly increase in decoded order")
    return origin, t


def mot_rows(detections: list[dict], frame_id: int,
             width_px: int, height_px: int) -> tuple[list[list], list[list]]:
    """Validate tracked boxes and emit canonical MOT rows and class sidecar."""
    if frame_id < 0 or width_px < 1 or height_px < 1:
        raise ValueError("Frame ID and dimensions are invalid")
    output, labels = [], []
    seen = set()
    for box in detections:
        ident = box["track_id"]
        if isinstance(ident, bool) or not isinstance(ident, (int, float)) or \
                not math.isfinite(ident) or ident != int(ident) or ident < 0:
            raise ValueError("Tracking IDs must be finite nonnegative integers")
        ident = int(ident)
        if ident in seen:
            raise ValueError("Duplicate tracker identity within decoded frame")
        seen.add(ident)
        score = box["confidence"]
        if not isinstance(score, (float, int)) or \
                not math.isfinite(score) or not 0 <= score <= 1:
            raise ValueError("Detector confidence must be within [0,1]")
        cls = box["class_id"]
        if isinstance(cls, bool) or not isinstance(cls, (int, float)) or \
                not math.isfinite(cls) or cls != int(cls) or cls < 0:
            raise ValueError("Species/class ID must be a nonnegative integer")
        xyxy = box["xyxy"]
        if len(xyxy) != 4 or any(not isinstance(v, (int, float)) or
                                 not math.isfinite(v) for v in xyxy):
            raise ValueError("Bounding box needs four finite XYXY coordinates")
        x1, y1, x2, y2 = map(float, xyxy)
        if not (0 <= x1 < x2 <= width_px + 1e-7 and
                0 <= y1 < y2 <= height_px + 1e-7):
            raise ValueError("Detector box is invalid or outside image extent")
        output.append([frame_id + 1, ident, x1, y1,
                       x2 - x1, y2 - y1, float(score), -1, -1, -1])
        labels.append([frame_id, ident, int(cls)])
    return output, labels


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _extract_tracked_boxes(result) -> tuple[list[dict], int]:
    """Convert a single Ultralytics video-frame result, no invented track IDs."""
    boxes = getattr(result, "boxes", None)
    if boxes is None:
        return [], 0
    xyxy = boxes.xyxy.cpu().tolist()
    if not xyxy:
        return [], 0
    identities = boxes.id
    if identities is None:
        # A detector hit without a tracker identity is not a fish trajectory.
        return [], len(xyxy)
    ids = identities.cpu().tolist()
    scores = boxes.conf.cpu().tolist()
    classes = boxes.cls.cpu().tolist()
    if not (len(xyxy) == len(ids) == len(scores) == len(classes)):
        raise RuntimeError("Ultralytics box/identity/confidence lengths disagree")
    return [
        {"xyxy": coords, "track_id": ident, "confidence": score,
         "class_id": cls}
        for coords, ident, score, cls in zip(xyxy, ids, scores, classes)
    ], 0


def run_video(video: Path, weights: Path, output_dir: Path, prefix: str,
              session_id: str, camera_id: str, confidence: float = 0.25,
              iou: float = 0.7, tracker: str = "bytetrack.yaml",
              device: str | None = None,
              class_filter: list[int] | None = None) -> dict:
    """Decode video/PTS in one PyAV pipeline and produce four auditable files."""
    if not re.fullmatch(r"[A-Za-z0-9_-]+", prefix):
        raise ValueError("prefix must be safe letters, digits, _ or -")
    for text in (session_id, camera_id):
        if not isinstance(text, str) or not text.strip() or \
                any(z in text for z in (",", "\n", "\r")):
            raise ValueError("Session/camera IDs must be CSV-safe nonempty text")
    if not isinstance(confidence, (int, float)) or \
            not math.isfinite(confidence) or not (0 < confidence <= 1):
        raise ValueError("confidence must be in (0,1]")
    if not isinstance(iou, (int, float)) or \
            not math.isfinite(iou) or not (0 < iou <= 1):
        raise ValueError("iou must be in (0,1]")
    if tracker != "bytetrack.yaml":
        raise ValueError("This runner explicitly supports bytetrack.yaml only")
    if not video.is_file() or not weights.is_file():
        raise FileNotFoundError("Both input video and model weights must exist")
    if class_filter is not None and \
            (len(set(class_filter)) != len(class_filter) or
             any(c < 0 for c in class_filter)):
        raise ValueError("Class filter must contain unique nonnegative IDs")

    try:
        import av
        from ultralytics import YOLO
        import ultralytics
    except ImportError as exc:
        raise RuntimeError(
            "Optional runner requires: pip install av ultralytics; "
            "R package dependencies alone do not execute the model") from exc

    output_dir.mkdir(parents=True, exist_ok=True)
    names = {
        "frames": f"{prefix}.frames.csv",
        "mot": f"{prefix}.mot.txt",
        "classes": f"{prefix}.classes.csv",
        "metadata": f"{prefix}.run.json",
    }
    # Never mix an old run with a new run under the same output prefix.
    # These files form one logical scientific bundle, not four independent CSVs.
    if any((output_dir / name).exists() for name in names.values()):
        raise FileExistsError("Refusing to overwrite an existing video bundle prefix")
    tmpdir = Path(tempfile.mkdtemp(prefix=f".{prefix}-", dir=output_dir))
    n_frames, n_tracked, n_unassigned = 0, 0, 0
    origin, prev, shape = None, None
    track_classes: dict[int, int] = {}, None
    try:
        model = YOLO(str(weights))
        with (tmpdir / names["frames"]).open("w", newline="", encoding="utf-8") as ff, \
                (tmpdir / names["mot"]).open("w", newline="", encoding="utf-8") as mf, \
                (tmpdir / names["classes"]).open("w", newline="", encoding="utf-8") as cf:
            fwriter = csv.writer(ff)
            mwriter = csv.writer(mf)
            cwriter = csv.writer(cf)
            fwriter.writerow(["session_id", "camera_id", "frame_id",
                              "time_s", "width_px", "height_px"])
            cwriter.writerow(["frame_id", "track_id", "class_id"])
            with av.open(str(video)) as container:
                streams = container.streams.video
                if not streams:
                    raise ValueError("No video stream found in input")
                # The *same* decoded pixel buffers supply YOLO and frame PTS.
                for frame in container.decode(streams[0]):
                    origin, t = local_pts(frame.time, origin, prev)
                    prev = t
                    bgr = frame.to_ndarray(format="bgr24")
                    height_px, width_px = bgr.shape[:2]
                    if shape is None:
                        shape = (height_px, width_px)
                    elif shape != (height_px, width_px):
                        raise ValueError("Changing frame dimensions are unsupported")
                    fwriter.writerow([session_id, camera_id, n_frames,
                                      format(t, ".17g"), width_px, height_px])
                    kwargs = {
                        "source": bgr, "persist": True, "tracker": tracker,
                        "conf": confidence, "iou": iou, "verbose": False,
                    }
                    if device is not None:
                        kwargs["device"] = device
                    if class_filter is not None:
                        kwargs["classes"] = class_filter
                    result = model.track(**kwargs)
                    if len(result) != 1:
                        raise RuntimeError(
                            "Expected one Ultralytics result per decoded video frame")
                    observations, ignored = _extract_tracked_boxes(result[0])
                    rows, labels = mot_rows(
                        observations, n_frames, width_px, height_px)
                    for _, track_id, class_id in labels:
                        old_class = track_classes.get(track_id)
                        if old_class is not None and old_class != class_id:
                            raise ValueError(
                                "Track class changed within one camera-local identity")
                        track_classes[track_id] = class_id
                    mwriter.writerows(rows)
                    cwriter.writerows(labels)
                    n_frames += 1
                    n_tracked += len(rows)
                    n_unassigned += ignored
        if n_frames == 0:
            raise ValueError("No decodable video frames")
        # SHA-256 protects the R side from accidental/mismatched files,
        # although it is not an authenticated chain of custody.
        file_sha256 = {
            part: sha256_file(tmpdir / names[part])
            for part in ("frames", "mot", "classes")
        }
        manifest = {
            "schema_version": "1.1",
            "session_id": session_id,
            "camera_id": camera_id,
            "video_sha256": sha256_file(video),
            "weights_sha256": sha256_file(weights),
            "video_path": str(video.resolve()),
            "weights_path": str(weights.resolve()),
            "video_decoder": "PyAV",
            "time_source": "decoded_video_frame_pts_from_same_buffer_as_model_input",
            "first_raw_pts_s": origin,
            "time_s_relative_to_first_frame": True,
            "frame_origin_in_mot": 1,
            "ultralytics_version": getattr(ultralytics, "__version__", "unknown"),
            "pyav_version": getattr(av, "__version__", "unknown"),
            "tracker_config": tracker,
            "detection_confidence_threshold": confidence,
            "detection_iou_parameter": iou,
            "class_filter": class_filter,
            "n_decoded_frames": n_frames,
            "n_tracked_box_rows": n_tracked,
            "n_unassigned_detector_boxes_skipped": n_unassigned,
            "fish_model_training_audited": False,
            "fish_identity_accuracy_certified": False,
            "hardware_exposure_synchronization_certified": False,
            "underwater_3d_calibration_certified": False,
            "outputs": names,
            "output_sha256": file_sha256,
            "output_bundle_integrity": "unkeyed_sha256_not_signed",
        }
        with (tmpdir / names["metadata"]).open("w", encoding="utf-8") as fh:
            json.dump(manifest, fh, indent=2, sort_keys=True)
            fh.write("\n")
        # No published outputs until the whole video decode/model run succeeded.
        for name in names.values():
            os.replace(tmpdir / name, output_dir / name)
        return manifest
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--video", type=Path, required=True)
    parser.add_argument("--weights", type=Path, required=True,
                        help="User-supplied fish-specific YOLO weights; unvalidated here")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--session-id", required=True)
    parser.add_argument("--camera-id", required=True)
    parser.add_argument("--confidence", type=float, default=0.25)
    parser.add_argument("--iou", type=float, default=0.7)
    parser.add_argument("--device", default=None)
    parser.add_argument("--classes", type=int, nargs="*", default=None)
    args = parser.parse_args(argv)
    metadata = run_video(
        args.video, args.weights, args.output_dir, args.prefix,
        args.session_id, args.camera_id, args.confidence, args.iou,
        device=args.device, class_filter=args.classes)
    print(json.dumps({
        "outputs": metadata["outputs"],
        "n_decoded_frames": metadata["n_decoded_frames"],
        "n_tracked_box_rows": metadata["n_tracked_box_rows"],
        "n_unassigned_detector_boxes_skipped":
            metadata["n_unassigned_detector_boxes_skipped"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

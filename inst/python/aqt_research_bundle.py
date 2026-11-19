#!/usr/bin/env python3
"""AquaTrajectories Research Bundle v1: loss-audited tracking interchange.

External tools own detection/identity. This module NEVER estimates fish IDs,
timestamps, camera geometry, or physical coordinates. Stdlib-only converter.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import shutil
import tempfile
from pathlib import Path

VERSION = "1.0.0"
FRAME_COLUMNS = ["session_id", "camera_id", "frame_id", "time_s", "width_px", "height_px"]
OBS_COLUMNS = [
    "session_id", "camera_id", "track_id", "frame_id", "time_s",
    "x", "y", "observed", "quality_flag", "position_definition",
    "bbox_left", "bbox_top", "bbox_width", "bbox_height",
    "detection_confidence", "identity_probability", "source_row",
]
KINDS = ("mot_bytetrack", "mot_botsort", "idtracker_tidy", "yolo_csv")
TIME_STATUS = ("source_pts", "externally_verified", "unverified", "unknown")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for block in iter(lambda: f.read(1048576), b""):
            h.update(block)
    return h.hexdigest()


def text_id(value, name):
    require(isinstance(value, str) and bool(value.strip()) and
            not any(c in value for c in ("\n", "\r", "\0")), name + " must be a valid nonempty string")
    return value


def integer(value, name, minimum=0):
    require(value is not None and str(value).strip() != "", name + " is required")
    try:
        n = int(str(value))
    except (ValueError, TypeError):
        raise ValueError(name + " must be an integer") from None
    require(str(n) == str(value).strip() or
            (isinstance(value, str) and value.strip().lstrip("0") == str(n)),
            name + " must not be fractional")
    require(n >= minimum, name + " is below minimum")
    return n


def number(value, name, nullable=False):
    if value is None or str(value).strip() == "" or (nullable and str(value).strip().lower() == "nan"):
        require(nullable, name + " is missing")
        return None
    try:
        v = float(value)
    except (ValueError, TypeError):
        raise ValueError(name + " must be numeric") from None
    require(math.isfinite(v), name + " must be finite")
    return v


def fmt(v):
    return "" if v is None else format(v, ".17g")


def read_frames(path, session_id, camera_id, time_status):
    records, frame_map = [], {}
    with Path(path).open(newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        require(reader.fieldnames == FRAME_COLUMNS,
                "Frame CSV must have EXACT columns: " + ",".join(FRAME_COLUMNS))
        last_f, last_t = -1, None
        for raw in reader:
            require(None not in raw and None not in raw.values(), "Malformed frame CSV row")
            require(raw["session_id"] == session_id and raw["camera_id"] == camera_id,
                    "Frame manifest scope mismatch")
            fid = integer(raw["frame_id"], "frame_id")
            t = number(raw["time_s"], "time_s", nullable=True)
            w = integer(raw["width_px"], "width_px", 1)
            h = integer(raw["height_px"], "height_px", 1)
            require(fid > last_f, "Frame IDs must strictly increase (gaps allowed)")
            if time_status == "unknown":
                require(t is None, "Unknown timing must have blank time_s; never infer FPS")
            else:
                require(t is not None and t >= 0, "Declared timed frames require recorded nonnegative seconds")
                require(last_t is None or t > last_t, "Frame timestamps must strictly increase")
            rec = [session_id, camera_id, str(fid), fmt(t), str(w), str(h)]
            records.append(rec)
            frame_map[fid] = (t, w, h)
            last_f, last_t = fid, t
    require(bool(records), "Frame manifest is empty")
    return records, frame_map


def read_source(kind, path, frame_map, session_id, camera_id, frame_origin):
    seen = set()
    with Path(path).open(newline="", encoding="utf-8-sig") as f:
        if kind.startswith("mot_"):
            require(frame_origin is not None, "MOT frame origin must be declared explicitly")
            reader = csv.reader(f)
            def convert(raw, n):
                require(len(raw) >= 7, "MOT row requires 7 or more columns")
                source_frame = integer(raw[0], "MOT frame", frame_origin)
                fid = source_frame - frame_origin
                track = text_id(raw[1], "MOT track ID")
                left = number(raw[2], "left")
                top = number(raw[3], "top")
                width = number(raw[4], "width")
                height = number(raw[5], "height")
                score = number(raw[6], "MOT score")
                require(0 <= score <= 1, "MOT result score must be within [0,1]")
                require(left >= 0 and top >= 0 and width > 0 and height > 0, "Invalid MOT bounding box")
                return fid, track, left + width/2, top + height/2, (left, top, width, height), score, None, True, "bbox_center", None
        else:
            reader = csv.DictReader(f)
            cols = reader.fieldnames or []
            if kind == "idtracker_tidy":
                require(frame_origin is not None, "idtracker frame origin must be explicitly declared")
                require(all(x in cols for x in ("frame", "time", "individual", "x", "y", "probability")),
                        "idtracker.ai tidy CSV requires frame,time,individual,x,y,probability")
                def convert(raw, n):
                    fid = integer(raw["frame"], "idtracker frame", frame_origin) - frame_origin
                    track = text_id(raw["individual"], "individual")
                    x = number(raw["x"], "idtracker x", nullable=True)
                    y = number(raw["y"], "idtracker y", nullable=True)
                    require((x is None) == (y is None), "Incomplete idtracker XY coordinates")
                    prob = number(raw["probability"], "idtracker identity probability", nullable=True)
                    require(prob is None or 0 <= prob <= 1, "Invalid idtracker identity probability")
                    t = number(raw["time"], "idtracker source time", nullable=True)
                    return fid, track, x, y, None, None, prob, x is not None, "source_xy", t
            elif kind == "yolo_csv":
                require(all(x in cols for x in ("frame_id", "track_id", "x_px", "y_px")),
                        "YOLO CSV requires frame_id,track_id,x_px,y_px")
                def convert(raw, n):
                    fid = integer(raw["frame_id"], "YOLO zero-based frame_id")
                    track = text_id(raw["track_id"], "track_id")
                    x, y = number(raw["x_px"], "x_px"), number(raw["y_px"], "y_px")
                    confidence = number(raw.get("detection_confidence", raw.get("confidence")),
                                        "detection confidence", nullable=True)
                    require(confidence is None or 0 <= confidence <= 1, "Invalid YOLO confidence")
                    box_keys = ["bbox_left", "bbox_top", "bbox_width", "bbox_height"]
                    bbox = tuple(number(raw.get(k), k, nullable=True) for k in box_keys)
                    require(all(v is None for v in bbox) or all(v is not None for v in bbox),
                            "YOLO bounding box must be complete or absent")
                    return fid, track, x, y, None if all(v is None for v in bbox) else bbox, confidence, None, True, "source_xy", None
            else:
                raise ValueError("Unsupported tracking source: " + kind)
        for rownum, raw in enumerate(reader, 1):
            if not raw or (isinstance(raw, list) and all(not s.strip() for s in raw)):
                continue
            require(None not in raw and (not isinstance(raw, dict) or None not in raw.values()),
                    "Malformed tracking row")
            fid, track, x, y, bbox, detconf, idprob, observed, posdef, src_t = convert(raw, rownum)
            require(fid in frame_map, "Source frame has no matching frame-manifest row: " + str(fid))
            t, w, h = frame_map[fid]
            if src_t is not None:
                require(t is not None, "Source contains time but manifest declares unknown time; supply a matching timed manifest")
                require(abs(t - src_t) <= 1e-6, "idtracker time disagrees with frame manifest at frame " + str(fid))
            if observed:
                require(0 <= x <= w and 0 <= y <= h, "Position is outside frame image")
            if bbox is not None:
                left, top, bw, bh = bbox
                require(left >= 0 and top >= 0 and bw > 0 and bh > 0 and
                        left + bw <= w + 1e-7 and top + bh <= h + 1e-7,
                        "Bounding box is outside frame image")
            key = (fid, track)
            require(key not in seen, "Duplicated track identity in same camera/frame: " + repr(key))
            seen.add(key)
            vals = [
                session_id, camera_id, track, str(fid), fmt(t), fmt(x), fmt(y),
                "TRUE" if observed else "FALSE",
                "unreviewed" if observed else "source_missing_position", posdef,
                *(fmt(v) for v in (bbox or (None,)*4)),
                fmt(detconf), fmt(idprob), str(rownum),
            ]
            yield vals


def write_csv(path, columns, rows):
    n = 0
    with Path(path).open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow(columns)
        for row in rows:
            require(len(row) == len(columns), "Internal CSV row width mismatch")
            writer.writerow(row)
            n += 1
    return n


def verify(directory):
    directory = Path(directory)
    meta = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
    require(meta.get("schema_version") == VERSION, "Incompatible research-bundle version")
    require(meta.get("coordinate_units") == "px" and meta.get("coordinate_system") == "image",
            "Invalid spatial units/coordinate system")
    require(meta.get("time_status") in TIME_STATUS, "Invalid time status")
    for name in ("frames.csv", "observations.csv"):
        p = directory / name
        require(p.is_file(), "Missing research-bundle file: " + name)
        require(sha(p) == meta["output_sha256"][name], "SHA-256 mismatch: " + name)
    frames, fm = read_frames(directory / "frames.csv",
                             meta["session_id"], meta["camera_id"], meta["time_status"])
    require(len(frames) == meta["n_frames"], "Frame count mismatch")
    count = 0
    seen = set()
    with (directory / "observations.csv").open(newline="", encoding="utf-8") as f:
        rd = csv.DictReader(f)
        require(rd.fieldnames == OBS_COLUMNS, "Incorrect observation schema")
        for r in rd:
            require(None not in r and None not in r.values(), "Malformed canonical observation row")
            require(r["session_id"] == meta["session_id"] and
                    r["camera_id"] == meta["camera_id"], "Observation scope mismatch")
            fid = integer(r["frame_id"], "frame_id")
            require(fid in fm, "Unknown frame_id")
            ident = text_id(r["track_id"], "track_id")
            require((fid, ident) not in seen, "Duplicate observation identity")
            seen.add((fid, ident))
            t, w, h = fm[fid]
            require(r["time_s"] == fmt(t), "Observation/manifest time differs")
            obs = r["observed"]
            require(obs in ("TRUE", "FALSE"), "Invalid observed flag")
            x = number(r["x"], "x", nullable=True)
            y = number(r["y"], "y", nullable=True)
            require((x is None) == (y is None), "Unpaired XY")
            require((x is not None) == (obs == "TRUE"), "Observed flag contradicts XY")
            if x is not None:
                require(0 <= x <= w and 0 <= y <= h, "Position outside frame")
            box = [number(r[k], k, nullable=True) for k in
                   ("bbox_left", "bbox_top", "bbox_width", "bbox_height")]
            require(all(v is None for v in box) or all(v is not None for v in box),
                    "Incomplete bounding box")
            if box[0] is not None:
                require(box[0] >= 0 and box[1] >= 0 and box[2] > 0 and box[3] > 0 and
                        box[0]+box[2] <= w+1e-7 and box[1]+box[3] <= h+1e-7,
                        "Invalid canonical bounding box")
            for k in ("detection_confidence", "identity_probability"):
                v = number(r[k], k, nullable=True)
                require(v is None or 0 <= v <= 1, "Invalid probability")
            require(r["position_definition"] in ("bbox_center", "source_xy"),
                    "Unrecognized position definition")
            require(r["quality_flag"] in ("unreviewed", "source_missing_position"),
                    "Unsupported QC flag")
            integer(r["source_row"], "source_row", 1)
            count += 1
    require(count == meta["n_observations"], "Observation count mismatch")
    require(meta["fish_identity_accuracy_certified"] is False and
            meta["cross_camera_identity_certified"] is False and
            meta["underwater_calibration_certified"] is False,
            "Bundle must not claim unperformed certification")
    return meta


def create(args):
    require(args.kind in KINDS, "Unsupported tracking source")
    require(args.time_status in TIME_STATUS, "Unsupported time provenance")
    require(args.frame_origin is None or args.frame_origin in (0, 1),
            "Frame origin must be explicitly 0 or 1")
    if args.kind.startswith("mot_") or args.kind == "idtracker_tidy":
        require(args.frame_origin is not None, "Explicit --frame-origin required")
    elif args.frame_origin is not None:
        require(args.frame_origin == 0, "YOLO canonical frame IDs must be zero-based")
    if args.time_status == "externally_verified":
        require(args.clock_evidence is not None and args.clock_evidence.is_file(),
                "External timestamp verification requires --clock-evidence file")
    require(args.source.is_file() and args.frames.is_file(), "Source/frames file missing")
    for opt in ("model", "tracker_config", "clock_evidence"):
        path = getattr(args, opt)
        require(path is None or path.is_file(), "Missing declared input: " + opt)
    session_id = text_id(args.session_id, "session_id")
    camera_id = text_id(args.camera_id, "camera_id")
    frames, frame_map = read_frames(args.frames, session_id, camera_id, args.time_status)
    output = args.out.resolve()
    require(not output.exists(), "Output directory already exists: refusing overwrite")
    require(output.parent.is_dir(), "Output parent directory does not exist")
    tmp = Path(tempfile.mkdtemp(prefix=".aqt-research-v1-", dir=output.parent))
    try:
        write_csv(tmp / "frames.csv", FRAME_COLUMNS, frames)
        n = write_csv(tmp / "observations.csv", OBS_COLUMNS, read_source(
            args.kind, args.source, frame_map, session_id, camera_id, args.frame_origin))
        def evidence(path):
            if path is None:
                return None
            return {"filename": path.name, "sha256": sha(path)}
        metadata = {
            "schema_version": VERSION,
            "session_id": session_id, "camera_id": camera_id,
            "tracking_kind": args.kind, "frame_origin_in_source": args.frame_origin,
            "time_status": args.time_status,
            "time_note": "Exact supplied per-frame seconds, no frame/fps inference; source_pts is a declaration, not independent certification",
            "coordinate_units": "px", "coordinate_system": "image",
            "n_frames": len(frames), "n_observations": n,
            "source_files": {
                "tracking": evidence(args.source), "frame_manifest": evidence(args.frames),
                "model": evidence(args.model), "tracker_config": evidence(args.tracker_config),
                "clock_evidence": evidence(args.clock_evidence),
            },
            "output_sha256": {p: sha(tmp / p) for p in ("frames.csv", "observations.csv")},
            "quality_flag_meaning": "unreviewed is not a verified detection or identity",
            "fish_identity_accuracy_certified": False,
            "cross_camera_identity_certified": False,
            "underwater_calibration_certified": False,
            "sha256_is_authenticated_provenance": False,
        }
        (tmp / "manifest.json").write_text(
            json.dumps(metadata, indent=2, sort_keys=True, allow_nan=False) + "\n",
            encoding="utf-8")
        verify(tmp)
        os.replace(tmp, output)
        return metadata
    finally:
        if tmp.exists():
            shutil.rmtree(tmp)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("create", help="Convert an external tracker output into Research Bundle v1")
    p.add_argument("--kind", choices=KINDS, required=True)
    p.add_argument("--source", required=True, type=Path)
    p.add_argument("--frames", required=True, type=Path, help="Complete per-frame manifest with actual times or blanks")
    p.add_argument("--session-id", required=True)
    p.add_argument("--camera-id", required=True)
    p.add_argument("--time-status", choices=TIME_STATUS, required=True)
    p.add_argument("--frame-origin", type=int, default=None)
    p.add_argument("--model", type=Path)
    p.add_argument("--tracker-config", type=Path)
    p.add_argument("--clock-evidence", type=Path)
    p.add_argument("--out", required=True, type=Path)
    q = sub.add_parser("verify", help="Check emitted bytes and canonical contracts")
    q.add_argument("--directory", required=True, type=Path)
    args = parser.parse_args(argv)
    result = create(args) if args.command == "create" else verify(args.directory)
    print(json.dumps({"status": "PASS", "schema_version": result["schema_version"],
                      "tracking_kind": result["tracking_kind"],
                      "n_observations": result["n_observations"],
                      "time_status": result["time_status"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

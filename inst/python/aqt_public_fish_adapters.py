"""Conservative conversion of published fish annotations to AquaTrajectories.

Supports Datumaro JSON/ZIP (bbox, polygon and track_id) and MOTChallenge
ground-truth gt.txt + seqinfo.ini. No fish predictions or PTS invented.
Source human annotation must be reviewed before independent scoring.
"""
from __future__ import annotations
import argparse
import configparser
import csv
import hashlib
import json
import math
from pathlib import Path
import re
import zipfile


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def positive(v, name):
    if isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v) or v <= 0:
        raise ValueError(f"{name} must be finite positive")
    return float(v)


def identifier(v, name):
    if v is None or isinstance(v, bool) or str(v).strip() == "":
        raise ValueError(f"{name} missing")
    return str(v)


def read_datumaro_json(path):
    path = Path(path)
    if path.suffix.lower() == ".zip":
        with zipfile.ZipFile(path) as z:
            names = [x for x in z.namelist() if re.fullmatch(
                r"(?:[^/]+/)?annotations/[^/]+\.json", x)]
            if len(names) != 1:
                raise ValueError("Datumaro ZIP must have exactly one annotations/*.json")
            info = z.getinfo(names[0])
            if info.file_size > 80_000_000 or info.compress_size == 0:
                raise ValueError("Oversized or unsupported annotation archive")
            obj = json.loads(z.read(names[0]).decode("utf-8"))
    else:
        if not path.is_file() or path.stat().st_size > 80_000_000:
            raise ValueError("Missing/oversized Datumaro JSON")
        obj = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(obj, dict) or not isinstance(obj.get("items"), list):
        raise ValueError("Datumaro requires items list")
    return obj


def frame_number(item, origin, frame_map):
    name = identifier(item.get("id"), "Datumaro image id")
    if frame_map is not None:
        if name not in frame_map:
            raise ValueError("Image absent from explicit frame map")
        frame = frame_map[name]
    else:
        stem = Path(name).stem
        match = re.search(r"(?:^|[_-])(\d+)$", stem)
        if match is None:
            if stem.isdecimal():
                frame = int(stem)
            else:
                raise ValueError("Ambiguous frame ID; provide --frame-map")
        else:
            frame = int(match.group(1))
    if not isinstance(frame, int) or isinstance(frame, bool) or frame < origin:
        raise ValueError("Frame ID precedes source frame origin")
    return frame - origin


def load_frame_map(path):
    if path is None:
        return None
    mapping = {}
    with Path(path).open(newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames != ["item_id", "source_frame_id"]:
            raise ValueError("Frame map requires item_id,source_frame_id")
        for row in reader:
            name = identifier(row["item_id"], "item_id")
            if name in mapping:
                raise ValueError("Repeated image in frame map")
            try:
                number = int(row["source_frame_id"])
            except ValueError as e:
                raise ValueError("Noninteger source frame") from e
            mapping[name] = number
    return mapping


def geometry(data, width, height):
    if not isinstance(data, (list, tuple)) or len(data) != 4:
        raise ValueError("Bounding box must be [left,top,width,height]")
    left, top, w, h = data
    for name, v in (("left", left), ("top", top)):
        if not isinstance(v, (float, int)) or not math.isfinite(v):
            raise ValueError(f"Invalid box {name}")
    positive(w, "box width")
    positive(h, "box height")
    x2, y2 = left + w, top + h
    if left < -1e-6 or top < -1e-6 or x2 > width + 1e-6 or y2 > height + 1e-6:
        raise ValueError("Box outside declared image dimensions")
    return (float(left), float(top), float(x2), float(y2))


def convert_datumaro(path, session, camera, origin, width, height, frame_map=None):
    session = identifier(session, "session_id")
    camera = identifier(camera, "camera_id")
    positive(width, "image width")
    positive(height, "image height")
    if not isinstance(origin, int) or isinstance(origin, bool) or origin < 0:
        raise ValueError("origin must be nonnegative integer")
    obj = read_datumaro_json(path)
    labels = (((obj.get("categories") or {}).get("label") or {}).get("labels") or [])
    frames, boxes, tracks, issues = [], [], [], []
    seen, per_frame_track = set(), set()
    for item in obj["items"]:
        if not isinstance(item, dict):
            raise ValueError("Datumaro item must be object")
        frame = frame_number(item, origin, frame_map)
        if frame in seen:
            raise ValueError("Duplicate Datumaro frame index")
        seen.add(frame)
        frames.append({"session_id": session, "camera_id": camera,
                       "frame_id": frame, "width_px": int(width),
                       "height_px": int(height), "source_item_id": str(item["id"]),
                       "annotation_status": "published_annotation_unreviewed"})
        anns = item.get("annotations", [])
        if not isinstance(anns, list):
            raise ValueError("Datumaro annotations must be list")
        objects = {}
        for j, ann in enumerate(anns):
            if not isinstance(ann, dict):
                raise ValueError("Datumaro annotation must be object")
            typ, attrs = ann.get("type"), ann.get("attributes") or {}
            if not isinstance(attrs, dict):
                raise ValueError("Malformed annotation attributes")
            if typ not in ("bbox", "polygon", "mask"):
                issues.append({"frame_id": frame, "reason": "unsupported_annotation_type",
                               "annotation_index": j})
                continue
            if attrs.get("ignored") or attrs.get("ignore") or attrs.get("outside"):
                issues.append({"frame_id": frame,
                               "reason": "ignore_or_outside_requires_review",
                               "annotation_index": j})
                continue
            class_num = ann.get("label_id")
            if not isinstance(class_num, int) or isinstance(class_num, bool) or class_num < 0 or class_num >= len(labels):
                raise ValueError("Unknown Datumaro class label_id")
            cl = identifier(labels[class_num].get("name"), "class label")
            tid = attrs.get("track_id")
            if tid is not None:
                tid = identifier(tid, "track_id")
            group = ann.get("group")
            if tid is not None:
                group_key = ("track", cl, tid)
            elif isinstance(group, int) and group > 0:
                group_key = ("group", cl, str(group))
            else:
                group_key = ("annotation", str(j))
            if typ == "bbox":
                rect = ann.get("bbox")
            elif typ == "polygon":
                pts = ann.get("points")
                if (not isinstance(pts, list) or len(pts) < 6 or len(pts) % 2 or
                        not all(isinstance(p, (int, float)) and math.isfinite(p) for p in pts)):
                    raise ValueError("Invalid Datumaro polygon points")
                xs, ys = pts[::2], pts[1::2]
                rect = [min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)]
            else:
                issues.append({"frame_id": frame,
                               "reason": "RLE_mask_without_bbox_requires_conversion",
                               "annotation_index": j})
                continue
            xyxy = geometry(rect, width, height)
            if group_key in objects:
                old = objects[group_key]
                if old["tid"] != tid:
                    raise ValueError("Inconsistent grouped identity")
                if typ == "bbox":
                    old.update(xyxy=xyxy, preferred="bbox")
            else:
                objects[group_key] = dict(xyxy=xyxy, tid=tid,
                                          preferred=typ, cl=cl)
        for row in objects.values():
            xmin, ymin, xmax, ymax = row["xyxy"]
            cl, tid = row["cl"], row["tid"]
            boxes.append({"session_id": session, "camera_id": camera,
                          "frame_id": frame, "class_id": cl,
                          "xmin": xmin, "ymin": ymin, "xmax": xmax, "ymax": ymax})
            if tid is not None:
                pair = (frame, cl, tid)
                if pair in per_frame_track:
                    raise ValueError("Duplicate fish identity in one frame")
                per_frame_track.add(pair)
                tracks.append({"session_id": session, "camera_id": camera,
                               "frame_id": frame, "track_id": tid,
                               "x": (xmin + xmax) / 2, "y": (ymin + ymax) / 2,
                               "class_id": cl})
    if not frames:
        raise ValueError("No annotated Datumaro frames")
    return dict(frames=frames, boxes=boxes, tracks=tracks,
                issues=issues, source_format="datumaro_json")


def convert_mot(gt, seqinfo, session, camera):
    session = identifier(session, "session_id")
    camera = identifier(camera, "camera_id")
    cfg = configparser.ConfigParser()
    cfg.read(Path(seqinfo), encoding="utf-8")
    if not cfg.has_section("Sequence"):
        raise ValueError("MOT seqinfo.ini missing [Sequence]")
    try:
        n = int(cfg.get("Sequence", "seqLength"))
        w = int(cfg.get("Sequence", "imWidth"))
        h = int(cfg.get("Sequence", "imHeight"))
    except (ValueError, configparser.Error) as e:
        raise ValueError("MOT sequence size/length invalid") from e
    if n < 1 or w < 1 or h < 1:
        raise ValueError("MOT sequence dimensions and frames must be positive")
    frames = [dict(session_id=session, camera_id=camera, frame_id=i,
                   width_px=w, height_px=h, source_item_id=str(i+1),
                   annotation_status="published_annotation_unreviewed")
              for i in range(n)]
    boxes, tracks, issues, seen = [], [], [], set()
    with Path(gt).open(newline="", encoding="utf-8-sig") as f:
        for rowno, row in enumerate(csv.reader(f), 1):
            if not row:
                continue
            if len(row) not in (9, 10):
                raise ValueError(f"MOT ground truth row {rowno} must have 9 or 10 fields")
            try:
                frame, tid = int(row[0]), int(row[1])
                x, y, bw, bh = (float(q) for q in row[2:6])
                valid, cl, visibility = float(row[6]), int(row[7]), float(row[8])
            except (ValueError, TypeError) as e:
                raise ValueError("Invalid MOT ground-truth row") from e
            if not 1 <= frame <= n:
                raise ValueError("MOT gt frame index not in seqinfo range")
            if not math.isfinite(valid) or not 0 <= visibility <= 1:
                raise ValueError("Invalid MOT inclusion flag or visibility")
            if tid < 0 or valid == 0:
                issues.append({"frame_id": frame-1,
                               "reason": "mot_ignored_or_unassigned_ground_truth",
                               "annotation_index": rowno})
                continue
            xmin, ymin, xmax, ymax = geometry([x, y, bw, bh], w, h)
            key = (frame, tid)
            if key in seen:
                raise ValueError("Repeated MOT fish track in same frame")
            seen.add(key)
            boxes.append(dict(session_id=session, camera_id=camera,
                              frame_id=frame-1, class_id=str(cl),
                              xmin=xmin, ymin=ymin, xmax=xmax, ymax=ymax))
            tracks.append(dict(session_id=session, camera_id=camera,
                               frame_id=frame-1, track_id=str(tid),
                               x=(xmin+xmax)/2, y=(ymin+ymax)/2,
                               class_id=str(cl)))
    return dict(frames=frames, boxes=boxes, tracks=tracks,
                issues=issues, source_format="mot_gt")


def save_dataset(dataset, output, source_paths):
    dest = Path(output)
    dest.mkdir(parents=True, exist_ok=True)
    if any(dest.iterdir()):
        raise FileExistsError("Refuse nonempty benchmark export destination")
    columns = {
        "frames": ["session_id","camera_id","frame_id","width_px",
                   "height_px","source_item_id","annotation_status"],
        "boxes": ["session_id","camera_id","frame_id","class_id",
                  "xmin","ymin","xmax","ymax"],
        "tracks": ["session_id","camera_id","frame_id","track_id",
                   "x","y","class_id"],
        "issues": ["frame_id","reason","annotation_index"]
    }
    flagged_frames = {x["frame_id"] for x in dataset["issues"]}
    for row in dataset["frames"]:
        if row["frame_id"] in flagged_frames:
            row["annotation_status"] = "requires_ignore_mask_or_adjudication"
    written = {}
    for name, fields in columns.items():
        target = dest / (name + ".csv")
        with target.open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fields)
            writer.writeheader()
            writer.writerows(dataset[name])
        written[name] = target
    report = {
        "schema_version": "1.0",
        "source_format": dataset["source_format"],
        "n_annotated_frames": len(dataset["frames"]),
        "n_boxes": len(dataset["boxes"]),
        "n_track_rows": len(dataset["tracks"]),
        "n_unresolved_annotations": len(dataset["issues"]),
        "source_files_sha256": {Path(p).name: digest(p) for p in source_paths},
        "output_files_sha256": {key: digest(val) for key,val in written.items()},
        "source_human_annotation_independently_reverified": False,
        "real_image_pts_verified": False,
        "absolute_xyz_accuracy_certified": False,
        "note": "Independent annotation scope, masks and human review required before scoring"
    }
    (dest / "audit.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8")
    return report


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--format", choices=("datumaro","mot"), required=True)
    ap.add_argument("--input", type=Path, required=True)
    ap.add_argument("--seqinfo", type=Path)
    ap.add_argument("--session-id", required=True)
    ap.add_argument("--camera-id", required=True)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--source-frame-origin", type=int)
    ap.add_argument("--frame-map", type=Path)
    ap.add_argument("--width", type=int)
    ap.add_argument("--height", type=int)
    a = ap.parse_args(argv)
    if a.format == "datumaro":
        if a.source_frame_origin is None or not a.width or not a.height:
            ap.error("Datumaro requires explicit --source-frame-origin --width --height")
        data = convert_datumaro(
            a.input, a.session_id, a.camera_id, a.source_frame_origin,
            a.width, a.height, load_frame_map(a.frame_map))
        inputs = [a.input] + ([a.frame_map] if a.frame_map else [])
    else:
        if a.seqinfo is None:
            ap.error("MOT requires --seqinfo with all acquired frame counts")
        data = convert_mot(a.input, a.seqinfo, a.session_id, a.camera_id)
        inputs = [a.input, a.seqinfo]
    print(json.dumps(save_dataset(data, a.output, inputs), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

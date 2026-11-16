#!/usr/bin/env python3
"""Convert original DIGI4ECO CVAT 1.1 track annotations with real source PTS.
No fish-detector predictions, independent identity adjudication, 3D truth, or
physical synchronization is inferred. Source video is not copied or uploaded.
External source: DOI 10.5281/zenodo.20701225, CC BY 4.0.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as src:
        for part in iter(lambda: src.read(1024 * 1024), b""):
            h.update(part)
    return h.hexdigest()


def xml_data(path):
    if path.stat().st_size > 100 * 1024 * 1024:
        raise ValueError("Annotation XML is larger than 100 MB")
    with path.open("rb") as stream:
        head = stream.read(8192)
    if b"<!DOCTYPE" in head.upper() or b"<!ENTITY" in head.upper():
        raise ValueError("DTD and entity declarations are refused")
    root = ET.parse(path).getroot()
    if root.tag != "annotations":
        raise ValueError("Expected original CVAT annotations root")
    w = root.findtext("./meta/task/original_size/width")
    h = root.findtext("./meta/task/original_size/height")
    if not w or not h:
        raise ValueError("Original CVAT video width/height absent")
    width, height = int(w), int(h)
    if width <= 0 or height <= 0:
        raise ValueError("Invalid source dimensions")
    return root, width, height


def read_pts(path):
    times = []
    with path.open(newline="", encoding="utf-8-sig") as stream:
        for row in csv.reader(stream):
            if not row or not any(cell.strip() for cell in row):
                continue
            if len(row) != 1:
                raise ValueError("Expected exactly one raw PTS float per decoded frame")
            val = float(row[0])
            if val < 0 or not (-1e15 < val < 1e15):
                raise ValueError("Source PTS is invalid")
            if times and val <= times[-1]:
                raise ValueError("Decoded frame PTS must strictly increase")
            times.append(val)
            if len(times) > 200000:
                raise ValueError("Video exceeds explicit 200,000 frame cap")
    if not times:
        raise ValueError("PTS contains no frames")
    return times


def write_rows(path, columns, rows):
    with path.open("w", newline="", encoding="utf-8") as dest:
        writer = csv.DictWriter(dest, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def convert(annotation_path, video_path, pts_path, output, session, camera):
    root, width, height = xml_data(annotation_path)
    pts = read_pts(pts_path)
    if not video_path.is_file() or video_path.stat().st_size == 0:
        raise ValueError("Original video is missing or empty")
    if not session or not camera or any(c in session + camera for c in "\r\n,"):
        raise ValueError("Session/camera IDs must be nonempty and contain no commas")
    output.mkdir(parents=True, exist_ok=True)
    first = pts[0]
    frame_rows = [
        dict(session_id=session, camera_id=camera, frame_id=i,
             time_s=format(t-first, ".12g"), raw_time_s=format(t, ".12g"),
             width_px=width, height_px=height)
        for i, t in enumerate(pts)
    ]
    tracks, reference = [], []
    fish_ids = set()
    count_occluded = count_outside = 0
    for track in root.findall("track"):
        track_id = track.attrib.get("id")
        if not track_id or track_id in fish_ids:
            raise ValueError("Duplicate or empty original track ID")
        fish_ids.add(track_id)
        label = track.attrib.get("label", "")
        for box in track.findall("box"):
            frame = int(box.attrib["frame"])
            if frame < 0 or frame >= len(pts):
                raise ValueError("CVAT box frame outside supplied source PTS")
            outside = box.attrib.get("outside", "0") == "1"
            occluded = box.attrib.get("occluded", "0") == "1"
            coords = [float(box.attrib[k]) for k in ("xtl","ytl","xbr","ybr")]
            x1, y1, x2, y2 = coords
            if not all(-1e8 < v < 1e8 for v in coords) or x2 < x1 or y2 < y1:
                raise ValueError("Invalid source annotation box coordinates")
            count_occluded += int(occluded)
            count_outside += int(outside)
            tm = format(pts[frame]-first, ".12g")
            tracks.append(dict(session_id=session,camera_id=camera,
                track_id=track_id,time_s=tm,
                x="" if outside else format((x1+x2)/2,".12g"),
                y="" if outside else format((y1+y2)/2,".12g"),
                observed="FALSE" if outside else "TRUE",
                source_frame_id=frame,original_occluded=str(occluded).upper(),
                original_outside=str(outside).upper()))
            # Original annotation truth is not a detector prediction.
            reference.append(dict(session_id=session,camera_id=camera,
                source_frame_id=frame,track_id=track_id,label=label,
                xtl=x1,ytl=y1,xbr=x2,ybr=y2,original_occluded=str(occluded).upper(),
                original_outside=str(outside).upper(),
                provenance="Original source-author CVAT annotation; not AquaTrajectories prediction"))
    if not reference:
        raise ValueError("No source CVAT tracking boxes found")
    tracks.sort(key=lambda r:(r["session_id"],r["camera_id"],r["track_id"],float(r["time_s"])))
    scoped = [(x["track_id"],x["time_s"]) for x in tracks]
    if len(set(scoped)) != len(scoped):
        raise ValueError("Source CVAT contains repeated fish/time assignment")
    write_rows(output/"source_frames.csv",
       ["session_id","camera_id","frame_id","time_s","raw_time_s","width_px","height_px"],frame_rows)
    write_rows(output/"source_2d_tracks.csv",
       ["session_id","camera_id","track_id","time_s","x","y","observed",
        "source_frame_id","original_occluded","original_outside"],tracks)
    write_rows(output/"reviewed_source_boxes.csv",
       ["session_id","camera_id","source_frame_id","track_id","label","xtl","ytl","xbr","ybr",
        "original_occluded","original_outside","provenance"],reference)
    report = {
      "dataset_title":"DIGI4ECO Underwater Fish Tracking Dataset",
      "dataset_doi":"10.5281/zenodo.20701225",
      "source_licence":"CC BY 4.0; attribution to original dataset authors required",
      "source_annotations":"Original CVAT XML 1.1 manual MOT annotations",
      "source_video_name":video_path.name,
      "source_video_sha256":digest(video_path),
      "source_annotation_sha256":digest(annotation_path),
      "source_pts_csv_sha256":digest(pts_path),
      "session_id":session,"camera_id":camera,
      "source_width_px":width,"source_height_px":height,
      "source_frame_count":len(pts),"source_original_track_count":len(fish_ids),
      "original_annotation_box_rows":len(reference),
      "source_occluded_box_rows":count_occluded,
      "source_outside_box_rows":count_outside,
      "timestamps":"Original supplied decoded frame PTS; mapped to session-local time by subtracting first PTS",
      "frame_to_exposure_sync_independently_certified":False,
      "cross_camera_biological_identity_independently_certified":False,
      "physical_underwater_XYZ_truth_independently_surveyed":False,
      "aqt_detector_or_tracker_predictions_created":False,
      "no_source_video_redistributed":True
    }
    (output/"provenance.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    return report


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--video",type=Path,required=True)
    p.add_argument("--annotations",type=Path,required=True)
    p.add_argument("--pts",type=Path,required=True,help="One actual decoded frame presentation timestamp per CSV row")
    p.add_argument("--output",type=Path,required=True)
    p.add_argument("--session",default="DIGI4ECO")
    p.add_argument("--camera",default="CAM1")
    a = p.parse_args()
    print(json.dumps(convert(a.annotations,a.video,a.pts,a.output,a.session,a.camera),indent=2))


if __name__ == "__main__":
    main()

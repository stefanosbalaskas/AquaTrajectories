#!/usr/bin/env python3
"""Inspect original FISHTRAC/VFT five-column normalized detector exports.

Original research:
https://github.com/tmandel/fish-detrac/blob/master/fishtrac/trackers/VFT/detections.csv
Format from upstream converter: 1-based frame, normalized bbox center X/Y,
normalized width/height. No confidence, fish class, ID or camera PTS.

Do not use these predictions as independent detection or identity truth.
Dimensions are optionally supplied, and must be verified against the
matching source video before pixel coordinates are scientifically meaningful.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path


def hash_file(path: Path) -> str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024*1024),b""):
            h.update(block)
    return h.hexdigest()


def parse_fishtrac(path: Path, frame_origin: int=1,
                   image_width: int|None=None, image_height: int|None=None):
    if type(frame_origin) is not int or frame_origin<0:
        raise ValueError("source frame origin must be a nonnegative integer")
    if (image_width is None)!=(image_height is None):
        raise ValueError("Both source image dimensions must be provided together")
    if image_width is not None and (
        type(image_width) is not int or image_width<1 or
        type(image_height) is not int or image_height<1):
        raise ValueError("Image dimensions must be positive integers")
    path=Path(path)
    if not path.is_file() or path.stat().st_size>25_000_000:
        raise ValueError("Missing or oversized FISHTRAC export")
    observations=[]
    frames=set()
    with path.open("r",newline="",encoding="utf-8-sig") as f:
        for line,row in enumerate(csv.reader(f),1):
            if not row:
                continue
            if len(row)!=5:
                raise ValueError(f"Row {line}: expected exactly five fields")
            try:
                frame_num=float(row[0])
                cx,cy,w,h=(float(x) for x in row[1:])
            except ValueError as e:
                raise ValueError(f"Row {line}: nonnumeric detection") from e
            if not (math.isfinite(frame_num) and frame_num.is_integer()
                    and frame_num>=frame_origin):
                raise ValueError(f"Row {line}: invalid source frame number")
            if not all(map(math.isfinite,(cx,cy,w,h))) or not(
                0<w<=1 and 0<h<=1 and
                0<=cx-w/2 and cx+w/2<=1 and
                0<=cy-h/2 and cy+h/2<=1):
                raise ValueError(f"Row {line}: normalized box outside image")
            frame=int(frame_num)-frame_origin
            frames.add(frame)
            x1,y1,x2,y2=cx-w/2,cy-h/2,cx+w/2,cy+h/2
            record={
                "source_frame_id":int(frame_num),
                "frame_id_zero_based":frame,
                "xmin_normalized":x1,"ymin_normalized":y1,
                "xmax_normalized":x2,"ymax_normalized":y2,
            }
            if image_width is not None:
                record.update({
                    "xmin_px":x1*image_width,"ymin_px":y1*image_height,
                    "xmax_px":x2*image_width,"ymax_px":y2*image_height
                })
            observations.append(record)
    if not observations:
        raise ValueError("No detector observations in FISHTRAC file")
    frame_ids=sorted(frames)
    return {
        "file_sha256":hash_file(path),
        "format":"fishtrac_vft_normalized_centre_xywh",
        "n_detection_rows":len(observations),
        "first_source_frame":min(x["source_frame_id"] for x in observations),
        "last_source_frame":max(x["source_frame_id"] for x in observations),
        "n_frames_with_detections":len(frame_ids),
        "unobserved_frame_indices_within_range":
            frame_ids[-1]-frame_ids[0]+1-len(frame_ids),
        "frame_counts_are_acquired_video_counts":False,
        "image_width_provided_externally":image_width,
        "image_height_provided_externally":image_height,
        "coordinates_are_2d_detector_outputs":True,
        "independent_ground_truth_provided":False,
        "individual_fish_ids_provided":False,
        "detector_confidence_provided":False,
        "actual_camera_pts_provided":False,
        "camera_hardware_sync_verified":False,
        "underwater_xyz_certified":False,
        "observations":observations,
    }


def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--input",type=Path,required=True)
    p.add_argument("--frame-origin",type=int,default=1)
    p.add_argument("--image-width",type=int)
    p.add_argument("--image-height",type=int)
    p.add_argument("--output",type=Path)
    args=p.parse_args(argv)
    data=parse_fishtrac(args.input,args.frame_origin,
                        args.image_width,args.image_height)
    result=json.dumps(data,indent=2,sort_keys=True)+"\n"
    if args.output:
        if args.output.exists():
            raise FileExistsError("Will not overwrite prior FISHTRAC audit")
        args.output.write_text(result,encoding="utf-8")
    else:
        print(result,end="")
    return 0


if __name__=="__main__":
    raise SystemExit(main())

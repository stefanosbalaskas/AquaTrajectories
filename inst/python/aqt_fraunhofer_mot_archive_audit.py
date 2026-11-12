#!/usr/bin/env python3
"""Audit genuine Fraunhofer HHI ricefish MOT archives WITHOUT inventing IDs.

Source URL is an original anchor extracted in Wave 14A. Dataset host TLS
certificate is invalid on default Linux trust store: downloader must preserve
TLS-verification failure as a caveat. This source inspection never authorizes
independent scientific validation, official MOT metrics or video timing.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import zipfile

def sha256_file(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda:f.read(1<<20),b""):
            h.update(chunk)
    return h.hexdigest()

def inspect_archive(path, *, sequence, original_url, tls_verified=False):
    if sequence not in ("A","B"):
        raise ValueError("Only original HHI sequences A and B")
    if not Path(path).is_file() or Path(path).stat().st_size>1_200_000_000:
        raise ValueError("Original source MOT archive missing or too large")
    result={"sequence":sequence,"original_source_url":original_url,
            "original_zip_sha256":sha256_file(path),
            "original_zip_bytes":Path(path).stat().st_size,
            "original_download_peer_tls_verified":bool(tls_verified),
            "archive_gt_source_verified":False,
            "original_frames_and_tracks_adjudicated":False,
            "video_fps_and_hardware_timing_verified":False,
            "actual_tracker_predictions_scored":False,
            "official_HOTA_IDF1_measured":False}
    with zipfile.ZipFile(path) as z:
        members=z.infolist()
        if len(members)>30000:
            raise ValueError("Excessive original source archive entries")
        visible=[]
        for m in members:
            p=PurePosixPath(m.filename)
            if (p.is_absolute() or ".." in p.parts or
                "\\" in m.filename or len(m.filename)>320 or
                m.file_size>500_000_000 or
                (m.compress_size>0 and m.file_size>200*m.compress_size)):
                raise ValueError("Unsafe/oversized archive member")
            visible.append({"path":m.filename,"uncompressed_bytes":m.file_size})
        result["archive_members_count"]=len(visible)
        result["first_members"]=visible[:40]
        result["annotation_candidates"]=[
            obj for obj in visible if obj["path"].lower().endswith(
                (".txt",".ini",".json"))][:90]
        result["image_member_count"]=sum(
            x["path"].lower().endswith((".jpg",".jpeg",".png"))
            for x in visible)
        result["video_member_count"]=sum(
            x["path"].lower().endswith((".mp4",".avi",".mov"))
            for x in visible)
        gt_members=[m for m in members if
                    m.filename.lower().endswith("/gt/gt.txt") or
                    m.filename.lower() in ("gt.txt","gt/gt.txt")]
        result["native_gt_candidate_count"]=len(gt_members)
        if len(gt_members)==1 and gt_members[0].file_size < 40_000_000:
            raw=z.read(gt_members[0])
            report={"source_member":gt_members[0].filename,
                    "member_sha256":hashlib.sha256(raw).hexdigest(),
                    "rows":0,"n_unique_track_ids":0,"n_unique_frames":0,
                    "minimum_frame_id":None,"maximum_frame_id":None,
                    "duplicate_frame_and_id":0,
                    "source_confidence_values":{},
                    "bad_numeric_rows":0}
            frame_ids=set()
            track_ids=set()
            keys=set()
            for lineno,row in enumerate(csv.reader(io.StringIO(
                    raw.decode("utf-8-sig"))),1):
                if not row:continue
                report["rows"]+=1
                if len(row)<6:report["bad_numeric_rows"]+=1;continue
                try:
                    frame=int(row[0]);fish_id=int(row[1])
                    dims=tuple(float(x) for x in row[2:6])
                except (TypeError,ValueError):
                    report["bad_numeric_rows"]+=1;continue
                if (frame,fish_id) in keys:
                    report["duplicate_frame_and_id"]+=1
                keys.add((frame,fish_id))
                frame_ids.add(frame);track_ids.add(fish_id)
                if len(row)>=7:
                    c=row[6].strip()
                    report["source_confidence_values"][c]=(
                        report["source_confidence_values"].get(c,0)+1)
            report["n_unique_track_ids"]=len(track_ids)
            report["n_unique_frames"]=len(frame_ids)
            report["minimum_frame_id"]=min(frame_ids) if frame_ids else None
            report["maximum_frame_id"]=max(frame_ids) if frame_ids else None
            result["native_gt"]=report
        else:
            result["gt_parse_limitation"]="Expected one readable /gt/gt.txt; original archive differs"
    return result

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--zip",type=Path,required=True)
    p.add_argument("--sequence",choices=("A","B"),required=True)
    p.add_argument("--source-url",required=True)
    p.add_argument("--out",type=Path,required=True)
    a=p.parse_args(argv)
    if a.out.exists():raise FileExistsError("Cannot overwrite source archive evidence")
    report=inspect_archive(a.zip,sequence=a.sequence,original_url=a.source_url)
    a.out.parent.mkdir(parents=True,exist_ok=True)
    a.out.write_text(json.dumps(report,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps(report,indent=2,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())

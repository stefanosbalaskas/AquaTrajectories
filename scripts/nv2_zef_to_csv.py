#!/usr/bin/env python3
"""Audit original 3D-ZeF MOT labels and export source-linked TOP-VIEW 2D
head-point tracks. No timestamps, calibrated physical XYZ, or inferred IDs.

Input is original public vapaau/3D-ZeF/data/ZebraFish-NN/gt/gt.txt.
The full 19-column annotation specification is in the original README.
Frame index is used ONLY as an ordinal equality key for group geometry.
"""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path

def hash_file(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda:f.read(1<<20),b""):
            h.update(chunk)
    return h.hexdigest()

def convert(path,out_dir,sequence):
    if not sequence.isdigit() or not 1 <= int(sequence) <= 8:
        raise ValueError("Sequence must be 01 through 08")
    sequence=f"{int(sequence):02d}"
    if out_dir.exists():raise FileExistsError("Output directory exists")
    if not path.is_file() or path.stat().st_size>20_000_000:
        raise ValueError("Original label source missing or too large")
    url=("https://huggingface.co/datasets/vapaau/3D-ZeF/resolve/main/"
         f"data/ZebraFish-{sequence}/gt/gt.txt")
    all_rows=[]; seen=set(); excluded=[]
    with path.open("r",encoding="utf-8-sig",newline="") as stream:
        for lineno,cols in enumerate(csv.reader(stream,skipinitialspace=True),1):
            if not cols:continue
            if len(cols)!=19:raise ValueError(f"Expected 19 columns at source line {lineno}")
            try:
                f=float(cols[0]); fid=float(cols[1])
                x=float(cols[5]);y=float(cols[6])
                occlusion=float(cols[11])
            except (ValueError,TypeError) as e:
                raise ValueError(f"Invalid source values at line {lineno}") from e
            if not (math.isfinite(f) and f>=0 and f.is_integer()
                    and math.isfinite(fid) and fid>=0 and fid.is_integer()):
                raise ValueError(f"Invalid frame or identity at {lineno}")
            f=int(f);fid=int(fid)
            if (f,fid) in seen:raise ValueError("Duplicate (frame,id) reference")
            seen.add((f,fid))
            if not(math.isfinite(x) and math.isfinite(y)
                   and x>=0 and y>=0):
                excluded.append({"source_line":lineno,
                                 "reason":"unusable_top_view_head_point"})
                continue
            if not(math.isfinite(occlusion) and occlusion in (0,1)):
                raise ValueError(f"Malformed occlusion flag at {lineno}")
            all_rows.append((f,str(fid),x,y,lineno,occlusion))
    if len(all_rows)<3:raise ValueError("Too few source observations")
    start=min(r[0] for r in all_rows)
    all_rows.sort(key=lambda r:(r[0],r[1]))
    out_dir.mkdir(parents=True)
    csv_path=out_dir/"SOURCE_FRAME_CENTER_TRACKS.csv"
    with csv_path.open("w",encoding="utf-8",newline="") as stream:
        writer=csv.writer(stream)
        writer.writerow(("session_id","camera_id","track_id","frame_id",
            "time_s","x","y","observed","source_row"))
        for f,ident,x,y,line,occ in all_rows:
            writer.writerow((f"3D_ZEF_{sequence}","TOP",ident,f,f-start,
               format(x,".17g"),format(y,".17g"),"TRUE",line))
    tids={r[1] for r in all_rows}; frames={r[0] for r in all_rows}
    meta={
      "schema":"NV2_REAL_MOT_ANNOTATION_SOURCE_V1",
      "dataset":"3D-ZeF20 annotated zebrafish top-view head positions",
      "source_url":url,"sequence":f"ZeF_{sequence}",
      "data_origin":"original_downloaded_annotation_gt_NOT_tracker_predictions",
      "source_type":"MOT_challenge_19_column_3D_ZeF_top_view_2D",
      "source_file_sha256":hash_file(path),
      "source_zip_sha256":None,
      "transport_tls_peer_verified":True,
      "origin_verified_by_independent_frozen_digest":False,
      "native_gt_sha256":hash_file(path),
      "coordinate_units":"px",
      "coordinate_semantics":"original_top_view_annotated_head_xy",
      "clock_status":"ORDINAL_FRAME_PROXY_NOT_SECONDS",
      "physical_seconds_observed":False,
      "independent_true_underwater_XYZ_certified":False,
      "fish_identification_by_independent_biologist":False,
      "max_simultaneous_source_ids":max(sum(r[0]==f for r in all_rows) for f in frames),
      "n_tracks":len(tids),"n_frames":len(frames),
      "n_source_observations":len(all_rows),
      "n_original_annotated_rows":len(seen),
      "n_excluded_unusable_points":len(excluded),
      "min_frame":min(frames),"max_frame":max(frames),
      "csv_sha256":hash_file(csv_path)}
    (out_dir/"SOURCE_PROVENANCE.json").write_text(
        json.dumps(meta,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    if excluded:
        with (out_dir/"EXCLUDED_TOP_VIEW_POINTS.csv").open(
             "w",encoding="utf-8",newline="") as stream:
            writer=csv.DictWriter(stream,fieldnames=["source_line","reason"])
            writer.writeheader();writer.writerows(excluded)
    print("NV2_REAL_ZEF_CONVERT_PASS",meta["sequence"],
      "rows",len(all_rows),"fish_ids",len(tids),
      "frames",len(frames),"simultaneous_max",meta["max_simultaneous_source_ids"])
    return meta

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--gt",type=Path,required=True)
    p.add_argument("--sequence",required=True)
    p.add_argument("--out",type=Path,required=True)
    a=p.parse_args(argv)
    convert(a.gt,a.out,a.sequence)
if __name__=="__main__":main()

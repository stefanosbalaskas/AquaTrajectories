#!/usr/bin/env python3
"""Read-only 3D-ZeF20 / two-GoPro zebrafish benchmark schema probe.

Real research source: https://github.com/mapeAAU/3D-ZeF
Public labels: https://motchallenge.net/data/3DZeF20Lables.zip

The original 3D-ZeF source code reads camera JSON intrinsic K/Distortion,
four aquarium corner correspondences {world:{x,y,z},camera:{x,y}},
and evaluation 'gt.txt' columns frame,id,3d_x,3d_y,3d_z.
These labels may be calibration-derived reconstructions, NOT independently
surveyed true underwater 3D fish positions. Do not report absolute XYZ RMSE
against labels as metrology certification.
"""

from __future__ import annotations
import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path, PurePosixPath
import stat
import zipfile


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024*1024), b""):
            h.update(block)
    return h.hexdigest()


def finite_number(x, what):
    if isinstance(x, bool):
        raise ValueError(f"{what} cannot be a boolean")
    try:
        value = float(x)
    except (TypeError, ValueError) as e:
        raise ValueError(f"{what} is nonnumeric") from e
    if not math.isfinite(value):
        raise ValueError(f"{what} is not finite")
    return value


def inspect_camera_intrinsics(obj: dict):
    if not isinstance(obj, dict) or "K" not in obj or "Distortion" not in obj:
        raise ValueError("3D-ZeF intrinsic JSON needs K and Distortion")
    K = obj["K"]
    if not isinstance(K, list) or len(K)!=3 or any(
            not isinstance(row, list) or len(row)!=3 for row in K):
        raise ValueError("Intrinsic K must be a 3x3 matrix")
    k = [[finite_number(val, "K element") for val in row] for row in K]
    d = obj["Distortion"]
    if isinstance(d, list) and len(d)==1 and isinstance(d[0],list):
        d = d[0]
    if not isinstance(d, list) or len(d) not in (4,5,8):
        raise ValueError("Unexpected lens distortion coefficient count")
    distortion = [finite_number(val,"lens distortion") for val in d]
    if k[0][0]<=0 or k[1][1]<=0 or abs(k[2][2]-1)>1e-6:
        raise ValueError("Invalid focal length or homogeneous K scale")
    return {
        "K": k,"distortion_coefficients": distortion,
        "distortion_model_verified_against_original_video": False,
        "lens_stabilization_crop_verified": False,
        "camera_intrinsic_accuracy_certified": False,
    }


def inspect_camera_world_references(obj: list):
    if not isinstance(obj,list) or len(obj)!=4:
        raise ValueError("Original 3D-ZeF code expects four aquarium corners")
    results=[]
    for point in obj:
        if not isinstance(point,dict) or not all(
                isinstance(point.get(k),dict) for k in ("camera","world")):
            raise ValueError("Corner needs camera and world mappings")
        results.append({
            "image_xy_px": [finite_number(point["camera"].get(k),
                              "corner camera pixel") for k in ("x","y")],
            "world_xyz_cm": [finite_number(point["world"].get(k),
                              "corner world coordinate") for k in ("x","y","z")]
        })
    if len({tuple(x["world_xyz_cm"]) for x in results}) !=4:
        raise ValueError("Four world reference corners must be distinct")
    if len({tuple(x["image_xy_px"]) for x in results}) !=4:
        raise ValueError("Four projected reference corners must be distinct")
    return {
        "reference_count":4,"references":results,
        "world_coordinate_unit_from_original_source":"cm",
        "references_are_fitted_calibration_inputs":True,
        "independent_target_holdouts_provided":False,
        "real_xyz_fish_accuracy_certified":False,
    }


def inspect_zef_gt_csv(text: str, *, max_rows=1_000_000):
    """Read first five original ZF3D motmetrics GT fields without FPS guessing.

    Verified against mapeAAU/3D-ZeF/modules/evaluation/MOT_evaluation.py:
    pandas.read_csv(gt_csv,header=None,usecols=[0,1,2,3,4],
                    names=['frame','id','3d_x','3d_y','3d_z']).
    """
    rows=csv.reader(io.StringIO(text))
    seen=set()
    count=0;frames=set();ids=set();sample=[]
    for line_no,row in enumerate(rows,1):
        if not row:
            continue
        if len(row)<5:
            raise ValueError("3D-ZeF GT row requires five columns")
        frame=finite_number(row[0],"frame")
        track=finite_number(row[1],"fish track ID")
        if frame!=int(frame) or frame<1:
            raise ValueError("3D-ZeF GT frames must be 1-based integers")
        if track!=int(track) or track<1:
            raise ValueError("3D-ZeF identity must be positive integer")
        xyz=[finite_number(z,k) for z,k in zip(
            row[2:5],("3d_x","3d_y","3d_z"))]
        key=(int(frame),int(track))
        if key in seen:
            raise ValueError("Repeated fish identity within one frame")
        seen.add(key);frames.add(int(frame));ids.add(int(track))
        count+=1
        if count>max_rows:
            raise ValueError("3D-ZeF label count exceeds inspection cap")
        if len(sample)<3:
            sample.append(dict(frame=int(frame),track_id=int(track),
                               reconstructed_xyz=xyz))
    if count==0:
        raise ValueError("Empty 3D-ZeF GT cannot certify dataset")
    return {
        "n_observations":count, "n_distinct_frames_with_fish":len(frames),
        "n_distinct_fish_ids":len(ids),
        "min_source_frame":min(frames),"max_source_frame":max(frames),
        "sample_rows":sample,
        "fields":["frame","id","3d_x","3d_y","3d_z"],
        "source_frame_origin":1,
        "dataset_3d_coordinates_are_original_tracking_labels":True,
        "independent_physical_xyz_survey_certified":False,
        "fish_welfare_or_stress_certified":False
    }


def inspect_labels_zip(path: Path):
    """Inspect zip contents without extraction and use any native 3D GT files."""
    if not path.is_file():
        raise FileNotFoundError("3D-ZeF label zip missing")
    entries=[];gts=[]
    with zipfile.ZipFile(path) as z:
        members=z.infolist()
        total=sum(x.file_size for x in members)
        if len(members)>25000 or total>400*1024*1024:
            raise ValueError("Label archive outside safe inspection bounds")
        for member in members:
            name=member.filename
            pp=PurePosixPath(name)
            if (pp.is_absolute() or ".." in pp.parts or "\\" in name or
                    name.startswith("/") or "\0" in name):
                raise ValueError("Archive contains unsafe path")
            mode=(member.external_attr>>16)&0xFFFF
            if stat.S_ISLNK(mode):
                raise ValueError("Symlink extraction target is not permitted")
            entries.append(dict(path=name,size_bytes=member.file_size,
                               is_directory=member.is_dir()))
            if not member.is_dir() and pp.name.lower()=="gt.txt" and (
                    "gt" in pp.parts or "gt" in pp.parent.name.lower()):
                if member.file_size>25_000_000:
                    raise ValueError("Oversized source GT")
                raw=z.read(member)
                gts.append(dict(path=name,inspection=inspect_zef_gt_csv(
                    raw.decode("utf-8-sig"))))
    return {
        "archive_sha256":file_sha256(path),
        "members":entries,
        "native_mot_3d_gt_inspections":gts,
        "n_member_files":sum(not x["is_directory"] for x in entries),
        "independent_real_underwater_xyz_certified":False,
        "raw_videos_and_hardware_sync_externally_required":True,
    }


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--labels-zip",type=Path)
    parser.add_argument("--intrinsic-json",type=Path)
    parser.add_argument("--references-json",type=Path)
    parser.add_argument("--out",type=Path)
    args=parser.parse_args(argv)
    if not any((args.labels_zip,args.intrinsic_json,args.references_json)):
        parser.error("Provide at least one archive/calibration source")
    report={"schema_version":"1.0",
            "dataset":"3D-ZeF20",
            "origin":"public two-GoPro glass-tank fish benchmark",
            "physical_accuracy_certified":False,
            "benchmark_calibration_vs_heldout_targets_independent":False}
    for path,target,fn in (
        (args.labels_zip,"labels_archive",inspect_labels_zip),
        (args.intrinsic_json,"intrinsics",inspect_camera_intrinsics),
        (args.references_json,"aquarium_references",
            inspect_camera_world_references)):
        if path is None:
            continue
        value=fn(path) if target=="labels_archive" else fn(json.loads(
            path.read_text(encoding="utf-8")))
        report[target]=value
        report[target+"_input_sha256"]=file_sha256(path)
    contents=json.dumps(report,indent=2,sort_keys=True)+"\n"
    if args.out:
        args.out.write_text(contents,encoding="utf-8")
    else:
        print(contents,end="")
    return 0


if __name__=="__main__":
    raise SystemExit(main())

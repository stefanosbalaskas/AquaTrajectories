#!/usr/bin/env python3
"""Audit original external AquaCal real aquarium ChArUco target evidence.

This is NOT an AquaTrajectories underwater calibration run. We independently
check source bytes and published real-rig numerical consistency, *without*
inventing original 3D point observations or asserting independent validation
of the AquaTrajectories reconstruction algorithm.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path

SOURCE_REPO="https://github.com/McGrathLab/AquaCal"
SOURCE_COMMIT="1ed009687ffe9d5e82f0ee8a613bc1355d455ecd"
ORIGINAL_BLOBS={
    "real_rig_metrics.json":"645ce20043966394dec779052a8ef27fb31697b1",
    "benchmark.json":"bc98aad6ea59320e54e9cc451a9e2f8be58092e3"
}

def git_blob(path):
    p=Path(path)
    n=p.stat().st_size
    with p.open("rb") as f:
        h=hashlib.sha1(b"blob "+str(n).encode()+b"\0")
        for chunk in iter(lambda:f.read(1<<20),b""):
            h.update(chunk)
    return h.hexdigest()

def sha256(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda:f.read(1<<20),b""):
            h.update(chunk)
    return h.hexdigest()

def number(o,key):
    v=o.get(key)
    if type(v) not in (float,int) or not math.isfinite(v):
        raise ValueError("Missing nonfinite or unsupported physical metric: "+key)
    return float(v)

def audit(real_metrics,benchmark):
    m=json.loads(Path(real_metrics).read_text())
    b=json.loads(Path(benchmark).read_text())
    if git_blob(real_metrics)!=ORIGINAL_BLOBS["real_rig_metrics.json"]:
        raise ValueError("Original real aquarium physical metric Git blob mismatch")
    if git_blob(benchmark)!=ORIGINAL_BLOBS["benchmark.json"]:
        raise ValueError("Original calibration benchmark Git blob mismatch")
    n=m["n_comparisons"]
    if type(n) is not int or n<100:
        raise ValueError("Insufficient original physical source comparison count")
    mae_mm=number(m,"inter_corner_mae_mm")
    rmse_mm=number(m,"inter_corner_rmse_mm")
    relative_pct=number(m,"mean_relative_error_pct")
    if not (0<=mae_mm<=rmse_mm and 0<=relative_pct):
        raise ValueError("Invalid physical length error bounds")
    # Published target: 60 mm inter-corner ChArUco board segment.
    spacing=60.
    if abs(mae_mm/spacing*100-relative_pct)>1e-7:
        raise ValueError("Published physical board length and relative MAE disagree")
    a=b.get("accuracy")
    if not isinstance(a,dict):
        raise ValueError("Original benchmark lacks physical accuracy block")
    mean_m=number(a,"validation_3d_error_mean")
    std_m=number(a,"validation_3d_error_std")
    if abs(mean_m*1000-mae_mm)>1e-8:
        raise ValueError("Source 3D mean error and target MAE disagree")
    # Moment identity: RMSE² = mean² + population variance.
    reconstruct_rmse_mm=math.hypot(mean_m,std_m)*1000
    if abs(reconstruct_rmse_mm-rmse_mm)>1e-8:
        raise ValueError("Source RMSE differs from published error moments")
    if abs(number(a,"reprojection_rms")-number(m,"mean_reprojection_px"))>1e-8:
        raise ValueError("Original pooled reprojection metric source mismatch")
    environment=b.get("environment") or {}
    if environment.get("opencv_version")!="4.13.0":
        raise ValueError("Published ChArUco original OpenCV environment changed")
    source_cam=b.get("problem_shape",{})
    if source_cam.get("n_cameras")!=13 or source_cam.get("n_frames_holdout")!=52:
        raise ValueError("Original 13-camera source and holdout scope changed")
    return {
        "schema":"aqt_external_physical_target_evidence_v1",
        "source_repository":SOURCE_REPO,
        "source_commit":SOURCE_COMMIT,
        "source_real_rig_metric_git_blob":ORIGINAL_BLOBS["real_rig_metrics.json"],
        "source_benchmark_git_blob":ORIGINAL_BLOBS["benchmark.json"],
        "source_real_rig_metric_sha256":sha256(real_metrics),
        "source_benchmark_sha256":sha256(benchmark),
        "original_heldout_physical_length_comparisons":n,
        "original_calibration_camera_count":source_cam["n_cameras"],
        "original_source_holdout_frame_count":source_cam["n_frames_holdout"],
        "physical_Charuco_intercorner_spacing_mm":spacing,
        "source_reported_intercorner_MAE_mm":mae_mm,
        "source_reported_intercorner_RMSE_mm":rmse_mm,
        "recomputed_error_moment_RMSE_mm":reconstruct_rmse_mm,
        "source_reported_relative_MAE_pct":relative_pct,
        "source_reported_pooled_reprojection_RMS_px":number(a,"reprojection_rms"),
        "source_mean_primary_camera_reprojection_px":number(m,"mean_per_camera_reprojection_px"),
        "source_opencv_version":environment["opencv_version"],
        "source_aquacal_version":environment.get("aquacal_version"),
        "actual_external_real_aquarium_target_evidence_imported":True,
        "external_published_summary_numerically_consistent":True,
        "individual_source_3d_target_coordinates_downloaded":False,
        "source_calibration_images_reprocessed_by_AquaTrajectories":False,
        "AquaTrajectories_own_XYZ_RMSE_measured":False,
        "independent_AquaTrajectories_metrology_certified":False,
        "multi_camera_exposure_hardware_sync_verified":False,
        "fish_3d_positions_or_animal_welfare_validated":False,
        "interpretation":"Original another-project 13-camera real underwater calibration "
          "inter-corner length measurements. Source summary and moments rechecked, "
          "not AquaTrajectories reconstructed 3D physical XYZ accuracy."
    }

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--real-metrics",type=Path,required=True)
    p.add_argument("--benchmark",type=Path,required=True)
    p.add_argument("--out",type=Path,required=True)
    a=p.parse_args(argv)
    if a.out.exists():raise FileExistsError("Do not overwrite physical source evidence")
    r=audit(a.real_metrics,a.benchmark)
    a.out.parent.mkdir(parents=True,exist_ok=True)
    a.out.write_text(json.dumps(r,indent=2,sort_keys=True)+"\n")
    print(json.dumps(r,indent=2,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Tank-blocked empirical joint fish tracking + 3D uncertainty calibration.

Explicit externally measured reference XYZ, detector misses, ID correctness,
pixel, optical and clock residuals are jointly observed in *the same row*
rather than sampled as falsely independent components. Train/heldout TANKS
must be disjoint. Empirical tank-block errors produce a conservative
finite-sample radial score only for successfully detected/correctly identified
fish; misses and ID mistakes count as unconditional failures, never as
imputed true trajectories. Correlated tank sampling preserves original
within-row uncertainty dependencies and avoids frame pseudoreplication.

Software can process genuine independently verified external experiments,
but it cannot establish that user-supplied physical targets or fish IDs were
measured by independent experts. Scientific validation remains external.
"""
from __future__ import annotations
import argparse
import csv
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import random
import statistics

COLUMNS=[
    "tank_id","session_id","fish_id","time_s","partition",
    "truth_x","truth_y","truth_z",
    "pred_x","pred_y","pred_z",
    "detection_success","identity_correct",
    "pixel_error_a_px","pixel_error_b_px",
    "camera_clock_error_s","calibration_geometry_error_units"]
RESIDUAL_FEATURES=[
    "dx","dy","dz","pixel_error_a_px","pixel_error_b_px",
    "camera_clock_error_s","calibration_geometry_error_units"]
MAX_ROWS=1_000_000

def sha256(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda:f.read(1<<20),b""):
            h.update(chunk)
    return h.hexdigest()

def _num(v,name,missing=False):
    if v=="" and missing:return None
    try:x=float(v)
    except (ValueError,TypeError) as e:raise ValueError("Invalid numeric "+name) from e
    if not math.isfinite(x):
        raise ValueError("Nonfinite physical source "+name)
    return x

def _flag(v,name):
    if v not in ("0","1"):raise ValueError(name+" must be 0 or 1")
    return v=="1"

def read_source(path):
    with Path(path).open("r",encoding="utf-8-sig",newline="") as f:
        reader=csv.DictReader(f)
        if reader.fieldnames!=COLUMNS:
            raise ValueError("Original physical/ID residual source schema differs")
        rows=[]
        seen=set()
        for row in reader:
            if len(rows)>=MAX_ROWS:
                raise ValueError("Too many original fish residual observations")
            for col in ("tank_id","session_id","fish_id"):
                if not row[col] or len(row[col])>150:
                    raise ValueError("Missing real tank/session/fish ID")
            if row["partition"] not in ("train","holdout"):
                raise ValueError("Explicit train/holdout TANK split required")
            t=_num(row["time_s"],"time_s")
            key=(row["tank_id"],row["session_id"],row["fish_id"],t)
            if key in seen:
                raise ValueError("Duplicate original fish/time within physical tank/session")
            seen.add(key)
            detected=_flag(row["detection_success"],"detection_success")
            identity=_flag(row["identity_correct"],"identity_correct")
            if identity and not detected:
                raise ValueError("Fish identity cannot be verified when detection failed")
            truth=tuple(_num(row[k],k) for k in ("truth_x","truth_y","truth_z"))
            pred=tuple(_num(row[k],k,missing=True)
                       for k in ("pred_x","pred_y","pred_z"))
            if detected and any(v is None for v in pred):
                raise ValueError("Detected fish must have complete 3D prediction")
            if not detected and any(v is not None for v in pred):
                raise ValueError("Missing fish cannot have invented reconstructed XYZ")
            features={k:_num(row[k],k) for k in (
                "pixel_error_a_px","pixel_error_b_px",
                "camera_clock_error_s","calibration_geometry_error_units")}
            if not detected and any(abs(features[k])>1e10 for k in features):
                raise ValueError("Unbounded source measurement errors")
            residual=None
            if detected:
                residual=tuple(pred[j]-truth[j] for j in range(3))
            rows.append({
                "tank_id":row["tank_id"],"session_id":row["session_id"],
                "fish_id":row["fish_id"],"time_s":t,
                "partition":row["partition"],"truth_xyz":truth,
                "pred_xyz":pred,"detected":detected,
                "identity_correct":identity,"residual_xyz":residual,
                **features})
    if not rows:
        raise ValueError("Original uncertainty calibration dataset is empty")
    tank_partition={}
    for row in rows:
        key=row["tank_id"]
        if key in tank_partition and tank_partition[key]!=row["partition"]:
            raise ValueError("Source tank leakage between training and heldout residuals")
        tank_partition[key]=row["partition"]
    if set(tank_partition.values())!={"train","holdout"}:
        raise ValueError("Need independently heldout original tanks, not fish/frame split")
    return rows

def _mean(x):
    return sum(x)/len(x) if x else None

def _quantile_sorted(samples,alpha):
    if not 0<alpha<1:raise ValueError("Uncertainty alpha must be (0,1)")
    n=len(samples)
    # Finite-sample conformal order statistic; inf radius when
    # n insufficient for requested nominal coverage.
    index=math.ceil((n+1)*(1-alpha))
    if index>n:return None
    return sorted(samples)[index-1]

def _covariance(feature_rows):
    if not feature_rows:return None
    n=len(feature_rows)
    means=[_mean([x[j] for x in feature_rows])
           for j in range(len(feature_rows[0]))]
    if n<2:return None
    return [
        [sum((r[i]-means[i])*(r[j]-means[j])
             for r in feature_rows)/(n-1)
         for j in range(len(means))]
        for i in range(len(means))]

def _radial(row):
    if not row["detected"] or not row["identity_correct"]:
        return None
    return math.sqrt(sum(v*v for v in row["residual_xyz"]))

def _vector(row):
    r=row["residual_xyz"] if row["residual_xyz"] is not None else (None,)*3
    return [*r,*[row[k] for k in RESIDUAL_FEATURES[3:]]]

def calibrate(rows,alpha=.05,n_draws=2000,seed=713,xyz_units=None):
    if xyz_units not in ("cm","m"):
        raise ValueError("Original physical truth XYZ units cm or m must be explicitly declared")
    if not 0<alpha<1 or type(n_draws) is not int or n_draws<10 or n_draws>100000:
        raise ValueError("Invalid alpha or Monte Carlo draws")
    if type(seed) is not int or seed<0 or seed>2147483647:
        raise ValueError("Invalid deterministic random seed")
    train=[x for x in rows if x["partition"]=="train"]
    hold=[x for x in rows if x["partition"]=="holdout"]
    train_by_tank=defaultdict(list)
    hold_by_tank=defaultdict(list)
    for x in train:train_by_tank[x["tank_id"]].append(x)
    for x in hold:hold_by_tank[x["tank_id"]].append(x)
    if len(train_by_tank)<3 or len(hold_by_tank)<1:
        raise ValueError("Need >=3 training tanks and >=1 independent holdout tank")
    # In each train tank any detector miss or ID error has no true XYZ
    # containment; finite-sample score explicitly becomes Infinity.
    tank_scores={}
    tank_failure={}
    for tank,records in sorted(train_by_tank.items()):
        good=[_radial(r) for r in records]
        failures=sum(x is None for x in good)
        tank_failure[tank]=failures
        tank_scores[tank]=max(good) if good and failures==0 else math.inf
    finite_scores=[s for s in tank_scores.values() if math.isfinite(s)]
    n=len(train_by_tank)
    rank=math.ceil((n+1)*(1-alpha))
    radius=_quantile_sorted(list(tank_scores.values()),alpha)
    if radius is not None and not math.isfinite(radius):
        radius=None
    eligible=radius is not None
    heldout_by_tank={}
    for tank,records in sorted(hold_by_tank.items()):
        hits=[_radial(r) for r in records]
        success=eligible and all(v is not None and v<=radius for v in hits)
        heldout_by_tank[tank]={
            "n_observations":len(records),
            "n_detection_failures":sum(not r["detected"] for r in records),
            "n_identity_failures":sum(r["detected"] and
                                      not r["identity_correct"] for r in records),
            "all_source_observations_covered":bool(success),
            "max_valid_radial_xyz_error":max(
                (v for v in hits if v is not None),default=None)}
    hold_tanks=list(heldout_by_tank.values())
    # Both all-frame/tank coverage and individual successes disclosed.
    observed_success=sum(
        _radial(x) is not None and eligible and _radial(x)<=radius
        for x in hold)
    valid_train=[x for x in train if _radial(x) is not None]
    # Study-systematic errors are preserved by sampling one original
    # tank and then one correlated original complete residual record.
    # This is a block experiment, not independent per-frame bootstrap.
    rng=random.Random(seed)
    tank_names=sorted(train_by_tank)
    sampled=[]
    for draw in range(n_draws):
        tank=rng.choice(tank_names)
        frame=rng.choice(train_by_tank[tank])
        features=_vector(frame)
        sampled.append({
            "draw":draw+1,"sampled_training_tank":tank,
            "source_detection_success":frame["detected"],
            "source_identity_correct":frame["identity_correct"],
            "dx":features[0],"dy":features[1],"dz":features[2],
            "pixel_error_a_px":features[3],
            "pixel_error_b_px":features[4],
            "camera_clock_error_s":features[5],
            "calibration_geometry_error_units":features[6]})
    # Entire tank mean vectors for covariance, not frame pseudoreplicates.
    vectors=[]
    for tank,records in sorted(train_by_tank.items()):
        complete=[_vector(r) for r in records if _radial(r) is not None]
        if complete:
            vectors.append([_mean([v[j] for v in complete])
                            for j in range(len(RESIDUAL_FEATURES))])
    rates={
       "source_train_detection_failure_fraction":
           sum(not r["detected"] for r in train)/len(train),
       "source_train_identity_failure_given_detected":
           sum(r["detected"] and not r["identity_correct"] for r in train)/
           max(1,sum(r["detected"] for r in train)),
       "source_holdout_detection_failure_fraction":
           sum(not r["detected"] for r in hold)/len(hold),
       "source_holdout_identity_failure_given_detected":
           sum(r["detected"] and not r["identity_correct"] for r in hold)/
           max(1,sum(r["detected"] for r in hold))}
    return {
        "schema":"aqt_empirical_joint_fish_uncertainty_v1",
        "alpha":alpha,"intended_marginal_coverage":1-alpha,
        "n_original_train_tanks":len(train_by_tank),
        "n_original_holdout_tanks":len(hold_by_tank),
        "n_original_train_observations":len(train),
        "n_original_holdout_observations":len(hold),
        "n_failed_training_tank_groups":sum(bool(x) for x in tank_failure.values()),
        "n_successful_train_tank_max_scores":len(finite_scores),
        "finite_sample_order_statistic_rank":rank,
        "finite_sample_group_max_radial_radius":radius,
        "radius_units":xyz_units,
        "original_xyz_physical_units_externally_declared":True,
        "finite_sample_unconditional_joint_interval_available":eligible,
        "holdout_all_frame_tank_coverage_fraction":(
            sum(v["all_source_observations_covered"] for v in hold_tanks)/
            len(hold_tanks) if eligible else None),
        "holdout_individual_observation_coverage_including_failures":(
            observed_success/len(hold) if eligible else None),
        "holdout_tank_diagnostics":heldout_by_tank,
        "joint_tank_mean_residual_covariance":_covariance(vectors),
        "joint_error_feature_order":RESIDUAL_FEATURES,
        "train_holdout_fish_source_failures":rates,
        "empirical_joint_correlated_draws":sampled,
        "source_residuals_share_original_observation_scope":True,
        "independent_tank_partition_contract_verified":True,
        "original_physical_XYZ_independent_survey_authenticated":False,
        "source_fish_ID_ground_truth_independently_adjudicated":False,
        "external_empirical_accuracy_scientifically_certified":False,
        "calibration_assumption":"exchangeable independently sampled tanks, "
          "whole-tank max 3D radial error, no cross-tank contamination; "
          "source true XYZ/identity and detector masks require third-party review",
        "caution":"This is a real-data-ready empirical calibration algorithm, "
          "not proof source biological accuracy, human welfare or physically surveyed XYZ."}

def main(argv=None):
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--empirical-source-csv",required=True,type=Path)
    ap.add_argument("--alpha",type=float,default=.05)
    ap.add_argument("--draws",type=int,default=2000)
    ap.add_argument("--seed",type=int,default=713)
    ap.add_argument("--xyz-units",choices=("cm","m"),required=True,
                    help="Must equal actual externally surveyed physical XYZ units")
    ap.add_argument("--out",required=True,type=Path)
    args=ap.parse_args(argv)
    if args.out.exists():raise FileExistsError("Refusing overwrite independent original empirical evidence")
    data=calibrate(read_source(args.empirical_source_csv),args.alpha,
                   args.draws,args.seed,args.xyz_units)
    data["original_source_csv_sha256"]=sha256(args.empirical_source_csv)
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(data,indent=2,sort_keys=True,allow_nan=False)+"\n")
    print(json.dumps({k:data[k] for k in (
       "n_original_train_tanks","n_original_holdout_tanks",
       "finite_sample_group_max_radial_radius",
       "holdout_all_frame_tank_coverage_fraction",
       "external_empirical_accuracy_scientifically_certified")},
       sort_keys=True,indent=2))
    return 0

if __name__=="__main__":raise SystemExit(main())

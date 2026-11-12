#!/usr/bin/env python3
"""Auditable 3D-ZeF published-label agreement, not underwater XYZ certification.

GT and externally generated predictions use the original ZF3D first five
fields: frame,id,3d_x,3d_y,3d_z (1-based frames, centimetre source units).
A separately declared fully annotated frame manifest is mandatory for scoring.
This is not official ZF3D MOTA, TrackEval HOTA, or independent physical truth.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path
import re
import zipfile

from aqt_3dzef_source_probe import inspect_labels_zip, file_sha256


def read_tracks(text, name):
    observations = []
    seen = set()
    for lineno, row in enumerate(csv.reader(io.StringIO(text)), 1):
        if not row:
            continue
        if len(row) < 5:
            raise ValueError(f"{name}:{lineno}: expected at least five ZF3D fields")
        try:
            frame, fish_id = int(row[0]), int(row[1])
            xyz = tuple(float(v) for v in row[2:5])
        except (ValueError, TypeError) as e:
            raise ValueError(f"{name}:{lineno}: invalid frame, identity or XYZ") from e
        if frame < 1 or fish_id < 1 or not all(math.isfinite(v) for v in xyz):
            raise ValueError(f"{name}:{lineno}: nonpositive key or nonfinite XYZ")
        if (frame, fish_id) in seen:
            raise ValueError(f"{name}:{lineno}: duplicate frame/fish identity")
        seen.add((frame, fish_id))
        observations.append((frame, fish_id, xyz))
    return observations


def read_evaluated_frames(path, frame_count):
    with Path(path).open(newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames not in (["frame", "review_status"],
                                    ["frame", "review_status", "reviewer_id"]):
            raise ValueError("Frame manifest must have frame,review_status[,reviewer_id]")
        frames = set()
        declared_reviewers = set()
        for row in reader:
            try:
                f = int(row["frame"])
            except (TypeError, ValueError) as e:
                raise ValueError("Manifest frame must be integer") from e
            if f < 1 or f > frame_count or f in frames:
                raise ValueError("Manifest contains repeated/out-of-range frame")
            if row["review_status"] != "fully_annotated":
                raise ValueError("Refuse unreviewed or partially annotated frames")
            frames.add(f)
            if "reviewer_id" in row and row["reviewer_id"]:
                declared_reviewers.add(row["reviewer_id"].strip())
    if not frames:
        raise ValueError("No fully annotated frames")
    return frames, sorted(declared_reviewers)


def hungarian(cost):
    """Square minimum-cost assignment (O(n^3)); no scientific metric claimed."""
    n = len(cost)
    if not n:
        return []
    if any(len(r) != n or any(not math.isfinite(v) for v in r) for r in cost):
        raise ValueError("Assignment requires finite square costs")
    u, v = [0.0] * (n + 1), [0.0] * (n + 1)
    p, way = [0] * (n + 1), [0] * (n + 1)
    for i in range(1, n + 1):
        p[0] = i
        j0 = 0
        minv = [math.inf] * (n + 1)
        used = [False] * (n + 1)
        while True:
            used[j0] = True
            i0 = p[j0]
            delta, j1 = math.inf, 0
            for j in range(1, n + 1):
                if used[j]:
                    continue
                cur = cost[i0 - 1][j - 1] - u[i0] - v[j]
                if cur < minv[j]:
                    minv[j], way[j] = cur, j0
                if minv[j] < delta:
                    delta, j1 = minv[j], j
            for j in range(n + 1):
                if used[j]:
                    u[p[j]] += delta
                    v[j] -= delta
                else:
                    minv[j] -= delta
            j0 = j1
            if p[j0] == 0:
                break
        while True:
            j1 = way[j0]
            p[j0] = p[j1]
            j0 = j1
            if j0 == 0:
                break
    result = [None] * n
    for j in range(1, n + 1):
        result[p[j] - 1] = j - 1
    return result


def frame_match(gt, pred, threshold_cm):
    """Maximise valid 3D matches, then minimise Euclidean distance."""
    n, m = len(gt), len(pred)
    if not n or not m:
        return []
    cutoff = threshold_cm
    unmatched_cost = cutoff + 1.0
    invalid_cost = 3.0 * unmatched_cost
    size = n + m
    matrix = [[0.0 for _ in range(size)] for _ in range(size)]
    distances = {}
    for i, a in enumerate(gt):
        for j, b in enumerate(pred):
            distance = math.dist(a[2], b[2])
            distances[i, j] = distance
            matrix[i][j] = distance if distance <= cutoff else invalid_cost
        for j in range(m, size):
            matrix[i][j] = unmatched_cost
    for i in range(n, size):
        for j in range(m):
            matrix[i][j] = unmatched_cost
    assigned = hungarian(matrix)
    return [(i, j, distances[i, j]) for i, j in enumerate(assigned[:n])
            if j < m and distances[i, j] <= cutoff]


def _fraction(numer, denom):
    return numer / denom if denom else None


def score_agreement(truth, predictions, frames, frame_count, threshold_cm):
    if not isinstance(frame_count, int) or isinstance(frame_count, bool) or frame_count < 1:
        raise ValueError("Explicit positive source frame count required")
    if (not isinstance(threshold_cm, (int, float)) or
            not math.isfinite(threshold_cm) or threshold_cm <= 0):
        raise ValueError("Association threshold must be finite positive cm")
    if not frames or any(not isinstance(f, int) or f < 1 or f > frame_count for f in frames):
        raise ValueError("Invalid fully annotated frame scope")
    for name, rows in (("truth", truth), ("predictions", predictions)):
        if any(f > frame_count for f, _, _ in rows):
            raise ValueError(f"{name} frame exceeds declared full video extent")
    gt = [r for r in truth if r[0] in frames]
    pd = [r for r in predictions if r[0] in frames]
    gt_by_frame = {}
    pd_by_frame = {}
    for row in gt:
        gt_by_frame.setdefault(row[0], []).append(row)
    for row in pd:
        pd_by_frame.setdefault(row[0], []).append(row)
    matched, frame_table = [], []
    for frame in sorted(frames):
        g, p = gt_by_frame.get(frame, []), pd_by_frame.get(frame, [])
        pairs = frame_match(g, p, float(threshold_cm))
        for i, j, distance in pairs:
            a, b = g[i], p[j]
            matched.append((frame, a[1], b[1], a[2], b[2], distance))
        frame_table.append(dict(frame=frame, truth_count=len(g),
                                prediction_count=len(p), matched_count=len(pairs),
                                false_positives=len(p)-len(pairs),
                                false_negatives=len(g)-len(pairs)))
    ng, np, nm = len(gt), len(pd), len(matched)
    gt_ids, pred_ids = sorted({r[1] for r in gt}), sorted({r[1] for r in pd})
    idtp = 0
    if gt_ids and pred_ids:
        gi, pi = {x: i for i, x in enumerate(gt_ids)}, {x: i for i, x in enumerate(pred_ids)}
        size = max(len(gi), len(pi))
        weight = [[0] * size for _ in range(size)]
        for _, a, b, _, _, _ in matched:
            weight[gi[a]][pi[b]] += 1
        maximum = max(max(r) for r in weight)
        perm = hungarian([[maximum - w for w in row] for row in weight])
        idtp = sum(weight[i][perm[i]] for i in range(len(gt_ids)))
    idfp, idfn = np - idtp, ng - idtp
    by_true_id = {}
    for frame, a, b, _, _, _ in matched:
        by_true_id.setdefault(a, []).append((frame, b))
    switches = 0
    comparable = 0
    for series in by_true_id.values():
        series.sort()
        for previous, current in zip(series, series[1:]):
            if current[0] == previous[0] + 1:
                comparable += 1
                switches += int(current[1] != previous[1])
    component_errors = [[p[k] - g[k] for k in range(3)]
                        for _, _, _, g, p, _ in matched]
    def root_mean_square(x):
        return math.sqrt(sum(z*z for z in x) / len(x)) if x else None
    summary = {
        "metric_scope": "agreement_with_published_3dzef_3d_head_labels",
        "source_xyz_unit": "cm",
        "n_full_video_frames_declared": frame_count,
        "n_evaluated_frames": len(frames),
        "evaluated_frame_fraction": len(frames) / frame_count,
        "n_source_truth_rows": len(truth),
        "n_source_prediction_rows": len(predictions),
        "n_truth_inside_evaluation": ng,
        "n_predictions_inside_evaluation": np,
        "n_truth_excluded_outside_scope": len(truth) - ng,
        "n_predictions_excluded_outside_scope": len(predictions) - np,
        "n_matches": nm,
        "false_positives": np - nm,
        "false_negatives": ng - nm,
        "false_positives_on_declared_empty_frames": sum(
            v["prediction_count"] for v in frame_table if not v["truth_count"]),
        "match_precision": _fraction(nm, np),
        "match_recall": _fraction(nm, ng),
        "association_distance_cutoff_cm": threshold_cm,
        "matched_3d_euclidean_rmse_cm": root_mean_square([v[5] for v in matched]),
        "matched_3d_euclidean_mae_cm": _fraction(sum(v[5] for v in matched), nm),
        "coordinate_bias_cm_xyz": [
            _fraction(sum(r[k] for r in component_errors), nm) for k in range(3)],
        "coordinate_rmse_cm_xyz": [
            root_mean_square([r[k] for r in component_errors]) for k in range(3)],
        "IDTP": idtp,
        "IDFP": idfp,
        "IDFN": idfn,
        "camera_local_3d_IDF1_like": _fraction(2*idtp, 2*idtp + idfp + idfn),
        "adjacent_identity_switches": switches,
        "comparable_adjacent_pairs": comparable,
        "official_ZF3D_MOTA_computed": False,
        "official_TrackEval_HOTA_computed": False,
        "independent_physical_xyz_ground_truth_verified": False,
        "camera_exposure_synchronization_verified": False,
        "behaviour_or_welfare_validated": False,
    }
    matches_table = [
        dict(frame=f, truth_id=tid, predicted_id=pid,
             true_x_cm=g[0], true_y_cm=g[1], true_z_cm=g[2],
             pred_x_cm=p[0], pred_y_cm=p[1], pred_z_cm=p[2],
             euclidean_error_cm=d)
        for f, tid, pid, g, p, d in matched
    ]
    return summary, frame_table, matches_table


def dump_csv(path, rows, columns):
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=columns)
        writer.writeheader()
        writer.writerows(rows)


def open_original_gt(archive, member):
    audit = inspect_labels_zip(Path(archive))
    allowed = {entry["path"] for entry in audit["native_mot_3d_gt_inspections"]}
    if member not in allowed:
        raise ValueError("Requested GT member was not verified in the original archive")
    with zipfile.ZipFile(archive) as zipped:
        return zipped.read(member).decode("utf-8-sig"), audit


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--labels-zip", type=Path)
    ap.add_argument("--archive-member", help="Exact original ZIP gt/gt.txt path")
    ap.add_argument("--truth", type=Path, help="Local original ZF3D GT file")
    ap.add_argument("--predictions", type=Path, help="Independent 5-column ZF3D predictions")
    ap.add_argument("--evaluated-frames", type=Path)
    ap.add_argument("--frame-count", type=int)
    ap.add_argument("--threshold-cm", type=float, default=2.0)
    ap.add_argument("--output-dir", type=Path)
    ap.add_argument("--audit-json", type=Path)
    a = ap.parse_args(argv)
    if not a.predictions:
        if a.labels_zip is None or a.archive_member or a.truth:
            ap.error("Audit mode requires only --labels-zip")
        audit = inspect_labels_zip(a.labels_zip)
        report = {
            "mode": "published_annotations_structure_only",
            "archive_sha256": audit["archive_sha256"],
            "native_gt_count": len(audit["native_mot_3d_gt_inspections"]),
            "sequences": [{
                "path": r["path"],
                "observations": r["inspection"]["n_observations"],
                "fish_ids": r["inspection"]["n_distinct_fish_ids"],
                "source_first_frame": r["inspection"]["min_source_frame"],
                "source_last_frame": r["inspection"]["max_source_frame"]
            } for r in audit["native_mot_3d_gt_inspections"]],
            "actual_fish_predictions_scored": False,
            "physical_xyz_certified": False
        }
        target = a.audit_json
        if target:
            target.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        else:
            print(json.dumps(report, indent=2))
        return 0
    if (a.truth is None) == (a.labels_zip is None):
        ap.error("Scoring needs exactly one of --truth or --labels-zip")
    if a.labels_zip and not a.archive_member:
        ap.error("Scoring ZIP needs --archive-member")
    if not a.output_dir or not a.evaluated_frames or not a.frame_count:
        ap.error("Scoring requires --output-dir, --evaluated-frames, --frame-count")
    if a.labels_zip:
        gt_text, source_audit = open_original_gt(a.labels_zip, a.archive_member)
        source_id = a.archive_member
        input_hash = file_sha256(a.labels_zip)
    else:
        gt_text = a.truth.read_text(encoding="utf-8-sig")
        source_id = a.truth.name
        input_hash = file_sha256(a.truth)
    gt = read_tracks(gt_text, "GT")
    predictions = read_tracks(a.predictions.read_text(encoding="utf-8-sig"), "predictions")
    evaluated, reviewers = read_evaluated_frames(a.evaluated_frames, a.frame_count)
    summary, frame_table, matches = score_agreement(
        gt, predictions, evaluated, a.frame_count, a.threshold_cm)
    truth_sig = {(f, i, xyz) for f, i, xyz in gt if f in evaluated}
    pred_sig = {(f, i, xyz) for f, i, xyz in predictions if f in evaluated}
    if truth_sig == pred_sig and truth_sig:
        raise ValueError("Predictions exactly reproduce source labels: refuse oracle/leakage scoring")
    output = a.output_dir
    if output.exists() and any(output.iterdir()):
        raise FileExistsError("Refuse nonempty output directory")
    output.mkdir(parents=True, exist_ok=True)
    summary.update({
        "source_GT_identifier": source_id,
        "source_GT_or_archive_sha256": input_hash,
        "predictions_sha256": file_sha256(a.predictions),
        "evaluated_frames_sha256": file_sha256(a.evaluated_frames),
        "reviewer_ids_declared_by_manifest": reviewers,
        "reviewer_independence_externally_verified": False,
        "source_ground_truth_not_generated_from_predictions": True,
        "prediction_model_weights_sha256_verified": False,
        "real_fish_video_run_verified": False,
        "scientific_accuracy_certified": False,
        "note": ("Agreement to source 3D tracking labels only. Frame completeness "
                 "and reviewer/model provenance require independent checking.")
    })
    dump_csv(output/"per_frame.csv", frame_table,
             ["frame", "truth_count", "prediction_count", "matched_count",
              "false_positives", "false_negatives"])
    dump_csv(output/"matches.csv", matches,
             ["frame", "truth_id", "predicted_id", "true_x_cm", "true_y_cm",
              "true_z_cm", "pred_x_cm", "pred_y_cm", "pred_z_cm",
              "euclidean_error_cm"])
    summary["artifact_sha256"] = {
        p.name: file_sha256(p) for p in (output/"per_frame.csv", output/"matches.csv")}
    (output/"summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True)+"\n",
                                      encoding="utf-8")
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

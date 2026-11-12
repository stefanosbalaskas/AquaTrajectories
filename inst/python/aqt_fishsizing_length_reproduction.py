#!/usr/bin/env python3
"""Read-only evaluation of original FishSizing per-frame length results.

The official FishSizing result CSV stores filtered_length in metres,
gt in centimetres, abs_error_cm and rel_error_%. This audit reproduces
the published row-level error columns; it NEVER claims these are
AquaTrajectories predictions or independent true underwater fish XYZ.

Source: https://github.com/Caterina1996/fish_sizing
"""

from __future__ import annotations
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for b in iter(lambda: stream.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def _optional_number(raw: str | None, name: str) -> float | None:
    if raw is None or not str(raw).strip():
        return None
    try:
        value = float(raw)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"Invalid {name} numeric value") from exc
    if not math.isfinite(value):
        raise ValueError(f"Nonfinite {name}")
    return value


def _manual_reference_lengths(path: Path) -> list[float]:
    """Values alone cannot certify the source fish's specimen identity."""
    if not path.is_file():
        raise FileNotFoundError("Missing manually measured fish source table")
    with path.open("r", newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        needed = {"Dataset", "Identifier", "Species_Scientific_Name",
                  "Total_Length_cm"}
        if not needed.issubset(reader.fieldnames or []):
            raise ValueError("FishSizing manual specimen table columns missing")
        values = []
        for row in reader:
            # The original source stores decimal comma in quote-protected fields.
            n = _optional_number(
                row["Total_Length_cm"].replace(",", "."), "Total_Length_cm")
            if n is None or n <= 0:
                raise ValueError("Invalid specimen length")
            values.append(n)
    if not values:
        raise ValueError("No external manual fish reference measurements")
    return values


def inspect_source_results(csv_path: Path,
                           manual_gt_csv: Path | None = None) -> dict:
    csv_path = Path(csv_path)
    if not csv_path.is_file() or csv_path.stat().st_size > 20 * 1024 * 1024:
        raise ValueError("Missing or oversized source model result CSV")
    manual_lengths = (
        _manual_reference_lengths(manual_gt_csv)
        if manual_gt_csv is not None else None
    )
    needed = {
        "frame_id", "object_id", "fish_3d_ok", "filtered_length",
        "gt", "abs_error_cm", "rel_error_%"
    }
    n = 0
    with_length = 0
    invalid_sentinel = 0
    with_source_error = 0
    passing_three_d_flag = 0
    complete_flagged_errors = 0
    error_values = []
    flagged_error_values = []
    gt_seen = set()
    with csv_path.open("r", newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        if not needed.issubset(reader.fieldnames or []):
            raise ValueError("FishSizing per-frame result columns missing")
        for row in reader:
            n += 1
            frame = row["frame_id"]
            if not frame or not frame.startswith("frame_") or not (
                    frame[6:].isdigit() and int(frame[6:]) >= 1):
                raise ValueError("Original frame ID requires frame_1 origin")
            if not row["object_id"]:
                raise ValueError("Source object reference must be present")
            ok3 = row["fish_3d_ok"].lower()
            if ok3 not in ("true", "false"):
                raise ValueError("fish_3d_ok requires True/False source status")
            if ok3 == "true":
                passing_three_d_flag += 1
            prediction = _optional_number(
                row["filtered_length"], "filtered_length_m")
            gt = _optional_number(row["gt"], "ground_truth_cm")
            abs_e = _optional_number(row["abs_error_cm"], "abs_error_cm")
            rel_e = _optional_number(row["rel_error_%"], "rel_error_percent")
            if prediction == -1.0:
                # Real FishSizing export includes -1.0 as an invalid-result
                # sentinel, not a biologically impossible negative fish.
                if ok3 != "false" or abs_e is not None or rel_e is not None:
                    raise ValueError(
                        "Invalid sentinel cannot have 3D quality or an error")
                invalid_sentinel += 1
                prediction = None
            elif prediction is not None:
                if prediction <= 0:
                    raise ValueError("Model length must be positive")
                with_length += 1
            if gt is not None:
                if gt <= 0:
                    raise ValueError("Manual ground-truth length invalid")
                gt_seen.add(gt)
                if manual_lengths is not None and not any(
                        math.isclose(gt, m, rel_tol=0, abs_tol=1e-7)
                        for m in manual_lengths):
                    raise ValueError(
                        "Reported GT is not among published manual lengths")
            if abs_e is None and rel_e is None:
                continue
            if None in (prediction, gt, abs_e, rel_e):
                raise ValueError(
                    "Source error row must contain length, GT and both errors")
            actual_e = abs(100 * prediction - gt)
            if abs_e < 0 or rel_e < 0 or not math.isclose(
                    actual_e, abs_e, rel_tol=1e-9, abs_tol=1e-7):
                raise ValueError(
                    "Published abs_error_cm not reproduced by filtered length")
            if not math.isclose(
                    100 * actual_e / gt, rel_e,
                    rel_tol=1e-9, abs_tol=1e-7):
                raise ValueError("Published relative error disagrees with source")
            error_values.append(actual_e)
            with_source_error += 1
            if ok3 == "true":
                complete_flagged_errors += 1
                flagged_error_values.append(actual_e)
    if not n or not with_source_error:
        raise ValueError("No valid per-frame source error rows")
    mean = lambda values: (sum(values) / len(values) if values else None)
    return {
        "schema_version": "1.0",
        "source_csv_sha256": sha256(csv_path),
        "manual_gt_csv_sha256": (
            sha256(manual_gt_csv) if manual_gt_csv else None),
        "n_original_result_rows": n,
        "n_rows_with_filtered_length": with_length,
        "n_rows_with_invalid_length_sentinel_minus_one": invalid_sentinel,
        "n_rows_with_reproducible_source_errors": with_source_error,
        "n_rows_fish_3d_ok_true": passing_three_d_flag,
        "n_rows_fish_3d_ok_with_reproduced_error": complete_flagged_errors,
        "n_rows_without_source_error": n - with_source_error,
        "reported_gt_lengths_cm": sorted(gt_seen),
        "source_model_per_frame_mae_cm": mean(error_values),
        "source_model_per_frame_rmse_cm": (
            math.sqrt(mean([v*v for v in error_values]))
            if error_values else None),
        "source_model_3d_ok_subset_mae_cm": mean(flagged_error_values),
        "source_error_columns_recomputed_from_original_source": True,
        "manual_gt_matches_published_length_values_only": (
            manual_lengths is not None),
        "manual_specimen_identity_from_this_csv_certified": False,
        "source_model_predictions_are_aquatrajectories": False,
        "underwater_xyz_position_truth_certified": False,
        "fish_behaviour_or_welfare_certified": False,
        "statistical_inference_over_frames_permitted": False,
        "interpretation": (
            "Descriptive source-model frame errors only; repeated frames "
            "are correlated, and biological specimen/session identity "
            "needs separately verified provenance"),
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--source-results", type=Path, required=True)
    ap.add_argument("--manual-gt", type=Path)
    ap.add_argument("--out", type=Path)
    args = ap.parse_args(argv)
    report = inspect_source_results(args.source_results, args.manual_gt)
    text = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.out:
        if args.out.exists():
            raise FileExistsError("Refusing to overwrite source model audit")
        args.out.write_text(text, encoding="utf-8")
    else:
        print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Read-only stereo ROS calibration + fish-length CSV schema audit.

Grounded in published FishSizing ROS calibration YAML and length CSV
formats. No automatic 3D refraction calibration is claimed.

The optional PyYAML package is required only for reading YAML files;
the validation helpers run with the Python standard library alone.
"""

from __future__ import annotations

import argparse
import csv
from decimal import Decimal, InvalidOperation
import json
import math
from pathlib import Path
from typing import Any


def _matrix(field: Any, rows: int, cols: int, name: str) -> list[list[float]]:
    if not isinstance(field, dict) or \
            field.get("rows") != rows or field.get("cols") != cols or \
            not isinstance(field.get("data"), list) or \
            len(field["data"]) != rows * cols:
        raise ValueError(f"ROS camera {name} requires {rows}x{cols} data")
    try:
        values = [float(x) for x in field["data"]]
    except (TypeError, ValueError) as exc:
        raise ValueError(f"ROS {name} has nonnumeric entries") from exc
    if not all(math.isfinite(x) for x in values):
        raise ValueError(f"ROS {name} must contain finite numeric values")
    return [values[i * cols:(i + 1) * cols] for i in range(rows)]


def validate_ros_calibration(cam: dict[str, Any]) -> dict[str, Any]:
    """Audit K,D,R,P structural compatibility, not their physical accuracy."""
    if not isinstance(cam, dict):
        raise ValueError("ROS camera YAML root must be a mapping")
    w, h = cam.get("image_width"), cam.get("image_height")
    if not isinstance(w, int) or isinstance(w, bool) or w < 1 or \
            not isinstance(h, int) or isinstance(h, bool) or h < 1:
        raise ValueError("ROS image width/height must be positive integers")
    model = cam.get("distortion_model")
    if model != "plumb_bob":
        raise ValueError("This audit currently supports plumb_bob only")
    k = _matrix(cam.get("camera_matrix"), 3, 3, "camera_matrix")
    dist = _matrix(
        cam.get("distortion_coefficients"), 1, 5,
        "distortion_coefficients")
    rect = _matrix(cam.get("rectification_matrix"), 3, 3,
                   "rectification_matrix")
    proj = _matrix(cam.get("projection_matrix"), 3, 4,
                   "projection_matrix")
    if k[0][0] <= 0 or k[1][1] <= 0 or proj[0][0] <= 0 or \
            proj[1][1] <= 0 or abs(k[2][2] - 1) > 1e-6:
        raise ValueError("ROS camera focal lengths must be positive")
    if not isinstance(cam.get("camera_name"), str) or \
            not cam["camera_name"].strip():
        raise ValueError("ROS camera_name is required")
    return {
        "camera_name": cam["camera_name"],
        "image_width": w,
        "image_height": h,
        "distortion_model": model,
        "K": k,
        "D": dist[0],
        "R": rect,
        "P": proj,
        "image_unit": "pixels",
        "extrinsic_translation_unit": "unknown_not_declared_in_ROS_yaml",
        "underwater_refraction_calibration_certified": False,
        "measured_xyz_ground_truth_provided": False,
        "camera_shutter_synchronization_verified": False,
    }


def audit_ros_stereo_pair(left: dict[str, Any],
                          right: dict[str, Any]) -> dict[str, Any]:
    l = validate_ros_calibration(left)
    r = validate_ros_calibration(right)
    if (l["image_width"], l["image_height"]) != \
            (r["image_width"], r["image_height"]):
        raise ValueError("ROS stereo camera image dimensions differ")
    if l["camera_name"] == r["camera_name"]:
        raise ValueError("Left/right ROS cameras must have distinct names")
    pl, pr = l["P"], r["P"]
    if abs(pl[0][3]) > 1e-6:
        raise ValueError(
            "Expected the rectified left projection x-translation to be zero")
    baseline_in_unknown_units = -(pr[0][3] / pr[0][0])
    if not math.isfinite(baseline_in_unknown_units) or \
            baseline_in_unknown_units <= 0:
        raise ValueError(
            "Right rectified projection requires a positive stereo baseline")
    return {
        "left": l,
        "right": r,
        "rectified_baseline_magnitude_in_unspecified_units":
            baseline_in_unknown_units,
        "baseline_unit": "unknown_not_provided_in_calibration_yaml",
        "requires_raw_ROS_image_header_timestamps": True,
        "refractive_port_model_requires_separate_metrology": True,
        "physical_xyz_accuracy_certified": False,
    }


def parse_length_cm(raw: str) -> float:
    """Parse source CSV quoted decimal-comma length (not US thousands)."""
    if not isinstance(raw, str) or not raw.strip():
        raise ValueError("Fish specimen length must be a nonempty string")
    text = raw.strip()
    if "," in text and "." in text:
        raise ValueError("Ambiguous mixed decimal/thousands punctuation")
    try:
        value = Decimal(text.replace(",", "."))
    except InvalidOperation as exc:
        raise ValueError("Fish length must use decimal point or comma") from exc
    if not value.is_finite() or value <= 0:
        raise ValueError("Fish specimen length must be positive and finite")
    return float(value)


def audit_length_csv(path: Path) -> dict[str, Any]:
    """Inspect independently supplied measured body-length truth only."""
    expected = [
        "Dataset", "Identifier", "Species_Common_Name",
        "Species_Scientific_Name", "Total_Length_cm"]
    if not path.is_file():
        raise FileNotFoundError("Measured fish specimen CSV not found")
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames != expected:
            raise ValueError("FishSizing physical specimen CSV schema mismatch")
        rows = list(reader)
    if not rows:
        raise ValueError("No independently measured fish specimen rows")
    used: set[tuple[str, str]] = set()
    records: list[dict[str, Any]] = []
    for row in rows:
        if not row["Dataset"] or not row["Identifier"] or \
                not row["Species_Scientific_Name"]:
            raise ValueError("Fish specimen identity and species are required")
        scope = (row["Dataset"], row["Identifier"])
        if scope in used:
            raise ValueError("Duplicate biological specimen in one dataset")
        used.add(scope)
        records.append({
            "dataset": row["Dataset"],
            "specimen_id": row["Identifier"],
            "species_common": row["Species_Common_Name"],
            "species_scientific": row["Species_Scientific_Name"],
            "total_length_cm": parse_length_cm(row["Total_Length_cm"]),
        })
    return {
        "n_specimens": len(records),
        "records": records,
        "measurement_type": "externally_reported_manual_total_fish_length_cm",
        "measured_true_XYZ_positions_provided": False,
        "fish_trajectories_or_swimming_behaviour_certified": False,
    }


def _load_yaml(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError("ROS camera calibration YAML file not found")
    try:
        import yaml
    except ImportError as exc:
        raise RuntimeError("Install optional pyyaml to inspect ROS YAML") from exc
    value = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("ROS camera calibration file did not contain a map")
    return value


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--left-yaml", type=Path)
    parser.add_argument("--right-yaml", type=Path)
    parser.add_argument("--fish-lengths-csv", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    if (args.left_yaml is None) != (args.right_yaml is None):
        parser.error("Both --left-yaml and --right-yaml are needed together")
    if args.left_yaml is None and args.fish_lengths_csv is None:
        parser.error("Supply ROS stereo YAML pair and/or a fish lengths CSV")
    summary: dict[str, Any] = {
        "schema_version": "1.0",
        "dataset_adapter": "FishSizing_ROS_and_manual_measurements",
    }
    if args.left_yaml is not None and args.right_yaml is not None:
        summary["stereo"] = audit_ros_stereo_pair(
            _load_yaml(args.left_yaml), _load_yaml(args.right_yaml))
    if args.fish_lengths_csv is not None:
        summary["measurements"] = audit_length_csv(args.fish_lengths_csv)
    contents = json.dumps(summary, indent=2, sort_keys=True) + "\n"
    if args.output is None:
        print(contents, end="")
    else:
        args.output.write_text(contents, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

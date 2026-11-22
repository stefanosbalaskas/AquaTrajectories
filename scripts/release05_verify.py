#!/usr/bin/env python3
"""Independent (stdlib-only) verifier for the released synthetic trajectory report.

This checker NEVER imports aquaTrajectories, R, its QC decisions, or any R
numerical code. It independently recomputes every eligible source-row edge,
count, excluded step and Euclidean path and checks every recorded file hash.
It is evidence for cross-language reproducibility, not biological validity.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from collections import Counter, defaultdict
from pathlib import Path

LOCKED_SOURCE_SHA256 = "b940aedc80b9ca0a2355b5fcc1912cc233ecf6318044bed4d7449ca7ee0be2bc"
SCHEMA = "AQT_RELEASE05_TRAJECTORY_REPORT_V1"
KNOWN_EDGES = {"A1", "A2", "A5", "B1", "B4", "B5",
               "C1", "C2", "C4", "C5"}
KNOWN_PATHS = {"0001": (3, 3.0), "0002": (3, 3.0),
               "0003": (4, 4.0)}
KNOWN_OMISSIONS = {
    "first_record_in_track": {"A0", "B0", "C0"},
    "unobserved_current_position": {"B2"},
    "unobserved_previous_position": {"B3"},
    "nonadjacent_source_frame": {"A4"},
    "speed_threshold": {"C3"},
}
EXPECTED_EXPORTS = {"paths", "speed", "qc_coverage", "qc_reasons"}


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise ValueError("RELEASE05_VERIFY_FAIL: " + reason)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for piece in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(piece)
    return h.hexdigest()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def check_hash_map(base: Path, data: dict[str, str]) -> None:
    require(isinstance(data, dict) and bool(data), "empty SHA-256 file map")
    for name, declared in data.items():
        sub = Path(name)
        require(
            sub.parts and all(part not in ("", ".", "..") for part in sub.parts)
            and not sub.is_absolute() and "\\" not in name,
            "unsafe manifest relative file name: " + name,
        )
        file = base / sub
        require(file.is_file() and not file.is_symlink(),
                "expected provenance file is absent or symlink: " + name)
        require(sha256(file) == declared, "SHA-256 mismatch: " + name)


def independent_oracle(csv_path: Path, expected: dict) -> tuple[dict, dict]:
    source = rows(csv_path)
    require(len(source) == 17, "source must contain exactly 17 frozen observations")
    require(len({r["source_row"] for r in source}) == len(source),
            "duplicate original source-row IDs")
    require({r["track_id"] for r in source} == set(KNOWN_PATHS),
            "synthetic track identifiers drifted")
    require(all((r["session_id"], r["camera_id"]) == ("S1", "TOP")
                for r in source), "mixed source scopes")
    per = defaultdict(list)
    for r in source:
        require(r["observed"] in ("TRUE", "FALSE"),
                "invalid explicit observed flag")
        present = all(r[k].strip() != "" for k in ("x", "y"))
        require(present == (r["observed"] == "TRUE"),
                "observed does not agree with position coordinates")
        per[r["track_id"]].append(r)
    steps = {}
    counts = Counter()
    stats = {}
    for track, records in per.items():
        records.sort(key=lambda r: float(r["time_s"]))
        prev = None
        total = 0.0
        good_steps = 0
        duration = 0.0
        for r in records:
            label = r["source_row"]
            this_good = r["observed"] == "TRUE"
            if prev is None:
                reason = "first_record_in_track"
            elif not this_good:
                reason = "unobserved_current_position"
            elif prev["observed"] != "TRUE":
                reason = "unobserved_previous_position"
            else:
                dt = float(r["time_s"]) - float(prev["time_s"])
                require(math.isfinite(dt) and dt > 0, "nonincreasing original time")
                dx = float(r["x"]) - float(prev["x"])
                dy = float(r["y"]) - float(prev["y"])
                distance = math.hypot(dx, dy)
                if int(r["frame_id"]) - int(prev["frame_id"]) != 1:
                    reason = "nonadjacent_source_frame"
                elif dt > float(expected["max_gap_s"]):
                    reason = "long_time_gap"
                elif distance / dt > float(expected["max_speed_cm_s"]):
                    reason = "speed_threshold"
                else:
                    reason = "eligible"
                    total += distance
                    duration += dt
                    good_steps += 1
            counts[reason] += 1
            steps[label] = {
                "reason": reason,
                "track_id": track,
                "eligible": reason == "eligible",
                "previous": prev["source_row"] if prev is not None else None,
            }
            prev = r
        stats[track] = dict(
            eligible_steps=good_steps,
            path_length_cm=total,
            valid_duration_s=duration,
            n_source_rows=len(records),
            n_observed_positions=sum(r["observed"] == "TRUE" for r in records)
        )
    # Hard-coded secondary oracle protects against a silently rewritten
    # expected-results file that agrees with changed but non-identical input.
    require({key for key, rec in steps.items() if rec["eligible"]} == KNOWN_EDGES,
            "independent frozen eligible edge set differs")
    for fish, (n, length) in KNOWN_PATHS.items():
        require(stats[fish]["eligible_steps"] == n
                and math.isclose(stats[fish]["path_length_cm"], length,
                                 rel_tol=0, abs_tol=1e-12),
                "independent expected geometry differs for " + fish)
    for reason, labels in KNOWN_OMISSIONS.items():
        require({label for label, item in steps.items()
                 if item["reason"] == reason} == labels,
                "independent expected source omissions differ: " + reason)
    require(sum(counts.values()) == 17 and counts["eligible"] == 10,
            "independent source accounting fails")
    return steps, stats


def verify(destination: Path) -> dict:
    require(destination.is_dir(), "missing report output directory")
    manifest_path = destination / "RELEASE05_MANIFEST.json"
    require(manifest_path.is_file(), "missing locked output manifest")
    m = load_json(manifest_path)
    require(m["schema"] == SCHEMA
            and m["release_version"] in ("0.1.2", "0.2.0")
            and m["package_version"] == m["release_version"]
            and m["dataset_origin"] == "synthetic"
            and m["external_biological_accuracy_certified"] is False,
            "release manifest makes an unsupported assertion")
    source = destination / "input" / "locked_trajectories.csv"
    expected_path = destination / "input" / "locked_expected.json"
    require(source.is_file() and expected_path.is_file(),
            "self-contained locked input files missing")
    require(sha256(source) == LOCKED_SOURCE_SHA256
            and m["original_source_sha256"] == LOCKED_SOURCE_SHA256,
            "original source hash does not match independent locked source")
    require(sha256(expected_path) == m["original_expected_sha256"],
            "expected-result manifest input not reproducible")
    expected = load_json(expected_path)
    require(expected["schema"] == "AQT_RELEASE05_LOCKED_SYNTHETIC_TRAJECTORY_V1"
            and expected["source_file_sha256"] == LOCKED_SOURCE_SHA256
            and expected["coordinate_system"] == "tank"
            and expected["units"] == "cm"
            and expected["source_clock_measured_externally"] is False,
            "scientific source and unit contract changed")
    require(float(expected["max_gap_s"]) == 1.01
            and float(expected["max_speed_cm_s"]) == 2.0,
            "QC policy changed from frozen example")
    require(sha256(destination / "scripts/release05_example.R")
            == m["producing_R_script_sha256"]
            and sha256(destination / "scripts/release05_verify.py")
            == m["independent_Python_verifier_sha256"],
            "producer or independent verifier source bytes differ")
    check_hash_map(destination, m["output_sha256"])
    # Ensure no unrecorded derived file was inserted or silently left out.
    actual_files = {
        p.relative_to(destination).as_posix()
        for p in destination.rglob("*") if p.is_file()
    }
    require(actual_files == set(m["output_sha256"]) | {"RELEASE05_MANIFEST.json"},
            "unrecorded or missing output files")
    steps, numeric = independent_oracle(source, expected)
    exp_per = {v["track_id"]: v for v in expected["per_track"]}
    require(set(exp_per) == set(KNOWN_PATHS), "expected fish population drift")
    for fish, result in numeric.items():
        ref = exp_per[fish]
        require(result["eligible_steps"] == ref["eligible_steps"]
                and math.isclose(result["path_length_cm"],
                                 ref["path_length_cm"], abs_tol=1e-12)
                and math.isclose(result["valid_duration_s"],
                                 ref["valid_duration_s"], abs_tol=1e-12),
                "expected report results do not match independent oracle")
    lineage = rows(destination / "qc2" / "QC_ROW_LINEAGE.csv")
    require(len(lineage) == len(steps), "QC2 input lineage loses original rows")
    require({z["to_source_row"] for z in lineage} == set(steps),
            "QC2 source-row lineage mismatch")
    for r in lineage:
        truth = steps[r["to_source_row"]]
        require(r["reason_detail"] == truth["reason"]
                and (r["step_eligible"] == "TRUE") == truth["eligible"]
                and r["track_id"] == truth["track_id"]
                and (r["from_source_row"] or None) == truth["previous"],
                "QC2 output conflicts with independent oracle at "
                + r["to_source_row"])
    result_rows = rows(destination / "RESULTS.csv")
    require(len(result_rows) == 3, "one report row per fish required")
    for r in result_rows:
        fish = r["track_id"]
        require(fish in numeric, "report introduced an unobserved track ID")
        truth = numeric[fish]
        for col in ("n_source_rows", "n_observed_positions", "n_eligible_steps"):
            independent_name = "eligible_steps" if col == "n_eligible_steps" else col
            require(int(r[col]) == truth[independent_name], "incorrect per-fish " + col)
        for col in ("path_length_cm", "valid_duration_s"):
            require(math.isclose(float(r[col]), truth[col],
                                 abs_tol=1e-12, rel_tol=0),
                    "incorrect independent per-fish " + col)
        require(math.isclose(float(r["mean_speed_cm_s"]),
                             truth["path_length_cm"] / truth["valid_duration_s"],
                             abs_tol=1e-12, rel_tol=0),
                "mean speed improperly pooled over missing/excluded data")
    totals = rows(destination / "QC_TOTALS.csv")
    require(len(totals) == 1
            and int(totals[0]["source_rows"]) == 17
            and int(totals[0]["observed_positions"]) == 16
            and int(totals[0]["eligible_steps"]) == 10
            and int(totals[0]["policy_excluded_steps"]) == 2
            and int(totals[0]["not_estimable_rows"]) == 5
            and math.isclose(float(totals[0]["path_length_cm"]), 10, abs_tol=1e-12)
            and totals[0]["dataset_origin"] == "synthetic",
            "numeric whole-report summary disagrees with source")
    qc_manifest = load_json(destination / "qc2" / "QC2_MANIFEST.json")
    require(qc_manifest["source_file_sha256"] == LOCKED_SOURCE_SHA256,
            "QC2 original CSV provenance broken")
    check_hash_map(destination / "qc2", qc_manifest["output_sha256"])
    catalog = rows(destination / "FIGURE_CATALOG.csv")
    require({r["figure"] for r in catalog} == EXPECTED_EXPORTS,
            "four native figure types not documented")
    for entry in catalog:
        name = entry["figure"]
        require(entry["original_source_sha256"] == LOCKED_SOURCE_SHA256
                and int(entry["source_rows"]) == 17
                and int(entry["accepted_steps"]) == 10
                and entry["policy_id"] == "QC001",
                "figure catalog has incorrect scientific source")
        path = destination / "figures" / name
        figure_manifest = load_json(path / "VIZ2_MANIFEST.json")
        require(figure_manifest["data_provenance"]["source_file_sha256"]
                == LOCKED_SOURCE_SHA256
                and figure_manifest["data_provenance"]["coordinate_units"] == "cm"
                and figure_manifest["counts"]["n_eligible_steps"] == 10
                and figure_manifest["counts"]["n_source_rows"] == 17,
                "figure-to-input source-row linkage broken for " + name)
        check_hash_map(path, figure_manifest["output_sha256"])
        edges = rows(path / "ELIGIBLE_SOURCE_SEGMENTS.csv")
        require({e["to_source_row"] for e in edges} == KNOWN_EDGES,
                "the plotted eligible edge set drifted: " + name)
        require(len(rows(path / "PLOTTED_SOURCE_POINTS.csv")) == 17,
                "the figure drops observed source rows: " + name)
        require(len(rows(path / "ALL_QC_ROW_DECISIONS.csv")) == 17,
                "figure QC trace lacks every original decision: " + name)
        pdf = path / "figure.pdf"
        png = path / "figure.png"
        require(pdf.read_bytes()[:4] == b"%PDF"
                and png.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n",
                "figure file signature invalid for " + name)
        if name == "paths":
            require((path / "figure.svg").is_file()
                    and b"<svg" in (path / "figure.svg").read_bytes()[:4096]
                    and (path / "figure.tiff").read_bytes()[:4] in
                    (b"II*\x00", b"MM\x00*"),
                    "vector/tiff formats not correctly exported")
    report = (destination / "REPORT.md").read_text(encoding="utf-8")
    require("synthetic" in report.lower()
            and LOCKED_SOURCE_SHA256 in report and "10 cm" in report
            and "scientific limitations" in report.lower(),
            "report lacks source identity or limitations")
    return {
        "schema": "AQT_RELEASE05_INDEPENDENT_PYTHON_ORACLE_V1",
        "status": "PASS_INDEPENDENT_SOURCE_TO_REPORT",
        "original_rows": len(steps),
        "qualified_steps": len(KNOWN_EDGES),
        "qualified_path_length_cm": sum(z["path_length_cm"] for z in numeric.values()),
        "figure_kinds": sorted(EXPECTED_EXPORTS),
        "algorithm": "stdlib-only original-frame/time QC and Euclidean distances",
        "biological_ground_truth_certified": False,
    }


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, required=True,
                    help="Newly generated reproducible native R report directory")
    ap.add_argument("--report", type=Path,
                    help="Optional external JSON summary file")
    args = ap.parse_args()
    result = verify(args.out)
    if args.report:
        require(not args.report.exists() and args.report.parent.is_dir(),
                "independent evidence summary would overwrite a file")
        args.report.write_text(json.dumps(result, indent=2) + "\n",
                               encoding="utf-8")
    print("RELEASE05_INDEPENDENT_PYTHON_ORACLE_PASS",
          result["original_rows"], "source rows",
          result["qualified_steps"], "eligible edges",
          result["qualified_path_length_cm"], "cm")


if __name__ == "__main__":
    main()

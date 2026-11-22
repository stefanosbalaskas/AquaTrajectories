#!/usr/bin/env python3
"""Audit real covr-instrumented R coverage; do not omit any source expressions.

The covr aggregate is authoritative for the reported percentage. Unexecuted
expression records are an additional, not numerically interchangeable, metric.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import pathlib
import sys
from collections import Counter

NEEDED = {
    "filename", "functions", "first_line", "last_line",
    "first_column", "last_column", "value"
}


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def audit(directory: pathlib.Path, out_dir: pathlib.Path, target: float) -> int:
    cov = directory / "EXECUTED_COVERAGE.csv"
    meta_file = directory / "EXECUTION_COVERAGE_SUMMARY.json"
    if not cov.is_file() or not meta_file.is_file():
        raise SystemExit("FAIL: missing real instrumented covr outputs")
    meta = json.loads(meta_file.read_text(encoding="utf-8"))
    if meta.get("schema") != "AQT_CORE2_EXECUTED_COVERAGE_V1":
        raise SystemExit("FAIL: unrecognized source-coverage schema")
    if meta.get("status") != "MEASURED" or not isinstance(meta.get("percent"), (int, float)):
        raise SystemExit("FAIL: source coverage has not been measured")
    if meta.get("output_sha256") != sha256(cov):
        raise SystemExit("FAIL: original instrumented rows changed after measurement")
    with cov.open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames is None or not NEEDED.issubset(reader.fieldnames):
            raise SystemExit("FAIL: missing instrumented expression fields")
        all_rows = list(reader)
    if not all_rows:
        raise SystemExit("FAIL: zero instrumented expressions")
    if len(all_rows) != meta.get("n_instrumented_records"):
        raise SystemExit("FAIL: covr row count differs from signed summary")
    uncovered = []
    for row in all_rows:
        try:
            hits = float(row["value"])
            first_line = int(row["first_line"])
        except (TypeError, ValueError) as error:
            raise SystemExit("FAIL: invalid instrumented covr value") from error
        if hits < 0 or first_line < 1:
            raise SystemExit("FAIL: impossible expression count or position")
        if hits == 0:
            uncovered.append(row)
    files = Counter(x["filename"] for x in uncovered)
    functions = Counter((x["filename"], x["functions"]) for x in uncovered)
    out_dir.mkdir(parents=True, exist_ok=True)
    enriched = []
    for row in uncovered:
        relative = row["filename"]
        path = pathlib.Path(relative)
        source = "<source file not found>"
        if path.is_file() and path.as_posix().startswith("R/"):
            lines = path.read_text(encoding="utf-8").splitlines()
            position = int(row["first_line"])
            if position <= len(lines):
                source = lines[position - 1].strip()
        enriched.append({
            "file": relative, "function": row["functions"],
            "line": int(row["first_line"]),
            "column": int(row["first_column"]),
            "source": source[:500]
        })
    enriched.sort(key=lambda x: (x["file"], x["line"], x["column"]))
    report = {
        "schema": "AQT_COVR_100_AUDIT_V1",
        "status": "FULL_TARGET_PASS" if meta["percent"] >= target and not uncovered else "INCOMPLETE",
        "target_percent": target,
        "covr_measured_percent": meta["percent"],
        "instrumented_expression_records": len(all_rows),
        "unexecuted_expression_records": len(uncovered),
        "functions_with_unexecuted_expressions": len(functions),
        "source_files_with_unexecuted_expressions": len(files),
        "coverage_csv_sha256": sha256(cov),
        "source_namespace_sha256": meta.get("source_sha256"),
        "note": "covr percent and raw expression-record fractions are not interchangeable; neither certifies biological accuracy",
        "top_uncovered_functions": [
            {"file": p, "function": fn, "missed_expressions": n}
            for (p, fn), n in sorted(functions.items(), key=lambda z: (-z[1], z[0]))[:100]
        ],
        "top_uncovered_files": [
            {"file": p, "missed_expressions": n}
            for p, n in files.most_common(100)
        ],
    }
    (out_dir / "COVERAGE100_AUDIT.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    with (out_dir / "UNCOVERED_EXPRESSIONS.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=["file", "function", "line", "column", "source"])
        writer.writeheader()
        writer.writerows(enriched)
    md = [
        "# Instrumented R coverage: reproducible gap inventory",
        "",
        f"**Actual covr measurement:** {meta['percent']:.4f}% (target {target:.2f}%)",
        f"**Unexecuted expressions:** {len(uncovered)}/{len(all_rows)}",
        f"**Functions/files with gaps:** {len(functions)} / {len(files)}",
        "",
        "Unexecuted expressions are **not** missing source-line percentages.",
        "The full source/line ledger is in UNCOVERED_EXPRESSIONS.csv.",
        "No denominator, file, function or external failure path is suppressed.",
        "",
        "## Most missed functions",
        "",
        "| File | Function | Unexecuted expressions |",
        "| :--- | :--- | ---: |",
    ]
    for (p, fn), count in sorted(functions.items(), key=lambda z: (-z[1], z[0]))[:60]:
        md.append(f"| \`{p}\` | \`{fn}\` | {count} |")
    (out_dir / "COVERAGE100_GAPS.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print("AQT_COVR100_MEASURED", f"{meta['percent']:.4f}%",
          "expression_gaps", len(uncovered), "target", target)
    if report["status"] != "FULL_TARGET_PASS":
        print("AQT_COVR100_NOT_YET_MET: all unexecuted statements remain visible")
        return 1
    print("AQT_COVR100_FULL_PASS")
    return 0


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("coverage_directory")
    p.add_argument("--output", default="coverage100-audit")
    p.add_argument("--target", type=float, default=100.)
    p.add_argument("--diagnostic-only", action="store_true")
    args = p.parse_args()
    if not (0 < args.target <= 100):
        raise SystemExit("target must be within (0, 100]")
    rc = audit(pathlib.Path(args.coverage_directory), pathlib.Path(args.output), args.target)
    if rc and not args.diagnostic_only:
        sys.exit(rc)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Fail-closed, stdlib-only verification of the AquaTrajectories methods dossier.

Exit 0: the *protocol bundle structure* is valid, NOT scientific acceptance.
Exit 2: external evidence invalid/unavailable OR evidence mode (always manual gate).
Exit 1: malformed protocol source or coding error.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[2]
EXPECTED_VERSION = "methods-v0.1.0"
EXPECTED_TAG_COMMIT = "43101800087a18d0942da4d03e21ea47099cb7a9"
EXPECTED_KEYS = {
    "independent_heldout_boxes", "independent_multifish_ids",
    "original_raw_video_permission", "hardware_exposure_pulses",
    "surveyed_xyz_holdout", "measured_joint_error_coverage",
    "randomized_tank_biology", "physical_aci_trials"
}

class ProtocolError(ValueError):
    pass

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for part in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(part)
    return h.hexdigest()

def ensure(condition: bool, message: str) -> None:
    if not condition:
        raise ProtocolError(message)

def audit_protocol(root: Path = ROOT, repo: Path | None = None) -> dict:
    root = Path(root)
    repo = Path(repo) if repo is not None else root.parents[2]
    manifest_path = root / "manifest.json"
    ensure(manifest_path.is_file(), "Missing manifest.json")
    m = json.loads(manifest_path.read_text(encoding="utf-8"))
    ensure(m.get("schema_version") == "1.0", "Unexpected manifest schema")
    ensure(m.get("protocol_version") == EXPECTED_VERSION, "Protocol version mismatch")
    ensure(m.get("status") == "protocol_only_not_registered", "Manifest falsely marked registered")
    ensure(m.get("paper_status") == "manuscript_draft_no_independent_results", "Draft paper status changed without review")
    sw = m.get("software_baseline", {})
    ensure(sw.get("version") == "0.1.1" and sw.get("git_tag") == "v0.1.1", "Wrong released software")
    ensure(sw.get("tag_commit_sha") == EXPECTED_TAG_COMMIT, "Pinned release SHA mismatch")
    ensure(sw.get("doi") == "10.5281/zenodo.24262905", "Wrong released DOI")
    ensure(not m.get("scientific_release_allowed"), "Self-certified scientific release forbidden")
    ensure(m.get("empirical_results_count") == 0, "Evidence unexpectedly claims empirical results")
    ensure(not m.get("registration", {}).get("registered"), "Protocol cannot self-declare registration")
    ensure(m.get("registration", {}).get("url") is None, "Invented registration URL detected")
    ensure(all(val is False for val in m.get("claims", {}).values()), "Any self-certified independent scientific claim prohibited")
    ensure(set(m.get("external_evidence", {})) == EXPECTED_KEYS, "External-evidence key set mismatch")
    ensure(all(v == "not_provided" for v in m["external_evidence"].values()),
           "Empirical claims need independent reviewer procedure, not manifest editing")
    required = list(m.get("required_documents", []))
    ensure(len(required) == len(set(required)) and len(required) >= 9, "Document inventory invalid")
    for name in required:
        ensure("/" not in name and "\\" not in name and (root / name).is_file(),
               f"Required document absent: {name}")
        ensure((root / name).stat().st_size > 100, f"Required document too short: {name}")
    schemas = list(m.get("required_schema_files", []))
    ensure(len(schemas) == len(set(schemas)) and len(schemas) == 12, "Expected exactly 12 data schemas")
    for rel in schemas:
        ensure(rel.startswith("schemas/") and rel.endswith(".csv"), f"Unexpected schema path: {rel}")
        file = root / rel
        ensure(file.is_file(), f"Missing schema {rel}")
        with file.open("r", encoding="utf-8", newline="") as handle:
            rows = list(csv.reader(handle))
        ensure(len(rows) == 1 and len(rows[0]) >= 4,
               f"Schema has non-header rows or insufficient columns: {rel}")
        ensure(len(rows[0]) == len(set(rows[0])), f"Duplicate schema column: {rel}")
    manuscript = (root / "MANUSCRIPT.md").read_text(encoding="utf-8")
    protocol = (root / "REGISTERABLE_PROTOCOL.md").read_text(encoding="utf-8")
    ensure("NOT YET AVAILABLE" in manuscript and "NOT REGISTERED" in protocol,
           "Manuscript missing explicit scientific holdout boundary")
    registry = repo / m.get("source_science_registry", "")
    ensure(registry.is_file(), "Missing original scientific gate registry")
    gates = json.loads(registry.read_text(encoding="utf-8"))
    milestones = gates.get("milestones", [])
    ensure(len(milestones) == 9, "Original scientific registry must contain nine gates")
    ensure(not gates.get("independently_validated_research_system") and
           not gates.get("scientific_release_approved"), "Source registry is unexpectedly self-certified")
    ensure(all(row.get("scientific_certified") is False for row in milestones),
           "Source scientific gate is unexpectedly certified; needs human investigation")
    return {
        "protocol_version": EXPECTED_VERSION,
        "software_tag": "v0.1.1",
        "software_tag_sha": EXPECTED_TAG_COMMIT,
        "scientific_certified": False,
        "protocol_status": "STRUCTURAL_PASS_ONLY",
        "registration": "NOT_REGISTERED",
        "independent_results": "NOT_PROVIDED",
        "schemas": len(schemas),
        "documents": len(required),
        "gates": len(milestones),
        "files_sha256": {rel: sha256(root / rel)
                         for rel in sorted(required + schemas + ["manifest.json"])}
    }

def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", required=True, choices=["protocol", "evidence"])
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--repository-root", type=Path)
    parser.add_argument("--report", type=Path, help="Optional report JSON path")
    args = parser.parse_args(argv)
    try:
        report = audit_protocol(args.root, args.repository_root)
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print(f"AQT_METHODS_PROTOCOL_INVALID: {exc}", file=sys.stderr)
        return 2
    if args.mode == "evidence":
        # No checker can authenticate an external reviewer's signature,
        # an original camera, animal ethics approval or independently
        # surveyed physical truth based solely on a self-written JSON.
        report["status"] = "BLOCKED_INDEPENDENT_EXTERNAL_EVIDENCE_REQUIRED"
        report["reason"] = "Protocol structure passes; no original independently audited heldout measurements supplied"
        status = 2
    else:
        report["status"] = "PASS_PROTOCOL_STRUCTURE_NOT_SCIENTIFIC_CERTIFICATION"
        status = 0
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in
                      ["protocol_version", "software_tag", "schemas", "status"]}, sort_keys=True))
    return status

if __name__ == "__main__":
    sys.exit(main())

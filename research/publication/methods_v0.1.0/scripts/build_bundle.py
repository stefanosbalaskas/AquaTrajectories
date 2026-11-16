#!/usr/bin/env python3
"""Build a deterministic, no-restricted-data methods-protocol reproducibility ZIP."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZIP_STORED, ZipFile, ZipInfo
from verify import ROOT, audit_protocol

FILENAME = "AquaTrajectories_methods_v0.1.0_pinned_v0.1.1.zip"
FIXED_DATE = (2026, 11, 16, 0, 0, 0)
ALLOWED_SUFFIXES = {".md", ".json", ".csv", ".bib", ".py"}

def build(root: Path = ROOT, output: Path | None = None) -> dict:
    root = Path(root)
    audit_protocol(root)
    output = Path(output) if output else root / "dist" / FILENAME
    files = []
    for p in root.rglob("*"):
        if not p.is_file() or p.suffix.lower() not in ALLOWED_SUFFIXES:
            continue
        if "__pycache__" in p.parts or "dist" in p.parts or ".git" in p.parts:
            continue
        rel = p.relative_to(root).as_posix()
        if rel.startswith("study_evidence") or rel.startswith("empirical/"):
            raise RuntimeError("Refuse to bundle arbitrary unreviewed empirical data")
        if rel.endswith(".pyc"):
            continue
        files.append((rel, p))
    files.sort()
    hashes = {name: hashlib.sha256(p.read_bytes()).hexdigest() for name, p in files}
    manifest = {
      "dossier_version": "methods-v0.1.0",
      "software_tag": "v0.1.1",
      "source_files_sha256": hashes,
      "scientific_results_supplied": False,
      "note": "Integrity hashes do not independently authenticate original video, annotation, survey or ethics evidence."
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    def add(z: ZipFile, name: str, payload: bytes):
        info = ZipInfo(name, FIXED_DATE)
        info.compress_type = ZIP_STORED
        info.external_attr = 0o644 << 16
        z.writestr(info, payload)
    with ZipFile(output, "w", compression=ZIP_STORED) as z:
        for name, p in files:
            add(z, "AquaTrajectories_methods_v0.1.0/" + name, p.read_bytes())
        add(z, "AquaTrajectories_methods_v0.1.0/FILE_SHA256.json",
            (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8"))
    return {
      "bundle": str(output),
      "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
      "file_count": len(files) + 1,
      "scientific_results_supplied": False,
      "reproducible_protocol_only": True
    }

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path)
    args=parser.parse_args(argv)
    result=build(output=args.output)
    print(json.dumps(result, indent=2, sort_keys=True))

if __name__=="__main__":
    main()

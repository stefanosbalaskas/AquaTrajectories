#!/usr/bin/env python3
"""Fail-closed, stdlib-only source and provenance checks for v0.2.1.

Checks known filename and archive risks, not a claim of comprehensive
content/third-party rights or independent biological validation.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import tarfile

ROOT = pathlib.Path(".")
VERSION = "0.2.1"
SOURCE = "aquaTrajectories_0.2.1.tar.gz"
FORBIDDEN_EXT = {
    ".xlsx", ".xls", ".xlsm", ".mp4", ".mov", ".avi", ".mkv", ".rar",
    ".7z", ".onnx", ".pt", ".pth", ".h5", ".hdf5", ".parquet",
    ".feather", ".pkl", ".pem", ".key",
}
PRIVATE_PATH = re.compile(
    r"(?:^|[/_.-])(smartfish|confidential|private[_-]?data|"
    r"private[_-]?videos?|raw[_-]?videos?|original[_-]?annotations)(?:$|[/_.-])",
    re.IGNORECASE,
)
REQUIRED = [
    "DESCRIPTION", "NAMESPACE", "NEWS.md", "CITATION.cff",
    "inst/examples/evidence_guardrails.R",
    "inst/examples/evidence_guardrails.Rmd",
    "research/release05/locked_trajectories.csv",
    "docs/RELEASE_CANDIDATE_0_2_1.md",
    "docs/RELEASE_NOTES_0_2_1.md",
]


def sha(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit("AQT_V021_RELEASE_AUDIT_FAIL: " + message)


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()


def validate_path(name: str) -> None:
    p = pathlib.PurePosixPath(name)
    require(not p.is_absolute() and ".." not in p.parts, "unsafe archive path: " + name)
    require(not any(part.lower().endswith(tuple(FORBIDDEN_EXT)) for part in p.parts),
            "potentially private binary file: " + name)
    require(not PRIVATE_PATH.search(name), "private-data path in archive: " + name)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tarball", default=None)
    ap.add_argument("--output", default="v021_source_manifest.json")
    args = ap.parse_args()
    desc = (ROOT / "DESCRIPTION").read_text(encoding="utf-8")
    cff = (ROOT / "CITATION.cff").read_text(encoding="utf-8")
    news = (ROOT / "NEWS.md").read_text(encoding="utf-8")
    require(re.search(r"^Version: 0\.2\.0$", desc, re.M) is not None,
            "DESCRIPTION release version mismatch")
    require(re.search(r"^version: 0\.2\.0$", cff, re.M) is not None,
            "CITATION.cff release version mismatch")
    require("date-released:" not in cff,
            "future candidate must not invent published release date")
    require(news.startswith("# aquaTrajectories 0.2.1 "),
            "NEWS v0.2.1 must be first")
    require("s.balaskas@ac.upatras.gr" in desc,
            "candidate maintainer metadata unexpectedly changed")
    ns = (ROOT / "NAMESPACE").read_text(encoding="utf-8").splitlines()
    exports = [re.fullmatch(r"export\(([^)]+)\)", line).group(1)
               for line in ns if re.fullmatch(r"export\(([^)]+)\)", line)]
    require(len(exports) == 188 and len(set(exports)) == 188,
            "the release freezes exactly 188 unique R exports")
    for name in exports:
        require((ROOT / "man" / (name + ".Rd")).is_file(),
                "undocumented export: " + name)
    for filename in REQUIRED:
        require((ROOT / filename).is_file(), "required source missing: " + filename)
    tracked = git("ls-files", "-z").split("\x00")
    tracked = [name for name in tracked if name]
    for name in tracked:
        validate_path(name)
    require(not any("smartfish" in name.lower() for name in tracked),
            "SmartFish empirical paths are not allowed")
    sha_tag = git("rev-parse", "HEAD")
    result = {
        "schema": "AQT_V021_RELEASE_AUDIT_V1",
        "status": "SOURCE_CHECKED",
        "commit_sha": sha_tag,
        "package_version": VERSION,
        "exported_r_functions": len(exports),
        "namespace_sha256": sha(ROOT / "NAMESPACE"),
        "evidence_fixture_origin": "synthetic",
        "historical_synthetic_fixture_sha256": sha(
            ROOT / "research/release05/locked_trajectories.csv"),
        "tracked_file_count": len(tracked),
        "private_binary_filename_audit": "PASS",
        "independent_biological_validation": False,
        "full_content_and_redistribution_rights_certified": False,
    }
    if args.tarball:
        tar = pathlib.Path(args.tarball)
        require(tar.name == SOURCE and tar.is_file(), "missing v0.2.1 source tarball")
        with tarfile.open(tar, "r:gz") as handle:
            members = handle.getmembers()
            names = [x.name for x in members if x.isfile()]
            for name in names:
                validate_path(name)
            for name in ("DESCRIPTION", "NAMESPACE",
                         "inst/examples/evidence_guardrails.R"):
                require("aquaTrajectories/" + name in names,
                        "tarball missing " + name)
            require(not any("smartfish" in name.lower() for name in names),
                    "SmartFish file in R source tarball")
        result.update({
            "tarball": tar.name,
            "tarball_sha256": sha(tar),
            "tarball_regular_files": len(names),
            "tarball_path_audit": "PASS",
        })
    pathlib.Path(args.output).write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("AQT_V021_RELEASE_AUDIT_PASS", json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()

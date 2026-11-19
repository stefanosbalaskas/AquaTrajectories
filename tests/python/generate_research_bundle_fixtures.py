#!/usr/bin/env python3
"""Create tiny deterministic cross-language fixtures; NO real animal recordings."""
import json
import sys
from pathlib import Path
from test_research_bundle import fixture, rb

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Use: python tests/python/generate_research_bundle_fixtures.py OUTPUT_DIR")
    root = Path(sys.argv[1])
    if root.exists():
        raise SystemExit("Refusing to overwrite fixture directory")
    root.mkdir(parents=True)
    result = {}
    for kind in ("mot_bytetrack","mot_botsort","idtracker_tidy","yolo_csv"):
        folder = root / kind
        args = fixture(folder, kind=kind)
        result[kind] = rb.create(args)["output_sha256"]
    unknown = fixture(root / "unknown_clock",kind="mot_bytetrack",
                      time_status="unknown")
    result["unknown_clock"] = rb.create(unknown)["output_sha256"]
    (root/"EXPECTED.json").write_text(
        json.dumps(result,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    print("SYNTHETIC_TRACKER_BUNDLES_COMPLETE",len(result))

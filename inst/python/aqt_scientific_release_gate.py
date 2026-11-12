#!/usr/bin/env python3
"""Machine-readable AquaTrajectories milestone evidence and release block.

Completeness of a self-declared software inventory is NOT an independent
scientific credential. This checker may reject an unsupported release but it
cannot certify ethics, fish IDs, animal welfare, external XYZ or true hardware.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

STATES={"software_contract_passed","real_source_qualified","simulation_only"}
KEYS=set(range(1,10))


def validate_manifest(obj):
    if not isinstance(obj,dict) or obj.get("schema_version")!="1.0":
        raise ValueError("Incorrect release evidence schema")
    milestones=obj.get("milestones")
    if not isinstance(milestones,list) or len(milestones)!=9:
        raise ValueError("Exactly nine scientific release milestones required")
    present=set()
    not_certified=[]
    for item in milestones:
        if not isinstance(item,dict):
            raise ValueError("Malformed scientific milestone")
        index=item.get("id")
        if type(index) is not int or index not in KEYS or index in present:
            raise ValueError("Milestone IDs must be 1..9 and unique")
        present.add(index)
        if (not isinstance(item.get("name"),str) or
            not item["name"].strip() or
            item.get("engineering_state") not in STATES):
            raise ValueError("Missing milestone provenance/state")
        prs=item.get("qualified_prs")
        if not isinstance(prs,list) or not prs or any(
                type(v) is not int or v<=0 for v in prs) or len(prs)!=len(set(prs)):
            raise ValueError("Milestone references missing or duplicated")
        if not isinstance(item.get("remaining"),str) or not item["remaining"].strip():
            raise ValueError("Missing external validation blocker explanation")
        if type(item.get("scientific_certified")) is not bool:
            raise ValueError("Scientific certification must be explicit boolean")
        if item["scientific_certified"]:
            raise ValueError("Self-declared certification cannot replace independent physical/biological audit")
        not_certified.append({"id":index,"name":item["name"],
                              "missing_external_evidence":item["remaining"]})
    if present!=KEYS:
        raise ValueError("Nine mandatory priority IDs not fully represented")
    if obj.get("scientific_release_approved") is not False or (
            obj.get("independently_validated_research_system") is not False):
        raise ValueError("Refuse unsupported scientific release approval")
    commit=obj.get("last_development_evidence_commit")
    if not isinstance(commit,str) or not re.fullmatch(r"[0-9a-f]{40}",commit):
        raise ValueError("Source evidence commit must be a full SHA")
    return {
        "schema_version":"1.0",
        "engineering_registry_complete":True,
        "n_qualified_software_scope_records":9,
        "n_independently_certified_scientific_milestones":0,
        "scientific_release_permitted":False,
        "n_scientifically_blocked_milestones":len(not_certified),
        "blockers":sorted(not_certified,key=lambda x:x["id"]),
        "software_manifest_is_not_external_certification":True
    }


def run(path):
    blob=Path(path).read_bytes()
    result=validate_manifest(json.loads(blob))
    result["input_manifest_sha256"]=hashlib.sha256(blob).hexdigest()
    return result


def main(argv=None):
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--manifest",required=True,type=Path)
    ap.add_argument("--mode",choices=["engineering_registry","scientific_release"],
                    default="engineering_registry")
    ap.add_argument("--report",type=Path)
    args=ap.parse_args(argv)
    report=run(args.manifest)
    if args.report:
        if args.report.exists():
            raise FileExistsError("Refuse overwrite evidence report")
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(report,indent=2,sort_keys=True)+"\n")
    else:
        print(json.dumps(report,indent=2,sort_keys=True))
    # A scientific release is categorically BLOCKED by this manifest. The
    # user must replace it with independently inspected and documented
    # third-party evidence; merely toggling booleans is rejected.
    if args.mode=="scientific_release":
        return 2
    return 0


if __name__=="__main__":
    raise SystemExit(main())

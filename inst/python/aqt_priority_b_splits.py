#!/usr/bin/env python3
"""Leakage-resistant experiment split and trained-model provenance qualification.

Only external recording-level split membership is reviewed; this cannot prove
that a supplied file was not visually duplicated or manually inspected.
Requires exact source recording hashes, fish groups and acquisition sessions.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import re
from pathlib import Path

COLUMNS=["dataset","recording_id","fish_group_id","session_id",
         "source_video_sha256","split","annotation_status"]
SPLITS={"train","val","test"}

def validate_split(path):
    with Path(path).open(newline="",encoding="utf-8-sig") as f:
        r=csv.DictReader(f)
        if r.fieldnames != COLUMNS:
            raise ValueError("Split must contain dataset, recording, fish group, session, hash, split and annotation status")
        rows=list(r)
    if not rows:
        raise ValueError("No independent recording split")
    def validate_hash(s):
        return isinstance(s,str) and re.fullmatch(r"[0-9a-f]{64}",s) is not None
    for row in rows:
        if (not all(row.get(k) and row[k].strip() for k in COLUMNS) or
            not validate_hash(row["source_video_sha256"]) or
            row["split"] not in SPLITS or
            row["annotation_status"] not in
            {"fully_annotated","published_unreviewed","training_labels"}):
            raise ValueError("Missing or invalid source recording fields")
    if {r["split"] for r in rows}!=SPLITS:
        raise ValueError("Train, validation and held-out test source recordings must all exist")
    if len({(r["dataset"],r["recording_id"]) for r in rows})!=len(rows):
        raise ValueError("Duplicate source recording ID")
    # Strongest defensible splits: no repeated raw video, animal group OR
    # acquisition session appears across the three partitions.
    for key in ("source_video_sha256","fish_group_id","session_id"):
        members={}
        for r in rows:
            item=(r["dataset"],r[key]) if key!="source_video_sha256" else r[key]
            members.setdefault(item,set()).add(r["split"])
        if any(len(v)!=1 for v in members.values()):
            raise ValueError("Train/validation/test leakage across "+key)
    result={"n_recordings":len(rows),
            "by_split":{v:sum(r["split"]==v for r in rows) for v in SPLITS},
            "test_video_sha256":[r["source_video_sha256"] for r in rows
                                  if r["split"]=="test"],
            "train_video_sha256":[r["source_video_sha256"] for r in rows
                                   if r["split"]=="train"],
            "val_video_sha256":[r["source_video_sha256"] for r in rows
                                 if r["split"]=="val"],
            "source_manifest_sha256":hashlib.sha256(Path(path).read_bytes()).hexdigest(),
            "overlap_in_declared_source_hash_groups_sessions":False,
            "annotation_independence_certified":False}
    return result

def validate_model_provenance(path,split):
    p=json.loads(Path(path).read_text())
    for k in ("model_or_config_sha256","training_source_video_sha256",
              "model_selection_source_video_sha256","source_split_manifest_sha256"):
        if k not in p:
            raise ValueError("Missing frozen model selection provenance: "+k)
    if p["source_split_manifest_sha256"]!=split["source_manifest_sha256"]:
        raise ValueError("Model provenance not tied to frozen group splits")
    if set(p["training_source_video_sha256"])!=set(split["train_video_sha256"]):
        raise ValueError("Recorded training inputs differ from train split")
    if set(p["model_selection_source_video_sha256"])!=set(split["val_video_sha256"]):
        raise ValueError("Model selection used other than the validation split")
    if (set(p["training_source_video_sha256"]) |
        set(p["model_selection_source_video_sha256"])) & set(split["test_video_sha256"]):
        raise ValueError("Held-out test source contaminated by training/model selection")
    if p.get("test_reference_labels_used_for_training_or_selection") is not False:
        raise ValueError("Training provenance admits test leakage")
    return True

def main():
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument("--splits",type=Path,required=True)
    a.add_argument("--model-provenance",type=Path)
    a.add_argument("--out",type=Path,required=True)
    opts=a.parse_args()
    if opts.out.exists():raise FileExistsError("Refuse overwrite split qualification")
    audit=validate_split(opts.splits)
    if opts.model_provenance:
        validate_model_provenance(opts.model_provenance,audit)
        audit["model_provenance_consistent"]=True
    opts.out.parent.mkdir(parents=True,exist_ok=True)
    opts.out.write_text(json.dumps(audit,indent=2,sort_keys=True)+"\n")
    print(json.dumps(audit,sort_keys=True))

if __name__=="__main__":main()

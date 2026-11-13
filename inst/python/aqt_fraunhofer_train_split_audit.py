#!/usr/bin/env python3
"""Inspect original Fraunhofer Datumaro A/B and YOLO training ZIP provenance.

This is a reproducible source-data QA step, NOT a trained YOLO result.
It checks *exact image byte equality* between official training and
evaluation source archives. Non-overlapping hashes do NOT establish
independent aquaria, biological fish, background, temporal ranges, or
holdout recording cohorts: these need independent video-level review.

The upstream HHI HTTPS peer has an incomplete certificate issuer chain.
All outputs say upstream TLS verification was NOT achieved.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import zipfile

ALLOWED={
 "datumaro_a":"https://cvg.hhi.fraunhofer.de/FishTrackingData/video_a/datumaro_a.zip",
 "datumaro_b":"https://cvg.hhi.fraunhofer.de/FishTrackingData/video_b/datumaro_b.zip",
 "training_yolo":"https://cvg.hhi.fraunhofer.de/FishTrackingData/training_yolo_ultralytics.zip"
}
IMG_EXT={".jpg",".jpeg",".png"}
LABEL_EXT={".json",".txt",".yaml",".yml"}
MAX_ARCHIVE=3_500_000_000
MAX_MEMBER=600_000_000
MAX_MEMBERS=100000

def file_sha(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda:f.read(1<<20),b""):
            h.update(chunk)
    return h.hexdigest()

def inspect(path,role):
    if role not in ALLOWED:
        raise ValueError("Only original source HHI Datumaro A/B or YOLO train archives")
    file=Path(path)
    if not file.is_file() or file.stat().st_size>MAX_ARCHIVE:
        raise ValueError("Missing or oversized original HHI archive")
    counts=Counter()
    img_sha={}
    stem_index=Counter()
    annotation_records=[]
    original_sample_member_names=[]
    with zipfile.ZipFile(file) as z:
        members=z.infolist()
        if len(members)>MAX_MEMBERS or not members:
            raise ValueError("Unreasonable original archive member count")
        for info in members:
            raw=info.filename
            pp=PurePosixPath(raw)
            if (pp.is_absolute() or ".." in pp.parts or
                "\\" in raw or len(raw)>320 or
                info.file_size>MAX_MEMBER or
                (info.file_size and not info.compress_size) or
                (info.compress_size and info.file_size>500*info.compress_size)):
                raise ValueError("Unsafe/oversized original HHI archive member")
            if info.is_dir():continue
            counts["files"]+=1
            if len(original_sample_member_names)<15:
                original_sample_member_names.append(raw)
            ext=pp.suffix.lower()
            if ext in IMG_EXT:
                counts["image_files"]+=1
                h=hashlib.sha256()
                with z.open(info) as stream:
                    for buf in iter(lambda:stream.read(1<<20),b""):
                        h.update(buf)
                img_sha[raw]=h.hexdigest()
                stem_index[pp.stem]+=1
            elif ext in LABEL_EXT:
                counts["annotation_or_config_files"]+=1
                if ext==".json":
                    counts["json_files"]+=1
                    if info.file_size<=80_000_000:
                        raw_json=z.read(info)
                        try:data=json.loads(raw_json)
                        except (ValueError,UnicodeDecodeError):
                            raise ValueError("Original Datumaro JSON is invalid")
                        summary={"member":info.filename,
                                 "original_member_sha256":hashlib.sha256(raw_json).hexdigest(),
                                 "top_level_type":type(data).__name__,
                                 "top_level_keys":sorted(data.keys())[:24] if isinstance(data,dict) else [],
                                 "item_count":None,
                                 "annotation_type_counts":{},
                                 "source_track_attributes_observed":False}
                        if isinstance(data,dict) and isinstance(data.get("items"),list):
                            items=data["items"]
                            summary["item_count"]=len(items)
                            typ=Counter()
                            track=False
                            for item in items:
                                if not isinstance(item,dict):
                                    raise ValueError("Malformed Datumaro dataset item")
                                for ann in item.get("annotations",[]):
                                    if not isinstance(ann,dict):
                                        raise ValueError("Malformed Datumaro annotation")
                                    typ[str(ann.get("type","unknown"))]+=1
                                    attrs=ann.get("attributes",{})
                                    if isinstance(attrs,dict) and any(
                                        "track" in str(k).lower() or "identity" in str(k).lower()
                                        for k in attrs):track=True
                            summary["annotation_type_counts"]=dict(typ)
                            summary["source_track_attributes_observed"]=track
                        annotation_records.append(summary)
    if counts["image_files"]==0:
        raise ValueError("Original source archive contains no original image bytes")
    if counts["annotation_or_config_files"]==0:
        raise ValueError("Original source archive lacks annotation/configuration provenance")
    return {
      "source_archive_role":role,"original_source_url":ALLOWED[role],
      "original_archive_sha256":file_sha(file),
      "original_archive_bytes":file.stat().st_size,
      "original_source_tls_peer_verified":False,
      "archive_member_counts":dict(counts),
      "source_member_examples":original_sample_member_names,
      "source_image_digests":img_sha,
      "original_image_sha256_unique_count":len(set(img_sha.values())),
      "duplicate_image_exact_digest_count":len(img_sha)-len(set(img_sha.values())),
      "duplicate_image_filename_stem_count":sum(n-1 for n in stem_index.values() if n>1),
      "original_annotation_descriptors":annotation_records,
      "datumaro_tracks_independently_reviewed":False,
      "original_video_exposure_timing_verified":False
    }

def compare(archives):
    if set(archives)!={"datumaro_a","datumaro_b","training_yolo"}:
        raise ValueError("Require all three real HHI source archives")
    source={key:inspect(value,key) for key,value in archives.items()}
    digests={key:set(v["source_image_digests"].values()) for key,v in source.items()}
    pairs={}
    for a,b in (("datumaro_a","datumaro_b"),("datumaro_a","training_yolo"),
                ("datumaro_b","training_yolo")):
        common=digests[a]&digests[b]
        pairs[f"{a}_versus_{b}"]={
            "exactly_identical_source_image_sha256_count":len(common),
            "exact_source_image_bytes_disjoint":not common,
            "spatial_or_temporal_near_duplicates_tested":False,
            "independent_tank_or_fish_cohort_verified":False
        }
    # Avoid shipping all original per-image hashes as a massively bloated
    # report. Only publish 10 source pairs and the aggregate digest
    # of the canonically sorted image-digest manifest per archive.
    for record in source.values():
        images=record.pop("source_image_digests")
        sorted_manifest="\n".join(f"{k}\t{v}" for k,v in sorted(images.items()))
        record["source_image_digest_manifest_sha256"]=hashlib.sha256(
            sorted_manifest.encode()).hexdigest()
        record["original_image_sha256_examples"]=dict(list(sorted(images.items()))[:10])
    return {
        "schema":"aqt_wave14i_hhi_source_split_audit_v1",
        "sources":source,
        "source_image_overlap_analysis":pairs,
        "verified_no_exact_file_duplicates_between_train_and_evaluation":all(
            pairs[f"datumaro_{seq}_versus_training_yolo"]["exact_source_image_bytes_disjoint"]
            for seq in ("a","b")),
        "video_holdout_not_temporally_correlated_verified":False,
        "detector_weights_trained_by_AquaTrajectories":False,
        "model_detection_f1_computed":False,
        "actual_fish_tracking_HOTA_computed":False,
        "source_identity_GT_prediction_blind_adjudicated":False,
        "scientific_cross_domain_transfer_certified":False,
        "summary":"All source images hashed from exact ZIP members. Exact byte equality "
           "can detect duplicates but cannot establish cross-video/tank/animal independence."
    }

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--datumaro-a",type=Path,required=True)
    p.add_argument("--datumaro-b",type=Path,required=True)
    p.add_argument("--training-yolo",type=Path,required=True)
    p.add_argument("--out",type=Path,required=True)
    args=p.parse_args(argv)
    if args.out.exists():raise FileExistsError("Original source split evidence cannot be overwritten")
    data=compare({"datumaro_a":args.datumaro_a,
                  "datumaro_b":args.datumaro_b,
                  "training_yolo":args.training_yolo})
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(data,sort_keys=True,indent=2)+"\n")
    print(json.dumps({
        "original_source_image_counts":{
            k:v["archive_member_counts"]["image_files"] for k,v in data["sources"].items()},
        "source_exact_image_duplicate_counts":data["source_image_overlap_analysis"],
        "train_eval_independent_fish_tanks_verified":False
    },indent=2))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
